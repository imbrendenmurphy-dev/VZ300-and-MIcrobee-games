; common header for overlay parts
        DEVICE NOSLOT64K
        INCLUDE "engine.inc"
        INCLUDE "../build/layout.inc"
        INCLUDE "../build/resident.sym.inc"
        org OVL
        jp part_entry

; frame start: sync to field, set raster table, speaker bits = 0
FRAME_START MACRO rtv
        ld (sp_save),sp
        call frame_sync
        ld sp,(rtv)
        xor a
        ENDM

; frame end: restore stack, run music sequencer, part logic follows
FRAME_END MACRO
        ld sp,(sp_save)
        call music_save
        call music_tick
        ENDM

; 16 bit random (xorshift) -> HL, A = L
rnd16:  ld hl,(.seed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (.seed),hl
        ld a,l
        ret
.seed:  dw $ACE1

; A = 0..255 -> 3 decimal digits (screen codes) at (DE)
put_dec3:
        ld b,'0'-1
.h:     inc b
        sub 100
        jr nc,.h
        add a,100
        ld c,a
        ld a,b
        ld (de),a
        inc de
        ld a,c
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ld c,a
        ld a,b
        ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
        ret
