; =====================================================================
;  shots.asm - shots (positions in quarter pixels) and effects
;  shot: +0 flags (bit7 live, bit0 enemy), +1/2 x4, +3/4 y4, +5 vx, +6 vy,
;        +7 life, +8 damage
; =====================================================================

; fire_shot: A = weapon, B = direction, C = owner (0 player, 1 enemy),
; IX = shooter
fire_shot:
            cp W_DISRUPT            ; (no shot: it hits everything in sight)
            jp z,disrupt
            ld (fs_w),a
            ld a,b
            ld (fs_dir),a
            ld a,c
            ld (fs_own),a
            ld a,(fs_w)
            call weapon_ptr
            ld a,(hl)
            ld (fs_spd),a
            inc hl
            ld a,(hl)
            ld (fs_dmg),a
            inc hl
            inc hl
            ld a,(hl)
            ld (fs_life),a
            ld a,(fs_dir)
            call fs_vel
            ; start at the shooter's centre, a step ahead
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld de,6
            add hl,de
            add hl,hl
            add hl,hl
            ld a,(fs_vx)
            ld e,a
            add a,a
            sbc a,a
            ld d,a
            add hl,de
            add hl,de
            ld (fs_x),hl
            ld l,(ix+O_Y)
            ld h,0
            inc hl
            inc hl
            inc hl
            add hl,hl
            add hl,hl
            ld a,(fs_vy)
            ld e,a
            add a,a
            sbc a,a
            ld d,a
            add hl,de
            add hl,de
            ld (fs_y),hl
            ld a,(fs_w)
            cp W_SCATTER
            jr nz,.tw
            ; scatter: a fan of three, the outer two a direction either side
            ld a,(fs_dir)
            inc a
            call fs_vel
            call spawn_shot
            ld a,(fs_dir)
            dec a
            call fs_vel
            call spawn_shot
            ld a,(fs_dir)
            call fs_vel
            jr .one
.tw:        cp W_TWIN
            jr nz,.one
            ; twin: two shots side by side (offset across the direction)
            ld a,(fs_dir)
            and 3
            cp 2
            jr z,.vert
            ld hl,(fs_y)
            ld de,-8
            add hl,de
            ld (fs_y),hl
            call spawn_shot
            ld hl,(fs_y)
            ld de,16
            add hl,de
            ld (fs_y),hl
            jr .one
.vert:      ld hl,(fs_x)
            ld de,-10
            add hl,de
            ld (fs_x),hl
            call spawn_shot
            ld hl,(fs_x)
            ld de,20
            add hl,de
            ld (fs_x),hl
.one:       call spawn_shot
            ld a,(fs_own)
            or a
            ld a,SFX_SHOT
            jr z,.s
            ld a,SFX_ESHOT
.s:         jp sfx

; fs_vx/fs_vy = shotvel[fs_spd][A & 7]
fs_vel:
            and 7
            ld l,a
            ld a,(fs_spd)
            add a,a
            add a,a
            add a,a
            add a,l
            add a,a
            ld l,a
            ld h,0
            ld de,shotvel
            add hl,de
            ld a,(hl)
            ld (fs_vx),a
            inc hl
            ld a,(hl)
            ld (fs_vy),a
            ret

spawn_shot:
            ld hl,shots
            ld b,MAXSHOTS
.f:         bit 7,(hl)
            jr z,.got
            ld de,SHSZ
            add hl,de
            djnz .f
            ret                     ; all in use
.got:       ld a,(fs_own)
            or $80
            ld (hl),a
            inc hl
            ld de,(fs_x)
            ld (hl),e
            inc hl
            ld (hl),d
            inc hl
            ld de,(fs_y)
            ld (hl),e
            inc hl
            ld (hl),d
            inc hl
            ld a,(fs_vx)
            ld (hl),a
            inc hl
            ld a,(fs_vy)
            ld (hl),a
            inc hl
            ld a,(fs_life)
            ld (hl),a
            inc hl
            ld a,(fs_dmg)
            ld (hl),a
            ret

; ---------------------------------------------------------------------
shots_update:
            ld ix,shots
            ld b,MAXSHOTS
.l:         push bc
            bit 7,(ix+0)
            call nz,shot_one
            ld de,SHSZ
            add ix,de
            pop bc
            djnz .l
            ret

shot_one:
            call snd_pt
            dec (ix+7)
            jr z,.kill
            ; move
            ld l,(ix+1)
            ld h,(ix+2)
            ld a,(ix+5)
            ld e,a
            add a,a
            sbc a,a
            ld d,a
            add hl,de
            ld (ix+1),l
            ld (ix+2),h
            ld l,(ix+3)
            ld h,(ix+4)
            ld a,(ix+6)
            ld e,a
            add a,a
            sbc a,a
            ld d,a
            add hl,de
            ld (ix+3),l
            ld (ix+4),h
            call shot_xy            ; BC = x px, E = y
            ld a,b                  ; off the map?
            cp 2
            jr nc,.kill
            push bc
            push de
            call tile_at
            pop de
            pop bc
            and A_SHOT
            jr nz,.wall
            bit 0,(ix+0)
            jr nz,.enemy
            ; player's shot: any droid here?
            push ix
            ld (sh_x),bc
            ld a,e
            ld (sh_y),a
            ld a,(ix+8)
            ld (sh_dmg),a
            ld ix,droids
            ld b,MAXDROIDS
.d:         push bc
            bit 7,(ix+O_FLAGS)
            call nz,shot_hits
            pop bc
            jr c,.hitd
            ld de,OSZ
            add ix,de
            djnz .d
            pop ix
            ret
.hitd:      ld a,(sh_dmg)
            call droid_hurt
            pop ix
.kill:      ld (ix+0),0
            ret
.wall:      push bc
            push de
            call shot_xy
            ld h,b
            ld l,c
            ld a,e
            call fx_spark
            pop de
            pop bc
            jr .kill
.enemy:     ld (sh_x),bc
            ld a,e
            ld (sh_y),a
            push ix
            ld ix,plr
            bit 7,(ix+O_FLAGS)
            call nz,shot_hits
            pop ix
            ret nc
            ld a,(ix+8)
            call player_hurt
            jr .kill

; IX = shot -> BC = x px, E = y row
shot_xy:
            ld c,(ix+1)
            ld b,(ix+2)
            srl b
            rr c
            srl b
            rr c
            ld e,(ix+3)
            ld d,(ix+4)
            srl d
            rr e
            srl d
            rr e
            ret

; IX = object, (sh_x, sh_y) = point: C if it is inside the object's box
shot_hits:
            ld hl,(sh_x)
            ld e,(ix+O_XL)
            ld d,(ix+O_XH)
            or a
            sbc hl,de               ; px - x
            ld a,h
            or a
            jr nz,.no
            ld a,l
            cp 13
            ret nc
            ld a,(sh_y)
            sub (ix+O_Y)
            jr c,.no
            cp 8
            ret
.no:        or a
            ret

draw_shots:
            ld ix,shots
            ld b,MAXSHOTS
.l:         push bc
            bit 7,(ix+0)
            jr z,.n
            call shot_xy
            ld d,0
            push bc
            push de
            ld a,1                  ; yours yellow, theirs red
            bit 0,(ix+0)
            jr z,.c
            ld a,3
.c:         ld (sh_col),a
            call plot_dot
            pop de
            pop bc
            ; a trailing dot half a step back
            ld a,(ix+5)
            sra a
            sra a
            sra a
            neg
            ld l,a
            add a,a
            sbc a,a
            ld h,a
            add hl,bc
            ld b,h
            ld c,l
            ld a,(ix+6)
            sra a
            sra a
            sra a
            neg
            add a,e
            ld e,a
            ld a,(sh_col)
            call plot_dot
.n:         ld de,SHSZ
            add ix,de
            pop bc
            djnz .l
            ret

shots_clear:
            ld hl,shots
            ld bc,SHSZ*MAXSHOTS
            xor a
            jp fill

; ---------------------------------------------------------------------
; effects: +0 kind (0 free, 1 boom, 2 spark), +1/2 x, +3 y, +4 timer
fx_boom:
            ld b,1
            jr fx_add
fx_spark:
            ld b,2
; HL = x px, A = y, B = kind
fx_add:
            ld c,a
            push hl
            ld hl,fxs
            ld e,MAXFX
.f:         ld a,(hl)
            or a
            jr z,.got
            ld a,l
            add a,FXSZ
            ld l,a
            jr nc,.n
            inc h
.n:         dec e
            jr nz,.f
            pop hl
            ret
.got:       pop de
            ld (hl),b
            inc hl
            ld (hl),e
            inc hl
            ld (hl),d
            inc hl
            ld (hl),c
            inc hl
            ld (hl),0
            ret

fx_update:
            ld hl,fxs
            ld b,MAXFX
.l:         ld a,(hl)
            or a
            jr z,.n
            push hl
            inc hl
            inc hl
            inc hl
            inc hl
            inc (hl)
            ld c,(hl)
            pop hl
            cp 1
            ld a,c
            jr nz,.sp
            cp 16                   ; boom: 4 frames x 4
            jr c,.n
            ld (hl),0
            jr .n
.sp:        cp 5
            jr c,.n
            ld (hl),0
.n:         ld de,FXSZ
            add hl,de
            djnz .l
            ret

draw_fx:
            ld ix,fxs
            ld b,MAXFX
.l:         push bc
            ld a,(ix+0)
            or a
            jr z,.n
            ld c,(ix+1)
            ld b,(ix+2)
            ld e,(ix+3)
            ld d,0
            cp 1
            jr nz,.sp
            ld a,(ix+4)
            srl a
            srl a
            add a,HIGH(expld)
            ld h,a
            ld l,0
            call draw_spr
            jr .n
.sp:        ld a,(ix+4)
            and 1
            add a,a
            inc a                   ; yellow / red flicker
            call plot_dot
.n:         ld de,FXSZ
            add ix,de
            pop bc
            djnz .l
            ret

fx_clear:
            ld hl,fxs
            ld bc,FXSZ*MAXFX
            xor a
            jp fill
