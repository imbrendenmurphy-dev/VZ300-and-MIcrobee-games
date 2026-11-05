; =====================================================================
;  CIRCUS 2 - data: acts, text, music, sound effects
; =====================================================================

; ---------------------------------------------------------------------
; ACTS.  db css, bg ; db nrows, flags ; dw name, hint
;   rows: db y ; dw speed(8.8 px/substep, signed) ; dw slots, gift, bomb, steel
;         db sprite (0 yellow, 1 blue, 2 red)
; ---------------------------------------------------------------------
acttab: dw act1,act2,act3,act4,act5,act6,act7,act8,act9

act1:   db 0,0, 3,0
        dw n_act1,h_act1
        db 2
        dw 44, $7777, 0, 0, 0
        db 0
        db 8
        dw -36, $7777, 0, 0, 0
        db 1
        db 14
        dw 30, $7777, 0, 0, 0
        db 2

act2:   db 1,0, 3,0
        dw n_act2,h_act2
        db 2
        dw 52, $EEEE, $0200, 0, 0
        db 2
        db 8
        dw -44, $EEEE, $0020, 0, 0
        db 1
        db 14
        dw 36, $EEEE, $2002, 0, 0
        db 0

act3:   db 0,2, 3,AF_MONKEY
        dw n_act3,h_act3
        db 2
        dw -56, $F7F7, $0010, 0, 0
        db 0
        db 8
        dw 48, $7F7F, 0, 0, 0
        db 1
        db 14
        dw -40, $F7F7, $1000, 0, 0
        db 2

act4:   db 1,1, 0,AF_BONUS
        dw n_act4,h_act4

act5:   db 1,2, 3,AF_HOOP
        dw n_act5,h_act5
        db 2
        dw 60, $FFFF, 0, 0, $1111
        db 1
        db 8
        dw -52, $EEEE, $0202, 0, 0
        db 0
        db 14
        dw 44, $FFFF, 0, 0, $8080
        db 2

act6:   db 0,3, 4,0
        dw n_act6,h_act6
        db 2
        dw 68, $7777, 0, $0404, $1010
        db 0
        db 8
        dw -60, $EEEE, $0040, $2000, 0
        db 1
        db 14
        dw 52, $7777, 0, $0202, 0
        db 2
        db 20
        dw -44, $EEEE, $0400, $0020, $8000
        db 0

act7:   db 0,2, 3,AF_MONKEY|AF_HOOP|AF_BOB
        dw n_act7,h_act7
        db 3
        dw 64, $FFFF, $0101, 0, $1010
        db 2
        db 9
        dw -58, $FFFF, 0, $0808, 0
        db 0
        db 15
        dw 50, $FFFF, $1000, 0, 0
        db 1

act8:   db 1,3, 0,AF_BONUS|AF_PRIZE
        dw n_act8,h_act8

act9:   db 1,0, 4,AF_MONKEY|AF_HOOP|AF_BOB
        dw n_act9,h_act9
        db 3
        dw 76, $FFFF, $0100, $0404, $2020
        db 2
        db 9
        dw -70, $FFFF, $1000, $0040, $0101
        db 1
        db 15
        dw 62, $FFFF, $0010, $4000, 0
        db 0
        db 21
        dw -54, $FFFF, $0001, $0200, $1000
        db 2

n_act1: db "OPENING NIGHT",0
h_act1: db "LAND ON THE TIP: FLY HIGH",0
n_act2: db "GIFTS GALORE",0
h_act2: db "STRIPY ONES HIDE PRIZES",0
n_act3: db "MONKEY BUSINESS",0
h_act3: db "DODGE THE CUSTARD PIES!",0
n_act4: db "BALLOON BONANZA",0
h_act4: db "POP ALL YOU CAN!",0
n_act5: db "RING OF FIRE",0
h_act5: db "FLY THROUGH THE HOOP!",0
n_act6: db "BOMBS AWAY",0
h_act6: db "BOMBS POP NEIGHBOURS",0
n_act7: db "THE NIGHT SHOW",0
h_act7: db "EVERYTHING AT ONCE!",0
n_act8: db "PRIZE POP",0
h_act8: db "GRAB THE GIFTS AND GOLD",0
n_act9: db "GRAND FINALE",0
h_act9: db "THE GREATEST SHOW!",0

; ---------------------------------------------------------------------
; text
; ---------------------------------------------------------------------
txt_act:        db "ACT ",0
txt_demo:       db "DEMO - PRESS ANY KEY",0
txt_bonusround: db "BONUS",0
txt_encore:     db "s ENCORE! s",0
txt_time:       db "TIME ",0
txt_boing:      db "BOING!",0
txt_ouch:       db "OUCH!",0
txt_bonk:       db "BONK!",0
txt_perfect:    db "PERFECT!",0
txt_streak:     db "STREAK ",0
txt_clang:      db "CLANG",0
txt_rowclear:   db "ROW CLEAR!",0
txt_extralife:  db "EXTRA LIFE!",0
txt_hot:        db "HOT!",0
txt_hoop:       db "HOOP!",0
txt_splat:      db "SPLAT!",0
txt_pied:       db "PIED!",0
txt_ook:        db "OOK OOK!",0
txt_wide:       db "WIDE!",0
txt_slow:       db "SLOW-MO",0
txt_net:        db "SAFETY NET",0
txt_x2:         db "DOUBLE!",0
txt_umb:        db "UMBRELLA",0
txt_fire:       db "FIREWORKS",0
txt_1up:        db "1UP!",0
txt_hudnet:     db "N",0
txt_paused:     db "PAUSED",0
txt_pausehelp:  db "P PLAY  S SOUND  Q QUIT",0
txt_actclear:   db "BRAVO!",0
txt_bonusdone:  db "TIME UP!",0
txt_nomiss:     db "NO FALLS +5000",0
txt_popped:     db "POPPED ",0
txt_gameover:   db "GAME OVER",0
txt_gameover2:  db "THE CLOWNS NEED A NAP",0
txt_press:      db "rr PRESS ANY KEY ll",0
txt_credit:     db "VIBED BY BPM 2026",0
txt_tkeys:      db "Z/X MOVE  SPACE FLIP",0
txt_sound:      db "S SOUND: ",0
txt_on:         db "ON",0
txt_off:        db "OFF",0
txt_diff:       db "D LEVEL: ",0
txt_easy:       db "EASY",0
txt_normal:     db "NORMAL",0
txt_hard:       db "HARD",0
txt_hi:         db "HI ",0
txt_howto:      db "HOW TO PLAY",0
howto_lines:
        db "SLIDE THE SEESAW: Z/X OR M/,",0
        db "SPACE OR FIRE FLIPS IT",0
        db "CATCH CLOWNS ON THE HIGH END",0
        db "LAND ON THE TIP: SUPER JUMP!",0
        db "POP EVERY BALLOON TO WIN",0
        db "P PAUSE   JOYSTICK WORKS TOO",0
        db 0
txt_powerups:   db "GOODIES",0
txt_lg_wide:    db "WIDE SEESAW",0
txt_lg_slow:    db "SLOW MOTION",0
txt_lg_net:     db "SAFETY NET",0
txt_lg_x2:      db "DOUBLE PTS",0
txt_lg_umb:     db "UMBRELLA",0
txt_lg_fire:    db "FIREWORKS",0
txt_lg_1up:     db "EXTRA LIFE",0
txt_lg_gift:    db "GIFT",0
txt_lg_bomb:    db "BOMB",0
txt_lg_steel:   db "STEEL",0
txt_halloffame: db "TOP CLOWNS",0
txt_comingup:   db "COMING UP",0
preview_lines:
        db "RING OF FIRE",0
        db "MONKEY BUSINESS",0
        db "BOMBS AWAY!",0
        db "BONUS ROUNDS",0
        db 0
txt_newhigh:    db "HIGH SCORE!",0
txt_entername:  db "ENTER YOUR NAME",0
txt_entryhelp:  db "TYPE OR USE JOYSTICK",0

; ---------------------------------------------------------------------
; MUSIC  (note, ticks) ... $FF loop / $FE end.  1 tick = 1/25 s
; ---------------------------------------------------------------------
mus_title0:
        db E5,4,Ds5,4,E5,4,C5,4
        db A4,4,Gs4,4,A4,4,F4,4
        db D4,4,F4,4,A4,4,C5,4
        db B4,8,G4,8
        db D5,4,Cs5,4,D5,4,B4,4
        db G4,4,Fs4,4,G4,4,E4,4
        db C4,4,E4,4,G4,4,B4,4
        db C5,8,RST,8
        db G5,4,E5,4,C5,4,E5,4
        db G5,8,E5,8
        db F5,4,D5,4,B4,4,D5,4
        db F5,8,D5,8
        db E5,4,F5,4,G5,4,A5,4
        db G5,4,F5,4,E5,4,D5,4
        db C5,4,E5,4,D5,4,B4,4
        db C5,8,C4,8
        db $FF
mus_title1:
        db C4,4,RST,4,G3,4,RST,4
        db F3,4,RST,4,C4,4,RST,4
        db D4,4,RST,4,A3,4,RST,4
        db G3,4,RST,4,D4,4,RST,4
        db G3,4,RST,4,D4,4,RST,4
        db C4,4,RST,4,G3,4,RST,4
        db C4,4,RST,4,G3,4,RST,4
        db C4,4,RST,4,G3,4,RST,4
        db C4,4,RST,4,G3,4,RST,4
        db C4,4,RST,4,E4,4,RST,4
        db G3,4,RST,4,D4,4,RST,4
        db G3,4,RST,4,B3,4,RST,4
        db C4,4,RST,4,G3,4,RST,4
        db G3,4,RST,4,D4,4,RST,4
        db G3,4,RST,4,B3,4,RST,4
        db C4,4,RST,4,G3,4,RST,4
        db $FF

; the original CIRCUS jingle, reharmonised
mus_actstart0:
        db C5,4,A5,5,G5,2,F5,4,G5,4,F5,4,D5,4,C5,4,A4,7,RST,4
        db C5,4,D5,4,G5,4,F5,4,E5,4,D5,4,E5,4,F5,10
        db $FE
mus_actstart1:
        db F3,8,C4,8,F3,8,C4,8,F3,8,C4,7
        db As3,8,C4,8,C4,8,F3,9
        db $FE

mus_clear0:
        db C5,3,E5,3,G5,3,C6,9,G5,3,C6,14,$FE
mus_clear1:
        db C4,9,G3,9,C4,17,$FE

mus_over0:
        db G4,8,Fs4,8,F4,8,E4,24,$FE
mus_over1:
        db C4,8,B3,8,As3,8,A3,24,$FE

; ---------------------------------------------------------------------
; SOUND EFFECTS: (voice0 period, voice1 period) per update. $FF in voice0
; = noise with density in voice1.  $FE ends.
; ---------------------------------------------------------------------
sfx_flip:       db 30,0, 22,0, $FE
sfx_jump:       db 60,0, 50,0, 40,0, $FE
sfx_launch:     db 90,45, 70,35, 55,28, 45,22, 38,19, 32,0, $FE
sfx_wall:       db 120,0, $FE
sfx_bonk:       db 100,0, 140,0, 100,0, $FE
sfx_splat:      db $FF,3, $FF,5, $FF,8, $FF,12, $FF,18, $FE
sfx_pop_var:    db $FF,2, 40,0, $FE
sfx_boom:       db $FF,1, $FF,2, $FF,4, $FF,6, $FF,9, $FF,14, $FE
sfx_clang:      db 20,21, 20,21, 30,31, $FE
sfx_power:      db 60,0, 47,0, 40,0, 30,0, 23,0, 20,40, $FE
sfx_1up:        db 40,0, 30,0, 23,0, 40,0, 30,0, 20,0, 20,0, $FE
sfx_hoop:       db 80,0, 60,0, 45,0, 33,0, $FE
sfx_throw:      db 50,0, 70,0, $FE
