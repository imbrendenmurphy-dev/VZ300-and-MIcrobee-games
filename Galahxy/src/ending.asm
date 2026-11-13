; =====================================================================
;  ending.asm - the game is won: four cards, a lives bonus, the credits
; =====================================================================
ending:
            call silence
            ld hl,tune_title
            call music
            ld hl,str_credit
            call bar_msg
            ; ---- card 1
            call bb_wait
            ld a,$AA
            call cls_bb
            ld a,10
            ld b,14
            ld c,$FF
            call band_bb
            ld a,1
            ld c,3
            call text_col
            ld hl,en_1a
            ld a,12
            call big_centre
            ld a,1
            ld c,2
            call text_col
            ld hl,en_1b
            ld a,30
            call small_centre
            ld hl,en_1c
            ld a,38
            call small_centre
            ld a,0
            ld c,2
            call text_col
            ld hl,en_1d
            ld a,48
            call small_centre
            ld a,250
            call show_hold
            ; ---- card 2: the cast go home
            call bb_wait
            ld a,$AA
            call cls_bb
            ld a,1
            ld c,2
            call text_col
            ld hl,en_2a
            ld a,9
            call small_centre
            ld b,0
.pp:        push bc
            ld a,b
            add a,a
            add a,a
            add a,a
            ld c,a
            add a,a
            add a,a
            add a,c                 ; 40 px apart
            add a,18+XOFF
            ld c,22+YOFF
            ld e,b
            ld b,a
            ld a,e
            add a,SPR_BIGGAZ
            call blit
            pop bc
            inc b
            ld a,b
            cp 3
            jr nz,.pp
            ld a,0
            ld c,2
            call text_col
            ld hl,en_2b
            ld a,42
            call small_centre
            ld hl,en_2c
            ld a,49
            call small_centre
            ld a,250
            call show_hold
            ; ---- card 3: a bonus for the lives in hand
            call bb_wait
            ld a,$AA
            call cls_bb
            ld a,10
            ld b,9
            ld c,$FF
            call band_bb
            ld a,1
            ld c,3
            call text_col
            ld hl,en_3a
            ld a,12
            call small_centre
            ld a,1
            ld c,2
            call text_col
            ld hl,en_3b
            ld de,26*32+3
            call bbde
            call print
            ld a,(p_lives)
            cp 10
            jr c,.l9
            ld a,9
.l9:        push af
            add a,'0'
            ld de,26*32+15
            call bbde
            call putc
            pop af
            ld d,a                  ; n x 10,000 = n000 tens
            ld e,0
            ld a,d
            rlca
            rlca
            rlca
            rlca
            ld d,a
            ld a,34
            call tally_line
            ld hl,en_3c
            ld de,44*32+3
            call bbde
            call print
            ld hl,score
            ld de,44*32+18
            call bbde
            call print_score
            ld a,1
            ld (hud_dirty),a
            call hud_force
            ld a,220
            call show_hold
            ; ---- card 4: credits
            call bb_wait
            ld a,$AA
            call cls_bb
            ld hl,logo_data
            ld de,9*32
            call bbde
            ld bc,LOGO_H*32
            ldir
            ld a,1
            ld c,2
            call text_col
            ld hl,str_credit
            ld a,32
            call small_centre
            ld a,0
            ld c,2
            call text_col
            ld hl,en_4a
            ld a,42
            call small_centre
            ld hl,en_4b
            ld a,49
            call small_centre
            ld a,250
            call show_hold
            jp silence
en_1a:      db "YOU DID IT!",0
en_1b:      db "THE COSMIC COCKATOO IS PLUCKED",0
en_1c:      db "AND THE GALAHXY PARTIES ON.",0
en_1d:      db "(SOMEBODY HAS TO CLEAN UP, THOUGH)",0
en_2a:      db "OUR HEROES FLEW HOME",0
en_2b:      db "FOR A CUPPA, SOME TOAST",0
en_2c:      db "AND A GOOD LONG SQUAWK.",0
en_3a:      db "ONE LAST BONUS",0
en_3b:      db "LIVES LEFT",0
en_3c:      db "FINAL SCORE",0
en_4a:      db "THANKS FOR PLAYING, MATE.",0
en_4b:      db "NOW TRY ANOTHER FLYER!",0
