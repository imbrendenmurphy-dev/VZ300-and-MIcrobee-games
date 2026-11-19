; =====================================================================
;  OVERRIDE                                        ViBED by BPM 2026
;  Dick Smith VZ300 + BennVenn SD + 128K, mode 1 (128x64, 4 colours)
;  main program (OVERRIDE.VZ, $8000) + upper bank 1 data (OVCOM.DAT)
; =====================================================================
            include "defs.asm"
            include "gen/consts.inc"
            include "vars.asm"
            org CODE
entry:      di
            ld sp,STACK_TOP
            jp boot

            include "sys.asm"
            include "sd.asm"
            include "ring.asm"
            include "sprite.asm"
            include "text.asm"
            include "deck.asm"
            include "droid.asm"
            include "player.asm"
            include "shots.asm"
            include "hud.asm"
            include "sound.asm"
            include "game.asm"
            include "demo.asm"
            include "boot.asm"
            include "gen/tables.inc"
code_end:
            assert code_end <= VARS

; ---------------------------------------------------------------------
;  upper bank 1 (mapping 7), loaded from OVCOM.DAT
; ---------------------------------------------------------------------
            org FECODE
            include "gen/copy.inc"
            include "gen/gfxdata.inc"
            include "gmusic.asm"
upper_end:
            assert upper_end <= WPT
