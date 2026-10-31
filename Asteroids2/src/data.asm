; ---------------------------------------------------------------------------
; data.asm - text, sound effects, tables
; ---------------------------------------------------------------------------
txt_wave:       db "WAVE ",0
txt_gameover:   db "GAME OVER",0
txt_w:          db "W",0
txt_shipicon:   db "^",0
txt_bombicon:   db "[",0
txt_shieldicon: db "]",0
txt_p_shield:   db "SHIELD",0,0
txt_p_bomb:     db "BOMB",0,0,0,0
txt_p_spread:   db "SPREAD",0,0
txt_p_rapid:    db "RAPID",0,0,0
txt_p_life:     db "1 UP",0,0,0,0
txt_demo:       db "DEMO",0
txt_press:      db "PRESS FIRE TO PLAY",0
txt_credit1:    db "2026  VIBED BY BPM",0
txt_credit2:    db "ORIGINAL BY DUBOIS+MCNAMARA",0
txt_roster:     db "- ENEMY FILES -",0
txt_treasure:   db "- TREASURE + POWER -",0
txt_hiscores:   db "HIGH SCORES",0
txt_newhigh:    db "NEW HIGH SCORE!",0
txt_enter:      db "LEFT/RIGHT CHOOSE",0
txt_enter2:     db "FIRE TO ENTER",0
txt_r_saucer:   db "RAIDER SAUCER   200",0
txt_r_hunter:   db "HUNTER AIMS!   1000",0
txt_r_sting:    db "STINGER DIVES   500",0
txt_r_mine:     db "MINE   150 SHRAPNEL",0
txt_r_volat:    db "VOLATILE: CHAIN BLAST",0
txt_r_ore:      db "ORE ROCK: JEWELS",0
txt_t_topaz:    db "TOPAZ           250",0
txt_t_ruby:     db "RUBY            500",0
txt_t_emerald:  db "EMERALD        1000",0
txt_t_spread:   db "SPREAD SHOT",0
txt_t_rapid:    db "RAPID FIRE",0
txt_t_shield:   db "SHIELD - 3 HITS",0
txt_t_bomb:     db "SMART BOMB",0
txt_t_life:     db "EXTRA SHIP",0
txt_scroll:     db "      WELCOME TO ASTEROIDS II ...  BLAST THE ROCKS, CRACK ORE FOR JEWELS "
                db "AND CHAIN THEM FOR UP TO X4 POINTS ...  BEWARE VOLATILE ROCKS, THEY BURST "
                db "INTO SHRAPNEL ...  KEYS: U/I TURN  O THRUST  Z OR SPACE FIRE  P HYPERSPACE  "
                db "B SMART BOMB  M MUSIC ON/OFF ...  JOYSTICK: DOWN BOMB, ARM HYPERSPACE ...  "
                db "GREETINGS TO EVERY VZ FAN STILL FLYING ...  ",0
txt_needram:    db "ASTEROIDS II NEEDS THE",0
txt_needram2:   db "BENNVENN SD 128K EXPANSION",0

        ALIGN 4
pixmask: db $C0,$30,$0C,$03

; ---- sound effects -----------------------------------------------------
; segment: frames, freq(word), dfreq(word), duty, dduty, mode(0 tone/1 noise)
; freq word = Hz * 3.954 (tone);  for noise, freq = memory step (1..4)

SFX_SHOT    equ 0
SFX_BOOM_L  equ 1
SFX_BOOM_M  equ 2
SFX_BOOM_S  equ 3
SFX_DIE     equ 4
SFX_THRUST  equ 5
SFX_BEAT1   equ 6
SFX_BEAT2   equ 7
SFX_HYPER   equ 8
SFX_LIFE    equ 9
SFX_CLINK   equ 10
SFX_SHIELD  equ 11
SFX_SPAWN   equ 12
SFX_BOMB    equ 13
SFX_WAVE    equ 14
SFX_JEWEL   equ 15
SFX_PICKUP  equ 16
SFX_SAUCER  equ 17
SFX_HUNTER  equ 18
SFX_EFIRE   equ 19
SFX_STING   equ 20
SFX_MINE    equ 21
SFX_EBOOM   equ 22
SFX_SHRAP   equ 23
SFX_CHAIN   equ 24
SFX_GEMDROP equ 25

sfx_table:
        dw sx_shot   : db 1, 2
        dw sx_boomL  : db 2, 6
        dw sx_boomM  : db 2, 5
        dw sx_boomS  : db 2, 4
        dw sx_die    : db 2, 9
        dw sx_thrust : db 2, 1
        dw sx_beat1  : db 0, 1
        dw sx_beat2  : db 0, 1
        dw sx_hyper  : db 1, 7
        dw sx_life   : db 1, 9
        dw sx_clink  : db 1, 3
        dw sx_shield : db 1, 6
        dw sx_spawn  : db 1, 5
        dw sx_bomb   : db 2, 10
        dw sx_wave   : db 0, 5
        dw sx_jewel  : db 1, 6
        dw sx_pickup : db 1, 8
        dw sx_saucer : db 0, 3
        dw sx_hunter : db 0, 3
        dw sx_efire  : db 1, 2
        dw sx_sting  : db 0, 3
        dw sx_mine   : db 0, 2
        dw sx_eboom  : db 2, 7
        dw sx_shrap  : db 2, 7
        dw sx_chain  : db 1, 7
        dw sx_gemdrop: db 1, 4

sx_shot:   SEG 1, 5200, 0, 90, 0, 0
           SEG 4, 4200, -700, 80, -18, 0
           db 0
sx_boomL:  SEG 16, 1, 0, 128, -8, 1
           db 0
sx_boomM:  SEG 10, 1, 0, 118, -11, 1
           db 0
sx_boomS:  SEG 6, 2, 0, 100, -16, 1
           db 0
sx_die:    SEG 4, 1, 0, 128, 0, 1
           SEG 40, 1, 0, 128, -3, 1
           db 0
sx_thrust: SEG 2, 1, 0, 34, 0, 1
           db 0
sx_beat1:  SEG 2, 435, 0, 70, -30, 0
           db 0
sx_beat2:  SEG 2, 388, 0, 70, -30, 0
           db 0
sx_hyper:  SEG 6, 900, 600, 110, 0, 0
           SEG 6, 4500, -500, 110, -16, 0
           db 0
sx_life:   SEG 3, 2069, 0, 100, -10, 0
           SEG 3, 2607, 0, 100, -10, 0
           SEG 3, 3100, 0, 100, -10, 0
           SEG 3, 4138, 0, 100, -10, 0
           SEG 3, 3100, 0, 100, -10, 0
           SEG 6, 4138, 0, 100, -12, 0
           db 0
sx_clink:  SEG 3, 7000, -300, 70, -20, 0
           db 0
sx_shield: SEG 8, 3000, -250, 120, -12, 0
           db 0
sx_spawn:  SEG 10, 700, 250, 90, -6, 0
           db 0
sx_bomb:   SEG 3, 1, 0, 128, 0, 1
           SEG 30, 1, 0, 128, -4, 1
           db 0
sx_wave:   SEG 4, 1035, 0, 90, -15, 0
           SEG 4, 1550, 0, 90, -15, 0
           SEG 8, 2069, 0, 90, -8, 0
           db 0
sx_jewel:  SEG 2, 6200, 0, 90, -20, 0
           SEG 2, 7800, 0, 90, -20, 0
           SEG 2, 9300, 0, 90, -20, 0
           SEG 4, 12400, 0, 80, -16, 0
           db 0
sx_pickup: SEG 3, 2069, 300, 100, 0, 0
           SEG 3, 3100, 300, 100, 0, 0
           SEG 3, 4138, 300, 100, 0, 0
           SEG 5, 6200, -200, 100, -18, 0
           db 0
sx_saucer: SEG 6, 1700, 120, 50, 0, 0
           SEG 6, 2420, -120, 50, 0, 0
           db $FF
           dw sx_saucer
sx_hunter: SEG 3, 3400, 300, 45, 0, 0
           SEG 3, 4300, -300, 45, 0, 0
           db $FF
           dw sx_hunter
sx_efire:  SEG 4, 2400, -350, 80, -15, 0
           db 0
sx_sting:  SEG 10, 1200, 160, 60, -5, 0
           db 0
sx_mine:   SEG 2, 5000, 0, 40, -18, 0
           db 0
sx_eboom:  SEG 3, 1, 0, 128, 0, 1
           SEG 12, 1, 0, 120, -9, 1
           db 0
sx_shrap:  SEG 4, 1, 0, 128, 0, 1
           SEG 14, 2, 0, 128, -8, 1
           db 0
sx_chain:  SEG 2, 8277, 0, 90, -30, 0
           SEG 2, 10430, 0, 90, -30, 0
           SEG 4, 12400, 0, 90, -18, 0
           db 0
sx_gemdrop: SEG 4, 4138, 600, 70, -14, 0
           db 0

        INCLUDE "tables.inc"
        INCLUDE "burst.inc"
        INCLUDE "music.inc"
        INCLUDE "assets.inc"
