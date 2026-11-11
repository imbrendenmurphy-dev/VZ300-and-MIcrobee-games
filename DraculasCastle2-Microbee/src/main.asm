; ===========================================================================
;  DRACULA'S CASTLE II - THE CASTLE AWAKENS      ViBED by BPM 2026
;  Dick Smith VZ300 + BennVenn SD + 128K, mode 1
; ===========================================================================
            include "gen/debug.inc"
            include "vars.asm"
            org $8000
entry:      di
            ld sp,STACK_TOP
            jp boot

            include "sys.asm"
            include "mb_hw.asm"
            include "music.asm"
            include "text.asm"
            include "view.asm"
            include "boot.asm"
            include "explore.asm"
            include "battle.asm"
            include "screens.asm"
            include "title.asm"
            include "egg.asm"
            include "sd.asm"

            include "gen/geom.inc"
            include "data.asm"
code_end:
            assert code_end <= VPBUF
