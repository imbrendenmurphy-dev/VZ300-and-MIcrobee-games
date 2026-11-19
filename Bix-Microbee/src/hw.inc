; =====================================================================
;  BIX THE BILBY for the Microbee Premium Plus - hardware, memory map
;  Z80 3.375 MHz, 1MB RAM (32 blocks of 32K), 32K PCG RAM (16 banks of
;  128 glyphs), 6545. A scanline is 216 T; a frame is 313 lines.
;  Display: the 40-column mode, 40 x 25 cells of 8 x 8 (320 x 200).
; =====================================================================
P_PIOA      EQU $00         ; joystick (active low), b7 fire
P_PIOAC     EQU $01
P_PIOB      EQU $02         ; b6 speaker
P_PIOBC     EQU $03
P_CLK40     EQU $09         ; IN with A = 1: the 40-column dot clock
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

; ---- RAM blocks (the lower window, 0000-7FFF). Block 0 is the upper 32K.
BLK_GAME    EQU 4           ; the game's logic, the tile map
BLK_MAP     EQU 5           ; the cell-glyph map, the pair table, the cell builder
; a stage's data is in block BLK_STG + stage (see gen.inc for its layout)
BLK_LAD     EQU 7           ; the attribute ladders (built at start-up)


; ---- BLK_MAP (see map.asm)
M_COLUMN    EQU $0000
M_QUEUE     EQU $0003
M_MIXED     EQU $0006
M_ROW       EQU $0009
M_HASH      EQU $1000       ; 1024 x (left, right, code, attribute)
M_TCELL     EQU $2000       ; tile -> TL, TR, BL, BR cell glyphs
M_PLATH     EQU $2100       ; 4 x 7
M_PLATV     EQU $2120       ; 4 x 12
M_PCOL      EQU $2200       ; ink by attribute * 128 + code: colour, then mono (+$600)
M_CGMAP     EQU $2E00       ; 32 cell glyphs a column
M_FONT      EQU $7C00       ; the 64-glyph font
M_HUDG      EQU $7800       ; the status line's glyphs: 4 slides x 2 halves x 16

; ---- upper memory (block 0)
VARS        EQU $9800
STACK       EQU $9A00
ROWTAB      EQU $9900       ; 25 x ring offset of each screen row
DRAWQ       EQU $9A00       ; sprites to draw: frame, face, x (2), y (2), ink, 0
NDRAW       EQU 14
HUDBUF      EQU $9A80       ; the status line: 40 glyph numbers (0-15)
HUDCODE     EQU $9940       ; its two rows of screen codes at the present slide
MAPQ        EQU $9AB0       ; requests for the map block, 6 bytes each
NMAPQ       EQU 12
COLMIX      EQU $9B00       ; 64 columns x 4: which of a column's cells change colour with the shift
POOLBUF     EQU $9C00       ; this frame's composed glyphs, 8 bytes a slot
LISTA       EQU $9F40       ; cell lists (CELLMAP addresses), 2 bytes a slot
LISTB       EQU $A000
FLIPL       EQU $A0A0       ; the flip list: address, code, attribute, colour, flags
FLIPEND     EQU $A7F0
CELLMAP     EQU $A800       ; ring: this frame's pool slot for each cell (0 = none)
SCRSH       EQU $B000       ; ring: the background's screen code
ATTSH       EQU $B800       ; ring: its attribute (b7 shifts, b6 mixed, b0-3 base)
TILEPAT     EQU $C000       ; 12 x 1024 glyph patterns

MAXSLOT     EQU 80
RING        EQU 2048
COLS        EQU 40
PF_ROW0     EQU 2           ; playfield = cell rows 2..24 (rows 0-1: the status band)
PFROWS      EQU 23
PF_ROW1     EQU 25

; ---- PCG banks: 0-11 the scroll glyphs
BK_HUD      EQU 12          ; the status line's glyphs at each slide
BK_FONT     EQU 13
BK_POOLA    EQU 14
BK_POOLB    EQU 15

LADSTEP     EQU $1100       ; ladder k is at k * LADSTEP in BLK_LAD

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
K_C         EQU 3
K_M         EQU 13
K_O         EQU 15
K_P         EQU 16
K_Q         EQU 17
K_S         EQU 19
K_V         EQU 22
K_X         EQU 24
K_Z         EQU 26
K_ESC       EQU $30
K_RET       EQU $34
K_SPACE     EQU $37
K_UP        EQU $38
K_DOWN      EQU $3A
K_LEFT      EQU $3B
K_RIGHT     EQU $3E

; ---- the game's key bits (as the VZ game)
KB_L equ 0
KB_R equ 1
KB_U equ 2
KB_D equ 3
KB_J equ 4
K_L  equ 1
K_R  equ 2
K_U  equ 4
K_D  equ 8
K_J  equ 16
K_MUS equ 32
K_QUIT equ 128
K_MONO equ 64
