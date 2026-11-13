; =====================================================================
;  FLIGHT: input, physics (plane + helicopter), missions, views, HUD
; =====================================================================

; ---------------------------------------------------------------- interrupt
; one per field; returns with interrupts off (poll turns them back on after sync)
isr:    push af
        push hl
        push de
        push bc
        ld hl,fcount
        inc (hl)
        ld hl,(ftick)
        inc hl
        ld (ftick),hl
        ld a,(musptr+1)
        or a
        jr z,.eng
        call musick
        jr .q
.eng:   ld a,(engdly)
        or a
        jr z,.q
        ld h,a
        ld a,(heli)
        or a
        jr z,.e1
        ld a,(fcount)          ; helicopter: chop the drone into blade thumps
        and 3
        jr nz,.q
        ld a,h
        add a,a
        ld h,a
.e1:    ld a,(latchv)
        or $01
        ld (latch),a
        ld l,h
.d1:    dec l
        jr nz,.d1
        xor $21
        ld (latch),a
        ld l,h
.d2:    dec l
        jr nz,.d2
        ld a,(latchv)
        ld (latch),a
.q:     pop bc
        pop de
        pop hl
        pop af
        ret

; ---------------------------------------------------------------- music (in the interrupt)
; note = period byte (1 = rest, 0 = end, $ff = loop), half-cycles, duration in fields
musick: ld a,(mustim)
        or a
        jr z,.next
        dec a
        ld (mustim),a
        ld a,(musblip)
        or a
        ret z
        dec a
        ld (musblip),a
        jr blip
.next:  ld hl,(musptr)
        ld a,(hl)
        or a
        jr nz,.n1
        ld (musptr+1),a
        ret
.n1:    cp $ff
        jr nz,.n2
        ld hl,(musloop)
        ld (musptr),hl
        ld a,(hl)
.n2:    ld (musn),a
        inc hl
        ld a,(hl)
        ld (musc),a
        inc hl
        ld a,(hl)
        dec a
        ld (mustim),a
        inc hl
        ld (musptr),hl
        ld a,2
        ld (musblip),a
blip:   ld a,(musn)
        cp 2
        ret c
        ld d,a
        ld a,(musc)
        ld b,a
        ld a,(latchv)
        or $01
.l:     ld (latch),a
        ld e,d
.d:     dec e
        jr nz,.d
        xor $21
        djnz .l
        ld a,(latchv)
        ld (latch),a
        ret

musplay:
        xor a
        ld (musptr+1),a
        ld (mustim),a
        ld (musblip),a
        ld (musloop),hl
        ld a,l
        ld (musptr),a
        ld a,h
        ld (musptr+1),a
        ret

musstop:
        xor a
        ld (musptr+1),a
        ret

poll:   ld a,(latch)
        rla
        ret nc
        ei
        ret

; wait for the next field
waitf:  ld a,(fcount)
        ld b,a
.w:     call poll
        ld a,(fcount)
        cp b
        jr z,.w
        ret

; wait for field sync, copy back buffer to screen (tear free), count fields
flip:   ld a,(latch)
        rla
        jr nc,.go
        ld hl,fcount
        ld a,(hl)
        ei
.w:     cp (hl)
        jr z,.w
.go:    di
        ld hl,buf
        ld de,vram
        ld bc,1536
.cp:    call copy32
        jp pe,.cp
        ld a,(fcount)
        ld hl,flast
        ld b,(hl)
        ld (hl),a
        sub b
        jr nz,.nz
        inc a
.nz:    cp 13
        jr c,.ok
        ld a,12
.ok:    ld (nf),a
        ei
        ret

; ---------------------------------------------------------------- input
; menu keys -> A: bit0 up, 1 down, 2 left, 3 right, 4 fire/space, 5 return, 6 P
kscan:  ld c,0
        ld a,($68fe)
        bit 4,a
        jr nz,.q1
        set 0,c
.q1:     ld a,($68fd)
        bit 4,a
        jr nz,.q2
        set 1,c
.q2:     ld a,($68ef)
        bit 5,a
        jr nz,.q3
        set 2,c
.q3:     bit 3,a
        jr nz,.q4
        set 3,c
.q4:     bit 4,a
        jr nz,.q5
        set 4,c
.q5:     ld a,($68bf)
        bit 2,a
        jr nz,.q6
        set 5,c
.q6:     bit 4,a
        jr nz,.q7
        set 6,c
.q7:     call joyrd
        ld a,b
        or c
        ret

; joystick 1 -> B: bit0 up, 1 down, 2 left, 3 right, 4 fire (0 if no stick)
joyrd:  ld b,0
        in a,($2c)
        cpl
        and $0f
        ld e,a
        and $03
        cp $03
        ret z
        ld a,e
        and $0c
        cp $0c
        ret z
        ld b,e
        in a,($2e)
        ld d,a
        and $0f
        ret z
        bit 4,d
        ret nz
        set 4,b
        ret

; newly pressed keys -> A
kedge:  call kscan
        ld b,a
        ld a,(kold)
        cpl
        and b
        ld c,a
        ld a,b
        ld (kold),a
        ld a,c
        ret

; wait until nothing is held
keyrel: call waitf
        call kscan
        or a
        jr nz,keyrel
        ld (kold),a
        ret

; flight keys: ctrl bits 0 nose up, 1 nose down, 2 left, 3 right, 4 thr+, 5 thr-, 6 brake
;              ctrl2 bits 0 P, 1-4 views, 5 map, 6 RETURN, 7 R (ctrl2e = newly pressed)
readkeys:
        ld a,(demo)
        or a
        jr z,.k0
        call kscan
        and $7f
        jr z,.dm
        ld a,2
        ld (quitf),a
.dm:    xor a
        ld (ctrl),a
        ld (ctrl2e),a
        jp autopilot
.k0:    ld c,0
        ld a,($68fe)
        bit 4,a
        jr nz,.k1
        set 0,c
.k1:    bit 1,a
        jr nz,.k3
        set 4,c
.k3:    ld a,($68fd)
        bit 4,a
        jr nz,.k4
        set 1,c
.k4:    bit 1,a
        jr nz,.k5
        set 5,c
.k5:    ld a,($68ef)
        bit 5,a
        jr nz,.k6
        set 2,c
.k6:    bit 3,a
        jr nz,.k7
        set 3,c
.k7:    bit 4,a
        jr nz,.k8
        set 6,c
.k8:    push bc
        call joyrd
        pop hl
        ld c,l
        ld a,b
        or a
        jr z,.nj
        bit 0,b
        jr z,.j1
        set 1,c
.j1:    bit 1,b
        jr z,.j2
        set 0,c
.j2:    bit 2,b
        jr z,.j3
        set 2,c
.j3:    bit 3,b
        jr z,.j4
        set 3,c
.j4:    bit 4,b
        jr z,.j5
        set 4,c
.j5:    in a,($2d)
        bit 4,a
        jr nz,.nj
        set 5,c
.nj:    ld a,c
        ld (ctrl),a
        ; ---- second set
        ld c,0
        ld a,($68bf)
        bit 4,a
        jr nz,.a1
        set 0,c
.a1:    bit 2,a
        jr nz,.a2
        set 6,c
.a2:    ld a,($68f7)
        bit 4,a
        jr nz,.a3
        set 1,c
.a3:    bit 1,a
        jr nz,.a4
        set 2,c
.a4:    bit 3,a
        jr nz,.a5
        set 3,c
.a5:    bit 5,a
        jr nz,.a6
        set 4,c
.a6:    bit 0,a
        jr nz,.a7
        set 5,c
.a7:    ld a,($68fe)
        bit 5,a
        jr nz,.a8
        set 7,c
.a8:    ld a,(ctrl2)
        cpl
        and c
        ld (ctrl2e),a
        ld a,c
        ld (ctrl2),a
        ret

; ---------------------------------------------------------------- main flight loop
; returns with quitf: 1 quit / demo timeout, 2 key pressed in demo, 3 mission complete
flyloop:
        call readkeys
        ld a,(quitf)
        or a
        ret nz
        ld a,(ctrl2e)
        bit 0,a
        call nz,dopause
        ld a,(quitf)
        or a
        ret nz
        ld a,(ctrl2e)
        bit 7,a
        call nz,startmis
        call viewkeys
        call physics
        call mtimer
        call setview
        call buildmat
        call drawbg
        call poll
        call drawgrid
        call drawobjs
        call drawgoal
        ld a,(view)
        cp 4
        call z,drawarrow
        call overlay
        call drawmsg
        call flip
        call drawpanel
        ld a,(demo)
        or a
        jr z,.nd
        ld hl,(ftick)
        ld de,(demoend)
        or a
        sbc hl,de
        jr c,.nd
        ld a,1
        ld (quitf),a
        ret
.nd:    ld a,(mdone)
        or a
        jr z,flyloop
        ld b,a
        ld a,(nf)
        ld c,a
        ld a,b
        sub c
        jr c,.fin
        jr z,.fin
        ld (mdone),a
        jr flyloop
.fin:   ld a,3
        ld (quitf),a
        ret

mtimer: ld a,(mdone)
        or a
        ret nz
        ld a,(crash)
        or a
        ret nz
        ld a,(mfld)
        ld b,a
        ld a,(nf)
        add a,b
.l:     cp 50
        jr c,.s
        sub 50
        ld hl,(msec)
        inc hl
        ld (msec),hl
        jr .l
.s:     ld (mfld),a
        ret

; ---------------------------------------------------------------- mission start
startmis:
        ld ix,(curloc)
        ld a,(ix+4)
        or $08
        ld (latchv),a
        ld (latch),a
        ld a,(ix+5)
        ld (skycol),a
        ld a,(ix+6)
        ld (gndcol),a
        ld a,(ix+7)
        ld (gridcol),a
        ld l,(ix+8)
        ld h,(ix+9)
        ld (objp),hl
        ld l,(ix+10)
        ld h,(ix+11)
        ld (obst),hl
        ld l,(ix+12)
        ld h,(ix+13)
        ld (plats),hl
        ld l,(ix+14)
        ld h,(ix+15)
        ld (shipobj),hl
        ld a,(ix+16)
        ld (water),a
        ld a,(ix+17)
        ld (ovink),a
        ld a,h
        or l
        jr z,.nship
        ld e,(ix+18)
        ld d,(ix+19)
        push hl
        pop iy
        ld (iy+2),e
        ld (iy+3),d
        xor a
        ld (shipz24),a
        ld (shipz24+1),de
        ld (shipz),de
        ld l,(iy+0)
        ld h,(iy+1)
        ld (shipx),hl
.nship: ld hl,fltvars
        ld de,fltvars+1
        ld bc,fltend-fltvars-1
        ld (hl),0
        ldir
        ld iy,(curmis)
        ld a,(iy+4)
        ld (heli),a
        ld l,(iy+5)
        ld h,(iy+6)
        ld (px+2),hl
        ld l,(iy+7)
        ld h,(iy+8)
        ld (pz+2),hl
        ld l,(iy+9)
        ld h,(iy+10)
        ld (py+2),hl
        ld l,(iy+11)
        ld h,(iy+12)
        ld (yaw3+1),hl
        ld a,(iy+13)
        ld (spd+2),a
        ld a,(iy+14)
        ld (thr),a
        ld a,(iy+15)
        ld (ongnd),a
        ld l,(iy+16)
        ld h,(iy+17)
        ld (fuel),hl
        ld (fuelmax),hl
        ld a,(iy+21)
        ld (goalcnt),a
        push iy
        pop hl
        ld de,22
        add hl,de
        ld (goalp),hl
        xor a
        ld (goalidx),a
        ld (mfld),a
        ld (crashes),a
        ld (mdone),a
        ld (view),a
        ld (quitf),a
        ld (nofuel),a
        ld (ctrl2),a
        ld (ctrl2e),a
        ld hl,0
        ld (msec),hl
        ld a,(demo)
        ld (apon),a
        call settrig
        call shippos
        call saveck
        call panelinit
        ld hl,msg_go
        ld a,(goalcnt)
        or a
        jr nz,.m
        ld hl,msg_free
.m:     ld a,(demo)
        or a
        jr z,.m2
        ld hl,msg_demo
.m2:    call setmsg
        ld a,(fcount)
        ld (flast),a
        ld a,1
        ld (nf),a
        ret

; ---------------------------------------------------------------- checkpoints
saveck: ld hl,fltvars
        ld de,ckbuf
        ld bc,fltend-fltvars
        ldir
        ld hl,(fuel)
        ld (ckfuel),hl
        ret

loadck: ld hl,ckbuf
        ld de,fltvars
        ld bc,fltend-fltvars
        ldir
        ld hl,(ckfuel)
        ld (fuel),hl
        ; forgiving: always at least a third of a tank after a retry
        ld hl,(fuelmax)
        ld a,h
        or l
        jr z,.nf
        ld e,l
        ld d,h
        srl d
        rr e
        srl d
        rr e
        ld hl,(fuel)
        or a
        sbc hl,de
        jr nc,.nf
        ld (fuel),de
.nf:    xor a
        ld (nofuel),a
        call settrig
        ld hl,msg_retry
        jp setmsg

; ---------------------------------------------------------------- physics
physics:
        ld a,(crash)
        or a
        jp nz,crashed
        call fuelburn
        call shipmove
        ld a,(heli)
        or a
        jr z,.pl
        call heliphys
        jr .com
.pl:    call planephys
.com:   ld hl,(vx88)
        ld ix,px
        call addvel
        ld hl,(vz88)
        ld ix,pz
        call addvel
        ld hl,(vs88)
        ld ix,py
        call addvel
        call contact
        ld a,(crash)
        or a
        ret nz
        call goals
        ; out of fuel and down somewhere that isn't the goal: retry
        ld a,(nofuel)
        or a
        ret z
        ld a,(ongnd)
        or a
        ret z
        ld a,(mdone)
        or a
        ret nz
        ld hl,msg_nofuel
        jp crashm

crashed:
        ld a,(nf)
        ld b,a
        ld a,(crash)
        sub b
        jr c,.rs
        jr z,.rs
        ld (crash),a
        ret
.rs:    xor a
        ld (crash),a
        jp loadck

fuelburn:
        ld hl,(fuelmax)
        ld a,h
        or l
        ret z
        ; each field burns (thr/2 + 48)/256 units: about 25 units a second at cruise power
        ld a,(thr)
        srl a
        add a,48
        ld c,a
        ld a,(nf)
        ld b,a
.l:     ld a,(facc)
        add a,c
        ld (facc),a
        jr nc,.n
        ld hl,(fuel)
        ld a,h
        or l
        jr z,.out
        dec hl
        ld (fuel),hl
.n:     djnz .l
        ret
.out:   ld hl,0
        ld (fuel),hl
        ld a,(nofuel)
        or a
        ret nz
        inc a
        ld (nofuel),a
        ld hl,msg_empty
        jp setmsg

; throttle / collective from W S (ctrl in C)
thrctl: ld a,(nf)
        ld b,a
        add a,a
        add a,b
        ld b,a
        ld a,(thr)
        bit 4,c
        jr z,.t1
        add a,b
        jr nc,.t2
        ld a,255
        jr .t2
.t1:    bit 5,c
        jr z,.t2
        sub b
        jr nc,.t2
        xor a
.t2:    ld (thr),a
        ret

; ---------------------------------------------------------------- aeroplane
planephys:
        ld a,(ctrl)
        ld c,a
        call thrctl
        ld a,(nofuel)
        or a
        jr z,.t3
        xor a
        ld (thr),a
.t3:    ld a,(thr)
        or a
        jr z,.e0
        rrca
        rrca
        rrca
        and $1f
        ld b,a
        ld a,60
        sub b
.e0:    ld (engdly),a
        ld a,(spd+2)
        ld (spdi),a
        ld hl,0
        ld (prate),hl
        ld (rrate),hl
        xor a
        ld (stall),a
        ld a,(ongnd)
        or a
        jp nz,.gctl
        ld a,(airtime)
        inc a
        jr z,.at
        ld (airtime),a
.at:    ld a,(spdi)
        cp 15
        jr c,.na
        bit 0,c
        jr z,.p1
        ld hl,pitchrate
        ld (prate),hl
.p1:    bit 1,c
        jr z,.p2
        ld hl,-pitchrate
        ld (prate),hl
.p2:    bit 3,c
        jr z,.r1
        ld hl,rollrate
        ld (rrate),hl
.r1:    bit 2,c
        jr z,.na
        ld hl,-rollrate
        ld (rrate),hl
.na:    call apctl
        ld hl,(rrate)
        ld a,h
        or l
        jr nz,.al
        ld hl,(roll3+1)
        call neghl
        ld (rrate),hl
.al:    ld hl,32767
        ld de,(csr)
        or a
        sbc hl,de
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ex de,hl
        ld hl,(prate)
        or a
        sbc hl,de
        ld (prate),hl
        ld a,(spdi)
        cp vstall
        jr nc,.ctl
        ld a,1
        ld (stall),a
        ld hl,-12288
        ld (prate),hl
        jr .ctl
.gctl:  ld hl,-8192
        ld (prate),hl
        ld a,(spdi)
        cp 25
        jr c,.ctl
        bit 0,c
        jr z,.ctl
        ld hl,pitchrate
        ld (prate),hl
.ctl:   ld hl,pitch3
        ld de,(prate)
        ld a,(nf)
        ld b,a
        call addn24
        ld hl,roll3
        ld de,(rrate)
        ld a,(nf)
        ld b,a
        call addn24
        ld a,(ongnd)
        or a
        jr nz,.gcl
        ld hl,(pitch3+1)
        ld de,pmax
        call clamp
        ld (pitch3+1),hl
        ld hl,(roll3+1)
        ld de,rmax
        call clamp
        ld (roll3+1),hl
        jr .trig
.gcl:   ld hl,0
        ld (roll3),hl
        ld (roll3+1),hl
        ld hl,(pitch3+1)
        bit 7,h
        jr z,.gc1
        ld hl,0
        ld (pitch3),hl
        ld (pitch3+1),hl
        jr .trig
.gc1:   ld de,gpmax
        call clamp
        ld (pitch3+1),hl
.trig:  call settrig
        ; ---- speed: thrust - drag - gravity - friction
        ld a,(thr)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push hl
        ld a,(spdi)
        ld b,a
        call umul8
        ld d,h
        ld e,l
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        or a
        sbc hl,de
        ex de,hl
        pop hl
        or a
        sbc hl,de
        push hl
        ld de,12845
        ld bc,(snp)
        call fmul
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld a,(ongnd)
        or a
        jr z,.nfr
        ld de,-400
        add hl,de
        ld a,(ctrl)
        bit 6,a
        jr z,.nfr
        ld de,-4000
        add hl,de
.nfr:   call addspd
        ld de,(spd+1)
        ld bc,(snp)
        call fmul
        ld (vs88),hl
        ld de,(spd+1)
        ld bc,(csp)
        call fmul
        ld (vh88),hl
        ex de,hl
        ld bc,(sny)
        call fmul
        ld (vx88),hl
        ld de,(vh88)
        ld bc,(csy)
        call fmul
        ld (vz88),hl
        ld a,(stall)
        or a
        jr z,.ns
        ld a,(spdi)
        ld b,a
        ld a,vstall
        sub b
        ld h,a
        ld l,0
        srl h
        rr l
        ex de,hl
        ld hl,(vs88)
        or a
        sbc hl,de
        ld (vs88),hl
.ns:    ld a,(ongnd)
        or a
        jr z,.yaw
        ld a,(spdi)
        cp vr
        jr c,.stay
        ld hl,(vs88)
        bit 7,h
        jr nz,.stay
        ld a,h
        or l
        jr z,.stay
        xor a
        ld (ongnd),a
        ld (airtime),a
        jr .yaw
.stay:  ld hl,0
        ld (vs88),hl
.yaw:   ld a,(ongnd)
        or a
        jr nz,.gyaw
        ld de,(snr)
        ld bc,16352
        call fmul
        ld a,h
        ld (ysgn),a
        bit 7,h
        call nz,neghl
        ld de,0
        ld b,5
.ys:    add hl,hl
        rl e
        rl d
        djnz .ys
        ld a,(spdi)
        cp 20
        jr nc,.yv
        ld a,20
.yv:    ld c,a
        ld b,0
        call udiv32
        ld a,(ysgn)
        or a
        call m,neghl
        ex de,hl
        jr .yadd
.gyaw:  ld de,0
        ld a,(spdi)
        or a
        jr z,.yadd
        ld a,(ctrl)
        bit 3,a
        jr z,.gy1
        ld de,15360
.gy1:   bit 2,a
        jr z,.yadd
        ld de,-15360
.yadd:  ld hl,yaw3
        ld a,(nf)
        ld b,a
        jp addn24

; add force HL (1/65536 m/s per field) nf times to spd, clamp 0..100 m/s
addspd: ld a,h
        add a,a
        sbc a,a
        ld e,a
        ld d,a
        ld ix,spd
        ld a,(nf)
        ld b,a
        call add32n
        ld a,(spd+3)
        or a
        jp p,.sp1
        ld hl,0
        ld (spd),hl
        ld (spd+2),hl
        ret
.sp1:   ld hl,(spd+2)
        ld de,100
        or a
        sbc hl,de
        ret c
        ld hl,100
        ld (spd+2),hl
        ld hl,0
        ld (spd),hl
        ret

; autopilot steering (demo): smooth roll / pitch toward the targets
apctl:  ld a,(apon)
        or a
        ret z
        ld hl,(aprol)
        ld de,(roll3+1)
        or a
        sbc hl,de
        ld de,4000
        call clamp
        add hl,hl
        add hl,hl
        add hl,hl
        ld (rrate),hl
        ld hl,(appit)
        ld de,(pitch3+1)
        or a
        sbc hl,de
        ld de,2000
        call clamp
        add hl,hl
        add hl,hl
        add hl,hl
        ld (prate),hl
        ret

; ---------------------------------------------------------------- helicopter
heliphys:
        ld a,(ctrl)
        ld c,a
        call thrctl
        ld a,(thr)
        rrca
        rrca
        rrca
        and $1f
        ld b,a
        ld a,44
        sub b
        ld (engdly),a
        ld a,(spd+2)
        ld (spdi),a
        xor a
        ld (stall),a
        ld a,(ongnd)
        or a
        jr nz,.gnd
        ld a,(airtime)
        inc a
        jr z,.gnd
        ld (airtime),a
.gnd:   ; ---- cyclic: Q nose up (slow down), A nose down (go forward)
        ld de,0
        bit 0,c
        jr z,.p1
        ld de,6144
.p1:    bit 1,c
        jr z,.p2
        ld de,-6144
.p2:    ld hl,pitch3
        ld a,(nf)
        ld b,a
        call addn24
        ld hl,(pitch3+1)
        ld de,3640
        call clamp
        ld (pitch3+1),hl
        ld a,(ongnd)
        or a
        jr z,.p3
        ld hl,0
        ld (pitch3),hl
        ld (pitch3+1),hl
.p3:    ; ---- pedals: M , turn (also on the ground), small visual bank in the air
        ld de,0
        ld hl,0
        ld a,(ctrl)
        bit 3,a
        jr z,.y1
        ld de,22000
        ld hl,1820
.y1:    bit 2,a
        jr z,.y2
        ld de,-22000
        ld hl,-1820
.y2:    ld a,(ongnd)
        or a
        jr z,.y3
        ld hl,0
.y3:    xor a
        ld (roll3),a
        ld (roll3+1),hl
        ld hl,yaw3
        ld a,(nf)
        ld b,a
        call addn24
        call settrig
        ; ---- forward speed: rotor tilt minus drag
        ld a,(ongnd)
        or a
        jr z,.air
        ld hl,-20000
        jr .adf
.air:   ld de,12845
        ld bc,(snp)
        call fmul
        call neghl
        push hl
        ld de,(spd+1)
        ld bc,10066
        call fmul
        ex de,hl
        pop hl
        or a
        sbc hl,de
.adf:   call addspd
        ld hl,(spd+2)
        ld de,70
        or a
        sbc hl,de
        jr c,.vt
        ld hl,70
        ld (spd+2),hl
.vt:    ; ---- collective: 128 = hover, +-8 m/s
        ld a,(thr)
        sub 128
        ld l,a
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(nofuel)
        or a
        jr z,.v0
        ld hl,-768                ; autorotation
.v0:    ld (vtgt),hl
        ld a,(ongnd)
        or a
        jr z,.va
        ld de,-257
        add hl,de
        bit 7,h
        jr nz,.sit
        xor a
        ld (ongnd),a
        ld (airtime),a
        ld hl,256
        ld (vs88),hl
        jr .vel
.sit:   ld hl,0
        ld (vs88),hl
        jr .vel
.va:    ld a,(nf)
        cp 9
        jr c,.v1
        ld a,8
.v1:    ld b,a
.v2:    ld hl,(vtgt)
        ld de,(vs88)
        or a
        sbc hl,de
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        add hl,de
        ld (vs88),hl
        djnz .v2
.vel:   ld de,(spd+1)
        ld bc,(sny)
        call fmul
        ld (vx88),hl
        ld de,(spd+1)
        ld bc,(csy)
        call fmul
        ld (vz88),hl
        ret

; ---------------------------------------------------------------- ship
shipmove:
        ld hl,(shipobj)
        ld a,h
        or l
        ret z
        ld a,(nf)
        ld b,a
        ld de,31
        ld hl,shipz24
        call addn24
shippos:
        ld hl,(shipobj)
        ld a,h
        or l
        ret z
        push hl
        pop iy
        ld hl,(shipz24+1)
        ld (shipz),hl
        ld (iy+2),l
        ld (iy+3),h
        ld l,(iy+0)
        ld h,(iy+1)
        ld (shipx),hl
        ret

; HL = |HL|
absh:   bit 7,h
        ret z
        jp neghl

; HL = x(+shipx), DE = z(+shipz) when A = ship type (B = ship type id)
shipofs:
        cp b
        ret nz
        push hl
        ld hl,(shipz)
        add hl,de
        ex de,hl
        pop hl
        push de
        ld de,(shipx)
        add hl,de
        pop de
        ret

; is the aircraft inside |px-HL|<(IX+o) and |pz-DE|<(IX+o+2)?  enter with BC = IX offset of hx
; carry set if inside
inrect: push de
        ld de,(px+2)
        or a
        sbc hl,de
        call absh
        push ix
        add ix,bc
        ld e,(ix+0)
        ld d,(ix+1)
        or a
        sbc hl,de
        pop ix
        pop de
        ret nc
        ex de,hl
        ld de,(pz+2)
        or a
        sbc hl,de
        call absh
        push ix
        add ix,bc
        ld e,(ix+2)
        ld d,(ix+3)
        or a
        sbc hl,de
        pop ix
        ret

; ---------------------------------------------------------------- ground and obstacles
groundh:
        ld hl,0
        ld (gh),hl
        xor a
        ld (onplat),a
        ld (onship),a
        ld ix,(plats)
.l:     ld a,(ix+0)
        or a
        ret z
        ld l,(ix+1)
        ld h,(ix+2)
        ld e,(ix+3)
        ld d,(ix+4)
        ld b,2
        call shipofs
        ld bc,5
        call inrect
        jr nc,.nx
        ld l,(ix+9)
        ld h,(ix+10)
        ld (gh),hl
        ld a,1
        ld (onplat),a
        ld a,(ix+0)
        cp 2
        jr nz,.nx
        ld (onship),a
.nx:    ld de,11
        add ix,de
        jr .l

contact:
        call groundh
        ld a,(ongnd)
        or a
        jr z,.air
        ld hl,(py+2)
        ld de,(gh)
        or a
        sbc hl,de
        jr z,.set
        jp m,.set
        ld a,h
        or a
        jr nz,.fall
        ld a,l
        cp 4
        jr c,.set
.fall:  xor a
        ld (ongnd),a
        ret
.set:   ld hl,0
        ld (py),hl
        ld hl,(gh)
        ld (py+2),hl
        ld a,(onship)
        or a
        ret z
        ld hl,7936
        ld de,0
        ld ix,pz
        ld a,(nf)
        ld b,a
        jp add32n
.air:   ld a,(py+3)
        or a
        jp m,.under
        ld hl,(py+2)
        ld de,(gh)
        or a
        sbc hl,de
        jr z,.lvl
        jp p,obstac
        jr .under
.lvl:   ld a,(vs88+1)               ; level with the ground but still climbing: not a touchdown
        or a
        jp p,obstac
        jr .tch
.under: ld hl,(py+2)
        ld de,(gh)
        or a
        sbc hl,de
        ld de,6
        add hl,de
        bit 7,h
        jp nz,crashit
.tch:   ld a,(water)
        or a
        jr z,.nw
        ld a,(onplat)
        or a
        jr nz,.nw
        ld hl,msg_ditch
        jp crashm
.nw:    ld hl,(vs88)
        ld de,1280
        ld a,(heli)
        or a
        jr z,.v1
        ld de,1100
.v1:    add hl,de
        bit 7,h
        jr nz,.hard
        ld hl,(roll3+1)
        call absh
        ld de,3640
        or a
        sbc hl,de
        jr nc,.hard
        ld a,(heli)
        or a
        jr nz,.hs
        ld hl,(pitch3+1)
        ld de,1092
        add hl,de
        bit 7,h
        jr nz,.hard
        jr .ok
.hs:    ld a,(spd+2)
        cp 14
        jr nc,.hard
.ok:    ld a,1
        ld (ongnd),a
        ld hl,0
        ld (vs88),hl
        ld a,(airtime)
        cp 12
        jr c,.q
        ld hl,msg_land
        call setmsg
.q:     jp .set
.hard:  ld hl,msg_hard
        jp crashm

obstac: ld ix,(obst)
.l:     ld a,(ix+0)
        or a
        jp z,.ceil
        cp 2
        jr z,.pyr
        ld l,(ix+1)
        ld h,(ix+2)
        ld e,(ix+3)
        ld d,(ix+4)
        ld b,3
        call shipofs
        ld bc,5
        call inrect
        jr nc,.nx
        ld hl,(py+2)
        ld e,(ix+9)
        ld d,(ix+10)
        or a
        sbc hl,de
        jp m,.nx
        ld hl,(py+2)
        ld e,(ix+11)
        ld d,(ix+12)
        or a
        sbc hl,de
        jp m,crashit
.nx:    ld de,13
        add ix,de
        jr .l
.pyr:   ld l,(ix+1)
        ld h,(ix+2)
        ld bc,(px+2)
        or a
        sbc hl,bc
        call absh
        push hl
        ld l,(ix+3)
        ld h,(ix+4)
        ld bc,(pz+2)
        or a
        sbc hl,bc
        call absh
        pop bc
        push hl
        or a
        sbc hl,bc
        pop hl
        jr nc,.mx
        ld h,b
        ld l,c
.mx:    ex de,hl
        ld l,(ix+5)
        ld h,(ix+6)
        or a
        sbc hl,de
        jr c,.nx
        jr z,.nx
        ld d,h
        ld e,l
        srl d
        rr e
        srl d
        rr e
        or a
        sbc hl,de
        ld de,(py+2)
        or a
        sbc hl,de
        jr c,.nx
        jr z,.nx
        jp crashit
.ceil:  ld hl,(py+2)
        ld de,9000
        or a
        sbc hl,de
        ret c
        ld hl,9000
        ld (py+2),hl
        ret

crashit:
        ld hl,msg_crash
crashm: call setmsg
        ld a,150
        ld (crash),a
        ld hl,crashes
        inc (hl)
        xor a
        ld (engdly),a
        ld (stall),a
        ld hl,0
        ld (spd),hl
        ld (spd+2),hl
        ld (vs88),hl
        ld a,(py+3)
        or a
        jp p,.c1
        ld (py),hl
        ld (py+2),hl
.c1:    jp crashsnd

; ---------------------------------------------------------------- goals
; target of goal IX -> tgx,tgz
goaltgt:
        ld l,(ix+1)
        ld h,(ix+2)
        ld e,(ix+3)
        ld d,(ix+4)
        ld a,(ix+0)
        cp 3
        jr c,.s
        push hl
        ld hl,(shipz)
        add hl,de
        ex de,hl
        pop hl
        push de
        ld de,(shipx)
        add hl,de
        pop de
.s:     ld (tgx),hl
        ld (tgz),de
        ret

goals:  ld a,(demo)
        or a
        jp nz,bearing
        ld a,(mdone)
        or a
        ret nz
        ld a,(goalcnt)
        or a
        ret z
        ld ix,(goalp)
        call goaltgt
        call bearing
        ld a,(ix+0)
        cp 2
        jr z,.land
        cp 3
        jr z,.land
        call .rect
        ret nc
        ld hl,(py+2)
        ld e,(ix+7)
        ld d,(ix+8)
        or a
        sbc hl,de
        ret m
        ld hl,(py+2)
        ld e,(ix+9)
        ld d,(ix+10)
        or a
        sbc hl,de
        ret p
        jr .pass
.land:  ld a,(ongnd)
        or a
        ret z
        ld a,(spd+2)
        cp 3
        ret nc
        ld a,(ix+0)
        cp 3
        jr nz,.l2
        ld a,(onship)
        or a
        ret z
.l2:    call .rect
        ret nc
.pass:  ld a,(goalidx)
        inc a
        ld (goalidx),a
        ld hl,(goalp)
        ld de,16
        add hl,de
        ld (goalp),hl
        ld b,a
        ld a,(goalcnt)
        cp b
        jr z,.done
        call saveck
        ld hl,msg_gate
        call setmsg
        ld hl,tune_gate
        jp musplay
.done:  ld a,180
        ld (mdone),a
        xor a
        ld (engdly),a
        ld hl,msg_done
        call setmsg
        ld hl,tune_done
        jp musplay
.rect:  ld hl,(tdx)
        call absh
        ld e,(ix+5)
        ld d,(ix+6)
        or a
        sbc hl,de
        ret nc
        ld hl,(tdz)
        call absh
        ld e,(ix+5)
        ld d,(ix+6)
        or a
        sbc hl,de
        ret

; bearing and distance to (tgx,tgz) using the aircraft heading
bearing:
        ld hl,(tgx)
        ld de,(px+2)
        or a
        sbc hl,de
        ld (tdx),hl
        ld hl,(tgz)
        ld de,(pz+2)
        or a
        sbc hl,de
        ld (tdz),hl
        ld hl,(tdx)
        call absh
        push hl
        ld hl,(tdz)
        call absh
        pop de
        or a
        sbc hl,de
        add hl,de
        jr nc,.o
        ex de,hl
.o:     srl d
        rr e
        add hl,de
        jr nc,.nc
        ld hl,$ffff
.nc:    ld (gdm),hl
        ld de,0
        ld bc,100
        call udiv32
        ld de,999
        call clamp
        ld (gdist),hl
        ; heading-relative offsets
        ld hl,(tdx)
        ld de,(tdz)
        ld a,(gdm+1)
        cp $3e
        jr c,.sm
        sra h
        rr l
        sra d
        rr e
.sm:    ld (tdx2),hl
        ld (tdz2),de
        ld de,(tdx2)
        ld bc,(csy)
        call fmul
        push hl
        ld de,(tdz2)
        ld bc,(sny)
        call fmul
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld (relx),hl
        ld de,(tdx2)
        ld bc,(sny)
        call fmul
        push hl
        ld de,(tdz2)
        ld bc,(csy)
        call fmul
        pop de
        add hl,de
        ld (relz),hl
        ; classify: turn level -2..2 and arrow text
        ld a,(relx+1)
        rlca
        and 1
        ld c,a                     ; 1 = target to the left
        ld hl,(relz)
        bit 7,h
        jr nz,.hard
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ex de,hl
        ld hl,(relx)
        call absh
        or a
        sbc hl,de
        jr c,.ahead
        ld hl,(relz)
        sra h
        rr l
        ex de,hl
        ld hl,(relx)
        call absh
        or a
        sbc hl,de
        jr c,.soft
.hard:  ld a,2
        jr .cls
.soft:  ld a,1
        jr .cls
.ahead: xor a
.cls:   ld b,a
        bit 0,c
        jr z,.r
        neg
.r:     ld (turnlv),a
        ld a,b
        add a,a
        add a,c
        add a,a
        ld e,a
        ld d,0
        ld hl,arrows
        add hl,de
        ld (arrowp),hl
        ret

arrows: db ch_up,ch_sp,ch_up,ch_sp
        db ch_sp,ch_gt,ch_lt,ch_sp
        db ch_gt,ch_gt,ch_lt,ch_lt

; demo autopilot: chase the waypoints around the harbour
autopilot:
        ld hl,(wpp)
        ld a,h
        or l
        jr nz,.h
        ld hl,demowps
        jr .ld
.h:     ld hl,(gdm)
        ld de,450
        or a
        sbc hl,de
        jr nc,.go
        ld hl,(wpp)
        ld de,6
        add hl,de
        ld a,(hl)
        inc hl
        and (hl)
        dec hl
        inc a
        jr nz,.ld
        ld hl,demowps
.ld:    ld (wpp),hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (tgx),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (tgz),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (tgalt),de
        ld hl,$ffff
        ld (gdm),hl
.go:    ld a,(turnlv)
        ld hl,0
        or a
        jr z,.rs
        ld hl,1820
        bit 7,a
        jr z,.rp
        neg
        ld hl,-1820
.rp:    cp 2
        jr nz,.rs
        add hl,hl
        ld de,910
        bit 7,h
        jr z,.rq
        ld de,-910
.rq:    add hl,de
.rs:    ld (aprol),hl
        ld hl,(tgalt)
        ld de,(py+2)
        or a
        sbc hl,de
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,1500
        call clamp
        ld (appit),hl
        ret

; ---------------------------------------------------------------- views
viewkeys:
        ld a,(ctrl2e)
        ld c,a
        bit 5,c
        jr z,.v
        ld a,(view)
        cp 4
        jr nz,.m1
        ld a,(mapz)
        xor 1
        ld (mapz),a
        jr .mm
.m1:    ld a,4
        ld (view),a
.mm:    ld a,(mapz)
        or a
        ld hl,msg_map1
        jr z,.ms
        ld hl,msg_map2
.ms:    jp setmsg
.v:     ld b,0
        ld hl,msg_fwd
        bit 1,c
        jr nz,.set
        inc b
        ld hl,msg_left
        bit 2,c
        jr nz,.set
        inc b
        ld hl,msg_right
        bit 3,c
        jr nz,.set
        inc b
        ld hl,msg_rear
        bit 4,c
        ret z
.set:   ld a,b
        ld (view),a
        jp setmsg

; camera for the chosen view (after physics has set the aircraft's trig)
setview:
        call setcam
        ld a,(view)
        or a
        ret z
        cp 4
        jr z,.map
        ld hl,(yaw3+1)
        ld de,(pitch3+1)
        ld bc,(roll3+1)
        cp 1
        jr nz,.r
        ld a,h
        sub $40
        ld h,a
        ld (cyaw),hl
        ld (cpitch),bc
        ex de,hl
        call neghl
        ld (croll),hl
        jp calctrig
.r:     cp 2
        jr nz,.b
        ld a,h
        add a,$40
        ld h,a
        ld (cyaw),hl
        ld (croll),de
        ld h,b
        ld l,c
        call neghl
        ld (cpitch),hl
        jp calctrig
.b:     ld a,h
        add a,$80
        ld h,a
        ld (cyaw),hl
        ex de,hl
        call neghl
        ld (cpitch),hl
        ld h,b
        ld l,c
        call neghl
        ld (croll),hl
        jp calctrig
.map:   ld hl,(yaw3+1)
        ld (cyaw),hl
        ld hl,-16384
        ld (cpitch),hl
        ld hl,0
        ld (croll),hl
        call calctrig
        ld hl,1500
        ld a,(mapz)
        or a
        jr z,.z
        ld hl,5000
.z:     ld (cyi),hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (cy16),hl
        ret

; aircraft symbol in the middle of the map
drawarrow:
        ld a,$ff
        ld (linecol),a
        ld hl,arrowl
        ld b,4
.l:     push bc
        ld a,(hl)
        inc hl
        ld (lx0),a
        ld a,(hl)
        inc hl
        ld (ly0),a
        ld a,(hl)
        inc hl
        ld (lx1),a
        ld a,(hl)
        inc hl
        ld (ly1),a
        push hl
        call line2d
        pop hl
        pop bc
        djnz .l
        ret
arrowl: db 96,28,96,36, 92,32,100,32, 93,31,96,28, 99,31,96,28

; goal marker (gates)
drawgoal:
        ld a,(demo)
        or a
        ret nz
        ld a,(mdone)
        or a
        ret nz
        ld a,(goalcnt)
        or a
        ret z
        ld ix,(goalp)
        ld l,(ix+11)
        ld h,(ix+12)
        ld a,h
        or l
        ret z
        ld (goalobj+4),hl
        ld a,(ix+13)
        ld (goalobj+6),a
        ld a,(ix+14)
        ld (goalobj+9),a
        ld hl,(tgx)
        ld (goalobj),hl
        ld hl,(tgz)
        ld (goalobj+2),hl
        ld a,62
        ld (goalobj+7),a
        ld a,5
        ld (goalobj+8),a
        ld ix,goalobj
        jp drawobj

; ---------------------------------------------------------------- HUD overlay in the view
overlay:
        call settrn
        ld a,(ovink)
        ld (oc_ink),a
        ld a,(demo)
        or a
        jr z,.nd
        ld a,(ftick)
        and $20
        jp z,.x
        ld hl,txt_demo
        ld de,buf+40*32
        call ptextc
        jr .x
.nd:    ld a,(goalcnt)
        or a
        jr z,.tm
        ld a,(mdone)
        or a
        jr nz,.tm
        ld de,buf+1*32+1
        ld a,ch_g
        call chout
        ld a,(goalidx)
        inc a
        call chout
        ld a,ch_slash
        call chout
        ld a,(goalcnt)
        call chout
        inc de
        ld hl,(arrowp)
        ld a,(hl)
        inc hl
        call chout
        ld a,(hl)
        call chout
        inc de
        ld hl,(gdist)
        call pdec1
        ld a,ch_k
        call chout
.tm:    ld a,(goalcnt)
        or a
        jr z,.fu
        ld de,buf+1*32+27
        ld hl,(msec)
        call ptime
.fu:    ld hl,(fuelmax)
        ld a,h
        or l
        jr z,.x
        ld de,buf+7*32+1
        ld hl,txt_fuel
        call ptext
        ld de,(fuel)
        ld bc,100
        call umul16
        ld bc,(fuelmax)
        call udiv32
        ld b,3
        ld de,buf+7*32+6
        call prnum
        ld a,ch_pct
        call chout
.x:     jp setopq


; HL tenths -> "NN.N"
pdec1:  push de
        ld de,0
        ld bc,10
        push hl
        call udiv32
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        add hl,hl
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld a,l
        ld (tmpb),a
        ld h,b
        ld l,c
        pop de
        ld b,2
        call prnum
        ld a,ch_dot
        call chout
        ld a,(tmpb)
        jp chout

; HL seconds -> "MM:SS" at DE
ptime:  push de
        push hl
        ld de,0
        ld bc,60
        call udiv32
        ld de,99
        call clamp
        ld b,h
        ld c,l
        ld (tmpw),hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,bc
        add hl,hl
        add hl,hl
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld a,l
        ld (tmpb),a
        pop de
        ld hl,(tmpw)
        ld b,2
        call prnum
        ld a,ch_colon
        call chout
        ld a,(tmpb)
        ld l,a
        ld h,0
        ld b,2
        jp prnum

; ---------------------------------------------------------------- panel
pl1     equ vram+50*32
pl2     equ vram+57*32

panelinit:
        call setopq
        ld hl,vram+48*32
        ld a,$55
        call fill32
        ld b,15
        ld a,$aa
.l:     call fill32
        djnz .l
        ld a,$aa
        ld (pc_pap),a
        xor a
        ld (pc_ink),a
        ld hl,lbl_spd
        ld de,pl1
        call ptext
        ld hl,lbl_alt
        ld de,pl1+9
        call ptext
        ld hl,lbl_hdg
        ld de,pl1+20
        call ptext
        ld hl,lbl_thr
        ld a,(heli)
        or a
        jr z,.t
        ld hl,lbl_col
.t:     ld de,pl2
        call ptext
        ld hl,lbl_vs
        ld de,pl2+9
        jp ptext

lbl_spd: text "SPD"
lbl_alt: text "ALT"
lbl_hdg: text "HDG"
lbl_thr: text "THR"
lbl_col: text "COL"
lbl_vs:  text "VS"
st_gnd:  text "GROUND "
st_brk:  text "BRAKES "
st_fly:  text "       "
st_stl:  text "STALL  "
st_crs:  text "CRASH  "
st_nof:  text "NO FUEL"
st_hov:  text "HOVER  "
st_dne:  text "DONE!  "

drawpanel:
        call setopq
        ld a,$aa
        ld (pc_pap),a
        ld a,$55
        ld (pc_ink),a
        ld de,(spd+1)
        ld bc,498
        call umul16
        ex de,hl
        ld b,3
        ld de,pl1+4
        call prnum
        ld de,(py+1)
        ld bc,840
        call umul16
        push de
        ld a,(py+3)
        or a
        jp p,.ap
        xor a
.ap:    ld e,a
        ld d,0
        ld bc,840
        call umul16
        pop de
        add hl,de
        ld b,5
        ld de,pl1+13
        call prnum
        ld de,(yaw3+1)
        ld bc,360
        call umul16
        ex de,hl
        ld b,3
        ld de,pl1+24
        call prnum
        ld a,(thr)
        ld b,100
        call umul8
        ld l,h
        ld h,0
        ld b,3
        ld de,pl2+4
        call prnum
        ld hl,(vs88)
        ld a,ch_plus
        bit 7,h
        jr z,.vp
        call neghl
        ld a,ch_minus
.vp:    ld de,pl2+12
        call chout
        ex de,hl
        ld bc,50394
        call umul16
        ex de,hl
        ld b,4
        ld de,pl2+13
        call prnum
        ld hl,st_dne
        ld a,(mdone)
        or a
        jr nz,.st
        ld hl,st_crs
        ld a,(crash)
        or a
        jr nz,.red
        ld hl,st_nof
        ld a,(nofuel)
        or a
        jr nz,.red
        ld hl,st_stl
        ld a,(stall)
        or a
        jr nz,.red
        ld a,(ongnd)
        or a
        jr nz,.gd
        ld hl,st_fly
        ld a,(heli)
        or a
        jr z,.st
        ld a,(spd+2)
        cp 3
        jr nc,.st
        ld hl,st_hov
        jr .st
.gd:    ld hl,st_gnd
        ld a,(ctrl)
        bit 6,a
        jr z,.st
        ld hl,st_brk
        jr .st
.red:   ld a,$ff
        ld (pc_ink),a
.st:    ld de,pl2+19
        jp ptext

; ---------------------------------------------------------------- pause
dopause:
        ld a,(engdly)
        push af
        xor a
        ld (engdly),a
        call setopq
        ld hl,vram+9*32+3
        ld b,32
.r:     push bc
        push hl
        ld b,26
        ld a,$aa
.c:     ld (hl),a
        inc hl
        djnz .c
        pop hl
        ld de,32
        add hl,de
        pop bc
        djnz .r
        ld a,$aa
        ld (pc_pap),a
        ld hl,pausetab
.t:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.w0
        ld a,(hl)
        inc hl
        ld (pc_ink),a
        call ptext
        jr .t
.w0:    call keyrel
.w:     call waitf
        call kedge
        bit 6,a
        jr nz,.res
        bit 5,a
        jr nz,.quit
        ld a,($68fe)
        bit 5,a
        jr nz,.w
        call startmis
        jr .res
.quit:  ld a,1
        ld (quitf),a
.res:   pop af
        ld (engdly),a
        call keyrel
        ld a,(fcount)
        ld (flast),a
        xor a
        ld (ctrl2),a
        ld (ctrl2e),a
        ret

pausetab:
        dw vram+11*32+13
        db $ff
        text "PAUSED"
        dw vram+19*32+5
        db $55
        text "P     CARRY ON"
        dw vram+25*32+5
        db $55
        text "R     RESTART FLIGHT"
        dw vram+31*32+5
        db $55
        text "RET   QUIT TO MENU"
        dw vram+35*32+5
        db $00
        text "1-4 VIEWS  5 MAP"
        dw 0

; ---------------------------------------------------------------- messages + sound
; message record: time (fields), column, ink (1 = locale ink), text
msg_go:    db 150,11,1
        text "GOOD LUCK!"
msg_free:  db 150,10,1
        text "FREE FLIGHT"
msg_demo:  db 1,0,1
        db 255
msg_land:  db 100,11,1
        text "TOUCHDOWN"
msg_crash: db 150,12,$ff
        text "CRASHED!"
msg_hard:  db 150,9,$ff
        text "HARD LANDING!"
msg_ditch: db 150,12,$ff
        text "DITCHED!"
msg_nofuel: db 150,10,$ff
        text "OUT OF FUEL!"
msg_empty: db 150,9,$ff
        text "FUEL EXHAUSTED"
msg_retry: db 120,6,1
        text "TRY AGAIN FROM HERE"
msg_gate:  db 100,9,1
        text "CHECKPOINT OK!"
msg_done:  db 200,7,$ff
        text "MISSION COMPLETE!"
msg_fwd:   db 80,10,1
        text "FORWARD VIEW"
msg_left:  db 80,11,1
        text "LEFT VIEW"
msg_right: db 80,11,1
        text "RIGHT VIEW"
msg_rear:  db 80,11,1
        text "REAR VIEW"
msg_map1:  db 80,10,1
        text "MAP  1.5 KM"
msg_map2:  db 80,10,1
        text "MAP  5 KM"
txt_stall: text "STALL"
txt_demo:  text "DEMO - PRESS SPACE"
txt_fuel:  text "FUEL"

setmsg: ld (msgptr),hl
        ld a,(hl)
        ld (msgtim),a
        ret

drawmsg:
        call settrn
        ld a,(stall)
        or a
        jr z,.m1
        ld a,$ff
        ld (oc_ink),a
        ld hl,txt_stall
        ld de,buf+36*32+13
        call ptext
        ld b,40
        ld c,10
        call beep
.m1:    ld a,(msgtim)
        or a
        jr z,.x
        ld b,a
        ld a,(nf)
        ld c,a
        ld a,b
        sub c
        jr nc,.m2
        xor a
.m2:    ld (msgtim),a
        ld hl,(msgptr)
        inc hl
        ld e,(hl)
        inc hl
        ld d,0
        ld a,(hl)
        inc hl
        cp 1
        jr nz,.ink
        ld a,(ovink)
.ink:   ld (oc_ink),a
        push hl
        ld hl,buf+14*32
        add hl,de
        ex de,hl
        pop hl
        call ptext
.x:     jp setopq

; B = half-period delay, C = half-cycles
beep:   ld a,(latchv)
        or $01
.l:     ld (latch),a
        ld e,b
.d:     dec e
        jr nz,.d
        xor $21
        dec c
        jr nz,.l
        ld a,(latchv)
        ld (latch),a
        ret

crashsnd:
        ld hl,$a5c3
        ld bc,5000
.l:     add hl,hl
        jr nc,.n
        ld a,l
        xor $2d
        ld l,a
.n:     ld d,$01
        bit 3,h
        jr z,.o
        ld d,$20
.o:     ld a,(latchv)
        or d
        ld (latch),a
        ld a,b
        or $08
.dl:    dec a
        jr nz,.dl
        dec bc
        ld a,b
        or c
        jr nz,.l
        ld a,(latchv)
        ld (latch),a
        ret
