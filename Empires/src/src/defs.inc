; ===================================================================
;  EMPIRES : THE LIVING WORLD  -  Microbee Premium Plus
;  ViBED by BPM 2026
;  defs.inc - hardware and game constants
; ===================================================================

; ---- hardware (verified against MAME mbee driver + FPGABee docs) ----
SCRN      equ 0F000h     ; 2K screen RAM (port 1C bit4=0) / attribute RAM (bit4=1)
HIRAM     equ 0F800h     ; 2K PCG bank window (port 08 bit6=0) / colour RAM (bit6=1)
P_COL     equ 08h        ; bit6: 1 = colour RAM at F800
P_EXT     equ 1Ch        ; bit7 ext graphics, bit4 attr RAM, bits3-0 PCG bank at F800
P_CRTCA   equ 0Ch        ; 6545 address / status (b7 update, b6 lpen, b5 vblank)
P_CRTCD   equ 0Dh
P_PIOB    equ 02h        ; bit6 = speaker
P_PIOAC   equ 01h        ; PIO A control
P_PIOBC   equ 03h        ; PIO B control
P_PIOA    equ 00h        ; joystick (active low: b0 up b1 down b2 left b3 right b7 fire)
P_ROMLAT  equ 0Bh        ; 1 while scanning the keyboard (as the boot ROM/BIOS do)
EXT_ON    equ 80h
EXT_ATTR  equ 90h

; ---- screen layout (80x24 text mode inherited from CP/M) ----
COLS      equ 80
ROWS      equ 24
SCRSIZE   equ COLS*ROWS
VIEWW     equ 40          ; tiles across (2 chars each)
VIEWH     equ 20          ; tile rows
VIEWROW   equ 1           ; first screen row of map view
MSGROW    equ 21
TOOLROW   equ 22
INFOROW   equ 23

; ---- world ----
MAPW      equ 112
MAPH      equ 112
MAPSIZE   equ MAPW*MAPH

; terrain ids (low 5 bits of terrain byte; bit7 = explored)
T_DEEP    equ 0
T_SHALLOW equ 1
T_RIVER   equ 2
T_BEACH   equ 3
T_GRASS   equ 4
T_MEADOW  equ 5
T_FOREST  equ 6
T_DENSE   equ 7
T_HILLS   equ 8
T_MOUNT   equ 9
T_SNOW    equ 10
T_DESERT  equ 11
T_MARSH   equ 12
T_FIELD   equ 13
T_ROCK    equ 14
T_RUINS   equ 15
EXPLORED  equ 80h

; object ids (bit7 = under construction)
O_NONE    equ 0
O_ROAD    equ 1
O_TC_TL   equ 2
O_TC_TR   equ 3
O_TC_BL   equ 4
O_TC_BR   equ 5
O_HUT     equ 6
O_HOUSE   equ 7
O_MANOR   equ 8
O_FARM    equ 9
O_WOOD    equ 10
O_QUARRY  equ 11
O_WELL    equ 12
O_MARKET  equ 13
O_MILL    equ 14
O_TOWER   equ 15
O_COUNT   equ 16
BUILDING  equ 80h

; tools
NTOOLS    equ 10

; keyboard matrix codes (6545 light-pen scan; A=1..Z=26, '0'=32..'9'=41)
K_A equ 1
K_C equ 3
K_D equ 4
K_F equ 6
K_G equ 7
K_H equ 8
K_I equ 9
K_J equ 10
K_K equ 11
K_L equ 12
K_M equ 13
K_N equ 14
K_P equ 16
K_Q equ 17
K_S equ 19
K_W equ 23
K_X equ 24
K_Y equ 25
K_0 equ 32
K_1 equ 33
K_COMMA equ 44
K_DOT equ 46
K_ESC equ 48
K_TAB equ 50
K_RET equ 52
K_SPACE equ 55
K_SHIFT equ 63
K_UP    equ 38h
K_DOWN  equ 3Ah
K_LEFT  equ 3Bh
K_RIGHT equ 3Eh

; colours (Premium RGBI: low nibble fg, high nibble bg)
BLACK equ 0
RED equ 1
GREEN equ 2
YELLOW equ 3
BLUE equ 4
MAGENTA equ 5
CYAN equ 6
GREY equ 7
DGREY equ 8
BRED equ 9
BGREEN equ 10
BYELLOW equ 11
BBLUE equ 12
BMAGENTA equ 13
BCYAN equ 14
WHITE equ 15

; UI colour scheme
C_TEXT    equ COL(WHITE,BLACK)
C_DIM     equ COL(GREY,BLACK)
C_PANEL   equ COL(WHITE,BLUE)
C_PANELHI equ COL(BYELLOW,BLUE)
C_STATUS  equ COL(WHITE,BLUE)
C_STATNUM equ COL(BYELLOW,BLUE)
C_MSG     equ COL(BYELLOW,BLACK)
C_WARN    equ COL(BRED,BLACK)
C_GOOD    equ COL(BGREEN,BLACK)
C_TITLE   equ COL(BCYAN,BLACK)
