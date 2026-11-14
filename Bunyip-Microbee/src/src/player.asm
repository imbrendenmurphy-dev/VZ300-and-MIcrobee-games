; ==========================================================================
; player.asm - keys, walking, turning, bumping things, the zapper
;   VIBED BY BPM 2026
; ==========================================================================

; key list: keyst[n] = 1 while held
KY_UP   equ 0
KY_W    equ 1
KY_DOWN equ 2
KY_S    equ 3
KY_LEFT equ 4
KY_A    equ 5
KY_RIGHT equ 6
KY_D    equ 7
KY_Z    equ 8
KY_X    equ 9
KY_FIRE equ 10
KY_E    equ 11
KY_RET  equ 12
KY_M    equ 13
KY_P    equ 14
KY_C    equ 15
KY_ESC  equ 16
KY_R    equ 17
KY_T    equ 18
NKEYS   equ 19
KEYLIST: db K_UP,K_W,K_DOWN,K_S,K_LEFT,K_A,K_RIGHT,K_D,26,24
        db K_SPACE,K_E,K_RET,K_M,K_P,K_C,K_ESC,K_R,20

; readkeys: scan the keys once per frame into keyst (1 = held).  The
;           keyboard scan needs the ROM latch (port 0Bh) on, and nothing
;           may write to the screen while it is.
readkeys:
        ld a,1
        out (PORT_0B),a
        ld hl,KEYLIST
        ld de,keyst
        ld b,NKEYS
.l      push bc
        push hl
        push de
        ld a,(hl)
        call keytest
        pop de
        pop hl
        pop bc
        ld a,0
        jr z,.u
        inc a
.u      ld (de),a
        inc hl
        inc de
        djnz .l
        xor a
        out (PORT_0B),a
        ret

; edge: A = key index -> NZ only when newly pressed this frame
edge:   ld e,a
        ld d,0
        ld hl,keyst
        add hl,de
        ld a,(hl)
        ld hl,keyold
        add hl,de
        or a
        jr z,.up
        ld a,(hl)
        ld (hl),1
        xor 1
        ret
.up     ld (hl),0
        ret

; held: A = first key index, B = second -> NZ if either is held
held2:  ld e,a
        ld d,0
        ld hl,keyst
        add hl,de
        ld a,(hl)
        ld e,b
        ld hl,keyst
        add hl,de
        or (hl)
        ret

; --------------------------------------------------------------------------
; player_input: turn, walk, strafe, bump, use, fire (nstep fields' worth)
; --------------------------------------------------------------------------
player_input:
        ld a,(lastf)            ; move by the time the last frame took
        or a
        jr nz,.n1
        inc a
.n1     cp 7
        jr c,.n2
        ld a,6
.n2     ld (nstep),a
        ; turning
        ld a,KY_LEFT
        ld b,KY_A
        call held2
        jr z,.ntl
        ld de,-TURN
        call turn
.ntl    ld a,KY_RIGHT
        ld b,KY_D
        call held2
        jr z,.ntr
        ld de,TURN
        call turn
.ntr    xor a
        ld (walking),a
        ; forwards / backwards
        ld a,KY_UP
        ld b,KY_W
        call held2
        jr z,.nf
        xor a
        ld (mvneg),a
        ld hl,(pa)
        call walk
        jr .side
.nf     ld a,KY_DOWN
        ld b,KY_S
        call held2
        jr z,.side
        ld a,1
        ld (mvneg),a
        ld hl,(pa)
        call walk
.side   ld a,KY_Z               ; strafe left
        ld b,KY_Z
        call held2
        jr z,.nsl
        ld a,1
        ld (mvneg),a
        ld hl,(pa)
        ld de,512
        add hl,de
        call walk
.nsl    ld a,KY_X               ; strafe right
        ld b,KY_X
        call held2
        jr z,.nsr
        xor a
        ld (mvneg),a
        ld hl,(pa)
        ld de,512
        add hl,de
        call walk
.nsr    ; the zapper sways while you walk
        ld a,(walking)
        or a
        jr z,.nb
        ld a,(bobt)
        ld hl,nstep
        add a,(hl)
        ld (bobt),a
        rrca
        rrca
        and 15
        cp 8
        jr c,.b1
        xor 15
.b1     ld (gun_bob),a
.nb     ; bump or use what is in front
        ld a,(bumpcd)
        or a
        jr z,.bc
        ld hl,nstep
        sub (hl)
        jr nc,.bc0
        xor a
.bc0    ld (bumpcd),a
        jr .fire
.bc     ld a,KY_UP              ; walking into it, or the use key
        ld b,KY_W
        call held2
        jr nz,.use
        ld a,KY_E
        ld b,KY_RET
        call held2
        jr z,.fire
.use    call front_cell
        call interact
.fire   ld a,(firecd)
        or a
        jr z,.fc
        ld hl,nstep
        sub (hl)
        jr nc,.fc0
        xor a
.fc0    ld (firecd),a
        jr .gun
.fc     ld a,KY_FIRE
        ld b,KY_FIRE
        call held2
        call nz,fire
.gun    ld a,(gun_fire)
        or a
        ret z
        ld hl,nstep
        sub (hl)
        jr nc,.g0
        xor a
.g0     ld (gun_fire),a
        ret

; walk: HL = direction to walk in (angle; mvneg = backwards)
walk:   ld a,h
        and 7
        ld h,a
        push hl
        call mvget
        call movex
        pop hl
        ld de,-512              ; sin(a) = cos(a - 90 degrees)
        add hl,de
        ld a,h
        and 7
        ld h,a
        call mvget
        call movey
        ld a,1
        ld (walking),a
        ret

; turn: pa += DE * nstep
turn:   ld a,(nstep)
        ld b,a
        ld hl,(pa)
.l      add hl,de
        djnz .l
        ld a,h
        and 7
        ld h,a
        ld (pa),hl
        ret

; mvget: HL = angle -> DE = distance along that axis this frame
;        (1/65536 cell units, signed, negated when walking backwards)
mvget:  srl h                   ; MVT has one entry per 4 angle steps
        rr l
        res 0,l
        ld de,MVT
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(nstep)
        ld b,a
        ld hl,0
.l      add hl,de
        djnz .l
        ex de,hl
        ld a,(mvneg)
        or a
        ret z
negde:  xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
        ret

; movex: try to move by DE along x; the move is refused if it would put
;        the player within MARGIN of a wall (so you slide along walls)
movex:  ld hl,(px)
        ld a,(px+2)
        add hl,de
        bit 7,d
        jr z,.p
        adc a,0FFh
        jr .s
.p      adc a,0
.s      ld (nx),hl
        ld (nx+2),a
        ld l,h
        ld h,a                  ; HL = new x as cell.fraction
        ld bc,MARGIN
        bit 7,d
        jr z,.pp
        ld bc,-MARGIN
.pp     add hl,bc
        ld b,h                  ; B = cell to test
        ld hl,(py+1)
        ld de,-MARGIN
        add hl,de
        ld c,h
        push bc
        call cellat
        pop bc
        or a
        ret nz
        ld hl,(py+1)
        ld de,MARGIN
        add hl,de
        ld c,h
        call cellat
        or a
        ret nz
        ld hl,(nx)
        ld (px),hl
        ld a,(nx+2)
        ld (px+2),a
        ret

movey:  ld hl,(py)
        ld a,(py+2)
        add hl,de
        bit 7,d
        jr z,.p
        adc a,0FFh
        jr .s
.p      adc a,0
.s      ld (nx),hl
        ld (nx+2),a
        ld l,h
        ld h,a
        ld bc,MARGIN
        bit 7,d
        jr z,.pp
        ld bc,-MARGIN
.pp     add hl,bc
        ld c,h                  ; C = row to test
        ld hl,(px+1)
        ld de,-MARGIN
        add hl,de
        ld b,h
        push bc
        call cellat
        pop bc
        or a
        ret nz
        ld hl,(px+1)
        ld de,MARGIN
        add hl,de
        ld b,h
        call cellat
        or a
        ret nz
        ld hl,(nx)
        ld (py),hl
        ld a,(nx+2)
        ld (py+2),a
        ret

; cellat: B = x cell, C = y cell -> A = map cell (0 = open), HL -> it
cellat: ld a,b
        or c
        and 0E0h
        ld a,1                  ; off the map: solid
        ret nz
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or b
        ld l,a
        ld a,h
        add a,high(MAP)
        ld h,a
        ld a,(hl)
        or a
        ret nz
        set 2,h                 ; SOLID = MAP + 1C00h: scenery in the way?
        set 3,h
        set 4,h
        ld a,(hl)
        res 2,h
        res 3,h
        res 4,h
        ret

; cellxy: HL = x (8.8), DE = y (8.8) -> A = map cell, HL -> it
cellxy: ld b,h
        ld c,d
        jr cellat

; front_cell: B, C = the cell 0.8 cells ahead of the player
front_cell:
        ld hl,(pa)
        call dirvec             ; DE = x step (8.8, 0.8 cells), HL = y step
        push hl
        ld hl,(px+1)
        add hl,de
        ld b,h
        pop de
        ld hl,(py+1)
        add hl,de
        ld c,h
        ret

; dirvec: HL = angle -> DE = cos * 0.8 cells, HL = sin * 0.8 cells (8.8)
dirvec: push hl
        call .one
        pop hl
        push de
        ld de,-512
        add hl,de
        ld a,h
        and 7
        ld h,a
        call .one
        ex de,hl
        pop de
        ret
.one    srl h                   ; MVT = cos * 3277; >> 4 = cos * 205
        rr l
        res 0,l
        ld de,MVT
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ex de,hl
        ret

; --------------------------------------------------------------------------
; interact: B, C = the cell in front.  Doors open, levers swing, secret
;           walls slide away, locked doors want their key.
; --------------------------------------------------------------------------
interact:
        push bc
        call cellat
        pop bc
        or a
        ret z
        ld (icell),hl
        cp C_DOOR
        jr z,.open
        cp C_SECRET
        jr z,.secret
        cp C_GDOOR
        jr c,.n
        cp C_RDOOR+1
        jr nc,.n
        sub C_GDOOR             ; 0 gold, 1 blue, 2 red
        ld e,a
        ld b,a
        inc b
        ld a,(keys)
.kb     rrca
        djnz .kb
        jr c,.open
        ld a,e                  ; locked
        add a,MSG_NEEDG
        jp bumpmsg
.n      cp C_LEVER
        jp z,lever
        cp C_LEVON
        jp z,lever
        cp C_EXIT
        jr z,.exit
        cp C_GATE
        ld a,MSG_GATE
        jp z,bumpmsg
        ld a,(icell)
        ld hl,(icell)
        ld a,(hl)
        cp C_BGATE
        ld a,MSG_BGATE
        jp z,bumpmsg
        ret
.open   ld hl,(icell)
        ld (hl),0
        ld a,SND_DOOR
        call snd_play
        ld a,20
        ld (bumpcd),a
        ret
.secret ld hl,(icell)
        ld (hl),0
        ld hl,secrets
        inc (hl)
        ld de,500
        call addscore
        ld a,SND_KEY
        call snd_play
        ld a,MSG_SECRET
        jp bumpmsg
.exit   ld a,(bossdead)
        or a
        ld a,MSG_SEALED
        jp z,bumpmsg
        ld a,1
        ld (zdone),a
        ret

; bumpmsg: show message A, and don't repeat it for a while
bumpmsg:
        call message
        ld a,40
        ld (bumpcd),a
        ret

; lever: B, C = its cell.  Swings it and every gate of its groups.
lever:  ld hl,(icell)
        ld a,(hl)
        xor C_LEVER ^ C_LEVON
        ld (hl),a
        ; which lever?  its groups
        ld hl,LEVERS
        ld a,(hl)
        or a
        ret z
        ld d,a
        inc hl
.f      ld a,(hl)
        cp b
        jr nz,.nx
        inc hl
        ld a,(hl)
        dec hl
        cp c
        jr z,.got
.nx     inc hl
        inc hl
        inc hl
        dec d
        jr nz,.f
        ret
.got    inc hl
        inc hl
        ld a,(hl)               ; group mask
        ld (lmask),a
        ld hl,GATES
        ld a,(hl)
        or a
        jr z,.done
        ld d,a
        inc hl
.g      push de
        push hl
        ld b,(hl)               ; x, y, group
        inc hl
        ld c,(hl)
        inc hl
        ld e,(hl)
        inc e
        ld a,(lmask)
.gb     dec e
        jr z,.gt
        rrca
        jr .gb
.gt     rrca
        jr nc,.gn
        push bc
        call cellat             ; HL -> cell
        pop bc
        or a
        ld (hl),0
        jr nz,.gn
        ld (hl),C_GATE          ; closing: not on top of the player
        ld a,(px+2)
        cp b
        jr nz,.gn
        ld a,(py+2)
        cp c
        jr nz,.gn
        ld (hl),0
.gn     pop hl
        inc hl
        inc hl
        inc hl
        inc hl
        pop de
        dec d
        jr nz,.g
.done   ld a,SND_LEVER
        call snd_play
        ld a,MSG_LEVER
        jp bumpmsg

; --------------------------------------------------------------------------
; fire: the zapper.  Hits the nearest creature across the middle of the
;       view that is nearer than the wall there (from last frame's sprites)
; --------------------------------------------------------------------------
fire:   ld a,(charges)
        or a
        jr z,.weak
        dec a
        ld (charges),a
        ld a,1
        ld (hud_dirty),a
        ld a,2
        ld (fdmg),a
        ld a,9
        jr .go
.weak   ld a,1                  ; flat: a feeble zap, slower
        ld (fdmg),a
        ld a,MSG_FLAT
        call message
        ld a,20
.go     ld (firecd),a
        ld a,6
        ld (gun_fire),a
        ld a,SND_ZAP
        call snd_play
        ; the wall at the middle of the view
        ld a,(ZB+39)
        ld b,a
        ld a,(ZB+40)
        cp b
        jr c,.m
        ld a,b
.m      ld (fwall),a
        ld a,0FFh
        ld (fbest),a
        ld (fbz),a
        ld a,(nvis)
        or a
        ret z
        ld b,a
        ld iy,VIS
.v      push bc
        ld a,(iy+V_ENT)
        cp 0FFh
        jr z,.nv
        ld a,(iy+V_Z)
        ld hl,fwall
        cp (hl)
        jr nc,.nv               ; behind the wall
        ld hl,fbz
        cp (hl)
        jr nc,.nv               ; not nearer than the best so far
        ld c,a
        ; across the middle?  |dx - 160| < w/2 + 6
        ld l,(iy+V_DX)
        ld h,(iy+V_DX+1)
        ld de,-160
        add hl,de
        bit 7,h
        jr z,.ap
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
.ap     ld a,h
        or a
        jr nz,.nv
        ld a,(iy+V_W)
        srl a
        add a,6
        cp l
        jr c,.nv
        jr z,.nv
        ; a creature still alive?
        ld a,(iy+V_ENT)
        call entptr
        ld a,(ix+E_TYPE)
        cp T_PROP
        jr z,.pr
        cp T_ENEMY
        jr c,.nv
        cp T_ROCK
        jr nc,.nv
        jr .al
.pr     bit 5,(ix+E_FL)         ; F_BREAK: urns and crates can be smashed
        jr z,.nv
.al     ld a,(ix+E_ST)
        cp ST_DIE
        jr nc,.nv
        ld a,c
        ld (fbz),a
        ld a,(iy+V_ENT)
        ld (fbest),a
.nv     ld bc,VSIZE
        add iy,bc
        pop bc
        djnz .v
        ld a,(fbest)
        cp 0FFh
        ret z
        call entptr
        ld a,(ix+E_TYPE)
        cp T_PROP
        jp z,smash
        ld a,(pwrt+1)           ; the Southern Cross doubles every zap
        ld hl,pwrt
        or (hl)
        ld a,(fdmg)
        jr z,.d
        add a,a
.d      jp hurt_ent

; entptr: A = entity number -> IX = its record (keeps BC, DE)
entptr: push de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,ENT
        add hl,de
        push hl
        pop ix
        pop de
        ret
