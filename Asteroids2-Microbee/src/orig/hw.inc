; ---------------------------------------------------------------------------
; ASTEROIDS II - hardware and memory constants
; Target: VZ300 + BennVenn SD loader / 128K (main RAM $7800-$F7FF used,
;         SRAM bank 1 at $4000-$67FF via port $37 = 3 for the sprite cache)
; ---------------------------------------------------------------------------
LATCH       equ $6800       ; write: b0/b5 speaker, b3 AG (1=CG2), b4 CSS
KBD         equ $6800       ; read: rows by address lines, b7 = field sync
VRAM        equ $7000
MAPPER      equ $37         ; BennVenn: b0 DOS RAM, b1 DOS-area bank, b2 hi bank
MAP_DOS     equ 1           ; as the DOS leaves it
MAP_BANK1   equ 3           ; second 10K SRAM bank at $4000

; keyboard rows (address low byte with one line low)
ROW0 equ $FE    ; R Q E . W T   (bits 5..0)
ROW1 equ $FD    ; F A D CTRL S G
ROW2 equ $FB    ; V Z C SHIFT X B
ROW3 equ $F7    ; 4 1 3 . 2 5
ROW4 equ $EF    ; M SPC , . . N
ROW5 equ $DF    ; 7 0 8 - 9 6
ROW6 equ $BF    ; U P I RET O Y
ROW7 equ $7F    ; J ; K : L H

; playfield / buffer geometry
PF_ROWS     equ 58          ; playfield rows (VRAM rows 6..63)
HUD_ROWS    equ 6
STRIDE      equ 44          ; 6 margin + 32 visible + 6 margin
MARGIN      equ 6

; ---------------------------------------------------------------------------
; runtime RAM (not part of the .VZ image)
; ---------------------------------------------------------------------------
; low RAM ($7800-$7FFF: BASIC/system area, ours once running with DI)
STACK_TOP   equ $7A00               ; stack $7800-$79FF
VARS        equ $7A00               ; 512 bytes
ROWTAB      equ $7C00               ; page aligned, 2*PF_ROWS
PARTS       equ $7D00
N_PART      equ 40
PARTSZ      equ 13
PARTS_END   equ PARTS + N_PART*PARTSZ
N_STAR      equ 18
STARS       equ PARTS_END               ; 6 bytes each
STARS_END   equ STARS + N_STAR*9
TSTAR       equ STARS_END               ; title stars, 4 bytes each
tstar       equ TSTAR
        ASSERT TSTAR + 14*4 <= $8000
; high RAM (after the persistent program)
RAM0        equ $D000
BUF         equ RAM0                    ; PF_ROWS*STRIDE = 2552 (+8 pad)
OBJS        equ BUF + 2560              ; object table
OBJSZ       equ 16
N_SHIP      equ 1
N_ROCK      equ 24
N_ENEMY     equ 4
N_ITEM      equ 6
N_PBUL      equ 12
N_EBUL      equ 8
OBJ_SHIP    equ OBJS
OBJ_ROCK    equ OBJ_SHIP  + OBJSZ*N_SHIP
OBJ_ENEMY   equ OBJ_ROCK  + OBJSZ*N_ROCK
OBJ_ITEM    equ OBJ_ENEMY + OBJSZ*N_ENEMY
OBJ_PBUL    equ OBJ_ITEM  + OBJSZ*N_ITEM
OBJ_EBUL    equ OBJ_PBUL  + OBJSZ*N_PBUL
OBJ_END     equ OBJ_EBUL  + OBJSZ*N_EBUL
SPRDESC     equ OBJ_END                 ; 8 * NSPRITES
CACHE_MAIN  equ SPRDESC + 8*NSPRITES    ; sprite cache overflow in main RAM
CACHE_MAIN_END equ $F800                ; $F800-$FFFF untouched (DOS work area)
CACHE_SRAM  equ $4000
CACHE_SRAM_END equ $6800

; object field offsets
O_TYPE  equ 0
O_XL    equ 1
O_XH    equ 2
O_YL    equ 3
O_YH    equ 4
O_VXL   equ 5
O_VXH   equ 6
O_VYL   equ 7
O_VYH   equ 8
O_SPR   equ 9
O_FRM   equ 10
O_TMR   equ 11
O_RX    equ 12
O_RY    equ 13
O_HP    equ 14
O_AUX   equ 15

; particle offsets
P_LIFE equ 0
P_COL equ 1
P_XL equ 2
P_XH equ 3
P_YL equ 4
P_YH equ 5

; sound channel record
CH_PTR  equ 0   ; 2 program pointer (0 = idle)
CH_CNT  equ 2   ; frames left in segment
CH_FRQ  equ 3   ; 2
CH_DF   equ 5   ; 2 freq delta per field
CH_DUTY equ 7
CH_DD   equ 8   ; signed duty delta
CH_PRIO equ 9
CH_MODE equ 10
CH_SIZE equ 11

        MACRO SEG fr, f, df, du, dd, md
        db fr
        dw f, df
        db du, dd, md
        ENDM
