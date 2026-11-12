; =====================================================================
;  ACTORS: the rogue mob, the station hands, explosions, pop-ups.
;   heeler    - runs Jo down, a step every few frames, quicker as the
;               wave goes on; a live pylon fries it
;   shearer   - keeps its distance, throws blades where Jo is heading
;   harvester - slow, four hits, knocked back by each; flattens hands
;   maggie    - a drone that swoops corner to corner, re-aiming at Jo
;   pylon     - stands still; touching it costs a charge cell
; =====================================================================
actors_update:
        ld iy,actors
        ld b,NACT
.l:     push bc
        ld a,(iy+A_T)
        or a
        call nz,actor_one
        call vschk
        ld de,ASZ
        add iy,de
        pop bc
        djnz .l
        ret

actor_one:
        cp T_BOOM
        jp z,act_boom
        cp T_POP
        jp z,act_pop
        ld b,a
        ld a,(state)
        or a
        ret nz                  ; only explosions move outside play
        ld a,b
        dec a
        jp z,act_heel
        dec a
        jp z,act_shear
        dec a
        jp z,act_harv
        dec a
        jp z,act_mag
        dec a
        jp z,hostile_touch
        jp act_human

; touching: C if actor IY overlaps Jo
touching:
        ld a,(px)
        sub (iy+A_X)
        add a,2
        cp 5
        ret nc
        ld a,(py)
        sub (iy+A_Y)
        add a,2
        cp 5
        ret

hostile_touch:
        ld a,(pinv)
        or a
        ret nz
        call touching
        ret nc
        jp player_hit

; move_actor: D, E = step (clamped to the paddock), sets the facing
move_actor:
        ld a,(iy+A_X)
        add a,d
        cp AX_MAX+1
        jr nc,.y
        ld (iy+A_X),a
.y:     ld a,(iy+A_Y)
        add a,e
        cp AY_MAX+1
        jr nc,.f
        ld (iy+A_Y),a
.f:     ld a,d
        or a
        ret z
        rlca
        and 1
        ld (iy+A_FACE),a
        ret

; towards: D, E = sign of (Jo - actor)
towards:
        ld a,(px)
        sub (iy+A_X)
        call sgn
        ld d,a
        ld a,(py)
        sub (iy+A_Y)
        call sgn
        ld e,a
        ret

; ---------------------------------------------------------------------
act_heel:
        dec (iy+A_TM)
        jr nz,.t
        ld a,(heel_per)
        ld (iy+A_TM),a
        call towards
        call random
        and 7
        jr nz,.mv
        ld b,3                  ; now and then a sidestep, so they spread out
        call rand_n
        dec a
        ld d,a
        ld b,3
        call rand_n
        dec a
        ld e,a
.mv:    call move_actor
        inc (iy+A_AN)
        call pylon_check
        jr nc,.t
        ld a,SFX_ZAP
        call play_sfx
        jp kill_actor
.t:     ld a,(pinv)
        or a
        ret nz
        call touching
        ret nc
        call player_hit
        jp kill_actor           ; it doesn't survive the bite

; pylon_check: C if heeler IY is on a live pylon
pylon_check:
        ld a,(w_pyl)
        or a
        ret z
        ld b,a
        ld ix,(pyl_ptr)
        ld de,ASZ
.l:     ld a,(ix+A_T)
        cp T_PYL
        jr nz,.n
        ld a,(iy+A_X)
        sub (ix+A_X)
        inc a
        cp 3
        jr nc,.n
        ld a,(iy+A_Y)
        sub (ix+A_Y)
        inc a
        cp 3
        ret c
.n:     add ix,de
        djnz .l
        or a
        ret

; ---------------------------------------------------------------------
act_shear:
        ld a,(iy+A_FL)
        or a
        jr z,.nf
        dec (iy+A_FL)
.nf:    dec (iy+A_TM)
        jr nz,.fire
        ld (iy+A_TM),6
        ld a,(px)
        sub (iy+A_X)
        ld d,a
        ld a,(py)
        sub (iy+A_Y)
        ld e,a
        call cheb
        cp 14
        jr c,.away
        cp 28
        jr nc,.near
        call random
        and 15
        call z,rand_dirs
        ld d,(iy+A_DX)
        ld e,(iy+A_DY)
        jr .mv
.away:  call towards
        ld a,d
        neg
        ld d,a
        ld a,e
        neg
        ld e,a
        jr .mv
.near:  call towards
.mv:    call move_actor
        inc (iy+A_AN)
.fire:  ld a,(shear_gap)
        or a
        jr z,.t
        dec (iy+A_AUX)
        jr nz,.t
        call throw_blade
        ld a,(shear_gap)
        ld b,a
        call random
        and 31
        add a,b
        ld (iy+A_AUX),a
.t:     jp hostile_touch

; ---------------------------------------------------------------------
act_harv:
        ld a,(iy+A_FL)
        or a
        jr z,.nf
        dec (iy+A_FL)
.nf:    dec (iy+A_TM)
        jr nz,.t
        ld (iy+A_TM),7
        call nearest_human
        jr nc,.h
        ld a,(px)
        ld d,a
        ld a,(py)
        ld e,a
.h:     ld a,d
        sub (iy+A_X)
        call sgn
        ld d,a
        ld a,e
        sub (iy+A_Y)
        call sgn
        ld e,a
        call move_actor
        inc (iy+A_AN)
        call crush_humans
.t:     jp hostile_touch

; nearest_human: D, E = the nearest station hand to IY (C: none left)
nearest_human:
        ld a,$FF
        ld (t_best),a
        ld ix,actors
        ld a,(w_hum)
        or a
        scf
        ret z
        ld b,a
.l:     ld a,(ix+A_T)
        cp T_HUMAN
        jr nz,.n
        ld a,(ix+A_X)
        sub (iy+A_X)
        call absa
        ld c,a
        ld a,(ix+A_Y)
        sub (iy+A_Y)
        call absa
        cp c
        jr nc,$+3
        ld a,c
        ld hl,t_best
        cp (hl)
        jr nc,.n
        ld (hl),a
        ld a,(ix+A_X)
        ld (t_tx),a
        ld a,(ix+A_Y)
        ld (t_ty),a
.n:     ld de,ASZ
        add ix,de
        djnz .l
        ld a,(t_best)
        cp $FF
        scf
        ret z
        ld a,(t_tx)
        ld d,a
        ld a,(t_ty)
        ld e,a
        or a
        ret

crush_humans:
        ld ix,actors
        ld a,(w_hum)
        or a
        ret z
        ld b,a
        ld de,ASZ
.l:     ld a,(ix+A_T)
        cp T_HUMAN
        jr nz,.n
        ld a,(ix+A_X)
        sub (iy+A_X)
        add a,2
        cp 5
        jr nc,.n
        ld a,(ix+A_Y)
        sub (iy+A_Y)
        add a,2
        cp 5
        jr nc,.n
        ld (ix+A_T),T_BOOM
        ld (ix+A_AUX),0
        ld (ix+A_COL),BGREEN
        ld a,SFX_LOST
        call play_sfx
.n:     add ix,de
        djnz .l
        ret

; ---------------------------------------------------------------------
act_mag:
        inc (iy+A_AN)
        dec (iy+A_TM)
        jr nz,.t
        ld (iy+A_TM),2
        dec (iy+A_AUX)
        jr nz,.m
        ld (iy+A_AUX),40        ; re-aim at Jo
        call towards
        ld a,d
        or a
        jr nz,$+4
        ld a,1
        ld (iy+A_DX),a
        ld a,e
        or a
        jr nz,$+4
        ld a,1
        ld (iy+A_DY),a
.m:     call bounce
        ld d,(iy+A_DX)
        ld e,(iy+A_DY)
        call move_actor
.t:     ld a,(pinv)
        or a
        ret nz
        call touching
        ret nc
        call player_hit
        jp kill_actor

; bounce: turn A_DX / A_DY round at the fence
bounce:
        ld a,(iy+A_X)
        add a,(iy+A_DX)
        cp AX_MAX+1
        jr c,.x
        ld a,(iy+A_DX)
        neg
        ld (iy+A_DX),a
.x:     ld a,(iy+A_Y)
        add a,(iy+A_DY)
        cp AY_MAX+1
        ret c
        ld a,(iy+A_DY)
        neg
        ld (iy+A_DY),a
        ret

; ---------------------------------------------------------------------
act_human:
        call touching
        jr c,rescue
        dec (iy+A_TM)
        ret nz
        ld (iy+A_TM),8
        dec (iy+A_AUX)
        jr nz,.m
        call random
        and 7
        add a,3
        ld (iy+A_AUX),a
        call rand_dirs
.m:     call bounce
        ld d,(iy+A_DX)
        ld e,(iy+A_DY)
        call move_actor
        inc (iy+A_AN)
        ret

rescue:
        ld a,(rescued)
        cp 5
        jr nc,$+3
        inc a
        ld (rescued),a
        ld b,a
        dec a
        ld (iy+A_HP),a          ; pop-up 1000 .. 5000
        ld (iy+A_T),T_POP
        ld (iy+A_AUX),0
        res 0,(iy+A_X)
        ld a,b
        rlca
        rlca
        rlca
        rlca
        ld d,a
        ld e,0
        call add_score
        ld a,SFX_RESCUE
        jp play_sfx

; ---------------------------------------------------------------------
act_boom:
        inc (iy+A_AUX)
        ld a,(iy+A_AUX)
        cp 9
        ret c
        ld (iy+A_T),0
        ret

act_pop:
        inc (iy+A_AUX)
        ld a,(iy+A_AUX)
        cp 40
        jr nc,.end
        and 7
        ret nz
        ld a,(iy+A_Y)
        or a
        ret z
        dec (iy+A_Y)
        ret
.end:   ld (iy+A_T),0
        ret

; =====================================================================
;  drawing (into the draw list of the hidden page)
; =====================================================================
draw_world:
        ld iy,actors
        ld b,NACT
.l:     push bc
        ld a,(iy+A_T)
        or a
        call nz,draw_actor
        call vschk
        ld de,ASZ
        add iy,de
        pop bc
        djnz .l
        call vschk
        call draw_player
        call draw_shots
        call draw_blades
        jp draw_message

draw_actor:
        ld d,(iy+A_X)
        ld e,(iy+A_Y)
        dec a
        jp z,.heel
        dec a
        jp z,.shear
        dec a
        jp z,.harv
        dec a
        jp z,.mag
        dec a
        jp z,.pyl
        dec a
        jp z,.hum
        dec a
        jp z,.boom
        ; pop-up
        ld a,(iy+A_AUX)
        and 4
        ld c,WHITE
        jr z,$+4
        ld c,YELLOW
        ld a,(iy+A_HP)
        add a,F_POP
        jp draw_sprite
.heel:  ld a,(iy+A_AN)
        and 1
        ld b,a
        ld a,(iy+A_FACE)
        add a,a
        add a,b
        add a,F_HEELER
        ld c,BRED
        jp draw_sprite
.shear: ld a,(iy+A_FL)
        or a
        ld a,F_SHEARER+2
        jr nz,.s2
        ld a,(iy+A_AN)
        and 1
        add a,F_SHEARER
.s2:    ld c,BMAGENTA
        jp draw_sprite
.harv:  ld a,(iy+A_AN)
        and 1
        add a,F_HARV
        ld c,YELLOW
        ld b,a
        ld a,(iy+A_FL)
        or a
        ld a,b
        jr z,$+4
        ld c,WHITE
        jp draw_sprite
.mag:   ld a,(iy+A_AN)
        rrca
        rrca
        and 1
        add a,F_MAGGIE
        ld c,BCYAN
        jp draw_sprite
.pyl:   ld a,(gtick)
        add a,d
        add a,e
        and 15
        cp 3
        ld a,F_PYLON
        ld c,BBLUE
        jr nc,.p1
        inc a
        ld c,BCYAN
.p1:    jp draw_sprite
.hum:   ld a,(iy+A_AN)
        and 1
        ld b,a
        ld a,(iy+A_HP)
        add a,a
        add a,b
        add a,F_HUMAN
        ld c,BGREEN
        jp draw_sprite
.boom:  ld a,(iy+A_AUX)
        ld b,F_BOOM
        cp 3
        jr c,.b1
        inc b
        cp 6
        jr c,.b1
        inc b
.b1:    ld a,b
        ld c,(iy+A_COL)
        jp draw_sprite

draw_player:
        ld a,(px)
        ld d,a
        ld a,(py)
        ld e,a
        ld a,(state)
        cp ST_DYING
        jr z,.dying
        cp ST_OVER
        ret z
        ld a,(pinv)
        and 2
        ret nz                  ; flickers while safe
        ld a,(pface)
        add a,a
        ld b,a
        ld a,(panim)
        rrca
        and 1
        add a,b
        add a,F_PLAYER
        ld c,WHITE
        jp draw_sprite
.dying: ld a,(stimer)
        cp 35
        ret c
        sub 35                  ; 15..0
        ld b,F_BOOM+2
        cp 5
        jr c,.d
        dec b
        cp 10
        jr c,.d
        dec b
.d:     ld a,b
        ld c,WHITE
        jp draw_sprite

draw_shots:
        ld ix,shots
        ld b,NSHOT
.l:     push bc
        ld a,(ix+0)
        or a
        jr z,.n
        ld d,(ix+1)
        ld e,(ix+2)
        call unit_addr
        add a,(ix+5)
        ld b,a
        ld c,WHITE
        call dl_cell
.n:     ld de,SSZ
        add ix,de
        pop bc
        djnz .l
        ret

draw_blades:
        ld ix,blades
        ld b,NBLADE
.l:     push bc
        ld a,(ix+0)
        or a
        jr z,.n
        ld d,(ix+2)
        ld e,(ix+4)
        call unit_addr
        ld b,a
        ld a,(ix+9)
        and 2
        add a,a
        add a,b
        add a,G_BOLT
        ld b,a
        ld c,BMAGENTA
        call dl_cell
.n:     ld de,BSZ
        add ix,de
        pop bc
        djnz .l
        ret

draw_message:
        ld a,(paused)
        or a
        jr z,.np
        ld hl,s_paused
        ld e,8
        ld c,WHITE
        jp draw_msg
.np:    ld a,(state)
        cp ST_INTRO
        jr z,.intro
        cp ST_CLEAR
        jr z,.clear
        cp ST_OVER
        ret nz
        ld hl,s_over
        ld e,8
        ld c,BRED
        call draw_msg
        ld a,(stimer)
        cp 125
        ret nc
        ld hl,s_again
        ld e,17
        ld c,WHITE
        jp draw_msg
.clear: ld hl,s_clear
        ld e,8
        ld c,BGREEN
        jp draw_msg
.intro: ld a,(respawned)
        or a
        jr z,.wv
        ld hl,s_ready
        ld e,8
        ld c,YELLOW
        jp draw_msg
.wv:    ld hl,s_wave            ; "WAVE nn" and a line about it
        ld de,msgbuf
        ld bc,5
        ldir
        ld a,(wave)
        ld b,$2F
.t:     inc b
        sub 10
        jr nc,.t
        add a,$3A
        ex de,hl
        ld (hl),b
        inc hl
        ld (hl),a
        inc hl
        ld (hl),0
        ld hl,msgbuf
        ld e,8
        ld c,YELLOW
        call draw_msg
        ld a,(wave)
        cp 11
        ld hl,s_wmore
        jr nc,.w2
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,wavetext
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
.w2:    ld e,17
        ld c,WHITE
        jp draw_msg
