; =====================================================================
;  MUSIC: the sequencer, once a frame (in the vertical blanking).
;
;  The kernel plays two voices on every scanline (15625 Hz): voice 1,
;  the lead, a 25% pulse (phase HL', increment DE'), and voice 2, the
;  bass, a square (phase IY, increment BC'). This code only sets the
;  increments: inc = f x 65536 / 15625. 0 = silent.
;
;  Song (tools/mkmusic.py): an order list of pattern numbers (with
;  $FE = set speed (next byte), $FF = the end), patterns of 16 rows,
;  each row 3 bytes: lead, bass, drum. A pattern starts with two bytes:
;  the lead and bass instruments.
;    lead / bass byte: 0 nothing new, 1 note off, n >= 2 note n (MIDI)
;    drum: 0 none, 1 kick, 2 snare, 3 hat, 4 kick + hat
;  Drums borrow the voices: the kick sweeps the bass voice down, the
;  snare and hat put noise on the lead voice.
; =====================================================================

; lead instruments
LI_BLIP	equ 0			; 2 frames
LI_PLUCK equ 1			; 4 frames, then a quiet octave echo
LI_HOLD	equ 2			; held, vibrato after 10 frames
LI_ARPMA equ 3			; held, major chord arpeggio
LI_ARPMI equ 4			; held, minor chord arpeggio
LI_ECHO	equ 5			; 3 on, 3 off, 2 on (a blip with an echo)
; bass instruments
BI_GATE	equ 0			; each note sounds one frame less than the row
BI_OCT	equ 1			; note and octave alternating each frame
BI_HOLD	equ 2			; held

mus_start:			; HL = song
	ld (m_order),hl
	ld (m_loop),hl
	ld hl,0
	ld (m_opos),hl
	ld (m_frames),hl
	ld hl,(m_order)
	xor a
	ld (m_lnote),a
	ld (m_bnote),a
	ld (m_drum),a
	ld (m_row),a
	ld a,6
	ld (m_speed),a
	ld a,1
	ld (m_tick),a
	ld (mus_on),a
	call mus_next_pattern
	ret

mus_stop:
	xor a
	ld (mus_on),a
	exx
	ld de,0
	ld bc,0
	exx
	ret

; ---- once a frame
mus_tick:
	ld a,(mus_on)
	or a
	ret z
	ld hl,(m_frames)
	inc hl
	ld (m_frames),hl
	ld hl,m_tick
	dec (hl)
	call z,mus_row
	; ---- lead
	ld hl,(m_lt)
	inc hl
	ld (m_lt),hl
	call lead_inc		; -> DE = increment
	; ---- drum on the lead voice?
	ld a,(m_dt)
	inc a
	cp 200
	jr c,.dts
	ld a,200
.dts:	ld (m_dt),a
	ld b,a
	ld a,(m_drum)
	cp 2
	jr z,.snare
	cp 3
	jr z,.hat
	cp 4
	jr z,.hat
	jr .lset
.snare:	ld a,b
	cp 4
	jr nc,.lset
	call rnd
	and $1F
	add a,$18
	ld d,a			; noise: random pitch 6-13 kHz-ish each frame
	call rnd
	ld e,a
	jr .lset
.hat:	ld a,b
	cp 2
	jr nc,.lset
	call rnd
	or $C0
	ld d,a
	ld e,b
.lset:	push de
	; ---- bass
	ld hl,(m_bt)
	inc hl
	ld (m_bt),hl
	call bass_inc		; -> BC
	ld a,(m_drum)
	cp 1
	jr z,.kick
	cp 4
	jr nz,.bset
.kick:	ld a,(m_dt)
	cp 4
	jr nc,.bset
	; the kick: a falling tone, 3 frames
	ld l,a
	ld h,0
	ld de,kick_tab
	add hl,hl
	add hl,de
	ld c,(hl)
	inc hl
	ld b,(hl)
.bset:	pop de
	; into the voices
	push bc
	push de
	exx
	pop de
	pop bc
	exx
	ret

; lead increment for this frame -> DE
lead_inc:
	ld a,(m_lnote)
	or a
	jp z,.off
	ld c,a
	ld a,(m_linst)
	ld hl,(m_lt)		; frames since the note started
	cp LI_BLIP
	jr nz,.n1
	ld a,l
	cp 3
	jp nc,.off
	jp .note
.n1:	cp LI_PLUCK
	jr nz,.n2
	ld a,l
	cp 5
	jp c,.note
	cp 8
	jp nc,.off
	ld a,c
	add a,12
	ld c,a
	jp .note
.n2:	cp LI_HOLD
	jr nz,.n3
	ld a,l
	cp 11
	jr c,.note
	; vibrato: +-1/4 semitone, a 4-frame cycle
	call .note
	ld a,(m_frames)
	and 3
	ret z
	cp 2
	ret z
	push de
	ex de,hl
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l			; inc / 64
	cp 1
	pop de
	jr nz,.vdown
	add hl,de
	ex de,hl
	ret
.vdown:	ex de,hl
	or a
	sbc hl,de
	ex de,hl
	ret
.n3:	cp LI_ARPMA
	jr z,.arp
	cp LI_ARPMI
	jr nz,.n5
.arp:	ld b,a
	ld a,(m_frames)
	ld e,a
	ld d,0
	ld hl,0
	ld a,e
.mod3:	sub 3
	jr nc,.mod3
	add a,3			; frame mod 3 (of the low byte: a tiny jump at wrap)
	or a
	jr z,.note
	cp 1
	jr nz,.a7
	ld a,b
	cp LI_ARPMA
	ld a,4
	jr z,.a4
	dec a
.a4:	add a,c
	ld c,a
	jr .note
.a7:	ld a,c
	add a,7
	ld c,a
	jr .note
.n5:	; LI_ECHO: 0-2 on, 3-5 off, 6-7 on, then off
	ld a,l
	cp 4
	jr c,.note
	cp 7
	jr c,.off
	cp 9
	jr c,.note
.off:	ld de,0
	ret
.note:	; DE = note C's increment
	ld l,c
	ld h,0
	add hl,hl
	ld de,note_tab
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ret

; bass increment for this frame -> BC
bass_inc:
	ld a,(m_bnote)
	or a
	jr z,.off
	ld c,a
	ld a,(m_binst)
	ld hl,(m_bt)
	cp BI_GATE
	jr nz,.b1
	ld a,l
	ld hl,m_speed
	cp (hl)
	jr nc,.off
	jr .note
.b1:	cp BI_OCT
	jr nz,.note
	ld a,(m_frames)
	and 1
	jr z,.note
	ld a,c
	add a,12
	ld c,a
.note:	ld l,c
	ld h,0
	add hl,hl
	ld de,note_tab
	add hl,de
	ld c,(hl)
	inc hl
	ld b,(hl)
	ret
.off:	ld bc,0
	ret

; ---- a new row
mus_row:
	ld a,(m_speed)
	ld (m_tick),a
	ld hl,(m_ptr)
	; lead
	ld a,(hl)
	inc hl
	or a
	jr z,.nl
	cp 1
	jr nz,.ln
	xor a
.ln:	ld (m_lnote),a
	push hl
	ld hl,0
	ld (m_lt),hl
	pop hl
.nl:	; bass
	ld a,(hl)
	inc hl
	or a
	jr z,.nb
	cp 1
	jr nz,.bn
	xor a
.bn:	ld (m_bnote),a
	push hl
	ld hl,0
	ld (m_bt),hl
	pop hl
.nb:	; drum
	ld a,(hl)
	inc hl
	or a
	jr z,.nd
	ld (m_drum),a
	xor a
	ld (m_dt),a
.nd:	ld (m_ptr),hl
	ld hl,m_row
	inc (hl)
	ld a,(hl)
	cp 16
	ret nz
	ld (hl),0
	; fall into the next pattern
mus_next_pattern:
	ld hl,(m_order)
.o:	ld a,(hl)
	inc hl
	cp $FF
	jr nz,.n
	; the end: back to the loop point
	ld hl,(m_loop)
	jr .o
.n:	cp $FE
	jr nz,.p
	ld a,(hl)
	inc hl
	ld (m_speed),a
	ld (m_tick),a
	jr .o
.p:	cp $FD			; $FD: set the loop point here
	jr nz,.q
	ld (m_loop),hl
	jr .o
.q:	ld (m_order),hl
	push af
	ld hl,(m_opos)
	inc hl
	ld (m_opos),hl
	pop af
	; pattern A -> HL = its address
	ld l,a
	ld h,0
	add hl,hl
	ld de,song_pats
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld a,(hl)
	ld (m_linst),a
	inc hl
	ld a,(hl)
	ld (m_binst),a
	inc hl
	ld (m_ptr),hl
	ret

; ---- random byte
rnd:	push hl
	ld hl,(rseed)
	add hl,hl
	jr nc,.n
	ld a,l
	xor $2D
	ld l,a
.n:	ld (rseed),hl
	ld a,l
	add a,h
	pop hl
	ret

; the kick: increments of a falling tone
kick_tab: dw 860, 520, 330, 210

	INCLUDE "notes.inc"
