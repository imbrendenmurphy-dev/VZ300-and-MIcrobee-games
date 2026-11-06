; ============================================================================
;  STAGE 4 - THE SWAMP OF THE DAMNED: creature behaviours
; ============================================================================
S4_LOGIC: dw w4_lurker,w4_golem,w4_mozzie,w4_marsh,w4_vulture,w4_snapjaw,w4_toad

; Bog Lurker: surfaces, wades after the hero, sinks back into the muck and
; stalks him unseen before surfacing again
w4_lurker:
        ld a,(ix+13)
        or a
        jr z,.up
        ; submerged: creep toward the hero, then wait for him
        dec (ix+13)
        ld a,(ix+8)
        and 3
        ret nz
        ld a,14
        ld (obj_h),a
        call face_hero
        cp 8
        ret c
        call walk_blocked
        ret nz
        jp step2
.up:    ld a,(ix+12)
        or a
        jr nz,.sink
        ld a,(ix+1)
        cp 2
        jp c,o_zombie
        ld a,(ix+8)
        cp 110
        jp c,o_zombie
        ; start sinking
        ld (ix+12),1
        ld (ix+1),1
        ld (ix+8),14
        ret
.sink:  dec (ix+8)
        dec (ix+8)              ; the update loop adds one: net -1 a frame
        ret nz
        ld (ix+12),0
        ld (ix+1),0
        ld (ix+13),50           ; stays under for a while
        ret

; Mud Golem: slow and heavy, lobs balls of burning mud
w4_golem:
        ld a,(ix+1)
        or a
        jp nz,o_skel
        ld a,16
        ld (obj_h),a
        ld a,(ix+8)
        cp 110
        jr c,.walk
        call hero_dist
        cp 56
        jr nc,.walk
        ld (ix+8),0
        call face_hero
        ld a,-9
        ld l,0
        jp shoot
.walk:  ld a,(ix+8)
        and 7
        ret nz
        call face_hero
        call walk_blocked
        jp nz,turn
        jp step2

; Mega Mosquito: hovers a little way off, then darts straight at the hero
w4_mozzie:
        ld a,(ix+1)
        or a
        jr nz,.act
        call hero_dist
        cp 80
        ret nc
        ld (ix+1),1
        ret
.act:   cp 2
        jr z,.dash
        ld a,(hero_y)
        sub 6
        call toward_y
        call face_hero
        cp 30
        jr nc,.close
        call turn               ; too near: back off
        call step2
        call turn
        jr .t
.close: cp 36
        call nc,step2
.t:     ld a,(ix+8)
        cp 50
        ret c
        ld (ix+1),2
        ld (ix+8),0
        ld a,SFX_THROW_ID
        jp play_sfx
.dash:  call step2
        call step2
        ld a,(hero_y)
        add a,2
        call toward_y
        ld a,(ix+8)
        cp 18
        ret c
        ld (ix+1),1
        ld (ix+8),0
        ret

; Marsh Light: loops lazily around a point that drifts toward the hero.
; Follow it at your peril.
w4_marsh:
        ld a,(ix+8)
        and 15
        jr nz,.nf
        ld a,(ix+8)
        and 16
        jr nz,.away
        call face_hero
        jr .nf
.away:  call face_hero
        call turn
.nf:    ld a,(ix+8)
        and 1
        call z,step2
        call tri32
        ld b,a
        ld a,(hero_y)
        sub 14
        add a,b
        jp toward_y

; Bog Vulture: circles high above the hero, then drops like a stone
w4_vulture:
        ld a,(ix+1)
        or a
        jr nz,.act
        call hero_dist
        cp 60
        ret nc
        ld (ix+1),1
        ret
.act:   cp 2
        jr z,.drop
        cp 3
        jr z,.climb
        ld a,2
        call toward_y
        call face_hero
        cp 4
        jp nc,step2
        ld a,(ix+8)
        cp 40
        ret c
        ld (ix+1),2
        ld a,SFX_THROW_ID
        jp play_sfx
.drop:  ld a,(ix+4)
        add a,3
        ld (ix+4),a
        cp 42
        ret c
        ld (ix+1),3
        ret
.climb: dec (ix+4)
        ld a,(ix+4)
        cp 3
        ret nc
        ld (ix+1),1
        ld (ix+8),0
        ret

; Snapjaw (mini-boss): a swamp gator that charges along the ground
w4_snapjaw:
        ld a,10
        ld (obj_h),a
        call obj_phys
        ld a,(ix+1)
        or a
        jr nz,.act
        call hero_dist
        cp 80
        ret nc
        ld (ix+1),1
        ld (ix+8),0
        ld a,SFX_THUNDER_ID
        jp play_sfx
.act:   cp 2
        jr z,.charge
        call face_hero
        ld a,(ix+8)
        cp 30
        ret c
        ld (ix+1),2
        ld (ix+8),0
        ret
.charge:
        ld a,(ix+6)
        or a
        jr nz,.air
        call walk_blocked
        jr nz,.hop
        ld a,(hero_y)
        add a,6
        cp (ix+4)
        jr nc,.run
.hop:   ld (ix+6),-12           ; the hero is above: jump at him
        ret
.air:   call air_step
        jp air_step
.run:   call step2
        call step2
        ld a,(ix+8)
        cp 32
        ret c
        ld (ix+1),1
        ld (ix+8),0
        ret

; Spitting Toad: hops toward the hero and spits arcing slime when it lands
w4_toad:
        ld a,10
        ld (obj_h),a
        call obj_phys
        jr z,.ground
        jp air_step
.ground:
        ld a,(ix+12)
        or a
        jr z,.wait
        ld (ix+12),0            ; just landed: spit
        call hero_dist
        cp 72
        ret nc
        ld a,-8
        ld l,0
        jp shoot
.wait:  ld a,(ix+8)
        cp 50
        ret c
        ld (ix+8),0
        call face_hero
        cp 72
        ret nc
        ld (ix+6),-9
        ld (ix+12),1
        ret
