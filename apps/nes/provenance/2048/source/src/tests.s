.importzp tileX, tileY, tilePower
.import DrawTile, PaintAttributeBuffer

.segment "CODE"

.export TestDrawTileShapes
TestDrawTileShapes:
    lda #$00
    sta tilePower
    sta tileX
    sta tileY
    jsr DrawTile
@NextTile:
    lda tileX
    clc
    adc #$04
    cmp #$10
    bcc :+
    lda tileY
    clc
    adc #$04
    sta tileY
    lda #$00
:
    sta tileX
    lda tilePower
    clc
    adc #$01
    sta tilePower
    jsr DrawTile
    lda tilePower
    cmp #13
    bne @NextTile
    rts

.export TestDrawEdgeTiles
TestDrawEdgeTiles:
    lda #1
    sta tilePower
    lda #0
    sta tileX
    lda #$FD
    sta tileY
    jsr DrawTile

    lda #4
    sta tileX
    lda #$FE
    sta tileY
    jsr DrawTile

    lda #8
    sta tileX
    lda #$FF
    sta tileY
    jsr DrawTile

    lda #15
    sta tileX
    lda #0
    sta tileY
    jsr DrawTile

    lda #14
    sta tileX
    lda #4
    sta tileY
    jsr DrawTile

    lda #13
    sta tileX
    lda #8
    sta tileY
    jsr DrawTile

    lda #12
    sta tileX
    lda #15
    sta tileY
    jsr DrawTile

    lda #8
    sta tileX
    lda #14
    sta tileY
    jsr DrawTile

    lda #4
    sta tileX
    lda #13
    sta tileY
    jsr DrawTile

    lda #$FD
    sta tileX
    lda #12
    sta tileY
    jsr DrawTile

    lda #$FE
    sta tileX
    lda #8
    sta tileY
    jsr DrawTile

    lda #$FF
    sta tileX
    lda #4
    sta tileY
    jsr DrawTile

    rts

.export TestColorMix1
TestColorMix1:
    lda #0
    sta tilePower
    sta tileX
    sta tileY
    jsr DrawTile
    inc tilePower
    inc tileX
    jsr DrawTile
    inc tilePower
    inc tileX
    jsr DrawTile
    inc tilePower
    inc tileX
    jsr DrawTile

    lda #0
    sta tileX
    lda #4
    sta tileY
    inc tilePower
    jsr DrawTile
    inc tilePower
    inc tileX
    jsr DrawTile
    inc tilePower
    inc tileX
    jsr DrawTile
    inc tilePower
    inc tileX
    jsr DrawTile

    lda #0
    sta tileX
    lda #8
    sta tileY
    inc tilePower
    jsr DrawTile
    inc tilePower
    inc tileX
    jsr DrawTile
    inc tilePower
    inc tileX
    jsr DrawTile
    inc tilePower
    inc tileX
    jsr DrawTile

    lda #0
    sta tileX
    lda #12
    sta tileY
    inc tilePower
    jsr DrawTile
    inc tilePower
    inc tileX
    jsr DrawTile

    rts
