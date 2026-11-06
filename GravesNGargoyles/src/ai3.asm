; ============================================================================
;  STAGE 3 - THE DROWNED VILLAGE: creature behaviours
; ============================================================================
S3_LOGIC: dw w3_sailor,w3_pirate,w3_gull,w3_lantern,w3_storm,w3_seahag,w3_spout

; Drowned Sailor: shambles like a zombie and hurls his harpoon
w3_sailor:
        ld a,(ix+1)
        cp 2
        jp c,o_zombie
        ld a,(ix+8)
        cp 100
        jp c,o_zombie
        call hero_dist
        cp 64
        jp nc,o_zombie
        ld (ix+8),0
        call face_hero
        xor a
        ld l,a
        jp shoot

; Pirate Bones: runs at you and leaps over anything in the way
w3_pirate:
        ld a,(ix+1)
        or a
        jp nz,o_skel
        ld a,16
        ld (obj_h),a
        call obj_phys
        jp nz,air_step
        ld a,(ix+8)
        and 31
        call z,face_hero
        ld a,(ix+8)
        and 1
        ret nz
        call walk_blocked
        jr nz,.jump
        ld a,(ix+8)
        and 63
        cp 40
        jp nz,step2
.jump:  ld (ix+6),-11
        ret

; Gull Ghoul: screams in from the side in a wave, straight past the hero
w3_gull:
        ld a,(ix+1)
        or a
        jr nz,.fly
        call hero_dist
        cp 96
        ret nc
        ld (ix+1),1
        call face_hero
        ld a,(ix+4)
        ld (ix+12),a
        ret
.fly:   call step2
        ld a,(ix+8)
        and 1
        call z,step2
        call tri32
        add a,(ix+12)
        ld (ix+4),a
        ret

; Lantern Ghost: hangs in the air bobbing, drifting closer, throwing flames
w3_lantern:
        ld a,(ix+12)
        or a
        jr nz,.go
        ld a,(ix+4)
        inc a
        ld (ix+12),a            ; base height (+1 so it is never 0)
.go:    ld a,(ix+8)
        and 3
        jr nz,.nb
        call face_hero
        cp 20
        call nc,step2
.nb:    ld a,(ix+10)
        and 31
        cp 16
        ld a,(ix+12)
        jr c,.u
        add a,2
.u:     dec a
        ld (ix+4),a
        ld a,(ix+8)
        cp 90
        ret c
        ld (ix+8),0
        call hero_dist
        cp 80
        ret nc
        xor a
        ld l,1
        jp shoot

; Storm Crow: climbs above the hero and drops lightning bolts
w3_storm:
        ld a,(ix+1)
        or a
        jr nz,.act
        call hero_dist
        cp 64
        ret nc
        ld (ix+1),1
        ld a,SFX_THROW_ID
        jp play_sfx
.act:   ld a,4
        call toward_y
        call face_hero
        cp 6
        jr c,.over
        jp step2
.over:  ld a,(ix+8)
        cp 40
        ret c
        ld (ix+8),0
        xor a
        ld l,a
        call shoot
        ret z
        ld (iy+5),0
        ld (iy+6),14
        ld a,SFX_THUNDER_ID
        jp play_sfx

; The Sea Hag (mini-boss): sinks out of sight and rises again beside the
; hero, throwing a pair of aimed hexes
w3_seahag:
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
.act:   bit 7,a
        jr nz,.hidden
        call face_hero
        ld a,(hero_y)
        sub 8
        call toward_y
        ld a,(ix+8)
        cp 30
        jr nz,.n1
        ld a,-4
        ld l,1
        call shoot
        ld a,4
        ld l,1
        jp shoot
.n1:    cp 70
        ret c
        ld (ix+1),$81           ; vanish
        ld (ix+8),0
        ld a,SFX_THUNDER_ID
        jp play_sfx
.hidden:
        ld a,(ix+8)
        cp 40
        ret c
        ; reappear on a random side of the hero
        call rand
        and 1
        ld de,36
        jr z,.s
        ld de,-44
.s:     call place_rel
        ld (ix+4),6
        ld (ix+1),1
        ld (ix+8),0
        ld (ix+15),7            ; shimmer in
        ret

; Gargoyle Spout: three quick fireballs in a row
w3_spout:
        call face_hero
        cp 72
        ret nc
        ld a,(ix+8)
        cp 62
        jr z,.f
        cp 68
        jr z,.f
        cp 74
        jr z,.f
        cp 80
        ret c
        ld (ix+8),0
        ret
.f:     xor a
        ld l,a
        jp shoot
