; ---------------------------------------------------------------
; DROPBEAR 3D - a first-person bear hunt for the VZ300
; mode 1 (128x64, 4 colours), 32-column textured raycaster
; VIBED BY BPM 2026
; Tables, textures, sprites, the world and text come from build.py
; ---------------------------------------------------------------
TURN:   equ 10
MARG:   equ 80
SIDE:   equ 40
EMARG:  equ 72
NOBJ:   equ 32
MUSP:   equ 14

        org CODEORG
start:  di
        ld sp,stacktop
        call joyinit
main:   call attract                ; title, music, gallery, demo - until fire is pressed
        ld hl,PG_INTRO
        call textpage
        call newgame
gloop:  call gameframe
        ld a,(hp)
        or a
        jr z,dead
        ld a,(leveldone)
        or a
        jr z,gloop
        call jingle_up
        call cls
        ld hl,PG_WIN
        call showpage
        ld a,(opals)
        ld de,WINNUM
        call print2
        call waitfire
        jp main

; one frame of play (the attract demo uses this too)
gameframe:
        call getinput
        ld a,(mapkey)
        or a
        jr z,gl1
        call areaflag
        bit 0,(hl)
        jr z,gl0
        call drawmap
        call blit
        xor a
        ld (fcnt),a
        ret
gl0:    ld a,(msgt)
        or a
        jr nz,gl1
        ld hl,MSG_NOMAP
        call setmsg
gl1:    call turnmove
        ld a,(goarea)
        or a
        call nz,changearea
        call fire
        call render
        call objects
        call drawvis
        call parts
        call drawgun
        call blit
        call hud
        jp timers

dead:   call jingle_down
        ld hl,PG_DEAD
        call textpage
        ld a,100
        ld (hp),a
        ld hl,OBJ+7             ; give the player a breather
        ld b,NOBJ
        ld de,8
dd1:    ld (hl),150
        add hl,de
        djnz dd1
        call spawn
        call cls
        call hudinit
        jp gloop

; ---------------- screens ---------------------------------------
textpage:
        push hl
        call cls
        pop hl
        call showpage
        jp waitfire

setlatch:
        ld a,(latch)
        and $21
        ld b,a
        ld a,(latchbase)
        or b
        ld (latch),a
        ld ($6800),a
        ret

cls:    ld hl,$7000
        ld de,$7001
        ld bc,$07FF
        ld (hl),$AA
        ldir
        ret

showpage:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        ret z
        call print
        jr showpage

; HL -> glyph string ($FF ends), DE -> screen byte
print:  ld a,(hl)
        inc hl
        cp $FF
        ret z
        push hl
        push de
        ld l,a
        ld h,0
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        ld bc,FONT
        add hl,bc
        ld b,6
pr1:    ld a,(hl)
        ld (de),a
        inc hl
        ld a,e
        add a,32
        ld e,a
        jr nc,pr2
        inc d
pr2:    djnz pr1
        pop de
        pop hl
        inc de
        jr print

; A = 0..99, DE -> screen
print2: ld b,27
p2a:    cp 10
        jr c,p2b
        sub 10
        inc b
        jr p2a
p2b:    add a,27
        ld (numbuf+1),a
        ld a,b
        ld (numbuf),a
        ld hl,numbuf
        jr print

waitfire:
wf1:    call getinput
        ld a,(inp)
        bit 6,a
        jr nz,wf1
        ld a,6
        call pause
wf2:    call getinput
        ld a,(inp)
        bit 6,a
        jr z,wf2
        ret

; A = units of about 4ms
pause:  or a
        ret z
        ld b,a
pa0:    ld a,($68EF)            ; remember a quick tap of SPACE
        bit 4,a
        jr nz,pa2
        ld a,1
        ld (tap),a
pa2:    ld hl,540
pa1:    dec hl
        ld a,h
        or l
        jr nz,pa1
        djnz pa0
        ret

; HL = addr, B = rows, C = width, A = value
fillrect:
        ld e,a
fr1:    push hl
        push bc
        ld b,c
fr2:    ld (hl),e
        inc hl
        djnz fr2
        pop bc
        pop hl
        ld a,l
        add a,32
        ld l,a
        jr nc,fr3
        inc h
fr3:    djnz fr1
        ret

; HL = src, DE = dst, A = rows, C = width
drawbmp:
        push af
        push de
        ld b,0
        push bc
        ldir
        pop bc
        pop de
        ld a,e
        add a,32
        ld e,a
        jr nc,db1
        inc d
db1:    pop af
        dec a
        jr nz,drawbmp
        ret

; ---------------- attract sequence ------------------------------
; returns when fire is pressed: title + music, the gallery, then a demo
attract:
        call titlescreen
        ret c
        call gallery
        ret c
        call demo
        ret c
        jr attract

titlescreen:
        ld a,1
        out ($37),a
        ld a,$08
        ld (latchbase),a
        call setlatch
        call cls
        ld hl,LOGO2             ; the logo lives in the high bank: copy it straight to the screen
        ld de,$7000
        ld bc,LOGOLEN
        call HICOPY
        ld hl,PG_TITLE
        call showpage
        ld hl,MUSIC
        ld de,ACTTEX
        ld bc,MUSLEN
        call HICOPY
        call playmus
        ret c
        ld b,250                ; let the last chord ring in the silence
tl1:    push bc
        ld a,1
        call pause
        call getinput
        pop bc
        ld a,(inp)
        bit 6,a
        scf
        ret nz
        djnz tl1
        or a
        ret

; three-channel music: each channel is a square wave from its own counter, and the
; speaker is handed to each channel in turn many thousand times a second
; row: period1, toggle1, period2, toggle2, period3, toggle3, length (16 bit, $FFxx ends)
playmus:
        ld hl,ACTTEX
qpm0:    ld a,(hl)
        ld (qmp1+1),a
        inc hl
        ld a,(hl)
        ld (qmx1+1),a
        inc hl
        ld a,(hl)
        ld (qmp2+1),a
        inc hl
        ld a,(hl)
        ld (qmx2+1),a
        inc hl
        ld a,(hl)
        ld (qmp3+1),a
        inc hl
        ld a,(hl)
        ld (qmx3+1),a
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,b
        cp $FF
        ret z
        push hl
        push bc
        call getinput
        pop bc
        ld a,(inp)
        bit 6,a
        jr z,qpm1
        pop hl
        scf
        ret
qpm1:    push bc
        exx
        pop bc
        exx
        ld a,(latch)
        and $DE
        or 1
        ld d,a
        ld h,a
        ld l,a
        ld b,1
        ld c,1
        ld e,1
qmloop:  dec b
        jr nz,qml1
qmp1:    ld b,0
        ld a,d
qmx1:    xor $21
        ld d,a
qml1:    ld a,d
        ld ($6800),a
        dec c
        jr nz,qml2
qmp2:    ld c,0
        ld a,h
qmx2:    xor $21
        ld h,a
qml2:    ld a,h
        ld ($6800),a
        dec e
        jr nz,qml3
qmp3:    ld e,0
        ld a,l
qmx3:    xor $21
        ld l,a
qml3:    ld a,l
        ld ($6800),a
        exx
        dec bc
        ld a,b
        or c
        exx
        jp nz,qmloop
        pop hl
        jp qpm0

; the locals introduce themselves
gallery:
        ld hl,GALL
        ld de,ACTTEX
        ld bc,GALLLEN
        call HICOPY
        ld hl,ACTTEX
ga0:    ld (gptr),hl
        ld a,(hl)
        inc hl
        or (hl)
        ret z
        ld hl,(gptr)
        ld de,10
        add hl,de
        ld a,(hl)
        ld (latchbase),a
        call setlatch
        call cls
        ld hl,(gptr)
        ld de,6
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call showpage
        xor a
        ld (gframe),a
        call gdraw
        ld hl,(gptr)            ; a little ta-da
        ld de,11
        add hl,de
        ld b,3
gji:    push bc
        ld e,(hl)
        inc hl
        ld d,0
        ld b,(hl)
        inc hl
        push hl
        call beep
        ld a,8
        call pause
        pop hl
        pop bc
        djnz gji
        ld b,7                  ; then show off for a couple of seconds
gw1:    push bc
        ld a,90
        call pause
        call getinput
        pop bc
        ld a,(inp)
        bit 6,a
        scf
        ret nz
        ld a,(gframe)
        xor 1
        ld (gframe),a
        push bc
        call gdraw
        pop bc
        djnz gw1
        ld hl,(gptr)
        ld de,17
        add hl,de
        jr ga0
; draw this entry's sprite in the frame gframe
gdraw:  ld a,1
        out ($37),a
        ld hl,(gptr)
        ld de,4
        add hl,de
        ld a,(hl)               ; backdrop colour for this one
        ld hl,$7000
        ld b,46
        ld c,32
        call fillrect
        ld hl,(gptr)
        ld a,(gframe)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        ld hl,(gptr)
        ld de,8
        add hl,de
        ld a,(hl)
        ld (s_top),a
        inc hl
        ld a,(hl)
        ld (s_left),a
        ld a,255
        ld (s_z),a
        ld hl,$7000
        ld (s_base),hl
        pop hl
        call drawspr
        ld hl,BUF
        ld (s_base),hl
        ld a,1
        out ($37),a
        ret

; the demo: the autopilot plays a different area each time round
demo:   ld a,(dcycle)
        ld (dsa),a
        inc a
        cp NAREA
        jr c,dm0
        xor a
dm0:    ld (dcycle),a
        ld a,(dsa)
        add a,a
        ld e,a
        ld d,0
        ld hl,DEMOTAB
        add hl,de
        ld a,(hl)
        ld (dsc),a
        inc hl
        ld a,(hl)
        ld (dsang),a
        call newgame2
        ld hl,OBJ               ; in the demo, everything here is awake and coming for you
        ld b,NOBJ
dmw:    ld a,(hl)
        or a
        jr z,dmw1
        cp NENEMY+1
        jr nc,dmw1
        push hl
        ld de,6
        add hl,de
        set 7,(hl)
        pop hl
dmw1:   ld de,8
        add hl,de
        djnz dmw
        ld a,1
        ld (demo_on),a
        xor a
        ld (dquit),a
        ld (aturn),a
        ld hl,MSG_DEMO
        call setmsg
        ld hl,DEMOLEN
        ld (dtime),hl
dml:    call gameframe
        ld a,(msgt)             ; keep the DEMO banner up
        or a
        jr nz,dml1
        ld hl,MSG_DEMO
        call setmsg
dml1:   ld a,(dquit)
        or a
        jr nz,dmq
        ld a,(hp)
        or a
        jr z,dme
        ld a,(leveldone)
        or a
        jr nz,dme
        ld hl,(dtime)
        dec hl
        ld (dtime),hl
        ld a,h
        or l
        jr nz,dml
dme:    xor a
        ld (demo_on),a
        ret
dmq:    xor a
        ld (demo_on),a
        scf
        ret

; steer for the demo: face the nearest creature in view and shoot, otherwise wander
autopilot:
        ld c,0
        ld a,(aimz)
        or a
        jr z,ap3
        ld a,(aimcol)
        cp 14
        jr nc,ap1
        set 2,c
        jr ap2
ap1:    cp 19
        jr c,ap2
        set 3,c
ap2:    ld hl,(target)
        ld a,h
        or l
        ret z
        set 6,c
        ret
ap3:    ld a,(aturn)
        or a
        jr z,ap4
        xor a
        ld (awalk),a
        ld a,(aturn)
        dec a
        ld (aturn),a
        ld a,(adir)
        ld c,a
        ret
ap4:    ld a,(awalk)            ; tried to walk last time but didn't move? turn away
        ld b,a
        ld hl,(px)
        ld de,(lastpx)
        ld (lastpx),hl
        or a
        sbc hl,de
        ld a,h
        or l
        ld hl,(py)
        ld de,(lastpy)
        ld (lastpy),hl
        jr nz,ap5
        or a
        sbc hl,de
        ld a,h
        or l
        jr nz,ap5
        or b
        jr nz,ap8
ap5:    ld a,(ZBUF+16)          ; wall close ahead (last frame's depth buffer)? turn to the open side
        cp 43
        jr c,ap5w
        call ahead              ; unless it's a door or a way out: walk into those
        cp 3
        jr z,ap5w
        cp 4
        jr nz,ap9
ap5w:   set 0,c
        ld a,1
        ld (awalk),a
        call rnd
        and 127
        jr z,ap8                ; now and then, wander off somewhere new
        ld a,(ZBUF+4)           ; drift towards the more open side
        ld b,a
        ld a,(ZBUF+28)
        sub b
        jr nc,ap6
        neg
        cp 8
        ret c
        set 3,c
        ret
ap6:    cp 8
        ret c
        set 2,c
        ret
; the map cell a step and a quarter in front of us
ahead:  push bc
        ld hl,(vx)
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,(px)
        add hl,de
        ld b,h
        ld hl,(vy)
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,(py)
        add hl,de
        ld c,h
        call mapat
        and $7F
        pop bc
        ret
ap8:    call rnd
        and 4
        jr nz,ap7
        ld a,8
        jr ap7
ap9:    ld a,(ZBUF+4)
        ld b,a
        ld a,(ZBUF+28)
        cp b
        ld a,8
        jr c,ap7
        ld a,4
ap7:    ld (adir),a
        xor a
        ld (awalk),a
        ld a,(adir)
        ld c,a
        call rnd
        and 7
        add a,6
        ld (aturn),a
        ret


; ---------------- the world -------------------------------------
; area record: theme, flags, name (16 + $FF), exit count, exits (cell, to area,
; to cell, facing), object count, objects (type, x, y), map (two cells a byte)
areaptr:
        ld a,(area)
        add a,a
        ld e,a
        ld d,0
        ld hl,ATAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

areaflag:
        ld a,(area)
        ld e,a
        ld d,0
        ld hl,aflags
        add hl,de
        ret

; the saved state of an area: 256 map bytes then 128 object bytes
liveptr:
        ld a,(area)
        add a,a
        ld h,a
        ld l,0
        ld de,LIVE
        add hl,de
        ret
; the map sits in the half of RAM that the high bank replaces, so it goes via a bounce buffer
savearea:
        ld hl,MAP
        ld de,ACTTEX
        ld bc,256
        ldir
        call liveptr
        ex de,hl
        push de
        ld hl,ACTTEX
        ld bc,256
        call HICOPY
        pop de
        inc d
        ld hl,OBJ
        ld bc,256
        jp HICOPY
getarea:
        call liveptr
        push hl
        ld de,ACTTEX
        ld bc,256
        call HICOPY
        ld hl,ACTTEX
        ld de,MAP
        ld bc,256
        ldir
        pop hl
        inc h
        ld de,OBJ
        ld bc,256
        jp HICOPY

; A = type -> HL = its entry in TYPES
typeptr:
        dec a
        ld l,a
        ld h,0
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        add hl,hl
        add hl,de
        ld de,TYPES
        add hl,de
        ret

; unpack the fresh copy of one area into MAP and OBJ
expand: call areaptr
        inc hl
        ld b,(hl)
        push hl
        call areaflag
        ld (hl),b
        pop hl
        ld de,18
        add hl,de
        ld a,(hl)
        inc hl
        add a,a
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        push hl
        ld hl,OBJ
        ld b,NOBJ*8
ex0:    ld (hl),0
        inc hl
        djnz ex0
        pop hl
        or a
        jr z,ex4
        ld b,a
        ld de,OBJ
ex2:    ld a,(hl)
        ld (otype),a
        ld (de),a
        inc de
        inc hl
        ld a,128
        ld (de),a
        inc de
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        ld a,128
        ld (de),a
        inc de
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        push hl
        push de
        ld a,(otype)
        call typeptr
        ld de,6
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ld (de),a
        inc de
        inc de
        inc de
        djnz ex2
ex4:    ld de,MAP
        ld b,128
ex5:    ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld (de),a
        inc de
        ld a,(hl)
        and $0F
        ld (de),a
        inc de
        inc hl
        djnz ex5
        jp marksolid

; furniture that blocks: mark its cell solid (bit 7: the rays see through it)
marksolid:
        ld hl,OBJ
        ld b,NOBJ
ms1:    ld a,(hl)
        cp DECOR
        jr c,ms2
        push bc
        push hl
        call typeptr
        ld de,9
        add hl,de
        ld a,(hl)
        pop hl
        push hl
        and $20
        jr z,ms3
        inc hl
        inc hl
        ld b,(hl)
        inc hl
        inc hl
        ld c,(hl)
        call mapat
        set 7,(hl)
ms3:    pop hl
        pop bc
ms2:    ld de,8
        add hl,de
        djnz ms1
        ret

newgame:
        xor a
        ld (dsa),a
        ld a,STARTCELL
        ld (dsc),a
        ld a,STARTANG
        ld (dsang),a
newgame2:
        xor a
        ld (keys),a
        ld (opals),a
        ld (leveldone),a
        ld (goarea),a
        ld (msgt),a
        ld (musict),a
        ld (recht),a
        ld a,40
        ld (ammo),a
        ld a,100
        ld (hp),a
        xor a
ng1:    ld (area),a
        call expand
        call savearea
        ld a,(area)
        inc a
        cp NAREA
        jr nz,ng1
        ld a,(dsa)
        ld (area),a
        ld a,(dsc)
        ld (entrycell),a
        ld a,(dsang)
        ld (entryang),a
        ld hl,GTUNE
        ld (gtptr),hl
        call loadarea
        call spawn
        call cls
        jp hudinit

loadarea:
        call getarea
        call areaptr
        ld a,(hl)
        push hl
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        ld de,THEMES
        add hl,de
        ld de,latchbase
        ld bc,10
        ldir
        call loadtex
        pop hl
        inc hl
        inc hl
        push hl
        ld de,17
        add hl,de
        ld (aexits),hl
        call setlatch
        pop hl
        call setmsg
        ld a,1
        ld (huddirty),a
        ret

spawn:  ld a,(entrycell)
        and $0F
        ld (px+1),a
        ld a,(entrycell)
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld (py+1),a
        ld a,128
        ld (px),a
        ld (py),a
        ld a,(entryang)
        ld (pang+1),a
        xor a
        ld (pang),a
        ld (gunflash),a
        ld (hurtflash),a
        ld (fcnt),a
        ld hl,0
        ld (target),hl
        ld a,25
        ld (firecd),a
        ld a,2
        ld (steps),a
        ld (lastf),a
clrparts:
        ld hl,PART+5
        ld b,32
        ld de,6
cp1:    ld (hl),0
        add hl,de
        djnz cp1
        ret

; copy this area's four wall textures from the library in the high bank
loadtex:
        ld hl,tlib
        ld de,ACTTEX
        ld b,4
lt1:    push bc
        push hl
        push de
        ld h,(hl)
        ld l,0
        ld bc,256
        call HICOPY
        pop de
        inc d
        pop hl
        inc hl
        pop bc
        djnz lt1
        ret

changearea:
        xor a
        ld (goarea),a
        call savearea
        ld a,(newarea)
        ld (area),a
        call loadarea
        call spawn
        ld e,160
        ld c,-8
        ld a,12
        jp sweep

hudinit:
        ld hl,$7600
        ld b,32
hi1:    ld (hl),$FF
        inc hl
        djnz hi1
        ld hl,PG_HUD
        call showpage
        ld a,1
        ld (huddirty),a
        ret

; ---------------- input -----------------------------------------
joyinit:
        xor a
        ld (joyon),a
        ld b,0                  ; only trust the joystick if it reads idle, steadily
ji1:    in a,($2C)
        and $1F
        cp $1F
        ret nz
        djnz ji1
        ld a,1
        ld (joyon),a
        ret

; inp: 0 fwd, 1 back, 2 left, 3 right, 4 strafe left, 5 strafe right, 6 fire
getinput:
        ld c,0
        ld a,($68FE)            ; R Q E - W T
        bit 1,a
        jr nz,gi1
        set 0,c
gi1:    bit 4,a
        jr nz,gi2
        set 4,c
gi2:    bit 3,a
        jr nz,gi3
        set 5,c
gi3:    ld a,($68FD)            ; F A D CTRL S G
        bit 1,a
        jr nz,gi4
        set 1,c
gi4:    bit 4,a
        jr nz,gi5
        set 2,c
gi5:    bit 3,a
        jr nz,gi6
        set 3,c
gi6:    ld a,($68EF)            ; M SPACE , - . N
        bit 4,a
        jr nz,gi7
        set 6,c
gi7:    cpl
        and $20
        ld (mapkey),a
        ld a,(joyon)
        or a
        jr z,gi9
        in a,($2D)
        ld b,a                  ; arm button, bit 4
        in a,($2C)
        bit 0,a
        jr nz,gj1
        set 0,c
gj1:    bit 1,a
        jr nz,gj2
        set 1,c
gj2:    bit 2,a
        jr nz,gj4
        bit 4,b
        jr z,gj3
        set 2,c
        jr gj4
gj3:    set 4,c
gj4:    bit 3,a
        jr nz,gj6
        bit 4,b
        jr z,gj5
        set 3,c
        jr gj6
gj5:    set 5,c
gj6:    in a,($2E)
        bit 4,a
        jr nz,gi9
        set 6,c
gi9:    ld a,c
        ld (inp),a
        ld a,(demo_on)
        or a
        ret z
        ld a,c
        and $40
        ld (dquit),a
        xor a
        ld (mapkey),a
        call autopilot
        ld a,c
        ld (inp),a
        ret

; ---------------- player movement -------------------------------
turnmove:
        ld a,(steps)
        ld b,a
        ld a,(inp)
        ld c,a
        ld hl,(pang)
tm1:    bit 2,c
        jr z,tm2
        ld de,-TURN
        add hl,de
tm2:    bit 3,c
        jr z,tm3
        ld de,TURN
        add hl,de
tm3:    djnz tm1
        ld a,h
        and 3
        ld h,a
        ld (pang),hl
        call getvec
        ld a,(steps)
        ld (stepc),a
tm4:    ld a,(inp)
        bit 0,a
        jr z,tm5
        ld hl,(vx)
        ld (mvx),hl
        ld hl,(vy)
        ld (mvy),hl
        call move
tm5:    ld a,(inp)
        bit 1,a
        jr z,tm6
        ld de,(vx)
        call negde
        ld (mvx),de
        ld de,(vy)
        call negde
        ld (mvy),de
        call move
tm6:    ld a,(inp)
        bit 4,a
        jr z,tm7
        ld hl,(vy)
        ld (mvx),hl
        ld de,(vx)
        call negde
        ld (mvy),de
        call move
tm7:    ld a,(inp)
        bit 5,a
        jr z,tm8
        ld de,(vy)
        call negde
        ld (mvx),de
        ld hl,(vx)
        ld (mvy),hl
        call move
tm8:    ld hl,stepc
        dec (hl)
        jp nz,tm4
        ret

; HL = angle -> A = cos table index (sin index is its complement)
fold:   ld a,h
        rrca
        ld a,l
        ret nc
        cpl
        ret

getvec: ld hl,(pang)
        call fold
        ld l,a
        ld h,ACT_HI
        ld a,(hl)
        ld (pcos),a
        ld a,l
        cpl
        ld l,a
        ld a,(hl)
        ld (psin),a
        ld a,(pang+1)
        inc a
        rrca
        and 1
        ld (pcn),a
        ld a,(pang+1)
        rrca
        and 1
        ld (psn),a
        ld a,(pcos)
        rrca
        rrca
        rrca
        and $1F
        ld e,a
        ld d,0
        ld a,(pcn)
        or a
        call nz,negde
        ld (vx),de
        ld a,(psin)
        rrca
        rrca
        rrca
        and $1F
        ld e,a
        ld d,0
        ld a,(psn)
        or a
        call nz,negde
        ld (vy),de
        ret

negde:  xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
        ret
neghl:  xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret
abshl:  bit 7,h
        ret z
        jr neghl

; B = x cell, C = y cell -> A = map byte, HL -> cell
mapat:  ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        or b
        ld l,a
        ld h,MAP_HI
        ld a,(hl)
        ret

move:   ld hl,(mvx)
        ld a,h
        or l
        jr z,mv_y
        ld de,(px)
        add hl,de
        ld (newp),hl
        ld de,MARG
        ld a,(mvx+1)
        rlca
        jr nc,mx1
        ld de,-MARG
mx1:    add hl,de
        ld b,h
        ld hl,(py)
        ld de,-SIDE
        add hl,de
        ld c,h
        call mapat
        or a
        jr nz,mx_b
        ld hl,(py)
        ld de,SIDE
        add hl,de
        ld c,h
        call mapat
        or a
        jr nz,mx_b
        ld hl,(newp)
        ld (px),hl
        jr mv_y
mx_b:   call bump
mv_y:   ld hl,(mvy)
        ld a,h
        or l
        ret z
        ld de,(py)
        add hl,de
        ld (newp),hl
        ld de,MARG
        ld a,(mvy+1)
        rlca
        jr nc,my1
        ld de,-MARG
my1:    add hl,de
        ld c,h
        ld hl,(px)
        ld de,-SIDE
        add hl,de
        ld b,h
        call mapat
        or a
        jr nz,bump
        ld hl,(px)
        ld de,SIDE
        add hl,de
        ld b,h
        call mapat
        or a
        jr nz,bump
        ld hl,(newp)
        ld (py),hl
        ret

; walked into something: A = cell value, HL -> cell
bump:   cp 3
        jr z,bdoor
        cp 4
        jr z,bexit
        cp 6
        jr z,block
        cp 7
        jr z,bswitch
        cp 10
        ret nz
        ld (hl),0               ; secret wall
        ld hl,MSG_SECRET
        call setmsg
        ld e,60
        ld c,-3
        ld a,16
        jp sweep
bdoor:  ld (hl),0
        ld hl,MSG_DOOR
        call setmsg
bdsnd:  ld e,120
        ld c,20
        ld a,6
        jp sweep
block:  ld a,(keys)
        or a
        jr z,bnokey
        dec a
        ld (keys),a
        ld (hl),0
        ld a,1
        ld (huddirty),a
        ld hl,MSG_UNLOCK
        call setmsg
        jr bdsnd
bnokey: ld a,(msgt)
        or a
        ret nz
        ld hl,MSG_NEEDKEY
        call setmsg
        ld de,230
        ld b,6
        jp beep
bswitch:
        ld (hl),8
        call opengates
        ld hl,MSG_GATE
        call setmsg
        ld e,200
        ld c,-10
        ld a,14
        jp sweep
bexit:  ld c,l
        ld hl,(aexits)
        ld b,(hl)
        inc hl
be1:    ld a,(hl)
        cp c
        jr z,be2
        inc hl
        inc hl
        inc hl
        inc hl
        djnz be1
        ret
be2:    inc hl
        ld a,(hl)
        cp $FF
        jr nz,be3
        ld a,1
        ld (leveldone),a
        ret
be3:    ld (newarea),a
        inc hl
        ld a,(hl)
        ld (entrycell),a
        inc hl
        ld a,(hl)
        ld (entryang),a
        ld a,1
        ld (goarea),a
        ret

opengates:
        ld hl,MAP
        ld b,0
og1:    ld a,(hl)
        cp 9
        jr nz,og2
        ld (hl),0
og2:    inc hl
        djnz og1
        ret

setmsg: ld a,150
        ld (msgt),a
drawmsg:
        ld de,$7000+57*32+16
        jp print

; ---------------- shooting --------------------------------------
fire:   ld a,(inp)
        bit 6,a
        ret z
        ld a,(firecd)
        or a
        ret nz
        ld a,14
        ld (firecd),a
        ld a,(ammo)
        or a
        jr nz,fi1
        ld de,20
        ld b,2
        jp beep
fi1:    dec a
        ld (ammo),a
        ld a,1
        ld (huddirty),a
        ld a,2
        ld (gunflash),a
        ld e,14
        ld c,3
        ld a,14
        call sweep
        ld hl,(target)
        ld a,h
        or l
        ret z
        ld a,(hl)
        or a
        ret z
        ld (otype),a
        push hl
        ld de,6
        add hl,de
        ld a,(hl)
        or $84
        ld (hl),a
        dec hl
        dec (hl)
        pop hl
        jr z,fi2
        ld de,90
        ld b,4
        jp beep
fi2:    ld (hl),0
        ld hl,0
        ld (target),hl
        ld a,(otype)
        call typeptr
        ld de,9
        add hl,de
        ld a,(hl)
        ld (kflg),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (pcols),a
        inc hl
        ld b,(hl)               ; how many pieces
        push de
        ld a,(tcol)             ; centre of the burst, in half pixels
        add a,a
        add a,a
        add a,a
        add a,4
        ld (pcx),a
        ld a,(th)
        srl a
        ld c,a
        ld a,(ttop)
        add a,c
        add a,a
        ld (pcy),a
        ld a,(th)               ; spread to match how big it looks
        ld c,15
        cp 10
        jr c,fi4
        ld c,31
        cp 24
        jr c,fi4
        ld c,63
fi4:    ld a,c
        ld (pspread),a
        call spawnp
        pop hl
        call setmsg
        ld a,(kflg)
        rrca
        jr nc,fi5
        call opengates          ; a boss: whatever it guarded is now open
        ld a,6
        ld (hurtflash),a
        ld b,0
        call noise
        ld b,0
        call noise
        jp jingle_up
fi5:    ld b,150
        jp noise

; B pieces fly out from (pcx, pcy) in colours from pcols
spawnp: ld a,(pnext)
        inc a
        and 31
        ld (pnext),a
        ld l,a
        ld h,0
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,PART
        add hl,de
        ld a,(pspread)
        srl a
        ld e,a
        call rnd
        ld c,a
        ld a,(pspread)
        and c
        sub e
        ld c,a
        ld a,(pcx)
        add a,c
        ld (hl),a
        inc hl
        call rnd
        ld c,a
        ld a,(pspread)
        and c
        sub e
        ld c,a
        ld a,(pcy)
        add a,c
        cp 92
        jr c,sp2
        ld a,88
sp2:    ld (hl),a
        inc hl
        call rnd
        and 31
        sub 16
        ld (hl),a
        inc hl
        call rnd
        and 15
        add a,4
        neg
        ld (hl),a
        inc hl
        call rnd
        and 3
        ld c,a
        inc c
        ld a,(pcols)
sp3:    dec c
        jr z,sp4
        rrca
        rrca
        jr sp3
sp4:    and 3
        ld c,a
        add a,a
        add a,a
        add a,c
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld (hl),a
        inc hl
        call rnd
        and 7
        add a,13
        ld (hl),a
        djnz spawnp
        ret

rnd:    push bc
        ld a,(seed)
        ld b,a
        add a,a
        add a,a
        add a,b
        inc a
        ld (seed),a
        rrca
        rrca
        rrca
        xor b
        pop bc
        ret

; crunchy noise, B = length (0 = long)
noise:  call rnd
        and 1
        jr z,nz2
        ld a,(latch)
        xor $21
        ld (latch),a
        ld ($6800),a
nz2:    ld a,10
nz3:    dec a
        jr nz,nz3
        call poll
        djnz noise
        ret

; move and draw the flying pieces
parts:  ld hl,PART
        ld b,32
pt1:    push bc
        push hl
        ld de,5
        add hl,de
        ld a,(hl)
        or a
        jr z,pt9
        dec (hl)
        pop hl
        push hl
        ld a,(hl)
        inc hl
        inc hl
        ld c,(hl)
        dec hl
        dec hl
        bit 7,c
        jr nz,pt2
        add a,c
        jr c,ptk
        jr pt3
pt2:    add a,c
        jr nc,ptk
pt3:    ld (hl),a
        srl a
        ld (ptx),a
        inc hl
        ld a,(hl)
        inc hl
        inc hl
        ld c,(hl)
        inc (hl)
        dec hl
        dec hl
        bit 7,c
        jr nz,pt4
        add a,c
        cp 92
        jr c,pt5
        inc hl                  ; bounce off the floor
        inc hl
        ld a,c
        srl a
        neg
        ld (hl),a
        dec hl
        ld a,(hl)
        sra a
        ld (hl),a
        dec hl
        ld a,91
        jr pt5
pt4:    add a,c
        jr nc,ptk
pt5:    ld (hl),a
        srl a
        ld c,a
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        ld (ptc),a
        ld a,c
        call plot
        jr pt9
ptk:    pop hl
        push hl
        ld de,5
        add hl,de
        ld (hl),0
pt9:    pop hl
        ld de,6
        add hl,de
        pop bc
        djnz pt1
        ret

; A = row, ptx = pixel x, ptc = colour pattern
plot:   ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(ptx)
        ld b,a
        srl a
        srl a
        or l
        ld l,a
        ld a,h
        add a,BUF_HI
        ld h,a
        ld a,b
        ld c,$F0                ; a chunky 2x2 piece
        bit 1,a
        jr z,pl1
        ld c,$0F
pl1:    ld a,(ptc)
        and c
        ld e,a
        ld a,c
        cpl
        ld c,a
        and (hl)
        or e
        ld (hl),a
        ld a,l
        add a,32
        ld l,a
        jr nc,pl2
        inc h
pl2:    ld a,c
        and (hl)
        or e
        ld (hl),a
        ret

; ---------------- sound -----------------------------------------
; DE = half period count, B = half cycles
beep:   ld a,(latch)
        xor $21
        ld (latch),a
        ld ($6800),a
        ld h,d
        ld l,e
bp2:    dec hl
        ld a,h
        or l
        jr nz,bp2
        call poll
        djnz beep
        ret

; A = half cycles, E = start count, C = signed change per half cycle
sweep:  ld (swc),a
        ld d,0
sw1:    ld b,1
        call beep
        ld a,e
        add a,c
        ld e,a
        ld hl,swc
        dec (hl)
        jr nz,sw1
        ret

jingle_up:
        ld e,200
        ld c,-4
        ld a,40
        call sweep
        ld de,40
        ld b,150
        jp beep
jingle_down:
        ld e,40
        ld c,2
        ld a,100
        jp sweep

; ---------------- field sync counter ----------------------------
poll:   ld a,($6800)
        and $80
        ld hl,lastfs
        cp (hl)
        ret z
        ld (hl),a
        or a
        ret nz
        ld hl,fcnt
        inc (hl)
        ret

; ---------------- per-frame timers ------------------------------
timers: ld a,(fcnt)
        cp 13
        jr c,ti0
        ld a,12
ti0:    ld (lastf),a
        ld b,a
        xor a
        ld (fcnt),a
        ld a,b
        inc a
        srl a
        jr nz,ti1
        inc a
ti1:    cp 7
        jr c,ti2
        ld a,6
ti2:    ld (steps),a
        ld hl,firecd
        call tdec
        ld a,(gunflash)
        or a
        jr z,ti3
        dec a
        ld (gunflash),a
ti3:    ld a,(hurtflash)
        or a
        jr z,ti4
        dec a
        ld (hurtflash),a
ti4:    ld b,a
        ld a,(latch)
        and $21
        ld c,a
        ld a,(latchbase)
        or c
        inc b
        dec b
        jr z,ti5
        xor $10
ti5:    ld (latch),a
        ld ($6800),a
        ld a,(msgt)
        or a
        jr z,ti6
        ld hl,msgt
        call tdec
        ld a,(msgt)
        or a
        jr nz,ti6
        ld hl,MSG_BLANK
        call drawmsg
ti6:    ld a,(lastf)
        ld b,a
        ld a,(animt)
        add a,b
        ld (animt),a
        ld a,(ammo)             ; slow emergency recharge so you are never stuck
        cp 8
        jr nc,ti7
        ld a,(recht)
        add a,b
        ld (recht),a
        cp 60
        jr c,ti7
        xor a
        ld (recht),a
        ld hl,ammo
        inc (hl)
        ld a,1
        ld (huddirty),a
ti7:    ld a,(lastf)
        ld b,a
        ld a,(musict)
        add a,b
        ld (musict),a
        cp MUSP
        ret c
        sub MUSP
        ld (musict),a
ti8:    ld hl,(gtptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        cp $FF
        jr nz,ti9
        ld hl,GTUNE
        ld (gtptr),hl
        jr ti8
ti9:    ld b,(hl)
        inc hl
        ld (gtptr),hl
        ld a,d
        or e
        ret z
        jp beep

tdec:   ld a,(lastf)
        ld b,a
        ld a,(hl)
        sub b
        jr nc,td1
        xor a
td1:    ld (hl),a
        ret

; ---------------- status panel ----------------------------------
hud:    ld a,(huddirty)
        or a
        ret z
        xor a
        ld (huddirty),a
        ld a,(hp)
        ld c,a
        ld hl,$7000+50*32+3
        ld b,10
hb1:    push bc
        ld a,c
        or a
        ld a,$FF
        jr nz,hb2
        ld a,$AA
hb2:    push hl
        ld de,32
        ld b,5
hb3:    ld (hl),a
        add hl,de
        djnz hb3
        pop hl
        inc hl
        pop bc
        ld a,c
        sub 10
        jr nc,hb4
        xor a
hb4:    ld c,a
        djnz hb1
        ld a,(ammo)
        ld de,$7000+50*32+20
        call print2
        ld a,(keys)
        add a,27
        ld (numbuf+1),a
        ld hl,numbuf+1
        ld de,$7000+50*32+28
        call print
        ld a,(opals)
        ld de,$7000+57*32+6
        jp print2

; ---------------- the map screen --------------------------------
drawmap:
        ld hl,MAP
        ld de,BUF
        ld a,16
dmr:    push af
        push de
        ld b,16
dmc:    ld a,(hl)
        and $0F
        inc hl
        push hl
        push bc
        add a,a
        ld c,a
        ld b,0
        ld hl,MAPPAT
        add hl,bc
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        ld (de),a
        inc de
        pop bc
        pop hl
        djnz dmc
        pop bc
        push hl
        ld h,b
        ld l,c
        ld bc,64
        ldir
        pop hl
        pop af
        dec a
        jr nz,dmr
        ld a,(py+1)             ; you are here
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld a,(px+1)
        add a,a
        add a,32
        ld e,a
        ld d,0
        add hl,de
        ld de,BUF
        add hl,de
        ld (hl),$FF
        inc hl
        ld (hl),$FF
        ret

; ---------------- walls -----------------------------------------
render: ld a,1                  ; wall textures live in SRAM bank 1
        out ($37),a
        ld hl,COLS
        ld (colptr),hl
        xor a
        ld (coln),a
rcol:   call poll
        ld hl,(colptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (fish),a
        ld (colptr),hl
        ld hl,(pang)
        add hl,de
        ld a,h
        and 3
        ld h,a
        call castray
        call height
        ld a,(coln)
        add a,ZBUF_LO
        ld l,a
        ld h,ZBUF_HI
        ld a,(hidx)
        ld (hl),a
        ld hl,fogz              ; too far to see in the dark?
        cp (hl)
        ld a,0
        jr nc,rc1
        inc a
rc1:    ld (fogged),a
        or a
        jr nz,rc3
        call texsrc
        ld de,TEXBUF
        ld a,(side)
        or a
        jr z,rc2
        ld b,DARK_HI
        call DARKCOPY
        jr rc3
rc2:    ldi
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
rc3:    ld a,(hidx)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,REC
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (dc1+1),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (dc2+1),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (dc3+1),de
        ld a,(fogged)
        or a
        jr z,rc4
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (dc2+1),de
rc4:    ld a,(coln)
        ld l,a
        ld h,BUF_HI
        ld de,32
        ld a,(skyc)
        ld c,a
dc1:    call 0
        ld a,(fogc)
        ld c,a
dc2:    call 0
        ld a,(groundc)
        ld c,a
dc3:    call 0
        ld hl,coln
        inc (hl)
        ld a,(hl)
        cp 32
        jp nz,rcol
        ret

; HL = ray angle 0..1023
castray:
        ld (rang),hl
        ld a,h
        rrca
        ld a,l
        jr nc,cr1
        cpl
cr1:    ld (cidx),a
        cpl
        ld (sidx),a
        ld a,h
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,QTAB
        add hl,de
        ld a,(hl)
        ld (xop),a
        inc hl
        ld a,(hl)
        ld (yadd+1),a
        inc hl
        ld a,(hl)
        ld (xneg),a
        inc hl
        ld a,(hl)
        ld (yneg),a
        ld a,(cidx)
        ld l,a
        ld h,DXLO_HI
        ld e,(hl)
        inc h
        ld d,(hl)
        ld a,e
        ld (sxlo+1),a
        ld a,d
        ld (sxhi+1),a
        ld a,(xneg)
        or a
        ld a,(px)
        jr nz,cr2
        cpl
cr2:    call mul816
        ld l,h
        ld h,a
        ld (sidex),hl
        ld a,(sidx)
        ld l,a
        ld h,DXLO_HI
        ld e,(hl)
        inc h
        ld d,(hl)
        ld a,e
        ld (sylo+1),a
        ld a,d
        ld (syhi+1),a
        ld a,(yneg)
        or a
        ld a,(py)
        jr nz,cr3
        cpl
cr3:    call mul816
        ld e,h
        ld d,a
        ld a,(py+1)
        add a,a
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,(px+1)
        or c
        ld c,a
        ld b,MAP_HI
        ld hl,(sidex)
dda:    or a
        sbc hl,de
        add hl,de
        jr nc,stepy
xop:    inc c
        ld a,(bc)
        and $7F
        jr nz,hitx
        ld a,l
sxlo:   add a,0
        ld l,a
        ld a,h
sxhi:   adc a,0
        ld h,a
        jp dda
stepy:  ld a,c
yadd:   add a,16
        ld c,a
        ld a,(bc)
        and $7F
        jr nz,hity
        ld a,e
sylo:   add a,0
        ld e,a
        ld a,d
syhi:   adc a,0
        ld d,a
        jp dda
hitx:   ld (cell),a
        xor a
        ld (side),a
        ld (dist),hl
        ret
hity:   ld (cell),a
        ld a,1
        ld (side),a
        ld (dist),de
        ret

height: ld hl,(dist)
        ld a,h
        cp 16
        jr c,ht1
        ld hl,$0FFF
ht1:    srl h
        rr l
        srl h
        rr l
        ld a,h
        add a,LOGD_HI
        ld h,a
        ld a,(hl)
        ld hl,fish
        sub (hl)
        jr nc,ht2
        xor a
ht2:    ld l,a
        ld h,HITAB_HI
        ld a,(hl)
        ld (hidx),a
        ret

; -> HL = texture column for this ray's hit
texsrc: ld a,(side)
        or a
        jr nz,ts_y
        ld a,(sidx)
        ld l,a
        ld h,ACT_HI
        ld a,(hl)
        ld de,(dist)
        call mul816
        ld a,(yneg)
        or a
        ld a,(py)
        jr nz,ts_s
        add a,h
        jr ts_d
ts_y:   ld a,(cidx)
        ld l,a
        ld h,ACT_HI
        ld a,(hl)
        ld de,(dist)
        call mul816
        ld a,(xneg)
        or a
        ld a,(px)
        jr nz,ts_s
        add a,h
        jr ts_d
ts_s:   sub h
ts_d:   and $F0
        ld c,a
        ld a,(cell)
        ld e,a
        ld d,0
        ld hl,TTEX-1
        add hl,de
        ld h,(hl)
        ld l,c
        ret

; ---------------- things: creatures, pickups --------------------
; object: type, x(2), y(2), hp, flags (bit 7 awake, low 4 hurt timer), bite cooldown
objects:
        call mktabs
        xor a
        ld (nvis),a
        ld (tz),a
        ld (aimz),a
        ld hl,0
        ld (target),hl
        ld hl,OBJ
        ld b,NOBJ
ob0:    push bc
        push hl
        ld a,(hl)
        or a
        jp z,ob9
        ld (otype),a
        ld (optr),hl
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
        ld (dx),hl
        call abshl
        ld (adx),hl
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,(py)
        or a
        sbc hl,de
        ld (dy),hl
        call abshl
        ld (ady),hl
        ld a,(otype)
        call typeptr
        ld (otp),hl
        ld de,9
        add hl,de
        ld a,(hl)
        ld (oflg),a
        ld a,(otype)
        cp NENEMY+1
        jr nc,ob2
        call ai
        jr ob3
ob2:    xor a
        ld (oframe),a
        ld (obob),a
        ld a,(otype)
        cp DECOR
        jr nc,ob3
        call pick
        ld hl,(optr)
        ld a,(hl)
        or a
        jr z,ob9
ob3:    call projq
        call poll
ob9:    pop hl
        pop bc
        ld de,8
        add hl,de
        dec b
        jp nz,ob0
        ret

pick:   ld hl,(adx)
        ld a,h
        or a
        ret nz
        ld a,l
        cp $70
        ret nc
        ld hl,(ady)
        ld a,h
        or a
        ret nz
        ld a,l
        cp $70
        ret nc
        ld a,(otype)
        cp T_HEALTH
        jr z,pk_h
        cp T_AMMO
        jr z,pk_a
        cp T_KEY
        jr z,pk_k
        cp T_OPAL
        jr z,pk_o
        call areaflag           ; the map
        set 0,(hl)
        ld hl,MSG_MAP
        jr pk_d
pk_k:   ld hl,keys
        inc (hl)
        ld hl,MSG_KEY
        jr pk_d
pk_o:   ld hl,opals
        inc (hl)
        ld hl,MSG_OPAL
        jr pk_d
pk_h:   ld a,(hp)
        cp 100
        ret nc
        add a,25
        cp 101
        jr c,pk1
        ld a,100
pk1:    ld (hp),a
        ld hl,MSG_HEALTH
        jr pk_d
pk_a:   ld a,(ammo)
        cp 99
        ret nc
        add a,15
        cp 100
        jr c,pk2
        ld a,99
pk2:    ld (ammo),a
        ld hl,MSG_AMMO
pk_d:   call setmsg
        ld hl,(optr)
        ld (hl),0
        ld a,1
        ld (huddirty),a
        ld de,50
        ld b,12
        call beep
        ld de,34
        ld b,18
        jp beep

ai:     ld hl,(optr)
        ld de,6
        add hl,de
        ld a,(hl)
        and $0F
        jr z,ai1
        dec (hl)
ai1:    ld a,(hl)
        ld (oflags),a
        inc hl
        ld a,(lastf)
        ld b,a
        ld a,(hl)
        sub b
        jr nc,ai2
        xor a
ai2:    ld (hl),a
        ld (ocool),a
        xor a
        ld (oframe),a
        ld (obob),a
        ld a,(oflags)
        and $0F
        jr nz,ai3
        ld a,(ocool)
        cp 36
        jr c,ai4
ai3:    ld a,1
        ld (oframe),a
ai4:    ld a,(oflg)
        and 8
        jr z,ai4b
        ld a,(animt)            ; flyers flap
        rrca
        rrca
        and 1
        ld (oframe),a
ai4b:   ld a,(oflags)
        rlca
        jr c,ai4e
        ld a,(adx+1)            ; asleep: wake if you come within three cells
        cp 3
        ret nc
        ld a,(ady+1)
        cp 3
        ret nc
        ld hl,(optr)
        ld de,6
        add hl,de
        set 7,(hl)
        ret
ai4e:
        ld a,(animt)
        rrca
        rrca
        rrca
        and 1
        ld (obob),a
        ld hl,(adx)
        ld a,h
        or a
        jr nz,ai_ch
        ld a,l
        cp $B0
        jr nc,ai_ch
        ld hl,(ady)
        ld a,h
        or a
        jr nz,ai_ch
        ld a,l
        cp $B0
        jr nc,ai_ch
        xor a
        ld (obob),a
        ld a,(ocool)
        or a
        ret nz
        ld hl,(optr)
        ld de,7
        add hl,de
        ld (hl),40
        ld a,1
        ld (huddirty),a
        ld a,(oflg)
        and 8
        jr nz,ai4c
        ld a,1
        ld (oframe),a
ai4c:   ld a,3
        ld (hurtflash),a
        ld hl,(otp)
        ld de,8
        add hl,de
        ld b,(hl)
        ld a,(hp)
        sub b
        jr nc,ai6
        xor a
ai6:    ld (hp),a
        ld hl,MSG_OUCH
        call setmsg
        ld e,150
        ld c,10
        ld a,8
        jp sweep

ai_ch:  ld hl,(otp)
        ld de,7
        add hl,de
        ld c,(hl)               ; speed
        ld a,(oflg)
        bit 1,a
        jr z,ac0a
        ld a,(animt)            ; chargers rush, then catch their breath
        and $40
        ret z
        ld a,(oflg)
ac0a:   bit 2,a
        jr z,ac0
        ld hl,(optr)            ; the angrier, the faster
        ld de,5
        add hl,de
        ld a,32
        sub (hl)
        ld c,a
ac0:    ld a,(steps)
        ld b,a
        xor a
ac1:    add a,c
        djnz ac1
        ld (estep),a
        ld hl,(adx)
        ld a,h
        or a
        jr nz,ac2
        ld a,l
        cp $50
        jr c,ac6
ac2:    ld hl,(optr)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(estep)
        ld c,a
        ld b,0
        ex de,hl
        ld a,(dx+1)
        rlca
        jr c,ac3
        or a
        sbc hl,bc
        ld (newp),hl
        ld de,-EMARG
        jr ac4
ac3:    add hl,bc
        ld (newp),hl
        ld de,EMARG
ac4:    add hl,de
        ld b,h
        ld hl,(optr)
        inc hl
        inc hl
        inc hl
        inc hl
        ld c,(hl)
        call mapat
        or a
        jr nz,ac6
        ld hl,(optr)
        inc hl
        ld de,(newp)
        ld (hl),e
        inc hl
        ld (hl),d
ac6:    ld hl,(ady)
        ld a,h
        or a
        jr nz,ac7
        ld a,l
        cp $50
        ret c
ac7:    ld hl,(optr)
        inc hl
        inc hl
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push bc
        ld a,(estep)
        ld c,a
        ld b,0
        ex de,hl
        ld a,(dy+1)
        rlca
        jr c,ac8
        or a
        sbc hl,bc
        ld (newp),hl
        ld de,-EMARG
        jr ac9
ac8:    add hl,bc
        ld (newp),hl
        ld de,EMARG
ac9:    add hl,de
        pop bc
        ld c,h
        call mapat
        or a
        ret nz
        ld hl,(optr)
        inc hl
        inc hl
        inc hl
        ld de,(newp)
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; DE = signed value, A = 0..255 scale, C bit 0 = negate -> HL = DE*A/256
smul:   ld b,a
        bit 7,d
        jr z,sm1
        call negde
        inc c
sm1:    ld a,b
        call mul816
        ld l,h
        ld h,a
        bit 0,c
        ret z
        jp neghl

; HL / C -> L (16 by 8)
div168: xor a
        ld b,16
dv1:    add hl,hl
        rla
        jr c,dv2
        cp c
        jr c,dv3
dv2:    sub c
        inc l
dv3:    djnz dv1
        ret

; quick tests first, from the cell the thing is in: too far for this area, behind us,
; or off to the side of the view. Only what passes gets placed properly.
projq:  ld a,(cullc)
        ld c,a
        ld a,(otype)
        cp T_HEALTH
        jr c,pq1
        ld a,c                  ; pickups and furniture: not past six cells
        cp 7
        jr c,pq1
        ld c,6
pq1:    ld a,(adx+1)
        cp c
        ret nc
        ld a,(ady+1)
        cp c
        ret nc
        ld hl,(optr)
        inc hl
        inc hl
        ld a,(hl)
        ld (fcx),a
        inc hl
        inc hl
        ld a,(hl)
        ld (fcy),a
        ld hl,TCT
        ld a,(fcx)
        call tget
        push hl
        ld hl,TST
        ld a,(fcy)
        call tget
        pop de
        add hl,de
        ld de,(p1)
        or a
        sbc hl,de
        ld (cdep),hl
        ld de,192
        add hl,de
        bit 7,h
        ret nz
        ld hl,TCT
        ld a,(fcy)
        call tget
        push hl
        ld hl,TST
        ld a,(fcx)
        call tget
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld de,(p2)
        or a
        sbc hl,de
        ld (clat),hl
        call abshl
        ex de,hl
        ld hl,(cdep)
        bit 7,h
        jr z,pq2
        ld hl,0
pq2:    push de
        ld d,h
        ld e,l
        srl d
        rr e
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        add hl,de
        ld de,384
        add hl,de
        pop de
        or a
        sbc hl,de
        ret c
        ld a,(otype)
        cp T_HEALTH
        jp c,proj
        ld hl,(cdep)            ; still things sit at the cell centre: these numbers are exact
        bit 7,h
        ret nz
        ld a,h
        or a
        jr nz,pf1
        ld a,l
        cp $30
        ret c
pf1:    ld (depth),hl
        ld hl,(clat)
        jp pjlat

; per frame: (cell + 0.5) x cos and x sin for every cell, and the player's own terms,
; so things that never move can be placed with a few additions
mktabs: ld a,(pcos)
        ld b,a
        ld a,(pcn)
        ld hl,TCT
        call mkt
        ld a,(psin)
        ld b,a
        ld a,(psn)
        ld hl,TST
        call mkt
        ld de,(px)
        ld a,(pcn)
        ld c,a
        ld a,(pcos)
        call smul
        push hl
        ld de,(py)
        ld a,(psn)
        ld c,a
        ld a,(psin)
        call smul
        pop de
        add hl,de
        ld (p1),hl
        ld de,(py)
        ld a,(pcn)
        ld c,a
        ld a,(pcos)
        call smul
        push hl
        ld de,(px)
        ld a,(psn)
        ld c,a
        ld a,(psin)
        call smul
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld (p2),hl
        ret
; B = step, A = 1 for negative, HL -> 16-entry table
mkt:    push hl
        ld e,b
        ld d,0
        ld l,b
        srl l
        ld h,0
        or a
        jr z,mk1
        call negde
        call neghl
mk1:    ld b,h
        ld c,l
        pop hl
        ld a,16
mk2:    ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        push hl
        ld h,b
        ld l,c
        add hl,de
        ld b,h
        ld c,l
        pop hl
        dec a
        jr nz,mk2
        ret
tget:   add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; work out where one object appears and add it to the draw list
proj:   ld de,(dx)
        ld a,(pcn)
        ld c,a
        ld a,(pcos)
        call smul
        push hl
        ld de,(dy)
        ld a,(psn)
        ld c,a
        ld a,(psin)
        call smul
        pop de
        add hl,de
        bit 7,h
        ret nz
        ld a,h
        or a
        jr nz,pj1
        ld a,l
        cp $30
        ret c
pj1:    ld (depth),hl
        ld de,(dy)
        ld a,(pcn)
        ld c,a
        ld a,(pcos)
        call smul
        push hl
        ld de,(dx)
        ld a,(psn)
        ld c,a
        ld a,(psin)
        call smul
        ex de,hl
        pop hl
        or a
        sbc hl,de
pjlat:  xor a
        bit 7,h
        jr z,pj2
        call neghl
        ld a,1
pj2:    ld (latneg),a
        ld de,(depth)
        or a
        sbc hl,de
        add hl,de
        ret nc
pj3:    ld a,d
        or a
        jr z,pj4
        srl d
        rr e
        srl h
        rr l
        jr pj3
pj4:    ld a,l
        srl a
        ld h,a
        ld a,0
        rra
        ld l,a
        ld c,e
        call div168
        ld a,l
        srl a
        srl a
        srl a
        ld b,a
        ld a,l
        sub b
        srl a
        srl a
        ld b,a
        ld a,(latneg)
        or a
        ld a,16
        jr z,pj5
        sub b
        jr pj6
pj5:    add a,b
pj6:    ld (scol),a
        ld hl,(depth)
        ld a,h
        cp 16
        jr c,pj7
        ld hl,$0FFF
pj7:    srl h
        rr l
        srl h
        rr l
        ld a,h
        add a,LOGD_HI
        ld h,a
        ld a,(hl)
        ld l,a
        ld h,HITAB_HI
        ld a,(hl)
        ld (oz),a
        ld hl,fogz              ; lost in the dark
        cp (hl)
        ret c
        ld hl,(otp)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld a,(oz)
        ld l,a
        ld h,0
        add hl,de
        ld a,(hl)
        ld (osize),a
        pop hl
        ld a,(oframe)
        or a
        jr z,pj8
        inc hl
        inc hl
pj8:    ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(osize)
        add a,a
        add a,a
        ld l,a
        ld h,0
        add hl,de
        ld (orec),hl
        ld a,(hl)
        and $3F
        ld (ow),a
        inc hl
        ld a,(hl)
        ld (oh),a
        ld a,(ow)
        srl a
        ld b,a
        ld a,(scol)
        sub b
        ld (oleft),a
        ld a,(oflg)
        and 8
        jr z,pj8a
        ld a,(oh)               ; flyers hang at eye level
        srl a
        ld b,a
        ld a,21
        sub b
        jr pj8b
pj8a:   ld a,(oflg)
        and $10
        jr z,pj8c
        ld a,(oz)               ; hangs from the ceiling
        ld l,a
        ld h,0
        ld de,BOT
        add hl,de
        ld a,48
        sub (hl)
        jr pj8b
pj8c:   ld a,(oz)
        ld l,a
        ld h,0
        ld de,BOT
        add hl,de
        ld a,(hl)
        ld hl,oh
        sub (hl)
        ld hl,obob
        sub (hl)
pj8b:   ld (otop),a
        ld a,(scol)
        cp 32
        jr nc,pj9
        add a,ZBUF_LO
        ld l,a
        ld h,ZBUF_HI
        ld a,(oz)
        cp (hl)
        jr c,pj9
        ld a,(otype)
        cp NENEMY+1
        jr nc,pj9
        ld hl,(optr)
        ld de,6
        add hl,de
        set 7,(hl)
        ld a,(oz)
        ld hl,aimz
        cp (hl)
        jr c,pjn
        ld (hl),a
        ld a,(scol)
        ld (aimcol),a
pjn:    ld a,(oleft)
        ld b,a
        ld a,16
        sub b
        ld b,a
        ld a,(ow)
        cp b
        jr c,pj9
        ld a,(oz)
        ld hl,tz
        cp (hl)
        jr c,pj9
        ld (hl),a
        ld hl,(optr)
        ld (target),hl
        ld a,(scol)             ; remember where it is on screen, for the burst
        ld (tcol),a
        ld a,(otop)
        ld (ttop),a
        ld a,(oh)
        ld (th),a
pj9:    ld a,(nvis)
        cp 24
        ret nc
        ld l,a
        inc a
        ld (nvis),a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,VIS
        add hl,de
        ld a,(oz)
        ld (hl),a
        inc hl
        ld a,(oleft)
        ld (hl),a
        inc hl
        ld de,(orec)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(otop)
        ld (hl),a
        ret

; draw the list, farthest first
drawvis:
        ld a,(nvis)
        or a
        ret z
        ld b,a
        ld hl,VIS
        ld c,255
        ld de,8
dvf:    ld a,(hl)
        cp c
        jr nc,dvn
        ld c,a
        ld (best),hl
dvn:    add hl,de
        djnz dvf
        ld a,c
        cp 255
        ret z
        ld (s_z),a
        ld hl,(best)
        ld (hl),255
        inc hl
        ld a,(hl)
        ld (s_left),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (s_top),a
        ex de,hl
        call drawspr
        call poll
        jr drawvis

drawgun:
        ld a,13
        ld (s_left),a
        ld a,48-GUNH
        ld (s_top),a
        ld a,255
        ld (s_z),a
        ld hl,GUN0
        ld a,(gunflash)
        or a
        jr z,drawspr
        ld hl,GUN1

; HL -> sprite record: width in bytes (bit 7 = stored whole, otherwise only the
; left half is stored and the right half is drawn mirrored), height, data
drawspr:
        ld a,(hl)
        ld b,a
        and $3F
        ld c,a
        ld a,1                  ; bit 6: this sprite's pixels are in SRAM bank 3
        bit 6,b
        jr z,dsb
        ld a,3
dsb:    out ($37),a
        inc hl
        ld a,(hl)
        ld (s_h),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (s_ptr),de
        ld a,c
        bit 7,b
        jr nz,ds0
        inc a
        srl a
ds0:    ld (s_n1),a
        ld b,a
        ld a,c
        sub b
        ld (s_n2),a
        ld c,a
        ld a,b
        sub c
        ld (s_odd),a
        ld a,(s_top)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(s_base)
        add hl,de
        ld (s_row),hl
        ld a,(s_h)
        ld l,a
        ld h,0
        add hl,hl
        ld (s_adv),hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ex de,hl
        ld hl,SPREND
        or a
        sbc hl,de
        ld (ds_j+1),hl
        ld (s_sp),sp
ds_col: ld a,(s_left)
        cp 32
        jr nc,ds_skip
        add a,ZBUF_LO
        ld l,a
        ld h,ZBUF_HI
        ld a,(s_z)
        cp (hl)
        jr c,ds_skip
        ld hl,(s_row)
        ld a,(s_left)
        ld e,a
        ld d,0
        add hl,de
        ld bc,32
        ld sp,(s_ptr)
ds_j:   jp 0
ds_ret: ld sp,(s_sp)
ds_skip:
        ld hl,(s_ptr)
        ld de,(s_adv)
        add hl,de
        ld (s_ptr),hl
        ld hl,s_left
        inc (hl)
        ld hl,s_n1
        dec (hl)
        jr nz,ds_col
        ld a,(s_n2)             ; now the mirrored half, walking back through the columns
        or a
        ret z
        ld a,(s_odd)
        or a
        jr z,dm_col
        ld hl,(s_ptr)
        ld de,(s_adv)
        or a
        sbc hl,de
        ld (s_ptr),hl
dm_col: ld hl,(s_ptr)
        ld de,(s_adv)
        or a
        sbc hl,de
        ld (s_ptr),hl
        ld a,(s_left)
        cp 32
        jr nc,dm_skip
        add a,ZBUF_LO
        ld l,a
        ld h,ZBUF_HI
        ld a,(s_z)
        cp (hl)
        jr c,dm_skip
        ld hl,(s_row)
        ld a,(s_left)
        ld e,a
        ld d,0
        add hl,de
        ld de,32
        ld a,(s_h)
        ld b,a
        exx
        ld h,MIR_HI
        ld sp,(s_ptr)
dm_l:   pop de
        ld l,e
        ld a,(hl)
        ld l,d
        ld d,(hl)
        exx
        and (hl)
        exx
        or d
        exx
        ld (hl),a
        add hl,de
        dec b
        exx
        jr nz,dm_l
        ld sp,(s_sp)
dm_skip:
        ld hl,s_left
        inc (hl)
        ld hl,s_n2
        dec (hl)
        jr nz,dm_col
        ret

; copy the finished view to the screen
blit:   ld hl,BUF
        ld de,$7000
        ld b,12
bl1:    push bc
        call BLIT4
        push hl
        push de
        call poll
        pop de
        pop hl
        pop bc
        djnz bl1
        ret

; ---------------- data ------------------------------------------
QTAB:   db $0C,$10,0,0
        db $0D,$10,1,0
        db $0D,$F0,1,1
        db $0C,$F0,0,1
PMASK:  db $C0,$30,$0C,$03
MAPPAT: db $00,$00              ; floor
        db $AA,$AA,$AA,$AA      ; walls
        db $7D,$7D              ; door
        db $55,$55              ; way out
        db $AA,$AA
        db $F7,$DF              ; locked door
        db $5F,$F5,$AA,$AA      ; switch
        db $E6,$E6              ; gate
        db $AA,$AA              ; secrets stay secret
latch:  db 1
latchbase: db $08               ; theme block: these 10 bytes are copied in together
skyc:   db $55
groundc: db 0
fogz:   db 0
fogc:   db $AA
cullc:  db 9
tlib:   ds 4
s_base: dw BUF
numbuf: db 0,0,$FF
aflags: ds 12
area:   db 0
newarea: db 0
goarea: db 0
entrycell: db 0
entryang: db 0
keys:   db 0
opals:  db 0
mapkey: db 0
fogged: db 0
px:     dw 0
py:     dw 0
pang:   dw 0
vx:     dw 0
vy:     dw 0
mvx:    dw 0
mvy:    dw 0
newp:   dw 0
rang:   dw 0
sidex:  dw 0
dist:   dw 0
colptr: dw 0
dx:     dw 0
dy:     dw 0
adx:    dw 0
ady:    dw 0
depth:  dw 0
optr:   dw 0
otp:    dw 0
orec:   dw 0
target: dw 0
best:   dw 0
gtptr:  dw 0
ttptr:  dw 0
aexits: dw 0
s_ptr:  dw 0
s_row:  dw 0
s_adv:  dw 0
s_sp:   dw 0
s_n1:   db 0
s_n2:   db 0
s_odd:  db 0
s_h:    db 0
s_left: db 0
s_top:  db 0
s_z:    db 0
hp:     db 0
ammo:   db 0
leveldone: db 0
huddirty: db 0
msgt:   db 0
firecd: db 0
gunflash: db 0
hurtflash: db 0
musict: db 0
recht:  db 0
animt:  db 0
fcnt:   db 0
lastf:  db 0
lastfs: db 0
steps:  db 0
stepc:  db 0
estep:  db 0
inp:    db 0
joyon:  db 0
swc:    db 0
tframe: db 0
tap:    db 0
tcount: db 0
coln:   db 0
fish:   db 0
cell:   db 0
side:   db 0
xneg:   db 0
yneg:   db 0
cidx:   db 0
sidx:   db 0
hidx:   db 0
pcos:   db 0
psin:   db 0
pcn:    db 0
psn:    db 0
latneg: db 0
tcol:   db 0
ttop:   db 0
th:     db 0
pcx:    db 0
pcy:    db 0
pspread: db 0
pcols:  db 0
pnext:  db 0
ptx:    db 0
ptc:    db 0
seed:   db 37
kflg:   db 0
awalk:  db 0
gptr:   dw 0
gframe: db 0
dcycle: db 0
dsa:    db 0
dsc:    db 0
dsang:  db 0
demo_on: db 0
dquit:  db 0
dtime:  dw 0
aimz:   db 0
aimcol: db 0
aturn:  db 0
adir:   db 0
lastpx: dw 0
lastpy: dw 0
fcx:    db 0
fcy:    db 0
p1:     dw 0
p2:     dw 0
cdep:   dw 0
clat:   dw 0
TCT:    ds 32
TST:    ds 32
scol:   db 0
nvis:   db 0
tz:     db 0
otype:  db 0
oflg:   db 0
oflags: db 0
ocool:  db 0
oframe: db 0
obob:   db 0
oz:     db 0
osize:  db 0
ow:     db 0
oh:     db 0
oleft:  db 0
otop:   db 0
        ds 160
stacktop:
codeend:

; ---- below $B800, so it can run while the high bank is switched in --------
        org HICOPY
hicopy: ld a,5
        out ($37),a
        ldir
        ld a,1
        out ($37),a
        ret
