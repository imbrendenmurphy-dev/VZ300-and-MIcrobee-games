; ---------------------------------------------------------------------------
; video.asm - back buffer, beam-safe copy, sprite cache and blitter, text
; ---------------------------------------------------------------------------

; ---- build row table: ROWTAB[r] = BUF + r*STRIDE + MARGIN
init_rowtab:
        ld a,STRIDE
        ld (row_stride),a
        xor a
        ld (ds_lastwb),a        ; force re-patch
        ld hl,BUF+MARGIN
        ld ix,ROWTAB
        ld b,PF_ROWS
        ld de,STRIDE
.l:     ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        add hl,de
        djnz .l
        ret

; ---- clear the visible 32 columns of each buffer row to blue (~10.9K T)
; (margins only ever receive the off-screen halves of wrapped sprites)
clear_buf:
        ld (sp_save),sp
        ld de,$AAAA
CROW = 0
        DUP PF_ROWS
        ld sp,BUF + CROW*STRIDE + MARGIN + 32
        push de
        push de
        push de
        push de
        push de
        push de
        push de
        push de
        push de
        push de
        push de
        push de
        push de
        push de
        push de
        push de
CROW = CROW + 1
        EDUP
        ld sp,(sp_save)
        ret

; ---- copy visible part of back buffer to VRAM rows 6..63  (~23.7K T)
; Must be started right after the field-sync falling edge: it finishes
; inside vertical blanking, and in any case outruns the beam.
copy_buf:
        ld (sp_save),sp
CROW = 0
        DUP PF_ROWS
        ld sp,BUF + CROW*STRIDE + MARGIN
        pop af
        pop bc
        pop de
        pop hl
        exx
        ex af,af'
        pop af
        pop bc
        pop de
        pop hl
        ld sp,VRAM + (CROW+HUD_ROWS)*32 + 16
        push hl
        push de
        push bc
        push af
        exx
        ex af,af'
        push hl
        push de
        push bc
        push af
        ld sp,BUF + CROW*STRIDE + MARGIN + 16
        pop af
        pop bc
        pop de
        pop hl
        exx
        ex af,af'
        pop af
        pop bc
        pop de
        pop hl
        ld sp,VRAM + (CROW+HUD_ROWS)*32 + 32
        push hl
        push de
        push bc
        push af
        exx
        ex af,af'
        push hl
        push de
        push bc
        push af
CROW = CROW + 1
        EDUP
        ld sp,(sp_save)
        ret

; ---- check for BennVenn SRAM bank 1 at $4000; Z set if present
check_sram:
        ld a,MAP_BANK1
        out (MAPPER),a
        ld hl,$4000
        ld (hl),$A5
        ld a,(hl)
        cp $A5
        ret nz
        ld (hl),$5A
        ld a,(hl)
        cp $5A
        ret nz
        ld hl,$67FF
        ld (hl),$3C
        ld a,(hl)
        cp $3C
        ret

; ---- build sprite descriptors and pre-shifted cache
; desc: ptr(2) wbo h size ox oy spare
preshift_all:
        ld hl,CACHE_SRAM
        ld (cache_ptr),hl
        ld hl,CACHE_SRAM_END
        ld (cache_end),hl
        ld ix,SPRDESC
        ld iy,sprite_src
        ld b,NSPRITES
.spr:   push bc
        ld a,(iy+0)             ; w px
        ld (ps_w),a
        ld c,a
        add a,3
        srl a
        srl a
        ld (ps_wbs),a           ; source bytes per row
        ld a,c
        add a,6
        srl a
        srl a
        ld (ps_wbo),a           ; output bytes per row
        ld a,(iy+1)
        ld (ps_h),a
        ; size = wbo*h
        ld b,a
        xor a
        ld hl,ps_wbo
.mul:   add a,(hl)
        djnz .mul
        ld (ps_size),a
        ; need 4*size bytes; switch to main RAM area if SRAM full
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ex de,hl                ; DE = 4*size
        ld hl,(cache_ptr)
        add hl,de
        ld bc,(cache_end)
        or a
        sbc hl,bc
        jr c,.fits
        jr z,.fits
        ld hl,CACHE_MAIN
        ld (cache_ptr),hl
        ld hl,CACHE_MAIN_END
        ld (cache_end),hl
.fits:  ld hl,(cache_ptr)
        ld (ix+0),l
        ld (ix+1),h
        ld a,(ps_wbo)
        ld (ix+2),a
        ld a,(ps_h)
        ld (ix+3),a
        ld a,(ps_size)
        ld (ix+4),a
        ld a,(ps_w)
        srl a
        ld (ix+5),a
        ld a,(ps_h)
        srl a
        ld (ix+6),a
        ld (ix+7),0
        ; generate 4 shifts
        ld de,(cache_ptr)
        xor a
.shift: ld (ps_s),a
        push iy
        pop hl
        inc hl
        inc hl                  ; HL = source rows
        ld a,(ps_h)
        ld b,a
.row:   push bc
        ; temp = source row padded to wbo bytes
        push de
        ld de,ps_tmp
        ld a,(ps_wbs)
        ld c,a
        ld b,0
        ldir
        ld a,(ps_wbo)
        ld b,a
        ld a,(ps_wbs)
        neg
        add a,b
        jr z,.nopad
        ld b,a
        xor a
.pad:   ld (de),a
        inc de
        djnz .pad
.nopad: ; shift temp right by 2*s bits
        ld a,(ps_s)
        add a,a
        or a
        jr z,.noshift
        ld c,a
.sh1:   push hl
        ld hl,ps_tmp
        ld a,(ps_wbo)
        ld b,a
        or a                    ; clear carry
.sh2:   rr (hl)
        inc hl
        djnz .sh2
        pop hl
        dec c
        jr nz,.sh1
.noshift:
        pop de
        push hl
        ld hl,ps_tmp
        ld a,(ps_wbo)
        ld c,a
        ld b,0
        ldir                    ; DE advances
        pop hl
        pop bc
        djnz .row
        ld a,(ps_s)
        inc a
        cp 4
        jr nz,.shift
        ld (cache_ptr),de
        ; next source sprite: iy += 2 + wbs*h
        ld a,(ps_size)          ; reuse: compute wbs*h
        ld a,(ps_h)
        ld b,a
        xor a
        ld hl,ps_wbs
.mul2:  add a,(hl)
        djnz .mul2
        ld e,a
        ld d,0
        inc de
        inc de
        add iy,de
        ld de,8
        add ix,de
        pop bc
        dec b
        jp nz,.spr
        ret

; ---- draw sprite (XOR) into the back buffer (or VRAM via ROWTAB) with wrap-around
; in: A = sprite id, D = x centre (0..127), E = y centre row (0..57)
; uses all regs except IX/IY
draw_spr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,SPRDESC
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = data (shift 0)
        inc hl
        ld a,(hl)               ; wb
        inc hl
        cp 0
ds_lastwb equ $-1
        jr z,.samew
        ; width changed: repatch entry + stride
        ld (ds_lastwb),a
        ld (ds_wb),a
        push hl
        push bc
        ld c,a
        ld a,(row_stride)
        sub c
        ld (dr_stride+1),a
        ld a,7
        sub c
        ld b,a
        add a,a
        add a,a
        add a,b                 ; *5
        ld l,a
        ld h,0
        ld bc,dr_u7
        add hl,bc
        ld (dr_entry+1),hl
        pop bc
        pop hl
.samew: ld a,(hl)
        ld (ds_h),a
        inc hl
        ld a,(hl)
        ld (ds_size),a
        inc hl
        ld a,d
        sub (hl)                ; x0 = x - ox
        and 127
        ld d,a                  ; D = x0
        inc hl
        ld a,e
        sub (hl)                ; y0 = y - oy
        jr nc,.ypos
        add a,PF_ROWS
.ypos:  cp PF_ROWS
        jr c,.yok
        sub PF_ROWS
.yok:   ld (ds_y0),a
        ; data += shift*size
        ld h,b
        ld l,c
        ld a,d
        and 3
        jr z,.s1
        ld b,a
        ld a,(ds_size)
        ld c,a
        ld a,b
        ld b,0
.sadd:  add hl,bc
        dec a
        jr nz,.sadd
.s1:    ld (ds_data),hl
        ; xb = x0 >> 2
        ld a,d
        rrca
        rrca
        and 31
        ld (ds_xb),a
        ld c,a
        ; fast path: no horizontal or vertical wrap
        ld a,(ds_wb)
        add a,c
        cp 33
        jr nc,.slow
        ld a,(ds_y0)
        ld b,a
        ld a,(ds_h)
        add a,b
        cp PF_ROWS+1
        jr nc,.slow
        ld a,b
        add a,a
        ld l,a
        ld h,ROWTAB/256
        ld a,(hl)
        inc l
        ld h,(hl)
        add a,c
        ld e,a
        adc a,h
        sub e
        ld d,a                  ; DE = row base + xb
        ld hl,(ds_data)
        ld a,(ds_h)
        ld b,a
        jp draw_rows
.slow:  ld a,(ds_xb)
        call ds_part
        ld a,(ds_xb)
        ld c,a
        ld a,(ds_wb)
        add a,c
        cp 33
        ret c
        ld a,(ds_xb)
        sub 32
        ; fall through: draw again shifted one screen left

; draw all rows at byte column A (signed), handles vertical wrap
ds_part:
        ld (ds_col),a
        ld hl,(ds_data)
        push hl
        ld a,(ds_y0)
        call ds_rowaddr         ; DE = dest
        pop hl
        ld a,(ds_y0)
        ld c,a
        ld a,PF_ROWS
        sub c                   ; rows until bottom
        ld c,a
        ld a,(ds_h)
        cp c
        jr c,.one
        jr z,.one
        ; split
        sub c
        push af
        ld b,c
        call draw_rows
        push hl
        xor a
        call ds_rowaddr
        pop hl
        pop af
        ld b,a
        jp draw_rows
.one:   ld b,a
        jp draw_rows

; DE = ROWTAB[A] + signed ds_col
ds_rowaddr:
        add a,a
        ld l,a
        ld h,ROWTAB/256
        ld e,(hl)
        inc l
        ld d,(hl)
        ld a,(ds_col)
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,de
        ex de,hl
        ret

; HL = src, DE = dst, B = rows. Entry/stride patched by draw_spr.
draw_rows:
dr_entry:
        jp dr_u7
dr_u7:  ld a,(de)
        xor (hl)
        ld (de),a
        inc hl
        inc de
        ld a,(de)
        xor (hl)
        ld (de),a
        inc hl
        inc de
        ld a,(de)
        xor (hl)
        ld (de),a
        inc hl
        inc de
        ld a,(de)
        xor (hl)
        ld (de),a
        inc hl
        inc de
        ld a,(de)
        xor (hl)
        ld (de),a
        inc hl
        inc de
        ld a,(de)
        xor (hl)
        ld (de),a
        inc hl
        inc de
        ld a,(de)
        xor (hl)
        ld (de),a
        inc hl
        inc de
        ld a,e
dr_stride:
        add a,0
        ld e,a
        jr nc,.nc
        inc d
.nc:    djnz draw_rows
        ret

; ---- plot pixel into back buffer: D = x (0..127), E = y (0..57), C = colour pattern
plot:
        ld a,e
        add a,a
        ld l,a
        ld h,ROWTAB/256
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,d
        rrca
        rrca
        and 31
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld a,d
        and 3
        add a,pixmask & 255
        ld e,a
        ld d,pixmask/256
        ld a,(de)
        and c
        xor (hl)
        ld (hl),a
        ret

; colour patterns for XOR drawing onto the blue (empty) back buffer
COL_Y equ $FF           ; yellow
COL_G equ $AA           ; green
COL_R equ $55           ; red
COL_B equ $AA           ; (legacy name: dim colour = green)
; direct patterns (HUD / title, written straight to VRAM)
D_Y equ $55
D_B equ $AA
D_R equ $FF
D_G equ $00

; ---- text -------------------------------------------------------------
; HL -> glyph address for char in A
char_addr:
        sub 32
        jr nc,.ok
        xor a
.ok:    cp 64
        jr c,.ok2
        sub 32                  ; lower case -> upper
.ok2:   ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        ld bc,font_data
        add hl,bc
        ld bc,0
        ret

; NOTE: char_addr clobbers C -> keep colour in a variable for print routines
; print to back buffer: HL = string, D = byte column (0..31), E = row (0..57)
; colour from (txt_col)
print_buf:
        ld a,(hl)
        or a
        ret z
        push hl
        push de
        push de
        call char_addr
        pop de
        ex de,hl                ; DE = glyph, H = col, L = row
        ld a,l
        add a,a
        ld c,a
        ld a,h
        ld h,ROWTAB/256
        ld l,c
        ld c,(hl)
        inc l
        ld b,(hl)
        ld l,a
        ld h,0
        add hl,bc               ; HL = buffer address
        ld b,5
.r:     ld a,(txt_col)
        ld c,a
        ld a,(de)
        and c
        xor (hl)
        ld (hl),a
        inc de
        ld a,l
        add a,STRIDE
        ld l,a
        jr nc,.nc
        inc h
.nc:    djnz .r
        pop de
        pop hl
        inc hl
        inc d
        jr print_buf

; print_vram with colour in (txt_col), HL string, DE vram address
print_v:
        ld a,(hl)
        or a
        ret z
        push hl
        push de
        call char_addr
        ld b,5
.r:     ld a,(hl)
        cpl
        and D_B
        ld c,a
        ld a,(txt_col)
        and (hl)
        or c
        ld (de),a
        inc hl
        ld a,e
        add a,32
        ld e,a
        jr nc,.nc
        inc d
.nc:    djnz .r
        pop de
        pop hl
        inc hl
        inc de
        jr print_v

; DE = VRAM address of text cell: A = column (0..31), B = pixel row (0..63)
vram_addr:
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,a
        ld d,$70
        add hl,de
        ex de,hl
        ret

; centre a string: HL = string -> A = start column
centre_col:
        push hl
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.e
        inc b
        inc hl
        jr .l
.e:     pop hl
        ld a,32
        sub b
        srl a
        ret

; clear VRAM to pattern A
cls_vram:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),a
        ldir
        ret
