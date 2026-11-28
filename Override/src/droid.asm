; =====================================================================
;  droid.asm - the deck's droids: spawning, waypoint AI, shooting
; =====================================================================

; IX = object, A = type: copy the type's stats
set_type:
            ld (ix+O_TYPE),a
            call type_ptr           ; HL = stats
            inc hl
            inc hl
            ld a,(hl)
            ld (ix+O_EN),a
            ld (ix+O_MAXE),a
            ret

; A = type -> HL = its stats record (TSZ bytes)
type_ptr:
            ld l,a
            ld h,0
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,de
            add hl,hl               ; *10
            ld de,types
            add hl,de
            ret

; A = type -> A = stat at offset C
type_stat:
            push hl
            push de
            call type_ptr
            ld b,0
            add hl,bc
            ld a,(hl)
            pop de
            pop hl
            ret

; IX = object: position it on waypoint A (top-left of its 2x2 tiles)
at_wpt:
            call wpt_ptr            ; HL = node
            ld a,(hl)
            inc hl
            push hl
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            inc hl
            ld (ix+O_XL),l
            ld (ix+O_XH),h
            pop hl
            ld a,(hl)
            ld e,a
            add a,a
            add a,e
            add a,a
            add a,2
            ld (ix+O_Y),a
            xor a
            ld (ix+O_XF),a
            ld (ix+O_YF),a
            ret

; A = waypoint -> HL = its node (x, y, degree, 5 neighbours)
wpt_ptr:
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,WPT
            add hl,de
            ret

; ---------------------------------------------------------------------
; spawn the deck's surviving droids (alive mask in deck_alive)
droids_spawn:
            ld hl,droids
            ld bc,OSZ*MAXDROIDS
            xor a
            call fill
            ld a,(dinfo+DI_NDROIDS)
            or a
            ret z
            ld (sp_n),a
            xor a
            ld (sp_i),a
            ld ix,droids
.l:         ld a,(sp_i)
            call alive_bit
            jr z,.next
            ld a,(sp_i)
            add a,a
            ld e,a
            ld d,0
            ld hl,dinfo+DI_DROIDS
            add hl,de
            ld a,(hl)               ; type
            inc hl
            ld c,(hl)               ; waypoint
            push bc
            call set_type
            pop bc
            ld a,c
            ld (ix+O_TGT),a
            ld (ix+O_PREV),a
            call at_wpt
            ld a,(sp_i)
            ld (ix+O_SPAWN),a
            ld (ix+O_FLAGS),$80
            ld a,(ix+O_TYPE)
            call slot_for
            ld (ix+O_SLOT),a
            call random
            and 31
            ld (ix+O_COOL),a
            ld (ix+O_THINK),a
            ld de,OSZ
            add ix,de
.next:      ld hl,sp_i
            inc (hl)
            ld a,(sp_n)
            cp (hl)
            jr nz,.l
            ret

; A = spawn index -> NZ if that droid is still alive on this deck
alive_bit:
            ld hl,(cur_alive)
            ld b,a
            inc b
.s:         dec b
            jr z,.t
            srl h
            rr l
            jr .s
.t:         ld a,l
            and 1
            ret

; clear spawn bit A in the deck's alive mask
kill_bit:
            ld hl,1
            ld b,a
            inc b
.s:         dec b
            jr z,.t
            add hl,hl
            jr .s
.t:         ld a,l
            cpl
            ld c,a
            ld a,h
            cpl
            ld b,a
            ld hl,(cur_alive)
            ld a,l
            and c
            ld l,a
            ld a,h
            and b
            ld h,a
            ld (cur_alive),hl
            ret

; sprite cache slot for enemy type A (builds it if new); slot 0 is the
; player's host. Up to 7 enemy types a deck.
slot_for:
            ld c,a
            ld hl,slot_type+1
            ld b,NSPRSLOT-1
            ld e,1
.f:         ld a,(hl)
            cp c
            ld a,e
            ret z
            cp $FF
            inc hl
            inc e
            djnz .f
            ; not there: take the next free slot
            ld hl,slot_type+1
            ld b,NSPRSLOT-1
            ld e,1
.g:         ld a,(hl)
            cp $FF
            jr z,.new
            inc hl
            inc e
            djnz .g
            ld a,1                  ; (full: share slot 1)
            ret
.new:       ld (hl),c
            ld a,c
            ld d,e
            push de
            ld b,0                  ; enemy colours
            call build_type
            pop de
            ld a,d
            ret

; build_type: A = type, B = 0 enemy / 1 player colours, D = slot
build_type:
            push de
            ld l,a
            ld h,0
            add hl,hl
            ld a,b
            or l
            ld l,a                  ; image index = type*2 + variant
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl               ; *64
            ld de,dimg
            add hl,de
            pop de
            ld a,d
            add a,HIGH(SPRC)
            ld d,a
            ld e,0
            ld a,(cur_map)
            push af
            ld a,MAP_GAME
            out (BANKPORT),a
            call build_sprite
            pop af
            out (BANKPORT),a
            ret

; reset the sprite slot table (slot 0 = player host)
slots_reset:
            ld hl,slot_type
            ld b,NSPRSLOT
.l:         ld (hl),$FF
            inc hl
            djnz .l
            ret

; ---------------------------------------------------------------------
; droids_update: move, think, shoot, die
droids_update:
            ld ix,droids
            ld b,MAXDROIDS
.l:         push bc
            ld a,(ix+O_FLAGS)
            bit 7,a
            call nz,droid_one
            ld de,OSZ
            add ix,de
            pop bc
            djnz .l
            ret

droid_one:
            call snd_pt
            ld a,(ix+O_FLASH)
            or a
            jr z,.nf
            dec (ix+O_FLASH)
.nf:        ; ---- movement towards the target waypoint
            ld a,(ix+O_TYPE)
            ld c,T_SPEED
            call type_stat
            ld c,a
            ld a,(ix+O_SEEN)        ; slows to a creep while it has you in sight
            or a
            jr z,.sp
            ld a,(ix+O_TYPE)
            ld c,T_AGGR
            call type_stat
            cp 3
            ld a,(ix+O_TYPE)
            ld c,T_SPEED
            call type_stat
            ld c,a
            jr z,.sp                ; hunters keep coming
            srl c
.sp:        ld a,(ix+O_XF)
            add a,c
            ld b,a
            and 15
            ld (ix+O_XF),a
            ld a,b
            rrca
            rrca
            rrca
            rrca
            and 15                  ; whole pixels this frame
            jr z,.think
            ld (dm_step),a
            ld a,(ix+O_TGT)
            call wpt_ptr
            ld a,(hl)
            inc hl
            push hl
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            inc hl                  ; target x
            ld e,(ix+O_XL)
            ld d,(ix+O_XH)
            or a
            sbc hl,de               ; dx
            ld a,(dm_step)
            ld c,a
            call step_toward
            ld (dm_ax),a            ; 0 = arrived on x
            add hl,de
            ld (ix+O_XL),l
            ld (ix+O_XH),h
            pop hl
            ld a,(hl)
            ld e,a
            add a,a
            add a,e
            add a,a
            add a,2                 ; target y
            sub (ix+O_Y)
            ld l,a
            sbc a,a
            ld h,a                  ; dy (signed 16)
            ld a,(dm_step)
            ld c,a
            call step_toward
            ld b,a
            ld a,(ix+O_Y)
            add a,l
            ld (ix+O_Y),a
            ld a,(dm_ax)
            or b
            call z,droid_next       ; reached the waypoint
.think:     ; ---- line of sight to the player (a droid at a time)
            dec (ix+O_THINK)
            jr nz,.combat
            ld (ix+O_THINK),12
            call droid_sees
            ld (ix+O_SEEN),a
.combat:    ld a,(ix+O_COOL)
            or a
            jr z,.c0
            dec (ix+O_COOL)
            jr .ram
.c0:        ld a,(ix+O_SEEN)
            or a
            jr z,.ram
            ld a,(ix+O_TYPE)
            ld c,T_WEAPON
            call type_stat
            or a
            jr z,.ram
            ld a,(plr+O_FLAGS)
            bit 7,a
            jr z,.ram
            call droid_fire
.ram:       ; ---- touching the player?
            call touch_player
            ret nc
            ld a,(ix+O_RAM)         ; just bumped or just duelled: wait
            or a
            jr z,.ready
            dec (ix+O_RAM)
            ret
.ready:     ld a,(p_tmode)
            or a
            jr z,.hit
            ; link!
            ld (xfer_obj),ix
            ld a,EV_TRANSFER
            ld (event),a
            ret
.hit:       ld (ix+O_RAM),12
            ld a,6
            call droid_hurt         ; both take a knock
            ld a,(plr+O_INV)
            or a
            ret nz
            ld a,5
            call player_hurt
            ret

; HL = delta (signed 16), C = max step -> HL = step taken (signed), A = 0 if
; the step reaches the target
step_toward:
            bit 7,h
            jr nz,.neg
            ld a,h
            or a
            jr nz,.pf
            ld a,l
            cp c
            jr c,.pa
            jr z,.pa
.pf:        ld l,c
            ld h,0
            ld a,1
            ret
.pa:        xor a
            ret
.neg:       call neg_hl
            ld a,h
            or a
            jr nz,.nf
            ld a,l
            cp c
            jr c,.na
            jr z,.na
.nf:        ld l,c
            ld h,0
            call neg_hl
            ld a,1
            ret
.na:        call neg_hl
            xor a
            ret

; choose the next waypoint: towards the player when hunting, else at
; random (not straight back unless it's a dead end)
droid_next:
            ld a,(ix+O_TGT)
            ld b,(ix+O_PREV)
            ld (ix+O_PREV),a
            call wpt_ptr
            inc hl
            inc hl
            ld a,(hl)               ; degree
            inc hl
            ld (dn_deg),a
            ld (dn_list),hl
            cp 1
            jr nz,.many
            ld a,(hl)
            ld (ix+O_TGT),a
            ret
.many:      ld a,(ix+O_SEEN)
            or a
            jr z,.rnd
            ld a,(ix+O_TYPE)
            ld c,T_AGGR
            call type_stat
            cp 3
            jr nz,.rnd
            jp hunt_next
.rnd:       ld a,(dn_deg)
            ld c,a
            call rand_n
            ld hl,(dn_list)
            ld e,a
            ld d,0
            add hl,de
            ld a,(hl)
            cp b                    ; straight back? try once more
            jr nz,.set
            ld a,(dn_deg)
            ld c,a
            call rand_n
            ld hl,(dn_list)
            ld e,a
            ld d,0
            add hl,de
            ld a,(hl)
.set:       ld (ix+O_TGT),a
            ret

; hunters pick the neighbour nearest the player
hunt_next:
            ld a,$FF
            ld (hn_best),a
            ld hl,$7FFF
            ld (hn_dist),hl
            ld a,(dn_deg)
            ld b,a
            ld hl,(dn_list)
.n:         push bc
            push hl
            ld a,(hl)
            ld (hn_cand),a
            call wpt_ptr
            ld a,(hl)               ; x tile
            inc hl
            ld c,(hl)               ; y tile
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,(plr+O_XL)
            or a
            sbc hl,de
            call abs_hl
            push hl
            ld a,c
            add a,a
            add a,c
            add a,a                 ; 6y
            ld hl,plr+O_Y
            sub (hl)
            jr nc,.p
            neg
.p:         ld l,a
            ld h,0
            pop de
            add hl,de               ; |dx| + |dy|
            ld de,(hn_dist)
            or a
            sbc hl,de
            jr nc,.worse
            add hl,de
            ld (hn_dist),hl
            ld a,(hn_cand)
            ld (hn_best),a
.worse:     pop hl
            inc hl
            pop bc
            djnz .n
            ld a,(hn_best)
            ld (ix+O_TGT),a
            ret

; IX = droid: does it touch the player? C if so
touch_player:
            ld a,(plr+O_FLAGS)
            rla                     ; C = alive
            ret nc                  ; dead: never touching (NC)
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld de,(plr+O_XL)
            or a
            sbc hl,de
            call abs_hl
            ld a,h
            or a
            ret nz
            ld a,l
            cp 12
            ret nc
            ld a,(plr+O_Y)
            sub (ix+O_Y)
            jr nc,.p
            neg
.p:         cp 8
            ret

; IX = droid: A = 1 if it can see the player (in range, nothing in between)
droid_sees:
            ld a,(plr+O_FLAGS)
            bit 7,a
            jp z,.no
            ld a,(ix+O_TYPE)
            ld c,T_AGGR
            call type_stat
            or a
            jp z,.no
            ld b,a
            ; range: |dx| < 100, |dy| < 44 (aggression 1: 40 x 20)
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld de,(plr+O_XL)
            or a
            sbc hl,de
            ld (ls_dx),hl
            call abs_hl
            ld a,h
            or a
            jp nz,.no
            ld a,b
            cp 1
            ld a,l
            jr nz,.r2
            cp 40
            jp nc,.no
            jr .ry
.r2:        cp 100
            jp nc,.no
.ry:        ld a,(plr+O_Y)
            sub (ix+O_Y)
            ld (ls_dy),a
            jr nc,.py
            neg
.py:        ld c,a
            ld a,b
            cp 1
            ld a,c
            jr nz,.r3
            cp 20
            jr nc,.no
            jr .los
.r3:        cp 44
            jr nc,.no
.los:       ; march from the droid's centre to the player's in 16 steps
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld de,6
            add hl,de
            ld (ls_x),hl            ; 8.8 would be nicer; use 16ths of the delta
            ld a,(ix+O_Y)
            add a,4
            ld (ls_y),a
            ld b,1
.st:        push bc
            ; x = x0 - dx*b/16 (ls_dx is droid - player)
            ld hl,(ls_dx)
            ld a,b
            call smul_hl_a          ; HL = dx*b
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            ex de,hl
            ld hl,(ls_x)
            or a
            sbc hl,de
            ld b,h
            ld c,l
            pop de                  ; D = step
            push de
            ld a,(ls_dy)
            ld l,a
            sbc a,a
            ld h,a
            ld a,d
            call smul_hl_a
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            ld a,(ls_y)
            add a,l
            ld e,a
            call tile_at
            and A_SHOT
            pop bc
            jr nz,.no
            inc b
            ld a,b
            cp 16
            jr nz,.st
            ld a,1
            ret
.no:        xor a
            ret

; HL = HL * A (signed HL, unsigned A < 128)
smul_hl_a:
            bit 7,h
            jp z,mul16x8
            call neg_hl
            call mul16x8
            jp neg_hl

; ---------------------------------------------------------------------
; IX = droid: fire at the player (8 directions)
droid_fire:
            ld a,(ix+O_TYPE)
            ld c,T_WEAPON
            call type_stat
            ld (df_w),a
            call weapon_ptr
            ld a,(hl)               ; speed (unused here: in the dir table)
            inc hl
            inc hl
            ld a,(hl)               ; reload
            ld c,a
            ld a,(ix+O_TYPE)        ; higher classes reload a little faster
            push bc
            ld c,T_CLASS
            call type_stat
            pop bc
            ld b,a
            ld a,c
            sub b
            ld (ix+O_COOL),a
            ; direction from the droid to the player
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld de,(plr+O_XL)
            ex de,hl
            or a
            sbc hl,de               ; player - droid
            ld a,(ix+O_Y)
            ld b,a
            ld a,(plr+O_Y)
            sub b
            ld e,a                  ; dy (signed byte)
            call dir8
            ld (ix+O_FACE),a
            ld b,a
            ld a,(df_w)
            ld c,1                  ; enemy shot
            jp fire_shot

; HL = dx (signed 16), E = dy (signed 8) -> A = direction 0-7
; (0 E, 1 SE, 2 S, 3 SW, 4 W, 5 NW, 6 N, 7 NE). Rows count 3/2 a pixel.
dir8:
            ld a,h
            ld (d8_sx),a            ; sign of dx in bit 7
            call abs_hl
            ld a,h
            or a
            jr z,.s
            ld l,255
.s:         ld a,l
            ld (d8_ax),a            ; |dx| (capped)
            ld a,e
            ld (d8_sy),a
            bit 7,a
            jr z,.p
            neg
.p:         ld l,a                  ; |dy|
            ld h,0
            ld d,h
            ld e,l
            add hl,hl
            add hl,de               ; 3|dy|
            srl h
            rr l                    ; 1.5|dy| (screen units vs x's)
            ld a,h
            or a
            jr z,.q
            ld l,255
.q:         ld a,l
            ld (d8_ay),a
            ; class: horizontal if ax > 2 ay, vertical if ay > 2 ax
            ld a,(d8_ay)
            ld l,a
            ld h,0
            add hl,hl
            ld a,(d8_ax)
            ld e,a
            ld d,0
            or a
            sbc hl,de
            jr c,.horiz             ; 2ay < ax
            ld a,(d8_ax)
            ld l,a
            ld h,0
            add hl,hl
            ld a,(d8_ay)
            ld e,a
            or a
            sbc hl,de
            jr c,.vert
            ; diagonal
            ld a,(d8_sx)
            rla
            ld a,(d8_sy)
            jr c,.left
            rla
            ld a,1                  ; SE
            ret nc
            ld a,7                  ; NE
            ret
.left:      rla
            ld a,3                  ; SW
            ret nc
            ld a,5                  ; NW
            ret
.horiz:     ld a,(d8_sx)
            rla
            ld a,0
            ret nc
            ld a,4
            ret
.vert:      ld a,(d8_sy)
            rla
            ld a,2
            ret nc
            ld a,6
            ret

; A = weapon -> HL = its record (speed, damage, reload, life)
weapon_ptr:
            add a,a
            add a,a
            ld l,a
            ld h,0
            ld de,weapons
            add hl,de
            ret

; ---------------------------------------------------------------------
; IX = droid, A = damage. Kills it when its energy runs out.
droid_hurt:
            ld b,a
            ld a,(ix+O_EN)
            sub b
            jr c,droid_die
            jr z,droid_die
            ld (ix+O_EN),a
            ld (ix+O_FLASH),4
            ld (ix+O_SEEN),1        ; it knows where you are now
            ld a,SFX_HIT
            jp sfx

droid_die:
            ld (ix+O_FLAGS),0
            ld a,(ix+O_SPAWN)
            call kill_bit
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld a,(ix+O_Y)
            call fx_boom
            ld a,(ix+O_TYPE)
            call add_type_score
            ld a,SFX_BOOM
            call sfx
            jp check_cleared

; A = type: add its score value
add_type_score:
            ld c,T_SCORE
            call type_ptr
            ld de,T_SCORE
            add hl,de
            ld e,(hl)
            inc hl
            ld d,(hl)               ; BCD points (4 digits)
            call add_score
            jp alert_kill           ; (a droid gone heats the alert)

; ---------------------------------------------------------------------
draw_droids:
            ld ix,droids
            ld b,MAXDROIDS
.l:         push bc
            bit 7,(ix+O_FLAGS)
            call nz,draw_obj
            ld de,OSZ
            add ix,de
            pop bc
            djnz .l
            ret

; IX = object: draw its sprite (flashing white-hot when hit)
draw_obj:
            ld a,(ix+O_SLOT)
            add a,HIGH(SPRC)
            ld h,a
            ld l,0
            xor a
            bit 0,(ix+O_FLASH)
            jr z,.n
            ld a,$55                ; yellow silhouette
.n:         ld (spr_sil),a
            ld c,(ix+O_XL)
            ld b,(ix+O_XH)
            ld e,(ix+O_Y)
            ld d,0
            call draw_spr
            xor a
            ld (spr_sil),a
            ret
