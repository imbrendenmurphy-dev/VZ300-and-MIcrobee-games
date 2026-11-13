; =====================================================================
;  BIX THE BILBY - THE STAR DIGGER          VIBED BY BPM 2026
;  for the Microbee Premium Plus (1MB RAM, 32K PCG)
;  a native version of the VZ300 game: prototype, world 1-1
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"
        INCLUDE "gen.inc"

; ---- the engine: block 0, always in view
        ORG $8000
entry:  di
        ld sp,STACK
        ld a,1
        call map_blk
        call hw_init
        call map_game
        jp g_start
        INCLUDE "engine.asm"
        INCLUDE "sound.asm"
        INCLUDE "sprtab.inc"
        INCLUDE "snd.inc"
prog_end:
        ASSERT prog_end <= VARS
        INCLUDE "vars.inc"
        SAVEBIN "../build/BIX.BIN",$8000,prog_end-$8000

; ---- the game: block BLK_GAME in the lower window
        ORG $0100
        INCLUDE "game.asm"
        INCLUDE "logic.asm"
        ALIGN 256
tattr:  INCBIN "../build/tattr.bin"
ENTLIST0: INCBIN "../build/ents.bin"
MAP0:   INCBIN "../build/tmap.bin"
game_end:
MAP     EQU $6000               ; the tile map in play: 12 tiles a column
        ASSERT game_end <= MAP
        ASSERT MAP + MAPLEN <= $7000
POOL    EQU $7000               ; entities, NENT x 16
ENTST   EQU $7100               ; a state for each spawn record
        SAVEBIN "../build/GAME.BNK",$0100,game_end-$0100
