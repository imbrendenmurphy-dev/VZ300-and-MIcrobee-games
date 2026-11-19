;  BIX THE BILBY for the Microbee Premium Plus - hardware, memory map
;  Z80 3.375 MHz, 1MB RAM (32 blocks of 32K), 32K PCG RAM (16 banks of
;  128 glyphs), 6545. A scanline is 216 T; a frame is 312 lines.
;  Display: the 40-column mode, 40 x 25 cells of 8 x 10 (320 x 250): a
;  full PAL picture. Only 62 lines (13,400 T) of each field are blanking.
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
BLK_MAP     EQU 5           ; the quad table, the cell glyphs, the screen code
BLK_CGM     EQU 7           ; the cell-glyph map of the stage in play
; the stage's quads, each with its 12 pictures, inks and flags (136 bytes; 240 a block)
QDB_B0      EQU 6
QDB_B1      EQU 21
QDB_B2      EQU 22
QREC        EQU 136
QPERBLK     EQU 240
; the stages are packed into blocks from BLK_STG0, the sprites from BLK_SPR0 (gen.inc)

; ---- BLK_MAP (see map.asm)
M_CGROW     EQU $3000       ; row r of every cell glyph: M_CGROW + r * 256 + glyph
M_TCELL     EQU $3A00       ; tile -> TL, TR, BL, BR cell glyphs
M_SLE       EQU $3B00       ; slot -> its quad's entry: low bytes, high at +$80
M_SLREF     EQU $3C00       ; slot -> cells on show using it
M_PH1280    EQU $3C80       ; phase -> phase * 1280 (2 bytes)
M_FREEQ     EQU $3D00       ; 256-entry ring of slots that may be reused
M_COLMIX    EQU $3E00       ; 64 columns x 4: cells whose ink changes with the step across
M_VMIX      EQU $3F00       ; 64 columns x 4: cells whose ink changes with the vertical step
M_QTAB      EQU $4000       ; 1024 quads x 8: the 4 cell glyphs, its record (2), slot, -
M_MIXINK    EQU $6000       ; 256 x 12: the inks of quads whose ink changes with the phase
M_HUDG      EQU $6C00       ; the status line's glyphs (10 bytes each) (start-up only)
M_FONT      EQU $7000       ; the font (10 bytes a glyph) (start-up only)
M_LOADQ     EQU $6D00       ; slots whose glyphs go to the PCG next blanking
M_LOGCG     EQU $6D80       ; the floating log's six cell glyphs
M_SLFL      EQU $6E00       ; slot -> its quad's flags
M_LSB       EQU $6F00       ; n -> its lowest set bit (0..7)
M_SLINK     EQU $7800       ; slot's ink at phase p: + (p >> 1) x 256 + (p & 1) x 128 + slot

; the map block's entry points
M_SCROLL    EQU $0000
M_QUEUE     EQU $0003
M_MIXED     EQU $0006
M_PRESENT   EQU $0009
M_SNAP      EQU $000C
M_QINSERT   EQU $000F
M_TABINIT   EQU $0012
M_CGSCATTER EQU $0015
M_PCGCLEAR  EQU $0018
M_HUDPUT    EQU $001B
M_PLAT      EQU $001E
M_RESTORES  EQU $0021
M_QBUILD    EQU $0024

; ---- upper memory (block 0)
VARS        EQU $9400
ROWTAB      EQU $9500       ; 25 x the ring offset of each screen row
HUDBUF      EQU $9540       ; the status line: 40 glyph numbers
HUDCOL      EQU $9568       ; and their colours
CGBUF       EQU $9590       ; cell glyphs fetched from the map: 2 x 41 (or 2 x 33)
DRAWQ       EQU $9600       ; sprites to draw: frame, face, x (2), y (2), ink, 0
NDRAW       EQU 14
MAPQ        EQU $9680       ; requests for the map block, 6 bytes each
NMAPQ       EQU 12
STACK       EQU $9800       ; (9700-97FF)
POOLBUF     EQU $9800       ; this frame's composed glyphs, 10 bytes a slot (1..80)
REC         EQU POOLBUF     ; (while a stage loads) a quad's record being built
LISTA       EQU $9C00       ; cell lists: CELLMAP index (2), ring (2) a slot
LISTB       EQU $9D40
ROW40       EQU $9E80       ; screen row -> row x 40 (2 bytes)
MUL10       EQU $9F00       ; n -> n * 10: low bytes, high at +128 (n < 128)
FLIPL       EQU $A000       ; flips: address, code, attribute, colour, flags (6)
FLIPEND     EQU $A3F0
NFLIPMAX    EQU 168
CELLMAP     EQU $A400       ; screen cell (row * 40 + column) -> this frame's pool slot
SCRSH       EQU $A800       ; ring: the code of the background quad shown there
CFLIPL      EQU $B000       ; colour flips: address, colour, - (4)
NCFLIPMAX   EQU 126
DIV10       EQU $B200       ; n -> n / 10, then n mod 10 at +256 (n < 256)
SLOTPAT     EQU $B400       ; 12 phases x 128 slots x 10 bytes: what is in the PCG

MAXSLOT     EQU 80
RING        EQU 2048
COLS        EQU 40
PF_ROW0     EQU 1           ; playfield = cell rows 1..24 (row 0: the status line)
PFROWS      EQU 24
PF_ROW1     EQU 25
NPH         EQU 12          ; phases: 4 steps of 2 pixels across x 3 of 0, 3, 7 lines down

; ---- PCG banks: 0-11 the scroll glyphs (bank = phase)
BK_HUD      EQU 12
BK_FONT     EQU 13
BK_POOLA    EQU 14
BK_POOLB    EQU 15

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
