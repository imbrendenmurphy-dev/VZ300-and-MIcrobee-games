; ---------------------------------------------------------------- incremental column drawers
; Same job as drawcol1/drawcol2 in raycore (which the benchmark still uses), but every write to
; colour RAM makes the CPU wait, so these only rewrite the sky and ground cells that changed since
; last frame. The wall cells are always drawn (they're textured).
; (Skipping unchanged wall cells via a RAM copy of the view was tried and gave no speed-up.)
; Per ray, in the PREVP page: +0 wall top row last frame, +64 ground start row, +128 dirty (1 = a sprite,
; a piece or the gun drew over this column, or the whole view changed: redraw it all).
; In: A = wall height, HL = top of the view in this column, (texl). Same tables as the raycore drawers.

gdraw1: ld c,a
        ld a,(texl)
        exx
        ld l,a
        ld d,VTAB>>8
        exx
        ld (gdest),hl
        call gprep
        ld a,(gt1)              ; sky: rows gt0 .. gt1-1
        ld hl,gt0
        sub (hl)
        jr z,g1w
        jr c,g1w
        ld b,a
        ld a,(gt0)
        call growp
        ld a,(gsky)
g1s:    ld (hl),a
        add hl,de
        djnz g1s
g1w:    ld a,(gt1)              ; the wall
        call growp
        call gvset
g1l:    exx
        ld a,e
        add a,b
        ld e,a
        ld a,(de)
        ld h,a
        ld a,(hl)
        exx
        ld (hl),a
        add hl,de
        djnz g1l
        ld a,(gf0)              ; ground: rows gf1 .. gf0-1 (HL is already at gf1)
        ld b,a
        ld a,(gf1)
        sub b
        ret nc
        neg
        ld b,a
        ld a,(gground)
g1f:    ld (hl),a
        add hl,de
        djnz g1f
        ret

gdraw2: ld c,a
        ld a,(texl)
        exx
        ld l,a
        ld d,VTAB>>8
        exx
        ld (gdest),hl
        call gprep
        ld a,(gt1)
        ld hl,gt0
        sub (hl)
        jr z,g2w
        jr c,g2w
        ld b,a
        ld a,(gt0)
        call growp
        ld a,(gsky)
g2s:    ld (hl),a
        inc hl
        ld (hl),a
        dec hl
        add hl,de
        djnz g2s
g2w:    ld a,(gt1)
        call growp
        call gvset
g2l:    exx
        ld a,e
        add a,b
        ld e,a
        ld a,(de)
        ld h,a
        ld a,(hl)
        exx
        ld (hl),a
        inc hl
        ld (hl),a
        dec hl
        add hl,de
        djnz g2l
        ld a,(gf0)
        ld b,a
        ld a,(gf1)
        sub b
        ret nc
        neg
        ld b,a
        ld a,(gground)
g2f:    ld (hl),a
        inc hl
        ld (hl),a
        dec hl
        add hl,de
        djnz g2f
        ret

; new top/rows/ground start from the tables (C = height); swap with last frame's for this ray
gprep:  ld b,TOPS>>8
        ld a,(bc)
        ld (gt1),a
        ld b,ROWS>>8
        ld a,(bc)
        ld (gr1),a
        ld hl,gt1
        add a,(hl)
        ld (gf1),a
        ld a,(ray)
        ld l,a
        ld h,PREVP>>8
        ld a,(hl)
        ld (gt0),a
        ld a,(gt1)
        ld (hl),a
        set 6,l
        ld a,(hl)
        ld (gf0),a
        ld a,(gf1)
        ld (hl),a
        res 6,l
        set 7,l
        ld a,(hl)
        ld (hl),0
        or a
        ret z
        xor a                   ; dirty: all the sky and all the ground
        ld (gt0),a
        ld a,VIEWH
        ld (gf0),a
        ret

; A = row -> HL = this column at that row, DE = 40
growp:  add a,a
        ld l,a
        ld h,0
        ld de,ROW40
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(gdest)
        add hl,de
        ld de,40
        ret

; texture v start and step into the alternate set, B = wall rows
gvset:  ld b,VINIT>>8
        ld a,(bc)
        exx
        ld e,a
        exx
        ld b,VSTEP>>8
        ld a,(bc)
        exx
        ld b,a
        exx
        ld a,(gr1)
        ld b,a
        ret

; everything on the view changed: redraw every column in full next frame
invalall:
        ld hl,PREVP+128
        ld b,40
ia1:    ld (hl),1
        inc hl
        djnz ia1
        ret

; mark this ray's column for a full redraw next frame
dirtyray:
        ld a,(ray)
        ld l,a
        ld h,PREVP>>8
        set 7,l
        ld (hl),1
        ret
