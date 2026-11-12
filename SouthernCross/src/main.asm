; ============================================================================
;  SOUTHERN CROSS  -  an original vertically scrolling shoot-'em-up
;  for the Dick Smith VZ300 + BennVenn SD loader + 128K.  Mode 1 (128x64).
;  VIBED BY BPM 2026
; ============================================================================
;
;  SCREEN
;   bytes 0-3 of each row   left panel (score, hi, stage)      16 px
;   bytes 4-27              playfield                           96 px
;   bytes 28-31             right panel (stars, weapon, lives)  16 px
;
;  FILES
;   SCROSS.VZ      the program (loads at $8000, no mapper writes)
;   SCROSS00.DAT   front end: title art and the three-voice title tune
;   SCROSS01.DAT   stage 1: scenery blocks, map, waves, boss art (SRAM bank B)
;
;  MEMORY MAP
;   $4000-$67FF  SRAM bank B (port $37 = 3): the current stage pack
;   $7000-$77FF  video RAM - written only before the display starts
;   $7800-$7AE8  left alone (ROM / SD DOS system area)
;   $7B00-$7CFF  HUD shadow, 64 rows x 8 bytes
;   $7D00-$7D7C  stack            $7D7D  jp isr
;   $7D80-$7DFF  test: the last 128 spare-CPU readings
;   $7E00-$7EB7  frame buffer row table (92 rows)
;   $7F00-$8000  IM2 vector table
;   $8000-       program, sprites, tables, variables
;   OVL-$EBFF    overlay: the front pack on the title, or the copy code
;                built for play (LDI chain + blit)
;   $EE00-$F69F  frame buffer, 92 rows x 24 (20-row margin on top for
;                the boss, 8 below); the DOS's stack during SD loads
;   $F800-$F9FF  DOS sector buffer
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
FBTOP    equ 20                 ; margin rows above the screen
FBROWS   equ FBTOP+64+8
FBVIS    equ FB+FBTOP*FBW
OVL_END  equ $EC00              ; keep 3K below $F800 clear for the DOS stack

        include "build_opts.asm"
        org $8000
        db ISRJP>>8             ; also the IM2 table's 257th byte
        jp init

        include "sys.asm"
        include "sd.asm"
        include "title.asm"
        include "render.asm"
        include "game.asm"
        include "boss.asm"

; ------------------------------------------------------------------- data
        include "gen/sprites.asm"
        include "gen/hud.asm"
        include "gen/paths.asm"
        include "gen/music.asm"
        include "vars.asm"
CORE_END:

; ------------------------------------------------------------------- overlay
OVL      equ (CORE_END+255)&$FF00
; for play: code built at start-up
LDICHAIN     equ OVL
LDICHAIN_END equ LDICHAIN+32*FBW*2
BLIT_PF      equ LDICHAIN_END+1
CODE_END     equ BLIT_PF+64*40+3
        assert CODE_END <= OVL_END
; on the title: the front pack
        segment "SCROSS00.DAT"
        org OVL
FRONT_START:
        include "gen/front.asm"
        assert FR_END <= OVL_END
        endsegment

; ------------------------------------------------------------------- stage 1
        segment "SCROSS01.DAT"
        org $4000
        include "gen/stage1.asm"
        assert STG_END <= $6800
        endsegment
