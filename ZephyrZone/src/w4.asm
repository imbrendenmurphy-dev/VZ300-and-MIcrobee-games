; =====================================================================
;  w4.asm - WORLD 4: NEON CITY  (module loaded at W_CODE in upper bank 1)
;  sprites: 16 tower, 17 neon sign, 18 barrier, 19 DARTJET, 20 COPSAUCER, 21 GUNMECH, 22-24 MEGAMECH head / gun pod / link
; =====================================================================
            include "../build/mainsym.inc"
            org W_CODE
            jp boss_start
            jp upd_boss
            jp upd_bseg
            jp boss_hit
            dw timeline
            db 10,90, 10,66
            dw 0                    ; (no in-game music)
            dw 0
            db "NEON CITY       ",0
            db "MEGAMECH        ",0
            db 14,16,30
            dw galnames
            assert $ == W_HDREND

NSEG        equ 6
SP_XAMP     equ 170
SP_YBASE    equ 75
SP_YAMP     equ 35
SP_ZBASE    equ 420
SP_ZAMP     equ 100
SP_HR       equ 30
SP_SEGHR    equ 10
TO_R        equ 110
            include "totem.inc"

            include "gallery.inc"
            jp gal_show
galnames:
            db "TOWER",0
            db "NEON SIGN",0
            db "BARRIER",0
            db "DARTJET",0
            db "COPSAUCER",0
            db "GUNMECH",0
            db "MEGAMECH",0
            db "GUN POD",0
            db "",0

; the stage timeline
;           time, EV_WAVE, pattern, sprite, count, x/4, y, amp, speed, fire, pts/10, hp
timeline:
            dw 10
            db EV_MSG,M_STAGE
            dw 110
            db EV_MSG,M_NAME1
            dw 320
            db EV_WAVE,P_LINE,S_EN1,5,0,60,30,24,200,12,1
            dw 620
            db EV_WAVE,P_HOP,S_EN3,1,0,0,6,14,150,30,6
            dw 920
            db EV_WAVE,P_CROSS,S_EN1,6,0,50,120,24,200,12,1
            dw 1220
            db EV_WAVE,P_RING,S_EN2,6,0,70,90,22,130,15,1
            dw 1500
            db EV_SCEN,34,7
            dw 1520
            db EV_WAVE,P_SWOOP,S_EN1,5,-60,70,40,24,200,12,1
            dw 1820
            db EV_WAVE,P_HOP,S_EN3,2,0,0,6,14,140,30,6
            dw 2120
            db EV_WAVE,P_SPIRAL,S_EN2,8,0,80,100,22,120,15,1
            dw 2420
            db EV_WAVE,P_DIVE,S_EN1,5,0,160,60,24,200,12,1
            dw 2700
            db EV_SCEN,28,2
            dw 2720
            db EV_WAVE,P_SNAKE,S_EN2,6,20,50,120,24,110,15,1
            dw 3020
            db EV_WAVE,P_HOP,S_EN3,3,0,0,6,14,130,30,6
            dw 3320
            db EV_WAVE,P_CROSS,S_EN1,8,0,60,130,26,200,12,1
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
