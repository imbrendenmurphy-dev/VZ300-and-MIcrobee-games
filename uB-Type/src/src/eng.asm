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
	ld a,(qnA)
	jr z,$+8
	ld hl,QB
	ld a,(qnB)
	ld (qbase),hl
	ld (qptr),hl
	push af
	call stars_hide
	pop af
	or a
	ret z
	ld (rs_n),a
	ld hl,(qbase)
	; pass 1: screen codes, clear the slot marks
	ld b,a
.p1:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	inc hl
	inc hl
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
	; pass 2: attributes
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,(qbase)
	ld a,(rs_n)
	ld b,a
.p2:	ld e,(hl)
	inc hl
	ld a,(hl)
	inc hl
	inc hl
	inc hl
	inc hl
	xor $70^$58
	ld d,a
	ld a,(de)		; SHA
	ld c,a
	ld a,d
	xor $58^$F0
	ld d,a
	ld a,c
	ld (de),a
	djnz .p2
	ld a,(pool_bank)
	or LV_SCREEN
	out (P_LV),a
	; pass 3: colours
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,(qbase)
	ld a,(rs_n)
	ld b,a
.p3:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	inc hl
	inc hl
	inc hl
	set 3,d
	ld a,(de)		; SHK
	set 7,d
	ld (de),a
	djnz .p3
	xor a
	out (P_COLCTL),a
	ret
rs_n	db 0

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
.nbf:	; shadows + screen codes
	ld de,colbuf
	ld b,PROWS
.w1:	ld a,(de)		; code
	inc de
	ld (hl),a		; SHC
	set 7,h
	ld (hl),a		; screen
	ld a,h
	xor $F0^$58
	ld h,a
	ld a,(de)		; bank
	inc de
	ld (hl),a		; SHA
	ld a,h
	xor $58^$78
	ld h,a
	ld a,(de)		; colour
	inc de
	ld (hl),a		; SHK
	res 3,h			; back to SHC
	ld a,l
	add a,64
	ld l,a
	jr nc,.n1
	inc h
	res 3,h
.n1:	djnz .w1
	; attributes
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,(cw_addr)
	ld de,colbuf+1
	ld b,PROWS
.w2:	set 7,h
	ld a,(de)
	ld (hl),a
	res 7,h
	inc de
	inc de
	inc de
	ld a,l
	add a,64
	ld l,a
	jr nc,.n2
	inc h
	res 3,h
.n2:	djnz .w2
	ld a,(pool_bank)
	or LV_SCREEN
	out (P_LV),a
	; colours
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,(cw_addr)
	ld de,colbuf+2
	ld b,PROWS
.w3:	set 7,h
	set 3,h
	ld a,(de)
	ld (hl),a
	inc de
	inc de
	inc de
	res 7,h
	res 3,h
	ld a,l
	add a,64
	ld l,a
	jr nc,.n3
	inc h
	res 3,h
.n3:	djnz .w3
	xor a
	out (P_COLCTL),a
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
	ld (ds_x),bc		; (C = y, B = x)
	bit 0,b
	jr z,.v0
	ld de,5
	add hl,de
	ld a,(hl)
.v0:	ld (ds_w),a
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (ds_dat),de
	ld e,(hl)
	inc hl
	ld d,(hl)		; colour table
	ld a,(ix+10)
	ld (ds_h),a
	ld a,(ix+11)
	ld (ds_h2),a
	; colour table for this vertical offset: + yo*hcm
	ld a,c
	and 3
	ld (ds_yo),a
	jr z,.y0
	ld l,a
	xor a
.ym:	add a,(ix+12)
	dec l
	jr nz,.ym
	add a,e
	ld e,a
	jr nc,.y0
	inc d
.y0:	ld (ds_ct),de
	; columns: first one on screen, clip both sides
	ld a,(ds_x+1)
	srl a
	sub 16			; col0
	jp p,.c0
	neg			; clipped on the left: j0 = -col0
	ld (ds_j0),a
	xor a
	jr .c1
.c0:	ld c,a
	xor a
	ld (ds_j0),a
	ld a,c
.c1:	cp SCOLS
	jp nc,.out		; wholly off the right-hand side
	ld (ds_sc0),a
	ld c,a
	ld a,SCOLS
	sub c
	ld c,a			; room on the right
	ld a,(ds_j0)
	ld l,a
	ld a,(ds_w)
	sub l
	jp c,.out
	jp z,.out
	cp c
	jr c,$+3
	ld a,c
	ld (ds_jn),a
	; left clip: skip j0 columns of data and colour
	ld a,l
	or a
	jr z,.nj
	ld b,a
	ld hl,(ds_dat)
	ld e,(ix+11)
	ld d,0
.jm:	add hl,de
	djnz .jm
	ld (ds_dat),hl
	ld a,(ds_j0)
	ld b,a
	ld hl,(ds_ct)
	ld e,(ix+13)
.cm:	add hl,de
	djnz .cm
	ld (ds_ct),hl
.nj:	ld a,(ix+13)
	ld (.cs+1),a
	; rows
	ld a,(ds_x)
	srl a
	srl a
	sub 4
	ld (ds_row0),a
	ld a,(ds_yo)
	add a,a
	add a,a
	ld (ds_yo4),a
	ld c,a
	ld a,(ix+10)		; H
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
.krow:	ld a,(ds_row0)
	ld hl,ds_k
	add a,(hl)
	jp m,.knext
	cp PROWS
	jp nc,.out
	; SHC address of the first cell drawn on this row
	rrca
	rrca			; row*64: high bits in A, low in carry chain
	ld l,a
	and $3F
	ld h,a
	ld a,l
	and $C0
	ld l,a			; HL = row*64
	ld a,(ds_sc0)
	add a,l
	ld l,a
	ld de,(pstart)
	add hl,de
	res 3,h
	ld (ds_ra),hl
	; first sprite line in this cell: st = 16k - 4yo
	ld a,(ds_k)
	add a,a
	add a,a
	add a,a
	add a,a
	ld hl,ds_yo4
	sub (hl)
	ld (ds_st),a
	ld c,0			; zt
	jr nc,.pos
	neg			; k = 0, yo > 0: blank lines on top
	ld c,a
	xor a
.pos:	ld (ds_s0),a		; s0
	ld e,a
	ld a,(ds_h)
	sub e			; lines left in the sprite
	ld b,a
	ld a,16
	sub c			; room in the cell
	cp b
	jr c,$+3
	ld a,b			; n
	ld b,a
	ld a,16
	sub c
	sub b			; zb
	; patch the fill/copy entries from the aligned tables
	add a,a
	ld l,a
	ld h,ZENT>>8
	ld a,(hl)
	inc l
	ld h,(hl)
	ld l,a
	ld (cell.zb+1),hl
	ld a,c
	add a,a
	ld l,a
	ld h,ZENT>>8
	ld a,(hl)
	inc l
	ld h,(hl)
	ld l,a
	ld (cell.zt+1),hl
	ld a,b
	add a,a
	add a,LENT-ZENT
	ld l,a
	ld h,ZENT>>8
	ld a,(hl)
	inc l
	ld h,(hl)
	ld l,a
	ld (cell.ld+1),hl
	; first column: source = dat + s0, colour = ct + k
	ld hl,(ds_dat)
	ld a,(ds_s0)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ex de,hl		; DE = source
	ld hl,(ds_ct)
	ld a,(ds_k)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	push hl
	pop iy			; IY = colour entry
	ld a,(ds_jn)
	ld b,a
	ld hl,(ds_ra)
.jcol:	ld a,(iy+0)
	inc a
	jr z,.jsk		; FFh: nothing in this cell
	dec a
	push bc
	push de
	push hl
	call cell
	pop hl
	pop de
	pop bc
.jsk:	inc hl
	res 3,h
	ld a,(ds_h2)
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
.knext:	ld a,2
	call sndsvc
	ld hl,ds_k
	inc (hl)
	ld a,(ds_nk)
	cp (hl)
	jp nz,.krow
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
	xor a
.zt:	call zfill_end
	ld hl,(ds_src)
.ld:	call ldi_end
	xor a
.zb:	call zfill_end
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
.comp:	call bg_fetch
	ld de,(pool_dst)
	call compose
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
.q:	; queue entry: SHC address, code, bank, colour
	ld a,(caching)
	or a
	jr nz,.qn
	ld a,(pool_slot)
	dec a
	ld l,a
	ld h,SLOTQ>>8
	ld a,(qcount)
	ld (hl),a		; slot -> its queue entry
.qn:	ld hl,(qptr)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld a,(pool_code)
	ld (hl),a
	inc hl
	ld a,(pool_bank)
	ld (hl),a
	inc hl
	ld a,(cl_ink)
	or c
	ld (hl),a
	inc hl
	ld (qptr),hl
	ld hl,qcount
	inc (hl)
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
bg_fetch:
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
	ld de,BGBUF
	REPT 16
	ldi
	ENDR
	MEMV BLK_WORK
	ret

; BGBUF + sprite column -> PCG at DE (a glyph: 16-aligned). Cell lines
; 0..zt-1 and zt+n..15 keep the background; lines zt.. show (background
; AND mask) OR data. The sprite lines run through an unrolled chain
; entered n lines from its end (56 T-states a line).
compose:
	ld a,(ds_st)
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
	ld b,a			; n = min(room, left)
	ld a,b
	ld (cp_n),a
	; background above the sprite
	ld a,c
	or a
	jr z,.nt
	push bc
	ld b,0
	ld hl,BGBUF
	ldir
	pop bc
.nt:	ld a,b
	or a
	jr z,.bot0
	push iy
	; chain entry: cmp_end - 10n
	add a,a
	ld l,a
	add a,a
	add a,a
	add a,l			; 10n
	ld l,a
	ld a,cmp_end&255
	sub l
	ld l,a
	ld a,cmp_end>>8
	sbc a,0
	ld h,a
	ld (.go+1),hl
	; pointers: BC background, HL mask, HL' data, DE' destination
	ld a,c
	add a,BGBUF&255
	ld c,a
	ld b,BGBUF>>8
	ld hl,(ds_src)
	push hl
	push de
	ld a,(ds_h)
	ld e,a
	ld d,0
	add hl,de
	exx
	pop de
	pop hl
	exx
.go:	call cmp_end
	exx
	push de
	exx
	pop de
	ld h,b
	ld l,c			; background below
	pop iy
	jr .bot
.bot0:	ld hl,BGBUF
	ld a,c
	add a,l
	ld l,a
.bot:	ld a,e
	and 15
	ret z
	neg
	add a,16
	ld c,a
	ld b,0
	ldir
	ret
cmp_chain:
	REPT 16
	ld a,(bc)
	inc c
	and (hl)
	inc hl
	exx
	or (hl)
	inc hl
	ld (de),a
	inc e
	exx
	ENDR
cmp_end:
	ret
cp_n	db 0

; the cell already has a pool glyph this frame (A = slot+1)
cell_over:
	dec a
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
	push hl
	ld de,BGBUF
	REPT 16
	ldi
	ENDR
	pop de
	push ix
	call compose
	pop ix
	ld a,(pool_bank)
	or LV_SCREEN
	out (P_LV),a
	xor a
	ld (dch_ok),a		; (caching: this cell can't be kept)
	; the sprite on top gives the cell its colour: entry = qbase + 5*n + 4
	ld l,c
	ld h,SLOTQ>>8
	ld l,(hl)		; n = this slot's queue entry
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,hl
	add hl,de
	ld de,(qbase)
	add hl,de
	inc hl
	inc hl
	inc hl
	inc hl
	ld a,(hl)
	and $F0
	ld b,a
	ld a,(cl_ink)
	or b
	ld (hl),a
	ret

; ---------------------------------------------------------------------
;  write the queued cells to the page: codes, attributes, colours
; ---------------------------------------------------------------------
apply_queue:
	ld a,(qcount)
	ld b,a
	ld a,(rpage)
	or a
	ld a,b
	jr nz,.b
	ld (qnA),a
	jr .c
.b:	ld (qnB),a
.c:	or a
	ret z
	ld (aq_n),a
	ld hl,(qbase)
.p1:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	set 7,d
	ld a,(hl)
	ld (de),a
	inc hl
	inc hl
	inc hl
	djnz .p1
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,(qbase)
	ld a,(aq_n)
	ld b,a
.p2:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	set 7,d
	inc hl
	ld a,(hl)
	ld (de),a
	inc hl
	inc hl
	djnz .p2
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,(qbase)
	ld a,(aq_n)
	ld b,a
.p3:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	set 7,d
	set 3,d
	inc hl
	inc hl
	ld a,(hl)
	ld (de),a
	inc hl
	djnz .p3
	xor a
	out (P_COLCTL),a
	ret
aq_n	db 0

; ---- enemy bullet (VZ bul2): B = x+32, C = y+16
bul2:	ld a,(frame)
	and 2
	ld a,SP_EBUL0
	jr z,$+3
	inc a
	jp drawspr

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
	ret z			; not moved, nothing new
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
	ld c,a
	ld b,0
	ldir
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
	ldir
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
ds_w	db 0
ds_h	db 0
ds_h2	db 0
ds_hcm	db 0
ds_dat	dw 0
ds_ct	dw 0
ds_yo	db 0
ds_yo4	db 0
ds_sc0	db 0
ds_j0	db 0
ds_jn	db 0
ds_row0	db 0
ds_nk	db 0
ds_k	db 0
ds_ra	dw 0
ds_st	db 0
ds_s0	db 0
ds_x	dw 0
ds_zb	db 0
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
