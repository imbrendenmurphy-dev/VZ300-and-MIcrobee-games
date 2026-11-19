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

;@@RAYCORE@@
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
