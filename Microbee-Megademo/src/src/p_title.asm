; =====================================================================
;  PART: TITLE - the logo falls and bounces (FLD: a gap of blank lines
;  of any height above it, no copying), copper bars (one-line splits)
;  and a smooth scroller (4 pre-shifted copies chosen by the CRTC).
;
;  Physical lines: 0-15 top row (blank), 16..L0-1 the gap, L0..L0+79
;  the logo (5 rows), then one-line frames to 239 (the bars), 240-255
;  the scroller.
; =====================================================================
G0	equ 28			; the logo's resting gap (lines)
GMIN	equ 15			; the gap is 5 chunks of 3 lines or more
GMAX	equ 140

pt_g	equ pv+0		; gap, 8.8
pt_v	equ pv+2		; its speed, 8.8 signed
pt_t	equ pv+4		; frames
pt_pos	equ pv+6		; scroll position (pixels)
pt_crs	equ pv+8		; last coarse position
pt_tp	equ pv+10		; text pointer: the next column to render
pt_bph	equ pv+12		; bar phase
pt_tab	equ pv+14		; this frame's index table
pt_m	equ pv+16
pt_b0	equ pv+17		; first table-driven line
pt_l0	equ pv+18
pt_bars	equ pv+20

title_part:
	dw title_jobs, title_init, title_frame, ORD_TWISTER

title_init:
	ld hl,GMIN*256
	ld (pt_g),hl
	ld hl,scroll_text+64
	ld (pt_tp),hl
	ld hl,t_bars_c
	ld a,(monomode)
	or a
	jr z,.c
	ld hl,t_bars_m
.c:	ld (pt_bars),hl
	ld hl,T_BLANK
	ld (s1_addr),hl
	jp title_template

title_frame:
	ld hl,(pt_t)
	inc hl
	ld (pt_t),hl
	call title_move
	call title_scroll
	; ---- patch the template line program (in the build buffer)
	ld a,(lp_build)
	ld ixh,a
	ld ixl,TT_CH0
	; the gap g in 5 chunks of g/5 (+1 for the first g mod 5)
	ld a,(pt_g+1)
	ld l,a
	ld h,t_div5>>8
	ld b,(hl)		; B = g / 5
	ld c,b
	sla c
	sla c			; C = 4B
	sub c
	sub b			; A = g - 5B
	ld c,a
	ld l,5
.ch:	ld a,b
	dec c
	jp m,.nx
	inc a
.nx:	push af
	dec a
	ld (ix+TT_R9V-TT_CH0),a	; this chunk's R9 = lines - 1 (IX walks the chunks)
	pop af
	sub 2
	ld (ix+TT_IDN-TT_CH0),a	; idle lines
	ld de,TT_CHSZ
	add ix,de
	dec l
	jr nz,.ch
	; the index table: m = 158 - L0 entries (L0 = 16 + g)
	ld a,(pt_g+1)
	add a,16
	ld (pt_l0),a
	add a,83
	ld (pt_b0),a
	ld a,(pt_l0)
	ld b,a
	ld a,158
	sub b
	ld (pt_m),a
	ld a,(lp_build)
	ld h,a
	ld l,TT_RLM
	ld a,(pt_m)
	ld (hl),a		; op_rlala's m
	ld l,TT_TAB
	ld (pt_tab),hl
	; the bottom after the table: copy the template
	ld a,(pt_m)
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,de
	ex de,hl		; DE = the end of the table
	ld hl,tt_bottom
	ld bc,tt_bottom_end-tt_bottom
	ldir
	jp title_bars

; ---- the template line program (both buffers, at init)
title_template:
	call .one
	call lp_swap
	call .one
	jp lp_swap
.one:	call lp_begin
	ld a,1
	call lp_top		; phys 1-3
	ld a,11
	call lp_idle		; 4-14
	ld hl,R12+(T_BLANK>>8)*256
	ld de,R13+(T_BLANK&255)*256
	call lp_w2		; 15 (the top row's last line): the gap is blank
	ld b,5
.c:	push bc
	ld hl,R9+2*256
	call lp_w1		; the chunk's first line: its height
	ld a,1
	call lp_idle		; (patched)
	pop bc
	push bc
	ld a,b
	cp 1
	ld hl,R12+(T_BLANK>>8)*256
	ld de,R13+(T_BLANK&255)*256
	jr nz,.cb
	ld hl,R12+(T_LOGO>>8)*256
	ld de,R13+(T_LOGO&255)*256
.cb:	call lp_w2		; its last line: the next address
	pop bc
	djnz .c
	ld hl,R9+15*256
	ld de,R4+4*256
	call lp_w2		; the logo's first line
	ld a,78
	call lp_idle
	ld hl,R12+(T_BLANK>>8)*256
	ld de,R13+(T_BLANK&255)*256
	call lp_w2		; its last line: the bars' start
	ld hl,R9+0*256
	ld de,R4+0*256
	call lp_w2		; phys L0+80: one-line frames
	ld a,1
	ld b,t_coptab>>8
	jp lp_rlala

; template offsets (bytes from the buffer start): lp_top = 3 x 6,
; idle 4, w2 6 -> the chunks start at 28; a chunk = w1 6 + idle 4 + w2 6
TT_CH0	equ 28
TT_CHSZ	equ 16
TT_R9V	equ TT_CH0+3		; the R9 value byte in a chunk's first w2
TT_IDN	equ TT_CH0+8		; the idle count
TT_RLM	equ TT_CH0+5*TT_CHSZ+6+4+6+6+2	; op_rlala's m
TT_TAB	equ TT_RLM+2

; the bottom: lp_bottom with S1 = the blank row
tt_bottom:
	dw op_w2, R9+15*256, R4+3*256
	dw op_w2, R5+9*256, R6+1*256
	dw op_w2, R7+3*256, R15
	dw op_idle, KEND-242
	dw op_end
tt_bottom_end:

; ---- the logo's motion
title_move:
	ld hl,(pt_t)
	ld de,170
	or a
	sbc hl,de
	jr nc,.spring
	; falling: v += 0.16, bounce off the floor
	ld hl,(pt_v)
	ld de,40
	add hl,de
	ld (pt_v),hl
	ld de,(pt_g)
	add hl,de
	ld de,GMAX*256
	push hl
	or a
	sbc hl,de
	pop hl
	jr c,.st
	ld hl,(pt_v)		; v = -(v - v/4)
	ld d,h
	ld e,l
	call sra_hl2
	ex de,hl
	or a
	sbc hl,de
	call neg_hl
	ld (pt_v),hl
	ld hl,GMAX*256
.st:	ld (pt_g),hl
	ret
.spring: ; v += (G0 - g) / 16 - v / 8, plus a hop on each kick drum
	ld hl,G0*256
	ld de,(pt_g)
	or a
	sbc hl,de
	call sra_hl4
	ex de,hl
	ld hl,(pt_v)
	add hl,de
	push hl
	call sra_hl2
	call sra_hl1
	ex de,hl
	pop hl
	or a
	sbc hl,de
	; the kick: a hop
	ld a,(m_drum)
	cp 1
	jr z,.k
	cp 4
	jr nz,.nk
.k:	ld a,(m_dt)
	cp 1
	jr nz,.nk
	ld de,-200
	add hl,de
.nk:	ld (pt_v),hl
	ld de,(pt_g)
	add hl,de
	; clamp GMIN..GMAX
	bit 7,h
	jr nz,.lo
	ld a,h
	cp GMIN
	jr c,.lo
	cp GMAX
	jr c,.ok
	ld hl,GMAX*256
	jr .ok
.lo:	ld hl,GMIN*256
.ok:	ld (pt_g),hl
	ret

neg_hl:	xor a
	sub l
	ld l,a
	sbc a,a
	sub h
	ld h,a
	ret
sra_hl4: sra h
	rr l
sra_hl3: sra h
	rr l
sra_hl2: sra h
	rr l
sra_hl1: sra h
	rr l
	ret

; ---- copper bars into the index table
TB_MAX	equ 20			; the longest bar
title_bars:
	; all blank (pushed: the table's words, high byte = 2 x index) ...
	ld (tb_sp),sp
	ld hl,(pt_tab)
	ld a,(pt_m)
	ld e,a
	ld d,0
	add hl,de
	add hl,de
	ld sp,hl
	ld bc,T_BLANKIX*2*256
	dec a			; the last entry is the scroller
	ld e,a
	ld d,254
	push de			; (the low byte is not used)
	srl a
	jr nc,.c1
	push bc
.c1:	srl a
	jr nc,.c2
	push bc
	push bc
.c2:	srl a
	jr nc,.c2b
	push bc
	push bc
	push bc
	push bc
.c2b:	or a
	jr z,.c4
.c3:	push bc
	push bc
	push bc
	push bc
	push bc
	push bc
	push bc
	push bc
	dec a
	jr nz,.c3
.c4:	ld sp,(tb_sp)
	; ... then the bars. First each bar's depth and first line:
	; tb_list = 5 x (front flag, first line, profile pointer)
	ld a,(pt_bph)
	add a,2
	ld (pt_bph),a
	ld c,a
	ld de,(pt_bars)
	ld ix,tb_list
	ld b,T_NBARS
.pre:	ld h,sin_tab>>8
	ld a,c
	add a,64
	ld l,a
	ld a,(hl)
	rlca
	and 1
	xor 1
	ld (ix+0),a		; 1 = in front
	ld l,c
	inc h			; t_bcentre follows sin_tab
	ld h,(hl)		; the centre line
	ld a,(de)		; length
	srl a
	neg
	add a,h
	ld (ix+1),a		; first line
	ld (ix+2),e
	ld (ix+3),d
	ld a,(de)
	inc a
	add a,e
	ld e,a
	jr nc,$+3
	inc d			; next profile
	ld a,c
	add a,51
	ld c,a
	push de
	ld de,4
	add ix,de
	pop de
	djnz .pre
	ld c,0
	call .pass
	ld c,1
.pass:	ld ix,tb_list
	ld b,T_NBARS
.bar:	push bc
	ld a,(ix+0)
	cp c
	jp nz,.skip
	ld e,(ix+2)
	ld d,(ix+3)
	ld a,(de)
	ld c,a			; length
	inc de			; DE = profile
	ld a,(ix+1)		; first line
	; clip the top: skip lines above b0
	ld hl,pt_b0
	sub (hl)		; A = first line - b0
	jr nc,.top
	; skip -A lines
	neg
	cp c
	jr nc,.skip
	ld b,a
	add a,e
	ld e,a
	jr nc,$+3
	inc d
	ld a,c
	sub b
	ld c,a
	xor a
.top:	; clip the bottom: lines b0 + A .. +C-1 must be < 240
	ld b,a
	ld a,(pt_b0)
	add a,b
	add a,c
	sub 240
	jr c,.nb
	ld h,a
	ld a,c
	sub h
	jr z,.skip
	jr c,.skip
	ld c,a
.nb:	; HL = tab + 2 B + 1
	ld l,b
	ld h,0
	add hl,hl
	ld a,(pt_tab)
	add a,l
	ld l,a
	ld a,(pt_tab+1)
	adc a,h
	ld h,a
	inc hl
	ex de,hl		; HL = profile, DE = table entry
	; C lines: jump into the unrolled LDI / INC DE run
	ld a,TB_MAX
	sub c
	ld c,a
	add a,a
	add a,c			; 3 bytes a line
	ld (.jr+1),a
	ld b,0			; (LDI decrements BC: harmless)
.jr:	jr $+2
	REPT TB_MAX
	ldi
	inc de
	ENDR
.skip:	ld de,4
	add ix,de
	pop bc
	dec b
	jp nz,.bar
	ret

; ---- the scroller
title_scroll:
	ld hl,(pt_t)
	ld a,h
	or a
	jr nz,.go
	ld a,l
	cp 100			; starts after 2 seconds
	ret c
.go:	ld hl,(pt_pos)
	inc hl
	inc hl
	ld (pt_pos),hl
	; coarse = pos >> 3
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld a,l
	ld hl,pt_crs
	cp (hl)
	ld (hl),a
	call nz,title_newcol
	ld a,(pt_pos)
	rrca
	and 3
	call title_render
	; the scroller's address into index 127
	ld hl,(pt_pos)
	ld a,l
	rrca
	and 3			; phase
	ld d,a
	ld e,0
	srl d
	rr e			; DE = phase x 128
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld a,l
	and 63
	add a,e
	ld e,a
	ld hl,T_SCR
	add hl,de
	ld a,h
	ld (t_coptab+254),a
	ld a,l
	ld (t_coptab+255),a
	ret

; a new column enters at the right: coarse + 63 -> slot (coarse + 63) & 63
title_newcol:
	ld a,(pt_crs)
	add a,63
	and 63
	ld (tr_slot),a
	ld hl,(pt_tp)
	ld a,(hl)
	inc hl
	ld b,a
	ld a,(hl)
	or a
	jr nz,.n2
	ld hl,scroll_text
	ld a,(hl)
.n2:	ld (pt_tp),hl
	sub 32
	ld (tr_fb),a		; the right character (font index)
	ld a,b
	sub 32
	ld (tr_fa),a		; the left one
	ret

; render phase A (0-3: 2A pixels) of the column in tr_slot, from the
; pre-shifted font (block SF_BLK): line = left[a] | right[b]
title_render:
	ld c,a
	srl a
	add a,3
	call win_pcg
	ld a,SF_BLK
	call map_blk
	ld a,c
	and 1
	rrca
	rrca			; 0 or 64
	ld b,a
	ld a,(tr_slot)
	or b
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,PCGWIN
	add hl,de
	push hl			; the glyph
	; left: SF_OFF + phase x 4K + a x 16; right: + 2K + b x 16
	ld a,c
	add a,a
	add a,a
	add a,a
	add a,a
	add a,SF_OFF>>8
	ld b,a			; B = high byte of this phase's tables
	ld a,(tr_fa)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,h
	add a,b
	ld h,a
	ex de,hl		; DE = left part
	ld a,(tr_fb)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,h
	add a,b
	add a,8
	ld h,a			; HL = right part
	pop bc			; BC = the glyph
	REPT 16
	ld a,(de)
	or (hl)
	ld (bc),a
	inc e
	inc l
	inc c
	ENDR
	ret

; A = character -> HL = its 16 bytes in font_ram
font_ptr:
	sub 32
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,font_ram
	add hl,de
	ret

scroll_text:
	db "                                                                "
	db "WELCOME TO THE MICROBEE MEGADEMO ... THE FIRST MEGADEMO EVER MADE "
	db "FOR THE MICROBEE PREMIUM PLUS ... VIBED BY BPM 2026 ... "
	db "EVERY SCANLINE YOU SEE IS RE-PROGRAMMED BY THE Z80 WHILE THE 6545 "
	db "IS DRAWING IT ... THE LOGO BOUNCES WITHOUT A SINGLE BYTE BEING COPIED "
	db "AND THESE COPPER BARS ARE ONE-LINE SCREENS STACKED UP 220 HIGH ... "
	db "1 MEGABYTE RAM ... 32K PCG ... ONE BEEPER ... NO EXCUSES ...      "
	db 0
