; =====================================================================
;  PARALLAX: half-speed distant silhouette band + two-speed far stars.
;  Both are drawn only into bytes/pixels that are still open space.
; =====================================================================

; ---- build FARBUF (4 pre-shifted copies of the 64x8 band) and the star list
build_far:
	ld a,(LVLBUF+17)
	ld (fbandy),a
	ld a,(palT)
	ld b,a
	add a,a
	add a,a
	add a,b		; *5
	ld b,a
	add a,a
	add a,a
	add a,a
	add a,a
	add a,b		; *$55
	ld (fspace),a
	; star colour
	ld a,(LVLBUF+18)
	call palof
	ld b,a
	add a,a
	add a,a
	add a,b
	ld b,a
	add a,a
	add a,a
	add a,a
	add a,a
	add a,b
	ld (fstarc),a
	; source pattern (logical, unpacked by build_tiles) -> remapped row, 4 shifts
	ld de,THTMP+256
	xor a
.row:	ld (fb_r),a
	; remap row into fb_tmp
	ld hl,fb_tmp
	ld b,16
.rm:	ld a,(de)
	inc de
	push hl
	ld l,a
	ld h,REMAPT>>8
	ld a,(hl)
	pop hl
	ld (hl),a
	inc hl
	djnz .rm
	ld a,(fb_tmp)
	ld (hl),a		; wrap copy
	push de
	; shifts 0..3
	xor a
.sh:	ld (fb_s),a
	; dest = FARBUF + (r>>2)*256 + (r&3)*64 + slot(s)
	ld hl,fslot
	ld e,a
	ld d,0
	add hl,de
	ld c,(hl)		; slot
	ld a,(fb_r)
	and 3
	rrca
	rrca			; *64
	or c
	ld e,a
	ld a,(fb_r)
	rrca
	rrca
	and 1
	add a,FARBUF>>8
	ld d,a
	ld hl,fb_tmp
	ld a,16
	ld (fb_n),a
.by:	ld b,(hl)		; this byte
	inc hl
	ld c,(hl)		; next byte (fb_tmp[16] = fb_tmp[0])
	ld a,(fb_s)
	or a
	jr z,.st
.s2:	sla c
	rl b
	sla c
	rl b
	dec a
	jr nz,.s2
.st:	ld a,b
	ld (de),a
	inc e
	ld a,(fb_n)
	dec a
	ld (fb_n),a
	jr nz,.by
	ld a,(fb_s)
	inc a
	cp 4
	jr c,.sh
	pop de
	ld a,(fb_r)
	inc a
	cp 8
	jr c,.row
	; ---- far stars from the random table
	ld hl,rndt+40
	ld de,fstars
	ld b,NFSTAR
.fs:	ld a,(hl)
	ld (de),a		; x 0..255
	inc hl
	inc de
	ld a,(hl)
	and 63
	cp PFH
	jr c,$+4
	sub 16
	ld (de),a		; y
	inc hl
	inc de
	djnz .fs
	ret
fslot	db 0,32,16,48
fb_r	db 0
fb_s	db 0
fb_tmp	ds 17
fb_n	db 0
fbandy	db 0
fspace	db 0
fstarc	db 0
NFSTAR	equ 12

; ---- draw band and stars into compose (call after bgcopy)
draw_far:
	ld a,(fspace)
	ld c,a
	; ---- stars: first half at 1/2 speed, second half at 1/4 speed
	ld hl,(scrollx)
	srl h
	rr l
	ld a,l
	ld (fs_o1),a
	srl h
	rr l
	ld a,l
	ld (fs_o2),a
	ld ix,fstars
	ld b,NFSTAR
.st:	push bc
	ld a,b
	cp NFSTAR/2+1
	ld a,(fs_o1)
	jr nc,$+5
	ld a,(fs_o2)
	ld e,a
	ld a,(ix+0)
	sub e
	bit 7,a
	jr nz,.sn		; off screen (128..255)
	ld e,a
	; byte address COMPOSE + y*32 + x>>2
	ld l,(ix+1)
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,e
	rrca
	rrca
	and 31
	or l
	ld l,a
	ld a,h
	add a,COMPOSE>>8
	ld h,a
	ld a,e
	and 3
	ld e,a
	ld d,0
	push hl
	ld hl,pixmask
	add hl,de
	ld d,(hl)		; pixel mask
	pop hl
	ld a,(hl)
	xor c
	and d
	jr nz,.sn		; pixel is not open space
	ld a,(fstarc)
	and d
	ld e,a
	ld a,d
	cpl
	and (hl)
	or e
	ld (hl),a
.sn:	inc ix
	inc ix
	pop bc
	djnz .st
	; ---- band (half speed). Each band row is drawn as up to three runs
	; through an unrolled 16-entry merge block: [o..15], [0..15], [0..o-1]
	ld a,(fbandy)
	or a
	ret z
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,COMPOSE
	add hl,de
	ex de,hl		; DE = first band row
	ld hl,(scrollx)
	srl h
	rr l			; half speed
	ld a,l
	and 3
	push hl
	ld hl,fslot
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	ld (fb_sl),a		; slot offset of this shift
	pop hl
	ld a,l
	rrca
	rrca
	and 15
	ld (fb_o),a
	; entry points for run lengths n1 = 16-o and n3 = o
	ld b,a
	ld a,16
	sub b
	call mblk_entry
	ld (.e1+1),hl
	ld a,(fb_o)
	call mblk_entry
	ld (.e3+1),hl
	xor a
.row:	push af
	ld b,a
	rrca
	rrca
	and 1
	add a,FARBUF>>8
	ld h,a
	ld a,b
	and 3
	rrca
	rrca
	ld b,a
	ld a,(fb_sl)
	or b
	ld b,a			; B = row base low
	ld a,(fb_o)
	or b
	ld l,a
.e1:	call mblk_end
	ld l,b
	call mblk
	ld l,b
.e3:	call mblk_end
	ld a,e
	or a
	jr nz,$+3
	inc d
	pop af
	inc a
	cp 8
	jr c,.row
	ret
mblk_entry:	; A = run length 0..16 -> HL = entry address (keeps DE)
	push de
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl		; *8 bytes per entry
	ex de,hl
	ld hl,mblk_end
	or a
	sbc hl,de
	pop de
	ret
mblk:
	REPT 16
	ld a,(de)
	cp c
	jr nz,$+4
	ld a,(hl)
	ld (de),a
	inc e
	inc l
	ENDR
mblk_end:	ret
fb_sl	db 0
fb_o	db 0
fs_o1	db 0
fs_o2	db 0
pixmask	db $c0,$30,$0c,$03

; ---- background for this frame. While the scroll is stopped (boss fights)
;      the finished background (terrain + band + stars) is cached once in an
;      idle shift buffer and simply copied back each frame.
drawbg:	ld a,(scrollon)
	or a
	jr z,.stop
	xor a
	ld (bgbaked),a
	ld (bodybaked),a
	call bgcopy
	jp draw_far
.stop:	ld a,(bgbaked)
	or a
	jr nz,.use
	call bgcopy
	call draw_far
	ld a,(scrollx)
	add a,2
	and 3
	add a,a
	add a,a
	add a,a
	add a,SHB>>8
	ld h,a
	ld l,0
	ld (statbuf),hl
	ex de,hl
	ld hl,COMPOSE
	ld bc,PFH*32
	ldir
	ld a,1
	ld (bgbaked),a
	; an arrived (now stationary) big boss body is baked in once
	ld a,(bossW)
	or a
	jr z,.nb
	ld a,(bossent+1)
	or a
	jr z,.nb
	ld ix,(bossent)
	ld a,(ix+E_TYPE)
	cp T_BOSS
	jr nz,.nb
	ld a,(ix+E_ST)
	cp 1
	jr nz,.nb
	ld a,(statbuf+1)
	ld (dsbase+1),a
	call draw_boss_body
	ld a,COMPOSE>>8
	ld (dsbase+1),a
	ld a,1
	ld (bodybaked),a
	; the frame being built needs it too
	call draw_boss_body.go
.nb:	ret
.use:	ld hl,(statbuf)
	ld de,COMPOSE
	ld bc,PFH*32
	ld a,PFH
.r:	REPT 32
	ldi
	ENDR
	ex af,af'
	call sndrow
	ex af,af'
	bit 3,a
	jr z,.nc
	ex af,af'
	call vschk
	ex af,af'
.nc:	dec a
	jr nz,.r
	ret
bgbaked	db 0
bodybaked db 0
statbuf	dw 0
