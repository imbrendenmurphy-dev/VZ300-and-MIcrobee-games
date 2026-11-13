; ---------------------------------------------------------------------
; MAKE_SKYLINE: build the skyline rows (heights 1..7, two pixel shifts,
; 96 bytes each) from RIDGE into $7800.., pointers in SKYPTR
; ---------------------------------------------------------------------
make_skyline:
        ld de,$7800             ; free system RAM below the program (the ROM is never used)
        ld iy,SKYPTR
        xor a
        ld (MKSH),a
.s:     ld b,1
.h:     ld (iy+0),e
        ld (iy+1),d
        inc iy
        inc iy
        ld a,(MKSH)
        ld l,a
        ld h,RIDGE/256
        ld ixl,96
.k:     ld c,0
        ld a,4
.p:     push af
        ld a,(hl)               ; pixel: 1 = mountain, 2 = sky
        sub b
        jr c,.sky
        cp 2
        jr nc,.mtn
        ld a,l
        add a,b
        and 1
        jr z,.sky
.mtn:   ld a,1
        jr .px
.sky:   ld a,2
.px:    sla c
        sla c
        or c
        ld c,a
        inc l
        pop af
        dec a
        jr nz,.p
        ld a,c
        ld (de),a
        inc de
        dec ixl
        jr nz,.k
        inc b
        ld a,b
        cp SKYL_H+1
        jr nz,.h
        ld a,(MKSH)
        add a,2
        ld (MKSH),a
        cp 4
        jr nz,.s
        ret
