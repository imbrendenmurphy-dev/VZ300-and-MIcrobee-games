; =====================================================================
;  TENNIS II - the match engine: serving, ball flight, hitting,
;  computer players, scoring, umpire calls
; =====================================================================
MODE_DEMO     equ 0
MODE_TOUR     equ 1
MODE_EXHIB    equ 2
MODE_2P       equ 3
MODE_PRACTICE equ 4

CTL_CPU  equ 0
CTL_ANY  equ 1          ; 1-player human: keyboard + either joystick
CTL_PAD1 equ 2
CTL_PAD2 equ 3
CTL_NONE equ 4

; player record
P_X     equ 0
P_Y     equ 2
P_CTL   equ 4
P_TEAM  equ 5
P_END   equ 6
P_FRAME equ 7
P_ANIM  equ 8
P_SWING equ 9
P_SWFR  equ 10
P_CHAR  equ 11
P_SPD   equ 12
P_REACH equ 14
P_REACT equ 15
P_ACC   equ 16
P_POW   equ 17
P_NET   equ 18
P_SERV  equ 19
P_FAULT equ 20
P_LOB   equ 21
P_INP   equ 22
P_INPN  equ 23
P_FBUF  equ 24
P_TX    equ 25
P_TY    equ 26
P_DLY   equ 27
P_STREAK equ 28
P_FIRE  equ 29
P_POSE  equ 30
P_MOVED equ 31
P_SPDY  equ 32
P_HITOK equ 34
P_NAME  equ 35
P_IDX   equ 37
P_APPR  equ 38
P_LNAME equ 39
PSIZE   equ 41

G_ACC   equ 16          ; gravity, 0.25 units/frame^2
NETH    equ 14*64       ; net height

; point reasons
R_NORMAL equ 0
R_OUT    equ 1
R_NET    equ 2
R_ACE    equ 3
R_WINNER equ 4
R_DFAULT equ 5
R_FAULT  equ 6          ; not a point: second serve
R_LET    equ 7          ; not a point: replay the serve

; popups
POP_OUT equ 0
POP_NET equ 1
POP_ACE equ 2
POP_WIN equ 3
POP_FAULT equ 4
POP_DF  equ 5
POP_LET equ 6
POP_FIRE equ 7
POP_SMASH equ 8
POP_TARGET equ 9
POP_IN  equ 10
popstr: dw ps0,ps1,ps2,ps3,ps4,ps5,ps6,ps7,ps8,ps9,ps10
ps0:    db "OUT!",0
ps1:    db "NET!",0
ps2:    db "ACE!",0
ps3:    db "WINNER!",0
ps4:    db "FAULT",0
ps5:    db "DBL FAULT",0
ps6:    db "LET",0
ps7:    db "ON FIRE!",0
ps8:    db "SMASH!",0
ps9:    db "BULLSEYE!",0
ps10:   db "IN",0

; characters: dw short name, dw long name, dw speed, reach, react, acc, pow, net, serve, fault, lob
CHSIZE  equ 14
chartab:
        dw cn0,cl0,140 : db 18,16,40,20,  0, 20,60, 40
        dw cn1,cl1,150 : db 20,14,32,30,  0, 30,50,150
        dw cn2,cl2,172 : db 22,12,28,60,200, 40,50, 20
        dw cn3,cl3,146 : db 22,12,26,110,30,120,80, 20
        dw cn4,cl4,184 : db 24,10,20,50,  0, 50,40, 60
        dw cn5,cl5,198 : db 24, 8,18,140,40, 80,50, 30
        dw cn6,cl6,180 : db 25, 7,12,80, 90, 70,30, 70
        dw cn7,cl7,208 : db 26, 5, 8,150,100,110,25, 50
        dw cn8,cl8,194 : db 26, 6,16,100,60, 80,40, 40
cn0: db "RUS",0
cn1: db "LOU",0
cn2: db "NET",0
cn3: db "BAZ",0
cn4: db "DUS",0
cn5: db "RIT",0
cn6: db "PRO",0
cn7: db "MVZ",0
cn8: db "YOU",0
cl0: db "ROOKIE RUSTY",0
cl1: db "LOBBY LOU",0
cl2: db "NET NETTA",0
cl3: db "BIG SERVE BAZZA",0
cl4: db "DUSTY THE WALL",0
cl5: db "ROCKET RITA",0
cl6: db "THE PROFESSOR",0
cl7: db "MR VZ300",0
cl8: db "YOU",0
s_p1:  db "P1",0
s_p2:  db "P2",0
s_lp1: db "PLAYER 1",0
s_lp2: db "PLAYER 2",0
s_cpu: db "CPU",0

; setup_player: IX = player, A = character, C = control, B = skill boost (0..3)
setup_player:
        ld (ix+P_CHAR),a
        ld (ix+P_CTL),c
        push bc
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl               ; *14 = *16 - *2
        add hl,hl
        add hl,hl
        add hl,hl
        sbc hl,de
        sbc hl,de
        ld de,chartab
        add hl,de
        ld a,(hl)
        ld (ix+P_NAME),a
        inc hl
        ld a,(hl)
        ld (ix+P_NAME+1),a
        inc hl
        ld a,(hl)
        ld (ix+P_LNAME),a
        inc hl
        ld a,(hl)
        ld (ix+P_LNAME+1),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        pop bc
        push bc
        ; boost: +6 speed per level
        ld a,b
        add a,a
        ld c,a
        add a,a
        add a,c
        add a,e
        ld e,a
        jr nc,.ns
        inc d
.ns:    ld (ix+P_SPD),e
        ld (ix+P_SPD+1),d
        ; Y speed = 3/4 of X speed
        push hl
        ex de,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        srl h
        rr l
        srl h
        rr l
        ld (ix+P_SPDY),l
        ld (ix+P_SPDY+1),h
        pop hl
        pop bc
        ld a,(hl)
        ld (ix+P_REACH),a
        inc hl
        ld a,(hl)               ; react - boost
        sub b
        jr nc,.r1
        xor a
.r1:    ld (ix+P_REACT),a
        inc hl
        ld a,(hl)               ; accuracy error - 3*boost
        sub b
        sub b
        sub b
        jr nc,.a1
        xor a
.a1:    cp 6
        jr nc,.a2
        ld a,6
.a2:    ld (ix+P_ACC),a
        inc hl
        ld a,(hl)
        ld (ix+P_POW),a
        inc hl
        ld a,(hl)
        ld (ix+P_NET),a
        inc hl
        ld a,(hl)
        ld (ix+P_SERV),a
        inc hl
        ld a,(hl)
        ld (ix+P_FAULT),a
        inc hl
        ld a,(hl)
        ld (ix+P_LOB),a
        call ctl_cpu
        ret z
        ; humans: standard human reach + speed
        ld (ix+P_REACH),26
        ld (ix+P_SPD),196
        ld (ix+P_SPD+1),0
        ld (ix+P_SPDY),148
        ld (ix+P_SPDY+1),0
        ret

; ---------------------------------------------------------------------
; play_match: plays a whole match with pl0/pl1 set up and the surface set.
; -> A = winner (0/1), or $FF if quit / demo aborted / demo timed out
; ---------------------------------------------------------------------
play_match:
        xor a
        ld (pts),a
        ld (pts+1),a
        ld (games),a
        ld (games+1),a
        ld (sets),a
        ld (sets+1),a
        ld (tiebreak),a
        ld (servenum),a
        ld (match_over),a
        ld (pop_tim),a
        ld (pop_on),a
        ld (flag_tim),a
        ld (puff_tim),a
        ld (pl0+P_STREAK),a
        ld (pl1+P_STREAK),a
        ld (pl0+P_FIRE),a
        ld (pl1+P_FIRE),a
        ld (pl0+P_IDX),a
        ld (pl0+P_TEAM),a
        ld (pl0+P_END),a
        inc a
        ld (pl1+P_IDX),a
        ld (pl1+P_TEAM),a
        ld (pl1+P_END),a
        ld a,(mode)
        cp MODE_PRACTICE
        jp z,practice_start
        ; computer serves first against a human; otherwise random
        call random
        and 1
        ld (server),a
        ld a,(pl0+P_CTL)
        cp CTL_CPU
        jr nz,.sv
        ld a,(pl1+P_CTL)
        cp CTL_CPU
        jr z,.sv
        xor a
        ld (server),a
.sv:    call serve_setup
        call court_show
        call crowd_reset
        ; opening call: "<name> TO SERVE"
        call server_ix
        ld l,(ix+P_LNAME)
        ld h,(ix+P_LNAME+1)
        ld de,s_toserve
        call banner
        ld b,70
        call hold
        ret nz
        call court_restore
.loop:  call match_step
        ld a,(match_over)
        or a
        jr z,.loop
        ld a,(match_win)
        ret
s_toserve: db "TO SERVE",0

; IX = server, IY = receiver
server_ix:
        ld ix,pl0
        ld iy,pl1
        ld a,(server)
        or a
        ret z
        ld ix,pl1
        ld iy,pl0
        ret

; hold B frames, drawing the scene. NZ if the demo was aborted.
hold:
        push bc
        call anim_players
        call ball_dead_phys
        call fx_update
        call crowd_tick
        call match_draw
        call do_frame
        pop bc
        ld a,(mode)
        or a
        jr nz,.nd
        call check_start
        jr z,.nd
        ld a,$FF
        ld (match_win),a
        ld a,1
        ld (match_over),a
        or a
        ret
.nd:    djnz hold
        xor a
        ret

; ---------------------------------------------------------------------
; one frame of play
match_step:
        call players_update
        call ball_update
        call fx_update
        call crowd_tick
        call match_draw
        call do_frame
        call match_keys
        ; demo: time out / abort
        ld a,(mode)
        or a
        jr nz,.nd
        ld hl,(demotim)
        dec hl
        ld (demotim),hl
        ld a,h
        or l
        jr z,.abort
        call check_start
        jr nz,.abort
.nd:    ld a,(pt_over)
        or a
        ret z
        dec a
        ld (pt_over),a
        ret nz
        ; point over
        ld a,(mode)
        cp MODE_PRACTICE
        jp z,practice_next
        ld a,(pt_reason)
        cp R_FAULT
        jp z,serve_setup
        cp R_LET
        jp z,serve_setup
        ld a,(pt_win)
        call award_point
        ld a,(match_over)
        or a
        ret nz
        jp serve_setup
.abort: ld a,$FF
        ld (match_win),a
        ld a,1
        ld (match_over),a
        ret

; P = pause (X quits), S = sound mode
match_keys:
        ld a,(mode)
        or a
        ret z
        ld a,(keysnew)
        bit 0,a
        call nz,toggle_sound
        ld a,(keysnew)
        bit 1,a
        ret z
        ld hl,s_paused
        ld de,s_pausehelp
        call banner
        ld a,(soundmode)
        push af
        xor a
        ld (soundmode),a
.pl:    call match_draw
        call do_frame
        ld a,(keysnew)
        bit 3,a
        jr nz,.quit
        bit 1,a
        jr z,.pl
        pop af
        ld (soundmode),a
        jp court_restore
.quit:  pop af
        ld (soundmode),a
        ld a,$FF
        ld (match_win),a
        ld a,1
        ld (match_over),a
        ret
s_paused:    db "PAUSED",0
s_pausehelp: db "P: PLAY ON   X: QUIT",0

toggle_sound:
        ld a,(soundmode)
        or a
        jr nz,.s1
        ld a,3
.s1:    dec a
        ld (soundmode),a
        or a
        call z,stop_music
        ret

; ---------------------------------------------------------------------
; serve_setup: players to their serving positions, ball in the server's hand
serve_setup:
        xor a
        ld (pt_over),a
        ld (ball_st),a
        ld (ball_net),a
        ld (ball_cord),a
        ld (ball_fire),a
        ld (rally),a
        ld (pl0+P_SWING),a
        ld (pl1+P_SWING),a
        ld (pl0+P_POSE),a
        ld (pl1+P_POSE),a
        ld (pl0+P_APPR),a
        ld (pl1+P_APPR),a
        ld (pl0+P_FBUF),a
        ld (pl1+P_FBUF),a
        inc a
        ld (pl0+P_HITOK),a
        ld (pl1+P_HITOK),a
        call crowd_settle
        ; side: deuce when the points played so far are even
        ld a,(pts)
        ld b,a
        ld a,(pts+1)
        add a,b
        and 1
        ld c,a                  ; 0 deuce, 1 ad
        call server_ix
        ld a,(ix+P_END)
        or a
        jr nz,.near
        ld b,88                 ; far server: his right is the screen left
        ld a,c
        or a
        jr z,.f1
        ld b,168
.f1:    ld a,b
        ld c,16
        jr .place
.near:  ld b,168
        ld a,c
        or a
        jr z,.n1
        ld b,88
.n1:    ld a,b
        ld c,240
.place: ld (srv_x),a
        call place_ix           ; A = X, C = Y
        ; receiver diagonally opposite
        push ix
        push iy
        pop ix
        ld a,(ix+P_END)
        ld c,20
        or a
        jr z,.r1
        ld c,236
.r1:    ld a,(srv_x)
        neg                     ; 256 - X
        call place_ix
        pop ix
        ; ball in hand
        call ball_to_hand
        ; serve timer
        call ctl_cpu
        ld a,200
        jr nz,.h
        ld b,30
        call rand_n
        add a,35
.h:     ld (srv_tim),a
        ld a,(ix+P_IDX)
        ld (ball_last),a
        call hud_draw
        ret

; place_ix: A = X int, C = Y int
place_ix:
        call from_int
        ld (ix+P_X),l
        ld (ix+P_X+1),h
        ld a,c
        call from_int
        ld (ix+P_Y),l
        ld (ix+P_Y+1),h
        ld (ix+P_FRAME),FR_IDLE
        ret

; ball_to_hand: IX = server
ball_to_hand:
        ld l,(ix+P_X)
        ld h,(ix+P_X+1)
        ld de,-4*64
        ld a,(ix+P_END)
        or a
        jr z,.l
        ld de,4*64
.l:     add hl,de
        ld (ball_x),hl
        ld l,(ix+P_Y)
        ld h,(ix+P_Y+1)
        ld (ball_y),hl
        ld hl,18*64
        ld (ball_z),hl
        ld hl,0
        ld (ball_vx),hl
        ld (ball_vy),hl
        ld (ball_vz),hl
        ret

; ---------------------------------------------------------------------
players_update:
        ld ix,pl0
        call player_update
        ld ix,pl1
        call player_update
        ld a,(ball_st)
        cp 2
        jp c,serve_logic
        ret

player_update:
        ld (ix+P_MOVED),0
        ld a,(ix+P_CTL)
        cp CTL_NONE
        ret z
        call ctl_cpu
        jr z,.cpu
        ld a,(ix+P_CTL)
        ; input for humans
        ld b,0
        cp CTL_ANY
        jr nz,.c2
        ld a,(inp)
        ld b,a
        ld a,(inpnew)
        jr .gotin
.c2:    cp CTL_PAD1
        jr nz,.c3
        ld a,(pad1)
        ld b,a
        ld a,(pad1new)
        jr .gotin
.c3:    cp CTL_PAD2
        jr nz,.cpu
        ld a,(pad2)
        ld b,a
        ld a,(pad2new)
.gotin: ld (ix+P_INPN),a
        ld (ix+P_INP),b
        bit 4,a
        jr z,.nf
        ld (ix+P_FBUF),10
        jr .hf
.nf:    ld a,(ix+P_FBUF)
        or a
        jr z,.hf
        dec (ix+P_FBUF)
.hf:    ; servers stand still until the serve is struck
        call is_waiting_server
        jr z,.anim
        ld a,(pt_over)
        or a
        jr nz,.anim
        call human_move
        jr .clamp
.cpu:   call is_waiting_server
        jr z,.anim
        call ai_move
.clamp: call clamp_player
.anim:  jp anim_one

; Z if IX is the server and the serve has not been struck yet
is_waiting_server:
        ld a,(ball_st)
        cp 2
        jr nc,.no
        ld a,(server)
        cp (ix+P_IDX)
        ret
.no:    or 1
        ret

human_move:
        ld b,(ix+P_INP)
        ld e,(ix+P_SPD)
        ld d,(ix+P_SPD+1)
        ld l,(ix+P_X)
        ld h,(ix+P_X+1)
        bit 0,b
        jr z,.l
        add hl,de
        ld (ix+P_MOVED),1
.l:     bit 1,b
        jr z,.x
        or a
        sbc hl,de
        ld (ix+P_MOVED),1
.x:     ld (ix+P_X),l
        ld (ix+P_X+1),h
        ld e,(ix+P_SPDY)
        ld d,(ix+P_SPDY+1)
        ld l,(ix+P_Y)
        ld h,(ix+P_Y+1)
        bit 2,b
        jr z,.d
        or a
        sbc hl,de
        ld (ix+P_MOVED),1
.d:     bit 3,b
        jr z,.y
        add hl,de
        ld (ix+P_MOVED),1
.y:     ld (ix+P_Y),l
        ld (ix+P_Y+1),h
        ret

; keep players inside their half and on screen
clamp_player:
        ld l,(ix+P_X)
        ld h,(ix+P_X+1)
        ld de,24*64
        call clamp_lo
        ld de,232*64
        call clamp_hi
        ld (ix+P_X),l
        ld (ix+P_X+1),h
        ld l,(ix+P_Y)
        ld h,(ix+P_Y+1)
        ld a,(ix+P_END)
        or a
        jr nz,.n
        ld de,10*64
        call clamp_lo
        ld de,112*64
        call clamp_hi
        jr .s
.n:     ld de,144*64
        call clamp_lo
        ld de,250*64
        call clamp_hi
.s:     ld (ix+P_Y),l
        ld (ix+P_Y+1),h
        ret
clamp_lo:       ; HL = max(HL, DE) signed
        push hl
        or a
        sbc hl,de
        pop hl
        ret p
        ex de,hl
        ret
clamp_hi:       ; HL = min(HL, DE)
        push hl
        or a
        sbc hl,de
        pop hl
        ret m
        ret z
        ex de,hl
        ret

; animation frame for IX
anim_one:
        ld a,(ix+P_CTL)
        cp CTL_NONE
        ret z
        ld a,(ix+P_SWING)
        or a
        jr z,.ns
        dec (ix+P_SWING)
        ld a,(ix+P_SWFR)
        jr .set
.ns:    ld a,(ix+P_POSE)
        or a
        jr z,.np
        ld a,(framecount)
        and 16
        ld a,FR_IDLE
        jr z,.set
        ld a,(ix+P_POSE)
        jr .set
.np:    ld a,(ball_st)
        cp 1
        jr nz,.nt
        ld a,(server)
        cp (ix+P_IDX)
        ld a,FR_SERVE1
        jr z,.set
.nt:    ld a,(ix+P_MOVED)
        or a
        ld a,FR_IDLE
        jr z,.set
        inc (ix+P_ANIM)
        ld a,(ix+P_ANIM)
        and 8
        ld a,FR_RUN1
        jr z,.set
        ld a,FR_RUN2
.set:   ld (ix+P_FRAME),a
        ret
anim_players:
        ld ix,pl0
        call anim_one
        ld ix,pl1
        jp anim_one

; ---------------------------------------------------------------------
; computer movement
ai_move:
        ld a,(pt_over)
        or a
        ret nz
        ld a,(ball_st)
        cp 2
        jr nz,.recover
        ld a,(ball_last)
        cp (ix+P_IDX)
        jr z,.recover
        ; incoming: wait out the reaction time, then run to the planned spot
        ld a,(ix+P_DLY)
        or a
        jr z,.go
        dec (ix+P_DLY)
        ret
.go:    ld b,(ix+P_TX)
        ld c,(ix+P_TY)
        jp move_toward
.recover:
        ; centre-ish, shading towards the opponent; baseline or net
        call other_iy
        ld a,(iy+P_X+1)         ; X/4
        sub 32
        sra a                   ; (X-128)/8
        add a,128
        ld b,a
        ld a,(ix+P_END)
        or a
        ld c,14
        ld a,(ix+P_APPR)
        jr nz,.nr
        or a
        jr z,.go2
        ld c,92
        jr .go2
.nr:    or a
        ld c,242
        jr z,.go2
        ld c,164
.go2:   jp move_toward

; IY = the other player
other_iy:
        ld iy,pl1
        ld a,(ix+P_IDX)
        or a
        ret z
        ld iy,pl0
        ret

; move IX toward B = X int, C = Y int at its speed
move_toward:
        push bc
        ld a,b
        call from_int
        ld e,(ix+P_X)
        ld d,(ix+P_X+1)
        or a
        sbc hl,de               ; HL = target - X
        ld c,(ix+P_SPD)
        ld b,(ix+P_SPD+1)
        call step_axis
        ld (ix+P_X),e
        ld (ix+P_X+1),d
        pop bc
        ld a,c
        call from_int
        ld e,(ix+P_Y)
        ld d,(ix+P_Y+1)
        or a
        sbc hl,de
        ld c,(ix+P_SPDY)
        ld b,(ix+P_SPDY+1)
        call step_axis
        ld (ix+P_Y),e
        ld (ix+P_Y+1),d
        ret
; DE = position, HL = delta, BC = speed -> DE = new position
step_axis:
        ld a,h
        or l
        ret z
        bit 7,h
        jr nz,.neg
        push hl
        or a
        sbc hl,bc
        pop hl
        jr c,.snap              ; delta < speed
        ex de,hl
        add hl,bc
        ex de,hl
        ld (ix+P_MOVED),1
        ret
.neg:   push hl
        add hl,bc
        pop hl
        jr c,.snap              ; |delta| <= speed
        ex de,hl
        or a
        sbc hl,bc
        ex de,hl
        ld (ix+P_MOVED),1
        ret
.snap:  ex de,hl
        add hl,de               ; new = old + delta
        ex de,hl
        ld (ix+P_MOVED),1
        ret

; ---------------------------------------------------------------------
; serving
serve_logic:
        ld a,(pt_over)
        or a
        ret nz
        ld a,(mode)
        cp MODE_PRACTICE
        jp z,practice_feed
        call server_ix
        ld a,(ball_st)
        or a
        jr nz,.toss
        call ball_to_hand
        call ctl_cpu
        jr z,.tim
        ld a,(ix+P_INPN)
        bit 4,a
        jr nz,.dotoss
.tim:   ld hl,srv_tim
        dec (hl)
        ret nz
.dotoss:
        ld a,1
        ld (ball_st),a
        ld hl,224
        ld (ball_vz),hl
        ld a,SFX_TOSS
        call play_sfx
        ; computer picks its strike height
        ld b,10
        call rand_n
        add a,30
        ld (srv_hitz),a
        ld (ix+P_FBUF),0
        ret
.toss:  ; ball in the air
        ld hl,(ball_z)
        ld de,(ball_vz)
        add hl,de
        ld (ball_z),hl
        ld hl,(ball_vz)
        ld de,-G_ACC
        add hl,de
        ld (ball_vz),hl
        call ctl_cpu
        jr z,.cpu
        ld a,(ix+P_INPN)
        bit 4,a
        jp nz,serve_hit
        jr .fall
.cpu:   ld hl,(ball_vz)
        bit 7,h
        jr z,.fall
        ld hl,(ball_z)
        call to_int
        ld b,a
        ld a,(srv_hitz)
        cp b
        jp nc,serve_hit
.fall:  ld hl,(ball_vz)
        bit 7,h
        ret z
        ld hl,(ball_z)
        ld de,-16*64
        add hl,de
        ret c
        ; caught it: toss again
        xor a
        ld (ball_st),a
        ld a,40
        ld (srv_tim),a
        ret

; serve_hit: IX = server, IY = receiver
serve_hit:
        ld hl,(ball_z)
        call to_int
        ld (tmpz),a
        ; flight time
        ld b,a
        call ctl_cpu
        jr z,.ct
        ld a,b
        srl a
        ld b,a
        ld a,46
        sub b                   ; 46 - z/2
        jr .tset
.ct:    ld a,(ix+P_SERV)
        srl a
        srl a
        srl a
        ld b,a
        ld a,40
        sub b
.tset:  ld b,a
        ld a,(servenum)
        or a
        ld a,b
        jr z,.t1
        add a,6
.t1:    cp 22
        jr nc,.t2
        ld a,22
.t2:    ld (shotT),a
        ; target: the diagonal service box
        ld a,(ix+P_X+1)
        cp 32                   ; X < 128 ?
        ld b,176
        jr c,.bx
        ld b,80
.bx:    ld a,(ix+P_END)
        or a
        ld c,170
        jr z,.by
        ld c,86
.by:    ; humans steer wide / down the T
        call ctl_cpu
        jr z,.cpu_aim
        ld a,(ix+P_INP)
        bit 0,a
        jr z,.s1
        ld a,b
        add a,30
        ld b,a
.s1:    ld a,(ix+P_INP)
        bit 1,a
        jr z,.s2
        ld a,b
        sub 30
        ld b,a
.s2:    ; error grows with a fast serve
        push bc
        ld a,(shotT)
        cp 28
        ld b,16
        jr c,.e1
        ld b,8
.e1:    ld a,(servenum)
        or a
        jr z,.e2
        ld b,6
.e2:    jr .err
.cpu_aim:
        push bc
        ld b,20
        call rand_spread
        pop bc
        add a,b
        ld b,a
        push bc
        ; deliberate fault chance
        ld a,(ix+P_FAULT)
        ld c,a
        ld a,(servenum)
        or a
        jr z,.f1
        srl c
        srl c
        srl c
.f1:    call random
        cp c
        ld b,8
        jr nc,.err
        ; push it long
        pop bc
        ld a,(ix+P_END)
        or a
        ld a,c
        jr nz,.fl
        add a,26
        jr .fl2
.fl:    sub 26
.fl2:   ld c,a
        push bc
        ld b,4
.err:   push bc
        call rand_spread
        pop bc
        ld e,a
        pop bc
        ld a,b
        add a,e
        ld b,a
        ld a,c
        add a,e
        ld c,a
        ld a,(shotT)
        call make_vel
        ld a,2
        ld (ball_st),a
        ld a,1
        ld (ball_serve),a
        xor a
        ld (ball_bnc),a
        ld (ball_cross),a
        ld (ball_cord),a
        ld a,(ix+P_IDX)
        ld (ball_last),a
        ld (ix+P_HITOK),0
        ld (iy+P_HITOK),1
        ld (ix+P_SWING),10
        ld (ix+P_SWFR),FR_SERVE2
        ld a,SFX_SERVE
        call play_sfx
        ; computer receiver plans its return
        push iy
        pop ix
        jp ai_plan

; ---------------------------------------------------------------------
; make_vel: B = target X int, C = target Y int, A = flight frames (T)
make_vel:
        ld (shotT),a
        ld a,b
        ld (land_x),a
        ld a,c
        ld (land_y),a
        push bc
        ld a,b
        call from_int
        ld de,(ball_x)
        or a
        sbc hl,de
        ld a,(shotT)
        call sdiv
        ld (ball_vx),hl
        pop bc
        ld a,c
        call from_int
        ld de,(ball_y)
        or a
        sbc hl,de
        ld a,(shotT)
        call sdiv
        ld (ball_vy),hl
        ; vz = g*T/2 - z/T = 8T - z/T
        ld hl,(ball_z)
        ld a,(shotT)
        call sdiv
        push hl
        ld a,(shotT)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        pop de
        or a
        sbc hl,de
        ld (ball_vz),hl
        ret

; ---------------------------------------------------------------------
; ball physics, net, bounces, in/out, hits
ball_update:
        ld a,(ball_st)
        cp 2
        ret c
        cp 4
        ret z
        ld hl,(ball_y)
        ld (prev_y),hl
        call ball_move
        ld a,(ball_st)
        cp 2
        jp nz,ball_bounce       ; dead ball: physics only
        ; net
        ld a,(ball_cross)
        or a
        jp nz,.nonet
        ld hl,(prev_y)
        ld de,YNET*64
        or a
        sbc hl,de
        ld a,h
        ld hl,(ball_y)
        or a
        sbc hl,de
        xor h
        jp p,.nonet             ; same side of the net
        ld a,1
        ld (ball_cross),a
        ld hl,(ball_z)
        ld de,NETH
        or a
        sbc hl,de
        jr nc,.nonet            ; cleared it
        ld hl,(ball_z)
        ld de,NETH-6*64
        or a
        sbc hl,de
        jr c,.netted
        ; net cord: it dribbles over
        ld a,1
        ld (ball_cord),a
        ld hl,(ball_vy)
        sra h
        rr l
        sra h
        rr l
        ld (ball_vy),hl
        ld hl,(ball_vx)
        sra h
        rr l
        ld (ball_vx),hl
        ld hl,80
        ld (ball_vz),hl
        ld a,SFX_CORD
        call play_sfx
        jr .nonet
.netted:
        ld a,1
        ld (ball_net),a
        ld hl,(ball_vy)
        call neghl
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld (ball_vy),hl
        ld hl,0
        ld (ball_vx),hl
        ld a,SFX_NET
        call play_sfx
        ld a,(mode)
        cp MODE_PRACTICE
        jr z,.prn
        ld a,(ball_serve)
        or a
        jp nz,do_fault
.prn:   call receiver_idx
        ld b,R_NET
        ld c,POP_NET
        jp point_won
.nonet: call ball_bounce
        ld a,(ball_st)
        cp 2
        ret nz
        ld a,(pt_over)
        or a
        ret nz
        ; hits
        ld a,(ball_cross)
        or a
        ret z
        ld a,(ball_net)
        or a
        ret nz
        call receiver_idx
        ld ix,pl0
        or a
        jr z,.r
        ld ix,pl1
.r:     jp try_hit

receiver_idx:   ; A = 1 - last hitter
        ld a,(ball_last)
        xor 1
        ret

; move the ball one frame (also used for dead balls); world bounds
ball_move:
        ld hl,(ball_x)
        ld de,(ball_vx)
        add hl,de
        ld (ball_x),hl
        ld hl,(ball_y)
        ld de,(ball_vy)
        add hl,de
        ld (ball_y),hl
        ld hl,(ball_z)
        ld de,(ball_vz)
        add hl,de
        ld (ball_z),hl
        ld hl,(ball_vz)
        ld de,-G_ACC
        add hl,de
        ld (ball_vz),hl
        ; out of the world?
        ld hl,(ball_y)
        bit 7,h
        jr nz,.gone
        ld a,h
        cp $40
        jr nc,.gone
        ld hl,(ball_x)
        bit 7,h
        jr nz,.gone
        ld a,h
        cp $40
        ret c
.gone:  ld a,4
        ld (ball_st),a          ; 4 = gone (not drawn)
        ld a,(pt_over)
        or a
        ret nz
        ; a ball that bounced in and flew away is a winner
        ld a,(ball_bnc)
        or a
        jr z,.long
        ld a,(ball_last)
        ld b,R_WINNER
        ld c,POP_WIN
        jp point_won
.long:  call receiver_idx
        ld b,R_OUT
        ld c,POP_OUT
        jp point_won

; dead-ball physics used while holding (ball rolls on)
ball_dead_phys:
        ld a,(ball_st)
        cp 3
        ret nz
        call ball_move
        jp ball_bounce

; bounce + line calls
ball_bounce:
        ld hl,(ball_z)
        bit 7,h
        ret z
        ld hl,(ball_vz)
        bit 7,h
        ret z
        ld hl,0
        ld (ball_z),hl
        ld hl,(ball_vz)
        call neghl
        ld a,(s_rest)
        call sfrac
        ld (ball_vz),hl
        ld hl,(ball_vx)
        ld a,(s_keep)
        call sfrac
        ld (ball_vx),hl
        ld hl,(ball_vy)
        ld a,(s_keep)
        call sfrac
        ld (ball_vy),hl
        ld hl,ball_bnc
        inc (hl)
        ; small bounces: stop bouncing
        ld hl,(ball_vz)
        ld de,-40
        add hl,de
        jr c,.big
        ld hl,0
        ld (ball_vz),hl
.big:   ld a,(ball_bnc)
        cp 3
        jr nc,.q
        call ball_screen
        ld a,b
        sub 2
        ld (puff_x),a
        ld a,c
        dec a
        ld (puff_y),a
        ld a,8
        ld (puff_tim),a
        ld a,SFX_BOUNCE
        call play_sfx
.q:     ld a,(ball_st)
        cp 2
        ret nz
        ld a,(pt_over)
        or a
        ret nz
        ld a,(ball_net)
        or a
        jr z,.live
        ; a netted ball: the point is already decided
        ret
.live:  ld a,(ball_bnc)
        cp 2
        jp z,.second
        cp 1
        ret nz
        ; first bounce: in or out?
        ld hl,(ball_x)
        call to_int
        ld b,a
        ld hl,(ball_y)
        call to_int
        ld c,a
        ld a,(mode)
        cp MODE_PRACTICE
        jp z,practice_bounce
        ld a,(ball_serve)
        or a
        jr nz,.servebox
        ; rally: inside the singles court on the far side of the hitter
        ld a,b
        cp XL-2
        jr c,.out
        cp XR+3
        jr nc,.out
        call hitter_far         ; Z if hitter is at the far end
        ld a,c
        jr z,.wantnear
        cp YFAR-2
        jr c,.out
        cp YNET
        jr nc,.out
        ret
.wantnear:
        cp YNET
        jr c,.out
        cp YNEAR+3
        jr nc,.out
        ret
.out:   call receiver_idx
        ld b,R_OUT
        ld c,POP_OUT
        call point_won
        jp show_flag
.servebox:
        call hitter_far
        ld a,c
        jr z,.sn
        cp YSF-2
        jr c,.fault
        cp YNET
        jr nc,.fault
        jr .sx
.sn:    cp YNET
        jr c,.fault
        cp YSN+3
        jr nc,.fault
.sx:    ; the box on the opposite side to the server
        ld a,(srv_x)            ; where the server stood (they may have moved since)
        cp 128
        ld a,b
        jr c,.right
        cp XL-2
        jr c,.fault
        cp XC+2
        jr nc,.fault
        jr .sok
.right: cp XC-1
        jr c,.fault
        cp XR+3
        jr nc,.fault
.sok:   ld a,(ball_cord)
        or a
        ret z
        ; touched the net and landed in: let
        ld a,R_LET
        ld (pt_reason),a
        ld a,50
        ld (pt_over),a
        ld a,POP_LET
        jp popup_ball
.fault: call show_flag
        jp do_fault
.second:
        ; two bounces: the hitter wins it
        ld a,(ball_last)
        ld b,R_WINNER
        ld c,POP_WIN
        ld e,a
        ld a,(ball_serve)
        or a
        ld a,e
        jr z,.pw
        ld b,R_ACE
        ld c,POP_ACE
.pw:    jp point_won

; Z if the last hitter is at the far end
hitter_far:
        push bc
        ld a,(ball_last)
        ld hl,pl0+P_END
        or a
        jr z,.p
        ld hl,pl1+P_END
.p:     ld a,(hl)
        or a
        pop bc
        ret

do_fault:
        ld a,(servenum)
        or a
        jr nz,.double
        inc a
        ld (servenum),a
        ld a,R_FAULT
        ld (pt_reason),a
        ld a,55
        ld (pt_over),a
        ld a,SFX_FAULT
        call play_sfx
        ld a,POP_FAULT
        jp popup_ball
.double:
        call receiver_idx
        ld b,R_DFAULT
        ld c,POP_DF
        jp point_won

; ---------------------------------------------------------------------
; try_hit: IX = the receiving player
try_hit:
        ld a,(ix+P_CTL)
        cp CTL_NONE
        ret z
        ld a,(ix+P_HITOK)
        or a
        ret z
        ld a,(ball_bnc)
        cp 2
        ret nc
        ld b,a
        ld a,(ball_serve)
        or a
        jr z,.ok1
        ld a,b                  ; a serve must bounce first
        or a
        ret z
.ok1:   ; along-court distance: positive while the ball is still on its way
        ld hl,(ball_y)
        call to_int
        ld c,a
        ld l,(ix+P_Y)
        ld h,(ix+P_Y+1)
        call to_int
        ld b,a                  ; B = player Y, C = ball Y
        ld a,(ix+P_END)
        or a
        ld a,b
        jr nz,.nearp
        ld a,c
        sub b                   ; far player: ball Y - player Y
        jr .dd
.nearp: sub c                   ; near player: player Y - ball Y
.dd:    ld (hit_d),a
        cp 9
        jr c,.inwin
        cp -6
        ret c
.inwin: ; across-court distance
        ld hl,(ball_x)
        call to_int
        ld c,a
        ld l,(ix+P_X)
        ld h,(ix+P_X+1)
        call to_int
        ld b,a
        ld a,c
        sub b
        ld (hit_dx),a           ; signed: ball X - player X
        jp pe,.far              ; overflow: way off
        call abs_a
        cp (ix+P_REACH)
        ret nc
        ; height
        ld hl,(ball_z)
        call to_int
        ld (tmpz),a
        cp 72
        ret nc
        jp make_shot
.far:   ret

; ---------------------------------------------------------------------
; make_shot: IX = hitter
; shot types: 0 normal, 1 power, 2 lob, 3 drop, 4 smash, 5 volley
shot_T:     db 44,31,66,40,20,36
shot_depth: db 30,16,14,92,28,40
make_shot:
        call other_iy
        ; near the net?  (|Y - 128| < 70)
        ld l,(ix+P_Y)
        ld h,(ix+P_Y+1)
        call to_int
        sub YNET
        call abs_a
        ld (tmpnet),a
        call ctl_cpu
        jr z,.cpu
        ; ---- human: fire = power, back = lob, forward = drop
        ld a,(ix+P_FBUF)
        or a
        jr z,.hn
        ld (ix+P_FBUF),0
        ld a,(tmpz)
        cp 34
        jr c,.hp
        ld a,(tmpnet)
        cp 70
        jr nc,.hp
        ld a,4
        jr .type
.hp:    ld a,1
        jr .type
.hn:    ld a,(ix+P_INP)
        ld b,a
        ld a,(ix+P_END)
        or a
        ld a,b
        jr z,.hfar
        ; near player: up = forward, down = back
        bit 3,a
        jr nz,.lob
        bit 2,a
        jr nz,.drop
        jr .norm
.hfar:  bit 2,a
        jr nz,.lob
        bit 3,a
        jr nz,.drop
        jr .norm
.lob:   ld a,2
        jr .type
.drop:  ld a,3
        jr .type
        ; ---- computer
.cpu:   ld a,(tmpz)
        cp 34
        jr c,.c1
        ld a,(tmpnet)
        cp 70
        jr nc,.c1
        ld a,4
        jr .type
.c1:    call random
        ld b,a
        ; lob more often when the opponent is at the net
        ld a,(ix+P_LOB)
        ld c,a
        ld a,(iy+P_APPR)
        or a
        jr z,.c2
        sla c
        jr nc,.c2
        ld c,255
.c2:    ld a,c
        srl a                   ; lob chance is per 512
        ld c,a
        ld a,b
        cp c
        jr c,.lob
        call random
        cp (ix+P_POW)
        ld a,1
        jr c,.type
.norm:  xor a
.type:  ; volley: a normal shot taken before the bounce near the net
        or a
        jr nz,.t2
        ld a,(ball_bnc)
        or a
        jr nz,.t1
        ld a,(tmpnet)
        cp 80
        ld a,5
        jr c,.t2
.t1:    xor a
.t2:    ld (shottype),a
        ; flight time + depth
        ld hl,shot_T
        call idx_byte
        ld b,a
        ld a,(ix+P_FIRE)
        or a
        jr z,.nf
        ld a,(shottype)
        cp 1
        jr nz,.nf
        ld a,b
        sub 7                   ; on fire: blistering
        ld b,a
        ld a,1
        ld (ball_fire),a
        jr .tf
.nf:    xor a
        ld (ball_fire),a
.tf:    ld a,b
        ld (shotT),a
        ld a,(shottype)
        ld hl,shot_depth
        call idx_byte
        ld c,a
        ld a,(ix+P_END)
        or a
        jr nz,.tyfar
        ld a,YNEAR
        sub c
        ld c,a
        jr .tx
.tyfar: ld a,YFAR
        add a,c
        ld c,a
.tx:    ; across
        call ctl_cpu
        jr z,.cpux
        ; human: contact point sets the angle (as in the original), stick steers
        ld a,(hit_dx)
        ld b,a
        add a,a
        add a,b                 ; 3*dx
        neg
        add a,128
        ld b,a
        ld a,(ix+P_INP)
        bit 0,a
        jr z,.h1
        ld a,b
        add a,52
        jr nc,.h0
        ld a,250
.h0:    ld b,a
.h1:    ld a,(ix+P_INP)
        bit 1,a
        jr z,.h2
        ld a,b
        sub 52
        jr nc,.h3
        xor a
.h3:    ld b,a
.h2:    ; error: worse when the timing is off, or going for power
        ld a,(hit_d)
        call abs_a
        add a,a
        add a,5
        ld e,a
        ld a,(shottype)
        cp 1
        jr nz,.h4
        ld a,e
        add a,8
        ld e,a
.h4:    ld a,(ix+P_FIRE)
        or a
        jr z,.herr
        ld e,4
        jr .herr
.cpux:  ; away from the opponent, with a little variety
        ld a,(iy+P_X+1)
        cp 32
        ld b,84
        jr nc,.cx1
        ld b,172
.cx1:   push bc
        ld b,48
        call rand_spread
        pop bc
        add a,b
        ld b,a
        ld a,(ix+P_ACC)
        ld e,a
        ld a,(shottype)
        cp 1
        jr nz,.herr
        ld a,e
        add a,8
        ld e,a
.herr:  ; apply error to X and Y
        push bc
        ld b,e
        call rand_spread
        pop bc
        ld d,a
        ld a,b
        add a,d
        ; clamp X 4..252 (no wrap-around)
        bit 7,d
        jr nz,.xneg
        jr nc,.xok
        ld a,252
        jr .xok
.xneg:  jr c,.xok
        ld a,4
.xok:   cp 4
        jr nc,.xk2
        ld a,4
.xk2:   cp 253
        jr c,.xk3
        ld a,252
.xk3:   ld b,a
        push bc
        ld b,e
        call rand_spread
        pop bc
        sra a
        add a,c
        ld c,a
        ; keep the target on the other side of the net
        ld a,(ix+P_END)
        or a
        ld a,c
        jr nz,.cyf
        cp YNET+8
        jr nc,.cy2
        ld c,YNET+8
        jr .cy2
.cyf:   cp YNET-8
        jr c,.cy2
        ld c,YNET-8
.cy2:   ld a,(shotT)
        push bc
        call make_vel
        pop bc
        ; a badly timed human shot comes off the frame low
        call ctl_cpu
        jr z,.nl
        ld a,(hit_d)
        call abs_a
        cp 6
        jr c,.nl
        ld hl,(ball_vz)
        ld a,180
        call sfrac
        ld (ball_vz),hl
.nl:    ; bookkeeping
        ld a,(ix+P_IDX)
        ld (ball_last),a
        xor a
        ld (ball_bnc),a
        ld (ball_cross),a
        ld (ball_serve),a
        ld (ball_cord),a
        ld (ix+P_HITOK),0
        ld (iy+P_HITOK),1
        ld hl,rally
        inc (hl)
        ld (ix+P_SWING),9
        ld a,(hit_dx)
        or a
        ld a,FR_FORE
        jp p,.sw
        ld a,FR_BACK
.sw:    ld (ix+P_SWFR),a
        ; sound
        ld a,(shottype)
        cp 4
        jr nz,.snd
        ld a,SFX_SMASH
        call play_sfx
        ld a,POP_SMASH
        call popup_ball
        jr .snd2
.snd:   cp 1
        ld a,SFX_HIT
        jr nz,.snd1
        ld a,SFX_POWER
.snd1:  call play_sfx
.snd2:  ; computer hitter may follow it in to the net
        ld (ix+P_APPR),0
        call ctl_cpu
        jr nz,.plan
        ld a,(shottype)
        cp 2
        jr z,.plan
        call random
        cp (ix+P_NET)
        jr nc,.plan
        ld (ix+P_APPR),1
.plan:  push iy
        pop ix
        ; fall through to plan the receiver's run

; ai_plan: IX = computer receiver; work out where to meet the ball
ai_plan:
        call ctl_cpu
        ret nz
        ld a,(ix+P_REACT)
        ld (ix+P_DLY),a
        ; intercept line: home baseline, or the net if approaching
        ld a,(ix+P_END)
        or a
        ld c,16
        jr z,.e0
        ld c,240
.e0:    ld a,(ix+P_APPR)
        or a
        jr z,.e1
        ld a,(ix+P_END)
        or a
        ld c,96
        jr z,.e1
        ld c,160
.e1:    ; a short ball: come in to meet it after the bounce
        ld a,(land_y)
        ld b,a
        ld a,(ix+P_END)
        or a
        jr nz,.sn
        ld a,b
        sub 24
        jr c,.sk
        cp c
        jr c,.sk
        ld c,a                  ; meet it closer to the net
        jr .sk
.sn:    ld a,b
        add a,24
        jr c,.sk
        cp c
        jr nc,.sk
        ld c,a
.sk:    ld a,c
        ld (ix+P_TY),a
        ; X where the ball's path crosses that line:
        ; X = land_x + (Yi - land_y) * (land_x - bx) / (land_y - by)
        ld hl,(ball_x)
        call to_int
        ld b,a
        ld a,(land_x)
        sub b
        ld e,a
        ld a,0
        sbc a,0
        ld d,a                  ; DE = dxl (signed 16)
        ld hl,(ball_y)
        call to_int
        ld b,a
        ld c,0                  ; sign count
        ld a,(land_y)
        sub b
        jr nc,.dyp
        neg
        inc c
.dyp:   or a
        jr nz,.dy
        inc a
.dy:    ld (tmp_dy),a
        ld a,(land_y)
        ld b,a
        ld a,(ix+P_TY)
        sub b
        jr nc,.kp
        neg
        inc c
.kp:    or a
        jr z,.zero
        ld h,a
        bit 7,d
        jr z,.k2
        inc c
        ld a,e
        neg
        ld e,a
.k2:    push bc
        call umul8              ; HL = |k| * |dxl|
        pop bc
        ld a,(tmp_dy)
.k3:    push bc
        ld c,a
        call udiv16
        pop bc
        bit 0,c
        call nz,neghl
        ld a,(land_x)
        ld e,a
        ld d,0
        add hl,de
        ; clamp 16..240
        bit 7,h
        jr nz,.lo
        ld a,h
        or a
        jr nz,.hi
        ld a,l
        cp 16
        jr c,.lo
        cp 241
        jr nc,.hi
        jr .xok
.zero:  ld a,(land_x)
        jr .xok
.lo:    ld a,16
        jr .xok
.hi:    ld a,240
.xok:   ld b,a
        ; an imperfect read of the ball
        push bc
        ld a,(ix+P_ACC)
        srl a
        ld b,a
        call rand_spread
        pop bc
        add a,b
        ld (ix+P_TX),a
        ret

; ---------------------------------------------------------------------
; point_won: A = winner index, B = reason, C = popup
point_won:
        ld e,a
        ld a,(pt_over)
        or a
        ret nz
        ld hl,dbg_why           ; statistics for the soak tests (reason counts)
        ld a,l
        add a,b
        ld l,a
        jr nc,.dn
        inc h
.dn:    inc (hl)
        ld a,e
        ld (pt_win),a
        ld a,b
        ld (pt_reason),a
        ld a,3
        ld (ball_st),a
        ld a,70
        ld (pt_over),a
        ld a,c
        call popup_ball
        ld a,(mode)
        cp MODE_PRACTICE
        ret z
        ; poses
        ld a,(pt_win)
        ld ix,pl0
        ld iy,pl1
        or a
        jr z,.w
        ld ix,pl1
        ld iy,pl0
.w:     ld (ix+P_POSE),FR_JOY
        ld (iy+P_POSE),FR_SAD
        ld (iy+P_STREAK),0
        ld (iy+P_FIRE),0
        ; crowd + streaks on aces and winners
        ld a,(pt_reason)
        cp R_ACE
        jr z,.great
        cp R_WINNER
        jr nz,.plain
.great: ld a,32
        call crowd_cheer
        ld a,SFX_CROWD
        call play_sfx
        call ctl_cpu
        jr z,.plain
        inc (ix+P_STREAK)
        ld a,(ix+P_STREAK)
        cp 3
        jr nz,.tp
        ld (ix+P_FIRE),1
        ld a,POP_FIRE
        call popup_ball
        ld hl,mus_fire_0
        ld de,mus_fire_1
        call jingle
.tp:    ; tour points for great shots
        ld de,$0025
        ld a,(pt_reason)
        cp R_WINNER
        jr z,.ap
        ld de,$0050
.ap:    call add_tourpts
        ret
.plain: ld a,(ix+P_CTL)
        cp CTL_CPU
        ret z
        ld de,$0010
        jp add_tourpts

; add BCD DE to the tour points (tour mode only)
add_tourpts:
        ld a,(mode)
        cp MODE_TOUR
        ret nz
        ld hl,tourpts+2
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ret

; jingle: play HL/DE unless the sound is off
jingle:
        ld a,(soundmode)
        or a
        ret z
        jp play_music

; ---------------------------------------------------------------------
; scoring
; award_point: A = winner index
award_point:
        ld (aw),a
        xor 1
        ld (al),a
        ld a,(tiebreak)
        or a
        jp nz,.tb
        ld hl,pts
        ld a,(aw)
        call idx_ptr
        inc (hl)
        ; normalise deuce: both >= 4 -> both - 1
        ld a,(pts)
        cp 4
        jr c,.nn
        ld a,(pts+1)
        cp 4
        jr c,.nn
        ld hl,pts
        dec (hl)
        inc hl
        dec (hl)
.nn:    ld hl,pts
        ld a,(aw)
        call idx_byte
        cp 4
        jr c,.call
        ld b,a
        ld hl,pts
        ld a,(al)
        call idx_byte
        ld c,a
        ld a,b
        sub c
        cp 2
        jp nc,game_won
.call:  call hud_draw
        ld hl,mus_point_0
        ld de,mus_point_1
        call jingle
        call make_call
        jp show_call
.tb:    ld hl,pts
        ld a,(aw)
        call idx_ptr
        inc (hl)
        ld a,(hl)
        ld b,a
        ld a,(tbtarget)
        ld c,a
        ld a,b
        cp c
        jr c,.tbc
        ld hl,pts
        ld a,(al)
        call idx_byte
        ld c,a
        ld a,b
        sub c
        cp 2
        jp nc,game_won
.tbc:   ; server changes after the first point, then every two
        ld a,(pts)
        ld b,a
        ld a,(pts+1)
        add a,b
        and 1
        jr z,.ns
        ld a,(server)
        xor 1
        ld (server),a
.ns:    ; change ends every six points
        ld a,(pts)
        ld b,a
        ld a,(pts+1)
        add a,b
        ld c,a
.m6:    sub 6
        jr z,.ch
        jr nc,.m6
        jr .call
.ch:    call .call
        jp change_ends

idx_ptr:        ; HL += A
        add a,l
        ld l,a
        ret nc
        inc h
        ret

game_won:
        xor a
        ld (pts),a
        ld (pts+1),a
        ld (servenum),a
        ld hl,games
        ld a,(aw)
        call idx_ptr
        inc (hl)
        ld a,(tiebreak)
        or a
        jp nz,set_won
        ; set won?
        ld hl,games
        ld a,(aw)
        call idx_byte
        ld b,a
        ld hl,games
        ld a,(al)
        call idx_byte
        ld c,a
        ld a,(gamesper)
        ld d,a
        ld a,b
        cp d
        jr c,.noset
        sub c
        cp 2
        jr nc,set_won
        ; tie-break at n-n
        ld a,b
        cp d
        jr nz,.noset
        ld a,c
        cp d
        jr nz,.noset
        ld a,1
        ld (tiebreak),a
        ld a,d
        cp 6
        ld a,7
        jr z,.tt
        ld a,5
.tt:    ld (tbtarget),a
.noset: ld a,(server)
        xor 1
        ld (server),a
        call hud_draw
        call game_banner
        ; change ends after odd games
        ld a,(games)
        ld b,a
        ld a,(games+1)
        add a,b
        and 1
        ret z
        jp change_ends

game_banner:
        call aw_ix
        ld hl,mus_game_0
        ld de,mus_game_1
        call jingle
        ld hl,s_game
        call str_name           ; tbuf = "GAME " + name
        ld a,(tiebreak)
        or a
        ld de,s_tbreak
        jr nz,.b
        call games_line         ; DE = "GAMES n-m"
.b:     ld hl,tbuf
        call banner
        ld b,80
        call hold
        jp court_restore

set_won:
        xor a
        ld (tiebreak),a
        ld hl,sets
        ld a,(aw)
        call idx_ptr
        inc (hl)
        ld a,(games)
        ld b,a
        ld a,(games+1)
        add a,b
        ld (lastsetg),a
        ld a,(server)
        xor 1
        ld (server),a
        ld hl,sets
        ld a,(aw)
        call idx_byte
        ld b,a
        ld a,(setsneed)
        cp b
        jr z,match_won
        ; set banner
        ld de,$0500
        call aw_human_pts
        call aw_ix
        ld hl,mus_set_0
        ld de,mus_set_1
        call jingle
        ld hl,s_set
        call str_name
        call sets_line
        ld hl,tbuf
        call banner
        xor a
        ld (games),a
        ld (games+1),a
        call hud_draw
        ld b,110
        call hold
        call court_restore
        ld a,(lastsetg)
        and 1
        ret z
        jp change_ends

match_won:
        ld a,(aw)
        ld (match_win),a
        ld a,1
        ld (match_over),a
        call hud_draw
        call aw_ix
        ld (ix+P_POSE),FR_JOY
        ld hl,mus_match_0
        ld de,mus_match_1
        call jingle
        ld hl,s_gsm
        ld e,(ix+P_LNAME)
        ld d,(ix+P_LNAME+1)
        call banner
        ld a,60
        call crowd_cheer
        ld b,150
        jp hold

; tour points for the human set winner: DE = BCD
aw_human_pts:
        call aw_ix
        ld a,(ix+P_CTL)
        cp CTL_CPU
        ret z
        jp add_tourpts

aw_ix:  ld ix,pl0
        ld a,(aw)
        or a
        ret z
        ld ix,pl1
        ret

; tbuf = string HL + IX's long name
str_name:
        ld de,tbuf
.c:     ld a,(hl)
        or a
        jr z,.n
        ld (de),a
        inc hl
        inc de
        jr .c
.n:     ld l,(ix+P_LNAME)
        ld h,(ix+P_LNAME+1)
.c2:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.c2
        ret

; DE = "GAMES a-b" (winner first) in tbuf2
games_line:
        ld hl,games
        jr score_line
sets_line:
        ld hl,sets
score_line:
        push hl
        ld hl,s_gamesw
        ld a,(hl)
        ld de,tbuf2
        ld bc,6
        ldir
        pop hl
        push hl
        ld a,(aw)
        call idx_byte
        add a,'0'
        ld (de),a
        inc de
        ld a,'-'
        ld (de),a
        inc de
        pop hl
        ld a,(al)
        call idx_byte
        add a,'0'
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld de,tbuf2
        ret
s_gamesw: db "SCORE "
s_game:   db "GAME ",0
s_set:    db "SET ",0
s_gsm:    db "GAME SET AND MATCH",0
s_tbreak: db "TIE-BREAK WON",0

; ---------------------------------------------------------------------
; umpire call: tbuf = score words (server first), tbuf2 = pressure line
make_call:
        ld a,(server)
        ld hl,pts
        call idx_byte
        ld (cs),a
        ld a,(server)
        xor 1
        ld hl,pts
        call idx_byte
        ld (cr),a
        ld de,tbuf
        ld a,(tiebreak)
        or a
        jr nz,.tb
        ld a,(cs)
        cp 3
        jr c,.words
        ld a,(cr)
        cp 3
        jr c,.words
        ld a,(cs)
        ld b,a
        ld a,(cr)
        cp b
        jr nz,.adv
        ld hl,s_deuce
        call strcpy
        jr .press
.adv:   ; the leader: server if cs > cr
        ld a,(server)
        jr c,.al
        xor 1
.al:    call ix_of
        ld hl,s_advant
        call strcpy
        ld l,(ix+P_LNAME)
        ld h,(ix+P_LNAME+1)
        call strcpy
        jr .press
.words: ld a,(cs)
        ld b,a
        ld a,(cr)
        cp b
        jr z,.all
        ld a,(cs)
        call word_de
        ld a,'-'
        ld (de),a
        inc de
        ld a,(cr)
        call word_de
        xor a
        ld (de),a
        jr .press
.all:   ld a,(cs)
        call word_de
        ld hl,s_all
        call strcpy
        jr .press
.tb:    ld hl,s_tb
        call strcpy
        ld a,(cs)
        call num_de
        ld a,'-'
        ld (de),a
        inc de
        ld a,(cr)
        call num_de
        xor a
        ld (de),a
.press: ld hl,0
        ld (callline2),hl
        xor a
        call press_for
        ld a,1
        jp press_for

ix_of:  ld ix,pl0
        or a
        ret z
        ld ix,pl1
        ret

; strcpy HL -> DE; DE is left on the terminating 0
strcpy:
        ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        jr strcpy

; word_de: A = 0..3 -> word copied to DE (no terminator), DE advanced
word_de:
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,wordtab
        add hl,de
        pop de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
.c:     ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr .c
wordtab: dw w0,w1,w2,w3
w0: db "LOVE",0
w1: db "FIFTEEN",0
w2: db "THIRTY",0
w3: db "FORTY",0
s_all:    db " ALL",0
s_deuce:  db "DEUCE",0
s_advant: db "ADVANTAGE ",0
s_tb:     db "TIE-BREAK ",0

; num_de: A (0..99) as decimal at DE, DE advanced
num_de:
        cp 10
        jr c,.one
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10
        push af
        ld a,b
        ld (de),a
        inc de
        pop af
.one:   add a,'0'
        ld (de),a
        inc de
        ret

; press_for: A = player. One point from the game -> BREAK / SET / MATCH POINT
press_for:
        ld (pf),a
        ld b,a
        xor 1
        ld hl,pts
        call idx_byte
        ld c,a                  ; opponent's points
        ld a,b
        ld hl,pts
        call idx_byte           ; mine
        ld b,a
        ld a,(tiebreak)
        or a
        jr z,.reg
        ld a,(tbtarget)
        dec a
        cp b
        jr z,.tbx
        ret nc                  ; not at target-1 or above
.tbx:   ld a,b
        cp c
        ret c
        ret z
        jr .gamept              ; a tie-break point is always a set point
.reg:   ld a,b
        cp 3
        ret c
        cp c
        ret c
        ret z
        ; game point: would it win the set?
        ld hl,games
        ld a,(pf)
        call idx_byte
        inc a
        ld b,a
        ld a,(pf)
        xor 1
        ld hl,games
        call idx_byte
        ld c,a
        ld a,(gamesper)
        ld d,a
        ld a,b
        cp d
        jr c,.break
        sub c
        cp 2
        jr c,.break
.gamept:
        ld hl,sets
        ld a,(pf)
        call idx_byte
        inc a
        ld b,a
        ld a,(setsneed)
        cp b
        ld hl,s_matchpt
        jr z,.set
        ld hl,s_setpt
.set:   ld (callline2),hl
        ret
.break: ld a,(server)
        ld b,a
        ld a,(pf)
        cp b
        ret z
        ld hl,s_breakpt
        ld (callline2),hl
        ret
s_breakpt: db "BREAK POINT",0
s_setpt:   db "SET POINT",0
s_matchpt: db "MATCH POINT",0

show_call:
        ld hl,tbuf
        ld de,(callline2)
        call banner
        ld b,55
        call hold
        jp court_restore

; ---------------------------------------------------------------------
change_ends:
        ld a,(pl0+P_END)
        xor 1
        ld (pl0+P_END),a
        ld a,(pl1+P_END)
        xor 1
        ld (pl1+P_END),a
        call sprites_for_ends
        ld hl,mus_change_0
        ld de,mus_change_1
        call jingle
        ld hl,s_change
        ld de,0
        call banner
        ; walk-off: just swap; positions are reset by serve_setup
        call serve_setup
        ld b,60
        call hold
        jp court_restore
s_change: db "CHANGE ENDS",0

; ---------------------------------------------------------------------
; effects: popups, line judge flag, bounce puff
popup_ball:     ; A = popup index, drawn into the backdrop near the ball
        push af
        call popup_clear
        call ball_screen
        pop af
        ld (pop_idx),a
        add a,a
        ld l,a
        ld h,0
        ld de,popstr
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (pop_str),hl
        ld e,0
.len:   ld a,(hl)
        or a
        jr z,.l2
        inc e
        inc hl
        jr .len
.l2:    ld a,e
        ld (pop_w),a
        ; column: centred on the ball, kept on the court
        ld a,b
        srl a
        srl a
        srl e
        sub e
        jr nc,.x0
        xor a
.x0:    cp 6
        jr nc,.x1
        ld a,6
.x1:    ld e,a
        ld a,(pop_w)
        add a,e
        cp 33
        jr c,.x2
        ld a,32
        ld hl,pop_w
        sub (hl)
        ld e,a
.x2:    ld a,e
        ld (pop_x),a
        ld a,c
        sub 10
        jr nc,.y0
        xor a
.y0:    cp 6
        jr nc,.y1
        ld a,6
.y1:    cp 50
        jr c,.y2
        ld a,50
.y2:    ld (pop_y),a
        ; save what is underneath
        ld a,(pop_x)
        ld d,a
        ld a,(pop_y)
        ld e,a
        call scraddr
        ld a,h
        or $88
        ld h,a
        ld de,popsave
        ld b,5
.sv:    push bc
        push hl
        ld a,(pop_w)
        ld c,a
        ld b,0
        ldir
        pop hl
        ld bc,32
        add hl,bc
        pop bc
        djnz .sv
        ; print it
        ld a,(s_bgmap)
        ld b,a
        ld a,(s_bgmap+1)
        call set_ink
        ld hl,(pop_str)
        ld a,(pop_x)
        ld d,a
        ld a,(pop_y)
        ld e,a
        call print
        ld a,1
        ld (pop_on),a
        ld a,45
        ld (pop_tim),a
        ret

; take the popup off the backdrop again
popup_clear:
        ld a,(pop_on)
        or a
        ret z
        xor a
        ld (pop_on),a
        ld (pop_tim),a
        ld a,(pop_x)
        ld d,a
        ld a,(pop_y)
        ld e,a
        push de
        call scraddr
        ld a,h
        or $88
        ld h,a
        ex de,hl
        ld hl,popsave
        ld b,5
.r:     push bc
        push de
        ld a,(pop_w)
        ld c,a
        ld b,0
        ldir
        pop de
        ex de,hl
        ld bc,32
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
        pop de
        ld a,(pop_w)
        ld b,a
        ld c,5
        jp queue_rect

show_flag:
        call ball_screen
        ld a,b
        cp 75
        ld a,26
        jr c,.l
        ld a,116
.l:     ld (flag_x),a
        ld a,c
        sub 4
        jr nc,.y
        xor a
.y:     ld (flag_y),a
        ld a,50
        ld (flag_tim),a
        ld a,SFX_OUT
        jp play_sfx

fx_update:
        ld hl,pop_tim
        ld a,(hl)
        or a
        jr z,.p
        dec (hl)
        call z,popup_clear
.p:     ld hl,flag_tim
        ld a,(hl)
        or a
        jr z,.f
        dec (hl)
.f:     ld hl,puff_tim
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret

; ball screen position: B = x, C = ground y (shadow)
ball_screen:
        ld hl,(ball_x)
        call to_int
        ld b,a
        push bc
        ld hl,(ball_y)
        call to_int
        pop bc
        ld c,a
        jp proj

; ---------------------------------------------------------------------
; build the draw list
match_draw:
        call dl_reset
        ; bounce puff
        ld a,(puff_tim)
        or a
        jr z,.np
        and 4
        ld a,SPR_PUFF2
        jr z,.p2
        ld a,SPR_PUFF1
.p2:    ld hl,(puff_x)
        ld b,l
        ld c,h
        call spr_put
.np:    ; practice extras
        ld a,(mode)
        cp MODE_PRACTICE
        call z,practice_draw
        ; shadow
        ld a,(ball_st)
        cp 4
        jr z,.nob
        call ball_screen
        ld (bscr),bc
        dec b
        ld a,(ball_st)
        or a
        jr z,.nosh
        ld a,SPR_SHADOW
        call spr_put
.nosh:
.nob:   ; players: far end first
        call top_player
        push iy
        call draw_player
        pop ix
        call draw_player
        ; ball
        ld a,(ball_st)
        cp 4
        jr z,.nb
        ld bc,(bscr)
        ld hl,(ball_z)
        bit 7,h
        jr nz,.gz
        ld a,c
        sub h                   ; z/4 pixels (z is 10.6)
        jr c,.nb                ; above the top of the screen
        ld c,a
.gz:    dec b
        dec c
        ld a,(ball_fire)
        or a
        jr z,.nfire
        ld a,(ball_st)
        cp 2
        jr nz,.nfire
        push bc
        ld a,(framecount)
        and 2
        ld a,SPR_FIRE1
        jr z,.f1
        ld a,SPR_FIRE2
.f1:    dec b
        dec c
        call spr_put
        pop bc
.nfire: ld a,SPR_BALL
        call spr_put
.nb:    ; line judge flag
        ld a,(flag_tim)
        or a
        jr z,.nfl
        ld hl,(flag_x)
        ld b,l
        ld c,h
        ld a,SPR_FLAG
        call spr_put
.nfl:   ret

draw_player:    ; IX
        ld a,(ix+P_CTL)
        cp CTL_NONE
        ret z
        ld l,(ix+P_X)
        ld h,(ix+P_X+1)
        call to_int
        ld b,a
        push bc
        ld l,(ix+P_Y)
        ld h,(ix+P_Y+1)
        call to_int
        pop bc
        ld c,a
        call proj
        ld a,b
        sub 4
        jr nc,.x0
        xor a
.x0:    cp 20
        jr nc,.x1
        ld a,20
.x1:    ld b,a
        ld a,c
        sub 9
        jr nc,.y0
        xor a
.y0:    ld c,a
        ; sprite id: end + frame (the sets are coloured for whoever is at each end)
        ld a,(ix+P_END)
        or a
        ld d,SPR_F
        jr z,.e
        ld d,SPR_N
.e:     ld a,(ix+P_FRAME)
        add a,d
        jp spr_put
