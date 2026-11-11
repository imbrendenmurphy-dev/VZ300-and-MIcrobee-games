; ==========================================================================
; road.asm - "PCG strip" pseudo-3D road renderer      (ViBED by BPM 2026)
;
;  Geometry : segment projection (curves + hills with crest occlusion),
;             24 projected points (1 segment apart near, 2 apart far).
;  Raster   : 64x16 cells of 8x16, hardware page flip via 6545 R12/R13
;             (page 0 at MA 000h, page 1 at MA 400h).
;             Chunky logical pixels of 2x2 -> 256x128 playfield.
;  Cells    : every road cell uses a PCG character from bank 0, so road
;             rows never need attribute writes:
;               - one "stripe" char per row: each line is solid (A) or a
;                 fine checker of A/B, giving the moving light/dark bands
;                 with only two colours per cell;
;               - a static edge library (slope x sub-cell offset) for cells
;                 where road, kerb and verge meet.
;             Stripe bitmaps are prepared in RAM and blitted to PCG in the
;             vertical blank right after the page flip.
; ==========================================================================

; --------------------------------------------------------------------------
; project: fills SYT/SXT/SWT[p], PHT[p] for p=0..NSEG and LINEK[y], LTOP
; --------------------------------------------------------------------------
P_project:
project:
        ld hl,(camPos)
        ld a,h
        ld (seg),a
        ld a,l
        ld (frac),a
        rrca
        rrca
        rrca
        and 1Fh
        ld (fq),a
        ; camera ground height: lerp(TY[seg], TY[seg+1], frac)
        ld a,(seg)
        inc a
        call get_ty
        push hl
        ld a,(seg)
        call get_ty
        pop de
        ld a,(frac)
        call lerp
        ld de,CAMH
        add hl,de
        ld (H0),hl
        ; DXK = -(curve[seg] * frac) >> 8 ; XK = 0
        ld a,(seg)
        call get_curve
        ld (.csg),a
        bit 7,a
        jr z,.cp
        neg
.cp     ld e,a
        ld a,(frac)
        call mul8q
        ld l,h
        ld h,0
        ld a,(.csg)
        bit 7,a
        call z,neghl
        ld (DXK),hl
        ld hl,0
        ld (XK),hl
        ld a,128
        ld (maxy),a
        xor a
        ld (kseg),a
        inc a
        ld (kk),a
        ; point loop -------------------------------------------------------
.kl     ld a,(kk)
        and 7
        call z,vbpoll
        ; advance PSTEP[p] segments, accumulating the curve
        ld a,(kk)
        ld e,a
        ld d,0
        ld hl,PSTEP
        add hl,de
        ld b,(hl)
.st     push bc
        ld a,(seg)
        ld hl,kseg
        add a,(hl)
        inc (hl)
        call get_curve
        ld e,a
        rlca
        sbc a,a
        ld d,a
        ld hl,(DXK)
        add hl,de
        ld (DXK),hl
        ld de,(XK)
        add hl,de
        ld (XK),hl
        pop bc
        djnz .st
        ld a,(seg)
        ld hl,kseg
        add a,(hl)
        ld (sk),a
        ; parity of the last segment of this strip -> stripe phase
        dec a
        and 1
        ld b,a
        ld a,(kk)
        ld e,a
        ld d,0
        ld hl,PHT
        add hl,de
        ld (hl),b
        ; table index = p*32 + fq
        ld l,e
        ld h,d
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(fq)
        or l
        ld l,a
        ld (tidx),hl
        ld de,INVM
        add hl,de
        ld a,(hl)
        ld (invm),a
        ld de,INVR-INVM
        add hl,de
        ld a,(hl)
        ld (invr),a
        ; sy = HY + (H0 - TY[sk]) * inv >> 14
        ld a,(sk)
        call get_ty
        ex de,hl
        ld hl,(H0)
        or a
        sbc hl,de
        call mulinv
        ld de,HY
        add hl,de
        ld (cur_sy),hl
        ; sx = 128 + (XK - camX) * inv >> 14
        ld hl,(XK)
        ld de,(camX)
        or a
        sbc hl,de
        call mulinv
        ld de,128
        add hl,de
        ld (cur_sx),hl
        ; sw = HWT[idx]
        ld hl,(tidx)
        ld de,HWTL
        add hl,de
        ld a,(hl)
        ld de,HWTH-HWTL
        add hl,de
        ld h,(hl)
        ld l,a
        ld (cur_sw),hl
        ; store at p
        ld a,(kk)
        add a,a
        ld e,a
        ld d,0
        ld hl,SYT
        add hl,de
        ld bc,(cur_sy)
        ld (hl),c
        inc hl
        ld (hl),b
        ld hl,SXT
        add hl,de
        ld bc,(cur_sx)
        ld (hl),c
        inc hl
        ld (hl),b
        ld hl,SWT
        add hl,de
        ld bc,(cur_sw)
        ld (hl),c
        inc hl
        ld (hl),b
        ; p == 1: virtual point 0 well below the screen
        ld a,(kk)
        dec a
        jr nz,.nv
        ld hl,400
        ld (SYT),hl
        ld hl,(cur_sx)
        ld (SXT),hl
        ld hl,(cur_sw)
        ld (SWT),hl
        ld a,(PHT+1)
        ld (PHT),a
.nv     ; visible?  sy < maxy (signed)
        ld hl,(cur_sy)
        bit 7,h
        jr nz,.vis0
        ld a,h
        or a
        jr nz,.next
        ld a,(maxy)
        ld b,a
        ld a,l
        cp b
        jr nc,.next
        jr .fill
.vis0   xor a
.fill   ld c,a                  ; new maxy
        ld hl,maxy
        ld b,(hl)
        ld (hl),c
        ld a,b
        sub c
        jr z,.next
        ld b,a
        ld a,(kk)
        ld e,c
        ld d,0
        ld hl,LINEK
        add hl,de
.fl     ld (hl),a
        inc hl
        djnz .fl
        ld a,c
        or a
        jr z,.done
.next   ld hl,kk
        inc (hl)
        ld a,(hl)
        cp NSEG+1
        jp c,.kl
.done   ld a,(maxy)
        ld (LTOP),a
        ret
.csg    db 0

; mulinv: HL = (HL * inv) >> 14 using mantissa/shift form (invm, invr)
mulinv:
        ld a,h
        ld (.sgn),a
        bit 7,h
        call nz,neghl
        ld a,h
        ld (.hh),a
        ld e,l
        ld a,(invm)
        call mul8q              ; HL = hl*m
        ld (.lo),hl
        ld a,(.hh)
        or a
        ld hl,0
        jr z,.z
        ld e,a
        ld a,(invm)
        call mul8q              ; HL = hh*m
.z      ld a,(.lo+1)
        add a,l
        ld l,a
        jr nc,.c1
        inc h                   ; H:L:(lo) = 24-bit product
.c1     ld a,(invr)
        sub 8
        jr c,.small
        jr z,.sg
        ld b,a
.s1     srl h
        rr l
        djnz .s1
        jr .sg
.small  ld a,(invr)
        ld b,a
        ld a,(.lo)
.s2     srl h
        rr l
        rra
        djnz .s2
        ld h,l
        ld l,a
.sg     ld a,(.sgn)
        bit 7,a
        ret z
        jp neghl
.sgn    db 0
.hh     db 0
.lo     dw 0

get_ty: ; A = segment -> HL = height (signed 16)
        ld l,a
        ld h,0
        ld de,TRK_YL
        add hl,de
        ld e,(hl)
        inc h
        ld d,(hl)
        ex de,hl
        ret

get_curve: ; A = segment -> A = curve
        ld l,a
        ld h,0
        ld de,TRK_CURVE
        add hl,de
        ld a,(hl)
        ret

neghl:  xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; --------------------------------------------------------------------------
; line_geom: A = logical line y -> (lcx) centre x, (lhw) half width
; --------------------------------------------------------------------------
line_geom:
        ld (.y),a
        ld l,a
        ld h,0
        ld de,LINEK
        add hl,de
        ld a,(hl)
        add a,a
        ld e,a
        ld d,0
        ld (.k2),de
        ld hl,SYT
        add hl,de
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = SY[p]
        dec hl
        dec hl
        ld d,(hl)
        dec hl
        ld e,(hl)               ; DE = SY[p-1]
        push de
        ex de,hl
        or a
        sbc hl,bc
        ex de,hl                ; DE = dy
        pop hl
        ld a,(.y)
        ld c,a
        ld b,0
        or a
        sbc hl,bc               ; HL = t
        call frac8
        ld (.f),a
        ld de,(.k2)
        ld hl,SXT
        call .lp
        ld (lcx),hl
        ld de,(.k2)
        ld hl,SWT
        call .lp
        ld (lhw),hl
        ret
.lp     add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec hl
        dec hl
        ld a,(hl)
        dec hl
        ld l,(hl)
        ld h,a
        ld a,(.f)
        jp lerp
.y      db 0
.k2     dw 0
.f      db 0

; --------------------------------------------------------------------------
; bounds_at: (lcx),(lhw) -> 4 boundary x at IX+0..7
;   b0 = cx-hw-kw  b1 = cx-hw  b2 = cx+hw  b3 = cx+hw+kw,  kw = hw/8+1
; --------------------------------------------------------------------------
bounds_at:
        ld hl,(lhw)
        bit 7,h
        jr z,.p
        ld hl,0
        ld (lhw),hl
.p      srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        inc hl
        ex de,hl                ; DE = kw
        ld hl,(lcx)
        ld bc,(lhw)
        or a
        sbc hl,bc
        ld (ix+2),l
        ld (ix+3),h
        or a
        sbc hl,de
        ld (ix+0),l
        ld (ix+1),h
        ld hl,(lcx)
        add hl,bc
        ld (ix+4),l
        ld (ix+5),h
        add hl,de
        ld (ix+6),l
        ld (ix+7),h
        ret

; --------------------------------------------------------------------------
; build_regions: BX0[4] (row top line), BX8[4] (next row's top line)
;   -> REGLEN[9] (interior, edge, interior, ...), ECODE[], REGCOL[9]
; Boundaries: 0 verge|kerb, 1 kerb|road, 2 road|kerb, 3 kerb|verge.
; A kerb too thin to resolve in this row is absorbed into the verge.
; --------------------------------------------------------------------------
P_regions:
build_regions:
        ; ---------- kerb merge state: bit0 left kerb < 1 cell, bit1 right
        ld c,0
        ld hl,(BX0+2)
        ld de,(BX0+0)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.m1
        ld a,l
        cp 4
        jr nc,.m1
        set 0,c
.m1     ld hl,(BX0+6)
        ld de,(BX0+4)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.m2
        ld a,l
        cp 4
        jr nc,.m2
        set 1,c
.m2     ld a,c
        ld (mstate),a
        xor a
        ld (cur),a
        ld hl,ECODE
        ld (eptr),hl
        ld hl,REGLEN
        ld (rptr),hl
        ld a,(mstate)
        rra
        jr c,.sk0
        xor a
        call bnd
        jr .b1
.sk0    call bnd_skip
.b1     ld a,1
        call bnd
        ld a,2
        call bnd
        ld a,(mstate)
        and 2
        jr nz,.sk3
        ld a,3
        call bnd
        jr .b4
.sk3    call bnd_skip
.b4
        ld a,(cur)              ; final interior
        ld b,a
        ld a,64
        sub b
        ld hl,(rptr)
        ld (hl),a
        ; ---------- colours: precomputed per merge state (set_theme)
        ld a,(mstate)
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,b                 ; *9
        ld e,a
        ld d,0
        ld hl,RCOLS
        ld a,(allint)
        or a
        jr z,.rc
        ld hl,HCOLS
.rc     add hl,de
        ld de,REGCOL
        ld bc,9
        ldir
        ret

bnd_skip:                       ; boundary absorbed: empty interior + edge
        push af
        ld hl,(rptr)
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (rptr),hl
        pop af
        ret

; bnd: A = boundary index -> one interior region and one edge region
bnd:
        add a,a
        ld e,a
        ld d,0
        ld hl,BX0
        add hl,de
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = x0
        ld de,7
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = x8
        ex de,hl
        or a
        sbc hl,bc               ; slope = x8 - x0
        call clamp32
        add a,32
        ld e,a
        ld d,0
        ld hl,SLOPETAB
        add hl,de
        ld a,(hl)
        add a,a
        add a,a
        ld e,a
        ld hl,EDGE_DIR
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (.ptr),de
        inc hl
        ld e,(hl)               ; omin (signed)
        inc hl
        ld a,(hl)
        ld (.span),a
        ld a,e
        rlca
        sbc a,a
        ld d,a
        ld h,b
        ld l,c
        or a
        sbc hl,de               ; t = x0 - omin
        ld (.t),hl
        sra h                   ; cmax = t >> 2
        rr l
        sra h
        rr l
        call cellof16
        ld (.cmax),a
        ld hl,(.t)              ; cmin = (t - span) >> 2 + 1
        ld a,(.span)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        sra h
        rr l
        sra h
        rr l
        inc hl
        call cellof16
        ; start = clamp(max(cmin,cur), cur..64)
        ld c,a
        ld a,(cur)
        ld b,a
        ld a,c
        bit 7,a
        jr nz,.uc
        cp b
        jr nc,.s1
.uc     ld a,b
.s1     cp 65
        jr c,.s2
        ld a,64
.s2     ld c,a                  ; C = start
        sub b
        ld hl,(rptr)
        ld (hl),a               ; interior length
        inc hl
        ld a,(.cmax)
        bit 7,a
        jr nz,.none
        cp 64
        jr c,.e1
        ld a,63
.e1     sub c
        jr c,.none
        inc a
        ld (hl),a               ; edge length
        inc hl
        ld (rptr),hl
        ld b,a
        add a,c
        ld (cur),a
        ; HL = ptr + t - 4*start
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,(.t)
        or a
        sbc hl,de
        ld de,(.ptr)
        add hl,de
        ld de,(eptr)
.ecl    ld a,(hl)
        ld (de),a
        inc e
        dec hl
        dec hl
        dec hl
        dec hl
        djnz .ecl
        ld (eptr),de
        ret
.none   ld (hl),0
        inc hl
        ld (rptr),hl
        ld a,c
        ld (cur),a
        ret
.ptr    dw 0
.t      dw 0
.span   db 0
.cmax   db 0

BDEF:   db 0,1,2,1              ; left class of boundaries 0..3 (0 verge 1 kerb 2 road)
        db 1,2,1,0              ; right class
        db 1,1,1,1              ; enabled

; min_s / max_s: signed byte min/max of A,B -> A
min_s:  ld c,a
        xor b
        jp m,.d
        ld a,c
        cp b
        ret c
        ld a,b
        ret
.d      bit 7,c
        ld a,c
        ret nz
        ld a,b
        ret
max_s:  ld c,a
        xor b
        jp m,.d
        ld a,c
        cp b
        ret nc
        ld a,b
        ret
.d      bit 7,c
        ld a,c
        ret z
        ld a,b
        ret

; cmp_signed: carry set if HL < DE (signed)
cmp_signed:
        ld a,h
        xor d
        jp m,.diff
        push hl
        or a
        sbc hl,de
        pop hl
        ret
.diff   bit 7,h
        scf
        ret nz
        or a
        ret

; cellof16: HL = cell number (signed) -> A = clamp(HL, -1, 64)
cellof16:
        bit 7,h
        jr nz,.neg
        ld a,h
        or a
        jr nz,.big
        ld a,l
        cp 65
        ret c
.big    ld a,64
        ret
.neg    ld a,0FFh
        ret

; cellof: HL = x (signed) -> A = clamp(x>>2, -1, 64)
cellof:
        bit 7,h
        jr nz,.neg
        ld a,h
        or a
        jr nz,.big
        ld a,l
        srl a
        srl a
        ret
.big    ld a,64
        ret
.neg    ld a,0FFh
        ret

; clamp32: HL signed -> A = clamp(HL,-32,32)
clamp32:
        bit 7,h
        jr nz,.n
        ld a,h
        or a
        jr nz,.pmax
        ld a,l
        cp 33
        ret c
.pmax   ld a,32
        ret
.n      ld a,h
        inc a
        jr nz,.nmax
        ld a,l
        cp -32
        ret nc
.nmax   ld a,-32
        ret

; --------------------------------------------------------------------------
; write_row: row (crow) of page (page): code pass + colour pass.
;   Road rows never need attributes (all bank 0); if this row last held
;   something else on this page, the attribute row is reset first.
; --------------------------------------------------------------------------
P_write_row:
write_row:
        call row_addr
        ld (raddr),hl
        call row_type_road
        ; ---- codes: interior = (rcode), edges copied from ECODE
        ld hl,(raddr)
        ld de,ECODE
        ld ix,REGLEN
        ld c,5                  ; 5 interior regions, 4 edge regions between
.pl     ld b,(ix+0)
        ld a,b
        or a
        jr z,.pe
        ld a,(rcode)
        call fillb
.pe     dec c
        jr z,.pd
        ld a,(ix+1)
        or a
        jr z,.pn
        ld b,a
        ld a,(allint)
        or a
        jr z,.cpy
        ld a,(rcode)            ; horizon row: edges filled like interior
        call fillb
        jr .pn
.cpy    ld a,(de)               ; copy edge codes
        ld (hl),a
        inc e
        inc l
        djnz .cpy
.pn     inc ix
        inc ix
        jr .pl
.pd     ; ---- colours (constant per region)
        ld a,40h
        out (PORT_08),a
        ld hl,(raddr)
        ld a,h
        add a,8
        ld h,a
        ld de,REGLEN
        ld ix,REGCOL
        ld c,9
.cl     ld a,(de)
        or a
        jr z,.cs
        ld b,a
        ld a,(ix+0)
        call fillb
.cs     inc de
        inc ix
        dec c
        jr nz,.cl
        xor a
        out (PORT_08),a
        ret


; row_type_road: ensure attribute row (crow) on (page) is all bank 0
row_type_road:
        call rowtype_ptr
        ld a,(hl)
        cp 1
        ret z
        ld (hl),1
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld hl,(raddr)
        xor a
        ld b,64
        call fillb
        ld a,X1C
        out (PORT_1C),a
        ret

; rowtype_ptr: HL -> ROWTYPE[page*16 + crow]
rowtype_ptr:
        ld a,(page)
        add a,a
        add a,a
        add a,a
        add a,a
        ld hl,crow
        add a,(hl)
        ld e,a
        ld d,0
        ld hl,ROWTYPE
        add hl,de
        ret

; row_addr: HL = VRAM + page*0400h + crow*64
row_addr:
        ld a,(crow)
        rrca
        rrca                    ; crow*64 = (crow>>2)*256 + (crow&3)*64
        ld l,a
        and 3Fh
        ld h,a
        ld a,l
        and 0C0h
        ld l,a
        ld a,(page)
        add a,a
        add a,a
        add a,high(VRAM)
        add a,h
        ld h,a
        ret

; fillb: fill B (1..64) bytes at HL with A, HL advances (unrolled)
fillb:
        push hl
        ld hl,FILL_END
        push de
        ld e,b
        ld d,0
        or a
        sbc hl,de
        sbc hl,de
        pop de
        ex (sp),hl
        ret
FILL64:
        include "../build/fill.inc"
FILL_END:
        ret

; --------------------------------------------------------------------------
; stripe_char
stripe_char:
        ld a,(crow)
        dec a                   ; rows 1..15 -> chars 0..14
        or 80h
        ld (rcode),a
        and 7Fh
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,STRIPEBUF
        add hl,de
        ex de,hl                ; DE -> buffer
        ld a,(crow)
        add a,a
        add a,a
        add a,a
        ld c,a
        ld b,high(LINEK)        ; LINEK is page aligned
        ld h,high(PHT)          ; PHT is page aligned
        ld a,8
.l      ex af,af'
        ld a,(bc)
        ld l,a
        ld a,(hl)
        or a
        jr z,.dark
        ld a,0FFh
        ld (de),a
        inc de
        ld (de),a
        jr .nx
.dark   ld a,0AAh
        ld (de),a
        inc de
        ld a,55h
        ld (de),a
.nx     inc de
        inc c
        ex af,af'
        dec a
        jr nz,.l
        ret

; blit_stripes: copy STRIPEBUF (15 chars) into PCG bank 0 chars 0..14.
;   called inside vertical blank right after the page flip.
blit_stripes:
        ld hl,STRIPEBUF
        ld de,PCGWIN
        ld bc,15*16
        ldir
        ret
