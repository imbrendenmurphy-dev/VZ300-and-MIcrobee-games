; =====================================================================
;  SKYLARKIN' stage 2 overlay: BARBIE BEACH. Thongs, seagulls that steal
;  your bell, sizzling snags, crabs, and THE GREAT AUSTRALIAN BARBIE.
;  The joke: shoot its gas bottle until GAS LOW - only then does the
;  barbecue go out and can be hurt.   VIBED BY BPM 2026
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

E_THONG     equ 1
E_GULL      equ 2
E_SNAG      equ 3
E_BALL      equ 4
E_CRAB      equ 5
E_LILO      equ 6
E_SMOKE     equ 7
E_LOB       equ 8

etype_tab:
        dw 0 : db 0,1,0,1,8,8 : dw 0
        dw en_sine    : db SF_THONG0,2,BCYAN,1,12,6 : dw $0010
        dw en_gull    : db SF_GULL0,2,WHITE,2,14,8 : dw $0030
        dw en_snag    : db SF_SNAG0,2,BRED,2,12,5 : dw $0020
        dw en_bubble  : db SF_BALL,1,BMAGENTA,1,10,7 : dw $0010
        dw en_crab    : db SF_CRAB0,2,BRED,3,10,8 : dw $0030
        dw en_line    : db SF_LILO,1,BRED,2,16,4 : dw $0020
        dw en_smoke   : db SF_SMOKE0,2,GREY,99,12,8 : dw $0000
        dw en_lob     : db SF_SNAG0,2,BRED,1,12,5 : dw $0005

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
        dw wv_thongs,wv_gulls,wv_snags,wv_ball,wv_crabs,wv_lilo,wv_flags

; a snake of thongs, flip-flopping
wv_thongs:
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
        ld a,E_THONG
        call en_new
        jr c,.n
        ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FD       ; -2.5
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

; a V of thongs between the flags (a formation: all of them = a capsule)
wv_flags:
        ld b,5
        call new_group
        ld hl,vform2
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
        ld a,E_THONG
        call en_new
        jr c,.n
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FD
        ld a,(ix+E_Y)
        ld (ix+E_P1),a
.n:     pop hl
        pop bc
        djnz .l
        ret
vform2: db 0,0, 14,-12, 14,12, 28,-24, 28,24

; three gulls, one after the other
wv_gulls:
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
        add a,a
        ld c,a
        ld a,(wv_yv)
        cp 80
        jr c,.y
        ld a,80
.y:     add a,32
        add a,c
        ld c,a
        ld a,E_GULL
        call en_new
        jr c,.n
        ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FD
.n:     pop bc
        djnz .l
        ret

; snags fly in, sizzle and pop
wv_snags:
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
        ld a,E_SNAG
        call en_new
        jr c,.n
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,190               ; where it stops
        ld (ix+E_P1),a
        ld (ix+E_FIRE),40
.n:     pop bc
        djnz .l
        ret

; a beach ball: it has a bell inside
wv_ball:
        ld hl,328
        ld a,(wv_yv)
        add a,32
        ld c,a
        ld a,E_BALL
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_BELL
        ld (ix+E_DXL),$80
        ld (ix+E_DXH),$FE       ; -1.5
        ld (ix+E_DYH),$FE
        ret

; crabs on the sand
wv_crabs:
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
        ld c,32+170
        ld a,E_CRAB
        call en_new
        jr c,.n
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,20
        ld (ix+E_FIRE),a
.n:     pop bc
        djnz .l
        ret

; a red lilo: it drops a capsule
wv_lilo:
        ld hl,328
        ld a,(wv_yv)
        add a,32
        ld c,a
        ld a,E_LILO
        call en_new
        ret c
        ld (ix+E_FLAGS),EF_CAPS
        ld (ix+E_DXH),$FD
        ld a,(ix+E_Y)
        ld (ix+E_P1),a
        ret

; ---------------------------------------------------------------------
; behaviours
; a seagull: makes for any bell (MINE!), otherwise for the pilot's height
en_gull:
        ld a,(ix+E_P2)
        or a
        jr z,.hunt
        ; carrying a bell off: up and away
        ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FF
        ld (ix+E_DYL),$00
        ld (ix+E_DYH),$FE
        jp en_move
.hunt:  call en_move
        ; target height: the first bell, or the pilot
        ld a,(py)
        ld c,a
        ld hl,bells
        ld b,NBELL
.b:     ld a,(hl)
        or a
        jr nz,.bf
        ld de,BE_SIZE
        add hl,de
        djnz .b
        jr .steer
.bf:    push hl
        pop iy
        ld a,(iy+BL_Y)
        ld c,a
        ; close enough to take it?
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld e,(iy+BL_X)
        ld d,(iy+BL_X+1)
        or a
        sbc hl,de
        ld de,12
        add hl,de
        ld a,h
        or a
        jr nz,.steer
        ld a,l
        cp 24
        jr nc,.steer
        ld a,(ix+E_Y)
        sub (iy+BL_Y)
        add a,10
        cp 20
        jr nc,.steer
        ld (iy+0),0             ; got it: MINE!
        ld (ix+E_P2),1
        ld a,SFX_SQUAWK
        jp play_sfx
.steer: ld a,(ix+E_Y)
        cp c
        ret z
        jr c,.dn
        dec (ix+E_Y)
        ret
.dn:    inc (ix+E_Y)
        ret

; a snag: flies in, stops, sizzles, pops into three pellets
en_snag:
        ld a,(ix+E_ST)
        or a
        jr nz,.h
        ld (ix+E_DXL),0
        ld (ix+E_DXH),$FD
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
.h:     cp 1
        jr nz,.leave
        ld a,(ix+E_T)
        and 7
        ld a,SFX_SIZZLE
        call z,play_sfx
        dec (ix+E_FIRE)
        ret nz
        ; pop! three pellets: aimed, and one either side
        ld (ix+E_ST),2
        call en_aim
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld a,(ix+E_Y)
        ld c,a
        ld de,$F0E8             ; up-left
        call bullet_new
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld a,(ix+E_Y)
        add a,4
        ld c,a
        ld de,$10E8             ; down-left
        call bullet_new
        ld a,SFX_POP
        jp play_sfx
.leave: ld (ix+E_DXL),$00
        ld (ix+E_DXH),$FC
        jp en_move

; a crab scuttles along the sand and nips pellets up at you
en_crab:
        ld (ix+E_DXL),0
        ld (ix+E_DXH),$FE
        ld a,(scrolling)
        or a
        jr nz,.s
        ld (ix+E_DXH),$FF
.s:     ld a,(ix+E_T)
        and 32
        jr z,.m
        ld (ix+E_DXL),$80       ; scuttles back now and then
.m:     call en_move
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld de,5
        add hl,de
        ld a,h
        cp 2
        jr nc,.f
        srl h
        rr l
        ld a,l
        call floor_at
        add a,32-8
        ld (ix+E_Y),a
.f:     call en_vis
        ret c
        dec (ix+E_FIRE)
        ret nz
        ld a,(difficulty)
        ld b,70
        or a
        jr z,.r
        ld b,45
.r:     ld (ix+E_FIRE),b
        jp en_aim

; barbecue smoke: drifts, wobbles, fades (harmless, but you can't see through it)
en_smoke:
        call en_move
        ld a,(ix+E_T)
        cp 150
        ret c
        ld (ix+E_TYPE),0
        ret

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
        add a,32-6
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

; on_kill: IX = an enemy shot down. NZ if the stage handled it.
; A gull carrying a bell drops it.
on_kill:
        ld a,(ix+E_TYPE)
        cp E_GULL
        jr nz,.no
        ld a,(ix+E_P2)
        or a
        jr z,.no
        ld (ix+E_P2),0
        push ix
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld a,(ix+E_Y)
        ld c,a
        call bell_at
        pop ix
.no:    xor a
        ret

; =====================================================================
; THE GREAT AUSTRALIAN BARBIE
; =====================================================================
BS_ENTER    equ 0
BS_FLIP     equ 1
BS_SMOKE    equ 2
BS_WARN     equ 3
BS_TONGS    equ 4
BS_GAS      equ 5
BS_DIE      equ 6
BC_WARN     equ 4
BC_FLAME    equ 8
GAS_FULL    equ 8           ; hits on the bottle to run it dry

boss_start:
        ld a,1
        ld (boss_on),a
        ld a,GS_BOSS
        ld (gstate),a
        ld hl,336
        ld (boss_x),hl
        ld a,32+80
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
boss_hps:   db 40,52,68

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
.jt:    dw cb_enter,cb_flip,cb_smoke,cb_warn,cb_tongs,cb_gas,cb_die

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
        ld a,BS_FLIP
        jp cb_next

; roll up and down (slowly) after the pilot
cb_bob: ld a,(py)
        sub 34
        jr nc,cb_to
        xor a
cb_to:  cp 32+8
        jr nc,.a
        ld a,32+8
.a:     cp 32+112
        jr c,.b
        ld a,32+112
.b:     ld hl,boss_y
        cp (hl)
        ret z
        jr c,.u
        inc (hl)                ; 2 px at a time (every fourth frame): each
        cp (hl)                 ; page keeps its boss glyphs every other frame
        ret z
        inc (hl)
        ret
.u:     dec (hl)
        cp (hl)
        ret z
        dec (hl)
        ret

; flip snags at the pilot: they arc over and burst on the sand
cb_flip:
        ld a,1
        ld (boss_var),a
        ld a,(boss_t)
        and 3
        call z,cb_bob
        ld a,(boss_t)
        and 15
        cp 4
        jr nz,.t
        ld hl,(boss_x)
        ld de,30
        add hl,de
        ld a,(boss_y)
        add a,22
        ld c,a
        ld a,E_LOB
        call en_new
        jr c,.t
        call random
        and $7F
        neg
        ld (ix+E_DXL),a
        ld (ix+E_DXH),$FD       ; -2.5 .. -3
        ld (ix+E_DYL),$00
        ld (ix+E_DYH),$FB       ; up it goes
        ld a,SFX_SPIT
        call play_sfx
.t:     ld a,(boss_t)
        cp 72
        ret c
        ld a,BS_SMOKE
        jp cb_next

; smoke rolls out; pellets come through it
cb_smoke:
        xor a
        ld (boss_var),a
        ld a,(boss_t)
        and 3
        call z,cb_bob
        ld a,(boss_t)
        and 15
        jr nz,.p
        ld hl,(boss_x)
        ld de,20
        add hl,de
        ld a,(boss_y)
        add a,8
        ld c,a
        ld a,E_SMOKE
        call en_new
        jr c,.p
        ld (ix+E_FLAGS),EF_SHIELD+EF_HARMLESS
        ld (ix+E_DXL),$40
        ld (ix+E_DXH),$FE
        ld (ix+E_DYL),$C0
        ld (ix+E_DYH),$FF
.p:     ld a,(boss_t)
        and 15
        cp 8
        jr nz,.t
        ld hl,(boss_x)
        ld de,30
        add hl,de
        ld a,(boss_y)
        add a,30
        ld c,a
        call bullet_aimed
.t:     ld a,(boss_t)
        cp 64
        ret c
        ld a,(boss_jam)
        cp GAS_FULL
        jr nc,.gas
        ld a,(boss_n)
        cp 3
        jr nc,.gas
        ld a,BS_WARN
        jp cb_next
.gas:   ld a,SFX_HISS
        call play_sfx
        ld a,BS_GAS
        jp cb_next

; CLACK CLACK: the tongs line up on you, flashing, then shoot out
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
        ld a,SFX_CLACK
        call z,play_sfx
        ld a,1
        ld (warn_msg),a
        ld a,(boss_t)
        cp 40
        ret c
        ld a,RED
        ld (boss_pal+BC_WARN),a
        ld a,BS_TONGS
        jp cb_next
cb_aim: ld a,(py)
        sub 26
        jr nc,$+3
        xor a
        jp cb_to

; the tongs: a band at the tongs' height, across to the left edge
cb_tongs:
        ld a,(boss_t)
        and 3
        ld a,SFX_CLACK
        call z,play_sfx
        ld a,(pdead)
        or a
        jr nz,.t
        ld a,(boss_y)
        add a,29
        ld b,a                  ; band top
        ld a,(py)
        add a,9
        cp b
        jr c,.t
        ld a,b
        add a,8
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
        ld hl,boss_n
        inc (hl)
        ld a,BS_FLIP
        jp cb_next

; GAS LOW: the flames go out, it shudders: the hotplate is open to fire
cb_gas: ld a,3
        ld (boss_var),a
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
        ld a,1
        ld (warn_msg),a
        ld a,(boss_t)
        and 31
        ld a,SFX_HISS
        call z,play_sfx
        ld a,(boss_t)
        cp 100
        ret c
        ld hl,232
        ld (boss_x),hl
        xor a
        ld (boss_jam),a
        ld (boss_n),a
        ld (warn_msg),a
        ld a,1
        ld (hud_dirty),a
        ld a,BS_FLIP
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

; shot IX against the barbecue: the gas bottle (always), the hotplate (GAS LOW)
shot_boss:
        ld a,(boss_st)
        cp BS_ENTER
        ret z
        cp BS_DIE
        ret z
        ; the gas bottle: x+4..x+20, y+38..y+58
        ld de,4*256+20
        ld bc,38*256+58
        call setbox
        call sbox
        jr nc,.body
        ld a,(boss_st)
        cp BS_GAS
        jr z,.hot               ; (already dry: it counts as the body)
        ld a,(boss_jam)
        cp GAS_FULL
        jr nc,.tk
        inc a
        ld (boss_jam),a
        ld a,SFX_HISS
        call play_sfx
        jr .spend
.tk:    ld a,SFX_TINK
        call play_sfx
        jr .spend
.body:  ; the barbecue itself: x+20..x+74, y+8..y+56
        ld de,20*256+74
        ld bc,8*256+56
        call setbox
        call sbox
        ret nc
        ld a,(boss_st)
        cp BS_GAS
        jr nz,.tk
.hot:   ld a,(ix+0)
        cp ST_BEAM
        jr nz,.nb
        ld a,(ix+6)
        and 3
        ret nz                  ; beams: every fourth frame
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

; boss_area: E = damage from a blast or a shout (half unless out of gas)
boss_area:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_GAS
        jr z,.f
        srl e
        ret z
.f:     jp boss_hurt

; the pilot against the barbecue
boss_touch:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_DIE
        ret z
        ld hl,(boss_x)
        ld de,20+16
        add hl,de
        call hx
        ld c,a
        ld a,(hx1)
        cp c
        ret c
        ld a,(boss_y)
        add a,10
        ld c,a
        ld a,(hy1)
        cp c
        ret c
        ld a,(boss_y)
        add a,60
        ld c,a
        ld a,(hy0)
        cp c
        ret nc
        jp hit_player

; the tongs, drawn with the small objects while they're out
draw_boss_objs:
        ld a,(boss_on)
        or a
        ret z
        ld a,(boss_st)
        cp BS_TONGS
        ret nz
        ld a,(boss_y)
        add a,30-24
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,WHITE
        ld (spr_ink),a
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

warn1:      db "! CLACK CLACK ! ",0
warn2:      db "!! GAS LOW !!   ",0
ovl_end:
        ASSERT ovl_end <= OVL_END
        SAVEBIN "../build/OVL2.BIN",OVL,ovl_end-OVL
        DISPLAY "stage 2 overlay end: ",ovl_end
