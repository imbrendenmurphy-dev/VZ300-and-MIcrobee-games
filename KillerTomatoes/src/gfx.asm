; =====================================================================
;  gfx.asm - video primitives for VZ300 mode 1 (128x64, 2bpp, $7000)
; =====================================================================

; ---- cls: fill whole screen with pattern byte A (fast, uses SP) ----
cls:
        ld (sp_save),sp
        ld sp,VRAM+2048
        ld h,a
        ld l,a
        ld b,128
.l:     push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        djnz .l
        ld sp,(sp_save)
        ret

; ---- yaddr: A = y (0..63) -> HL = VRAM + y*32. keeps BC,DE ----
yaddr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,high VRAM
        ld h,a
        ret

; ---- xyaddr: B = x pixel, C = y -> HL = byte address. keeps BC,DE ----
xyaddr:
        ld a,c
        call yaddr
        ld a,b
        rrca
        rrca
        and $3F
        add a,l
        ld l,a
        ret

; ---- fill_rect: B = xbyte, C = y, D = width bytes, E = height, A = pattern ----
fill_rect:
        ld (fr_pat),a
        call xyaddr_b
.row:   push hl
        ld b,d
        ld a,(fr_pat)
.col:   ld (hl),a
        inc hl
        djnz .col
        pop hl
        ld a,l
        add a,32
        ld l,a
        jr nc,$+3
        inc h
        dec e
        jr nz,.row
        ret
; B = xbyte, C = y -> HL
xyaddr_b:
        ld a,c
        call yaddr
        ld a,b
        add a,l
        ld l,a
        ret

; ---- pset: B = x, C = y, A = colour (0..3) ----
pset:
        push de
        ld e,a
        call xyaddr
        ld a,b
        and 3
        ld d,a                  ; pixel index 0..3
        ld a,e
        ; build pattern: colour * $55
        ld e,0
        or a
        jr z,.p1
        ld e,$55
        dec a
        jr z,.p1
        ld e,$AA
        dec a
        jr z,.p1
        ld e,$FF
.p1:    ld a,d
        push hl
        ld hl,pixmask
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld d,(hl)               ; D = pixel mask
        pop hl
        ld a,e
        and d
        ld e,a
        ld a,d
        cpl
        and (hl)
        or e
        ld (hl),a
        pop de
        ret
pixmask: db $C0,$30,$0C,$03

; =====================================================================
;  Colour tables. cmap (4 bytes) = physical colour for logical 0..3
;  MASKP page: mask[v]  (00 where pixel nonzero, 11 where transparent)
;  COLP page:  col[v]   (logical -> physical, transparent pixels -> 00)
;  FLASHP page: flash[v] (nonzero pixels -> flash colour)
; =====================================================================
build_tables:
        ld hl,MASKP*256
        ld c,0                  ; v
.v:     ld b,4                  ; 4 pixels
        ld a,c
        ld (bt_v),a
        xor a
        ld (bt_m),a
        ld (bt_c),a
        ld (bt_f),a
.px:    ; shift accumulators left 2
        ld a,(bt_m)
        add a,a
        add a,a
        ld (bt_m),a
        ld a,(bt_c)
        add a,a
        add a,a
        ld (bt_c),a
        ld a,(bt_f)
        add a,a
        add a,a
        ld (bt_f),a
        ld a,(bt_v)
        rlca
        rlca
        ld (bt_v),a
        and 3
        jr nz,.solid
        ld a,(bt_m)
        or 3
        ld (bt_m),a
        jr .nx
.solid: push hl
        ld hl,cmap
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        pop hl
        ld a,(bt_c)
        or e
        ld (bt_c),a
        ld a,(flashc)
        ld e,a
        ld a,(bt_f)
        or e
        ld (bt_f),a
.nx:    djnz .px
        ld a,(bt_m)
        ld (hl),a
        inc h
        ld a,(bt_c)
        ld (hl),a
        inc h
        ld a,(bt_f)
        ld (hl),a
        dec h
        dec h
        inc l
        inc c
        jr nz,.v
        ret

; ---- set sprite colour page: A = COLP or FLASHP ----
spr_page:
        ld (draw_spr.as1+1),a
        ld (draw_spr.as2+1),a
        ld (draw_spr.ss1+1),a
        ld (draw_spr.ss2+1),a
        ld (draw_spr.ss3+1),a
        ld (draw_big.bs1+1),a
        ld (draw_big.bs2+1),a
        ld (draw_big.bs3+1),a
        ld (draw_big.bs4+1),a
        ld (draw_big.bs5+1),a
        ret

; =====================================================================
;  draw_spr: 8x5 sprite. B = x (even), C = y, HL = data (10 bytes)
;  masked draw through MASKP / colour page. Uses SP to read data.
; =====================================================================
draw_spr:
        push hl
        call xyaddr
        ex de,hl                ; DE = screen
        pop hl
        ld (sp_save),sp
        ld sp,hl
        ld ixh,5
        bit 1,b
        jr nz,.sh
.ar:    pop bc
        ld l,c
        ld h,MASKP
        ld a,(de)
        and (hl)
.as1:    ld h,COLP
        or (hl)
        ld (de),a
        inc e
        ld l,b
        ld h,MASKP
        ld a,(de)
        and (hl)
.as2:    ld h,COLP
        or (hl)
        ld (de),a
        ld a,e
        add a,31
        ld e,a
        jr nc,$+3
        inc d
        dec ixh
        jr nz,.ar
        ld sp,(sp_save)
        ret
.sh:    pop bc
        ld a,c
        rrca
        rrca
        rrca
        rrca
        ld c,a
        and $0F
        ld l,a
        ld h,MASKP
        ld a,(de)
        and (hl)
.ss1:    ld h,COLP
        or (hl)
        ld (de),a
        inc e
        ld a,b
        rrca
        rrca
        rrca
        rrca
        ld b,a
        and $0F
        ld l,a
        ld a,c
        and $F0
        or l
        ld l,a
        ld h,MASKP
        ld a,(de)
        and (hl)
.ss2:    ld h,COLP
        or (hl)
        ld (de),a
        inc e
        ld a,b
        and $F0
        ld l,a
        ld h,MASKP
        ld a,(de)
        and (hl)
.ss3:    ld h,COLP
        or (hl)
        ld (de),a
        ld a,e
        add a,30
        ld e,a
        jr nc,$+3
        inc d
        dec ixh
        jr nz,.sh
        ld sp,(sp_save)
        ret

; =====================================================================
;  draw_big: B = x (even), C = y, HL = data, A = width bytes (even), IXH = rows
; =====================================================================
draw_big:
        ld (bw),a
        ld e,a
        ld a,32
        sub e
        ld (bstep),a
        push hl
        call xyaddr
        ex de,hl
        pop hl
        ld (sp_save),sp
        ld sp,hl
        bit 1,b
        jr nz,.sh
.ar:    ld a,(bw)
        srl a
        ld iyl,a
.ap:    pop bc
        ld l,c
        ld h,MASKP
        ld a,(de)
        and (hl)
.bs1:    ld h,COLP
        or (hl)
        ld (de),a
        inc e
        ld l,b
        ld h,MASKP
        ld a,(de)
        and (hl)
.bs2:    ld h,COLP
        or (hl)
        ld (de),a
        inc e
        dec iyl
        jr nz,.ap
        ld a,(bstep)
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        dec ixh
        jr nz,.ar
        ld sp,(sp_save)
        ret
.sh:
.sr:    ld ixl,0
        ld a,(bw)
        srl a
        ld iyl,a
.sp:    pop bc
        ld a,c
        rrca
        rrca
        rrca
        rrca
        ld c,a
        and $0F
        or ixl
        ld l,a
        ld h,MASKP
        ld a,(de)
        and (hl)
.bs3:    ld h,COLP
        or (hl)
        ld (de),a
        inc e
        ld a,c
        and $F0
        ld c,a
        ld a,b
        rrca
        rrca
        rrca
        rrca
        ld b,a
        and $0F
        or c
        ld l,a
        ld h,MASKP
        ld a,(de)
        and (hl)
.bs4:    ld h,COLP
        or (hl)
        ld (de),a
        inc e
        ld a,b
        and $F0
        ld ixl,a
        dec iyl
        jr nz,.sp
        ld a,ixl
        ld l,a
        ld h,MASKP
        ld a,(de)
        and (hl)
.bs5:    ld h,COLP
        or (hl)
        ld (de),a
        ld a,(bstep)
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        dec ixh
        jr nz,.sr
        ld sp,(sp_save)
        ret

; =====================================================================
;  Text: 3x5 font in 4-pixel cells. txt_fg/txt_bg pattern bytes,
;  txt_mode 0 = opaque, 1 = transparent
; =====================================================================
; draw_char: A = glyph, HL = screen addr. Keeps HL.
draw_char:
        push hl
        push hl
        add a,a
        ld e,a
        ld d,0
        ld hl,font
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        ld b,5
.r:     push bc
        ld a,e
        and 7
        ld c,a
        ld b,0
        push hl
        ld hl,mtab
        add hl,bc
        ld c,(hl)
        pop hl
        ld a,(txt_mode)
        or a
        jr nz,.tr
        ld a,(txt_fg)
        and c
        ld b,a
        ld a,c
        cpl
        ld c,a
        ld a,(txt_bg)
        and c
        or b
        ld (hl),a
        jr .nx
.tr:    ld a,c
        cpl
        and (hl)
        ld b,a
        ld a,(txt_fg)
        and c
        or b
        ld (hl),a
.nx:    srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        ld bc,32
        add hl,bc
        pop bc
        djnz .r
        pop hl
        ret
mtab:   db $00,$0C,$30,$3C,$C0,$CC,$F0,$FC

; set text colours: A = fg colour index, C = bg colour index
set_txt:
        call colpat
        ld (txt_fg),a
        ld a,c
        call colpat
        ld (txt_bg),a
        ret
; colpat: A = colour 0..3 -> pattern byte
colpat:
        push hl
        ld hl,pattab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        ret
pattab: db $00,$55,$AA,$FF

; draw_str: HL = string, B = x (byte column), C = y
;   codes: $FF end, $FE newline, $FD c = fg colour, $FC c = bg colour, $FB n = set x
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

; =====================================================================
;  Big logo letters: each font pixel = 4x3 block (1 byte x 3 rows)
;  top 2 rows colour lg_fg, bottom row lg_sh (bevel)
;  draw_bigstr: HL = string ($FF end), B = xbyte, C = y
; =====================================================================
draw_bigstr:
.lp:    ld a,(hl)
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
        jr .lp
big_char:
        add a,a
        ld e,a
        ld d,0
        ld hl,font
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = glyph
        push bc
        call xyaddr_b
        pop bc
        ld c,5
.row:   ; pixels: bit2 = left, bit1 = mid, bit0 = right
        push de
        ld a,e
        rrca
        rrca
        rrca
        and 7
        ld (bt_v),a             ; next row's pixels
        ld a,e
        and 7
        ld d,a
        push hl
        ld b,3
.cl:    ld a,d
        and 4
        jr z,.skip
        ld a,(lg_fg)
        ld (hl),a
        push hl
        push bc
        ld bc,32
        add hl,bc
        ld (hl),a
        add hl,bc
        ld a,(bt_v)
        and 4
        ld a,(lg_fg)
        jr nz,$+5
        ld a,(lg_sh)
        ld (hl),a
        pop bc
        pop hl
.skip:  inc hl
        sla d
        ld a,(bt_v)
        add a,a
        ld (bt_v),a
        djnz .cl
        pop hl
        pop de
        ld a,l
        add a,96
        ld l,a
        jr nc,$+3
        inc h
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        dec c
        jr nz,.row
        ret
