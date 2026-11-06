; ============================================================================
;  GRAVES 'N' GARGOYLES  -  Sir Tinplate's Long Night
;  A gothic fantasy arcade platform adventure for the Dick Smith VZ300
;  Target: VZ300 + BennVenn SD loader + 128K SRAM.  Mode 1 (128x64 4-colour)
;  (c) 2026  ViBED by BPM
; ============================================================================
;
;  MEMORY MAP
;   $4000-$4A7F  SRAM bank B  background ring, phase 0 (56 rows x 48 bytes)
;   $4A80-$54FF  SRAM bank B  background ring, phase 2 (shifted 2 pixels)
;                (the title art is unpacked here while the front end runs)
;   $5500-$60FF  SRAM bank B  frame blit routine (copied there at start-up)
;   $6100-$66FF  SRAM bank B  hero layered class data
;   $7000-$77FF  video RAM (rows 0-7 HUD, rows 8-63 playfield)
;   $7800-$7900  IM2 vector table (257 x $79) -> ISR stub at $7979
;   $797C-$7AFF  stack
;   $7B00-$7BFF  HUD buffer  $7C00 hero colour lookup  $7D00 FB row table
;   $7E00-$7EFF  FLIP table
;   $8000-       program + data (the tail of the load image holds the SRAM
;                blobs; after start-up that space becomes variables + FB)
;   FB           frame buffer 64 rows x 40 bytes (4 margin bytes each side)
;
LATCH    equ $6800
VRAM     equ $7000
RING0    equ $4000
RING2    equ $4A80
RINGW    equ 48
TITLEBUF equ $4000
LOGOBUF  equ $4800      ; logo sprite (mask+data) rebuilt here for the front end
IM2TAB   equ $7800
ISRJP    equ $7979
STACKTOP equ $7B00
HUDBUF   equ $7B00      ; 12 rows: 8 top + 4 bottom
HLUT     equ $7C80
YTAB     equ $7D00
FLIPT    equ $7E00
FBW      equ 40
FBROWS   equ 64

SRAM_GAME equ 3            ; port $37: SRAM mapped, bank B
SRAM_DOS  equ 1            ; port $37: DOS bank (as left by the loader)

        include "build_opts.asm"
        org $8000
        jp init

        include "sys.asm"
        include "render.asm"
        include "hero.asm"
        include "objects.asm"
        include "boss.asm"
        include "game.asm"
        include "front.asm"

; ------------------------------------------------------------------- data
        include "gen/gfx.asm"
        include "gen/level1.asm"
        include "gen/music.asm"
        include "gen/title.asm"
        include "gen/blit_lo.asm"
        include "text.asm"
RESIDENT_END:

; ------------------------------------------------------------------- SRAM blobs
BLOB1_SRC:
        phase $5500
        include "gen/blit_pf.asm"
BLOB1_END:
        dephase
BLOB2_SRC:
        phase $6100
        include "gen/herocls.asm"
BLOB2_END:
        dephase
LOAD_END:
        assert BLOB1_END <= $6100
        assert BLOB2_END <= $6800

        include "vars.asm"
