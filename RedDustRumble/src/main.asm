; ============================================================================
;  RED DUST RUMBLE - WORLD TOUR  v0.7
;  A one-on-one fighting game for the Dick Smith VZ300
;  with the BennVenn SD loader and 128K SRAM.
;  VIBED BY BPM 2026
; ============================================================================
;
;  MEMORY (see DESIGN.md)
;  Port $37: bit 0 = SRAM at $4000-$67FF, bit 1 = which 10K bank is there,
;            bit 2 = swaps the 18K at $B800-$FFFF for a second bank.
;    1  DOS bank + normal high memory     (only while reading the SD card)
;    3  fighter A + normal high memory    (the stage and its clean copies)
;    7  fighter A + second high bank      (fighter B, tables, game code)
;
;  $4000-$67FF  bank 0: the SD DOS (left alone)   bank 1: fighter A
;  $7B00-$7D7C  stack          $7D7D interrupt jump     $7F00 interrupt table
;  $8000-$AFFF  always visible: interrupt, input, sound, SD loader, drawing,
;               variables
;  $B000-$B7FF  the shadow screen (start-up code sits here in the .VZ file)
;  normal high memory (port $37 = 3):
;    $B800  copy of the banked code as loaded (re-copied after every SD load)
;    $D000  stage, 192 pixels wide      $DA20  the same shifted 2 pixels
;    $E440  background animation list   $E600  clean copy of the view
;    $EE00-$F7FF stack for the DOS      $F800 sector buffer    $FA00+ DOS
;  second high bank (port $37 = 7):
;    $B800  fighter B      $E000  draw tables      $E800-$FFFF game code
; ============================================================================

LATCH    equ $6800
VRAM     equ $7000
STACKTOP equ $7D7D
ISRJP    equ $7D7D
IM2TAB   equ $7F00

SB       equ $B000          ; shadow screen
VARS     equ $AE00

SLOT_A   equ $4000          ; fighter A (SRAM bank 1)
SLOT_B   equ $B800          ; fighter B (second high bank)
SLOTLEN  equ $2800

H1IMG    equ $B800          ; banked code as loaded, in normal high memory
H1CODE   equ $E800          ; where it runs, in the second high bank
H1LEN    equ $1800

STAGE0   equ $D000
STAGEW   equ 48
STAGEROWS equ 54
SKYROWS  equ 17
STAGE2   equ STAGE0+STAGEROWS*STAGEW
PATCH    equ $E440
BG       equ $E600
DOSSTACK equ $F800
SECBUF   equ $F800

XF_ID    equ $E0            ; draw tables (mask page = +1)
XF_FLIP  equ $E2
XF_RED   equ $E4
XF_FRED  equ $E6

MAP_H0   equ 3
MAP_H1   equ 7

GROUND   equ 58
BANDBOT  equ 62
ARENATOP equ 10
HUDROWS  equ 10
TOURSTART equ 0             ; (7 or 8 to test the last fight or the ending)
ANIMRATE equ 11             ; ticks between background animation steps

        org $8000
        db ISRJP>>8             ; last byte of the interrupt table (runs as LD A,L)
        jp boot

        include "sys.asm"
        include "load.asm"
        include "gfx.asm"
        include "render.asm"
        include "snd.asm"
        include "cpu.asm"
        include "match.asm"
        include "data.asm"
        include "gen/roster.asm"
        include "gen/tables.asm"
        include "gen/font.asm"
L_END:
        assert L_END <= VARS
        include "vars.asm"
        assert VARSEND <= SB

; ---- start-up code: runs once from where the shadow screen will be
        org SB
        include "boot.asm"
        assert $ <= SB+$800

; ---- the banked part: stored at H1IMG, runs at H1CODE
        org H1IMG
        phase H1CODE
        include "fight.asm"
        include "front.asm"
H1_END:
        dephase
        assert H1_END <= H1CODE+H1LEN
