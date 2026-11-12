; =====================================================================
;  SPINDRIFT - Microbee Premium Plus hardware, memory map, constants
;  Z80 3.375 MHz, 1MB RAM (32 blocks of 32K), 32K PCG RAM (16 banks of
;  128 glyphs), 6545 CRTC. A scanline is 216 T; a frame is 313 lines.
;
;  Display: the 40-column mode, 40 x 25 cells of 8 x 8 pixels (320 x
;  200) at half the dot clock.
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

; ---- RAM blocks (lower window 0000-7FFF). Block 0 is the upper 32K.
BLK_TAB     EQU 4           ; font, ship, shots, explosions, position table
BLK_ENM     EQU 5           ; enemy sprites
BLK_PIC     EQU 6           ; title picture
MP_TAB      EQU ((BLK_TAB & $1C) << 3) | ((BLK_TAB & 3) ^ 2) | 4
MP_ENM      EQU ((BLK_ENM & $1C) << 3) | ((BLK_ENM & 3) ^ 2) | 4
MP_PIC      EQU ((BLK_PIC & $1C) << 3) | ((BLK_PIC & 3) ^ 2) | 4

; ---- upper memory (block 0): code 8000-C7FF, then
CELLHI      EQU $C800       ; per cell: high byte of its glyph buffer (0 = none)
CELLLO      EQU $CC00       ; low byte (CELLHI + 400h: code relies on it)
POOLBUF     EQU $D000       ; this frame's composed glyphs, 8 bytes a slot
TRASH       EQU $D380       ; where sprites go under text
CELLPTR     EQU $D400       ; CELLHI address of each slot's cell
ENT         EQU $D500       ; game objects D500-D7FF
LISTA       EQU $D800       ; three cell lists, 1K each: addresses +0,
LISTB       EQU $DC00       ;  codes +200h, colours +300h, count +1FEh
LISTC       EQU $E000
TQA         EQU $E400       ; text queues: 5 bytes an entry, count at +3FFh
TQB         EQU $E800
VARS        EQU $EC00       ; EC00-EEFF
STACK       EQU $EFF0

MAXSLOT     EQU 111         ; sprite glyphs a frame (codes 91h-FFh)
MAXLIST     EQU 250
MAXTQ       EQU 200
NCELL       EQU 1000
PAGE1       EQU $0400       ; second screen page (6545 start address)

; ---- PCG banks
BK_FONT     EQU 0           ; 64 characters
BK_HUD      EQU 1           ; icons
BK_PIC      EQU 2           ; title picture: banks 2..9
BK_POOL0    EQU 14          ; page 0: blank, 16 star dots, 111 sprite glyphs
BK_POOL1    EQU 15

; ---- the playfield
CX          EQU 160
CY          EQU 100
R_RIM       EQU 224         ; the player's orbit (radius units: index * 4)

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
K_H         EQU 8
K_J         EQU 10
K_M         EQU 13
K_O         EQU 15
K_P         EQU 16
K_Q         EQU 17
K_R         EQU 18
K_S         EQU 19
K_X         EQU 24
K_Z         EQU 26
K_1         EQU $21
K_ESC       EQU $30
K_RET       EQU $34
K_SPACE     EQU $37
K_UP        EQU $38
K_DOWN      EQU $3A
K_LEFT      EQU $3B
K_RIGHT     EQU $3E

; ---- pad bits
PB_RIGHT    EQU 0
PB_LEFT     EQU 1
PB_UP       EQU 2
PB_DOWN     EQU 3
PB_FIRE     EQU 4
; ---- key bits
KB_ESC      EQU 0
KB_PAUSE    EQU 1
KB_SOUND    EQU 2
KB_MODE     EQU 3
KB_START    EQU 4
KB_RESTART  EQU 5
