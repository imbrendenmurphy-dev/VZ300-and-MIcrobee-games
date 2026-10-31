; =====================================================================
;  ENGINE: palette remap, tiles, sprite cache, column decoder,
;  pre-shifted background buffers, compose, sprites, HUD
; =====================================================================

; ---- build remap tables from palette (palT/palA/palB/palC)
build_remap:
	ld hl,REMAPT
	ld b,0			; b = logical byte
.l:	ld c,b
	ld d,0			; REMAPT value
	ld e,0			; REMAPD value
	ld a,4
	ld (tmp1),a
	xor a
	ld (tmp1+1),a		; mask accum
.p:	; take top pixel of c
	ld a,c
	rlca
	rlca
	and 3
	push af
	; REMAPT pixel
	or a
	jr nz,.nz
	ld a,(palT)
	jr .t
.nz:	call palof
.t:	sla d
	sla d
	or d
	ld d,a
	pop af
	push af
	or a
	jr z,.z2
	call palof
	jr .t2
.z2:	xor a
.t2:	sla e
	sla e
	or e
	ld e,a
	pop af
	; mask
	push bc
	ld b,a
	ld a,(tmp1+1)
	sla a
	sla a
	inc b
	dec b
	jr nz,.m0
	or 3
.m0:	ld (tmp1+1),a
	pop bc
	sla c
	sla c
	ld a,(tmp1)
	dec a
	ld (tmp1),a
	jr nz,.p
	ld l,b
	ld h,REMAPT>>8
	ld (hl),d
	ld h,REMAPD>>8
	ld (hl),e
	ld h,MASKT>>8
	ld a,(tmp1+1)
	ld (hl),a
	inc b
	jr nz,.l
	ret
palof:	; A=1..3 -> physical colour
	push hl
	ld hl,palA-1
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	pop hl
	ret

; ---- copy level tileset through REMAPT into TILEG
build_tiles:
	ld a,(LVLBUF)		; theme
	add a,a
	ld l,a
	ld h,0
	ld de,theme_tab
	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld de,THTMP		; unpack this theme's tiles + far band
	call unlzb
	ld de,THTMP		; DE = logical tiles
	ld hl,TILEG
	ld b,0
.l:	ld a,(de)
	push hl
	ld l,a
	ld h,REMAPT>>8
	ld a,(hl)
	pop hl
	ld (hl),a
	inc hl
	inc de
	djnz .l
	ret

; ---- build pre-shifted sprite cache for this level
build_cache:
	ld hl,(cachebase)
	ld (tmp2),hl
	ld ix,spr_tab
	ld iy,cache_tab
	ld b,NSPR
	ld c,0			; sprite id
.spr:	push bc
	; used by this stage? (bitmask in the stage header)
	ld a,c
	rrca
	rrca
	rrca
	and 31
	ld hl,(cmaskp)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,c
	and 7
	ld b,a
	ld a,(hl)
	inc b
.bt:	dec b
	jr z,.bt2
	rrca
	jr .bt
.bt2:	rrca
	jr c,.use
	xor a
	ld (iy+0),a
	ld (iy+1),a
	jp .nxt
.use:	ld hl,(tmp2)
	ld (iy+0),l
	ld (iy+1),h
	ld a,(ix+0)		; w
	inc a
	ld (iy+4),a		; W
	ld a,(ix+1)
	ld (iy+5),a		; H
	; stride = W*H*2
	ld b,a
	ld a,(iy+4)
	ld e,a
	ld d,0
	ld hl,0
.mu:	add hl,de
	djnz .mu
	add hl,hl
	ld (iy+2),l
	ld (iy+3),h
	; flying sprites keep only the 0 and 2 px shifts (flag: stride bit 15)
	ld a,1
	ld (cstep),a
	push bc
	ld a,c
	rrca
	rrca
	rrca
	and 31
	ld hl,spr2s
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,c
	and 7
	ld b,a
	ld a,(hl)
	inc b
.b2:	dec b
	jr z,.b3
	rrca
	jr .b2
.b3:	pop bc
	rrca
	jr nc,.four
	ld a,2
	ld (cstep),a
	set 7,(iy+3)
.four:
	; build 4 shifts
	ld a,0
.sh:	ld (dsSS),a
	ld l,(ix+2)
	ld h,(ix+3)		; source
	ld a,(ix+1)
	ld (dsRows),a
.row:	ld b,(ix+0)		; w bytes
	ld e,0			; prev byte
.byt:	ld d,(hl)
	inc hl
	push hl
	push bc
	ld h,e
	ld l,d
	ld a,(dsSS)
	add a,a
	jr z,.ns
	ld b,a
.s1:	srl h
	rr l
	djnz .s1
.ns:	ld a,l
	call cput
	pop bc
	pop hl
	ld e,d
	djnz .byt
	; final byte: prev<<8 >> shift
	push hl
	ld h,e
	ld l,0
	ld a,(dsSS)
	add a,a
	jr z,.ns2
	ld b,a
.s2:	srl h
	rr l
	djnz .s2
.ns2:	ld a,l
	call cput
	pop hl
	ld a,(dsRows)
	dec a
	ld (dsRows),a
	jr nz,.row
	ld a,(cstep)
	ld b,a
	ld a,(dsSS)
	add a,b
	cp 4
	jr c,.sh
.nxt:	ld de,4
	add ix,de
	ld de,6
	add iy,de
	pop bc
	inc c
	dec b
	jp nz,.spr
	ret
cstep	db 1
cmaskp	dw LVLBUF+23
cput:	; write mask,data for logical byte A at (tmp2)
	push hl
	ld l,a
	ld h,MASKT>>8
	ld b,(hl)
	ld h,REMAPD>>8
	ld c,(hl)
	ld hl,(tmp2)
	ld (hl),b
	inc hl
	ld (hl),c
	inc hl
	ld (tmp2),hl
	pop hl
	ret

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

; ---- build the 4 shift buffers' ring column A (0..35) from world column HL
;      (needs columns HL and HL+1 decoded in the tile ring)
genB:	ld (gb_ring),a
	ld a,l
	and 63
	ld (gb_ca),a
	inc a
	and 63
	ld (gb_cb),a
	; tile column pointers
	ld a,(gb_ca)
	call tcol
	ld (gb_pa),hl
	ld a,(gb_cb)
	call tcol
	ld (gb_pb),hl
	; dest = SHB + ring
	ld a,(gb_ring)
	ld e,a
	ld d,SHB>>8
	ld ix,TILEG
	ld iy,TILEG
	ld b,NTR
.tr:	push bc
	ld hl,(gb_pa)
	ld a,(hl)
	inc hl
	ld (gb_pa),hl
	add a,a
	add a,a
	ld ixl,a
	ld hl,(gb_pb)
	ld a,(hl)
	inc hl
	ld (gb_pb),hl
	add a,a
	add a,a
	ld iyl,a
	ld h,(ix+0)
	ld l,(iy+0)
	call put4
	ld h,(ix+1)
	ld l,(iy+1)
	call put4
	ld h,(ix+2)
	ld l,(iy+2)
	call put4
	ld h,(ix+3)
	ld l,(iy+3)
	call put4
	call vschk
	pop bc
	djnz .tr
	ret
put4:	ld a,h
	ld (de),a
	add hl,hl
	add hl,hl
	ld a,d
	add a,8
	ld d,a
	ld a,h
	ld (de),a
	add hl,hl
	add hl,hl
	ld a,d
	add a,8
	ld d,a
	ld a,h
	ld (de),a
	add hl,hl
	add hl,hl
	ld a,d
	add a,8
	ld d,a
	ld a,h
	ld (de),a
	ld a,d
	sub 24
	ld d,a
	ld a,e
	add a,ROWB
	ld e,a
	ret nc
	inc d
	ret
tcol:	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld bc,TRING
	add hl,bc
	ret
gb_ring	db 0
gb_ca	db 0
gb_cb	db 0
gb_pa	dw 0
gb_pb	dw 0

; ---- set the view up at world column HL (restart / checkpoint)
setview:
	push hl
	call prof_reset
	pop hl
	ld (scol),hl
	add hl,hl
	add hl,hl
	ld (scrollx),hl
	xor a
	ld (vring),a
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
	; build B ring columns 0..32
	ld hl,(scol)
	xor a
.gl:	push af
	push hl
	call genB
	pop hl
	inc hl
	pop af
	inc a
	cp 33
	jr c,.gl
	ret

; ---- advance scroll by one pixel
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
	ld a,(vring)
	inc a
	cp ROWB
	jr c,$+3
	xor a
	ld (vring),a
	ld hl,(gencol)
	push hl
	call deccol
	pop hl
	push hl
	inc hl
	ld (gencol),hl
	pop hl
	dec hl			; column gencol-1 -> ring (vring+32) mod 36
	ld a,(vring)
	add a,32
	cp ROWB
	jr c,$+4
	sub ROWB
	jp genB

; ---- copy the right shift buffer into compose rows 0..55
bgcopy:
	ld a,(scrollx)
	and 3
	add a,a
	add a,a
	add a,a
	add a,SHB>>8
	ld h,a
	ld a,(vring)
	ld l,a			; HL = row 0 source (row base + ring col)
	; segment lengths
	ld a,ROWB
	sub l			; 36-rc
	cp 33
	jr c,$+4
	ld a,32
	ld c,a			; n1
	add a,a
	ld e,a
	ld a,low(ldiend)
	sub e
	ld (.c1+1),a
	ld a,high(ldiend)
	sbc a,0
	ld (.c1+2),a
	ld a,32
	sub c
	add a,a
	ld e,a
	ld a,low(ldiend)
	sub e
	ld (.c2+1),a
	ld a,high(ldiend)
	sbc a,0
	ld (.c2+2),a
	; HL adjust after seg1: hl = src1+n1 ; row start = src1 - rc
	ld a,(vring)
	add a,c			; rc + n1
	neg
	ld (.a1+1),a
	ld a,$ff
	ld (.a1+2),a
	ld a,(vring)		; next row src1 = rowstart + 36 + rc ; after seg2 hl = rowstart+n2
	add a,ROWB
	sub 32
	add a,c			; 36 + rc - n2  (n2 = 32-n1)
	ld (.a2+1),a
	ld de,COMPOSE
	ld b,PFH
.row:
.c1:	call ldiend
.a1:	ld bc,0
	add hl,bc
.c2:	call ldiend
.a2:	ld bc,0
	add hl,bc
	call sndrow
	ld a,e
	and $ff
	; vsync check every 8 rows
	ld a,(bgrow)
	inc a
	ld (bgrow),a
	and 7
	call z,vschk
	ld a,(bgrow)
	cp PFH
	jr c,.row
	xor a
	ld (bgrow),a
	ret
bgrow	db 0
ldichain:
	REPT 32
	ldi
	ENDR
ldiend:	ret

; ---- draw sprite A at (B=x+32, C=y+16) into compose
drawspr:
	push bc
	ld l,a
	ld h,0
	add hl,hl
	ld e,l
	ld d,h
	add hl,hl
	add hl,de		; *6
	ld de,cache_tab
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,d
	or e
	jr nz,.ok
	pop bc
	ret
.ok:	push de
	ld e,(hl)
	inc hl
	ld d,(hl)		; stride
	inc hl
	ld a,(hl)
	ld (dsW),a
	inc hl
	ld a,(hl)
	ld (dsH),a
	pop hl			; base
	pop bc
	ld a,b
	and 3
	jr z,.s0
	bit 7,d
	jr z,.sa
	res 7,d
	srl a			; 2-shift sprite: x rounded to an even pixel
	jr z,.s0
.sa:	add hl,de
	dec a
	jr nz,.sa
.s0:	; byte column
	ld a,b
	rrca
	rrca
	and $3f
	sub 8			; -8..55
	ld b,a
	; reject
	bit 7,a
	jr nz,.neg
	cp 32
	ret nc
	ld d,0			; skipL
	jr .cnt
.neg:	ld a,(dsW)
	add a,b
	ret z
	ret m
	ld a,b
	neg
	ld d,a			; skipL
	ld b,0
.cnt:	; count = W - skipL, clipped to 32-startcol
	ld a,(dsW)
	sub d
	ld e,a
	ld a,32
	sub b
	cp e
	jr nc,$+3
	ld e,a
	ld a,e
	ld (dsCnt),a
	ld a,(dsW)
	sub e
	add a,a
	ld (dsSkip),a		; src skip bytes per row
	; rows
	ld a,c
	sub 16			; y
	bit 7,a
	jr nz,.yneg
	cp PFH
	ret nc
	ld c,a			; y start
	ld e,0			; skipT
	jr .ry
.yneg:	ld e,a
	ld a,(dsH)
	add a,e
	ret z
	ret m
	ld a,e
	neg
	ld e,a
	ld c,0
.ry:	ld a,(dsH)
	sub e
	ld (dsRows),a
	; clip bottom: y + rows <= PFH
	ld a,c
	push hl
	ld hl,dsRows
	add a,(hl)
	sub PFH
	jr c,.cb
	jr z,.cb
	neg
	add a,(hl)
	ld (hl),a
.cb:	pop hl
	; src += (skipT*W + skipL)*2
	push bc
	ld a,e
	or a
	jr z,.nt
	ld b,a
	ld a,(dsW)
	add a,a
	ld c,a
	push de
	ld d,0
	ld e,c
.tl:	add hl,de
	djnz .tl
	pop de
.nt:	ld a,d
	add a,a
	ld e,a
	ld d,0
	add hl,de
	pop bc
	; dst = COMPOSE + y*32 + startcol(B)
	push hl
	ld l,c
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,l
	add a,b
	ld l,a
	ld a,h
dsbase:	adc a,COMPOSE>>8	; (patched to draw into the cached background)
	ld d,a
	ld e,l
	pop hl
	ld a,(dsRows)
	ld c,a
.r:	ld a,(dsCnt)
	ld b,a
	push de
.b:	ld a,(de)
	and (hl)
	inc hl
	or (hl)
	inc hl
	ld (de),a
	inc e
	djnz .b
	pop de
	ld a,e
	add a,32
	ld e,a
	jr nc,$+3
	inc d
	ld a,(dsSkip)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	dec c
	jr nz,.r
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

; ---- HUD -----------------------------------------------------------
HUDY	equ 56
hud_init:
	; rows 56..63: background, separator line
	ld hl,COMPOSE+HUDY*32
	ld b,32
	ld a,$ff
	call hrem
.s:	ld (hl),a
	inc hl
	djnz .s
	ld bc,7*32
.c:	xor a
	call hrem
	ld (hl),a
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,.c
	; meter frame
	ld hl,COMPOSE+58*32+8
	ld b,16
	ld a,$ff
	call hrem
.m1:	ld (hl),a
	inc hl
	djnz .m1
	ld hl,COMPOSE+62*32+8
	ld b,16
.m2:	ld (hl),a
	inc hl
	djnz .m2
	ld a,$ff
	ld (hudflag),a
	ld (lastchg),a
	jp hud_update
hrem:	; remap logical byte A through the palette (keeps HL,BC,DE)
	push bc
	push de
	ld c,a
	ld b,4
	ld d,0
.l:	ld a,c
	rlca
	rlca
	ld c,a
	and 3
	jr nz,.nz
	ld a,(palT)
	jr .p
.nz:	call palof
.p:	sla d
	sla d
	or d
	ld d,a
	djnz .l
	ld a,d
	pop de
	pop bc
	ret
hud_update:
	; charge meter rows 59..61, 16 bytes (64 px), charge 0..48 -> px = charge*4/3
	ld a,(charge)
	ld hl,lastchg
	cp (hl)
	jr nz,.chg
	ld a,(hudflag)
	or a
	ret z
	ld a,(charge)
.chg:	ld (hl),a
	ld hl,hudblit
	ld (hl),1
	ld c,a
	srl a
	srl a
	add a,c			; ~1.25x
	ld c,a			; pixels filled 0..60
	ld hl,COMPOSE+59*32+8
	ld b,16
.mb:	ld a,c
	cp 4
	jr c,.part
	sub 4
	ld c,a
	ld a,$aa		; logical 2 full
	jr .wr
.part:	ld e,a
	ld c,0
	ld a,0
	inc e
.pp:	dec e
	jr z,.wr
	rrca
	rrca
	or $80
	jr .pp
.wr:	push bc
	call hrem
	ld (hl),a
	ld bc,32
	add hl,bc
	ld (hl),a
	add hl,bc
	ld (hl),a
	ld bc,-63
	add hl,bc
	pop bc
	djnz .mb
	ld a,(hudflag)
	or a
	ret z
	xor a
	ld (hudflag),a
	; score digits
	ld hl,COMPOSE+58*32
	ld de,score
	ld b,3
.sd:	ld a,(de)
	rrca
	rrca
	rrca
	rrca
	call hdig
	ld a,(de)
	call hdig
	inc de
	djnz .sd
	; weapon letter (S L C, or - for none) at byte 24 in red
	ld hl,COMPOSE+58*32+24
	ld a,(podw)
	or a
	ld a,13
	jr z,.wl
	ld a,(podw)
	add a,9
.wl:	ld c,2
	call hdigc
	; speed pips at byte 25: one rising bar per speed level
	ld hl,COMPOSE+58*32+25
	ld b,5
	ld e,0			; row 0..4
.sp:	push bc
	ld d,0
	ld a,(pspeed)
	ld c,a
	ld a,e
	cp 3
	jr c,.s1
	ld a,c
	or a
	jr z,.s1
	ld a,d
	or $c0
	ld d,a
.s1:	ld a,e
	cp 2
	jr c,.s2
	ld a,c
	cp 2
	jr c,.s2
	ld a,d
	or $30
	ld d,a
.s2:	ld a,c
	cp 3
	jr c,.s3
	ld a,d
	or $0c
	ld d,a
.s3:	ld a,d
	and $fc
	ld d,a
	ld a,d			; logical 3 where set
	call hrem
	ld (hl),a
	ld bc,32
	add hl,bc
	inc e
	pop bc
	djnz .sp
	; helpers indicator H at byte 26 in green
	ld hl,COMPOSE+58*32+26
	ld a,(sats)
	or a
	ld a,15
	jr z,$+4
	ld a,14
	ld c,3
	call hdigc
	; lives icons bytes 28..30 rows 59..61
	ld hl,COMPOSE+59*32+28
	ld a,(lives)
	dec a
	ld c,a
	ld b,3
.lv:	push bc
	push hl
	ld a,c
	or a
	jp m,.nol
	jr z,.nol
	ld de,lifeicon
	jr .dl
.nol:	ld de,lifeblank
.dl:	ld b,3
.lr:	ld a,(de)
	call hrem
	ld (hl),a
	inc de
	push bc
	ld bc,32
	add hl,bc
	pop bc
	djnz .lr
	pop hl
	inc hl
	pop bc
	dec c
	djnz .lv
	; stage digit at byte 31
	ld hl,COMPOSE+58*32+31
	ld a,(lvlnum)
	inc a
	jp hdig
hdigc:	; glyph A in logical colour C (1..3)
	ld (hd_c),a
	ld a,c
	ld (hd_col),a
	ld a,(hd_c)
	jr hdig2
hd_c	db 0
hd_col	db 1
hdig:	; draw digit A&15 at HL (5 rows), HL += 1
	push af
	ld a,1
	ld (hd_col),a
	pop af
hdig2:	push de
	push bc
	push hl
	and 15
	ld e,a
	add a,a
	add a,a
	add a,e
	ld e,a
	ld d,0
	ld ix,hudfont
	add ix,de
	ld b,5
	ld de,32
.r:	ld a,(hd_col)
	cp 1
	ld a,(ix+0)
	jr z,.c1
	push bc
	ld c,a
	sla a
	ld b,a
	ld a,(hd_col)
	cp 2
	ld a,b
	jr z,.c2
	or c			; colour 3 = 2x + x
.c2:	pop bc
.c1:	call hrem
	ld (hl),a
	add hl,de
	inc ix
	djnz .r
	pop hl
	inc hl
	pop bc
	pop de
	ret
lifeicon:	db $c0,$f5,$c0
lifeblank:	db 0,0,0

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

; ---- 2x2 bullet: B=x(+32), C=y(+16), D=fill byte (colour in all 4 pixels)
bul2:	ld a,b
	sub 32
	cp 127
	ret nc
	ld b,a
	ld a,c
	sub 16
	cp PFH-1
	ret nc
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,b
	rrca
	rrca
	and 31
	or l
	ld l,a
	ld a,h
	add a,COMPOSE>>8
	ld h,a
	ld a,b
	and 3
	cp 3
	jr z,.split
	ld e,$f0
	or a
	jr z,.m
	ld e,$3c
	dec a
	jr z,.m
	ld e,$0f
.m:	call .px
	ld bc,32
	add hl,bc
.px:	ld a,e
	cpl
	and (hl)
	ld c,a
	ld a,d
	and e
	or c
	ld (hl),a
	ret
.split:	ld e,$03
	call .px
	inc hl
	ld e,$c0
	call .px
	ld bc,31
	add hl,bc
	ld e,$03
	call .px
	inc hl
	ld e,$c0
	jr .px
