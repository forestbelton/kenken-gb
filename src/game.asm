INCLUDE "hardware.inc"
INCLUDE "macros.inc"
INCLUDE "rand.inc"

DEF CURSOR_X0 EQU 40
DEF CURSOR_Y0 EQU 9

DEF CURSOR_X1 EQU 40
DEF CURSOR_Y1 EQU 32

DEF CURSOR_X2 EQU 16
DEF CURSOR_Y2 EQU 32

SECTION "Puzzle constants", ROM0

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

SECTION "Game graphics", ROM0

titleTiles: INCBIN "src/assets/title.bin"
titleTilesEnd:

boardTiles: INCBIN "src/assets/board.bin"
boardTilesEnd:

DEF EDGE_TILE_IDX = (boardTilesEnd - boardTiles) / 16

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

SECTION "Game state", WRAM0

gPuzzleSolution: DS 4 * 4
gCursorX: DS 1
gCursorY: DS 1
gPuzzleValues: DS 4 * 4
gCheckWin: DS 1

SECTION "Game code", ROM0

DEF USE_RANDOM_PUZZLES EQU 1

EXPORT RunGame

RunGame:
    ld a, [rLY]
    cp LY_VBLANK
    jr c, RunGame

    ; Disable LCD
    xor a
    ld [rLCDC], a

    call ClearOAM

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

IF USE_RANDOM_PUZZLES == 1
    ; Load random puzzle
    call rand
    call Mod218
    
    ld de, gPuzzleTable
    ADD16A de
    ld a, b
    ADD16A de

    ld a, [de]
    ld l, a
    inc de
    ld a, [de]
    ld h, a
ELSE
    ld hl, puzzle000
ENDC

    call LoadPuzzle

    ; Turn on LCD
    ld a, LCDC_ON | LCDC_BG_ON | LCDC_OBJ_ON
    ld [rLCDC], a

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

    ld bc, gPuzzleSolution
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
    jp RunWin

.Done:
    xor a
    ld [gCheckWin], a

    ret

; Update the value at the cursor position.
UpdateValue:
    ; Check if A button pressed
    ld a, [gNewKeys]
    and PAD_A
    jr z, .CheckB
    ld e, 1
    jr .UpdateValue

.CheckB:
    ld a, [gNewKeys]
    and PAD_B
    ret z
    ld e, $ff

.UpdateValue:
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

    ; value <- max(0, min(value, 4))
    ld a, [bc]
    add e
    cp 5
    jr nz, .CheckNegative1
    ld a, 4
    jr .UpdateValueTiles
.CheckNegative1
    cp $ff
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
    add $14

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

; Update cursor sprite position in OAM.
; @param de: OAM address
; @param b: Y position + 16
; @param c: X position + 8
UpdateCursorSprite:
    ; Y = B + cursorY * 32
    ld a, [gCursorY]
    REPT 5
        ; We can use RLCA here instead of SLA due to the fact that the carry bit is
        ; always clear upon calling this function. This saves 5 bytes in each REPT.
        rlca
    ENDR
    add b
    ld [de], a
    inc de

    ; X = C + cursorX * 32
    ld a, [gCursorX]
    REPT 5
        rlca
    ENDR
    add c
    ld [de], a
    inc de

    inc de
    inc de

    ret

MACRO UPDATE_CURSOR_SPRITE
    ld bc, ((\2 + 16) << 8) | (\1 + 8)
    call UpdateCursorSprite
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
    UPDATE_CURSOR_SPRITE CURSOR_X1, CURSOR_Y1
    UPDATE_CURSOR_SPRITE CURSOR_X2, CURSOR_Y2

    ret

; Load a cursor sprite into OAM.
; @param b: Y position + 16
; @param c: X position + 8
; @param h: OAM attributes
LoadCursorSprite:
    ld a, b
    ld [de], a
    inc de
    ld a, c
    ld [de], a
    inc de
    xor a
    ld [de], a
    inc de
    ld a, h
    ld [de], a
    inc de
    ret

MACRO LOAD_CURSOR_SPRITE
    ld bc, ((\2 + 16) << 8) | (\1 + 8)
    ld h, \3
    call LoadCursorSprite
ENDM

; Load a puzzle from ROM
; @param hl Puzzle address
LoadPuzzle:
    ; Reset puzzle state
    xor a
    ld [gCursorX], a
    ld [gCursorY], a
    ld [gCheckWin], a

    ; Unpack puzzle solution
    ld bc, gPuzzleSolution
    ld d, 4
.UnpackPuzzleRow:
    push de
    
    ld e, [hl]
    ld d, 4
.UnpackPuzzleCell:
    ld a, e
    and $3
    inc a

    ld [bc], a
    inc bc

    srl e
    srl e

    dec d
    jr nz, .UnpackPuzzleCell

    inc hl

    pop de
    dec d
    jr nz, .UnpackPuzzleRow

    push hl
    
    xor a
    ld de, gPuzzleValues
    ld h, 4 * 4
    call MemSet

    ; Load cursor sprites
    ld de, STARTOF(OAM)

    LOAD_CURSOR_SPRITE CURSOR_X0, CURSOR_Y0, %00010000
    LOAD_CURSOR_SPRITE CURSOR_X1, CURSOR_Y1, %01010000
    LOAD_CURSOR_SPRITE CURSOR_X2, CURSOR_Y2, %01110000

    ; Load puzzle sprite sequences (NOTE: MUST always have at least one sprite sequence)
    pop hl
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
    
    ld a, EDGE_TILE_IDX + 3
    ld [bc], a
    REPT 3
        ADD16 bc, $20
        ld a, EDGE_TILE_IDX
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

    add EDGE_TILE_IDX - 1
    ld [bc], a
    inc bc

.CopyBottom\@:
    ld a, [hl]
    bit (N * 2 + 1), a
    jr z, .EdgeDone\@
    REPT 2
        ld a, EDGE_TILE_IDX + 1
        ld [bc], a
        inc bc
    ENDR
    ld a, EDGE_TILE_IDX + 4
    ld [bc], a

.EdgeDone\@:
ENDR

    inc hl
    pop bc
    dec c
    ret z
    push bc
    jp .LoadPuzzleEdgeLoopStart
