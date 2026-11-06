; =====================================================================
;  BOSS-PART GLYPH CACHE. While the scenery stands still (a boss fight)
;  the boss's core, guns and hatches are drawn in the same places frame
;  after frame. The first time a part is drawn on a page its cells are
;  composed into glyphs of their own (PCG bank 14 for page A, 15 for
;  page B, copied to the mirror too) and the queue entries are kept;
;  after that the part costs only its queue entries. Each page keeps 8
;  entries of 64 bytes: sprite, y, x, frame stamp, cell count, 3 spare,
;  then up to 11 queue entries (SHC address, code, bank, colour).
;  CSLOT = 254 marks a cell holding a cached glyph; CMAP gives its code,
;  so a bullet passing over a gun is composed onto the gun.
; =====================================================================
DC_ENT	equ 6
DC_MAXC	equ 11

; the cache table of the page being drawn -> HL
dc_table:
	ld a,(rpage)
	or a
	ld hl,CTABA
	ret z
	ld hl,CTABB
	ret

; forget every cached part (both pages)
dc_clear:
	ld hl,CTABA
	ld b,2*DC_ENT
	ld de,64
.c:	ld (hl),255
	add hl,de
	djnz .c
	ret

; drawspr for a boss part: A = sprite, B = x, C = y
ds_cached:
	ld (dc_key),a
	ld (dc_key+1),bc		; (y, x)
	call dc_table
	ld b,DC_ENT
.f:	ld a,(dc_key)
	cp (hl)
	jr nz,.n
	inc hl
	ld a,(dc_key+1)
	cp (hl)
	jr nz,.n1
	inc hl
	ld a,(dc_key+2)
	cp (hl)
	jr nz,.n2
	dec hl
	dec hl
	jp dc_replay
.n2:	dec hl
.n1:	dec hl
.n:	ld de,64
	add hl,de
	djnz .f
	; not cached: take an entry not used this frame
	call dc_table
	ld c,0			; entry number
	ld b,DC_ENT
.v:	push hl
	inc hl
	inc hl
	inc hl
	ld a,(frame)
	cp (hl)
	pop hl
	jr nz,.got
	ld de,64
	add hl,de
	inc c
	djnz .v
	ld a,(dc_key)		; all busy: draw it the ordinary way
	ld bc,(dc_key+1)
	jp drawspr_nc
.got:	ld (dc_ent),hl
	ld (hl),255		; not valid until it is complete
	; its glyphs: codes 80h + 11 * entry in the page's cache bank
	ld a,c
	add a,a
	add a,c
	add a,a
	add a,a
	sub c			; 11 * entry
	add a,$80
	ld (dc_code),a
	ld hl,(pool_dst)
	ld (dc_sv),hl
	ld a,(pool_code)
	ld (dc_sv+2),a
	ld a,(pool_bank)
	ld (dc_sv+3),a
	ld a,(dc_code)
	ld (pool_code),a
	and $7F
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,PCGWIN
	add hl,de
	ld (pool_dst),hl
	ld a,(rpage)
	add a,BK_CACHE
	ld (pool_bank),a
	or LV_SCREEN
	out (P_LV),a
	ld hl,(qptr)
	ld (dc_q0),hl
	ld a,1
	ld (caching),a
	ld (dch_ok),a
	ld a,(dc_key)
	ld bc,(dc_key+1)
	call drawspr_nc
	xor a
	ld (caching),a
	; back to the pool
	ld hl,(dc_sv)
	ld (pool_dst),hl
	ld a,(dc_sv+2)
	ld (pool_code),a
	ld a,(dc_sv+3)
	ld (pool_bank),a
	or LV_SCREEN
	out (P_LV),a
	; keep it? (nothing in the way, not too many cells)
	ld a,(dch_ok)
	or a
	ret z
	ld hl,(qptr)
	ld de,(dc_q0)
	or a
	sbc hl,de		; 2 * cells
	ld a,l
	srl a
	cp DC_MAXC+1
	ret nc
	or a
	ret z
	ld (dch_n),a
	; the entry: key, stamp, count, then per cell SHC address, code,
	; bank, colour (read back from the page)
	ld de,(dc_ent)
	ld hl,dc_key
	ldi
	ldi
	ldi
	ld a,(frame)
	ld (de),a
	inc de
	ld a,(dch_n)
	ld (de),a
	inc de
	inc de
	inc de
	inc de
	ld hl,(dc_q0)
	ld a,(dch_n)
	ld b,a
.rb:	ld c,(hl)
	inc hl
	ld a,(hl)
	inc hl
	push hl
	ld h,a
	ld l,c			; SHC address
	ex de,hl
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ex de,hl		; HL = SHC address, DE -> entry
	set 7,h
	ld a,(hl)		; code
	ld (de),a
	inc de
	ld a,LV_ATTR
	out (P_LV),a
	ld a,(hl)		; bank
	ld (de),a
	inc de
	ld a,(pool_bank)
	or LV_SCREEN
	out (P_LV),a
	set 3,h
	ld a,COL_ON
	out (P_COLCTL),a
	ld a,(hl)		; colour
	ld (de),a
	inc de
	xor a
	out (P_COLCTL),a
	pop hl
	djnz .rb
	; their glyphs into the mirror (for compositing over them later)
	ld hl,(dc_ent)
	ld de,8
	add hl,de
	push hl
	ld a,(dch_n)
	ld b,a
.m:	push bc
	push hl
	inc hl
	inc hl
	ld a,(hl)		; code
	call dc_mirror
	pop hl
	ld de,5
	add hl,de
	pop bc
	djnz .m
	; and the cell map
	pop hl
	ld a,(dch_n)
	ld b,a
	jp dc_mark

; copy cached glyph A (page's cache bank) from PCG to the mirror
dc_mirror:
	and $7F
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	push hl
	ld de,PCGWIN
	add hl,de
	ld a,(rpage)
	add a,BK_CACHE
	push af
	or LV_SCREEN
	out (P_LV),a
	ld de,BGBUF
	ld bc,16
	ldir
	ld a,(pool_bank)
	or LV_SCREEN
	out (P_LV),a
	pop af
	add a,a
	add a,a
	add a,a			; bank * 8 = high byte of bank * 2048
	pop hl
	add a,h
	ld d,a
	ld e,l
	MEMV BLK_MIRROR
	ld hl,BGBUF
	ld bc,16
	ldir
	MEMV BLK_WORK
	ret

; a cached part again: put its cells on the page. HL = entry
dc_replay:
	inc hl
	inc hl
	inc hl
	ld a,(frame)
	ld (hl),a		; used this frame
	inc hl
	ld a,(hl)		; cells
	ld (dch_n),a
	ld de,4
	add hl,de
	push hl
	ld b,a
.r:	push bc
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)		; code
	inc hl
	ld b,(hl)		; bank
	inc hl
	ld c,(hl)		; colour
	inc hl
	push hl
	ex de,hl
	call scrput
	pop hl
	pop bc
	djnz .r
	pop hl			; the entries
	ld a,(dch_n)
	ld b,a
	; fall into dc_mark
; mark B queued cells from HL: CSLOT = 254, CMAP = glyph code
dc_mark:
.k:	ld e,(hl)
	inc hl
	ld d,(hl)		; SHC address (70-77xx)
	inc hl
	ld a,d
	xor $70^$60
	ld d,a
	ld a,254
	ld (de),a		; CSLOT
	ld a,d
	and 7
	or CMAP>>8
	ld d,a
	ld a,(hl)		; code
	ld (de),a
	inc hl
	inc hl
	inc hl
	djnz .k
	ret

dc_key	ds 3
dc_ent	dw 0
dc_code	db 0
dc_sv	ds 4
dc_q0	dw 0
dch_ok	db 0
dch_n	db 0
