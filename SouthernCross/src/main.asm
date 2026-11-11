; ============================================================================
;  SOUTHERN CROSS  -  engine test build (SCTEST)
;  An original vertically scrolling shoot-'em-up for the Dick Smith VZ300
;  Target: VZ300 + BennVenn SD loader + 128K.  Mode 1 (128x64, 4 colours)
;  VIBED BY BPM 2026
; ============================================================================
;
;  SCREEN
;   bytes 0-3 of each row   left panel (score, hi, stage)      16 px
;   bytes 4-27              playfield                           96 px
;   bytes 28-31             right panel (stars, weapon, lives)  16 px
;
;  MEMORY MAP (this test build: no SD calls)
;   $4000-$57FF  SRAM bank B (port $37 = 3): background strip, 256 x 24 bytes
;   $7000-$77FF  video RAM - written only during vertical blank
;   $7800-$7AE8  left alone (ROM / SD DOS system area)
;   $7B00-$7CFF  HUD shadow, 64 rows x 8 bytes
;   $7D00-$7D7C  stack            $7D7D  jp isr
;   $7E00-$7E9F  frame buffer row table (80 rows)
;   $7F00-$8000  IM2 vector table (every vector reads $7D7D)
;   $8000-       program, graphics, variables; then code built at start-up
;                (unrolled LDI chain and blits) over the strip's load space
;   $EE00-$F57F  frame buffer, 80 rows x 24 bytes (8 margin rows each end)
;   $FA00-$FFFF  BennVenn DOS RAM - never touched
;
LATCH    equ $6800
VRAM     equ $7000
HUDBUF   equ $7B00
STACKTOP equ $7D7D
ISRJP    equ $7D7D
YTAB     equ $7E00
IM2TAB   equ $7F00
FB       equ $EE00
FBW      equ 24
FBROWS   equ 80
FBVIS    equ FB+8*FBW

        org $8000
        db ISRJP>>8             ; also the IM2 table's 257th byte
        jp init

        include "sys.asm"
        include "render.asm"
        include "game.asm"

; ------------------------------------------------------------------- data
        include "gen/sprites.asm"
        include "gen/hud.asm"
        include "gen/paths.asm"
        include "gen/music.asm"
        include "vars.asm"
; the background strip is copied into SRAM bank B at start-up; the space it
; occupied in the load image is then reused for code built at start-up
        include "gen/strip.asm"
STRIP_END:
PROG_END:
SRAMSTRIP    equ $4000
LDICHAIN     equ (STRIP+255)&$FF00
LDICHAIN_END equ LDICHAIN+64*FBW*2
BLIT_PF      equ LDICHAIN_END+1
BLIT_HUD     equ BLIT_PF+64*40+3
CODE_END     equ BLIT_HUD+3+64*22+1
        assert CODE_END <= FB
        assert STRIP_END-STRIP <= $2800
