.import _printf, exit
.importzp sp

.segment "DATA"
tempA: .res 1
tempX: .res 1
tempY: .res 1
testName: .res 128, 0
testFileName: .res 80, 0

.segment "CODE"

PushStack: 
    sta tempA
    stx tempX
    sty tempY
    rts

PopStack:
    lda tempA
    ldx tempX
    ldy tempY
    rts

; printf macro
; Outputs text to the console and adds a newline.  Accepts a format string and
; up to 10 additional arguments, which function similarly to C-style printf.
;
; Non-immediate arguments are assumed to be the address of a single byte.  To
; reference address pairs containing words, use printfw.
;
; Examples:
;   printf "Hello, world!"
;   printf "Here is an immediate byte: $%02x", #$34
;   printf "Here is an immediate word: %d", #1234
;   printf "Here is the byte at address $00: $%02x", $00
;   printf "Here is the byte at label myaddr: $%02x", myaddr
;   printf "Here is the word at address $00: $%02x%02x", $01, $00
;   printfw "Here is the word at address $00: %d", $00
;   printfw "Here is the word at label testword: %d", testword
;   printf "Here is the string stored at mystring: %s", #mystring
.macro printf format, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10
    .local fmt, SkipData
    jsr PushStack
    jmp SkipData
fmt: .byte format
    .byte $0A   ; newline
    .byte $00
SkipData:
    ldy #0
    dec sp
    lda #>fmt
    sta (sp), y
    dec sp
    lda #<fmt
    sta (sp), y
    ldx #2  ; X is counter of number of bytes used by format and all the args
    pushArg arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10
    txa
    tay
    jsr _printf
    jsr PopStack
.endmacro

; printfw
; Same as printf (see above), but assumes address arguments store words instead
; of bytes.
.macro printfw format, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10
    .local fmt, SkipData
    jsr PushStack
    jmp SkipData
fmt: .byte format
    .byte $0A   ; newline
    .byte $00
SkipData:
    ldy #0
    dec sp
    lda #>fmt
    sta (sp), y
    dec sp
    lda #<fmt
    sta (sp), y
    ldx #2  ; X is counter of number of bytes used by format and all the args
    pushArgw arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10
    txa
    tay
    jsr _printf
    jsr PopStack
.endmacro

; Sub-macro used by printf
.macro pushArg arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10
    .ifblank arg1
        .exitmacro
    .endif
    .if (.match (.left (1, {arg1}), #))
        ; Immediate
        dec sp
        lda #>(.right (.tcount ({arg1})-1, {arg1}))
        sta (sp), y
        dec sp
        lda #<(.right (.tcount ({arg1})-1, {arg1}))
        sta (sp), y
    .else
        ; Address
        dec sp
        lda #00
        sta (sp), y
        dec sp
        lda arg1
        sta (sp), y
    .endif
    inx
    inx
    pushArg arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10
.endmacro

; Word-size version of pushArg, used by printfw
.macro pushArgw arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10
    .ifblank arg1
        .exitmacro
    .endif
    .if .match(.left(1, {arg1}), #)
        ; Immediate
        dec sp
        lda #>(.right (.tcount ({arg1})-1, {arg1}))
        sta (sp), y
        dec sp
        lda #<(.right (.tcount ({arg1})-1, {arg1}))
        sta (sp), y
    .else
        ; General address
        dec sp
        lda 1+(arg1)
        sta (sp), y
        dec sp
        lda arg1
        sta (sp), y
    .endif
    inx
    inx
    pushArgw arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10
.endmacro

.macro setTestFileName name
    .local str, Done, NextChar
    jsr PushStack
    ldx #0
    jmp NextChar
str: .asciiz name
NextChar:
    lda str, x
    sta testFileName, x
    beq Done
    inx
    jmp NextChar
Done:
    jsr PopStack
    printf "Running tests from file %s", #str
.endmacro

.macro setTestName name
    .local str, Done, NextChar
    jsr PushStack
    ldx #0
    jmp NextChar
str: .asciiz .string(name)
NextChar:
    lda str, x
    sta testName, x
    beq Done
    inx
    jmp NextChar
Done:
    jsr PopStack
    printf "  - Running test %s", #str
.endmacro

.macro expectA value, string
    .local ExpectSucceeded, ExpectFailed
    cmp value
    bne ExpectFailed
    jmp ExpectSucceeded
ExpectFailed:
    sta tempA
    printf "Test '%s' in file '%s' failed!", #testName, #testFileName
    printf .concat("Expected ", string, " (A register) to be $%02x, but got $%02x"), value, tempA
    lda #1
    jmp exit
ExpectSucceeded:
.endmacro

.macro expectX value, string
    .local ExpectSucceeded, ExpectFailed
    cpx value
    bne ExpectFailed
    jmp ExpectSucceeded
ExpectFailed:
    stx tempX
    printf "Test '%s' in file '%s' failed!", #testName, #testFileName
    printf .concat("Expected ", string, " (X register) to be $%02x, but got $%02x"), value, tempX
    lda #1
    jmp exit
ExpectSucceeded:
.endmacro

.macro expectY value, string
    .local ExpectSucceeded, ExpectFailed
    cpy value
    bne ExpectFailed
    jmp ExpectSucceeded
ExpectFailed:
    sty tempY
    printf "Test '%s' in file '%s' failed!", #testName, #testFileName
    printf .concat("Expected ", string, " (Y register) to be $%02x, but got $%02x"), value, tempY
    lda #1
    jmp exit
ExpectSucceeded:
.endmacro

.macro expectByte addr, value, string
    .local ExpectSucceeded, ExpectFailed
    jsr PushStack
    lda addr
    cmp value
    bne ExpectFailed
    jmp ExpectSucceeded
ExpectFailed:
    sta tempA
    printf "Test '%s' in file '%s' failed!", #testName, #testFileName
    printf .concat("Expected '", string, "' (byte at address $%04x) to be $%02x, but got $%02x"), #addr, value, addr
    lda #1
    jmp exit
ExpectSucceeded:
    jsr PopStack
.endmacro

.macro expectWord addr, value, string
    .local ExpectSucceeded, ExpectFailed
    jsr PushStack
    lda addr
    cmp #.lobyte(.right(.tcount(value)-1, value))
    bne ExpectFailed
    lda addr+1
    cmp #.hibyte(.right(.tcount(value)-1, value))
    bne ExpectFailed
    jmp ExpectSucceeded
ExpectFailed:
    printf "Test '%s' in file '%s' failed!", #testName, #testFileName
    printfw .concat("Expected '", string, "' (word at address $%04x) to be $%04x, but got $%04x"), #addr, value, addr
    lda #1
    jmp exit
ExpectSucceeded:
    jsr PopStack
.endmacro
