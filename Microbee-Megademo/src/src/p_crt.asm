; =====================================================================
;  PARTS: CRT ON / CRT OFF - the picture tube warming up (a dot, a line,
;  the screen) and switching off at the end. Lines 16-239 are one-line
;  screens, each showing a black, white, grey or "dot" row.
; =====================================================================
pc_t	equ pv+0
pc_tab	equ pv+2		; the table's offset in the buffers
pc_sp	equ pv+4
pc_mode	equ pv+6		; 0 on, 1 off
pc_h	equ pv+7
pc_n	equ pv+8

CRT_C	equ 128			; the centre line
CI_BLACK equ 0*2
CI_WHITE equ 1*2
CI_GREY	equ 2*2			; and 3: the other phase
CI_DIM	equ 4*2			; and 5
CI_DOT	equ 6*2
CI_DOT2	equ 7*2

crton_part:
	dw crt_jobs, crton_init, crt_frame, ORD_BOOT
crtoff_part:
	dw crt_jobs, crtoff_init, crt_frame, $FFFF

crton_init:
	xor a
	jr crt_init
crtoff_init:
	ld a,1
crt_init:
	ld (pc_mode),a
	ld hl,0
	ld (s1_addr),hl
	ld hl,crt_build
	jp lp_both

crt_build:
	call lp_begin
	ld a,1
	call lp_top		; 0-2
	ld a,11
	call lp_idle		; 3-13
	ld hl,R12+0*256
	ld de,R13+0*256
	call lp_w2		; 14: black
	ld hl,R9+0*256
	call lp_w1		; 15: one-line frames from 16
	ld a,222
	ld b,crt_tab>>8
	call lp_rlala		; 16-238
	ld a,l
	ld (pc_tab),a
	ld a,h
	and 3
	ld (pc_tab+1),a
	ld hl,0
	jp lp_bottom

crt_frame:
	ld hl,(pc_t)
	inc hl
	ld (pc_t),hl
	ld a,(pc_mode)
	or a
	jp nz,crt_off
	; ---- on
	ld a,h
	or a
	ld a,l
	jr z,.s
	ld a,255
.s:	cp 25
	jr c,.black
	cp 35
	jr c,.dot2
	cp 45
	jr c,.dot
	cp 55
	jr c,.line
	cp 95
	jr c,.grow
	cp 100
	jr c,.white
	cp 112
	jr c,.grey
	cp 124
	jr c,.dim
.black:	ld a,CI_BLACK
	jp crt_fill
.dot2:	ld a,CI_BLACK
	call crt_fill
	ld bc,CI_DOT2*256+CI_DOT2
	ld de,(CRT_C-1)*256+CRT_C+1
	jp crt_band
.dot:	ld a,CI_BLACK
	call crt_fill
	ld bc,CI_DOT*256+CI_DOT
	ld de,(CRT_C-1)*256+CRT_C+1
	jp crt_band
.line:	ld a,CI_BLACK
	call crt_fill
	ld bc,CI_GREY*256+CI_GREY+2
	ld de,(CRT_C-2)*256+CRT_C+2
	call crt_band
	ld bc,CI_WHITE*256+CI_WHITE
	ld de,(CRT_C)*256+CRT_C
	jp crt_band
.grow:	; h = 112 x ((t - 55) / 40)^2 (an ease-in)
	sub 55
	ld e,a
	ld h,0
	ld l,a
	call mul8		; HL = (t-55)^2, 0..1521
	; h = HL x 112 / 1600 ~ HL / 14
	ld c,14
	call div16_8
	ld a,l
	cp 112
	jr c,.h
	ld a,112
.h:	jp crt_h
.white:	ld a,CI_WHITE
	jp crt_fill
.grey:	ld a,CI_BLACK
	call crt_fill
	ld bc,CI_GREY*256+CI_GREY+2
	ld de,19*256+239
	jp crt_band
.dim:	ld a,CI_BLACK
	call crt_fill
	ld bc,CI_DIM*256+CI_DIM+2
	ld de,19*256+239
	jp crt_band

crt_off:
	ld a,h
	or a
	ld a,l
	jr z,.s
	ld a,255
.s:	cp 8
	jr c,.white
	cp 48
	jr c,.shrink
	cp 56
	jr c,.line
	cp 70
	jr c,.dot
	cp 90
	jr c,.dot2
	; black, then the end
	ld a,(pc_t)
	cp 200
	jr c,.bl
	ld a,1
	ld (pv_done),a
.bl:	ld a,CI_BLACK
	jp crt_fill
.white:	ld a,CI_WHITE
	jp crt_fill
.shrink: ; h = 112 x (48 - t) / 40, squared for an ease-out
	ld b,a
	ld a,48
	sub b			; 1..40
	ld l,a
	ld h,0
	call mul8
	ld c,14
	call div16_8
	ld a,l
	jp crt_h
.line:	jp crton_line
.dot:	ld a,CI_BLACK
	call crt_fill
	ld bc,CI_DOT*256+CI_DOT
	ld de,(CRT_C-1)*256+CRT_C+1
	jp crt_band
.dot2:	ld a,CI_BLACK
	call crt_fill
	ld bc,CI_DOT2*256+CI_DOT2
	ld de,(CRT_C)*256+CRT_C
	jp crt_band
crton_line:
	ld a,CI_BLACK
	call crt_fill
	ld bc,CI_GREY*256+CI_GREY+2
	ld de,(CRT_C-2)*256+CRT_C+2
	call crt_band
	ld bc,CI_WHITE*256+CI_WHITE
	ld de,(CRT_C)*256+CRT_C
	jp crt_band

; a white band of half-height A around the centre, grey glow at its edges
; (only the 2 lines each side: the vertical blanking is short)
crt_h:	ld (pc_h),a
	ld a,CI_BLACK
	call crt_fill
	ld a,(pc_h)
	ld b,a
	ld a,CRT_C
	sub b
	ld d,a
	ld a,CRT_C
	add a,b
	ld e,a
	push de
	ld bc,CI_WHITE*256+CI_WHITE
	call crt_band
	pop de
	push de
	ld a,d
	sub 2
	jr nc,.u
	xor a
.u:	ld d,a
	add a,1
	ld e,a
	ld bc,CI_GREY*256+CI_GREY+2
	call crt_band
	pop de
	ld a,e
	inc a
	ld d,a
	add a,1
	ld e,a
	ld bc,CI_GREY*256+CI_GREY+2
	jp crt_band

; the whole table (lines 19-239) index A, the bottom row black
crt_fill:
	ld (pc_sp),sp
	push af
	ld a,(lp_build)
	ld h,a
	ld l,0
	ld de,(pc_tab)
	add hl,de
	ld de,444
	add hl,de
	pop af
	ld sp,hl
	ld b,a
	ld c,0
	ld de,CI_BLACK*256
	push de			; entry 221: the bottom row
	ld a,221/13
.f:	REPT 13
	push bc
	ENDR
	dec a
	jr nz,.f
	ld sp,(pc_sp)
	ret

; lines D..E (clipped to 19-239): index B on even lines, C on odd ones
crt_band:
	ld a,d
	cp 19
	jr nc,.lo
	ld d,19
.lo:	ld a,e
	cp 240
	jr c,.hi
	ld e,239
.hi:	ld a,e
	sub d
	ret c
	inc a
	ld (pc_n),a
	; entry address: table + 2 (D - 19) + 1
	ld a,(lp_build)
	ld h,a
	ld l,0
	push de
	ld de,(pc_tab)
	add hl,de
	pop de
	ld a,d
	sub 19
	push de
	ld e,a
	ld d,0
	add hl,de
	add hl,de
	pop de
	inc hl
	ld a,(pc_n)
	ld e,a
	bit 0,d
	jr z,.l
	ld a,b			; start on an odd line: swap the phases
	ld b,c
	ld c,a
.l:	ld (hl),b
	inc hl
	inc hl
	dec e
	ret z
	ld (hl),c
	inc hl
	inc hl
	dec e
	jr nz,.l
	ret

; HL = L x L (8-bit square)
mul8:	ld e,l
	ld d,0
	ld b,8
	ld a,l
	ld hl,0
.m:	add hl,hl
	rla
	jr nc,.n
	add hl,de
.n:	djnz .m
	ret
