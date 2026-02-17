IF !DEF(MACROS_INC)

def MACROS_INC equ 1

MACRO ADD16
    ld a, \2
    add LOW(\1)
    ld LOW(\1), a
    ld a, 0
    adc HIGH(\1)
    ld HIGH(\1), a
ENDM

ENDC
