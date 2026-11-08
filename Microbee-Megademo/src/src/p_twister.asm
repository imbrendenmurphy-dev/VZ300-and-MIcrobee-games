; =====================================================================
;  PART: THE TWISTER - a square bar, twisting and spinning, drawn to the
;  pixel: 30 slices of it (90 degrees) are rows of 64 cells, and every
;  scanline from 16 to 239 is a one-line screen showing the slice for its
;  angle. Per frame only the 222-entry index table changes:
;     angle(y) = shape_k(y + phase) + rotation   (in 3-degree steps)
;  shape_k: precomputed twist profiles (16 amplitudes) in a RAM block.
; =====================================================================
pw_t	equ pv+0		; frames
pw_rot	equ pv+2		; rotation, 8.8 (in slices)
pw_spd	equ pv+4		; rotation speed, 8.8
pw_ph	equ pv+6		; twist phase
pw_k	equ pv+7		; twist amplitude 0-15
pw_cap	equ pv+8		; caption number
pw_kick	equ pv+9
pw_w2	equ pv+10
pw_sp	equ pv+12
tw_end	equ pv+14
pw_tabo	equ pv+16

twister_part:
	dw twister_jobs, twister_init, twister_frame, ORD_PLASMA

twister_init:
	ld hl,$0060
	ld (pw_spd),hl
	ld hl,twister_build
	jp lp_both

; the static line program; the table and line 16's slice change
twister_build:
	call lp_begin
	ld a,1
	call lp_top		; 0-2
	ld a,11
	call lp_idle		; 3-13
	ld hl,R12+0*256
	ld de,R13+0*256
	call lp_w2		; 14 (the top row's last line): line 16's slice
	ld hl,R9+0*256
	call lp_w1		; 15: one-line frames from 16
	ld a,222
	ld b,tw_tab>>8
	call lp_rlala		; 16-238
	ld a,l
	ld (pw_tabo),a		; the table's offset in the buffer
	ld a,h
	and 3
	ld (pw_tabo+1),a
	ld hl,TW_S1
	jp lp_bottom
TWW2	equ 3*6+4+3		; offset of line 14's R12 value

twister_frame:
	ld hl,(pw_t)
	inc hl
	ld (pw_t),hl
	; ---- motion
	; twist amplitude: 0 for 2 s, then 8 + 7 sin(t / 4)
	ld a,h
	or a
	jr nz,.tw
	ld a,l
	cp 100
	ld a,0
	jr c,.ka
.tw:	ld a,l
	srl h
	rra
	srl h
	rra
	ld l,a
	ld h,sin_tab>>8
	ld a,(hl)
	sra a
	sra a
	sra a
	sra a			; -8..7
	add a,8
	cp 16
	jr c,.ka
	ld a,15
.ka:	ld (pw_k),a
	; the phase travels down the bar
	ld a,(pw_ph)
	add a,3
	ld (pw_ph),a
	; rotation: speed eases back to 0.375 slices a frame; a kick spins it
	ld a,(m_drum)
	cp 1
	jr z,.k
	cp 4
	jr nz,.nk
.k:	ld a,(m_dt)
	cp 1
	jr nz,.nk
	ld hl,$0180
	ld (pw_spd),hl
.nk:	ld hl,(pw_spd)
	ld de,-4
	add hl,de
	ld a,h
	or a
	jr nz,.sp
	ld a,l
	cp $60
	jr nc,.sp
	ld hl,$0060
.sp:	ld (pw_spd),hl
	ex de,hl
	ld hl,(pw_rot)
	add hl,de
	; wrap at 30 slices
	ld a,h
	cp TW_N
	jr c,.rw
	sub TW_N
	ld h,a
.rw:	ld (pw_rot),hl
	; ---- the caption changes every 6 seconds
	ld a,(pw_t)
	or a
	jr nz,.nc
	ld a,(pw_t+1)
	and 1
	call z,twister_caption
.nc:	; ---- this frame's table in the build buffer
	ld a,(lp_build)
	ld h,a
	ld l,0
	ld de,(pw_tabo)
	add hl,de
	ld de,444
	add hl,de
	ld (tw_end),hl
	; ---- the table, pushed from the bottom up
	ld a,TW_SHB
	call map_blk
	ld (pw_sp),sp
	ld sp,(tw_end)
	ld a,64*2		; the last entry: the bottom row
	push af
	; shape pointer: TW_SHO + k x 512 + phase + 220
	ld a,(pw_k)
	add a,a
	add a,TW_SHO>>8
	ld h,a
	ld a,(pw_ph)
	ld l,a
	ld de,220
	add hl,de
	ld a,(pw_rot+1)
	add a,a
	ld c,a			; C = 2 x rotation
	ld b,221/13
	ld e,a
.f:	REPT 13
	ld a,(hl)
	dec hl
	add a,c
	push af
	ENDR
	djnz .f
	; HL+1 = entry 0's shape: line 16-18's slice = the same angle
	inc hl
	ld a,(hl)
	add a,c
	ld sp,(pw_sp)
	ld l,a
	ld h,tw_tab>>8
	ld b,(hl)
	inc hl
	ld c,(hl)
	; patch the w2 at code line 3: R12 = B, R13 = C
	ld a,(lp_build)
	ld h,a
	ld l,TWW2
	ld (hl),b
	inc hl
	inc hl
	ld (hl),c
	ret

; the caption row (F): the next of the captions
twister_caption:
	ld a,(pw_cap)
	inc a
	cp 5
	jr c,.c
	xor a
.c:	ld (pw_cap),a
	add a,a
	ld l,a
	ld h,0
	ld de,tw_caps
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	call win_screen
	ld de,VIDEO+TW_F
	ld b,64
.l:	ld a,(hl)
	inc hl
	add a,$80-32
	ld (de),a
	inc de
	djnz .l
	ret

tw_caps: dw tc0, tc1, tc2, tc3, tc4
tc0:	db "     1 PIXEL ACCURATE ... 222 ONE-LINE SCREENS EVERY FRAME      "
tc1:	db "   30 SLICES OF A SQUARE BAR ... THE CRTC PICKS ONE PER LINE    "
tc2:	db "        NO PIXELS ARE DRAWN WHILE IT TWISTS ... NOT ONE         "
tc3:	db "     THE Z80 JUST TELLS THE 6545 WHERE TO LOOK, 15625 TIMES     "
tc4:	db "          A SECOND ... AND PLAYS THE MUSIC IN BETWEEN           "
