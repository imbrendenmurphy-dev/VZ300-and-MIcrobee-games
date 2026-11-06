; ============================================================================
;  STAGE 5 - THE CRYSTAL DEEPS: creature behaviours
; ============================================================================
S5_LOGIC: dw w5_crawler,w5_gemknight,w5_cavebat,w5_shade,w5_shard,w5_glimmer,w5_eye

; Crystal Crawler: creeps along and fires crystal shards up both ways
w5_crawler:
        ld a,(ix+1)
        cp 2
        jp c,o_zombie
        ld a,(ix+8)
        cp 90
        jp c,o_zombie
        ld (ix+8),0
        call hero_dist
        cp 72
        ret nc
        ld a,-9
        ld l,0
        call shoot
        call turn
        ld a,-9
        ld l,0
        call shoot
        jp turn

; Gem Knight: marches up, then leaps at the hero sword-first
w5_gemknight:
        ld a,(ix+1)
        or a
        jp nz,o_skel
        ld a,16
        ld (obj_h),a
        call obj_phys
        jp nz,air_step
        ld a,(ix+8)
        and 15
        call z,face_hero
        call hero_dist
        cp 40
        jr nc,.walk
        ld a,(ix+8)
        cp 60
        jr c,.walk
        ld (ix+8),0
        call face_hero
        ld (ix+6),-12
        ld a,SFX_JUMP_ID
        jp play_sfx
.walk:  ld a,(ix+8)
        and 3
        ret nz
        call walk_blocked
        jp nz,turn
        jp step2

; Cave Bat: hangs from the roof until the hero walks underneath, then drops
; on him and flaps about in a zigzag
w5_cavebat:
        ld a,(ix+1)
        or a
        jr nz,.act
        ld (ix+10),0            ; folded wings
        call hero_dist
        cp 14
        ret nc
        ld (ix+1),1
        ld a,SFX_THROW_ID
        jp play_sfx
.act:   cp 1
        jr nz,.zig
        ld a,(ix+4)
        add a,3
        ld (ix+4),a
        ld b,a
        ld a,(hero_y)
        cp b
        ret nc
        ld (ix+1),2
        jp face_hero
.zig:   call step2
        ld a,(ix+8)
        and 15
        call z,face_hero
        call tri32
        ld b,a
        ld a,(hero_y)
        sub 6
        add a,b
        jp toward_y

; Shade: the hero's reflection. It moves the opposite way to him and
; copies his height
w5_shade:
        ld a,(ix+12)
        ld b,a
        ld a,(hero_x)
        ld (ix+12),a
        sub b                   ; hero dx this frame
        jr z,.still
        add a,8
        cp 16
        jr nc,.still            ; first frame / respawn
        sub 8
        neg
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
.still: ld a,(ix+8)
        and 3
        jr nz,.y
        call face_hero
        cp 6
        call nc,step2
.y:     ld a,(hero_y)
        jp toward_y

; Shard Sprite: a homing splinter of crystal that shatters after a while
w5_shard:
        ld a,(ix+1)
        or a
        jr nz,.act
        call hero_dist
        cp 64
        ret nc
        ld (ix+1),1
        ld (ix+8),0
        ret
.act:   ld a,(ix+8)
        cp 140
        jr nc,.die
        and 7
        call z,face_hero
        call step2
        ld a,(ix+8)
        and 1
        ret nz
        ld a,(hero_y)
        add a,4
        jp toward_y
.die:   ld (ix+0),0
        ld e,(ix+2)
        ld d,(ix+3)
        ld a,(ix+4)
        ld b,6
        push af
        ld a,(col_yel)
        ld c,a
        pop af
        jp part_burst

; Glimmer Imp (mini-boss): the stage 1 imp's tricks plus a three-way spray
w5_glimmer:
        call o_imp
        ld a,(ix+1)
        cp 1
        ret nz
        ld a,(ix+8)
        cp 30
        ret nz
        ld l,0
        ld a,-6
        call shoot
        ld l,0
        xor a
        call shoot
        ld l,0
        ld a,6
        jp shoot

; Crystal Eye: watches, then fires aimed bolts in pairs
w5_eye:
        call face_hero
        cp 80
        ret nc
        ld a,(ix+8)
        cp 64
        jr z,.f
        cp 72
        ret c
        ld (ix+8),0
.f:     xor a
        ld l,1
        jp shoot
