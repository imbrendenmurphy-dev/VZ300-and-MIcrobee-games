; =====================================================================
;  SPRITES on the software-scrolled screen (STARHIVE)
;
;  Every cell a sprite touches gets a slot in this frame's pool (page 0
;  = PCG banks 12-13, page 1 = banks 14-15, 255 slots), written into
;  the page not on display. Over black space a cell is 11 bytes copied
;  from the sprite column's pre-shifted strip; over scenery it starts as
;  the pair glyph at the coming phase k (read back from PCG bank k) with
;  the sprite masked and ORed in. Where sprites overlap in a cell, the
;  one drawn last has it.
;
;  Each cell goes into its display row's bucket (address, code, attribute,
;  colour). The commit goes down the rows: last frame's cells in the row
;  put back from the shadows, the row's scenery pass, this frame's cells
;  - all just ahead of the beam.
;
;  WORK block (lower window): bucket sets 0000 and 0B00 (22 rows of 128
;  bytes each, by page), sprite library from 1600, shadows SHK 6800,
;  SHC 7000, SHA 7800 (scenery colour, code, attribute by ring cell).
; =====================================================================

NSLOT	equ 128		; (one bank a page: 12 or 14)
BK_POOL	equ 12
SB0	equ $0000		; 22 buckets of 128 bytes (20 cells) per set
SB1	equ $0B00

; ---------------------------------------------------------------------
;  start a frame: the bucket set of this page emptied
; ---------------------------------------------------------------------
frame_begin:
	xor a
	ld (nslot),a
	ld a,(page)
	add a,a
	add a,BK_POOL
	ld (pgbank),a
	or LV_SCREEN
	ld (sr_dbk),a
	ld hl,PCGWIN
	ld (sr_dst),hl
	ld a,(page)
	or a
	ld hl,SB0+2
	jr z,.s
	ld hl,SB1+2
.s:	ld de,bk_s
	ld b,VROWS
.b:	ld a,l
	ld (de),a
	inc de
	ld a,h
	ld (de),a
	inc de
	ld a,l
	add a,128
	ld l,a
	jr nc,$+3
	inc h
	djnz .b
	ret

; end every bucket of this frame
finish_frame:
	ld hl,bk_s
	ld b,VROWS
.s:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	xor a
	ld (de),a
	inc de
	ld (de),a
	djnz .s
	ret

; both bucket sets empty (at the start)
buckets_clear:
	ld hl,SB0+2
	ld de,128
	ld b,2*VROWS
.c:	ld (hl),0
	inc hl
	ld (hl),0
	dec hl
	add hl,de
	djnz .c
	ret

; ---------------------------------------------------------------------
;  draw a sprite: DE = x + 16 (pixels), C = y + 16 (playfield lines),
;  HL = frame in the sprite library. WORK must be mapped.
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
	ld a,(hl)
	ld (sd_flag),a
	inc hl
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)		; BC = block size
	inc hl			; HL = block 0
	ld a,e
	and 7
	jr z,.s0
	ex af,af'
	ld a,(sd_flag)
	rrca
	jr nc,.s8
	ex af,af'		; even shifts only: block (x & 7) / 2
	srl a
	jr z,.s0
	jr .sh
.s8:	ex af,af'
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
	push de
	ld a,(sd_wb)		; strips = data + wb * 2h; stride h + 22
	ld b,a
	ld a,(sd_h2)
	ld e,a
	ld d,0
.st:	add hl,de
	djnz .st
	ld (sd_strip),hl
	ld a,(sd_h)
	add a,2*CL
	ld l,a
	ld h,0
	ld (sd_sstr),hl
	pop de			; x
	srl d			; first column = x / 8 - 2 (signed)
	rr e
	srl d
	rr e
	srl d
	rr e
	ld a,e
	sub 2
	ld (sd_cx),a
	ld a,(sd_y)
	ld l,a
	ld h,rowt>>8
	ld a,(hl)
	ld (sd_row),a
	inc h			; offt = rowt + 256
	ld a,(hl)
	ld (sd_j),a
	ld a,(sd_row)		; first row: ring offset and bucket pointer
	add a,a
	ld l,a
	ld h,0
	ld de,mul40
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld hl,(scrS)
	add hl,de
	ld (sd_ring),hl
	ld a,(sd_row)
	add a,a
	ld e,a
	ld d,0
	ld hl,bk_s-4
	add hl,de
	ld (sd_bpa),hl
	ld a,(sd_h)
	ld (sd_n),a
	xor a
	ld (sd_i2),a
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
	ret nc			; below the playfield
	cp EROW0
	call nc,spr_row
	call vschk
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
	ld hl,(sd_ring)
	ld de,40
	add hl,de
	ld (sd_ring),hl
	ld hl,(sd_bpa)
	inc hl
	inc hl
	ld (sd_bpa),hl
	ld a,(sd_n)
	sub b
	ld (sd_n),a
	jr nz,.row
	ret

; the sprite's columns in one cell row
spr_row:
	ld hl,(sd_bpa)
	ld (sr_bpa),hl		; this row's bucket pointer
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld (sr_bp),hl
	ld hl,(sd_ring)		; ring offset of the row on the coming frame
	ld a,l
	ld (.rlo+1),a
	ld a,h
	ld (.rhi+1),a
	ld a,(sd_i2)
	rrca
	ld (.i0+1),a
	ld b,a			; i0
	ld a,(sd_rn)
	add a,b
	ld (.i1+1),a
	ld a,(sd_j)		; strips from line 11 + i0 - j
	ld c,a
	ld a,CL
	add a,b
	sub c
	ld e,a
	ld d,0
	ld ix,(sd_strip)
	add ix,de		; IX = strip of column 0
	xor a
	ld (sr_mset),a
	ld hl,(sd_data)		; merge source in HL' (column 0, this row's
	ld a,(sd_i2)		; first line), 2h in DE'
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(sd_h2)
	ld e,a
	ld d,0
	exx
	ld hl,-2		; the stack pointer during a merge (after the
	add hl,sp		; column loop's PUSH BC), to restore after it
	ld (sr_sp),hl
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
	jp z,.skip
	jp c,.skip
.i0:	ld a,0
	cp (iy+1)
	jp nc,.skip
	ld a,(nslot)
	cp NSLOT
	jp nc,.skip		; pool full: clipped
	ld a,(sr_bp)
	and $7F
	cp 128-8
	jp nc,.skip		; row bucket full: clipped
	push bc
	ld a,c
.rlo:	add a,0
	ld e,a
.rhi:	ld a,0
	adc a,0
	and 7
	ld d,a			; DE = ring offset of the cell
	ld (sr_ring),de
	or $78			; SHA
	ld d,a
	ld a,(de)
	cp STAR_BANK
	jp nz,.pair
	; over black space (or a far star, which the sprite hides)
	xor a
	call .entry
	push ix
	pop hl
	REPT CL
	ldi
	ENDR
	jp .done
	; over scenery: the pair glyph at phase k, masked and merged
.pair:	res 3,d			; SHC
	ld a,(de)
	and $7F
	ld c,a
	call .mset
	ld a,(k)
	add a,COLT>>8
	ld h,a
	ld l,c
	ld a,(hl)
	and $F0
	push af
	ld a,(k)
	or LV_SCREEN
	out (P_LV),a
	ld a,c
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
	ld de,sr_bg
	REPT CL
	ldi
	ENDR
	pop af
	call .entry
	ld hl,sr_bg
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
	ld sp,(sr_sp)
.tail:	ld a,0
	or a
	jr z,.done
	ld c,a
	ld b,0
	ldir			; lines below
.done:	pop bc
.skip:	exx			; next column
	add hl,de
	exx
	ld de,(sd_sstr)
	add ix,de
	inc iy
	inc iy
	inc iy
	inc c
	dec b
	jp nz,.col
	ld hl,(sr_bpa)		; the row's bucket pointer
	ld de,(sr_bp)
	ld (hl),e
	inc hl
	ld (hl),d
	ld a,LV_SCREEN
	out (P_LV),a
	ret

; the new cell's bucket entry (A = paper) and its glyph: DE = the glyph,
; its bank in the window; the next slot's glyph moves on
.entry:	ld c,a
	ld a,(iy+2)
	call fold
	or c
	ld c,a
	ld hl,(sr_bp)
	ld de,(sr_ring)
	ld (hl),e
	inc hl
	ld a,d
	or $F0
	ld (hl),a
	inc hl
	ld a,(nslot)
	or $80
	ld (hl),a		; code
	inc hl
	ld a,(sr_dbk)
	and $0F
	ld (hl),a		; attribute: the slot's bank
	inc hl
	ld (hl),c		; colour
	inc hl
	ld (hl),0
	inc hl
	ld (sr_bp),hl
	ld hl,nslot
	inc (hl)
	ld a,(sr_dbk)
	out (P_LV),a
	ld de,(sr_dst)
	ld hl,16
	add hl,de
	ld a,h
	or a
	jr nz,.e1
	ld h,$F8		; past this bank: on to the next
	ld a,(sr_dbk)
	inc a
	ld (sr_dbk),a
.e1:	ld (sr_dst),hl
	ret

; patch the merge code for this row (once)
.mset:	ld a,(sr_mset)
	or a
	ret nz
	inc a
	ld (sr_mset),a
	push bc
	push de
	push hl
	ld a,(sd_j)
	ld (.j0+1),a
	ld b,a
	ld a,(sd_rn)
	ld c,a
	add a,b
	neg
	add a,CL
	ld (.tail+1),a		; lines below the sprite in the cell
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
	pop hl
	pop de
	pop bc
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
mrg_ntab:
	dw mrg_new_end-7,mrg_new_end-14,mrg_new_end-21,mrg_new_end-28
	dw mrg_new_end-35,mrg_new_end-42,mrg_new_end-49,mrg_new_end-56
	dw mrg_new_end-63,mrg_new_end-70,mrg_new_end-77

; ---------------------------------------------------------------------
;  an overlay (bullet or shot): ready-drawn cells, no composing.
;  DE = x + 16, C = y + 16, HL = its table, A = colour, B = PCG bank
; ---------------------------------------------------------------------
; DE = x + 16, C = y + 16, HL = table, A = colour, B = bank
ovl_draw:
	call fold
	ld (ov_col),a
	ld a,b
	ld (ov_bank),a
	ld a,e
	and 6
	rrca			; shift / 2
	ld b,a
	add a,a
	add a,a
	add a,a
	add a,b
	add a,b
	add a,b
	ld b,a			; 11 (shift / 2)
	push hl
	ld l,c
	ld h,rowt>>8
	ld c,(hl)		; row
	inc h
	ld a,(hl)		; line in the cell
	add a,b
	add a,a
	add a,a
	pop hl
	add a,l
	ld l,a
	jr nc,$+3
	inc h			; HL = the four codes
	srl d
	rr e
	srl d
	rr e
	srl d
	rr e
	ld a,e
	sub 2
	ld (ov_col0),a
	ld a,c
	call .row		; top: codes 0, 1
	inc hl
	inc hl
	ld a,c
	inc a			; below: codes 2, 3
.row:	ld b,a
	ld a,(hl)		; nothing in this row of the overlay?
	inc hl
	or (hl)
	dec hl
	ret z
	ld a,b
	cp EROW0
	ret c
	cp EROW1+1
	ret nc
	push bc
	push hl
	ld (ov_row),a
	sub 2			; this row's bucket pointer
	add a,a
	add a,low(bk_s)
	ld e,a
	ld a,high(bk_s)
	adc a,0
	ld d,a
	ld (ov_bpa),de
	ld a,(ov_row)		; ring offset of the row's first column
	add a,a
	ld e,a
	ld d,0
	ld hl,mul40
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld hl,(scrS)
	add hl,de
	ld a,(ov_col0)
	ld e,a
	add a,a
	sbc a,a
	ld d,a
	add hl,de
	ex de,hl		; DE = ring offset of column col0
	pop hl
	push hl
	ld b,2
.c:	ld a,(hl)
	or a
	jr z,.n
	ld (ov_code),a
	ld a,(ov_col0)		; column on the screen?
	add a,2
	sub b
	cp SCOLS
	jr nc,.n
	push hl
	ld hl,(ov_bpa)
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	and $7F
	cp 128-8
	jr nc,.f
	ld (hl),e		; address, code, attribute, colour
	inc l
	ld a,d
	and 7
	or $F0
	ld (hl),a
	inc l
	ld a,(ov_code)
	ld (hl),a
	inc l
	ld a,(ov_bank)
	ld (hl),a
	inc l
	ld a,(ov_col)
	ld (hl),a
	inc l
	inc l
	push de
	ex de,hl
	ld hl,(ov_bpa)
	ld (hl),e
	inc hl
	ld (hl),d
	pop de
.f:	pop hl
.n:	inc hl
	inc de
	djnz .c
	pop hl
	pop bc
	ret

mul40:	dw 0,40,80,120,160,200,240,280,320,360,400,440,480,520,560,600
	dw 640,680,720,760,800,840,880,920
sr_bg:	ds 16

; ---------------------------------------------------------------------
;  the playfield rows (2..23), top first: last frame's sprite cells in
;  the row put back (from the other bucket set; one row up before a
;  coarse step), the scenery pass, then this frame's sprite cells
; ---------------------------------------------------------------------
rows_commit:
	ld a,(lv_work)
	call blkport
	out (P_MEM),a
	ld a,COL_ON
	out (P_COLCTL),a
	ld (spsave),sp
	ld a,(top)
	and 31
	or SEGS>>8
	ld (ps_page),a
	ld a,(page)		; this frame's set; last frame's the other
	or a
	ld hl,SB0+2
	ld de,SB1+2
	jr z,.p0
	ex de,hl
.p0:	ld (ps_bk16),hl
	ld a,(step)		; (one row up before a step)
	or a
	jr z,.p1
	ld hl,-128
	add hl,de
	ex de,hl
.p1:	ld (ps_old16),de
	ld a,VROWS
	ld (ps_n),a
	ld a,(k)
	ld d,a
	add a,COLT>>8
	ld e,a
	ld (ps_de),de
.row:	ld a,(step)		; no old cells for the new top row
	or a
	jr z,.ok
	ld a,(ps_n)
	cp VROWS
	jr z,.r2
.ok:	ld sp,(ps_old16)
.r1:	pop hl			; put back last frame's cells
	bit 7,h
	jr z,.r2
	pop bc
	pop bc
	ld d,h
	ld e,l
	res 7,d			; SHC (F0 -> 70)
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,(de)
	ld (hl),a
	set 3,d			; SHA
	ld a,LV_ATTR
	out (P_LV),a
	ld a,(de)
	ld (hl),a
	res 4,d			; SHK
	ld a,(de)
	set 3,h
	ld (hl),a
	jp .r1
.r2:	ld a,LV_ATTR
	out (P_LV),a
	ld de,(ps_de)
	ld a,(ps_page)
	ld h,a
	ld l,0
	ld sp,hl
.la:	pop hl			; scenery of one colour: the phase bank
	bit 7,h
	jr z,.lb
	ld (hl),d
	jp .la
.lb:	ld a,(ps_page)
	ld h,a
	ld l,$58
	ld sp,hl
.l:	pop hl			; scenery whose colour changes too
	bit 7,h
	jr z,.r3
	pop bc
	ld (hl),d
	ld b,e
	ld a,(bc)
	set 3,h
	ld (hl),a
	jp .l
.r3:	ld sp,(ps_bk16)
.r4:	pop hl			; this frame's sprite cells
	bit 7,h
	jr z,.r5
	pop bc
	pop de
	ld a,LV_SCREEN
	out (P_LV),a
	ld (hl),c
	ld a,LV_ATTR
	out (P_LV),a
	ld (hl),b
	set 3,h
	ld (hl),e
	jp .r4
.r5:	ld hl,(ps_bk16)
	ld de,128
	add hl,de
	ld (ps_bk16),hl
	ld hl,(ps_old16)
	add hl,de
	ld (ps_old16),hl
	ld a,(ps_page)
	dec a
	and 31
	or SEGS>>8
	ld (ps_page),a
	ld hl,ps_n
	dec (hl)
	jp nz,.row
	ld sp,(spsave)
	xor a
	out (P_COLCTL),a
	ld a,LV_SCREEN
	out (P_LV),a
	ret
