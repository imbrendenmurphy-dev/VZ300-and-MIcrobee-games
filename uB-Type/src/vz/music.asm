; =====================================================================
;  MUSIC: two-voice beeper player - pulse-wave melody over a square bass,
;  each note clipped short so the notes stand apart
;  tune rows: ticks, note1, note2 (MIDI numbers, 0 = rest), flags (1 = drum)
;  a tick is TICKIT loop iterations (~1/25 s). mcb is called every tick;
;  if it returns carry the tune stops and play_tune returns A=1.
; =====================================================================
TICKIT	equ 1100		; ~122 T per loop -> ~1/26 s per tick

play_tune:	; HL = tune, A = loop flag
	ld (mt_loop),a
	ld (mt_ptr),hl
	ld (mt_start),hl
	ld a,(latch)
	and $1e
	or 1
	ld (m_s1),a
	ld (m_s2),a
.row:	ld hl,(mt_ptr)
	ld a,(hl)
	or a
	jr nz,.ok
	ld a,(mt_loop)
	or a
	ret z
	ld hl,(mt_start)
	ld (mt_ptr),hl
	jr .row
.ok:	ld (mt_tk),a
	inc hl
	ld a,(hl)
	call setv1
	inc hl
	ld a,(hl)
	call setv2
	inc hl
	ld a,(hl)
	inc hl
	ld (mt_ptr),hl
	and 1
	call nz,drum
.tick:	ld a,(mt_tk)
	cp 1
	call z,mute
	call mplay
	call mcbcall
	jr nc,.nt
	ld a,1
	ret
.nt:	ld hl,mt_tk
	dec (hl)
	jr nz,.tick
	jr .row
mcbcall: ld hl,(mcb)
	jp (hl)
nocb:	or a
	ret

setv1:	; melody voice: narrow pulse (gritty), duty = period/4
	push hl
	ld e,a
	ld d,0
	ld hl,ptab1
	add hl,de
	ld a,(hl)
	ld (m_p1),a
	ld (m_c1),a
	srl a
	srl a
	jr nz,$+3
	inc a
	ld (mplay.w1+1),a
	ld a,e
	or a
	ld a,$21
	jr nz,$+3
	xor a
	ld (mplay.m1+1),a
	pop hl
	ret
setv2:	; bass voice: square
	push hl
	ld e,a
	ld d,0
	ld hl,ptab2
	add hl,de
	ld a,(hl)
	ld (m_p2),a
	ld (m_c2),a
	ld a,e
	or a
	ld a,$21
	jr nz,$+3
	xor a
	ld (mplay.mx2+1),a
	ld a,(m_s1)		; restart the bass from the speaker's rest state
	ld (m_s2),a
	pop hl
	ret
mute:	; last tick of a row: both voices silent so notes stand apart
	xor a
	ld (mplay.m1+1),a
	ld (mplay.mx2+1),a
	ld a,(m_s1)
	ld (m_s2),a
	ret

mplay:	push ix
	ld a,(m_p1)
	ld b,a
	ld a,(m_p2)
	ld c,a
	ld a,(m_c1)
	ld d,a
	ld a,(m_c2)
	ld e,a
	ld a,(m_s1)
	ld ixh,a		; speaker rest state
	ld a,(m_s2)
	ld ixl,a		; bass state
	ld hl,TICKIT
.lp:	dec d
	jr nz,.a
	ld d,b
.a:	ld a,d
.w1:	cp 0			; pulse on while the counter is below the duty
	sbc a,a
.m1:	and $21
	xor ixh
	ld (LATCH),a
	dec e
	jr nz,.b
	ld e,c
	ld a,ixl
.mx2:	xor $21
	ld ixl,a
.b:	ld a,ixl
	ld (LATCH),a
	dec hl
	ld a,h
	or l
	jr nz,.lp
	ld a,d
	ld (m_c1),a
	ld a,e
	ld (m_c2),a
	ld a,ixl
	ld (m_s2),a
	ld a,ixh
	ld (LATCH),a		; leave the speaker at rest between ticks
	pop ix
	ret

drum:	; short noise burst
	ld b,0
	ld a,(m_s1)
	ld c,a
.d:	ld a,r
	and $21
	xor c
	and $21
	xor c
	ld (LATCH),a
	ld a,b
	and 3
	jr nz,$+2
	djnz .d
	ret

mt_loop	db 0
mt_ptr	dw 0
mt_start dw 0
mt_tk	db 0
mcb	dw nocb
m_p1	db 1
m_p2	db 1
m_c1	db 1
m_c2	db 1
m_s1	db 1
m_s2	db 1
