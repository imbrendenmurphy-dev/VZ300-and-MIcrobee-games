; ============================================================================
;  HERO - Sir Tinplate
;  Armour is drawn on the sprite itself.  Frames are built at run time from
;  layered class data (body + armour pieces) for the current armour level, so
;  all six stages of armour cost very little memory.
; ============================================================================

HF_STAND equ 0
HF_RUN   equ 1
HF_JUMP  equ 4
HF_THROW equ 5
HF_CROUCH equ 6
HF_HURT  equ 7

GRAVITY  equ $0050
JUMPV    equ $0400
MAXFALL  equ $0500

; ---------------------------------------------------------------- builder
build_hero:
        ; copy level table + body table to the aligned lookup page
        ld a,(arm_cur)
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,HERO_ARMTAB
        add hl,de
        ld de,HLUT
        ld bc,16
        ldir
        ld hl,HERO_BODYTAB
        ld bc,16
        ldir
        ld de,HERO_CLS
        ld ix,HC_P0
        ld a,NHEROF*16          ; total rows
.row:   push af
        ld h,HLUT>>8
        ld a,3
.byte:  push af
        ld bc,0
        call .pix
        call .pix
        call .pix
        call .pix
        ld (ix+0),b
        ld (ix+1),c
        inc ix
        inc ix
        pop af
        dec a
        jr nz,.byte
        pop af
        dec a
        jr nz,.row
        ; phase-2 copies
        ld hl,HC_P0
        ld de,HC_P2
        ld a,NHEROF*16
.sh:    push af
        ld b,3
        call shr4_row
        pop af
        dec a
        jr nz,.sh
        ; descriptors
        ld ix,HERO_DESC
        ld hl,HC_P0
        ld de,HC_P2
        ld b,NHEROF
.ds:    ld (ix+0),3
        ld (ix+1),16
        ld (ix+2),l
        ld (ix+3),h
        ld (ix+4),e
        ld (ix+5),d
        push bc
        ld bc,96
        add hl,bc
        ex de,hl
        ld bc,128
        add hl,bc
        ex de,hl
        pop bc
        ld a,6
        add a,ixl
        ld ixl,a
        jr nc,$+4
        inc ixh
        djnz .ds
        ret

; one pixel: DE -> class byte, accumulate into B (keep) / C (data)
.pix:   ld a,(de)
        inc de
        push af
        rrca
        rrca
        rrca
        rrca
        and 15
        or $80
        ld l,a
        ld a,(hl)
        cp $FF
        jr nz,.arm
        pop af
        and 15
        add a,$90
        ld l,a
        ld a,(hl)
        jr .px2
.arm:   inc sp
        inc sp
.px2:   sla b
        sla b
        sla c
        sla c
        cp $FF
        jr nz,.op
        ld a,b
        or 3
        ld b,a
        ret
.op:    or c
        ld c,a
        ret

; shr4_row: shift a sprite row (B pairs at HL) right by 2 pixels into B+1
; pairs at DE.  Advances HL and DE.
shr4_row:
        ld a,$FF
        ld (sh_pk),a
        xor a
        ld (sh_pd),a
.lp:    ld a,(hl)               ; keep
        inc hl
        call .mix
        ld (sh_t),a
        ld a,(sh_pk)
        call .comb
        ld a,(sh_t)
        ld (sh_pk),a
        ld a,(hl)               ; data
        inc hl
        ld (sh_t),a
        ld a,(sh_pd)
        call .comb
        ld a,(sh_t)
        ld (sh_pd),a
        djnz .lp
        ; tail byte
        ld a,(sh_pk)
        rlca
        rlca
        rlca
        rlca
        or $0F
        ld (de),a
        inc de
        ld a,(sh_pd)
        rlca
        rlca
        rlca
        rlca
        and $F0
        ld (de),a
        inc de
        ret
.mix:   ret
; comb: A = previous byte, (sh_t) = current byte -> writes (prev<<4)|(cur>>4)
.comb:  rlca
        rlca
        rlca
        rlca
        and $F0
        ld c,a
        ld a,(sh_t)
        rrca
        rrca
        rrca
        rrca
        and $0F
        or c
        ld (de),a
        inc de
        ret

; ---------------------------------------------------------------- tiles
; tile_at: HL = world x (px), A = y (signed px) -> A = attribute
tile_at:
        bit 7,a
        jr nz,.none             ; above the map: empty
        cp 56
        jr nc,.solid            ; below the map: solid floor
        rrca
        rrca
        rrca
        and 7
        ld c,a
        ld a,h
        bit 7,a
        jr nz,.solid
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l                    ; tile column
        ld de,(lvl_w)
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.solid
        ld de,(lvl_map)
        add hl,de
        ld l,(hl)               ; column dictionary index
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,0
        add hl,bc
        ld de,(lvl_cols)
        add hl,de
        ld a,(hl)
        ld (last_tile),a
        ld l,a
        ld h,0
        ld de,(lvl_tattr)
        add hl,de
        ld a,(hl)
        ret
.none:  xor a
        ret
.solid: ld a,1
        ret

; tile probe helper: hero x + B offset, y + C offset
hprobe:
        ld hl,(hero_x)
        ld e,b
        ld d,0
        add hl,de
        ld a,(hero_y)
        add a,c
        jp tile_at

; ---------------------------------------------------------------- update
hero_update:
        ld a,(hero_dead)
        or a
        jp nz,hero_dying
        ; timers
        ld hl,invuln
        ld a,(hl)
        or a
        jr z,$+3
        dec (hl)
        ld hl,throw_t
        ld a,(hl)
        or a
        jr z,$+3
        dec (hl)
        ld a,(hurt_t)
        or a
        jr z,.nohurt
        dec a
        ld (hurt_t),a
        ; knockback drift
        ld a,(hero_dir)
        or a
        ld hl,(hero_x)
        ld de,-2
        jr z,.kb
        ld de,2
.kb:    add hl,de
        call hero_try_x
        jp .vert
.nohurt:
        ; weapon swap
        ld a,(keys_new)
        bit K_SWAP,a
        call nz,weapon_next
        ; crouch
        xor a
        ld (crouch),a
        ld a,(on_ground)
        or a
        jr z,.nocr
        ld a,(keys)
        bit K_DOWN,a
        jr z,.nocr
        ld a,1
        ld (crouch),a
.nocr:  ; horizontal
        xor a
        ld (moving),a
        ld a,(keys)
        ld c,a
        bit K_LEFT,c
        jr z,.nl
        ld a,1
        ld (hero_dir),a
        ld a,(crouch)
        or a
        jr nz,.nmv
        ld hl,(hero_x)
        dec hl
        dec hl
        call hero_try_x
        jr .mvd
.nl:    bit K_RIGHT,c
        jr z,.nmv
        xor a
        ld (hero_dir),a
        ld a,(crouch)
        or a
        jr nz,.nmv
        ld hl,(hero_x)
        inc hl
        inc hl
        call hero_try_x
.mvd:   ld a,1
        ld (moving),a
.nmv:   ; jump
        ld a,(keys_new)
        bit K_UP,a
        jr z,.nj
        ld a,(on_ground)
        or a
        jr z,.nj
        ld hl,-JUMPV
        ld (hero_vy),hl
        xor a
        ld (on_ground),a
        ld a,SFX_JUMP_ID
        call play_sfx
.nj:    ; variable jump height
        ld a,(keys)
        bit K_UP,a
        jr nz,.vert
        ld hl,(hero_vy)
        bit 7,h
        jr z,.vert
        ld de,$0100
        add hl,de
        jr c,.vert              ; vy >= -$100: leave it
        ld hl,-$0100
        ld (hero_vy),hl
.vert:  ; gravity
        ld hl,(hero_vy)
        ld de,GRAVITY
        add hl,de
        bit 7,h
        jr nz,.up
        ld de,MAXFALL
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.up
        ld hl,MAXFALL
.up:    ld (hero_vy),hl
        ; remember old feet
        ld a,(hero_y)
        add a,16
        ld (old_feet),a
        ; y += vy (8.8)
        ld a,(hero_yf)
        ld e,a
        ld a,(hero_y)
        ld d,a
        ex de,hl
        ld de,(hero_vy)
        add hl,de
        ld a,l
        ld (hero_yf),a
        ld a,h
        ld (hero_y),a
        ; vertical collision
        ld a,(hero_vy+1)
        bit 7,a
        jr nz,.rising
        ; falling: probe feet
        ld bc,$0410
        call hprobe
        call .land_chk
        jr c,.landed
        ld bc,$0710
        call hprobe
        call .land_chk
        jr c,.landed
        xor a
        ld (on_ground),a
        jr .vdone
.landed:
        ld a,(on_ground)
        or a
        jr nz,.wasg
        ld a,(hero_vy+1)
        cp 3
        jr c,.wasg
        ld a,SFX_THROW_ID       ; thud
        call play_sfx
.wasg:  ld a,(hero_y)
        add a,16
        and $F8
        sub 16
        ld (hero_y),a
        xor a
        ld (hero_yf),a
        ld hl,0
        ld (hero_vy),hl
        ld a,1
        ld (on_ground),a
        jr .vdone
.rising:
        ld bc,$0502
        call hprobe
        cp 1
        jr nz,.vdone
        ld hl,0
        ld (hero_vy),hl
        ld a,(hero_y)
        add a,2
        and $F8
        add a,6
        ld (hero_y),a
.vdone: ; hazards under the feet
        ld bc,$0511
        call hprobe
        cp 3
        jr nz,.nohz
        ld a,(on_ground)
        or a
        jr z,.nohz
        call hero_hit
        ld hl,-$0380
        ld (hero_vy),hl
        xor a
        ld (on_ground),a
.nohz:  ; fell off the bottom (should not happen) -> bounce
        ld a,(hero_y)
        cp 50
        jr c,.ny
        bit 7,a
        jr nz,.ny
        ld a,26
        ld (hero_y),a
.ny:    ; attack
        call hero_attack
        ; animation frame
        call hero_pick_frame
        ; sparkles for enchanted+ armour
        ld a,(arm_cur)
        cp 3
        ret c
        call rand
        and 7
        ret nz
        call rand
        and 15
        ld e,a
        ld d,0
        ld hl,(hero_x)
        add hl,de
        ex de,hl
        call rand
        and 15
        ld c,a
        ld a,(hero_y)
        add a,c
        push af
        ld a,(col_yel)
        ld l,a
        ld h,8
        ld bc,$00FF
        pop af
        jp part_spawn

; land_chk: A = attribute at feet -> carry if we land on it
.land_chk:
        cp 1
        jr z,.yes
        cp 3
        jr z,.yes
        cp 2
        jr nz,.no
        ; one-way: only if the old feet were at or above the tile top
        ld a,(hero_y)
        add a,16
        and $F8
        ld b,a
        ld a,(old_feet)
        cp b
        jr z,.yes
        jr c,.yes
.no:    or a
        ret
.yes:   scf
        ret

; hero_try_x: HL = new x. Moves if not blocked by walls or limits.
hero_try_x:
        ; limits
        bit 7,h
        ret nz
        ld de,(xlim_lo)
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ld de,(xlim_hi)
        push hl
        or a
        sbc hl,de
        pop hl
        ret nc
        ld (try_x),hl
        ; probe the leading edge at two heights
        ld de,(hero_x)
        or a
        sbc hl,de
        ld b,9
        jr nc,$+4
        ld b,2
        ld c,4
        ld a,(crouch)
        or a
        jr z,$+4
        ld c,9
        push bc
        ld hl,(try_x)
        ld e,b
        ld d,0
        add hl,de
        ld a,(hero_y)
        add a,c
        call tile_at
        pop bc
        cp 1
        ret z
        ld hl,(try_x)
        ld e,b
        ld d,0
        add hl,de
        ld a,(hero_y)
        add a,13
        call tile_at
        cp 1
        ret z
        ld hl,(try_x)
        ld (hero_x),hl
        ret

hero_pick_frame:
        ld a,(hurt_t)
        or a
        ld b,HF_HURT
        jr nz,.set
        ld a,(crouch)
        or a
        ld b,HF_CROUCH
        jr nz,.set
        ld a,(throw_t)
        or a
        ld b,HF_THROW
        jr nz,.set
        ld a,(on_ground)
        or a
        ld b,HF_JUMP
        jr z,.set
        ld a,(moving)
        or a
        ld b,HF_STAND
        jr z,.set
        ld hl,hero_anim
        inc (hl)
        ld a,(hl)
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        ld hl,RUNSEQ
        add hl,de
        ld b,(hl)
.set:   ld a,b
        ld (hero_frame),a
        ret
RUNSEQ: db 1,3,2,3

hero_draw:
        ld a,(hero_dead)
        or a
        jr nz,.d
        ld a,(invuln)
        or a
        jr z,.d
        ld a,(frame_no)
        and 1
        ret nz
.d:     ld a,(hero_frame)
        ld l,a
        add a,a
        add a,l
        add a,a
        ld e,a
        ld d,0
        ld hl,HERO_DESC
        add hl,de
        ld de,(hero_x)
        ld a,(hero_dir)
        ld c,a
        ld a,(hero_y)
        call draw_world
        ; charge glow
        ld a,(charge)
        cp CHARGE_FULL
        ret c
        ld a,(frame_no)
        and 1
        ret z
        ld hl,S_SPARK_0
        ld de,(hero_x)
        inc de
        inc de
        ld a,(hero_y)
        sub 4
        ld c,0
        jp draw_world

; ---------------------------------------------------------------- damage
hero_hit:
        ld a,(invuln)
        or a
        ret nz
        ld a,(hero_dead)
        or a
        ret nz
        ld a,(cheat)
        or a
        ret nz
        call hp_take            ; five hits to each armour level
        jr nz,.bruise
        ld a,(arm_cur)
        or a
        jr z,hero_die
        ; armour flies off
        ld b,a
        ld a,(opt_diff)
        cp 2
        jr nz,.one
        ld a,b
        cp 2
        jr c,.one
        dec b
.one:   dec b
        ld a,b
        ld (arm_cur),a
        call build_hero
        ld a,SFX_ARMOUR_ID
        call play_sfx
        ; armour pieces
        ld de,(hero_x)
        ld hl,4
        add hl,de
        ex de,hl
        ld a,(hero_y)
        add a,4
        ld b,6
        ld c,0
        ld a,(col_grn)
        ld c,a
        ld a,(hero_y)
        call part_burst
        call spawn_pieces
.bruise:
        ld a,10
        ld (hurt_t),a
        ld a,(opt_diff)
        or a
        ld a,40
        jr nz,$+4
        ld a,60
        ld (invuln),a
        ld hl,-$0280
        ld (hero_vy),hl
        xor a
        ld (on_ground),a
        ld a,1
        ld (hud_need),a
        ret

hero_die:
        ld a,1
        ld (hero_dead),a
        ld a,50
        ld (dead_t),a
        ld hl,-$0400
        ld (hero_vy),hl
        ld a,SFX_DIE_ID
        call play_sfx
        call stop_music
        ld de,(hero_x)
        ld a,(hero_y)
        ld b,10
        ld a,(col_red)
        ld c,a
        ld a,(hero_y)
        call part_burst
        ret

hero_dying:
        ld a,HF_HURT
        ld (hero_frame),a
        ld hl,(hero_vy)
        ld de,GRAVITY
        add hl,de
        ld (hero_vy),hl
        ld a,(hero_y)
        add a,h
        cp 70
        jr c,$+4
        ld a,70
        bit 7,a
        jr z,$+4
        ld a,0
        ld (hero_y),a
        ld hl,dead_t
        dec (hl)
        ret nz
        ld a,1
        ld (life_lost),a
        ret

; ---------------------------------------------------------------- weapons
W_LANCE equ 0
W_DAGGER equ 1
W_AXE   equ 2
W_TORCH equ 3
CHARGE_FULL equ 25

weapon_next:
        ld a,(weapon)
        ld b,4
.lp:    inc a
        and 3
        ld c,a
        ld a,(owned)
        ld e,c
        inc e
.sh:    rrca
        dec e
        jr nz,.sh
        jr c,.got
        ld a,c
        djnz .lp
        ret
.got:   ld a,c
        ld (weapon),a
        ld a,SFX_SELECT_ID
        call play_sfx
        ld a,1
        ld (hud_need),a
        ret

; one throw used: when a weapon runs out it is lost (with its enchantment)
; and the knight goes back to the weapon he held before, or the lance
use_ammo:
        ld a,(weapon)
        or a
        ret z                   ; the lance never runs out
        ld e,a
        ld d,0
        ld hl,ammo
        add hl,de
        ld a,1
        ld (hud_need),a
        dec (hl)
        ret nz
        ld hl,wlevel
        add hl,de
        ld (hl),d
        ld b,e
        ld a,1
.m:     add a,a
        djnz .m                 ; A = 1 << weapon
        cpl
        ld hl,owned
        and (hl)
        ld (hl),a
        ld a,(prev_w)
        ld (weapon),a
        ld b,a
        inc b
        ld a,(hl)
.c:     rrca
        djnz .c
        ret c                   ; still have the previous one
        xor a
        ld (weapon),a
        ret
AMMO_GIVE: db 0,60,30,25        ; throws per pickup: lance, daggers, axes, torches

hero_attack:
        ; magic by key
        ld a,(keys_new)
        bit K_MAGIC,a
        jr z,.nk
        call cast_magic
.nk:    ; charge while fire held
        ld a,(keys)
        bit K_FIRE,a
        jr z,.rel
        ld a,(charge)
        cp CHARGE_FULL
        jr nc,.ch
        inc a
        ld (charge),a
        cp CHARGE_FULL
        jr nz,.ch
        ld a,(magic)
        or a
        jr z,.ch
        ld a,SFX_SELECT_ID
        call play_sfx
.ch:    ld a,(keys_new)
        bit K_FIRE,a
        ret z
        jp throw
.rel:   ld a,(charge)
        cp CHARGE_FULL
        jr c,.nc
        call cast_magic
.nc:    xor a
        ld (charge),a
        ret

throw:
        ld a,(throw_t)
        cp 3
        ret nc
        ; count shots of the current weapon kind
        ld a,(weapon)
        ld e,a
        ld d,0
        ld hl,WMAX
        add hl,de
        ld b,(hl)
        ld hl,wlevel
        add hl,de
        ld a,(hl)
        or a
        jr z,$+3
        inc b                   ; upgraded: one more on screen
        ld a,b
        ld (wmax_cur),a
        call count_shots
        ld hl,wmax_cur
        cp (hl)
        ret nc
        ; find a free shot slot
        ld ix,pshots
        ld b,NPSHOT
.f:     ld a,(ix+0)
        or a
        jr z,.got
        ld de,SHSIZE
        add ix,de
        djnz .f
        ret
.got:   ld a,(weapon)
        inc a
        ld (ix+0),a
        ld a,(hero_dir)
        ld (ix+7),a
        ld hl,(hero_x)
        ld de,2
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        ld a,(crouch)
        or a
        ld a,(hero_y)
        jr z,$+4
        add a,5
        add a,6
        ld (ix+3),a
        ld (ix+6),0
        ld (ix+5),0
        ; speed by weapon
        ld a,(weapon)
        ld e,a
        ld d,0
        ld hl,WSPEED
        add hl,de
        ld a,(hl)
        ld c,a
        ld a,(hero_dir)
        or a
        ld a,c
        jr z,$+4
        neg
        ld (ix+4),a
        ld a,(weapon)
        cp W_AXE
        jr nz,.nax
        ld (ix+5),-10
.nax:   cp W_TORCH
        jr nz,.nto
        ld (ix+5),-8
.nto:   ld a,6
        ld (throw_t),a
        ld a,SFX_THROW_ID
        call play_sfx
        call use_ammo
        ; upgraded daggers: a second dagger, angled
        ld a,(weapon)
        cp W_DAGGER
        ret nz
        ld a,(wlevel+W_DAGGER)
        or a
        ret z
        ld l,(ix+1)
        ld h,(ix+2)
        ld c,(ix+3)
        ld e,(ix+4)
        ld d,(ix+7)
        ld ix,pshots
        ld b,NPSHOT
.f2:    ld a,(ix+0)
        or a
        jr z,.g2
        push de
        ld de,SHSIZE
        add ix,de
        pop de
        djnz .f2
        ret
.g2:    ld (ix+0),W_DAGGER+1
        ld (ix+1),l
        ld (ix+2),h
        ld a,c
        sub 4
        ld (ix+3),a
        ld (ix+4),e
        ld (ix+5),0
        ld (ix+6),0
        ld (ix+7),d
        ret

count_shots:
        ld ix,pshots
        ld b,NPSHOT
        ld c,0
        ld a,(weapon)
        inc a
        ld e,a
.lp:    ld a,(ix+0)
        cp e
        jr nz,.n
        inc c
.n:     push de
        ld de,SHSIZE
        add ix,de
        pop de
        djnz .lp
        ld a,c
        ret

WMAX:   db 2,3,1,1
WSPEED: db 6,8,4,4
WDMG:   db 1,1,2,1,1      ; lance dagger axe torch flame

; shot: +0 type (1 lance 2 dagger 3 axe 4 torch 5 flame) +1 x +3 y +4 vx +5 vy
;       +6 timer +7 dir
SHSIZE equ 8
NPSHOT equ 4

shots_update:
        ld ix,pshots
        ld b,NPSHOT
.lp:    push bc
        ld a,(ix+0)
        or a
        jr z,.nx
        inc (ix+6)
        cp 5
        jr z,.flame
        ; x += vx
        ld a,(ix+4)
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+1)
        ld h,(ix+2)
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        ; arcing weapons
        ld a,(ix+0)
        cp 3
        jr c,.straight
        ld a,(ix+5)
        sra a
        sra a
        add a,(ix+3)
        ld (ix+3),a
        inc (ix+5)              ; double gravity: a short lob that lands
        inc (ix+5)              ; on screen, about 50 pixels away
        ld a,(ix+0)
        cp 4
        jr nz,.straight
        ; torch: becomes a flame on the ground
        ld l,(ix+1)
        ld h,(ix+2)
        ld de,4
        add hl,de
        ld a,(ix+3)
        add a,6
        call tile_at
        or a
        jr z,.straight
        cp 3
        jr z,.straight
        ld (ix+0),5
        ld (ix+6),0
        ld a,(ix+3)
        add a,6
        and $F8
        sub 6
        ld (ix+3),a
        jr .nx
.straight:
        ; off screen?
        ld l,(ix+1)
        ld h,(ix+2)
        ld de,(cam_x)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.kill
        ld a,l
        cp 136
        jr nc,.kill
        ld a,(ix+3)
        cp 58
        jr nc,.killq
        ; straight weapons stop at walls
        ld a,(ix+0)
        cp 3
        jr nc,.nx
        ld l,(ix+1)
        ld h,(ix+2)
        ld de,6
        add hl,de
        ld a,(ix+3)
        inc a
        call tile_at
        cp 1
        jr nz,.nx
        call shot_spark
.kill:  ld (ix+0),0
        jr .nx
.killq: bit 7,a
        jr nz,.nx
        ld (ix+0),0
        jr .nx
.flame: ld a,(ix+6)
        cp 45
        jr c,.nx
        ld (ix+0),0
.nx:    ld de,SHSIZE
        add ix,de
        pop bc
        dec b
        jp nz,.lp
        ret

shot_spark:
        ld e,(ix+1)
        ld d,(ix+2)
        ld a,(ix+3)
        ld b,3
        ld c,a
        ld a,(col_yel)
        ld c,a
        ld a,(ix+3)
        call part_burst
        ld a,SFX_CLINK_ID
        jp play_sfx

shots_draw:
        ld ix,pshots
        ld b,NPSHOT
.lp:    push bc
        ld a,(ix+0)
        or a
        jr z,.nx
        dec a
        ld e,a
        ; upgraded variants
        ld a,e
        cp 2
        jr nc,.nu
        push de
        ld d,0
        ld hl,wlevel
        add hl,de
        ld a,(hl)
        pop de
        or a
        jr z,.nu
        ld a,e
        add a,5                 ; lance2 / dagger2 entries
        ld e,a
.nu:    ld a,e
        cp 2                    ; axe, torch and flame animate
        jr c,.st
        cp 5
        jr nc,.st
        ld a,(ix+6)
        and 2
        jr z,.st
        ld a,e
        add a,8
        ld e,a
.st:    ld d,0
        ld hl,SHOTSPR
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,(ix+1)
        ld d,(ix+2)
        ld a,(ix+7)
        ld c,a
        ld a,(ix+3)
        call draw_world
.nx:    ld de,SHSIZE
        add ix,de
        pop bc
        djnz .lp
        ret

; index: 0 lance 1 dagger 2 axe 3 torch 4 flame 5 lance2 6 dagger2 (7 unused)
;        +8: alternate animation frame
SHOTSPR:
        dw S_LANCE_0,S_DAGGER_0,S_AXE_0,S_TORCH_0,S_FLAME_0,S_LANCE2_0,S_DAGGER2_0,S_LANCE_0
        dw S_LANCE_0,S_DAGGER_0,S_AXE_1,S_TORCH_1,S_FLAME_1,S_LANCE2_0,S_DAGGER2_0,S_LANCE_0

; ---------------------------------------------------------------- magic
cast_magic:
        ld a,(magic)
        or a
        ret z
        dec a
        ld (magic),a
        xor a
        ld (charge),a
        ld a,1
        ld (hud_need),a
        ld a,SFX_MAGIC_ID
        call play_sfx
        ; lightning storm: flash the palette and strike every enemy on screen
        ld a,8
        ld (flash_t),a
        ld a,6
        ld (shake_t),a
        call magic_strike
        ; bolts from the sky
        ld b,10
.bl:    push bc
        call rand
        and 127
        ld e,a
        ld d,0
        ld hl,(cam_x)
        add hl,de
        ex de,hl
        call rand
        and 31
        ld b,4
        ld c,a
        ld a,(col_yel)
        ld c,a
        call rand
        and 31
        call part_burst
        pop bc
        djnz .bl
        ret

; spawn flying armour pieces (debris objects)
spawn_pieces:
        ld b,3
.lp:    push bc
        call obj_alloc
        jr nc,.done
        ld (ix+0),OT_DEBRIS
        ld hl,(hero_x)
        ld de,4
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ld a,(hero_y)
        ld (ix+4),a
        call rand
        and 7
        sub 4
        add a,a
        ld (ix+5),a
        ld (ix+6),-28
        ld (ix+8),30
        pop bc
        djnz .lp
        ret
.done:  pop bc
        ret

; lightning storm damage: every shootable enemy on screen takes 3, the boss 3
magic_strike:
        ld iy,magic_shot
        ld (iy+0),2             ; behaves like a dagger hit for obj_damage
        ld ix,objs
        ld b,NOBJ
.lp:    push bc
        ld a,(ix+0)
        or a
        jr z,.nx
        call obj_box
        ld a,(obj_flags)
        and F_SHOOT
        jr z,.nx
        call obj_relx
        ld a,h
        or a
        jr nz,.nx
        ld a,l
        cp 128
        jr nc,.nx
        ld a,(ix+0)
        cp OT_ZOMBIE
        jr nz,.hit
        ld a,(ix+1)
        or a
        jr z,.nx
.hit:   ld a,(ix+9)
        sub 3
        jr nc,.ok
        xor a
.ok:    ld (ix+9),a
        ld (ix+15),6
        or a
        call z,obj_kill
.nx:    ld de,OSIZE
        add ix,de
        pop bc
        djnz .lp
        ; the boss
        ld a,(boss_on)
        or a
        ret z
        ld ix,(boss_ptr)
        ld a,(ix+1)
        cp 2
        ret c
        cp 9
        ret z
        ld a,(boss_hp)
        sub 3
        jr z,.bd
        jr c,.bd
        ld (boss_hp),a
        ld (ix+15),8
        ld a,1
        ld (hud_need),a
        ret
.bd:    ld a,1
        ld (boss_hp),a
        ret
magic_shot: ds 8
