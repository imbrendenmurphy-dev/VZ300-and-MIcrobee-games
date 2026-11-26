; =====================================================================
;  ovl.asm - OVTTL.DAT: the front end's overlay, loaded into low bank 3
;  ($4000-$5FFF, below the sprite cache) whenever no deck is live: at the
;  start of each attract cycle, and for the ship cards, game over and
;  the ending. Holds the intro cinematic, the title and attract pages,
;  the cards, high scores and their music. Runs in the front end's
;  mapping and uses its drawing kit.
; =====================================================================
            include "gen/mainsym.inc"
            include "gen/fesym.inc"
            org $4000
ov_attract: jp attract          ; A = 0: play, 1: run the demo
ov_shipcard: jp shipcard_main
ov_shipdone: jp shipdone_main
ov_gameover: jp gameover_main
ov_ending:  jp ending_main

attract:
            call intro
            call title_screen
            jr nz,.start
            call story_pages
            jr nz,.start
            call roster_pages
            jr nz,.start
            call hiscore_page
            jr nz,.start
            ld a,1
            ret
.start:     xor a
            ret

; the title theme / the briefing tune, unless already playing
title_tune:
            ld a,(t_tune)
            cp 1
            ret z
            ld a,1
            ld (t_tune),a
            ld hl,song_title
            jp m_playhl
brief_tune:
            ld a,(t_tune)
            cp 2
            ret z
            ld a,2
            ld (t_tune),a
            ld hl,song_brief
            jp m_playhl

; =====================================================================
; the intro cinematic: a starfield, the Kestrel freighter gliding in,
; red alert, the probe's launch, a flash into the title. Fire skips it.
NSTAR       equ 18
SHIP_Y      equ 24
EV_TEXT     equ 1
EV_CLRB     equ 2
EV_SHIP     equ 3
EV_ALERT    equ 4
EV_PROBE    equ 5
EV_FLASH    equ 6
EV_END      equ 7
EV_CLRT     equ 8

; the script: time (fields), event, argument
script:     dw 30
            db EV_TEXT
            dw t_belt
            dw 110
            db EV_SHIP
            dw 0
            dw 190
            db EV_TEXT
            dw t_dark1
            dw 250
            db EV_TEXT
            dw t_dark2
            dw 470
            db EV_CLRB
            dw 0
            dw 475
            db EV_ALERT
            dw 0
            dw 480
            db EV_TEXT
            dw t_rogue1
            dw 540
            db EV_TEXT
            dw t_rogue2
            dw 660
            db EV_CLRB
            dw 0
            dw 662
            db EV_CLRT
            dw 0
            dw 665
            db EV_PROBE
            dw 0
            dw 700
            db EV_TEXT
            dw t_probe
            dw 800
            db EV_FLASH
            dw 0
            dw 812
            db EV_END
            dw 0
            dw $FFFF

; text: row, then the string
t_belt:     db 3,"2391. THE OUTER BELT.",0
t_dark1:    db 48,"THE KESTREL FREIGHTERS",0
t_dark2:    db 55,"HAVE GONE DARK.",0
t_rogue1:   db 48,"A ROGUE MIND RULES",0
t_rogue2:   db 55,"EVERY DROID ABOARD.",0
t_probe:    db 55,"ONE PROBE. ONE CHANCE.",0

intro:
            ld a,$08
            call fe_setlatch
            call m_stop
            xor a
            ld (t_tune),a
            ld hl,song_intro
            call m_playhl
            ld a,$AA
            call fe_cls
            ; stars in the two bands clear of the text and the ship
            ld hl,stars
            ld b,NSTAR
.si:        call random
            and 127
            ld (hl),a
            inc hl
            call random
            and 15
            cp 10
            jr c,.up
            add a,39-10             ; rows 39-44
            jr .sy
.up:        add a,11                ; rows 11-20
.sy:        ld (hl),a
            inc hl
            call random
            and 1
            inc a
            ld (hl),a
            inc hl
            djnz .si
            ld hl,0
            ld (at_t),hl
            ld hl,script
            ld (at_ev),hl
            xor a
            ld (at_tp+1),a
            ld (at_ship),a
            ld (at_alert),a
            ld (at_probe),a
            ld (at_end),a
            ld a,128
            ld (at_sx),a
            ld a,SHIP_Y
            ld (at_sy),a
.f:         call fe_frame
            call read_input
            ld a,(in_new)
            and K_FIRE|K_ANY
            jr nz,.skip
            call at_events
            ld a,(fe_frames)
            and 1
            call z,at_stars
            call at_type
            call at_shipmove
            call at_alertf
            call at_probef
            ld hl,(at_t)
            inc hl
            ld (at_t),hl
            ld a,(at_end)
            or a
            jr z,.f
.skip:      ld a,$08
            call fe_setlatch
            call m_stop
            xor a
            ld (t_tune),a
            ret

; run the events that are due
at_events:
            ld hl,(at_ev)
            ld e,(hl)
            inc hl
            ld d,(hl)
            ld hl,(at_t)
            or a
            sbc hl,de
            ret c                   ; not yet
            ld hl,(at_ev)
            inc hl
            inc hl
            ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (at_ev),hl
            cp EV_TEXT
            jr z,.text
            cp EV_CLRB
            jr z,.clrb
            cp EV_CLRT
            jr z,.clrt
            cp EV_SHIP
            jr z,.ship
            cp EV_ALERT
            jr z,.alert
            cp EV_PROBE
            jr z,.probe
            cp EV_FLASH
            jr z,.flash
            ld a,1                  ; EV_END
            ld (at_end),a
            ret
.text:      ld a,(de)
            ld (at_row),a
            inc de
            ld (at_tp),de
            ; centre it
            ex de,hl
            ld b,0
.ln:        ld a,(hl)
            or a
            jr z,.lc
            inc b
            inc hl
            jr .ln
.lc:        ld a,32
            sub b
            srl a
            ld (at_col),a
            jr at_events
.clrb:      ld a,46
            ld b,18
            jr .clr
.clrt:      xor a
            ld b,10
.clr:       ld c,$AA
            call fe_rows
            jr at_events
.ship:      ld a,1
            ld (at_ship),a
            jr at_events
.alert:     ld a,64
            ld (at_alert),a
            jr at_events
.probe:     ld a,1
            ld (at_probe),a
            xor a
            ld (at_px),a
            ld a,58
            ld (at_py),a
            jp at_events
.flash:     xor a
            ld b,64
            ld c,$55
            call fe_rows
            ld a,FX_ZAP
            call fe_sfx
            jp at_events

; typewriter: a character every other field
at_type:
            ld hl,(at_tp)
            ld a,h
            or a
            ret z
            ld a,(fe_frames)
            and 1
            ret nz
            ld a,(hl)
            or a
            jr z,.done
            inc hl
            ld (at_tp),hl
            push af
            ld de,$0102
            call txt_colour
            call fe_txt
            pop af
            push af
            ld a,(at_col)
            ld d,a
            inc a
            ld (at_col),a
            ld a,(at_row)
            ld e,a
            pop af
            push de
            push af
            call draw_char
            pop af
            pop de
            cp ' '
            jr z,.m
            push de
            ld a,FX_TYPE
            call fe_sfx
            pop de
.m:         ld a,e
            ld b,5
            jp fe_mark
.done:      xor a
            ld (at_tp+1),a
            ret

; stars drift left (erase, move, draw)
at_stars:
            ld hl,stars
            ld b,NSTAR
.s:         push bc
            push hl
            ld b,(hl)
            inc hl
            ld c,(hl)
            push hl
            push bc
            ld a,2
            call fe_px              ; old spot back to blue
            pop bc
            pop hl
            inc hl
            ld a,b
            sub (hl)                ; speed
            and 127
            ld b,a
            pop hl
            ld (hl),a
            push hl
            ld a,(hl)
            and 3
            ld a,1                  ; mostly yellow, some green
            jr nz,.c
            xor a
.c:         call fe_px
            pop hl
            inc hl
            inc hl
            inc hl
            pop bc
            djnz .s
            ret

; the freighter glides in: a pixel every 4 fields to x = 44
at_shipmove:
            ld a,(at_ship)
            or a
            ret z
            ld a,(fe_frames)
            and 3
            ret nz
            ld a,(at_sx)
            cp 44
            jr z,ship_draw
            dec a
            ld (at_sx),a
; draw the freighter at x = at_sx, row at_sy (clipped on the right)
ship_draw:
            ld a,(at_sx)
            cp 128
            ret nc
            ld c,a
            ; source = art + phase * 168
            and 3
            ld l,a
            ld h,0
            ld de,168
            call mul16x8_de         ; HL = phase*168
            ld de,ship_art
            add hl,de
            ld (at_src),hl
            ; bytes to draw: min(12, 32 - col)
            ld a,c
            srl a
            srl a
            ld (at_scol),a
            ld b,a
            ld a,32
            sub b
            cp 13
            jr c,.w
            ld a,12
.w:         ld (at_sw),a
            ld a,(at_sy)
            ld (at_sr),a
            ld b,14
.r:         push bc
            ld a,(at_sr)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,(at_scol)
            add a,l
            ld l,a
            ld de,FEBB
            add hl,de
            ex de,hl
            ld hl,(at_src)
            push hl
            ld a,(at_sw)
            ld c,a
            ld b,0
            ldir
            pop hl
            ld bc,12
            add hl,bc
            ld (at_src),hl
            ld hl,at_sr
            inc (hl)
            pop bc
            djnz .r
            ld a,(at_sy)
            ld b,14
            jp fe_mark

; HL = L * DE (L small)
mul16x8_de:
            ld a,l
            ld hl,0
            or a
            ret z
.l:         add hl,de
            dec a
            jr nz,.l
            ret

; red alert: the palette flips between the colour sets, with a siren
at_alertf:
            ld a,(at_alert)
            or a
            ret z
            dec a
            ld (at_alert),a
            ld b,a
            and 15
            jr nz,.n
            ld a,FX_ALARM
            call fe_sfx
.n:         ld a,b
            and 4
            ld a,$08
            jr z,.s
            ld a,$18
.s:         jp fe_setlatch

; the probe streaks from the bottom left to the freighter's hull
at_probef:
            ld a,(at_probe)
            or a
            ret z
            ld a,(fe_frames)
            and 1
            ret nz
            ; erase the old dot
            ld a,(at_px)
            ld b,a
            ld a,(at_py)
            ld c,a
            ld a,2
            push bc
            call fe_px
            pop bc
            inc b
            ld a,2
            call fe_px
            ld a,(at_px)
            cp 56
            jr nc,.hit
            inc a
            ld (at_px),a
            ; y = 58 - x*7/16
            ld l,a
            ld h,0
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,hl
            or a
            sbc hl,de               ; x*7
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            ld a,58
            sub l
            ld (at_py),a
            ld c,a
            ld a,(at_px)
            ld b,a
            ld a,1
            push bc
            call fe_px
            pop bc
            inc b
            ld a,1
            jp fe_px
.hit:       xor a
            ld (at_probe),a
            ld a,FX_ZAP
            call fe_sfx
            jp ship_draw            ; mend the hull where the dot was

; =====================================================================
; the title: logo, droid parade, high score, a smooth ticker, PRESS FIRE.
; NZ = start a game
title_screen:
            call title_tune
            ld hl,title_pic
            call fe_pic
            ld de,$0102
            call txt_colour
            ld hl,hiscore_txt
            ld de,hiscore
            call hi_line
            ld hl,t_buf
            ld e,45
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
            ; the ticker band starts empty
            ld hl,tk_buf
            ld bc,5*33
.tc:        ld (hl),$AA
            inc hl
            dec bc
            ld a,b
            or c
            jr nz,.tc
            ld hl,ticker
            ld (tk_p),hl
            xor a
            ld (tk_n),a
            ld hl,1000
            ld (t_time),hl
            call press_draw
.f:         call fe_frame
            call read_input
            ld a,(in_new)
            and K_FIRE
            ret nz
            ld a,(fe_frames)
            and 1
            call z,parade
            call tick_step
            ; PRESS FIRE blinks
            ld a,(fe_frames)
            and 31
            call z,press_draw
            ld hl,(t_time)
            dec hl
            ld (t_time),hl
            ld a,h
            or l
            jr nz,.f
            ret                     ; Z: timed out

press_draw:
            ld a,(fe_frames)
            and 32
            ld de,$0102
            jr z,.on
            ld de,$0202
.on:        call txt_colour
            ld hl,press_txt
            ld e,59
            jp fe_strc

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

; the ticker: rows 52-56, a pixel a field. tk_buf is 5 rows of 33
; bytes; each new character is drawn into the hidden 33rd column.
TK_ROW      equ 52
tick_step:
            ld a,(tk_n)
            or a
            jr nz,.sh
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
            ld hl,tk_buf
            ld (txt_base),hl
            ld a,33
            ld (txt_stride),a
            pop af
            ld de,$2000             ; column 32, row 0
            call draw_char
            ld a,4
            ld (tk_n),a
.sh:        ld hl,tk_n
            dec (hl)
            ; shift each row left by a pixel (two bits), right to left
            ld hl,tk_buf+32
            ld c,5
.r:         push hl
            or a
            ld b,33
.b1:        rl (hl)
            dec hl
            djnz .b1
            pop hl
            push hl
            or a
            ld b,33
.b2:        rl (hl)
            dec hl
            djnz .b2
            pop hl
            ld de,33
            add hl,de
            dec c
            jr nz,.r
            ; copy the 32 visible bytes of each row
            ld hl,tk_buf
            ld de,FEBB+TK_ROW*32
            ld b,5
.cp:        push bc
            ld bc,32
            ldir
            inc hl
            pop bc
            djnz .cp
            ld a,TK_ROW
            ld b,5
            jp fe_mark

press_txt:  db "PRESS FIRE TO START",0
hiscore_txt: db "HI ",0
ticker:     db "OVERRIDE ... VIBED BY BPM 2026 ... TAKE BACK THE KESTREL FLEET DECK BY DECK ... "
            db "HOLD FIRE TO LINK INTO A DROID AND MAKE IT YOURS ... HIGHER CLASSES FIGHT HARDER IN THE LINK DUEL ... "
            db "DROIDS YOU RIDE SLOWLY BURN OUT, SO KEEP MOVING ... ENERGIZERS RECHARGE ... "
            db "CONSOLES SHOW THE DECK AND THE DROID FILES ... N TURNS THE MUSIC OFF ...        ",0

; =====================================================================
; briefing: typed out over the circuit backdrop, then the controls
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
            ld a,BK_GRID|BK_FRAME
            call fe_back
            ld de,$0102             ; yellow: clear of the green grid
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
            ld a,BK_STARS
            call fe_back
            ld a,BF_SYSTEM
            ld hl,files_txt
            ld e,2
            call fe_header
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
files_txt:  db "DROID FILES",0

; ---------------------------------------------------------------------
; high scores
hiscore_page:
            call brief_tune
            ld a,BK_GRID|BK_FRAME
            call fe_back
            ld a,BF_GOLD
            ld hl,hs_txt
            ld e,3
            call fe_header
            ld de,$0612             ; panel: column 6, row 18
            ld bc,$142A             ; 20 bytes x 42 rows
            ld a,3
            call fe_panel
            ld b,5
            ld hl,hitab
            ld e,22
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
            ld hl,song_hiscore
            call m_playhl
            ld a,BK_STARS|BK_FRAME
            call fe_back
            ld a,BF_GOLD
            ld hl,newhs_txt
            ld e,4
            call fe_header
            ld de,$0002
            call txt_colour
            ld hl,enter_txt
            ld e,20
            call fe_strc
            ld hl,enter2_txt
            ld e,54
            call fe_strc
            ld de,$091D             ; a panel for the letters: x 36-91
            ld bc,$0E12
            ld a,0
            call fe_panel
            xor a
            ld (he_pos),a
            ld hl,1500
            ld (t_time),hl
.e:         ; the three letters in the display font, the current one red
            ld de,$0A20             ; clear them: x 40-87, rows 32-42
            ld bc,$0C0B
            ld a,$AA
            call fe_box
            ld b,3
            ld c,0
.dl:        push bc
            ld a,BF_GOLD
            ld hl,he_pos
            ld b,c
            ld c,a
            ld a,(hl)
            cp b
            ld a,c
            jr nz,.cc
            ld a,(fe_frames)
            and 8
            ld a,BF_GOLD
            jr z,.cc
            ld a,BF_ALERT
.cc:        call bf_style
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
            add a,c
            add a,a
            add a,a                 ; 20 * position
            add a,41
            ld d,a
            ld e,33
            ld hl,t_buf
            call big_str
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
            ld (hl),'Z'
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

; =====================================================================
; cards
shipcard_main:
            ld a,$08
            call fe_setlatch
            ld hl,song_shipcard
            call m_playhl
            ld a,BK_STARS|BK_FRAME
            call fe_back
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
            ld e,4
            call fe_strc
            ld a,BF_GOLD
            ld hl,shipinfo+SI_NAME
            ld e,15
            call fe_header
            ld a,42                 ; the freighter, centred
            ld (at_sx),a
            ld a,31
            ld (at_sy),a
            call ship_draw
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
            ld e,49
            call fe_strc
            ld de,$0002
            call txt_colour
            ld hl,go_txt
            ld e,56
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

ship_txt:   db "SHIP ",0
of3_txt:    db " OF 3",0
decks_txt:  db " DECKS   ",0
droids_txt: db " DROIDS",0
go_txt:     db "SECURE EVERY DECK",0

shipdone_main:
            ld a,$08
            call fe_setlatch
            ld hl,song_shipdone
            call m_playhl
            ld a,BK_STARS|BK_FRAME
            call fe_back
            ld a,BF_GOLD
            ld hl,secured_txt
            ld e,6
            call fe_header
            ld de,$0002
            call txt_colour
            ld hl,shipinfo+SI_NAME
            ld e,24
            call fe_strc
            ld a,42
            ld (at_sx),a
            ld a,33
            ld (at_sy),a
            call ship_draw
            ld de,$0302
            call txt_colour
            ld hl,bonus_txt
            ld e,54
            call fe_strc
            ld a,220
            call fe_delay
            jp m_stop
secured_txt: db "SHIP SECURED",0
bonus_txt:  db "BONUS 5000",0

gameover_main:
            ld a,$08
            call fe_setlatch
            ld hl,song_gameover
            call m_playhl
            ld a,BK_GRID|BK_FRAME
            call fe_back
            ld a,BF_ALERT
            ld hl,over_txt
            ld e,18
            call fe_header
            ld de,$0726
            ld bc,$1209
            ld a,3
            call fe_panel
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
            ld hl,song_ending
            call m_playhl
            ld hl,ending1
            call type_page
            ld a,250
            call fe_delay
            ld a,250
            call fe_delay
            ld a,BK_STARS|BK_FRAME
            call fe_back
            ld a,BF_GOLD
            ld hl,end_big
            ld e,10
            call fe_header
            ld de,$0002
            call txt_colour
            ld hl,ending2
            ld e,28
.l:         ld a,(hl)
            cp $FF
            jr z,.w
            push hl
            push de
            call fe_strc
            pop de
            pop hl
.z:         ld a,(hl)
            inc hl
            or a
            jr nz,.z
            ld a,e
            add a,7
            ld e,a
            jr .l
.w:         ld a,250
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
end_big:    db "OVERRIDE",0
ending2:    db "VIBED BY BPM 2026",0
            db "FOR THE DICK SMITH VZ300",0
            db "WITH THE BENNVENN SD + 128K",0
            db "THANKS FOR PLAYING!",0
            db $FF

            include "gen/ovsongs.inc"
            include "gen/ovdata.inc"

; ---- variables (fresh each load)
at_t:       ds 2
at_ev:      ds 2
at_tp:      ds 2
at_row:     ds 1
at_col:     ds 1
at_ship:    ds 1
at_sx:      ds 1
at_sy:      ds 1
at_alert:   ds 1
at_probe:   ds 1
at_px:      ds 1
at_py:      ds 1
at_end:     ds 1
at_src:     ds 2
at_scol:    ds 1
at_sw:      ds 1
at_sr:      ds 1
stars:      ds NSTAR*3
par_x:      ds 4
par_t:      ds 1
tk_p:       ds 2
tk_n:       ds 1
tk_buf:     ds 5*33
hs_n:       ds 1
he_name:    ds 2
he_pos:     ds 1
ov_end:
            assert ov_end <= $6000
