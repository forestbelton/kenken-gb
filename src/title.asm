INCLUDE "hardware.inc"

Section "Title graphics", ROM0

titleTiles: INCBIN "src/assets/title.bin"
titleTilesEnd:

titleTileMap: INCBIN "src/assets/title.bin.map"
titleTileMapEnd:

pressStartTiles: INCBIN "src/assets/press-start.bin"
pressStartTilesEnd:

Section "Title state", WRAM0

gFrameCounter: DS 1

SECTION "Title screen", ROM0

EXPORT RunTitle

RunTitle:
    ld a, [rLY]
    cp LY_VBLANK
    jr c, RunTitle

    ; Disable LCD
    xor a
    ld [rLCDC], a

    call ClearOAM

    ; Copy "Press start" tiles
    ld de, pressStartTiles
    ld hl, $8000
    ld bc, pressStartTilesEnd - pressStartTiles
    call MemCopy

    ; Add "Press start" sprites
    ld hl, STARTOF(OAM)
    FOR Y, 2
        FOR X, 10
            ld a, ($D + Y) * 8 + 16
            ld [hl+], a
            ld a, ($5 + X) * 8 + 8
            ld [hl+], a
            ld a, X + Y * 10
            ld [hl+], a
            xor a
            ld [hl+], a
        ENDR
    ENDR

    ; Copy title tiles
    ld de, titleTiles
    ld hl, $9000
    ld bc, titleTilesEnd - titleTiles
    call MemCopy

    ; Copy tile map
    ld de, titleTileMap
    ld hl, TILEMAP0
    call MapCopy

    xor a
    ld [gFrameCounter], a

    ; Turn on LCD
    ld a, LCDC_ON | LCDC_BG_ON | LCDC_OBJ_ON
    ld [rLCDC], a

.UpdateTitle:
    ld a, [rLY]
    cp LY_VBLANK
    jp nc, .UpdateTitle
.TitleWaitVBlank2:
    ld a, [rLY]
    cp LY_VBLANK
    jp c, .TitleWaitVBlank2

    ld a, [gFrameCounter]
    inc a
    and $1f
    ld [gFrameCounter], a
    jr nz, .UpdateKeys

    ; Toggle visibility of press start sprites
    ld a, [rLCDC]
    xor LCDC_OBJ_ON
    ld [rLCDC], a

.UpdateKeys:
    call UpdateKeys

    ld a, [gNewKeys]
    and PAD_START
    jr z, .UpdateTitle

    jp RunGame
