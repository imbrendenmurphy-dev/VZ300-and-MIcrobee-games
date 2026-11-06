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
;   $8000-       resident program + data, then the pack area: the front pack
;                (title, menus) or a stage pack is loaded here from SD.
;                The tail of the load image holds the SRAM blobs, copied up
;                at start-up before the first pack is loaded over them.
;   after packs  variables, then the frame buffer, all below $FA00
;   $FA00-$FFFF  BennVenn DOS RAM - never touched
;   FB           frame buffer 64 rows x 40 bytes (4 margin bytes each side)
;
LATCH    equ $6800
VRAM     equ $7000
RING0    equ $4000
RING2    equ $4A80
RINGW    equ 48
TITLEBUF equ $4000
LOGOBUF  equ $4800      ; logo sprite (mask+data) rebuilt here for the front end
; Nothing may live below $7AE9 here: the SD DOS calls the ROM, which uses
; the BASIC system area $7800-$7AE8 (RST vectors, input buffer).
; IM2 table $7F00-$8000: its 257th byte is the first byte of the program,
; which is therefore $F9 (ld sp,hl) so every vector reads $F9F9.
IM2TAB   equ $7F00
ISRJP    equ $F9F9      ; jp isr, just above the stack, below the DOS's RAM
STACKTOP equ $F9F9      ; stack grows down into the free RAM above the frame buffer
HUDBUF   equ $7B00      ; 12 rows: 8 top + 4 bottom
HLUT     equ $7C80
DOSMAP   equ $7CF0      ; port $37 value that maps the DOS (probed at start-up)
DOSBUSY  equ $7CF1      ; non-zero while a DOS call is in progress
BOOT_SP  equ $7CF2      ; loader's SP, IX, IY at entry (kept for DOS calls)
BOOT_IX  equ $7CF4
BOOT_IY  equ $7CF6
YTAB     equ $7D00
FLIPT    equ $7E00
FBW      equ 40
FBROWS   equ 64

SRAM_GAME equ 3            ; port $37: SRAM mapped, bank B
SRAM_DOS  equ 1            ; port $37: DOS bank (as left by the loader)

        include "build_opts.asm"
        org $8000
        db $F9                  ; ld sp,hl: also the IM2 table's 257th byte
        jp init

        include "sys.asm"
        include "render.asm"
        include "hero.asm"
        include "objects.asm"
        include "boss.asm"
        include "game.asm"
        include "front.asm"
        include "sd.asm"

; ------------------------------------------------------------------- data
        include "gen/gfx.asm"
        include "gen/music.asm"
        include "gen/blit_lo.asm"
        include "text.asm"
        include "packs.asm"
RESIDENT_END:
PACK_AREA equ (RESIDENT_END+255)&$FF00
; stage pack header (fixed offsets, see tools/stages.py)
STG_NUM   equ PACK_AREA+1
STG_MAP   equ PACK_AREA+2
STG_W     equ PACK_AREA+4
STG_OBJ   equ PACK_AREA+6
STG_TILES equ PACK_AREA+8
STG_TATTR equ PACK_AREA+10
STG_SONG  equ PACK_AREA+12
STG_BSONG equ PACK_AREA+14
STG_MOON  equ PACK_AREA+16
STG_BTOP  equ PACK_AREA+18
STG_BJAW  equ PACK_AREA+20
STG_BHP   equ PACK_AREA+22      ; 3 bytes: casual, normal, expert
STG_SUMMON equ PACK_AREA+25     ; object type summoned in phase 2
STG_CSS   equ PACK_AREA+26      ; $00 or $10 colour set
STG_AMB   equ PACK_AREA+27      ; ambient lightning on/off
STG_CARD  equ PACK_AREA+28
STG_BNAME equ PACK_AREA+30
STG_SPR   equ PACK_AREA+32      ; 7 roles x 4 frames (dw)
STG_HEAD  equ PACK_AREA+88
STG_PORT  equ PACK_AREA+90      ; stage card portrait sprite
STG_BSPD  equ PACK_AREA+92      ; boss speed: 0 normal, 1 fast
STG_VOLLEY equ PACK_AREA+93     ; boss fireballs per volley
STG_JAWY  equ PACK_AREA+94      ; boss jaw y offset
STG_COLS  equ PACK_AREA+95      ; column dictionary (8 bytes per unique column)
STG_LOGIC equ PACK_AREA+97      ; 7 x dw: behaviour routines for roles 1-7
PACK_TOP  equ PKMAX7

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
