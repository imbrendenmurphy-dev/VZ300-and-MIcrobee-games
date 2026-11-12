; =====================================================================
;  SKYLARKIN' stage 3 overlay: BIG THINGS HIGHWAY. Fly swarms, bounding
;  roos, emus, tumbleweeds, galahs, the road train (HONK HONK!) and
;  THE BIG PRAWN: it does a tail flip across the screen, and is so dizzy
;  afterwards that its head is open to fire.   VIBED BY BPM 2026
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

E_FLY       equ 1
E_ROO       equ 2
E_EMU       equ 3
E_WEED      equ 4
E_GALAH     equ 5
E_RGALAH    equ 6
E_CAB       equ 7
E_TRAILER   equ 8
E_LOB       equ 9

etype_tab:
        dw 0 : db 0,1,0,1,8,8 : dw 0
        dw en_fly     : db SF_FLY0,2,GREY,1,4,4 : dw $0005
        dw en_roo     : db SF_ROO0,2,BROWN,3,12,12 : dw $0030
        dw en_emu     : db SF_EMU0,2,GREY,3,10,11 : dw $0030
        dw en_bubble  : db SF_WEED,1,YELLOW,1,10,7 : dw $0010
        dw en_line    : db SF_GALAH0,2,BMAGENTA,1,12,6 : dw $0015
        dw en_line    : db SF_GALAH0,2,BRED,2,12,6 : dw $0020
        dw en_truck   : db SF_CAB,1,BRED,99,22,10 : dw $0000
        dw en_truck   : db SF_TRAILER,1,WHITE,99,22,10 : dw $0000
        dw en_lob     : db SF_GLOB,1,BMAGENTA,1,4,4 : dw $0005

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
        dw wv_flies,wv_roos,wv_emus,wv_weed,wv_galahs,wv_truck,wv_rgalah

; a cloud of flies: they buzz round the pilot for a while
wv_flies:
        ld b,6
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,320
        add hl,de
        ld a,b
        add a,a
        add a,a
        ld c,a
        ld a,(wv_yv)
        add a,32+10
        add a,c
        ld c,a
        ld a,E_FLY
        call en_new
        jr c,.n
        ld (ix+E_DXH),$FE
.n:     pop bc
        djnz .l
        ret

; roos bounding along
wv_roos:
        ld b,2
.l:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a                 ; 64 px apart
        ld l,a
        ld h,0
        ld de,280
        add hl,de
        ld c,32+140
        ld a,E_ROO
        call en_new
        jr c,.n
        ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FD
.n:     pop bc
        djnz .l
        ret

; emus: run in, stop, peck pellets at you, run off
wv_emus:
        ld b,2
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
        ld c,32+140
        ld a,E_EMU
        call en_new
        jr c,.n
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,150
        ld (ix+E_P1),a          ; where it stops
.n:     pop bc
        djnz .l
        ret

; a tumbleweed: there's a bell in it
wv_weed:
        ld hl,328
        ld a,(wv_yv)
        add a,32
        ld c,a
        ld a,E_WEED
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_BELL
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FE
        ld (ix+E_DYH),$FE
        ret

; a V of galahs (all of them: a capsule)
wv_galahs:
        ld b,5
        call new_group
        ld hl,vform3
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
        ld a,E_GALAH
        call en_new
        jr c,.n
        ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FD
.n:     pop hl
        pop bc
        djnz .l
        ret
vform3: db 0,0, 14,-12, 14,12, 28,-24, 28,24

; a red galah: it drops a capsule
wv_rgalah:
        ld hl,328
        ld a,(wv_yv)
        add a,32
        ld c,a
        ld a,E_RGALAH
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_CAPS
        ld (ix+E_DXH),$FD
        ret

; the road train: a warning first (HONK HONK), then it thunders through
wv_truck:
        ld a,(truck_t)
        or a
        ret nz
        ld a,50
        ld (truck_t),a
        ret

; called every frame (from boss_update): the road train's countdown
truck_tick:
        ld a,(truck_t)
        or a
        ret z
        dec a
        ld (truck_t),a
        jr z,.go
        cp 10
        jr c,.q
        ld b,a
        ld a,1
        ld (warn_msg),a
        ld a,b
        and 15
        ld a,SFX_HONK
        call z,play_sfx
        ret
.q:     ld a,(warn_msg)
        or a
        ret z
        xor a
        ld (warn_msg),a
        inc a
        ld (hud_dirty),a
        ret
.go:    ld a,1
        ld (hud_dirty),a
        ld hl,330
        ld c,32+152
        ld a,E_CAB
        call en_new
        jr c,.t1
        ld (ix+E_FLAGS),EF_SHIELD
.t1:    ld hl,354
        ld c,32+152
        ld a,E_TRAILER
        call en_new
        jr c,.t2
        ld (ix+E_FLAGS),EF_SHIELD
.t2:    ld hl,378
        ld c,32+152
        ld a,E_TRAILER
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_SHIELD
        ld a,SFX_HONK
        jp play_sfx
truck_t:    db 0

; ---------------------------------------------------------------------
; behaviours
; a fly: buzzes at the pilot, jittering, then gives up and goes
en_fly:
        ld a,(ix+E_T)
        cp 200
        jr c,.buzz
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FC
        ld (ix+E_DYL),$00
        ld (ix+E_DYH),$FF
        jp en_move
.buzz:  call random
        and $3F
        sub $20
        ld c,a                  ; jitter
        ; x: towards the pilot
        ld hl,(px)
        ld de,8
        add hl,de
        ld e,(ix+E_XL)
        ld d,(ix+E_XH)
        or a
        sbc hl,de
        ld a,$C0
        ld b,$FE
        jr c,.xl
        ld a,$40
        ld b,$01
.xl:    add a,c
        ld (ix+E_DXL),a
        ld (ix+E_DXH),b
        ld a,(py)
        add a,4
        cp (ix+E_Y)
        ld a,$40
        ld b,$01
        jr nc,.yd
        ld a,$C0
        ld b,$FE
.yd:    add a,c
        ld (ix+E_DYL),a
        ld (ix+E_DYH),b
        jp en_move

; a roo: big bounds along the ground
en_roo:
        call en_move
        ld a,(ix+E_DYL)
        add a,$28
        ld (ix+E_DYL),a
        jr nc,.g
        inc (ix+E_DYH)
.g:     ld a,(ix+E_DYH)
        bit 7,a
        ret nz
        call ground_y
        sub 12
        cp (ix+E_Y)
        ret nc
        ld (ix+E_Y),a           ; landed: and up again
        ld (ix+E_DYL),$80
        ld (ix+E_DYH),$FB       ; -4.5
        ld (ix+E_ANIM),0
        ret

; A = the ground's biased y under enemy IX
ground_y:
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld de,6
        add hl,de
        ld a,h
        cp 2
        jr nc,.r
        bit 7,h
        jr nz,.r
        srl h
        rr l
        ld a,l
        call floor_at
        add a,32
        ret
.r:     ld a,32+160
        ret

; an emu: runs in on the ground, stops, pecks twice, runs off
en_emu: call ground_y
        sub 11
        ld (ix+E_Y),a
        ld a,(ix+E_ST)
        or a
        jr nz,.s
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FC
        call en_move
        ld a,(ix+E_XH)
        or a
        ret nz
        ld a,(ix+E_XL)
        cp (ix+E_P1)
        ret nc
        ld (ix+E_ST),1
        ld (ix+E_T),0
        ret
.s:     cp 1
        jr nz,.run
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FE       ; stands still on the moving ground
        call en_move
        ld a,(ix+E_T)
        cp 16
        jr z,.peck
        cp 36
        jr z,.peck
        cp 50
        ret c
        ld (ix+E_ST),2
        ret
.peck:  ld a,SFX_SNAP
        call play_sfx
        jp en_aim
.run:   ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FA
        jp en_move

; the road train: straight through at speed (shots bounce off it)
en_truck:
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$F9       ; -7
        jp en_move

; a flipped snag: arcs over and bursts on the sand
en_lob:
        call en_move
        ld a,(ix+E_DYL)
        add a,$1C
        ld (ix+E_DYL),a
        jr nc,.g
        inc (ix+E_DYH)
.g:     ld a,(ix+E_DYH)
        bit 7,a
        ret nz                  ; still going up
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld de,6
        add hl,de
        ld a,h
        cp 2
        jr nc,.low
        srl h
        rr l
        ld a,l
        call floor_at
        add a,32-4
        jr .t
.low:   ld a,32+178
.t:     cp (ix+E_Y)
        ret nc
        ; burst: three pellets up and out
        ld (ix+E_TYPE),0
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld a,(ix+E_Y)
        ld c,a
        ld de,$E0F0
        call bullet_new
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld a,(ix+E_Y)
        ld c,a
        ld de,$E010
        call bullet_new
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld a,(ix+E_Y)
        ld c,a
        ld de,$E800
        call bullet_new
        ld a,SFX_POP
        jp play_sfx

; on_kill: nothing special here
on_kill:
        xor a
        ret

; =====================================================================
; THE BIG PRAWN
; =====================================================================
BS_ENTER    equ 0
BS_SAUCE    equ 1
BS_WARN     equ 2
BS_SWEEP    equ 3
BS_CURL     equ 4
BS_DASH     equ 5
BS_DIZZY    equ 6
BS_DIE      equ 7
BC_WARN     equ 4

boss_start:
        ld a,1
        ld (boss_on),a
        ld a,GS_BOSS
        ld (gstate),a
        ld hl,336
        ld (boss_x),hl
        ld a,32+60
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
boss_hps:   db 40,52,70

boss_update:
        call truck_tick
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
.jt:    dw cb_enter,cb_sauce,cb_warn,cb_sweep,cb_curl,cb_dash,cb_dizzy,cb_die

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
        ld a,BS_SAUCE
        jr cb_next

cb_bob: ld a,(py)
        sub 30
        jr nc,cb_to
        xor a
cb_to:  cp 32+4
        jr nc,.a
        ld a,32+4
.a:     cp 32+110
        jr c,.b
        ld a,32+110
.b:     ld hl,boss_y
        cp (hl)
        ret z
        jr c,.u
        inc (hl)
        ret
.u:     dec (hl)
        ret

; cocktail sauce: globs lobbed at the pilot
cb_sauce:
        xor a
        ld (boss_var),a
        ld a,(boss_t)
        and 1
        call z,cb_bob
        ld a,(boss_t)
        and 15
        cp 6
        jr nz,.t
        ld hl,(boss_x)
        ld de,8
        add hl,de
        ld a,(boss_y)
        add a,26
        ld c,a
        ld a,E_LOB
        call en_new
        jr c,.t
        call random
        and $7F
        neg
        ld (ix+E_DXL),a
        ld (ix+E_DXH),$FD
        ld (ix+E_DYL),$80
        ld (ix+E_DYH),$FC
        ld a,SFX_SPIT
        call play_sfx
.t:     ld a,(boss_t)
        cp 80
        ret c
        ld a,(boss_n)
        and 1
        ld a,BS_WARN
        jr z,.w
        ld a,BS_CURL
.w:     jp cb_next

; the antennae glow, line up on you, then sweep
cb_warn:
        ld a,1
        ld (boss_var),a
        ld a,(boss_t)
        cp 24
        call c,cb_aim
        ld a,(boss_t)
        and 4
        ld a,YELLOW
        jr z,.c
        ld a,WHITE
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
        ld a,YELLOW
        ld (boss_pal+BC_WARN),a
        ld a,SFX_BEAM
        call play_sfx
        ld a,BS_SWEEP
        jp cb_next
cb_aim: ld a,(py)
        sub 30
        jr nc,$+3
        xor a
        jp cb_to

; the sweep: a band at the lower antenna's height, right across
cb_sweep:
        ld a,(boss_t)
        and 7
        ld a,SFX_BEAM
        call z,play_sfx
        ld a,(pdead)
        or a
        jr nz,.t
        ld a,(boss_y)
        add a,34
        ld b,a
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
        ld a,BS_SAUCE
        jp cb_next

; it curls up and shakes (TAIL FLIP!) - get out of its row
cb_curl:
        ld a,2
        ld (boss_var),a
        ld (warn_msg),a
        ld a,(boss_t)
        cp 20
        call c,cb_aim
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
        and 7
        ld a,SFX_ALARM
        call z,play_sfx
        ld a,(boss_t)
        cp 44
        ret c
        ld hl,232
        ld (boss_x),hl
        ld a,SFX_BEAM
        call play_sfx
        ld a,BS_DASH
        jp cb_next

; the dash: across to the left edge and back
cb_dash:
        ld a,(boss_jam)         ; 0 going, 1 coming back
        or a
        jr nz,.back
        ld hl,(boss_x)
        ld de,-10
        add hl,de
        ld (boss_x),hl
        ld de,8
        or a
        sbc hl,de
        ret nc
        ld hl,8
        ld (boss_x),hl
        ld a,1
        ld (boss_jam),a
        ld a,SFX_BOOM
        call play_sfx
        ld a,1
        ld (shake_off),a
        ret
.back:  xor a
        ld (shake_off),a
        ld hl,(boss_x)
        ld de,4
        add hl,de
        ld (boss_x),hl
        ld de,232
        or a
        sbc hl,de
        ret c
        ld hl,232
        ld (boss_x),hl
        xor a
        ld (boss_jam),a
        ld (warn_msg),a
        ld a,1
        ld (hud_dirty),a
        ld a,BS_DIZZY
        jp cb_next

; dizzy: stars round its head - the head is open to fire
cb_dizzy:
        ld a,3
        ld (boss_var),a
        ld a,(boss_t)
        and 15
        ld a,SFX_DONG
        call z,play_sfx
        ld a,(boss_t)
        cp 100
        ret c
        ld hl,boss_n
        inc (hl)
        ld a,BS_SAUCE
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
        ld de,$2500
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

; shot IX against the prawn: the head while it's dizzy, otherwise it bounces off
shot_boss:
        ld a,(boss_st)
        cp BS_ENTER
        ret z
        cp BS_DIE
        ret z
        ; the head: x+2..x+26, y+16..y+42
        ld de,2*256+26
        ld bc,16*256+42
        call setbox
        call sbox
        jr nc,.body
        ld a,(boss_st)
        cp BS_DIZZY
        jr z,.hot
.tk:    ld a,SFX_TINK
        call play_sfx
        jr .spend
.body:  ld de,24*256+80
        ld bc,8*256+56
        call setbox
        call sbox
        ret nc
        jr .tk
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
        ld a,(boss_st)
        cp BS_DIZZY
        jr z,.f
        srl e
        ret z
.f:     jp boss_hurt

boss_touch:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_DIE
        ret z
        ld hl,(boss_x)
        ld de,8+16
        add hl,de
        call hx
        ld c,a
        ld a,(hx1)
        cp c
        ret c
        ld a,c
        add a,34
        ld c,a
        ld a,(hx0)
        cp c
        ret nc
        ld a,(boss_y)
        add a,12
        ld c,a
        ld a,(hy1)
        cp c
        ret c
        ld a,(boss_y)
        add a,54
        ld c,a
        ld a,(hy0)
        cp c
        ret nc
        jp hit_player

; the antenna sweep, drawn with the small objects
draw_boss_objs:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_SWEEP
        ret nz
        ld a,(boss_y)
        add a,35-24
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(ticks)
        and 2
        ld a,YELLOW
        jr z,.c
        ld a,WHITE
.c:     ld (spr_ink),a
        ld hl,(boss_x)
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

warn1:      db "!! HONK HONK !! ",0
warn2:      db "! TAIL FLIP !   ",0
ovl_end:
        ASSERT ovl_end <= OVL_END
        SAVEBIN "../build/OVL3.BIN",OVL,ovl_end-OVL
        DISPLAY "stage 3 overlay end: ",ovl_end
