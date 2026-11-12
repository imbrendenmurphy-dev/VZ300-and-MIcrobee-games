; =====================================================================
;  FRILLSEEKER - VIBED BY BPM 2026
;  an original mascot platform game for the Microbee Premium Plus
;  (1MB RAM, 32K PCG). Engine prototype.
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"

        ORG $8000
entry:  di
        ld sp,STACK
        MEMV BLK_WORK
        call hw_init
        ld hl,hook_none
        ld (tw_hook),hl
        jp monitor_select

        INCLUDE "engine.asm"
        INCLUDE "anim.asm"
        INCLUDE "game.asm"
        INCLUDE "sound.asm"
        INCLUDE "tables.inc"
        INCLUDE "regions.inc"
        INCLUDE "snd.inc"
        INCLUDE "sprtab.inc"
prog_end:
        ASSERT prog_end <= COLSH
        INCLUDE "vars.asm"
        SAVEBIN "../build/FRILL.BIN",$8000,prog_end-$8000
