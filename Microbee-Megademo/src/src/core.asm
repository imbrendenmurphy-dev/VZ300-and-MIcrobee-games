; =====================================================================
;  CORE: start-up, banking, keyboard, video RAM helpers
; =====================================================================

hw_init:
	di
	ld hl,vars_start
	ld de,vars_start+1
	ld bc,vars_end-vars_start-1
	ld (hl),0
	ldir
	ld a,LP>>8
	ld (lp_live),a
	ld a,(LP>>8)+4
	ld (lp_build),a
	ld a,64
	ld (r1val),a
	ld hl,$3A71
	ld (rseed),hl
	MEMV 1
	; PIO A: input (joystick), no interrupts
	ld a,$CF
	out (P_PIOAC),a
	ld a,$FF
	out (P_PIOAC),a
	ld a,$07
	out (P_PIOAC),a
	; PIO B: bit control, b6 speaker out, no interrupts
	ld a,$CF
	out (P_PIOBC),a
	ld a,$BF
	out (P_PIOBC),a
	ld a,$07
	out (P_PIOBC),a
	xor a
	out (P_PIOB),a
	out (P_ROMLAT),a
	im 1
	call crtc_safe
	; music voices silent
	exx
	ld hl,0
	ld de,0
	ld bc,0
	exx
	ld iy,0
	ret

; A = block -> A = port 50h value (ROMs off, video window at F000)
bank_port:
	push bc
	ld b,a
	and 3
	xor 2
	ld c,a
	ld a,b
	and $1C
	rlca
	rlca
	rlca
	or c
	or 4
	pop bc
	ret
map_blk:
	ld (cur_blk),a
	call bank_port
	out (P_MEM),a
	ret

; HL = start, BC = count, E = value
fill:	ld (hl),e
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,fill
	ret

; the video window: screen RAM / attribute RAM / colour RAM / PCG bank A
win_screen:
	xor a
	out (P_COLCTL),a
	ld a,LV_SCREEN
	out (P_LV),a
	ret
win_attr:
	xor a
	out (P_COLCTL),a
	ld a,LV_ATTR
	out (P_LV),a
	ret
win_col:
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	ret
win_pcg:
	and 15
	or LV_SCREEN
	out (P_LV),a
	xor a
	out (P_COLCTL),a
	ret

; ---------------------------------------------------------------------
;  keyboard (6545 light-pen scan, as the boot ROM does)
; ---------------------------------------------------------------------
; A = key code -> NZ if held
key1:	push bc
	ld b,a
	ld a,1
	out (P_ROMLAT),a
	ld a,$12
	out (P_CRTCA),a
	ld a,b
	rrca
	rrca
	rrca
	rrca
	and $03
	out (P_CRTCD),a
	ld a,$13
	out (P_CRTCA),a
	ld a,b
	rlca
	rlca
	rlca
	rlca
	and $F0
	out (P_CRTCD),a
	ld a,$10
	out (P_CRTCA),a
	in a,(P_CRTCD)
	ld a,$1F
	out (P_CRTCA),a
	out (P_CRTCD),a
	nop
	ld b,0
.w:	in a,(P_CRTCA)
	bit 7,a
	jr nz,.d
	djnz .w
.d:	and $40
	push af
	xor a
	out (P_ROMLAT),a
	pop af
	pop bc
	ret

jphl:	jp (hl)
