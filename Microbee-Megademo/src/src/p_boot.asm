; =====================================================================
;  PART: BOOT - a terminal types out the machine's self-test (with what
;  the 6545 taught us), then the picture tears apart. 14 text rows, each
;  its own screen (a one-row frame), so each can be moved on its own.
; =====================================================================
pb_t	equ pv+0
pb_ptr	equ pv+2		; the script
pb_pos	equ pv+4		; where the next character goes (screen RAM)
pb_wait	equ pv+6
pb_cur	equ pv+8		; cursor position
pb_g	equ pv+10		; glitch strength

bt_part:
	dw boottext_jobs, boot_init, boot_frame, ORD_TITLE

boot_init:
	ld hl,boot_script
	ld (pb_ptr),hl
	ld hl,B_BLANK
	ld (s1_addr),hl
	ld hl,boot_build
	jp lp_both

; lp_top, idle 11, then row k (k = 0-13, lines 16 + 16k ..): idle 15 and
; in its last line the next row's address (the last: the bottom row)
boot_build:
	call lp_begin
	ld a,1
	call lp_top		; 0-2
	ld a,11
	call lp_idle		; 3-13
	ld hl,R12+0*256
	ld de,R13+0*256
	call lp_w2		; 14: row 0
	ld b,14
	ld c,1
.r:	push bc
	ld a,15
	call lp_idle
	pop bc
	push bc
	ld a,c
	cp 14
	jr nz,.n
	ld a,B_BLANK>>6
.n:	ld l,a
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
	pop bc
	inc c
	djnz .r
	ld hl,B_BLANK
	jp lp_bottom
BT_W0	equ 3*6+4+3		; row 0's R12 value byte; row k+1's at BT_W0 + 10 (k+1)

boot_frame:
	ld hl,(pb_t)
	inc hl
	ld (pb_t),hl
	call win_screen
	ld hl,(pb_cur)		; take the cursor away first
	ld de,VIDEO
	add hl,de
	ld (hl),$80
	; ---- typing
	ld a,(pb_wait)
	or a
	jr z,.ty
	dec a
	ld (pb_wait),a
	jr .cur
.ty:	ld hl,(pb_ptr)
	ld a,(hl)
	inc hl
	or a
	jr z,.cur		; the end of the script
	cp 1
	jr nz,.ch
	; 1, row, col: move; 2, n: pause n frames
	ld a,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld (pb_ptr),hl
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld d,0
	add hl,de
	ld (pb_pos),hl
	jr .cur
.ch:	cp 2
	jr nz,.put
	ld a,(hl)
	inc hl
	ld (pb_ptr),hl
	ld (pb_wait),a
	jr .cur
.put:	ld (pb_ptr),hl
	add a,$80-32
	ld hl,(pb_pos)
	ld de,VIDEO
	add hl,de
	ld (hl),a
	ld hl,(pb_pos)
	inc hl
	ld (pb_pos),hl
.cur:	; the cursor: a block blinking after the last character
	ld hl,(pb_pos)
	ld (pb_cur),hl
	ld a,(pb_t)
	and 16
	jr z,.nc
	ld de,VIDEO
	add hl,de
	ld (hl),$80+127-32	; the block
.nc:	; ---- the rows' addresses: steady, or torn apart near the end
	ld hl,(pb_t)
	ld de,790
	or a
	sbc hl,de
	jr c,.calm
	ld a,l
	cp 120
	jr c,.g
	ld a,120
.g:	srl a
	srl a
	srl a
	srl a			; strength 0-7
	ld (pb_g),a
.calm:	ld a,(lp_build)
	ld h,a
	ld l,BT_W0
	ld b,14
	ld c,0
.row:	; row C's address: 64 C (+ a random tear)
	push hl
	ld l,c
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,(pb_g)
	or a
	jr z,.st
	ld d,a
	call rnd
	and 7
	cp d
	jr nc,.st		; most rows stay
	call rnd
	and 15
	sub 8			; -8..7 cells
	ld e,a
	ld d,0
	bit 7,e
	jr z,.p
	dec d
.p:	add hl,de
	ld a,h
	and 7
	ld h,a
.st:	ex de,hl
	pop hl
	ld (hl),d		; R12
	inc hl
	inc hl
	ld (hl),e		; R13
	ld de,8
	add hl,de		; the next row's
	inc c
	djnz .row
	ret

; the script: 1, row, col = move; 2, n = wait n frames; 0 = the end
boot_script:
	db 2,40
	db 1,1,2,"MICROBEE PREMIUM PLUS",2,10
	db 1,1,44,"SELF TEST 2026",2,40
	db 1,3,2,"Z80A CPU AT 3.375 MHZ .................. OK",2,15
	db 1,4,2,"MEMORY 1024K ........................... OK",2,15
	db 1,5,2,"PCG RAM 32K ............................ OK",2,15
	db 1,6,2,"SPEAKER, 1 BIT ......................... OK",2,15
	db 1,7,2,"6545 CRTC .............................. ?",2,60
	db 1,8,6,"RE-READS ITS START ADDRESS ON EVERY LINE",2,20
	db 1,9,6,"HOLDS THE CPU WHEN IT TOUCHES THE SCREEN",2,20
	db 1,10,6,"COMPARES ITS ROW COUNT ALL THE TIME",2,40
	db 1,11,6,"... PERFECT.",2,60
	db 1,13,2,"LOADING THE IMPOSSIBLE",2,25,".",2,25,".",2,25,".",2,60
	db 0
