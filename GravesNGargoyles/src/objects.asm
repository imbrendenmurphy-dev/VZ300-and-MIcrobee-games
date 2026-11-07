; ============================================================================
;  OBJECTS - enemies, pickups, chests, checkpoints, decor, enemy shots
;  slot: +0 type +1 state +2/3 x +4 y +5 vx +6 vy +7 yfrac +8 timer +9 hp
;        +10 anim +11 dir +12 p1 +13 p2 +14 level index +15 flash
; ============================================================================
OSIZE   equ 16
NOBJ    equ 14

OT_ZOMBIE equ 1
OT_SKEL   equ 2
OT_BAT    equ 3
OT_GHOST  equ 4
OT_CROW   equ 5
OT_IMP    equ 6
OT_PLANT  equ 7
OT_CHEST  equ 8
OT_ITEM   equ 9
OT_CHECK  equ 10
OT_ZZONE  equ 11
OT_BOSS   equ 12
OT_TORCH  equ 13
OT_DEBRIS equ 14
OT_FIRE   equ 15
OT_SKULL  equ 16
OT_SUN    equ 17
NOT       equ 18

; flags
F_HARM  equ 1
F_SHOOT equ 2
F_TOUCH equ 4
F_KEEP  equ 8           ; collected/killed permanently (never respawns)

; per type: flags, hp, box dx, dy, w, h, score (BCD tens)
OTAB:   db 0,0,0,0,0,0,0                    ; 0
        db F_HARM|F_SHOOT,1, 3,1,7,13, $10  ; zombie
        db F_HARM|F_SHOOT,2, 3,1,7,15, $20  ; skeleton
        db F_HARM|F_SHOOT,1, 1,0,10,7, $15  ; bat (and every stage's bat)
        db F_HARM|F_SHOOT,2, 2,1,8,10, $25  ; ghost
        db F_HARM|F_SHOOT,1, 0,1,7,5,  $15  ; crow
        db F_HARM|F_SHOOT|F_KEEP,8, 1,1,10,9, $99  ; imp
        db F_HARM|F_SHOOT,2, 1,0,8,10, $30  ; plant
        db F_TOUCH|F_KEEP,0, 0,1,12,9, 0    ; chest
        db F_TOUCH|F_KEEP,0, 0,0,8,7, 0     ; item
        db F_TOUCH|F_KEEP,0, 2,0,4,8, 0     ; checkpoint
        db 0,0,0,0,0,0,0                    ; zombie zone
        db 0,0,0,0,0,0,0                    ; boss trigger
        db 0,0,0,0,0,0,0                    ; torch
        db 0,0,0,0,0,0,0                    ; debris
        db F_HARM,0, 0,0,4,4, 0             ; fireball
        db 0,0,0,0,0,0,0                    ; flying skull
        db F_TOUCH,0, 0,0,12,10, 0          ; sunstone
OTW     equ 7

; ---------------------------------------------------------------- alloc
; obj_alloc -> IX = free slot (cleared), carry set; NC if none
obj_alloc:
        ld ix,objs
        ld b,NOBJ
        ld de,OSIZE
.lp:    ld a,(ix+0)
        or a
        jr z,.got
        add ix,de
        djnz .lp
        or a
        ret
.got:   push ix
        pop hl
        ld b,OSIZE
.cl:    ld (hl),0
        inc hl
        djnz .cl
        ld (ix+14),$FF
        scf
        ret

objs_clear:
        ld hl,objs
        ld de,objs+1
        ld bc,NOBJ*OSIZE-1
        ld (hl),0
        ldir
        ld hl,pshots
        ld de,pshots+1
        ld bc,NPSHOT*SHSIZE-1
        ld (hl),0
        ldir
        ld hl,parts
        ld de,parts+1
        ld bc,NPART*PSIZE-1
        ld (hl),0
        ldir
        ret

; ---------------------------------------------------------------- spawning
; spawn level objects whose column has come into view
objs_spawn:
        ld b,2
.lp:    push bc
        ld hl,(lvl_objp)
        ld a,(hl)
        cp $FF
        jr z,.done
        ; col*8 <= cam_x + 144 ?
        ld e,a
        ld d,0
        ex de,hl
        call mul8
        push hl
        ld hl,(cam_x)
        ld bc,144
        add hl,bc
        pop bc
        or a
        sbc hl,bc
        jr c,.done
        ; too far behind (camera passed it while respawning)?  spawn anyway
        ld hl,(lvl_objp)
        ld a,(lvl_obji)
        ld c,a
        call is_kept
        jr nz,.skip
        call obj_alloc
        jr nc,.done
        ld hl,(lvl_objp)
        ld a,(hl)               ; col
        inc hl
        ld e,a
        ld d,0
        ex de,hl
        call mul8
        ld (ix+2),l
        ld (ix+3),h
        ex de,hl
        ld a,(hl)               ; y
        inc hl
        ld (ix+4),a
        ld a,(hl)               ; type
        inc hl
        ld (ix+0),a
        ld a,(hl)               ; param
        ld (ix+12),a
        ld a,(lvl_obji)
        ld (ix+14),a
        call obj_init
.skip:  ld hl,(lvl_objp)
        inc hl
        inc hl
        inc hl
        inc hl
        ld (lvl_objp),hl
        ld hl,lvl_obji
        inc (hl)
        pop bc
        djnz .lp
        ret
.done:  pop bc
        ret

; kept bitmap: C = level object index -> NZ if collected/killed for good
is_kept:
        call kept_addr
        and (hl)
        ret
set_kept:
        call kept_addr
        or (hl)
        ld (hl),a
        ret
kept_addr:
        ld a,c
        rrca
        rrca
        rrca
        and 31
        ld e,a
        ld d,0
        ld hl,kept
        add hl,de
        ld a,c
        and 7
        ld b,a
        ld a,1
        jr z,.d
.s:     rlca
        djnz .s
.d:     ret

; per-type initialisation; IX = object
obj_init:
        ld a,(ix+0)
        ld e,a
        add a,a
        add a,a
        add a,a
        sub e                   ; *7
        ld e,a
        ld d,0
        ld hl,OTAB+1
        add hl,de
        ld a,(hl)
        ld (ix+9),a             ; hp
        ld a,(ix+0)
        cp OT_ZOMBIE
        jr nz,.n1
        ld a,(ix+4)
        sub 14
        ld (ix+4),a
        ret
.n1:    cp OT_SKEL
        jr nz,.n2
        ld a,(ix+4)
        sub 16
        ld (ix+4),a
        ld a,1
        ld (ix+11),a
        ret
.n2:    cp OT_CHEST
        jr nz,.n3
        ld a,(ix+4)
        or a
        jr nz,.cy
        ld a,40
.cy:    sub 10
        ld (ix+4),a
        ret
.n3:    cp OT_CHECK
        jr nz,.n4
        ld a,(ix+4)
        sub 8
        ld (ix+4),a
        ret
.n4:    cp OT_IMP
        jr nz,.n5
        ld a,(opt_diff)
        add a,a
        add a,6
        ld (ix+9),a
        ld (ix+13),a
        ret
.n5:    cp OT_PLANT
        jr nz,.n6
        ld a,(ix+4)
        sub 10
        ld (ix+4),a
        ret
.n6:    cp OT_ITEM
        ret nz
        ld a,(ix+4)
        or a
        ret nz
        ld (ix+4),32
        ret

; ---------------------------------------------------------------- update
objs_update:
        ld ix,objs
        ld b,NOBJ
.lp:    push bc
        ld a,(ix+0)
        or a
        jr z,.nx
        ld a,(ix+15)
        or a
        jr z,$+5
        dec (ix+15)
        inc (ix+8)
        inc (ix+10)
        ; despawn far away objects (not boss/zone)
        call obj_relx           ; HL = x - cam_x
        ld a,(ix+0)
        cp OT_BOSS
        jr z,.keep
        ld de,-48
        push hl
        or a
        sbc hl,de
        pop hl
        jp m,.free
        ld de,128+72
        or a
        sbc hl,de
        jp p,.free
.keep:  ld a,(ix+0)
        cp 3                    ; every stage's bat: rests one frame in four
        jr nz,.go
        ld a,(ix+8)
        and 3
        cp 3
        jr z,.nx
        ld a,(ix+0)
.go:    add a,a
        ld e,a
        ld d,0
        ld hl,OBJ_LOGIC
        cp 2*8
        jr nc,.tab
        ld hl,(lvl_logic)       ; enemies: the stage's own behaviours
        dec hl
        dec hl
.tab:   add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call jp_hl
        jr .nx
.free:  ld (ix+0),0
.nx:    ld de,OSIZE
        add ix,de
        pop bc
        djnz .lp
        ret
jp_hl:  jp (hl)

OBJ_LOGIC:
        dw o_none,o_zombie,o_skel,o_bat,o_ghost,o_crow,o_imp,o_plant
        dw o_none,o_item,o_none,o_zzone,boss_logic,o_none,o_debris,o_fire,o_skull,o_item

o_none: ret

; obj_relx: HL = object x - cam_x (signed)
obj_relx:
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,(cam_x)
        or a
        sbc hl,de
        ret

; face the hero: sets dir (0 right, 1 left), A = |dx| clipped to 255
face_hero:
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,(hero_x)
        or a
        sbc hl,de               ; obj - hero
        jr c,.right
        ld (ix+11),1
        jr .abs
.right: ld (ix+11),0
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
.abs:   ld a,h
        or a
        ld a,l
        ret z
        ld a,255
        ret

; distance to hero without changing direction -> A
hero_dist:
        ld a,(ix+11)
        push af
        call face_hero
        ld b,a
        pop af
        ld (ix+11),a
        ld a,b
        ret

; move by 2 px in facing direction
step2:
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,2
        ld a,(ix+11)
        or a
        jr z,.r
        ld de,-2
.r:     add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ret

; walker edge/wall check: NZ if the way ahead is blocked or ends -> turn
walk_blocked:
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,10
        ld a,(ix+11)
        or a
        jr z,.r
        ld de,1
        ; left side: x+1-2
        dec hl
        dec hl
.r:     add hl,de
        push hl
        ld a,(ix+4)
        add a,8
        call tile_at
        pop hl
        cp 1
        jr z,.blk
        ld a,(obj_h)
        add a,(ix+4)
        call tile_at
        or a
        jr z,.blk
        cp 3
        jr z,.blk
        xor a
        ret
.blk:   or 1
        ret

; ---------------------------------------------------------------- zombie
o_zombie:
        ld a,(ix+1)
        or a
        jr nz,.z1
        ; hidden in the ground until the hero comes close
        call hero_dist
        cp 52
        ret nc
        ld (ix+1),1
        ld (ix+8),0
        call face_hero
        ld a,SFX_THROW_ID
        jp play_sfx
.z1:    cp 1
        jr nz,.z2
        ld a,(ix+8)
        cp 14
        ret c
        ld (ix+1),2
        ret
.z2:    ; shamble
        ld a,(ix+8)
        and 1
        ret nz
        ld a,(opt_diff)
        cp 2
        jr z,.fast
        ld a,(ix+8)
        and 3
        ret nz
.fast:  ld a,14
        ld (obj_h),a
        call walk_blocked
        jr z,.go
        ld a,(ix+11)
        xor 1
        ld (ix+11),a
        ret
.go:    jp step2

; ---------------------------------------------------------------- skeleton
o_skel:
        ld a,16
        ld (obj_h),a
        ld a,(ix+1)
        or a
        jr nz,.headless
        ld a,(ix+8)
        and 3
        ret nz
        ld a,(ix+8)
        and 63
        jr nz,.w
        call face_hero
.w:     call walk_blocked
        jr z,.go
        ld a,(ix+11)
        xor 1
        ld (ix+11),a
        ret
.go:    jp step2
.headless:
        ; confused: random turns, faster
        ld a,(ix+8)
        and 31
        jr nz,.h1
        call rand
        and 1
        ld (ix+11),a
.h1:    ld a,(ix+8)
        and 1
        ret nz
        call walk_blocked
        jr z,.go
        ld a,(ix+11)
        xor 1
        ld (ix+11),a
        ret

; ---------------------------------------------------------------- bat
o_bat:
        ld a,(ix+1)
        or a
        jr nz,.fly
        call hero_dist
        cp 70
        ret nc
        ld (ix+1),1
        ld a,(ix+4)
        ld (ix+12),a            ; base y
        ret
.fly:   ld a,(ix+8)
        and 15
        jr nz,.nf
        call face_hero
.nf:    call step2
        ; swoop: y follows a triangle wave toward the hero's head height
        ld a,(ix+8)
        and 31
        cp 16
        jr c,.dn
        neg
        add a,32
.dn:    ld b,a
        ld a,(ix+12)
        add a,b
        ld c,a
        ld a,(hero_y)
        cp c
        jr nc,.ok
        ld c,a
.ok:    ld (ix+4),c
        ret

; ---------------------------------------------------------------- ghost
o_ghost:
        ld a,(ix+8)
        and 1
        ret nz
        call face_hero
        cp 4
        call nc,step2
        ld a,(ix+8)
        and 3
        ret nz
        ld a,(hero_y)
        add a,2
        cp (ix+4)
        jr z,.r
        jr c,.u
        inc (ix+4)
        ret
.u:     dec (ix+4)
.r:     ret

; ---------------------------------------------------------------- crow
o_crow:
        ld a,(ix+1)
        or a
        jr nz,.fly
        call hero_dist
        cp 50
        ret nc
        ld (ix+1),1
        call face_hero
        ld a,SFX_THROW_ID
        jp play_sfx
.fly:   call step2
        ld a,(ix+8)
        and 1
        ret nz
        ld a,(hero_y)
        add a,6
        cp (ix+4)
        jr c,.up
        inc (ix+4)
        ret
.up:    dec (ix+4)
        ret

; ---------------------------------------------------------------- plant
o_plant:
        call face_hero
        ld a,(ix+8)
        cp 60
        ret c
        ld (ix+8),0
        cp 100
        ret nc
        ld a,(ix+11)
        ld c,a
        ld a,(ix+4)
        add a,2
        ld b,a
        ld e,(ix+2)
        ld d,(ix+3)
        ld l,0
        jp spawn_fire

; ---------------------------------------------------------------- imp (mini-boss)
; state 0 wait, 1 hover, 2 swoop down, 3 climb
o_imp:
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
.act:   cp 1
        jr nz,.s2
        ; hover near the hero, bobbing, shooting
        call face_hero
        cp 30
        jr c,.nm
        call step2
.nm:    ld a,(ix+8)
        and 7
        cp 4
        ld a,(ix+4)
        jr c,.bu
        inc a
        jr .bd
.bu:    dec a
.bd:    cp 2
        jr nc,$+4
        ld a,2
        ld (ix+4),a
        ld a,(ix+8)
        cp 45
        ret c
        ld (ix+8),0
        call rand
        and 1
        jr z,.shoot
        ld (ix+1),2
        ret
.shoot: ld a,(ix+11)
        ld c,a
        ld a,(ix+4)
        add a,4
        ld b,a
        ld e,(ix+2)
        ld d,(ix+3)
        ld l,1
        jp spawn_fire
.s2:    cp 2
        jr nz,.s3
        ; dive at the hero
        call step2
        call step2
        ld a,(ix+4)
        add a,2
        ld (ix+4),a
        ld b,a
        ld a,(hero_y)
        cp b
        ret nc
        ld (ix+1),3
        ret
.s3:    call step2
        ld a,(ix+4)
        sub 2
        ld (ix+4),a
        cp 6
        ret nc
        ld (ix+1),1
        ld (ix+8),0
        ret

; ---------------------------------------------------------------- zombie zone
o_zzone:
        ; active while the hero is inside the zone
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,(hero_x)
        ex de,hl
        or a
        sbc hl,de               ; hero - zone start
        ret c
        ld a,h
        or a
        ret nz
        ld a,(ix+12)
        add a,a
        add a,a
        add a,a
        cp l
        ret c
        ; keep the zone object alive with the camera
        ld a,(ix+8)
        cp 55
        ret c
        ld (ix+8),0
        ; count zombies
        ld iy,objs
        ld b,NOBJ
        ld c,0
.cz:    ld a,(iy+0)
        cp OT_ZOMBIE
        jr nz,.nz
        inc c
.nz:    ld de,OSIZE
        add iy,de
        djnz .cz
        ld a,c
        cp 3
        ret nc
        push ix
        call obj_alloc
        jr nc,.out
        ld (ix+0),OT_ZOMBIE
        ld (ix+9),1
        ld (ix+14),$FF
        ld (ix+1),1             ; rising immediately
        call rand
        and 1
        ld hl,(hero_x)
        ld de,44
        jr z,.side
        ld de,-40
.side:  add hl,de
        ld a,l
        and $FE
        ld l,a
        ld (ix+2),l
        ld (ix+3),h
        ; find the ground under that column
        ld b,0
.gf:    push bc
        push hl
        ld a,b
        call tile_at
        pop hl
        pop bc
        cp 1
        jr z,.gfd
        cp 2
        jr z,.gfd
        ld a,b
        add a,8
        ld b,a
        cp 56
        jr c,.gf
        ld (ix+0),0
        jr .out
.gfd:   ld a,b
        and $F8
        sub 14
        ld (ix+4),a
        call face_hero
.out:   pop ix
        ret

; ---------------------------------------------------------------- items
o_item:
        ; fall until resting on ground
        ld a,(ix+6)
        or a
        ret z
        ld a,(ix+6)
        sra a
        sra a
        add a,(ix+4)
        ld (ix+4),a
        inc (ix+6)
        bit 7,(ix+6)
        ret nz
        ; past the apex: keep falling (vy 0 means resting), cap the speed
        ld a,(ix+6)
        cp 16
        jr c,.sp
        ld (ix+6),16
.sp:    or a
        jr nz,.fall
        ld (ix+6),1
.fall:  ld l,(ix+2)
        ld h,(ix+3)
        ld de,4
        add hl,de
        ld a,(ix+4)
        add a,8
        call tile_at
        or a
        ret z
        cp 3
        ret z
        ld a,(ix+4)
        add a,8
        and $F8
        sub 8
        ld (ix+4),a
        ld (ix+6),0
        ret

; ---------------------------------------------------------------- debris / skull / fire
o_debris:
o_skull:
        ld a,(ix+5)
        sra a
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld a,l
        and $FE
        ld l,a
        ld (ix+2),l
        ld (ix+3),h
        ld a,(ix+6)
        sra a
        sra a
        add a,(ix+4)
        ld (ix+4),a
        inc (ix+6)
        inc (ix+6)
        cp 60
        jr nc,.kill
        ld a,(ix+8)
        cp 40
        ret c
.kill:  ld (ix+0),0
        ret

o_fire:
        ld a,(ix+5)
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ld a,(ix+6)
        sra a
        sra a
        add a,(ix+4)
        ld (ix+4),a
        cp 58
        jr nc,.kill
        ld a,(ix+8)
        cp 70
        ret c
.kill:  ld (ix+0),0
        ret

; spawn_fire: DE = x, B = y, C = dir, L = aimed (1 = toward hero's height)
spawn_fire:
        push ix
        push hl
        push de
        push bc
        call obj_alloc
        pop bc
        pop de
        pop hl
        jr nc,.out
        ld (ix+0),OT_FIRE
        ld (ix+2),e
        ld (ix+3),d
        ld (ix+4),b
        ld a,c
        or a
        ld a,3
        jr z,$+4
        ld a,-3
        ld (ix+5),a
        ld (ix+6),0
        ld a,l
        or a
        jr z,.dv
        ld a,(hero_y)
        add a,6
        sub b
        sra a
        sra a
        sra a
        ld (ix+6),a
.dv:    ld a,(fire_dvy)
        add a,(ix+6)
        ld (ix+6),a
        xor a
        ld (fire_dvy),a
        ld (last_obj),ix
.out:   pop ix
        ret

; ---------------------------------------------------------------- shared helpers
; obj_phys: gravity for jumping enemies. vy in (ix+6) (quarter pixels),
; feet at y+obj_h. Lands on solid or one-way tiles. Z = standing.
obj_phys:
        ld a,(ix+6)
        sra a
        sra a
        add a,(ix+4)
        ld (ix+4),a
        ld a,(ix+6)
        cp 14
        jr nc,.cap
        inc a
        ld (ix+6),a
.cap:   bit 7,a
        jr nz,.air              ; rising
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,5
        add hl,de
        ld a,(obj_h)
        add a,(ix+4)
        ld b,a
        call tile_at
        or a
        jr z,.air
        cp 3
        jr z,.air
        ld a,(obj_h)
        ld c,a
        ld a,b
        and $F8
        sub c
        ld (ix+4),a
        ld (ix+6),0
        xor a
        ret
.air:   or 1
        ret

; aim_dy: A = (hero_y + 6 - y) / 8 (signed), for aimed shots and dives
aim_dy: ld a,(hero_y)
        add a,6
        sub (ix+4)
        sra a
        sra a
        sra a
        ret

; shoot: fire from the object's middle in its facing direction.
; A = extra vy (signed), L = 1 to aim at the hero.  Returns IY = shot (or 0)
shoot:  ld (fire_dvy),a
        ld a,(ix+11)
        ld c,a
        ld a,(ix+4)
        add a,3
        ld b,a
        ld e,(ix+2)
        ld d,(ix+3)
        inc de
        inc de
        inc de
        ld iy,0
        ld (last_obj),iy
        call spawn_fire
        ld a,SFX_THROW_ID
        call play_sfx
        ld iy,(last_obj)
        push iy
        pop hl
        ld a,h
        or l                    ; NZ: IY = the new shot
        ret

; air_step: 2 px forward unless a wall is ahead (then turn round)
air_step:
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,11
        ld a,(ix+11)
        or a
        jr z,.r
        ld de,-2
.r:     add hl,de
        ld a,(ix+4)
        add a,4
        call tile_at
        cp 1
        jp nz,step2
turn:   ld a,(ix+11)
        xor 1
        ld (ix+11),a
        ret

; toward_y: move y one pixel toward A
toward_y:
        cp (ix+4)
        ret z
        jr c,.up
        inc (ix+4)
        ret
.up:    dec (ix+4)
        ret

; place_rel: x = hero_x + DE (kept even and on the map)
place_rel:
        ld hl,(hero_x)
        add hl,de
        bit 7,h
        jr z,.ok
        ld hl,8
.ok:    ld a,l
        and $FE
        ld (ix+2),a
        ld (ix+3),h
        ret

; watched: NZ if the hero is facing this object
watched:
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,(hero_x)
        or a
        sbc hl,de               ; C: object is left of the hero
        ld a,(hero_dir)         ; 0 right, 1 left
        jr c,.left
        xor 1
.left:  or a
        ret

; tri32: A = triangle wave 0..16..0 from the timer (period 32)
tri32:  ld a,(ix+8)
        and 31
        cp 16
        ret c
        neg
        add a,32
        ret

; ---------------------------------------------------------------- collisions
; box from object type table -> obox (x16, y, w, h)
obj_box:
        ld a,(ix+0)
        ld e,a
        add a,a
        add a,a
        add a,a
        sub e
        ld e,a
        ld d,0
        ld hl,OTAB
        add hl,de
        ld a,(hl)
        ld (obj_flags),a
        inc hl
        inc hl
        ld e,(hl)               ; dx
        inc hl
        ld a,(hl)               ; dy
        add a,(ix+4)
        ld (obox_y),a
        inc hl
        ld a,(hl)
        ld (obox_w),a
        inc hl
        ld a,(hl)
        ld (obox_h),a
        inc hl
        ld a,(hl)
        ld (obj_score),a
        ld l,(ix+2)
        ld h,(ix+3)
        ld d,0
        add hl,de
        ld (obox_x),hl
        ret

; overlap test of obox against tbox -> carry if overlapping
box_hit:
        ; x: obox_x < tbox_x + tbox_w  and  tbox_x < obox_x + obox_w
        ld hl,(tbox_x)
        ld a,(tbox_w)
        ld e,a
        ld d,0
        add hl,de
        ld de,(obox_x)
        or a
        sbc hl,de               ; (t+tw) - o
        jr c,.no
        jr z,.no
        ld hl,(obox_x)
        ld a,(obox_w)
        ld e,a
        ld d,0
        add hl,de
        ld de,(tbox_x)
        or a
        sbc hl,de
        jr c,.no
        jr z,.no
        ; y (signed bytes, biased)
        ld a,(tbox_y)
        add a,64
        ld b,a
        ld a,(tbox_h)
        add a,b
        ld c,a                  ; t bottom
        ld a,(obox_y)
        add a,64
        cp c
        jr nc,.no
        ld d,a
        ld a,(obox_h)
        add a,d
        cp b
        jr c,.no
        jr z,.no
        scf
        ret
.no:    or a
        ret

; shots against shootable objects
collide_shots:
        ld iy,pshots
        ld b,NPSHOT
.sl:    push bc
        ld a,(iy+0)
        or a
        jp z,.snx
        ; shot box
        ld l,(iy+1)
        ld h,(iy+2)
        ld (tbox_x),hl
        ld a,(iy+3)
        ld (tbox_y),a
        ld a,8
        ld (tbox_w),a
        ld a,4
        ld (tbox_h),a
        ld a,(iy+0)
        cp 3
        jr c,.sb
        ld a,6
        ld (tbox_h),a
.sb:    ; flame only hurts every 8 frames
        ld a,(iy+0)
        cp 5
        jr nz,.nfl
        ld a,(iy+6)
        and 7
        jp nz,.snx
.nfl:   ; boss
        call boss_shot_check
        jr c,.consume
        ld ix,objs
        ld b,NOBJ
.ol:    push bc
        ld a,(ix+0)
        or a
        jr z,.onx
        bit 7,(ix+1)            ; hidden (teleporting) enemies
        jr nz,.onx
        call obj_box
        ld a,(obj_flags)
        and F_SHOOT
        jr z,.onx
        ; emerging zombies are invulnerable until half out
        ld a,(ix+0)
        cp OT_ZOMBIE
        jr nz,.ok1
        ld a,(ix+1)
        or a
        jr z,.onx
.ok1:   call box_hit
        jr nc,.onx
        call obj_damage
        pop bc
        ; does the shot survive?
        ld a,(iy+0)
        cp 3
        jr nc,.snx              ; axe, torch, flame pierce
        cp 1
        jr nz,.consume
        ld a,(wlevel+W_LANCE)
        or a
        jr nz,.snx              ; enchanted lance pierces
.consume:
        ld a,(iy+0)
        cp 5
        jr z,.snx
        ld (iy+0),0
        jr .snx
.onx:   ld de,OSIZE
        add ix,de
        pop bc
        djnz .ol
.snx:   ld de,SHSIZE
        add iy,de
        pop bc
        dec b
        jp nz,.sl
        ret

; obj_damage: IX = object, IY = shot
obj_damage:
        ld a,(iy+0)
        dec a
        ld e,a
        ld d,0
        ld hl,WDMG
        add hl,de
        ld b,(hl)
        ld a,(iy+0)
        cp 3
        jr nc,.dm
        dec a
        ld e,a
        ld hl,wlevel
        add hl,de
        ld a,(hl)
        or a
        jr z,.dm
        inc b
.dm:    ld a,(ix+0)
        cp OT_SKEL
        jr nz,.nsk
        ld a,(ix+1)
        or a
        jr nz,.nsk
        ; first hit knocks the skeleton's head off
        ld (ix+1),1
        ld (ix+9),1
        ld (ix+15),4
        call spawn_skull
        ld a,SFX_HIT_ID
        jp play_sfx
.nsk:   ld a,(ix+9)
        sub b
        ld (ix+9),a
        jr z,obj_kill
        jr c,obj_kill
        ld (ix+15),4
        ld a,SFX_HIT_ID
        jp play_sfx

; obj_kill: IX = object (score from obj_score set by obj_box)
obj_kill:
        ld a,(obj_score)
        call add_score
        ld a,SFX_KILL_ID
        call play_sfx
        ld e,(ix+2)
        ld d,(ix+3)
        ld hl,4
        add hl,de
        ex de,hl
        ld a,(ix+4)
        add a,4
        ld b,8
        push af
        ld a,(col_red)
        ld c,a
        ld a,(ix+0)
        cp OT_SKEL
        jr z,.bone
        cp OT_GHOST
        jr nz,.nb
.bone:  ld a,(col_yel)
        ld c,a
.nb:    pop af
        call part_burst
        ld a,(ix+0)
        cp OT_IMP
        jr nz,.nimp
        ; mini-boss: big bang and an armour reward
        ld a,30
        ld (flash_t),a
        ld a,SFX_BOOM_ID
        call play_sfx
        ld c,(ix+14)
        call set_kept
        ld (ix+0),OT_ITEM
        ld (ix+12),2
        ld (ix+6),-8
        ld (ix+14),$FF
        ret
.nimp:  ; random drop
        call rand
        and 7
        jr nz,.nodrop
        call rand
        and 3
        jr nz,.coin
        ld (ix+12),3            ; potion
        jr .drop
.coin:  ld (ix+12),0
.drop:  ld (ix+0),OT_ITEM
        ld (ix+6),-10
        ld (ix+14),$FF
        ld (ix+8),0
        ret
.nodrop:
        ld (ix+0),0
        ret

spawn_skull:
        push ix
        ld l,(ix+2)
        ld h,(ix+3)
        ld a,(ix+4)
        push af
        push hl
        call obj_alloc
        pop hl
        pop bc
        jr nc,.out
        ld (ix+0),OT_SKULL
        ld (ix+2),l
        ld (ix+3),h
        ld (ix+4),b
        ld (ix+5),4
        ld (ix+6),-24
.out:   pop ix
        ret

; hero against objects
collide_hero:
        ld a,(hero_dead)
        or a
        ret nz
        ld hl,(hero_x)
        inc hl
        inc hl
        inc hl
        ld (tbox_x),hl
        ld a,6
        ld (tbox_w),a
        ld a,(crouch)
        or a
        ld a,(hero_y)
        ld b,13
        jr z,.nc
        add a,5
        ld b,8
.nc:    add a,2
        ld (tbox_y),a
        ld a,b
        ld (tbox_h),a
        call boss_hero_check
        ld ix,objs
        ld b,NOBJ
.lp:    push bc
        ld a,(ix+0)
        or a
        jr z,.nx
        bit 7,(ix+1)
        jr nz,.nx
        call obj_box
        ld a,(obj_flags)
        and F_HARM|F_TOUCH
        jr z,.nx
        ld a,(ix+0)
        cp OT_ZOMBIE
        jr nz,.nz
        ld a,(ix+1)
        or a
        jr z,.nx
        ld a,(ix+8)
        cp 8
        jr c,.nx
.nz:    call box_hit
        jr nc,.nx
        ld a,(obj_flags)
        and F_HARM
        jr z,.touch
        call hero_hit
        jr .nx
.touch: call obj_touch
.nx:    ld de,OSIZE
        add ix,de
        pop bc
        djnz .lp
        ret

; touching a chest / item / checkpoint / sunstone
obj_touch:
        ld a,(ix+0)
        cp OT_CHEST
        jr nz,.n1
        ld a,(ix+1)
        or a
        ret nz
        ld (ix+1),1
        ld c,(ix+14)
        call set_kept
        ld a,SFX_CHEST_ID
        call play_sfx
        ; pop out the contents
        push ix
        ld l,(ix+2)
        ld h,(ix+3)
        inc hl
        inc hl
        ld b,(ix+4)
        ld c,(ix+12)
        push bc                 ; (not AF: popping it would lose obj_alloc's carry)
        push hl
        call obj_alloc
        pop hl
        pop bc
        jr nc,.ch
        ld (ix+0),OT_ITEM
        ld (ix+2),l
        ld (ix+3),h
        ld (ix+4),b
        ld (ix+12),c
        ld (ix+6),-14
        ld (ix+14),$FF
.ch:    pop ix
        ret
.n1:    cp OT_CHECK
        jr nz,.n2
        ld a,(ix+1)
        or a
        ret nz
        ld (ix+1),1
        ld l,(ix+2)
        ld h,(ix+3)
        ld (check_x),hl
        ld a,(ix+14)
        ld (check_obj),a
        call arm_full
        call build_hero
        ld a,SFX_CHECK_ID
        call play_sfx
        ld hl,STR_CHECK
        call banner
        ld a,1
        ld (hud_need),a
        ret
.n2:    cp OT_SUN
        jr nz,.n3
        ld a,1
        ld (stage_clear),a
        ld (ix+0),0
        ret
.n3:    ; item: falling items can't be grabbed until they land
        ld a,(ix+6)
        bit 7,a
        ret nz
        ld a,(ix+12)
        ld (ix+0),0
        ld c,(ix+14)
        ld a,c
        cp $FF
        jr z,.nk
        push af
        call set_kept
        pop af
.nk:    ld a,(ix+12)
        jp collect

; collect item A
collect:
        ld e,a
        ld d,0
        ld hl,COLLECT_T
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,1
        ld (hud_need),a
        jp (hl)
COLLECT_T:
        dw c_coin,c_jewel,c_armour,c_potion,c_lance,c_dagger,c_axe,c_torch,c_heart
c_coin: ld a,SFX_COIN_ID
        call play_sfx
        ld a,$05
        jp add_score
c_jewel:
        ld a,SFX_COIN_ID
        call play_sfx
        ld a,$50
        jp add_score
c_armour:
        ld a,SFX_POWER_ID
        call play_sfx
        ld a,(arm_cur)
        ld b,a
        ld a,(arm_max)
        cp b
        jr z,.up
        call set_arm            ; repair
        ld hl,STR_REPAIR
        call banner
        jp build_hero
.up:    cp 5
        jr nc,.max
        inc a
        ld (arm_max),a
        call set_arm
        call build_hero
        ; banner with the new armour name
        ld a,(arm_cur)
        call armour_name
        jp banner
.max:   ld a,$99
        jp add_score
c_potion:
        ld a,SFX_POWER_ID
        call play_sfx
        ld a,(magic)
        cp 3
        jr nc,.full
        inc a
        ld (magic),a
        ret
.full:  ld a,$20
        jp add_score
c_lance: ld a,W_LANCE
        jr c_weapon
c_dagger: ld a,W_DAGGER
        jr c_weapon
c_axe:  ld a,W_AXE
        jr c_weapon
c_torch: ld a,W_TORCH
c_weapon:
        ld hl,weapon
        cp (hl)
        jr z,.same
        ld c,(hl)
        ld (hl),a
        ld hl,prev_w
        ld (hl),c
.same:  ld e,a
        ld d,0
        ld b,a
        inc b
        ld a,(owned)
        ld c,a
        ld a,1
.sh:    dec b
        jr z,.sd
        rlca
        jr .sh
.sd:    ld b,a
        and c                   ; Z = a new weapon
        ; more throws for it (a new one starts from none), up to 99
        ld hl,AMMO_GIVE
        add hl,de               ; (ADD HL keeps Z)
        ld a,(hl)
        ld hl,ammo
        add hl,de
        jr z,.set
        add a,(hl)
        cp 100
        jr c,.set
        ld a,99
.set:   ld (hl),a
        ld a,c
        and b
        jr z,.new
        ; already owned: enchant it
        ld hl,wlevel
        add hl,de
        ld (hl),1
        ld hl,STR_UPGRADE
        call banner
        jr .snd
.new:   ld a,c
        or b
        ld (owned),a
        ld hl,WNAMES
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call banner
.snd:   ld a,SFX_POWER_ID
        jp play_sfx
c_heart:
        ld a,(lives)
        cp 9
        jr nc,.f
        inc a
        ld (lives),a
.f:
        ld hl,STR_1UP
        call banner
        ld a,SFX_POWER_ID
        jp play_sfx

; A = level -> HL = name string
armour_name:
        ld hl,ARMOUR_NAMES
        or a
        ret z
        ld b,a
.lp:    ld a,(hl)
        inc hl
        or a
        jr nz,.lp
        djnz .lp
        ret

; ---------------------------------------------------------------- drawing
objs_draw:
        ld ix,objs
        ld b,NOBJ
.lp:    push bc
        ld a,(ix+0)
        or a
        jr z,.nx
        ; hit flash: skip alternate frames
        ld a,(ix+15)
        and 1
        jr nz,.nx
        bit 7,(ix+1)            ; hidden
        jr nz,.nx
        ld a,(ix+0)
        add a,a
        ld e,a
        ld d,0
        ld hl,OBJ_DRAW
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call jp_hl
.nx:    ld de,OSIZE
        add ix,de
        pop bc
        djnz .lp
        xor a
        ld (spr_rows),a
        ret

OBJ_DRAW:
        dw d_none,d_zombie,d_skel,d_bat,d_ghost,d_crow,d_imp,d_plant
        dw d_chest,d_item,d_check,d_none,boss_draw,d_torch,d_debris,d_fire,d_skull,d_sun

d_none: ret

; draw with frame HL, object position/dir
dobj:   ld e,(ix+2)
        ld d,(ix+3)
        ld a,(ix+11)
        ld c,a
        ld a,(ix+4)
        jp draw_world

; animation helper: A = mask of anim counter bit -> picks frame 0/1
anim2:  and (ix+10)
        ret

d_zombie:
        ld a,(ix+1)
        or a
        ret z
        cp 1
        jr nz,.walk
        ld a,(ix+8)
        inc a
        cp 15
        jr c,$+4
        ld a,14
        ld (spr_rows),a
        ld b,a
        ld a,14
        sub b
        add a,(ix+4)
        ld hl,(STG_SPR+0)
        ld e,(ix+2)
        ld d,(ix+3)
        ld c,(ix+11)
        call draw_world
        xor a
        ld (spr_rows),a
        ; dirt kicked up
        ld a,(ix+8)
        and 3
        ret nz
        ld e,(ix+2)
        ld d,(ix+3)
        ld hl,5
        add hl,de
        ex de,hl
        ld a,(ix+4)
        add a,13
        ld b,2
        push af
        ld a,(col_red)
        ld c,a
        pop af
        jp part_burst
.walk:  ld hl,(STG_SPR+0)
        ld a,8
        call anim2
        jr z,dobj
        ld hl,(STG_SPR+2)
        jr dobj

d_skel: ld a,(ix+1)               ; 0 whole, 1 headless
        add a,a
        add a,a
        ld e,a
        ld a,8
        call anim2
        jr z,$+4
        inc e
        inc e
        ld d,0
        ld hl,STG_SPR+8
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr dobj

d_bat:  ld hl,(STG_SPR+16)
        ld a,4
        call anim2
        jr z,dobj
        ld hl,(STG_SPR+18)
        jr dobj

d_ghost:
        ; simulated transparency: visible two frames in three
        ld a,(frame_no)
        ld b,a
.m3:    sub 3
        jr nc,.m3
        add a,3
        or a
        ret z
        ld hl,(STG_SPR+24)
        ld a,8
        call anim2
        jr z,dobj
        ld hl,(STG_SPR+26)
        jr dobj

d_crow: ld hl,(STG_SPR+32)
        ld a,(ix+1)
        or a
        jr z,dobj
        ld a,2
        call anim2
        jr z,dobj
        ld hl,(STG_SPR+34)
        jr dobj

d_imp:  ld hl,(STG_SPR+48)
        ld a,4
        call anim2
        jr z,dobj
        ld hl,(STG_SPR+50)
        jr dobj

d_plant:
        ld hl,(STG_SPR+40)
        ld a,(ix+8)
        cp 50
        jr c,dobj
        ld hl,(STG_SPR+42)
        jr dobj

d_chest:
        ld hl,S_CHEST_0
        ld a,(ix+1)
        or a
        jr z,dobj
        ld hl,S_CHEST_1
        jr dobj

d_item: ld a,(ix+12)
        add a,a
        ld e,a
        ld d,0
        ld hl,ITEMSPR
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ; coins spin
        ld a,(ix+12)
        or a
        jr nz,.nc
        ld a,4
        call anim2
        jr z,.nc
        ld hl,S_COIN_1
.nc:    ; gentle bob
        ld a,(ix+10)
        and 16
        ld a,(ix+4)
        jr z,$+3
        dec a
        ld e,(ix+2)
        ld d,(ix+3)
        ld c,0
        jp draw_world
ITEMSPR: dw S_COIN_0,S_JEWEL_0,S_ARMOUR_0,S_POTION_0,S_WLANCE_0,S_WDAGGER_0,S_WAXE_0,S_WTORCH_0,S_HEART_0

d_check:
        ld hl,S_CHECKPT_0
        ld a,(ix+1)
        or a
        jr z,dobj
        ld a,4
        call anim2
        jr z,dobj
        ld hl,S_CHECKPT_1
        jr dobj

d_torch:
        ld hl,S_FLAME_0
        ld a,2
        call anim2
        jr z,dobj
        ld hl,S_FLAME_1
        jr dobj

d_debris:
        ld hl,S_PIECES_0
        ld a,2
        call anim2
        jr z,dobj
        ld hl,S_PIECES_1
        jr dobj

d_fire: ld hl,S_FIREBALL_0
        jr dobj

d_skull:
        ld hl,(STG_HEAD)
        jr dobj

d_sun:  ld hl,S_SUNSTONE_0
        ld a,(frame_no)
        and 4
        jp z,dobj
        ld hl,S_SUNSTONE_1
        jp dobj
