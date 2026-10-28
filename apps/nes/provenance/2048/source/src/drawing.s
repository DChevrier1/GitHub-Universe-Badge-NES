.include "defs.s"

.import TileDefinitions, TileColorLookups, PaletteData, BackgroundPatternTable
.import GetTilePosOnNonSlideAxis
.importzp tileRow, slideDir

.struct TileDef
    patternStart    .byte   ; Index into the first CHR table for the tile (ignoring color)
    color           .byte   ; Which color is the tile? (0-4, where 0=>A, 1=>B, etc.)
.endstruct

.segment "ZEROPAGE"

.import tileX, tileY, tilePower, tileVelocity

tileRowCounter: .res 1  ; Counter used for drawing tiles
tileColor:      .res 1  ; Internal variable used for drawing tiles
colorLookup:    .res 1  ; Used in palette mapping
attrIndex:      .res 1  ; Index into attr buffer, used in palette mapping
spriteIndex:    .res 1  ; Next empty index in the SPRITE_BUFFER
spriteX:        .res 1  ; Used in tile sprite drawing
spriteY:        .res 1  ; Used in tile sprite drawing
spriteCHRIndex: .res 1  ; Used in tile sprite drawing
spriteMin:      .res 1  ; Used in sprite filtering
spriteMax:      .res 1  ; Used in sprite filtering

.segment "CODE"

.importzp tileRow
.export WipeBoardRow
WipeBoardRow:
    lda slideDir
    cmp #DIR_UP
    beq @WipeVertical
    cmp #DIR_DOWN
    beq @WipeVertical
@WipeHorizontal:
    lda tileRow
    asl
    asl
    asl
    asl
    asl
    asl
    tay
    asl
    tax
@CopyNextH:
    lda tileRow
    lsr
    cmp #1
    beq :+
    lda BackgroundPatternTable + (BOARD_TOP_Y * 32) + BOARD_LEFT_X, X
    jmp :++
:
    lda BackgroundPatternTable + (BOARD_TOP_Y * 32) + 256 + BOARD_LEFT_X, X
:
    sta BOARD_BUFFER, Y
    lda #0
    sta COLOR_BUFFER, Y
    inx
    iny
    tya
    and #$0F
    bne @CopyNextH
    tya
    and #%00111111
    beq @Done
    txa
    clc
    adc #16
    tax
    jmp @CopyNextH
@WipeVertical:
    lda tileRow
    asl
    asl
    tay
    tax
@CopyNextV:
    lda BackgroundPatternTable + (BOARD_TOP_Y * 32) + BOARD_LEFT_X, X
    sta BOARD_BUFFER, Y
    sta BOARD_BUFFER + 64, Y
    sta BOARD_BUFFER + 128, Y
    sta BOARD_BUFFER + 192, Y
    lda #0
    sta COLOR_BUFFER, Y
    sta COLOR_BUFFER + 64, Y
    sta COLOR_BUFFER + 128, Y
    sta COLOR_BUFFER + 192, Y
    inx
    iny
    tya
    and #$03
    bne @CopyNextV
    tya
    clc
    adc #12
    tay
    txa
    clc
    adc #28
    cmp #128
    bcs @Done
    tax
    jmp @CopyNextV
@Done:
    rts

.export WipeSpriteRow
WipeSpriteRow:
    ldy #0
    lda slideDir
    cmp #DIR_LEFT
    beq @HorizontalMode
    cmp #DIR_RIGHT
    beq @HorizontalMode
@VerticalMode:
    ldx #3  ; Fourth byte of sprite is X-pos, which is what we want to filter on for vertical mode
    lda tileRow
    asl
    asl
    clc
    adc #BOARD_LEFT_X
    asl
    asl
    asl
    sta spriteMin
    adc #32
    sta spriteMax
    jmp @ContinueWipe
@HorizontalMode:
    ldx #0  ; First byte of sprite is Y-pos, which is what we want for horizontal mode
    lda tileRow
    asl
    asl
    clc
    adc #BOARD_TOP_Y
    asl
    asl
    asl
    sta spriteMin
    adc #32
    sta spriteMax
@ContinueWipe:
    lda SPRITE_BUFFER, x
    cmp spriteMin
    bcc @NextSprite
    cmp spriteMax
    bcs @NextSprite
    lda #$FF
    sta SPRITE_BUFFER, y
    sta SPRITE_BUFFER + 1, y
    sta SPRITE_BUFFER + 2, y
    sta SPRITE_BUFFER + 3, y
@NextSprite:
    .repeat 4
        iny
    .endrepeat
    txa
    clc
    adc #4
    bcs @Done
    tax
    jmp @ContinueWipe
@Done:
    rts

.export WipeSpriteBuffer
WipeSpriteBuffer:
    ldx $00
    stx spriteIndex
    lda $FF     ; Last tile is empty
:
    sta SPRITE_BUFFER, x
    inx
    bne :-
    rts

; DrawBoardRow
; Draws all the tiles (if any) from a given row or column onto BOARD_BUFFER.
;
; Params:
; tileRow - Which row or column to draw (0-3)
; slideDir - Determines whether to draw based on columns or rows
.export DrawBoardRow
.importzp tileRow
.importzp tiles
DrawBoardRow:
    ldx #0
@NextTile:
    lda tiles + Tile::powers, X
    and #$0F
    sta tilePower
    cmp #$0F
    beq @IncTile
    jsr GetTilePosOnNonSlideAxis
    lsr
    lsr
    cmp tileRow
    bne @IncTile
    lda tiles + Tile::xpos, X
    sta tileX
    lda tiles + Tile::ypos, X
    sta tileY
    txa
    pha
    jsr DrawTile
    pla
    tax
@IncTile:
    .repeat .sizeof(Tile)
        inx
    .endrepeat
    cpx #(17 * .sizeof(Tile))
    bcs @Done
    jmp @NextTile
@Done:
    rts
    

; Draws a tile on BOARD_BUFFER
; tileX and tileY specify coordinates where to place the tile's top-left corner
; tilePower indicates which tile to draw (0=>1, 1=>2, 2=>4, etc.)
.export DrawTile
DrawTile:
    lda tileY
    asl A
    asl A
    asl A
    asl A
    clc
    adc tileX
    tax             ; X now has starting index in BOARD_BUFFER
    lda tilePower
    asl A
    tay
    lda TileDefinitions+TileDef::color, Y
    sta tileColor
    lda TileDefinitions+TileDef::patternStart, Y
    tay             ; Y now has starting index in CHR
    lda #0
    sta tileRowCounter
DrawTileRow:
    ; Is this row too high or low (outside the board?)
    lda tileY
    clc
    adc tileRowCounter
    cmp #$FD
    bcc :+
    cmp #16
    bcc :+
    iny     ; Increment indices as if we drew the row
    iny
    inx
    inx
    inx
    jmp TileRowDone
:
    lda tileX   ; Is this column outside the board?
    cmp #$FD
    bcs @Col1Done
    cmp #16
    bcs @Col1Done
    tya
    sta BOARD_BUFFER, X
    lda tileColor
    sta COLOR_BUFFER, X
@Col1Done:
    iny
    inx
    lda tileX   ; Is this column outside the board?
    cmp #$FF
    bcs :+
    cmp #15
    bcs @Col2Done
:
    tya
    sta BOARD_BUFFER, x
    lda tileColor
    sta COLOR_BUFFER, X
@Col2Done:
    inx
    lda tileX   ; Is this column outside the board?
    cmp #$FE
    bcs :+
    cmp #14
    bcs @Col3Done
:
    tya
    sta BOARD_BUFFER, x
    lda tileColor
    sta COLOR_BUFFER, X
@Col3Done:
    iny
    inx
    lda tileX
    cmp #13         ; Is this column outside the board?
    bpl TileRowDone
    tya
    sta BOARD_BUFFER, x
    lda tileColor
    sta COLOR_BUFFER, X
TileRowDone:
    lda tileY
    clc
    adc tileRowCounter
    cmp #15     ; If we just drew on the last row of the board, we're done
    bne :+
    jmp TileBGDone
:
    inc tileRowCounter
    lda tileRowCounter
    cmp #4
    bne :+
    jmp TileBGDone     ; When tileRowCounter is 4, we're done with the backgrounds
:
    cmp #2
    bne :+
    dey
    dey
    dey
:
    iny
    ; Increment X by 13 to draw on the next row
    txa
    clc
    adc #13
    tax
    jmp DrawTileRow
TileBGDone:

; If there are any existing sprites under this tile, drop them off the screen
    ldx #0
@CheckNextSprite:
    lda SPRITE_BUFFER, X
    cmp #$FF
    beq @SpriteNoCollision
    lda tileY
    clc
    adc #BOARD_TOP_Y
    asl
    asl
    asl
    sec
    sbc #1
    cmp SPRITE_BUFFER, X
    beq @CheckSpriteX
    clc
    adc #8
    cmp SPRITE_BUFFER, X
    beq @CheckSpriteX
    clc
    adc #8
    cmp SPRITE_BUFFER, X
    beq @CheckSpriteX
    clc
    adc #8
    cmp SPRITE_BUFFER, X
    beq @CheckSpriteX
    jmp @SpriteNoCollision
@CheckSpriteX:
    inx     ; Go to sprite X coord byte
    inx
    inx
    lda tileX
    clc
    adc #BOARD_LEFT_X
    asl
    asl
    asl
    cmp SPRITE_BUFFER, X
    beq @SpriteCollision
    clc
    adc #8
    cmp SPRITE_BUFFER, X
    beq @SpriteCollision
    clc
    adc #8
    cmp SPRITE_BUFFER, X
    beq @SpriteCollision
    clc
    adc #8
    cmp SPRITE_BUFFER, X
    beq @SpriteCollision
    jmp @SpriteNoCollision
@SpriteCollision:
    dex
    dex
    dex
    lda #$FF
    sta SPRITE_BUFFER, X
@SpriteNoCollision:
    txa
    and #%11111100  ; Make sure we're at first byte of sprite (Y-pos)
    tax
    inx             ; Increment to next sprite
    inx
    inx
    inx
    bne @CheckNextSprite

; Do we even need to draw the sprite?
    lda tileX
    cmp #15
    bpl TileSpriteDone
    cmp #$FE
    bmi TileSpriteDone
    lda tileY
    cmp #15
    bpl TileSpriteDone
    cmp #$FE
    bmi TileSpriteDone

    jsr SetUpTileSpriteVars

TileSpriteTopLeft:
    ; Do we draw this corner?
    lda tileY
    cmp #$FF
    bmi :+
    lda tileX
    cmp #$FF
    bmi TileSpriteTopRight
    jsr WriteTileSpriteBytes
    jmp TileSpriteTopRight
:
    inc spriteCHRIndex
    jmp TileSpriteBottomLeft

TileSpriteTopRight:
    ; Increment indices
    inc spriteCHRIndex
    ; Do we draw this corner?
    lda tileX
    cmp #14
    bpl TileSpriteBottomLeft
    lda spriteX
    clc
    adc #8
    sta spriteX
    jsr WriteTileSpriteBytes
    ; Reset X coord
    lda spriteX
    sec
    sbc #8
    sta spriteX

TileSpriteBottomLeft:
    ; Increment indices
    lda spriteCHRIndex
    clc
    adc #$0F
    sta spriteCHRIndex
    lda spriteY
    clc
    adc #8
    sta spriteY
    ; Do we draw this corner?
    lda tileY
    cmp #14
    bpl TileSpriteDone
    lda tileX
    cmp #$FF
    bmi TileSpriteBottomRight
    jsr WriteTileSpriteBytes

TileSpriteBottomRight:
    ; Increment indices
    inc spriteCHRIndex
    lda spriteX
    clc
    adc #8
    sta spriteX
    ; Do we draw this corner?
    lda tileX
    cmp #14
    bpl TileSpriteDone
    jsr WriteTileSpriteBytes

TileSpriteDone:
    rts

SetUpTileSpriteVars:
    ; Y coord
    lda tileY
    clc
    adc #BOARD_TOP_Y
    asl A       ; Multiply by 8 scanlines
    asl A
    asl A
    clc         ; Add padding inside the tile (PPU draws sprite on next line, so 8 - 1 => 7)
    adc #7
    sta spriteY
    ; X coord
    lda tileX
    clc
    adc #BOARD_LEFT_X
    asl A
    asl A
    asl A
    clc
    adc #8
    sta spriteX
    ; CHR Index
    lda tilePower
    asl A
    cmp #$10
    bmi :+
    clc
    adc #$10
:
    sta spriteCHRIndex
    rts

WriteTileSpriteBytes:
    ; First byte - Y pos
    ldx spriteIndex
    lda spriteY
    sta SPRITE_BUFFER, X
    inx
    ; Second byte - CHR index
    lda spriteCHRIndex
    sta SPRITE_BUFFER, X
    inx
    ; Third byte - attributes
    lda tileColor
    bne :+
    lda #$01    ; Second sprite palette
    jmp @StoreThirdByte
:
    lda #$00
@StoreThirdByte:
    sta SPRITE_BUFFER, X
    inx
    ; Fourth byte - X pos
    lda spriteX
    sta SPRITE_BUFFER, X
    inx
    ; Increment sprite index
    stx spriteIndex
    rts

.export PaintAttributeBufferRow
PaintAttributeBufferRow:
    ldx #$00
    stx attrIndex
BeginPaintQuadrant:
    ; Do we need to be looking at this block?
    ldy slideDir
    cpy #DIR_DOWN
    beq :+
    cpy #DIR_UP
    beq :+
    ; horizontal
    lda tileRow
    and #$03
    asl
    asl
    eor attrIndex
    and #%00001100
    beq @ContinuePaint
    inc attrIndex
    inx
    inx
    inx
    inx
    jmp @FinishedAttributeBlock
:
    ; vertical
    lda tileRow
    and #$03
    eor attrIndex
    and #$03
    beq @ContinuePaint
    inc attrIndex
    inx
    inx
    inx
    inx
    jmp @FinishedAttributeBlock
@ContinuePaint:
    ; top left
    lda COLOR_BUFFER, X
    asl A
    asl A
    tay
    txa
    clc
    adc #$11
    tax
    tya
    ora COLOR_BUFFER, X
    tay
    txa
    sec
    sbc #$0F
    tax
    lda TileColorLookups, Y
    sta colorLookup
    and #$30
    lsr A
    lsr A
    lsr A
    lsr A
    ldy attrIndex
    sta ATTR_BUFFER, Y
    jsr IncrementBoardBufferColors
    ; top right
    lda COLOR_BUFFER, X
    asl A
    asl A
    tay
    txa
    clc
    adc #$11
    tax
    tya
    ora COLOR_BUFFER, X
    tay
    txa
    sec
    sbc #$0F
    tax
    lda TileColorLookups, Y
    sta colorLookup
    and #$30
    lsr A
    lsr A
    ldy attrIndex
    ora ATTR_BUFFER, Y
    sta ATTR_BUFFER, Y
    jsr IncrementBoardBufferColors
    ; bottom left
    txa
    clc
    adc #$1C
    tax
    lda COLOR_BUFFER, X
    asl A
    asl A
    tay
    txa
    clc
    adc #$11
    tax
    tya
    ora COLOR_BUFFER, X
    tay
    txa
    sec
    sbc #$0F
    tax
    lda TileColorLookups, Y
    sta colorLookup
    and #$30
    ldy attrIndex
    ora ATTR_BUFFER, Y
    sta ATTR_BUFFER, Y
    jsr IncrementBoardBufferColors
    ; bottom right
    lda COLOR_BUFFER, X
    asl A
    asl A
    tay
    txa
    clc
    adc #$11
    tax
    tya
    ora COLOR_BUFFER, X
    tay
    txa
    sec
    sbc #$0F
    tax
    lda TileColorLookups, Y
    sta colorLookup
    and #$30
    asl A
    asl A
    ldy attrIndex
    ora ATTR_BUFFER, Y
    sta ATTR_BUFFER, Y
    jsr IncrementBoardBufferColors

    inc attrIndex
    txa
    sec
    sbc #$20
    tax
@FinishedAttributeBlock:
    ;Check if we're done
    lda attrIndex
    cmp #$10
    bpl DonePaletteMap
    ; Check if we need to move to next row
    and #$03
    cmp #$00
    bne :+
    txa
    clc
    adc #$30
    tax
:
    jmp BeginPaintQuadrant

DonePaletteMap:
    rts

COLOR_BUMP_INCREMENT = $50  ; $10 is one row in the CHR table

IncrementBoardBufferColors:
    ; Can we skip entirely (colorLookup == 0)?
    lda colorLookup
    and #$03
    bne :+
    rts
:
    ; Stash X and Y
    txa
    pha
    tya
    pha
@TopLeft:
    ; X to top-left corner
    dex
    dex
    ; Get CHR increment factor
    lda colorLookup
    and #$02
    beq @TopRight
    ; Add to existing CHR index
    lda BOARD_BUFFER, X
    clc
    adc #COLOR_BUMP_INCREMENT
    sta BOARD_BUFFER, X
@TopRight:
    inx
    ; Get CHR increment factor
    lda colorLookup
    ldy slideDir
    cpy #DIR_LEFT
    beq :+
    cpy #DIR_RIGHT
    beq :+
    and #$02
    jmp :++
:
    and #$01
:
    beq @BottomLeft
    ; Add to existing CHR index
    lda BOARD_BUFFER, X
    clc
    adc #COLOR_BUMP_INCREMENT
    sta BOARD_BUFFER, X
@BottomLeft:
    ; Move down a row in the board buffer
    txa
    clc
    adc #$0F
    tax
    lda colorLookup
    ldy slideDir
    cpy #DIR_LEFT
    beq :+
    cpy #DIR_RIGHT
    beq :+
    and #$01
    jmp :++
:
    and #$02
:
    beq @BottomRight
    lda BOARD_BUFFER, X
    clc
    adc #COLOR_BUMP_INCREMENT
    sta BOARD_BUFFER, X
@BottomRight:
    inx
    lda colorLookup
    and #$01
    beq @Done
    lda BOARD_BUFFER, X
    clc
    adc #COLOR_BUMP_INCREMENT
    sta BOARD_BUFFER, X
@Done:
    ; Restore Y and X
    pla
    tay
    pla
    tax
    ; Return
    rts
