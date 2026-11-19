; =====================================================================
;  FRILLSEEKER - Microbee Premium Plus hardware, memory map, constants
;  Z80 3.375 MHz, 1MB RAM (32 blocks of 32K), 32K PCG RAM (16 banks of
;  128 glyphs), 6545 CRTC. A scanline is 216 T; a frame is 312 lines.
;
;  Display: the full-height 40-column mode, 40 x 32 cells of 8 x 8
;  pixels (320 x 256) at half the dot clock: near-square pixels, square
;  cells, the whole of a PAL tube.
; =====================================================================
P_PIOA      EQU $00         ; joystick (active low), b7 fire
P_PIOAC     EQU $01
P_PIOB      EQU $02         ; b6 speaker
P_PIOBC     EQU $03
P_CLK40     EQU $09         ; IN with A = 1: the 40-column dot clock (A = 0: back to 80)
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

MEMV        MACRO blk
            ld a,(((blk) & $1C) << 3) | (((blk) & 3) ^ 2) | 4
            out (P_MEM),a
            ENDM

; ---- RAM blocks (lower window 0000-7FFF). Block 0 is the upper 32K.
BLK_WORK    EQU 1
BLK_SPR     EQU 4           ; sprite frames, blocks 4..7
BLK_GFX     EQU 8           ; font
BLK_ROOM    EQU 9           ; rooms, two to a block, for the monitor chosen at the loader: 9-20
BLK_TITLE   EQU 21          ; the title picture: colour at 0000, mono at 4000
BLK_FRONT   EQU 22          ; the front end: music, attract sequence, demonstrations (src/front.asm)

; ---- the title record (tools/title.py)
T_SCR       EQU $0100
T_ATTR      EQU $0600
T_COL       EQU $0B00
T_PAT       EQU $1000

; ---- a room record (16K; see tools/rooms.py)
R_SCR       EQU $0000
R_ATTR      EQU $0500
R_COL       EQU $0A00
R_TMAP      EQU $0F00       ; 20 x 15
R_OBJ       EQU $1040       ; type, x (word), y ... 0
R_NPAT      EQU $1080       ; dw glyphs; rooms left, right, up, down ($FF = none)
R_NAME      EQU $1090
R_PAT       EQU $1100       ; up to 768 glyphs x 8
R_ANIM      EQU $2900

NCELL       EQU 1280        ; 40 x 32
COLS        EQU 40

; ---- upper memory (block 0). The four cell tables are SHD pages apart:
; code relies on it.
TMAP        EQU $AA00       ; the room's tile map, 20 x 15
SCRATCH     EQU $AB40       ; where a sprite draws when the pool is full
COLSH       EQU $AC00       ; the room's colours
SCRSH       EQU $B100       ; the room's screen codes (background)
ATTSH       EQU $B600       ; the room's glyph banks (b4: busy cell)
CELLMAP     EQU $BB00       ; this frame's pool slot for each cell (0 = none)
SHD         EQU 5
TILEPAT     EQU $C000       ; the room's glyph patterns, 1024 x 8
POOLBUF     EQU $E000       ; this frame's composed glyphs, 8 bytes a slot
LISTA       EQU $E400       ; cell lists (CELLMAP addresses), 2 bytes a slot
LISTB       EQU $E500
ANIMS       EQU $E600       ; the living background's sets
FLIPL       EQU $E700       ; the flip list: addr, screen, attr, colour, pad
VARS        EQU $EE00
STACK       EQU $EFF0

MAXSLOT     EQU 120
PF_ROW0     EQU 2           ; playfield = cell rows 2..31
PF_ROW1     EQU 32
PF_H        EQU 240         ; its height in pixels (20 x 15 tiles of 16)
TM_SIZE     EQU 300
ROOM_W      EQU 320

; ---- PCG banks
BK_FONT     EQU 11          ; the 8 x 16 font, two glyphs a letter
BK_POOLA    EQU 14          ; sprite glyph pool A (slots 1..120)
BK_POOLB    EQU 15          ; sprite glyph pool B

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
K_K         EQU 11
K_M         EQU 13
K_O         EQU 15
K_P         EQU 16
K_Q         EQU 17
K_ESC       EQU $30
K_RET       EQU $34
K_SPACE     EQU $37
K_UP        EQU $38
K_DOWN      EQU $3A
K_LEFT      EQU $3B
K_RIGHT     EQU $3E
K_SHIFT     EQU $3F

; ---- pad bits
PB_RIGHT    EQU 0
PB_LEFT     EQU 1
PB_FRILL    EQU 2
PB_DOWN     EQU 3
PB_JUMP     EQU 4
