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
        ld hl,kept
        ld de,kept+1
        ld bc,31
        ld (hl),0
        ldir
        ld hl,DBG_START
        ld (check_x),hl
        ld a,DBG_ARMOUR
        ld (arm_max),a
        ld (arm_cur),a
        ld a,DBG_OWNED
        ld (owned),a
        ld a,DBG_CHEAT
        ld (cheat),a
        ld a,$FF
        ld (check_obj),a
        jp build_hero
START_LIVES: db 5,3,3

; ---------------------------------------------------------------- stage
; play the stage from the current checkpoint. Returns A: 0 = cleared,
; 1 = game over, 2 = quit (demo ended / player escaped)
play_stage:
        ld hl,LEVEL1_MAP
        ld (lvl_map),hl
        ld hl,LEVEL1_W
        ld (lvl_w),hl
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
        ld hl,LEVEL1_OBJ
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
        ld a,MUS_STAGE1
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
        jr nz,.quit
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
.n:     ld a,(latch)
        and $EF
        or b
        ld (latch_next),a
        ret

; random ambient lightning over the graveyard
ambient:
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
