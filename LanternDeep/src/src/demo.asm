; =====================================================================
; THE LANTERN DEEP - the attract tour
; After the first clip (the Lanternless Way, DEMO_SCRIPT), the demo visits
; each region in turn: a scripted clip per room, played through the normal
; game with the bearer kept from harm, then back to the title.
; Clip: DB room, x, y, facing, items ; DW script (frames, input) pairs,
; 0 ends. Input bits: 1 up, 2 down, 4 left, 8 right, 10h strike, 20h fire.
; =====================================================================
DEMO_CLIPS:
            DB 7,57,11,DIR_UP,$02   : DW dm_colossus
            DB 10,31,12,DIR_RIGHT,$06 : DW dm_grotto
            DB 14,3,11,DIR_RIGHT,$0E : DW dm_magma
            DB 15,39,1,DIR_DOWN,$0E : DW dm_forge
            DB 19,12,11,DIR_RIGHT,$1E : DW dm_heart
N_CLIPS     EQU 5
demo_clip:  DB 0

; the next clip (or, after the last, the title)
demo_next:  ld a,(demo_clip) : cp N_CLIPS : jp nc,title_screen
            ld l,a : inc a : ld (demo_clip),a
            ld h,0 : ld e,l : ld d,h
            add hl,hl : add hl,de : add hl,hl : add hl,de    ; *7
            ld de,DEMO_CLIPS : add hl,de
            ld a,(hl) : ld (dn_room),a : inc hl
            ld b,(hl) : inc hl : ld c,(hl) : inc hl
            ld a,(hl) : ld (ENTS+16+EN_DIR),a : inc hl
            ld a,(hl) : ld (items),a : inc hl
            ld e,(hl) : inc hl : ld d,(hl)
            ld (demo_ptr),de
            ld a,(de) : ld (demo_cnt),a
            push bc
            call torch_select
            xor a : ld (fire_ent),a : ld (input),a : ld (prev_input),a
            ld a,(hp_max) : ld (hp),a
            ld ix,ENTS+16
            ld (ix+EN_AUX),0 : ld (ix+EN_FRAME),0
            ld a,C_WHT : ld (ix+EN_COL),a
            call player_glyph_nd
            pop bc
            ld a,(dn_room)
            jp enter_room
dn_room:    DB 0

dm_colossus: DB 30,0, 3,$10,16,0, 3,$10,16,0, 3,$10,30,0, 12,$04,10,0, 3,$01,10,0
            DB 3,$10,16,0, 3,$10,16,0, 12,$08,10,0, 3,$01,10,0, 3,$10,16,0
            DB 3,$10,40,0, 3,$20,60,0, 0
dm_grotto:  DB 30,0, 90,$08, 20,0, 8,$01, 40,0, 60,$08, 20,0, 3,$20, 60,0
            DB 8,$02, 30,0, 50,$08, 40,0, 0
dm_magma:   DB 30,0, 120,$08, 10,0, 3,$20, 50,0, 110,$08, 20,0
            DB 8,$02, 30,0, 0
dm_forge:   DB 30,0, 70,$02, 30,0, 10,$04, 30,0, 3,$20, 50,0
            DB 10,$08, 30,0, 0
dm_heart:   DB 40,0, 150,$08, 30,0, 8,$01, 20,0, 3,$20, 60,0
            DB 3,$10,20,0, 3,$10, 80,0, 0

; =====================================================================
; Lives: three. Falling costs one and wakes the bearer where the region
; began, with everything carried and every door, chest and boss as they
; were left. With none left the title returns; CONTINUE starts again at
; the region's start with three more.
; =====================================================================
lives:      DB 3
lives_check: ld a,(lives) : or a : ret nz
            ld a,3 : ld (lives),a
            ret
death_msg:  ld hl,msg_dead
            ld a,(lives) : cp 2 : jr nc,.m
            ld hl,msg_over
.m:         jp message
hud_lives:  ld hl,23*80+67 : ld a,S_P_DOWN0 : ld c,C_WHT : ld b,SPRITE_BANK : call put_glyph
            ld a,(lives) : add a,$90 : ld c,C_WHT : ld b,FONT_BANK
            jp put_glyph
lose_life:  ld a,(lives) : dec a : ld (lives),a
            push af
            ld a,(cur_region) : ld e,a : add a,a : add a,e : ld e,a : ld d,0
            ld hl,REGION_START : add hl,de
            ld a,(hl) : inc hl : ld b,(hl) : inc hl : ld c,(hl)
            ld (ck_room),a : ld (ck_xy),bc : ld (ll_room),a
            ld a,DIR_RIGHT : ld (ck_dir),a
            pop af
            jp z,to_title                   ; no lives left
            xor a : ld (dead),a : ld (fire_ent),a
            ld a,(hp_max) : ld (hp),a
            ld a,5 : ld (mp),a
            ld ix,ENTS+16
            ld (ix+EN_AUX),0
            ld a,C_WHT : ld (ix+EN_COL),a : ld (ix+EN_COL0),a
            ld a,DIR_RIGHT : ld (ix+EN_DIR),a
            call torch_select
            call player_glyph_nd
            ld a,(ll_room) : ld bc,(ck_xy)
            call enter_room
            ld hl,msg_wake : call message
            ld a,1 : ld (hud_dirty),a
            ret
ll_room:    DB 0
msg_over:   DB "THE LAST FLAME GOES OUT...",0
msg_wake:   DB "THE FLAME GUTTERS, BUT LIVES. YOU WAKE WHERE THIS REGION BEGAN.",0

; item messages (moved up here for room)
msg_key:    DB "THE IRON KEY! IT IS COLD AND HEAVY.",0
msg_lantern: DB "THE GLIMMER LANTERN! YOUR LIGHT REACHES FURTHER.",0
msg_blade:  DB "THE MOONSILVER BLADE! IT SINGS AGAINST STONE.",0
msg_ring:   DB "THE EMBER RING! FIRE WILL NOT HARM YOU NOW.",0
msg_potion: DB "A FLASK OF LIGHT. YOUR WOUNDS CLOSE.",0
msg_heart:  DB "A HEART CRYSTAL! YOUR LIFE GROWS STRONGER.",0

; the boot question (title.asm, monitor_ask)
t_mon1:     DB "THE LANTERN DEEP",0
t_mon2:     DB "WHICH MONITOR ARE YOU USING?",0
t_mon3:     DB "C  COLOUR         M  MONOCHROME",0
