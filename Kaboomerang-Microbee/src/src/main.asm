; =====================================================================
;  KABOOMERANG
;  an arcade game for the Microbee Premium Plus (1MB RAM, 32K PCG)
;  Wally the demolition wombat versus Baron Von Croak.
;  ViBED by BPM 2026
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
        INCLUDE "actors.asm"
        INCLUDE "front.asm"
        INCLUDE "music.inc"
        INCLUDE "sprtab.inc"
        INCLUDE "tiledata.inc"
code_end:
; the arena maps (11 rows of 32): kept in the program area, cleared per stage
        ALIGN 256
amap:   ds 352                  ; 0 floor 1 border 2 pillar 3 mound 4 burrow
imap:   ds 352                  ; item (1 fire 2 nut 3 heart 4 thongs 5 exit), b7 hidden
bmap:   ds 352                  ; bomb number + 1
fmap:   ds 352                  ; flame time left
fkind:  ds 352                  ; flame kind
cmap:   ds 352                  ; crumble time
wmap:   ds 352                  ; blast preview: b0 shown, b1 wanted
maps_end:
        ASSERT maps_end <= TABLES
        SAVEBIN "../build/KB.BIN",$8000,code_end-$8000
        DISPLAY "code end: ",code_end
        DISPLAY "maps end: ",maps_end

        ORG VARS
        INCLUDE "vars.asm"
        ASSERT vars_end <= STACK-256
        DISPLAY "vars end: ",vars_end
