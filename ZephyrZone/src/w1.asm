; =====================================================================
;  w1.asm - WORLD 1: CHECKER PLAINS  (module loaded at W_CODE in upper bank 1)
;  sprites: 16 lolly tree, 17 candy column, 18 bush, 19 BLOBBIT,
;           20 SPINDLE, 21 HOPCAP, 22-24 COILWYRM head / body / tail
; =====================================================================
            include "../build/mainsym.inc"
            org W_CODE
            jp boss_start
            jp upd_boss
            jp upd_bseg
            jp boss_hit
            dw timeline
            db 14,76, 10,100            ; tree: radius, height ; column
            dw 0                    ; (no in-game music)
            dw 0
            db "CHECKER PLAINS  ",0
            db "COILWYRM        ",0
            db 14,14,14
            dw galnames
            assert $ == W_HDREND

NSEG        equ 8
SP_XAMP     equ 210
SP_YBASE    equ 70
SP_YAMP     equ 45
SP_ZBASE    equ 380
SP_ZAMP     equ 120
SP_HR       equ 26
SP_SEGHR    equ 18
            include "serpent.inc"

S_BLOBBIT   equ S_EN1
S_SPINDLE   equ S_EN2
S_HOPCAP    equ S_EN3
; the stage timeline
;           time, EV_WAVE, pattern, sprite, count, x/4, y, amp, speed, fire, pts/10, hp
            include "gallery.inc"
            jp gal_show
galnames:
            db "LOLLY TREE",0
            db "CANDY COLUMN",0
            db "BUSH",0
            db "BLOBBIT",0
            db "SPINDLE",0
            db "HOPCAP",0
            db "COILWYRM",0
            db "",0
            db "",0

timeline:
            dw 10
            db EV_MSG,M_STAGE
            dw 110
            db EV_MSG,M_NAME1
            dw 324
            db EV_WAVE,P_LINE,S_BLOBBIT,3,0,40,20,22,200,10,1
            dw 567
            db EV_WAVE,P_SNAKE,S_BLOBBIT,5,-20,50,110,24,200,10,1
            dw 864
            db EV_WAVE,P_HOP,S_HOPCAP,4,10,0,70,20,200,12,2
            dw 1161
            db EV_WAVE,P_LINE,S_SPINDLE,5,0,70,30,22,120,15,1
            dw 1458
            db EV_WAVE,P_CROSS,S_BLOBBIT,6,0,60,110,22,200,10,1
            dw 1755
            db EV_SCEN,40,7
            dw 1782
            db EV_WAVE,P_SWOOP,S_SPINDLE,4,-60,60,40,22,200,15,1
            dw 1998
            db EV_WAVE,P_SWOOP,S_SPINDLE,4,60,80,40,22,200,15,1
            dw 2268
            db EV_WAVE,P_DIVE,S_BLOBBIT,4,0,150,60,22,140,12,1
            dw 2565
            db EV_WAVE,P_RING,S_BLOBBIT,6,0,60,90,20,200,10,1
            dw 2902
            db EV_WAVE,P_HOP,S_HOPCAP,6,-20,0,80,22,200,12,2
            dw 3172
            db EV_SCEN,34,2
            dw 3213
            db EV_WAVE,P_LINE,S_BLOBBIT,5,0,30,25,24,110,10,1
            dw 3510
            db EV_WAVE,P_SPIRAL,S_SPINDLE,8,0,70,100,22,130,15,1
            dw 3847
            db EV_WAVE,P_SNAKE,S_BLOBBIT,6,-30,60,120,26,200,10,1
            dw 3915
            db EV_WAVE,P_DIVE,S_SPINDLE,3,40,160,40,22,100,15,1
            dw 4252
            db EV_SCEN,60,1
            dw 4320
            db EV_MSG,M_WARN
            dw 4326
            db EV_SFX,SFX_WARN
            dw 4441
            db EV_SFX,SFX_WARN
            dw 4495
            db EV_MSG,M_BOSS1
            dw 4536
            db EV_BOSS
            dw $FFFF
