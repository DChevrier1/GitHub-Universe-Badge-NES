.include "defs.s"

.segment "STARTUP"

.export start
start:
    sei  ; ignore IRQ
    cld  ; disable decimal mode
    
    ; Disable APU interrupts
    ldx #$40
    stx APU_FRAME_CTR
    ldx #$00
    stx APU_DMC

    ; setup stack at 0xFF
    ldx #$FF
    txs

    ; Turn off PPU
    inx ; X => 0
    stx PPU_CTRL
    stx PPU_MASK

; Wait for a VBLANK
:
    bit $2002
    bpl :-

; Zero out RAM from 0x0000 - 0x07FF
    txa     ; A == 0
ClearMem:
    sta $00, x
    sta $100, x
    lda #$FF    ; Board stage and sprites (0x200-0x3FF) get 0xFF
    sta $200, x
    sta $300, x
    lda #$00
    sta $400, x
    sta $500, x
    sta $600, x
    sta $700, x
    inx
    bne ClearMem    ; branches when X != 0

; Wait for another VBLANK
:
    bit $2002
    bpl :-

; Set OAM DMA start address to 0x200
    lda #$02
    sta OAM_DMA
    nop

; Set up palettes in PPU
    ; Set PPU address to 0x3F00 (palettes)
    bit PPU_STATUS  ; clear PPU address latch
    lda #$3F
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR
    ldx #$00
.import PaletteData
LoadPalettes:
    lda PaletteData, X
    sta PPU_DATA
    inx
    cpx #$20
    bne LoadPalettes
