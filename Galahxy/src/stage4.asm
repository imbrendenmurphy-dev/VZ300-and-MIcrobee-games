; =====================================================================
;  stage4.asm - STAGE 4: SHERBET SEA  (GLXS4.DAT) - pastel palette
;  Dive in! The water's fizzy.
;  Mechanic: fizz geysers on the sea bed. Each one bubbles for a moment
;  (the tell), then blows a column of fizz up the screen: time your run.
;  Secret: the treasure chest on the wreck.
;  Midboss: THE ICE-CREAM SUB.  Boss: QUEEN JELLYFISH.
; =====================================================================
            org STAGE
            jp s4_init
            jp s4_ret
            jp s4_obj
            jp s4_hit
            jp s4_kill
            jp seg_next
            jp s4_ret
            dw GTILES, STILES, SMAP, s4_segs, s4_mid, s4_boss
            org STG_SPRTAB
            include "gen/stg_spr_tab.inc"
            assert $ <= STG_TYPES
T_FISH      equ 1
T_PUFFER    equ 2
T_JELLY     equ 3
T_CRAB      equ 4
T_CLAM      equ 5
T_SEAHORSE  equ 6
T_GEYSER    equ 7
T_FIZZ      equ 8
T_CHEST     equ 9
T_TORP      equ 10
T_SUB       equ 11
T_QUEEN     equ 12
T_TENTACLE  equ 13
T_FISH2     equ 14
            org STG_TYPES
            db 0,0,0,0,0,0,0,0,0,0
            db BH_SINE,   SPR_FISH,     1, 0,0,8,5, $10, TF_HARM|TF_ANIM, $16
            db BH_DART,   SPR_PUFFER,   2, 0,0,7,7, $20, TF_HARM|TF_ANIM, 36
            db BH_RISE,   SPR_JELLY,    2, 0,0,7,6, $20, TF_HARM|TF_ANIM, 4
            db BH_WALK,   SPR_CRAB,     2, 0,0,8,5, $20, TF_HARM|TF_ANIM|TF_GROUND, 0
            db BH_TURRET, SPR_CLAM,     3, 0,0,7,5, $30, TF_HARM|TF_ANIM|TF_GROUND, 64
            db BH_LINE,   SPR_SEAHORSE, 1, 0,0,5,8, $30, TF_HARM|TF_ANIM|TF_CARRY, 30
            db BH_STAGE,  SPR_GEYSER, 255, 0,2,7,2, $00, TF_GROUND, 0
            db BH_RISE,   SPR_FIZZ,   255, 0,0,5,5, $00, TF_HARM|TF_ANIM, 24
            db BH_GROUND, SPR_CHEST,    8, 0,0,9,6, $00, TF_GROUND|TF_HOOK, 0
            db BH_LINE,   SPR_TORP,     1, 0,0,8,3, $05, TF_HARM|TF_ANIM, 60
            db BH_BOSS,   SPR_SUB,    255, 1,3,21,9, $00, TF_HARM, 0
            db BH_BOSS,   SPR_QUEEN,  255, 4,3,26,10,$00, TF_HARM, 0
            db BH_ARM,    SPR_TENTACLE,255, 0,0,5,18,$00, TF_HARM|TF_ANIM, 1
            db BH_SINE,   SPR_FISH,     1, 0,0,8,5, $15, TF_HARM|TF_ANIM, $29
            assert $ <= STG_CODE

            org STG_CODE
            db "SHERBET SEA",0
            db "DIVE IN! THE WATER'S FIZZY",0

WRECK_COL   equ 400
COURT_COL   equ 642
GY          equ YOFF
s4_segs:    dw GMAP_INTRO, INTRO_C, $FFFF : db SG_NEXT
            dw GMAP_LOOP, LOOP_C, $FFFF : db SG_MID
            dw GMAP_WRECK, WRECK_C, WRECK_COL : db SG_NEXT
            dw GMAP_COURT, COURT_C, COURT_COL : db SG_NEXT
            dw GMAP_COURT, COURT_C, $FFFF : db SG_LOOP

s4_init:    ld a,L_MODE|L_CSS|L_SPK0   ; the pastel palette (CSS1)
            ld hl,s4_tl
            ld de,tune_stage
            call stg_setup
            ld a,SPR_SHOAL          ; no clouds down here: shoals of fish
            ld (cloud_spr),a
s4_ret:     ret

; the geyser: bubbles (tell), then four puffs of fizz straight up
s4_obj:
            inc (ix+O_TM)
            ld a,(ix+O_X)
            cp 128+XOFF
            ret nc
            ld a,(ix+O_TM)
            cp 96
            jr c,.t
            ld (ix+O_TM),0
            ld (ix+O_SPR),SPR_GEYSER
            ret
.t:         cp 50
            jr nz,.t2
            ld (ix+O_SPR),SPR_GEYSER+1
            ld a,SFX_HISS
            jp sfx
.t2:        cp 74
            ret c
            and 3
            ret nz
            ld b,(ix+O_X)
            inc b
            ld a,(ix+O_Y)
            sub 4
            ld c,a
            ld a,T_FIZZ
            jp spawn_keep
; geysers and fizz can't be shot
s4_hit:     jp arm_hit

; the treasure chest
s4_kill:
            ld a,(ix+O_T)
            cp T_CHEST
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
            ld hl,m_chest
            ld a,80
            jp stg_msg
m_chest:    db 4,"SUNKEN TREASURE! +5000",0

; THE ICE-CREAM SUB: torpedoes, then faster torpedoes
s4_mid:     db T_SUB, 80, 140+XOFF, 20+YOFF, 96+XOFF, 20+YOFF, 2
            db 0, 6, 8+YOFF, 34+YOFF, 31
            dw 0, m_sub, m_subdn, tune_mid
            db $05, 6, 40, 0
            dw .p1, .p2, .p2
.p1:        db BM_BOB2, 80
            db 10, A_SPAWN, T_TORP, 6
            db 10, A_SFX, SFX_WHIRR
            db 40, A_FAN, 1, 0
            db 50, A_SPAWN, T_TORP, 6
            db $FF
.p2:        db BM_BOB3, 64
            db 6, A_SPAWN, T_TORP, 6
            db 6, A_SFX, SFX_WHIRR
            db 22, A_SPAWN, T_TORP, 6
            db 30, A_TELL, 14
            db 46, A_FAN, 3, 7
            db 54, A_SPAWN, T_TORP, 6
            db $FF
m_sub:      db 5,"UP PERISCOPE! IT'S A SUB",0
m_subdn:    db 6,"SUB-MERGED! +5000",0

; QUEEN JELLYFISH: her tentacles come down from above
s4_boss:    db T_QUEEN, 190, 140+XOFF, 16+YOFF, 92+XOFF, 16+YOFF, 2
            db 2, 10, 8+YOFF, 26+YOFF, 0
            dw m_visit, m_queen, m_queendn, tune_boss
            db $10, 8, 125, 65
            dw .p1, .p2, .p3
.p1:        db BM_BOB1, 96                  ; she pulses (tell) and lets her babies go
            db 16, A_FAN, 1, 0
            db 36, A_FRAME, 1
            db 36, A_SFX, SFX_HONK
            db 56, A_SPAWN, T_FISH2, 4
            db 62, A_SPAWN, T_FISH2, 10
            db 68, A_SPAWN, T_FISH2, 16
            db 72, A_FRAME, 0
            db $FF
.p2:        db BM_BOB1, 110                 ; angry: a tentacle from above (it comes slowly, then fast)
            db 1, A_FRAME, 2
            db 1, A_SFX, SFX_CREAK
            db 10, A_TELL, 14
            db 24, A_ARM, T_TENTACLE
            db 60, A_FAN, 3, 7
            db 70, A_TELL, 12
            db 82, A_ARM, T_TENTACLE
            db $FF
.p3:        db BM_BOB2|BM_FAST, 72          ; everything at once
            db 1, A_FRAME, 2
            db 6, A_ARM, T_TENTACLE
            db 20, A_RAIN, T_FIZZ
            db 30, A_TELL, 10
            db 40, A_FAN, 3, 8
            db 48, A_SPAWN, T_FISH2, 10
            db 56, A_RAIN, T_FIZZ
            db $FF
m_visit:    db 2,"VISITORS! DO STAY... FOREVER",0
m_queen:    db 4,"WARNING! QUEEN JELLYFISH",0
m_queendn:  db 5,"JELLY WOBBLED! +10000",0

s4_tl:      dw 2   : db TL_MSG : dw m_intro : db 100
            dw 10  : db TL_FORM, T_FISH, 5, 16, 12, 1
            dw 26  : db TL_SPAWN, T_GEYSER, 132+XOFF, 44+GY
            dw 32  : db TL_FORM, T_PUFFER, 3, 26, 18, 2
            dw 48  : db TL_SPAWN, T_SEAHORSE, 132+XOFF, 20+YOFF
            dw 54  : db TL_FORM, T_JELLY, 3, 50, 26, 3
            dw 72  : db TL_SPAWN, T_GEYSER, 132+XOFF, 44+GY
            dw 76  : db TL_SPAWN, T_CLAM, 144+XOFF, 44+GY
            dw 84  : db TL_FORM, T_FISH2, 5, 34, 12, 4
            dw 100 : db TL_FORM, T_CRAB, 3, 44, 26, 5
            dw 122 : db TL_SPAWN, T_GEYSER, 132+XOFF, 44+GY
            dw 128 : db TL_SPAWN, T_GEYSER, 132+XOFF, 44+GY
            dw 134 : db TL_SPAWN, T_SEAHORSE, 132+XOFF, 34+YOFF
            dw 140 : db TL_FORM, T_PUFFER, 4, 14, 16, 6
            dw 158 : db TL_FORM, T_JELLY, 4, 50, 20, 7
            dw 178 : db TL_SPAWN, T_CLAM, 132+XOFF, 44+GY
            dw 184 : db TL_FORM, T_FISH, 6, 22, 10, 8
            dw 202 : db TL_SPAWN, T_GEYSER, 132+XOFF, 44+GY
            dw 208 : db TL_SPAWN, T_GEYSER, 132+XOFF, 44+GY
            dw 214 : db TL_SPAWN, T_GEYSER, 132+XOFF, 44+GY
            dw 220 : db TL_SPAWN, T_SEAHORSE, 132+XOFF, 14+YOFF
            dw 226 : db TL_FORM, T_CRAB, 4, 44, 20, 1
            dw 244 : db TL_FORM, T_FISH2, 5, 12, 12, 2
            dw 256 : db TL_MSG : dw m_ping : db 80
            dw 266 : db TL_CALL : dw mid_start
            dw 266 : db TL_HOLD
            ; ---- THE WRECK
            dw WRECK_COL    : db TL_MSG : dw m_wreck : db 100
            dw WRECK_COL+4  : db TL_SPAWN, T_SHOP, 132+XOFF, 16+YOFF
            dw WRECK_COL+16 : db TL_FORM, T_FISH, 6, 12, 10, 3
            dw WRECK_COL+34 : db TL_SPAWN, T_GEYSER, 132+XOFF, 42+GY
            dw WRECK_COL+40 : db TL_FORM, T_JELLY, 4, 50, 18, 4
            dw WRECK_COL+58 : db TL_SPAWN, T_CLAM, 132+XOFF, 38+GY
            dw WRECK_COL+62 : db TL_SPAWN, T_SEAHORSE, 132+XOFF, 24+YOFF
            dw WRECK_COL+68 : db TL_FORM, T_PUFFER, 5, 20, 14, 5
            dw WRECK_COL+88 : db TL_SPAWN, T_GEYSER, 132+XOFF, 42+GY
            dw WRECK_COL+92 : db TL_SPAWN, T_GEYSER, 132+XOFF, 42+GY
            dw WRECK_COL+98 : db TL_SPAWN, T_CHEST, 132+XOFF, 36+GY
            dw WRECK_COL+104 : db TL_FORM, T_CRAB, 4, 37, 20, 6
            dw WRECK_COL+124 : db TL_FORM, T_FISH2, 6, 28, 10, 7
            dw WRECK_COL+142 : db TL_SPAWN, T_CLAM, 132+XOFF, 38+GY
            dw WRECK_COL+146 : db TL_SPAWN, T_CLAM, 146+XOFF, 38+GY
            dw WRECK_COL+152 : db TL_FORM, T_COIN, 8, 14, 5, 0
            dw WRECK_COL+166 : db TL_SPAWN, T_GEYSER, 132+XOFF, 42+GY
            dw WRECK_COL+170 : db TL_SPAWN, T_SEAHORSE, 132+XOFF, 14+YOFF
            dw WRECK_COL+176 : db TL_FORM, T_JELLY, 5, 50, 16, 8
            dw WRECK_COL+198 : db TL_SPAWN, T_GEYSER, 132+XOFF, 42+GY
            dw WRECK_COL+202 : db TL_SPAWN, T_GEYSER, 132+XOFF, 42+GY
            dw WRECK_COL+206 : db TL_FORM, T_PUFFER, 5, 26, 14, 1
            dw WRECK_COL+222 : db TL_FORM, T_FISH, 6, 18, 10, 2
            dw COURT_COL    : db TL_MSG : dw m_court : db 100
            dw COURT_COL+2  : db TL_SPAWN, T_SHOP, 132+XOFF, 18+YOFF
            dw COURT_COL+40 : db TL_CALL : dw boss_start
            dw COURT_COL+40 : db TL_HOLD
            dw $7FFF : db TL_END
m_intro:    db 3,"MIND THE GEYSERS: THEY FIZZ",0
m_ping:     db 10,"PING... PING...",0
m_wreck:    db 5,"THE WRECK OF THE WAFER",0
m_court:    db 4,"HER MAJESTY WILL SEE YOU",0

            include "gen/stg_tunes.inc"
            include "gen/stg_scen.inc"
            include "gen/stg_spr_rec.inc"
stg_end:
            assert stg_end <= STAGE_END
