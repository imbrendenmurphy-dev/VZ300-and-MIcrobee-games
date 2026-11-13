; ============================================================================
;  DATA: fighters, moves, sounds, words
; ============================================================================

; fighter definitions: walk fwd/back, jump vx fwd/back (quarter px a tick),
; jump length, jump arc, standing hurt height, moves
def_flick:
        db 8, 6, 10, 8, 14
        dw jump_flick
        db 30
        dw moves_flick
def_dusty:
        db 5, 4, 8, 7, 18
        dw jump_dusty
        db 34
        dw moves_dusty

; moves: startup, active, recovery (ticks), damage, hit x from..to (pixels
; forward of the body centre), hit y from..to (pixels up), flags, hit-stun,
; block-stun, recovery frame, wind-up frame, strike frame, speed while
; striking, effect (bit 7 = crouching move)
moves_flick:
        ; A standing: jab
        db 2,1,2,  5,  4,20, 14,24, MF_LIGHT,        5,3, FR_SA_W, FR_SA_W, FR_SA_S, 0, 0
        ; B standing: big right hand
        db 4,2,5, 10,  4,24, 12,26, 0,               8,5, FR_SB_W, FR_SB_W, FR_SB_S, 0, 0
        ; A crouching: low jab
        db 2,1,3,  4,  4,20,  6,14, MF_LIGHT,        5,3, FR_CROUCH, FR_CROUCH, FR_CA_S, 0, $80
        ; B crouching: sweep
        db 4,2,7,  9,  4,26,  0, 5, MF_LOW+MF_KD,    0,5, FR_CROUCH, FR_CROUCH, FR_CB_S, 0, $80
        ; A jumping: jump punch
        db 2,3,0,  6,  0,18,  4,20, MF_HIGH+MF_LIGHT+MF_AIR, 5,3, FR_JUMP, FR_JUMP, FR_JA, 0, 0
        ; B jumping: jump kick
        db 2,3,0, 10,  0,22,  0,16, MF_HIGH+MF_AIR,  8,5, FR_JUMP, FR_JUMP, FR_JB, 0, 0
        ; BLADE RUN (A+B): dashing punch, punishable when blocked
        db 4,6,8, 14,  2,18, 12,26, MF_SPEC,        12,5, FR_SP1_W, FR_SP1_W, FR_SP1_S, 24, 0
        ; TIN ROOF (down + A+B): rising uppercut, beats jump-ins
        db 2,5,12, 16, 0,14, 10,42, MF_SPEC+MF_KD+MF_INVSU+MF_RISE, 0,5, FR_SP2_S, FR_SP2_W, FR_SP2_S, 0, 0

moves_dusty:
        ; A standing: rein jab
        db 3,1,3,  6,  4,26, 16,28, MF_LIGHT,        5,3, FR_SA_W, FR_SA_W, FR_SA_S, 0, 0
        ; B standing: long boot
        db 6,2,7, 12,  4,36, 10,22, 0,               8,5, FR_SB_W, FR_SB_W, FR_SB_S, 0, 0
        ; A crouching
        db 3,1,4,  5,  4,26,  6,14, MF_LIGHT,        5,3, FR_CROUCH, FR_CROUCH, FR_CA_S, 0, $80
        ; B crouching: long sweep
        db 6,2,9, 10,  4,38,  0, 5, MF_LOW+MF_KD,    0,5, FR_CROUCH, FR_CROUCH, FR_CB_S, 0, $80
        ; A jumping
        db 3,5,0,  7,  0,22,  6,22, MF_HIGH+MF_LIGHT+MF_AIR, 5,3, FR_JUMP, FR_JUMP, FR_JA, 0, 0
        ; B jumping
        db 3,5,0, 11,  0,28,  0,14, MF_HIGH+MF_AIR,  8,5, FR_JUMP, FR_JUMP, FR_JB, 0, 0
        ; WHIP CRACK (A+B): hits only at the tip, 34-56 pixels out
        db 9,2,14, 11, 34,56, 12,30, MF_SPEC,        10,5, FR_SP1_S, FR_SP1_W, FR_SP1_S, 0, 1
        ; ANKLE SNARE (down + A+B): low whip, knocks down
        db 9,2,15, 10, 30,50, 0, 6, MF_SPEC+MF_LOW+MF_KD, 0,5, FR_SP2_S, FR_SP2_W, FR_SP2_S, 0, $82

; ---------------------------------------------------------------------------
; sounds: db fields, mode (0 rest 1 tone 2 noise), dw step ; 0 = end
; tone frequency = step * 0.73 Hz
; ---------------------------------------------------------------------------
sfx_hit_lt:
        db 2,2
        dw $3000
        db 2,2
        dw $1400
        db 0
sfx_hit_hvy:
        db 2,2
        dw $2400
        db 2,2
        dw $1000
        db 2,2
        dw $0700
        db 0
sfx_block:
        db 1,2
        dw $5000
        db 1,1
        dw $0C00
        db 0
sfx_thud:
        db 3,2
        dw $0500
        db 0
sfx_special:
        db 1,1
        dw $0400
        db 1,1
        dw $0600
        db 1,1
        dw $0900
        db 0
sfx_ko:
        db 3,1
        dw $0445
        db 3,1
        dw $0334
        db 3,1
        dw $0267
        db 3,1
        dw $01D0
        db 3,1
        dw $0156
        db 3,1
        dw $0103
        db 4,1
        dw $00BF
        db 6,1
        dw $0089
        db 0
sfx_bell:
        db 5,1
        dw $0668
        db 3,0
        dw 0
        db 12,1
        dw $0668
        db 0
sfx_win:
        db 4,1
        dw $02CB
        db 2,0
        dw 0
        db 4,1
        dw $0384
        db 2,0
        dw 0
        db 4,1
        dw $0430
        db 2,0
        dw 0
        db 10,1
        dw $0597
        db 0
sfx_blip:
        db 2,1
        dw $0700
        db 0
sfx_sel:
        db 2,1
        dw $0500
        db 3,1
        dw $0A00
        db 0

; title tune: a slow, gritty riff - short notes with gaps ("dink, dink-dink")
N_A2  equ $0096
N_C3  equ $00B3
N_D3  equ $00C9
N_E3  equ $00E1
N_G3  equ $010C
N_A3  equ $012D
tune_title:
        db 3,1
        dw N_A2
        db 9,0
        dw 0
        db 3,1
        dw N_A2
        db 3,0
        dw 0
        db 3,1
        dw N_C3
        db 9,0
        dw 0
        db 3,1
        dw N_D3
        db 9,0
        dw 0
        db 3,1
        dw N_E3
        db 3,0
        dw 0
        db 3,1
        dw N_G3
        db 3,0
        dw 0
        db 3,1
        dw N_E3
        db 9,0
        dw 0
        db 3,1
        dw N_D3
        db 3,0
        dw 0
        db 3,1
        dw N_C3
        db 9,0
        dw 0
        db 3,1
        dw N_A2
        db 3,0
        dw 0
        db 3,1
        dw N_A3
        db 3,0
        dw 0
        db 3,1
        dw N_G3
        db 3,0
        dw 0
        db 3,1
        dw N_E3
        db 21,0
        dw 0
        db 0

; ---------------------------------------------------------------------------
; words
; ---------------------------------------------------------------------------
s_flick:    db "FLICK",0
s_dusty:    db "DUSTY",0
s_red_dust: db "RED DUST",0
s_rumble:   db "RUMBLE",0
s_vibed:    db "VIBED BY BPM 2026",0
s_1p:       db "1 PLAYER",0
s_2p:       db "2 PLAYERS",0
s_easy:     db "LEVEL: EASY",0
s_normal:   db "LEVEL: NORMAL",0
s_hard:     db "LEVEL: HARD",0
s_ctest:    db "CONTROL TEST",0
s_quit:     db "QUIT TO SD",0
s_arrow:    db ">",0
s_choose:   db "CHOOSE YOUR FIGHTER",0
s_p1:       db "P1",0
s_p2:       db "P2",0
s_cpu:      db "CPU",0
s_pick1:    db "P1: LEFT/RIGHT, FIRE",0
s_pick2:    db "P2: LEFT/RIGHT, FIRE",0
s_pickcpu:  db "NOW PICK THE CPU",0
s_vs:       db "VS",0
s_roundn:   db "ROUND 1",0
s_fight:    db "FIGHT!",0
s_time:     db "TIME",0
s_ko:       db "K.O.",0
s_draw:     db "DRAW",0
s_paused:   db "PAUSED",0
s_pausehelp: db "RETURN: GO ON   Q: QUIT",0
s_youwin:   db "YOU WIN!",0
s_youlose:  db "YOU LOSE",0
s_p1wins:   db "P1 WINS",0
s_p2wins:   db "P2 WINS",0
s_drawgame: db "DRAW GAME",0
s_again:    db "FIRE: REMATCH   B: MENU",0
s_ct_title: db "CONTROL TEST",0
s_ct_j1:    db "JOY 1",0
s_ct_j2:    db "JOY 2",0
s_ct_k1:    db "KEYS1",0
s_ct_k2:    db "KEYS2",0
s_ct_syms:  db "UDLRAB"
s_ct_ports: db "2C 2E 2D 29 23 2B 27",0
s_ct_drop:  db "J1 DROPS U   D   L   R",0
s_ct_drop2: db "J2 DROPS U   D   L   R",0
s_ct_gap:   db "A+B GAP",0
s_ct_exit:  db "RETURN: BACK",0
s_sel_f1:   db "FAST",0
s_sel_f2:   db "CLOSE-IN",0
s_sel_d1:   db "SLOW",0
s_sel_d2:   db "LONG REACH",0

; select screen text: row, colour, string
sel_text:
        db 21,1
        dw s_flick
        db 27,0
        dw s_sel_f1
        db 33,0
        dw s_sel_f2
        db 41,1
        dw s_dusty
        db 47,0
        dw s_sel_d1
        db 53,0
        dw s_sel_d2
        db 0

        include "gen/tables.asm"
