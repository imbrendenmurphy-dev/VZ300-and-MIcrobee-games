; ==========================================================================
; engine.asm - the wall renderer (proven on hardware as BEECAST V2)
;   VIBED BY BPM 2026
;
;   * 80 rays across the screen, two per character column.  Each ray is a
;     grid walk (DDA).  All multiplying is done by adding logs and looking
;     the answer up.  Only every second ray is always cast; where its
;     neighbours hit the same wall plane the gap is their average.
;   * The 3D window is 40 x 22 cells.  Every cell shows one PCG character
;     whose left and right halves are wall to different heights:
;     code = 80h + 11 * left + right (0..10 scanlines of wall each).
;   * The PCG bank (attribute RAM) picks the dither pattern, colour RAM the
;     ink; the paper is the zone's ceiling colour above the horizon and its
;     floor colour below.
;   * Two screen pages, flipped in vertical blank.  Each page remembers
;     what every column showed, and only the cells that changed are written.
;   * Every half column leaves its wall distance in ZB for the sprites.
;
; Runs with BLK_TAB in the lower window.
; ==========================================================================

; per-column state, 512 bytes per screen page, IX = base+128+x
S_EL    equ -128                ; scanlines of ceiling above the left half
S_ER    equ -88                 ; ... right half
S_COL   equ -48                 ; wall ink
S_PAT   equ -8                  ; wall pattern (PCG bank)
S_TMIN  equ 32                  ; first row with any wall in it
S_TFULL equ 72                  ; first row that is all wall
S_SK    equ 112                 ; shade key the ink and pattern came from

; --------------------------------------------------------------------------
; reset_view: empty 3D window on both pages, in the zone's colours.
;   Afterwards every cell outside a wall is right for good: blank above the
;   horizon, floor dots below it (the row's own PCG bank group).
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
        ld hl,PCGWIN+40
        call .cols
        ld hl,PCGWIN+400h+40
        call .cols
        xor a
        out (PORT_08),a
        ld hl,STATE
        call .pg
        ld hl,STATE+512
.pg     ld b,80                 ; no wall anywhere yet
.a      ld (hl),NOWALL
        inc hl
        djnz .a
        ld b,80                 ; ink and pattern unknown
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
.cols   ld a,(cpaper)           ; ceiling rows
        push hl
        ld bc,439
        call fillv
        pop hl
        ld de,440
        add hl,de
        ld a,(floorc)           ; floor rows: floor paper and dot ink
        ld b,a
        ld a,(fpaper)
        or b
        ld bc,439
        jp fillv
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
; frame_setup: the things every ray of this frame shares
; --------------------------------------------------------------------------
frame_setup:
        ld a,(M_st1+1)          ; a new stamp for the cells the rays cross
        inc a
        jr nz,.st
        inc a
.st     ld (M_st1+1),a
        ld (M_st2+1),a
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
;            E = wall plane: the x of the grid line hit, or 32 + its y
;            (rz) = distance in 1/8 cell (0..255)
;       (rp) is left pointing at the next table entry.  The wall cell hit
;       is marked in SEEN (for the map).
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
        set 3,h                 ; STAMP = MAP + 800h: crossed this frame
M_st1:  ld (hl),0
        res 3,h
        ld a,(hl)
        exx
        or a
        jp z,.dda
        sbc hl,bc               ; distance to the face just crossed
        ld c,a
        exx
        set 2,h                 ; SEEN = MAP + 400h
        ld (hl),a
        res 2,h
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
        set 3,h
M_st2:  ld (hl),0
        res 3,h
        ld a,(hl)
        exx
        or a
        jp z,.dda
        ex de,hl
        sbc hl,bc
        ld c,a
        exx
        set 2,h
        ld (hl),a
        res 2,h
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
        ld a,l
        rrca
        rrca
        rrca
        and 1Fh
        ld d,a
        ld a,h
        rrca
        rrca
        rrca
        or d
        ld (rz),a               ; distance in 1/8 cell for the sprites
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
        ld a,(rz)
        ld (cur_z),a
.pair   call vbpoll
        ld hl,(rp)              ; the next even ray (left half of the next column)
        call cast
        ld b,a
        ld (nxt_e),a
        ld a,c
        ld (nxt_sk),a
        ld a,(rz)
        ld (nxt_z),a
        ld a,e
        ld (nxt_key),a
        ld hl,cur_key           ; same wall plane on both sides of the gap?
        cp (hl)
        jr nz,.real
        ld a,(cur_e)
        ld c,a                  ; C = this column's left ray, B = the next one
        or a                    ; a wall taller than the window is clipped,
        jr z,.cz                ; so it can only be averaged with another one
        ld a,b
        or a
        jr z,.real
        jr .mid
.cz     ld a,b
        or a
        jr nz,.real
.mid    ld a,(cur_z)            ; right half distance: the average too
        ld hl,nxt_z
        add a,(hl)
        rra
        ld (rz),a
        ld a,c
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
.draw   push af
        ld a,(colx)             ; depth of both halves for the sprites
        add a,a
        ld l,a
        ld h,high(ZB)
        ld a,(cur_z)
        ld (hl),a
        inc l
        ld a,(rz)
        ld (hl),a
        pop af
        call drawpair
        ld hl,(nxt_e)
        ld (cur_e),hl
        ld a,(nxt_key)
        ld (cur_key),a
        ld a,(nxt_z)
        ld (cur_z),a
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
        ld a,(colx)
        add a,a
        ld l,a
        ld h,high(ZB)
        ld a,(rz)
        ld (hl),a
        inc l
        ld (hl),a
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
;   those rows carry the wall's ink and PCG bank; see reset_view.
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
M_shofs: add a,0                ; 0 = colour tables, 128 = mono tables
        ld l,a
        ld h,high(SHC)
        ld a,(hl)
        ld (d_col),a
        inc h                   ; SHP follows SHC
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
        ld (ix+S_COL),a         ; new ink: the whole wall span
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

; colfill: ink E into B cells down column (colx) from view row A; the paper
;          is the ceiling's above the horizon and the floor's below
colfill:
        ld c,a
        call rowadr
        ld a,h
        add a,8
        ld h,a
        ld a,(cpaper)
        or e
        ld d,a
        ld a,(fpaper)
        or e
        ld e,a
        ld a,40h
        out (PORT_08),a
.l      ld a,c
        cp 11
        ld a,d
        jr c,.t
        ld a,e
.t      ld (hl),a
        ld a,l
        add a,40
        ld l,a
        jr nc,.n
        inc h
.n      inc c
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
; flip: show the page just drawn from the next vertical blank (playing the
;       sound effect while waiting); count fields
; --------------------------------------------------------------------------
flip:   call snd_wait
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

; showpage0: point the 6545 at page 0 (text screens) and draw on page 0
showpage0:
        ld a,12
        out (CRTC_A),a
        xor a
        out (CRTC_D),a
        ld a,13
        out (CRTC_A),a
        xor a
        out (CRTC_D),a
        ld a,1                  ; the next page drawn is page 1
        ld (page),a
        ld a,64
        ld (M_pgrow+1),a
        ld (M_pgrow2+1),a
        ret
