; =====================================================================
;  MICROBEE MEGADEMO - hardware and memory layout (Premium Plus)
;  Z80 3.375 MHz, 1MB banked RAM (32 blocks of 32K), 32K PCG RAM,
;  6545 CRTC: a character every 2 T, a scanline = 108 chars = 216 T,
;  a frame = 313 lines = 67608 T (50 Hz)
; =====================================================================

; ---------------- ports
P_PIOA      EQU $00         ; joystick
P_PIOAC     EQU $01
P_PIOB      EQU $02         ; b6 speaker
P_SPK       EQU $02
P_PIOBC     EQU $03
P_COLCTL    EQU $08         ; b6: F800 window = colour RAM
P_ROMLAT    EQU $0B         ; 1 during keyboard scans
P_CRTCA     EQU $0C         ; 6545 address / status (b5 vertical blanking)
P_CRTCD     EQU $0D
P_LV        EQU $1C         ; b7 premium graphics, b4 attribute RAM, b0-3 PCG bank
P_MEM       EQU $50

LV_SCREEN   EQU $80         ; F000 = screen RAM, F800 = PCG bank (| n)
LV_ATTR     EQU $90         ; F000 = attribute RAM
COL_ON      EQU $40

VIDEO       EQU $F000
PCGWIN      EQU $F800
COLWIN      EQU $F800

; port 50h value for block n with ROMs off and the video window at F000
MEMV        MACRO blk
            ld a,(((blk) & $1C) << 3) | (((blk) & 3) ^ 2) | 4
            out (P_MEM),a
            ENDM

; ---------------- colours (RGBI)
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

; ---------------- memory (block 0 = 8000h-FFFFh, always mapped)
LP          EQU $E000       ; the line program (kernel display list), 2K
LP2         EQU $E800       ; part scratch (2K)
STACK       EQU $EFF0

; ---------------- key codes (6545 light pen scan)
K_C         EQU 3
K_M         EQU 13
K_ESC       EQU $30
K_RET       EQU $34
K_SPACE     EQU $37

; ---------------- permanent PCG banks
BK_PAT0     EQU 13          ; glyph g: line 0 = g (00-7F)
BK_PAT1     EQU 14          ; glyph g: line 0 = 80h + g
BK_FONT     EQU 15          ; the 8x16 font, ASCII 32-127
