; =====================================================================
;  boss.asm : chapter bosses (2x2 / 3x3) and enemy projectiles
; =====================================================================
BOSSDEF EQU LVBUF+LV_BOSS
b_on:    db 0
b_x:     db 0
b_y:     db 0
b_hp:    db 0
b_max:   db 0
b_cd:    db 0
b_scd:   db 0
b_mcd:   db 0
b_flash: db 0
b_size:  db 0
b_seen:  db 0               ; intro shown this chapter

; called by enter_screen: activate the boss if alive and inside the window
boss_check:
        xor a
        ld (b_on),a
        ld a,(BOSSDEF+BD_ALIVE)
        or a
        ret z
        ld a,(wx)
        ld b,a
        ld a,(BOSSDEF+BD_X)
        sub b
        cp WINW
        ret nc
        ld a,(wy)
        ld b,a
        ld a,(BOSSDEF+BD_Y)
        sub b
        cp WINH
        ret nc
        ld a,1
        ld (b_on),a
        ld a,(BOSSDEF+BD_X)
        ld (b_x),a
        ld a,(BOSSDEF+BD_Y)
        ld (b_y),a
        ld a,(BOSSDEF+BD_HP)
        ld (b_hp),a
        ld (b_max),a
        ld a,(BOSSDEF+BD_SIZE)
        ld (b_size),a
        ld a,60
        ld (b_cd),a
        ld (b_scd),a
        ld a,(BOSSDEF+BD_MEVERY)
        ld (b_mcd),a
        xor a
        ld (b_flash),a
        ret

; HL = cell -> NZ if inside the boss footprint
boss_at:
        ld a,(b_on)
        or a
        ret z
        ld a,(b_size)
        ld c,a
        ld a,l
        and $7F
        ld b,a
        ld a,(b_x)
        ld e,a
        ld a,b
        sub e
        cp c
        jr nc,.no
        ld a,h
        sub MAPH
        ld b,a
        ld a,(b_y)
        ld e,a
        ld a,b
        sub e
        cp c
        jr nc,.no
        or 1
        ret
.no:    xor a
        ret

; A = damage to the boss
boss_hit:
        ld c,a
        ld a,(b_hp)
        sub c
        jr c,boss_die
        jr z,boss_die
        ld (b_hp),a
        ld a,8
        ld (b_flash),a
        ld hl,SFX_HIT
        call sfx
        jp draw_status_if

boss_die:
        xor a
        ld (b_on),a
        ld (b_hp),a
        ld (BOSSDEF+BD_ALIVE),a
        ; explode every footprint cell
        ld a,(b_y)
        add a,MAPH
        ld h,a
        ld a,(b_x)
        ld l,a
        ld a,(b_size)
        ld b,a
.r:     push bc
        push hl
        ld a,(b_size)
        ld b,a
.c:     push bc
        push hl
        call render_cell
        pop hl
        push hl
        ld c,0
        call burst
        pop hl
        inc l
        pop bc
        djnz .c
        pop hl
        inc h
        pop bc
        djnz .r
        ld a,(p_xp)
        add a,12
        ld (p_xp),a
        ; the seals fade
        ld a,(wy)
        add a,MAPH
        ld h,a
        ld c,WINH
.sr:    ld a,(wx)
        ld l,a
        ld b,WINW
.sc:    ld a,(hl)
        and $7F
        sub TL_SEAL
        cp 4
        jr nc,.ns
        ld (hl),TL_FLOOR2|$80
.ns:    inc l
        djnz .sc
        inc h
        dec c
        jr nz,.sr
        ld hl,(boom_addr)
        ld a,(b_x)
        ld l,a
        ld a,(b_y)
        add a,MAPH
        ld h,a
        inc l
        inc h
        ld (boom_addr),hl
        ld a,16
        ld (boom_t),a
        call relight
        ld hl,SFX_VICTORY
        call sfx
        ld hl,T_SEALS
        call show_msg
        ; back to the room's own music
        ld a,(scr_track)
        call music_play
        ret

; draw the boss footprint
boss_draw:
        ld a,(b_on)
        or a
        ret z
        ld a,(b_y)
        add a,MAPH
        ld h,a
        ld a,(b_x)
        ld l,a
        ; glyph table: frame by time
        ld a,(frame)
        and 16
        ld de,BOSSDEF+BD_GLY
        jr z,.f0
        ld de,BOSSDEF+BD_GLY+9
.f0:    ld b,3
.r:     push bc
        push hl
        ld b,3
.c:     push bc
        ld a,(de)
        inc de
        cp $80
        jr z,.n                 ; empty slot (2x2 boss)
        push de
        push hl
        ld c,a
        push bc
        call cell_vram
        pop bc
        jr c,.nv
        ld a,(b_flash)
        and 2
        ld a,c
        jr z,.pp
        ld a,G_FLASH
.pp:    ld (de),a
.nv:    pop hl
        pop de
.n:     inc l
        pop bc
        djnz .c
        pop hl
        inc h
        pop bc
        djnz .r
        ld hl,b_flash
        jp dec0

; erase the footprint (before a move)
boss_erase:
        ld a,(b_y)
        add a,MAPH
        ld h,a
        ld a,(b_x)
        ld l,a
        ld a,(b_size)
        ld b,a
.r:     push bc
        push hl
        ld a,(b_size)
        ld b,a
.c:     push bc
        push hl
        call render_cell
        pop hl
        inc l
        pop bc
        djnz .c
        pop hl
        inc h
        pop bc
        djnz .r
        ret

boss_logic:
        ld a,(b_on)
        or a
        ret z
        ld a,(p_dead)
        or a
        ret nz
        ; --- shooting
        ld hl,b_scd
        dec (hl)
        jr nz,.nos
        ld a,(BOSSDEF+BD_SHOT)
        ld (hl),a
        call boss_shoot
.nos:   ; --- minions (counter in 4-frame units)
        ld a,(BOSSDEF+BD_MINION)
        or a
        jr z,.nom
        ld a,(frame)
        and 3
        jr nz,.nom
        ld hl,b_mcd
        dec (hl)
        jr nz,.nom
        ld a,(BOSSDEF+BD_MEVERY)
        or a
        jr nz,.me
        ld a,90
.me:    ld (hl),a
        call boss_minion
.nom:   ; --- movement
        ld hl,b_cd
        dec (hl)
        ret nz
        ld a,(BOSSDEF+BD_SPEED)
        ld (hl),a
        ; toward the player: compare with the footprint centre
        ld a,(b_size)
        srl a
        ld c,a
        ld a,(b_x)
        add a,c
        ld b,a
        ld a,(p_x)
        sub b
        call sgn
        ld d,a
        ld a,(b_y)
        add a,c
        ld b,a
        ld a,(p_y)
        sub b
        call sgn
        ld e,a
        ; try the axis with the larger distance first
        push de
        ld a,(b_x)
        add a,c
        ld b,a
        ld a,(p_x)
        sub b
        call absa
        ld l,a
        ld a,(b_y)
        add a,c
        ld b,a
        ld a,(p_y)
        sub b
        call absa
        pop de
        cp l
        jr c,.hfirst
        push de
        ld d,0
        call boss_try
        pop de
        ret z
        ld e,0
        call boss_try
        ret z
        jr .side
.hfirst:
        push de
        ld e,0
        call boss_try
        pop de
        ret z
        ld d,0
        call boss_try
        ret z
.side:
        ; blocked: sidestep in a random direction
        call rnd
        and 3
        ld e,a
        ld d,0
        ld hl,DXT
        add hl,de
        ld a,(hl)
        ld hl,DYT
        add hl,de
        ld e,(hl)
        ld d,a
        jp boss_try

; D = dx, E = dy (one of them 0). Z if moved (or attacked)
boss_try:
        ld a,d
        or e
        jr nz,.go
        or 1
        ret
.go:    ld a,(b_x)
        add a,d
        ld (bt_x),a
        ld a,(b_y)
        add a,e
        ld (bt_y),a
        ; check every new footprint cell
        ld a,(bt_y)
        add a,MAPH
        ld h,a
        ld a,(bt_x)
        ld l,a
        ld a,(b_size)
        ld b,a
.r:     push bc
        push hl
        ld a,(b_size)
        ld b,a
.c:     push bc
        ; player there? -> strike
        push hl
        ld de,(p_addr)
        or a
        sbc hl,de
        pop hl
        jr nz,.np
        pop bc
        pop hl
        pop bc
        call p_hurt
        xor a
        ret
.np:    push hl
        call cell_vram
        pop hl
        jr c,.bad
        ld a,(hl)
        and $7F
        ld e,a
        ld d,TPROP>>8
        ld a,(de)
        bit 0,a
        jr z,.ok
        and $F0
        cp 7<<4                 ; the drowned king wades
        jr nz,.bad
.ok:    pop bc
        inc l
        djnz .c
        pop hl
        inc h
        pop bc
        djnz .r
        ; move
        call boss_erase
        ld a,(bt_x)
        ld (b_x),a
        ld a,(bt_y)
        ld (b_y),a
        xor a
        ret
.bad:   pop bc
        pop hl
        pop bc
        or 1
        ret
bt_x:   db 0
bt_y:   db 0

; fire at the player from the boss centre
boss_shoot:
        ld a,(b_size)
        srl a
        ld c,a
        ld a,(b_x)
        add a,c
        ld l,a
        ld a,(b_y)
        add a,c
        add a,MAPH
        ld h,a
        push hl
        ld a,(p_x)
        sub l
        call sgn
        ld d,a
        ld a,(p_y)
        add a,MAPH
        sub h
        call sgn
        ld e,a
        pop hl
        ld a,(BOSSDEF+BD_SHOTG)
        ld (es_g),a
        push hl
        push de
        call eshot
        pop de
        pop hl
        ld a,(BOSSDEF+BD_PAT)
        or a
        jr z,.done
        ; spread: rotate the direction 45 degrees both ways
        push hl
        push de
        call rot45
        call eshot
        pop de
        pop hl
        call rotm45
        call eshot
.done:  ld hl,SFX_SHOT
        jp sfx

; rotate (D,E) by +45 / -45 degrees in the 8-direction ring
rot45:  ld a,1
        jr rotk
rotm45: ld a,7
rotk:   push hl
        push af
        ; find index of (d,e)
        ld hl,RING8
        ld b,0
.f:     ld a,(hl)
        cp d
        jr nz,.n
        inc hl
        ld a,(hl)
        dec hl
        cp e
        jr z,.got
.n:     inc hl
        inc hl
        inc b
        ld a,b
        cp 8
        jr c,.f
        pop af
        pop hl
        ret
.got:   pop af
        add a,b
        and 7
        add a,a
        ld e,a
        ld d,0
        ld hl,RING8
        add hl,de
        ld d,(hl)
        inc hl
        ld e,(hl)
        pop hl
        ret
RING8:  db 1,0, 1,1, 0,1, -1,1, -1,0, -1,-1, 0,-1, 1,-1

; spawn a minion next to the boss
boss_minion:
        ; free slot?
        ld ix,ENTS
        ld b,MAXENT
.f:     ld a,(ix+E_TYPE)
        or a
        jr z,.slot
        ld de,8
        add ix,de
        djnz .f
        ret
.slot:  ; try cells around the footprint
        ld hl,RING8
        ld b,8
.t:     push bc
        push hl
        ld a,(b_size)
        srl a
        ld c,a
        ld a,(hl)
        ld d,a
        inc hl
        ld e,(hl)
        ; centre + dir * (size/2+1)
        ld a,c
        inc a
        ld b,a
        ld a,(b_x)
        add a,c
        push bc
.mx:    add a,d
        djnz .mx
        pop bc
        ld l,a
        ld a,(b_y)
        add a,c
.my:    add a,e
        djnz .my
        add a,MAPH
        ld h,a
        push hl
        call cell_vram
        pop hl
        jr c,.no
        ld a,(hl)
        and $7F
        ld e,a
        ld d,TPROP>>8
        ld a,(de)
        ld c,a
        ld a,(BOSSDEF+BD_MINION)
        cp E_EEL
        jr z,.eel
        bit 0,c
        jr nz,.no
        jr .put
.eel:   ld a,c
        and $F0
        cp 7<<4
        jr nz,.no
.put:   push hl
        push ix
        call find_ent
        pop ix
        pop hl
        jr nz,.no
        ld a,(BOSSDEF+BD_MINION)
        ld (ix+E_TYPE),a
        ld (ix+E_X),l
        ld a,h
        sub MAPH
        ld (ix+E_Y),a
        ld (ix+E_SPN),255
        ld (ix+E_CD),20
        ld (ix+E_FLASH),0
        ld (ix+E_ANIM),0
        ld a,(BOSSDEF+BD_MINION)
        ld e,a
        add a,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        ld hl,ETAB
        add hl,de
        ld a,(hl)
        ld (ix+E_HP),a
        pop hl
        pop bc
        ret
.no:    pop hl
        inc hl
        inc hl
        pop bc
        dec b
        jp nz,.t
        ret

; ---------------------------------------------------------------------
; enemy projectiles: 6 x (addr lo, addr hi, dx, dy, life, glyph)
; ---------------------------------------------------------------------
MAXES   EQU 6
ESHOTS: ds MAXES*6
es_g:   db 0
eshots_clear:
        ld hl,ESHOTS
        ld b,MAXES*6
.c:     ld (hl),0
        inc hl
        djnz .c
        ret

; HL = start cell, D = dx, E = dy, es_g = glyph
eshot:
        ld a,d
        or e
        ret z
        push hl
        ld hl,ESHOTS+4
        ld b,MAXES
.f:     ld a,(hl)
        or a
        jr z,.got
        push de
        ld de,6
        add hl,de
        pop de
        djnz .f
        pop hl
        ret
.got:   ld (hl),24              ; life
        inc hl
        ld a,(es_g)
        ld (hl),a
        dec hl
        dec hl
        ld (hl),e
        dec hl
        ld (hl),d
        dec hl
        pop de                  ; start cell
        ld (hl),d
        dec hl
        ld (hl),e
        ret

eshots_tick:
        ld a,(frame)
        and 1
        ret nz
        ld ix,ESHOTS
        ld b,MAXES
.l:     push bc
        ld a,(ix+4)
        or a
        jr z,.n
        ld l,(ix+0)
        ld h,(ix+1)
        push hl
        call boss_at            ; don't erase the boss footprint (start cell)
        pop hl
        call z,render_cell_hl
        dec (ix+4)
        jr z,.n
        ld a,l
        add a,(ix+2)
        ld l,a
        ld a,h
        add a,(ix+3)
        ld h,a
        ld (ix+0),l
        ld (ix+1),h
        ; hit the player?
        push hl
        ld de,(p_addr)
        or a
        sbc hl,de
        pop hl
        jr nz,.np
        ld (ix+4),0
        call p_hurt
        jr .n
.np:    ld a,(hl)
        and $40
        jr nz,.die
        push hl
        call boss_at
        pop hl
        jr nz,.n                ; inside the boss: fly on unseen
        call cell_vram
        jr c,.die
        ld a,(ix+5)
        ld (de),a
        jr .n
.die:   ld (ix+4),0
.n:     ld de,6
        add ix,de
        pop bc
        djnz .l
        ret
render_cell_hl:
        push hl
        call render_cell
        pop hl
        ret

; ---------------------------------------------------------------------
; boss introduction: the chapter's mode(1) portrait for 3 seconds
; ---------------------------------------------------------------------
boss_intro:
        ld a,(b_seen)
        or a
        ret nz
        ld a,1
        ld (b_seen),a
        ld a,(lbase)
        push af
        call bank1
        ld hl,(LB_PIC)
        call show_picture
        ld hl,SFX_ROAR
        call sfx
        ld b,120
.w:     push bc
        call wait_frame
        call sound_tick
        pop bc
        djnz .w
        pop af
        ld (lbase),a
        ld (LATCH),a
        ret

; HL = picture (bank 1): css byte + ZX0 2048 bytes -> mode(1) VRAM
show_picture:
        call bank1
        ld a,(hl)
        inc hl
        or a
        ld a,M1G
        jr z,.g
        ld a,M1W
.g:     ld (lbase),a
        ld (LATCH),a
        ld de,VRAM
        call dzx0
        jp bank0
