; ============================================================================
;  BOSS: the CROWN OF THORNS - a mechanical starfish over the atoll
;
;  A 28 x 18 armoured body with five arms rotating round it.  Each arm ends
;  in a turret (an enemy object, T_POD) that fires aimed shots in turn after a
;  glint.  The body shrugs shots off ("tink") until every arm is gone; then
;  the shell opens and the core (T_CORE) fires five-way spreads with gaps
;  to slip through.  Losing arms makes it spin faster and fire sooner.
;  ETAB slot 0 is the core, slots 1-5 the turrets.
; ============================================================================
BODY_W  equ 28

boss_init:
        ; clear the decks: no stragglers or bullets during the fight
        ld hl,ETAB
        ld de,ETAB+1
        ld bc,NEN*EOSIZE-1
        ld (hl),0
        ldir
        call clear_ebullets
        ld a,1
        ld (boss_ph),a
        ld a,34
        ld (bx),a
        ld a,0
        ld (by),a
        ld (bang),a
        ld (bvolley),a
        ld (bnext),a
        ld a,1
        ld (bspeed),a
        ld (bdir),a
        ld a,5
        ld (barms),a
        ld a,60
        ld (bfire_tm),a
        ; the core (armoured until the arms are gone)
        ld ix,ETAB
        ld (ix+EO_T),T_CORE
        ld (ix+EO_HP),60
        ld (ix+EO_W),24
        ld (ix+EO_H2),18
        ld (ix+EO_G),7
        ; five turrets
        ld b,5
.p:     ld de,EOSIZE
        add ix,de
        ld (ix+EO_T),T_POD
        ld (ix+EO_HP),14
        ld (ix+EO_W),7
        ld (ix+EO_H2),9
        ld (ix+EO_G),7
        djnz .p
        jp boss_place

; every frame: move, spin, place the parts, schedule fire
upd_boss:
        ld a,(boss_ph)
        or a
        ret z
        cp 4
        jp z,.dying
        cp 1
        jr nz,.fight
        ; arriving: drop in from above the screen
        ld a,(anim)
        and 1
        jr z,.sp
        ld hl,by
        inc (hl)
        ld a,(hl)
        cp 22
        jr c,.sp
        ld a,2
        ld (boss_ph),a
.sp:    ld hl,bang
        inc (hl)
        jp boss_place
.fight: ; sway left and right in 2-pixel steps
        ld hl,bsway
        inc (hl)
        ld a,(boss_ph)
        cp 3
        ld a,(hl)
        jr z,.fast
        and 3
        jr nz,.sw
.fast:  ld a,(bdir)
        add a,a
        ld b,a
        ld a,(bx)
        add a,b
        ld (bx),a
        cp 12
        jr c,.flip
        cp 50
        jr c,.sw
.flip:  ld a,(bdir)
        neg
        ld (bdir),a
.sw:    ld a,(bspeed)           ; spin
        ld b,a
        ld a,(bang)
        add a,b
        ld (bang),a
        call boss_place
        ; firing
        ld hl,bfire_tm
        dec (hl)
        ret nz
        ld a,(boss_ph)
        cp 3
        jr z,.cf
        ; next live turret glints, then fires (pod_fire)
        ld a,(barms)
        add a,a
        add a,a
        add a,a
        neg
        add a,50                ; 42 frames with five arms .. 18 with one
        ld (hl),a
        ld a,(bnext)
        ld c,a
        ld b,5
.nx:    ld a,c
        inc a
        cp 6
        jr c,$+4
        ld a,1
        ld c,a
        call slot_ix
        ld a,(ix+EO_T)
        cp T_POD
        jr z,.got
        djnz .nx
        ret
.got:   ld a,c
        ld (bnext),a
        ld (ix+EO_FC),10
        ret
.cf:    ld (hl),58              ; the core: a glint, then the spread
        ld ix,ETAB
        ld (ix+EO_FC),14
        ret
.dying: ld a,(anim)             ; explosions all over it
        and 3
        jr nz,.dd
        call rand
        and 31
        ld b,a
        ld a,(bx)
        add a,b
        sub 6
        jr nc,$+3
        xor a
        ld b,a
        call rand
        and 15
        ld c,a
        ld a,(by)
        add a,c
        ld c,a
        call add_expl
        ld a,(anim)
        and 15
        ld a,FX_BIGX
        call z,play_sfx
.dd:    ld hl,bdie_tm
        dec (hl)
        ret nz
        xor a
        ld (boss_ph),a
        ld a,3                  ; stage clear
        ld (mode),a
        ld (flash_tm),a
        ld hl,0
        ld (clear_tm),hl
        ld (mode_tm),hl
        call clear_ebullets
        ld hl,SONG_CLEAR
        jp play_song

; A = slot 0-5 -> IX
slot_ix:
        push de
        ld ix,ETAB
        or a
        jr z,.d
        ld de,EOSIZE
.l:     add ix,de
        dec a
        jr nz,.l
.d:     pop de
        ret

; put the core and the turrets where the body and the angle say
boss_place:
        ld ix,ETAB
        ld a,(bx)
        add a,2
        ld (ix+EO_X),a
        ld a,(by)
        inc a
        ld (ix+EO_Y),a
        ld c,0                  ; arm angle offset
        ld b,5
.l:     push bc
        ld de,EOSIZE
        add ix,de
        ld a,(bang)
        add a,c
        ld e,a
        ld d,0
        ld hl,PODDX
        add hl,de
        ld a,(bx)
        add a,14-3
        add a,(hl)
        ld (ix+EO_X),a
        ld hl,PODDY
        add hl,de
        ld a,(by)
        add a,9-3
        add a,(hl)
        ld (ix+EO_Y),a
        pop bc
        ld a,c
        add a,51
        ld c,a
        djnz .l
        ret

; a turret (IX) fires when its glint runs out
pod_fire:
        ld a,(ix+EO_FC)
        or a
        ret z
        dec (ix+EO_FC)
        ret nz
        ld a,(ix+EO_X)
        add a,2
        ld b,a
        ld a,(ix+EO_Y)
        add a,4
        ld c,a
        jp fire_at

; the core (IX): five-way spread, alternating sets
core_fire:
        ld a,(ix+EO_FC)
        or a
        ret z
        dec (ix+EO_FC)
        ret nz
        ld a,(ix+EO_X)
        add a,11
        and $FE
        ld b,a
        ld a,(ix+EO_Y)
        add a,12
        ld c,a
        ld hl,SPREAD
        ld a,(bvolley)
        xor 1
        ld (bvolley),a
        jr z,.a
        ld hl,SPREAD+20
.a:     ld a,5
; A = count, HL = table of (vx, vy), from (B, C)
spread_fire:
        push af
        push hl
        push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl                  ; HL = vx, DE = vy
        call add_ebullet
        pop bc
        pop hl
        ld de,4
        add hl,de
        pop af
        dec a
        jr nz,spread_fire
        ret

; a turret or the core has been destroyed (A = its type)
boss_part_killed:
        cp T_CORE
        jr z,.core
        ld hl,barms
        dec (hl)
        ld hl,bspeed
        inc (hl)
        ld a,(barms)
        or a
        ret nz
        ; all arms gone: the shell opens
        ld a,3
        ld (boss_ph),a
        ld (flash_tm),a
        ld a,40
        ld (bfire_tm),a
        ld a,FX_BURST
        jp play_sfx
.core:  ld de,$5000             ; 5,000 + 5,000
        call add_score
        ld a,4
        ld (boss_ph),a
        ld a,90
        ld (bdie_tm),a
        ld (flash_tm),a
        call clear_ebullets
        ld a,FX_DIE
        jp play_sfx

; arms (limb dots) and the body, before the turrets are drawn
boss_draw:
        ld a,(boss_ph)
        or a
        ret z
        cp 4
        jr nz,.limbs
        ld a,(anim)             ; dying: the body flickers
        and 2
        ret nz
        jr .body
.limbs: ld ix,ETAB
        ld b,5
.l:     push bc
        ld de,EOSIZE
        add ix,de
        ld a,(ix+EO_T)
        cp T_POD
        jr nz,.n
        ; a banded chain of four segments, 9/16 .. 15/16 of the way out
        ld a,(bx)
        add a,14
        ld (lb_cx),a
        ld a,(by)
        add a,9
        ld (lb_cy),a
        ld a,(ix+EO_X)
        add a,3
        ld hl,lb_cx
        sub (hl)
        ld (lb_dx),a
        ld a,(ix+EO_Y)
        add a,3
        ld hl,lb_cy
        sub (hl)
        ld (lb_dy),a
        ; offsets by shifts: 9/16 = 1/2+1/16, 11/16 = 1/2+1/8+1/16,
        ; 13/16 = 1-1/8-1/16, 15/16 = 1-1/16
        ld a,(lb_dx)
        ld hl,lb_x
        call lb_parts
        ld a,(lb_dy)
        ld hl,lb_y
        call lb_parts
        ld hl,lb_x+1            ; three segments (11/16 .. 15/16)
        ld de,lb_y+1
        ld b,3
.ld:    push bc
        ld a,(lb_cx)
        add a,(hl)
        and $FE
        ld b,a
        ld a,(de)
        push hl
        ld hl,lb_cy
        add a,(hl)
        pop hl
        ld c,a
        push hl
        push de
        ld a,(hl)               ; alternate red and yellow
        pop de
        push de
        ld e,$FF
        bit 0,l
        jr z,.lc
        ld e,$55
.lc:    call draw_dot
        pop de
        pop hl
        inc hl
        inc de
        pop bc
        djnz .ld
.n:     pop bc
        djnz .l
.body:  ld hl,SPR_BODY_C
        ld a,(boss_ph)
        cp 3
        jr c,.bd
        ld hl,SPR_BODY_O0
        ld a,(anim)
        and 4
        jr z,.f
        ld hl,SPR_BODY_O1
.f:     ld a,(ETAB+EO_FL)       ; hit: flicker between the two
        or a
        jr z,.bd
        ld a,(anim)
        and 1
        ld hl,SPR_BODY_O0
        jr z,.bd
        ld hl,SPR_BODY_O1
.bd:    ld a,(bx)
        ld b,a
        ld a,(by)
        add a,FBTOP-16
        ld c,a
        jp draw_spr

; A = d (signed) -> (HL..HL+3) = d*9/16, d*11/16, d*13/16, d*15/16
lb_parts:
        ld c,a                  ; d
        sra a
        ld b,a                  ; d/2
        sra a
        sra a
        ld d,a                  ; d/8
        sra a
        ld e,a                  ; d/16
        ld a,b
        add a,e
        ld (hl),a               ; 9/16
        inc hl
        add a,d
        ld (hl),a               ; 11/16
        inc hl
        ld a,c
        sub d
        sub e
        ld (hl),a               ; 13/16
        inc hl
        ld a,c
        sub e
        ld (hl),a               ; 15/16
        ret
