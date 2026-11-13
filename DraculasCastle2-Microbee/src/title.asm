; ===========================================================================
;  title.asm - title screen, menu, attract sequence, chapter end
; ===========================================================================


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
            ld a,1
            ld (world_flow),a
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
            ld a,1
            ld (attract_on),a
            call stop_song
            call attract_run
            push af
            xor a
            ld (attract_on),a
            call stop_song
            pop af
            ret
attract_run:
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
            xor a
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
            dec a
            jp world_cinema

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
            call attract_jingle
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
            ld a,1
            ld (world_flow),a
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
