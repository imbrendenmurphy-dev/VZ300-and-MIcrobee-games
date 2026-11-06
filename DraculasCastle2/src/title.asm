; ===========================================================================
;  title.asm - title screen, menu, attract sequence, chapter end
; ===========================================================================

title_screen:
            ld sp,STACK_TOP
            ld a,MUS_TITLE
            call play_music
.redraw:    call draw_title
            ld hl,0
            ld (idle),hl
            xor a
            ld (menu_sel),a
            ld a,100
            ld (thunder_t),a
            call draw_title_menu
            call present_full
.loop:      call wait_frame
            call read_input
            ld hl,n_hit             ; N pressed: show the new music setting
            ld a,(hl)
            ld (hl),0
            or a
            jr z,.nn
            call draw_title_menu
            ld c,0
            ld b,32
            ld d,51
            ld e,57
            call present_rect
.nn:
            ; thunder & lightning
            ld hl,thunder_t
            dec (hl)
            jr nz,.nt
            call random
            and 127
            add a,150
            ld (hl),a
            call lightning
.nt:        ; alternate credit line every 128 frames
            ld a,(frame_count)
            and 127
            jr nz,.nc
            call draw_credit
            ld c,0
            ld b,32
            ld d,57
            ld e,63
            call present_rect
.nc:        ld a,(keys_new)
            or a
            jr nz,.key
            ld a,(any_key)
            or a
            jr nz,.reset_idle
            ld hl,(idle)
            inc hl
            ld (idle),hl
            ld de,1000
            or a
            sbc hl,de
            jr c,.loop
            call attract
            jp title_screen
.reset_idle:
            ld hl,0
            ld (idle),hl
            jr .loop
.key:       ld hl,0
            ld (idle),hl
            ld b,a
            bit 2,b
            jr nz,.left
            bit 3,b
            jr nz,.right
            bit 4,b
            jr nz,.select
            jp .loop
.left:      ld a,(menu_sel)
            dec a
            jp p,.ms
            ld a,2
            jr .ms
.right:     ld a,(menu_sel)
            inc a
            cp 3
            jr c,.ms
            xor a
.ms:        ld (menu_sel),a
            ld hl,sfx_tick
            call play_sfx
            call draw_title_menu
            ld c,0
            ld b,32
            ld d,51
            ld e,57
            call present_rect
            jp .loop
.select:    ld hl,sfx_select
            call play_sfx
            ld a,(menu_sel)
            or a
            jr z,.new
            cp 1
            jr z,.cont
            ; music toggle
            ld a,(music_on)
            xor 1
            ld (music_on),a
            call draw_title_menu
            ld c,0
            ld b,32
            ld d,51
            ld e,57
            call present_rect
            jp .loop
.new:       call story_intro
            jp new_game
.cont:      call load_game
            jr c,.nosave
            jp continue_game
.nosave:    ld hl,str_nosave
            call title_note
            jp .loop

title_note:
            push hl
            ld c,0
            ld b,32
            ld d,57
            ld e,6
            ld a,$AA
            call fill_rect
            ld b,1
            ld c,2
            call text_colors
            pop hl
            ld d,57
            ld b,0
            ld c,32
            call print_centre
            ld c,0
            ld b,32
            ld d,57
            ld e,63
            jp present_rect

draw_title:
            ld a,0
            call set_css
            ld ix,f_title
            ld de,BACK
            xor a
            call sd_load
            jp draw_credit

draw_credit:
            ld c,0
            ld b,32
            ld d,57
            ld e,6
            ld a,$AA
            call fill_rect
            ld a,(frame_count)
            and 128
            ld hl,str_sub
            ld b,1
            jr z,.s
            ld hl,str_credit
            ld b,3
.s:         push hl
            ld c,2
            call text_colors
            pop hl
            ld d,58
            ld b,0
            ld c,32
            jp print_centre

menu_x:     db 1,12,22
menu_txt:   dw str_m_new,str_m_cont,str_m_music
str_m_new:  db " NEW GAME ",0
str_m_cont: db " CONTINUE ",0
str_m_music: db " MUSIC ON ",0
str_m_mute: db " MUSIC OFF",0

draw_title_menu:
            ld c,0
            ld b,32
            ld d,51
            ld e,6
            ld a,$AA
            call fill_rect
            xor a
.l:         ld (tm_i),a
            ld b,1
            ld c,2
            ld hl,menu_sel
            cp (hl)
            jr nz,.n
            ld c,3
.n:         call text_colors
            ld a,(tm_i)
            add a,a
            ld e,a
            ld d,0
            ld hl,menu_txt
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld a,(tm_i)
            cp 2
            jr nz,.t
            ld a,(music_on)
            or a
            jr nz,.t
            ld hl,str_m_mute
.t:         ld a,(tm_i)
            ld e,a
            ld d,0
            push hl
            ld hl,menu_x
            add hl,de
            ld c,(hl)
            pop hl
            ld d,51
            call print_at
            ld a,(tm_i)
            inc a
            cp 3
            jr nz,.l
            ret

; flash the sky: swap colour set for a few frames + thunder
lightning:
            ld hl,sfx_thunder
            call play_sfx
            ld a,1
            call set_css
            ld b,2
            call wait_frames
            xor a
            call set_css
            ld b,3
            call wait_frames
            ld a,1
            call set_css
            ld b,1
            call wait_frames
            xor a
            jp set_css

str_sub:    db "THE CASTLE AWAKENS",0
str_credit: db "VIBED BY BPM  2026",0
str_nosave: db "NO SAVED GAME FOUND",0

; ---------------------------------------------------------------------------
; story pages (full screen text), skippable
; ---------------------------------------------------------------------------
story_intro:
            ld hl,story1
            call text_page
            ret c
            ld hl,story2
            call text_page
            ret

; text_page: HL = text (newlines), shows on a dark screen with a frame.
; waits for a key (carry set if key was pressed to skip all) - simplified: always returns NC
text_page:
            push hl
            ld a,$AA
            call cls_back
            ; red frame
            ld c,0
            ld b,32
            ld d,0
            ld e,1
            ld a,$FF
            call fill_rect
            ld c,0
            ld b,32
            ld d,63
            ld e,1
            ld a,$FF
            call fill_rect
            ld b,1
            ld c,2
            call text_colors
            pop hl
            ld c,1
            ld d,4
            call print_at
            ld a,0
            call set_css
            call present_full
            call wait_key
            or a
            ret

story1:     db 2,3,"     TRANSYLVANIA, 1897",1,1,2,1
            db "THE VILLAGERS OF BORGO PASS",1
            db "WHISPER OF STRANGE LIGHTS IN",1
            db "THE OLD CASTLE ON THE HILL.",1,1
            db "FOLK HAVE VANISHED. GRAVES",1
            db "LIE OPEN. THE DEAD WALK.",1,1
            db "SOMETHING ANCIENT HAS WOKEN.",0
story2:     db 2,3,"         YOUR QUEST",1,1,2,1
            db "ARMED WITH A WOODEN STAKE AND",1
            db "MORE COURAGE THAN SENSE, YOU",1
            db "CLIMB TO THE CASTLE GATES",1
            db "AT THE STROKE OF MIDNIGHT...",1,1
            db 2,0,"W/I FORWARD  A/J D/L TURN",1
            db "S/K TURN BACK  SPACE ACT",1
            db "M MAP  E ITEMS  P PAUSE",0

; ---------------------------------------------------------------------------
; attract sequence: story + location tour + monster gallery
; ---------------------------------------------------------------------------
attract:
            ld hl,story1
            call attract_page
            ret nz
            ; location tour: grounds then hall
            ld hl,tour_list
.tour:      ld a,(hl)
            cp $FF
            jr z,.gallery
            push hl
            ld (cur_area),a
            inc hl
            ld a,(hl)
            ld (px),a
            inc hl
            ld a,(hl)
            ld (py),a
            inc hl
            ld a,(hl)
            ld (pdir),a
            call tour_view
            pop hl
            jr nz,.abort
            ld de,4
            add hl,de
            jr .tour
.gallery:   ld a,1
.gl:        push af
            call gallery_monster
            pop bc
            ret nz
            ld a,b
            inc a
            cp NUM_MONSTERS+1
            jr nz,.gl
            ret
.abort:     ret

tour_list:  db 0,8,13,0, 0,2,8,0, 0,8,3,0, 1,8,13,0, 1,8,8,0, 1,2,5,2, 2,8,14,0, 2,11,7,0, 3,1,1,2, 3,7,6,0, 4,8,14,0, 4,4,11,0, 5,8,14,0, 5,7,6,0, $FF

; show one exploration view with area name; NZ if a key was pressed
tour_view:
            xor a
            ld (tour_tmp),a
            ld a,(cur_area)
            call load_area          ; p1 + p2 + pack, builds MAPBUF
            ld a,MAPBUF/256
            ld (map_page),a
            ld hl,AREA_RAM+2
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (area_events),de
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (area_exits),de
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (area_name),de
            ld a,(hl)
            ld (area_door_decor),a
            inc hl
            ld a,(hl)
            ld (area_door_kind),a
            ld a,$AA
            call cls_back
            call render_view
            ; caption on the right
            ld b,1
            ld c,2
            call text_colors
            ld hl,(area_name)
            ld d,20
            ld b,20
            ld c,12
            call print_centre
            ld hl,str_demo
            ld b,3
            ld c,2
            call text_colors
            ld hl,str_demo
            ld d,56
            ld b,0
            ld c,32
            call print_centre
            xor a
            call set_css
            call present_full
            ld b,120
            jp attract_wait

str_demo:   db "PRESS ANY KEY",0

; monster gallery: A = monster id -> NZ if key pressed
gallery_monster:
            push af
            ; the monster's home backdrop (def byte 13)
            dec a
            add a,a
            add a,a
            add a,a
            add a,a
            ld l,a
            ld h,0
            ld de,monsters+13
            add hl,de
            ld a,(hl)
            ld (AREA_RAM+26),a
            pop af
            call battle_load
            ld a,(bt_css)
            call set_css
            call draw_scene
            call clear_ui
            ld b,1
            ld c,2
            call text_colors
            ld hl,str_ghoulies
            ld d,50
            ld b,0
            ld c,32
            call print_centre
            ld de,msgbuf
            call mon_name_de
            ld b,3
            ld c,2
            call text_colors
            ld hl,msgbuf
            ld d,57
            ld b,0
            ld c,32
            call print_centre
            call present_full
            ld a,1
            ld (bt_anim),a
            ld b,150
.w:         push bc
            call wait_frame
            call read_input
            call idle_anim
            pop bc
            ld a,(any_key)
            or a
            ret nz
            djnz .w
            xor a
            ret

str_ghoulies: db "GROOVY GHOULIES OF THE CASTLE",0

attract_page:
            push hl
            ld a,$AA
            call cls_back
            ld b,1
            ld c,2
            call text_colors
            pop hl
            ld c,1
            ld d,4
            call print_at
            xor a
            call set_css
            call present_full
            ld b,200
; wait B frames; NZ if any key
attract_wait:
.w:         push bc
            call wait_frame
            call read_input
            pop bc
            ld a,(any_key)
            or a
            ret nz
            djnz .w
            xor a
            ret

; ---------------------------------------------------------------------------
; chapter end: summary screen
; ---------------------------------------------------------------------------
chapter_end:
            ld a,MUS_ENDING
            call play_music
            ld a,$AA
            call cls_back
            ld b,1
            ld c,2
            call text_colors
            ld hl,end_text
            ld c,1
            ld d,2
            call print_at
            ; stats
            ld b,3
            ld c,2
            call text_colors
            ; time (minutes) = play_time / 3000
            ld hl,(play_time+1)     ; frames/256
            ld c,12                 ; 3000/256 ~ 11.7
            call div_hl_c
            ld l,a
            ld h,0
            ld de,msgbuf
            push hl
            ld hl,str_time
            call strcpy_de
            pop hl
            call num3_left
            ld hl,str_min
            call strcpy_de
            ld hl,msgbuf
            ld c,4
            ld d,38
            call print_at
            ld de,msgbuf
            ld hl,str_kills
            call strcpy_de
            ld a,(kills)
            ld l,a
            ld h,0
            call num3_left
            ld hl,msgbuf
            ld c,4
            ld d,44
            call print_at
            ld de,msgbuf
            ld hl,str_secrets
            call strcpy_de
            ld a,(secrets)
            ld l,a
            ld h,0
            call num3_left
            ld hl,str_of2
            call strcpy_de
            ld hl,msgbuf
            ld c,4
            ld d,50
            call print_at
            ld de,msgbuf
            ld hl,str_treas
            call strcpy_de
            ld a,(treasure)
            ld l,a
            ld h,0
            call num3_left
            ld hl,str_of5
            call strcpy_de
            ld a,' '
            ld (de),a
            inc de
            ld hl,str_lv
            call strcpy_de
            ld a,(lvl)
            ld l,a
            ld h,0
            call num3_left
            ld hl,msgbuf
            ld c,4
            ld d,56
            call print_at
            xor a
            call set_css
            call present_full
            call wait_key
            ld b,100
            call wait_frames
            call wait_key
            jp title_screen

end_text:   db "  DRACULA CRUMBLES TO DUST.",1
            db "  DAWN BREAKS OVER BORGO PASS,",1
            db "  AND THE CASTLE SLEEPS AGAIN.",1,1
            db 2,3,"      THE END",1
            db 2,1,"  ...FOR NOW.",0
str_time:   db "TIME     ",0
str_min:    db " MIN",0
str_kills:  db "GHOULIES ",0
str_secrets: db "SECRETS  ",0
str_treas:  db "TREASURE ",0
