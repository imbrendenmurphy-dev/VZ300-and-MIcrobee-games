; =====================================================================
;  KERNEL: the cycle-exact raster engine
;
;  Every frame the CPU runs a "line program" (a display list) in step
;  with the 6545: each scanline takes exactly 216 T and is laid out as
;
;     [AUD2 46 T][W 86 T][AUD1 46 T][X 38 T]
;
;  AUD2 / AUD1 play one sample of each music voice (so the music is
;  sampled at 15625 Hz on every line), W is where the line's CRTC
;  register writes happen, X is loop control and the dispatch to the
;  next op. The line program is threaded through SP: each op is a word
;  (its address) followed by its arguments; an op ends with RET, which
;  jumps to the next op. An op starts with exactly 10 T of entry code
;  before its first AUD2 (the previous op's exit path is 28 T, RET
;  included, so X stays 38 T across op boundaries).
;
;  Sync: the kernel starts when the 6545's vertical blanking status
;  bit falls (display start). The sampling loop's latency is up to
;  about 84 T, so the kernel waits a fixed DSYNC T after it and all
;  register writes then land in the NEXT scanline at 45-175 T: the
;  writes of code line k take effect in physical line k+1.
;
;  Registers while the kernel runs (interrupts off):
;    HL' DE'  voice 1 phase / increment      IY, BC'  voice 2 phase / inc
;    SP       the line program               A, F     free in W and X
; =====================================================================

DSYNC	equ 140

; ---- one sample of voice 2 (bass): a 50% square. 46 T
AUD2	MACRO
	exx
	add iy,bc
	ld a,iyh
	rra
	out (P_SPK),a
	exx
	ENDM

; ---- one sample of voice 1 (lead): a 25% pulse (gritty). 46 T
AUD1	MACRO
	exx
	add hl,de
	ld a,h
	add a,a
	and h
	rra
	out (P_SPK),a
	exx
	ENDM

; ---------------------------------------------------------------------
;  kernel_run: wait for the display to start (playing the music while
;  waiting), then run the line program at LP. Returns after op_end.
; ---------------------------------------------------------------------
kernel_run:
	di
	ld (ksp),sp
	ld a,(lp_live)
	ld h,a
	ld l,0
	ld sp,hl
	ld c,P_CRTCA
	; the vertical blanking should be on (the bottom row has ended). If
	; the display is on, either the bottom row is still being drawn (it
	; ends within 12 lines) or the work overran into the next frame.
	ld b,80
.chk:	in a,(c)		; 80 x 39 T = 14 lines

	and $20
	jr nz,.ok		; in the vertical blanking: fine
	djnz .chk
	; overrun: the 6545 is running the bottom row's 4-row frame again.
	; Make it a standard 313-line frame (it is early in its first rows),
	; then sync to the next.
	ld hl,overruns
	inc (hl)
	ld hl,crtc_std+4
	ld b,4
	ld e,4
.or:	out (c),e
	ld a,(hl)
	out (P_CRTCD),a
	inc hl
	inc e
	djnz .or
	ld a,9
	out (c),a
	ld a,15
	out (P_CRTCD),a
.wv:	in a,(c)
	and $20
	jr z,.wv
.ok:	; the bottom row is over: the top row's address for the next frame
	ld hl,(s1_addr)
	ld a,12
	out (c),a
	ld a,h
	out (P_CRTCD),a
	ld a,13
	out (c),a
	ld a,l
	out (P_CRTCD),a
.wd:	AUD2			; 46
	in a,(P_CRTCA)		; 28
	and $20
	jp z,.go
	in a,(c)		; 29
	and $20
	jp z,.go
	in a,(c)		; 29
	and $20
	jp z,.go
	AUD1			; 46
	in a,(P_CRTCA)		; 28
	and $20
	jp z,.go
	jp .wd			; 10
.go:	DELAY DSYNC
	ret

; ---------------------------------------------------------------------
;  OPS
; ---------------------------------------------------------------------

; op_end: leave the kernel
op_end:	ld sp,(ksp)
	ret

; op_sync: re-synchronise mid-frame on the vertical blanking status
; rising (a sub-frame with R6 = 0 starting), after work whose timing
; drifts (the Premium holds the CPU on video RAM accesses). The next op's
; writes then land in the line after the edge, as after kernel_run's
; sync. Gives up after about 40 lines.
op_sync: ld c,P_CRTCA
	ld a,40
	ld ixl,a
.w:	AUD2
	in a,(c)		; 29
	and $20
	jp nz,.go
	in a,(c)		; 29
	and $20
	jp nz,.go
	dec ixl			; 18
	jp z,.go
	DELAY 10
	AUD1
	in a,(P_CRTCA)		; 28
	and $20
	jp nz,.go
	jp .w			; 10
.go:	DELAY DSYNC
	ret

; op_w2: one line, two register writes. args: (reg | val << 8) x 2
op_w2:	jp .e			; 10 entry
.e:	AUD2
	pop de			; 10
	ld a,e			; 4
	out (P_CRTCA),a		; 11
	ld a,d			; 4
	out (P_CRTCD),a		; 11
	pop de			; 10
	ld a,e			; 4
	out (P_CRTCA),a		; 11
	ld a,d			; 4
	out (P_CRTCD),a		; 11
	inc de			; 6  = 86
	AUD1
	DELAY 18
	ret			; 28

; op_idle: n lines (n >= 1), music only. args: n
; op_vcopy: copy 4 bytes a line (one LDI burst), (lines - 1) x 4 bytes.
; args: source, destination, lines (low byte)
op_vcopy: jp .e
.e:	AUD2
	pop hl			; 10
	pop de			; 10
	pop ix			; 14
	DELAY 52
	AUD1
	dec ixl			; 8
	jp z,.x			; 10
	DELAY 10
	jp .l			; 10
.l:	AUD2
	ldi			; 64: the burst
	ldi
	ldi
	ldi
	DELAY 22
	AUD1
	dec ixl			; 8
	jp z,.x			; 10
	DELAY 10
	jp .l			; 10
.x:	ret			; 18 + 10 = 28

op_idle: jp .e
.e:	AUD2
	pop hl			; 10  L = lines
	DELAY 76
	AUD1
	dec l			; 4
	jp z,.x			; 10
	DELAY 14
	jp .l			; 10
.l:	AUD2
	DELAY 86
	AUD1
	dec l
	jp z,.x
	DELAY 14
	jp .l
.x:	nop			; 4+10+4+10 = 28
	ret

; op_rlala: per-line start address from an index. 1 + m lines.
; args: (m | page << 8), then m words whose high bytes are 2 x index into
; the page-aligned table at page: [R12, R13] pairs. Line 1 sets up; loop
; line j writes table entry j-2, which takes effect for the following
; line (the frame that starts there).
op_rlala: jp .e
.e:	AUD2
	pop hl			; 10 L = m, H = page
	ld a,l			; 4
	ld ixl,a		; 8
	ld de,$0C0D		; 10 D = 12, E = 13
	ld c,P_CRTCA		; 7
	DELAY 47
	AUD1
	DELAY 28
	jp .l			; 10
.l:	AUD2
	pop af			; 10  A = 2 x index
	ld l,a			; 4
	out (c),d		; 12  select R12
	inc c			; 4
	outi			; 16  R12 = (hl)
	dec c			; 4
	out (c),e		; 12  select R13
	inc c			; 4
	outi			; 16  R13 = (hl)
	dec c			; 4   = 86
	AUD1
	dec ixl			; 8
	jp z,.x			; 10
	DELAY 10
	jp .l			; 10
.x:	ret			; 8+10+10 = 28

; op_rlal: per-line start address, given directly. 1 + m lines.
; args: m, then m words (R12 value, R13 value)
op_rlal: jp .e
.e:	AUD2
	pop hl			; 10
	ld a,l			; 4
	ld ixl,a		; 8
	ld hl,$0C0D		; 10 H = 12, L = 13
	ld c,P_CRTCA		; 7
	DELAY 47
	AUD1
	DELAY 28
	jp .l
.l:	AUD2
	pop de			; 10
	out (c),h		; 12
	inc c			; 4
	out (c),e		; 12
	dec c			; 4
	out (c),l		; 12
	inc c			; 4
	out (c),d		; 12
	dec c			; 4  = 74
	DELAY 12
	AUD1
	dec ixl
	jp z,.x
	DELAY 10
	jp .l
.x:	ret

; op_stream: copy 5 bytes a line from (st_src) to (st_dst); m + 2 lines,
; 5m + 3 bytes. args: m (>= 1). The source must be mapped (lower window)
; and the video window set up by the part.
op_stream: jp .e
.e:	AUD2
	ld hl,(st_src)		; 16
	ld de,(st_dst)		; 20
	pop bc			; 10
	ld ixl,c		; 8
	ldi			; 16
	DELAY 16		; 86
	AUD1
	DELAY 28
	jp .l
.l:	AUD2
	ldi			; 80
	ldi
	ldi
	ldi
	ldi
	inc bc			; 6
	AUD1
	dec ixl
	jp z,.z
	DELAY 10
	jp .l
.z:	DELAY 20		; 18 + 20 = 38
	AUD2
	ldi			; 32
	ldi
	ld (st_src),hl		; 16
	ld (st_dst),de		; 20
	DELAY 18
	AUD1
	DELAY 18
	ret

; ---------------------------------------------------------------------
;  LINE PROGRAM BUILDER (vblank code). The program is built at page
;  (lp_build) and goes live with lp_swap (two buffers, so a part may build
;  the next frame's program while this one runs).
;  HL = the write pointer (lpp) between calls.
; ---------------------------------------------------------------------
lp_begin:
	ld a,(lp_build)
	ld h,a
	ld l,0
	ld (lpp),hl
	ret
lp_swap:
	ld a,(lp_build)
	ld b,a
	ld a,(lp_live)
	ld (lp_build),a
	ld a,b
	ld (lp_live),a
	ret

; build the same (static) line program into both buffers: HL = builder
lp_both:
	ld (.b1+1),hl
	ld (.b2+1),hl
.b1:	call 0
	call lp_swap
.b2:	call 0
	jp lp_swap

; append word DE
lp_word:
	ld hl,(lpp)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (lpp),hl
	ret

; two writes: L = reg1, H = val1, E = reg2, D = val2
lp_w2:	push de
	push hl
	ld de,op_w2
	call lp_word
	pop de
	call lp_word
	pop de
	jp lp_word

; one write: L = reg, H = val (the other is a harmless R15 write)
lp_w1:	ld de,15
	jr lp_w2

; idle: A = lines
lp_idle: push af
	ld de,op_idle
	call lp_word
	pop af
	ld e,a
	ld d,0
	jp lp_word

; per-line index table: A = m (table lines), B = table page.
; -> HL = where the m words go (high bytes = 2 x index)
lp_rlala:
	push af
	push bc
	ld de,op_rlala
	call lp_word
	pop bc
	pop af
	ld e,a
	ld d,b
	push af
	call lp_word
	pop af
	ld hl,(lpp)
	push hl
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,de
	ld (lpp),hl
	pop hl
	ret

; direct addresses: A = m -> HL = where the m words go
lp_rlal:
	push af
	ld de,op_rlal
	call lp_word
	pop af
	ld e,a
	ld d,0
	push af
	call lp_word
	pop af
	ld hl,(lpp)
	push hl
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,de
	ld (lpp),hl
	pop hl
	ret

; stream: A = m (5m + 3 bytes, m + 2 lines)
lp_stream:
	push af
	ld de,op_stream
	call lp_word
	pop af
	ld e,a
	ld d,0
	jp lp_word

lp_end:	ld de,op_end
	jp lp_word

; ---- the standard frame frame-work (see docs/HANDOVER.md)
; Code lines 0-2: the top row S1 (lines 0-15, 16-line row). A = S1 rows.
lp_top:	dec a
	ld (.r4+2),a
	ld hl,R5+0*256
	ld de,R6+$7F*256
	call lp_w2
.r4:	ld de,R4+0*256
	ld hl,R7+$7F*256
	call lp_w2
	ld a,(r1val)
	ld h,a
	ld l,R1
	ld de,R15
	jp lp_w2

; Code lines 239-241: the bottom row F (lines 240-255) and the border,
; vsync at line 288. HL = start address for the next frame's S1.
; NB the Premium's 6545 re-reads R12/R13 at the start of every line of a
; frame's first character row: a frame's address may only change in its
; last line (or after its first row), so S1's is set in the blanking.
lp_bottom:
	ld (s1_addr),hl		; written by kernel_run once the bottom row is over
	ld hl,R9+15*256
	ld de,R4+3*256
	call lp_w2
	ld hl,R5+9*256
	ld de,R6+1*256
	call lp_w2
	ld hl,R7+3*256
	ld de,R15
	call lp_w2
	ld a,KEND-242
	call lp_idle
	jp lp_end

R1	equ 1
R4	equ 4
R5	equ 5
R6	equ 6
R7	equ 7
R9	equ 9
R12	equ 12
R13	equ 13
R15	equ 15
KEND	equ 244			; code lines run by the kernel each frame

; ---------------------------------------------------------------------
;  crtc_park: call right after kernel_run. Waits for the next frame to
;  start, then makes it (and the ones after it) standard 313-line frames
;  with the display blanked, so long work can follow (the next
;  kernel_run picks up from there). Silent: about one frame.
; ---------------------------------------------------------------------
crtc_park:
	ld c,P_CRTCA
.v1:	in a,(c)		; the vertical blanking
	and $20
	jr z,.v1
.v0:	in a,(c)		; the next frame's display starts
	and $20
	jr nz,.v0
	ld hl,crtc_std+4	; R4-R7 standard (it is in its first row)
	ld e,4
	ld b,4
.r:	out (c),e
	ld a,(hl)
	out (P_CRTCD),a
	inc hl
	inc e
	djnz .r
	ld a,9
	out (c),a
	ld a,15
	out (P_CRTCD),a
	ld a,1
	out (c),a
	xor a
	out (P_CRTCD),a		; R1 = 0: blank
	ret

; ---------------------------------------------------------------------
;  the "safe" standard 64 x 16 frame (313 lines), display blanked by
;  R1 = 0. Used outside the kernel (start-up, long set-ups).
; ---------------------------------------------------------------------
crtc_safe:
	ld hl,crtc_std
	ld c,0
.l:	ld a,c
	out (P_CRTCA),a
	ld a,(hl)
	out (P_CRTCD),a
	inc hl
	inc c
	ld a,c
	cp 16
	jr nz,.l
	ret
crtc_std:	db $6B,$00,$51,$37,$12,$09,$10,$12,$48,$0F,$20,$0F,$00,$00,$00,$00
crtc_text:	; the same with the display on
	ld a,R1
	out (P_CRTCA),a
	ld a,64
	out (P_CRTCD),a
	ret
