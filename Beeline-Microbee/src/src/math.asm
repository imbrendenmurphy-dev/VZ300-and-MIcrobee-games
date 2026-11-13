; ==========================================================================
; math.asm - fixed-point helpers for the road engine
; ==========================================================================

; --------------------------------------------------------------------------
; mul16u: DE:HL = BC * DE   (unsigned 16x16 -> 32, shift-add, ~900T)
; --------------------------------------------------------------------------
mul16u:
        ld hl,0
        ld a,16
.l      add hl,hl
        rl e
        rl d
        jr nc,.n
        add hl,bc
        jr nc,.n
        inc de
.n      dec a
        jr nz,.l
        ret

; --------------------------------------------------------------------------
; mulsh14: HL = (HL * DE) >> 14,  HL signed, DE unsigned (perspective scale)
;          multiplier = the 16-bit |HL| (usually small -> early-out variant)
; --------------------------------------------------------------------------
mulsh14:
        ld a,h
        ld (.sgn),a
        bit 7,h
        jr z,.pos
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
.pos    ld b,d                  ; BC = inv (multiplicand)
        ld c,e
        ex de,hl                ; DE = |h| (multiplier)
        ld hl,0
        ; skip leading zero bits of the multiplier
        ld a,d
        or a
        jr nz,.full
        ld d,e                  ; high byte zero: only 8 iterations needed
        ld e,0
        ld a,8
        jr .loop
.full   ld a,16
.loop   add hl,hl
        rl e
        rl d
        jr nc,.n
        add hl,bc
        jr nc,.n
        inc de
.n      dec a
        jr nz,.loop
        ; DE:HL = product.  >>14  ->  (DE<<2) | (H>>6)
        ld a,h
        rlca
        rlca
        and 3
        ex de,hl
        add hl,hl
        add hl,hl
        or l
        ld l,a
        ld a,(.sgn)
        bit 7,a
        ret z
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret
.sgn    db 0

; --------------------------------------------------------------------------
; mul8q: HL = A * E  (unsigned 8x8, quarter-square tables, ~150T)
;        destroys A, BC, DE
; --------------------------------------------------------------------------
mul8q:
        ld b,a
        sub e
        jr nc,.p
        neg
.p      ld c,a                  ; |a-b|
        ld a,b
        add a,e                 ; a+b (carry = bit 8)
        ld l,a
        ld a,high(SQL)
        adc a,0
        ld h,a
        ld e,(hl)
        inc h
        inc h
        ld d,(hl)               ; DE = (a+b)^2/4
        ld l,c
        ld h,high(SQL)
        ld a,e
        sub (hl)
        ld e,a
        inc h
        inc h
        ld a,d
        sbc a,(hl)
        ld h,a
        ld l,e
        ret

; --------------------------------------------------------------------------
; lerp: HL = P0 + ((P1 - P0) * f) >> 8      (signed 16, f = 0..255 in A)
;       in: HL = P0, DE = P1, A = f
; --------------------------------------------------------------------------
lerp:
        ld (.f),a
        ld (.p0),hl
        ex de,hl
        ld de,(.p0)
        or a
        sbc hl,de               ; HL = delta
        ld a,h
        ld (.sgn),a
        bit 7,h
        jr z,.pos
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
.pos    ld (.d),hl
        ; (dh*f) + ((dl*f) >> 8)
        ld a,(.f)
        ld e,l
        call mul8q              ; HL = dl*f
        ld a,h
        ld (.lo),a
        ld a,(.d+1)
        ld e,a
        ld a,(.f)
        call mul8q              ; HL = dh*f
        ld a,(.lo)
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc     ld a,(.sgn)
        bit 7,a
        jr z,.add
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
.add    ld de,(.p0)
        add hl,de
        ret
.f      db 0
.p0     dw 0
.d      dw 0
.lo     db 0
.sgn    db 0

; --------------------------------------------------------------------------
; frac8: A = (t * 256) / dy, clamped to 255.   in: HL = t (>=0), DE = dy (>0)
; --------------------------------------------------------------------------
frac8:
        ; scale down until dy < 256
.sc     ld a,d
        or a
        jr z,.ok
        srl d
        rr e
        srl h
        rr l
        jr .sc
.ok     ld a,h                  ; t >= 256 or t >= dy -> clamp
        or a
        jr nz,.max
        ld a,l
        cp e
        jr nc,.max
        ld h,l                  ; HL = t << 8
        ld l,0
        ld c,e
        ld b,8
.l      add hl,hl
        ld a,h
        jr c,.sub
        cp c
        jr c,.n
.sub    sub c
        ld h,a
        inc l
.n      djnz .l
        ld a,l
        ret
.max    ld a,255
        ret
