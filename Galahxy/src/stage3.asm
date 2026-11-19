; =====================================================================
;  stage3.asm - STAGE 3: TOY BOX TOWERS  (GLXS3.DAT) - main palette
;  Nobody put the toys away.
;  Mechanic: walls of toy blocks stand in the way. Blast a gap through
;  them or squeeze over the top - tin soldiers march through the gaps.
;  Secret: the green surprise block.
;  Midboss: JACK-IN-THE-BOX.  Boss: SERGEANT NUTCRACKER.
; =====================================================================
            org STAGE
            jp s3_init
            jp s3_ret
            jp s3_ret
            jp s3_ret
            jp s3_kill
            jp seg_next
            jp s3_ret
            dw GTILES, STILES, SMAP, s3_segs, s3_mid, s3_boss
            org STG_SPRTAB
            include "gen/stg_spr_tab.inc"
            assert $ <= STG_TYPES
T_PLANE     equ 1
T_SOLDIER   equ 2
T_BLOCK     equ 3
T_QBLOCK    equ 4
T_MARBLE    equ 5
T_ROBOT     equ 6
T_YOYO      equ 7
T_KITE      equ 8
T_NUT       equ 9
T_JACK      equ 10
T_NUTCRK    equ 11
T_SABRE     equ 12
T_PLANE2    equ 13
            org STG_TYPES
            db 0,0,0,0,0,0,0,0,0,0
            db BH_SINE,   SPR_PLANE,    1, 0,0,8,4, $10, TF_HARM|TF_ANIM, $17
            db BH_WALK,   SPR_SOLDIER,  2, 0,0,5,8, $20, TF_HARM|TF_ANIM|TF_GROUND, 0
            db BH_GROUND, SPR_BLOCK,    3, 0,0,8,6, $05, TF_HARM|TF_GROUND, 0
            db BH_GROUND, SPR_BLOCK+1,  4, 0,0,8,6, $00, TF_HARM|TF_GROUND|TF_HOOK, 0
            db BH_BOUNCE, SPR_MARBLE,   1, 0,0,5,5, $15, TF_HARM|TF_ANIM, 0
            db BH_TURRET, SPR_ROBOT,    3, 0,0,6,8, $30, TF_HARM|TF_ANIM|TF_GROUND, 70
            db BH_DART,   SPR_YOYO,     1, 0,0,5,5, $15, TF_HARM|TF_ANIM, 30
            db BH_LINE,   SPR_KITE,     1, 0,0,5,5, $30, TF_HARM|TF_ANIM|TF_CARRY, 30
            db BH_ARC,    SPR_WALNUT,      1, 0,0,4,4, $05, TF_HARM, 0
            db BH_BOSS,   SPR_JACK,   255, 2,2,12,14,$00, TF_HARM, 0
            db BH_BOSS,   SPR_NUTCRACKER,255, 7,0,18,18,$00, TF_HARM, 0
            db BH_ARM,    SPR_SABRE,  255, 0,0,12,3, $00, TF_HARM|TF_ANIM, 0
            db BH_SINE,   SPR_PLANE,    1, 0,0,8,4, $15, TF_HARM|TF_ANIM, $29
            assert $ <= STG_CODE

            org STG_CODE
            db "TOY BOX TOWERS",0
            db "NOBODY PUT THE TOYS AWAY",0

CITY_COL    equ 400
CHEST_COL   equ 642
GY          equ YOFF
WX          equ 134+XOFF
s3_segs:    dw GMAP_INTRO, INTRO_C, $FFFF : db SG_NEXT
            dw GMAP_LOOP, LOOP_C, $FFFF : db SG_MID
            dw GMAP_CITY, CITY_C, CITY_COL : db SG_NEXT
            dw GMAP_CHEST, CHEST_C, CHEST_COL : db SG_NEXT
            dw GMAP_CHEST, CHEST_C, $FFFF : db SG_LOOP

s3_init:    ld a,L_MODE|L_SPK0
            ld hl,s3_tl
            ld de,tune_stage
            jp stg_setup
s3_ret:     ret

; the surprise block: a cupcake, coins and a secret bonus
s3_kill:
            ld a,(ix+O_T)
            cp T_QBLOCK
            ret nz
            ld b,(ix+O_X)
            ld c,(ix+O_Y)
            ld a,T_PIE
            call spawn_keep
            ld hl,bonus_sec
            ld a,(hl)
            add a,3
            ld (hl),a
            ld de,$0300
            call add_score
            ld a,SFX_SECRET
            call sfx
            ld b,(ix+O_X)
            ld c,(ix+O_Y)
            ld a,4
            call coin_burst
            ld hl,m_surprise
            ld a,80
            jp stg_msg
m_surprise: db 5,"SURPRISE BLOCK! +3000",0

; JACK-IN-THE-BOX: the box rattles (tell), then out he pops, firing
s3_mid:     db T_JACK, 80, 140+XOFF, 30+YOFF, 100+XOFF, 30+YOFF, 2
            db 2, 4, 12+YOFF, 30+YOFF, 0
            dw 0, m_jack, m_jackdn, tune_mid
            db $05, 6, 40, 0
            dw .p1, .p2, .p2
.p1:        db 0, 84
            db 20, A_TELL, 20
            db 20, A_SFX, SFX_CREAK
            db 42, A_FRAME, 1
            db 42, A_SFX, SFX_HONK
            db 44, A_FAN, 3, 8
            db 56, A_LOB, T_MARBLE, -18, -22
            db 70, A_FRAME, 0
            db $FF
.p2:        db 0, 64
            db 10, A_TELL, 16
            db 10, A_SFX, SFX_CREAK
            db 28, A_FRAME, 1
            db 28, A_SFX, SFX_HONK
            db 30, A_FAN, 3, 6
            db 38, A_LOB, T_MARBLE, -16, -24
            db 40, A_LOB, T_MARBLE, -30, -18
            db 46, A_FAN, 1, 0
            db 54, A_FRAME, 0
            db $FF
m_jack:     db 5,"POP! GOES THE WEASEL",0
m_jackdn:   db 4,"BACK IN YOUR BOX! +5000",0

; SERGEANT NUTCRACKER: jaws, a sabre, and falling blocks
s3_boss:    db T_NUTCRK, 180, 140+XOFF, 22+YOFF, 92+XOFF, 22+YOFF, 0
            db 9, 10, 6+YOFF, 28+YOFF, 0
            dw m_shun, m_nutcrk, m_nutcrkdn, tune_boss
            db $10, 8, 120, 60
            dw .p1, .p2, .p3
.p1:        db BM_BOB1, 88                  ; the jaw drops (tell): three nuts
            db 16, A_FAN, 1, 0
            db 36, A_FRAME, 1
            db 36, A_SFX, SFX_CREAK
            db 58, A_LOB, T_NUT, -14, -26
            db 59, A_LOB, T_NUT, -24, -24
            db 60, A_LOB, T_NUT, -34, -20
            db 60, A_SFX, SFX_BOMB
            db 62, A_FRAME, 0
            db $FF
.p2:        db 0, 104                       ; angry brows: lines up, then the sabre
            db 1, A_FRAME, 2
            db 1, A_SFX, SFX_WARN
            db 1, A_TRACK, 34
            db 18, A_TELL, 20
            db 40, A_ARM, T_SABRE
            db 40, A_SFX, SFX_WHIRR
            db 72, A_FRAME, 1
            db 78, A_LOB, T_NUT, -20, -26
            db 80, A_LOB, T_NUT, -32, -22
            db 86, A_FRAME, 2
            db $FF
.p3:        db BM_BOB2|BM_FAST, 64          ; "FIX BAYONETS": blocks rain, jaws clack
            db 1, A_FRAME, 1
            db 4, A_RAIN, T_NUT
            db 18, A_RAIN, T_NUT
            db 32, A_FRAME, 2
            db 34, A_RAIN, T_NUT
            db 50, A_RAIN, T_NUT
            db 22, A_TELL, 12
            db 36, A_FAN, 3, 8
            db 56, A_FAN, 1, 0
            db $FF
m_shun:     db 3,"ATTEN-SHUN! WHO GOES THERE?",0
m_nutcrk:   db 1,"WARNING! SERGEANT NUTCRACKER",0
m_nutcrkdn: db 6,"CRACKED IT! +10000",0

s3_tl:      dw 2   : db TL_MSG : dw m_intro : db 100
            dw 10  : db TL_FORM, T_PLANE, 5, 16, 12, 1
            dw 28  : db TL_FORM, T_YOYO, 3, 26, 18, 2
            dw 44  : db TL_SPAWN, T_KITE, 132+XOFF, 22+YOFF
            ; the first wall: three high
            dw 52  : db TL_SPAWN, T_BLOCK, WX, 44+GY
            dw 52  : db TL_SPAWN, T_BLOCK, WX, 38+GY
            dw 52  : db TL_SPAWN, T_BLOCK, WX, 32+GY
            dw 60  : db TL_FORM, T_SOLDIER, 3, 42, 30, 3
            dw 84  : db TL_FORM, T_PLANE2, 5, 30, 12, 4
            dw 100 : db TL_SPAWN, T_ROBOT, 132+XOFF, 42+GY
            dw 106 : db TL_FORM, T_MARBLE, 4, 46, 14, 5
            ; a tall wall: five high
            dw 124 : db TL_SPAWN, T_BLOCK, WX, 44+GY
            dw 124 : db TL_SPAWN, T_BLOCK, WX, 38+GY
            dw 124 : db TL_SPAWN, T_BLOCK, WX, 32+GY
            dw 124 : db TL_SPAWN, T_BLOCK, WX, 26+GY
            dw 124 : db TL_SPAWN, T_BLOCK, WX, 20+GY
            dw 130 : db TL_SPAWN, T_KITE, 132+XOFF, 12+YOFF
            dw 136 : db TL_FORM, T_YOYO, 4, 14, 16, 6
            dw 154 : db TL_FORM, T_SOLDIER, 4, 42, 24, 7
            dw 180 : db TL_FORM, T_PLANE, 6, 22, 10, 8
            dw 198 : db TL_SPAWN, T_ROBOT, 132+XOFF, 42+GY
            ; a double wall
            dw 206 : db TL_SPAWN, T_BLOCK, WX, 44+GY
            dw 206 : db TL_SPAWN, T_BLOCK, WX, 38+GY
            dw 206 : db TL_SPAWN, T_BLOCK, WX, 32+GY
            dw 206 : db TL_SPAWN, T_BLOCK, WX, 26+GY
            dw 208 : db TL_SPAWN, T_BLOCK, WX, 44+GY
            dw 208 : db TL_SPAWN, T_BLOCK, WX, 38+GY
            dw 208 : db TL_SPAWN, T_BLOCK, WX, 32+GY
            dw 214 : db TL_SPAWN, T_KITE, 132+XOFF, 16+YOFF
            dw 220 : db TL_FORM, T_MARBLE, 5, 46, 12, 1
            dw 240 : db TL_FORM, T_PLANE2, 5, 14, 12, 2
            dw 256 : db TL_MSG : dw m_wind : db 80
            dw 266 : db TL_CALL : dw mid_start
            dw 266 : db TL_HOLD
            ; ---- BLOCK CITY
            dw CITY_COL    : db TL_MSG : dw m_city : db 100
            dw CITY_COL+4  : db TL_SPAWN, T_SHOP, 132+XOFF, 16+YOFF
            dw CITY_COL+14 : db TL_SPAWN, T_BLOCK, WX, 44+GY
            dw CITY_COL+14 : db TL_SPAWN, T_BLOCK, WX, 38+GY
            dw CITY_COL+14 : db TL_SPAWN, T_BLOCK, WX, 32+GY
            dw CITY_COL+14 : db TL_SPAWN, T_BLOCK, WX, 26+GY
            dw CITY_COL+18 : db TL_FORM, T_PLANE, 5, 12, 12, 3
            dw CITY_COL+36 : db TL_SPAWN, T_BLOCK, WX, 44+GY
            dw CITY_COL+36 : db TL_SPAWN, T_BLOCK, WX, 38+GY
            dw CITY_COL+36 : db TL_SPAWN, T_QBLOCK, WX, 32+GY
            dw CITY_COL+40 : db TL_FORM, T_SOLDIER, 4, 42, 22, 4
            dw CITY_COL+64 : db TL_SPAWN, T_ROBOT, 132+XOFF, 42+GY
            dw CITY_COL+68 : db TL_SPAWN, T_KITE, 132+XOFF, 24+YOFF
            dw CITY_COL+74 : db TL_FORM, T_YOYO, 5, 20, 14, 5
            dw CITY_COL+94 : db TL_SPAWN, T_BLOCK, WX, 44+GY
            dw CITY_COL+94 : db TL_SPAWN, T_BLOCK, WX, 38+GY
            dw CITY_COL+94 : db TL_SPAWN, T_BLOCK, WX, 32+GY
            dw CITY_COL+94 : db TL_SPAWN, T_BLOCK, WX, 26+GY
            dw CITY_COL+94 : db TL_SPAWN, T_BLOCK, WX, 20+GY
            dw CITY_COL+94 : db TL_SPAWN, T_BLOCK, WX, 14+GY
            dw CITY_COL+100 : db TL_FORM, T_MARBLE, 5, 46, 12, 6
            dw CITY_COL+120 : db TL_FORM, T_PLANE2, 6, 28, 10, 7
            dw CITY_COL+138 : db TL_SPAWN, T_ROBOT, 132+XOFF, 42+GY
            dw CITY_COL+142 : db TL_SPAWN, T_ROBOT, 144+XOFF, 42+GY
            dw CITY_COL+150 : db TL_FORM, T_COIN, 8, 14, 5, 0
            dw CITY_COL+164 : db TL_SPAWN, T_BLOCK, WX, 44+GY
            dw CITY_COL+164 : db TL_SPAWN, T_BLOCK, WX, 38+GY
            dw CITY_COL+164 : db TL_SPAWN, T_BLOCK, WX, 32+GY
            dw CITY_COL+166 : db TL_SPAWN, T_BLOCK, WX, 44+GY
            dw CITY_COL+166 : db TL_SPAWN, T_BLOCK, WX, 38+GY
            dw CITY_COL+170 : db TL_SPAWN, T_KITE, 132+XOFF, 14+YOFF
            dw CITY_COL+176 : db TL_FORM, T_SOLDIER, 5, 42, 20, 8
            dw CITY_COL+204 : db TL_FORM, T_YOYO, 5, 26, 14, 1
            dw CITY_COL+220 : db TL_FORM, T_PLANE, 6, 18, 10, 2
            dw CHEST_COL    : db TL_MSG : dw m_chest : db 100
            dw CHEST_COL+2  : db TL_SPAWN, T_SHOP, 132+XOFF, 18+YOFF
            dw CHEST_COL+40 : db TL_CALL : dw boss_start
            dw CHEST_COL+40 : db TL_HOLD
            dw $7FFF : db TL_END
m_intro:    db 3,"WHAT A MESS! MIND THE BLOCKS",0
m_wind:     db 3,"SOMETHING IS WINDING UP...",0
m_city:     db 10,"BLOCK CITY",0
m_chest:    db 3,"WHO LEFT THE TOY CHEST OPEN?",0

            include "gen/stg_tunes.inc"
            include "gen/stg_scen.inc"
            include "gen/stg_spr_rec.inc"
stg_end:
            assert stg_end <= STAGE_END
