; ---------------------------------------------------------------- render
setmode:                        ; A = mode 0..3
        ld (curmode),a
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
        ld de,modetab
        add hl,de
        ld de,m_nrays
        ld bc,11
        ldir
        ld hl,(m_drawcol)
        ld (dc_smc+1),hl
        ret

render:
        ld hl,(m_dest)
        ld (destp),hl
        xor a
        ld (ray),a
rn_l:
        call castray
        ld hl,(destp)
;@@PREDRAW@@
dc_smc: call drawcol1
        call poll
;@@SPRHOOK@@
        ld hl,(destp)
        ld a,(m_colstep)
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld (destp),hl
        ld a,(ray)
        inc a
        ld (ray),a
        ld hl,m_nrays
        cp (hl)
        jr nz,rn_l
        ld a,(m_buf)
        or a
        call nz,copybuf
        ret

copybuf:
        ld hl,BUF
        ld de,CRAM+40
        ld a,VIEWH
cb_l:
        ld (cbcnt),a
;@@LDI40@@
        call poll
        ld a,(cbcnt)
        dec a
        jr nz,cb_l
        ret

; cast one ray. In: A = ray index. Out: A = wall height, (texl) = texture column
castray:
        ld e,a
        ld d,0
        ld hl,(m_colang)
        add hl,de
        ld a,(pang)
        add a,(hl)
        ld (rayang),a
        ld hl,(m_cosoff)
        add hl,de
        ld a,(hl)
        ld (raycos),a
        ld a,(rayang)
        ld l,a
        ld h,SGN>>8
        ld a,(hl)
        ld (rayflg),a
        inc h
        ld e,(hl)
        inc h
        ld d,(hl)
        ld (dx_smc+1),de
        ld (dxv),de
        inc h
        ld c,(hl)
        inc h
        ld b,(hl)
        ld (dy_smc+1),bc
        ld (dyv),bc
        ld a,(rayflg)
        ld b,1
        rrca
        jr nc,sx_p
        ld b,0xFF
sx_p:
        ld a,b
        ld (sx_smc+1),a
        ld a,(rayflg)
        ld b,16
        bit 1,a
        jr z,sy_p
        ld b,0xF0
sy_p:
        ld a,b
        ld (sy_smc+1),a
        ; initial side distances
        ld a,(rayflg)
        rrca
        ld a,(pxf)
        jr c,sx1
        neg
        jr nz,sx1
        ld hl,(dxv)
        jr sx2
sx1:
        ld de,(dxv)
        call mul8
sx2:
        ld (sidex),hl
        ld a,(rayflg)
        and 2
        ld a,(pyf)
        jr nz,sy1
        neg
        jr nz,sy1
        ld hl,(dyv)
        jr sy2
sy1:
        ld de,(dyv)
        call mul8
sy2:
        ld (sidey),hl
        ld a,(pyc)
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(pxc)
        add a,b
        ex af,af'
        ld bc,(sidex)
        ld de,(sidey)
dda:
        ld h,b
        ld l,c
        or a
        sbc hl,de
        jr nc,ystep
dx_smc: ld hl,0
        add hl,bc
        ld b,h
        ld c,l
        ex af,af'
sx_smc: add a,1
        ld l,a
        ex af,af'
        ld h,MAP>>8
        ld a,(hl)
        or a
        jr z,dda
        ld (hittype),a
        xor a
        ld (hitside),a
        ld de,(dxv)
        ld h,b
        ld l,c
        or a
        sbc hl,de
        jr hitdone
ystep:
dy_smc: ld hl,0
        add hl,de
        ex de,hl
        ex af,af'
sy_smc: add a,16
        ld l,a
        ex af,af'
        ld h,MAP>>8
        ld a,(hl)
        or a
        jr z,dda
        ld (hittype),a
        ld a,1
        ld (hitside),a
        ex de,hl
        ld de,(dyv)
        or a
        sbc hl,de
hitdone:
        ld (perp),hl
        ; fisheye-corrected distance -> height
        ex de,hl
        ld a,(raycos)
        call mul8
        ld a,h
        cp 16
        jr c,hok
        ld hl,0x0FFF
hok:
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,h
        add a,HGT>>8
        ld h,a
        ld a,(hl)
        ld (hgt),a
        ; texture column
        ld a,(hitside)
        or a
        jr nz,u_s1
        ld a,(rayang)
        ld l,a
        ld h,SINM>>8
        ld a,(hl)
        ld de,(perp)
        call mul8
        ld a,(rayflg)
        and 2
        ld a,(pyf)
        jr nz,usub
        add a,l
        jr ucalc
usub:
        sub l
        jr ucalc
u_s1:
        ld a,(rayang)
        ld l,a
        ld h,COSM>>8
        ld a,(hl)
        ld de,(perp)
        call mul8
        ld a,(rayflg)
        rrca
        ld a,(pxf)
        jr c,usub
        add a,l
ucalc:
        rlca
        rlca
        rlca
        and 7
        ld b,a
        ld a,(hittype)
        dec a
        add a,a
        ld c,a
        ld a,(hitside)
        add a,c
        add a,a
        add a,a
        add a,a
        add a,b
        ld (texl),a
        ld a,(hgt)
        ret

;@@MUL8BEGIN@@ (a build may swap this routine for a faster one with the same result)
; HL = (DE * A) >> 8
mul8:
        ld hl,0
        ld c,0
        ld b,8
ml_l:
        add hl,hl
        rl c
        rla
        jr nc,ml_n
        add hl,de
        jr nc,ml_n
        inc c
ml_n:
        djnz ml_l
        ld l,h
        ld h,c
        ret
;@@MUL8END@@

; draw a 1-cell column. In: A = height, HL = dest (top of view), (texl)
drawcol1:
        ld c,a
        ld a,(texl)
        exx
        ld l,a
        ld d,VTAB>>8
        exx
        ld de,40
        ld b,TOPS>>8
        ld a,(bc)
        or a
        jr z,d1_nc
        ld b,a
d1_cl:
        ld (hl),CEIL
        add hl,de
        djnz d1_cl
d1_nc:
        ld b,VINIT>>8
        ld a,(bc)
        exx
        ld e,a
        exx
        ld b,VSTEP>>8
        ld a,(bc)
        exx
        ld b,a
        exx
        ld b,ROWS>>8
        ld a,(bc)
        ld b,a
d1_wl:
        exx
        ld a,e
        add a,b
        ld e,a
        ld a,(de)
        ld h,a
        ld a,(hl)
        exx
        ld (hl),a
        add hl,de
        djnz d1_wl
        ld b,FLRS>>8
        ld a,(bc)
        or a
        ret z
        ld b,a
d1_fl:
        ld (hl),FLOOR
        add hl,de
        djnz d1_fl
        ret

; draw a 2-cell-wide column
drawcol2:
        ld c,a
        ld a,(texl)
        exx
        ld l,a
        ld d,VTAB>>8
        exx
        ld de,40
        ld b,TOPS>>8
        ld a,(bc)
        or a
        jr z,d2_nc
        ld b,a
d2_cl:
        ld (hl),CEIL
        inc hl
        ld (hl),CEIL
        dec hl
        add hl,de
        djnz d2_cl
d2_nc:
        ld b,VINIT>>8
        ld a,(bc)
        exx
        ld e,a
        exx
        ld b,VSTEP>>8
        ld a,(bc)
        exx
        ld b,a
        exx
        ld b,ROWS>>8
        ld a,(bc)
        ld b,a
d2_wl:
        exx
        ld a,e
        add a,b
        ld e,a
        ld a,(de)
        ld h,a
        ld a,(hl)
        exx
        ld (hl),a
        inc hl
        ld (hl),a
        dec hl
        add hl,de
        djnz d2_wl
        ld b,FLRS>>8
        ld a,(bc)
        or a
        ret z
        ld b,a
d2_fl:
        ld (hl),FLOOR
        inc hl
        ld (hl),FLOOR
        dec hl
        add hl,de
        djnz d2_fl
        ret

; ---------------------------------------------------------------- helpers
; count vertical blank edges (one per 50Hz field). Clobbers A,F.
poll:
        ld a,(0xE002)
        and 0x80
pl_cmp: cp 0
        ret z
        ld (pl_cmp+1),a
        or a
        ret nz
        push hl
        ld hl,(fields)
        inc hl
        ld (fields),hl
        pop hl
        ret

