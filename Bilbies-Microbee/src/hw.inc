; =====================================================================
;  BILBIES! for the Microbee Premium Plus - hardware and memory layout
;  Z80 3.375 MHz, 1MB banked RAM (32 blocks of 32K), 32K PCG RAM
; =====================================================================

; ---------------- ports
P_PIOA      EQU $00         ; joystick (active low), b7 fire
P_PIOAC     EQU $01
P_PIOB      EQU $02         ; b2 mouse clock (DTR), b3 mouse data (CTS), b6 speaker
P_PIOBC     EQU $03
P_COLCTL    EQU $08         ; b6: F800 window = colour RAM
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

; ---------------- RAM blocks (32K each in the lower window). Block 0 = upper 32K.
BLK_WORLD   EQU 1           ; the level being played (unpacked)
BLK_FRONT   EQU 2           ; front end pictures / scratch
BLK_GFX     EQU 27          ; (block 3 is a CP/M BIOS buffer) HUD / font glyphs, icons, misc tables
BLK_SPR     EQU 4           ; bilby sprite banks 4..9
BLK_LEVEL   EQU 12          ; packed levels from block 12 on

; port 50h value for block n with ROMs off and the video window at F000:
;   b7 b6 b5 = n bits 4..2, b1 b0 = (n bits 1..0) xor 2, b2 = 1
MEMV        MACRO blk
            ld a,(((blk) & $1C) << 3) | (((blk) & 3) ^ 2) | 4
            out (P_MEM),a
            ENDM

; ---------------- WORLD block layout
WBMP        EQU $0000       ; 128 byte-columns x 160 rows, column-major
WCOL        EQU $5000       ; colour map, 10 rows x 128 (paper<<4 | ink)
WDUG        EQU $5500       ; colour after digging in each cell
WHDR        EQU $5A00       ; level header (see LH_ offsets)
WMASK       EQU $6000       ; collision: 80 rows x 64 bytes (bit 7 = left)
WMMAP       EQU $7400       ; minimap glyph shadow (16 x 4 cells x 16 bytes)
WEND        EQU $7800

; level header (WHDR), as the original level header plus extras
LH_NAME     EQU 0           ; 24 bytes, 0-terminated
LH_N        EQU 24          ; bilbies
LH_RATE     EQU 25
LH_SAVE     EQU 26
LH_MIN      EQU 27
LH_SKILL    EQU 28          ; 8
LH_LWB      EQU 36          ; width / 4
LH_LH       EQU 37          ; height
LH_HX       EQU 38          ; hatch x (word), y
LH_HY       EQU 40
LH_EX       EQU 41          ; exit x (word), y
LH_EY       EQU 43
LH_BRICK    EQU 44          ; brick ink colour (colour mode)
LH_WY       EQU 45          ; water row (0 none), x0 (word), x1 (word)
LH_WX0      EQU 46
LH_WX1      EQU 48
LH_SPRINK   EQU 50          ; bilby ink colour (colour mode)
LH_NSTEEL   EQU 51
LH_STEEL    EQU 52          ; 8 x (x0.w y0 x1.w y1)
LH_SIZE     EQU 100

; ---------------- screen: 64 x 16 cells of 8 x 16 pixels (512 x 256)
; two pages: screen RAM 000h and 400h, flipped with the 6545 start address
SCOLS       EQU 64
PFROWS      EQU 10          ; playfield rows (160 lines = the level's height)
HUDROW      EQU 10          ; HUD: rows 10 - 15

; ---------------- PCG banks
; page 0 playfield: banks 0-5, page 1: banks 6-11. Glyph column gc (0-63)
; is bank gc/12 (+6), glyphs (gc mod 12)*10 + row: so a column's 160 bytes
; are contiguous at F800h + (gc mod 12)*160.
BK_PAGE1    EQU 6
BK_HUD      EQU 12          ; HUD, font, icons, minimap: banks 12 - 15
BLANK_CODE  EQU $80         ; HUD bank glyph 0 is blank

; ---------------- colours
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

; speaker service call: units of 64 T-states since the last call (sound.asm)
SND	MACRO units
	ld a,units
	call sndsvc
	ENDM
