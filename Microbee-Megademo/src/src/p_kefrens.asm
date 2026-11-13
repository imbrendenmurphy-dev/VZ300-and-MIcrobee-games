; =====================================================================
;  PART: KEFRENS BARS - lines 16-239 all show the same row of 64 cells
;  (one-line frames, the start address never changes), and on every line
;  the CPU paints a bar into that row's colour RAM: what each line shows
;  is the row as it was when the beam got there. The bars pile up into
;  the classic Kefrens wall. In colour the bars are colour RAM; in mono
;  they are glyphs (the screen RAM), as the mono output shows only pixels.
; =====================================================================
pk_t	equ pv+0
pk_tab	equ pv+2		; offset of op_kefrens's table in the buffers
pk_bar	equ pv+4		; bar colours (4)
pk_sp	equ pv+8
pk_page	equ pv+10

kefrens_part:
	dw kefrens_jobs, kefrens_init, kefrens_frame, ORD_LIVE

; op_kefrens: 1 + m lines. args: m, the 4 bar colours (2 words), then m
; words: the colour RAM address of the bar's first cell on that line.
op_kefrens: jp .e
.e:	AUD2
	pop hl			; 10 L = m
	ld a,l			; 4
	ld ixl,a		; 8
	pop bc			; 10 the bar's colours
	pop de			; 10
	DELAY 44
	AUD1
	DELAY 28
	jp .l
.l:	AUD2
	pop hl			; 10
	ld (hl),b		; 7
	inc l			; 4
	ld (hl),c		; 7
	inc l			; 4
	ld (hl),d		; 7
	inc l			; 4
	ld (hl),e		; 7  = 50
	DELAY 36
	AUD1
	dec ixl
	jp z,.x
	DELAY 10
	jp .l
.x:	ret

kefrens_init:
	ld hl,kefrens_build
	jp lp_both

kefrens_build:
	call lp_begin
	ld a,1
	call lp_top		; 0-2
	ld a,11
	call lp_idle		; 3-13
	ld hl,R12+(K_ROW>>8)*256
	ld de,R13+(K_ROW&255)*256
	call lp_w2		; 14: the band shows the row
	ld hl,R9+0*256
	call lp_w1		; 15: one-line frames from 16 (R4 is 0)
	ld de,op_kefrens
	call lp_word		; 16-237: 1 + 221 lines
	ld de,221
	call lp_word
	ld de,0
	call lp_word
	call lp_word		; (the colours: patched)
	ld hl,(lpp)
	ld a,l
	ld (pk_tab),a
	ld a,h
	and 3
	ld (pk_tab+1),a
	ld de,221*2
	add hl,de
	ld (lpp),hl
	ld hl,R12+(K_F>>8)*256
	ld de,R13+(K_F&255)*256
	call lp_w2		; 238: the bottom row next
	ld hl,K_S1
	jp lp_bottom

kefrens_frame:
	ld hl,(pk_t)
	inc hl
	ld (pk_t),hl
	; clear the row: black colour, or blank glyphs in mono
	ld a,(monomode)
	or a
	ld hl,COLWIN+K_ROW
	ld c,0
	jr z,.cc
	call win_screen
	ld hl,VIDEO+K_ROW
	ld c,$80
	jr .cm
.cc:	call win_col
.cm:	ld a,h
	ld (pk_page),a
	ld a,c
	REPT 64
	ld (hl),a
	inc l
	ENDR
	; this frame's bar colours: a new palette every 4 seconds
	ld a,(pk_t+1)
	and 3
	add a,a
	add a,a
	ld e,a
	ld a,(monomode)
	or a
	jr z,.c
	ld a,16
	add a,e
	ld e,a
.c:	ld d,0
	ld hl,kf_bars
	add hl,de
	ld a,(lp_build)
	ld d,a
	ld a,(pk_tab)
	sub 4
	ld e,a
	ld a,(pk_tab+1)
	sbc a,0
	add a,d
	ld d,a			; DE = the colour words in the build buffer
	ld bc,4
	ldir
	; the table: x(y) = 30 + 14 sin(2y + 3t) + 13 sin(5y - 2t), pushed
	; from the end: words COLWIN + K_ROW + x
	ld a,(lp_build)
	ld h,a
	ld l,0
	ld de,(pk_tab)
	add hl,de
	ld de,221*2
	add hl,de
	ld (pk_sp),sp
	ld sp,hl
	; DE walks 14 sin(4y + 2t), HL walks 30 + 13 sin(10y - 2t)
	ld a,(pk_t)
	add a,220
	ld e,a
	ld d,kf_sin14>>8
	ld a,(pk_t)
	neg
	add a,220
	ld l,a
	ld h,kf_sin13>>8
	ld a,(pk_page)
	ld b,a
	ld a,221/13
.l:	ex af,af'
	REPT 13
	ld a,(de)
	dec e
	add a,(hl)
	dec l
	ld c,a
	push bc
	ENDR
	ex af,af'
	dec a
	jp nz,.l
	ld sp,(pk_sp)
	ret
