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
        call vbpoll
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
        ld iy,PTS+8             ; point records: sy, sx, sw (words), phase
        ; point loop -------------------------------------------------------
.kl     call vbpoll
        ld a,(maxy)             ; occlusion line in front of this point (traffic)
        ld (iy+7),a
        ; advance PSTEP[p] segments, accumulating the curve
        ld a,(kk)
        ld e,a
        ld d,0
        ld hl,PSTEP
        add hl,de
        ld b,(hl)               ; 1 or 2 segments to this point
        ld a,(kseg)
        ld c,a
        add a,b
        ld (kseg),a
        ld a,(seg)
        add a,c
        ld c,a                  ; first segment of the strip
        ld a,b
        ld b,high(TRK_CURVE)    ; TRK_CURVE is page aligned
        ld hl,(DXK)
        ld de,(XK)
.st     ex af,af'
        ld a,(bc)
        inc c
        push bc
        ld c,a
        rlca
        sbc a,a
        ld b,a
        add hl,bc               ; DXK += curve
        ex de,hl
        add hl,de               ; XK += DXK
        ex de,hl
        pop bc
        ex af,af'
        dec a
        jr nz,.st
        ld (DXK),hl
        ld (XK),de
        ld a,c
        ld (sk),a
        ; band phase of the last segment of this strip: bands are 2 segments
        dec a
        and 2
        ld (iy+6),a
        ; table index = p*32 + fq
        ld a,(kk)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(fq)
        or l
        ld l,a
        push hl
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
        ld (iy+0),l
        ld (iy+1),h
        ; sx = 128 + (XK - camX) * inv >> 14
        ld hl,(XK)
        ld de,(camX)
        or a
        sbc hl,de
        call mulinv
        ld de,128
        add hl,de
        ld (iy+2),l
        ld (iy+3),h
        ; sw = HWT[idx]
        pop hl
        ld de,HWTL
        add hl,de
        ld a,(hl)
        ld (iy+4),a
        ld de,HWTH-HWTL
        add hl,de
        ld a,(hl)
        ld (iy+5),a
        ; p == 1: virtual point 0 well below the screen
        ld a,(kk)
        dec a
        jr nz,.nv
        push iy
        pop hl
        ld de,PTS+2
        inc hl
        inc hl
        ld bc,5
        ldir
        ld hl,400
        ld (PTS),hl
.nv     ; visible?  sy < maxy (signed)
        ld l,(iy+0)
        ld h,(iy+1)
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
        ld a,(kk)               ; D = band phase offset of this strip (0 / 10)
        ld e,a
        ld a,(iy+6)             ; 0 or 2
        ld d,a
        add a,a
        add a,a
        add a,d
        ld d,a
        ld l,c                  ; LPH[y] = phase*10, LPH2[y] = phase*2, every line
        ld h,high(LPH)
        ld a,(iy+6)
        push bc
.fl     ld (hl),d
        inc h
        ld (hl),a
        dec h
        inc l
        djnz .fl
        pop bc
        ld a,c                  ; LINEK[y] = point, only on lines 8r and 127
        add a,b                 ;   (the only lines line_geom samples)
        ld b,a                  ; end (exclusive)
        ld h,high(LINEK)
        ld a,c
        add a,7
        and 0F8h
.lk     cp b
        jr nc,.l127
        ld l,a
        ld (hl),e
        add a,8
        jr .lk
.l127   ld a,b
        cp 128                  ; range reaches line 127?
        jr nz,.ldone
        ld l,127
        ld (hl),e
.ldone  ld a,c
        or a
        jp z,.done
.next   ld de,8
        add iy,de
        ld hl,kk
        inc (hl)
        ld a,(hl)
        cp NSEG+1
        jp c,.kl
.done   ld a,(kk)               ; last point with a valid record
        cp NSEG+1
        jr c,.km
        ld a,NSEG
.km     ld (kmax),a
        ld a,(maxy)
        ld (LTOP),a
        ld b,a                  ; lines above the horizon in its row: sky phase
        and 7
        ret z
        ld c,a
        ld a,b
        sub c
        ld l,a
        ld h,high(LPH)
        ld b,c
.sk     ld (hl),20
        inc h
        ld (hl),4
        dec h
        inc l
        djnz .sk
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
        ld h,high(LINEK)
        ld l,(hl)               ; point k
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PTS
        add hl,de
        push hl
        pop ix                  ; IX -> record k, IX-8 -> record k-1
        ld c,(ix+0)
        ld b,(ix+1)             ; BC = SY[k]
        ld l,(ix-8)
        ld h,(ix-7)             ; HL = SY[k-1]
        push hl
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
        ld l,(ix-6)
        ld h,(ix-5)
        ld e,(ix+2)
        ld d,(ix+3)
        call lerp
        ld (lcx),hl
        ld l,(ix-4)
        ld h,(ix-3)
        ld e,(ix+4)
        ld d,(ix+5)
        ld a,(.f)
        call lerp
        ld (lhw),hl
        ret
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
        ; kerbs are off since v6 (they cost ~9% of the frame): every row is
        ; verge | road | verge.  The kerb boundaries are still computed by
        ; bounds_at and are absorbed into the verge here (merge state 3).
        ld a,3
        ld (mstate),a
        xor a
        ld (cur),a
        ld hl,EPTRS
        ld (eprp),hl
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
        ld hl,(eprp)
        inc hl
        inc hl
        ld (eprp),hl
        pop af
        ret

; bnd: A = boundary index -> one interior region and one edge region,
;   plus EPTRS[k] -> mask index of the edge region's first cell (walk down)
bnd:
        add a,a
        add a,low(BX0)          ; BX0/BX8 sit in one page
        ld l,a
        ld h,high(BX0)
        ld c,(hl)
        inc l
        ld b,(hl)               ; BC = x0
        ld a,l
        add a,7
        ld l,a
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a                  ; HL = x8
        or a
        sbc hl,bc               ; slope = x8 - x0, clamp to -32..32 -> 0..64
        ld a,l
        add a,32
        ld e,a
        ld a,h
        or a
        jr nz,.sneg
        ld a,l
        cp 33
        ld a,e
        jr c,.sok
        ld a,64
        jr .sok
.sneg   inc a                   ; H = FF and L >= E0 -> in range
        jr nz,.smin
        ld a,l
        cp 0E0h
        ld a,e
        jr nc,.sok
.smin   xor a
.sok    ld l,a
        ld h,high(SLOPETAB)
        ld l,(hl)               ; slope*10 -> directory entry
        ld h,high(EDGE_DIR)
        ld a,(hl)               ; omin (signed)
        inc l
        ld e,(hl)               ; span
        inc l
        push hl                 ; -> sub-table pointers
        ld l,a
        rlca
        sbc a,a
        ld h,a                  ; HL = omin
        ld a,c                  ; HL = t = x0 - omin
        sub l
        ld l,a
        ld a,b
        sbc a,h
        ld h,a
        ld a,l
        and 3
        ld d,a                  ; D = r = t & 3 (sub-table)
        sra h
        rr l
        sra h
        rr l                    ; HL = q = t >> 2
        push hl
        call cellof16
        ld c,a                  ; C = cmax (clamped -1..64)
        ld a,d                  ; cmin = q - ((span + 3 - r) >> 2) + 1
        cpl
        and 3
        add a,e
        rra
        srl a
        ld e,a
        pop hl
        push hl
        ld a,l
        sub e
        ld l,a
        jr nc,.nb
        dec h
.nb     inc hl
        call cellof16
        ld b,a                  ; B = cmin (clamped)
        ld a,(cur)              ; start = clamp(max(cmin,cur), cur..64)
        ld e,a
        ld a,b
        bit 7,a
        jr nz,.uc
        cp e
        jr nc,.s1
.uc     ld a,e
.s1     cp 65
        jr c,.s2
        ld a,64
.s2     ld b,a                  ; B = start
        sub e
        ld hl,(rptr)
        ld (hl),a               ; interior length
        inc hl
        ld a,c
        bit 7,a
        jr nz,.none
        cp 64
        jr c,.e1
        ld a,63
.e1     sub b
        jr c,.none
        inc a
        ld (hl),a               ; edge length
        inc hl
        ld (rptr),hl
        add a,b
        ld (cur),a
        pop hl                  ; EPTRS[k] = sub[r] + q - start
        ld a,l
        sub b
        ld c,a
        ld a,h
        sbc a,0
        ld b,a
        pop hl
        ld a,d
        add a,a
        add a,l
        ld l,a
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        add hl,bc
        ex de,hl
        ld hl,(eprp)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (eprp),hl
        ret
.none   ld (hl),0
        inc hl
        ld (rptr),hl
        ld a,b
        ld (cur),a
        pop hl
        pop hl
        ld hl,(eprp)
        inc hl
        inc hl
        ld (eprp),hl
        ret

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
; Road rows.  Every road row of the hidden page gets its own characters in
; that page's dynamic PCG banks (32 slots per row):
;   slot 0..2   interior verge / kerb / road for this row's band phases
;   slot 3..    edge cells (mask x left/right surface) and car cells
; Codes are written every frame; attribute and colour RAM only when the
; row changes type (so road rows cost no colour writes at all).
; --------------------------------------------------------------------------

; row_bank: A = PCG bank of row (crow) on page (page): 1 + 4p + (crow-1)/4
;           also sets (sbase) = slot base ((crow-1)&3)*32
row_bank:
        ld a,(crow)
        dec a
        ld b,a
        and 3
        rrca
        rrca
        rrca                    ; *32
        ld (sbase),a
        ld a,b
        rrca
        rrca
        and 3
        ld b,a
        ld a,(page)
        add a,a
        add a,a
        add a,b
        inc a
        ld (rbank),a
        ret

DIV5:   db 0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,4
UNICODE equ 80h+122             ; uniform interiors: code UNICODE + 2*surface + light

; init_uniform: build the 6 uniform interior characters in banks 1..8
;   and their slot records (mask 0, surface page)
init_uniform:
        ld c,1                  ; bank
.bk     ld a,c
        or X1C
        out (PORT_1C),a
        push bc
        ld e,0                  ; e = 2*surface + phase
.ch     push de
        ld a,e                  ; phase offset for all 8 lines
        and 1
        ld a,0
        jr z,.p0
        ld a,10
.p0     ld hl,PHOFF
        ld b,8
.pf     ld (hl),a
        inc hl
        djnz .pf
        call patch_gen
        pop de
        push de
        ld a,e
        add a,UNICODE
        ld l,a                  ; record for car rows
        ld h,high(SLOTMASK)
        ld (hl),0
        inc h
        ld a,e
        srl a
        push hl
        ld l,a
        ld h,0
        ld bc,INTPAGE
        add hl,bc
        ld a,(hl)
        pop hl
        ld (hl),a               ; SLOTPAGE[code] = page of the surface
        ld b,high(MASKLIB)
        ld c,0
        push af
        ld a,e                  ; DE = PCGWIN + (122 + e) * 16
        add a,122
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PCGWIN
        add hl,de
        ex de,hl
        pop af
        ld h,a
        call cellgen
        pop de
        inc e
        ld a,e
        cp 6
        jr c,.ch
        pop bc
        inc c
        ld a,c
        cp 9
        jr c,.bk
        ld a,X1C
        out (PORT_1C),a
        ret

; slot_ptr: A = slot -> DE = PCG address, A = screen code   (bank selected)
slot_ptr:
        ld hl,sbase
        add a,(hl)
        ld e,a
        or 80h
        push af
        ld a,e
        ld d,0
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PCGWIN
        add hl,de
        ex de,hl
        pop af
        ret

; set_phases: band phase of the 8 lines of row (crow), patched into
; cellgen / cellcomp as RES offsets (phase*10): 0 dark, 1 light, 2 sky
set_phases:
        ld a,(crow)             ; copy LPH[crow*8 .. +7] -> PHOFF
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,high(LPH)
        ld de,PHOFF
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ; patch the immediates of cellgen from PHOFF
patch_gen:
        ld hl,PHOFF
        ld a,(hl)
        ld (cellgen.p0+1),a
        inc l
        ld a,(hl)
        ld (cellgen.p1+1),a
        inc l
        ld a,(hl)
        ld (cellgen.p2+1),a
        inc l
        ld a,(hl)
        ld (cellgen.p3+1),a
        inc l
        ld a,(hl)
        ld (cellgen.p4+1),a
        inc l
        ld a,(hl)
        ld (cellgen.p5+1),a
        inc l
        ld a,(hl)
        ld (cellgen.p6+1),a
        inc l
        ld a,(hl)
        ld (cellgen.p7+1),a
        ret

; patch_comp: copy the current PHOFF into cellcomp, and line*6+phase*2 into carroad
patch_comp:
        ld a,(crow)             ; carroad offsets: line*6 + LPH2[line]
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,high(LPH2)
        ld a,(hl)
        ld (carroad.p0+1),a
        inc l
        ld a,(hl)
        add a,6
        ld (carroad.p1+1),a
        inc l
        ld a,(hl)
        add a,12
        ld (carroad.p2+1),a
        inc l
        ld a,(hl)
        add a,18
        ld (carroad.p3+1),a
        inc l
        ld a,(hl)
        add a,24
        ld (carroad.p4+1),a
        inc l
        ld a,(hl)
        add a,30
        ld (carroad.p5+1),a
        inc l
        ld a,(hl)
        add a,36
        ld (carroad.p6+1),a
        inc l
        ld a,(hl)
        add a,42
        ld (carroad.p7+1),a

        ld hl,PHOFF
        ld a,(hl)
        ld (cellcomp.p0+1),a
        inc l
        ld a,(hl)
        ld (cellcomp.p1+1),a
        inc l
        ld a,(hl)
        ld (cellcomp.p2+1),a
        inc l
        ld a,(hl)
        ld (cellcomp.p3+1),a
        inc l
        ld a,(hl)
        ld (cellcomp.p4+1),a
        inc l
        ld a,(hl)
        ld (cellcomp.p5+1),a
        inc l
        ld a,(hl)
        ld (cellcomp.p6+1),a
        inc l
        ld a,(hl)
        ld (cellcomp.p7+1),a
        ret

; --------------------------------------------------------------------------
; cellgen: build one road character.
;   BC = MASKLIB page : mask index (lines on consecutive pages), H = RES page of the surface
;   pair, DE -> destination (16-aligned).  Per scanline: RES[phase][mval][s]
; --------------------------------------------------------------------------
cellgen:
        ld a,(bc)
        inc b
.p0     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p1     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p2     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p3     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p4     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p5     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p6     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p7     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        ret

; cellcomp: as cellgen, but composites a car cell over the ground:
;   out = (ground & notmask) | ink,  IX -> 32 bytes (notmask, ink) x 16
cellcomp:
        ld a,(bc)
        inc b
.p0     add a,0
        ld l,a
        ld a,(hl)
        and (ix+0)
        or (ix+1)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        and (ix+2)
        or (ix+3)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p1     add a,0
        ld l,a
        ld a,(hl)
        and (ix+4)
        or (ix+5)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        and (ix+6)
        or (ix+7)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p2     add a,0
        ld l,a
        ld a,(hl)
        and (ix+8)
        or (ix+9)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        and (ix+10)
        or (ix+11)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p3     add a,0
        ld l,a
        ld a,(hl)
        and (ix+12)
        or (ix+13)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        and (ix+14)
        or (ix+15)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p4     add a,0
        ld l,a
        ld a,(hl)
        and (ix+16)
        or (ix+17)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        and (ix+18)
        or (ix+19)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p5     add a,0
        ld l,a
        ld a,(hl)
        and (ix+20)
        or (ix+21)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        and (ix+22)
        or (ix+23)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p6     add a,0
        ld l,a
        ld a,(hl)
        and (ix+24)
        or (ix+25)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        and (ix+26)
        or (ix+27)
        ld (de),a
        inc e
        ld a,(bc)
        inc b
.p7     add a,0
        ld l,a
        ld a,(hl)
        and (ix+28)
        or (ix+29)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        and (ix+30)
        or (ix+31)
        ld (de),a
        ret

; carroad: car cell over plain road from the pre-composited table.
;   HL -> 64-byte block (64-aligned), DE -> destination.  The 8 immediates
;   (line*6 + phase*2) are patched per row by patch_comp.
carroad:
        ld c,l
        ld a,c
.p0     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,c
.p1     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,c
.p2     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,c
.p3     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,c
.p4     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,c
.p5     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,c
.p6     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        inc e
        ld a,c
.p7     add a,0
        ld l,a
        ld a,(hl)
        ld (de),a
        inc e
        inc l
        ld a,(hl)
        ld (de),a
        ret

; --------------------------------------------------------------------------
; write_row: road row (crow) of the hidden page
; --------------------------------------------------------------------------
P_write_row:
write_row:
        call row_addr
        ld (raddr),hl
        call row_bank
        call row_type_road
        call set_phases
        call vbpoll
        ld a,(rbank)
        or X1C
        out (PORT_1C),a
        ; interior characters.  A row lying wholly in one band uses the
        ; uniform characters prebuilt in every dynamic bank (codes FA..FF)
        ld hl,PHOFF
        ld a,(hl)
        cp 20
        jr z,.nonuni
        ld b,7
.uc     inc l
        cp (hl)
        jr nz,.nonuni
        djnz .uc
        or a                    ; 0 dark / 10 light
        ld a,UNICODE
        jr z,.ud
        inc a
.ud     ld (ICODE+0),a
        ld (rbase),a
        add a,2
        ld (ICODE+1),a
        add a,2
        ld (ICODE+2),a
        ld a,1
        ld (unif),a
        jr .igdone
.nonuni xor a
        ld (unif),a
        ld a,(sbase)
        or 80h
        ld (rbase),a
        ld b,0
.ig     push bc
        ld a,b
        call slot_ptr
        ld hl,ICODE
        ld c,b
        ld b,0
        add hl,bc
        ld (hl),a
        ld hl,INTPAGE
        add hl,bc
        ld b,(hl)               ; page
        ld l,a                  ; record: SLOTMASK[code] = 0, SLOTPAGE[code] = page
        ld h,high(SLOTMASK)
        ld (hl),0
        inc h
        ld (hl),b
        ld h,b
        ld bc,MASKLIB           ; mask 0 = all left (index 0)
        call cellgen
        pop bc
        inc b
        ld a,b
        cp 3
        jr c,.ig
.igdone call vbpoll
        ; slot records are only needed under the cars
        ld a,(crow)
        ld e,a
        ld d,0
        ld hl,RECROW
        add hl,de
        bit 0,(hl)
        jr z,.norec
        ld hl,16D5h             ; PUSH DE / LD D,n
        jr .setrec
.norec  ld hl,0918h             ; JR $+11
.setrec ld (.rec),hl
        ; edge slot allocator
        ld a,3
        call slot_ptr
        ld (sdest),de
        ld (scode),a
        ld a,(crow)             ; car rows keep 10 slots for the car
        cp CAR_ROW
        ld a,19
        jr nc,.lim
        ld a,(crow)             ; the 4th row of a bank gives 6 slots to the
        dec a                   ; uniform characters
        and 3
        cp 3
        ld a,29
        jr nz,.lim
        ld a,23
.lim    ld (sleft),a
        ; region table row for this merge state and code layout:
        ;   RT[mstate][uniform]: 5 interior surfaces (*k), 4 edge RES pages,
        ;   4 fallback surfaces (*k); codes = rbase + entry
        ld a,(mstate)
        add a,a
        ld hl,unif
        or (hl)                 ; *2 + uniform
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        add hl,de
        add hl,de
        add hl,de
        add hl,de               ; *13
        ld de,RT
        add hl,de
        push hl
        pop iy
        ld hl,EPTRS
        ld (eprp),hl
        ld hl,(raddr)           ; HL = screen pointer for the whole pass
        ld ix,REGLEN
        ld b,(ix+0)             ; region 0: interior
        ld a,b
        or a
        jr z,.r0
        ld a,(rbase)
        add a,(iy+0)
        call fillb
.r0     ld a,4
        ld (.j),a
.pl     ld a,(ix+1)             ; edge region j
        or a
        jp z,.pn
        push ix
        push hl
        ld b,a                  ; cells in this edge region
        ld a,(iy+5)             ; RES page of the pair
        ld (.pgi+1),a
        ld (.pgs+1),a
        ld a,(rbase)            ; fallback code when out of slots
        add a,(iy+9)
        ld (.fb),a
        ld a,(sleft)            ; n = min(cells, slots left)
        cp b
        jr c,.few
        sub b
        ld (sleft),a
        ld c,0                  ; no fallback cells
        jr .go
.few    ld c,a                  ; n = sleft, fallback = cells - n
        ld a,b
        sub c
        ld b,c
        ld c,a
        xor a
        ld (sleft),a
.go     ld a,c
        ld (.nfb),a
        ld a,b
        or a
        jr z,.nogen
        ld a,(scode)
        ld c,a                  ; alt set: B count, C code, DE -> masks, HL -> screen
        pop hl
        push bc
        exx
        pop bc
        ld hl,(eprp)            ; DE -> mask index of the first cell (walk down)
        ld e,(hl)
        inc hl
        ld d,(hl)
        exx
        push hl
        exx
        pop hl
        exx
        ld de,(sdest)
        exx
.ecl    ld a,(de)               ; mask index
        dec de
        ld (hl),c               ; screen code of the next slot
        inc hl
.rec    push de                 ; record SLOTMASK[code], SLOTPAGE[code] (car rows;
        ld d,high(SLOTMASK)     ;  other rows patch a JR over these 11 bytes)
        ld e,c
        ex de,hl
        ld (hl),a
        inc h
.pgs    ld (hl),0               ; RES page (patched)
        ex de,hl
        pop de
        inc c
        exx
        ld c,a                  ; BC = mask (page of line 0 : index)
        ld b,high(MASKLIB)
.pgi    ld h,0                  ; RES page of the pair (patched)
        call cellgen
        inc de
        exx
        djnz .ecl
        ld a,c
        ld (scode),a
        push hl                 ; screen pointer back to the main set
        exx
        ld (sdest),de
        pop hl
        push hl
.nogen  pop hl
        ld a,(.nfb)             ; out of slots: plain interior cells
        or a
        jr z,.efin
        ld b,a
        ld a,(.fb)
        call fillb
.efin   pop ix
.pn     push hl
        call vbpoll
        ld hl,(eprp)
        inc hl
        inc hl
        ld (eprp),hl
        pop hl
        ld b,(ix+2)             ; interior region after edge j
        ld a,b
        or a
        jr z,.pi
        ld a,(rbase)
        add a,(iy+1)
        call fillb
.pi     inc ix
        inc ix
        inc iy
        ld a,(.j)
        dec a
        ld (.j),a
        jp nz,.pl
.done   ld a,X1C
        out (PORT_1C),a
        call traffic_row        ; rival cars on this row
        ld a,(crow)             ; car rows: remember what lies under the car
        cp CAR_ROW
        ret c
        jp car_under
.fb     db 0
.nfb    db 0
.j      db 0

; car_under: for car row (crow) record, for columns CAR_COL..CAR_COL+9,
;   the RES page and mask index of the ground cell -> CUNDER[(row-13)*20],
;   read back from the codes just written and the per-code slot records.
car_under:
        ld a,(crow)
        sub CAR_ROW
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,a
        add a,a                 ; *20
        ld e,a
        ld d,0
        ld hl,CUNDER
        add hl,de
        ex de,hl                ; DE -> output
        ld hl,(raddr)
        ld bc,CAR_COL
        add hl,bc
        ld b,10
.c      ld a,(hl)               ; screen code
        inc hl
        push hl
        ld l,a
        ld h,high(SLOTPAGE)
        ld a,(hl)
        ld (de),a
        inc de
        dec h
        ld a,(hl)
        ld (de),a
        inc de
        pop hl
        djnz .c
        ; remember the next free slot for the car cells
        ld a,(crow)
        sub CAR_ROW
        ld e,a
        ld d,0
        ld hl,CSLOT
        add hl,de
        ld a,(scode)
        ld (hl),a
        ld hl,CSDEST
        add hl,de
        add hl,de
        ld bc,(sdest)
        ld (hl),c
        inc hl
        ld (hl),b
        ret

; region tables per kerb-merge state (bit0 left merged, bit1 right merged)
; interior surfaces of regions 0,2,4,6,8 ; pairs of edge regions 1,3,5,7
INTS:   db 0,1,2,1,0
        db 0,0,2,1,0
        db 0,1,2,0,0
        db 0,0,2,0,0
EPAIRS: db 0,1,2,3
        db 0,4,2,3
        db 0,1,5,3
        db 0,4,5,3
INTPAGE: db high(RESPAGES)+0, high(RESPAGES)+1, high(RESPAGES)+2   ; pair whose left = surface
PAIRPAGE: db high(RESPAGES)+0, high(RESPAGES)+1, high(RESPAGES)+2
        db high(RESPAGES)+3, high(RESPAGES)+4, high(RESPAGES)+5
PAIRLEFT: db 0,1,2,1,0,2

; RT[mstate][uniform] (13 bytes): interior surfaces of regions 0,2,4,6,8
; (times k = 1, or 2 for the uniform layout), RES pages of edge regions
; 1,3,5,7, fallback (left) surfaces of those edges (times k)
RT:
        db 0,1,2,1,0,high(RESPAGES)+0,high(RESPAGES)+1,high(RESPAGES)+2,high(RESPAGES)+3,0,1,2,1
        db 0,2,4,2,0,high(RESPAGES)+0,high(RESPAGES)+1,high(RESPAGES)+2,high(RESPAGES)+3,0,2,4,2
        db 0,0,2,1,0,high(RESPAGES)+0,high(RESPAGES)+4,high(RESPAGES)+2,high(RESPAGES)+3,0,0,2,1
        db 0,0,4,2,0,high(RESPAGES)+0,high(RESPAGES)+4,high(RESPAGES)+2,high(RESPAGES)+3,0,0,4,2
        db 0,1,2,0,0,high(RESPAGES)+0,high(RESPAGES)+1,high(RESPAGES)+5,high(RESPAGES)+3,0,1,2,1
        db 0,2,4,0,0,high(RESPAGES)+0,high(RESPAGES)+1,high(RESPAGES)+5,high(RESPAGES)+3,0,2,4,2
        db 0,0,2,0,0,high(RESPAGES)+0,high(RESPAGES)+4,high(RESPAGES)+5,high(RESPAGES)+3,0,0,2,1
        db 0,0,4,0,0,high(RESPAGES)+0,high(RESPAGES)+4,high(RESPAGES)+5,high(RESPAGES)+3,0,0,4,2


; row_type_road: when row (crow) of (page) was not a road row, set its
; attribute row to the row's bank and its colour row to the ground colour
row_type_road:
        call rowtype_ptr
        ld a,(hl)
        cp 1
        ret z
        ld (hl),1
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld hl,(raddr)
        ld a,(rbank)
        ld b,64
        call fillb
        ld a,X1C
        out (PORT_1C),a
        ld a,40h
        out (PORT_08),a
        ld hl,(raddr)
        ld a,h
        add a,8
        ld h,a
        ld a,(crow)
        ld e,a
        ld d,0
        push hl
        ld hl,ROWCOL
        add hl,de
        ld a,(hl)
        pop hl
        ld b,64
        call fillb
        xor a
        out (PORT_08),a
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
        rrca
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
