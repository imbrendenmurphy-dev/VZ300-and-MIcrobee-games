ai_input:
        ld c,0
        ld a,(ship_state)
        or a
        jp nz,set_input
        ; find nearest target (rocks + enemies)
        ld a,255
        ld (tmp2),a
        ld hl,0
        ld (tmp3),hl
        ld iy,OBJ_ROCK
        ld b,N_ROCK+N_ENEMY
.f:     ld a,(iy+O_TYPE)
        or a
        jr z,.nf
        push bc
        call vec_to_ship
        ld a,d
        call abs_a
        ld b,a
        ld a,e
        call abs_a
        ld c,a
        add a,a
        add a,c
        srl a
        add a,b                 ; ~distance
        jr c,.nf2
        ld hl,tmp2
        cp (hl)
        jr nc,.nf2
        ld (hl),a
        ld (tmp3),iy
.nf2:   pop bc
.nf:    ld de,OBJSZ
        add iy,de
        djnz .f
        ld c,0
        ld hl,(tmp3)
        ld a,h
        or l
        jr z,.done
        push hl
        pop iy
        ; danger: very close -> hyperspace (if allowed), else shoot
        ld a,(tmp2)
        cp 7
        jr nc,.far
        ld a,(hyper_cd)
        or a
        jr nz,.far
        ld a,(invuln)
        or a
        jr nz,.far
        ld c,IN_HYPER
        jr .done
.far:   call vec_to_ship        ; D,E = ship - target ; want target - ship
        ld a,d
        neg
        ld d,a
        ld (at_dx),a
        ld a,e
        neg
        ld e,a
        ld (at_dy),a
        call atan64             ; A = 0..63 angle to target
        ld b,a
        ld a,(ship_ang)
        rrca
        rrca
        and 63
        sub b
        and 63                  ; diff
        ld c,0
        cp 2
        jr c,.aim
        cp 62
        jr nc,.aim
        cp 32
        ld c,IN_LEFT
        jr c,.rot
        ld c,IN_RIGHT
.rot:   jr .thr
.aim:   ld c,0
        ld a,(tmp2)
        cp 60
        jr nc,.thr              ; too far: line up, don't waste shots
        ld c,IN_FIRE
        ld a,(frame_ct)
        and 2
        jr z,.thr
        ld c,0                  ; release so the fire is re-triggered
.thr:   ; thrust towards distant targets now and then
        ld a,(tmp2)
        cp 40
        jr c,.done
        ld a,(frame_ct)
        and 24
        jr nz,.done
        ld a,c
        or IN_THRUST
        ld c,a
.done:  jp set_input

