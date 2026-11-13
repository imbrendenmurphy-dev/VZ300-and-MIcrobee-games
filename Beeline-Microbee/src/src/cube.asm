; ==========================================================================
; cube.asm - CUBE.COM : true-polygon rendering experiment (ViBED by BPM 2026)
;
; A dither-shaded solid cube rasterised every frame into a 96x64 chunky
; (192x128 screen pixel) PCG bitmap, double buffered with the 6545 page flip.
;   - rotation/projection, back-face visibility and face shading come from a
;     64-step precomputed table (mkcube.py)
;   - edge scan conversion, span filling with dither masks, buffer clear and
;     page flip run live on the Z80 -> this measures raster throughput.
; The number shown top-left is frames per second (averaged over 16 frames).
; ==========================================================================
        org 100h
        jp start
        include "hw.asm"
        include "math.asm"

FB_COL  equ 20          ; framebuffer at cells (20..43, 4..11)
FB_ROW  equ 4
; page p uses PCG banks 1+2p (cell rows 0-4) and 2+2p (cell rows 5-7)

start:
        di
        ld sp,0EF00h
        call map_video
        call init_video
        ld hl,0
        ld (fields),hl
        ld (lastf),hl
        xor a
        ld (page),a
        ld (frame),a
        ld (fpsacc),a
        ld (fpscnt),a
        ld a,99
        ld (fpsval),a
        ; map both screen pages: cell (r,c) -> char (r mod 5)*24+c in its bank
        ld b,2
.pg     push bc
        ld a,b
        dec a
        ld (page),a
        call map_page
        pop bc
        djnz .pg
        xor a
        ld (page),a
        ld a,40h                ; title row colours, both pages
        out (PORT_08),a
        ld hl,PCGWIN+64
        ld b,64
.t0     ld (hl),(4<<4)|15
        inc hl
        djnz .t0
        ld hl,PCGWIN+400h+64
        ld b,64
.t1     ld (hl),(4<<4)|15
        inc hl
        djnz .t1
        xor a
        out (PORT_08),a
        ld hl,TITLE
        ld de,VRAM+64+20
        call print
        ld hl,TITLE
        ld de,VRAM+400h+64+20
        call print

P_frame:
loop:   ld hl,(fields)          ; fps accounting
        ld de,(lastf)
        ld (lastf),hl
        or a
        sbc hl,de
        ld a,l
        ld hl,fpsacc
        add a,(hl)
        ld (hl),a
        ld hl,fpscnt
        inc (hl)
        ld a,(hl)
        cp 16
        jr c,.nf
        ld (hl),0
        ld a,(fpsacc)
        ld c,a
        ld b,0
        xor a
        ld (fpsacc),a
        ld hl,800
        call div16
        ld a,l
        ld (fpsval),a
.nf
P_clear:
        call clear_fb
P_raster:
        call draw_cube
        call show_fps
P_wait:
        call wait_vb
        ld a,12
        out (CRTC_A),a
        ld a,(page)
        add a,a
        add a,a
        out (CRTC_D),a
        ld a,13
        out (CRTC_A),a
        xor a
        out (CRTC_D),a
        ld a,(page)
        xor 1
        ld (page),a
        ld a,(frame)
        inc a
        and CUBE_FRAMES-1
        ld (frame),a
        jp loop

; ---------------------------------------------------------------- mapping
map_page:
        ld c,0                  ; cell row 0..7
.r      ld a,c
        add a,FB_ROW
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,VRAM+FB_COL
        add hl,de
        ld a,(page)
        add a,a
        add a,a
        add a,h
        ld h,a                  ; HL -> screen cell
        ld a,c                  ; char base = (r mod 5)*24
        cp 5
        jr c,.a
        sub 5
.a      ld b,a
        add a,a
        add a,b
        add a,a
        add a,a
        add a,a                 ; *24
        or 80h
        ld b,24
        push hl
.cc     ld (hl),a
        inc hl
        inc a
        djnz .cc
        pop hl
        ld a,X1C_ATTR           ; attribute = bank
        out (PORT_1C),a
        ld a,(page)
        add a,a
        inc a
        ld b,a
        ld a,c
        cp 5
        ld a,b
        jr c,.b
        inc a
.b      ld b,24
        push hl
.ca     ld (hl),a
        inc hl
        djnz .ca
        pop hl
        ld a,X1C
        out (PORT_1C),a
        ld a,40h                ; colour: cyan on dark blue
        out (PORT_08),a
        ld a,h
        add a,8
        ld h,a
        ld b,24
.co     ld (hl),(4<<4)|14
        inc hl
        djnz .co
        xor a
        out (PORT_08),a
        inc c
        ld a,c
        cp 8
        jr c,.r
        ret

; ---------------------------------------------------------------- clear
; zero the back page's 192 characters (3072 bytes) with PUSH
clear_fb:
        ld a,(page)
        add a,a
        inc a
        or X1C
        out (PORT_1C),a         ; bank with rows 0-4: 120 chars = 1920 bytes
        ld hl,PCGWIN+1920
        ld b,1920/64
        call .sp
        ld a,(page)
        add a,a
        add a,2
        or X1C
        out (PORT_1C),a         ; rows 5-7: 72 chars = 1152 bytes
        ld hl,PCGWIN+1152
        ld b,1152/64
        call .sp
        ld a,X1C
        out (PORT_1C),a
        ret
.sp     ld (.ssp),sp
        ld sp,hl
        ld hl,0
.l      push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        push hl
        djnz .l
        ld sp,(.ssp)
        ret
.ssp    dw 0

; ---------------------------------------------------------------- cube
draw_cube:
        ; frame*28
        ld a,(frame)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl               ; *4
        ld d,h
        ld e,l
        add hl,hl               ; *8
        add hl,de               ; *12
        add hl,hl               ; *24
        add hl,de               ; *28
        ld de,CUBEDATA
        add hl,de
        ld a,(hl)
        inc hl
        or a
        ret z
        ld b,a
.f      push bc
        push hl
        call fill_quad
        pop hl
        ld de,9
        add hl,de
        pop bc
        djnz .f
        ret

; fill_quad: HL -> x0,y0,x1,y1,x2,y2,x3,y3,shade
fill_quad:
        ld de,QV
        ld bc,9
        ldir
        ld a,(QV+8)             ; dither pattern for this shade
        add a,a
        ld e,a
        ld d,0
        ld hl,PATS
        add hl,de
        ld a,(hl)
        ld (pe),a
        inc hl
        ld a,(hl)
        ld (po),a
        ; y range
        ld a,255
        ld (ymin),a
        xor a
        ld (ymax),a
        ld hl,QV+1
        ld b,4
.yr     ld a,(hl)
        ld c,a
        ld a,(ymin)
        cp c
        jr c,.y1
        ld a,c
        ld (ymin),a
.y1     ld a,(ymax)
        cp c
        jr nc,.y2
        ld a,c
        ld (ymax),a
.y2     inc hl
        inc hl
        djnz .yr
        ; init span tables over the range
        ld a,(ymin)
        ld l,a
        ld h,high(XL)
        ld a,(ymax)
        sub l
        inc a
        ld b,a
.in     ld (hl),255
        inc h
        ld (hl),0
        dec h
        inc l
        djnz .in
        ; 4 edges
        ld hl,QV
        ld b,4
.ed     push bc
        push hl
        ld a,(hl)
        ld (ex0),a
        inc hl
        ld a,(hl)
        ld (ey0),a
        inc hl
        ld a,b
        cp 1
        jr nz,.nx
        ld hl,QV                ; last edge wraps to vertex 0
.nx     ld a,(hl)
        ld (ex1),a
        inc hl
        ld a,(hl)
        ld (ey1),a
        call edge
        pop hl
        inc hl
        inc hl
        pop bc
        djnz .ed
        ; spans
        ld a,(ymin)
        ld (sy),a
.sp     ld a,(sy)
        ld l,a
        ld h,high(XL)
        ld a,(hl)
        ld (sxl),a
        inc h
        ld a,(hl)
        ld (sxr),a
        call span
        ld a,(sy)
        ld hl,ymax
        cp (hl)
        ret z
        inc a
        ld (sy),a
        jr .sp

; edge: (ex0,ey0)-(ex1,ey1) -> min/max into XL/XR
edge:
        ld a,(ey0)
        ld b,a
        ld a,(ey1)
        cp b
        ret z                   ; horizontal: endpoints covered by other edges
        jr nc,.ok
        ld a,(ex0)              ; swap so y0 < y1
        ld c,a
        ld a,(ex1)
        ld (ex0),a
        ld a,c
        ld (ex1),a
        ld a,(ey0)
        ld c,a
        ld a,(ey1)
        ld (ey0),a
        ld a,c
        ld (ey1),a
.ok     ld a,(ey0)
        ld b,a
        ld a,(ey1)
        sub b
        ld c,a                  ; dy (1..63)
        ld a,(ex1)
        ld hl,ex0
        sub (hl)                ; dx (signed)
        ld (.sg),a
        jp p,.pos
        neg
.pos    ; step = |dx|*256/dy  (8.8): 16/8 restoring division
        ld h,a
        ld l,0
        xor a
        ld b,16
.dl     add hl,hl
        rla
        jr c,.sub
        cp c
        jr c,.nsub
.sub    sub c
        inc l
.nsub   djnz .dl
        ; HL = quotient (8.8 step), sign
        ld a,(.sg)
        or a
        jp p,.sp
        call neghl
.sp     ld (.step),hl
        ld a,(ex0)
        ld h,a
        ld l,80h                ; x = x0 + 0.5
        ld a,(ey1)
        ld b,a
        ld a,(ey0)
        ld c,a
        ld a,b
        sub c
        inc a
        ld b,a                  ; rows to do
        ld e,c                  ; y
        ld d,high(XL)
.yl     ld a,h                  ; x integer part
        ex de,hl
        cp (hl)
        jr nc,.n1
        ld (hl),a
.n1     inc h
        cp (hl)
        jr c,.n2
        ld (hl),a
.n2     dec h
        inc l
        ex de,hl
        push de
        ld de,(.step)
        add hl,de
        pop de
        djnz .yl
        ret
.sg     db 0
.step   dw 0

; span: line (sy), x from (sxl) to (sxr) inclusive, pattern (pe)/(po)
span:
        ld a,(sxr)
        ld b,a
        ld a,(sxl)
        cp b
        ret z                   ; zero-width (also catches untouched lines? xl=255)
        ret nc
        ; cell row / bank
        ld a,(sy)
        rrca
        rrca
        rrca
        and 1Fh                 ; cell row r
        ld c,a
        ld a,(page)
        add a,a
        inc a                   ; bank for rows 0-4
        ld b,a
        ld a,c
        cp 5
        jr c,.b0
        inc b
        sub 5
.b0     ld c,a                  ; row within bank
        ld a,b
        or X1C
        out (PORT_1C),a
        ; address = F800 + (rr*24 + xl/4)*16 + 2*(y&7)
        ld a,c
        add a,a
        add a,c
        add a,a
        add a,a
        add a,a                 ; rr*24
        ld c,a
        ld a,(sxl)
        rrca
        rrca
        and 3Fh
        add a,c
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(sy)
        and 7
        add a,a
        add a,l
        ld l,a
        ld de,PCGWIN
        add hl,de
        ; cell count
        ld a,(sxl)
        rrca
        rrca
        and 3Fh
        ld c,a
        ld a,(sxr)
        rrca
        rrca
        and 3Fh
        sub c                   ; number of extra cells
        ld c,a
        ; left mask
        ld a,(sxl)
        and 3
        ld e,a
        ld d,0
        push hl
        ld hl,LMASK
        add hl,de
        ld b,(hl)               ; left mask
        ld a,(sxr)
        and 3
        ld e,a
        ld hl,RMASK
        add hl,de
        ld a,(hl)
        pop hl
        ld e,a                  ; right mask
        ld a,c
        or a
        jr nz,.multi
        ld a,b                  ; single cell: mask = L & R
        and e
        jr .last
.multi  ld a,b
        call .put
        ld de,16
        add hl,de
        dec c
        jr z,.r
.mid    ld a,(pe)
        ld (hl),a
        inc hl
        ld a,(po)
        ld (hl),a
        ld de,15
        add hl,de
        dec c
        jr nz,.mid
.r      push hl
        ld a,(sxr)
        and 3
        ld e,a
        ld d,0
        ld hl,RMASK
        add hl,de
        ld a,(hl)
        pop hl
.last   call .put
        ret
; OR pattern under mask A into (HL),(HL+1)
.put    ld d,a
        ld a,(pe)
        and d
        or (hl)
        ld (hl),a
        inc hl
        ld a,(po)
        and d
        or (hl)
        ld (hl),a
        dec hl
        ret

LMASK:  db 0FFh,3Fh,0Fh,03h
RMASK:  db 0C0h,0F0h,0FCh,0FFh
; dither patterns per shade (even line, odd line): dark .. bright
PATS:   db 00h,00h, 88h,22h, 0AAh,55h, 0EEh,0BBh, 0FFh,0FFh

; ---------------------------------------------------------------- text
show_fps:
        ld a,(fpsval)
        ld l,a
        ld h,0
        ld de,FPSTXT+4
        call put2b
        ld hl,FPSTXT
        ld a,(page)
        add a,a
        add a,a
        add a,high(VRAM)
        ld d,a
        ld e,64+4
        jp print
FPSTXT: db "FPS 00",0
TITLE:  db "SOLID POLYGON TEST",0

put2b:  ld bc,10
        ld a,'0'-1
.d      inc a
        or a
        sbc hl,bc
        jr nc,.d
        add hl,bc
        ld (de),a
        inc de
        ld a,l
        add a,'0'
        ld (de),a
        ret

print:  ld a,(hl)
        or a
        ret z
        push hl
        push de
        sub 32
        add a,a
        ld l,a
        ld h,0
        ld bc,FONTMAP
        add hl,bc
        ld a,(hl)
        ld (de),a
        inc hl
        ld c,(hl)
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld a,c
        ld (de),a
        ld a,X1C
        out (PORT_1C),a
        pop de
        pop hl
        inc hl
        inc de
        jr print

div16:  ld de,0
.l      or a
        sbc hl,bc
        jr c,.d
        inc de
        jr .l
.d      ex de,hl
        ret

neghl:  xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

        include "../build/cube.inc"
        include "../build/gfx.inc"
PCGDATA:
        incbin "../build/pcg.bin"
page:   db 0
frame:  db 0
lastf:  dw 0
fpsacc: db 0
fpscnt: db 0
fpsval: db 0
QV:     ds 9
pe:     db 0
po:     db 0
ymin:   db 0
ymax:   db 0
ex0:    db 0
ey0:    db 0
ex1:    db 0
ey1:    db 0
sy:     db 0
sxl:    db 0
sxr:    db 0
        align 256
XL:     ds 256
XR:     ds 256
