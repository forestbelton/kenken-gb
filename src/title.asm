INCLUDE "hardware.inc"

Section "Title graphics", ROM0

titleTiles: INCBIN "src/assets/title.bin"
titleTilesEnd:

titleTileMap: INCBIN "src/assets/title.bin.map"
titleTileMapEnd:

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

    ; Copy title tiles
    ld de, titleTiles
    ld hl, $9000
    ld bc, titleTilesEnd - titleTiles
    call MemCopy

    ; Copy tile map
    ld de, titleTileMap
    ld hl, TILEMAP0
    call MapCopy

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

    call UpdateKeys

    ld a, [gNewKeys]
    and PAD_START
    jr z, .UpdateTitle

    jp RunGame
