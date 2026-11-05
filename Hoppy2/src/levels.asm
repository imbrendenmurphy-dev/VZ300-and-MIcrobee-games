;=====================================================================
; Levels.  Lane: kind, bg, spec(1=racer bursts), speed (8.8 px/tick, +right)
; objects: type, x4 (byte column 0..31) ... $FF
; level: css, ticks-per-timebar-unit, flags, name, intro, lanes..., 0
;=====================================================================
	MACRO LANE kind,bg,spec,spd
	db kind,bg,spec
	dw spd
	ENDM

NLEVELS	equ 8
level_tab: dw lv1,lv2,lv3,lv4,lv5,lv6,lv7,lv8

; ---- shared static lanes
ln_home:	LANE K_HOME,0,0,0
		db $ff
ln_median:	LANE K_STATIC,BG_MEDIAN,0,0
		db $ff
ln_start:	LANE K_STATIC,BG_START,0,0
		db $ff
ln_grass:	LANE K_STATIC,BG_GRASS,0,0
		db $ff

;---------------------------------------------------------------- L1
lv1:	db 0,19,LF_FLY
	dw nm1,in1
	dw ln_home,l1w1,l1w2,l1w3,l1w4,l1w5,ln_median,l1r1,l1r2,l1r3,l1r4,l1r5,ln_start,0
l1w1:	LANE K_WATER,BG_WATER,0,$0050
	db OT_LOG3,0, OT_LOG3,11, OT_LOG3,22, $ff
l1w2:	LANE K_WATER,BG_WATER2,0,-$0060
	db OT_T3,0, OT_T3,11, OT_T3,21, $ff
l1w3:	LANE K_WATER,BG_WATER,0,$0080
	db OT_LOG6,0, OT_LOG6,17, $ff
l1w4:	LANE K_WATER,BG_WATER2,0,-$0050
	db OT_T2,2, OT_T2,10, OT_T2,18, OT_T2,26, $ff
l1w5:	LANE K_WATER,BG_WATER,0,$0040
	db OT_LOG4,0, OT_LOG4,12, OT_LOG4,23, $ff
l1r1:	LANE K_ROAD,BG_ROADK,0,-$0048
	db OT_TRUCK,0, OT_TRUCK,16, $ff
l1r2:	LANE K_ROAD,BG_ROAD,0,$0060
	db OT_CAR,0, OT_CAR,11, OT_CAR,22, $ff
l1r3:	LANE K_ROAD,BG_ROAD,0,-$0040
	db OT_TRACTOR,3, OT_TRACTOR,19, $ff
l1r4:	LANE K_ROAD,BG_ROAD,0,$00a0
	db OT_RACER,5, $ff
l1r5:	LANE K_ROAD,BG_ROAD,0,-$0050
	db OT_BEETLE,0, OT_BEETLE,10, OT_BEETLE,20, $ff

;---------------------------------------------------------------- L2
lv2:	db 0,18,LF_FLY|LF_PICK
	dw nm2,in2
	dw ln_home,l2w1,l2w2,l2w3,l2w4,l2w5,ln_median,l2r1,l2r2,l2r3,l2r4,l2r5,ln_start,0
l2w1:	LANE K_WATER,BG_WATER,0,$0060
	db OT_LOG4,0, OT_LOG4,14, OT_LOG2,26, $ff
l2w2:	LANE K_WATER,BG_WATER2,0,-$0070
	db OT_D3,0, OT_T3,11, OT_T3,21, $ff
l2w3:	LANE K_WATER,BG_WATER,0,$0090
	db OT_LOG6,0, OT_LOG3,18, $ff
l2w4:	LANE K_WATER,BG_WATER2,0,-$0060
	db OT_T2,2, OT_D2,10, OT_T2,18, OT_T2,26, $ff
l2w5:	LANE K_WATER,BG_WATER,0,$0050
	db OT_LOG4,0, OT_LOG3,12, OT_LOG4,22, $ff
l2r1:	LANE K_ROAD,BG_ROADK,0,-$0050
	db OT_BUS,0, OT_TRUCK,16, $ff
l2r2:	LANE K_ROAD,BG_ROAD,0,$0070
	db OT_TRACTOR,0, OT_CAR,11, OT_TRACTOR,22, $ff
l2r3:	LANE K_ROAD,BG_ROAD,0,-$0058
	db OT_DOZER,3, OT_CAR,14, OT_DOZER,24, $ff
l2r4:	LANE K_ROAD,BG_ROAD,0,$00b0
	db OT_RACER,5, OT_RACER,21, $ff
l2r5:	LANE K_ROAD,BG_ROAD,0,-$0060
	db OT_BEETLE,0, OT_BEETLE,8, OT_BEETLE,20, $ff

;---------------------------------------------------------------- L3
lv3:	db 0,17,LF_FLY|LF_PICK|LF_SNAKE|LF_SNAIL
	dw nm3,in3
	dw ln_home,l3w1,l3w2,l3w3,l3w4,l3w5,ln_median,l3r1,l3r2,l3r3,l3r4,l3r5,ln_start,0
l3w1:	LANE K_WATER,BG_WATER,0,$0070
	db OT_LOG3,0, OT_LOG3,12, OT_LOG3,23, $ff
l3w2:	LANE K_WATER,BG_WATER2,0,-$0080
	db OT_D3,0, OT_T3,11, OT_D3,21, $ff
l3w3:	LANE K_WATER,BG_WATER,0,$00a0
	db OT_LOG4,0, OT_LOG4,16, $ff
l3w4:	LANE K_WATER,BG_WATER2,0,-$0070
	db OT_D2,2, OT_T2,12, OT_D2,22, $ff
l3w5:	LANE K_WATER,BG_WATER,0,$0060
	db OT_LOG6,0, OT_LOG3,18, $ff
l3r1:	LANE K_ROAD,BG_ROADK,1,-$0060
	db OT_RACER,0, OT_RACER,16, $ff
l3r2:	LANE K_ROAD,BG_ROAD,0,$0070
	db OT_TRUCK,0, OT_CAR,12, OT_CAR,22, $ff
l3r3:	LANE K_ROAD,BG_ROAD,0,-$0068
	db OT_TRACTOR,2, OT_TRACTOR,12, OT_TRACTOR,22, $ff
l3r4:	LANE K_ROAD,BG_ROAD,1,$0080
	db OT_RACER,5, OT_BEETLE,20, $ff
l3r5:	LANE K_ROAD,BG_ROAD,0,-$0070
	db OT_BUS,0, OT_BEETLE,18, $ff

;---------------------------------------------------------------- L4
lv4:	db 0,17,LF_FLY|LF_PICK|LF_BAYCROC|LF_HOPPINA|LF_SNAIL
	dw nm4,in4
	dw ln_home,l4w1,l4w2,l4w3,l4w4,l4w5,ln_median,l4r1,l4r2,l4r3,l4r4,l4r5,ln_start,0
l4w1:	LANE K_WATER,BG_WATER,0,$0070
	db OT_CROC,0, OT_LOG3,12, OT_LOG4,22, $ff
l4w2:	LANE K_WATER,BG_WATER2,0,-$0080
	db OT_D3,0, OT_T3,11, OT_D2,22, $ff
l4w3:	LANE K_WATER,BG_WATER,0,$0090
	db OT_LOG4,0, OT_CROC,14, $ff
l4w4:	LANE K_WATER,BG_WATER2,0,-$0070
	db OT_D2,2, OT_T2,10, OT_D3,18, $ff
l4w5:	LANE K_WATER,BG_WATER,0,$0060
	db OT_LOG6,0, OT_CROC,18, $ff
l4r1:	LANE K_ROAD,BG_ROADK,0,-$0070
	db OT_TRUCK,0, OT_TRUCK,14, $ff
l4r2:	LANE K_ROAD,BG_ROAD,0,$0080
	db OT_CAR,0, OT_DOZER,10, OT_CAR,22, $ff
l4r3:	LANE K_ROAD,BG_ROAD,1,-$0060
	db OT_RACER,2, OT_TRACTOR,14, OT_RACER,24, $ff
l4r4:	LANE K_ROAD,BG_ROAD,0,$00c0
	db OT_BEETLE,5, OT_BEETLE,20, $ff
l4r5:	LANE K_ROAD,BG_ROAD,0,-$0070
	db OT_BUS,0, OT_CAR,18, $ff

;---------------------------------------------------------------- L5 candy (CSS1)
lv5:	db 1,16,LF_FLY|LF_PICK|LF_HOPPINA|LF_SNAKE|LF_SNAIL
	dw nm5,in5
	dw ln_home,l5w1,l5w2,l5w3,l5w4,l5w5,ln_median,l5r1,l5r2,l5r3,l5r4,l5r5,ln_start,0
l5w1:	LANE K_WATER,BG_WATER,0,-$0080
	db OT_LOG3,0, OT_LOG3,10, OT_LOG3,21, $ff
l5w2:	LANE K_WATER,BG_WATER2,0,$0080
	db OT_D3,0, OT_D3,11, OT_T3,21, $ff
l5w3:	LANE K_WATER,BG_WATER,0,-$00a0
	db OT_LOG6,0, OT_LOG2,16, OT_LOG2,24, $ff
l5w4:	LANE K_WATER,BG_WATER2,0,$0070
	db OT_LILY,0, OT_LILY,4, OT_LILY,10, OT_LILY,16, OT_LILY,20, OT_LILY,26, $ff
l5w5:	LANE K_WATER,BG_WATER,0,-$0060
	db OT_CROC,0, OT_LOG4,14, OT_LOG2,25, $ff
l5r1:	LANE K_ROAD,BG_ROADK,1,$0070
	db OT_RACER,0, OT_RACER,11, OT_RACER,22, $ff
l5r2:	LANE K_ROAD,BG_ROAD,0,-$0080
	db OT_BEETLE,0, OT_BEETLE,8, OT_BEETLE,16, OT_BEETLE,24, $ff
l5r3:	LANE K_ROAD,BG_ROAD,0,$0070
	db OT_BUS,0, OT_BUS,16, $ff
l5r4:	LANE K_ROAD,BG_ROAD,0,-$00d0
	db OT_CAR,5, $ff
l5r5:	LANE K_ROAD,BG_ROAD,0,$0060
	db OT_TRACTOR,0, OT_DOZER,11, OT_TRACTOR,22, $ff

;---------------------------------------------------------------- L6 double trouble (16 rows)
lv6:	db 0,24,LF_FLY|LF_PICK|LF_HOPPINA|LF_SNAIL
	dw nm6,in6
	dw ln_home,l6w1,l6w2,l6w3,ln_grass,l6r1,l6r2,l6r3,ln_median,l6w4,l6w5,l6w6,ln_grass,l6r4,l6r5,ln_start,0
l6w1:	LANE K_WATER,BG_WATER,0,$0070
	db OT_LOG4,0, OT_LOG3,13, OT_LOG3,23, $ff
l6w2:	LANE K_WATER,BG_WATER2,0,-$0080
	db OT_D3,0, OT_T3,10, OT_D2,20, $ff
l6w3:	LANE K_WATER,BG_WATER,0,$0060
	db OT_CROC,0, OT_LOG4,16, $ff
l6r1:	LANE K_ROAD,BG_ROADK,0,-$0090
	db OT_CAR,0, OT_CAR,11, OT_CAR,22, $ff
l6r2:	LANE K_ROAD,BG_ROAD,1,$0070
	db OT_RACER,4, OT_TRUCK,18, $ff
l6r3:	LANE K_ROAD,BG_ROAD,0,-$0060
	db OT_DOZER,0, OT_DOZER,16, $ff
l6w4:	LANE K_WATER,BG_WATER,0,-$0060
	db OT_LOG6,0, OT_LOG3,18, $ff
l6w5:	LANE K_WATER,BG_WATER2,0,$0070
	db OT_T2,0, OT_D2,8, OT_T2,16, OT_D2,24, $ff
l6w6:	LANE K_WATER,BG_WATER,0,-$0080
	db OT_LOG3,0, OT_LOG3,11, OT_LOG3,22, $ff
l6r4:	LANE K_ROAD,BG_ROADK,0,$0080
	db OT_TRACTOR,0, OT_BUS,12, $ff
l6r5:	LANE K_ROAD,BG_ROAD,0,-$00b0
	db OT_BEETLE,4, OT_BEETLE,20, $ff

;---------------------------------------------------------------- L7 rush hour
lv7:	db 0,15,LF_FLY|LF_PICK|LF_BAYCROC|LF_SNAKE|LF_SNAIL
	dw nm7,in7
	dw ln_home,l7w1,l7w2,l7w3,l7w4,l7w5,ln_median,l7r1,l7r2,l7r3,l7r4,l7r5,ln_start,0
l7w1:	LANE K_WATER,BG_WATER,0,$0090
	db OT_LOG3,0, OT_CROC,12, OT_LOG2,24, $ff
l7w2:	LANE K_WATER,BG_WATER2,0,-$0090
	db OT_D3,0, OT_D3,11, OT_D2,22, $ff
l7w3:	LANE K_WATER,BG_WATER,0,$00b0
	db OT_LOG4,0, OT_LOG4,16, $ff
l7w4:	LANE K_WATER,BG_WATER2,0,-$0080
	db OT_D2,2, OT_D2,12, OT_T2,22, $ff
l7w5:	LANE K_WATER,BG_WATER,0,$0070
	db OT_CROC,0, OT_LOG3,14, OT_LOG2,24, $ff
l7r1:	LANE K_ROAD,BG_ROADK,1,-$0080
	db OT_RACER,0, OT_CAR,10, OT_RACER,20, $ff
l7r2:	LANE K_ROAD,BG_ROAD,0,$0090
	db OT_TRUCK,0, OT_TRUCK,16, $ff
l7r3:	LANE K_ROAD,BG_ROAD,1,-$0070
	db OT_RACER,2, OT_RACER,13, OT_DOZER,23, $ff
l7r4:	LANE K_ROAD,BG_ROAD,0,$00e0
	db OT_CAR,0, OT_CAR,16, $ff
l7r5:	LANE K_ROAD,BG_ROAD,0,-$0080
	db OT_BUS,0, OT_BUS,16, $ff

;---------------------------------------------------------------- L8 finale (16 rows)
lv8:	db 0,22,LF_FLY|LF_PICK|LF_BAYCROC|LF_HOPPINA|LF_SNAKE|LF_SNAIL
	dw nm8,in8
	dw ln_home,l8w1,l8w2,l8w3,l8w4,ln_median,l8r1,l8r2,l8r3,ln_grass,l8w5,l8w6,ln_median,l8r4,l8r5,ln_start,0
l8w1:	LANE K_WATER,BG_WATER,0,$00a0
	db OT_LOG3,0, OT_CROC,12, OT_LOG3,24, $ff
l8w2:	LANE K_WATER,BG_WATER2,0,-$00a0
	db OT_D3,0, OT_D2,10, OT_D3,20, $ff
l8w3:	LANE K_WATER,BG_WATER,0,$0080
	db OT_CROC,0, OT_LOG4,14, $ff
l8w4:	LANE K_WATER,BG_WATER2,0,-$0090
	db OT_LILY,0, OT_LILY,6, OT_D2,12, OT_LILY,20, OT_LILY,26, $ff
l8r1:	LANE K_ROAD,BG_ROADK,1,$0090
	db OT_RACER,0, OT_RACER,11, OT_RACER,22, $ff
l8r2:	LANE K_ROAD,BG_ROAD,0,-$00a0
	db OT_BUS,0, OT_TRUCK,16, $ff
l8r3:	LANE K_ROAD,BG_ROAD,1,$0080
	db OT_DOZER,0, OT_RACER,12, OT_DOZER,22, $ff
l8w5:	LANE K_WATER,BG_WATER,0,-$0080
	db OT_LOG4,0, OT_LOG2,12, OT_LOG4,20, $ff
l8w6:	LANE K_WATER,BG_WATER2,0,$0090
	db OT_D3,0, OT_T3,11, OT_D3,22, $ff
l8r4:	LANE K_ROAD,BG_ROADK,0,-$00c0
	db OT_CAR,0, OT_CAR,10, OT_CAR,20, $ff
l8r5:	LANE K_ROAD,BG_ROAD,1,$0090
	db OT_TRACTOR,0, OT_RACER,11, OT_TRACTOR,22, $ff

nm1:	db "  SUNNY MEADOW",0
nm2:	db "   MARKET DAY",0
nm3:	db "   SNAKE PASS",0
nm4:	db "   CROC CREEK",0
nm5:	db "  CANDY CREEK",0
nm6:	db " DOUBLE TROUBLE",0
nm7:	db "   RUSH HOUR",0
nm8:	db " FREEWAY FINALE",0
in1:	db "HOP HOME TO ALL FIVE",1,"LILY BAYS. CATCH THE",1,"FLIES FOR BONUS!",0
in2:	db "NEW: DIVING TURTLES",1,"TURN RED BEFORE THEY",1,"DUNK. GRAB TREATS!",0
in3:	db "NEW: SNAKE ON THE",1,"VERGE + RACERS THAT",1,"REV UP. SNAIL = SLOW",0
in4:	db "NEW: CROCS! RIDE THE",1,"BACK, AVOID THE JAWS.",1,"RESCUE HOPPINA!",0
in5:	db "A SUGAR RUSH! THE",1,"RIVER IS CORDIAL AND",1,"THE ROAD IS ICING.",0
in6:	db "TWO ROADS, TWO RIVERS",1,"TWICE THE TROUBLE.",1,"MIND THE ISLANDS.",0
in7:	db "EVERYONE IS LATE FOR",1,"WORK. LOOK BEFORE",1,"YOU LEAP!",0
in8:	db "THE BIG ONE. GET THE",1,"FAMILY HOME AND THE",1,"POND IS SAVED!",0
