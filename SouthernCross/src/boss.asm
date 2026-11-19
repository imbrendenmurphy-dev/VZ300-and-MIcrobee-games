; ============================================================================
;  BOSSES - one engine, a definition per stage (in the stage pack)
;
;  A boss is a body sprite plus up to five parts.  ETAB slot 0 is the core
;  (T_CORE, the body's hit box), slots 1-5 the parts (T_POD).  The definition
;  says how the parts are arranged and how the boss moves and fights:
;
;   parts:  ORBIT  round the body on banded arms (Crown of Thorns, Rust Heart)
;           FIXED  at offsets on the body (Ice Citadel, Skyhook Carrier)
;           LEGS   fixed, stomping up and down in turn (Cassowary Walker)
;           TRAIL  following the head's path like a train (Drill Train)
;   move:   SWAY side to side, WALK (sway + bob), SNAKE (sweeping loops),
;           PARK (holds station)
;   parts are guns (aimed shots or three-way) or indestructible shields
;   the core may be armoured until every gun is gone, then the shell opens
;   and the core fires five-way spreads or eight-way rings
; ============================================================================

; definition layout (copied to BD at the start of the fight)
BD_BODYC  equ 0         ; dw body sprite: closed
BD_BODYO0 equ 2         ; dw open, frame 0
BD_BODYO1 equ 4         ; dw open, frame 1
BD_BW     equ 6         ; body width, height (pixels)
BD_BH     equ 7
BD_NP     equ 8         ; number of parts (0-5)
BD_PMODE  equ 9         ; 0 orbit 1 fixed 2 legs 3 trail
BD_PSPR0  equ 10        ; dw part sprites
BD_PSPR1  equ 12
BD_PSPRW  equ 14
BD_PW     equ 16
BD_PH     equ 17
BD_PHP    equ 18
BD_SHIELD equ 19        ; 1 = parts are indestructible shields (don't fire)
BD_CHP    equ 20
BD_ARMOUR equ 21        ; 1 = core armoured until the parts are gone
BD_MOVE   equ 22        ; 0 sway 1 walk 2 snake 3 park
BD_PFIRE  equ 23        ; 0 aimed 1 three-way
BD_CFIRE  equ 24        ; 0 five-way 1 ring of eight
BD_LIMBS  equ 25
BD_SPIN   equ 26
BD_FINT   equ 27        ; frames between part shots (full strength)
BD_CDX    equ 28        ; core hit box within the body
BD_CDY    equ 29
BD_CW     equ 30
BD_CH     equ 31
BD_OFS    equ 32        ; 5 x (dx, dy) for fixed / legs
BD_PARKY  equ 42        ; y16 it settles at
BD_XMIN   equ 43
BD_XMAX   equ 44
BD_LAUNCH equ 45        ; 1 = launches drone flights (the carrier)
BDSIZE    equ 46

M_ORBIT equ 0
M_FIXED equ 1
M_LEGS  equ 2
M_TRAIL equ 3

boss_init:
        ; clear the decks: no stragglers or bullets during the fight
        ld hl,ETAB
        ld de,ETAB+1
        ld bc,NEN*EOSIZE-1
        ld (hl),0
        ldir
        call clear_ebullets
        ld hl,(H_BOSSDEF)       ; this stage's boss
        ld de,BD
        ld bc,BDSIZE
        ldir
        ld a,1
        ld (boss_ph),a
        ld a,(BD+BD_XMIN)
        ld b,a
        ld a,(BD+BD_XMAX)
        add a,b
        srl a
        and $FE
        ld (bx),a
        xor a
        ld (by),a
        ld (bang),a
        ld (bvolley),a
        ld (bnext),a
        ld (bsway),a
        ld (bhist),a
        ld hl,BHIST             ; the trail starts bunched at the body
        ld b,64
.bh:    ld a,(bx)
        ld (hl),a
        inc hl
        ld (hl),0
        inc hl
        djnz .bh
        ld a,(BD+BD_SPIN)
        ld (bspeed),a
        ld a,1
        ld (bdir),a
        ld a,(BD+BD_NP)
        ld (barms),a
        ld a,60
        ld (bfire_tm),a
        ld a,90
        ld (cfire_tm),a
        ld (blaunch_tm),a
        ld a,255                ; the carrier's drone flights never drop shards
        ld (GRP+6*GRSIZE),a
        ; the core
        ld ix,ETAB
        ld (ix+EO_T),T_CORE
        ld a,(BD+BD_CHP)
        ld (ix+EO_HP),a
        ld a,(BD+BD_CW)
        ld (ix+EO_W),a
        ld a,(BD+BD_CH)
        add a,2
        ld (ix+EO_H2),a
        ld (ix+EO_G),7
        ; the parts
        ld a,(BD+BD_NP)
        or a
        jr z,.np
        ld b,a
.p:     ld de,EOSIZE
        add ix,de
        ld (ix+EO_T),T_POD
        ld a,(BD+BD_PHP)
        ld (ix+EO_HP),a
        ld a,(BD+BD_PW)
        ld (ix+EO_W),a
        ld a,(BD+BD_PH)
        add a,2
        ld (ix+EO_H2),a
        ld (ix+EO_G),7
        djnz .p
.np:    jp boss_place

ORBANG: db 0,51,102,154,205

; every frame: move, place the parts, schedule fire
upd_boss:
        ld a,(boss_ph)
        or a
        ret z
        cp 4
        jp z,.dying
        cp 1
        jr nz,.fight
        ; arriving: drop in from above the screen
        ld a,(anim)
        and 1
        jr z,.sp
        ld hl,by
        inc (hl)
        ld a,(BD+BD_PARKY)
        cp (hl)
        jr nz,.sp
        ld a,2
        ld (boss_ph),a
.sp:    ld hl,bang
        inc (hl)
        call boss_hist
        jp boss_place
.fight: ld hl,bsway
        inc (hl)
        ld a,(boss_ph)          ; faster once the shell is open
        cp 3
        jr nz,.mv
        inc (hl)
.mv:    ld a,(BD+BD_MOVE)
        cp 2
        jr z,.snake
        cp 3
        jr z,.spin
        ; sway (and walk): 2-pixel steps every 4 frames (2 when open)
        ld a,(boss_ph)
        cp 3
        ld a,(hl)
        jr z,.fast
        and 3
        jr nz,.walk
.fast:  ld a,(bdir)
        add a,a
        ld b,a
        ld a,(bx)
        add a,b
        ld (bx),a
        ld hl,BD+BD_XMIN
        cp (hl)
        jr c,.flip
        inc hl
        cp (hl)
        jr c,.walk
.flip:  ld a,(bdir)
        neg
        ld (bdir),a
.walk:  ld a,(BD+BD_MOVE)
        cp 1
        jr nz,.spin
        ld a,(bsway)            ; bob up and down with the stride
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,PODDY
        add hl,de
        ld a,(hl)
        sra a
        sra a
        ld b,a
        ld a,(BD+BD_PARKY)
        add a,b
        ld (by),a
        jr .spin
.snake: ; sweeping loops across the top of the screen
        ld a,(bsway)
        ld e,a
        ld d,0
        ld hl,PODDX
        add hl,de
        ld a,(BD+BD_XMIN)
        ld b,a
        ld a,(BD+BD_XMAX)
        add a,b
        srl a
        add a,(hl)
        and $FE
        ld (bx),a
        ld a,(bsway)
        add a,a
        add a,(hl)              ; (a lopsided figure eight)
        ld e,a
        ld hl,PODDY
        add hl,de
        ld a,(hl)
        sra a
        ld b,a
        ld a,(BD+BD_PARKY)
        add a,b
        ld (by),a
.spin:  ld a,(bspeed)
        ld b,a
        ld a,(bang)
        add a,b
        ld (bang),a
        call boss_hist
        call boss_place
        ; the carrier sends out drone flights
        ld a,(BD+BD_LAUNCH)
        or a
        call nz,boss_launch
        ; the core fires on its own clock once it is exposed
        call core_exposed
        jr nc,.pf
        ld hl,cfire_tm
        dec (hl)
        jr nz,.pf
        ld (hl),62
        ld a,(barms)            ; faster when it is all that's left
        or a
        jr nz,.cf
        ld (hl),46
.cf:    ld ix,ETAB
        ld (ix+EO_FC),14
.pf:    ; the guns: each glints, then fires, in turn
        ld a,(BD+BD_SHIELD)
        or a
        ret nz
        ld a,(barms)
        or a
        ret z
        ld hl,bfire_tm
        dec (hl)
        ret nz
        ld a,(BD+BD_NP)
        ld b,a
        ld a,(barms)
        sub b
        ld b,a                  ; -(parts lost)
        add a,a
        add a,b
        add a,a                 ; -6 each
        ld b,a
        ld a,(BD+BD_FINT)
        add a,b
        cp 14
        jr nc,$+4
        ld a,14
        ld (hl),a
        ld a,(bnext)
        ld c,a
        ld a,(BD+BD_NP)
        ld b,a
.nx:    ld a,c
        inc a
        ld hl,BD+BD_NP
        cp (hl)
        jr z,.ok
        jr c,.ok
        ld a,1
.ok:    ld c,a
        call slot_ix
        ld a,(ix+EO_T)
        cp T_POD
        jr z,.got
        djnz .nx
        ret
.got:   ld a,c
        ld (bnext),a
        ld (ix+EO_FC),10
        ret
.dying: ld a,(anim)             ; explosions all over it
        and 3
        jr nz,.dd
        call rand
        and 31
        ld b,a
        ld a,(bx)
        add a,b
        sub 6
        jr nc,$+3
        xor a
        ld b,a
        call rand
        and 15
        ld c,a
        ld a,(by)
        add a,c
        ld c,a
        call add_expl
        ld a,(anim)
        and 15
        ld a,FX_BIGX
        call z,play_sfx
.dd:    ld hl,bdie_tm
        dec (hl)
        ret nz
        xor a
        ld (boss_ph),a
        ld a,3                  ; stage clear
        ld (mode),a
        ld (flash_tm),a
        xor a
        ld (tl_flags),a
        ld hl,0
        ld (clear_tm),hl
        ld (mode_tm),hl
        call clear_ebullets
        ld hl,SONG_CLEAR
        jp play_song

; carry set if the core can be hurt now
core_exposed:
        ld a,(boss_ph)
        cp 3
        jr z,.y
        cp 2
        jr nz,.n
        ld a,(BD+BD_ARMOUR)
        or a
        jr z,.y
.n:     or a
        ret
.y:     scf
        ret

; remember where the body has been (for TRAIL parts): 64 entries
boss_hist:
        ld a,(bhist)
        inc a
        and 63
        ld (bhist),a
        add a,a
        ld e,a
        ld d,0
        ld hl,BHIST
        add hl,de
        ld a,(bx)
        ld (hl),a
        inc hl
        ld a,(by)
        ld (hl),a
        ret

; drone flights from the carrier's bays, every five seconds or so
boss_launch:
        ld hl,blaunch_tm
        dec (hl)
        ret nz
        ld (hl),125
        ld a,(boss_ph)
        cp 2
        ret nz
        ld a,T_DRONE
        ld (spawn_type),a
        ld hl,PATH_SWOOPR
        ld a,(bsway)
        and 64
        jr z,$+5
        ld hl,PATH_SWOOPL
        ld (spawn_path),hl
        ld a,6
        ld (spawn_grp),a
        ld a,(bx)
        add a,8
        ld (spawn_x),a
        ld b,3
.l:     push bc
        call spawn_enemy
        ld a,(spawn_x)
        add a,6
        ld (spawn_x),a
        pop bc
        djnz .l
        ret

; A = slot 0-5 -> IX
slot_ix:
        push de
        ld ix,ETAB
        or a
        jr z,.d
        ld de,EOSIZE
.l:     add ix,de
        dec a
        jr nz,.l
.d:     pop de
        ret

; put the core and the parts where the body (and the angle) say
boss_place:
        ld ix,ETAB
        ld a,(BD+BD_CDX)
        ld hl,bx
        add a,(hl)
        ld (ix+EO_X),a
        ld a,(BD+BD_CDY)
        ld hl,by
        add a,(hl)
        ld (ix+EO_Y),a
        ld a,(BD+BD_NP)
        or a
        ret z
        ld b,a
        ld c,0                  ; part number
.l:     push bc
        ld de,EOSIZE
        add ix,de
        ld a,(BD+BD_PMODE)
        cp M_FIXED
        jr z,.fixed
        cp M_LEGS
        jr z,.fixed
        cp M_TRAIL
        jr z,.trail
        ; ORBIT: centre + arm vector, five arms 51 apart
        ld e,c
        ld d,0
        ld hl,ORBANG
        add hl,de
        ld a,(hl)               ; five arms 51 apart
        ld hl,bang
        add a,(hl)
        ld e,a
        ld d,0
        ld hl,PODDX
        add hl,de
        ld a,(BD+BD_BW)
        srl a
        ld b,a
        ld a,(BD+BD_PW)
        srl a
        neg
        add a,b
        ld b,a                  ; bw/2 - pw/2
        ld a,(bx)
        add a,b
        add a,(hl)
        ld (ix+EO_X),a
        ld hl,PODDY
        add hl,de
        ld a,(BD+BD_BH)
        srl a
        ld b,a
        ld a,(BD+BD_PH)
        srl a
        neg
        add a,b
        ld b,a
        ld a,(by)
        add a,b
        add a,(hl)
        ld (ix+EO_Y),a
        jr .n
.fixed: ld a,c                  ; offsets from the body's corner
        add a,a
        ld e,a
        ld d,0
        ld hl,BD+BD_OFS
        add hl,de
        ld a,(bx)
        add a,(hl)
        ld (ix+EO_X),a
        inc hl
        ld a,(by)
        add a,(hl)
        ld (ix+EO_Y),a
        ld a,(BD+BD_PMODE)
        cp M_LEGS
        jr nz,.n
        ld a,c                  ; legs: alternate stomps
        rrca
        rrca                    ; odd parts half a stride later
        and $80
        ld b,a
        ld a,(bang)
        add a,a
        add a,a
        add a,b
        ld e,a
        ld d,0
        ld hl,PODDY
        add hl,de
        ld a,(hl)
        sra a
        sra a
        add a,(ix+EO_Y)
        ld (ix+EO_Y),a
        jr .n
.trail: ; where the body was (c+1)*12 frames ago
        ld a,c
        inc a
        ld b,a
        add a,a
        add a,b
        add a,a
        add a,a                 ; *12
        ld b,a
        ld a,(bhist)
        sub b
        and 63
        add a,a
        ld e,a
        ld d,0
        ld hl,BHIST
        add hl,de
        ld a,(BD+BD_BW)
        ld b,a
        ld a,(BD+BD_PW)
        neg
        add a,b
        srl a
        add a,(hl)
        ld (ix+EO_X),a
        inc hl
        ld a,(BD+BD_BH)
        ld b,a
        ld a,(BD+BD_PH)
        neg
        add a,b
        srl a
        add a,(hl)
        ld (ix+EO_Y),a
.n:     pop bc
        inc c
        dec b
        jp nz,.l
        ret

; a part (IX) fires when its glint runs out: aimed, or three-way
pod_fire:
        ld a,(ix+EO_FC)
        or a
        ret z
        dec (ix+EO_FC)
        ret nz
        ld a,(BD+BD_PW)
        srl a
        add a,(ix+EO_X)
        and $FE
        ld b,a
        ld a,(BD+BD_PH)
        add a,(ix+EO_Y)
        ld c,a
        ld a,(BD+BD_PFIRE)
        or a
        jp z,fire_at
        ld hl,SPREAD3
        ld a,3
        jp spread_fire

; the core (IX): five-way spreads or rings of eight, alternating sets
core_fire:
        ld a,(ix+EO_FC)
        or a
        ret z
        dec (ix+EO_FC)
        ret nz
        ld a,(BD+BD_CW)
        srl a
        add a,(ix+EO_X)
        and $FE
        ld b,a
        ld a,(BD+BD_CH)
        srl a
        add a,(ix+EO_Y)
        ld c,a
        ld a,(bvolley)
        xor 1
        ld (bvolley),a
        ld e,a
        ld a,(BD+BD_CFIRE)
        or a
        jr nz,.ring
        ld hl,SPREAD
        ld a,e
        or a
        jr z,.a
        ld hl,SPREAD+20
.a:     ld a,5
        jr spread_fire
.ring:  ld hl,RING8
        ld a,e
        or a
        jr z,.b
        ld hl,RING8+32
.b:     ld a,8
; A = count, HL = table of (vx, vy), from (B, C)
spread_fire:
        push af
        push hl
        push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl                  ; HL = vx, DE = vy
        call add_ebullet
        pop bc
        pop hl
        ld de,4
        add hl,de
        pop af
        dec a
        jr nz,spread_fire
        ret

; a part or the core has been destroyed (A = its type)
boss_part_killed:
        cp T_CORE
        jr z,.core
        ld hl,barms
        dec (hl)
        ld hl,bspeed
        inc (hl)
        ld a,(barms)
        or a
        ret nz
        ; all the guns gone: an armoured shell opens
        ld a,(BD+BD_ARMOUR)
        or a
        ret z
        ld a,3
        ld (boss_ph),a
        ld (flash_tm),a
        ld a,30
        ld (cfire_tm),a
        ld a,FX_BURST
        jp play_sfx
.core:  ld de,$5000             ; 5,000 + 5,000
        call add_score
        ld a,4
        ld (boss_ph),a
        ld a,90
        ld (bdie_tm),a
        ld (flash_tm),a
        call clear_ebullets
        ; any parts still alive go up with it
        ld ix,ETAB+EOSIZE
        ld b,5
.k:     ld a,(ix+EO_T)
        cp T_POD
        jr nz,.kn
        ld (ix+EO_T),0
        ld (ix+EO_W),0
        push bc
        ld b,(ix+EO_X)
        ld c,(ix+EO_Y)
        call add_expl
        pop bc
.kn:    ld de,EOSIZE
        add ix,de
        djnz .k
        ld a,FX_DIE
        jp play_sfx

; arms (limb dots) and the body, before the parts are drawn
boss_draw:
        ld a,(boss_ph)
        or a
        ret z
        cp 4
        jr nz,.limbs
        ld a,(anim)             ; dying: the body flickers
        and 2
        ret nz
        jp .body
.limbs: ld a,(BD+BD_LIMBS)
        or a
        jp z,.body
        ld ix,ETAB
        ld a,(BD+BD_NP)
        or a
        jp z,.body
        ld b,a
.l:     push bc
        ld de,EOSIZE
        add ix,de
        ld a,(ix+EO_T)
        cp T_POD
        jr nz,.n
        ; a banded chain of three segments, 11/16 .. 15/16 of the way out
        ld a,(BD+BD_BW)
        srl a
        ld hl,bx
        add a,(hl)
        ld (lb_cx),a
        ld a,(BD+BD_BH)
        srl a
        ld hl,by
        add a,(hl)
        ld (lb_cy),a
        ld a,(BD+BD_PW)
        srl a
        add a,(ix+EO_X)
        ld hl,lb_cx
        sub (hl)
        ld (lb_dx),a
        ld a,(BD+BD_PH)
        srl a
        add a,(ix+EO_Y)
        ld hl,lb_cy
        sub (hl)
        ld (lb_dy),a
        ld a,(lb_dx)
        ld hl,lb_x
        call lb_parts
        ld a,(lb_dy)
        ld hl,lb_y
        call lb_parts
        ld hl,lb_x+1
        ld de,lb_y+1
        ld b,3
.ld:    push bc
        ld a,(lb_cx)
        add a,(hl)
        and $FE
        ld b,a
        ld a,(de)
        push hl
        ld hl,lb_cy
        add a,(hl)
        pop hl
        ld c,a
        push hl
        push de
        ld e,$FF                ; alternate red and yellow
        bit 0,l
        jr z,.lc
        ld e,$55
.lc:    call draw_dot
        pop de
        pop hl
        inc hl
        inc de
        pop bc
        djnz .ld
.n:     pop bc
        dec b
        jp nz,.l
.body:  ld hl,(BD+BD_BODYC)
        call core_exposed
        jr nc,.bd
        ld a,(BD+BD_ARMOUR)     ; open-shell frames (unarmoured: always)
        or a
        jr z,.op
        ld a,(boss_ph)
        cp 3
        jr c,.bd
.op:    ld hl,(BD+BD_BODYO0)
        ld a,(anim)
        and 4
        jr z,.f
        ld hl,(BD+BD_BODYO1)
.f:     ld a,(ETAB+EO_FL)       ; hit: flicker between the two
        or a
        jr z,.bd
        ld a,(anim)
        and 1
        ld hl,(BD+BD_BODYO0)
        jr z,.bd
        ld hl,(BD+BD_BODYO1)
.bd:    ld a,(bx)
        ld b,a
        ld a,(by)
        add a,FBTOP-16
        ld c,a
        jp draw_spr

; A = d (signed) -> (HL..HL+3) = d*9/16, d*11/16, d*13/16, d*15/16
lb_parts:
        ld c,a                  ; d
        sra a
        ld b,a                  ; d/2
        sra a
        sra a
        ld d,a                  ; d/8
        sra a
        ld e,a                  ; d/16
        ld a,b
        add a,e
        ld (hl),a               ; 9/16
        inc hl
        add a,d
        ld (hl),a               ; 11/16
        inc hl
        ld a,c
        sub d
        sub e
        ld (hl),a               ; 13/16
        inc hl
        ld a,c
        sub e
        ld (hl),a               ; 15/16
        ret
