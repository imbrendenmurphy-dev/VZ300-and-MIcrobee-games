; =====================================================================
;  road.asm - pseudo-3D road: segment projection + scanline writer
;  Boundaries b = 0..NSEG are projected near-to-far with logarithm
;  tables (EXP[L(v) + LS(z)], ~1% accuracy).  Each segment is filled
;  line by line (x and half width interpolated), clipped against the
;  highest line drawn so far, so crests hide the road beyond them and
;  rises ahead climb into the sky.
; =====================================================================
T_EXPL  equ $4000
T_EXPH  equ $4400
T_LOGL  equ $4800
T_LOGH  equ $4900
T_LSL   equ $4A00
T_LSH   equ $4E00
T_WT    equ $5200
T_RW    equ $5600
T_LW    equ $5700
T_MK    equ $5800
T_LNL   equ $5900
T_LNH   equ $5A00
T_PIX   equ $5B00
T_PML   equ $5C00
T_PMR   equ $5D00
LS_X    equ 37
STRIPW  equ 48                  ; road half widths below this come from the strip cache
LODB    equ 12                  ; beyond this boundary, 2 segments per step
NZMAX   equ 800                 ; furthest z index drawn (25 segments)                  ; 64*log2(1.5): x scale = 1.5 * y scale


; ---------------------------------------------------------------- log multiply
; HL = signed value, DE = log scale (signed, biased) -> HL = signed product
plog:   bit 7,h
        jr z,plog_u
        NEGHL
        call plog_u
        NEGHL
        ret
plog_u: ld a,h                  ; normalise to 8 bits
        or a
        jr z,.n
.s:     srl h
        rr l
        ld a,e
        add a,64
        ld e,a
        jr nc,.s1
        inc d
.s1:    ld a,h
        or a
        jr nz,.s
.n:     ld a,l
        or a
        jr z,.zero
        ld h,high T_LOGL
        ld c,(hl)
        inc h
        ld b,(hl)               ; BC = 64*log2(v)
        ex de,hl
        add hl,bc               ; index
        bit 7,h
        jr nz,.zero
        ld a,h
        cp 4
        jr nc,.big
        ld de,T_EXPL
        add hl,de
        ld e,(hl)
        ld a,h
        add a,4
        ld h,a
        ld d,(hl)
        ex de,hl
        ret
.zero:  ld hl,0
        ret
.big:   ld hl,$7FFF
        ret

; ---------------------------------------------------------------- frame
draw_road:
        ld a,64
        ld (clip),a
        ld hl,0
        ld (xacc),hl
        ; dx = -(curve0 * frac) / 256  (small: done by shifts)
        ld hl,(pos_s)
        ld de,TRK_CURV
        add hl,de
        ld a,(hl)
        ld e,a
        add a,a
        sbc a,a
        ld d,a                  ; DE = curve (signed)
        ld hl,0
        ld a,(pos_f)
        ld b,8
.m:     add hl,hl
        rla
        jr nc,.m1
        add hl,de
.m1:    djnz .m
        ld l,h                  ; HL = DE*frac/256 (sign-extended)
        ld a,h
        rla
        sbc a,a
        ld h,a
        NEGHL
        ld (dxacc),hl
        ld hl,(camalt)
        ld de,CAMH
        add hl,de
        ld (camref),hl
        ld hl,(pos_s)
        ld (segp),hl
        call prj_reset
        ; zi for b=0 is clamped; b=1 -> (256-frac)>>3
        ld a,(pos_f)
        neg
        ld l,a
        ld h,0
        jr nz,.z1
        inc h                   ; frac 0 -> z = 256
.z1:    srl h
        rr l
        srl l
        srl l                   ; (256-frac)>>3 = 0..32
        ld h,0
        ld (zi),hl
        xor a
        ld (bidx),a
        ld hl,10                ; b = 0: z clamped to 80
        jr .pz
.bl:    ld hl,(zi)
.pz:    call project
        call record_k
        ld a,(bidx)
        or a
        call nz,fill_segment
        ; prev := cur
        ld hl,(cur_x)
        ld (prv_x),hl
        ld a,(cur_y)
        ld (prv_y),a
        ld a,(cur_w)
        ld (prv_w),a
        ; advance 2 segments per boundary (boundaries on even segments, so
        ; each stripe pair is one span); the first step aligns: 1 or 2
        ld b,2
        ld a,(bidx)
        or a
        jr nz,.st0
        ld a,(pos_s)
        and 1
        jr z,.st                ; even: 2 ; odd: 1 (next boundary even)
        dec b
        jr .st
.st0:   ld a,(kidx)             ; further away: 4, then 8 segments per boundary
        cp 8
        jr c,.st
        ld hl,pos_s
        add a,(hl)
        ld c,a                  ; segment number of this boundary (low bits)
        and 3
        jr nz,.st
        ld b,4
        ld a,(kidx)
        cp 16
        jr c,.st
        ld a,c
        and 7
        jr nz,.st
        ld b,8
.st:    ld a,b
        ld (lodn),a
        ld hl,kidx
        add a,(hl)
        ld (hl),a
        ld hl,(segp)
        push hl
        ld e,b
        ld d,0
        add hl,de
        ld (segp),hl
        pop hl
        ld de,TRK_CURV
        add hl,de               ; HL -> curves
        ld ix,(xacc)
        ld de,(dxacc)
.adv:   ld a,(hl)               ; x += dx ; dx += curve
        inc hl
        add ix,de
        ld c,a
        rla
        sbc a,a
        push bc
        ld b,a
        ex de,hl
        add hl,bc
        ex de,hl
        pop bc
        djnz .adv
        ld (xacc),ix
        ld (dxacc),de
        ld hl,(zi)
        ld de,32
        ld a,(bidx)
        or a
        jr z,.b1
        add hl,de
.b1:    ld a,(lodn)
        dec a
        jr z,.z2
.z3:    add hl,de
        dec a
        jr nz,.z3
.z2:    ld (zi),hl
        ld a,(bidx)
        inc a
        ld (bidx),a
        ld hl,(zi)
        ld de,-NZMAX
        add hl,de
        jr c,.done
        ld a,(clip)
        cp PANOTOP+1
        jp nc,.bl
.done:  ; open ground between the horizon and the top of the road
        ld a,(clip)
.gl:    dec a
        cp HZ+1
        ret c
        push af
        call grass_line
        pop af
        jr .gl

; ---------------------------------------------------------------- project
; HL = zi.  -> cur_w, cur_y (0..200), cur_x (signed 16)
project:
        push hl
        ld de,T_WT
        add hl,de
        ld a,(hl)
        ld (cur_w),a
        pop hl
        ld de,T_LSL
        add hl,de
        ld e,(hl)
        ld a,h
        add a,4
        ld h,a
        ld d,(hl)
        ld (cur_ls),de
        ; y = HZ + (camref - alt) * s
        ld hl,(segp)
        ld bc,TRK_ALTL
        add hl,bc
        ld c,(hl)
        ld a,h
        add a,high (TRK_ALTH-TRK_ALTL)
        ld h,a
        ld b,(hl)
        ld hl,(camref)
        or a
        sbc hl,bc
        call plog
        ld de,HZ
        add hl,de
        bit 7,h
        jr z,.yp
        xor a
        jr .ys
.yp:    ld a,h
        or a
        ld a,200
        jr nz,.ys
        ld a,l
        cp 200
        jr c,.ys
        ld a,200
.ys:    ld (cur_y),a
        ; x = 64 + 1.5 * (xacc - camx) * s
        ld hl,(xacc)
        ld de,(camx)
        or a
        sbc hl,de
        ld de,(cur_ls)
        ld a,e
        add a,LS_X
        ld e,a
        jr nc,.x1
        inc d
.x1:    call plog
        ld de,64
        add hl,de
        ld (cur_x),hl
        ret

; ---------------------------------------------------------------- segment
fill_segment:
        call maybe_ei
        ld a,(cur_y)
        ld b,a
        ld a,(clip)
        cp b
        ret c
        ret z                   ; far edge at/below the clip: hidden
        ld a,(prv_y)
        sub b
        ret c
        ret z
        ld (fs_n),a
        call seg_colours
        ld a,(fs_n)
        dec a
        jr nz,.multi
        ; one row: the far edge values, no interpolation
        ld a,(cur_y)
        ld (row),a
        cp 12
        jr nc,.o1
        ld a,12
.o1:    ld (clip),a
        ld a,(cur_y)
        cp 12
        ret c
        cp 64
        ret nc
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,BBR0
        add hl,de
        ld (rowadr),hl
        ld hl,(cur_x)
        ld (lnx+1),hl
        ld a,(cur_w)
        ld (lnw+1),a
        jp road_line
.multi: ; x step (8.8) = (cur_x - prv_x) * 256 / n
        ld hl,(cur_x)
        ld de,(prv_x)
        or a
        sbc hl,de
        call stepdiv
        ld (xstep),hl
        ld (fs_xs+1),hl
        ld a,h
        rla
        sbc a,a
        ld (fs_xh+1),a
        ld a,(cur_w)
        ld hl,prv_w
        sub (hl)
        ld l,a
        sbc a,a
        ld h,a
        call stepdiv
        ld (wstep),hl
        ld (fs_ws+1),hl
        ; first row = min(prv_y, clip) - 1 ; skip k = prv_y - row steps
        ld a,(clip)
        ld b,a
        ld a,(prv_y)
        cp b
        jr c,.r0
        ld a,b
.r0:    dec a
        ld (row),a
        ld b,a
        ld a,(prv_y)
        sub b                   ; k >= 1
        ; x = prv_x + (cur_x-prv_x)*k/n ; w likewise   (log multiply)
        ld (fs_k),a
        dec a
        jr nz,.kfar
        ; k = 1: start one step in from the near edge
        ld de,(xstep)
        ld a,d
        rla
        sbc a,a
        ld b,a
        ld a,$80
        add a,e
        ld (lnx),a
        ld a,(prv_x)
        adc a,d
        ld (lnx+1),a
        ld a,(prv_x+1)
        adc a,b
        ld (lnx+2),a
        ld a,(prv_w)
        ld h,a
        ld l,$80
        ld de,(wstep)
        add hl,de
        ld (lnw),hl
        jr .kdone
.kfar:  call kscale             ; DE = L(k) + LNS[n] - 512
        push de
        ld hl,(cur_x)
        ld de,(prv_x)
        or a
        sbc hl,de
        pop de
        push de
        call plog
        ld de,(prv_x)
        add hl,de
        ld (lnx+1),hl
        ld a,$80
        ld (lnx),a
        ld a,(cur_w)
        ld hl,prv_w
        sub (hl)
        ld l,a
        sbc a,a
        ld h,a
        pop de
        call plog
        ld a,(prv_w)
        add a,l
        ld h,a
        ld l,$80
        ld (lnw),hl
.kdone: ld a,(cur_y)
        cp 12
        jr nc,.c0
        ld a,12
.c0:    ld (clip),a
        ; row address
        ld a,(row)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,BBR0
        add hl,de
        ld (rowadr),hl
fs_lp:  ld a,(clip)
        ld b,a
        ld a,(row)
        cp b
        ret c                   ; row < clip
        call road_line
        ; next row up, step the interpolators
        ld hl,row
        dec (hl)
        ld hl,(rowadr)
        ld de,-32
        add hl,de
        ld (rowadr),hl
        ld hl,(lnx)
fs_xs:  ld de,0                 ; x step (patched)
        add hl,de
        ld (lnx),hl
        ld a,(lnx+2)
fs_xh:  adc a,0                 ; sign of the step (patched)
        ld (lnx+2),a
        ld hl,(lnw)
fs_ws:  ld de,0
        add hl,de
        ld (lnw),hl
        jr fs_lp

; HL = signed delta (16-bit), (fs_n) = lines -> HL = 8.8 step (clamped)
stepdiv:
        push hl
        ld a,(fs_n)
        ld l,a
        ld h,high T_LNL
        ld e,(hl)
        inc h
        ld d,(hl)
        pop hl
        call plog
        ret

; DE = 64*log2(k) + LNS[n] - 512  (scale for *k/n)
kscale: ld a,(fs_k)
        ld l,a
        ld h,high T_LOGL
        ld c,(hl)
        inc h
        ld b,(hl)
        ld a,(fs_n)
        ld l,a
        ld h,high T_LNL
        ld e,(hl)
        inc h
        ld d,(hl)
        ex de,hl
        add hl,bc
        ld de,-512
        add hl,de
        ex de,hl
        ret

; ---------------------------------------------------------------- colours
; patch this segment's colours into the line writer
seg_colours:
        ld hl,(segp)
        dec hl
        ld a,l
        and 2
        ld e,a                  ; stripe
        ld a,h
        add a,high TRK_FLAG
        ld h,a
        ld a,(hl)
        and 1                   ; tunnel
        ld (sc_tun),a
        add a,a
        add a,a
        ld d,a
        ld a,e
        rrca                    ; 0 / 1
        ld (sc_stripe),a
        add a,d                 ; palette index 0..5
        ld l,a
        add a,a
        add a,l                 ; *3
        add a,a                 ; *6
        ld l,a
        ld h,0
        ld de,pal_a
        add hl,de
        ld a,(hl)               ; grass (the dark/light stripe pair gives the speckle)
        ld (rl_g0+1),a
        ld (rl_cl0+1),a
        ld (rl_cr5+1),a
        ld (rl_g1+1),a
        inc hl
        inc hl
        ld a,(hl)               ; rumble
        ld (rl_cl1+1),a
        ld (rl_cl5+1),a
        ld (rl_cr0+1),a
        ld (rl_cr4+1),a
        inc hl
        ld a,(hl)               ; road
        ld (rl_cl2+1),a
        ld (rl_cl4+1),a
        ld (rl_cr1+1),a
        ld (rl_cr3+1),a
        inc hl
        ld a,(hl)               ; line
        ld (rl_cl3+1),a
        ld (rl_cr2+1),a
        inc hl
        ld a,(hl)
        ld (rl_lon+1),a         ; 0 = no centre line on this segment
        ret

; ---------------------------------------------------------------- one road line
; row (row) at (rowadr), centre lnx+1 (16-bit), half width lnw+1
        MACRO CLAMPX            ; HL signed -> A = 0..128
        ld a,h
        or a
        jr z,$+9
        rla
        sbc a,a
        cpl
        and 128
        jr $+9
        ld a,l
        cp 129
        jr c,$+4
        ld a,128
        ENDM

road_line_ns:
        ld a,1
        ld (rl_nostrip),a
        call road_line
        xor a
        ld (rl_nostrip),a
        ret
rl_nostrip: db 0
road_line:
rl_gx:  ; boundaries
        ld a,(lnw+1)
        ld c,a
        ld l,a
        ld h,high T_RW
        ld b,(hl)               ; rumble width
        inc h
        ld a,(hl)               ; centre line half width
        ld (rl_lw),a
        ld a,c
        add a,b
        jr c,rl_slow
        ld e,a                  ; w + rw
        ld hl,(lnx+1)
        ld a,h
        or a
        jr nz,rl_slow
        ld a,l
        sub e
        jr c,rl_slow              ; left rumble edge < 0
        ld (bnd+0),a
        add a,b
        ld (bnd+1),a
        ld a,l
        add a,e
        jr c,rl_slow
        cp 129
        jr nc,rl_slow
        ld (bnd+5),a
        sub b
        ld (bnd+4),a
        ; far, narrow road: copy a prepared strip
        ld a,c
        cp STRIPW
        jr nc,rl_lon
        ld a,(sc_tun)
        ld hl,rl_nostrip
        or (hl)
        ld hl,(lnx+1)
        jr nz,rl_lon
        jp rl_strip
        ; centre line
rl_lon: ld a,0
        or a
        jr z,rl_nol
        ld a,(rl_lw)
        or a
        jr z,rl_nol
        ld d,a
        ld a,l
        sub d
        ld (bnd+2),a
        ld a,l
        add a,d
        ld (bnd+3),a
        jp rl_write
rl_nol:   ld a,(bnd+1)
        ld (bnd+2),a
        ld (bnd+3),a
        jp rl_write
rl_slow:  ; edges off screen: 16-bit edges, clamped
        ld a,b
        ld (rl_rw),a
        ; road across the whole row?  (left edge <= 0 and right edge >= 128)
        ld b,0
        ld hl,(lnx+1)
        or a
        sbc hl,bc
        bit 7,h
        jr nz,.l0
        ld a,h
        or l
        jr nz,rl_sl2
.l0:    add hl,bc
        add hl,bc
        bit 7,h
        jr nz,rl_sl2
        ld a,h
        or a
        jr nz,rl_full
        ld a,l
        cp 128
        jr c,rl_sl2
rl_full: ld a,(rowadr)
        ld (sp_rl+1),a
        ld a,(rl_cl2+1)         ; road colour
        ld hl,(rowadr)
        call fill_row
        ld a,(rl_lon+1)
        or a
        ret z
        ld a,(rl_lw)
        or a
        ret z
        ld c,a
        ld b,0
        ld hl,(lnx+1)
        push hl
        or a
        sbc hl,bc
        ex de,hl
        pop hl
        add hl,bc
        ld a,(rl_cl3+1)
        jp span16
rl_sl2: ld a,(lnw+1)
        ld c,a
        ld b,0
        ld hl,(lnx+1)
        or a
        sbc hl,bc
        push hl                 ; l1
        CLAMPX
        ld (bnd+1),a
        add hl,bc
        add hl,bc               ; r1
        push hl
        CLAMPX
        ld (bnd+4),a
        ld a,(rl_rw)
        ld c,a
        pop hl
        add hl,bc
        CLAMPX
        ld (bnd+5),a
        pop hl
        or a
        sbc hl,bc
        CLAMPX
        ld (bnd+0),a
        ld a,(rl_lon+1)
        or a
        jr z,rl_snl
        ld a,(rl_lw)
        or a
        jr z,rl_snl
        ld c,a
        ld hl,(lnx+1)
        push hl
        or a
        sbc hl,bc
        CLAMPX
        ld (bnd+2),a
        pop hl
        add hl,bc
        CLAMPX
        ld (bnd+3),a
        jp rl_write
rl_snl:   ld a,(bnd+1)
        ld (bnd+2),a
        ld (bnd+3),a
        jp rl_write
rl_lw:  db 0
sc_tun: db 0
sc_stripe: db 0

; the road strip for (stripe, w, phase) from the cache in upper bank 1
; bnd+0 = left rumble edge (on screen), C = w, grass in (rl_g0+1)
rl_strip:
        ld a,(sc_stripe)
        rrca
        rrca                    ; stripe * 64
        add a,c                 ; + w
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl               ; *4
        ld a,(bnd+0)
        and 3
        or l
        ld l,a
        add hl,hl               ; *2
        ld de,STRIPS
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = strip record
        push de
        ld a,(rl_g0+1)
        ld hl,(rowadr)
        call fill_row
        pop de
        ld a,(bnd+0)
        rrca
        rrca
        and 31
        ld hl,(rowadr)
        add a,l
        ld l,a                  ; HL = first byte
        ld a,(de)
        ld c,a                  ; n
        inc de
        ld a,(de)
        ld b,a                  ; first-byte keep mask
        inc de
        ld a,(de)
        ld (.ml+1),a            ; last-byte keep mask
        inc de
        ld a,(hl)
        and b
        ex de,hl
        or (hl)
        inc hl
        ex de,hl
        ld (hl),a
        inc l
        ld a,c
        sub 2
        ret c                   ; n = 1
        jr z,.last
        ex de,hl                ; HL = source, DE = dest
        ld c,a
        ld b,0
        ldir
        ex de,hl
.last:  ld a,(hl)
.ml:    and 0
        ex de,hl
        or (hl)
        ex de,hl
        ld (hl),a
        ret

; build the strip cache for the current palette (call at section start).
; Each strip is rendered twice into the bottom back-buffer row, with grass
; $00 and $FF: the difference is the grass mask, the first is the data.
build_strips:
        ld hl,STRIPS+1024
        ld (bs_ptr),hl
        xor a
        ld (bs_s),a
.s:     ld a,(bs_s)
        ld (sc_stripe),a
        xor a
        ld (sc_tun),a
        ld hl,(pos_s)           ; palette for this stripe (as seg_colours)
        push hl
        ld a,(bs_s)
        add a,a
        ld l,a
        ld h,0
        inc hl                  ; segp-1 = 2*s  -> stripe bit = s
        ld (segp),hl
        call seg_colours
        pop hl
        ld (pos_s),hl
        xor a
        ld (bs_w),a
.w:     xor a
        ld (bs_p),a
.p:     ; table entry
        ld a,(bs_s)
        rrca
        rrca
        ld hl,bs_w
        add a,(hl)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld a,(bs_p)
        or l
        ld l,a
        add hl,hl
        ld de,STRIPS
        add hl,de
        ld de,(bs_ptr)
        ld (hl),e
        inc hl
        ld (hl),d
        ; render with grass 0 then grass $FF at pixel 8+p
        ld a,63
        ld (row),a
        ld hl,BBR0+63*32
        ld (rowadr),hl
        ld a,(bs_w)
        ld (lnw+1),a
        ld l,a
        ld h,high T_RW
        ld a,(hl)
        add a,l                 ; w + rw
        ld hl,bs_p
        add a,(hl)
        add a,8
        ld l,a
        ld h,0
        ld (lnx+1),hl
        xor a
        call .rend
        ld hl,BBR0+63*32+2
        ld de,bs_a
        ld bc,30
        ldir
        ld a,$FF
        call .rend
        ; n = bytes from byte 2 to the byte holding pixel 8+p+2(w+rw)-1
        ld a,(bs_w)
        ld l,a
        ld h,high T_RW
        add a,(hl)
        add a,a                 ; 2(w+rw)
        ld hl,bs_p
        add a,(hl)
        add a,7
        rrca
        rrca
        and 63
        ld b,a                  ; n
        or a
        jr nz,.n1
        inc b
.n1:    ld hl,(bs_ptr)
        ld (hl),b
        inc hl
        ; masks
        ld a,(BBR0+63*32+2)
        ld de,bs_a
        ex de,hl
        xor (hl)
        ex de,hl
        ld (hl),a               ; first keep mask
        inc hl
        push hl
        ld a,b
        dec a
        ld e,a
        ld d,0
        ld hl,BBR0+63*32+2
        add hl,de
        ld a,(hl)
        ld hl,bs_a
        add hl,de
        xor (hl)
        pop hl
        ld (hl),a               ; last keep mask
        inc hl
        ex de,hl
        ld hl,bs_a
        ld c,b
        ld b,0
        ldir                    ; data (grass = 0)
        ld (bs_ptr),de
        ld hl,bs_p
        inc (hl)
        ld a,(hl)
        cp 4
        jp c,.p
        ld hl,bs_w
        inc (hl)
        ld a,(hl)
        cp STRIPW
        jp c,.w
        ld hl,bs_s
        inc (hl)
        ld a,(hl)
        cp 2
        jp c,.s
        ret
.rend:  ld (rl_g0+1),a
        ld (rl_cl0+1),a
        ld (rl_cr5+1),a
        ld (rl_g1+1),a
        jp road_line_ns         ; (no strip shortcut while building)
bs_ptr: dw 0
bs_s:   db 0
bs_w:   db 0
bs_p:   db 0
bs_a:   ds 32
rl_rw:  db 0
bnd:    ds 6

        include "../build/rline.asm"

; open-ground line between the horizon and a far crest
grass_line:
        ld (row),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,BBR0
        add hl,de
        ld a,(row)
        rra
        ld a,(pal_a)
        jr nc,.e
        ld a,(pal_a+1)
.e:     ; fall into fill_row

; fill 32 bytes at HL (row start) with A: 16 PUSHes with the stack
; pointed at the row (interrupts held off for ~250 T)
fill_row:
        ld e,a
        ld d,a
        ld bc,32
        add hl,bc
        ld a,i                  ; P/V = interrupts were enabled
        di
        ld (fr_sp),sp
        ld sp,hl
        ex de,hl
        REPT 16
        push hl
        ENDR
        ld sp,(fr_sp)
        ret po
        ei
        ret
fr_sp:  dw 0

; span: pixels E (x0) .. C (x1, exclusive), 0..128, colour byte B,
; on row (rowadr) (row low byte patched into sp_rl)
span:   ld a,e
        cp c
        ret nc
        ld d,high T_PIX
        ld a,(de)               ; idx0
        ld hl,(rowadr)
        add a,l
        ld l,a
        inc d
        ld a,(de)               ; mask: pixels >= x0
        ld e,c
        ld c,a
        dec d
        ld a,(de)               ; idx1
sp_rl:  add a,0
        sub l                   ; bytes from first to last
        ex af,af'
        inc d
        inc d
        ld a,(de)
        ld d,a                  ; mask: pixels < x1 (0 if aligned)
        ex af,af'
        jr z,.one
        ld e,a
        ld a,(hl)               ; first byte
        xor b
        and c
        xor (hl)
        ld (hl),a
        inc l
        dec e
        jr z,.last
        ld a,e
        add a,a
        neg
        add a,62
        ld (.jr+1),a
.jr:    jr $+2
        REPT 31
        ld (hl),b
        inc l
        ENDR
.last:  ld a,d
        or a
        ret z
        ld a,(hl)
        xor b
        and d
        xor (hl)
        ld (hl),a
        ret
.one:   ld a,c
        and d
        ld c,a
        ld a,(hl)
        xor b
        and c
        xor (hl)
        ld (hl),a
        ret

; ---------------------------------------------------------------- palettes
; grass even row, grass odd row, rumble, road, line, line on?
pal_a:  db $00,$00,$FF,$AA,$AA,0        ; dark stripe: green, red rumble, blue road
pal_b:  db $04,$40,$55,$AA,$55,1        ; light stripe: speckled green, yellow rumble + line
        db 0,0,0,0,0,0
        db 0,0,0,0,0,0
pal_t:  db $FF,$FF,$FF,$AA,$AA,0        ; tunnel: walls
        db $DD,$77,$55,$AA,$55,1
