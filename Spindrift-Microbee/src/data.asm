; =====================================================================
;  DATA: the sectors, their waves, the paths, the Guardians, the words
; =====================================================================
; enemy kinds
T_SKIM  EQU 0
T_WEAV  EQU 1
T_SHADE EQU 2
T_FLARE EQU 3
T_SWARM EQU 4
T_JEWEL EQU 5
T_ROCK  EQU 6
T_POD   EQU 7
T_TURR  EQU 8

; ---------------------------------------------------------------------
; paths. Speeds are in 1/16 a frame; depth 224 is the player's orbit.
; ---------------------------------------------------------------------
entry_tab:
        dw ent_spiral,ent_bloom,ent_sweep,ent_cork,ent_drop,ent_loop,ent_fire
        dw bon_a,bon_b,bon_c,bon_d,bon_e
attack_tab:
        dw atk_lunge,atk_spiral,atk_pincer,atk_rush,atk_loop,atk_orbit,atk_swoop

E_SPIRAL EQU 0
E_BLOOM  EQU 1
E_SWEEP  EQU 2
E_CORK   EQU 3
E_DROP   EQU 4
E_LOOP   EQU 5
E_FIRE   EQU 6
A_LUNGE  EQU 0
A_SPIRL  EQU 1
A_PINCR  EQU 2
A_RUSH   EQU 3
A_LOOP   EQU 4
A_ORBIT  EQU 5
A_SWOOP  EQU 6

; the classic: a spiral out of the vanishing point
ent_spiral:
        db P_MV,52,40,36, P_FORM,16
; straight out, a showy swing close to the orbit, back in
ent_bloom:
        db P_MV,18,0,96, P_MV,30,56,40, P_MV,20,40,-64, P_FORM,16
; out to the orbit's edge and round it: shoot them point blank
ent_sweep:
        db P_MV,26,8,112, P_MV,36,72,0, P_MV,18,32,-80, P_FORM,18
ent_cork:
        db P_MV,14,80,24, P_MV,14,-80,24, P_MV,14,80,24, P_MV,14,-80,24, P_FORM,20
ent_drop:
        db P_MV,34,0,56, P_FORM,14
ent_loop:
        db P_MV,20,24,96, P_MV,24,96,16, P_FORM,20
; comes in shooting
ent_fire:
        db P_MV,24,32,64, P_FIRE, P_MV,20,48,24, P_FORM,18

; the chance stage: out past the orbit and away
bon_a:  db P_MV,30,48,64, P_MV,24,-64,40, P_MV,40,32,64, P_END
bon_b:  db P_MV,20,0,80, P_MV,40,64,8, P_MV,24,-32,80, P_END
bon_c:  db P_MV,12,96,28, P_MV,12,-96,28, P_MV,12,96,28, P_MV,12,-96,28, P_MV,20,0,96, P_END
bon_d:  db P_MV,40,-40,40, P_MV,30,-80,16, P_MV,22,0,100, P_END
bon_e:  db P_MV,24,0,40, P_MV,48,64,0, P_MV,26,32,96, P_END

; attack runs (from the formation)
; a lunge at where you are: move!
atk_lunge:
        db P_WARN, P_MV,10,0,16, P_AIM,16,180, P_FIRE, P_AIM,12,236, P_MV,8,0,0
        db P_MV,20,0,-80, P_FORM,16
; corkscrews out past you firing, comes back from the centre
atk_spiral:
        db P_WARN, P_MV,15,48,40, P_FIRE, P_MV,15,48,40, P_FIRE, P_MV,10,48,40
        db P_MV,16,48,80, P_CTR, P_FORM,40
; slides in from one side along the orbit
atk_pincer:
        db P_WARN, P_AIMO,12,40,150, P_FIRE, P_AIMO,12,40,200, P_MV,18,-40,0
        db P_MV,24,0,-72, P_FORM,18
; homes on you and rams
atk_rush:
        db P_WARN, P_MV,8,0,0, P_HOME,30,80, P_MV,12,0,64, P_CTR, P_FORM,40
atk_loop:
        db P_WARN, P_TO,18,32,176, P_MV,32,96,0, P_FIRE, P_TO,18,32,110, P_FORM,16
; out to the orbit ahead of you, then sweeps along it: shoot or dodge
atk_orbit:
        db P_WARN, P_AIMO,22,72,210, P_MV,40,-48,0, P_MV,20,0,-88, P_FORM,16
atk_swoop:
        db P_WARN, P_AIM,20,170, P_FIRE, P_MV,6,0,0, P_FIRE, P_TO,20,0,110, P_FORM,16

path_leave:
        db P_MV,30,32,-48, P_END
path_raider:
        db P_MV,6,0,32, P_HOME,30,72, P_MV,14,0,64, P_END

; ---------------------------------------------------------------------
; sectors: name, star colour, HUD colour, Guardian (FFh none), waves
; ---------------------------------------------------------------------
SC_STAR  EQU 2
SC_HUD   EQU 3
SC_BOSS  EQU 4
SC_WAVE0 EQU 5

sector_tab:
        dw sec1,sec2,sec3,sec4,sec5,sec6,sec7,sec8
sec1:   dw n_sec1 : db BLUE,BCYAN,$FF : dw w11,w12
sec2:   dw n_sec2 : db CYAN,BMAGENTA,0 : dw w21,w22
sec3:   dw n_sec3 : db BROWN,YELLOW,$FF : dw w31,w32
sec4:   dw n_sec4 : db RED,BRED,1 : dw w41,w42
sec5:   dw n_sec5 : db GREEN,BGREEN,$FF : dw w51,w52
sec6:   dw n_sec6 : db GREY,WHITE,2 : dw w61,w62
sec7:   dw n_sec7 : db YELLOW,YELLOW,$FF : dw w71,w72
sec8:   dw n_sec8 : db MAGENTA,BRED,3 : dw w81,w82

n_sec1: db "OORT DRIFT",0
n_sec2: db "COMET LANES",0
n_sec3: db "RING WORKS",0
n_sec4: db "CINDER GATE",0
n_sec5: db "GAS GIANT",0
n_sec6: db "IRON BELT",0
n_sec7: db "CORONA",0
n_sec8: db "THE EYE",0

; ---------------------------------------------------------------------
; waves. Header: attack 1, attack 2, frames between attacks, most at
; once, fire chance (/256), bullet speed (1/16), formation fire (/256 a
; frame), ring spins (1/64), homing (0/2), groups. Then each group:
; kind, entry, angle, flags (1 alternate mirror, 2 mirror, 4 jewel),
; colour (dim << 4 | bright), hits, count.
; ---------------------------------------------------------------------
W_HDR   EQU 11

; OORT DRIFT: a gentle start. No enemy fire in the first wave.
w11:    db A_LUNGE,A_LUNGE,130,1,0,40,0,16,-12,0,4
        db T_SKIM,E_SPIRAL,0,0,$4E,1,8
        db T_SKIM,E_SPIRAL,128,2,$4E,1,8
        db T_WEAV,E_DROP,64,1,$2A,1,8
        db T_WEAV,E_BLOOM,192,0,$2A,1,8
w12:    db A_LUNGE,A_LOOP,95,2,80,40,2,-20,16,0,4
        db T_WEAV,E_SWEEP,0,0,$2A,1,8
        db T_SKIM,E_CORK,128,0,$4E,1,8
        db T_WEAV,E_SPIRAL,64,2,$2A,1,8
        db T_SKIM,E_BLOOM,192,1,$4E,1,8
; COMET LANES: shades, spiral strafes
w21:    db A_SPIRL,A_LUNGE,80,2,120,44,3,20,-20,0,4
        db T_SHADE,E_SPIRAL,0,0,$5D,1,8
        db T_SKIM,E_LOOP,128,2,$6E,1,8
        db T_SHADE,E_SWEEP,64,0,$5D,1,8
        db T_SKIM,E_FIRE,192,1,$6E,1,8
w22:    db A_SPIRL,A_LOOP,72,3,140,46,4,-24,24,0,4
        db T_SHADE,E_CORK,32,0,$5D,1,8
        db T_SHADE,E_BLOOM,160,2,$5D,1,8
        db T_SKIM,E_FIRE,96,0,$6E,1,8
        db T_SHADE,E_SPIRAL,224,1,$5D,1,8
; RING WORKS: armoured rocks, pincers
w31:    db A_PINCR,A_LUNGE,70,3,140,46,4,24,-16,0,4
        db T_ROCK,E_DROP,0,1,$3B,2,8
        db T_WEAV,E_SPIRAL,128,0,$2A,1,8
        db T_ROCK,E_SWEEP,64,2,$3B,2,8
        db T_WEAV,E_CORK,192,0,$2A,1,8
w32:    db A_PINCR,A_SPIRL,65,3,150,48,5,-28,20,0,4
        db T_ROCK,E_BLOOM,32,0,$3B,2,8
        db T_WEAV,E_FIRE,160,1,$2A,1,8
        db T_ROCK,E_SPIRAL,96,2,$3B,2,8
        db T_WEAV,E_LOOP,224,0,$2A,1,8
; CINDER GATE: flares that ram
w41:    db A_RUSH,A_SPIRL,65,3,150,50,5,28,-24,0,4
        db T_FLARE,E_SPIRAL,0,1,$1B,1,8
        db T_SWARM,E_CORK,128,0,$39,1,8
        db T_FLARE,E_SWEEP,64,2,$1B,1,8
        db T_SWARM,E_FIRE,192,0,$39,1,8
w42:    db A_RUSH,A_LOOP,60,3,160,52,5,-32,28,0,5
        db T_FLARE,E_BLOOM,32,0,$1B,1,8
        db T_SWARM,E_SPIRAL,160,2,$39,1,8
        db T_FLARE,E_FIRE,96,1,$1B,1,8
        db T_SWARM,E_SWEEP,224,0,$39,1,8
        db T_FLARE,E_CORK,0,0,$1B,1,8
; GAS GIANT: swarmers loop the loop
w51:    db A_LOOP,A_PINCR,60,3,160,52,5,32,-28,0,4
        db T_SWARM,E_LOOP,0,0,$2A,1,8
        db T_SHADE,E_SPIRAL,128,2,$5D,1,8
        db T_SWARM,E_FIRE,64,1,$2A,1,8
        db T_SHADE,E_SWEEP,192,0,$5D,1,8
w52:    db A_LOOP,A_RUSH,55,4,170,54,6,-36,32,0,5
        db T_SWARM,E_CORK,32,0,$2A,1,8
        db T_SHADE,E_BLOOM,160,1,$5D,1,8
        db T_SWARM,E_SPIRAL,96,2,$2A,1,8
        db T_SHADE,E_FIRE,224,0,$5D,1,8
        db T_SWARM,E_LOOP,0,1,$2A,1,8
; IRON BELT: turrets, and hunters along your orbit
w61:    db A_ORBIT,A_RUSH,55,4,170,54,6,36,-32,0,4
        db T_TURR,E_DROP,0,1,$7F,2,8
        db T_ROCK,E_SPIRAL,128,0,$3B,2,8
        db T_TURR,E_BLOOM,64,2,$7F,2,8
        db T_ROCK,E_SWEEP,192,0,$3B,2,8
w62:    db A_ORBIT,A_SPIRL,50,4,180,56,6,-40,36,0,5
        db T_TURR,E_SPIRAL,32,2,$7F,2,8
        db T_ROCK,E_CORK,160,0,$3B,2,8
        db T_TURR,E_FIRE,96,1,$7F,2,8
        db T_ROCK,E_BLOOM,224,0,$3B,2,8
        db T_TURR,E_SWEEP,0,2,$7F,2,8
; CORONA: the sun's flares swoop and fire twice
w71:    db A_SWOOP,A_SPIRL,50,4,190,56,7,40,-36,0,5
        db T_FLARE,E_FIRE,0,0,$1B,1,8
        db T_SWARM,E_LOOP,128,2,$39,1,8
        db T_WEAV,E_SWEEP,64,1,$2A,1,8
        db T_FLARE,E_SPIRAL,192,0,$1B,1,8
        db T_SWARM,E_CORK,0,1,$39,1,8
w72:    db A_SWOOP,A_RUSH,45,4,200,58,7,-44,40,0,5
        db T_FLARE,E_BLOOM,32,1,$1B,1,8
        db T_WEAV,E_FIRE,160,0,$2A,1,8
        db T_SWARM,E_SWEEP,96,2,$39,1,8
        db T_FLARE,E_LOOP,224,0,$1B,1,8
        db T_WEAV,E_SPIRAL,0,2,$2A,1,8
; THE EYE: everything, and bullets that follow you
w81:    db A_RUSH,A_ORBIT,45,4,200,58,8,44,-40,2,5
        db T_SHADE,E_FIRE,0,1,$5D,1,8
        db T_TURR,E_SPIRAL,128,0,$7F,2,8
        db T_FLARE,E_SWEEP,64,2,$1B,1,8
        db T_ROCK,E_BLOOM,192,0,$3B,2,8
        db T_SWARM,E_LOOP,0,1,$39,1,8
w82:    db A_SWOOP,A_PINCR,40,5,210,60,8,-48,44,2,5
        db T_TURR,E_CORK,32,0,$7F,2,8
        db T_SHADE,E_FIRE,160,1,$5D,1,8
        db T_FLARE,E_SPIRAL,96,2,$1B,1,8
        db T_SWARM,E_SWEEP,224,0,$39,1,8
        db T_ROCK,E_LOOP,0,1,$3B,2,8

; the chance stage: forty jewels and no one shoots back
wave_bonus:
        db A_LUNGE,A_LUNGE,250,0,0,40,0,0,0,0,5
        db T_JEWEL,7,0,4,$6E,1,8
        db T_JEWEL,8,64,5,$5D,1,8
        db T_JEWEL,9,128,4,$3B,1,8
        db T_JEWEL,10,192,6,$2A,1,8
        db T_JEWEL,11,32,5,$1B,1,8

; ---------------------------------------------------------------------
; the Guardians: pods, pod hits, core hits, ring spin, eye open, eye
; shut, attacks (4), pod colour, core colour, raider kind, regrow
; ---------------------------------------------------------------------
boss_tab:
        dw boss0,boss1,boss2,boss3
boss0:  db 5,4,30,24,50,70, A_RADIAL,A_AIMED,A_RADIAL,A_LAUNCH, $5D,BMAGENTA,T_SHADE,75
boss1:  db 6,4,40,-32,45,70, A_AIMED,A_SPIRAL,A_RADIAL,A_LAUNCH, $1B,YELLOW,T_FLARE,60
boss2:  db 7,5,50,40,40,75, A_SPIRAL,A_LAUNCH,A_AIMED,A_RADIAL, $7F,BCYAN,T_TURR,55
boss3:  db 8,6,64,-44,36,70, A_SPIRAL,A_RADIAL,A_LAUNCH,A_AIMED, $5D,BRED,T_SWARM,50

; ---------------------------------------------------------------------
; how to play: until (frame / 4), pad, caption
; ---------------------------------------------------------------------
howto:  db 18,0 : dw cap_0
        db 34,1 << PAD_ACW : dw cap_acw
        db 50,1 << PAD_CW : dw cap_cw
        db 58,4 : dw cap_dir
        db 66,2 : dw cap_dir
        db 74,8 : dw cap_dir
        db 96,16 : dw cap_fire
        db 120,16 : dw cap_warn
        db 0
cap_0:    db "HOW TO PLAY",0
cap_acw:  db "X  SWEEPS ANTICLOCKWISE",0
cap_cw:   db "Z  SWEEPS CLOCKWISE",0
cap_dir:  db "ARROWS OR STICK  FLY TO THAT SIDE",0
cap_fire: db "SPACE OR FIRE  SHOOT INTO THE VORTEX",0
cap_warn: db "FLASHING ENEMY = INCOMING ATTACK",0

; ---------------------------------------------------------------------
t_score:    db "SCORE",0
t_hi:       db "HI",0
t_sector:   db "SECTOR",0
t_shield:   db "SHIELD",0
t_warps:    db "   WARPS",0
t_lap:      db "   LAP "
t_lapn:     db "2",0          ; (the lap number goes here)
t_sectorn:  db "SECTOR ",0
t_clear:    db "WAVE CLEAR",0
t_nodmg:    db "NO DAMAGE BONUS",0
t_warning:  db "WARNING",0
t_guardian: db "A GUARDIAN BARS THE WAY",0
t_chance:   db "CHANCE STAGE",0
t_chance2:  db "SHOOT EVERY JEWEL",0
t_hits:     db "HITS ",0
t_of40:     db " OF 40",0
t_perfect:  db "PERFECT  10000",0
t_gameover: db "GAME OVER",0
t_paused:   db "PAUSED",0
t_core:     db "    CORE",0
t_spaces:   db "                     ",0
t_spindrift:db "S P I N D R I F T",0
t_mon1:     db "PRESS C FOR A COLOUR MONITOR",0
t_mon2:     db "OR M FOR A MONOCHROME ONE",0
t_vibed:    db "VIBED BY BPM 2026",0
t_tag:      db "RIDE THE SPIRAL HOME",0
t_best:     db "HIGH SCORE",0
t_keys:     db "Z X SWEEP  SPACE FIRE  H PAUSE  S SOUND",0
t_press:    db "PRESS SPACE OR FIRE TO PLAY",0
t_press0:   db "                           ",0
t_fame:     db "HALL OF FAME",0
t_newhi:    db "NEW HIGH SCORE",0
t_initials: db "ENTER YOUR INITIALS",0
t_enter1:   db "TYPE LETTERS OR USE THE STICK",0
t_enter2:   db "FIRE TO ACCEPT",0

; the hall of fame: initials, score / 10 (BCD, low byte first)
hitab:  db "BPM" : db $00,$50,$00
        db "VIB" : db $00,$40,$00
        db "MBE" : db $00,$30,$00
        db "ZED" : db $00,$25,$00
        db "SPN" : db $00,$20,$00
        db "ORT" : db $00,$15,$00
        db "EYE" : db $00,$10,$00
        db "GYR" : db $00,$05,$00
