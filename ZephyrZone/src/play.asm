; =====================================================================
;  play.asm - stage timeline, lives / continues, title and demo
; =====================================================================
EV_END      equ 0
EV_MSG      equ 1           ; db id
EV_WAVE     equ 2           ; 10 bytes (see spawn_wave)
EV_SCEN     equ 3           ; db gap/4, mix
EV_BOSS     equ 4
EV_SFX      equ 5           ; db id

; ---------------------------------------------------------------------
; stage events due at the current clock
; ---------------------------------------------------------------------
stage_events:
            ld hl,(ev_ptr)
            ld e,(hl)
            inc hl
            ld d,(hl)               ; event time
            ld a,d
            and e
            inc a
            ret z                   ; $FFFF: no more events
            push hl
            ld hl,(clock)
            or a
            sbc hl,de
            pop hl
            ret c                   ; not yet
            inc hl
            ld a,(hl)
            inc hl
            or a
            jr z,.end
            dec a
            jr nz,.n1
            ld a,(hl)               ; MSG
            inc hl
            ld (ev_ptr),hl
            call to_fe
            dw show_msg
            jr stage_events
.n1:        dec a
            jr nz,.n2
            push hl                 ; a crowd still up there: the wave waits
            ld a,K_ENEMY
            call count_kind
            pop hl
            ld a,c
            cp 9
            ret nc
            call spawn_wave         ; WAVE (HL -> params, returns past them)
            ld (ev_ptr),hl
            jr stage_events
.n2:        dec a
            jr nz,.n3
            ld a,(hl)               ; SCEN
            ld (scen_gap),a
            inc hl
            ld a,(hl)
            ld (scen_mix),a
            inc hl
            ld (ev_ptr),hl
            jr stage_events
.n3:        dec a
            jr nz,.n4
            ld (ev_ptr),hl          ; BOSS
            call WJ_BSTART
            jr stage_events
.n4:        ld a,(hl)               ; SFX
            inc hl
            ld (ev_ptr),hl
            call sfx
            jr stage_events
.end:       dec hl
            dec hl
            dec hl
            ld (hl),$FF             ; (never reached: the timeline ends with $FFFF)
            ret

; a frame with the hero's pose forced (celebrations)
game_frame_pose:
            ld (force_pose),a
            call game_frame
            xor a
            ld (force_pose),a
            ret

; ---------------------------------------------------------------------
; demo autopilot: weave about, climb towards enemies, fire constantly
; ---------------------------------------------------------------------
autopilot:
            ld a,(in_now)
            and $80
            ld b,a
            ld a,(clock)
            ld c,a
            ld a,(clock+1)
            rra
            ld a,c
            rra
            ld c,a                  ; slow clock
            ld a,K_FIRE
            or b
            ld b,a
            ld a,c
            and $40
            jr z,.l
            set 3,b                 ; right
            jr .v
.l:         set 2,b                 ; left
.v:         ld a,c
            add a,$20
            and $40
            jr z,.d
            set 0,b
            jr .s
.d:         set 1,b
.s:         ld a,b
            ld (in_now),a
            ret

title_frame:
            call read_input
            call autopilot
            ld a,(dtf)
            or a
            jr nz,.d1
            ld a,2
.d1:        cp 5
            jr c,.d2
            ld a,4
.d2:        ld (dt),a
            ld hl,anim
            add a,(hl)
            ld (hl),a
            ld hl,(clock)
            ld a,(dt)
            ld e,a
            ld d,0
            add hl,de
            ld (clock),hl
            call map_game
            call hero_update
            call camera
            call world_update
            call project_all
            call render_bg
            call draw_objects
            call draw_hero
            call draw_logo
            call map_game
            call sound_tick
            ld a,(hud_dirty)
            or a
            call nz,title_hud_m
            jp present

draw_logo:
            ; the logo: ZEPHYR (two pieces) over ZONE, centred, top at row 7
            ld a,T_LOGOL
            call .piece
            ld a,T_LOGOR
            call .piece
            ; menu line under the logo: PRESS FIRE / TO GET READY / the mode /
            ; the starting stage (once a later one has been reached); a line
            ; just changed with the keys stays up for a while
            ld a,(tsel_t)
            or a
            jr z,.cyc
            ld hl,dt
            sub (hl)
            jr nc,.ct
            xor a
.ct:        ld (tsel_t),a
            ld a,(tsel_m)
            jr .m
.cyc:       ld a,(anim)
            rlca
            rlca
            and 3
            ld a,M_FIRE
            jr z,.m
            ld a,(anim)
            rlca
            rlca
            and 3
            dec a
            ld a,M_TOGR
            jr z,.m
            dec a
            ld a,(anim)
            rlca
            rlca
            and 3
            cp 2
            ld a,(diff)
            jr nz,.c3
            add a,M_CASUAL
            jr .m
.c3:        ld a,(clock+1)          ; alternate: how to change mode / start stage
            rra
            ld a,M_HINT
            jr nc,.m
            ld a,(maxw)
            dec a
            ld a,M_HINT
            jr z,.m
            ld a,M_FROM
.m:         ld hl,msg_id
            cp (hl)
            jr z,.same
            call to_fe
            dw show_msg
.same:      ld a,200
            ld (msg_t),a
            ld a,40
            jp msg_blit
.piece:     ld hl,64
            ld (spr_x),hl
            ld hl,7
            ld (spr_y),hl
            ld b,0
            ld c,0
            call spr_rec
            jp draw_sprite

; ---------------------------------------------------------------------
; the timeline: scenery only behind the title
; ---------------------------------------------------------------------
title_events:
            dw $FFFF


title_hud_m:
            call to_fe
            dw title_hud
            ret

; one paused frame (everything drawn, nothing moves)
pause_frame:
            xor a
            ld (dt),a
            call map_game
            call read_input
            ld a,250
            ld (msg_t),a
            call project_all
            call render_bg
            call draw_objects
            call draw_hero
            call draw_msg
            call map_game
            jp present

; ---------------------------------------------------------------------
; worlds: each ZZWn.DAT carries its ground, sprites, panorama, boss code,
; timeline and tunes (see defs.asm W_CODE)
; ---------------------------------------------------------------------
; start the loaded world's timeline and music
world_begin:
            ld hl,s_stage
            ld de,stg_buf
            ld bc,8
            ldir
            ld a,(world)
            add a,'0'
            ld (stg_buf+6),a
            call map_game
            ld hl,(W_TL)
            ld (ev_ptr),hl
; in play there is no music: the effects are the soundscape
cur_tune:
            ld hl,0
            jp music

; load world A (1..) from the SD card
load_world:
            ld (world_ld),a
            add a,'0'
            ld (wfile+4),a
            ld hl,0
            call music
            xor a
            ld (snd_mask),a
            ld hl,wfile
            call sd_load
            jp c,load_fail
            call world_setup
            xor a
            ld (intoff),a
            ld (ready),a
            ei
            ret
wfile:      db '"ZZW1"',0
s_stage:    db "STAGE 1",0

; colours, sky and names of the world now in memory
world_setup:
            call map_game
            ld a,(W_CSS)
            ld b,L_MODE|L_SPK0
            or a
            jr z,.c0
            ld b,L_MODE|L_SPK0|L_CSS
.c0:        ld a,b
            ld (latchv),a
            ld (LATCH),a
            ld a,(W_SKY)
            ld (sky_byte),a
            ld hl,skyrow
            ld de,skyrow+1
            ld bc,31
            ld (hl),a
            ldir
            ld hl,W_NAME
            ld de,wname_buf
            call .name
            ld hl,W_BNAME
            ld de,bname_buf
.name:      ld bc,17
            ldir
            ; trim trailing spaces
            dec de
.t:         dec de
            ld a,(de)
            cp ' '
            ret nz
            xor a
            ld (de),a
            jr .t

; ---------------------------------------------------------------------
; attract extras, after each demo game: the silent picture title, then
; the storyboard of one world's creatures (the next world each time)
; ---------------------------------------------------------------------
attract_extra:
            call title_pic
            ret nz                  ; a key: back to the title
            jp gallery              ; then the next world's storyboard

; MZ-700 style: a still picture (ZZTTL.DAT), no sound; the one-line logo
; rolls in from the right and settles over the scene
TL_LOGO     equ WORLD+2048      ; db width (bytes), rows, then the rows
TL_X        equ 1               ; where the logo settles (byte column, row)
TL_Y        equ 6
title_pic:
            ld hl,ttlfile
            call load_any
            xor a
            ld (world_ld),a         ; (the picture sat on the world: reload it)
            ld a,L_MODE|L_SPK0
            ld (latchv),a
            ld (LATCH),a
            call map_game
            ld hl,WORLD             ; (the top rows are never re-copied)
            ld de,VRAM
            ld bc,6*32
            ldir
            ld a,32
            ld (gal_y),a
            ld b,170                ; about ten seconds
.f:         push bc
            call read_input
            call bb_wait
            call map_game
            ld hl,WORLD
            ld de,BB
            ld bc,2048
            ldir
            ld a,(gal_y)
            cp TL_X+1
            jr c,.d
            dec a
            ld (gal_y),a
.d:         call tlogo
            xor a
            ld (dirty_top),a
            call present
            pop bc
            ld a,(in_new)
            and $9F
            ret nz
            djnz .f
            ret

; the logo at byte column (gal_y), colour 0 see-through (mapping 7)
tlogo:
            ld a,(TL_LOGO)
            ld b,a
            ld hl,gal_y
            ld a,32
            sub (hl)
            ret z
            cp b
            jr c,.n
            ld a,b
.n:         ld (tl_n),a
            ld e,(hl)
            ld d,0
            ld hl,BB+TL_Y*32
            add hl,de
            ex de,hl
            ld hl,TL_LOGO+2
            ld a,(TL_LOGO+1)
.r:         push af
            push hl
            push de
            ld a,(tl_n)
            ld b,a
.c:         ld a,(hl)
            ld c,a
            push hl
            ld l,a
            ld h,HIGH(MASK0)
            ld a,(de)
            and (hl)
            or c
            ld (de),a
            pop hl
            inc hl
            inc de
            djnz .c
            pop hl
            ld bc,32
            add hl,bc
            ex de,hl
            pop hl
            ld a,(TL_LOGO)
            ld c,a
            ld b,0
            add hl,bc
            pop af
            dec a
            jr nz,.r
            ret

; load any file named at HL, quietly (C never returns: load_fail)
load_any:
            push hl
            ld hl,0
            call music
            xor a
            ld (snd_mask),a
            pop hl
            call sd_load
            jp c,load_fail
            xor a
            ld (intoff),a
            ld (ready),a
            ei
            ret
ttlfile:    db '"ZZTTL"',0

; the finale after the last stage (ZZEND.DAT runs from upper bank 1)
run_ending:
            ld hl,endfile
            call load_any
            xor a
            ld (world_ld),a         ; (it overwrote the world)
            call map_game
            jp $B800
endfile:    db '"ZZEND"',0

; the storyboard: the world's scenery, creatures and boss parade past
; the stilled landscape, each named as it comes to the middle
gallery:
            ld a,(gal_w)
            push af
            inc a
            cp NWORLDS+1
            jr c,.gw
            ld a,1
.gw:        ld (gal_w),a
            pop af
            call load_world
            call game_init
            ld a,4                  ; (more speaker time for the theme)
            ld (minfields),a
            ld a,(mus_off)
            or a
            ld hl,tune_title
            call z,music
            ld a,M_NAME1
            call to_fe
            dw show_msg
            ld hl,0
            ld (gal_s),hl
            ld a,$FF
            ld (gal_c),a
            ld hl,(W_GAL)           ; the parade itself is in the world module,
            dec hl                  ; just before its names (gallery.inc)
            dec hl
            dec hl
            jp (hl)
