; =====================================================================
;  VZ-TYPE engine routines kept as they were: terrain profile decoder,
;  world column decoder (tile ring), view set-up, scroll step, terrain
;  test and scoring. Only the bitmap buffer work is gone.
; =====================================================================

; ---- terrain profile: RLE decoded on demand into a 256-column ring (PROFR)
prof_reset:
	ld hl,(LVLBUF+9)
	ld (prof_ptr),hl
	xor a
	ld (prof_run),a
	ld hl,0
	ld (prof_next),hl
	ret
prof_fill:	; make sure columns up to HL are decoded
	ex de,hl
.l:	ld hl,(prof_next)
	ld a,e
	sub l
	ld a,d
	sbc a,h
	ret c
	ld a,(prof_run)
	or a
	jr nz,.have
	ld hl,(prof_ptr)
	ld a,(hl)
	or a
	jr z,.end
	ld (prof_run),a
	inc hl
	ld a,(hl)
	ld (prof_val),a
	inc hl
	ld (prof_ptr),hl
	jr .have
.end:	ld a,255
	ld (prof_run),a
.have:	ld hl,prof_run
	dec (hl)
	ld hl,(prof_next)
	push hl
	ld h,PROFR>>8
	ld a,(prof_val)
	ld (hl),a
	pop hl
	inc hl
	ld (prof_next),hl
	jr .l
prof_ptr	dw 0
prof_next	dw 0
prof_run	db 0
prof_val	db 0

; ---- decode world column HL into the tile ring
;  tile ids: 0 empty, 1-4 full(parity), 5-6 ftop, 7-8 cbot, 9 FSU, 10 FSD,
;  11 CSD, 12 CSU, 13-20 block parts, 21 F0, 22 F1, 28/29 decor
deccol:
	ld (tmp1),hl
	; clamp to last column
	ld de,(lvlcols)
	dec de
	ld a,l
	sub e
	ld a,h
	sbc a,d
	jr c,.ok
	ex de,hl
.ok:	ld (tmp2),hl		; clamped x
	inc hl
	call prof_fill		; decoded through x+1
	ld hl,(tmp2)
	ld a,l
	ld l,a
	ld h,PROFR>>8
	ld a,(hl)
	ld (dc_cf),a
	ld (dc_p),a
	ld (dc_n),a
	; previous (if x > 0)
	ld de,(tmp2)
	ld a,d
	or e
	jr z,.np
	dec l
	ld a,(hl)
	ld (dc_p),a
	inc l
.np:	; next (if x < last)
	ld de,(lvlcols)
	dec de
	push hl
	ld hl,(tmp2)
	or a
	sbc hl,de
	pop hl
	jr nc,.nn
	inc l
	ld a,(hl)
	ld (dc_n),a
.nn:
	; destination slot
	ld a,(tmp1)
	and 63
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,TRING
	add hl,de
	ld (dc_dst),hl
	; x phase
	ld a,(tmp1)
	and 3
	ld (dc_par),a
	; base fill
	ld a,(dc_cf)
	rrca
	rrca
	rrca
	rrca
	and 15
	ld (dc_c),a
	ld a,(dc_cf)
	and 15
	ld (dc_f),a
	ld b,0			; y
.fy:	xor a			; tile
	ld c,a
	ld a,(dc_c)
	ld e,a
	ld a,b
	cp e
	jr c,.solid
	ld a,(dc_f)
	ld e,a
	ld a,NTR
	sub e			; NTR-f
	ld e,a
	ld a,b
	cp e
	jr c,.put
.solid:	ld a,b
	and 3
	add a,a
	add a,a
	ld c,a
	ld a,(dc_par)
	add a,c
	inc a
	ld c,a
.put:	ld (hl),c
	inc hl
	inc b
	ld a,b
	cp NTR
	jr c,.fy
	ld hl,(dc_dst)
	; ceiling edge
	ld a,(dc_c)
	or a
	jr z,.nocb
	dec a
	call dcrow
	ld a,(dc_par)
	and 1
	add a,19
	ld (hl),a
	; CSD: c == cp+1
	ld a,(dc_p)
	rrca
	rrca
	rrca
	rrca
	and 15
	inc a
	ld c,a
	ld a,(dc_c)
	cp c
	jr nz,.n1
	ld (hl),23
.n1:	; CSU: cn == c-1
	ld a,(dc_n)
	rrca
	rrca
	rrca
	rrca
	and 15
	inc a
	ld c,a
	ld a,(dc_c)
	cp c
	jr nz,.nocb
	ld (hl),24
.nocb:	; floor edge
	ld a,(dc_f)
	or a
	jr z,.nofl
	ld c,a
	ld a,NTR
	sub c
	ld (dc_fr),a
	call dcrow
	ld a,(dc_par)
	and 1
	add a,17
	ld (hl),a
	ld a,(dc_p)
	and 15
	inc a
	ld c,a
	ld a,(dc_f)
	cp c
	jr nz,.n2
	ld (hl),21
.n2:	ld a,(dc_n)
	and 15
	inc a
	ld c,a
	ld a,(dc_f)
	cp c
	jr nz,.nofl
	ld (hl),22
.nofl:	; ---- objects
	ld hl,(objptr)
.oadv:	ld e,(hl)
	inc hl
	ld d,(hl)		; obj x
	inc hl
	ld a,d
	and e
	inc a
	jr z,.oend		; $ffff terminator
	inc hl
	ld a,(hl)		; w
	dec hl
	; if x+w <= cur -> advance objptr
	push hl
	ld h,0
	ld l,a
	add hl,de		; x+w
	ld de,(tmp1)
	or a
	sbc hl,de		; (x+w)-cur
	pop hl
	jr z,.adv
	jr c,.adv
	jr .oscan
.adv:	inc hl
	inc hl
	inc hl
	inc hl
	ld (objptr),hl
	jr .oadv
.oscan:	ld hl,(objptr)
.os:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,d
	and e
	inc a
	jr z,.oend
	; if x > cur -> done
	push hl
	ld hl,(tmp1)
	or a
	sbc hl,de		; cur - x
	pop hl
	jr c,.oend
	ld a,l
	ld (dc_ox),de
	ld c,(hl)		; y
	inc hl
	ld b,(hl)		; w
	inc hl
	ld a,(hl)		; h
	ld (dc_oh),a
	inc hl
	ld a,(hl)		; kind
	ld (dc_ok),a
	inc hl
	push hl
	; covers cur?  cur - x < w
	push bc
	ld hl,(tmp1)
	ld de,(dc_ox)
	or a
	sbc hl,de
	ld a,h
	or a
	jr nz,.skipo
	ld a,l
	cp b
	jr nc,.skipo
	ld (dc_rel),a		; position within object
	call dcobj
.skipo:	pop bc
	pop hl
	jr .os
.oend:	; ---- F1 surface feature
	ld a,(tmp1)
	add a,7
	ld l,a
	ld h,rndt>>8
	ld a,(hl)
	and 15
	jr nz,.nof1
	ld a,(dc_f)
	cp 2
	jr c,.nof1
	ld c,a
	ld a,(dc_p)
	and 15
	cp c
	jr nz,.nof1
	ld a,(dc_n)
	and 15
	cp c
	jr nz,.nof1
	ld a,NTR+1
	sub c
	call dcrow
	ld (hl),34
.nof1:	; ---- decor
	ld a,(tmp1)
	ld l,a
	ld h,rndt>>8
	ld a,(hl)
	ld c,a
	and 7
	ret nz
	inc l
	ld a,(hl)
	and 15
	cp NTR
	ret nc
	call dcrow
	ld a,(hl)
	or a
	ret nz
	ld a,c
	rlca
	rlca
	and 3
	add a,48
	ld (hl),a
	ret
dcrow:	; HL = dst + A
	ld hl,(dc_dst)
	add a,l
	ld l,a
	ret nc
	inc h
	ret
dcobj:	; apply object row cells for this column. C=y, dc_rel, dc_oh, dc_ok, B=w
	ld a,(dc_ok)
	or a
	jr z,.blk
	cp 1
	jr nz,.fil
	ld a,33			; pillar: F0
.fil:	ld d,a
	ld a,(dc_oh)
	ld b,a
	ld a,c
	call dcrow
.pl:	ld (hl),d
	inc hl
	djnz .pl
	ret
.blk:	ld a,b
	dec a
	ld (dc_w1),a		; w-1
	ld a,(dc_oh)
	ld b,a			; rows
	ld e,0			; row index in block
	ld a,c
	call dcrow
.br:	push bc
	; default full parity
	ld a,c
	add a,e
	and 3
	add a,a
	add a,a
	ld d,a
	ld a,(dc_par)
	add a,d
	inc a
	ld d,a
	; flags: top=e==0, bot=e==h-1, lf=rel==0, rt=rel==w-1
	ld a,(dc_oh)
	dec a
	cp e
	ld a,0
	jr nz,$+4
	or 2			; bot
	inc e
	dec e
	jr nz,$+4
	or 1			; top
	ld b,a
	ld a,(dc_rel)
	or a
	jr nz,$+6
	ld a,b
	or 4
	ld b,a			; left
	ld a,(dc_w1)
	push hl
	ld hl,dc_rel
	cp (hl)
	pop hl
	jr nz,$+6
	ld a,b
	or 8
	ld b,a			; right
	; choose tile
	ld a,b
	and 5
	cp 5
	jr nz,$+6
	ld d,25
	jr .ch
	ld a,b
	and 9
	cp 9
	jr nz,$+6
	ld d,26
	jr .ch
	ld a,b
	and 6
	cp 6
	jr nz,$+6
	ld d,27
	jr .ch
	ld a,b
	and 10
	cp 10
	jr nz,$+6
	ld d,28
	jr .ch
	bit 0,b
	jr z,$+6
	ld d,29
	jr .ch
	bit 1,b
	jr z,$+6
	ld d,30
	jr .ch
	bit 2,b
	jr z,$+6
	ld d,31
	jr .ch
	bit 3,b
	jr z,.ch
	ld d,32
.ch:	ld (hl),d
	inc hl
	inc e
	pop bc
	dec b
	jp nz,.br
	ret

dc_cf	db 0
dc_p	db 0
dc_n	db 0
dc_c	db 0
dc_f	db 0
dc_fr	db 0
dc_par	db 0
dc_dst	dw 0
dc_ox	dw 0
dc_oh	db 0
dc_ok	db 0
dc_rel	db 0
dc_w1	db 0

; ---- set the view up at world column HL (restart / checkpoint)
setview:
	push hl
	call prof_reset
	pop hl
	ld (scol),hl
	add hl,hl
	add hl,hl
	ld (scrollx),hl
	; reposition object & spawn pointers
	ld hl,(objbase)
	ld (objptr),hl
	ld hl,(spnbase)
.sp:	ld e,(hl)
	inc hl
	ld d,(hl)
	dec hl
	ld a,d
	and e
	inc a
	jr z,.spd
	push hl
	ld hl,(scol)
	ld bc,30
	add hl,bc
	or a
	sbc hl,de		; scol+30 - col
	pop hl
	jr c,.spd
	ld bc,5
	add hl,bc
	jr .sp
.spd:	ld (spnptr),hl
	; decode scol .. scol+33
	ld hl,(scol)
	ld b,34
.dl:	push bc
	push hl
	call deccol
	pop hl
	inc hl
	pop bc
	djnz .dl
	ld (gencol),hl
	; both pages are rebuilt from scratch
	ld hl,$FFFF
	ld (lastLA),hl
	ld (lastLB),hl
	ld a,$FF
	ld (pphaseA),a
	ld (pphaseB),a
	ret

; ---- advance scroll by one pixel (the tile ring stays one screen ahead)
scroll_step:
	xor a
	ld (scrolled),a
	ld a,(scrollon)
	or a
	ret z
	ld a,1
	ld (scrolled),a
	ld hl,(scrollx)
	inc hl
	ld (scrollx),hl
	ld a,l
	and 3
	ret nz
	ld hl,(scol)
	inc hl
	ld (scol),hl
	ld hl,(gencol)
	push hl
	call deccol
	pop hl
	inc hl
	ld (gencol),hl
	ret

; ---- terrain test: B=x (screen 0..), C=y (screen 0..55) -> NZ if solid
solid:	ld a,c
	cp PFH
	jr nc,.yes		; outside playfield vertically counts as solid
	ld hl,(scrollx)
	ld a,b
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	srl h
	rr l
	srl h
	rr l			; column
	ld a,l
	and 63
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,c
	rrca
	rrca
	and 15
	add a,l
	ld l,a
	ld de,TRING
	add hl,de
	ld a,(hl)
	or a
	ret z
	cp 48
	jr nc,.no
	or a
	ret
.no:	xor a
	ret
.yes:	or 1
	ret

; ---- add BCD score: A = hundreds (BCD), i.e. points/100
addscore:
	ld hl,score+2
	add a,(hl)
	daa
	ld (hl),a
	dec hl
	ld a,(hl)
	adc a,0
	daa
	ld (hl),a
	dec hl
	ld a,(hl)
	adc a,0
	daa
	ld (hl),a
	ld a,1
	ld (hudflag),a
	; extra life every 50000: check ten-thousands digit change
	ld a,(score+1)
	and $f0
	ld b,a
	ld a,(score)
	rlca
	rlca
	rlca
	rlca
	and $f0			; hundred-thousand digit*16
	; compute (score/50000) = score[0]*2 + (score[1]>>4 >=5)
	ld a,(score)
	and 15
	add a,a
	ld c,a
	ld a,(score+1)
	rrca
	rrca
	rrca
	rrca
	and 15
	cp 5
	jr c,$+3
	inc c
	ld a,(nextlife)
	cp c
	ret nc
	ld a,c
	ld (nextlife),a
	ld a,(lives)
	cp 5
	ret nc
	inc a
	ld (lives),a
	ld hl,sfx_life
	jp sfx

