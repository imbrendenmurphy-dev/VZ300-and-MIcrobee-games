; Native Microbee glyph buffer: 40 x 25 cells, 8 x 10 pixels each.
; Game-space coordinates are retained for collision and movement only.
cls:
        ld hl,render_cache
        ld de,render_cache+1
        ld bc,NENTS*6-1
        ld (hl),0
        ldir
        ld hl,NATIVE
        ld de,NATIVE+1
        ld bc,16000-1
        ld (hl),0
        ldir
        jp dirty_all
dirty_all:
        ld hl,DIRTY_LIST
        ld (dirty_end),hl
        ld hl,$D000
        ld (dirty_end1),hl
        ld hl,NATIVE
        ld bc,1000
.cell:  push hl
        ld a,l
        or 15
        ld l,a
        ld (hl),0
        pop hl
        call dirty_cell
        ld de,16
        add hl,de
        dec bc
        ld a,b
        or c
        jr nz,.cell
        ret
build_tables:
        ret
spr_page:
        ld (native_flash),a
        ret
colpat:
        push hl
        ld hl,pattab
        and 3
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        ret
pattab: db 0,$55,$AA,$FF
set_txt:
        call colpat
        ld (txt_fg),a
        ld a,c
        call colpat
        ld (txt_bg),a
        ret

; Packed text coordinates, never dereferenced as memory.
yaddr:
        ld l,a
        ld h,0
        REPT 6
        add hl,hl
        ENDR
        ret
xyaddr:
        ld a,c
        call yaddr
        ld a,b
        rrca
        rrca
        and 63
        add a,l
        ld l,a
        ret
xyaddr_b:
        ld a,c
        call yaddr
        ld a,b
        add a,l
        ld l,a
        ret

; Header: width in bytes, native scanlines, Premium foreground colour.
draw_spr:
draw_big:
        ld a,1
        ld (blit_mode),a
draw_asset:
        ld a,b
        and 2
        ld (blit_shift),a
        ld a,b
        srl a
        srl a
        ld d,a
        ld a,(sprite_origin)
        add a,d
        ld (blit_x),a
        ld a,c
        add a,a
        add a,a
        sub 6
        jr nc,$+3
        xor a
        ld (blit_y),a
native_asset:
        ld a,(hl)
        cp 255
        jr nz,.plain
        push ix
        call prepared_asset
        pop ix
        ret
.plain:
        ld a,(hl)
        inc hl
        ld (blit_w),a
        ld a,(hl)
        inc hl
        ld (blit_h),a
        ld a,(hl)
        inc hl
        ld (blit_col),a
        ld (blit_src),hl
        ld a,(native_flash)
        cp FLASHP
        jr nz,.normal_colour
        ld a,15
        ld (blit_col),a
.normal_colour:
        ld a,(blit_mode)
        or a
        jp z,tile_fast
native_blit:
        call native_mark_rect
        ld a,(blit_mode)
        or a
        ld a,0
        jr z,.blend
        ld a,$B6
.blend: ld (native_byte),a
.row:   call hw_clock
        ld a,(blit_y)
        cp 250
        ret nc
        ld l,a
        ld h,0
        add hl,hl
        ld de,native_rows
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(blit_x)
        ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        add hl,de
        ld (blit_dst),hl
        ld de,(blit_src)
        ld a,(blit_w)
        ld b,a
        xor a
        ld (blit_carry),a
.col:   ld a,(de)
        inc de
        ld c,a
        ld a,(blit_shift)
        or a
        ld a,c
        jr z,.write
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld c,a
        ld a,(blit_carry)
        or c
        push af
        dec de
        ld a,(de)
        inc de
        rlca
        rlca
        rlca
        rlca
        and $F0
        ld (blit_carry),a
        pop af
.write: call native_byte
        push de
        ld de,16
        add hl,de
        pop de
        djnz .col
        ld a,(blit_shift)
        or a
        jr z,.endrow
        ld a,(blit_carry)
        call native_byte
.endrow:ld (blit_src),de
        ld hl,blit_y
        inc (hl)
        ld hl,blit_h
        dec (hl)
        jp nz,.row
        ret

; Aligned 16 x 20 backgrounds: four native glyphs, no pixel shifting.
; Map cells are aligned to two 8 x 10 character cells in both axes.
tile_fast:
        ld a,(blit_y)
        ld l,a
        ld h,0
        add hl,hl
        ld de,native_rows
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(blit_x)
        ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        add hl,de
        ld de,(blit_src)
        ld c,2
.half:  call hw_clock
        push hl
        call dirty_cell
        push hl
        ld a,l
        or 14
        ld l,a
        ld a,(blit_col)
        ld (hl),a
        ld a,l
        add a,16
        ld l,a
        jr nc,$+3
        inc h
        ld a,(blit_col)
        ld (hl),a
        call dirty_cell
        pop hl
        ld b,10
.row:   ld a,(de)
        ld (hl),a
        inc de
        push hl
        ld a,l
        add a,16
        ld l,a
        jr nc,$+3
        inc h
        ld a,(de)
        ld (hl),a
        inc de
        pop hl
        inc hl
        djnz .row
        pop hl
        push de
        ld de,640
        add hl,de
        pop de
        dec c
        jr nz,.half
        ret
native_byte:
        or (hl)
        ld (hl),a
        ret

native_mark_rect:
        ld a,(blit_y)
        cp 250
        ret nc
        ld l,a
        ld h,0
        add hl,hl
        ld de,native_rows
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,e
        and 15
        ld c,a
        ld a,(blit_h)
        add a,c
        dec a
        ld c,1
.divide:sub 10
        jr c,.divided
        inc c
        jr .divide
.divided:
        ld a,e
        and $F0
        ld e,a
        ld a,(blit_x)
        ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        add hl,de
.row:   push hl
        ld a,(blit_w)
        ld b,a
        ld a,(blit_shift)
        or a
        jr z,.col
        inc b
.col:   ld a,h
        cp $BE
        jr c,.safe
        jr nz,.end
        ld a,l
        cp $80
        jr nc,.end
.safe:  call dirty_cell
        push hl
        ld a,l
        or 14
        ld l,a
        ld a,(blit_col)
        ld (hl),a
        pop hl
        ld de,16
        add hl,de
        djnz .col
.end:   pop hl
        ld de,640
        add hl,de
        dec c
        jr nz,.row
        ret

draw_char:
        push hl
        push hl
        ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        ld de,font
        add hl,de
        ld (blit_src),hl
        pop hl
        ld a,l
        and 63
        push bc
        ld b,a
        ld a,(text_origin)
        add a,b
        pop bc
        ld (blit_x),a
        REPT 6
        srl h
        rr l
        ENDR
        ld a,l
        add a,a
        add a,a
        sub 6
        jr nc,$+3
        xor a
        ld (blit_y),a
        ld a,16
        ld (blit_h),a
        ld a,1
        ld (blit_w),a
        ld a,(txt_mode)
        ld (blit_mode),a
        xor a
        ld (blit_shift),a
        ld a,(txt_fg)
        call text_colour
        ld (blit_col),a
        call native_blit
        pop hl
        ret
text_colour:
        push af
        ld a,(mono_mode)
        or a
        jr z,.colour
        pop af
        ld a,15
        ret
.colour:pop af
        and 3
        push hl
        ld hl,text_palette
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        ret
text_palette: db 8,15,10,9

fill_rect:
        push bc
        push de
        ld a,b
        add a,4
        ld (blit_x),a
        ld a,c
        add a,a
        add a,a
        sub 6
        jr nc,$+3
        xor a
        ld (blit_y),a
        ld a,d
        ld (blit_w),a
        ld a,e
        add a,a
        add a,a
        ld (fill_rows),a
        xor a
        ld (blit_mode),a
        ld (blit_shift),a
        ld a,8
        ld (blit_col),a
.row:   ld hl,empty_line
        ld (blit_src),hl
        ld a,1
        ld (blit_h),a
        call native_blit
        ld hl,fill_rows
        dec (hl)
        jr nz,.row
        pop de
        pop bc
        ret
empty_line: ds 40,0
fill_rows: db 0

pset:
        ; A particle becomes a small native two-pixel spark.
        ld hl,spark_asset
        jp draw_spr
spark_asset: db 1,2,11,$C0,$C0
draw_str:
        ld a,b
        ld (txt_x0),a
        ld (txt_x),a
        ld a,c
        ld (txt_y),a
        call .ctr
.lp:    ld a,(hl)
        inc hl
        cp $FF
        ret z
        cp $FE
        jr z,.nl
        cp $FD
        jr z,.fg
        cp $FC
        jr z,.bg
        cp $FB
        jr z,.sx
        push hl
        push af
        ld a,(txt_x)
        ld b,a
        inc a
        ld (txt_x),a
        ld a,(txt_y)
        ld c,a
        call xyaddr_b
        pop af
        call draw_char
        pop hl
        ld a,(str_delay)
        or a
        jr z,.lp
        push hl
        call type_tick
        pop hl
        jr .lp
.nl:    ld a,(txt_x0)
        ld (txt_x),a
        ld a,(txt_y)
        add a,6
        ld (txt_y),a
        call .ctr
        jr .lp
; centre mode: set txt_x from the length of the line at HL
.ctr:   ld a,(txt_center)
        or a
        ret z
        push hl
        ld b,0
.cl:    ld a,(hl)
        inc hl
        cp $FE
        jr nc,.ce
        cp $FB
        jr c,.cg
        inc hl
        jr .cl
.cg:    inc b
        jr .cl
.ce:    pop hl
        ld a,32
        sub b
        srl a
        ld (txt_x),a
        ret
.fg:    ld a,(hl)
        inc hl
        call colpat
        ld (txt_fg),a
        jp .lp
.bg:    ld a,(hl)
        inc hl
        call colpat
        ld (txt_bg),a
        jp .lp
.sx:    ld a,(hl)
        inc hl
        ld (txt_x),a
        ld (txt_x0),a
        jp .lp

; print_bcd: HL = BCD bytes (big endian), B = count of bytes, DE = screen addr
print_bcd:
.lp:    ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and $0F
        add a,G_0
        push hl
        push bc
        ex de,hl
        call draw_char
        inc hl
        ex de,hl
        pop bc
        pop hl
        ld a,(hl)
        and $0F
        add a,G_0
        push hl
        push bc
        ex de,hl
        call draw_char
        inc hl
        ex de,hl
        pop bc
        pop hl
        inc hl
        djnz .lp
        ret

; print_dig: A = 0..9 (clamped), HL = screen
print_dig:
        cp 10
        jr c,$+4
        ld a,9
        add a,G_0
        jp draw_char


draw_bigstr:
.loop:  ld a,(hl)
        inc hl
        cp $FF
        ret z
        push hl
        push bc
        call big_char
        pop bc
        pop hl
        ld a,b
        add a,4
        ld b,a
        jr .loop
big_char:
        push bc
        ld l,a
        ld h,0
        add hl,hl
        ld de,big_font_table
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop bc
        sla b
        sla b
        jp draw_spr

