; ==========================================================================
; roadtest.asm - ROADTEST.COM : OutRun-style road prototype
; VIBED BY BPM 2026
;
; The road is not projected.  Its 64 logical lines (screen rows 8-15) each
; have a fixed distance and width (tools/mkroadtest.py).  Every frame, line
; by line from the bottom up:
;     dx += curve(segment at this line's distance) ; x += dx
;     centre = 128 + x/256 - player offset * width
;     band   = bit 6 of (position + distance)        -> stripes roll down
; Each road row is then built from PCG characters in the hidden page:
; one verge and one road character (the 8 lines' band patterns), plus one
; character per column that a road edge crosses in that row, composited
; line by line.  The player's car is laid over rows 13-15.
;
; Keys: M/up accelerate, N/down brake, Z X (, . or cursor) steer,
;       A autopilot on/off (starts on).   Top line: FPS and speed.
; ==========================================================================
        org 100h
        jp start
        include "hw.asm"

ROW0    equ 8                   ; first road row
FARL    equ 8                   ; lines 0..7 (row 8) use the far pattern
CARCOL  equ 27                  ; car: columns 27-36, rows 13-15
MAXSPD  equ 22*256              ; z units per field, 8.8
ACC     equ 22
BRAKE   equ 64
DRAG    equ 8
STEER   equ 7
PXMAX   equ 140                 ; road edges at +-128
FRAMEFIELDS equ 2

COL_FAR  equ 2                  ; ground ink (on black): rows 8-9
COL_NEAR equ 10                 ; rows 10-15
COL_LIGHT equ 9                 ; tail lights
COL_HUD  equ 0Fh
PANO_COLA equ (14<<4)|15
PANO_COLB equ (14<<4)|0

start:
        di
        ld sp,0EF00h
        call map_video
        call init_video
        call init_screen
        ld hl,0
        ld (fields),hl
        ld (flipf),hl
        ld (lastf),hl
        ld a,1
        ld (dt),a
        jp loop

; --------------------------------------------------------------------------
; static screen set-up for both pages
; --------------------------------------------------------------------------
init_screen:
        xor a
.pg     ld (page),a
        ; colours
        ld a,40h
        out (PORT_08),a
        call pagebase           ; HL = VRAM + page*400h
        ld a,h
        add a,8
        ld h,a                  ; colour RAM (F800 window)
        ld de,ROWCOLS
        ld c,16
.cr     ld a,(de)
        ld b,64
.cf     ld (hl),a
        inc hl
        djnz .cf
        inc de
        dec c
        jr nz,.cr
        xor a
        out (PORT_08),a
        ; sky rows 1-5: code + attribute
        call pagebase
        ld de,64
        add hl,de
        ld de,SKYROWS
        ld c,5
.sr     ld a,(de)
        ld b,64
        push hl
.sf     ld (hl),a
        inc hl
        djnz .sf
        pop hl
        inc de
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld a,(de)
        ld b,64
        push hl
.sa     ld (hl),a
        inc hl
        djnz .sa
        pop hl
        ld a,X1C
        out (PORT_1C),a
        inc de
        push de
        ld de,64
        add hl,de
        pop de
        dec c
        jr nz,.sr
        ; road rows: attribute = this page's bank for the row
        call pagebase
        ld de,ROW0*64
        add hl,de
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld c,0
.ar     ld a,(page)
        add a,a
        inc a
        bit 2,c
        jr z,.ab
        inc a
.ab     ld b,64
.af     ld (hl),a
        inc hl
        djnz .af
        inc c
        ld a,c
        cp 8
        jr c,.ar
        ld a,X1C
        out (PORT_1C),a
        ; HUD text
        call pagebase
        ld e,l
        ld d,h
        ld hl,HUDTXT
        call print
        ld a,(page)
        inc a
        cp 2
        jp c,.pg
        xor a
        ld (page),a             ; draw page 0 first (page 1 is shown)
        ld a,12
        out (CRTC_A),a
        ld a,4
        out (CRTC_D),a
        ld a,13
        out (CRTC_A),a
        xor a
        out (CRTC_D),a
        ret

ROWCOLS: db COL_HUD,4<<4,(4<<4)|12,12<<4,(12<<4)|14,14<<4,PANO_COLA,PANO_COLB
        db COL_FAR,COL_FAR,COL_NEAR,COL_NEAR,COL_NEAR,COL_NEAR,COL_NEAR,COL_NEAR
SKYROWS: db 20h,0                ; code, attribute (colours in ROWCOLS)
        db D50_CODE,D50_ATTR
        db 20h,0
        db D50_CODE,D50_ATTR
        db 20h,0
HUDTXT: db "ROADTEST   FPS 00   SPEED 000   AUTO   VIBED BY BPM 2026",0
HUD_FPS equ 15
HUD_SPD equ 26
HUD_MODE equ 32

; HL = VRAM + page*400h
pagebase:
        ld a,(page)
        add a,a
        add a,a
        add a,high(VRAM)
        ld h,a
        ld l,0
        ret

; ==========================================================================
; main loop
; ==========================================================================
loop:
        call vbpoll
        ; frame time -> dt (fields), fps every 16 frames
        ld hl,(fields)
        ld de,(lastf)
        ld (lastf),hl
        or a
        sbc hl,de
        ld a,l
        or a
        jr nz,.d1
        inc a
.d1     cp 5
        jr c,.d2
        ld a,4
.d2     ld (dt),a
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
P_input:
        call read_input
P_phys:
        call physics
        call car_pose
P_lines:
        call calc_lines
        call vbpoll
P_rows:
        xor a
.rl     ld (crow),a
        call draw_row
        call vbpoll
        ld a,(crow)
        inc a
        cp 8
        jr c,.rl
P_pano:
        call draw_pano
        call vbpoll
        call draw_hud
P_wait:
.w      call vbpoll
        ld hl,(fields)
        ld de,(flipf)
        or a
        sbc hl,de
        ld a,l
        cp FRAMEFIELDS
        jr c,.w
        in a,(CRTC_A)           ; late: flip only inside vertical blank
        and 20h
        call z,wait_vb
        ld hl,(fields)
        ld (flipf),hl
        ld a,12                 ; show the page just drawn
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
        jp loop

; --------------------------------------------------------------------------
; input: keys bits 1 left, 2 right, 4 accelerate, 8 brake; A toggles autopilot
; --------------------------------------------------------------------------
read_input:
        ld b,0
        ld hl,keymap
.k      ld a,(hl)
        or a
        jr z,.done
        push bc
        push hl
        call keytest
        pop hl
        pop bc
        inc hl
        jr z,.nk
        ld a,(hl)
        or b
        ld b,a
.nk     inc hl
        jr .k
.done   ld a,b
        and 16
        ld c,a
        ld a,(lastA)
        cpl
        and c
        ld a,c
        ld (lastA),a
        jr z,.na
        ld a,(auto)
        xor 1
        ld (auto),a
.na     ld a,b
        and 15
        jr z,.nm
        ld c,a                  ; any driving key takes over
        xor a
        ld (auto),a
        ld a,c
.nm     ld (keys),a
        ld a,(auto)
        or a
        ret z
        ; autopilot: full throttle, steer back towards the middle
        ld c,4
        ld hl,(px)
        ld de,(pxaim)
        or a
        sbc hl,de
        bit 7,h
        jr nz,.al
        ld a,l
        cp 10
        jr c,.ak
        set 0,c
        jr .ak
.al     ld a,l
        cp -10
        jr nc,.ak
        set 1,c
.ak     ld a,c
        ld (keys),a
        ret
keymap: db K_Z,1, K_COMMA,1, K_LEFT,1
        db K_X,2, K_DOT,2, K_RIGHT,2
        db K_M,4, K_UP,4
        db K_N,8, K_DOWN,8
        db K_A,16
        db 0

; --------------------------------------------------------------------------
; physics: dt field steps
; --------------------------------------------------------------------------
physics:
        ; curve under the car, scaled by speed (per field)
        ld hl,(pos)
        ld de,96
        add hl,de
        ld l,h
        ld h,high(TRACKL)
        ld a,(hl)
        ld (cp_),a
        ld e,a                  ; cs = curve * speed_hi
        rla
        sbc a,a
        ld d,a
        ld hl,0
        ld a,(speed+1)
        or a
        jr z,.cz
        ld b,a
.cm     add hl,de
        djnz .cm
.cz     ld (cs),hl
        ld a,(cp_)              ; autopilot aims into the bend a little
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        ld (pxaim),hl
        ld a,(dt)
        ld b,a
.f      push bc
        call phys1
        pop bc
        djnz .f
        ret

phys1:
        ld a,(keys)
        ld c,a
        ld hl,(speed)
        bit 2,c
        jr z,.na
        ld de,ACC
        add hl,de
        ld de,MAXSPD
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.sp
        ex de,hl
        jr .sp
.na     ld de,DRAG
        bit 3,c
        jr z,.dr
        ld de,BRAKE
.dr     or a
        sbc hl,de
        jr nc,.sp
        ld hl,0
.sp     ; off the road: hold the speed down
        push hl
        ld hl,(px)
        bit 7,h
        jr z,.ab
        xor a
        sub l
        ld l,a
.ab     ld a,l
        pop hl
        cp 136
        jr c,.on
        ld a,h
        cp 8
        jr c,.on
        ld de,-48
        add hl,de
.on     ld (speed),hl
        ; position
        ld a,(posf)
        add a,l
        ld (posf),a
        ld e,h
        ld d,0
        ld hl,(pos)
        adc hl,de
        ld (pos),hl
        ; panorama scroll
        ld hl,(pan)
        ld de,(cs)
        add hl,de
        ld (pan),hl
        ; steering (only when moving)
        ld a,(speed+1)
        or a
        ret z
        ld hl,(px)
        bit 0,c
        jr z,.nl
        ld de,-STEER
        add hl,de
.nl     bit 1,c
        jr z,.nr
        ld de,STEER
        add hl,de
.nr     ; centrifugal: px -= cs/64
        ex de,hl
        ld hl,(cs)
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ex de,hl
        or a
        sbc hl,de
        ; clamp
        ld de,PXMAX
        bit 7,h
        jr nz,.neg
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.ok
        ex de,hl
        jr .ok
.neg    ld de,-PXMAX
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.ok
        ex de,hl
.ok     ld (px),hl
        ret

; --------------------------------------------------------------------------
; calc_lines: the 64 lines in 32 pairs p (0 = horizon).  Band phase per line,
; road edges per pair.  At IY = LINES+128+p:
;   (iy-128) left edge column (biased +1: 0 = off the left, 65 = off the right)
;   (iy-64)  PLT index of the left partial cell: (v*4 + sub)*4, v = 3*pa + pb
;   (iy+0)   right edge column ;  (iy+64) PLT+256 index of the right partial
; --------------------------------------------------------------------------
calc_lines:
        ld hl,(px)              ; K = px*3.5 (1/256 px per line)
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        sra h
        rr l
        push hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de               ; 33K
        add hl,hl               ; 66K
        xor a                   ; P = -66K (24 bits, top byte in IXH)
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        rla
        sbc a,a
        ld de,132*256           ; + centre 128 + 4 column bias
        add hl,de
        adc a,0
        ld ixh,a
        pop de
        ex de,hl
        add hl,hl               ; dP = 2K
        push hl
        push de
        exx
        pop hl
        pop de
        exx
        ld iy,LINES+128+31
        ld b,31
.l      ld a,b                  ; z of the pair's two lines
        add a,a
        add a,a
        ld l,a
        ld h,high(ZT)
        ld e,(hl)
        inc l
        ld d,(hl)
        inc l
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,b
        cp FARL/2
        jr c,.far
        push de
        ld de,(pos)
        add hl,de               ; lower line: s = pos + z
        ld a,l
        and 40h                 ; pb (0/1) -> 16*pb
        rrca
        rrca
        ld c,a
        ld a,h                  ; segment
        ex af,af'
        pop hl
        add hl,de               ; upper line
        ld a,l
        and 40h                 ; pa -> 48*pa
        rrca
        rrca
        ld l,a
        add a,a
        add a,l
        add a,c
        ld c,a                  ; C = 16*v
        ex af,af'
        jr .cv
.far    ld de,(pos)
        add hl,de
        ld a,h
        ld c,8*16
.cv     exx                     ; dP += 4*curve, P += dP
        ld c,a
        ld b,high(TRACK4L)
        ld a,(bc)
        add a,e
        ld e,a
        inc b
        ld a,(bc)
        adc a,d
        ld d,a
        rla
        sbc a,a
        add hl,de
        adc a,ixh
        ld ixh,a
        ld a,h
        exx
        ld l,a
        ld a,ixh
        ld h,a                  ; HL = centre + 4 (column bias)
        ld a,b
        or 0C0h
        ld e,a
        ld d,high(ZT)
        ld a,(de)               ; WP[p]
        ld e,a
        ld d,0
        push hl
        or a
        sbc hl,de               ; left edge
        ld a,h
        or a
        jr nz,.lx
        ld a,l
        and 3
        add a,a
        add a,a
        or c
        ld (iy-64),a
        ld a,l
        rrca
        rrca
        and 3Fh
        ld (iy-128),a
.ld     pop hl
        add hl,de               ; right edge
        ld a,h
        or a
        jr nz,.rx
        ld a,l
        and 3
        add a,a
        add a,a
        or c
        ld (iy+64),a
        ld a,l
        rrca
        rrca
        and 3Fh
        ld (iy+0),a
.rd     dec iy
        dec b
        jp p,.l
        ret
.lx     push de
        call cvt
        ld (iy-128),d
        ld (iy-64),e
        pop de
        jr .ld
.rx     call cvt
        ld (iy+0),d
        ld (iy+64),e
        jr .rd

; cvt (off-screen cases): HL = x+4, H <> 0 -> D = column+1, E = sub*4 | C
cvt:    bit 7,h
        jr z,.big
        ld d,0
        ld e,c
        ret
.big    dec h
        jr nz,.r65
        ld a,l
        cp 4
        jr nc,.r65
        add a,a
        add a,a
        or c
        ld e,a
        ld d,64
        ret
.r65    ld d,65
        ld e,c
        ret

; --------------------------------------------------------------------------
; draw_row: road row crow (0..7 = screen row 8..15) into the hidden page.
; The row's 32 PCG slots: 0-15 edge cells (page 0 of the row's 512 bytes),
; 16 verge, 17 road, 18-31 car cells over plain verge/road.
; --------------------------------------------------------------------------
draw_row:
        ld a,(crow)
        add a,a
        add a,a
        ld (lbase),a            ; first line pair
        ld a,(page)             ; PCG bank: 1 + 2*page + (crow>>2)
        add a,a
        inc a
        ld c,a
        ld a,(crow)
        cp 4
        ld a,c
        jr c,.b0
        inc a
.b0     ld (rbank),a
        or X1C
        out (PORT_1C),a
        ld a,(crow)
        and 3
        ld c,a
        add a,a
        add a,high(PCGWIN)
        ld (rbase+1),a
        xor a
        ld (rbase),a
        ld a,c                  ; code base 80h + (crow&3)*32
        rrca
        rrca
        rrca
        or 80h
        ld (cbase),a
        ; edge ranges over the row's 8 lines
        ld a,(lbase)
        ld l,a
        ld h,high(LINES)
        call minmax
        ld (lmin),de
        ld a,(lbase)
        or 128
        ld l,a
        call minmax
        ld (rmin),de
        ; A = [a0,a1)  B = [b0,b1)   (biased columns 1..65)
        ld a,(lmin)
        ld b,1
        ld c,65
        call clamp
        ld (ra0),a
        ld a,(lmax)
        inc a
        ld hl,rmin
        cp (hl)
        jr c,.sep
        ld a,(rmax)             ; edges meet: one range
        ld hl,lmax
        cp (hl)
        jr nc,.m1
        ld a,(hl)
.m1     inc a
        ld b,a
        ld a,(ra0)
        ld c,a
        ld a,b
        ld b,c
        ld c,65
        call clamp
        ld (ra1),a
        ld (rb0),a
        ld (rb1),a
        jr .rng
.sep    ld b,a
        ld a,(ra0)
        ld c,a
        ld a,b
        ld b,c
        ld c,65
        call clamp
        ld (ra1),a
        ld b,a
        ld a,(rmin)
        call clamp
        ld (rb0),a
        ld b,a
        ld a,(rmax)
        inc a
        call clamp
        ld (rb1),a
.rng    ld a,(ra1)              ; at most 16 edge cells
        ld hl,ra0
        sub (hl)
        cp 16
        jr c,.k1
        ld a,16
        add a,(hl)
        ld (ra1),a
        ld a,16
.k1     ld (lena),a
        ld b,a
        ld a,16
        sub b
        ld c,a
        ld a,(rb1)
        ld hl,rb0
        sub (hl)
        cp c
        jr c,.k2
        ld a,c
        add a,(hl)
        ld (rb1),a
        ld a,c
.k2     add a,b
        ld (RC+2),a             ; N = edge cells
        ld a,(ra0)
        ld (RC+0),a             ; a0
        ld hl,ra1
        sub (hl)
        ld hl,rb0
        add a,(hl)
        ld (RC+1),a             ; a0 + (b0 - a1): column -> slot offset of range B
        ; ---- the 4 line pairs
        call vbpoll
        ld ix,RC
        ld a,(lbase)
        add a,128
        ld l,a
        ld h,high(LINES)
        push hl
        pop iy
        xor a
.line   ld (li),a
        add a,a
        add a,a
        ld l,a
        ld c,a
        ld a,(iy-64)            ; band phases -> emitter
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        add a,a                 ; emitters are 512 bytes apart
        add a,high(EMIT0)
        ld (.call+2),a
        ld a,(rbase+1)
        ld h,a
        inc a
        ld b,a
        ld de,13
.call   call EMIT0
        inc iy
        ld a,(li)
        inc a
        cp 4
        jr c,.line
        call vbpoll
        ; ---- screen codes (unless this page's row already has these ranges)
        ld a,(page)
        add a,a
        add a,a
        add a,a
        ld hl,crow
        add a,(hl)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,lastrng
        add hl,de
        ld de,ra0
        ld b,4
        ld c,0
.cmp    ld a,(de)
        cp (hl)
        jr z,.ceq
        ld (hl),a
        inc c
.ceq    inc hl
        inc de
        djnz .cmp
        ld a,c
        ld (rchg),a
        call pagebase
        ld a,(crow)
        add a,ROW0
        rrca
        rrca
        ld e,a
        and 0C0h
        ld l,a
        ld a,e
        and 03h
        add a,h
        ld h,a                  ; HL = row start
        ld (raddr),hl
        ld a,(rchg)
        ld c,a
        ld a,(carnew)           ; (a new car pose rewrites the car rows)
        or c
        jr z,.same
        ld a,(cbase)
        add a,16
        ld d,a                  ; D = verge code, D+1 road
        ld a,(ra0)              ; [1,a0) verge
        dec a
        ld b,a
        ld a,d
        call fill
        ld a,(ra1)              ; [a0,a1) edge slots
        ld c,a
        ld a,(ra0)
        ld b,a
        ld a,c
        sub b
        ld b,a
        ld a,(cbase)
        call seq
        ld e,a
        ld a,(rb0)              ; [a1,b0) road
        ld c,a
        ld a,(ra1)
        ld b,a
        ld a,c
        sub b
        ld b,a
        ld a,d
        inc a
        call fill
        ld a,(rb1)              ; [b0,b1) edge slots
        ld c,a
        ld a,(rb0)
        ld b,a
        ld a,c
        sub b
        ld b,a
        ld a,e
        call seq
        ld a,(rb1)              ; [b1,65) verge
        ld b,a
        ld a,65
        sub b
        ld b,a
        ld a,d
        call fill
.same   ld a,(crow)
        cp 5
        call nc,draw_car
        ld a,X1C
        out (PORT_1C),a
        ret

; fill: B cells at HL (within one 64-cell row) with code A, unrolled
fill:   inc b
        dec b
        ret z
        ld c,a
        ld a,b
        add a,a
        neg
        ld (.j+1),a
        ld a,c
.j      jp FILLBLK
; seq: A, A+1, ... (returns the next code in A)
seq:    inc b
        dec b
        ret z
.l      ld (hl),a
        inc l
        inc a
        djnz .l
        ret

; clamp: A into [B, C]
clamp:  cp b
        jr nc,.lo
        ld a,b
.lo     cp c
        ret c
        ld a,c
        ret

; minmax: 4 bytes at HL -> E = min, D = max
minmax: ld a,(hl)
        ld e,a
        ld d,a
        ld b,3
.l      inc l
        ld a,(hl)
        cp e
        jr nc,.n1
        ld e,a
.n1     cp d
        jr c,.n2
        ld d,a
.n2     djnz .l
        ret

; --------------------------------------------------------------------------
; draw_car: rows 13-15 (crow 5-7).  Cell types: 0 empty, 1 opaque static,
; 2 opaque with tail light, 3 partial: over plain verge/road it is copied
; from CARROAD (pre-composited per line and band phase), over an edge cell
; it is composited in place
; --------------------------------------------------------------------------
draw_car:
        ld a,(lbase)            ; OFFP[i] = 14i + 2*phase (ldi walks C down by 2)
        add a,64
        ld l,a
        ld h,high(LINES)
        ld de,OFFP
        ld c,0
        ld b,4
.o      ld a,(hl)
        rrca
        rrca
        rrca
        and 1Eh                 ; 2v
        push hl
        add a,low(PAB)
        ld l,a
        ld a,high(PAB)
        adc a,0
        ld h,a
        ld a,(hl)
        add a,c
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        add a,c
        add a,14
        ld (de),a
        inc de
        pop hl
        inc l
        ld a,c
        add a,28
        ld c,a
        djnz .o
        ld a,(crow)             ; cell list of this pose and row
        sub 5
        ld c,a
        ld a,(carpose)
        ld b,a
        add a,a
        add a,b
        add a,c
        add a,a
        ld l,a
        ld h,0
        ld de,CARL
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(rbase+1)          ; new slots from 18 (second page of the row, +32)
        inc a
        ld d,a
        ld e,32
        ld a,(cbase)
        add a,18
        ld (ccode),a
        ld a,(hl)
        inc hl
        or a
        jp z,.opq
        ld b,a
        ld a,(ra1)              ; edges clear of the car's columns: all over road
        cp CARCOL+2
        jp nc,.slow
        ld a,(rb0)
        cp CARCOL+11
        jp c,.slow
.f      push bc
        ld a,(hl)               ; screen code
        inc hl
        push hl
        ld hl,(raddr)
        add a,CARCOL
        add a,l
        ld l,a
        ld a,(ccode)
        ld (hl),a
        inc a
        ld (ccode),a
        pop hl
        ld a,(hl)
        inc hl
        add a,high(CARROAD)
        ld b,a
        ld a,(hl)
        inc hl
        inc hl
        add a,6                 ; road
        ld c,a
        push hl
        ld h,b
        call carcopy
        pop hl
        pop bc
        djnz .f
        jp .opq
.slow   push bc
        ld a,(hl)
        inc hl
        ld (cx),a
        ld a,(hl)
        inc hl
        ld (cpg),a
        ld a,(hl)
        inc hl
        ld (clo),a
        ld a,(hl)
        inc hl
        ld (cidx),a
        push hl
        push de
        ld a,(cx)
        add a,CARCOL+1          ; biased column
        ld hl,ra0
        cp (hl)
        jr c,.uv
        ld hl,ra1
        cp (hl)
        jr nc,.inb
        ld hl,ra0
        sub (hl)
        jr .inp
.inb    ld hl,rb0
        cp (hl)
        jr c,.ur
        ld hl,rb1
        cp (hl)
        jr nc,.uv
        ld hl,RC+1
        sub (hl)
.inp    add a,a                 ; edge cell: composite in place
        add a,a
        add a,a
        add a,a
        ld hl,(rbase)
        ld l,a
        call comp_edge
        pop de
        jr .sn
.ur     ld c,6
        jr .new
.uv     ld c,0
.new    ld hl,(raddr)
        ld a,(cx)
        add a,CARCOL
        add a,l
        ld l,a
        ld a,(ccode)
        ld (hl),a
        inc a
        ld (ccode),a
        ld a,(clo)
        add a,c
        ld c,a
        ld a,(cpg)
        add a,high(CARROAD)
        ld h,a
        pop de
        call carcopy
.sn     pop hl
        pop bc
        djnz .slow
.opq    ld a,(hl)               ; opaque cells: their static codes
        inc hl
        or a
        jr z,.ac
        ld b,a
        ld de,(raddr)
.oq     ld a,(raddr)
        add a,CARCOL
        add a,(hl)
        ld e,a
        inc hl
        ld a,(hl)
        inc hl
        ld (de),a
        djnz .oq
.ac     ld a,(carnew)           ; attributes and colours only when the pose changed
        or a
        ret z
        ld a,(crow)
        sub 5
        ld c,a
        add a,a
        add a,c
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,b
        add a,b
        ld e,a
        ld d,0
        ld hl,(carsrc)
        add hl,de
        ld (cptr),hl
        ld hl,(raddr)
        ld de,CARCOL
        add hl,de
        ld (caddr),hl
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld de,(cptr)
        ld b,10
.oa     ld a,(de)
        dec a
        cp 2
        ld a,(rbank)
        jr nc,.a1
        inc de
        inc de
        ld a,(de)
        dec de
        dec de
.a1     ld (hl),a
        inc de
        inc de
        inc de
        inc hl
        djnz .oa
        ld a,X1C
        out (PORT_1C),a
        ld a,40h
        out (PORT_08),a
        ld hl,(caddr)
        ld a,h
        add a,8
        ld h,a
        ld de,(cptr)
        ld b,10
.ol     ld a,(de)
        cp 2
        ld a,COL_LIGHT
        jr z,.l1
        ld a,COL_NEAR
.l1     ld (hl),a
        inc de
        inc de
        inc de
        inc hl
        djnz .ol
        xor a
        out (PORT_08),a
        ld a,(rbank)
        or X1C
        out (PORT_1C),a
        ret

; carcopy: one car cell from CARROAD: H = page, C = low base + surface,
; DE -> destination (16 bytes, advanced)
carcopy:
        ld a,(OFFP+0)
        add a,c
        ld l,a
        ldi
        ldi
        ld a,(OFFP+1)
        add a,c
        ld l,a
        ldi
        ldi
        ld a,(OFFP+2)
        add a,c
        ld l,a
        ldi
        ldi
        ld a,(OFFP+3)
        add a,c
        ld l,a
        ldi
        ldi
        ld a,(OFFP+4)
        add a,c
        ld l,a
        ldi
        ldi
        ld a,(OFFP+5)
        add a,c
        ld l,a
        ldi
        ldi
        ld a,(OFFP+6)
        add a,c
        ld l,a
        ldi
        ldi
        ld a,(OFFP+7)
        add a,c
        ld l,a
        ldi
        ldi
        ret

; comp_edge: car cell (cidx) composited in place over the PCG character at HL
comp_edge:
        push hl
        ld a,(cidx)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,CARPART
        add hl,de
        ex de,hl
        pop hl
        ld b,16
.l      ld a,(de)
        and (hl)
        inc de
        ex de,hl
        or (hl)
        inc hl
        ex de,hl
        ld (hl),a
        inc hl
        djnz .l
        ret

; slotaddr: A = slot -> HL = PCG address of the row's slot
slotaddr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(rbase)
        add hl,de
        ret

; car pose from steering (5 poses, 2 = straight), once per frame
car_pose:
        ld a,(keys)
        and 3
        ld c,2
        jr z,.t0
        ld hl,steerT
        inc (hl)
        ld b,(hl)
        cp 1
        jr nz,.r
        ld c,1
        ld a,b
        cp 4
        jr c,.tgt
        ld c,0
        jr .tgt
.r      cp 2
        jr nz,.tgt
        ld c,3
        ld a,b
        cp 4
        jr c,.tgt
        ld c,4
        jr .tgt
.t0     xor a
        ld (steerT),a
.tgt    ld a,(carpose)
        cp c
        jr z,.pz
        jr c,.up
        dec a
        jr .ps
.up     inc a
.ps     ld (carpose),a
.pz     ld a,(carpose)
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl               ; *18
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; *90
        ld de,CARDATA
        add hl,de
        ld (carsrc),hl
        ld a,(page)             ; attributes/colours only change with the pose
        ld e,a
        ld d,0
        ld hl,lastpose
        add hl,de
        ld a,(carpose)
        cp (hl)
        ld (hl),a
        ld a,0
        jr z,.same
        inc a
.same   ld (carnew),a
        ret

; --------------------------------------------------------------------------
; panorama rows 6-7, scrolled by the bends
; --------------------------------------------------------------------------
draw_pano:
        ld a,(page)
        ld e,a
        ld d,0
        ld hl,lastpan
        add hl,de
        ld a,(pan+1)
        cp (hl)
        ret z
        ld (hl),a
        ld c,a
        and 3
        ld b,a                  ; shift
        ld a,c
        rrca
        rrca
        and 3Fh
        ld c,a                  ; cell
        ld b,b
        call pagebase
        ld de,6*64
        add hl,de
        ex de,hl                ; DE = row 6
        push de
        ld a,b
        add a,high(PANOC)       ; PANOC + shift*256 + cell (+128 row B)
        ld h,a
        ld a,c
        ld l,a
        ld a,low(PANOC)
        add a,l
        ld l,a
        jr nc,.n1
        inc h
.n1     push hl
        push bc
        ld bc,64
        ldir
        pop bc
        pop hl
        push hl
        push bc
        ld bc,128
        add hl,bc
        ld bc,64
        ldir
        pop bc
        pop hl
        ld bc,PANOA-PANOC
        add hl,bc
        pop de
        ld a,X1C_ATTR
        out (PORT_1C),a
        push hl
        ld bc,64
        ldir
        pop hl
        ld bc,128
        add hl,bc
        ld bc,64
        ldir
        ld a,X1C
        out (PORT_1C),a
        ret

; --------------------------------------------------------------------------
; HUD: fps, speed, mode
; --------------------------------------------------------------------------
draw_hud:
        ld a,(fpsval)
        ld l,a
        ld h,0
        ld de,NUMTXT
        call put3
        call pagebase
        ld de,HUD_FPS
        add hl,de
        ex de,hl
        ld hl,NUMTXT+1
        call print
        ld a,(speed+1)          ; km/h ~ 13 per unit
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        add hl,hl
        add hl,de               ; *13
        ld de,NUMTXT
        call put3
        call pagebase
        ld de,HUD_SPD
        add hl,de
        ex de,hl
        ld hl,NUMTXT
        call print
        call pagebase
        ld de,HUD_MODE
        add hl,de
        ex de,hl
        ld hl,TXT_AUTO
        ld a,(auto)
        or a
        jr nz,.a
        ld hl,TXT_MAN
.a      jp print
TXT_AUTO: db "AUTO",0
TXT_MAN:  db "    ",0
NUMTXT: db "000",0

; put3: HL (0..999) -> 3 digits at DE
put3:   ld bc,100
        call .d
        ld bc,10
        call .d
        ld a,l
        add a,'0'
        ld (de),a
        ret
.d      ld a,'0'-1
.l      inc a
        or a
        sbc hl,bc
        jr nc,.l
        add hl,bc
        ld (de),a
        inc de
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

; ==========================================================================
        include "../build/roadtest.inc"
        include "../build/gfx.inc"
PCGDATA:
        incbin "../build/pcg.bin"

; ---------------------------------------------------------------- variables
        align 256
LINES:  ds 256
        align 256
        ds 128
FILLBLK:
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ret                     ; FILLBLK+128: page aligned
RC:     ds 3                    ; row: a0, slot offset of range B, edge cells
OFFP:   ds 8
cidx:   db 0
rchg:   db 0
lastpan: db 0FFh,0FFh
lastrng: ds 2*8*4,0FFh
cpg:    db 0
clo:    db 0
ccode:  db 0
carnew: db 0
lastpose: db 0FFh,0FFh
BT:     ds 4
nk:     dw 0
page:   db 0
crow:   db 0
li:     db 0
lbase:  db 0
rbank:  db 0
rbase:  dw 0
cbase:  db 0
raddr:  dw 0
caddr:  dw 0
lmin:   db 0
lmax:   db 0
rmin:   db 0
rmax:   db 0
ra0:    db 0
ra1:    db 0
rb0:    db 0
rb1:    db 0
lena:   db 0
slotb:  db 0
nextcode: db 0
nslot:  db 0
cx:     db 0
cptr:   dw 0
cpart:  dw 0
lcl:    db 0
lsl:    db 0
lcr:    db 0
lsr:    db 0
keys:   db 0
lastA:  db 0
auto:   db 1
pxaim:  dw 0
px:     dw 0
speed:  dw 0
pos:    dw 0
posf:   db 0
pan:    dw 0
cp_:    db 0
cs:     dw 0
kstep:  dw 0
sacc:   dw 0
xacc:   dw 0
dxacc:  dw 0
dt:     db 1
flipf:  dw 0
lastf:  dw 0
fpsacc: db 0
fpscnt: db 0
fpsval: db 0
steerT: db 0
carpose: db 2
carsrc: dw 0
ENDPROG:
        assert ENDPROG < 0E000h
