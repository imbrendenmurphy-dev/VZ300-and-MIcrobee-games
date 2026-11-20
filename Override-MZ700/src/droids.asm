; =====================================================================
;  droids.asm - hostile droids, shots, explosions, damage
; =====================================================================

; ---------------------------------------------------------------------
; droids_update: every enemy thinks, moves and maybe shoots
; ---------------------------------------------------------------------
droids_update:
        ld ix,DROIDS+DSZ
        ld b,NDROIDS-1
.l:     push bc
        ld a,(ix+D_TYPE)
        cp 0FFh
        call nz,droid_tick
        ld bc,DSZ
        add ix,bc
        pop bc
        djnz .l
        ret

droid_tick:
        inc (ix+D_ANIM)
        ld a,(ix+D_FLASH)
        or a
        jr z,$+5
        dec (ix+D_FLASH)
        ld a,(ix+D_RELD)
        or a
        jr z,$+5
        dec (ix+D_RELD)
        ; movement: speed/16 cells a frame
        ld a,(ix+D_TYPE)
        call roster_ptr
        push hl
        pop iy                      ; IY = roster entry
        ld a,(ix+D_ACC)
        add a,(iy+R_SPD)
        ld (ix+D_ACC),a
        cp 16
        jr c,.nomove
        sub 16
        ld (ix+D_ACC),a
        call droid_step
        ld a,(ix+D_TYPE)
        cp 0FFh
        ret z
        call roster_ptr
        push hl
        pop iy
.nomove:
        ld a,(pl_dead)
        or a
        ret nz
        ld a,(ix+D_RELD)
        or a
        ret nz
        ld a,(iy+R_WPN)
        or a
        ret z
        jp droid_shoot

; one step along the waypoint graph
droid_step:
        ld a,(ix+D_WAIT)
        or a
        jr z,.go
        dec (ix+D_WAIT)
        ret
.go:    ld a,(ix+D_NODE)
        call node_xy                ; B,C = node position
        ld a,b
        cp (ix+D_X)
        jr nz,.walk
        ld a,c
        cp (ix+D_Y)
        jr nz,.walk
        jp droid_pick               ; arrived: choose the next waypoint
.walk:  ; dx, dy = sign of the difference
        ld a,b
        sub (ix+D_X)
        call sign
        ld d,a
        ld a,c
        sub (ix+D_Y)
        call sign
        ld e,a
        ld (ix+D_DX),d
        ld (ix+D_DY),e
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
        jr nz,.turn
        call droid_blocker          ; any droid in the way? (carry = yes, IY = it)
        jr c,.blocked
        ld (ix+D_X),b
        ld (ix+D_Y),c
        ret
.blocked:
        ; ran into the player?
        call rand
        and 15
        add a,6
        ld (ix+D_WAIT),a
        call rand
        and 1
        ret z
.turn:  ld a,(ix+D_NODE)            ; go back where we came from
        ld b,(ix+D_PREV)
        ld (ix+D_NODE),b
        ld (ix+D_PREV),a
        ret

; at a waypoint: pick a neighbour (aggressive droids close in on the player)
droid_pick:
        ld a,(ix+D_NODE)
        call adj_ptr                ; HL = adjacency slot
        ld a,(hl)
        inc hl
        ld b,a                      ; neighbour count
        cp 1
        jr z,.only
        ; hunters: aggression 3 and the player within reach
        ld a,(iy+R_AGG)
        cp 3
        jr c,.random
        ld a,(pl_dead)
        or a
        jr nz,.random
        call player_dist            ; A = rough distance
        cp 30
        jr nc,.random
        call rand
        cp 200
        jr nc,.random
        ; choose the neighbour nearest the player
        ld c,0FFh                   ; best distance
        ld d,0                      ; best node
.nb:    push bc
        ld a,(hl)
        push hl
        push de
        call node_xy
        call dist_to_player         ; A = distance from (B,C)
        pop de
        pop hl
        pop bc
        cp c
        jr nc,.nw
        ld c,a
        ld d,(hl)
.nw:    inc hl
        djnz .nb
        ld a,d
        jr .set
.random:
        call rand_below             ; A = 0..B-1
        ld e,a
        ld d,0
        push hl
        add hl,de
        ld a,(hl)
        pop hl
        cp (ix+D_PREV)              ; don't double back if there is a choice
        jr nz,.set
        ld a,e
        inc a
        cp b
        jr c,.w
        xor a
.w:     ld e,a
        add hl,de
        ld a,(hl)
        jr .set
.only:  ld a,(hl)
.set:   ld b,(ix+D_NODE)
        ld (ix+D_PREV),b
        ld (ix+D_NODE),a
        ret

; A = signed value -> A = -1 / 0 / 1
sign:
        or a
        ret z
        ld a,1
        ret p
        ld a,0FFh
        ret

; A = node -> B = x, C = y
node_xy:
        push hl
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,NODES
        add hl,de
        pop de
        ld b,(hl)
        inc hl
        ld c,(hl)
        pop hl
        ret

; A = node -> HL = its 8-byte adjacency slot
adj_ptr:
        push de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,ADJ
        add hl,de
        pop de
        ret

; distance (max of |dx|, |dy|*2, capped 255) from the droid IX to the player
player_dist:
        ld b,(ix+D_X)
        ld c,(ix+D_Y)
dist_to_player:
        ld a,(DROIDS+D_X)
        sub b
        jr nc,$+4
        neg
        ld e,a
        ld a,(DROIDS+D_Y)
        sub c
        jr nc,$+4
        neg
        add a,a
        jr c,.big
        cp e
        ret nc
        ld a,e
        ret
.big:   ld a,0FFh
        ret

; is a droid other than IX overlapping footprint (B,C)?  carry = yes, IY = it
droid_blocker:
        push bc
        push de
        push hl
        ld iy,DROIDS
        ld a,NDROIDS
        ld (db_cnt),a
.l:     ld a,(iy+D_TYPE)
        cp 0FFh
        jr z,.n
        push iy
        pop hl
        push ix
        pop de
        or a
        sbc hl,de
        jr z,.n                     ; that's us
        ; the player while dead doesn't block
        push iy
        pop hl
        ld a,h
        cp high DROIDS
        jr nz,.chk
        ld a,l
        cp low DROIDS
        jr nz,.chk
        ld a,(pl_dead)
        or a
        jr nz,.n
.chk:   ld a,(iy+D_X)               ; |x - ox| < 3
        sub b
        add a,2
        cp 5
        jr nc,.n
        ld a,(iy+D_Y)               ; |y - oy| < 2
        sub c
        inc a
        cp 3
        jr nc,.n
        pop hl
        pop de
        pop bc
        scf
        ret
.n:     ld de,DSZ
        add iy,de
        ld hl,db_cnt
        dec (hl)
        jr nz,.l
        pop hl
        pop de
        pop bc
        or a
        ret

; ---------------------------------------------------------------------
; enemy shooting: aligned with the player (row, column or diagonal),
; in range, with a clear line
; ---------------------------------------------------------------------
droid_shoot:
        ld a,(invuln)               ; nobody fires while we arrive
        or a
        ret nz
        ; chance per frame by aggression
        ld a,(iy+R_AGG)
        or a
        ret z
        ld e,a
        ld d,0
        call rand
        ld c,a
        ld hl,shoot_chance-1
        add hl,de
        ld a,c
        cp (hl)
        ret nc
        ld a,(DROIDS+D_X)
        sub (ix+D_X)
        ld d,a                      ; ddx
        ld a,(DROIDS+D_Y)
        sub (ix+D_Y)
        ld e,a                      ; ddy
        ; range check
        ld a,d
        call abs_a
        cp (iy+R_RANGE)
        ret nc
        ld a,e
        call abs_a
        cp 12
        ret nc
        ; horizontal?
        ld a,e
        inc a
        cp 3
        jr nc,.nothor
        ld a,d
        call sign
        ld b,a                      ; sdx
        ld c,0
        ld a,e                      ; row: ddy=1 -> y+1, else y
        cp 1
        ld a,(ix+D_Y)
        jr nz,$+3
        inc a
        ld l,a                      ; start y
        ld a,b
        cp 1
        ld a,(ix+D_X)
        jr nz,.hl
        add a,4
.hl:    dec a                       ; right: x+3, left: x-1
        ld h,a
        ld a,0                      ; kind -
        jr .fire
.nothor:
        ld a,d
        inc a
        cp 3
        jr nc,.notver
        ld b,0
        ld a,e
        call sign
        ld c,a
        ld a,(ix+D_X)
        inc a
        ld h,a
        ld a,c
        cp 1
        ld a,(ix+D_Y)
        jr nz,.vu
        add a,3
.vu:    dec a                       ; down: y+2, up: y-1
        ld l,a
        ld a,1
        jr .fire
.notver:
        ; diagonal: | |ddx| - |ddy| | <= 1
        ld a,d
        call abs_a
        ld c,a
        ld a,e
        call abs_a
        sub c
        inc a
        cp 3
        ret nc
        ld a,d
        call sign
        ld b,a
        ld a,e
        call sign
        ld c,a
        ; start at the corner the shot leaves from
        ld a,b
        cp 1
        ld a,(ix+D_X)
        jr nz,.dl
        add a,4
.dl:    dec a
        ld h,a
        ld a,c
        cp 1
        ld a,(ix+D_Y)
        jr nz,.du
        add a,3
.du:    dec a
        ld l,a
        ; kind: '/' when dx and dy differ in sign
        ld a,b
        xor c
        rla
        ld a,2
        jr c,.fire
        inc a
.fire:  ; H,L = start, B,C = direction, A = kind
        ld (shot_kind),a
        ld (shot_dir),bc
        ld (shot_pos),hl
        ; line of sight up to the player
        ld a,(iy+R_RANGE)
        call los_clear
        ret nc
        ld a,1
        ld (shot_own),a
        ld a,(iy+R_DMG)
        ld (shot_dmg),a
        ld a,(iy+R_RANGE)
        add a,4
        ld (shot_life),a
        call shot_spawn
        ld a,(iy+R_RELOAD)
        ld (ix+D_RELD),a
        ; enemy zap sound if on screen
        ld b,(ix+D_X)
        ld c,(ix+D_Y)
        call in_view
        ret c
        ld hl,SFX_EZAP
        ld a,2
        jp sfx

shoot_chance:
        db 5,12,24

abs_a:
        or a
        ret p
        neg
        ret

; line from shot_pos in shot_dir for A cells: carry set if nothing solid
; before reaching the player's footprint
los_clear:
        ld e,a
        ld hl,(shot_pos)
        ld bc,(shot_dir)
.l:     push bc
        push hl
        ld b,h
        ld c,l
        call cell_flags
        and F_SHOT
        jr nz,.no
        ; reached the player?
        ld a,(DROIDS+D_X)
        ld d,a
        ld a,b
        sub d
        cp 3
        jr nc,.go
        ld a,(DROIDS+D_Y)
        ld d,a
        ld a,c
        sub d
        cp 2
        jr nc,.go
        pop hl
        pop bc
        scf
        ret
.go:    pop hl
        pop bc
        ld a,h
        add a,b
        ld h,a
        ld a,l
        add a,c
        ld l,a
        dec e
        jr nz,.l
        or a
        ret
.no:    pop hl
        pop bc
        or a
        ret

; spawn a shot from shot_* variables
shot_spawn:
        push ix
        ld ix,SHOTS
        ld b,NSHOTS
.f:     ld a,(ix+S_LIFE)
        or a
        jr z,.free
        ld de,SHOTSZ
        add ix,de
        djnz .f
        pop ix
        ret
.free:  ld a,(shot_life)
        ld (ix+S_LIFE),a
        ld hl,(shot_pos)
        ld (ix+S_X),h
        ld (ix+S_Y),l
        ld bc,(shot_dir)
        ld (ix+S_DX),b
        ld (ix+S_DY),c
        ld a,(shot_own)
        ld (ix+S_OWN),a
        ld a,(shot_dmg)
        ld (ix+S_DMG),a
        ld a,(shot_kind)
        ld (ix+S_KIND),a
        ; already inside a wall?
        ld b,h
        ld c,l
        call cell_flags
        and F_SHOT
        jr z,.ok
        ld (ix+S_LIFE),0
.ok:    pop ix
        ret

; ---------------------------------------------------------------------
; shots
; ---------------------------------------------------------------------
shots_update:
        ld ix,SHOTS
        ld b,NSHOTS
.l:     push bc
        ld a,(ix+S_LIFE)
        or a
        call nz,shot_tick
        ld bc,SHOTSZ
        add ix,bc
        pop bc
        djnz .l
        ret

shot_tick:
        ; a shot hits what is in its cell, then moves on
        call shot_hit
        ret c
        ld a,(ix+S_OWN)             ; enemy shots move every other frame
        or a
        jr z,.mv
        ld a,(frame)
        and 1
        ret nz
.mv:
        dec (ix+S_LIFE)
        ret z
        ld a,(ix+S_X)
        add a,(ix+S_DX)
        ld (ix+S_X),a
        ld b,a
        ld a,(ix+S_Y)
        add a,(ix+S_DY)
        ld (ix+S_Y),a
        ld c,a
        call cell_flags
        and F_SHOT
        jr z,.free
        ld (ix+S_LIFE),0            ; hit a wall: a spark
        dec b                       ; centre the 3x2 spark on the cell
        ld a,(ix+S_DY)
        or a
        jr z,.sp
        dec c
.sp:    ld a,4                      ; small spark (late frames only)
        call expl_spawn_small
        ret
.free:  jp shot_hit

; carry = the shot hit a droid (and is gone)
shot_hit:
        ld b,(ix+S_X)
        ld c,(ix+S_Y)
        ld a,(ix+S_OWN)
        or a
        jr nz,.enemy
        ; player's shot: any enemy
        ld iy,DROIDS+DSZ
        ld e,NDROIDS-1
.l:     ld a,(iy+D_TYPE)
        cp 0FFh
        jr z,.n
        call in_fp
        jr nc,.n
        ld a,(ix+S_DMG)
        ld (ix+S_LIFE),0
        push ix
        push iy
        pop ix
        call damage_enemy
        pop ix
        scf
        ret
.n:     push de
        ld de,DSZ
        add iy,de
        pop de
        dec e
        jr nz,.l
        or a
        ret
.enemy: ld a,(pl_dead)
        or a
        ret nz
        ld iy,DROIDS
        call in_fp
        ret nc
        ld a,(ix+S_DMG)
        ld (ix+S_LIFE),0
        call damage_player
        scf
        ret

; is cell (B,C) inside the footprint of droid IY? carry = yes
in_fp:
        ld a,b
        sub (iy+D_X)
        cp 3
        ret nc
        ld a,c
        sub (iy+D_Y)
        cp 2
        ret

; ---------------------------------------------------------------------
; damage
; ---------------------------------------------------------------------
; IX = enemy, A = damage
damage_enemy:
        ld (ix+D_FLASH),3
        ld c,a
        ld a,(ix+D_EN)
        sub c
        jr c,enemy_destroyed
        jr z,enemy_destroyed
        ld (ix+D_EN),a
        ld hl,SFX_HIT
        ld a,2
        jp sfx

enemy_destroyed:
        ld (ix+D_EN),0
        ld b,(ix+D_X)
        ld c,(ix+D_Y)
        call expl_spawn
        ld a,(ix+D_TYPE)
        ld (ix+D_TYPE),0FFh
        call roster_ptr
        ld bc,R_SCORE
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        call add_score
        ld hl,SFX_BOOM
        ld a,4
        call sfx
        ld a,1
        ld (check_clear),a
        ret

; A = damage to the player's host
damage_player:
        ld c,a
        ld a,(invuln)
        or a
        ret nz
        ld a,c
        ld (DROIDS+D_FLASH),a       ; flash a little longer for big hits
        ld a,(DROIDS+D_EN)
        sub c
        jr c,.dead
        jr z,.dead
        ld (DROIDS+D_EN),a
        ld a,1
        ld (hud_dirty),a
        ld hl,SFX_PHIT
        ld a,3
        jp sfx
.dead:  xor a
        ld (DROIDS+D_EN),a
        jp host_destroyed

; ---------------------------------------------------------------------
; explosions
; ---------------------------------------------------------------------
; B,C = top-left of a 3x2 blast
expl_spawn:
        xor a
expl_spawn_small:
        push ix
        ld e,a
        ld ix,EXPLS
        ld d,NEXPL
.f:     ld a,(ix+E_T)
        or a
        jr z,.free
        push de
        ld de,EXPLSZ
        add ix,de
        pop de
        dec d
        jr nz,.f
        pop ix
        ret
.free:  ld (ix+E_X),b
        ld (ix+E_Y),c
        ld (ix+E_F),e
        ld a,NEXPLF*2
        sub e
        sub e
        ld (ix+E_T),a
        ld a,e
        or a
        ld a,1
        jr z,$+3
        xor a
        ld (ix+E_HURT),a
        pop ix
        ret

expl_update:
        ld ix,EXPLS
        ld b,NEXPL
.l:     push bc
        ld a,(ix+E_T)
        or a
        jr z,.n
        dec (ix+E_T)
        ld a,(ix+E_T)
        and 1
        jr nz,.nf
        ld a,(ix+E_F)
        inc a
        cp NEXPLF
        jr c,$+3
        dec a
        ld (ix+E_F),a
.nf:    ld a,(ix+E_HURT)
        or a
        call nz,expl_hurt
.n:     ld bc,EXPLSZ
        add ix,bc
        pop bc
        djnz .l
        ret

; blast damage to droids touching the explosion (once)
expl_hurt:
        ld (ix+E_HURT),0
        ld iy,DROIDS
        ld b,NDROIDS
.l:     push bc
        ld a,(iy+D_TYPE)
        cp 0FFh
        jr z,.n
        ; |dx| <= 3 and |dy| <= 2
        ld a,(iy+D_X)
        sub (ix+E_X)
        add a,3
        cp 7
        jr nc,.n
        ld a,(iy+D_Y)
        sub (ix+E_Y)
        add a,2
        cp 5
        jr nc,.n
        push iy
        pop hl
        ld de,DROIDS
        or a
        sbc hl,de
        jr nz,.en
        ld a,(pl_dead)
        or a
        jr nz,.n
        ld a,4
        push ix
        call damage_player
        pop ix
        jr .n
.en:    ld a,(iy+D_EN)              ; chain reaction
        push ix
        push iy
        pop ix
        ld a,6
        call damage_enemy
        pop ix
.n:     ld bc,DSZ
        add iy,bc
        pop bc
        djnz .l
        ret
