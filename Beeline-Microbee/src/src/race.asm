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
        include "track.asm"
        include "traffic.asm"
        include "game.asm"
        include "ui.asm"
        include "snd.asm"
        include "tunnel.asm"

MAXSPD  equ 400
BOOSTV  equ 80                  ; extra top speed in a turbo or slipstream boost
FRAMEFIELDS equ 3              ; 50/3 = 16.7 fps locked (a frame that overruns waits for the next field)
ACC     equ 3
DRAG    equ 1
BRAKE   equ 8
OFFMAX  equ 150
CAR_ROW equ 13
CAR_COL equ 27
K_C     equ 3

start:
        ld sp,LSTACK
        call load_dat           ; BEELINE.DAT -> 9000h (CP/M still running)
        di
        ld sp,STACKTOP
        call map_video
        call gen_carroad
        call init_video
        call tunnel_init
        call init_uniform
        ld hl,0
        ld (panX),hl
        ld (fields),hl
        ld (lastf),hl
        ld (flipf),hl
        ld hl,ROWTYPE
        ld de,ROWTYPE+1
        ld bc,31
        ld (hl),0
        ldir
        xor a
        ld (page),a
        jp game_start

; --------------------------------------------------------------------------
; run_frame: one frame - input, physics (once per elapsed 50Hz field),
; rivals, track, projection, draw the hidden page, wait, flip.
; --------------------------------------------------------------------------
P_frame:
run_frame:
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
.dt2    ld b,a
        ld a,(fixdt)            ; test mode: fixed physics steps per frame
        or a
        jr nz,.dt3
        ld a,b
.dt3    ld (dt),a
        call vbpoll
        call read_input
        call input_filter
        call vbpoll
        ld a,(dt)
        ld b,a
.ph     push bc
        call physics
        pop bc
        djnz .ph
        call physics_frame
        call vbpoll
        call traffic_move
        call traffic_update
        call vbpoll
        call track_stream
        call tunnel_state
        call project
        call traffic_prep
        call car_pose
        call lit_restore
P_rows:
        call draw_page
        call draw_mouth
        call lit_close
        call vbpoll
        call hud_update
        call draw_hud
        call vbpoll
        call ovr_paint
P_wait:
        call snd_frame
        call snd_wait           ; steady pacing: flip every FRAMEFIELDS fields
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
        ret

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
        ld (rawkeys),a
        ld a,(apilot)
        ld hl,autodrive
        or (hl)
        ld hl,demo
        or (hl)
        jr z,.man
        call autopilot
.man    ld a,b
        ld (keys),a
        ret
keymap: db K_Z,1, K_COMMA,1, K_LEFT,1
        db K_X,2, K_DOT,2, K_RIGHT,2
        db K_M,4, K_UP,4, K_SPACE,16
        db K_N,8, K_DOWN,8
        db 0

; --------------------------------------------------------------------------
; physics: one 50Hz field step
; --------------------------------------------------------------------------
physics:
        ld a,(boostt)           ; turbo / slipstream: higher top speed, more push
        or a
        jr z,.nb
        dec a
        ld (boostt),a
        ld hl,(speed)
        ld de,ACC+3
        add hl,de
        ld de,MAXSPD+BOOSTV
        jr .lim
.nb     ld a,(keys)
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
.lim    call cmp_signed         ; over the top speed: ease back down
        jr c,.p2
        push hl
        ld hl,(speed)
        call cmp_signed
        pop hl
        jr c,.p3                ; was below it: clamp
        ld hl,(speed)
        dec hl
        dec hl
        dec hl
        call cmp_signed
        jr nc,.p2
.p3     ex de,hl
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
        call advance_dist
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
.nost   ret

; physics_frame: once per frame, for (dt) fields - the curve's pull and the
; panorama scroll (the curve barely changes within a frame)
physics_frame:
        ld a,(camPos+1)         ; centrifugal: camX -= curve*speed/512 per field
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
.cn     call times_dt
        ld de,(camX)
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
        call times_dt
        ld de,(panX)
        add hl,de
        ld (panX),hl
        ret
.c      db 0

; times_dt: HL = HL * (dt)
times_dt:
        ld a,(dt)
        ld b,a
        ld d,h
        ld e,l
        dec b
        ret z
.m      add hl,de
        djnz .m
        ret

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
        ld a,(intun)
        or a
        jp nz,tun_sky
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
        push hl
        call mouth_reset        ; any portal on this page is painted over
        pop hl
        push hl
        ld a,(page)             ; the overlay text must be painted again
        ld e,a
        ld d,0
        ld hl,OVRDIRTY
        add hl,de
        ld a,(OVRACT)
        or (hl)
        ld (hl),a
        pop hl
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
car_pose:
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
        ld (carsrc),hl
        ld a,(page)             ; attribute/colour rows change only with the pose
        ld e,a
        ld d,0
        ld hl,lastpose
        add hl,de
        ld a,(carpose)
        cp (hl)
        ld (hl),a               ; (this page will show this pose)
        ld a,0
        jr z,.same
        inc a
.same   ld (carnewac),a
        ret
carsrc:   dw 0
carnewac: db 0

; --------------------------------------------------------------------------
; car_row: the player's car on car row (crow), straight after write_row and
;   traffic_row built the row (phases, slot allocator and ground records are
;   all still current).  Cell types: 0 empty (ground stays), 1 static
;   character, 2 static light character, 3 partial: a new slot, built from
;   the ground under it (its code's slot records) and the car's mask/ink
;   (CARROAD fast path over plain road, else cellcomp).
; --------------------------------------------------------------------------
car_row:
        call vbpoll
        call patch_comp
        ld a,(crow)
        sub CAR_ROW
        ld b,a                  ; source = carsrc + 30*row
        add a,a
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,a
        sub c                   ; *30
        ld e,a
        ld d,0
        ld iy,(carsrc)
        add iy,de
        ld hl,(raddr)
        ld de,CAR_COL
        add hl,de
        ld (.dst),hl
        ld a,(crow)
        ld e,a
        ld d,0
        push hl
        ld hl,ROWCOL
        add hl,de
        ld a,(hl)
        ld (.gcol),a
        pop hl
        ld a,(rbank)
        or X1C
        out (PORT_1C),a
        ld ix,.attrs
        ld b,10
.cell   ld a,(iy+0)             ; type
        or a
        jr nz,.t1
        ld a,(rbank)            ; empty: ground stays; bank + ground colour
        ld (ix+0),a
        ld a,(.gcol)
        ld (ix+10),a
        jp .nx
.t1     cp 3
        jr z,.t3
        ld c,a
        ld a,(iy+1)             ; static character
        ld (hl),a
        ld a,(iy+2)
        ld (ix+0),a
        ld a,c
        cp 2
        ld a,(.gcol)
        jr nz,.t1c
        ld a,(LIGHTCOL)
.t1c    ld (ix+10),a
        jp .nx
.t3     push bc
        push hl
        ld e,(hl)               ; ground under it: its code's records
        ld d,high(SLOTMASK)
        ld a,(scode)            ; next free slot
        ld (hl),a
        inc a
        ld (scode),a
        ld a,(de)
        ld c,a                  ; C = mask
        inc d
        ld a,(de)               ; A = RES page
        ld de,(sdest)
        cp high(RESPAGES)+2     ; plain road under it? (road page, mask 0)
        jr nz,.slow
        inc c
        dec c
        jr nz,.slow
        ld l,(iy+1)             ; HL = CARROAD + 64*index
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,CARROAD
        add hl,bc
        call carroad
        jr .made
.slow   push ix
        ld b,high(MASKLIB)
        push af
        ld l,(iy+1)             ; IX = CARPART + 32*index
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push de
        ld de,CARPART
        add hl,de
        pop de
        push hl
        pop ix
        pop af
        ld h,a
        call cellcomp
        pop ix
.made   inc de
        ld (sdest),de
        call vbpoll
        ld a,(rbank)
        ld (ix+0),a
        ld a,(.gcol)
        ld (ix+10),a
        pop hl
        pop bc
.nx     inc hl
        inc ix
        inc iy
        inc iy
        inc iy
        dec b
        jp nz,.cell
        call vbpoll
        ld a,X1C
        out (PORT_1C),a
        ld a,(carnewac)         ; pose unchanged on this page: attr/colour stay
        or a
        ret z
        ld hl,(.dst)
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
        ret
.dst    dw 0
.gcol   db 0
.attrs  ds 10
.cols   ds 10

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

; --------------------------------------------------------------------------
; colour themes.  The ground is ONE colour on black (two shades: far rows,
; near rows); verge, kerb and road differ only by dither pattern.
;  per theme: ground far, ground near, tail light, peaks, mountains,
;             sky0..sky4 (top -> horizon), HUD colour
; --------------------------------------------------------------------------
NTHEMES equ 6
THEMES:
        db 4,12, 9,  5,0,  4,4,4,5,13,   0Dh    ; 0 DUSK: blue ground, violet/magenta sky
        db 8,7,  9,  7,0,  1,1,9,9,15,   09h    ; 1 SNOWLINE: grey ground, red sky
        db 2,10, 9,  15,0, 4,4,12,12,14, 0Bh    ; 2 DAYTIME: green ground, blue sky
        db 1,9,  11, 3,0,  4,12,12,6,11, 0Bh    ; 3 RED CENTRE: red earth, blue to gold sky
        db 4,6,  9,  4,0,  0,0,0,0,4,    0Eh    ; 4 NIGHT: dark ground, black sky
        db 8,7,  9,  8,0,  0,0,0,0,8,    0Fh    ; 5 TUNNEL: grey
THEMESZ equ 11
FARROWS equ 10                  ; rows 1..9 use the far shade

set_theme:
        call vbpoll
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
        ld a,0FFh               ; car attribute/colour cache
        ld (lastpose),a
        ld (lastpose+1),a
        ld a,(page)
        push af
        xor a
        ld (page),a
        call vbpoll
        call hud_static
        call vbpoll
        ld a,1
        ld (page),a
        call hud_static
        call vbpoll
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

; --------------------------------------------------------------------------
; load_dat: read BEELINE.DAT into DATSTART..DATEND through BDOS, before the
; program takes the machine over.  Returns to CP/M with a message on error.
; --------------------------------------------------------------------------
BDOS    equ 5
load_dat:
        ld a,(7)                ; BDOS page must lie above the data
        cp high(DATEND)+1
        ld de,M_TPA
        jr c,.fail
        ld de,DATFCB
        ld c,15
        call BDOS
        inc a
        ld de,M_NODAT
        jr z,.fail
        ld hl,DATSTART
.rd     push hl
        ex de,hl
        ld c,26
        call BDOS
        ld de,DATFCB
        ld c,20
        call BDOS
        pop hl
        or a
        jr nz,.eof
        ld de,128
        add hl,de
        ld de,DATEND
        or a
        push hl
        sbc hl,de
        pop hl
        jr c,.rd
        ret
.eof    ld de,DATEND            ; file shorter than expected?
        or a
        sbc hl,de
        ret nc
        ld de,M_NODAT
.fail   ld c,9
        call BDOS
        jp 0
DATFCB: db 0,"BEELINE DAT"
        ds 24
M_TPA:  db "BEELINE: not enough memory (needs CP/M with a TPA to D800h)",13,10,"$"
M_NODAT: db "BEELINE: cannot read BEELINE.DAT",13,10,"$"
        ds 64
LSTACK:

; gen_carroad: CARROAD = every partial car cell composited over plain road,
;   line l, phase p, scanline s at +l*6+p*2+s  (64 bytes per cell)
gen_carroad:
        ld iy,CARPART
        ld de,CARROAD
        ld b,NCARPART
.c      push bc
        ld c,8
.l      ld hl,ROADPAT
        ld b,3
.ph     ld a,(hl)
        and (iy+0)
        or (iy+1)
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        and (iy+2)
        or (iy+3)
        ld (de),a
        inc de
        inc hl
        djnz .ph
        inc iy
        inc iy
        inc iy
        inc iy
        dec c
        jr nz,.l
        ex de,hl
        ld bc,16
        add hl,bc
        ex de,hl
        pop bc
        djnz .c
        ret

; ==========================================================================
        include "../build/gfx.inc"

; ---------------------------------------------------------------- variables
camPos: dw 0
autodrive: db 0
demo:   db 0                    ; test (emulator -poke): autopilot in a normal game
fixdt:  db 0                    ; test mode (emulator -poke): physics steps per frame                 ; set by the emulator (-poke) / attract mode
camX:   dw 0
speed:  dw 0
panX:   dw 0
lastf:  dw 0
flipf:  dw 0
dt:     db 0
boostt: db 0                    ; fields of boost left
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
eprp:   dw 0
EPTRS:  ds 8
THM:    ds THEMESZ
ROWCOL: ds 16
LIGHTCOL: db 0
PANO_COLA: db 0
PANO_COLB: db 0
HUDCOL: db 0
lastsky: ds 4
ROWTYPE: ds 32
        align 16
BX0:    ds 8                    ; BX0 and BX8 contiguous, in one page
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
rbase:  db 0
unif:   db 0
CRLINE: ds 8
        align 16
PHOFF:  ds 8
carpose: db 2
lastpose: db 0FFh,0FFh
steerT: db 0
PTS:    ds (NSEG+1)*8              ; per projected point: sy, sx, sw, phase
ENDIMAGE:
        assert ENDIMAGE < 8000h         ; the .COM must load below 8000h
; ---- runtime-only buffers at 8000h (usable once map_video has run)
        org 8000h
        bss
LINEK:  ds 128
PHT:    ds NSEG+1
        align 256
LPH:    ds 256                  ; per line: band phase offset 0 dark / 10 light / 20 sky (LINEK + 256)
LPH2:   ds 128                  ; per line: phase*2 (carroad offsets), LPH + 256
        align 256
ECODE:  ds 256
SLOTMASK: ds 256                ; per screen code: mask index of its character
SLOTPAGE: ds 256                ; per screen code: RES page of its character
OVRBUF: ds OVR_N*128            ; overlay rows: 64 codes + 64 attributes each
        align 256
ROWBUF: ds 64                   ; tunnel portal: one row of codes
ENDPROG:
        assert ENDPROG <= 8E00h
STACKTOP equ 9000h                      ; stack: 8E00h-8FFFh

; ==========================================================================
; BEELINE.DAT: loaded at 9000h by load_dat (must end below CP/M's BDOS)
; ==========================================================================
        org 9000h
        data
DATSTART:
PCGDATA:
        incbin "../build/pcg.bin"
        include "../build/track.inc"
        include "../build/traffic.inc"
        include "../build/sound.inc"
TUNPCG:
        incbin "../build/tunnel.bin"
        include "../build/tunnel.inc"
DATEND:
        assert DATEND <= 0D800h        ; BDOS of the BEELINE boot disk is at D806h

; ---- runtime-only buffers from D000h (CP/M and the vidmap stub are gone)
        bss
        org 0D800h
CARROAD: ds NCARPART*64
ENDBSS2:
        assert ENDBSS2 <= 0F000h        ; video window above
