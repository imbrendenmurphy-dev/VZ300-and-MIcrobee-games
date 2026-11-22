; =====================================================================
;  RUNEDEEP - Microbee Premium Plus hardware, memory map, constants
;  Z80 3.375 MHz, 1MB RAM (32 blocks of 32K), 32K PCG RAM (16 banks of
;  128 glyphs), 6545 CRTC. 40 x 25 cells of 8 x 10 pixels, PAL, 50 Hz.
;  A scanline is 216 T, a frame 313 lines (67 608 T).
;  The Premium holds the CPU while it touches video RAM during a
;  displayed line, so all video writes are made in the blanking.
;  VIBED BY BPM 2026
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

; port 50h value for block n: ROMs off, video window at F000
MPORT       MACRO blk
            ld a,(((blk) & $1C) << 3) | (((blk) & 3) ^ 2) | 4
            out (P_MEM),a
            ENDM

; ---- RAM blocks (lower window 0000-7FFF). Block 0 is the upper 32K.
BLK_UI      EQU 8           ; font, frame, icons, texts, tables
BLK_TITLE   EQU 9           ; title picture
BLK_MUS     EQU 10          ; music and effects
BLK_SAVE    EQU 16          ; CP/M's video state (the loader saves it)
BLK_LVL     EQU 17          ; levels: 2 blocks each, 17/18 .. 23/24
BLK_STATE   EQU 25          ; each level's live state while away
MP_UI       EQU ((BLK_UI & $1C) << 3) | ((BLK_UI & 3) ^ 2) | 4
MP_TITLE    EQU ((BLK_TITLE & $1C) << 3) | ((BLK_TITLE & 3) ^ 2) | 4
MP_MUS      EQU ((BLK_MUS & $1C) << 3) | ((BLK_MUS & 3) ^ 2) | 4
MP_SAVE     EQU ((BLK_SAVE & $1C) << 3) | ((BLK_SAVE & 3) ^ 2) | 4
MP_STATE    EQU ((BLK_STATE & $1C) << 3) | ((BLK_STATE & 3) ^ 2) | 4
EXIT_VID    EQU $EFFE       ; written by the loader: CP/M's video window bits
EXIT_PORT   EQU $EFFF       ; CP/M's lower block (port 50h value)

; ---- upper memory (block 0)
MAP         EQU $C800       ; 32 x 32: the level at (8,8), walls around
MONMAP      EQU $CC00       ; monster number + 1 on each square
ITEMMAP     EQU $D000       ; item on each square
SHC         EQU $D400       ; view shadow: codes (24 x 16, by rows)
SHA         EQU SHC+384     ; attributes
SHK         EQU SHC+768     ; colours
MONS        EQU $D900       ; 16 monsters x 16 bytes
DECOR       EQU $DA00       ; decorations: 4 bytes each, up to 48, FF ends
ANIMS       EQU $DB00       ; animated view cells: offset lo, hi, class (up to 80)
TRIG        EQU $DC00       ; level triggers (copied from the level block)
MINI        EQU $DD00       ; minimap glyphs 64 x 10 (640 bytes)
SEEN        EQU $E000       ; squares seen, 16 x 16
TEXTBUF     EQU $E100       ; message log: 6 lines x 24 codes, 6 colours
SCRSH       EQU $E200       ; what each cell outside the view shows: code
COLSH       EQU $E600       ;  and colour (+80h: a bank 15 glyph)
VARS        EQU $EA00
STACK       EQU $EFF0

; ---- PCG banks: 0-13 the level's tiles, 14 font, 15 frame, icons, map
BK_FONT     EQU 14
BK_UI       EQU 15

; ---- screen
PAGE0       EQU $000
PAGE1       EQU $400
VCOL        EQU 1           ; view at column 1, row 1
VROW        EQU 1
VW          EQU 24
VH          EQU 16

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
K_D         EQU 4
K_E         EQU 5
K_F         EQU 6
K_H         EQU 8
K_M         EQU 13
K_N         EQU 14
K_P         EQU 16
K_Q         EQU 17
K_R         EQU 18
K_S         EQU 19
K_T         EQU 20
K_W         EQU 23
K_X         EQU 24
K_Y         EQU 25
K_Z         EQU 26
K_1         EQU $21
K_2         EQU $22
K_3         EQU $23
K_ESC       EQU $30
K_RET       EQU $34
K_SPACE     EQU $37
K_UP        EQU $38
K_DOWN      EQU $3A
K_LEFT      EQU $3B
K_RIGHT     EQU $3E
