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
FRAMEFIELDS equ 5              ; 50/5 = 10 fps locked (4 -> 12.5 fps when the engine is fast enough)
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
        call vbpoll
        call read_input
        call vbpoll
        ld a,(dt)
        ld b,a
.ph     push bc
        call physics
        call vbpoll
        pop bc
        djnz .ph
        call project
P_rows:
        call draw_page
        call vbpoll
        call draw_hud
        call vbpoll
        call draw_car
P_wait:
.w      call wait_vb            ; steady pacing: flip every FRAMEFIELDS fields
        ld hl,(fields)
        ld de,(flipf)
        or a
        sbc hl,de
        ld a,l
        cp FRAMEFIELDS
        jr c,.w
        ld hl,(fields)
        ld (flipf),hl
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
.done   ld a,(autodrive)
        or a
        jr z,.man
        ld b,4                  ; autopilot: accelerate, steer back to centre
        ld hl,(camX)
        ld de,-40
        call cmp_signed
        jr nc,.a1
        set 1,b
.a1     ld de,40
        call cmp_signed
        jr c,.man
        set 0,b
.man    ld a,b
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
.geo    call vbpoll
        ld a,(.r)
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
        call vbpoll
        call build_regions
        call write_row
        call vbpoll
        jr .next
.horizon                        ; row containing the top of the visible ground
        ld hl,BX8
        ld de,BX0
        ld bc,8
        ldir
        call build_regions      ; lines above the horizon come out black
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
        xor a
        ld (.gdirty),a
        ld a,(toprow)
        cp (hl)
        jr nz,.ch
        inc hl
        ld a,(panpx)
        cp (hl)
        ret z
        ld (hl),a               ; only the panorama scrolled: its 2 rows
        ld a,(toprow)
        sub 2
        jr c,.none
        jr z,.none
        ld (crow),a
        jr .sr
.none   ret
.ch     ld a,1                  ; horizon row moved: whole sky
        ld (.gdirty),a
        ld a,(toprow)
        ld (hl),a
        inc hl
        ld a,(panpx)
        ld (hl),a
        ld a,1
        ld (crow),a
.sr     call vbpoll
        ld a,(toprow)
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
        ld a,(.gdirty)          ; gradient rows only change with the horizon
        or a
        jp z,.nx
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
.nx     ld a,(crow)
        inc a
        ld (crow),a
        jp .sr
.gdirty db 0
.sc     db 0
.sa     db 0
.scol   db 0
.src    dw 0

; --------------------------------------------------------------------------
; draw_car: player car on rows 13-15, 5 steering poses that blend over a
; few frames.  Per cell: 0 empty (ground stays), 1 opaque static character,
; 2 opaque with tail light (light colour), 3 partial: built per frame from
; the ground under it (car_under) and the car's mask/ink (cellcomp).
; --------------------------------------------------------------------------
P_car:
draw_car:
        ; target pose from steering, held steering leans further
        ld a,(keys)
        and 3
        ld c,2
        jr z,.tgt0
        ld hl,steerT
        inc (hl)
        ld b,(hl)
        cp 1
        jr nz,.r
        ld c,1                  ; left
        ld a,b
        cp 4
        jr c,.tgt
        ld c,0
        jr .tgt
.r      cp 2
        jr nz,.tgt
        ld c,3                  ; right
        ld a,b
        cp 4
        jr c,.tgt
        ld c,4
        jr .tgt
.tgt0   xor a
        ld (steerT),a
.tgt    ld a,(carpose)          ; move one pose per frame towards the target
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
        add hl,de               ; *9
        add hl,hl               ; *18
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl               ; *72
        add hl,de               ; *90
        ld de,CARDATA
        add hl,de
        ld (.src),hl
        xor a
        ld (.cy),a
.rowl   call vbpoll
        ld a,(.cy)
        add a,CAR_ROW
        ld (crow),a
        call row_addr
        ld de,CAR_COL
        add hl,de
        ld (.dst),hl
        call row_bank
        call set_phases
        call patch_comp
        ld a,(.cy)
        ld e,a
        ld d,0
        ld hl,CSLOT
        add hl,de
        ld a,(hl)
        ld (.code),a
        ld hl,CSDEST
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (.pdst),hl
        ld a,(.cy)              ; CUNDER row pointer
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,a
        add a,a
        ld e,a
        ld hl,CUNDER
        add hl,de
        ld (.und),hl
        ld a,(crow)
        ld e,a
        ld hl,ROWCOL
        add hl,de
        ld a,(hl)
        ld (.gcol),a
        ld a,(rbank)
        or X1C
        out (PORT_1C),a
        ; pass 1: codes (and partial cells built); attr/colour to buffers
        ld ix,.attrs
        ld b,10
.cell   push bc
        call vbpoll
        ld hl,(.src)
        ld a,(hl)               ; type
        inc hl
        ld c,(hl)               ; a
        inc hl
        ld b,(hl)               ; b
        inc hl
        ld (.src),hl
        or a
        jr nz,.t1
        ld a,(rbank)            ; empty: ground stays, restore bank + colour
        ld (ix+0),a
        ld a,(.gcol)
        ld (ix+10),a
        jr .nx
.t1     cp 3
        jr z,.t3
        ld hl,(.dst)            ; static character
        ld (hl),c
        ld (ix+0),b
        cp 2
        ld a,(.gcol)
        jr nz,.t1c
        ld a,(LIGHTCOL)
.t1c    ld (ix+10),a
        jr .nx
.t3     push ix
        ld l,c                  ; IX = CARPART + 32*index
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,CARPART
        add hl,de
        push hl
        pop ix
        ld hl,(.und)            ; ground under this column: page, mask
        ld a,(hl)
        inc hl
        ld l,(hl)
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,MASKLIB
        add hl,de
        ld b,h
        ld c,l
        ld h,a
        ld de,(.pdst)
        call cellcomp
        inc de
        ld (.pdst),de
        pop ix
        ld hl,(.dst)
        ld a,(.code)
        ld (hl),a
        inc a
        ld (.code),a
        ld a,(rbank)
        ld (ix+0),a
        ld a,(.gcol)
        ld (ix+10),a
.nx     ld hl,(.dst)
        inc hl
        ld (.dst),hl
        ld hl,(.und)
        inc hl
        inc hl
        ld (.und),hl
        inc ix
        pop bc
        dec b
        jp nz,.cell
        ; pass 2: attributes, pass 3: colours
        ld hl,(.dst)
        ld de,-10
        add hl,de
        ld (.dst),hl
        ld a,X1C_ATTR
        out (PORT_1C),a
        ex de,hl
        ld hl,.attrs
        ld bc,10
        ldir
        ld a,X1C
        out (PORT_1C),a
        ld a,40h
        out (PORT_08),a
        ld hl,(.dst)
        ld a,h
        add a,8
        ld d,a
        ld e,l
        ld hl,.cols
        ld bc,10
        ldir
        xor a
        out (PORT_08),a
        ld a,(.cy)
        inc a
        ld (.cy),a
        cp 3
        jp c,.rowl
        ret
.src    dw 0
.dst    dw 0
.pdst   dw 0
.und    dw 0
.cy     db 0
.code   db 0
.gcol   db 0
.attrs  ds 10
.cols   ds 10

; --------------------------------------------------------------------------
; HUD: row 0.  Static text written once per page, digits updated per frame.
; --------------------------------------------------------------------------
HUD_SPD equ 6
HUD_TIM equ 20
HUD_FPS equ 29
HUDTXT: db "SPEED 000 KMH  TIME 000  FPS 00                VIBED BY BPM 2026"
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
; colour themes.  The ground is ONE colour on black (two shades: far rows,
; near rows); verge, kerb and road differ only by dither pattern.
;  per theme: ground far, ground near, tail light, peaks, mountains,
;             sky0..sky4 (top -> horizon), HUD colour
; --------------------------------------------------------------------------
NTHEMES equ 3
THEMES:
        db 4,12, 9,  5,0,  4,4,4,5,13,   0Dh    ; DUSK: blue ground, violet/magenta sky
        db 8,7,  9,  7,0,  1,1,9,9,15,   09h    ; SNOWLINE: grey ground, red sky
        db 2,10, 11, 15,0, 4,4,12,12,14, 0Bh    ; DAYTIME: green ground, blue sky
THEMESZ equ 11
FARROWS equ 10                  ; rows 1..9 use the far shade

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
        ld hl,ROWCOL            ; ground colour per screen row (black background)
        ld b,16
        ld c,0
.rc     ld a,c
        cp FARROWS
        ld a,(THM+0)
        jr c,.far
        ld a,(THM+1)
.far    ld (hl),a
        inc hl
        inc c
        djnz .rc
        ld a,(THM+2)
        ld (LIGHTCOL),a
        ld a,(THM+9)            ; panorama rows: sky4 background
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(THM+3)
        or b
        ld (PANO_COLA),a
        ld a,(THM+4)
        or b
        ld (PANO_COLB),a
        ld a,(THM+10)
        ld (HUDCOL),a
        ld ix,THM+5             ; sky0..sky4 -> gradient rows d=1..9
        ld a,(ix+4)
        call .solid
        ld (SKYTAB+0*3+2),a
        ld a,(ix+3)
        ld b,(ix+4)
        call .mix
        ld (SKYTAB+1*3+2),a
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
        ; force sky and road rows (attributes + colours) to be redrawn
        ld a,0FFh
        ld (lastsky),a
        ld (lastsky+2),a
        ld hl,ROWTYPE
        ld b,32
.rt     ld (hl),0
        inc hl
        djnz .rt
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
autodrive: db 0                 ; set by the emulator (-poke) / attract mode
camX:   dw 0
speed:  dw 0
panX:   dw 0
lastf:  dw 0
flipf:  dw 0
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
raddr:  dw 0
cur:    db 0
mstate: db 0
rptr:   dw 0
eptr:   dw 0
THM:    ds THEMESZ
ROWCOL: ds 16
LIGHTCOL: db 0
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
REGLEN: ds 9
sbase:  db 0
rbank:  db 0
sdest:  dw 0
scode:  db 0
sleft:  db 0
rints:  dw 0
rpairs: dw 0
wptr:   dw 0
ICODE:  ds 3
        align 16
PHOFF:  ds 8
CUNDER: ds 60
CSLOT:  ds 3
CSDEST: ds 6
carpose: db 2
steerT: db 0
SYT:    ds (NSEG+1)*2
SXT:    ds (NSEG+1)*2
SWT:    ds (NSEG+1)*2
        align 256
LINEK:  ds 128
PHT:    ds NSEG+1
        align 256
ECODE:  ds 256
SLOTMASK: ds 256                ; per screen code: mask index of its character
SLOTPAGE: ds 256                ; per screen code: RES page of its character
ENDPROG:
        assert ENDPROG < 0E000h
