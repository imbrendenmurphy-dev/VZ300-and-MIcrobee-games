; =====================================================================
;  w5.asm - WORLD 5: MUSHROOM MARSH  (module loaded at W_CODE in upper bank 1)
;  sprites: 16 toadstool, 17 moss stone, 18 puffballs, 19 STONEFACE, 20 BUZZWING, 21 SNAILOPS, 22-24 BOGAPEDE head / body / tail
; =====================================================================
            include "../build/mainsym.inc"
            org W_CODE
            jp boss_start
            jp upd_boss
            jp upd_bseg
            jp boss_hit
            dw timeline
            db 20,62, 10,60
            dw 0                    ; (no in-game music)
            dw 0
            db "MUSHROOM MARSH  ",0
            db "BOGAPEDE        ",0
            db 16,16,28
            dw galnames
            assert $ == W_HDREND

NSEG        equ 12
SP_XAMP     equ 200
SP_YBASE    equ 40
SP_YAMP     equ 35
SP_ZBASE    equ 380
SP_ZAMP     equ 120
SP_HR       equ 24
SP_SEGHR    equ 16
            include "serpent.inc"

            include "gallery.inc"
            jp gal_show
galnames:
            db "TOADSTOOL",0
            db "MOSS STONE",0
            db "PUFFBALLS",0
            db "STONEFACE",0
            db "BUZZWING",0
            db "SNAILOPS",0
            db "BOGAPEDE",0
            db "",0
            db "",0

; the stage timeline
;           time, EV_WAVE, pattern, sprite, count, x/4, y, amp, speed, fire, pts/10, hp
timeline:
            dw 10
            db EV_MSG,M_STAGE
            dw 110
            db EV_MSG,M_NAME1
            dw 320
            db EV_WAVE,P_LINE,S_EN1,3,0,50,40,18,150,15,2
            dw 620
            db EV_WAVE,P_SNAKE,S_EN2,5,-20,60,110,24,200,12,1
            dw 920
            db EV_WAVE,P_HOP,S_EN3,1,0,0,2,12,200,30,6
            dw 1220
            db EV_WAVE,P_RING,S_EN2,6,0,70,90,22,200,12,1
            dw 1500
            db EV_SCEN,34,7
            dw 1520
            db EV_WAVE,P_CROSS,S_EN1,4,0,40,120,20,140,15,2
            dw 1820
            db EV_WAVE,P_HOP,S_EN3,2,0,0,2,12,200,30,6
            dw 2120
            db EV_WAVE,P_SPIRAL,S_EN2,8,0,80,100,22,200,12,1
            dw 2420
            db EV_WAVE,P_DIVE,S_EN1,4,0,150,60,22,120,15,2
            dw 2700
            db EV_SCEN,28,2
            dw 2720
            db EV_WAVE,P_SWOOP,S_EN2,6,60,60,40,24,200,12,1
            dw 3020
            db EV_WAVE,P_HOP,S_EN3,3,0,0,2,12,200,30,6
            dw 3320
            db EV_WAVE,P_LINE,S_EN1,5,0,30,25,22,110,15,2
            dw 3720
            db EV_SCEN,60,1
            dw 3770
            db EV_MSG,M_WARN
            dw 3775
            db EV_SFX,SFX_WARN
            dw 3860
            db EV_SFX,SFX_WARN
            dw 3900
            db EV_MSG,M_BOSS1
            dw 3930
            db EV_BOSS
            dw $FFFF
