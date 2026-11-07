; =====================================================================
;  ENGINE: two-page scrolling playfield on the Premium's PCG
;
;  The 2K screen ring holds two 1024-cell pages (64 x 16). Page A shows
;  the terrain at even scroll positions (cell aligned), page B at odd ones
;  (shifted 4 pixels = one VZ pixel, drawn with 'pair' glyphs). Each page
;  coarse-scrolls by moving its start address one cell every other frame,
;  so only the new right-hand column is written. The page not on screen is
;  rendered while the other is shown; the 6545 start address is switched
;  in vertical blanking, so nothing tears.
;
;  Sprites are composed into PCG 'pool' glyphs (two banks per page) over
;  the glyph underneath. Shadow arrays hold the background of every ring
;  cell, so sprite cells are restored when their page comes round again.
; =====================================================================

; TAB block (current stage) layout, mapped in the lower window when used
T0C	equ $0000		; phase 0: tile*2+half -> code / bank / colour
T0A	equ $0080
T0K	equ $0100
T1C	equ $0200		; phase 1 inside a tile: tile -> code / bank / colour
T1A	equ $0240
T1K	equ $0280
PXC	equ $0300		; phase 1 across tiles: pair index -> code / bank / colour
PXA	equ $0400
PXK	equ $0500
BANDK	equ $0600		; band glyph colours
SHDR	equ $0680		; stage header: band row, band colour, star colour
BOSSC	equ $0700		; boss body cells
PXI	equ $1000		; tileA*64 + tileB -> pair index


; ---------------------------------------------------------------------
render:
	ld a,(scrollon)
	or a
	jr z,.stop
	ld a,(scrollx)
	and 1
	ld (phase),a
	ld (rpage),a
	jr .pl
.stop:	xor a
	ld (phase),a
	ld a,(rpage)
	xor 1
	ld (rpage),a
.pl:	ld hl,(scrollx)
	srl h
	rr l
	ld (curL),hl
	ld a,(rpage)
	add a,a
	add a,a
	add a,h
	and 7
	ld h,a
	ld (nextstart),hl
	ld a,h
	or SHC>>8
	ld h,a
	ld (pstart),hl		; as an SHC address
	; sprite pool for this page
	ld a,(rpage)
	or a
	ld a,BK_POOLA
	jr z,$+4
	ld a,BK_POOLB
	ld (poolbase),a
	ld (pool_bank),a
	or LV_SCREEN
	out (P_LV),a
	ld a,$80
	ld (pool_code),a
	ld hl,PCGWIN
	ld (pool_dst),hl
	xor a
	ld (pool_slot),a
	ld (qcount),a
	ld (qslot0),a
	ld (caching),a
	ld a,(scrollon)		; boss-part glyph caches only hold while
	or a			; the scenery stands still
	call nz,dc_clear
	call restore		; (also points qptr at this page's queue)
	call vschk
	call update_cols
	call draw_band
	call vschk
	call draw_all
	call draw_stars
	call vschk
	call apply_queue
	jp stars_show

; ---------------------------------------------------------------------
;  restore the cells sprites/stars used on this page last time
; ---------------------------------------------------------------------
restore:
	ld a,(rpage)
	or a
	ld hl,QA
	ld de,(qnA)
	jr z,.pg
	ld hl,QB
	ld de,(qnB)
.pg:	ld (qbase),hl
	ld (qptr),hl
	push de
	call stars_hide
	pop de
	ld a,d
	or e
	ret z
	; 16-bit count (a busy boss scene can list more than 255 cells):
	; B = low byte, C = passes of the outer loop
	ld a,e
	or a
	jr z,$+3
	inc d
	ld b,e
	ld c,d
	ld (rs_n),bc
	ld hl,(qbase)
	; pass 1: screen codes, clear the slot marks
.p1:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(de)		; SHC
	set 7,d
	ld (de),a		; screen
	ld a,d
	xor $F0^$60
	ld d,a
	xor a
	ld (de),a		; CSLOT
	djnz .p1
	dec c
	jr nz,.p1
	; pass 2: attributes
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,(qbase)
	ld bc,(rs_n)
.p2:	ld e,(hl)
	inc hl
	ld a,(hl)
	inc hl
	xor $70^$58
	ld d,a
	ld a,(de)		; SHA
	ex af,af'
	ld a,d
	xor $58^$F0
	ld d,a
	ex af,af'
	ld (de),a
	djnz .p2
	dec c
	jr nz,.p2
	ld a,(pool_bank)
	or LV_SCREEN
	out (P_LV),a
	; pass 3: colours
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,(qbase)
	ld bc,(rs_n)
.p3:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	set 3,d
	ld a,(de)		; SHK
	set 7,d
	ld (de),a
	djnz .p3
	dec c
	jr nz,.p3
	xor a
	out (P_COLCTL),a
	ret
rs_n	dw 0

; ---------------------------------------------------------------------
;  terrain columns
; ---------------------------------------------------------------------
update_cols:
	ld a,(rpage)
	or a
	ld hl,lastLA
	jr z,$+5
	ld hl,lastLB
	ld (uc_ptr),hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(phase)
	cp (hl)			; page holds this phase?
	jr nz,.full
	ld hl,(curL)
	or a
	sbc hl,de
	jr z,.done		; same position
	dec hl
	ld a,h
	or l
	jr nz,.full
	ld a,63			; moved one cell: the new right-hand column
	call colwrite
	jr .done
.full:	xor a
.fl:	push af
	call colwrite
	call vschk
	pop af
	inc a
	cp 64
	jr c,.fl
.done:	ld hl,(uc_ptr)
	ld de,(curL)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld a,(phase)
	ld (hl),a
	ret
uc_ptr	dw 0

; A = screen column 0..63 of the page being rendered
colwrite:
	ld (cw_c),a
	ld hl,(curL)
	ld e,a
	ld d,0
	add hl,de		; world cell
	ld a,l
	and 1
	ld (cw_half),a
	srl h
	rr l
	ld a,l
	and 63
	ld (cw_t),a
	call tcolp
	ld (cw_pa),hl
	ld a,(cw_t)
	inc a
	and 63
	call tcolp
	ld (cw_pb),hl
	ld a,(tabblk)
	call map_blk
	ld de,colbuf
	ld b,PROWS
	ld a,(phase)
	or a
	jr nz,.ph1
	; ---- phase 0: T0[tile*2+half]
	ld a,(cw_half)
	ld c,a
	ld hl,(cw_pa)
.p0:	ld a,(hl)
	inc hl
	push hl
	add a,a
	or c
	ld l,a
	ld h,T0C>>8
	ld a,(hl)
	ld (de),a
	inc de
	set 7,l			; T0A = T0C + 80h
	ld a,(hl)
	ld (de),a
	inc de
	res 7,l
	inc h			; T0K = T0C + 100h
	ld a,(hl)
	ld (de),a
	inc de
	pop hl
	djnz .p0
	jp .write
.ph1:	ld a,(cw_half)
	or a
	jr nz,.px
	; ---- phase 1, inside a tile: T1[tile]
	ld hl,(cw_pa)
.p1:	ld a,(hl)
	inc hl
	push hl
	ld l,a
	ld h,T1C>>8
	ld a,(hl)
	ld (de),a
	inc de
	set 6,l			; T1A = T1C + 40h
	ld a,(hl)
	ld (de),a
	inc de
	res 6,l
	set 7,l			; T1K = T1C + 80h
	ld a,(hl)
	ld (de),a
	inc de
	pop hl
	djnz .p1
	jr .write
	; ---- phase 1, across tiles: PX[PXI[a*64+b]]
.px:	ld hl,(cw_pa)
	ld ix,(cw_pb)
.p2:	ld a,(hl)		; tile a
	inc hl
	push hl
	rrca
	rrca
	ld c,a
	and $C0
	or (ix+0)		; tile b
	inc ix
	ld l,a
	ld a,c
	and $0F
	add a,PXI>>8
	ld h,a
	ld l,(hl)		; pair index
	ld h,PXC>>8
	ld a,(hl)
	ld (de),a
	inc de
	inc h
	ld a,(hl)
	ld (de),a
	inc de
	inc h
	ld a,(hl)
	ld (de),a
	inc de
	pop hl
	djnz .p2
.write:	MEMV BLK_WORK
	; the band row: open space there becomes band (code set by draw_band)
	ld a,(bandrow)
	or a
	jr z,.nob
	ld l,a
	add a,a
	add a,l
	ld l,a
	ld h,0
	ld de,colbuf
	add hl,de		; colbuf entry of the band row
	ld (cw_bp),hl
	xor a
	ld (cw_bf),a
	ld a,(hl)
	cp BLANK_CODE
	jr nz,.nob
	inc hl
	ld a,(hl)
	or a
	jr nz,.nob
	ld (hl),BK_BAND
	inc hl
	ld a,(bandcol)
	ld (hl),a
	ld a,1
	ld (cw_bf),a
.nob:	; SHC address of row 0
	ld hl,(pstart)
	ld a,(cw_c)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	res 3,h
	ld (cw_addr),hl
	; band flag of the band-row cell
	ld a,(bandrow)
	or a
	jr z,.nbf
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,de
	res 3,h
	ld a,h
	xor $70^$68
	ld h,a
	ld a,(cw_bf)
	ld (hl),a
	ld hl,(cw_addr)
.nbf:	; shadows and the page, one row at a time
	ld de,colbuf
	ld b,PROWS
	ld a,(pool_bank)
	or LV_SCREEN
	ld c,a			; (P_LV value for the screen)
.w1:	ld a,(de)		; code
	inc de
	ld (hl),a		; SHC
	set 7,h
	ld (hl),a		; screen
	ld a,LV_ATTR
	out (P_LV),a
	ld a,(de)		; bank
	inc de
	ld (hl),a		; attribute
	ex af,af'
	ld a,c
	out (P_LV),a
	res 7,h
	ld a,h
	xor $70^$58
	ld h,a
	ex af,af'
	ld (hl),a		; SHA
	ld a,h
	xor $58^$78
	ld h,a
	ld a,(de)		; colour
	inc de
	ld (hl),a		; SHK
	set 7,h			; F8-FF: colour RAM
	ex af,af'
	ld a,COL_ON
	out (P_COLCTL),a
	ex af,af'
	ld (hl),a
	xor a
	out (P_COLCTL),a
	ld a,h
	and $77			; back to SHC (70-77)
	ld h,a
	ld a,l
	add a,64
	ld l,a
	jr nc,.n1
	inc h
	res 3,h
.n1:	djnz .w1
	ret
tcolp:	; A = tile column 0..63 -> HL = TRING + A*16
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,TRING
	add hl,de
	ret
cw_c	db 0
cw_t	db 0
cw_half	db 0
cw_pa	dw 0
cw_pb	dw 0
cw_addr	dw 0
cw_bp	dw 0
cw_bf	db 0

; ---------------------------------------------------------------------
;  parallax band (half speed): one character row, open-space cells only
; ---------------------------------------------------------------------
draw_band:
	ld a,(bandrow)
	or a
	ret z
	; band pixel offset u0 = 4*(scrollx>>1): set = u0&4, column = u0>>3
	ld hl,(scrollx)
	srl h
	rr l
	ld a,l
	and 1
	rrca
	rrca
	rrca			; set * 32
	or $80
	ld ixl,a		; code base
	ld a,l
	srl a
	ld c,a			; pattern column
	; SHC address of the band row's first cell
	ld a,(bandrow)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,(pstart)
	add hl,de
	res 3,h
	ld b,SCOLS
.col:	ld a,h
	xor $70^$68
	ld d,a
	ld e,l
	ld a,(de)		; band flag
	or a
	jr z,.sk
	ld a,c
	and 31
	or ixl
	ld (hl),a		; SHC
	set 7,h
	ld (hl),a		; screen
	res 7,h
.sk:	inc c
	inc hl
	res 3,h
	djnz .col
	ret
db_nb	dw 0

; ---------------------------------------------------------------------
;  far stars: two speeds (1/2 and 1/4 of the scroll), drawn into
;  open-space cells only, as tiny star glyphs placed to the VZ pixel
; ---------------------------------------------------------------------
NSTAR	equ 12
stars_init:
	ld hl,rndt+40
	ld de,fstars
	ld b,NSTAR
.s:	ld a,(hl)
	ld (de),a		; x 0..255
	inc hl
	inc de
	ld a,(hl)
	and 63
	cp PFH
	jr c,$+4
	sub 16
	ld (de),a		; y
	inc hl
	inc de
	djnz .s
	ret

draw_stars:
	ld a,(rpage)
	or a
	ld hl,STQA
	jr z,$+5
	ld hl,STQB
	ld (stbase),hl
	ld (stptr),hl
	ld hl,(scrollx)
	srl h
	rr l
	ld a,l
	ld (fs_o1),a
	srl h
	rr l
	ld a,l
	ld (fs_o2),a
	ld ix,fstars
	ld b,NSTAR
.st:	push bc
	ld a,b
	cp NSTAR/2+1
	ld a,(fs_o1)
	jr nc,$+5
	ld a,(fs_o2)
	ld e,a
	ld a,(ix+0)
	sub e
	bit 7,a
	jp nz,.sn		; off screen (128..255)
	ld e,a			; screen x 0..127
	ld d,(ix+1)		; y 0..55
	; glyph: 80 + (x&1) + 2*(y&3), +8 for the near (brighter) layer
	ld a,d
	and 3
	add a,a
	ld c,a
	ld a,e
	and 1
	or c
	ld c,a
	ld a,b
	cp NSTAR/2+1
	ld a,c
	jr c,$+4
	or 8
	add a,$80+80
	ld (st_code),a
	; SHC address: pstart + (y>>2)*64 + (x>>1)
	ld a,d
	srl a
	srl a
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,e
	srl a
	ld e,a
	ld d,0
	add hl,de
	ld de,(pstart)
	add hl,de
	res 3,h
	; open space only, and no sprite there this frame
	ld a,(hl)
	cp BLANK_CODE
	jr nz,.sn
	ld a,h
	xor $70^$58
	ld d,a
	ld e,l
	ld a,(de)
	or a
	jr nz,.sn
	ld a,h
	xor $70^$60
	ld d,a
	ld a,(de)
	or a
	jr nz,.sn
	ex de,hl
	ld hl,(stptr)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld a,(st_code)
	ld (hl),a
	inc hl
	ld (stptr),hl
.sn:	inc ix
	inc ix
	pop bc
	dec b
	jp nz,.st
	; end of this page's star list
	ld hl,(stptr)
	ld (hl),0
	inc hl
	ld (hl),0
	ret

; star cells are code-only changes (blank space already has the star colour)
stars_show:
	ld hl,(stbase)
	jr .t
.l:	inc hl
	ld d,(hl)
	set 7,d
	inc hl
	ld a,(hl)
	ld (de),a
	inc hl
.t:	ld e,(hl)
	inc hl
	ld a,(hl)
	dec hl
	or a
	jr nz,.l
	ret
stars_hide:	; restore last time's stars on this page (codes from the shadow)
	ld a,(rpage)
	or a
	ld hl,STQA
	jr z,$+5
	ld hl,STQB
	jr .t
.l:	inc hl
	ld d,(hl)
	ld a,(de)		; SHC
	set 7,d
	ld (de),a
	inc hl
	inc hl
.t:	ld e,(hl)
	inc hl
	ld a,(hl)
	dec hl
	or a
	jr nz,.l
	ret
stbase	dw 0
stptr	dw 0
fs_o1	db 0
fs_o2	db 0
st_code	db 0

; ---------------------------------------------------------------------
;  SPRITES. drawspr: A = sprite id, B = x+32, C = y+16 (VZ coordinates)
;  descriptor (16 bytes): W0, dat0, ct0, W1, dat1, ct1, H, 2H, hcm, 4hcm, nk
; ---------------------------------------------------------------------
drawspr:
	cp SP_CORE0		; boss parts (core, guns, hatches)
	jr c,drawspr_nc
	cp SP_HATCH1+1
	jr nc,drawspr_nc
	ld e,a
	ld a,(scrollon)
	or a
	ld a,e
	jp z,ds_cached
drawspr_nc:
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl		; SPRDESC = 0
	ld a,(hl)
	or a
	ret z			; not in this stage's set
	push ix
	push iy
	push hl
	pop ix			; descriptor
	bit 0,b
	jr z,.v0
	ld de,5
	add hl,de
	ld a,(hl)
.v0:	ld (.wv+1),a		; W
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (.dat+1),de		; data of column 0
	ld e,(hl)
	inc hl
	ld d,(hl)		; colour table
	ld a,(ix+10)
	ld (ds_h),a
	ld (.hh+1),a
	; colour table for this vertical offset: + yo*hcm
	ld a,c
	and 3
	add a,a
	add a,a
	ld (.yo4+1),a		; 4yo
	jr z,.y0
	rrca
	rrca
	push bc
	ld b,a
	xor a
.ym:	add a,(ix+12)
	djnz .ym
	pop bc
	add a,e
	ld e,a
	jr nc,.y0
	inc d
.y0:	; columns: first one on screen, clip both sides
	ld a,b
	srl a
	sub 16			; col0
	ld l,0			; j0
	jp p,.c0
	neg
	ld l,a			; clipped on the left
	xor a
.c0:	cp SCOLS
	jp nc,.out		; wholly off the right-hand side
	ld (.sc0+1),a
	neg
	add a,SCOLS
	ld h,a			; room on the right
.wv:	ld a,0			; W
	sub l
	jp c,.out
	jp z,.out
	cp h
	jr c,$+3
	ld a,h
	ld (.jn+1),a		; columns drawn
	ld a,l
	or a
	jr z,.nj
	; left clip: skip j0 columns of data and colour
	push bc
	ld b,a
	push de
	ld hl,(.dat+1)
	ld e,(ix+11)
	ld d,0
.jm:	add hl,de
	djnz .jm
	ld (.dat+1),hl
	pop hl			; colour table
	ld b,a
	ld e,(ix+13)
.cm:	add hl,de
	djnz .cm
	ex de,hl
	pop bc
.nj:	ld (.ct+2),de		; colour table of the first column drawn
	ld a,(ix+13)
	ld (.cs+1),a
	ld a,(ix+11)
	ld (.h2+1),a
	ld hl,fcell
	ld a,(caching)
	or a
	jr z,$+5
	ld hl,cellsave
	ld (.jcall+1),hl
	; rows: row0 = y/4 - 4 (signed), nk = (H + 4yo + 15) / 16
	ld a,c
	srl a
	srl a
	sub 4
	ld (ds_row0),a
	; SHC address of (row0, sc0)
	ld l,a
	rla
	sbc a,a
	ld h,a
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
.sc0:	ld de,0			; (sc0, patched; D stays 0)
	add hl,de
	ld de,(pstart)
	add hl,de
	ld a,h
	and 7
	or $70
	ld h,a
	ld (ds_ra),hl
	ld a,(.yo4+1)
	ld c,a
	ld a,(ix+10)
	add a,c
	add a,15
	rrca
	rrca
	rrca
	rrca
	and 15
	ld (ds_nk),a
	xor a
	ld (ds_k),a
	; ---- row k: st = 16k - 4yo (negative on the first row: zt = -st)
.yo4:	ld a,0
	neg
.krow:	ld (ds_st),a
	ld c,0			; zt
	or a
	jp p,.pos
	neg
	ld c,a
	xor a
.pos:	ld (.s0+1),a		; s0
	ld e,a
.hh:	ld a,0			; H
	sub e			; lines left in the sprite
	ld b,a
	ld a,16
	sub c			; room in the cell
	cp b
	jr c,$+3
	ld a,b			; n
	ld b,a
	; row on screen?
	ld a,(ds_row0)
	ld hl,ds_k
	add a,(hl)
	jp m,.knext
	cp PROWS
	jp nc,.out
	; patch the fill/copy entries from the aligned tables
	ld a,16
	sub c
	sub b			; zb
	add a,a
	ld l,a
	ld h,ZENT>>8
	ld a,(hl)
	inc l
	ld h,(hl)
	ld l,a
	ld (fcell.zb+1),hl
	ld a,c
	add a,a
	ld l,a
	ld h,ZENT>>8
	ld a,(hl)
	inc l
	ld h,(hl)
	ld l,a
	ld (fcell.zt+1),hl
	ld a,b
	add a,a
	add a,LENT-ZENT
	ld l,a
	ld h,ZENT>>8
	ld a,(hl)
	inc l
	ld h,(hl)
	ld l,a
	ld (fcell.ld+1),hl
	; first column: source = dat + s0, colour = ct + k
.dat:	ld hl,0
.s0:	ld de,0			; (s0, patched; D stays 0)
	add hl,de
	ex de,hl		; DE = source
	ld a,(ds_k)
.ct:	ld iy,0
	add a,iyl
	ld iyl,a
	jr nc,$+4
	inc iyh			; IY = colour entry
.jn:	ld b,0
	ld hl,(ds_ra)
.jcol:	ld a,(iy+0)
	inc a
	jr z,.jsk		; FFh: nothing in this cell
	dec a
.jcall:	call fcell		; (cell itself while a boss part is cached)
.jsk:	inc hl
	res 3,h
.h2:	ld a,0			; (2H, patched)
	add a,e
	ld e,a
	jr nc,$+3
	inc d
.cs:	ld a,0
	add a,iyl
	ld iyl,a
	jr nc,$+4
	inc iyh
	djnz .jcol
.knext:	ld hl,(ds_ra)		; next row
	ld de,64
	add hl,de
	res 3,h
	ld (ds_ra),hl
	ld a,2
	call sndsvc
	ld hl,ds_k
	inc (hl)
	ld a,(ds_nk)
	cp (hl)
	jr z,.out
	ld a,(hl)		; st = 16k - 4yo
	add a,a
	add a,a
	add a,a
	add a,a
	ld hl,.yo4+1
	sub (hl)
	jp .krow
.out:	pop iy
	pop ix
	ret

zfill:	REPT 16
	ld (de),a
	inc e
	ENDR
zfill_end:
	ret
ldichain:
	REPT 16
	ldi
	ENDR
ldi_end:
	ret
	ALIGN 256
ZENT:	dw zfill_end,zfill_end-2,zfill_end-4,zfill_end-6,zfill_end-8,zfill_end-10,zfill_end-12,zfill_end-14
	dw zfill_end-16,zfill_end-18,zfill_end-20,zfill_end-22,zfill_end-24,zfill_end-26,zfill_end-28,zfill_end-30,zfill_end-32
LENT:	dw ldi_end,ldi_end-2,ldi_end-4,ldi_end-6,ldi_end-8,ldi_end-10,ldi_end-12,ldi_end-14
	dw ldi_end-16,ldi_end-18,ldi_end-20,ldi_end-22,ldi_end-24,ldi_end-26,ldi_end-28,ldi_end-30,ldi_end-32

; ---------------------------------------------------------------------
;  fcell: the common case, a sprite cell over open space, without the
;  generic cell's bookkeeping. A = ink, HL = SHC address, DE = column
;  source; keeps HL, DE, B, IY. Anything else goes to cell.
; ---------------------------------------------------------------------
fcell:	ld (cl_ink),a
	ld a,h
	xor $70^$60
	ld h,a
	ld a,(hl)		; CSLOT
	or a
	jr nz,.g1
	ld a,h
	xor $60^$58
	ld h,a
	ld a,(hl)		; SHA: background bank
	or a
	jr nz,.g2
	ld a,h
	xor $58^$70
	ld h,a
	ld a,(hl)		; SHC: background code
	cp BLANK_CODE
	jr nz,.g3
	ld a,(pool_slot)
	inc a
	ret z			; pool full
	ld (pool_slot),a
	ld c,a
	ld a,h
	xor $70^$60
	ld h,a
	ld (hl),c		; CSLOT = slot + 1
	xor $60^$70
	ld h,a
	; the glyph
	push bc			; (the caller's count)
	push de			; (the column source)
	ld (fc_addr),hl
	ex de,hl
	ld de,(pool_dst)
	call fcell_copy
	; on to the page: code, attribute (bank), colour
	ld hl,(fc_addr)
	set 7,h			; screen
	ld a,(pool_code)
	ld (hl),a
	ld a,LV_ATTR
	out (P_LV),a
	ld a,(pool_bank)
	ld (hl),a
	or LV_SCREEN
	out (P_LV),a
	set 3,h			; colour
	ld a,COL_ON
	out (P_COLCTL),a
	ld a,(cl_ink)
	ld (hl),a
	xor a
	out (P_COLCTL),a
	; and its address into the page's restore list
	ld hl,(qptr)
	ld a,(fc_addr)
	ld (hl),a
	inc hl
	ld a,(fc_addr+1)
	ld (hl),a
	inc hl
	ld (qptr),hl
	ld hl,qcount
	inc (hl)
	; next pool glyph
	ld hl,(pool_dst)
	ld a,l
	add a,16
	ld l,a
	jr nc,$+3
	inc h
	ld (pool_dst),hl
	ld hl,pool_code
	inc (hl)
	call z,fc_bank
	pop de
	pop bc
	ld hl,(fc_addr)
	ret
.g1:	ld a,h
	xor $60^$70
	ld h,a
	jr .gen
.g2:	ld a,h
	xor $58^$70
	ld h,a
.g3:
.gen:	ld a,(cl_ink)
cellsave:	; the generic cell, keeping HL DE B
	push bc
	push de
	push hl
	call cell
	pop hl
	pop de
	pop bc
	ret

fc_bank:	; into the page's second pool bank
	ld (hl),$80
	ld hl,PCGWIN
	ld (pool_dst),hl
	ld a,(pool_bank)
	inc a
	ld (pool_bank),a
	or LV_SCREEN
	out (P_LV),a
	ret

; copy a sprite column into the glyph at DE: zt blank lines, n lines from
; HL, zb blank lines (entries patched per row by drawspr)
fcell_copy:
	xor a
fcell.zt:
	call zfill_end
fcell.ld:
	call ldi_end
	xor a
fcell.zb:
	call zfill_end
	ret

; ---------------------------------------------------------------------
;  one sprite cell: HL = SHC address, A = ink, (ds_src) = column source.
;  The n-th new cell of a frame uses pool glyph n and queue entry n.
; ---------------------------------------------------------------------
cell:	ld (cl_ink),a
	ld (ds_src),de
	ld a,h
	xor $70^$60
	ld h,a
	ld a,(hl)		; CSLOT
	or a
	jr z,.new
	cp 254
	jr z,.cache
	cp 253
	jr z,.over253
	inc a
	jp nz,cell_over		; another sprite's glyph is here already
	; ---- boss body underneath (marked FFh)
	ld a,h
	xor $60^$70
	ld h,a
	call boss_bg
	ld a,h
	xor $70^$60
	ld h,a
	call .alloc
	ret z
	push hl
	jr .comp
.cache:	; a cached boss-part glyph underneath: compose onto a copy of it
	xor a
	ld (dch_ok),a		; (a cached sprite over another: don't keep)
	push hl
	ld a,h
	and 7
	or CMAP>>8
	ld d,a
	ld e,l
	ld a,(de)
	ld (cl_bgc),a
	ld a,(rpage)
	add a,BK_CACHE
	ld (cl_bgb),a
	ld a,h
	xor $60^$78
	ld h,a
	ld a,(hl)		; SHK
	and $F0
	ld (cl_pap),a
	pop hl
	call .alloc
	ret z
	push hl
	jr .comp
.over253:			; a ready-made bullet piece: draw as if open
	xor a
	ld (hl),a
.new:	call .alloc
	ret z
	ld c,(hl)		; background code
	ld a,h
	xor $70^$58
	ld h,a
	ld a,(hl)		; background bank
	or a
	jr nz,.slow
	ld a,c
	cp BLANK_CODE
	jr nz,.slow
	; ---- open space: copy the sprite column straight in
	ld a,h
	xor $58^$70
	ld h,a
	push hl
	ld de,(pool_dst)
	ld hl,(ds_src)
	call fcell_copy
	pop de
	ld c,0			; black paper
	jr .q
.slow:	; ---- over scenery: (background AND mask) OR data, its paper colour
	ld (cl_bgb),a
	ld a,c
	ld (cl_bgc),a
	ld a,h
	xor $58^$78
	ld h,a
	ld a,(hl)		; SHK
	and $F0
	ld (cl_pap),a
	res 3,h
	push hl
.comp:	ld de,(pool_dst)
	call bg_fetch		; background glyph straight into the pool glyph
	ld de,(pool_dst)
	call ovl		; and the sprite over it
	pop de
	ld a,(cl_pap)
	ld c,a
	jr .q
.alloc:	; HL = CSLOT address: take the next pool slot -> NZ, HL = SHC address
	ld a,(caching)
	or a
	jr z,.al
	ld (hl),254		; a cached glyph: not a pool slot
	jr .alc
.al:	ld a,(pool_slot)
	cp 255
	ret z			; pool full
	inc a
	ld (hl),a		; slot + 1
	ld (pool_slot),a
.alc:	ld a,h
	xor $60^$70
	ld h,a
	or 1
	ret
.q:	; DE = SHC address, C = paper: on to the page, address listed
	ex de,hl
	ld a,(cl_ink)
	or c
	ld c,a
	ld a,(pool_bank)
	ld b,a
	ld a,(pool_code)
	call scrput
	; next pool glyph
	ld hl,(pool_dst)
	ld de,16
	add hl,de
	ld (pool_dst),hl
	ld hl,pool_code
	inc (hl)
	ret nz
	ld (hl),$80		; into the page's second pool bank
	ld hl,PCGWIN
	ld (pool_dst),hl
	ld a,(pool_bank)
	inc a
	ld (pool_bank),a
	or LV_SCREEN
	out (P_LV),a
	ret

; background glyph (cl_bgb bank, cl_bgc code) from the mirror block -> BGBUF
bg_fetch:	; (cl_bgb bank, cl_bgc code) from the mirror -> glyph at DE
	ld a,(cl_bgb)
	add a,a
	add a,a
	add a,a			; bank*8 = high byte of bank*2048
	ld h,a
	ld a,(cl_bgc)
	and $7F
	ld l,a
	rrca
	rrca
	rrca
	rrca
	and $07
	add a,h
	ld h,a
	ld a,l
	rlca
	rlca
	rlca
	rlca
	and $F0
	ld l,a
	MEMV BLK_MIRROR
	REPT 16
	ldi
	ENDR
	MEMV BLK_WORK
	ret


; overlay the current sprite column onto the glyph at DE in place:
; (glyph AND mask) OR data on the sprite's lines only (52 T a line)
ovl:	ld a,(ds_st)
	ld c,0			; zt
	or a
	jp p,.p
	neg
	ld c,a
.p:	ld a,16
	sub c
	ld b,a			; room in the cell
	ld a,(ds_st)
	or a
	jp p,$+5
	xor a			; s0
	ld l,a
	ld a,(ds_h)
	sub l			; lines left in the sprite
	cp b
	jr nc,$+3
	ld b,a			; n
	ld a,b
	or a
	ret z
	ld a,e
	add a,c
	ld e,a			; first line drawn
	; entry: ovl_end - 13 per pair of lines (+7 for an odd count, which
	; starts on the second half of a pair)
	ld a,b
	inc a
	srl a			; pairs
	ld c,a
	add a,a
	add a,c
	add a,a
	add a,a
	add a,c			; 13 * pairs
	bit 0,b
	jr z,$+4
	sub 7			; odd: in at the second half
	ld c,a
	ld a,ovl_end&255
	sub c
	ld l,a
	ld a,ovl_end>>8
	sbc a,0
	ld h,a
	ld (.go+1),hl
	; the data is popped two lines at a time; the mask is read through HL
	ld hl,(ds_src)
	ld (ovl_sp),sp
	bit 0,b
	jr z,.ev
	dec hl			; odd: line 0 arrives in B
	ld sp,hl
	inc hl
	ld a,(ds_h)
	add a,l
	ld l,a
	jr nc,$+3
	inc h			; mask
	pop bc
	jp .go
.ev:	ld sp,hl
	ld a,(ds_h)
	add a,l
	ld l,a
	jr nc,$+3
	inc h			; mask
.go:	jp ovl_end
ovl_chain:
	REPT 8
	pop bc			; 10
	ld a,(de)		; 7
	and (hl)		; 7
	or c			; 4
	ld (de),a		; 7
	inc e			; 4
	inc hl			; 6
	ld a,(de)
	and (hl)
	or b
	ld (de),a
	inc e
	inc hl			; = 80 per pair
	ENDR
ovl_end:
	ld sp,(ovl_sp)
	ret
ovl_sp	dw 0

; the cell already has a pool glyph this frame (A = slot+1), HL = its
; CSLOT address
cell_over:
	ld (co_addr),hl
	sub 2			; (A = CSLOT + 1 = slot + 2)
	ld c,a			; slot
	rlca
	and 1
	ld b,a
	ld a,(poolbase)
	add a,b
	or LV_SCREEN
	out (P_LV),a
	ld a,c
	and $7F
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,PCGWIN
	add hl,de
	ex de,hl
	call ovl		; the sprite over the glyph, in place
	ld a,(pool_bank)
	or LV_SCREEN
	out (P_LV),a
	xor a
	ld (dch_ok),a		; (caching: this cell can't be kept)
	; the sprite on top gives the cell its ink
	ld hl,(co_addr)
	ld a,h
	or $F8			; CSLOT 60-67 -> colour RAM F8-FF
	ld h,a
	ld a,COL_ON
	out (P_COLCTL),a
	ld a,(hl)
	and $F0
	ld b,a
	ld a,(cl_ink)
	or b
	ld (hl),a
	xor a
	out (P_COLCTL),a
	ret
co_addr	dw 0

; HL = SHC address: A = code, B = bank, C = colour onto the page, and the
; address into the page's restore list (keeps HL)
scrput:	push hl
	set 7,h
	ld (hl),a
	ld a,LV_ATTR
	out (P_LV),a
	ld (hl),b
	ld a,(pool_bank)
	or LV_SCREEN
	out (P_LV),a
	set 3,h
	ld a,COL_ON
	out (P_COLCTL),a
	ld (hl),c
	xor a
	out (P_COLCTL),a
	pop de
	ld hl,(qptr)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (qptr),hl
	ld hl,qcount
	inc (hl)
	ex de,hl
	ret

; ---------------------------------------------------------------------
;  remember how many cells this page's restore list holds
; ---------------------------------------------------------------------
apply_queue:	; (16-bit: the list can pass 255 cells)
	ld hl,(qptr)
	ld de,(qbase)
	or a
	sbc hl,de
	srl h
	rr l
	ld a,(rpage)
	or a
	jr nz,.b
	ld (qnA),hl
	ret
.b:	ld (qnB),hl
	ret

; ---- enemy bullet (VZ bul2): B = x+32, C = y+16
; Over open space a bullet needs no composing: the font bank holds a
; ready-made glyph for each piece of each position (bultab), written
; straight to the page (CSLOT = 253: a sprite drawn on top later treats the
; cell as open space). Anywhere else it is drawn as a sprite.
bul2:	ld (bf_bc),bc
	ld a,(frame)
	and 2
	ld e,a			; 0 / 2
	rrca
	add a,SP_EBUL0
	ld (bf_spr),a
	ld a,e
	add a,a
	add a,a			; frame * 8
	ld e,a
	ld a,b
	and 1
	add a,a
	add a,a			; x offset * 4
	add a,e
	ld e,a
	ld a,c
	and 3
	add a,e			; entry
	add a,a
	add a,a
	add a,a
	ld e,a
	ld d,0
	ld hl,bultab
	add hl,de
	ld (bf_tab),hl
	ld a,b
	srl a
	sub 16
	ld (bf_col),a
	ld a,c
	srl a
	srl a
	sub 4
	ld (bf_row),a
	; every piece over open space?
	xor a
.p1:	push af
	call bf_addr
	jr z,.n1
	ld a,h
	xor $70^$60
	ld h,a
	ld a,(hl)		; CSLOT
	or a
	jr nz,.spr
	ld a,h
	xor $60^$58
	ld h,a
	ld a,(hl)		; SHA
	or a
	jr nz,.spr
	ld a,h
	xor $58^$70
	ld h,a
	ld a,(hl)		; SHC
	cp BLANK_CODE
	jr nz,.spr
.n1:	pop af
	inc a
	cp 4
	jr c,.p1
	; yes: the ready-made pieces
	xor a
.p2:	push af
	call bf_addr
	jr z,.n2
	ld a,d
	ld c,e
	ld b,BK_FONT
	call scrput
	ld a,h
	xor $70^$60
	ld h,a
	ld (hl),253
.n2:	pop af
	inc a
	cp 4
	jr c,.p2
	ret
.spr:	pop af
	ld bc,(bf_bc)
	ld a,(bf_spr)
	jp drawspr

; piece A (0..3: row-major 2 x 2) of the current bullet -> NZ with
; HL = SHC address, D = code, E = ink; Z if there is none or it is clipped
bf_addr:
	ld (bf_k),a
	add a,a
	ld e,a
	ld d,0
	ld hl,(bf_tab)
	add hl,de
	ld a,(hl)
	or a
	ret z
	ld d,a
	inc hl
	ld e,(hl)
	push de
	ld a,(bf_k)
	and 1
	ld hl,bf_col
	add a,(hl)
	cp SCOLS
	jr nc,.clip
	ld e,a
	ld a,(bf_k)
	srl a
	ld hl,bf_row
	add a,(hl)
	cp PROWS
	jr nc,.clip
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld d,0
	add hl,de
	ld de,(pstart)
	add hl,de
	ld a,h
	and 7
	or $70
	ld h,a
	pop de
	or a			; NZ
	ret
.clip:	pop de
	xor a
	ret
bf_bc	dw 0
bf_tab	dw 0
bf_spr	db 0
bf_col	db 0
bf_row	db 0
bf_k	db 0

; ---------------------------------------------------------------------
;  HUD: two rows (64 cells each) at the bottom of the page just shown.
;  The page moved since it was last shown, so codes and colours are
;  rewritten; the attributes (all font bank) only need the entering cell.
; ---------------------------------------------------------------------
hud_put:
	ld hl,(dispstart)
	ld a,(rpage)		; (the page just shown is the one last rendered)
	or a
	ld de,(hudlastA)
	jr z,$+6
	ld de,(hudlastB)
	push hl
	or a
	sbc hl,de
	pop de			; DE = this start
	ld a,(rpage)
	or a
	jr nz,.b
	ld (hudlastA),de
	jr .c
.b:	ld (hudlastB),de
.c:	ld a,h
	or l
	ld (hp_same),a		; 0 = not moved
	; ring address of HUD cell 0, cells before the ring wraps
	ld hl,HUDROW*64
	add hl,de
	ld a,h
	and 7
	ld h,a
	ld (hp_a),hl
	ex de,hl
	ld hl,$0800
	or a
	sbc hl,de
	ld a,h
	or a
	ld a,128
	jr nz,.n
	ld a,l
	cp 128
	jr c,.n
	ld a,128
.n:	ld (hp_n1),a
	ld a,(hp_same)
	or a
	jr nz,.mv
	ld a,(hudall)
	or a
	jr nz,.mv
	; not moved, nothing new - but the last HUD cell is shared with the
	; other page's first cell when the pages are a column apart, so
	; it is put back every time
	ld hl,(hp_a)
	ld de,127
	add hl,de
	ld a,h
	and 7
	or $F0
	ld h,a
	ld a,(HUDC+127)
	ld (hl),a
	ld a,LV_ATTR
	out (P_LV),a
	ld (hl),BK_FONT
	ld a,LV_SCREEN
	out (P_LV),a
	set 3,h
	ld a,COL_ON
	out (P_COLCTL),a
	ld a,(HUDK+127)
	ld (hl),a
	xor a
	out (P_COLCTL),a
	ret
.mv:	ld hl,HUDC
	ld a,$F0
	call .copy
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,HUDK
	ld a,$F8
	call .copy
	xor a
	out (P_COLCTL),a
	ld a,LV_ATTR
	out (P_LV),a
	ld a,(hudall)
	or a
	jr z,.one
	dec a
	ld (hudall),a
	ld hl,HUDA
	ld a,$F0
	call .copy
	jr .x
.one:	ld hl,(hp_a)		; the entering cell (127)
	ld de,127
	add hl,de
	ld a,h
	and 7
	or $F0
	ld h,a
	ld (hl),BK_FONT
.x:	ld a,LV_SCREEN
	out (P_LV),a
	ret
.copy:	; HL = source (128), A = window high byte
	ld (hp_w),a
	ld de,(hp_a)
	or d
	ld d,a
	ld a,(hp_n1)
	call ldin
	ld a,(hp_n1)
	cp 128
	ret z
	ld c,a
	ld a,128
	sub c
	ld c,a
	ld a,(hp_w)
	ld d,a
	ld e,0
	ld a,c
; copy A (1-128) bytes HL -> DE with an unrolled LDI chain (16 T a byte)
ldin:	push hl
	push de
	ld l,a
	ld h,0
	add hl,hl
	ex de,hl
	ld hl,ldin_end
	or a
	sbc hl,de		; entry
	pop de
	ex (sp),hl
	ret			; into the chain
ldin_chain:
	REPT 128
	ldi
	ENDR
ldin_end:
	ret
hp_a	dw 0
hp_n1	db 0
hp_w	db 0
hp_same	db 0

; HUD content changed: both pages get it in full
hud_diff:
	ld a,2
	ld (hudall),a
	ret

; ---- sprite drawing variables
ds_h	db 0
ds_row0	db 0
ds_nk	db 0
ds_k	db 0
ds_ra	dw 0
ds_st	db 0
ds_src	dw 0
cl_ink	db 0
cl_bgb	db 0
cl_bgc	db 0
cl_pap	db 0
pool_dst dw 0
pool_code db 0
pool_bank db 0
pool_slot db 0
poolbase db 0
qbase	dw 0
qcount	db 0
qslot0	db 0
caching	db 0
fc_addr	dw 0
