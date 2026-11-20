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
	ld hl,frame_id
	inc (hl)
	ld a,(hl)
	ld (spr_draw.cv+1),a
	ld (ovl_draw.cv+1),a
	ld a,$80
	ld (spr_draw.ns+1),a	; no pool slots used yet
	ld a,(page)
	add a,a
	add a,BK_POOL
	ld (pgbank),a
	ld (spr_draw.pb+1),a
	or LV_SCREEN
	ld (sr_dbk),a
	ld hl,PCGWIN
	ld (spr_draw.dst+1),hl
	ld a,(k)		; this frame's merge flag: byte and bit
	ld b,0
	cp 8
	jr c,.f0
	sub 8
	ld b,128
.f0:	ld c,a
	ld a,b
	ld (bg_get.mo+1),a
	ld b,c
	inc b
	ld a,$80
.f1:	rlca
	djnz .f1
	ld (bg_get.mm+1),a
	ld hl,(scrS)		; ring offsets of rows 2..23 (column 0) this
	ld bc,80		; frame
	add hl,bc
	ld c,40
	ld de,ringt+4
.rt:	ld a,l
	ld (de),a
	inc e
	ld a,h
	and 7
	ld (de),a
	inc e
	add hl,bc
	ld a,e
	cp low(ringt)+48
	jr nz,.rt
	ld a,(k)
	add a,COLT>>8
	ld (bg_get.ch+1),a
	ld a,(k)
	or LV_SCREEN
	ld (bg_get.kb+1),a
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
;  draw a sprite: DE = x + 16 (pixels), C = y + 16 (playfield lines, t),
;  HL = frame in the sprite library. WORK must be mapped.
;  Column by column: a column's cells run from the row of its first line
;  to the row of its last (from the frame's bounds), so no empty cell is
;  visited and nothing is set up per row.
; ---------------------------------------------------------------------
spr_draw:
	ld a,c
	ld (sd_y),a
	ld a,(hl)
	ld (sd_wb),a
	ld (sd_n),a		; columns to go
	inc hl
	ld a,(hl)
	ld (sd_h),a
	add a,a
	ld (.h2+1),a		; column stride of the (mask, gfx) lines
	inc hl
	ld a,(hl)
	ld (sd_flag),a
	inc hl
	ld a,(.ns+1)		; room in the pool for its cells at most?
	sub $80			; (slots used; 80h when all are)
	add a,(hl)
	ret c
	cp NSLOT+1
	ret nc
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
.s0:	push hl
	pop iy			; IY: the columns' (first line, end, colour)
	ld a,(sd_wb)
	ld b,a
	add a,a
	add a,b			; 3 wb
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld (sd_data),hl		; column 0's (mask, gfx) lines
	ld a,(sd_h)
	add a,a
	ld c,a
	ld b,0
	ld a,(sd_wb)
.st:	add hl,bc		; strips after wb x 2h
	dec a
	jr nz,.st
	ld bc,CL
	add hl,bc
	ld (sd_strip),hl	; column 0's strip, + 11
	ld a,(sd_h)
	add a,2*CL
	ld (.ss+1),a		; strip stride h + 22
	srl d			; first column = x / 8 - 2 (signed)
	rr e
	srl d
	rr e
	srl d
	rr e
	ld a,e
	sub 2
	ld (sd_cx),a
	ld (.cx0+1),a
	ld a,(sr_dbk)		; the pool's bank in the window
	out (P_LV),a

.col:	ld a,(iy+1)		; end line (0: an empty column)
	or a
	jp z,.cn
	ld a,(sd_cx)
	cp SCOLS
	jp nc,.cn		; off the playfield (signed)
	ld (.cx+1),a
	ld a,(iy+2)
	call fold
	ld (.ccol+1),a		; the column's colour
	ld (.cb+1),a
	ld a,(sd_y)
	ld c,a
	add a,(iy+0)
	ld l,a
	ld h,rowt>>8
	ld b,(hl)		; row of the first line
	ld a,c
	add a,(iy+1)
	dec a
	ld l,a
	ld a,(hl)		; row of the last
	cp EROW1+1
	jr c,.r1
	ld a,EROW1
.r1:	ld d,a
	ld a,b
	cp EROW0
	jr nc,.r0
	ld a,EROW0
.r0:	ld b,a			; B = first row on the playfield
	ld a,d
	sub b
	jp c,.cn
	inc a
	ld (sd_rn),a		; rows to do
	ld a,b			; s0: the sprite line at the cell's top
	add a,a			; = 11 row - 6 - t (signed)
	add a,a
	add a,a
	add a,b
	add a,b
	add a,b
	sub 6
	sub c
	ld e,a			; the strip line for a cell over black
	add a,a
	sbc a,a
	ld d,a
	ld hl,(sd_strip)
	add hl,de
	ld (sd_src),hl
	ld a,b			; the row's bucket pointer's address
	add a,a
	ld l,a
	ld h,(bk_s-4)>>8
	ld (sd_bpa),hl
	dec h			; ring offset of the cell (ringt: this
	ld a,(hl)		; frame's, by row)
	inc l
	ld h,(hl)
	ld l,a
.cx:	ld de,0			; (the column)
	add hl,de
	ld a,h
	and 7
	ld d,a
	ld e,l			; DE = ring offset

.cell:	ld hl,(sd_bpa)		; room in the row's bucket?
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	and $7F
	cp 128-8
	jp nc,.nx
	ld c,e
	ld a,d
	or $60
	ld b,a
.cv:	ld a,0			; covered this frame (the frame's number)
	ld (bc),a
	set 3,b
	set 4,b			; SHA: over black space or scenery?
	ld a,(bc)
	cp STAR_BANK
	jp nz,.pair
	ld (hl),e		; black (or a far star the sprite hides):
	inc l			; its entry ...
	ld a,d
	or $F0
	ld (hl),a
	inc l
.ns:	ld a,$80		; code: the next pool slot
	ld (hl),a
	inc a
	ld (.ns+1),a
	inc l
.pb:	ld (hl),0		; attribute: the pool's bank
	inc l
.cb:	ld (hl),0		; colour: the column's
	inc l
	inc l
	push de
	ex de,hl
	ld hl,(sd_bpa)
	ld (hl),e
	inc hl
	ld (hl),d
.dst:	ld de,0			; ... and 11 lines of the column's strip
	ld hl,(sd_src)		; into the slot's glyph
	REPT CL
	ldi
	ENDR
	ld (sd_src),hl
	ld a,e
	add a,16-CL
	ld e,a
	jr nc,$+3
	inc d
	ld (.dst+1),de
	pop de
.nx:	ld hl,40		; the next row
	add hl,de
	ld a,h
	and 7
	ld d,a
	ld e,l
	ld hl,(sd_bpa)
	inc hl
	inc hl
	ld (sd_bpa),hl
	ld hl,sd_rn
	dec (hl)
	jp nz,.cell
.cn:	call vsq		; the next column
	ld bc,3
	add iy,bc
	ld hl,(sd_strip)
.ss:	ld bc,0
	add hl,bc
	ld (sd_strip),hl
	ld hl,sd_cx
	inc (hl)
	ld hl,sd_n
	dec (hl)
	jp nz,.col
	ld a,LV_SCREEN
	out (P_LV),a
	ret

	; over scenery: the background (bg_get), the sprite's lines masked
	; and ORed in where the column has them
.pair:	ld (.bp+1),hl		; (the bucket)
	res 3,b			; SHC: the pair's slot
	ld a,(bc)
	and $7F
	ld c,a
	push de
	call bg_get		; the background, A = paper
	pop de
	push de
	call .entry		; DE = the glyph
	ld hl,(sd_src)		; s0 = the sprite line at the cell's top
	ld bc,(sd_strip)
	or a
	sbc hl,bc
	ld a,l
	ld c,a			; lines a..b of the sprite are in this cell:
				; a = max(s0, first), b = min(s0 + 11, end)
	ld b,(iy+0)
	bit 7,a
	jr nz,.pa
	cp b
	jr nc,.pb0
.pa:	ld a,b
.pb0:	ld (.al+1),a
	sub c
	ld (.hd+1),a		; lines above (the background)
	ld a,c
	add a,CL
	cp (iy+1)
	jr c,.pbm
	ld a,(iy+1)
.pbm:	ld b,a
.al:	ld a,0
	ld c,a
	ld a,b
	sub c			; n = b - a
	ld b,a
	add a,a			; jump into the merges: 7 bytes a line
	add a,a
	add a,a
	sub b
	ld c,a
	ld a,low(.me)
	sub c
	ld (.jn+1),a
	ld a,high(.me)
	sbc a,0
	ld (.jn+2),a
	ld a,(.hd+1)		; lines below
	add a,b
	neg
	add a,CL
	ld (.tl+1),a
	ld a,(sd_cx)		; the column's (mask, gfx) lines from line a:
.cx0:	sub 0			; data + column x 2h + 2a
	ld hl,(sd_data)
	jr z,.dc
.h2:	ld bc,0
.dm:	add hl,bc
	dec a
	jr nz,.dm
.dc:	ld a,(.al+1)
	add a,a
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	push hl
	pop ix
	ld hl,sr_bg
.hd:	ld a,0
	or a
	jr z,.nh
	ld c,a
	ld b,0
	ldir
.nh:	ld (sd_sp),sp
	ld sp,ix
.jn:	jp 0
	REPT CL			; (mask, gfx) by POP
	pop bc
	ld a,(hl)
	and c
	or b
	ld (de),a
	inc hl
	inc de
	ENDR
.me:	ld sp,(sd_sp)
.tl:	ld a,0
	or a
	jr z,.nt
	ld c,a
	ld b,0
	ldir
.nt:	ld hl,(sd_src)		; (keep the black cells' line in step)
	ld bc,CL
	add hl,bc
	ld (sd_src),hl
	pop de
	jp .nx

; the new cell's bucket entry (A = paper, DE = its ring offset) and its
; glyph: -> DE = the glyph, the pool's bank in the window; the next
; slot's glyph moves on
.entry:	ld c,a
.ccol:	ld a,0			; (the column's colour)
	or c
.fd:	call fold		; (patched to CP 0 / NOP while monochrome is off)
	ld c,a
.bp:	ld hl,0			; this row's bucket
	ld (hl),e		; address
	inc l
	ld a,d
	or $F0
	ld (hl),a
	inc l
	ld a,(.ns+1)		; code
	ld (hl),a
	inc a
	ld (.ns+1),a
	inc l
	ld a,(.pb+1)		; attribute
	ld (hl),a
	inc l
	ld (hl),c		; colour
	inc l
	inc l
	ex de,hl
	ld hl,(sd_bpa)
	ld (hl),e
	inc hl
	ld (hl),d
	ld hl,(.dst+1)		; DE = the slot's glyph; the next one moves on
	ld d,h
	ld e,l
	ld bc,16
	add hl,bc
	ld (.dst+1),hl
	ret

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
	ld (ov_col0),a		; first column (signed)
	ld a,c
	ld (ov_row),a
	push hl
	add a,a			; the row's bucket pointer's address
	add a,low(bk_s-4)
	ld l,a
	ld a,high(bk_s-4)
	adc a,0
	ld h,a
	ld (ov_bpa),hl
	ld a,c			; ring offset of the row's first column
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
	ex de,hl		; DE = ring offset
	pop hl
	ld a,(ov_row)
	call .row		; top: codes 0, 1
	inc hl
	inc hl
	ex de,hl
	ld bc,40
	add hl,bc
	ex de,hl
	ld bc,(ov_bpa)
	inc bc
	inc bc
	ld (ov_bpa),bc
	ld a,(ov_row)
	inc a			; below: codes 2, 3
	ld (ov_row),a
.row:	cp EROW0		; A = row, HL -> its two codes, DE = ring
	ret c			; offset of the first column
	cp EROW1+1
	ret nc
	ld a,(hl)		; nothing in this row of the overlay?
	inc hl
	or (hl)
	dec hl
	ret z
	push hl
	push de
	ld b,(hl)
	inc hl
	ld c,(hl)		; B, C = the codes
	ld hl,(ov_bpa)
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a			; HL = the row's bucket
	and $7F
	cp 128-14		; room for two (else clipped)
	jr nc,.rx
	ld a,(ov_col0)
	cp SCOLS
	ld a,b
	call c,.cell
	inc de
	ld a,(ov_col0)
	inc a
	cp SCOLS
	ld a,c
	call c,.cell
	ex de,hl
	ld hl,(ov_bpa)
	ld (hl),e
	inc hl
	ld (hl),d
.rx:	pop de
	pop hl
	ret
.cell:	or a			; A = code (0: none), DE = ring offset,
	ret z			; HL = bucket (moves on)
	ld (ov_code),a
	push bc
	push de
	ld (hl),e		; address
	inc l
	ld a,d
	and 7
	ld d,a
	or $F0
	ld (hl),a
	inc l
	push hl
	ld a,d
	or $60
	ld h,a
	ld l,e
.cv:	ld (hl),0		; covered this frame
	or $78			; SHA: over scenery?
	ld d,a
	ld a,(de)
	cp STAR_BANK
	jr z,.pl
	call ovl_merge		; yes: a composed cell (A = code, C = colour)
	jr c,.pl
	ld b,a
	ld a,(pgbank)
	jr .wr
.pl:	ld a,(ov_col)		; no: the ready-drawn cell
	ld c,a
	ld a,(ov_code)
	ld b,a
	ld a,(ov_bank)
.wr:	pop hl
	ld (hl),b		; code
	inc l
	ld (hl),a		; attribute
	inc l
	ld (hl),c		; colour
	inc l
	inc l
	pop de
	pop bc
	ret

; an overlay cell over scenery: the pair glyph at phase k (slot from
; SHC) with the overlay's pixels set, into the next pool slot, in the
; overlay's ink on the scenery's paper. DE = the cell's SHA address.
; -> A = code, C = colour; carry if the pool is full. HL kept.
ovl_merge:
	ld a,(spr_draw.ns+1)	; (wraps to 0 when all 128 are used)
	cp $80
	ret c
	push hl
	res 3,d			; SHC: the pair's slot
	ld a,(de)
	and $7F
	ld c,a
	call bg_get		; the background into sr_bg, A = paper
	ld b,a
	ld a,(ov_col)
	and $0F
	or b
	call fold
	ld (ov_scol),a		; the overlay's ink on that paper
	ld a,(ov_bank)
	or LV_SCREEN
	out (P_LV),a
	ld a,(ov_code)
	and $7F
	call .gl
	ld de,sr_bg		; its pixels set, the detail cleared a pixel
	ld c,CL			; either side (so it stands out)
.or:	ld a,(hl)
	or a
	jr z,.o0		; (a line without the overlay: as it was)
	ld b,a
	add a,a
	or b
	srl b
	or b			; the overlay a pixel wider each side
	cpl
	ex de,hl
	and (hl)
	ex de,hl
	or (hl)
	ld (de),a
.o0:	inc hl
	inc de
	dec c
	jr nz,.or
	ld a,(sr_dbk)		; into the pool
	out (P_LV),a
	ld hl,(spr_draw.dst+1)
	ex de,hl
	ld hl,sr_bg
	REPT CL
	ldi
	ENDR
	ld hl,(spr_draw.dst+1)
	ld bc,16
	add hl,bc
	ld (spr_draw.dst+1),hl
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,(ov_scol)
	ld c,a
	ld a,(spr_draw.ns+1)
	inc a
	ld (spr_draw.ns+1),a
	dec a
	pop hl
	or a
	ret
.gl:	rrca			; A = slot -> HL = its glyph in the window
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

; the background of a sprite or overlay cell over scenery: C = the pair's
; slot -> sr_bg = its glyph at phase k, A = the paper (high nibble).
; Where the glyph's set pixels are the majority (MFLG, from the level
; data) it is inverted and the ink becomes the paper: the cell keeps its
; main colour and only the thinner detail takes the sprite's colour.
; Black detail is dropped. Leaves the pool's bank in the window.
bg_get:
.ch:	ld h,COLT>>8		; (frame_begin: + k)
	ld l,c
	ld a,(hl)
	ld (.col+1),a		; its colours (ink low, paper high)
	ld a,c
.mo:	or 0			; (frame_begin: 0 or 128, by phase)
	ld l,a
	ld h,MFLG>>8
	ld a,(hl)
.mm:	and 0			; (frame_begin: the phase's bit)
	jr nz,.inv
	ld a,(.col+1)		; set pixels the detail, in the ink
	and $0F
	jr z,.zp		; (black: dropped)
	call .addr
	REPT CL
	ldi
	ENDR
	ld a,(sr_dbk)
	out (P_LV),a
	jr .pp
.zp:	call .zero
.pp:	ld a,(.col+1)		; the paper stays
	and $F0
	ret
.inv:	ld a,(.col+1)		; set pixels the main part: inverted, the
	and $F0			; paper's pixels the detail
	jr z,.zi		; (black: dropped)
	call .addr
	REPT CL
	ld a,(hl)
	cpl
	ld (de),a
	inc l
	inc e
	ENDR
	ld a,(sr_dbk)
	out (P_LV),a
	jr .col
.zi:	call .zero
.col:	ld a,0			; the ink is the paper
	rlca
	rlca
	rlca
	rlca
	and $F0
	ret
.zero:	ld hl,sr_bg
	ld b,CL
.zl:	ld (hl),0
	inc hl
	djnz .zl
	ret
.addr:
.kb:	ld a,LV_SCREEN		; (frame_begin: + k) phase k's bank in the
	out (P_LV),a		; window: HL = slot C's glyph, DE = sr_bg
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
	ret

mul40:	dw 0,40,80,120,160,200,240,280,320,360,400,440,480,520,560,600
	dw 640,680,720,760,800,840,880,920

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
.p0:	push hl
	pop ix			; IX: this frame's bucket of the row
	ld a,(step)		; (one row up before a step)
	or a
	jr z,.p1
	ld hl,-128
	add hl,de
	ex de,hl
.p1:	push de
	pop iy			; IY: last frame's
	ld a,(frame_id)
	ld (.cov+1),a
	ld a,VROWS
	ld (ps_n),a
	ld a,(k)
	ld d,a
	add a,COLT>>8
	ld e,a
	ld (ps_de),de
	ld a,LV_ATTR		; (the put-backs and new cells end in it too)
	out (P_LV),a
.row:	ld a,(step)		; no old cells for the new top row
	or a
	jr z,.ok
	ld a,(ps_n)
	cp VROWS
	jr z,.r2
.ok:	ld sp,iy
.r1:	pop hl			; put back last frame's cells - unless
	bit 7,h			; covered again this frame
	jr z,.r2
	pop bc
	pop bc
	ld a,h
	and 7
	or $60
	ld d,a
	ld e,l
	ld a,(de)		; (the frame it was last covered)
.cov:	cp 0
	jr z,.r1
	set 4,d			; SHC
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
.r2:	ld a,(ps_page)		; the jumps at +54h (from seg_build)
	ld h,a
	ld l,$54
	ld sp,hl
	pop hl
	ld (.j1+1),hl
	pop hl			; SP = +58h: cells whose colour changes too
	ld de,(ps_de)
	jp (hl)
.q2:	REPT 40
	pop hl
	pop bc
	ld (hl),d
	ld b,e
	ld a,(bc)
	set 3,h
	ld (hl),a
	ENDR
.q2e:	ld a,(ps_page)		; then the cells of one colour (from +2)
	ld h,a
	ld l,2
	ld sp,hl
.j1:	jp 0
.q1:	REPT 40
	pop hl			; the phase bank
	ld (hl),d
	ENDR
.q1e:
.r3:	ld sp,ix
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
.r5:	ld de,128
	add ix,de
	add iy,de
	ld hl,ps_page
	ld a,(hl)
	dec a
	and 31
	or SEGS>>8
	ld (hl),a
	ld hl,ps_n
	dec (hl)
	jp nz,.row
	ld sp,(spsave)
	xor a
	out (P_COLCTL),a
	ld a,LV_SCREEN
	out (P_LV),a
	ret
