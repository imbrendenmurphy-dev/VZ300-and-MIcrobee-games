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
        IFDEF PROMO
        ld a,(ship_state)       ; promo capture build: AI plays a real game
        cp 4
        jp nz,ai_input
        ENDIF
        ld a,(demo_mode)
        or a
        jp nz,ai_input
        ld c,0
        ld a,(KBD+ROW6)
        cpl
        ld b,a
        bit 5,b
        jr z,$+4
        set 0,c                 ; U left
        bit 3,b
        jr z,$+4
        set 1,c                 ; I right
        bit 1,b
        jr z,$+4
        set 2,c                 ; O thrust
        bit 4,b
        jr z,$+4
        set 4,c                 ; P hyperspace
        bit 2,b
        jr z,$+4
        set 6,c                 ; RETURN start
        ld a,(KBD+ROW2)
        cpl
        ld b,a
        bit 4,b
        jr z,$+4
        set 3,c                 ; Z fire
        bit 0,b
        jr z,$+4
        set 5,c                 ; B bomb
        ld a,(KBD+ROW4)
        cpl
        bit 4,a
        jr z,$+4
        set 3,c                 ; SPACE fire
        ld a,(KBD+ROW3)
        cpl
        bit 4,a
        jr z,$+4
        set 6,c                 ; 1 start
        ld a,(joy_ok)
        or a
        jr z,.nojoy
        in a,($2C)
        cpl
        and $0F
        ld b,a
        and 3
        cp 3
        jr z,.jbad              ; up+down: impossible -> ignore
        ld a,b
        and $0C
        cp $0C
        jr z,.jbad
        bit 2,b
        jr z,$+4
        set 0,c
        bit 3,b
        jr z,$+4
        set 1,c
        bit 0,b
        jr z,$+4
        set 2,c
        bit 1,b
        jr z,$+4
        set 5,c                 ; down = smart bomb
.jbad:  in a,($2E)
        bit 4,a
        jr nz,$+4
        set 3,c                 ; fire
        in a,($2D)
        bit 4,a
        jr nz,$+4
        set 4,c                 ; arm = hyperspace
.nojoy:
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
detect_joy:
        xor a
        ld (joy_ok),a
        ld b,8
.l:     in a,($2C)
        and $0F
        ret z                   ; all directions "pressed" -> floating bus / none
        in a,($2E)
        and $1F
        ret z
        djnz .l
        ld a,1
        ld (joy_ok),a
        ret

; ---------------- objects ----------------
; move object IX by its velocity, wrapping
move_obj:
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        ld e,(ix+O_VXL)
        ld d,(ix+O_VXH)
        add hl,de
        ld (ix+O_XL),l
        ld a,h
        and 127
        ld (ix+O_XH),a
        ld l,(ix+O_YL)
        ld h,(ix+O_YH)
        ld e,(ix+O_VYL)
        ld d,(ix+O_VYH)
        add hl,de
        ld (ix+O_YL),l
        ld a,h
        call wrap_y
        ld (ix+O_YH),a
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

update_parts:
        ld hl,PARTS
        ld b,N_PART
.l:     ld a,(hl)
        or a
        jr z,.skip
        dec (hl)
        jr z,.skip
        push bc
        push hl
        ; colour from scheme and life
        srl a
        srl a
        cp 3
        jr c,.c
        ld a,3
.c:     ld c,a
        inc hl
        ld a,(hl)
        add a,a
        add a,a
        add a,c
        add a,part_pal & 255
        ld e,a
        adc a,part_pal / 256
        sub e
        ld d,a
        ld a,(de)
        ld (tmp1+1),a           ; colour pattern
        inc hl                  ; -> xl
        push hl
        ld de,4
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        ld (tmp1),a             ; vy hi
        pop hl
        ld a,(hl)
        add a,e
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        and 127
        ld (hl),a
        ld (tmp2),a             ; x
        inc hl
        ld a,(hl)
        add a,c
        ld (hl),a
        inc hl
        ld a,(tmp1)
        adc a,(hl)
        cp PF_ROWS
        jr c,.ok
        bit 7,a
        jr nz,.ng
        sub PF_ROWS
        jr .ok
.ng:    add a,PF_ROWS
.ok:    ld (hl),a
        ld e,a
        ld a,(tmp2)
        ld d,a
        push hl
        call pix_addr           ; HL = buffer byte, A = mask
        ex de,hl
        pop hl
        ld bc,5
        add hl,bc               ; -> addr field
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld c,a
        ld a,(tmp1+1)
        and c
        ld (hl),a
        pop hl
        pop bc
.skip:  ld de,PARTSZ
        add hl,de
        djnz .l
        ret

; HL = back-buffer byte for D = x, E = y ; A = pixel mask
pix_addr:
        ld a,e
        add a,a
        ld l,a
        ld h,ROWTAB/256
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,d
        rrca
        rrca
        and 31
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld a,d
        and 3
        add a,pixmask & 255
        ld e,a
        ld d,pixmask/256
        ld a,(de)
        ret

draw_parts:
        ld hl,PARTS
        ld b,N_PART
.l:     ld a,(hl)
        or a
        jr z,.skip
        push hl
        ld de,10
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(de)
        xor (hl)
        ld (de),a
        pop hl
.skip:  ld de,PARTSZ
        add hl,de
        djnz .l
        ret

; palettes (by life/4: 0 = dying ... 3 = fresh)
PC_FIRE  equ 0
PC_ROCK  equ 1
PC_SPARK equ 2
PC_RED   equ 3
PC_GEM   equ 4
PC_EXH   equ 5
part_pal:
        db COL_B, COL_R, COL_R, COL_Y   ; fire: yellow -> red -> blue
        db COL_B, COL_B, COL_B, COL_Y   ; rock debris
        db COL_Y, COL_Y, COL_R, COL_Y   ; sparks
        db COL_R, COL_R, COL_R, COL_R
        db COL_B, COL_Y, COL_R, COL_Y   ; gem sparkle
        db COL_B, COL_R, COL_Y, COL_Y   ; exhaust

; ---------------- stars ----------------
init_stars:
        ld ix,STARS
        ld b,N_STAR
.l:     call rnd
        ld (ix+0),a
        call rnd
        and 127
        ld (ix+1),a
        call rnd
        ld (ix+2),a
.y:     call rnd
        and 63
        cp PF_ROWS
        jr nc,.y
        ld (ix+3),a
        ld c,COL_B
        ld a,b
        cp 5
        jr nc,.cb
        ld c,COL_Y              ; nearest layer (last 4 stars) yellow
.cb:    ld (ix+5),c
        ld (ix+6),0
        ld (ix+7),$7F
        ld (ix+8),0
        ld de,9
        add ix,de
        djnz .l
        ret

; stars: 10 far (x1), 8 mid (x2), 6 near (x3) drift with star_v minus 1/8 ship v
update_stars:
        ld hl,(OBJ_SHIP+O_VXL)
        ld b,3
        call sra_hl
        ex de,hl
        ld hl,(star_vx)
        or a
        sbc hl,de
        ld (tmp1),hl
        ld hl,(OBJ_SHIP+O_VYL)
        ld b,3
        call sra_hl
        ex de,hl
        ld hl,(star_vy)
        or a
        sbc hl,de
        ld (tmp2),hl
        ; double step, half the layers per frame (alternating) - halves the cost
        ld hl,(tmp1)
        add hl,hl
        ld (tmp1),hl
        ld hl,(tmp2)
        add hl,hl
        ld (tmp2),hl
        ld a,(frame_ct)
        and 2
        jr nz,.odd
        ld hl,STARS
        ld a,8
        jp .grp
.odd:   ld hl,STARS+8*9
        ld a,6
        call .grp2
        ld a,4
        jp .grp3
.grp3:  push af
        ld de,(tmp1)
        ld bc,(tmp2)
        ex de,hl
        add hl,hl
        ex de,hl
        push hl
        ld h,b
        ld l,c
        add hl,hl
        ld b,h
        ld c,l
        pop hl
        ; DE,BC = 2d ; add d once more
        push hl
        ld hl,(tmp1)
        add hl,de
        ex de,hl
        ld hl,(tmp2)
        add hl,bc
        ld b,h
        ld c,l
        pop hl
        pop af
        jr .run
.grp2:  push af
        push hl
        ld hl,(tmp1)
        add hl,hl
        ex de,hl
        ld hl,(tmp2)
        add hl,hl
        ld b,h
        ld c,l
        pop hl
        pop af
        jr .run
.grp:   ld de,(tmp1)
        ld bc,(tmp2)
.run:   push af
        ld a,(hl)
        add a,e
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        and 127
        ld (hl),a
        ld (tmp3),a
        inc hl
        ld a,(hl)
        add a,c
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,b
        cp PF_ROWS
        jr c,.ok
        bit 7,a
        jr nz,.ng
        sub PF_ROWS
        jr .ok
.ng:    add a,PF_ROWS
.ok:    ld (hl),a
        ; cache buffer address + pixel value
        push bc
        push de
        push hl
        ld e,a
        ld a,(tmp3)
        ld d,a
        call pix_addr
        ex de,hl
        pop hl
        inc hl
        inc hl                  ; -> col
        and (hl)
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),a
        inc hl
        pop de
        pop bc
        pop af
        dec a
        jr nz,.run
        ret

draw_stars:
        ld hl,STARS+6
        ld b,N_STAR
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(de)
        xor (hl)
        ld (de),a
        ld de,7
        add hl,de
        djnz .l
        ret

; ---------------- rocks ----------------
; rock parameter table: index rtype*4+size, 8 bytes:
; spr, frame mask, rx+1, ry+1, hp, score BCD hi, score BCD lo, anim speed
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

draw_rocks:
        ld ix,OBJ_ROCK
        ld b,N_ROCK
.l:     ld a,(ix+O_TYPE)
        or a
        jr z,.n
        ld a,(ix+O_AUX)
        and 1
        jr nz,.n                ; hit flash: skip on odd counts
        push bc
        ld a,(ix+O_SPR)
        add a,(ix+O_FRM)
        ld d,(ix+O_XH)
        ld e,(ix+O_YH)
        call draw_obj_spr
        call fs_poll
        pop bc
.n:     ld de,OBJSZ
        add ix,de
        djnz .l
        ret

; draw sprite A at D,E applying screen shake offset
draw_obj_spr:
        push af
        ld a,(draw_yoff)
        add a,e
        call wrap_y
        ld e,a
        pop af
        jp draw_spr

; hit rock IY (bullet already removed). Destroys/splits it.
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

draw_bullets:
        ld ix,OBJ_PBUL
        ld b,N_PBUL+N_EBUL
.l:     ld a,(ix+O_TYPE)
        or a
        jr z,.n
        push bc
        ld c,COL_Y
        cp T_PBUL
        jr z,.c
        ld c,COL_R
.c:     ld a,c
        ld (tmp2),a
        ld d,(ix+O_XH)
        ld a,(draw_yoff)
        add a,(ix+O_YH)
        call wrap_y
        ld e,a
        call plot
        ; tail at pos - v/2
        ld l,(ix+O_XL)
        ld h,(ix+O_XH)
        ld e,(ix+O_VXL)
        ld d,(ix+O_VXH)
        sra d
        rr e
        or a
        sbc hl,de
        ld a,h
        and 127
        ld d,a
        ld l,(ix+O_YL)
        ld h,(ix+O_YH)
        ld c,(ix+O_VYL)
        ld b,(ix+O_VYH)
        sra b
        rr c
        or a
        sbc hl,bc
        ld a,(draw_yoff)
        add a,h
        call wrap_y
        ld e,a
        ld a,(tmp2)
        ld c,a
        call plot
        pop bc
.n:     ld de,OBJSZ
        add ix,de
        djnz .l
        ret

; ---------------- collisions ----------------
; test point (coll_x, coll_y) against object IY (RX/RY are half sizes +1).
; extra margin in coll_mx/coll_my.  Z clear (NZ) on hit... returns carry set on hit
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
.dy:    cp 30
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
        ld ix,OBJ_PBUL
        ld b,N_PBUL
.b:     ld a,(ix+O_TYPE)
        or a
        jr z,.nb
        ld a,(ix+O_XH)
        ld (coll_x),a
        ld a,(ix+O_YH)
        ld (coll_y),a
        push bc
        ld iy,OBJ_ROCK
        ld b,N_ROCK
.r:     ld a,(iy+O_TYPE)
        or a
        jr z,.nr
        ld a,(coll_x)
        sub (iy+O_XH)
        and 127
        cp 64
        jr c,.px
        neg
        and 127
.px:    cp (iy+O_RX)
        jr nc,.nr               ; quick reject on x
        push bc
        call hit_test
        pop bc
        jr nc,.nr
        ld (ix+O_TYPE),0        ; bullet spent
        push ix
        call hit_rock
        pop ix
        jr .done
.nr:    ld de,OBJSZ
        add iy,de
        djnz .r
.done:  pop bc
.nb:    ld de,OBJSZ
        add ix,de
        djnz .b
        ret

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
        ; clear rocks, enemies, items, bullets
        ld hl,OBJ_ROCK
        ld bc,OBJ_END-OBJ_ROCK
        call clear_mem
        ; number of large rocks = 3 + wave (max 10)
        ld a,(wave)
        add a,3
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
hud_update:
        ld hl,hud_dirty
        bit 0,(hl)
        jr nz,.full
        bit 1,(hl)
        ret z
        res 1,(hl)
        ld a,D_Y
        ld (txt_col),a
        ld hl,score
        ld de,VRAM+0
        jp print_bcd3
.full:  ld (hl),0
        ; clear HUD rows 0..5
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,32*5-1
        ld (hl),D_B
        ldir
        ld hl,VRAM+32*5
        ld b,32
.ln:    ld (hl),$22             ; thin blue dotted rule
        inc hl
        djnz .ln
        ; score
        ld a,D_Y
        ld (txt_col),a
        ld hl,score
        ld de,VRAM+0
        call print_bcd3
        ; lives as ship icons
        ld a,D_R
        ld (txt_col),a
        ld a,(lives)
        cp 6
        jr c,.lv
        ld a,5
.lv:    or a
        jr z,.nolv
        ld b,a
        ld de,VRAM+7
.li:    push bc
        ld hl,txt_shipicon
        call print_v
        pop bc
        djnz .li
.nolv:  ; wave
        ld a,D_G
        ld (txt_col),a
        ld hl,txt_w
        ld de,VRAM+13
        call print_v
        ld a,D_Y
        ld (txt_col),a
        ld a,(wave_bcd)
        ld de,VRAM+14
        call print_bcd1
        ; bombs
        ld a,D_R
        ld (txt_col),a
        ld a,(bombs)
        or a
        jr z,.nob
        cp 6
        jr c,.bb
        ld a,5
.bb:    ld b,a
        ld de,VRAM+17
.bi:    push bc
        ld hl,txt_bombicon
        call print_v
        pop bc
        djnz .bi
.nob:   ; shield strength
        ld a,(shield_hp)
        or a
        jr z,.nos
        ld b,a
        ld a,D_G
        ld (txt_col),a
        ld de,VRAM+23
.si:    push bc
        ld hl,txt_shieldicon
        call print_v
        pop bc
        djnz .si
.nos:   ; hi score (blue)
        ld a,D_G
        ld (txt_col),a
        ld hl,hiscore
        ld de,VRAM+26
        call print_bcd3
        ret

; print 3 BCD bytes at HL as 6 digits to VRAM DE
print_bcd3:
        ld b,3
.l:     ld a,(hl)
        push hl
        push bc
        call print_bcd1
        pop bc
        pop hl
        inc hl
        djnz .l
        ret

; print BCD byte A as 2 digits at DE (advances DE by 2)
print_bcd1:
        push af
        rrca
        rrca
        rrca
        rrca
        call .dig
        pop af
.dig:   and $0F
        add a,'0'
        ld (numbuf),a
        xor a
        ld (numbuf+1),a
        ld hl,numbuf
        jp print_v

; weapon timer bar in HUD row 5 (drawn each frame cheaply)
hud_weapon_bar:
        ld a,(weapon)
        or a
        ret z
        ld a,(weapon_tmr)
        srl a
        srl a
        srl a
        srl a
        srl a                   ; /32 -> 0..7
        inc a
        ld b,a
        ld hl,VRAM+32*5+20
        ld a,(weapon)
        cp 1
        ld c,D_R
        jr z,.l
        ld c,D_Y
.l:     ld (hl),c
        inc hl
        djnz .l
        ld (hl),$88
        ret

; ---------------- the frame ----------------
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
        ld hl,VRAM+32*5+20
        ld b,9
.wb:    ld (hl),$88
        inc hl
        djnz .wb
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

game_draw:
        call update_stars
        call fs_poll
        call clear_buf
        call fs_poll
        call draw_stars
        call draw_rocks
        call draw_items
        call fs_poll
        call draw_enemies
        call draw_bullets
        call fs_poll
        call draw_parts
        call fs_poll
        call draw_ring
        ; ship
        ld a,(ship_state)
        or a
        jr nz,.noship
        ld a,(invuln)
        and 2
        jr nz,.noship
        ld a,(ship_ang)
        add a,4
        rrca
        rrca
        rrca
        and 31
        add a,SPR_SHIP
        ld hl,OBJ_SHIP+O_XH
        ld d,(hl)
        ld hl,OBJ_SHIP+O_YH
        ld e,(hl)
        call draw_obj_spr
        ld a,(shield_hp)
        or a
        jr z,.noship
        ld a,(frame_ct)
        rrca
        and 1
        add a,SPR_SHIELD
        ld hl,OBJ_SHIP+O_XH
        ld d,(hl)
        ld hl,OBJ_SHIP+O_YH
        ld e,(hl)
        call draw_obj_spr
.noship:
        ; banner text
        ld a,(banner_tmr)
        or a
        jr z,.nb
        and 4
        jr z,.nb
        ld a,COL_Y
        ld (txt_col),a
        ld hl,(banner_ptr)
        call centre_col
        ld d,a
        ld e,PF_ROWS/2-8
        call print_buf
.nb:    ; score popup
        ld a,(popup_tmr)
        or a
        jr z,.np
        ld a,(popup_tmr)
        and 2
        ld a,COL_Y
        jr z,.pc
        ld a,COL_R
.pc:    ld (txt_col),a
        ld hl,popup_txt
        ld a,(popup_x)
        ld d,a
        ld a,(popup_y)
        ld e,a
        call print_buf
.np:    ; demo label
        ld a,(demo_mode)
        or a
        jr z,.nd
        ld a,(frame_ct)
        and 32
        jr z,.nd
        ld a,COL_R
        ld (txt_col),a
        ld hl,txt_demo
        call centre_col
        ld d,a
        ld e,PF_ROWS-6
        call print_buf
.nd:    ; game over
        ld a,(game_over)
        or a
        ret z
        ld a,COL_R
        ld (txt_col),a
        ld hl,txt_gameover
        call centre_col
        ld d,a
        ld e,PF_ROWS/2-3
        jp print_buf

; A (BCD) -> 2-char string at HL (0 terminated)
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
draw_ring:
        ld a,(ring_tmr)
        or a
        ret z
        cp 9
        ld b,SPR_RING
        jr nc,.r
        inc b
        cp 5
        jr nc,.r
        inc b
.r:     ld a,(ring_x)
        ld d,a
        ld a,(ring_y)
        ld e,a
        ld a,b
        jp draw_obj_spr

; ---------------- game entry ----------------
new_game:
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
play_game:
play_game_demo:
        call init_rowtab
        ld hl,sfx_tick
        ld (tick_hook),hl
        ld a,D_B
        call cls_vram
        call new_game
.loop:  ; copy on a field-sync edge every 2nd field; logic + draw share the budget
.w:     call wait_fs
        ld a,(field_ct)
        ld hl,next_copy
        sub (hl)
        jp m,.w                 ; not yet due (handles 8-bit wrap)
        ld a,(field_ct)
        add a,2
        ld (hl),a
        call copy_buf
        call hud_update
        call hud_weapon_bar
        call game_update
        call game_draw
        ld a,(demo_mode)
        or a
        jr z,.nd
        ; demo ends on any key/fire or timeout
        call any_key
        jr z,.nk
        scf
        ret
.nk:    ld hl,(attract_tmr)
        dec hl
        ld (attract_tmr),hl
        ld a,h
        or l
        ret z
.nd:    ld a,(game_over)
        or a
        jr z,.loop
        ld hl,gover_tmr
        dec (hl)
        jr nz,.loop
        or a
        ret

; NZ if any key or fire pressed (keyboard all rows or joystick fire)
any_key:
        ld a,(KBD)              ; all rows selected
        cpl
        and $3F
        ret nz
        ld a,(joy_ok)
        or a
        ret z
        in a,($2E)
        cpl
        and $10
        ret
