; ---------------------------------------------------------------------------
; game.asm - ASTEROIDS II game logic
; ---------------------------------------------------------------------------
IN_LEFT   equ 1
IN_RIGHT  equ 2
IN_THRUST equ 4
IN_FIRE   equ 8
IN_HYPER  equ 16
IN_BOMB   equ 32
IN_START  equ 64

T_ROCK  equ $10         ; + rtype*4 + size
T_PBUL  equ $40
T_SHRAP equ $41         ; volatile-rock shrapnel: hits rocks, enemies and ship
T_EBUL  equ $48

RT_STONE equ 0
RT_ORE   equ 1
RT_VOLAT equ 2
RT_CRYST equ 3

; ---------------- utilities ----------------
; A = random byte (preserves HL, DE, BC)
rnd:    push hl
        ld hl,(rnd_seed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (rnd_seed),hl
        pop hl
        ret

; HL = sign-extended A
sext:   ld l,a
        rla
        sbc a,a
        ld h,a
        ret

; HL = HL >> 1 (arithmetic), B times
sra_hl: sra h
        rr l
        djnz sra_hl
        ret

; HL = signed A * B   (B small, >=1)
smul:   push de
        call sext
        ld d,h
        ld e,l
        dec b
        jr z,.x
.l:     add hl,de
        djnz .l
.x:     pop de
        ret

; A = |A| treating as signed
abs_a:  bit 7,a
        ret z
        neg
        ret

; clamp HL to +-DE (DE positive)
clamp_hl:
        bit 7,h
        jr nz,.neg
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ld h,d
        ld l,e
        ret
.neg:   push hl
        add hl,de
        pop hl
        ret c
        ld hl,0
        or a
        sbc hl,de
        ret

; add BCD points DE (D = hundreds+thousands... i.e. D=digits 3-4, E=digits 1-2) to score
add_score:
        ld a,(demo_mode)
        or a
        ret nz
        ld hl,score+2
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld hl,hud_dirty
        set 1,(hl)
        ; extra life every 10000 (score[0] holds the 10000s as BCD)
        ld a,(score)
        ld hl,next_life
        cp (hl)
        ret c
.award: ld a,(hl)
        add a,1
        daa
        ld (hl),a
        ld hl,hud_dirty
        set 0,(hl)
        ld a,(lives)
        cp 9
        jr nc,.nl
        inc a
        ld (lives),a
.nl:    ld a,SFX_LIFE
        call sfx_play
        ret

; ---------------- input ----------------
read_input:
        ld a,(demo_mode) : or a : jp nz,ai_input
        ld a,(INPUT_BITS) : ld c,a
set_input:
        ld a,(in_cur)
        ld (in_prev),a
        cpl
        and c
        ld (in_new),a
        ld a,c
        ld (in_cur),a
        ret

; detect joystick interface: Z clear (joy_ok=1) if it reads sanely
detect_joy: ret
move_obj:
        push ix
        pop hl
        inc hl                  ; HL -> O_XL
        ld d,h
        ld e,l
        inc de
        inc de
        inc de
        inc de                  ; DE -> O_VXL
        ld a,(de)
        add a,(hl)
        ld (hl),a
        inc hl
        inc de
        ld a,(de)
        adc a,(hl)
        and 127
        ld (hl),a
        inc hl
        inc de
        ld a,(de)
        add a,(hl)
        ld (hl),a
        inc hl
        inc de
        ld a,(de)
        adc a,(hl)
        call wrap_y
        ld (hl),a
        ret

; wrap A (row, possibly -1..-x or >=58) into 0..57
wrap_y: cp PF_ROWS
        ret c
        bit 7,a
        jr nz,.n
        sub PF_ROWS
        ret
.n:     add a,PF_ROWS
        ret

; find free slot: IX = pool, B = count -> IX = slot, Z clear if found (NZ), Z set if none
find_free:
        ld de,OBJSZ
.l:     ld a,(ix+O_TYPE)
        or a
        jr z,.f
        add ix,de
        djnz .l
        xor a                   ; Z = none
        ret
.f:     or 1                    ; NZ = found
        ret

; zero a pool: HL = start, BC = bytes
clear_mem:
        ld (hl),0
        dec bc
        ld a,b
        or c
        ret z
        ld d,h
        ld e,l
        inc de
        ldir
        ret

; ---------------- particles ----------------
; spawn: D = x, E = y, B = vx (1/16 px), C = vy (1/16 row), A = life; colour scheme (part_col)
; record: life, col, xl, xh, yl, yh, vxl, vxh, vyl, vyh
spawn_part:
        push hl
        push de
        ld hl,(part_next)
        ld (hl),a
        inc hl
        ld a,(part_col)
        ld (hl),a
        inc hl
        ld (hl),$80
        inc hl
        ld (hl),d
        inc hl
        ld (hl),$80
        inc hl
        ld (hl),e
        inc hl
        ex de,hl
        ld a,b
        call sext
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ex de,hl
        ld a,c
        call sext
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),0               ; addr: harmless until first update
        inc hl
        ld (hl),$7F
        inc hl
        ld (hl),0               ; val 0 -> no-op XOR
        inc hl
        ld de,PARTS_END
        or a
        sbc hl,de
        add hl,de
        jr c,.ok
        ld hl,PARTS
.ok:    ld (part_next),hl
        pop de
        pop hl
        ret

; burst: D = x, E = y, B = count, C = speed mask ($7F fast .. $0F slow), A = base life
; colour scheme in (part_col).  Velocities come from a precomputed table.
burst:  ld (burst_life),a
        ld a,c
        ld c,0
        cp $70
        jr nc,.sp
        inc c
        cp $30
        jr nc,.sp
        inc c
.sp:    ld a,c
        ld (burst_mask),a       ; shift count 0..2
.l:     push bc
        call fs_poll
        ld hl,burst_idx
        ld a,(hl)
        add a,4
        and 252
        ld (hl),a
        ld c,a                  ; index*4
        ld hl,(part_next)
        rrca
        rrca
        and 7
        push hl
        ld hl,burst_life
        add a,(hl)
        pop hl
        ld (hl),a               ; life
        inc hl
        ld a,(part_col)
        ld (hl),a
        inc hl
        ld (hl),$80
        inc hl
        ld (hl),d
        inc hl
        ld (hl),$80
        inc hl
        ld (hl),e
        inc hl
        push de
        push hl
        ld b,0
        ld hl,burst_tab
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld a,(burst_mask)
        or a
        jr z,.ns
.sh:    sra d
        rr e
        sra b
        rr c
        dec a
        jr nz,.sh
.ns:    pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld (hl),0
        inc hl
        ld (hl),$7F
        inc hl
        ld (hl),0
        inc hl
        ld de,PARTS_END
        or a
        sbc hl,de
        add hl,de
        jr c,.ok
        ld hl,PARTS
.ok:    ld (part_next),hl
        pop de
        pop bc
        djnz .l
        ret

        INCLUDE "sim-particles.inc"
init_stars: ret
update_stars: ret
PC_FIRE equ 0
PC_ROCK equ 1
PC_SPARK equ 2
PC_RED equ 3
PC_GEM equ 4
PC_EXH equ 5
rock_par:
        db SPR_ROCK_0_L, 7, 7, 5, 1, $00, $20, 5
        db SPR_ROCK_0_M, 7, 5, 4, 1, $00, $50, 4
        db SPR_ROCK_0_S, 3, 3, 3, 1, $01, $00, 3
        db 0,0,0,0,0,0,0,0
        db SPR_ROCK_1_L, 7, 7, 5, 3, $00, $50, 6
        db SPR_ROCK_1_M, 7, 5, 4, 2, $01, $00, 5
        db SPR_ROCK_1_S, 3, 3, 3, 1, $02, $00, 4
        db 0,0,0,0,0,0,0,0
        db SPR_ROCK_2_L, 7, 7, 5, 1, $00, $30, 4
        db SPR_ROCK_2_M, 7, 5, 4, 1, $00, $60, 3
        db SPR_ROCK_2_S, 3, 3, 3, 1, $01, $20, 2
        db 0,0,0,0,0,0,0,0
        db SPR_ROCK_3_L, 7, 7, 5, 1, $00, $40, 3
        db SPR_ROCK_3_M, 7, 5, 4, 1, $00, $80, 2
        db SPR_ROCK_3_S, 3, 3, 3, 1, $01, $60, 2
        db 0,0,0,0,0,0,0,0

; HL = &rock_par[type]  (A = object type)
rock_params:
        and $0F
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,rock_par
        add hl,de
        ret

; spawn rock from spawn_type/x/y/vx/vy. preserves IX, IY
spawn_rock:
        push ix
        ld ix,OBJ_ROCK
        ld b,N_ROCK
        call find_free
        jr z,.x
        ld a,(spawn_type)
        ld (ix+O_TYPE),a
        call rock_params
        ld a,(hl)
        ld (ix+O_SPR),a
        inc hl
        call rnd
        and (hl)
        ld (ix+O_FRM),a
        inc hl
        ld a,(hl)
        ld (ix+O_RX),a
        inc hl
        ld a,(hl)
        ld (ix+O_RY),a
        inc hl
        ld a,(hl)
        ld (ix+O_HP),a
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        ld (ix+O_TMR),a
        ld (ix+O_AUX),0
        call rnd
        and 1
        jr z,.d
        set 6,(ix+O_AUX)        ; spin direction
.d:     xor a
        ld (ix+O_XL),a
        ld (ix+O_YL),a
        ld a,(spawn_x)
        ld (ix+O_XH),a
        ld a,(spawn_y)
        ld (ix+O_YH),a
        ld hl,(spawn_vx)
        ld (ix+O_VXL),l
        ld (ix+O_VXH),h
        ld hl,(spawn_vy)
        ld (ix+O_VYL),l
        ld (ix+O_VYH),h
.x:     pop ix
        ret

; random velocity for a rock of size A (0=L) into spawn_vx/vy
rock_vel:
        ld c,a
        ld a,(level_speed)
        add a,c
        add a,c
        add a,2                 ; speed multiplier 2..9
        ld (tmp3),a
        call rnd
        and 63
        ld e,a
        ld d,0
        ld hl,sinx
        add hl,de
        ld a,(hl)
        ld hl,tmp3
        ld b,(hl)
        call smul
        ld b,2
        call sra_hl
        ld (spawn_vx),hl
        ld hl,cosy
        add hl,de
        ld a,(hl)
        ld hl,tmp3
        ld b,(hl)
        call smul
        ld b,2
        call sra_hl
        ld (spawn_vy),hl
        ret

update_rocks:
        xor a
        ld (rocks_alive),a
        ld ix,OBJ_ROCK
        ld b,N_ROCK
.l:     ld a,(ix+O_TYPE)
        or a
        jr z,.n
        push bc
        ld hl,rocks_alive
        inc (hl)
        call move_obj
        ; hit-flash countdown in AUX bits 0-3
        ld a,(ix+O_AUX)
        and $0F
        jr z,.nf
        dec (ix+O_AUX)
.nf:    dec (ix+O_TMR)
        jr nz,.na
        ld a,(ix+O_TYPE)
        call rock_params
        ld de,7
        add hl,de
        ld a,(hl)
        ld (ix+O_TMR),a
        ld de,-6
        add hl,de
        ld c,(hl)               ; frame mask
        ld a,(ix+O_FRM)
        bit 6,(ix+O_AUX)
        jr z,.fw
        dec a
        dec a
.fw:    inc a
        and c
        ld (ix+O_FRM),a
.na:    pop bc
.n:     ld de,OBJSZ
        add ix,de
        djnz .l
        ret

hit_rock:
        dec (iy+O_HP)
        jr z,rock_destroy
        ; armoured: flash and spark
        ld a,(iy+O_AUX)
        and $F0
        or 6
        ld (iy+O_AUX),a
        ld a,PC_SPARK
        ld (part_col),a
        ld d,(iy+O_XH)
        ld e,(iy+O_YH)
        ld b,4
        ld c,$1F
        ld a,3
        call burst
        ld a,SFX_CLINK
        jp sfx_play

rock_destroy:
        ld a,(iy+O_TYPE)
        ld (tmp3),a
        call rock_params
        push hl
        ld de,5
        add hl,de
        ld d,(hl)
        inc hl
        ld e,(hl)
        call add_score
        pop hl
        ld a,(iy+O_XH)
        ld (kill_x),a
        ld (spawn_x),a
        ld a,(iy+O_YH)
        ld (kill_y),a
        ld (spawn_y),a
        ld (iy+O_TYPE),0
        ; debris
        ld a,(tmp3)
        and 3
        ld c,a
        ld a,3
        sub c                   ; 3,2,1
        add a,a
        add a,a
        add a,2
        ld b,a
        ld a,PC_ROCK
        ld (part_col),a
        ld a,(kill_x)
        ld d,a
        ld a,(kill_y)
        ld e,a
        push bc
        ld c,$3F
        ld a,4
        call burst
        pop bc
        ld a,PC_FIRE
        ld (part_col),a
        srl b
        inc b
        ld c,$1F
        ld a,2
        call burst
        ; sound by size
        ld a,(tmp3)
        and 3
        add a,SFX_BOOM_L
        call sfx_play
        ; type specials
        ld a,(tmp3)
        rrca
        rrca
        and 3
        cp RT_ORE
        call z,ore_reward
        ld a,(tmp3)
        rrca
        rrca
        and 3
        cp RT_VOLAT
        call z,volatile_blast
        ; split
        ld a,(tmp3)
        and 3
        cp 2
        ret z                   ; small: gone
        inc a
        ld c,a                  ; child size
        ld a,(tmp3)
        and $FC
        or c
        ld (spawn_type),a
        ld b,2
        ld a,(tmp3)
        rrca
        rrca
        and 3
        cp RT_CRYST
        jr nz,.n2
        inc b
.n2:
.child: push bc
        ld a,(spawn_type)
        and 3
        call rock_vel
        ; add parent drift
        ld hl,(spawn_vx)
        ld e,(iy+O_VXL)
        ld d,(iy+O_VXH)
        add hl,de
        ld (spawn_vx),hl
        ld hl,(spawn_vy)
        ld e,(iy+O_VYL)
        ld d,(iy+O_VYH)
        add hl,de
        ld (spawn_vy),hl
        call spawn_rock
        pop bc
        djnz .child
        ret

; ---------------- bullets ----------------
; fire one bullet at angle A from the ship
fire_one:
        push af
        ld ix,OBJ_PBUL
        ld b,N_PBUL
        call find_free
        jr nz,.ok
        pop af
        ret
.ok:    pop af
        rrca
        rrca
        and 63
        ld e,a
        ld d,0
        ld hl,sinx
        add hl,de
        ld a,(hl)
        ld (tmp1),a
        ld hl,cosy
        add hl,de
        ld a,(hl)
        ld (tmp1+1),a
        ld (ix+O_TYPE),T_PBUL
        ld a,(weapon)
        cp 2
        ld a,12
        jr nz,.lf
        ld a,15
.lf:    ld (ix+O_TMR),a
        ; position = ship + dir*8 (nose)
        ld a,(tmp1)
        call sext
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(OBJ_SHIP+O_XL)
        add hl,de
        ld (ix+O_XL),l
        ld a,h
        and 127
        ld (ix+O_XH),a
        ld a,(tmp1+1)
        call sext
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(OBJ_SHIP+O_YL)
        add hl,de
        ld (ix+O_YL),l
        ld a,h
        call wrap_y
        ld (ix+O_YH),a
        ; velocity = dir*6 (+ half ship velocity)
        ld a,(tmp1)
        ld b,6
        call smul
        ex de,hl
        ld hl,(OBJ_SHIP+O_VXL)
        sra h
        rr l
        add hl,de
        ld (ix+O_VXL),l
        ld (ix+O_VXH),h
        ld a,(tmp1+1)
        ld b,6
        call smul
        ex de,hl
        ld hl,(OBJ_SHIP+O_VYL)
        sra h
        rr l
        add hl,de
        ld (ix+O_VYL),l
        ld (ix+O_VYH),h
        ret

update_bullets:
        ld ix,OBJ_PBUL
        ld b,N_PBUL+N_EBUL
.l:     ld a,(ix+O_TYPE)
        or a
        jr z,.n
        push bc
        call move_obj
        dec (ix+O_TMR)
        jr nz,.a
        ld (ix+O_TYPE),0
.a:     pop bc
.n:     ld de,OBJSZ
        add ix,de
        djnz .l
        ret

hit_test:
        ld a,(coll_x)
        sub (iy+O_XH)
        and 127
        cp 64
        jr c,.dx
        neg
        and 127
.dx:    ld c,a
        ld a,(coll_mx)
        add a,(iy+O_RX)
        cp c
        jr c,.miss
        jr z,.miss
        ld a,(coll_y)
        sub (iy+O_YH)
        jr nc,.dy
        neg
.dy:    cp PF_ROWS/2
        jr c,.dy2
        ld c,a
        ld a,PF_ROWS
        sub c
.dy2:   ld c,a
        ld a,(coll_my)
        add a,(iy+O_RY)
        cp c
        jr c,.miss
        jr z,.miss
        scf
        ret
.miss:  or a
        ret

coll_bullets_rocks:
        xor a
        ld (coll_mx),a
        ld (coll_my),a
        call cbr_make
        ld ix,OBJ_PBUL
        ld b,N_PBUL
.b:     ld a,(ix+O_TYPE)
        or a
        jr z,.nb
        ld a,(cbr_n)
        or a
        ret z                   ; no rocks left to hit
        ld a,(ix+O_XH)
        ld (coll_x),a
        ld a,(ix+O_YH)
        ld (coll_y),a
        push bc
        call fs_poll
        ld hl,cbr_list
        ld a,(cbr_n)
        ld b,a
.r:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld iyl,e
        ld iyh,d
        ld a,(coll_x)
        sub (iy+O_XH)
        and 127
        cp 64
        jr c,.px
        neg
        and 127
.px:    cp (iy+O_RX)
        jr nc,.nr               ; quick reject on x
        ; hit_test with zero margins (coll_mx = coll_my = 0): the x test
        ; above is its x test, so only its y test is left
        ld a,(coll_y)
        sub (iy+O_YH)
        jr nc,.dy
        neg
.dy:    cp PF_ROWS/2
        jr c,.dy2
        ld c,a
        ld a,PF_ROWS
        sub c
.dy2:   cp (iy+O_RY)
        jr nc,.nr
        ld (ix+O_TYPE),0        ; bullet spent
        push ix
        call hit_rock
        pop ix
        call cbr_make
        jr .done
.nr:    djnz .r
.done:  pop bc
.nb:    ld de,OBJSZ
        add ix,de
        djnz .b
        ret
cbr_make:
        ld hl,cbr_list
        ld de,OBJ_ROCK
        ld bc,N_ROCK*256
.m:     ld a,(de)
        or a
        jr z,.mn
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        inc c
.mn:    ld a,e
        add a,OBJSZ
        ld e,a
        jr nc,.mc
        inc d
.mc:    djnz .m
        ld a,c
        ld (cbr_n),a
        ret
cbr_n:  db 0
cbr_list: ds N_ROCK*2

; ship vs rocks
coll_ship_rocks:
        ld a,(ship_state)
        or a
        ret nz
        ld a,(OBJ_SHIP+O_XH)
        ld (coll_x),a
        ld a,(OBJ_SHIP+O_YH)
        ld (coll_y),a
        ld a,2
        ld (coll_mx),a
        ld a,1
        ld (coll_my),a
        ld iy,OBJ_ROCK
        ld b,N_ROCK
.r:     ld a,(iy+O_TYPE)
        or a
        jr z,.nr
        push bc
        call hit_test
        pop bc
        jr nc,.nr
        push bc
        call ship_hit_rock
        pop bc
        ld a,(ship_state)
        or a
        ret nz
.nr:    ld de,OBJSZ
        add iy,de
        djnz .r
        ret

; ship touched rock IY
ship_hit_rock:
        ld a,(invuln)
        or a
        ret nz
        ld a,(shield_hp)
        or a
        jr z,.die
        ; shield: rock takes the hit, shield loses one, rock bounces
        dec a
        ld (shield_hp),a
        ld a,25
        ld (invuln),a
        ld a,SFX_SHIELD
        call sfx_play
        ld hl,hud_dirty
        set 0,(hl)
        ld a,PC_SPARK
        ld (part_col),a
        ld a,(OBJ_SHIP+O_XH)
        ld d,a
        ld a,(OBJ_SHIP+O_YH)
        ld e,a
        ld b,8
        ld c,$3F
        ld a,4
        call burst
        ld (iy+O_HP),1
        jp rock_destroy
.die:   jp kill_ship

; ---------------- ship ----------------
reset_ship:
        ld hl,OBJ_SHIP
        ld bc,OBJSZ
        call clear_mem
        ld a,1
        ld (OBJ_SHIP+O_TYPE),a
        ld a,64
        ld (OBJ_SHIP+O_XH),a
        ld a,PF_ROWS/2
        ld (OBJ_SHIP+O_YH),a
        xor a
        ld (ship_ang),a
        ld (ship_state),a
        ld (thrusting),a
        ld a,50
        ld (invuln),a
        ret

kill_ship:
        ld a,1
        ld (ship_state),a
        ld a,45
        ld (ship_tmr),a
        xor a
        ld (shield_hp),a
        ld (weapon),a
        ld a,PC_FIRE
        ld (part_col),a
        ld a,(OBJ_SHIP+O_XH)
        ld d,a
        ld a,(OBJ_SHIP+O_YH)
        ld e,a
        push de
        ld b,20
        ld c,$7F
        ld a,8
        call burst
        pop de
        ld a,PC_SPARK
        ld (part_col),a
        ld b,10
        ld c,$3F
        ld a,10
        call burst
        ld a,6
        ld (flash_tmr),a
        ld a,8
        ld (shake),a
        ld a,SFX_DIE
        call sfx_play
        ld hl,lives
        ld a,(demo_mode)
        or a
        jr nz,.d
        dec (hl)
.d:     ld hl,hud_dirty
        set 0,(hl)
        ret

update_ship:
        ld a,(invuln)
        or a
        jr z,.ni
        dec a
        ld (invuln),a
.ni:    ld a,(hyper_cd)
        or a
        jr z,.nh
        dec a
        ld (hyper_cd),a
.nh:    ld a,(ship_state)
        or a
        jp nz,ship_special
        ; ---- rotation
        ld a,(in_cur)
        and IN_LEFT|IN_RIGHT
        jr z,.norot
        ld hl,ship_rot
        inc (hl)
        ld a,(hl)
        ld b,5
        cp 3
        jr c,.sp
        ld b,8
        cp 8
        jr c,.sp
        ld b,10
.sp:    ld a,(in_cur)
        and IN_LEFT
        ld a,(ship_ang)
        jr z,.rr
        sub b
        jr .rs
.rr:    add a,b
.rs:    ld (ship_ang),a
        jr .rot_done
.norot: xor a
        ld (ship_rot),a
.rot_done:
        ; ---- thrust
        xor a
        ld (thrusting),a
        ld a,(in_cur)
        and IN_THRUST
        jr z,.nothrust
        ld a,1
        ld (thrusting),a
        ld a,(ship_ang)
        rrca
        rrca
        and 63
        ld e,a
        ld d,0
        ld hl,sinx
        add hl,de
        ld a,(hl)
        push de
        call sext
        ld b,2
        call sra_hl
        ld de,(OBJ_SHIP+O_VXL)
        add hl,de
        ld (OBJ_SHIP+O_VXL),hl
        pop de
        ld hl,cosy
        add hl,de
        ld a,(hl)
        call sext
        ld b,2
        call sra_hl
        ld de,(OBJ_SHIP+O_VYL)
        add hl,de
        ld (OBJ_SHIP+O_VYL),hl
        call exhaust
        ld a,SFX_THRUST
        call sfx_play
.nothrust:
        ; ---- drag: v -= v/64
        ld hl,(OBJ_SHIP+O_VXL)
        push hl
        ld b,6
        call sra_hl
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld de,3*256
        call clamp_hl
        ld (OBJ_SHIP+O_VXL),hl
        ld hl,(OBJ_SHIP+O_VYL)
        push hl
        ld b,6
        call sra_hl
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld de,2*256
        call clamp_hl
        ld (OBJ_SHIP+O_VYL),hl
        ld ix,OBJ_SHIP
        call move_obj
        ; ---- fire
        ld a,(fire_cd)
        or a
        jr z,.cd0
        dec a
        ld (fire_cd),a
.cd0:   ld a,(in_new)
        and IN_FIRE
        jr z,.auto
        ld a,(fire_cd)
        cp 3
        jr c,.shoot
        jr .nofire
.auto:  ld a,(in_cur)
        and IN_FIRE
        jr z,.nofire
        ld a,(fire_cd)
        or a
        jr nz,.nofire
.shoot: call ship_fire
.nofire:
        ; ---- hyperspace
        ld a,(in_new)
        and IN_HYPER
        jr z,.nohyp
        ld a,(hyper_cd)
        or a
        jr nz,.nohyp
        call hyperspace
        ret
.nohyp: ; ---- smart bomb
        ld a,(in_new)
        and IN_BOMB
        ret z
        ld a,(bombs)
        or a
        ret z
        dec a
        ld (bombs),a
        jp smart_bomb

ship_fire:
        ld a,(weapon)
        cp 2
        ld b,5
        jr nz,.r
        ld b,2
.r:     ld a,b
        ld (fire_cd),a
        ; limit bullets: count live
        ld ix,OBJ_PBUL
        ld b,N_PBUL
        ld c,0
        ld de,OBJSZ
.c:     ld a,(ix+O_TYPE)
        cp T_PBUL
        jr nz,.c2
        inc c
.c2:    add ix,de
        djnz .c
        ld a,(weapon)
        ld b,5
        or a
        jr z,.lim
        ld b,10
.lim:   ld a,c
        cp b
        ret nc
        ld a,(ship_ang)
        call fire_one
        ld a,(weapon)
        cp 1
        jr nz,.snd
        ld a,(ship_ang)
        sub 14
        call fire_one
        ld a,(ship_ang)
        add a,14
        call fire_one
.snd:   ld a,SFX_SHOT
        jp sfx_play

; exhaust particles behind the ship
exhaust:
        ld a,(frame_ct)
        and 2
        ret z
        ld a,(ship_ang)
        add a,128
        rrca
        rrca
        and 63
        ld e,a
        ld d,0
        ld hl,sinx
        add hl,de
        ld a,(hl)
        sra a
        sra a
        sra a
        sra a
        sra a                   ; /32 -> offset px
        ld b,a
        ld a,(OBJ_SHIP+O_XH)
        add a,b
        and 127
        ld (tmp1),a
        ld hl,cosy
        add hl,de
        ld a,(hl)
        sra a
        sra a
        sra a
        sra a
        sra a
        ld c,a
        ld a,(OBJ_SHIP+O_YH)
        add a,c
        call wrap_y
        ld (tmp1+1),a
        ; velocity: backwards (sin/8 in 1/16 px units) + jitter
        ld hl,sinx
        add hl,de
        ld a,(hl)
        sra a
        sra a
        ld b,a
        call rnd
        and 7
        sub 4
        add a,b
        ld b,a
        ld hl,cosy
        add hl,de
        ld a,(hl)
        sra a
        sra a
        ld c,a
        ld a,PC_EXH
        ld (part_col),a
        ld a,(tmp1)
        ld d,a
        ld a,(tmp1+1)
        ld e,a
        call rnd
        and 3
        add a,5
        jp spawn_part

ship_special:
        cp 1
        jr nz,.s2
        ld hl,ship_tmr
        dec (hl)
        ret nz
        ld a,(lives)
        or a
        jr nz,.wait
        ld a,1
        ld (game_over),a
        ld a,120
        ld (gover_tmr),a
        ld a,4
        ld (ship_state),a
        ret
.wait:  ld a,2
        ld (ship_state),a
        ld a,100
        ld (ship_tmr),a
        ret
.s2:    cp 2
        jr nz,.s3
        ; wait for a clear centre (or time out)
        ld hl,ship_tmr
        dec (hl)
        jr z,.go
        ld a,64
        ld (coll_x),a
        ld a,PF_ROWS/2
        ld (coll_y),a
        ld a,12
        ld (coll_mx),a
        ld a,8
        ld (coll_my),a
        ld iy,OBJ_ROCK
        ld b,N_ROCK+N_ENEMY
.r:     ld a,(iy+O_TYPE)
        or a
        jr z,.nr
        push bc
        call hit_test
        pop bc
        ret c
.nr:    ld de,OBJSZ
        add iy,de
        djnz .r
.go:    call reset_ship
        ld a,SFX_SPAWN
        jp sfx_play
.s3:    cp 3
        ret nz
        ; hyperspace: reappear
        ld hl,ship_tmr
        dec (hl)
        ret nz
        xor a
        ld (ship_state),a
        ld a,12
        ld (invuln),a
        ld a,PC_GEM
        ld (part_col),a
        ld a,(OBJ_SHIP+O_XH)
        ld d,a
        ld a,(OBJ_SHIP+O_YH)
        ld e,a
        ld b,12
        ld c,$3F
        ld a,4
        jp burst

hyperspace:
        ld a,PC_GEM
        ld (part_col),a
        ld a,(OBJ_SHIP+O_XH)
        ld d,a
        ld a,(OBJ_SHIP+O_YH)
        ld e,a
        ld b,12
        ld c,$1F
        ld a,4
        call burst
        ld a,3
        ld (ship_state),a
        ld a,12
        ld (ship_tmr),a
        ld a,60
        ld (hyper_cd),a
        ; new random position, speed killed
        call rnd
        and 127
        ld (OBJ_SHIP+O_XH),a
.y:     call rnd
        and 63
        cp PF_ROWS
        jr nc,.y
        ld (OBJ_SHIP+O_YH),a
        ld hl,0
        ld (OBJ_SHIP+O_VXL),hl
        ld (OBJ_SHIP+O_VYL),hl
        ld a,SFX_HYPER
        jp sfx_play

; smart bomb: everything currently on screen takes a lethal hit
smart_bomb:
        ld a,8
        ld (flash_tmr),a
        ld a,10
        ld (shake),a
        ld a,SFX_BOMB
        call sfx_play
        ld hl,hud_dirty
        set 0,(hl)
        ; mark existing rocks
        ld ix,OBJ_ROCK
        ld b,N_ROCK
        ld de,OBJSZ
.m:     ld a,(ix+O_TYPE)
        or a
        jr z,.m2
        set 7,(ix+O_AUX)
.m2:    add ix,de
        djnz .m
        ld iy,OBJ_ROCK
        ld b,N_ROCK
.k:     ld a,(iy+O_TYPE)
        or a
        jr z,.k2
        bit 7,(iy+O_AUX)
        jr z,.k2
        push bc
        ld (iy+O_HP),1
        call rock_destroy
        pop bc
.k2:    ld de,OBJSZ
        add iy,de
        djnz .k
        ; enemies and their bullets
        call bomb_enemies
        ld hl,OBJ_EBUL
        ld bc,OBJSZ*N_EBUL
        call clear_mem
        ; shockwave rings from the ship
        ld a,12
        ld (ring_tmr),a
        ld a,(OBJ_SHIP+O_XH)
        ld (ring_x),a
        ld a,(OBJ_SHIP+O_YH)
        ld (ring_y),a
        ret

; ---------------- waves ----------------
start_wave:
        ld a,(wave)
        inc a
        cp 100
        jr c,.w
        ld a,99
.w:     ld (wave),a
        ld a,(wave_bcd)
        add a,1
        daa
        ld (wave_bcd),a
        ld hl,hud_dirty
        set 0,(hl)
        ; level speed bonus
        ld a,(wave)
        srl a
        srl a
        cp 3
        jr c,.ls
        ld a,3
.ls:    ld (level_speed),a
        ld a,(wave) : cp 3 : jr nc,.ls2
        ld a,$FF : ld (level_speed),a     ; slower rocks
.ls2:
        ; clear rocks, enemies, items, bullets
        ld hl,OBJ_ROCK
        ld bc,OBJ_END-OBJ_ROCK
        call clear_mem
        ; number of large rocks = 3 + wave (max 10)
        ld a,(wave)
        inc a
        cp 8
        jr c,.n
        ld a,7
.n:     ld b,a
.rl:    push bc
        call pick_rock_type
        add a,a
        add a,a
        or T_ROCK               ; size L
        ld (spawn_type),a
        ; position on an edge, away from the centre
        call rnd
        and 1
        jr z,.top
        call rnd
        and 15
        sub 8
        and 127
        ld (spawn_x),a
        call rnd
        and 31
        add a,13
        ld (spawn_y),a
        jr .pos
.top:   call rnd
        and 127
        ld (spawn_x),a
        call rnd
        and 7
        sub 4
        call wrap_y
        ld (spawn_y),a
.pos:   xor a
        call rock_vel
        call spawn_rock
        pop bc
        djnz .rl
        ; banner "WAVE nn"
        ld hl,txt_wave
        ld de,banner_buf
        ld bc,5
        ldir
        ld a,(wave_bcd)
        ex de,hl
        call bcd_to_str
        ld hl,banner_buf
        ld (banner_ptr),hl
        ld a,50
        ld (banner_tmr),a
        ld a,40
        ld (invuln),a
        call enemy_wave_init
        ; star drift changes direction each wave
        call rnd
        and 63
        ld e,a
        ld d,0
        ld hl,sinx
        add hl,de
        ld a,(hl)
        call sext
        ld b,4
        call sra_hl
        ld (star_vx),hl
        ld hl,cosy
        add hl,de
        ld a,(hl)
        call sext
        ld b,4
        call sra_hl
        ld (star_vy),hl
        ld a,SFX_WAVE
        jp sfx_play

; choose a rock type for the current wave
pick_rock_type:
        ld a,(wave)
        cp 2
        jr nc,.w2
        xor a
        ret
.w2:    ld c,a
        call rnd
        and 7
        cp 3
        jr nc,.stone            ; 5/8 stone
        ; special: 0..2 -> ore / crystal / volatile depending on wave
        ld b,a
        ld a,c
        cp 3
        jr nc,.w3
        ld a,RT_ORE
        ret
.w3:    ld a,b
        or a
        jr nz,.w3b
        ld a,RT_ORE
        ret
.w3b:   dec a
        jr nz,.w3c
        ld a,RT_CRYST
        ret
.w3c:   ld a,c
        cp 4
        ld a,RT_ORE
        ret c
        ld a,RT_VOLAT
        ret
.stone: xor a
        ret

; ---------------- heartbeat ----------------
heartbeat:
        ld hl,beat_tmr
        dec (hl)
        ret nz
        ; interval shrinks as rocks thin out: 4 + rocks_alive/2, max 22
        ld a,(rocks_alive)
        or a
        ret z
        srl a
        add a,6
        cp 22
        jr c,.i
        ld a,22
.i:     ld (hl),a
        ld hl,beat_alt
        ld a,(hl)
        xor 1
        ld (hl),a
        add a,SFX_BEAT1
        jp sfx_play

; ---------------- HUD ----------------
game_update:
        call read_input
        call update_ship
        call fs_poll
        call update_bullets
        call update_rocks
        call fs_poll
        call update_enemies
        call fs_poll
        call update_items
        call update_parts
        call fs_poll
        call coll_bullets_rocks
        call fs_poll
        call coll_bullets_enemies
        call coll_ship_rocks
        call fs_poll
        call coll_ship_enemies
        call coll_ship_items
        call heartbeat
        ; timers
        ld a,(banner_tmr)
        or a
        jr z,.nb
        dec a
        ld (banner_tmr),a
.nb:    ld a,(flash_tmr)
        or a
        jr z,.nf
        dec a
        ld (flash_tmr),a
.nf:    and 1
        rlca
        rlca
        rlca
        rlca
        or $08
        ld (latch_base),a
        ld a,(shake)
        or a
        jr z,.ns
        dec a
        ld (shake),a
        and 1
        jr z,.ns
        ld a,1
.ns:    ld (draw_yoff),a
        ld a,(ring_tmr)
        or a
        jr z,.nr
        dec a
        ld (ring_tmr),a
.nr:    ld a,(weapon_tmr)
        or a
        jr z,.nw
        dec a
        ld (weapon_tmr),a
        jr nz,.nw
        xor a
        ld (weapon),a
.nw:    ld a,(chain_tmr)
        or a
        jr z,.nc
        dec a
        ld (chain_tmr),a
        jr nz,.nc
        ld a,1
        ld (chain_mul),a
.nc:    ld a,(popup_tmr)
        or a
        jr z,.np
        dec a
        ld (popup_tmr),a
.np:    ; wave clear?
        ld a,(rocks_alive)
        or a
        ret nz
        ld a,(ship_state)
        cp 4
        ret z
        ld hl,wave_tmr
        inc (hl)
        ld a,(hl)
        cp 40
        ret c
        ld (hl),0
        jp start_wave

bcd_to_str:
        push af
        rrca
        rrca
        rrca
        rrca
        and $0F
        add a,'0'
        ld (hl),a
        inc hl
        pop af
        and $0F
        add a,'0'
        ld (hl),a
        inc hl
        ld (hl),0
        ret

; expanding shockwave ring (smart bomb / big kills)
new_game:
        call snd_off
        ld hl,score
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        ld a,3
        ld (lives),a
        ld a,2
        ld (bombs),a
        xor a
        ld (wave),a
        ld (wave_bcd),a
        ld (game_over),a
        ld (weapon),a
        ld (weapon_tmr),a
        ld (shield_hp),a
        ld (flash_tmr),a
        ld (shake),a
        ld (ring_tmr),a
        ld (popup_tmr),a
        ld (wave_tmr),a
        ld (hyper_cd),a
        ld (fire_cd),a
        ld (in_cur),a
        ld a,$01
        ld (next_life),a
        ld a,1
        ld (chain_mul),a
        ld a,10
        ld (beat_tmr),a
        ld hl,PARTS
        ld bc,PARTS_END-PARTS
        call clear_mem
        ld hl,PARTS
        ld (part_next),hl
        ld hl,hs_table
        ld de,hiscore
        ld bc,3
        ldir
        call reset_ship
        call init_stars
        call start_wave
        ld hl,hud_dirty
        set 0,(hl)
        ret

; run one game until game over (or attract timeout in demo). Returns.
