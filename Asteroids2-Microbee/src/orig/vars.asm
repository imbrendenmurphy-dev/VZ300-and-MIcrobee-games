; ---------------------------------------------------------------------------
; vars.asm - variables in runtime RAM (VARS .. VARS+511)
; ---------------------------------------------------------------------------
VP = VARS
        MACRO VAR _n, _s
_n equ VP
VP = VP + _s
        ENDM

        VAR sp_save, 2
        VAR frame_ct, 1
        VAR tick_hook, 2
        VAR latch_base, 1
        VAR rnd_seed, 2
        VAR snd_accA, 2
        VAR snd_accB, 2
        VAR snd_accC, 2
        VAR snd_frqA, 2
        VAR snd_frqB, 2
        VAR snd_frqC, 2
        VAR ch0, CH_SIZE
        VAR ch1, CH_SIZE
        VAR ch2, CH_SIZE
        VAR cache_ptr, 2
        VAR cache_end, 2
        VAR ps_w, 1
        VAR ps_wbs, 1
        VAR ps_wbo, 1
        VAR ps_h, 1
        VAR ps_size, 1
        VAR ps_s, 1
        VAR ps_tmp, 8
        VAR ds_wb, 1
        VAR ds_h, 1
        VAR ds_size, 1
        VAR ds_y0, 1
        VAR ds_data, 2
        VAR ds_xb, 1
        VAR ds_col, 1
        VAR txt_col, 1
        ; input
        VAR in_cur, 1
        VAR in_prev, 1
        VAR in_new, 1
        VAR joy_ok, 1
        VAR demo_mode, 1
        ; ship
        VAR ship_ang, 1
        VAR ship_rot, 1          ; rotation speed / hold counter
        VAR ship_state, 1        ; 0 alive 1 exploding 2 waiting 3 hyperspace
        VAR ship_tmr, 1
        VAR invuln, 1
        VAR fire_cd, 1
        VAR thrusting, 1
        VAR shield_hp, 1
        VAR weapon, 1            ; 0 normal 1 spread 2 rapid
        VAR weapon_tmr, 1
        VAR bombs, 1
        VAR hyper_cd, 1
        ; game
        VAR score, 3             ; BCD, big endian
        VAR hiscore, 3
        VAR lives, 1
        VAR wave, 1
        VAR wave_bcd, 1
        VAR next_life, 1         ; BCD ten-thousands threshold
        VAR rocks_alive, 1
        VAR banner_tmr, 1
        VAR banner_ptr, 2
        VAR beat_tmr, 1
        VAR beat_alt, 1
        VAR enemy_tmr, 2
        VAR flash_tmr, 1
        VAR shake, 1
        VAR chain_tmr, 1
        VAR chain_mul, 1
        VAR hud_dirty, 1
        VAR game_over, 1
        VAR gover_tmr, 1
        VAR wave_tmr, 1
        VAR draw_yoff, 1
        VAR star_vx, 2
        VAR star_vy, 2
        VAR tmp1, 2
        VAR tmp2, 2
        VAR tmp3, 2
        VAR spawn_type, 1
        VAR spawn_x, 1
        VAR spawn_y, 1
        VAR spawn_vx, 2
        VAR spawn_vy, 2
        VAR kill_x, 1
        VAR kill_y, 1
        VAR popup_tmr, 1
        VAR popup_x, 1
        VAR popup_y, 1
        VAR popup_txt, 8
        VAR prof_logic, 1
        VAR hs_table, 8*5        ; 5 entries: 3 BCD + 3 initials + 2 pad
        VAR hs_rank, 1
        VAR attract_step, 1
        VAR attract_tmr, 2
        VAR ai_tmr, 1
        VAR ai_target, 1
        VAR mus_ptr, 2
        VAR mus_row, 1
        VAR mus_tmr, 1
        VAR mus_tempo, 1
        VAR mus_order, 2
        VAR mus_loop, 2
        VAR mv0, 8
        VAR mv1, 8
        VAR mv2, 8
        VAR title_tmr, 2
        VAR shine_x, 1
        VAR scroll_ptr, 2
        VAR scroll_sub, 1
        VAR music_on, 1
        VAR sram_ok, 1
        VAR enemy_count, 1
        VAR level_speed, 1
        VAR last_key, 1
        VAR entry_pos, 1
        VAR entry_chr, 1
        VAR part_next, 2
        VAR part_col, 1
        VAR burst_life, 1
        VAR burst_mask, 1
        VAR coll_x, 1
        VAR coll_y, 1
        VAR coll_mx, 1
        VAR coll_my, 1
        VAR ring_tmr, 1
        VAR ring_x, 1
        VAR ring_y, 1
        VAR numbuf, 4
        VAR banner_buf, 10
        VAR at_dx, 1
        VAR at_dy, 1
        VAR burst_idx, 1
        VAR page_anim, 2
        VAR list_ptr, 2
        VAR list_frame, 2
        VAR entry_ptr, 2
        VAR mprog0, 28
        VAR mprog1, 28
        VAR mprog2, 28
        VAR row_stride, 1
        VAR next_copy, 1
        VAR field_ct, 1
        VAR fs_last, 1
        VAR vars_end, 0

        ASSERT vars_end <= VARS+512, "vars overflow"
