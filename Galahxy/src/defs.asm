; =====================================================================
;  GALAHXY                                        VIBED BY BPM 2026
;  Dick Smith VZ300 + BennVenn SD loader + 128K.  Mode 1, 128x64x4.
; =====================================================================
; BennVenn port $37 (MAME sdloader model, confirmed on the user's VZ300):
;   bit0 = SRAM at $4000-$67FF, bit1 = which 10K bank there,
;   bit2 = which 18K bank at $B800-$FFFF.
;   dos_map (1, or 0 if the DOS runs from ROM): DOS low bank + upper bank 0
;   MAP_GAME = 7: SRAM bank 3 low + upper bank 1   (everything runs here)
; The DOS's low bank and upper bank 0 ($F000+) are touched only by the DOS
; and the SD loader's stack/sector buffer.
BANKPORT    equ $37
MAP_GAME    equ 7

LATCH       equ $6800
FSREAD      equ $6FFF          ; bit7 = FS (0 = in field sync)
VRAM        equ $7000
L_SPK0      equ $01
L_MODE      equ $08
L_CSS       equ $10
L_SPK1      equ $20

; ---- main RAM
IM2TAB      equ $7C00          ; 257 bytes of $7D -> vector at $7D7D
IM2VEC      equ $7D7D
STACK_TOP   equ $8000          ; stack $7D80-$7FFF
VARS        equ $AB00          ; variables + object tables $AB00-$AFFF
BB          equ $B000          ; back buffer 0 (main RAM; also the SD bounce buffer)
BB1         equ $F800          ; back buffer 1 (upper bank 1)
HUDROWS     equ 6              ; rows 0-5: HUD, written straight into VRAM
SPLITROW    equ 32             ; ISR copies rows 6-31 in one field, 32-55 the next
COPYEND     equ 56             ; rows 56-63: the power bar, drawn straight into VRAM

; ---- SRAM bank 3 low ($4000-$67FF, mapping 7)
GRING       equ $4000          ; ground rings: 4 shifts x 18 rows x 64 bytes
GROWS       equ 18
GTOP        equ 38             ; screen row of the ground band
SRING       equ GRING+4*GROWS*64   ; skyline rings: 4 shifts x 12 rows x 64
SROWS       equ 12
STOP        equ 26
COM_LO      equ SRING+4*SROWS*64   ; $5E00: common data (GLXCOM.DAT)
HISCORES    equ $67C0          ; high-score table (survives until power-off)
; ---- upper bank 1 (mapping 7)
STAGE       equ $B800          ; stage pack (GLXS1.DAT)
STAGE_END   equ $E400
COM_HI      equ $E400          ; front end + common sprites (GLXCOM.DAT) to $FFFF

; ---- SD loader (DOS mapping: upper bank 0)
DOS_SP      equ $F800          ; DOS-call stack $F000-$F7FF in upper bank 0
SECBUF      equ $F800

; ---- playfield
PF_TOP      equ 6              ; first playfield row
PF_BOT      equ 55             ; last playfield row
BAR_ROW     equ 56             ; power bar rows 56-63 (straight into VRAM)
XOFF        equ 32             ; object x is stored +32 (screen x -32..223)
YOFF        equ 16             ; object y is stored +16

; ---- keys (in_now bits)
K_UP        equ 1
K_DOWN      equ 2
K_LEFT      equ 4
K_RIGHT     equ 8
K_FIRE      equ 16
K_ARM       equ 32             ; buy the highlighted power-up
K_PAUSE     equ 64
K_ANY       equ 128

; ---- stage pack header (fixed addresses at the start of every GLXSn.DAT)
STG_INIT    equ STAGE+0         ; jp: set up the stage (timeline, maps, palette)
STG_FRAME   equ STAGE+3         ; jp: once per frame (midboss / boss brains)
STG_OBJ     equ STAGE+6         ; jp: behaviour BH_STAGE for object IX
STG_HIT     equ STAGE+9         ; jp: object IX (stage behaviour) took C damage
STG_KILL    equ STAGE+12        ; jp: a hooked type was destroyed (IX)
STG_SEG     equ STAGE+15        ; jp: feed the next ground segment (gm_p, gm_left)
STG_DRAW    equ STAGE+18        ; jp: draw stage extras after the objects
STG_GTILES  equ STAGE+21        ; dw ground tiles (18 bytes each)
STG_STILES  equ STAGE+23        ; dw skyline tiles (12 bytes each)
STG_SMAP    equ STAGE+25        ; dw skyline map (SKY_C entries)
STG_ATTRACT equ STAGE+27        ; dw demo input script (attract mode)
STG_SPRTAB  equ STAGE+$40       ; sprite frames 128.. (dw each, max 96)
STG_TYPES   equ STAGE+$100      ; object types 0..31, 10 bytes each
STG_CODE    equ STAGE+$240      ; stage code and data from here
SKY_C       equ 128             ; skyline map length (columns, loops)

; stage phases
PH_PLAY     equ 0
PH_MID      equ 1
PH_BOSS     equ 2
PH_CLEAR    equ 3
PH_OVER     equ 4
