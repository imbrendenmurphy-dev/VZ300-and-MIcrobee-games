; MZRAY BENCH v0.1 - Sharp MZ-700 textured raycaster benchmark
; Colour-cell renderer: view rows 1-22, each cell's background colour is a pixel.
; VIBED BY BPM 2026

VIEWH   equ 22
CEIL    equ 0x00
FLOOR   equ 0x11
VRAM    equ 0xD000
CRAM    equ 0xD800

        org 0x1200
start:
        di
        ld sp,0x1200
        xor a
        ld (0xE008),a           ; speaker gate off
restart:
        call cls
        ld hl,s_title
        ld de,VRAM
        call print
        ld hl,s_test
        ld de,VRAM+33
        call print
        ld hl,s_b23
        ld de,VRAM+23*40
        call print
        ld hl,s_b24
        ld de,VRAM+24*40
        call print
        call bench_all
        call show_results
wait_mode:
        call getmode
        cp 0xFF
        jr z,wait_mode
        jp walk

; ---------------------------------------------------------------- bench
bench_all:
        xor a
ba_l:
        ld (testno),a
        call setmode
        ld a,(testno)
        add a,0x21
        ld (VRAM+38),a
        ld hl,0x0880
        ld (px),hl
        ld (py),hl
        xor a
        ld (pang),a
        ld hl,0
        ld (fields),hl
ba_s:
        call poll
        ld hl,(fields)
        ld a,h
        or l
        jr z,ba_s
        ld hl,0
        ld (fields),hl
        ld a,32
        ld (frcnt),a
ba_f:
        call render
        ld a,(pang)
        add a,8
        ld (pang),a
        ld a,(frcnt)
        dec a
        ld (frcnt),a
        jr nz,ba_f
        ld a,(testno)
        add a,a
        ld e,a
        ld d,0
        ld hl,results
        add hl,de
        ld de,(fields)
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,(testno)
        inc a
        cp 4
        jr nz,ba_l
        ret

show_results:
        call cls
        ld hl,s_r0
        ld de,VRAM+1*40+1
        call print
        ld hl,s_r1
        ld de,VRAM+3*40+1
        call print
        ld hl,s_r2
        ld de,VRAM+15*40+1
        call print
        ld hl,s_r3
        ld de,VRAM+18*40+1
        call print
        ld hl,s_r4
        ld de,VRAM+20*40+1
        call print
        ld hl,s_r5
        ld de,VRAM+21*40+1
        call print
        xor a
sr_l:
        ld (testno),a
        add a,a
        add a,5
        call rowaddr
        ld (rowp),hl
        ld a,(testno)
        add a,a
        ld e,a
        ld d,0
        ld hl,tstr
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,(rowp)
        inc de
        call print
        ld a,(testno)
        add a,a
        ld e,a
        ld d,0
        ld hl,results
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        ex de,hl
        call num5
        ld hl,(rowp)
        ld de,25
        add hl,de
        call p3
        pop de
        ld a,d
        or e
        jr z,sr_n
        ld hl,16000
        call div16
        call num5
        ld hl,(rowp)
        ld de,32
        add hl,de
        call pfps
sr_n:
        ld a,(testno)
        inc a
        cp 4
        jr nz,sr_l
        ret

; ---------------------------------------------------------------- walk mode
walk:
        push af
        call cls
        ld hl,s_w0
        ld de,VRAM
        call print
        ld hl,s_w23
        ld de,VRAM+23*40
        call print
        ld hl,s_w24
        ld de,VRAM+24*40
        call print
        pop af
walk_mode:
        call setmode
        ld a,(curmode)
        add a,a
        ld e,a
        ld d,0
        ld hl,mstr
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,VRAM+5
        call print
        ld hl,0
        ld (fields),hl
        ld (frames),hl
        ld (fps10),hl
        xor a
        ld (fpsc),a
wk_l:
        call render
        call controls
        ld hl,(frames)
        inc hl
        ld (frames),hl
        ld a,(fpsc)
        inc a
        ld (fpsc),a
        cp 16
        jr nz,wk_h
        xor a
        ld (fpsc),a
        ld de,(fields)
        ld hl,0
        ld (fields),hl
        ld a,d
        or e
        jr z,wk_h
        ld hl,8000
        call div16
        ld (fps10),hl
wk_h:
        ld hl,(fps10)
        call num5
        ld hl,VRAM+23*40+4
        call pfps
        ld hl,(frames)
        call num5
        ld hl,VRAM+23*40+18
        call p5
        jr wk_l

controls:
        ld a,7
        call keyrow
        ld (k7),a
        bit 2,a
        jr nz,ct1
        ld a,(pang)
        sub 4
        ld (pang),a
ct1:
        ld a,(k7)
        bit 3,a
        jr nz,ct2
        ld a,(pang)
        add a,4
        ld (pang),a
ct2:
        ld a,(k7)
        bit 5,a
        jr nz,ct3
        call fwdvec
        call move
ct3:
        ld a,(k7)
        bit 4,a
        jr nz,ct4
        call fwdvec
        ld a,b
        neg
        ld b,a
        ld a,c
        neg
        ld c,a
        call move
ct4:
        call getmode
        cp 0xFF
        jr z,ct5
        ld hl,curmode
        cp (hl)
        jr z,ct5
        pop hl
        jp walk_mode
ct5:
        ld a,4
        call keyrow
        bit 6,a
        ret nz
        pop hl
        jp restart

fwdvec:
        ld a,(pang)
        ld l,a
        ld h,COS8>>8
        ld a,(hl)
        sra a
        sra a
        ld b,a
        ld h,SIN8>>8
        ld a,(hl)
        sra a
        sra a
        ld c,a
        ret

move:                           ; B=dx C=dy (signed, 1/256 cell)
        ld a,b
        or a
        jr z,mv_y
        ld hl,(px)
        ld e,b
        ld d,0
        bit 7,b
        jr z,mv1
        dec d
mv1:
        add hl,de
        push hl
        ld de,0x0028
        bit 7,b
        jr z,mv2
        ld de,0xFFD8
mv2:
        add hl,de
        ld e,h
        ld a,(pyc)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,e
        ld l,a
        ld h,MAP>>8
        ld a,(hl)
        pop hl
        or a
        jr nz,mv_y
        ld (px),hl
mv_y:
        ld a,c
        or a
        ret z
        ld hl,(py)
        ld e,c
        ld d,0
        bit 7,c
        jr z,mv3
        dec d
mv3:
        add hl,de
        push hl
        ld de,0x0028
        bit 7,c
        jr z,mv4
        ld de,0xFFD8
mv4:
        add hl,de
        ld a,h
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,(pxc)
        add a,e
        ld l,a
        ld h,MAP>>8
        ld a,(hl)
        pop hl
        or a
        ret nz
        ld (py),hl
        ret

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
dc_smc: call drawcol1
        call poll
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

keyrow:                         ; A = row -> A = column bits (0 = pressed)
        or 0xF0
        ld (0xE000),a
        nop
        nop
        ld a,(0xE001)
        ret

getmode:                        ; A = 0..3 for keys 1-4, else 0xFF
        ld a,5
        call keyrow
        ld b,a
        ld a,0
        bit 7,b
        ret z
        inc a
        bit 6,b
        ret z
        inc a
        bit 5,b
        ret z
        inc a
        bit 4,b
        ret z
        ld a,0xFF
        ret

cls:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,999
        ld (hl),0
        ldir
        ld hl,CRAM
        ld de,CRAM+1
        ld bc,999
        ld (hl),0x70
        ldir
        ret

print:                          ; HL = string (display codes, FF end), DE = dest
        ld a,(hl)
        cp 0xFF
        ret z
        ld (de),a
        inc hl
        inc de
        jr print

rowaddr:                        ; A = row -> HL = VRAM + row*40
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,VRAM
        add hl,de
        ret

num5:                           ; HL -> numbuf (5 display-code digits)
        ld de,numbuf
        ld bc,-10000
        call nd
        ld bc,-1000
        call nd
        ld bc,-100
        call nd
        ld bc,-10
        call nd
        ld a,l
        add a,0x20
        ld (de),a
        ret
nd:
        ld a,0x1F
nd1:
        inc a
        add hl,bc
        jr c,nd1
        sbc hl,bc
        ld (de),a
        inc de
        ret

pfps:                           ; HL = dest; prints numbuf as dd.d
        ex de,hl
        ld a,(numbuf+2)
        cp 0x20
        jr nz,pf1
        xor a
pf1:
        ld (de),a
        inc de
        ld a,(numbuf+3)
        ld (de),a
        inc de
        ld a,0x2E
        ld (de),a
        inc de
        ld a,(numbuf+4)
        ld (de),a
        ret

p3:
        ex de,hl
        ld hl,numbuf+2
        ld bc,3
        ldir
        ret

p5:
        ex de,hl
        ld hl,numbuf
        ld bc,5
        ldir
        ret

div16:                          ; HL = HL / DE
        ld a,h
        ld c,l
        ld hl,0
        ld b,16
dv_l:
        sla c
        rla
        adc hl,hl
        sbc hl,de
        jr nc,dv_ok
        add hl,de
        jr dv_n
dv_ok:
        inc c
dv_n:
        djnz dv_l
        ld h,a
        ld l,c
        ret

; ---------------------------------------------------------------- data
s_title: dsc "MZ RAY BENCH V0.1"
s_test:  dsc "TEST"
s_b23:   dsc "RUNNING 4 TESTS OF 32 FRAMES EACH"
s_b24:   dsc "PLEASE WAIT"
s_r0:    dsc "MZ RAY BENCH V0.1   RESULTS"
s_r1:    dsc "TEST RAYS DRAW            FIELDS  FPS"
s_r2:    dsc "FIELDS ARE COUNTED PER 32 FRAMES"
s_r3:    dsc "PRESS 1 2 3 OR 4 TO WALK ABOUT"
s_r4:    dsc "CURSOR KEYS MOVE AND TURN"
s_r5:    dsc "B RUNS THE BENCHMARK AGAIN"
s_t0:    dsc "1    20   DIRECT"
s_t1:    dsc "2    20   BUFFERED"
s_t2:    dsc "3    40   DIRECT"
s_t3:    dsc "4    40   BUFFERED"
s_w0:    dsc "MODE"
s_w23:   dsc "FPS        FRAMES"
s_w24:   dsc "CURSORS MOVE  1 TO 4 MODE  B BENCH"
s_m0:    dsc "1  20 RAYS DIRECT  "
s_m1:    dsc "2  20 RAYS BUFFERED"
s_m2:    dsc "3  40 RAYS DIRECT  "
s_m3:    dsc "4  40 RAYS BUFFERED"
tstr:    dw s_t0,s_t1,s_t2,s_t3
mstr:    dw s_m0,s_m1,s_m2,s_m3

modetab:
        db 20,2,0
        dw CRAM+40,colang20,cosoff20,drawcol2
        db 20,2,1
        dw BUF,colang20,cosoff20,drawcol2
        db 40,1,0
        dw CRAM+40,colang40,cosoff40,drawcol1
        db 40,1,1
        dw BUF,colang40,cosoff40,drawcol1
;@@SMALLTABLES@@

; variables
m_nrays:   db 0
m_colstep: db 0
m_buf:     db 0
m_dest:    dw 0
m_colang:  dw 0
m_cosoff:  dw 0
m_drawcol: dw 0
curmode:   db 0
testno:    db 0
frcnt:     db 0
fpsc:      db 0
k7:        db 0
ray:       db 0
rayang:    db 0
raycos:    db 0
rayflg:    db 0
hittype:   db 0
hitside:   db 0
hgt:       db 0
texl:      db 0
cbcnt:     db 0
pang:      db 0
px:        dw 0
py:        dw 0
pxf        equ px
pxc        equ px+1
pyf        equ py
pyc        equ py+1
fields:    dw 0
frames:    dw 0
fps10:     dw 0
destp:     dw 0
rowp:      dw 0
dxv:       dw 0
dyv:       dw 0
sidex:     dw 0
sidey:     dw 0
perp:      dw 0
results:   dw 0,0,0,0
numbuf:    ds 5

;@@TABLES@@

BUF:    ds 880
