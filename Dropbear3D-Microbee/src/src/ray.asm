; ==========================================================================
; ray.asm - RAY.COM : first-person raycaster speed test for the
;           Microbee Premium Plus (native Z80, 40 x 25 mode, 320 x 250)
;   VIBED BY BPM 2026
;
; A walkable test level drawn with character cells, no bitmap:
;
;   * 80 rays across the screen, two per character column.  Each ray is a
;     grid walk (DDA).  All multiplying is done by adding logs and looking
;     the answer up, so a ray costs about 1,200 T-states.
;   * Only every second ray is always cast.  If the rays either side of a
;     gap hit the same wall plane, the wall height between them is their
;     average (exact for a flat wall), otherwise the gap ray is cast too.
;     About 45 real rays draw an 80-ray picture.  (R switches to a plain
;     40-ray mode, one ray per character column, to compare.)
;   * The 3D window is 40 x 22 cells.  Every cell shows one PCG character
;     whose left and right halves are wall to different heights, so wall
;     tops and bottoms are exact to the scanline at 4-pixel column width.
;     Code = 80h + 11 * left + right (0..10 scanlines of wall each).
;   * The PCG bank (attribute RAM) picks the dither pattern, so shading a
;     whole column costs nothing per frame; colour RAM picks the hue.
;   * Two screen pages, flipped in vertical blank.  Each page remembers
;     what every column showed, and only the cells that changed are
;     written.
;
; Tables, the map and the PCG data come from tools/gen.py.
; ==========================================================================
        org 100h
        jp start
        include "hw.asm"

; per-column state, 512 bytes per screen page, IX = base+128+x
S_EL    equ -128                ; scanlines of ceiling above the left half
S_ER    equ -88                 ; ... right half
S_COL   equ -48                 ; wall colour
S_PAT   equ -8                  ; wall pattern (PCG bank)
S_TMIN  equ 32                  ; first row with any wall in it
S_TFULL equ 72                  ; first row that is all wall
S_SK    equ 112                 ; shade key the colour and pattern came from

MARGIN  equ 0040h               ; keep a quarter of a cell away from walls
TURN    equ 14                  ; angle units per field (2048 = full circle)
FLOORC  equ 08h                 ; floor dots: dark grey

start:
        di
        ld sp,0EF00h
        call map_video
        call init_video
        call reset_view
        call text_static
        ld hl,0
        ld (fields),hl
        ld (flast),hl
        ld (fmark),hl

main:
P_frame:
        call input
P_render:
        call frame_setup
        call render
P_hud:
        call hud
P_flip:
        call flip
        jp main

; --------------------------------------------------------------------------
; reset_view: empty 3D window on both pages.  Afterwards every cell
;   outside a wall is right for good: blank above the horizon, floor dots
;   (in the floor colour, from the row's own PCG bank group) below it.
; --------------------------------------------------------------------------
reset_view:
        ld hl,VRAM+40
        ld a,80h
        ld bc,879
        call fillv
        ld hl,VRAM+400h+40
        ld a,80h
        ld bc,879
        call fillv
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld hl,VRAM+40
        call .attrs
        ld hl,VRAM+400h+40
        call .attrs
        ld a,X1C
        out (PORT_1C),a
        ld a,40h
        out (PORT_08),a
        ld hl,PCGWIN+12*40
        ld a,(floorc)
        ld bc,439
        call fillv
        ld hl,PCGWIN+400h+12*40
        ld a,(floorc)
        ld bc,439
        call fillv
        xor a
        out (PORT_08),a
        ld hl,STATE
        call .pg
        ld hl,STATE+512
.pg     ld b,80                 ; no wall anywhere yet
        ; (NOWALL = every scanline above the horizon is ceiling)
.a      ld (hl),NOWALL
        inc hl
        djnz .a
        ld b,80                 ; colour and pattern unknown
.b      ld (hl),0FFh
        inc hl
        djnz .b
        ld b,80
.c      ld (hl),11
        inc hl
        djnz .c
        ld b,40
.d      ld (hl),0FFh
        inc hl
        djnz .d
        ret
.attrs  xor a                   ; 11 rows above the horizon
        ld bc,439
        call fillv
        inc hl
        ld a,4                  ; 4 rows of far floor
        ld bc,159
        call fillv
        inc hl
        ld a,8                  ; 7 rows of near floor
        ld bc,279
; fillv: BC+1 bytes of A from HL; HL ends on the last byte
fillv:  ld (hl),a
        ld d,h
        ld e,l
        inc de
        ldir
        dec de
        ex de,hl
        ret

; --------------------------------------------------------------------------
; input: keys, movement with wall sliding, mode toggles, benchmark
; --------------------------------------------------------------------------
input:
        ld a,(lastf)            ; move by the time the last frame took
        or a
        jr nz,.n1
        inc a
.n1     cp 7
        jr c,.n2
        ld a,6
.n2     ld (nstep),a
        call readkeys
        call vbpoll
        ld a,(bstage)
        or a
        jp nz,bench_step

        ld a,(keyst+0)
        ld hl,kl_r
        call edge
        jr z,.nor
        ld a,(M_rays+1)
        xor 1
        ld (M_rays+1),a
        call show_rays
.nor    ld a,(keyst+1)
        ld hl,kl_c
        call edge
        jr z,.noc
        ld a,(M_shofs+1)
        xor 128
        ld (M_shofs+1),a
        ld a,FLOORC
        jr z,.fc
        ld a,0Fh
.fc     ld (floorc),a
        call reset_view
.noc    ld a,(keyst+2)
        ld hl,kl_b
        call edge
        jp nz,bench_start

        ld a,(keyst+3)
        ld hl,keyst+4
        or (hl)
        jr z,.ntl
        ld de,-TURN
        call turn
.ntl    ld a,(keyst+5)
        ld hl,keyst+6
        or (hl)
        jr z,.ntr
        ld de,TURN
        call turn
.ntr    xor a
        ld (mvneg),a
        ld a,(keyst+7)
        ld hl,keyst+8
        or (hl)
        jr nz,.go
        ld a,1
        ld (mvneg),a
        ld a,(keyst+9)
        ld hl,keyst+10
        or (hl)
        ret z
.go     ld hl,(pa)
        call mvget
        call movex
        ld hl,(pa)
        ld de,-512              ; sin(a) = cos(a - 90 degrees)
        add hl,de
        ld a,h
        and 7
        ld h,a
        call mvget
        jp movey

; readkeys: scan the keys once per frame into keyst (1 = held).  The
;           keyboard scan needs the ROM latch (port 0Bh) on, and nothing
;           may write to the screen while it is, so no drawing happens here.
NKEYS   equ 11
KEYLIST: db K_R,K_C,K_B,K_LEFT,K_A,K_RIGHT,K_D,K_UP,K_W,K_DOWN,K_S
readkeys:
        ld a,1
        out (PORT_0B),a
        ld hl,KEYLIST
        ld de,keyst
        ld b,NKEYS
.l      push bc
        push hl
        push de
        ld a,(hl)
        call keytest
        pop de
        pop hl
        pop bc
        ld a,0
        jr z,.u
        inc a
.u      ld (de),a
        inc hl
        inc de
        djnz .l
        xor a
        out (PORT_0B),a
        ret

; edge: A = key state now, HL -> its last state.  NZ only when newly pressed
edge:   or a
        jr z,.up
        ld a,(hl)
        ld (hl),1
        xor 1
        ret
.up     ld (hl),0
        ret

; turn: pa += DE * nstep
turn:   ld a,(nstep)
        ld b,a
        ld hl,(pa)
.l      add hl,de
        djnz .l
        ld a,h
        and 7
        ld h,a
        ld (pa),hl
        ret

; mvget: HL = angle -> DE = distance along that axis this frame
;        (1/65536 cell units, signed, negated when walking backwards)
mvget:  add hl,hl
        ld de,MVT
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(nstep)
        ld b,a
        ld hl,0
.l      add hl,de
        djnz .l
        ex de,hl
        ld a,(mvneg)
        or a
        ret z
        xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
        ret

; movex: try to move by DE along x; the move is refused if it would put
;        the player within MARGIN of a wall (so you slide along walls)
movex:  ld hl,(px)
        ld a,(px+2)
        add hl,de
        bit 7,d
        jr z,.p
        adc a,0FFh
        jr .s
.p      adc a,0
.s      ld (nx),hl
        ld (nx+2),a
        ld l,h
        ld h,a                  ; HL = new x as cell.fraction
        ld bc,MARGIN
        bit 7,d
        jr z,.pp
        ld bc,-MARGIN
.pp     add hl,bc
        ld b,h                  ; B = cell to test
        ld hl,(py+1)
        ld de,-MARGIN
        add hl,de
        ld c,h
        push bc
        call cellat
        pop bc
        or a
        ret nz
        ld hl,(py+1)
        ld de,MARGIN
        add hl,de
        ld c,h
        call cellat
        or a
        ret nz
        ld hl,(nx)
        ld (px),hl
        ld a,(nx+2)
        ld (px+2),a
        ret

movey:  ld hl,(py)
        ld a,(py+2)
        add hl,de
        bit 7,d
        jr z,.p
        adc a,0FFh
        jr .s
.p      adc a,0
.s      ld (nx),hl
        ld (nx+2),a
        ld l,h
        ld h,a
        ld bc,MARGIN
        bit 7,d
        jr z,.pp
        ld bc,-MARGIN
.pp     add hl,bc
        ld c,h                  ; C = row to test
        ld hl,(px+1)
        ld de,-MARGIN
        add hl,de
        ld b,h
        push bc
        call cellat
        pop bc
        or a
        ret nz
        ld hl,(px+1)
        ld de,MARGIN
        add hl,de
        ld b,h
        call cellat
        or a
        ret nz
        ld hl,(nx)
        ld (py),hl
        ld a,(nx+2)
        ld (py+2),a
        ret

; cellat: B = x cell, C = y cell -> A = map cell (0 = open)
cellat: ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or b
        ld l,a
        ld de,MAP
        add hl,de
        ld a,(hl)
        ret

; --------------------------------------------------------------------------
; benchmark: spin once on the spot (128 frames) in the hall, then in the
;            corridor, and show the average frames per second for each
; --------------------------------------------------------------------------
bench_start:
        ld hl,px
        ld de,bsave
        ld bc,8
        ldir
        ld a,1
        ld (bstage),a
bench_spot:
        ld a,(bstage)
        dec a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,SPOTS
        add hl,de
        xor a
        ld (px),a
        ld (py),a
        ld (bframe),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (px+1),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (py+1),de
        ld hl,0
        ld (pa),hl
        ld hl,(fields)
        ld (bf0),hl
        ret
bench_step:
        ld hl,(pa)
        ld de,16
        add hl,de
        ld a,h
        and 7
        ld h,a
        ld (pa),hl
        ld a,(bframe)
        inc a
        ld (bframe),a
        cp 128
        ret nz
        ld hl,(fields)
        ld de,(bf0)
        or a
        sbc hl,de
        ex de,hl
        ld hl,64000             ; 128 frames * 50 fields * 10
        call div16
        ld a,(bstage)
        cp 2
        jr z,.last
        ld (bres),bc
        ld a,2
        ld (bstage),a
        jr bench_spot
.last   ld (bres+2),bc
        xor a
        ld (bstage),a
        ld hl,bsave
        ld de,px
        ld bc,8
        ldir
        ld hl,T_BENCH
        ld de,23*40
        call print
        ld a,(M_rays+1)
        or a
        ld hl,T_80
        jr nz,.r
        ld hl,T_40
.r      ld de,23*40+6
        call print
        ld hl,(bres)
        ld de,23*40+20
        call prfps
        ld hl,(bres+2)
        ld de,23*40+34
        jp prfps

SPOTS:  dw 1480h, 0480h         ; hall  (20.5, 4.5)
        dw 0C80h, 0C80h         ; corridor (12.5, 12.5)

; --------------------------------------------------------------------------
; frame_setup: the things every ray of this frame shares
; --------------------------------------------------------------------------
frame_setup:
        ld a,(py+2)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(px+2)
        or l
        ld l,a
        ld de,MAP
        add hl,de
        ld (M_map+1),hl
        ld a,(px+1)
        ld hl,lfxp
        call .logs
        ld a,(py+1)
        ld hl,lfyp
        call .logs
        ld hl,(pa)
        ld (M_pa+1),hl
        ld a,0FFh
        ld (M_lastq+1),a
        ret
; A = fraction, HL -> two words: log(1-f), log(f)
.logs   push hl
        ld l,a
        ld h,0
        add hl,hl
        push hl
        ld de,LFP
        add hl,de
        ld c,(hl)
        inc hl
        ld b,(hl)
        pop hl
        ld de,LFN
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; setquad: A = quadrant of the ray (0..3).  Sets the grid step directions
;          and which fraction (to the next line that way) starts the walk.
;          Keeps HL and DE.
setquad:
        ld (M_lastq+1),a
        push hl
        or a
        jr z,.xp
        cp 3
        jr z,.xp
        ld hl,-1
        ld (M_stepx+1),hl
        ld hl,(lfxn)
        jr .x
.xp     ld hl,1
        ld (M_stepx+1),hl
        ld hl,(lfxp)
.x      ld (M_lfx+1),hl
        ld a,(M_lastq+1)
        cp 2
        jr nc,.yn
        ld hl,32
        ld (M_stepy+1),hl
        ld hl,(lfyp)
        jr .y
.yn     ld hl,-32
        ld (M_stepy+1),hl
        ld hl,(lfyn)
.y      ld (M_lfy+1),hl
        pop hl
        ret

; --------------------------------------------------------------------------
; cast: one ray.  HL -> ray table entry (angle offset, log cos offset)
;       out: A = scanlines of ceiling above the wall (0..109)
;            C = shade key: wall type * 8 + side * 4 + band
;                (side 0 = x face, 1 = y face; band = distance / 4 cells)
;            E = wall plane: the x of the grid line hit, or 32 + its y
;       (rp) is left pointing at the next table entry
;
;   step per cell   ddx = cos(offset) / |cos(angle)|   (same for y, sin)
;   first step      sx  = ddx * fraction to the next grid line
;   Both come from EXPT[ log(1/|cos|) + log(cos offset) (+ log fraction) ].
;   Scaling by cos(offset) makes the walk measure straight-ahead distance,
;   which is what the wall height needs (no fish-eye, no multiply).
; --------------------------------------------------------------------------
cast:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (rp),hl              ; rays are mostly cast in table order
        ex de,hl                ; HL = angle offset, BC = log cos offset
M_pa:   ld de,0                 ; the player's facing
        add hl,de
        ld a,h
        and 7
        ld h,a
        srl a
M_lastq: cp 0FFh
        call nz,setquad
        add hl,hl
        add hl,hl
        ld de,LD4
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        add hl,bc
        ld (M_ly+1),hl          ; log ddy
        ex de,hl
        add hl,bc
        ld d,h
        ld e,l                  ; DE = log ddx
        add hl,hl
        ld bc,EXPT
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (M_ddx+1),hl
M_lfx:  ld hl,0
        add hl,de
        bit 7,h
        jr nz,.zx
        add hl,hl
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr .sx
.zx     ld hl,0
.sx     ld (M_sx+1),hl
M_ly:   ld hl,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (M_ddy+1),hl
M_lfy:  ld hl,0
        add hl,de
        bit 7,h
        jr nz,.zy
        add hl,hl
        add hl,bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        jr .sy
.zy     ld de,0
.sy                             ; DE = distance to the first y line
M_sx:   ld hl,0                 ; HL = distance to the first x line
        exx
M_map:  ld hl,0                 ; the player's map cell
M_stepx: ld de,1
M_stepy: ld bc,32
        exx
.dda    ld a,l
        sub e
        ld a,h
        sbc a,d
        jr nc,.ys
M_ddx:  ld bc,0
        add hl,bc
        exx
        add hl,de
        ld a,(hl)
        exx
        or a
        jp z,.dda
        sbc hl,bc               ; distance to the face just crossed
        ld c,a
        exx
        ld a,l
        exx
        and 31
        ld e,a
        ld b,0
        jp .hit
.ys     ex de,hl
M_ddy:  ld bc,0
        add hl,bc
        ex de,hl
        exx
        add hl,bc
        ld a,(hl)
        exx
        or a
        jp z,.dda
        ex de,hl
        sbc hl,bc
        ld c,a
        exx
        ld a,h
        sub high(MAP)
        add a,a
        add a,a
        add a,a
        ld d,a
        ld a,l
        rlca
        rlca
        rlca
        and 7
        or d
        or 32
        exx
        ld e,a
        ld b,1
.hit    ld a,h
        cp 32
        jr c,.ok
        ld hl,1FFFh
.ok     srl h
        rr l
        srl h
        rr l                    ; distance in 1/64 cell, 0..2047
        ld a,h
        cp 4
        jr c,.bd
        ld a,3
.bd     ld d,a                  ; shading band: every 4 cells
        ld a,c
        add a,a
        add a,b
        add a,a
        add a,a
        add a,d
        ld c,a
        ld a,h
        add a,high(ET)
        ld h,a
        ld a,(hl)
        ret

; --------------------------------------------------------------------------
; render: 40 character columns of two half-columns each
; --------------------------------------------------------------------------
render:
        ld a,(page)
        add a,a
        add a,high(STATE)
        ld h,a
        ld l,128
        push hl
        pop ix
        xor a
        ld (colx),a
M_rays: ld a,1                  ; 1 = 80-ray picture, 0 = 40 rays
        or a
        jp z,render40
        ld hl,RAYA
        call cast
        ld (cur_e),a
        ld a,c
        ld (cur_sk),a
        ld a,e
        ld (cur_key),a
.pair   call vbpoll
        ld hl,(rp)              ; the next even ray (left half of the next column)
        call cast
        ld b,a
        ld (nxt_e),a
        ld a,c
        ld (nxt_sk),a
        ld a,e
        ld (nxt_key),a
        ld hl,cur_key           ; same wall plane on both sides of the gap?
        cp (hl)
        jr nz,.real
        dec hl
        dec hl
        ld c,(hl)               ; C = this column's left ray, B = the next one
        ld a,c
        or a                    ; a wall taller than the window is clipped,
        jr z,.cz                ; so it can only be averaged with another one
        ld a,b
        or a
        jr z,.real
        jr .mid
.cz     ld a,b
        or a
        jr nz,.real
.mid    ld a,c
        add a,b
        inc a
        srl a
        ld b,c
        ld c,a
        ld a,(cur_sk)
        jr .draw
.real   ld hl,(rp)
        push hl
        ld a,(colx)
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,RAYO
        add hl,de
        call cast               ; the odd ray of this column
        pop hl
        ld (rp),hl
        ld d,c
        ld c,a
        ld a,(cur_e)
        ld b,a
        cp c
        ld a,(cur_sk)
        jr c,.draw              ; the nearer half gives the colour and shade
        jr z,.draw
        ld a,d
.draw   call drawpair
        ld hl,(nxt_e)
        ld (cur_e),hl
        ld a,(nxt_key)
        ld (cur_key),a
        inc ix
        ld hl,colx
        inc (hl)
        ld a,(hl)
        cp 40
        jp nz,.pair
        ret

render40:
        ld hl,RAY40
        ld (rp),hl
.pair   call vbpoll
        ld hl,(rp)
        call cast
        ld b,a
        ld a,c
        ld c,b
        call drawpair
        inc ix
        ld hl,colx
        inc (hl)
        ld a,(hl)
        cp 40
        jp nz,.pair
        ret

; --------------------------------------------------------------------------
; drawpair: bring column (colx) of the hidden page up to date.
;   A = shade key, B, C = ceiling scanlines for the left and right halves
;   The wall covers rows n .. 21-n (n = first row with wall in it).  Only
;   those rows carry the wall's colour and PCG bank; see reset_view.
; --------------------------------------------------------------------------
drawpair:
        ld e,a
        cp (ix+S_SK)
        jr nz,.look
        ld a,b
        cp (ix+S_EL)
        jr nz,.look
        ld a,c
        cp (ix+S_ER)
        ret z                   ; nothing changed in this column
.look   ld a,e
        ld (ix+S_SK),a
M_shofs: add a,0                ; 0 = colour table, 128 = mono table
        ld l,a
        ld h,high(SHTAB)
        ld a,(hl)
        ld (d_col),a
        set 6,l
        ld a,(hl)
        ld (d_pat),a
        ld a,c
        cp b
        jr c,.rmin
        ld d,b
        ld e,c
        jr .mm
.rmin   ld d,c
        ld e,b
.mm     ld l,d                  ; D = smaller, E = larger
        ld h,high(TMINT)
        ld a,(hl)
        ld h,a                  ; first row with wall in it
        ld (n_tmin),a
        ld a,(ix+S_TMIN)
        ld (o_tmin),a
        ld a,b
        cp (ix+S_EL)
        jr nz,.chars
        ld a,c
        cp (ix+S_ER)
        jp z,.colours
.chars  push hl
        ld a,e
        add a,low(TFULLT)
        ld l,a
        ld a,high(TFULLT)
        adc a,0
        ld h,a
        ld a,(hl)
        pop hl
        ld l,a                  ; first row that is all wall
        ld a,(o_tmin)
        cp h
        jr c,.r0
        ld a,h
.r0     ld d,a                  ; D = first row to rewrite
        ld a,(ix+S_TFULL)
        cp l
        jr nc,.r1
        ld a,l
.r1     sub d                   ; rows to rewrite (mirrored below the horizon)
        ld (ix+S_EL),b
        ld (ix+S_ER),c
        ld (ix+S_TMIN),h
        ld (ix+S_TFULL),l
        jp z,.colours
        ld (cnt),a
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or d
        ld l,a
        ld a,h
        add a,high(PROFL)
        ld h,a
        push hl                 ; left half profile, times 11
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or d
        ld l,a
        ld a,h
        add a,high(PROF)
        ld h,a                  ; right half profile (+80h)
        ld a,d
        exx
        add a,a
        ld c,a
M_pgrow: add a,64               ; this page's row table (0 or 64)
        ld l,a
        ld h,high(ROWT)
        ld e,(hl)
        inc l
        ld d,(hl)               ; top row address
        ld a,42
        sub c
M_pgrow2: add a,64
        ld l,a
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a                  ; mirror row address
        ld bc,(colx)
        add hl,bc
        ex de,hl
        add hl,bc               ; HL = top cell, DE = bottom cell
        ld bc,40
        exx
        pop de
        ld a,(cnt)
        ld b,a
.loop   ld a,(de)
        add a,(hl)
        inc e
        inc l
        exx
        ld (hl),a
        add hl,bc
        ld (de),a
        ex de,hl
        or a
        sbc hl,bc
        ex de,hl
        exx
        djnz .loop

.colours
        ld a,(n_tmin)
        ld c,a                  ; C = n, B = o (the old first wall row)
        ld a,(o_tmin)
        ld b,a
        ld a,(d_col)
        cp (ix+S_COL)
        jr z,.csame
        ld (ix+S_COL),a         ; new colour: the whole wall span
        ld e,a
        ld a,22
        sub c
        sub c
        ld b,a
        ld a,c
        call colfill
        ld a,(o_tmin)
        ld b,a
        ld a,(n_tmin)
        ld c,a
        jr .cshr
.csame  ld a,c
        cp b
        jr nc,.cshr
        ld a,(d_col)            ; taller: the rows gained above and below
        ld e,a
        ld a,b
        sub c
        ld b,a
        push bc
        ld a,c
        call colfill
        pop bc
        ld a,(d_col)
        ld e,a
        ld a,(o_tmin)
        neg
        add a,22
        call colfill
        jr .attr
.cshr   ld a,b
        cp c
        jr nc,.attr
        ld a,c                  ; shorter: the rows given back to the floor
        sub b
        ld b,a
        ld a,(floorc)
        ld e,a
        ld a,22
        sub c
        call colfill
.attr   ld a,(n_tmin)
        ld c,a
        ld a,(o_tmin)
        ld b,a
        ld a,(d_pat)
        cp (ix+S_PAT)
        jr z,.asame
        ld (ix+S_PAT),a
        ld a,22
        sub c
        sub c
        ld b,a
        ld a,c
        jp attrfill
.asame  ld a,c
        cp b
        ret nc
        ld a,b
        sub c
        ld b,a
        push bc
        ld a,c
        call attrfill
        pop bc
        ld a,(o_tmin)
        neg
        add a,22
        jp attrfill

; colfill: colour E into B cells down column (colx) from view row A
colfill:
        call rowadr
        ld a,h
        add a,8
        ld h,a
        ld a,40h
        out (PORT_08),a
        ld a,e
        ld de,40
.l      ld (hl),a
        add hl,de
        djnz .l
        xor a
        out (PORT_08),a
        ret

; attrfill: PCG bank for pattern (d_pat) into B cells from view row A
attrfill:
        ld c,a
        call rowadr
        ld a,c
        add a,low(ROWBANK)
        ld e,a
        ld a,high(ROWBANK)
        adc a,0
        ld d,a
        ld a,(d_pat)
        ld c,a
        ld a,X1C_ATTR
        out (PORT_1C),a
.l      ld a,(de)
        inc de
        add a,c
        ld (hl),a
        ld a,l
        add a,40
        ld l,a
        jr nc,.n
        inc h
.n      djnz .l
        ld a,X1C
        out (PORT_1C),a
        ret

; rowadr: HL = screen address of view row A in column (colx), hidden page
;         keeps BC, DE
rowadr: add a,a
        ld l,a
        ld a,(M_pgrow+1)
        add a,l
        ld l,a
        ld h,high(ROWT)
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,(colx)
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; --------------------------------------------------------------------------
; flip: show the page just drawn from the next vertical blank; count fields
; --------------------------------------------------------------------------
flip:   call wait_vb
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
        rrca
        rrca
        ld (M_pgrow+1),a
        ld (M_pgrow2+1),a
        ld hl,(fields)
        ld de,(flast)
        ld (flast),hl
        or a
        sbc hl,de
        ld a,l
        ld (lastf),a
        ret

; hud: frames per second, averaged over 16 frames
hud:    ld a,(fcount)
        inc a
        and 15
        ld (fcount),a
        ret nz
        ld hl,(fields)
        ld de,(fmark)
        ld (fmark),hl
        or a
        sbc hl,de
        ex de,hl
        ld a,d
        or e
        ret z
        ld hl,8000              ; 16 frames * 50 fields * 10
        call div16
        ld h,b
        ld l,c
        ld de,36
        jp prfps

; div16: BC = HL / DE (unsigned)
div16:  ld a,h
        ld c,l
        ld hl,0
        ld b,16
.l      sla c
        rla
        adc hl,hl
        sbc hl,de
        jr nc,.ok
        add hl,de
        jr .n
.ok     inc c
.n      djnz .l
        ld b,a
        ret

; prfps: HL = frames per second * 10 (0..999) as "dd.d" at screen offset DE
prfps:  push de
        ld ix,NUMBUF
        ld bc,-100
        call .d
        ld bc,-10
        call .d
        ld (ix+0),'.'
        inc ix
        ld a,l
        add a,'0'
        ld (ix+0),a
        pop de
        ld hl,NUMBUF
        jp print
.d      ld a,'0'-1
.dl     inc a
        add hl,bc
        jr c,.dl
        sbc hl,bc
        ld (ix+0),a
        inc ix
        ret

; print: zero-terminated capitals at HL -> screen offset DE, on both pages
print:  ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        sub 32
        ld l,a
        ld h,0
        ld bc,FMAP
        add hl,bc
        ld a,(hl)
        ld hl,VRAM
        add hl,de
        ld (hl),a
        ld bc,400h
        add hl,bc
        ld (hl),a
        pop hl
        inc de
        jr print

show_rays:
        ld a,(M_rays+1)
        or a
        ld hl,T_80
        jr nz,.r
        ld hl,T_40
.r      ld de,24
        jp print

text_static:
        ld hl,T_TOP
        ld de,0
        call print
        ld hl,T_KEYS
        ld de,23*40
        call print
        ld hl,T_KEYS2
        ld de,24*40
        jp print

T_TOP:   db "BEECAST 3D TEST V2      80 RAYS FPS",0
T_KEYS:  db "ARROWS OR WASD: MOVE    R: 40/80 RAYS  ",0
T_KEYS2: db "C: MONO  B: BENCH  VIBED BY BPM 2026",0
T_BENCH: db "BENCH 80 RAYS: HALL 00.0 CORRIDOR 00.0 ",0
T_80:    db "80",0
T_40:    db "40",0

; ---------------------------------------------------------------- variables
px:     db 0,80h,7              ; x: 1/65536, 1/256, cell   (7.5)
py:     db 0,80h,5              ; y                          (5.5)
pa:     dw 0                    ; facing, 0..2047 (0 = east)
bsave:  ds 8
nx:     ds 3
nstep:  db 1
mvneg:  db 0
lastf:  db 1
flast:  dw 0
fmark:  dw 0
fcount: db 0
page:   db 1                    ; page being drawn (page 0 is on screen first)
colx:   dw 0
cnt:    db 0
n_tmin: db 0
o_tmin: db 0
d_col:  db 0
d_pat:  db 0
floorc: db FLOORC
rp:     dw 0                    ; ray table pointer
cur_e:  db 0                    ; the left ray of the column being drawn
cur_sk: db 0
cur_key: db 0
nxt_e:  db 0                    ; the left ray of the next column
nxt_sk: db 0
nxt_key: db 0
lfxp:   dw 0
lfxn:   dw 0
lfyp:   dw 0
lfyn:   dw 0
keyst:  ds NKEYS
kl_r:   db 0
kl_c:   db 0
kl_b:   db 0
bstage: db 0
bframe: db 0
bf0:    dw 0
bres:   dw 0,0
NUMBUF: ds 8

        include "../build/tables.inc"
PCGDATA:
        incbin "../build/pcg.bin"
        align 256
STATE:  ds 1024
