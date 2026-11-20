; =====================================================================
;  player.asm - the link probe and its host, camera, demo pilot
;
;  Controls: direction = move.  FIRE + direction = shoot (armed host).
;  Hold FIRE still = transfer mode (the probe flashes); touch a droid
;  in transfer mode to start the circuit duel.  FIRE on a lift = lift,
;  FIRE next to a console = console.  Unarmed hosts move in transfer
;  mode while FIRE is held.
; =====================================================================

XMODE_T         equ 90              ; transfer mode lasts this many frames
BURN_T          equ 45              ; host loses 1 energy this often

EV_NONE         equ 0
EV_TRANSFER     equ 1
EV_LIFT         equ 2
EV_CONSOLE      equ 3
EV_DEAD         equ 4
EV_QUIT         equ 5
EV_CLEAR        equ 6               ; ship cleared

player_update:
        ld a,(pl_dead)
        or a
        jr z,.alive
        ld hl,dead_time
        dec (hl)
        ret nz
        ld a,EV_DEAD
        ld (event),a
        ret
.alive: ld ix,DROIDS
        inc (ix+D_ANIM)
        ld hl,DROIDS+D_FLASH
        call dec_nz
        ld hl,DROIDS+D_RELD
        call dec_nz
        ld hl,invuln
        call dec_nz
        ld hl,bump_cool
        call dec_nz
        ; input
        ld a,(demo)
        or a
        jr z,.kb
        call ai_input
        jr .gotk
.kb:    call read_keys
.gotk:  ld (keys),a
        ld c,a
        ld a,(DROIDS+D_TYPE)
        call roster_ptr
        push hl
        pop iy                      ; IY = host roster entry
        ld a,(keys)
        ld c,a
        bit B_FIRE,c
        jr z,.nofire
        ld a,c
        and K_DIRS
        jr z,.still
        ld a,(iy+R_WPN)
        or a
        jr z,.unarmed
        xor a                       ; shooting cancels transfer mode
        ld (xmode),a
        ld (fire_hold),a
        call player_shoot
        jp .after_move
.unarmed:
        call xmode_on
        jr .move
.still: ld hl,fire_hold
        ld a,(hl)
        inc a
        jr z,.cap
        ld (hl),a
.cap:   cp 1
        jr nz,.hold
        call on_lift
        jr nc,.nolift
        ld a,EV_LIFT
        ld (event),a
        ret
.nolift:
        call near_console
        jr nc,.hold
        ld a,EV_CONSOLE
        ld (event),a
        ret
.hold:  ld a,(fire_hold)
        cp 6
        call nc,xmode_on
        jp .after_move
.nofire:
        xor a
        ld (fire_hold),a
        ld hl,xmode
        call dec_nz
        jr nz,.move
        ld a,1                      ; transfer mode just ended
        ld (hud_dirty),a
.move:  ; movement
        ld a,(keys)
        and K_DIRS
        jr z,.after_move
        ld a,(ix+D_ACC)
        add a,(iy+R_SPD)
        ld (ix+D_ACC),a
        cp 16
        jr c,.after_move
        sub 16
        ld (ix+D_ACC),a
        call player_step
.after_move:
        call player_env
        jp camera_update

; HL = counter: decrement unless zero (Z set if it is zero afterwards)
dec_nz:
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret

xmode_on:
        ld a,(xmode)
        or a
        jr nz,.on
        ld hl,SFX_XMODE
        ld a,2
        call sfx
.on:    ld a,XMODE_T
        ld (xmode),a
        ret

; key bits -> D = dx, E = dy
keys_dir:
        ld a,(keys)
        ld d,0
        ld e,0
        bit B_LEFT,a
        jr z,$+3
        dec d
        bit B_RIGHT,a
        jr z,$+3
        inc d
        bit B_UP,a
        jr z,$+3
        dec e
        bit B_DOWN,a
        jr z,$+3
        inc e
        ret

player_step:
        call keys_dir
        ld a,d
        or e
        ret z
        ld (ix+D_DX),d
        ld (ix+D_DY),e
        call try_move
        ret nc                      ; moved
        ret z                       ; hit a droid (handled)
        ld a,d                      ; wall: slide along it
        or a
        ret z
        ld a,e
        or a
        ret z
        push de
        ld e,0
        call try_move
        pop de
        ret nc
        ret z
        ld d,0
        call try_move
        ret

; try to move the player by D,E.  NC = moved; C+Z = droid in the way
; (transfer or bump done); C+NZ = wall
try_move:
        ld a,(ix+D_X)
        add a,d
        ld b,a
        ld a,(ix+D_Y)
        add a,e
        ld c,a
        push de
        call fp_flags
        pop de
        and F_SOLID
        jr nz,.wall
        push de
        call droid_blocker
        pop de
        jr c,.droid
        ld (ix+D_X),b
        ld (ix+D_Y),c
        or a
        ret
.wall:  scf
        ld a,1
        or a
        scf
        ret
.droid: push ix
        push iy
        pop ix                      ; IX = the droid we touched
        call touch_enemy
        pop ix
        xor a
        scf
        ret

; IX = enemy touching the player (either way round)
bump_player:
touch_enemy:
        ld a,(xmode)
        or a
        jr z,.bump
        ld a,(event)
        or a
        ret nz
        push ix
        pop hl
        ld de,DROIDS
        or a
        sbc hl,de
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                   ; /16 -> H
        ld a,h
        ld (event_arg),a
        ld a,EV_TRANSFER
        ld (event),a
        ret
.bump:  ld a,(bump_cool)
        or a
        ret nz
        ld a,14
        ld (bump_cool),a
        ld hl,SFX_BUMP
        ld a,3
        call sfx
        ld a,2
        push ix
        call damage_enemy
        pop ix
        ld a,1
        jp damage_player

; FIRE + direction with an armed host
player_shoot:
        ld a,(DROIDS+D_RELD)
        or a
        ret nz
        call keys_dir
        ld b,d
        ld c,e
        ld a,e
        or a
        jr nz,.notpure
        ; horizontal: alternate rows (twin lasers fire both)
        ld a,(DROIDS+D_ANIM)
        and 1
        ld e,a
        ld a,(DROIDS+D_Y)
        add a,e
        ld l,a
        ld a,b
        cp 1
        ld a,(DROIDS+D_X)
        jr nz,.h1
        add a,4
.h1:    dec a
        ld h,a
        xor a
        jr .go
.notpure:
        ld a,d
        or a
        jr nz,.diag
        ld a,(DROIDS+D_X)           ; vertical
        inc a
        ld h,a
        ld a,c
        cp 1
        ld a,(DROIDS+D_Y)
        jr nz,.v1
        add a,3
.v1:    dec a
        ld l,a
        ld a,1
        jr .go
.diag:  ld a,b
        cp 1
        ld a,(DROIDS+D_X)
        jr nz,.d1
        add a,4
.d1:    dec a
        ld h,a
        ld a,c
        cp 1
        ld a,(DROIDS+D_Y)
        jr nz,.d2
        add a,3
.d2:    dec a
        ld l,a
        ld a,b
        xor c
        rla
        ld a,2
        jr c,.go
        inc a
.go:    ld (shot_kind),a
        ld (shot_dir),bc
        ld (shot_pos),hl
        xor a
        ld (shot_own),a
        ld a,(iy+R_DMG)
        ld (shot_dmg),a
        ld a,(iy+R_RANGE)
        add a,2
        ld (shot_life),a
        call shot_spawn
        ; twin lasers: second shot on the other row
        ld a,(iy+R_WPN)
        cp W_TWIN
        jr nz,.one
        ld a,(shot_kind)
        or a
        jr nz,.one
        ld hl,(shot_pos)
        ld a,(DROIDS+D_Y)
        cp l
        jr nz,.up
        inc l
        jr .two
.up:    dec l
.two:   ld (shot_pos),hl
        call shot_spawn
.one:   ld a,(iy+R_RELOAD)
        ld (DROIDS+D_RELD),a
        ld hl,SFX_ZAP
        ld a,(iy+R_WPN)
        cp W_CANNON
        jr nz,$+5
        ld hl,SFX_CANNON
        ld a,2
        jp sfx

; carry = standing on a lift pad (sets lift_x/lift_y/lift_shaft)
on_lift:
        ld a,(nlifts)
        or a
        ret z
        ld b,a
        ld hl,LIFTS
.l:     ld a,(DROIDS+D_Y)
        inc hl
        cp (hl)                     ; same row as the pad
        dec hl
        jr nz,.n
        ld a,(DROIDS+D_X)
        sub (hl)
        inc a
        cp 3                        ; within one cell
        jr nc,.n
        ld a,(hl)
        ld (lift_x),a
        inc hl
        ld a,(hl)
        ld (lift_y),a
        inc hl
        ld a,(hl)
        ld (lift_shaft),a
        scf
        ret
.n:     inc hl
        inc hl
        inc hl
        inc hl
        djnz .l
        or a
        ret

; carry = a console is right next to the player
near_console:
        ld a,(ncons)
        or a
        ret z
        ld b,a
        ld hl,CONS
.l:     ld a,(DROIDS+D_X)           ; console x in [px-2, px+3]
        sub 2
        ld c,a
        ld a,(hl)
        sub c
        cp 6
        jr nc,.n
        inc hl
        ld a,(DROIDS+D_Y)           ; console y in [py-1, py+2]
        dec a
        ld c,a
        ld a,(hl)
        dec hl
        sub c
        cp 4
        jr nc,.n
        scf
        ret
.n:     inc hl
        inc hl
        djnz .l
        or a
        ret

; energizers, burnout, low-energy alarm
player_env:
        ld a,(DROIDS+D_TYPE)
        call roster_ptr
        ld bc,R_EN
        add hl,bc
        ld c,(hl)                   ; C = max energy
        ld a,(DROIDS+D_X)
        ld b,a
        push bc
        ld a,(DROIDS+D_Y)
        ld c,a
        call fp_flags
        pop bc
        and F_ENER
        jr z,.noener
        ld a,(frame)
        and 1
        jr nz,.burn
        ld a,(DROIDS+D_EN)
        cp c
        jr nc,.full
        inc a
        ld (DROIDS+D_EN),a
        ld a,1
        ld (hud_dirty),a
        ld a,(frame)
        and 7
        jr nz,.burn
        ld hl,SFX_CHARGE
        ld a,1
        call sfx
        jr .burn
.full:  ld a,BURN_T                 ; full: no burnout while on the pad
        ld (burn_time),a
        jr .alarm
.noener:
.burn:  ld a,(DROIDS+D_TYPE)
        or a
        jr z,.alarm                 ; the probe itself never burns out
        ld hl,burn_time
        dec (hl)
        jr nz,.alarm
        ld (hl),BURN_T
        ld hl,DROIDS+D_EN
        dec (hl)
        ld a,1
        ld (hud_dirty),a
        ld a,(hl)
        or a
        jp z,host_destroyed
.alarm: ld a,(DROIDS+D_EN)          ; below a quarter: beep
        add a,a
        add a,a
        cp c
        ret nc
        ld a,(frame)
        and 15
        ret nz
        ld hl,SFX_ALARM
        ld a,1
        jp sfx

; the host's energy ran out
host_destroyed:
        ld a,40
        ld (invuln),a
        ld a,(DROIDS+D_X)
        ld b,a
        ld a,(DROIDS+D_Y)
        ld c,a
        call expl_spawn
        xor a
        ld (xmode),a
        ld a,(DROIDS+D_TYPE)
        or a
        jr nz,.eject
        ld a,1                      ; the probe is gone: game over
        ld (pl_dead),a
        ld a,60
        ld (dead_time),a
        ld hl,SFX_DEATH
        ld a,6
        jp sfx
.eject: xor a
        ld (DROIDS+D_TYPE),a
        ld a,15
        ld (DROIDS+D_EN),a
        push ix
        ld ix,DROIDS
        call droid_setup
        pop ix
        ld a,1
        ld (hud_dirty),a
        ld hl,txt_ejected
        ld a,60
        call hud_msg
        ld hl,SFX_BOOM
        ld a,5
        jp sfx

txt_ejected: db "HOST LOST - PROBE OUT",0

; ---------------------------------------------------------------------
; camera: keep the player near the centre (dead zone 2 x 1)
; ---------------------------------------------------------------------
camera_update:
        ld a,(DROIDS+D_X)
        sub 19
        ld b,a                      ; ideal camx
        ld a,(camx)
        sub b
        jr z,.y
        jp p,.right
        cp -2
        jr nc,.y
        ld a,b
        sub 2
        ld (camx),a
        jr .y
.right: cp 3
        jr c,.y
        ld a,b
        add a,2
        ld (camx),a
.y:     ld a,(DROIDS+D_Y)
        sub 10
        ld b,a
        ld a,(camy)
        sub b
        ret z
        jp p,.down
        cp -1
        ret nc
        ld a,b
        dec a
        ld (camy),a
        ret
.down:  cp 2
        ret c
        ld a,b
        inc a
        ld (camy),a
        ret

camera_snap:
        ld a,(DROIDS+D_X)
        sub 19
        ld (camx),a
        ld a,(DROIDS+D_Y)
        sub 10
        ld (camy),a
        ret

; =====================================================================
;  demo pilot: plays the game on its own for the attract mode
; =====================================================================
ai_input:
        call anykey
        jr z,.nokey
        ld a,1
        ld (demo_abort),a
        ld a,EV_QUIT
        ld (event),a
        xor a
        ret
.nokey: ld hl,(demo_time)
        dec hl
        ld (demo_time),hl
        ld a,h
        or l
        jr nz,.go
        ld a,EV_QUIT
        ld (event),a
        xor a
        ret
.go:    ; stuck?
        ld a,(DROIDS+D_X)
        ld hl,ai_lastx
        cp (hl)
        ld (hl),a
        jr nz,.moved
        ld a,(DROIDS+D_Y)
        ld hl,ai_lasty
        cp (hl)
        ld (hl),a
        jr nz,.moved
        ld a,(ai_keys)
        and K_DIRS
        jr z,.moved2
        ld hl,ai_stuck
        inc (hl)
        ld a,(hl)
        cp 18
        jr c,.moved2
        ld (hl),0
        call ai_snap                ; re-plan from the nearest waypoint
        call rand
        and K_DIRS
        ld (ai_keys),a
        ret
.moved: ld a,(DROIDS+D_Y)
        ld (ai_lasty),a
        xor a
        ld (ai_stuck),a
.moved2:
        ; pick a target now and then
        ld hl,ai_think
        ld a,(hl)
        or a
        jr z,.think
        dec (hl)
        ld a,(ai_target)
        cp 0FFh
        jr z,.think
        call slot_ix_tgt
        ld a,(iy+D_TYPE)
        cp 0FFh
        jr nz,.have
.think: ld a,20
        ld (ai_think),a
        call ai_choose
.have:  ld a,(ai_target)
        cp 0FFh
        jp z,ai_go_lift
        call slot_ix_tgt            ; IY = target droid
        ; close enough to engage directly?
        ld a,(iy+D_X)
        sub (ix+D_X)
        ld d,a
        call abs_a
        cp 13
        jr nc,.far
        ld a,(iy+D_Y)
        sub (ix+D_Y)
        ld e,a
        call abs_a
        cp 6
        jr nc,.far
        ; same room?  check a straight step line is clear
        call ai_clear_to
        jr nc,.far
        ld a,(ai_want_xfer)
        or a
        jp nz,ai_do_xfer
        jp ai_do_shoot
.far:   ; follow the waypoint graph to the target's nearest waypoint
        ld b,(iy+D_X)
        ld c,(iy+D_Y)
        call nearest_node
        ld hl,ai_tnode
        cp (hl)
        jr z,.same
        ld (hl),a
        call bfs_from
        call ai_snap
.same:  ld a,(ai_node)
        call node_xy
        ld a,b
        cp (ix+D_X)
        jr nz,.walk
        ld a,c
        cp (ix+D_Y)
        jr nz,.walk
        ; at the waypoint: next one downhill
        ld a,(ai_node)
        call adj_ptr
        ld b,(hl)
        inc hl
        ld c,0FFh
        ld e,0FFh
.nb:    ld a,(hl)
        push hl
        add a,low DIST
        ld l,a
        ld a,high DIST
        adc a,0
        ld h,a
        ld a,(hl)
        pop hl
        cp c
        jr nc,.nw
        ld c,a
        ld e,(hl)
.nw:    inc hl
        djnz .nb
        ld a,e
        cp 0FFh
        jr z,.idle
        ld (ai_node),a
        call node_xy
.walk:  ; direction towards (B,C)
        ld a,b
        sub (ix+D_X)
        call sign
        ld d,a
        ld a,c
        sub (ix+D_Y)
        call sign
        ld e,a
        call dir_keys
        ld (ai_keys),a
        ret
.idle:  xor a
        ld (ai_keys),a
        ret

; IY = droid in slot ai_target
slot_ix_tgt:
        ld a,(ai_target)
slot_iy:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,DROIDS
        add hl,de
        push hl
        pop iy
        ret

; D,E = dx,dy -> A = key bits
dir_keys:
        xor a
        bit 7,d
        jr z,$+4
        or K_LEFT
        inc d
        dec d
        jr z,.y
        bit 7,d
        jr nz,.y
        or K_RIGHT
.y:     bit 7,e
        jr z,$+4
        or K_UP
        inc e
        dec e
        ret z
        bit 7,e
        ret nz
        or K_DOWN
        ret

; nearest enemy becomes the target; decide shoot or transfer
ai_choose:
        ld a,0FFh
        ld (ai_target),a
        ; looking for a body (unarmed or weak): prefer low classes
        xor a
        ld (ai_pref),a
        ld a,(DROIDS+D_TYPE)
        call roster_ptr
        ld bc,R_WPN
        add hl,bc
        ld a,(hl)
        or a
        jr z,.pref
        ld a,(DROIDS+D_EN)
        cp 14
        jr nc,.nopref
.pref:  ld a,1
        ld (ai_pref),a
.nopref:
        ld c,0FFh                   ; best distance
        ld iy,DROIDS+DSZ
        ld b,NDROIDS-1
        ld e,1
.l:     ld a,(iy+D_TYPE)
        cp 0FFh
        jr z,.n
        push bc
        push de
        ld b,(iy+D_X)
        ld c,(iy+D_Y)
        call dist_to_player
        ld c,a
        ld a,(ai_pref)
        or a
        jr z,.np
        ld a,(iy+D_TYPE)
        call roster_ptr
        ld de,R_CLASS
        add hl,de
        ld a,(hl)
        add a,a
        add a,a
        add a,a
        add a,a                     ; class * 16
        add a,c
        jr nc,$+4
        ld a,0FEh
        ld c,a
.np:    ld a,c
        pop de
        pop bc
        cp c
        jr nc,.n
        ld c,a
        ld a,e
        ld (ai_target),a
.n:     push de
        ld de,DSZ
        add iy,de
        pop de
        inc e
        djnz .l
        ld a,(ai_target)
        cp 0FFh
        ret z
        call slot_ix_tgt
        ; transfer if unarmed, if low on energy, or sometimes when the
        ; target is not much stronger
        ld a,(DROIDS+D_TYPE)
        call roster_ptr
        ld bc,R_WPN
        add hl,bc
        ld a,(hl)
        or a
        jr z,.xfer
        ld a,(DROIDS+D_EN)
        cp 14
        jr c,.xfer
        ld a,(iy+D_TYPE)
        call roster_ptr
        ld bc,R_CLASS
        add hl,bc
        ld b,(hl)
        ld a,(DROIDS+D_TYPE)
        call roster_ptr
        ld de,R_CLASS
        add hl,de
        ld c,a                      ; C = host class, B = target class
        ld a,b
        cp c
        jr c,.shoot                 ; weaker than our host: just shoot it
        sub c
        cp 3
        jr nc,.shoot                ; far stronger: shoot it
        call rand
        cp 150
        jr c,.xfer
.shoot: xor a
        jr .set
.xfer:  ld a,1
.set:   ld (ai_want_xfer),a
        ret

; carry = straight step line from the player to the target is clear
ai_clear_to:
        ld b,(ix+D_X)
        ld c,(ix+D_Y)
        ld e,30
.l:     ld a,(iy+D_X)
        sub b
        call sign
        ld d,a
        ld a,(iy+D_Y)
        sub c
        call sign
        or d
        scf
        ret z
        ld a,(iy+D_X)
        sub b
        call sign
        add a,b
        ld b,a
        ld a,(iy+D_Y)
        sub c
        call sign
        add a,c
        ld c,a
        ; touching the target counts as there
        push de
        push iy
        call in_target
        pop iy
        pop de
        ret c
        push de
        call fp_flags
        pop de
        and F_SOLID
        ret nz                      ; NC (and has flags) -> blocked
        dec e
        jr nz,.l
        or a
        ret

; carry if footprint (B,C) overlaps the target IY
in_target:
        ld a,(iy+D_X)
        sub b
        add a,2
        cp 5
        ret nc
        ld a,(iy+D_Y)
        sub c
        inc a
        cp 3
        ret

ai_do_xfer:
        ld a,(xmode)
        or a
        jr nz,.go
        ld a,K_FIRE                 ; hold fire to arm transfer mode
        ld (ai_keys),a
        ret
.go:    ld a,(iy+D_X)
        sub (ix+D_X)
        call sign
        ld d,a
        ld a,(iy+D_Y)
        sub (ix+D_Y)
        call sign
        ld e,a
        call dir_keys
        ld (ai_keys),a
        ret

ai_do_shoot:
        ld a,(iy+D_X)
        sub (ix+D_X)
        ld d,a
        ld a,(iy+D_Y)
        sub (ix+D_Y)
        ld e,a
        or a
        jr nz,.notrow
        ld a,d
        call abs_a
        cp 4
        jr c,.back
        ld a,d                      ; in line: fire along the row
        call sign
        ld d,a
        ld e,0
        call dir_keys
        or K_FIRE
        ld (ai_keys),a
        ret
.notrow:
        ld a,d
        inc a
        cp 3
        jr nc,.align
        ld a,e
        call abs_a
        cp 3
        jr c,.back
        ld d,0
        ld a,e
        call sign
        ld e,a
        call dir_keys
        or K_FIRE
        ld (ai_keys),a
        ret
.align: ; line up on the target's row, keep some distance
        ld a,e
        call sign
        ld e,a
        ld a,d
        call abs_a
        cp 6
        ld a,0
        jr nc,.keep
        ld a,d
        call sign
        neg
.keep:  ld d,a
        call dir_keys
        ld (ai_keys),a
        ret
.back:  ld a,d                      ; too close: back off
        call sign
        neg
        ld d,a
        ld e,0
        call dir_keys
        ld (ai_keys),a
        ret

; no enemies left: walk to the nearest lift and use it
ai_go_lift:
        ld a,(nlifts)
        or a
        jp z,.idle
        call on_lift
        jr nc,.walk
        ld a,(frame)
        and 1
        ld a,K_FIRE
        jr z,$+3
        xor a
        ld (ai_keys),a
        ret
.walk:  ld a,(LIFTS)
        ld b,a
        ld a,(LIFTS+1)
        ld c,a
        call nearest_node
        ld hl,ai_tnode
        cp (hl)
        jr z,.same
        ld (hl),a
        call bfs_from
        call ai_snap
.same:  ld a,(ai_node)
        call node_xy
        ld a,b
        cp (ix+D_X)
        jr nz,.go
        ld a,c
        cp (ix+D_Y)
        jr nz,.go
        ld a,(ai_node)
        ld hl,ai_tnode
        cp (hl)
        jr z,.onpad
        call adj_ptr
        ld b,(hl)
        inc hl
        ld c,0FFh
        ld e,0FFh
.nb:    ld a,(hl)
        push hl
        add a,low DIST
        ld l,a
        ld a,high DIST
        adc a,0
        ld h,a
        ld a,(hl)
        pop hl
        cp c
        jr nc,.nw
        ld c,a
        ld e,(hl)
.nw:    inc hl
        djnz .nb
        ld a,e
        ld (ai_node),a
        call node_xy
.go:    ld a,b
        sub (ix+D_X)
        call sign
        ld d,a
        ld a,c
        sub (ix+D_Y)
        call sign
        ld e,a
        call dir_keys
        ld (ai_keys),a
        ret
.onpad: ld a,(LIFTS)                ; step onto the pad itself
        ld b,a
        ld a,(LIFTS+1)
        ld c,a
        jr .go
.idle:  xor a
        ld (ai_keys),a
        ret

; ai_node = waypoint nearest the player
ai_snap:
        ld b,(ix+D_X)
        ld c,(ix+D_Y)
        call nearest_node
        ld (ai_node),a
        ret

; B,C = position -> A = nearest waypoint (Manhattan distance)
nearest_node:
        push de
        push hl
        ld hl,NODES
        ld a,(nnodes)
        ld d,a
        ld e,0                      ; index
        ld a,0FFh
        ld (nn_best),a
        xor a
        ld (nn_node),a
.l:     ld a,(hl)
        sub b
        call abs_a
        push af
        inc hl
        ld a,(hl)
        inc hl
        sub c
        call abs_a
        add a,a
        ld (nn_tmp),a
        pop af
        push hl
        ld hl,nn_tmp
        add a,(hl)
        jr nc,$+4
        ld a,0FEh
        ld hl,nn_best
        cp (hl)
        jr nc,.n
        ld (hl),a
        ld a,e
        ld (nn_node),a
.n:     pop hl
        inc e
        dec d
        jr nz,.l
        ld a,(nn_node)
        pop hl
        pop de
        ret

; breadth-first distances (in hops) from waypoint ai_tnode into DIST
bfs_from:
        ld hl,DIST
        ld b,MAXNODES
.c:     ld (hl),0FFh
        inc hl
        djnz .c
        ld a,(ai_tnode)
        ld e,a
        ld d,0
        ld hl,DIST
        add hl,de
        ld (hl),0
        ld hl,BFSQ
        ld (hl),a
        ld (bfs_head),hl
        inc hl
        ld (bfs_tail),hl
.q:     ld hl,(bfs_head)
        ld de,(bfs_tail)
        or a
        sbc hl,de
        ret z
        add hl,de
        ld a,(hl)                   ; node
        inc hl
        ld (bfs_head),hl
        ld e,a
        ld d,0
        ld hl,DIST
        add hl,de
        ld a,(hl)
        inc a
        ld c,a                      ; distance of neighbours
        ld a,e
        call adj_ptr
        ld b,(hl)
        inc hl
.nb:    ld e,(hl)
        inc hl
        push hl
        ld d,0
        ld hl,DIST
        add hl,de
        ld a,(hl)
        cp 0FFh
        jr nz,.seen
        ld (hl),c
        ld hl,(bfs_tail)
        ld (hl),e
        inc hl
        ld (bfs_tail),hl
.seen:  pop hl
        djnz .nb
        jr .q
