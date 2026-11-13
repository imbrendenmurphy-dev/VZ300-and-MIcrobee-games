; =====================================================================
;  PART: CREDITS - a smooth vertical scroller. Between the top row and
;  the bottom row: a blank gap of g lines (18 down to 3: the fine
;  scroll), then 12 text rows read from a ring of 16 rows (rows 0-11 are
;  copied after it, so any 12 in a row are contiguous), then a blank
;  filler of 32 - g lines. A new line of text goes into the ring each time
;  the gap wraps.
; =====================================================================
cr_p	equ pv+0		; the scroll position (lines)
cr_r	equ pv+2		; the ring row at the top
cr_li	equ pv+3		; the next line of text
cr_g	equ pv+4
cr_half	equ pv+5

credits_part:
	dw credits_jobs, credits_init, credits_frame, ORD_END+2

credits_init:
	ld hl,CR_TOP
	ld (s1_addr),hl
	ld a,18
	ld (cr_g),a
	call credits_build
	call lp_swap
	jp credits_build

credits_frame:
	ld a,(cr_half)
	xor 1
	ld (cr_half),a
	jp z,credits_build	; (moves every other frame: half a line a frame)
	ld hl,(cr_p)
	inc hl
	ld (cr_p),hl
	ld a,l
	and 15
	jr nz,.prep
	; the gap wraps: the ring moves on a row (its new bottom row is ready)
	ld a,(cr_r)
	inc a
	and 15
	ld (cr_r),a
	ld a,(cr_li)
	inc a
	cp CR_N
	jr c,.w
	xor a
.w:	ld (cr_li),a
	xor a
	jr .g
.prep:	; meanwhile the next line goes into ring row (r + 12) & 15, one
	; piece a frame (the vertical blanking is short)
	push af
	ld c,a
	ld a,(cr_r)
	add a,12
	and 15
	ld b,a			; the row
	ld a,c
	cp 4
	jr nz,.p6
	ld a,b
	call cr_rows
	jr .pg
.p6:	cp 6
	jr nz,.p8
	ld a,b
	cp 12
	jr nc,.pg
	add a,16
	call cr_rows
	jr .pg
.p8:	cp 8
	jr nz,.p10
	ld a,b
	call cr_rowc
	jr .pg
.p10:	cp 10
	jr nz,.pg
	ld a,b
	cp 12
	jr nc,.pg
	add a,16
	call cr_rowc
.pg:	pop af
.g:	ld b,a
	ld a,18
	sub b
	ld (cr_g),a
	jp credits_build

; the line program for gap g (code line k shows from line k + 1)
credits_build:
	call lp_begin
	ld a,1
	call lp_top		; 0-2
	ld a,11
	call lp_idle		; 3-13
	ld hl,R12+(CR_BLANK>>8)*256
	ld de,R13+(CR_BLANK&255)*256
	call lp_w2		; 14: the gap shows the blank row
	ld a,(cr_g)
	dec a
	ld h,a
	ld l,R9
	call lp_w1		; 15: the gap is a frame of g lines
	ld a,(cr_g)
	sub 2
	call lp_idle		; 16 .. 13+g
	; 14+g: the text's address: ring row r
	ld a,(cr_r)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld e,R13
	ld d,l
	ld l,R12
	call lp_w2
	ld hl,R9+15*256
	ld de,R4+11*256
	call lp_w2		; 15+g: 12 rows of 16 lines
	ld a,15
	call lp_idle		; 16+g .. 30+g
	ld hl,R12+(CR_BLANK>>8)*256
	ld de,R13+(CR_BLANK&255)*256
	call lp_w2		; 31+g (the text's row 1): then the filler's
	ld a,175
	call lp_idle		; 32+g .. 206+g
	ld a,(cr_g)
	ld b,a
	ld a,31
	sub b			; x - 1 = 31 - g
	ld h,a
	ld l,R9
	ld de,R4+0*256
	call lp_w2		; 207+g: the filler, x lines
	ld a,(cr_g)
	ld b,a
	ld a,30
	sub b
	call lp_idle		; 208+g .. 237
	ld hl,R12+(CR_F>>8)*256
	ld de,R13+(CR_F&255)*256
	call lp_w2		; 238
	ld hl,CR_TOP
	jp lp_bottom

; line cr_li into ring row A: the screen RAM
cr_rows:
	call cr_addr
	ld de,VIDEO
	add hl,de
	ex de,hl		; DE = destination
	call win_screen
	ld a,CR_TBLK
	call map_blk
	ld a,(cr_li)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld bc,CR_TOFF
	add hl,bc
	ld bc,64
	ldir
	ret

; ... and its colour (in colour only)
cr_rowc:
	ld c,a
	ld a,(monomode)
	or a
	ret nz
	ld a,c
	call cr_addr
	call win_col
	ld de,COLWIN
	add hl,de
	ld a,(cr_li)
	ld e,a
	ld d,0
	push hl
	ld hl,cr_cols
	add hl,de
	ld a,(hl)
	pop hl
	ld b,64
.c:	ld (hl),a
	inc hl
	djnz .c
	ret

cr_addr: ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ret
