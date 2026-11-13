; =====================================================================
;  game.asm - the game block: front end, the level, the camera, and
;  what joins the VZ game's logic (logic.asm) to the Microbee engine.
;  Positions are in VZ pixels (a tile is 8 x 8 of them, a Microbee cell
;  4 x 4); the engine draws at twice that, so the sixteenths the game
;  already keeps show as half-pixel steps.
; =====================================================================
; ---- the VZ game's constants
ST_NORM   equ 0
ST_BURROW equ 1
ST_DIE    equ 2
ST_WIN    equ 3
ACC     equ 3
AIRACC  equ 2
SKID    equ 6
FRIC    equ 3
MAXV    equ 46
JUMPV   equ 66
CUTV    equ 20
GRAV    equ 7
GRAVHI  equ 5
MAXFALL equ 80
SPRINGV equ 104
BURSTV  equ 90
STOMPV  equ 58
DIGV    equ 24
E_ANT   equ 1
E_MAG   equ 2
E_DROP  equ 3
E_TOAD  equ 4
E_PLATH equ 5
E_PLATV equ 6
E_GLOW  equ 7
E_ONEUP equ 8
E_START equ 9
E_WORM  equ 10
E_BOOM  equ 11
E_SPIT  equ 12
E_BOSS  equ 13
NENT    equ 10
RROWS   equ 128                 ; the level is 16 tiles high
VIEWW   equ 160                 ; the screen is 160 VZ pixels wide (the VZ's was 128)
SFX_JUMP    equ 0
SFX_SPRING  equ 1
SFX_BONUS   equ 2
SFX_BREAK   equ 3
SFX_STAR    equ 4
SFX_ONEUP   equ 5
SFX_HURT    equ 6
SFX_DIE     equ 7
SFX_WIN     equ 8
SFX_DIG     equ 9
SFX_DIGSTEP equ 10
SFX_BURST   equ 11
SFX_CHECK   equ 12
SFX_SWOOP   equ 13
SFX_HOP     equ 14
SFX_STOMP   equ 15
SFX_POWER   equ 16

; ---------------------------------------------------------------------
g_start:
        ld sp,STACK
        call title
        call new_game
        call level_start
        call game_loop
        call e_music_off
        ld a,(levdone)
        or a
        jr z,.over
        call clear_screen
        jr g_start
.over:  call over_screen
        jr g_start

; ---------------------------------------------------------------- front end
title:  xor a
        call e_text
        ld hl,t_1
        ld de,$040D
        ld c,YELLOW
        call e_print
        ld hl,t_2
        ld de,$060C
        ld c,BGREEN
        call e_print
        ld hl,t_3
        ld de,$0A07
        ld c,GREY
        call e_print
        ld hl,t_4
        ld de,$0C04
        ld c,GREY
        call e_print
        ld hl,t_5
        ld de,$0F03
        ld c,BCYAN
        call e_print
        ld hl,t_5b
        ld de,$1003
        ld c,BCYAN
        call e_print
        ld hl,t_5c
        ld de,$1103
        ld c,BCYAN
        call e_print
        ld hl,t_5d
        ld de,$1203
        ld c,GREY
        call e_print
        ld hl,t_7
        ld de,$170B
        ld c,BRED
        call e_print
.mon:   ld hl,t_6c
        ld a,(mono)
        or a
        jr z,.m1
        ld hl,t_6m
.m1:    ld de,$1402
        ld c,WHITE
        call e_print
.k:     ld a,1
        call e_wait
        call rnd8
        call e_menukeys
        ld a,(padnew)
        bit 6,a                 ; M
        jr z,.k1
        ld a,1
        ld (mono),a
        jr .mon
.k1:    bit 5,a                 ; C
        jr z,.k2
        xor a
        ld (mono),a
        jr .mon
.k2:    and K_J
        jr z,.k
        ; the inks: colour, or three brightnesses for a monochrome monitor
        ld a,(mono)
        or a
        ld a,M_PCOL >> 8
        ld b,YELLOW
        jr z,.c
        ld a,(M_PCOL >> 8) + 6
        ld b,WHITE
.c:     ld (pcol_h),a
        ld a,b
        ld (hud_col),a
        ret

t_1:    db "BIX THE BILBY",0
t_2:    db "THE STAR DIGGER",0
t_3:    db "MICROBEE PREMIUM PLUS VERSION",0
t_4:    db "PROTOTYPE: WORLD 1-1 GUMLEAF GULLY",0
t_5:    db "O P OR ARROWS: RUN   SPACE: JUMP",0
t_5b:   db "A OR DOWN: DIG IN, THEN TUNNEL",0
t_5c:   db "HOLD SPACE UNDERGROUND: BURST OUT",0
t_5d:   db "V: SMOOTH / STEPPED VERTICAL SCROLL",0
t_6c:   db "MONITOR: COLOUR  (M = MONO)   SPACE",0
t_6m:   db "MONITOR: MONO  (C = COLOUR)   SPACE",0
t_7:    db "VIBED BY BPM 2026",0
t_clr:  db "GUMLEAF GULLY CLEAR!",0
t_stars: db "STARS",0
t_score: db "SCORE",0
t_over: db "GAME OVER",0
t_sp:   db "PRESS SPACE",0

clear_screen:
        xor a
        call e_text
        ld hl,t_clr
        ld de,$080A
        ld c,YELLOW
        call e_print
        jr res_common
over_screen:
        xor a
        call e_text
        ld hl,t_over
        ld de,$080F
        ld c,BRED
        call e_print
res_common:
        ld hl,t_score
        ld de,$0C0E
        ld c,WHITE
        call e_print
        ld hl,score
        ld de,numbuf
        ld b,3
.d:     ld a,(hl)
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
        inc hl
        djnz .d
        ld a,'0'
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld hl,numbuf
        ld de,$0C14
        ld c,WHITE
        call e_print
        ld hl,t_7
        ld de,$170B
        ld c,BRED
        call e_print
        ld a,30
        call e_wait
        ld hl,t_sp
        ld de,$120E
        ld c,BCYAN
        call e_print
.k:     ld a,1
        call e_wait
        call e_menukeys
        ld a,(padnew)
        and K_J
        jr z,.k
        ret
numbuf: ds 8

; ---------------------------------------------------------------- the game's variables
frame     db 0
rnd       dw $1234
look      db 0
keys      db 0
keysold   db 0
kedge     db 0
px16      dw 0
py16      dw 0
vx        db 0
vy        db 0
pstate    db 0
onground  db 0
coyote    db 0
jbuf      db 0
facing    db 0
pframe    db 0
panim     db 0
invuln    db 0
health    db 3
shield    db 0
idlet     db 0
burstt    db 0
landt     db 0
skidding  db 0
statet    db 0
oldppy    db 0
ppx       dw 0
ppy       db 0
ridedx    db 0
lives     db 3
nstars    db 0
score     ds 3
chkx      dw 0
chky      db 0
hudflag   db 0
gameover  db 0
levdone   db 0
tmp1      dw 0
tmp2      dw 0
tmp3      dw 0
shake     db 0
levw      dw LEVW
lv_world  db 1
lv_sx     dw 0
lv_sy     db 0
demo      db 0
mode      db 0
colgen    db 0
pgrav     db 0
st_t      db 0

; ---------------------------------------------------------------- the frame
game_loop:
.lp:    call read_input
        call player_update
        call camera_update
        call vpoll
        call ents_update
        call vpoll
        call hud_update
        call player_draw
        call ents_draw
        call e_frame
        ld hl,frame
        inc (hl)
        ld a,(keys)
        and K_QUIT
        jr z,.nq
        ld a,1
        ld (gameover),a
.nq:    ld a,(levdone)
        or a
        ret nz
        ld a,(gameover)
        or a
        ret nz
        jr .lp

read_input:
        call e_input            ; C = keys
        ld a,(padnew)
        and K_MUS
        jr z,.nm
        ld a,(mus_on)
        xor 1
        ld (mus_on),a
.nm:    ld a,(padnew)
        and K_MONO              ; V: the smooth vertical scroll on / off
        jr z,.nv
        ld a,(smooth)
        xor 1
        ld (smooth),a
.nv:    ld a,(keys)
        ld (keysold),a
        cpl
        and c
        ld (kedge),a
        ld a,c
        ld (keys),a
        ret

sfx_play:
        push hl
        push de
        push bc
        call e_sfx
        pop bc
        pop de
        pop hl
        ret

music_stop:
        jp e_music_off

; nothing yet where the VZ game throws particles
dust_puff:
dirt_spray:
dirt_bit:
block_debris:
sparkle_burst:
sparkle_one:
spawn_part:
conveyor:
        ret

mul12:  add hl,hl               ; x 16: the map's column height here
        add hl,hl
        add hl,hl
        add hl,hl
        ret

; set_tile: HL = map address, A = new tile; the engine redraws its cells
set_tile_log:
set_tile:
        ld (hl),a
        ld (st_t),a
        ld de,MAP
        or a
        sbc hl,de
        ld c,16
        call div16_8            ; HL = tile column, A = row
        ld b,a
        ex de,hl
        ld c,0
        ld h,5
        ld a,(st_t)
        ld l,a
        ; fall through
; a request for the map block: DE = column, B = row, C = n, H = kind, L = argument
q_map:  ld a,(nmapq)
        cp NMAPQ
        ret nc
        push hl
        ld l,a
        add a,a
        add a,l
        add a,a                 ; x 6
        add a,MAPQ & 255
        ld l,a
        ld h,MAPQ >> 8
        ld (hl),e
        inc l
        ld (hl),d
        inc l
        ld (hl),b
        inc l
        ld (hl),c
        inc l
        pop de
        ld (hl),d
        inc l
        ld (hl),e
        ld hl,nmapq
        inc (hl)
        ret

; ---------------------------------------------------------------- the level
new_game:
        ld a,3
        ld (lives),a
        xor a
        ld (nstars),a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ret

level_start:
        call e_gfx
        call e_mapreset
        ld hl,MAP0
        ld de,MAP
        ld bc,MAPLEN
        ldir
        ld hl,(levw)
        add hl,hl
        add hl,hl
        add hl,hl
        push hl
        ld de,VIEWW
        or a
        sbc hl,de
        ld (camxmax),hl
        pop hl
        ld de,8
        or a
        sbc hl,de
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (pxmax16),hl
        ld hl,START_X
        ld (chkx),hl
        ld a,START_Y
        ld (chky),a
        ld hl,ENTST
        ld b,64
.e:     ld (hl),0
        inc hl
        djnz .e
        ld hl,POOL
        ld b,NENT*16
.p:     ld (hl),0
        inc hl
        djnz .p
        ld hl,$1234
        ld (rnd),hl
        xor a
        ld (frame),a
        ld (nmapq),a
        ld (ndraw),a
        ld hl,tune
        call e_music
        ; fall through
respawn:
        ; the floating logs are part of the background: take them out of it
        ld ix,POOL
        ld b,NENT
.pl:    push bc
        call plat_erase
        pop bc
        ld de,16
        add ix,de
        djnz .pl
        xor a
        ld (pstate),a
        ld (vx),a
        ld (vy),a
        ld (invuln),a
        ld (shield),a
        ld (levdone),a
        ld (gameover),a
        ld (onplat),a
        ld (ridedx),a
        ld (ridedy),a
        ld (burstt),a
        ld (look),a
        ld (facing),a
        ld (ndraw),a
        ld a,3
        ld (health),a
        ld a,1
        ld (spawnall),a
        ld hl,ENTST             ; spawn records: active -> available (dead stay dead)
        ld b,64
.e:     ld a,(hl)
        cp 1
        jr nz,.e1
        ld (hl),0
.e1:    inc hl
        djnz .e
        ld hl,POOL
        ld b,NENT*16
.p:     ld (hl),0
        inc hl
        djnz .p
        ld hl,(chkx)
        add hl,hl
        add hl,hl
        add hl,hl
        ld (ppx),hl
        call setposx
        ld a,(chky)
        add a,a
        add a,a
        add a,a
        sub 2
        ld (ppy),a
        call setposy
        ld a,(ppy)
        ld (safey),a
        ld hl,(ppx)
        ld (safex),hl
        call camera_snap
        ld a,1
        ld (hudflag),a
        call hud_update
        call e_snap
        jp spawn_scan

; rescue: fell into water or a pit. Costs one health point (unless
; flashing) and puts Bix back on the last solid ground he stood on; the
; camera runs back to him.
rescue: ld a,(invuln)
        or a
        jr nz,.keep
        ld a,(health)
        dec a
        ld (health),a
        jp z,player_die
.keep:  ld hl,(safex)
        ld (ppx),hl
        call setposx
        ld a,(safey)
        ld (ppy),a
        call setposy
        xor a
        ld (vx),a
        ld (vy),a
        ld (look),a
        ld a,60
        ld (invuln),a
        ld a,1
        ld (hudflag),a
        ld a,SFX_HURT
        jp sfx_play

die_update:
        ld a,PF_HURT
        ld (pframe),a
        ld a,(vy)
        add a,6
        bit 7,a
        jr nz,.d1
        cp MAXFALL
        jr c,.d1
        ld a,MAXFALL
.d1:    ld (vy),a
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        ld de,(py16)
        add hl,de
        ld (py16),hl
        call getpos
        ld hl,statet
        dec (hl)
        ret nz
        ld hl,lives
        dec (hl)
        jr z,.go
        jp respawn
.go:    ld a,1
        ld (gameover),a
        ret

; ---------------------------------------------------------------- camera
camera_snap:
        call cam_target
        ld (camx),hl
        ld a,(ppy)
        ld (refy),a
        call cam_ytarget
        ld (camy),a
        ret

; -> A = where the camera wants to be down the level. It follows the
; height Bix last stood at (so an ordinary jump does not move it), and
; goes with him whenever he nears the top or bottom of the picture: a
; spring, a burst, a long fall.
cam_ytarget:
        ld a,(pstate)
        cp ST_BURROW
        jr z,.set
        ld a,(onground)
        or a
        jr z,.keep
.set:   ld a,(ppy)
        bit 7,a
        jr nz,.keep
        ld (refy),a
.keep:  ld a,(refy)
        sub 56
        jr nc,.t1
        xor a
.t1:    ld b,a
        ld a,(ppy)
        bit 7,a
        jr nz,.top0             ; above the top of the level
        sub 14
        jr nc,.t2
        xor a
.t2:    cp b
        jr nc,.t3
        ld b,a
.t3:    ld a,(ppy)
        sub 68
        jr c,.t4
        cp b
        jr c,.t4
        ld b,a
.t4:    ld a,b
        cp CAMYMAX+1
        ret c
        ld a,CAMYMAX
        ret
.top0:  xor a
        ret
refy:   db 0

; -> HL = where the camera wants to be
cam_target:
        ld hl,(ppx)
        ld a,(look)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        add hl,de
        ld de,VIEWW/2-4
        or a
        sbc hl,de
        bit 7,h
        jr z,.x1
        ld hl,0
.x1:    ld de,(camxmax)
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        ret

camera_update:
        ; look-ahead drifts toward the speed, plus a little for the way he faces
        ld a,(vx)
        sra a
        ld b,a
        ld a,(facing)
        or a
        ld a,16
        jr z,.f
        ld a,-16
.f:     add a,b
        ld b,a
        ld hl,look
        ld a,b
        sub (hl)
        jr z,.l3
        jp m,.ldec
        inc (hl)
        jr .l3
.ldec:  dec (hl)
.l3:    call cam_target
        ; step = (target - camx) / 4, at least 1, at most 4 (a cell a frame)
        ld de,(camx)
        or a
        sbc hl,de
        ld a,h
        or l
        jr z,cam_y
        bit 7,h
        jr nz,.xneg
        ld a,h
        or a
        jr nz,.xp4
        ld a,l
        srl a
        srl a
        jr nz,.xp
        inc a
.xp:    cp 5
        jr c,.xpa
.xp4:   ld a,4
.xpa:   ld l,a
        ld h,0
        add hl,de
        ld (camx),hl
        jr cam_y
.xneg:  ld a,h
        cp $FF
        jr nz,.xn4
        ld a,l
        neg
        srl a
        srl a
        jr nz,.xn
        inc a
.xn:    cp 5
        jr c,.xna
.xn4:   ld a,4
.xna:   ld l,a
        ld h,0
        ex de,hl
        or a
        sbc hl,de
        ld (camx),hl
cam_y:  call cam_ytarget
        ld hl,camy
        sub (hl)
        ret z
        jr c,.up
        srl a                   ; a quarter of the way, 1 to 4 a frame
        srl a
        jr nz,.d1
        inc a
.d1:    cp 5
        jr c,.d2
        ld a,4
.d2:    add a,(hl)
        ld (hl),a
        ret
.up:    neg
        srl a
        srl a
        jr nz,.u1
        inc a
.u1:    cp 5
        jr c,.u2
        ld a,4
.u2:    ld b,a
        ld a,(hl)
        sub b
        ld (hl),a
        ret

; ---------------------------------------------------------------- sprites
; A = frame, B = facing, HL = x, E = y (VZ pixels; x in the world), C = ink
q_ent:  push af
        ld d,0
        bit 7,e
        jr z,.yp
        dec d
.yp:    ex de,hl                ; HL = y, DE = x
        add hl,hl
        push bc
        ld bc,16
        add hl,bc
        pop bc
        push hl
        ex de,hl
        ld de,(camx)
        or a
        sbc hl,de
        add hl,hl               ; screen x
        pop de                  ; screen y
        pop af
; A = frame, B = facing, HL = screen x, DE = screen y, C = ink
q_spr:  ld (qs_x),hl
        ld (qs_f),a
        ld a,(ndraw)
        cp NDRAW
        ret nc
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,DRAWQ >> 8
        ld a,(qs_f)
        ld (hl),a
        inc l
        ld (hl),b
        inc l
        ld a,(qs_x)
        ld (hl),a
        inc l
        ld a,(qs_x+1)
        ld (hl),a
        inc l
        ld (hl),e
        inc l
        ld (hl),d
        inc l
        ld (hl),c
        ld hl,ndraw
        inc (hl)
        ret
qs_x:   dw 0
qs_f:   db 0

player_draw:
        ld a,(invuln)
        and 2
        ret nz                  ; flicker while invulnerable
        ld hl,(py16)            ; sixteenths -> Microbee pixels
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld de,16
        add hl,de
        push hl
        ld hl,(px16)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ex de,hl
        ld hl,(camx)
        add hl,hl
        ex de,hl
        or a
        sbc hl,de
        pop de
        ld a,(facing)
        ld b,a
        ld c,YELLOW
        ld a,(shield)
        or a
        jr z,.ns
        ld a,(frame)
        and 2
        jr z,.ns
        ld c,WHITE              ; the Wattle Glow
.ns:    ld a,(pframe)
        jp q_spr

ent_frame:      ; type -> first sprite frame
        db 0, EF_ANT1, EF_MAG1, EF_DROP1, EF_TOAD1, 0, 0, EF_GLOW1, EF_ONEUP, 0
        db EF_WORM1, EF_BOOM, 0, 0
ent_ink:
        db 0, BRED, WHITE, GREY, BGREEN, 0, 0, YELLOW, YELLOW, 0
        db BMAGENTA, WHITE, 0, 0

ent_jt: dw ant_upd, mag_upd, drop_upd, toad_upd, plath_upd, platv_upd
        dw glow_upd, oneup_upd, ent_nop, worm_upd, boom_upd, ent_nop, ent_nop

ents_draw:
        ld ix,POOL
        ld b,NENT
.l:     ld a,(ix+0)
        or a
        jr z,.n
        cp E_PLATH
        jr z,.n
        cp E_PLATV
        jr z,.n
        cp E_BOSS
        jr nc,.n
        cp E_WORM
        jr nz,.d0
        ld a,(ix+1)
        or a
        jr z,.n
.d0:    push bc
        ld a,(ix+0)
        ld e,a
        ld d,0
        ld hl,ent_ink
        add hl,de
        ld c,(hl)
        ld hl,ent_frame
        add hl,de
        cp E_BOOM
        ld a,(hl)
        jr z,.nb
        add a,(ix+8)
.nb:    ld b,(ix+9)
        ld l,(ix+2)
        ld h,(ix+3)
        ld e,(ix+4)
        call q_ent
        pop bc
.n:     ld de,16
        add ix,de
        djnz .l
        ret

; ---------------------------------------------------------------- the floating logs
; A log is not a sprite: it is cell glyphs put into the map (the engine
; joins and shifts them like any others), so it costs almost nothing and
; Bix is composed over it like any background.
ent_release:
        call plat_erase
        jp ent_release0

; IX = entity: if it is a log or a lift, take its cells out of the map
plat_erase:
        ld a,(ix+0)
        cp E_PLATH
        jr z,.h
        cp E_PLATV
        ret nz
        call plat_cell
        ld c,6
        ld hl,$0000
        push de
        push bc
        call q_map
        pop bc
        pop de
        inc b
        ld hl,$0000
        jp q_map
.h:     call plat_cell
        ld c,7
        ld hl,$0000
        jp q_map

; -> DE = the cell column of its left end, B = its cell row
plat_cell:
        ld e,(ix+2)
        ld d,(ix+3)
        srl d
        rr e
        srl d
        rr e
        ld a,(ix+4)
        rrca
        rrca
        and $3F
        ld b,a
        ret

plath_upd:
        ld a,(frame)            ; half speed: move on every other frame
        and 1
        ret nz
        call plat_cell
        ld (pl_x),de
        call plat_erase
        call plath_move
plath_show:
        call plat_cell
        ld a,(ix+2)
        and 3
        ld l,a
        ld h,1
        ld c,7
        push de
        push bc
        call q_map              ; the log's cell glyphs at its new place
        pop bc
        pop de
        ; show the cells from the leftmost it was or is in, less one
        ld hl,(pl_x)
        or a
        sbc hl,de
        jr nc,.o
        add hl,de
        ex de,hl
.o:     dec de
        ld c,10
        ld hl,$0401
        jp q_map
pl_x:   dw 0
pl_r:   db 0

platv_upd:
        ld a,(frame)
        and 1
        ret z
        call plat_cell
        ld a,b
        ld (pl_r),a
        call plat_erase
        call platv_move
platv_show:
        call plat_cell
        ld a,(ix+4)
        and 3
        ld l,a
        ld h,2
        ld c,6
        push de
        push bc
        push hl
        call q_map
        pop hl
        pop bc
        pop de
        ld a,l
        or a
        jr z,.one               ; it sits on a cell row: no second row
        ld h,3
        inc b
        push de
        push bc
        call q_map
        pop bc
        pop de
        dec b
.one:   ld a,(pl_r)             ; show three rows from the higher of old and new
        cp b
        jr nc,.r
        ld b,a
.r:     dec de
        ld c,8
        ld hl,$0403
        jp q_map

; a log or lift that has just appeared
plat_new:
        call plat_cell
        ld (pl_x),de
        ld a,b
        ld (pl_r),a
        ld a,(ix+0)
        cp E_PLATH
        jp z,plath_show
        jr platv_show

; ---------------------------------------------------------------- the status line
; BIX n   hearts   star nn   SCORE nnnnnn0   1-1
hud_update:
        ld a,(hudflag)
        or a
        ret z
        xor a
        ld (hudflag),a
        ld a,(hud_dirty)
        or a
        jr nz,.hd
        inc a
        ld (hud_dirty),a
.hd:    ld a,1
        ld (hud_rb),a
        ld hl,HUDBUF
        ld b,COLS
.c:     ld (hl),0
        inc l
        djnz .c
        ld hl,HUDBUF+1
        ld (hl),14              ; Bix's head
        inc l
        inc l
        ld a,(lives)
        call .dig
        ld hl,HUDBUF+7
        ld a,(health)
        ld c,a
        ld b,3
.h:     ld a,c
        or a
        ld a,13
        jr z,.h1
        dec c
        ld a,12
.h1:    ld (hl),a
        inc l
        djnz .h
        ld hl,HUDBUF+14
        ld (hl),11
        inc l
        inc l
        ld a,(nstars)
        ld b,0
.t:     cp 10
        jr c,.t1
        sub 10
        inc b
        jr .t
.t1:    push af
        ld a,b
        call .dig
        pop af
        call .dig
        ld hl,HUDBUF+22
        ld de,score
        ld b,3
.s:     ld a,(de)
        rrca
        rrca
        rrca
        rrca
        call .dig
        ld a,(de)
        call .dig
        inc de
        djnz .s
        xor a
        call .dig
        ld hl,HUDBUF+36
        ld (hl),2
        inc l
        ld (hl),15
        inc l
        ld (hl),2
        ret
.dig:   and 15
        inc a
        ld (hl),a
        inc l
        ret
