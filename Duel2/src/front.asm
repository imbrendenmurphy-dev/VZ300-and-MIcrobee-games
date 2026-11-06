; =====================================================================
;  DUEL II - title, attract cycle, menu, campaign, two-player duel,
;  balloon bust, ending, Hall of Fame, records
; =====================================================================

attract:
        ld sp,STACKTOP
.cycle: call title_screen
        jr nz,.go
        call how_to_play
        jr nz,.go
        call meet_aces
        jr nz,.go
        call run_demo
        jr nz,.go
        call hiscore_screen
        jr nz,.go
        jr .cycle
.go:    ld sp,STACKTOP
        call stop_music
        jp main_menu

; ---------------------------------------------------------------------
; plain CSS0 page into BBUF: green, heading HL (big, red) at row 1
page:
        push hl
        call quiet_world
        ld a,0
        ld (palbase),a
        call to_b
        xor a
        call cls_b
        ld a,3
        ld b,0
        call set_ink
        pop hl
        ld a,h
        or l
        jr z,.n
        ld e,1
        call print2_c
.n:     ld a,$55
        ld de,$000C
        ld bc,$2001
        jp fill_rect
; stop drawing objects: nothing to erase, everything clean
quiet_world:
        call clear_objd
        xor a
        ld (banner_t),a
        ld (popup_t),a
        ld (drone),a
        ld (drone+1),a
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
; list of lines: HL -> (db ink, row : dw string), $FF ends
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

; wait up to BC frames; select aborts -> NZ
page_wait:
.l:     push bc
        call do_frame
        pop bc
        call check_start
        ret nz
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret

; ---------------------------------------------------------------------
; TITLE: the logo over a cyan sky, two computer aces dogfighting
title_screen:
        ld a,MODE_TITLE
        ld (mode),a
        ld a,1
        call set_theatre        ; ocean colours (CSS1) for the planes
        ld hl,clouds
        ld de,clouds+1
        ld bc,MAXCL*CL_SIZE-1
        ld (hl),0
        ldir
        ld a,8
        ld (p2ace),a
        ld (p1cpu),a
        ld a,1
        ld (nodamage),a
        call start_round
        xor a
        ld (hud_dirty),a
        ld a,1
        ld (guns_on),a
        ld hl,0
        ld (wind),hl
        ld hl,title_pic
        ld de,BBUF
        call unpack
        call to_b
        ld a,0
        ld b,1
        call set_ink
        ld hl,s_sub
        ld e,23
        call print_c
        call show_b
        ld hl,mus_title_0
        ld de,mus_title_1
        call bgm
        xor a
        ld (tmsg),a
        call title_msg
        ld hl,520
        ld (attr_t),hl
.l:     call do_frame
        call update_world
        call draw_world
        ld a,(framecount)
        and 127
        call z,title_msg
        call check_start
        jr nz,.out
        ld hl,(attr_t)
        dec hl
        ld (attr_t),hl
        ld a,h
        or l
        jr nz,.l
.out:   push af
        xor a
        ld (nodamage),a
        ld a,$FF
        ld (p1cpu),a
        call stop_music
        pop af
        ret
s_sub:  db "ACE OF ACES RETURNS",0
title_msg:
        call to_b
        ld a,(tmsg)
        inc a
        and 3
        ld (tmsg),a
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
        ld a,0
        call fillbyte
        ld de,$003A
        ld bc,$2005
        call fill_rect
        ld a,3
        ld b,0
        call set_ink
        pop hl
        ld e,58
        call print_c
        ld de,58
        ld c,5
        jp b2f_rows
title_msgs: dw tm0,tm1,tm2,tm3
tm0:    db "PRESS FIRE OR SPACE TO PLAY",0
tm1:    db "THE SEQUEL TO VZ DUEL",0
tm2:    db "VIBED BY BPM 2026",0
tm3:    db "8 ACES  4 THEATRES  2 PLAYERS",0

; ---------------------------------------------------------------------
how_to_play:
        ld hl,s_how
        call page
        ld hl,how_lines
        call text_list
        call show_b
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        ld bc,480
        call page_wait
        push af
        call stop_music
        pop af
        ret
s_how:  db "HOW TO PLAY",0
how_lines:
        db 1,15 : dw hw0
        db 1,21 : dw hw1
        db 2,28 : dw hw2
        db 3,34 : dw hw3
        db 3,40 : dw hw4
        db 3,46 : dw hw5
        db 2,52 : dw hw6
        db 1,58 : dw hw7
        db $FF
hw0:    db "HIT YOUR RIVAL 15 TIMES TO WIN",0
hw1:    db "THE SKY WRAPS - HIDE IN CLOUDS!",0
hw2:    db "     WHITE PLANE  DARK PLANE",0
hw3:    db "TURN    A  S        L  ;  ",0
hw4:    db "FASTER  Z           .     ",0
hw5:    db "SLOWER  W           P     ",0
hw6:    db "FIRE  SHIFT OR X  SPACE OR ,",0
hw7:    db "STICK: TURN, UP/DOWN THROTTLE",0

; ---------------------------------------------------------------------
meet_aces:
        xor a
        ld (tmpa),a
        call .pg
        ret nz
        ld a,4
        ld (tmpa),a
.pg:    ld hl,s_meet
        call page
        ld a,(tmpa)
        ld (hrow),a
        ld de,$140D             ; cells: x px, row
        call ace_cell
        ld de,$540D
        call ace_cell
        ld de,$1426
        call ace_cell
        ld de,$5426
        call ace_cell
        call show_b
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        ld bc,300
        call page_wait
        push af
        call stop_music
        pop af
        ret
s_meet: db "MEET THE ACES",0
; ace_cell: D = x pixel of portrait... (D = x px, E = row); ace = (hrow)++
ace_cell:
        push de
        ld a,(hrow)
        call portrait_at
        pop de
        ld a,(hrow)
        call ace_name
        push hl
        call strlen
        ld a,d
        rrca
        rrca
        and 31
        add a,3
        ld c,a
        ld a,b
        srl a
        neg
        add a,c
        ld d,a
        ld a,e
        add a,20
        ld e,a
        ld a,(hrow)
        and 1
        ld a,1
        jr z,.c
        ld a,2
.c:     ld b,0
        push de
        call set_ink
        pop de
        pop hl
        call print
        ld a,(hrow)
        inc a
        ld (hrow),a
        ret
; A = ace -> HL = name
ace_name:
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,ace_names
        add hl,de
        pop de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret
; portrait_at: A = picture 0..8, D = x px (multiple of 4), E = row -> BBUF
portrait_at:
        push de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        sbc hl,de               ; *120
        ld de,portraits
        add hl,de
        pop de
        ld a,d
        rrca
        rrca
        and 31
        ld d,a
        ld bc,$0614
        jp blit_pic
ace_names: dw an0,an1,an2,an3,an4,an5,an6,an7,an8
an0:    db "ROOKIE RUDY",0
an1:    db "FARMER FRITZ",0
an2:    db "SALTY SUE",0
an3:    db "CAPTAIN KRAKEN",0
an4:    db "DUNE RAIDER",0
an5:    db "SCORPION",0
an6:    db "NIGHT OWL",0
an7:    db "THE PHANTOM",0
an8:    db "YOU",0
ace_quotes: dw aq0,aq1,aq2,aq3,aq4,aq5,aq6,aq7
aq0:    db "'IS THIS THE THROTTLE?'",0
aq1:    db "'GET OFF MY FIELD!'",0
aq2:    db "'ANCHORS AWEIGH!'",0
aq3:    db "'RELEASE THE GUNS!'",0
aq4:    db "'SAND IN YOUR EYES!'",0
aq5:    db "'I STING FROM BEHIND'",0
aq6:    db "'I SEE YOU IN THE DARK'",0
aq7:    db "'NOW YOU SEE ME...'",0

; ---------------------------------------------------------------------
; computer v computer demo on a random theatre
run_demo:
        ld a,MODE_DEMO
        ld (mode),a
        ld b,4
        call rand_n
        call set_theatre
        call load_backdrop
        ld b,5
        call rand_n
        add a,3
        ld (p2ace),a
        ld b,5
        call rand_n
        add a,3
        ld (p1cpu),a
        xor a
        ld (pl0+P_WINS),a
        ld (pl1+P_WINS),a
        ld (quit),a
        inc a
        ld (roundno),a
        ld hl,1500
        ld (demot),hl
        call play_round_demo
        ld a,$FF
        ld (p1cpu),a
        xor a
        ld (quit),a
        call check_start
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
        call show_b
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        ld bc,400
        call page_wait
        push af
        call stop_music
        pop af
        ret
s_hof:  db "HALL OF FAME",0
s_play: db "PRESS FIRE TO PLAY",0
draw_hitab:
        ld ix,hitab
        xor a
        ld (hrow),a
.l:     ld a,(hrow)
        and 1
        ld a,1
        jr z,.c
        ld a,2
.c:     ld b,0
        call set_ink
        ld a,(hrow)
        ld b,a
        add a,a
        add a,a
        add a,a
        sub b
        add a,17
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

; initials entry for the campaign score
enter_hiscore:
        ld ix,hitab
        ld c,0
.f:     push ix
        pop hl
        ld de,score
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
        ld hl,score
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
        ld hl,score
        ld b,3
        ld de,$0D2A
        call print_bcd
        call show_b
        ld hl,mus_hiscore_0
        ld de,mus_hiscore_1
        call jingle
        xor a
        ld (hpos),a
        ld hl,1500
        ld (attr_t),hl
.loop:  call to_f
        ld a,1
        ld (objmark),a
        call restore_old
        ld a,3
        ld b,0
        call set_ink
        ld hl,nameb
        ld de,$0D1E
        call print2
        ld a,(framecount)
        and 8
        jr z,.nc
        ld a,1
        ld b,0
        call set_ink
        ld a,(hpos)
        add a,a
        add a,13
        ld d,a
        ld e,41
        ld a,'^'
        call putchar
.nc:    xor a
        ld (objmark),a
        ld a,(mnunew)
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
.nr:    call do_frame
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
MENU_N  equ 5
main_menu:
        ld sp,STACKTOP
        xor a
        ld (mode),a
        ld (quit),a
        ld (menusel),a
        ld a,$FF
        ld (p1cpu),a
        ld hl,s_title2
        call page
        ld hl,s_menuhelp
        ld e,58
        ld a,2
        call text_c
        call menu_items
        call show_b
        ld hl,1500
        ld (attr_t),hl
.loop:  call do_frame
        ld a,(mnunew)
        ld c,a
        bit 2,c
        jr z,.n1
        ld a,(menusel)
        or a
        jr z,.n1
        dec a
        ld (menusel),a
        call .moved
.n1:    bit 3,c
        jr z,.n2
        ld a,(menusel)
        cp MENU_N-1
        jr nc,.n2
        inc a
        ld (menusel),a
        call .moved
.n2:    ld a,c
        and $13
        jr z,.n3
        call menu_change
.n3:    ld a,(keysnew)
        bit 3,a
        call nz,unlock_classic
        ld a,(mnunew)
        or a
        jr z,.idle
        ld hl,1500
        ld (attr_t),hl
.idle:  ld hl,(attr_t)
        dec hl
        ld (attr_t),hl
        ld a,h
        or l
        jr nz,.loop
        jp attract
.moved: push bc
        ld a,SFX_BLIP
        call play_sfx
        call menu_items
        pop bc
        ld hl,1500
        ld (attr_t),hl
        ret
s_title2:   db "DUEL II",0
s_menuhelp: db "UP/DOWN + FIRE. C: CLASSIC 1984",0

menu_change:
        ld a,(menusel)
        or a
        jp z,campaign
        dec a
        jp z,two_player
        dec a
        jr nz,.r
        ; theatre for two players
        ld a,(classic)
        add a,4
        ld b,a
        ld a,(th2p)
        inc a
        cp b
        jr c,.t
        xor a
.t:     ld (th2p),a
        jr .upd
.r:     dec a
        jr nz,.s
        ld a,(rounds2p)
        add a,2
        cp 6
        jr c,.r2
        ld a,1
.r2:    ld (rounds2p),a
        jr .upd
.s:     ld a,(soundmode)
        or a
        jr nz,.s1
        ld a,3
.s1:    dec a
        ld (soundmode),a
.upd:   ld a,SFX_SELECT
        call play_sfx
        call menu_items
        jp save_records

menu_items:
        call to_b
        ld a,0
        call fillbyte
        ld de,$0010
        ld bc,$2028
        call fill_rect
        xor a
        ld (tmpa),a
.l:     ld a,(tmpa)
        ld b,a
        add a,a
        add a,a
        add a,a                 ; *8
        add a,17
        ld e,a
        ld (hy),a
        ld a,(menusel)
        cp b
        ld a,1
        jr nz,.c
        ld a,3
.c:     ld b,0
        push de
        call set_ink
        pop de
        ld a,(tmpa)
        add a,a
        ld l,a
        ld h,0
        ld bc,menu_tab
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld d,5
        call print
        ; value
        ld a,(tmpa)
        cp 2
        jr nz,.v1
        ld a,(th2p)
        add a,a
        ld l,a
        ld h,0
        ld bc,theatre_names
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr .pv
.v1:    cp 3
        jr nz,.v2
        ld a,(rounds2p)
        add a,'0'
        ld hl,s_bestof+8
        ld (hl),a
        ld hl,s_bestof
        jr .pv
.v2:    cp 4
        jr nz,.nv
        ld a,(soundmode)
        add a,a
        ld l,a
        ld h,0
        ld bc,snd_names
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
.pv:    ld a,(hy)
        ld e,a
        ld d,15
        call print
.nv:    ; cursor
        ld a,(menusel)
        ld b,a
        ld a,(tmpa)
        cp b
        jr nz,.nc
        ld a,(hy)
        ld e,a
        ld d,3
        ld a,']'
        call putchar
.nc:    ld a,(tmpa)
        inc a
        ld (tmpa),a
        cp MENU_N
        jp nz,.l
        ld de,$10
        ld c,$28
        jp b2f_rows
menu_tab: dw mi0,mi1,mi2,mi3,mi4
mi0:    db "1 PLAYER CAMPAIGN",0
mi1:    db "2 PLAYER DUEL",0
mi2:    db "THEATRE:",0
mi3:    db "ROUNDS:",0
mi4:    db "SOUND:",0
s_bestof: db "BEST OF 3",0

unlock_classic:
        ld a,(classic)
        or a
        ret nz
        ld a,1
        ld (classic),a
        ld a,4
        ld (th2p),a
        call menu_items
        call to_b
        ld a,3
        ld b,0
        call set_ink
        ld a,0
        call fillbyte
        ld de,$003A
        ld bc,$2005
        call fill_rect
        ld a,3
        ld b,0
        call set_ink
        ld hl,s_unlock
        ld e,58
        call print_c
        ld de,58
        ld c,5
        call b2f_rows
        ld hl,mus_power_0
        ld de,mus_power_1
        call jingle
        jp save_records
s_unlock: db "CLASSIC 1984 UNLOCKED! (2P)",0

; =====================================================================
;  DUELS
; =====================================================================
; duel: best of (need*2-1) rounds -> A = 0 player 1 won, 1 player 2, 3 quit
duel:
        xor a
        ld (pl0+P_WINS),a
        ld (pl1+P_WINS),a
        inc a
        ld (roundno),a
.r:     call load_backdrop
        call play_round
        cp 3
        ret z
        cp 2
        jr z,.r                 ; both down: fly it again
        ld hl,pl0+P_WINS
        or a
        jr z,.w
        ld hl,pl1+P_WINS
.w:     inc (hl)
        or a
        call z,round_bonus
        ld a,(roundno)
        inc a
        ld (roundno),a
        ld a,(need)
        ld b,a
        ld a,(pl0+P_WINS)
        cp b
        ld a,0
        ret z
        ld a,(pl1+P_WINS)
        cp b
        ld a,1
        ret z
        jr .r
; campaign round won: 50 per hit left, 1000 for a flawless round
round_bonus:
        ld a,(mode)
        cp MODE_CAMP
        ret nz
        ld a,(pl0+P_HP)
        or a
        ret z
        ld b,a
.l:     push bc
        ld de,$0050
        call add_score
        pop bc
        djnz .l
        ld a,(pl0+P_HP)
        cp 15
        ret nz
        ld de,$1000
        jp add_score

; demo round: ends early after demot frames
play_round_demo:
        call play_round
        ret

; who-won banner when a round ends (called as rend_t is set)
round_banner:
        ld hl,mus_win_0
        ld de,mus_win_1
        ld bc,s_youwin
        ld a,(pl1+P_STATE)
        cp 1
        jr z,.p1d
        ld a,(pl0+P_STATE)
        cp 1
        jr z,.set
        ld bc,s_both
        jr .set2
.p1d:   ld hl,mus_lose_0
        ld de,mus_lose_1
        ld bc,s_downed
        ld a,(mode)
        cp MODE_CAMP
        jr z,.set
        ld bc,s_p2win
        jr .set
.set:   ld a,(mode)
        cp MODE_CAMP
        jr z,.set2
        ld a,b
        cp s_youwin/256
        jr nz,.set2
        ld a,c
        cp s_youwin&255
        jr nz,.set2
        ld bc,s_p1win
.set2:  ld (banner),bc
        ld a,140
        ld (banner_t),a
        ld a,(mode)
        cp MODE_DEMO
        ret z
        jp jingle
s_youwin: db "YOU WIN!",0
s_downed: db "SHOT DOWN!",0
s_p1win:  db "PLAYER 1 WINS",0
s_p2win:  db "PLAYER 2 WINS",0
s_both:   db "BOTH DOWN!",0

; ---------------------------------------------------------------------
two_player:
        ld a,MODE_2P
        ld (mode),a
        ld a,$FF
        ld (p2ace),a
        ld (p1cpu),a
        xor a
        ld (pl0+P_CTL),a
        inc a
        ld (pl1+P_CTL),a
        ld a,(rounds2p)
        inc a
        srl a
        ld (need),a
        ld a,(th2p)
        call set_theatre
        call theatre_intro
        call duel
        cp 3
        jp z,main_menu
        ; result
        push af
        ld hl,s_result
        call page
        pop af
        ld hl,s_p1win
        or a
        jr z,.w
        ld hl,s_p2win
.w:     ld e,26
        ld a,1
        call text_c
        ld hl,s_theduel
        ld e,34
        ld a,2
        call text_c
        call show_b
        ld hl,mus_duel_0
        ld de,mus_duel_1
        call jingle
        ld bc,350
        call page_wait
        call stop_music
        jp main_menu
s_result:  db "RESULT",0
s_theduel: db "THE DUEL!",0

; theatre intro: the backdrop itself with the name over it
theatre_intro:
        call quiet_world
        call load_backdrop
        call to_b
        ld a,(col0)
        ld b,a
        ld a,(col3)
        call set_ink
        ld a,(theatre)
        cp 4
        jr z,.nn
        add a,'1'
        ld (s_thn+8),a
        ld hl,s_thn
        ld e,18
        call print2_c
.nn:    ld a,(col0)
        ld b,a
        ld a,(col1)
        call set_ink
        ld a,(theatre)
        add a,a
        ld l,a
        ld h,0
        ld de,theatre_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,32
        call print2_c
        call show_b
        ld hl,mus_theatre_0
        ld de,mus_theatre_1
        call jingle
        ld bc,170
        call page_wait
        jp stop_music
s_thn:  db "THEATRE 1",0

; =====================================================================
;  CAMPAIGN
; =====================================================================
campaign:
        ld a,MODE_CAMP
        ld (mode),a
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld (acen),a
        ld (pl0+P_CTL),a
        ld a,3
        ld (lives),a
        ld a,2
        ld (need),a
        ld a,$FF
        ld (p1cpu),a
        ld hl,mus_start_0
        ld de,mus_start_1
        call jingle
.ace:   ld a,(acen)
        and 1
        jr nz,.same
        ld a,(acen)
        srl a
        call set_theatre
        call theatre_intro
.same:  ld a,(acen)
        ld (p2ace),a
        call ace_card
.again: ld a,MODE_CAMP
        ld (mode),a
        ld a,(acen)
        srl a
        call set_theatre
        call duel
        cp 3
        jp z,game_over
        or a
        jr nz,.lost
        ; duel won
        ld de,$2000
        call add_score
        call duel_won
        ld a,(acen)
        inc a
        ld (acen),a
        cp 8
        jp z,ending
        and 1
        jr nz,.ace
        call balloon_bust       ; after each theatre
        jr .ace
.lost:  ld a,(lives)
        dec a
        ld (lives),a
        jp z,game_over
        call try_again
        jr .again

; ace card: portrait, name, quote
ace_card:
        ld hl,s_nextace
        call page
        ld a,(acen)
        ld de,$340E
        call portrait_at
        ld a,(acen)
        call ace_name
        ld e,38
        ld a,3
        call text_c
        ld a,(acen)
        add a,a
        ld l,a
        ld h,0
        ld de,ace_quotes
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,45
        ld a,1
        call text_c
        ld a,(acen)
        add a,'1'
        ld (s_acen+4),a
        ld a,(lives)
        add a,'0'
        ld (s_acen+20),a
        ld hl,s_acen
        ld e,53
        ld a,2
        call text_c
        ld hl,s_bo3
        ld e,59
        ld a,1
        call text_c
        call show_b
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        ld bc,400
        call page_wait
        jp stop_music
s_nextace: db "TALLY HO!",0
s_acen:    db "ACE 1 OF 8   PLANES 3",0
s_bo3:     db "BEST OF 3 ROUNDS - FIRE!",0

duel_won:
        ld hl,s_victory
        call page
        ld a,8
        ld de,$340E
        call portrait_at
        ld a,(acen)
        call ace_name
        ld e,38
        ld a,3
        call text_c
        ld hl,s_defeated
        ld e,45
        ld a,1
        call text_c
        ld hl,s_plus2000
        ld e,53
        ld a,2
        call text_c
        call show_b
        ld hl,mus_duel_0
        ld de,mus_duel_1
        call jingle
        ld bc,260
        call page_wait
        jp stop_music
s_victory:  db "VICTORY!",0
s_defeated: db "IS DEFEATED!",0
s_plus2000: db "DUEL BONUS 2000",0

try_again:
        ld hl,s_downed
        call page
        ld a,(acen)
        ld de,$340E
        call portrait_at
        ld a,(lives)
        add a,'0'
        ld (s_left+0),a
        ld hl,s_left
        ld e,40
        ld a,1
        call text_c
        ld hl,s_retry
        ld e,48
        ld a,2
        call text_c
        call show_b
        ld hl,mus_lose_0
        ld de,mus_lose_1
        call jingle
        ld bc,260
        call page_wait
        jp stop_music
s_left:  db "0 PLANES LEFT",0
s_retry: db "BACK UP FOR ANOTHER GO!",0

game_over:
        call stop_music
        ld hl,s_gover
        call page
        ld a,(acen)
        ld de,$340E
        call portrait_at
        ld a,(acen)
        call ace_name
        ld e,38
        ld a,3
        call text_c
        ld hl,s_wins
        ld e,45
        ld a,1
        call text_c
        ld hl,score
        ld b,3
        ld de,$0D35
        call to_b
        call print_bcd
        call show_b
        ld hl,mus_over_0
        ld de,mus_over_1
        call jingle
        ld bc,300
        call page_wait
        call stop_music
        call enter_hiscore
        jp main_menu
s_gover: db "GAME OVER",0
s_wins:  db "RULES THE SKY!",0

ending:
        ld hl,score             ; +10000
        ld a,(hl)
        add a,1
        daa
        ld (hl),a
        ld hl,s_ace
        call page
        ld de,$300E
        ld hl,medal_pic
        ld bc,$081E
        ld d,12
        call blit_pic
        ld hl,s_end1
        ld e,46
        ld a,1
        call text_c
        ld hl,s_end2
        ld e,52
        ld a,2
        call text_c
        ld hl,s_end3
        ld e,58
        ld a,3
        call text_c
        call show_b
        ld hl,mus_ending_0
        ld de,mus_ending_1
        call jingle
        ld bc,700
        call page_wait
        call stop_music
        call enter_hiscore
        jp main_menu
s_ace:  db "ACE OF ACES!",0
s_end1: db "ALL EIGHT ACES DEFEATED",0
s_end2: db "THE SKY IS YOURS",0
s_end3: db "BONUS 10000",0

; =====================================================================
;  BALLOON BUST bonus round
; =====================================================================
BN_COUNT equ 20
balloon_bust:
        ld hl,s_bust
        call page
        ld hl,bust_lines
        call text_list
        call show_b
        ld hl,mus_theatre_0
        ld de,mus_theatre_1
        call jingle
        ld bc,250
        call page_wait
        call stop_music
        ld a,MODE_BONUS
        ld (mode),a
        ld a,(acen)
        srl a
        call set_theatre
        call load_backdrop
        ld a,BN_COUNT
        ld (bn_left),a
        xor a
        ld (bn_got),a
        ld (bn_fr),a
        ld (bn_spt),a
        ld a,45
        ld (bn_secs),a
        call start_round
        call draw_hud
        call show_b
        ld a,1
        ld (guns_on),a
        ld hl,s_go
        ld (banner),hl
        ld a,40
        ld (banner_t),a
        call battle_music
.l:     call game_frame
        ld a,(quit)
        or a
        jr nz,.end
        ld a,(bn_fr)
        inc a
        ld (bn_fr),a
        cp 50
        jr c,.nt
        xor a
        ld (bn_fr),a
        ld a,1
        ld (hud_dirty),a
        ld a,(bn_secs)
        dec a
        ld (bn_secs),a
        jr z,.end
.nt:    ld a,(bn_left)
        or a
        jr nz,.l
        ld hl,balloons+BA_ON
        ld de,BASIZE
        ld b,NBAL
.ck:    ld a,(hl)
        or a
        jr nz,.l
        add hl,de
        djnz .ck
.end:   call stop_music
        xor a
        ld (drone),a
        ld (drone+1),a
        ld (quit),a
        ; result
        ld hl,s_bust
        call page
        ld a,(bn_got)
        ld de,$0E1A
        call to_b
        ld a,1
        ld b,0
        call set_ink
        ld a,(bn_got)
        ld de,$0D1A
        call print_dec2
        ld hl,s_of20
        ld de,$0F1A
        call print
        ld a,(bn_got)
        cp BN_COUNT
        jr nz,.np
        ld de,$5000
        call add_score
        ld hl,s_perfect
        ld e,36
        ld a,3
        call text_c
.np:    call show_b
        ld hl,mus_win_0
        ld de,mus_win_1
        call jingle
        ld bc,250
        call page_wait
        jp stop_music
s_bust:  db "BALLOON BUST!",0
s_go:    db "GO!",0
s_of20:  db " OF 20 BALLOONS",0
s_perfect: db "PERFECT! BONUS 5000",0
bust_lines:
        db 1,22 : dw bl0
        db 1,30 : dw bl1
        db 2,38 : dw bl2
        db 3,50 : dw bl3
        db $FF
bl0:    db "BONUS ROUND",0
bl1:    db "SHOOT 20 BALLOONS IN 45 SECONDS",0
bl2:    db "200 EACH, ALL 20: 5000 MORE",0
bl3:    db "FIRE TO START",0

; balloons come up in a steady stream
bonus_spawn:
        ld a,(bn_left)
        or a
        jp z,move_balloons
        ld a,(bn_spt)
        or a
        jr z,.sp
        dec a
        ld (bn_spt),a
        jp move_balloons
.sp:    ld a,55
        ld (bn_spt),a
        ld a,(bn_left)
        dec a
        ld (bn_left),a
        call spawn_balloon
        jp move_balloons

; ---------------------------------------------------------------------
; Records in BennVenn SRAM bank 3 ($6780-$67BF): kept until power-off.
; Saving is only enabled if a probe shows the bank switch really works.
REC_LEN equ 4+30+4
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
        cp 3
        jr nc,.s
        ld (soundmode),a
.s:     inc hl
        ld a,(hl)
        and 1
        ld (classic),a
        inc hl
        ld a,(hl)
        cp 6
        jr nc,.r
        and 1
        jr z,.r
        ld a,(hl)
        ld (rounds2p),a
.r:     inc hl
        ld a,(hl)
        cp 5
        ret nc
        ld b,a
        ld a,(classic)
        or a
        jr nz,.t
        ld a,b
        cp 4
        ret nc
.t:     ld a,b
        ld (th2p),a
        ret
.restore:
        ld a,(probe1)
        ld ($67FF),a
.nosram:
        ld a,1
        out ($37),a
        ret
rec_sig: db "DU2A"
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
        ld a,(soundmode)
        ld (de),a
        inc de
        ld a,(classic)
        ld (de),a
        inc de
        ld a,(rounds2p)
        ld (de),a
        inc de
        ld a,(th2p)
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
