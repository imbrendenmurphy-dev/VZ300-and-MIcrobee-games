; =====================================================================
;  LEVELS: unpack level A into the WORLD block (colour or mono picture)
; =====================================================================
level_load:
	ld l,a
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,de
	add hl,hl		; x6
	ld de,LEVTAB
	add hl,de
	push hl
	ld a,(hl)		; colour: the whole level
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld de,0
	call unlzb_bank
	pop hl
	ld a,(monomode)
	or a
	ret z
	inc hl			; mono: the picture over the colour one
	inc hl
	inc hl
	ld a,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld de,0
	jp unlzb_bank

; unpack from block A, address HL, into the WORLD block at DE: the packed
; bytes are fetched with the source block mapped for a moment each
unlzb_bank:
	call bank_port
	ld (ub_src),a
	ld a,BLK_WORLD
	call bank_port
	ld (ub_dst),a
	out (P_MEM),a
	; the 16-byte literal table and the length come first
	ld b,18
	push de
	ld de,ub_tab
.t:	call ub_byte
	ld (de),a
	inc de
	djnz .t
	pop de
	ld a,(ub_tab+16)
	ld (lzb_n),a
	ld a,(ub_tab+17)
	ld (lzb_n+1),a
	ld c,$80
.loop:	push hl
	ld hl,(lzb_n)
	ld a,h
	or l
	pop hl
	ret z
	call ub_bit
	jr c,.match
	call ub_bit
	jr c,.lit8
	ld b,4
	call ub_bits
	push hl
	ld hl,ub_tab
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	pop hl
	jr .put
.lit8:	ld b,8
	call ub_bits
.put:	ld (de),a
	inc de
	push hl
	ld hl,(lzb_n)
	dec hl
	ld (lzb_n),hl
	pop hl
	jr .loop
.match:	ld b,1
.gz:	call ub_bit
	jr c,.g1
	inc b
	jr .gz
.g1:	ld a,1
	dec b
	jr z,.gd
.gl:	call ub_bit
	rla
	djnz .gl
.gd:	inc a
	ld (lzb_len),a
	call ub_bit
	jr c,.o12
	ld b,7
	call ub_bits
	ld b,0
	jr .od
.o12:	ld b,4
	call ub_bits
	ld (lzb_hi),a
	ld b,8
	call ub_bits
	push af
	ld a,(lzb_hi)
	ld b,a
	pop af
.od:	push hl
	push bc
	ld c,a
	ld a,e
	sub c
	ld l,a
	ld a,d
	sbc a,b
	ld h,a
	dec hl
	pop bc
	push bc
	ld a,(lzb_len)
	ld c,a
	ld b,0
	ldir
	pop bc
	ld hl,(lzb_n)
	ld a,(lzb_len)
	push de
	ld e,a
	ld d,0
	or a
	sbc hl,de
	ld (lzb_n),hl
	pop de
	pop hl
	call vschk
	jp .loop
ub_bits:
	xor a
.l:	call ub_bit
	rla
	djnz .l
	ret
ub_bit:	sla c
	ret nz
	push af
	call ub_byte
	ld c,a
	pop af
	scf
	rl c
	ret
; the next packed byte (HL) from the source block
ub_byte:
	ld a,(ub_src)
	out (P_MEM),a
	ld a,(hl)
	inc hl
	push af
	ld a,(ub_dst)
	out (P_MEM),a
	pop af
	ret
