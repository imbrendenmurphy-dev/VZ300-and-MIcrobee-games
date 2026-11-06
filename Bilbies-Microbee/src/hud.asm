; =====================================================================
;  HUD: rows 10-15 of both pages. Row 10 the status line, rows 11-14 the
;  twelve buttons (counts on row 11), row 15 the level's name; the
;  minimap at columns 48-63, rows 11-15.
; =====================================================================
G_FONT	equ 0			; glyph = ASCII - 32 (bank 12)
HUD_SCR	equ $F000+10*64		; page 0 row 10 (page 1: +400h)

hud_init:
	call hud_glyphs
	jp hud_layout
; the panel's glyphs into PCG banks 12-15
hud_glyphs:
	MEMV BLK_GFX
	ld hl,0
	ld b,BK_HUD
.pb:	ld a,b
	or LV_SCREEN
	out (P_LV),a
	ld de,PCGWIN
	push bc
	ld bc,2048
	ldir
	pop bc
	inc b
	ld a,b
	cp 16
	jr nz,.pb
	ld a,LV_SCREEN
	out (P_LV),a
	ret
hud_layout:
	MEMV BLK_GFX
	; layout on both pages
	ld hl,$2000
	ld de,HUD_SCR
	ld bc,384
	ldir
	ld hl,$2000
	ld de,HUD_SCR+$400
	ld bc,384
	ldir
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,$2180
	ld de,HUD_SCR
	ld bc,384
	ldir
	ld hl,$2180
	ld de,HUD_SCR+$400
	ld bc,384
	ldir
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,$2300
	ld a,(monomode)
	or a
	jr z,.c
	ld hl,$2480
.c:	push hl
	ld de,HUD_SCR+$800
	ld bc,384
	ldir
	pop hl
	ld de,HUD_SCR+$C00
	ld bc,384
	ldir
	xor a
	out (P_COLCTL),a
	; the level's name on row 15
	MEMV BLK_WORLD
	ld hl,WHDR+LH_NAME
	ld de,hud_nbuf
	ld bc,24
	ldir
	ld hl,hud_nbuf
	ld de,15*64+2
	call hud_text
	ld a,255
	ld (hud_sel),a
	ld (hud_pause),a
	ld hl,hud_sold
	ld b,64
.so:	ld (hl),0
	inc hl
	djnz .so
	ld a,1
	ld (v_pdirty),a
	jp mm_glyphs

; HL = 0-terminated text, DE = screen offset (row*64 + col): both pages
hud_text:
	ld a,(hl)
	or a
	ret z
	sub 32
	or $80
	push de
	push af
	ld a,d
	or $F0
	ld d,a
	pop af
	ld (de),a
	set 2,d
	ld (de),a
	pop de
	inc hl
	inc de
	jr hud_text

; A = cell colour for button B (0-11), rows 11-14: both pages
hud_btn_colour:
	ld c,a
	ld a,COL_ON
	out (P_COLCTL),a
	ld a,b
	add a,a
	add a,a
	ld e,a
	ld d,0
	ld hl,$F800+11*64
	add hl,de
	ld b,4
.r:	push bc
	push hl
	ld b,4
.c:	ld (hl),c
	set 2,h
	ld (hl),c
	res 2,h
	inc hl
	djnz .c
	pop hl
	ld de,64
	add hl,de
	pop bc
	djnz .r
	xor a
	out (P_COLCTL),a
	ret

; ---- every frame: highlights, counts, the status line
hud_update:
	call vschk
.snd1:	SND 6
	ld a,(v_title)
	or a
	jp nz,title_panel
	; selection highlight
	ld a,(v_sel)
	ld hl,hud_sel
	cp (hl)
	jr z,.s1
	push af
	ld a,(hl)
	ld (hl),255
	cp 12
	jr nc,.s0
	ld b,a
	call btn_normal
	call hud_btn_colour
.s0:	pop af
	ld (hud_sel),a
	ld b,a
	call btn_lit
	call hud_btn_colour
.s1:	ld a,(v_paused)
	ld hl,hud_pause
	cp (hl)
	jr z,.s2
	ld (hl),a
	ld b,BT_PAUSE
	or a
	jr z,.pn
	call btn_lit
	jr .pc
.pn:	call btn_normal
.pc:	call hud_btn_colour
.s2:	; counts
	ld a,(v_pdirty)
	or a
	jr z,.st
	xor a
	ld (v_pdirty),a
	ld a,(v_minrate)
	ld de,11*64+1
	call hud_num2
	ld a,(v_rate)
	ld de,11*64+5
	call hud_num2
	ld hl,v_skill
	ld de,11*64+9
	ld b,8
.sk:	push bc
	push hl
	push de
	ld a,(hl)
	call hud_num2
	pop de
	pop hl
	pop bc
	inc hl
	inc de
	inc de
	inc de
	inc de
	djnz .sk
.st:	call vschk		; status line: what's under the cursor, out, in, time
.snd2:	SND 5
	ld hl,hud_sbuf
	ld b,62
.cl:	ld (hl),' '
	inc hl
	djnz .cl
	ld (hl),0
	ld de,hud_sbuf+1
	ld a,(v_hcount)
	or a
	jr z,.nh
	push af
	ld a,(v_hst)
	add a,a
	ld l,a
	ld h,0
	ld bc,STNAMES
	add hl,bc
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call strcpy
	inc de
	pop af
	call fmt_num
.snd14:	SND 10
.nh:	ld de,hud_sbuf+20
	ld hl,s_out
	call strcpy
	call count_out
	call fmt_num
.snd15:	SND 40
	ld de,hud_sbuf+32
	ld hl,s_in
	call strcpy
	; in % = saved * 100 / n
	ld a,(v_saved)
	ld l,a
	ld h,0
	ld c,l
	ld b,h
	add hl,hl
	add hl,bc
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,bc
	add hl,hl
	add hl,hl		; x100
	ld a,(v_ncrt)
	call div16_8		; HL / A -> A
	call fmt_num
.snd16:	SND 27
	ld a,'%'
	ld (de),a
	ld de,hud_sbuf+46
	ld hl,s_time
	call strcpy
	ld hl,(v_tleft)		; minutes:seconds
	ld a,60
	call div16_8		; A = minutes, C = seconds
	push bc
	call fmt_num
.snd17:	SND 26
	ld a,'-'
	ld (de),a
	inc de
	pop bc
	ld a,c
	ld b,'0'-1
.t10:	inc b
	sub 10
	jr nc,.t10
	add a,'0'+10
	ld c,a
	ld a,b
	ld (de),a
	inc de
	ld a,c
	ld (de),a
	ld a,(v_paused)
	or a
	jr z,.np
	ld hl,s_paused
	ld de,hud_sbuf+56
	call strcpy
.np:	; write only what changed since last time (both pages)
	ld hl,hud_sbuf
	ld de,hud_sold
	ld bc,10*64+1+$F000
.w:	ld a,(hl)
	or a
	ret z
	ex de,hl
	cp (hl)
	jr z,.same
	ld (hl),a
	sub 32
	or $80
	ld (bc),a
	set 2,b
	ld (bc),a
	res 2,b
.same:	ex de,hl
	inc hl
	inc de
	inc bc
	jr .w

btn_normal:
	ld a,(monomode)
	or a
	ld a,(BLUE<<4)|WHITE
	ret z
	ld a,(BLACK<<4)|GREY
	ret
btn_lit:
	ld a,(monomode)
	or a
	ld a,(RED<<4)|WHITE
	ret z
	ld a,(DGREY<<4)|WHITE
	ret

; A = 0-99 at screen offset DE (two characters, both pages)
hud_num2:
	ld b,'0'-1
.t:	inc b
	sub 10
	jr nc,.t
	add a,'0'+10
	ld c,a
	ld a,b
	cp '0'
	jr nz,.n
	ld a,' '
.n:	ld (hud_n2),a
	ld a,c
	ld (hud_n2+1),a
	xor a
	ld (hud_n2+2),a
	ld hl,hud_n2
	jp hud_text

; copy 0-terminated (HL) to (DE), DE left after it
strcpy:	ld a,(hl)
	or a
	ret z
	ld (de),a
	inc hl
	inc de
	jr strcpy

; A (0-255) as decimal at (DE), DE after it
fmt_num:
	ld c,0
	ld b,100
	call .dg
	ld b,10
	call .dg
	add a,'0'
	ld (de),a
	inc de
	ret
.dg:	ld l,'0'-1
.d1:	inc l
	sub b
	jr nc,.d1
	add a,b
	ld h,a
	ld a,l
	cp '0'
	jr nz,.out
	bit 0,c
	jr z,.skip
.out:	ld (de),a
	inc de
	ld c,1
.skip:	ld a,h
	ret

; HL / A -> A = quotient (low byte), C = remainder
div16_8:
	ld c,a
	ld b,16
	xor a
.l:	add hl,hl
	rla
	jr c,.s
	cp c
	jr c,.n
.s:	sub c
	inc l
.n:	djnz .l
	ld c,a
	ld a,l
	ret

; the button under the cursor: A = 0-11, 12 the minimap, 255 none
hud_button:
	ld a,(cur_y)
	cp 176
	jr c,.no
	ld hl,(cur_x)
	ld a,h
	or a
	jr nz,.mm		; 256-511
	ld a,l
	rrca
	rrca
	rrca
	rrca
	rrca
	and 7			; x / 32
	ret
.mm:	ld a,l
	cp 128
	jr nc,.m
	rrca
	rrca
	rrca
	rrca
	rrca
	and 3
	add a,8
	ret
.m:	ld a,12
	ret
.no:	ld a,255
	ret
; minimap x (0-127) under the cursor
hud_mm_x:
	ld a,(cur_x)
	sub 128			; (cur_x 384-511: low byte 128-255)
	ret

s_out:	db "OUT ",0
s_in:	db "IN ",0
s_time:	db "TIME ",0
s_paused:	db "PAUSED",0
STNAMES:	dw stn0,stn1,stn2,stn3,stn4,stn4,stn6,stn7,stn8,stn9,stn10,stn11,stn0,stn0,stn0,stn15,stn0,stn0
stn0:	db 0
stn1:	db "WALKER ",0
stn2:	db "FALLER ",0
stn3:	db "FLOATER ",0
stn4:	db "CLIMBER ",0
stn6:	db "BLOCKER ",0
stn7:	db "BUILDER ",0
stn8:	db "SHRUGGER ",0
stn9:	db "BASHER ",0
stn10:	db "MINER ",0
stn11:	db "DIGGER ",0
stn15:	db "BOMBER ",0
