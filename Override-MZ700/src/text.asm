; =====================================================================
;  text.asm - front-end strings (ASCII; 01h-07h inside = colour change)
; =====================================================================

txt_sub:        db "THE DROID TRANSFER GAME",0
txt_credit:     db "MZ-700 VERSION  2026  VIBED BY BPM",0
txt_press:      db "PRESS SPACE TO START",0
txt_joy_off:    db "J: JOYSTICK OFF (KEYBOARD)",0
txt_joy_on:     db "J: MZ-1X03 JOYSTICK ON",0
txt_joy_cal:    db "CENTRE THE STICK...",0
txt_joy_none:   db "J: NO JOYSTICK FOUND",0
txt_best:       db "HIGH SCORE ",0

scroll_text:
        db "                                        "
        db "A ROGUE SHIP MIND HAS SEIZED THE SERVICE DROIDS OF THREE STARSHIPS. "
        db "YOU ARE THE LINK PROBE - UNIT 000 - ARMED WITH NOTHING BUT THE POWER "
        db "TO TAKE OVER ANY DROID YOU TOUCH...    "
        db "CURSOR KEYS OR Q A O P MOVE.  SPACE FIRES IN THE DIRECTION YOU PUSH.  "
        db "HOLD SPACE STILL TO ENTER TRANSFER MODE, THEN RAM A DROID TO LINK WITH IT. "
        db "WIN THE CIRCUIT DUEL AND ITS BODY IS YOURS.    "
        db "HOSTS BURN OUT - KEEP JUMPING TO STRONGER ONES.  ENERGIZERS RECHARGE YOU, "
        db "LIFTS TAKE YOU BETWEEN DECKS, CONSOLES SHOW THE DECK PLAN.  "
        db "CLEAR EVERY DECK AND THE LIGHTS GO OUT - CLEAR EVERY SHIP TO WIN.    "
        db "CR PAUSES, BREAK QUITS.  PRESS J HERE FOR AN MZ-1X03 JOYSTICK: STICK MOVES, EITHER BUTTON FIRES.        ",0

txt_gallery:    db "- D R O I D   D A T A B A N K -",0
txt_energy:     db "ENERGY ",0

howto_text:
        db WHITE,"     HOW TO OVERRIDE THE FLEET",0
        db BLACK,0
        db YELLOW,"MOVE",0
        db CYAN,"  CURSOR KEYS OR Q A O P",0
        db YELLOW,"SHOOT",0
        db CYAN,"  SPACE + DIRECTION (ARMED HOSTS)",0
        db YELLOW,"TRANSFER",0
        db CYAN,"  HOLD SPACE STILL UNTIL YOU FLASH,",0
        db CYAN,"  THEN TOUCH A DROID. IN THE DUEL",0
        db CYAN,"  FIRE PULSES DOWN YOUR WIRES. OWN",0
        db CYAN,"  MOST OF THE CENTRE WHEN THE CLOCK",0
        db CYAN,"  STOPS AND THE DROID IS YOURS.",0
        db YELLOW,"LIFTS AND CONSOLES",0
        db CYAN,"  PRESS SPACE ON A LIFT PAD OR",0
        db CYAN,"  NEXT TO A CONSOLE.",0
        db YELLOW,"ENERGY",0
        db CYAN,"  HOSTS BURN OUT - RECHARGE ON AN",0
        db CYAN,"  ENERGIZER. LOSE YOUR HOST AND THE",0
        db CYAN,"  BARE PROBE IS LEFT. LOSE THAT AND",0
        db CYAN,"  THE GAME IS OVER.",0
        db BLACK,0
        db GREEN,"  THE FIRST DIGIT OF A DROID IS ITS",0
        db GREEN,"  CLASS. HIGHER CLASS, MORE POINTS.",0
        db 0FFh

txt_hiscores:   db "- T O P   L I N K E R S -",0
txt_hshead:     db "  NAME  SCORE      REACHED",0
txt_ship:       db "SHIP ",0
txt_entername:  db "NEW HIGH SCORE - ENTER YOUR NAME",0
txt_enterhelp:  db "UP/DOWN LETTER   SPACE NEXT",0
txt_welldone:   db "WELL DONE!",0

hiscore_default:
        db "BPM", 00h,00h,02h, 2,0
        db "MZ7", 00h,50h,01h, 1,0
        db "SHP", 00h,00h,01h, 1,0
        db "DRD", 00h,75h,00h, 0,0
        db "LNK", 00h,50h,00h, 0,0
        db "ZAP", 00h,30h,00h, 0,0
        db "ARC", 00h,20h,00h, 0,0
        db "OVR", 00h,10h,00h, 0,0

txt_gameover:   db "G A M E   O V E R",0
txt_finalscore: db "FINAL SCORE ",0
txt_shipclear:  db "SHIP CLEARED",0
txt_shipbonus:  db "ALL DECKS SECURE  BONUS 5000",0
txt_nextship:   db "TRANSFERRING TO THE NEXT SHIP...",0
txt_victory1:   db "THE FLEET IS FREE",0
txt_victory2:   db "THE SHIP MIND IS SILENT. EVERY DECK",0
txt_victory3:   db "IS DARK. THE LINK PROBE RESTS.",0

txt_boarding:   db "LINK PROBE BOARDING SHIP  OF 3",0
txt_brief1:     db "SEIZE OR DESTROY EVERY DROID",0
txt_brief2:     db "ON EVERY DECK OF THIS VESSEL",0
txt_lifthelp:   db "UP/DOWN CHOOSE DECK   SPACE GET OUT",0
txt_lift_clear: db "DECK CLEARED",0
txt_lift_droids: db "     DROIDS ACTIVE",0
txt_console:    db "- DECK CONSOLE -",0
txt_con_left:   db "HOSTILES ",0
