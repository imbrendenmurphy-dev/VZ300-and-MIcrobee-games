; =====================================================================
;  UTIL: the polar projection, angle sums, division, scores
; =====================================================================

; A = angle (0 = bottom, rising anticlockwise), B = rr (0-255, the
; player's orbit is 224) -> HL = x (signed), C = y. BLK_TAB mapped.
polar:  ld c,a
        ld a,b
        and $FE
        ld l,a
        ld h,ROWPTR >> 8
        ld e,(hl)
        inc l
        ld d,(hl)
        ld a,c
        and $3F
        bit 6,c
        jr z,.a
        neg
        add a,64
.a:     add a,a
        ld l,a
        ld h,0
        add hl,de
        ld e,(hl)               ; dx
        inc hl
        ld d,(hl)               ; dy
        ld a,c
        add a,a
        xor c                   ; b7 = angle b7 xor b6: below the centre?
        ld a,d                  ; y = CY +- dy; off the screen: FFh
        jp p,.yd
        ld d,a
        ld a,CY
        sub d
        jr nc,.yok
        ld a,$FF
        jr .yok
.yd:    add a,CY
        jr c,.yoff
        cp SCRH
        jr c,.yok
.yoff:  ld a,$FF
.yok:   ld b,c
        ld c,a
        ld d,0
        ld hl,CX
        bit 7,b
        jr nz,.xl
        add hl,de
        ret
.xl:    or a
        sbc hl,de
        ret

; B = rr -> A = depth size class 0-5
sizeof: ld a,b
        srl a
        ld l,a
        ld h,SIZECLS >> 8
        ld a,(hl)
        ret

; A = B - C as a signed angle difference (-128..127), flags from it
adiff:  ld a,b
        sub c
        ret

; |A| -> A
absa:   or a
        ret p
        neg
        ret

; HL = signed dividend, C = divisor (1-255) -> HL = HL / C (signed,
; truncated)
sdiv:   ld a,h
        push af
        bit 7,h
        jr z,.p
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
.p:     ; HL = HL / C, unsigned
        xor a
        ld b,16
.d:     add hl,hl
        rla
        jr c,.s
        cp c
        jr c,.n
.s:     sub c
        inc l
.n:     djnz .d
        pop af
        bit 7,a
        ret z
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; DE = points / 10 in BCD (up to 9999 = 99990 points)
add_score:
        ld hl,score
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld a,(hud_dirty)
        or 1
        ld (hud_dirty),a
        ; an extra ship at 20 000, 60 000 and every 60 000 after
        ld hl,score+2
        ld de,next_life+2
        ld a,(de)
        cp (hl)
        jr c,.life
        ret nz
        dec hl
        dec de
        ld a,(de)
        cp (hl)
        jr c,.life
        ret nz
        dec hl
        dec de
        ld a,(de)
        cp (hl)
        jr z,.life
        ret nc
.life:  ld a,(lives)
        cp 6
        jr nc,.nl
        inc a
        ld (lives),a
.nl:    ; next threshold: 60 000 more (BCD of points / 10)
        ld a,(next_life+1)
        add a,$60
        daa
        ld (next_life+1),a
        ld a,(next_life+2)
        adc a,0
        daa
        ld (next_life+2),a
        ld a,$FF
        ld (hud_dirty),a
        ld hl,sfx_life
        ld a,6
        jp play_sfx

; HL = 3 BCD bytes (low first), DE = text buffer: 6 digits and a 0
bcd_text:
        inc hl
        inc hl
        ld b,3
.l:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        ld (de),a
        inc de
        ld a,(hl)
        and 15
        add a,'0'
        ld (de),a
        inc de
        dec hl
        djnz .l
        ld a,'0'
        ld (de),a
        inc de
        xor a
        ld (de),a
        ret

; A = 0-99 -> two digits at DE, then 0
dec2:   ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ex de,hl
        ld (hl),b
        inc hl
        ld (hl),a
        inc hl
        ld (hl),0
        ex de,hl
        ret
