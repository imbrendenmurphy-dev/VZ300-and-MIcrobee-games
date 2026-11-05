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
STR_BOSS:    db "GRAVEMAW AWAKENS!",0
STR_PRESS:   db "PRESS FIRE",0
STR_COPY:    db "@ 2026 VIBED BY BPM",0
STR_MENUTITLE: db "- DREADMOOR -",0
STR_M_START: db "START GAME",0
STR_M_DIFF:  db "LEVEL: ",0
STR_M_MUSIC: db "MUSIC: ",0
STR_M_CTRL:  db "CONTROLS",0
STR_M_HIGH:  db "HIGH SCORES",0
STR_M_CRED:  db "CREDITS",0
DIFFNAMES:   dw .d0,.d1,.d2
.d0:         db "CASUAL",0
.d1:         db "NORMAL",0
.d2:         db "EXPERT",0
ONOFF:       dw .on,.off
.on:         db "ON",0
.off:        db "OFF",0
WNAMES:      dw .w0,.w1,.w2,.w3
.w0:         db "LANCE!",0
.w1:         db "DAGGERS!",0
.w2:         db "BATTLE AXE!",0
.w3:         db "FIRE TORCH!",0
STR_HIGH:    db "HALL OF HEROES",0
STR_NEWHI:   db "A NEW HERO!",0
STR_ENTER:   db "ENTER YOUR INITIALS",0
STR_CURSOR:  db "-",0
STR_BEAST:   db "- CREATURES OF THE NIGHT -",0

STORY1:
        db 6,0,"THE KINGDOM OF DREADMOOR",0
        db 16,2,"THE SORCERER MORGRAVE HAS",0
        db 23,2,"STOLEN THE SEVEN SUNSTONES.",0
        db 30,2,"THE SUN WILL NOT RISE AND",0
        db 37,2,"THE DEAD WALK THE LAND...",0
        db $FF
STORY2:
        db 6,0,"ONE KNIGHT REMAINS AWAKE:",0
        db 16,0,"SIR TINPLATE",0
        db 24,2,"THE LEAST IMPRESSIVE KNIGHT",0
        db 31,2,"IN THE REALM, IN BORROWED",0
        db 38,2,"TIN ARMOUR. WHAT COULD GO",0
        db 45,2,"WRONG?",0
        db $FF
STORY3:
        db 6,0,"WIN BETTER ARMOUR.",0
        db 14,0,"FIND MIGHTIER WEAPONS.",0
        db 22,0,"BRING BACK THE DAWN!",0
        db 34,2,"(AND TRY TO KEEP",0
        db 41,2,"YOUR TROUSERS ON)",0
        db $FF
CARD_STAGE1:
        db 8,0,"STAGE 1",0
        db 16,0,"GALLOWS HILL",0
        db 46,2,"THE DEAD DO NOT REST HERE",0
        db $FF
CARD_CLEAR:
        db 8,0,"SUNSTONE RECOVERED!",0
        db 18,2,"1 OF 7",0
        db 28,2,"STAGE BONUS 30000",0
        db $FF
CARD_END:
        db 4,0,"THE FIRST SUNSTONE GLOWS.",0
        db 12,2,"BEYOND THE HILL LIE THE",0
        db 19,2,"WITCHWOOD, THE DROWNED VILLAGE",0
        db 26,2,"THE SWAMP OF THE DAMNED, THE",0
        db 33,2,"CRYSTAL DEEPS... AND MORGRAVE.",0
        db 46,0,"TO BE CONTINUED...",0
        db 56,0,"THANK YOU FOR PLAYING!",0
        db $FF
CARD_OVER:
        db 14,0,"GAME OVER",0
        db 28,0,"CONTINUE? PRESS FIRE",0
        db 50,2,"YOUR ARMOUR IS KEPT",0
        db $FF
CARD_CTRL:
        db 2,0,"CONTROLS",0
        db 11,2,"O / P    LEFT / RIGHT",0
        db 18,2,"Q        JUMP",0
        db 25,2,"A        CROUCH",0
        db 32,2,"SPACE    THROW (HOLD=MAGIC)",0
        db 39,2,"W / RET  CHANGE WEAPON",0
        db 46,2,"M MAGIC  H PAUSE  S MUSIC",0
        db 55,0,"JOYSTICK: UP JUMPS, ARM SWAPS",0
        db $FF
CARD_CRED:
        db 4,0,"DREADMOOR",0
        db 12,2,"SIR TINPLATE'S LONG NIGHT",0
        db 24,2,"CODE, ART AND MUSIC",0
        db 31,0,"VIBED BY BPM",0
        db 43,2,"FOR THE DICK SMITH VZ300",0
        db 50,2,"BENNVENN SD + 128K",0
        db 58,0,"@ 2026",0
        db $FF

; bestiary: frame0, frame1, name, description
BEAST:
        dw S_ZOMBIE_0,S_ZOMBIE_1
        db "GRAVE ZOMBIE",0,"RISES WHEN YOU STEP NEAR",0
        dw S_SKEL_0,S_SKEL_1
        db "RATTLEBONES",0,"FIGHTS ON WITHOUT HIS HEAD",0
        dw S_BAT_0,S_BAT_1
        db "CRYPT BAT",0,"SWOOPS FROM THE DARK",0
        dw S_GHOST_0,S_GHOST_1
        db "MOURNING GHOST",0,"DRIFTS THROUGH WALLS",0
        dw S_CROW_0,S_CROW_1
        db "GALLOWS CROW",0,"WATCHES. WAITS. DIVES.",0
        dw S_PLANT_0,S_PLANT_1
        db "GRAVE BLOOM",0,"SPITS FIRE AT PASSERS-BY",0
        dw S_IMP_0,S_IMP_1
        db "GRISTLE THE IMP",0,"GUARDIAN OF THE HILL",0
        dw 0

HISCORE_INIT:
        db $00,$20,$00,"BPM"
        db $00,$15,$00,"VZ3"
        db $00,$10,$00,"DSE"
        db $00,$05,$00,"SIR"
        db $00,$02,$50,"TIN"
HISCORE_INIT_END:
