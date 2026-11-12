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
        ld ix,ENT
        ld b,NENT
.e      push bc
        ld a,NENT
        sub b
        ld (cur_ent),a
        ld a,(ix+E_TYPE)
        or a
        call nz,proj_one
        ld bc,ESIZE
        add ix,bc
        pop bc
        djnz .e
        ; the zapper, nearest of all
        ld a,(show_gun)
        or a
        jr z,.sort
        ld (iy+V_Z),0
        ld (iy+V_ENT),0FFh
        ld a,(gun_fire)
        or a
        ld a,IMG_WEAP0
        jr z,.g0
        inc a
.g0     ld (iy+V_IMG),a
        ld (iy+V_S),0
        ld a,(gun_bob)          ; sway 0..7 dots
        ld e,a
        ld d,0
        ld hl,156
        add hl,de
        ld (iy+V_DX),l
        ld (iy+V_DX+1),h
        ld a,(gun_bob)
        rra
        and 3
        ld e,a
        ld hl,222
        add hl,de
        ld (iy+V_YB),l
        ld (iy+V_YB+1),h
        ld de,-WEAPON_H
        add hl,de
        ld (iy+V_YT),l
        ld (iy+V_YT+1),h
        ld (iy+V_H),WEAPON_H
        ld a,(gun_ink)
        ld (iy+V_INK),a
        ld a,(WTAB+IMG_WEAP0*16)
        ld (iy+V_W),a
        ld hl,nvis
        inc (hl)
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
        ; height = yb * F / 64, at most 124
        ld a,(pyb)
        ld e,(ix+E_F)
        call mul8
        ld a,h
        cp 1Fh
        ld a,124
        jr nc,.hc
        add hl,hl
        add hl,hl
        ld a,h
.hc     ld b,a
        ld a,(ix+E_ST)
        cp ST_DIE
        ld a,b
        jr nz,.hd
        ld e,(ix+E_TM)          ; dying: squash by timer/16
        call mul8
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
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
        ld a,(ix+E_IMG)
        bit 3,(ix+E_AN)         ; second frame every 8 fields
        jr z,.f0
        ld b,a
        ld a,(ix+E_TYPE)
        cp T_ENEMY
        ld a,b
        jr c,.f0
        cp IMG_WEAP0            ; items and shots have one frame
        jr c,.f0
        inc a
.f0     ld (iy+V_IMG),a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
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
        jr nz,.ik
        ld b,CWHITE             ; hurt: flash white
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
        ; directory entry: IMGDIR + (img * 16 + s) * 8
        ld a,(iy+V_IMG)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,(iy+V_S)
        ld d,0
        add hl,de
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,IMGDIR
        add hl,de
        push hl
        pop ix                  ; IX = directory entry
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
        ; ---- phase A: claim the cells (tileset mapped)
        ld a,BLK_PCG
        call setblk
        xor a
        ld (ncell),a
        ld a,(dy0)
        call div10
        ld (dr0),a
        ld a,(dy1)
        dec a
        call div10
        ld (dr1),a
        xor a
        ld (dk),a
.col    ld a,(dc0)
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
        ld (dvis),a
        ld a,(dr0)
        ld (dr),a
.row    call claim
        ld a,(dr)
        ld hl,dr1
        cp (hl)
        jr z,.nextc
        inc a
        ld (dr),a
        jr .row
.nextc  ld hl,dk
        inc (hl)
        ld a,(dbw)
        cp (hl)
        jp nz,.col
        ld a,(ncell)
        or a
        jp z,tabblk
        ; ---- phase B: compose (sprite block mapped)
        ld a,(dblk)
        call setblk
        ld hl,CELLS
        ld a,(ncell)
        ld b,a
.cb     push bc
        push hl
        call compose
        pop hl
        ld bc,4
        add hl,bc
        pop bc
        djnz .cb
        ; ---- phase C: upload the glyphs
        ld hl,CELLS
        ld a,(ncell)
        ld b,a
.cc     push bc
        ld a,(hl)               ; slot
        push hl
        call upload_slot
        pop hl
        ld bc,4
        add hl,bc
        pop bc
        djnz .cc
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
; claim: cell (dcx, dr) of the hidden page joins this sprite
; --------------------------------------------------------------------------
claim:
        ld a,(ncell)
        cp POOLN
        ret nc
        ; HL = cell address
        ld a,(dr)
        inc a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; (row+1) * 40
        ld a,(dcx)
        ld e,a
        ld d,0
        add hl,de
        ld a,(page)
        or a
        jr z,.pg
        ld de,400h
        add hl,de
.pg     ld de,VRAM
        add hl,de
        ld (caddr),hl
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld b,(hl)               ; B = bank
        ld a,X1C
        out (PORT_1C),a
        ld c,(hl)               ; C = code
        ld a,(poolbk)
        cp b
        jr nz,.n15
        ld a,c                  ; already one of this frame's glyphs
        sub 80h
        jp .have
.n15    ld a,b
        cp 15
        jr nz,.new
        ld a,(pool15)
        ld e,a
        ld a,c
        sub 80h
        sub e
        add a,128
        jp .have
.new    ld a,(nslot)            ; a free glyph in the pool?
        cp POOLN
        ret nc
        inc a
        ld (nslot),a
        dec a
        ld (cslot),a
        ; restore entry: address, code, bank, colour
        push bc
        call rlist_ptr          ; HL = list, A = count
        dec hl
        inc (hl)
        inc hl
        ld e,a
        ld d,0
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,de
        pop de
        add hl,de               ; entry = list + 5 * count
        ld de,(caddr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        pop bc
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld a,d
        add a,8
        ld d,a
        ld a,40h
        out (PORT_08),a
        ld a,(de)
        ld (hl),a
        xor a
        out (PORT_08),a
        ld a,(cslot)
        ; copy the old glyph from the tileset: bank * 1280 + (code-80h) * 10
        push af
        ld a,c
        sub 80h
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; * 10
        ld a,b
        and 15
        ld d,a
        add a,a
        add a,a
        add a,d
        add a,h
        ld h,a
        pop af
        call slot_ptr           ; DE = shadow glyph
        ld bc,CELLH
        ldir
        ; point the cell at it
        ld a,(cslot)
        call slot_code          ; B = bank, C = code
        ld hl,(caddr)
        ld (hl),c
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld (hl),b
        ld a,X1C
        out (PORT_1C),a
        ld a,(cslot)
        jr .ink
.have   ld (cslot),a
.ink    ; the cell takes the sprite's ink and keeps its paper
        ld hl,(caddr)
        ld a,h
        add a,8
        ld h,a
        ld a,40h
        out (PORT_08),a
        ld a,(hl)
        and 0F0h
        or (iy+V_INK)
        ld (hl),a
        xor a
        out (PORT_08),a
        ; add to the cell list: slot, column, row, visible halves
        ld a,(ncell)
        ld l,a
        inc a
        ld (ncell),a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,CELLS
        add hl,de
        ld a,(cslot)
        ld (hl),a
        inc hl
        ld a,(dk)
        ld (hl),a
        inc hl
        ld a,(dr)
        ld (hl),a
        inc hl
        ld a,(dvis)
        ld (hl),a
        ret

; slot_ptr: A = slot -> DE = its shadow glyph (keeps HL, BC)
slot_ptr:
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,SHADOW
        add hl,de
        ex de,hl
        pop hl
        ret

; slot_code: A = slot -> B = PCG bank, C = code
slot_code:
        cp 128
        jr nc,.h
        or 80h
        ld c,a
        ld a,(poolbk)
        ld b,a
        ret
.h      sub 128
        ld c,a
        ld a,(pool15)
        add a,c
        or 80h
        ld c,a
        ld b,15
        ret

; upload_slot: A = slot -> its shadow glyph into PCG RAM
upload_slot:
        push af
        call slot_ptr
        pop af
        call slot_code
        ld a,b
        or X1C
        out (PORT_1C),a
        ld a,c
        sub 80h
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,PCGWIN
        add hl,bc
        ex de,hl
        ld bc,CELLH
        ldir
        ret

; --------------------------------------------------------------------------
; compose: HL -> cell list entry (slot, column, row, visible halves)
;   lays the sprite's rows over the shadow glyph
; --------------------------------------------------------------------------
compose:
        ld a,(hl)
        call slot_ptr           ; DE = shadow glyph
        ld (cmp_sh),de
        inc hl
        ld a,(hl)               ; column k: base + (k << colsize)
        inc hl
        ld c,(hl)               ; row r
        inc hl
        ld b,(hl)               ; visible halves
        push bc
        ld l,a
        ld h,0
        ld a,(dcs)
        ld b,a
.sh     add hl,hl
        djnz .sh
        ld de,(dbase)
        add hl,de
        ld a,l
        ld (cmp_or1+1),a
        ld (cmp_or2+1),a
        ld a,h
        ld (cmp_hi),a
        pop bc
        ld a,b
        ld (cmp_vv+1),a
        cpl
        ld (cmp_nvv+1),a
        ld a,c                  ; lines max(y0, 10r) .. min(y1, 10r + 10)
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
.a      ld c,a                  ; C = first line on screen
        sub b
        ld hl,(cmp_sh)
        add a,l
        ld l,a                  ; HL -> that line in the glyph
        ld a,b
        add a,CELLH
        ld b,a
        ld a,(dy1)
        cp b
        jr c,.z
        ld a,b
.z      sub c
        ret z
        ret c
        ex af,af'               ; A' = lines
        ld b,h                  ; BC = glyph line pointer
        ld a,l
        ld e,c
        ld c,a
        ld d,high(ROWMAP)       ; DE = row map
        ld a,(cmp_hi)
        ld h,a                  ; H = the column's page
        ld a,(cmp_vv+1)
        inc a
        jr nz,.part
.f      ld a,(de)               ; both halves visible
        inc e
cmp_or1: or 0
        ld l,a
        ld a,(bc)
        and (hl)                ; keep the background outside the mask
        inc l
        or (hl)                 ; and draw the sprite's ink
        ld (bc),a
        inc c
        ex af,af'
        dec a
        ret z
        ex af,af'
        jr .f
.part   ld a,(de)               ; one half is behind the wall
        inc e
cmp_or2: or 0
        ld l,a
        ld a,(hl)
cmp_nvv: or 0                   ; the hidden half keeps its background
        ld (.t+1),a
        inc l
        ld a,(hl)
cmp_vv: and 0
        ld (.u+1),a
        ld a,(bc)
.t      and 0
.u      or 0
        ld (bc),a
        inc c
        ex af,af'
        dec a
        ret z
        ex af,af'
        jr .part
cmp_hi: db 0
cmp_sh: dw 0
cmp_hi: db 0
