; ============================================================================
;  TEXT  (font: A-Z 0-9 . , ! ? - : ' / ( ) * @=(c) < > + = # %)
;  card format: row, colour (0 yellow 1 red 2 green), "text", 0 ... $FF
; ============================================================================
STR_READY:   db "READY!",0
STR_PAUSED:  db "- PAUSED -",0
STR_CHECK:   db "CHECKPOINT!",0
STR_REPAIR:  db "ARMOUR REPAIRED!",0
STR_UPGRADE: db "WEAPON ENCHANTED!",0
STR_1UP:     db "EXTRA LIFE!",0
WNAMES:      dw .w0,.w1,.w2,.w3
.w0:         db "LANCE!",0
.w1:         db "DAGGERS!",0
.w2:         db "BATTLE AXE!",0
.w3:         db "FIRE TORCH!",0
STR_HIGH:    db "HALL OF HEROES",0
STR_NEWHI:   db "A NEW HERO!",0
STR_ENTER:   db "ENTER YOUR INITIALS",0
STR_CURSOR:  db "-",0

CARD_CLEAR:
        db 8,0,"SUNSTONE RECOVERED!",0
        db 25,2,"STAGE BONUS 30000",0
        db $FF
CARD_OVER:
        db 14,0,"GAME OVER",0
        db 28,0,"CONTINUE? PRESS FIRE",0
        db 46,2,"YOUR ARMOUR IS KEPT",0
        db $FF
HISCORE_INIT:
        db $00,$20,$00,"BPM"
        db $00,$15,$00,"VZ3"
        db $00,$10,$00,"DSE"
        db $00,$05,$00,"SIR"
        db $00,$02,$50,"TIN"
HISCORE_INIT_END:
