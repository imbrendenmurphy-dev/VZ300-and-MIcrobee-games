; ---------------------------------------------------------------------
;  Ground grid, drawn straight in screen space (no 3D clipping).
;  A ground line x = k seen from eye height H lies in the plane through
;  the eye with world normal (H, k-px, 0); a line z = k uses (0, k-pz, H).
;  Turned into view space (u row already squashed for the 4:3 screen,
;  so r and f are scaled by s^2 = 0.453 instead) that normal N gives the
;  screen line  Nr*X + Nu*Y + 256*Nf = 0  (X = sx-256, Y = 64-sy).
;  The visible part is the part below the horizon, which starts at the
;  line's vanishing point.  Lines lying on the horizon are skipped.
; ---------------------------------------------------------------------
ggrid:
        ld hl,(alt)             ; H = eye height in half metres
        add hl,hl
        ld a,(altf)
        rlca
        and 1
        ld e,a
        ld d,0
        add hl,de
        inc hl
        inc hl
        inc hl
        inc hl
        ld (gH),hl
        ; far limit: keep ground nearer than ~6.5 km, i.e. at least
        ; gT = H*0.078 (in gval units) below the horizon
        srl h
        rr l
        srl h
        rr l
        ld d,h
        ld e,l                  ; H/4
        srl d
        rr e
        srl d
        rr e                    ; H/16
        ld h,d
        ld l,e
        srl d
        rr e
        srl d
        rr e                    ; H/64
        add hl,de
        ld a,h
        or l
        jr nz,ggt1
        inc hl
ggt1:   ld (gT),hl
        ; ---- north-south lines (x = k)
        ld hl,(px)
        ld a,(pxf)
        call gfirst
        ld hl,m00               ; H -> column 0, k-px -> column 1
        call gfam
        ; ---- east-west lines (z = k)
        ld hl,(pz)
        ld a,(pzf)
        call gfirst
        ld hl,m02               ; H -> column 2, k-pz -> column 1
        jp gfam

; HL = position (m), A = fraction -> (gd) = first line offset, half m
; first line = (pos & F800h) - 4096 m
gfirst: rlca
        and 1
        ld e,a
        ld d,0
        ld a,h
        and 07h
        ld h,a
        add hl,hl
        add hl,de
        ld de,8192
        add hl,de
        call neghl
        ld (gd),hl
        ret

; HL -> column for H.  Five lines, 2 km (4096 half m) apart.
gfam:   ld (gcolh),hl
        ld a,5
        ld (gfcnt),a
gfm1:   call vbpoll
        ld hl,(gH)
        ld de,(gd)
        call gnorm
        ld hl,(gcolh)
        ld de,m01
        call gcomb
        call gline
        ld hl,(gd)
        ld de,4096
        add hl,de
        ld (gd),hl
        ld hl,gfcnt
        dec (hl)
        jr nz,gfm1
        ret

; HL = H (>0), DE = d -> (ga),(gb) 8-bit, larger magnitude 64..127
gnorm:  ld (gnh),hl
        ld (gnd),de
gn0:    ld hl,(gnd)
        bit 7,h
        call nz,neghl
        ld de,(gnh)
        or a
        sbc hl,de
        add hl,de
        jr nc,gn1
        ex de,hl
gn1:    ld a,h
        or a
        jr nz,gnsr
        ld a,l
        cp 128
        jr nc,gnsr
        cp 64
        jr nc,gndone
        ld hl,(gnh)
        add hl,hl
        ld (gnh),hl
        ld hl,(gnd)
        add hl,hl
        ld (gnd),hl
        jr gn0
gnsr:   ld hl,(gnh)
        sra h
        rr l
        ld (gnh),hl
        ld hl,(gnd)
        sra h
        rr l
        ld (gnd),hl
        jr gn0
gndone: ld a,(gnh)
        ld (ga),a
        ld a,(gnd)
        ld (gb),a
        ret

; gN[i] = P[i]*ga + Q[i]*gb   (HL -> column P, DE -> column Q)
gcomb:  ld (gpp),hl
        ld (gqp),de
        ld hl,gN
        ld (gnp),hl
        ld a,3
        ld (gci),a
gcm1:   ld hl,(gpp)
        ld b,(hl)
        inc hl
        ld (gpp),hl
        ld a,(ga)
        call smul8
        push hl
        ld hl,(gqp)
        ld b,(hl)
        inc hl
        ld (gqp),hl
        ld a,(gb)
        call smul8
        pop de
        add hl,de
        ex de,hl
        ld hl,(gnp)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (gnp),hl
        ld hl,gci
        dec (hl)
        jr nz,gcm1
        ret

; A * B (signed, |x| <= 127) -> HL, quarter-square table
smul8:  ld c,a
        xor b
        push af
        ld a,c
        or a
        jp p,smu1
        neg
smu1:   ld c,a
        ld a,b
        or a
        jp p,smu2
        neg
smu2:   ld b,a
        add a,c
        ld l,a
        ld h,sqtab/256
        ld e,(hl)
        inc h
        ld d,(hl)
        ld a,c
        sub b
        jr nc,smu3
        neg
smu3:   ld l,a
        dec h
        ld a,e
        sub (hl)
        ld e,a
        inc h
        ld a,d
        sbc a,(hl)
        ld d,a
        ex de,hl
        pop af
        ret p
        jp neghl

; HL -> view column (r,u,f bytes) -> vanishing point (gvx,gvy), gvok
gvp:    xor a
        ld (gvok),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        or a
        ret z
        jp p,gvp1
        neg
        ld c,a
        ld a,e
        neg
        ld e,a
        ld a,d
        neg
        ld d,a
        ld a,c
gvp1:   ld (gvf),a
        ld a,d
        ld (gvu),a
        ld a,e
        call sexta
        ld a,(gvf)
        ld e,a
        ld d,0
        call projdiv
        ld de,256
        add hl,de
        ld (gvx),hl
        ld a,(gvu)
        call sexta
        ld a,(gvf)
        ld e,a
        ld d,0
        call projdiv
        ex de,hl
        ld hl,64
        or a
        sbc hl,de
        ld (gvy),hl
        ld a,1
        ld (gvok),a
        ret

; HL = HL * 0.453 (x/2 - x/16 + x/64)
sc45:   sra h
        rr l
        ld d,h
        ld e,l
        sra d
        rr e
        sra d
        rr e
        sra d
        rr e
        or a
        sbc hl,de
        sra d
        rr e
        sra d
        rr e
        add hl,de
        ret

gnegN:  ld hl,(gN)
        call neghl
        ld (gN),hl
        ld hl,(gN+2)
        call neghl
        ld (gN+2),hl
        ld hl,(gN+4)
        call neghl
        ld (gN+4),hl
        ret

; HL = signed numerator, DE = signed denominator -> HL = 256*num/den
gdiv:   ld a,d
        or e
        jr nz,gdv1
        ld de,15000             ; parallel: far off screen
        bit 7,h
        ex de,hl
        ret z
        jp neghl
gdv1:   bit 7,d
        jp z,projdiv
        call neghl
        ex de,hl
        call neghl
        ex de,hl
        jp projdiv

; HL -> A: 0 = 0..127, 1 = above (<0), 2 = below (>127)
ycls:   bit 7,h
        ld a,1
        ret nz
        ld a,h
        or a
        jr nz,ycl2
        ld a,l
        cp 128
        ld a,0
        ret c
ycl2:   ld a,2
        ret

; HL -> A: 0 = 0..511, 1 = left, 2 = right
xcls:   bit 7,h
        ld a,1
        ret nz
        ld a,h
        cp 2
        ld a,0
        ret c
        ld a,2
        ret

; (HL,DE) = screen point -> carry if it is on the sky side of the horizon
gsky:   push de
        ld de,-256
        add hl,de               ; X
        ld a,(m01)
        call mul168
        ex (sp),hl              ; save X term, HL = sy
        ex de,hl
        ld hl,64
        or a
        sbc hl,de               ; Y
        ld d,h
        ld e,l
        sra d
        rr e
        add hl,de               ; 1.5 Y  (undo the screen squash)
        ld a,(m11h)
        call mul168
        pop de
        add hl,de
        push hl
        ld a,(m21)
        call sexta
        add hl,hl
        pop de
        add hl,de               ; g > 0 : sky
        bit 7,h
        jr nz,gsk0
        ld a,h
        or l
        jr z,gsk0
        scf
        ret
gsk0:   or a
        ret

; ---- one grid line from gN ----
gline:  ld hl,(gN)
        call sc45
        ld (gN),hl
        ld hl,(gN+4)
        call sc45
        ld (gN+4),hl
        ld hl,(gN+2)
        bit 7,h
        call nz,neghl
        ex de,hl
        ld hl,(gN)
        bit 7,h
        call nz,neghl
        or a
        sbc hl,de
        jp nc,gsteep
        ; ---- flat: |Nu| > |Nr|, ends at the left and right edges
        ld a,(gN+3)
        bit 7,a
        call nz,gnegN           ; Nu > 0
        ld hl,(gN)
        ld de,(gN+4)
        or a
        sbc hl,de
        ld de,(gN+2)
        call projdiv            ; Y at X = -256
        ex de,hl
        ld hl,64
        or a
        sbc hl,de
        ld (cy0),hl
        ld hl,(gN)
        ld de,(gN+4)
        add hl,de
        call neghl
        ld de,(gN+2)
        call projdiv            ; Y at X = +256
        ex de,hl
        ld hl,64
        or a
        sbc hl,de
        ld (cy1),hl
        ld a,(hzfl)             ; within a pixel of the horizon: skip
        or a
        jr z,gfl1
        ld hl,(cy0)
        ld de,(hzy0)
        call near1
        jr nc,gfl1
        ld hl,(cy1)
        ld de,(hzy1)
        call near1
        ret c
gfl1:   ld hl,0
        ld (cx0),hl
        ld hl,511
        ld (cx1),hl
        ld hl,(cy0)
        call ycls
        ld (gcl0),a
        ld hl,(cy1)
        call ycls
        ld (gcl1),a
        ld b,a
        ld a,(gcl0)
        and b
        ret nz
        ld a,(gcl0)
        or a
        jr z,gfl2
        call gxat
        ld (cx0),hl
        ld (cy0),de
        call xcls
        or a
        ret nz
gfl2:   ld a,(gcl1)
        or a
        jr z,gfl3
        call gxat
        ld (cx1),hl
        ld (cy1),de
        call xcls
        or a
        ret nz
gfl3:   jp gfar

; ---- steep: ends at the top and bottom edges
gsteep: ld a,(gN+1)
        bit 7,a
        call nz,gnegN           ; Nr > 0
        ld hl,(gN)
        ld a,h
        or l
        ret z
        ld hl,(gN+2)
        sra h
        rr l
        sra h
        rr l
        ld (gq),hl              ; Nu/4
        ld de,(gN+4)
        add hl,de
        call neghl
        ld de,(gN)
        call projdiv            ; X at Y = +64 (top)
        ld de,256
        add hl,de
        ld (cx0),hl
        ld hl,(gq)
        ld de,(gN+4)
        or a
        sbc hl,de
        ld de,(gN)
        call projdiv            ; X at Y = -64 (bottom)
        ld de,256
        add hl,de
        ld (cx1),hl
        ld hl,0
        ld (cy0),hl
        ld hl,127
        ld (cy1),hl
        ld hl,(cx0)
        call xcls
        ld (gcl0),a
        ld hl,(cx1)
        call xcls
        ld (gcl1),a
        ld b,a
        ld a,(gcl0)
        and b
        ret nz
        ld a,(gcl0)
        or a
        jr z,gst2
        call gyat
        ld (cx0),de
        ld (cy0),hl
        call ycls
        or a
        ret nz
gst2:   ld a,(gcl1)
        or a
        jr z,gst3
        call gyat
        ld (cx1),de
        ld (cy1),hl
        call ycls
        or a
        ret nz
gst3:   ; fall into gfar

; Keep the part of (cx0,cy0)-(cx1,cy1) at least gT below the horizon
gfar:   ld hl,(cx0)
        ld de,(cy0)
        call gval
        ld (gg0),hl
        ld hl,(cx1)
        ld de,(cy1)
        call gval
        ld (gg1),hl
        ld de,(gg0)
        bit 7,d
        jr nz,gfa1
        ld a,d
        or e
        jr z,gfa1
        ; end 0 too far (or sky)
        bit 7,h
        jr nz,gfa0
        ld a,h
        or l
        ret nz                  ; both too far
gfa0:   ; end0 += (end1-end0) * g0/(g0-g1)
        ex de,hl                ; HL = g0, DE = g1
        push hl
        or a
        sbc hl,de
        ex de,hl                ; DE = g0-g1
        pop hl
        ld bc,cx0
        call gmove
        jp drawline
gfa1:   ld hl,(gg1)
        bit 7,h
        jp nz,drawline
        ld a,h
        or l
        jp z,drawline
        ; end 1 too far: end1 += (end0-end1) * g1/(g1-g0)
        ld de,(gg0)
        push hl
        or a
        sbc hl,de
        ex de,hl
        pop hl
        ld bc,cx1
        call gmove
        jp drawline

; BC -> end to move (x at BC, y at BC+4 for cx0/cy0 or cx1/cy1),
; HL/DE = fraction of the way to the other end
gmove:  ld (gmp),bc
        call projdiv            ; 0..256
        ld a,h
        or a
        jr z,gmv1
        ld l,255
gmv1:   srl l
        ld a,l
        ld (gfr),a
        ld hl,(gmp)
        ld de,cx0
        or a
        sbc hl,de
        ld hl,cx1
        jr nz,gmv2
        ld hl,cx0
        ld de,cx1
        jr gmv3
gmv2:   ld de,cx0
gmv3:   ; HL -> this x, DE -> other x
        push hl
        push de
        call gmv4               ; x
        pop de
        pop hl
        ld bc,cy0-cx0
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
gmv4:   push hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = this
        ex de,hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = other
        ex de,hl
        or a
        sbc hl,bc               ; other - this
        push bc
        ld a,(gfr)
        call mul168
        pop bc
        add hl,bc
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; (HL,DE) = screen point -> HL = height above the horizon (x4 scale)
; plus gT: <= 0 means near enough ground
gval:   push de
        ld de,-256
        add hl,de
        add hl,hl
        add hl,hl               ; 4X
        ld a,(m01)
        call mul168
        ex (sp),hl
        ex de,hl
        ld hl,64
        or a
        sbc hl,de               ; Y
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; 6Y = 4 * 1.5Y
        ld a,(m11h)
        call mul168
        pop de
        add hl,de
        push hl
        ld a,(m21)
        call sexta
        add hl,hl
        add hl,hl
        add hl,hl               ; 8*m21
        pop de
        add hl,de
        ld de,(gT)
        add hl,de
        ret

; VP as a drawable point -> HL = x, DE = y (clamped to the view)
gvclamp:
        ld hl,(gvy)
        bit 7,h
        jr z,gvc1
        ld hl,0
gvc1:   ld a,h
        or a
        jr nz,gvc2
        ld a,l
        cp 128
        jr c,gvc3
gvc2:   ld hl,127
gvc3:   ex de,hl
        ld hl,(gvx)
        bit 7,h
        jr z,gvc4
        ld hl,0
gvc4:   ld a,h
        cp 2
        ret c
        ld hl,511
        ret

; carry if (cx0) < HL < (cx1)    (DE = cx0 on entry)
gbetw:  or a
        sbc hl,de
        jr z,gbno
        jp m,gbno
        add hl,de
        ex de,hl
        ld hl,(cx1)
        or a
        sbc hl,de
        jr z,gbno
        jp m,gbno
        scf
        ret
gbno:   or a
        ret
gbetwy: or a
        sbc hl,de
        jr z,gbno
        jp m,gbno
        add hl,de
        ex de,hl
        ld hl,(cy1)
        or a
        sbc hl,de
        jr z,gbno
        jp m,gbno
        scf
        ret

; flat line leaving the top (A=1) or bottom (A=2): HL = sx, DE = sy
gxat:   push af
        ld hl,(gN+2)
        sra h
        rr l
        sra h
        rr l                    ; Nu/4
        pop af
        push af
        cp 1
        jr nz,gxa1
        ld de,(gN+4)            ; top: X = -256*(Nu/4 + Nf)/Nr
        add hl,de
        call neghl
        jr gxa2
gxa1:   ld de,(gN+4)            ; bottom: X = 256*(Nu/4 - Nf)/Nr
        or a
        sbc hl,de
gxa2:   ld de,(gN)
        call gdiv
        ld de,256
        add hl,de
        pop af
        ld de,0
        cp 1
        ret z
        ld de,127
        ret

; steep line leaving the left (A=1) or right (A=2): HL = sy, DE = sx
gyat:   push af
        ld hl,(gN)
        ld de,(gN+4)
        cp 1
        jr nz,gya1
        or a                    ; left: Y = 256*(Nr - Nf)/Nu
        sbc hl,de
        jr gya2
gya1:   add hl,de               ; right: Y = -256*(Nr + Nf)/Nu
        call neghl
gya2:   ld de,(gN+2)
        call gdiv
        ex de,hl
        ld hl,64
        or a
        sbc hl,de
        pop af
        ld de,0
        cp 1
        ret z
        ld de,511
        ret
