; ---------------------------------------------------------------------------
; Playfield rendering: terrain window, water, hatch, burrow, bilbies, sparks,
; cursor -> BACK -> screen
; ---------------------------------------------------------------------------
render_play:
        ld a,(v_scrb)
        ld (v_lastscr),a
        ld a,(v_scry)
        ld (v_lastsy),a
        call comp_terrain
        call draw_water
        call draw_objects
        call draw_creatures
        call draw_parts
render_light:
        call cursor_put
        call blit_back
        jp cursor_remove

; save the BACK bytes the cursor covers (3 bytes x 7 rows), then draw it
cursor_put:
        xor a
        ld (v_csaved),a
        ld a,(v_cy)
        cp PFH
        ret nc
        ld a,(v_cx)
        sub 3
        add a,8
        rrca
        rrca
        and $3F
        ld (v_ccol),a
        ld a,(v_cy)
        sub 3
        ld (v_crow),a
        ld c,a
        ld de,CURSAVE
        ld b,7
.r:     ld a,c
        cp PFH
        jr nc,.n
        push bc
        call .addr
        ldi
        ldi
        ldi
        pop bc
        jr .nx
.n:     inc de
        inc de
        inc de
.nx:    inc c
        djnz .r
        ld a,1
        ld (v_csaved),a
        jp draw_cursor
; HL = BACK byte for row C at v_ccol
.addr:  ld a,c
        add a,a
        ld l,a
        ld h,BROW>>8
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,(v_ccol)
        add a,l
        ld l,a
        ret nc
        inc h
        ret
cursor_remove:
        ld a,(v_csaved)
        or a
        ret z
        ld a,(v_crow)
        ld c,a
        ld hl,CURSAVE
        ld b,7
.r:     ld a,c
        cp PFH
        jr nc,.n
        push bc
        push hl
        call cursor_put.addr
        ex de,hl
        pop hl
        ldi
        ldi
        ldi
        pop bc
        jr .nx
.n:     inc hl
        inc hl
        inc hl
.nx:    inc c
        djnz .r
        ret

; scroll in pixels -> HL (and v_spx)
scroll_px:
        ld a,(v_scrb)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld (v_spx),hl
        ret

; level x DE -> viewport x A, carry set if well off the window (-8..131 kept)
view_x:
        ld hl,(v_spx)
        ex de,hl
        or a
        sbc hl,de               ; x - scroll
        ex de,hl
        ld hl,8
        add hl,de               ; +8
        ld a,h
        or a
        jr nz,.off
        ld a,l
        cp 140
        jr nc,.off
        sub 8
        or a
        ret
.off:   scf
        ret

; ---- water: rows wy..lh-1 between wx0 and wx1 (multiples of 4) -----------------
draw_water:
        ld a,(v_wy)
        or a
        ret z
        ; visible bytes: wx0/4 - scrb .. wx1/4 - scrb, clipped to 0..32
        ld hl,(v_wx0)
        srl h
        rr l
        srl h
        rr l
        ld a,(v_scrb)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        jr nc,.a0
        ld hl,0
.a0:    ld a,h
        or a
        ret nz
        ld a,l
        cp 32
        ret nc
        ld b,a                  ; first byte
        ld hl,(v_wx1)
        srl h
        rr l
        srl h
        rr l
        or a
        sbc hl,de
        ret c
        ret z
        ld a,h
        or a
        jr nz,.a2
        ld a,l
        cp 33
        jr c,.a3
.a2:    ld a,32
.a3:    sub b
        ret c
        ret z
        ld (v_wcnt),a
        ld a,(v_gtick)
        rra
        and 3
        ld (v_wph),a
        ; rows: level rows wy.. -> screen rows wy - scry ..
        ld a,(v_wy)
        ld c,a
.r:     ld a,(v_lh)
        cp c
        ret z
        ret c
        ld a,(v_scry)
        ld e,a
        ld a,c
        sub e
        jr c,.n                 ; above the window
        cp PFH
        ret nc
        push bc
        add a,a
        ld l,a
        ld h,BROW>>8
        ld e,(hl)
        inc l
        ld d,(hl)
        ld a,b
        add a,2
        add a,e
        ld e,a
        adc a,d
        sub e
        ld d,a
        ld a,(v_wy)
        ld b,a
        ld a,c
        sub b
        cp 4
        jr c,.p
        ld a,3
.p:     add a,a
        add a,a
        ld l,a
        ld a,(v_wph)
        add a,l
        ld l,a
        ld h,0
        ld bc,WATERP
        add hl,bc
        ld a,(hl)
        ld h,a
        ld a,(v_wcnt)
        ld b,a
        ex de,hl
.w:     ld (hl),d
        ld a,d
        rlca
        rlca
        ld d,a
        inc hl
        djnz .w
        pop bc
.n:     inc c
        jr .r

; ---- the hatch and the burrow -------------------------------------------------
; a 3-byte-wide object: HL = frame, DE = level x (multiple of 4), C = top row
; (level), B = rows
draw_obj:
        push hl
        ex de,hl
        srl h
        rr l
        srl h
        rr l
        ld a,(v_scrb)
        ld e,a
        ld d,0
        or a
        sbc hl,de               ; viewport byte
        ld de,2
        add hl,de               ; with the margin
        ld a,h
        or a
        jr nz,.off
        ld a,l
        cp 34
        jr nc,.off
        ld (ds_col),a
        pop hl
        ld a,(v_scry)
        ld e,a
        ld a,c
        sub e
        ld c,a                  ; screen row (may be negative)
.r:     ld a,c
        cp PFH
        jr nc,.n
        push bc
        push hl
        add a,a
        ld l,a
        ld h,BROW>>8
        ld e,(hl)
        inc l
        ld d,(hl)
        ld a,(ds_col)
        add a,e
        ld e,a
        adc a,d
        sub e
        ld d,a
        pop hl
        push hl
        ld b,3
.c:     ld a,(hl)
        push hl
        ld h,OPQ>>8
        ld l,a
        ld l,(hl)
        ex de,hl
        xor (hl)
        and e
        xor (hl)
        ld (hl),a
        ex de,hl
        pop hl
        inc hl
        inc de
        djnz .c
        pop hl
        pop bc
.n:     inc hl
        inc hl
        inc hl
        inc c
        djnz .r
        ret
.off:   pop hl
        ret

draw_objects:
        ld a,(v_hatch)
        srl a
        cp 8
        jr c,.h
        ld a,7
.h:     ld l,a
        ld h,0
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de               ; x18
        ld de,HATCHF
        add hl,de
        ld a,(v_hy)
        ld c,a
        ld de,(v_hx)
        ld b,6
        call draw_obj
        ld a,(v_gtick)
        rrca
        rrca
        and 3
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,de               ; x24
        ld de,EXITF
        add hl,de
        ld a,(v_ey)
        sub 7
        ld c,a
        push hl
        ld hl,(v_ex)
        ld de,-6
        add hl,de
        ex de,hl
        pop hl
        ld b,8
        jp draw_obj

; ---- the bilbies ---------------------------------------------------------------
draw_creatures:
        call scroll_px
        ld ix,CRT
        ld b,NCRT
.l:     push bc
        ld a,(ix+C_ST)
        or a
        jr z,.n
        cp ST_GONE
        jr nc,.n
        call draw_one
        call int_poll
.n:     ld de,CSZ
        add ix,de
        pop bc
        djnz .l
        ret

; frame address for IX -> HL
frame_of:
        ld a,(ix+C_ST)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld e,a
        ld d,0
        add hl,de
        add hl,de               ; x6
        ld de,ANIMT+2
        add hl,de
        bit 0,(ix+C_DIR)
        jr z,.r
        inc hl
        inc hl
.r:     ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(ix+C_AN)
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        ld c,l
        ld b,h
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,bc               ; x14
        add hl,de
        ret

draw_one:
        ; vertical: screen top row = y - scry - 6, keep -7..43
        ld a,(v_scry)
        ld c,a
        ld a,(ix+C_Y)
        sub c
        jr c,.vt                ; above the window: maybe partly visible
        cp PFH+6
        ret nc
        jr .vok
.vt:    cp -1
        ret nz
.vok:   sub 6
        ld (v_sy),a
        ld e,(ix+C_XL)
        ld d,(ix+C_XH)
        call view_x
        ret c
        sub 3
        ld (v_sx),a
        call frame_of
        ld a,(v_sx)
        ld b,a
        ld a,(v_sy)
        ld c,a
        call draw_spr
        bit 2,(ix+C_FL)
        ret z
        ld a,(ix+C_BT)
        ld c,0
.d:     inc c
        sub 13
        jr nc,.d
        ld a,c
        cp 6
        jr c,.dc
        ld a,5
.dc:    ld l,a
        ld h,0
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de               ; x14
        ld de,DIGSPR
        add hl,de
        ld a,(v_sx)
        ld b,a
        ld a,(v_sy)
        sub 5
        ld c,a
        jp draw_spr

; ---- sparks ----------------------------------------------------------------------
draw_parts:
        call scroll_px
        ld ix,PART
        ld b,NPART
.l:     push bc
        ld a,(ix+5)
        or a
        jr z,.n
        ld l,(ix+0)
        ld h,(ix+1)
        srl h
        rr l
        ex de,hl
        call view_x
        jr c,.n
        cp 128
        jr nc,.n
        ld b,a
        ld a,(ix+2)
        srl a
        ld c,a
        ld a,(v_scry)
        ld e,a
        ld a,c
        sub e
        jr c,.n
        ld c,a
        ld a,(ix+6)
        call plot_back
.n:     ld de,PSZ
        add ix,de
        pop bc
        djnz .l
        ret

; ---- cursor ------------------------------------------------------------------------
draw_cursor:
        ld a,(v_cy)
        cp PFH
        ret nc
        ld a,(v_hcount)
        or a
        ld hl,CURS0
        jr z,.c
        ld hl,CURS1
.c:     ld a,(v_cx)
        sub 3
        ld b,a
        ld a,(v_cy)
        sub 3
        ld c,a
        jp draw_spr
