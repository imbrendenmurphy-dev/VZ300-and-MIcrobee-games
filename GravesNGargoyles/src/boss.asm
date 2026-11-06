; ============================================================================
;  BOSS: GRAVEMAW, the Skull Under the Hill
;  A 32x28 composite (skull + separate jaw).  Vulnerable only while the jaw is
;  open and the eyes blaze; shots bounce off the bone otherwise (clink!).
;  Phase 2 (below half health): faster, slams the ground and calls bats.
;  states: 0 wait  1 rise  2 hover  3 jaw open/attack  4 slam  9 death
; ============================================================================

boss_logic:
        ld (boss_ptr),ix
        ld a,(ix+1)
        or a
        jr nz,.s1
        ; lock the arena once the camera reaches it
        ld l,(ix+2)
        ld h,(ix+3)
        ld (arena_x),hl
        ld hl,(cam_x)
        ld de,(arena_x)
        or a
        sbc hl,de
        ret c
        jr .lock
.s1:    cp 1
        jp z,.rise
        cp 2
        jp z,.hover
        cp 3
        jp z,.attack
        cp 4
        jp z,.slam
        jp .death
.lock:  ld a,1
        ld (cam_lock),a
        ld (boss_on),a
        ld hl,(arena_x)
        ld (cam_x),hl
        ld de,4
        add hl,de
        ld (xlim_lo),hl
        ld de,112
        add hl,de
        ld (xlim_hi),hl
        ld hl,(arena_x)
        ld de,48
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ld (ix+4),60
        ld (ix+1),1
        ld (ix+8),0
        ld (ix+12),0            ; jaw
        ld a,(opt_diff)
        ld e,a
        ld d,0
        ld hl,BOSS_HP
        add hl,de
        ld a,(hl)
        ld (boss_hp),a
        ld (boss_hpmax),a
        ld a,1
        ld (hud_need),a
        call stop_music
        ld a,SFX_THUNDER_ID
        call play_sfx
        ld hl,STR_BOSS
        jp banner
.rise:  ld a,8
        ld (shake_t),a
        ld a,(ix+8)
        and 1
        ret nz
        dec (ix+4)
        ld a,(ix+4)
        or a
        ret nz
        ld (ix+1),2
        ld (ix+8),0
        ld hl,SONG_BOSS
        call play_song
        ret
.hover: ; patrol high across the arena, bouncing off the edges
        call .speed
        and (ix+8)
        jr nz,.nmv
        ld a,(arena_x)
        ld c,a
        ld a,(ix+2)
        sub c                   ; position within the arena
        ld b,a
        ld a,(ix+11)
        or a
        jr nz,.ml
        ld a,b
        cp 92
        jr c,.mv
        ld (ix+11),1
        jr .nmv
.ml:    ld a,b
        cp 6
        jr nc,.mv
        ld (ix+11),0
        jr .nmv
.mv:    call step2
.nmv:   ld a,(ix+8)
        and 15
        cp 8
        ld a,0
        jr c,$+4
        ld a,1
        ld (ix+4),a
        ld a,(ix+8)
        cp 60
        ret c
        ld (ix+1),3
        ld (ix+8),0
        ret
.attack:
        ld a,(ix+8)
        cp 6
        jr nc,.op
        ld (ix+12),a            ; jaw opening
        ret
.op:    cp 10
        jr nz,.nf
        ; three fireballs: aimed, high, low
        call .fire3
.nf:    ld a,(ix+8)
        cp 26
        jr nz,.nf2
        ld a,(boss_hp)
        ld b,a
        ld a,(boss_hpmax)
        srl a
        cp b
        call nc,.fire3          ; second volley in phase 2
.nf2:   ld a,(ix+8)
        cp 44
        ret c
        ld a,50
        sub (ix+8)
        jr c,.cl
        ld (ix+12),a
        ret
.cl:    ld (ix+12),0
        ld (ix+8),0
        ld a,(boss_hp)
        ld b,a
        ld a,(boss_hpmax)
        srl a
        cp b
        jr c,.toh
        ld (ix+1),4             ; phase 2: slam
        ret
.toh:   ld (ix+1),2
        ret
.slam:  ld a,(ix+8)
        cp 12
        jr nc,.drop
        ld a,(ix+4)
        or a
        ret z
        dec (ix+4)
        ret
.drop:  cp 24
        jr nc,.land
        ld a,(ix+4)
        add a,3
        cp 20
        jr c,$+4
        ld a,20
        ld (ix+4),a
        ret
.land:  jr nz,.back
        ld a,10
        ld (shake_t),a
        ld a,SFX_BOOM_ID
        call play_sfx
        ; summon a pair of bats
        call .bat
        call .bat
        ret
.back:  ld a,(ix+4)
        or a
        jr z,.done
        dec (ix+4)
        ret
.done:  ld (ix+1),2
        ld (ix+8),0
        ret
.death: ld a,(ix+8)
        and 3
        jr nz,.nb
        ld a,4
        ld (shake_t),a
        call rand
        and 31
        ld e,a
        ld d,0
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ex de,hl
        call rand
        and 15
        add a,(ix+4)
        ld b,10
        push af
        ld a,(frame_no)
        and 4
        ld a,(col_yel)
        jr z,$+5
        ld a,(col_red)
        ld c,a
        pop af
        call part_burst
        ld a,SFX_BOOM_ID
        call play_sfx
.nb:    ld a,(ix+8)
        cp 70
        ret c
        ; gone: leave the sunstone
        xor a
        ld (boss_on),a
        ld (boss_hp),a
        ld a,1
        ld (hud_need),a
        ld (ix+0),OT_SUN
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,10
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ld (ix+4),16
        ld (ix+6),-12
        ld (ix+11),0
        ret

.speed: ; movement mask: every 2nd frame, every frame in phase 2
        ld a,(boss_hp)
        ld b,a
        ld a,(boss_hpmax)
        srl a
        cp b
        ld a,0
        ret nc
        ld a,1
        ret

.fire3: ld a,SFX_KILL_ID
        call play_sfx
        ld b,3
.fl:    ld a,b
        push af
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,14
        add hl,de
        ex de,hl
        ld a,(ix+4)
        add a,20
        ld b,a
        call face_hero_b
        pop af
        push af
        sub 2
        ld (fire_dvy),a
        ld l,1
        call spawn_fire
        pop bc
        djnz .fl
        ret

.bat:   push ix
        call obj_alloc
        jr nc,.bo
        ld (ix+0),OT_BAT
        ld (ix+9),1
        ld (ix+1),1
        ld (ix+12),4
        call rand
        and 1
        ld de,4
        jr z,.bl
        ld de,116
.bl:    ld hl,(arena_x)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ld (ix+4),2
.bo:    pop ix
        ret

; C = direction from the boss toward the hero
face_hero_b:
        ld hl,(hero_x)
        push de
        or a
        sbc hl,de
        pop de
        ld c,0
        ret nc
        ld c,1
        ret

BOSS_HP: db 14,20,28

; is the boss vulnerable (jaw open)? -> NZ
boss_vuln:
        ld ix,(boss_ptr)
        ld a,(ix+1)
        cp 3
        jr nz,.no
        ld a,(ix+12)
        cp 4
        jr c,.no
        or 1
        ret
.no:    xor a
        ret

; shot vs boss: IY = shot, tbox = shot box -> carry = shot consumed
boss_shot_check:
        ld a,(boss_on)
        or a
        ret z
        ld ix,(boss_ptr)
        ld a,(ix+1)
        cp 2
        jr c,.no
        cp 9
        jr z,.no
        call boss_box
        call box_hit
        jr nc,.no
        call boss_vuln
        jr z,.clink
        ; damage
        ld a,(iy+0)
        dec a
        ld e,a
        ld d,0
        ld hl,WDMG
        add hl,de
        ld b,(hl)
        ld a,(boss_hp)
        sub b
        jr z,.dead
        jr c,.dead
        ld (boss_hp),a
        ld (ix+15),6
        ld a,SFX_BOSSHIT_ID
        call play_sfx
        ld a,1
        ld (hud_need),a
        scf
        ret
.dead:  xor a
        ld (boss_hp),a
        ld (ix+1),9
        ld (ix+8),0
        ld (ix+12),6
        ld a,$10
        call add_score_k
        call stop_music
        ld a,40
        ld (flash_t),a
        ld a,1
        ld (hud_need),a
        scf
        ret
.clink: ld e,(iy+1)
        ld d,(iy+2)
        ld a,(iy+3)
        ld b,2
        push af
        ld a,(col_yel)
        ld c,a
        pop af
        call part_burst
        ld a,SFX_CLINK_ID
        call play_sfx
        scf
        ret
.no:    or a
        ret

boss_box:
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,4
        add hl,de
        ld (obox_x),hl
        ld a,(ix+4)
        add a,2
        ld (obox_y),a
        ld a,24
        ld (obox_w),a
        ld a,24
        ld (obox_h),a
        ret

boss_hero_check:
        ld a,(boss_on)
        or a
        ret z
        ld ix,(boss_ptr)
        ld a,(ix+1)
        cp 2
        ret c
        cp 9
        ret z
        call boss_box
        call box_hit
        ret nc
        jp hero_hit

boss_draw:
        ld a,(ix+1)
        or a
        ret z
        ; jaw
        ld a,(ix+4)
        add a,18
        add a,(ix+12)
        ld hl,S_BJAW_0
        ld e,(ix+2)
        ld d,(ix+3)
        ld c,0
        call draw_world
        ld hl,S_BSKULL_0
        ld e,(ix+2)
        ld d,(ix+3)
        ld c,0
        ld a,(ix+4)
        call draw_world
        ; blazing eyes while vulnerable
        call boss_vuln
        ret z
        ld a,(frame_no)
        and 1
        ret z
        ld ix,(boss_ptr)
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,8
        add hl,de
        ex de,hl
        ld a,(ix+4)
        add a,9
        ld hl,S_SPARK_0
        push de
        push af
        ld c,0
        call draw_world
        pop af
        pop de
        ld hl,12
        add hl,de
        ex de,hl
        ld hl,S_SPARK_0
        ld c,0
        jp draw_world
