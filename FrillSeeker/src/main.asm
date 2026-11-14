; =====================================================================
;  FRILLSEEKER - VIBED BY BPM 2026
;  an original mascot platform game for the Microbee Premium Plus
;  (1MB RAM, 32K PCG). Engine prototype.
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"

        ORG $8000
entry:  jr start
        nop
boot_mono: db 0                 ; 8003h: the loader puts the monitor here (1 = monochrome)
start:  di
        ld sp,STACK
        MEMV BLK_WORK
        call hw_init
        ld a,(boot_mono)
        ld (mono),a
        ld a,BLK_ROOM
        ld (roomblk0),a
        jp title_screen

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
        INCLUDE "front.asm"
        SAVEBIN "../build/FRONT.BNK",$0000,front_end
