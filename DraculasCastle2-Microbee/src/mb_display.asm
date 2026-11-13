; Display choice, deliberately presented in monochrome before the choice.
mb_mode_menu:
            ld a,1
            ld (mb_mode),a
            call mb_invalidate
            ld a,$AA
            call cls_back
            ld b,1
            ld c,2
            call text_colors
            ld hl,mb_display_text
            ld c,2
            ld d,12
            call print_at
            call present_full
.wait:      call wait_frame
            call mb_mode_keys
            cp $FF
            jr z,.wait
            ld (mb_mode),a
            call mb_invalidate
            ret

; A = 0 colour, 1 mono, FF no selection. No game state changes here.
mb_mode_keys:
            ld a,1
            out ($0B),a
            ld a,3
            call mb_keytest
            ld a,0
            jr nz,.done
            ld a,13
            call mb_keytest
            ld a,1
            jr nz,.done
            ld a,$FF
.done:      push af
            xor a
            out ($0B),a
            pop af
            ret

mb_pause_display:
            call mb_mode_keys
            cp $FF
            ret z
            ld hl,mb_mode
            cp (hl)
            ret z
            ld (hl),a
            call mb_invalidate
            jp present_full

mb_display_text:
            db "DRACULA'S CASTLE II",1,1
            db "CHOOSE YOUR DISPLAY",1,1
            db "C - COLOUR",1
            db "M - MONOCHROME",1,1
            db "CHANGE WITH C/M WHILE PAUSED",0
