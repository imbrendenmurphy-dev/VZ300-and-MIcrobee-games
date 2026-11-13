; =====================================================================
;  PART: PLASMA - 26 rows x 32 blocks of 16 x 8 pixels. In colour a
;  block is a checker glyph mixing ink and paper (the colour RAM); in mono
;  it is a glyph of 0-8 lit pixels in 8 (the screen RAM).
;  The plasma is computed INSIDE the scanlines by op_plasma, between the
;  music samples: two blocks a line, a row in 16 lines, half the rows each
;  frame (25 fps):  block(x, y) = ramp_B(y)[ A[x + warp(y) + scroll] ]
;  where ramp_B is the ramp rotated by B (128 rotations in a RAM block).
;  The Premium holds the CPU when it touches video RAM during a visible
;  line, until the horizontal blanking: so each line's 4 writes come in
;  one burst, which lines up with the blanking once and stays there.
; =====================================================================
pp_t	equ pv+0
pp_args	equ pv+2		; offset of op_plasma's arguments in the buffers
pp_pat	equ pv+4		; pattern page
pp_vbase equ pv+6		; video base of the plasma: colour RAM, or screen RAM in mono
BLK_RAMP equ 30			; 128 rotated copies of the colour ramp

plasma_part:
	dw plasma_jobs, plasma_init, plasma_frame, ORD_KEFRENS

; ---- the op: rows given as (A pointer, destination, ramp page << 8)
; (H = 0 ends). The burst writes the 2 blocks computed on the line before.
op_plasma: jp .e
.r:	REPT 16
	AUD2
	ld a,ixh		; 8   the burst: block 1 twice, block 2 twice
	ld (bc),a		; 7
	inc c			; 4
	ld (bc),a		; 7
	inc c			; 4
	ex af,af'		; 4
	ld (bc),a		; 7
	inc c			; 4
	ld (bc),a		; 7
	inc c			; 4   = 56
	ld a,(hl)		; 7   the next block 1
	inc l			; 4
	ld e,a			; 4
	ld a,(de)		; 7
	ld ixh,a		; 8   = 86
	AUD1
	ld a,(hl)		; 7   the next block 2
	inc l			; 4
	ld e,a			; 4
	ld a,(de)		; 7
	ex af,af'		; 4   = 26
	DELAY 12
	ENDR
.e:	AUD2
	pop hl			; 10
	pop bc			; 10
	pop de			; 10
	ld a,(hl)		; the first two blocks
	inc l
	ld e,a
	ld a,(de)
	ld ixh,a		; 30
	ld a,(hl)
	inc l
	ld e,a
	ld a,(de)
	ex af,af'		; 26 = 86
	AUD1
	ld a,h			; 4
	or a			; 4
	jp z,.x			; 10
	DELAY 10
	jp .r			; 10
.x:	ret

plasma_init:
	ld a,pl_pat0>>8
	ld (pp_pat),a
	; 128 rotated copies of the ramp (rotation 2p in page p) in BLK_RAMP
	ld a,BLK_RAMP
	call map_blk
	ld hl,pl_ramp
	ld bc,COLWIN+P_AREA
	ld a,(monomode)
	or a
	jr z,.c
	ld hl,pl_mramp
	ld bc,VIDEO+P_AREA
.c:	ld (pp_vbase),bc
	ld (pl_wp),hl
	ld de,0
	ld c,0			; 2p
.pg:	ld hl,(pl_wp)
	ld a,l
	add a,c
	ld l,a			; ramp + 2p
	push bc
	ld a,c
	neg
	ld c,a
	ld b,0
	or a
	jr nz,.n0
	inc b			; 256 when p = 0
.n0:	ldir			; to the end of the ramp
	pop bc
	ld a,c
	or a
	jr z,.nx
	push bc
	ld b,0
	ld hl,(pl_wp)
	ldir			; then its start
	pop bc
.nx:	ld a,c
	add a,2
	ld c,a
	jr nz,.pg
	ld hl,plasma_build
	jp lp_both

plasma_build:
	; lines 16-207: the plasma (24 rows of 8), 208-223: a blank band where
	; the CPU re-synchronises (the plasma's video writes make its timing
	; drift on the real machine), 224-239: the text row S2.
	call lp_begin
	ld a,1
	call lp_top		; 0-2
	ld a,11
	call lp_idle		; 3-13
	ld hl,R12+(P_AREA>>8)*256
	ld de,R13+(P_AREA&255)*256
	call lp_w2		; 14 (phys 15)
	ld hl,R9+7*256
	ld de,R4+(P_ROWS+1)*256
	call lp_w2		; 15: rows of 8 lines from 16, P_ROWS + 2 of them
	ld hl,R6+P_ROWS*256
	call lp_w1		; 16: the last two rows (208-223) are not displayed
	ld de,op_plasma
	call lp_word		; 17-187: 10 rows x 17 + 1 (20 lines' room for drift)
	ld hl,(lpp)
	ld a,l
	ld (pp_args),a
	ld a,h
	and 3
	ld (pp_args+1),a
	ld de,11*6
	add hl,de
	ld (lpp),hl
	ld de,op_sync		; until line 208 (the blank rows start)
	call lp_word
	ld hl,R12+(P_S2>>8)*256
	ld de,R13+(P_S2&255)*256
	call lp_w2		; 209
	ld a,14
	call lp_idle		; 210-223
	ld hl,R9+15*256
	ld de,R4+0*256
	call lp_w2		; 224: S2 is one row of 16 lines
	ld a,14
	call lp_idle		; 225-238
	ld hl,R12+(P_F>>8)*256
	ld de,R13+(P_F&255)*256
	call lp_w2		; 239: S2's last line
	ld hl,P_S1
	jp lp_bottom

plasma_frame:
	ld hl,(pp_t)
	inc hl
	ld (pp_t),hl
	; switch the pattern every 10 seconds
	ld a,l
	or a
	jr nz,.np
	ld a,h
	and 1
	jr nz,.np
	ld a,(pp_pat)
	xor (pl_pat0^pl_pat1)>>8
	ld (pp_pat),a
.np:	ld a,(monomode)
	or a
	call z,win_col
	ld a,(monomode)
	or a
	call nz,win_screen
	ld a,BLK_RAMP
	call map_blk
	; this frame's rows: y = parity, parity + 2, ... (13 rows)
	ld a,(lp_build)
	ld h,a
	ld l,0
	ld de,(pp_args)
	add hl,de
	ld (pl_wp),hl
	ld a,(pp_t)
	and 1
	ld (pl_y),a
	ld b,10
.rows:	push bc
	call pl_rowp		; -> HL, BC, D
	push de
	push hl
	ld hl,(pl_wp)
	pop de
	ld (hl),e		; A pointer
	inc hl
	ld (hl),d
	inc hl
	ld (hl),c		; destination
	inc hl
	ld (hl),b
	inc hl
	pop de
	ld (hl),0
	inc hl
	ld (hl),d		; ramp page
	inc hl
	ld (pl_wp),hl
	pop bc
	djnz .rows
	; the end marker (H = 0)
	ld hl,(pl_wp)
	inc hl
	ld (hl),0
	; the other rows here, in the vertical blanking
.vb:	ld a,(pl_y)
	cp P_ROWS
	ret nc
	call pl_rowp
	REPT 32
	ld a,(hl)
	inc l
	ld e,a
	ld a,(de)
	ld (bc),a
	inc c
	ld (bc),a
	inc c
	ENDR
	jp .vb

; the parameters of row (pl_y), then pl_y += 2:
; HL = A pointer, BC = video address, D = ramp page
pl_rowp:
	ld a,(pl_y)
	ld c,a
	add a,2
	ld (pl_y),a
	ld de,(pp_t)
	srl d
	rr e			; time / 2: both halves of a frame pair agree
	; warp = (sin(6y + 3t) + 128) / 8, scroll = t
	ld a,c
	add a,a
	add a,c
	add a,a			; 6y
	ld b,a
	ld a,e
	add a,a
	add a,e			; 3t
	add a,b
	ld l,a
	ld h,sin_tab>>8
	ld a,(hl)
	add a,128
	rrca
	rrca
	rrca
	and 31
	add a,e			; + scroll
	push af
	; B = sin(6y - 2t) / 2 + 4t (the colours cycle): ramp page B / 2
	ld a,c
	add a,a
	add a,c
	add a,a			; 6y
	sub e
	sub e
	ld l,a
	ld a,(hl)
	sra a
	ld b,a
	ld a,e
	add a,a
	add a,a
	add a,b
	srl a
	ld (pl_e),a
	; destination: the video base + 64 y
	ld l,c
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld bc,(pp_vbase)
	add hl,bc
	ld b,h
	ld c,l
	pop af
	ld l,a
	ld a,(pp_pat)
	ld h,a
	ld a,(pl_e)
	ld d,a
	ret
