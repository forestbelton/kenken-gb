INCLUDE "hardware.inc"
INCLUDE "macros.inc"

SECTION "Utilities", ROM0

; Copy bytes from one area to another.
; @param de: Source
; @param hl: Destination
; @param bc: Length
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

; Copy tilemap to VRAM.
; @param de: Source
; @param hl: Destination
MapCopy:
    ld b, 18
.MapCopyRowStart:
    ld c, 20
.MapCopyRow:
    ld a, [de]
    ld [hli], a
    inc de
    dec c
    jr nz, .MapCopyRow
    dec b
    ret z
    ADD16 hl, 12
    jr .MapCopyRowStart

EXPORT MapCopy

; Update input state.
UpdateKeys:
  ; Poll half the controller
  ld a, JOYP_GET_BUTTONS
  call .onenibble
  ld b, a ; B7-4 = 1; B3-0 = unpressed buttons

  ; Poll the other half
  ld a, JOYP_GET_CTRL_PAD
  call .onenibble
  swap a ; A7-4 = unpressed directions; A3-0 = 1
  xor a, b ; A = pressed buttons + directions
  ld b, a ; B = pressed buttons + directions

  ; And release the controller
  ld a, JOYP_GET_NONE
  ldh [rJOYP], a

  ; Combine with previous gCurKeys to make gNewKeys
  ld a, [gCurKeys]
  xor a, b ; A = keys that changed state
  and a, b ; A = keys that changed to pressed
  ld [gNewKeys], a
  ld a, b
  ld [gCurKeys], a
  ret

.onenibble
  ldh [rJOYP], a ; switch the key matrix
  call .knownret ; burn 10 cycles calling a known ret
  ldh a, [rJOYP] ; ignore value while waiting for the key matrix to settle
  ldh a, [rJOYP]
  ldh a, [rJOYP] ; this read counts
  or a, $F0 ; A7-4 = 1; A3-0 = unpressed keys
.knownret
  ret

EXPORT UpdateKeys

SECTION "Joypad state", WRAMX

gCurKeys: DS 1
gNewKeys: DS 1

EXPORT gCurKeys
EXPORT gNewKeys
