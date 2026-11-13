; =====================================================================
;  PARTS: TUNNEL, FLOOR, SWIRL, TWIST - effects no 3.375 MHz Z80 could
;  compute in time, so every frame was computed in advance into RAM blocks
;  (36 frames a block, 25 fps) and the plasma's kernel op shows them:
;  block = ramp[texel], half the rows a frame. The ramp pages (16 colour
;  ones, rotated slowly: colour cycling, and a mono one) are in each block.
; =====================================================================
fx_f	equ pv+8		; the frame within its block (0..35)
fx_blk	equ pv+9		; its block
fx_y	equ pv+10
fx_b0	equ pv+11		; the effect's first block
fx_nb	equ pv+12		; its number of blocks
FX_PER	equ 36

tunnel_part:
	dw tunnel_jobs, tunnel_init, fx_frame, ORD_FLOOR
floor_part:
	dw floor_jobs, floor_init, fx_frame, ORD_SWIRL
swirl_part:
	dw swirl_jobs, swirl_init, fx_frame, ORD_TWIST
twist_part:
	dw twist_jobs, twist_init, fx_frame, ORD_VECTOR

tunnel_init:
	ld bc,FX_TUNNEL_BLK*256+FX_TUNNEL_N
	jr fx_init
floor_init:
	ld bc,FX_FLOOR_BLK*256+FX_FLOOR_N
	jr fx_init
swirl_init:
	ld bc,FX_SWIRL_BLK*256+FX_SWIRL_N
	jr fx_init
twist_init:
	ld bc,FX_TWIST_BLK*256+FX_TWIST_N
fx_init:
	ld a,b
	ld (fx_b0),a
	ld (fx_blk),a
	ld a,c
	ld (fx_nb),a
	ld bc,COLWIN+P_AREA
	ld a,(monomode)
	or a
	jr z,.c
	ld bc,VIDEO+P_AREA
.c:	ld (pp_vbase),bc
	ld hl,plasma_build
	jp lp_both

fx_frame:
	ld hl,(pp_t)
	inc hl
	ld (pp_t),hl
	ld a,l
	and 1
	jr nz,.same		; a new picture every other frame
	ld a,(fx_f)
	inc a
	cp FX_PER
	jr c,.f
	ld a,(fx_b0)
	ld c,a
	ld a,(fx_nb)
	add a,c
	ld c,a
	ld a,(fx_blk)
	inc a
	cp c
	jr c,.b
	ld a,(fx_b0)
.b:	ld (fx_blk),a
	xor a
.f:	ld (fx_f),a
.same:	ld a,(monomode)
	or a
	call z,win_col
	ld a,(monomode)
	or a
	call nz,win_screen
	ld a,(fx_blk)
	call map_blk
	; D = the ramp page: slow colour cycling, or the mono one
	ld hl,(pp_t)
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl		; t / 16 in H
	ld a,h
	and 15
	ld e,a
	ld a,(monomode)
	or a
	ld a,e
	jr z,.r
	ld a,16
.r:	ld (pl_e),a
	ld a,(pp_t)
	and 1
	ld (fx_y),a
	ld a,(lp_build)
	ld h,a
	ld l,0
	ld de,(pp_args)
	add hl,de
	ld (pl_wp),hl
	ld b,10
.rows:	push bc
	call fx_rowp
	push de
	push hl
	ld hl,(pl_wp)
	pop de
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	pop de
	ld (hl),0
	inc hl
	ld (hl),d
	inc hl
	ld (pl_wp),hl
	pop bc
	djnz .rows
	ld hl,(pl_wp)
	inc hl
	ld (hl),0		; the end marker (H = 0)
.vb:	ld a,(fx_y)
	cp P_ROWS
	ret nc
	call fx_rowp
	REPT 32
	ld a,(hl)
	inc l
	ld e,a
	ld a,(de)
	ld (bc),a
	inc c
	ld (bc),a
	inc c
	ENDR
	jp .vb

; row (fx_y), then fx_y += 2: HL = its texels, BC = video, D = ramp page
fx_rowp:
	ld a,(fx_y)
	ld c,a
	add a,2
	ld (fx_y),a
	ld a,(fx_f)		; HL = (20 + 3 f) * 256 + 32 y
	ld b,a
	add a,a
	add a,b
	add a,20
	ld h,a
	ld a,c
	rrca
	rrca
	rrca
	ld l,a
	and $1F
	add a,h
	ld h,a
	ld a,l
	and $E0
	ld l,a
	push hl
	ld l,c
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld bc,(pp_vbase)
	add hl,bc
	ld b,h
	ld c,l
	pop hl
	ld a,(pl_e)
	ld d,a
	ret
