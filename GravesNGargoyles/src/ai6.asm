; ============================================================================
;  STAGE 6 - THE DEMON CASTLE: creature behaviours
; ============================================================================
S6_LOGIC: dw w6_ghoul,w6_armour,w6_gargbat,w6_bride,w6_stone,w6_redgarg,w6_wallface

; Ghoul Guard: patrols his beat and ignores you - until he sees you ahead,
; then he runs
w6_ghoul:
        ld a,(ix+1)
        cp 2
        jp c,o_zombie
        ld a,14
        ld (obj_h),a
        call watched_by_me
        jr z,.patrol
        call hero_dist
        cp 56
        jr nc,.patrol
        call walk_blocked
        jp nz,turn
        jp step2                ; run (every frame)
.patrol:
        ld a,(ix+8)
        and 3
        ret nz
        ld a,(ix+8)
        cp 160
        jr c,.p
        ld (ix+8),0
        jp turn
.p:     call walk_blocked
        jp nz,turn
        jp step2

; NZ if the hero is in front of this object
watched_by_me:
        ld b,(ix+11)
        push bc
        call face_hero
        pop bc
        ld a,(ix+11)            ; direction toward the hero
        ld (ix+11),b
        xor b
        sub 1
        sbc a,a                 ; $FF if already facing him
        or a
        ret

; Living Armour: clanks slowly forward and swings at close range
w6_armour:
        ld a,(ix+1)
        or a
        jp nz,o_skel
        ld a,16
        ld (obj_h),a
        call hero_dist
        cp 26
        jr nc,.walk
        ld a,(ix+8)
        cp 50
        ret c
        ld (ix+8),0
        call face_hero
        ld a,-2
        ld l,0
        call shoot
        ret z
        ld (iy+8),58            ; a short swing, gone in a moment
        ret
.walk:  ld a,(ix+8)
        and 7
        ret nz
        call face_hero
        call walk_blocked
        jp nz,turn
        jp step2

; Gargoyle Bat: swoops in V shapes, aiming each dive at the hero
w6_gargbat:
        ld a,(ix+1)
        or a
        jr nz,.act
        call hero_dist
        cp 72
        ret nc
        ld (ix+1),1
        ld a,(ix+4)
        ld (ix+12),a
        ret
.act:   call step2
        ld a,(ix+8)
        and 31
        jr nz,.nf
        call face_hero
.nf:    call tri32
        add a,a
        add a,(ix+12)
        cp 46
        jr c,$+4
        ld a,46
        ld (ix+4),a
        ret

; Phantom Bride: drifts through the walls, fades away and reappears on
; the other side of the hero
w6_bride:
        ld a,(ix+1)
        bit 7,a
        jr nz,.hidden
        call o_ghost
        ld a,(ix+8)
        cp 120
        ret c
        ld (ix+1),$80
        ld (ix+8),0
        ret
.hidden:
        ld a,(ix+8)
        cp 30
        ret c
        ld de,-36
        ld a,(ix+11)            ; she was facing the hero: come back behind him
        or a
        jr nz,.s
        ld de,30
.s:     call place_rel
        ld (ix+1),0
        ld (ix+8),0
        ld (ix+15),7
        ret

; Stone Gargoyle: a statue until you pass, then it dives at you again and again
w6_stone:
        ld a,(ix+1)
        or a
        jr nz,.act
        ld (ix+10),0
        call hero_dist
        cp 36
        ret nc
        ld (ix+1),1
        ld (ix+8),0
        call face_hero
        ld a,SFX_THROW_ID
        jp play_sfx
.act:   cp 2
        jr z,.up
        call step2
        call step2
        ld a,(hero_y)
        add a,4
        call toward_y
        ld a,(hero_y)
        add a,4
        call toward_y
        ld a,(ix+8)
        cp 22
        ret c
        ld (ix+1),2
        ld (ix+8),0
        ret
.up:    call step2
        ld a,4
        call toward_y
        ld a,4
        call toward_y
        ld a,(ix+8)
        cp 22
        ret c
        ld (ix+1),1
        ld (ix+8),0
        jp face_hero

; The Red Gargoyle (mini-boss): hovers above, rains fire, and makes
; low strafing runs across the floor
w6_redgarg:
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
        jr z,.strafe
        ld a,6
        call toward_y
        call face_hero
        cp 4
        call nc,step2
        ld a,(ix+8)
        and 31
        jr nz,.ns
        xor a
        ld l,a
        call shoot
        jr z,.ns
        ld (iy+5),0
        ld (iy+6),12
.ns:    ld a,(ix+8)
        cp 120
        ret c
        ld (ix+1),2
        ld (ix+8),0
        ret
.strafe:
        ld a,(hero_y)
        add a,2
        call toward_y
        ld a,(hero_y)
        add a,2
        call toward_y
        ld a,(ix+8)
        cp 16
        ret c
        call step2
        call step2
        ld a,(ix+8)
        cp 56
        ret c
        ld (ix+1),1
        ld (ix+8),0
        ret

; Wall Face: a rapid burst of fire every so often
w6_wallface:
        call face_hero
        cp 80
        ret nc
        ld a,(ix+8)
        cp 70
        ret c
        cp 86
        jr nc,.end
        and 3
        ret nz
        xor a
        ld l,a
        jp shoot
.end:   ld (ix+8),0
        ret
