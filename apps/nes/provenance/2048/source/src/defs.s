; definitions
PPU_CTRL      = $2000
PPU_MASK      = $2001
PPU_STATUS    = $2002
PPU_SCROLL    = $2005
PPU_ADDR      = $2006
PPU_DATA      = $2007
OAM_ADDRESS   = $2003
OAM_DMA       = $4014
APU_DMC       = $4010
APU_STATUS    = $4015
APU_FRAME_CTR = $4017

SPRITE_BUFFER = $0200   ; Staging area for sprite data
BOARD_BUFFER  = $0300   ; Staging area for main board nametable
COLOR_BUFFER  = $0400   ; Staging area for tile colors, for attribute table calc
ATTR_BUFFER   = $0500   ; Staging area for board attribute table

BOARD_LEFT_X  = 4       ; X coordinate of board left edge in nametable space (must multiple of 4 for attributes to map properly)
BOARD_TOP_Y   = 8       ; Y coordinate of board top edge in nametable space (must multiple of 4 for attributes to map properly)

BUTTON_A      = 1 << 7
BUTTON_B      = 1 << 6
BUTTON_SELECT = 1 << 5
BUTTON_START  = 1 << 4
BUTTON_UP     = 1 << 3
BUTTON_DOWN   = 1 << 2
BUTTON_LEFT   = 1 << 1
BUTTON_RIGHT  = 1 << 0

.enum
    BLIT_NONE
    BLIT_HORIZONTAL
    BLIT_VERTICAL
.endenum

.enum
    DIR_UP
    DIR_DOWN
    DIR_LEFT
    DIR_RIGHT
.endenum

.struct Tile
    powers      .byte   ; Low nibble = current power; High nibble = "new" power after slide completes
    xpos        .byte   ; x position in board space, -3 to 15
    ypos        .byte   ; y position in board space, -3 to 15
    velocity    .byte   ; per-frame velocity along the current slide axis
.endstruct
