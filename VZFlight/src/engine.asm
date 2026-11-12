; ---------------------------------------------------------------- maths
neghl:  xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret
negde:  xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
        ret
negbc:  xor a
        sub c
        ld c,a
        sbc a,a
        sub b
        ld b,a
        ret

; HL >>= A (arithmetic)
sran:   or a
        ret z
        ld b,a
.l:     sra h
        rr l
        djnz .l
        ret

; HL = A * B (unsigned 8x8, quarter squares). keeps B
umul8:  ld c,a
        add a,b
        ld l,a
        ld h,high(sqlo)
        jr nc,.s1
        inc h
.s1:    ld e,(hl)
        inc h
        inc h
        ld d,(hl)
        ld a,c
        sub b
        jr nc,.s2
        neg
.s2:    ld l,a
        ld h,high(sqlo)
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

; HL = (DE * m) >> 8, signed.  HL -> matrix entry (mag, sign)
mul16m: ld b,(hl)
        inc hl
        ld a,(hl)
        bit 7,d
        jr z,.p
        xor 1
        ld c,a
        call negde
        ld a,c
.p:     ld (msgn),a
        push de
        ld a,e
        call umul8
        ld a,h
        pop de
        push af
        ld a,d
        call umul8
        pop af
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(msgn)
        or a
        ret z
        jp neghl

; DE:HL = DE * BC unsigned
umul16: ld hl,0
        ld a,16
.l:     add hl,hl
        rl e
        rl d
        jr nc,.n
        add hl,bc
        jr nc,.n
        inc de
.n:     dec a
        jr nz,.l
        ret

; DE:HL = DE * BC signed
smul16: ld a,d
        xor b
        push af
        bit 7,d
        call nz,negde
        bit 7,b
        call nz,negbc
        call umul16
        pop af
        ret p
        xor a
        sub l
        ld l,a
        ld a,0
        sbc a,h
        ld h,a
        ld a,0
        sbc a,e
        ld e,a
        ld a,0
        sbc a,d
        ld d,a
        ret

; HL = (DE * BC) >> 15 signed (Q15 multiply)
fmul:   ld a,d
        xor b
        push af
        bit 7,d
        call nz,negde
        bit 7,b
        call nz,negbc
        call umul16
        add hl,hl
        ex de,hl
        adc hl,hl
        pop af
        ret p
        jp neghl

; HL = DE:HL / BC unsigned (BC < 32768). carry set on overflow
udiv32: ex de,hl
        or a
        sbc hl,bc
        jr nc,.ovf
        add hl,bc
        ld a,16
.l:     sla e
        rl d
        adc hl,hl
        sbc hl,bc
        jr nc,.q1
        add hl,bc
        jr .q0
.q1:    inc e
.q0:    dec a
        jr nz,.l
        ex de,hl
        or a
        ret
.ovf:   scf
        ret

; DE:HL += sign-extended BC   (destroys A, C)
add32s: ld a,b
        add a,a
        sbc a,a
        add hl,bc
        ld c,a
        adc a,e
        ld e,a
        ld a,c
        adc a,d
        ld d,a
        ret

; (IX) 32-bit += DE:HL, B times
add32n: ld a,(ix+0)
        add a,l
        ld (ix+0),a
        ld a,(ix+1)
        adc a,h
        ld (ix+1),a
        ld a,(ix+2)
        adc a,e
        ld (ix+2),a
        ld a,(ix+3)
        adc a,d
        ld (ix+3),a
        djnz add32n
        ret

; (HL) 24-bit += sign-extended DE, B times
addn24: ld a,d
        add a,a
        sbc a,a
        ld c,a
.l:     ld a,(hl)
        add a,e
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,c
        ld (hl),a
        dec hl
        dec hl
        djnz .l
        ret

; clamp HL to [-DE, DE]
clamp:  bit 7,h
        jr nz,.neg
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ld h,d
        ld l,e
        ret
.neg:   push hl
        add hl,de
        pop hl
        ret c
        ld h,d
        ld l,e
        jp neghl

; HL = cos / sin of angle HL (Q15)
cos:    ld a,h
        add a,$40
        ld h,a
sin:    xor a
        add hl,hl
        rla
        add hl,hl
        rla
        ld l,h
        ld h,a
        add hl,hl
        ld de,sintab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

settrig:
        ld hl,(yaw3+1)
        ld (cyaw),hl
        ld hl,(pitch3+1)
        ld (cpitch),hl
        ld hl,(roll3+1)
        ld (croll),hl
calctrig:
        ld hl,(cyaw)
        call sin
        ld (sny),hl
        ld hl,(cyaw)
        call cos
        ld (csy),hl
        ld hl,(cpitch)
        call sin
        ld (snp),hl
        ld hl,(cpitch)
        call cos
        ld (csp),hl
        ld hl,(croll)
        call sin
        ld (snr),hl
        ld hl,(croll)
        call cos
        ld (csr),hl
        ret

; (IX) += HL(8.8 m/s) * 5.125 * nf   (16.16 metres)
addvel: ld b,h
        ld c,l
        ld a,h
        add a,a
        sbc a,a
        ld e,a
        ld d,a
        add hl,hl
        rl e
        rl d
        add hl,hl
        rl e
        rl d
        push bc
        call add32s
        pop bc
        sra b
        rr c
        sra b
        rr c
        sra b
        rr c
        call add32s
        ld a,(nf)
        ld b,a
        jp add32n

; ---------------------------------------------------------------- camera + matrix
setcam: ld hl,(px+2)
        ld (cxi),hl
        ld hl,(pz+2)
        ld (czi),hl
        ld hl,(py+2)
        inc hl
        inc hl
        ld (cyi),hl
        ld hl,(px+1)
        ld a,(px+3)
        call .s4
        ld (cx16),hl
        ld hl,(pz+1)
        ld a,(pz+3)
        call .s4
        ld (cz16),hl
        ld hl,(py+1)
        ld a,(py+3)
        call .s4
        ld de,40
        add hl,de
        ld (cy16),hl
        ret
.s4:    add hl,hl
        rla
        add hl,hl
        rla
        add hl,hl
        rla
        add hl,hl
        rla
        ld l,h
        ld h,a
        ret

buildmat:
        ld de,(snp)
        ld bc,(snr)
        call fmul
        ld (ta),hl
        ld de,(snp)
        ld bc,(csr)
        call fmul
        ld (tb),hl
        ; r0 = csy*csr + sny*ta
        ld de,(csy)
        ld bc,(csr)
        call fmul
        push hl
        ld de,(sny)
        ld bc,(ta)
        call fmul
        pop de
        add hl,de
        ld (q00),hl
        ; r1 = -csp*snr
        ld de,(csp)
        ld bc,(snr)
        call fmul
        call neghl
        ld (q01),hl
        ; r2 = csy*ta - sny*csr
        ld de,(csy)
        ld bc,(ta)
        call fmul
        push hl
        ld de,(sny)
        ld bc,(csr)
        call fmul
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld (q02),hl
        ; u0 = csy*snr - sny*tb
        ld de,(csy)
        ld bc,(snr)
        call fmul
        push hl
        ld de,(sny)
        ld bc,(tb)
        call fmul
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld (q10),hl
        ; u1 = csp*csr
        ld de,(csp)
        ld bc,(csr)
        call fmul
        ld (q11),hl
        ; u2 = -(csy*tb + sny*snr)
        ld de,(csy)
        ld bc,(tb)
        call fmul
        push hl
        ld de,(sny)
        ld bc,(snr)
        call fmul
        pop de
        add hl,de
        call neghl
        ld (q12),hl
        ; f0 = sny*csp ; f1 = snp ; f2 = csy*csp
        ld de,(sny)
        ld bc,(csp)
        call fmul
        ld (q20),hl
        ld hl,(snp)
        ld (q21),hl
        ld de,(csy)
        ld bc,(csp)
        call fmul
        ld (q22),hl
        ; ---- convert Q15 -> (magnitude 0..255, sign)
        ld hl,q00
        ld de,m00
        ld b,9
.cv:    ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld l,c
        ld h,a
        ld c,0
        bit 7,h
        jr z,.p
        call neghl
        inc c
.p:     ld a,l
        add a,64
        ld l,a
        jr nc,.q
        inc h
.q:     add hl,hl
        ld a,h
        jr nc,.r
        ld a,255
.r:     ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
        pop hl
        djnz .cv
        ret

; ---------------------------------------------------------------- horizon / background
drawbg: ld hl,(q01)
        sra h
        rr l
        sra h
        rr l
        ld (bux),hl
        bit 7,h
        call nz,neghl
        ld (aux),hl
        ld hl,(q11)
        sra h
        rr l
        sra h
        rr l
        ld (buy),hl
        bit 7,h
        call nz,neghl
        ld (auy),hl
        ld hl,(q21)
        sra h
        rr l
        sra h
        rr l
        ld (buz),hl
        bit 7,h
        call nz,neghl
        ld (auz),hl
        ld a,(bux+1)
        rlca
        jr c,.sw
        ld a,(gndcol)
        ld (lcol),a
        ld a,(skycol)
        ld (rcol),a
        jr .cs
.sw:    ld a,(skycol)
        ld (lcol),a
        ld a,(gndcol)
        ld (rcol),a
.cs:    ld hl,(aux)
        ld de,(auy)
        or a
        sbc hl,de
        jp c,.shallow
        ; ---- steep: |ux| >= |uy|
        ld hl,(aux)
        ld a,h
        or l
        jp z,.uniform
        call .slope
        ld de,(auz)
        ld bc,1536
        call umul16
        ld bc,(aux)
        call udiv32
        jp c,.uniform
        ld a,h
        cp $7f
        jp nc,.uniform
        ld a,(bux+1)
        ld b,a
        ld a,(buz+1)
        xor b
        call p,neghl
        call sext7
        ld (bgx),hl
        ld (bgx+2),de
        ld hl,(slope)
        call sext7
        ld (bginc),hl
        ld (bginc+2),de
        ld b,24
.s24:   ld hl,(bgx)
        ld de,(bginc)
        or a
        sbc hl,de
        ld (bgx),hl
        ld hl,(bgx+2)
        ld de,(bginc+2)
        sbc hl,de
        ld (bgx+2),hl
        djnz .s24
        jp .bias
.slope: ld de,(auy)
        ld bc,24
        call umul16
        ld bc,(aux)
        call udiv32
        ret c
        bit 7,h
        scf
        ret nz
        ld a,(bux+1)
        ld b,a
        ld a,(buy+1)
        xor b
        call m,neghl
        ld (slope),hl
        or a
        ret
.getyc: ld de,(auz)
        ld bc,8192
        call umul16
        ld bc,(auy)
        call udiv32
        ret c
        ld a,h
        cp $3f
        ccf
        ret c
        ld a,(buy+1)
        ld b,a
        ld a,(buz+1)
        xor b
        call m,neghl
        or a
        ret
.shallow:
        ld hl,(aux)
        ld a,h
        or l
        jp z,.flat
        call .slope
        jp c,.flat
        call .getyc
        jp c,.uniform
        ex de,hl
        ld hl,-3072
        or a
        sbc hl,de
        ex de,hl
        ld bc,(slope)
        call smul16
        ld (bgx),hl
        ld (bgx+2),de
        ld hl,(slope)
        call sext7
        ld (bginc),hl
        ld (bginc+2),de
.bias:  ld hl,(bgx+2)
        inc hl
        inc hl
        ld (bgx+2),hl
        ; ---- row loop
        ld hl,buf
        ld (bgrow),hl
        ld b,48
.row:   push bc
        ld hl,(bgrow)
        ld a,(bgx+3)
        or a
        jp m,.rz
        jr nz,.rf
        ld a,(bgx+2)
        cp 4
        jr nc,.rf
        rrca
        rrca
        rrca
        ld c,a
        ld a,(bgx+1)
        rrca
        rrca
        rrca
        and $1f
        or c
        jr z,.rz
        ld c,a
        rrca
        rrca
        and $3f
        ld d,a
        ld a,(lcol)
        inc d
        dec d
        jr z,.nl0
        ld b,d
.f1:    ld (hl),a
        inc hl
        djnz .f1
.nl0:   ld a,c
        and 3
        jr z,.nm
        push hl
        ld e,a
        ld d,0
        ld hl,mixmask-1
        add hl,de
        ld e,(hl)
        pop hl
        ld a,(lcol)
        and e
        ld d,a
        ld a,e
        cpl
        ld e,a
        ld a,(rcol)
        and e
        or d
        ld (hl),a
        inc hl
.nm:    ld a,l
        and $1f
        jr z,.rdone
        ld b,a
        ld a,32
        sub b
        ld b,a
        ld a,(rcol)
.f2:    ld (hl),a
        inc hl
        djnz .f2
        jr .rdone
.rz:    ld a,(rcol)
        call fill32
        jr .rdone
.rf:    ld a,(lcol)
        call fill32
.rdone: ld (bgrow),hl
        ld hl,(bgx)
        ld de,(bginc)
        add hl,de
        ld (bgx),hl
        ld hl,(bgx+2)
        ld de,(bginc+2)
        adc hl,de
        ld (bgx+2),hl
        pop bc
        dec b
        jp nz,.row
        ret
.flat:  call .getyc
        jr c,.uniform
        ld de,127
        add hl,de
        add hl,hl
        ld l,h
        ld a,h
        add a,a
        sbc a,a
        ld h,a
        ld de,24
        add hl,de
        bit 7,h
        jr z,.fl1
        ld hl,0
.fl1:   ld a,l
        cp 49
        jr c,.fl2
        ld a,48
.fl2:   ld b,a
        ld a,(skycol)
        ld c,a
        ld a,(gndcol)
        ld (bgoth),a
        ld a,(buy+1)
        rlca
        jr nc,.fu
        ld a,(gndcol)
        ld c,a
        ld a,(skycol)
        ld (bgoth),a
.fu:    ld hl,buf
        ld a,b
        or a
        jr z,.fl3
        push bc
        call fillrows
        pop bc
.fl3:   ld a,48
        sub b
        ret z
        ld b,a
        ld a,(bgoth)
        ld c,a
        jp fillrows
.uniform:
        ld a,(buz+1)
        rlca
        ld a,(skycol)
        jr nc,.u0
        ld a,(gndcol)
.u0:    ld c,a
.u1:    ld hl,buf
        ld b,48
        jp fillrows

; fill B rows of colour C at HL
fillrows:
        ld a,c
.r:     call fill32
        djnz .r
        ret

; DE:HL = sign-extended HL << 7
sext7:  ld a,h
        add a,a
        sbc a,a
        ld d,a
        ld e,h
        ld h,l
        ld l,0
        sra d
        rr e
        rr h
        rr l
        ret

; ---------------------------------------------------------------- 3D pipeline
; work point format (10 bytes): x,y,z (halved view coords), code, tcode, X, Y

; guard-frustum outcode of wpm -> A   (bit0 near, 1 left, 2 right, 3 top, 4 bottom)
ocode:  ld c,0
        ld hl,(wpm+4)
        ld de,(nearh)
        or a
        sbc hl,de
        jp p,.z1
        set 0,c
.z1:    ld hl,(wpm+4)
        ld de,(wpm+0)
        push hl
        add hl,de
        bit 7,h
        jr z,.x1
        set 1,c
.x1:    pop hl
        or a
        sbc hl,de
        jp p,.x2
        set 2,c
.x2:    ld hl,(wpm+4)
        sra h
        rr l
        ld de,(wpm+2)
        push hl
        or a
        sbc hl,de
        jp p,.y1
        set 3,c
.y1:    pop hl
        add hl,de
        bit 7,h
        jr z,.y2
        set 4,c
.y2:    ld a,c
        ret

; tight (just outside the screen) outcode of wpm -> A
tcode:  ld c,0
        ld hl,(wpm+4)
        sra h
        rr l
        ld d,h
        ld e,l
        sra d
        rr e
        push de
        add hl,de
        ex de,hl
        ld hl,(wpm+0)
        push hl
        add hl,de
        bit 7,h
        jr z,.t1
        set 1,c
.t1:    pop hl
        or a
        sbc hl,de
        jp m,.t2
        set 2,c
.t2:    pop hl
        ld d,h
        ld e,l
        sra d
        rr e
        add hl,de
        sra d
        rr e
        add hl,de
        ex de,hl
        ld hl,(wpm+2)
        push hl
        or a
        sbc hl,de
        jp m,.t3
        set 3,c
.t3:    pop hl
        add hl,de
        bit 7,h
        jr z,.t4
        set 4,c
.t4:    ld a,c
        ret

; A = min(128, 128*|HL| / z) using zn/zsh ; sign of HL kept in psgn
pdiv:   ld a,h
        ld (psgn),a
        or a
        call m,neghl
        ld a,(zsh)
        or a
        jr z,.ns
        ld b,a
.sh:    srl h
        rr l
        djnz .sh
.ns:    ld a,(zn)
        ld c,a
        ld a,h
        or a
        jr nz,.max
        ld a,l
        cp c
        jr nc,.max
        ld l,0
        ld b,7
.d:     sla l
        add a,a
        jr c,.s
        cp c
        jr c,.n
.s:     sub c
        inc l
.n:     djnz .d
        ld a,l
        ret
.max:   ld a,128
        ret

; project wpm (inside guard) -> B = X (sx+32, 0..192), C = Y (sy+8, 0..64)
projpm: ld hl,(wpm+4)
        ld b,0
.nl:    ld a,h
        or a
        jr z,.zd
        srl h
        rr l
        inc b
        jr .nl
.zd:    ld a,l
        ld (zn),a
        ld a,b
        ld (zsh),a
        ld hl,(wpm+0)
        call pdiv
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        inc hl
        inc hl
        srl h
        rr l
        srl h
        rr l
        ld a,(psgn)
        or a
        ld a,96
        jp m,.xn
        add a,l
        jr .xs
.xn:    sub l
.xs:    push af
        ld hl,(wpm+2)
        call pdiv
        inc a
        srl a
        ld l,a
        ld a,(psgn)
        or a
        ld a,32
        jp m,.yn
        sub l
        jr nc,.ys
        xor a
        jr .ys
.yn:    add a,l
        cp 65
        jr c,.ys
        ld a,64
.ys:    ld c,a
        pop af
        ld b,a
        ret

projwpi:
        ld hl,wpi
        ld de,wpm
        ld bc,6
        ldir
        jp projpm

; finish vertex in wpm (coords set): codes, projection, store to record at IY
vfin:   call ocode
        ld (wpm+6),a
        push af
        call tcode
        ld (wpm+7),a
        pop af
        or a
        jr nz,.st
        call projpm
        ld a,b
        ld (wpm+8),a
        ld a,c
        ld (wpm+9),a
.st:    push iy
        pop de
        ld hl,wpm
        ld bc,10
        ldir
        ret

; move the inside point wpi toward the outside point wpo until it is off screen
bisect: ld b,12
.l:     push bc
        call midio
        call ocode
        ld (wpm+6),a
        call tcode
        ld (wpm+7),a
        ld a,(wpm+6)
        or a
        jr nz,.out
        ld hl,wpm
        ld de,wpi
        ld bc,8
        ldir
        ld a,(wpm+7)
        ld hl,wpo+7
        and (hl)
        pop bc
        ret nz
        djnz .l
        ret
.out:   ld hl,wpm
        ld de,wpo
        ld bc,8
        ldir
        pop bc
        djnz .l
        ret

; draw the 3D segment between vertex records IX and IY in colour (linecol)
drawseg:
        ld a,(ix+7)
        and (iy+7)
        ret nz
        ld a,(ix+6)
        and (iy+6)
        ret nz
        ld a,(ix+6)
        or (iy+6)
        jr nz,.clip
        ld a,(ix+8)
        ld (lx0),a
        ld a,(ix+9)
        ld (ly0),a
        ld a,(iy+8)
        ld (lx1),a
        ld a,(iy+9)
        ld (ly1),a
        jp line2d
.clip:  ld a,(ix+6)
        or a
        jr nz,.aout
        push ix
        pop hl
        ld de,wpi
        ld bc,8
        ldir
        push iy
        pop hl
        ld de,wpo
        ld bc,8
        ldir
        ld a,(ix+8)
        ld (lx0),a
        ld a,(ix+9)
        ld (ly0),a
.fin1:  call bisect
        call projwpi
        ld a,b
        ld (lx1),a
        ld a,c
        ld (ly1),a
        jp line2d
.aout:  ld a,(iy+6)
        or a
        jr nz,.both
        push iy
        pop hl
        ld de,wpi
        ld bc,8
        ldir
        push ix
        pop hl
        ld de,wpo
        ld bc,8
        ldir
        ld a,(iy+8)
        ld (lx0),a
        ld a,(iy+9)
        ld (ly0),a
        jr .fin1
.both:  push ix
        pop hl
        ld de,wpa
        ld bc,8
        ldir
        push iy
        pop hl
        ld de,wpb
        ld bc,8
        ldir
        ld b,10
.sl:    push bc
        call midab
        call ocode
        ld (wpm+6),a
        call tcode
        ld (wpm+7),a
        ld a,(wpm+6)
        or a
        jr z,.found
        ld c,a
        ld a,(wpm+7)
        ld b,a
        ld a,(wpa+6)
        and c
        jr nz,.repa
        ld a,(wpa+7)
        and b
        jr nz,.repa
        ld a,(wpb+6)
        and c
        jr nz,.repb
        ld a,(wpb+7)
        and b
        jr nz,.repb
.rej:   pop bc
        ret
.repa:  ld a,(wpb+6)
        and c
        jr nz,.rej
        ld a,(wpb+7)
        and b
        jr nz,.rej
        ld hl,wpm
        ld de,wpa
        ld bc,8
        ldir
        jr .nx
.repb:  ld hl,wpm
        ld de,wpb
        ld bc,8
        ldir
.nx:    pop bc
        djnz .sl
        ret
.found: pop bc
        ld hl,wpm
        ld de,wps
        ld bc,8
        ldir
        ld hl,wpm
        ld de,wpi
        ld bc,8
        ldir
        ld hl,wpb
        ld de,wpo
        ld bc,8
        ldir
        call bisect
        call projwpi
        ld a,b
        ld (lx1),a
        ld a,c
        ld (ly1),a
        ld hl,wps
        ld de,wpi
        ld bc,8
        ldir
        ld hl,wpa
        ld de,wpo
        ld bc,8
        ldir
        call bisect
        call projwpi
        ld a,b
        ld (lx0),a
        ld a,c
        ld (ly0),a
        jp line2d

; ---------------------------------------------------------------- 2D clip + line
; A = (A*E + D/2) / D     keeps HL, DE
muldiv: push hl
        push de
        ld b,e
        call umul8
        pop de
        push de
        ld a,d
        srl a
        add a,l
        ld l,a
        jr nc,.m1
        inc h
.m1:    ld c,d
        ld a,h
        ld b,8
.d:     sla l
        rla
        jr c,.s
        cp c
        jr c,.n
.s:     sub c
        inc l
.n:     djnz .d
        ld a,l
        pop de
        pop hl
        ret

; A = H + (L-H)*E/D
interp: ld a,l
        sub h
        jr nc,.pos
        neg
        call muldiv
        ld b,a
        ld a,h
        sub b
        ret
.pos:   call muldiv
        add a,h
        ret

; line (lx0,ly0)-(lx1,ly1) in offset coords, clipped to the 128x48 view
line2d: ld a,(lx0)
        ld b,a
        ld a,(lx1)
        cp b
        jr nc,.ord
        ld (lx0),a
        ld a,b
        ld (lx1),a
        ld a,(ly0)
        ld b,a
        ld a,(ly1)
        ld (ly0),a
        ld a,b
        ld (ly1),a
.ord:   ld a,(lx1)
        cp 32
        ret c
        ld a,(lx0)
        cp 160
        ret nc
        cp 32
        jr nc,.nl
        ld c,a
        ld a,32
        sub c
        ld e,a
        ld a,(lx1)
        sub c
        ld d,a
        ld a,(ly0)
        ld h,a
        ld a,(ly1)
        ld l,a
        call interp
        ld (ly0),a
        ld a,32
        ld (lx0),a
.nl:    ld a,(lx1)
        cp 160
        jr c,.nr
        ld c,a
        sub 159
        ld e,a
        ld a,(lx0)
        ld b,a
        ld a,c
        sub b
        ld d,a
        ld a,(ly1)
        ld h,a
        ld a,(ly0)
        ld l,a
        call interp
        ld (ly1),a
        ld a,159
        ld (lx1),a
.nr:    ld a,(ly0)
        ld b,a
        ld a,(ly1)
        ld c,a
        ld a,b
        cp 8
        jr nc,.y1
        ld a,c
        cp 8
        ret c
.y1:    ld a,b
        cp 56
        jr c,.y2
        ld a,c
        cp 56
        ret nc
.y2:    ld a,b
        cp 8
        jr nc,.c1
        ld a,8
        sub b
        ld e,a
        ld a,c
        sub b
        ld d,a
        ld a,(lx0)
        ld h,a
        ld a,(lx1)
        ld l,a
        call interp
        ld (lx0),a
        ld a,8
        ld (ly0),a
        jr .c2
.c1:    cp 56
        jr c,.c2
        sub 55
        ld e,a
        ld a,b
        sub c
        ld d,a
        ld a,(lx0)
        ld h,a
        ld a,(lx1)
        ld l,a
        call interp
        ld (lx0),a
        ld a,55
        ld (ly0),a
.c2:    ld a,(ly0)
        ld b,a
        ld a,(ly1)
        ld c,a
        cp 8
        jr nc,.c3
        ld a,8
        sub c
        ld e,a
        ld a,b
        sub c
        ld d,a
        ld a,(lx1)
        ld h,a
        ld a,(lx0)
        ld l,a
        call interp
        ld (lx1),a
        ld a,8
        ld (ly1),a
        jr .c4
.c3:    cp 56
        jr c,.c4
        sub 55
        ld e,a
        ld a,c
        sub b
        ld d,a
        ld a,(lx1)
        ld h,a
        ld a,(lx0)
        ld l,a
        call interp
        ld (lx1),a
        ld a,55
        ld (ly1),a
.c4:    ld a,(lx0)
        sub 32
        ld e,a
        ld a,(ly0)
        sub 8
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,e
        rrca
        rrca
        and $3f
        or l
        ld l,a
        ld a,h
        add a,high(buf)
        ld h,a
        push hl
        ld a,(lx0)
        ld c,a
        ld a,(lx1)
        sub c
        ld (ldx),a
        ld a,(ly0)
        ld c,a
        ld a,(ly1)
        sub c
        ld d,0
        jr nc,.dn
        neg
        ld d,4
.dn:    ld (ldy),a
        ld b,a
        ld a,e
        and 3
        add a,d
        add a,a
        ld e,a
        ld d,0
        ld a,(ldx)
        cp b
        jr c,.ymaj
        call patchx
        ld hl,xmtab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (.jp+1),hl
        ld a,(ldx)
        ld b,a
        inc b
        srl a
        ld e,a
        ld a,(ldy)
        ld c,a
        jr .go
.ymaj:  ld a,(ldy)
        call patchy
        ld hl,ymtab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (.jp+1),hl
        ld a,(ldy)
        ld b,a
        inc b
        srl a
        ld e,a
        ld a,(ldx)
        ld c,a
.go:    ld a,(linecol)
        ld d,a
        pop hl
.jp:    jp 0

; ---------------------------------------------------------------- scenery
drawgrid:
        ld a,(gridcol)
        ld (linecol),a
        ld hl,1
        ld (nearh),hl
        ld hl,(cxi)
        ld de,512
        add hl,de
        ld a,h
        and 3
        ld h,a
        call neghl
        ld (dx),hl
        ld hl,(czi)
        ld de,512
        add hl,de
        ld a,h
        and 3
        ld h,a
        call neghl
        ld (dz),hl
        ld hl,(cyi)
        call neghl
        ld (dy),hl
        call xform
        call gridvec
        call gridx
        jp gridz

drawobjs:
        ld ix,(objp)
.lp:    ld a,(ix+5)
        or a
        ret z
        call drawobj
        ld de,10
        add ix,de
        call poll
        jr .lp

; instance at IX: x(2) z(2) shape(2) s vis fl
drawobj:
        ld l,(ix+0)
        ld h,(ix+1)
        ld de,(cxi)
        or a
        sbc hl,de
        ld (dx),hl
        ld a,h
        or a
        jp p,.a1
        cpl
.a1:    cp (ix+7)
        ret nc
        ld (adx),a
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,(czi)
        or a
        sbc hl,de
        ld (dz),hl
        ld a,h
        or a
        jp p,.a2
        cpl
.a2:    cp (ix+7)
        ret nc
        ld (adz),a
        ld b,(ix+8)
        ld a,(adx)
        cp b
        jr nc,.coarse
        ld a,(adz)
        cp b
        jr nc,.coarse
        ld a,(cyi+1)
        cp b
        jr nc,.coarse
        ; fine mode: 1/16 m units
        ld l,(ix+0)
        ld h,(ix+1)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(cx16)
        or a
        sbc hl,de
        ld (dx),hl
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(cz16)
        or a
        sbc hl,de
        ld (dz),hl
        ld l,(ix+9)
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(cy16)
        or a
        sbc hl,de
        ld (dy),hl
        ld a,4
        sub (ix+6)
        ld (vshift),a
        ld hl,16
        ld (nearh),hl
        jr .xf
.coarse:
        ld l,(ix+9)
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(cyi)
        or a
        sbc hl,de
        ld (dy),hl
        ld a,8
        sub (ix+6)
        ld (vshift),a
        ld hl,1
        ld (nearh),hl
.xf:    call xform
        ; bounding radius (view units) = 1 << (14 - vshift)
        ld a,(vshift)
        ld b,a
        ld a,14
        sub b
        ld b,a
        ld hl,1
.rs:    add hl,hl
        djnz .rs
        srl h
        rr l
        ex de,hl
        ld hl,(o2)
        sra h
        rr l
        sra h
        rr l
        add hl,de
        bit 7,h
        ret nz
        ld (cullz),hl
        ld hl,(o0)
        bit 7,h
        call nz,neghl
        srl h
        rr l
        srl h
        rr l
        ld de,(cullz)
        or a
        sbc hl,de
        jr c,.okx
        ret nz
.okx:   ld hl,(o1)
        bit 7,h
        call nz,neghl
        srl h
        rr l
        srl h
        rr l
        ld de,(cullz)
        or a
        sbc hl,de
        jr c,.oky
        ret nz
.oky:   ld l,(ix+4)
        ld h,(ix+5)
        ld a,(hl)
        ld (nv),a
        inc hl
        ld a,(hl)
        ld (ne),a
        inc hl
        ld iy,vtab
.vl:    ld a,(hl)
        ld (kx),a
        inc hl
        ld a,(hl)
        ld (ky),a
        inc hl
        ld a,(hl)
        ld (kz),a
        inc hl
        push hl
        ld hl,0
        ld (acc0),hl
        ld (acc1),hl
        ld (acc2),hl
        ld a,(kx)
        or a
        call nz,addcol0
        ld a,(ky)
        or a
        call nz,addcol1
        ld a,(kz)
        or a
        call nz,addcol2
        call vcoords
        call vfin
        pop hl
        ld de,10
        add iy,de
        ld a,(nv)
        dec a
        ld (nv),a
        jr nz,.vl
        push ix
.el:    ld a,(hl)
        inc hl
        call mul10
        ld ix,vtab
        add ix,de
        ld a,(hl)
        inc hl
        call mul10
        ld iy,vtab
        add iy,de
        ld a,(hl)
        inc hl
        ld (linecol),a
        push hl
        call drawseg
        call poll
        pop hl
        ld a,(ne)
        dec a
        ld (ne),a
        jr nz,.el
        pop ix
        ret

mul10:  ld e,a
        add a,a
        add a,a
        add a,e
        add a,a
        ld e,a
        ld d,0
        ret

; ---------------------------------------------------------------- text
; opaque char A at DE (screen/buffer address of top byte), DE advances one column
pchar:  push hl
        push bc
        push de
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        ld bc,font
        add hl,bc
        ld b,5
.l:     ld c,(hl)
        inc hl
        ld a,c
pc_ink  equ $+1
        and $55
        ex af,af'
        ld a,c
        cpl
pc_pap  equ $+1
        and $aa
        ld c,a
        ex af,af'
        or c
        ld (de),a
        ld a,e
        add a,32
        ld e,a
        jr nc,.n
        inc d
.n:     djnz .l
        pop de
        inc de
        pop bc
        pop hl
        ret

; transparent char A at DE
ochar:  push hl
        push bc
        push de
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        ld bc,font
        add hl,bc
        ld b,5
.l:     ld c,(hl)
        inc hl
        ld a,(de)
oc_ink  equ $+1
        xor $ff
        and c
        ld c,a
        ld a,(de)
        xor c
        ld (de),a
        ld a,e
        add a,32
        ld e,a
        jr nc,.n
        inc d
.n:     djnz .l
        pop de
        inc de
        pop bc
        pop hl
        ret

ptext:  ld a,(hl)
        inc hl
        cp $ff
        ret z
        call chout
        jr ptext

; multi-line text: $fe = next line (6 rows down from the line start in (lnstart))
ptextm: ld (lnstart),de
.l:     ld a,(hl)
        inc hl
        cp $ff
        ret z
        cp $fe
        jr z,.nl
        call chout
        jr .l
.nl:    push hl
        ld hl,(lnstart)
        ld de,6*32
        add hl,de
        ld (lnstart),hl
        ex de,hl
        pop hl
        jr .l

; centred text: HL text, DE = start of the row
ptextc: push hl
        ld b,0
.c:     ld a,(hl)
        inc hl
        cp $ff
        jr z,.e
        inc b
        jr .c
.e:     ld a,32
        sub b
        srl a
        add a,e
        ld e,a
        jr nc,.n
        inc d
.n:     pop hl
        jr ptext

chout:  jp pchar
setopq: push hl
        ld hl,pchar
        ld (chout+1),hl
        pop hl
        ret
settrn: push hl
        ld hl,ochar
        ld (chout+1),hl
        pop hl
        ret

; print HL as B decimal digits at DE
prnum:  push de
        ld a,5
        sub b
        add a,a
        ld e,a
        ld d,0
        ld ix,p10tab
        add ix,de
        pop de
.dl:    push bc
        ld c,(ix+0)
        ld b,(ix+1)
        xor a
.s:     or a
        sbc hl,bc
        jr c,.dn
        inc a
        jr .s
.dn:    add hl,bc
        pop bc
        call chout
        inc ix
        inc ix
        djnz .dl
        ret



