;=====================================================================
; 3D HUMAN ENGINE (mode(1) 128x64, CSS0: 0 green 1 yellow 2 blue 3 red)
; Articulated skeleton (16 joints) from interpolated keyframes, rotated
; by an orbiting camera with perspective, rendered as depth-sorted
; shaded spheres: pre-shifted 2bpp sprites for r<=9, shaded span
; discs for larger radii (close-ups). Back buffer 64 bytes x 64 rows,
; visible window = bytes 16..47 (BB x pixels 64..191).
;=====================================================================
BB      equ $E800           ; main RAM (bank 3 at $4000 holds assets)
CURJ    equ $7800           ; 16 joints x 3 signed bytes
PJ      equ $7830           ; 16 x 8: bx(2) by(2) z K(2) -
SPL     equ $78B0           ; 80 x 8: bx by(2) z r kind
ORD     equ $7B30           ; draw order (80)
MAT     equ $7B80           ; m00 m02 m10 m11 m12 m20 m21 m22
HV      equ $7B90           ; human vars
NSPH    equ HV+0
CAMTX   equ HV+1
CAMTY   equ HV+2
CAMTZ   equ HV+3
ZOOM    equ HV+4            ; 16-bit 8.8 px per unit
YAW     equ HV+6
PITCH   equ HV+7
HEADYAW equ HV+8
EYES    equ HV+9            ; 0 closed 1 open
BREATH  equ HV+10           ; signed radius add for chest
FEATON  equ HV+11
HTMP    equ $7BC0           ; 48 bytes scratch
SBUCK   equ $F9C0           ; 64 sort buckets (shares tunnel RAM; never concurrent)
HKEY    equ HV+12
HFR     equ HV+14
GHOST   equ HV+15
GHRISE  equ HV+16
GHSHR   equ HV+17
BGCOL   equ HV+18
NOFIG   equ HV+19
HEXTRA  equ HV+20           ; hook (2)
HPOST   equ HV+22           ; hook (2)
DBX     equ HV+24
DBY     equ HV+25           ; 2
DRR     equ HV+27
DKIND   equ HV+28
BTI     equ HV+29
BROWS   equ HV+30
BSTART  equ HV+31
BCOL    equ HV+32
BY0     equ HV+33           ; 2
BRL     equ HV+35
BLX     equ HV+36
BLDY    equ HV+37
BRH     equ HV+38
BHX     equ HV+39
BHDY    equ HV+40
BDY     equ HV+41
BYR     equ HV+42
BOL     equ HV+43           ; 2
BSY     equ HV+45
BBASE   equ HV+46           ; 2
BKND    equ HV+48

;---------------------------------------------------------------------
; animate: HL = pointer to first key of segment, A = number of keys,
;          DE = local time (frames). Fills CURJ.
animate:
        ld (HTMP),a
        push hl
        ; key index = t>>5, frac = (t&31)<<3
        ld a,e
        and 31
        add a,a
        add a,a
        add a,a
        ld (HFR),a
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e                    ; DE = key index
        ld a,(HTMP)
        dec a                   ; last index
        ld c,a
        ld a,d
        or a
        jr nz,.last
        ld a,e
        cp c
        jr c,.ok
.last:  ld e,c
        xor a
        ld (HFR),a
.ok:    ; HL += e*48
        ld d,0
        ld h,d
        ld l,e
        add hl,hl
        add hl,de               ; *3
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *48
        pop de
        add hl,de               ; key k
        ld de,CURJ
        ld b,48
        ld a,(HFR)
        or a
        jr nz,.interp
.cp:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .cp
        ret
.interp:
        push bc
        ld a,(hl)               ; a0
        push hl
        ld bc,48
        add hl,bc
        ld c,(hl)               ; a1
        pop hl
        push de
        ld a,c
        sub (hl)                ; diff (signed, may overflow for big jumps: keys are smooth)
        ld e,a
        ld a,(HFR)
        push hl
        call mulsu2             ; HL = diff*frac (diff signed in E, frac unsigned in A)
        ld a,h
        pop hl
        add a,(hl)
        pop de
        ld (de),a
        inc hl
        inc de
        pop bc
        ld a,b
        and 7
        jr nz,.nt
        TICK
.nt:    djnz .interp
        ret

; E signed * A unsigned -> HL
mulsu2: ld d,a
        ld a,e
        ld e,d
        jp mulsu

;---------------------------------------------------------------------
; camera matrix from YAW/PITCH
cammat: ld a,(YAW)
        call cos8
        ld (HTMP),a             ; ct
        ld a,(YAW)
        call sin8
        ld (HTMP+1),a           ; st
        ld a,(PITCH)
        call cos8
        ld (HTMP+2),a           ; cp
        ld a,(PITCH)
        call sin8
        ld (HTMP+3),a           ; sp
        ld a,(HTMP)
        ld (MAT+0),a            ; m00 = ct
        ld a,(HTMP+1)
        ld (MAT+1),a            ; m02 = st
        ld a,(HTMP+3)
        ld (MAT+6),a            ; m21 = sp
        ld a,(HTMP+2)
        ld (MAT+3),a            ; m11 = cp
        ; m10 = st*sp
        ld a,(HTMP+1)
        ld hl,HTMP+3
        ld e,(hl)
        call muls
        call hl7
        ld (MAT+2),a
        ; m12 = -ct*sp
        ld a,(HTMP+3)
        ld e,a
        ld a,(HTMP)
        call muls
        call hl7
        neg
        ld (MAT+4),a
        ; m20 = -st*cp
        ld a,(HTMP+1)
        ld hl,HTMP+2
        ld e,(hl)
        call muls
        call hl7
        neg
        ld (MAT+5),a
        ; m22 = ct*cp
        ld a,(HTMP+2)
        ld e,a
        ld a,(HTMP)
        call muls
        call hl7
        ld (MAT+7),a
        ret

; A = HL >> 7 (signed, result byte)
hl7:    push hl
        add hl,hl
        ld a,h
        pop hl
        ret

; rotate (B=vx, C=vy, D=vz signed) -> B=x1, C=y2, D=z2 (signed bytes)
rot3:   ld a,b
        ld (HTMP+4),a           ; vx
        ld a,c
        ld (HTMP+5),a           ; vy
        ld a,d
        ld (HTMP+6),a           ; vz
        ; x1 = vx*m00 + vz*m02
        ld a,(MAT+0)
        ld e,b
        call muls
        push hl
        ld a,(MAT+1)
        ld e,d
        call muls
        pop de
        add hl,de
        call hl7
        ld (HTMP+7),a
        TICK
        ; y2 = vx*m10 + vy*m11 + vz*m12
        ld a,(HTMP+4)
        ld e,a
        ld a,(MAT+2)
        call muls
        push hl
        ld a,(HTMP+5)
        ld e,a
        ld a,(MAT+3)
        call muls
        push hl
        ld a,(HTMP+6)
        ld e,a
        ld a,(MAT+4)
        call muls
        pop de
        add hl,de
        pop de
        add hl,de
        call hl7
        ld (HTMP+8),a
        TICK
        ; z2 = vx*m20 + vy*m21 + vz*m22
        ld a,(HTMP+4)
        ld e,a
        ld a,(MAT+5)
        call muls
        push hl
        ld a,(HTMP+5)
        ld e,a
        ld a,(MAT+6)
        call muls
        push hl
        ld a,(HTMP+6)
        ld e,a
        ld a,(MAT+7)
        call muls
        pop de
        add hl,de
        pop de
        add hl,de
        call hl7
        ld d,a
        ld a,(HTMP+7)
        ld b,a
        ld a,(HTMP+8)
        ld c,a
        TICK
        ret

; project rotated point (B=x1,C=y2,D=z2) -> IX entry: bx,by,z,K
; K = ZOOM*P/128 ; bx = 128 + x1*K*1.5/256 ; by = 32 - y2*K/256
proj:   ld a,d
        ld (ix+4),a
        add a,128
        ld l,a
        ld h,PTAB>>8
        ld a,(hl)               ; P (128 = 1.0)
        push bc
        ; K = ZOOM * P >> 7
        ld e,a
        ld a,(ZOOM+1)
        call mulu               ; HL = Zh*P
        push hl
        ld a,(ZOOM)
        call mulu               ; HL = Zl*P
        ld l,h
        ld h,0
        pop de
        add hl,de               ; ZOOM*P >> 8
        add hl,hl               ; >>7
        ld (ix+5),l
        ld (ix+6),h
        TICK
        pop bc
        ; by = 32 - (y2*K)>>8
        push bc
        ld a,c
        call mulsK              ; HL = (A*K)>>8 signed
        ex de,hl
        ld hl,32
        or a
        sbc hl,de
        ld (ix+2),l
        ld (ix+3),h
        TICK
        pop bc
        ; bx = 128 + 1.5*(x1*K)>>8
        ld a,b
        call mulsK
        ld d,h
        ld e,l
        sra d
        rr e
        add hl,de
        ld de,128
        add hl,de
        ld (ix+0),l
        ld (ix+1),h
        TICK
        ret

; HL = (A signed * K) >> 8, K at (ix+5)
mulsK:  ld c,a
        ld e,(ix+6)
        call mulsu              ; HL = a*Kh
        push hl
        ld a,c
        ld e,(ix+5)
        call mulsu              ; a*Kl
        ; >>8 with sign
        ld a,h
        ld l,a
        rla
        sbc a,a
        ld h,a
        pop de
        add hl,de
        ret

;---------------------------------------------------------------------
; project all 16 joints relative to camera target
projall:
        call cammat
        ld hl,CURJ
        ld ix,PJ
        ld b,16
.l:     push bc
        push hl
        ld a,(CAMTX)
        ld c,a
        ld a,(hl)
        sub c
        ld b,a
        inc hl
        ld a,(CAMTY)
        ld c,a
        ld a,(hl)
        sub c
        ld c,a
        inc hl
        ld a,(CAMTZ)
        ld d,a
        ld a,(hl)
        sub d
        ld d,a
        call rot3
        call proj
        ld de,8
        add ix,de
        pop hl
        inc hl
        inc hl
        inc hl
        pop bc
        djnz .l
        ret

;---------------------------------------------------------------------
; HL = PJ + A*8
jptr:   add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,PJ
        add hl,de
        ret

; HL = a, DE = b, (HTMP+9) = t  -> HL = a + (b-a)*t/256
lerp16: push hl
        ex de,hl
        or a
        sbc hl,de               ; diff
        push hl
        ld a,(HTMP+9)
        ld e,a
        ld a,l
        call mulu
        ld c,h
        pop hl
        ld a,(HTMP+9)
        ld e,a
        ld a,h
        push bc
        call mulsu
        pop bc
        ld b,0
        add hl,bc
        pop de
        add hl,de
        ret

;---------------------------------------------------------------------
; Build sphere list from SPHT. Entry: bx,by(16) z(biased) r kind
buildsph:
        xor a
        ld (NSPH),a
        ld a,(NOFIG)
        or a
        ret nz
        ld hl,SPHT
        ld b,NSPHT
.l:     push bc
        push hl
        ld a,(hl)               ; joint A
        ld (HTMP+20),a
        inc hl
        ld a,(hl)               ; joint B
        ld (HTMP+21),a
        inc hl
        ld a,(hl)               ; t
        ld (HTMP+9),a
        inc hl
        ld a,(hl)               ; rad16
        ld (HTMP+22),a
        ld a,(FEATON)
        or a
        jr z,.all
        ld a,b
        cp NSPHT-2
        jr nc,.skp              ; entries 0..2 skipped in close-ups
        cp NSPHT-6
        jr c,.skp               ; entries after the head skipped
.all:   ld a,b
        cp NSPHT-3              ; 4th entry = chest: breathing
        jr nz,.nb
        ld a,(BREATH)
        ld hl,HTMP+22
        add a,(hl)
        ld (hl),a
.nb:    call sphAB
        ld a,(HTMP+22)
        ld e,a
        xor a
        call addsph
        TICK
.skp:   pop hl
        ld de,4
        add hl,de
        pop bc
        djnz .l
        ret


; joints (HTMP+20/21), t (HTMP+9) -> HTMP+10: bx(2) by(2) z K(2)
sphAB:  ld a,(HTMP+20)
        call jptr
        ld (HTMP+23),hl         ; pa
        ld a,(HTMP+21)
        call jptr
        ld (HTMP+25),hl         ; pb
        ld a,(HTMP+9)
        or a
        jr nz,.lp
        ld hl,(HTMP+23)
        ld de,HTMP+10
        ld bc,7
        ldir
        ret
.lp:    ld c,0
        call lerpq              ; bx
        ld c,2
        call lerpq              ; by
        ; K from joint A
        ld hl,(HTMP+23)
        ld de,5
        add hl,de
        ld a,(hl)
        ld (HTMP+15),a
        inc hl
        ld a,(hl)
        ld (HTMP+16),a
        ; z: 8-bit
        ld hl,(HTMP+23)
        ld de,4
        add hl,de
        ld c,(hl)
        ld hl,(HTMP+25)
        add hl,de
        ld a,(hl)
        sub c
        jp pe,.zbig             ; overflow -> 16-bit
        ld e,a
        ld a,(HTMP+9)
        call mulsu2
        ld a,h
        add a,c
        ld (HTMP+14),a
        ret
.zbig:  ld a,c
        ld (HTMP+14),a
        ret

; quick lerp of the 16-bit field at C: one 8x8 multiply when |b-a| < 128
lerpq:  ld b,0
        ld hl,(HTMP+25)
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)               ; b
        ld hl,(HTMP+23)
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; a
        push hl
        ex de,hl
        or a
        sbc hl,de               ; b - a
        ld a,l
        rla
        ld a,h
        adc a,0
        jr nz,.wide             ; not representable as a signed byte
        ld e,l
        ld a,(HTMP+9)
        push bc
        call mulsu2             ; (b-a)*t
        pop bc
        ld e,h                  ; >>8 with sign
        ld a,h
        rla
        sbc a,a
        ld d,a
        pop hl
        add hl,de
        jr .st
.wide:  pop hl
        push bc
        ld de,(HTMP+25)
        ld a,c
        add a,e
        ld e,a
        jr nc,.w1
        inc d
.w1:    ex de,hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
        call lerp16
        pop bc
.st:    ex de,hl
        ld hl,HTMP+10
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; lerp 16-bit field at offset C between pa/pb into HTMP+10+C
lerpf:  ld b,0
        ld hl,(HTMP+23)
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        ld hl,(HTMP+25)
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        push bc
        call lerp16
        pop bc
        ex de,hl
        ld hl,HTMP+10
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        ret

;---------------------------------------------------------------------
; append sphere: HTMP+10 bx(2) by(2) z K(2); E = rad16, A = kind
addsph: ld (HTMP+27),a
        ld hl,(HTMP+15)         ; K
        ld a,h
        cp 16
        ld a,46
        jr nc,.big              ; K >= 4096: huge (clamp)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h                  ; K>>4 (0..255)
        call mulu               ; rad*K>>4
        ld a,h                  ; >>8  -> rad*K>>12
        or a
        jr nz,.nz
        inc a
.nz:    cp 47
        jr c,.big
        ld a,46
.big:   ld (HTMP+28),a          ; r
        ; vertical cull: by+r >= 0 and by-r <= 63
        ld e,a
        ld d,0
        ld hl,(HTMP+12)
        add hl,de
        bit 7,h
        ret nz
        ld hl,(HTMP+12)
        or a
        sbc hl,de
        bit 7,h
        jr nz,.vok
        ld a,h
        or a
        ret nz
        ld a,l
        cp 64
        ret nc
.vok:   ; horizontal: W = r + r/2 ; need W <= bx <= 255-W
        ld a,(HTMP+28)
        ld e,a
        srl a
        add a,e
        ld e,a                  ; W
        ld hl,(HTMP+10)
        ld a,h
        or a
        ret nz                  ; bx outside 0..255
        ld a,l
        cp e
        ret c
        add a,e
        ret c
        ; append
        ld a,(NSPH)
        cp 79
        ret nc
        ld l,a
        inc a
        ld (NSPH),a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,SPL
        add hl,de
        ld a,(HTMP+10)
        ld (hl),a
        inc hl
        ld a,(HTMP+12)
        ld (hl),a
        inc hl
        ld a,(HTMP+13)
        ld (hl),a
        inc hl
        ld a,(HTMP+14)
        add a,128
        ld (hl),a
        inc hl
        ld a,(HTMP+28)
        ld (hl),a
        inc hl
        ld a,(HTMP+27)
        ld (hl),a
        ret

;---------------------------------------------------------------------
; world-space sphere (B=x,C=y,D=z body units; E=rad16; A=kind)
addworld:
        push af
        push de
        ld a,(CAMTX)
        ld e,a
        ld a,b
        sub e
        ld b,a
        ld a,(CAMTY)
        ld e,a
        ld a,c
        sub e
        ld c,a
        ld a,(CAMTZ)
        ld e,a
        ld a,d
        sub e
        ld d,a
        call rot3
        ld ix,HTMP+10
        call proj
        pop de
        pop af
        jp addsph

;---------------------------------------------------------------------
; face features (lying frame) around the head joint
feats:  ld a,(FEATON)
        or a
        ret z
        ld a,(HEADYAW)
        call cos8
        ld (HTMP+29),a
        ld a,(HEADYAW)
        call sin8
        ld (HTMP+30),a
        ld hl,FEATT
        ld b,NFEAT
.l:     push bc
        push hl
        ; ox = (a*c + cc*s)>>7 ; oy = (-a*s + cc*c)>>7 ; oz = -b
        ld a,(hl)
        ld (HTMP+0),a           ; a
        inc hl
        ld a,(hl)
        neg
        ld (HTMP+2),a           ; oz
        inc hl
        ld a,(hl)
        ld (HTMP+1),a           ; c
        inc hl
        ld a,(hl)
        ld (HTMP+3),a           ; rad16
        inc hl
        ld a,(hl)
        ld (HTMP+31),a          ; kind
        ld a,(HTMP+0)
        ld hl,HTMP+29
        ld e,(hl)
        call muls
        push hl
        ld a,(HTMP+1)
        ld hl,HTMP+30
        ld e,(hl)
        call muls
        pop de
        add hl,de
        call hl7
        ld b,a                  ; ox
        TICK
        push bc
        ld a,(HTMP+0)
        neg
        ld hl,HTMP+30
        ld e,(hl)
        call muls
        push hl
        ld a,(HTMP+1)
        ld hl,HTMP+29
        ld e,(hl)
        call muls
        pop de
        add hl,de
        call hl7
        pop bc
        ld c,a                  ; oy
        ld a,(HTMP+2)
        ld d,a
        call rot3               ; B,C,D fine units camera space
        ; screen from head joint PJ+24
        ld ix,PJ+24
        push de
        push bc
        ld a,b
        call mulsK              ; (x1*K)>>8
        call sra2
        ld d,h
        ld e,l
        sra d
        rr e
        add hl,de
        ld e,(ix+0)
        ld d,(ix+1)
        add hl,de
        ld (HTMP+10),hl
        TICK
        pop bc
        ld a,c
        call mulsK
        call sra2
        ex de,hl
        ld l,(ix+2)
        ld h,(ix+3)
        or a
        sbc hl,de
        ld (HTMP+12),hl
        pop de
        ld a,d
        sra a
        sra a
        add a,(ix+4)
        ld (HTMP+14),a
        ld a,(ix+5)
        ld (HTMP+15),a
        ld a,(ix+6)
        ld (HTMP+16),a
        TICK
        ; kind handling
        ld a,(HTMP+3)
        ld e,a
        ld a,(HTMP+31)
        cp 2
        jr nz,.nk
        ld a,(EYES)
        or a
        jr nz,.open
        srl e
        ld a,1
        call addsph
        jr .nx
.open:  push de                 ; red rim, eye white, blue pupil
        ld a,e
        add a,5
        ld e,a
        ld hl,HTMP+14
        dec (hl)
        ld a,1
        call addsph
        ld hl,HTMP+14
        inc (hl)
        pop de
        ld a,2
        push de
        call addsph
        pop de
        srl e
        ld hl,HTMP+14
        inc (hl)
        ld a,3
        call addsph
        jr .nx
.nk:    cp 3
        jr nz,.nk2
        ld hl,HTMP+14
        ld a,(hl)
        sub 6
        ld (hl),a
        ld a,1
.nk2:   call addsph
.nx:    TICK
        pop hl
        ld de,5
        add hl,de
        pop bc
        dec b
        jp nz,.l
        ret

sra2:   sra h
        rr l
        sra h
        rr l
        ret

;---------------------------------------------------------------------
; depth sort far -> near: counting sort on z>>2 (64 buckets)
hsort:  ld a,(NSPH)
        or a
        ret z
        ld hl,SBUCK
        ld b,64
.z:     ld (hl),0
        inc hl
        djnz .z
        ; count
        ld a,(NSPH)
        ld b,a
        ld hl,SPL+3
.c:     ld a,(hl)
        rrca
        rrca
        and 63
        push hl
        add a,SBUCK&255
        ld l,a
        ld h,SBUCK>>8
        inc (hl)
        pop hl
        ld de,8
        add hl,de
        ld a,b
        and 7
        call z,snd
        djnz .c
        TICK
        ; prefix sums -> start positions
        ld hl,SBUCK
        ld b,64
        xor a
.p:     ld c,(hl)
        ld (hl),a
        add a,c
        inc hl
        djnz .p
        ; place
        ld a,(NSPH)
        ld b,a
        ld c,0
        ld hl,SPL+3
.s:     ld a,(hl)
        rrca
        rrca
        and 63
        push hl
        add a,SBUCK&255
        ld l,a
        ld h,SBUCK>>8
        ld a,(hl)
        inc (hl)
        ld l,a
        ld h,0
        ld de,ORD
        add hl,de
        ld (hl),c
        pop hl
        ld de,8
        add hl,de
        inc c
        ld a,c
        and 7
        call z,snd
        djnz .s
        TICK
        ret

;---------------------------------------------------------------------
; clear visible window of BB with BGCOL
clearbb:
        ld hl,BB+16
        ld c,64
.r:     ld a,(BGCOL)
        ld b,2
.q:     ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc hl
        TICK
        djnz .q
        ld de,32
        add hl,de
        dec c
        jr nz,.r
        ret

;---------------------------------------------------------------------
; draw all spheres in order
hdraw:  ld a,(NSPH)
        or a
        ret z
        ld b,a
        ld hl,ORD
.l:     push bc
        push hl
        ld a,(hl)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,SPL
        add hl,de
        ld a,(hl)
        ld (DBX),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (DBY),de
        inc hl
        inc hl
        ld a,(hl)
        ld (DRR),a
        inc hl
        ld a,(hl)
        ld (DKIND),a
        ld a,(DRR)
        cp 10
        jr nc,.bigd
        call blit
        jr .nx
.bigd:  call bigdisc
.nx:    pop hl
        inc hl
        pop bc
        djnz .l
        ret

; colour byte for solid kinds
KCOL:   db 0, $FF, $55, $AA, $00, $55

; template sprite blit (DBX, DBY, DRR, DKIND)
blit:   ld a,(DRR)
        dec a
        add a,a
        add a,a
        ld (BTI),a              ; (r-1)*4
        ; W from phase 0 template
        ld l,a
        ld h,0
        add hl,hl
        ld de,TPTR
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,TBLOB
        add hl,de
        ld b,(hl)               ; W
        ld a,(DBX)
        sub b
        ld c,a                  ; left px
        and 3
        ld hl,BTI
        add a,(hl)
        ld l,a
        ld h,0
        add hl,hl
        ld de,TPTR
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,TBLOB+1
        add hl,de               ; -> rows byte
        ld a,(hl)
        ld (BROWS),a
        inc hl
        ld a,c
        srl a
        srl a
        ld (BSTART),a
        ; solid colour + checker for ghost
        ld a,(DKIND)
        ld e,a
        ld d,0
        push hl
        ld hl,KCOL
        add hl,de
        ld a,(hl)
        ld (BCOL),a
        pop hl
        ; top row y = by - r ; row base pointer stepped by 64 per row
        ld de,(DBY)
        ld a,(DRR)
        ld c,a
        ld a,e
        sub c
        ld e,a
        jr nc,.t
        dec d
.t:     ld (BY0),de
        ; base = BB + y*64 + start (valid only while 0<=y<64)
        ld a,e
        rrca
        rrca
        ld c,a
        and $3F
        add a,BB>>8
        ld b,a
        ld a,c
        and $C0
        ld c,a
        ld a,(BSTART)
        add a,c
        ld c,a
        ld (BBASE),bc
        ld a,(DKIND)
        ld (BKND),a
.row:   ld c,(hl)               ; lead
        inc hl
        ld b,(hl)               ; len
        inc hl
        ld a,(BY0+1)
        or a
        jr nz,.skip
        ld a,(BY0)
        cp 64
        jr nc,.skip
        ld a,b
        or a
        jr z,.next
        ld de,(BBASE)
        ld a,e
        add a,c
        ld e,a
        ld a,(BKND)
        or a
        jr nz,.solid
.sh:    ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        djnz .sh
        jr .next
.solid: cp 5
        jr z,.ghost
.so:    ld a,(hl)
        cpl
        ld c,a
        ld a,(BCOL)
        and c
        ld c,a
        ld a,(de)
        and (hl)
        or c
        ld (de),a
        inc hl
        inc hl
        inc e
        djnz .so
        jr .next
.ghost: ld a,(BY0)
        and 1
        ld a,$33
        jr z,.gp
        ld a,$CC
.gp:    ld (.gm+1),a
.gl:    ld a,(hl)
.gm:    or $33
        ld c,a
        cpl
        and $55
        push bc
        ld b,a
        ld a,(de)
        and c
        or b
        ld (de),a
        pop bc
        inc hl
        inc hl
        inc e
        djnz .gl
        jr .next
.skip:  ld a,b                  ; skip len*2 bytes
        add a,a
        add a,l
        ld l,a
        jr nc,.next
        inc h
.next:  ld de,(BY0)
        inc de
        ld (BY0),de
        ld de,(BBASE)
        ld a,e
        add a,64
        ld e,a
        jr nc,.nb
        inc d
.nb:    ld (BBASE),de
        ld a,(BROWS)
        dec a
        ld (BROWS),a
        ret z
        and 1
        jp nz,.row
        TICK
        jp .row

;---------------------------------------------------------------------
; large shaded disc via spans (DBX, DBY, DRR, DKIND)
bigdisc:
        ld a,(DKIND)
        ld e,a
        ld d,0
        ld hl,KCOL
        add hl,de
        ld a,(hl)
        ld (BCOL),a
        ; geometry: lit disc centre (bx - 3r/8, by - r/4) radius r+r/8
        ld a,(DRR)
        ld c,a
        srl a
        srl a
        srl a
        ld b,a                  ; r/8
        add a,c
        cp 55
        jr c,.rl
        ld a,55
.rl:    ld (BRL),a
        ld a,b
        add a,a
        add a,b                 ; 3r/8
        ld b,a
        ld a,(DBX)
        sub b
        jr nc,.lx
        xor a
.lx:    ld (BLX),a
        ld a,c
        srl a
        srl a
        ld (BLDY),a             ; lit centre is r/4 above
        ; highlight: centre (bx - 9r/16, by - 3r/8) radius r/2
        ld a,c
        srl a
        ld (BRH),a
        ld a,c
        srl a
        srl a
        srl a
        srl a                   ; r/16
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,b                 ; 9r/16
        ld b,a
        ld a,(DBX)
        sub b
        jr nc,.hx
        xor a
.hx:    ld (BHX),a
        ld a,c
        srl a
        srl a
        srl a
        ld b,a
        add a,a
        add a,b
        ld (BHDY),a             ; 3r/8
        ; rows: start at max(-r, -by)
        xor a
        ld (BYR),a
        ld a,(DRR)
        neg
        ld (BDY),a
        ld hl,(DBY)
        bit 7,h
        jr nz,.row              ; by < 0: start at -r anyway (rows skipped)
        ld a,h
        or a
        jr nz,.row
        ld a,l                  ; by 0..255
        cp 64
        jr nc,.row
        ; -by > -r ?  i.e. by < r
        ld b,a
        ld a,(DRR)
        cp b
        jr c,.row
        jr z,.row
        ld a,b
        neg
        ld (BDY),a
.row:   ; y = by + dy (16-bit)
        ld a,(BDY)
        ld l,a
        rla
        sbc a,a
        ld h,a
        ld de,(DBY)
        add hl,de
        ld a,h
        or a
        jp nz,.nrow
        ld a,l
        cp 64
        jp nc,.nrow
        ld (BYR),a
        ; outer half width
        ld a,(DRR)
        ld c,a
        ld a,(BDY)
        call cwidth             ; A = hw
        ld b,a
        ld a,(DBX)
        sub b
        jr nc,.o1
        xor a
.o1:    ld d,a
        ld a,(DBX)
        add a,b
        jr nc,.o2
        ld a,255
.o2:    ld e,a
        ld (BOL),de
        ld a,(DKIND)
        or a
        jr z,.shd
        ld a,(BCOL)
        ld c,a
        ld a,(BYR)
        call bhspan
        jp .nrow
.shd:   ld c,$FF                ; red base
        ld a,(BYR)
        call bhspan
        ; lit disc row: dy' = dy + r/4
        ld a,(BLDY)
        ld b,a
        ld a,(BDY)
        add a,b
        ld b,a
        bit 7,a
        jr z,.l1
        neg
.l1:    ld hl,BRL
        cp (hl)
        jr z,.l2
        jr nc,.nolit
.l2:    ld c,(hl)
        ld a,b
        call cwidth
        ld b,a
        ld a,(BYR)
        and 1
        add a,b
        ld b,a
        ld a,(BLX)
        sub b
        jr nc,.l3
        xor a
.l3:    ld d,a
        ld a,(BLX)
        add a,b
        jr nc,.l4
        ld a,255
.l4:    ld e,a
        call clipol
        jr c,.nolit
        ld c,$00                ; green body
        ld a,(BYR)
        call bhspan
        ; highlight
        ld a,(BHDY)
        ld b,a
        ld a,(BDY)
        add a,b
        ld b,a
        bit 7,a
        jr z,.h1
        neg
.h1:    ld hl,BRH
        cp (hl)
        jr z,.h2
        jr nc,.nolit
.h2:    ld c,(hl)
        ld a,b
        call cwidth
        ld b,a
        ld a,(BYR)
        and 1
        xor 1
        add a,b
        ld b,a
        ld a,(BHX)
        sub b
        jr nc,.h3
        xor a
.h3:    ld d,a
        ld a,(BHX)
        add a,b
        jr nc,.h4
        ld a,255
.h4:    ld e,a
        call clipol
        jr c,.nolit
        ld c,$55                ; yellow
        ld a,(BYR)
        call bhspan
.nolit:
.nrow:  TICK
        ld a,(BYR)
        cp 63
        ret z                   ; drew the last visible row
        ld a,(BDY)
        inc a
        ld (BDY),a
        dec a
        ld hl,DRR
        cp (hl)
        jp nz,.row
        ret

; clip span D..E to outer BOL (D=lo,E=hi stored in BOL/BOL+1). C set if empty
clipol: ld a,(BOL+1)
        cp d
        jr c,.a
        ld d,a
.a:     ld a,(BOL)
        cp e
        jr nc,.b
        ld e,a
.b:     ld a,e
        cp d
        ret                     ; C if e<d

; A = dy (signed), C = radius -> A = half width (CIRCW, aspect 1.5)
cwidth: bit 7,a
        jr z,.p
        neg
.p:     cp c
        jr c,.ok
        jr z,.ok
        xor a
        ret
.ok:    push hl
        push de
        push bc
        ld e,a
        ld d,0
        ld l,c
        ld h,0
        add hl,hl
        push de
        ld de,CIRCOFF
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL = CIRCW + r(r+1)/2
        pop de
        add hl,de
        ld a,(hl)
        pop bc
        pop de
        pop hl
        ret

; horizontal span in BB: A=y (0-63), D=x0, E=x1 (BB px), C=colour byte
bhspan: ld (BSY),a
        ld a,d
        cp 64
        jr nc,.c0
        ld d,64
.c0:    ld a,e
        cp 192
        jr c,.c1
        ld e,191
.c1:    ld a,e
        cp d
        ret c
        ; row base
        ld a,(BSY)
        rrca
        rrca
        ld l,a
        and $3F
        add a,BB>>8
        ld h,a
        ld a,l
        and $C0
        ld l,a
        ld a,d
        srl a
        srl a
        ld b,a                  ; b0
        add a,l
        ld l,a
        ld a,e
        srl a
        srl a
        sub b                   ; nbytes-1
        ld b,a
        ld a,d
        and 3
        push hl
        ld hl,LMASKT
        add a,l
        ld l,a
        ld a,(hl)
        pop hl
        ld d,a                  ; left mask
        ld a,e
        and 3
        push hl
        ld hl,RMASKT
        add a,l
        ld l,a
        ld a,(hl)
        pop hl
        ld e,a                  ; right mask
        ld a,b
        or a
        jr nz,.multi
        ld a,d
        and e
        jr .last
.multi: ld a,d
        call .mw
        inc l
        dec b
        jr z,.lastb
        ld a,c
.mid:   ld (hl),a
        inc l
        djnz .mid
.lastb: ld a,e
.last:  ; masked write of C with mask A
.mw:    push de
        ld d,a
        cpl
        and (hl)
        ld e,a
        ld a,c
        and d
        or e
        ld (hl),a
        pop de
        ret

LMASKT: db $FF,$3F,$0F,$03
RMASKT: db $C0,$F0,$FC,$FF

;---------------------------------------------------------------------
; copy BB window to VRAM on the next field
present1:
        call waitvb
        ld a,(PMODE)
        or a
        jr z,.np
        call setmode
        xor a
        ld (PMODE),a
.np:
        ld hl,BB+16
        ld de,VRAM
        ld a,64
.r:     ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        TICK
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        TICK
        ld bc,32
        add hl,bc
        dec a
        jr nz,.r
        ret

;---------------------------------------------------------------------
; one complete human frame. Scene hooks: HEXTRA (add spheres), HPOST (draw over)
hrender:
        call projall
        call buildsph
        call feats
        ld hl,(HEXTRA)
        call jphl
        call hsort
        call clearbb
        call hdraw
        ld hl,(HPOST)
        call jphl
        jp present1
jphl:   jp (hl)
nohook: ret

; 2bpp plot into BB: D = BB x px, E = row, C = colour (0-3)
bplot:  ld a,e
        cp 64
        ret nc
        ld a,d
        cp 64
        ret c
        cp 192
        ret nc
        push hl
        push bc
        ld a,e
        rrca
        rrca
        ld l,a
        and $3F
        add a,BB>>8
        ld h,a
        ld a,l
        and $C0
        ld l,a
        ld a,d
        srl a
        srl a
        add a,l
        ld l,a
        push hl
        ld a,d
        and 3
        ld hl,PMASKT
        add a,l
        ld l,a
        ld b,(hl)               ; pixel mask
        ld a,c
        ld hl,KCOLB
        add a,l
        ld l,a
        ld a,(hl)
        and b
        ld c,a
        ld a,b
        cpl
        pop hl
        and (hl)
        or c
        ld (hl),a
        pop bc
        pop hl
        ret
PMASKT: db $C0,$30,$0C,$03
KCOLB:  db $00,$55,$AA,$FF
