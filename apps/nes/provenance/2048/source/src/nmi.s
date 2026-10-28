.include "defs.s"

.import Blit16, BlitCol16

.segment "ZEROPAGE"
blitStartPPU:   .res 2  ; Counter address used in blitting to PPU
blitMode:       .res 1  ; see BLIT_* enum in defs.s
blitCounter:    .res 1  ; Which row/col are we blitting?
nmiDone:        .res 1  ; Set to true when NMI routine finishes
temp:           .res 1  ; General-purpose temporary variable
.export blitMode, blitCounter, nmiDone

.import blitSource

.segment "CODE"

.export nmi
nmi:
; Save CPU state
    pha
    txa
    pha
    tya
    pha

; Sprite load
    ; Tell PPU to DMA copy sprite data from 0x0200
    lda #$02
    sta OAM_DMA
    nop

    lda blitMode
    cmp #BLIT_HORIZONTAL
    bne :+
    jmp BlitHorizontal
:
    cmp #BLIT_VERTICAL
    beq BlitVertical
    jmp DoneBlitting

BlitVertical:
    ; Get low byte of PPU address
    lda #BOARD_TOP_Y
    asl
    asl
    asl
    asl
    asl
    clc
    adc #BOARD_LEFT_X
    sta temp
    lda blitCounter
    and #$03
    asl A
    asl A
    clc
    adc temp
    sta blitStartPPU
    ; Get high byte of PPU address
    lda #BOARD_TOP_Y
    lsr     ; BOARD_TOP_Y * 32 / 256 == BOARD_TOP_Y / 8
    lsr
    lsr
    clc    
    adc #$20    ; PPU start
    sta blitStartPPU+1

    ; Y will be index into BOARD_BUFFER
    lda blitCounter
    and #$03
    asl
    asl
    tay

    ; Set write mode to vertical
    lda #%10001100
    sta PPU_CTRL

    ; Set starting target address for writing first column
    bit PPU_STATUS
    lda blitStartPPU + 1
    sta PPU_ADDR
    lda blitStartPPU
    sta PPU_ADDR
    ; Write first column
    jsr BlitCol16
.repeat 3
    ; Set starting target address for writing next column
    inc blitStartPPU
    bit PPU_STATUS
    lda blitStartPPU + 1
    sta PPU_ADDR
    lda blitStartPPU
    sta PPU_ADDR
    iny
    ; Write next column
    jsr BlitCol16
.endrepeat
; Blit ATTR table Vertical
    ; Set write mode back to horizontal
    lda #%10001000
    sta PPU_CTRL
    ; (BOARD_TOP_Y * 2) + (BOARD_LEFT_X / 4) + (blitCounter % 3)
    ; ( (BOARD_TOP_Y * 8) + BOARD_LEFT_X + ((blitCounter % 3) * 4) ) / 4
    ; ( ((blitCounter % 3) * 4) + (BOARD_TOP_Y * 8) + BOARD_LEFT_X ) / 4
    ; ( (((blitCounter % 3) + (BOARD_TOP_Y * 2)) * 4) + BOARD_LEFT_X ) / 4
    ; ( (((blitCounter % 3) + BOARD_TOP_Y + BOARD_TOP_Y) * 4) + BOARD_LEFT_X ) / 4
    lda blitCounter
    and #$03
    clc
    adc #BOARD_TOP_Y
    clc
    adc #BOARD_TOP_Y
    asl
    asl
    clc
    adc #BOARD_LEFT_X
    lsr
    lsr
    clc
    adc #$C0
    tay
    lda #$23
    bit PPU_STATUS
    sta PPU_ADDR
    sty PPU_ADDR
    lda blitCounter
    and #$03
    tax
    lda ATTR_BUFFER, X
    sta PPU_DATA
    .repeat 3
        tya
        clc
        adc #8
        tay
        lda #$23
        bit PPU_STATUS
        sta PPU_ADDR
        sty PPU_ADDR
        txa
        clc
        adc #4
        tax
        lda ATTR_BUFFER, X
        sta PPU_DATA
    .endrepeat
    jmp DoneBlitting

BlitHorizontal:
    lda blitCounter
    and #$03
    asl A
    asl A
    clc
    adc #BOARD_TOP_Y
    tax
    lsr A
    lsr A
    lsr A
    clc
    adc #$20
    tay         ; Y is high byte of PPU write address
    txa
    asl A
    asl A
    asl A
    asl A
    asl A
    clc
    adc #BOARD_LEFT_X
    sta blitStartPPU
    sty blitStartPPU+1

    lda blitCounter
    and #$03
    asl A
    asl A
    asl A
    asl A
    asl A
    asl A
    tay     ; Y is index into BOARD_BUFFER

    lda #<BOARD_BUFFER
    sta blitSource
    lda #>BOARD_BUFFER
    sta blitSource+1

    ; Set write mode to horizontal
    lda #%10001000
    sta PPU_CTRL

    ; write first row
    bit PPU_STATUS
    lda blitStartPPU + 1
    sta PPU_ADDR
    lda blitStartPPU
    sta PPU_ADDR
    jsr Blit16

    ; write second row
    lda blitStartPPU
    clc
    adc #32
    sta blitStartPPU
    bcc :+
    inc blitStartPPU + 1
:
    bit PPU_STATUS
    lda blitStartPPU + 1
    sta PPU_ADDR
    lda blitStartPPU
    sta PPU_ADDR
    jsr Blit16

    ; write third row
    lda blitStartPPU
    clc
    adc #32
    sta blitStartPPU
    bcc :+
    inc blitStartPPU + 1
:
    bit PPU_STATUS
    lda blitStartPPU + 1
    sta PPU_ADDR
    lda blitStartPPU
    sta PPU_ADDR
    jsr Blit16

    ; write fourth row
    lda blitStartPPU
    clc
    adc #32
    sta blitStartPPU
    bcc :+
    inc blitStartPPU + 1
:
    bit PPU_STATUS
    lda blitStartPPU + 1
    sta PPU_ADDR
    lda blitStartPPU
    sta PPU_ADDR
    jsr Blit16

; Blit ATTR table Horizontal
    lda blitCounter
    and #$03
    asl A
    asl A
    clc
    adc #BOARD_TOP_Y
    asl A
    asl A
    asl A
    clc
    adc #BOARD_LEFT_X
    lsr A
    lsr A
    adc #$C0
    ldy #$23
    bit PPU_STATUS
    sty PPU_ADDR
    sta PPU_ADDR
    lda blitCounter
    and #$03
    asl A
    asl A
    tax
    lda ATTR_BUFFER, X
    inx
    sta PPU_DATA
    lda ATTR_BUFFER, X
    inx
    sta PPU_DATA
    lda ATTR_BUFFER, X
    inx
    sta PPU_DATA
    lda ATTR_BUFFER, X
    inx
    sta PPU_DATA
    jmp DoneBlitting

DoneBlitting:
    inc blitCounter

; Reset PPU scroll to avoid trouble
    lda #$00
    sta $2005
    sta $2005

; Set NMI done flag for main loop
    lda #1
    sta nmiDone

; Restore CPU state
    pla
    tay
    pla
    tax
    pla

; NMI done
    rti

