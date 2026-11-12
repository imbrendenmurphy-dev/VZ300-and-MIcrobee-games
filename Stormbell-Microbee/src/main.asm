; =====================================================================
;  STORMBELL - VIBED BY BPM 2026
;  an original martial arts duelling game for the Microbee Premium Plus
;  (1MB RAM, 32K PCG, 40-column mode).
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"

        ORG $8000
entry:  di
        ld sp,STACK
        call hw_init
        jp title

        INCLUDE "video.asm"
        INCLUDE "render.asm"
        INCLUDE "input.asm"
        INCLUDE "sound.asm"
        INCLUDE "fight.asm"
        INCLUDE "game.asm"
        INCLUDE "ftab.inc"
        INCLUDE "snd.inc"
prog_end:
        ASSERT prog_end <= WANT
        INCLUDE "vars.asm"
        SAVEBIN "../build/STORM.BIN",$8000,prog_end-$8000
