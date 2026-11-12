; =====================================================================
;  stage1.asm - STAGE 1: BACKYARD BLITZ  (GLXS1.DAT, $B800-$E3FF)
;  Sunday arvo in the suburbs and the backyard has come alive.
;  Mechanic: the backyard fights back from the ground (sprinklers lob
;  arcs of water, thongs hop, eskies hide pies), and the side gate
;  splits the stage: fly HIGH over the shed ROOF (coin trails, possums,
;  magpies) or LOW through the GARDEN (gnomes - shoot three and the
;  GOLDEN GNOME turns up).
;  Midboss: THE HILLS HOIST.  Boss: THE GRILLFATHER.
; =====================================================================
            org STAGE
            jp s1_init
            jp s1_frame
            jp s1_obj
            jp s1_hit
            jp s1_kill
            jp s1_seg
            jp s1_draw
            dw GTILES, STILES, SMAP, 0
            org STG_SPRTAB
            include "gen/s1spr_tab.inc"
            assert $ <= STG_TYPES

; ---- object types (beh, spr, hp, ox, oy, w, h, score BCD tens, flags, param)
TF_GROUND   equ 1<<F_GROUND
TF_ANIM     equ 1<<F_ANIM
TF_CARRY    equ 1<<F_CARRY
TF_HARM     equ 1<<F_HARM
TF_HOOK     equ 1<<F_HOOK
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
            db BH_STAGE,  SPR_HOIST,  255, 7,3,9,10,$00, TF_HARM, 0
            db BH_ARC,    SPR_PEG,      1, 0,0,3,3, $05, TF_HARM, 0
            db BH_SINE,   SPR_UNDIES,   1, 0,0,5,3, $05, TF_HARM|TF_ANIM, $28
            db BH_STAGE,  SPR_GRILL,  255, 3,0,26,14,$00, TF_HARM, 0
            db BH_STAGE,  SPR_TONGS,  255, 0,0,12,3,$00, TF_HARM|TF_ANIM, 0
            assert $ <= STG_CODE

            org STG_CODE
s1_name:    db "BACKYARD BLITZ",0
            db "SUNDAY ARVO. THE BARBIE'S ALIVE!",0

; ---- stage state (kept in the stage pack; reset by s1_init)
seg_st:     db 0
mid_done:   db 0
gnome_n:    db 0
boss_cyc:   db 0
boss_base:  db 0
GATE_COL    equ 400
ROUTE_COL   equ 450
PATIO_COL   equ 692
GY          equ YOFF               ; ground objects: y below is the screen row

s1_init:
            ld hl,s1_tl
            ld (tl_p),hl
            xor a
            ld (seg_st),a
            ld (mid_done),a
            ld (gnome_n),a
            ld (route),a
            ld a,L_MODE|L_SPK0
            ld (latchv),a
            ld hl,tune_stage1
            jp music

s1_frame:   ret
s1_draw:    ret

; ---------------------------------------------------------------------
; ground segments: intro, (lawn while the HOIST is up), gate, route, patio
; ---------------------------------------------------------------------
s1_seg:
            ld a,(seg_st)
            or a
            jr nz,.s1
            inc a
            ld (seg_st),a
            ld hl,GMAP_INTRO
            ld de,INTRO_C
            jr .set
.s1:        cp 1
            jr nz,.s2
            ld a,(mid_done)
            or a
            jr nz,.gate
            ld hl,GMAP_LAWN
            ld de,LAWN_C
            jr .set
.gate:      ld a,2
            ld (seg_st),a
            ld hl,GATE_COL
            ld (tl_col),hl
            ld hl,GMAP_GATE
            ld de,GATE_C
            jr .set
.s2:        cp 2
            jr nz,.s3
            ld a,3
            ld (seg_st),a
            ld hl,ROUTE_COL
            ld (tl_col),hl
            ld a,(p_y)              ; the route: high = roof, low = garden
            cp 30+YOFF
            ld a,0
            ld hl,GMAP_ROOF
            ld bc,m_roof
            jr c,.rt
            inc a
            ld hl,GMAP_GARDEN
            ld bc,m_garden
.rt:        ld (route),a
            ld (msg_p),bc
            ld a,80
            ld (msg_t),a
            ld a,SFX_SECRET
            call sfx
            ld de,ROUTE_C
            jr .set
.s3:        cp 3
            jr nz,.s4
            ld a,4
            ld (seg_st),a
            ld hl,PATIO_COL
            ld (tl_col),hl
.s4:        ld hl,GMAP_PATIO        ; (loops under the boss)
            ld de,ARENA_C
.set:       ld (gm_p),hl
            ld (gm_left),de
            ret
m_roof:     db 6,"OVER THE SHED ROOF!",0
m_garden:   db 4,"THROUGH THE VEGGIE PATCH!",0

; ---------------------------------------------------------------------
; hooked kills
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
            push ix
            call spawn_obj
            pop ix
            ld hl,m_esky
            ld a,50
            jp s1_msg
.k1:        cp T_GNOME
            jr nz,.k2
            ld a,(route)
            or a
            ret z
            ld hl,gnome_n
            inc (hl)
            ld a,(hl)
            cp 3
            ret nz
            ld b,136+XOFF
            ld c,48+GY
            ld a,T_GOLDGN
            push ix
            call spawn_obj
            pop ix
            ld a,SFX_SECRET
            call sfx
            ld hl,m_gold
            ld a,70
            jp s1_msg
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
            jp s1_msg
m_esky:     db 7,"PIES IN THE ESKY!",0
m_gold:     db 6,"A GOLDEN GNOME?!",0
m_secret:   db 6,"SECRET! +5000",0

; HL = message, A = time
s1_msg:
            ld (msg_p),hl
            ld (msg_t),a
            ret

; A coins around B,C
coin_burst:
            push ix
.l:         push af
            push bc
            call random
            and 15
            add a,b
            ld b,a
            call random
            and 7
            sub 4
            add a,c
            ld c,a
            ld a,T_COIN
            call spawn_obj
            pop bc
            pop af
            dec a
            jr nz,.l
            pop ix
            ret

; ---------------------------------------------------------------------
; stage objects: the HILLS HOIST, the GRILLFATHER and his tongs
; ---------------------------------------------------------------------
s1_obj:
            ld a,(ix+O_T)
            cp T_HOIST
            jp z,hoist_ai
            cp T_GRILL
            jp z,grill_ai
            jp tongs_ai

; boss took C damage (only while O_P = 1)
s1_hit:
            ld a,(ix+O_T)
            cp T_TONGS
            jr z,.clink
            ld a,(ix+O_P)
            or a
            jr z,.clink
            ld a,(boss_hp)
            sub c
            jr nc,.ok
            xor a
.ok:        ld (boss_hp),a
            ld a,1
            ld (hud_dirty),a
            ld a,(boss_hp)
            or a
            jr z,.dead
            ld a,SFX_KNOCK
            jp sfx
.clink:     res F_FLASH,(ix+O_FL)
            ld a,SFX_KNOCK
            jp sfx
.dead:      ld (ix+O_P),0
            ld (ix+O_ST),9
            ld (ix+O_TM),0
            ld a,SFX_BIG
            call sfx
            jp silence_music
silence_music:
            ld hl,0
            jp music

; set up the boss bar: A = hit points
boss_bar_on:
            ld (boss_hp),a
            ld (boss_max),a
            xor a
            ld (boss_hp+1),a
            ld (boss_max+1),a
            inc a
            ld (boss_bar),a
            ld (hud_dirty),a
            ret

; dying: explosions for A frames, then NZ... returns Z when finished
boss_dying:
            inc (ix+O_TM)
            ld a,(ix+O_TM)
            and 3
            jr nz,.nb
            push bc
            call random
            and 15
            add a,(ix+O_X)
            add a,2
            ld b,a
            call random
            and 7
            add a,(ix+O_Y)
            ld c,a
            push ix
            ld a,T_BOOM
            call spawn_obj
            pop ix
            ld a,(ix+O_TM)
            and 15
            ld a,SFX_KILL
            call z,sfx
            pop bc
.nb:        ld a,(ix+O_TM)
            and 4
            jr z,.nf
            set F_FLASH,(ix+O_FL)
.nf:        ld a,(ix+O_TM)
            cp b
            ret

; ---------------------------------------------------------------------
; THE HILLS HOIST: drops in spinning, flings undies and pegs; when hurt
; it spins faster, swings wider and winds up (flashing, creaking) before
; a three-way peg volley.  Weak point: the hub.
; ---------------------------------------------------------------------
HOIST_HP    equ 70
mid_start:
            ld a,PH_MID
            ld (stg_phase),a
            ld b,96+XOFF
            ld c,YOFF-6
            ld a,T_HOIST
            call spawn_obj
            ret c
            ld a,SFX_CREAK
            call sfx
            ld hl,tune_hoist
            jp music

hoist_ai:
            ld a,(ix+O_ST)
            cp 9
            jp z,.die
            inc (ix+O_TM)
            ; spin: faster when hurt
            ld a,(boss_hp)
            cp HOIST_HP/2
            ld a,7
            jr nc,.sp
            ld a,3
.sp:        and (ix+O_TM)
            jr nz,.ns
            ld a,(ix+O_SPR)
            xor 1
            ld (ix+O_SPR),a
.ns:        ld a,(ix+O_ST)
            or a
            jr nz,.fight
            ; dropping in
            ld a,(ix+O_TM)
            and 1
            ret nz
            inc (ix+O_Y)
            ld a,(ix+O_Y)
            cp 16+YOFF
            ret c
            ld (ix+O_ST),1
            ld (ix+O_P),1
            ld (ix+O_TM),0
            ld a,HOIST_HP
            call boss_bar_on
            ld hl,m_hoist
            ld a,60
            call s1_msg
            ld a,SFX_WARN
            jp sfx
.fight:     ; bob up and down (wider when hurt)
            ld a,(ix+O_TM)
            and 63
            ld e,a
            ld d,0
            ld hl,sine16
            add hl,de
            ld a,(hl)
            sra a
            ld c,a
            ld a,(boss_hp)
            cp HOIST_HP/2
            jr c,.wide
            sra c
.wide:      ld a,16+YOFF
            add a,c
            ld (ix+O_Y),a
            ld a,(boss_hp)
            cp HOIST_HP/2
            jr c,.angry
            ; calm: every 64 frames fling two pairs of undies and a peg
            ld a,(ix+O_TM)
            and 63
            ret nz
            ld a,SFX_WHIRR
            call sfx
            call .hub
            ld a,T_UNDIES
            call .spawn
            call .hub
            ld a,c
            add a,6
            ld c,a
            ld a,T_UNDIES
            call .spawn
            jp .peg
.angry:     ; wind up (flash + creak) for 16 frames, then a volley
            ld a,(ix+O_TM)
            and 63
            cp 40
            jr nz,.nc
            ld a,SFX_CREAK
            call sfx
.nc:        cp 40
            jr c,.nt
            bit 1,(ix+O_TM)
            jr z,.nt
            set F_FLASH,(ix+O_FL)
.nt:        ld a,(ix+O_TM)
            and 63
            ret nz
            call .hub
            push bc
            call fire_at
            pop bc
            push bc
            ld a,c
            sub 6
            ld c,a
            call fire_at
            pop bc
            ld a,c
            add a,6
            ld c,a
            call fire_at
            call .peg
            ld a,T_UNDIES
            call .hub
            ld a,T_UNDIES
            jp .spawn
.peg:       call .hub
            ld a,T_PEG
            call .spawn
            ret c
            ld hl,-$0140
            ld (iy+O_VX),l
            ld (iy+O_VX+1),h
            ld hl,-$0120
            ld (iy+O_VY),l
            ld (iy+O_VY+1),h
            ret
.hub:       ld a,(ix+O_X)
            add a,9
            ld b,a
            ld a,(ix+O_Y)
            add a,6
            ld c,a
            ret
; spawn A at B,C keeping IX -> IY = the new object
.spawn:     push ix
            call spawn_obj
            push ix
            pop iy
            pop ix
            ret
.die:       ld b,60
            call boss_dying
            ret c
            ; collapse: coins everywhere, the stage rolls on
            ld b,(ix+O_X)
            ld c,(ix+O_Y)
            ld (ix+O_T),0
            ld a,6
            call coin_burst
            ld de,$0500
            call add_score
            xor a
            ld (boss_bar),a
            ld (tl_hold),a
            ld (stg_phase),a
            inc a
            ld (mid_done),a
            ld (hud_dirty),a
            ld hl,m_hoistdn
            ld a,80
            call s1_msg
            ld hl,tune_stage1
            jp music
m_hoist:    db 4,"THE HILLS HOIST SPINS UP!",0
m_hoistdn:  db 7,"CLOTHESLINED! +5000",0

; ---------------------------------------------------------------------
; THE GRILLFATHER: waddles in, says G'DAY - then means business.
;  phase 1: the lid lifts (tell) and he lobs three hot snags
;  phase 2: angry eyes (tell) while he lines up, then the tongs shoot out
;  phase 3: lid off, flames - snags rain down and pellet fans
; ---------------------------------------------------------------------
GRILL_HP    equ 150
boss_start:
            ld a,PH_BOSS
            ld (stg_phase),a
            ld a,(p_hits)
            ld (boss_hits0),a
            call silence_music
            ld b,140+XOFF
            ld c,24+YOFF
            ld a,T_GRILL
            call spawn_obj
            ret

grill_ai:
            ld a,(ix+O_ST)
            cp 9
            jp z,.die
            inc (ix+O_TM)
            or a
            jr nz,.s1
            ; walking in: a stomp every 8 frames, legs alternate
            ld a,(ix+O_TM)
            and 7
            ret nz
            ld a,SFX_KNOCK
            call sfx
            ld a,(ix+O_X)
            sub 4
            ld (ix+O_X),a
            ld a,(ix+O_Y)
            xor 1
            ld (ix+O_Y),a
            ld a,(ix+O_X)
            cp 92+XOFF
            ret nc
            ld (ix+O_ST),1
            ld (ix+O_TM),0
            ld (ix+O_SPR),SPR_GRILL+1
            ld a,SFX_HONK
            call sfx
            ld hl,m_gday
            ld a,60
            jp s1_msg
.s1:        cp 1
            jr nz,.s2
            ; "G'DAY MATE!" then the warning
            ld a,(ix+O_TM)
            cp 30
            jr nz,.n30
            ld (ix+O_SPR),SPR_GRILL
.n30:       cp 64
            jr nz,.n64
            ld (ix+O_SPR),SPR_GRILL+2
            ld a,SFX_WARN
            call sfx
            ld hl,m_grill
            ld a,70
            call s1_msg
.n64:       ld a,(ix+O_TM)
            cp 120
            ret c
            ld (ix+O_ST),2
            ld (ix+O_P),1
            ld (ix+O_TM),0
            ld (ix+O_SPR),SPR_GRILL
            ld a,(ix+O_Y)
            ld (boss_base),a
            ld a,GRILL_HP
            call boss_bar_on
            ld hl,tune_boss
            jp music
.s2:        ; ---- the fight
            ld a,(boss_hp)
            cp GRILL_HP/3
            jp c,.p3
            cp GRILL_HP*2/3
            jr c,.p2
            ; phase 1: bob; lid up at 40 (tell), lob at 64, cycle 90
            call .bob4
            ld a,(ix+O_TM)
            cp 40
            jr nz,.a1
            ld (ix+O_SPR),SPR_GRILL+1
            ld a,SFX_SIZZLE
            jp sfx
.a1:        cp 64
            jr nz,.a2
            ld (ix+O_SPR),SPR_GRILL
            ld de,-$0100
            call .lob
            ld de,-$0180
            call .lob
            ld de,-$0200
            call .lob
            ld a,SFX_BOMB
            jp sfx
.a2:        cp 20
            jr nz,.a3
            ld a,(diff)
            or a
            jr z,.a3
            call .mouth
            call fire_at
.a3:        ld a,(ix+O_TM)
            cp 90
            ret c
            ld (ix+O_TM),0
            ret
.p2:        ; phase 2: angry eyes, follow the player for 36 frames, then tongs
            ld a,(ix+O_TM)
            cp 1
            jr nz,.b1
            ld (ix+O_SPR),SPR_GRILL+2
            ld a,SFX_CREAK
            call sfx
.b1:        ld a,(ix+O_TM)
            cp 36
            jr nc,.b2
            ; line up the mouth (row +8) with the player
            bit 0,(ix+O_TM)
            jr z,.b2
            ld a,(p_y)
            sub 8
            cp 10+YOFF
            jr nc,.y1
            ld a,10+YOFF
.y1:        cp 34+YOFF
            jr c,.y2
            ld a,34+YOFF
.y2:        cp (ix+O_Y)
            jr z,.b2
            jr c,.yu
            inc (ix+O_Y)
            jr .b2
.yu:        dec (ix+O_Y)
.b2:        ld a,(ix+O_TM)
            cp 36
            jr c,.flash
            cp 40
            jr nz,.b3
            ld (ix+O_SPR),SPR_GRILL+1
            ld a,(ix+O_X)
            sub 10
            ld b,a
            ld a,(ix+O_Y)
            add a,8
            ld c,a
            ld a,T_TONGS
            push ix
            call spawn_obj
            pop ix
            ld a,SFX_WHIRR
            jp sfx
.flash:     cp 24
            ret c
            bit 1,a
            ret z
            set F_FLASH,(ix+O_FL)
            ret
.b3:        cp 80
            jr nz,.b4
            ld (ix+O_SPR),SPR_GRILL
            ld de,-$0160
            call .lob
            ld de,-$0220
            jp .lob
.b4:        cp 110
            ret c
            ld (ix+O_TM),0
            ret
.p3:        ; phase 3: lid off and flaming; wide bob, snag rain, pellet fans
            ld (ix+O_SPR),SPR_GRILL+2
            ld a,(ix+O_TM)
            and 63
            ld e,a
            ld d,0
            ld hl,sine16
            add hl,de
            ld a,(hl)
            sra a
            ld c,a
            ld a,(boss_base)
            add a,c
            ld (ix+O_Y),a
            ld a,(ix+O_TM)
            and 15
            jr nz,.c1
            ; a hot snag falls from the sky somewhere ahead of you
            call random
            and 63
            add a,20+XOFF
            ld b,a
            ld c,PF_TOP+YOFF
            ld a,T_HOTSNAG
            call .spawnk
            ret c
            ld hl,-$0030
            ld (iy+O_VX),l
            ld (iy+O_VX+1),h
            ld a,SFX_SIZZLE
            call sfx
.c1:        ld a,(ix+O_TM)
            and 63
            cp 32
            ret nz
            call .mouth
            push bc
            call fire_at
            pop bc
            push bc
            ld a,c
            sub 8
            ld c,a
            call fire_at
            pop bc
            ld a,c
            add a,8
            ld c,a
            jp fire_at
.bob4:      ld a,(ix+O_TM)
            add a,a
            and 63
            ld e,a
            ld d,0
            ld hl,sine16
            add hl,de
            ld a,(hl)
            sra a
            sra a
            ld c,a
            ld a,(boss_base)
            add a,c
            ld (ix+O_Y),a
            ret
.mouth:     ld a,(ix+O_X)
            ld b,a
            ld a,(ix+O_Y)
            add a,8
            ld c,a
            ret
; lob a hot snag from the mouth: DE = vx
.lob:       push de
            call .mouth
            ld a,T_HOTSNAG
            call .spawnk
            pop de
            ret c
            ld (iy+O_VX),e
            ld (iy+O_VX+1),d
            ld hl,-$0180
            ld (iy+O_VY),l
            ld (iy+O_VY+1),h
            ret
.spawnk:    push ix
            call spawn_obj
            push ix
            pop iy
            pop ix
            ret
.die:       ld b,90
            call boss_dying
            ret c
            ld b,(ix+O_X)
            ld c,(ix+O_Y)
            ld (ix+O_T),0
            ld a,8
            call coin_burst
            ; any tongs go too
            ld hl,objs
            ld b,NOBJ
.tg:        ld a,(hl)
            cp T_TONGS
            jr nz,.tn
            ld (hl),0
.tn:        ld de,OSZ
            add hl,de
            djnz .tg
            ld de,$1000
            call add_score
            xor a
            ld (boss_bar),a
            ld a,1
            ld (hud_dirty),a
            ld a,PH_CLEAR
            ld (stg_phase),a
            ld a,150
            ld (clear_t),a
            call clear_ebul
            ld hl,m_grilldn
            ld a,120
            call s1_msg
            ld hl,tune_clear
            jp music
m_gday:     db 10,"G'DAY, MATE!",0
m_grill:    db 3,"WARNING! THE GRILLFATHER",0
m_grilldn:  db 4,"SNAGGED HIM! +10000",0

; the tongs shoot out to the left edge, then snap back
tongs_ai:
            ld a,(ix+O_ST)
            or a
            jr nz,.back
            ld a,(ix+O_X)
            sub 3
            ld (ix+O_X),a
            cp 2+XOFF
            ret nc
            ld (ix+O_ST),1
            ld a,SFX_KNOCK
            jp sfx
.back:      ld a,(ix+O_X)
            add a,4
            ld (ix+O_X),a
            cp 80+XOFF
            ret c
            ld (ix+O_T),0
            ret

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
            dw GATE_COL+30 : db TL_SPAWN, T_TINNIE, 132+XOFF, 30+YOFF
            dw ROUTE_COL  : db TL_IFROUTE, 0 : dw .garden
            ; ---- ROOF: coin trails, possums, magpies
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
.garden:    dw 460 : db TL_SPAWN, T_GNOME, 132+XOFF, 48+GY
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
            dw PATIO_COL+8  : db TL_FORM, T_SNAG, 6, 30, 10, 2
            dw PATIO_COL+40 : db TL_CALL : dw boss_start
            dw PATIO_COL+40 : db TL_HOLD
            dw $7FFF : db TL_END
m_intro:    db 3,"SUNDAY ARVO IN THE BURBS...",0
m_wash:     db 8,"IT'S WASHING DAY!",0
m_gate:     db 1,"FLY HIGH: ROOF  LOW: GARDEN",0
m_patio:    db 4,"SMELLS LIKE A BARBIE...",0

; ---- scenery and sprites
            include "gen/s1scen.inc"
            include "gen/s1spr_rec.inc"
s1_end:
            assert s1_end <= STAGE_END
