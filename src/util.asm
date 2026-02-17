SECTION "Utilities", ROM0

MemCopy:
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or a, c
    jp nz, MemCopy
    ret

EXPORT MemCopy
