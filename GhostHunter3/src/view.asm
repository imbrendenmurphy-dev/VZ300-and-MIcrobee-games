; =====================================================================
;  GHOST HUNTER 3 - the scrolling view
;
;  The maze lives in BennVenn SRAM bank A ($4000, port $37 = 1) as a ring
;  of 58 pixel rows (exactly the viewport height).  Each ring row holds the
;  same map row four times, pre-shifted by 0..3 pixels (4 x 42 bytes), so
;  any camera x is a plain byte copy.  Map row R lives in ring slot R mod 58.
;  When the camera moves a row, the one new map row is rendered from the
;  tile grid.  Frames where the camera moved redraw the whole viewport with
;  a generated stack copy (top half, its sprites, bottom half, its sprites),
;  so nothing flickers; other frames just erase and redraw the sprites.
; =====================================================================
RING    equ $4000
RSTRIDE equ 168
PSTRIDE equ 42
VPROWS  equ 58
VPTOP   equ 6
MAPW    equ 27
GSTRIDE equ 28                  ; grid row stride (col 27 = guard wall)
MAPWPX  equ 162
MAXCAMX equ MAPWPX-128
BANKA   equ 1
BANKB   equ 3

bank_a: ld a,BANKA
        out ($37),a
        ret
bank_b: ld a,BANKB
        out ($37),a
        ret

; ---------------------------------------------------------------------
; build_level: A = maze index. Unpacks the maze into the grid (tile id*4),
; finds the house, start, energisers, teleporters, item spots, tunnels,
; decals, builds the tile pages for the style.
; ---------------------------------------------------------------------
build_level:
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,mazetab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (mazename),hl
        ex de,hl
        ld a,(hl)
        inc hl
        ld (maph),a
        ld b,a
        add a,a
        add a,a
        add a,b                 ; *5
        ld (maphpx),a
        sub VPROWS
        ld (maxcamy),a
        ld a,(hl)
        inc hl
        ld (mstyle),a
        push hl
        ; guard rows (walls) above and below, guard column 27
        ld hl,GRIDTOP
        ld de,GRIDTOP+1
        ld bc,GSTRIDE*(MAXH+2)-1
        ld (hl),$FF
        ldir
        pop hl
        ; ---- pass 1: unpack 4-bit half rows, mirror, walls -> $80
        ld de,GRID
        ld a,(maph)
        ld c,a
.p1row: push bc
        push de
        ld b,7
        ld ix,halfbuf
.p1b:   ld a,(hl)
        inc hl
        ld c,a
        rrca
        rrca
        rrca
        rrca
        and 15
        ld (ix+0),a
        ld a,c
        and 15
        ld (ix+1),a
        inc ix
        inc ix
        djnz .p1b
        pop de
        push hl
        ; left half + centre
        ld ix,halfbuf
        ld b,14
        push de
.p1l:   ld a,(ix+0)
        call enc_code
        ld (de),a
        inc de
        inc ix
        djnz .p1l
        ; right half mirrored (cols 14..26 = half 12..0)
        ld ix,halfbuf+12
        ld b,13
.p1r:   ld a,(ix+0)
        call enc_code
        ld (de),a
        inc de
        dec ix
        djnz .p1r
        pop de
        ld hl,GSTRIDE
        add hl,de
        ex de,hl
        pop hl
        pop bc
        dec c
        jr nz,.p1row
        ; HL -> decal list
        ld (decalsrc),hl
        ; ---- pass 2: walls -> tile ids from the 8 neighbours
        ld a,(mstyle)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,styletab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (styleids),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (styletiles),de
        ld ix,GRID
        ld a,(maph)
        ld c,0                  ; cy
.p2row: push af
        ld b,MAPW
.p2c:
        ld a,(ix+0)
        cp $FF
        jr nz,.p2n
        push bc
        ; mask: bit0 n,1 s,2 w,3 e,4 nw,5 ne,6 sw,7 se (built from se down to n)
        ; a neighbour is a wall if it holds 10 or more ($FF or a wall id*4)
        ld e,0
        ld a,(ix+GSTRIDE+1)
        cp 10
        ccf
        rl e
        ld a,(ix+GSTRIDE-1)
        cp 10
        ccf
        rl e
        ld a,(ix-GSTRIDE+1)
        cp 10
        ccf
        rl e
        ld a,(ix-GSTRIDE-1)
        cp 10
        ccf
        rl e
        ld a,(ix+1)
        cp 10
        ccf
        rl e
        ld a,(ix-1)
        cp 10
        ccf
        rl e
        ld a,(ix+GSTRIDE)
        cp 10
        ccf
        rl e
        ld a,(ix-GSTRIDE)
        cp 10
        ccf
        rl e
        ld d,0
        ld hl,shapetab
        add hl,de
        ld a,(hl)
        add a,a
        ld e,a
        ld a,c
        and 1
        add a,e
        ld e,a
        ld hl,(styleids)
        add hl,de
        ld a,(hl)
        ld (ix+0),a
        pop bc
.p2n:   inc ix
        djnz .p2c
        inc ix                  ; skip guard column
        inc c
        pop af
        dec a
        jr nz,.p2row
        ; ---- pass 3: clear wall marks, non-wall codes -> ids, lists
        xor a
        ld (nener),a
        ld (ntele),a
        ld (nspots),a
        ld hl,0
        ld (pellets),hl
        ld hl,GRID
        ld c,0
.p3row: ld b,0
.p3c:   ld a,(hl)
        cp 10
        jp nc,.p3n              ; wall id
        push hl
        push bc
        call code_to_id         ; A code, B cx, C cy -> A = id*4 (records lists)
        pop bc
        pop hl
        ld (hl),a
.p3n:   inc hl
        inc b
        ld a,b
        cp MAPW
        jr nz,.p3c
        inc hl
        inc c
        ld a,(maph)
        cp c
        jr nz,.p3row
        ld hl,(pellets)
        ld (pellets_total),hl
        ; tunnel rows: a row is a tunnel if column 0 is open
        ld hl,GRID
        ld de,tunrow
        ld a,(maph)
        ld b,a
.tr:    ld a,(hl)
        cp T_TUNNEL*4
        ld a,0
        jr nz,.tr1
        inc a
.tr1:   ld (de),a
        inc de
        push de
        ld de,GSTRIDE
        add hl,de
        pop de
        djnz .tr
        ; ---- decals
        ld hl,(decalsrc)
        ld a,(hl)
        inc hl
        ld (ndecals),a
        or a
        jr z,.nodec
        ld b,a
        ld ix,decals
.dl:    ld a,(hl)
        ld (ix+D_X),a
        inc hl
        ld a,(hl)
        ld (ix+D_Y),a
        inc hl
        ld a,(hl)
        inc hl
        ld (ix+D_KIND),a
        add a,a
        add a,a                 ; kind*4 tiles
        add a,T_EYES0
        add a,a
        add a,a                 ; id*4
        ld (ix+D_BASE),a
        ld (ix+D_FRAME),0
        push hl
        push bc
        call random
        and 63
        add a,20
        ld (ix+D_TIM),a
        ld b,(ix+D_X)
        ld c,(ix+D_Y)
        call cell_addr
        ld a,(ix+D_BASE)
        ld (hl),a
        pop bc
        pop hl
        ld de,DSIZE
        add ix,de
        djnz .dl
.nodec: xor a
        ld (decalidx),a
        ; ---- tile pages
        jp build_tpages

; pass-1 encode: wall code 3 -> $FF, everything else keeps its code (0..9)
enc_code:
        cp 3
        ret nz
        ld a,$FF
        ret

; code_to_id: A = code, B = cx, C = cy -> A = tile id * 4
code_to_id:
        or a
        ret z                   ; empty (id 0)
        cp 1
        jr nz,.n1
.pel:   ld hl,(pellets)
        inc hl
        ld (pellets),hl
        ld a,T_PELLET*4
        ret
.n1:    cp 2
        jr nz,.n2
        ld hl,(pellets)
        inc hl
        ld (pellets),hl
        ld a,(nener)
        cp 24
        jr nc,.e1
        ld e,a
        inc a
        ld (nener),a
        ld d,0
        ld hl,energ_list
        add hl,de
        add hl,de
        ld (hl),b
        inc hl
        ld (hl),c
.e1:    ld a,T_ENERG0*4
        ret
.n2:    cp 4
        jr nz,.n3
        ; door: remember the centre (the middle door cell)
        ld a,b
        cp 13
        jr nz,.d1
        ld a,c
        ld (doorcy),a
.d1:    ld a,T_DOOR*4
        ret
.n3:    cp 5
        jr nz,.n4
        ld a,T_HOUSE*4
        ret
.n4:    cp 6
        jr nz,.n5
        ld a,(ntele)
        cp 4
        jr nc,.t1
        ld e,a
        inc a
        ld (ntele),a
        ld d,0
        ld hl,tele_list
        add hl,de
        add hl,de
        ld (hl),b
        inc hl
        ld (hl),c
.t1:    ld a,T_TELE0*4
        ret
.n5:    cp 7
        jr nz,.n6
        ld a,T_TUNNEL*4
        ret
.n6:    cp 8
        jr nz,.n7
        ; item spot (has a pellet)
        ld a,(nspots)
        cp 8
        jr nc,.pel
        ld e,a
        inc a
        ld (nspots),a
        ld d,0
        ld hl,spots
        add hl,de
        add hl,de
        ld (hl),b
        inc hl
        ld (hl),c
        jp .pel
.n7:    ; 9 = player start (empty)
        ld a,b
        ld (startcx),a
        ld a,c
        ld (startcy),a
        xor a
        ret

; mod58e: A = E mod 58
mod58e: ld a,e
.l:     sub VPROWS
        jr nc,.l
        add a,VPROWS
        ret

; cell_addr: B = cx (0..26), C = cy -> HL = grid address
cell_addr:
        push de
        ld l,c
        ld h,0
        add hl,hl
        ld de,rowg
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; cy*28
        ld hl,GRID
        add hl,de
        ld e,b
        ld d,0
        add hl,de
        pop de
        ret

; build_tpages: TPAGE + j*256 + id*4 = L0,L1,R0,R1 for tile row j
build_tpages:
        ld hl,(styletiles)
        ld b,(hl)
        inc hl
        ld e,0                  ; id*4
.t:     push bc
        ld d,TPAGE>>8
        ld b,5
.r:     push bc
        ld a,(hl)               ; b0 = bits 11..4
        inc hl
        ld c,(hl)               ; b1 = bits 3..0 << 4
        inc hl
        push de
        ld (de),a               ; L0
        inc e
        ld b,a
        ld a,c
        ld (de),a               ; L1
        inc e
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld (de),a               ; R0 = b0 >> 4
        inc e
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and $0F
        or b
        ld (de),a               ; R1 = b0 << 4 | b1 >> 4
        pop de
        inc d
        pop bc
        djnz .r
        ld a,e
        add a,4
        ld e,a
        pop bc
        djnz .t
        ret

; ---------------------------------------------------------------------
; gen_row: A = map pixel row R. Renders it into ring slot R mod 58, all phases.
; ---------------------------------------------------------------------
gen_row:
        push af
        ld e,a
        ld d,0
        call mod58e
        add a,a
        ld l,a
        ld h,0
        ld bc,ringrow
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (grow_dst),hl
        pop af
        ld e,a
        ld d,0
        ld hl,div5
        add hl,de
        ld c,(hl)               ; cy
        ld a,c
        add a,a
        add a,a
        add a,c
        ld b,a
        ld a,e
        sub b                   ; row in the cell
        add a,TPAGE>>8
        ld (grow_pg),a
        ld b,0
        call cell_addr          ; HL = grid row start
        ld bc,(grow_dst)
        ld a,(grow_pg)
        ld d,a
        ld a,13
        call gen_pairs
        ; last cell (26): left format
        ld e,(hl)
        ld a,(de)
        ld (bc),a
        inc bc
        inc e
        ld a,(de)
        ld (bc),a
        ld ix,(grow_dst)
        ld b,40
        jp gen_phases

; gen_pairs: A = pairs, HL = grid ptr, BC = dest, D = tile page.
gen_pairs:
        ld ixh,a
.p:     ld e,(hl)
        inc hl
        ld a,(de)
        ld (bc),a
        inc bc
        inc e
        ld a,(de)
        ld ixl,a
        ld a,(hl)
        inc hl
        or 2
        ld e,a
        ld a,(de)
        or ixl
        ld (bc),a
        inc bc
        inc e
        ld a,(de)
        ld (bc),a
        inc bc
        dec ixh
        jr nz,.p
        ret

; gen_phases: IX = phase-0 byte j, B = count. phase p byte j = (b[j]<<2p)|(b[j+1]>>(8-2p))
gen_phases:
        ld d,(ix+0)
.l:     ld e,(ix+1)
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        ld (ix+PSTRIDE),h
        add hl,hl
        add hl,hl
        ld (ix+PSTRIDE*2),h
        add hl,hl
        add hl,hl
        ld (ix+PSTRIDE*3),h
        ld d,e
        inc ix
        djnz .l
        ret

; fill the whole ring for the current camy (slow: about 6 frames)
fill_ring:
        ld a,(camy)
        ld b,VPROWS
.l:     push af
        push bc
        call gen_row
        pop bc
        pop af
        inc a
        djnz .l
        ret

; ---------------------------------------------------------------------
; regen_cell: B = cx, C = cy (grid already changed). Re-renders the cell's
; bytes in every ring row it covers and marks it dirty on screen.
; ---------------------------------------------------------------------
regen_cell:
        xor a
        ld e,5
; regen_rows: B = cx, C = cy, A = first pixel row in the cell, E = rows
regen_rows:
        ld (rc_j),a
        ld d,a
        ld a,e
        ld (rc_cnt),a
        ld a,b
        ld (rc_cx),a
        ld a,c
        add a,a
        add a,a
        add a,c
        add a,d
        ld (rc_r),a             ; first pixel row
        ld a,b
        and $FE
        ld b,a
        call cell_addr          ; HL = pair start
        ld (rc_grid),hl
        ld a,(rc_cnt)
.row:   push af
        ld a,(camy)
        ld e,a
        ld a,(rc_r)
        sub e
        cp VPROWS
        jr nc,.skip
        ld a,(rc_r)
        ld e,a
        ld d,0
        call mod58e
        add a,a
        ld l,a
        ld h,0
        ld de,ringrow
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; ring row
        ld a,(rc_cx)
        srl a                   ; pair k
        ld e,a
        add a,a
        add a,e                 ; 3k
        ld e,a
        ld d,0
        add hl,de
        push hl                 ; phase-0 byte 3k
        ld b,h
        ld c,l
        ld a,(rc_j)
        add a,TPAGE>>8
        ld d,a
        ld hl,(rc_grid)
        ld a,(rc_cx)
        cp 26
        jr z,.last
        ld a,1
        call gen_pairs
        jr .ph
.last:  ld e,(hl)
        ld a,(de)
        ld (bc),a
        inc bc
        inc e
        ld a,(de)
        ld (bc),a
.ph:    pop ix
        dec ix                  ; bytes 3k-1 .. 3k+2
        ld b,4
        ld a,(rc_cx)
        cp 2
        jr nc,.p1
        inc ix                  ; k = 0: start at byte 0
        dec b
.p1:    cp 26
        jr nz,.p2
        dec b                   ; last pair: up to byte 39
.p2:    call gen_phases
.skip:  ld hl,rc_r
        inc (hl)
        ld hl,rc_j
        inc (hl)
        pop af
        dec a
        jr nz,.row
        ; dirty rect on screen?
        ld a,(rc_cx)
        ld b,a
        add a,a
        add a,b
        add a,a                 ; px = cx*6
        ld b,a
        ld a,(rc_j)             ; rows done -> back to the cell's top row
        ld c,a
        ld a,(rc_r)
        sub c
        ld c,a
        ; fall through
; mark_dirty: B = map px x, C = map py of a 6x5 cell -> dirty list (restored next frame)
mark_dirty:
        ld a,(panflag)
        or a
        ret nz                  ; full redraw anyway
        ld a,(camy)
        ld e,a
        ld a,c
        sub e                   ; screen row - VPTOP
        jr nc,.y1
        cp -4
        ret c
        xor a                   ; partly above: clip
        jr .y2
.y1:    cp VPROWS
        ret nc
.y2:    add a,VPTOP
        ld c,a
        ld a,(camx)
        ld e,a
        ld a,b
        sub e
        jr nc,.x1
        cp -5
        ret c
        xor a
        jr .x2
.x1:    cp 128
        ret nc
.x2:    srl a
        srl a
        ld d,a                  ; col
        ld hl,(dirtyp)
        ld a,l
        cp low (dirtylist+4*NDIRTY)
        ret z
        push hl
        ld e,c
        call scraddr
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ; width: 3 bytes (2 when at the right edge)
        ld a,e
        and 31
        cp 30
        ld a,3
        jr c,.w
        ld a,e
        and 31
        cpl
        add a,33                ; 32-col
.w:     ld (hl),a
        inc hl
        ; height: 5 rows, clipped at the bottom
        ld a,c
        sub 59
        ld a,5
        jr c,.h
        ld a,64
        sub c
.h:     ld (hl),a
        inc hl
        ld (dirtyp),hl
        ld (hl),0
        inc hl
        ld (hl),0
        ret

; ---------------------------------------------------------------------
; camera
; ---------------------------------------------------------------------
; set_camera_on_player: centre the camera on the player (no limits)
cam_centre:
        ld a,(PLAYER+A_X)
        sub 61
        jr nc,.x1
        xor a
.x1:    cp MAXCAMX+1
        jr c,.x2
        ld a,MAXCAMX
.x2:    ld (camx),a
        ld a,(PLAYER+A_Y)
        sub 27
        jr nc,.y1
        xor a
.y1:    ld b,a
        ld a,(maxcamy)
        cp b
        jr nc,.y2
        ld b,a
.y2:    ld a,b
        ld (camy),a
        jp build_srctab

; target camera from the dead zone -> D = target x, E = target y
cam_target:
        ld a,(camx)
        ld d,a
        ld a,(PLAYER+A_X)
        add a,3
        sub d                   ; screen x of the hero's centre
        cp 46
        jr nc,.x1
        ld a,(PLAYER+A_X)
        add a,3
        sub 46
        jr nc,.xs
        xor a
        jr .xs
.x1:    cp 83
        jr c,.xd
        ld a,(PLAYER+A_X)
        add a,3
        sub 82
        jr nc,.xs
        xor a
.xs:    cp MAXCAMX+1
        jr c,.xs2
        ld a,MAXCAMX
.xs2:   ld d,a
.xd:    ; vertical
        ld a,(camy)
        ld e,a
        ld a,(PLAYER+A_Y)
        add a,2
        sub e
        cp 20
        jr nc,.y1
        ld a,(PLAYER+A_Y)
        add a,2
        sub 20
        jr nc,.ys
        xor a
        jr .ys
.y1:    cp 38
        ret c
        ld a,(PLAYER+A_Y)
        add a,2
        sub 38
        jr nc,.ys
        xor a
.ys:    ld e,a
        ld a,(maxcamy)
        cp e
        ret nc
        ld e,a
        ret

; update_camera: follow the hero (x up to 8px/frame, y 1 row/frame)
update_camera:
        call cam_target
        ld c,0                  ; changed flag
        ld a,(camx)
        cp d
        jr z,.yy
        ld c,1
        jr c,.xr
        sub d                   ; moving left
        cp 9
        jr c,.xset
        ld a,(camx)
        sub 8
        ld d,a
        jr .xset
.xr:    ld a,d
        ld hl,camx
        sub (hl)
        cp 9
        jr c,.xset
        ld a,(camx)
        add a,8
        ld d,a
.xset:  ld a,d
        ld (camx),a
.yy:    ld a,(camy)
        cp e
        jr z,.done
        ld c,1
        jr c,.down
        ; up one row: new map row camy-1
        dec a
        ld (camy),a
        call gen_row
        jr .done
.down:  inc a
        ld (camy),a
        add a,VPROWS-1
        call gen_row
.done:  ld a,c
        or a
        ret z
        ; fall through
build_srctab:
        ld a,1
        ld (panflag),a
        ; source for viewport row 57 = ringrow[(camy+57) mod 58] + phase*42 + camx/4
        ld a,(camy)
        add a,VPROWS-1
        ld e,a
        call mod58e
        ld c,a                  ; slot of row 57
        add a,a
        ld l,a
        ld h,0
        ld de,ringrow
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(camx)
        and 3
        ld e,a
        ld d,0
        push hl
        ld hl,ph42
        add hl,de
        ld a,(camx)
        srl a
        srl a
        add a,(hl)
        pop hl
        ld e,a
        ld d,0
        add hl,de
        ; fill srctab backwards with pushes: [src, src+16] per row.
        ; Two straight runs: slots c..0, then (after wrapping) 57..c+1.
        ld (savesp),sp
        ld sp,srctab+4*VPROWS
        ld de,-RSTRIDE
        ld a,c
        inc a                   ; rows in the first run
        ld (bs_slot),a
        ld bc,16
.r1:    add hl,bc
        push hl
        sbc hl,bc               ; (carry is clear after the add)
        push hl
        add hl,de
        dec a
        jr nz,.r1
        ld a,(bs_slot)
        sub VPROWS
        jr z,.done
        neg                     ; rows in the second run
        push af
        ld bc,RSTRIDE*VPROWS
        add hl,bc
        ld bc,16
        pop af
.r2:    add hl,bc
        push hl
        sbc hl,bc
        push hl
        add hl,de
        dec a
        jr nz,.r2
.done:  ld sp,(savesp)
        ret

ph42:   db 0,PSTRIDE,PSTRIDE*2,PSTRIDE*3

; swoop: move the camera quickly to the hero (teleports, respawn); game paused
cam_swoop:
.l:     call cam_target
        ld a,d
        ld (swx),a
        ld a,e
        ld (swy),a
        ld a,(camx)
        cp d
        jr nz,.go
        ld a,(camy)
        cp e
        ret z
.go:    ; x: up to 6 px
        ld a,(swx)
        ld hl,camx
        sub (hl)
        jr z,.ydo
        jr c,.xl
        cp 7
        jr c,.xa
        ld a,6
.xa:    add a,(hl)
        ld (hl),a
        jr .ydo
.xl:    neg
        cp 7
        jr c,.xb
        ld a,6
.xb:    ld b,a
        ld a,(hl)
        sub b
        ld (hl),a
.ydo:   ; y: up to 4 rows per frame
        ld b,4
.yl:    push bc
        ld a,(swy)
        ld hl,camy
        cp (hl)
        jr z,.yd
        jr c,.yup
        inc (hl)
        ld a,(hl)
        add a,VPROWS-1
        call gen_row
        jr .yd
.yup:   dec (hl)
        ld a,(hl)
        call gen_row
.yd:    pop bc
        djnz .yl
        call build_srctab
        call build_drawlist
        call do_frame
        jr .l

; ---------------------------------------------------------------------
; generate the unrolled stack copy (viewport rows 0..28 at COPYA, 29..57 at COPYB)
; per row:  ld sp,(src) / 8 pops / ld sp,dst+16 / 8 pushes, twice (16 bytes each)
; ---------------------------------------------------------------------
gen_copycode:
        ld de,COPYA
        ld b,0
        call .part
        ld de,COPYB
        ld b,29
.part:  ld a,$ED                ; ld (savesp),sp
        ld (de),a
        inc de
        ld a,$73
        ld (de),a
        inc de
        ld hl,savesp
        call .wde
        ld c,29
.row:   push bc
        ; source pointers: srctab + b*4 (+2)
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        push bc
        ld bc,srctab
        add hl,bc
        pop bc
        ld (gc_src),hl
        call .ldsp_ind
        call .pops
        ; dest: VRAM + (VPTOP+b)*32 + 16
        ld a,b
        add a,VPTOP
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push bc
        ld bc,VRAM+16
        add hl,bc
        pop bc
        ld (gc_dst),hl
        call .ldsp_nn
        call .pushes
        ld hl,(gc_src)
        inc hl
        inc hl
        call .ldsp_ind
        call .pops
        ld hl,(gc_dst)
        push bc
        ld bc,16
        add hl,bc
        pop bc
        call .ldsp_nn
        call .pushes
        pop bc
        inc b
        dec c
        jr nz,.row
        ld a,$ED                ; ld sp,(savesp)
        ld (de),a
        inc de
        ld a,$7B
        ld (de),a
        inc de
        ld hl,savesp
        call .wde
        ld a,$C9                ; ret
        ld (de),a
        inc de
        ret
.ldsp_ind:                      ; ld sp,(HL)
        ld a,$ED
        ld (de),a
        inc de
        ld a,$7B
        ld (de),a
        inc de
        jr .wde
.ldsp_nn:                       ; ld sp,HL
        ld a,$31
        ld (de),a
        inc de
.wde:   ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ret
.pops:  ld hl,popseq
        jr .cpy10
.pushes: ld hl,pushseq
.cpy10: push bc
        ld bc,10
        ldir
        pop bc
        ret
popseq: db $F1,$C1,$D1,$E1,$08,$D9,$F1,$C1,$D1,$E1      ; pop af,bc,de,hl, ex af, exx, pop x4
pushseq: db $E5,$D5,$C5,$F5,$08,$D9,$E5,$D5,$C5,$F5     ; push hl,de,bc,af, ex af, exx, push x4

; ---------------------------------------------------------------------
; RENDER (game): called at the start of vblank
; draw list entries: id, x+8, y+16 (screen), extra.  $FE text, $FD pixel.
; ---------------------------------------------------------------------
render_game:
        ld a,(panflag)
        or a
        jr z,.static
        xor a
        ld (panflag),a
        ld hl,eraselist
        ld (elptr),hl
        call COPYA
        ld a,1
        ld (rpass),a
        call draw_list
        call COPYB
        ld a,2
        ld (rpass),a
        call draw_list
        jr .fin
.static:
        ld hl,eraselist
        call erase_ring
        ld hl,dirtylist
        call erase_ring
        ld hl,eraselist
        ld (elptr),hl
        xor a
        ld (rpass),a
        call draw_list
.fin:   ld hl,(elptr)
        ld (hl),0
        inc hl
        ld (hl),0
        ld hl,dirtylist
        ld (dirtyp),hl
        ld (hl),0
        inc hl
        ld (hl),0
        ret

; erase_ring: HL = rect list (addr, w, h ... 0,0) -> restore from the ring
erase_ring:
.e:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or a
        ret z
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        ; screen row s = (addr-VRAM)/32 - VPTOP ; col = addr & 31
        ld a,e
        and 31
        ld (er_col),a
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,hl               ; H = row (addr bits 12..5)
        ld a,h
        and 63
        sub VPTOP
        add a,a
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,srctab
        add hl,de
        pop de                  ; HL -> srctab entry, DE = vram
.row:   push bc
        push hl
        push de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(er_col)
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld c,b
        ld b,0
        ldir
        pop de
        ld hl,32
        add hl,de
        ex de,hl
        pop hl
        inc hl
        inc hl
        inc hl
        inc hl
        pop bc
        dec c
        jr nz,.row
        pop hl
        jr .e

; restore_rect_game: D col, E row (screen), B width, C height
restore_rect_game:
        call scraddr
        ld de,rr_tmp
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        ld hl,rr_tmp
        jp erase_ring

; draw_list: draws the draw list. rpass 0 = all, 1 = bottom row <= 34, 2 = the rest
draw_list:
        ld ix,drawlist
.d:     ld a,(ix+0)
        cp $FF
        ret z
        cp $FE
        jp z,.text
        cp $FD
        jp z,.pixel
        ; ---- sprite
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,shtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; base
        inc hl
        ld a,(hl)
        ld (pw_),a
        inc hl
        ld a,(hl)
        ld (h_),a
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; shiftsize
        ; band test: bottom row = y-16+h-1 (pass 1: <= 34, pass 2: the rest)
        ld a,(rpass)
        or a
        jr z,.go
        ld l,a
        ld a,(h_)
        add a,(ix+2)
        sub 17
        cp 35
        ld a,l
        jr c,.inA
        cp 1
        jp z,.next
        jr .go
.inA:   cp 2
        jp z,.next
.go:    ld a,(ix+1)
        and 3
        jr z,.s0
.s1:    ex de,hl
        add hl,bc
        ex de,hl
        dec a
        jr nz,.s1
.s0:    ; DE = data.  rows: top = y-16
        ld a,(ix+2)
        sub 16
        ld c,a                  ; top row (screen)
        ld a,(h_)
        ld b,a                  ; height
        ld a,c
        cp VPTOP
        jr nc,.ntop
        ; clip top
        ld a,VPTOP
        sub c                   ; rows to skip
        cp b
        jp nc,.next
        ld l,a
        ld a,b
        sub l
        ld b,a
        ld a,(pw_)
.sk:    push af
        add a,e
        ld e,a
        jr nc,.sk1
        inc d
.sk1:   pop af
        dec l
        jr nz,.sk
        ld c,VPTOP
.ntop:  ld a,c
        cp 64
        jp nc,.next
        add a,b
        sub 64
        jr c,.nbot
        jr z,.nbot
        ld l,a
        ld a,b
        sub l
        ld b,a
.nbot:  ld a,b
        ld (h_),a
        ; columns: col = x/4 - 2
        ld a,(ix+1)
        srl a
        srl a
        sub 2
        jr nc,.cpos
        ; clipped at the left: skip -col bytes
        neg
        ld l,a
        ld a,(pw_)
        sub l
        jp c,.next
        jp z,.next
        ld (w_),a
        ld a,l
        add a,e
        ld e,a
        jr nc,.cl1
        inc d
.cl1:   xor a
        jr .cset
.cpos:  ld l,a
        ld a,32
        sub l
        jp c,.next
        jp z,.next
        ld h,a                  ; bytes available
        ld a,(pw_)
        cp h
        jr c,.cw
        ld a,h
.cw:    ld (w_),a
        ld a,l
.cset:  ld (col_),a
        push de
        ld d,a
        ld e,c
        call scraddr
        pop de
        ; record erase
        push hl
        push de
        ex de,hl
        ld hl,(elptr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(w_)
        ld (hl),a
        inc hl
        ld a,(h_)
        ld (hl),a
        inc hl
        ld (elptr),hl
        pop de
        pop hl
        ld a,(w_)
        ld b,a
        ld a,(pw_)
        sub b
        ld (skip_),a
        ld a,(h_)
        ld (rowcnt),a
        ld b,d
        ld c,e
        ex de,hl
        ld h,MASKTAB/256
        ld a,(w_)
        cp 3
        jr z,.row3
.row:   push de
        ld a,(w_)
        ld iyl,a
.byte:  ld a,(bc)
        ld l,a
        ld a,(de)
        and (hl)
        inc h
        or (hl)
        dec h
        ld (de),a
        inc bc
        inc e
        dec iyl
        jr nz,.byte
        ld a,(skip_)
        add a,c
        ld c,a
        jr nc,.nsk
        inc b
.nsk:   pop de
        ld a,e
        add a,32
        ld e,a
        jr nc,.nc
        inc d
.nc:    ld a,(rowcnt)
        dec a
        ld (rowcnt),a
        jr nz,.row
        jp .next
.row3:  ld a,(bc)
        ld l,a
        ld a,(de)
        and (hl)
        inc h
        or (hl)
        dec h
        ld (de),a
        inc bc
        inc e
        ld a,(bc)
        ld l,a
        ld a,(de)
        and (hl)
        inc h
        or (hl)
        dec h
        ld (de),a
        inc bc
        inc e
        ld a,(bc)
        ld l,a
        ld a,(de)
        and (hl)
        inc h
        or (hl)
        dec h
        ld (de),a
        inc bc
        ld a,e
        add a,30
        ld e,a
        jr nc,.r3c
        inc d
.r3c:   ld a,(rowcnt)
        dec a
        ld (rowcnt),a
        jr nz,.row3
        jp .next
.text:  ; text popup: col=(ix+1), row=(ix+2), string index (ix+3)
        ld a,(ix+2)
        add a,4                 ; bottom row
        call .band
        jp nz,.next
        ld a,(ix+3)
        add a,a
        ld l,a
        ld h,0
        ld de,popstr
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld b,0
.tl:    ld a,(hl)
        or a
        jr z,.tld
        inc b
        inc hl
        jr .tl
.tld:   pop hl
        push bc
        push hl
        ld a,1
        ld b,2
        call set_ink
        pop hl
        pop bc
        ld d,(ix+1)
        ld e,(ix+2)
        push hl
        push de
        push bc
        call scraddr
        ex de,hl
        ld hl,(elptr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        pop bc
        ld (hl),b
        inc hl
        ld (hl),5
        inc hl
        ld (elptr),hl
        pop de
        pop hl
        xor a
        ld (textdest),a
        call print
        jp .next
.pixel: ld a,(ix+2)
        call .band
        jp nz,.next
        ld a,(ix+1)
        ld c,a
        srl a
        srl a
        ld d,a
        ld e,(ix+2)
        call scraddr
        ex de,hl
        ld hl,(elptr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),1
        inc hl
        ld (hl),1
        inc hl
        ld (elptr),hl
        ld a,(ix+3)
        add a,a
        add a,a
        ld b,a
        ld a,c
        and 3
        or b
        add a,a
        ld l,a
        ld h,0
        ld bc,pixtab
        add hl,bc
        ld b,(hl)
        inc hl
        ld c,(hl)
        ex de,hl
        ld a,(hl)
        and b
        or c
        ld (hl),a
.next:  ld de,4
        add ix,de
        jp .d
; .band: A = bottom screen row -> Z if it belongs to this pass
.band:  ld l,a
        ld a,(rpass)
        or a
        ret z                   ; single pass: everything
        ld h,a
        ld a,l
        cp 35
        ld a,h
        jr c,.bA
        cp 2                    ; lower half -> pass 2
        ret
.bA:    cp 1                    ; upper half -> pass 1
        ret

; dl_add_map: A = sprite id, B = map px x, C = map py -> draw list (if visible)
dl_add_map:
        push af
        call map_to_dl
        jr c,.off
        pop af
        jp dl_add
.off:   pop af
        ret
; map_to_dl: B,C map coords -> B = x+8, C = y+16 screen (carry if not visible)
map_to_dl:
        ld a,(camx)
        ld e,a
        ld a,b
        sub e
        jr nc,.xp
        cp -7
        ret c
        jr .xo
.xp:    cp 128
        ccf
        ret c
.xo:    add a,8
        ld b,a
        ld a,(camy)
        ld e,a
        ld a,c
        sub e
        jr nc,.yp
        cp -6
        ret c
        jr .yo
.yp:    cp VPROWS
        ccf
        ret c
.yo:    add a,VPTOP+16
        ld c,a
        or a
        ret

; ---------------------------------------------------------------------
; map animation: energisers blink, teleporters swirl, decals (eyes peek out
; of the walls and candles flicker) - only while the view is still
; ---------------------------------------------------------------------
animate_map:
        ; power pills: frame slot s (0..15) refreshes pills s and s+16
        ld a,(framecount)
        and 15
        push af
        call .pill
        pop af
        add a,16
        call .pill
        jr .ne
.pill:  ld hl,nener
        cp (hl)
        ret nc
        add a,a
        ld e,a
        ld d,0
        ld hl,energ_list
        add hl,de
        ld b,(hl)
        inc hl
        ld c,(hl)
        call cell_addr
        ld a,(hl)
        cp T_ENERG0*4
        jr z,.e0
        cp T_ENERG1*4
        ret nz                  ; eaten
.e0:    ld a,(framecount)
        and 16
        ld a,T_ENERG0*4
        jr z,.e1
        ld a,T_ENERG1*4
.e1:    cp (hl)
        ret z
        ld (hl),a
        ld a,1
        ld e,3
        jp regen_rows
.ne:    ; teleporters: one per frame on frames 12..15 of every 16
        ld a,(ntele)
        or a
        jr z,.nt
        ld c,a
        ld a,(framecount)
        and 15
        sub 12
        jr c,.nt
        cp c
        jr nc,.nt
        add a,a
        ld e,a
        ld d,0
        ld hl,tele_list
        add hl,de
        ld b,(hl)
        inc hl
        ld c,(hl)
        call cell_addr
        ld a,(framecount)
        rrca
        rrca
        rrca
        rrca
        and 3
        add a,T_TELE0
        add a,a
        add a,a
        ld (hl),a
        jp regen_cell
.nt:    ; decals (one per frame), only when the camera is still
        ld a,(panflag)
        or a
        ret nz
        ld a,(ndecals)
        or a
        ret z
        ld b,a
        ld a,(decalidx)
        inc a
        cp b
        jr c,.di
        xor a
.di:    ld (decalidx),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; *8 (DSIZE)
        ld de,decals
        add hl,de
        push hl
        pop ix
        ld a,(ix+D_TIM)
        sub b                   ; each decal is visited every ndecals frames
        jr nc,.dt
        xor a
.dt:    ld (ix+D_TIM),a
        ret nz
        ; time for the next state
        ld a,(ix+D_KIND)
        cp 2
        jr z,.candle
        ; eyes: 0 closed -> 1 slit -> 2/3 look (towards the hero) -> 1 -> 0
        ld a,(ix+D_FRAME)
        or a
        jr nz,.e2
        ld (ix+D_FRAME),1
        ld (ix+D_TIM),10
        jr .dset
.e2:    cp 1
        jr nz,.e3
        bit 0,(ix+D_FLG)
        jr nz,.eclose
        set 0,(ix+D_FLG)
        call .look
        ld (ix+D_TIM),60
        jr .dset
.eclose: res 0,(ix+D_FLG)
        ld (ix+D_FRAME),0
        call random
        and 127
        add a,90
        ld (ix+D_TIM),a
        jr .dset
.e3:    ; looking: maybe glance the other way, then shut
        call random
        and 3
        jr nz,.e4
        call .look
        ld a,(ix+D_FRAME)
        xor 1
        ld (ix+D_FRAME),a
        ld (ix+D_TIM),30
        jr .dset
.e4:    ld (ix+D_FRAME),1
        ld (ix+D_TIM),8
        jr .dset
.candle:
        call random
        and 3
        cp 3
        jr nz,.c1
        xor a
.c1:    ld (ix+D_FRAME),a
        call random
        and 15
        add a,6
        ld (ix+D_TIM),a
.dset:  ld b,(ix+D_X)
        ld c,(ix+D_Y)
        call cell_addr
        ld a,(ix+D_FRAME)
        add a,a
        add a,a
        add a,(ix+D_BASE)
        cp (hl)
        ret z
        ld (hl),a
        ld a,(ix+D_KIND)
        cp 2
        ld a,3                  ; eyes: the face row only
        ld e,1
        jp nz,regen_rows
        xor a                   ; candle: the top three rows
        ld e,3
        jp regen_rows
.look:  ; frame 2 (look left) or 3 (look right) towards the hero
        ld a,(ix+D_X)
        ld b,a
        add a,a
        add a,b
        add a,a                 ; px
        ld b,a
        ld a,(PLAYER+A_X)
        cp b
        ld a,2
        jr c,.lk
        inc a
.lk:    ld (ix+D_FRAME),a
        ret

; ---------------------------------------------------------------------
; INTERMISSION BACKDROPS: a sparse 16x16 pattern scrolling diagonally behind
; the cartoon (rows BG_TOP..BG_BOT-1). The pattern is pre-shifted into four
; pixel phases; each frame BGBUF is repainted outside vblank and VRAM during
; vblank (just before the sprites), both with stack pushes.
; ---------------------------------------------------------------------
BG_TOP  equ 12
BG_BOT  equ 52
BGPH    equ TPAGE           ; 4 phases x 16 rows x 4 bytes (scratch: TPAGE is rebuilt per level)
BGROWS  equ TPAGE+256       ; this frame's rows: 16 x (C,B,E,D)

; bg_begin: HL = 64-byte pattern, D = dx, E = dy (per frame)
bg_begin:
        ld a,d
        ld (bg_dx),a
        ld a,e
        ld (bg_dy),a
        xor a
        ld (bg_ox),a
        ld (bg_oy),a
        ld (bg_cap),a
        ld de,BGPH
        ld bc,64
        ldir
        ; phases 1..3: each is the previous rotated left by one pixel (2 bits)
        ld hl,BGPH
        ld de,BGPH+64
        ld bc,192
        ldir
        ld ix,BGPH+64
        ld c,3
.ph:    ld b,16
.row:   push bc
        ld b,2
.bit:   ld a,(ix+0)
        rlca
        rl (ix+3)
        rl (ix+2)
        rl (ix+1)
        rl (ix+0)
        djnz .bit
        ; the next phase starts from this one
        pop bc
        push bc
        ld a,c
        cp 1
        jr z,.nocp
        ld a,(ix+0)
        ld (ix+64),a
        ld a,(ix+1)
        ld (ix+65),a
        ld a,(ix+2)
        ld (ix+66),a
        ld a,(ix+3)
        ld (ix+67),a
.nocp:  pop bc
        ld de,4
        add ix,de
        djnz .row
        dec c
        jr nz,.ph
        ld a,1
        ld (bghook),a
        ret

; bg_step (outside vblank): advance, build the row table, repaint BGBUF
bg_step:
        ld a,(bg_dx)
        ld hl,bg_ox
        add a,(hl)
        ld (hl),a
        ld a,(bg_dy)
        ld hl,bg_oy
        add a,(hl)
        ld (hl),a
        ; row table: for pattern row k, the 4 bytes rotated by (ox>>2)&3, phase ox&3
        ld a,(bg_ox)
        and 3
        rrca
        rrca                    ; phase*64
        ld l,a
        ld h,BGPH>>8
        ld a,(bg_ox)
        rrca
        rrca
        and 3
        ld c,a                  ; byte rotation
        ld de,BGROWS
        ld b,16
.r:     push bc
        ld b,4
.q:     ld a,c
        and 3
        push hl
        add a,l
        ld l,a
        ld a,(hl)
        pop hl
        ld (de),a
        inc de
        inc c
        djnz .q
        ld a,l
        add a,4
        ld l,a
        pop bc
        djnz .r
        ret

; bg_vram (vblank)
bg_vram:
        ld hl,VRAM
; bg_paint:
        ld (savesp),sp
        ld de,(BG_TOP+1)*32
        add hl,de               ; end of the first row
        ld a,(bg_oy)
        add a,BG_TOP
        and 15
        add a,a
        add a,a
        ld ixl,a
        ld ixh,BGROWS>>8
        ld a,BG_TOP
.row:   ld (bg_r),a
        ld b,a
        ld a,(bg_cap)
        or a
        jr z,.nc
        ld c,a
        ld a,b
        sub c
        cp 5
        jr c,.skip              ; leave the caption alone (no stack use: SP is in VRAM)
.nc:    ld c,(ix+0)
        ld b,(ix+1)
        ld e,(ix+2)
        ld d,(ix+3)
        ld sp,hl
        push de
        push bc
        push de
        push bc
        push de
        push bc
        push de
        push bc
        push de
        push bc
        push de
        push bc
        push de
        push bc
        push de
        push bc
.skip:  ld de,32
        add hl,de
        ld a,ixl
        add a,4
        and 63
        ld ixl,a
        ld a,(bg_r)
        inc a
        cp BG_BOT
        jr nz,.row
        ld sp,(savesp)
        ret
