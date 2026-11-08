; =====================================================================
;  FRONT END (block BLK_FRONT, runs at 0000h in the lower window):
;  monitor choice, title and attract cycle, menus, the Summer Tour,
;  exhibition, two players, target practice, Hall of Fame, trophies.
;  Upper routines that change the lower window are called with UCALL.
; =====================================================================
        ORG $0000
front_base:

; information page colours (paper blue)
C_TEXT  equ BLUE<<4|WHITE
C_HI    equ BLUE<<4|YELLOW
C_DIM   equ BLUE<<4|BCYAN
C_HEAD  equ BLACK<<4|YELLOW
C_FOOT  equ BLACK<<4|BCYAN
C_PLAIN equ BLACK<<4|WHITE

PIC_TITLE  equ 5
PIC_INFO   equ 6
PIC_TROPHY equ 7

front_start:
        ld sp,STACK
        UCALL load_game
        call monitor_screen
        UCALL cache_pics
        jp attract

; ---------------------------------------------------------------------
; helpers
; txtc: A = colour (mono: white on black, or black on white for highlights)
txtc:   push bc
        ld b,a
        ld a,(monomode)
        or a
        ld a,b
        jr z,.c
        cp C_HI
        ld a,$0F
        jr nz,.c
        ld a,$F0
.c:     ld (txt_col),a
        pop bc
        ret
; text: HL, D col, E row, A colour, font (txt_font)
text:   call txtc
        jp print
text_c: call txtc
        jp print_c
; sport / classic / led fonts
f_sport:
        push hl
        ld hl,G_FONT1
        jr f_set
f_classic:
        push hl
        ld hl,G_FONT3
        jr f_set
f_led:  push hl
        ld hl,G_FONT2
f_set:  ld (txt_font),hl
        pop hl
        ret
; text list: HL -> (db colour, row : dw string)..., $FF
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

; page: the information backdrop with heading HL (CLASSIC font, row 0..1 band)
page:   push hl
        ld a,PIC_INFO
        UCALL show_pic
        call f_classic
        pop hl
        ld a,h
        or l
        jr z,.n
        ld e,0
        ld a,C_HEAD
        call text_c
.n:     jp f_sport

; blank black screen
blank_page:
        ld hl,G_FONT1
        ld (fc_glyph),hl
        ld a,C_PLAIN
        call txtc
        ld de,0
        ld bc,$4010
        jp fill_cells

; wait up to BC frames (start aborts -> NZ); HL = per-frame hook or 0
page_wait:
        ld (infohook),hl
.l:     push bc
        ld hl,(infohook)
        ld a,h
        or l
        call nz,.call
        call input_used
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

; one frame, nothing else
frame1: call input_used
        jp do_frame

; ---------------------------------------------------------------------
; the monitor: colour or monochrome
monitor_screen:
        call blank_page
        call f_classic
        ld hl,s_mtitle
        ld e,3
        ld a,BLACK<<4|YELLOW
        call text_c
        call f_sport
        ld hl,s_mq
        ld e,7
        ld a,C_PLAIN
        call text_c
        ld hl,s_mc
        ld e,9
        ld a,BLACK<<4|BCYAN
        call text_c
        ld hl,s_mm
        ld e,10
        ld a,BLACK<<4|BCYAN
        call text_c
        ld hl,s_credit
        ld e,14
        ld a,BLACK<<4|GREY
        call text_c
.w:     call frame1
        ld a,(keysnew)
        bit 5,a                 ; C
        jr nz,.col
        ld a,(inpnew)
        bit 1,a                 ; M (left)
        jr nz,.mono
        call check_start
        jr z,.w
        ret                     ; keep the saved choice
.col:   xor a
        jr .s
.mono:  ld a,1
.s:     ld (monomode),a
        ld a,SFX_SELECT
        call play_sfx
        UCALL save_game
        ret
s_mtitle: db "MICROBEE AUSTRALIAN OPEN TENNIS",0
s_mq:     db "WHAT KIND OF MONITOR?",0
s_mc:     db "C  -  COLOUR",0
s_mm:     db "M  -  MONOCHROME (AMBER/GREEN)",0
s_credit: db "VIBED BY BPM 2026",0

; ---------------------------------------------------------------------
; ATTRACT: title, how to play, meet the tour, a demo match, Hall of Fame
attract:
        ld sp,STACK
        xor a
        ld (mode),a
        ld (twoplayer),a
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
.go:    ld sp,STACK
        call stop_music
        jp main_menu

; ---------------------------------------------------------------------
; TITLE: the logo, a rally on the little court, rotating messages
title_screen:
        ld a,PIC_TITLE
        UCALL show_pic
        call f_sport
        ld hl,mus_title_0
        ld de,mus_title_1
        call bgm
        call rally_init
        xor a
        ld (tmsg),a
        ld b,6
.m:     push bc
        call title_message
        ld bc,110
        ld hl,rally_step
        call page_wait
        pop bc
        jr nz,.x
        djnz .m
        call stop_music
        xor a
        ret
.x:     call stop_music
        or 1
        ret
title_message:
        ld a,(tmsg)
        inc a
        cp 4
        jr c,.k
        xor a
.k:     ld (tmsg),a
        add a,a
        ld l,a
        ld h,0
        ld de,title_msgs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld hl,G_FONT1
        ld (fc_glyph),hl
        ld a,BLACK<<4|YELLOW
        call txtc
        ld de,$000F
        ld bc,$4001
        call fill_cells
        pop hl
        ld e,15
        ld a,BLACK<<4|YELLOW
        jp text_c
title_msgs: dw tm0,tm1,tm2,tm3
tm0:    db "PRESS FIRE OR SPACE TO PLAY",0
tm1:    db "THE MICROBEE EDITION OF TENNIS II",0
tm2:    db "VIBED BY BPM 2026",0
tm3:    db "KOOYONG  PERTH  SYDNEY  MELBOURNE",0

; the title rally: far player at y 168, near player at y 234; the ball
; flies between them in 36 frames with a little arc
RA_T    equ 36
RA_OFFN equ 9           ; racket reach (in 2-pixel units): near player
RA_OFFF equ 6           ;   far player
RA_YF   equ 150         ; ball at the far racket
RA_YN   equ 208         ;   at the near racket
rally_init:
        xor a
        ld (ra_t),a
        ld (ra_dir),a
        ld a,128
        ld (ra_x0),a
        ld (ra_pf),a
        ld (ra_pn),a
        ld a,160
        ld (ra_x1),a
        ret
rally_step:
        ld hl,ra_t
        inc (hl)
        ld a,(hl)
        cp RA_T
        jr c,.fly
        ; hit: turn round, new target
        ld (hl),0
        ld a,(ra_dir)
        xor 1
        ld (ra_dir),a
        ld a,(ra_x1)
        ld (ra_x0),a
        ld b,120
        call rand_n
        add a,68
        ld (ra_x1),a
        ld a,SFX_HIT
        call play_sfx
        ld a,12
        ld (ra_sw),a
.fly:   ; the receiver runs so that its racket meets the ball at x1
        ld a,(ra_dir)
        or a
        ld hl,ra_pf
        ld c,RA_OFFF
        jr z,.up
        ld hl,ra_pn
        ld c,RA_OFFN
.up:    ld a,(ra_x1)
        sub c                   ; where the body must stand
        sub (hl)
        jr z,.ok
        jr c,.l
        cp 4
        jr c,.r1
        ld a,4
.r1:    add a,(hl)
        ld (hl),a
        jr .ok
.l:     cp -4
        jr nc,.l1
        ld a,-4
.l1:    add a,(hl)
        ld (hl),a
.ok:    ld a,(ra_sw)
        or a
        jr z,.ns
        dec a
        ld (ra_sw),a
.ns:    ; ball: x = x0 + (x1-x0)*t/T, y from one end to the other, arc
        ld a,(ra_x1)
        ld hl,ra_x0
        sub (hl)
        ld e,a
        ld a,(ra_t)
        call ra_frac            ; A = (signed E) * t / 36
        ld hl,ra_x0
        add a,(hl)
        ld (ra_bx),a
        ld a,(ra_t)
        ld b,a
        ld a,(ra_dir)
        or a
        ld a,b
        jr nz,.d
        ld a,RA_T
        sub b                   ; going up: from the near end
.d:     ; y from racket to racket
        ld e,RA_YN-RA_YF
        call ra_frac
        add a,RA_YF
        ld c,a
        ; arc: 4 t (T - t) / 64
        ld a,(ra_t)
        ld b,a
        ld a,RA_T
        sub b
        ld e,a
        ld h,b
        call umul8
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,c
        sub l
        ld (ra_by),a
        ; draw: far player (small), near player, ball
        ld a,(ra_pf)
        ld l,a
        ld h,0
        add hl,hl
        ld (spr_x),hl
        ld hl,168
        ld (spr_y),hl
        ld a,(monomode)
        or a
        ld a,YELLOW
        jr z,.c1
        ld a,WHITE
.c1:    ld (spr_ink),a
        xor a
        call ra_pose
        add a,NFR
        ld c,SF_HF_LOU
        call draw_bh
        ld a,(ra_pn)
        ld l,a
        ld h,0
        add hl,hl
        ld (spr_x),hl
        ld hl,236
        ld (spr_y),hl
        call ink_white
        ld a,1
        call ra_pose
        call draw_you
        ld a,(ra_bx)
        ld l,a
        ld h,0
        add hl,hl
        ld (spr_x),hl
        ld a,(ra_by)
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(monomode)
        or a
        ld a,YELLOW
        jr z,.c3
        ld a,WHITE
.c3:    ld (spr_ink),a
        ld a,SF_BALL1
        jp spr_draw
; A = 0 far player, 1 near player -> A = near-view body frame: the hitter
; swings through (contact, follow-through, finish), the receiver winds up
ra_pose:
        ld b,a
        ld a,(ra_dir)           ; 0: ball going up (the near player hit it)
        xor 1                   ; = the hitter's side
        cp b
        jr nz,.recv
        ld a,(ra_sw)
        or a
        jr z,.idle
        cp 9
        jr c,.f2
        ld a,FR_B_FH+1
        ret
.f2:    cp 5
        ld a,FR_B_FH+3
        ret c
        ld a,FR_B_FH+2
        ret
.recv:  ld a,(ra_t)
        cp RA_T-7
        jr c,.idle
        ld a,FR_B_FH
        ret
.idle:  ld a,FR_B_IDLE
        ret
; A = t, E = signed span -> A = E * t / 36
ra_frac:
        ld h,a
        ld a,e
        or a
        jp p,.p
        neg
        ld e,a
        call umul8
        call .div
        neg
        ret
.p:     call umul8
.div:   ld c,RA_T
        call udiv16
        ld a,l
        ret

; ---------------------------------------------------------------------
how_to_play:
        ld hl,s_how
        call page
        ld hl,how_lines
        call text_list
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        ld bc,400
        ld hl,0
        call page_wait
        push af
        call stop_music
        pop af
        ret
s_how:  db "HOW TO PLAY",0
how_lines:
        db C_HI,3   : dw hw0
        db C_TEXT,4 : dw hw0b
        db C_HI,6   : dw hw1
        db C_TEXT,7 : dw hw2
        db C_TEXT,8 : dw hw3
        db C_HI,10  : dw hw4
        db C_TEXT,11 : dw hw5
        db C_TEXT,12 : dw hw6
        db C_DIM,13 : dw hw7
        db C_FOOT,15 : dw hw8
        db $FF
hw0:    db "MOVE: Q A M ,  OR THE ARROW KEYS OR JOYSTICK",0
hw0b:   db "SPACE/SHIFT/FIRE: HIT HARDER  P: PAUSE  S: SOUND",0
hw1:    db "THE SWING IS AUTOMATIC!",0
hw2:    db "WHERE THE BALL MEETS YOU SETS THE ANGLE",0
hw3:    db "HOLD LEFT OR RIGHT AS YOU HIT TO STEER IT",0
hw4:    db "FIRE: A POWER DRIVE  (A SMASH IF IT'S HIGH)",0
hw5:    db "PULL BACK: A LOB    PUSH UP: A DROP SHOT",0
hw6:    db "SERVE: FIRE TO TOSS, FIRE AGAIN TO HIT",0
hw7:    db "THREE WINNERS IN A ROW AND YOU'RE ON FIRE!",0
hw8:    db "THE SUMMER TOUR SAVES ITSELF TO THE DISK",0

; ---------------------------------------------------------------------
; MEET THE TOUR: two players a page
meet_tour:
        xor a
        ld (mt_i),a
.pg:    ld hl,s_meet
        call page
        ld hl,mus_info_0
        ld de,mus_info_1
        ld a,(mt_i)
        or a
        call z,bgm
        ld b,2
        ld e,3
.c:     push bc
        push de
        ld a,(mt_i)
        cp 9
        jr nc,.cx
        call char_panel
.cx:    ld hl,mt_i
        inc (hl)
        pop de
        ld a,e
        add a,6
        ld e,a
        pop bc
        djnz .c
        ld bc,280
        ld hl,0
        call page_wait
        jr nz,.x
        ld a,(mt_i)
        cp 9
        jp c,.pg
        call stop_music
        xor a
        ret
.x:     call stop_music
        or 1
        ret
s_meet: db "MEET THE TOUR",0

; char_panel: A = character, E = top row: portrait (10x5 cells) + name + lines
char_panel:
        ld (cp_c),a
        ld a,e
        ld (cp_r),a
        ld a,(cp_c)
        ld d,6
        ld a,(cp_r)
        ld e,a
        ld a,(cp_c)
        UCALL show_portrait
        ld hl,G_FONT1           ; clear the old lines
        ld (fc_glyph),hl
        ld a,C_TEXT
        call txtc
        ld a,(cp_r)
        ld e,a
        ld d,19
        ld bc,$2B04
        call fill_cells
        ld a,(cp_c)
        call char_lname
        ld a,(cp_r)
        inc a
        ld e,a
        ld d,19
        call f_classic
        ld a,C_HI
        call text
        call f_sport
        ld a,(cp_c)
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,chardesc
        add hl,de
        push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(cp_r)
        add a,2
        ld e,a
        ld d,19
        ld a,C_TEXT
        call text
        pop hl
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(cp_r)
        add a,3
        ld e,a
        ld d,19
        ld a,C_DIM
        jp text

; A = character -> HL = long name
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
        sbc hl,de               ; *14
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
cd2a: db "CHARGES THE NET LIKE A RAID",0
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
cd7b: db "'64 COLUMNS OF PURE CLASS'",0
cd8a: db "THAT'S YOU!",0
cd8b: db "'LET'S PLAY!'",0

; ---------------------------------------------------------------------
; DEMO: computer v computer on a random court
run_demo:
        xor a
        ld (mode),a
        ld b,4
        call rand_n
        ld (dm_v),a
        ld b,8
        call rand_n
        ld (dm_a),a
        ld b,8
        call rand_n
        ld hl,dm_a
        cp (hl)
        jr nz,.d
        inc a
        and 7
.d:     ld (dm_b),a
        ld hl,1500
        ld (demotim),hl
        ld a,(dm_v)
        call set_surface
        ld ix,pl0
        ld a,(dm_a)
        ld c,CTL_CPU
        ld b,1
        call setup_player
        ld ix,pl1
        ld a,(dm_b)
        ld c,CTL_CPU
        ld b,1
        call setup_player
        ld a,4
        ld (gamesper),a
        ld a,1
        ld (setsneed),a
        UCALL play_match
        cp $FF
        ret z                   ; (NZ: start pressed)
        xor a
        ret

; ---------------------------------------------------------------------
; HALL OF FAME
hiscore_screen:
        ld hl,s_hof
        call page
        call draw_hitab
        ld hl,s_play
        ld e,15
        ld a,C_FOOT
        call text_c
        ld bc,300
        ld hl,0
        jp page_wait
s_hof:  db "HALL OF FAME",0
s_play: db "PRESS FIRE TO PLAY",0

draw_hitab:
        xor a
        ld (tmpa),a
        ld hl,hitab
.r:     push hl
        ld a,(tmpa)
        add a,a
        add a,4
        ld e,a
        ld (tmpy),a
        ; rank
        ld a,(tmpa)
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,ranks
        add hl,de
        ld a,(tmpy)
        ld e,a
        ld d,17
        call f_classic
        ld a,C_DIM
        call text
        ; initials
        pop hl
        push hl
        inc hl
        inc hl
        inc hl
        ld de,nameb
        ld bc,3
        ldir
        xor a
        ld (de),a
        ld hl,nameb
        ld a,(tmpy)
        ld e,a
        ld d,25
        ld a,C_HI
        call text
        call f_led
        pop hl
        push hl
        ld b,3
        ld a,(tmpy)
        ld e,a
        ld d,34
        ld a,C_TEXT
        call txtc
        call print_bcd
        call f_sport
        pop hl
        ld de,6
        add hl,de
        ld a,(tmpa)
        inc a
        ld (tmpa),a
        cp 5
        jr c,.r
        ret
ranks:  db "1ST",0,"2ND",0,"3RD",0,"4TH",0,"5TH",0

; ---------------------------------------------------------------------
; MAIN MENU
MENU_N  equ 8
main_menu:
        ld sp,STACK
        xor a
        ld (mode),a
        ld (intour),a
        ld (twoplayer),a
.redraw:
        ld hl,s_title2
        call page
        ld hl,s_menuhelp
        ld e,15
        ld a,C_FOOT
        call text_c
        call menu_items
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        ld hl,0
        ld (attr_t),hl
.loop:  ; the ball cursor bounces beside the choice
        ld a,(menusel)
        add a,4
        add a,a
        add a,a
        add a,a
        add a,a
        add a,12
        ld l,a
        ld a,(framecount)
        and 8
        jr z,.b
        ld a,l
        sub 3
        ld l,a
.b:     ld h,0
        ld (spr_y),hl
        ld hl,104
        ld (spr_x),hl
        ld a,(monomode)
        or a
        ld a,YELLOW
        jr z,.bc
        ld a,WHITE
.bc:    ld (spr_ink),a
        ld a,SF_BALL2
        call spr_draw
        call frame1
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,1200
        or a
        sbc hl,de
        jp z,.idle
        ld a,(keysnew)
        bit 5,a
        call nz,unlock_classic
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
        call menu_items
.nu:    bit 3,c
        jr z,.nd
        ld a,(menusel)
        cp MENU_N-1
        jr nc,.nd
        inc a
        ld (menusel),a
        ld a,SFX_BLIP
        call play_sfx
        call menu_items
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
        cp 5
        jr c,.go
        call menu_change
        call menu_items
        jp .loop
.go:    ld a,SFX_SELECT
        call play_sfx
        call stop_music
        ld a,(menusel)
        or a
        jp z,tour_new
        dec a
        jp z,tour_continue
        dec a
        jp z,exhib_setup
        dec a
        jp z,twop_setup
        jp practice_mode
.idle:  call stop_music
        jp attract
s_title2:   db "MICROBEE AUSTRALIAN OPEN",0
s_menuhelp: db "UP/DOWN + FIRE    C: THE CLASSIC 1984 COURT",0

menu_change:    ; left/right/fire on an option line
        ld a,(menusel)
        cp 5
        jr nz,.snd
        ld a,(gamesper_d)
        add a,2
        cp 8
        jr c,.g
        ld a,2
.g:     ld (gamesper_d),a
        jr .tick
.snd:   cp 6
        jr nz,.mon
        call toggle_sound
        jr .tick
.mon:   cp 7
        ret nz
        ld a,(monomode)
        xor 1
        ld (monomode),a
        UCALL cache_pics
        ld hl,s_title2
        call page
        ld hl,s_menuhelp
        ld e,15
        ld a,C_FOOT
        call text_c
.tick:  UCALL save_game
        ld a,SFX_TICK
        jp play_sfx

menu_items:
        ld hl,menu_tab
        ld b,0
.l:     push bc
        push hl
        ld a,(menusel)
        cp b
        ld a,C_TEXT
        jr nz,.c
        ld a,C_HI
.c:     push af
        ld a,b
        add a,4
        ld e,a
        ld d,15
        pop af
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
        ; option values
        ld a,(gamesper_d)
        add a,'0'
        ld (tbuf2),a
        xor a
        ld (tbuf2+1),a
        ld hl,tbuf2
        ld de,$1E09
        ld a,C_HI
        call text
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
        ld de,$1E0A
        ld a,C_HI
        call text
        ld a,(monomode)
        or a
        ld hl,s_colour
        jr z,.m
        ld hl,s_mono
.m:     ld de,$1E0B
        ld a,C_HI
        call text
        ; is there a tour to continue?
        ld a,(tour_saved)
        or a
        ret nz
        ld hl,s_notour
        ld de,$1E05
        ld a,C_DIM
        jp text
menu_tab: dw mi0,mi1,mi2,mi3,mi4,mi5,mi6,mi7
mi0:    db "NEW SUMMER TOUR",0
mi1:    db "CONTINUE TOUR",0
mi2:    db "EXHIBITION",0
mi3:    db "TWO PLAYERS",0
mi4:    db "TARGET PRACTICE",0
mi5:    db "GAMES PER SET:",0
mi6:    db "SOUND:",0
mi7:    db "MONITOR:",0
sndnames: dw sm0,sm1,sm2
sm0:    db "OFF        ",0
sm1:    db "EFFECTS    ",0
sm2:    db "MUSIC + FX ",0
s_colour: db "COLOUR     ",0
s_mono:   db "MONOCHROME ",0
s_notour: db "(NONE SAVED)",0

unlock_classic:
        ld a,(classic)
        or a
        ret nz
        ld a,1
        ld (classic),a
        UCALL save_game
        ld hl,s_unlock
        ld e,13
        ld a,C_HI
        call text_c
        ld a,SFX_CONE
        jp play_sfx
s_unlock: db "CLASSIC 1984 COURT UNLOCKED!",0

; ---------------------------------------------------------------------
; EXHIBITION: any rival, any court
exhib_setup:
        ld a,MODE_EXHIB
        ld (mode),a
.redraw:
        ld hl,s_exhib
        call page
        ld hl,s_exhelp
        ld e,15
        ld a,C_FOOT
        call text_c
        call exhib_draw
.w:     call frame1
        ld a,(inpnew)
        ld c,a
        bit 0,c
        jr z,.nr
        ld a,(exopp)
        inc a
        cp 8
        jr c,.r
        xor a
.r:     ld (exopp),a
        call .chg
        jr .nc
.nr:    bit 1,c
        jr z,.nl
        ld a,(exopp)
        dec a
        jp p,.l
        ld a,7
.l:     ld (exopp),a
        call .chg
        jr .nc
.nl:    ld a,c
        and $0C
        jr z,.nc
        call next_court
        call exhib_draw
.nc:    ld a,(keysnew)
        bit 6,a
        jp nz,main_menu
        call check_start
        jr z,.w
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
        ld b,0
        call setup_player
        call match_setsneed
        UCALL play_match
        cp $FF
        jp z,main_menu
        call result_screen
        jp main_menu
.chg:   ld a,SFX_BLIP
        call play_sfx
        jp exhib_draw
s_exhib:  db "EXHIBITION",0
s_exhelp: db "LEFT/RIGHT: RIVAL   UP/DOWN: COURT   FIRE: PLAY",0

next_court:
        ld a,(classic)
        add a,4                 ; 4 courts, 5 with the classic one
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
        ld a,(exopp)
        ld e,3
        call char_panel
        ld hl,s_courtl
        ld de,$060A
        ld a,C_DIM
        call text
        ld hl,G_FONT1
        ld (fc_glyph),hl
        ld a,C_TEXT
        call txtc
        ld de,$100A
        ld bc,$2001
        call fill_cells
        ld a,(excourt)
        call surf_name
        ld de,$100A
        ld a,C_HI
        jp text
s_courtl: db "COURT:",0
; A = venue -> HL = its name
surf_name:
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        add hl,hl
        ld de,surftab+4
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; sets to win and games per set for the match about to start
match_setsneed:
        ld a,(gamesper_d)
        ld (gamesper),a
        ld a,1
        ld (setsneed),a
        ret

; ---------------------------------------------------------------------
; TWO PLAYERS
twop_setup:
        ld a,MODE_2P
        ld (mode),a
        ld hl,s_2p
        call page
        ld hl,twop_lines
        call text_list
        call .court
.w:     call frame1
        ld a,(inpnew)
        and $0F
        jr z,.nc
        call next_court
        call .court
.nc:    ld a,(keysnew)
        bit 6,a
        jp nz,main_menu
        call check_start
        jr z,.w
        ld a,1
        ld (twoplayer),a
        ld a,(excourt)
        call set_surface
        ld ix,pl1
        ld a,8
        ld c,CTL_PAD1
        ld b,0
        call setup_player
        ld ix,pl0
        ld a,8
        ld c,CTL_PAD2
        ld b,0
        call setup_player
        ld hl,s_lp1
        ld (pl1+P_LNAME),hl
        ld hl,s_p1
        ld (pl1+P_NAME),hl
        ld hl,s_lp2
        ld (pl0+P_LNAME),hl
        ld hl,s_p2
        ld (pl0+P_NAME),hl
        ld a,4                  ; player 2's kit: Mr Microbee's
        ld (pl0+P_CHAR),a
        call match_setsneed
        UCALL play_match
        push af
        xor a
        ld (twoplayer),a
        pop af
        cp $FF
        jp z,main_menu
        call result_screen
        jp main_menu
.court: ld hl,G_FONT1
        ld (fc_glyph),hl
        ld a,C_TEXT
        call txtc
        ld de,$000C
        ld bc,$4001
        call fill_cells
        ld a,(excourt)
        call surf_name
        ld e,12
        ld a,C_HI
        jp text_c
s_2p:   db "TWO PLAYERS",0
twop_lines:
        db C_HI,3   : dw tp0
        db C_TEXT,4 : dw tp1
        db C_TEXT,5 : dw tp1b
        db C_HI,7   : dw tp2
        db C_TEXT,8 : dw tp3
        db C_DIM,11 : dw tp4
        db C_FOOT,15 : dw tp5
        db $FF
tp0:    db "PLAYER 1  (STARTS AT THE NEAR END)",0
tp1:    db "Q A M ,  OR THE ARROW KEYS",0
tp1b:   db "SPACE TO HIT HARDER",0
tp2:    db "PLAYER 2  (STARTS AT THE FAR END)",0
tp3:    db "I K J L + H, OR THE JOYSTICK",0
tp4:    db "COURT:",0
tp5:    db "ANY DIRECTION: COURT    FIRE: PLAY",0

; RESULT of an exhibition / two-player match
result_screen:
        ld (tmpa),a
        ld hl,s_result
        call page
        ld a,(tmpa)
        ld ix,pl0
        or a
        jr z,.w
        ld ix,pl1
.w:     ld l,(ix+P_LNAME)
        ld h,(ix+P_LNAME+1)
        ld e,5
        call f_classic
        ld a,C_HI
        call text_c
        call f_sport
        ld hl,s_wins
        ld e,7
        ld a,C_TEXT
        call text_c
        ld hl,mus_match_0
        ld de,mus_match_1
        call jingle
        ld bc,300
        ld hl,0
        call page_wait
        jp stop_music
s_result: db "MATCH RESULT",0
s_wins:   db "WINS THE MATCH!",0

; ---------------------------------------------------------------------
; THE SUMMER TOUR: four tournaments, three rounds each
tour_surf:  db V_KOOYONG, V_PERTH, V_SYDNEY, V_MELBOURNE
tour_opp:   db 0,1,3,  2,4,6,  1,3,5,  4,6,7
tour_names: dw tn0,tn1,tn2,tn3
tn0:    db "THE KOOYONG CLASSIC",0
tn1:    db "THE PERTH CLAY CUP",0
tn2:    db "THE SYDNEY HARBOUR OPEN",0
tn3:    db "THE AUSTRALIAN OPEN",0
roundnames: dw rn0,rn1,rn2
rn0:    db "QUARTER-FINAL",0
rn1:    db "SEMI-FINAL",0
rn2:    db "FINAL",0

tour_new:
        xor a
        ld (tourn),a
        ld (round),a
        ld hl,tourpts
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        jr tour_go
tour_continue:
        ld a,(tour_saved)
        or a
        jp z,main_menu
        ld a,(tour_t)
        ld (tourn),a
        ld a,(tour_r)
        ld (round),a
        ld hl,tour_p
        ld de,tourpts
        ld bc,3
        ldir
tour_go:
        ld a,MODE_TOUR
        ld (mode),a
        ld a,1
        ld (intour),a
.rd:    call tour_save
        call bracket_screen
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
        call match_setsneed
        UCALL play_match
        cp $FF
        jp z,main_menu          ; quit: the tour stays saved at this round
        or a
        jp z,tour_lost
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
        xor a
        ld (round),a
        ld a,(tourn)
        cp 4
        jp z,grand_slam
        call tour_save
        call practice_run
        jp .rd

; save the tour where it is now
tour_save:
        ld a,1
        ld (tour_saved),a
        ld a,(tourn)
        ld (tour_t),a
        ld a,(round)
        ld (tour_r),a
        ld hl,tourpts
        ld de,tour_p
        ld bc,3
        ldir
        UCALL save_game
        ret
tour_clear:
        xor a
        ld (tour_saved),a
        UCALL save_game
        ret

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
        call tour_clear
        ld hl,s_out
        call page
        call cur_opp
        call char_lname
        ld e,5
        call f_classic
        ld a,C_HI
        call text_c
        call f_sport
        ld hl,s_out2
        ld e,7
        ld a,C_TEXT
        call text_c
        ld hl,s_tpts
        ld e,10
        ld a,C_DIM
        call text_c
        call f_led
        ld a,C_HI
        call txtc
        ld hl,tourpts
        ld b,3
        ld de,$1D0B
        call print_bcd
        call f_sport
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

bracket_screen:
        ld a,(tourn)
        add a,a
        ld hl,tour_names
        call idx_ptr
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call page
        ld a,(tourn)
        ld hl,tour_surf
        call idx_byte
        call surf_name
        ld e,3
        ld a,C_DIM
        call text_c
        xor a
        ld (tmpa),a
.r:     ld a,(tmpa)
        ld b,a
        add a,a
        add a,b
        add a,5
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
        ld d,12
        ld a,C_DIM
        call text
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
        inc a
        ld e,a
        ld d,14
        ld a,(round)
        ld b,a
        ld a,(tmpa)
        cp b
        ld a,C_HI
        jr z,.cur
        ld a,C_TEXT
.cur:   call f_classic
        call text
        call f_sport
        ld a,(round)
        ld b,a
        ld a,(tmpa)
        cp b
        jr nc,.nt
        ld hl,s_won
        ld a,(tmpy)
        inc a
        ld e,a
        ld d,40
        ld a,C_HI
        call text
.nt:    ld a,(tmpa)
        inc a
        ld (tmpa),a
        cp 3
        jr c,.r
        ld hl,s_tpts
        ld de,$0E0E
        ld a,C_DIM
        call text
        call f_led
        ld a,C_HI
        call txtc
        ld hl,tourpts
        ld b,3
        ld de,$1C0E
        call print_bcd
        call f_sport
        ld hl,s_brhelp
        ld e,15
        ld a,C_FOOT
        call text_c
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
.w:     call frame1
        ld a,(keysnew)
        bit 6,a
        jr nz,.x
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
s_won:    db "WON",0
s_brhelp: db "FIRE: PLAY ON     ESC: SAVE AND QUIT",0

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
        ld e,4
        call char_panel
        ld hl,s_vs
        ld e,11
        ld a,C_TEXT
        call text_c
        ld hl,s_ready
        ld e,15
        ld a,C_FOOT
        call text_c
        ld hl,mus_start_0
        ld de,mus_start_1
        call jingle
        ld bc,250
        ld hl,0
        jp page_wait
s_vs:    db "IS YOUR OPPONENT",0
s_ready: db "PRESS FIRE",0

trophy_screen:
        ld a,PIC_TROPHY
        UCALL show_pic
        ld a,(tourn)
        add a,a
        ld hl,tour_names
        call idx_ptr
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,0
        call f_classic
        ld a,C_HEAD
        call text_c
        call f_sport
        ld hl,s_champ
        ld e,13
        ld a,C_HI
        call text_c
        ld hl,s_bonus5
        ld e,15
        ld a,C_FOOT
        call text_c
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
trophy_anim:    ; you, jumping for joy either side of the cup
        ld a,(framecount)
        and 8
        ld l,186
        jr z,.a
        ld l,180
.a:     ld h,0
        ld (spr_y),hl
        ld hl,120
        ld (spr_x),hl
        call ink_white
        ld a,(framecount)
        and 16
        ld a,FR_B_JOY
        jr z,.b
        inc a
.b:     push af
        call draw_you
        ld a,(framecount)
        and 8
        ld l,180
        jr z,.c
        ld l,186
.c:     ld h,0
        ld (spr_y),hl
        ld hl,392
        ld (spr_x),hl
        pop af
        xor 1
        jp draw_you

grand_slam:
        call tour_clear
        ld a,PIC_TROPHY
        UCALL show_pic
        call f_classic
        ld hl,s_gs1
        ld e,0
        ld a,C_HEAD
        call text_c
        call f_sport
        ld hl,s_gs2
        ld e,13
        ld a,C_HI
        call text_c
        ld hl,s_gs3
        ld e,15
        ld a,C_FOOT
        call text_c
        ld de,$0000
        ld hl,tourpts
        ld a,(hl)
        add a,2                 ; + 20000 (BCD, top byte)
        daa
        ld (hl),a
        ld hl,mus_ending_0
        ld de,mus_ending_1
        call bgm
        ld bc,700
        ld hl,trophy_anim
        call page_wait
        call stop_music
        call enter_hiscore
        jp main_menu
s_gs1:  db "GRAND SLAM!",0
s_gs2:  db "ALL FOUR TITLES ARE YOURS!",0
s_gs3:  db "GRAND SLAM BONUS 20000",0

; ---------------------------------------------------------------------
; TARGET PRACTICE
practice_mode:
        xor a
        ld (intour),a
        call practice_run
        ld hl,s_prres
        call page
        ld hl,s_hits2
        ld e,5
        ld a,C_TEXT
        call text_c
        ld a,(pr_hits)
        ld de,$1F06
        ld b,a
        ld a,C_HI
        call txtc
        ld a,b
        call print_n2
        ld hl,s_pts2
        ld e,8
        ld a,C_TEXT
        call text_c
        call f_led
        ld a,C_HI
        call txtc
        ld hl,pr_score
        ld b,2
        ld de,$1E09
        call print_bcd
        call f_sport
        ld bc,300
        ld hl,0
        call page_wait
        jp main_menu
s_prres: db "PRACTICE OVER",0
s_hits2: db "TARGETS HIT",0
s_pts2:  db "POINTS",0

; one 20-ball session on the next tournament's court
practice_run:
        ld a,MODE_PRACTICE
        ld (mode),a
        ld a,(intour)
        or a
        ld a,(tourn)
        jr z,.ex
        and 3
        ld hl,tour_surf
        call idx_byte
        jr .t
.ex:    ld a,(excourt)
.t:     call set_surface
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
        UCALL play_match
        ld a,(intour)
        or a
        ret z
        ld a,(pr_score+1)
        ld e,a
        ld a,(pr_score)
        ld d,a
        ld a,MODE_TOUR
        ld (mode),a
        jp add_tourpts

; ---------------------------------------------------------------------
; HALL OF FAME entry: a place for the tour points?
enter_hiscore:
        ; find the slot: first entry with fewer points
        ld hl,hitab
        ld b,0
.f:     push hl
        ld de,tourpts
        ld c,3
.cmp:   ld a,(de)
        cp (hl)
        jr nz,.d
        inc hl
        inc de
        dec c
        jr nz,.cmp
        pop hl
        jr .next                ; equal: not better
.d:     pop hl
        jr nc,.slot             ; ours is bigger
.next:  ld de,6
        add hl,de
        inc b
        ld a,b
        cp 5
        jr c,.f
        ret
.slot:  ld a,b
        ld (hpos),a
        ; shift the lower entries down
        ld a,4
        sub b
        jr z,.ins
        ld c,a
        add a,a
        add a,c
        add a,a                 ; 6 per entry
        ld c,a
        ld b,0
        ld hl,hitab+23
        ld de,hitab+29
        lddr
.ins:   ld a,(hpos)
        ld l,a
        add a,a
        add a,l
        add a,a
        ld l,a
        ld h,0
        ld de,hitab
        add hl,de
        ld (hiptr),hl
        ex de,hl
        ld hl,tourpts
        ld bc,3
        ldir
        ld a,'A'
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        ; initials, one letter at a time
        ld hl,s_nhs
        call page
        ld hl,s_ent
        ld e,13
        ld a,C_TEXT
        call text_c
        ld hl,s_ent2
        ld e,15
        ld a,C_FOOT
        call text_c
        ld hl,mus_hiscore_0
        ld de,mus_hiscore_1
        call jingle
        xor a
        ld (hrow),a
.lt:    call draw_hitab
        ld a,(hpos)
        add a,a
        add a,5
        ld e,a
        ld a,(hrow)
        add a,25
        ld d,a
        ld hl,s_mark
        ld a,(framecount)
        and 8
        ld a,C_DIM
        jr z,.mk
        ld a,C_HI
.mk:    call text
        call frame1
        ld hl,(hiptr)
        ld de,3
        add hl,de
        ld a,(hrow)
        ld e,a
        ld d,0
        add hl,de
        ld a,(inpnew)
        bit 2,a
        jr z,.n1
        ld a,(hl)
        inc a
        cp 'Z'+1
        jr c,.s1
        ld a,'A'
.s1:    ld (hl),a
        ld a,SFX_TICK
        call play_sfx
.n1:    ld a,(inpnew)
        bit 3,a
        jr z,.n2
        ld a,(hl)
        dec a
        cp 'A'
        jr nc,.s2
        ld a,'Z'
.s2:    ld (hl),a
        ld a,SFX_TICK
        call play_sfx
.n2:    call check_start
        jr z,.lt
        ld a,SFX_SELECT
        call play_sfx
        ld a,(hrow)
        inc a
        ld (hrow),a
        cp 3
        jr c,.lt
        UCALL save_game
        call draw_hitab
        ld bc,100
        ld hl,0
        call page_wait
        jp stop_music
s_nhs:  db "NEW RECORD!",0
s_ent:  db "ENTER YOUR INITIALS",0
s_ent2: db "UP/DOWN: LETTER    FIRE: NEXT",0
s_mark: db "-",0

front_end:
        ASSERT front_end <= $8000
        SAVEBIN "../build/FRONT.BIN",front_base,front_end-front_base
        DISPLAY "front end: ",front_end
