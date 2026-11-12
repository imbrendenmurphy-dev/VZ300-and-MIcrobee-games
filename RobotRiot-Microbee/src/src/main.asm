; =====================================================================
;  ROBOT RIOT 2086
;  a single-screen arena shooter for the Microbee Premium Plus.
;  The robot factories have risen; one cyborg hero, the last human family.
;  VIBED BY BPM 2026
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"
        INCLUDE "gen.inc"

DL0     equ $D000               ; draw lists (252 cells x 6 bytes)
DL1     equ $D600
VARS    equ $DC00
BGMAP   equ $CC00               ; 1K: what an erased cell goes back to
STACK   equ $EFFE

        ORG $8000
entry:  di
        ld sp,STACK
        call hw_init
        jp start

        INCLUDE "core.asm"
        INCLUDE "input.asm"
        INCLUDE "render.asm"
        INCLUDE "sound.asm"
        INCLUDE "game.asm"
        INCLUDE "actors.asm"
        INCLUDE "fx.asm"
        INCLUDE "attract.asm"
        INCLUDE "music.inc"
        INCLUDE "tables.inc"
code_end:
        ASSERT code_end <= BGMAP
        SAVEBIN "../build/RR.BIN",$8000,code_end-$8000
        DISPLAY "code end: ",code_end

        ORG VARS
        INCLUDE "vars.asm"
        ASSERT vars_end <= STACK-256
        DISPLAY "vars end: ",vars_end
