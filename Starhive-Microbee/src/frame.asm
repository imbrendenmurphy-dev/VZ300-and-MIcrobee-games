; =====================================================================
;  FRAME: dynamic cells (sprites drawn into PCG), double-buffered
;  pools, the restore list.
;
;  Every cell a sprite touches gets a slot in this frame's pool (page A
;  = PCG banks 8-9, page B = banks 10-11, 255 slots each), composed
;  straight into the page not on display. A new slot starts as the
;  scenery glyph under it (RAM mirror) with the sprite masked and ORed
;  in: the sprite's outline mask clears the scenery around it. The cell
;  takes the sprite column's colour over the scenery's paper (black in
;  open space). At vertical blank the screen cells are pointed at the
;  new glyphs and the cells sprites have left are put back.
;
;  List entry (4 bytes, slot order): ring offset (2), colour, row.
; =====================================================================

NSLOT	equ 255

; ---------------------------------------------------------------------
;  start composing a frame (WORK mapped): clear the previous frame's
;  marks, make it the old list
; ---------------------------------------------------------------------
frame_begin:
	ld hl,(listold)		; the list committed last frame becomes old
	ld de,(listcur)
	ld (listold),de
	ld (listcur),hl
	ld (nextent),hl
	ld a,(nslot)
	ld (nold),a
	or a
	jr z,.e
	ld b,a
	ex de,hl		; HL = old list (= the last frame's)
.c:	ld e,(hl)
	inc hl
	ld a,(hl)
	or $60			; CSL
	ld d,a
	xor a
	ld (de),a
	inc hl
	inc hl
	inc hl
	djnz .c
.e:	xor a
	ld (nslot),a
	ld (nedges),a
	ret

; ---------------------------------------------------------------------
;  draw a sprite: DE = x + 16 (pixels), C = y + 16 (window lines),
;  HL = frame in SPRLIB. WORK must be mapped.
;  Frame: wb, h, flags, 0, block size (2), then 8 shifted blocks: wb
;  (first line, end line, colour) per column, then wb columns x h lines
;  x (mask, gfx).
; ---------------------------------------------------------------------
spr_draw:
	ld a,c
	ld (sd_y),a
	ld a,(hl)
	ld (sd_wb),a
	inc hl
	ld a,(hl)
	ld (sd_h),a
	add a,a
	ld (sd_h2),a
	inc hl
	inc hl
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)		; BC = block size
	inc hl			; HL = block 0
	ld a,e
	and 7
	jr z,.s0
.sh:	add hl,bc
	dec a
	jr nz,.sh
.s0:	ld (sd_bnd),hl
	ld a,(sd_wb)
	ld b,a
	add a,a
	add a,b			; 3 * wb
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld (sd_data),hl
	; first playfield column = x / 8 - 2 (signed)
	srl d
	rr e
	srl d
	rr e
	srl d
	rr e
	ld a,e
	sub 2
	ld (sd_cx),a
	; first display row and line: t = y + 16 - k
	ld a,(fineK)
	ld b,a
	ld a,(sd_y)
	sub b
	ret c			; too far above the window
	ld l,a
	ld h,0
	ld de,rowt
	add hl,de
	ld a,(hl)
	ld (sd_row),a
	inc h			; offt = rowt + 256
	ld a,(hl)
	ld (sd_j),a
	ld a,(sd_h)
	ld (sd_n),a
	xor a
	ld (sd_i2),a		; sprite line * 2 at the top of this row
	; ---- one cell row at a time
.row:	ld a,(sd_j)
	ld c,a
	ld a,CL
	sub c
	ld b,a
	ld a,(sd_n)
	cp b
	jr nc,.f
	ld b,a			; lines in this row
.f:	ld a,b
	ld (sd_rn),a
	ld a,(sd_row)
	cp EROW1+1
	ret nc			; below the window
	cp EROW0
	call nc,spr_row
	ld a,(sd_rn)
	ld b,a
	add a,a
	ld hl,sd_i2
	add a,(hl)
	ld (hl),a
	xor a
	ld (sd_j),a
	ld hl,sd_row
	inc (hl)
	ld a,(sd_n)
	sub b
	ld (sd_n),a
	jr nz,.row
	ret

; the sprite's columns in one cell row: sprite lines sd_i2/2 .. + sd_rn,
; drawn from line sd_j of each cell. The row's constants are patched
; into the code (self-modifying) so the column loop stays tight.
spr_row:
	call vschk
	ld a,(sd_row)
	ld (.rowv+1),a
	ld c,a
	call ring_row
	ld a,l
	ld (.rlo+1),a
	ld a,h
	ld (.rhi+1),a
	ld a,(page)
	add a,a
	add a,BK_POOLA|LV_SCREEN
	ld (.pgb+1),a
	ld (.pgo+1),a
	; edge row?
	ld a,c
	cp EROW0
	jr z,.ise
	cp EROW1
.ise:	ld a,0
	jr nz,.nedge
	inc a
.nedge:	ld (.flg+1),a
	; lines: first sprite line i0, end i1, first cell line j0
	ld a,(sd_i2)
	rrca
	ld (.i0+1),a
	ld b,a
	ld a,(sd_rn)
	ld c,a
	add a,b
	ld (.i1+1),a
	ld a,(sd_j)
	ld (.j0+1),a
	ld (.j0o+1),a
	add a,c
	neg
	add a,CL
	ld (.tail+1),a		; lines below the sprite in the cell
	; merge entry points (by line count)
	ld a,c
	add a,a
	ld l,a
	ld h,0
	ld de,mrg_ntab-2
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (.jn+1),de
	ld de,mrg_otab-mrg_ntab-1
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (.jo+1),de
	; source pointer in HL' (column 0, the row's first line), h*2 in DE'
	ld hl,(sd_data)
	ld a,(sd_i2)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(sd_h2)
	ld e,a
	ld d,0
	exx
	ld ix,-2		; the stack pointer during a merge (after the
	add ix,sp		; column loop's PUSH BC), to restore after it
	ld iy,(sd_bnd)
	ld a,(sd_cx)
	ld c,a
	ld a,(sd_wb)
	ld b,a
.col:	ld a,c
	cp SCOLS
	jp nc,.skip		; off the playfield (signed)
.i1:	ld a,0
	cp (iy+0)
	jp z,.skip		; the row ends before the column's first line
	jp c,.skip
.i0:	ld a,0
	cp (iy+1)
	jp nc,.skip		; the row starts after its last line
	ld a,c
.rlo:	add a,0
	ld l,a
.rhi:	ld a,0
	adc a,0
	and 7
	ld e,a			; ring offset high (wrapped)
	or $60
	ld h,a
	ld a,(hl)		; CSL
	or a
	jp z,.new
	; ---- existing slot: recolour its entry, merge in place
	push bc
	dec a
	ld c,a
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	ld de,(listcur)
	add hl,de
	inc hl
	inc hl
	ld a,(hl)
	and $F0
	or (iy+2)
	ld (hl),a
	ld a,c
	rlca
	and 1
.pgo:	add a,0
	out (P_LV),a
	ld a,c
	and $7F
	rrca
	rrca
	rrca
	rrca
	ld l,a
	and $07
	or $F8
	ld h,a
	ld a,l
	and $F0
.j0o:	or 0
	ld l,a			; HL = glyph line j0
	exx
	ld sp,hl
	exx
.jo:	jp 0
.olddone:
	ld sp,ix
	pop bc
	jp .skip
	; ---- new slot: the scenery glyph with the sprite merged in
.new:	push bc
	ld a,(nslot)
	cp NSLOT
	jp nc,.full		; pool full: clipped
	inc a
	ld (nslot),a
	ld (hl),a		; CSL = slot + 1
	dec a
	ld c,a			; slot
	ld d,e			; D = ring offset high
	ld e,l
	ld hl,(nextent)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld a,d
	or $68			; SHK
	ld d,a
	ld a,(de)
	and $F0
	or (iy+2)
	ld (hl),a
	inc hl
.rowv:	ld (hl),0
	inc hl
	ld (nextent),hl
.flg:	ld a,0
	or a
	jr z,.ne
	ld hl,nedges		; edge row: remember the slot
	ld a,(hl)
	inc (hl)
	ld hl,edgeslots
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld (hl),c
.ne:	; mirror glyph = SHA * 2048 + (SHC & 7Fh) * 16
	ld a,d
	xor $68^$78		; SHA
	ld d,a
	ld a,(de)
	add a,a
	add a,a
	add a,a
	ld b,a
	res 3,d			; SHC
	ld a,(de)
	and $7F
	rlca
	rlca
	rlca
	rlca
	ld l,a
	and $07
	add a,b
	ld h,a
	ld a,l
	and $F0
	ld l,a			; HL = mirror glyph
	; destination: the slot's glyph in the hidden page
	ld a,c
	rlca
	and 1
.pgb:	add a,0
	out (P_LV),a
	ld a,c
	and $7F
	rrca
	rrca
	rrca
	rrca
	ld e,a
	and $07
	or $F8
	ld d,a
	ld a,e
	and $F0
	ld e,a
.j0:	ld a,0
	or a
	jr z,.nohead
	ld c,a
	ld b,0
	ldir			; lines above the sprite
.nohead:
	exx
	ld sp,hl
	exx
.jn:	jp 0
.newdone:
	ld sp,ix
.tail:	ld a,0
	or a
	jr z,.full
	ld c,a
	ld b,0
	ldir			; lines below
.full:	pop bc
.skip:	exx			; next column
	add hl,de
	exx
	inc iy
	inc iy
	inc iy
	inc c
	dec b
	jp nz,.col
	ret

; unrolled merges, entered (11 - n) blocks in: SP -> (mask, gfx) pairs
mrg_new:
	REPT CL
	pop bc
	ld a,(hl)
	and c
	or b
	ld (de),a
	inc hl
	inc de
	ENDR
mrg_new_end:
	jp spr_row.newdone
mrg_old:
	REPT CL
	pop bc
	ld a,(hl)
	and c
	or b
	ld (hl),a
	inc hl
	ENDR
mrg_old_end:
	jp spr_row.olddone
mrg_ntab:			; entry for 1..11 lines
	dw mrg_new_end-7,mrg_new_end-14,mrg_new_end-21,mrg_new_end-28
	dw mrg_new_end-35,mrg_new_end-42,mrg_new_end-49,mrg_new_end-56
	dw mrg_new_end-63,mrg_new_end-70,mrg_new_end-77
mrg_otab:
	dw mrg_old_end-6,mrg_old_end-12,mrg_old_end-18,mrg_old_end-24
	dw mrg_old_end-30,mrg_old_end-36,mrg_old_end-42,mrg_old_end-48
	dw mrg_old_end-54,mrg_old_end-60,mrg_old_end-66

; slot C -> its PCG bank in the window, HL = its glyph
slot_pcg:
	ld a,c
	rlca
	and 1
	ld b,a
	ld a,(page)
	add a,a
	add a,BK_POOLA|LV_SCREEN
	add a,b
	out (P_LV),a
	ld a,c
	and $7F
	rrca
	rrca
	rrca
	rrca
	ld l,a
	and $07
	or $F8
	ld h,a
	ld a,l
	and $F0
	ld l,a
	ret

; ---------------------------------------------------------------------
;  after the sprites: cut the slots on the edge rows to the window
;  (row 2 keeps lines 10-k..10, row 23 keeps lines 0..10-k)
; ---------------------------------------------------------------------
edge_slots_mask:
	ld a,(nedges)
	or a
	jr z,.x
	ld b,a
	ld de,edgeslots
.s:	push bc
	push de
	ld a,(de)
	ld c,a			; slot
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	ld de,(listcur)
	add hl,de
	inc hl
	inc hl
	inc hl
	ld a,(hl)		; row
	dec hl
	push af
	ld a,(hl)		; colour: black paper on the edge rows
	and $0F
	ld (hl),a
	call slot_pcg
	pop af
	ld e,a
	ld a,(fineK)
	ld b,a
	ld a,e
	cp EROW0
	jr nz,.b1
	ld a,CL-1		; row 2: clear lines 0 .. 9-k
	sub b
	jr z,.n
	ld b,a
.z0:	ld (hl),0
	inc hl
	djnz .z0
	jr .n
.b1:	ld a,b			; row 23: clear lines 11-k .. 10
	or a
	jr z,.n
	ld a,CL
	sub b
	add a,l
	ld l,a
.z1:	ld (hl),0
	inc hl
	djnz .z1
.n:	pop de
	inc de
	pop bc
	djnz .s
.x:	ld a,LV_SCREEN
	out (P_LV),a
	ret

; ---------------------------------------------------------------------
;  end of composing (WORK mapped): cells sprites have left go back:
;  old entries not drawn this frame. Edge rows go back to their edge
;  glyph. Restore entry: ring offset (2), code, attr, colour.
; ---------------------------------------------------------------------
rest_build:
	ld de,RESTLIST
	xor a
	ld (nrest),a
	ld a,(nold)
	or a
	ret z
	ld b,a
	ld hl,(listold)
.e:	push bc
	ld c,(hl)
	inc hl
	ld b,(hl)		; BC = ring offset
	inc hl
	inc hl
	ld a,(hl)		; its display row last frame
	inc hl
	push hl
	ld hl,stepped
	add a,(hl)		; ... and now
	cp EROW1+1
	jr nc,.keep		; scrolled off: will be prepared afresh
	ld (rb_row),a
	ld a,b
	or $60
	ld h,a
	ld l,c
	ld a,(hl)
	or a
	jr nz,.keep		; still a sprite cell this frame
	ex de,hl		; HL = restore entry
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	ld a,(rb_row)
	cp EROW0
	jr z,.edge
	cp EROW1
	jr z,.edge
	ld a,b
	or $70
	ld d,a
	ld e,c
	ld a,(de)
	ld (hl),a		; code
	inc hl
	set 3,d
	ld a,(de)
	ld (hl),a		; attr
	inc hl
.col:	ld a,b
	or $68
	ld d,a
	ld e,c
	ld a,(de)
	ld (hl),a		; colour
	inc hl
	ex de,hl
	ld hl,nrest
	inc (hl)
.keep:	pop hl
	pop bc
	ld a,b
	and 15
	call z,vschk
	djnz .e
	ret
.edge:	; column = (offset - rowbase[row]) & 7FFh
	push hl
	ld a,(rb_row)
	call ring_row
	ld a,c
	sub l
	ld e,a			; (< 40: only the low byte matters)
	ld d,0
	ld a,(rb_row)
	cp EROW0
	ld hl,eu0
	ld a,G_E0
	jr z,.e0
	ld hl,eu1
	ld a,G_E1
.e0:	add hl,de
	add a,(hl)
	pop hl
	ld (hl),a		; code: the edge glyph
	inc hl
	ld (hl),BK_FIX
	inc hl
	ld a,b			; colour: black paper
	or $68
	ld d,a
	ld e,c
	ld a,(de)
	call edge_colour
	ld (hl),a
	inc hl
	ex de,hl
	ld hl,nrest
	inc (hl)
	jp .keep
rb_row	db 0
