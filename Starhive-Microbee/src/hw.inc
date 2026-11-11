; =====================================================================
;  STARHIVE  -  hardware constants and memory layout
;  Microbee Premium Plus: Z80 3.375 MHz, 1MB banked RAM, 32K PCG RAM
;  40 x 24 characters of 8 x 11 pixels (40-column clock: IN A,(09h)
;  with A = 1), hardware smooth scrolling by the 6545's R5.
;  VIBED BY BPM 2026
; =====================================================================

; ---------------- ports
P_PIOA      EQU $00         ; joystick (active low), b7 fire
P_PIOAC     EQU $01
P_PIOB      EQU $02         ; b6 = speaker
P_PIOBC     EQU $03
P_COLCTL    EQU $08         ; b6: F800 window = colour RAM
P_CLK40     EQU $09         ; IN with A = 1: 40-column clock, A = 0: 80
P_ROMLAT    EQU $0B         ; 1 during keyboard scans
P_CRTCA     EQU $0C         ; 6545 address / status (b5 vertical blanking)
P_CRTCD     EQU $0D
P_LV        EQU $1C         ; b7 premium graphics, b4 attribute RAM, b0-3 PCG bank
P_MEM       EQU $50         ; memory map

LV_SCREEN   EQU $80         ; F000 = screen RAM, F800 = PCG bank (| n)
LV_ATTR     EQU $90         ; F000 = attribute RAM
COL_ON      EQU $40

VIDEO       EQU $F000
PCGWIN      EQU $F800
COLWIN      EQU $F800

; ---------------- RAM blocks (32K each, lower window). Block 0 = upper 32K.
BLK_FRONT   EQU 1           ; front end (title, music, screens)
BLK_WORK    EQU 2           ; shadows, glyph mirror, sprite library
BLK_LEVEL   EQU 3           ; current level: map, metatiles, waves

; port 50h value for block n with ROMs off and the video window at F000:
;   b7 b6 b5 = n bits 4..2, b1 b0 = (n bits 1..0) xor 2, b2 = 1
MEMV        MACRO blk
            ld a,(((blk) & $1C) << 3) | (((blk) & 3) ^ 2) | 4
            out (P_MEM),a
            ENDM

; ---------------- display: 40 x 24 cells of 11 lines (264 lines)
; The 2K screen RAM is a ring: row d starts at (S + 40 d) & 7FFh.
; Coarse scroll moves S back 40 cells, fine scroll is R5 = k.
SCOLS       EQU 40
DROWS       EQU 24
CL          EQU 11          ; lines in a cell
EROW0       EQU 2           ; playfield rows 2..23; 2 and 23 are cut to
EROW1       EQU 23          ; the window (display lines 32 .. 263)
WINTOP      EQU 32
PFW         EQU 320         ; playfield width in pixels
PFH         EQU 232         ; and height in lines

; ---------------- PCG banks
BK_SCEN     EQU 0           ; scenery glyphs, banks 0-4 (640)
BK_FIX      EQU 7           ; black, edge glyphs, star glyphs
BK_POOLA    EQU 8           ; dynamic cells, page A (banks 8-9)
BK_HUD      EQU 12          ; HUD: banks 12-15, 11 cells x 11 phases each

G_BLACK     EQU $87
G_E0        EQU $88         ; row-2 edge glyphs (40)
G_E1        EQU $B0         ; row-23 edge glyphs (40)
BK_STAR     EQU 4           ; far-star glyphs: scenery bank 4, codes F0-FF
G_STAR      EQU $F0

; ---------------- WORK block layout (lower window during play)
MIRROR      EQU $0000       ; scenery glyphs, 16 bytes apart (640 -> 2800h)
SPRLIB      EQU $2800       ; sprite library (to 57FFh)
SPRLIB_END  EQU $5800
EDGEC2      EQU $5800       ; edge-row glyph stamps, coloured paper (640)
EDGEC       EQU $5C00       ; edge-row glyph stamps (640)
CSL         EQU $6000       ; dynamic slot + 1 of each ring cell, this frame
SHK         EQU $6800       ; shadow colour (bg<<4 | fg)
SHC         EQU $7000       ; shadow screen code
SHA         EQU $7800       ; shadow attribute (PCG bank)

; level block layout
LV_NROWS    EQU $0000       ; map rows
LV_META     EQU $0010       ; metatiles: up to 1020 x 12 (4 cells: code, attr, colour)
LV_MAP      EQU $3000       ; 20 metatile numbers (2 bytes) per pair of rows

; ---------------- Premium colours (fg = low nibble, bg = high nibble)
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
