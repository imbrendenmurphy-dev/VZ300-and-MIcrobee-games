; ============================================================================
;  GRAPHICS: shadow screen, sprites, effects, text, HUD
;  All drawing goes into SB; the interrupt copies SB to video RAM.
; ============================================================================

; sb_addr: B = byte column, C = row -> HL = SB address
sb_addr:
        ld a,c
        and 7
        rrca
        rrca
        rrca
        or b
        ld l,a
        ld a,c
        rrca
        rrca
        rrca
        and $1F
        add a,SB>>8
        ld h,a
        ret

; cls_sb: SB = colour pattern A (whole screen)
cls_sb:
        ld hl,SB
        ld de,SB+1
        ld bc,2047
        ld (hl),a
        ldir
        ret

; bg_to_sb: whole backdrop into SB
bg_to_sb:
        ld hl,BG
        ld de,SB
        ld bc,2048
        ldir
        ret

; restore_band: BG -> SB for rows A .. BANDBOT-1
restore_band:
        cp BANDBOT
        ret nc
        ld c,a
        ld b,0
        call sb_addr            ; HL = SB + row*32
        push hl
        ld de,BG-SB
        add hl,de               ; matching BG address
        pop de
        ld a,BANDBOT
        sub c
        ld b,a
.r:     call ldi32
        djnz .r
        ret

; ---------------------------------------------------------------------------
; draw_fighter: IX = fighter.  Picks the 0- or 2-pixel-shifted copy of the
; frame, mirrors and recolours through the transform page, clips to the
; screen edges and to clip_top.
; ---------------------------------------------------------------------------
draw_fighter:
        ld a,(ix+F_BANK)
        out ($37),a
        ld a,(ix+F_FRM)
        add a,a
        ld b,a
        add a,a
        add a,a
        add a,b                 ; frame * 10
        ld e,a
        ld d,0
        ld l,(ix+F_DIRL)
        ld h,(ix+F_DIRH)
        add hl,de
        push hl
        pop iy                  ; IY = directory entry
        call scr_x              ; HL = x on the screen
        ld e,(iy+6)             ; anchor
        ld d,0
        ld a,(ix+F_FACE)
        or a
        jr nz,.left
        or a
        sbc hl,de               ; E = x - ax
        jr .edge
.left:  add hl,de
        inc hl
        ld a,(iy+4)
        add a,a
        add a,a
        ld e,a
        or a
        sbc hl,de               ; E = x + ax + 1 - 4*wb
.edge:  ld a,l
        and $FE
        ld l,a
        and 2
        ld (d_s),a
        sra h
        rr l
        sra h
        rr l
        ld a,l
        ld (d_xb),a
        ld a,(d_s)
        or a
        ld a,(iy+4)
        ld c,(iy+0)
        ld b,(iy+1)
        jr z,.v0
        inc a
        ld c,(iy+2)
        ld b,(iy+3)
.v0:    ld (d_wv),a
        ld (d_ptr),bc
        ; columns c0 .. c1
        ld a,(d_xb)
        ld b,a
        bit 7,a
        jr z,.c0
        xor a
.c0:    ld (d_c0),a
        ld a,(d_wv)
        add a,b                 ; xb + wv
        bit 7,a
        ret nz
        cp 33
        jr c,.c1
        ld a,32
.c1:    ld hl,d_c0
        sub (hl)
        ret z
        ret c
        cp BLITMAX+1
        ret nc
        ld (d_n),a
        ; widen this tick's area to the columns drawn
        ld b,a
        ld a,(d_c0)
        ld hl,cur_l
        cp (hl)
        jr nc,$+3
        ld (hl),a
        add a,b
        inc hl
        cp (hl)
        jr c,$+3
        ld (hl),a
        ; source offset and per-row adjustment
        ld a,(d_c0)
        ld hl,d_xb
        sub (hl)
        ld c,a                  ; c0 - xb
        ld a,(ix+F_FACE)
        or a
        jr nz,.sl
        ld a,c
        ld (d_off),a
        ld a,(d_wv)
        ld hl,d_n
        sub (hl)
        ld (.adj+1),a
        ld hl,blitr_end
        jr .so
.sl:    ld a,(d_wv)
        dec a
        sub c
        ld (d_off),a
        ld a,(d_wv)
        ld hl,d_n
        add a,(hl)
        ld (.adj+1),a
        ld hl,blitl_end
.so:    ; entry = end - 15 * n
        ld a,(d_n)
        ld e,a
        ld d,0
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de               ; 15n
        ex de,hl
        pop hl
        or a
        sbc hl,de
        ld (.call+1),hl
        ; rows
        ld a,GROUND
        sub (ix+F_Y)
        add a,(iy+7)            ; bottom row
        sub (iy+5)
        inc a                   ; top row (signed)
        ld (d_top),a
        ld c,0
        ld hl,clip_top
        sub (hl)
        jp p,.noskip
        neg
        ld c,a                  ; rows to skip
.noskip:
        ld a,(iy+5)
        sub c
        ret z
        ret c
        ld (d_rows),a
        ld a,(d_top)
        add a,c
        ld (d_row0),a
        ; cur_top = min(cur_top, first row)
        ld hl,cur_top
        cp (hl)
        jr nc,.nt
        ld (hl),a
.nt:    ; source = ptr + skip*wv + off
        ld hl,(d_ptr)
        ld a,c
        or a
        jr z,.ns
        ld a,(d_wv)
        ld e,a
        ld d,0
.sk:    add hl,de
        dec c
        jr nz,.sk
.ns:    ld a,(d_off)
        ld e,a
        ld d,0
        add hl,de
        push hl                 ; source
        ld a,(d_c0)
        ld b,a
        ld a,(d_row0)
        ld c,a
        call sb_addr
        ld b,h
        ld c,l                  ; BC = destination
        pop de
        ld a,(ix+F_XF)
        bit 0,(ix+F_FACE)
        jr z,.nf
        add a,2
.nf:    ld h,a                  ; transform page
        push ix
        ld a,(d_rows)
        ld ixl,a
.row:   push bc
.call:  call 0
        pop bc
        ld a,e
.adj:   add a,0
        ld e,a
        jr nc,$+3
        inc d
        ld a,c
        add a,32
        ld c,a
        jr nc,$+3
        inc b
        dec ixl
        jr nz,.row
        pop ix
        ret

; ---------------------------------------------------------------------------
; pixels and effects
; ---------------------------------------------------------------------------
; set_colour: A = colour 0-3 for plot
set_colour:
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,pl_bits
        add hl,de
        ld (plot_colp),hl
        ret

; plot: HL = x (signed 16-bit), A = row.  Clipped to 0-127 and
; ARENATOP..BANDBOT-1; widens this tick's area.
plot:
        ld c,a
        ld a,h
        or a
        ret nz
        ld a,l
        cp 128
        ret nc
        ld b,a                  ; x
        ld a,c
        cp ARENATOP
        ret c
        cp BANDBOT
        ret nc
        ld hl,cur_top
        cp (hl)
        jr nc,$+3
        ld (hl),a
        ld a,b
        rrca
        rrca
        and $1F
        ld e,a                  ; column
        ld hl,cur_l
        cp (hl)
        jr nc,$+3
        ld (hl),a
        inc a
        inc hl
        cp (hl)
        jr c,$+3
        ld (hl),a
        ld a,c
        and 7
        rrca
        rrca
        rrca
        or e
        ld l,a
        ld a,c
        rrca
        rrca
        rrca
        and $1F
        add a,SB>>8
        ld h,a
        ld a,b
        and 3
        ld e,a
        ld d,0
        push hl
        ld hl,pl_mask
        add hl,de
        ld a,(hl)
        ld hl,(plot_colp)
        add hl,de
        ld e,(hl)
        pop hl
        and (hl)
        or e
        ld (hl),a
        ret

; plotxy: HL = x, A = row
plotxy: jp plot

; draw_points: HL = point list, (pt_x) = base x, (pt_row) = base row,
; (pt_flip) = 1 to mirror dx.  Colour from set_colour.
draw_points:
        ld b,(hl)
        inc hl
.p:     push bc
        ld a,(hl)               ; dx
        inc hl
        ld c,(hl)               ; dy (up)
        inc hl
        push hl
        ld e,a
        ld d,0
        bit 7,a
        jr z,$+3
        dec d                   ; sign-extend
        ld a,(pt_flip)
        or a
        jr z,.nf
        ld a,e
        cpl
        ld e,a
        ld a,d
        cpl
        ld d,a
        inc de
.nf:    ld hl,(pt_x)
        add hl,de
        ld a,(pt_row)
        sub c
        call plotxy
        pop hl
        pop bc
        djnz .p
        ret

; hline: yellow line from (pt_x) for A pixels forward (backward if pt_flip)
; at row (pt_row).  Clipped; widens this tick's area.
hline:
        ld e,a
        ld d,0
        ld hl,(pt_x)
        ld a,(pt_flip)
        or a
        jr z,.r
        or a
        sbc hl,de
        inc hl                  ; left end
.r:     push hl
        add hl,de
        ex de,hl                ; DE = right end + 1
        pop hl
        bit 7,h
        jr z,.l1
        ld hl,0
.l1:    bit 7,d
        ret nz
        ld a,d
        or a
        jr nz,.r128
        ld a,e
        cp 129
        jr c,.r1
.r128:  ld de,128
.r1:    ld a,h
        or a
        ret nz
        ld a,e
        sub l
        ret z
        ret c
        ld b,a                  ; pixels
        ld a,(pt_row)
        cp ARENATOP
        ret c
        cp BANDBOT
        ret nc
        ld c,a
        push hl
        ld hl,cur_top
        cp (hl)
        jr nc,$+3
        ld (hl),a
        pop hl
        ld a,l
        rrca
        rrca
        and $1F
        push hl
        ld hl,cur_l
        cp (hl)
        jr nc,$+3
        ld (hl),a
        ld a,e
        dec a
        rrca
        rrca
        and $1F
        inc a
        inc hl
        cp (hl)
        jr c,$+3
        ld (hl),a
        pop hl
        ld a,l
        push af
        rrca
        rrca
        and $1F
        ld e,a
        ld a,c
        and 7
        rrca
        rrca
        rrca
        or e
        ld l,a
        ld a,c
        rrca
        rrca
        rrca
        and $1F
        add a,SB>>8
        ld h,a
        pop af
        and 3
        ld d,$3F
hl_bits_op:
        ld e,$40                ; colour pattern (self-modified: $40 yellow, 0 green)
        jr z,.px
.sh:    rrc d
        rrc d
        rrc e
        rrc e
        dec a
        jr nz,.sh
.px:    ld a,(hl)
        and d
        or e
        ld (hl),a
        rrc d
        rrc d
        rrc e
        rrc e
        ld a,d
        cp $3F
        jr nz,.nx
        inc hl
.nx:    djnz .px
        ret

; ---------------------------------------------------------------------------
; TEXT  (3x5 font in 4-pixel cells = one byte per glyph row)
; text: HL = string, B = byte column, C = row, A = colour.  Drawn over SB.
; text_bg: same, into BG
; ---------------------------------------------------------------------------
text_bg:
        push af
        ld a,BG>>8
        ld (txt_page),a
        pop af
        call text
        ld a,SB>>8
        ld (txt_page),a
        ret

text:
        ld (txt_col),a
.c:     ld a,(hl)
        or a
        ret z
        push hl
        push bc
        call glyph
        pop bc
        pop hl
        inc hl
        inc b
        jr .c

; glyph: A = char, B = column, C = row
glyph:
        sub 32
        ret c
        cp 64
        ret nc
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de               ; *5
        ld de,font
        add hl,de
        ex de,hl                ; DE = glyph rows
        call txt_addr           ; HL = address of (B, C)
        ld b,5
.r:     push bc
        ld a,(de)
        inc de
        push de
        ld e,a
        ld d,0
        push hl
        ld hl,nibm
        add hl,de
        ld b,(hl)               ; mask of set pixels
        ld a,(txt_col)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,e
        ld e,a
        ld hl,nibc
        add hl,de
        ld c,(hl)               ; coloured pixels
        pop hl
        ld a,b
        cpl
        and (hl)
        or c
        ld (hl),a
        ld de,32
        add hl,de
        pop de
        pop bc
        djnz .r
        ret

; txt_addr: B = column, C = row -> HL in the text page (SB or BG)
txt_addr:
        call sb_addr
        ld a,(txt_page)
        sub SB>>8
        add a,h
        ld h,a
        ret

; big text: double size (8-pixel cells, 10 rows), with a red drop shadow
; big_text: HL = string, C = row; centred
big_text:
        push hl
        call strlen
        add a,a
        ld b,a
        ld a,32
        sub b
        srl a
        ld b,a                  ; first column
        pop hl
        push hl
        push bc
        inc c
        ld a,3
        call big_line           ; shadow, one row lower
        pop bc
        pop hl
        ld a,1
        jp big_line

; big_line: HL = string, B = column, C = row, A = colour
big_line:
        ld (txt_col),a
.c:     ld a,(hl)
        or a
        ret z
        push hl
        push bc
        call big_glyph
        pop bc
        pop hl
        inc hl
        inc b
        inc b
        jr .c

big_glyph:
        sub 32
        ret c
        cp 64
        ret nc
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        ld de,font
        add hl,de
        ex de,hl
        call txt_addr
        ld b,5
.r:     push bc
        ld a,(de)
        inc de
        push de
        ld c,a
        ; left byte from bits 3,2 ; right byte from bits 1,0
        rrca
        rrca
        and 3
        call .dbl
        inc hl
        ld a,c
        and 3
        call .dbl
        ld de,31
        add hl,de
        ld a,c
        rrca
        rrca
        and 3
        call .dbl
        inc hl
        ld a,c
        and 3
        call .dbl
        ld de,31
        add hl,de
        pop de
        pop bc
        djnz .r
        ret
.dbl:   ; write the doubled 2-pixel pattern A at (HL)
        push bc
        push de
        push hl
        ld e,a
        ld d,0
        ld hl,dblm
        add hl,de
        ld b,(hl)
        ld a,(txt_col)
        add a,a
        add a,a
        add a,e
        ld e,a
        ld hl,dblc
        add hl,de
        ld c,(hl)
        pop hl
        ld a,b
        cpl
        and (hl)
        or c
        ld (hl),a
        pop de
        pop bc
        ret

; strlen: HL = string -> A = length
strlen:
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc b
        jr .l
.e:     ld a,b
        ret

; text_c: small text centred on the screen. HL = string, C = row, A = colour
text_c:
        push af
        push hl
        call strlen
        ld b,a
        ld a,32
        sub b
        srl a
        ld b,a
        pop hl
        pop af
        jp text

; fill_rect: B = column, C = row, D = width (bytes), E = height, A = byte
fill_rect:
        push af
        call sb_addr
        pop af
.r:     push hl
        push de
        ld b,d
.c:     ld (hl),a
        inc hl
        djnz .c
        pop de
        pop hl
        push de
        ld de,32
        add hl,de
        pop de
        dec e
        jr nz,.r
        ret

; ---------------------------------------------------------------------------
; HUD (rows 0-7, drawn straight into SB; copied when copy_hud is set)
; ---------------------------------------------------------------------------
hud_all:
        ld a,$AA                ; the HUD band is dark blue
        ld b,0
        ld c,0
        ld d,32
        ld e,HUDROWS
        call fill_rect
        call hud_names
        call hud_bars
        call hud_timer
        call hud_pips
        ret

; names above the bars
hud_names:
        ld a,$AA
        ld b,0
        ld c,0
        ld d,9
        ld e,5
        call fill_rect
        ld a,$AA
        ld b,23
        ld c,0
        ld d,9
        ld e,5
        call fill_rect
        ld a,(p1+F_CHAR)
        call char_name
        ld b,1
        ld c,0
        ld a,1
        call text
        ld a,(p2+F_CHAR)
        call char_name
        push hl
        call strlen
        ld b,a
        ld a,31
        sub b
        ld b,a
        pop hl
        ld c,0
        ld a,1
        call text
        ld a,1
        ld (copy_hud),a
        ret

hud_bars:
        ; player 1: bytes 1-12, health anchored at the centre end
        ld a,(p1+F_HP)
        inc a
        srl a                   ; L = pixels of health (0-48)
        ld c,a
        ld a,48
        sub c
        ld d,a                  ; first filled pixel
        ld e,48                 ; end
        ld b,1
        call bar
        ; player 2: bytes 19-30
        ld a,(p2+F_HP)
        inc a
        srl a
        ld e,a
        ld d,0
        ld b,19
        call bar
        ld a,1
        ld (copy_hud),a
        ret

; bar: B = first byte column, D..E-1 = pixels of health (0-47); the rest is
; red (health lost).  Rows 6-9, yellow frame.
bar:
        push bc
        push de
        ld c,6
        call sb_addr
        push hl
        ld b,12
.o1:    ld (hl),$55
        inc hl
        djnz .o1
        pop hl
        ld de,96
        add hl,de
        ld b,12
.o4:    ld (hl),$55
        inc hl
        djnz .o4
        pop de
        pop bc
        ld c,7
        call .row
        ld c,8
.row:   push bc
        push de
        call sb_addr
        ld c,0                  ; pixel index
        ld b,12
.byte:  push bc
        ld b,4
        xor a
        ld (bar_acc),a
.px:    ld a,(bar_acc)
        add a,a
        add a,a
        ld (bar_acc),a
        ld a,c
        or a
        jr z,.yel
        cp 47
        jr z,.yel
        cp d
        jr c,.lost
        cp e
        jr nc,.lost
.yel:   ld a,1
        jr .set
.lost:  ld a,3
.set:   push hl
        ld hl,bar_acc
        or (hl)
        ld (hl),a
        pop hl
        inc c
        djnz .px
        ld a,(bar_acc)
        ld (hl),a
        inc hl
        pop bc
        ld a,c
        add a,4
        ld c,a
        djnz .byte
        pop de
        pop bc
        ret

; the round timer: big yellow digits in the middle of the band
hud_timer:
        ld a,$AA
        ld b,14
        ld c,0
        ld d,4
        ld e,HUDROWS
        call fill_rect
        ld a,(round_time)
        ld b,0
.t:     cp 10
        jr c,.u
        sub 10
        inc b
        jr .t
.u:     add a,'0'
        ld (num_buf+1),a
        ld a,b
        add a,'0'
        ld (num_buf),a
        xor a
        ld (num_buf+2),a
        ld hl,num_buf
        ld b,14
        ld c,0
        ld a,1
        call big_line
        ld a,1
        ld (copy_hud),a
        ret

; round wins: two slots beside each name, yellow when won
hud_pips:
        ld a,(p1+F_WINS)
        ld b,a
        ld hl,SB+1*32+8
        call .pips
        ld a,(p2+F_WINS)
        ld b,a
        ld hl,SB+1*32+22
        call .pips
        ld a,1
        ld (copy_hud),a
        ret
.pips:  ; B = wins, HL = first slot (row 1); slots are bytes, 3 rows tall
        ld c,2
.pl:    ld a,b
        or a
        ld a,$82                ; empty slot: green middle
        jr z,.e
        ld a,$54
        dec b
.e:     push hl
        ld de,32
        ld (hl),a
        add hl,de
        ld (hl),a
        add hl,de
        ld (hl),a
        pop hl
        inc hl
        dec c
        jr nz,.pl
        ret

; floor_names: the street needs nothing printed now (names live in the HUD)
floor_names:
        ret

; char_name: A = character -> HL = name
char_name:
        ld hl,s_flick
        or a
        ret z
        ld hl,s_dusty
        ret
