; =====================================================================
;  w2.asm - WORLD 2: SUNSET DUNES  (module loaded at W_CODE in upper bank 1)
;  sprites: 16 saguaro, 17 obelisk, 18 rock, 19 SANDRAY, 20 SUNDISC, 21 CACTOID, 22-24 SUN TOTEM core / fire pod / (spare)
; =====================================================================
            include "../build/mainsym.inc"
            org W_CODE
            jp boss_start
            jp upd_boss
            jp upd_bseg
            jp boss_hit
            dw timeline
            db 14,70, 10,60
            dw 0                    ; (no in-game music)
            dw 0
            db "SUNSET DUNES    ",0
            db "SUN TOTEM       ",0
            db 16,16,14
            dw galnames
            assert $ == W_HDREND

NSEG        equ 6
SP_XAMP     equ 150
SP_YBASE    equ 70
SP_YAMP     equ 40
SP_ZBASE    equ 420
SP_ZAMP     equ 90
SP_HR       equ 28
SP_SEGHR    equ 12
TO_R        equ 100
            include "totem.inc"

; the stage timeline
;           time, EV_WAVE, pattern, sprite, count, x/4, y, amp, speed, fire, pts/10, hp
            include "gallery.inc"
            jp gal_show
galnames:
            db "SAGUARO",0
            db "OBELISK",0
            db "ROCK",0
            db "SANDRAY",0
            db "SUNDISC",0
            db "CACTOID",0
            db "SUN TOTEM",0
            db "FIRE POD",0
            db "",0

timeline:
            dw 10
            db EV_MSG,M_STAGE
            dw 110
            db EV_MSG,M_NAME1
            dw 324
            db EV_WAVE,P_SNAKE,S_EN1,4,0,50,110,22,200,12,1
            dw 594
            db EV_WAVE,P_HOP,S_EN3,4,-20,0,70,20,200,12,2
            dw 864
            db EV_WAVE,P_RING,S_EN2,6,0,70,90,22,140,15,1
            dw 1161
            db EV_WAVE,P_CROSS,S_EN1,6,0,50,120,24,200,12,1
            dw 1458
            db EV_SCEN,36,7
            dw 1485
            db EV_WAVE,P_SWOOP,S_EN1,4,-60,70,40,24,130,12,1
            dw 1701
            db EV_WAVE,P_SWOOP,S_EN1,4,60,40,40,24,130,12,1
            dw 1971
            db EV_WAVE,P_HOP,S_EN3,6,20,0,90,22,200,12,2
            dw 2268
            db EV_WAVE,P_SPIRAL,S_EN2,8,0,80,100,22,120,15,1
            dw 2619
            db EV_WAVE,P_DIVE,S_EN1,4,0,160,60,24,120,12,1
            dw 2889
            db EV_SCEN,30,2
            dw 2916
            db EV_WAVE,P_LINE,S_EN2,5,0,40,30,26,100,15,1
            dw 3213
            db EV_WAVE,P_CROSS,S_EN1,8,0,60,130,24,140,12,1
            dw 3537
            db EV_WAVE,P_HOP,S_EN3,6,-30,0,110,24,200,12,2
            dw 3834
            db EV_WAVE,P_RING,S_EN2,8,0,60,100,24,110,15,1
            dw 3888
            db EV_WAVE,P_DIVE,S_EN1,3,40,160,40,24,100,12,1
            dw 4212
            db EV_SCEN,60,1
            dw 4279
            db EV_MSG,M_WARN
            dw 4286
            db EV_SFX,SFX_WARN
            dw 4401
            db EV_SFX,SFX_WARN
            dw 4455
            db EV_MSG,M_BOSS1
            dw 4495
            db EV_BOSS
            dw $FFFF
