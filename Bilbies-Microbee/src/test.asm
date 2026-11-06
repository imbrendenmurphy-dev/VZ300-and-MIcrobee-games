; renderer test: a crowd of bilbies walking on a level, the view panning
NT	equ 40
test_main:
	ld a,1
	ld (rpage),a
	xor a
	ld (vscroll),a
	ld (tframe),a
	; actors: x = 20 + 14*i, y = 70 + (i & 3)*8 ... (screen px)
.loop:	call render_begin
	call scroll_sync
	call render_begin
	call restore
	ld b,NT
	ld c,0
.a:	push bc
	; x = c*12 + tframe*1, y = 120
	ld a,c
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	ld e,l
	ld d,h
	add hl,hl
	add hl,de		; x12
	ld a,(tframe)
	ld e,a
	ld d,0
	add hl,de
	ld b,h
	ld c,l
	ld a,(tframe)
	srl a
	and 7
	ld l,a
	add a,a
	add a,l
	ld l,a
	ld h,0
	ld de,SPRIDX
	add hl,de		; walk frame (tframe/2 & 7)
	ld e,120+32-17
	call draw_sprite
	pop bc
	inc c
	djnz .a
	call apply_colours
	ld a,2
	call waitfields
	ld a,(rpage)
	call show_page
	ld a,(rpage)
	xor 1
	ld (rpage),a
	ld hl,tframe
	inc (hl)
	; pan: every 16 frames one column
	ld a,(hl)
	and 15
	jr nz,.loop
	ld a,(vscroll)
	inc a
	cp 65
	jr c,.ok
	xor a
.ok:	ld (vscroll),a
	jp .loop
tframe	db 0
