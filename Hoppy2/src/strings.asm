txt_200:	db "200",0
txt_love:	db "LOVE!",0
txt_shield:	db "SAFE",0
txt_snail:	db "SLOW",0
txt_x2:		db "X2!",0
txt_1up:	db "1UP!",0
txt_paused:	db " PAUSED - RETURN GO - X QUITS",0
txt_level:	db "LEVEL",0
txt_lap:	db "LAP 2 - FASTER!",0
txt_subtitle:	db "- THE BIG POND MOVE -",0
txt_snailwin:	db "SNAIL WINS!",0
txt_honk:	db "HONK!",0
txt_gulp:	db "GULP!",0
txt_eek:	db "EEK!",0
txt_arrow:	db ">",0
txt_caret:	db "^",0
txt_hiscores:	db "TOP FROGS",0
txt_newhi:	db "A NEW TOP FROG SCORE!",0
txt_entername:	db "^ _ CHANGE   FIRE/P = NEXT",0
txt_gameover:	db "GAME OVER",0
txt_continue:	db "CONTINUE?",0
txt_contkey:	db "FIRE = GO ON (SCORE RESETS)",0
txt_clear:	db "POND CLEAR!",0
txt_t_home:	db "ALL FIVE HOME",0
txt_t_flies:	db "FLIES GOBBLED",0
txt_t_flawless:	db "FLAWLESS - NO SPLATS",0
txt_t_tidy:	db "TIDY ROW BONUS",0
txt_t_score:	db "SCORE",0
txt_saved:	db "THE POND IS SAVED! HOORAY!",0
txt_demo:	db "DEMO - PRESS FIRE",0

story_txt:
	db "OH NO! THE MAYOR IS DRAINING",1,"HOPPY'S POND TO BUILD A CAR",1,"PARK!",3
	db "HOPPY'S FROGLETS HAVE LEAPT",1,"ALL OVER THE COUNTRYSIDE.",1,"SOMEONE MUST BRING THEM HOME",3
	db "...TO THE NEW POND, OVER THE",1,"ROADS AND THE RIVER. HOPPY:",1,"   'LEAVE IT TO ME, KIDS!'",0

scroll_msg:
	db 2,1,"   *** HOPPY 2 *** THE BIG POND MOVE ***   ",2,3,"PRESS SPACE OR FIRE TO PLAY   "
	db 2,1,"HOP WITH Q A O P (OR M ,) OR A JOYSTICK...  SPACE = SNAIL SLOW-MO...  RETURN = PAUSE...   "
	db 2,0,"FILL ALL FIVE LILY BAYS!  GOBBLE FLIES!  RESCUE HOPPINA!   "
	db 2,1,"A LOVING REMAKE OF HOPPY BY DUBOIS AND MCNAMARA...   REMAKE VIBED BY BPM 2026 FOR THE DICK SMITH VZ300...   "
	db 2,3,"NO SNAILS WERE HARMED IN THE MAKING OF THIS GAME...         ",0

page1:	dw .t,.b,.s
.t:	db "HOW TO HOP",0
.b:	db "Q/A UP+DOWN   O/P LEFT+RIGHT",1,"(ALSO M , KEYS OR JOYSTICK)",1
	db 2,$20,"SPACE/FIRE USE SNAIL SLOW-MO",1,"RETURN PAUSE  X QUIT (PAUSED)",1
	db 2,$23,"FILL ALL 5 BAYS BEFORE THE",1,"TIME BAR RUNS OUT. HEDGES",1,"JUST BOUNCE YOU BACK.",0
.s:	dw spr_fup
	db 4,56
	dw spr_fupj
	dw spr_frt
	db 116,56
	dw spr_frtj
	dw 0
page2:	dw .t,.b,.s
.t:	db "TROUBLEMAKERS",0
.b:	db "   CARS, TRUCKS AND TRACTORS",1,"   RACERS REV BEFORE A DASH",1
	db 2,$20,"   TURTLES GO RED, THEN DIVE",1,"   CROCS: RIDE BACK, NOT JAWS",1
	db 2,$23,"   THE VERGE SNAKE SLITHERS",1,"   CROCS LURK IN SOME BAYS",0
.s:	dw spr_dozer
	db 8,48
	dw spr_dozer2
	dw spr_snake
	db 48,50
	dw spr_snake2
	dw spr_bcpeek
	db 88,50
	dw spr_bcroc
	dw 0
page3:	dw .t,.b,.s
.t:	db "POND TREATS",0
.b:	db "   FLY IN A BAY     200",1,"   BUBBLE  SHIELD ONE SPLAT",1
	db "   SNAIL   SPACE = SLOW-MO",1,"   STAR    DOUBLE SCORES",1
	db "   HEART   EXTRA FROG",1,"   HOPPINA CARRY HOME  1000",0
.s:	dw spr_fly
	db 2,9
	dw spr_fly2
	dw spr_bubble
	db 2,15
	dw 0
	dw spr_snail
	db 2,21
	dw 0
	dw spr_star
	db 2,27
	dw 0
	dw spr_heart
	db 2,33
	dw 0
	dw spr_hoppina
	db 2,39
	dw 0
	dw 0

hi_default:
	db $00,$50,$00,"HOP"
	db $00,$40,$00,"DUB"
	db $00,$30,$00,"MAC"
	db $00,$25,$00,"BPM"
	db $00,$20,$00,"VZ "
	db $00,$15,$00,"FRG"
	db $00,$10,$00,"TAD"
	db $00,$05,$00,"EGG"
