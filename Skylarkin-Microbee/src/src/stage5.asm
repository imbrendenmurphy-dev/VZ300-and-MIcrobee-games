; =====================================================================
;  SKYLARKIN' stage 5 overlay: HEAD OFFICE. Middle managers, briefcases,
;  memos, red tape you have to shoot through, shredders, your bonus (in
;  an envelope) and THE CEO: pie charts, the DENIED stamp (it hunts your
;  column, then slams down), and at the end his tie comes undone.
;  VIBED BY BPM 2026
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

E_MANAGER   equ 1
E_BRIEF     equ 2
E_MEMO      equ 3
E_TAPE      equ 4
E_SHRED     equ 5
E_RBRIEF    equ 6
E_ENVELOPE  equ 7
E_PIE       equ 8
E_STAMP     equ 9

etype_tab:
        dw 0 : db 0,1,0,1,8,8 : dw 0
        dw en_hover   : db SF_MANAGER0,2,BBLUE,3,12,12 : dw $0040
        dw en_line    : db SF_BRIEF0,2,BROWN,2,12,7 : dw $0020
        dw en_sine    : db SF_MEMO0,2,WHITE,1,8,6 : dw $0010
        dw en_tape    : db SF_TAPE,1,BRED,2,8,8 : dw $0005
        dw en_turret  : db SF_SHRED0,2,GREY,5,12,6 : dw $0050
        dw en_line    : db SF_BRIEF0,2,BRED,2,12,7 : dw $0020
        dw en_balloon : db SF_ENVELOPE,1,YELLOW,1,10,7 : dw $0010
        dw en_pie     : db SF_PIE,1,BRED,2,8,7 : dw $0010
        dw en_stamp   : db SF_STAMP,1,BRED,99,24,12 : dw $0000

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
        dw wv_managers,wv_briefs,wv_memos,wv_tape,wv_shredder,wv_rbrief,wv_bonus

wv_managers:
        ld b,3
.l:     push bc
        ld a,b
        dec a
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,a
        add a,a                 ; 0, 24, 48
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
        ld a,E_MANAGER
        call en_new
        jr c,.n
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,190
        ld (ix+E_P1),a
        ld (ix+E_FIRE),24
.n:     pop bc
        djnz .l
        ret

; a V of briefcases (all of them: a capsule)
wv_briefs:
        ld b,5
        call new_group
        ld hl,vform5
        ld b,5
.l:     push bc
        ld e,(hl)
        inc hl
        ld a,(wv_yv)
        add a,32+20
        add a,(hl)
        inc hl
        push hl
        ld c,a
        ld l,e
        ld h,0
        ld de,328
        add hl,de
        ld a,E_BRIEF
        call en_new
        jr c,.n
        ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FD
.n:     pop hl
        pop bc
        djnz .l
        ret
vform5: db 0,0, 14,-12, 14,12, 28,-24, 28,24

wv_memos:
        ld b,6
        call new_group
        ld b,6
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,312
        add hl,de
        ld a,(wv_yv)
        add a,32+16
        ld c,a
        ld a,E_MEMO
        call en_new
        jr c,.n
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FD
        ld a,(ix+E_Y)
        ld (ix+E_P1),a
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        ld (ix+E_T),a
.n:     pop bc
        djnz .l
        ret

; red tape: a wall right down the screen - shoot your way through
wv_tape:
        ld b,11
.l:     push bc
        ld a,b
        dec a
        ld c,a
        add a,a
        add a,c                 ; *3
        add a,a
        add a,a                 ; *12
        add a,32+16
        ld c,a
        ld hl,332
        ld a,E_TAPE
        call en_new
.n:     pop bc
        djnz .l
        ret

wv_shredder:
        ld hl,332
        ld c,32+164
        ld a,E_SHRED
        call en_new
        ret c
        ld (ix+E_FIRE),30
        ret

wv_rbrief:
        ld hl,328
        ld a,(wv_yv)
        add a,32
        ld c,a
        ld a,E_RBRIEF
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_CAPS
        ld (ix+E_DXH),$FD
        ret

; YOUR BONUS: an envelope with a bell in it
wv_bonus:
        ld hl,328
        ld a,(wv_yv)
        add a,32+40
        ld c,a
        ld a,E_ENVELOPE
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_BELL
        ld (ix+E_DXH),$FF
        ld (ix+E_DYL),$B0
        ld (ix+E_DYH),$FF
        ret

; ---------------------------------------------------------------------
en_tape:                        ; goes by with the scenery
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FE
        ld a,(scrolling)
        or a
        jr nz,.m
        ld (ix+E_DXH),$FF
.m:     jp en_move

; a pie chart: spins at you, then bursts into three wedges
en_pie: call en_move
        ld a,(ix+E_T)
        cp 30
        ret c
        ld (ix+E_TYPE),0
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld a,(ix+E_Y)
        ld c,a
        push hl
        push bc
        call bullet_aimed
        pop bc
        pop hl
        push hl
        push bc
        ld de,$F0E4
        call bullet_new
        pop bc
        pop hl
        ld de,$10E4
        call bullet_new
        ld a,SFX_POP
        jp play_sfx

; the DENIED stamp: hunts the pilot's column at the top, slams down, lifts off
en_stamp:
        ld a,(ix+E_ST)
        or a
        jr nz,.s1
        ; hunting: flashing, following the pilot's x
        ld a,(ix+E_T)
        and 3
        jr nz,.nf
        ld (ix+E_FLASH),2
.nf:    ld a,(ix+E_T)
        and 7
        ld a,SFX_ALARM
        call z,play_sfx
        ld hl,(px)
        ld de,-4
        add hl,de
        ld e,(ix+E_XL)
        ld d,(ix+E_XH)
        or a
        sbc hl,de
        jr z,.t
        ld bc,3
        jr nc,.r
        ld bc,-3
.r:     ex de,hl
        add hl,bc
        ld (ix+E_XL),l
        ld (ix+E_XH),h
.t:     ld a,(ix+E_T)
        cp 44
        ret c
        ld (ix+E_ST),1
        ret
.s1:    cp 1
        jr nz,.s2
        ld a,(ix+E_Y)           ; slam!
        add a,9
        ld (ix+E_Y),a
        cp 32+168
        ret c
        ld (ix+E_Y),32+168
        ld (ix+E_ST),2
        ld (ix+E_T),0
        ld a,1
        ld (shake_off),a
        ld a,SFX_STAMP
        jp play_sfx
.s2:    cp 2
        jr nz,.s3
        xor a
        ld (shake_off),a
        ld a,(ix+E_T)
        cp 16
        ret c
        ld (ix+E_ST),3
        ret
.s3:    ld a,(ix+E_Y)
        sub 5
        ld (ix+E_Y),a
        cp 32
        ret nc
        ld (ix+E_TYPE),0
        ret

on_kill:
        xor a
        ret

; =====================================================================
; THE CEO
; =====================================================================
BS_ENTER    equ 0
BS_PIES     equ 1
BS_STAMP    equ 2
BS_WARN     equ 3
BS_TIE      equ 4
BS_DIE      equ 5
BC_WARN     equ 4

boss_start:
        ld a,1
        ld (boss_on),a
        ld a,GS_BOSS
        ld (gstate),a
        ld hl,336
        ld (boss_x),hl
        ld a,32+56
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
        ld hl,mus_boss5_0
        ld de,mus_boss5_1
        call play_music
        ld a,SFX_ALARM
        jp play_sfx
boss_hps:   db 70,90,120

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
.jt:    dw cb_enter,cb_pies,cb_stamp,cb_warn,cb_tie,cb_die

cb_next:
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
        ld a,BS_PIES
        jr cb_next

cb_bob: ld a,(py)
        sub 20
        jr nc,cb_to
        xor a
cb_to:  cp 32+4
        jr nc,.a
        ld a,32+4
.a:     cp 32+100
        jr c,.b
        ld a,32+100
.b:     ld hl,boss_y
        cp (hl)
        ret z
        jr c,.u
        inc (hl)
        cp (hl)
        ret z
        inc (hl)
        ret
.u:     dec (hl)
        cp (hl)
        ret z
        dec (hl)
        ret

; the last phase? (hp below a third: the tie comes undone)
last_phase:
        ld hl,(boss_hpmax)
        ld a,l
        ld b,0
.d:     sub 3
        jr c,.k
        inc b
        jr .d
.k:     ld a,(boss_hp)
        cp b
        ret                     ; C: the last phase
; the resting look: 0, or 3 with the tie undone
rest_var:
        call last_phase
        ld a,0
        ret nc
        ld a,3
        ret

; pie charts: four of them, thrown at you
cb_pies:
        call rest_var
        ld (boss_var),a
        ld a,(boss_t)
        and 3
        call z,cb_bob
        ld a,(boss_t)
        and 15
        cp 2
        jr nz,.t
        ld a,1
        ld (boss_var),a
        ld hl,(boss_x)
        ld de,8
        add hl,de
        ld a,(boss_y)
        add a,6
        ld c,a
        ld a,E_PIE
        call en_new
        jr c,.t
        ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FD
        ld a,SFX_SPIT
        call play_sfx
.t:     ld a,(boss_t)
        cp 70
        ret c
        ld a,BS_STAMP
        jp cb_next

; the stamp: DENIED - it comes down where you are
cb_stamp:
        ld a,2
        ld (boss_var),a
        ld a,(boss_t)
        cp 4
        jr nz,.t
        call stamp_new
        ld a,(difficulty)
        cp 2
        jr z,.two
        call last_phase
        jr nc,.t
.two:   ld hl,stamp_x2
        call stamp_new.x
.t:     ld a,(boss_t)
        cp 96
        ret c
        call last_phase
        ld a,BS_WARN
        jr c,.w
        ld a,BS_PIES
.w:     jp cb_next
stamp_new:
        ld hl,(px)
.x:     ld c,32
        ld a,E_STAMP
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_SHIELD
        ret
stamp_x2    equ 40

; the last phase: the tie whips across
cb_warn:
        ld a,3
        ld (boss_var),a
        ld a,(boss_t)
        cp 20
        call c,cb_aim
        ld a,2
        ld (warn_msg),a
        ld a,(boss_t)
        and 7
        ld a,SFX_ALARM
        call z,play_sfx
        ld a,(boss_t)
        cp 36
        ret c
        ld a,SFX_BEAM
        call play_sfx
        ld a,BS_TIE
        jp cb_next
cb_aim: ld a,(py)
        sub 30
        jr nc,$+3
        xor a
        jp cb_to

cb_tie: ld a,(pdead)
        or a
        jr nz,.t
        ld a,(boss_y)
        add a,30
        ld b,a
        ld a,(py)
        add a,9
        cp b
        jr c,.t
        ld a,b
        add a,10
        ld c,a
        ld a,(py)
        add a,4
        cp c
        jr nc,.t
        call hit_player
.t:     ld a,(boss_t)
        cp 24
        ret c
        xor a
        ld (warn_msg),a
        ld a,1
        ld (hud_dirty),a
        ld a,BS_PIES
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
        ld de,$5000
        call add_score
        xor a
        ld (warn_msg),a
        ld a,BS_DIE
        jp cb_next

; half x of HL (biased +16 by the caller) -> A (255 off the right)
hx:     ld a,h
        cp 2
        ld a,255
        ret nc
        srl h
        rr l
        ld a,l
        ret

; the box x+o0..x+o1 (half x), y+v0..y+v1 against the shot box: C if it touches
; (bx0, bx1, by0, by1 set by the caller)
sbox:   ld a,(bx0)
        ld c,a
        ld a,(sx1)
        cp c
        jr c,.miss              ; shot right edge < box left
        ld a,(bx1)
        ld c,a
        ld a,(sx0)
        cp c
        jr nc,.miss
        ld a,(by0)
        ld c,a
        ld a,(sy1)
        cp c
        jr c,.miss
        ld a,(by1)
        ld c,a
        ld a,(sy0)
        cp c
        jr nc,.miss
        scf
        ret
.miss:  or a
        ret
; set bx0/bx1 from boss_x + D .. + E pixels, by0/by1 from boss_y + B .. + C
setbox: push bc
        ld hl,(boss_x)
        ld a,d
        add a,16
        ld c,a
        ld b,0
        add hl,bc
        push de
        call hx
        pop de
        ld (bx0),a
        ld a,e
        sub d
        srl a
        ld hl,bx0
        add a,(hl)
        ld (bx1),a
        pop bc
        ld a,(boss_y)
        add a,b
        ld (by0),a
        ld a,(boss_y)
        add a,c
        ld (by1),a
        ret
bx0:    db 0
bx1:    db 0
by0:    db 0
by1:    db 0

; shot IX against the CEO: his head is the target; the chair and the mech take nothing
shot_boss:
        ld a,(boss_st)
        cp BS_ENTER
        ret z
        cp BS_DIE
        ret z
        ld de,30*256+52
        ld bc,2*256+26
        call setbox
        call sbox
        jr c,.hot
        ld de,10*256+70
        ld bc,0*256+64
        call setbox
        call sbox
        ret nc
        ld a,SFX_TINK
        call play_sfx
        jr .spend
.hot:   ld a,(ix+0)
        cp ST_BEAM
        jr nz,.nb
        ld a,(ix+6)
        and 3
        ret nz
        jr .d
.nb:    cp ST_BOMB
        jr nz,.d
        jp bomb_burst
.d:     ld e,(ix+7)
        call boss_hurt
        ld a,(ix+0)
        cp ST_BEAM
        ret z
        cp ST_RING
        ret z
.spend: ld a,(ix+0)
        cp ST_BEAM
        ret z
        ld (ix+0),0
        ret

boss_area:
        ld a,(boss_on)
        or a
        ret z
        srl e
        ret z
        jp boss_hurt

boss_touch:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_DIE
        ret z
        ld hl,(boss_x)
        ld de,22+16
        add hl,de
        call hx
        ld c,a
        ld a,(hx1)
        cp c
        ret c
        ld a,(boss_y)
        add a,2
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

draw_boss_objs:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_TIE
        ret nz
        ld a,(boss_y)
        add a,32-24
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(ticks)
        and 2
        ld a,BRED
        jr z,.c
        ld a,YELLOW
.c:     ld (spr_ink),a
        ld hl,(boss_x)
        ld de,24
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

warn1:      db "!!! DENIED !!!  ",0
warn2:      db "! TIE UNDONE !  ",0
ovl_end:
        ASSERT ovl_end <= OVL_END
        SAVEBIN "../build/OVL5.BIN",OVL,ovl_end-OVL
        DISPLAY "stage 5 overlay end: ",ovl_end
