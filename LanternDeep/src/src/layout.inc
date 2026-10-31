; =====================================================================
; THE LANTERN DEEP - memory layout and hardware constants
; Microbee Premium Plus (Z80 3.375 MHz, 1MB banked RAM, 32K PCG RAM)
; =====================================================================

; ---------------- ports
P_PIOA      EQU $00         ; joystick (active low)
P_PIOAC     EQU $01
P_PIOB      EQU $02         ; bit 6 = speaker
P_PIOBC     EQU $03
P_COLCTL    EQU $08         ; bit 6: F800 window = colour RAM
P_ROMLAT    EQU $0B         ; 1 = character ROM / keyboard latch
P_CRTCA     EQU $0C         ; 6545 address / status
P_CRTCD     EQU $0D
P_LV        EQU $1C         ; b7 premium graphics, b4 attribute RAM, b0-3 PCG bank
P_MEM       EQU $50         ; memory map (see bank_port)

LV_SCREEN   EQU $80         ; F000 = screen RAM, F800 = PCG bank n (| n)
LV_ATTR     EQU $90         ; F000 = attribute RAM
COL_ON      EQU $40

; port 50h values: lower 32K = block 1 ("home"), ROMs off; b3 = video off
MEM_HOME_V  EQU $07         ; video window at F000
MEM_HOME    EQU $0F         ; no video window

VIDEO       EQU $F000
PCGWIN      EQU $F800
COLWIN      EQU $F800

; asset blocks (filled by LANTERN.COM, see src/loader.asm)
BLK_GFX     EQU 8
BLK_WORLD   EQU 9
BLK_TITLE   EQU 10
BLK_AUDIO   EQU 11
BLK_WORLD2  EQU 12          ; glimmer-lantern ray-trees
BLK_STATE   EQU 13          ; explored cells per room (256 bytes each)
BLK_REGION  EQU 16          ; region n: PCG tiles + tables at 16+2n, rooms at 17+2n

; ---------------- screen
SCR_COLS    EQU 80
SCR_ROWS    EQU 24
PLAY_ROWS   EQU 22
HUD_ROW     EQU 22

; ---------------- map buffers (24 rows x 128, 1-cell border round the
; 80x22 play area). Every array shares the same layout so a cell pointer
; into FLAGS reaches the others by adding a constant to H (mod 256).
; FLAGS and LIGHT live in the fixed upper block so the ray-cast can run
; while the lower window shows the WORLD bank holding the ray-trees.
STRIDE      EQU 128
FLAGS       EQU $C000       ; upper
LIGHT       EQU $CC00       ; upper
TILE        EQU $3400       ; lower (home block)
STAT        EQU $4000
ENT         EQU $4C00
SHCHR       EQU $5800
SHCOL       EQU $6400
SHKEY       EQU $7000       ; last light key drawn (to $7BFF)
D_TILE      EQU ((TILE-FLAGS)>>8)&$FF
D_STAT      EQU ((STAT-FLAGS)>>8)&$FF
D_LIGHT     EQU ((LIGHT-FLAGS)>>8)&$FF
D_ENT       EQU ((ENT-FLAGS)>>8)&$FF
D_SHCHR     EQU ((SHCHR-FLAGS)>>8)&$FF
D_SHCOL     EQU ((SHCOL-FLAGS)>>8)&$FF
D_SHKEY     EQU ((SHKEY-FLAGS)>>8)&$FF

; FLAGS bits
F_OPAQUE    EQU 0           ; blocks light
F_EDGE      EQU 1           ; outside the play area
F_FACE      EQU 2           ; wall face: light also reaches the cell above
F_SOLID     EQU 3           ; blocks movement
F_CYCLE     EQU 4           ; colour-cycling tile
F_QUEUED    EQU 5           ; in the dirty queue
F_REVEAL    EQU 6           ; static light of this cell is visible
F_SEEN      EQU 7           ; explored

; ---------------- upper (fixed) block work areas
LISTA       EQU $D800       ; lit-cell lists (768 entries each)
LISTB       EQU $DE00
OUTQ        EQU $E400       ; output queues (see core.asm)
BOUNCE      EQU $EA00       ; 256-byte bounce buffer for bank copies
DIRTYQ      EQU $EB00       ; dirty cell queue (up to 380 cells)
STACK       EQU $EFFE
