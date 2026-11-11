; ---------------------------------------------------------------
; DROPBEAR 3D - a first-person bear hunt for the VZ300
; mode 1 (128x64, 4 colours), 32-column textured raycaster
; VIBED BY BPM 2026
; Tables, textures, sprites, levels and text come from build.py
; ---------------------------------------------------------------
TURN: equ 10
MARG: equ 80
SIDE: equ 40
EMARG: equ 72
ESPD: equ 12
BOSSSPD: equ 8
BITE: equ 7
BOSSBITE: equ 14
BEARHP: equ 2
BOSSHP: equ 12
NOBJ: equ 16
MUSP: equ 14

        org CODEORG
start:  di
        ld sp,stacktop
        call joyinit
main:   call titlescreen
        ld a,1
        ld (level),a
        ld a,40
        ld (ammo),a
lvl:    call introscreen
        call loadlevel
gloop:  call getinput
        call turnmove
        call fire
        call render
        call objects
        call drawvis
        call drawgun
        call blit
        call hud
        call timers
        ld a,(hp)
        or a
        jr z,dead
        ld a,(leveldone)
        or a
        jr z,gloop
        call jingle_up
        ld a,(level)
        inc a
        ld (level),a
        cp 4
        jr nz,lvl
        ld hl,PG_WIN
        call textpage
        jp main
dead:   call jingle_down
        ld hl,PG_DEAD
        call textpage
        jr lvl

; ---------------- screens ---------------------------------------
introscreen:
        call levptr
        ld a,(hl)
        ld (latchbase),a
        call setlatch
        ld a,(level)
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,PGTAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
textpage:
        push hl
        call cls
        pop hl
        call showpage
        jp waitfire

levptr: ld a,(level)
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,LEVTAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

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

titlescreen:
        ld a,$08
        ld (latchbase),a
        call setlatch
        call cls
        ld hl,LOGO
        ld de,$7000+2*32+5
        ld a,LOGOH
        ld c,LOGOW
        call drawbmp
        ld hl,$7000+15*32+5
        ld b,2
        ld c,22
        ld a,$FF
        call fillrect
        ld hl,PG_TITLE
        call showpage
        ld hl,ZBUF
        ld b,32
tz1:    ld (hl),0
        inc hl
        djnz tz1
        xor a
        ld (tframe),a
        ld (tap),a
        ld hl,TTUNE
        ld (ttptr),hl
tt0:    ld hl,$7000+24*32+1
        ld b,40
        ld c,13
        ld a,$AA
        call fillrect
        ld hl,$7000
        ld (s_base),hl
        ld a,2
        ld (s_left),a
        ld a,26
        ld (s_top),a
        ld a,255
        ld (s_z),a
        ld hl,TBEAR0
        ld a,(tframe)
        rrca
        jr nc,tt1
        ld hl,TBEAR1
tt1:    call drawspr
        ld a,4
        ld (tcount),a
tt2:    ld hl,(ttptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        cp $FF
        jr nz,tt3
        ld hl,TTUNE
        ld (ttptr),hl
        jr tt2
tt3:    ld b,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (ttptr),hl
        push af
        ld a,d
        or e
        call nz,beep
        pop af
        call pause
        call getinput
        ld a,(inp)
        bit 6,a
        jr nz,ttx
        ld a,(tap)
        or a
        jr nz,ttx
        ld hl,tcount
        dec (hl)
        jr nz,tt2
        ld hl,tframe
        inc (hl)
        jp tt0
ttx:    ld hl,BUF
        ld (s_base),hl
        ret

; ---------------- level setup -----------------------------------
loadlevel:
        call levptr
        ld a,(hl)
        ld (latchbase),a
        inc hl
        ld a,(hl)
        ld (px+1),a
        inc hl
        ld a,(hl)
        ld (py+1),a
        inc hl
        ld a,128
        ld (px),a
        ld (py),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (pang),de
        ld a,(hl)
        inc hl
        push hl
        ld hl,OBJ
        ld b,NOBJ*8
ll1:    ld (hl),0
        inc hl
        djnz ll1
        pop hl
        ld b,a
        ld c,0
        ld de,OBJ
ll2:    ld a,(hl)
        ld (de),a
        inc de
        cp 3
        jr nc,ll3
        inc c
ll3:    inc hl
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
        ld hl,-5
        add hl,de
        ld a,(hl)
        pop hl
        cp 2
        ld a,BOSSHP
        jr z,ll4
        ld a,BEARHP
ll4:    ld (de),a
        inc de
        inc de
        inc de
        djnz ll2
        ld a,c
        ld (bears),a
        ld de,MAP
        ld bc,256
        ldir
        ld a,100
        ld (hp),a
        xor a
        ld (key),a
        ld (leveldone),a
        ld (msgt),a
        ld (gunflash),a
        ld (hurtflash),a
        ld (musict),a
        ld (recht),a
        ld (fcnt),a
        ld hl,0
        ld (target),hl
        ld a,(ammo)
        cp 20
        jr nc,ll5
        ld a,20
        ld (ammo),a
ll5:    ld a,25
        ld (firecd),a
        ld a,2
        ld (steps),a
        ld (lastf),a
        ld hl,GTUNE
        ld (gtptr),hl
        call setlatch
        call cls

hudinit:
        ld hl,$7600
        ld b,32
hi1:    ld (hl),$FF
        inc hl
        djnz hi1
        ld hl,PG_HUD
        call showpage
        ld a,(level)
        add a,27
        ld (numbuf+1),a
        ld hl,numbuf+1
        ld de,$7000+57*32+13
        call print
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
gi7:    ld a,(joyon)
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
        ret nz
        ld a,(key)
        or a
        jr z,bnokey
        ld a,1
        ld (leveldone),a
        ret
bnokey: ld a,(msgt)
        or a
        ret nz
        ld hl,MSG_NEEDKEY
        call setmsg
        ld de,230
        ld b,6
        jp beep
bdoor:  ld (hl),0
        ld hl,MSG_DOOR
        call setmsg
        ld e,120
        ld c,20
        ld a,6
        jp sweep

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
        ld hl,bears
        dec (hl)
        ld hl,MSG_GOTONE
        ld a,(otype)
        cp 2
        jr nz,fi3
        ld hl,MSG_BOSS
fi3:    call setmsg
        ld e,40
        ld c,5
        ld a,30
        jp sweep

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
        ld hl,STR_KEY
        ld a,(key)
        or a
        jr nz,hb5
        ld hl,STR_NOKEY
hb5:    ld de,$7000+50*32+24
        call print
        ld a,(bears)
        ld de,$7000+57*32+6
        jp print2

; ---------------- walls -----------------------------------------
render: ld hl,COLS
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
        call texsrc
        ld de,TEXBUF
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
        ld a,(hidx)
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
        ld (dc3+1),de
        ld a,(coln)
        ld l,a
        ld h,BUF_HI
        ld de,32
        ld c,$55                ; sky
dc1:    call 0
dc2:    call 0
        ld c,$00                ; ground
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
        or a
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
        or a
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
        ld l,a
        ld a,(cell)
        dec a
        add a,a
        ld h,a
        ld a,(side)
        add a,h
        add a,TEX_HI
        ld h,a
        ret

; ---------------- things: bears, pickups ------------------------
; object: type, x(2), y(2), hp, flags (bit 7 awake, low 4 hurt timer), bite cooldown
objects:
        xor a
        ld (nvis),a
        ld (tz),a
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
        cp 3
        jr nc,ob2
        call ai
        jr ob3
ob2:    xor a
        ld (oframe),a
        ld (obob),a
        call pick
        ld hl,(optr)
        ld a,(hl)
        or a
        jr z,ob9
ob3:    call proj
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
        cp 3
        jr z,pk_h
        cp 4
        jr z,pk_a
        ld a,1
        ld (key),a
        ld hl,MSG_KEY
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
ai4:    ld a,(oflags)
        rlca
        ret nc
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
        ld (hl),50
        ld a,1
        ld (oframe),a
        ld (huddirty),a
        ld a,3
        ld (hurtflash),a
        ld a,(otype)
        cp 2
        ld b,BITE
        jr nz,ai5
        ld b,BOSSBITE
ai5:    ld a,(hp)
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

ai_ch:  ld a,(otype)
        cp 2
        ld c,ESPD
        jr nz,ac0
        ld c,BOSSSPD
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
        xor a
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
        ld a,(otype)
        dec a
        ld l,a
        add a,a
        add a,l
        add a,a
        ld l,a
        ld h,0
        ld de,TYPES
        add hl,de
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
        ld a,(oz)
        ld l,a
        ld h,0
        ld de,BOT
        add hl,de
        ld a,(hl)
        ld hl,oh
        sub (hl)
        ld hl,obob
        sub (hl)
        ld (otop),a
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
        cp 3
        jr nc,pj9
        ld hl,(optr)
        ld de,6
        add hl,de
        set 7,(hl)
        ld a,(oleft)
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
pj9:    ld a,(nvis)
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

; HL -> sprite record (width bytes, height, data); s_left, s_top, s_z set
drawspr:
        ld a,(hl)
        ld (s_w),a
        inc hl
        ld a,(hl)
        ld (s_h),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (s_ptr),de
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
        ld hl,s_w
        dec (hl)
        jr nz,ds_col
        ret

; copy the finished view to the screen
blit:   ld hl,BUF
        ld de,$7000
        ld b,6
bl1:    push bc
        call BLIT8
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
latch:  db 1
latchbase: db $08
s_base: dw BUF
numbuf: db 0,0,$FF
level:  db 1
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
orec:   dw 0
target: dw 0
best:   dw 0
gtptr:  dw 0
ttptr:  dw 0
s_ptr:  dw 0
s_row:  dw 0
s_adv:  dw 0
s_sp:   dw 0
s_w:    db 0
s_h:    db 0
s_left: db 0
s_top:  db 0
s_z:    db 0
hp:     db 0
ammo:   db 0
key:    db 0
bears:  db 0
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
scol:   db 0
nvis:   db 0
tz:     db 0
otype:  db 0
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
OBJ:    ds 128
        ds 160
stacktop:
codeend:
