; =====================================================================
;  stage6.asm - STAGE 6: THE GALAH GALAXY  (GLXS6.DAT) - pastel palette
;  Where every galah comes from. One small flap for a galah...
;  Mechanic: meteor showers. They fall on a slant from the top of the
;  screen: shoot them (two hits) or slip between them.
;  Secret: the golden saucer that streaks past over the cheese moon.
;  Midboss: THE SPACE CHOOK.  Boss: THE COSMIC COCKATOO.
; =====================================================================
            org STAGE
            jp s6_init
            jp s6_ret
            jp s6_obj
            jp s6_hit
            jp s6_kill
            jp seg_next
            jp s6_ret
            dw GTILES, STILES, SMAP, s6_segs, s6_mid, s6_boss
            org STG_SPRTAB
            include "gen/stg_spr_tab.inc"
            assert $ <= STG_TYPES
T_UFO       equ 1
T_COMET     equ 2
T_ALIEN     equ 3
T_ROVER     equ 4
T_DISH      equ 5
T_ROCKET    equ 6
T_METEOR    equ 7
T_GOLDUFO   equ 8
T_EGG       equ 9
T_CHOOK     equ 10
T_COCKY     equ 11
T_BEAK      equ 12
T_CLAW      equ 13
T_UFO2      equ 14
            org STG_TYPES
            db 0,0,0,0,0,0,0,0,0,0
            db BH_SINE,   SPR_UFO,      1, 0,0,8,5, $10, TF_HARM|TF_ANIM, $17
            db BH_DART,   SPR_COMET,    1, 0,0,8,4, $20, TF_HARM|TF_ANIM, 38
            db BH_SWOOP,  SPR_ALIEN,    2, 0,0,7,5, $25, TF_HARM|TF_ANIM, 1
            db BH_WALK,   SPR_ROVER,    2, 0,0,8,5, $20, TF_HARM|TF_ANIM|TF_GROUND, 0
            db BH_TURRET, SPR_DISH,     3, 0,0,6,5, $30, TF_HARM|TF_ANIM|TF_GROUND, 58
            db BH_LINE,   SPR_ROCKET,   1, 0,0,8,4, $30, TF_HARM|TF_ANIM|TF_CARRY, 30
            db BH_STAGE,  SPR_METEOR,   2, 0,0,5,5, $15, TF_HARM|TF_ANIM, 0
            db BH_LINE,   SPR_GOLDUFO,  4, 0,0,8,5, $00, TF_HOOK, 56
            db BH_ARC,    SPR_EGG,      1, 0,0,4,4, $05, TF_HARM, 0
            db BH_BOSS,   SPR_CHOOK,  255, 3,3,18,10,$00, TF_HARM, 0
            db BH_BOSS,   SPR_COCKY,  255, 5,5,26,14,$00, TF_HARM, 0
            db BH_ARM,    SPR_BEAK,   255, 0,0,12,4, $00, TF_HARM|TF_ANIM, 0
            db BH_ARM,    SPR_CLAW,   255, 0,0,7,18, $00, TF_HARM, 1
            db BH_SINE,   SPR_UFO,      1, 0,0,8,5, $15, TF_HARM|TF_ANIM, $2A
            assert $ <= STG_CODE

            org STG_CODE
            db "THE GALAH GALAXY",0
            db "WHERE EVERY GALAH COMES FROM",0

CHEESE_COL  equ 400
NEST_COL    equ 642
GY          equ YOFF
s6_segs:    dw GMAP_INTRO, INTRO_C, $FFFF : db SG_NEXT
            dw GMAP_LOOP, LOOP_C, $FFFF : db SG_MID
            dw GMAP_CHEESE, CHEESE_C, CHEESE_COL : db SG_NEXT
            dw GMAP_NEST, NEST_C, NEST_COL : db SG_NEXT
            dw GMAP_NEST, NEST_C, $FFFF : db SG_LOOP

s6_init:    ld a,L_MODE|L_CSS|L_SPK0   ; the pastel palette (CSS1)
            ld hl,s6_tl
            ld de,tune_stage
            call stg_setup
            ld a,SPR_STARS          ; no clouds in space: twinkling stars
            ld (cloud_spr),a
s6_ret:     ret

; a meteor: falls on a slant, gone when it reaches the ground
s6_obj:
            ld a,(ix+O_ST)
            or a
            jr nz,.mv
            inc (ix+O_ST)
            ld (ix+O_VX),$20
            ld (ix+O_VX+1),$FF
            ld (ix+O_VY),$90
            ld (ix+O_VY+1),0
.mv:        call obj_move
            ld a,(ix+O_Y)
            cp 42+YOFF
            ret c
            ld (ix+O_T),T_BOOM      ; thump: a puff of moon dust
            ld (ix+O_SPR),SPR_BOOM
            ld (ix+O_TM),0
            ld (ix+O_ST),0
            ret
; meteors take two hits
s6_hit:     ld a,(ix+O_HP)
            sub c
            jp c,kill_obj
            jp z,kill_obj
            ld (ix+O_HP),a
            ld a,SFX_KNOCK
            jp sfx

; the golden saucer
s6_kill:
            ld a,(ix+O_T)
            cp T_GOLDUFO
            ret nz
            ld hl,bonus_sec
            ld a,(hl)
            add a,5
            ld (hl),a
            ld de,$0500
            call add_score
            ld a,SFX_SECRET
            call sfx
            ld b,(ix+O_X)
            ld c,(ix+O_Y)
            ld a,8
            call coin_burst
            ld hl,m_gold
            ld a,80
            jp stg_msg
m_gold:     db 4,"THE GOLDEN SAUCER! +5000",0

; THE SPACE CHOOK: a hen in a saucer. She lays eggs. At you.
s6_mid:     db T_CHOOK, 110, 140+XOFF, 18+YOFF, 98+XOFF, 18+YOFF, 2
            db 0, 8, 8+YOFF, 32+YOFF, 31
            dw 0, m_chook, m_chookdn, tune_mid
            db $05, 6, 55, 0
            dw .p1, .p2, .p2
.p1:        db BM_BOB2, 80
            db 8, A_SFX, SFX_HONK
            db 10, A_LOB, T_EGG, -16, -20
            db 30, A_LOB, T_EGG, -28, -14
            db 50, A_FAN, 1, 0
            db 62, A_LOB, T_EGG, -22, -24
            db $FF
.p2:        db BM_BOB3, 64
            db 4, A_SFX, SFX_HONK
            db 6, A_LOB, T_EGG, -14, -22
            db 8, A_LOB, T_EGG, -26, -18
            db 10, A_LOB, T_EGG, -38, -12
            db 28, A_TELL, 12
            db 42, A_FAN, 3, 7
            db 52, A_SPAWN, T_UFO2, 6
            db $FF
m_chook:    db 3,"BUK BUK BUK... IT'S A SPACE CHOOK",0
m_chookdn:  db 5,"CHOOK SCRAMBLED! +5000",0

; THE COSMIC COCKATOO: crest up = feathers; then the beak; then the claw
s6_boss:    db T_COCKY, 230, 140+XOFF, 14+YOFF, 90+XOFF, 14+YOFF, 2
            db 0, 11, 6+YOFF, 22+YOFF, 0
            dw m_pretty, m_cocky, m_cockydn, tune_boss
            db $20, 12, 150, 75
            dw .p1, .p2, .p3
.p1:        db BM_BOB1, 96                  ; the crest goes up (tell): a fan of feathers, then eggs
            db 10, A_FRAME, 1
            db 10, A_SFX, SFX_HONK
            db 26, A_FAN, 3, 8
            db 34, A_FRAME, 0
            db 50, A_LOB, T_EGG, -18, -22
            db 54, A_LOB, T_EGG, -32, -16
            db 76, A_FAN, 1, 0
            db $FF
.p2:        db BM_BOB2, 110                 ; cross: he lines up on you, flashes, and pecks
            db 1, A_FRAME, 2
            db 2, A_TRACK, 30
            db 34, A_TELL, 12
            db 34, A_SFX, SFX_CREAK
            db 48, A_ARM, T_BEAK
            db 70, A_FRAME, 1
            db 80, A_FAN, 3, 7
            db 88, A_FRAME, 2
            db 96, A_SPAWN, T_UFO2, 12
            db $FF
.p3:        db BM_BOB2|BM_FAST, 84          ; livid: the claw from above, eggs from everywhere
            db 1, A_FRAME, 2
            db 4, A_TELL, 10
            db 14, A_ARM, T_CLAW
            db 26, A_RAIN, T_EGG
            db 36, A_FRAME, 1
            db 44, A_FAN, 3, 8
            db 50, A_FRAME, 2
            db 58, A_RAIN, T_EGG
            db 66, A_LOB, T_EGG, -26, -22
            db 74, A_RAIN, T_EGG
            db $FF
m_pretty:   db 1,"SQUAAAWK! WHO'S A PRETTY BOY THEN?",0
m_cocky:    db 3,"WARNING! THE COSMIC COCKATOO",0
m_cockydn:  db 3,"COCKY'S CRACKED IT! +20000",0

s6_tl:      dw 2   : db TL_MSG : dw m_intro : db 100
            dw 10  : db TL_FORM, T_UFO, 5, 16, 12, 1
            dw 28  : db TL_FORM, T_COMET, 3, 28, 18, 2
            dw 44  : db TL_SPAWN, T_ROCKET, 132+XOFF, 20+YOFF
            dw 50  : db TL_FORM, T_ROVER, 3, 38, 24, 3
            dw 66  : db TL_MSG : dw m_shower : db 80
            dw 74  : db TL_SPAWN, T_METEOR, 120+XOFF, 6+YOFF
            dw 78  : db TL_SPAWN, T_METEOR, 96+XOFF, 6+YOFF
            dw 82  : db TL_SPAWN, T_METEOR, 126+XOFF, 6+YOFF
            dw 86  : db TL_SPAWN, T_METEOR, 80+XOFF, 6+YOFF
            dw 90  : db TL_SPAWN, T_DISH, 132+XOFF, 38+GY
            dw 96  : db TL_FORM, T_UFO2, 5, 30, 12, 4
            dw 112 : db TL_FORM, T_ALIEN, 3, 12, 22, 5
            dw 130 : db TL_SPAWN, T_ROCKET, 132+XOFF, 34+YOFF
            dw 136 : db TL_FORM, T_COMET, 4, 14, 16, 6
            dw 152 : db TL_SPAWN, T_METEOR, 110+XOFF, 6+YOFF
            dw 155 : db TL_SPAWN, T_METEOR, 126+XOFF, 6+YOFF
            dw 158 : db TL_SPAWN, T_METEOR, 90+XOFF, 6+YOFF
            dw 161 : db TL_SPAWN, T_METEOR, 118+XOFF, 6+YOFF
            dw 164 : db TL_SPAWN, T_METEOR, 70+XOFF, 6+YOFF
            dw 170 : db TL_FORM, T_ROVER, 4, 38, 20, 7
            dw 186 : db TL_SPAWN, T_DISH, 132+XOFF, 38+GY
            dw 190 : db TL_FORM, T_UFO, 6, 22, 10, 8
            dw 208 : db TL_SPAWN, T_ROCKET, 132+XOFF, 14+YOFF
            dw 214 : db TL_FORM, T_ALIEN, 4, 14, 18, 1
            dw 232 : db TL_FORM, T_COMET, 4, 30, 14, 2
            dw 246 : db TL_FORM, T_UFO2, 5, 12, 12, 3
            dw 256 : db TL_MSG : dw m_buk : db 80
            dw 266 : db TL_CALL : dw mid_start
            dw 266 : db TL_HOLD
            ; ---- THE CHEESE MOON
            dw CHEESE_COL    : db TL_MSG : dw m_cheese : db 100
            dw CHEESE_COL+4  : db TL_SPAWN, T_SHOP, 132+XOFF, 16+YOFF
            dw CHEESE_COL+16 : db TL_FORM, T_UFO, 6, 12, 10, 4
            dw CHEESE_COL+34 : db TL_SPAWN, T_METEOR, 124+XOFF, 6+YOFF
            dw CHEESE_COL+37 : db TL_SPAWN, T_METEOR, 100+XOFF, 6+YOFF
            dw CHEESE_COL+40 : db TL_SPAWN, T_METEOR, 76+XOFF, 6+YOFF
            dw CHEESE_COL+44 : db TL_FORM, T_ALIEN, 4, 16, 18, 5
            dw CHEESE_COL+60 : db TL_SPAWN, T_DISH, 132+XOFF, 38+GY
            dw CHEESE_COL+64 : db TL_SPAWN, T_ROCKET, 132+XOFF, 24+YOFF
            dw CHEESE_COL+70 : db TL_FORM, T_COMET, 5, 20, 14, 6
            dw CHEESE_COL+90 : db TL_SPAWN, T_GOLDUFO, 132+XOFF, 10+YOFF
            dw CHEESE_COL+96 : db TL_FORM, T_ROVER, 4, 38, 20, 7
            dw CHEESE_COL+114 : db TL_SPAWN, T_METEOR, 126+XOFF, 6+YOFF
            dw CHEESE_COL+116 : db TL_SPAWN, T_METEOR, 104+XOFF, 6+YOFF
            dw CHEESE_COL+118 : db TL_SPAWN, T_METEOR, 82+XOFF, 6+YOFF
            dw CHEESE_COL+120 : db TL_SPAWN, T_METEOR, 60+XOFF, 6+YOFF
            dw CHEESE_COL+126 : db TL_FORM, T_UFO2, 6, 28, 10, 8
            dw CHEESE_COL+144 : db TL_SPAWN, T_DISH, 132+XOFF, 38+GY
            dw CHEESE_COL+148 : db TL_SPAWN, T_DISH, 146+XOFF, 38+GY
            dw CHEESE_COL+154 : db TL_FORM, T_COIN, 8, 14, 5, 0
            dw CHEESE_COL+168 : db TL_SPAWN, T_ROCKET, 132+XOFF, 14+YOFF
            dw CHEESE_COL+174 : db TL_FORM, T_ALIEN, 5, 14, 16, 1
            dw CHEESE_COL+194 : db TL_FORM, T_COMET, 5, 26, 14, 2
            dw CHEESE_COL+208 : db TL_SPAWN, T_METEOR, 120+XOFF, 6+YOFF
            dw CHEESE_COL+211 : db TL_SPAWN, T_METEOR, 92+XOFF, 6+YOFF
            dw CHEESE_COL+216 : db TL_FORM, T_UFO, 6, 18, 10, 3
            dw NEST_COL    : db TL_MSG : dw m_nest : db 100
            dw NEST_COL+2  : db TL_SPAWN, T_SHOP, 132+XOFF, 18+YOFF
            dw NEST_COL+40 : db TL_CALL : dw boss_start
            dw NEST_COL+40 : db TL_HOLD
            dw $7FFF : db TL_END
m_intro:    db 3,"ONE SMALL FLAP FOR A GALAH",0
m_shower:   db 6,"METEOR SHOWER! LOOK UP",0
m_buk:      db 12,"BUK... BUK...",0
m_cheese:   db 2,"THE MOON IS CHEESE. KNEW IT.",0
m_nest:     db 4,"THE NEST AT THE END OF SPACE",0

            include "gen/stg_tunes.inc"
            include "gen/stg_scen.inc"
            include "gen/stg_spr_rec.inc"
stg_end:
            assert stg_end <= STAGE_END
