; =====================================================================
;  ROGUE MUSTER
;  a single-screen arena shooter for the Microbee Premium Plus
;  Koolabah Station, 2186: the mustering machines have gone rogue.
;  VIBED BY BPM 2026
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"
        INCLUDE "gen.inc"

DL0     equ $D000               ; draw lists (252 cells x 6 bytes)
DL1     equ $D600
VARS    equ $DC00
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
        INCLUDE "front.asm"
        INCLUDE "music.inc"
        INCLUDE "tables.inc"
code_end:
        ASSERT code_end <= DL0
        SAVEBIN "../build/RM.BIN",$8000,code_end-$8000
        DISPLAY "code end: ",code_end

        ORG VARS
        INCLUDE "vars.asm"
        ASSERT vars_end <= STACK-256
        DISPLAY "vars end: ",vars_end
