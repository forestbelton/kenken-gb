INCLUDE "hardware.inc"
INCLUDE "macros.inc"

SECTION "HEADER", ROM0[$100]
    jp main
    ds $150 - @, 0

main:
    ; Disable audio
    xor a
    ld [rNR52], a

    ; Initialize display registers
    ld a, %11100100
    ld [rBGP], a
    ld a, %11111100
    ld [rOBP0], a
    ld a, %11100100
    ld [rOBP1], a

    call RunTitle
