; =====================================================================
;  boss.asm - KING CANE, the giant cane toad (World 1 boss, 24x20)
;  +1 state (0 sit, 1 air, 2 spit wind-up, 9 dying) +7 timer +6 vy
;  +9 dir +13 jump count +14 hp +15 invulnerable timer
;  Weak spots: stomp his head, or BURST out of the ground beneath him.
;  His landings send a shockwave through the ground - be in the air, or
;  underground!
; =====================================================================
BOSS_HP   equ 6
BOSS_GY   equ 52
bosshp    db 0

boss_init:
        ld (ix+4),BOSS_GY
        ld a,(lv_bossid)
        cp 3
        jr z,.yt
        cp 4
        jr nz,.y
.yt:    ld (ix+4),ROBO_TOP
.y:
        ld a,(lv_bossid)
        cp 2
        ld a,BOSS_HP
        jr nz,.h0
        ld a,GOLEM_HP
.h0:    ld b,a
        ld a,(lv_bossid)
        cp 5
        ld a,b
        jr nz,.h
        ld a,DRAGON_HP
.h:     ld (ix+14),a
        ld (bosshp),a
        ld (ix+1),0
        ld (ix+7),70
        ld (ix+9),1
        ld (ix+10),$FF
        ld a,1
        ld (hudflag),a
        ret

boss_upd:
        ld a,(ix+15)
        or a
        jr z,.ni
        dec (ix+15)
.ni:    ld a,(ix+1)
        cp 9
        jp z,.dying
        call boss_hitcheck
        ld a,(ix+0)
        or a
        ret z
        ld a,(lv_bossid)
        cp 2
        jp z,golem_upd
        cp 3
        jp z,robo_upd
        cp 4
        jp z,robo_upd           ; Thunderhawk: the robot's pattern, with dives
        cp 5
        jr nz,.cane
        ld a,(ix+14)            ; Magma Dragon: hops like King Cane, then takes to the air
        cp 5
        jp c,robo_upd
.cane:  ld a,(ix+1)
        or a
        jp z,.sit
        dec a
        jp z,.air
        ; ---- spit wind-up
        ld (ix+8),1
        dec (ix+7)
        ret nz
        call free_slot_keep
        ret nc
        ld (iy+0),E_SPIT
        ld (iy+10),$FF
        ld a,(ix+4)
        add a,9
        ld (iy+4),a
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,8
        add hl,de
        ld (iy+2),l
        ld (iy+3),h
        call dx_boss
        bit 7,h
        ld a,3
        ld (iy+9),0
        jr z,.s1
        ld a,-3
        ld (iy+9),1
.s1:    ld (iy+5),a
        ld a,SFX_SWOOP
        call sfx_play
        ld (ix+1),0
        ld (ix+7),30
        ret
.sit:   ld a,(frame)
        rrca
        rrca
        rrca
        and 1
        ld (ix+8),a
        dec (ix+7)
        ret nz
        ld a,(ix+14)
        cp 4
        jr nc,.jump
        ld a,(ix+13)
        cp 2
        jr c,.jump
        ld (ix+13),0
        ld (ix+1),2
        ld (ix+7),24
        ret
.jump:  inc (ix+13)
        ld (ix+1),1
        ld (ix+6),-9
        call dx_boss
        ld a,h
        rla
        and 1
        ld (ix+9),a
        ld a,SFX_HOP
        jp sfx_play
.air:   ld (ix+8),2
        ld a,(frame)
        and 1
        jr z,.ay
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,4
        bit 0,(ix+9)
        jr z,.ar
        ld de,-4
.ar:    add hl,de
        ld a,l
        cp 8
        jr c,.ay
        cp 97
        jr nc,.ay
        ld (ix+2),l
        ld (ix+3),h
.ay:    ld a,(ix+4)
        add a,(ix+6)
        ld (ix+4),a
        inc (ix+6)
        bit 7,(ix+6)
        ret nz
        cp BOSS_GY
        ret c
        ; ---- landing: shockwave
        ld (ix+4),BOSS_GY
        ld (ix+1),0
        ld a,(ix+14)
        cp 4
        ld a,40
        jr nc,.l1
        ld a,22
.l1:    ld (ix+7),a
        ld a,6
        ld (shake),a
        ld a,SFX_STOMP
        call sfx_play
        call boss_dust
        ld a,(pstate)
        or a                    ; ST_NORM
        ret nz
        ld a,(onground)
        or a
        ret z
        ld a,(onplat)
        or a
        ret nz
        jp player_hurt
.dying: ld a,(frame)
        and 3
        jr nz,.d1
        call random
        and 15
        ld e,a
        ld d,0
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        call random
        and 15
        add a,(ix+4)
        call sparkle_burst
        ld a,SFX_BREAK
        call sfx_play
.d1:    ld (ix+8),3
        ld a,(frame)
        and 2
        ld (ix+15),a            ; flicker while he goes
        dec (ix+7)
        ret nz
        ld (ix+0),0
        ld a,ST_WIN
        ld (pstate),a
        ld a,70
        ld (statet),a
        ld a,$50
        call add_score_a        ; 500 points... and then some
        ld a,$50
        call add_score_a
        ld a,SFX_WIN
        jp sfx_play

; HL = player x - boss centre
dx_boss:
        ld hl,(ppx)
        ld e,(ix+2)
        ld d,(ix+3)
        or a
        sbc hl,de
        ld de,-8
        add hl,de
        ret

boss_dust:
        ld a,1
        ld (pgrav),a
        ld l,(ix+2)
        ld h,(ix+3)
        ld a,BOSS_GY+19
        ld bc,$FEFE
        ld de,$010A
        call spawn_part
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,23
        add hl,de
        ld a,BOSS_GY+19
        ld bc,$02FE
        ld de,$010A
        call spawn_part
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,4
        add hl,de
        ld a,BOSS_GY+19
        ld bc,$FFFC
        ld de,$030C
        call spawn_part
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,19
        add hl,de
        ld a,BOSS_GY+19
        ld bc,$01FC
        ld de,$030C
        jp spawn_part

boss_hitcheck:
        ld a,(pstate)
        or a
        ret nz
        ld hl,(ppx)
        ld e,(ix+2)
        ld d,(ix+3)
        or a
        sbc hl,de
        ld a,h
        inc a
        cp 2
        ret nc
        ld a,l
        add a,4
        cp 25
        ret nc
        ld a,(ppy)
        sub (ix+4)
        add a,5
        cp 25
        ret nc
        ; overlapping
        ld a,(ix+15)
        or a
        ret nz
        call boss_flying        ; flyers are only open while landed
        jr nc,.n3
        ld a,(ix+1)
        cp 2
        jr nz,.hurt
.n3:
        ld a,(burstt)
        or a
        jr nz,.hit
        ld a,(lv_bossid)        ; the Golem's crystal back can't be stomped
        cp 2
        jr z,.hurt
        ld a,(vy)
        bit 7,a
        jr nz,.hurt
        or a
        jr z,.hurt
        ld a,(ppy)
        add a,10
        sub (ix+4)
        cp 10
        jr nc,.hurt
.hit:   ld a,256-70
        ld (vy),a
        xor a
        ld (burstt),a
        ld (ix+15),40
        ld a,5
        ld (shake),a
        dec (ix+14)
        call boss_flying
        jr nc,.h3
        ld (ix+1),3             ; flyers flee back up
.h3:    inc (ix+14)
        dec (ix+14)
        ld a,(ix+14)
        ld (bosshp),a
        ld a,1
        ld (hudflag),a
        ld a,$20
        call add_score_a
        ld a,(ix+14)
        or a
        jr z,.dead
        ld a,SFX_STOMP
        jp sfx_play
.dead:  ld (ix+1),9
        ld (ix+7),80
        call music_stop
        ld a,SFX_DIE
        jp sfx_play
.hurt:  ld a,(shield)
        or a
        ret nz
        jp player_hurt

; boss_flying -> carry set if the current boss is in an airborne phase
boss_flying:
        ld a,(lv_bossid)
        cp 3
        jr c,.no
        cp 5
        jr c,.yes
        ld a,(ix+14)
        cp 5
        ret                     ; dragon: flying once hp < 5 (carry)
.yes:   scf
        ret
.no:    or a
        ret

; free_slot_keep: like free_slot but returns the slot in IY (IX preserved)
free_slot_keep:
        push ix
        call free_slot
        push ix
        pop iy
        pop ix
        ret

boss_draw:
        ld a,(ix+15)
        and 2
        ret nz
        ld a,(ix+8)
        ld b,a
        ld a,(ix+15)
        cp 21
        jr c,.f
        ld b,3
.f:     ld l,b
        ld h,0
        ld de,120
        call mul16
        ld de,BOSSG
        add hl,de
        push hl
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,(camx)
        or a
        sbc hl,de
        sra h
        rr l
        sra h
        rr l
        ld c,l
        ld a,(camy)
        ld b,a
        ld a,(ix+4)
        sub b
        pop hl
        ld b,20
        ld e,6
        jp drawspr

; =====================================================================
;  THE GEODE GOLEM (World 2 boss).  Stomps slowly after Bix; pounds the
;  ground to shake crystal shards loose from the ceiling.  His crystal back
;  hurts anyone who lands on it: the only way to hurt him is to BURST up
;  out of the ground underneath him.
; =====================================================================
GOLEM_HP equ 5
golem_upd:
        ld a,(ix+1)
        or a
        jr z,.walk
        ; ---- wind-up, then POUND
        ld (ix+8),2
        dec (ix+7)
        ret nz
        ld a,7
        ld (shake),a
        ld a,SFX_STOMP
        call sfx_play
        call boss_dust
        ld b,2
        ld a,(ix+14)
        cp 3
        jr nc,.n
        ld b,3
.n:     push bc
        call shard
        pop bc
        djnz .n
        ld (ix+1),0
        ld a,(ix+14)
        cp 3
        ld a,55
        jr nc,.t
        ld a,32
.t:     ld (ix+7),a
        ; shockwave through the floor
        ld a,(pstate)
        or a
        ret nz
        ld a,(onground)
        or a
        ret z
        jp player_hurt
.walk:  ld a,(frame)
        rrca
        rrca
        and 1
        ld (ix+8),a
        ld c,3                  ; step every 4 frames (2 when angry)
        ld a,(ix+14)
        cp 3
        jr nc,.s
        ld c,1
.s:     ld a,(frame)
        and c
        jr nz,.w2
        call dx_boss
        ld a,h
        or l
        jr z,.w2
        ld de,4
        bit 7,h
        ld (ix+9),0
        jr z,.w1
        ld de,-4
        ld (ix+9),1
.w1:    ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld a,l
        cp 8
        jr c,.w2
        cp 97
        jr nc,.w2
        ld (ix+2),l
        ld (ix+3),h
.w2:    dec (ix+7)
        ret nz
        ld (ix+1),2
        ld (ix+7),18
        ret

; a crystal shard falls from the ceiling somewhere in the arena
shard:
        call free_slot_keep
        ret nc
        ld (iy+0),E_DROP
        ld (iy+1),1
        ld (iy+10),$FF
        call random
        and 63
        ld b,a
        call random
        and 31
        add a,b
        add a,12
        ld (iy+2),a
        ld (iy+3),0
        ld (iy+4),16
        ld (iy+13),16
        ld (iy+6),0
        ret

; =====================================================================
;  RUST-O-TRON (World 3 boss).  Hovers along the ceiling dropping hot bolts,
;  then lands to cool off with its hatch open: that's when Bix can stomp it
;  or burst up into it.  Its landing shakes the factory floor.
; =====================================================================
ROBO_TOP equ 34
DRAGON_HP equ 8
robo_upd:
        ld a,(ix+1)
        or a
        jp z,.hover
        dec a
        jp z,.down
        dec a
        jp z,.landed
        ; ---- 3: climbing back up
        ld a,(frame)
        and 1
        ld (ix+8),a
        dec (ix+4)
        dec (ix+4)
        ld a,(ix+4)
        cp ROBO_TOP+1
        ret nc
        ld (ix+4),ROBO_TOP
        ld (ix+1),0
        ld (ix+13),0
        ld (ix+7),20
        ret
.down:  ld (ix+8),2
        ld a,(lv_bossid)
        cp 4
        jr nz,.dn
        ld (ix+8),0             ; Thunderhawk swoops at Bix as it dives
        call dx_boss
        ld a,h
        or l
        jr z,.dn
        ld de,4
        bit 7,h
        jr z,.dv
        ld de,-4
.dv:    ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld a,l
        cp 8
        jr c,.dn
        cp 97
        jr nc,.dn
        ld (ix+2),l
        ld (ix+3),h
        inc (ix+4)
.dn:    inc (ix+4)
        inc (ix+4)
        ld a,(ix+4)
        cp BOSS_GY
        ret c
        ld (ix+4),BOSS_GY
        ld (ix+1),2
        ld a,(ix+14)
        cp 3
        ld a,60
        jr nc,.l1
        ld a,38
.l1:    ld (ix+7),a
        ld a,6
        ld (shake),a
        ld a,SFX_STOMP
        call sfx_play
        call boss_dust
        ld a,(pstate)
        or a
        ret nz
        ld a,(onground)
        or a
        ret z
        ld a,(onplat)
        or a
        ret nz
        jp player_hurt
.landed:
        ld (ix+8),2
        dec (ix+7)
        ret nz
        ld (ix+1),3
        ret
.hover: ld a,(frame)
        and 1
        ld (ix+8),a
        and 1
        jr z,.dr
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,4
        bit 0,(ix+9)
        jr z,.r
        ld de,-4
.r:     add hl,de
        ld a,l
        cp 8
        jr c,.flip
        cp 97
        jr nc,.flip
        ld (ix+2),l
        ld (ix+3),h
        jr .dr
.flip:  ld a,(ix+9)
        xor 1
        ld (ix+9),a
.dr:    dec (ix+7)
        ret nz
        ld a,(ix+14)
        cp 3
        ld a,20
        jr nc,.t
        ld a,12
.t:     ld (ix+7),a
        inc (ix+13)
        ld a,(ix+13)
        cp 5
        jr c,.bolt
        ld (ix+1),1             ; time to cool down
        ret
.bolt:  call free_slot_keep
        ret nc
        ld (iy+0),E_SPIT
        ld (iy+10),$FF
        ld (iy+5),0
        ld (iy+6),3
        ld a,(ix+4)
        add a,14
        ld (iy+4),a
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,8
        add hl,de
        ld (iy+2),l
        ld (iy+3),h
        ld a,SFX_HOP
        jp sfx_play
