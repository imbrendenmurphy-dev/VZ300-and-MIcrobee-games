; =====================================================================
;  ACTORS: Wally, the Kaboomerang, the wildlife. Drawing them.
; =====================================================================
DIR_R   equ 0
DIR_L   equ 1
DIR_U   equ 2
DIR_D   equ 3

; A = action, B = frames
set_act:
        ld (p_act),a
        ld a,b
        ld (p_actt),a
        ret

; direction A -> D = dx, E = dy (signed)
dir_vec:
        ld de,$0100
        or a
        ret z
        ld de,$FF00
        dec a
        ret z
        ld de,$00FF
        dec a
        ret z
        ld de,$0001
        ret

; ---------------------------------------------------------------------
; step_thing: move the thing at (C = hx, B = hy) one unit in direction A,
; sliding around corners. -> NC moved (B, C updated), C = blocked
step_thing:
        ld (t_dir),a
        call dir_vec
        ld a,d
        or a
        jr z,.vert
        ; horizontal
        ld a,b
        and 7
        jr z,.hal
        ; not on a row: slide towards the nearer open row
        ld (t_tx),a             ; misalignment 1..7
        ld a,c
        call round_t
        add a,d
        ld d,a                  ; target column
        ld a,b
        rrca
        rrca
        rrca
        and $1F
        ld e,a                  ; row above
        ld a,(t_tx)
        cp 4
        jr c,.hn
        inc e                   ; nearer: the row below
        call can_enter
        jr z,.hdown
        dec e
        call can_enter
        jr z,.hup
        scf
        ret
.hn:    call can_enter
        jr z,.hup
        inc e
        call can_enter
        jr z,.hdown
        scf
        ret
.hup:   dec b
        or a
        ret
.hdown: inc b
        or a
        ret
.hal:   ld a,c
        and 7
        jr nz,.hgo
        ld a,c
        rrca
        rrca
        rrca
        and $1F
        add a,d
        push de
        ld d,a
        ld a,b
        rrca
        rrca
        rrca
        and $1F
        ld e,a
        call can_enter
        pop de
        scf
        ret nz
.hgo:   ld a,c
        add a,d
        ld c,a
        or a
        ret
.vert:  ld a,c
        and 7
        jr z,.val
        ld (t_tx),a
        ld a,b
        call round_t
        add a,e
        ld e,a                  ; target row
        ld a,c
        rrca
        rrca
        rrca
        and $1F
        ld d,a                  ; column left
        ld a,(t_tx)
        cp 4
        jr c,.vn
        inc d
        call can_enter
        jr z,.vright
        dec d
        call can_enter
        jr z,.vleft
        scf
        ret
.vn:    call can_enter
        jr z,.vleft
        inc d
        call can_enter
        jr z,.vright
        scf
        ret
.vleft: dec c
        or a
        ret
.vright: inc c
        or a
        ret
.val:   ld a,b
        and 7
        jr nz,.vgo
        ld a,b
        rrca
        rrca
        rrca
        and $1F
        add a,e
        push de
        ld e,a
        ld a,c
        rrca
        rrca
        rrca
        and $1F
        ld d,a
        call can_enter
        pop de
        scf
        ret nz
.vgo:   ld a,b
        add a,e
        ld b,a
        or a
        ret

; ---------------------------------------------------------------------
; the player
player_update:
        ld a,(p_act)
        or a
        jr z,.na
        ld hl,p_actt
        dec (hl)
        jr nz,.na
        xor a
        ld (p_act),a
.na:    ld a,(p_inv)
        or a
        jr z,.ni
        dec a
        ld (p_inv),a
.ni:    ld a,(gstate)
        or a
        ret nz
        ; newest direction pressed, and a short memory of taps
        ld a,(padnew)
        and $0F
        jr z,.nonew
        ld b,0
.nb:    rrca
        jr c,.got
        inc b
        jr .nb
.got:   ld a,b
        ld (p_last),a
        ld (p_buf),a
        ld a,6
        ld (p_buft),a
.nonew: ld a,(p_buft)
        or a
        jr z,.nbt
        dec a
        ld (p_buft),a
.nbt:   ; busy?
        ld a,(p_act)
        cp ACT_HURT
        jr z,.nomove
        cp ACT_DEAD
        jr z,.nomove
        cp ACT_WIN
        jr z,.nomove
        ld a,(p_speed)
        or a
        ld a,1
        jr z,.sp
        ld a,(gtick)
        and 1
        inc a
.sp:    ld (t_n),a
        xor a
        ld (p_moving),a
.mv:    call try_dirs
        jr c,.nomove
        ld a,1
        ld (p_moving),a
        ld hl,t_n
        dec (hl)
        jr nz,.mv
.nomove:
        ld a,(p_moving)
        or a
        jr z,.idle
        ld hl,p_anim
        inc (hl)
        xor a
        ld (p_idle),a
        jr .sf
.idle:  ld hl,p_idle
        inc (hl)
        jr nz,.sf
        dec (hl)
.sf:    ; safe in a burrow (standing in it, lined up)
        xor a
        ld (p_safe),a
        ld a,(p_hx)
        ld c,a
        and 7
        jr nz,.nsafe
        ld a,(p_hy)
        ld b,a
        and 7
        jr nz,.nsafe
        ld a,c
        rrca
        rrca
        rrca
        ld d,a
        ld a,b
        rrca
        rrca
        rrca
        ld e,a
        call amap_at
        cp M_BURROW
        jr nz,.nsafe
        ld a,1
        ld (p_safe),a
.nsafe: ; fire: a bomb, or (when none can go down) the boomerang
        ld a,(padnew)
        and $10
        jr z,.nbomb
        call place_bomb
        jr nc,.placed
        call throw_boom
        jr .nbomb
.placed: ld a,ACT_PLACE
        ld b,5
        call set_act
.nbomb: ld a,(padnew)
        and $20
        call nz,throw_boom
        ; items
        ld a,(p_hx)
        call round_t
        ld d,a
        ld a,(p_hy)
        call round_t
        ld e,a
        call tidx
        ld bc,imap
        add hl,bc
        ld a,(hl)
        or a
        ret z
        ret m                   ; still hidden
        cp IT_EXIT
        jr z,.exit
        ld (hl),0
        push af
        call draw_tile
        pop af
        jp pickup
.exit:  ld a,(allclear)
        or a
        ret z
        ld a,(p_hx)
        and 7
        ret nz
        ld a,(p_hy)
        and 7
        ret nz
        jp stage_clear

; try the wanted directions in order -> NC moved
try_dirs:
        ld a,(p_buft)           ; a tapped direction first
        or a
        jr z,.held
        ld a,(p_buf)
        call try_dir
        ret nc
.held:  ld a,(pad)
        and $0F
        scf
        ret z
        ld b,a
        ld a,(p_last)           ; the newest held one
        call .bit
        and b
        jr z,.others
        ld a,(p_last)
        call try_dir
        ret nc
.others: ld c,0
.o:     ld a,c
        call .bit
        and b
        jr z,.on
        push bc
        ld a,c
        call try_dir
        pop bc
        ret nc
        ld a,(pad)              ; blocked: face the newest held way
.on:    inc c
        ld a,c
        cp 4
        jr nz,.o
        ld a,(pad)
        and $0F
        ld b,a
        ld a,(p_last)
        call .bit
        and b
        jr z,.nf
        ld a,(p_last)
        ld (p_dir),a
.nf:    scf
        ret
.bit:   push bc
        ld b,a
        inc b
        ld a,$80
.bl:    rlca
        djnz .bl
        pop bc
        ret
; A = direction: one unit that way -> NC moved
try_dir:
        push af
        ld a,(p_hx)
        ld c,a
        ld a,(p_hy)
        ld b,a
        pop af
        push af
        call step_thing
        pop de
        ret c
        ld a,c
        ld (p_hx),a
        ld a,b
        ld (p_hy),a
        ld a,d
        ld (p_dir),a
        or a
        ret

; A = item picked up
pickup:
        cp IT_FIRE
        jr nz,.n1
        ld hl,p_range
        ld a,(hl)
        cp 8
        jr nc,.done
        inc (hl)
        jr .done
.n1:    cp IT_NUT
        jr nz,.n2
        ld hl,p_bombs
        ld a,(hl)
        cp 8
        jr nc,.done
        inc (hl)
        jr .done
.n2:    cp IT_HEART
        jr nz,.n3
        ld a,(p_maxh)
        ld b,a
        ld a,(p_hearts)
        cp b
        jr nc,.done
        inc a
        ld (p_hearts),a
        jr .done
.n3:    ld a,1                  ; thongs
        ld (p_speed),a
.done:  ld a,1
        ld (hud_dirty),a
        ld de,$0050
        call add_score
        ld a,SFX_PICKUP
        call play_sfx
        ld a,(p_act)
        or a
        jr z,.hop
        cp ACT_STARTLE
        ret nz
.hop:   ld a,ACT_COLLECT
        ld b,11
        jp set_act

hurt:
        ld a,(p_inv)
        or a
        ret nz
        ld a,(gstate)
        or a
        ret nz
        ld a,(p_safe)
        or a
        ret nz
        ld a,50
        ld (p_inv),a
        ld a,1
        ld (hud_dirty),a
        ld a,SFX_HURT
        call play_sfx
        ld hl,p_hearts
        dec (hl)
        jr z,.dead
        ld a,ACT_HURT
        ld b,12
        jp set_act
.dead:  ld a,ACT_DEAD
        ld b,100
        call set_act
        ld a,2
        ld (gstate),a
        ld a,100
        ld (gtimer),a
        call stop_music
        ld hl,mus_over_0
        ld de,mus_over_1
        call play_music
        ld hl,s_over
        jp show_msg
s_over: db "WALLY'S DONE IN!",0

stage_clear:
        ld a,1
        ld (gstate),a
        ld a,90
        ld (gtimer),a
        ld a,ACT_WIN
        ld b,90
        call set_act
        ld de,$1000
        call add_score
        call stop_music
        ld hl,mus_clear_0
        ld de,mus_clear_1
        call play_music
        ld hl,s_clear
        jp show_msg
s_clear: db "STAGE CLEAR!",0

; ---------------------------------------------------------------------
; the Kaboomerang
throw_boom:
        ld a,(bm_on)
        or a
        ret nz
        ld a,(p_dir)
        call dir_vec
        ld a,d
        ld (bm_dx),a
        ld a,e
        ld (bm_dy),a
        ; start lined up with Wally's tile across the throw
        ld a,(p_hx)
        ld c,a
        ld a,(p_hy)
        ld b,a
        ld a,d
        or a
        jr nz,.h
        ld a,c
        call round_t
        add a,a
        add a,a
        add a,a
        ld c,a
        jr .s
.h:     ld a,b
        call round_t
        add a,a
        add a,a
        add a,a
        ld b,a
.s:     ld a,c
        ld (bm_hx),a
        ld a,b
        ld (bm_hy),a
        ld a,1
        ld (bm_on),a
        ld (bm_out),a
        ld (hud_dirty),a
        xor a
        ld (bm_dist),a
        ld (bm_carry),a
        ld a,SFX_THROW
        jp play_sfx

BM_SPEED equ 3
boom_update:
        ld a,(bm_on)
        or a
        ret z
        ld hl,bm_f
        inc (hl)
        ld a,(bm_out)
        or a
        jp z,.back
        ; out: fly straight, 4 tiles or until something stops it
        ld a,(bm_dx)
        ld b,a
        add a,a
        add a,b
        ld b,a
        ld a,(bm_hx)
        add a,b
        ld (bm_hx),a
        ld a,(bm_dy)
        ld b,a
        add a,a
        add a,b
        ld b,a
        ld a,(bm_hy)
        add a,b
        ld (bm_hy),a
        ld a,(bm_dist)
        add a,BM_SPEED
        ld (bm_dist),a
        ; the leading edge in a wall?
        ld a,(bm_hx)
        ld c,a
        ld a,(bm_dx)
        cp 1
        jr nz,.e1
        ld a,c
        add a,7
        ld c,a
.e1:    ld a,(bm_dx)
        or a
        jr nz,.e2
        ld a,c
        add a,4
        ld c,a
.e2:    ld a,c
        rrca
        rrca
        rrca
        and $1F
        ld d,a
        ld a,(bm_hy)
        ld c,a
        ld a,(bm_dy)
        cp 1
        jr nz,.e3
        ld a,c
        add a,7
        ld c,a
.e3:    ld a,(bm_dy)
        or a
        jr nz,.e4
        ld a,c
        add a,4
        ld c,a
.e4:    ld a,c
        rrca
        rrca
        rrca
        and $1F
        ld e,a
        call walkable
        jr z,.open
        ; snap back to the last tile
        ld a,(bm_hx)
        call round_t
        ld b,a
        ld a,(bm_dx)
        cp 1
        jr nz,.s1
        dec b
.s1:    ld a,b
        add a,a
        add a,a
        add a,a
        ld (bm_hx),a
        ld a,(bm_hy)
        call round_t
        ld b,a
        ld a,(bm_dy)
        cp 1
        jr nz,.s2
        dec b
.s2:    ld a,b
        add a,a
        add a,a
        add a,a
        ld (bm_hy),a
        jr .stop
.open:  call boom_touch
        jr c,.stop
        ld a,(bm_dist)
        cp 32
        ret c
.stop:  xor a
        ld (bm_out),a
        ld a,(bm_carry)         ; drop a carried bomb here
        or a
        ret z
        dec a
        call bomb_ix
        ld a,(bm_hx)
        call round_t
        ld d,a
        ld a,(bm_hy)
        call round_t
        ld e,a
        ld b,8
.free:  push bc
        call walkable
        jr nz,.bk
        call bomb_at
        jr nz,.bk
        call amap_at
        cp M_BURROW
        jr nz,.ok
.bk:    pop bc                  ; step back towards Wally
        ld a,(bm_dx)
        neg
        add a,d
        ld d,a
        ld a,(bm_dy)
        neg
        add a,e
        ld e,a
        djnz .free
        ret
.ok:    pop bc
        ld (ix+B_TX),d
        ld (ix+B_TY),e
        ld (ix+B_CARRIED),0
        xor a
        ld (bm_carry),a
        ld a,(ix+B_ON)
        or a
        ret z
        call tidx
        ld bc,bmap
        add hl,bc
        ld a,(bm_carry)
        push ix
        pop bc
        push hl
        ld hl,-bombs
        add hl,bc
        ld a,l
        rrca
        rrca
        rrca
        inc a
        pop hl
        ld (hl),a
        call draw_tile
        ld a,SFX_PLACE
        jp play_sfx
.back:  ; home to Wally
        ld a,(p_hx)
        ld hl,bm_hx
        call .toward
        ld a,(p_hy)
        ld hl,bm_hy
        call .toward
        call boom_touch
        ld a,(p_hx)
        ld hl,bm_hx
        sub (hl)
        jr nc,$+4
        neg
        cp 4
        ret nc
        ld a,(p_hy)
        ld hl,bm_hy
        sub (hl)
        jr nc,$+4
        neg
        cp 4
        ret nc
        xor a                   ; caught
        ld (bm_on),a
        ld a,1
        ld (hud_dirty),a
        ld a,(bm_carry)         ; still carrying? put the bomb at Wally's feet
        or a
        jr z,.cs
        ld a,1
        ld (bm_out),a
        ld (bm_on),a
        jp .stop
.cs:    ld a,SFX_CATCH
        jp play_sfx
.toward:
        sub (hl)
        ret z
        jr c,.neg
        cp BM_SPEED+1
        jr c,.add
        ld a,BM_SPEED
.add:   add a,(hl)
        ld (hl),a
        ret
.neg:   neg
        cp BM_SPEED+1
        jr c,.sub
        ld a,BM_SPEED
.sub:   ld b,a
        ld a,(hl)
        sub b
        ld (hl),a
        ret

; what the boomerang touches: bombs (picked up), items (fetched), wildlife
; (stunned) -> C = it stops
boom_touch:
        ld a,(bm_out)           ; flying out: a bomb under either tile it overlaps?
        or a
        jr z,.nob0
        ld a,(bm_carry)
        or a
        jr nz,.nob0
        ld a,(bm_hx)
        rrca
        rrca
        rrca
        and $1F
        ld d,a
        ld a,(bm_hy)
        rrca
        rrca
        rrca
        and $1F
        ld e,a
        call bomb_at
        jr nz,.take
        ld a,(bm_hx)
        add a,7
        rrca
        rrca
        rrca
        and $1F
        ld d,a
        ld a,(bm_hy)
        add a,7
        rrca
        rrca
        rrca
        and $1F
        ld e,a
        call bomb_at
        jr z,.nob0
.take:  ld (bm_carry),a
        ld (hl),0
        dec a
        call bomb_ix
        ld (ix+B_CARRIED),1
        call draw_tile
        ld a,SFX_CATCH
        call play_sfx
.nob0:  ld a,(bm_hx)
        call round_t
        ld d,a
        ld a,(bm_hy)
        call round_t
        ld e,a
        call tidx
        ld bc,imap
        add hl,bc
        ld a,(hl)
        or a
        jr z,.noit
        jp m,.noit
        cp IT_EXIT
        jr z,.noit
        ld (hl),0
        push af
        call draw_tile
        pop af
        call pickup
.noit:  ld ix,actors
        ld b,NACT
.a:     ld a,(ix+A_TYPE)
        or a
        jr z,.an
        ld a,(ix+A_STUN)
        or a
        jr nz,.an
        ld a,(bm_hx)
        sub (ix+A_HX)
        jr nc,$+4
        neg
        cp 6
        jr nc,.an
        ld a,(bm_hy)
        sub (ix+A_HY)
        jr nc,$+4
        neg
        cp 6
        jr nc,.an
        ld (ix+A_STUN),75
        ld a,SFX_STUN
        call play_sfx
        scf
        ret
.an:    ld de,ASZ
        add ix,de
        djnz .a
        or a
        ret

; ---------------------------------------------------------------------
; the wildlife
enemies_update:
        ld ix,actors
        ld b,NACT
.e:     push bc
        ld a,(ix+A_TYPE)
        or a
        jr z,.n
        inc (ix+A_ANIM)
        ld a,(ix+A_STUN)
        or a
        jr z,.go
        dec (ix+A_STUN)
        jr .n
.go:    ld a,(ix+A_TYPE)
        cp ET_TOAD
        jr nz,.nt
        call toad_think
        jr .n
.nt:    cp ET_FRILL
        jr nz,.ni
        call frill_think
        jr .n
.ni:    call ibis_think
.n:     ld de,ASZ
        add ix,de
        pop bc
        djnz .e
        ret

; IX = actor: the directions it can go from its tile -> A = mask (b0 R b1 L b2 U b3 D)
opts:
        ld a,(ix+A_HX)
        rrca
        rrca
        rrca
        and $1F
        ld (t_tx),a
        ld a,(ix+A_HY)
        rrca
        rrca
        rrca
        and $1F
        ld (t_ty),a
        ld c,0
        ld b,0
.d:     push bc
        ld a,b
        call dir_vec
        ld a,(t_tx)
        add a,d
        ld d,a
        ld a,(t_ty)
        add a,e
        ld e,a
        ld a,(ix+A_HX)
        ld c,a
        ld a,(ix+A_HY)
        ld b,a
        call can_enter
        pop bc
        jr nz,.no
        ld a,b
        inc a
        push bc
        ld b,a
        ld a,$80
.r:     rlca
        djnz .r
        pop bc
        or c
        ld c,a
.no:    inc b
        ld a,b
        cp 4
        jr nz,.d
        ld a,c
        ret

; A = option mask -> A = a random direction from it (mask not 0)
pick_dir:
        ld c,a
.p:     call random
        and 3
        ld b,a
        inc b
        ld a,$80
.r:     rlca
        djnz .r
        and c
        jr z,.p
        ld b,0
.n:     rrca
        ret c
        inc b
        jr .n
pick_r: ; (pick_dir result is in B)
        ret

; A = direction -> A = its mask bit
dir_bit:
        push bc
        ld b,a
        inc b
        ld a,$80
.r:     rlca
        djnz .r
        pop bc
        ret

; move IX one unit in its direction
move_on:
        ld a,(ix+A_DIR)
        call dir_vec
        ld a,(ix+A_HX)
        add a,d
        ld (ix+A_HX),a
        ld a,(ix+A_HY)
        add a,e
        ld (ix+A_HY),a
        ret
; IX lined up on a tile? -> Z
aligned:
        ld a,(ix+A_HX)
        or (ix+A_HY)
        and 7
        ret

; cane toad: hops a tile, rests, hops again
toad_think:
        ld a,(ix+A_PAUSE)
        or a
        jr z,.go
        dec (ix+A_PAUSE)
        ret
.go:    ld a,(ix+A_STEP)
        or a
        jr nz,.hop
        call opts
        or a
        jr nz,.has
        ld (ix+A_PAUSE),10
        ret
.has:   ld c,a
        ld a,(ix+A_DIR)
        call dir_bit
        and c
        jr z,.new
        call random
        cp 77
        jr nc,.keep
.new:   ld a,c
        call pick_dir
        ld (ix+A_DIR),b
.keep:  ld (ix+A_STEP),8
.hop:   call move_on
        dec (ix+A_STEP)
        ret nz
        call random
        and 7
        add a,7
        ld (ix+A_PAUSE),a
        ret

; frill-neck: ambles; sprints with its frill up when it sees Wally down a lane
frill_think:
        call aligned
        jr nz,.move
        call opts
        or a
        ret z
        ld c,a
        push bc
        call sight
        pop bc
        jr c,.nosee
        ld b,a
        call dir_bit
        and c
        jr z,.nosee
        ld a,(ix+A_CHARGE)
        or a
        jr nz,.ch
        ld a,SFX_SQUAWK
        call play_sfx
.ch:    ld (ix+A_DIR),b
        ld (ix+A_CHARGE),1
        jr .move
.nosee: ld (ix+A_CHARGE),0
        ld a,(ix+A_DIR)
        call dir_bit
        and c
        jr z,.new
        ld a,c                  ; a junction: sometimes turn
        call bits3
        jr c,.move
        call random
        cp 90
        jr nc,.move
.new:   ld a,c
        call pick_dir
        ld (ix+A_DIR),b
.move:  ld a,(ix+A_CHARGE)
        or a
        jr nz,.fast
        ld a,(gtick)
        and 1
        ret z
        jp move_on
.fast:  call move_on
        call aligned
        ret z
        jp move_on
; fewer than 3 options -> C
bits3:  ld b,0
.l:     srl a
        jr nc,.z
        inc b
.z:     or a
        jr nz,.l
        ld a,b
        cp 3
        ret

; IX: Wally down an open lane? -> NC and A = direction
sight:
        ld a,(p_hx)
        call round_t
        ld d,a
        ld a,(p_hy)
        call round_t
        ld e,a
        ld a,(ix+A_HX)
        rrca
        rrca
        rrca
        and $1F
        ld (t_tx),a
        ld a,(ix+A_HY)
        rrca
        rrca
        rrca
        and $1F
        ld (t_ty),a
        ld a,(t_tx)
        cp d
        jr nz,.row
        ld a,(t_ty)             ; same column
        cp e
        scf
        ret z
        ld c,DIR_D
        ld b,1
        jr c,.cl
        ld c,DIR_U
        ld b,$FF
.cl:    ld (t_best),a
        ld a,e
        ld (t_n),a
.cs:    ld a,(t_best)
        add a,b
        ld (t_best),a
        ld hl,t_n
        cp (hl)
        jr z,.yes
        push bc
        push de
        ld e,a
        ld a,(t_tx)
        ld d,a
        call walkable
        jr nz,.blk
        call bomb_at
.blk:   pop de
        pop bc
        jr z,.cs
        scf
        ret
.row:   ld a,(t_ty)
        cp e
        scf
        ret nz
        ld a,(t_tx)
        ld c,DIR_R
        ld b,1
        cp d
        jr c,.rl
        ld c,DIR_L
        ld b,$FF
.rl:    ld (t_best),a
        ld a,d
        ld (t_n),a
.rs:    ld a,(t_best)
        add a,b
        ld (t_best),a
        ld hl,t_n
        cp (hl)
        jr z,.yes
        push bc
        push de
        ld d,a
        ld a,(t_ty)
        ld e,a
        call walkable
        jr nz,.blk2
        call bomb_at
.blk2:  pop de
        pop bc
        jr z,.rs
        scf
        ret
.yes:   ld a,c
        or a
        ret

; bin chicken: goes for uncovered power-ups, steals them, runs from Wally
ibis_think:
        call aligned
        jp nz,move_on
        ; on a tile with a power-up? take it
        ld a,(ix+A_CARRY)
        or a
        jr nz,.has
        ld d,(ix+A_HX)
        srl d
        srl d
        srl d
        ld e,(ix+A_HY)
        srl e
        srl e
        srl e
        call tidx
        ld bc,imap
        add hl,bc
        ld a,(hl)
        or a
        jr z,.has
        jp m,.has
        cp IT_EXIT
        jr z,.has
        ld (ix+A_CARRY),a
        ld (hl),0
        call draw_tile
        ld a,SFX_STEAL
        call play_sfx
.has:   call opts
        or a
        ret z
        ld (t_k),a
        ; target: away from Wally when carrying, else the nearest power-up
        ld a,(ix+A_CARRY)
        or a
        jr z,.seek
        ld a,(p_hx)
        ld (t_tx),a
        ld a,(p_hy)
        ld (t_ty),a
        ld a,1                  ; maximise the distance
        jr .choose
.seek:  call nearest_item
        jr c,.wander
        xor a                   ; minimise
.choose:
        ld (t_n),a
        ld a,$FF
        ld (t_best),a
        ld a,(t_n)
        or a
        jr z,.cb
        xor a
        ld (t_best),a
.cb:    ld c,0
.cd:    ld a,c
        call dir_bit
        ld hl,t_k
        and (hl)
        jr z,.cn
        ld a,c
        call dir_vec
        ld a,d                  ; distance from (hx+8dx, hy+8dy) to the target
        add a,a
        add a,a
        add a,a
        add a,(ix+A_HX)
        ld hl,t_tx
        sub (hl)
        jr nc,$+4
        neg
        ld b,a
        ld a,e
        add a,a
        add a,a
        add a,a
        add a,(ix+A_HY)
        ld hl,t_ty
        sub (hl)
        jr nc,$+4
        neg
        add a,b
        jr nc,$+4
        ld a,$FE
        ld b,a
        ld a,(t_n)
        or a
        ld a,(t_best)
        jr nz,.max
        cp b
        jr c,.cn
        jr z,.cn
        jr .take
.max:   cp b
        jr nc,.cn
.take:  ld a,b
        ld (t_best),a
        ld (ix+A_DIR),c
.cn:    inc c
        ld a,c
        cp 4
        jr nz,.cd
        jp move_on
.wander: ld a,(ix+A_DIR)
        call dir_bit
        ld hl,t_k
        and (hl)
        jr z,.wn
        call random
        cp 80
        jp nc,move_on
.wn:    ld a,(t_k)
        call pick_dir
        ld (ix+A_DIR),b
        jp move_on

; the nearest uncovered power-up -> (t_tx, t_ty) in units; C = none
nearest_item:
        ld a,$FF
        ld (t_best),a
        ld e,1
.r:     ld d,1
.c:     call tidx
        ld bc,imap
        add hl,bc
        ld a,(hl)
        or a
        jr z,.n
        jp m,.n
        cp IT_EXIT
        jr z,.n
        ld a,d
        add a,a
        add a,a
        add a,a
        sub (ix+A_HX)
        jr nc,$+4
        neg
        ld b,a
        ld a,e
        add a,a
        add a,a
        add a,a
        sub (ix+A_HY)
        jr nc,$+4
        neg
        add a,b
        jr nc,$+4
        ld a,$FE
        ld hl,t_best
        cp (hl)
        jr nc,.n
        ld (hl),a
        ld a,d
        add a,a
        add a,a
        add a,a
        ld (t_tx),a
        ld a,e
        add a,a
        add a,a
        add a,a
        ld (t_ty),a
.n:     inc d
        ld a,d
        cp AW-1
        jr nz,.c
        inc e
        ld a,e
        cp AH-1
        jr nz,.r
        ld a,(t_best)
        cp $FF
        ccf
        ret nc
        scf
        ccf
        ret

; ---------------------------------------------------------------------
; flames and touches
damage:
        ; Wally in a flame?
        ld a,(p_hx)
        call round_t
        ld d,a
        ld a,(p_hy)
        call round_t
        ld e,a
        call tidx
        ld bc,fmap
        add hl,bc
        ld a,(hl)
        cp FL_HURT+1
        call nc,hurt
        ld ix,actors
        ld b,NACT
.a:     push bc
        ld a,(ix+A_TYPE)
        or a
        jp z,.n
        ld a,(ix+A_HX)
        call round_t
        ld d,a
        ld a,(ix+A_HY)
        call round_t
        ld e,a
        call tidx
        ld bc,fmap
        add hl,bc
        ld a,(hl)
        cp FL_HURT+1
        jr c,.alive
        ; beaten: a puff, points, anything it carried falls out
        ld a,(ix+A_CARRY)
        or a
        jr z,.nc
        push af
        call tidx
        ld bc,imap
        add hl,bc
        pop af
        ld (hl),a
        call draw_tile
.nc:    ld a,(ix+A_HX)
        add a,OX/2
        ld b,a
        ld a,(ix+A_HY)
        add a,OY/2
        ld c,a
        call spawn_puff
        ld a,(ix+A_TYPE)
        ld de,$0100
        cp ET_TOAD
        jr z,.sc
        ld de,$0200
        cp ET_FRILL
        jr z,.sc
        ld de,$0300
.sc:    call add_score
        ld (ix+A_TYPE),0
        ld a,SFX_ZAP
        call play_sfx
        ld hl,nenemy
        dec (hl)
        jr nz,.n
        ld a,1
        ld (allclear),a
        jr .n
.alive: ld a,(ix+A_STUN)
        or a
        jr nz,.n
        ld a,(p_hx)
        sub (ix+A_HX)
        jr nc,$+4
        neg
        cp 6
        jr nc,.n
        ld a,(p_hy)
        sub (ix+A_HY)
        jr nc,$+4
        neg
        cp 6
        jr nc,.n
        call hurt
.n:     ld de,ASZ
        add ix,de
        pop bc
        dec b
        jp nz,.a
        ret

; ---------------------------------------------------------------------
; drawing. Sprite position: spr_x = OX + 2*hx + dx, spr_y = OY + 2*hy + dy
; A = frame, C = ink, D = dx, E = dy (signed pixels), (t_tx, t_ty) = hx, hy
put_spr:
        push af
        ld a,c
        ld (spr_ink),a
        ld a,(t_tx)
        ld l,a
        ld h,0
        add hl,hl
        ld a,d
        ld c,a
        rla
        sbc a,a
        ld b,a
        add hl,bc
        ld bc,OX
        add hl,bc
        ld (spr_x),hl
        ld a,(t_ty)
        ld l,a
        ld h,0
        add hl,hl
        ld a,e
        ld c,a
        rla
        sbc a,a
        ld b,a
        add hl,bc
        ld bc,OY
        add hl,bc
        ld (spr_y),hl
        pop af
        jp spr_draw

draw_actors:
        call parts_draw
        ld ix,actors
        ld b,NACT
.a:     push bc
        ld a,(ix+A_TYPE)
        or a
        call nz,draw_enemy
        ld de,ASZ
        add ix,de
        pop bc
        djnz .a
        call draw_wally
        ld a,(bm_on)
        or a
        ret z
        ld a,(bm_hx)
        ld (t_tx),a
        ld a,(bm_hy)
        ld (t_ty),a
        ld a,(bm_f)
        and 3
        add a,SF_BOOM0
        ld de,0
        ld c,YELLOW
        call put_spr
        ld a,(bm_carry)         ; a bomb the boomerang carries, on top
        or a
        ret z
        ld de,$0202
        ld c,YELLOW
        ld a,SF_CBOMB_T
        call put_spr
        ld de,$0202
        ld c,BGREEN
        ld a,SF_CBOMB_B
        jp put_spr

draw_enemy:
        ld a,(ix+A_HX)
        ld (t_tx),a
        ld a,(ix+A_HY)
        ld (t_ty),a
        ; stunned: flashing white
        ld a,(ix+A_STUN)
        and 4
        ld (t_k),a
        ld a,(ix+A_TYPE)
        cp ET_TOAD
        jr nz,.nt
        ; toad: hop arc, squat before a hop
        ld e,0
        ld a,(ix+A_STEP)
        or a
        jr z,.sq
        ld hl,hoparc
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        ld a,SF_TOAD_T
        jr .tf
.sq:    ld a,(ix+A_PAUSE)
        or a
        ld a,SF_TOAD_T
        jr z,.tf
        ld a,(ix+A_PAUSE)
        cp 4
        ld a,SF_TOAD_T
        jr nc,.tf
        ld a,SF_TOADSQ_T
.tf:    ld d,0
        ld c,BROWN
        ld b,GREEN
        jr .two
.nt:    cp ET_FRILL
        jr nz,.ni
        ld a,(ix+A_ANIM)
        ld b,a
        ld a,(ix+A_CHARGE)
        or a
        jr z,.slow
        ld a,b
        rrca
        rrca
        and 1
        add a,a
        add a,SF_FRO0_T
        ld c,BMAGENTA
        jr .fr
.slow:  ld a,b
        rrca
        rrca
        rrca
        and 1
        add a,a
        add a,SF_FRS0_T
        ld c,BRED
.fr:    ld b,BGREEN
        ld de,0
        jr .two
.ni:    ld a,(ix+A_ANIM)        ; bin chicken
        rrca
        rrca
        rrca
        and 1
        add a,a
        ld b,a
        ld a,(ix+A_DIR)
        cp DIR_R
        ld a,SF_IBL0_T
        jr nz,.il
        ld a,SF_IBR0_T
.il:    add a,b
        ld c,DGREY
        ld b,WHITE
        push af
        ld a,(ix+A_CARRY)
        or a
        jr z,.ic
        ld hl,itemink-1
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld b,(hl)
.ic:    pop af
        ld de,0
.two:   ; A = top frame (bottom = A+1), C = top ink, B = bottom ink
        push af
        ld a,(t_k)
        or a
        jr z,.ns
        ld bc,WHITE*256+WHITE
.ns:    pop af
        push af
        push bc
        push de
        call put_spr
        pop de
        pop bc
        pop af
        inc a
        ld c,b
        jp put_spr
hoparc: db 0,-2,-4,-6,-6,-6,-4,-2,0
itemink: db YELLOW,BGREEN,BRED,BCYAN,YELLOW

; Wally: hat (yellow) over the body (grey), by his action
draw_wally:
        ld a,(p_inv)            ; flashing after a hit
        and 4
        jr z,.vis
        ld a,(p_act)
        cp ACT_HURT
        ret nz
.vis:   ld a,(p_hx)
        ld (t_tx),a
        ld a,(p_hy)
        ld (t_ty),a
        ld a,YELLOW
        ld (t_k),a              ; hat ink
        ld a,(p_act)
        cp ACT_PLACE
        jp z,.place
        cp ACT_STARTLE
        jp z,.startle
        cp ACT_COLLECT
        jp z,.collect
        cp ACT_HURT
        jp z,.hurt
        cp ACT_WIN
        jp z,.win
        cp ACT_DEAD
        jp z,.dead
        ld a,(p_safe)
        or a
        jr z,.ns
        ld a,(p_moving)
        or a
        jr nz,.ns
        ld a,SF_HAT_F           ; in a burrow: only his hat shows
        ld de,6
        ld c,YELLOW
        jp put_spr
.ns:    ld a,(p_moving)
        or a
        jr z,.idle
        ld a,(p_anim)
        rrca
        rrca
        and 3
        ld b,a
        ld a,(p_dir)
        cp DIR_R
        jr nz,.wl
        ld a,b
        and 1
        add a,SF_W_SIDE0
        ld c,SF_HAT_R
        jr .side
.wl:    cp DIR_L
        jr nz,.wv
        ld a,b
        and 1
        add a,SF_W_SIDEL0
        ld c,SF_HAT_L
        jr .side
.wv:    ld hl,walkfeet
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)               ; feet a b a c
        ld b,a
        ld a,(p_dir)
        cp DIR_U
        ld a,1                  ; back
        jr z,.wf
        xor a                   ; front
.wf:    ld c,b
        ld de,0
        jp .body
.side:  ld b,a                  ; B = body frame, C = hat frame
        push bc
        ld a,c
        ld de,0
        ld c,YELLOW
        call put_spr
        pop bc
        ld a,b
        ld de,0
        ld c,GREY
        jp put_spr
.idle:  ld a,(p_dir)
        cp DIR_R
        jr nz,.il
        ld bc,SF_W_SIDE0*256+SF_HAT_R
        ld a,b
        jr .side
.il:    cp DIR_L
        jr nz,.if
        ld bc,SF_W_SIDEL0*256+SF_HAT_L
        ld a,b
        jr .side
.if:    ; facing us: blink, look about, tap a foot
        ld a,(p_idle)
        ld b,a
        ld c,0                  ; feet a
        cp 60
        jr c,.nt
        and 8
        jr z,.nt
        ld c,1                  ; tap
.nt:    ld a,b
.m96:   cp 96
        jr c,.mm
        sub 96
        jr .m96
.mm:    ld b,0                  ; face norm
        cp 56
        jr c,.fc
        cp 60
        jr nc,.f2
        ld b,2                  ; blink
        jr .fc
.f2:    cp 68
        jr c,.fc
        cp 78
        jr nc,.f3
        ld b,3                  ; look left
        jr .fc
.f3:    cp 88
        jr nc,.fc
        ld b,4                  ; look right
.fc:    ld a,(p_dir)
        cp DIR_U
        jr nz,.fd
        ld b,1
.fd:    ld a,b
        ld de,0
        jp .body
.place: ld a,2                  ; blink, feet wide, crouched
        ld c,3
        ld de,$0002
        jp .bodyh
.startle:
        ld a,(p_actt)
        sub 4                   ; the hat jumps
        jr nc,$+3
        xor a
        neg
        ld e,a
        ld d,0
        push de
        ld a,SF_HAT_F
        ld c,YELLOW
        call put_spr
        pop de
        ld a,5                  ; wide eyes, feet up
        ld c,4
        ld e,0
        jp .bodyo
.collect:
        ld a,(p_actt)
        ld hl,hoparc
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        ld d,0
        ld a,7                  ; happy
        ld c,0
        jr .bodyh
.hurt:  ld a,WHITE
        ld (t_k),a
        ld a,(p_actt)
        and 2
        ld d,2
        jr z,.hs
        ld d,-2
.hs:    ld e,0
        ld a,6                  ; dizzy
        ld c,3
        jr .bodyh
.win:   ld a,(p_actt)
        ld b,a
        and 15
        ld hl,hoparc
        cp 9
        jr c,.wj
        xor a
.wj:    add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        ld d,0
        ld a,b
        and 16
        ld a,7
        ld c,3
        jr z,.bodyh
        ld c,0
        jr .bodyh
.dead:  ld a,(p_actt)
        cp 70
        jr c,.sq
        ld de,0                 ; dizzy spin first
        ld a,6
        ld c,0
        jr .bodyh
.sq:    cp 20
        ret c
        ld b,a                  ; the hat flies off, Wally flattened
        ld a,70
        sub b
        add a,a
        neg
        ld e,a
        ld d,0
        ld a,SF_HAT_F
        ld c,YELLOW
        call put_spr
        ld a,SF_W_SQUASH
        ld de,0
        ld c,GREY
        jp put_spr
; A = face (0 norm 1 back 2 blink 3 lookL 4 lookR 5 wide 6 dizzy 7 happy),
; C = feet (0 a 1 b 2 c 3 wide 4 up), D/E = offset of both parts
.bodyh: push af
        push bc
        push de
        ld a,(t_k)
        ld c,a
        ld a,SF_HAT_F
        call put_spr
        pop de
        pop bc
        pop af
        jr .bodyo
.body:  push af
        push bc
        push de
        ld c,YELLOW
        ld a,SF_HAT_F
        call put_spr
        pop de
        pop bc
        pop af
.bodyo: ld b,a
        add a,a
        add a,a
        add a,b                 ; face * 5
        add a,c
        add a,SF_W_norm_a
        ld c,GREY
        jp put_spr
walkfeet: db 0,1,0,2
