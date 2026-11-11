; ==========================================================================
; race.asm - Phase 2 road experiment / prototype for Microbee Premium Plus
;            "PCG strip" pseudo-3D engine: curves, hills, crest occlusion,
;            hardware page flipping, dithered colour themes.
;
;   ViBED by BPM 2026
;
;   Controls:  Z / X  or  , / .  or cursor L/R : steer
;              M / SPACE / cursor up           : accelerate
;              N / cursor down                 : brake
;              C                               : cycle colour theme
;
;   Runs as a CP/M .COM.  Takes over the machine (interrupts off) and
;   writes the video hardware directly.  Reset to exit.
; ==========================================================================

        org 100h
        jp start

        include "hw.asm"
        include "math.asm"
        include "road.asm"

MAXSPD  equ 400
ACC     equ 3
DRAG    equ 1
BRAKE   equ 8
OFFMAX  equ 150
CAR_ROW equ 13
CAR_COL equ 27
K_C     equ 3

start:
        di
        ld sp,0EF00h
        call map_video
        call init_video
        ld hl,0
        ld (camPos),hl
        ld (camX),hl
        ld (speed),hl
        ld (panX),hl
        ld (fields),hl
        ld (lastf),hl
        xor a
        ld (fpsacc),a
        ld (fpscnt),a
        ld (theme),a
        ld (ckey),a
        ld hl,ROWTYPE
        ld de,ROWTYPE+1
        ld bc,31
        ld (hl),0
        ldir
        ld a,99
        ld (fpsval),a
        call set_theme
        xor a
        ld (page),a
        call hud_static
        ld a,1
        ld (page),a
        call hud_static
        xor a
        ld (page),a

; --------------------------------------------------------------------------
; main loop: input, physics (once per elapsed 50Hz field), project, draw
; the hidden page, wait for vertical blank, flip, blit stripe characters.
; --------------------------------------------------------------------------
P_frame:
mainloop:
        ld hl,(fields)
        ld de,(lastf)
        ld (lastf),hl
        or a
        sbc hl,de
        ld a,l
        or a
        jr nz,.dt
        inc a
.dt     cp 8
        jr c,.dt2
        ld a,8
.dt2    ld (dt),a
        call fps_update
        call read_input
        ld a,(dt)
        ld b,a
.ph     push bc
        call physics
        pop bc
        djnz .ph
        call project
P_rows:
        call draw_page
        call draw_hud
        call draw_car
P_wait:
        call wait_vb
        ld a,12                 ; flip: show the page just drawn
        out (CRTC_A),a
        ld a,(page)
        add a,a
        add a,a                 ; R12 = 0 or 4  (MA 000h / 400h)
        out (CRTC_D),a
        ld a,13
        out (CRTC_A),a
        xor a
        out (CRTC_D),a
        call blit_stripes       ; still inside vertical blank
P_flip:
        ld a,(page)
        xor 1
        ld (page),a
        jp mainloop

; --------------------------------------------------------------------------
; input -> (keys) bit0 left, bit1 right, bit2 accel, bit3 brake
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
        ld (keys),a
        ; C cycles the colour theme (on key-down)
        ld a,K_C
        call keytest
        ld hl,ckey
        jr z,.nc
        ld a,(hl)
        or a
        ret nz
        ld (hl),1
        ld a,(theme)
        inc a
        cp NTHEMES
        jr c,.t
        xor a
.t      ld (theme),a
        jp set_theme
.nc     ld (hl),0
        ret
keymap: db K_Z,1, K_COMMA,1, K_LEFT,1
        db K_X,2, K_DOT,2, K_RIGHT,2
        db K_M,4, K_SPACE,4, K_UP,4
        db K_N,8, K_DOWN,8
        db 0

; --------------------------------------------------------------------------
; physics: one 50Hz field step
; --------------------------------------------------------------------------
physics:
        ld a,(keys)
        ld hl,(speed)
        bit 2,a
        jr z,.noacc
        ld de,ACC
        add hl,de
        jr .sp
.noacc  bit 3,a
        jr z,.coast
        ld de,-BRAKE
        add hl,de
        jr .sp
.coast  ld de,-DRAG
        add hl,de
.sp     bit 7,h
        jr z,.p1
        ld hl,0
.p1     ld de,MAXSPD
        call cmp_signed
        jr c,.p2
        ld hl,MAXSPD
.p2     push hl                 ; off-road slowdown
        ld hl,(camX)
        bit 7,h
        call nz,neghl
        ld de,RW+30
        call cmp_signed
        pop hl
        jr c,.onroad
        ld de,OFFMAX
        call cmp_signed
        jr c,.onroad
        ld de,-6
        add hl,de
.onroad ld (speed),hl
        srl h                   ; advance: camPos += speed/4
        rr l
        srl h
        rr l
        ld de,(camPos)
        add hl,de
        ld (camPos),hl
        ld hl,(speed)           ; steering: +-(speed/16 + 4) when moving
        ld a,h
        or l
        jr z,.nost
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld de,4
        add hl,de
        ex de,hl
        ld a,(keys)
        ld hl,(camX)
        bit 0,a
        jr z,.nl
        or a
        sbc hl,de
.nl     bit 1,a
        jr z,.nr
        add hl,de
.nr     ld (camX),hl
.nost   ld a,(camPos+1)         ; centrifugal: camX -= curve*speed/512
        call get_curve
        ld (.c),a
        bit 7,a
        jr z,.cp
        neg
.cp     ld e,a
        ld hl,(speed)
        srl h
        rr l
        ld a,l
        call mul8q
        ld l,h
        ld h,0
        ld a,(.c)
        bit 7,a
        jr nz,.cn
        call neghl
.cn     ld de,(camX)
        add hl,de
        ld de,500
        call cmp_signed
        jr c,.c1
        ld hl,500
.c1     ld de,-500
        call cmp_signed
        jr nc,.c2
        ld hl,-500
.c2     ld (camX),hl
        ld a,(.c)               ; panorama scroll: panX += curve*speed/256
        bit 7,a
        jr z,.pp
        neg
.pp     ld e,a
        ld hl,(speed)
        srl h
        rr l
        ld a,l
        call mul8q
        ld l,h
        ld h,0
        add hl,hl
        ld a,(.c)
        bit 7,a
        call nz,neghl
        ld de,(panX)
        add hl,de
        ld (panX),hl
        ret
.c      db 0

; --------------------------------------------------------------------------
; draw_page: all rows of the back page
;   geometry is sampled once per row boundary line (8r) and shared by the
;   row above and below: BXR[r] = 4 boundary x values at line 8r (r=16 -> 127)
; --------------------------------------------------------------------------
draw_page:
        ld a,(LTOP)
        cp 128
        jp nc,draw_sky
        add a,7
        rrca
        rrca
        rrca
        and 1Fh
        ld (.r),a
.geo    ld a,(.r)
        cp 16
        ld b,127
        jr z,.g16
        add a,a
        add a,a
        add a,a
        ld b,a
.g16    ld a,b
        call line_geom
        ld a,(.r)
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld ix,BXR
        add ix,de
        call bounds_at
        ld a,(.r)
        inc a
        ld (.r),a
        cp 17
        jr c,.geo
        call vbpoll
        ld a,1
        ld (crow),a
.row    ld a,(crow)
        add a,a
        add a,a
        add a,a
        ld (rowtop),a
        add a,7
        ld b,a
        ld a,(LTOP)
        ld c,a
        ld a,b
        cp c
        jp c,.next              ; whole row above LTOP -> sky (done later)
        ld a,(crow)             ; BX8 = BXR[crow+1]
        inc a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,BXR
        add hl,de
        ld de,BX8
        ld bc,8
        ldir
        ld a,(rowtop)
        cp c
        jr c,.horizon
        ld a,(crow)             ; road row: BX0 = BXR[crow]
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,BXR
        add hl,de
        ld de,BX0
        ld bc,8
        ldir
        call stripe_char
        xor a
        ld (allint),a
        call build_regions
        call write_row
        call vbpoll
        jr .next
.horizon                        ; row containing the top of the visible ground
        ld hl,BX8
        ld de,BX0
        ld bc,8
        ldir
        ld a,1
        ld (allint),a
        call build_regions
        ld a,(rowtop)
        ld b,a
        ld a,(LTOP)
        sub b                   ; empty lines at top (1..7)
        add a,IDX_HMASK
        or 80h
        ld (rcode),a
        call write_row
.next   ld a,(crow)
        inc a
        ld (crow),a
        cp 16
        jp c,.row
        jp draw_sky
.r      db 0

; --------------------------------------------------------------------------
; draw_sky: rows 1..toprow-1 (skipped when unchanged for this page)
; --------------------------------------------------------------------------
draw_sky:
        ld a,(LTOP)
        rrca
        rrca
        rrca
        and 1Fh
        ld (toprow),a
        ld hl,(panX)            ; panorama position (logical px) = panX/16
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        ld (panpx),a
        ld a,(page)
        add a,a
        ld e,a
        ld d,0
        ld hl,lastsky
        add hl,de
        ld a,(toprow)
        cp (hl)
        jr nz,.ch
        inc hl
        ld a,(panpx)
        cp (hl)
        ret z
        dec hl
.ch     ld a,(toprow)
        ld (hl),a
        inc hl
        ld a,(panpx)
        ld (hl),a
        ld a,1
        ld (crow),a
.sr     ld a,(toprow)
        ld b,a
        ld a,(crow)
        cp b
        ret nc
        call row_addr
        ld (raddr),hl
        call rowtype_ptr
        ld (hl),2
        ld a,(toprow)
        sub 2
        ld c,a                  ; panorama row A
        ld a,(crow)
        cp c
        jr z,.panoA
        inc c
        cp c
        jr z,.panoB
        ld a,(toprow)           ; gradient row: d = (toprow-2) - crow  (>=1)
        sub 2
        ld hl,crow
        sub (hl)
        cp 9
        jr c,.g
        ld a,9
.g      ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de               ; *3
        ld de,SKYTAB-3
        add hl,de
        ld a,(hl)
        ld (.sc),a
        inc hl
        ld a,(hl)
        ld (.sa),a
        inc hl
        ld a,(hl)
        ld (.scol),a
        ld hl,(raddr)
        ld a,(.sc)
        ld b,64
        call fillb
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld hl,(raddr)
        ld a,(.sa)
        ld b,64
        call fillb
        ld a,X1C
        out (PORT_1C),a
        jr .colr
.panoA  ld a,(PANO_COLA)
        ld b,0
        jr .pano
.panoB  ld a,(PANO_COLB)
        ld b,64*2
.pano   ld (.scol),a
        ; src = PANOC + shift*256 + rowsel*128 + (panpx>>2)
        ld a,(panpx)
        and 3
        ld h,a
        ld l,b
        ld a,(panpx)
        rrca
        rrca
        and 3Fh
        add a,l
        ld l,a
        ld (.src),hl
        ld de,PANOC
        add hl,de
        ld de,(raddr)
        ld bc,64
        ldir
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld hl,(.src)
        ld de,PANOA
        add hl,de
        ld de,(raddr)
        ld bc,64
        ldir
        ld a,X1C
        out (PORT_1C),a
.colr   ld a,40h
        out (PORT_08),a
        ld hl,(raddr)
        ld a,h
        add a,8
        ld h,a
        ld a,(.scol)
        ld b,64
        call fillb
        xor a
        out (PORT_08),a
        ld a,(crow)
        inc a
        ld (crow),a
        jp .sr
.sc     db 0
.sa     db 0
.scol   db 0
.src    dw 0

; --------------------------------------------------------------------------
; draw_car: player car on rows 13-15 (pose by steering), three passes
;   cells: code, attr, fg, bg (255 = colour of ground beneath, 254 = empty)
; --------------------------------------------------------------------------
P_car:
draw_car:
        ld a,(keys)
        and 3
        ld b,1
        cp 1
        jr nz,.n1
        ld b,0
.n1     cp 2
        jr nz,.n2
        ld b,2
.n2     ld a,b
        ld hl,CARDATA
        ld de,120
        or a
        jr z,.p0
.pm     add hl,de
        dec a
        jr nz,.pm
.p0     ld (.src),hl
        xor a
        ld (.cy),a
.rowl   ld a,(.cy)
        add a,CAR_ROW
        ld (crow),a
        call row_addr
        ld de,CAR_COL
        add hl,de
        ld (.dst),hl
        ; ground boundaries under this row (line 8*(row+1)) -> cell numbers
        ld a,(crow)
        inc a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld ix,BXR
        add ix,de
        ld b,4
        ld de,.cb
.cbl    ld l,(ix+0)
        ld h,(ix+1)
        push de
        call cellof
        pop de
        inc a                   ; -1..64 -> 0..65
        ld (de),a
        inc de
        inc ix
        inc ix
        djnz .cbl
        ; colours
        ld hl,(.src)
        ld de,.cols
        ld c,CAR_COL+1          ; +1 matches the cb offset
        ld b,10
.colc   push bc
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld (.fg),a
        ld a,(hl)
        inc hl
        cp 255
        jr nz,.hb
        push hl
        ld hl,.cb               ; class = number of boundaries at or left of c
        ld b,0
        ld a,c
        cp (hl)
        jr c,.u
        inc b
        inc hl
        cp (hl)
        jr c,.u
        inc b
        inc hl
        cp (hl)
        jr c,.u
        inc b
        inc hl
        cp (hl)
        jr c,.u
        inc b
.u      ld a,b
        ld hl,UNDERCOL
        add a,l
        ld l,a
        jr nc,.u2
        inc h
.u2     ld a,(hl)
        pop hl
.hb     add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(.fg)
        or b
        ld (de),a
        inc de
        pop bc
        inc c
        djnz .colc
        ; pass 1: codes (empty cells keep the road)
        ld hl,(.src)
        ld de,(.dst)
        ld b,10
.c1     ld a,(hl)
        inc hl
        inc hl
        inc hl
        ld c,(hl)
        inc hl
        inc c
        inc c
        jr z,.c1s
        ld (de),a
.c1s    inc de
        djnz .c1
        ; pass 2: attributes (all cells: empty cells back to bank 0)
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld hl,(.src)
        ld de,(.dst)
        ld b,10
.c2     inc hl
        ld a,(hl)
        inc hl
        inc hl
        ld c,(hl)
        inc hl
        inc c
        inc c
        jr nz,.c2w
        xor a
.c2w    ld (de),a
        inc de
        djnz .c2
        ld a,X1C
        out (PORT_1C),a
        ; pass 3: colours
        ld a,40h
        out (PORT_08),a
        ld hl,(.dst)
        ld a,h
        add a,8
        ld h,a
        ex de,hl
        ld hl,(.src)
        ld ix,.cols
        ld b,10
.c3     inc hl
        inc hl
        inc hl
        ld c,(hl)
        inc hl
        inc c
        inc c
        jr z,.c3s
        ld a,(ix+0)
        ld (de),a
.c3s    inc de
        inc ix
        djnz .c3
        xor a
        out (PORT_08),a
        ld (.src),hl
        ld a,(.cy)
        inc a
        ld (.cy),a
        cp 3
        jp c,.rowl
        ret
.src    dw 0
.dst    dw 0
.cy     db 0
.fg     db 0
.cb     ds 4
.cols   ds 10

; --------------------------------------------------------------------------
; HUD: row 0.  Static text written once per page, digits updated per frame.
; --------------------------------------------------------------------------
HUD_SPD equ 6
HUD_TIM equ 20
HUD_FPS equ 29
HUDTXT: db "SPEED 000 KMH  TIME 000  FPS 00                 VIBED BY BPM 2026"
HUDLEN  equ 64

hud_static:
        xor a
        ld (crow),a
        call row_addr
        push hl
        ld de,HUDTXT
        ld b,HUDLEN
        ld c,0
        call .w
        ld a,X1C_ATTR
        out (PORT_1C),a
        pop hl
        push hl
        ld de,HUDTXT
        ld b,HUDLEN
        ld c,1
        call .w
        ld a,X1C
        out (PORT_1C),a
        ld a,40h
        out (PORT_08),a
        pop hl
        ld de,800h
        add hl,de
        ld a,(HUDCOL)
        ld b,64
        call fillb
        xor a
        out (PORT_08),a
        ret
.w      ld a,(de)
        sub 32
        add a,a
        add a,c
        push hl
        push de
        ld e,a
        ld d,0
        ld hl,FONTMAP
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ld (hl),a
        inc hl
        inc de
        djnz .w
        ret

draw_hud:
        ld hl,(speed)           ; km/h = speed*3/4
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        srl h
        rr l
        srl h
        rr l
        ld de,HUDTXT+HUD_SPD
        call put3
        ld hl,(fields)
        ld bc,50
        call div16
        ld de,HUDTXT+HUD_TIM
        call put3
        ld a,(fpsval)
        ld l,a
        ld h,0
        ld de,HUDTXT+HUD_FPS
        call put2
        xor a
        ld (crow),a
        call row_addr
        push hl
        ld c,0
        call .dig
        ld a,X1C_ATTR
        out (PORT_1C),a
        pop hl
        ld c,1
        call .dig
        ld a,X1C
        out (PORT_1C),a
        ret
.dig    push hl
        ld de,HUD_SPD
        add hl,de
        ex de,hl
        ld hl,HUDTXT+HUD_SPD
        ld b,3
        call .cp
        pop hl
        push hl
        ld de,HUD_TIM
        add hl,de
        ex de,hl
        ld hl,HUDTXT+HUD_TIM
        ld b,3
        call .cp
        pop hl
        ld de,HUD_FPS
        add hl,de
        ex de,hl
        ld hl,HUDTXT+HUD_FPS
        ld b,2
.cp     ld a,(hl)
        sub 32
        add a,a
        add a,c
        push hl
        ld l,a
        ld h,0
        push de
        ld de,FONTMAP
        add hl,de
        pop de
        ld a,(hl)
        pop hl
        ld (de),a
        inc hl
        inc de
        djnz .cp
        ret

; put3: HL = value (0..999) -> 3 ascii digits at DE
put3:   ld bc,100
        call .dig
        ld bc,10
        call .dig
        ld a,l
        add a,'0'
        ld (de),a
        ret
.dig    ld a,'0'-1
.d      inc a
        or a
        sbc hl,bc
        jr nc,.d
        add hl,bc
        ld (de),a
        inc de
        ret
put2:   ld bc,10
        call put3.dig
        ld a,l
        add a,'0'
        ld (de),a
        ret

; div16: HL = HL / BC (unsigned, small quotients)
div16:  ld de,0
.l      or a
        sbc hl,bc
        jr c,.d
        inc de
        jr .l
.d      ex de,hl
        ret

; fps = 800 / fields over the last 16 frames
fps_update:
        ld a,(dt)
        ld hl,fpsacc
        add a,(hl)
        ld (hl),a
        ld hl,fpscnt
        inc (hl)
        ld a,(hl)
        cp 16
        ret c
        ld (hl),0
        ld a,(fpsacc)
        ld c,a
        ld b,0
        xor a
        ld (fpsacc),a
        ld hl,800
        call div16
        ld a,l
        cp 100
        jr c,.ok
        ld a,99
.ok     ld (fpsval),a
        ret

; --------------------------------------------------------------------------
; colour themes (inspired by period Microbee racers: dithered gradients)
;  per theme: verge A,B  kerb A,B  road A,B  terrain  peaks  mountains
;             sky0..sky4 (top -> horizon)  HUD colour
; A = solid-line colour, B = second colour of the checker lines
; --------------------------------------------------------------------------
NTHEMES equ 3
THEMES:
        ; DUSK: violet-to-magenta sky, blue road, pink/white kerbs
        db 4,0,  15,13,  12,4,  0,  5,0,  4,4,4,5,13,   0Dh
        ; SNOWLINE: red sky, white horizon, grey road, white verges
        db 15,7, 15,9,   7,8,   7,  7,8,  1,1,9,9,15,   09h
        ; DAYTIME: blue sky, green verges, grey road
        db 10,2, 15,9,   7,8,   2,  15,4, 4,4,12,12,14,  0Bh
THEMESZ equ 15

set_theme:
        ld a,(theme)
        ld b,a
        ld hl,THEMES
        ld de,THEMESZ
        or a
        jr z,.t0
.tl     add hl,de
        djnz .tl
.t0     ld de,THM
        ld bc,THEMESZ
        ldir
        ; class colours: CLS_INT[c] = (B<<4)|A ; CLS_HOR[c] = (TERR<<4)|A
        ld ix,THM
        ld b,3
        ld hl,CLS_INT
        ld de,CLS_HOR
.c1     ld a,(ix+1)
        add a,a
        add a,a
        add a,a
        add a,a
        or (ix+0)
        ld (hl),a
        inc hl
        ld a,(THM+6)
        add a,a
        add a,a
        add a,a
        add a,a
        or (ix+0)
        ld (de),a
        inc de
        inc ix
        inc ix
        djnz .c1
        ; CLS_PAIR[l*3+r] = (A_l<<4)|A_r
        ld hl,CLS_PAIR
        ld c,0
.pl     ld a,c
        call .ca
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        ld e,0
.pr     ld a,e
        call .ca
        or b
        ld (hl),a
        inc hl
        inc e
        ld a,e
        cp 3
        jr c,.pr
        inc c
        ld a,c
        cp 3
        jr c,.pl
        ; region colour sets for the 4 kerb-merge states
        ; regions: V | (V,K) | K | (K,R) | R | (R,K) | K | (K,V) | V
        ;  merged left: (V,K)+K -> empty, (K,R) -> (V,R)
        ld de,RCOLS
        ld hl,RCSPEC
        ld b,36
.rs     push bc
        ld a,(hl)
        inc hl
        push hl
        push de
        call .rcol
        pop de
        ld (de),a
        inc de
        pop hl
        pop bc
        djnz .rs
        ld de,HCOLS
        ld hl,RCSPEC
        ld b,36
.hs     push bc
        ld a,(hl)
        inc hl
        and 3                   ; horizon: (terrain, right class A)
        push hl
        push de
        ld e,a
        ld d,0
        ld hl,CLS_HOR
        add hl,de
        ld a,(hl)
        pop de
        ld (de),a
        inc de
        pop hl
        pop bc
        djnz .hs
        ; car ground colours: classes verge, kerb, road, kerb, verge
        ld a,(THM+0)
        ld (UNDERCOL+0),a
        ld (UNDERCOL+4),a
        ld a,(THM+2)
        ld (UNDERCOL+1),a
        ld (UNDERCOL+3),a
        ld a,(THM+4)
        ld (UNDERCOL+2),a
        ; panorama row colours: sky4 background, peaks / mountains foreground
        ld a,(THM+13)
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(THM+7)
        or b
        ld (PANO_COLA),a
        ld a,(THM+8)
        or b
        ld (PANO_COLB),a
        ld a,(THM+14)
        ld (HUDCOL),a
        ; sky gradient colours (codes are fixed): d=1..9
        ld ix,THM+9             ; sky0..sky4
        ld a,(ix+4)
        call .solid
        ld (SKYTAB+0*3+2),a     ; d1 sky4
        ld a,(ix+3)
        ld b,(ix+4)
        call .mix
        ld (SKYTAB+1*3+2),a     ; d2 sky3/sky4
        ld a,(ix+3)
        call .solid
        ld (SKYTAB+2*3+2),a
        ld a,(ix+2)
        ld b,(ix+3)
        call .mix
        ld (SKYTAB+3*3+2),a
        ld a,(ix+2)
        call .solid
        ld (SKYTAB+4*3+2),a
        ld a,(ix+1)
        ld b,(ix+2)
        call .mix
        ld (SKYTAB+5*3+2),a
        ld a,(ix+1)
        call .solid
        ld (SKYTAB+6*3+2),a
        ld a,(ix+0)
        ld b,(ix+1)
        call .mix
        ld (SKYTAB+7*3+2),a
        ld a,(ix+0)
        call .solid
        ld (SKYTAB+8*3+2),a
        ; invalidate cached sky rows and the HUD colour on both pages
        ld a,0FFh
        ld (lastsky),a
        ld (lastsky+2),a
        ld a,(page)
        push af
        xor a
        ld (page),a
        call hud_static
        ld a,1
        ld (page),a
        call hud_static
        pop af
        ld (page),a
        ret
.rcol   ; spec byte: bit7 = edge, bits 3-2 left class, bits 1-0 right class
        bit 7,a
        jr nz,.re
        and 3
        ld e,a
        ld d,0
        ld hl,CLS_INT
        add hl,de
        ld a,(hl)
        ret
.re     ld c,a
        rrca
        rrca
        and 3
        ld b,a
        add a,a
        add a,b
        ld b,a
        ld a,c
        and 3
        add a,b
        ld e,a
        ld d,0
        ld hl,CLS_PAIR
        add hl,de
        ld a,(hl)
        ret
.ca     push hl                 ; A = class -> A = colour A of class
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,THM
        add hl,de
        pop de
        ld a,(hl)
        pop hl
        ret
.solid  add a,a                 ; space char: background colour only
        add a,a
        add a,a
        add a,a
        ret
.mix    add a,a                 ; dither: background A (upper), foreground B (lower)
        add a,a
        add a,a
        add a,a
        or b
        ret

; region colour specs: interior = class, edge = 80h | left<<2 | right
V_ equ 0
K_ equ 1
R_ equ 2
RCSPEC: db V_, 80h|V_<<2|K_, K_, 80h|K_<<2|R_, R_, 80h|R_<<2|K_, K_, 80h|K_<<2|V_, V_
        db V_, 80h|V_<<2|K_, V_, 80h|V_<<2|R_, R_, 80h|R_<<2|K_, K_, 80h|K_<<2|V_, V_
        db V_, 80h|V_<<2|K_, K_, 80h|K_<<2|R_, R_, 80h|R_<<2|V_, V_, 80h|K_<<2|V_, V_
        db V_, 80h|V_<<2|K_, V_, 80h|V_<<2|R_, R_, 80h|R_<<2|V_, V_, 80h|K_<<2|V_, V_

; sky gradient rows by distance above the panorama: code, attr, colour
SKYTAB: db 20h,0,0
        db D50_CODE,D50_ATTR,0
        db 20h,0,0
        db D50_CODE,D50_ATTR,0
        db 20h,0,0
        db D50_CODE,D50_ATTR,0
        db 20h,0,0
        db D50_CODE,D50_ATTR,0
        db 20h,0,0

; ==========================================================================
        include "../build/gfx.inc"
PCGDATA:
        incbin "../build/pcg.bin"

; ---------------------------------------------------------------- variables
camPos: dw 0
camX:   dw 0
speed:  dw 0
panX:   dw 0
lastf:  dw 0
dt:     db 0
keys:   db 0
ckey:   db 0
theme:  db 0
page:   db 0
fpsacc: db 0
fpscnt: db 0
fpsval: db 0
seg:    db 0
frac:   db 0
fq:     db 0
H0:     dw 0
XK:     dw 0
DXK:    dw 0
kk:     db 0
kseg:   db 0
sk:     db 0
maxy:   db 0
LTOP:   db 0
tidx:   dw 0
invm:   db 0
invr:   db 0
cur_sy: dw 0
cur_sx: dw 0
cur_sw: dw 0
lcx:    dw 0
lhw:    dw 0
crow:   db 0
rowtop: db 0
toprow: db 0
panpx:  db 0
rcode:  db 0
allint: db 0
raddr:  dw 0
cur:    db 0
mstate: db 0
rptr:   dw 0
eptr:   dw 0
THM:    ds THEMESZ
CLS_INT: ds 3
CLS_HOR: ds 3
CLS_PAIR: ds 9
UNDERCOL: ds 5
PANO_COLA: db 0
PANO_COLB: db 0
HUDCOL: db 0
lastsky: ds 4
ROWTYPE: ds 32
BX0:    ds 8                    ; BX0 and BX8 must be contiguous
BX8:    ds 8
BXR:    ds 17*8
BINFO:  ds 32
BLC:    ds 4                    ; BLC, BRC, BEN must be contiguous
BRC:    ds 4
BEN:    ds 4
REGLEN: ds 9                    ; REGLEN, REGCOL must be contiguous
REGCOL: ds 9
STRIPEBUF: ds 15*16
SYT:    ds (NSEG+1)*2
SXT:    ds (NSEG+1)*2
SWT:    ds (NSEG+1)*2
RCOLS:  ds 36                   ; region colours [merge state 0..3][9]
HCOLS:  ds 36                   ; horizon-row region colours
        align 256
LINEK:  ds 128
PHT:    ds NSEG+1
        align 256
ECODE:  ds 64
ENDPROG:
        assert ENDPROG < 0E000h
