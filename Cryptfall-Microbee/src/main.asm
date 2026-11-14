; =====================================================================
;  CRYPTFALL
;  a cave-digging game of falling stone for the Microbee Premium Plus
;  VIBED BY BPM 2026
; =====================================================================
        INCLUDE "defs.inc"
        INCLUDE "tiles.inc"

        ORG $0100
entry:  di
        ld sp,STACK
        call hw_init
        jp start

        INCLUDE "hw.asm"
        INCLUDE "input.asm"
        INCLUDE "video.asm"
        INCLUDE "sound.asm"
        INCLUDE "disk.asm"
        INCLUDE "logic.asm"
        INCLUDE "game.asm"
        INCLUDE "front.asm"
        INCLUDE "music.inc"
        INCLUDE "gfxdata.inc"
        ALIGN 256
tflags: INCLUDE "tflags.inc"
hibuf:  ds 128
code_end:
        ASSERT code_end <= CAVE
        SAVEBIN "../build/CRYPT.COM",$0100,code_end-$0100
        DISPLAY "code end: ",code_end

        ORG VARS
        INCLUDE "vars.asm"
        ASSERT vars_end <= STACK-512
        DISPLAY "vars end: ",vars_end
