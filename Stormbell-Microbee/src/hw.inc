; =====================================================================
;  STORMBELL - Microbee Premium Plus hardware, memory map, constants
;  Z80 3.375 MHz, 1MB RAM (32 blocks of 32K), 32K PCG RAM (16 banks of
;  128 glyphs), 6545 CRTC.
;
;  Display: the 40-column mode, 40 x 25 cells of 8 x 10 pixels (320 x
;  250, a full PAL picture). The screen, attribute and colour RAM are 2K each, so there is
;  room for two pages of 1000 cells: the game draws the hidden one and
;  swaps them in the vertical blanking.
; =====================================================================
P_PIOA      EQU $00         ; joystick (active low), b7 fire
P_PIOAC     EQU $01
P_PIOB      EQU $02         ; b6 speaker
P_PIOBC     EQU $03
P_COLCTL    EQU $08         ; b6: F800 window = colour RAM
P_CLK40     EQU $09         ; IN with A = 1: the 40-column dot clock
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
PAGE1       EQU $0400       ; the second page's offset in the video RAM

; ---- RAM blocks (lower window 0000-7FFF). Block 0 is the upper 32K.
BLK_WORK    EQU 1
BLK_FIGHT   EQU 4           ; the six fighters: blocks 4..9
BLK_GFX     EQU 10          ; font, the title (picture 0), the ending (picture 1)
BLK_STG     EQU 11          ; the five stages: blocks 11..15
BLK_STGM    EQU 16          ; the same for a monochrome monitor: blocks 16..20
BLK_GFXM    EQU 21          ; the title and the ending for a monochrome monitor

; ---- a stage block (tools/build.py, pack_stage)
SB_NGLYPH   EQU $00
SB_MIDW     EQU $02
SB_FARW     EQU $03
SB_DUELC    EQU $04
SB_ENDC     EQU $05
SB_FAR      EQU $06         ; dw: code, bank, colour planes, 7 rows x FARW
SB_MID      EQU $08         ; dw: the same, 8 rows x MIDW
SB_FCELL    EQU $0A         ; dw: the same, 8 rows x 40 (the floor's cells)
SB_FDESC    EQU $0C         ; dw: 8 x (k, dw first glyph, 0, dw table)
SB_PHASE    EQU $0E         ; dw: 48 x 8 strip offsets
SB_GLYPHS   EQU $10         ; dw: 10 bytes a glyph
FAR_ROW     EQU 1           ; far layer: rows 1..7
FAR_ROWS    EQU 7
MID_ROW     EQU 8           ; midground: rows 8..15
MID_ROWS    EQU 8
FLOOR_ROW   EQU 16          ; floor: rows 16..23
FLOOR_ROWS  EQU 8
FLOOR_T     EQU 48          ; the floor repeats every 48 camera pixels
RUN_PX      EQU 4           ; camera pixels a tick while running

; ---- a fighter block (tools/build.py)
FB_PUNCH    EQU $0002       ; reach of the punch, pixels
FB_KICK     EQU $0003
FB_BODY     EQU $0004
FB_FRAMES   EQU $0010       ; dw offset of each frame record
FB_GLYPHS   EQU $4000       ; 20 bytes a glyph: 10 pattern, 10 mask

; ---- a picture record (in the GFX blocks)
PIC_BASE    EQU $0500
PIC_SLOT    EQU $2000
PIC_CODES   EQU 0
PIC_BANKS   EQU 1000
PIC_COLS    EQU 2000
PIC_N       EQU 3000
PIC_GLYPHS  EQU 3008

; ---- PCG banks
BK_FONT     EQU 0           ; font 0..63, HUD 64.., overlap pool 96..127
BK_PIC      EQU 1           ; the title or ending picture: banks 1..4
BK_SCN      EQU 1           ; the stage's scenery: banks 1..4
BK_HERO     EQU 5           ; banks 5..9
BK_FOE      EQU 10          ; banks 10..15
POOL0       EQU 96
POOLN       EQU 16          ; pool glyphs a page

; ---- the screen
COLS        EQU 40
NCELL       EQU 1000
BAND_ROW    EQU 10          ; the fighters' band: cell rows 10..20
BAND_ROWS   EQU 11
BAND_N      EQU BAND_ROWS*COLS
BAND_OFF    EQU BAND_ROW*COLS

; ---- scenery waiting for the vertical blanking (upper RAM)
MIDBUF      EQU $B000       ; rows 8..15: 3 planes of 320 bytes
FARBUF      EQU $B400       ; rows 1..7: 3 planes of 280 bytes

; ---- band buffers (upper RAM), 200h apart: code, bank, colour
WANT        EQU $C000       ; what the band should show
BASE        EQU $C600       ; the empty stage
HAVE0       EQU $CC00       ; what page 0 shows
HAVE1       EQU $D200       ; what page 1 shows
OWN         EQU $D800       ; this compose: 1 = the under fighter's cell
VARS        EQU $E000
STACK       EQU $EFF0

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

; ---- keys (6545 light pen scan codes)
K_A         EQU 1
K_D         EQU 4
K_K         EQU 11
K_L         EQU 12
K_M         EQU 13
K_P         EQU 16
K_S         EQU 19
K_ESC       EQU $30
K_RET       EQU $34
K_SPACE     EQU $37
K_UP        EQU $38
K_DOWN      EQU $3A
K_LEFT      EQU $3B
K_RIGHT     EQU $3E

; ---- pad bits
PB_FWD      EQU 0
PB_BACK     EQU 1
PB_GUARD    EQU 2
PB_PUNCH    EQU 3
PB_KICK     EQU 4
PB_START    EQU 5
PB_ESC      EQU 6
PB_PAUSE    EQU 7
