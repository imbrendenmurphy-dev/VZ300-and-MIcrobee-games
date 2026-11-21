; =====================================================================
;  game.asm - one game (or the attract-mode demo) from start to end
; =====================================================================

NSHIPS          equ 3
DEMO_FRAMES     equ 25*50

game:
        call mus_stop
        call sfx_stop
        xor a
        ld (demo_abort),a
        ld (pl_dead),a
        ld (event),a
        ld (xmode),a
        ld (msg_time),a
        ld (check_clear),a
        ld (clear_delay),a
        ld hl,0
        ld (score),hl
        ld (score+1),hl
        ld hl,DEMO_FRAMES
        ld (demo_time),hl
        ; the probe
        ld ix,DROIDS
        ld (ix+D_TYPE),0
        ld a,(demo)                 ; the demo pilot starts in an armed host
        or a
        jr z,.probe
        ld b,4
        call rand_below
        ld e,a
        ld d,0
        ld hl,demo_hosts
        add hl,de
        ld a,(hl)
        ld (ix+D_TYPE),a
.probe: call droid_setup
        ld a,(ix+D_TYPE)
        call roster_ptr
        ld bc,R_EN
        add hl,bc
        ld a,(hl)
        ld (ix+D_EN),a
        ld a,BURN_T
        ld (burn_time),a
        ; first ship; the demo starts on a random one
        xor a
        call ship_init
        call ship_intro
        ld a,0FFh
        ld (deck),a
        xor a
        ld (lift_shaft),a
        ld a,(demo)
        or a
        ld a,0
        jr z,.d0
        ld a,(ndecks)               ; demo: a random deck
        ld b,a
        call rand_below
.d0:    call enter_deck
        ld a,(demo)
        or a
        jr nz,.loop
        ld hl,txt_welcome
        ld a,90
        call hud_msg
.loop:  call deck_play
        ld a,(event)
        cp EV_TRANSFER
        jr z,.xfer
        cp EV_LIFT
        jr z,.lift
        cp EV_CONSOLE
        jr z,.con
        cp EV_DEAD
        jr z,.dead
        cp EV_CLEAR
        jr z,.clear
        ret                         ; EV_QUIT
.xfer:  call do_transfer
        ld a,(event)
        cp EV_QUIT
        ret z
        jr .loop
.lift:  call lift_screen            ; A = deck to go to
        ld b,a
        ld a,(event)
        cp EV_QUIT
        ret z
        ld a,b
        call enter_deck
        jr .loop
.con:   ld a,(demo)
        or a
        jr nz,.loop
        call console_screen
        call redraw_deck
        jr .loop
.dead:  ld a,(demo)
        or a
        ret nz
        jp game_over_screen
.clear: call save_droids
        call ship_clear_screen
        ld a,(ship)
        inc a
        cp NSHIPS
        jp nc,victory_screen
        call ship_init
        call ship_intro
        ld a,0FFh
        ld (deck),a
        xor a
        ld (lift_shaft),a
        call enter_deck
        jr .loop

txt_welcome: db "TRANSFER OR DESTROY",0
demo_hosts:  db 3,4,6,8             ; 218, 263, 355, 461

; ---------------------------------------------------------------------
; enter_deck: A = deck; the player arrives on the pad of lift_shaft
; ---------------------------------------------------------------------
enter_deck:
        push af
        ld a,(deck)
        cp 0FFh
        call nz,save_droids
        pop af
        call load_deck
        ; find the pad of our shaft
        ld a,(nlifts)
        ld b,a
        ld hl,LIFTS
        ld de,LIFTS                 ; fallback: the first pad
.l:     inc hl
        inc hl
        ld a,(lift_shaft)
        cp (hl)
        dec hl
        dec hl
        jr nz,.n
        ex de,hl
        jr .f
.n:     inc hl
        inc hl
        inc hl
        inc hl
        djnz .l
.f:     ex de,hl                    ; HL = pad
        ld a,(hl)
        ld (DROIDS+D_X),a
        inc hl
        ld a,(hl)
        ld (DROIDS+D_Y),a
        inc hl
        ld a,(hl)
        ld (lift_shaft),a
        xor a
        ld (xmode),a
        ld (fire_hold),a
        ld a,75
        ld (invuln),a
        ld a,0FFh
        ld (ai_target),a
        ld (ai_tnode),a
        xor a
        ld (ai_think),a
        call ai_snap
        call camera_snap
        call count_enemies
        ld (enemies_left),a
        jp redraw_deck

redraw_deck:
        ld a,BLACK
        call cls
        call hud_full
        ld a,(fieldcnt)
        ld (lastframe),a
        ld a,2                      ; a fire button still held from the
        ld (fire_hold),a            ; screen before doesn't work a lift
        ret

; ---------------------------------------------------------------------
; deck_play: run frames until something happens (event set)
; ---------------------------------------------------------------------
deck_play:
        xor a
        ld (event),a
.f:     call wait_frame
        call draw_view
        call hud_update
        call hud_msg_tick
        ld hl,frame
        inc (hl)
        call player_update
        ld a,(event)
        or a
        ret nz
        call droids_update
        ld a,(event)
        or a
        ret nz
        call shots_update
        call expl_update
        call doors_update
        call ener_update
        call clear_check
        ld a,(event)
        or a
        ret nz
        ld a,(demo)
        or a
        jr z,.notdemo
        ld a,(msg_time)             ; keep the demo banner up
        or a
        jr nz,.f
        ld hl,txt_demo
        ld a,250
        call hud_msg
        jr .f
.notdemo:
        ld a,(key_quit)
        or a
        jr z,.nq
        ld a,EV_QUIT
        ld (event),a
        ret
.nq:    ld a,(key_pause)
        or a
        call nz,pause
        jr .f

pause:
        call sfx_stop
        ld hl,txt_paused
        ld a,255
        call hud_msg
.w1:    call poll
        call read_keys
        ld a,(key_pause)
        or a
        jr nz,.w1
.w2:    call poll
        call read_keys
        ld a,(key_pause)
        or a
        jr z,.w2
.w3:    call poll
        call read_keys
        ld a,(key_pause)
        or a
        jr nz,.w3
        ld a,1
        ld (msg_time),a
        ld a,(fieldcnt)
        ld (lastframe),a
        ret

txt_paused: db "PAUSED - PRESS CR",0
txt_demo:   db "DEMO - PRESS A KEY",0

; deck cleared?  ship cleared?
clear_check:
        ld a,(clear_delay)
        or a
        jr z,.cc
        dec a
        ld (clear_delay),a
        ret nz
        ld a,EV_CLEAR
        ld (event),a
        ret
.cc:    ld a,(check_clear)
        or a
        ret z
        xor a
        ld (check_clear),a
        call count_enemies
        ld (enemies_left),a
        or a
        ret nz
        ld a,(deck)
        call dstate_ptr
        ld a,(de)
        or a
        ret nz                      ; already dark
        ld a,1
        ld (de),a
        call dim_deck
        ld de,0500h                 ; deck bonus 500
        call add_score
        ld hl,txt_deckclear
        ld a,80
        call hud_msg
        ld hl,SONG_CLEAR
        call mus_play
        ; whole ship?
        ld a,(ndecks)
        ld b,a
        ld c,0
.l:     ld a,c
        call dstate_ptr
        ld a,(de)
        or a
        ret z
        inc c
        djnz .l
        ld a,90
        ld (clear_delay),a
        ret

txt_deckclear: db "DECK CLEARED  +500",0

; ---------------------------------------------------------------------
; transfer: run the duel and apply the result
; ---------------------------------------------------------------------
do_transfer:
        ld a,(event_arg)
        ld (tr_enemy),a
        call transfer_game
        ld a,(event)
        cp EV_QUIT
        ret z
        xor a
        ld (event),a
        ld (xmode),a
        ld (fire_hold),a
        ld a,25
        ld (bump_cool),a
        ld a,(tr_result)
        cp 1
        jr nz,.lost
        ; won: the host becomes the droid we took over
        ld a,(tr_enemy)
        call slot_iy
        ld a,(iy+D_TYPE)
        ld (DROIDS+D_TYPE),a
        ld (iy+D_TYPE),0FFh
        call roster_ptr
        push hl
        ld bc,R_EN
        add hl,bc
        ld a,(hl)
        ld (DROIDS+D_EN),a
        pop hl
        ld bc,R_SCORE
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        call add_score
        ld ix,DROIDS
        call droid_setup
        ld a,BURN_T
        ld (burn_time),a
        ld a,1
        ld (check_clear),a
        ld a,20
        ld (invuln),a
        call redraw_deck
        ld hl,txt_xwin
        ld a,60
        call hud_msg
        ld hl,SFX_TAKEOVER
        ld a,5
        jp sfx
.lost:  call redraw_deck
        jp host_destroyed

txt_xwin: db "TRANSFER COMPLETE",0
