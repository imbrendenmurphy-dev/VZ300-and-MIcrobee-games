; =====================================================================
;  GAME: levels, moving, acting on what is in front, the turn
;
;  Level block B header: +0 backdrop, +2 wall table, +4 level
;  definition, +6 glyph count, +8 action table, +10 text table.
;  Level definition: start x, y, facing; 16 x 16 square types; items
;  (count, then offset lo/hi, item); monsters (count, offset lo/hi,
;  type); decorations (count, then 8 bytes as in DECOR); step triggers
;  (count, offset lo/hi, action).
;  MAP is 32 x 32 with the level at (8,8): offset = (y+8)*32 + x+8.
; =====================================================================
LV_STATE    EQU $2000       ; each level's saved state: 8K in BLK_STATE

; ---------------------------------------------------------------------
new_game:
        ld hl,hero_init
        ld de,hp
        ld bc,hero_init_end-hero_init
        ldir
        xor a
        ld (king_phase),a
        ld (visited),a
        ld (level),a
        ld (dead),a
        ld (won),a
        ld (runestep),a
        ld hl,0
        ld (turns),hl
        ld (kills),hl
        ld a,255
        ld (arrive),a           ; arrive at the level's start
        call log_clear
        jp enter_level

; hp, hpmax, mp, mpmax, lvl, xp, atk, def, gold, potions, keys x3,
; sigils, spells, weapon, armour
hero_init:
        db 30,30,6,6,1
        dw 0
        db 3,1
        dw 0
        db 1,0,0,0,0,0,0,0
hero_init_end:

; ---------------------------------------------------------------------
;  enter_level: (level) 0..3; (arrive) 255 = the level's start, 0 = by
;  stairs down (arrive on the next level's up stairs), 1 = by stairs up
;  (arrive on the down stairs), 2 = fell through a pit (at (pitx,pity))
; ---------------------------------------------------------------------
enter_level:
        call snd_quiet
        call display_off
        ld a,(level)
        add a,a
        add a,BLK_LVL
        call blk_port
        ld (lvl_mpa),a
        ld a,(level)
        add a,a
        add a,BLK_LVL+1
        call blk_port
        ld (lvl_mpb),a
        ; the level's tiles into PCG banks 0-13
        ld a,(lvl_mpb)
        out (P_MEM),a
        ld de,(6)
        ld a,(lvl_mpa)
        out (P_MEM),a
        ld hl,-14*128
        add hl,de
        jr nc,.small            ; up to 1792: banks 0-13
        push hl
        ld de,14*128
        ld hl,0
        xor a
        call pcg_load
        pop de                  ; the rest: bank 15 from slot 0
        ld hl,14*128*10
        ld a,BK_UI
        call pcg_load
        jr .loaded
.small: ld hl,0
        xor a
        call pcg_load
.loaded:
        ; its state: saved, or new
        ld a,(level)
        ld b,a
        inc b
        ld a,(visited)
.vb:    rrca
        djnz .vb
        jr c,.restore
        call level_init
        ld a,(level)
        ld b,a
        inc b
        ld a,$80
.vs:    rlca
        djnz .vs
        ld hl,visited
        or (hl)
        ld (hl),a
        jr .place
.restore:
        call state_restore
.place: call place_player
        call ui_level
        call view_now
        call display_on
        ld a,(level)
        jp mus_level

; A = block -> A = its port 50h value (ROMs off, video window at F000)
blk_port:
        push bc
        ld b,a
        and 3
        xor 2
        ld c,a
        ld a,b
        and $1C
        rlca
        rlca
        rlca
        or c
        or 4
        pop bc
        ret

; a new level from its definition
level_init:
        ld hl,MAP
        ld de,MAP+1
        ld bc,$3FF
        ld (hl),T_WALL
        ldir
        ld hl,ITEMMAP
        ld de,ITEMMAP+1
        ld bc,$3FF
        ld (hl),0
        ldir
        ld hl,MONMAP
        ld de,MONMAP+1
        ld bc,$3FF
        ld (hl),0
        ldir
        ld hl,SEEN
        ld de,SEEN+1
        ld bc,$FF
        ld (hl),0
        ldir
        ld hl,MONS
        ld de,MONS+1
        ld bc,$FF
        ld (hl),0
        ldir
        ld a,(lvl_mpb)
        out (P_MEM),a
        ld hl,(4)
        inc hl                  ; (start x, y, facing: place_player)
        inc hl
        inc hl
        ld de,MAP+8*32+8
        ld b,16
.row:   push bc
        ld bc,16
        ldir
        ex de,hl
        ld bc,16
        add hl,bc
        ex de,hl
        pop bc
        djnz .row
        ; items
        ld b,(hl)
        inc hl
        ld a,b
        or a
        jr z,.mon
.it:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld hl,ITEMMAP
        add hl,de
        ld (hl),a
        pop hl
        djnz .it
.mon:   ld b,(hl)
        inc hl
        ld a,b
        ld (nmons),a
        or a
        jr z,.dec
        ld ix,MONS
        ld c,1
.mo:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (ix+M_TYPE),a
        ld (ix+M_POS),e
        ld (ix+M_POS+1),d
        push hl
        push de
        call mon_stats          ; A = type -> HL = its stats
        ld a,(hl)
        ld (ix+M_HP),a
        pop de
        ld hl,MONMAP
        add hl,de
        ld (hl),c
        pop hl
        ld de,16
        add ix,de
        inc c
        djnz .mo
.dec:   ld a,(hl)
        ld (ndecor),a
        inc hl
        ld de,DECOR
        or a
        jr z,.dend
        add a,a
        add a,a
        add a,a
        ld c,a
        ld b,0
        ldir
.dend:  ld a,$FF
        ld (de),a
        inc de
        ld (de),a
        ; step triggers
        ld a,(hl)
        add a,a
        add a,(hl)              ; 3 bytes each
        inc a
        ld c,a
        ld b,0
        ld de,TRIG
        ldir
        ret

; put the player where (arrive) says
place_player:
        ld a,(arrive)
        cp 255
        jr z,.start
        cp 2
        jr z,.pit
        ; by stairs: find the matching stairs in MAP
        or a
        ld a,T_UP
        jr z,.find
        ld a,T_DOWN
.find:  ld hl,MAP
        ld bc,$400
        cpir
        dec hl
        ld (ppos),hl
        ; face the open square next to them
        ld b,4
.f:     ld a,b
        dec a
        ld (facing),a
        push bc
        call ahead
        pop bc
        ld a,(hl)
        ld e,a
        ld d,high(passtab)
        ld a,low(passtab)
        add a,e
        ld e,a
        ld a,(de)
        or a
        ret nz
        djnz .f
        ret
.pit:   ld hl,(pitpos)
        ld (ppos),hl
        ret
.start: ld a,(lvl_mpb)
        out (P_MEM),a
        ld hl,(4)
        ld e,(hl)               ; x
        inc hl
        ld d,(hl)               ; y
        inc hl
        ld a,(hl)
        ld (facing),a
        ld a,d
        add a,8
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,e
        add a,8
        ld e,a
        ld d,0
        add hl,de
        ld de,MAP
        add hl,de
        ld (ppos),hl
        ret

; save / restore the live level (MAP, ITEMMAP, MONMAP, MONS, DECOR,
; SEEN, nmons, ndecor) in BLK_STATE at level * 8K
state_addr:
        ld a,(level)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        ld d,a
        ld e,0                  ; level * 8K
        ld a,MP_STATE
        out (P_MEM),a
        ret

state_save:
        call state_addr
        ld hl,MAP
        ld bc,$C00              ; MAP, MONMAP, ITEMMAP
        ldir
        ld hl,MONS
        ld bc,$200              ; MONS, DECOR
        ldir
        ld hl,SEEN
        ld bc,$100
        ldir
        ld a,(nmons)
        ld (de),a
        inc de
        ld a,(ndecor)
        ld (de),a
        ld a,(lvl_mpb)
        out (P_MEM),a
        ret

state_restore:
        call state_addr
        ex de,hl
        ld de,MAP
        ld bc,$C00
        ldir
        ld de,MONS
        ld bc,$200
        ldir
        ld de,SEEN
        ld bc,$100
        ldir
        ld a,(hl)
        ld (nmons),a
        inc hl
        ld a,(hl)
        ld (ndecor),a
        ; the step triggers come from the level definition again
        ld a,(lvl_mpb)
        out (P_MEM),a
        ld hl,(4)
        ld de,3+256
        add hl,de
        ld a,(hl)               ; items
        ld b,a
        add a,a
        add a,b
        inc a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)               ; monsters
        ld b,a
        add a,a
        add a,b
        inc a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)               ; decorations
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        inc hl
        ex de,hl
        ld hl,(4)
        ld bc,3+256
        add hl,bc
        push de
        ld a,(hl)
        ld b,a
        add a,a
        add a,b
        inc a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        ld b,a
        add a,a
        add a,b
        inc a
        ld e,a
        ld d,0
        add hl,de
        pop de
        add hl,de               ; the triggers
        ld a,(hl)
        add a,a
        add a,(hl)
        inc a
        ld c,a
        ld b,0
        ld de,TRIG
        ldir
        ret

; HL = the square in front (facing)
ahead:  ld a,(facing)
ahead_d:                        ; A = direction
        add a,a
        ld e,a
        ld d,0
        ld hl,fwdtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(ppos)
        add hl,de
        ret

; compose the view and commit it (waits for the commit)
view_refresh:
        push ix
        push iy
        call commit_wait
        call compose
        call commit_start
        call mark_seen
        call commit_wait
        pop iy
        pop ix
        ret

; compose and copy at once (display off)
view_now:
        call compose
        call mark_seen
        xor a
.r:     push af
        call commit_row
        pop af
        inc a
        cp VH
        jr nz,.r
        ld a,(vispage)
        xor 1
        call show_page
        ; the other page too, so both carry the view
        xor a
.r2:    push af
        call commit_row
        pop af
        inc a
        cp VH
        jr nz,.r2
        xor a
        ld (cm_state),a
        ret

; ---------------------------------------------------------------------
;  play: the turn loop. Returns when the game ends.
; ---------------------------------------------------------------------
play:
.loop:  call frame
        ld a,(won)
        or a
        jp nz,victory
        ld a,(dead)
        or a
        jp nz,.died
        ld a,(cm_state)
        or a
        jr nz,.loop             ; the last view is still going up
        call handle_cmd
        call handle_move
        jr .loop
.died:  call death
        ret c                   ; end the game
        jr .loop

; movement keys: newly pressed, or held (repeating)
handle_move:
        ld a,(repcnt)
        or a
        jr z,.r
        dec a
        ld (repcnt),a
.r:     ld a,(pressed)
        ld c,a
        xor a
        ld (pressed),a
        ld a,(repcnt)
        or a
        jr nz,.new
        ld a,(held)
        or c
        ld c,a
.new:   ld a,c
        or a
        ret z
        bit IN_ACT,c
        jp nz,act
        bit IN_LEFT,c
        jr nz,.tl
        bit IN_RIGHT,c
        jr nz,.tr
        ld b,10
        bit IN_FWD,c
        ld a,(facing)
        jr nz,.step
        bit IN_BACK,c
        add a,2
        jr nz,.step
        bit IN_SLEFT,c
        add a,1
        jr nz,.step
        bit IN_SRIGHT,c
        ret z
        add a,2
.step:  and 3
        push bc
        call try_step
        pop bc
        ld a,b
        ld (repcnt),a
        ret
.tl:    ld a,(facing)
        dec a
        jr .turn
.tr:    ld a,(facing)
        inc a
.turn:  and 3
        ld (facing),a
        ld a,9
        ld (repcnt),a
        ld hl,sfx_turn
        call sfx
        call ui_compass
        jp view_refresh

; A = direction: step that way if you can (a turn passes)
try_step:
        ld (stepdir),a
        call ahead_d
        ld a,(hl)
        cp T_ILLUS
        jr z,.go
        ld e,a
        ld d,high(passtab)
        ld a,low(passtab)
        add a,e
        ld e,a
        ld a,(de)
        or a
        jr z,.bump
        push hl
        ld de,MONMAP-MAP
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr nz,.blocked
.go:    ld (ppos),hl
        ld hl,sfx_step
        call sfx
        call view_refresh
        call on_enter
        jp end_turn
.blocked:
        ld hl,sfx_bump
        call sfx
        ld hl,t_blocked
        jp log_msg
.bump:  ld a,(hl)
        ld hl,sfx_bump
        call sfx
        cp T_DOOR
        ld hl,t_door_shut
        jp z,log_msg
        cp T_GATE
        ld hl,t_gate_shut
        jp z,log_msg
        cp T_LOCK1
        jp c,.nomsg
        cp T_LOCK3+1
        ld hl,t_locked
        jp c,log_msg
.nomsg: ret

stepdir:    db 0

; ---------------------------------------------------------------------
;  SPACE: act on what is in front
; ---------------------------------------------------------------------
act:    ld a,15
        ld (repcnt),a
        call ahead
        push hl
        ld de,MONMAP-MAP
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jp nz,attack            ; A = monster + 1
        ; a decoration on the face we look at?
        push hl
        ld a,(facing)
        add a,2
        and 3
        ld (dp_side),a
        call find_decor_e       ; -> A = 0, or IX = the entry
        pop hl
        or a
        jp nz,use_decor
        ld a,(hl)
        cp T_DOOR
        jr z,.door
        cp T_LOCK1
        jr c,.n1
        cp T_LOCK3+1
        jr c,.lock
.n1:    cp T_SEAL
        jp z,use_seal
        cp T_GATE
        ld hl,t_gate_shut
        jp z,log_msg
        cp T_WALL
        jr z,.search
        cp T_HIDDEN
        jr z,.search
        cp T_ILLUS
        jr z,.illus
        ret
.door:  ld (hl),T_FLOOR
        ld hl,sfx_door
        call sfx
        ld hl,t_door_open
        call log_msg
        call view_refresh
        jp end_turn
.lock:  sub T_LOCK1
        ld e,a
        ld d,0
        push hl
        ld hl,keys
        add hl,de
        ld a,(hl)
        or a
        jr z,.nokey
        dec (hl)
        pop hl
        ld (hl),T_FLOOR
        push de
        ld hl,sfx_unlock
        call sfx
        pop de
        ld hl,t_unlock_tab
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call log_msg
        call ui_stats
        call view_refresh
        jp end_turn
.nokey: pop hl
        ld hl,t_nokey_tab
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(hl)
        jp log_msg
.search:
        ld hl,t_wall
        jp log_msg
.illus: ld hl,t_illus
        jp log_msg

; HL = square address; (dp_side) set -> A = 1 and IX = the decoration
; entry, or A = 0
find_decor_e:
        ld de,MAP
        or a
        sbc hl,de
        ld ix,DECOR
        ld a,(ndecor)
        or a
        ret z
        ld b,a
.l:     ld a,(ix+0)
        cp l
        jr nz,.n
        ld a,(ix+1)
        cp h
        jr nz,.n
        ld a,(dp_side)
        cp (ix+2)
        jr nz,.n
        ld a,1
        ret
.n:     ld de,8
        add ix,de
        djnz .l
        xor a
        ret

; ---------------------------------------------------------------------
;  after every action that takes a turn
; ---------------------------------------------------------------------
end_turn:
        ld hl,(turns)
        inc hl
        ld (turns),hl
        call monsters_turn
        jp ui_stats

; on entering a square: items, stairs, pits, plates, portals, spinners,
; step triggers
on_enter:
        ld hl,(ppos)
        ld de,ITEMMAP-MAP
        add hl,de
        ld a,(hl)
        or a
        call nz,pickup
        ld hl,(ppos)
        ld a,(hl)
        cp T_DOWN
        jp z,go_down
        cp T_UP
        jp z,go_up
        cp T_PIT
        jp z,fall_pit
        cp T_TELE
        jp z,teleport
        cp T_SPIN
        jp z,spinner
        jp step_trigger

go_down:
        ld hl,t_down
        call log_msg
        ld a,(level)
        cp 3
        ret z
        call state_save
        ld a,(level)
        inc a
        ld (level),a
        xor a
        ld (arrive),a
        ld hl,sfx_stairs
        call sfx
        jp enter_level

go_up:  ld a,(level)
        or a
        jr nz,.up
        ld hl,t_noup
        jp log_msg
.up:    call state_save
        ld hl,level
        dec (hl)
        ld a,1
        ld (arrive),a
        ld hl,sfx_stairs
        call sfx
        ld hl,t_up
        call log_msg
        jp enter_level

fall_pit:
        ld hl,sfx_fall
        call sfx
        ld hl,t_pit
        call log_msg
        ld a,6
        call hurt_player
        ld a,(level)
        cp 3
        ret z
        ; land at the same place one level down
        ld hl,(ppos)
        ld (pitpos),hl
        call state_save
        ld hl,level
        inc (hl)
        ld a,2
        ld (arrive),a
        call enter_level
        ; never inside a wall
        ld hl,(ppos)
        ld a,(hl)
        or a
        ret z
        ld (hl),T_FLOOR
        jp view_refresh

teleport:
        ld hl,sfx_portal
        call sfx
        ld hl,t_portal
        call log_msg
        jp step_trigger         ; its trigger says where to

spinner:
        call rnd
        and 3
        ld (facing),a
        ld hl,sfx_spin
        call sfx
        ld hl,t_spin
        call log_msg
        call ui_compass
        jp view_refresh

; the step triggers: TRIG = count, then offset lo, hi, action
step_trigger:
        ld hl,(ppos)
        ld de,MAP
        or a
        sbc hl,de
        ex de,hl
        ld hl,TRIG
        ld b,(hl)
        inc hl
        ld a,b
        or a
        ret z
.l:     ld a,(hl)
        inc hl
        cp e
        jr nz,.n1
        ld a,(hl)
        cp d
        jr nz,.n1
        inc hl
        ld a,(hl)
        jp run_action
.n1:    inc hl
        inc hl
        djnz .l
        ret

; ---------------------------------------------------------------------
;  items
; ---------------------------------------------------------------------
; HL = the item's ITEMMAP square, A = item
pickup: ld (hl),0
        dec a
        ld e,a
        ld d,0
        ld hl,pickup_tab
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,e
        inc a
        jp (hl)

pickup_tab:
        dw pk_gold, pk_potion, pk_key, pk_key, pk_key, pk_sword, pk_armour
        dw pk_fire, pk_mend, pk_sigil, pk_gem, pk_ring, pk_vial, pk_bones

pk_gold:
        call rnd
        and 15
        add a,10
        jr pk_gold_a
pk_gem: ld a,100
pk_gold_a:
        push af
        ld e,a
        ld d,0
        ld hl,(gold)
        add hl,de
        ld (gold),hl
        ld hl,sfx_coin
        call sfx
        pop af
        ld l,a
        ld h,0
        ld de,msgbuf
        push de
        ld bc,t_gold_a
        call fmt_num_msg
        pop hl
        jp ui_stats
pk_potion:
        ld hl,potions
        inc (hl)
        ld hl,t_potion
        jp pk_item
pk_key: sub 3
        ld e,a
        ld d,0
        ld hl,keys
        add hl,de
        inc (hl)
        ld hl,t_key_tab
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr pk_item
pk_sword:
        ld hl,atk
        inc (hl)
        inc (hl)
        ld hl,weapon
        inc (hl)
        ld hl,t_sword
        jr pk_fanfare
pk_armour:
        ld hl,def
        inc (hl)
        inc (hl)
        ld hl,armour
        inc (hl)
        ld hl,t_armour
        jr pk_fanfare
pk_fire:
        ld hl,spells
        set 0,(hl)
        ld hl,t_fire
        jr pk_fanfare
pk_mend:
        ld hl,spells
        set 1,(hl)
        ld hl,t_mend
        jr pk_fanfare
pk_sigil:
        ld a,(level)
        ld b,a
        inc b
        ld a,$80
.s:     rlca
        djnz .s
        ld hl,sigils
        or (hl)
        ld (hl),a
        ld hl,t_sigil
        push hl
        ld hl,sfx_sigil
        call sfx
        pop hl
        call log_msg
        jp ui_stats
pk_ring:
        ld a,(hpmax)
        add a,5
        ld (hpmax),a
        ld a,(hp)
        add a,5
        ld (hp),a
        ld hl,t_ring
        jr pk_fanfare
pk_vial:
        ld a,(mpmax)
        ld (mp),a
        ld hl,t_vial
        jr pk_item
pk_bones:
        ld hl,(ppos)
        ld de,ITEMMAP-MAP
        add hl,de
        ld (hl),14              ; bones stay
        ld hl,t_bones
        jp log_msg
pk_item:
        push hl
        ld hl,sfx_pickup
        call sfx
        pop hl
        call log_msg
        jp ui_stats
pk_fanfare:
        push hl
        ld hl,sfx_fanfare
        call sfx
        pop hl
        call log_msg
        jp ui_stats

; ---------------------------------------------------------------------
;  decorations: IX = the entry (offset lo, hi, side, sprite, kind,
;  param, state, -)
; ---------------------------------------------------------------------
D_LEVER     EQU 1
D_BUTTON    EQU 2
D_RUNE      EQU 3
D_TORCH     EQU 4
D_FOUNT     EQU 5
D_TABLET    EQU 6
D_ALCOVE    EQU 7

use_decor:
        ld a,(ix+4)
        cp D_LEVER
        jr z,.lever
        cp D_BUTTON
        jr z,.button
        cp D_RUNE
        jp z,.rune
        cp D_FOUNT
        jp z,.fount
        cp D_TABLET
        jp z,.tablet
        cp D_ALCOVE
        jp z,.alcove
        ld hl,t_torch
        jp log_msg
.lever: ld a,(ix+6)
        xor 1
        ld (ix+6),a
        ld a,(ix+3)
        xor 1                   ; up / down are neighbouring sprites
        ld (ix+3),a
        ld hl,sfx_lever
        call sfx
        ld a,(ix+5)
        call run_action
        call view_refresh
        jp end_turn
.button:
        ld a,(ix+6)
        or a
        ld hl,t_nothing
        jp nz,log_msg
        inc (ix+6)
        ld hl,sfx_lever
        call sfx
        ld a,(ix+5)
        call run_action
        call view_refresh
        jp end_turn
.rune:  ; plaques must be touched in order 0, 1, 2, 3 (param = place)
        ld a,(ix+6)
        or a
        ret nz                  ; already lit
        ld a,(runestep)
        cp (ix+5)
        jr nz,.wrong
        inc a
        ld (runestep),a
        ld (ix+6),1
        inc (ix+3)              ; the lit plaque is the next sprite
        ld hl,sfx_rune
        call sfx
        ld hl,t_rune_ok
        call log_msg
        call view_refresh
        ld a,(runestep)
        cp 4
        ret nz
        ; all four: the action of the last plaque's twin (param2 in +7)
        ld a,(ix+7)
        jp run_action
.wrong: ; every plaque goes dark again
        xor a
        ld (runestep),a
        ld iy,DECOR
        ld a,(ndecor)
        ld b,a
.wl:    ld a,(iy+4)
        cp D_RUNE
        jr nz,.wn
        ld a,(iy+6)
        or a
        jr z,.wn
        ld (iy+6),0
        dec (iy+3)
.wn:    ld de,8
        add iy,de
        djnz .wl
        ld hl,sfx_wrong
        call sfx
        ld hl,t_rune_bad
        call log_msg
        jp view_refresh
.fount: ld a,(ix+6)
        cp 3
        ld hl,t_fount_dry
        jp nc,log_msg
        inc (ix+6)
        ld a,(hpmax)
        ld (hp),a
        ld a,(mpmax)
        ld (mp),a
        ld hl,sfx_heal
        call sfx
        ld hl,t_fount
        call log_msg
        jp end_turn
.tablet:
        ld a,(ix+5)
        jp show_text
.alcove:
        ld a,(ix+6)
        or a
        ld hl,t_alcove_empty
        jp nz,log_msg
        ld (ix+6),1
        ld a,(ix+5)             ; the item it holds
        ld hl,0
        jp pickup_a

; A = item: give it (no square)
pickup_a:
        ld hl,dummy_sq
        jp pickup
dummy_sq:   db 0

; the sealed door: it opens for all three sigils (on the last level;
; elsewhere a vault opened by its runes)
use_seal:
        ld a,(level)
        cp 3
        ld hl,t_vault
        jp nz,log_msg
        ld a,(sigils)
        cp 7
        jr z,.open
        ld hl,t_seal
        jp log_msg
.open:  push hl
        call ahead
        ld (hl),T_FLOOR
        pop hl
        ld hl,sfx_sigil
        call sfx
        ld hl,t_seal_open
        call log_msg
        jp view_refresh

; ---------------------------------------------------------------------
;  actions (from levers, buttons, runes, step triggers)
;  Action table in the level block (+8): dw per action. An action:
;  ops until 0: 1 open (lo, hi), 2 toggle gate (lo, hi), 3 message
;  (text), 4 teleport (lo, hi, facing), 5 hide (lo, hi): make a wall,
;  6 once: the trigger fires only once (clears itself), 7 spawn (lo,
;  hi, type)
; ---------------------------------------------------------------------
run_action:
        ld (act_no),a
        ld a,(lvl_mpb)
        out (P_MEM),a
        ld a,(act_no)
        ld l,a
        ld h,0
        add hl,hl
        ld de,(8)
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
.op:    ld a,(hl)
        inc hl
        or a
        jp z,.done
        cp 1
        jr z,.open
        cp 2
        jr z,.toggle
        cp 3
        jr z,.msg
        cp 4
        jr z,.tele
        cp 5
        jr z,.hide
        cp 6
        jr z,.once
        cp 7
        jp z,.spawn
        jp .done
.open:  call .sq
        ld (de),a
        ld a,T_FLOOR
        ld (de),a
        ld a,1
        ld (act_vis),a
        jr .op
.toggle:
        call .sq
        ld a,(de)
        cp T_GATE
        ld a,T_FLOOR
        jr z,.t1
        ld a,T_GATE
.t1:    ld (de),a
        ld a,1
        ld (act_vis),a
        push hl
        ld hl,sfx_gate
        call sfx
        pop hl
        jr .op
.msg:   ld a,(hl)
        inc hl
        push hl
        call show_text
        ld a,(lvl_mpb)
        out (P_MEM),a
        pop hl
        jr .op
.tele:  call .sq
        ld a,(hl)
        inc hl
        ld (facing),a
        ld (ppos),de
        ld a,1
        ld (act_vis),a
        jr .op
.hide:  call .sq
        ld a,T_WALL
        ld (de),a
        ld a,1
        ld (act_vis),a
        jr .op
.once:  ; clear this square's step trigger
        push hl
        ld hl,(ppos)
        ld de,MAP
        or a
        sbc hl,de
        ex de,hl
        ld hl,TRIG+1
        ld a,(TRIG)
        ld b,a
.ol:    ld a,(hl)
        cp e
        jr nz,.on
        inc hl
        ld a,(hl)
        dec hl
        cp d
        jr nz,.on
        ld (hl),$FF
        inc hl
        ld (hl),$FF
        dec hl
.on:    inc hl
        inc hl
        inc hl
        djnz .ol
        pop hl
        jp .op
.spawn: call .sq
        ld a,(hl)
        inc hl
        push hl
        call spawn_mon
        pop hl
        ld a,1
        ld (act_vis),a
        jp .op
.done:  ld a,(act_vis)
        or a
        ret z
        xor a
        ld (act_vis),a
        call ui_compass
        jp view_refresh
; (hl) = offset lo, hi -> DE = square address
.sq:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,MAP
        add hl,de
        ex de,hl
        pop hl
        ret

act_no:     db 0
act_vis:    db 0
arrive:     db 0
pitpos:     dw 0

; ---------------------------------------------------------------------
;  random: a 16-bit xorshift -> A
; ---------------------------------------------------------------------
rnd:    push hl
        push de
        ld hl,(rseed)
        ld a,h
        or l
        jr nz,.s
        ld hl,$ACE1
.s:     ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; << 7
        ld a,h
        xor d
        ld d,a
        ld a,l
        xor e
        ld e,a                  ; x ^= x << 7
        ld a,d
        rra                     ; x >> 9: d >> 1
        and $7F
        xor e
        ld e,a                  ; x ^= x >> 9 (low byte part)
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; << 8
        ld a,h
        xor d
        ld h,a
        ld l,e
        ld (rseed),hl
        ld a,l
        xor h
        pop de
        pop hl
        ret

; A = n -> A = random 0..n-1 (n > 0)
rndn:   push bc
        ld b,a
        call rnd
.l:     cp b
        jr c,.d
        sub b
        jr .l
.d:     pop bc
        ret
