; ---------------------------------------------------------------------------
; Generic 24-pixel-wide sprite: d_src (rows of mask x3, pixels x3), d_x (half-
; pixels), d_y, d_h rows, d_face (1 = mirror), d_ink.  Drawn into NATIVE over
; a 4-column rectangle d_rcx, d_rcy0..d_rcy1 (from spr_rect).
; ---------------------------------------------------------------------------
spr_rect:
        ld a,(d_x)
        srl a
        srl a
        ld (d_rcx),a
        ld a,(d_y)
        ld l,a
        ld h,0
        ld de,ycell
        add hl,de
        ld a,(hl)
        ld (d_rcy0),a
        ld a,(d_h)
        dec a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        ld (d_rcy1),a
        ret

; Restore the 4-column rectangle A = column, B = first row, C = last row.
erase_rect:
        ld (er_c),a
        ld a,c
        ld (er_r1),a
        ld c,b
.r:     ld a,(er_r1)
        cp c
        ret c
        ld a,(er_c)
        call cell_addr
        ld b,4
.c:     push bc
        call vb_poll
        call restore_cell
        ld de,16
        add hl,de
        pop bc
        djnz .c
        inc c
        jr .r

spr_draw:
        ld a,(d_face)           ; variant = face * 4 + shift
        add a,a
        add a,a
        ld b,a
        ld a,(d_x)
        and 3
        add a,b
        ld b,a
        ld a,(d_h)              ; offset = variant * rows * 8
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,0
        inc b
        jr .v
.va:    add hl,de
.v:     djnz .va
        push hl
        ld hl,(d_vt)            ; this frame's variants: block, address
        ld a,(hl)
        call bank_port
        ld (d_port),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        add hl,de
        push hl                 ; source
        ld a,(d_y)
        ld l,a
        ld h,0
        ld de,yline
        add hl,de
        ld a,(hl)
        ld (cur_line),a
        ld a,(d_rcy0)
        ld c,a
        ld a,(d_rcx)
        call cell_addr
        ld a,(cur_line)
        or l
        ld l,a
        ex de,hl                ; DE = destination
        pop hl
        ld a,(d_h)
        ld b,a
        ld a,(cur_line)
        ld c,a
        ld a,(d_port)
        call spr_blit
        ld a,(d_rcy0)           ; ink + queue the rectangle
        ld c,a
.r:     ld a,(d_rcy1)
        cp c
        ret c
        ld a,(d_rcx)
        call cell_addr
        ld b,4
.c:     push hl                 ; bare cells (no ink of their own) take the
        ld a,h                  ; sprite's ink; scenery keeps its colour
        sub $40
        ld h,a
        ld a,l
        or 12
        ld l,a
        ld a,(gmode)
        or a
        ld a,0
        jr nz,.bare             ; (the shaft: always)
        ld a,(hl)
        and $0F
.bare:  pop hl
        or a
        jr nz,.keep
        ld a,l
        or 12
        ld l,a
        ld a,(hl)
        and $F0
        push hl
        ld hl,d_ink
        or (hl)
        pop hl
        ld (hl),a
        ld a,l
        and $F0
        ld l,a
.keep:  call dirty_cell
        ld de,16
        add hl,de
        djnz .c
        inc c
        jr .r

; ---------------------------------------------------------------- Wren
wren_rect:
        ld a,(wx)
        ld (d_x),a
        ld a,(wy)
        ld (d_y),a
        ld a,24
        ld (d_h),a
        call spr_rect
        ld a,(d_rcx)
        ld (rcx),a
        ld a,(d_rcy0)
        ld (rcy0),a
        ld a,(d_rcy1)
        ld (rcy1),a
        ret

wren_erase:
        ld a,(rcy0)
        ld b,a
        ld a,(rcy1)
        ld c,a
        ld a,(rcx)
        jp erase_rect

wren_draw:
        ld a,(wframe)           ; wren_vt + frame * 3
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,wren_vt
        add hl,de
        ld (d_vt),hl
        ld a,(wx)
        ld (d_x),a
        ld a,(wy)
        ld (d_y),a
        ld a,(wface)
        ld (d_face),a
        ld a,24
        ld (d_h),a
        ld a,WREN_FG
        ld (d_ink),a
        ld a,(rcx)
        ld (d_rcx),a
        ld a,(rcy0)
        ld (d_rcy0),a
        ld a,(rcy1)
        ld (d_rcy1),a
        jp spr_draw

wren_place:
        ld a,F_STAND
        ld (wframe),a
        xor a
        ld (wstate),a
        call wren_rect
        jp wren_draw
