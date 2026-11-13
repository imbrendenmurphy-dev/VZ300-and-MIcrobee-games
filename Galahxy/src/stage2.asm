; =====================================================================
;  stage2.asm - STAGE 2: BATH-TIME NEBULA  (GLXS2.DAT) - pastel palette
;  Someone left the bath running... in space.
;  Mechanic: bubbles float up from below all the time. They don't hurt,
;  but they soak up your shots - and every one you pop pays a coin.
;  Secret: pull the plug in the deep end.
;  Midboss: THE SHOWER HEAD.  Boss: ADMIRAL DUCKWORTH.
; =====================================================================
            org STAGE
            jp s2_init
            jp s2_ret
            jp s2_ret
            jp s2_ret
            jp s2_kill
            jp seg_next
            jp s2_ret
            dw GTILES, STILES, SMAP, s2_segs, s2_mid, s2_boss
            org STG_SPRTAB
            include "gen/stg_spr_tab.inc"
            assert $ <= STG_TYPES
T_DUCK      equ 1
T_BUBBLE    equ 2
T_SOAP      equ 3
T_SHAMPOO   equ 4
T_BRUSH     equ 5
T_FLANNEL   equ 6
T_BATHBOMB  equ 7
T_PLUG      equ 8
T_DROP      equ 9
T_SHOWER    equ 10
T_ADMIRAL   equ 11
T_JET       equ 12
T_DUCK2     equ 13
            org STG_TYPES
            db 0,0,0,0,0,0,0,0,0,0
            db BH_SINE,   SPR_DUCK,     1, 0,0,8,6, $10, TF_HARM|TF_ANIM, $16
            db BH_RISE,   SPR_BUBBLE,   1, 0,0,7,6, $05, TF_ANIM|TF_GROUND, 5
            db BH_BOUNCE, SPR_SOAP,     1, 0,0,7,4, $15, TF_HARM|TF_ANIM, 0
            db BH_GROUND, SPR_SHAMPOO,  3, 0,0,5,6, $30, TF_HARM|TF_ANIM|TF_GROUND, 70
            db BH_DART,   SPR_BRUSH,    1, 0,0,8,3, $15, TF_HARM|TF_ANIM, 30
            db BH_SWOOP,  SPR_FLANNEL,  2, 0,0,7,5, $20, TF_HARM|TF_ANIM, 1
            db BH_LINE,   SPR_BATHBOMB, 1, 0,0,5,5, $30, TF_HARM|TF_ANIM|TF_CARRY, 30
            db BH_GROUND, SPR_PLUG,     6, 0,0,7,5, $00, TF_GROUND|TF_HOOK, 0
            db BH_ARC,    SPR_DROP,     1, 0,0,3,4, $05, TF_HARM, 0
            db BH_BOSS,   SPR_SHOWER, 255, 2,4,17,8, $00, TF_HARM, 0
            db BH_BOSS,   SPR_ADMIRAL,255, 8,3,20,15,$00, TF_HARM, 0
            db BH_ARM,    SPR_JET,    255, 0,0,12,3, $00, TF_HARM|TF_ANIM, 0
            db BH_SINE,   SPR_DUCK,     1, 0,0,8,6, $15, TF_HARM|TF_ANIM, $29
            assert $ <= STG_CODE

            org STG_CODE
            db "BATH-TIME NEBULA",0
            db "SOMEONE LEFT THE BATH RUNNING",0

DEEP_COL    equ 400
DRAIN_COL   equ 642
GY          equ YOFF
s2_segs:    dw GMAP_INTRO, INTRO_C, $FFFF : db SG_NEXT
            dw GMAP_LOOP, LOOP_C, $FFFF : db SG_MID
            dw GMAP_DEEP, DEEP_C, DEEP_COL : db SG_NEXT
            dw GMAP_DRAIN, DRAIN_C, DRAIN_COL : db SG_NEXT
            dw GMAP_DRAIN, DRAIN_C, $FFFF : db SG_LOOP

s2_init:    ld a,L_MODE|L_CSS|L_SPK0   ; the pastel palette (CSS1)
            ld hl,s2_tl
            ld de,tune_stage
            jp stg_setup
s2_ret:     ret

; the plug: pull it for a secret
s2_kill:
            ld a,(ix+O_T)
            cp T_PLUG
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
            ld a,5
            call coin_burst
            ld hl,m_plug
            ld a,80
            jp stg_msg
m_plug:     db 2,"YOU PULLED THE PLUG! +5000",0

; THE SHOWER HEAD: hangs in the corner raining on everything
s2_mid:     db T_SHOWER, 80, 96+XOFF, YOFF-6, 96+XOFF, 12+YOFF, 1
            db 4, 12, 8+YOFF, 24+YOFF, 7
            dw 0, m_shower, m_showerdn, tune_mid
            db $05, 6, 40, 0
            dw .p1, .p2, .p2
.p1:        db BM_BOB1, 60
            db 1, A_SFX, SFX_HISS
            db 2, A_LOB, T_DROP, -8, 4
            db 12, A_LOB, T_DROP, -20, 0
            db 22, A_LOB, T_DROP, -32, -6
            db 40, A_FAN, 1, 0
            db $FF
.p2:        db BM_BOB2|BM_FAST, 60
            db 1, A_SFX, SFX_HISS
            db 2, A_LOB, T_DROP, -8, 4
            db 8, A_LOB, T_DROP, -18, 0
            db 14, A_LOB, T_DROP, -28, -6
            db 20, A_LOB, T_DROP, -38, -12
            db 30, A_TELL, 18
            db 30, A_SFX, SFX_CREAK
            db 50, A_FAN, 3, 7
            db $FF
m_shower:   db 5,"IT'S THE SHOWER HEAD!",0
m_showerdn: db 5,"ALL WASHED UP! +5000",0

; ADMIRAL DUCKWORTH: a very large rubber duck with a very large hat
s2_boss:    db T_ADMIRAL, 170, 140+XOFF, 22+YOFF, 92+XOFF, 22+YOFF, 2
            db 0, 8, 8+YOFF, 30+YOFF, 0
            dw m_quack, m_admiral, m_admiraldn, tune_boss
            db $10, 8, 115, 55
            dw .p1, .p2, .p3
.p1:        db BM_BOB1, 96                  ; opens his beak (tell): a flight of ducklings
            db 20, A_FAN, 1, 0
            db 40, A_FRAME, 1
            db 40, A_SFX, SFX_HONK
            db 60, A_SPAWN, T_DUCK2, 2
            db 68, A_SPAWN, T_DUCK2, 8
            db 76, A_SPAWN, T_DUCK2, 14
            db 80, A_FRAME, 0
            db $FF
.p2:        db 0, 100                       ; angry: lines up, then the water jet
            db 1, A_FRAME, 2
            db 1, A_SFX, SFX_CREAK
            db 1, A_TRACK, 34
            db 18, A_TELL, 20
            db 40, A_FRAME, 1
            db 40, A_ARM, T_JET
            db 40, A_SFX, SFX_HISS
            db 70, A_FRAME, 2
            db 76, A_LOB, T_DROP, -20, -26
            db 78, A_LOB, T_DROP, -34, -22
            db $FF
.p3:        db BM_BOB2, 64                  ; the bath overflows
            db 1, A_FRAME, 2
            db 4, A_RAIN, T_DROP
            db 20, A_RAIN, T_DROP
            db 36, A_RAIN, T_DROP
            db 52, A_RAIN, T_DROP
            db 10, A_SPAWN, T_DUCK2, 6
            db 24, A_TELL, 12
            db 36, A_FAN, 3, 8
            db $FF
m_quack:    db 2,"QUACK. PERMISSION TO BOARD?",0
m_admiral:  db 2,"WARNING! ADMIRAL DUCKWORTH",0
m_admiraldn: db 5,"DUCK SOUP! +10000",0

s2_tl:      dw 2   : db TL_MSG : dw m_intro : db 100
            dw 10  : db TL_FORM, T_DUCK, 5, 16, 12, 1
            dw 24  : db TL_FORM, T_BUBBLE, 3, 50, 30, 0
            dw 40  : db TL_FORM, T_BRUSH, 3, 26, 18, 2
            dw 56  : db TL_SPAWN, T_BATHBOMB, 132+XOFF, 30+YOFF
            dw 62  : db TL_FORM, T_BUBBLE, 4, 50, 22, 0
            dw 80  : db TL_SPAWN, T_SHAMPOO, 132+XOFF, 44+GY
            dw 86  : db TL_FORM, T_FLANNEL, 3, 8, 20, 3
            dw 104 : db TL_FORM, T_SOAP, 4, 48, 14, 4
            dw 120 : db TL_SPAWN, T_BATHBOMB, 132+XOFF, 18+YOFF
            dw 126 : db TL_FORM, T_BUBBLE, 5, 50, 16, 0
            dw 146 : db TL_FORM, T_DUCK, 6, 34, 10, 5
            dw 164 : db TL_SPAWN, T_SHAMPOO, 132+XOFF, 44+GY
            dw 168 : db TL_SPAWN, T_SHAMPOO, 142+XOFF, 44+GY
            dw 174 : db TL_FORM, T_BRUSH, 4, 14, 16, 6
            dw 192 : db TL_FORM, T_BUBBLE, 4, 50, 18, 0
            dw 208 : db TL_FORM, T_FLANNEL, 4, 8, 16, 7
            dw 226 : db TL_SPAWN, T_BATHBOMB, 132+XOFF, 38+YOFF
            dw 232 : db TL_FORM, T_DUCK2, 5, 22, 12, 8
            dw 250 : db TL_MSG : dw m_drip : db 80
            dw 262 : db TL_CALL : dw mid_start
            dw 262 : db TL_HOLD
            dw DEEP_COL    : db TL_MSG : dw m_deep : db 100
            dw DEEP_COL+4  : db TL_SPAWN, T_SHOP, 132+XOFF, 20+YOFF
            dw DEEP_COL+16 : db TL_FORM, T_DUCK, 6, 12, 10, 1
            dw DEEP_COL+34 : db TL_FORM, T_BUBBLE, 5, 50, 14, 0
            dw DEEP_COL+52 : db TL_FORM, T_FLANNEL, 4, 8, 16, 2
            dw DEEP_COL+70 : db TL_SPAWN, T_BATHBOMB, 132+XOFF, 24+YOFF
            dw DEEP_COL+76 : db TL_FORM, T_SOAP, 5, 40, 12, 3
            dw DEEP_COL+96 : db TL_FORM, T_BRUSH, 5, 30, 14, 4
            dw DEEP_COL+110 : db TL_SPAWN, T_PLUG, 132+XOFF, 46+GY
            dw DEEP_COL+116 : db TL_FORM, T_BUBBLE, 6, 50, 12, 0
            dw DEEP_COL+136 : db TL_FORM, T_DUCK2, 6, 26, 10, 5
            dw DEEP_COL+156 : db TL_FORM, T_COIN, 8, 16, 5, 0
            dw DEEP_COL+170 : db TL_SPAWN, T_BATHBOMB, 132+XOFF, 36+YOFF
            dw DEEP_COL+176 : db TL_FORM, T_FLANNEL, 5, 8, 14, 6
            dw DEEP_COL+198 : db TL_FORM, T_DUCK, 6, 34, 10, 7
            dw DEEP_COL+216 : db TL_FORM, T_BRUSH, 4, 18, 14, 8
            dw DRAIN_COL    : db TL_MSG : dw m_drain : db 100
            dw DRAIN_COL+2  : db TL_SPAWN, T_SHOP, 132+XOFF, 18+YOFF
            dw DRAIN_COL+10 : db TL_FORM, T_BUBBLE, 4, 50, 16, 0
            dw DRAIN_COL+40 : db TL_CALL : dw boss_start
            dw DRAIN_COL+40 : db TL_HOLD
            dw $7FFF : db TL_END
m_intro:    db 4,"BATH TIME! MIND THE SUDS",0
m_drip:     db 9,"DRIP... DRIP...",0
m_deep:     db 8,"THE DEEP END",0
m_drain:    db 3,"SOMETHING IS IN THE BATH...",0

            include "gen/stg_tunes.inc"
            include "gen/stg_scen.inc"
            include "gen/stg_spr_rec.inc"
stg_end:
            assert stg_end <= STAGE_END
