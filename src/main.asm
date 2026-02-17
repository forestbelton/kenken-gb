INCLUDE "hardware.inc"

SECTION "HEADER", ROM0[$100]
    jp main
    ds $150 - @, 0

main:
    ; Disable audio
    xor a
    ld [rNR52], a

waitForVblank:
    ld a, [rLY]
    cp 144
    jr c, waitForVblank

    ; Disable LCD
    xor a
    ld [rLCDC], a

    ; Copy tile data
    ld de, boardTiles
    ld hl, $9000
    ld bc, boardTilesEnd - boardTiles
    call MemCopy

    ; Copy tile map
    ld de, boardTileMap
    ld hl, $9800
    call MapCopy

    ; Turn on LCD
    ld a, LCDC_ON | LCDC_BG_ON
    ld [rLCDC], a

    ; Initialize display registers
    ld a, %11100100
    ld [rBGP], a

done:
    jr done

MapCopy:
    ld b, 18
MapCopyRowStart:
    ld c, 20
MapCopyRow:
    ld a, [de]
    ld [hli], a
    inc de
    dec c
    jr nz, MapCopyRow
    dec b
    jr z, MapCopyDone
REPT 12
    inc hl
ENDR
    jr MapCopyRowStart
MapCopyDone:
    ret

SECTION "GRAPHICS", ROM0

boardTiles: INCBIN "src/assets/board.bin"
boardTilesEnd:

boardTileMap: INCBIN "src/assets/board.bin.map"
boardTileMapEnd:

