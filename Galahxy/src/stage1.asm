; =====================================================================
;  stage1.asm - STAGE 1: PARTY PLANET  (GLXS1.DAT, $B800-$E3FF)
;  The party snacks have come alive.
;  Mechanic: the party fights back from the ground (candy cannons lob
;  sprinkles, beach balls bounce, gift boxes hide cupcakes), and the
;  balloon arch splits the stage: fly HIGH for the CLOUD TOPS (coin
;  trails, party bunnies, penguins) or LOW for the LOLLY GARDEN
;  (gingerbread men - shoot three and the GOLDEN one turns up).
;  Midboss: THE CAROUSEL.  Boss: KING WOBBLE.
; =====================================================================
            org STAGE
            jp s1_init
            jp s1_ret
            jp s1_ret
            jp s1_ret
            jp s1_kill
            jp seg_next
            jp s1_ret
            dw GTILES, STILES, SMAP, s1_segs, s1_mid, s1_boss
            org STG_SPRTAB
            include "gen/stg_spr_tab.inc"
            assert $ <= STG_TYPES

; ---- object types (beh, spr, hp, ox, oy, w, h, score BCD tens, flags, param)
T_SNAG      equ 1
T_SNAG2     equ 2
T_BLOWIE    equ 3
T_SWOOPER   equ 4
T_THONG     equ 5
T_TINNIE    equ 6
T_SPRINK    equ 7
T_ESKY      equ 8
T_GNOME     equ 9
T_GOLDGN    equ 10
T_HOTSNAG   equ 11
T_POSSUM    equ 12
T_HOIST     equ 13
T_PEG       equ 14
T_UNDIES    equ 15
T_GRILL     equ 16
T_TONGS     equ 17
            org STG_TYPES
            db 0,0,0,0,0,0,0,0,0,0
            db BH_SINE,   SPR_SNAG,     1, 0,0,8,3, $10, TF_HARM|TF_ANIM, $16
            db BH_SINE,   SPR_SNAG,     1, 0,0,8,3, $10, TF_HARM|TF_ANIM, $28
            db BH_DART,   SPR_BLOWIE,   1, 0,1,6,4, $15, TF_HARM|TF_ANIM, 34
            db BH_SWOOP,  SPR_SWOOPER,  2, 0,1,7,5, $20, TF_HARM|TF_ANIM, 1
            db BH_BOUNCE, SPR_THONG,    1, 0,0,7,3, $15, TF_HARM|TF_ANIM, 0
            db BH_LINE,   SPR_TINNIE,   1, 0,0,4,5, $30, TF_HARM|TF_ANIM|TF_CARRY, 30
            db BH_GROUND, SPR_SPRINKLER,3, 0,1,5,3, $30, TF_HARM|TF_ANIM|TF_GROUND, 64
            db BH_GROUND, SPR_ESKY,     4, 0,0,8,5, $50, TF_HARM|TF_GROUND|TF_HOOK, 0
            db BH_GROUND, SPR_GNOME,    2, 0,0,5,7, $20, TF_HARM|TF_GROUND|TF_HOOK, 0
            db BH_GROUND, SPR_GNOME+1,  6, 0,0,5,7, $00, TF_GROUND|TF_HOOK, 0
            db BH_ARC,    SPR_HOTSNAG,  1, 0,0,5,3, $05, TF_HARM|TF_ANIM, 0
            db BH_BOUNCE, SPR_POSSUM,   2, 0,0,6,5, $25, TF_HARM, 0
            db BH_BOSS,   SPR_HOIST,  255, 7,3,9,10,$00, TF_HARM, 0
            db BH_ARC,    SPR_PEG,      1, 0,0,3,3, $05, TF_HARM, 0
            db BH_SINE,   SPR_UNDIES,   1, 0,0,5,3, $05, TF_HARM|TF_ANIM, $28
            db BH_BOSS,   SPR_GRILL,  255, 3,0,26,14,$00, TF_HARM, 0
            db BH_ARM,    SPR_TONGS,  255, 0,0,12,3,$00, TF_HARM|TF_ANIM, 0
            assert $ <= STG_CODE

            org STG_CODE
s1_name:    db "PARTY PLANET",0
            db "THE PARTY SNACKS HAVE COME ALIVE",0

GATE_COL    equ 400
ROUTE_COL   equ 450
PATIO_COL   equ 692
GY          equ YOFF               ; ground objects: y below is the screen row
s1_segs:    dw GMAP_INTRO, INTRO_C, $FFFF : db SG_NEXT
            dw GMAP_LAWN, LAWN_C, $FFFF : db SG_MID
            dw GMAP_GATE, GATE_C, GATE_COL : db SG_NEXT
            dw GMAP_ROOF, ROOF_C, ROUTE_COL : db SG_ROUTE
            dw GMAP_GARDEN, GARDEN_C, ROUTE_COL : db SG_NEXT
            dw GMAP_PATIO, PATIO_C, PATIO_COL : db SG_NEXT
            dw GMAP_PATIO, PATIO_C, $FFFF : db SG_LOOP

s1_init:    ld a,L_MODE|L_SPK0      ; the main palette (CSS0)
            ld hl,s1_tl
            ld de,tune_stage1
            jp stg_setup
s1_ret:     ret

; ---------------------------------------------------------------------
; hooked kills: gift boxes, gingerbread men, the golden one
; ---------------------------------------------------------------------
s1_kill:
            ld a,(ix+O_T)
            cp T_ESKY
            jr nz,.k1
            ld b,(ix+O_X)
            ld c,(ix+O_Y)
            dec c
            dec c
            ld a,T_PIE
            call spawn_keep
            ld hl,m_esky
            ld a,50
            jp stg_msg
.k1:        cp T_GNOME
            jr nz,.k2
            ld a,(route)
            or a
            ret z
            ld hl,stg_cnt
            inc (hl)
            ld a,(hl)
            cp 3
            ret nz
            ld b,136+XOFF
            ld c,46+GY
            ld a,T_GOLDGN
            call spawn_keep
            ld a,SFX_SECRET
            call sfx
            ld hl,m_gold
            ld a,70
            jp stg_msg
.k2:        cp T_GOLDGN
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
            ld a,3
            call coin_burst
            ld hl,m_secret
            ld a,70
            jp stg_msg
m_esky:     db 5,"A CUPCAKE IN THE BOX!",0
m_gold:     db 3,"A GOLDEN GINGERBREAD?!",0
m_secret:   db 6,"SECRET! +5000",0

; ---------------------------------------------------------------------
; THE CAROUSEL: drops in spinning, flings streamers and wooden horses;
; when hurt it bobs wider and flashes before a three-way volley.
; ---------------------------------------------------------------------
s1_mid:     db T_HOIST, 70, 96+XOFF, YOFF-6, 96+XOFF, 16+YOFF, 1
            db 9, 6, 10+YOFF, 30+YOFF, 7
            dw 0, m_hoist, m_hoistdn, tune_hoist
            db $05, 6, 35, 0
            dw .p1, .p2, .p2
.p1:        db BM_BOB1, 64
            db 1, A_SFX, SFX_WHIRR
            db 1, A_SPAWN, T_UNDIES, 4
            db 2, A_SPAWN, T_UNDIES, 10
            db 3, A_LOB, T_PEG, -20, -18
            db $FF
.p2:        db BM_BOB2, 64
            db 40, A_SFX, SFX_CREAK
            db 40, A_TELL, 22
            db 63, A_FAN, 3, 6
            db 1, A_LOB, T_PEG, -20, -18
            db 2, A_LOB, T_PEG, -28, -12
            db 3, A_SPAWN, T_UNDIES, 6
            db $FF
m_hoist:    db 4,"THE CAROUSEL SPINS UP!",0
m_hoistdn:  db 5,"MERRY-GO-DOWN! +5000",0

; ---------------------------------------------------------------------
; KING WOBBLE: wobbles in and asks if this is the party - then:
;  phase 1: lifts his crown (tell) and lobs three jelly blobs
;  phase 2: angry eyes while he lines up (tell), then the giant spoon
;  phase 3: crown off - jelly rains down and he fires fans of shots
; ---------------------------------------------------------------------
s1_boss:    db T_GRILL, 150, 140+XOFF, 24+YOFF, 92+XOFF, 24+YOFF, 0
            db 0, 8, 10+YOFF, 34+YOFF, 0
            dw m_gday, m_grill, m_grilldn, tune_boss
            db $10, 8, 100, 50
            dw .p1, .p2, .p3
.p1:        db BM_BOB1|BM_FAST, 90
            db 20, A_FAN, 1, 0
            db 40, A_FRAME, 1
            db 40, A_SFX, SFX_SIZZLE
            db 64, A_FRAME, 0
            db 64, A_LOB, T_HOTSNAG, -16, -24
            db 65, A_LOB, T_HOTSNAG, -24, -24
            db 66, A_LOB, T_HOTSNAG, -32, -24
            db 66, A_SFX, SFX_BOMB
            db $FF
.p2:        db 0, 110
            db 1, A_FRAME, 2
            db 1, A_SFX, SFX_CREAK
            db 1, A_TRACK, 36
            db 20, A_TELL, 18
            db 40, A_FRAME, 1
            db 40, A_ARM, T_TONGS
            db 40, A_SFX, SFX_WHIRR
            db 80, A_FRAME, 0
            db 80, A_LOB, T_HOTSNAG, -22, -24
            db 81, A_LOB, T_HOTSNAG, -34, -24
            db $FF
.p3:        db BM_BOB2, 64
            db 1, A_FRAME, 2
            db 2, A_RAIN, T_HOTSNAG
            db 18, A_RAIN, T_HOTSNAG
            db 34, A_RAIN, T_HOTSNAG
            db 50, A_RAIN, T_HOTSNAG
            db 20, A_TELL, 12
            db 32, A_FAN, 3, 8
            db 50, A_SFX, SFX_SIZZLE
            db $FF
m_gday:     db 1,"PARDON ME. IS THIS THE PARTY?",0
m_grill:    db 5,"WARNING! KING WOBBLE",0
m_grilldn:  db 4,"JUST DESSERTS! +10000",0

; ---------------------------------------------------------------------
; the timeline (ground columns; 1 column = 4 px = 4 frames)
; ---------------------------------------------------------------------
s1_tl:
            dw 2   : db TL_MSG : dw m_intro : db 100
            dw 12  : db TL_FORM, T_SNAG, 5, 14, 12, 1
            dw 32  : db TL_FORM, T_BLOWIE, 3, 24, 18, 2
            dw 50  : db TL_SPAWN, T_TINNIE, 132+XOFF, 30+YOFF
            dw 58  : db TL_FORM, T_SNAG, 5, 36, 12, 3
            dw 78  : db TL_SPAWN, T_SPRINK, 132+XOFF, 51+GY
            dw 84  : db TL_FORM, T_SWOOPER, 3, 8, 20, 4
            dw 104 : db TL_SPAWN, T_TINNIE, 132+XOFF, 16+YOFF
            dw 110 : db TL_FORM, T_THONG, 4, 50, 14, 5
            dw 130 : db TL_SPAWN, T_ESKY, 132+XOFF, 50+GY
            dw 136 : db TL_FORM, T_BLOWIE, 4, 32, 16, 6
            dw 156 : db TL_SPAWN, T_SPRINK, 132+XOFF, 51+GY
            dw 160 : db TL_FORM, T_SNAG2, 6, 20, 10, 7
            dw 182 : db TL_SPAWN, T_TINNIE, 132+XOFF, 40+YOFF
            dw 188 : db TL_FORM, T_SWOOPER, 4, 8, 16, 8
            dw 210 : db TL_SPAWN, T_SPRINK, 132+XOFF, 51+GY
            dw 216 : db TL_SPAWN, T_SPRINK, 140+XOFF, 51+GY
            dw 222 : db TL_FORM, T_SNAG, 5, 30, 12, 1
            dw 240 : db TL_FORM, T_BLOWIE, 5, 18, 14, 2
            dw 262 : db TL_SPAWN, T_TINNIE, 132+XOFF, 24+YOFF
            dw 268 : db TL_FORM, T_THONG, 5, 50, 12, 3
            dw 290 : db TL_MSG : dw m_wash : db 80
            dw 304 : db TL_CALL : dw mid_start
            dw 304 : db TL_HOLD
            ; ---- after the HOIST: the side gate
            dw GATE_COL   : db TL_MSG : dw m_gate : db 120
            dw GATE_COL+6 : db TL_FORM, T_SNAG, 4, 24, 12, 4
            dw GATE_COL+18 : db TL_SPAWN, T_SHOP, 132+XOFF, 22+YOFF
            dw GATE_COL+30 : db TL_SPAWN, T_TINNIE, 132+XOFF, 30+YOFF
            dw ROUTE_COL  : db TL_IFROUTE, 0 : dw .garden
            ; ---- ROOF: coin trails, possums, magpies
            dw ROUTE_COL+2 : db TL_MSG : dw m_roof : db 90
            dw 458 : db TL_FORM, T_COIN, 6, 18, 6, 0
            dw 470 : db TL_FORM, T_POSSUM, 3, 34, 20, 5
            dw 492 : db TL_FORM, T_SWOOPER, 4, 8, 16, 6
            dw 515 : db TL_FORM, T_COIN, 8, 30, 5, 0
            dw 525 : db TL_SPAWN, T_TINNIE, 132+XOFF, 20+YOFF
            dw 535 : db TL_FORM, T_POSSUM, 4, 34, 18, 7
            dw 560 : db TL_FORM, T_BLOWIE, 5, 14, 14, 8
            dw 585 : db TL_FORM, T_COIN, 8, 12, 5, 0
            dw 598 : db TL_FORM, T_SWOOPER, 5, 8, 14, 1
            dw 625 : db TL_SPAWN, T_TINNIE, 132+XOFF, 36+YOFF
            dw 630 : db TL_FORM, T_SNAG2, 6, 26, 10, 2
            dw 660 : db TL_FORM, T_POSSUM, 4, 34, 18, 3
            dw 660 : db TL_GOTO : dw .patio
            ; ---- GARDEN: gnomes (three -> the golden one), sprinklers, an esky
.garden:    dw ROUTE_COL+2 : db TL_MSG : dw m_garden : db 90
            dw 460 : db TL_SPAWN, T_GNOME, 132+XOFF, 48+GY
            dw 468 : db TL_FORM, T_SNAG, 5, 20, 12, 3
            dw 490 : db TL_SPAWN, T_SPRINK, 132+XOFF, 51+GY
            dw 496 : db TL_FORM, T_THONG, 4, 50, 14, 4
            dw 515 : db TL_SPAWN, T_GNOME, 132+XOFF, 48+GY
            dw 522 : db TL_FORM, T_BLOWIE, 4, 30, 16, 5
            dw 545 : db TL_SPAWN, T_ESKY, 132+XOFF, 50+GY
            dw 550 : db TL_FORM, T_SNAG2, 6, 14, 10, 6
            dw 575 : db TL_SPAWN, T_GNOME, 132+XOFF, 48+GY
            dw 580 : db TL_SPAWN, T_SPRINK, 150+XOFF, 51+GY
            dw 590 : db TL_FORM, T_SWOOPER, 4, 8, 16, 7
            dw 615 : db TL_SPAWN, T_TINNIE, 132+XOFF, 28+YOFF
            dw 620 : db TL_FORM, T_COIN, 6, 36, 6, 0
            dw 640 : db TL_FORM, T_THONG, 5, 50, 12, 8
            dw 660 : db TL_FORM, T_BLOWIE, 4, 22, 16, 1
            ; ---- the PATIO: the barbie
.patio:     dw PATIO_COL    : db TL_MSG : dw m_patio : db 100
            dw PATIO_COL+2  : db TL_SPAWN, T_SHOP, 132+XOFF, 18+YOFF
            dw PATIO_COL+8  : db TL_FORM, T_SNAG, 6, 30, 10, 2
            dw PATIO_COL+40 : db TL_CALL : dw boss_start
            dw PATIO_COL+40 : db TL_HOLD
            dw $7FFF : db TL_END
m_intro:    db 3,"WELCOME TO PARTY PLANET!",0
m_wash:     db 3,"ALL ABOARD THE CAROUSEL!",0
m_gate:     db 1,"UP: CLOUD TOPS  DOWN: LOLLIES",0
m_roof:     db 6,"OVER THE CLOUD TOPS!",0
m_garden:   db 4,"THROUGH THE LOLLY GARDEN!",0
m_patio:    db 4,"SOMEONE SET THE TABLE...",0

; ---- tunes, scenery and sprites
            include "gen/stg_tunes.inc"
            include "gen/stg_scen.inc"
            include "gen/stg_spr_rec.inc"
stg_end:
            assert stg_end <= STAGE_END
