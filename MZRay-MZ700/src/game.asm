; DROPBEAR 3D for the Sharp MZ-700 - step 1: world walkabout
; Port of the VZ300 game DROPBEAR 3D onto the MZRAY colour-cell raycaster (raycore.asm, unchanged).
; VIBED BY BPM 2026

VIEWH   equ 22
CEIL    equ 0x00
FLOOR   equ 0x11
VRAM    equ 0xD000
CRAM    equ 0xD800
NOBJ    equ 32
MARG    equ 80              ; how close you can get to a wall ahead (1/256 cell)
SIDE    equ 40              ; body half-width for the sideways check
TURNF   equ 0x0140          ; turn per field, 8.8 angle units (about 88 degrees a second)
MSGROW  equ VRAM+20         ; messages: row 0, right half

        org 0x1200
start:
        di
        ld sp,0x1200
        xor a
        ld (0xE008),a           ; speaker gate off
        ld a,2                  ; mode 3: 40 rays, direct
        call setmode
title:
        call attract            ; title, music, gallery, demo - until SPACE
        call sndoff
        call cls
        ld hl,PG_INTRO
        call showpage
        call waitspace
        ld a,1
        ld (tuneon),a
        call newgame
        call cls
        call hudinit
        call loadarea
        call spawn
        ld hl,0
        ld (fields),hl
gloop:
        call frame
        ld a,(hp)
        or a
        jr z,dead
        ld a,(leveldone)
        or a
        jr z,gloop
        call sndoff
        call cls
        ld hl,PG_WIN
        call showpage
        ld hl,SFX_WIN
        call sndwait
        ld a,(opals)
        ld de,WINNUM
        ld c,2
        call pnum
        call waitspace
        jp title

; no instant death: back to the door you came in by, full health, everything you'd collected
dead:   call sndoff
        call cls
        ld hl,PG_DEAD
        call showpage
        ld hl,SFX_DEATH
        call sndwait
        ld hl,PART+7            ; no pieces left hanging about
        ld b,32
        ld de,8
dd0:    ld (hl),0
        add hl,de
        djnz dd0
        ld a,(skycol)
        ld c,0
        call flash
        call waitspace
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
        call showname
        ld hl,0
        ld (fields),hl
        jp gloop

; ---------------------------------------------------------------- one frame
frame:
        call getinput
        call modekeys
        ld a,(inp)              ; holding M: the map, if this area's is known
        rlca
        jr nc,fr1
        call areaflag
        bit 0,(hl)
        jr z,fr0
        call drawmap
        call hud
        jp timers
fr0:    ld a,(msgt)
        or a
        jr nz,fr1
        ld hl,MSG_NOMAP
        call setmsg
fr1:    xor a
        ld (mapon),a
        call turnmove
        ld a,(goarea)
        or a
        call nz,changearea
        call fire
        call objects
        call parts
        call render
        call hud
        jp timers

; ---------------------------------------------------------------- input
; inp bits: 0 fwd, 1 back, 2 left, 3 right, 4 strafe left, 5 strafe right, 6 space, 7 M
getinput:
        ld c,0
        ld a,2                  ; row 2: Q b7, S b5, W b1
        call keyrow
        bit 1,a
        jr nz,gi1
        set 0,c
gi1:    bit 5,a
        jr nz,gi2
        set 1,c
gi2:    bit 7,a
        jr nz,gi3
        set 4,c
gi3:    ld a,4                  ; row 4: A b7, D b4, E b3
        call keyrow
        bit 7,a
        jr nz,gi4
        set 2,c
gi4:    bit 4,a
        jr nz,gi5
        set 3,c
gi5:    bit 3,a
        jr nz,gi6
        set 5,c
gi6:    ld a,7                  ; row 7: up b5, down b4, right b3, left b2
        call keyrow
        bit 5,a
        jr nz,gi7
        set 0,c
gi7:    bit 4,a
        jr nz,gi8
        set 1,c
gi8:    bit 3,a
        jr nz,gi9
        set 3,c
gi9:    bit 2,a
        jr nz,gi10
        set 2,c
gi10:   ld a,6                  ; row 6: SPACE b3
        call keyrow
        bit 3,a
        jr nz,gi11
        set 6,c
gi11:   ld a,3                  ; row 3: M b3
        call keyrow
        bit 3,a
        jr nz,gi12
        set 7,c
gi12:   ld a,c
        ld (inp),a
        ld a,(demo_on)          ; in the demo, SPACE quits and the autopilot drives
        or a
        ret z
        ld a,c
        and 0x40
        ld (dquit),a
        call autopilot
        ld a,c
        ld (inp),a
        ret

keyrow:                         ; A = row -> A = column bits (0 = pressed)
        or 0xF0
        ld (0xE000),a
        nop
        nop
        ld a,(0xE001)
        ret

getmode:                        ; A = 0..3 for keys 1-4, else 0xFF
        ld a,5
        call keyrow
        ld b,a
        ld a,0
        bit 7,b
        ret z
        inc a
        bit 6,b
        ret z
        inc a
        bit 5,b
        ret z
        inc a
        bit 4,b
        ret z
        ld a,0xFF
        ret

modekeys:
        call getmode
        cp 0xFF
        ret z
        ld hl,curmode
        cp (hl)
        ret z
        call setmode
showmode:
        ld a,(curmode)
        add a,0x21
        ld (VRAM+24*40+16),a
        ret

waitspace:
ws1:    call getinput
        ld a,(inp)
        bit 6,a
        jr nz,ws1
ws2:    call getinput
        ld a,(inp)
        bit 6,a
        jr z,ws2
ws3:    call getinput
        ld a,(inp)
        bit 6,a
        jr nz,ws3
        ret

; ---------------------------------------------------------------- movement
turnmove:
        ld a,(lastf)
        ld b,a
tn_l:   push bc
        ld a,(inp)
        ld c,a
        ld hl,(pangf)           ; L = fraction, H = pang
        bit 2,c
        jr z,tn1
        ld de,0-TURNF
        add hl,de
tn1:    bit 3,c
        jr z,tn2
        ld de,TURNF
        add hl,de
tn2:    ld (pangf),hl
        call movestep
        pop bc
        djnz tn_l
        ret

movestep:                       ; one field's worth of walking
        ld a,(inp)
        and 0x33
        ret z
        ld a,(pang)
        ld l,a
        ld h,COS8>>8
        ld a,(hl)
        sra a
        sra a
        sra a
        ld (vx),a
        ld h,SIN8>>8
        ld a,(hl)
        sra a
        sra a
        sra a
        ld (vy),a
        ld a,(inp)
        bit 0,a
        jr z,ms1
        ld a,(vx)
        ld (mvx),a
        ld a,(vy)
        ld (mvy),a
        call move
ms1:    ld a,(inp)
        bit 1,a
        jr z,ms2
        ld a,(vx)
        neg
        ld (mvx),a
        ld a,(vy)
        neg
        ld (mvy),a
        call move
ms2:    ld a,(inp)
        bit 4,a
        jr z,ms3
        ld a,(vy)
        ld (mvx),a
        ld a,(vx)
        neg
        ld (mvy),a
        call move
ms3:    ld a,(inp)
        bit 5,a
        ret z
        ld a,(vy)
        neg
        ld (mvx),a
        ld a,(vx)
        ld (mvy),a
        jp move

; (mvx),(mvy) = signed step in 1/256 cell. Each axis is tried on its own so you slide along walls.
move:   ld a,(mvx)
        or a
        jr z,mv_y
        ld e,a
        ld d,0
        bit 7,a
        jr z,mx0
        dec d
mx0:    ld hl,(px)
        add hl,de
        ld (newp),hl
        ld de,MARG
        ld a,(mvx)
        bit 7,a
        jr z,mx1
        ld de,0-MARG
mx1:    add hl,de
        ld a,h
        ld (tx),a
        ld hl,(py)
        ld de,0-SIDE
        add hl,de
        ld a,h
        call testcell
        jr nz,mx_b
        ld hl,(py)
        ld de,SIDE
        add hl,de
        ld a,h
        call testcell
        jr nz,mx_b
        ld hl,(newp)
        ld (px),hl
        jr mv_y
mx_b:   call bump
mv_y:   ld a,(mvy)
        or a
        ret z
        ld e,a
        ld d,0
        bit 7,a
        jr z,my0
        dec d
my0:    ld hl,(py)
        add hl,de
        ld (newp),hl
        ld de,MARG
        ld a,(mvy)
        bit 7,a
        jr z,my1
        ld de,0-MARG
my1:    add hl,de
        ld a,h
        ld (ty),a
        ld hl,(px)
        ld de,0-SIDE
        add hl,de
        ld a,h
        ld (tx),a
        ld a,(ty)
        call testcell
        jp nz,bump
        ld hl,(px)
        ld de,SIDE
        add hl,de
        ld a,h
        ld (tx),a
        ld a,(ty)
        call testcell
        jp nz,bump
        ld hl,(newp)
        ld (py),hl
        ret

; A = y cell, (tx) = x cell -> A = map value, HL -> map cell, NZ if blocked
testcell:
        add a,a
        add a,a
        add a,a
        add a,a
        ld hl,tx
        add a,(hl)
        ld l,a
        ld h,COLL>>8
        ld a,(hl)
        ld h,MAP>>8
        or a
        jr nz,tc_f
        ld a,(hl)
        or a
        ret
tc_f:   ld a,1                  ; furniture: blocked like a plain wall
        or a
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
        ld hl,SFX_SECRET
        jp sfx
bdoor:  ld (hl),0
        ld hl,MSG_DOOR
        call setmsg
        ld hl,SFX_DOOR
        jp sfx
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
        ld hl,SFX_DOOR
        jp sfx
bnokey: ld a,(msgt)
        or a
        ret nz
        ld hl,MSG_NEEDKEY
        call setmsg
        ld hl,SFX_NOKEY
        jp sfx
bswitch:
        ld (hl),8
        call opengates
        ld hl,MSG_GATE
        call setmsg
        ld hl,SFX_GATE
        jp sfx
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
        cp 0xFF
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

; ---------------------------------------------------------------- pickups
abshl:  bit 7,h
        ret z
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; HL -> object to pick up
pick:   ld a,(hl)
        cp T_HEALTH
        jr z,pk_h
        cp T_AMMO
        jr z,pk_a
        cp T_KEY
        jr z,pk_k
        cp T_OPAL
        jr z,pk_o
        push hl                 ; the map
        call areaflag
        set 0,(hl)
        pop hl
        ld de,MSG_MAP
        jr pk_d
pk_k:   ld a,(keys)
        inc a
        ld (keys),a
        ld de,MSG_KEY
        jr pk_d
pk_o:   ld a,(opals)
        inc a
        ld (opals),a
        ld de,MSG_OPAL
        jr pk_d
pk_h:   ld a,(hp)
        cp 100
        ret nc
        add a,25
        cp 101
        jr c,pk1
        ld a,100
pk1:    ld (hp),a
        ld de,MSG_HEALTH
        jr pk_d
pk_a:   ld a,(ammo)
        cp 99
        ret nc
        add a,15
        cp 100
        jr c,pk2
        ld a,99
pk2:    ld (ammo),a
        ld de,MSG_AMMO
pk_d:   ld (hl),0               ; it's gone
        ld a,1
        ld (huddirty),a
        ex de,hl
        call setmsg
        ld hl,SFX_PICK
        jp sfx

; ---------------------------------------------------------------- the world
; area record: theme, known, name (16 + FF), exit count, exits (cell, to area, to cell, facing),
; object count, objects (type, x, y), map (two cells a byte)
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

; saved state of each area: 256 map bytes then 256 object bytes
liveptr:
        ld a,(area)
        add a,a
        ld h,a
        ld l,0
        ld de,LIVE
        add hl,de
        ret
savearea:
        call liveptr
        ex de,hl
        ld hl,MAP
        ld bc,256
        ldir
        ld hl,OBJ
        ld bc,256
        ldir
        ret
getarea:
        call liveptr
        ld de,MAP
        ld bc,256
        ldir
        ld de,OBJ
        ld bc,256
        ldir
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
        push af
        ld hl,OBJ
        ld de,OBJ+1
        ld bc,255
        ld (hl),0
        ldir
        pop af
        pop hl
        or a
        jr z,ex4
        ld b,a
        ld de,OBJ
ex2:    ld a,(hl)               ; type
        ld (de),a
        inc de
        inc hl
        ld a,128                ; x: middle of the cell
        ld (de),a
        inc de
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        ld a,128                ; y
        ld (de),a
        inc de
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        push hl                 ; hp from the type table; asleep; no cooldown
        dec de
        dec de
        dec de
        dec de
        dec de
        ld a,(de)
        inc de
        inc de
        inc de
        inc de
        inc de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push de
        ld de,TYPET+5
        add hl,de
        pop de
        ld a,(hl)
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ld (de),a
        inc de
        pop hl
        djnz ex2
ex4:    ld de,MAP
        ld b,128
ex5:    ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        ld (de),a
        inc de
        ld a,(hl)
        and 0x0F
        ld (de),a
        inc de
        inc hl
        djnz ex5
        ret

; blocking furniture goes in its own page, so the rays never see it
markcoll:
        ld hl,COLL
        ld de,COLL+1
        ld bc,255
        ld (hl),0
        ldir
        ld hl,OBJ
        ld b,NOBJ
mc_l:   ld a,(hl)
        push hl
        ld e,a
        ld d,0
        ld hl,SOLIDT
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr z,mc_n
        push hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        inc hl
        ld a,(hl)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,e
        ld l,a
        ld h,COLL>>8
        ld (hl),1
        pop hl
mc_n:   ld de,8
        add hl,de
        djnz mc_l
        ret

newgame:
        xor a
        ld (keys),a
        ld (opals),a
        ld (leveldone),a
        ld (goarea),a
        ld (msgt),a
        ld a,40
        ld (ammo),a
        ld a,100
        ld (hp),a
        ld hl,GTUNE
        ld (gtptr),hl
        ld hl,PART+7
        ld b,32
        ld de,8
ng0:    ld (hl),0
        add hl,de
        djnz ng0
        xor a
ng1:    ld (area),a
        call expand
        call savearea
        ld a,(area)
        inc a
        cp NAREA
        jr nz,ng1
        xor a
        ld (area),a
        ld a,STARTCELL
        ld (entrycell),a
        ld a,STARTANG
        ld (entryang),a
        ret

loadarea:
        call getarea
        call markcoll
        call areaptr
        ld a,(hl)
        push hl
        call settheme
        pop hl
        inc hl
        inc hl
        push hl
        ld de,17
        add hl,de
        ld (aexits),hl
        pop hl
        xor a
        ld (msgt),a
showname:
        ld hl,VRAM              ; clear the top line, then the area name
        ld de,VRAM+1
        ld bc,39
        ld (hl),0
        ldir
        call areaptr
        inc hl
        inc hl
        ld de,VRAM
        call print
        ld a,1
        ld (huddirty),a
        ret

; A = theme: sky and ground colours go into the column drawers, four wall textures into TEX
settheme:
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,THEMES
        add hl,de
        ld a,(hl)
        ld (skycol),a
        ld (d1_cl+1),a
        ld (d2_cl+1),a
        ld (d2_cl+4),a
        inc hl
        ld a,(hl)
        ld (d1_fl+1),a
        ld (d2_fl+1),a
        ld (d2_fl+4),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)               ; fog: walls shorter than this fade into the murk (0 = none)
        ld (fogh),a
        ex de,hl                ; HL -> library block: slot, row, 16 bytes
        xor a
st_s:   ld (tslot),a
        ld e,a
        ld d,0
        push hl
        ld hl,TOFF
        add hl,de
        ld e,(hl)
        pop hl
        ld d,TEX>>8
        ld b,8
st_r:   push bc
        push de
        ld bc,16
        ldir
        pop de
        inc d
        pop bc
        djnz st_r
        ld a,(tslot)
        inc a
        cp 5
        jr nz,st_s
        ret

; pre-draw hook (A = wall height, HL = screen): past the fog distance, draw the fog texture
fogchk: ld c,a
        ld a,(fogh)
        cp c
        ld a,c
        ret c
        ret z
        ld a,(texl)
        and 7
        or FOGTEX
        ld (texl),a
        ld a,c
        ret

spawn:  ld a,(entrycell)
        and 0x0F
        ld (pxc),a
        ld a,(entrycell)
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        ld (pyc),a
        ld a,128
        ld (pxf),a
        ld (pyf),a
        ld a,(entryang)         ; facing 0..3 -> 0, 64, 128, 192
        rrca
        rrca
        ld (pang),a
        xor a
        ld (pangf),a
        ret

; the automap: each map cell is two screen cells wide, centred in the view; you blink in white
MAPTOP  equ CRAM+40+3*40+4
drawmap:
        ld a,(mapon)            ; clear the view only when the map first opens (no flicker)
        or a
        jr nz,dm0
        inc a
        ld (mapon),a
        ld hl,CRAM+40
        ld de,CRAM+41
        ld bc,VIEWH*40-1
        ld (hl),0
        ldir
dm0:    ld hl,MAP
        ld de,MAPTOP
        ld c,16
dm_r:   ld b,16
dm_c:   ld a,(hl)
        push hl
        ld l,a
        ld h,MAPCOL>>8
        ld a,(hl)
        pop hl
        ld (de),a
        inc de
        ld (de),a
        inc de
        inc hl
        djnz dm_c
        ex de,hl
        ld a,c
        ld bc,8
        add hl,bc
        ld c,a
        ex de,hl
        dec c
        jr nz,dm_r
        ld a,(animt)
        and 8
        ret z
        ld a,(pyc)
        call times40
        ld a,(pxc)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld de,MAPTOP
        add hl,de
        ld (hl),0x77
        inc hl
        ld (hl),0x77
        ret

changearea:
        xor a
        ld (goarea),a
        call savearea
        ld a,(newarea)
        ld (area),a
        call loadarea
        jp spawn

; ---------------------------------------------------------------- status lines
setmsg: ld a,150                ; about three seconds
        ld (msgt),a
drawmsg:
        ld de,MSGROW
        jp print

hudinit:
        ld hl,PG_HUD
        call showpage
        call showmode
        ld a,1
        ld (huddirty),a
        ret

hud:    ld a,(huddirty)
        or a
        ret z
        xor a
        ld (huddirty),a
        ld a,(hp)
        ld de,VRAM+23*40+7
        ld c,3
        call pnum
        ld a,(ammo)
        ld de,VRAM+23*40+17
        ld c,2
        call pnum
        ld a,(keys)
        ld de,VRAM+23*40+26
        ld c,1
        call pnum
        ld a,(opals)
        ld de,VRAM+23*40+35
        ld c,2
        jp pnum

; A = value, DE = screen, C = digits
pnum:   push de
        push bc
        ld l,a
        ld h,0
        call num5
        pop bc
        pop de
        ld a,5
        sub c
        ld l,a
        ld h,0
        push bc
        ld bc,numbuf
        add hl,bc
        pop bc
        ld b,0
        ldir
        ret

; per-frame bookkeeping: fields since last frame, message timer, frame rate
timers: ld hl,(fields)
        ld a,h
        or a
        jr nz,ti_big
        ld a,l
        cp 9
        jr c,ti_ok
ti_big: ld a,8
ti_ok:  or a
        jr nz,ti_nz
        inc a
ti_nz:  ld (lastf),a
        ld b,a
        ld a,(animt)
        add a,b
        ld (animt),a
        ld hl,firecd
        call tdec
        call sndframe
        call flashend
        ld a,(gunflash)
        or a
        jr z,ti_g
        dec a
        ld (gunflash),a
ti_g:   ld de,(fields)
        ld hl,(fsum)
        add hl,de
        ld (fsum),hl
        ld hl,0
        ld (fields),hl
        ld a,(msgt)
        or a
        jr z,ti_m
        ld hl,lastf
        sub (hl)
        jr nc,ti_m1
        xor a
ti_m1:  ld (msgt),a
        or a
        jr nz,ti_m
        ld hl,MSG_BLANK
        call drawmsg
ti_m:   ld hl,fpsc
        inc (hl)
        ld a,(hl)
        cp 16
        ret nz
        ld (hl),0
        ld de,(fsum)
        ld hl,0
        ld (fsum),hl
        ld a,d
        or e
        ret z
        ld hl,8000
        call div16
        call num5
        ld hl,VRAM+24*40+4
        jp pfps

tdec:   ld a,(lastf)            ; (HL) -= fields since last frame, stopping at 0
        ld b,a
        ld a,(hl)
        sub b
        jr nc,td1
        xor a
td1:    ld (hl),a
        ret

;@@OBJECTS@@

;@@FX@@

;@@ATTRACT@@

;@@RAYCORE@@

; ---------------------------------------------------------------- helpers
cls:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,999
        ld (hl),0
        ldir
        ld hl,CRAM
        ld de,CRAM+1
        ld bc,999
        ld (hl),0x70
        ldir
        ret

; HL -> list of (screen address, string) ending with a zero address
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

print:                          ; HL = string (display codes, FF end), DE = dest. HL ends past the FF
        ld a,(hl)
        inc hl
        cp 0xFF
        ret z
        ld (de),a
        inc de
        jr print

num5:                           ; HL -> numbuf (5 display-code digits)
        ld de,numbuf
        ld bc,-10000
        call nd
        ld bc,-1000
        call nd
        ld bc,-100
        call nd
        ld bc,-10
        call nd
        ld a,l
        add a,0x20
        ld (de),a
        ret
nd:
        ld a,0x1F
nd1:
        inc a
        add hl,bc
        jr c,nd1
        sbc hl,bc
        ld (de),a
        inc de
        ret

pfps:                           ; HL = dest; prints numbuf as dd.d
        ex de,hl
        ld a,(numbuf+2)
        cp 0x20
        jr nz,pf1
        xor a
pf1:
        ld (de),a
        inc de
        ld a,(numbuf+3)
        ld (de),a
        inc de
        ld a,0x2E
        ld (de),a
        inc de
        ld a,(numbuf+4)
        ld (de),a
        ret

div16:                          ; HL = HL / DE
        ld a,h
        ld c,l
        ld hl,0
        ld b,16
dv_l:
        sla c
        rla
        adc hl,hl
        sbc hl,de
        jr nc,dv_ok
        add hl,de
        jr dv_n
dv_ok:
        inc c
dv_n:
        djnz dv_l
        ld h,a
        ld l,c
        ret

; ---------------------------------------------------------------- render modes
modetab:
        db 20,2,0
        dw CRAM+40,colang20,cosoff20,drawcol2
        db 20,2,1
        dw BUF,colang20,cosoff20,drawcol2
        db 40,1,0
        dw CRAM+40,colang40,cosoff40,drawcol1
        db 40,1,1
        dw BUF,colang40,cosoff40,drawcol1
;@@SMALLTABLES@@

; ---------------------------------------------------------------- variables
m_nrays:   db 0
m_colstep: db 0
m_buf:     db 0
m_dest:    dw 0
m_colang:  dw 0
m_cosoff:  dw 0
m_drawcol: dw 0
curmode:   db 0
ray:       db 0
rayang:    db 0
raycos:    db 0
rayflg:    db 0
hittype:   db 0
hitside:   db 0
hgt:       db 0
texl:      db 0
cbcnt:     db 0
pangf:     db 0                 ; must sit just before pang: (pangf) as a word is 8.8 angle
pang:      db 0
px:        dw 0
py:        dw 0
pxf        equ px
pxc        equ px+1
pyf        equ py
pyc        equ py+1
fields:    dw 0
fsum:      dw 0
fpsc:      db 0
lastf:     db 1
destp:     dw 0
dxv:       dw 0
dyv:       dw 0
sidex:     dw 0
sidey:     dw 0
perp:      dw 0
newp:      dw 0
numbuf:    ds 5
inp:       db 0
vx:        db 0
vy:        db 0
mvx:       db 0
mvy:       db 0
tx:        db 0
ty:        db 0
tslot:     db 0
area:      db 0
newarea:   db 0
goarea:    db 0
entrycell: db 0
entryang:  db 0
aexits:    dw 0
aflags:    ds 12
keys:      db 0
opals:     db 0
hp:        db 0
ammo:      db 0
leveldone: db 0
huddirty:  db 0
msgt:      db 0
animt:     db 0
firecd:    db 0
gunflash:  db 0
scount:    dw 0
sdelta:    dw 0
smask:     db 0
sfld:      db 0
snext:     dw 0
sact:      db 0
mdink:     db 0
musict:    db 0
gtptr:     dw 0
seed:      db 37
flasht:    db 0
skycol:    db 0x11
fogh:      db 0
mapon:     db 0
tuneon:    db 0
demo_on:   db 0
dquit:     db 0
dcycle:    db 0
dsa:       db 0
dtime:     dw 0
aturn:     db 0
awalk:     db 0
adir:      db 0
lastpx:    dw 0
lastpy:    dw 0
aimz:      db 0
aimcol:    db 0
gptr:      dw 0
gframe:    db 0
wcnt:      db 0
tmv:       ds 6
tmvi:      db 0
tmlen:     db 0
tmptr:     dw 0
pnext:     db 0
pcx:       db 0
pcy:       db 0
pspr:      db 0
pcolp:     dw 0
pidx:      db 0
tcen:      db 20
trow:      db 11
tsz:       db 8
nvis:      db 0
tgth:      db 0
target:    dw 0
cwall:     db 0
scol:      db 0
psgn:      db 0
pcosm:     db 0
psinm:     db 0
otype:     db 0
otp:       dw 0
dx:        dw 0
dy:        dw 0
adx:       dw 0
ady:       dw 0
oframe:    db 0
oflags:    db 0
ocool:     db 0
oflg:      db 0
estep:     db 0
oz:        dw 0
olat:      dw 0
oh:        db 0
ocen:      dw 0
ohs:       db 0
ows:       db 0
oleft:     dw 0
oright:    db 0
oleftc:    db 0
oust:      dw 0
ouacc:     dw 0
osb:       dw 0
ovs:       db 0
ovi:       db 0
otop:      db 0
orows:     db 0
oentry:    db 0
zminc:     db 0
zminl:     db 0
sprmask:   dw 0
dthr:      dw 0

;@@GAMEDATA@@

;@@TABLES@@

gend:
OBJ     equ (gend+255)&0xFF00   ; work areas past the end of the file, so they aren't loaded
COLL    equ OBJ+256
VIS     equ COLL+256            ; visible sprite entries; their draw order at VIS+ORDLO
ORDLO   equ 0xC0
ZB      equ VIS+0xD0            ; last frame's wall height per column (40)
MASKS   equ VIS+256             ; per column: which ORD positions cover it (40 words)
PHEAD   equ MASKS+0x50          ; per ray: first piece drawn there (index+1, 0 = none) (40)
PNEXT   equ MASKS+0x80          ; per piece: the next one under the same ray (32)
PART    equ MASKS+256           ; 32 pieces x 8 bytes
LIVE    equ PART+256
BUF     equ LIVE+512*NAREA
BUFEND  equ BUF+880
