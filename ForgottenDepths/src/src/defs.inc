; =====================================================================
;  THE FORGOTTEN DEPTHS  -  VZ300 + BennVenn SD/128K
;  VIBED BY BPM 2026
;  defs.inc : hardware + memory map
; =====================================================================
LATCH   EQU $6800           ; write: b0/b5 speaker, b3 mode(1), b4 CSS ; read: b7 = /FS
VRAM    EQU $7000
KR0     EQU $68FE           ; b0 T  b1 W  b3 E  b4 Q  b5 R
KR1     EQU $68FD           ; b0 G  b1 S  b2 CTRL b3 D b4 A b5 F
KR2     EQU $68FB           ; b0 B  b1 X  b2 SHIFT b3 C b4 Z b5 V
KR3     EQU $68F7           ; b0 5  b1 2  b3 3  b4 1  b5 4
KR4     EQU $68EF           ; b0 N  b1 .  b3 ,  b4 SPACE b5 M
KR5     EQU $68DF           ; b0 6  b1 9  b3 8  b4 0  b5 7
KR6     EQU $68BF           ; b0 Y  b1 O  b2 RETURN b3 I b4 P b5 U
KR7     EQU $687F           ; b0 H  b1 L  b3 K  b4 ;  b5 J

M0G     EQU $20             ; mode(0), CSS0 (green text)   bit5 = speaker idle level
M0O     EQU $30             ; mode(0), CSS1 (orange text)
M1W     EQU $38             ; mode(1), CSS1 buff/cyan/magenta/orange
M1G     EQU $28             ; mode(1), CSS0 green/yellow/blue/red

LISTA   EQU $7800           ; light change lists (2 x 384 cells x 2 bytes)
LISTB   EQU $7B00
STACKTOP EQU $8000          ; stack $7E00-$7FFF

MAPH    EQU $CC             ; level map: row r at (MAPH+r)*256, x 0-127 tile, x+128 light
MAP     EQU MAPH*256        ; 45 rows -> $CC00-$F8FF  ($FA00+ untouched: SD DOS RAM)
MAPW    EQU 128
MAPROWS EQU 45
LSLOT_SIZE EQU $0DC0
WINW    EQU 32
WINH    EQU 15

; light byte: b0-2 current level, b3 in-change-list, b4-6 static level
LV_MEM  EQU 0
LV_CDIM EQU 1
LV_DIM  EQU 2
LV_COOL EQU 3
LV_LIT  EQU 4

; input bits
IN_R    EQU 0
IN_D    EQU 1
IN_L    EQU 2
IN_U    EQU 3
IN_FIRE EQU 4
IN_MAG  EQU 5
IN_MAP  EQU 6
IN_INV  EQU 7
