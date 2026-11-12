; =====================================================================
;  SKYLARKIN'! - Microbee Premium Plus hardware, memory map, constants.
;  Z80 3.375 MHz; 1MB RAM (32 blocks of 32K); 32K PCG RAM (16 banks of
;  128 glyphs). 6545 CRTC: 40 x 25 characters of 8 lines = 320 x 200.
;  VIBED BY BPM 2026
; =====================================================================
P_PIOA      EQU $00         ; joystick (active low), b7 fire
P_PIOAC     EQU $01
P_PIOB      EQU $02         ; b6 speaker
P_PIOBC     EQU $03
P_COLCTL    EQU $08         ; b6: F800 window = colour RAM
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
COLWIN      EQU $F800

; ---- RAM blocks (lower window 0000-7FFF). Block 0 is the upper 32K.
BLK_RT      EQU 1           ; runtime: base maps (cur_*), scratch
BLK_SPR     EQU 3           ; pilots, bells, capsules, explosions (+ glyph store)
; the stage blocks come from build/blocks.inc (BLK_S1A ...)
BLK_STRIP   EQU 29          ; 29, 30, 31: the current stage's expanded strips

; ---- RT block layout
RT_CURLO    EQU $0000       ; base picture of the playfield: glyph low codes
RT_CURHI    EQU $0400       ;   banks
RT_CURCOL   EQU $0800       ;   colours
RT_SCR      EQU $1000       ; scratch (stage expansion)

; ---- PCG banks
BK_FONT     EQU 0           ; blank, font, HUD icons
BK_STAGE    EQU 1           ; 1..9: the stage's scenery
BK_FAST     EQU 10          ; 10..11: ready-made bullet and shot glyphs
BK_BOSS     EQU 12          ; 12 (page 0), 13 (page 1): the boss
BK_POOL     EQU 14          ; 14 (page 0), 15 (page 1): sprite cells
POOLN       EQU 120         ; glyphs per pool
DLN         EQU 126         ; direct (ready-made glyph) cells per frame
STORE_TOP   EQU 12          ; banks 0..11 have an 8-byte copy at 0000h of every sprite block

; ---- the screen: 40 x 25. Row 0 score line, rows 1-23 playfield, row 24 upgrade bar
PF_TOP      EQU 1
PF_ROWS     EQU 23
PF_Y0       EQU 8           ; first playfield pixel line on the screen
PF_Y1       EQU 192         ; one past the last

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

; ---- upper memory tables (page aligned)
CELLMAP     EQU $D000       ; per cell: 0 free, 1..120 pool glyph+1, 80h+n direct cell n
PL_LO       EQU $D400       ; pool glyph k: its cell (lo, hi), ink
PL_HI       EQU $D500
PL_INK      EQU $D600
DL_LO       EQU $D700       ; direct cell n (n < 128): cell lo
DL_HI       EQU $D780       ;   cell hi
DL_CODE     EQU $D800       ;   glyph code (80h+n)
DL_BANK     EQU $D880       ;   bank (FFh = void: taken over by the pool)
DL_INK      EQU $D900       ;   ink
GLYPHBUF    EQU $D980       ; 16 bytes
ELIST       EQU $D990       ; live enemy boxes: 18 x 6 bytes
RL0         EQU $DA00       ; restore list of page 0: video addresses (dw), 256
RL1         EQU $DC00       ; page 1
BL0         EQU $DE00       ; boss cells drawn on page 0 (dw), 128
BL1         EQU $DF00       ; page 1
SCRATCH     EQU $E000       ; 1K scratch: bounce buffer, stage expansion
BOUNCE      EQU $E000
VARS        EQU $E400
STACK       EQU $EFFE

; ---- the stage overlay: each stage's enemy types, waves and boss, copied
; here from its B block when the stage loads (tools/build.py, src/stageN.asm)
OVL         EQU $C000
OVL_END     EQU $D000
ovl_wave        EQU OVL+0       ; A = wave type, C = y
ovl_boss_start  EQU OVL+3
ovl_boss_update EQU OVL+6
ovl_shot_boss   EQU OVL+9       ; shot IX against the boss
ovl_boss_area   EQU OVL+12      ; E = blast damage
ovl_boss_touch  EQU OVL+15      ; the pilot's box (hx0..hy1) against the boss
ovl_boss_objs   EQU OVL+18      ; beams etc., drawn with the small objects
ovl_on_kill     EQU OVL+21      ; IX = enemy shot down -> NZ if handled
ETYPE_TAB       EQU OVL+32
