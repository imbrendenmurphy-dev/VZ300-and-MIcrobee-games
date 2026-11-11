; =====================================================================
;  VIDEO: 6545 set-up (40 columns, 11-line cells), hardware fine and
;  coarse scrolling, ring rows, the window's cut edges, star glyphs
;
;  The 2K screen RAM is a ring of cells; display row d starts at
;  (S + 40 d) & 7FFh. Each frame the 6545's vertical total adjust (R5)
;  delays the picture by k lines (k = 0..10): the whole picture slides
;  down smoothly. When k passes 10, S steps back 40 cells (one row) and
;  k drops by 11, so the picture continues seamlessly.
;  Rows 0-1 are the HUD band (black, text held at every phase); rows
;  2..23 the playfield, whose first and last rows show the scenery cut
;  to the fixed window (display lines 32..263) through shared glyphs.
; =====================================================================

; ---------------------------------------------------------------------
;  6545: the 40 x 24, 8 x 11 mode proven on the Premium Plus (MODES40):
;  R0-R3 35 28 2C 34, 28 rows of 11 lines + R5 = 308..318 lines.
; ---------------------------------------------------------------------
crtc_init:
	ld a,1
	in a,(P_CLK40)		; 40-column clock
	ld hl,crtc_tab
crtc_load:
	ld c,0
.ci:	ld a,c
	out (P_CRTCA),a
	ld a,(hl)
	out (P_CRTCD),a
	inc hl
	inc c
	ld a,c
	cp 16
	jr nz,.ci
	ret
crtc_tab:	db $35,$28,$2C,$34, 27,0,DROWS,26, $48,CL-1,$20,CL-1, 0,0,0,0
; back to the standard 80 x 24 display
crtc_exit:
	xor a
	in a,(P_CLK40)
	ld hl,crtc_80
	jr crtc_load
crtc_80:	db $6B,$50,$58,$37, $1B,$05,$18,$1A, $48,$0A,$2A,$0A, 0,0,0,0

; set R5 = k and the start address = S
crtc_scroll:
	ld a,5
	out (P_CRTCA),a
	ld a,(fineK)
	out (P_CRTCD),a
	ld hl,(scrS)
	ld a,12
	out (P_CRTCA),a
	ld a,h
	out (P_CRTCD),a
	ld a,13
	out (P_CRTCA),a
	ld a,l
	out (P_CRTCD),a
	ret

; ---------------------------------------------------------------------
;  frame timing: rising edges of the 6545 vertical blanking status.
;  vschk must run at least once per vertical blank (every ~15000 T).
; ---------------------------------------------------------------------
vschk:	in a,(P_CRTCA)
	and $20
	jr z,.lo
	ld a,(vblast)
	or a
	ret nz
	ld a,$20
	ld (vblast),a
	ld a,(vcount)
	inc a
	ld (vcount),a
	ld a,(vtotal)
	inc a
	ld (vtotal),a
	ret
.lo:	ld (vblast),a
	ret

; wait for the start of a vertical blank once FIELDS fields have passed
; since the last frame (if the frame ran long, the next blank after
; that). The sound driver's idle loop runs while waiting.
waitframe:
	ld a,(vcount)
	cp FIELDS
	jr c,.w
	ld (lagged),a		; ran long: wait for a fresh blank
	ld a,FIELDS-1
	ld (vcount),a
.w:	in a,(P_CRTCA)
	and $20
	jr z,.lo
	ld a,(vblast)
	or a
	jr nz,.idle
	ld a,$20
	ld (vblast),a
	ld a,(vtotal)
	inc a
	ld (vtotal),a
	ld a,(vcount)
	inc a
	ld (vcount),a
	cp FIELDS
	jr c,.idle
	xor a
	ld (vcount),a
	ld a,(vtotal)		; fields since the last frame
	ld (elapsed),a
	xor a
	ld (vtotal),a
	ret
.lo:	ld (vblast),a
.idle:	call snd_idle
	jr .w

; one vertical blank (front end)
vsync1:	xor a
	ld (vcount),a
.l:	call vschk
	ld a,(vcount)
	or a
	jr z,.l
	ret

; ---------------------------------------------------------------------
;  ring rows
; ---------------------------------------------------------------------
NROWB	equ 26
rows_calc:			; rowbase[d] = (S + 40 d) & 7FFh, d = 0..25
	ld hl,(scrS)
	ld de,rowbase
	ld b,NROWB
.r:	ld a,l
	ld (de),a
	inc de
	ld a,h
	and 7
	ld (de),a
	inc de
	ld a,l
	add a,SCOLS
	ld l,a
	jr nc,$+3
	inc h
	djnz .r
	ret
ring_row:			; A = display row -> HL = ring offset of column 0
	add a,a
	ld l,a
	ld h,0
	push de
	ld de,rowbase
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	pop de
	ret

; ---------------------------------------------------------------------
;  clear: colour RAM, attributes, screen (all black)
; ---------------------------------------------------------------------
cls_all:
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,COLWIN
	ld bc,$0800
	ld e,0
	call fill
	xor a
	out (P_COLCTL),a
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,VIDEO
	ld bc,$0800
	ld e,BK_FIX
	call fill
	ld a,LV_SCREEN
	out (P_LV),a
	ld hl,VIDEO
	ld bc,$0800
	ld e,G_BLACK
	jp fill

; HL = start, BC = count, E = value
fill:	ld (hl),e
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,fill
	ret

; clear all 16 PCG banks
pcg_clear:
	ld b,16
.b:	ld a,b
	dec a
	or LV_SCREEN
	out (P_LV),a
	push bc
	ld hl,PCGWIN
	ld bc,$0800
	ld e,0
	call fill
	pop bc
	djnz .b
	ld a,LV_SCREEN
	out (P_LV),a
	ret

; copy B whole banks of glyphs (2K each, PCG layout) from HL to PCG
; bank C on
pcg_banks:
	ld a,c
	or LV_SCREEN
	out (P_LV),a
	push bc
	ld de,PCGWIN
	ld bc,$0800
	ldir
	pop bc
	inc c
	djnz pcg_banks
	ld a,LV_SCREEN
	out (P_LV),a
	ret

; copy 16 bytes HL -> PCG glyph code A of the bank in the window
; (HL advances by 16; keeps A, BC, DE)
put_glyph:
	push af
	push de
	push bc
	call glyph_addr
	ld bc,16
	ldir
	pop bc
	pop de
	pop af
	ret
; A = code -> DE = its line 0 in the PCG window
glyph_addr:			; (keeps A)
	push af
	rlca
	rlca
	rlca
	rlca
	ld e,a
	and $07
	or $F8
	ld d,a
	ld a,e
	and $F0
	ld e,a
	pop af
	ret

; ---------------------------------------------------------------------
;  RING ROWS: write map row DE into the ring row at offset HL. The
;  shadows always; the video RAM only if A <> 0 (the row is hidden).
;  Map rows count upwards from the start of the level.
; ---------------------------------------------------------------------
prep_row:
	ld (pr_vid),a
	ld (pr_base),hl
	; --- 1: fetch 40 cells (code, attr, colour) from the level block
	MEMV BLK_LEVEL
	ld hl,(LV_NROWS)	; past the end of the map: repeat the last row
	dec hl
	or a
	sbc hl,de
	jr nc,.inmap
	add hl,de
	ex de,hl
.inmap:	ld a,e
	and 1
	ld (pr_half),a
	srl d			; metarow = maprow / 2
	rr e
	ld h,d
	ld l,e
	add hl,hl
	add hl,hl
	add hl,de
	add hl,hl
	add hl,hl
	add hl,hl		; *40 (20 metatiles x 2 bytes)
	ld de,LV_MAP
	add hl,de		; HL -> 20 metatile numbers
	ld de,rowtmp
	ld b,SCOLS/2
.mt:	push bc
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	push hl
	ld h,b
	ld l,c
	add hl,hl
	add hl,bc		; *3
	add hl,hl
	add hl,hl		; *12
	ld bc,LV_META
	add hl,bc
	ld a,(pr_half)
	or a
	jr nz,.top		; odd map row = upper half of the metatile
	ld bc,6
	add hl,bc
.top:	ld bc,6
	ldir
	pop hl
	pop bc
	djnz .mt
	; --- 2: shadows (+ video)
	call vschk
	MEMV BLK_WORK
	ld de,(pr_base)
	ld hl,rowtmp
	ld b,SCOLS
.pc:	push bc
	ld c,(hl)		; code
	inc hl
	ld b,(hl)		; attr
	inc hl
	ld a,(hl)		; colour
	inc hl
	push hl
	ld (pr_col),a
	ld a,d
	and 7
	ld d,a			; wrap the ring
	ld l,e
	or $70
	ld h,a
	ld (hl),c		; SHC
	set 3,h
	ld (hl),b		; SHA
	ld a,d
	or $68
	ld h,a
	ld a,(pr_col)
	ld (hl),a		; SHK
	ld a,(pr_vid)
	or a
	jr z,.nv
	ld a,d
	or $F0
	ld h,a
	ld (hl),c		; screen
	ld a,LV_ATTR
	out (P_LV),a
	ld (hl),b		; attribute
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	set 3,h
	ld a,(pr_col)
	ld (hl),a		; colour
	xor a
	out (P_COLCTL),a
.nv:	pop hl
	inc de
	pop bc
	djnz .pc
	ret

; black row (HUD band) at ring offset HL: video only
black_row:
	ld b,SCOLS
.c:	ld a,h
	and 7
	or $F0
	ld h,a
	ld (hl),G_BLACK
	ld a,LV_ATTR
	out (P_LV),a
	ld (hl),BK_FIX
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	set 3,h
	ld (hl),0
	res 3,h
	xor a
	out (P_COLCTL),a
	inc hl
	djnz .c
	ret

; ---------------------------------------------------------------------
;  SCROLL: start of a level. m_top = map row on display row 2.
; ---------------------------------------------------------------------
scroll_init:
	ld hl,0
	ld (scrS),hl
	xor a
	ld (fineK),a
	ld (stepped),a
	call rows_calc
	xor a
	call ring_row
	call black_row
	ld a,1
	call ring_row
	call black_row
	ld hl,(m_top)
	ld c,EROW0
.r:	push bc
	push hl
	ex de,hl
	ld a,c
	call ring_row
	ld a,1
	call prep_row
	pop hl
	dec hl			; the row below shows the previous map row
	pop bc
	inc c
	ld a,c
	cp DROWS
	jr nz,.r
	jp edge_maps

; advance the scroll by (scrollSpd) lines (0, 2 or 4; 1 = 2 lines every
; other frame). On a coarse step: blank the new HUD row, fill the
; shadows of the new top playfield row, remap the edge rows.
scroll_step:
	xor a
	ld (stepped),a
	ld a,(elapsed)		; lines = (speed in half-lines a field *
	ld b,a			; fields elapsed + remainder) / 2
	ld a,(scrollSpd)
	ld c,a
	xor a
.m:	add a,c
	djnz .m
	ld hl,scr_half
	add a,(hl)
	ld b,a
	and 1
	ld (hl),a
	ld a,b
	srl a
	cp CL
	jr c,.cap
	ld a,CL-1		; at most one coarse step a frame
.cap:	or a
	ret z
	ld b,a
	push bc
	call star_phase
	pop bc
	ld a,(fineK)
	add a,b
	cp CL
	jr c,.fine
	sub CL
	ld (fineK),a
	ld a,1
	ld (stepped),a
	ld hl,(scrS)
	ld de,-SCOLS
	add hl,de
	ld a,h
	and 7
	ld h,a
	ld (scrS),hl
	call rows_calc
	ld hl,(m_top)
	inc hl
	ld (m_top),hl
	xor a			; new row 0: hidden until the commit
	call ring_row
	call black_row
	call hud_step
	ld a,EROW0		; new row 2 (on display as HUD row 1 until
	call ring_row		; the commit): shadows only
	ld de,(m_top)
	xor a
	call prep_row
	jp edge_maps
.fine:	ld (fineK),a
	ret

; ---------------------------------------------------------------------
;  EDGE ROWS. The cells of display rows 2 and 23 point at shared glyphs
;  (bank BK_FIX, G_E0 + u, G_E1 + u), one per different scenery glyph
;  in the row; each frame those few glyphs are rewritten as the scenery
;  cut to the window. The maps (cell -> u, u -> mirror glyph) change
;  only on a coarse step. WORK must be mapped.
; ---------------------------------------------------------------------
edge_maps:
	call vschk
	ld a,EROW0
	ld ix,eu0
	ld iy,egm0
	call .row
	ld (nu0),a
	call vschk
	ld a,EROW1
	ld ix,eu1
	ld iy,egm1
	call .row
	ld (nu1),a
	ret
.row:	call ring_row
	ld b,SCOLS
	ld c,0			; uniques so far
.c:	push bc
	push hl
	; glyph number g = SHA * 128 + (SHC & 7Fh); paper not black: the
	; inverted glyph, stamped in EDGEC2 and flagged in egm (bit 15)
	ld a,h
	and 7
	or $68
	ld h,a
	ld a,(hl)		; colour
	and $F0
	ld (em_inv),a
				; (SHK -> SHC:)
	ld a,h
	xor $68^$70
	ld h,a
	ld a,(hl)
	and $7F
	ld e,a
	set 3,h
	ld d,(hl)		; bank
	srl d
	jr nc,.ev
	set 7,e
.ev:	ld hl,EDGEC
	ld a,(em_inv)
	or a
	jr z,.st
	ld hl,EDGEC2
.st:	add hl,de
	ld a,(hl)
	or a
	jr nz,.seen
	pop hl
	pop bc
	inc c
	push bc
	push hl
	ld hl,EDGEC
	ld a,(em_inv)
	or a
	jr z,.st2
	ld hl,EDGEC2
.st2:	add hl,de
	ld (hl),c		; u + 1
	ex de,hl		; egm[u] = mirror offset = g * 16 (+ 8000h: inverted)
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,(em_inv)
	or a
	jr z,.st3
	set 7,h
.st3:	ld (iy+0),l
	ld (iy+1),h
	inc iy
	inc iy
	ld a,c
.seen:	dec a
	ld (ix+0),a
	inc ix
	pop hl
	inc hl
	pop bc
	djnz .c
	ld a,c			; clear the stamps again
	or a
	ret z
	push af
	ld b,c
.cl:	dec iy
	dec iy
	ld l,(iy+0)
	ld h,(iy+1)
	ld de,EDGEC
	bit 7,h
	jr z,.c0
	res 7,h
	ld de,EDGEC2
.c0:	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l			; g
	add hl,de
	ld (hl),0
	djnz .cl
	pop af
	ret

; write the edge glyphs for the current phase: A = 0 for row 2 (shows
; lines 10-k .. 10), A <> 0 for row 23 (lines 0 .. 10-k). A glyph whose
; cells have a coloured paper is inverted (the paper colour becomes the
; ink over black) so the hidden lines are black. Bank BK_FIX in the
; window, WORK mapped.
edge_glyphs:
	or a
	ld a,(fineK)
	jr nz,.r1
	ld b,a			; row 2: lines < 10-k hidden
	ld a,CL-1
	sub b
	ld (eg_h0),a
	ld a,CL
	ld (eg_h1),a
	ld a,(nu0)
	ld ix,egm0
	ld c,G_E0
	jr .go
.r1:	ld b,a			; row 23: lines >= 11-k hidden
	xor a
	ld (eg_h0),a
	ld a,CL
	sub b
	ld (eg_h1),a
	ld a,(nu1)
	ld ix,egm1
	ld c,G_E1
.go:	or a
	ret z
	ld b,a
	ld a,c
	call glyph_addr
.u:	push bc
	ld l,(ix+0)
	ld h,(ix+1)
	inc ix
	inc ix
	ld c,0			; invert mask
	bit 7,h
	jr z,.ni
	res 7,h
	dec c
.ni:	ld a,(eg_h0)		; hidden lines at the top
	or a
	jr z,.nz0
	ld b,a
	add a,l
	ld l,a
	xor a
.z0:	ld (de),a
	inc de
	djnz .z0
.nz0:	ld a,(eg_h0)		; shown lines
	ld b,a
	ld a,(eg_h1)
	sub b
	ld b,a
.k:	ld a,(hl)
	xor c
	ld (de),a
	inc hl
	inc de
	djnz .k
	ld a,(eg_h1)		; hidden lines at the foot
	cp CL
	jr z,.nz1
	neg
	add a,CL
	ld b,a
	xor a
.z1:	ld (de),a
	inc de
	djnz .z1
.nz1:	ld a,e
	add a,16-CL
	ld e,a
	jr nc,$+3
	inc d
	pop bc
	djnz .u
	ret
eg_h0	db 0			; shown lines: eg_h0 <= line < eg_h1
eg_h1	db 0

; copy a 40-cell row between a shadow array and a video window, split
; where the row wraps round the 2K ring: HL = ring offset, B = source
; high base (70h SHC, 78h SHA, 68h SHK), C = destination high base
; (F0h screen/attr, F8h colour)
rcopy:	ld (rc_off),hl
	ld a,h
	cp 7
	jr c,.one		; below 700h: no wrap possible
	ld a,l
	cp $100-SCOLS+1
	jr c,.one		; ends before 800h
	neg			; first part: 800h - offset
	jr .two
.one:	ld a,SCOLS
.two:	ld (rc_n1),a
	ld a,h
	or c
	ld d,a
	ld e,l
	ld a,h
	or b
	ld h,a
	push bc
	ld a,(rc_n1)
	ld c,a
	ld b,0
	ldir
	pop bc
	ld a,(rc_n1)
	cp SCOLS
	ret z
	ld h,b			; the rest from offset 0
	ld l,0
	ld d,c
	ld e,0
	neg
	add a,SCOLS
	ld c,a
	ld b,0
	ldir
	ret
rc_off	dw 0
rc_n1	db 0

; point the cells of display row A (EROW0 or EROW1) at their edge
; glyphs: codes, attributes, colours (from the shadows)
edge_codes:
	ld (ec_row),a
	cp EROW0
	ld b,G_E0
	ld de,eu0
	jr z,.r
	ld b,G_E1
	ld de,eu1
.r:	ld a,b
	ld (.base+1),a
	ld a,(ec_row)
	call ring_row
	ld (ec_off),hl
	ld c,SCOLS		; codes
.c1:	ld a,h
	and 7
	or $F0
	ld h,a
	ld a,(de)
.base:	add a,0
	ld (hl),a
	inc hl
	inc de
	dec c
	jr nz,.c1
	ld a,LV_ATTR		; banks: copy a row of BK_FIX
	out (P_LV),a
	ld hl,(ec_off)
	ld b,SCOLS
.c2:	ld a,h
	and 7
	or $F0
	ld h,a
	ld (hl),BK_FIX
	inc hl
	djnz .c2
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON		; colours from the shadow, black paper
	out (P_COLCTL),a
	ld hl,(ec_off)
	ld b,SCOLS
.c3:	ld a,h
	and 7
	or $68
	ld h,a
	ld a,(hl)
	call edge_colour
	set 7,h
	set 4,h
	ld (hl),a
	inc hl
	djnz .c3
	xor a
	out (P_COLCTL),a
	ret
; colour A of a cell on an edge row: a coloured paper becomes the ink
; over black (the glyph is inverted to match)
edge_colour:
	cp $10
	ret c
	rrca
	rrca
	rrca
	rrca
	and $0F
	ret
ec_row	db 0
ec_off	dw 0
em_inv	db 0

; display row A back to the scenery from the shadows
row_restore:
	call ring_row
	ld (ec_off),hl
	ld bc,$70F0
	call rcopy		; codes
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,(ec_off)
	ld bc,$78F0
	call rcopy		; banks
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,(ec_off)
	ld bc,$68F8
	call rcopy		; colours
	xor a
	out (P_COLCTL),a
	ret

; ---------------------------------------------------------------------
;  STARS: glyphs G_STAR.. hold far and middle stars. Each frame their
;  rows are rotated up against the scroll, so those stars drift down
;  at a half or three quarters of the scenery's speed (parallax). Their
;  mirror copies are kept in step (sprites and edges draw from them).
;  star_tab: per glyph its mirror offset; star_src: 11 lines each.
; ---------------------------------------------------------------------
star_update:			; WORK mapped; textures are stored twice over
	ld ix,star_tab		; (88 bytes) so any 11-line window is in one run
	ld b,N_STARS
.g:	ld e,(ix+0)		; mirror offset
	ld d,(ix+1)
	ld l,(ix+2)		; texture
	ld h,(ix+3)
	ld a,(st_ph0)
	add a,(ix+4)		; + 11 * (map row mod 4)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld c,CL
	ld a,b
	ld b,0
	ldir
	ld b,a
	ld de,5
	add ix,de
	djnz .g
	ret
; advance the far stars by half of A lines of scroll (phase mod 44)
star_phase:
	srl a
	ld b,a
	ld a,(st_ph0)
	add a,b
	cp 44
	jr c,$+4
	sub 44
	ld (st_ph0),a
	ret
; write the star glyphs from their mirror copies (bank BK_FIX in the
; window, WORK mapped)
star_glyphs:
	ld ix,star_tab
	ld a,G_STAR
	ld (sg_code),a
	ld b,N_STARS
.g:	push bc
	ld l,(ix+0)
	ld h,(ix+1)
	ld a,(sg_code)
	call glyph_addr
	inc a
	ld (sg_code),a
	ld bc,CL
	ldir
	ld de,5
	add ix,de
	pop bc
	djnz .g
	ret
sg_code	db 0
; A mod 11 (A = 0..255)
mod11:	sub CL
	jr nc,mod11
	add a,CL
	ret
