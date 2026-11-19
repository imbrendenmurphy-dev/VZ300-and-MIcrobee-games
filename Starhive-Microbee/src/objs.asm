; =====================================================================
;  STARHIVE test objects: the player's ship, shots, a drone formation
;  and its bullets (from the first scroll test)
; =====================================================================
PFH2	equ VROWS*CL		; playfield height (242 lines)
NSHOTS	equ 6
NBULS	equ 8
NDRONE	equ 8

move_player:
	ld a,(frame)
	inc a
	ld (frame),a
	ld a,(inp)
	ld b,a
	ld hl,(px)
	bit 2,b
	jr z,.nl
	ld de,-4
	add hl,de
	ld de,16
	or a
	sbc hl,de
	jr nc,.l1
	ld hl,0
.l1:	add hl,de
.nl:	bit 3,b
	jr z,.nr
	ld de,4
	add hl,de
	push hl
	ld de,16+PFW-16
	or a
	sbc hl,de
	pop hl
	jr c,.nr
	ld hl,16+PFW-16
.nr:	ld (px),hl
	ld a,(py)
	bit 0,b
	jr z,.nu
	sub 4
	cp 16+4
	jr nc,.nu
	ld a,16+4
.nu:	bit 1,b
	jr z,.nd
	add a,4
	cp 16+PFH2-18
	jr c,.nd
	ld a,16+PFH2-18
.nd:	ld (py),a
	; fire
	bit 4,b
	ret z
	ld a,(firecd)
	or a
	jr z,.f
	dec a
	ld (firecd),a
	ret
.f:	ld a,2
	ld (firecd),a
	ld hl,shots
	ld b,NSHOTS
.s:	ld a,(hl)
	or a
	jr z,.got
	inc hl
	inc hl
	inc hl
	djnz .s
	ret
.got:	ld a,(py)
	sub 4
	ld (hl),a		; y (0 = free)
	inc hl
	ld de,(px)
	ld a,e
	add a,7
	ld (hl),a
	inc hl
	ld a,d
	adc a,0
	ld (hl),a
	ret

move_shots:
	ld hl,shots
	ld b,NSHOTS
.s:	ld a,(hl)
	or a
	jr z,.n
	sub 12
	cp 8
	jr nc,.k
	xor a
.k:	ld (hl),a
.n:	inc hl
	inc hl
	inc hl
	djnz .s
	ld hl,buls
	ld b,NBULS
.b:	ld a,(hl)
	or a
	jr z,.bn
	add a,5
	cp 250
	jr c,.bk
	xor a
.bk:	ld (hl),a
.bn:	inc hl
	inc hl
	inc hl
	djnz .b
	ret

; drones: a figure-of-eight formation, each with its own phase
move_drones:
	ld a,(dphase)
	add a,3
	ld (dphase),a
	ld a,(ndr)
	or a
	ret z
	ld ix,drones
	ld b,a
	ld c,0
.w:	push bc
	ld a,(dphase)
	add a,c
	call sin8		; -63..63
	ld l,a
	add a,a
	sbc a,a
	ld h,a			; sign extend
	add hl,hl		; x = 154 + 2 sin
	ld de,154+16-6
	add hl,de
	ld (ix+0),l
	ld (ix+1),h
	ld a,(dphase)
	add a,a
	add a,c
	add a,c
	call sin8
	sra a
	add a,70+16
	ld (ix+2),a
	ld a,(frame)
	add a,c
	and 31
	jr nz,.nb
	ld hl,buls
	ld b,NBULS
.f:	ld a,(hl)
	or a
	jr z,.g
	inc hl
	inc hl
	inc hl
	djnz .f
	jr .nb
.g:	ld a,(ix+2)
	add a,10
	ld (hl),a
	inc hl
	ld a,(ix+0)
	add a,4
	ld (hl),a
	inc hl
	ld a,(ix+1)
	adc a,0
	ld (hl),a
.nb:	ld de,3
	add ix,de
	pop bc
	ld a,c
	add a,32
	ld c,a
	djnz .w
	ret

sin8:	ld hl,sintab
	ld e,a
	ld d,0
	add hl,de
	ld a,(hl)
	ret

; list of (y + 16, x + 16 (2 bytes)) objects -> sprites; y = 0: none
draw_list:
.o:	push bc
	ld a,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	or a
	jr z,.n
	push hl
	ld c,a
	ld hl,(dl_frame)
	call spr_draw
	call vschk
	pop hl
.n:	pop bc
	djnz .o
	ret

draw_all:
	ld hl,SP_BULLET
	ld (dl_frame),hl
	ld hl,buls
	ld b,NBULS
	call draw_list
	ld a,(ndr)
	or a
	jr z,.nw
	ld hl,SP_DRONE1
	ld a,(frame)
	and 2
	jr z,.w1
	ld hl,SP_DRONE2
.w1:	ld (dl_frame),hl
	ld ix,drones
	ld a,(ndr)
	ld b,a
.w:	push bc
	ld e,(ix+0)
	ld d,(ix+1)
	ld c,(ix+2)
	ld hl,(dl_frame)
	push ix
	call spr_draw
	pop ix
	call vschk
	ld de,3
	add ix,de
	pop bc
	djnz .w
.nw:	ld hl,SP_SHOT
	ld (dl_frame),hl
	ld hl,shots
	ld b,NSHOTS
	call draw_list
	ld de,(px)
	ld a,(py)
	ld c,a
	ld a,(frame)
	and 1
	ld hl,SP_HORNET1
	jr z,.p1
	ld hl,SP_HORNET2
.p1:	jp spr_draw

