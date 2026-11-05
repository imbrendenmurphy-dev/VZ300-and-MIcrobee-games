; =====================================================================
;  HUGE BOSS BODIES: a fixed set of PCG glyphs per stage (banks 7-9).
;  While the boss slides in with the scenery its cells are queued on the
;  page each frame (marked FFh in CSLOT so sprites drawn over the body -
;  its guns, hatches and core - compose onto the body's own glyphs).
;  Once it has arrived the scroll stops: the body is written into each
;  page's shadow once and then costs nothing.
;  BOSSBUF: ncol, nrow, row0, n(2) .. +10h codes, +190h banks, +310h colours
; =====================================================================
BB_CODE	equ BOSSBUF+$10
BB_ATTR	equ BOSSBUF+$190
BB_COL	equ BOSSBUF+$310

; B = E_X (x+32), C = E_Y (y+16)
boss_cells:
	ld a,(BOSSBUF)
	or a
	ret z
	ld a,b
	srl a
	sub 16
	ld (bc_col0),a
	ld a,(scrollon)
	or a
	jr z,.arr
	xor a			; moving: queue the cells every frame
	ld (bakedA),a
	ld (bakedB),a
	inc a
	jr .go
.arr:	ld a,(rpage)		; arrived: bake into this page once
	or a
	ld hl,bakedA
	jr z,$+5
	ld hl,bakedB
	ld a,(hl)
	or a
	ret nz
	ld (hl),1
	xor a
.go:	ld (bc_mode),a
	ld hl,BB_CODE
	ld (bc_src),hl
	ld a,(BOSSBUF+2)
	ld (bc_row),a
	ld a,(BOSSBUF+1)
	ld (bc_nr),a
.r:	ld a,(bc_row)
	cp PROWS
	ret nc
	; SHC address of (row, col0)
	rrca
	rrca
	ld l,a
	and $3F
	ld h,a
	ld a,l
	and $C0
	ld l,a
	ld de,(pstart)
	add hl,de
	ld a,(bc_col0)
	ld e,a
	rla
	sbc a,a
	ld d,a
	add hl,de
	ld (bc_cur),hl
	ld a,(bc_col0)
	ld (bc_sc),a
	ld de,(bc_src)
	ld a,(BOSSBUF)
	ld b,a
.c:	ld a,(bc_sc)
	cp SCOLS		; (negative columns read as >= 64)
	jr nc,.nx
	ld a,(de)
	ld c,a			; code
	ld hl,BB_ATTR-BB_CODE
	add hl,de
	ld a,(hl)
	ld (bc_bank),a
	or a
	jr nz,.vis
	ld a,c
	cp BLANK_CODE
	jr z,.nx		; transparent
.vis:	ld a,(bc_mode)
	or a
	push de
	push bc
	call nz,bc_queue
	call z,bc_bake
	pop bc
	pop de
.nx:	inc de
	ld hl,bc_sc
	inc (hl)
	ld hl,(bc_cur)
	inc hl
	ld (bc_cur),hl
	djnz .c
	ld hl,(bc_src)
	ld a,(BOSSBUF)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld (bc_src),hl
	ld hl,bc_row
	inc (hl)
	ld hl,bc_nr
	dec (hl)
	jr nz,.r
	ret

; queue one body cell (C = code, DE = its entry in BB_CODE)
bc_queue:
	ld hl,BB_COL-BB_CODE
	add hl,de
	ld b,(hl)		; colour
	ld hl,(bc_cur)
	res 3,h
	ex de,hl		; DE = SHC address
	ld a,d
	xor $70^$60
	ld h,a
	ld l,e
	ld (hl),255		; boss body here
	ld hl,(qptr)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (hl),c
	inc hl
	ld a,(bc_bank)
	ld (hl),a
	inc hl
	ld (hl),b
	inc hl
	ld (qptr),hl
	ld hl,qcount
	inc (hl)
	ld hl,qslot0
	inc (hl)
	or 1			; NZ: (keeps the caller's 'call z' from running)
	ret

; write one body cell into the page's shadow and screen (C = code)
bc_bake:
	ld hl,BB_COL-BB_CODE
	add hl,de
	ld b,(hl)		; colour
	ld hl,(bc_cur)
	res 3,h
	ld (hl),c		; SHC
	ld a,h
	xor $70^$68
	ld h,a
	ld (hl),0		; no band here
	xor $68^$58
	ld h,a
	ld a,(bc_bank)
	ld (hl),a		; SHA
	ld a,h
	xor $58^$78
	ld h,a
	ld (hl),b		; SHK
	set 7,h
	ld a,COL_ON
	out (P_COLCTL),a
	ld (hl),b
	xor a
	out (P_COLCTL),a
	res 3,h
	ld (hl),c		; screen code
	ld a,LV_ATTR
	out (P_LV),a
	ld a,(bc_bank)
	ld (hl),a
	ld a,(pool_bank)
	or LV_SCREEN
	out (P_LV),a
	xor a			; Z
	ret

; background of a cell marked as boss body: HL = its SHC address ->
; cl_bgc, cl_bgb, cl_pap from the boss tables (keeps HL)
boss_bg:
	push hl
	ld de,(pstart)
	or a
	sbc hl,de
	ld a,h
	and 7
	ld h,a
	ld a,l
	and 63
	ld c,a			; screen column
	add hl,hl
	add hl,hl
	ld b,h			; screen row
	ld a,(BOSSBUF+2)
	ld e,a
	ld a,b
	sub e
	ld b,a			; body row
	ld a,(bc_col0)
	ld e,a
	ld a,c
	sub e
	ld c,a			; body column
	ld hl,0
	ld a,(BOSSBUF)
	ld e,a
	ld d,0
	inc b
.m:	dec b
	jr z,.md
	add hl,de
	jr .m
.md:	ld e,c
	add hl,de
	ld de,BB_CODE
	add hl,de
	ld a,(hl)
	ld (cl_bgc),a
	ld de,BB_ATTR-BB_CODE
	add hl,de
	ld a,(hl)
	ld (cl_bgb),a
	ld de,BB_COL-BB_ATTR
	add hl,de
	ld a,(hl)
	and $F0
	ld (cl_pap),a
	pop hl
	ret

bc_col0	db 0
bc_row	db 0
bc_nr	db 0
bc_sc	db 0
bc_src	dw 0
bc_cur	dw 0
bc_mode	db 0
bc_bank	db 0
bakedA	db 0
bakedB	db 0
