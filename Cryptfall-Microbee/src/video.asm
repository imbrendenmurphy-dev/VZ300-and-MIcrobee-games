; =====================================================================
;  VIDEO: two screen pages flipped in vertical blanking.  Every cave
;  tile is 2 x 2 character cells; the tile glyphs live in PCG bank 0 and
;  animate by having their patterns rewritten, so a cave full of gems
;  twinkles for the cost of one tile.  Text uses the font in bank 1.
;
;  The cave scrolls a cell (8 pixels) at a time and things move between
;  tiles in two half steps, also a cell each: all plain character writes.
; =====================================================================

; A = row (0..24) -> HL = address of its first cell on the draw page.
; keeps BC, DE
row_addr:
        push de
        add a,a
        ld e,a
        ld d,0
        ld hl,row40
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(dbase)
        add a,h
        ld h,a
        pop de
        ret
row40:
        dw 0,40,80,120,160,200,240,280,320,360,400,440,480,520,560,600,640,680,720,760,800,840,880,920,960

; draw on the hidden page / on page A
draw_hidden:
        ld a,(dpage)
        xor 1
draw_page:
        add a,a
        add a,a
        add a,VIDEO>>8
        ld (dbase),a
        ret

; ---- colour RAM in the F800 window (the usual state), or the PCG
col_on: ld a,COL_ON
        out (P_COLCTL),a
        ret
col_off:
        xor a
        out (P_COLCTL),a
        ret

; clear the draw page: code A everywhere, colour C, PCG bank B in the attributes
fill_page:
        push bc
        ld hl,(dbase-1)
        ld l,0
        call .f
        pop bc
        push bc
        ld a,c
        ld hl,(dbase-1)
        ld l,0
        ld de,$800
        add hl,de
        call .f
        pop bc
        ld a,LV_ATTR
        out (P_LV),a
        ld a,b
        ld hl,(dbase-1)
        ld l,0
        call .f
        ld a,LV_SCREEN
        out (P_LV),a
        ret
.f:     ld d,h
        ld e,l
        inc de
        ld (hl),a
        ld bc,999
        ldir
        ret

; the game screen's attributes on the draw page: playfield bank 0, text rows bank 1
game_attrs:
        ld a,LV_ATTR
        out (P_LV),a
        ld a,PF_TOP
        call row_addr
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,PF_ROWS*COLS-1
        ldir
        ld a,LV_SCREEN
        out (P_LV),a
        ret

; ---------------------------------------------------------------------
;  PCG
; ---------------------------------------------------------------------
; HL = 40 bytes (4 cells of 10 rows), A = first glyph (0..124) of bank 0
pcg_tile:
        ld b,4
; HL = B x 10 bytes, A = first glyph, bank 0
pcg_put:
        ex de,hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,PCGWIN>>8
        ld h,a
        ex de,hl                ; DE = PCG address, HL = source
        call col_off
.g:     push bc
        ld bc,GLH
        ldir
        ld a,e
        add a,16-GLH
        ld e,a
        jr nc,.n
        inc d
.n:     pop bc
        djnz .g
        jp col_on

; A = PCG bank for pcg_put (and leave the screen latch on it); bank 0 = normal
pcg_bank:
        or LV_SCREEN
        out (P_LV),a
        ret

; load the font and the pause map's quarter blocks (bank 1), and the blank
; glyphs of bank 0; the tile pictures are loaded per cave (load_tiles)
pcg_init:
        ld a,1
        call pcg_bank
        ld hl,font_data
        xor a
        ld b,80
        call pcg_put
        xor a
        call pcg_bank
        ld hl,blank32
        xor a
        jp pcg_tile
blank32: ds 4*GLH

; ---------------------------------------------------------------------
;  text.  HL = string (0 ends), B = row, C = column, (txt_col) = colour.
;  Characters 32..95; lower case is folded to upper.
; ---------------------------------------------------------------------
print:  push hl
        ld a,b
        call row_addr
        ld b,0
        add hl,bc
        ex de,hl
        pop hl
.c:     ld a,(hl)
        or a
        ret z
        inc hl
        call put_char
        jr .c
; A = character at DE on the draw page (and its colour); DE moves on
put_char:
        cp 96
        jr c,.u
        sub 32
.u:     add a,$80-32
        ld (de),a
        push de
        ld a,d
        add a,8
        ld d,a
        ld a,(txt_col)
        ld (de),a
        pop de
        inc de
        ret

; print HL centred on row B
print_c:
        push hl
        ld c,0
.l:     ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc c
        jr .l
.e:     ld a,COLS
        sub c
        srl a
        ld c,a
        pop hl
        jr print

; blank row B (spaces, colour 0)
clear_row:
        ld a,b
        call row_addr
        ld b,COLS
.c:     ld (hl),$80
        push hl
        ld a,h
        add a,8
        ld h,a
        ld (hl),0
        pop hl
        inc hl
        djnz .c
        ret

; print A as two decimal digits (BCD byte) at DE
put_bcd:
        push af
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        call put_char
        pop af
        and 15
        add a,'0'
        jp put_char

; A (binary 0..255) -> HL = BCD (H hundreds, L tens/units)
bin2bcd:
        ld hl,0
        ld b,8
.b:     add a,a
        ld c,a
        ld a,l
        adc a,a
        daa
        ld l,a
        ld a,h
        adc a,a
        daa
        ld h,a
        ld a,c
        djnz .b
        ret

; ---------------------------------------------------------------------
;  the cave on the draw page
; ---------------------------------------------------------------------
; the whole playfield, final state: 22 cell rows of 40
draw_full:
        xor a
        ld (df_cy),a
.row:   call vschk
        ld a,(sy)
        ld hl,df_cy
        add a,(hl)
        ld c,a                  ; C = cave cell row
        srl a                   ; tile row
        ld h,a
        ld l,0
        srl h
        rr l
        srl h
        rr l                    ; HL = row * 64
        ld a,(sx)
        srl a
        add a,l
        ld l,a
        ld a,h
        add a,CAVE>>8
        ld h,a
        ld (df_src),hl
        ld a,c
        and 1
        ld (df_half),a
        ld a,(df_cy)
        add a,PF_TOP
        call row_addr
        ld (df_dst),hl
        ld a,(df_half)
        add a,GT>>8
        call .line
        ld hl,(df_dst)
        ld de,$800
        add hl,de
        ld (df_dst),hl
        ld a,(df_half)
        add a,CT>>8
        call .line
        ld hl,df_cy
        inc (hl)
        ld a,(hl)
        cp PF_ROWS
        jr nz,.row
        ret
.line:  ld h,a                  ; table page
        ld bc,(df_src)
        ld de,(df_dst)
        ld ixl,20
        ld a,(sx)
        rra
        jr nc,.t
        ld a,(bc)               ; odd: the right half of the first tile
        inc c
        and $7F
        or $40
        ld l,a
        ld a,(hl)
        ld (de),a
        inc de
        ld ixl,19
.t:     ld a,(bc)
        inc c
        and $7F
        ld l,a
        ld a,(hl)
        ld (de),a
        inc de
        set 6,l
        ld a,(hl)
        ld (de),a
        inc de
        dec ixl
        jr nz,.t
        ld a,(sx)
        rra
        ret nc
        ld a,(bc)               ; odd: the left half of the last tile
        and $7F
        ld l,a
        ld a,(hl)
        ld (de),a
        ret

; A = tile, B = cell row, C = cell column of its top left (viewport cells,
; may be off any edge): draw its 2 x 2 cells, clipped
plot4:  and $7F
        ld (p4_id),a
        ld d,0
.q:     ld a,d
        and 1
        add a,c
        cp COLS
        jr nc,.nx
        ld e,a                  ; E = x
        ld a,d
        rrca
        and 1
        add a,b
        cp PF_ROWS
        jr nc,.nx
        push bc
        push de
        add a,PF_TOP
        call row_addr
        ld a,e
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ex de,hl                ; DE = cell address, H = quadrant
        ld a,h
        rrca
        and 1
        add a,GT>>8
        ld b,a
        ld a,h
        and 1
        rrca
        rrca
        ld c,a
        ld a,(p4_id)
        or c
        ld c,a
        ld a,(bc)
        ld (de),a
        inc b
        inc b
        ld a,d
        add a,8
        ld d,a
        ld a,(bc)
        ld (de),a
        pop de
        pop bc
.nx:    inc d
        ld a,d
        cp 4
        jr nz,.q
        ret

; HL = cave cell -> B = cell row, C = cell column in the viewport. keeps HL
cell_xy:
        ld a,l
        and 63
        add a,a
        ld c,a
        ld a,(sx)
        ld e,a
        ld a,c
        sub e
        ld c,a
        ld a,l
        rlca
        rlca
        and 3
        ld b,a
        ld a,h
        sub CAVE>>8
        add a,a
        add a,a
        or b
        add a,a
        ld b,a
        ld a,(sy)
        ld e,a
        ld a,b
        sub e
        ld b,a
        ret

; draw cave cell HL as it stands
draw_cell:
        call cell_xy
        ld a,(hl)
        jp plot4

; every entry of a change list as it stands.  HL = list, A = count
draw_list:
        or a
        ret z
        ld b,a
.e:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        inc hl
        push hl
        ex de,hl
        call draw_cell
        pop hl
        pop bc
        djnz .e
        ret

; the frame straight after a cave step: things that moved are shown half
; way (one cell back towards where they came from).  (rn_full) = the page
; was just drawn whole.
draw_half:
        ld a,(chg_n)
        or a
        ret z
        ; pass 1: movers' cells blank, everything else as it stands
        ld hl,(chg_cur)
        ld b,a
.e:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ex de,hl
        call .valid
        jr z,.plain
        call cell_xy
        xor a
        call plot4
        jr .n1
.plain: ld a,(rn_full)
        or a
        call z,draw_cell
.n1:    pop hl
        pop bc
        djnz .e
        ; pass 2: the movers, one cell back
        ld a,(chg_n)
        ld b,a
        ld hl,(chg_cur)
.m:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ex de,hl
        call .valid
        jr z,.n2
        push af
        call cell_xy
        pop af
        dec a
        jr nz,.d2
        inc b                   ; came up: one cell lower
        jr .go
.d2:    dec a
        jr nz,.d3
        dec c                   ; came right: one cell left
        jr .go
.d3:    dec a
        jr nz,.d4
        dec b                   ; came down
        jr .go
.d4:    inc c                   ; came left
.go:    ld a,(hl)
        call plot4
.n2:    pop hl
        pop bc
        djnz .m
        ret
; HL = cell, A = the entry's direction -> NZ and A = direction if this is
; still the cell's latest arrival
.valid: or a
        ret z
        ld e,a
        set 3,h
        ld a,(hl)
        res 3,h
        cp e
        jr nz,.no
        or a
        ret
.no:    xor a
        ret

; ---------------------------------------------------------------------
;  render: bring the hidden page up to date.  (rn_tick) = a cave step
;  has just run.
; ---------------------------------------------------------------------
render:
        call draw_hidden
        ld a,(dpage)
        xor 1
        ld e,a
        ld d,0
        ; does the page need drawing whole? (scrolled since, or forced)
        ld hl,pg_force
        add hl,de
        ld a,(hl)
        ld (hl),0
        ld c,a
        ld hl,pg_sx
        add hl,de
        ld a,(sx)
        cp (hl)
        ld (hl),a
        jr z,.x
        ld c,1
.x:     ld hl,pg_sy
        add hl,de
        ld a,(sy)
        cp (hl)
        ld (hl),a
        jr z,.y
        ld c,1
.y:     ld a,c
        ld (rn_full),a
        or a
        call nz,draw_full
        ld a,(dpage)
        xor 1
        ld e,a
        ld d,0
        ld hl,pg_sync
        add hl,de
        ld a,(rn_tick)
        or a
        jr z,.steady
        ; the half-step frame
        ld (hl),0
        ld a,(rn_full)
        or a
        jr nz,.h
        ld hl,(chg_prev)
        ld a,(prev_n)
        call draw_list
.h:     jp draw_half
.steady:
        ld a,(hl)
        or a
        ret nz
        ld (hl),1
        ld a,(rn_full)
        or a
        ret nz
        ld hl,(chg_cur)
        ld a,(chg_n)
        jp draw_list

; both pages must be drawn whole
force_both:
        ld a,1
        ld (pg_force),a
        ld (pg_force+1),a
        ret

; ---------------------------------------------------------------------
;  tile animation: rewrite the patterns of the animated tiles' glyphs.
;  Called once a frame, straight after the flip.
; ---------------------------------------------------------------------
; A = frame number, HL = the slot's frame table (dw), C = slot glyph base
anim_set:
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,c
        jp pcg_tile
