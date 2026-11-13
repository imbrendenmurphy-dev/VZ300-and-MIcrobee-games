; =====================================================================
;  STAGE 4: missions, briefing and debrief screens, logbook on disk
; =====================================================================
MREC    equ 320                 ; bytes per mission record
K_M     equ 13
K_1     equ 33
K_ESC   equ 48

; ---------------------------------------------------------------------
;  Keyboard helpers for the menus
; ---------------------------------------------------------------------
kdown:  push bc                 ; A = scan code -> NZ if held
        push hl
        ld b,a
        ld a,1
        out (ROMLAT),a
        ld a,b
        call keytst
        push af
        xor a
        out (ROMLAT),a
        pop af
        pop hl
        pop bc
        ret

anykey: ld c,0                  ; A = first key held, or FFh
ak1:    ld a,c
        call kdown
        jr nz,ak2
        inc c
        ld a,c
        cp 64
        jr nz,ak1
        ld a,0FFh
        ret
ak2:    ld a,c
        ret

getkey: call anykey             ; wait for all keys up, then a press
        inc a
        jr nz,getkey
gk1:    call anykey
        cp 0FFh
        jr z,gk1
        ret

; ---------------------------------------------------------------------
;  Text screens: page A, all 16 rows as characters
; ---------------------------------------------------------------------
tcls:   ld a,EXT
        out (LATCH),a
        ld hl,SCREEN
        ld (hl),' '
        ld de,SCREEN+1
        ld bc,1023
        ldir
        ld a,EXT+ATTRSEL
        out (LATCH),a
        ld hl,SCREEN
        ld (hl),0
        ld de,SCREEN+1
        ld bc,1023
        ldir
        ld a,EXT
        out (LATCH),a
        ld a,12
        out (CRTCA),a
        xor a
        out (CRTCD),a
        ld a,13
        out (CRTCA),a
        xor a
        out (CRTCD),a
        ld hl,SCREEN+64         ; rule under the heading
        ld b,64
tc1:    ld (hl),'-'
        inc hl
        djnz tc1
        ret

; HL = seconds, DE = screen address -> "MM:SS"
ttime:  push de
        ld a,60
        call div16u8
        ld (ttsec),a
        pop de
        push de
        ld bc,2*256+' '
        call pdec
        pop de
        inc de
        inc de
        ld a,':'
        ld (de),a
        inc de
        ld a,(ttsec)
        ld l,a
        ld h,0
        ld bc,2*256+'0'
        jp pdec

; A = row -> HL = its first cell on the text screen
rowaddr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,SCREEN
        add hl,de
        ret

; A = rating 1..4 -> HL = name
ratname:
        ld hl,s_rnone
        or a
        ret z
        push de
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,ratings
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        ret

; A = mission number -> HL = record
misrec: ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *64
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; *320
        ld de,(misp)
        add hl,de
        ret

; A = mission number -> HL = its logbook entry (best time, rating, flown)
logent: add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,logb+8
        add hl,de
        ret

; ---------------------------------------------------------------------
;  Mission menu.  Returns with a flight set up (mission or free flight).
; ---------------------------------------------------------------------
menu:   xor a
        ld (mact),a
        ld a,(autoff)           ; test builds go straight to free flight
        or a
        jp nz,freefl
        call tcls
        ld hl,t_title
        ld de,SCREEN+2
        call ps2
        ld hl,LOCBUF+3
        ld de,SCREEN+19
        ld bc,16
        ldir
        ld hl,t_vibed
        ld de,SCREEN+46
        call ps2
        ld hl,t_mhead
        ld de,SCREEN+2*64+2
        call ps2
        xor a
        ld (mni),a
mn1:    ld a,(mni)
        ld hl,nmis
        cp (hl)
        jp nc,mn3
        add a,3
        call rowaddr
        inc hl
        inc hl
        ld (mnrow),hl
        ld a,(mni)
        add a,'1'
        ld (hl),a
        ld a,(mni)
        call misrec
        ld de,(mnrow)
        inc de
        inc de
        inc de
        ld bc,18
        ldir                    ; title
        ld a,(mni)
        call logent
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (mntmp),a            ; best rating
        inc hl
        ld a,(hl)
        ld (mntmp+1),a          ; times flown
        ld a,d
        or e
        jr z,mn2
        ex de,hl
        ld de,(mnrow)
        push hl
        ld hl,28
        add hl,de
        ex de,hl
        pop hl
        call ttime
mn2:    ld hl,(mnrow)
        ld de,39
        add hl,de
        ex de,hl
        ld a,(mntmp)
        call ratname
        call ps2
        ld hl,(mnrow)
        ld de,54
        add hl,de
        ex de,hl
        ld a,(mntmp+1)
        ld l,a
        ld h,0
        ld bc,3*256+' '
        call pdec
        ld hl,mni
        inc (hl)
        jp mn1
mn3:    ld a,(nmis)             ; free flight on the next row
        add a,3
        call rowaddr
        inc hl
        inc hl
        ex de,hl
        ld hl,t_free
        call ps2
        ld hl,t_land            ; logbook totals
        ld de,SCREEN+13*64+2
        call ps2
        ld hl,(logb+3)
        ld de,SCREEN+13*64+14
        ld bc,5*256+' '
        call pdec
        ld hl,t_bgrade
        ld de,SCREEN+13*64+24
        call ps2
        ld a,(bestg)
        cp 'Z'
        jr nz,mn4
        ld a,'-'
mn4:    ld (SCREEN+13*64+44),a
        ld hl,t_pick
        ld de,SCREEN+15*64+2
        call ps2
        ld a,(locok)
        or a
        jr nz,mnk
        ld hl,m_noloc
        ld de,SCREEN+14*64+2
        call ps2
mnk:    call getkey
        cp K_F
        jp z,freefl
        sub K_1
        jr c,mnk
        ld hl,nmis
        cp (hl)
        jr nc,mnk
        ld (misno),a
        ; ---- briefing
brief:  call tcls
        ld hl,t_mis
        ld de,SCREEN+2
        call ps2
        ld a,(misno)
        add a,'1'
        ld (SCREEN+10),a
        ld a,(misno)
        call misrec
        ld (mptr),hl
        ld de,SCREEN+13
        ld bc,18
        ldir
        ld de,SCREEN+3*64+6     ; seven lines of briefing
        ld b,7
br1:    push bc
        push de
        ld bc,30
        ldir
        pop de
        ex de,hl
        ld bc,64
        add hl,bc
        ex de,hl
        pop bc
        djnz br1
        ld hl,t_par
        ld de,SCREEN+11*64+6
        call ps2
        ld hl,(mptr)
        ld de,237
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,SCREEN+11*64+16
        call ttime
        ld a,(misno)
        call logent
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr z,br2
        push de
        ld hl,t_ybest
        ld de,SCREEN+11*64+28
        call ps2
        pop hl
        ld de,SCREEN+11*64+38
        call ttime
br2:    ld hl,t_fly
        ld de,SCREEN+15*64+2
        call ps2
brk:    call getkey
        cp K_ESC
        jp z,menu
        cp K_SPC
        jr nz,brk
        ; ---- start the mission
        call flyinit
        ld a,1
        ld (mact),a
        xor a
        ld (mgi),a
        ld (mtf),a
        ld (mdone),a
        ld (mland),a
        ld (mprevok),a
        ld (cklnd),a
        ld hl,0
        ld (mts),hl
        ld (mpen),hl
        ld (ckgate),hl
        call mplace
        jp mgoal0

freefl: call flyinit
        xor a
        ld (mact),a
        ld (curfld),a
        jp resetrwy

; back to the flight display
flyinit:
        call vinit
        call drawstatic
        ld a,6
        ld (ticks),a
        ret

; put the aircraft at the mission start
mplace: ld hl,(mptr)
        ld de,228
        add hl,de
        ld a,(hl)
        ld (curfld),a
        inc hl
        ld a,(hl)
        or a
        jp z,resetrwy
        dec a
        jp z,resetfin
        inc hl                  ; in the air: final-approach state, then move
        push hl
        call resetfin
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (px),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (pz),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (alt),de
        ld a,(hl)
        ld (hdg+1),a
        xor a
        ld (hdg),a
        ld hl,0
        ld (pitch),hl
        ld a,60
        ld (thr),a
        ret

; ---------------------------------------------------------------------
;  Mission progress, once a frame
; ---------------------------------------------------------------------
mission:
        ld a,(mact)
        or a
        ret z
        ld a,(mdone)
        or a
        jr z,ms1
        ld a,(mdtim)            ; finished: short pause, then the debrief
        ld hl,ticks
        sub (hl)
        jp c,debrief
        jp z,debrief
        ld (mdtim),a
        ret
ms1:    ld a,(crashed)          ; the clock (stopped while crashed)
        or a
        jr nz,ms2
        ld a,(ticks)
        ld hl,mtf
        add a,(hl)
mt1:    cp 50
        jr c,mt2
        sub 50
        ld hl,(mts)
        inc hl
        ld (mts),hl
        jr mt1
mt2:    ld (mtf),a
ms2:    ld hl,(gptr)
        ld a,(hl)
        cp 1
        jr z,msgate
        ; ---- landing goal
        ld a,(mland)
        or a
        ret z
        xor a
        ld (mland),a
        ld a,(tdon)
        or a
        ret z
        call rwindex
        ld hl,(gptr)
        inc hl
        cp (hl)
        ret nz                  ; landed somewhere else: no matter
        inc a
        ld (cklnd),a
        ld hl,0
        ld (ckgate),hl
        ld a,1
        ld (mwasl),a
        jp mnext

msgate: inc hl
        ld a,(hl)               ; axis
        ld (gax),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(px)
        or a
        sbc hl,de
        ld (gdx),hl
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (glop),hl
        ld hl,(pz)
        or a
        sbc hl,de
        ld (gdz),hl
        ld a,(gax)
        or a
        ld hl,(gdz)             ; along: z for axis 0, x for axis 1
        ld de,(gdx)
        jr z,mg1
        ex de,hl
mg1:    ld (glat),de
        ld a,(mprevok)
        or a
        jr z,mg9
        ld de,(mprevd)          ; crossed the gate's plane?
        ld a,h
        xor d
        jp p,mg9
        push hl
        call nabs
        ld bc,300
        or a
        sbc hl,bc
        pop hl
        jr nc,mg9
        push hl
        ex de,hl
        call nabs
        or a
        sbc hl,bc
        pop hl
        jr nc,mg9
        ; crossed: wide, low or high?
        ld (mprevd),hl
        ld hl,(glat)
        call nabs
        ld de,33
        or a
        sbc hl,de
        ld hl,m_wide
        jr nc,mgmiss
        ld hl,(glop)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(alt)
        or a
        sbc hl,de
        pop hl
        ld de,m_low
        jr c,mgmiss2
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(alt)
        ex de,hl
        or a
        sbc hl,de
        ld hl,m_high
        jr c,mgmiss
        ; through!
        ld hl,(gptr)
        ld (ckgate),hl
        ld a,(hdg+1)
        ld (ckhdg),a
        xor a
        ld (cklnd),a
        ld (mwasl),a
        jr mnext
mgmiss2:
        ex de,hl
mgmiss: call setmsg
        ld hl,m_again2
        jp ps2
mg9:    ld (mprevd),hl
        ld a,1
        ld (mprevok),a
        ret

; |HL| -> HL
nabs:   bit 7,h
        ret z
        jp neghl

; next goal (or done)
mnext:  ld a,(mgi)
        inc a
        ld (mgi),a
        ld hl,(mptr)
        ld de,239
        add hl,de
        cp (hl)
        jr c,mgoal
        ld a,1
        ld (mdone),a
        ld a,150
        ld (mdtim),a
        ld a,(mwasl)
        or a
        ld hl,m_mdone
        jp z,setmsg
        ld hl,m_mdone           ; finished with a landing: keep the grade
        call setmsg
        jp mgradeon
mgoal0: xor a
        ld (mgi),a
        ld (mwasl),a
mgoal:  ld a,(mgi)              ; gptr = goal mgi, tell the pilot
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; *10
        ld de,(mptr)
        add hl,de
        ld de,240
        add hl,de
        ld (gptr),hl
        xor a
        ld (mprevok),a
        ld a,(hl)
        cp 1
        jr nz,mgl
        ld hl,m_gate            ; "GATE n OF N AHEAD - FOLLOW THE GUIDE LINE"
        call setmsg
        call mgnum
        ld hl,m_gate2
        call ps2
        jr mgradeon
mgl:    ld hl,m_landat          ; "NOW LAND AT TURTLE IS"
        call setmsg
        ld hl,(gptr)
        inc hl
        ld a,(hl)
        push de
        call rwptr
        pop de
        ld a,(hl)
        push hl
        ld bc,4
        add hl,bc
        ld a,(hl)
        pop hl
        ld c,0
        call rwname
mgradeon:
        ld a,(mwasl)            ; after a landing, add its grade
        or a
        ret z
        ld hl,m_lgrade
        call ps2
        ld a,(lastg)
        ld (de),a
        inc de
        ld a,')'
        ld (de),a
        ret

; write "n OF N" at DE (goal number counted from 1)
mgnum:  ld a,(mgi)
        add a,'1'
        ld (de),a
        inc de
        ld hl,m_of
        call ps2
        ld hl,(mptr)
        ld bc,239
        add hl,bc
        ld a,(hl)
        add a,'0'
        ld (de),a
        inc de
        ret

; runway index of (rwp) -> A
rwindex:
        ld hl,(rwp)
        ld de,(rwyp)
        or a
        sbc hl,de
        ld a,20
        call div16u8
        ld a,l
        ret

; A = runway index -> HL = entry
rwptr:  ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,(rwyp)
        add hl,de
        ret

; ---- crash or R in a mission: back to the last gate (or runway), +15 s
mrestart:
        ld hl,(mpen)
        ld de,15
        add hl,de
        ld (mpen),hl
        ld hl,(ckgate)
        ld a,h
        or l
        jr nz,mrg
        ld a,(cklnd)
        or a
        jr z,mrs
        dec a                   ; on the runway we last landed on
        ld (curfld),a
        call resetrwy
        ld hl,m_rbackr
        call setmsg
        jr mrend
mrs:    call mplace             ; nothing done yet: from the start
        ld hl,m_rbacks
        call setmsg
        jr mrend
mrg:    push hl                 ; at the last gate, heading the same way
        call resetfin
        pop hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (px),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (pz),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        add hl,de
        srl h
        rr l
        ld (alt),hl             ; middle of its height band
        ld a,(ckhdg)
        ld (hdg+1),a
        xor a
        ld (hdg),a
        ld hl,0
        ld (pitch),hl
        ld a,60
        ld (thr),a
        ld hl,m_rbackg
        call setmsg
mrend:  xor a
        ld (mprevok),a
        ret

; ---- gate on screen: a 60 m square frame between its heights
drawgate:
        ld a,(mact)
        or a
        ret z
        ld a,(mdone)
        or a
        ret nz
        ld hl,(gptr)
        ld a,(hl)
        cp 1
        ret nz
        inc hl
        ld a,(hl)
        ld (gax),a
        inc hl
        ld de,gobj
        ldi                     ; x
        ldi
        xor a
        ld (de),a               ; y origin 0
        inc de
        ld (de),a
        inc de
        ldi                     ; z
        ldi
        ld c,(hl)               ; low (m) -> half metres
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld h,b
        ld l,c
        add hl,hl
        ld (glo2),hl
        pop hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld h,b
        ld l,c
        add hl,hl
        ld (ghi2),hl
        ld a,(gax)
        or a
        ld hl,gtpl0
        jr z,dg1
        ld hl,gtpl1
dg1:    ld bc,GTPLEN
        ldir
        ld hl,(glo2)            ; patch the two heights
        ld (gobj+GYLO),hl
        ld hl,(ghi2)
        ld (gobj+GYHI),hl
        xor a
        ld (lodfar),a
        ld hl,gobj
        jp dobj

; templates after the 6-byte origin: x, y, z axis tables, verts, edges
gtpl0:  db 2,2
        dw -60,60
        db 2,2
        dw 0,0
        db 1,1
        dw 0
        db 4,4
        db 0,0,0, 1,0,0, 1,1,0, 0,1,0
        db 4,4
        db 0,1, 1,2, 2,3, 3,0
GTPLEN  equ $-gtpl0
gtpl1:  db 2,2                 ; (two equal x values keep the layout the same)
        dw 0,0
        db 2,2
        dw 0,0
        db 2,2
        dw -60,60
        db 4,4
        db 0,0,0, 0,0,1, 0,1,1, 0,1,0
        db 4,4
        db 0,1, 1,2, 2,3, 3,0
GYLO    equ 6+8                 ; y values sit after the x table (2 bytes + 2 or 1 words)
GYHI    equ 6+10

; ---- gate guide line (row 5) instead of the approach line
pngate: ld hl,gbuf              ; "GATE 2 OF 5  1840 M  << LEFT    330-1150 FT CLIMB"
        ld (hl),' '
        ld de,gbuf+1
        ld bc,61
        ldir
        ld hl,m_gt
        ld de,gbuf
        call ps2
        call mgnum
        ; distance (larger of dx, dz) and direction
        ld hl,(gptr)
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld de,(px)
        or a
        sbc hl,de
        ld (gdx),hl
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (glop),hl
        ex de,hl
        ld de,(pz)
        or a
        sbc hl,de
        ld (gdz),hl
        call nabs
        push hl
        ld hl,(gdx)
        call nabs
        pop de
        or a
        sbc hl,de
        add hl,de
        jr nc,pg1
        ex de,hl
pg1:    ld de,gbuf+12
        ld b,5
        call mnum
        ld hl,m_mtr
        call ps2
        ; ahead f and right r (as the cull test)
        ld hl,(gdx)
        ld a,(sh)
        call mul168
        push hl
        ld hl,(gdz)
        ld a,(ch)
        call mul168
        pop de
        add hl,de
        ld (gfw),hl
        ld hl,(gdz)
        ld a,(sh)
        call mul168
        push hl
        ld hl,(gdx)
        ld a,(ch)
        call mul168
        pop de
        or a
        sbc hl,de
        ld (grt),hl
        ld hl,s_dround
        ld a,(gfw+1)
        bit 7,a
        jr nz,pg5               ; behind: turn round
        ld hl,(grt)
        call nabs
        ex de,hl                ; DE = |r|
        ld hl,(gfw)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l                    ; f/8
        or a
        sbc hl,de
        ld hl,s_dahead
        jr nc,pg5
        ld hl,(gfw)
        srl h
        rr l                    ; f/2
        or a
        sbc hl,de
        ld b,0
        jr nc,pg3
        ld hl,(gfw)
        add hl,hl               ; 2f
        or a
        sbc hl,de
        ld b,1
        jr nc,pg3
        ld b,2
pg3:    ld a,(grt+1)            ; left or right
        bit 7,a
        ld a,b
        jr z,pg4
        add a,3
pg4:    add a,a
        ld e,a
        ld d,0
        ld hl,s_dirs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
pg5:    ld de,gbuf+21
        call ps2
        ; height band in feet and what to do about it
        ld hl,(glop)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        push hl
        call feet
        ld de,gbuf+32
        ld b,4
        call mnum
        ld a,'-'
        ld (de),a
        inc de
        pop bc                  ; low (m)
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de                 ; high (m)
        push bc
        ex de,hl
        call feet
        ld de,gbuf+37
        call mnumL
        ld hl,m_ft
        call ps2
        inc de
        ld (gstat),de
        pop bc                  ; low
        pop de                  ; high
        ld hl,(alt)
        or a
        sbc hl,bc
        ld hl,s_climb
        jr c,pg6
        ld hl,(alt)
        ex de,hl
        or a
        sbc hl,de
        ld hl,s_desc
        jr c,pg6
        ld hl,s_hok
pg6:    ld de,(gstat)
        call ps2
        ld hl,gbuf
        ld de,F_RWN
        call fadr
        ld bc,62
        ldir
        ret

; HL = metres -> feet (x 3.28)
feet:   ld d,h
        ld e,l
        add hl,hl
        add hl,de
        srl d
        rr e
        srl d
        rr e
        add hl,de
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        add hl,de
        ret

; HL = value, DE = dest, B = width: left aligned (writes the digits only)
mnumL:  push de
        ld de,numbuf
        ld bc,5*256+'0'
        call pdec
        ld hl,numbuf
        ld b,4
mnl1:   ld a,(hl)
        cp '0'
        jr nz,mnl2
        inc hl
        djnz mnl1
mnl2:   pop de
        inc b
mnl3:   ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz mnl3
        ret

; ---------------------------------------------------------------------
;  Debrief: time, rating, best, logbook saved
; ---------------------------------------------------------------------
debrief:
        xor a
        ld (mact),a
        ld hl,(mts)
        ld de,(mpen)
        add hl,de
        ld (mtot),hl
        ld hl,(mptr)            ; rating against par
        ld de,237
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (mpar),de
        ld b,1
        ld hl,(mtot)
        call dbcmp              ; t <= par
        jr nc,db1
        inc b
        ld hl,(mpar)            ; t <= 1.25 par
        ld d,h
        ld e,l
        srl d
        rr e
        srl d
        rr e
        add hl,de
        call dbcmp2
        jr nc,db1
        inc b
        ld hl,(mpar)            ; t <= 1.6 par
        ld d,h
        ld e,l
        srl d
        rr e
        add hl,de
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        add hl,de               ; ~1.56 par
        call dbcmp2
        jr nc,db1
        inc b
db1:    ld a,(mwasl)            ; finished with a rough landing: one down
        or a
        jr z,db2
        ld a,(lastg)
        cp 'D'
        jr c,db2
        ld a,b
        cp 4
        jr z,db2
        inc b
db2:    ld a,b
        ld (mrat),a
        ; logbook entry
        xor a
        ld (newbest),a
        ld a,(misno)
        call logent
        push hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr z,db3
        ld hl,(mtot)
        ex de,hl
        or a
        sbc hl,de               ; best - t
        jr c,db4
        jr z,db4
db3:    pop hl
        push hl
        ld de,(mtot)
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,1
        ld (newbest),a
db4:    pop hl
        inc hl
        inc hl
        ld a,(hl)
        or a
        jr z,db5
        ld a,(mrat)
        cp (hl)
        jr nc,db6
db5:    ld a,(mrat)
        ld (hl),a
db6:    inc hl
        inc (hl)                ; times flown
        call lsave
        ld (lsok),a
        ; ---- the screen
        call tcls
        ld hl,t_done
        ld de,SCREEN+2
        call ps2
        ld hl,(mptr)
        ld de,SCREEN+22
        ld bc,18
        ldir
        ld hl,t_time
        ld de,SCREEN+3*64+6
        call ps2
        ld hl,(mts)
        ld de,SCREEN+3*64+20
        call ttime
        ld hl,t_pen
        ld de,SCREEN+4*64+6
        call ps2
        ld hl,(mpen)
        ld de,SCREEN+4*64+20
        call ttime
        ld hl,t_total
        ld de,SCREEN+5*64+6
        call ps2
        ld hl,(mtot)
        ld de,SCREEN+5*64+20
        call ttime
        ld hl,t_par
        ld de,SCREEN+5*64+30
        call ps2
        ld hl,(mpar)
        ld de,SCREEN+5*64+40
        call ttime
        ld a,(mwasl)
        or a
        jr z,db7
        ld hl,t_lgr
        ld de,SCREEN+7*64+6
        call ps2
        ld a,(lastg)
        ld (SCREEN+7*64+21),a
db7:    ld hl,t_rating
        ld de,SCREEN+9*64+6
        call ps2
        ld a,(mrat)
        call ratname
        ld de,SCREEN+9*64+14
        call ps2
        ld a,(newbest)
        or a
        jr z,db8
        ld hl,t_newbest
        ld de,SCREEN+11*64+6
        call ps2
db8:    ld hl,t_saved
        ld a,(lsok)
        or a
        jr nz,db9
        ld hl,t_nosave
db9:    ld de,SCREEN+13*64+6
        call ps2
        ld hl,t_menu
        ld de,SCREEN+15*64+2
        call ps2
dbk:    call getkey
        cp K_SPC
        jr nz,dbk
        jp menu

; HL = t: carry clear if t <= (mpar)
dbcmp:  ld de,(mpar)
        ex de,hl
        or a
        sbc hl,de               ; par - t: no borrow when t <= par
        ret
; HL = limit: carry clear if (mtot) <= limit
dbcmp2: ld de,(mtot)
        or a
        sbc hl,de
        ret

; ---------------------------------------------------------------------
;  Logbook file (same name as the area, .LOG): load before taking over,
;  save after each mission.
; ---------------------------------------------------------------------
logfcbset:
        ld hl,logfcb
        ld b,36
lf1:    ld (hl),0
        inc hl
        djnz lf1
        ld hl,5Dh
        ld de,logfcb+1
        ld bc,8
        ldir
        ld hl,s_logtyp
        ld bc,3
        ldir
        ret

logload:
        call logfcbset
        ld c,15
        ld de,logfcb
        call 5
        inc a
        jr z,lginit
        ld c,26
        ld de,logb
        call 5
        ld c,20
        ld de,logfcb
        call 5
        push af
        ld c,16
        ld de,logfcb
        call 5
        pop af
        or a
        jr nz,lginit
        ld a,(logb)
        cp 'L'
        jr nz,lginit
        ld a,(logb+1)
        cp 'G'
        jr nz,lginit
        ld a,(logb+5)
        ld (bestg),a
        ret
lginit: ld hl,logb
        ld b,128
lg1:    ld (hl),0
        inc hl
        djnz lg1
        ld hl,'L'+'G'*256
        ld (logb),hl
        ld a,1
        ld (logb+2),a
        ld a,'Z'
        ld (logb+5),a
        ld (bestg),a
        ret

; -> A = 1 saved, 0 not
lsave:  ld a,(bestg)
        ld (logb+5),a
        call logfcbset
        ei                      ; CP/M may want its interrupts for the disk
        ld c,19                 ; delete the old one
        ld de,logfcb
        call 5
        call logfcbset
        ld c,22                 ; make
        ld de,logfcb
        call 5
        inc a
        jr z,lsf
        ld c,26
        ld de,logb
        call 5
        ld c,21                 ; write one record
        ld de,logfcb
        call 5
        push af
        ld c,16
        ld de,logfcb
        call 5
        pop af
        or a
        jr nz,lsf
        di
        call lsfix
        ld a,1
        ret
lsf:    di
        call lsfix
        xor a
        ret
lsfix:  ld a,EXT                ; our video settings back
        out (LATCH),a
        xor a
        out (COLP),a
        out (ROMLAT),a
        ret

s_logtyp: db "LOG"

; ---------------------------------------------------------------------
t_title:  db "SOUTHERN CROSS -",0
t_vibed:  db "VIBED BY BPM 2026",0
t_mhead:  db "MISSIONS                    BEST TIME  RATING          FLOWN",0
t_free:   db "F  FREE FLIGHT  (R RUNWAY, F FINAL, N NEXT AIRFIELD, M MENU)",0
t_land:   db "LANDINGS",0
t_bgrade: db "BEST LANDING GRADE",0
t_pick:   db "PRESS A MISSION NUMBER, OR F FOR FREE FLIGHT",0
t_mis:    db "MISSION  :",0
t_par:    db "PAR TIME",0
t_ybest:  db "YOUR BEST",0
t_fly:    db "SPACE TO FLY   ESC FOR THE MENU   (M IN FLIGHT: BACK TO MENU)",0
t_done:   db "MISSION COMPLETE:",0
t_time:   db "FLYING TIME",0
t_pen:    db "PENALTIES",0
t_total:  db "TOTAL",0
t_lgr:    db "LANDING GRADE",0
t_rating: db "RATING",0
t_newbest: db "** NEW BEST TIME **",0
t_saved:  db "LOGBOOK SAVED TO DISK.",0
t_nosave: db "COULD NOT SAVE THE LOGBOOK (DISK FULL OR WRITE-PROTECTED?)",0
t_menu:   db "SPACE FOR THE MENU",0
ratings:  dw s_r1,s_r2,s_r3,s_r4
s_r1:     db "ACE AVIATOR",0
s_r2:     db "CAPTAIN",0
s_r3:     db "FIRST OFFICER",0
s_r4:     db "STUDENT PILOT",0
s_rnone:  db "-",0
m_gate:   db "GATE ",0
m_gate2:  db " AHEAD - SEE THE GUIDE LINE",0
m_of:     db " OF ",0
m_gt:     db "GATE ",0
m_mtr:    db " M",0
m_ft:     db " FT",0
m_landat: db "NOW LAND AT ",0
m_lgrade: db " (LAST LANDING: ",0
m_mdone:  db "MISSION COMPLETE!",0
m_wide:   db "MISSED - WIDE OF THE GATE",0
m_low:    db "MISSED - UNDER THE GATE",0
m_high:   db "MISSED - OVER THE GATE",0
m_again2: db ". COME ROUND AND TRY AGAIN.",0
m_rbackg: db "BACK AT THE LAST GATE. 15 SECONDS ADDED.",0
m_rbackr: db "BACK ON THE RUNWAY. 15 SECONDS ADDED.",0
m_rbacks: db "BACK AT THE START. 15 SECONDS ADDED.",0
s_dround: db "TURN ROUND",0
s_dahead: db "  AHEAD   ",0
s_dirs:   dw s_d0,s_d1,s_d2,s_d3,s_d4,s_d5
s_d0:     db "  RIGHT > ",0
s_d1:     db "  RIGHT >>",0
s_d2:     db " RIGHT >>>",0
s_d3:     db " < LEFT   ",0
s_d4:     db "<< LEFT   ",0
s_d5:     db "<<< LEFT  ",0
s_climb:  db "CLIMB",0
s_desc:   db "LOWER",0
s_hok:    db "OK   ",0
