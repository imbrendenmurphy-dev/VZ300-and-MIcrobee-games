; =====================================================================
;  STAGE 2: take-off, touchdown, landing grade, approach aid, messages
; =====================================================================
AIMN    equ 180                 ; aim point (centre of the aim markers), m
AIMS    equ 1020                ; same for landing southbound
RWYLEN  equ 1200

; ---- touchdown: A = 0 landed, 1 bounce, 2 crash (reason in crreason)
touch:  ld hl,(vs)
        bit 7,h
        jr nz,tch1
        ld hl,0
        jr tch2
tch1:   call neghl
tch2:   ld (tdsink),hl
        ld de,1409              ; over 5.5 m/s (1080 ft/min): crash
        or a
        sbc hl,de
        ld hl,r_sink
        jr nc,tchcr
        ld a,(roll+1)           ; bank over 30 degrees: wing tip
        add a,21
        cp 43
        ld hl,r_bank
        jr nc,tchcr
        ld a,(pitch+1)          ; nose down over 8 degrees
        add a,6
        bit 7,a
        ld hl,r_nose
        jr nz,tchcr
        ld hl,(tdsink)          ; 3.5 - 5.5 m/s: bounce
        ld de,897
        or a
        sbc hl,de
        ld a,1
        ret nc
        xor a
        ret
tchcr:  ld (crreason),hl
        ld a,2
        ret

; ---- bounce: nose up a little, lose some speed, try again
bounce: xor a
        ld (altf),a
        ld hl,0
        ld (alt),hl
        ld hl,3*256
        ld (pitch),hl
        ld hl,(vel)
        ld d,h
        ld e,l
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        or a
        sbc hl,de
        ld (vel),hl
        ld hl,bounces
        inc (hl)
        ld hl,m_bnc
        jp setmsg

; ---- 1 if heading southbound (hdg 90..270 degrees) else 0
southb: ld a,(hdg+1)
        add a,64
        rlca
        and 1
        ret

; ---- landed: work out the grade and report it
landed: xor a
        ld (worst),a
        ld a,100
        ld (score),a
        ld hl,r_grease
        ld (wreason),hl
        ; sink rate
        ld hl,(tdsink)
        ld de,t_sink
        call ptab
        ld hl,r_hard
        call pen
        ; on the runway?
        ld hl,(px)
        bit 7,h
        call nz,neghl
        ld (tdoff),hl
        ld de,16
        or a
        sbc hl,de
        jr nc,ldoff
        ld hl,(pz)
        bit 7,h
        jr nz,ldoff
        ld de,RWYLEN
        or a
        sbc hl,de
        jr nc,ldoff
        ; centreline
        ld hl,(tdoff)
        ld de,t_ctr
        call ptab
        ld hl,r_ctr
        call pen
        ; touchdown point measured from the threshold you landed over
        ld hl,(pz)
        call southb
        or a
        jr z,ldz1
        ex de,hl
        ld hl,RWYLEN
        or a
        sbc hl,de
ldz1:   ld (tddist),hl
        ld de,120
        or a
        sbc hl,de
        jr nc,ldz2
        ld hl,(tddist)
        ld de,t_short
        call ptab
        ld hl,r_short
        call pen
        jr ldz3
ldz2:   ld hl,(tddist)
        ld de,t_long
        call ptab
        ld hl,r_long
        call pen
        jr ldz3
ldoff:  ld hl,(pz)
        ld (tddist),hl
        ld a,40
        ld hl,r_off
        call pen
ldz3:   ; wings level
        ld a,(roll+1)
        call absa
        ld l,a
        ld h,0
        ld de,t_bank
        call ptab
        ld hl,r_wings
        call pen
        ; lined up with the runway
        call southb
        rrca
        ld b,a                  ; 0 or 128
        ld a,(hdg+1)
        sub b
        call absa
        ld l,a
        ld h,0
        ld de,t_line
        call ptab
        ld hl,r_line
        call pen
        ; speed
        ld a,(vel+1)
        ld l,a
        ld h,0
        ld de,t_fast
        call ptab
        ld hl,r_fast
        call pen
        ; bounces, 10 each
        ld a,(bounces)
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,a
        ld hl,r_bounce
        call pen
        ; small faults only: say so kindly
        ld a,(worst)
        or a
        jr z,ldgr
        cp 8
        jr nc,ldgr
        ld hl,r_nice
        ld (wreason),hl
ldgr:   ; grade
        ld a,(score)
        ld b,'A'
        cp 90
        jr nc,ldg
        inc b
        cp 78
        jr nc,ldg
        inc b
        cp 65
        jr nc,ldg
        inc b
        cp 50
        jr nc,ldg
        inc b
ldg:    ld a,b
        ld (lastg),a
        ld hl,bestg
        cp (hl)
        jr nc,ldg1
        ld (hl),a
ldg1:   ; "GRADE B  OFF CENTRE        SINK 240 FT/M  TD 230 M  BEST A"
        ld hl,m_grade
        call setmsg
        ld a,(lastg)
        ld (msgbuf+6),a
        ld hl,(wreason)
        ld de,msgbuf+9
        call ps2
        ld hl,m_sink
        ld de,msgbuf+27
        call ps2
        ld hl,(tdsink)
        call fpm
        ld de,msgbuf+32
        ld b,4
        call mnum
        ld hl,m_td
        call ps2
        ld hl,(tddist)
        bit 7,h
        jr z,ldg2
        ld hl,0
ldg2:   ld b,4
        call mnum
        ld hl,m_best
        call ps2
        ld a,(bestg)
        ld (de),a
        ret

; A = penalty, HL = reason: score -= A, remember the biggest fault
pen:    ld b,a
        ld a,(score)
        sub b
        jr nc,pen1
        xor a
pen1:   ld (score),a
        ld a,(worst)
        cp b
        ret nc
        ld a,b
        ld (worst),a
        ld (wreason),hl
        ret

; HL = value, DE -> table of (dw limit, db penalty) -> A = penalty
ptab:   ex de,hl
pt1:    ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,b
        ld l,c
        or a
        sbc hl,de
        pop hl
        ret nc
        jr pt1

; HL = vertical speed (8.8 m/s, positive) -> ft/min
fpm:    ld d,h
        ld e,l
        srl d
        rr e
        srl d
        rr e
        or a
        sbc hl,de
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        add hl,de
        ret

; HL = value, DE = dest, B = width -> right aligned, DE moves past it
mnum:   push de
        push bc
        ld c,' '
        call pdec
        pop bc
        pop hl
        ld e,b
        ld d,0
        add hl,de
        ex de,hl
        ret

; HL -> message: clear the message line and write it at the left
setmsg: push hl
        ld hl,msgbuf
        ld de,msgbuf+1
        ld (hl),' '
        ld bc,62
        ldir
        xor a
        ld (msgbuf+63),a
        pop hl
        ld de,msgbuf
        jp ps2

; ---- lift-off report
liftoff:
        ld hl,m_lift
        call setmsg
        ld a,(vel+1)
        call knots
        ld de,msgbuf+12
        ld b,3
        call mnum
        ld hl,m_after
        call ps2
        push de
        ld hl,(pz)
        ld de,(rollz)
        or a
        sbc hl,de
        bit 7,h
        call nz,neghl
        pop de
        ld b,4
        call mnum
        ld hl,m_climb
        jp ps2

; ---- crash report
crashmsg:
        ld hl,m_crash
        call setmsg
        ld hl,(crreason)
        call ps2
        ld hl,m_crash2
        jp ps2

; ---- approach line of the panel (row 5)
pnappr: ; centreline offset, shown always
        ld hl,(px)
        call southb
        or a
        call nz,neghl           ; southbound: left and right swap
        ld a,h
        ld (ltmp),a
        bit 7,h
        call nz,neghl
        ld a,h
        or a
        jr nz,pna0
        ld a,l
        cp 3
        jr nc,pna1
        ld hl,s_cntr
        jr pna3
pna0:   ld hl,999
pna1:   ld de,F_LIN
        call fadr
        ld b,3
        call mnum
        ld hl,s_left
        ld a,(ltmp)
        bit 7,a
        jr nz,pna2
        ld hl,s_right
pna2:   call ps2
        jr pna4
pna3:   ld de,F_LIN
        call pstr
pna4:   ; range to the aim point and PAPI, only in the air
        ld a,(ongnd)
        or a
        jp nz,pnaoff
        call southb
        or a
        jr nz,pnas
        ld hl,AIMN
        ld de,(pz)
        or a
        sbc hl,de
        jr pnar
pnas:   ld hl,(pz)
        ld de,AIMS
        or a
        sbc hl,de
pnar:   bit 7,h
        jp nz,pnaoff
        ld a,h
        or l
        jp z,pnaoff
        ld de,10000
        or a
        sbc hl,de
        add hl,de
        jp nc,pnaoff
        ld (rng),hl
        ld de,F_RNG
        call fadr
        ld b,5
        call mnum
        ; PAPI: light i is white if the glide angle is above its setting
        ; (2.5, 2.83, 3.17, 3.5 degrees: tan * 1024 = 45, 51, 57, 63)
        ld hl,(rng)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld (rng),hl             ; range/16
        ld c,0                  ; whites
        ld b,4
        ld de,papit
pnp1:   push bc
        push de
        ld a,(de)
        ld e,a
        ld hl,(rng)
        call mul16u8            ; range/16 * t
        ld b,6
pnp2:   srl h
        rr l
        djnz pnp2               ; /64 -> height of that light's beam, m
        ld de,(alt)
        ex de,hl
        or a
        sbc hl,de               ; alt - beam
        pop de
        pop bc
        jr c,pnp3
        jr z,pnp3
        inc c
pnp3:   inc de
        djnz pnp1
        ld a,c
        ld (whites),a
        ld de,F_PAPI
        call fadr
        ld b,4
pnp4:   ld a,'W'
        dec c
        bit 7,c
        jr z,pnp5
        ld a,'R'
pnp5:   ld (de),a
        inc de
        djnz pnp4
        ld a,(whites)
        add a,a
        ld e,a
        ld d,0
        ld hl,s_glide
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,F_GLD
        jp pstr
pnaoff: ld hl,s_norng
        ld de,F_RNG
        call pstr
        ld hl,s_nopapi
        ld de,F_PAPI
        jp pstr

papit:  db 63,57,51,45
s_glide: dw s_g0,s_g1,s_g2,s_g3,s_g4
s_g0:   db "TOO LOW! ",0
s_g1:   db "LOW      ",0
s_g2:   db "ON SLOPE ",0
s_g3:   db "HIGH     ",0
s_g4:   db "TOO HIGH ",0
s_norng: db "   --",0
s_nopapi: db "              ",0    ; PAPI, space, glide text
s_cntr: db "ON CENTRE    ",0
s_left: db " M LEFT  ",0
s_right: db " M RIGHT ",0

; penalty tables: (limit, penalty)
t_sink: dw 196
        db 0
        dw 392
        db 5
        dw 588
        db 15
        dw 783
        db 25
        dw 0FFFFh
        db 35
t_ctr:  dw 2
        db 0
        dw 5
        db 5
        dw 10
        db 12
        dw 0FFFFh
        db 20
t_short: dw 59
        db 15
        dw 0FFFFh
        db 8
t_long: dw 450
        db 0
        dw 600
        db 8
        dw 800
        db 15
        dw 0FFFFh
        db 25
t_bank: dw 3
        db 0
        dw 7
        db 5
        dw 0FFFFh
        db 10
t_line: dw 3
        db 0
        dw 8
        db 5
        dw 0FFFFh
        db 10
t_fast: dw 31
        db 0
        dw 35
        db 5
        dw 0FFFFh
        db 10

r_grease: db "GREASED IT!",0
r_nice:   db "NICE LANDING",0
r_hard:   db "TOO HARD",0
r_ctr:    db "OFF CENTRE",0
r_short:  db "SHORT LANDING",0
r_long:   db "LONG LANDING",0
r_off:    db "OFF THE RUNWAY",0
r_wings:  db "WINGS NOT LEVEL",0
r_line:   db "NOT LINED UP",0
r_fast:   db "TOO FAST",0
r_bounce: db "BOUNCED",0
r_sink:   db "SINKING TOO FAST",0
r_bank:   db "WING TIP HIT",0
r_nose:   db "NOSE FIRST",0

m_grade:  db "GRADE",0
m_sink:   db "SINK",0
m_td:     db " FT/M  TD",0
m_best:   db " M  BEST ",0
m_lift:   db "LIFT-OFF AT",0
m_after:  db " KT AFTER",0
m_climb:  db " M.  CLIMB AWAY AT 60-70 KT.",0
m_crash:  db "CRASHED: ",0
m_crash2: db ". BACK ON FINAL IN 3 SECONDS.",0
m_bnc:    db "BOUNCED! HOLD THE NOSE UP A LITTLE AND LET IT SETTLE.",0
m_rwy:    db "RUNWAY 36. T FOR FULL POWER, A TO LIFT THE NOSE AT 52 KT.",0
m_fin:    db "ON FINAL. KEEP THE PAPI AT WWRR, WINGS LEVEL, FLARE GENTLY.",0
m_again:  db "BACK ON FINAL - HAVE ANOTHER GO. KEEP THE PAPI AT WWRR.",0
