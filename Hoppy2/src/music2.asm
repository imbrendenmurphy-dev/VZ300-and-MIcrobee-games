;=====================================================================
; Two-voice beeper music (full CPU).  Each loop iteration writes voice A
; then voice B to the speaker (~25 kHz interleave), phase accumulators
; give clean square waves.  Tunes: rows (fields, bass, melody), 0 = end.
; m2_cb: optional routine run between rows (e.g. one animation tick);
; it returns A = key bits, non-zero aborts the tune (NZ returned).
;=====================================================================
m2_jingle:
	push hl
	ld hl,0
	ld (m2_cb),hl
	pop hl
m2_play:
	ld (m2_ptr),hl
	call snd_off
	ld a,1
	ld (m2_on),a
.row:	ld hl,(m2_ptr)
	ld a,(hl)
	or a
	jr z,.end
	ld (m2_f),a
	inc hl
	ld a,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld (m2_ptr),hl
	push bc
	call m2_inc
	ld (m2_ia),hl
	pop bc
	ld a,c
	call m2_inc
	ld (m2_ib),hl
	ld a,(m2_f)
	ld b,a
	ld hl,0
	ld de,508		; loop iterations per field
.mul:	add hl,de
	djnz .mul
	ld (m2_n),hl
	call m2_tone
	ld hl,(m2_cb)
	ld a,h
	or l
	jr z,.row
	call jp_hl
	or a
	jr z,.row
	xor a
	ld (m2_on),a
	or 1
	ret
.end:	xor a
	ld (m2_on),a
	ret

m2_inc:	add a,a
	ld l,a
	ld h,0
	ld de,m2_ftab
	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret

m2_tone:
	ld a,(latch_v)
	and $de
	or $20
	ld (.k1+1),a
	ld (.k2+1),a
	exx
	ld bc,(m2_n)
	exx
	ld de,(m2_ia)
	ld bc,(m2_ib)
	ld hl,(m2_pa)
	ld ix,(m2_pb)
.l:	add hl,de
	ld a,h
	add a,a
	sbc a,a
	and $21
.k1:	xor 0
	ld (LATCH),a
	add ix,bc
	ld a,ixh
	add a,a
	sbc a,a
	and $21
.k2:	xor 0
	ld (LATCH),a
	exx
	dec bc
	ld a,b
	or c
	exx
	jp nz,.l
	ld (m2_pa),hl
	ld (m2_pb),ix
	ld a,(latch_v)
	ld (LATCH),a
	ret

	INCLUDE "music2.inc"
