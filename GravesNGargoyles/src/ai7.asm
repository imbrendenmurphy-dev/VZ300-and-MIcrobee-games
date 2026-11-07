; ============================================================================
;  STAGE 7 - MORGRAVE'S CITADEL: creature behaviours
; ============================================================================
S7_LOGIC: dw w7_tome,w7_mage,w7_ftome,w7_spirit,w7_raven,w7_familiar,w7_mirror

; Shambling Tome: flaps its covers and scatters burning pages
w7_tome:
        ld a,(ix+1)
        cp 2
        jp c,o_zombie
        ld a,(ix+8)
        cp 70
        jp c,o_zombie
        ld (ix+8),0
        call hero_dist
        cp 64
        ret nc
        ld a,-12
        ld l,0
        call shoot
        call turn
        ld a,-6
        ld l,0
        call shoot
        jp turn

; Skeleton Mage: blinks toward the hero and casts aimed bolts
w7_mage:
        ld a,(ix+1)
        or a
        jp nz,o_skel
        call face_hero
        ld a,(ix+8)
        cp 50
        jr nz,.n
        xor a
        ld l,1
        jp shoot
.n:     cp 100
        ret c
        ld (ix+8),0
        call hero_dist
        cp 30
        ret c
        ; blink 24 px toward him if there is floor to land on
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,24
        ld a,(ix+11)
        or a
        jr z,.r
        ld de,-24
.r:     add hl,de
        push hl
        ld de,5
        add hl,de
        ld a,(ix+4)
        add a,16
        call tile_at
        pop hl
        or a
        ret z                   ; no floor there
        cp 3
        ret z
        push hl
        ld l,(ix+2)
        ld h,(ix+3)
        ex de,hl
        ld a,(ix+4)
        add a,6
        ld b,4
        push af
        ld a,(col_yel)
        ld c,a
        pop af
        call part_burst         ; sparkle where he was
        pop hl
        ld (ix+2),l
        ld (ix+3),h
        ld (ix+15),5
        ld a,SFX_THUNDER_ID
        jp play_sfx

; Flying Tome: bounces diagonally between floor and ceiling
w7_ftome:
        ld a,(ix+1)
        or a
        jr nz,.act
        call hero_dist
        cp 90
        ret nc
        call face_hero
        ld (ix+1),1
        ld (ix+12),2
        ret
.act:   call step2
        ld a,(ix+12)
        add a,(ix+4)
        ld (ix+4),a
        cp 4
        jr c,.flip
        cp 44
        ret c
.flip:  ld a,(ix+12)
        neg
        ld (ix+12),a
        ret

; Bound Spirit: circles round and round the hero
w7_spirit:
        ld a,(ix+8)
        add a,a
        add a,a                 ; phase, 64 frames a lap
        ld c,a
        call .tri               ; 0..32..0
        ld e,a
        ld d,0
        ld hl,(hero_x)
        add hl,de
        ld de,-14
        add hl,de               ; target x = hero - 14 + tri
        ld e,(ix+2)
        ld d,(ix+3)
        or a
        sbc hl,de
        jr z,.y
        ld (ix+11),0
        jr nc,.mv
        ld (ix+11),1
.mv:    call step2
.y:     ld a,c
        add a,64
        call .tri
        srl a
        ld b,a
        ld a,(hero_y)
        sub 6
        add a,b
        call toward_y
        jp toward_y
.tri:   ; A = 0..255 phase -> 0..32..0
        bit 7,a
        jr z,$+4
        cpl
        srl a
        srl a
        ret

; Morgrave's Raven: picks a line to the hero and dives along it, fast
w7_raven:
        ld a,(ix+1)
        or a
        jr nz,.act
        call hero_dist
        cp 64
        ret nc
.aim:   ld (ix+1),1
        ld (ix+8),0
        call face_hero
        call aim_dy
        sra a
        ld (ix+12),a
        ld a,SFX_THROW_ID
        jp play_sfx
.act:   call step2
        call step2
        ld a,(ix+12)
        add a,(ix+4)
        cp 46
        jr c,$+4
        ld a,46
        ld (ix+4),a
        ld a,(ix+8)
        cp 24
        ret c
        ; climb away then aim again
        ld (ix+12),-1
        ld a,(ix+4)
        cp 8
        ret nc
        jr .aim

; The Familiar (mini-boss): huge pouncing leaps, spitting hexes at the top
; of each one
w7_familiar:
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
        ld a,SFX_THUNDER_ID
        jp play_sfx
.act:   ld a,(ix+6)
        or a
        jr z,.ground
        cp -1
        jr nz,.air
        xor a                   ; apex: hex
        ld l,1
        call shoot
.air:   jp air_step
.ground:
        ld a,(ix+8)
        cp 28
        ret c
        ld (ix+8),0
        call face_hero
        ld (ix+6),-15
        ret

; Magic Mirror: throws back anything you throw at it, and sends its own
; bolts besides
w7_mirror:
        call face_hero
        cp 72
        ret nc
        ld a,(ix+8)
        cp 24
        ret c
        ; any hero shot in flight?
        ld iy,pshots
        ld b,NPSHOT
        ld de,8
.s:     ld a,(iy+0)
        or a
        jr nz,.fire
        add iy,de
        djnz .s
        ld a,(ix+8)
        cp 140
        ret c
.fire:  ld (ix+8),0
        xor a
        ld l,1
        jp shoot

; the ending text (shown while this pack is still loaded)
CARD_END:
        db 4,0,"THE SEVENTH SUNSTONE BLAZES",0
        db 11,2,"MORGRAVE CRUMBLES TO DUST AND",0
        db 17,2,"AT LAST THE SUN RISES OVER",0
        db 23,2,"DREADMOOR. THE DEAD LIE DOWN.",0
        db 31,0,"ARISE, SIR TINPLATE,",0
        db 37,0,"KNIGHT OF THE LONG NIGHT!",0
        db 44,1,"THE END",0
        db 50,2,"THANK YOU FOR PLAYING!",0
        db $FF
