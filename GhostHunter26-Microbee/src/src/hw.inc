; =====================================================================
;  GHOST HUNTER '26 - Microbee Premium Plus hardware, memory map, constants.
;  Z80 3.375 MHz; 1MB RAM (32 blocks of 32K); 32K PCG RAM (16 banks of
;  128 glyphs). 6545 CRTC: 40 x 25 characters of 10 lines at half dot
;  clock = 320 x 250 pixels (8 x 10 cells).   VIBED BY BPM 2026
; =====================================================================
P_PIOA      EQU $00         ; joystick (active low), b7 fire
P_PIOAC     EQU $01
P_PIOB      EQU $02         ; b6 speaker
P_PIOBC     EQU $03
P_COLCTL    EQU $08         ; b6: F800 window = colour RAM
P_ROMLAT    EQU $0B         ; 1 during keyboard scans
P_CRTCA     EQU $0C         ; 6545 address / status (b5 vertical blanking)
P_CRTCD     EQU $0D
P_LV        EQU $1C         ; b7 premium graphics, b4 attribute RAM, b0-3 PCG bank
P_MEM       EQU $50

LV_SCREEN   EQU $80
LV_ATTR     EQU $90
COL_ON      EQU $40
VIDEO       EQU $F000
PCGWIN      EQU $F800
COLWIN      EQU $F800

; ---- RAM blocks (lower window 0000-7FFF). Block 0 is the upper 32K.
BLK_RT      EQU 1           ; render tables (restore lists)
BLK_SPR     EQU 4           ; sprite block: glyph store 0000h, frames 3000h
BLK_GFX     EQU 7           ; glyph stores (colour, mono), title picture

; ---- RT block layout
RT_LIST     EQU $0000       ; restore lists: 8 x 256 (page*4 + quarter)
RT_FLAG0    EQU $0800       ; page 0: 1 = cell listed
RT_FLAG1    EQU $0C00
RT_BASELO   EQU $1000       ; (unused base maps)
RT_BASEHI   EQU $1400
RT_BASECOL  EQU $1800
RT_END      EQU $1000

; ---- PCG
BK_POOL     EQU 14          ; sprite glyph pools: 14 (page 0), 15 (page 1)
POOLN       EQU 120         ; glyphs per pool

BLK_MAZE    EQU 8           ; the six mazes

; ---- colours
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
