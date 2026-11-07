; front-end text (lives in the front pack)
STR_PRESS:   db "PRESS FIRE",0
STR_COPY:    db "VIBED BY BPM 2026",0
STR_MENUTITLE: db "GRAVES 'N' GARGOYLES",0
STR_M_START: db "START GAME",0
STR_M_PASS:  db "PASSWORD",0
STR_M_DIFF:  db "LEVEL: ",0
STR_M_MUSIC: db "MUSIC: ",0
STR_M_CTRL:  db "CONTROLS",0
STR_M_HIGH:  db "HIGH SCORES",0
STR_M_CRED:  db "CREDITS",0
STR_BEAST:   db "- CREATURES OF THE NIGHT -",0
DIFFNAMES:   dw .d0,.d1,.d2
.d0:         db "CASUAL",0
.d1:         db "NORMAL",0
.d2:         db "EXPERT",0
ONOFF:       dw .on,.off
.on:         db "ON",0
.off:        db "OFF",0
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
        db 4,0,"WIN BETTER ARMOUR.",0
        db 11,0,"FIND MIGHTIER WEAPONS.",0
        db 18,0,"BRING BACK THE DAWN!",0
        db 27,2,"EACH SUIT TAKES FIVE KNOCKS",0
        db 34,1,"- WATCH THE RED BAR -",0
        db 42,2,"(AND KEEP YOUR TROUSERS ON)",0
        db $FF
CARD_CTRL:
        db 3,0,"CONTROLS",0
        db 10,2,"O / P    LEFT / RIGHT",0
        db 16,2,"Q        JUMP",0
        db 22,2,"A        CROUCH",0
        db 28,2,"SPACE    THROW (HOLD=MAGIC)",0
        db 34,2,"W / RET  CHANGE WEAPON",0
        db 40,2,"M MAGIC  H PAUSE  S MUSIC",0
        db 48,0,"JOYSTICK: UP JUMPS, ARM SWAPS",0
        db $FF
CARD_CRED:
        db 4,0,"GRAVES 'N' GARGOYLES",0
        db 12,2,"SIR TINPLATE'S LONG NIGHT",0
        db 22,2,"CODE, ART AND MUSIC",0
        db 29,0,"VIBED BY BPM 2026",0
        db 39,2,"FOR THE DICK SMITH VZ300",0
        db 46,2,"BENNVENN SD + 128K",0
        db $FF

; bestiary: frame0, frame1, name, description
BEAST:
        dw F_ZOMBIE_0,F_ZOMBIE_1
        db "GRAVE ZOMBIE",0,"RISES WHEN YOU STEP NEAR",0
        dw F_SKEL_0,F_SKEL_1
        db "RATTLEBONES",0,"FIGHTS ON WITHOUT HIS HEAD",0
        dw F_TBAT_0,F_TBAT_1
        db "CRYPT BAT",0,"SWOOPS FROM THE DARK",0
        dw F_GHOST_0,F_GHOST_1
        db "MOURNING GHOST",0,"DRIFTS THROUGH WALLS",0
        dw F_CROW_0,F_CROW_1
        db "GALLOWS CROW",0,"WATCHES. WAITS. DIVES.",0
        dw F_PLANT_0,F_PLANT_1
        db "GRAVE BLOOM",0,"SPITS FIRE AT PASSERS-BY",0
        dw F_IMP_0,F_IMP_1
        db "GRISTLE THE IMP",0,"GUARDIAN OF THE HILL",0
        dw 0

