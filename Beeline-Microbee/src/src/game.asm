; ==========================================================================
; game.asm - BEELINE: the race, title, scores        ViBED by BPM 2026
;
;   A five-leg point-to-point race against 19 rivals and the clock.
;   Reach each checkpoint before time runs out; every checkpoint adds time
;   and changes the scenery.  Bumping a rival costs speed, never a life.
;
;   States: title (attract mode on autopilot), countdown, race, time up,
;           finish (time bonus tally), initials entry.
; ==========================================================================

GS_TITLE  equ 0
GS_COUNT  equ 1
GS_RACE   equ 2
GS_TIMEUP equ 3
GS_FINISH equ 4
GS_ENTRY  equ 5

START_TIME equ 80               ; seconds for leg 1
K_S     equ 19

; key bits in (keys): 0 left 1 right 2 accel 3 brake
; edge-detected extra keys (ekeys): bit0 SPACE/M (go), bit1 P, bit2 ESC,
;                                   bit3 left, bit4 right

; --------------------------------------------------------------------------
game_start:
        call hud_mode_title
        ld a,(autodrive)        ; test mode (emulator -poke): straight into a race
        or a
        jr nz,.test
        ld a,(fixdt)
        or a
        jr nz,.test
        call title_init
        jr game_loop
.test   call race_init
        call ovr_clear
        ld a,1
        ld (apilot),a
        ld a,GS_RACE
        ld (gstate),a
game_loop:
        call run_frame
        call read_ekeys
        ld a,(ekeys)
        bit 5,a
        jr z,.nm
        ld a,(musoff)
        xor 1
        ld (musoff),a
.nm
        ld a,(dt)
        ld e,a
        ld d,0
        ld hl,(stimer)
        add hl,de
        ld (stimer),hl
        ld a,(gstate)
        add a,a
        ld e,a
        ld d,0
        ld hl,STATES
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,game_loop
        push de
        jp (hl)
STATES: dw title_tick, count_tick, race_tick, timeup_tick, finish_tick, entry_tick

set_state:
        ld (gstate),a
        ld hl,0
        ld (stimer),hl
        ret

; read_ekeys: edge-triggered keys -> (ekeys)
;   bit0 SPACE/M  bit1 P  bit2 ESC  bit3 left  bit4 right
read_ekeys:
        ld a,(rawkeys)          ; go = accelerate or turbo (M, cursor up, SPACE)
        ld b,a
        and 14h
        ld c,0
        jr z,.g0
        inc c
.g0     bit 4,b                 ; turbo key -> bit 6
        jr z,.g1
        set 6,c
.g1
        ld a,(ekframe)          ; P, ESC and S are read on alternate frames
        xor 1
        ld (ekframe),a
        jr z,.skip
        ld a,K_P
        call .kt
        jr z,.c
        set 1,c
.c      ld a,K_ESC
        call .kt
        jr z,.d
        set 2,c
.d      ld a,K_S
        call .kt
        jr z,.e
        set 5,c
        jr .e
.skip   ld a,(ekprev)           ; keep last frame's state of P, ESC, S
        and 26h
        or c
        ld c,a
.e      ld a,(rawkeys)
        and 3
        rlca
        rlca
        rlca
        or c
        ld c,a
        ld a,(ekprev)
        cpl
        and c
        ld (ekeys),a
        ld a,c
        ld (ekprev),a
        ret
.kt     push bc
        call keytest
        pop bc
        ret

; ==========================================================================
; title / attract mode
; ==========================================================================
title_init:
        call race_world
        ld a,1
        ld (apilot),a
        ld hl,0
        ld (titlet),hl
        xor a
        ld (tpage),a
        call hud_mode_title
        call title_page
        ld hl,MUS_TITLE
        call snd_music
        ld a,GS_TITLE
        jp set_state

title_page:
        call ovr_clear
        ld a,(tpage)
        or a
        jr nz,.scores
        ld a,1                  ; logo, rows 1-3
        call ovr_logo
        ld a,4
        ld hl,T_TAG
        ld b,15
        call ovr_text_c
        ld a,6
        ld hl,T_PRESS
        ld b,15
        call ovr_text_c
        ld a,7
        ld hl,T_KEYS
        ld b,14
        jp ovr_text_c
.scores ld a,1
        ld hl,T_BEST
        ld b,11
        call ovr_big_c
        ld b,0                  ; five entries on rows 3..7
.e      push bc
        ld a,b
        call hs_line            ; -> TXTBUF
        pop bc
        push bc
        ld a,b
        add a,3
        ld hl,TXTBUF
        ld c,a
        ld a,b
        or a
        ld b,15
        jr nz,.c
        ld b,11
.c      ld a,c
        call ovr_text_c
        pop bc
        inc b
        ld a,b
        cp 5
        jr c,.e
        ret

title_tick:
        ld a,(ekeys)
        bit 0,a
        jp nz,start_race
        call checkpoint_quiet
        ld hl,(stimer)          ; flip between logo and scores every 8 s
        ld de,400
        or a
        sbc hl,de
        jr c,.blink
        ld hl,0
        ld (stimer),hl
        ld a,(tpage)
        xor 1
        ld (tpage),a
        jp title_page
.blink  ld a,(tpage)            ; "PRESS SPACE" blinks
        or a
        ret nz
        ld a,(stimer)
        and 32
        ld a,15
        jr z,.on
        ld a,0FFh
.on     ld b,a
        ld a,6
        jp ovr_setfg

start_race:
        call race_init
        ret

T_TAG:   db "A 5-LEG RACE AGAINST 19 RIVALS AND THE CLOCK",0
T_PRESS: db "PRESS SPACE TO RACE",0
T_KEYS:  db "Z X STEER  M GO  N BRAKE  SPACE TURBO  P PAUSE  S MUSIC",0
T_BEST:  db "BEST DRIVERS",0

; ==========================================================================
; race
; ==========================================================================
; race_world: fresh road, grid and scenery (title and race)
race_world:
        call track_reset
        xor a
        ld (leg),a
        call traffic_reset
        ld hl,0
        ld (camX),hl
        ld (speed),hl
        xor a
        ld (steerT),a
        ld a,2
        ld (carpose),a
        jp leg_theme

race_init:
        call race_world
        xor a
        ld (apilot),a
        ld hl,SCORE
        ld b,4
.z      ld (hl),a
        inc hl
        djnz .z
        ld a,START_TIME
        ld (tsec),a
        ld a,3
        ld (turbos),a
        xor a
        ld (boostt),a
        ld a,50
        ld (tfld),a
        call hud_mode_race
        call ovr_clear
        ld hl,0
        call snd_music
        ld a,1
        ld hl,T_LEG1
        ld b,15
        call ovr_text_c
        ld a,4
        ld hl,LEGNAME
        ld b,11
        call ovr_name
        ld a,3
        ld (cdown),a
        call show_count
        call snd_count
        ld a,GS_COUNT
        jp set_state
T_LEG1: db "LEG 1 OF 5",0

; countdown: 3 2 1 GO, one second each
count_tick:
        ld hl,(stimer)
        ld de,50
        or a
        sbc hl,de
        ret c
        ld (stimer),hl
        ld a,(cdown)
        dec a
        ld (cdown),a
        jr z,.go
        call show_count
        jp snd_count
.go     call ovr_clear
        ld a,2
        ld hl,T_GO
        ld b,10
        call ovr_big_c
        ld a,50
        ld (msgt),a
        call snd_go
        ld hl,MUS_RACE
        call snd_music
        ld a,GS_RACE
        jp set_state
T_GO:   db "GO!",0

show_count:
        ld a,2                  ; clear the big rows, then the digit
        call ovr_rowoff
        ld a,3
        call ovr_rowoff
        ld a,(cdown)
        add a,'0'
        ld (.s),a
        ld a,2
        ld hl,.s
        ld b,11
        jp ovr_big_c
.s      db "0",0

race_tick:
        ld a,(ekeys)
        bit 2,a
        jp nz,title_init
        bit 1,a
        call nz,pause
        ; message timeout
        ld a,(msgt)
        or a
        jr z,.m0
        ld hl,dt
        sub (hl)
        jr nc,.m1
        xor a
.m1     ld (msgt),a
        call z,ovr_clear
.m0     ; clock
        ld a,(dt)
        ld b,a
        ld a,(tfld)
        sub b
        jr z,.sec
        jr nc,.ts
.sec    add a,50
        ld (tfld),a
        ld a,(tsec)
        dec a
        ld (tsec),a
        jp z,timeup_init
        cp 6
        call c,snd_warn
        jr .tdone
.ts     ld (tfld),a
.tdone  ; score: speed * dt / 64
        ld hl,(speed)
        ld a,(dt)
        ld b,a
        ld de,0
.sp     ex de,hl
        add hl,de
        ex de,hl
        djnz .sp
        ld a,e                  ; DE = speed*dt -> /64
        rlca
        rlca
        and 3
        ld e,a
        ld a,d
        add a,a
        add a,a
        or e
        call add_score_a
        ; rival events
        ld a,(tevents)
        ld c,a
        xor a
        ld (tevents),a
        bit 0,c
        jr z,.e1
        push bc
        ld a,10h                ; overtake: +1000
        call add_score_100
        call snd_pass
        pop bc
.e1     bit 2,c
        push bc
        call nz,snd_crash
        pop bc
        bit 3,c                 ; slipstream boost
        jr z,.e3
        call snd_slip
        ld hl,T_SLIP
        call boost_msg
.e3     ld a,(ekeys)            ; turbo
        bit 6,a
        jr z,.e4
        ld a,(turbos)
        or a
        jr z,.e4
        ld a,(boostt)
        cp 20
        jr nc,.e4
        ld a,(turbos)
        dec a
        ld (turbos),a
        ld a,150
        ld (boostt),a
        call snd_turbo
        ld hl,T_TURBO
        call boost_msg
.e4     jp checkpoint

; boost_msg: HL -> text for row 1, unless a bigger message is showing
boost_msg:
        ld a,(msgt)
        or a
        ret nz
        ld a,1
        ld b,15
        call ovr_text_c
        ld a,60
        ld (msgt),a
        ret
T_SLIP:  db "SLIPSTREAM!",0
T_TURBO: db "TURBO!",0

; checkpoint: past the end of this leg?
checkpoint:
        call past_leg
        ret c
        ld a,(leg)
        cp NLEGS-1
        jp nc,finish_init
        inc a
        ld (leg),a
        call leg_theme
        call set_pace
        ld a,3                  ; turbos topped up
        ld (turbos),a
        ld a,(leg)              ; time bonus
        ld e,a
        ld d,0
        ld hl,LEGBONUS-1
        add hl,de
        ld a,(tsec)
        add a,(hl)
        cp 100
        jr c,.t
        ld a,99
.t      ld (tsec),a
        call ovr_clear
        ld a,1
        ld hl,T_EXT
        ld b,14
        call ovr_text_c
        ld a,2
        ld hl,T_CHECK
        ld b,11
        call ovr_big_c
        ld a,(leg)              ; leg name
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        add hl,de
        add hl,hl               ; *14
        ld de,LEGNAME
        add hl,de
        ld a,4
        ld b,15
        call ovr_name
        ld a,150
        ld (msgt),a
        jp snd_check
T_EXT:  db "EXTENDED PLAY!",0
T_CHECK: db "CHECKPOINT",0
LEGBONUS: db 60,50,56,54

; checkpoint_quiet: attract mode changes scenery at each leg end too
checkpoint_quiet:
        call past_leg
        ret c
        ld a,(leg)
        inc a
        cp NLEGS
        jr c,.l
        call race_world         ; demo finished: start over
        jp title_page
.l      ld (leg),a
        jp leg_theme

; past_leg: NC if tdist >= LEGEND[leg]
past_leg:
        ld a,(leg)
        add a,a
        ld e,a
        ld d,0
        ld hl,LEGEND
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(tdist)
        or a
        sbc hl,de
        ret

leg_theme:
        ld a,(leg)
        ld e,a
        ld d,0
        ld hl,LEGTHEME
        add hl,de
        ld a,(hl)
        ld (theme),a
        jp set_theme
LEGTHEME: db 2,3,1,0,4

; pause: P again to continue (the picture stays as it is)
pause:  ld a,(page)             ; "PAUSED" on the HUD of the shown page
        push af
        xor 1
        ld (page),a
        ld hl,HUDTXT
        ld de,PAUSEBUF
        ld bc,64
        ldir
        ld hl,T_PAUSED
        ld de,HUDTXT+24
        ld bc,16
        ldir
        call hud_static
.w      call wait_vb
        call read_ekeys
        ld a,(ekeys)
        and 2
        jr z,.w
        ld hl,PAUSEBUF
        ld de,HUDTXT
        ld bc,64
        ldir
        call hud_static
        pop af
        ld (page),a
        ld hl,(fields)          ; no time passes during the pause
        ld (lastf),hl
        ld (flipf),hl
        xor a
        ld (ekeys),a
        ret
T_PAUSED: db "    PAUSED      "

; ==========================================================================
; time up / finish / entry
; ==========================================================================
timeup_init:
        ld hl,0
        call snd_music
        call ovr_clear
        ld a,2
        ld hl,T_TIMEUP
        ld b,9
        call ovr_big_c
        call snd_timeup
        ld a,GS_TIMEUP
        jp set_state
T_TIMEUP: db "TIME UP",0
T_GAMEOVER: db "GAME OVER",0

timeup_tick:
        ld hl,(stimer)
        ld de,100
        or a
        sbc hl,de
        jr c,.r
        ld a,(gover)            ; "GAME OVER" after 2 s
        or a
        jr nz,.r
        inc a
        ld (gover),a
        ld a,2
        call ovr_rowoff
        ld a,3
        call ovr_rowoff
        ld a,2
        ld hl,T_GAMEOVER
        ld b,9
        call ovr_big_c
.r      ld hl,(stimer)
        ld de,250
        or a
        sbc hl,de
        ret c
        xor a
        ld (gover),a
        jp game_over

finish_init:
        ld hl,0
        call snd_music
        ld a,1
        ld (apilot),a
        call ovr_clear
        ld a,2
        ld hl,T_FINISH
        ld b,11
        call ovr_big_c
        ld hl,T_FINPOS          ; "YOU FINISHED 3RD"
        ld de,TXTBUF
        ld bc,13
        ldir
        ld a,(rivals)
        inc a
        call pos_text           ; DE advances
        xor a
        ld (de),a
        ld a,1
        ld hl,TXTBUF
        ld b,15
        call ovr_text_c
        ld a,(rivals)           ; winner's bonus
        or a
        jr nz,.nw
        ld a,50h
        call add_score_10k
.nw     call snd_finish
        ld a,GS_FINISH
        jp set_state
T_FINISH: db "FINISH!",0
T_FINPOS: db "YOU FINISHED "

finish_tick:
        ld a,(tsec)             ; time bonus: 10000 per second left
        or a
        jr z,.done
        dec a
        ld (tsec),a
        ld a,1
        call add_score_10k
        jp snd_tally
.done   ld hl,(stimer)
        ld de,350
        or a
        sbc hl,de
        ret c
        jp game_over

; game_over: initials if the score made the table, else the title
game_over:
        call hs_rank
        cp 5
        jp nc,title_init
        ld (erank),a
        ld a,'A'
        ld (ename),a
        ld (ename+1),a
        ld (ename+2),a
        xor a
        ld (epos),a
        ld a,1
        ld (apilot),a
        call ovr_clear
        ld a,2
        ld hl,T_GREAT
        ld b,11
        call ovr_big_c
        ld a,4
        ld hl,T_ENTER
        ld b,15
        call ovr_text_c
        ld a,7
        ld hl,T_EKEYS
        ld b,14
        call ovr_text_c
        call entry_show
        ld a,GS_ENTRY
        jp set_state
T_GREAT: db "GREAT DRIVING",0
T_ENTER: db "ENTER YOUR INITIALS",0
T_EKEYS: db "Z X CHOOSE   SPACE NEXT",0

entry_tick:
        ld a,(ekeys)
        ld c,a
        ld a,(epos)
        ld e,a
        ld d,0
        ld hl,ename
        add hl,de
        bit 3,c                 ; left: previous letter
        jr z,.r
        ld a,(hl)
        dec a
        cp 'A'
        jr nc,.l1
        ld a,'Z'
.l1     ld (hl),a
        jp entry_show
.r      bit 4,c
        jr z,.ok
        ld a,(hl)
        inc a
        cp 'Z'+1
        jr c,.r1
        ld a,'A'
.r1     ld (hl),a
        jp entry_show
.ok     bit 0,c
        ret z
        call snd_pass
        ld a,(epos)
        inc a
        ld (epos),a
        cp 3
        jp c,entry_show
        call hs_insert
        call title_init
        ld a,1                  ; straight to the score table
        ld (tpage),a
        jp title_page

entry_show:
        ld hl,ename
        ld de,TXTBUF
        ld b,3
        ld a,(epos)
        ld c,a
.c      ld a,(hl)
        ld (de),a
        inc de
        inc hl
        ld a,' '
        ld (de),a
        inc de
        djnz .c
        xor a
        ld (de),a
        ld a,5
        ld hl,TXTBUF
        ld b,11
        jp ovr_text_c

; ==========================================================================
; high scores: 5 x (3 letters, 4 BCD bytes big-endian)
; ==========================================================================
HISC:   db "BPM",00h,10h,00h,00h
        db "VBD",00h,08h,00h,00h
        db "BEE",00h,06h,00h,00h
        db "MCB",00h,04h,00h,00h
        db "ZED",00h,02h,00h,00h
HISCEND:

; hs_rank: A = table position the current score would take (5 = none)
hs_rank:
        ld hl,HISC+3
        ld c,0
.e      ld de,SCORE
        push hl
        ld b,4
.c      ld a,(de)
        cp (hl)
        jr nz,.d
        inc de
        inc hl
        djnz .c
        pop hl                  ; equal: goes below
        jr .n
.d      pop hl
        jr nc,.got              ; score > entry
.n      ld de,7
        add hl,de
        inc c
        ld a,c
        cp 5
        jr c,.e
.got    ld a,c
        ret

; hs_insert: put (ename, SCORE) at position erank
hs_insert:
        ld a,(erank)            ; shift the lower entries down
        ld b,a
        ld a,4
        sub b
        jr z,.put
        ld c,a
        ld b,0
        ld h,b
        ld l,c
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,bc               ; *7
        ld b,h
        ld c,l
        ld hl,HISCEND-8
        ld de,HISCEND-1
        lddr
.put    ld a,(erank)
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        ld de,HISC
        add hl,de
        ex de,hl
        ld hl,ename
        ld bc,3
        ldir
        ld hl,SCORE
        ld bc,4
        ldir
        ret

; hs_line: A = entry -> TXTBUF "1ST  BPM  01000000"
hs_line:
        push af
        ld de,TXTBUF
        inc a
        call pos_text
        ld a,' '
        ld (de),a
        inc de
        ld (de),a
        inc de
        pop af
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,bc
        ld bc,HISC
        add hl,bc
        ld bc,3
        ldir
        ld a,' '
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld b,4
        call put_bcd
        xor a
        ld (de),a
        ret

; pos_text: A = 1..20 -> "1ST", "2ND", "12TH" at DE (DE advances)
pos_text:
        ld (.n),a
        cp 10
        jr c,.one
        ld b,'0'-1
.t      inc b
        sub 10
        jr nc,.t
        add a,10
        ld c,a
        ld a,b
        ld (de),a
        inc de
        ld a,c
.one    add a,'0'
        ld (de),a
        inc de
        ld a,(.n)
        ld hl,.th
        cp 4
        jr nc,.s
        ld hl,.rd
        cp 3
        jr z,.s
        ld hl,.nd
        cp 2
        jr z,.s
        ld hl,.st
.s      ld a,(hl)
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        ld (de),a
        inc de
        ret
.n      db 0
.st     db "ST"
.nd     db "ND"
.rd     db "RD"
.th     db "TH"
