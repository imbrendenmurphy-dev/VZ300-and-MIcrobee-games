; =====================================================================
;  COMMIT: run at the start of vertical blank. Everything is ready in
;  RAM; this only points the hardware at it, top of the screen first,
;  so work that runs past the blank stays ahead of the beam.
; =====================================================================
commit:
	MEMV BLK_WORK
	call crtc_scroll
	; --- HUD band (rows 0-1): first, the beam reaches it first
	call hud_commit
	; --- top edge row
	ld a,BK_FIX|LV_SCREEN
	out (P_LV),a
	xor a
	call edge_glyphs
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,(stepped)
	or a
	jr z,.ns0
	ld a,EROW0		; new top playfield row: edge glyphs
	call edge_codes
	ld a,EROW0+1		; old top row, now row 3: scenery again
	call row_restore
.ns0:	; --- sprite cells left behind, then this frame's sprite cells
	call rest_commit
	call new_commit
	call vschk
	; --- far stars (a one-line step; harmless if the beam is mid-way)
	ld a,BK_STAR|LV_SCREEN
	out (P_LV),a
	call star_glyphs
	call vschk
	; --- bottom edge row (the beam is far above it)
	ld a,BK_FIX|LV_SCREEN
	out (P_LV),a
	ld a,1
	call edge_glyphs
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,(stepped)
	or a
	jr z,.ns1
	ld a,EROW1		; (the old bottom row is now hidden)
	call edge_codes
.ns1:	call vschk
	ld a,(page)
	xor 1
	ld (page),a
	ret

; ---------------------------------------------------------------------
;  restore list: ring offset, code, attr, colour (5 bytes)
; ---------------------------------------------------------------------
rest_commit:
	ld a,(nrest)
	or a
	ret z
	ld b,a
	ld c,a
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,RESTLIST
.p1:	ld e,(hl)
	inc hl
	ld a,(hl)
	or $F0
	ld d,a
	inc hl
	ld a,(hl)
	ld (de),a		; code
	inc hl
	inc hl
	set 3,d
	ld a,(hl)
	ld (de),a		; colour
	inc hl
	djnz .p1
	xor a
	out (P_COLCTL),a
	ld a,LV_ATTR
	out (P_LV),a
	ld b,c
	ld hl,RESTLIST
.p2:	ld e,(hl)
	inc hl
	ld a,(hl)
	or $F0
	ld d,a
	inc hl
	inc hl
	ld a,(hl)
	ld (de),a		; attr
	inc hl
	inc hl
	djnz .p2
	ld a,LV_SCREEN
	out (P_LV),a
	ret

; ---------------------------------------------------------------------
;  this frame's sprite cells: list entries (ring offset, colour, row) in
;  slot order; code 80h + (slot & 7Fh), attr = page bank + slot / 128.
;  Done in chunks of 16 so the top of the screen is finished first.
; ---------------------------------------------------------------------
new_commit:
	ld a,(nslot)
	or a
	ret z
	ld (nc_left),a
	ld hl,(listcur)
	ld (nc_ptr),hl
	xor a
	ld (nc_slot),a
	ld a,(page)
	add a,a
	add a,BK_POOLA
	ld (nc_bank),a
.chunk:	ld a,(nc_left)
	cp 16
	jr c,.last
	ld a,16
.last:	ld (nc_n),a
	; pass 1: code + colour
	ld a,COL_ON
	out (P_COLCTL),a
	ld a,(nc_n)
	ld b,a
	ld a,(nc_slot)
	ld c,a
	ld hl,(nc_ptr)
.p1:	ld e,(hl)
	inc hl
	ld a,(hl)
	or $F0
	ld d,a
	inc hl
	ld a,c
	or $80
	ld (de),a		; code
	set 3,d
	ld a,(hl)
	ld (de),a		; colour
	inc hl
	inc hl
	inc c
	djnz .p1
	xor a
	out (P_COLCTL),a
	; pass 2: attribute
	ld a,LV_ATTR
	out (P_LV),a
	ld a,(nc_n)
	ld b,a
	ld a,(nc_slot)
	ld c,a
	ld hl,(nc_ptr)
.p2:	ld e,(hl)
	inc hl
	ld a,(hl)
	or $F0
	ld d,a
	inc hl
	inc hl
	inc hl
	ld a,c
	add a,a			; carry = slot >= 128
	ld a,(nc_bank)
	adc a,0
	ld (de),a
	inc c
	djnz .p2
	ld a,LV_SCREEN
	out (P_LV),a
	ld (nc_ptr),hl
	ld a,c
	ld (nc_slot),a
	ld a,(nc_left)
	ld hl,nc_n
	sub (hl)
	ld (nc_left),a
	jp nz,.chunk
	ret
nc_left	db 0
nc_n	db 0
nc_slot	db 0
nc_bank	db 0
nc_ptr	dw 0
