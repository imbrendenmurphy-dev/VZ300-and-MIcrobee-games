; ==========================================================================
; defs.asm - shared constants for BUNYIP
;   VIBED BY BPM 2026
; ==========================================================================

; entity record (ENT array, NENT x ESIZE)
E_TYPE  equ 0           ; 0 = free, see T_*
E_X     equ 1           ; x, 8.8 (fraction, cell)
E_Y     equ 3           ; y, 8.8
E_HP    equ 5
E_ST    equ 6           ; state, see ST_*
E_TM    equ 7           ; state timer (fields)
E_AN    equ 8           ; animation clock
E_KIND  equ 9           ; creature kind (K_*), or item image
E_IMG   equ 10          ; image (frame 0)
E_INK   equ 11
E_F     equ 12          ; height: 64 = a wall's half height... 128 = full wall
E_FL    equ 13          ; flags, see F_*
E_CD    equ 14          ; attack cooldown (creatures) / x speed (shots)
E_VY    equ 15          ; y speed (shots)
E_VX    equ 14
ESIZE   equ 16
NENT    equ 48

; entity types
T_GKEY  equ 1
T_BKEY  equ 2
T_RKEY  equ 3
T_PIE   equ 4
T_CHG   equ 5
T_OPAL  equ 6
T_ENEMY equ 8
T_BOSS  equ 10
T_ROCK  equ 12
T_FIRE  equ 13

; states
ST_IDLE equ 0
ST_CHASE equ 1
ST_PAIN equ 2
ST_DIE  equ 3
ST_GONE equ 4

; flags
F_FLY   equ 1
F_BOSS  equ 2
F_LOS   equ 4           ; last line-of-sight check saw the player

; creature kinds
KD_REDBACK equ 0
KD_FLYFOX equ 1
KD_YOWIE equ 2
KD_BUNYIP equ 3

; map cell types
C_DOOR  equ 5
C_GDOOR equ 6
C_BDOOR equ 7
C_RDOOR equ 8
C_LEVER equ 9
C_LEVON equ 10
C_EXIT  equ 11
C_GATE  equ 12
C_SECRET equ 13
C_BGATE equ 14

; colours
CBLACK  equ 0
CRED    equ 1
CGREEN  equ 2
CBROWN  equ 3
CBLUE   equ 4
CMAGENTA equ 5
CCYAN   equ 6
CGREY   equ 7
CDGREY  equ 8
CBRED   equ 9
CBGREEN equ 10
CYELLOW equ 11
CBBLUE  equ 12
CBMAG   equ 13
CBCYAN  equ 14
CWHITE  equ 15

MARGIN  equ 0050h       ; keep 0.31 cells away from walls
TURN    equ 14          ; angle units per field (2048 = full circle)
