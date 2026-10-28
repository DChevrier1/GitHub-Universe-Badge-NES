.include "defs.s"

.segment "ZEROPAGE"
blitSource:     .res 2  ; Pointer to memory location to blit from
.export blitSource

.segment "CODE"

.export Blit256, Blit224
Blit256:
    jsr Blit32
Blit224:
    jsr Blit32
    jsr Blit32
    jsr Blit32
    jsr Blit32
    jsr Blit32
    jsr Blit32
    jsr Blit32
    rts

.export Blit32
Blit32:
    jsr Blit16
    jsr Blit16
    rts

.export Blit16
Blit16:
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    lda (blitSource), Y
    sta PPU_DATA
    iny
    rts

.export BlitCol16
BlitCol16:
    lda BOARD_BUFFER + $00, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $10, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $20, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $30, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $40, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $50, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $60, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $70, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $80, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $90, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $A0, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $B0, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $C0, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $D0, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $E0, Y
    sta PPU_DATA
    lda BOARD_BUFFER + $F0, Y
    sta PPU_DATA
    rts
