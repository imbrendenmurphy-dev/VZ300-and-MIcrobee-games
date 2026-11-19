; =====================================================================
;  CRYPTFALL - Microbee Premium Plus: hardware, memory map, tile numbers
;  Z80 3.375 MHz.  6545 CRTC set to 40 x 25 characters of 8 lines
;  (320 x 200).  Runs as a CP/M program: CP/M stays alive so the caves
;  and the high scores go through the BDOS.          VIBED BY BPM 2026
; =====================================================================
BDOS        EQU $0005
P_PIOA      EQU $00         ; joystick (active low), b7 fire
P_PIOAC     EQU $01
P_PIOB      EQU $02         ; b6 speaker
P_COLCTL    EQU $08         ; b6: F800 window = colour RAM
P_ROMLAT    EQU $0B         ; 1 during keyboard scans
P_CRTCA     EQU $0C         ; 6545 address / status (b5 vertical blanking)
P_CRTCD     EQU $0D
P_LV        EQU $1C         ; b7 premium graphics, b4 attribute RAM, b0-3 PCG bank
P_FDCST     EQU $44         ; WD2793 command / status
P_MEM       EQU $50
MEM_GAME    EQU $04         ; CP/M's own value with the video window at F000h

LV_SCREEN   EQU $80
LV_ATTR     EQU $90
COL_ON      EQU $40
VIDEO       EQU $F000       ; page 0; page 1 at F400h
PCGWIN      EQU $F800
COLWIN      EQU $F800

; ---- memory
CAVE        EQU $A000       ; the cave: up to 32 rows, 64 bytes a row
DMAP        EQU $A800       ; per cell: the direction of its latest arrival
CAVEBUF     EQU $B000       ; a cave record's header as it comes off the disk
CHG_A       EQU $B900       ; change lists (256 entries of 3 bytes)
CHG_B       EQU $BC00
GT          EQU $BF00       ; glyphs of each tile: page 0 top cells (left at +0, right at +64), page 1 bottom
CT          EQU $C100       ; colours, the same layout (2 pages)
VARS        EQU $C300
DEMOBUF     EQU $C600       ; the attract recording (up to 512 bytes)
STACK       EQU $CAF0
ROWLEN      EQU 64
CAVE_ROWS   EQU 32
CAVE_BYTES  EQU CAVE_ROWS*ROWLEN
CHG_MAX     EQU 250

; ---- the screen
COLS        EQU 40
PF_TOP      EQU 2           ; playfield: rows 2..23
PF_ROWS     EQU 22
MSG_ROW     EQU 24
FRAME_FIELDS EQU 3          ; fields a frame; a cave step is two frames

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

; ---- cave record: 18 CP/M records = a 256-byte header, then 32 rows of 64
CH_W        EQU 0
CH_H        EQU 1
CH_QUOTA    EQU 2
CH_TIME     EQU 3           ; seconds (word)
CH_GEMV     EQU 5           ; points a gem (BCD tens: 15h = 150)
CH_GEMX     EQU 6           ; points a gem once the gate is open
CH_MAGIC    EQU 7           ; seconds the enchanted grate stays awake
CH_SLOW     EQU 8           ; seconds before the slime grows fast
CH_FLAGS    EQU 9           ; b0 bonus room
CH_SLMAX    EQU 10          ; slime cells that turn it to stone
CH_SLOTS    EQU 16          ; the pictures this cave uses (up to 31, $FF ends)
CH_THEME    EQU 48          ; pairs of tile, ink ($FF ends): the cave's colours
CH_NAME     EQU 128         ; 24 characters
CH_HINT     EQU 152         ; 40 characters
CH_SIZE     EQU 256
CAVE_RECS   EQU 18

; ---- pad bits
PAD_R       EQU 1
PAD_L       EQU 2
PAD_U       EQU 4
PAD_D       EQU 8
PAD_FIRE    EQU 16
GLH equ 10                     ; lines in a character cell
