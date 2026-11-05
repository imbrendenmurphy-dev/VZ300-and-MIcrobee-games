; =====================================================================
;  uB-TYPE  -  hardware constants and memory layout
;  Microbee Premium Plus: Z80 3.375 MHz, 1MB banked RAM, 32K PCG RAM
; =====================================================================

; ---------------- ports
P_PIOA      EQU $00         ; joystick (active low), b7 fire
P_PIOAC     EQU $01
P_PIOB      EQU $02         ; b6 = speaker
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

; ---------------- RAM blocks (32K each, lower window). Block 0 = upper 32K.
BLK_FRONT   EQU 1           ; front end code + data (title, screens, music)
BLK_WORK    EQU 2           ; shadows, cell slots, stage tables, sprite set
BLK_MIRROR  EQU 3           ; RAM copy of every PCG glyph (for compositing)
BLK_GFX     EQU 4           ; common glyphs (font, HUD, stars) + sprite library
BLK_TITLE   EQU 5           ; title artwork
BLK_STAGE   EQU 8           ; stage n data in block 8+n (8..15)
N_BLOCKS    EQU 16

; port 50h value for block n with ROMs off and the video window at F000:
;   b7 b6 b5 = n bits 4..2, b1 b0 = (n bits 1..0) xor 2, b2 = 1
MEMV        MACRO blk
            ld a,(((blk) & $1C) << 3) | (((blk) & 3) ^ 2) | 4
            out (P_MEM),a
            ENDM

; ---------------- screen: 64 x 16 cells of 8 x 16 pixels (512 x 256),
; two 1024-cell pages in the 2K ring (hardware coarse scroll + page flip)
SCOLS       EQU 64
PROWS       EQU 14          ; playfield rows (one per VZ tile row)
HUDROW      EQU 14          ; HUD = rows 14, 15

; ---------------- PCG banks
BK_FONT     EQU 0           ; font, HUD, stars, misc (banks 0-1)
BK_TERR     EQU 2           ; terrain phase 0 / phase 1 (banks 2-5)
BK_BAND     EQU 6           ; parallax band
BK_BOSS     EQU 7           ; boss body (banks 7-9)
BK_POOLA    EQU 10          ; sprite cells, page A (banks 10-11)
BK_POOLB    EQU 12          ; sprite cells, page B (banks 12-13)
BK_SPARE    EQU 14
BK_CACHE    EQU 14          ; boss-part glyph cache: 14 page A, 15 page B

BLANK_CODE  EQU $80         ; glyph 0 of bank 0 is blank

; ---------------- WORK block layout (lower window during play).
; A ring cell is addressed by its SHC address 7000h|addr; the other copies
; differ by single bits: screen / attribute window F000h|addr (set 7,h),
; SHK 7800h|addr (set 3,h), colour window F800h|addr (set 7 + set 3),
; SHA 5800h|addr (h xor 28h), CSLOT 6000h|addr (h xor 10h).
SPRDESC     EQU $0000       ; sprite set: descriptors then data (to 57FFh)
SHA         EQU $5800       ; shadow attribute (PCG bank)
CSLOT       EQU $6000       ; sprite cell slot + 1 this frame (0 = none)
BANDF       EQU $6800       ; band-capable cell flags
SHC         EQU $7000       ; shadow screen code
SHK         EQU $7800       ; shadow colour (paper<<4 | ink)

; ---------------- Premium colours
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
