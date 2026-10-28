.include "defs.s"

.segment "ZEROPAGE"

tiles: .res (17 * .sizeof(Tile))
tileIndex1: .res 1
tileIndex2: .res 1
tileIndex3: .res 1
tileIndex4: .res 1
tileRow: .res 1
slideDir: .res 1        ; See DIR_* enums in defs.s
currentPower: .res 1    ; temp var used by CalculateTileTransitions
.export tiles, slideDir, tileRow
.exportzp tileIndex1, tileIndex2, tileIndex3, tileIndex4

; Used by AddTile routine (and also DrawTile)
tileX:          .res 1  ; X coordinate in board space where to add/draw the tile (top left corner)
tileY:          .res 1  ; Y coordinate in board space where to add/draw the tile (top left corner)
tilePower:      .res 1  ; Which number tile to draw (0=>1, 1=>2, 2=>4, 3=>8, etc.)
tileVelocity:   .res 1  ; Velocity of new tile to be added
.export tileX, tileY, tilePower, tileVelocity

.segment "CODE"

; WipeTiles
; Clears all the tiles on the board by setting their power to $F
WipeTiles:
    lda #$FF
    ldx #0
:
    sta tiles, X
    inx
    cpx #(17 * .sizeof(Tile))
    bne :-
    rts

; CalculateTileTransitions
; Calculates the slide velocities and resulting powers for the four tiles
; indexed by tileIndex[1-4].  Velocities are in board-space units (A velocity of
; -1 will move 1 full tile to the left after 4 frames).  If the tile is
; disappearing because another tile will merge into it, its new power is set to
; $F.
;
; Params:
; tileIndex[1-4] - Indices into the tiles array for up to four tiles in the same
;                  row or column.  Tiles with index $FF will be considered empty
;                  slots.
CalculateTileTransitions:
    ldy #0  ; Y will be velocity counter
    ldx tileIndex1
    cpx #$FF
    bne :+
    ; No tile in slot 1
    jsr @IncrementVelocity
    jmp @Tile2
:
    ; There is a tile in slot 1
    lda #0  ; Tile in slot 1 never moves
    sta tiles + Tile::velocity, X
    ; Find the next tile and see if it will merge with this one
    lda tiles + Tile::powers, X
    and #$0F
    sta currentPower
    ldx tileIndex2
    cpx #$FF
    beq @Tile2Empty
    ; There is a tile in slot 2
    lda tiles + Tile::powers, X
    and #$0F
    cmp currentPower
    bne @Tile2NoMatch
    ; Tile in slot 2 matches
    jsr @IncrementVelocity
    tya
    sta tiles + Tile::velocity, X
    ; Set tile 2 newPower accordingly
    jsr SetTilePowerIncrease
    ; Mark tile 1 for removal
    ldx tileIndex1
    jsr SetTileDisappears
    jmp @Tile3
@Tile2NoMatch:
    ; Tile in slot 2 is not a match
    tya
    sta tiles + Tile::velocity, X
    jsr SetTilePowerConstant
    ldx tileIndex1
    jsr SetTilePowerConstant
    jmp @Tile2
@Tile2Empty:
    jsr @IncrementVelocity
    ldx tileIndex3
    cpx #$FF
    beq @Tile3Empty
    ; There is a tile in slot 3
    lda tiles + Tile::powers, X
    and #$0F
    cmp currentPower
    bne @Tile3NoMatch
    ; Tile in slot 3 matches
    jsr @IncrementVelocity
    tya
    sta tiles + Tile::velocity, X
    ; Set its newPower accordingly
    jsr SetTilePowerIncrease
    ldx tileIndex1
    jsr SetTileDisappears
    jmp @Tile4
@Tile3NoMatch:
    ; Tile in slot 3 is not a match
    tya
    sta tiles + Tile::velocity, X
    jsr SetTilePowerConstant
    ldx tileIndex1
    jsr SetTilePowerConstant
    jmp @Tile3
@Tile3Empty:
    jsr @IncrementVelocity
    ldx tileIndex4
    cpx #$FF
    bne :+
    ldx tileIndex1
    jsr SetTilePowerConstant
    jmp @Done
:
    ; There is a tile in slot 4
    lda tiles + Tile::powers, X
    and #$0F
    cmp currentPower
    bne @Tile4NoMatch
    ; Tile in slot 4 matches
    jsr @IncrementVelocity
    tya
    sta tiles + Tile::velocity, X
    ; Set its newPower accordingly
    jsr SetTilePowerIncrease
    ldx tileIndex1
    jsr SetTileDisappears
    jmp @Done
@Tile4NoMatch:
    ; Tile in slot 4 is not a match
    tya
    sta tiles + Tile::velocity, X
    jsr SetTilePowerConstant
    ldx tileIndex1
    jsr SetTilePowerConstant
    jmp @Done
@Tile2:
    ldx tileIndex2
    cpx #$FF
    bne :+
    ; No tile in slot 2
    jsr @IncrementVelocity
    jmp @Tile3
:
    ; There is a tile in slot 2
    tya
    sta tiles + Tile::velocity, X
    ; Find the next tile and see if it will merge with this one
    lda tiles + Tile::powers, X
    and #$0F
    sta currentPower
    ldx tileIndex3
    cpx #$FF
    beq @Tile3Empty2
    ; There is a tile in slot 3
    lda tiles + Tile::powers, X
    and #$0F
    cmp currentPower
    bne @Tile3NoMatch2
    ; Tile in slot 3 matches
    jsr @IncrementVelocity
    tya
    sta tiles + Tile::velocity, X
    ; Set tile 3 newPower accordingly
    jsr SetTilePowerIncrease
    ; Mark tile 2 for removal
    ldx tileIndex2
    jsr SetTileDisappears
    jmp @Tile4
@Tile3NoMatch2:
    ; Tile in slot 3 is not a match
    tya
    sta tiles + Tile::velocity, X
    jsr SetTilePowerConstant
    ldx tileIndex2
    jsr SetTilePowerConstant
    jmp @Tile3
@Tile3Empty2:
    jsr @IncrementVelocity
    ldx tileIndex4
    cpx #$FF
    bne :+
    ldx tileIndex2
    jsr SetTilePowerConstant
    jmp @Done
:
    ; There is a tile in slot 4
    lda tiles + Tile::powers, X
    and #$0F
    cmp currentPower
    bne @Tile4NoMatch2
    ; Tile in slot 4 matches
    jsr @IncrementVelocity
    tya
    sta tiles + Tile::velocity, X
    ; Set its newPower accordingly
    jsr SetTilePowerIncrease
    ldx tileIndex2
    jsr SetTileDisappears
    jmp @Done
@Tile4NoMatch2:
    ; Tile in slot 4 is not a match
    tya
    sta tiles + Tile::velocity, X
    jsr SetTilePowerConstant
    ldx tileIndex2
    jsr SetTilePowerConstant
    jmp @Done
@Tile3:
    ldx tileIndex3
    cpx #$FF
    bne :+
    ; No tile in slot 3
    jsr @IncrementVelocity
    jmp @Tile4
:
    ; There is a tile in slot 3
    tya
    sta tiles + Tile::velocity, X
    ; Find the next tile and see if it will merge with this one
    lda tiles + Tile::powers, X
    and #$0F
    sta currentPower
    ldx tileIndex4
    cpx #$FF
    bne :+
    ldx tileIndex3
    jsr SetTilePowerConstant
    jmp @Done
:
    ; There is a tile in slot 4
    lda tiles + Tile::powers, X
    and #$0F
    cmp currentPower
    bne @Tile4NoMatch3
    ; Tile in slot 4 matches
    jsr @IncrementVelocity
    tya
    sta tiles + Tile::velocity, X
    ; Set tile 4 newPower accordingly
    jsr SetTilePowerIncrease
    ; Mark tile 3 for removal
    ldx tileIndex3
    jsr SetTileDisappears
    jmp @Done
@Tile4NoMatch3:
    ; Tile in slot 4 is not a match
    tya
    sta tiles + Tile::velocity, X
    jsr SetTilePowerConstant
    ldx tileIndex3
    jsr SetTilePowerConstant
    jmp @Done
@Tile4:
    ldx tileIndex4
    cpx #$FF
    beq @Done
    tya
    sta tiles + Tile::velocity, X
    jsr SetTilePowerConstant
@Done:
    rts
@IncrementVelocity:
    lda slideDir
    cmp #DIR_LEFT
    beq :+
    cmp #DIR_UP
    beq :+
    iny
    rts
:
    dey
    rts

; SetTilePowerIncrease
; Sets a tile's new power (high nibble) to one greater than its current power
; (low nibble).
;
; Params:
; X - index into tiles array
SetTilePowerIncrease:
    lda tiles + Tile::powers, X
    clc
    adc #1
    asl
    asl
    asl
    asl
    ora tiles + Tile::powers, X
    sta tiles + Tile::powers, X
    rts

; SetTilePowerConstant
; Sets a tile's new power (high nibble) to the same as its current power (low
; nibble).
;
; Params:
; X - index into tiles array
SetTilePowerConstant:
    lda tiles + Tile::powers, X
    asl
    asl
    asl
    asl
    ora tiles + Tile::powers, X
    sta tiles + Tile::powers, X
    rts

; SetTileDisappears
; Sets a tile's new power (high nibble) to $F to indicate this tile will
; disappear from the board.
;
; Params:
; X - index into tiles array
SetTileDisappears:
    lda #$F0
    ora tiles + Tile::powers, X
    sta tiles + Tile::powers, X
    rts

; IterateTileRowSlide
; Updates the position of all tiles in a given row or column based on their set
; velocities and slide direction.
;
; Params:
; tileRow - which row or column to update in board space (0-3)
; slideDir - whether to look based on row or col
IterateTileRowSlide:
    ldx #0
@NextTile:
    lda tiles + Tile::powers, X
    and #$0F
    cmp #$0F
    beq @IncTile
    jsr GetTilePosOnNonSlideAxis
    lsr
    lsr
    cmp tileRow
    bne @IncTile
    jsr IterateTileSlide
@IncTile:
    .repeat .sizeof(Tile)
        inx
    .endrepeat
    cpx #.sizeof(tiles)
    bcs @Done
    jmp @NextTile
@Done:
    rts

; IterateTileSlide
; Updates the position of a tile based on its velocity and the current slide
; direction. 
;
; Params:
; X - Index into tiles array
; slideDir - Determines whether to slide along the X or Y axis
IterateTileSlide:
    lda slideDir
    cmp #DIR_UP
    beq @IterateVertical
    cmp #DIR_DOWN
    beq @IterateVertical
@IterateHorizontal:
    lda tiles + Tile::xpos, X
    clc
    adc tiles + Tile::velocity, X
    sta tiles + Tile::xpos, X
    rts
@IterateVertical:
    lda tiles + Tile::ypos, X
    clc
    adc tiles + Tile::velocity, X
    sta tiles + Tile::ypos, X
    rts

; FindTileRow
; Locates up to four tiles in a given row or column (tileRow) and assigns their
; addresses in order to tileIndex1-4. The order is determined by the current
; slide direction (slideDir), where the tiles are always sliding from index 4
; toward index 1.  For instance, if slideDir is DIR_DOWN, then tileIndex1 will
; refer to the tile at the bottom of the board (if any), and tileIndex4 will
; refer to the tile at the top of the board.  If there is no tile in a slot, the
; index value will be $FF.  Only tiles in true board board positions 0, 4, 8,
; and 12 will be found, not intermediate permissions such as 1 or 13.
;
; Params:
; slideDir - Sets whether to search by row or column, and the output order of
;            the tileIndex values.  (See DIR_* enum)
; tileRow - Which row or column to find tiles in (0-3)
FindTileRow:
    ; Clear tileIndex vars
    lda #$FF
    sta tileIndex1
    sta tileIndex2
    sta tileIndex3
    sta tileIndex4
    ldx #0  ; X is index into tiles array
@StartTileCheck:
    jsr GetTilePosOnNonSlideAxis
    tay
    and #$03        ; Must be a multiple of 4
    bne @NextTile
    tya
    lsr
    lsr
    cmp tileRow
    bne @NextTile
    jsr GetTilePosOnSlideAxis
    cmp #0
    bne :+
    stx tileIndex1
    jmp @NextTile
:
    cmp #4
    bne :+
    stx tileIndex2
    jmp @NextTile
:
    cmp #8
    bne :+
    stx tileIndex3
    jmp @NextTile
:
    cmp #12
    bne @NextTile
    stx tileIndex4
    jmp @NextTile
@NextTile:
.repeat .sizeof(Tile)
    inx
.endrepeat
    cpx #(.sizeof(Tile) * 17)
    bne @StartTileCheck
    ; Reverse the pointer order if direction is right or down
    lda slideDir
    cmp #DIR_LEFT
    beq :+
    cmp #DIR_UP
    beq :+
    ldx tileIndex1
    lda tileIndex4
    stx tileIndex4
    sta tileIndex1
    ldx tileIndex2
    lda tileIndex3
    stx tileIndex3
    sta tileIndex2
:
    rts

; GetTilePosOnSlideAxis
; Retrieves the position coordinate of a given tile along the current sliding
; axis.
;
; Params:
; X - index into tiles array
; slideDir - determines the slide axis
;
; Returns:
; A - the tile's coordinate in board-space on the sliding axis
GetTilePosOnSlideAxis:
    lda slideDir
    cmp #DIR_UP
    beq :+
    cmp #DIR_DOWN
    beq :+
    lda tiles + Tile::xpos, X
    jmp :++
:
    lda tiles + Tile::ypos, X
:
    rts

; GetTilePosOnNonSlideAxis
; Retrieves the position coordinate of a given tile along the opposite axis of
; the current sliding axis.
;
; Params:
; X - index into tiles array
; slideDir - determines the slide axis
;
; Returns:
; A - the tile's coordinate in board-space on the non-sliding axis
GetTilePosOnNonSlideAxis:
    lda slideDir
    cmp #DIR_UP
    beq :+
    cmp #DIR_DOWN
    beq :+
    lda tiles + Tile::ypos, X
    jmp :++
:
    lda tiles + Tile::xpos, X
:
    rts

ResetTileVelocities:
    ldx #0
    lda #0
@NextTile:
    sta tiles + Tile::velocity, X
    .repeat .sizeof(Tile)
        inx
    .endrepeat
    cpx #.sizeof(tiles)
    bcs @Done
    jmp @NextTile
@Done:
    rts

; Copy the new tile power (high nibble) into the current tile power slot (low nibble)
.export UpdateTilePowers
UpdateTilePowers:
    ldx #0
@NextTile:
    lda tiles + Tile::powers, X
    and #$F0
    cmp #$F0
    bne @RegularTile
@DisappearingTile:
    lda #$FF
    sta tiles + Tile::powers, X
    sta tiles + Tile::xpos, X
    sta tiles + Tile::ypos, X
    jmp @FinishedUpdate
@RegularTile:
    lsr
    lsr
    lsr
    lsr
    sta tiles + Tile::powers, X
@FinishedUpdate:
    .repeat .sizeof(Tile)
        inx
    .endrepeat
    cpx #.sizeof(tiles)
    bcs @Done
    jmp @NextTile
@Done:
    rts

; GetEmptyTileIndex
; Finds the first unused tile slot in the `tiles` array and sets the X register
; to that index.  If all the tile slots are occupied, sets X to $FF.
GetEmptyTileIndex:
    ldx #0
@NextTile:
    lda tiles + Tile::powers, X
    cmp #$FF
    bne @NotEmpty
    rts
@NotEmpty:
    .repeat .sizeof(Tile)
        inx
    .endrepeat
    cpx #.sizeof(tiles)
    bcs @NoneFound
    jmp @NextTile
@NoneFound:
    ldx #$FF
    rts

; AddTile
; Adds the specified tile to the board in the first empty slot.  If all slots in
; `tiles` are full, does nothing.
;
; Params:
; tileX - the X position of the new tile, in board space (top left corner)
; tileY - the Y position of the new tile, in board space (top left corner)
; tilePower - the power of the new tile (0 => 1, 1 => 2, 2 => 4, etc.)
; tileVelocity - the velocity of the new tile
.export AddTile
AddTile:
    jsr GetEmptyTileIndex
    cpx #$FF
    bne :+
    rts
:
    lda tileX
    sta tiles + Tile::xpos, x
    lda tileY
    sta tiles + Tile::ypos, x
    lda tileVelocity
    sta tiles + Tile::velocity, x
    lda tilePower
    asl
    asl
    asl
    asl
    ora tilePower
    sta tiles + Tile::powers, x
    rts

.ifdef TEST
.export SetTileDisappears, SetTilePowerConstant, SetTilePowerIncrease
.export CalculateTileTransitions, IterateTileSlide
.endif

.export WipeTiles
.export GetTilePosOnNonSlideAxis, GetTilePosOnSlideAxis
.export FindTileRow, CalculateTileTransitions, IterateTileRowSlide, ResetTileVelocities