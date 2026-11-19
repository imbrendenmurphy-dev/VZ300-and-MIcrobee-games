; =====================================================================
;  BIX THE BILBY - THE STAR DIGGER          (c) 2026  ViBED by BPM
;  Dick Smith VZ300 + BennVenn SD loader + 128K.   Mode 1, 128x64x4.
; =====================================================================
; ---------------------------------------------------------------------
; Memory map
;   $4000-$45FF  shift tables (SRAM, built at boot)  LS1,RS1,LS2,RS2,LS3,RS3
;   $4600-$46FF  sprite mask table (SRAM, built at boot)
;   $4700-$5FFF  pre-shifted sprites (SRAM, copied from load image)
;   $6000-$67FF  work: entity pool, particles, spawn states, star list
;   $6800        latch / keyboard     $7000-$77FF video RAM
;   $7800-$7FFF  variables + stack
;   $8000-$ADFF  code + resident data
;   $AE00-$AF00  IM2 vector table (I=$AE, all $AF) ; $AFAF: JP isr
;   $B000-$E2FF  4-phase ring buffer (96 rows x 4 phases x 34 bytes)
;                (holds the staged SRAM/map data at load time)
;   $E300-$EBBF  back buffer: 56 rows x 40 bytes (4 guard bytes each side)
;   $EC00-$F98B  level map (column-major, 12 rows per column, +1 sky column)
;   $FA00-$FFFF  untouched (BennVenn DOS workspace)
; ---------------------------------------------------------------------
LATCH     equ $6800
VRAM      equ $7000
LS1       equ $40          ; page numbers of the shift tables
MASKPG    equ $46
SPRITES   equ $4700
POOL      equ $6000        ; entity pool  (NENT x 16)
NENT      equ 10
PARTS     equ $60A0        ; particles    (NPART x 8)
NPART     equ 16
ENTST     equ $6120        ; per-spawn-record state (64)
STARL     equ $6160        ; star tile list (x lo, x hi, y) x 128
STARMAX   equ 128
RING      equ $B000
RW        equ 34           ; ring width in bytes
RSTRIDE   equ RW*4         ; bytes per ring row (4 phases)
RROWS     equ 96
BB        equ $E300
BBW       equ 40
BBVIS     equ BB+4
PFROWS    equ 56           ; visible playfield rows (VRAM rows 8..63)
MAP       equ $EC00
ENTLIST   equ $6300        ; spawn list (copied from load image)
tattr     equ $6400        ; tile attributes (page aligned, 64 used)
IM2TAB    equ $AE00
IM2VEC    equ $AFAF

LATBASE   equ $08          ; mode 1, colour set 0

; keys
KB_L equ 0
KB_R equ 1
KB_U equ 2
KB_D equ 3
KB_J equ 4
K_L  equ 1
K_R  equ 2
K_U  equ 4
K_D  equ 8
K_J  equ 16

; player states
ST_NORM   equ 0
ST_BURROW equ 1
ST_DIE    equ 2
ST_WIN    equ 3

; physics (1/16 pixel units per game frame, 25 fps)
ACC     equ 3
AIRACC  equ 2
SKID    equ 6
FRIC    equ 3
MAXV    equ 46
JUMPV   equ 66
CUTV    equ 20
GRAV    equ 7
GRAVHI  equ 5
MAXFALL equ 80
SPRINGV equ 104
BURSTV  equ 90
STOMPV  equ 58
DIGV    equ 24

; entity types (spawn list) - must match tools/lvlkit.py
E_ANT   equ 1
E_MAG   equ 2
E_DROP  equ 3
E_TOAD  equ 4
E_PLATH equ 5
E_PLATV equ 6
E_GLOW  equ 7
E_ONEUP equ 8
E_START equ 9
E_WORM  equ 10
E_BOOM  equ 11
E_SPIT  equ 12
E_BOSS  equ 13
; overlay entry points (jump table at the start of the overlay)
OVL_TITLE  equ $B000
OVL_INTRO  equ $B003
OVL_CLEAR  equ $B006
OVL_OVER   equ $B009
OVL_ENDING equ $B00C
OVL_LOADLV equ $B00F
OVL_LOADPL equ $B012
OVL_HISC   equ $B015
OVL_TAMENU equ $B018
OVL_TARES  equ $B01B

TIME_LEVEL equ 400
TIME_BOSS  equ 300
