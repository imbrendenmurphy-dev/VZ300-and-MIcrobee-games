; Native title and animated bestiary; gameplay returns through native_leave.
title_screen:
            ld sp,STACK_TOP
            ld a,MUS_TITLE
            call play_music
            call native_enter
            xor a
            ld (menu_sel),a
.redraw:    xor a
            call native_show
            call native_menu
            ld hl,0
            ld (idle),hl
.loop:      call wait_frame
            call read_input
            call mb_mode_keys
            cp $FF
            jr z,.controls
            ld hl,mb_mode
            cp (hl)
            jr z,.controls
            ld (hl),a
            jr .redraw
.controls:  ld a,(n_hit)
            or a
            jr z,.keys
            xor a
            ld (n_hit),a
            call native_menu
.keys:      ld a,(keys_new)
            ld b,a
            and K_LEFT|K_UP
            jr nz,.prev
            ld a,b
            and K_RIGHT|K_DOWN
            jr nz,.next
            bit 4,b
            jr nz,.select
            ld hl,(idle)
            inc hl
            ld (idle),hl
            ld de,1000
            or a
            sbc hl,de
            jr c,.loop
            call native_leave
            call attract
            jp title_screen
.prev:      ld a,(menu_sel)
            dec a
            jp p,.set
            ld a,2
            jr .set
.next:      ld a,(menu_sel)
            inc a
            cp 3
            jr c,.set
            xor a
.set:       ld (menu_sel),a
            call native_menu
            ld hl,0
            ld (idle),hl
            jr .loop
.select:    ld a,(menu_sel)
            cp 2
            jr z,.gallery
            or a
            jr nz,.continue
            call native_leave
            call story_intro
            jp new_game
.continue:  call load_game
            jr c,.nosave
            call native_leave
            jp continue_game
.nosave:    ld hl,native_no_save
            ld de,$F000+30*40+5
            call native_text
            call native32_commit
            ld b,70
            call wait_frames
            call native_menu
            jp .loop
.gallery:   call native_gallery
            jp .redraw

native_menu:
            ld hl,native_menu_new
            ld de,$F000+24*40+8
            call native_text
            ld hl,native_menu_continue
            ld de,$F000+26*40+8
            call native_text
            ld hl,native_menu_gallery
            ld de,$F000+28*40+8
            call native_text
            ld a,(menu_sel)
            ld de,$F000+24*40+8
            or a
            jr z,.cursor
            ld de,$F000+26*40+8
            dec a
            jr z,.cursor
            ld de,$F000+28*40+8
.cursor:    ld hl,native_menu_cursor
            call native_text
            ld a,(music_on)
            or a
            ld hl,native_sound_on
            jr nz,.footer
            ld hl,native_sound_off
.footer:    ld de,$F000+30*40+1
            call native_text
            ld a,(music_vol)
            dec a
            ld hl,native_tone_soft
            jr z,.tone
            ld hl,native_tone_vz
.tone:      ld de,$F000+30*40+13
            call native_text
            jp native32_commit

native_gallery:
            xor a
            ld (native_monster),a
            ld (native_frame),a
.load:      call native_group_load
.show:      call native_anim_gallery
            call native_group_show
            xor a
            ld (native_timer),a
.wait:      call wait_frame
            call read_input
            ld a,(keys_new)
            bit 6,a
            ret nz
            ld b,a
            and K_FIRE|K_RIGHT
            jr nz,.next
            ld a,b
            and K_LEFT
            jr nz,.prev
            ld hl,native_timer
            inc (hl)
            ld a,(hl)
            cp 12
            jr c,.wait
            ld a,(native_anim_enabled)
            or a
            jr z,.ordinary
            call native_anim_advance
            jr .show
.ordinary:
            ld a,(native_frame)
            inc a
            cp 3
            jr c,.frame
            xor a
.frame:     ld (native_frame),a
            jr .show
.next:      ld a,(native_monster)
            inc a
            cp 12
            jr c,.set
            xor a
            jr .set
.prev:      ld a,(native_monster)
            dec a
            jp p,.set
            ld a,11
.set:       ld (native_monster),a
            xor a
            ld (native_frame),a
            jr .load

native_menu_new: db "  NEW GAME",0
native_menu_continue: db "  CONTINUE",0
native_menu_gallery: db "  GHOUL GALLERY",0
native_menu_cursor: db ">",0
native_sound_on: db "N:MUSIC ON ",0
native_sound_off: db "N:MUSIC OFF",0
native_tone_soft: db "-/+ SOFT  C:COLOUR M:MONO",0
native_tone_vz: db "-/+ VZ    C:COLOUR M:MONO",0
native_no_save: db "NO CHECKPOINT - START A NEW GAME",0
