; =====================================================================
;  game.asm : player, monsters, combat, magic, particles, status bar
; =====================================================================
p_x:     db 0
p_y:     db 0
p_addr:  dw 0
p_dir:   db 0
p_hp:    db 6
p_hpmax: db 6
p_mp:    db 0
p_mpmax: db 4
p_gems:  db 0
p_staff: db 0
p_key:   db 0
p_boots: db 0
p_sun:   db 0
p_ring:  db 0
p_blade: db 0
scr_track: db 0
p_xp:    db 0
p_lvl:   db 1
p_dead:  db 0
p_inv:   db 0
p_cd:    db 0
p_atk:   db 0
p_atkcd: db 0
p_atkcell: dw 0
p_mpt:   db 0
p_walk:  db 0
p_cast:  db 0
p_get:   db 0
r_x:     db 0               ; room entry point (respawn)
r_y:     db 0
r_dir:   db 0
fb_on:   db 0
fb_addr: dw 0
fb_dir:  db 0
fb_t:    db 0
boom_t:  db 0
boom_addr: dw 0
msg_t:   db 0
game_over: db 0             ; 1 = finished (ending)

DXT:    db 1,0,-1,0
DYT:    db 0,1,0,-1

MAXENT  EQU 12
E_TYPE  EQU 0
E_X     EQU 1
E_Y     EQU 2
E_HP    EQU 3
E_CD    EQU 4
E_SPN   EQU 5
E_ANIM  EQU 6
E_FLASH EQU 7
ENTS:   ds MAXENT*8


; ---------------------------------------------------------------------
; new game / resume / chapter flow
; ---------------------------------------------------------------------
game_new:
        ld a,6
        ld (p_hpmax),a
        ld a,4
        ld (p_mpmax),a
        xor a
        ld (p_gems),a
        ld (p_staff),a
        ld (p_boots),a
        ld (p_sun),a
        ld (p_ring),a
        ld (p_blade),a
        ld (p_xp),a
        inc a
        ld (p_lvl),a
        ld (lv_num),a
        IFDEF TALL
        ld a,1
        ld (p_staff),a
        ld (p_boots),a
        ld (p_ring),a
        ENDIF
        IFDEF TLEV
        ld a,TLEV
        ld (lv_num),a
        ENDIF
game_run:
.ch:    ld a,(lv_num)
        call level_load
        call level_begin
        call chapter_card
        call chapter_start
        call game_loop
        ld a,(game_over)
        cp 1
        ret nz                  ; 2 = the end (shown already)
        ld hl,lv_num
        inc (hl)
        jr .ch

; place the player at the chapter start and enter its first screen
chapter_start:
        ld a,(p_hpmax)
        ld (p_hp),a
        ld a,(p_staff)
        or a
        jr z,.nm
        ld a,(p_mpmax)
.nm:    ld (p_mp),a
        xor a
        ld (p_key),a
        ld (p_dead),a
        ld (fb_on),a
        ld (boom_t),a
        ld (game_over),a
        ld (p_atk),a
        ld (p_inv),a
        ld (b_seen),a
        ld (msg_t),a
        IFDEF TSX
        ld a,TSX
        ld (p_x),a
        ld a,TSY
        ld (p_y),a
        ENDIF
        call p_setaddr
        ld a,(p_x)
        rlca
        rlca
        rlca
        and 3
        ld (scr_x),a
        ld a,(p_y)
        ld b,-1
.d15:   inc b
        sub 15
        jr nc,.d15
        ld a,b
        ld (scr_y),a
        call enter_screen
        call bank1
        ld hl,(LB_SMSG)
        call bank0
        jp show_msg

p_setaddr:
        ld a,(p_y)
        add a,MAPH
        ld h,a
        ld a,(p_x)
        ld l,a
        ld (p_addr),hl
        ret

; enter the current screen (scr_x/scr_y): lights, monsters, music, status
enter_screen:
        ld a,(p_x)
        ld (r_x),a
        ld a,(p_y)
        ld (r_y),a
        ld a,(p_dir)
        ld (r_dir),a
        xor a
        ld (fb_on),a
        ld (boom_t),a
        call parts_clear
        call eshots_clear
        ; screen properties
        ld a,(scr_y)
        add a,a
        add a,a
        ld b,a
        ld a,(scr_x)
        add a,b
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,LVBUF+LV_SCREENS
        add hl,de
        ld a,(hl)
        inc hl
        or a
        ld a,M0G
        jr z,.g
        ld a,M0O
.g:     ld (lbase),a
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (scr_name),de
        ld (scr_track),a
        push af
        call set_window
        call boss_check
        pop af
        ld b,a
        ld a,(b_on)
        or a
        jr z,.nb
        push bc
        call boss_intro
        pop bc
        ld b,TR_BOSS
.nb:    ld a,b
        ld hl,mus_track
        cp (hl)
        call nz,music_play
        call room_enter
        call ents_spawn
        jp draw_status
scr_name: dw 0

; ---------------------------------------------------------------------
; main loop
; ---------------------------------------------------------------------
game_loop:
        call wait_frame
        ld a,(light_dirty)
        or a
        call nz,light_update
        call anim_tick
        call parts_tick
        call eshots_tick
        call ents_draw
        call boss_draw
        call fb_draw
        call atk_draw
        call player_draw
        call msg_tick
        call read_input
        call player_logic
        ld a,(game_over)
        or a
        ret nz
        call ents_logic
        call boss_logic
        call fb_logic
        ; lantern flicker
        ld a,(frame)
        and 15
        jr nz,.nf
        call rnd
        and 3
        cp NVAR
        jr c,.v
        xor a
.v:     ld (light_var),a
        ld a,1
        ld (light_dirty),a
.nf:    ld a,(boom_t)
        or a
        jr z,.nb
        dec a
        ld (boom_t),a
        jr nz,.nb
        ld a,1
        ld (light_dirty),a
.nb:    call sound_tick
        jr game_loop

; ---------------------------------------------------------------------
; player
; ---------------------------------------------------------------------
player_logic:
        ld a,(p_dead)
        or a
        jp nz,p_dying
        ld hl,p_inv
        call dec0
        ld hl,p_atkcd
        call dec0
        ld hl,p_cd
        call dec0
        ld hl,p_cast
        call dec0
        ld hl,p_get
        call dec0
        ; mana regeneration
        ld a,(p_staff)
        or a
        jr z,.nmr
        ld hl,p_mpt
        inc (hl)
        ld a,(hl)
        cp 200
        jr c,.nmr
        ld (hl),0
        ld a,(p_mp)
        ld hl,p_mpmax
        cp (hl)
        jr nc,.nmr
        inc a
        ld (p_mp),a
        call draw_status_if
.nmr:
        ld a,(in_new)
        bit IN_MAP,a
        jp nz,automap
        bit IN_INV,a
        jp nz,inventory
        bit IN_MAG,a
        call nz,cast_fire
        ld a,(in_new)
        bit IN_FIRE,a
        call nz,sword
        ; movement
        ld a,(in_now)
        and $0F
        jr nz,.mv
        xor a
        ld (p_cd),a
        ret
.mv:    ld c,a
        ld a,(p_cd)
        or a
        ret nz
        ; prefer a newly pressed direction
        ld a,(in_new)
        and c
        jr nz,.pick
        ld a,c
.pick:  ld b,0
.pk:    rrca
        jr c,.got
        inc b
        jr .pk
.got:   ld a,b                  ; 0 R 1 D 2 L 3 U
        ld hl,p_dir
        cp (hl)
        jr z,.same
        ld (hl),a
        ld a,1
        ld (light_dirty),a
.same:  ld a,6
        ld (p_cd),a
        call front_cell         ; HL = target, B = x, C = y
        ; outside the window?
        ld a,(wx)
        ld d,a
        ld a,b
        sub d
        cp WINW
        jp nc,p_leave
        ld a,(wy)
        ld d,a
        ld a,c
        sub d
        cp WINH
        jp nc,p_leave
        ; the boss?
        push hl
        push bc
        call boss_at
        pop bc
        pop hl
        jr z,.nboss
        jp hit_boss_bump
.nboss: ; entity there?
        push hl
        push bc
        call find_ent
        pop bc
        pop hl
        jr z,.noent
        ld a,(ix+E_TYPE)
        cp E_STAFF
        jr nc,.walk             ; items: walk onto them
        ; bump attack
        jp hit_ent_sword
.noent: ld a,(hl)
        and $7F
        ld e,a
        ld d,TPROP>>8
        ld a,(de)
        bit 0,a
        jr z,.walk
        ; solid: door?
        and $F0
        cp 4<<4
        jp z,try_door
        cp 5<<4
        ret z
        cp 6<<4
        jr z,.lava
        cp 7<<4
        jr z,.water
        cp 11<<4
        jr nz,.ngate
        ld hl,T_GATE
        jr .warn
.ngate: cp 8<<4
        jr nz,.bump
        ld hl,T_SEALED
        jr .warn
.lava:  ld a,(p_ring)
        or a
        jr nz,.walk
        ld hl,T_LAVA
        jr .warn
.water: ld a,(p_boots)
        or a
        jr nz,.wade
        ld hl,T_WATER
.warn:  ld a,(msg_t)
        or a
        call z,show_msg
.bump:  ld hl,SFX_BUMP
        call sfx
        ld a,10
        ld (p_cd),a
        ret
.wade:  push bc
        push hl
        ld hl,SFX_SPLASH
        call sfx
        pop hl
        pop bc
.walk:  push bc
        ld hl,(p_addr)
        call render_cell
        pop bc
        ld a,b
        ld (p_x),a
        ld a,c
        ld (p_y),a
        call p_setaddr
        ld a,1
        ld (light_dirty),a
        ld hl,p_walk
        inc (hl)
        ld a,(sfx_ptr+1)
        or a
        ld hl,SFX_STEP
        call z,sfx
        jp arrive

; HL = player front cell address, B = x, C = y
front_cell:
        ld a,(p_dir)
        ld e,a
        ld d,0
        ld hl,DXT
        add hl,de
        ld a,(p_x)
        add a,(hl)
        ld b,a
        ld hl,DYT
        add hl,de
        ld a,(p_y)
        add a,(hl)
        ld c,a
        add a,MAPH
        ld h,a
        ld l,b
        ret

; leaving the window: move to the neighbouring screen if walkable
p_leave:
        ld a,b
        cp MAPW
        ret nc
        ld a,c
        cp MAPROWS
        ret nc
        ld a,(hl)
        and $7F
        ld e,a
        ld d,TPROP>>8
        ld a,(de)
        bit 0,a
        ret nz
        ld a,b
        ld (p_x),a
        ld a,c
        ld (p_y),a
        call p_setaddr
        ld a,(p_x)
        rlca
        rlca
        rlca
        and 3
        ld (scr_x),a
        ld a,(p_y)
        ld b,0
.d15:   sub 15
        jr c,.dd
        inc b
        jr .d15
.dd:    ld a,b
        ld (scr_y),a
        call screen_wipe
        jp enter_screen

; quick vertical wipe to black before a screen change
screen_wipe:
        ld hl,VRAM
        ld c,8
.f:     push bc
        push hl
        call wait_frame
        call sound_tick
        pop hl
        pop bc
        ld b,64
.w:     ld (hl),$80
        inc hl
        djnz .w
        dec c
        jr nz,.f
        ret

; player arrived at p_addr: items, runes, stairs
arrive:
        ld hl,(p_addr)
        call find_ent
        call nz,pickup
        ld hl,(p_addr)
        ld a,(hl)
        and $7F
        ld e,a
        ld d,TPROP>>8
        ld a,(de)
        and $F0
        ret z
        cp 3<<4
        jp z,read_rune
        cp 9<<4
        jp z,portal_jump
        cp 10<<4
        jp z,plate_press
        cp 1<<4
        jr z,.up
        cp 2<<4
        ret nz
        ; stairs down (or the Ember itself)
        ld hl,(p_addr)
        ld a,(hl)
        and $7F
        sub TL_EMBER
        cp 4
        ld a,2
        jr c,.fin
        ld a,1
.fin:   ld (game_over),a
        cp 2
        jp z,final_ending
        jp chapter_exit
.up:    ld hl,T_STAIRUP
        jp show_msg

read_rune:
        call bank1
        ld a,(p_x)
        ld c,a
        ld a,(p_y)
        ld b,a
        ld hl,(LB_MSGS)
.l:     ld a,(hl)
        cp 255
        jp z,bank0
        cp c
        jr nz,.n
        inc hl
        ld a,(hl)
        dec hl
        cp b
        jr nz,.n
        inc hl
        inc hl
        push hl
        ld hl,SFX_RUNE
        call sfx
        pop hl
        call show_msg
        jp bank0
.n:     ld de,34
        add hl,de
        jr .l

try_door:
        ld a,(p_key)
        or a
        jr nz,.open
        ld hl,T_LOCKED
        call show_msg
        ld hl,SFX_BUMP
        jp sfx
.open:  ld (hl),TL_DOORWAY|$80
        ld hl,SFX_DOOR
        call sfx
        ld hl,T_OPEN
        call show_msg
        jp relight

; world changed (door opened / wall broken): recompute static light, redraw
relight:
        ld hl,(light_old)
        ld de,(light_oend)
        call restore_list
        ld hl,LISTA
        ld (light_old),hl
        ld (light_oend),hl
        call room_statics
        call light_update_noren
        jp render_window

pickup:
        ld a,(ix+E_TYPE)
        cp E_STAFF
        ret c
        push af
        ld (ix+E_TYPE),0
        ld a,(ix+E_SPN)
        call spawn_kill
        ld a,12
        ld (p_get),a
        pop af
        cp E_STAFF
        jr nz,.k
        ld a,1
        ld (p_staff),a
        ld a,(p_mpmax)
        ld (p_mp),a
        ld hl,SFX_STAFF
        call sfx
        ld hl,T_STAFF
        jr .msg
.k:     cp E_KEY
        jr nz,.g
        ld a,1
        ld (p_key),a
        ld hl,SFX_PICKUP
        call sfx
        ld hl,T_KEY
        jr .msg
.g:     cp E_GEM
        jr nz,.p
        ld hl,p_gems
        inc (hl)
        ld hl,SFX_GEM
        call sfx
        ld hl,T_GEM
        jr .msg
.p:     cp E_POTION
        jr nz,.h
        ld a,(p_hpmax)
        ld (p_hp),a
        ld hl,SFX_PICKUP
        call sfx
        ld hl,T_POTION
        jr .msg
.h:     cp E_HEART
        jp nz,pickup2
        ld a,(p_hpmax)
        add a,2
        cp 13
        jr c,.hm
        ld a,12
.hm:    ld (p_hpmax),a
        ld (p_hp),a
        ld hl,SFX_STAFF
        call sfx
        ld hl,T_HEART
.msg:   push hl
        ld hl,(p_addr)
        ld c,3
        call burst
        pop hl
        jp show_msg

pickup2:
        push af
        ld hl,SFX_STAFF
        call sfx
        pop af
        cp E_BOOTS
        jr nz,.s
        ld (p_boots),a
        ld hl,T_BOOTS
        jr .m
.s:     cp E_SUNSTONE
        jr nz,.r
        ld (p_sun),a
        call reveal_hidden
        call render_window
        ld a,1
        ld (light_dirty),a
        ld hl,T_SUN
        jr .m
.r:     cp E_RING
        jr nz,.b
        ld (p_ring),a
        ld hl,T_RING
        jr .m
.b:     cp E_BLADE
        jr nz,.mana
        ld (p_blade),a
        ld hl,T_BLADE
        jr .m
.mana:  ld a,(p_mpmax)
        cp 9
        jr nc,.mm
        inc a
        ld (p_mpmax),a
.mm:    ld (p_mp),a
        ld hl,T_MANA
.m:     push hl
        ld hl,(p_addr)
        ld c,1
        call burst
        call draw_status
        pop hl
        jp show_msg

; ---------------------------------------------------------------------
; portals come in pairs (LV_PORTALS: x1,y1,x2,y2, 255 = none)
; ---------------------------------------------------------------------
portal_jump:
        ld hl,LVBUF+LV_PORTALS
        ld b,2
.pr:    ld a,(hl)
        cp 255
        ret z
        push bc
        ; on the first portal of the pair?
        ld a,(p_x)
        cp (hl)
        jr nz,.n1
        inc hl
        ld a,(p_y)
        cp (hl)
        dec hl
        jr nz,.n1
        inc hl
        inc hl
        jr .go
.n1:    inc hl
        inc hl
        ld a,(p_x)
        cp (hl)
        jr nz,.n2
        inc hl
        ld a,(p_y)
        cp (hl)
        dec hl
        jr nz,.n2
        dec hl
        dec hl
        jr .go
.n2:    inc hl
        inc hl
        pop bc
        djnz .pr
        ret
.go:    pop bc
        ; HL -> destination x,y
        push hl
        ld hl,(p_addr)
        ld c,1
        call burst
        ld hl,SFX_STAFF
        call sfx
        pop hl
        ld a,(hl)
        ld (p_x),a
        inc hl
        ld a,(hl)
        ld (p_y),a
        ld a,(scr_x)
        ld b,a
        ld a,(scr_y)
        ld c,a
        push bc
        ld hl,(p_addr)
        call render_cell
        call p_setaddr
        ; destination screen
        ld a,(p_x)
        rlca
        rlca
        rlca
        and 3
        ld (scr_x),a
        ld a,(p_y)
        ld b,-1
.d15:   inc b
        sub 15
        jr nc,.d15
        ld a,b
        ld (scr_y),a
        pop bc
        ld a,(scr_x)
        cp b
        jr nz,.far
        ld a,(scr_y)
        cp c
        jr nz,.far
        ld a,1
        ld (light_dirty),a
        jr .msg
.far:   call screen_wipe
        call enter_screen
.msg:   ld hl,(p_addr)
        ld c,3
        call burst
        ld hl,T_PORTAL
        jp show_msg

; pressure plate: every gate in this screen opens
plate_press:
        ld a,(wy)
        add a,MAPH
        ld h,a
        ld c,WINH
        ld d,0                  ; opened count
.r:     ld a,(wx)
        ld l,a
        ld b,WINW
.c:     ld a,(hl)
        and $7F
        cp TL_GATE
        jr nz,.n
        ld (hl),TL_DOORWAY|$80
        inc d
.n:     inc l
        djnz .c
        inc h
        dec c
        jr nz,.r
        ld a,d
        or a
        ret z
        ld hl,SFX_DOOR
        call sfx
        ld hl,T_GRIND
        call show_msg
        jp relight

; the sunstone shows every hidden wall of the chapter
reveal_hidden:
        ld h,MAPH
        ld c,MAPROWS
.r:     ld l,0
.c:     ld a,(hl)
        and $7F
        cp TL_HIDDEN
        jr z,.g
        cp TL_HID_T
        jr z,.g
        cp TL_HID_Y
        jr z,.g
        cp TL_HID_V
        jr nz,.n
.g:     ld a,(hl)
        and $80
        or TL_HGLOW
        ld (hl),a
.n:     inc l
        bit 7,l
        jr z,.c
        inc h
        dec c
        jr nz,.r
        ret

; A = spawn index -> mark dead in the chapter spawn table (255 = summoned)
spawn_kill:
        cp 255
        ret z
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,LVBUF+LV_SPAWNS+3
        add hl,de
        ld (hl),0
        ret

player_draw:
        ld hl,(p_addr)
        call cell_vram
        ret c
        ld a,(p_dead)
        or a
        jr nz,.dead
        ld a,(p_inv)
        and 2
        ld a,$40                ; inverse @ (hurt flash)
        jr nz,.put
        ld a,(p_cast)
        or a
        ld a,G_PCAST
        jr nz,.put
        ld a,(p_get)
        or a
        ld a,G_PGET
        jr nz,.put
        ld a,(p_atk)
        or a
        ld a,G_PATK
        jr nz,.put
        xor a                   ; '@'
.put:   ld (de),a
        ret
.dead:  rrca
        rrca
        rrca
        and 3
        ld hl,DEADG
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (de),a
        ret
DEADG:  db $80,46,43,42         ; blank . + *  (reversed by timer)

p_hurt:
        ld a,(p_inv)
        or a
        ret nz
        ld a,70
        ld (p_inv),a
        ld hl,SFX_HURT
        call sfx
        ld a,(p_hp)
        dec a
        ld (p_hp),a
        push af
        call draw_status_if
        pop af
        ret nz
        ; death
        ld a,31
        ld (p_dead),a
        ld hl,T_DIED
        call show_msg
        ld hl,SFX_KILL
        jp sfx

p_dying:
        dec a
        ld (p_dead),a
        ret nz
        ; respawn at the room entry point
        ld a,(p_hpmax)
        ld (p_hp),a
        ld a,(r_x)
        ld (p_x),a
        ld a,(r_y)
        ld (p_y),a
        ld a,(r_dir)
        ld (p_dir),a
        call p_setaddr
        ld a,60
        ld (p_inv),a
        call enter_screen
        ret

; ---------------------------------------------------------------------
; sword: three-cell sweep in front of the player
; ---------------------------------------------------------------------
SWORD_DMG EQU 2
sword:
        ld a,(p_atkcd)
        or a
        ret nz
        ld a,14
        ld (p_atkcd),a
        ld a,9
        ld (p_atk),a
        ld hl,0
        ld (p_atkcell),hl
        ld hl,SFX_SWING
        call sfx
        xor a
        ld (sw_bhit),a
        ; hit the three cells
        ld b,0
.c:     push bc
        call sweep_cell         ; HL = cell, carry if invalid
        jr c,.n
        push hl
        call boss_at
        pop hl
        jr z,.nb
        ld a,(sw_bhit)
        or a
        jr nz,.n
        inc a
        ld (sw_bhit),a
        call sword_dmg
        call boss_hit
        jr .n
.nb:    push hl
        call find_ent
        pop hl
        jr z,.nw
        ld a,(ix+E_TYPE)
        cp E_STAFF
        jr nc,.nw
        call hit_ent_sword0
        jr .n
.nw:    ; hidden wall in front?
        pop bc
        push bc
        ld a,b
        cp 1
        jr nz,.n
        ld a,(hl)
        and $7F
        ld e,a
        ld d,TPROP>>8
        ld a,(de)
        and $F0
        cp 5<<4
        call z,break_wall
.n:     pop bc
        inc b
        ld a,b
        cp 3
        jr c,.c
        ret

; B = 0..2 -> HL = sweep cell (front + perp*(B-1)), DE = vram; carry if outside window
sweep_cell:
        push bc
        call front_cell
        pop bc
        ld a,b
        cp 1
        jr z,.chk
        ld a,(p_dir)
        inc a
        and 3
        ld e,a
        ld d,0
        push hl
        ld hl,DXT
        add hl,de
        ld c,(hl)
        ld hl,DYT
        add hl,de
        ld d,(hl)
        pop hl
        ld a,b
        or a
        jr nz,.plus
        ld a,c
        neg
        ld c,a
        ld a,d
        neg
        ld d,a
.plus:  ld a,l
        add a,c
        ld l,a
        ld a,h
        add a,d
        ld h,a
.chk:   push hl
        call cell_vram
        pop hl
        ret

hit_ent_sword:
        ld a,(p_atkcd)
        or a
        ret nz
        ld a,12
        ld (p_atkcd),a
        ld a,6
        ld (p_atk),a
        ld hl,SFX_SWING
        call sfx
hit_ent_sword0:
        call sword_dmg
        jr hit_ent
; damage = 1 + level (+2 with the runeblade)
sword_dmg:
        ld a,(p_blade)
        or a
        ld a,(p_lvl)
        inc a
        ret z
        add a,2
        ret
sw_bhit: db 0
hit_boss_bump:
        ld a,(p_atkcd)
        or a
        ret nz
        ld a,12
        ld (p_atkcd),a
        ld a,6
        ld (p_atk),a
        ld hl,SFX_SWING
        call sfx
        call sword_dmg
        jp boss_hit

; IX = entity, A = damage
hit_ent:
        ld c,a
        ld a,(ix+E_HP)
        sub c
        ld (ix+E_HP),a
        ld (ix+E_FLASH),6
        jr z,.kill
        jr c,.kill
        ld hl,SFX_HIT
        jp sfx
.kill:  ; xp
        ld a,(ix+E_TYPE)
        ld e,a
        add a,a
        add a,a
        add a,e                 ; *5
        ld e,a
        ld d,0
        ld hl,ETAB+2
        add hl,de
        ld a,(p_xp)
        add a,(hl)
        ld (p_xp),a
        ld (ix+E_TYPE),0
        ld a,(ix+E_SPN)
        call spawn_kill
        ld a,(ix+E_Y)
        add a,MAPH
        ld h,a
        ld a,(ix+E_X)
        ld l,a
        push hl
        call render_cell
        pop hl
        ld c,2
        call burst
        ld hl,SFX_KILL
        call sfx
        ; level up?
        ld a,(p_lvl)
        ld e,a
        ld d,0
        ld hl,XPLEV-1
        add hl,de
        ld a,(p_xp)
        cp (hl)
        ret c
        ld a,(p_lvl)
        cp 5
        ret nc
        inc a
        ld (p_lvl),a
        ld a,(p_hpmax)
        cp 8
        jr nc,.hx
        inc a
        ld (p_hpmax),a
.hx:    ld (p_hp),a
        ld a,(p_mpmax)
        cp 6
        jr nc,.mx
        inc a
        ld (p_mpmax),a
.mx:    ld hl,SFX_STAFF
        call sfx
        ld hl,T_LEVEL
        jp show_msg
XPLEV:  db 6,14,26,40,255

break_wall:
        ld (hl),TL_BROKENWALL|$80
        push hl
        ld c,4
        call burst
        ld hl,SFX_CRUMBLE
        call sfx
        ld hl,T_HIDDEN
        call show_msg
        pop hl
        jp relight

; draw the sword sweep (p_atk counts 9..1)
atk_draw:
        ld a,(p_atk)
        or a
        ret z
        dec a
        ld (p_atk),a
        ; erase previous
        ld hl,(p_atkcell)
        ld a,h
        or a
        jr z,.ne
        call render_cell
        ld hl,0
        ld (p_atkcell),hl
.ne:    ld a,(p_atk)
        or a
        ret z
        ; stage = (8 - p_atk) / 3
        ld b,a
        ld a,9
        sub b
        ld b,0
.dv:    sub 3
        jr c,.dd
        inc b
        jr .dv
.dd:    ld a,b
        cp 3
        ret nc
        call sweep_cell
        ret c
        ld a,(hl)
        and $40
        ret nz                  ; don't draw into walls
        ld (p_atkcell),hl
        ; glyph from offset
        push de
        ld a,(p_y)
        add a,MAPH
        ld c,a
        ld a,h
        sub c                   ; dy
        inc a
        ld c,a
        ld a,(p_x)
        ld b,a
        ld a,l
        sub b                   ; dx
        inc a
        ld b,a
        add a,a
        add a,b
        add a,c
        ld e,a
        ld d,0
        ld hl,SLASH
        add hl,de
        ld a,(hl)
        pop de
        ld (de),a
        ret

; ---------------------------------------------------------------------
; fireball
; ---------------------------------------------------------------------
cast_fire:
        ld a,(p_staff)
        or a
        ret z
        ld a,(fb_on)
        or a
        ret nz
        ld a,(p_mp)
        or a
        jr nz,.ok
        ld hl,SFX_NOMP
        call sfx
        ld hl,T_NOMP
        jp show_msg
.ok:    dec a
        ld (p_mp),a
        call draw_status_if
        ld a,1
        ld (fb_on),a
        ld a,10
        ld (p_cast),a
        ld hl,(p_addr)
        ld (fb_addr),hl
        ld a,(p_dir)
        ld (fb_dir),a
        xor a
        ld (fb_t),a
        ld hl,SFX_FIRE
        jp sfx

fb_logic:
        ld a,(fb_on)
        or a
        ret z
        ld hl,fb_t
        inc (hl)
        ld a,(hl)
        and 1
        ret nz
        ; advance
        ld hl,(fb_addr)
        ld de,(p_addr)
        or a
        sbc hl,de
        ld hl,(fb_addr)
        call nz,render_cell
        ld hl,(fb_addr)
        ld a,(fb_dir)
        ld e,a
        ld d,0
        push hl
        ld hl,DXT
        add hl,de
        ld b,(hl)
        ld hl,DYT
        add hl,de
        ld c,(hl)
        pop hl
        ld a,l
        add a,b
        ld l,a
        ld a,h
        add a,c
        ld h,a
        ; outside window?
        push hl
        call cell_vram
        pop hl
        jr c,.boom0
        ld a,(hl)
        and $40
        jr nz,.wall
        push hl
        call boss_at
        pop hl
        jr z,.nbf
        push hl
        ld a,4
        call boss_hit
        pop hl
        jr .boom
.nbf:   push hl
        call find_ent
        pop hl
        jr z,.fly
        ld a,(ix+E_TYPE)
        cp E_STAFF
        jr nc,.fly
        push hl
        ld a,3
        call hit_ent
        pop hl
        jr .boom
.fly:   ld (fb_addr),hl
        ld a,1
        ld (light_dirty),a
        ld a,(fb_t)
        cp 40
        ret c
        jr .boom
.wall:  ld a,(hl)
        and $7F
        ld e,a
        ld d,TPROP>>8
        ld a,(de)
        and $F0
        cp 5<<4
        jr nz,.boom0
        push hl
        call break_wall
        pop hl
.boom0: ld hl,(fb_addr)
.boom:  xor a
        ld (fb_on),a
        ld (boom_addr),hl
        ld a,12
        ld (boom_t),a
        ld a,1
        ld (light_dirty),a
        ld c,0
        call burst
        ld hl,SFX_BOOM
        jp sfx

fb_draw:
        ld a,(fb_on)
        or a
        ret z
        ld hl,(fb_addr)
        call cell_vram
        ret c
        ld a,(frame)
        and 2
        ld a,G_FB0
        jr z,.p
        ld a,G_FB1
.p:     ld (de),a
        ret

; ---------------------------------------------------------------------
; particles: 12 x (addr lo, addr hi, dx, dy, life, kind)
; ---------------------------------------------------------------------
MAXPART EQU 16
PARTS:  ds MAXPART*6
parts_clear:
        ld hl,PARTS
        ld b,MAXPART*6
.c:     ld (hl),0
        inc hl
        djnz .c
        ret

; burst at HL: C = kind (0 fire, 1 magic, 2 death, 3 sparkle, 4 dust)
burst:
        ld ix,PARTS
        ld de,BURSTD
        ld b,MAXPART
.l:     ld a,(ix+4)
        or a
        jr nz,.n
        ld (ix+0),l
        ld (ix+1),h
        ld a,(de)
        inc de
        ld (ix+2),a
        ld a,(de)
        inc de
        ld (ix+3),a
        ld (ix+4),5
        ld (ix+5),c
        ld a,(de)
        cp 99
        ret z
.n:     push de
        ld de,6
        add ix,de
        pop de
        djnz .l
        ret
BURSTD: db 1,0, 1,1, 0,1, -1,1, -1,0, -1,-1, 0,-1, 1,-1, 99

parts_tick:
        ld a,(frame)
        and 1
        ret nz
        ld ix,PARTS
        ld b,MAXPART
.l:     push bc
        ld a,(ix+4)
        or a
        jr z,.n
        ; erase
        ld l,(ix+0)
        ld h,(ix+1)
        push hl
        call render_cell
        pop hl
        dec (ix+4)
        jr z,.n
        ld a,l
        add a,(ix+2)
        ld l,a
        ld a,h
        add a,(ix+3)
        ld h,a
        ld a,(hl)
        and $40
        jr nz,.die
        ld (ix+0),l
        ld (ix+1),h
        call cell_vram
        jr c,.die
        ; glyph = PGLY[kind*4 + life-1]
        ld a,(ix+5)
        add a,a
        add a,a
        add a,(ix+4)
        dec a
        ld l,a
        ld h,0
        push de
        ld de,PGLY
        add hl,de
        pop de
        ld a,(hl)
        ld (de),a
        jr .n
.die:   ld (ix+4),0
.n:     ld de,6
        add ix,de
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; monsters
; ---------------------------------------------------------------------
ents_spawn:
        ld hl,ENTS
        ld b,MAXENT*8
.c:     ld (hl),0
        inc hl
        djnz .c
        ld ix,ENTS
        ld hl,LVBUF+LV_SPAWNS
        ld c,0                  ; spawn index
.l:     ld a,(hl)
        or a
        ret z
        push hl
        ld b,a                  ; type
        inc hl
        ld a,(wx)
        ld d,a
        ld a,(hl)
        sub d
        cp WINW
        jr nc,.n
        inc hl
        ld a,(wy)
        ld d,a
        ld a,(hl)
        sub d
        cp WINH
        jr nc,.n
        inc hl
        ld a,(hl)
        or a
        jr z,.n
        pop hl
        push hl
        ld (ix+E_TYPE),b
        inc hl
        ld a,(hl)
        ld (ix+E_X),a
        inc hl
        ld a,(hl)
        ld (ix+E_Y),a
        ld (ix+E_SPN),c
        ld a,b
        ld e,a
        add a,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        push hl
        ld hl,ETAB
        add hl,de
        ld a,(hl)
        ld (ix+E_HP),a
        inc hl
        ld a,c
        and 15
        inc a                   ; desync
        ld (ix+E_CD),a
        pop hl
        ld (ix+E_FLASH),0
        ld (ix+E_ANIM),0
        ld de,8
        add ix,de
        ld a,ixl
        cp (ENTS+MAXENT*8)&255
        jr z,.full
.n:     pop hl
        inc hl
        inc hl
        inc hl
        inc hl
        inc c
        jr .l
.full:  pop hl
        ret

; HL = map address -> NZ + IX = entity there, Z = none
find_ent:
        ld ix,ENTS
        ld b,MAXENT
        ld a,h
        sub MAPH
        ld c,a
.l:     ld a,(ix+E_TYPE)
        or a
        jr z,.n
        ld a,(ix+E_X)
        cp l
        jr nz,.n
        ld a,(ix+E_Y)
        cp c
        jr nz,.n
        or 1
        ret
.n:     ld de,8
        add ix,de
        djnz .l
        xor a
        ret

ents_draw:
        ld ix,ENTS
        ld b,MAXENT
.l:     push bc
        ld a,(ix+E_TYPE)
        or a
        jr z,.n
        ld a,(ix+E_Y)
        add a,MAPH
        ld h,a
        ld a,(ix+E_X)
        or $80
        ld l,a
        ld a,(hl)
        and 7
        jr z,.n                 ; in darkness: unseen
        call cell_vram
        jr c,.n
        ld a,(ix+E_FLASH)
        or a
        jr z,.nf
        dec (ix+E_FLASH)
        and 2
        ld a,G_FLASH
        jr nz,.put
.nf:    ld a,(ix+E_TYPE)
        ld c,a
        add a,a
        add a,a
        add a,c
        ld c,a
        ld a,(frame)
        add a,(ix+E_X)
        and 8
        ld a,c
        jr z,.f0
        inc a
.f0:    add a,3
        ld c,a
        ld b,0
        ld hl,ETAB
        add hl,bc
        ld a,(hl)
.put:   ld (de),a
.n:     ld de,8
        add ix,de
        pop bc
        djnz .l
        ret

ents_logic:
        ld ix,ENTS
        ld b,MAXENT
.l:     push bc
        ld a,(ix+E_TYPE)
        cp E_SKELETON
        jr c,.n
        cp E_STAFF
        jr nc,.n
        dec (ix+E_CD)
        jr nz,.n
        ; reload speed
        ld c,a
        add a,a
        add a,a
        add a,c
        ld e,a
        ld d,0
        ld hl,ETAB+1
        add hl,de
        ld a,(hl)
        ld (ix+E_CD),a
        call ent_act
.n:     ld de,8
        add ix,de
        pop bc
        djnz .l
        ret

; IX = monster: choose a step
ent_act:
        ; dx, dy toward player
        ld a,(p_x)
        sub (ix+E_X)
        call sgn
        ld d,a
        ld a,(p_y)
        sub (ix+E_Y)
        call sgn
        ld e,a
        ; distance (max of |dx|,|dy|) for wake-up
        ld a,(p_x)
        sub (ix+E_X)
        call absa
        ld b,a
        ld a,(p_y)
        sub (ix+E_Y)
        call absa
        cp b
        jr nc,.m
        ld a,b
.m:     ld b,a                  ; B = chebyshev distance
        ld a,(ix+E_HP)
        cp 2
        jr nc,.hale
        ld a,(ix+E_TYPE)
        cp E_SKELETON
        jr z,.flee
        cp E_DROWNED
        jr z,.flee
        cp E_SPIDER
        jr nz,.hale
.flee:  ld a,b
        cp 7
        jr nc,.hale             ; far away: back to normal
        ld a,d
        neg
        ld d,a
        ld a,e
        neg
        ld e,a
        call rnd
        and 1
        jr z,.fy
        ld e,0
        jp .try
.fy:    ld d,0
        jp .try
.hale:  ld a,(ix+E_TYPE)
        cp E_IMP
        jr nz,.notimp
        ld a,(p_x)
        sub (ix+E_X)
        call absa
        ld c,a
        ld a,(p_y)
        sub (ix+E_Y)
        call absa
        or a
        jr z,.al
        cp c
        jr z,.al
        ld a,c
        or a
        jr nz,.wander
.al:    ld a,b
        cp 9
        jr nc,.wander
        call rnd
        and 1
        jr nz,.wander
        ld a,(ix+E_Y)
        add a,MAPH
        ld h,a
        ld a,(ix+E_X)
        ld l,a
        ld a,G_FB0
        ld (es_g),a
        call eshot
        ld hl,SFX_SHOT
        jp sfx
.notimp:
        ld a,(ix+E_TYPE)
        cp E_BAT
        jr z,.bat
        cp E_GHOST
        jr z,.chase8
        ; skeleton / slime: chase when near, else wander
        ld a,b
        cp 9
        jr nc,.wander
        ; axis move: larger component first
        ld a,(p_x)
        sub (ix+E_X)
        call absa
        ld c,a
        ld a,(p_y)
        sub (ix+E_Y)
        call absa
        cp c
        jr nc,.vert
        ld e,0
        jr .try
.vert:  ld d,0
        jr .try
.bat:   ld a,(ix+E_ANIM)        ; fleeing after a bite?
        or a
        jr z,.bch
        dec (ix+E_ANIM)
        ld a,d
        neg
        ld d,a
        ld a,e
        neg
        ld e,a
        jr .try
.bch:   call rnd
        and 1
        jr nz,.chase8
.wander:
        call rnd
        and 3
        ld e,a
        ld d,0
        ld hl,DXT
        add hl,de
        ld a,(hl)
        ld hl,DYT
        add hl,de
        ld e,(hl)
        ld d,a
        jr .try
.chase8:
        ld a,b
        cp 12
        jr nc,.wander
.try:   ; target cell
        ld a,(ix+E_X)
        add a,d
        ld l,a
        ld a,(ix+E_Y)
        add a,e
        add a,MAPH
        ld h,a
        ; player there? -> attack
        push hl
        ld de,(p_addr)
        or a
        sbc hl,de
        pop hl
        jr nz,.np
        ld a,(p_dead)
        or a
        ret nz
        ld (ix+E_ANIM),4        ; bats flee for a few moves after biting
        jp p_hurt
.np:    push hl
        call cell_vram
        pop hl
        ret c                   ; stay inside the screen
        push hl
        call boss_at
        pop hl
        ret nz
        ld a,(ix+E_TYPE)
        cp E_GHOST
        jr z,.free
        ld c,a
        ld a,(hl)
        and $7F
        ld e,a
        ld d,TPROP>>8
        ld a,(de)
        ld b,a
        ld a,c
        cp E_EEL
        jr nz,.ne
        ld a,b
        and $F0
        cp 7<<4
        ret nz
        jr .free
.ne:    bit 0,b
        jr z,.free
        cp E_MAGMA
        ret nz
        ld a,b
        and $F0
        cp 6<<4
        ret nz
.free:  ; another entity there?
        push ix
        push hl
        call find_ent
        pop hl
        pop ix
        ret nz
        ; fireball cell?
        ; move
        push hl
        ld a,(ix+E_Y)
        add a,MAPH
        ld h,a
        ld a,(ix+E_X)
        ld l,a
        call render_cell
        pop hl
        ld (ix+E_X),l
        ld a,h
        sub MAPH
        ld (ix+E_Y),a
        ret

sgn:    or a
        ret z
        ld a,1
        ret p
        ld a,-1
        ret
absa:   or a
        ret p
        neg
        ret

; ---------------------------------------------------------------------
; status bar (row 15) and messages
; ---------------------------------------------------------------------
STATROW EQU VRAM+15*32
draw_status_if:
        ld a,(msg_t)
        or a
        ret nz
draw_status:
        ld hl,STATROW
        ld b,32
.c:     ld (hl),32
        inc hl
        djnz .c
        ; life (red) then mana (cyan), two points per cell
        ld de,STATROW
        ld a,(p_hp)
        ld c,a
        ld a,(p_hpmax)
        ld b,a
        ld a,G_HPF
        call pips
        ld a,(p_staff)
        or a
        jr z,.nomp
        ld a,(p_mpmax)
        ld b,a
        ld a,(p_mp)
        ld c,a
        ld a,G_MPF
        call pips
.nomp:  ld de,STATROW+11
        ld a,(p_key)
        or a
        jr z,.nk
        ld a,G_KEY
        ld (de),a
.nk:    inc de
        ld a,(p_gems)
        or a
        jr z,.ng
        ld a,G_GEM
        ld (de),a
        inc de
        ld a,(p_gems)
        call num2
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
.ng:    ld a,(b_on)
        or a
        jr nz,.boss
        ld hl,(scr_name)
        ld de,STATROW+15
        ld bc,17
        ldir
        ret
.boss:  ld hl,BOSSDEF+BD_NAME
        ld de,STATROW+15
        ld bc,12
        ldir
        ; bar: 5 cells, 10 half steps
        ld a,(b_max)
        ld c,a
        ld a,(b_hp)
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; hp*10
        ld b,0
.dv:    ld a,l
        sub c
        ld l,a
        ld a,h
        sbc a,0
        ld h,a
        jr c,.dd
        inc b
        jr .dv
.dd:    ld a,b
        or a
        jr nz,$+3
        inc b                   ; alive: at least half a cell
        ld c,b
        ld b,10
        ld de,STATROW+27
        ld a,G_BOSSF
        jp pips
; B = max, C = current, DE = vram, A = full glyph ; draws ceil(max/2) cells
pips:
        ld (pip_g),a
.l:     ld a,b
        or a
        ret z
        ld a,c
        cp 2
        jr nc,.full
        or a
        jr z,.emp
        ld a,(pip_g)
        and $FA                 ; left half only (TL+BL)
        jr .put
.emp:   ld a,G_PIPE
        jr .put
.full:  ld a,(pip_g)
.put:   ld (de),a
        inc de
        ld a,c
        sub 2
        jr nc,$+3
        xor a
        ld c,a
        ld a,b
        sub 2
        jr nc,$+3
        xor a
        ld b,a
        jr .l
pip_g:  db 0

; HL = 32-char message
show_msg:
        ld a,(bank_cur)
        push af
        call bank1
        ld de,STATROW
        ld bc,32
        ldir
        pop af
        call bank_set
        ld a,150
        ld (msg_t),a
        ret
msg_tick:
        ld a,(msg_t)
        or a
        ret z
        dec a
        ld (msg_t),a
        ret nz
        jp draw_status

; ---------------------------------------------------------------------
dec0:   ld a,(hl)
        or a
        ret z
        dec (hl)
        ret

rnd_seed: dw $ACE1
rnd:    push hl
        ld hl,(rnd_seed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (rnd_seed),hl
        pop hl
        ret
