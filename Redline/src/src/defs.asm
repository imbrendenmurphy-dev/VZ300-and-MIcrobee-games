; =====================================================================
;  REDLINE - COAST TO COAST            (c) 2026  ViBED by BPM
;  Dick Smith VZ300 + BennVenn SD loader + 128K.  Mode 1, 128x64x4.
; =====================================================================
; BennVenn port $37 (per Bix / MAME sdloader.cpp, confirmed on the user's
; machine): bit0 = DOS RAM at $4000-$67FF, bit1 = which 10K bank there,
; bit2 = which 18K bank at $B800-$FFFF.
;   1 = DOS bank low  + upper bank 0   (the DOS's own mapping, for SD calls)
;   3 = bank 3 low    + upper bank 0   (front end)
;   7 = bank 3 low    + upper bank 1   (racing)
; The DOS's bank (low, bit1=0) and $FA00-$FFFF of upper bank 0 are never
; written, so the DOS can still load the track files.
BANKPORT  equ $37
MAP_DOS   equ 1
MAP_FE    equ 3
MAP_RACE  equ 7

LATCH     equ $6800
VRAM      equ $7000
L_SPK0    equ $01
L_MODE    equ $08
L_CSS     equ $10
L_SPK1    equ $20

; ---- bank 3 ($4000-$67FF): engine tables ($4000-$5AFF, see road.asm)
SPRBANK3  equ $5E00       ; scenery sprite set (to $67FF)

; ---- upper bank 1 ($B800-$FFFF): the current track section + its scenery
TRK_CURV  equ $B800       ; per segment: curve (signed)
TRK_ALTL  equ $BA00       ; altitude at segment start, low
TRK_ALTH  equ $BC00       ;                            high
TRK_FLAG  equ $BE00       ; flags: bit0 tunnel, bit1 gantry, bit2 checkpoint
MAXSEG    equ 512         ; segments per section window
OBJLIST   equ $C000       ; roadside objects: seg lo, seg hi, type, x (sorted, $FFFF ends)
GANLIST   equ $C340       ; gantries: seg lo, seg hi, kind, seconds added
SECHDR    equ $C3C0       ; section header (64 bytes, see section_start)
G_START   equ 0
G_CHECK   equ 1
G_SECTION equ 2           ; checkpoint that also loads the next section
G_FINISH  equ 3
PANO      equ $C400       ; panorama: 2 phases x 16 rows x 64 bytes = 2K
SCENERY   equ $CC00       ; scenery sprite set (to $DFFF)
STRIPS    equ $E000       ; far-road strip cache, built per section ($E000-$FFFF)
; ---- upper bank 0 ($B800-$F9FF, $FA00+ = DOS): front end + common sprites
COMMON    equ $D400       ; cars, player car (to $F7FF; $F800-$F9FF = DOS sector buffer)
CAR_LV    equ COMMON
PCAR_TAB  equ COMMON+144

; ---- screen
HUDROWS   equ 12          ; rows 0-11: HUD, drawn straight into VRAM
BBTOP     equ 12          ; back buffer covers rows 12-63
BBROWS    equ 52
BB        equ $B180       ; 52 x 32 bytes = $B180-$B7FF
BBR0      equ BB-BBTOP*32 ; address of (virtual) row 0
HZ        equ 27          ; horizon row
PANOTOP   equ 12          ; panorama rows 12-27

; ---- road geometry (world units; a segment is 256 long)
CAMH      equ 144         ; camera height
ROADW     equ 192         ; road half width
NSEG      equ 30          ; draw distance in segments (for object arrays: 32)

IM2TAB    equ $7E00
IM2VEC    equ $7F7F
BOUNCE    equ $7F84       ; 120 bytes
BOUNCEN   equ 120

        MACRO bank n
        ld a,n
        out (BANKPORT),a
        ENDM
        MACRO NEGHL
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ENDM
