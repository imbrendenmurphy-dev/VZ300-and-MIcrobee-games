; =====================================================================
;  SKYLARKIN' stage 1 overlay: OPEN PLAN. Enemy types, waves, the
;  COPYTRON 9000. Assembled at OVL against the main program symbols;
;  copied to OVL when the stage loads.   VIBED BY BPM 2026
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "../build/main.equ"
        ORG OVL
        jp wave_start
        jp boss_start
        jp boss_update
        jp shot_boss
        jp boss_area
        jp boss_touch
        jp draw_boss_objs
        jp on_kill
        dw warn1,warn2
        ds OVL+32-$
E_PLANE     equ 1
E_SHEET     equ 2
E_STAPLER   equ 3
E_MUG       equ 4
E_CHAIR     equ 5
E_PRINTER   equ 6
E_BALLOON   equ 7
E_BUBBLE    equ 8
E_SWARM     equ 9
E_CRUMPLE   equ 10
E_RPLANE    equ 11

etype_tab:
        dw 0 : db 0,1,0,1,8,8 : dw 0
        dw en_line    : db SF_PLANE0,2,WHITE,1,12,6 : dw $0010
        dw en_sine    : db SF_SHEET0,2,WHITE,1,8,7 : dw $0010
        dw en_hover   : db SF_STAPLER0,2,BRED,3,12,8 : dw $0030
        dw en_mug     : db SF_MUG0,2,BROWN,2,10,10 : dw $0020
        dw en_chair   : db SF_CHAIR0,2,GREY,4,14,12 : dw $0030
        dw en_turret  : db SF_PRINTER0,2,WHITE,6,14,8 : dw $0050
        dw en_balloon : db SF_BALLOON,1,BMAGENTA,1,10,9 : dw $0010
        dw en_bubble  : db SF_BUBBLE,1,BCYAN,1,6,5 : dw $0005
        dw en_swarm   : db SF_SHEET0,2,WHITE,1,8,7 : dw $0001
        dw en_crumple : db SF_CRUMPLE,1,WHITE,99,5,5 : dw $0000
        dw en_line    : db SF_PLANE0,2,BRED,2,12,6 : dw $0020


wave_start:
        ld (wv_y),a
        ld a,c
        ld (wv_yv),a
        ld a,(wv_y)
        add a,a
        ld l,a
        ld h,0
        ld de,wave_jt
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        xor a
        ld (cur_grp),a
        jp (hl)
wave_jt:
        dw wv_vplanes,wv_snake,wv_staplers,wv_mugs,wv_chairs,wv_printer,wv_balloon,wv_bubbles,wv_carrier

; a formation: (cur_grp) = a fresh group of B enemies
wv_vplanes:
        ld b,5
        call new_group
        ld hl,vform
        ld b,5
.l:     push bc
        ld e,(hl)
        inc hl
        ld a,(wv_yv)
        add a,32
        add a,(hl)
        inc hl
        push hl
        ld c,a
        ld l,e
        ld h,0
        ld de,328
        add hl,de
        ld a,E_PLANE
        call en_new
        jr c,.n
        ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FD       ; -2.5
        ld a,(ix+E_Y)
        ld (ix+E_P1),a
.n:     pop hl
        pop bc
        djnz .l
        ret
vform:  db 0,0, 14,-12, 14,12, 28,-24, 28,24

wv_snake:
        ld b,6
        call new_group
        ld b,6
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a                 ; 16 px apart
        ld l,a
        ld h,0
        ld de,312
        add hl,de
        ld a,(wv_yv)
        add a,32
        ld c,a
        ld a,E_SHEET
        call en_new
        jr c,.n
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FE       ; -2
        ld a,(ix+E_Y)
        ld (ix+E_P1),a          ; the middle line
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        ld (ix+E_T),a           ; phase
.n:     pop bc
        djnz .l
        ret

wv_staplers:
        ld b,3
.l:     push bc
        ld a,b
        dec a
        ld c,a
        add a,a
        add a,c                 ; 0, 3, 6
        add a,a
        add a,a
        add a,a                 ; *8: 0, 24, 48
        ld c,a
        ld a,(wv_yv)
        cp 100
        jr c,.y
        ld a,100
.y:     add a,32
        add a,c
        ld c,a
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,320
        add hl,de
        ld a,E_STAPLER
        call en_new
        jr c,.n
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,196               ; where it stops
        ld (ix+E_P1),a
        ld (ix+E_FIRE),20
.n:     pop bc
        djnz .l
        ret

wv_mugs:
        ld b,3
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a                 ; 32 px apart
        ld l,a
        ld h,0
        ld de,300
        add hl,de
        ld a,b
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,(wv_yv)
        cp 90
        jr c,.y
        ld a,90
.y:     add a,32
        add a,c
        ld c,a
        ld a,E_MUG
        call en_new
        jr c,.n
        ld (ix+E_DXL),$C0
        ld (ix+E_DXH),$FE       ; -1.25
        ld a,(ix+E_Y)
        ld (ix+E_P1),a
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld (ix+E_FIRE),a
.n:     pop bc
        djnz .l
        ret

wv_chairs:
        ld b,2
.l:     push bc
        ld a,b
        dec a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a                 ; 0 or 64
        ld l,a
        ld h,0
        ld de,330
        add hl,de
        ld c,32+160
        ld a,E_CHAIR
        call en_new
        jr c,.n
        ld (ix+E_DXH),$FC       ; -4
.n:     pop bc
        djnz .l
        ld a,(difficulty)
        or a
        ret z
        ; one sneaks up from behind
        ld hl,-16
        ld c,32+160
        ld a,E_CHAIR
        call en_new
        ret c
        ld (ix+E_DXH),$02
        ld (ix+E_P2),1
        ret

wv_printer:
        ld hl,332
        ld c,32+150
        ld a,E_PRINTER
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_CAPS
        ld (ix+E_FIRE),40
        ret

wv_balloon:
        ld hl,328
        ld a,(wv_yv)
        add a,32+40
        cp 32+150
        jr c,.y
        ld a,32+150
.y:     ld c,a
        ld a,E_BALLOON
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_BELL
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FF       ; -1
        ld (ix+E_DYL),$B0
        ld (ix+E_DYH),$FF       ; floats up
        ret

wv_bubbles:
        ld b,4
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,220
        add hl,de
        ld c,32+170
        ld a,E_BUBBLE
        call en_new
        jr c,.n
        ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FE
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        neg
        ld (ix+E_DYL),a
        ld (ix+E_DYH),$FC       ; jumps up
.n:     pop bc
        djnz .l
        ret

wv_carrier:
        ld hl,328
        ld a,(wv_yv)
        add a,32
        ld c,a
        ld a,E_RPLANE
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_CAPS
        ld (ix+E_DXH),$FD       ; -3
        ld a,(ix+E_Y)
        ld (ix+E_P1),a
        ret


en_swarm:                       ; the copier's paper: flutters at the pilot
        ld a,(ix+E_T)
        and 7
        jr nz,.m
        ld a,(py)
        add a,4
        cp (ix+E_Y)
        ld a,$60
        jr nc,.d
        ld a,$A0
.d:     ld (ix+E_DYL),a
        add a,a
        sbc a,a
        ld (ix+E_DYH),a
.m:     jp en_move

en_crumple:                     ; screwed-up paper flying back into the copier
        ld (ix+E_DXL),0
        ld (ix+E_DXH),6
        call en_move
        ld a,(boss_on)
        or a
        ret z
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld de,(boss_x)
        or a
        sbc hl,de
        ret c
        ld (ix+E_TYPE),0        ; swallowed
        ld hl,boss_jam
        inc (hl)
        ld a,SFX_GULP
        jp play_sfx

; en_aim: an aimed pellet from enemy IX
; on_kill: IX = an enemy shot down. NZ if the stage handled it.
on_kill:
        ld a,(ix+E_TYPE)
        cp E_SWARM
        jr nz,.no
        ; a sheet of copier paper: screwed up, it flies back at the copier
        ld (ix+E_TYPE),E_CRUMPLE
        ld (ix+E_HP),99
        ld (ix+E_FLAGS),EF_SHIELD
        ld a,SFX_CRUMPLE
        call play_sfx
        or 1
        ret
.no:    xor a
        ret

BS_ENTER    equ 0
BS_SPIT     equ 1
BS_SHOOT    equ 2
BS_WARN     equ 3
BS_FIRE     equ 4
BS_JAM      equ 5
BS_DIE      equ 6
BC_WARN     equ 4


boss_start:
        ld a,1
        ld (boss_on),a
        ld a,GS_BOSS
        ld (gstate),a
        ld hl,336
        ld (boss_x),hl
        ld a,32+70
        ld (boss_y),a
        xor a
        ld (boss_var),a
        ld (boss_st),a
        ld (boss_jam),a
        ld (boss_n),a
        ld (boss_flash),a
        ld hl,0
        ld (boss_t),hl
        ld a,(difficulty)
        ld e,a
        ld d,0
        ld hl,boss_hps
        add hl,de
        ld a,(hl)
        ld l,a
        ld h,0
        ld (boss_hp),hl
        ld (boss_hpmax),hl
        ld a,1
        ld (hud_dirty),a
        call stop_music
        ld hl,mus_boss_0
        ld de,mus_boss_1
        call play_music
        ld a,SFX_ALARM
        jp play_sfx
boss_hps:   db 36,48,64

; ---------------------------------------------------------------------
boss_update:
        ld a,(boss_on)
        or a
        ret z
        ld hl,(boss_t)
        inc hl
        ld (boss_t),hl
        ld a,(boss_flash)
        or a
        jr z,.f
        dec a
        ld (boss_flash),a
.f:     ld a,(boss_st)
        add a,a
        ld l,a
        ld h,0
        ld de,.jt
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
.jt:    dw cb_enter,cb_spit,cb_shoot,cb_warn,cb_fire,cb_jam,cb_die

cb_next:                        ; A = the next state
        ld (boss_st),a
        ld hl,0
        ld (boss_t),hl
        ret

cb_enter:
        ld hl,(boss_x)
        dec hl
        dec hl
        ld (boss_x),hl
        ld de,232
        or a
        sbc hl,de
        ret nz
        ld a,BS_SPIT
        jr cb_next

; follow the pilot up and down (slowly)
cb_bob: ld a,(py)
        sub 30
        cp 32
        jr nc,.a
        ld a,32
.a:     cp 32+104
        jr c,.b
        ld a,32+104
.b:     ld hl,boss_y
        cp (hl)
        ret z
        jr c,.u
        inc (hl)
        ret
.u:     dec (hl)
        ret

cb_spit:
        ld a,1
        ld (boss_var),a
        ld a,(boss_t)
        and 1
        call z,cb_bob
        ld a,(boss_t)
        and 7
        jr nz,.t
        ld a,SFX_SPIT
        call play_sfx
        ld hl,(boss_x)
        ld de,-4
        add hl,de
        ld a,(boss_y)
        add a,28
        ld c,a
        ld a,E_SWARM
        call en_new
        jr c,.t
        ld (ix+E_DXL),$60
        ld (ix+E_DXH),$FD       ; -2.6
.t:     ld a,(boss_t)
        cp 64
        ret c
        ld a,BS_SHOOT
        jr cb_next

cb_shoot:
        xor a
        ld (boss_var),a
        ld a,(boss_t)
        and 1
        call z,cb_bob
        ld a,(boss_t)
        and 15
        cp 8
        jr nz,.t
        ; both eyes fire
        ld hl,(boss_x)
        ld de,24
        add hl,de
        ld a,(boss_y)
        add a,26
        ld c,a
        call bullet_aimed
        ld a,(difficulty)
        or a
        jr z,.t
        ld hl,(boss_x)
        ld de,40
        add hl,de
        ld a,(boss_y)
        add a,26
        ld c,a
        call bullet_aimed
.t:     ld a,(boss_t)
        cp 48
        ret c
        ld a,(boss_jam)
        cp 3
        jr nc,.jam
        ld a,(boss_n)
        cp 3
        jr nc,.jam
        ld a,BS_WARN
        jp cb_next
.jam:   ld a,SFX_JAM
        call play_sfx
        ld a,BS_JAM
        jp cb_next

cb_warn:
        ld a,2
        ld (boss_var),a
        ld a,(boss_t)
        cp 24
        call c,cb_aim
        ld a,(boss_t)
        and 4
        ld a,RED
        jr z,.c
        ld a,YELLOW
.c:     ld (boss_pal+BC_WARN),a
        ld a,(boss_t)
        and 7
        ld a,SFX_ALARM
        call z,play_sfx
        ld a,1
        ld (warn_msg),a
        ld a,(boss_t)
        cp 40
        ret c
        ld a,RED
        ld (boss_pal+BC_WARN),a
        ld a,SFX_BEAM
        call play_sfx
        ld a,BS_FIRE
        jp cb_next
; line the mouth up with the pilot
cb_aim: ld a,(py)
        sub 34
        jp cb_bob.a

cb_fire:
        ld a,(boss_t)
        and 7
        ld a,SFX_BEAM
        call z,play_sfx
        ; the beam: mouth row, the whole way left
        ld a,(pdead)
        or a
        jr nz,.t
        ld a,(boss_y)
        add a,37
        ld b,a                  ; beam top
        ld a,(py)
        add a,9
        cp b
        jr c,.t
        ld a,b
        add a,6
        ld c,a
        ld a,(py)
        add a,4
        cp c
        jr nc,.t
        call hit_player
.t:     ld a,(boss_t)
        cp 30
        ret c
        xor a
        ld (warn_msg),a
        ld a,1
        ld (hud_dirty),a
        ld hl,boss_n
        inc (hl)
        ld a,BS_SPIT
        jp cb_next

cb_jam:
        ld a,3
        ld (boss_var),a
        ; it shakes and smokes
        ld a,(boss_t)
        and 1
        ld hl,(boss_x)
        jr z,.l
        inc hl
        inc hl
        jr .s
.l:     dec hl
        dec hl
.s:     ld (boss_x),hl
        ld a,(boss_t)
        and 15
        jr nz,.t
        ld hl,(boss_x)
        ld de,30
        add hl,de
        ld a,(boss_y)
        sub 8
        ld c,a
        call fx_boom
.t:     ld a,(boss_t)
        cp 80
        ret c
        ld hl,232
        ld (boss_x),hl
        xor a
        ld (boss_jam),a
        ld (boss_n),a
        ld a,BS_SPIT
        jp cb_next

cb_die: ld a,(boss_t)
        and 3
        jr nz,.t
        call random
        and 63
        ld e,a
        ld d,0
        ld hl,(boss_x)
        add hl,de
        push hl
        call random
        and 63
        ld c,a
        ld a,(boss_y)
        add a,c
        sub 8
        ld c,a
        pop hl
        call fx_boom
        ld a,SFX_BOOM
        call play_sfx
        ld a,(boss_t)
        and 8
        ld a,1
        jr z,.k
        xor a
.k:     ld (shake_off),a
.t:     ld a,(boss_t)
        cp 75
        ret c
        xor a
        ld (boss_on),a
        ld (shake_off),a
        ld a,GS_CLEAR
        ld (gstate),a
        ret

; ---------------------------------------------------------------------
; boss_hurt: E = damage
boss_hurt:
        ld a,(boss_st)
        cp BS_DIE
        ret z
        cp BS_ENTER
        ret z
        ld hl,(boss_hp)
        ld d,0
        or a
        sbc hl,de
        jr z,.dead
        jr c,.dead
        ld (boss_hp),hl
        ld a,3
        ld (boss_flash),a
        ld a,1
        ld (hud_dirty),a
        ld a,SFX_BOSSHIT
        jp play_sfx
.dead:  ld hl,0
        ld (boss_hp),hl
        ld a,1
        ld (hud_dirty),a
        ld de,$2000
        call add_score
        xor a
        ld (warn_msg),a
        ld a,BS_DIE
        jp cb_next

; the body: x+16..x+80, y+10..y+64 (half x biased by 8 like the shots)
; the jam: x+0..x+36, y+42..y+58 (only while jammed)
shot_boss:
        ld a,(boss_on)
        or a
        ret z
        ld hl,(boss_x)
        ld de,16+16
        add hl,de
        call .hx
        ld c,a                  ; body x0
        ld a,(sx1)
        cp c
        jr c,.jam
        ld a,(boss_y)
        add a,10
        ld c,a
        ld a,(sy1)
        cp c
        jr c,.jam
        add a,0
        ld a,(boss_y)
        add a,64
        ld c,a
        ld a,(sy0)
        cp c
        jr nc,.jam
        ; the body: shots are swallowed (beams go on)
        call .weak
        ret c
        ld a,(ix+0)
        cp ST_BEAM
        ret z
        ld (ix+0),0
        ld a,SFX_TINK
        jp play_sfx
.jam:   call .weak
        ret
; a hit on the jam? -> C (and the damage done)
.weak:  ld a,(boss_st)
        cp BS_JAM
        jr nz,.no
        ld hl,(boss_x)
        ld de,16
        add hl,de
        call .hx
        ld c,a
        ld a,(sx1)
        cp c
        jr c,.no
        ld a,c
        add a,18
        ld c,a
        ld a,(sx0)
        cp c
        jr nc,.no
        ld a,(boss_y)
        add a,42
        ld c,a
        ld a,(sy1)
        cp c
        jr c,.no
        ld a,c
        add a,16
        ld c,a
        ld a,(sy0)
        cp c
        jr nc,.no
        ld a,(ix+0)
        cp ST_BEAM
        jr nz,.nb
        ld a,(ix+6)
        and 3
        jr nz,.y                ; beams: every fourth frame
.nb:    cp ST_BOMB
        jr nz,.nbo
        call bomb_burst
        scf
        ret
.nbo:   ld a,(ix+0)
        cp ST_BEAM
        jr z,.d
        cp ST_RING
        jr z,.d
        ld (ix+0),0
.d:     ld e,(ix+7)
        call boss_hurt
.y:     scf
        ret
.no:    or a
        ret
.hx:    ld a,h
        cp 2
        ld a,255
        ret nc
        srl h
        rr l
        ld a,l
        ret

; boss_area: E = damage from a blast or a shout (half while not jammed)
boss_area:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_JAM
        jr z,.f
        srl e
        ret z
.f:     jp boss_hurt

; the pilot against the body
boss_touch:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_DIE
        ret z
        ld hl,(boss_x)
        ld de,16+16
        add hl,de
        call shot_boss.hx
        ld c,a
        ld a,(hx1)
        cp c
        ret c
        ld a,(boss_y)
        add a,12
        ld c,a
        ld a,(hy1)
        cp c
        ret c
        ld a,(boss_y)
        add a,62
        ld c,a
        ld a,(hy0)
        cp c
        ret nc
        jp hit_player


; the toner beam (drawn with the small objects)
draw_boss_objs:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_FIRE
        ret nz
        ld a,(boss_y)
        add a,37-24
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(ticks)
        and 2
        ld a,BMAGENTA
        jr z,.c
        ld a,WHITE
.c:     ld (spr_ink),a
        ld hl,(boss_x)
        ld de,16
        add hl,de
        ld a,l
        and $F8
        ld l,a
.l:     ld (spr_x),hl
        push hl
        ld a,K_TONER
        call obj_draw
        pop hl
        ld de,-8
        add hl,de
        bit 7,h
        jr z,.l
        ret

warn1:      db "! TONER LOW !   ",0
warn2:      db "! TONER LOW !   ",0
ovl_end:
        ASSERT ovl_end <= OVL_END
        SAVEBIN "../build/OVL1.BIN",OVL,ovl_end-OVL
        DISPLAY "stage 1 overlay end: ",ovl_end
