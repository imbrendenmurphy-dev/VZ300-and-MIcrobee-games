; ============================================================================
;  FRONT END AND MATCH FLOW
; ============================================================================

; ---------------------------------------------------------------------------
; TITLE AND MAIN MENU
; ---------------------------------------------------------------------------
front_main:
        call stop_sfx
        xor a
        ld (two_player),a
        ld (menu_pos),a
        ld (dbg_on),a
.title: call draw_title
        ld hl,tune_title
        call play_loop
        ld hl,0
        ld (idle_ticks),hl
        call clear_keys
.loop:  call menu_frame
        call menu_keys          ; A = pads, B = system keys
        ld c,a
        or b
        jr z,.idle
        ld hl,0
        ld (idle_ticks),hl
.idle:  ld hl,(idle_ticks)
        inc hl
        ld (idle_ticks),hl
        ld de,25*20             ; 20 seconds: CPU v CPU demo
        or a
        sbc hl,de
        jp nc,demo
        ; up / down
        ld a,c
        bit 0,a
        jr z,.nu
        ld a,(menu_pos)
        or a
        jr z,.nu
        dec a
        ld (menu_pos),a
        call blip
        jr .redraw
.nu:    ld a,c
        bit 1,a
        jr z,.nd
        ld a,(menu_pos)
        cp 4
        jr z,.nd
        inc a
        ld (menu_pos),a
        call blip
        jr .redraw
.nd:    ; left / right on the level line
        ld a,(menu_pos)
        cp 2
        jr nz,.nlr
        ld a,c
        and $0C
        jr z,.nlr
        ld a,c
        bit 3,a
        ld a,(opt_diff)
        jr z,.lft
        cp 2
        jr z,.nlr
        inc a
        jr .sd
.lft:   or a
        jr z,.nlr
        dec a
.sd:    ld (opt_diff),a
        call blip
        jr .redraw
.nlr:   ; select: A, B, RETURN or SPACE
        ld a,c
        and $30
        jr nz,.sel
        ld a,b
        and 3
        jr z,.loop
.sel:   ld a,(menu_pos)
        or a
        jr z,.one
        cp 1
        jr z,.two
        cp 2
        jr z,.lvl
        cp 3
        jp z,control_test
        jp quit_to_sd
.lvl:   ld a,(opt_diff)
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (opt_diff),a
        call blip
.redraw:
        call draw_menu
        jp .loop
.one:   xor a
        ld (two_player),a
        jr .go
.two:   ld a,1
        ld (two_player),a
.go:    call stop_sfx
        call sfx_select
        call select_screen
        jp c,front_main         ; backed out
.again: call play_match
        jp nc,.again            ; rematch
        jp front_main

menu_frame:
        ld a,2
        ld (tick_len),a
        jp frame_end

blip:   push bc
        ld hl,sfx_blip
        call play_sfx_keep
        pop bc
        ret
sfx_select:
        ld hl,sfx_sel
        jp play_sfx

; play_sfx_keep: a short sound over the title tune, which then restarts
play_sfx_keep:
        jp play_sfx

; play_loop: HL = tune to repeat
play_loop:
        di
        ld (sfx_loopp),hl
        ld a,1
        ld (sfx_loop),a
        ei
        jp play_sfx

draw_title:
        call title_base
        call draw_menu
        ret

; title_base: arena, logo, the two fighters
title_base:
        call hide_msg
        call clean_floor
        call bg_to_sb
        ld hl,s_red_dust
        ld c,1
        call big_text
        ld a,$AA
        ld b,0
        ld c,10
        ld d,32
        ld e,16
        call fill_rect          ; dark band behind the second line of the logo
        ld hl,s_rumble
        ld c,13
        call big_text
        ; the two fighters, posing
        ld ix,p1
        xor a
        ld b,0
        call setup_fighter
        ld hl,18*4
        ld (p1+F_XL),hl
        xor a
        ld (p1+F_FACE),a
        ld (p1+F_Y),a
        ld a,FR_IDLE
        ld (p1+F_FRM),a
        ld ix,p2
        ld a,1
        ld b,1
        call setup_fighter
        ld hl,110*4
        ld (p2+F_XL),hl
        ld a,1
        ld (p2+F_FACE),a
        xor a
        ld (p2+F_Y),a
        ld a,FR_IDLE
        ld (p2+F_FRM),a
        xor a
        ld (clip_top),a
        ld ix,p1
        call draw_fighter
        ld ix,p2
        call draw_fighter
        ld hl,s_vibed
        ld c,58
        ld a,2
        call text_c
        ret

draw_menu:
        ; clear the menu panel and print the five lines
        ld b,8
        ld c,27
        ld d,16
        ld e,30
        ld a,$AA                ; dark panel behind the menu
        call fill_rect
        ld hl,menu_lines
        ld c,28
        ld b,0
.l:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld a,b
        cp 2
        jr nz,.nl
        ; level line: "LEVEL " + name
        ld a,(opt_diff)
        add a,a
        ld e,a
        ld d,0
        ld hl,lvl_names
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
.nl:    ld a,(menu_pos)
        cp b
        ld a,1
        jr z,$+3
        xor a
        push af
        push bc
        call text_c
        pop bc
        pop af
        ; cursor arrow at column 9
        cp 1
        jr nz,.nc
        ld hl,s_arrow
        ld b,8
        ld a,3
        call text
.nc:    pop hl
        pop bc
        ld a,c
        add a,6
        ld c,a
        inc b
        ld a,b
        cp 5
        jr nz,.l
        ld a,1
        ld (copy_full),a
        ret

menu_lines:
        dw s_1p, s_2p, 0, s_ctest, s_quit
lvl_names:
        dw s_easy, s_normal, s_hard

; ---------------------------------------------------------------------------
; setup_fighter: IX = record, A = character (0 Flick, 1 Dusty), B = side
; (0 = player 1 blue, 1 = player 2 red)
; ---------------------------------------------------------------------------
setup_fighter:
        ld (ix+F_CHAR),a
        or a
        ld hl,def_flick
        ld de,dir_flick
        ld c,BANK_FLICK
        jr z,.f
        ld hl,def_dusty
        ld de,dir_dusty
        ld c,BANK_DUSTY
.f:     ld (ix+F_DEFL),l
        ld (ix+F_DEFH),h
        ld (ix+F_DIRL),e
        ld (ix+F_DIRH),d
        ld (ix+F_BANK),c
        ld a,XF_ID
        dec b
        jr nz,$+4
        ld a,XF_RED
        ld (ix+F_XF),a
        ret

; ---------------------------------------------------------------------------
; CHARACTER SELECT.  Carry set if backed out.
; ---------------------------------------------------------------------------
select_screen:
        xor a
        ld (sel_p1),a
        ld a,1
        ld (sel_p2),a
        xor a
        ld (sel_stage),a        ; 0 = player 1 choosing, 1 = player 2 / CPU
        call clear_keys
.draw:  call draw_select
.loop:  call menu_frame
        call menu_keys
        ld c,a
        ld a,b
        bit 2,a                 ; Q backs out
        jr z,.nq
        scf
        ret
.nq:    ; player 2 picks with its own controls in 2-player mode
        ld hl,p1_new
        call take_new
        ld hl,p2_new
        call take_new
        ld e,a
        ld a,(sel_stage)
        or a
        jr z,.k
        ld a,(two_player)
        or a
        jr z,.k
        ld c,e
.k:     ld a,c
        and $0C
        jr z,.ns
        ld hl,sel_p1
        ld a,(sel_stage)
        or a
        jr z,$+5
        ld hl,sel_p2
        ld a,(hl)
        xor 1
        ld (hl),a
        call blip
        jr .draw
.ns:    ld a,c
        and $30
        jr nz,.ok
        ld a,b
        and 3
        jr z,.loop
.ok:    call sfx_select
        ld a,(sel_stage)
        or a
        jr nz,.done
        inc a
        ld (sel_stage),a
        ; the other fighter by default
        ld a,(sel_p1)
        xor 1
        ld (sel_p2),a
        jr .draw
.done:  or a
        ret

draw_select:
        call clean_floor
        call bg_to_sb
        ld a,$AA
        ld b,10
        ld c,19
        ld d,12
        ld e,38
        call fill_rect          ; dark panel for the words
        ld hl,s_choose
        ld c,2
        ld a,1
        call text_c
        ; fighters
        ld ix,p1
        xor a
        ld b,0
        call setup_fighter
        ld hl,30*4
        ld (p1+F_XL),hl
        xor a
        ld (p1+F_FACE),a
        ld (p1+F_Y),a
        ld a,FR_IDLE
        ld (p1+F_FRM),a
        ld ix,p2
        ld a,1
        ld b,1
        call setup_fighter
        ld hl,98*4
        ld (p2+F_XL),hl
        ld a,1
        ld (p2+F_FACE),a
        xor a
        ld (p2+F_Y),a
        ld a,FR_IDLE
        ld (p2+F_FRM),a
        ld a,8
        ld (clip_top),a
        ld ix,p1
        call draw_fighter
        ld ix,p2
        call draw_fighter
        ; names and styles, between the two fighters
        ld hl,sel_text
.dt:    ld a,(hl)
        or a
        jr z,.dte
        ld c,a
        inc hl
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        call text_c
        pop hl
        jr .dt
.dte:
        ; who has picked what: P1 marker, and P2 / CPU marker
        ld a,(sel_p1)
        ld hl,s_p1
        ld c,2
        call .mark
        ld a,(sel_stage)
        or a
        jr z,.prompt
        ld a,(sel_p2)
        ld hl,s_cpu
        ld b,a
        ld a,(two_player)
        or a
        ld a,b
        jr z,$+5
        ld hl,s_p2
        ld c,3
        call .mark2
.prompt:
        ld hl,s_pick1
        ld a,(sel_stage)
        or a
        jr z,.pp
        ld hl,s_pick2
        ld a,(two_player)
        or a
        jr nz,.pp
        ld hl,s_pickcpu
.pp:    ld c,58
        ld a,2
        call text_c
        ld a,1
        ld (copy_full),a
        ret
.mark:  ; A = side picked (0 left, 1 right), HL = label, C = colour; row 9
        ld b,5
        or a
        jr z,$+4
        ld b,22
        push bc
        ld a,c
        ld c,11
        call text
        pop bc
        ret
.mark2: ld b,5
        or a
        jr z,$+4
        ld b,22
        ld a,c
        ld c,17
        jp text

; ---------------------------------------------------------------------------
; MATCH.  Carry clear = rematch, carry set = back to the menu.
; ---------------------------------------------------------------------------
play_match:
        ld ix,p1
        ld a,(sel_p1)
        ld b,0
        call setup_fighter
        ld (ix+F_CPU),0
        ld (ix+F_WINS),0
        ld ix,p2
        ld a,(sel_p2)
        ld b,1
        call setup_fighter
        ld a,(two_player)
        xor 1
        ld (ix+F_CPU),a
        ld (ix+F_WINS),0
        ld a,(demo_on)
        or a
        jr z,$+7
        ld a,1
        ld (p1+F_CPU),a
        ld a,1
        ld (round_num),a
        ld hl,0
        ld (slow_ticks),hl
        call stop_sfx
        ; versus card
        call round_setup
        ld hl,s_vs
        ld de,0
        ld a,20
        call show_msg
        ld b,40
        call show_ticks
        call hide_msg
.round: call round_setup
        ; ---- "ROUND n", then "FIGHT!"
        ld a,(round_num)
        add a,'0'
        ld (s_roundn+6),a
        ld hl,s_roundn
        ld de,0
        ld a,18
        call show_msg
        ld b,30
        call show_ticks
        ld hl,s_fight
        ld de,0
        ld a,18
        call show_msg
        ld hl,sfx_bell
        call play_sfx
        ld b,14
        call show_ticks
        call hide_msg
        ld hl,0
        ld (slow_ticks),hl
        ; ---- go
        ld a,ST_STAND
        ld (p1+F_ST),a
        ld (p2+F_ST),a
        call clear_keys
.fight: call fight_tick
        ld a,(quit_req)
        or a
        jp nz,.quit
        ld a,(ko_flag)
        or a
        jr nz,.ko
        ld a,(round_time)
        or a
        jr nz,.fight
        ; ---- time up
        ld a,1
        ld (inputs_off),a
        ld hl,s_time
        ld de,0
        ld a,18
        call show_msg
        ld hl,sfx_bell
        call play_sfx
        ld b,40
        call run_ticks
        jr .judge
.ko:    ; ---- knock-out: slow motion while the loser falls
        ld a,1
        ld (inputs_off),a
        ld hl,s_ko
        ld de,0
        ld a,16
        call show_msg
        ld hl,sfx_ko
        call play_sfx
        ld a,4
        ld (tick_len),a
        ld b,16
        call run_ticks
        ld a,2
        ld (tick_len),a
        ld b,24
        call run_ticks
.judge: ; ---- who won the round?
        call hide_msg
        ld a,(p1+F_HP)
        ld b,a
        ld a,(p2+F_HP)
        cp b
        jr z,.draw
        ld ix,p1
        jr c,$+6
        ld ix,p2
        inc (ix+F_WINS)
        ld (ix+F_ST),ST_WIN
        call hud_pips
        ld hl,sfx_win
        call play_sfx
        ld b,40
        call run_ticks
        ld a,(ix+F_WINS)
        cp 2
        jr z,.match
        jr .next
.draw:  ld hl,s_draw
        ld de,0
        ld a,18
        call show_msg
        ld b,40
        call run_ticks
        call hide_msg
.next:  ld hl,round_num
        inc (hl)
        ld a,(hl)
        cp 10
        jp c,.round
        ; nine rounds without a winner: a drawn match
        ld ix,0
.match: ; ---- result
        xor a
        ld (inputs_off),a
        ld (dbg_on),a
        call result_screen
        ret

.quit:  xor a
        ld (quit_req),a
        ld (inputs_off),a
        ld (dbg_on),a
        call stop_sfx
        scf
        ret

; show_ticks: B ticks of the arena with the fighters frozen, no logic
show_ticks:
        push bc
        call render_fight
        call frame_end
        pop bc
        djnz show_ticks
        ret

; run_ticks: B ticks with logic but no new input
run_ticks:
        push bc
        push ix
        call game_logic
        call render_fight
        call frame_end
        pop ix
        pop bc
        djnz run_ticks
        ret

; fight_tick: one tick of the round
fight_tick:
        call menu_keys          ; system keys (B)
        ld c,a
        ld a,(demo_on)
        or a
        jr z,.nd
        ld a,c
        or b
        jr z,.nd
        ld a,1                  ; any key ends the demo
        ld (quit_req),a
        ret
.nd:    ld a,b
        bit 0,a
        jp nz,pause
        bit 3,a
        call nz,dbg_toggle
        call game_logic
        ; round timer
        ld hl,tcount
        inc (hl)
        ld a,(hl)
        cp 25
        jr c,.r
        ld (hl),0
        ld a,(round_time)
        or a
        jr z,.r
        dec a
        ld (round_time),a
        call hud_timer
.r:     call render_fight
        jp frame_end

dbg_toggle:
        ld a,(dbg_on)
        xor 1
        ld (dbg_on),a
        ld hl,$FFFF
        ld (spare_min),hl
        ld hl,0
        ld (slow_ticks),hl
        ld (spare_show),hl
        xor a
        ld (dbg_cnt),a
        ld a,1
        ld (dbg_dirty),a
        ld a,(dbg_on)
        or a
        ret nz
        jp hud_names

pause:
        call stop_sfx
        ld hl,s_paused
        ld de,s_pausehelp
        ld a,18
        call show_msg
.p:     call render_fight
        call frame_end
        call menu_keys
        ld a,b
        bit 2,a
        jr nz,.q
        bit 0,a
        jr z,.p
        jr .out
.q:     ld a,1
        ld (quit_req),a
.out:   call hide_msg
        call clear_keys
        ret

; round_setup: fighters to their marks, fresh health, arena redrawn
round_setup:
        ld a,32
        ld (cam),a
        ld (src_cam),a
        xor a
        ld (scrolled),a
        ld (bg_stale),a
        ld (cam_lock),a
        call bg_build
        ld ix,p1
        ld hl,(32+36)*4
        xor a
        call .one
        ld ix,p2
        ld hl,(32+92)*4
        ld a,1
        call .one
        ld a,60
        ld (round_time),a
        xor a
        ld (tcount),a
        ld (ko_flag),a
        ld (hitstop),a
        ld (spark_t),a
        ld (inputs_off),a
        ld (quit_req),a
        call hide_msg
        ld a,2
        ld (tick_len),a
        call bg_to_sb
        call hud_all
        call band_full
        ld a,ARENATOP
        ld (clip_top),a
        ld a,1
        ld (copy_full),a
        ret
.one:   ld (ix+F_XL),l
        ld (ix+F_XH),h
        ld (ix+F_FACE),a
        xor a
        ld (ix+F_Y),a
        ld (ix+F_T),a
        ld (ix+F_PUSH),a
        ld (ix+F_INV),a
        ld (ix+F_AIR),a
        ld (ix+F_AICNT),a
        ld (ix+F_AIACT),a
        ld (ix+F_HPOS),a
        ld (ix+F_PRS),a
        ld (ix+F_PAD),a
        ld (ix+F_VX),a
        ld (ix+F_HITF),a
        ld (ix+F_ST),ST_FROZEN
        ld (ix+F_FRM),FR_IDLE
        ld (ix+F_HP),96
        ld (ix+F_TA),$7F
        ld (ix+F_TB),$7F
        push ix
        pop hl
        ld de,F_HIST
        add hl,de
        ld b,16
.h:     ld (hl),a
        inc hl
        djnz .h
        ret

; result_screen: IX = winner (0 = drawn).  Carry clear = rematch.
result_screen:
        push ix
        pop hl
        ld a,h
        or l
        ld hl,s_drawgame
        jr z,.set
        ld a,(two_player)
        or a
        jr nz,.two
        ld a,(demo_on)
        or a
        jr nz,.two
        ld hl,s_youwin
        ld a,(ix+F_CPU)
        or a
        jr z,.set
        ld hl,s_youlose
        jr .set
.two:   ld hl,s_p1wins
        push ix
        pop de
        ld a,e
        cp p1&255
        jr z,.set
        ld hl,s_p2wins
.set:   ld de,s_again
        ld a,16
        call show_msg
        ld a,(demo_on)
        or a
        jr nz,.demo
        call clear_keys
.w:     call render_fight
        call frame_end
        call menu_keys
        ld c,a
        bit 4,c
        jr nz,.re
        bit 5,c
        jr nz,.menu
        ld a,b
        and 5                   ; RETURN or Q
        jr z,.w
.menu:  scf
        ret
.re:    call sfx_select
        or a
        ret
.demo:  ld b,60
        call show_ticks
        scf
        ret

; ---------------------------------------------------------------------------
; DEMO: CPU against CPU from the title; any key stops it
; ---------------------------------------------------------------------------
demo:
        call stop_sfx
        ld a,1
        ld (demo_on),a
        call random
        and 1
        ld (sel_p1),a
        call random
        and 1
        ld (sel_p2),a
        xor a
        ld (two_player),a
        ld a,2
        ld (opt_diff),a
        call play_match
        xor a
        ld (demo_on),a
        ld a,1
        ld (opt_diff),a
        jp front_main

; ---------------------------------------------------------------------------
; CONTROL TEST: live controls, raw ports, drop-outs and the A+B gap
; ---------------------------------------------------------------------------
control_test:
        call stop_sfx
        ld hl,ct_drop
        ld b,16
.z:     ld (hl),0
        inc hl
        djnz .z
        xor a
        ld (ct_gap),a
        ld a,$FF
        ld (ct_fa),a
        ld (ct_fb),a
        ld a,1
        ld (ct_on),a
        ld a,4
        ld (tick_len),a
        call clear_keys
.loop:  call ct_draw
        call frame_end
        call menu_keys
        ld a,b
        and 5                   ; RETURN or Q
        jr z,.loop
        xor a
        ld (ct_on),a
        ld a,2
        ld (tick_len),a
        jp front_main

ct_draw:
        xor a
        call cls_sb
        ld hl,s_ct_title
        ld c,0
        ld a,1
        call text_c
        ; live pads
        ld hl,s_ct_j1
        ld a,(pad_j1)
        ld c,7
        call ct_pad
        ld hl,s_ct_j2
        ld a,(pad_j2)
        ld c,13
        call ct_pad
        ld hl,s_ct_k1
        ld a,(pad_k1)
        ld c,19
        call ct_pad
        ld hl,s_ct_k2
        ld a,(pad_k2)
        ld c,25
        call ct_pad
        ; raw ports
        ld hl,s_ct_ports
        ld b,0
        ld c,32
        ld a,2
        call text
        ld hl,raw_2c
        ld b,0
        ld c,38
        ld d,7
.rp:    push bc
        push de
        push hl
        ld a,(hl)
        call hex2
        pop hl
        pop de
        pop bc
        push bc
        push de
        push hl
        ld hl,num_buf
        ld a,1
        call text
        pop hl
        pop de
        pop bc
        inc hl
        ld a,b
        add a,3
        ld b,a
        dec d
        jr nz,.rp
        ; drop-outs: joystick 1 and 2, U D L R
        ld hl,s_ct_drop
        ld b,0
        ld c,45
        ld a,2
        call text
        ld hl,ct_drop
        ld c,45
        call ct_counts
        ld c,51
        ld hl,s_ct_drop2
        ld b,0
        ld a,2
        push bc
        call text
        pop bc
        ld hl,ct_drop+6
        call ct_counts
        ; A+B gap
        ld hl,s_ct_gap
        ld b,0
        ld c,58
        ld a,2
        call text
        ld a,(ct_gap)
        call num2
        xor a
        ld (num_buf+2),a
        ld hl,num_buf
        ld b,9
        ld c,58
        ld a,1
        call text
        ld hl,s_ct_exit
        ld b,14
        ld c,58
        ld a,3
        call text
        ld a,1
        ld (copy_full),a
        ret

; ct_pad: HL = label, A = pad bits, C = row
ct_pad:
        ld (ct_bits),a
        push bc
        ld b,0
        ld a,2
        call text
        pop bc
        ld hl,s_ct_syms
        ld b,7
        ld d,1
.s:     push bc
        push de
        push hl
        ld a,(hl)
        ld (num_buf),a
        xor a
        ld (num_buf+1),a
        ld a,(ct_bits)
        and d
        ld a,2
        jr z,$+4
        ld a,1
        ld hl,num_buf
        call text
        pop hl
        pop de
        pop bc
        inc hl
        inc b
        inc b
        sla d
        bit 6,d
        jr z,.s
        ret

; ct_counts: HL = 4 counters, C = row -> printed at columns 14..
ct_counts:
        ld b,10
        ld d,4
.c:     push bc
        push de
        push hl
        ld a,(hl)
        push bc
        call num2
        pop bc
        xor a
        ld (num_buf+2),a
        ld hl,num_buf
        ld a,1
        call text
        pop hl
        pop de
        pop bc
        inc hl
        ld a,b
        add a,4
        ld b,a
        dec d
        jr nz,.c
        ret

; hex2: A -> two hex digits in num_buf
hex2:
        push af
        rrca
        rrca
        rrca
        rrca
        call .d
        ld (num_buf),a
        pop af
        call .d
        ld (num_buf+1),a
        xor a
        ld (num_buf+2),a
        ret
.d:     and 15
        add a,'0'
        cp '9'+1
        ret c
        add a,7
        ret

; ct_field: in the interrupt while the control test is open
;  drop-outs: a direction held, released for one field, then held again
ct_field:
        ld a,(pad_j1)
        ld hl,ct_j1h
        ld de,ct_drop
        call .drops
        ld a,(pad_j2)
        ld hl,ct_j2h
        ld de,ct_drop+6
        call .drops
        ; A+B gap on any controller
        ld a,(m_prev)
        ld c,a
        ld a,(ct_mprev)
        cpl
        and c
        ld b,a                  ; new presses this field
        ld a,c
        ld (ct_mprev),a
        ld hl,ct_fa
        inc (hl)
        jr nz,$+3
        dec (hl)
        ld hl,ct_fb
        inc (hl)
        jr nz,$+3
        dec (hl)
        bit 4,b
        jr z,.nb
        ld a,(ct_fb)
        cp 25
        jr nc,$+5
        ld (ct_gap),a
        xor a
        ld (ct_fa),a
.nb:    bit 5,b
        ret z
        ld a,(ct_fa)
        cp 25
        jr nc,$+5
        ld (ct_gap),a
        xor a
        ld (ct_fb),a
        ret
.drops: ; A = pad now, HL = history (last field, the one before), DE = 4 counters
        ld c,a
        ld a,(hl)
        cpl
        inc hl
        and (hl)
        and c                   ; held two fields ago, gone, held again
        ld b,a
        dec hl
        ld a,(hl)
        inc hl
        ld (hl),a
        dec hl
        ld (hl),c
        ex de,hl
        ld c,4
.bit:   rr b
        jr nc,.n
        inc (hl)
        jr nz,.n
        dec (hl)
.n:     inc hl
        dec c
        jr nz,.bit
        ret

; clean_floor: menus show the middle of the stage; fighters drawn at
; screen positions (camera 0)
clean_floor:
        ld a,32
        ld (src_cam),a
        call bg_build
        xor a
        ld (cam),a
        ld (scrolled),a
        ld (bg_stale),a
        ret
