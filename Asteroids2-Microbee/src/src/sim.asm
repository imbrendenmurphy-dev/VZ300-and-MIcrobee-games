; ===========================================================================
;  ASTEROIDS II - simulation bank (Microbee block 1, 0000-5FFF)
;  The original VZ300 game logic, unchanged apart from drawing/hardware,
;  plus an exporter that hands the renderer a display list every tick.
; ===========================================================================
        DEVICE NOSLOT64K
        ORG 0
        jp sim_init             ; 00
        jp sim_new_game         ; 03  A = 1 demo, 0 player
        jp sim_step             ; 06  one 25 Hz game tick + export
        jp sim_tick             ; 09  one 50 Hz sound/music tick + export SND
        jp mus_start_x          ; 0C
        jp mus_stop_x           ; 0F
        jp sfx_play_x           ; 12  A = effect
        jp sim_export           ; 15
        jp export_snd           ; 18

        INCLUDE "abi.inc"
        INCLUDE "sim-sprites.inc"
        INCLUDE "sim-hw.inc"
        INCLUDE "spr-ids.inc"

sim_init:
        ld hl,VARS : ld bc,512 : call clear_mem
        ld hl,OBJS : ld bc,OBJ_END-OBJS : call clear_mem
        ld hl,PARTS : ld bc,N_PART*PARTSZ : call clear_mem
        ld hl,PARTS : ld (part_next),hl
        ld hl,$ACE1 : ld (rnd_seed),hl
        ld hl,no_tick : ld (tick_hook),hl
        ld a,1 : ld (music_on),a
        call snd_off
        jp export_snd

sim_new_game:
        ld (demo_mode),a
        ld hl,OBJS : ld bc,OBJ_END-OBJS : call clear_mem
        ld hl,PARTS : ld bc,N_PART*PARTSZ : call clear_mem
        ld hl,PARTS : ld (part_next),hl
        xor a : ld (in_cur),a : ld (in_prev),a : ld (in_new),a
        ld (ST_DONE),a
        call new_game
        ld hl,sfx_tick : ld (tick_hook),hl
        jp sim_export

sim_step:
        ld hl,frame_ct : inc (hl)
        ld a,(game_over) : or a : jr z,.run
        ld hl,gover_tmr : ld a,(hl) : or a : jr z,.fin
        dec (hl) : jr nz,.run
.fin:   ld a,1 : ld (ST_DONE),a
.run:   call game_update
        ret

sim_tick:
        ld hl,(tick_hook) : jp (hl)
export_snd:
        ld hl,ch0 : ld de,SND : ld bc,3*CH_SIZE : ldir
        ret

mus_start_x:
        call mus_start : jr export_snd
mus_stop_x:
        call mus_stop : jr export_snd
sfx_play_x:                     ; front-end sounds: always audible
        push af : xor a : ld (demo_mode),a : pop af
        call sfx_play : jr export_snd

; ---------------------------------------------------------------------------
; display list export
; ---------------------------------------------------------------------------
; IX = object, A = sprite, C = colour, coordinates from O_XH/XL, O_YH/YL
emit:   push hl
        ld hl,DCOUNT : ld e,a : ld a,(hl) : cp DLIST_MAX : jr nc,.full
        inc (hl)
        ld a,e : ld (iy+3),a : ld (iy+4),c
        ; x = XH*4 + XL>>6 (0..511)
        ld a,(ix+O_XL) : rlca : rlca : and 3 : ld e,a
        ld l,(ix+O_XH) : ld h,0 : add hl,hl : add hl,hl
        ld a,l : or e : ld (iy+0),a : ld (iy+1),h
        ld a,(ix+O_YL) : rlca : rlca : and 3 : ld e,a
        ld a,(ix+O_YH) : add a,a : add a,a : or e
        ld hl,yoff_px : add a,(hl) : ld (iy+2),a
        ld de,5 : add iy,de
.full:  pop hl
        ret

; A = sprite, C = colour, D = x px lo, H = x px hi, E = y px  (absolute)
emit_xy:
        push af
        ld a,(DCOUNT) : cp DLIST_MAX : jr nc,.full
        inc a : ld (DCOUNT),a
        pop af
        ld (iy+3),a : ld (iy+4),c : ld (iy+0),d
        ld a,h : and 1 : ld (iy+1),a
        ld a,(yoff_px) : add a,e : ld (iy+2),a
        push de : ld de,5 : add iy,de : pop de
        ret
.full:  pop af
        ret

sim_export:
        xor a : ld (DCOUNT),a
        ld a,(draw_yoff) : add a,a : add a,a : ld (yoff_px),a
        ld iy,DLIST
        ; ---- rocks
        ld ix,OBJ_ROCK : ld b,N_ROCK
.rk:    ld a,(ix+O_TYPE) : or a : jr z,.rn
        ld a,(ix+O_AUX) : and 1 : jr nz,.rn           ; hit flash
        ld a,(ix+O_TYPE) : rrca : rrca : and 3
        ld e,a : ld d,0 : ld hl,rock_cols : add hl,de : ld c,(hl)
        ld a,(ix+O_SPR) : add a,(ix+O_FRM)
        push bc : call emit : pop bc
.rn:    ld a,b : and 3 : call z,fs_poll
        ld de,OBJSZ : add ix,de : djnz .rk
        ; ---- items (blink in the last 64 frames)
        ld ix,OBJ_ITEM : ld b,N_ITEM
.it:    ld a,(ix+O_TYPE) : or a : jr z,.in
        ld a,(ix+O_TMR) : cp 64 : jr nc,.vis
        ld a,(frame_ct) : and 2 : jr z,.in
.vis:   ld a,(ix+O_TYPE) : cp T_PICK : jr nc,.pick
        sub T_JEWEL : ld e,a : ld d,0 : ld hl,jewel_cols : add hl,de : ld c,(hl)
        add a,a : add a,a : ld e,a
        ld a,(ix+O_FRM) : rrca : rrca : and 3 : add a,e : add a,SPR_JEWEL_TOPAZ
        jr .idr
.pick:  sub T_PICK : add a,a : ld e,a
        ld a,(ix+O_FRM) : rrca : rrca : rrca : and 1
        ld c,15 : jr z,.pc : ld c,11
.pc:    add a,e : add a,SPR_PICK_SHIELD
.idr:   push bc : call emit : pop bc
.in:    ld de,OBJSZ : add ix,de : djnz .it
        ; ---- enemies
        ld ix,OBJ_ENEMY : ld b,N_ENEMY
.en:    ld a,(ix+O_TYPE) : or a : jr z,.enn
        sub $20 : and 3 : ld e,a : ld d,0 : ld hl,enemy_cols : add hl,de : ld c,(hl)
        ld a,(ix+O_TYPE) : cp T_STING : jr nz,.ens
        ld a,(ix+O_AUX) : add a,4 : rrca : rrca : rrca : and 7 : jr .edr
.ens:   ld a,(frame_ct) : rrca : and 1
.edr:   add a,(ix+O_SPR)
        push bc : call emit : pop bc
.enn:   ld de,OBJSZ : add ix,de : djnz .en
        ; ---- shockwave ring
        ld a,(ring_tmr) : or a : jr z,.nr
        ld b,SPR_RING : ld c,11
        cp 9 : jr nc,.r
        inc b : ld c,9
        cp 5 : jr nc,.r
        inc b : ld c,13
.r:     ld a,(ring_x) : ld l,a : ld h,0 : add hl,hl : add hl,hl : inc hl : inc hl
        ld d,l
        ld a,(ring_y) : add a,a : add a,a : add a,2 : ld e,a
        ld a,b : call emit_xy
.nr:    ; ---- ship, flame, shield
        ld ix,OBJ_SHIP
        ld a,(ship_state) : or a : jr nz,.ns
        ld a,(invuln) : and 2 : jr nz,.ns
        ld a,(thrusting) : or a : jr z,.nf
        ld a,(frame_ct) : and 1 : jr z,.nf
        ld a,(ship_ang) : add a,8 : rrca : rrca : rrca : rrca : and 15
        add a,a : ld c,a : ld a,(frame_ct) : rrca : and 1 : add a,c
        add a,SPR_FLAME : ld c,$9B : call emit
.nf:    ld a,(ship_ang) : add a,4 : rrca : rrca : rrca : and 31
        ld c,$0F : call emit
        ld a,(shield_hp) : or a : jr z,.ns
        ld a,(frame_ct) : rrca : and 1 : add a,SPR_SHIELD
        ld c,14 : call emit
.ns:    ; ---- score / pickup popup
        ld a,(popup_tmr) : or a : jr z,.np
        and 2 : ld c,11 : jr z,.ppc : ld c,9
.ppc:   ld a,(popup_x) : ld l,a : ld h,0 : add hl,hl : add hl,hl : inc hl : inc hl : inc hl
        ld a,(popup_y) : add a,a : add a,a : add a,5 : ld e,a
        ld ix,popup_txt : ld b,6
.pch:   ld a,(ix+0) : or a : jr z,.np
        push hl : push bc
        sub 32 : jr c,.psk
        cp 64 : jr nc,.psk
        push de : ld e,a : ld d,0 : push hl : ld hl,glyph_map : add hl,de : ld a,(hl) : pop hl : pop de
        or a : jr z,.psk
        ld d,l : call emit_xy
.psk:   pop bc : pop hl
        ld de,8 : add hl,de : ld a,(popup_y) : add a,a : add a,a : add a,5 : ld e,a
        inc ix : djnz .pch
.np:    ; ---- dots: particles and bullets
        xor a : ld (PCOUNT),a
        ld hl,PLIST : ld (dotp),hl
        ld a,(yoff_px) : ld (.yo+1),a
        ld hl,PARTS : ld de,PLIST : ld b,N_PART : ld c,0
.pl:    ld a,(hl) : or a : jr z,.pn
        push bc
        srl a : srl a : cp 4 : jr c,.age : ld a,3
.age:   ld c,a : inc hl : ld a,(hl) : and 7 : add a,a : add a,a : add a,c
        add a,low part_cols : ld c,a : ld a,high part_cols : adc a,0 : ld b,a
        ld a,(bc) : ld (.pcol+1),a
        inc hl : ld a,(hl) : rlca : and 1 : ld c,a      ; XL bit 7
        inc hl : ld a,(hl) : add a,a : or c : ld (de),a : inc de   ; x/2
        inc hl : ld a,(hl) : rlca : rlca : and 3 : ld c,a
        inc hl : ld a,(hl) : add a,a : add a,a : or c
.yo:    add a,0 : ld (de),a : inc de
.pcol:  ld a,0 : ld (de),a : inc de
        ld bc,PARTSZ-5 : add hl,bc
        pop bc : inc c
        jr .pt
.pn:    ld a,l : add a,PARTSZ : ld l,a : jr nc,.pt : inc h
.pt:    ld a,b : and 7 : call z,fs_poll
        djnz .pl
        ld (dotp),de : ld a,c : ld (PCOUNT),a
        call fs_poll
        ; bullets: a 4x2 head and a dot at pos - v/2 (the VZ drew two pixels)
        ld ix,OBJ_PBUL : ld b,N_PBUL+N_EBUL
.bl:    ld a,(ix+O_TYPE) : or a : jr z,.bn
        ld c,14
        cp T_PBUL : jr z,.bc
        ld c,13
        cp T_SHRAP : jr z,.bc
        ld c,9
.bc:    call obj_xy
        call emit_dot
        ; tail
        push bc
        ld l,(ix+O_XL) : ld h,(ix+O_XH)
        ld e,(ix+O_VXL) : ld d,(ix+O_VXH) : sra d : rr e
        or a : sbc hl,de
        ld a,h : and 127 : add a,a : bit 7,l : jr z,$+3 : inc a
        push af
        ld l,(ix+O_YL) : ld h,(ix+O_YH)
        ld c,(ix+O_VYL) : ld b,(ix+O_VYH) : sra b : rr c
        or a : sbc hl,bc
        ld a,l : rlca : rlca : and 3 : ld e,a
        ld a,h : add a,a : add a,a : or e : ld hl,yoff_px : add a,(hl) : ld e,a
        pop af
        pop bc : push bc
        call emit_dot
        pop bc
.bn:    ld a,b : and 3 : call z,fs_poll
           ld de,OBJSZ : add ix,de : djnz .bl
        call fs_poll
        ; ---- status for the HUD / front end
        ld hl,score : ld de,ST_SCORE : ld bc,3 : ldir
        ld a,(lives) : ld (ST_LIVES),a
        ld a,(wave_bcd) : ld (ST_WAVE),a
        ld a,(bombs) : ld (ST_BOMBS),a
        ld a,(game_over) : ld (ST_GOVER),a
        ld a,(shield_hp) : ld (ST_SHIELD),a
        ld a,(weapon) : ld (ST_WEAPON),a
        ld a,(weapon_tmr) : ld (ST_WTMR),a
        ld a,(demo_mode) : ld (ST_DEMO),a
        ld a,(frame_ct) : ld (ST_FRAME),a
        ld a,(chain_mul) : ld (ST_CHAIN),a
        ld hl,(OBJ_SHIP+O_VXL) : ld (ST_VX),hl
        ld hl,(OBJ_SHIP+O_VYL) : ld (ST_VY),hl
        ; banner: wave banners blink (original: banner_tmr & 4)
        xor a : ld (ST_BANNER),a
        ld a,(banner_tmr) : or a : jr z,.nb
        and 4 : jr z,.nb
        ld hl,(banner_ptr) : ld de,ST_BTEXT : ld bc,23 : ldir
        xor a : ld (de),a
        ld a,1 : ld (ST_BANNER),a
.nb:    ret

yoff_px: db 0
dotp:    dw PLIST
dot_c:   db 0
; IX = object/particle with XL,XH,YL,YH at +1..+4 (objects) -> A = x/2, E = y
obj_xy:
        ld a,(ix+O_XH) : add a,a : bit 7,(ix+O_XL) : jr z,$+3 : inc a
        push af
        ld a,(ix+O_YL) : rlca : rlca : and 3 : ld e,a
        ld a,(ix+O_YH) : add a,a : add a,a : or e
        ld hl,yoff_px : add a,(hl) : ld e,a
        pop af
        ret
; A = x/2, E = y, C = colour -> PLIST (keeps A, BC, DE)
emit_dot:
        push hl : push af
        ld a,(PCOUNT) : cp PLIST_MAX : jr nc,.full
        inc a : ld (PCOUNT),a
        ld hl,(dotp) : pop af : ld (hl),a : inc hl : ld (hl),e : inc hl : ld (hl),c : inc hl
        ld (dotp),hl
        pop hl : ret
.full:  pop af : pop hl : ret
; colour bytes: low nibble = top cell row, high nibble = cells below (shading)
rock_cols:  db $87,$3B,$19,$6E      ; stone grey, ore gold, volatile red, crystal cyan
jewel_cols: db 11,9,10             ; topaz, ruby, emerald
enemy_cols: db $5D,$09,$0B,$09      ; saucer, hunter, stinger, mine
; particle colours by class x age (dying .. fresh); 12 = bright blue fades
; into the background
part_cols:
        db 1,9,11,15            ; fire: dark red .. white hot
        db 8,8,7,15             ; rock debris
        db 6,14,15,15           ; sparks
        db 1,9,9,13             ; red
        db 5,13,11,15           ; gem sparkle
        db 4,12,14,14           ; exhaust
        db 7,7,7,7, 7,7,7,7

        INCLUDE "sim-glyphs.inc"
        INCLUDE "sim-ai.inc"
        INCLUDE "sim-music.inc"
        INCLUDE "sim-sound.inc"
jp_hl:  jp (hl)
no_tick:
        ret
fs_poll:
        jp $8003                ; engine vb_poll: count vertical blanks
        INCLUDE "sim-logic.inc"
        INCLUDE "sim-enemies.inc"
        INCLUDE "sim-data.inc"
        INCLUDE "sim-vars.inc"
        ASSERT $ < $6000
        SAVEBIN "../build/GAME.BNK",0,$
