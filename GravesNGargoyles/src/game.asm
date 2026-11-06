; ============================================================================
;  GAME FLOW
; ============================================================================

new_game:
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld (cheat),a
        ld a,(opt_diff)
        ld e,a
        ld d,0
        ld hl,START_LIVES
        add hl,de
        ld a,(hl)
        ld (lives),a
        ld a,1
        ld (arm_max),a
        ld (arm_cur),a
        ld (magic),a
        ld (owned),a            ; lance
        xor a
        ld (weapon),a
        ld (wlevel),a
        ld (wlevel+1),a
        ld (wlevel+2),a
        ld (wlevel+3),a
        ld a,DBG_ARMOUR
        ld (arm_max),a
        ld (arm_cur),a
        ld a,DBG_OWNED
        ld (owned),a
        ld a,DBG_CHEAT
        ld (cheat),a
        ld a,DBG_STAGE
        ld (cur_stage),a
        ; a password entered from the menu overrides the defaults
        ld a,(pw_ok)
        or a
        jr z,.np
        xor a
        ld (pw_ok),a
        ld a,(pw_stage)
        ld (cur_stage),a
        ld a,(pw_arm)
        ld (arm_max),a
        ld (arm_cur),a
        ld a,(pw_owned)
        ld (owned),a
        ld a,(pw_diff)
        ld (opt_diff),a
        ld a,(pw_wl)
        ld hl,wlevel
        ld b,4
.wl:    rrca
        ld (hl),0
        jr nc,$+4
        ld (hl),1
        inc hl
        djnz .wl
.np:    call stage_reset
        jp build_hero
START_LIVES: db 5,3,3

; fresh stage: forget kept objects and checkpoints
stage_reset:
        ld hl,kept
        ld de,kept+1
        ld bc,31
        ld (hl),0
        ldir
        ld hl,DBG_START
        ld (check_x),hl
        ld a,$FF
        ld (check_obj),a
        ret

; ---------------------------------------------------------------- passwords
; 20 bits in 4 characters: stage-1 (3), armour (3), difficulty (2),
; weapons owned (4), weapons enchanted (4), checksum (4).  Scrambled by
; the checksum so neighbouring stages look nothing alike.
PW_ALPHA: db "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

; pw_sum: D,E -> A = 4-bit checksum (keeps D,E)
pw_sum: ld a,e
        add a,a
        add a,e
        add a,d
        add a,7
        ld c,a
        rrca
        rrca
        rrca
        rrca
        xor c
        and 15
        ret

; pw_encode: current progress (cur_stage = stage to play) -> pw_text
pw_encode:
        ld a,(cur_stage)
        dec a
        and 7
        ld d,a
        ld a,(arm_max)
        and 7
        add a,a
        add a,a
        add a,a
        or d
        ld d,a
        ld a,(opt_diff)
        rrca
        rrca
        and $C0
        or d
        ld d,a
        ld hl,wlevel+3
        ld b,4
        ld c,0
.w:     ld a,(hl)
        dec hl
        cp 1
        ccf
        rl c
        djnz .w
        ld a,c
        rlca
        rlca
        rlca
        rlca
        ld e,a
        ld a,(owned)
        and 15
        or e
        ld e,a
        call pw_sum
        ld (pw_bits+2),a
        ld c,a
        rlca
        rlca
        rlca
        rlca
        ld b,a                  ; chk<<4
        or c
        xor $A5
        xor e
        ld (pw_bits),a
        ld a,b
        xor $3C
        xor d
        ld (pw_bits+1),a
        ld hl,pw_text
        ld b,4
.ch:    push bc
        ld a,(pw_bits)
        and 31
        ld e,a
        ld d,0
        push hl
        ld hl,PW_ALPHA
        add hl,de
        ld a,(hl)
        pop hl
        ld (hl),a
        inc hl
        ld b,5
.sh:    push hl
        ld hl,pw_bits+2
        srl (hl)
        dec hl
        rr (hl)
        dec hl
        rr (hl)
        pop hl
        djnz .sh
        pop bc
        djnz .ch
        ld (hl),0
        ret

; pw_decode: pw_idx[0..3] (alphabet indexes) -> NC and pw_* set if valid
pw_decode:
        xor a
        ld (pw_bits),a
        ld (pw_bits+1),a
        ld (pw_bits+2),a
        ld hl,pw_idx+3
        ld b,4
.c:     push bc
        ld b,5
.sh:    push hl
        ld hl,pw_bits
        sla (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        pop hl
        djnz .sh
        ld a,(pw_bits)
        or (hl)
        ld (pw_bits),a
        dec hl
        pop bc
        djnz .c
        ld a,(pw_bits+2)
        cp 16
        ccf
        ret c
        ld c,a
        rlca
        rlca
        rlca
        rlca
        ld b,a
        or c
        xor $A5
        ld e,a
        ld a,(pw_bits)
        xor e
        ld e,a
        ld a,b
        xor $3C
        ld d,a
        ld a,(pw_bits+1)
        xor d
        ld d,a
        call pw_sum
        ld c,a
        ld a,(pw_bits+2)
        cp c
        scf
        ret nz
        ld a,d
        and 7
        cp 7
        ccf
        ret c                   ; stage 8 does not exist
        inc a
        ld (pw_stage),a
        ld a,d
        rrca
        rrca
        rrca
        and 7
        or a
        scf
        ret z
        cp 6
        ccf
        ret c
        ld (pw_arm),a
        ld a,d
        rlca
        rlca
        and 3
        cp 3
        ccf
        ret c
        ld (pw_diff),a
        ld a,e
        and 15
        scf
        ret z
        ld (pw_owned),a
        ld a,e
        rrca
        rrca
        rrca
        rrca
        and 15
        ld (pw_wl),a
        or a                    ; NC: valid
        ret

; ---------------------------------------------------------------- stage
; play the stage from the current checkpoint. Returns A: 0 = cleared,
; 1 = game over, 2 = quit (demo ended / player escaped)
play_stage:
        ld hl,(STG_MAP)
        ld (lvl_map),hl
        ld hl,(STG_COLS)
        ld (lvl_cols),hl
        ld hl,(STG_LOGIC)
        ld (lvl_logic),hl
        ld hl,(STG_W)
        ld (lvl_w),hl
        ld hl,(STG_TILES)
        ld (lvl_tiles),hl
        ld hl,(STG_TATTR)
        ld (lvl_tattr),hl
        ; stage colour set
        ld a,(STG_CSS)
        ld (stage_css),a
.respawn:
        call objs_clear
        xor a
        ld (hero_dead),a
        ld (life_lost),a
        ld (stage_clear),a
        ld (cam_lock),a
        ld (boss_on),a
        ld (boss_hp),a
        ld (hurt_t),a
        ld (throw_t),a
        ld (charge),a
        ld (flash_t),a
        ld (shake_t),a
        ld (banner_t),a
        ld (crouch),a
        ld (hero_dir),a
        ld (fire_dvy),a
        ld a,30
        ld (invuln),a
        ld a,(arm_max)
        ld (arm_cur),a
        ; hero on the ground at the checkpoint
        ld hl,(check_x)
        ld (hero_x),hl
        call find_ground
        ld (hero_y),a
        xor a
        ld (hero_yf),a
        ld hl,0
        ld (hero_vy),hl
        ld a,1
        ld (on_ground),a
        ; limits
        ld hl,0
        ld (xlim_lo),hl
        ld hl,(lvl_w)
        call mul8
        ld de,12
        or a
        sbc hl,de
        ld (xlim_hi),hl
        ; camera
        call cam_target
        ld (cam_x),hl
        ; skip level objects that are behind the camera
        ld hl,(STG_OBJ)
        xor a
        ld (lvl_obji),a
.sk:    ld a,(hl)
        cp $FF
        jr z,.skd
        ld e,a
        ld d,0
        push hl
        ex de,hl
        call mul8
        ld de,(cam_x)
        or a
        sbc hl,de
        pop hl
        jr nc,.skd
        ; torches behind are still wanted? they are decor - skip
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,(lvl_obji)
        inc a
        ld (lvl_obji),a
        jr .sk
.skd:   ld (lvl_objp),hl
        call build_hero
        call camera_reset
        ld a,1
        ld (hud_mode),a
        call hud_draw
        ld a,(demo_mode)
        or a
        jr nz,.nmus
        ld hl,(STG_SONG)
        call play_song
.nmus:  ld hl,STR_READY
        call banner
        ; ---------------------------------------------------- frame loop
.loop:  call read_input
        ld a,(keys_new)
        bit K_PAUSE,a
        call nz,pause_game
        ; music toggle (S)
        ld a,($68FD)
        bit 4,a
        jr nz,.nos
        ld a,(s_held)
        or a
        jr nz,.nos2
        ld a,(opt_music)
        xor 1
        ld (opt_music),a
.nos2:  ld a,1
        jr .nos3
.nos:   xor a
.nos3:  ld (s_held),a
        ; demo ends on keypress or timeout
        ld a,(demo_mode)
        or a
        jr z,.nd
        call any_key_real
        jr nz,.quit
        ld hl,(demo_t)
        dec hl
        ld (demo_t),hl
        ld a,h
        or l
        jr z,.quit
.nd:    call hero_update
        call cam_update
        call camera_cols
        call objs_spawn
        call objs_update
        call shots_update
        call collide_shots
        call collide_hero
        call parts_update
        call ambient
        ; compose
        call bg_copy
        call draw_moon
        call objs_draw
        call shots_draw
        call hero_draw
        call parts_draw
        call banner_draw
        ld a,(hud_need)
        or a
        call nz,hud_draw
        call fx_palette
        call frame_end
        ld hl,frame_no
        inc (hl)
        ; outcomes
        ld a,(life_lost)
        or a
        jr nz,.died
        ld a,(stage_clear)
        or a
        jp z,.loop
        xor a
        ret
.died:  ld a,(demo_mode)
        or a
        jr z,.ndd
        ld hl,0
        ld (demo_t),hl          ; a death ends the demo normally
        jr .quit
.ndd:
        ld a,(lives)
        dec a
        ld (lives),a
        jr z,.over
        call death_card
        jp .respawn
.over:  ld a,1
        ret
.quit:  ld a,2
        ret

; real keyboard/joystick check used to interrupt the demo
any_key_real:
        ld a,(frame_no)
        cp 20
        jr c,.no
        call any_key
        ret
.no:    xor a
        ret

; find_ground: HL = world x -> A = hero top y standing on the first solid
; or platform tile from the top
find_ground:
        ld b,8
.lp:    push bc
        push hl
        ld de,6
        add hl,de
        ld a,b
        call tile_at
        pop hl
        pop bc
        or a
        jr z,.nx
        cp 3
        jr z,.nx
        ld a,b
        and $F8
        sub 16
        ret
.nx:    ld a,b
        add a,8
        ld b,a
        cp 56
        jr c,.lp
        ld a,24
        ret

; cam_target -> HL = desired camera x
cam_target:
        ld a,(cam_lock)
        or a
        jr z,.f
        ld hl,(arena_x)
        ret
.f:     ld hl,(hero_x)
        ld de,56
        or a
        sbc hl,de
        jr nc,.p
        ld hl,0
.p:     ; max = lvl_w*8 - 128
        push hl
        ld hl,(lvl_w)
        call mul8
        ld de,128
        or a
        sbc hl,de
        ex de,hl
        pop hl
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.ok
        ex de,hl
.ok:    ld a,l
        and $FE
        ld l,a
        ret

cam_update:
        call cam_target
        ld de,(cam_x)
        or a
        sbc hl,de               ; target - cam
        jr z,.set
        jr c,.left
        ; right: step up to 4
        ld a,h
        or a
        jr nz,.r4
        ld a,l
        cp 4
        jr c,.rs
.r4:    ld hl,4
.rs:    add hl,de
        jr .st
.left:  ; hl negative
        ld a,h
        inc a
        jr nz,.l4
        ld a,l
        cp -4
        jr nc,.ls
.l4:    ld hl,-4
.ls:    add hl,de
.st:    ld a,l
        and $FE
        ld l,a
        ld (cam_x),hl
.set:   ; shake offset for drawing
        ld hl,(cam_x)
        ld a,(shake_t)
        or a
        jr z,.ns
        dec a
        ld (shake_t),a
        ld de,2
        ld a,(frame_no)
        and 1
        jr z,.sh
        ld a,h
        or l
        jr z,.ns
        ld de,-2
.sh:    add hl,de
.ns:    ld (cam_draw),hl
        ret

; lightning palette flash
fx_palette:
        ld a,(flash_t)
        or a
        ld b,0
        jr z,.n
        dec a
        ld (flash_t),a
        and 2
        jr z,.n
        ld b,$10
.n:     ld a,(stage_css)
        xor b
        ld b,a
        ld a,(latch)
        and $EF
        or b
        ld (latch_next),a
        ret

; back to the standard colour set (front end, cards)
css_reset:
        xor a
        ld (stage_css),a
        ld a,(latch)
        and $EF
        ld (latch_next),a
        ret

; random ambient lightning over the graveyard
ambient:
        ld a,(STG_AMB)
        or a
        ret z
        ld a,(boss_on)
        or a
        ret nz
        call rand
        or a
        ret nz
        call rand
        and 3
        ret nz
        ld a,4
        ld (flash_t),a
        ld a,SFX_THUNDER_ID
        jp play_sfx

; ---------------------------------------------------------------- banner
; banner: HL = string shown centred for ~2 seconds
banner:
        ld (banner_s),hl
        ld a,50
        ld (banner_t),a
        ret

banner_draw:
        ld a,(banner_t)
        or a
        ret z
        dec a
        ld (banner_t),a
        ld hl,(banner_s)
        ld c,19
        ld a,(col_red)
        push hl
        call text_fbc_sh
        pop hl
        ld c,18
        ld a,(col_yel)
        jp text_fbc

; shadow variant: one pixel right/down is not possible per byte; draw a
; dark band instead
text_fbc_sh:
        jp text_fbc

; ---------------------------------------------------------------- pause
pause_game:
        ld hl,STR_PAUSED
        ld c,28
        ld a,(col_yel)
        call text_fbc
        call frame_end
.w:     call audio_run
        call read_input
        ld a,(keys_new)
        bit K_PAUSE,a
        jr z,.w
        ret

; ---------------------------------------------------------------- cards
death_card:
        call stop_music
        ld b,25
        call wait_fields
        ret
