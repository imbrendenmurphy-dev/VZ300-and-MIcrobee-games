; =====================================================================
;  demo.asm - the autopilot that plays the attract demo: it picks the
;  nearest droid, walks the waypoint graph to it (BFS from the droid's
;  waypoint), then shoots it or links into it.
; =====================================================================

; input bits for directions 0-7 (E SE S SW W NW N NE)
dir_keys:   db K_RIGHT, K_RIGHT|K_DOWN, K_DOWN, K_LEFT|K_DOWN, K_LEFT, K_LEFT|K_UP, K_UP, K_RIGHT|K_UP

autopilot:
            xor a
            ld (ap_keys),a
            ld a,(plr+O_FLAGS)
            bit 7,a
            jp z,.out
            ; ---- target still alive?
            ld ix,(ap_tgt)
            ld a,(ap_have)
            or a
            jr z,.pick
            bit 7,(ix+O_FLAGS)
            jr nz,.have
.pick:      call ap_pick
            ld a,(ap_have)
            or a
            jp z,.out
            ld ix,(ap_tgt)
.have:      ; ---- distance to the target
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld de,(plr+O_XL)
            or a
            sbc hl,de
            ld (ap_dx),hl
            ld a,(ix+O_Y)
            ld hl,plr+O_Y
            sub (hl)
            ld (ap_dy),a
            ; close and in sight? engage
            ld hl,(ap_dx)
            call abs_hl
            ld a,h
            or a
            jr nz,.walk
            ld a,l
            cp 56
            jr nc,.walk
            ld a,(ap_dy)
            bit 7,a
            jr z,.p
            neg
.p:         cp 28
            jr nc,.walk
            call ap_clear           ; nothing solid in between?
            jr nz,.walk
            jp ap_engage
.walk:      xor a
            ; ---- follow the waypoints
            ld a,(ap_node)
            cp $FF
            call z,ap_nearest
            ld a,(ap_node)
            call wpt_ptr
            ld a,(hl)
            inc hl
            ld c,(hl)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            inc hl
            ld de,(plr+O_XL)
            or a
            sbc hl,de               ; dx to the node
            push hl
            ld a,c
            add a,a
            add a,c
            add a,a
            add a,2
            ld hl,plr+O_Y
            sub (hl)
            ld e,a                  ; dy
            pop hl
            ; arrived?
            push hl
            push de
            call abs_hl
            ld a,h
            or a
            jr nz,.go
            ld a,l
            cp 3
            jr nc,.go
            ld a,e
            bit 7,a
            jr z,.p2
            neg
.p2:        cp 3
            jr nc,.go
            pop de
            pop hl
            call ap_hop             ; next node towards the target
            jr .out
.go:        pop de
            pop hl
            call dir8
            ld e,a
            ld d,0
            ld hl,dir_keys
            add hl,de
            ld a,(hl)
            ld (ap_keys),a
            ; stuck? (no progress for a while) -> re-plan from the nearest node
            ld hl,(plr+O_XL)
            ld de,(ap_lastx)
            or a
            sbc hl,de
            jr nz,.mv
            ld a,(plr+O_Y)
            ld hl,ap_lasty
            cp (hl)
            jr nz,.mv
            ld hl,ap_stuck
            inc (hl)
            ld a,(hl)
            cp 40
            jr c,.out
            ld (hl),0
            ld a,$FF
            ld (ap_node),a
            jr .out
.mv:        xor a
            ld (ap_stuck),a
.out:       ld hl,(plr+O_XL)
            ld (ap_lastx),hl
            ld a,(plr+O_Y)
            ld (ap_lasty),a
            ld a,(ap_keys)
            ld (in_now),a
            ret

; close to the target: shoot it if we are the stronger, else link
ap_engage:
            ld a,(plr+O_TYPE)
            ld c,T_WEAPON
            call type_stat
            ld b,a
            ld a,(ix+O_TYPE)
            ld c,T_CLASS
            call type_stat
            ld c,a                  ; target class
            ld a,(plr+O_TYPE)
            push bc
            ld c,T_CLASS
            call type_stat
            pop bc
            ; link if unarmed, or the target outclasses us, or we are hurt
            ld d,a
            ld a,b
            or a
            jr z,.link
            ld a,c
            cp d
            jr nc,.link
            ; shoot: face it and fire (step back if very close)
            ld hl,(ap_dx)
            ld a,(ap_dy)
            ld e,a
            call dir8
            ld e,a
            ld d,0
            ld hl,dir_keys
            add hl,de
            ld a,(frames)
            and 1
            ld a,(hl)
            jr z,.f
            or K_FIRE
.f:         ld (ap_keys),a
            ld hl,(ap_dx)
            call abs_hl
            ld a,l
            cp 20
            jr nc,ap_done
            ld a,(ap_keys)          ; too close: back off while shooting
            and K_FIRE
            ld b,a
            ld a,e
            add a,4
            and 7
            ld e,a
            ld hl,dir_keys
            add hl,de
            ld a,(hl)
            or b
            ld (ap_keys),a
            jr ap_done
.link:      ld a,(p_tmode)
            or a
            jr nz,.ram
            ld a,K_FIRE             ; hold still with fire held
            ld (ap_keys),a
            jr ap_done
.ram:       ld hl,(ap_dx)
            ld a,(ap_dy)
            ld e,a
            call dir8
            ld e,a
            ld d,0
            ld hl,dir_keys
            add hl,de
            ld a,(hl)
            or K_FIRE
            ld (ap_keys),a
ap_done:    ld a,(ap_keys)
            ld (in_now),a
            ld hl,(plr+O_XL)
            ld (ap_lastx),hl
            ret

; is the line from the player to the target clear? Z if so
ap_clear:
            ld a,(ix+O_SEEN)        ; the droid's own sight test is good enough
            or a
            jr z,.mid
            xor a
            ret
.mid:
            ; not tracked: check the midpoint only
            ld hl,(ap_dx)
            sra h
            rr l
            ld de,(plr+O_XL)
            add hl,de
            ld de,6
            add hl,de
            ld b,h
            ld c,l
            ld a,(ap_dy)
            sra a
            ld hl,plr+O_Y
            add a,(hl)
            add a,4
            ld e,a
            call tile_at
            and A_SHOT
            jr nz,.no
            xor a
            ret
.no:        or 1
            ret

; pick the nearest live droid
ap_pick:
            xor a
            ld (ap_have),a
            ld hl,$7FFF
            ld (ap_best),hl
            ld ix,droids
            ld b,MAXDROIDS
.l:         push bc
            bit 7,(ix+O_FLAGS)
            jr z,.n
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld de,(plr+O_XL)
            or a
            sbc hl,de
            call abs_hl
            push hl
            ld a,(ix+O_Y)
            ld hl,plr+O_Y
            sub (hl)
            jr nc,.p
            neg
.p:         ld l,a
            ld h,0
            add hl,hl
            pop de
            add hl,de
            ld de,(ap_best)
            or a
            sbc hl,de
            jr nc,.n
            add hl,de
            ld (ap_best),hl
            ld (ap_tgt),ix
            ld a,1
            ld (ap_have),a
.n:         ld de,OSZ
            add ix,de
            pop bc
            djnz .l
            ld a,$FF
            ld (ap_node),a
            ret

; the waypoint nearest the player -> ap_node
ap_nearest:
            ld a,(dinfo+DI_NWPT)
            ld b,a
            ld c,0
            ld hl,$7FFF
            ld (ap_best),hl
.l:         push bc
            ld a,c
            call wpt_ptr
            ld a,(hl)
            inc hl
            ld e,(hl)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            push de
            ld de,(plr+O_XL)
            or a
            sbc hl,de
            call abs_hl
            pop de
            push hl
            ld a,e
            add a,a
            add a,e
            add a,a
            ld hl,plr+O_Y
            sub (hl)
            jr nc,.p
            neg
.p:         ld l,a
            ld h,0
            add hl,hl
            pop de
            add hl,de
            ld de,(ap_best)
            or a
            sbc hl,de
            pop bc
            jr nc,.n
            add hl,de
            ld (ap_best),hl
            ld a,c
            ld (ap_node),a
.n:         inc c
            djnz .l
            ret

; at ap_node: BFS from the target droid's waypoint, step to the
; neighbour that is closer to it
ap_hop:
            ld ix,(ap_tgt)
            ld a,(ix+O_TGT)
            call bfs
            ld a,(ap_node)
            call wpt_ptr
            inc hl
            inc hl
            ld b,(hl)               ; degree
            inc hl
            ld a,(ap_node)
            ld e,a
            ld d,0
            push hl
            ld hl,bfs_d
            add hl,de
            ld c,(hl)               ; our distance
            pop hl
            ld a,(ap_node)
            ld (ap_next),a
.l:         ld a,(hl)
            push hl
            ld e,a
            ld d,0
            ld hl,bfs_d
            add hl,de
            ld a,(hl)
            pop hl
            cp c
            jr nc,.w
            ld c,a
            ld a,(hl)
            ld (ap_next),a
.w:         inc hl
            djnz .l
            ld a,(ap_next)
            ld (ap_node),a
            ret

; bfs: A = start node -> bfs_d[] = hops from it ($FF unreached)
bfs:
            ld (bf_start),a
            ld hl,bfs_d
            ld b,MAXWPT
.c:         ld (hl),$FF
            inc hl
            djnz .c
            ld a,(bf_start)
            ld e,a
            ld d,0
            ld hl,bfs_d
            add hl,de
            ld (hl),0
            ld hl,bfs_q
            ld (hl),a
            ld (bf_head),hl
            inc hl
            ld (bf_tail),hl
.q:         ld hl,(bf_head)
            ld de,(bf_tail)
            or a
            sbc hl,de
            ret z
            add hl,de
            ld a,(hl)
            inc hl
            ld (bf_head),hl
            ld (bf_cur),a
            ld e,a
            ld d,0
            ld hl,bfs_d
            add hl,de
            ld a,(hl)
            inc a
            ld (bf_nd),a
            ld a,(bf_cur)
            call wpt_ptr
            inc hl
            inc hl
            ld b,(hl)
            inc hl
.n:         ld a,(hl)
            push hl
            ld e,a
            ld d,0
            ld hl,bfs_d
            add hl,de
            ld a,(hl)
            cp $FF
            jr nz,.seen
            ld a,(bf_nd)
            ld (hl),a
            ld hl,(bf_tail)
            ld (hl),e
            inc hl
            ld (bf_tail),hl
.seen:      pop hl
            inc hl
            djnz .n
            jr .q
