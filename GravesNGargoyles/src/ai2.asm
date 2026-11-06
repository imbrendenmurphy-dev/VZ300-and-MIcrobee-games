; ============================================================================
;  STAGE 2 - THE WITCHWOOD: creature behaviours (lives in the stage pack)
; ============================================================================
S2_LOGIC: dw w2_trudger,w2_scarecrow,w2_moth,w2_wisp,w2_owl,w2_granny,w2_snapvine

; Toadstool Trudger: pops out of the ground, then hops after the hero
w2_trudger:
        ld a,(ix+1)
        cp 2
        jp c,o_zombie
        ld a,14
        ld (obj_h),a
        call obj_phys
        jp nz,air_step          ; in the air: keep going
        ld a,(ix+8)
        cp 24
        ret c
        ld (ix+8),0
        call face_hero
        ld (ix+6),-10           ; hop
        ret

; Scarecrow: stands still as a decoy, then lunges when you get close.
; Knock his pumpkin off and he blunders about (stage 1's headless logic).
w2_scarecrow:
        ld a,(ix+1)
        or a
        jp nz,o_skel
        ld a,16
        ld (obj_h),a
        ld a,(ix+12)
        or a
        jr nz,.lunge
        call hero_dist
        cp 44
        ret nc
        ld a,(ix+8)
        cp 40
        ret c
        call face_hero
        ld (ix+12),18
        ret
.lunge: dec (ix+12)
        jr nz,.go
        ld (ix+8),0
        ret
.go:    call walk_blocked
        ret nz
        jp step2

; Fang Moth: erratic fluttering toward the hero
w2_moth:
        ld a,(ix+1)
        or a
        jr nz,.fly
        call hero_dist
        cp 72
        ret nc
        ld (ix+1),1
        ret
.fly:   ld a,(ix+8)
        and 7
        call z,face_hero
        ld a,(ix+8)
        and 1
        call z,step2
        call rand
        and 3
        sub 1                   ; -1..2
        add a,(ix+4)
        ld b,a
        ld a,(hero_y)
        cp b
        ld a,b
        jr nc,.lo
        dec a
        dec a
.lo:    cp 2
        jr nc,$+4
        ld a,2
        cp 46
        jr c,$+4
        ld a,46
        ld (ix+4),a
        ret

; Witch-Wisp: shy. Frozen while the hero looks at it, creeps up when he doesn't
w2_wisp:
        call watched
        ret nz
        call o_ghost
        jp o_ghost

; Hoot Owl: perches, swoops down at the hero and climbs back up, over and over
w2_owl:
        ld a,(ix+1)
        or a
        jr nz,.act
        call hero_dist
        cp 56
        ret nc
        ld a,(ix+4)
        ld (ix+12),a            ; perch height
        call face_hero
        ld (ix+1),1
        ld a,SFX_THROW_ID
        jp play_sfx
.act:   call step2
        ld a,(ix+1)
        cp 1
        jr nz,.climb
        ld a,(ix+4)
        add a,2
        ld (ix+4),a
        ld b,a
        ld a,(hero_y)
        add a,4
        cp b
        ret nc
        ld (ix+1),2
        ret
.climb: dec (ix+4)
        ld a,(ix+12)
        cp (ix+4)
        ret c
        ld (ix+1),1
        jp face_hero

; Granny Grimweed (mini-boss): flies her broom across the top of the screen
; dropping potion bombs
w2_granny:
        ld a,(ix+1)
        or a
        jr nz,.act
        call hero_dist
        cp 80
        ret nc
        ld (ix+1),1
        ld a,SFX_THUNDER_ID
        jp play_sfx
.act:   call step2
        ld a,(ix+8)
        and 15
        call tri32
        srl a
        add a,3
        ld (ix+4),a
        ; turn round once well past the hero
        call hero_dist
        cp 50
        jr c,.nt
        ld a,(ix+13)
        or a
        jr nz,.nt2
        ld (ix+13),1
        call face_hero
        jr .nt2
.nt:    ld (ix+13),0
.nt2:   ld a,(ix+8)
        cp 22
        ret c
        ld (ix+8),0
        xor a
        ld l,0
        call shoot
        ret z
        ld (iy+5),0             ; falls straight down
        ld (iy+6),10
        ret

; Snapvine: a three-way spray of thorns when the hero comes near
w2_snapvine:
        call face_hero
        cp 64
        ret nc
        ld a,(ix+8)
        cp 70
        ret c
        ld (ix+8),0
        ld l,0
        ld a,-10
        call shoot
        ld l,0
        ld a,-5
        call shoot
        ld l,0
        xor a
        jp shoot
