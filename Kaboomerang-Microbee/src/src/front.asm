; =====================================================================
;  FRONT: start-up (colour or mono), the title, the game loop.
; =====================================================================
start:
        ld a,(boot_mono)
        ld (monomode),a
        ld a,1
        ld (musicon),a
        ld (sfxon),a
        ld (preview),a
        ld a,r
        ld l,a
        ld h,$5A
        ld (seed),hl
        call clear_screen
        call load_store
        call frame_begin
        ld a,(boot_test)
        or a
        jp nz,game_new
        call choose_mono
        jp title

boot_mono:  db 0
boot_test:  db 0

; every cell blank (glyph 0), black: straight into the maps, both pages redrawn
clear_screen:
        xor a
        ld e,0
        ld c,25
        call block_rows
        ld hl,cur_lo
        ld (hl),$80
        ld de,cur_lo+1
        ld bc,1023
        ldir
        ld hl,cur_hi
        ld (hl),0
        ld de,cur_hi+1
        ld bc,2047              ; banks and colours
        ldir
        jp all_dirty

; the glyph store (colour or mono) into PCG banks 0-3 and into the sprite
; block at 0000h (sprites copy background glyphs from there)
load_store:
        ld a,BLK_GFX
        call map_blk
        ld hl,GFX_STORE_C
        ld a,(monomode)
        or a
        jr z,.c
        ld hl,GFX_STORE_M
.c:     push hl
        ld b,0
.bk:    ld a,b
        or LV_SCREEN
        out (P_LV),a
        push bc
        ld de,PCGWIN
        ld bc,2048
        ldir
        pop bc
        inc b
        ld a,b
        cp 4
        jr nz,.bk
        ld a,LV_SCREEN
        out (P_LV),a
        pop hl
        ld a,BLK_SPR
        ld (cb_dst),a
        ld de,0
        ld bc,STORE_N*16
        ld a,BLK_GFX
        call blk_copy
        ld a,BLK_RT
        jp map_blk

choose_mono:
        call clear_screen
        ld hl,s_name
        ld de,14*256+7
        ld a,YELLOW
        call print_at
        ld hl,s_cm1
        ld de,6*256+11
        ld a,WHITE
        call print_at
        ld hl,s_cm2
        ld de,6*256+13
        ld a,WHITE
        call print_at
        ld hl,s_credit
        ld de,11*256+20
        ld a,GREY
        call print_at
.w:     call frame_begin
        call read_input
        call frame_end
        ld a,(keysnew)
        ld b,a
        call input_used
        bit 3,b
        jr nz,.col
        bit 4,b
        jr z,.w
        ld a,1
        jr .set
.col:   xor a
.set:   ld (monomode),a
        ld a,SFX_MENU
        call play_sfx
        jp load_store
s_cm1:  db "C  FOR A COLOUR MONITOR",0
s_cm2:  db "M  FOR A MONOCHROME MONITOR",0
s_credit: db "VIBED BY BPM 2026",0

; ---------------------------------------------------------------------
title:
        call stop_music
        ld hl,G_TITLE
        ld (lp_first),hl
        ld a,BLK_GFX
        ld hl,GFX_TITLE
        call load_picture
        ld a,BLK_RT
        call map_blk
        ld hl,title_text
.tx:    ld a,(hl)               ; col, row, colour, text, 0 ... FFh
        cp $FF
        jr z,.txd
        ld d,a
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        call print_at
        pop hl
.tz:    ld a,(hl)
        inc hl
        or a
        jr nz,.tz
        jr .tx
.txd:
        ld hl,mus_title_0
        ld de,mus_title_1
        call play_music
        xor a
        ld (t_dir),a            ; the toad crossing the title
        ld (gtick),a
.loop:  call frame_begin
        call read_input
        ld hl,gtick
        inc (hl)
        call title_toad
        call sound_tick
        call frame_end
        ld a,(keysnew)
        bit 2,a
        call nz,toggle_sound
        ld a,(padnew)
        and $10
        ld b,a
        ld a,(keysnew)
        and $20
        or b
        push af
        call input_used
        pop af
        jr z,.loop
        call stop_music
        ld a,SFX_MENU
        call play_sfx
        jp game_new
title_text:
        db 17,8,BCYAN,"WALLY THE",0
        db 17,9,BCYAN,"DEMOLITION WOMBAT",0
        db 17,11,WHITE,"STOP BARON VON",0
        db 17,12,WHITE,"CROAK'S CAR PARKS!",0
        db 9,14,YELLOW,"SPACE OR FIRE TO PLAY",0
        db 4,16,GREY,"ARROWS OR QAOP MOVE   SPACE BOMB",0
        db 5,17,GREY,"X BOOMERANG  H PAUSE  S SOUND",0
        db 11,23,BRED,"VIBED BY BPM 2026",0
        db $FF
s_name: db "KABOOMERANG",0

; a cane toad hops across the title, Wally after it
title_toad:
        ld a,72                 ; on the ground, just above the tiles
        ld (t_ty),a
        ld a,(gtick)
        ld b,a
        and 15
        ld e,0
        cp 9
        jr nc,.t
        ld hl,hoparc
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
.t:     ld a,b                  ; x: one tile a hop, 16 frames a hop
        rrca
        and $7F
        cp 152
        jr c,.x
        sub 152
.x:     ld (t_tx),a
        push de
        ld d,0
        ld a,SF_TOAD_T
        ld c,BROWN
        call put_spr
        pop de
        ld d,0
        ld a,SF_TOAD_B
        ld c,GREEN
        call put_spr
        ret

toggle_sound:
        ld a,(musicon)
        xor 1
        ld (musicon),a
        ld (sfxon),a
        jp z,stop_music
        ret

; ---------------------------------------------------------------------
game_new:
        xor a
        ld (stage),a
        ld hl,score
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld a,3
        ld (p_hearts),a
        ld a,5
        ld (p_maxh),a
        ld a,1
        ld (p_bombs),a
        ld a,2
        ld (p_range),a
        xor a
        ld (p_speed),a
game_stage:
        call stop_music
        ld a,BLK_RT
        call map_blk
        call stage_init
        ld hl,s_ready
        call show_msg
        ld hl,mus_ready_0
        ld de,mus_ready_1
        call play_music
        ld a,3
        ld (gstate),a
        ld a,45
        ld (gtimer),a
        xor a
        ld (paused),a
        ld (allclear),a
        ld (msg_t),a
        ld (said_log),a
.loop:  call frame_begin
        call read_input
        ld a,(keysnew)
        bit 0,a                 ; ESC: back to the title
        jp nz,.quit
        bit 1,a
        jr z,.np
        ld a,(paused)
        xor 1
        ld (paused),a
.np:    ld a,(keysnew)
        bit 2,a
        call nz,toggle_sound
        ld a,(paused)
        or a
        jr z,.run
        call draw_actors
        call input_used
        call frame_end
        jr .loop
.run:   ld hl,gtick
        inc (hl)
        ld a,(gstate)
        cp 3
        jr nz,.play
        ld hl,gtimer            ; READY!
        dec (hl)
        jr nz,.common
        call hide_msg
        xor a
        ld (gstate),a           ; no music in play: the bombs do the talking
        jr .common
.play:  call player_update
        ld a,(gstate)
        or a
        jr nz,.ending
        call boom_update
        call enemies_update
        call bombs_update
        call tiles_pass
        call damage
        ; all the wildlife beaten: show the way out
        ld a,(allclear)
        or a
        jr z,.mt
        ld a,(said_log)
        or a
        jr nz,.mt
        ld a,1
        ld (said_log),a
        ld hl,s_log
        call show_msg
        ld a,40
        ld (msg_t),a
.mt:    ld a,(msg_t)
        or a
        jr z,.common
        dec a
        ld (msg_t),a
        call z,hide_msg
        jr .common
.ending:
        call bombs_update
        call tiles_pass
        ld hl,gtimer
        dec (hl)
        jr nz,.common
        ld a,(gstate)
        cp 1
        jr nz,.cont
        ld hl,stage             ; next stage, keeping the power-ups
        inc (hl)
        jp game_stage
.cont:  ld a,3                  ; unlimited continues: same stage, full hearts
        ld (p_hearts),a
        jp game_stage
.common:
        call parts_update
        ld a,(hud_dirty)
        or a
        jr z,.nh
        xor a
        ld (hud_dirty),a
        call draw_hud
.nh:    call draw_actors
        call sound_tick
        call input_used
        call frame_end
        jp .loop
.quit:  call input_used
        call stop_music
        jp title
s_ready: db "GET READY!",0
s_log:  db "FIND THE HOLLOW LOG!",0
