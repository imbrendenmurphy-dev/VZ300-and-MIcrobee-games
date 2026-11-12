; =====================================================================
;  ENGINE.ASM - VZ300 3D racer renderer (Stage 3)      VIBED BY BPM 2026
;  Mirrors ref3.py operation for operation. Included by race.asm.
; =====================================================================

; ---------------------------------------------------------------------
; helpers
; ---------------------------------------------------------------------
sext:   ld l,a                  ; HL = A sign-extended
        add a,a
        sbc a,a
        ld h,a
        ret

neg16:  xor a                   ; HL = -HL
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

logm:   ld a,h                  ; DE = LOGT[min(HL,2047)], HL >= 0
        cp 8
        jr c,.ok
        ld hl,2047
.ok:    ld a,h
        add a,LOGL/256
        ld h,a
        ld e,(hl)
        add a,8
        ld h,a
        ld d,(hl)
        ret

expt_or:                        ; A = EXPT[HL] with HL<0 -> 0, HL>511 -> 127
        bit 7,h
        jr nz,.z
        ld a,h
        cp 2
        jr nc,.m
        add a,EXPTP/256
        ld h,a
        ld a,(hl)
        ret
.z:     xor a
        ret
.m:     ld a,127
        ret

; DE = constant - lzm : expt_or. In: HL = constant, (LZM) ; out A
expt_c: ld de,(LZM)
        or a
        sbc hl,de
        jr expt_or

; quarter-square signed multiply, HL = B * C ; clobbers A,C,DE
mul8:   ld a,c
        xor $80
        ld h,a
        ld a,b
        xor $80
        ld l,a
        add a,h
        ld e,a
        ld a,SQPAGE
        adc a,0
        ld d,a
        ld a,l
        sub h
        jr nc,.p
        neg
.p:     ld l,a
        ld h,SQPAGE+1
        ld a,(de)
        sub (hl)
        ld c,a
        inc d
        inc d
        inc h
        inc h
        ld a,(de)
        sbc a,(hl)
        ld h,a
        ld l,c
        ret

; HL = HL / DE (unsigned 16-bit), clobbers A,BC
div16:  ld a,h
        ld c,l
        ld hl,0
        ld b,16
.d:     sla c
        rla
        adc hl,hl
        sbc hl,de
        jr nc,.n
        add hl,de
        jr .k
.n:     inc c
.k:     djnz .d
        ld h,a
        ld l,c
        ret

; ---------------------------------------------------------------------
; TRANSFORM: build the cross-section table SECS (32 bytes per entry)
;   +0 k (low byte) +2 LX +4 LY +6 LZ +8 RX +10 RY +12 RZ
;   +16 sxL +17 syL +18 sxR +19 syR (when z >= NEARZ)
; ---------------------------------------------------------------------
transform:
        ld hl,(CAM_I)
        ld (TK),hl
        ld de,TRK_H
        add hl,de
        ld a,(CAM_TH)
        add a,(hl)
        ld (HC),a
        ld hl,(CAM_LAT)         ; X = -lat
        call neg16
        ld (VX),hl
        ld a,(CAM_F)            ; Z = -(f >> 2)
        srl a
        srl a
        neg
        call sext
        ld (VZ),hl
        ld hl,(CAM_I)           ; Y = -CH - (((f>>1) * DY[i]) >> 7)
        ld de,TRK_DY
        add hl,de
        ld c,(hl)
        ld a,c
        ld (DYI),a
        ld a,(CAM_F)
        srl a
        ld b,a
        call mul8
        add hl,hl
        ld a,h
        call sext
        ex de,hl
        ld hl,-CH
        or a
        sbc hl,de
        ld (VY),hl
        ld a,(DYI)              ; hz = HORIZ + ((DY[i]*7) >> 4)
        call sext
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld a,l
        add a,HORIZ
        ld (HZ),a
        ld ix,SECS
        xor a
        ld (NSEC),a
        ld (DEPTHV),a
tr_loop:
        CHKEI
        ld hl,(TK)
        ld a,h
        and 1
        ld h,a
        ld (TIDX),hl
        ld de,TRK_H
        add hl,de
        ld a,(HC)
        ld b,a
        ld a,(hl)
        sub b
        ld (DANG),a
        ; level of detail
        ld a,(DEPTHV)
        cp LOD1
        jr c,tr_lod
        cp LOD2
        ld a,(TK)
        jr nc,.far
        and 1
        jr z,tr_lod
        jp tr_adv
.far:   and 3
        jr z,tr_lod
        jp tr_adv
tr_lod: ld a,(TK)
        ld (ix+0),a
        ld hl,(TIDX)
        ld de,TRK_HBX
        add hl,de
        ld a,(hl)
        ld (HBXV),a
        ld b,a
        ld a,(DANG)
        ld l,a
        ld h,COS64/256
        ld c,(hl)
        call mul8
        add hl,hl
        add hl,hl
        ld a,h
        ld (OXV),a              ; ox = (hbx*cos) >> 6
        ld a,(HBXV)
        ld b,a
        ld a,(DANG)
        ld l,a
        ld h,SIN64/256
        ld c,(hl)
        call mul8
        add hl,hl
        add hl,hl
        ld a,h
        neg
        ld (OZV),a              ; oz = -((hbx*sin) >> 6)
        ld hl,(TIDX)
        ld de,TRK_HBY
        add hl,de
        ld a,(hl)
        ld (HBYV),a
        ; L = (X-ox, Y-hby, Z-oz)   R = (X+ox, Y+hby, Z+oz)
        ld a,(OXV)
        call sext
        ex de,hl
        ld hl,(VX)
        or a
        sbc hl,de
        ld (ix+2),l
        ld (ix+3),h
        ld hl,(VX)
        add hl,de
        ld (ix+8),l
        ld (ix+9),h
        ld a,(HBYV)
        call sext
        ex de,hl
        ld hl,(VY)
        or a
        sbc hl,de
        ld (ix+4),l
        ld (ix+5),h
        ld hl,(VY)
        add hl,de
        ld (ix+10),l
        ld (ix+11),h
        ld a,(OZV)
        call sext
        ex de,hl
        ld hl,(VZ)
        or a
        sbc hl,de
        ld (ix+6),l
        ld (ix+7),h
        ld hl,(VZ)
        add hl,de
        ld (ix+12),l
        ld (ix+13),h
        ld de,32
        add ix,de
        ld hl,NSEC
        inc (hl)
tr_adv: ld a,(DANG)             ; step one section along heading d
        ld l,a
        ld h,SIN64/256
        ld e,(hl)
        inc h                   ; COS64 follows SIN64
        ld c,(hl)
        ld a,e
        add a,a
        sbc a,a
        ld d,a
        ld hl,(VX)
        add hl,de
        ld (VX),hl
        ld e,c
        ld a,c
        add a,a
        sbc a,a
        ld d,a
        ld hl,(VZ)
        add hl,de
        ld (VZ),hl
        ld hl,(TIDX)
        ld de,TRK_DY
        add hl,de
        ld e,(hl)
        ld a,e
        add a,a
        sbc a,a
        ld d,a
        ld hl,(VY)
        add hl,de
        ld (VY),hl
        ld hl,(TK)
        inc hl
        ld (TK),hl
        ld hl,DEPTHV
        inc (hl)
        ld a,(hl)
        cp DEPTH+1
        jp c,tr_loop
        ; project every cross-section side that is in front of the near plane
        ld ix,SECS
        ld a,(NSEC)
        ld b,a
.pj:    push bc
        CHKEI
        push ix
        pop iy
        inc iy
        inc iy                  ; IY -> L point
        call zfront
        jr c,.p1
        call proj
        ld a,(PSX)
        ld (ix+16),a
        ld a,(PSY)
        ld (ix+17),a
.p1:    ld de,6
        add iy,de               ; IY -> R point
        call zfront
        jr c,.p2
        call proj
        ld a,(PSX)
        ld (ix+18),a
        ld a,(PSY)
        ld (ix+19),a
.p2:    ld de,32
        add ix,de
        pop bc
        djnz .pj
        ret

; carry set if the point at IY is behind the near plane (z < NEARZ)
zfront: ld a,(iy+5)
        bit 7,a
        jr nz,.b
        or a
        ret nz                  ; z >= 256 (carry clear)
        ld a,(iy+4)
        cp NEARZ                ; carry if z < NEARZ
        ret
.b:     scf
        ret

; ---------------------------------------------------------------------
; PROJ: point at IY (x,y,z 16-bit) -> PSX, PSY (biased screen coords)
; inline log lookups; KX/KY = focal constant - log z
; ---------------------------------------------------------------------
proj:   ld l,(iy+4)
        ld h,(iy+5)
        ld a,h
        cp 8
        jr c,.z1
        ld hl,2047
.z1:    ld a,h
        add a,LOGL/256
        ld h,a
        ld e,(hl)
        add a,8
        ld h,a
        ld d,(hl)               ; DE = log z
        ld hl,LOGFX+BIAS
        or a
        sbc hl,de
        ld (PKX),hl
        ld hl,LOGFY+BIAS
        or a
        sbc hl,de
        ld (PKY),hl
        ; ---- x
        ld l,(iy+0)
        ld h,(iy+1)
        ld de,(PKX)
        call pxq
        add a,128
        ld (PSX),a
        ; ---- y
        ld l,(iy+2)
        ld h,(iy+3)
        ld de,(PKY)
        call pxq
        ; sy = clamp(64 + hz - py, 0, 255)
        ld e,a
        add a,a
        sbc a,a
        ld d,a                  ; DE = py
        ld a,(HZ)
        add a,64
        ld l,a
        ld h,0
        or a
        sbc hl,de
        bit 7,h
        jr z,.pos
        xor a
        jr .st
.pos:   ld a,h
        or a
        ld a,l
        jr z,.st
        ld a,255
.st:    ld (PSY),a
        ret

; A = signed pixel offset of coordinate HL with constant DE (= focal - log z)
pxq:    ld a,h
        or l
        ret z
        ld c,h                  ; C bit7 = sign
        bit 7,h
        jr z,.p
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
.p:     ld a,h
        cp 8
        jr c,.q
        ld hl,2047
.q:     ld a,h
        add a,LOGL/256
        ld h,a
        ld b,(hl)
        add a,8
        ld h,a
        ld h,(hl)
        ld l,b                  ; HL = log |v|
        add hl,de
        bit 7,h
        jr nz,.zero
        ld a,h
        cp 2
        jr nc,.max
        add a,EXPTP/256
        ld h,a
        ld a,(hl)
        jr .sg
.zero:  xor a
        ret
.max:   ld a,127
.sg:    bit 7,c
        ret z
        neg
        ret

; ---------------------------------------------------------------------
; RENDER: transform, strips (front to back), finalise
; ---------------------------------------------------------------------
render: ld a,(HALFON)
        or a
        ld a,255
        jr z,.h0
        ld a,64+HALFROW
.h0:    ld (half_y+1),a
        call transform
        ; reset row coverage
        ld hl,ROWCL
        ld b,64
.r1:    ld (hl),255
        inc l
        djnz .r1
        ld hl,ROWLP
        ld b,128
.r2:    ld (hl),16              ; LP and RP
        inc l
        djnz .r2
        ld a,200
        ld (YTOP),a
        xor a
        ld (NGATE),a
        ld ix,SECS
        ld a,(NSEC)
        or a
        jp z,fin_half
        dec a
        jp z,fin_half
        ld b,a
st_loop:
        push bc
        CHKEI
        call do_strip
        ld de,32
        add ix,de
        pop bc
        djnz st_loop
        jp fin_half

; strip between entry IX (near) and IX+32 (far)
do_strip:
        push ix
        pop iy
        ld de,32+2
        add iy,de               ; far L
        call zfront
        ret c
        ld de,6
        add iy,de               ; far R
        call zfront
        ret c
        ; far points from the table
        ld a,(ix+32+18)
        ld (PX2),a
        ld a,(ix+32+19)
        ld (PY2),a
        ld a,(ix+32+16)
        ld (PX3),a
        ld a,(ix+32+17)
        ld (PY3),a
        ; near left (clip if needed)
        push ix
        pop iy
        inc iy
        inc iy
        call zfront
        ld a,0
        jr nc,.nl
        ld de,32
        call clip_iy            ; CPT = clipped point, IY -> CPT
        call proj
        ld a,(PSX)
        ld (PX0),a
        ld a,(PSY)
        ld (PY0),a
        ld hl,NEARZ
        ld (ZNL),hl
        ld a,1
        jr .nl2
.nl:    ld a,(ix+16)
        ld (PX0),a
        ld a,(ix+17)
        ld (PY0),a
        ld l,(ix+6)
        ld h,(ix+7)
        ld (ZNL),hl
        xor a
.nl2:   ld (CLIPPED),a
        ; near right
        push ix
        pop iy
        ld de,8
        add iy,de
        call zfront
        jr nc,.nr
        ld de,32
        call clip_iy
        call proj
        ld a,(PSX)
        ld (PX1),a
        ld a,(PSY)
        ld (PY1),a
        ld hl,NEARZ
        ld (ZNR),hl
        ld a,1
        ld (CLIPPED),a
        jr .nr2
.nr:    ld a,(ix+18)
        ld (PX1),a
        ld a,(ix+19)
        ld (PY1),a
        ld l,(ix+12)
        ld h,(ix+13)
        ld (ZNR),hl
.nr2:   ; zm, rail width, skirt rows
        ld hl,(ZNL)
        ld de,(ZNR)
        add hl,de
        srl h
        rr l
        call logm
        ld (LZM),de
        ld hl,C_RAIL
        call expt_c
        or a
        jr nz,.rw1
        inc a
.rw1:   cp 41
        jr c,.rw2
        ld a,40
.rw2:   ld (RW),a
        ld hl,C_SKIRT
        call expt_c
        cp 41
        jr c,.s2
        ld a,40
.s2:    ld (SS),a
        ld a,(ix+0)
        ld (KK),a
        ; gate at this cross-section?
        and 15
        jr nz,.nog
        ld a,(CLIPPED)
        or a
        jr nz,.nog
        ld a,(PY0)
        ld b,a
        ld a,(PY1)
        cp b
        jr nc,.gm
        ld a,b
.gm:    ld b,a                  ; max(PY0,PY1)
        ld a,(YTOP)
        inc a
        cp b
        jr c,.nog               ; max > ytop+1
        call add_gate
.nog:   call stripfill
        ld b,a
        ld a,(YTOP)
        cp b
        ret c
        ld a,b
        ld (YTOP),a
        ret

; clip the point at IY against the far point at IY+DE; result in CPT, IY -> CPT
clip_iy:
        push iy
        pop hl
        add hl,de
        push hl
        pop bc                  ; BC -> far point (keep in FARP)
        ld (FARP),bc
        ; num = NEARZ - n.z ; den = f.z - n.z
        ld l,(iy+4)
        ld h,(iy+5)
        ex de,hl                ; DE = n.z
        ld hl,NEARZ
        or a
        sbc hl,de
        add hl,hl               ; num*128
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push hl
        push iy
        ld iy,(FARP)
        ld l,(iy+4)
        ld h,(iy+5)
        pop iy
        or a
        sbc hl,de               ; den
        ex de,hl
        pop hl
        call div16
        ld a,h
        or a
        jr nz,.t127
        ld a,l
        cp 128
        jr c,.tok
.t127:  ld a,127
.tok:   ld (TCL),a
        ; x
        ld bc,0
        call clip_axis
        ld (CPT+0),hl
        ld bc,2
        call clip_axis
        ld (CPT+2),hl
        ld hl,NEARZ
        ld (CPT+4),hl
        ld iy,CPT
        ret

; HL = n.c + ((clamp(f.c - n.c) * t) >> 7) for coordinate offset BC
clip_axis:
        push iy
        pop hl
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = n.c
        push de
        ld hl,(FARP)
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; HL = f.c
        or a
        sbc hl,de               ; diff
        ; clamp to -128..127
        ld a,h
        bit 7,a
        jr nz,.neg
        or a
        jr nz,.hi
        ld a,l
        cp 128
        jr c,.ok
.hi:    ld a,127
        jr .ok
.neg:   cp $FF
        jr nz,.lo
        ld a,l
        cp 128
        jr nc,.ok
.lo:    ld a,128
.ok:    ld b,a
        ld a,(TCL)
        ld c,a
        call mul8
        add hl,hl
        ld a,h
        call sext
        pop de
        add hl,de
        ret

add_gate:                       ; record gate: P0, P1, h, w, t
        ld a,(NGATE)
        cp 8
        ret nc
        ld l,a
        inc a
        ld (NGATE),a
        ld a,l
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,GATES/256
        ld a,(PX0)
        ld (hl),a
        inc l
        ld a,(PY0)
        ld (hl),a
        inc l
        ld a,(PX1)
        ld (hl),a
        inc l
        ld a,(PY1)
        ld (hl),a
        inc l
        push hl
        ld hl,C_GH
        call expt_c
        pop hl
        ld (hl),a
        inc l
        push hl
        ld hl,C_GW
        call expt_c
        or a
        jr nz,.w
        inc a
.w:     pop hl
        ld (hl),a
        inc l
        push hl
        ld hl,C_GT
        call expt_c
        or a
        jr nz,.t
        inc a
.t:     pop hl
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; STRIPFILL: rasterise quad P0..P3 into XMIN/XMAX, build runs per row,
; add the visible parts to each row. Returns A = top row (255 = none).
; ---------------------------------------------------------------------
stripfill:
        ; ymin / ymax
        ld a,(PY0)
        ld b,a
        ld c,a
        ld hl,PY1
        call .mm
        ld hl,PY2
        call .mm
        ld hl,PY3
        call .mm
        ld a,b
        ld (YMIN),a
        ld a,c
        ld (YMAX),a
        ; yr0 = max(ymin,64+TOPROW), yr1 = min(ymax + s, 127)
        ld a,(YMIN)
        cp 64+TOPROW
        jr nc,.a1
        ld a,64+TOPROW
.a1:    ld (YR0),a
        ld a,(SS)
        ld b,a
        ld a,(YMAX)
        add a,b
        jr c,.a2
        cp 128
        jr c,.a3
.a2:    ld a,127
.a3:    ld (YR1),a
        ld b,a
        ld a,(YR0)
        cp b
        jr z,.go
        jr c,.go
        ld a,255
        ret
.go:    ; ya0 = max(ymin, 64+TOPROW-s), ya1 = min(ymax,127)
        ld a,(SS)
        ld b,a
        ld a,64+TOPROW
        sub b
        ld b,a
        ld a,(YMIN)
        cp b
        jr nc,.a4
        ld a,b
.a4:    ld (YA0),a
        ld a,(YMAX)
        cp 128
        jr c,.a5
        ld a,127
.a5:    ld (YA1),a
        ; init rows ya0..ya1
        ld a,(YA0)
        ld l,a
        ld a,(YA1)
        sub l
        jr c,.noinit
        inc a
        ld b,a
.in:    ld h,XMIN/256
        ld (hl),255
        inc h
        ld (hl),0
        inc l
        djnz .in
.noinit:
        ; four edges
        ld hl,PX0
        ld de,PX1
        xor a
        call edge
        ld hl,PX1
        ld de,PX2
        ld a,1
        call edge
        ld hl,PX2
        ld de,PX3
        ld a,2
        call edge
        ld hl,PX3
        ld de,PX0
        ld a,3
        call edge
        ; colours for this strip
        ld a,(KK)
        rrca
        rrca
        and 1
        ld a,SU_A
        jr z,.c1
        ld a,SU_B
.c1:    ld (SUC),a
        ld a,(KK)
        rrca
        and 1
        ld a,RL_A
        jr z,.c2
        ld a,RL_B
.c2:    ld (RLC),a
        ld a,(YMAX)
        ld (sr3_ymax1+1),a
        ld (sr3_ymax2+1),a
        ld a,(YMIN)
        ld (sr3_ymin1+1),a
        ld a,(SS)
        ld (sr3_s1+1),a
        ld a,(RW)
        ld (sr3_rw1+1),a
        ld (sr3_rw2+1),a
        ld a,(RLC)
        ld (sr3_rl1+1),a
        ld (sr3_rl2+1),a
        ld a,(SUC)
        ld (sr3_su1+1),a
        ld a,255
        ld (STOP),a
        ld a,(YR0)
        ld (YCUR),a
.row:   ld a,(YCUR)
@half_y:
        cp 255                  ; patched: 64 + HALFROW when half-rate is on
        jr c,.full
        rra
        jr c,.skip              ; odd row in the half-rate region
.full:  call strip_row
.skip:  ld a,(YR1)
        ld b,a
        ld a,(YCUR)
        cp b
        jr z,.done
        inc a
        ld (YCUR),a
        jp .row
.done:  ld a,(STOP)
        ret
.mm:    ld a,(hl)               ; B = min, C = max
        cp b
        jr nc,.m1
        ld b,a
.m1:    cp c
        ret c
        ret z
        ld c,a
        ret

; edge from point (HL)->(DE) [x at +0, y at +4] with tag A
edge:   ld (ETAG),a             ; HL -> PXa, DE -> PXb (PY = PX + 4, same page)
        push de
        ld b,(hl)
        ld a,l
        add a,4
        ld l,a
        ld c,(hl)               ; B = xa, C = ya
        pop hl
        ld d,(hl)
        ld a,l
        add a,4
        ld l,a
        ld e,(hl)               ; D = xb, E = yb
        ld a,e
        sub c
        jp z,.hz
        jr nc,.ord
        ld a,b                  ; swap so that ya < yb
        ld b,d
        ld d,a
        ld a,c
        ld c,e
        ld e,a
        sub c
.ord:   cp 1
        jp z,.d1
        ld l,a                  ; HL = LOG dy
        ld h,LOGL/256
        ld a,(hl)
        ld h,LOGL/256+8
        ld h,(hl)
        ld l,a
        ld (.ldy+1),hl
        ld a,d                  ; dx = xb - xa
        sub b
        jr z,.zero
        ld h,0
        jr nc,.pos
        neg
        dec h
.pos:   ld l,a
        ld a,h
        ld (.sgn+1),a
        ld h,LOGL/256           ; HL = LOG |dx|
        ld a,(hl)
        ld h,LOGL/256+8
        ld h,(hl)
        ld l,a
        push de
.ldy:   ld de,0
        or a
        sbc hl,de
        ld de,512
        add hl,de               ; d2
        pop de
        bit 7,h
        jr z,.p0
        ld hl,0
.p0:    ld a,h
        cp 4
        jr c,.p1
        ld hl,1023
.p1:    ld a,h
        add a,EXP88L/256
        ld h,a
        ld a,(hl)
        inc h
        inc h
        inc h
        inc h
        ld h,(hl)
        ld l,a                  ; HL = slope magnitude
.sgn:   ld a,0
        or a
        jr z,.slok
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        jr .slok
.zero:  ld h,a
        ld l,a
.slok:  ld a,b                  ; x88 in HL', slope in DE'
        push hl
        exx
        pop de
        ld h,a
        ld l,128
        exx
        ; both endpoints on screen (63..192)? then no per-row clamp is needed: D = 1
        cp 63
        jr c,.slw
        cp 193
        jr nc,.slw
        ld a,d
        cp 63
        jr c,.slw
        cp 193
        jr nc,.slw
        ld d,1
        jr .chk
.slw:   ld d,0
.chk:   ld a,(YA0)              ; skip rows above ya0 (x still advances)
        sub c
        jr c,.ns
        jr z,.ns
        ld b,a
        exx
.sk:    add hl,de
        djnz .sk
        exx
        ld a,(YA0)
        ld c,a
.ns:    ld a,(YA1)              ; last row = min(yb, ya1)
        cp e
        jr c,.e1
        ld a,e
.e1:    sub c
        ret c                   ; nothing on screen
        inc a
        ld b,a                  ; row count
        dec d
        ld a,(ETAG)
        jr nz,.slp
        ld (.t3+1),a
        ld (.t4+1),a
.lpf:   exx
        ld a,h
        add hl,de
        exx
        ld d,a
        ld l,c
        ld h,XMIN/256
        cp (hl)
        jr nc,.m1
        ld (hl),a
        ld h,TMIN/256
.t3:    ld (hl),0
.m1:    ld h,XMAX/256
        ld a,(hl)
        cp d
        jr nc,.m2
        ld (hl),d
        ld h,TMAX/256
.t4:    ld (hl),0
.m2:    inc c
        djnz .lpf
        ret
.slp:   ld (.t1+1),a
        ld (.t2+1),a
.lp:    exx
        ld a,h
        add hl,de
        exx
        cp 63
        jr nc,.c1
        ld a,63
.c1:    cp 193
        jr c,.c2
        ld a,192
.c2:    ld d,a
        ld l,c
        ld h,XMIN/256
        cp (hl)
        jr nc,.n1
        ld (hl),a
        ld h,TMIN/256
.t1:    ld (hl),0
.n1:    ld h,XMAX/256
        ld a,(hl)
        cp d
        jr nc,.n2
        ld (hl),d
        ld h,TMAX/256
.t2:    ld (hl),0
.n2:    inc c
        djnz .lp
        ret
.hz:    ld a,c                  ; horizontal edge
        call .inr
        ret c
        ld l,c
        ld a,b
        call updx
        ld l,c
        ld a,d
        jp updx
.d1:    ld a,c                  ; dy == 1: exact endpoints
        call .inr
        jr c,.d1b
        ld l,c
        ld a,b
        call updx
.d1b:   ld a,e
        call .inr
        ret c
        ld l,e
        ld a,d
        jp updx
.inr:   ld hl,YA0               ; carry set if A outside ya0..ya1 (BCDE kept)
        cp (hl)
        ret c
        inc hl
        ld l,(hl)
        ld h,a
        ld a,l
        cp h
        ret

; update XMIN/XMAX for row L with x = A, tag (ETAG)
updx:   cp 63
        jr nc,.u1
        ld a,63
.u1:    cp 193
        jr c,.u2
        ld a,192
.u2:    ld h,XMIN/256
        cp (hl)
        jr nc,.u3
        ld (hl),a
        ld h,TMIN/256
        ex af,af'
        ld a,(ETAG)
        ld (hl),a
        ex af,af'
.u3:    ld h,XMAX/256
        cp (hl)
        ret c
        ret z
        ld (hl),a
        ld h,TMAX/256
        ld a,(ETAG)
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; one row of a strip (YCUR = y). Registers: B=Sa C=Sb D=flags
; (bit0 surface, bit1 skirt, bit2 left rail, bit3 right rail), E=parity,
; IYH=l1 IYL=r1, HL=run writer. Per-strip constants are patched in.
; ---------------------------------------------------------------------
strip_row:
        ld a,(YCUR)
        ld l,a
        ld h,XMIN/256
        ld d,0
@sr3_ymax1:
        ld a,0
        cp l
        jr c,.nsv
        ld b,(hl)               ; Sa
        inc h
        ld a,(hl)               ; Sb
        cp b
        jr c,.nsv
        ld c,a
        inc h                   ; TMIN
        ld a,(hl)
        cp 3
        jr nz,.t1
        set 2,d
.t1:    inc h                   ; TMAX
        ld a,(hl)
        dec a
        jr nz,.t2
        set 3,d
.t2:    set 0,d
.nsv:
@sr3_s1:
        ld a,0
        or a
        jr z,.nkv
        ld e,a
        ld a,l
        sub e                   ; ky
@sr3_ymin1:
        cp 0
        jr c,.nkv
@sr3_ymax2:
        cp 0
        jr z,.k0
        jr nc,.nkv
.k0:    ld l,a
        ld h,XMIN/256
        ld e,(hl)               ; Ka
        inc h
        ld a,(hl)               ; Kb
        cp e
        jr c,.nkv
        ld (KB),a
        ld a,e
        ld (KA),a
        set 1,d
.nkv:   ld a,d
        and 3
        ret z
        ; span a (L) .. b (H)
        bit 0,d
        jr z,.ko
        ld l,b
        ld h,c
        bit 1,d
        jr z,.ab
        ld a,(KA)
        cp l
        jr nc,.ab1
        ld l,a
.ab1:   ld a,(KB)
        cp h
        jr c,.ab
        ld h,a
        jr .ab
.ko:    ld a,(KA)
        ld l,a
        ld a,(KB)
        ld h,a
.ab:    ld a,l
        cp 64
        jr nc,.ab2
        ld l,64
.ab2:   ld a,h
        cp 192
        jr c,.ab3
        ld h,191
.ab3:   ld a,h
        cp l
        ret c                   ; nothing on screen
        ld (RA),hl              ; RA = a, RB = b
        ; hidden behind nearer track?
        ld a,(YCUR)
        sub 64
        ld e,a
        ld a,d
        ld d,ROWCL/256
        ld (FLG),a
        ld a,(de)
        cp 255
        jr z,.vis
        cp l
        jr z,.q3
        jr nc,.vis
.q3:    ld a,e
        add a,64
        ld e,a
        ld a,(de)
        cp h
        jr c,.vis
        ld a,(YCUR)             ; hidden: top-row bookkeeping only
        ld b,a
        ld a,(STOP)
        cp b
        ret c
        ld a,b
        ld (STOP),a
        ret
.vis:   ld a,(FLG)
        ld d,a
        ld a,(YCUR)
        and 1
        rrca
        rrca
        rrca
        rrca
        ld e,a                  ; E = parity
        ld hl,RUNBUF
        bit 0,d
        jp z,.konly
        bit 1,d                 ; left skirt if Ka < Sa
        jr z,.nok
        ld a,(KA)
        cp b
        jr nc,.nok
        ld (hl),a
        inc l
        ld a,SK
        add a,e
        ld (hl),a
        inc l
.nok:   ; l1 = (railL ? Sa+rw : Sa), at most Sb+1
@sr3_rw1:
        ld a,0
        bit 2,d
        jr z,.l0
        add a,b
        jr .l1
.l0:    ld a,b
.l1:    dec a                   ; l1-1 <= Sb ?
        cp c
        jr c,.l2
        jr z,.l2
        ld a,c
.l2:    inc a
        ld iyh,a
        ; r1 = (railR ? Sb-rw+1 : Sb+1), at least l1
        ld a,c
        inc a
        bit 3,d
        jr z,.r1
@sr3_rw2:
        sub 0
.r1:    cp iyh
        jr nc,.r2
        ld a,iyh
.r2:    ld iyl,a
        bit 2,d                 ; left rail
        jr z,.nl
        ld (hl),b
        inc l
@sr3_rl1:
        ld a,0
        add a,e
        ld (hl),a
        inc l
.nl:    ld a,iyh                ; surface if l1 < r1
        cp iyl
        jr nc,.ns
        ld (hl),a
        inc l
@sr3_su1:
        ld a,0
        add a,e
        ld (hl),a
        inc l
.ns:    bit 3,d                 ; right rail if r1 <= Sb
        jr z,.nr
        ld a,iyl
        cp c
        jr z,.yr
        jr nc,.nr
.yr:    ld (hl),a
        inc l
@sr3_rl2:
        ld a,0
        add a,e
        ld (hl),a
        inc l
.nr:    bit 1,d                 ; right skirt if Kb > Sb
        jr z,.ed
        ld a,(KB)
        cp c
        jr z,.ed
        jr c,.ed
        ld a,c
        inc a
        ld (hl),a
        inc l
        ld a,SK
        add a,e
        ld (hl),a
        inc l
        jr .ed
.konly: ld a,(KA)
        ld (hl),a
        inc l
        ld a,SK
        add a,e
        ld (hl),a
        inc l
.ed:    ld a,l                  ; B = run count
        sub RUNBUF & 255
        rrca
        ld b,a
        ld hl,RUNBUF
        ld a,(RB)
        ld e,a                  ; E = b
        ; drop runs that end left of the screen
.dl:    ld a,b
        cp 2
        jr c,.dl2
        inc l
        inc l
        ld a,(hl)
        cp 65
        jr nc,.dl1
        dec b
        jr .dl
.dl1:   dec l
        dec l
.dl2:   ld a,(hl)
        cp 64
        jr nc,.dl3
        ld (hl),64
.dl3:   ld a,l
        ld (RUNS0),a
        ld c,0                  ; keep runs starting at or before b
        push hl
.dr:    ld a,e
        cp (hl)
        jr c,.dr2
        inc c
        inc l
        inc l
        djnz .dr
.dr2:   pop hl
        ld a,c
        ld (NRUN),a
        call cover
        ld a,(YCUR)
        ld b,a
        ld a,(STOP)
        cp b
        ret c
        ld a,b
        ld (STOP),a
        ret

; ---------------------------------------------------------------------
; COVER: add runs (RUNS0 low byte in the RUNBUF page, NRUN) spanning RA..RB
; to row YCUR-64. Inline writes, no per-run calls.
; ---------------------------------------------------------------------
cover:  ld a,(YCUR)
        sub 64
        ld (CR_R),a
        ld c,a
        rrca
        rrca
        rrca
        ld b,a
        and $E0
        ld (LBASE),a
        ld a,b
        and $1F
        add a,LISTS/256
        ld (LBASE+1),a
        ld l,c
        ld h,ROWCL/256
        ld a,(hl)
        inc a
        jr nz,.cov
        ; uncovered row: CL = a, CR = b, all runs at RP (always room: RP = 16)
        ld a,(RA)
        ld (hl),a
        set 6,l
        ld a,(RB)
        ld (hl),a
        ld h,ROWLP/256
        ld e,(hl)               ; RP
        ld a,(NRUN)
        ld b,a
        add a,a
        add a,e
        ld (hl),a
        ld a,(LBASE+1)
        ld d,a
        ld a,(LBASE)
        add a,e
        ld e,a                  ; DE -> list[RP]
        ld a,(RUNS0)
        ld l,a
        ld h,RUNBUF/256
.u:     ld a,(hl)
        sub 64
        ld (de),a
        inc l
        inc e
        ld a,(hl)
        ld (de),a
        inc l
        inc e
        djnz .u
        ret
.cov:   dec a
        ld b,a                  ; B = CL
        ld a,(RA)
        cp b
        jr nc,.right
        ld (hl),a               ; CL = a
        ld d,b                  ; D = old CL
        ld a,(RUNS0)
        ld l,a
        ld h,RUNBUF/256
        ld a,(NRUN)
        ld b,a
        ld c,0
.cl:    ld a,(hl)               ; count runs with x < old CL
        cp d
        jr nc,.cle
        inc c
        inc l
        inc l
        djnz .cl
.cle:   ld a,c
        or a
        jr z,.right
        ld b,c
        push hl
        ld a,(CR_R)
        ld l,a
        ld h,ROWLP/256
        ld c,(hl)               ; LP
        ex (sp),hl              ; HL = runs pointer, stack = &LP
        ld a,(LBASE+1)
        ld d,a
        ld a,(LBASE)
        add a,c
        ld e,a                  ; DE -> list[LP]
.cl2:   ld a,c
        cp 4
        jr c,.cl3
        dec l
        ld a,(hl)               ; colour
        dec e
        ld (de),a
        dec l
        ld a,(hl)               ; x
        sub 64
        dec e
        ld (de),a
        dec c
        dec c
        djnz .cl2
.cl3:   pop hl
        ld (hl),c
.right: ld a,(CR_R)
        or 64
        ld l,a
        ld h,ROWCL/256
        ld b,(hl)               ; CR
        ld a,(RB)
        cp b
        ret z
        ret c
        ld (hl),a
        ld a,b
        inc a
        ld d,a                  ; D = cr1
        ld a,(RUNS0)
        ld l,a
        ld h,RUNBUF/256
        inc l
        ld e,(hl)               ; E = c0 (first run's colour)
        dec l
        ld a,(NRUN)
        ld b,a
.c0:    ld a,d                  ; last run with x <= cr1 gives c0
        cp (hl)
        jr c,.c0e
        inc l
        ld e,(hl)
        inc l
        djnz .c0
.c0e:   ld a,l
        ld (RUNP),a             ; remaining runs (x > cr1): B of them
        ld a,b
        ld (NRUN),a
        ld a,(CR_R)
        or 64
        ld l,a
        ld h,ROWLP/256
        ld c,(hl)               ; RP
        push hl
        ld a,(LBASE+1)
        ld h,a
        ld a,(LBASE)
        add a,c
        ld l,a                  ; HL -> list[RP]
        ld a,c
        cp 28
        jr nc,.fin
        ld a,d
        sub 64
        ld (hl),a
        inc l
        ld (hl),e
        inc l
        inc c
        inc c
        ld a,(NRUN)
        or a
        jr z,.fin
        ld b,a
        ld a,(RUNP)
        ld e,a
        ld d,RUNBUF/256
.ap:    ld a,c
        cp 28
        jr nc,.fin
        ld a,(de)
        sub 64
        ld (hl),a
        inc e
        inc l
        ld a,(de)
        ld (hl),a
        inc e
        inc l
        inc c
        inc c
        djnz .ap
.fin:   pop hl
        ld (hl),c
        ret

app_run:                        ; append (A = biased x, C = colour) at RP if room
        ld e,a
        ld a,(CR_R)
        add a,64
        ld l,a
        ld h,ROWLP/256
        ld a,(hl)
        cp 28
        ret nc
        ld d,a
        add a,2
        ld (hl),a
        ld hl,(LBASE)
        ld a,d
        add a,l
        ld l,a
        ld a,e
        sub 64
        ld (hl),a
        inc l
        ld (hl),c
        ret

pre_run:                        ; prepend (A = biased x, C = colour) at LP if room
        ld e,a
        ld a,(CR_R)
        ld l,a
        ld h,ROWLP/256
        ld a,(hl)
        cp 4
        ret c
        sub 2
        ld (hl),a
        ld hl,(LBASE)
        add a,l
        ld l,a
        ld a,e
        sub 64
        ld (hl),a
        inc l
        ld (hl),c
        ret

; ---------------------------------------------------------------------
; FIN_HALF: odd rows in the half-rate region copy the row above
; (colours +16 flips the dither phase), then finalise
; ---------------------------------------------------------------------
fin_half:
        ld a,(HALFON)
        or a
        jp z,finalise
        ld c,HALFROW+1
.r:     ld l,c                  ; CL, CR, LP, RP of row c-1 -> row c
        dec l
        ld h,ROWCL/256
        ld a,(hl)
        inc l
        ld (hl),a
        ld b,a                  ; B = CL (255 = empty)
        ld a,l
        add a,63
        ld l,a
        ld a,(hl)
        inc l
        ld (hl),a
        ld h,ROWLP/256
        dec l
        ld a,(hl)
        inc l
        ld (hl),a
        ld e,a                  ; E = RP
        ld l,c
        dec l
        ld a,(hl)
        inc l
        ld (hl),a
        ld d,a                  ; D = LP
        ld a,b
        inc a
        jr z,.nx
        ld a,e                  ; pairs = (RP - LP) / 2
        sub d
        rrca
        or a
        jr z,.nx
        ld b,a
        ld a,c                  ; HL = list of row c, at LP ; DE = 32 bytes above
        rrca
        rrca
        rrca
        ld h,a
        and $E0
        add a,d
        ld l,a
        ld a,h
        and $1F
        add a,LISTS/256
        ld h,a
        ld a,l
        sub 32
        ld e,a
        ld d,h
        jr nc,.cp
        dec d
.cp:    ld a,(de)
        ld (hl),a
        inc e
        inc l
        ld a,(de)
        add a,16
        ld (hl),a
        inc e
        inc l
        djnz .cp
.nx:    inc c
        inc c
        ld a,c
        cp 64
        jr c,.r
        jp finalise

; ---------------------------------------------------------------------
; FINALISE: background runs, terminators, start offsets (tight version)
; ---------------------------------------------------------------------
finalise:
        ld a,(HZ)
        bit 7,a
        jr z,.f1
        xor a
.f1:    cp 64
        jr c,.f2
        ld a,63
.f2:    ld (SPLIT),a
        ; background colours for rows TOPROW..63 (parity added below) into BGROW
        ld c,a                  ; C = split
        ld hl,BGROW+TOPROW
        ld a,TOPROW
        cp c
        jr nc,.gr               ; horizon above the rendered area: no sky rows
        ld a,c
        sub TOPROW
        ld (SKYD),a             ; d = split - TOPROW
        ld (.bn+1),a
        ld (.bn2+1),a
        ld de,(SKYTAB)
        inc e
        inc e                   ; bands 2..4
        ld b,0                  ; accumulator
        ld a,TOPROW
.sky:   cp c
        jr nc,.gr
        ex af,af'
        ld a,(de)
        ld (hl),a
        ld a,b                  ; acc += 3 ; while acc >= d: acc -= d, band++
        add a,3
.bn:    cp 0
        jr c,.bs
.bn2:   sub 0
        inc e
        jr .bn
.bs:    ld b,a
        ex af,af'
        inc l
        inc a
        jr .sky
.gr:    ld b,a                  ; ground: haze for 2 rows, then void
        ld a,c
        add a,2
        ld c,a
        ld a,b
.g1:    cp 64
        jr nc,.par
        cp c
        ld (hl),HAZE
        jr c,.g2
        ld (hl),VOID
.g2:    inc l
        inc a
        jr .g1
.par:   ld hl,BGROW+1           ; odd rows +16
        ld b,32
.p1:    ld a,(hl)
        add a,16
        ld (hl),a
        inc l
        inc l
        djnz .p1
        ; walk the rows: E = row, BC = its run list, D = background
        ld bc,LISTS+TOPROW*32
        ld e,TOPROW
.row:   CHKEI
        ld l,e
        ld h,BGROW/256
        ld d,(hl)
        ld h,ROWCL/256
        ld a,(hl)               ; CL
        inc a
        jr z,.unc
        cp 66                   ; CL > 64: prepend (0,bg)
        jr c,.nl
        ld h,ROWLP/256
        ld a,(hl)
        sub 2
        ld (hl),a
        add a,c
        ld l,a
        ld h,b
        ld (hl),0
        inc l
        ld (hl),d
.nl:    ld a,e
        add a,64
        ld l,a
        ld h,ROWCL/256
        ld a,(hl)               ; CR
        ld h,ROWLP/256
        cp 191
        jr nc,.nr
        sub 63                  ; (CR+1) - 64
        ex af,af'
        ld a,(hl)               ; RP, then RP += 2
        inc (hl)
        inc (hl)
        add a,c
        ld l,a
        ld h,b
        ex af,af'
        ld (hl),a
        inc l
        ld (hl),d
        inc l
        ld (hl),128
        jr .next
.nr:    ld a,(hl)
        add a,c
        ld l,a
        ld h,b
        ld (hl),128
        jr .next
.unc:   ld a,c                  ; uncovered: (0,bg),128 at 14
        add a,14
        ld l,a
        ld h,b
        ld (hl),0
        inc l
        ld (hl),d
        inc l
        ld (hl),128
        ld h,ROWLP/256
        ld l,e
        ld (hl),14
.next:  ld a,c
        add a,32
        ld c,a
        jr nc,.n2
        inc b
.n2:    inc e
        ld a,e
        cp 64
        jp nz,.row
        ret

pre_force:                      ; prepend without the room check
        ld e,a
        ld a,(CR_R)
        ld l,a
        ld h,ROWLP/256
        ld a,(hl)
        sub 2
        ld (hl),a
        ld hl,(LBASE)
        add a,l
        ld l,a
        ld a,e
        sub 64
        ld (hl),a
        inc l
        ld (hl),c
        ret

app_force:                      ; append without the room check (space was reserved)
        ld e,a
        ld a,(CR_R)
        add a,64
        ld l,a
        ld h,ROWLP/256
        ld a,(hl)
        ld d,a
        add a,2
        ld (hl),a
        ld hl,(LBASE)
        ld a,d
        add a,l
        ld l,a
        ld a,e
        sub 64
        ld (hl),a
        inc l
        ld (hl),c
        ret

; ---------------------------------------------------------------------
; COMP2: compose all 64 rows from the run lists into BUFFER
; ---------------------------------------------------------------------
compose:
        ld a,(SKYDIRTY)         ; restore the static sky only after a gate drew on it
        or a
        jr z,.nsky
        ld hl,SKYIMG
        ld de,BUFFER
        ld bc,TOPROW*32
        ldir
        xor a
        ld (SKYDIRTY),a
        inc a
        ld (HUDFORCE),a
        ld (TOPCHG),a
.nsky:
        ld a,TOPROW
        ld (crow),a
        ld de,BUFFER+TOPROW*32
        ld b,PATTAB/256
        ld iy,c2back
c2row:  CHKEI
        ld a,(crow)             ; HL = LISTS + crow*32 + LP[crow]
        ld l,a
        ld h,ROWLP/256
        ld c,(hl)
        rrca
        rrca
        rrca
        ld h,a
        and $E0
        add a,c
        ld l,a
        ld a,h
        and $1F
        add a,LISTS/256
        ld h,a
        ld b,PATTAB/256
        ld a,e
        ld ixl,a                ; row start (low byte)
        inc l
        ld c,(hl)
        inc l
        ld a,(bc)
        ld ixh,a
c2seg:  ld a,(hl)
        ld (c2x+1),a
        rrca
        rrca
        and $3F
        ld c,a
        ld a,e
        sub ixl                 ; j = bytes written this row (0..32)
        sub c
        cp 1
        jr z,c2thin
        add a,a
        add a,64
        ld (c2j+1),a
        ld a,ixh
c2j:    jp FILL2
c2back:
c2x:    ld a,0
        cp 128
        jr z,c2end
        inc l
        and 3
        jr z,c2al
        ex af,af'
        ld c,(hl)
        inc l
        ld a,(bc)
        ld c,a
        xor ixh
c2mix:  ex af,af'
        dec a
        jr z,c2s1
        dec a
        jr z,c2s2
        ex af,af'
        and $FC
        jr c2sx
c2s2:   ex af,af'
        and $F0
        jr c2sx
c2s1:   ex af,af'
        and $C0
c2sx:   xor c
        ld (de),a
        inc e
        ld ixh,c
        jp c2seg
c2al:   ld c,(hl)
        inc l
        ld a,(bc)
        ld ixh,a
        jp c2seg
c2thin: dec e
        inc l
        ld a,(c2x+1)
        and 3
        jr z,c2t0
        ex af,af'
        ld c,(hl)
        inc l
        ld a,(bc)
        ld c,a
        ld a,(de)
        xor c
        jr c2mix
c2t0:   ld c,(hl)
        inc l
        ld a,(bc)
        ld c,a
        xor a
        jr c2sx
c2end:  ld a,e
        or a
        jr nz,.r2
        inc d
.r2:    ld a,(crow)
        inc a
        ld (crow),a
        cp 64
        jp nz,c2row
        jp draw_skyline

; ---------------------------------------------------------------------
; gates: solid colour-3 rectangles OR-ed into BUFFER (far to near)
; ---------------------------------------------------------------------
draw_gates:
        ld a,(NGATE)
        or a
        ret z
        ld b,a
.g:     push bc
        dec b
        ld a,b
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,GATES/256
        push hl
        pop ix
        ld a,(ix+0)
        ld c,(ix+1)
        call pylon
        ld a,(ix+2)
        ld c,(ix+3)
        call pylon
        ; crossbar rows: min(y0,y1)-h .. +t-1 ; x from min(x0,x1) to max (biased)
        ld a,(ix+1)
        ld b,(ix+3)
        cp b
        jr c,.y1
        ld a,b
.y1:    sub (ix+4)
        jr nc,.y2
        xor a
.y2:    ld (RY0),a
        add a,(ix+6)
        jr nc,.y3
        ld a,0                  ; overflow: treat as 256 -> 255 after dec
.y3:    dec a
        ld (RY1),a
        ld a,(ix+0)
        ld b,(ix+2)
        cp b
        jr c,.x1
        ld c,a
        ld a,b
        ld b,c
.x1:    ld (RX0),a
        ld a,b
        ld (RX1),a
        call rect
        pop bc
        djnz .g
        ret

pylon:  ; A = biased x, C = biased base y ; (ix+4) h, (ix+5) w
        ld b,a
        ld a,(ix+5)
        srl a
        ld d,a
        ld a,b
        sub d                   ; xl (biased), saturate at 0
        jr nc,.p1
        xor a
.p1:    ld (RX0),a
        ld a,(ix+5)             ; x1 = x + (w - w/2) - 1, computed from x itself
        sub d
        add a,b
        jr nc,.p2
        ld a,0
.p2:    dec a                   ; (255 on overflow)
        ld (RX1),a
        ld a,c
        or a
        ret z                   ; base on biased row 0: nothing above it on screen
        dec a
        ld (RY1),a
        inc a
        sub (ix+4)
        jr nc,.p3
        xor a
.p3:    ld (RY0),a
        jp rect

; rect: biased coords RX0..RX1 (screen x + 64), RY0..RY1 (screen y + 64), colour 3
rect:   ld a,(RX1)
        cp 64
        ret c
        ld a,(RX0)
        cp 192
        ret nc
        ld a,(RY1)
        cp 64
        ret c
        ld a,(RY0)
        cp 128
        ret nc
        cp 64+TOPROW            ; drawing over the static sky?
        jr nc,.ns
        ld a,1
        ld (SKYDIRTY),a
        ld (TOPCHG),a
.ns:    ld a,(RX0)
        cp 64
        jr nc,.a
        ld a,64
.a:     sub 64
        ld (RX0),a
        ld a,(RX1)
        cp 192
        jr c,.b
        ld a,191
.b:     sub 64
        ld (RX1),a
        ld b,a
        ld a,(RX0)
        cp b
        jr z,.c
        ret nc
.c:     ld a,(RY0)
        cp 64
        jr nc,.d
        ld a,64
.d:     sub 64
        ld (RY0),a
        ld a,(RY1)
        cp 128
        jr c,.e
        ld a,127
.e:     sub 64
        ld (RY1),a
        ld b,a
        ld a,(RY0)
        cp b
        jr z,.f
        ret nc
.f:     ld a,(RX0)
        and 3
        add a,LMASK & 255
        ld l,a
        ld h,LMASK/256
        ld a,(hl)
        ld (MLEFT),a
        ld a,(RX1)
        and 3
        add a,4+(LMASK & 255)
        ld l,a
        ld a,(hl)
        ld (MRIGHT),a
        ld a,(RY0)
        ld (RY),a
.row:   ld a,(RY)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,BUFFER
        add hl,de
        ld a,(RX0)
        rrca
        rrca
        and $1F
        ld c,a
        ld b,0
        add hl,bc
        ld a,(RX1)
        rrca
        rrca
        and $1F
        sub c
        jr nz,.wide
        ld a,(MLEFT)
        ld b,a
        ld a,(MRIGHT)
        and b
        or (hl)
        ld (hl),a
        jr .nx
.wide:  ld b,a
        ld a,(MLEFT)
        or (hl)
        ld (hl),a
        inc hl
        dec b
        jr z,.last
.mid:   ld (hl),$FF
        inc hl
        djnz .mid
.last:  ld a,(MRIGHT)
        or (hl)
        ld (hl),a
.nx:    ld a,(RY1)
        ld b,a
        ld a,(RY)
        cp b
        ret z
        inc a
        ld (RY),a
        jp .row

; ---------------------------------------------------------------------
; MAKE_SKY_TOP: static sky image for rows 0..TOPROW-1 (bands 0 and 1)
; ---------------------------------------------------------------------
make_sky_top:
        ld de,SKYIMG
        ld c,0                  ; row
.r:     ld hl,(SKYTAB)
        ld a,c
        cp TOPROW/2
        jr c,.b0
        inc hl
.b0:    ld a,(hl)               ; colour
        bit 0,c
        jr z,.ev
        add a,16
.ev:    add a,PATTAB & 255
        ld l,a
        ld h,PATTAB/256
        ld a,(hl)
        ld b,32
.f:     ld (de),a
        inc de
        djnz .f
        inc c
        ld a,c
        cp TOPROW
        jr nz,.r
        ld a,1
        ld (SKYDIRTY),a
        ret

; ---------------------------------------------------------------------
; DRAW_SKYLINE: distant mountains just above the horizon, panning with
; the heading; written only on byte columns clear of track
; ---------------------------------------------------------------------
draw_skyline:
        ld a,(SKYLN)
        or a
        ret z
        ld a,(SPLIT)
        ld (.sp+1),a
        sub SKYL_H
        jr c,.y0
        cp TOPROW
        jr nc,.y1
.y0:    ld a,TOPROW
.y1:    ld (SKY_Y),a
        ld a,(HC)               ; s = 2*heading = 4q + 2sh
        add a,a
        ld c,a
        rrca
        rrca
        and $3F
        ld (.q+1),a
        ld a,c
        and 2                   ; B = 2sh
        ld b,a
        add a,a
        add a,a
        add a,a
        sub b                   ; 14*sh: pointer-table offset of this shift
        ld (.sb+1),a
.row:   ld a,(SKY_Y)
.sp:    cp 0
        ret nc
        ld (.cy+1),a
        ld e,a
        ld a,(.sp+1)
        sub e                   ; h = split - y
        dec a
        add a,a
.sb:    add a,0
        add a,SKYPTR & 255
        ld l,a
        ld h,SKYPTR/256
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
.q:     ld bc,0
        add hl,bc               ; HL = source bytes
        ld a,e                  ; DE = BUFFER + y*32
        rrca
        rrca
        rrca
        ld e,a
        and $1F
        add a,BUFFER/256
        ld d,a
        ld a,e
        and $E0
        ld e,a
.cy:    ld a,0
        push hl
        ld l,a
        ld h,ROWCL/256
        ld b,(hl)               ; CL
        add a,64
        ld l,a
        ld c,(hl)               ; CR
        pop hl
        ld a,b
        inc a
        jr nz,.cov
        ld bc,32                ; no track on this row
        ldir
        jr .nx
.cov:   ld a,b                  ; left of the track: min(32, (CL-64)/4) bytes
        sub 64
        jr c,.nol
        rrca
        rrca
        and $3F
        cp 33
        jr c,.lok
        ld a,32
.lok:   or a
        jr z,.nol
        push bc
        push hl
        push de
        ld c,a
        ld b,0
        ldir
        pop de
        pop hl
        pop bc
.nol:   ld a,c                  ; right of the track: from (CR-64)/4 + 1
        sub 64
        jr nc,.r1
        xor a
        jr .r2
.r1:    rrca
        rrca
        and $3F
        inc a
.r2:    cp 32
        jr nc,.nx
        ld c,a
        ld b,0
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        ld a,32
        sub c
        ld c,a
        ldir
.nx:    ld hl,SKY_Y
        inc (hl)
        jp .row

