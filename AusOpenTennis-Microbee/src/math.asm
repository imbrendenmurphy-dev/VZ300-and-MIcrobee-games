; =====================================================================
;  small maths helpers (from TENNIS II on the VZ300)
;  World positions are 10.6 fixed point (signed 16-bit, 64 = 1 unit).
;  Court: X 32..224 singles, Y 24 (far baseline) .. 232 (near), net 128.
; =====================================================================

; HL = H*E (unsigned), clobbers B,D
umul8:
        ld l,0
        ld d,l
        ld b,8
.l:     add hl,hl
        jr nc,.n
        add hl,de
.n:     djnz .l
        ret

; A = (A signed * E unsigned) >> 8, clobbers HL,B,D
smul8:
        or a
        jp p,.pos
        neg
        ld h,a
        call umul8
        call neghl
        ld a,h
        ret
.pos:   ld h,a
        call umul8
        ld a,h
        ret

neghl:
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; HL = HL / C (unsigned), A = remainder, clobbers B
udiv16:
        xor a
        ld b,16
.l:     add hl,hl
        rla
        jr c,.s
        cp c
        jr c,.n
.s:     sub c
        inc l
.n:     djnz .l
        ret

; HL = HL (signed) / A (1..255), clobbers BC
sdiv:
        ld c,a
        bit 7,h
        jr z,udiv16
        call neghl
        call udiv16
        jp neghl

; HL = HL (signed) * A / 256, clobbers BC,DE
sfrac:
        ld e,a
        bit 7,h
        jr z,ufrac
        call neghl
        call ufrac
        jp neghl
ufrac:
        ld c,l
        call umul8
        push hl
        ld h,c
        call umul8
        ld l,h
        ld h,0
        pop bc
        add hl,bc
        ret

; A = clamp(HL >> 6, 0..255)   (HL 10.6 signed; HL clobbered)
to_int:
        bit 7,h
        jr nz,.neg
        ld a,h
        cp $40
        jr nc,.big
        add hl,hl
        add hl,hl
        ld a,h
        ret
.neg:   xor a
        ret
.big:   ld a,255
        ret

; HL = A * 64  (int -> 10.6)
from_int:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ret

; |A| (signed) -> A
abs_a:
        or a
        ret p
        neg
        ret

; signed random in -B/2 .. +B/2 (B = spread 0..127) -> A
rand_spread:
        ld a,b
        or a
        ret z
        push bc
        call rand_n
        pop bc
        srl b
        sub b
        ret

