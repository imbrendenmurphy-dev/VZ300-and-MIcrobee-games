; =====================================================================
;  w3.asm - WORLD 3: CRYSTAL NIGHT  (module loaded at W_CODE in upper bank 1)
;  sprites: 16 crystal spire, 17 gem rock, 18 glowcaps, 19 GLOWMOTH, 20 PRISM, 21 JELLYBELL, 22-24 SHARDWYRM head / body / tail
; =====================================================================
            include "../build/mainsym.inc"
            org W_CODE
            jp boss_start
            jp upd_boss
            jp upd_bseg
            jp boss_hit
            dw timeline
            db 14,72, 14,22
            dw 0                    ; (no in-game music)
            dw 0
            db "CRYSTAL NIGHT   ",0
            db "SHARDWYRM       ",0
            db 16,12,14
            dw galnames
            assert $ == W_HDREND

NSEG        equ 10
SP_XAMP     equ 230
SP_YBASE    equ 80
SP_YAMP     equ 55
SP_ZBASE    equ 360
SP_ZAMP     equ 130
SP_HR       equ 26
SP_SEGHR    equ 18
            include "serpent.inc"

; the stage timeline
;           time, EV_WAVE, pattern, sprite, count, x/4, y, amp, speed, fire, pts/10, hp
            include "gallery.inc"
            jp gal_show
galnames:
            db "CRYSTAL SPIRE",0
            db "GEM ROCK",0
            db "GLOWCAPS",0
            db "GLOWMOTH",0
            db "PRISM",0
            db "JELLYBELL",0
            db "SHARDWYRM",0
            db "",0
            db "",0

timeline:
            dw 10
            db EV_MSG,M_STAGE
            dw 110
            db EV_MSG,M_NAME1
            dw 324
            db EV_WAVE,P_CROSS,S_EN1,6,0,60,110,24,200,12,1
            dw 621
            db EV_WAVE,P_SPIRAL,S_EN2,8,0,70,100,24,130,15,1
            dw 945
            db EV_WAVE,P_HOP,S_EN3,5,0,0,80,22,200,12,2
            dw 1215
            db EV_WAVE,P_SNAKE,S_EN1,6,-20,40,130,26,140,12,1
            dw 1512
            db EV_SCEN,32,7
            dw 1539
            db EV_WAVE,P_DIVE,S_EN2,4,0,160,60,26,110,15,1
            dw 1809
            db EV_WAVE,P_SWOOP,S_EN1,5,-60,70,40,26,120,12,1
            dw 2025
            db EV_WAVE,P_SWOOP,S_EN1,5,60,40,40,26,120,12,1
            dw 2322
            db EV_WAVE,P_RING,S_EN2,8,0,70,100,24,100,15,1
            dw 2646
            db EV_WAVE,P_HOP,S_EN3,6,30,0,100,24,150,12,2
            dw 2943
            db EV_SCEN,28,2
            dw 2970
            db EV_WAVE,P_CROSS,S_EN1,8,0,50,140,26,120,12,1
            dw 3294
            db EV_WAVE,P_SPIRAL,S_EN2,8,0,90,100,24,100,15,1
            dw 3645
            db EV_WAVE,P_LINE,S_EN1,6,0,30,25,28,90,12,1
            dw 3915
            db EV_WAVE,P_DIVE,S_EN2,4,-40,160,40,26,90,15,1
            dw 4266
            db EV_SCEN,60,1
            dw 4333
            db EV_MSG,M_WARN
            dw 4340
            db EV_SFX,SFX_WARN
            dw 4455
            db EV_SFX,SFX_WARN
            dw 4509
            db EV_MSG,M_BOSS1
            dw 4549
            db EV_BOSS
            dw $FFFF
