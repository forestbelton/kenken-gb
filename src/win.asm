INCLUDE "hardware.inc"

SECTION "Win graphics", ROM0

winTiles: INCBIN "src/assets/win.bin"
winTilesEnd:

winMap: INCBIN "src/assets/win.bin.map"
winMapEnd:

SECTION "Win screen", ROM0

EXPORT RunWin

RunWin:
    ld a, [rLY]
    cp LY_VBLANK
    jr c, RunWin

    ; Disable LCD
    xor a
    ld [rLCDC], a

    call ClearOAM

    ; Copy win tiles
    ld de, winTiles
    ld hl, $9000
    ld bc, winTilesEnd - winTiles
    call MemCopy

    ; Copy tile map
    ld de, winMap
    ld hl, TILEMAP0
    call MapCopy

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

    call UpdateKeys

    ld a, [gCurKeys]
    and PAD_A
    jr z, Update

    jr Update
