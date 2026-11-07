; small page-safe tables
	ALIGN 16
BITT:	db $80,$40,$20,$10,$08,$04,$02,$01
PAIRMASK:	db $C0,$30,$0C,$03

; the original's random numbers (sparks)
vrand:	push hl
	ld hl,(v_seed)
	ld a,h
	rra
	ld a,l
	rra
	xor h
	ld h,a
	ld a,l
	rra
	ld a,h
	rra
	xor l
	ld l,a
	xor h
	ld h,a
	ld (v_seed),hl
	ld a,l
	pop hl
	ret
