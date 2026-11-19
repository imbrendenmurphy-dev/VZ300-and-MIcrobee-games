; =====================================================================
;  REDBACK - hardware constants and memory layout
;  Microbee Premium Plus: Z80 3.375 MHz, banked RAM, 32K PCG RAM
;  40 x 25 characters of 8 x 10 pixels, PAL, 313 lines, 50 Hz
;  (40-column dot clock: IN A,(09h) with A = 1)
;  VIBED BY BPM 2026
; =====================================================================
P_PIOA      EQU $00
P_PIOAC     EQU $01
P_PIOB      EQU $02         ; b6 = speaker
P_PIOBC     EQU $03
P_COLCTL    EQU $08         ; b6: F800 window = colour RAM
P_CLK40     EQU $09
P_ROMLAT    EQU $0B
P_CRTCA     EQU $0C
P_CRTCD     EQU $0D
P_LV        EQU $1C         ; b7 premium graphics, b4 attribute RAM, b0-3 PCG bank
P_MEM       EQU $50

LV_SCREEN   EQU $80
LV_ATTR     EQU $90
COL_ON      EQU $40

VIDEO       EQU $F000
PCGWIN      EQU $F800

; port 50h value for block n: ROMs off, video window at F000
MEMV        MACRO blk
            ld a,(((blk) & $1C) << 3) | (((blk) & 3) ^ 2) | 4
            out (P_MEM),a
            ENDM
BLK_PAIRS   EQU 8           ; pair glyph records + sprites
BLK_DECK    EQU 12          ; deck columns
BLK_SAVE    EQU 16          ; CP/M's video state, saved by the loader
EXIT_VID    EQU $E8FE       ; video window bits of CP/M's port 50h value
EXIT_PORT   EQU $E8FF       ; CP/M's lower block (port 50h value)
MV_SAVE     EQU ((BLK_SAVE & $1C) << 3) | ((BLK_SAVE & 3) ^ 2) | 4
P_COL       EQU $08
MV_PAIRS    EQU ((BLK_PAIRS & $1C) << 3) | ((BLK_PAIRS & 3) ^ 2) | 4
MV_DECK     EQU ((BLK_DECK & $1C) << 3) | ((BLK_DECK & 3) ^ 2) | 4

; ---------------- PCG banks
BK_POOL0    EQU 8           ; sprite cell pool A / B
BK_POOL1    EQU 9
BK_HUD      EQU 12

; ---------------- screen
CELLH       EQU 10
RING0       EQU $100        ; ring address of deck column 0 (start address = RING0 + S)

; ---------------- upper RAM map
SHC         EQU $C000       ; shadow of the screen codes, 2K ring
RES         EQU $C800       ; resident ref of each pair slot (128 words)
PCOL        EQU $C900       ; colour of each pair slot (128)
Y10         EQU $CA00       ; line -> playfield row
YM          EQU $CB00       ; line -> line within cell
TOPA        EQU $D800       ; commit lists, top rows / rest, two frames
TOPB        EQU $D980
BOTA        EQU $DB00
BOTB        EQU $DC80
LDQ         EQU $E700       ; queued pair loads: slot, ref
HUDC        EQU $E800       ; HUD codes (80)
VARS        EQU $E900
STACK       EQU $EFF0

; ---------------- colours (fg = low nibble, paper = high nibble)
BLACK       EQU 0
RED         EQU 1
GREEN       EQU 2
BROWN       EQU 3
BLUE        EQU 4
MAGENTA     EQU 5
CYAN        EQU 6
GREY        EQU 7
DGREY       EQU 8
BRED        EQU 9
BGREEN      EQU 10
YELLOW      EQU 11
BBLUE       EQU 12
BMAGENTA    EQU 13
BCYAN       EQU 14
WHITE       EQU 15
