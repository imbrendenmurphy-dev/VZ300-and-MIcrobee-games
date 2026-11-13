; =====================================================================
;  ZEPHYR ZONE                                  ViBED by BPM 2026
;  Dick Smith VZ300 + BennVenn SD loader + 128K.  Mode 1, 128x64x4.
; =====================================================================
; BennVenn port $37 (Bix / MAME sdloader.cpp, confirmed on the user's
; machine): bit0 = DOS RAM at $4000-$67FF, bit1 = which 10K bank there,
; bit2 = which 18K bank at $B800-$FFFF.
;   dos_map (1, or 0 if the DOS runs from ROM) = DOS low + upper bank 0
;   3 = bank 3 low + upper bank 0        (front end, common sprites)
;   7 = bank 3 low + upper bank 1        (racing through a world)
; The DOS's low bank and $FA00-$FFFF of upper bank 0 are never written.
BANKPORT    equ $37
MAP_FE      equ 3
MAP_GAME    equ 7

LATCH       equ $6800
FSREAD      equ $6FFF          ; keyboard read with no row selected: bit7 = FS (0 = sync)
VRAM        equ $7000
L_SPK0      equ $01
L_MODE      equ $08
L_CSS       equ $10
L_SPK1      equ $20

; ---- main RAM
IM2TAB      equ $7C00          ; 257 bytes of $7D -> vector at $7D7D
IM2VEC      equ $7D7D
STACK_TOP   equ $8000          ; stack $7D80-$7FFF
VARS        equ $A700          ; variables $A700-$AFFF (see vars.asm)
BB          equ $B000          ; back buffer, 64 rows x 32 bytes
HUDROWS     equ 6              ; rows 0-5: HUD, drawn straight into VRAM
BBCOPY      equ BB+HUDROWS*32  ; rows 6-63 are copied by the field ISR
NCOPY       equ 64-HUDROWS

; ---- bank 3 (mapping 3 or 7), see tools/tables.py
MASK0       equ $4000          ; colour-key 0: mask
MASK2       equ $4100          ; colour-key 2: mask
CLEAN2      equ $4200          ;               data with key pixels zeroed
PRJ_MX      equ $4300          ; per z index: x scale mantissa
PRJ_MY      equ $4400          ;              y scale mantissa
PRJ_E       equ $4500          ;              shift
PRJ_LV      equ $4600          ;              sprite level 0..10
PRJ_GY      equ $4700          ;              ground row below the horizon
GROW        equ $4800          ; ground rows d=1..DMAX, 16 bytes each:
                               ;  K, d, half, Zlo, dw base phase 0..3
STRIPS      equ $4AC0          ; ground strip library
DMAX        equ 44

; ---- upper bank 0
FE_CODE     equ $B800          ; front end code (part of the .VZ image)
COMMON      equ $C800          ; common sprites (hero, shots, explosions...) from ZZCOM.DAT
DOS_SP      equ $F800          ; stack for DOS calls: $F000-$F7FF (2K)
SECBUF      equ $F800          ; SD sector buffer (as 13 Ghosts / DC2)
; ---- upper bank 1: the current world (ZZWn.DAT)
WORLD       equ $B800          ; world header + sprite directory, then sprites, panorama
W_CSS       equ WORLD+0        ; colour set
W_SKY       equ WORLD+1        ; sky fill byte
W_PANO      equ WORLD+2        ; dw panorama (2 phases x 12 rows x 96 bytes)
W_NTYPES    equ WORLD+4
W_CODE      equ WORLD+$48      ; world module (tools/build.py assembles src/wN.asm here)
WJ_BSTART   equ W_CODE+0       ; jp boss start
WJ_BUPD     equ W_CODE+3       ; jp boss head update (IX)
WJ_BSEG     equ W_CODE+6       ; jp boss part update (IX)
WJ_BHIT     equ W_CODE+9       ; jp boss hit by a bolt (IX)
W_TL        equ W_CODE+12      ; dw stage timeline
W_SCN       equ W_CODE+14      ; scenery A: hit radius, height ; B: hit radius, height
W_TUNE      equ W_CODE+18      ; dw stage tune
W_BTUNE     equ W_CODE+20      ; dw boss tune
W_NAME      equ W_CODE+22      ; world name (16 chars + 0)
W_BNAME     equ W_CODE+39      ; boss name (16 chars + 0)
W_EHR       equ W_CODE+56      ; hit radius of creature types 19, 20, 21
W_GAL       equ W_CODE+59      ; dw nine names (sprite types 16-24) for the storyboard
W_HDREND    equ W_CODE+61
; world sprite types (fixed order in every world)
S_SCENA     equ 16             ; tall obstacle
S_SCENB     equ 17             ; second obstacle
S_SCENC     equ 18             ; harmless decoration
S_EN1       equ 19
S_EN2       equ 20
S_EN3       equ 21
S_BOSSA     equ 22
S_BOSSB     equ 23
S_BOSSC     equ 24
W_DIR       equ WORLD+8
SQTAB       equ $FC00          ; quarter squares (4 pages), upper bank 1 (from ZZCOM)        ; per world sprite type: dw frame table, db nframes, db nlevels

; sprite types: 0-15 common (upper bank 0), 16-31 world (upper bank 1)
T_HERO      equ 0
T_BOLT      equ 1
T_FIREBALL  equ 2
T_BOOM      equ 3
T_SHADOW    equ 4
T_ORB       equ 5
T_LOGOL     equ 6
T_LOGOR     equ 7
C_DIR       equ COMMON         ; common sprite directory (same layout as W_DIR)

NLEV        equ 11             ; sprite scale levels
PANH        equ 12             ; panorama rows
HZ_MIN      equ 20
HZ_MAX      equ 30

NWORLDS     equ 5
T_SPARK     equ 8
T_FLAME     equ 9
T_LOGOZ     equ 10
