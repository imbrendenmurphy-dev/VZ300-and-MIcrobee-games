; ==========================================================================
; sprite.asm - creatures, items, shots and the zapper, drawn into the
;              character-cell picture
;   VIBED BY BPM 2026
;
; Every sprite is pre-shrunk to 16 sizes (prescale.asm), each stored as
; byte columns of (NOT mask, data) pairs, once as is and once moved 4 dots
; right, in its own RAM block.  Drawing one:
;
;   1. project: depth z and screen position from the player's view; the
;      height picks the size, the rows are stretched to the exact height.
;   2. cells:   for every character cell it covers where it is nearer than
;      the wall in that half column, the cell's glyph is copied from the
;      tileset (RAM block 4) into a private glyph of this page's pool, and
;      the cell is pointed at it.  The cell's old code, bank and colour go
;      on the page's restore list.
;   3. compose: the sprite's rows are laid over those private glyphs.
;   4. upload:  the private glyphs go to PCG RAM.
;
; Before the page is drawn again, its restore list puts the cells back.
; Pools: page 0 uses bank 13 and the first half of bank 15, page 1 bank 14
; and the second half of 15 (192 glyphs each).
; ==========================================================================

POOLN   equ 192

; VIS entry
V_Z     equ 0           ; depth, 1/8 cell (sort key)
V_ENT   equ 1           ; entity number (0FFh = the zapper)
V_IMG   equ 2
V_S     equ 3           ; size
V_DX    equ 4           ; centre, dots from the left of the view (signed word)
V_YT    equ 6           ; top scanline (signed word)
V_YB    equ 8           ; bottom scanline, exclusive (signed word)
V_H     equ 10          ; height in scanlines
V_INK   equ 11
V_W     equ 12          ; width in dots
VSIZE   equ 16
NVIS    equ 16

; IMGDIR entry (per image and size, built by prescale)
D_BLK   equ 0
D_B0    equ 1           ; base of the unshifted columns
D_BW    equ 3           ; bytes (columns) unshifted; shifted has one more
D_B1    equ 4           ; base of the shifted columns
D_CS    equ 6           ; column size shift: 6 = 64 bytes, 7 = 128

; --------------------------------------------------------------------------
; mul8: HL = A * E (unsigned), from quarter squares (BLK_TAB mapped)
;       keeps IX, IY
; --------------------------------------------------------------------------
mul8:   ld d,a
        add a,e
        ld l,a
        ld h,0
        jr nc,.s
        inc h
.s      add hl,hl
        ld bc,QSQ
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = (a+e)^2/4
        ld a,d
        sub e
        jr nc,.p
        neg
.p      ld l,a
        ld h,0
        add hl,hl
        ld de,QSQ
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = (a-e)^2/4
        ld h,b
        ld l,c
        or a
        sbc hl,de
        ret

; mulsv: HL = signed 8.8 value, A = magnitude (/256), C bit 0 = negate
;        -> HL = signed (value * magnitude / 256)
mulsv:  ld b,c
        bit 7,h
        jr z,.pos
        inc b
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
.pos    ld (msv_m),a
        push bc
        push hl
        ld e,l                  ; low byte part: (L * m) >> 8
        call mul8
        ld a,h
        ld (msv_lo),a
        pop hl
        ld a,(msv_m)
        ld e,h                  ; high byte part: H * m
        call mul8
        ld a,(msv_lo)
        ld e,a
        ld d,0
        add hl,de
        pop bc
        bit 0,b
        ret z
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ret

; --------------------------------------------------------------------------
; proj_setup: the player's view for this frame (BLK_TAB mapped)
;   cmag/smag = |cos|,|sin| of the facing (/256); csgn/ssgn = 1 if negative
; --------------------------------------------------------------------------
proj_setup:
        ld hl,(pa)
        ld de,COSM
        add hl,de
        ld a,(hl)
        ld (cmag),a
        ld hl,(pa)
        ld de,-512
        add hl,de
        ld a,h
        and 7
        ld h,a
        ld de,COSM
        add hl,de
        ld a,(hl)
        ld (smag),a
        xor a                   ; cos < 0 for 513..1535
        ld (csgn),a
        ld hl,(pa)
        ld de,-513
        add hl,de
        jr nc,.c
        ld de,-1023
        add hl,de
        jr c,.c
        ld a,1
        ld (csgn),a
.c      xor a                   ; sin < 0 for 1025..2047
        ld hl,(pa)
        ld de,-1025
        add hl,de
        jr nc,.s
        inc a
.s      ld (ssgn),a
        ret

; --------------------------------------------------------------------------
; proj_all: every live entity that can be seen goes into VIS, then the
;           zapper; then sorted far to near into VORD
; --------------------------------------------------------------------------
proj_all:
        call proj_setup
        xor a
        ld (nvis),a
        ld iy,VIS
        ld a,(M_st1+1)          ; this frame's stamp
        ld (.st+1),a
        ld hl,ENT
        ld b,NENT
.e      ld a,(hl)
        or a
        jr z,.nx
        push hl                 ; only things in cells the rays crossed
        inc hl
        inc hl
        ld c,(hl)               ; x cell
        inc hl
        inc hl
        ld a,(hl)               ; y cell
        rrca
        rrca
        rrca
        ld e,a
        and 3
        add a,high(STAMP)
        ld d,a
        ld a,e
        and 0E0h
        or c
        ld e,a
        ld a,(de)
.st     cp 0
        pop hl
        jr nz,.nx
        push hl
        push bc
        push hl
        pop ix
        ld a,NENT
        sub b
        ld (cur_ent),a
        call proj_one
        pop bc
        pop hl
.nx     ld a,b
        and 7
        jr nz,.nv
        push hl
        call vbpoll
        pop hl
.nv     ld de,ESIZE
        add hl,de
        djnz .e
.sort   ld a,(nvis)             ; bubble sort of the order, far to near
        or a
        ret z
        ld b,a
        ld hl,VORD
        xor a
.i      ld (hl),a
        inc hl
        inc a
        djnz .i
        ld a,(nvis)
        dec a
        ret z
        ld c,a                  ; passes
.p      ld hl,VORD
        ld b,c
.q      ld a,(hl)
        call vz
        ld d,a
        inc hl
        ld a,(hl)
        call vz
        cp d
        jr c,.n                 ; next is nearer: in order
        jr z,.n
        ld a,(hl)               ; swap
        dec hl
        ld e,(hl)
        ld (hl),a
        inc hl
        ld (hl),e
.n      djnz .q
        dec c
        jr nz,.p
        ret
; vz: A = VIS index -> A = its depth (keeps HL, BC, D)
vz:     push hl
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,high(VIS)
        ld a,(hl)
        pop hl
        ret

; --------------------------------------------------------------------------
; proj_one: IX = entity, IY = next VIS entry.  Adds it if it can be seen.
; --------------------------------------------------------------------------
proj_one:
        ld a,(nvis)
        cp NVIS-1               ; keep a place for the zapper
        ret nc
        ld a,(ix+E_ST)
        cp ST_GONE
        ret z
        ld a,(ix+E_Y+1)         ; only where this frame's rays went
        rrca
        rrca
        rrca
        ld l,a
        and 3
        add a,high(STAMP)
        ld h,a
        ld a,l
        and 0E0h
        or (ix+E_X+1)
        ld l,a
        ld a,(M_st1+1)
        cp (hl)
        ret nz
        ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        ld de,(px+1)
        or a
        sbc hl,de
        ld (pdx),hl
        ld a,h                  ; further than 15 cells either way: skip
        add a,15
        cp 30
        ret nc
        ld l,(ix+E_Y)
        ld h,(ix+E_Y+1)
        ld de,(py+1)
        or a
        sbc hl,de
        ld (pdy),hl
        ld a,h
        add a,15
        cp 30
        ret nc
        ; z = dx cos + dy sin
        ld hl,(pdx)
        ld a,(csgn)
        ld c,a
        ld a,(cmag)
        call mulsv
        ld (pz),hl
        ld hl,(pdy)
        ld a,(ssgn)
        ld c,a
        ld a,(smag)
        call mulsv
        ld de,(pz)
        add hl,de
        ld (pz),hl
        bit 7,h
        ret nz                  ; behind
        ld a,h
        or a
        jr nz,.zf
        ld a,l
        cp 66h                  ; nearer than 0.4 cells: not drawn
        ret c
.zf     ld a,h
        cp 15
        ret nc
        ; x = dy cos - dx sin
        ld hl,(pdy)
        ld a,(csgn)
        ld c,a
        ld a,(cmag)
        call mulsv
        ld (pxr),hl
        ld hl,(pdx)
        ld a,(ssgn)
        xor 1
        ld c,a
        ld a,(smag)
        call mulsv
        ld de,(pxr)
        add hl,de
        ld (pxr),hl
        ; yb = half wall height at this depth
        ld hl,(pz)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l                    ; z in 1/32 cell, 0..479
        ld de,YBT
        add hl,de
        ld a,(hl)
        ld (pyb),a
        ; centre: 160 + 1.5 * (x * yb)
        ld hl,(pxr)
        ld c,0
        call mulsv
        ld d,h
        ld e,l
        sra d
        rr e
        add hl,de
        ld de,160
        add hl,de
        ld (iy+V_DX),l
        ld (iy+V_DX+1),h
        ; height = yb * F / 64, at most HCAP (very near sprites cost a lot)
        ld a,(pyb)
        ld e,(ix+E_F)
        call mul8
        ld a,h
        cp 1Fh
        ld a,HCAP
        jr nc,.hd
        add hl,hl
        add hl,hl
        ld a,h
        cp HCAP
        jr c,.hd
        ld a,HCAP
.hd     cp 4
        ret c                   ; too small to draw
        ld (iy+V_H),a
        ; size and width
        srl a
        ld e,a
        ld d,0
        ld hl,HTOS
        add hl,de
        ld a,(hl)
        ld (iy+V_S),a
        ld c,a
        ld a,(ix+E_ST)
        cp ST_DIE
        jr nz,.alive
        ld a,(ix+E_TM)          ; dying: flashes, then a puff of smoke
        cp PUFFT
        jr nc,.alive
        rrca
        rrca
        and 1
        add a,IMG_PUFF_A
        jr .f0
.alive  ld a,(ix+E_IMG)
        bit 3,(ix+E_AN)         ; second frame every 8 fields
        jr z,.f0
        bit 3,(ix+E_FL)         ; F_ANIM
        jr z,.f0
        inc a
.f0     ld (iy+V_IMG),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or c
        ld l,a
        ld a,h
        add a,high(WTAB)
        ld h,a
        ld l,a
        ld h,high(WTAB)
        ld a,(hl)
        ld (iy+V_W),a
        ; on screen at all?  |centre - 160| < 160 + w/2
        srl a
        add a,160
        ld b,a
        ld l,(iy+V_DX)
        ld h,(iy+V_DX+1)
        ld de,-160
        add hl,de
        bit 7,h
        jr z,.ap
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
.ap     ld a,h
        or a
        ret nz
        ld a,l
        cp b
        ret nc
        ; bottom = 110 + yb - lift; top = bottom - h
        ld a,(ix+E_FL)
        and F_FLY
        ld b,0
        jr z,.nl
        ld a,(pyb)              ; flyers float at 3/4 of the wall
        srl a
        ld b,a
        srl a
        add a,b
        ld b,a
.nl     ld a,(pyb)
        ld l,a
        ld h,0
        ld de,110
        add hl,de
        ld e,b
        ld d,0
        or a
        sbc hl,de
        ld (iy+V_YB),l
        ld (iy+V_YB+1),h
        ld e,(iy+V_H)
        or a
        sbc hl,de
        ld (iy+V_YT),l
        ld (iy+V_YT+1),h
        ; depth key, ink, owner
        ld hl,(pz)
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h                  ; z / 32 = 1/8 cells
        ld (iy+V_Z),a
        ld a,(ix+E_INK)
        ld b,a
        ld a,(ix+E_ST)
        cp ST_PAIN
        jr z,.iw
        cp ST_DIE
        jr nz,.ik
        ld a,(ix+E_TM)          ; dying: flicker white
        cp PUFFT
        jr c,.ik
        and 2
        jr z,.ik
.iw     ld b,CWHITE             ; hurt: flash white
.ik     ld a,(mono)
        or a
        ld a,b
        jr z,.im
        ld a,CWHITE
.im     ld (iy+V_INK),a
        ld a,(cur_ent)
        ld (iy+V_ENT),a
        ld bc,VSIZE
        add iy,bc
        ld hl,nvis
        inc (hl)
        ret

; --------------------------------------------------------------------------
; restore_page: put back every cell the sprites took on the hidden page
; --------------------------------------------------------------------------
restore_page:
        call rlist_ptr          ; HL = list, A = count
        or a
        ret z
        ld (.n+1),a
        push hl
        ld b,a
        ld de,5
.c      ld e,(hl)               ; codes
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (de),a
        inc hl
        inc hl
        inc hl
        djnz .c
        pop hl
        push hl
        ld a,X1C_ATTR
        out (PORT_1C),a
.n      ld b,0
        push bc
.a      ld e,(hl)               ; banks
        inc hl
        ld d,(hl)
        inc hl
        inc hl
        ld a,(hl)
        ld (de),a
        inc hl
        inc hl
        djnz .a
        ld a,X1C
        out (PORT_1C),a
        pop bc
        pop hl
        ld a,40h
        out (PORT_08),a
.k      ld e,(hl)               ; colours
        inc hl
        ld a,(hl)
        add a,8
        ld d,a
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        ld (de),a
        inc hl
        djnz .k
        xor a
        out (PORT_08),a
        call rlist_ptr
        dec hl                  ; the count sits just before the list
        ld (hl),0
        ret

; rlist_ptr: HL = this page's restore list, A = its length
rlist_ptr:
        ld a,(page)
        or a
        ld hl,RLIST0
        jr z,.p
        ld hl,RLIST1
.p      ld a,(hl)
        inc hl
        ret

; --------------------------------------------------------------------------
; draw_sprites: VIS in VORD order
; --------------------------------------------------------------------------
draw_sprites:
        call rlist_ptr          ; HL = list, A = count (0 after restore_page)
        dec hl
        ld (rl_head),hl
        inc hl
        ld e,a
        ld d,0
        add hl,de
        add hl,de
        add hl,de
        add hl,de
        add hl,de
        ld (rl_ptr),hl
        xor a
        ld (nslot),a
        ld a,(page)             ; pool banks for this page
        add a,13
        ld (poolbk),a
        ld a,(page)
        or a
        ld a,0
        jr z,.p
        ld a,64
.p      ld (pool15),a
        ld a,(nvis)
        or a
        ret z
        ld b,a
        ld hl,VORD
.l      push bc
        push hl
        ld a,(hl)
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,high(VIS)
        push hl
        pop iy
        call draw_one
        pop hl
        pop bc
        inc hl
        djnz .l
        jp tabblk

; --------------------------------------------------------------------------
; draw_one: IY = VIS entry
; --------------------------------------------------------------------------
draw_one:
        ; directory entry: SPRDIR + (img * 16 + s) * 8, in block 4
        ld a,(iy+V_IMG)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(iy+V_S)
        or l
        ld l,a
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,SPRDIR
        add hl,de
        ld a,BLK_PCG
        call setblk
        ld de,DCOPY
        ld bc,8
        ldir
        call tabblk
        ld ix,DCOPY             ; IX = directory entry
        ; left edge in half columns: (centre - w/2) >> 2
        ld l,(iy+V_DX)
        ld h,(iy+V_DX+1)
        ld a,(iy+V_W)
        srl a
        ld e,a
        ld d,0
        or a
        sbc hl,de
        sra h
        rr l
        sra h
        rr l                    ; HL = left half column (signed)
        ld a,l
        and 1
        ld (dshift),a
        sra h
        rr l
        ld a,l
        ld (dc0),a              ; first cell column (signed byte)
        ld a,(ix+D_BW)
        ld b,a
        ld l,(ix+D_B0)
        ld h,(ix+D_B0+1)
        ld a,(dshift)
        or a
        jr z,.s0
        inc b
        ld l,(ix+D_B1)
        ld h,(ix+D_B1+1)
.s0     ld a,b
        ld (dbw),a
        ld (dbase),hl
        ld a,(ix+D_CS)
        ld (dcs),a
        ld a,(ix+D_BLK)
        ld (dblk),a
        ; visible rows y0..y1
        ld l,(iy+V_YT)
        ld h,(iy+V_YT+1)
        ld (dyt),hl
        bit 7,h
        jr z,.t
        ld hl,0
.t      ld (dy0),hl
        ld l,(iy+V_YB)
        ld h,(iy+V_YB+1)
        ld de,220
        or a
        sbc hl,de
        add hl,de
        jr c,.b
        ex de,hl
.b      ld (dy1),hl
        ld de,(dy0)
        or a
        sbc hl,de
        ret c
        ret z
        call rowmap
        ; ---- every cell it covers where it is nearer than the wall: make
        ;      the sprite's lines for it; if any of the sprite shows there,
        ;      take the cell and lay them over (sprite block mapped)
        ld a,(dblk)
        call setblk
        ld a,(dy0)
        call div10
        ld (dr0),a
        ld a,(dy1)
        dec a
        call div10
        ld (dr1),a
        ; screen address of row dr0, column 0 of the hidden page
        ld a,(dr0)
        inc a
        add a,a
        ld l,a
        ld h,high(ROW40)
        ld e,(hl)
        inc l
        ld d,(hl)
        ld a,(page)
        or a
        jr z,.pg
        set 2,d
.pg     ld (drow0),de
        xor a
        ld (dk),a
.col    call vbpoll
        ld a,(dc0)
        ld hl,dk
        add a,(hl)
        cp 40
        jp nc,.nextc            ; off screen (also negative)
        ld (dcx),a
        ; which halves are nearer than the wall?
        add a,a
        ld l,a
        ld h,high(ZB)
        ld b,0
        ld a,(iy+V_Z)
        cp (hl)
        jr nc,.lv
        ld b,0F0h
.lv     inc l
        cp (hl)
        jr nc,.rv
        ld a,b
        or 0Fh
        ld b,a
.rv     ld a,b
        or a
        jp z,.nextc
        ld (M_cvv+1),a          ; the visible halves
        cpl
        ld (M_cnvv+1),a
        ; this sprite column: base + (k << colsize)
        ld a,(dk)
        ld l,a
        ld h,0
        ld a,(dcs)
        ld b,a
.sh     add hl,hl
        djnz .sh
        ld de,(dbase)
        add hl,de
        ld a,l
        ld (M_cl1+1),a
        ld (M_cl2+1),a
        ld a,h
        ld (cmp_hi),a
        ld a,(dcx)
        ld l,a
        ld h,0
        ld de,(drow0)
        add hl,de
        ld (caddr),hl
        ld a,(dr0)
        ld (dr),a
.row    call cellsp
        call nz,put_cell
        ld a,(dr)
        ld hl,dr1
        cp (hl)
        jr z,.nextc
        inc a
        ld (dr),a
        ld hl,(caddr)
        ld de,40
        add hl,de
        ld (caddr),hl
        jr .row
.nextc  ld hl,dk
        inc (hl)
        ld a,(dbw)
        cp (hl)
        jp nz,.col
        ld a,X1C
        out (PORT_1C),a
        jp tabblk

; div10: A = 0..219 -> A = A / 10
div10:  ld b,-1
.l      inc b
        sub 10
        jr nc,.l
        ld a,b
        ret

; --------------------------------------------------------------------------
; rowmap: ROWMAP[y] = 2 * source row, for the visible y range
; --------------------------------------------------------------------------
rowmap:
        ld a,(iy+V_IMG)
        ld e,a
        ld d,0
        ld hl,IMGH0
        add hl,de
        ld a,(hl)
        ld (.h0+1),a
        ld c,(iy+V_H)           ; C = h
        ld hl,(dyt)             ; HL = y (signed)
        ld de,0                 ; D = 2*row, E = accumulator
        ld b,c
.l      bit 7,h
        jr nz,.skip
        ld a,h
        or a
        jr nz,.done
        ld a,l
        cp 220
        jr nc,.done
        push hl
        ld h,high(ROWMAP)
        ld (hl),d
        pop hl
.skip   inc hl
        ld a,e
.h0     add a,0
        ld e,a
.w      ld a,e
        cp c
        jr c,.n
        sub c
        ld e,a
        inc d
        inc d
        jr .w
.n      djnz .l
.done   ret

; --------------------------------------------------------------------------
; cellsp: the sprite's lines in cell row dr of this column, into TMPM (NOT
;   mask: 1 = background shows) and TMPD (ink).  Lines the sprite does not
;   reach, and halves behind the wall, are left clear.
;   -> NZ if any of the sprite shows in the cell
; --------------------------------------------------------------------------
cellsp: ld a,(dr)
        add a,a
        ld b,a
        add a,a
        add a,a
        add a,b
        ld b,a                  ; B = 10 r
        ld a,(dy0)
        cp b
        jr nc,.a
        ld a,b
.a      ld e,a                  ; E = first line on screen
        sub b
        add a,low(TMPM)
        ld c,a                  ; C = its line in the cell
        ld a,b
        add a,CELLH
        ld b,a
        ld a,(dy1)
        cp b
        jr c,.z
        ld a,b
.z      sub e                   ; lines
        cp CELLH
        jp nz,.prt
        ld a,(M_cvv+1)          ; a whole cell, both halves visible:
        inc a                   ; the quick way, unrolled
        jp nz,.whole0
        ld d,high(ROWMAP)
        ld a,(cmp_hi)
        ld h,a
        ld a,(M_cl1+1)
        ld c,a
        ld a,(de)
        inc e
        or c
        ld l,a
        ld a,(hl)
        ld (TMPM+0),a
        inc l
        ld a,(hl)
        ld (TMPD+0),a
        ld a,(de)
        inc e
        or c
        ld l,a
        ld a,(hl)
        ld (TMPM+1),a
        inc l
        ld a,(hl)
        ld (TMPD+1),a
        ld a,(de)
        inc e
        or c
        ld l,a
        ld a,(hl)
        ld (TMPM+2),a
        inc l
        ld a,(hl)
        ld (TMPD+2),a
        ld a,(de)
        inc e
        or c
        ld l,a
        ld a,(hl)
        ld (TMPM+3),a
        inc l
        ld a,(hl)
        ld (TMPD+3),a
        ld a,(de)
        inc e
        or c
        ld l,a
        ld a,(hl)
        ld (TMPM+4),a
        inc l
        ld a,(hl)
        ld (TMPD+4),a
        ld a,(de)
        inc e
        or c
        ld l,a
        ld a,(hl)
        ld (TMPM+5),a
        inc l
        ld a,(hl)
        ld (TMPD+5),a
        ld a,(de)
        inc e
        or c
        ld l,a
        ld a,(hl)
        ld (TMPM+6),a
        inc l
        ld a,(hl)
        ld (TMPD+6),a
        ld a,(de)
        inc e
        or c
        ld l,a
        ld a,(hl)
        ld (TMPM+7),a
        inc l
        ld a,(hl)
        ld (TMPD+7),a
        ld a,(de)
        inc e
        or c
        ld l,a
        ld a,(hl)
        ld (TMPM+8),a
        inc l
        ld a,(hl)
        ld (TMPD+8),a
        ld a,(de)
        inc e
        or c
        ld l,a
        ld a,(hl)
        ld (TMPM+9),a
        inc l
        ld a,(hl)
        ld (TMPD+9),a
        jp .done
.whole0 ld a,CELLH
        jr .whole
.prt    ld hl,0FFFFh            ; part of a cell: clear it first
        ld (TMPM),hl
        ld (TMPM+2),hl
        ld (TMPM+4),hl
        ld (TMPM+6),hl
        ld (TMPM+8),hl
        ld hl,0
        ld (TMPD),hl
        ld (TMPD+2),hl
        ld (TMPD+4),hl
        ld (TMPD+6),hl
        ld (TMPD+8),hl
.whole  ex af,af'               ; A' = lines
        ld b,high(TMPM)         ; BC -> TMPM line
        ld d,high(ROWMAP)       ; DE -> row map
        ld a,(cmp_hi)
        ld h,a                  ; H = the column's page
        ld a,(M_cvv+1)
        inc a
        jr nz,.part
.f      ld a,(de)               ; both halves visible
        inc e
M_cl1:  or 0
        ld l,a
        ld a,(hl)
        ld (bc),a
        inc l
        ld a,(hl)
        set 4,c
        ld (bc),a
        res 4,c
        inc c
        ex af,af'
        dec a
        jr z,.done
        ex af,af'
        jr .f
.part   ld a,(de)               ; one half is behind the wall
        inc e
M_cl2:  or 0
        ld l,a
        ld a,(hl)
M_cnvv: or 0                    ; the hidden half shows the background
        ld (bc),a
        inc l
        ld a,(hl)
M_cvv:  and 0
        set 4,c
        ld (bc),a
        res 4,c
        inc c
        ex af,af'
        dec a
        jr z,.done
        ex af,af'
        jr .part
.done   ld hl,TMPM              ; any NOT mask bit clear?
        ld a,(hl)
        rept CELLH-1
        inc l
        and (hl)
        endm
        inc a                   ; all FF: nothing (Z)
        ret

; --------------------------------------------------------------------------
; put_cell: take cell (caddr) and lay TMPM/TMPD over it; the cell takes the
;   sprite's ink if the sprite is most of what is lit in it; to PCG RAM
; --------------------------------------------------------------------------
put_cell:
        ld hl,TMPM              ; covers the whole cell? (all NOT masks 0)
        ld a,(hl)
        rept CELLH-1
        inc l
        or (hl)
        endm
        ld (pc_full),a
        call claim
        ret c                   ; no glyphs left this frame
        ld a,(cmp_slot)
        call slot_ptr
        ld (cmp_sh),de
        ld a,(pc_full)
        or a
        jr nz,.mix
        ld hl,TMPD              ; opaque: the glyph is the sprite's lines
        ld bc,CELLH
        ldir
        ld hl,TMPD
        xor a
        rept CELLH
        or (hl)
        inc l
        endm
        jp z,.up                ; all black: the cell keeps its ink
        jp .ink
.mix    ld hl,TMPM              ; background where the mask is clear, then ink
        ld a,(de)
        and (hl)
        set 4,l
        or (hl)
        res 4,l
        ld (de),a
        inc l
        inc e
        ld a,(de)
        and (hl)
        set 4,l
        or (hl)
        res 4,l
        ld (de),a
        inc l
        inc e
        ld a,(de)
        and (hl)
        set 4,l
        or (hl)
        res 4,l
        ld (de),a
        inc l
        inc e
        ld a,(de)
        and (hl)
        set 4,l
        or (hl)
        res 4,l
        ld (de),a
        inc l
        inc e
        ld a,(de)
        and (hl)
        set 4,l
        or (hl)
        res 4,l
        ld (de),a
        inc l
        inc e
        ld a,(de)
        and (hl)
        set 4,l
        or (hl)
        res 4,l
        ld (de),a
        inc l
        inc e
        ld a,(de)
        and (hl)
        set 4,l
        or (hl)
        res 4,l
        ld (de),a
        inc l
        inc e
        ld a,(de)
        and (hl)
        set 4,l
        or (hl)
        res 4,l
        ld (de),a
        inc l
        inc e
        ld a,(de)
        and (hl)
        set 4,l
        or (hl)
        res 4,l
        ld (de),a
        inc l
        inc e
        ld a,(de)
        and (hl)
        set 4,l
        or (hl)
        res 4,l
        ld (de),a
        ld a,(pc_bg)            ; a (nearly) blank background: any ink at all
        cp 3                    ; makes the sprite most of what is lit
        jr nc,.tl
        ld hl,TMPD
        xor a
        rept CELLH
        or (hl)
        inc l
        endm
        jp z,.up
        jp .ink
.tl     ld h,high(POPC)         ; sprite ink pixels
        ld de,TMPD
        ld c,0
        rept CELLH
        ld a,(de)
        ld l,a
        ld a,c
        add a,(hl)
        ld c,a
        inc e
        endm
        or a
        jp z,.up                ; none: the cell keeps its ink
        ld c,a
        ld a,(pc_bg)            ; background pixels <= sprite pixels: the
        cp c                    ; sprite is at least half of what is lit
        jp c,.ink
        jp z,.ink
        ld a,c
        add a,a
        ld b,a
        ld de,(cmp_sh)          ; lit pixels in the cell
        ld c,0
        rept CELLH
        ld a,(de)
        ld l,a
        ld a,c
        add a,(hl)
        ld c,a
        inc e
        endm
        ld a,c
        ld c,b
        cp c
        jr z,.ink
        jr nc,.up               ; lit > sprite pixels * 2: keep the old ink
.ink    ld hl,(caddr)
        set 3,h
        ld a,40h
        out (PORT_08),a
        ld a,(hl)
        and 0F0h
        or (iy+V_INK)
        ld (hl),a
        xor a
        out (PORT_08),a
.up     ; the glyph to PCG RAM: pool bank, or bank 15 for slots 128+
        ld a,(cmp_slot)
        cp 128
        jr nc,.u15
        ld e,a
        ld a,(poolbk)
        jr .ub
.u15    sub 128
        ld e,a
        ld a,(pool15)
        add a,e
        ld e,a
        ld a,15
.ub     or X1C
        out (PORT_1C),a
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PCGWIN
        add hl,de
        ex de,hl
        ld hl,(cmp_sh)
        rept CELLH
        ldi
        endm
        ret

; --------------------------------------------------------------------------
; claim: cell (caddr) of the hidden page joins this sprite.  A cell not yet
;   taken this frame gets a private glyph: unless the sprite covers it all,
;   a copy of what it showed, read back from PCG RAM; its old code, bank and
;   ink go on the page's restore list.  -> cmp_slot, or CY if the pool is
;   used up.
; --------------------------------------------------------------------------
claim:
        ld hl,(caddr)
        ld c,(hl)               ; C = code
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld b,(hl)               ; B = bank
        ld a,X1C
        out (PORT_1C),a
        ld a,(poolbk)
        cp b
        jr nz,.n15
        ld a,c                  ; already one of this frame's glyphs
        sub 80h
        jp .old
.n15    ld a,b
        cp 15
        jr nz,.new
        ld a,(pool15)
        ld e,a
        ld a,c
        sub 80h
        sub e
        add a,128
        jp .old
.new    ld a,(nslot)            ; a free glyph in the pool?
        cp POOLN
        ccf
        ret c
        ld (cslot),a
        inc a
        ld (nslot),a
        ; restore entry: address, code, bank, ink
        ld de,(rl_ptr)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
        ld a,b
        ld (de),a
        inc de
        set 3,h
        ld a,40h
        out (PORT_08),a
        ld a,(hl)
        ld (de),a
        xor a
        out (PORT_08),a
        res 3,h
        inc de
        ld (rl_ptr),de
        push hl
        ld hl,(rl_head)
        inc (hl)
        ld a,b                  ; lit pixels of the old glyph (LITC), if known
        and 15
        cp 13
        ld a,0FFh
        jr nc,.lq
        ld a,b
        rrca
        ld h,a
        and 80h
        ld l,a
        ld a,c
        and 7Fh
        or l
        ld l,a
        ld a,h
        and 07h
        add a,high(LITC)
        ld h,a
        ld a,(hl)
.lq     ld (pc_bg),a
        ld a,(pc_full)
        or a
        jr z,.nc                ; covered: nothing to copy
        ; copy the old glyph from the tileset in RAM block 4 (the same
        ; glyphs as PCG RAM, which is not read back): bank * 1280 + code * 10
        ld a,BLK_PCG
        call setblk
        ld a,c
        and 7Fh
        ld l,a
        ld h,high(C10)
        ld e,(hl)
        inc h
        ld d,(hl)               ; DE = code * 10
        ld a,b
        and 15
        ld l,a
        add a,a
        add a,a
        add a,l                 ; bank * 5
        add a,d
        ld h,a
        ld l,e
        ld a,(cslot)
        call slot_ptr           ; DE = private glyph
        rept CELLH
        ldi
        endm
        ld a,(dblk)             ; back to the sprite's block
        call setblk
.nc     pop hl
        ; point the cell at it
        ld a,(cslot)
        cp 128
        jr nc,.h
        or 80h
        ld (hl),a
        ld a,(poolbk)
        jr .pb
.h      sub 128
        ld e,a
        ld a,(pool15)
        add a,e
        or 80h
        ld (hl),a
        ld a,15
.pb     ld e,a
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld (hl),e
        ld a,X1C
        out (PORT_1C),a
        ld a,(cslot)
.have   ld (cmp_slot),a
        or a                    ; (no carry)
        ret
.old    ld (cmp_slot),a         ; a glyph of this frame: lit pixels not known
        ld a,0FFh
        ld (pc_bg),a
        or a
        ret

; slot_ptr: A = slot -> DE = its private glyph (keeps HL, BC)
slot_ptr:
        ld e,a
        rrca
        rrca
        rrca
        rrca
        ld d,a
        and 0F0h
        ld e,a
        ld a,d
        and 0Fh
        add a,high(SHADOW)
        ld d,a
        ret

cmp_hi: db 0
cmp_sh: dw 0
cmp_ad: dw 0
cmp_slot: db 0
pc_full: db 0
pc_bg:  db 0FFh
