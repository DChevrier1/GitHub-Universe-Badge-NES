.include "../src/defs.s"
.include "helpers.s"

.import WipeTiles, FindTileRow, GetTilePosOnNonSlideAxis, GetTilePosOnSlideAxis
.import SetTileDisappears, SetTilePowerConstant, SetTilePowerIncrease
.import CalculateTileTransitions, IterateTileSlide, IterateTileRowSlide
.importzp tileRow, tiles, slideDir, tileIndex1, tileIndex2, tileIndex3, tileIndex4

.segment "STARTUP"
.export _main
_main:
    setTestFileName "test-board.s"
    jsr WipeTiles
    jsr TestWipeTiles
    jsr TestGetTilePosOnNonSlideAxis
    jsr TestGetTilePosOnSlideAxis
    jsr TestFindTilesEmpty
    jsr TestFindTilesSingle
    jsr TestFindTilesMultiple
    jsr TestFindTilesOrderReversed
    jsr TestFindTilesIgnoreIntermediatePositions
    jsr TestSetTileDisappears
    jsr TestSetTilePowerConstant
    jsr TestSetTilePowerIncrease
    jsr TestCalculateTileTransitionsEmpty
    jsr TestCalculateTileTransitionsSingleFirstTile
    jsr TestCalculateTileTransitionsSingleSlidingTile
    jsr TestCalculateTileTransitionsMultipleSlidingTilesSync
    jsr TestCalculateTileTransitionsMultipleSlidingTilesGap
    jsr TestCalculateTileTransitionsFullSlateNoMerge
    jsr TestCalculateTileTransitionsSimpleMerge
    jsr TestCalculateTileTransitionsSlidingMerge
    jsr TestCalculateTileTransitionsGapMerge
    jsr TestCalculateTileTransitionsDoubleMerge
    jsr TestCalculateTileTransitionsMiddleMerge
    jsr TestCalculateTileTransitionsMegaMerge
    jsr TestCalculateTileTransitionsMergeAndSlide
    jsr TestIterateTileSlides
    jsr TestIterateTileRowSlides
    printf "All tests in '%s' passed!", #testFileName
    lda #0
    jmp exit

.segment "CODE"

.macro setTile slot, xp, yp, pow, vel
    lda #0
    ldx slot
:
    cpx #0
    beq :+
    dex
    clc
    adc #.sizeof(Tile)
    jmp :-
:
    tax
    lda xp
    sta tiles+Tile::xpos, x
    lda yp
    sta tiles+Tile::ypos, x
    .ifblank pow
    .else
        lda pow
        sta tiles+Tile::powers, x
    .endif
    .ifblank vel
    .else
        lda vel
        sta tiles+Tile::velocity, x
    .endif
.endmacro

TestWipeTiles:
    setTestName TestWipeTiles
    jsr WipeTiles
    ldx #0
NextTile:
    lda tiles, X
    expectA #$FF, "tiles+X"
    inx
    cpx #(17 * .sizeof(Tile))
    beq :+
    jmp NextTile
:
    rts

TestFindTilesEmpty:
    setTestName TestFindTilesEmpty
    jsr WipeTiles
    lda #0
    sta tileRow
    lda #DIR_LEFT
    sta slideDir
    jsr FindTileRow
    ldy #0
    lda tileIndex1, y
    expectA #$FF, "tileIndex1"
    lda tileIndex2, y
    expectA #$FF, "tileIndex2"
    lda tileIndex3, y
    expectA #$FF, "tileIndex3"
    lda tileIndex4, y
    expectA #$FF, "tileIndex4"
    rts

TestFindTilesSingle:
    setTestName TestFindTiles
    jsr WipeTiles
    setTile #0, #0, #0, #0
    lda #0
    sta tileRow
    lda #DIR_LEFT
    sta slideDir
    jsr FindTileRow

    lda tileIndex1
    expectA #0, "tileIndex1"
    lda tileIndex2
    expectA #$FF, "tileIndex2"
    lda tileIndex3
    expectA #$FF, "tileIndex3"
    lda tileIndex4
    expectA #$FF, "tileIndex4"

    ldx tileIndex1
    lda tiles+Tile::xpos, x
    expectA #0, "tiles[tileIndex1].x"
    lda tiles+Tile::ypos, x
    expectA #0, "tiles[tileIndex1].y"
    lda tiles+Tile::powers, x
    expectA #0, "tiles[tileIndex1].powers"

    rts

.macro setTileIndexSlot tileIndex, slot
    .local @SetSlot
    lda #slot
    cmp #$FF
    beq @SetSlot
    clc
.repeat (.sizeof(Tile) - 1)
    adc #slot
.endrepeat
@SetSlot:
    sta tileIndex
.endmacro

.macro setSlideDir dir
    lda #dir
    sta slideDir
.endmacro

.macro checkTileTransition tileIndex, pows, vel
    ldx tileIndex
    lda tiles + Tile::powers, X
    expectA pows, .concat("Updated tile ", .string(tileIndex), " powers")
    lda tiles + Tile::velocity, X
    expectA vel, .concat("Updated tile ", .string(tileIndex), " velocity")
.endmacro

TestFindTilesMultiple:
    setTestName TestFindTiles
    jsr WipeTiles
    setTile  #9, #12, #0, #0
    setTile #13, #12, #8, #1
    setTile  #2,  #4, #0, #3
    lda #3  ; => xpos == 12
    sta tileRow
    lda #DIR_UP
    sta slideDir
    jsr FindTileRow

    lda tileIndex1
    expectA #(9*.sizeof(Tile)), "tileIndex1"
    lda tileIndex2
    expectA #$FF, "tileIndex2"
    lda tileIndex3
    expectA #(13*.sizeof(Tile)), "tileIndex3"
    lda tileIndex4
    expectA #$FF, "tileIndex4"

    ldx tileIndex1
    lda tiles+Tile::xpos, x
    expectA #12, "tiles[tileIndex1].x"
    lda tiles+Tile::ypos, x
    expectA #0, "tiles[tileIndex1].y"
    lda tiles+Tile::powers, x
    expectA #0, "tiles[tileIndex1].powers"

    ldx tileIndex3
    lda tiles+Tile::xpos, x
    expectA #12, "tiles[tileIndex1].x"
    lda tiles+Tile::ypos, x
    expectA #8, "tiles[tileIndex1].y"
    lda tiles+Tile::powers, x
    expectA #1, "tiles[tileIndex1].powers"

    rts

TestFindTilesOrderReversed:
    setTestName TestFindTilesOrderReversed
    jsr WipeTiles
    setTile  #9, #12, #0, #0
    setTile #13, #12, #8, #1
    setTile  #2,  #4, #0, #3
    lda #3  ; => xpos == 12
    sta tileRow
    lda #DIR_DOWN
    sta slideDir
    jsr FindTileRow

    lda tileIndex4
    expectA #(9*.sizeof(Tile)), "tileIndex4"
    lda tileIndex3
    expectA #$FF, "tileIndex3"
    lda tileIndex2
    expectA #(13*.sizeof(Tile)), "tileIndex2"
    lda tileIndex1
    expectA #$FF, "tileIndex1"

    ldx tileIndex4
    lda tiles+Tile::xpos, x
    expectA #12, "tiles[tileIndex4].x"
    lda tiles+Tile::ypos, x
    expectA #0, "tiles[tileIndex4].y"
    lda tiles+Tile::powers, x
    expectA #0, "tiles[tileIndex4].powers"

    ldx tileIndex2
    lda tiles+Tile::xpos, x
    expectA #12, "tiles[tileIndex2].x"
    lda tiles+Tile::ypos, x
    expectA #8, "tiles[tileIndex2].y"
    lda tiles+Tile::powers, x
    expectA #1, "tiles[tileIndex2].powers"

    rts

TestFindTilesIgnoreIntermediatePositions:
    setTestName TestFindTilesIgnoreIntermediatePositions
    jsr WipeTiles
    setTile #13,  #0, #4, #0
    setTile  #9,  #1, #4, #1
    setTile  #3,  #2, #4, #2
    setTile  #0,  #3, #4, #3
    setTile #16, #12, #4, #4
    setTile  #8,  #7, #4, #5
    setTile  #2, #17, #4, #6
    setTile #10, #18, #4, #7
    setTile  #5, #19, #4, #8
    lda #1  ; => ypos == 4
    sta tileRow
    lda #DIR_LEFT
    sta slideDir
    jsr FindTileRow

    lda tileIndex1
    expectA #(13*.sizeof(Tile)), "tileIndex1"
    lda tileIndex2
    expectA #$FF, "tileIndex2"
    lda tileIndex3
    expectA #$FF, "tileIndex3"
    lda tileIndex4
    expectA #(16*.sizeof(Tile)), "tileIndex4"

    ldx tileIndex1
    lda tiles+Tile::xpos, x
    expectA #0, "tiles[tileIndex4].x"
    lda tiles+Tile::ypos, x
    expectA #4, "tiles[tileIndex4].y"
    lda tiles+Tile::powers, x
    expectA #0, "tiles[tileIndex4].powers"

    ldx tileIndex4
    lda tiles+Tile::xpos, x
    expectA #12, "tiles[tileIndex2].x"
    lda tiles+Tile::ypos, x
    expectA #4, "tiles[tileIndex2].y"
    lda tiles+Tile::powers, x
    expectA #4, "tiles[tileIndex2].powers"

    rts

TestGetTilePosOnSlideAxis:
    setTestName TestGetTilePosOnSlideAxis
    jsr WipeTiles
    setTile  #9,  #1, #4, #1
    lda #DIR_LEFT
    sta slideDir

    ldx #9*.sizeof(Tile)
    jsr GetTilePosOnSlideAxis
    expectA #1, "A"

    ldx #0*.sizeof(Tile)
    jsr GetTilePosOnSlideAxis
    expectA #$FF, "A"

    lda #DIR_UP
    sta slideDir

    ldx #9*.sizeof(Tile)
    jsr GetTilePosOnSlideAxis
    expectA #4, "A"

    ldx #0*.sizeof(Tile)
    jsr GetTilePosOnSlideAxis
    expectA #$FF, "A"

    rts

TestGetTilePosOnNonSlideAxis:
    setTestName TestGetTilePosOnNonSlideAxis
    jsr WipeTiles
    setTile  #9,  #1, #4, #1
    lda #DIR_LEFT
    sta slideDir

    ldx #9*.sizeof(Tile)
    jsr GetTilePosOnNonSlideAxis
    expectA #4, "A"

    ldx #0*.sizeof(Tile)
    jsr GetTilePosOnNonSlideAxis
    expectA #$FF, "A"

    lda #DIR_DOWN
    sta slideDir

    ldx #9*.sizeof(Tile)
    jsr GetTilePosOnNonSlideAxis
    expectA #1, "A"

    ldx #0*.sizeof(Tile)
    jsr GetTilePosOnNonSlideAxis
    expectA #$FF, "A"

    rts

DumpTiles:
    ldy #0
    ldx #0
DumpNextTile:
    lda tiles+Tile::xpos, x
    printf "Tile %0d xpos = %d", tempY, tempA
    lda tiles+Tile::ypos, x
    printf "Tile %0d ypos = %d", tempY, tempA
    lda tiles+Tile::powers, x
    printf "Tile %0d powers = $%02x", tempY, tempA
    lda tiles+Tile::velocity, x
    printf "Tile %0d velocity = %d", tempY, tempA
    printf ""
.repeat .sizeof(Tile)
    inx
.endrepeat
    iny
    cpy #17
    beq :+
    jmp DumpNextTile
:
    printf "tileIndex1 = %d", tileIndex1
    printf "tileIndex2 = %d", tileIndex2
    printf "tileIndex3 = %d", tileIndex3
    printf "tileIndex4 = %d", tileIndex4
    rts

TestSetTileDisappears:
    setTestName TestSetTileDisappears
    jsr WipeTiles
    setTile #7, #0, #0, #3

    ldx #(.sizeof(Tile) * 7)
    jsr SetTileDisappears

    ldx #(.sizeof(Tile) * 7)
    lda tiles + Tile::powers, X
    expectA #$F3, "Updated tile powers"
    rts

TestSetTilePowerConstant:
    setTestName TestSetTilePowerConstant
    jsr WipeTiles
    setTile #7, #0, #0, #3

    ldx #(.sizeof(Tile) * 7)
    jsr SetTilePowerConstant

    ldx #(.sizeof(Tile) * 7)
    lda tiles + Tile::powers, X
    expectA #$33, "Updated tile powers"
    rts

TestSetTilePowerIncrease:
    setTestName TestSetTilePowerIncrease
    jsr WipeTiles
    setTile #7, #0, #0, #3

    ldx #(.sizeof(Tile) * 7)
    jsr SetTilePowerIncrease

    ldx #(.sizeof(Tile) * 7)
    lda tiles + Tile::powers, X
    expectA #$43, "Updated tile powers"
    rts

TestCalculateTileTransitionsEmpty:
    setTestName TestCalculateTileTransitionsEmpty
    jsr WipeTiles
    setTileIndexSlot tileIndex1, $FF
    setTileIndexSlot tileIndex2, $FF
    setTileIndexSlot tileIndex3, $FF
    setTileIndexSlot tileIndex4, $FF
    jsr CalculateTileTransitions
    expectByte tileIndex1, #$FF, "Tile index 1"
    expectByte tileIndex2, #$FF, "Tile index 2"
    expectByte tileIndex3, #$FF, "Tile index 3"
    expectByte tileIndex4, #$FF, "Tile index 4"
    rts

TestCalculateTileTransitionsSingleFirstTile:
    setTestName TestCalculateTileTransitionsSingleFirstTile
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, 0
    setTileIndexSlot tileIndex2, $FF
    setTileIndexSlot tileIndex3, $FF
    setTileIndexSlot tileIndex4, $FF
    setTile #0, #4, #8, #1
    jsr CalculateTileTransitions
    checkTileTransition tileIndex1, #$11, #0
    rts

TestCalculateTileTransitionsSingleSlidingTile:
    setTestName TestCalculateTileTransitionsSingleSlidingTile
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, $FF
    setTileIndexSlot tileIndex2, 0
    setTileIndexSlot tileIndex3, $FF
    setTileIndexSlot tileIndex4, $FF
    setTile #0, #4, #8, #1
    jsr CalculateTileTransitions
    checkTileTransition tileIndex2, #$11, #1

    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, $FF
    setTileIndexSlot tileIndex2, $FF
    setTileIndexSlot tileIndex3, 0
    setTileIndexSlot tileIndex4, $FF
    setTile #0, #4, #8, #1
    jsr CalculateTileTransitions
    checkTileTransition tileIndex3, #$11, #2

    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, $FF
    setTileIndexSlot tileIndex2, $FF
    setTileIndexSlot tileIndex3, $FF
    setTileIndexSlot tileIndex4, 0
    setTile #0, #4, #8, #1
    jsr CalculateTileTransitions
    checkTileTransition tileIndex4, #$11, #3
    rts

TestCalculateTileTransitionsMultipleSlidingTilesSync:
    setTestName TestCalculateTileTransitionsMultipleSlidingTilesSync
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, $FF
    setTileIndexSlot tileIndex2, 0
    setTileIndexSlot tileIndex3, 1
    setTileIndexSlot tileIndex4, 2
    setTile #0, #4, #8, #1
    setTile #1, #8, #8, #2
    setTile #2, #12, #8, #3
    jsr CalculateTileTransitions
    checkTileTransition tileIndex2, #$11, #1
    checkTileTransition tileIndex3, #$22, #1
    checkTileTransition tileIndex4, #$33, #1
    rts

TestCalculateTileTransitionsMultipleSlidingTilesGap:
    setTestName TestCalculateTileTransitionsMultipleSlidingTilesGap
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, $FF
    setTileIndexSlot tileIndex2, 1
    setTileIndexSlot tileIndex3, $FF
    setTileIndexSlot tileIndex4, 3
    setTile #1, #8, #8, #1
    setTile #3, #12, #8, #2
    jsr CalculateTileTransitions
    checkTileTransition tileIndex2, #$11, #1
    checkTileTransition tileIndex4, #$22, #2

    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, 1
    setTileIndexSlot tileIndex2, $FF
    setTileIndexSlot tileIndex3, $FF
    setTileIndexSlot tileIndex4, 3
    setTile #1, #8, #8, #1
    setTile #3, #12, #8, #2
    jsr CalculateTileTransitions
    checkTileTransition tileIndex1, #$11, #0
    checkTileTransition tileIndex4, #$22, #2
    rts

TestCalculateTileTransitionsFullSlateNoMerge:
    setTestName TestCalculateTileTransitionsFullSlateNoMerge
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, 0
    setTileIndexSlot tileIndex2, 1
    setTileIndexSlot tileIndex3, 2
    setTileIndexSlot tileIndex4, 3
    setTile #0, #4, #8, #1
    setTile #1, #8, #8, #2
    setTile #2, #12, #8, #1
    setTile #3, #12, #8, #2
    jsr CalculateTileTransitions
    checkTileTransition tileIndex1, #$11, #0
    checkTileTransition tileIndex2, #$22, #0
    checkTileTransition tileIndex3, #$11, #0
    checkTileTransition tileIndex4, #$22, #0
    rts

TestCalculateTileTransitionsSimpleMerge:
    setTestName TestCalculateTileTransitionsSimpleMerge
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, 0
    setTileIndexSlot tileIndex2, 1
    setTileIndexSlot tileIndex3, $FF
    setTileIndexSlot tileIndex4, $FF
    setTile #0, #4, #8, #1
    setTile #1, #8, #8, #1
    jsr CalculateTileTransitions
    checkTileTransition tileIndex1, #$F1, #0
    checkTileTransition tileIndex2, #$21, #1
    rts

TestCalculateTileTransitionsSlidingMerge:
    setTestName TestCalculateTileTransitionsSlidingMerge
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, $FF
    setTileIndexSlot tileIndex2, 0
    setTileIndexSlot tileIndex3, 1
    setTileIndexSlot tileIndex4, $FF
    setTile #0, #4, #8, #1
    setTile #1, #8, #8, #1
    jsr CalculateTileTransitions
    checkTileTransition tileIndex2, #$F1, #1
    checkTileTransition tileIndex3, #$21, #2
    rts

TestCalculateTileTransitionsGapMerge:
    setTestName TestCalculateTileTransitionsGapMerge
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, $FF
    setTileIndexSlot tileIndex2, 0
    setTileIndexSlot tileIndex3, $FF
    setTileIndexSlot tileIndex4, 1
    setTile #0, #4, #8, #1
    setTile #1, #8, #8, #1
    jsr CalculateTileTransitions
    checkTileTransition tileIndex2, #$F1, #1
    checkTileTransition tileIndex4, #$21, #3
    rts

TestCalculateTileTransitionsDoubleMerge:
    setTestName TestCalculateTileTransitionsDoubleMerge
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, 0
    setTileIndexSlot tileIndex2, 1
    setTileIndexSlot tileIndex3, 2
    setTileIndexSlot tileIndex4, 3
    setTile #0, #4, #8, #1
    setTile #1, #8, #8, #1
    setTile #2, #8, #8, #2
    setTile #3, #8, #8, #2
    jsr CalculateTileTransitions
    checkTileTransition tileIndex1, #$F1, #0
    checkTileTransition tileIndex2, #$21, #1
    checkTileTransition tileIndex3, #$F2, #1
    checkTileTransition tileIndex4, #$32, #2
    rts

TestCalculateTileTransitionsMiddleMerge:
    setTestName TestCalculateTileTransitionsMiddleMerge
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, 0
    setTileIndexSlot tileIndex2, 1
    setTileIndexSlot tileIndex3, 2
    setTileIndexSlot tileIndex4, 3
    setTile #0, #4, #8, #1
    setTile #1, #8, #8, #2
    setTile #2, #8, #8, #2
    setTile #3, #8, #8, #3
    jsr CalculateTileTransitions
    checkTileTransition tileIndex1, #$11, #0
    checkTileTransition tileIndex2, #$F2, #0
    checkTileTransition tileIndex3, #$32, #1
    checkTileTransition tileIndex4, #$33, #1
    rts

TestCalculateTileTransitionsMegaMerge:
    setTestName TestCalculateTileTransitionsMegaMerge
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, 0
    setTileIndexSlot tileIndex2, 1
    setTileIndexSlot tileIndex3, 2
    setTileIndexSlot tileIndex4, 3
    setTile #0, #4, #8, #1
    setTile #1, #8, #8, #1
    setTile #2, #8, #8, #1
    setTile #3, #8, #8, #1
    jsr CalculateTileTransitions
    checkTileTransition tileIndex1, #$F1, #0
    checkTileTransition tileIndex2, #$21, #1
    checkTileTransition tileIndex3, #$F1, #1
    checkTileTransition tileIndex4, #$21, #2
    rts

TestCalculateTileTransitionsMergeAndSlide:
    setTestName TestCalculateTileTransitionsMergeAndSlide
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTileIndexSlot tileIndex1, 0
    setTileIndexSlot tileIndex2, 1
    setTileIndexSlot tileIndex3, 2
    setTileIndexSlot tileIndex4, 3
    setTile #0, #4, #8, #1
    setTile #1, #8, #8, #1
    setTile #2, #8, #8, #2
    setTile #3, #8, #8, #1
    jsr CalculateTileTransitions
    checkTileTransition tileIndex1, #$F1, #0
    checkTileTransition tileIndex2, #$21, #1
    checkTileTransition tileIndex3, #$22, #1
    checkTileTransition tileIndex4, #$11, #1
    rts

.macro checkTilePos slot, xp, yp
    .if (.match (.left (1, {slot}), #))
        ldx #(.right(.tcount(slot) - 1, slot) * .sizeof(Tile))
    .else
        ldx #(slot * .sizeof(Tile))
    .endif
    lda tiles + Tile::xpos, X
    expectA xp, "X position of tile"
    lda tiles + Tile::ypos, X
    expectA yp, "Y position of tile"
.endmacro

TestIterateTileSlides:
    setTestName TestIterateTileSlides
    jsr WipeTiles

    setSlideDir DIR_RIGHT
    setTile #0, #0, #0, #1, #0
    ldx #0
    jsr IterateTileSlide
    checkTilePos #0, #0, #0

    setSlideDir DIR_RIGHT
    setTile #0, #0, #0, #1, #1
    ldx #0
    jsr IterateTileSlide
    checkTilePos #0, #1, #0

    setSlideDir DIR_LEFT
    setTile #0, #2, #0, #1, #$FF
    ldx #0
    jsr IterateTileSlide
    checkTilePos #0, #1, #0
    
    setSlideDir DIR_UP
    setTile #0, #2, #2, #1, #$FF
    ldx #0
    jsr IterateTileSlide
    checkTilePos #0, #2, #1

    setSlideDir DIR_DOWN
    setTile #0, #2, #2, #1, #1
    ldx #0
    jsr IterateTileSlide
    checkTilePos #0, #2, #3
    
    rts

TestIterateTileRowSlides:
    setTestName TestIterateTileRowSlides
    jsr WipeTiles
    setSlideDir DIR_RIGHT
    setTile #0, #0, #0, #1, #2
    setTile #1, #4, #0, #1, #1
    setTile #2, #0, #4, #1, #1
    setTile #3, #0, #8, #1, #3
    lda #0
    sta tileRow
    jsr IterateTileRowSlide
    checkTilePos #0, #2, #0
    checkTilePos #1, #5, #0
    checkTilePos #2, #0, #4
    checkTilePos #3, #0, #8
    rts
