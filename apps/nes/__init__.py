"""Silent, stock-firmware NES launcher for the Universe 2026 badge.

Original adapter; emulator attribution and license are in UPSTREAM.md / LICENSE.
No IRQ handlers, clock overclocking, full-state imports or stock settings writes.
"""
import array
import gc
import os
import time
try:
    from .font5x7 import GLYPHS as FONT
    from .cartridge import inspect_rom, load_sram, save_sram
except ImportError:
    from font5x7 import GLYPHS as FONT
    from cartridge import inspect_rom, load_sram, save_sram

APP_DIR='/system/apps/nes'
FRAME_US=16667


def discover(folder):
    games=[]
    try:names=sorted(os.listdir(folder))
    except OSError:return games
    for name in names:
        if not name.lower().endswith('.nes') or '/' in name or '\\' in name:continue
        try:
            meta=inspect_rom(folder+'/'+name)
            games.append({'file':name,'title':name[:-4].replace('_',' ').replace('-',' '),'meta':meta,'error':''})
        except (OSError,ValueError) as error:
            games.append({'file':name,'title':name[:-4],'meta':None,'error':str(error)[:100]})
    return games


class Inputs:
    """Separate capacitive START from the physical HOME key."""
    def __init__(self,badge,constants):
        self.badge=badge
        self.constants=constants
        self.chord_ms=0
        self.chord_active=False
        self.chord_latched=False
    def read(self,dt):
        pad=self.badge.pad
        buttons=self.badge.buttons
        key=self.constants
        states=[pad.held(key[name]) for name in ('BUTTON_BACK','BUTTON_SELECT','BUTTON_MENU','BUTTON_HOME','BUTTON_UP','BUTTON_DOWN','BUTTON_LEFT','BUTTON_RIGHT')]
        # Physical Select is an A fallback; physical Home is never NES Start.
        for index,name in ((0,'BUTTON_SELECT'),(1,'BUTTON_BACK'),(2,'BUTTON_MENU'),
                           (4,'BUTTON_UP'),(5,'BUTTON_DOWN'),(6,'BUTTON_LEFT'),(7,'BUTTON_RIGHT')):
            states[index]=states[index] or buttons.held(key[name])
        # The cross is also reported as an analog vector by the pad controller.
        direction=pad.direction()
        states[4]=states[4] or direction.y<-.25
        states[5]=states[5] or direction.y>.25
        states[6]=states[6] or direction.x<-.25
        states[7]=states[7] or direction.x>.25
        if states[4] and states[5]:states[4]=states[5]=False
        if states[6] and states[7]:states[6]=states[7]=False
        mask=sum((1<<i) for i in range(8) if states[i])
        chord=states[2] and states[3]
        pause=False
        if not states[2] and not states[3]:
            self.chord_latched=False
        if chord:
            # dt precedes this input sample. Do not count a slow loading frame
            # as time spent holding a newly pressed chord.
            if self.chord_active and not self.chord_latched:
                self.chord_ms+=max(0,dt)*1000
                if self.chord_ms>=700:
                    pause=True;self.chord_latched=True
        else:
            self.chord_ms=0
        self.chord_active=chord
        return {'mask':mask,'pause':pause,'home':buttons.pressed(key['BUTTON_HOME']),
                'up':pad.pressed(key['BUTTON_UP']) or buttons.pressed(key['BUTTON_UP']),
                'down':pad.pressed(key['BUTTON_DOWN']) or buttons.pressed(key['BUTTON_DOWN']),
                'choose':pad.pressed(key['BUTTON_BACK']) or pad.pressed(key['BUTTON_HOME']) or buttons.pressed(key['BUTTON_SELECT']),
                'back':pad.pressed(key['BUTTON_SELECT'])}


class NESApp:
    def __init__(self,namespace,app_dir=APP_DIR,state_dir='/state/nes_badge'):
        self.ns=namespace
        self.badge=namespace['badge']
        self.screen=namespace['screen']
        self.input=Inputs(self.badge,namespace)
        self.app_dir=app_dir
        self.state_dir=state_dir
        self.games=discover(app_dir+'/roms')
        self.selected=0
        self.mode='library'
        self.pause_index=0
        self.error=''
        self.nes=None
        self.sram_path=None
        self.last_sram=None
        self.active=None
        self.frames=0
        self.fps=0
        self.accum_us=0
        self.fps_elapsed=0
        self.save_elapsed=0
        self.dirty=True
        self.palette=None
        self.hw_palette=None
        self.last_mask=0
        self.skip_game_elapsed=True
        self.save_error=False
        self.badge.caselights(0,0,0,0)
        self.pens=[namespace['color'].rgb(*rgb) for rgb in ((9,14,26),(27,40,61),(111,130,158),(229,238,250),(255,179,84),(78,214,188))]
        if len(self.screen.raw)!=320*240*2:raise ValueError('NES requires the badge RGB565 320x240 mode')

    def text(self,value,x,y,shade=3,scale=1):
        self.screen.pen=self.pens[shade]
        for ch in str(value).upper():
            for row,bits in enumerate(FONT.get(ch,FONT.get('?', [0]*7))):
                for col in range(5):
                    if bits & (1<<(4-col)):self.screen.rectangle(x+col*scale,y+row*scale,scale,scale)
            x+=6*scale

    def clear(self):
        self.screen.pen=self.pens[0];self.screen.rectangle(0,0,320,240)

    def library(self):
        self.clear()
        self.text('NES',12,12,4,3)
        self.text('POCKET ARCADE',78,20,3)
        self.text('SILENT / STOCK CLOCK / LOCAL GAMES',12,47,2)
        if not self.games:
            self.text('NO GAMES FOUND',12,84,4)
            self.text('COPY AUTHORIZED .NES FILES TO',12,110)
            self.text('APPS/NES/ROMS ON THE BADGER DRIVE',12,125)
        else:
            start=max(0,min(self.selected-2,len(self.games)-6))
            for row,index in enumerate(range(start,min(start+6,len(self.games)))):
                item=self.games[index];y=73+row*21
                if index==self.selected:
                    self.screen.pen=self.pens[1];self.screen.rectangle(8,y-4,304,19)
                self.text(('> ' if index==self.selected else '  ')+item['title'][:43],12,y,4 if item['error'] else 3)
            item=self.games[self.selected]
            detail=item['error'] or ('MAPPER '+str(item['meta']['mapper'])+' / '+str(item['meta']['size']//1024)+' KB')
            self.text(detail[:49],12,207,4 if item['error'] else 2)
        self.text('UP/DOWN CHOOSE   A/START PLAY',12,225,5)
        self.dirty=False

    def build_palette(self,colors):
        # Convert through the firmware's native image writer: no endian guesses.
        image=self.ns['image'];color=self.ns['color']
        surface=image(64,1,bytearray(128),image.RGB565)
        for index,rgb in enumerate(colors):
            surface.pen=color.rgb(*rgb);surface.put(index,0)
        import struct
        self.hw_palette=array.array('H',struct.unpack('<64H',surface.raw))
        self.palette=array.array('H',[0]*32)

    def launch(self,index):
        entry=self.games[index]
        if entry['error']:
            self.error=entry['error'];self.dirty=True;return False
        if not self.persist():
            self.pause(save=False)
            return False
        self.nes=None;gc.collect()
        try:
            try:from .emu import NES,NES_PALETTE
            except ImportError:from emu import NES,NES_PALETTE
            path=self.app_dir+'/roms/'+entry['file']
            # A content-derived ID avoids collisions and untrusted save filenames.
            import hashlib,binascii
            digest=hashlib.sha256()
            with open(path,'rb') as handle:
                while True:
                    chunk=handle.read(4096)
                    if not chunk:break
                    digest.update(chunk)
            identity=binascii.hexlify(digest.digest()).decode()[:24]
            core=NES(path)
            self.nes=core
            self.sram_path=self.state_dir+'/'+identity+'.sav'
            if core.has_battery:load_sram(self.sram_path,core.mem)
            self.last_sram=bytes(core.mem[0x4000:0x6000]) if core.has_battery else None
            if self.hw_palette is None:self.build_palette(NES_PALETTE)
            self.active=entry;self.selected=index;self.mode='game';self.error=''
            self.resume_clock();self.save_elapsed=0
            self.clear();return True
        except (OSError,ValueError,MemoryError,RuntimeError) as error:
            self.nes=None;self.error=str(error)[:100];self.mode='error';self.dirty=True;return False

    def persist(self):
        if not self.nes or not self.nes.has_battery:return True
        try:
            current=bytes(self.nes.mem[0x4000:0x6000])
            if current!=self.last_sram:
                try:os.mkdir(self.state_dir)
                except OSError:pass
                save_sram(self.sram_path,self.nes.mem)
                self.last_sram=current
            if self.save_error:self.error=''
            self.save_error=False
            return True
        except (OSError,ValueError,MemoryError):
            self.error='SAVE FAILED - KEEP BADGE POWERED';self.save_error=True;return False

    def pause(self,save=True):
        self.mode='pause';self.pause_index=0;self.dirty=True
        if save:self.persist()

    def resume_clock(self):
        self.frames=0;self.fps=0;self.fps_elapsed=0;self.accum_us=0
        # The next firmware delta includes loading or menu drawing, not play.
        self.skip_game_elapsed=True

    def draw_error(self):
        self.clear();self.text('CANNOT RUN THIS GAME',12,22,4,2)
        for i in range(3):self.text(self.error[i*48:(i+1)*48],12,70+i*16)
        self.text('A OR B: BACK TO LIBRARY',12,206,5)
        self.dirty=False

    def draw_pause(self):
        self.clear();self.text('PAUSED',12,15,4,2)
        self.text(self.active['title'][:48],12,43)
        for i,label in enumerate(('RESUME','RESTART GAME','GAME LIBRARY')):
            self.text(('> ' if i==self.pause_index else '  ')+label,12,83+i*27,5 if i==self.pause_index else 3)
        self.text('A/B REMAIN INDEPENDENT IN GAME',12,181,2)
        self.text('HOLD START + SELECT TO PAUSE',12,196,2)
        self.text('PHYSICAL HOME RETURNS TO MONAOS',12,211,2)
        if self.error:self.text(self.error[:49],12,226,4)
        self.dirty=False

    def update(self):
        dt=max(0,self.badge.ticks_delta/1000.0)
        event=self.input.read(dt)
        if event['home']:
            if self.close():return 'menu'
            self.pause(save=False);self.draw_pause();return
        if self.mode=='library':
            if self.games:
                if event['up']:self.selected=(self.selected-1)%len(self.games);self.dirty=True
                if event['down']:self.selected=(self.selected+1)%len(self.games);self.dirty=True
                if event['choose']:self.launch(self.selected)
            if self.mode=='library' and self.dirty:self.library()
            elif self.mode=='error' and self.dirty:self.draw_error()
            elif self.mode=='pause' and self.dirty:self.draw_pause()
            return
        if self.mode=='error':
            if event['back'] or event['choose']:
                self.mode='library';self.dirty=True;self.library()
            elif self.dirty:self.draw_error()
            return
        if self.mode=='pause':
            if event['up']:self.pause_index=(self.pause_index-1)%3;self.dirty=True
            if event['down']:self.pause_index=(self.pause_index+1)%3;self.dirty=True
            if event['back']:self.mode='game';self.resume_clock();self.clear();return
            if event['choose']:
                if self.pause_index==0:self.mode='game';self.resume_clock();self.clear();return
                if self.pause_index==1:
                    self.launch(self.selected)
                    if self.mode=='pause':self.draw_pause()
                    elif self.mode=='error':self.draw_error()
                    return
                if self.pause_index==2:
                    if not self.persist():self.dirty=True;self.draw_pause();return
                    self.nes=None;gc.collect();self.mode='library';self.dirty=True;self.library();return
            if self.dirty:self.draw_pause()
            return
        if event['pause']:self.pause();self.draw_pause();return
        if self.skip_game_elapsed:
            self.skip_game_elapsed=False
            return
        self.fps_elapsed+=dt;self.save_elapsed+=dt
        self.accum_us=min(FRAME_US*2,self.accum_us+int(dt*1000000))
        if self.accum_us<FRAME_US:return
        try:
            steps=0
            while self.accum_us>=FRAME_US and steps<2:
                self.nes.step_frame(event['mask'])
                self.accum_us-=FRAME_US;steps+=1
            for i in range(32):self.palette[i]=self.hw_palette[self.nes.mem[0x0900+i]&63]
            # Firmware fence before raw Viper stores; black sidebars preserve 1:1 pixels.
            self.screen.pen=self.pens[0];self.screen.rectangle(0,0,32,240);self.screen.rectangle(288,0,32,240)
            self.nes.render(self.screen.raw,self.palette,2,False)
            self.frames+=1
            if self.fps_elapsed>=1:
                self.fps=round(self.frames/self.fps_elapsed);self.frames=0;self.fps_elapsed=0
            self.text(str(self.fps),3,8,2);self.text('FPS',3,19,2)
            self.last_mask=event['mask']
            if self.save_elapsed>=60:
                self.save_elapsed=0
                if not self.persist():self.pause(save=False);self.draw_pause()
        except (OSError,ValueError,RuntimeError,IndexError,MemoryError) as error:
            self.error=str(error)[:100];self.mode='error';self.dirty=True

    def close(self):
        saved=self.persist()
        self.badge.caselights(0,0,0,0)
        return saved


_app=None

def on_exit():
    if _app and not _app.close():
        # The stock Home interrupt may already be exiting run(); report failure
        # explicitly without replacing that interrupt or claiming the save worked.
        print('NES SAVE FAILED: SRAM was not written; keep the badge powered and retry saving when possible.')


def _start():
    global _app
    namespace=dict(globals())
    for name in ('badge','screen','run','color','image','HIRES','VSYNC','BUTTON_UP','BUTTON_DOWN','BUTTON_LEFT','BUTTON_RIGHT','BUTTON_SELECT','BUTTON_BACK','BUTTON_MENU','BUTTON_HOME'):
        try:namespace[name]=eval(name)
        except NameError:pass
    if not all(name in namespace for name in ('badge','screen','run')):return
    namespace['badge'].mode(namespace['HIRES']|namespace['VSYNC'])
    namespace['screen']=eval('screen')
    namespace['screen'].antialias=namespace['image'].OFF
    namespace['badge'].default_clear=None
    _app=NESApp(namespace)
    namespace['run'](_app.update)

_start()
