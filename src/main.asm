INCLUDE "hardware.inc"
INCLUDE "macros.inc"

SECTION "STATE", WRAMX

gPuzzle: DS 2
gCursorX: DS 1
gCursorY: DS 1
gPuzzleValues: DS 4 * 4
gCheckWin: DS 1

SECTION "GRAPHICS", ROM0

titleTiles: INCBIN "src/assets/title.bin"
titleTilesEnd:

titleTileMap: INCBIN "src/assets/title.bin.map"
titleTileMapEnd:

boardTiles: INCBIN "src/assets/board.bin"
boardTilesEnd:

boardEdges: INCBIN "src/assets/board-edges.bin"
boardEdgesEnd:

value0Tiles: INCBIN "src/assets/value0.bin"
value1Tiles: INCBIN "src/assets/value1.bin"
value2Tiles: INCBIN "src/assets/value2.bin"
value3Tiles: INCBIN "src/assets/value3.bin"
value4Tiles: INCBIN "src/assets/value4.bin"
value4TilesEnd:

boardTileMap: INCBIN "src/assets/board.bin.map"
boardTileMapEnd:

opTiles: INCBIN "src/assets/op.bin"
opTilesEnd:

cursorTiles: INCBIN "src/assets/cursor.bin"
cursorTilesEnd:

DEF EDGE_TILE_IDX = (boardTilesEnd - boardTiles) / 16

SECTION "PUZZLES", ROM0

puzzle001: INCBIN "src/puzzles/001.bin"

puzzleEdgeMapAddrs:
    FOR Y, 4
        FOR X, 4
            DW $9822 + (X * 4) + ($80 * Y)
        ENDR
    ENDR

puzzleValueMapAddrs:
    FOR Y, 4
        FOR X, 4
            DW $9843 + (X * 4) + ($80 * Y)
        ENDR
    ENDR

DEF CURSOR_X0 EQU 40
DEF CURSOR_Y0 EQU 9

DEF CURSOR_X1 EQU 40
DEF CURSOR_Y1 EQU 32

DEF CURSOR_X2 EQU 16
DEF CURSOR_Y2 EQU 32

SECTION "HEADER", ROM0[$100]
    jp main
    ds $150 - @, 0

main:
    ; Disable audio
    xor a
    ld [rNR52], a

waitForVblank:
    ld a, [rLY]
    cp LY_VBLANK
    jr c, waitForVblank

    ; Disable LCD
    xor a
    ld [rLCDC], a

    ; Clear OAM
    xor a
    ld b, OAM_SIZE
    ld hl, STARTOF(OAM)
ClearOAM:
    ld [hli], a
    dec b
    jp nz, ClearOAM

    ; Copy board + edge + values tile data
    ld de, boardTiles
    ld hl, $9000
    ld bc, value4TilesEnd - boardTiles
    call MemCopy

    ; Copy cursor sprite
    ld de, cursorTiles
    ld hl, $8000
    ld bc, cursorTilesEnd - cursorTiles
    call MemCopy

    ; Copy operator sprites
    ld de, opTiles
    ld hl, $8000 + (cursorTilesEnd - cursorTiles)
    ld bc, opTilesEnd - opTiles
    call MemCopy

    ; Copy tile map
    ld de, boardTileMap
    ld hl, TILEMAP0
    call MapCopy

    ; Initialize game state
    ld hl, puzzle001
    call LoadPuzzle

    ; Initialize key state
    ld [gCurKeys], a
    ld [gNewKeys], a

    ; Turn on LCD
    ld a, LCDC_ON | LCDC_BG_ON | LCDC_OBJ_ON
    ld [rLCDC], a

    ; Initialize display registers
    ld a, %11100100
    ld [rBGP], a
    ld a, %11111100
    ld [rOBP0], a
    ld a, %11100100
    ld [rOBP1], a

Update:
    ld a, [rLY]
    cp LY_VBLANK
    jp nc, Update
WaitVBlank2:
    ld a, [rLY]
    cp LY_VBLANK
    jp c, WaitVBlank2

    call UpdateWin

    call UpdateKeys

    call UpdateValue
    call UpdateCursor
    jr Update

; Check if the puzzle state is correct.
UpdateWin:
    ld a, [gCheckWin]
    or a
    ret z

    ; Dereference puzzle pointer
    ld bc, gPuzzle
    ld a, [bc]
    ld l, a
    inc bc
    ld a, [bc]
    ld h, a
    ld b, h
    ld c, l

    ld hl, gPuzzleValues

    ld e, 16
.CheckValues:
    ; Compare [bc] (solution) and [hl] (guess)
    ld a, [bc]
    inc bc
    ld d, a

    ld a, [hl+]
    cp d
    jr nz, .Done

    dec e
    jr nz, .CheckValues

    ; Solution is correct
    halt

.Done:
    xor a
    ld [gCheckWin], a

    ret

; Update the value at the cursor position.
UpdateValue:
    ; Check if A button pressed
    ld a, [gNewKeys]
    and PAD_A
    ret z

    ; Calculate value offset
    ld a, [gCursorY]
    sla a
    sla a
    ld d, a
    ld a, [gCursorX]
    add d
    ld d, a

    ld bc, gPuzzleValues
    ADD16A bc

    ; value <- (value + 1) % 5
    ld a, [bc]
    inc a
    cp 5
    jr nz, .UpdateValueTiles
    xor a

.UpdateValueTiles:
    ; Update puzzle state
    ld [bc], a
    ld e, a

    ; Calculate base map address
    ld bc, puzzleValueMapAddrs
    ld a, d
    sla a
    ADD16A bc
    ld a, [bc]
    inc bc
    ld l, a
    ld a, [bc]
    ld h, a

    ; Calculate tile index
    ld a, e
    sla a
    sla a
    add $15

    ; Update map with new tiles
    ld [hl+], a
    inc a
    ld [hl], a
    inc a
    ld e, a
    ADD16 hl, $1f
    ld a, e
    ld [hl+], a
    inc a
    ld [hl], a

    ld a, 1
    ld [gCheckWin], a

    ret

MACRO UPDATE_CURSOR_SPRITE
    ; Y = \2 + cursorY * 32 + 16
    ld a, [gCursorY]
    REPT 5
        sla a
    ENDR
    add \2 + 16
    ld [de], a
    inc de

    ; X = \1 + cursorX * 32 + 8
    ld a, [gCursorX]
    REPT 5
        sla a
    ENDR
    add \1 + 8
    ld [de], a
    inc de
ENDM

; Update the position of the cursor.
UpdateCursor:
    ; Check if up pressed
    ld a, [gNewKeys]
    and PAD_UP
    jr z, .CheckDown

    ; Check if cursor can move up
    ld a, [gCursorY]
    or a
    ret z

    dec a
    ld [gCursorY], a
    jr .UpdateCursorSprites

.CheckDown:
    ; Check if down pressed
    ld a, [gNewKeys]
    and PAD_DOWN
    jr z, .CheckLeft

    ; Check if cursor can move down
    ld a, [gCursorY]
    cp 3
    ret z

    inc a
    ld [gCursorY], a
    jr .UpdateCursorSprites

.CheckLeft:
    ; Check if down pressed
    ld a, [gNewKeys]
    and PAD_LEFT
    jr z, .CheckRight

    ; Check if cursor can move left
    ld a, [gCursorX]
    or a
    ret z

    dec a
    ld [gCursorX], a
    jr .UpdateCursorSprites

.CheckRight:
    ; Check if right pressed
    ld a, [gNewKeys]
    and PAD_RIGHT
    ret z

    ; Check if cursor can move right
    ld a, [gCursorX]
    cp 3
    ret z

    inc a
    ld [gCursorX], a

.UpdateCursorSprites:
    ld de, STARTOF(OAM)

    UPDATE_CURSOR_SPRITE CURSOR_X0, CURSOR_Y0
    inc de
    inc de

    UPDATE_CURSOR_SPRITE CURSOR_X1, CURSOR_Y1
    inc de
    inc de

    UPDATE_CURSOR_SPRITE CURSOR_X2, CURSOR_Y2
    inc de
    inc de

    ret

MACRO LOAD_SPRITE_OAM
    ld a, \2 + 16
    ld [de], a
    inc de
    ld a, \1 + 8
    ld [de], a
    inc de
    ld a, \3
    ld [de], a
    inc de
    ld a, \4
    ld [de], a
    inc de
ENDM

; Load a puzzle from ROM
; @param hl Puzzle address
LoadPuzzle:
    ; Reset puzzle state
    xor a
    ld [gCursorX], a
    ld [gCursorY], a
    ld [gCheckWin], a

    ; Set pointer to current puzzle
    ld bc, gPuzzle
    ld a, h
    ld [bc], a
    inc bc
    ld a, l
    ld [bc], a
    
    ld de, gPuzzleValues
    ld h, 4 * 4
    call MemSet

    ; Load cursor sprites
    ld de, STARTOF(OAM)

    LOAD_SPRITE_OAM CURSOR_X0, CURSOR_Y0, 0, %00010000
    LOAD_SPRITE_OAM CURSOR_X1, CURSOR_Y1, 0, %01010000
    LOAD_SPRITE_OAM CURSOR_X2, CURSOR_Y2, 0, %01110000

    ; Load puzzle sprite sequences (NOTE: MUST always have at least one sprite sequence)
    ; ADD16 hl, 8
    ADD16 hl, 16
    ld a, [hl+]
    ld c, a

.LoadSpriteSequence:
    ld a, [hl+] ; Initial X
    ld b, a

    ld a, [hl+] ; Initial Y
    push af

.LoadSpriteSequenceLoop
    ; End loop when encountering sequence terminator (0xff)
    ld a, [hl]
    cp a, $ff
    jr z, .LoadSpriteSequenceDone

    ; Write Tile Y
    pop af
    ld [de], a
    inc de
    push af

    ; Write Tile X (increments by 4 each time)
    ld a, b
    ld [de], a
    inc de
    add a, 4
    ld b, a

    ; Write OAM tile index
    ld a, [hl+]
    ld [de], a
    inc de

    ; Write OAM attribute
    xor a
    ld [de], a
    inc de

    jr .LoadSpriteSequenceLoop

.LoadSpriteSequenceDone
    ; Skip terminator byte
    inc hl

    ; Remove stored tile Y from stack
    pop af

    ; Loop if more sprites left in sequence
    dec c
    jr nz, .LoadSpriteSequence

    ; Update edge tiles
    ld de, puzzleEdgeMapAddrs

    ld b, 0
    ld c, 4
    push bc

.LoadPuzzleEdgeLoopStart:
FOR N, 4
    ; Lookup tile start for cell
    ld a, [de]
    inc de
    ld c, a
    ld a, [de]
    inc de
    ld b, a

    ; Copy left edge if first bit set
    ld a, [hl]
    bit (N * 2), a
    jr z, .SkipCopyLeft\@
    
    ld a, EDGE_TILE_IDX + 4
    ld [bc], a
    REPT 3
        ADD16 bc, $20
        ld a, EDGE_TILE_IDX + 1
        ld [bc], a
    ENDR

    jr .CopyLeftDone\@

.SkipCopyLeft\@:
    ; First bit not set -> seek to bottom right of cell
    ADD16 bc, $60

.CopyLeftDone\@:
    ld a, [hl]
    REPT N
        srl a
        srl a
    ENDR
    and $3
    jr z, .EdgeDone\@

    add EDGE_TILE_IDX
    ld [bc], a
    inc bc

.CopyBottom\@:
    ld a, [hl]
    bit (N * 2 + 1), a
    jr z, .EdgeDone\@
    REPT 2
        ld a, EDGE_TILE_IDX + 2
        ld [bc], a
        inc bc
    ENDR
    ld a, EDGE_TILE_IDX + 5
    ld [bc], a

.EdgeDone\@:
ENDR

    inc hl
    pop bc
    dec c
    ret z
    push bc
    jp .LoadPuzzleEdgeLoopStart
