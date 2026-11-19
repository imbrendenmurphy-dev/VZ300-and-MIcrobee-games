; =====================================================================
;  OVERRIDE                                        ViBED by BPM 2026
;  Dick Smith VZ300 + BennVenn SD loader + 128K.  Mode 1, 128x64x4.
; =====================================================================
; BennVenn port $37: bit0 = SRAM (not the DOS ROM) at $4000-$67FF,
; bit1 = which 10K low bank, bit2 = which 18K upper bank at $B800-$FFFF.
;   dos_map (1, or 0 if the DOS runs from ROM) = DOS low + upper bank 0
;   3 = low bank 3 + upper bank 0   (storage: ship data, pictures, text)
;   7 = low bank 3 + upper bank 1   (everything else)
BANKPORT    equ $37
MAP_STORE   equ 3
MAP_GAME    equ 7

LATCH       equ $6800
FSREAD      equ $6FFF          ; keyboard read with no row selected: bit7 = FS (0 = sync)
VRAM        equ $7000
L_SPK0      equ $01
L_MODE      equ $08
L_CSS       equ $10
L_SPK1      equ $20
LATCH_GAME  equ L_MODE|L_SPK0  ; mode 1, colour set 0, speaker at rest

; ---- main RAM
IM2TAB      equ $7C00          ; 257 bytes of $7D -> vector at $7D7D
IM2VEC      equ $7D7D
STACK_TOP   equ $8000          ; stack $7D80-$7FFF
CODE        equ $8000
VARS        equ $AC00          ; variables $B000-$B5FF (vars.asm)
BOUNCE      equ $B600          ; 512-byte SD bounce buffer / scratch
BOUNCE_END  equ $B800

; ---- low bank 3
RING        equ $4000          ; 4 phases x 64 rows x 32 bytes
RINGPH      equ $0800          ; phase stride
SPRC        equ $6000          ; sprite cache: 8 slots x 256 bytes
NSPRSLOT    equ 8

; ---- upper bank 1 (mapping 7)
BB          equ $B800          ; back buffer: 64 rows x 40 bytes
BBW         equ 40
BBG         equ 4              ; guard bytes left of each row
HUDROWS     equ 10
VIEWROWS    equ 54
VIEWTOP     equ BB+HUDROWS*BBW+BBG   ; first visible byte of the deck view
MAP         equ $C200          ; deck map 64 x 32
MAPW        equ 64
MAPH        equ 32
FECODE      equ $CA00          ; front end + copy code + data (OVCOM.DAT)

; ---- upper bank 0 (mapping 3, storage)
SHIP        equ $B800          ; ship data (OVSHIPn.DAT)
STORE2      equ $D800          ; title picture, text pages (OVCOM.DAT)
DOS_SP      equ $F800          ; stack for DOS calls: $F000-$F7FF
SECBUF      equ $F800          ; SD sector buffer

; ---- front end jump table (upper bank 0, OVCOM.DAT)
FE_JT       equ $B800
fe_main     equ FE_JT+0
fe_transfer equ FE_JT+3
fe_lift     equ FE_JT+6
fe_console  equ FE_JT+9
fe_shipcard equ FE_JT+12
fe_shipdone equ FE_JT+15
fe_gameover equ FE_JT+18
fe_ending   equ FE_JT+21

; ---- tiles
TILEW       equ 8
TILEH       equ 6
