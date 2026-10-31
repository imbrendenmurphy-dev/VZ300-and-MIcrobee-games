; =====================================================================
;  THE LANTERN DEEP
;  An original dungeon adventure for the Microbee Premium Plus
;  VIBED BY BPM - 2026
; =====================================================================
            DEVICE NOSLOT64K
            INCLUDE "layout.inc"

; ---------------------------------------------------------------------
; Lower (home) block: 0000-7FFF
; ---------------------------------------------------------------------
            ORG $0000
            di
            jp entry
            ORG $0038
            ei                              ; no interrupt source is enabled
            reti

            ORG $0500                       ; loader hand-off area (reserved)
            DS 16

            ORG $0600
entry:      di
            ld sp,STACK
            im 1
            call hw_init
            call mem_probe
            ld a,BLK_GFX
            call pcg_load_all
            call monitor_ask
            jp title_screen

            INCLUDE "game.asm"
            INCLUDE "gen/world.asm"
            INCLUDE "gen/title_data.asm"
            INCLUDE "gen/tmus.asm"
            INCLUDE "gen/speech.asm"
            INCLUDE "title.asm"
lower_end:
            ASSERT lower_end <= TILE, "lower code overlaps the map arrays"

; ---------------------------------------------------------------------
; Upper (fixed) block: 8000-97FF code, 9800-B5FF region tables,
; B600-BEFF room record, BF00 entities, C000-EFFF work areas
; ---------------------------------------------------------------------
            ORG $8000
            INCLUDE "core.asm"
            INCLUDE "sound.asm"
            INCLUDE "disk.asm"
            INCLUDE "demo.asm"
            INCLUDE "gen/savemap.asm"
            INCLUDE "gen/audio.asm"
upper_end:
            ASSERT upper_end <= REGTAB, "upper code overlaps the region tables"
            ORG $BF00
ENTS:       DS 256

            DISPLAY "lower end: ",/A,lower_end,"  upper end: ",/A,upper_end
            SAVEBIN "../build/LANTERN.LO",$0000,$3400
            SAVEBIN "../build/LANTERN.HI",$8000,$1A00
            SAVEBIN "../build/image.bin",$0000,$10000
