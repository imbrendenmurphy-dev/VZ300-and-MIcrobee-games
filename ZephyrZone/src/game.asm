; =====================================================================
;  game.asm - the hero, the camera and the world scroll
; =====================================================================
ZP          equ 160         ; the hero's depth (sprites are drawn at scale 1.0 there)
PX_MAX      equ 150*8
PY_MAX      equ 92*8
ACC_X       equ 7           ; 1/8 units per field per field
MAXV_X      equ 40
ACC_Y       equ 6
MAXV_Y      equ 30

; hero poses (frame numbers of sprite type T_HERO, see tools/hero.py)
P_FLY       equ 0
P_FLY2      equ 1
P_BANKL     equ 2
P_BANKL2    equ 3
P_BANKR     equ 4
P_BANKR2    equ 5
P_CLIMB     equ 6
P_DIVE      equ 7
P_RUN       equ 8
P_FIRE      equ 12
P_HURT      equ 13
P_CHEER     equ 14
P_FALL1     equ 15
P_FALL2     equ 16
P_DOWN      equ 17

game_init:
            ld hl,objs
            ld de,objs+1
            ld bc,NOBJ*OSIZE-1
            ld (hl),0
            ldir
            ld hl,0
            ld (px8),hl
            ld (pvx),hl
            ld (pvy),hl
            ld (travel),hl
            ld (next_spawn),hl
            ld hl,40*8
            ld (py8),hl
            ld a,13
            ld (speed),a
            ld a,3                  ; a steady 16.7 frames a second
            ld (minfields),a
            ld (dt),a
            ld a,HUDROWS            ; repaint the whole sky on the first frame
            ld (dirty_prev),a
            ret

; ---------------------------------------------------------------------
; one frame of play
; ---------------------------------------------------------------------
game_frame:
            call read_input
            ld a,(demo)
            or a
            call nz,autopilot
            ld a,(dtf)
            or a
            jr nz,.d1
            ld a,2
.d1:        cp 5
            jr c,.d2
            ld a,4
.d2:        ld (dt),a
            ld hl,anim
            add a,(hl)
            ld (hl),a
            ld a,(frozen)
            or a
            jr nz,.nc
            ld hl,(clock)
            ld a,(dt)
            ld e,a
            ld d,0
            add hl,de
            ld (clock),hl
.nc:        call map_game
            ld a,(frozen)           ; the hero is down: everything holds still
            or a
            jr nz,.fz
            call hero_update
            call hero_fire
            call camera
            call world_update
            call update_objects
            call hero_collide
            call stage_events
            jr .pj
.fz:        call camera
.pj:        call project_all
            call render_bg
            call draw_objects
            call draw_hero
            call draw_msg
            call map_game
            call sound_tick
            ld a,(hud_dirty)
            or a
            call nz,hud_draw_m
            jp present

; ---------------------------------------------------------------------
; firing: hold fire (or autofire) for a stream of bolts
; ---------------------------------------------------------------------
hero_fire:
            ld a,(fire_cd)
            ld hl,dt
            sub (hl)
            jr nc,.c
            xor a
.c:         ld (fire_cd),a
            ld a,(dead)
            or a
            ret nz
            ld a,(in_now)
            and K_FIRE
            ld b,a
            ld a,(autofire)
            or b
            ret z
            ld a,(fire_cd)
            or a
            ret nz
            ld a,(nbolts)
            cp 7
            ret nc
            ld a,6
            ld (fire_cd),a
            ld a,5
            ld (hfire),a
            ld a,SFX_SHOT
            call sfx
            ld a,(wlevel)
            or a
            jr nz,.w1
            ld de,8
            ld c,0
            jp spawn_bolt
.w1:        dec a
            jr nz,.w2
            ld de,-2
            ld c,0
            call spawn_bolt
            ld de,18
            ld c,0
            jp spawn_bolt
.w2:        ld de,8
            ld c,0
            call spawn_bolt
            ld de,-2
            ld c,-3
            call spawn_bolt
            ld de,18
            ld c,3
            ; fall through
; bolt at hero x + DE, sideways speed C
spawn_bolt:
            push de
            push bc
            call obj_alloc
            pop bc
            pop de
            ret c
            ld hl,nbolts
            inc (hl)
            ld (ix+O_KIND),K_BOLT
            ld (ix+O_SPR),T_BOLT
            ld (ix+O_FLAGS),0
            ld (ix+O_VX),c
            ld hl,(px)
            add hl,de
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            ld a,(py)
            add a,34
            ld (ix+O_Y),a
            ld hl,ZP+20
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
            ret

; ---------------------------------------------------------------------
; hero: accelerate towards the stick, clamp, pose
; ---------------------------------------------------------------------
hero_update:
            ld a,(dt)
            ld b,a
.step:      push bc
            ; ---- x
            ld a,(in_now)
            ld hl,(pvx)
            bit 2,a
            jr z,.nl
            ld de,-ACC_X
            add hl,de
            jr .cx
.nl:        bit 3,a
            jr z,.nr
            ld de,ACC_X
            add hl,de
            jr .cx
.nr:        call damp
.cx:        ld de,MAXV_X
            call clampv
            ld (pvx),hl
            ex de,hl
            ld hl,(px8)
            add hl,de
            ld de,PX_MAX
            call clampp
            ld (px8),hl
            ; ---- y (up = climb)
            ld a,(in_now)
            ld hl,(pvy)
            bit 0,a
            jr z,.nu
            ld de,ACC_Y
            add hl,de
            jr .cy
.nu:        bit 1,a
            jr z,.nd
            ld de,-ACC_Y
            add hl,de
            jr .cy
.nd:        call damp
.cy:        ld de,MAXV_Y
            call clampv
            ld (pvy),hl
            ex de,hl
            ld hl,(py8)
            add hl,de
            bit 7,h
            jr z,.yp
            ld hl,0
            ld (pvy),hl
.yp:        ld de,PY_MAX
            push hl
            or a
            sbc hl,de
            pop hl
            jr c,.yok
            ld hl,0
            ld (pvy),hl
            ld hl,PY_MAX
.yok:       ld (py8),hl
            pop bc
            dec b
            jp nz,.step
            ; units
            ld hl,(px8)
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            ld (px),hl
            ld hl,(py8)
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            ld a,l
            ld (py),a
            ; ---- pose
            ld a,(hfire)
            or a
            jr z,.nf
            dec a
            ld (hfire),a
.nf:        ld a,(py)
            cp 3
            jr nc,.air
            ; running on the ground
            ld a,(anim)
            rrca
            rrca
            and 3
            add a,P_RUN
            jr .pose
.air:       ld hl,(pvx)
            ld de,-24
            call cmp16s
            jr nc,.nbl
            ld a,P_BANKL2
            jr .pose
.nbl:       ld de,-8
            call cmp16s
            jr nc,.nbl2
            ld a,P_BANKL
            jr .pose
.nbl2:      ld de,25
            call cmp16s
            jr c,.nbr
            ld a,P_BANKR2
            jr .pose
.nbr:       ld de,9
            call cmp16s
            jr c,.nbr2
            ld a,P_BANKR
            jr .pose
.nbr2:      ld hl,(pvy)
            ld de,14
            call cmp16s
            jr c,.ncl
            ld a,P_CLIMB
            jr .pose
.ncl:       ld de,-14
            call cmp16s
            jr nc,.ndv
            ld a,P_DIVE
            jr .pose
.ndv:       ld a,(hfire)
            or a
            ld a,P_FIRE
            jr nz,.pose
            ld a,(anim)
            rrca
            rrca
            and 1
.pose:      ld b,a
            ld a,(force_pose)
            or a
            jr nz,.fp
            ld a,(inv)
            cp 50
            ld a,b
            jr c,.fp
            ld a,(health)           ; just hit: thrown back
            or a
            ld a,b
            jr z,.fp
            ld a,(inv)
            cp 60
            ld a,b
            jr c,.fp
            ld a,P_HURT
.fp:        ld (hpose),a
            ret

; HL towards 0 by 4
damp:
            bit 7,h
            jr nz,.neg
            ld de,-4
            add hl,de
            ret c                   ; was >= 4
            ld hl,0
            ret
.neg:       ld de,4
            add hl,de
            ret nc
            ld hl,0
            ret

; clamp HL to +-DE
clampv:
            push hl
            or a
            sbc hl,de
            pop hl
            jr z,.ok
            bit 7,h
            jr nz,.lo
            push hl
            or a
            sbc hl,de
            pop hl
            ret c
            ex de,hl
            ret
.lo:        push hl
            add hl,de               ; HL + DE < 0 -> clamp to -DE
            pop hl
            ret c
            ld hl,0
            or a
            sbc hl,de
            ret
.ok:        ret

; clamp HL (signed) to +-DE
clampp:     jr clampv

; signed compare HL vs DE: C if HL < DE
cmp16s:
            ld a,h
            xor d
            jp m,.diff
            push hl
            or a
            sbc hl,de
            pop hl
            ret
.diff:      bit 7,h
            scf
            ret nz
            or a
            ret

; ---------------------------------------------------------------------
; camera: follows the hero sideways; horizon drops as he climbs
; ---------------------------------------------------------------------
camera:
            ; camx = px * 7/16
            ld hl,(px)
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,hl               ; *8
            or a
            sbc hl,de               ; *7
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            ld (camx),hl
            ld a,l
            add a,a
            add a,a
            ld (cam_cf),a           ; frac(camx/64) * 256
            ld a,l
            sra h
            rra
            sra h
            rra
            ld (pano_x),a
            ; hz = 20 + py * 13 / 128
            ld a,(py)
            ld c,13
            call mul88_fast
            ld a,h
            add hl,hl
            ld a,h
            add a,HZ_MIN
            cp HZ_MAX+1
            jr c,.h
            ld a,HZ_MAX
.h:         ld (hz),a
            ; hero screen position: sx = 64 + (px - camx) * 0.6, sy = hz + (96 - py) * 0.4
            ld hl,(px)
            ld de,(camx)
            or a
            sbc hl,de
            ld b,h
            bit 7,h
            jr z,.p
            xor a
            sub l
            ld l,a
.p:         ld a,l
            ld c,154
            push bc
            call mul88_fast
            pop bc
            ld l,h
            ld h,0
            bit 7,b
            jr z,.p2
            xor a
            sub l
            ld l,a
            sbc a,a
            ld h,a
.p2:        ld de,64
            add hl,de
            ld (hsx),hl
            ld a,(py)
            ld b,a
            ld a,CAMH
            sub b
            ld c,102
            call mul88_fast
            ld a,(hz)
            add a,h
            ld l,a
            ld h,0
            ld (hsy),hl
            ret

; A * C -> HL without the bank-3/upper-1 tables (small loop, for the camera)
mul88_fast:
            ld hl,0
            ld d,0
            ld e,c
            ld b,8
.l:         add hl,hl
            rla
            jr nc,.n
            add hl,de
.n:         djnz .l
            ret

; ---------------------------------------------------------------------
; the world moves towards us; scenery appears on the horizon
; ---------------------------------------------------------------------
world_update:
            ; distance this frame
            ld a,(dt)
            ld b,a
            ld a,(speed)
            ld c,a
            xor a
.m:         add a,c
            djnz .m
            ld c,a                  ; units this frame
            ld hl,(zs)
            ld b,0
            add hl,bc
            ld (zs),hl
            ld hl,(travel)
            add hl,bc
            ld (travel),hl
            ; move objects
            ld ix,objs
            ld b,NOBJ
.o:         ld a,(ix+O_KIND)
            or a
            jr z,.on
            bit 0,(ix+O_FLAGS)
            jr z,.on
            ld l,(ix+O_Z)
            ld h,(ix+O_Z+1)
            ld e,c
            ld d,0
            or a
            sbc hl,de
            jr c,.kill
            ld de,60
            sbc hl,de
            jr c,.kill
            add hl,de
            ld (ix+O_Z),l
            ld (ix+O_Z+1),h
            jr .on
.kill:      ld (ix+O_KIND),0
.on:        ld de,OSIZE
            add ix,de
            djnz .o
            ; spawn scenery every scen_gap*4 units, types from scen_mix
            ld hl,(travel)
            ld de,(next_spawn)
            or a
            sbc hl,de
            ret c
            ld a,(boss_on)          ; the boss has the stage to itself
            or a
            ret nz
            ld a,(scen_gap)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            ld de,(next_spawn)
            add hl,de
            ld (next_spawn),hl
            ld a,(scen_mix)
            or a
            ret z
            ld c,a
            ; pick a type allowed by the mix (1 lolly, 2 column, 4 bush)
.pick:      call random
            and 3
            jr z,.pick
            cp 3
            jr nz,.p2
            ld a,4
.p2:        and c
            jr z,.pick
            ld b,a
            push bc
            call obj_alloc
            pop bc
            ret c
            ld (ix+O_KIND),K_SCEN
            ld (ix+O_FLAGS),F_WORLD|F_OBST|F_SHOOT
            ld (ix+O_HP),3          ; tall scenery: three hits
            ld (ix+O_PTS),3
            ld (ix+O_Z),LOW(2000)
            ld (ix+O_Z+1),HIGH(2000)
            ld a,(W_SCN)
            ld (ix+O_HR),a
            ld a,(W_SCN+1)
            ld (ix+O_BY),a          ; obstacle height
            ld a,b
            ld e,S_SCENA
            cp 1
            jr z,.t
            ld a,(W_SCN+2)
            ld (ix+O_HR),a
            ld a,(W_SCN+3)
            ld (ix+O_BY),a
            ld e,S_SCENB
            ld (ix+O_FLAGS),F_WORLD|F_OBST|F_SHOOT
            ld (ix+O_HP),4          ; takes four hits
            ld (ix+O_PTS),5
            ld a,b
            cp 2
            jr z,.t
            ld e,S_SCENC
            ld (ix+O_FLAGS),F_WORLD|F_SHOOT
            ld (ix+O_BY),26         ; small: shootable up to this height
            ld (ix+O_HP),1
            ld (ix+O_PTS),2
.t:         ld (ix+O_SPR),e
            ; x: anywhere +-510 around the camera, but columns keep off
            ; the hero's lane now and then so the way is never blocked
            call random
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            ld de,-510
            add hl,de
            ld de,(camx)
            add hl,de
            ld (ix+O_X),l
            ld (ix+O_X+1),h
            ret

; project every object and file the visible ones into depth buckets
; (zindex / 4: 16-unit steps near the hero, 64-unit steps far away)
NBKT        equ 56
project_all:
            ld hl,bkt
            ld de,bkt+1
            ld bc,NBKT-1
            ld (hl),0
            ldir
            ld ix,objs
            ld b,NOBJ
            ld c,1                  ; object index + 1
.l:         push bc
            ld a,(ix+O_KIND)
            or a
            jr z,.n
            call project
            ld a,(ix+O_VIS)
            or a
            jr z,.n
            pop bc
            push bc
            ld a,(pj_zi)
            rrca
            rrca
            and 63
            cp NBKT
            jr c,.bk
            ld a,NBKT-1
.bk:        ld e,a
            ld d,0
            ld hl,bkt
            add hl,de
            ld a,(hl)
            ld (ix+O_AUX),a
            ld (hl),c
.n:         ld de,OSIZE
            add ix,de
            pop bc
            inc c
            djnz .l
            ret

; the hero and his shadow
draw_hero:
            ld a,(inv)
            or a
            jr z,.vis
            ld b,a
            ld a,(dt)
            ld c,a
            ld a,b
            sub c
            jr nc,.i
            xor a
.i:         ld (inv),a
            ld a,(anim)
            and 2
            ret nz                  ; flicker while invulnerable
.vis:
            ld hl,(hsx)
            ld (spr_x),hl
            ld a,(hz)
            add a,38
            ld l,a
            ld h,0
            ld (spr_y),hl
            ld a,T_SHADOW
            ld b,0
            ld c,2
            ld a,(py)
            cp 40
            jr c,.s
            inc c
.s:         ld a,T_SHADOW
            call spr_rec
            call draw_sprite
            ld hl,(hsx)
            ld (spr_x),hl
            ld hl,(hsy)
            ld (spr_y),hl
            ld a,(force_pose)       ; (struck down / celebrating)
            or a
            jr nz,.fp
            ld a,(hpose)
.fp:        ld b,a
            ld c,0
            ld a,T_HERO
            call spr_rec
            jp draw_sprite

hud_draw_m:
            call to_fe
            dw hud_draw
            ret
