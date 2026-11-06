; =====================================================================
;  TENNIS II - title, attract cycle, menus, World Tour, exhibition,
;  two players, target practice, trophy, ending, Hall of Fame, records
; =====================================================================

; background music only in "music + SFX" mode
bgm:
        ld a,(soundmode)
        cp 2
        jp nz,stop_music
        jp play_music

attract:
        ld sp,STACKTOP
        xor a
        ld (mode),a
        ld (flashtim),a
.cycle: call title_screen
        jr nz,.go
        call how_to_play
        jr nz,.go
        call meet_tour
        jr nz,.go
        call run_demo
        jr nz,.go
        call hiscore_screen
        jr nz,.go
        jr .cycle
.go:    ld sp,STACKTOP
        call stop_music
        jp main_menu

; plain CSS0 page: clear to green, big heading HL at row 2 in red.
; A drifting dot texture (grass or net) starts behind it once it is revealed.
page:
        push hl
        call tex_off
        ld a,1
        ld (tex_want),a
        ld a,MODE1
        ld (palbase),a
        call dl_reset
        call do_frame
        xor a
        call cls_bg
        ld a,1
        ld (noq),a
        ld a,3
        ld b,0
        call set_ink
        pop hl
        ld a,h
        or l
        jr z,.n
        ld e,2
        call print2_c
.n:     ld a,$55
        ld de,$000D
        ld bc,$2001
        call fill_rect
        xor a
        ld (noq),a
        ret
; text: HL string, D col, E row, A ink (on green)
text:
        push hl
        push de
        ld b,0
        call set_ink
        pop de
        pop hl
        jp print
; centred text: HL, E row, A ink
text_c:
        push hl
        push de
        ld b,0
        call set_ink
        pop de
        pop hl
        jp print_c
; list of lines: HL -> (db ink, row : dw string), terminated by $FF
text_list:
        ld a,(hl)
        cp $FF
        ret z
        ld b,a
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        ld a,b
        call text_c
        pop hl
        inc hl
        jr text_list

; wait up to BC frames (start aborts -> NZ); HL = per-frame hook or 0
page_wait:
        ld (infohook),hl
.l:     push bc
        call dl_reset
        ld hl,(infohook)
        ld a,h
        or l
        call nz,.call
        call do_frame
        pop bc
        call check_start
        ret nz
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret
.call:  jp (hl)

; ---------------------------------------------------------------------
; TITLE
title_screen:
        call tex_off
        ld a,SURF_GRASS
        call set_surface
        ld a,MODE1
        ld (palbase),a
        call dl_reset
        call do_frame
        ld hl,title_pic
        ld de,BGBUF
        call unpack
        ld a,1
        ld (noq),a
        ld a,2
        ld b,0
        call set_ink
        ld hl,s_gslam
        ld e,22
        call print_c
        xor a
        ld (noq),a
        call wipe_show
        ld a,16
        ld (cbudget),a
        ld hl,mus_title_0
        ld de,mus_title_1
        call bgm
        ld hl,0
        ld (attr_t),hl
        ld a,$FF
        ld (tmsg),a
        call rally_init
.loop:  call dl_reset
        call rally_step
        call title_message
        call do_frame
        call check_start
        jr nz,.out
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,760
        or a
        sbc hl,de
        jr nz,.loop
        xor a
.out:   push af
        ld a,24
        ld (cbudget),a
        call stop_music
        pop af
        ret
s_gslam: db "* G R A N D   S L A M *",0

title_message:
        ld hl,(attr_t)
        ld a,l
        and 127
        ret nz
        ld a,(tmsg)
        inc a
        and 3
        ld (tmsg),a
        push af
        xor a
        ld de,$003A
        ld bc,$2005
        call fill_rect
        pop af
        add a,a
        ld l,a
        ld h,0
        ld de,title_msgs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,58
        ld a,1
        jp text_c
title_msgs: dw tm0,tm1,tm2,tm3
tm0:    db "PRESS FIRE OR SPACE TO PLAY",0
tm1:    db "THE SEQUEL TO VZ TENNIS",0
tm2:    db "VIBED BY BPM 2026",0
tm3:    db "GRASS  CLAY  HARD  NIGHT",0

; title rally: two little players knock the ball up and down the title court
; ra_t (0..35), ra_dir (0 = going up), ra_x0/ra_x1 screen x, ra_pf/ra_pn players' x
RA_T equ 36
rally_init:
        xor a
        ld (ra_t),a
        ld (ra_dir),a
        ld (ra_sw0),a
        ld (ra_sw1),a
        ld a,70
        ld (ra_x0),a
        ld (ra_pn),a
        ld a,52
        ld (ra_x1),a
        ld a,60
        ld (ra_pf),a
        ret
rally_step:
        ld a,(ra_t)
        inc a
        cp RA_T
        jr c,.k
        ; the ball reaches a player: hit it back
        ld a,(ra_dir)
        xor 1
        ld (ra_dir),a
        ld a,(ra_x1)
        ld (ra_x0),a
        ld b,52
        call rand_n
        add a,38
        ld (ra_x1),a
        ld a,10
        ld hl,ra_sw0
        ld a,(ra_dir)
        or a
        jr nz,.s
        inc hl
.s:     ld (hl),10
        xor a
.k:     ld (ra_t),a
        ; ball position
        ld b,a
        ld hl,ra_frac
        call idx_byte
        ld e,a                  ; t/T * 256
        push de
        ld a,(ra_x0)
        ld b,a
        ld a,(ra_x1)
        sub b
        call smul8
        ld b,a
        ld a,(ra_x0)
        add a,b
        ld (ra_bx),a
        pop de
        ld a,(ra_dir)
        or a
        ld a,-20
        jr z,.d
        ld a,20
.d:     call smul8
        ld b,a
        ld a,(ra_dir)
        or a
        ld a,55
        jr z,.y
        ld a,35
.y:     add a,b
        ld (ra_by),a
        ; players drift towards where the ball will arrive
        ld a,(ra_dir)
        or a
        ld hl,ra_pf
        jr z,.pm
        ld hl,ra_pn
.pm:    ld a,(ra_x1)
        cp (hl)
        jr z,.dr
        jr c,.dl
        inc (hl)
        jr .dr
.dl:    dec (hl)
.dr:    ; far player (team A, far frames)
        ld a,(ra_pf)
        sub 4
        ld b,a
        ld c,27
        ld hl,ra_sw0
        ld d,SPR_F
        call ra_player
        ; shadow + ball
        ld a,(ra_bx)
        dec a
        ld b,a
        ld a,(ra_by)
        ld c,a
        ld a,SPR_SHADOW
        call spr_put
        ld a,(ra_t)
        ld hl,ra_arc
        call idx_byte
        ld b,a
        ld a,(ra_by)
        sub b
        dec a
        ld c,a
        ld a,(ra_bx)
        dec a
        ld b,a
        ld a,SPR_BALL
        call spr_put
        ; near player last (in front)
        ld a,(ra_pn)
        sub 4
        ld b,a
        ld c,47
        ld hl,ra_sw1
        ld d,SPR_N
        jp ra_player
; B,C = position, HL = swing timer, D = sprite base
ra_player:
        ld a,(hl)
        or a
        jr z,.n
        dec (hl)
        ld a,FR_FORE
        cp 6
        jr .s
.n:     ld a,(framecount)
        and 8
        ld a,FR_RUN1
        jr z,.s
        ld a,FR_RUN2
.s:     add a,d
        jp spr_put
ra_frac:
        db 0,7,14,21,28,36,43,50,57,64,71,78,85,92,100,107,114,121
        db 128,135,142,149,156,164,171,178,185,192,199,206,213,220,228,235,242,249
ra_arc: db 0,2,4,5,7,8,9,10,11,12,13,13,14,14,15,15,15,15
        db 15,15,15,15,14,14,13,13,12,11,10,9,8,7,5,4,2,0

; ---------------------------------------------------------------------
how_to_play:
        ld hl,s_how
        call page
        ld hl,how_lines
        call text_list
        call wipe_show
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        ld bc,420
        ld hl,0
        call page_wait
        push af
        call stop_music
        pop af
        ret
s_how:  db "HOW TO PLAY",0
how_lines:
        db 1,16 : dw hw0
        db 1,22 : dw hw1
        db 2,28 : dw hw2
        db 2,34 : dw hw3
        db 3,40 : dw hw4
        db 3,46 : dw hw5
        db 1,52 : dw hw6
        db 2,58 : dw hw7
        db $FF
hw0:    db "MOVE: Q A M ,  OR JOYSTICK",0
hw1:    db "THE SWING IS AUTOMATIC!",0
hw2:    db "WHERE THE BALL MEETS YOU = ANGLE",0
hw3:    db "HOLD LEFT/RIGHT TO STEER IT",0
hw4:    db "FIRE: POWER  (SMASH IF HIGH)",0
hw5:    db "PULL BACK: LOB  PUSH UP: DROP",0
hw6:    db "SERVE: FIRE TO TOSS, FIRE TO HIT",0
hw7:    db "3 WINNERS IN A ROW: ON FIRE!",0

; ---------------------------------------------------------------------
; meet the tour: two characters per page
meet_tour:
        xor a
        ld (mt_i),a
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
.pg:    ld hl,s_meet
        call page
        ld a,(mt_i)
        ld e,15
        call char_panel
        ld a,(mt_i)
        inc a
        ld e,39
        call char_panel
        call wipe_show
        ld bc,240
        ld hl,0
        call page_wait
        jr nz,.out
        ld a,(mt_i)
        add a,2
        ld (mt_i),a
        cp 8
        jr c,.pg
        xor a
.out:   push af
        call stop_music
        pop af
        ret
s_meet: db "MEET THE TOUR",0

; char_panel: A = character, E = top row. Portrait + name + style + quote.
char_panel:
        ld (cp_c),a
        ld a,e
        ld (cp_r),a
        ld d,1
        ld a,(cp_c)
        call blit_portrait
        ld a,(cp_c)
        call char_lname
        ld a,(cp_r)
        inc a
        ld e,a
        ld d,8
        ld a,3
        call text
        ld a,(cp_c)
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,chardesc
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld a,(cp_r)
        add a,8
        ld e,a
        ld d,8
        ld a,1
        call text
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,(cp_r)
        add a,14
        ld e,a
        ld d,8
        ld a,2
        jp text

; HL = long name of character A
char_lname:
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        sbc hl,de
        sbc hl,de
        ld de,chartab+2
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

chardesc:
        dw cd0a,cd0b, cd1a,cd1b, cd2a,cd2b, cd3a,cd3b
        dw cd4a,cd4b, cd5a,cd5b, cd6a,cd6b, cd7a,cd7b, cd8a,cd8b
cd0a: db "NEW ON TOUR. KEEN!",0
cd0b: db "'IS IT MY SERVE?'",0
cd1a: db "LOVES A HIGH LOB",0
cd1b: db "'WHAT GOES UP...'",0
cd2a: db "CHARGES THE NET",0
cd2b: db "'SEE YOU AT THE NET!'",0
cd3a: db "HUGE SERVE, HEAVY FEET",0
cd3b: db "'STRAYA! BOOM!'",0
cd4a: db "GETS EVERYTHING BACK",0
cd4b: db "'I NEVER MISS. EVER.'",0
cd5a: db "FAST AND FURIOUS",0
cd5b: db "'BLINK AND YOU MISS IT'",0
cd6a: db "PRECISE ANGLES",0
cd6b: db "'GEOMETRY WINS GAMES'",0
cd7a: db "THE CHAMPION",0
cd7b: db "'8 BITS OF PURE CLASS'",0
cd8a: db "THAT'S YOU!",0
cd8b: db "'LET'S PLAY!'",0

; blit_portrait: A = portrait 0..8, D = column, E = row (24x20 -> BG + queue)
blit_portrait:
        push de
        ld l,a
        ld h,0
        add hl,hl               ; *120 = *128 - *8
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,bc
        ld bc,portraits
        add hl,bc
        pop de
        push hl
        push de
        ld bc,$0614
        call queue_rect
        pop de
        call scraddr
        ld a,h
        or $88
        ld h,a
        ex de,hl
        pop hl
        ld b,20
.r:     push bc
        ld bc,6
        ldir
        ex de,hl
        ld bc,26
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
        ret

; ---------------------------------------------------------------------
; DEMO: computer v computer on a random surface
run_demo:
        ld a,MODE_DEMO
        ld (mode),a
        ld b,4
        call rand_n
        call set_surface
        ld b,8
        call rand_n
        ld (tmpa),a
.o:     ld b,8
        call rand_n
        ld hl,tmpa
        cp (hl)
        jr z,.o
        ld ix,pl1
        ld c,CTL_CPU
        ld b,2
        call setup_player
        ld a,(tmpa)
        ld ix,pl0
        ld c,CTL_CPU
        ld b,2
        call setup_player
        ld a,(gamesper)
        push af
        ld a,2
        ld (gamesper),a
        ld a,1
        ld (setsneed),a
        ld hl,2000
        ld (demotim),hl
        call play_match
        ld b,a
        pop af
        ld (gamesper),a
        call stop_music
        ld a,b
        cp $FF                  ; start pressed
        jr z,.go
        xor a
        ret
.go:    or a
        ret

; ---------------------------------------------------------------------
hiscore_screen:
        ld hl,s_hof
        call page
        call draw_hitab
        ld hl,s_play
        ld e,58
        ld a,1
        call text_c
        call wipe_show
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        xor a
        ld (ra_t),a
        ld bc,360
        ld hl,hof_anim
        call page_wait
        push af
        call stop_music
        pop af
        ret
s_hof:  db "HALL OF FAME",0
s_play: db "PRESS FIRE TO PLAY",0
; a ball bounces along under the table
hof_anim:
        ld a,(framecount)
        and 127
        ld b,a
        ld a,(framecount)
        and 15
        ld hl,ra_arc
        add a,a
        call idx_byte
        srl a
        ld c,a
        ld a,55
        sub c
        ld c,a
        ld a,b
        cp 118
        ret nc
        ld a,SPR_BALL
        jp spr_put

draw_hitab:
        ld ix,hitab
        xor a
        ld (hrow),a
.l:     ld a,(hrow)
        and 1
        ld a,1
        jr z,.c
        ld a,3
.c:     ld b,0
        call set_ink
        ld a,(hrow)
        ld b,a
        add a,a
        add a,a
        add a,a
        sub b
        add a,18
        ld (hy),a
        ld a,(hrow)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,ranks
        add hl,de
        ld a,(hy)
        ld e,a
        ld d,7
        call print
        ld a,(ix+3)
        ld (nameb),a
        ld a,(ix+4)
        ld (nameb+1),a
        ld a,(ix+5)
        ld (nameb+2),a
        xor a
        ld (nameb+3),a
        ld hl,nameb
        ld a,(hy)
        ld e,a
        ld d,12
        call print
        push ix
        pop hl
        ld b,3
        ld a,(hy)
        ld e,a
        ld d,17
        call print_bcd
        ld de,6
        add ix,de
        ld a,(hrow)
        inc a
        ld (hrow),a
        cp 5
        jr nz,.l
        ret
ranks:  db "1ST",0,"2ND",0,"3RD",0,"4TH",0,"5TH",0

; initials entry for the tour points in tourpts
enter_hiscore:
        ld ix,hitab
        ld c,0
.f:     push ix
        pop hl
        ld de,tourpts
        ld b,3
.cmp:   ld a,(de)
        cp (hl)
        jr c,.lower
        jr nz,.found
        inc hl
        inc de
        djnz .cmp
.lower: ld de,6
        add ix,de
        inc c
        ld a,c
        cp 5
        jr nz,.f
        ret
.found: ld a,4
        sub c
        jr z,.noshift
        ld b,a
        ld hl,hitab+23
        ld de,hitab+29
.sh:    push bc
        ld bc,6
        lddr
        pop bc
        djnz .sh
.noshift:
        ld (hiptr),ix
        ld hl,tourpts
        push ix
        pop de
        ld bc,3
        ldir
        ld a,'A'
        ld (nameb),a
        ld (nameb+1),a
        ld (nameb+2),a
        xor a
        ld (nameb+3),a
        ld hl,s_nhs
        call page
        ld hl,s_ent
        ld e,18
        ld a,1
        call text_c
        ld hl,s_ent2
        ld e,52
        ld a,2
        call text_c
        ld hl,tourpts
        ld b,3
        ld de,$0D2A
        call print_bcd
        call wipe_show
        ld hl,mus_hiscore_0
        ld de,mus_hiscore_1
        call jingle
        xor a
        ld (hpos),a
        ld hl,1500
        ld (attr_t),hl
.loop:  call dl_reset
        ld a,3
        ld b,0
        call set_ink
        ld hl,nameb
        ld de,$0D1E
        call print2
        ; blinking cursor under the letter
        ld a,(framecount)
        and 8
        jr z,.nc
        ld a,(hpos)
        add a,a
        add a,13
        add a,a
        add a,a
        ld b,a
        ld c,41
        ld e,1
        call dl_pixel
        ld a,(hpos)
        add a,a
        add a,13
        add a,a
        add a,a
        inc a
        ld b,a
        ld c,41
        ld e,1
        call dl_pixel
.nc:    ld a,(inpnew)
        ld c,a
        ld a,(hpos)
        ld e,a
        ld d,0
        ld hl,nameb
        add hl,de
        bit 2,c
        jr z,.nu
        ld a,(hl)
        call next_letter
        ld (hl),a
        ld a,SFX_TICK
        call play_sfx
.nu:    bit 3,c
        jr z,.nd
        ld a,(hl)
        call prev_letter
        ld (hl),a
        ld a,SFX_TICK
        call play_sfx
.nd:    bit 1,c
        jr z,.nl
        ld a,(hpos)
        or a
        jr z,.nl
        dec a
        ld (hpos),a
.nl:    ld a,c
        and $11
        jr z,.nr
        ld a,SFX_BLIP
        call play_sfx
        ld a,(hpos)
        inc a
        ld (hpos),a
        cp 3
        jr z,.done
.nr:    ld a,(keysnew)
        and 4
        jr nz,.done
        call do_frame
        ld hl,(attr_t)
        dec hl
        ld (attr_t),hl
        ld a,h
        or l
        jp nz,.loop
.done:  ld de,(hiptr)
        inc de
        inc de
        inc de
        ld hl,nameb
        ld bc,3
        ldir
        call stop_music
        call save_records
        jp hiscore_screen
next_letter:
        cp 'Z'
        jr z,.sp
        cp ' '
        jr z,.a
        inc a
        ret
.sp:    ld a,' '
        ret
.a:     ld a,'A'
        ret
prev_letter:
        cp 'A'
        jr z,.sp
        cp ' '
        jr z,.z
        dec a
        ret
.sp:    ld a,' '
        ret
.z:     ld a,'Z'
        ret
s_nhs:  db "NEW RECORD!",0
s_ent:  db "ENTER YOUR INITIALS",0
s_ent2: db "UP/DOWN, FIRE TO ACCEPT",0

; ---------------------------------------------------------------------
; MAIN MENU
MENU_N equ 6
main_menu:
        ld sp,STACKTOP
        xor a
        ld (mode),a
        ld (intour),a
        ld a,SURF_GRASS
        call set_surface
.redraw:
        ld hl,s_title2
        call page
        ld hl,s_menuhelp
        ld e,58
        ld a,2
        call text_c
        call wipe_show
        call menu_items
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        ld hl,0
        ld (attr_t),hl
.loop:  call dl_reset
        ; cursor ball
        ld a,(menusel)
        ld b,a
        add a,a
        add a,a
        add a,a
        sub b
        sub b
        add a,17
        ld c,a
        ld a,(framecount)
        and 16
        ld b,20
        jr z,.cb
        ld b,22
.cb:    ld a,SPR_BALL
        call spr_put
        call do_frame
        ; idle -> attract
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,1500
        or a
        sbc hl,de
        jp z,.idle
        ; C: the classic court
        ld a,($6FFB)
        bit 3,a
        call z,unlock_classic
        ld a,(inpnew)
        ld c,a
        or a
        jr z,.nk
        ld hl,0
        ld (attr_t),hl
.nk:    bit 2,c
        jr z,.nu
        ld a,(menusel)
        or a
        jr z,.nu
        dec a
        ld (menusel),a
        ld a,SFX_BLIP
        call play_sfx
.nu:    bit 3,c
        jr z,.nd
        ld a,(menusel)
        cp MENU_N-1
        jr nc,.nd
        inc a
        ld (menusel),a
        ld a,SFX_BLIP
        call play_sfx
.nd:    ld a,c
        and 3
        jr z,.nlr
        call menu_change
        call menu_items
.nlr:   ld a,c
        and $10
        jr nz,.sel
        ld a,(keysnew)
        and 4
        jr nz,.sel
        ld a,(keysnew)
        bit 0,a
        jp z,.loop
        call toggle_sound
        call menu_items
        jp .loop
.sel:   ld a,(menusel)
        cp 4
        jr c,.go
        call menu_change
        call menu_items
        jp .loop
.go:    ld a,SFX_SELECT
        call play_sfx
        call stop_music
        ld a,(menusel)
        or a
        jp z,tour_start
        dec a
        jp z,exhib_setup
        dec a
        jp z,twop_setup
        jp practice_mode
.idle:  call stop_music
        jp attract
s_title2:   db "TENNIS II",0
s_menuhelp: db "UP/DOWN + FIRE. C: CLASSIC COURT",0

menu_change:    ; left/right/fire on an option line
        ld a,(menusel)
        cp 4
        jr nz,.snd
        ld a,(gamesper)
        add a,2
        cp 8
        jr c,.g
        ld a,2
.g:     ld (gamesper),a
        ld a,SFX_TICK
        jp play_sfx
.snd:   cp 5
        ret nz
        call toggle_sound
        ld a,SFX_TICK
        jp play_sfx

menu_items:
        ld hl,menu_tab
        ld b,0
.l:     push bc
        push hl
        ld a,(menusel)
        cp b
        ld a,1
        jr nz,.c
        ld a,3
.c:     push af
        ld a,b
        ld c,a
        add a,a
        add a,a
        add a,a
        sub c
        sub c
        add a,16
        ld e,a
        ld (tmpy),a
        xor a
        push de
        ld de,0
        ld a,(tmpy)
        ld e,a
        ld d,6
        ld bc,$1A05
        xor a
        call fill_rect
        pop de
        pop af
        ld d,7
        pop hl
        push hl
        push af
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop af
        call text
        pop hl
        inc hl
        inc hl
        pop bc
        inc b
        ld a,b
        cp MENU_N
        jr nz,.l
        ; values
        ld a,(gamesper)
        ld e,40
        ld d,23
        call print_dec2
        ld a,(soundmode)
        add a,a
        ld l,a
        ld h,0
        ld de,sndnames
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,$0E2E
        jp print
menu_tab: dw mi0,mi1,mi2,mi3,mi4,mi5
mi0:    db "WORLD TOUR",0
mi1:    db "EXHIBITION",0
mi2:    db "TWO PLAYERS",0
mi3:    db "TARGET PRACTICE",0
mi4:    db "GAMES PER SET:",0
mi5:    db "SOUND:",0
sndnames: dw sm0,sm1,sm2
sm0:    db "OFF      ",0
sm1:    db "SFX ONLY ",0
sm2:    db "MUSIC+SFX",0

unlock_classic:
        ld a,(classic)
        or a
        ret nz
        ld a,1
        ld (classic),a
        ld hl,mus_fire_0
        ld de,mus_fire_1
        call jingle
        ld hl,s_unlock
        ld e,52
        ld a,2
        call text_c
        jp save_records
s_unlock: db "CLASSIC 1984 COURT UNLOCKED!",0

; ---------------------------------------------------------------------
; EXHIBITION: pick an opponent and a court
exhib_setup:
        ld a,MODE_EXHIB
        ld (mode),a
        ld hl,s_exhib
        call page
        ld hl,s_exhelp
        ld e,58
        ld a,2
        call text_c
        call wipe_show
        call exhib_draw
.l:     call dl_reset
        call do_frame
        ld a,(keysnew)
        bit 3,a
        jp nz,main_menu
        ld a,(inpnew)
        ld c,a
        bit 0,c
        jr z,.n1
        ld a,(exopp)
        inc a
        and 7
        ld (exopp),a
        call exhib_draw
.n1:    ld a,(inpnew)
        ld c,a
        bit 1,c
        jr z,.n2
        ld a,(exopp)
        dec a
        and 7
        ld (exopp),a
        call exhib_draw
.n2:    ld a,(inpnew)
        ld c,a
        and $0C
        jr z,.n3
        call next_court
        call exhib_draw
.n3:    ld a,(inpnew)
        and $10
        jr nz,.go
        ld a,(keysnew)
        and 4
        jr z,.l
.go:    ld a,SFX_SELECT
        call play_sfx
        ld a,(excourt)
        call set_surface
        ld ix,pl1
        ld a,8
        ld c,CTL_ANY
        ld b,0
        call setup_player
        ld ix,pl0
        ld a,(exopp)
        ld c,CTL_CPU
        ld b,1
        call setup_player
        ld a,1
        ld (setsneed),a
        call play_match
        call result_screen
        jp main_menu
s_exhib:  db "EXHIBITION",0
s_exhelp: db "L/R: RIVAL  U/D: COURT  FIRE: GO",0

next_court:
        ld a,(classic)
        add a,4
        ld b,a
        ld a,(excourt)
        inc a
        cp b
        jr c,.k
        xor a
.k:     ld (excourt),a
        ld a,SFX_TICK
        jp play_sfx

exhib_draw:
        ld a,SFX_BLIP
        call play_sfx
        xor a
        ld de,$0010
        ld bc,$2028
        call fill_rect
        ld a,(exopp)
        ld e,16
        call char_panel
        ld hl,s_court
        ld de,$0233
        ld a,1
        call text
        ld a,(excourt)
        call surf_name
        ld de,$0933
        ld a,3
        jp text
s_court: db "COURT:",0

; HL = name of surface A
surf_name:
        add a,a
        add a,a
        add a,a
        add a,a
        add a,13
        ld l,a
        ld h,0
        ld de,surftab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; ---------------------------------------------------------------------
; TWO PLAYERS: P1 (red) on joystick 1 / Q A M , SPACE; P2 (blue) on stick 2 / I J K L H
twop_setup:
        ld a,MODE_2P
        ld (mode),a
        ld hl,s_2p
        call page
        ld hl,twop_lines
        call text_list
        call wipe_show
        call twop_court
.l:     call dl_reset
        call do_frame
        ld a,(keysnew)
        bit 3,a
        jp nz,main_menu
        ld a,(inpnew)
        ld c,a
        and $0F
        jr z,.n
        call next_court
        call twop_court
.n:     ld a,(inpnew)
        and $10
        jr nz,.go
        ld a,(keysnew)
        and 4
        jr z,.l
.go:    ld a,SFX_SELECT
        call play_sfx
        ld a,(excourt)
        call set_surface
        ld ix,pl1
        ld a,8
        ld c,CTL_PAD1
        ld b,0
        call setup_player
        ld hl,s_p1
        ld (pl1+P_NAME),hl
        ld hl,s_lp1
        ld (pl1+P_LNAME),hl
        ld ix,pl0
        ld a,8
        ld c,CTL_PAD2
        ld b,0
        call setup_player
        ld hl,s_p2
        ld (pl0+P_NAME),hl
        ld hl,s_lp2
        ld (pl0+P_LNAME),hl
        ld a,1
        ld (setsneed),a
        call play_match
        call result_screen
        jp main_menu
s_2p:   db "TWO PLAYERS",0
twop_lines:
        db 3,17 : dw tp0
        db 1,23 : dw tp1
        db 2,31 : dw tp2
        db 1,37 : dw tp3
        db 2,58 : dw tp4
        db $FF
tp0:    db "PLAYER 1  (STARTS NEAR END)",0
tp1:    db "JOYSTICK 1 OR Q A M , SPACE",0
tp2:    db "PLAYER 2  (STARTS FAR END)",0
tp3:    db "JOYSTICK 2 OR I J K L + H",0
tp4:    db "ANY DIRECTION: COURT  FIRE: GO",0
twop_court:
        xor a
        ld de,$0030
        ld bc,$2006
        call fill_rect
        ld a,(excourt)
        call surf_name
        ld e,48
        ld a,3
        jp text_c

; ---------------------------------------------------------------------
; result screen for exhibition / two players
result_screen:
        cp $FF
        ret z
        call ix_of
        push ix
        ld hl,s_result
        call page
        pop ix
        ld l,(ix+P_LNAME)
        ld h,(ix+P_LNAME+1)
        ld e,22
        ld a,3
        call text_c
        ld hl,s_wins
        ld e,30
        ld a,1
        call text_c
        ; final set score
        ld hl,tbuf
        ld a,(games)
        add a,'0'
        ld (hl),a
        inc hl
        ld (hl),'-'
        inc hl
        ld a,(games+1)
        add a,'0'
        ld (hl),a
        inc hl
        ld (hl),0
        ld hl,tbuf
        ld e,40
        ld a,2
        call text_c
        call wipe_show
        ld bc,300
        ld hl,0
        jp page_wait
s_result: db "RESULT",0
s_wins:   db "WINS THE MATCH!",0

; ---------------------------------------------------------------------
; WORLD TOUR
tour_surf:  db SURF_GRASS, SURF_CLAY, SURF_HARD, SURF_NIGHT
tour_opp:   db 0,1,3,  2,4,6,  1,3,5,  4,6,7
tour_names: dw tn0,tn1,tn2,tn3
tn0:    db "VZ OPEN",0
tn1:    db "PARIS CLAY CUP",0
tn2:    db "HARD COURT CLASSIC",0
tn3:    db "NIGHT MASTERS",0
roundnames: dw rn0,rn1,rn2
rn0:    db "QUARTER-FINAL",0
rn1:    db "SEMI-FINAL",0
rn2:    db "FINAL",0

tour_start:
        ld a,MODE_TOUR
        ld (mode),a
        ld a,1
        ld (intour),a
        xor a
        ld (tourn),a
        ld hl,tourpts
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
.tn:    xor a
        ld (round),a
.rd:    call bracket_screen
        jp nz,main_menu
        call opponent_card
        ld a,MODE_TOUR
        ld (mode),a
        ld a,(tourn)
        ld hl,tour_surf
        call idx_byte
        call set_surface
        ld ix,pl1
        ld a,8
        ld c,CTL_ANY
        ld b,0
        call setup_player
        call cur_opp
        ld ix,pl0
        ld c,CTL_CPU
        ld a,(tourn)
        ld b,a
        ld a,(curopp)
        call setup_player
        ld a,1
        ld (setsneed),a
        call play_match
        cp $FF
        jp z,main_menu
        or a
        jp z,tour_lost
        ; match won: 1000 x round
        ld a,(round)
        inc a
        ld d,a
        sla d
        sla d
        sla d
        sla d
        ld e,0
        call add_tourpts
        ld a,(round)
        inc a
        ld (round),a
        cp 3
        jr c,.rd
        call trophy_screen
        ld a,(tourn)
        inc a
        ld (tourn),a
        cp 4
        jp z,grand_slam
        ; bonus round between tournaments
        call practice_run
        jp .tn

cur_opp:
        ld a,(tourn)
        ld b,a
        add a,a
        add a,b
        ld b,a
        ld a,(round)
        add a,b
        ld hl,tour_opp
        call idx_byte
        ld (curopp),a
        ret

tour_lost:
        ld hl,s_out
        call page
        call cur_opp
        call char_lname
        ld e,24
        ld a,3
        call text_c
        ld hl,s_out2
        ld e,32
        ld a,1
        call text_c
        ld hl,s_tpts
        ld e,44
        ld a,2
        call text_c
        ld hl,tourpts
        ld b,3
        ld de,$0D32
        call print_bcd
        call wipe_show
        ld hl,mus_lose_0
        ld de,mus_lose_1
        call jingle
        ld bc,280
        ld hl,0
        call page_wait
tour_over:
        call stop_music
        call enter_hiscore
        jp main_menu
s_out:  db "KNOCKED OUT",0
s_out2: db "SENDS YOU HOME. BAD LUCK!",0
s_tpts: db "TOUR POINTS",0

; bracket: tournament name, surface, the three rounds. NZ if X pressed.
bracket_screen:
        ld a,(tourn)
        add a,a
        ld hl,tour_names
        call idx_ptr
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld hl,0
        call page
        pop hl
        ld e,2
        ld a,3
        call text_c
        ld a,(tourn)
        ld hl,tour_surf
        call idx_byte
        call surf_name
        ld e,8
        ld a,2
        call text_c
        ; rounds
        xor a
        ld (tmpa),a
.r:     ld a,(tmpa)
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,a
        sub b
        sub b
        sub b
        add a,17
        ld (tmpy),a
        ld a,(tmpa)
        add a,a
        ld hl,roundnames
        call idx_ptr
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(tmpy)
        ld e,a
        ld d,2
        ld a,1
        call text
        ; opponent
        ld a,(tourn)
        ld b,a
        add a,a
        add a,b
        ld b,a
        ld a,(tmpa)
        add a,b
        ld hl,tour_opp
        call idx_byte
        call char_lname
        ld a,(tmpy)
        add a,6
        ld e,a
        ld d,4
        ld a,(round)
        ld b,a
        ld a,(tmpa)
        cp b
        ld a,3
        jr z,.cur
        ld a,2
.cur:   call text
        ; tick for rounds won
        ld a,(round)
        ld b,a
        ld a,(tmpa)
        cp b
        jr nc,.nt
        ld hl,s_won
        ld a,(tmpy)
        ld e,a
        ld d,22
        ld a,3
        call text
.nt:    ld a,(tmpa)
        inc a
        ld (tmpa),a
        cp 3
        jr c,.r
        ld hl,tourpts
        ld b,3
        ld de,$1A3A
        call print_bcd
        ld hl,s_tpts
        ld de,$0D3A
        ld a,1
        call text
        call wipe_show
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
.w:     call dl_reset
        call do_frame
        ld a,(keysnew)
        bit 3,a
        jr nz,.x
        call check_start
        jr z,.w
        call stop_music
        xor a
        ret
.x:     call stop_music
        or 1
        ret
s_won:  db "WON",0

opponent_card:
        call cur_opp
        ld a,(round)
        add a,a
        ld hl,roundnames
        call idx_ptr
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call page
        ld a,(curopp)
        ld e,18
        call char_panel
        ld hl,s_vs
        ld e,46
        ld a,1
        call text_c
        ld hl,s_ready
        ld e,56
        ld a,2
        call text_c
        call wipe_show
        ld hl,mus_start_0
        ld de,mus_start_1
        call jingle
        ld bc,250
        ld hl,0
        jp page_wait
s_vs:    db "IS YOUR OPPONENT",0
s_ready: db "PRESS FIRE",0

trophy_screen:
        ld hl,0
        call page
        ld a,(tourn)
        add a,a
        ld hl,tour_names
        call idx_ptr
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,2
        ld a,3
        call text_c
        ld hl,s_champ
        ld e,8
        ld a,1
        call text_c
        call draw_trophy
        ld hl,s_bonus5
        ld e,58
        ld a,2
        call text_c
        call wipe_show
        ld de,$5000
        call add_tourpts
        ld hl,mus_trophy_0
        ld de,mus_trophy_1
        call jingle
        ld bc,330
        ld hl,trophy_anim
        call page_wait
        jp stop_music
s_champ:  db "CHAMPION!",0
s_bonus5: db "TROPHY BONUS 5000",0
trophy_anim:    ; you, jumping for joy beside the cup
        ld a,(framecount)
        and 16
        ld c,44
        jr z,.a
        ld c,42
.a:     ld b,32
        ld a,SPR_N+FR_JOY
        call spr_put
        ld a,(framecount)
        and 16
        ld c,42
        jr z,.b
        ld c,44
.b:     ld b,90
        ld a,SPR_N+FR_JOY
        jp spr_put

draw_trophy:    ; 48x48 cup at columns 10-21, rows 12-59
        ld hl,trophy_pic
        ld de,BGBUF+12*32+10
        ld c,12
; unpack_rect: packbits HL -> a C-byte-wide rectangle at DE (32-byte rows)
unpack_rect:
        ld a,c
        ld (ur_w),a
        ld b,c
.next:  ld a,(hl)
        inc hl
        cp 128
        ret z
        jr nc,.rep
        inc a
        ld c,a
.lit:   ld a,(hl)
        inc hl
        call .put
        dec c
        jr nz,.lit
        jr .next
.rep:   neg
        inc a
        ld c,a
        ld a,(hl)
        inc hl
.r1:    call .put
        dec c
        jr nz,.r1
        jr .next
.put:   ld (de),a
        inc de
        dec b
        ret nz
        push af
        push hl
        ld a,(ur_w)
        ld b,a
        ld a,32
        sub b
        ld l,a
        ld h,0
        add hl,de
        ex de,hl
        pop hl
        pop af
        ret

grand_slam:
        ld de,$0000
        ld hl,tourpts           ; +20000
        ld a,(hl)
        add a,2
        daa
        ld (hl),a
        ld hl,s_gs1
        call page
        call draw_trophy
        ld hl,s_gs2
        ld e,58
        ld a,2
        call text_c
        call wipe_show
        ld hl,mus_ending_0
        ld de,mus_ending_1
        call bgm
        ld a,(soundmode)
        cp 1
        jr nz,.m
        ld hl,mus_trophy_0
        ld de,mus_trophy_1
        call jingle
.m:     ld bc,2000
        ld hl,ending_anim
        call page_wait
        jp tour_over
s_gs1:  db "GRAND SLAM!",0
s_gs2:  db "ALL FOUR TITLES ARE YOURS",0
s_gs3:  db "GRAND SLAM BONUS 20000",0
ending_anim:
        call trophy_anim
        ; fireworks: random sparks
        ld a,(framecount)
        and 3
        ret nz
        ld b,100
        call rand_n
        add a,22
        ld b,a
        push bc
        ld b,30
        call rand_n
        pop bc
        add a,16
        ld c,a
        ld b,b
        ld a,(framecount)
        and 4
        ld a,SPR_PUFF1
        jr z,.p
        ld a,SPR_PUFF2
.p:     jp spr_put

; ---------------------------------------------------------------------
; TARGET PRACTICE
practice_mode:
        xor a
        ld (intour),a
        call practice_run
        ; results
        ld hl,s_prres
        call page
        ld hl,s_hits2
        ld e,22
        ld a,1
        call text_c
        ld a,(pr_hits)
        ld de,$0F1C
        call print_dec2
        ld hl,s_pts
        ld de,$0B26
        ld a,1
        call text
        ld hl,pr_score
        ld b,2
        ld de,$0F26
        call print_bcd
        call wipe_show
        ld bc,300
        ld hl,0
        call page_wait
        jp main_menu
s_prres: db "PRACTICE OVER",0
s_hits2: db "TARGETS HIT",0

; practice_run: one 20-ball session on the next tournament's surface
practice_run:
        ld a,MODE_PRACTICE
        ld (mode),a
        ld a,(intour)
        or a
        ld a,(tourn)
        jr nz,.t
        ld a,(excourt)
.t:     and 3
        call set_surface
        ld ix,pl1
        ld a,8
        ld c,CTL_ANY
        ld b,0
        call setup_player
        ld ix,pl0
        ld a,8
        ld c,CTL_NONE
        ld b,0
        call setup_player
        call play_match
        ld a,(intour)
        or a
        ret z
        ; bonus into the tour points
        ld a,(pr_score+1)
        ld e,a
        ld a,(pr_score)
        ld d,a
        ld a,MODE_TOUR
        ld (mode),a
        jp add_tourpts

practice_start:
        xor a
        ld (server),a           ; the machine "serves"
        ld (pr_hits),a
        ld (pr_score),a
        ld (pr_score+1),a
        ld (ball_st),a
        ld a,20
        ld (pr_balls),a
        ld a,50
        ld (feedtim),a
        ld a,1
        ld (pl1+P_HITOK),a
        ld ix,pl1
        ld a,128
        ld c,236
        call place_ix
        ld ix,pl0
        ld a,128
        ld c,14
        call place_ix
        ld a,4
        ld (ball_st),a
        ld b,3
        ld hl,cone_x
.c:     push bc
        push hl
        call cone_new
        pop hl
        pop bc
        inc hl
        djnz .c
        call court_to_bg
        call stamp_machine
        ld a,(s_latch)
        ld (palbase),a
        ld a,1
        ld (noq),a
        call hud_draw
        xor a
        ld (noq),a
        call wipe_show
        ld hl,s_tp
        ld de,s_tp2
        call banner
        ld b,80
        call hold
        call court_restore
        xor a
        ld (ball_st),a
        ld hl,mus_prac_0
        ld de,mus_prac_1
        call bgm
.loop:  call match_step
        ld a,(match_over)
        or a
        jr z,.loop
        call stop_music
        ld a,1
        ret
s_tp:   db "TARGET PRACTICE",0
s_tp2:  db "20 BALLS. HIT CONES!",0

; cone_new: HL -> cone_x[k]; new random position (and cone_y, cone_t)
cone_new:
        push hl
        ld b,150
        call rand_n
        add a,52
        pop hl
        ld (hl),a
        push hl
        ld de,3
        add hl,de
        push hl
        ld b,70
        call rand_n
        add a,38
        pop hl
        ld (hl),a
        add hl,de
        ld (hl),0
        pop hl
        ret

practice_feed:
        ld a,(ball_st)
        or a
        ret nz
        ld a,(pr_balls)
        or a
        ret z
        ld hl,feedtim
        dec (hl)
        ret nz
        ld hl,pr_balls
        dec (hl)
        ld hl,128*64
        ld (ball_x),hl
        ld hl,22*64
        ld (ball_y),hl
        ld hl,14*64
        ld (ball_z),hl
        ld b,130
        call rand_n
        add a,62
        ld b,a
        push bc
        ld b,28
        call rand_n
        pop bc
        add a,196
        ld c,a
        ld a,48
        call make_vel
        ld a,2
        ld (ball_st),a
        xor a
        ld (ball_last),a
        ld (ball_bnc),a
        ld (ball_cross),a
        ld (ball_serve),a
        ld (ball_net),a
        ld (ball_cord),a
        ld (ball_fire),a
        ld a,1
        ld (pl1+P_HITOK),a
        ld a,SFX_FEED
        call play_sfx
        ld ix,pl1
        call ai_plan
        jp hud_draw

; practice_bounce: B = X, C = Y of the first bounce
practice_bounce:
        ld a,(ball_last)
        or a
        ret z                   ; the machine's feed: play on
        ld a,40
        ld (pt_over),a
        ld a,3
        ld (ball_st),a
        ; in the far court?
        ld a,b
        cp XL-2
        jr c,.out
        cp XR+3
        jr nc,.out
        ld a,c
        cp YFAR-2
        jr c,.out
        cp YNET
        jr nc,.out
        ; a cone?
        ld hl,cone_x
        ld e,3
.k:     ld a,(hl)
        sub b
        call abs_a
        cp 13
        jr nc,.nx
        push hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        pop hl
        sub c
        call abs_a
        cp 11
        jr c,.hit
.nx:    inc hl
        dec e
        jr nz,.k
        ld de,$0050
        call pr_add
        ld a,POP_IN
        jp popup_ball
.hit:   inc hl
        inc hl
        inc hl
        inc hl
        inc hl
        inc hl
        ld (hl),40              ; cone_t
        ld hl,pr_hits
        inc (hl)
        ld de,$0500
        call pr_add
        ld a,SFX_CONE
        call play_sfx
        ld a,24
        call crowd_cheer
        ld a,POP_TARGET
        jp popup_ball
.out:   ld a,POP_OUT
        call popup_ball
        jp show_flag

pr_add:         ; BCD DE into pr_score (2 bytes, high first)
        ld hl,pr_score+1
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        ret

practice_next:
        ; cones that were hit move on
        ld hl,cone_t
        ld b,3
.c:     ld a,(hl)
        or a
        jr z,.n
        ld (hl),0
        push bc
        push hl
        ld de,-6
        add hl,de
        call cone_new
        pop hl
        pop bc
.n:     inc hl
        djnz .c
        xor a
        ld (ball_st),a
        ld a,30
        ld (feedtim),a
        call hud_draw
        ld a,(pr_balls)
        or a
        ret nz
        ld a,1
        ld (match_over),a
        ld (match_win),a
        ret

; the ball machine is stamped into the backdrop (it never moves)
stamp_machine:
        ld b,128
        ld c,16
        call proj
        ld a,b
        sub 3
        srl a
        srl a
        ld d,a
        ld a,c
        sub 5
        ld e,a
        call scraddr
        ld a,h
        or $88
        ld h,a
        ex de,hl                ; DE = BG address
        ld hl,shtab+SPR_MACHINE*8
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; HL = shifted (mask,data) pairs
        ld b,5
.r:     push bc
        ld b,3
.c:     ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc de
        djnz .c
        ex de,hl
        ld bc,29
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
        ret

practice_draw:
        ; cones
        ld hl,cone_x
        ld e,3
.k:     push hl
        push de
        ld b,(hl)
        inc hl
        inc hl
        inc hl
        ld c,(hl)
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        or a
        jr z,.nt
        dec (hl)
.nt:    push af
        call proj
        dec b
        dec b
        ld a,c
        sub 2
        ld c,a
        pop af
        ld a,SPR_CONEA
        jr z,.s
        ld a,(framecount)
        and 4
        ld a,SPR_CONEHIT
        jr z,.s
        ld a,SPR_CONE
.s:     call spr_put
        pop de
        pop hl
        inc hl
        dec e
        jr nz,.k
        ret

; ---------------------------------------------------------------------
; Records in BennVenn SRAM bank 3 ($67C0-$67FF): kept until power-off.
; Saving is only enabled if a probe shows the bank switch really works.
REC_LEN equ 4+30+3
load_records:
        xor a
        ld (srok),a
        ld a,1
        out ($37),a             ; the DOS mapping the loader leaves (a no-op re-write)
        ld a,($67FF)
        ld (probe1),a
        ld a,3
        out ($37),a
        ld a,($67FF)
        ld (probe3),a
        ld a,(probe1)
        cpl
        ld ($67FF),a
        ld a,1
        out ($37),a
        ld a,($67FF)
        ld b,a
        ld a,(probe1)
        cp b
        jr nz,.restore          ; bank 1 changed: no banking here, undo
        ld a,3
        out ($37),a
        ld a,($67FF)
        ld b,a
        ld a,(probe1)
        cpl
        cp b
        jr nz,.nosram
        ld a,(probe3)
        ld ($67FF),a
        ld a,1
        ld (srok),a
        ; read the block
        ld hl,SAVEADR
        ld de,recbuf
        ld bc,REC_LEN+1
        ldir
        ld a,1
        out ($37),a
        ld hl,recbuf
        ld de,rec_sig
        ld b,4
.sg:    ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .sg
        call rec_sum
        ld hl,recbuf+REC_LEN
        cp (hl)
        ret nz
        ld hl,recbuf+4
        ld de,hitab
        ld bc,30
        ldir
        ld a,(hl)
        cp 2
        jr c,.g
        cp 7
        jr nc,.g
        ld (gamesper),a
.g:     inc hl
        ld a,(hl)
        cp 3
        jr nc,.s
        ld (soundmode),a
.s:     inc hl
        ld a,(hl)
        and 1
        ld (classic),a
        ret
.restore:
        ld a,(probe1)
        ld ($67FF),a
.nosram:
        ld a,1
        out ($37),a
        ret
rec_sig: db "T2R1"
rec_sum:        ; A = sum of recbuf[0..REC_LEN-1]
        ld hl,recbuf
        ld b,REC_LEN
        xor a
.l:     add a,(hl)
        inc hl
        djnz .l
        ret
save_records:
        ld a,(srok)
        or a
        ret z
        ld hl,rec_sig
        ld de,recbuf
        ld bc,4
        ldir
        ld hl,hitab
        ld bc,30
        ldir
        ld a,(gamesper)
        ld (de),a
        inc de
        ld a,(soundmode)
        ld (de),a
        inc de
        ld a,(classic)
        ld (de),a
        call rec_sum
        ld (recbuf+REC_LEN),a
        ld a,3
        out ($37),a
        ld hl,recbuf
        ld de,SAVEADR
        ld bc,REC_LEN+1
        ldir
        ld a,1
        out ($37),a
        ret

; ---------------------------------------------------------------------
; Backplane texture for the information screens: a sparse lattice of dots
; (grass tufts or a net mesh) drifting in a different direction on each
; screen. Dots live only in VRAM, drawn in vblank only on bytes that are
; plain background both in the BG buffer and on screen, so text, pictures
; and sprites always sit on top. 64 dots: 8 across x 8 down, wrapping.
tex_start:
        ld hl,tex_seq
        inc (hl)
        ld a,(hl)
        and 1
        ld (tex_kind),a
        ld a,(hl)
        and 7
        add a,a
        ld hl,tex_dirs
        call idx_ptr
        ld a,(hl)
        ld (tex_vx),a
        inc hl
        ld a,(hl)
        ld (tex_vy),a
        xor a
        ld (tex_ax),a
        ld (tex_ay),a
        ld b,32
        call rand_n
        ld (tex_ox),a
        ld b,8
        call rand_n
        ld (tex_oy),a
        ld a,1
        ld (tex_first),a
        xor a
        ld (tex_phase),a
        ld (tex_n0),a
        ld (tex_n1),a
        ld hl,tex_vblank
        ld (vbhook),hl
        ret
tex_off:
        xor a
        ld (tex_want),a
        ld hl,vb_none
        ld (vbhook),hl
        ret
; directions, in 1/16 pixel per frame (x, y) - 64 dots: 8 across x 8 down
tex_dirs:
        db 13,4,  -9,6,  5,-8,  -14,-3,  15,0,  -4,9,  10,-7,  -8,-5
; grass: per-row scatter so it doesn't look like a grid
tex_jit: db 0,19,7,26,13,3,22,10

tex_vblank:
        ld a,(cfirst)           ; the commit queue copied something this frame:
        or a                    ; leave the rest of vblank to it
        ret z
        ld a,(q_head)
        ld b,a
        ld a,(q_tail)
        cp b
        ret nz
        ld a,(tex_phase)
        or a
        jr nz,.half2
        ld a,(tex_first)
        or a
        jr nz,.go
        ; move (checked every other frame; speeds are per 2 frames)
        ld a,(tex_vx)
        ld b,a
        ld a,(tex_ax)
        add a,b
        call tex_axis
        ld (tex_ax),a
        ld d,c
        ld a,(tex_vy)
        ld b,a
        ld a,(tex_ay)
        add a,b
        call tex_axis
        ld (tex_ay),a
        ld a,(tex_ox)
        add a,d
        ld (tex_ox),a
        ld a,(tex_oy)
        add a,c
        ld (tex_oy),a
        ld a,d
        or c
        ret z                   ; not a whole pixel yet
.go:    xor a
        ld (tex_first),a
        inc a
        ld (tex_phase),a
        ; top half: rows 0-3
        ld hl,tex_list
        ld a,(tex_n0)
        call tex_erase
        ld b,0
        ld de,tex_list
        call tex_draw
        ld (tex_n0),a
        ret
.half2: xor a
        ld (tex_phase),a
        ld hl,tex_list+96
        ld a,(tex_n1)
        call tex_erase
        ld b,4
        ld de,tex_list+96
        call tex_draw
        ld (tex_n1),a
        ret
; A = accumulator -> A wrapped, C = whole-pixel step (-1, 0, +1)
tex_axis:
        ld c,0
        bit 7,a
        jr nz,.neg
        cp 16
        ret c
        sub 16
        inc c
        ret
.neg:   cp -15
        ret nc
        add a,16
        dec c
        ret

; erase: HL = list, A = count. Put back the bytes under our dots (if still ours).
tex_erase:
        or a
        ret z
        ld b,a
.e:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(de)
        cp (hl)
        inc hl
        jr nz,.s
        ld a,d
        or $88                  ; VRAM $70xx -> BG buffer $F8xx
        ld d,a
        ld a,(de)
        res 7,d
        res 3,d
        ld (de),a
.s:     djnz .e
        ret

; draw: B = first row (0 or 4), DE = list -> A = dots drawn.
; In each row 8 dots, 4 bytes apart, all with the same pattern.
tex_draw:
        exx
        ld c,0                  ; count (alternate set: DE' = list, C' = count)
        exx
        push de
        exx
        pop de
        exx
        ld a,b
        add a,4
        ld (tex_rowend),a
.row:   push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,(tex_oy)
        add a,c
        and 63
        add a,a
        ld l,a
        ld h,0
        ld de,rowaddr
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = VRAM row start
        ld a,(tex_kind)
        or a
        jr nz,.net
        ld a,b
        ld hl,tex_jit
        call idx_byte
        jr .xs
.net:   ld a,b
        and 1
        rrca
        rrca
        rrca
        rrca                    ; (row & 1) * 16
.xs:    ld hl,tex_ox
        add a,(hl)              ; x of the first dot
        ld b,a
        and 3
        ld c,a
        ld a,(tex_kind)
        add a,a
        add a,a
        add a,c
        ld hl,tex_dotb
        call idx_byte
        ld c,a                  ; C = dot pattern
        ld a,b
        rrca
        rrca
        and 3                   ; byte column of the first dot (0..3)
        or e
        ld l,a
        ld h,d
        ld a,e
        ld e,a                  ; E = row start (low byte)
        ld b,8
.d:     ld a,(hl)
        or a
        jr nz,.n                ; something on screen here
        set 7,h
        set 3,h
        or (hl)                 ; plain background in the page...
        dec l
        or (hl)                 ; ...and either side (keeps clear of text)
        inc l
        inc l
        or (hl)
        dec l
        ld (tex_hl),hl
        ld de,-64               ; ...and two rows above and below
        add hl,de
        or (hl)
        ld de,32
        add hl,de
        or (hl)
        add hl,de
        add hl,de
        or (hl)
        add hl,de
        or (hl)
        ld hl,(tex_hl)
        res 7,h
        res 3,h
        or a
        jr nz,.n
        ld (hl),c
        ld a,l                  ; note it for the erase
        exx
        ld (de),a
        inc de
        exx
        ld a,h
        exx
        ld (de),a
        inc de
        exx
        ld a,c
        exx
        ld (de),a
        inc de
        inc c
        exx
.n:     ld a,l
        add a,4
        xor l
        and $1F
        xor l                   ; L = row part of L | (col + 4) & 31
        ld l,a
        djnz .d
        pop bc
        inc b
        ld a,(tex_rowend)
        cp b
        jp nz,.row
        exx
        ld a,c
        exx
        ret
; grass: a two-pixel blue tuft; net: one yellow knot
tex_dotb:
        db $A0,$28,$0A,$02
        db $40,$10,$04,$01
