; =====================================================================
;  ents.asm - enemies, platforms, items
;  pool entry (16 bytes):
;   +0 type +1 state +2/3 x +4 y +5 vx +6 vy +7 timer +8 frame +9 dir
;   +10 spawn idx +11/12 x0 +13 y0 +14 range +15 spare
; =====================================================================
platix  dw 0
spawnpend db 0

; ---------------------------------------------------------------- spawning
spawn_scan:
        ; Records spawn only in a band just off either screen edge, so an
        ; enemy never appears out of thin air in view (a record whose slot was
        ; full, or whose enemy wandered off, waits until it is off-screen).
        ; After a (re)spawn or a camera snap, spawnall lets everything in.
        ld hl,(camx)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l                    ; camera tile x
        push hl
        ld de,20
        add hl,de
        ld (tmp2),hl            ; window right
        pop hl
        push hl
        ld de,16
        add hl,de
        ld (svhi),hl            ; last tile that could be on screen
        pop hl
        ld de,3
        or a
        sbc hl,de
        jr nc,.c1
        ld hl,0
.c1:    ld (svlo),hl            ; first tile that could be on screen
        ld de,2
        or a
        sbc hl,de
        jr nc,.c0
        ld hl,0
.c0:    ld (tmp1),hl            ; window left
        ld iy,ENTLIST
        ld c,0                  ; record index
.l:     ld a,(iy+0)
        and (iy+1)
        cp $FF
        jr z,.end
        ld a,(iy+3)
        cp E_START
        jr z,.n
        cp E_GLOW
        jr nz,.v
        ld a,(iy+4)
        or a
        jr nz,.n                ; hidden in a bonus block
.v:     ld b,0
        ld hl,ENTST
        add hl,bc
        ld a,(hl)
        or a
        jr nz,.n
        ; within window?
        ld e,(iy+0)
        ld d,(iy+1)
        ld hl,(tmp1)
        ex de,hl
        or a
        sbc hl,de
        jr c,.n
        ld e,(iy+0)
        ld d,(iy+1)
        ld hl,(tmp2)
        or a
        sbc hl,de
        jr c,.n
        ld a,(spawnall)
        or a
        jr nz,.go
        ld a,(iy+3)             ; logs and lifts are scenery: always let them
        cp E_PLATH              ; in, even on screen (a missing one is far
        jr z,.go                ; worse than one appearing)
        cp E_PLATV
        jr z,.go
        ld e,(iy+0)             ; on screen? then not yet
        ld d,(iy+1)
        ld hl,(svlo)
        ex de,hl
        or a
        sbc hl,de
        jr c,.go
        ld e,(iy+0)
        ld d,(iy+1)
        ld hl,(svhi)
        or a
        sbc hl,de
        jr nc,.n
.go:    push bc
        call spawn_rec
        pop bc
.n:     ld de,5
        add iy,de
        inc c
        jr .l
.end:   xor a
        ld (spawnall),a
        ret
svlo    dw 0
svhi    dw 0
spawnall db 1

; spawn_rec: IY = record, C = record index
spawn_rec:
        call free_slot
        ret nc
        ld b,0
        ld hl,ENTST
        add hl,bc
        ld (hl),1
        ld (ix+10),c
        ld a,(iy+3)
        ld (ix+0),a
        ld l,(iy+0)
        ld h,(iy+1)
        add hl,hl
        add hl,hl
        add hl,hl
        ld (ix+2),l
        ld (ix+3),h
        ld (ix+11),l
        ld (ix+12),h
        ld a,(iy+2)
        add a,a
        add a,a
        add a,a
        ld (ix+4),a
        ld (ix+13),a
        ld a,(iy+4)
        add a,a
        add a,a
        add a,a
        ld (ix+14),a
        ld (ix+9),1             ; face left (towards an approaching player)
        ld a,(ix+0)
        cp E_MAG
        jr nz,.nm
        ld (ix+15),15           ; magpies start their patrol at home, not 30px off
.nm:    cp E_BOSS
        jp z,boss_init
        cp E_PLATH
        jr nz,.n1
        ld (ix+9),0
.n1:    cp E_PLATV
        ret nz
        ld (ix+9),1
        ret

; free_slot -> IX = free pool slot, carry set if found
free_slot:
        ld ix,POOL
        ld b,NENT
        ld de,16
.l:     ld a,(ix+0)
        or a
        jr z,.f
        add ix,de
        djnz .l
        or a
        ret
.f:     push ix
        pop hl
        ld b,16
.z:     ld (hl),0
        inc hl
        djnz .z
        scf
        ret

; reveal_bonus: HL = map address of a bonus block -> pop a Wattle Glow out
reveal_bonus:
        ld de,MAP
        or a
        sbc hl,de
        ld c,12
        call div16_8
        push af
        push hl
        call free_slot
        pop hl
        pop bc                  ; b = ty
        ret nc
        add hl,hl
        add hl,hl
        add hl,hl
        ld (ix+2),l
        ld (ix+3),h
        ld a,b
        add a,a
        add a,a
        add a,a
        ld (ix+4),a
        sub 10
        ld (ix+13),a            ; rise to just above the block
        ld (ix+0),E_GLOW
        ld (ix+10),$FF
        ret

; ---------------------------------------------------------------- update
ents_update:
        xor a
        ld (ridedx),a
        ld (ridedy),a
        ld a,(frame)
        and 3
        jr nz,.sp1
        ld a,1
        ld (spawnpend),a
.sp1:   ld a,(colgen)           ; not on frames that rendered a ring column
        or a
        jr nz,.nsc
        ld a,(spawnpend)
        or a
        jr z,.nsc
        xor a
        ld (spawnpend),a
        call spawn_scan
.nsc:
        ld ix,POOL
        ld b,NENT
.l:     ld a,(ix+0)
        or a
        jr z,.n
        push bc
        call ent_far
        jr c,.desp
        ld a,(ix+0)
        add a,a
        ld e,a
        ld d,0
        ld hl,ent_jt-2
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call jp_hl
        ld a,(ix+0)
        or a
        call nz,ent_touch
        jr .nn
.desp:  call ent_release
.nn:    pop bc
.n:     ld de,16
        add ix,de
        djnz .l
        ret
jp_hl:  jp (hl)

ent_jt: dw ant_upd, mag_upd, drop_upd, toad_upd, plath_upd, platv_upd
        dw glow_upd, oneup_upd, ent_nop, worm_upd, boom_upd, spit_upd, boss_upd
ent_nop: ret

; release a slot; spawn record becomes available again unless dead
ent_release:
        ld (ix+0),0
        ld a,(ix+10)
        cp $FF
        ret z
        ld e,a
        ld d,0
        ld hl,ENTST
        add hl,de
        ld a,(hl)
        cp 2
        ret z
        ld (hl),0
        ret

; carry set if the entity is far outside the camera
ent_far:
        ld l,(ix+2)
        ld h,(ix+3)
        call .far1
        ret nc                  ; near: keep
        ld a,(ix+0)             ; moving logs/platforms stay while their home
        cp E_PLATH              ; point is near too: otherwise one could vanish
        scf                     ; and not come back until that point had
        ret nz                  ; scrolled off screen
        ld l,(ix+11)
        ld h,(ix+12)
.far1:  ld de,(camx)
        or a
        sbc hl,de               ; sx
        ld de,48
        add hl,de               ; sx+48 must be 0..224
        bit 7,h
        jr nz,.far
        ld a,h
        or a
        jr nz,.far
        ld a,l
        cp 224
        ccf
        ret
.far:   scf
        ret

; ---------------------------------------------------------------- behaviours
; tile probe for entities: HL = x, A = y -> attr
ent_tile:
        push bc
        push de
        call tile_at
        pop de
        pop bc
        ret

anim2:  ; toggle frame bit every 4 frames -> A = 0/1
        ld a,(frame)
        rrca
        rrca
        and 1
        ret

ant_upd:
        call anim2
        ld (ix+8),a
        ld a,(frame)
        and 1
        jr nz,.go               ; ants scuttle at 1px every other frame... plus bursts
        ld a,(ix+7)
        inc (ix+7)
        and 3
        ret nz
.go:    ; probe ahead
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,8
        bit 0,(ix+9)
        jr z,.r
        ld de,-1
.r:     add hl,de
        push hl
        ld a,(ix+4)
        add a,4
        call ent_tile
        pop hl
        and A_SOLID
        jr nz,.turn
        ld a,(ix+4)
        add a,9
        call ent_tile
        and A_SOLID|A_ONEWAY
        jr z,.turn
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,1
        bit 0,(ix+9)
        jr z,.m
        ld de,-1
.m:     add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ret
.turn:  ld a,(ix+9)
        xor 1
        ld (ix+9),a
        ret

mag_upd:
        ld a,(frame)
        rrca
        and 1
        ld (ix+8),a
        ld a,(ix+1)
        or a
        jr z,.patrol
        dec a
        jp z,.dive
        ; rising back home
        dec (ix+4)
        ld a,(ix+4)
        cp (ix+13)
        ret nz
        ld (ix+1),0
        ld (ix+7),40            ; cooldown
        ret
.patrol:
        inc (ix+15)
        ld a,(ix+15)
        ; triangle wave -24..+24 over 96 frames
        and 63
        cp 32
        jr c,.t1
        cpl
        and 31
        ld b,a
        ld a,1
        ld (ix+9),a
        ld a,b
        jr .t2
.t1:    ld (ix+9),0
.t2:    sub 16
        add a,a                 ; -32..+30
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(ix+11)
        ld h,(ix+12)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ; bob
        ld a,(ix+15)
        rrca
        rrca
        rrca
        and 3
        add a,(ix+13)
        ld (ix+4),a
        ; cooldown, then watch for Bix below
        ld a,(ix+7)
        or a
        jr z,.watch
        dec (ix+7)
        ret
.watch: ld a,(pstate)
        cp ST_BURROW
        ret z
        call dx_player          ; HL = player x - x (signed)
        ld a,h
        inc a
        cp 2
        ret nc
        ld a,l
        add a,40
        cp 80
        ret nc
        ld a,(ppy)
        sub (ix+4)
        ret c
        cp 8
        ret c
        ; swoop!
        ld (ix+1),1
        ld a,(ppy)
        ld (ix+14),a            ; target y
        ld a,l
        bit 7,a
        ld a,2
        ld (ix+9),0
        jr z,.d1
        ld a,-2
        ld (ix+9),1
.d1:    ld (ix+5),a
        ld a,SFX_SWOOP
        jp sfx_play
.dive:  ld a,(ix+5)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        inc (ix+4)
        inc (ix+4)
        ld a,(ix+4)
        cp (ix+14)
        jr nc,.up
        ld l,(ix+2)
        ld h,(ix+3)
        ld a,(ix+4)
        add a,8
        call ent_tile
        and A_SOLID
        ret z
.up:    ld (ix+1),2
        ld a,(ix+2)
        ld (ix+11),a
        ld a,(ix+3)
        ld (ix+12),a
        ret

drop_upd:
        ld a,(ix+1)
        or a
        jr nz,.fall
        ld (ix+8),0
        ld a,(ix+7)             ; cooldown (pistons)
        or a
        jr z,.armed
        dec (ix+7)
        ret
.armed: call dx_player
        ld a,h
        inc a
        cp 2
        ret nc
        ld a,l
        add a,14
        cp 28
        ret nc
        ld a,(ppy)
        sub (ix+4)
        ret c
        ld (ix+1),1
        ld (ix+6),0
        ld a,SFX_SWOOP
        jp sfx_play
.fall:  dec a
        jr z,.fall1
        dec a
        jp z,.walk
        ; state 3: piston retracting
        ld (ix+8),0
        dec (ix+4)
        ld a,(ix+4)
        cp (ix+13)
        ret nz
        ld (ix+1),0
        ld (ix+7),20
        ret
.fall1: ld (ix+8),1
        ld a,(ix+6)
        cp 6
        jr nc,.f1
        inc (ix+6)
.f1:    ld a,(ix+4)
        add a,(ix+6)
        ld (ix+4),a
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,4
        add hl,de
        ld a,(ix+4)
        add a,8
        call ent_tile
        and A_SOLID|A_ONEWAY
        ret z
        ld a,(ix+4)
        add a,8
        and $F8
        sub 8
        ld (ix+4),a
        ld (ix+1),2
        ld a,3
        ld (shake),a
        ld a,(lv_world)
        cp 3
        jr nz,.nw3
        ld (ix+1),3             ; factory: crusher pistons retract
        ld a,SFX_STOMP
        jp sfx_play
.nw3:   cp 2
        jr z,.shat
        cp 4
        jr z,.shat
        cp 5
        ret nz
.shat:  ; caverns / sky: stalactites and hail shatter on impact
        ld (ix+0),E_BOOM
        ld (ix+7),0
        call mark_dead
        ld a,SFX_BREAK
        jp sfx_play
.walk:  call anim2
        ld (ix+8),a
        ld a,(frame)
        and 1
        ret z
        call dx_player
        bit 7,h
        ld de,1
        ld (ix+9),0
        jr z,.w1
        ld de,-1
        ld (ix+9),1
.w1:    push de
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        bit 7,d
        jr nz,.w2
        ld de,7
        add hl,de
.w2:    ld a,(ix+4)
        add a,4
        call ent_tile
        pop de
        and A_SOLID
        ret nz
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ret

toad_upd:
        ld a,(ix+1)
        or a
        jr nz,.air
        ld (ix+8),0
        ld a,(ix+7)
        inc (ix+7)
        cp 36
        ret c
        ; hop towards Bix
        ld (ix+7),0
        ld (ix+1),1
        ld (ix+6),-6
        call dx_player
        bit 7,h
        ld a,1
        ld (ix+9),0
        jr z,.h
        ld a,-1
        ld (ix+9),1
.h:     ld (ix+5),a
        ld a,SFX_HOP
        jp sfx_play
.air:   ld (ix+8),1
        ld a,(ix+5)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        push hl
        ld de,4
        add hl,de
        ld a,(ix+4)
        add a,4
        call ent_tile
        pop hl
        and A_SOLID
        jr nz,.nx
        ld (ix+2),l
        ld (ix+3),h
.nx:    ld a,(frame)
        and 1
        jr z,.ny
        inc (ix+6)
.ny:    ld a,(ix+4)
        add a,(ix+6)
        ld (ix+4),a
        bit 7,(ix+6)
        ret nz
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,4
        add hl,de
        ld a,(ix+4)
        add a,8
        call ent_tile
        and A_SOLID|A_ONEWAY
        ret z
        ld a,(ix+4)
        add a,8
        and $F8
        sub 8
        ld (ix+4),a
        ld (ix+1),0
        ret

plath_upd:
        ld a,(frame)            ; half speed: move on every other frame
        and 1
        ret nz
        ld e,1
        bit 0,(ix+9)
        jr z,.r
        ld e,-1
.r:     ld a,e
        ld d,0
        bit 7,e
        jr z,.r1
        dec d
.r1:    ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        call plat_ride
        ld (ridedx_tmp),a
        ld a,(ridedx_tmp)
        or a
        jr z,.nr
        ld a,e                  ; carry Bix a whole pixel (px16 is 1/16 pixel)
        add a,a
        add a,a
        add a,a
        add a,a
        ld (ridedx),a
.nr:    ; bounds
        ld l,(ix+2)
        ld h,(ix+3)
        ld e,(ix+11)
        ld d,(ix+12)
        or a
        sbc hl,de
        jr z,.go_r
        jr c,.go_r
        ld a,h
        or a
        jr nz,.go_l
        ld a,l
        cp (ix+14)
        ret c
.go_l:  ld (ix+9),1
        ret
.go_r:  ld (ix+9),0
        ret
ridedx_tmp db 0

; plat_ride -> A = 1 if Bix is standing on this platform
plat_ride:
        ld a,(onplat)
        or a
        ret z
        push ix
        pop hl
        ld bc,(platix)
        or a
        sbc hl,bc
        ld a,0
        ret nz
        inc a
        ret

platv_upd:
        ld a,(frame)
        and 1
        ret z
        ld a,1
        bit 0,(ix+9)
        jr z,.d
        ld a,-1
.d:     ld e,a
        add a,(ix+4)
        ld (ix+4),a
        push de
        call plat_ride
        pop de
        or a
        jr z,.nr
        ld a,e
        ld (ridedy),a
.nr:    ld a,(ix+4)
        cp (ix+13)
        jr nc,.up
        ld b,a
        ld a,(ix+13)
        sub (ix+14)
        cp b
        ret c
        ld (ix+9),0             ; reached the top: go down
        ret
.up:    ld (ix+9),1             ; reached the bottom: go up
        ret

glow_upd:
        call anim2
        ld (ix+8),a
        ld a,(ix+4)
        cp (ix+13)
        ret z
        ret c
        dec (ix+4)
        ret

oneup_upd:
        ld (ix+8),0
        ret

; worm / witchetty grub: hides in the ground, pops up when Bix comes near
worm_upd:
        ld a,(ix+1)
        or a
        jr nz,.up
        ld a,(ix+7)
        or a
        jr z,.w
        dec (ix+7)
        ret
.w:     call dx_player
        ld a,h
        inc a
        cp 2
        ret nc
        ld a,l
        add a,36
        cp 72
        ret nc
        ld (ix+1),1
        ld (ix+7),55
        ld a,SFX_HOP
        call sfx_play
        ld l,(ix+2)
        ld h,(ix+3)
        ld (tmp2),hl
        ld a,(ix+4)
        ld (tmp3),a
        ld a,1
        ld (pgrav),a
        ld hl,(tmp2)
        inc hl
        inc hl
        ld a,(tmp3)
        add a,6
        ld bc,$FFFD
        ld de,$0308
        call spawn_part
        ld hl,(tmp2)
        ld de,5
        add hl,de
        ld a,(tmp3)
        add a,6
        ld bc,$01FD
        ld de,$0308
        jp spawn_part
.up:    call anim2
        ld (ix+8),a
        call dx_player
        ld a,h
        rla
        and 1
        ld (ix+9),a
        dec (ix+7)
        ret nz
        ld (ix+1),0
        ld (ix+7),60
        ret

spit_upd:
        ld a,(frame)
        and 1
        ld (ix+8),0
        ld a,(ix+5)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ; falling bolts
        ld a,(ix+6)
        or a
        jr z,.nv
        add a,(ix+4)
        ld (ix+4),a
        cp 100
        jr nc,.gone
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,4
        add hl,de
        add a,8
        call ent_tile
        and A_SOLID
        jr z,.nv
        ld (ix+0),E_BOOM
        ld (ix+7),0
        ret
.nv:    ld l,(ix+2)
        ld h,(ix+3)
        ; walls of the arena
        ld a,h
        or a
        jr nz,.gone
        ld a,l
        cp 6
        jr c,.gone
        cp 118
        ret c
.gone:  ld (ix+0),0
        ret

boom_upd:
        inc (ix+7)
        ld a,(ix+7)
        cp 7
        ret c
        ld (ix+0),0
        ret

; HL = player x - entity x
dx_player:
        ld hl,(ppx)
        ld e,(ix+2)
        ld d,(ix+3)
        or a
        sbc hl,de
        ret

; ---------------------------------------------------------------- collisions
ent_touch:
        ld a,(pstate)
        cp ST_DIE
        ret z
        cp ST_WIN
        ret z
        ld a,(ix+0)
        cp E_PLATH
        ret z
        cp E_PLATV
        ret z
        cp E_BOOM
        ret z
        cp E_BOSS
        ret z
        cp E_WORM
        jr nz,.nw
        ld a,(ix+1)
        or a
        ret z
.nw:    ; boxes: player x+1..x+6 , y..y+9 ; entity x+1..x+6 , y+1..y+7
        call dx_player          ; px - ex
        ld a,h
        inc a
        cp 2
        ret nc
        ld a,l
        add a,6
        cp 12
        ret nc
        ld a,(ppy)
        sub (ix+4)
        add a,9                 ; (py - ey) in -9..7 overlaps
        cp 17
        ret nc
        ld a,(ix+0)
        cp E_GLOW
        jr z,.glow
        cp E_ONEUP
        jr z,.oneup
        ld a,(pstate)
        cp ST_BURROW
        ret z
        ld a,(shield)
        ld b,a
        ld a,(burstt)
        or b
        jr nz,.kill
        ld a,(vy)
        bit 7,a
        jr nz,.hurt
        or a
        jr z,.hurt
        ld a,(ppy)
        add a,10
        sub (ix+4)
        cp 6
        jr nc,.hurt
        ; stomp!
        ld a,256-STOMPV
        ld (vy),a
        ld a,(keys)
        and K_J
        jr z,.kill
        ld a,256-STOMPV-24
        ld (vy),a
.kill:  ld (ix+0),E_BOOM
        ld (ix+7),0
        ld (ix+8),0
        call mark_dead
        ld a,$10
        call add_score_a        ; 100 points
        ld a,SFX_STOMP
        jp sfx_play
.hurt:  jp player_hurt
.glow:  ld a,(lv_world)
        cp 4
        jr nz,.gs
        ld a,250                ; Skyward Isles: Wattle Wings (double jump)
        ld (wings),a
        jr .gw
.gs:    ld a,250
        ld (shield),a
.gw:
        ld (ix+0),0
        call mark_dead
        ld a,SFX_POWER
        jp sfx_play
.oneup: ld hl,lives
        inc (hl)
        ld a,1
        ld (hudflag),a
        ld (ix+0),0
        call mark_dead
        ld a,SFX_ONEUP
        jp sfx_play

mark_dead:
        ld a,(ix+10)
        cp $FF
        ret z
        ld e,a
        ld d,0
        ld hl,ENTST
        add hl,de
        ld (hl),2
        ret

; ---------------------------------------------------------------- drawing
ents_draw:
        ld ix,POOL
        ld b,NENT
.l:     ld a,(ix+0)
        or a
        jr z,.n
        push bc
        call ent_draw1
        pop bc
.n:     ld de,16
        add ix,de
        djnz .l
        ret

ent_frame:      ; type -> base frame in etab order
        db 0, EF_ANT1, EF_MAG1, EF_DROP1, EF_TOAD1, 0, 0, EF_GLOW1, EF_ONEUP, 0
        db EF_WORM1, EF_BOOM, EF_FLY, 0

ent_draw1:
        ld a,(ix+0)
        cp E_BOSS
        jp z,boss_draw
        cp E_WORM
        jr nz,.d0
        ld a,(ix+1)
        or a
        ret z
.d0:    ld l,(ix+2)
        ld h,(ix+3)
        ld de,(camx)
        or a
        sbc hl,de
        ld a,l
        and 3
        ld c,a                  ; phase
        sra h
        rr l
        sra h
        rr l
        ld a,h
        inc a
        cp 2
        ret nc
        ld b,l                  ; byte column
        ld a,(ix+0)
        cp E_PLATH
        jr z,.plat
        cp E_PLATV
        jr z,.plat
        ld e,a
        ld d,0
        ld hl,ent_frame
        add hl,de
        ld a,(ix+0)
        cp E_BOOM
        ld a,(hl)
        jr nz,.nb
        ld e,a
        ld a,(ix+7)
        and 2
        ld a,e
        jr z,.nb2
.nb:    add a,(ix+8)
.nb2:   add a,a
        add a,(ix+9)
        add a,a
        add a,a
        add a,c
        add a,a
        ld e,a
        ld d,0
        ld hl,etab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld c,b
        ld a,(camy)
        ld b,a
        ld a,(ix+4)
        sub b
        ld b,8
        ld e,3
        jp drawspr
.plat:  ld a,c
        add a,a
        ld e,a
        ld d,0
        ld hl,qtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld c,b
        ld a,(camy)
        ld b,a
        ld a,(ix+4)
        sub b
        ld b,4
        ld e,7
        jp drawspr
