; =====================================================================
;  ZEPHYR ZONE                                  ViBED by BPM 2026
;  Dick Smith VZ300 + BennVenn SD + 128K, mode 1 (128x64, 4 colours)
; =====================================================================
            include "defs.asm"
            include "vars.asm"
            include "gen/speech.inc"
            org $8000
entry:      di
            ld sp,STACK_TOP
            jp boot

            include "sys.asm"
            include "sd.asm"
            include "ground.asm"
            include "sprite.asm"
            include "obj.asm"
            include "game.asm"
            include "enemy.asm"
            include "hud.asm"
            include "sound.asm"
            include "play.asm"
            include "boot.asm"
            include "gen/sine.inc"
            include "gen/ready.inc"
            include "gen/buildid.inc"
code_end:
            assert code_end <= VARS
            include "fe.asm"
