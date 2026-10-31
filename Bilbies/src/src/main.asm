; ---------------------------------------------------------------------------
; BILBIES!  for the VZ300 + BennVenn SD loader / 128K
; an original puzzle game: guide the bilbies home
; ---------------------------------------------------------------------------
        DEVICE NOSLOT64K
        INCLUDE "equ.asm"
        INCLUDE "vars.asm"

        ORG CODE
code_start:
        INCLUDE "core.asm"
        INCLUDE "game.asm"
        INCLUDE "level.asm"
        INCLUDE "play.asm"
        INCLUDE "render.asm"
        INCLUDE "gfx.asm"
        INCLUDE "panel.asm"
        INCLUDE "front.asm"
        INCLUDE "music.asm"
        INCLUDE "sound.asm"
        INCLUDE "data.asm"
code_end:
        ASSERT code_end <= MASK
        DISPLAY "code end: ",/A,code_end
        SAVEBIN "../build/mem.bin",VARS,$10000-VARS
