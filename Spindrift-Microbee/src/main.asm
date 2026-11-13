; =====================================================================
;  SPINDRIFT - an arcade shooter for the Microbee Premium Plus
;  VIBED BY BPM 2026
;
;  Sweep round the rim of the vortex and shoot inward as the swarm
;  spirals out of deep space. 1MB RAM, 32K PCG, the 40-column mode.
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"

        ORG $8000
entry:  di
        ld sp,STACK
        call hw_init
        ld hl,hitab+3
        ld de,hiscore
        ld bc,3
        ldir
        ld a,SHAPE_CRT
        call set_shape
        call monitor_ask
        call shape_ask
.main:  call attract
        xor a
        ld (demo),a
        call play_game
        jr .main

        INCLUDE "engine.asm"
        INCLUDE "sound.asm"
        INCLUDE "input.asm"
        INCLUDE "util.asm"
        INCLUDE "enemy.asm"
        INCLUDE "game.asm"
        INCLUDE "boss.asm"
        INCLUDE "front.asm"
        INCLUDE "shape.asm"
        INCLUDE "data.asm"
        INCLUDE "gen.inc"
        INCLUDE "snd.inc"
prog_end:
        ASSERT prog_end <= CELLHI
        DISPLAY "program ends ", prog_end
        INCLUDE "vars.asm"
        SAVEBIN "../build/SPIN.BIN",$8000,prog_end-$8000
