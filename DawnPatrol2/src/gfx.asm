; ===================================================================
;  DAWN PATROL 2  -  graphics core
; ===================================================================

; ------------------------------------------------------------------
; vram_copy : back buffer playfield -> VRAM (called from ISR at FS)
; 54 rows x 32 bytes, unrolled LDI, stays ahead of the beam
; ------------------------------------------------------------------
vram_copy:
        ld hl,BUF+BTOP*BSTR+8
        ld de,VRAM+VTOP*32
        ld a,PFH
.row:
        dup 32
        ldi
        edup
        ld bc,16
        add hl,bc
        dec a
        jp nz,.row
        ret

; ------------------------------------------------------------------
; band drawing
; in: A = rows, HL = scroll x (px), DE = dest (buffer addr of col 8)
;     bd_base(tmp+0) bd_skip(tmp+2) bd_pmask, bd_shsize set by caller
; ------------------------------------------------------------------
bd_base equ tmp
bd_skip equ tmp+2
draw_band:
        ld iyl,a
        ld a,l
        and 3
        ld c,a
        srl h
        rr l
        srl h
        rr l
        ld a,(bd_pmask)
        and l
        ld l,a
        ld a,(bd_pmask+1)
        and h
        ld h,a
        push de
        ld de,(bd_shsize)
        ld a,c
        or a
        jr z,.s0
.sl:    add hl,de
        dec c
        jr nz,.sl
.s0:    ld de,(bd_base)
        add hl,de
        pop de
.row:
        dup 32
        ldi
        edup
        ld bc,(bd_skip)
        add hl,bc
        ex de,hl
        ld bc,16
        add hl,bc
        ex de,hl
        dec iyl
        jp nz,.row
        ret

; set band params: in HL = base, DE = stride, BC = shsize, A = period mask (bytes-1)
band_params:
        ld (bd_base),hl
        ld hl,-32
        add hl,de
        ld (bd_skip),hl
        ld (bd_shsize),bc
        ld l,a
        ld h,0
        ld (bd_pmask),hl
        ret

; fill A rows of buffer from HL (col 8) with byte in C
fill_rows:
        ld de,16
.r:
        dup 32
        ld (hl),c
        inc hl
        edup
        add hl,de
        dec a
        jp nz,.r
        ret

; ------------------------------------------------------------------
; render the parallax scenery for camera rcx
; ------------------------------------------------------------------
render_scenery:
        call check_ei
        ld a,BANK_P
        out (BANKPORT),a
        ; sky
        ld hl,BUF+(BTOP+0)*BSTR+8
        ld a,(skybyte)
        ld c,a
        ld a,PY_CLOUD
        call fill_rows
        ; clouds: x = rcx/8 + drift/16
        ld hl,CL_BASE
        ld de,CL_STR
        ld bc,CL_SH
        ld a,CL_P-1
        call band_params
        ld hl,(rcx)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ex de,hl
        ld hl,(cloud_drift)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        add hl,de
        ld de,BUF+(BTOP+PY_CLOUD)*BSTR+8
        ld a,CL_ROWS
        call draw_band
        ; mountains x = rcx/4
        ld hl,MT_BASE
        ld de,MT_STR
        ld bc,MT_SH
        ld a,MT_P-1
        call band_params
        ld hl,(rcx)
        srl h
        rr l
        srl h
        rr l
        ld de,BUF+(BTOP+PY_MOUNT)*BSTR+8
        ld a,MT_ROWS
        call draw_band
        ; hills x = rcx/2
        ld hl,HL_BASE
        ld de,HL_STR
        ld bc,HL_SH
        ld a,HL_P-1
        call band_params
        ld hl,(rcx)
        srl h
        rr l
        ld de,BUF+(BTOP+PY_HILL)*BSTR+8
        ld a,HL_ROWS
        call draw_band
        ; ground x = rcx
        ld hl,GR_BASE
        ld de,GR_STR
        ld bc,GR_SH
        ld a,GR_P-1
        call band_params
        ld hl,(rcx)
        ld de,BUF+(BTOP+PY_GROUND)*BSTR+8
        ld a,GR_ROWS
        call draw_band
        ; foreground x = rcx*3/2
        ld hl,FG_BASE
        ld de,FG_STR
        ld bc,FG_SH
        ld a,FG_P-1
        call band_params
        ld hl,(rcx)
        ld d,h
        ld e,l
        srl d
        rr e
        add hl,de
        ld de,BUF+(BTOP+PY_FG)*BSTR+8
        ld a,FG_ROWS
        call draw_band
        call check_ei
        ; world band (bank W)
        ld a,BANK_W
        out (BANKPORT),a
        ld hl,WD_BASE
        ld de,WD_W
        ld bc,WD_SH
        call band_params
        ld hl,$FFFF
        ld (bd_pmask),hl
        ld hl,(rcx)
        ld de,BUF+(BTOP+PY_WORLD)*BSTR+8
        ld a,WD_ROWS
        call draw_band
        ret

; ------------------------------------------------------------------
; sprite drawing
; in: A = sprite id, (spr_x) = screen x (signed 16), (spr_y) = py (signed 8)
; (draw_flash) nonzero -> draw as solid flash silhouette
; ------------------------------------------------------------------
draw_spr:
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,SPRTAB
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)               ; bytes per row (incl. shift byte)
        inc hl
        ld b,(hl)               ; height
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; block size
        ld (ds_blk),hl
        ; x
        ld hl,(spr_x)
        push de
        ld de,32
        add hl,de
        pop de
        ld a,h
        or a
        ret nz
        ld a,l
        srl a
        srl a
        ld (ds_col),a            ; column
        add a,c
        cp BSTR+1
        ret nc
        ld a,l
        and 3
        ex de,hl                ; hl = base
        jr z,.s0
        ld de,(ds_blk)
.sl:    add hl,de
        dec a
        jr nz,.sl
.s0:    ; y clip
        ld a,(spr_y)
        add a,BTOP
        bit 7,a
        jr z,.ypos
        ; top clip: skip -a rows
        neg
        cp b
        ret nc
        push af
        ld e,a
        ld a,b
        sub e
        ld b,a
        pop af
        ; hl += rows*c*2
        push bc
        ld b,a
        ld e,c
        sla e
        ld d,0
.tc:    add hl,de
        djnz .tc
        pop bc
        xor a
.ypos:  cp 64
        ret nc
        ld e,a
        add a,b
        cp 65
        jr c,.ok
        ld a,64
        sub e
        ld b,a
.ok:    ld a,(spr_vram)
        or a
        jp nz,.vram
        ; dst = BROW[e] + col
        push hl
        ld l,e
        ld h,0
        add hl,hl
        ld de,BROW
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(ds_col)
        add a,e
        ld e,a
        jr nc,.nc1
        inc d
.nc1:   pop hl
        ld iyl,b
        ld a,BSTR
        sub c
        ld iyh,a
        ld a,(draw_flash)
        or a
        jr nz,.flash
.row:   ld b,c
.byte:  ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc de
        djnz .byte
        ex de,hl
        ld a,l
        add a,iyh
        ld l,a
        jr nc,.nc2
        inc h
.nc2:   ex de,hl
        dec iyl
        jr nz,.row
        ret
.vram:  push hl
        ld a,(ds_col)
        sub 8
        jr c,.vno
        ld d,a
        add a,c
        cp 33
        jr nc,.vno
        ld a,e
        sub BTOP
        jr c,.vno
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,d
        add a,l
        ld l,a
        ld a,h
        adc a,VRAM/256
        ld h,a
        ex de,hl
        pop hl
        ld iyl,b
        ld a,32
        sub c
        ld iyh,a
        jp .row
.vno:   pop hl
        ret
.flash: ld a,c
        ld (ds_wb),a
.frow:  ld a,(ds_wb)
        ld b,a
.fb:    ld a,(hl)
        cpl
.fpat:  and $55
        ld c,a
        ld a,(de)
        and (hl)
        or c
        inc hl
        inc hl
        ld (de),a
        inc de
        djnz .fb
        ex de,hl
        ld a,l
        add a,iyh
        ld l,a
        jr nc,.nc3
        inc h
.nc3:   ex de,hl
        dec iyl
        jr nz,.frow
        ret

; ------------------------------------------------------------------
; plot a pixel in the back buffer
; in: A = colour 0..3, BC = screen x (signed), E = py (signed)
; ------------------------------------------------------------------
plot:
        ld d,a
        ld a,b
        or a
        ret nz
        ld a,c
        cp 128
        ret nc
        ld a,e
        cp PFH
        ret nc
plot_nc:                        ; D=colour, C=x (0..127), A=E=py (0..53)
        add a,BTOP
        add a,a
        ld l,a
        ld h,BROW/256
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,c
        rrca
        rrca
        and $3F
        add a,8
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld a,c
        and 3
        ld c,a
        ld a,d
        add a,a
        add a,a
        or c
        ld e,a
        ld d,PIXT/256
        ld a,(de)
        ld b,a
        ld a,c
        or 16
        ld e,a
        ld a,(de)
        and (hl)
        or b
        ld (hl),a
        ret

; horizontal line: A = colour, BC = x start (signed), E = py, L = length
hline:
        ld h,a
.lp:    push bc
        push de
        push hl
        ld a,h
        call plot
        pop hl
        pop de
        pop bc
        inc bc
        dec l
        jr nz,.lp
        ret

; ------------------------------------------------------------------
; sun : drawn only over sky-coloured pixels (so it sits behind
; clouds and mountains). in: A = py of top, C = buffer column
; ------------------------------------------------------------------
draw_sun:
        ld b,12
        ld de,(sun_ptr)
.row:   cp PY_HILL
        jr nc,.done
        push af
        push bc
        add a,BTOP
        add a,a
        ld l,a
        ld h,BROW/256
        ld a,(hl)
        inc l
        ld h,(hl)
        add a,c
        ld l,a
        jr nc,.nc
        inc h
.nc:    ex de,hl                ; de = dst, hl = sun data
        ld b,3
.byte:  ld a,(de)
        ld c,a                  ; bg
        push hl
        ld l,a
        ld h,skym/256
        ld a,(hl)               ; sky pixels
        pop hl
        and (hl)                ; & shape = m
        inc hl
        ld (.m+1),a
        ld a,(hl)
        xor c
.m:     and 0
        xor c
        ld (de),a
        inc hl
        inc de
        djnz .byte
        ex de,hl                ; de = sun data
        pop bc
        pop af
        inc a
        djnz .row
.done:  ret

; build skym table for sky colour (skycol)
build_skym:
        ld hl,skym
.lp:    ld c,l
        ld b,4
        ld e,0
.px:    ld a,c
        rlca
        rlca
        ld c,a
        and 3
        ld d,a
        ld a,(skycol)
        cp d
        ld a,e
        rlca
        rlca
        jr nz,.no
        or 3
.no:    ld e,a
        djnz .px
        ld (hl),e
        inc l
        jr nz,.lp
        ret

; ------------------------------------------------------------------
; LZ decompressor. HL = src, DE = dst
; 0 = end, 1..127 literal run, 128+ match len (n&127)+3, dist word
; ------------------------------------------------------------------
unlz:
        ld a,(hl)
        inc hl
        or a
        ret z
        jp m,.match
        ld c,a
        ld b,0
        ldir
        jr unlz
.match: and $7F
        add a,3
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld h,d
        ld l,e
        and a
        sbc hl,bc
        ld c,a
        ld b,0
        ldir
        pop hl
        jr unlz

; ------------------------------------------------------------------
; sprite pre-shifting (run once). PSJOBS: db n ; n x (dw src, dw dst, db wb, db h)
; ------------------------------------------------------------------
preshift_all:
        ld a,BANK_W
        out (BANKPORT),a
        ld hl,PSJOBS
        ld a,(hl)
        inc hl
.job:   push af
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (tmp),de             ; src
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (tmp+2),de           ; dst
        ld a,(hl)
        inc hl
        ld (tmp+4),a            ; wb
        ld a,(hl)
        inc hl
        ld (tmp+5),a            ; h
        push hl
        call preshift_one
        pop hl
        pop af
        dec a
        jr nz,.job
        ret

preshift_one:
        ; shift 0
        ld hl,(tmp)
        ld de,(tmp+2)
        ld a,(tmp+5)
.r0:    push af
        ld a,(tmp+4)
        add a,a
        ld c,a
        ld b,0
        ldir
        ld a,$FF
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        pop af
        dec a
        jr nz,.r0
        ; block size = h * (wb+1) * 2
        ld a,(tmp+4)
        inc a
        add a,a
        ld (tmp+6),a            ; row bytes
        ld e,a
        ld d,0
        ld hl,0
        ld a,(tmp+5)
        ld b,a
.mul:   add hl,de
        djnz .mul
        ld (tmp+0),hl           ; block size (src no longer needed)
        ld a,3
.sh:    push af
        ; copy previous block to next
        ld hl,(tmp+2)
        ld bc,(tmp+0)
        push hl
        add hl,bc
        ex de,hl
        pop hl
        ld (tmp+2),de
        ldir
        ; rotate each row right by 2 bits
        ld hl,(tmp+2)
        ld a,(tmp+5)
.rr:    push af
        push hl
        call .rot1
        pop hl
        push hl
        call .rot1
        pop hl
        ld a,(tmp+6)
        ld e,a
        ld d,0
        add hl,de
        pop af
        dec a
        jr nz,.rr
        pop af
        dec a
        jr nz,.sh
        ret
.rot1:  ; mask chain (even bytes) with 1s in, data chain (odd) with 0s in
        ld a,(tmp+4)
        inc a
        ld b,a
        push hl
        scf
.m:     rr (hl)
        inc hl
        inc hl
        djnz .m
        pop hl
        inc hl
        ld b,a
        or a
.d:     rr (hl)
        inc hl
        inc hl
        djnz .d
        ret

; ------------------------------------------------------------------
; periodic band expand: HL = raw rows, DE = dest base, B = rows,
; C = period bytes, A = wrap index (32 mod P)
; stride = P+32 ; produces 4 shift blocks
; ------------------------------------------------------------------
band_expand:
        ld (tmp+4),a            ; wrap index
        ld a,c
        ld (tmp+5),a            ; P
        ld a,b
        ld (tmp+6),a            ; rows
        ld (tmp+2),de           ; dest base
        ; shift 0
.r0:    push bc
        ld b,0
        push de
        ldir                    ; P bytes
        pop bc                  ; bc = row start
        push hl
        ld h,b
        ld l,c
        ld bc,32
        ldir                    ; replicate (overlapping)
        pop hl
        pop bc
        djnz .r0
        ld (tmp),hl             ; (raw ptr after - unused)
        ; block size = rows * stride
        ld a,(tmp+5)
        add a,32
        ld e,a
        ld d,0
        ld hl,0
        ld a,(tmp+6)
        ld b,a
.mul:   add hl,de
        djnz .mul
        ld (tmp),hl
        ld a,3
.sh:    push af
        ld hl,(tmp+2)
        ld bc,(tmp)
        push hl
        add hl,bc
        ex de,hl
        pop hl
        ld (tmp+2),de
        ldir
        ld hl,(tmp+2)
        ld a,(tmp+6)
.rw:    push af
        call .rot
        call .rot
        ld a,(tmp+5)
        add a,32
        ld e,a
        ld d,0
        add hl,de
        pop af
        dec a
        jr nz,.rw
        pop af
        dec a
        jr nz,.sh
        ret
.rot:   ; rotate row at HL left by 1 bit, carry in from bit7 of row[wrap]
        push hl
        ld a,(tmp+5)
        add a,32
        ld b,a
        ld e,a
        ld d,0
        push hl
        add hl,de
        dec hl
        ex (sp),hl              ; stack: end ptr, hl = row start
        ld a,(tmp+4)
        ld e,a
        add hl,de
        ld a,(hl)
        pop hl                  ; end ptr
        rla
.l:     rl (hl)
        dec hl
        djnz .l
        pop hl
        ret

; world expand: raw 12 x 192 at HL -> bank W base, 4 shifts, no wrap
world_expand:
        ld de,WD_BASE
        ld bc,WD_SH
        ldir
        ld de,WD_BASE
        ld (tmp+2),de
        ld a,3
.sh:    push af
        ld hl,(tmp+2)
        ld bc,WD_SH
        push hl
        add hl,bc
        ex de,hl
        pop hl
        ld (tmp+2),de
        ldir
        ld hl,(tmp+2)
        ld a,WD_ROWS
.rw:    push af
        call .rot
        call .rot
        ld de,WD_W
        add hl,de
        pop af
        dec a
        jr nz,.rw
        pop af
        dec a
        jr nz,.sh
        ret
.rot:   push hl
        ld de,WD_W-1
        add hl,de
        ld b,WD_W
        or a
.l:     rl (hl)
        dec hl
        djnz .l
        pop hl
        ret

; ------------------------------------------------------------------
; VRAM text (32 byte stride). txt_fg / txt_bg = colour byte patterns
; ------------------------------------------------------------------
; vaddr: in B = row (0..63), C = col (0..31) -> HL
vaddr:
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,c
        add a,l
        ld l,a
        ld a,h
        adc a,VRAM/256
        ld h,a
        ret

; print zero-terminated string DE at HL (VRAM addr)
print:
        ld a,(de)
        or a
        jr z,.e
        inc de
        push de
        call putc
        pop de
        jr print
.e:     ld (print_end),hl
        ret
print_end dw 0

; putc: A = char, HL = vram addr. advances HL by one
putc:
        sub 32
        jr nc,.ok
        xor a
.ok:    cp 64
        jr c,.ok2
        sub 32                  ; lower case -> upper
.ok2:   ld e,a
        ld d,0
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,de
        ld de,FONT
        add hl,de
        ex de,hl                ; de = glyph
        pop hl
        push hl
        ld b,3
.lp:    ld a,(de)
        inc de
        push af
        rrca
        rrca
        rrca
        rrca
        call .wr
        pop af
        dec b
        jr z,.done
        call .wr
        jr .lp
.done:  pop hl
        inc hl
        ret
.wr:    ; write nibble A&15 at HL, HL += 32
        push de
        and 15
        ld e,a
        ld d,0
        push hl
        ld hl,N2M
        add hl,de
        ld c,(hl)
        pop hl
        ld a,(txt_fg)
        and c
        ld d,a
        ld a,c
        cpl
        ld e,a
        ld a,(txt_bg)
        and e
        or d
        ld (hl),a
        ld de,32
        add hl,de
        pop de
        ret

; double size text: putc2 A=char HL=vram addr -> HL += 2
print2:
        ld a,(de)
        or a
        ret z
        inc de
        push de
        call putc2
        pop de
        jr print2

putc2:
        sub 32
        jr nc,.ok
        xor a
.ok:    ld e,a
        ld d,0
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,de
        ld de,FONT
        add hl,de
        ex de,hl
        pop hl
        push hl
        ld b,3
.lp:    ld a,(de)
        inc de
        push af
        rrca
        rrca
        rrca
        rrca
        call .wr
        call .wr2
        pop af
        dec b
        jr z,.done
        call .wr
        call .wr2
        jr .lp
.done:  pop hl
        inc hl
        inc hl
        ret
.wr2:   ld a,(tmp+7)
.wr:    ld (tmp+7),a
        push de
        push bc
        and 15
        ld c,a
        rrca
        rrca
        and 3
        call .one
        inc hl
        ld a,c
        and 3
        call .one
        ld de,31
        add hl,de
        pop bc
        pop de
        ret
.one:   push hl
        ld e,a
        ld d,0
        ld hl,D2M
        add hl,de
        ld e,(hl)
        pop hl
        ld a,(txt_fg)
        and e
        ld d,a
        ld a,e
        cpl
        ld e,a
        ld a,(txt_bg)
        and e
        or d
        ld (hl),a
        ret

; print BCD bytes: HL = vram addr, DE = bcd ptr, B = byte count
print_bcd:
.lp:    ld a,(de)
        inc de
        push af
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        push de
        push bc
        call putc
        pop bc
        pop de
        pop af
        and 15
        add a,'0'
        push de
        push bc
        call putc
        pop bc
        pop de
        djnz .lp
        ret

; print 2-digit decimal A (0..99) at HL
print_dec2:
        ld c,'0'-1
.t:     inc c
        sub 10
        jr nc,.t
        add a,10+'0'
        push af
        ld a,c
        call putc
        pop af
        jp putc

; fill VRAM rows: B = first row, C = count, A = byte
vfill:
        push af
        push bc
        ld c,0
        call vaddr
        pop bc
        pop af
        ld b,c
.r:     push bc
        ld b,32
.b:     ld (hl),a
        inc hl
        djnz .b
        pop bc
        djnz .r
        ret

cls:    ; A = byte
        ld hl,VRAM
        ld (hl),a
        ld de,VRAM+1
        ld bc,2047
        ldir
        ret

; set text colours: A = fg index, C = bg index
set_txt:
        call colbyte
        ld (txt_fg),a
        ld a,c
        call colbyte
        ld (txt_bg),a
        ret
colbyte:                        ; A = 0..3 -> pattern byte
        and 3
        ld b,a
        add a,a
        add a,a
        add a,b
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b                 ; *$55 = *(1+4+16+64)
        ret

spr_vram db 0
ds_blk  dw 0
ds_col  db 0
ds_wb   db 0
pop_pat db $55
txt_fg  db $55
txt_bg  db $AA
sun_ptr dw SUN0

N2M     db $00,$03,$0C,$0F,$30,$33,$3C,$3F,$C0,$C3,$CC,$CF,$F0,$F3,$FC,$FF
D2M     db $00,$0F,$F0,$FF
