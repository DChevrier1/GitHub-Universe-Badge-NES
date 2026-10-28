JOYPAD1 = $4016
JOYPAD2 = $4017

.zeropage

buttons1: .res 1
buttons2: .res 1
last_frame_buttons1: .res 1
newButtons1: .res 1
.export newButtons1

.code

.export ReadJoy
ReadJoy:
    lda #$01
    sta JOYPAD1
    sta buttons1  ; doubles as a ring counter
    lsr a         ; now A is 0
    sta JOYPAD1
loop:
    lda JOYPAD1
    and #%00000001  ; ignore bits other than controller
    cmp #$01        ; Set carry if and only if nonzero
    rol buttons1    ; Carry -> bit 0; bit 7 -> Carry
    ; lda JOYPAD2     ; Repeat
    ; and #%00000001
    ; cmp #$01
    ; rol buttons2    ; Carry -> bit 0; bit 7 -> Carry
    bcc loop

    ; Check for new presses
    lda last_frame_buttons1
    eor #%11111111
    and buttons1
    sta newButtons1

    lda buttons1
    sta last_frame_buttons1

    rts
