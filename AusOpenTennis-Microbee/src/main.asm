; =====================================================================
;  MICROBEE AUSTRALIAN OPEN TENNIS
;  for the Microbee Premium Plus (1MB RAM, 32K PCG RAM)
;  the Microbee edition of TENNIS II - GRAND SLAM.  VIBED BY BPM 2026
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"
TABLES  equ $D400               ; page-aligned tables
cur_lo  equ TABLES              ; background: glyph low codes (80h+n)
cur_hi  equ TABLES+$400         ;   banks
cur_col equ TABLES+$800         ;   colours (paper << 4 | ink)
cellmap equ TABLES+$C00         ; pool glyph + 1 of each cell this frame
nc_lo   equ TABLES+$1000        ; pool glyph k: its cell's low byte,
nc_q    equ TABLES+$1100        ;   quarter,
nc_ink  equ TABLES+$1200        ;   ink
rs_tmp  equ TABLES+$1300        ; restored cells of a quarter (256)
lzx_buf equ rs_tmp              ; (also the unpacker's and blk_copy's buffer)
bounce  equ rs_tmp
VARS    equ TABLES+$1400
STACK   equ $EFFE

UCALL   MACRO target
        push hl
        ld hl,target
        ld (kb_tgt),hl
        pop hl
        call upc
        ENDM

        ORG $8000
entry:  di
        ld sp,STACK
        call hw_init
        jp start

        INCLUDE "core.asm"
        INCLUDE "render.asm"
        INCLUDE "math.asm"
        INCLUDE "sound.asm"
        INCLUDE "match.asm"
        INCLUDE "draw.asm"
        INCLUDE "court.asm"
        INCLUDE "services.asm"
        INCLUDE "save.asm"
        INCLUDE "boot.asm"
        INCLUDE "sprtab.inc"
        INCLUDE "courts.inc"
        INCLUDE "gfx.inc"
        INCLUDE "music.inc"
        INCLUDE "projtab.inc"
        ASSERT $ <= NOISETAB
        ORG NOISETAB
        INCLUDE "noise.inc"
code_end:
        ASSERT code_end <= TABLES
        SAVEBIN "../build/AOT.BIN",$8000,code_end-$8000
        DISPLAY "code end: ",code_end

        INCLUDE "front.asm"

        ORG VARS
        INCLUDE "vars.asm"
vars_end:
        ASSERT vars_end <= STACK-200
        DISPLAY "vars end: ",vars_end
