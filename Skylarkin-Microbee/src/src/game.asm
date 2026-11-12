; =====================================================================
;  GAME: the main loop, stage flow, drawing order.
; =====================================================================
GS_PLAY     equ 0
GS_BOSS     equ 1
GS_CLEAR    equ 2
GS_OVER     equ 3

start:
        ld a,2
        ld (musicon),a
        ld a,1
        ld (sfxon),a
        jp front_boot

; ---------------------------------------------------------------------
; a new game: (pilot), (difficulty) set by the front end
; ---------------------------------------------------------------------
new_game:
        ld hl,score
        ld b,4
.z:     ld (hl),0
        inc hl
        djnz .z
        ld a,$05
        ld (next_life),a
        ld a,3
        ld (lives),a
        call reset_powers
        ld a,1
        ld (stage),a
        ; fall into play_stage

; ---------------------------------------------------------------------
; play_stage: the stage in (stage), from its start
; ---------------------------------------------------------------------
play_stage:
        call stop_music
        ld a,(stage)
        call load_stage
        call clear_objects
        ld hl,0
        ld (scrollx),hl
        ld a,1
        ld (scrolling),a
        call scroll_set
        call pages_from_base
        call hud_full
        call player_start
        xor a
        ld (gstate),a
        ld (boss_on),a
        ld (ticks),a
        call stage_intro
        call stage_music
; ---------------------------------------------------------------------
game_loop:
        call read_input
        ld a,(keysnew)
        and 2                   ; H: pause
        call nz,pause
        ld a,(demo)
        or a
        jr z,.nd
        call demo_input
        ld a,(keys)
        or a
        jp nz,demo_quit
.nd:    call input_used_late
        call sound_tick
        ; ---- logic
        ld a,(stg_b)
        call map_blk
        call scroll_step
        call waves_step
        call player_update
        call shots_update
        call enemies_update
        call bullets_update
        call capsules_update
        call bells_update
        call effects_update
        call ovl_boss_update
        call collide_all
        call powers_tick
        ; ---- drawing
        call frame_begin
        call scroll_set
        call strips
        call boss_draw
        call draw_enemies
        call draw_capsules
        call draw_bells
        call draw_effects
        call draw_player
        ld a,BLK_SPR
        call map_blk
        call draw_shots
        call draw_bullets
        call ovl_boss_objs
        call frame_end
        call hud_update
        ld hl,ticks
        inc (hl)
        ; ---- what next
        ld a,(gstate)
        cp GS_CLEAR
        jp z,stage_clear
        cp GS_OVER
        jp z,game_over
        ld a,(keysnew)
        and 1                   ; ESC: back to the title
        jp nz,quit_game
        jp game_loop

input_used_late:
        ret

quit_game:
        call stop_music
        jp front_main

; ---------------------------------------------------------------------
scroll_step:
        ld a,(scrolling)
        or a
        ret z
        ld hl,(scrollx)
        ld de,(scroll_end)
        or a
        sbc hl,de
        jr c,.go
        xor a
        ld (scrolling),a
        jp ovl_boss_start
.go:    ld hl,(scrollx)
        inc hl
        inc hl
        ld (scrollx),hl
        ret

; ---------------------------------------------------------------------
; waves: wave records (dw column, db type, db y) in the B block; each
; starts when the scroll reaches its column (+40: it enters from the right)
; ---------------------------------------------------------------------
waves_step:
        ld a,(scrolling)
        or a
        ret z
        ld hl,(wave_ptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        and e
        inc a
        ret z                   ; FFFFh: the end
        ex de,hl
        ld bc,40
        or a
        sbc hl,bc               ; when the wave column comes on screen
        jr c,.now
        ex de,hl
        ld hl,(scr_m)
        or a
        sbc hl,de
        ret c
.now:   ld hl,(wave_ptr)
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld (wave_ptr),hl
        jp ovl_wave           ; A = type, C = y

; ---------------------------------------------------------------------
; the pages: both from the base picture (RT block), all 1000 cells
; ---------------------------------------------------------------------
pages_from_base:
        ld a,BLK_RT
        call map_blk
        ld a,LV_SCREEN
        out (P_LV),a
        ld hl,RT_CURLO
        ld de,VIDEO
        ld bc,1000
        ldir
        ld hl,RT_CURLO
        ld de,VIDEO+$400
        ld bc,1000
        ldir
        ld a,LV_ATTR
        out (P_LV),a
        ld hl,RT_CURHI
        ld de,VIDEO
        ld bc,1000
        ldir
        ld hl,RT_CURHI
        ld de,VIDEO+$400
        ld bc,1000
        ldir
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld hl,RT_CURCOL
        ld de,COLWIN
        ld bc,1000
        ldir
        ld hl,RT_CURCOL
        ld de,COLWIN+$400
        ld bc,1000
        ldir
        xor a
        out (P_COLCTL),a
        ld (rlcnt),a
        ld (rlcnt+1),a
        ld (blcnt),a
        ld (blcnt+1),a
        ret

; ---------------------------------------------------------------------
clear_objects:
        ld hl,shots
        ld de,shots+1
        ld bc,boss_hdr-shots-1   ; (the boss header and table stay)
        ld (hl),0
        ldir
        ret

; ---------------------------------------------------------------------
; pause: H again to carry on, ESC to quit
; ---------------------------------------------------------------------
pause:
        call stop_music
        ld hl,s_paused
        ld e,12
        ld a,WHITE+(RED<<4)
        ld (txt_col),a
        call print_c
.w:     call input_used
        ld a,2
        call frame_wait
        call read_input
        ld a,(keysnew)
        and 1
        jr nz,.quit
        ld a,(keysnew)
        and 2
        jr z,.w
        call input_used
        call clear_msg
        jp stage_music
.quit:  call clear_msg
        ld sp,STACK
        jp front_main
s_paused:   db " PAUSED - H TO CARRY ON, ESC TO QUIT ",0

; clear_msg: row 12 back to the base sky colour
clear_msg:
        ld a,BLK_RT
        call map_blk
        ld a,(RT_CURCOL+40*11)  ; row 11's colour (a plain row)
        ld (txt_col),a
        ld hl,0
        ld (fc_glyph),hl
        ld de,0*256+12
        ld bc,40*256+1
        jp fill_cells

; ---------------------------------------------------------------------
; stage intro: the name over the playfield for two seconds
; ---------------------------------------------------------------------
stage_intro:
        ld a,YELLOW+(BLUE<<4)
        ld (txt_col),a
        ld a,(stage)
        add a,'0'
        ld (s_stg+6),a
        ld hl,s_stg
        ld e,10
        call print_c
        ld a,(stage)
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,stage_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,WHITE+(BLUE<<4)
        ld (txt_col),a
        ld e,12
        call print_c
        ld b,50
.w:     push bc
        call read_input
        call sound_tick
        ld a,2
        call frame_wait
        pop bc
        djnz .w
        ld a,BLK_RT
        call map_blk
        ld a,(RT_CURCOL+40*11)
        ld (txt_col),a
        ld hl,0
        ld (fc_glyph),hl
        ld de,0*256+10
        ld bc,40*256+3
        call fill_cells
        call input_used
        ret
s_stg:      db "STAGE 1",0
stage_names:
        dw sn1,sn2,sn3,sn4,sn5
sn1:    db "OPEN PLAN",0
sn2:    db "BARBIE BEACH",0
sn3:    db "BIG THINGS HIGHWAY",0
sn4:    db "PUB ROCK",0
sn5:    db "HEAD OFFICE",0

stage_music:
        ld a,(stage)
        dec a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,stage_tunes
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
        jp play_music
stage_tunes:
        dw mus_game_0,mus_game_1, mus_game2_0,mus_game2_1, mus_game3_0,mus_game3_1
        dw mus_game4_0,mus_game4_1, mus_game5_0,mus_game5_1

; ---------------------------------------------------------------------
stage_clear:
        call stop_music
        ld hl,mus_clear_0
        ld de,mus_clear_1
        call play_music
        ld a,YELLOW+(BLUE<<4)
        ld (txt_col),a
        ld hl,s_clear
        ld e,11
        call print_c
        ld b,100
.w:     push bc
        call sound_tick
        ld a,2
        call frame_wait
        pop bc
        djnz .w
        ld a,(stage)
        cp 5
        jp nc,ending
        inc a
        ld (stage),a
        ld a,(stage)
        ld b,a
        ld a,(n_stages)
        cp b
        jp c,ending
        jp play_stage
s_clear:    db "STAGE CLEAR!",0
n_stages:   db 5

game_over:
        call stop_music
        ld hl,mus_over_0
        ld de,mus_over_1
        call play_music
        ld a,WHITE+(RED<<4)
        ld (txt_col),a
        ld hl,s_over
        ld e,11
        call print_c
        ld b,100
.w:     push bc
        call sound_tick
        ld a,2
        call frame_wait
        pop bc
        djnz .w
        jp game_end
s_over:     db " GAME OVER ",0
