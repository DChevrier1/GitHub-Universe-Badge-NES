.include "defs.s"

.segment "ZEROPAGE"
frameCounter: .res 1
tilePosPtr: .res 2
slideDirTemp: .res 1

.segment "CODE"

.import PaintAttributeBufferRow
.import WipeBoardRow, WipeSpriteBuffer, WipeSpriteRow
.import WipeTiles, IterateTileRowSlide, CalculateTileTransitions, ResetTileVelocities, FindTileRow, UpdateTilePowers, AddTile
.import DrawBoardRow
.import ReadJoy
.importzp blitSource, blitMode, nmiDone
.importzp blitCounter, slideDir, tileRow
.importzp tileX, tileY, tilePower, tileVelocity
.importzp newButtons1
.importzp tileIndex1, tileIndex2, tileIndex3, tileIndex4

; Set blit mode
    lda #BLIT_HORIZONTAL
    sta blitMode

; Draw the main background
.import Blit256
    ; Set PPU address to 0x2000 (first nametable)
    bit PPU_STATUS  ; clear PPU address latch
    lda #$20
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR
    lda #<BackgroundPatternTable
    sta blitSource
    lda #>BackgroundPatternTable
    sta blitSource + 1
    ldy #0
    jsr Blit256
    inc blitSource + 1
    jsr Blit256
    inc blitSource + 1
    jsr Blit256
    inc blitSource + 1
    jsr Blit256

    ; Add some tiles for testing
    .importzp tiles
    jsr WipeTiles
    lda #0
    sta tilePower
    lda #4
    sta tileX
    lda #12
    sta tileY
    lda #0
    sta tileVelocity
    jsr AddTile

    lda #0
    sta tileX
    jsr AddTile

    lda #2
    sta tilePower
    lda #0
    sta tileY
    jsr AddTile

    lda #$FF
    sta frameCounter

    lda #DIR_LEFT
    sta slideDir

; Enable interrupts
    cli
    ; enable NMI, use second CHAR tile set for sprites
    lda #%10001000
    sta PPU_CTRL
    ; Enable sprites and background
    lda #%00011110
    sta PPU_MASK

MainLoop:
    lda frameCounter
    cmp #$FF
    bne :+
    ; Only check button presses if we're not currently animating
    jsr CheckForButtonPresses
:

    ; Set tileRow
    lda blitCounter
    and #$03
    sta tileRow

    jsr IterateTileRowSlide
    jsr WipeSpriteRow
    jsr WipeBoardRow
    jsr DrawBoardRow
    jsr PaintAttributeBufferRow

    lda frameCounter
    cmp #$FF
    beq WaitLoop
    inc frameCounter
    lda frameCounter
    cmp #12
    bne :+
    jsr UpdateTilePowers
:
    cmp #16 ; End animation after 16 frames
    bne :+
    lda #$FF
    sta frameCounter
    jsr ResetTileVelocities
:

WaitLoop:
    lda nmiDone
    cmp #1
    bne WaitLoop
    lda #0
    sta nmiDone
    jmp MainLoop

CheckForButtonPresses:
    jsr ReadJoy
    lda newButtons1
    cmp #BUTTON_LEFT
    bne :+
    lda #DIR_LEFT
    sta slideDir
    lda #BLIT_HORIZONTAL
    sta blitMode
    jmp BeginSlideAnimation
:
    cmp #BUTTON_RIGHT
    bne :+
    lda #DIR_RIGHT
    sta slideDir
    lda #BLIT_HORIZONTAL
    sta blitMode
    jmp BeginSlideAnimation
:
    cmp #BUTTON_DOWN
    bne :+
    lda #DIR_DOWN
    sta slideDir
    lda #BLIT_VERTICAL
    sta blitMode
    jmp BeginSlideAnimation
:
    cmp #BUTTON_UP
    bne :+
    lda #DIR_UP
    sta slideDir
    lda #BLIT_VERTICAL
    sta blitMode
    jmp BeginSlideAnimation
:
    rts
BeginSlideAnimation:
    lda #0
    sta frameCounter
    sta blitCounter
    ; Calculate velocities on all 4 rows
    sta tileRow
    jsr FindTileRow
    jsr CalculateTileTransitions
    .repeat 3
        inc tileRow
        jsr FindTileRow
        jsr CalculateTileTransitions
    .endrepeat

    ; Set up a new tile to slide in
    lda #0
    sta tilePower
    lda slideDir
    sta slideDirTemp
    cmp #DIR_LEFT
    bne :+
    lda #$FF ; -1
    sta tileVelocity
    lda #16
    sta tileX
    lda #DIR_UP
    sta slideDir
    lda #<tileY
    sta tilePosPtr
    lda #>tileY
    sta tilePosPtr+1
    lda #3
    sta tileRow
    jmp @DoneSettingUpSlideInTile
:
    cmp #DIR_RIGHT
    bne :+
    lda #1
    sta tileVelocity
    lda #$FC    ; -4
    sta tileX
    lda #DIR_UP
    sta slideDir
    lda #<tileY
    sta tilePosPtr
    lda #>tileY
    sta tilePosPtr+1
    lda #0
    sta tileRow
    jmp @DoneSettingUpSlideInTile
:
    cmp #DIR_UP
    bne :+
    lda #$FF ; -1
    sta tileVelocity
    lda #16
    sta tileY
    lda #DIR_LEFT
    sta slideDir
    lda #<tileX
    sta tilePosPtr
    lda #>tileX
    sta tilePosPtr+1
    lda #3
    sta tileRow
    jmp @DoneSettingUpSlideInTile
:
    ; DIR_DOWN
    lda #1
    sta tileVelocity
    lda #$FC    ; -4
    sta tileY
    lda #DIR_LEFT
    sta slideDir
    lda #<tileX
    sta tilePosPtr
    lda #>tileX
    sta tilePosPtr+1
    lda #0
    sta tileRow
@DoneSettingUpSlideInTile:
    jsr FindTileRow
    lda slideDirTemp
    sta slideDir
    ldx tileIndex1
    cpx #$FF
    beq @UseTileIndex1
    lda tiles + Tile::velocity, X
    bne @UseTileIndex1
    jmp @TryTileIndex2
@UseTileIndex1:
    lda #0
    ldy #0
    sta (tilePosPtr), y
    jsr AddTile
    jmp @DoneAddingNewTile
@TryTileIndex2:
    ldx tileIndex2
    cpx #$FF
    beq @UseTileIndex2
    lda tiles + Tile::velocity, X
    bne @UseTileIndex2
    jmp @TryTileIndex3
@UseTileIndex2:
    lda #4
    ldy #0
    sta (tilePosPtr), y
    jsr AddTile
    jmp @DoneAddingNewTile
@TryTileIndex3:
    ldx tileIndex3
    cmp #$FF
    beq @UseTileIndex3
    lda tiles + Tile::velocity, X
    bne @UseTileIndex3
    jmp @TryTileIndex4
@UseTileIndex3:
    lda #8
    ldy #0
    sta (tilePosPtr), y
    jsr AddTile
    jmp @DoneAddingNewTile
@TryTileIndex4:
    ldx tileIndex4
    cpx #$FF
    lda tiles + Tile::velocity, X
    bne @UseTileIndex4
    jmp @DoneAddingNewTile
@UseTileIndex4:
    lda #12
    ldy #0
    sta (tilePosPtr), y
    jsr AddTile
@DoneAddingNewTile:
    rts

.segment "RODATA"

.export BackgroundPatternTable
BackgroundPatternTable:
.incbin "../data/board-background.nam"

.segment "CHARS"

.incbin "../data/2048.chr"

.segment "VECTORS"
.import nmi, start
.word nmi
.word start
