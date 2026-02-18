INCLUDE "hardware.inc"
INCLUDE "macros.inc"

SECTION "Title graphics", ROM0

titleTileMap: INCBIN "src/assets/title.bin.map"
titleTileMapEnd:

SECTION "HEADER", ROM0[$100]
    jp main
    ds $150 - @, 0

main:
    ; Disable audio
    xor a
    ld [rNR52], a

    call RunGame
