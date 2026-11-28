; ---------------------------------------------------------------------------
; Levels (kept in SRAM bank 3, copied to LSTAGE to build):
;   header: name, n, rate, save, minutes, skills x8, width/4, height,
;           hatch x.w y, exit x.w y, brick byte, water y x0.w x1.w,
;           background texture, nsteel, steel x (x0.w y0 x1.w y1)
;   shapes (mode: 0 solid, 1 picture only where it's air, 2 picture only
;           where it's solid, 3 erase to air):
;     1 mode tex x.w y w.w h          rectangle
;     3 mode tex y n (xl.w xr.w)xn    spans
;     4 top bottom                    edge colours (applied at the end)
;     6 xbyte y wbytes h off.w        raw picture, solid where not blue
;     8 texA texB                     strata bands 6-7 and 11-12 deep
;     9 mode tex cx.w cy rx ry        ellipse
;    10 mode tex x0.w x1.w y rough seed   ground from y down
;     0 end
; ---------------------------------------------------------------------------

; A = level number -> copy it into LSTAGE (from bank 3); HL = LSTAGE
level_fetch:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,LVTAB
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ex de,hl
        ld de,LSTAGE
        di
        ld a,$4F
        out ($50),a
        call dzx0_standard      ; the designs are packed in bank B
        ld a,$0F
        out ($50),a
        call int_poll
        ld hl,LSTAGE
        ret

; A = level -> the level variables, the picture and the mask
level_load:
        call level_fetch
        ld de,v_nbuf            ; the name (LSTAGE is reused once built)
        ld (v_lname),de
.nm:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.nm
        ld de,v_ncrt
        ld bc,4+8
        ldir                    ; n, rate, save, minutes, skills
        ld a,(v_rate)
        ld (v_minrate),a
        ld a,(hl)               ; width / 4
        inc hl
        ld (v_lwb),a
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld (v_lw),hl
        pop hl
        ld de,v_lh
        ld bc,13
        ldir                    ; lh hx.w hy ex.w ey brick wy wx0.w wx1.w bg
        ld a,(hl)               ; background texture
        inc hl
        push hl
        call tex_ptr
        ld (v_bgtex),hl
        pop hl
        ld a,(hl)
        inc hl
        ld (v_nsteel),a
        or a
        jr z,.ns
        ld b,a
        ld de,v_steel
.st:    push bc
        ld bc,6
        ldir
        pop bc
        djnz .st
.ns:    push hl
        call terr_clear
        pop hl
        ld a,$AA
        ld (v_top),a
        ld (v_bot),a
        call shapes
        call edges
        jp game_init

; A = texture number -> HL = its pattern (16 bytes)
tex_ptr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,TEXT
        add hl,de
        ret

; the background pattern everywhere, no mask
terr_clear:
        ld hl,MASK
        ld de,MASK+1
        ld bc,MASKSZ-1
        ld (hl),0
        ldir
        ld c,0                  ; row
.r:     ld a,c
        and 7
        add a,a
        ld e,a
        ld d,0
        ld hl,(v_bgtex)
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; the row's two bytes
        push bc
        ld a,c
        srl a
        add a,TERR>>8
        ld h,a
        ld a,c
        rrca
        and $80
        ld l,a
        ld b,64
.c:     ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        djnz .c
        pop bc
        call int_poll
        inc c
        ld a,c
        cp LHMAX
        jr nz,.r
        ret

; ---- shape interpreter ------------------------------------------------------
shapes:
.op:    call int_poll
        ld a,(hl)
        inc hl
        or a
        ret z
        ld (v_op),a
        cp 1
        jp z,op_rect
        cp 3
        jp z,op_spans
        cp 4
        jr z,.edge
        cp 6
        jp z,op_image
        cp 8
        jp z,op_strata
        cp 9
        jp z,op_ellipse
        cp 10
        jp z,op_ground
        cp 11
        jp z,op_stamp
        cp 12
        jp z,op_cspans
        ret                     ; (unknown: stop)
.edge:  ld a,(hl)
        ld (v_top),a
        inc hl
        ld a,(hl)
        ld (v_bot),a
        inc hl
        jr .op

; mode, tex -> v_fmode, v_tex
mode_tex:
        ld a,(hl)
        ld (v_fmode),a
        inc hl
        ld a,(hl)
        inc hl
        push hl
        call tex_ptr
        ld (v_tex),hl
        pop hl
        ret
; word at (HL)+ -> DE
getw:   ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ret

op_rect:
        call mode_tex
        call getw
        ld (v_x0),de
        ld c,(hl)               ; y
        inc hl
        call getw               ; w
        ld a,(hl)               ; h
        inc hl
        push hl
        push af
        ld hl,(v_x0)
        add hl,de
        dec hl
        ld (v_xr),hl
        pop af
        ld b,a
.r:     push bc
        ld de,(v_x0)
        call span
        pop bc
        inc c
        djnz .r
        pop hl
        jp shapes.op

op_spans:
        call mode_tex
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
.r:     push bc
        call getw
        push de
        call getw
        ld (v_xr),de
        pop de
        push hl
        call span
        pop hl
        pop bc
        inc c
        djnz .r
        jp shapes.op

; centred spans: mode tex x.w top n, then n half widths (stalactites, rocks)
op_cspans:
        call mode_tex
        call getw
        ld (v_x0),de
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
.r:     push bc
        ld e,(hl)
        inc hl
        push hl
        ld d,0
        ld hl,(v_x0)
        add hl,de
        ld (v_xr),hl
        ld hl,(v_x0)
        or a
        sbc hl,de
        jr nc,.l
        ld hl,0
.l:     ex de,hl
        call span
        pop hl
        pop bc
        inc c
        djnz .r
        jp shapes.op

; ellipse: rows cy-ry..cy+ry, half width rx * SQ[|dy| * 128 / (2 ry + 1)] / 256
op_ellipse:
        call mode_tex
        call getw
        ld (v_x0),de            ; centre x
        ld a,(hl)
        ld (v_ecy),a
        inc hl
        ld a,(hl)
        ld (v_rx),a
        inc hl
        ld a,(hl)
        ld (v_ry),a
        inc hl
        push hl
        ld a,(v_ry)
        neg
        ld (v_dy),a
.row:   ; t = |dy| * 128 / (2 ry + 1)
        ld a,(v_dy)
        bit 7,a
        jr z,.ab
        neg
.ab:    ld l,a
        ld h,0
        ld b,7
.m7:    add hl,hl
        djnz .m7                ; |dy| * 128
        ld a,(v_ry)
        add a,a
        inc a
        ld e,a
        ld d,0
        ld b,0
.dv:    or a
        sbc hl,de
        jr c,.dd
        inc b
        jr .dv
.dd:    ld a,b
        cp 65
        jr c,.t
        ld a,64
.t:     ld e,a
        ld d,0
        ld hl,SQT
        add hl,de
        ld e,(hl)               ; profile 0..255
        ld a,(v_rx)
        ; hw = rx * e / 256
        ld h,0
        ld l,0
        ld d,0
        ld b,8
.mul:   add hl,hl
        add a,a
        jr nc,.mn
        add hl,de
.mn:    djnz .mul
        ld a,h                  ; hw
        ld (v_hw),a
        ; span from cx-hw to cx+hw on row cy+dy
        ld a,(v_ecy)
        ld hl,v_dy
        add a,(hl)
        ld c,a
        ld a,c
        cp LHMAX
        jr nc,.nx               ; (above the top or below the bottom)
        ld a,(v_hw)
        ld e,a
        ld d,0
        ld hl,(v_x0)
        add hl,de
        ld (v_xr),hl
        ld hl,(v_x0)
        or a
        sbc hl,de
        jr nc,.l0
        ld hl,0
.l0:    ex de,hl
        call span
.nx:    ld a,(v_dy)
        inc a
        ld (v_dy),a
        ld hl,v_ry
        sub (hl)
        dec a
        jp m,.row               ; (dy <= ry)
        pop hl
        jp shapes.op

; ground: column heights wander by +-1 (when rough) inside y +- rough;
; filled from the surface to the bottom of the level
op_ground:
        call mode_tex
        call getw
        ld (v_x0),de
        call getw
        ld (v_x1),de
        ld a,(hl)
        ld (v_ecy),a             ; base row
        inc hl
        ld a,(hl)
        ld (v_rx),a             ; rough
        inc hl
        ld a,(hl)               ; seed
        inc hl
        push hl
        ld l,a
        ld h,$A5
        ld (v_lfsr),hl
        ld hl,(v_x1)
        ld de,(v_x0)
        or a
        sbc hl,de
        inc hl
        ld (v_cnt),hl
        ; heights
        ld hl,GBUF
        ld (v_gp),hl
        ld a,(v_ecy)
        ld (v_hw),a
.h:     ld hl,(v_gp)
        ld a,(v_hw)
        ld (hl),a
        inc hl
        ld (v_gp),hl
        call lfsr
        ld a,(v_rx)
        or a
        jr z,.hn
        ld a,l
        and 3
        jr nz,.hn
        ld a,(v_hw)
        bit 2,l
        jr z,.dn
        inc a
        jr .ck
.dn:    dec a
.ck:    ld b,a                  ; candidate
        ld a,(v_ecy)
        ld c,a
        ld a,(v_rx)
        add a,c
        cp b
        jr c,.hn                ; below y + rough: keep
        ld a,(v_rx)
        ld d,a
        ld a,c
        sub d                   ; y - rough
        ld c,a
        ld a,b
        cp c
        jr c,.hn                ; above y - rough: keep
        ld (v_hw),a
.hn:    ld hl,(v_cnt)
        dec hl
        ld (v_cnt),hl
        ld a,h
        or l
        jr nz,.h
        ld hl,(v_x1)
        ld de,(v_x0)
        or a
        sbc hl,de
        inc hl
        ld (v_cnt),hl
        ; rows: from y-rough to y+rough scan the runs, below that one span
        ld a,(v_rx)
        ld b,a
        ld a,(v_ecy)
        sub b
        jr nc,.r0
        xor a
.r0:    ld c,a
.row:   ld a,(v_lh)
        cp c
        jr z,.done
        jr c,.done
        ld a,(v_rx)
        ld b,a
        ld a,(v_ecy)
        add a,b
        cp c
        jr c,.full
        call .runs
        jr .nr
.full:  ld de,(v_x1)
        ld (v_xr),de
        ld de,(v_x0)
        push bc
        call span
        pop bc
.nr:    inc c
        jr .row
.done:  pop hl
        jp shapes.op
; runs of columns with height <= row C
.runs:  xor a
        ld (v_inrun),a
        ld hl,GBUF
        ld de,(v_x0)
        ld a,(v_cnt)
        ld (v_k),a
        ld a,(v_cnt+1)
        ld (v_k+1),a
.rl:    ld a,(hl)
        cp c
        jr z,.in
        jr c,.in
        ; out
        ld a,(v_inrun)
        or a
        jr z,.rn
        xor a
        ld (v_inrun),a
        call .emit
        jr .rn
.in:    ld a,(v_inrun)
        or a
        jr nz,.rn
        inc a
        ld (v_inrun),a
        ld (v_runx),de
.rn:    inc hl
        inc de
        push hl
        ld hl,(v_k)
        dec hl
        ld (v_k),hl
        ld a,h
        or l
        pop hl
        jr nz,.rl
        ld a,(v_inrun)
        or a
        ret z
; span from v_runx to DE-1 on row C
.emit:  push hl
        push de
        push bc
        dec de
        ld (v_xr),de
        ld de,(v_runx)
        call span
        pop bc
        pop de
        pop hl
        ret

; 16-bit Galois LFSR -> HL
lfsr:   ld hl,(v_lfsr)
        srl h
        rr l
        jr nc,.n
        ld a,h
        xor $B4
        ld h,a
.n:     ld (v_lfsr),hl
        ret

; ---- the span: row C, from DE to v_xr, mode v_fmode, texture v_tex -----------
span:
        ld a,c
        cp LHMAX
        ret nc
        ld hl,(v_xr)
        bit 7,h
        ret nz
        ld a,h
        cp 2
        jr c,.xok
        ld hl,511
        ld (v_xr),hl
.xok:   or a
        sbc hl,de
        ret c                   ; xr < xl
        ; pattern rows
        ld a,c
        and 7
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,(v_tex)
        add hl,de
        ld (v_prow),hl
        ld l,a
        ld h,0
        ld de,(v_bgtex)
        add hl,de
        ld (v_brow),hl
        pop de
        ; row bases
        ld a,c
        srl a
        add a,TERR>>8
        ld h,a
        ld a,c
        rrca
        and $80
        ld l,a
        ld (v_trow),hl
        ld a,c
        rrca
        rrca
        and $3F
        add a,MASK>>8
        ld h,a
        ld a,c
        and 3
        rrca
        rrca
        ld l,a
        ld (v_mrow),hl
.px:    ; DE = x; how many left (xr - x)?
        ld hl,(v_xr)
        or a
        sbc hl,de
        ret c
        ld a,e
        and 7
        jr nz,.nf
        ld a,h
        or a
        jr nz,.fast
        ld a,l
        cp 7
        jr nc,.fast
.nf:    ld a,e
        and 3
        jr nz,.one
        ld a,h
        or a
        jr nz,.four
        ld a,l
        cp 3
        jr c,.one
.four:  ld a,$FF
        ld (v_pm),a
        ld a,e
        and 4
        ld a,$F0
        jr z,.f1
        ld a,$0F
.f1:    ld (v_nm),a
        call .grp
        inc de
        inc de
        inc de
        inc de
        jr .px
.one:   ld a,e
        and 3
        ld hl,PMSK
        add a,l
        ld l,a
        ld a,(hl)
        ld (v_pm),a
        ld a,e
        and 7
        ld hl,BITT
        add a,l
        ld l,a
        ld a,(hl)
        ld (v_nm),a
        call .grp
        inc de
        jr .px
; whole mask bytes (8 pixels) at a time: DE = x (a multiple of 8), HL = xr - x
.fast:  inc hl
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l                    ; L = how many groups of 8
        ld b,l
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        push hl                 ; x after
        ; mask address mrow + x>>3
        ld a,e
        rrca
        rrca
        rrca
        and $1F
        bit 0,d
        jr z,.fa
        or $20
.fa:    ld hl,(v_mrow)
        add a,l
        ld l,a
        push hl
        ; display address trow + x>>2
        ld a,e
        rrca
        rrca
        and $3F
        bit 0,d
        jr z,.fb
        or $40
.fb:    ld hl,(v_trow)
        add a,l
        ld l,a
        pop de                  ; DE = mask, HL = display
        ld a,(v_fmode)
        cp 3
        jr z,.f3
        push hl
        ld hl,(v_prow)
        ld c,(hl)
        inc hl
        ld a,(hl)
        pop hl
        ld (v_sm),a             ; right pattern byte
        ld a,(v_fmode)
        or a
        jr z,.f0
        cp 1
        jr z,.fd
        ; 2: over solid
.fo:    ld a,(de)
        call .sel
        ld a,c
        xor (hl)
        and ixh
        xor (hl)
        ld (hl),a
        inc hl
        ld a,(v_sm)
        xor (hl)
        and ixl
        xor (hl)
        ld (hl),a
        inc hl
        inc de
        djnz .fo
        pop de
        jp .px
        ; 1: over air
.fd:    ld a,(de)
        cpl
        call .sel
        ld a,c
        xor (hl)
        and ixh
        xor (hl)
        ld (hl),a
        inc hl
        ld a,(v_sm)
        xor (hl)
        and ixl
        xor (hl)
        ld (hl),a
        inc hl
        inc de
        djnz .fd
        pop de
        jp .px
        ; 0: solid
.f0:    ld a,(v_sm)
.f0l:   ex de,hl
        ld (hl),$FF
        ex de,hl
        ld (hl),c
        inc hl
        ld (hl),a
        inc hl
        inc de
        djnz .f0l
        pop de
        jp .px
        ; 3: erase to the background
.f3:    push hl
        ld hl,(v_brow)
        ld c,(hl)
        inc hl
        ld a,(hl)
        pop hl
.f3l:   ex de,hl
        ld (hl),0
        ex de,hl
        ld (hl),c
        inc hl
        ld (hl),a
        inc hl
        inc de
        djnz .f3l
        pop de
        jp .px
; mask byte A -> IXH, IXL = pixel-pair selections of its two nibbles
.sel:   push hl
        ld h,NIB2>>8
        push af
        rrca
        rrca
        rrca
        rrca
        and $0F
        add a,NIB2&255
        ld l,a
        ld a,(hl)
        ld ixh,a
        pop af
        and $0F
        add a,NIB2&255
        ld l,a
        ld a,(hl)
        ld ixl,a
        pop hl
        ret

; one display byte at x DE with pixel mask v_pm, mask bits v_nm
.grp:   push de
        ; display byte address: trow + x>>2
        ld a,e
        rrca
        rrca
        and $3F
        bit 0,d
        jr z,.g0
        or $40
.g0:    ld hl,(v_trow)
        add a,l
        ld l,a
        ld (v_dp),hl
        ; mask byte address: mrow + x>>3
        ld a,e
        rrca
        rrca
        rrca
        and $1F
        bit 0,d
        jr z,.g1
        or $20
.g1:    ld hl,(v_mrow)
        add a,l
        ld l,a
        ld (v_mp),hl
        ; solid pixels of this display byte as pixel pairs
        ld a,(hl)
        bit 2,e
        jr nz,.lo
        rrca
        rrca
        rrca
        rrca
.lo:    and $0F
        ld hl,NIB2
        add a,l
        ld l,a
        ld a,(hl)
        ld (v_sm),a
        ; the pattern byte
        ld hl,(v_prow)
        bit 2,e
        jr z,.p0
        inc hl
.p0:    ld b,(hl)
        ld a,(v_fmode)
        cp 3
        jr nz,.nb
        ld hl,(v_brow)
        bit 2,e
        jr z,.p1
        inc hl
.p1:    ld b,(hl)
.nb:    ; selection
        ld a,(v_fmode)
        or a
        jr z,.m0
        cp 3
        jr z,.m3
        cp 1
        ld a,(v_sm)
        jr z,.m1
        ld c,a                  ; 2: over solid
        ld a,(v_pm)
        and c
        jr .ap
.m1:    cpl                     ; 1: over air
        ld c,a
        ld a,(v_pm)
        and c
        jr .ap
.m0:    ld hl,(v_mp)
        ld a,(v_nm)
        or (hl)
        ld (hl),a
        ld a,(v_pm)
        jr .ap
.m3:    ld hl,(v_mp)
        ld a,(v_nm)
        cpl
        and (hl)
        ld (hl),a
        ld a,(v_pm)
.ap:    ld c,a
        ld hl,(v_dp)
        ld a,b
        xor (hl)
        and c
        xor (hl)
        ld (hl),a
        pop de
        ret

; ---- raw picture: xbyte y wbytes h offset.w (from the level start) ------------
op_image:
        ld a,(hl)
        ld (v_x0),a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        ld (v_rx),a
        inc hl
        ld b,(hl)
        inc hl
        call getw
        push hl
        ld hl,LSTAGE
        add hl,de               ; the picture
.r:     push bc
        ld a,(v_rx)
        ld b,a
        ld a,(v_x0)
        ld e,a
        ld d,0
.c:     ; display byte
        push hl
        push de
        push bc
        ld a,(hl)
        ld (v_sm),a
        ex de,hl                ; HL = byte column
        add hl,hl
        add hl,hl               ; x = column * 4
        ex de,hl
        call disp_addr
        ld a,(v_sm)
        ld (hl),a
        ; mask: the non-blue pixels
        ld hl,OPQ
        ld l,a
        ld a,(hl)               ; pixel pairs, 11 = opaque
        push de
        ld b,0
        ld d,4
.bt:    rlca
        rlca
        ld h,a
        and 3
        jr z,.bz
        scf
.bz:    rl b
        ld a,h
        dec d
        jr nz,.bt
        pop de
        ; B = 4 bits (left pixel highest)
        ld a,b
        bit 2,e
        jr nz,.lo
        rlca
        rlca
        rlca
        rlca
.lo:    ld b,a
        call mask_addr
        ld a,b
        or (hl)
        ld (hl),a
        pop bc
        pop de
        pop hl
        inc hl
        inc de
        djnz .c
        pop bc
        inc c
        djnz .r
        pop hl
        jp shapes.op

; ---- a scenery stamp from the library in bank B: id (+128 flipped), x.w, y ----
; drawn only on air, the mask untouched
op_stamp:
        ld a,(hl)
        ld (v_k),a
        inc hl
        call getw
        ld (v_x0),de
        ld a,(hl)
        inc hl
        ld (v_ecy),a
        push hl
        di
        ld a,(v_k)
        add a,a                 ; (the flip bit falls off)
        ld l,a
        ld h,0
        ld de,LVBANK+2
        add hl,de
        ld a,$4F : out ($50),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,(hl)
        ld (mb_rx),a            ; upper bank scratch
        inc hl
        ld a,(hl)
        ld (mb_ry),a
        inc hl
        ld de,mb_stamp
        call dzx0_standard
        ld a,$0F
        out ($50),a
        ld a,(mb_rx) : ld (v_rx),a
        ld a,(mb_ry) : ld (v_ry),a
        ld hl,mb_stamp : ld de,STBUF : ld bc,256 : ldir
        ld de,(v_x0)
        ld a,(v_k)
        rla
        jr nc,.nf
        ld a,(v_rx)
        add a,a
        add a,a
        dec a
        ld l,a
        ld h,0
        add hl,de
        ex de,hl                ; flipped: start at the right
.nf:    ld (v_x1),de
        ld hl,STBUF
        ld a,(v_ecy)
        ld c,a
        ld a,(v_ry)
        ld b,a
.r:     push bc
        ld de,(v_x1)
        ld a,(v_rx)
        ld b,a
.c:     ld a,(hl)
        inc hl
        push hl
        push bc
        ld (v_sm),a
        ld b,4
.p:     ld a,(v_sm)
        rlca
        rlca
        ld (v_sm),a
        and 3
        cp C_BLU
        call nz,.px
        ld a,(v_k)
        rla
        jr c,.l
        inc de
        jr .n
.l:     dec de
.n:     djnz .p
        pop bc
        pop hl
        djnz .c
        pop bc
        inc c
        djnz .r
        pop hl
        jp shapes.op
; colour A at (DE, C) if that's open air in the level
.px:    push hl
        push bc
        ld b,a
        call in_level
        jr nz,.no
        call solid
        jr nz,.no
        call disp_addr          ; HL, A = pixel mask
        ld c,a
        push hl
        ld hl,COLX
        ld a,b
        add a,l
        ld l,a
        jr nc,.cx
        inc h
.cx:    ld a,(hl)
        pop hl
        xor (hl)
        and c
        xor (hl)
        ld (hl),a
.no:    pop bc
        pop hl
        ret
COLX:   db $00,$55,$AA,$FF

; ---- strata: picture-only bands 6-7 and 11-12 pixels below the surface ------
op_strata:
        ld a,(hl)
        inc hl
        push hl
        push af
        call tex_ptr
        ld (v_texa),hl
        pop af
        pop hl
        ld a,(hl)
        inc hl
        push hl
        call tex_ptr
        ld (v_texb),hl
        ld c,0
.row:   ld a,c
        ld hl,v_lh
        cp (hl)
        jp nc,.done
        push bc
        ld b,0                  ; mask byte column
        ld a,c
        call .mbyte
        ld (v_erow),hl
.col:   push bc
        ; ANDs of the mask rows above: A6 = rows y-5..y, A8, A11, A13
        xor a
        ld (v_band2),a
        ld a,c
        cp 5
        jr c,.n2
        ld hl,(v_erow)
        ld a,l
        add a,b
        ld l,a
        ld de,-64
        ld a,(hl)
        REPT 5
        add hl,de
        and (hl)
        ENDR
        jr z,.n2                ; nothing 6 deep here
        ld (v_band1),a          ; A6
        ld a,c
        cp 7
        jr c,.p1                ; band 1 = A6
        ld a,(v_band1)
        add hl,de
        and (hl)
        add hl,de
        and (hl)                ; A8
        ld (v_sm),a
        cpl
        ld b,a
        ld a,(v_band1)
        and b
        ld (v_band1),a          ; A6 and not A8
        ld a,(v_sm)
        or a
        jr z,.p1
        ld b,a
        ld a,c
        cp 10
        jr c,.p1
        ld a,b
        REPT 3
        add hl,de
        and (hl)
        ENDR
        jr z,.p1                ; A11 = 0
        ld b,a
        ld a,c
        cp 12
        ld a,b
        jr c,.b2                ; band 2 = A11
        add hl,de
        and (hl)
        add hl,de
        and (hl)                ; A13
        cpl
        and b
.b2:    ld (v_band2),a
.p1:    pop bc
        push bc
        ld a,(v_band1)
        or a
        jr z,.n1
        ld hl,(v_texa)
        call .paint
.n1:    ld a,(v_band2)
        or a
        jr z,.n2
        pop bc
        push bc
        ld hl,(v_texb)
        call .paint
.n2:    pop bc
        inc b
        ld a,b
        cp 64
        jp nz,.col
        pop bc
        call int_poll
        inc c
        jp .row
.done:  pop hl
        jp shapes.op
; mask byte at row A, column B -> HL
.mbyte: push af
        and 3
        rrca
        rrca
        or b
        ld l,a
        pop af
        rrca
        rrca
        and $3F
        add a,MASK>>8
        ld h,a
        ret
; paint A (8 mask bits) at row C, column B with pattern HL
.paint: push bc
        call .pnt
        pop bc
        ret
.pnt:   ld (v_sm),a
        ld a,c
        and 7
        add a,a
        add a,l
        ld l,a
        jr nc,.pc
        inc h
.pc:    ld e,(hl)
        inc hl
        ld d,(hl)               ; pattern bytes (left, right)
        ld a,c
        srl a
        add a,TERR>>8
        ld h,a
        ld a,c
        rrca
        and $80
        ld l,a
        ld a,b
        add a,a
        add a,l
        ld l,a                  ; HL = display byte 2B
        ld a,(v_sm)
        rrca
        rrca
        rrca
        rrca
        call .nib
        ld a,e
        xor (hl)
        and c
        xor (hl)
        ld (hl),a
        inc hl
        ld a,(v_sm)
        call .nib
        ld a,d
        xor (hl)
        and c
        xor (hl)
        ld (hl),a
        ret
; C = NIB2[A & 15] (the row in C is saved and put back by the caller's pop)
.nib:   and $0F
        push hl
        ld hl,NIB2
        add a,l
        ld l,a
        ld a,(hl)
        pop hl
        ld c,a
        ret

; ---- edges: lit tops, shaded undersides (from the mask) ----------------------
edges:
        ld a,(v_bot)
        cp BG
        jr z,.top
        ld (v_efill),a
        ld c,0
.br:    ld a,(v_lh)
        dec a
        cp c
        jr z,.top
        ld b,0
        ld a,c
        call op_strata.mbyte
        ld (v_erow),hl
.bb:    ld hl,(v_erow)
        ld a,l
        add a,b
        ld l,a
        ld d,(hl)
        ld a,d
        or a
        jr z,.bn
        ld a,l
        add a,64
        ld l,a
        jr nc,.b1
        inc h
.b1:    ld a,(hl)
        cpl
        and d
        jr z,.bn
        push bc
        call .paint
        pop bc
.bn:    inc b
        ld a,b
        cp 64
        jr nz,.bb
        inc c
        jr .br
.top:   ld a,(v_top)
        cp BG
        ret z
        ld (v_efill),a
        ld c,0
.tr:    ld a,(v_lh)
        cp c
        ret z
        ld b,0
        ld a,c
        call op_strata.mbyte
        ld (v_erow),hl
.tb:    ld hl,(v_erow)
        ld a,l
        add a,b
        ld l,a
        ld d,(hl)
        ld a,d
        or a
        jr z,.tn
        xor a
        inc c
        dec c
        jr z,.t0
        ld a,l
        sub 64
        ld l,a
        jr nc,.t1
        dec h
.t1:    ld a,(hl)
.t0:    cpl
        and d
        jr z,.tn
        push bc
        call .paint
        pop bc
.tn:    inc b
        ld a,b
        cp 64
        jr nz,.tb
        call int_poll
        inc c
        jr .tr
; paint the fill colour over mask bits A at row C, column B
.paint: push af
        ld a,c
        srl a
        add a,TERR>>8
        ld h,a
        ld a,c
        rrca
        and $80
        ld l,a
        ld a,b
        add a,a
        add a,l
        ld l,a
        pop af
        push af
        rrca
        rrca
        rrca
        rrca
        call .one
        inc hl
        pop af
.one:   and $0F
        ret z
        push hl
        ld hl,NIB2
        add a,l
        ld l,a
        ld e,(hl)
        pop hl
        ld a,(v_efill)
        xor (hl)
        and e
        xor (hl)
        ld (hl),a
        ret

; ---- level preview: quarter size (128 x 20) into PREV (32 x 20) ---------------
; the top-left pixel of each 4 x 4 block
make_preview:
        ld de,PREV
        ld c,2                  ; level row (the middle of each band of 4)
.r:     push bc
        ld a,c
        srl a
        add a,TERR>>8
        ld h,a
        ld a,c
        rrca
        and $80
        ld l,a
        ld (v_trow),hl
        ld a,c
        ld b,0
        call op_strata.mbyte
        ld (v_erow),hl
        ld b,0                  ; picture byte column = preview pixel
.c:     ld ixh,4
.p:     ; the 4 mask bits under this preview pixel
        ld hl,(v_erow)
        ld a,b
        srl a
        add a,l
        ld l,a
        ld a,(hl)
        bit 0,b
        jr nz,.lo
        rrca
        rrca
        rrca
        rrca
.lo:    and $0F
        ld c,C_BLU
        jr z,.px                ; air
        ; the leftmost solid pixel's colour
        ld hl,FSH
        add a,l
        ld l,a
        jr nc,.f
        inc h
.f:     ld c,(hl)               ; rotations
        ld hl,(v_trow)
        ld a,l
        add a,b
        ld l,a
        ld a,(hl)
.sh:    rlca
        dec c
        jr nz,.sh
        and 3
        ld c,a
.px:    ld a,ixl
        add a,a
        add a,a
        or c
        ld ixl,a
        inc b
        dec ixh
        jr nz,.p
        ld a,ixl
        ld (de),a
        inc de
        ld a,b
        cp 128
        jr c,.c
        pop bc
        ld a,c
        add a,4
        ld c,a
        cp LHMAX
        jr c,.r
        ret
; rotations to bring the leftmost set pixel of a 4-bit mask into bits 0-1
FSH:    db 0,8,6,6,4,4,4,4,2,2,2,2,2,2,2,2
; show it at screen row A (20 rows)
show_preview:
        ld c,0
        call scr_addr
        ld hl,PREV
        ld bc,20*256+32
        jp put_raw

        INCLUDE "dzx0.asm"
