; =====================================================================
;  HUD: one line of text across the top band (display rows 0-1). Each
;  region's text is held in PCG at all 11 scroll phases, each drawn
;  shifted up by k lines so it stays still on screen while the picture
;  slides. When the text changes, its columns are redrawn (hud_render);
;  each frame only the cells' codes change (hud_commit).
;  A HUD cell is (bank, index): code 80h + k * 11 + index.
;  Region: col0, ncols, colour, bitmap (8 bytes a column), cells (2
;  bytes a cell: column-major, row 0 then row 1).
;  The text sits on display lines 13..19 (row 1 at k = 0, row 0 at 10).
; =====================================================================
R_COL0	equ 0
R_NCOL	equ 1
R_COLR	equ 2
R_BMP	equ 3
R_CELLS	equ 5
R_SIZE	equ 7
HUD_T	equ 13

; redraw region IX's columns hd_min..hd_max at all phases
hud_render_all:
	xor a
	ld (hd_min),a
	ld a,(ix+R_NCOL)
	dec a
	ld (hd_max),a
hud_render:
	ld a,(hd_max)
	cp $FF
	ret z			; nothing changed
	ld a,(hd_min)
	ld (hr_c),a
.col:	call vschk		; (keep counting fields: a column is ~5000 T)
	; padded column: 13 clear lines, the 8 text lines, 11 clear
	ld a,(hr_c)
	add a,a
	add a,a
	add a,a
	ld l,(ix+R_BMP)
	ld h,(ix+R_BMP+1)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld de,hr_pad+HUD_T
	ld bc,8
	ldir
	; the column's two cells
	ld a,(hr_c)
	add a,a
	add a,a			; 4 bytes a column
	ld l,(ix+R_CELLS)
	ld h,(ix+R_CELLS+1)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld de,hr_pad
	ld b,2
.cell:	push bc
	ld a,(hl)		; bank
	inc hl
	or LV_SCREEN
	out (P_LV),a
	ld a,(hl)		; index
	inc hl
	push hl
	or $80
	ld c,a			; code at k = 0
	ex de,hl		; HL = source at k = 0
	push hl
	ld b,CL
.ph:	push bc
	push hl
	ld a,c
	call glyph_addr
	ld bc,CL
	ldir
	pop hl
	inc hl			; next phase: one line on
	pop bc
	ld a,c
	add a,CL
	ld c,a
	djnz .ph
	pop hl
	ld de,CL
	add hl,de
	ex de,hl		; DE = source for the next row
	pop hl
	pop bc
	djnz .cell
	ld a,(hr_c)
	inc a
	ld (hr_c),a
	ld hl,hd_max
	cp (hl)
	jp z,.col
	jp c,.col
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,$FF		; clean again
	ld (hd_max),a
	ld (hd_min),a
	ret
hr_c	db 0
hd_min	db $FF
hd_max	db $FF
hr_pad	ds 32

; HUD cells as a flat list: hud_flat = column, row (0/1), index, bank,
; colour (5 bytes); hud_off = each cell's ring offset now.
; hud_place: work out the offsets and write every cell's bank and
; colour (start of a level; the display is off or the rows are new)
hud_place:
	ld ix,hud_flat
	ld iy,hud_off
	ld b,N_HUDC
.c:	push bc
	ld a,(ix+1)		; row
	call ring_row
	ld a,(ix+0)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,h
	and 7
	or $F0
	ld h,a
	ld (iy+0),l
	ld (iy+1),h
	ld a,(ix+2)
	ld (iy+2),a		; index
	ld a,LV_ATTR
	out (P_LV),a
	ld a,(ix+3)
	ld (hl),a		; bank
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	set 3,h
	ld a,(ix+4)
	ld (hl),a		; colour
	xor a
	out (P_COLCTL),a
	ld de,5
	add ix,de
	ld de,3
	add iy,de
	pop bc
	djnz .c
	ret

; after a coarse step (scroll_step, before the commit): every cell moves
; up the ring by a row; the row-0 cells land in the new, hidden row and
; get their bank and colour there. The row-1 cells land where row 0's
; were, which already have the same bank and colour (a column's two
; cells share them), so only codes change at the commit.
hud_step:
	ld ix,hud_flat
	ld hl,hud_off
	ld b,N_HUDC
.c:	ld e,(hl)
	inc hl
	ld d,(hl)		; F0h | high
	ld a,e
	sub SCOLS
	ld e,a
	jr nc,.nb
	dec d
	ld a,d
	and 7
	or $F0
	ld d,a
.nb:	ld (hl),d
	dec hl
	ld (hl),e
	inc hl
	inc hl
	inc hl
	ld a,(ix+1)
	or a
	jr nz,.n		; row 1: nothing more
	ld a,LV_ATTR		; row 0: bank and colour in the new row
	out (P_LV),a
	ld a,(ix+3)
	ld (de),a
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	set 3,d
	ld a,(ix+4)
	ld (de),a
	xor a
	out (P_COLCTL),a
.n:	ld de,5
	add ix,de
	djnz .c
	ret

; at vertical blank: every cell's code for this phase
hud_commit:
	ld a,(fineK)		; k * 11 + 80h
	ld b,a
	add a,a
	add a,a
	add a,b
	add a,a
	add a,b
	add a,$80
	ld c,a
	ld hl,hud_off
	ld b,N_HUDC
.c:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)
	inc hl
	add a,c
	ld (de),a
	djnz .c
	ret

; ---------------------------------------------------------------------
;  print text into a region's bitmap: IX = region, B = column, HL =
;  text (0-terminated). Changed columns are marked for hud_render.
; ---------------------------------------------------------------------
hud_print:
.ch:	ld a,(hl)
	or a
	ret z
	inc hl
	push hl
	push bc
	sub 32
	ld e,a
	ld d,0
	ld hl,font_map
	add hl,de
	ld a,(hl)		; glyph index
	ld l,a
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,hl
	add hl,hl
	or a
	sbc hl,de		; *7
	ld de,font7
	add hl,de
	push hl
	ld a,b			; destination: bmp + column * 8
	add a,a
	add a,a
	add a,a
	ld l,(ix+R_BMP)
	ld h,(ix+R_BMP+1)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ex de,hl
	pop hl
	push hl
	push de
	ld b,7
.cmp:	ld a,(de)
	cp (hl)
	jr nz,.diff
	inc hl
	inc de
	djnz .cmp
	pop de
	pop hl
	jr .same
.diff:	pop de
	pop hl
	ld bc,7
	ldir
	pop bc
	push bc
	ld a,(hd_min)		; take column B into the dirty range
	cp b
	jr c,.minok
	ld a,b
	ld (hd_min),a
.minok:	ld a,(hd_max)
	inc a
	jr z,.set
	dec a
	cp b
	jr nc,.same
.set:	ld a,b
	ld (hd_max),a
.same:	pop bc
	inc b
	pop hl
	jr .ch

; print the 6-digit BCD number at (HL, 3 bytes, high first) with a
; trailing 0 (scores are multiples of 10): IX, B as hud_print
hud_score:
	ld de,numbuf
	ld a,3
.d:	push af
	ld a,(hl)
	rrca
	rrca
	rrca
	rrca
	and 15
	add a,'0'
	ld (de),a
	inc de
	ld a,(hl)
	and 15
	add a,'0'
	ld (de),a
	inc de
	inc hl
	pop af
	dec a
	jr nz,.d
	ld a,'0'
	ld (de),a
	inc de
	xor a
	ld (de),a
	ld hl,numbuf
	jp hud_print

; print the 16-bit number HL as 5 digits: IX, B as hud_print
hud_num5:
	push bc
	ld de,numbuf
	ld bc,-10000
	call .dg
	ld bc,-1000
	call .dg
	ld bc,-100
	call .dg
	ld bc,-10
	call .dg
	ld a,l
	add a,'0'
	ld (de),a
	inc de
	xor a
	ld (de),a
	pop bc
	ld hl,numbuf
	jp hud_print
.dg:	ld a,'0'-1
.dl:	inc a
	add hl,bc
	jr c,.dl
	sbc hl,bc
	ld (de),a
	inc de
	ret
numbuf	ds 10
