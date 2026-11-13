; =====================================================================
;  STARWHIRL - data: enemy stats, sectors, bosses, text
; =====================================================================

; typeinfo: 8 bytes a type - first frame, hits, points (BCD lo, hi),
;   fires (0/1), dive style (0 sweep the orbit, 1 kamikaze, 2 never), -, -
typeinfo:
        db      FT_GLINT, 1, $00,$01, 0, 0, 0, 0     ; GLINT   100
        db      FT_MOTH,  1, $50,$01, 1, 0, 0, 0     ; MOTH    150, shoots
        db      FT_SPIN,  2, $00,$02, 1, 0, 0, 0     ; SPINNER 200, 2 hits
        db      FT_HORNET,1, $50,$02, 1, 1, 0, 0     ; HORNET  250, rams
        db      FT_MINE,  2, $00,$03, 0, 2, 0, 0     ; MINE    300, drifts out
        db      FT_POD,   1, $00,$10, 0, 2, 0, 0     ; POD    1000, twin shot
        db      FT_SPARK, 1, $00,$02, 0, 2, 0, 0     ; SPARK (bonus round)
        db      FT_ARMOR, 3, $00,$05, 0, 2, 0, 0     ; boss armour pod 500

; palette per sector: blue space, blue, then two nebula (CSS1) sectors
sec_css:    db 0, 0, CSS1, CSS1, 0

sec_titles: dw s_sec1, s_sec2, s_sec3, s_sec4, s_sec5
sec_names:  dw s_nm1, s_nm2, s_nm3, s_nm4, s_nm5
s_sec1: db "SECTOR 1",0
s_sec2: db "SECTOR 2",0
s_sec3: db "SECTOR 3",0
s_sec4: db "SECTOR 4",0
s_sec5: db "SECTOR 5",0
s_nm1:  db "THE DRIFT",0
s_nm2:  db "THE ICE BELT",0
s_nm3:  db "EMBER REACH",0
s_nm4:  db "THE GLASS NEBULA",0
s_nm5:  db "THE EYE OF THE STORM",0

wave_msgs:  dw s_w1, s_w2, s_w3, s_w4
s_w1:   db "WAVE 1",0
s_w2:   db "WAVE 2",0
s_w3:   db "WAVE 3",0
s_w4:   db "WAVE 4",0

snd_names:  dw s_snd0, s_snd1, s_snd2
s_snd0: db "SOUND ON",0
s_snd1: db "FX ONLY",0
s_snd2: db "SOUND OFF",0

; bosses: design (0 WARDEN, 1 CORAL, 2 EMBER, 3 EYE), pods, strength
bdes_tab:   db 0, 1, 2, 1, 3
bpod_tab:   db 4, 6, 6, 8, 8
bhp_tab:    db 22, 28, 34, 40, 48
boss_names: dw s_b1, s_b2, s_b3, s_b4, s_b5
s_b1:   db "THE WARDEN",0
s_b2:   db "THE CORAL QUEEN",0
s_b3:   db "THE EMBER LORD",0
s_b4:   db "THE PRISM QUEEN",0
s_b5:   db "THE HEART OF THE WHIRL",0

s_paused:    db "PAUSED",0
s_pausehelp: db "P GO ON  M SOUND  Q QUIT",0
s_twin:      db "TWIN SHOT",0
s_twinhud:   db "TWIN",0
s_hboss:     db "BOSS",0
s_hbonus:    db "BONUS",0
s_bonus:     db "BONUS ",0
s_ready:     db "READY",0
s_gameover:  db "GAME OVER",0
s_warning:   db "WARNING",0
s_secclear:  db "SECTOR CLEAR",0
s_nodamage:  db "NO DAMAGE BONUS 10000",0
s_bonusrnd:  db "BONUS ROUND",0
s_shootall:  db "SHOOT ALL 40 STARS",0
s_hits:      db "HITS ",0
s_each:      db "200 POINTS EACH",0
s_perfect:   db "PERFECT  10000 BONUS",0
s_end1:      db "THE STORM STILLS",0
s_end2:      db "50000 BONUS",0
s_end3:      db "BUT IT STIRS",0
s_end4:      db "ROUND 2 - FASTER AND FIERCER",0
s_extra:     db "EXTRA SHIP",0

; dir16: 16 directions for explosion sparks (signed 4.4 x, y per frame;
;   y two-thirds of x so bursts look round on a 4:3 screen)
dir16:
        db  24,  0,   22,  6,   17, 11,    9, 15
        db   0, 16,   -9, 15,  -17, 11,  -22,  6
        db -24,  0,  -22, -6,  -17,-11,   -9,-15
        db   0,-16,    9,-15,   17,-11,   22, -6

; high scores: 8 x (score BCD x3, initials x3, sector reached, -)
hisc_init:
        db $05,$00,$00, "BPM", 5, 0
        db $04,$00,$00, "VZ ", 4, 0
        db $03,$00,$00, "SWL", 3, 0
        db $02,$50,$00, "DSE", 3, 0
        db $02,$00,$00, "AUS", 2, 0
        db $01,$50,$00, "BEE", 2, 0
        db $01,$00,$00, "ACE", 1, 0
        db $00,$50,$00, "ZAP", 1, 0
