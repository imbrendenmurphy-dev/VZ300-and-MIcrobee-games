rand:
        push hl
        ld hl,(v_seed)
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
        ld (v_seed),hl
        ld a,l
        xor h
        pop hl
        ret

; ---- controls -> A (and v_ctl): b0 left b1 right b2 down b3 up b4 fire b5 arm
read_controls:
        call mb_scan
        push bc
        push hl
        ld c,0
        ld a,(KR0)
        bit 4,a
        jr nz,.n1
        set 3,c                 ; Q up
.n1:    ld a,(KR1)
        bit 4,a
        jr nz,.n2
        set 2,c                 ; A down
.n2:    ld a,(KR6)
        bit 1,a
        jr nz,.n3
        set 0,c                 ; O left
.n3:    bit 4,a
        jr nz,.n4
        set 1,c                 ; P right
.n4:    ld a,(KR4)
        bit 4,a                 ; SPACE
        jr nz,.n5
        set 4,c
.n5:    bit 5,a                 ; M
        jr nz,.n6
        set 4,c
.n6:    call rjoy
        ld a,c
        ld (v_ctl),a
        pop hl
        pop bc
        ret

rjoy:
        in a,($00)
        or a : ret z
        cpl : ld b,a
        bit 0,b : jr z,.d : set 3,c
.d:     bit 1,b : jr z,.l : set 2,c
.l:     bit 2,b : jr z,.r : set 0,c
.r:     bit 3,b : jr z,.f : set 1,c
.f:     bit 7,b : ret z : set 4,c : ret
joy_detect: ret
; ---- NZ if any key / fire
anykey:
        push bc
        push hl
        call read_controls
        and $30
        jr nz,.y
        ld c,8
        ld hl,$68FE
.k:     ld a,(hl)
        and $3F
        cp $3F
        jr nz,.y
        rlc l
        dec c
        jr nz,.k
        pop hl
        pop bc
        xor a
        ret
.y:     pop hl
        pop bc
        or 1
        ret
waitrel:
.r:     ld a,1
        call frame_sync
        call anykey
        jr nz,.r
        ret

; ---- key test: A = row address low byte, B = bit mask -> Z if pressed
keyt:
        push hl
        ld h,$68
        ld l,a
        ld a,(hl)
        pop hl
        and b
        ret

; ---- tables built at boot ------------------------------------------------------
; SHT + s*$200: hi part / SHT + s*$200 + $100: lo part of a byte shifted right by
; 2*s bits (s = 1..3; s = 0 isn't used). OPQ: opaque-pixel mask of a sprite byte
; (blue pixels are transparent).
build_tables:
        ld b,1
.s:     push bc
        ld a,b
        dec a
        add a,a
        add a,SHT>>8
        ld h,a
        ld l,0
.b:     ; value L shifted right by 2*B bits into (hi, lo)
        ld d,l
        ld e,0
        push bc
.sh:    srl d
        rr e
        srl d
        rr e
        djnz .sh
        pop bc
        ld (hl),d
        inc h
        ld (hl),e
        dec h
        inc l
        jr nz,.b
        pop bc
        inc b
        ld a,b
        cp 4
        jr nz,.s
        ; opaque masks
        ld hl,OPQ
.o:     ld a,l
        ld c,0
        ld b,4
.op:    rlca
        rlca
        ld d,a
        and 3
        cp C_BLU
        ld a,c
        jr z,.tr
        scf
        rla
        scf
        rla
        jr .nx
.tr:    add a,a
        add a,a
.nx:    ld c,a
        ld a,d
        djnz .op
        ld (hl),c
        inc l
        jr nz,.o
        ret
