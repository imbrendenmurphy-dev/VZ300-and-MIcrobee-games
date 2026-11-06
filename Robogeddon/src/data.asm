; =====================================================================
;  ROBOGEDDON - tables and text
; =====================================================================

; ---- object type info: w, h, flags, score (4-digit BCD, lo then hi)
tinfo:
        db 5,5, F_SHOOT|F_COUNT|F_DEADLY|F_MOVER,        $00,$01  ; droid   100
        db 5,5, F_SHOOT|F_DEADLY,                        $25,$00  ; pylon    25
        db 7,7, F_DEADLY|F_MOVER,                        $00,$00  ; crusher
        db 5,5, F_SHOOT|F_COUNT|F_DEADLY|F_BIG|F_MOVER,  $00,$10  ; orb    1000
        db 5,5, F_SHOOT|F_COUNT|F_DEADLY|F_BIG|F_MOVER,  $00,$10  ; factory 1000
        db 5,5, F_SHOOT|F_COUNT|F_DEADLY|F_MOVER,        $50,$01  ; seeker  150
        db 7,6, F_SHOOT|F_COUNT|F_DEADLY|F_BIG|F_MOVER,  $00,$05  ; mindbot 500
        db 5,5, F_SHOOT|F_COUNT|F_DEADLY|F_MOVER,        $00,$01  ; mutant  100
        db 7,6, F_SHOOT|F_COUNT|F_DEADLY|F_BIG|F_MOVER,  $00,$02  ; tank    200
        db 5,6, F_HUMAN, 0,0                                      ; mom
        db 5,6, F_HUMAN, 0,0                                      ; dad
        db 3,5, F_HUMAN, 0,0                                      ; kid
        db 5,5, 0, 0,0                                            ; skull
        db 16,5, 0, 0,0                                           ; popup
        db 5,5, 0, 0,0                                            ; pickup
        db 5,5, 0, 0,0                                            ; explosion

; ---- waves: droids, pylons, crushers, mindbots, orbs, factories,
;             moms, dads, kids, droid step delay
spawn_types:
        db T_DROID, T_PYLON, T_CRUSH, T_BRAIN, T_ORB, T_FACT, T_MOM, T_DAD, T_KID
wavetab:
        db 15, 5, 0, 0, 0, 0, 1, 1, 1, 7      ; 1
        db 17, 8, 3, 0, 1, 0, 2, 1, 1, 6      ; 2
        db 22,10, 4, 0, 1, 0, 2, 2, 2, 6      ; 3
        db 18, 0,10, 0, 2, 0, 3, 2, 2, 6      ; 4  crusher wave
        db 14, 5, 3, 7, 0, 0, 3, 3, 3, 6      ; 5  mindbot wave
        db 29,10, 3, 0, 2, 0, 2, 2, 2, 5      ; 6
        db 10, 4, 3, 0, 0, 4, 2, 2, 2, 5      ; 7  tank wave
        db 28,12, 4, 0, 2, 0, 2, 1, 1, 5      ; 8
        db 24, 0,12, 0, 2, 0, 3, 3, 3, 5      ; 9  crusher wave
        db 14, 6, 3,10, 0, 0, 3, 3, 4, 5      ; 10 mindbot wave
        db 32,10, 4, 0, 3, 0, 1, 1, 1, 4      ; 11
        db 12, 4, 3, 0, 0, 5, 2, 2, 2, 4      ; 12 tank wave
        db 28,12, 5, 0, 3, 0, 1, 1, 1, 4      ; 13
        db 24, 0,14, 0, 2, 0, 3, 3, 3, 4      ; 14 crusher wave
        db 14, 7, 3,12, 0, 0, 3, 3, 4, 4      ; 15 mindbot wave
        db 32,10, 4, 0, 3, 0, 1, 1, 1, 3      ; 16
        db 14, 5, 3, 0, 0, 6, 2, 2, 2, 3      ; 17 tank wave
        db 30,11, 5, 0, 3, 0, 1, 1, 1, 3      ; 18
        db 24, 0,16, 0, 3, 0, 3, 3, 3, 3      ; 19 crusher wave
        db 16, 7, 3,14, 0, 0, 3, 3, 4, 3      ; 20 mindbot wave

flash_cols:
        db 1, 3, 2, 3
; the blue arena's edge: a single 50:50 green/blue line, fading into the
; VZ's green border.  (blue pixels, green-pixel mask)
; side bytes for rows 0..3 mod 4 (left, right)
dith_t:
        db $2A,$C0, $AA,$00             ; even rows: green on the outside pixel
        db $AA,$00, $A8,$03             ; odd rows: green on the right side
        db $2A,$C0, $AA,$00
        db $AA,$00, $A8,$03
        db $22,$CC                      ; top line
        db $22,$CC                      ; divider under the scores
        db $88,$33                      ; bottom line

; ---- directions: 0 U, 1 UR, 2 R, 3 DR, 4 D, 5 DL, 6 L, 7 UL
; pad bits 0 R, 1 L, 2 U, 3 D -> direction ($FF none)
dirtab:
        db $FF, 2, 6, $FF, 0, 1, 7, 0, 4, 3, 5, 4, $FF, 2, 6, $FF
dirbits:
        db $04, $05, $01, $09, $08, $0A, $02, $06
; player speed (8.8): x 1.75, y 1.16  (the screen's pixels are 1.5x taller)
pmvx:   dw 0, $01C0, $01C0, $01C0, 0, -$01C0, -$01C0, -$01C0
pmvy:   dw -$0128, -$0128, 0, $0128, $0128, $0128, 0, -$0128
; player shots, pixels per frame
sdx:    db 0, 5, 6, 5, 0, -5, -6, -5
sdy:    db -4, -3, 0, 3, 4, 3, 0, -3
; enemy bullets, 1/32 pixel per frame
bvx:    db 0, 57, 80, 57, 0, -57, -80, -57
bvy:    db -53, -38, 0, 38, 53, 38, 0, -38
card_dx: db 1, -1, 0, 0
card_dy: db 0, 0, 1, -1

rescue_pts:
        dw $1000, $2000, $3000, $4000, $5000
pop_strs:
        dw s_p1000, s_p2000, s_p3000, s_p4000, s_p5000
s_p1000: db "1000",0
s_p2000: db "2000",0
s_p3000: db "3000",0
s_p4000: db "4000",0
s_p5000: db "5000",0

; ---- front end
logo_letters:
        db F_BIG_R, F_BIG_O, F_BIG_B, F_BIG_O, F_BIG_G
        db F_BIG_E, F_BIG_D, F_BIG_D, F_BIG_O, F_BIG_N
ease18: db 0, 7, 14, 20, 26, 31, 36, 41, 45, 49, 52, 55, 58, 60, 62, 63, 64, 64
ease25: db 0, 5, 10, 15, 19, 24, 28, 32, 35, 39, 42, 45, 48, 50, 53, 55, 57, 58, 60, 61, 62, 63, 63, 64, 64

mode_names:
        dw s_m_dual, s_m_one, s_m_keys
s_m_dual: db "DUAL STICK",0
s_m_one:  db "ONE STICK",0
s_m_keys: db "KEYBOARD",0
snd_names:
        dw s_snd_all, s_snd_fx, s_snd_off
s_snd_all: db "ALL",0
s_snd_fx:  db "FX",0
s_snd_off: db "OFF",0

s_ctl:      db "CONTROLS (1-3): ",0
s_2085:     db "2085",0
s_vibed:    db "VIBED BY BPM 2026",0
s_start:    db "SPACE OR FIRE TO START",0
s_trn_opt:  db "T TRAINER ",0
s_on:       db "ON",0
s_off:      db "OFF",0
s_snd_opt:  db "  M SOUND ",0

s_story_h:  db "- THE STORY SO FAR -",0
story:
        db "THE YEAR IS 2085.",0
        db "OUR OWN ROBOTS HAVE TURNED",0
        db "ON US: THE ROBOGEDDON.",0
        db "ONE FAMILY IS LEFT, AND",0
        db "ONLY YOU CAN SAVE THEM.",0
        db "BLAST EVERY ROBOT, SAVE THE",0
        db "HUMANS. NEVER STOP MOVING!",0
        db $FF

s_meet:     db "THE ROBOTS",0
gallery:    ; frame, x, y, text column, text
        db F_GRUNT0, 9, 17, 4
        dw s_g_droid
        db F_ELEC1_3, 9, 25, 4
        dw s_g_pylon
        db F_HULK0, 8, 32, 4
        dw s_g_crush
        db F_SPH1, 9, 41, 4
        dw s_g_orb
        db F_ENF0, 9, 49, 4
        dw s_g_seek
        db F_BRAIN0, 63, 17, 18
        dw s_g_brain
        db F_PROG0, 64, 25, 18
        dw s_g_mut
        db F_SPH2, 64, 33, 18
        dw s_g_fact
        db F_TANK0, 63, 41, 18
        dw s_g_tank
        db F_DAD0, 64, 49, 18
        dw s_g_hum
s_g_droid:  db "DROID   100",0
s_g_pylon:  db "PYLON    25",0
s_g_crush:  db "CRUSHER ---",0
s_g_orb:    db "ORB    1000",0
s_g_seek:   db "SEEKER  150",0
s_g_brain:  db "MINDBOT  500",0
s_g_mut:    db "MUTANT   100",0
s_g_fact:   db "FACTORY 1000",0
s_g_tank:   db "TANK     200",0
s_g_hum:    db "HUMANS 1000+",0
s_zap:      db "SHOOT THEIR SHOTS: 25",0

s_controls: db "CONTROLS",0
ctl_heads:
        dw cl_h1, cl_h2, cl_h3
ctl_lines:
cl_h1:  db "1 DUAL STICK",0
        db " JOY 1 MOVE, JOY 2 SHOOT",0
cl_h2:  db "2 ONE STICK",0
        db " HOLD FIRE: SHOOT+STRAFE",0
cl_h3:  db "3 KEYBOARD",0
        db " WASD MOVE, IJKL SHOOT",0
        db "RETURN PAUSE  M SOUND",0
        db $FF

s_hiscores: db "- ROBOGEDDON HEROES -",0
s_great:    db "GREAT SCORE!",0
s_initials: db "ENTER YOUR INITIALS",0
s_namehelp: db "UP/DOWN LETTER  FIRE NEXT",0

; ---- in game
s_wave:     db "WAVE ",0
s_cleared:  db " CLEAR",0
s_saved:    db "HUMANS SAVED: ",0
s_bonus:    db "FULL FAMILY BONUS 5000",0
s_gameover: db "GAME OVER",0
s_sub_first: db "SAVE THE LAST HUMAN FAMILY!",0
s_sub_crush: db "CRUSHERS! THEY CAN'T BE STOPPED",0
s_sub_brain: db "MINDBOTS ARE HUNTING HUMANS",0
s_sub_tank:  db "TANK FACTORIES INBOUND",0
s_sub_orb:   db "WATCH OUT FOR THE ORBS",0
s_sub_droid: db "THE DROIDS ARE COMING",0
s_paused:   db "- PAUSED -",0
s_pausq:    db "RETURN TO PLAY, Q TO QUIT",0
s_w:        db "W",0
s_hi:       db "HI",0
s_demo:     db "DEMO",0
s_trn:      db "TRAINER",0

; ---- default high scores: score (BCD), name, wave, spare
hisc_init:
        db $05,$00,$00, "BPM", 15, 0
        db $04,$00,$00, "VZ3", 12, 0
        db $03,$00,$00, "DSE", 10, 0
        db $02,$50,$00, "ZAP",  8, 0
        db $02,$00,$00, "BOT",  6, 0
        db $01,$50,$00, "MOM",  5, 0
        db $01,$00,$00, "DAD",  3, 0
        db $00,$50,$00, "KID",  2, 0
