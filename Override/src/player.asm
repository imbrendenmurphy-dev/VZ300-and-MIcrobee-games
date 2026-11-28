; =====================================================================
;  player.asm - the player's host droid (record plr, same layout)
; =====================================================================

; direction bits (U D L R) -> facing 0-7 ($FF = none)
dirtab:     db $FF,6,2,$FF,4,5,3,4,0,7,1,0,$FF,6,2,$FF

player_update:
            ld ix,plr
            bit 7,(ix+O_FLAGS)
            ret z
            ld a,(ix+O_FLASH)
            or a
            jr z,.f
            dec (ix+O_FLASH)
.f:         ld a,(ix+O_INV)
            or a
            jr z,.i
            dec (ix+O_INV)
.i:         ld a,(ix+O_COOL)
            or a
            jr z,.c
            dec (ix+O_COOL)
.c:         ld a,(in_now)
            ld (p_in),a
            and K_DIRS
            ld (p_dirs),a
            ld e,a
            ld d,0
            ld hl,dirtab
            add hl,de
            ld a,(hl)
            cp $FF
            jr z,.nf
            ld (ix+O_FACE),a
.nf:        ; ---- target velocity (1/16 px a frame; rows at 2/3)
            ld a,(ix+O_TYPE)
            ld c,T_SPEED
            call type_stat
            ld (p_spd),a
            ld b,a
            ld a,(p_dirs)
            and K_UP|K_DOWN
            jr z,.nd
            ld a,(p_dirs)
            and K_LEFT|K_RIGHT
            jr z,.nd
            ld a,b                  ; diagonal: 3/4
            srl a
            srl a
            ld c,a
            ld a,b
            sub c
            ld b,a
.nd:        ld c,0                  ; tvx
            ld a,(p_dirs)
            bit 3,a
            jr z,.nr
            ld c,b
.nr:        bit 2,a
            jr z,.nl
            ld a,b
            neg
            ld c,a
.nl:        ld a,c
            ld (p_tvx),a
            ; vertical: 2/3 of the speed
            ld a,b
            add a,a
            ld l,a
            ld h,0
            ld c,3
            call div_hl_c
            ld b,l
            ld c,0
            ld a,(p_dirs)
            bit 1,a
            jr z,.ndn
            ld c,b
.ndn:       bit 0,a
            jr z,.nup
            ld a,b
            neg
            ld c,a
.nup:       ld a,c
            ld (p_tvy),a
            ; accelerate: acc = speed/5 + 1
            ld a,(p_spd)
            ld l,a
            ld h,0
            ld c,5
            call div_hl_c
            inc l
            ld a,l
            ld (p_acc),a
            ld a,(p_tvx)
            ld b,(ix+O_VX)
            call approach
            ld (ix+O_VX),a
            ld a,(p_tvy)
            ld b,(ix+O_VY)
            call approach
            ld (ix+O_VY),a
            ; ---- move x
            ld a,(ix+O_VX)
            ld b,(ix+O_XF)
            add a,b                 ; signed sum (frac 0..15 + v)
            ld b,a
            and 15
            ld (ix+O_XF),a
            ld a,b
            sra a
            sra a
            sra a
            sra a
            or a
            call nz,move_x
            ld a,(ix+O_VY)
            ld b,(ix+O_YF)
            add a,b
            ld b,a
            and 15
            ld (ix+O_YF),a
            ld a,b
            sra a
            sra a
            sra a
            sra a
            or a
            call nz,move_y
            ; ---- fire / transfer
            call player_fire
            ; ---- the tile under the middle
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld bc,6
            add hl,bc
            ld b,h
            ld c,l
            ld a,(ix+O_Y)
            add a,4
            ld e,a
            call tile_at
            ld (p_under),a
            bit 5,a                 ; A_ENERGY
            jr z,.ne
            ld a,(frames)
            and 1
            jr nz,.nb
            ld a,(ix+O_EN)
            cp (ix+O_MAXE)
            jr nc,.nb
            inc (ix+O_EN)
            ld a,1
            ld (hud_e),a
            ld a,SFX_CHARGE
            call sfx
            jr .nb
.ne:        ; ---- burnout: a borrowed body slowly wears out
            ld a,(ix+O_TYPE)
            or a
            jr z,.nb
            ld hl,p_burn
            dec (hl)
            jr nz,.nb
            ld c,T_CLASS
            call type_stat
            add a,a
            add a,a
            ld b,a
            ld a,70
            sub b
            ld (p_burn),a
            ld a,1
            call player_hurt_raw
.nb:        ret

; A = target, B = current, (p_acc) -> A = new velocity
approach:
            sub b
            jr z,.eq
            jp m,.down
            ld c,a
            ld a,(p_acc)
            cp c
            jr c,.u
            ld a,c
.u:         add a,b
            ret
.down:      neg
            ld c,a
            ld a,(p_acc)
            cp c
            jr c,.d
            ld a,c
.d:         ld c,a
            ld a,b
            sub c
            ret
.eq:        ld a,b
            ret

; HL = HL / C (unsigned, small)
div_hl_c:
            ld b,16
            xor a
.l:         add hl,hl
            rla
            cp c
            jr c,.n
            sub c
            inc l
.n:         djnz .l
            ret

; ---------------------------------------------------------------------
; move_x: A = signed pixels. Moves a pixel at a time; when blocked, slides
; round corners (doorways are only a little wider than a droid).
move_x:
            ld (mv_n),a
.l:         ld a,(mv_n)
            or a
            ret z
            ld c,1
            bit 7,a
            jr z,.p
            ld c,-1
            inc a
            jr .s
.p:         dec a
.s:         ld (mv_n),a
            ld a,c
            ld (mv_d),a
            call try_x
            jr z,.l
            ; blocked: console? slide?
            call bump_check
            ld a,(p_dirs)
            and K_UP|K_DOWN
            jr nz,.stop
            call slide_y
            jr z,.l
.stop:      ld (ix+O_VX),0
            ret

; try moving by mv_d pixels in x: Z = moved
try_x:
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld a,(mv_d)
            ld e,a
            add a,a
            sbc a,a
            ld d,a
            add hl,de
            push hl
            ld e,(ix+O_Y)
            ld a,A_SOLID
            call box_hit
            pop hl
            ret nz
            ld (ix+O_XL),l
            ld (ix+O_XH),h
            ret

; blocked in x: is there room one to three rows up or down? step towards it
slide_y:
            ld b,1
.l:         push bc
            ld a,(ix+O_Y)
            sub b
            call .t
            pop bc
            jr z,.up
            push bc
            ld a,(ix+O_Y)
            add a,b
            call .t
            pop bc
            jr z,.dn
            inc b
            ld a,b
            cp 4
            jr nz,.l
            or 1
            ret
.up:        dec (ix+O_Y)
            xor a
            ret
.dn:        inc (ix+O_Y)
            xor a
            ret
.t:         ld e,a
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld a,(mv_d)
            ld c,a
            add a,a
            sbc a,a
            ld b,a
            add hl,bc
            ld a,A_SOLID
            jp box_hit

move_y:
            ld (mv_n),a
.l:         ld a,(mv_n)
            or a
            ret z
            ld c,1
            bit 7,a
            jr z,.p
            ld c,-1
            inc a
            jr .s
.p:         dec a
.s:         ld (mv_n),a
            ld a,c
            ld (mv_d),a
            call try_y
            jr z,.l
            call bump_check
            ld a,(p_dirs)
            and K_LEFT|K_RIGHT
            jr nz,.stop
            call slide_x
            jr z,.l
.stop:      ld (ix+O_VY),0
            ret

try_y:
            ld a,(ix+O_Y)
            ld hl,mv_d
            add a,(hl)
            ld e,a
            push de
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld a,A_SOLID
            call box_hit
            pop de
            ret nz
            ld (ix+O_Y),e
            ret

slide_x:
            ld b,1
.l:         push bc
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld c,b
            ld b,0
            or a
            sbc hl,bc
            call .t
            pop bc
            jr z,.lf
            push bc
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld c,b
            ld b,0
            add hl,bc
            call .t
            pop bc
            jr z,.rt
            inc b
            ld a,b
            cp 4
            jr nz,.l
            or 1
            ret
.lf:        ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            dec hl
            jr .set
.rt:        ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            inc hl
.set:       ld (ix+O_XL),l
            ld (ix+O_XH),h
            xor a
            ret
.t:         ld a,(ix+O_Y)
            push hl
            ld hl,mv_d
            add a,(hl)
            pop hl
            ld e,a
            ld a,A_SOLID
            jp box_hit

; pushing into a console for a moment opens it
bump_check:
            ld a,(bh_attr)
            and A_CONSOLE
            ret z
            ld hl,p_push
            inc (hl)
            ld a,(hl)
            cp 8
            ret c
            ld (hl),0
            ld a,EV_CONSOLE
            ld (event),a
            ret

; ---------------------------------------------------------------------
; fire: tap to shoot where you face; hold with no direction to link
player_fire:
            ld a,(p_in)
            and K_FIRE
            jr nz,.down
            xor a
            ld (p_held),a
            ld (p_tmode),a
            ret
.down:      ld a,(p_held)
            inc a
            jr nz,.h
            dec a
.h:         ld (p_held),a
            dec a
            jr nz,.notnew
            ; newly pressed: on a lift pad with no direction -> the lift
            ld a,(p_dirs)
            or a
            jr nz,.shoot
            ld a,(p_under)
            and A_LIFT
            jr z,.shoot
            ld a,EV_LIFT
            ld (event),a
            ret
.notnew:    ld a,(p_tmode)
            or a
            ret nz                  ; linking: no shooting
            ld a,(p_dirs)
            or a
            jr nz,.shoot
            ld a,(p_held)
            cp 12
            ret c
            ld a,1                  ; hold still a moment: link mode
            ld (p_tmode),a
            ld a,SFX_LINK
            jp sfx
.shoot:     ld a,(ix+O_COOL)
            or a
            ret nz
            ld a,(ix+O_TYPE)
            ld c,T_WEAPON
            call type_stat
            or a
            ret z
            ld (df_w),a
            call weapon_ptr
            inc hl
            inc hl
            ld a,(hl)
            ld (ix+O_COOL),a
            ld b,(ix+O_FACE)
            ld a,(df_w)
            ld c,0
            jp fire_shot

; ---------------------------------------------------------------------
; damage to the player: A = points (ignored while invulnerable)
player_hurt:
            ld b,a
            ld a,(plr+O_INV)
            or a
            ret nz
            ld a,b
            srl a                   ; you take half (rounded up)
            adc a,0
player_hurt_raw:
            ld b,a
            ld a,(plr+O_EN)
            sub b
            jr c,.dead
            jr z,.dead
            ld (plr+O_EN),a
            add a,a                 ; under a quarter: warn once
            jr c,.ok
            add a,a
            jr c,.ok
            ld c,a
            ld a,(plr+O_MAXE)
            cp c
            jr c,.ok
            jr z,.ok
            ld a,(p_low)
            or a
            jr nz,.ok2
            inc a
            ld (p_low),a
            ld hl,msg_low
            call show_msg
            jr .ok2
.ok:        xor a
            ld (p_low),a
.ok2:       ld a,4
            ld (plr+O_FLASH),a
            ld a,1
            ld (hud_e),a
            ld a,SFX_HURT
            jp sfx
.dead:      xor a
            ld (plr+O_EN),a
            ld a,1
            ld (hud_e),a
            jp host_lost

; the host body is destroyed: back to the bare probe, or lose a life
host_lost:
            ld hl,(plr+O_XL)
            ld a,(plr+O_Y)
            call fx_boom
            ld a,SFX_BOOM
            call sfx
            ld a,(plr+O_TYPE)
            or a
            jr z,.probe
            ld ix,plr
            xor a
            call become
            ld a,60
            ld (plr+O_INV),a
            ld hl,msg_host
            jp show_msg
.probe:     ld a,EV_DEATH
            ld (event),a
            xor a
            ld (plr+O_FLAGS),a
            ret

; the player takes body type A (full energy, new sprite)
become:
            push af
            ld ix,plr
            call set_type
            pop af
            ld (slot_type),a
            ld b,1
            ld d,0
            call build_type
            ld a,1
            ld (hud_all),a
            ld a,70
            ld (p_burn),a
            ret

draw_player:
            ld ix,plr
            bit 7,(ix+O_FLAGS)
            ret z
            ld a,(ix+O_INV)         ; flicker while invulnerable
            and 2
            ret nz
            ld a,(p_tmode)          ; linking: pulses red
            or a
            jr z,.n
            ld a,(frames)
            and 2
            jr z,.n
            ld a,$FF
            ld (ix+O_FLASH),1
            ld (spr_sil),a
            ld h,HIGH(SPRC)
            ld l,0
            ld c,(ix+O_XL)
            ld b,(ix+O_XH)
            ld e,(ix+O_Y)
            ld d,0
            call draw_spr
            xor a
            ld (spr_sil),a
            ld (ix+O_FLASH),a
            ret
.n:         jp draw_obj
