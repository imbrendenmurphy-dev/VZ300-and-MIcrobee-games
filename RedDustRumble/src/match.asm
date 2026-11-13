; ---------------------------------------------------------------------------
; A MATCH: best of three rounds.  Carry = back to the menu.
; ---------------------------------------------------------------------------
play_match:
        call stop_sfx
        call vs_card
        ld a,(sel_p1)
        ld (want_a),a
        ld a,(sel_p2)
        ld (want_b),a
        ld a,(sel_stage)
        ld (want_stage),a
        call load_match
        call stage_css
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
        call round_setup
        ld b,6
        call show_ticks
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
        ; the deciding blow has landed: call for the finisher (once)
        ld a,(fin_on)
        dec a
        jr nz,.nfm
        ld a,(fin_msg)
        or a
        jr nz,.nfm
        inc a
        ld (fin_msg),a
        ld hl,s_finish
        ld de,0
        ld a,12
        call show_msg
        ld hl,sfx_bell
        call play_sfx
.nfm:   ld a,(round_time)
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
.ko:    ; ---- knock-out
        ld a,1
        ld (inputs_off),a
        ld a,(fin_on)
        cp 3
        jr nz,.plain
        ; a finisher: its name goes up while the loser sails away
        ld ix,(fin_who)
        ld l,(ix+F_DEFL)
        ld h,(ix+F_DEFH)
        ld de,D_FINNAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,0
        ld a,12
        call show_msg
        ld b,45
        call run_ticks
        jr .judge
.plain: ; slow motion while the loser falls
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
.match: ; ---- result: 0 player 1 won, 1 player 2 won, 2 a draw
        push ix
        pop hl
        ld de,p1
        or a
        sbc hl,de
        ld a,0
        jr z,.mr
        inc a
        ld de,p2-p1
        or a
        sbc hl,de
        jr z,.mr
        inc a
.mr:    ld (match_res),a
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
        call do_flash
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
        call do_flash
        ; round timer (stopped while a finisher is on)
        ld a,(fin_on)
        or a
        jr nz,.r
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
        ld (fin_on),a
        ld (fin_msg),a
        ld (flash_t),a
        ld (pr1),a
        ld (pr2),a
        call stage_css
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
        ld (ix+F_HIDE),a
        ld (ix+F_SEQ),a
        ld (ix+F_SEQT),a
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

result_screen:
        ld a,(match_res)
        cp 2
        ld hl,s_drawgame
        ld de,s_again
        jr z,.set
        ld a,(demo_on)
        or a
        jr nz,.two
        ld a,(two_player)
        or a
        jr nz,.two
        ; one player
        ld a,(match_res)
        or a
        ld hl,s_youlose
        ld de,s_retry
        jr nz,.set
        ld hl,s_youwin
        ld de,s_next
        jr .set
.two:   ld a,(match_res)
        or a
        ld hl,s_p1wins
        ld de,s_again
        jr z,.set
        ld hl,s_p2wins
.set:   ld a,16
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

; demo: two CPU fighters, chosen at random, at the second one's home
demo:
        call stop_sfx
        ld a,1
        ld (demo_on),a
        xor a
        ld (two_player),a
        ld (tour_on),a
        call random
        and 7
        ld (sel_p1),a
        call random
        and 7
        ld (sel_p2),a
        ld (sel_stage),a
        ld a,(opt_diff)
        push af
        ld a,2
        ld (opt_diff),a
        call play_match
        pop af
        ld (opt_diff),a
        xor a
        ld (demo_on),a
        jp front_main

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

