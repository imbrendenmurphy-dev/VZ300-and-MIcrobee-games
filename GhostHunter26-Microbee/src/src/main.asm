; =====================================================================
;  GHOST HUNTER '26
;  a maze chase for the Microbee Premium Plus (1MB RAM, 32K PCG),
;  in the full-screen 40-column mode: 320 x 250 (40 x 25 cells of 8 x 10), sixteen colours, every cell its own
;  ink and paper. Four ghosts with minds of their own, six haunted mazes,
;  power-ups, treasures, bonus rounds and a hunter with three hearts.
;  VIBED BY BPM 2026
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"
        INCLUDE "tiles.inc"
        INCLUDE "gfx.inc"

TABLES  equ $D000               ; page-aligned tables
cur_lo  equ TABLES              ; screen: glyph low codes (80h+n)
cur_hi  equ TABLES+$400         ;   banks
cur_col equ TABLES+$800         ;   colours (paper << 4 | ink)
cellmap equ TABLES+$C00         ; pool glyph + 1 of each cell this frame
nc_lo   equ TABLES+$1000        ; pool glyph k: its cell's low byte,
nc_q    equ TABLES+$1100        ;   quarter,
nc_ink  equ TABLES+$1200        ;   ink
rs_tmp  equ TABLES+$1300        ; restored cells of a quarter (256)
bounce  equ rs_tmp
VARS    equ TABLES+$1400        ; E400h
STACK   equ $EFFE

        ORG $8000
entry:  di
        ld sp,STACK
        call hw_init
        jp start

        INCLUDE "core.asm"
        INCLUDE "input.asm"
        INCLUDE "render.asm"
        INCLUDE "sound.asm"
        INCLUDE "game.asm"
        INCLUDE "ghosts.asm"
        INCLUDE "front.asm"
        INCLUDE "music.inc"
        INCLUDE "sprtab.inc"
        INCLUDE "tiledata.inc"
code_end:
; the maze in play (copied from the MAZE block each round)
dmap:   ds 23*64                ; dots on the lattice of cell corners: 1 dot, 2 energiser
edges:  ds 91                   ; lanes out of each node: 1 R, 2 L, 4 U, 8 D
home:   ds 91                   ; the way back to the pen door from each node
maps_end:
        ALIGN 256
div10:  ds 256                  ; y / 10   (render: cell row of a pixel line)
div10r: ds 256                  ; y % 10
tabs_end:
        ASSERT tabs_end <= TABLES
        SAVEBIN "../build/GH.BIN",$8000,code_end-$8000
        DISPLAY "code end: ",code_end
        DISPLAY "maps end: ",maps_end

        ORG VARS
        INCLUDE "vars.asm"
        ASSERT vars_end <= STACK-256
        DISPLAY "vars end: ",vars_end
