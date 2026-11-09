; =====================================================================
;  RENDER: the playfield is a real bitmap - every playfield cell of a page
;  has its own PCG glyph. Glyph column gc (0-63) holds world byte-column
;  wc where wc & 63 = gc. Two pages (screen RAM 000h / 400h, PCG banks
;  0-5 / 6-11) are drawn in turn and shown with the 6545 start address.
;  Sprites are drawn straight into the hidden page's glyphs; the next time
;  that page is drawn they are wiped by copying the world bitmap back over
;  the rows they touched (which also brings in any terrain changes).
;  Cells a sprite touches get the sprite's ink colour (the paper is kept);
;  they are listed and put back the next time.
; =====================================================================

; per-page data block (PAGE0 / PAGE1, 256-aligned)
PG_DIRTY	equ 0		; 64 x (ymin, ymax) by glyph column
PG_SCT		equ 128		; 64 x (bank port, address lo, hi, gc*2) by screen column
PG_CST		equ 384		; 640 cell states: b0 sprite now, b1 sprite shown, b2 redo
PG_RT		equ 1024	; 64 x 8: restore (bank port, PCG column lo hi, world column lo hi)
PG_DLIST	equ 1536	; dirty glyph columns (64), then their count
PG_DN		equ 1600
PG_SIZE		equ 2048

render_init:
	ld ix,COLBASE
	ld b,0			; gc
.cb:	ld a,b
	ld c,0
.m12:	cp 12
	jr c,.m12d
	sub 12
	inc c
	jr .m12
.m12d:	push af			; A = gc mod 12, C = gc / 12
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld e,l
	ld d,h
	add hl,hl
	add hl,hl
	add hl,de		; x160
	ld de,PCGWIN
	add hl,de
	ld (ix+0),l
	ld (ix+1),h
	inc ix
	inc ix
	ld hl,BANKP		; page 0 at +0, page 1 at +64
	ld e,b
	ld d,0
	add hl,de
	ld a,c
	or LV_SCREEN
	ld (hl),a
	ld de,64
	add hl,de
	add a,BK_PAGE1
	ld (hl),a
	ld hl,ATTRS		; page 0 at +0 (twice), page 1 at +128 (twice)
	ld e,b
	ld d,0
	add hl,de
	ld (hl),c
	ld de,64
	add hl,de
	ld (hl),c
	add hl,de
	ld a,c
	add a,BK_PAGE1
	ld (hl),a
	add hl,de
	ld (hl),a
	pop af			; CODES: $80 + (gc mod 12) * 10 + row
	ld c,a
	add a,a
	add a,a
	add a,c
	add a,a
	or $80
	ld c,a
	ld hl,CODES
	ld e,b
	ld d,0
	add hl,de
	ld de,64
	push bc
	ld b,PFROWS
.cr:	ld (hl),c
	add hl,de
	ld (hl),c
	add hl,de
	inc c
	djnz .cr
	pop bc
	inc b
	ld a,b
	cp 64
	jp nz,.cb
	ld ix,WCADDR		; wc * 160
	ld hl,WBMP
	ld de,160
	ld b,128
.wa:	ld (ix+0),l
	ld (ix+1),h
	inc ix
	inc ix
	add hl,de
	djnz .wa
	; fall through
; forget both pages (nothing loaded, no dirt, no colour lists)
render_reset:
	ld a,255
	ld (pscroll),a
	ld (pscroll+1),a
	ld hl,PAGE0
	ld de,PAGE0+1
	ld bc,PG_SIZE*2-1
	ld (hl),0
	ldir
	ld a,255
	ld (crmin),a
	ld (crmin+1),a
	xor a
	ld (crmax),a
	ld (crmax+1),a
	ld hl,PAGE0
	call .nd
	ld hl,PAGE1
.nd:	ld b,64
.d:	ld (hl),255
	inc hl
	ld (hl),0
	inc hl
	djnz .d
	ret

; A = page -> IX = its data block (A kept)
page_ix:
	ld ix,PAGE0
	or a
	ret z
	ld ix,PAGE1
	ret

; A = page: every cell state cleared (its colours are the world's)
clear_cst:
	push af
	call page_ix
	push ix
	pop hl
	ld de,PG_CST
	add hl,de
	ld d,h
	ld e,l
	inc de
	ld bc,639
	ld (hl),0
	ldir
	pop af
	ld e,a
	ld d,0
	ld hl,crmin
	add hl,de
	ld (hl),255
	ld hl,crmax
	add hl,de
	ld (hl),0
	ret

; ---------------------------------------------------------------------
;  bring page (rpage) to the view scroll (vscroll)
; ---------------------------------------------------------------------
scroll_sync:
	ld a,(rpage)
	ld e,a
	ld d,0
	ld hl,pscroll
	add hl,de
	ld a,(vscroll)
	ld c,a			; target
	ld a,(hl)
	cp c
	ret z
	ld (hl),c
	ld b,a			; old
	MEMV BLK_WORLD
	ld a,b
	cp 255
	jr z,.all
	ld a,c
	sub b
	jr c,.left
	cp 64
	jr nc,.all
	ld e,a			; right: load wc = old+64 .. new+63
	ld a,b
	add a,64
	jr .load
.left:	neg
	cp 64
	jr nc,.all
	ld e,a			; left: load wc = new .. old-1
	ld a,c
	jr .load
.all:	ld e,64
	ld a,c
.load:
.ll:	push de
	push af
	call vschk
.snd5:	SND 30
	pop af
	push af
	call load_col		; (A = the world column)
	pop af
	pop de
	inc a
	dec e
	jr nz,.ll
	call make_sct
	jp write_codes

; A = world column wc: copy it into the rendered page's glyph column wc&63
load_col:
	ld c,a
	and 63
	ld b,a			; gc
	ld a,(rpage)
	call page_ix
	ld hl,BANKP
	or a
	jr z,.p0
	ld hl,BANKP+64
.p0:	ld e,b
	ld d,0
	add hl,de
	ld a,(hl)
	out (P_LV),a
	ld a,b
	add a,a
	ld e,a
	add ix,de
	ld (ix+PG_DIRTY),255
	ld (ix+PG_DIRTY+1),0
	ld hl,COLBASE
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)		; DE = glyph column
	ld l,c
	ld h,0
	add hl,hl
	ld bc,WCADDR
	add hl,bc
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a			; HL = world column
	ld bc,160
	ldir
	ret

; the screen-column table of page (rpage): bank port, address, gc*2
make_sct:
	ld a,(rpage)
	call page_ix
	ld hl,BANKP
	or a
	jr z,.p0
	ld hl,BANKP+64
.p0:	ld (ms_bp),hl
	ld de,PG_SCT
	add ix,de
	ld e,a
	ld d,0
	ld hl,pscroll
	add hl,de
	ld c,(hl)		; scroll
	ld b,64
.l:	ld a,c
	and 63
	ld e,a
	ld d,0
	ld hl,(ms_bp)
	add hl,de
	ld a,(hl)
	ld (ix+0),a
	ld a,e
	add a,a
	ld (ix+3),a
	ld e,a
	ld hl,COLBASE
	add hl,de
	ld a,(hl)
	ld (ix+1),a
	inc hl
	ld a,(hl)
	ld (ix+2),a
	inc ix
	inc ix
	inc ix
	inc ix
	inc c
	djnz .l
	; restore table by gc: port, PCG column, world column now shown there
	ld a,(rpage)
	call page_ix
	ld de,PG_RT
	add ix,de
	ld a,(rpage)
	ld e,a
	ld d,0
	ld hl,pscroll
	add hl,de
	ld a,(hl)
	ld (ms_scr),a
	ld b,0			; gc
.r:	ld hl,(ms_bp)
	ld e,b
	ld d,0
	add hl,de
	ld a,(hl)
	ld (ix+0),a
	ld a,b
	add a,a
	ld e,a
	ld hl,COLBASE
	add hl,de
	ld a,(hl)
	ld (ix+1),a
	inc hl
	ld a,(hl)
	ld (ix+2),a
	ld a,(ms_scr)		; wc = scroll + ((gc - scroll) & 63)
	ld c,a
	ld a,b
	sub c
	and 63
	add a,c
	ld l,a
	ld h,0
	add hl,hl
	ld de,WCADDR
	add hl,de
	ld a,(hl)
	ld (ix+3),a
	inc hl
	ld a,(hl)
	ld (ix+4),a
	ld de,8
	add ix,de
	inc b
	ld a,b
	cp 64
	jr nz,.r
	ret

; screen codes, attributes and colours of the rendered page's playfield
write_codes:
	ld a,(rpage)
	add a,a
	add a,a
	or $F0
	ld d,a
	ld e,0			; DE = page's screen RAM
	push de
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,(vscroll)
	and 63
	ld l,a
	ld h,0
	ld bc,CODES
	add hl,bc
	ld a,PFROWS
.sc:	push hl
	ld bc,64
	ldir
	pop hl
	ld bc,128
	add hl,bc
	dec a
	jr nz,.sc
	pop de
	push de
	ld a,LV_ATTR
	out (P_LV),a
	ld a,(rpage)
	rrca			; x128
	ld l,a
	ld a,(vscroll)
	and 63
	add a,l
	ld l,a
	ld h,0
	ld bc,ATTRS
	add hl,bc
	ld a,PFROWS
.at:	push hl
	ld bc,64
	ldir
	pop hl
	dec a
	jr nz,.at
	ld a,LV_SCREEN
	out (P_LV),a
	pop de
	ld a,d
	or $08			; colour window F800h + page
	ld d,a
	ld a,COL_ON
	out (P_COLCTL),a
	ld a,(vscroll)
	ld l,a
	ld h,0
	ld bc,WCOL
	add hl,bc
	ld a,PFROWS
.co:	push hl
	ld bc,64
	ldir
	pop hl
	ld bc,128
	add hl,bc
	dec a
	jr nz,.co
	xor a
	out (P_COLCTL),a
	ld a,(rpage)		; every colour is the world's again
	jp clear_cst

; ---------------------------------------------------------------------
;  restore: wipe the sprites drawn on this page last time (copy the world
;  back over their rows) and put back the cell colours
; ---------------------------------------------------------------------
restore:
.snd22:	SND 10
	MEMV BLK_WORLD
	ld a,(rpage)
	call page_ix
	ld hl,BANKP
	or a
	jr z,.p0
	ld hl,BANKP+64
.p0:	ld (rs_bank),hl
	ld e,a
	ld d,0
	ld hl,pscroll
	add hl,de
	ld a,(hl)
	ld (rs_scroll),a
	push ix
	pop hl
	ld de,PG_DN
	add hl,de
	ld a,(hl)
	or a
	ret z
	ld (hl),0
	ld b,a
	push ix
	pop hl
	ld de,PG_DLIST
	add hl,de
	ld (rs_dl),hl
.l:	push bc
	ld hl,(rs_dl)
	ld a,(hl)		; gc
	inc hl
	ld (rs_dl),hl
	ld (rs_gc),a
	push ix
	pop hl
	add a,a
	ld e,a
	ld d,0
	add hl,de		; dirty entry
	ld c,(hl)		; ymin
	ld (hl),255
	inc hl
	ld a,(hl)		; ymax
	ld (hl),0
	cp 160
	jr c,.ym
	ld a,159
.ym:	sub c
	jr c,.n
	inc a
	ld (rs_cnt),a
	ld a,c
	cp 160
	jr nc,.n
	ld a,(rs_gc)		; restore entry: IX + PG_RT + gc*8
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	push ix
	pop de
	add hl,de
	ld de,PG_RT
	add hl,de
	ld a,(hl)
	out (P_LV),a
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a			; HL = world column, DE = PCG column
	ld a,c			; + ymin
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,c
	add a,e
	ld e,a
	jr nc,$+3
	inc d
	ld a,(rs_cnt)
	add a,a			; enter the unrolled copy 2*count bytes from its end
	ld c,a
	ld a,0
	adc a,0
	ld b,a
	push hl
	ld hl,ldi_end
	or a
	sbc hl,bc
	ld (.ldj+1),hl
	pop hl
.ldj:	call 0
.n:	call vschk
.snd6:	SND 18
	pop bc
	djnz .l
	ret

; ---------------------------------------------------------------------
;  terrain changes. World byte-column A, rows E..E+1 changed: wipe them on
;  both pages that show that column.
; ---------------------------------------------------------------------
mark_dirty:
	ld c,a			; wc
	ld b,0			; page
.p:	ld hl,pscroll
	ld a,l
	add a,b
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	cp 255
	jr z,.n
	ld d,a
	ld a,c
	sub d
	jr c,.n
	cp 64
	jr nc,.n
	ld a,c
	and 63
	add a,a
	ld l,a
	ld h,0
	push de
	ld de,PAGE0
	ld a,b
	or a
	jr z,.p0
	ld de,PAGE1
.p0:	add hl,de
	pop de
	ld a,(hl)
	inc a
	call z,dl_add
	ld a,e
	cp (hl)
	jr nc,.m1
	ld (hl),a
.m1:	inc hl
	inc a
	cp (hl)
	jr c,.n
	ld (hl),a
.n:	inc b
	ld a,b
	cp 2
	jr nz,.p
	ret

; a world cell's colour changed: world column A, cell row D (0-9):
; flag the cell on both pages (if shown) to be rewritten from the world
mark_colour:
	push ix
	call .go
	pop ix
	ret
.go:	ld c,a
	ld b,0
.p:	push bc
	ld hl,pscroll
	ld a,l
	add a,b
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	cp 255
	jr z,.n
	ld e,a
	ld a,c
	sub e
	jr c,.n
	cp 64
	jr nc,.n
	ld e,a			; screen column
	ld a,d			; cell = row*64 + col
	rrca
	rrca
	ld l,a
	and $C0
	or e
	ld e,a
	ld a,l
	and 3
	push de
	ld d,a
	ld a,b
	call page_ix
	push ix
	pop hl
	add hl,de
	ld de,PG_CST
	add hl,de
	set 2,(hl)
	pop de
	ld e,b			; extend the page's row range
	ld b,0
	ld c,e
	ld hl,crmin
	add hl,bc
	ld a,d
	cp (hl)
	jr nc,.r1
	ld (hl),a
.r1:	ld hl,crmax
	add hl,bc
	cp (hl)
	jr c,.n
	ld (hl),a
.n:	pop bc
	inc b
	ld a,b
	cp 2
	jr nz,.p
	ret

; ---------------------------------------------------------------------
;  sprites. Each frame in its bank: 8 words (one data block per pixel
;  shift); a data block is: columns, height, then per column: first row,
;  rows, then (AND mask, OR data) pairs, top to bottom.
;  in: HL = frame index entry (bank, address), BC = x of the frame's left
;  edge (signed, screen pixels), E = y of its top + 32.
;  The cells touched get ink (sprink) (0 = leave the colours alone).
;  render_begin must have been called for the page.
; ---------------------------------------------------------------------
draw_sprite:
	ld a,e
	ld (ds_y32),a
	ld a,(hl)		; bank
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)		; DE = frame's shift table
	call map_blk
	ld a,c
	and 7
	add a,a
	ld l,a
	ld h,0
	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a			; HL = data block
	sra b
	rr c
	sra b
	rr c
	sra b
	rr c			; BC = first byte column (signed)
	ld a,(hl)
	inc hl
	ld (ds_cols),a
	ld (ds_ncol),a
	ld e,(hl)		; height
	inc hl
	; all on the screen? columns 0..63 and rows 0..159
	ld a,b
	or a
	jp nz,ds_slow
	ld a,(ds_cols)
	add a,c
	cp 65
	jp nc,ds_slow
	ld a,(ds_y32)
	sub 32
	jp c,ds_slow
	ld d,a			; top
	add a,e
	cp 161
	jp nc,ds_slow
	; fast path. IY = screen column entry, D = top
	ld a,c
	ld (ds_sc),a
	add a,a
	add a,a
	ld c,a
	ld b,0
	ld iy,(ds_sct)
	add iy,bc
	ld a,d
	ld (ds_ybase),a
	ld (ds_ymin),a		; colour rows: the frame's whole height
	add a,e
	dec a
	ld (ds_ymax),a
ds_fcol:
	ld a,(hl)		; first row
	inc hl
	ld c,(hl)		; rows
	inc hl
	inc c
	dec c
	jr z,ds_fnext0
	ld b,a
	ld a,(ds_ybase)
	add a,b
	ld b,a			; B = y
	ld (ds_ptr),hl
	; dirty range of the glyph column: (ds_dhi):gc*2
	ld a,(ds_dhi)
	ld h,a
	ld l,(iy+3)
	ld a,(hl)
	inc a
	call z,dl_add		; first dirt in this column on this page
	ld a,b
	cp (hl)
	jr nc,.d1
	ld (hl),a
.d1:	inc l
	add a,c
	dec a
	cp (hl)
	jr c,.d2
	ld (hl),a
.d2:	ld a,(iy+0)
	out (P_LV),a
	ld a,(iy+1)		; PCG address = column + y
	add a,b
	ld l,a
	ld a,(iy+2)
	adc a,0
	ld h,a
	ld a,c			; blit entry
	add a,a
	ld e,a
	ld d,BLITENT>>8
	ld a,(de)
	ld (.jmp+1),a
	inc e
	ld a,(de)
	ld (.jmp+2),a
	di
	ld (sp_save),sp
	ld sp,(ds_ptr)
.jmp:	jp 0
ds_fnext:
.snd8:	call vschk
	SND 27
	ld hl,(ds_ptr)
ds_fnext0:
	inc iy
	inc iy
	inc iy
	inc iy
	ld a,(ds_cols)
	dec a
	ld (ds_cols),a
	jr nz,ds_fcol
	; colours: cells rows ymin>>4 .. ymax>>4, columns sc .. sc+cols-1
	ld a,(sprink)
	or a
	ret z
	ld a,(ds_ymin)
	cp 255
	ret z
	jp ds_colrect

blit_rows:
	REPT 32
	pop bc
	ld a,(hl)
	and c
	or b
	ld (hl),a
	inc hl
	ENDR
blit_end:
	ld (ds_ptr),sp
	ld sp,(sp_save)
	ei
	ld a,(ds_slowf)
	or a
	jp z,ds_fnext
	jp ds_slow.next

; mark the cell rectangle of the sprite just drawn (state b0)
ds_colrect:
	ld a,(ds_ymin)
	rrca
	rrca
	rrca
	rrca
	and 15
	ld d,a			; first row
	ld hl,dr_min
	cp (hl)
	jr nc,.m1
	ld (hl),a
.m1:	ld a,(ds_ymax)
	rrca
	rrca
	rrca
	rrca
	and 15
	ld hl,dr_max
	cp (hl)
	jr c,.m2
	ld (hl),a
.m2:	sub d
	inc a
	ld c,a			; rows
	ld a,d			; cell = row*64 + sc
	rrca
	rrca
	ld l,a
	and $C0
	ld e,a
	ld a,(ds_sc)
	or e
	ld e,a
	ld a,l
	and 3
	ld d,a
	ld hl,(ds_page)
	add hl,de
	ld de,PG_CST
	add hl,de
	ld de,64
.r:	push hl
	ld a,(ds_ncol)
	ld b,a
.c:	set 0,(hl)
	inc hl
	djnz .c
	pop hl
	add hl,de
	dec c
	jr nz,.r
	ret

; general path, with clipping (sprites at the screen's edges)
ds_slow:
	ld (ds_x),bc
	ld a,1
	ld (ds_slowf),a
	ld a,255
	ld (ds_ymin),a
	xor a
	ld (ds_ymax),a
	ld a,(ds_cols)
	ld (ds_ncol),a
	ld a,c
	ld (ds_sc0),a
.col:	ld b,(hl)		; first row
	inc hl
	ld a,(hl)		; rows
	inc hl
	ld (ds_ptr),hl
	ld c,a
	add a,a
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld (ds_next),hl
	ld a,c
	or a
	jp z,.skip
	ld a,(ds_x+1)
	or a
	jp nz,.skip
	ld a,(ds_x)
	cp 64
	jp nc,.skip
	ld (ds_sc),a
	ld a,(ds_y32)
	add a,b
	sub 32
	jr nc,.ntop
	neg
	ld b,a
	ld a,c
	sub b
	jp c,.skip
	jp z,.skip
	ld c,a
	ld hl,(ds_ptr)
	ld a,b
	add a,a
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld (ds_ptr),hl
	xor a
.ntop:	cp 160
	jp nc,.skip
	ld b,a
	add a,c
	sub 160
	jr c,.nbot
	ld e,a
	ld a,c
	sub e
	jp z,.skip
	ld c,a
.nbot:	ld a,(ds_sc)
	add a,a
	add a,a
	ld e,a
	ld d,0
	ld iy,(ds_sct)
	add iy,de
	ld a,(ds_dhi)
	ld h,a
	ld l,(iy+3)
	ld a,(hl)
	inc a
	call z,dl_add
	ld a,b
	cp (hl)
	jr nc,.d1
	ld (hl),a
.d1:	inc l
	add a,c
	dec a
	cp (hl)
	jr c,.d2
	ld (hl),a
.d2:	ld hl,ds_ymax
	cp (hl)
	jr c,.d3
	ld (hl),a
.d3:	ld a,b
	ld hl,ds_ymin
	cp (hl)
	jr nc,.d4
	ld (hl),a
.d4:	ld a,(iy+0)
	out (P_LV),a
	ld a,(iy+1)
	add a,b
	ld l,a
	ld a,(iy+2)
	adc a,0
	ld h,a
	ld a,c
	add a,a
	ld e,a
	ld d,BLITENT>>8
	ld a,(de)
	ld (.jmp+1),a
	inc e
	ld a,(de)
	ld (.jmp+2),a
	di
	ld (sp_save),sp
	ld sp,(ds_ptr)
.jmp:	jp 0
.next:
.snd11:	SND 32
.skip:	ld hl,(ds_x)
	inc hl
	ld (ds_x),hl
	ld hl,(ds_next)
	ld a,(ds_cols)
	dec a
	ld (ds_cols),a
	jp nz,.col
	xor a
	ld (ds_slowf),a
	; colours: clipped rectangle
	ld a,(sprink)
	or a
	ret z
	ld a,(ds_ymin)
	cp 255
	ret z
	; columns visible: from max(sc0,0) to min(sc0+n,64)-1
	ld a,(ds_sc0)
	ld b,a
	ld a,(ds_ncol)
	ld c,a
	ld a,(ds_x+1)		; (ds_x is now one past the last column)
	or a
	jr z,.cpos
	ret
.cpos:	ld a,b			; first column (signed byte)
	bit 7,a
	jr z,.c0
	add a,c			; columns left from 0
	ret m
	ret z
	ld c,a
	xor a
.c0:	ld b,a
	add a,c
	cp 65
	jr c,.c1
	ld a,64
	sub b
	ret c
	ret z
	ld c,a
.c1:	ld a,b
	ld (ds_sc),a
	ld a,c
	ld (ds_ncol),a
	jp ds_colrect

; colours: scan the rows that may have sprite cells (now or last time)
; or cells to redo, and rewrite the colours that change
apply_colours:
	MEMV BLK_WORLD
	ld a,(rpage)
	ld e,a
	ld d,0
	ld hl,crmin
	add hl,de
	ld a,(dr_min)
	ld c,a
	ld a,(hl)
	cp c
	jr c,.a1
	ld a,c
.a1:	ld (ac_r0),a
	ld a,(dr_min)		; the page's range becomes this frame's
	ld (hl),a
	ld hl,crmax
	add hl,de
	ld a,(dr_max)
	ld c,a
	ld a,(hl)
	cp c
	jr nc,.a2
	ld a,c
.a2:	ld (ac_r1),a
	ld a,(dr_max)
	ld (hl),a
	ld a,(ac_r0)
	cp 10
	ret nc			; nothing
	ld a,(sprink)
	ld (ac_ink),a
	ld a,COL_ON
	out (P_COLCTL),a
.row:	call vschk
.snd7:	SND 49
	ld a,(ac_r0)
	ld b,a
	ld a,(ac_r1)
	cp b
	jr c,.done
	; HL = states of the row, row's colour screen address and world address
	ld a,b
	rrca
	rrca
	ld c,a
	and $C0
	ld e,a
	ld a,c
	and 3
	ld d,a			; DE = row*64
	ld hl,(ds_page)
	add hl,de
	push de
	ld de,PG_CST
	add hl,de
	pop de
	ld a,(rpage)
	add a,a
	add a,a
	or $F8
	or d
	ld d,a
	ld (ac_scr),de
	ld a,b			; world: WCOL + row*128 + scroll
	rrca
	and $80
	ld e,a
	ld a,b
	srl a
	add a,WCOL>>8
	ld d,a
	ld a,(rs_scroll)
	add a,e
	ld e,a
	ld (ac_wld),de
	ld b,64
.cell:	ld a,(hl)
	or a
	jr nz,.some
.nx:	inc hl
	djnz .cell
	ld hl,ac_r0
	inc (hl)
	jr .row
.done:	xor a
	out (P_COLCTL),a
	ret
.some:	; state: b0 now, b1 shown, b2 redo
	ld c,a
	and 1
	add a,a
	ld (hl),a		; new state: shown = now
	ld a,c
	bit 2,a
	jr nz,.wr
	rrca			; b0 vs b1
	xor c
	and 1
	jr z,.nx
.wr:	push hl
	ld a,64
	sub b
	ld l,a
	ld h,0
	ld de,(ac_wld)
	add hl,de
	ld a,(hl)		; world colour
	bit 0,c
	jr z,.w1
	and $F0
	ld e,a
	ld a,(ac_ink)
	or e
.w1:	ld e,a
	ld a,64
	sub b
	ld l,a
	ld h,0
	push de
	ld de,(ac_scr)
	add hl,de
	pop de
	ld (hl),e
	pop hl
	jr .nx

; set up the per-page pointers for drawing sprites on (rpage)
render_begin:
	ld a,(rpage)
	call page_ix
	ld (ds_page),ix
	ld (ds_dirty),ix
	ld a,255
	ld (dr_min),a
	xor a
	ld (dr_max),a
	ld a,ixh
	ld (ds_dhi),a
	ld a,(rpage)
	ld de,PG_SCT
	add ix,de
	ld (ds_sct),ix
	ld e,a
	ld d,0
	ld hl,pscroll
	add hl,de
	ld a,(hl)
	ld (rs_scroll),a
	ret

; blit entry points by row count (n -> blit_end - 7n)
	ALIGN 256
BLITENT:
	dw blit_end-0
	dw blit_end-6
	dw blit_end-12
	dw blit_end-18
	dw blit_end-24
	dw blit_end-30
	dw blit_end-36
	dw blit_end-42
	dw blit_end-48
	dw blit_end-54
	dw blit_end-60
	dw blit_end-66
	dw blit_end-72
	dw blit_end-78
	dw blit_end-84
	dw blit_end-90
	dw blit_end-96
	dw blit_end-102
	dw blit_end-108
	dw blit_end-114
	dw blit_end-120
	dw blit_end-126
	dw blit_end-132
	dw blit_end-138
	dw blit_end-144
	dw blit_end-150
	dw blit_end-156
	dw blit_end-162
	dw blit_end-168
	dw blit_end-174
	dw blit_end-180
	dw blit_end-186
	dw blit_end-192

; 160 LDIs (restore copies one column's rows with these)
ldi_rows:
	REPT 160
	ldi
	ENDR
ldi_end:
	ret

; HL = a clean dirty entry (page block + gc*2): list its gc on that page
; (keeps all registers but AF)
dl_add:	push hl
	push de
	ld a,l
	rra			; gc (page blocks are 2K aligned: L = gc*2)
	and 63
	ld e,a
	ld a,h
	and $F8			; page block
	ld h,a
	ld l,0
	push hl
	ld a,e
	ld de,PG_DN
	add hl,de
	ld e,(hl)		; count
	inc (hl)
	pop hl
	ld d,0
	push af
	ld a,e
	ld de,PG_DLIST
	add hl,de
	ld e,a
	ld d,0
	add hl,de
	pop af
	ld (hl),a
	pop de
	pop hl
	ret
