CLR_BG = $3d    ; Background color
CLR_TA = $37    ; First tile color
CLR_TB = $27    ; Second tile color
CLR_TC = $17    ; Third tile color
CLR_BLANK = $08 ; Blank slot color
CLR_WHITE = $20
CLR_BLACK = $1D
CLR_LIGHTBLUE = $11
CLR_DARKBLUE = $02
CLR_GRAY = $3d

.segment "RODATA"

PaletteData:
    ; Backgrounds
    ; Intent here is for every pair of colors to be available on at least one
    ; palette
    .byte CLR_BG, CLR_LIGHTBLUE, CLR_DARKBLUE, CLR_WHITE
    .byte CLR_BG, CLR_TA, CLR_TB, CLR_WHITE
    .byte CLR_BG, CLR_TA, CLR_TC, CLR_WHITE
    .byte CLR_BG, CLR_TB, CLR_TC, CLR_WHITE
    ; Sprites
    .byte CLR_BG, CLR_WHITE, CLR_GRAY, CLR_BLACK
    .byte CLR_BG, CLR_BLACK, CLR_GRAY, CLR_WHITE
    .byte CLR_BG, CLR_WHITE, CLR_GRAY, CLR_BLACK
    .byte CLR_BG, CLR_WHITE, CLR_GRAY, CLR_BLACK

; See definition of TileDef struct
TileDefinitions:
    ; CHR tile-start, color (0-4 => A-B)
    .byte $00+$00, 0     ; 1
    .byte $00+$00, 1     ; 2
    .byte $00+$50, 2     ; 4
    .byte $10+$00, 0     ; 8
    .byte $10+$00, 1     ; 16
    .byte $10+$50, 2     ; 32
    .byte $20+$00, 0     ; 64
    .byte $20+$00, 1     ; 128
    .byte $20+$50, 2     ; 256
    .byte $30+$00, 0     ; 512
    .byte $30+$00, 1     ; 1024
    .byte $30+$50, 2     ; 2048
    .byte $40+$00, 0     ; 4096
    .byte $40+$00, 1     ; 8192

TileColorLookups:
; Provides palette information for mapping pairs of colors correctly to the
; attribute table.
;
; Index format:
; 7  bit  0
; ---- ----
; xxxx LLRR
; |||| ||++- Color of right (bottom) two squares (0-2 => A-C)
; |||| ++--- Color of left (top) two squares (0-2 => A-C)
; ++++------ Unused
;
; Result format:
; 7  bit  0
; ---- ----
; xxPP xxLR
; |||| |||+- Increment right/bottom CHR index by number of shapes times 16
; |||| ||+-- Increment left/top CHR index by number of shapes times 16
; |||| ++--- Unused
; ||++------ Which palette to use (0-3)
; ++-------- Unused
.byte $10   ; A A
.byte $11   ; A B
.byte $20   ; A C
.byte $FF   ; Unused
.byte $12   ; B A
.byte $13   ; B B
.byte $30   ; B C
.byte $FF   ; Unused
.byte $20   ; C A
.byte $30   ; C B
.byte $20   ; C C

.export TileDefinitions, TileColorLookups, PaletteData