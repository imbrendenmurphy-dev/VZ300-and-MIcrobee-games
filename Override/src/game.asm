; =====================================================================
;  game.asm - game flow: ships, decks, the frame loop, events
; =====================================================================

; trampoline into the front end (upper bank 0):  call fe_call : dw routine
; A and HL pass in, A comes back. Interrupts must already be off.
fe_call:
            ld (fc_a),a
            ld (fc_hl),hl
            pop hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            push hl                 ; return address
            ld a,(cur_map)
            push af
            ld hl,.back
            push hl
            push de                 ; target
            ld a,MAP_STORE
            call setmap
            ld a,(fc_a)
            ld hl,(fc_hl)
            ret
.back:      ld (fc_a),a
            pop af
            call setmap
            ld a,(fc_a)
            ret

; leave game mode (interrupt copy) for a front-end screen
game_off:
            ld a,(gm_on)
            or a
            ret z
            call wait_bb
            di
            xor a
            ld (gm_on),a
            call snd_off
            call snd_hush
            ld a,LATCH_GAME
            ld (LATCH),a
            ret

; back to game mode
game_on:
            call init_im2
            ld a,1
            ld (gm_on),a
            ld (hud_all),a
            ret

; ---------------------------------------------------------------------
; game_new: A = 1 for the attract demo. Returns when the game (or the
; demo) is over, with the caller's mapping.
game_new:
            ld (demo),a
            ld a,(cur_map)
            ld (gn_map),a
            ld (gn_sp),sp
            xor a
            ld (ship),a
            ld (gm_on),a
            call new_run
            ld hl,0
            ld (demo_t),hl
            ld a,1
            ld (sfx_on),a
            ld a,(demo)
            or a
            jr z,.ship
            ld a,(demo_ship)        ; the demo tours the ships in turn
            ld (ship),a
.ship:      call ship_enter
            jp c,game_exit
            call game_loop          ; returns at game over / end of demo
game_exit:
            call game_off
            ld sp,(gn_sp)
            ld a,(gn_map)
            jp setmap

; a fresh run: no score, three probes, starting as the bare probe
new_run:
            xor a
            ld (score),a
            ld (score+1),a
            ld (score+2),a
            ld (plr+O_TYPE),a
            ld a,3
            ld (lives),a
            ret

; ---------------------------------------------------------------------
; ship_enter: load ship (ship) and start on its first deck
ship_enter:
            ld a,MAP_GAME
            call setmap
            call gm_stop            ; the ship's tune starts on its first deck
            call snd_hush
            ld a,(ship)
            add a,'1'
            ld (fn_ship+3),a
            ld hl,fn_ship
            call load_file
            ret c
            ; every deck starts full of droids
            ld hl,deck_alive
            ld b,16
.cl:        ld (hl),0
            inc hl
            djnz .cl
            ld a,(shipinfo+SI_NDECKS)
            ld b,a
            ld ix,shipinfo+SI_DECKS
            ld hl,deck_alive
.d:         push bc
            ld a,(ix+SD_NDROIDS)
            ld de,0
            or a
            jr z,.z
            ld b,a
            ld de,1
.sh:        sla e
            rl d
            djnz .sh
            dec de                  ; (1 << n) - 1
.z:         ld (hl),e
            inc hl
            ld (hl),d
            inc hl
            ld de,SDSZ
            add ix,de
            pop bc
            djnz .d
            ; the player arrives in the body they left the last ship in
            ; (the bare probe on a new run), with fresh energy
            ld a,(plr+O_TYPE)
            push af
            ld ix,plr
            ld hl,plr
            ld bc,OSZ
            xor a
            call fill
            ld a,$80
            ld (plr+O_FLAGS),a
            call slots_reset
            pop af
            ld (plr+O_TYPE),a
            ld (slot_type),a
            ld ix,plr
            call set_type
            ; ship card, then the start deck
            call game_off
            ld a,(demo)
            or a
            jr nz,.nc
            call fe_call
            dw fe_shipcard
.nc:        ld a,(shipinfo+SI_START)
            ld b,0
            call deck_enter
            or a                    ; (NC)
            ret

; ---------------------------------------------------------------------
; deck_enter: A = deck, B = lift to arrive at ($FF: same shaft as
; arr_shaft). Loads the deck file and sets everything up.
deck_enter:
            push bc
            push af
            call game_off
            ; keep the old deck's survivors
            ld a,(cur_deck)
            call alive_slot
            ld de,(cur_alive)
            ld a,(deck_loaded)
            or a
            jr z,.ns
            ld (hl),e
            inc hl
            ld (hl),d
.ns:        pop af
            ld (cur_deck),a
            add a,'0'
            ld (fn_deck+5),a
            ld a,(ship)
            add a,'1'
            ld (fn_deck+3),a
            ld a,MAP_GAME
            call setmap
            ld hl,MAP               ; clear the map (void beyond the deck)
            ld bc,MAPW*MAPH
            xor a
            call fill
            ld hl,fn_deck
            call load_file
            pop bc
            jp c,load_fail
            ld a,1
            ld (deck_loaded),a
            ld a,(cur_deck)
            call alive_slot
            ld e,(hl)
            inc hl
            ld d,(hl)
            ld (cur_alive),de
            ld a,(dinfo+DI_W)
            ld (deck_w),a
            ld a,(dinfo+DI_H)
            ld (deck_h),a
            ; arrival lift: the one on shaft arr_shaft, else the first
            ld a,b
            cp $FF
            jr nz,.lb
            ld a,(dinfo+DI_NLIFTS)
            ld b,a
            ld c,0
            ld hl,dinfo+DI_LIFTS
.fs:        ld a,(arr_shaft)
            cp (hl)
            jr z,.found
            inc hl
            inc hl
            inc hl
            inc c
            djnz .fs
            ld c,0
.found:     ld a,c
.lb:        ld (arr_lift),a
            ld l,a
            add a,a
            add a,l
            ld e,a
            ld d,0
            ld hl,dinfo+DI_LIFTS
            add hl,de
            ld a,(hl)
            ld (arr_shaft),a
            inc hl
            ld a,(hl)               ; tx
            inc hl
            ld c,(hl)               ; ty
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            inc hl
            ld (plr+O_XL),hl
            ld a,c
            add a,a
            add a,c
            add a,a
            add a,2
            ld (plr+O_Y),a
            xor a
            ld (plr+O_VX),a
            ld (plr+O_VY),a
            ld (p_tmode),a
            ld (p_held),a
            ld (event),a
            ld a,$80
            ld (plr+O_FLAGS),a
            ld a,40
            ld (plr+O_INV),a
            ; set up the deck
            call door_scan
            ld a,(plr+O_TYPE)
            call slots_reset
            ld a,(plr+O_TYPE)
            ld (slot_type),a
            ld b,1
            ld d,0
            call build_type
            call droids_spawn
            call shots_clear
            call fx_clear
            call set_tileset
            call camera
            call ring_full
            ld hl,dinfo+DI_NAME
            call show_msg
            ld a,(shipinfo+SI_NDECKS)   ; each ship has its own tune, and
            dec a                   ; another for its bottom (engine) deck
            ld b,a
            ld a,(cur_deck)
            cp b
            ld a,0
            jr nz,.tune
            inc a
.tune:      call gm_play
            jp game_on

; HL = this deck's alive word (A = deck)
alive_slot:
            add a,a
            ld e,a
            ld d,0
            ld hl,deck_alive
            add hl,de
            ret

; lights out on cleared decks
set_tileset:
            ld hl,tiles_norm
            ld a,(cur_alive)
            ld b,a
            ld a,(cur_alive+1)
            or b
            jr nz,.s
            ld hl,tiles_dim
.s:         ld (tset),hl
            ret

; ---------------------------------------------------------------------
; camera: centre on the player, clamped to the deck
camera:
            ld hl,(plr+O_XL)
            ld de,6-64
            add hl,de
            bit 7,h
            jr z,.x1
            ld hl,0
.x1:        ex de,hl
            ld a,(deck_w)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld bc,-128
            add hl,bc               ; max cam_x
            or a
            sbc hl,de
            jr nc,.x2
            add hl,de
            ex de,hl
            jr .x3
.x2:        ex de,hl                ; (DE was within range)
            add hl,de
            or a
            sbc hl,de
.x3:        ld (cam_x),hl
            ; y
            ld a,(plr+O_Y)
            sub 27-4
            jr nc,.y1
            xor a
.y1:        ld b,a
            ld a,(deck_h)
            ld c,a
            add a,a
            add a,c
            add a,a
            sub VIEWROWS            ; max cam_y
            cp b
            jr c,.y2
            ld a,b
.y2:        ld (cam_y),a
            ret

; ---------------------------------------------------------------------
; the frame loop
game_loop:
            xor a
            ld (event),a
.frame:     call read_input
            call snd_pt
            ld a,(demo)
            or a
            jr z,.real
            ld a,(in_now)           ; any key ends the demo
            and K_ANY
            jp nz,demo_quit
            call autopilot
            ld hl,(demo_t)
            inc hl
            ld (demo_t),hl
            ld de,DEMO_FRAMES
            or a
            sbc hl,de
            jp nc,demo_quit
            jr .go
.real:      ld a,(in_new)
            and K_PAUSE
            call nz,pause
.go:        call player_update
            call droids_update
            call shots_update
            call fx_update
            ld a,(frames)
            and 3
            call z,door_update
            call camera
            call ring_update
            call sound_tick
            call wait_bb
            call win_copy
            call draw_droids
            call draw_player
            call draw_shots
            call draw_fx
            call snd_pt
            call hud_update
            call present
            ld a,(plr+O_FLAGS)      ; a dead player always comes first,
            rla                     ; whatever else happened (or didn't)
            jr nc,.dead
            ld a,(event)
            or a
            jr z,.frame
            ld b,a
            xor a
            ld (event),a
            ld a,b
            cp EV_TRANSFER
            jp z,ev_transfer
            cp EV_LIFT
            jp z,ev_lift
            cp EV_CONSOLE
            jp z,ev_console
            cp EV_DEATH
            jp z,ev_death
            cp EV_CLEARED
            jp z,ev_cleared
            jp .frame
.dead:      xor a
            ld (event),a
            jp ev_death

demo_quit:
            ld a,(demo_ship)
            inc a
            cp NSHIPS
            jr c,.s
            xor a
.s:         ld (demo_ship),a
            ret

pause:
            call wait_bb
            call snd_hush
            ld hl,msg_pause
            call show_msg
            ld a,250
            ld (msg_t),a
.w:         call hud_update
            ld a,(hud_dirty)
            or a
            jr z,.nd
            ld a,1
            ld (ready),a
.nd:        call wait_bb
            ld a,2
            call wait_fields
            call read_input
            ld a,(in_new)
            and K_PAUSE|K_FIRE
            jr z,.w
            xor a
            ld (msg_t),a
            inc a
            ld (hud_n),a
            ret

; ---------------------------------------------------------------------
ev_transfer:
            call game_off
            ld ix,(xfer_obj)
            ld a,(ix+O_TYPE)
            ld (xf_enemy),a
            ld a,(plr+O_TYPE)
            ld (xf_mine),a
            call fe_call
            dw fe_transfer          ; A = 1 won, 0 lost, 2 deadlock
            ld (xf_result),a
            call slot7_fix
            xor a                   ; link mode ends with the duel
            ld (p_tmode),a
            ld (p_held),a
            ld hl,(demo_t)          ; a duel counts towards the demo's length
            ld de,200
            add hl,de
            ld (demo_t),hl
            ld a,(xf_result)
            ld ix,(xfer_obj)
            or a
            jr z,.lost
            cp 2
            jr z,.dead
            ; won: take the droid's body where it stands
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld (plr+O_XL),hl
            ld a,(ix+O_Y)
            ld (plr+O_Y),a
            ld a,(ix+O_SPAWN)
            call kill_bit
            ld (ix+O_FLAGS),0
            ld a,(plr+O_TYPE)       ; the old body burns out
            or a
            jr z,.nob
            ld hl,(plr+O_XL)
            ld a,(plr+O_Y)
            call fx_boom
.nob:       ld a,(ix+O_TYPE)
            push af
            call add_type_score
            pop af
            call become
            ld a,40
            ld (plr+O_INV),a
            ld hl,msg_linked
            call show_msg
            call game_on
            call check_cleared      ; (keep the event it may set)
            jp game_loop.frame
.dead:      ld hl,msg_deadlock
            call show_msg
            ld a,60
            ld (plr+O_INV),a
            ld (ix+O_RAM),60
            call game_on
            jp game_loop
.lost:      call game_on
            ld a,40
            ld (ix+O_RAM),a
            call host_lost          ; (the probe: a death)
            jp game_loop.frame

ev_lift:
            call game_off
            ld a,(cur_deck)
            ld (lf_deck),a
            call alive_slot         ; (the lift shows which decks are clear)
            ld de,(cur_alive)
            ld (hl),e
            inc hl
            ld (hl),d
            ld a,(arr_lift)          ; which pad are we on? the nearest one
            call nearest_lift
            ld (lf_shaft),a
            ld (arr_shaft),a
            call fe_call
            dw fe_lift              ; A = chosen deck
            ld hl,cur_deck
            cp (hl)
            jr z,.same
            ld b,$FF
            call deck_enter
            jp game_loop
.same:      call game_on
            ld a,20
            ld (plr+O_INV),a
            jp game_loop

; A = shaft of the lift pad under the player
nearest_lift:
            ld a,(dinfo+DI_NLIFTS)
            ld b,a
            ld hl,dinfo+DI_LIFTS
            ld de,$FFFF
            ld (nl_best),de
            xor a
            ld (nl_shaft),a
.l:         push bc
            ld c,(hl)               ; shaft
            inc hl
            ld a,(hl)
            inc hl
            inc hl
            push hl
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,(plr+O_XL)
            or a
            sbc hl,de
            call abs_hl
            ld de,(nl_best)
            or a
            sbc hl,de
            jr nc,.w
            add hl,de
            ld (nl_best),hl
            ld a,c
            ld (nl_shaft),a
.w:         pop hl
            pop bc
            djnz .l
            ld a,(nl_shaft)
            ret

ev_console:
            call game_off
            call fe_call
            dw fe_console
            call slot7_fix
            call game_on
            ld a,10
            ld (plr+O_INV),a
            jp game_loop

ev_death:
            ld a,(lives)
            dec a
            ld (lives),a
            jr z,.over
            ; a new probe beams in at the arrival lift
            ld a,30
            call wait_fields_game
            call game_off
            ld a,(cur_deck)
            ld b,a
            ld a,(arr_lift)
            ld c,a
            ld a,b
            ld b,c
            ld ix,plr
            xor a
            ld (plr+O_TYPE),a
            call set_type
            ld a,(cur_deck)
            call deck_enter
            ld hl,msg_newprobe
            call show_msg
            ld a,100
            ld (plr+O_INV),a
            xor a
            ld (event),a
            call check_cleared      ; (in case the last droid went with you)
            jp game_loop.frame
.over:      ld a,40
            call wait_fields_game
            call game_off
            ld a,(demo)
            or a
            ret nz
            call fe_call
            dw fe_gameover
            or a                    ; A = 1: continue on this ship
            ret z
            call new_run            ; from its top deck, with a new score
            xor a
            ld (deck_loaded),a
            call ship_enter
            jp c,game_exit
            jp game_loop

; keep showing frames for a moment (A = fields)
wait_fields_game:
            ld (wfg_n),a
.l:         call droids_update
            call shots_update
            call fx_update
            call sound_tick
            call wait_bb
            call win_copy
            call draw_droids
            call draw_shots
            call draw_fx
            call snd_pt
            call hud_update
            call present
            ld a,(wfg_n)
            sub 2
            ld (wfg_n),a
            jr nc,.l
            ret

; a droid is gone: was it the last on this deck?
check_cleared:
            ld hl,(cur_alive)
            ld a,h
            or l
            ret nz
            ld a,EV_CLEARED
            ld (event),a
            ret

ev_cleared:
            ld de,$1000             ; 1000 points
            call add_score
            ld a,SFX_CLEAR
            call sfx
            ld a,(cur_deck)
            call alive_slot
            xor a
            ld (hl),a
            inc hl
            ld (hl),a
            call wait_bb
            call set_tileset        ; lights out
            call ring_full
            ld hl,msg_cleared
            call show_msg
            ; every deck clear?
            ld a,(shipinfo+SI_NDECKS)
            ld b,a
            ld hl,deck_alive
.l:         ld a,(hl)
            inc hl
            or (hl)
            inc hl
            jp nz,game_loop
            djnz .l
            ; ship secured
            ld a,60
            call wait_fields_game
            call game_off
            ld de,$5000
            call add_score
            ld a,(lives)            ; and a spare probe (up to five)
            cp 5
            jr nc,.nl
            inc a
            ld (lives),a
.nl:        ld a,(demo)
            or a
            ret nz
            call fe_call
            dw fe_shipdone
            ld a,(ship)
            inc a
            ld (ship),a
            cp NSHIPS
            jr nc,.won
            xor a
            ld (deck_loaded),a
            call ship_enter
            jp c,game_exit
            jp game_loop
.won:       call fe_call
            dw fe_ending
            ret

; ---------------------------------------------------------------------
; add_score: DE = BCD points (4 digits) added to the 6-digit score
add_score:
            ld hl,score+2
            ld a,(hl)
            add a,e
            daa
            ld (hl),a
            dec hl
            ld a,(hl)
            adc a,d
            daa
            ld (hl),a
            dec hl
            ld a,(hl)
            adc a,0
            daa
            ld (hl),a
            ld a,1
            ld (hud_s),a
            ret

; ---------------------------------------------------------------------
; load_file: HL = '"NAME"',0 -> NC loaded, C failed
load_file:
            call sd_load
            ret

load_fail:
            ld hl,str_nofile
            jp fatal

fn_ship:    db '"OV1"',0
fn_deck:    db '"OV1D0"',0
msg_pause:  db "PAUSED",0
msg_linked: db "LINK ESTABLISHED",0
msg_deadlock: db "DEADLOCK",0
msg_host:   db "HOST DESTROYED",0
msg_newprobe: db "NEW PROBE ONLINE",0
msg_cleared: db "DECK CLEARED",0
msg_low:    db "LOW ENERGY",0
