; =====================================================================
;  title.asm - title screen, attract sequence, cards, high scores
; =====================================================================

title_main:
            ld a,$08
            call fe_setlatch
            call hi_init
            xor a
            ld (t_tune),a
            ld (r_page),a
.loop:      call intro_run
            call title_screen
            jr nz,.start
            call story_pages
            jr nz,.start
            call roster_pages
            jr nz,.start
            call hiscore_page
            jr nz,.start
            ; the demo plays the real game by itself
            call m_stop
            xor a
            ld (t_tune),a
            ld a,1
            call game_new
            ld a,$08
            call fe_setlatch
            call hiscore_page
            jr nz,.start
            jr .loop
.start:     call m_stop
            xor a
            ld (t_tune),a
            call game_new
            ld a,$08
            call fe_setlatch
            jr .loop

; the intro cinematic: loaded from OVATT.DAT into low bank 3 each cycle
; (the game's ring buffer lives there, so it can't stay); skipped if the
; file is missing
intro_run:
            call m_stop
            ld hl,att_name
            call sd_load
            ret c
            call $4000
            xor a
            ld (t_tune),a           ; the title theme starts afresh
            ret
att_name:   db '"OVATT"',0

; start the title theme unless it is already playing
title_tune:
            ld a,(t_tune)
            cp 1
            ret z
            ld a,1
            ld (t_tune),a
            ld a,MUS_TITLE
            jp m_play
; the briefing tune for the attract pages
brief_tune:
            ld a,(t_tune)
            cp 2
            ret z
            ld a,2
            ld (t_tune),a
            ld a,MUS_BRIEF
            jp m_play

; ---------------------------------------------------------------------
; the title: logo, droid parade, high score, ticker, PRESS FIRE.
; NZ = start a game
title_screen:
            call title_tune
            ld hl,title_pic
            call fe_pic
            ld d,1
            ld e,2
            call txt_colour
            ld hl,hiscore_txt
            ld de,hiscore
            call hi_line
            ld hl,t_buf
            ld e,47
            call fe_strc
            ; parade: four droids spaced across the lane
            ld hl,par_x
            ld (hl),116
            inc hl
            ld (hl),116+36
            inc hl
            ld (hl),116+72
            inc hl
            ld (hl),116+108
            ld a,(r_page)
            ld (par_t),a
            ld b,4
            ld c,1
.ps:        push bc
            call par_next
            pop bc
            inc c
            djnz .ps
            ld hl,ticker
            ld (tk_p),hl
            xor a
            ld (tk_n),a
            ld hl,1000
            ld (t_time),hl
            ld de,$0102
            call txt_colour
            ld hl,press_txt
            ld e,58
            call fe_strc
.f:         call fe_frame
            call read_input
            ld a,(in_new)
            and K_FIRE
            ret nz
            ; parade
            ld a,(fe_frames)
            and 1
            call z,parade
            ; ticker
            ld hl,tk_n
            inc (hl)
            ld a,(hl)
            cp 3
            call nc,tick_step
            ; PRESS FIRE blinks
            ld a,(fe_frames)
            and 31
            jr nz,.nb
            ld a,(fe_frames)
            and 32
            ld de,$0102
            jr z,.on
            ld de,$0202
.on:        call txt_colour
            ld hl,press_txt
            ld e,58
            call fe_strc
.nb:        ld hl,(t_time)
            dec hl
            ld (t_time),hl
            ld a,h
            or l
            jr nz,.f
            ret                     ; Z: timed out

; the next parade droid in slot C: its type and colours
par_next:
            ld a,(par_t)
            inc a
            cp NTYPES
            jr c,.t
            ld a,1
.t:         ld (par_t),a
            push bc
            ld d,c
            ld b,0
            call build_type
            pop bc
            ret

; move and redraw the parade lane (rows 34-41)
parade:
            ld a,34
            ld b,8
            ld c,$AA
            call fe_rows
            ld hl,par_x
            ld c,1
.d:         ld a,(hl)
            dec a
            jr nz,.mv
            ; off the left: back in at the right as the next type
            push hl
            push bc
            call par_next
            pop bc
            pop hl
            ld a,140
.mv:        ld (hl),a
            cp 117
            jr nc,.skip             ; still behind the right edge
            push hl
            push bc
            ld b,a
            ld a,c
            add a,HIGH(SPRC)
            ld h,a
            ld l,0
            ld a,(fe_frames)        ; a little bob
            rrca
            rrca
            rrca
            and 1
            add a,34
            ld c,a
            call fe_spr
            pop bc
            pop hl
.skip:      inc hl
            inc c
            ld a,c
            cp 5
            jr nz,.d
            ; edges
            ld hl,FEBB+34*32
            ld b,8
.e:         ld a,$AA
            ld (hl),a
            inc hl
            ld (hl),a
            ld de,29
            add hl,de
            ld (hl),a
            inc hl
            ld (hl),a
            inc hl
            djnz .e
            ret

; scroll the ticker (rows 51-55) a character to the left
tick_step:
            xor a
            ld (tk_n),a
            ld hl,FEBB+51*32+1
            ld de,FEBB+51*32
            ld b,5
.r:         push bc
            ld bc,31
            ldir
            inc hl
            inc de
            pop bc
            djnz .r
            ld hl,(tk_p)
            ld a,(hl)
            or a
            jr nz,.c
            ld hl,ticker
            ld a,(hl)
.c:         inc hl
            ld (tk_p),hl
            push af
            ld de,$0002
            call txt_colour
            call fe_txt
            pop af
            ld de,$1F33             ; column 31, row 51
            call draw_char
            ld a,51
            ld b,5
            jp fe_mark

press_txt:  db "PRESS FIRE TO START",0
hiscore_txt: db "HI ",0
ticker:     db "        OVERRIDE ... VIBED BY BPM 2026 ... TAKE BACK THE KESTREL FLEET DECK BY DECK ... "
            db "HOLD FIRE TO LINK INTO A DROID AND MAKE IT YOURS ... HIGHER CLASSES FIGHT HARDER IN THE LINK DUEL ... "
            db "DROIDS YOU RIDE SLOWLY BURN OUT, SO KEEP MOVING ... ENERGIZERS RECHARGE ... CONSOLES SHOW THE DECK AND THE DROID FILES ... ",0

; HL = label, DE = 3-byte BCD -> t_buf "LABEL 012345"
hi_line:
            push de
            ld de,t_buf
.c:         ld a,(hl)
            or a
            jr z,.e
            ld (de),a
            inc hl
            inc de
            jr .c
.e:         pop hl
            ld b,3
            jp bcd_str

; ---------------------------------------------------------------------
; briefing: typed out, then the controls
story_pages:
            call brief_tune
            ld hl,story1
            call type_page
            ret nz
            ld a,150
            call fe_delay
            ret nz
            ld hl,story2
            call type_page
            ret nz
            ld a,200
            jp fe_delay

; type out a page of lines (HL, $FF ends), green on blue
type_page:
            push hl
            ld a,$AA
            call fe_cls
            ld de,$0002
            call txt_colour
            call fe_txt
            pop hl
            ld e,3
.line:      ld a,(hl)
            cp $FF
            ret z                   ; (Z)
            ld d,0
.ch:        ld a,(hl)
            inc hl
            or a
            jr z,.nl
            push hl
            push de
            push af
            call draw_char
            pop af
            cp ' '
            jr z,.sp
            ld a,FX_TYPE
            call fe_sfx
.sp:        pop de
            push de
            ld a,e
            ld b,5
            call fe_mark
            call fe_frame
            call read_input
            pop de
            pop hl
            ld a,(in_new)
            and K_FIRE|K_ANY
            ret nz
            inc d
            jr .ch
.nl:        ld a,e
            add a,6
            ld e,a
            jr .line
; ---------------------------------------------------------------------
; droid files: three droids a page, three pages a visit
roster_pages:
            call brief_tune
            ld b,3
.p:         push bc
            call roster_page
            pop bc
            ret nz
            djnz .p
            xor a
            ret

roster_page:
            ld a,$AA
            call fe_cls
            ld de,$0102
            call txt_colour
            ld hl,files_txt
            ld e,1
            call fe_str2c
            ld b,3
            ld c,14
.d:         push bc
            ld a,(r_page)
            inc a
            cp NTYPES
            jr c,.t
            ld a,1
.t:         ld (r_page),a
            ld a,c
            call roster_entry
            pop bc
            ld a,c
            add a,17
            ld c,a
            djnz .d
            ld a,250
            jp fe_delay

; A = top row: show droid r_page there
roster_entry:
            ld (re_y),a
            ld a,(r_page)
            ld d,7                  ; slot 7
            ld b,0
            push af
            call build_type
            ld a,(re_y)
            ld c,a
            ld b,4
            ld hl,SPRC+$700
            call fe_spr
            pop af
            ; number and name
            ld de,t_buf
            call type_num
            ld de,$0102
            call txt_colour
            ld hl,t_buf
            ld a,(re_y)
            ld e,a
            ld d,5
            call fe_str
            ld a,(r_page)
            call r_name
            ld a,(re_y)
            ld e,a
            ld d,9
            call fe_str
            ; class, energy, weapon
            ld de,$0002
            call txt_colour
            ld a,(r_page)
            call r_stats
            ld hl,t_buf
            ld a,(re_y)
            add a,6
            ld e,a
            ld d,5
            call fe_str
            ld de,$0302
            call txt_colour
            ld a,(r_page)
            call r_weapon
            ld a,(re_y)
            add a,12
            ld e,a
            ld d,5
            jp fe_str

; A = type -> HL = its name
r_name:
            ld hl,r_names
; HL = list of 0-ended strings, A = index -> HL = that string
str_index:
            or a
            ret z
            ld b,a
.l:         ld a,(hl)
            inc hl
            or a
            jr nz,.l
            djnz .l
            ret

; A = type -> HL = weapon name
r_weapon:
            ld c,T_WEAPON
            call type_stat
            ld hl,r_wnames
            jr str_index

; A = type -> t_buf "CLASS n  EN nnn"
r_stats:
            push af
            ld hl,class_txt
            ld de,t_buf
            ld bc,6
            ldir
            pop af
            push af
            ld c,T_CLASS
            call type_stat
            add a,'0'
            ld (de),a
            inc de
            ld a,' '
            ld (de),a
            inc de
            ld (de),a
            inc de
            ld a,'E'
            ld (de),a
            inc de
            ld a,'N'
            ld (de),a
            inc de
            ld a,' '
            ld (de),a
            inc de
            pop af
            ld c,T_EN
            call type_stat
            jp num3

files_txt:  db "DROID FILES",0
class_txt:  db "CLASS "

; ---------------------------------------------------------------------
; high scores
hi_init:
            ld hl,hi_default
            ld de,hitab
            ld bc,30
            ldir
            ld hl,hitab
            ld de,hiscore
            ld bc,3
            ldir
            ret
hi_default: db $01,$50,$00,"BPM"
            db $01,$20,$00,"VZ3"
            db $00,$90,$00,"DSE"
            db $00,$60,$00,"LNK"
            db $00,$30,$00,"OVR"

hiscore_page:
            call brief_tune
            ld a,$AA
            call fe_cls
            ld de,$0102
            call txt_colour
            ld hl,hs_txt
            ld e,2
            call fe_str2c
            ld b,5
            ld hl,hitab
            ld e,20
            ld a,'1'
            ld (hs_n),a
.l:         push bc
            ld a,(hs_n)
            ld c,a
            push hl
            push de
            ld de,t_buf
            ld a,c
            ld (de),a
            inc de
            ld a,'.'
            ld (de),a
            inc de
            ld a,' '
            ld (de),a
            inc de
            push hl
            inc hl
            inc hl
            inc hl
            ldi
            ldi
            ldi
            pop hl
            ld a,' '
            ld (de),a
            inc de
            ld (de),a
            inc de
            ld b,3
            call bcd_str
            pop de
            push de
            ld a,(hs_n)
            ld de,$0102
            cp '1'
            jr nz,.c
            ld de,$0302
.c:         call txt_colour
            pop de
            push de
            ld hl,t_buf
            ld d,9
            call fe_str
            pop de
            pop hl
            ld bc,6
            add hl,bc
            ld a,e
            add a,8
            ld e,a
            pop bc
            push hl
            ld hl,hs_n
            inc (hl)
            pop hl
            djnz .l
            ld a,250
            jp fe_delay
hs_txt:     db "HIGH SCORES",0

; after a game: a place in the table? then the initials
hi_enter:
            ld hl,hitab
            ld b,5
            ld c,0
.f:         push hl
            ld de,score
            ld a,(de)
            cp (hl)
            jr nz,.cmp
            inc hl
            inc de
            ld a,(de)
            cp (hl)
            jr nz,.cmp
            inc hl
            inc de
            ld a,(de)
            cp (hl)
.cmp:       pop hl
            jr z,.no                ; equal: below the old one
            jr nc,.yes
.no:        ld de,6
            add hl,de
            inc c
            djnz .f
            ret                     ; not a high score
.yes:       ; move the rest down
            ld a,c
            ld (he_slot),a
            push hl
            ld a,4
            sub c
            jr z,.nm
            ld b,a
            ld hl,hitab+23
            ld de,hitab+29
.mv:        push bc
            ld bc,6
            lddr
            pop bc
            djnz .mv
.nm:        pop hl
            push hl
            ex de,hl
            ld hl,score
            ld bc,3
            ldir
            ld a,'A'
            ld (de),a
            inc de
            ld (de),a
            inc de
            ld (de),a
            pop hl
            ld bc,3
            add hl,bc
            ld (he_name),hl
            ; the entry screen
            ld a,MUS_HISCORE
            call m_play
            ld a,$AA
            call fe_cls
            ld de,$0102
            call txt_colour
            ld hl,newhs_txt
            ld e,4
            call fe_str2c
            ld de,$0002
            call txt_colour
            ld hl,enter_txt
            ld e,22
            call fe_strc
            ld hl,enter2_txt
            ld e,30
            call fe_strc
            xor a
            ld (he_pos),a
            ld hl,1500
            ld (t_time),hl
.e:         ; draw the three letters (the current one blinks red)
            ld b,3
            ld c,0
.dl:        push bc
            ld de,$0102
            ld a,(he_pos)
            cp c
            jr nz,.cc
            ld a,(fe_frames)
            and 8
            jr z,.cc
            ld de,$0302
.cc:        call txt_colour
            pop bc
            push bc
            ld hl,(he_name)
            ld a,c
            add a,l
            ld l,a
            jr nc,.hl
            inc h
.hl:        ld a,(hl)
            ld (t_buf),a
            xor a
            ld (t_buf+1),a
            ld a,c
            add a,a
            add a,a
            add a,10
            ld d,a
            ld e,42
            ld hl,t_buf
            call fe_str2
            pop bc
            inc c
            djnz .dl
            call fe_frame
            call fe_frame
            call read_input
            ld hl,(he_name)
            ld a,(he_pos)
            add a,l
            ld l,a
            jr nc,.h2
            inc h
.h2:        ld a,(in_new)
            and K_UP|K_RIGHT
            jr z,.n1
            inc (hl)
            ld a,(hl)
            cp 'Z'+1
            jr c,.s1
            ld (hl),'A'
            jr .s1
.n1:        ld a,(in_new)
            and K_DOWN|K_LEFT
            jr z,.n2
            dec (hl)
            ld a,(hl)
            cp 'A'
            jr nc,.s1
.w1:        ld (hl),'Z'
.s1:        ld a,FX_MOVE
            call fe_sfx
.n2:        ld a,(in_new)
            and K_FIRE
            jr z,.n3
            ld a,FX_SELECT
            call fe_sfx
            ld hl,he_pos
            inc (hl)
            ld a,(hl)
            cp 3
            jr nc,.done
.n3:        ld hl,(t_time)
            dec hl
            ld (t_time),hl
            ld a,h
            or l
            jp nz,.e
.done:      ld hl,hitab
            ld de,hiscore
            ld bc,3
            ldir
            ld a,40
            call fe_delay
            jp m_stop
newhs_txt:  db "WELL DONE!",0
enter_txt:  db "YOU MADE THE TOP FIVE",0
enter2_txt: db "UP/DOWN LETTER, FIRE NEXT",0

; ---------------------------------------------------------------------
; cards
shipcard_main:
            ld a,$08
            call fe_setlatch
            ld a,MUS_SHIPCARD
            call m_play
            ld a,$AA
            call fe_cls
            ld de,$0002
            call txt_colour
            ld hl,ship_txt
            ld de,t_buf
            call copy0
            ld a,(ship)
            add a,'1'
            ld (de),a
            inc de
            ld hl,of3_txt
            call copy0
            ld hl,t_buf
            ld e,8
            call fe_strc
            ld de,$0102
            call txt_colour
            ld hl,shipinfo+SI_NAME
            ld e,18
            call fe_str2c
            ld de,$0302
            call txt_colour
            ; "n DECKS  nn DROIDS"
            ld a,(shipinfo+SI_NDECKS)
            ld de,t_buf
            call num3
            ld hl,t_buf+2
            ld de,t_buf2
            call copy0
            ld hl,decks_txt
            call copy0
            push de
            call ship_droids
            ld de,t_buf
            call num3
            pop de
            ld hl,t_buf+1
            call copy0
            ld hl,droids_txt
            call copy0
            ld hl,t_buf2
            ld e,34
            call fe_strc
            ld de,$0002
            call txt_colour
            ld hl,go_txt
            ld e,50
            call fe_strc
            ld a,200
            call fe_delay
            jp m_stop

; A = droids on this ship
ship_droids:
            ld a,(shipinfo+SI_NDECKS)
            ld b,a
            ld hl,shipinfo+SI_DECKS+SD_NDROIDS
            xor a
.l:         add a,(hl)
            ld de,SDSZ
            add hl,de
            djnz .l
            ret

; copy the 0-ended string HL to DE (DE ends on the 0)
copy0:
            ld a,(hl)
            ld (de),a
            or a
            ret z
            inc hl
            inc de
            jr copy0

ship_txt:   db "SHIP ",0
of3_txt:    db " OF 3",0
decks_txt:  db " DECKS   ",0
droids_txt: db " DROIDS",0
go_txt:     db "SECURE EVERY DECK",0

shipdone_main:
            ld a,$08
            call fe_setlatch
            ld a,MUS_SHIPDONE
            call m_play
            ld a,$AA
            call fe_cls
            ld de,$0102
            call txt_colour
            ld hl,secured_txt
            ld e,12
            call fe_str2c
            ld de,$0002
            call txt_colour
            ld hl,shipinfo+SI_NAME
            ld e,28
            call fe_strc
            ld de,$0302
            call txt_colour
            ld hl,bonus_txt
            ld e,40
            call fe_strc
            ld a,220
            call fe_delay
            jp m_stop
secured_txt: db "SHIP SECURED",0
bonus_txt:  db "BONUS 5000",0

gameover_main:
            ld a,$08
            call fe_setlatch
            ld a,MUS_GAMEOVER
            call m_play
            ld a,$AA
            call fe_cls
            ld de,$0302
            call txt_colour
            ld hl,over_txt
            ld e,20
            call fe_str2c
            ld de,$0102
            call txt_colour
            ld hl,score_txt
            ld de,score
            call hi_line
            ld hl,t_buf
            ld e,40
            call fe_strc
            ld a,200
            call fe_delay
            call m_stop
            jp hi_enter
over_txt:   db "GAME OVER",0
score_txt:  db "SCORE ",0

ending_main:
            ld a,$08
            call fe_setlatch
            ld a,MUS_ENDING
            call m_play
            ld hl,ending1
            call type_page
            ld a,250
            call fe_delay
            ld a,250
            call fe_delay
            ld hl,ending2
            call type_page
            ld a,250
            call fe_delay
            ld a,250
            call fe_delay
            call m_stop
            jp hi_enter
ending1:    db "THE LAST LIGHTS OF THE",0
            db "LEVIATHAN FLICKER AND DIE.",0
            db "",0
            db "THE OVERMIND IS GONE. ACROSS",0
            db "THE KESTREL FLEET THE DROIDS",0
            db "STAND STILL, WAITING FOR",0
            db "ORDERS THAT WILL NEVER COME.",0
            db "",0
            db "THE FLEET IS FREE.",0
            db $FF
ending2:    db "",0
            db "      O V E R R I D E",0
            db "",0
            db "     DESIGN, CODE, MUSIC",0
            db "        VIBED BY BPM",0
            db "             2026",0
            db "",0
            db "  FOR THE DICK SMITH VZ300",0
            db "  WITH THE BENNVENN SD + 128K",0
            db "  THANKS FOR PLAYING!",0
            db $FF
