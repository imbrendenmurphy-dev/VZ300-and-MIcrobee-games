; =====================================================================
;  FRONT END (overlay, kept in block 1 and copied to FEBASE on entry):
;  monitor choice, title + attract pages, stage intro, congratulations,
;  game over, name entry; VZ-TYPE's two-voice beeper music.
;
;  While the front end runs, the lower window holds the TITLE block
;  (picture maps at 4000h) and the screen shows page 0 of video RAM.
; =====================================================================
	jp f_boot
	jp f_title
	jp f_title_hof
	jp f_intro
	jp f_congrats
	jp f_over

TMAP_C	equ $4000		; title picture in the TITLE block
TMAP_B	equ $4400
TMAP_K	equ $4800
OCC	equ QA			; 1 byte per cell: something drawn (no stars)
LOGOK	equ HUDA		; logo colours, rows 1-4 (256 bytes, aligned)

BK_BIG	equ 4			; (banks set by mkfront.py)
BLANK	equ BLANK_CODE

; colours
CK_TEXT	equ $0F
CK_DIM	equ $06
CK_HEAD	equ $0B

; ---------------------------------------------------------------------
;  screen set-up
; ---------------------------------------------------------------------
f_begin:
	xor a
	ld (sfxon),a
	ld (spkbit),a
	out (P_PIOB),a
	ld (demomode),a
	call crtc_game
	call cls_all
	ld a,BLK_TITLE
	call map_blk
	; front-end glyphs: TITLE block 0000-3FFF -> PCG banks 2-9
	ld hl,0
	ld b,2
.bk:	push bc
	ld a,b
	or LV_SCREEN
	out (P_LV),a
	ld de,PCGWIN
	ld bc,$0800
	ldir
	pop bc
	inc b
	ld a,b
	cp 10
	jr nz,.bk
	ld a,LV_SCREEN
	out (P_LV),a
	; nothing drawn yet
	ld hl,OCC
	ld bc,1024
	ld e,0
	call fill
	; logo colours for the glint
	ld hl,TMAP_K+64*LOGO_R0
	ld de,LOGOK
	ld bc,256
	ldir
	ld hl,0
	ld (fe_t),hl
	ld a,255
	ld (shipcol),a
	call fstars_init
	ret

; mapped colour: in monochrome mode everything is white on black
mcol:	ld a,(mono)
	or a
	ld a,c
	ret z
	or a
	ret z
	ld a,CK_TEXT
	ret

; DE = cell offset, A = code, B = bank, C = colour (keeps BC DE)
put:	push hl
	ld hl,VIDEO
	add hl,de
	ld (hl),a
	ld a,LV_ATTR
	out (P_LV),a
	ld (hl),b
	ld a,LV_SCREEN
	out (P_LV),a
	set 3,h
	ld a,COL_ON
	out (P_COLCTL),a
	call mcol
	ld (hl),a
	xor a
	out (P_COLCTL),a
	ld hl,OCC
	add hl,de
	ld (hl),1
	pop hl
	ret

; DE = cell offset: blank, nothing drawn (keeps BC DE)
unput:	push hl
	ld hl,VIDEO
	add hl,de
	ld (hl),BLANK
	ld a,LV_ATTR
	out (P_LV),a
	ld (hl),0
	ld a,LV_SCREEN
	out (P_LV),a
	ld hl,OCC
	add hl,de
	ld (hl),0
	pop hl
	ret

; A = row -> DE = row * 64
rowoff:	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ex de,hl
	ret

; clear B rows from row A
clrrows:
	call rowoff
.r:	push bc
	ld b,64
.c:	call unput
	inc de
	djnz .c
	pop bc
	djnz .r
	ret

; HL = text (codes, 0 end), DE = offset, C = colour -> HL past the end
text:	ld a,(hl)
	inc hl
	or a
	ret z
	ld b,0
	call put
	inc de
	jr text

; centred text: A = row, HL = text, C = colour
ctext:	push af
	push hl
	ld b,0
.n:	ld a,(hl)
	or a
	jr z,.e
	inc b
	inc hl
	jr .n
.e:	pop hl
	pop af
	push af
	ld a,64
	sub b
	srl a
	ld b,a
	pop af
ctext_at:	; A = row, B = column
	push bc
	call rowoff
	pop bc
	ld a,e
	add a,b
	ld e,a
	jr text

; big letters: HL = string (font indices, FFh end), A = row, B = column,
; colours (big_k1) top half, (big_k2) bottom half
big:	push bc
	call rowoff
	pop bc
	ld a,e
	add a,b
	ld e,a
.ch:	ld a,(hl)
	cp 255
	ret z
	inc hl
	push hl
	add a,a
	add a,a
	ld l,a
	ld h,0
	push hl
	ld bc,bf_code
	add hl,bc
	ex (sp),hl
	ld bc,bf_bank
	add hl,bc		; HL = banks, (SP) = codes
	pop ix			; IX = codes
	ld a,(big_k1)
	ld c,a
	ld b,(hl)
	ld a,(ix+0)
	call put
	inc de
	inc hl
	ld b,(hl)
	ld a,(ix+1)
	call put
	ld a,e
	add a,63
	ld e,a
	jr nc,$+3
	inc d
	ld a,(big_k2)
	ld c,a
	inc hl
	ld b,(hl)
	ld a,(ix+2)
	call put
	inc de
	inc hl
	ld b,(hl)
	ld a,(ix+3)
	call put
	ld a,e
	sub 63
	ld e,a
	jr nc,$+3
	dec d
	pop hl
	jr .ch

; centred big text: HL = string, A = row
cbig:	push hl
	ld b,0
.n:	ld c,(hl)
	inc c
	jr z,.e
	inc b
	inc b
	inc hl
	jr .n
.e:	pop hl
	push af
	ld a,64
	sub b
	srl a
	ld b,a
	pop af
	jr big

big_k1	db CK_HEAD
big_k2	db $09

; 6 BCD digits at HL -> screen at DE, colour C
num6:	ld b,3
.d:	push bc
	ld a,(hl)
	rrca
	rrca
	rrca
	rrca
	and 15
	add a,$80+16
	ld b,0
	call put
	inc de
	ld a,(hl)
	and 15
	add a,$80+16
	call put
	inc de
	inc hl
	pop bc
	djnz .d
	ret

; title picture rows from the TITLE block: A = first row, B = rows
tpic:	call rowoff
	ld a,b
	add a,a
	add a,a
	add a,a
	add a,a
	add a,a
	add a,a
	ld c,a
	ld a,b
	rrca
	rrca
	and $3F
	ld b,a			; BC = cells
	ld a,b
	or c
	ret z
.c:	push bc
	ld hl,TMAP_C
	add hl,de
	ld a,(hl)
	or a
	jr z,.n
	ld bc,TMAP_B-TMAP_C
	add hl,bc
	ld b,(hl)
	push bc
	ld bc,TMAP_K-TMAP_B
	add hl,bc
	pop bc
	ld c,(hl)
	call put
.n:	inc de
	pop bc
	dec bc
	ld a,b
	or c
	jr nz,.c
	ret

; ---------------------------------------------------------------------
;  starfield: stars move left through empty cells, two speeds
; ---------------------------------------------------------------------
FNSTAR	equ 24
; a star: cell offset (2), x in half cells (0-127), position in the
; cell (0-3), layer (0 far, 1 near)
fstars_init:
	ld ix,fst
	ld b,FNSTAR
.s:	call rnd
	and 127
	ld (ix+2),a
	call new_row
	ld a,b
	and 1
	ld (ix+4),a
	ld de,5
	add ix,de
	djnz .s
	ret
new_row:	; new row and position for star IX at its x
	call rnd
	and 3
	ld (ix+3),a
	call rnd
	and 15
	call rowoff
	ld a,(ix+2)
	srl a
	or e
	ld e,a
	ld (ix+0),e
	ld (ix+1),d
	ret

; move the stars due this frame (near every 2nd frame, far every 4th)
stars:	ld ix,fst
	ld b,FNSTAR
.s:	ld a,(ix+4)
	or a
	ld a,(fe_t)
	jr z,.far
	and 1
	jr .tm
.far:	and 3
.tm:	jp nz,.nx
	ld e,(ix+0)
	ld d,(ix+1)
	ld hl,OCC
	add hl,de
	ld a,(hl)
	or a
	jr nz,.mv
	ld hl,VIDEO		; erase
	add hl,de
	ld (hl),BLANK
.mv:	ld a,(ix+2)
	dec a
	and 127
	ld (ix+2),a
	cp 127
	jr nz,.same
	call new_row
	jr .draw
.same:	and 1
	jr z,.draw		; still in the same cell
	dec de
	ld (ix+0),e
	ld (ix+1),d
.draw:	ld e,(ix+0)
	ld d,(ix+1)
	ld hl,OCC
	add hl,de
	ld a,(hl)
	or a
	jr nz,.nx
	ld hl,VIDEO
	add hl,de
	ld a,(ix+3)
	add a,a
	ld c,a
	ld a,(ix+2)
	and 1
	or c
	ld c,a
	ld a,(ix+4)
	or a
	ld a,c
	jr z,$+4
	or 8
	add a,$80+80
	ld (hl),a
	set 3,h
	ld a,COL_ON
	out (P_COLCTL),a
	ld a,(ix+4)
	or a
	ld c,$04		; far: blue
	jr z,$+4
	ld c,$07		; near: grey
	call mcol
	ld (hl),a
	xor a
	out (P_COLCTL),a
.nx:	ld de,5
	add ix,de
	dec b
	jp nz,.s
	ret

; ---------------------------------------------------------------------
;  logo glint: a white band sweeps the letters now and then
; ---------------------------------------------------------------------
glint:	ld a,(mono)
	or a
	ret nz
	ld a,(gl_x)
	inc a
	ld (gl_x),a
	cp LOGO_C1+8
	ret nc			; (waits for the counter to wrap)
	sub 6
	ret c
	ld b,0			; logo row
.r:	push bc
	ld a,(gl_x)
	sub b			; slanted with the letters
	ld c,a
	call .one		; column C white
	ld a,c
	sub 3
	ld c,a
	call .res		; three columns back restored
	pop bc
	inc b
	ld a,b
	cp 4
	jr nz,.r
	ret
.cell:	; B = logo row, C = column -> HL = LOGOK entry, DE = screen offset
	ld a,b
	add a,LOGO_R0
	call rowoff
	ld a,e
	add a,c
	ld e,a
	ld a,b
	rrca
	rrca
	and $C0
	add a,c
	ld l,a
	ld h,LOGOK>>8
	ret
.one:	ld a,c
	cp 64
	ret nc
	call .cell
	ld a,(hl)
	or a
	ret z
	and $F0
	or $0F
	jr .set
.res:	ld a,c
	cp 64
	ret nc
	call .cell
	ld a,(hl)
	or a
	ret z
.set:	ld hl,COLWIN
	add hl,de
	push af
	ld a,COL_ON
	out (P_COLCTL),a
	pop af
	ld (hl),a
	xor a
	out (P_COLCTL),a
	ret

; ---------------------------------------------------------------------
;  the ship flying across: shiprow, shipx = pixel x + 64
; ---------------------------------------------------------------------
ship_go:	; A = row
	ld (shiprow),a
	ld hl,0
	ld (shipx),hl
	xor a
	ld (shipcol),a
	ret
ship_step:
	ld a,(shipcol)
	inc a
	ret z			; not flying
	ld a,(fe_t)		; 4 pixels every other frame
	and 1
	ret nz
	ld hl,(shipx)
	inc hl
	inc hl
	inc hl
	inc hl
	ld (shipx),hl
	; first cell column (signed) = x/8 - 8
	ld a,l
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld e,a
	ld a,l
	sub 8
	ld (shipc0),a
	cp 64+1
	jr c,.on
	cp 256-8
	jr nc,.on
	ld a,255		; gone off the right
	ld (shipcol),a
	ret
.on:	; table entry: (exhaust frame * 4 + phase) * 28
	ld a,e
	rrca
	and 3
	ld c,a
	ld a,(fe_t)
	rrca
	rrca
	and 4
	or c
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	push hl
	add hl,hl
	add hl,hl
	add hl,hl		; *32
	pop de
	or a
	sbc hl,de		; *28
	ld de,ship_tab
	add hl,de
	ld (shipsrc),hl
	ld b,0			; row
.r:	push bc
	ld a,(shiprow)
	add a,b
	call rowoff
	ld a,(shipc0)
	dec a			; the column left behind
	call .clr
	ld c,7
	ld a,(shipc0)
	ld b,a
.c:	push bc
	ld a,b
	cp 64
	jr nc,.sk
	push de
	add a,e
	ld e,a
	ld hl,(shipsrc)
	ld a,(hl)
	or a
	jr nz,.vis
	ld a,BLANK
	ld b,0
	ld c,0
	call put
	jr .dn
.vis:	inc hl
	ld c,(hl)
	ld b,6
	call put
.dn:	pop de
.sk:	ld hl,(shipsrc)
	inc hl
	inc hl
	ld (shipsrc),hl
	pop bc
	inc b
	dec c
	jr nz,.c
	pop bc
	inc b
	ld a,b
	cp 2
	jr nz,.r
	ret
.clr:	cp 64
	ret nc
	push de
	add a,e
	ld e,a
	call unput
	pop de
	ret

; ---------------------------------------------------------------------
;  rows 14 (message) and 15 (scroller)
; ---------------------------------------------------------------------
msg_line:
	ld a,14
	ld b,1
	call clrrows
	ld a,(msgn)
	or a
	jr nz,.m1
	ld hl,s_hi
	ld de,hsbuf
	ld bc,9
	ldir
	ld hl,hitab
	call bcd_txt
	ld hl,hsbuf
	ld c,$0E
	jr .show
.m1:	dec a
	jr nz,.m2
	ld hl,s_press
	ld c,$0F
	jr .show
.m2:	ld hl,s_trn_off
	ld c,$06
	ld a,(trainer)
	or a
	jr z,.show
	ld hl,s_trn_on
	ld c,$0B
.show:	ld a,14
	jp ctext
next_msg:
	ld a,(msgn)
	inc a
	cp 3
	jr c,$+3
	xor a
	ld (msgn),a
	jr msg_line

; 6 BCD digits at HL -> text codes at DE (then 0)
bcd_txt:
	ld b,3
.d:	ld a,(hl)
	rrca
	rrca
	rrca
	rrca
	and 15
	add a,$80+16
	ld (de),a
	inc de
	ld a,(hl)
	and 15
	add a,$80+16
	ld (de),a
	inc de
	inc hl
	djnz .d
	xor a
	ld (de),a
	ret

scroll_init:
	ld hl,scroll_txt
	ld (scr_p),hl
	ld de,15*64
	ld b,64
	ld hl,scr_k
.c:	push bc
	ld a,BLANK
	ld c,(hl)
	ld b,0
	call put
	pop bc
	inc hl
	inc de
	djnz .c
	ret
scr_k:	db $04,$04,$04,$04,$0C,$0C,$0C,$06,$06,$06,$0E,$0E,$0E,$0E,$0E,$0E
	db $0E,$0E,$0E,$0E,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
	db $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0E,$0E,$0E,$0E
	db $0E,$0E,$0E,$0E,$0E,$0E,$06,$06,$06,$0C,$0C,$0C,$04,$04,$04,$04
scroll:	ld a,(fe_t)
	and 3
	ret nz
	ld hl,(scr_p)
	inc hl
	push hl
	ld de,64
	add hl,de
	ld a,(hl)
	pop hl
	or a
	jr nz,.ok
	ld hl,scroll_txt	; (starts with the same 64 spaces it ends with)
.ok:	ld (scr_p),hl
	ld de,VIDEO+15*64
	ld bc,64
	ldir
	ret

; ---------------------------------------------------------------------
;  MUSIC: VZ-TYPE's two-voice player. A pulse-wave melody over a square
;  bass, each note clipped short so the notes stand apart. Tune rows:
;  ticks, note1, note2 (MIDI numbers, 0 = rest), flags (1 = drum).
;  A tick is two frames; the callback (mcb) runs once a frame, in the
;  vertical blank, and stops the tune by returning carry (A = 1).
; ---------------------------------------------------------------------
play_tune:	; HL = tune, A = loop flag
	ld (mt_loop),a
	ld (mt_ptr),hl
	ld (mt_start),hl
	xor a
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
	jr c,.stop
	call mplay
	call mcbcall
	jr c,.stop
	ld hl,mt_tk
	dec (hl)
	jr nz,.tick
	jr .row
.stop:	xor a
	out (P_PIOB),a
	inc a
	ret
mcbcall: ld hl,(mcb)
	jp (hl)

setv1:	; melody voice: narrow pulse, duty = period / 4
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
	ld (mplay.w1a+1),a
	ld (mplay.w1b+1),a
	ld a,e
	or a
	ld a,$40
	jr nz,$+3
	xor a
	ld (mplay.m1a+1),a
	ld (mplay.m1b+1),a
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
	ld a,$40
	jr nz,$+3
	xor a
	ld (mplay.x2a+1),a
	ld (mplay.x2b+1),a
	xor a
	ld (m_s2),a
	pop hl
	ret
mute:	; last tick of a row: both voices silent
	xor a
	ld (mplay.m1a+1),a
	ld (mplay.m1b+1),a
	ld (mplay.x2a+1),a
	ld (mplay.x2b+1),a
	ld (m_s2),a
	ret

; play until the next vertical blanking starts. One pass of either loop
; is 122 T-states, which the pitch tables are made for.
mplay:	push ix
	ld a,(m_p1)
	ld b,a
	ld a,(m_p2)
	ld c,a
	ld a,(m_c1)
	ld d,a
	ld a,(m_c2)
	ld e,a
	ld ixh,0
	ld a,(m_s2)
	ld ixl,a
	; still in the blanking period: play until it ends
.la:	dec d
	jr nz,.aa
	ld d,b
.aa:	ld a,d
.w1a:	cp 0
	sbc a,a
.m1a:	and $40
	xor ixh
	out (P_PIOB),a
	dec e
	jr nz,.ba
	ld e,c
	ld a,ixl
.x2a:	xor $40
	ld ixl,a
.ba:	ld a,ixl
	out (P_PIOB),a
	in a,(P_CRTCA)
	and $20
	jr nz,.la
	; the picture: play until the next blanking
.lb:	dec d
	jr nz,.ab
	ld d,b
.ab:	ld a,d
.w1b:	cp 0
	sbc a,a
.m1b:	and $40
	xor ixh
	out (P_PIOB),a
	dec e
	jr nz,.bb
	ld e,c
	ld a,ixl
.x2b:	xor $40
	ld ixl,a
.bb:	ld a,ixl
	out (P_PIOB),a
	in a,(P_CRTCA)
	and $20
	jr z,.lb
	ld a,d
	ld (m_c1),a
	ld a,e
	ld (m_c2),a
	ld a,ixl
	ld (m_s2),a
	xor a
	out (P_PIOB),a
	pop ix
	ret

drum:	; short noise burst
	ld b,0
.d:	ld a,r
	and $40
	out (P_PIOB),a
	ld a,b
	and 3
	jr nz,$+2
	djnz .d
	xor a
	out (P_PIOB),a
	ret

; frames of the callback without music: B = frames (0 = 256)
wait_frames:
.w:	push bc
	call vsync1
	call mcbcall
	pop bc
	ret c
	djnz .w
	or a
	ret

; fire (SPACE or joystick) -> NZ; also remembers it for the edge test
firekey:
	ld a,K_SPACE
	call key1
	ret nz
	in a,(P_PIOA)		; joystick fire (active low; 00 = none fitted)
	or a
	ret z
	cpl
	and $80
	ret
; wait until fire is released
fire_up:
.w:	call vsync1
	call firekey
	jr nz,.w
	ret

; ---------------------------------------------------------------------
;  BOOT: which monitor? then the title
; ---------------------------------------------------------------------
f_boot:
	ld sp,STACKTOP
	; default hall of fame
	ld hl,def_hi
	ld de,hitab
	ld bc,5*8
	ldir
	call f_begin
	ld a,LOGO_R0
	ld b,4
	call tpic
	ld hl,s_mtitle
	ld c,$0F
	ld a,7
	call ctext
	ld hl,s_mc
	ld c,$0E
	ld a,9
	ld b,14
	call ctext_at
	ld hl,s_mm
	ld c,$0B
	ld a,10
	ld b,14
	call ctext_at
	ld hl,s_mret
	ld c,$06
	ld a,13
	call ctext
	ld hl,stars_cb
	ld (mcb),hl
.k:	ld b,1
	call wait_frames
	ld a,K_C
	call key1
	jr nz,.col
	ld a,K_RET
	call key1
	jr nz,.col
	ld a,K_M
	call key1
	jr z,.k
	ld a,1
	jr .set
.col:	xor a
.set:	ld (mono),a
.rel:	call vsync1		; wait for the key to be let go
	xor a
	call keyany
	jr nz,.rel
	jp f_title

; any key on the keyboard -> NZ
keyany:	ld a,K_C
	call key1
	ret nz
	ld a,K_M
	call key1
	ret nz
	ld a,K_RET
	jp key1

stars_cb:
	ld hl,(fe_t)
	inc hl
	ld (fe_t),hl
	call stars
	call ship_step
	or a
	ret

; ---------------------------------------------------------------------
;  TITLE and attract pages: 0 title, 1 hall of fame, 2 how to play,
;  3 power-ups, then the game demo
; ---------------------------------------------------------------------
f_title_hof:
	ld a,1
	jr f_tgo
f_title:
	xor a
f_tgo:	ld sp,STACKTOP
	ld (page),a
	; the HUD's hi score is the top of the table
	ld hl,hitab
	ld de,hiscore
	ld bc,3
	ldir
	call f_begin
	ld a,LOGO_R0
	ld b,4
	call tpic
	ld hl,s_sub
	ld c,CK_DIM
	ld a,5
	call ctext
	xor a
	ld (msgn),a
	call msg_line
	call scroll_init
	call draw_page
	ld hl,title_cb
	ld (mcb),hl
	xor a
	ld (fe_exit),a
.tune:	ld hl,tune_title
	ld a,1
	call play_tune
	ld a,(fe_exit)
	cp 2
	jr z,.demo
	; start a game
	call fire_up
	MEMV BLK_WORK
	xor a
	ld (demomode),a
	jp new_game
.demo:	ld a,(demostage)
	push af
	inc a
	and 7
	ld (demostage),a
	pop af
	jp demo_start

title_cb:
	ld hl,(fe_t)
	inc hl
	ld (fe_t),hl
	call stars
	call glint
	call scroll
	ld a,(page)
	or a
	call z,ship_step
	ld a,(fe_t)
	and 127
	call z,next_msg
	; T: trainer mode on / off
	ld a,K_T
	call key1
	ld a,0
	jr z,$+3
	inc a
	ld hl,tkey
	ld b,(hl)
	ld (hl),a
	or a
	jr z,.nt
	ld a,b
	or a
	jr nz,.nt
	ld a,(trainer)
	xor 1
	ld (trainer),a
	ld a,2
	ld (msgn),a
	call msg_line
.nt:	; next page when its time is up
	ld hl,(pagetm)
	inc hl
	ld (pagetm),hl
	ld a,(page)
	or a
	ld de,500
	jr z,$+5
	ld de,330
	or a
	sbc hl,de
	jr c,.k
	ld a,(page)
	inc a
	cp 4
	jr c,.np
	ld a,2
	ld (fe_exit),a
	scf
	ret
.np:	ld (page),a
	call draw_page
.k:	call firekey
	ret z
	ld a,1
	ld (fe_exit),a
	scf
	ret

draw_page:
	ld hl,0
	ld (pagetm),hl
	ld a,255
	ld (shipcol),a
	ld a,6
	ld b,8
	call clrrows
	ld a,(page)
	or a
	jr z,.p0
	dec a
	jr z,.p1
	dec a
	jp z,.p2
	; ---- power-ups
	ld hl,b_power
	ld a,6
	call head
	ld ix,cap_tab
	ld hl,cap_txt
	ld de,8*64+3		; S L C on rows 8-9
	ld b,3
	call caps
	ld de,10*64+13		; + H on rows 10-11
	ld b,2
	call caps
	ld hl,s_capinfo
	ld c,$06
	ld a,13
	jp ctext
.p0:	; ---- title: credits, the ship, the planet
	ld hl,s_cred1
	ld c,$0E
	ld a,7
	call ctext
	ld a,HZ_R0
	ld b,2
	call tpic
	ld a,10
	jp ship_go
.p1:	; ---- hall of fame
	ld hl,b_hof
	ld a,6
	call head
	ld ix,hitab
	ld a,1
	ld (hof_n),a
.e:	ld a,(hof_n)
	add a,8
	call rowoff
	ld a,e
	add a,22
	ld e,a
	ld a,(hof_n)
	cp 1
	ld c,$0B		; the leader in yellow
	jr z,$+4
	ld c,$0F
	add a,$80+16		; rank digit
	ld b,0
	call put
	inc de
	ld a,$80+'.'-32
	call put
	inc de
	inc de
	inc de
	ld c,$0E
	ld a,(ix+3)
	add a,$60
	call put
	inc de
	ld a,(ix+4)
	add a,$60
	call put
	inc de
	ld a,(ix+5)
	add a,$60
	call put
	inc de
	inc de
	inc de
	inc de
	inc de
	push ix
	pop hl
	ld c,$0F
	call num6
	ld de,8
	add ix,de
	ld hl,hof_n
	inc (hl)
	ld a,(hl)
	cp 6
	jr c,.e
	ret
.p2:	; ---- how to play
	ld hl,b_howto
	ld a,6
	call head
	ld hl,help_txt
	ld a,8
.h:	push af
	ld c,$0F
	call ctext
	pop af
	inc a
	ld b,a
	ld a,(hl)
	inc a
	ret z
	ld a,b
	jr .h

; heading: big text, A = row
head:	push af
	ld a,CK_HEAD
	ld (big_k1),a
	ld a,$09
	ld (big_k2),a
	pop af
	jp cbig

; B capsules from IX (icons) and HL (names) at DE
caps:	push bc
	push de
	push hl
	ld b,2			; icon: 2 rows of 4 cells
.r:	push bc
	ld b,4
.c:	push bc
	ld a,(ix+0)
	or a
	jr z,.e
	ld c,(ix+1)
	ld b,7
	call put
.e:	inc de
	inc ix
	inc ix
	pop bc
	djnz .c
	ld a,e
	add a,60
	ld e,a
	jr nc,$+3
	inc d
	pop bc
	djnz .r
	pop hl
	pop de
	push de
	ld a,e			; name to the right of the icon, upper row
	add a,5
	ld e,a
	ld c,$0F
	call text
	pop de
	ld a,e
	add a,20
	ld e,a
	pop bc
	djnz caps
	ret

; ---------------------------------------------------------------------
;  STAGE INTRO (called from level_start; returns)
; ---------------------------------------------------------------------
f_intro:
	call f_begin
	; STAGE n
	ld hl,b_stage
	ld de,bigbuf
.c:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	inc a
	jr nz,.c
	dec de
	ld a,(lvlnum)
	add a,28		; font index of '1'
	ld (de),a
	inc de
	ld a,255
	ld (de),a
	ld a,$0F
	ld (big_k1),a
	ld a,$0E
	ld (big_k2),a
	ld hl,bigbuf
	ld a,2
	call cbig
	; its name
	ld hl,stage_names
	ld a,(lvlnum)
	or a
	jr z,.nm
	ld b,a
.sk:	ld a,(hl)
	inc hl
	or a
	jr nz,.sk
	djnz .sk
.nm:	ld c,$0B
	ld a,5
	call ctext
	ld a,$0B
	ld (big_k1),a
	ld a,$09
	ld (big_k2),a
	ld hl,b_ready
	ld a,8
	call cbig
	; score and lives
	ld hl,s_score
	ld de,13*64+22
	ld c,$06
	call text
	ld hl,score
	ld c,$0F
	call num6
	ld a,(trainer)
	or a
	jr z,.nt
	ld hl,s_trn_on
	ld c,$0B
	ld a,14
	call ctext
.nt:	ld a,11
	call ship_go
	ld hl,stars_cb
	ld (mcb),hl
	ld hl,tune_stage
	xor a
	call play_tune
	ld b,60
	call wait_frames
	MEMV BLK_WORK
	ret

; ---------------------------------------------------------------------
;  CONGRATULATIONS after the eighth stage (returns)
; ---------------------------------------------------------------------
f_congrats:
	call f_begin
	ld a,$0F
	ld (big_k1),a
	ld a,$0B
	ld (big_k2),a
	ld hl,b_well
	ld a,2
	call cbig
	ld hl,s_cong1
	ld c,$0E
	ld a,6
	call ctext
	ld hl,s_cong2
	ld c,$0D
	ld a,8
	call ctext
	ld hl,s_cong3
	ld c,$0B
	ld a,10
	call ctext
	ld a,12
	call ship_go
	ld hl,stars_cb
	ld (mcb),hl
	ld hl,tune_clear
	xor a
	call play_tune
	ld b,200
	call wait_frames
	MEMV BLK_WORK
	ret

; ---------------------------------------------------------------------
;  GAME OVER, then the hall of fame if the score made it
; ---------------------------------------------------------------------
f_over:	ld sp,STACKTOP
	call f_begin
	ld a,$09
	ld (big_k1),a
	ld a,$01
	ld (big_k2),a
	ld hl,b_game
	ld a,4
	call cbig
	ld hl,s_score
	ld de,8*64+25
	ld c,$06
	call text
	ld hl,score
	ld c,$0F
	call num6
	ld a,(trainer)
	or a
	jr z,.nt
	ld hl,s_trnover
	ld c,$0B
	ld a,11
	call ctext
.nt:	ld hl,stars_cb
	ld (mcb),hl
	ld hl,tune_over
	xor a
	call play_tune
	ld b,100
	call wait_frames
	ld a,(trainer)
	or a
	jp nz,f_title
	call enter_name
	jp c,f_title_hof
	jp f_title

; a place in the hall of fame? -> carry if the name was entered
enter_name:
	ld ix,hitab
	ld b,5
.f:	ld a,(score)
	cp (ix+0)
	jr c,.nx
	jr nz,.got
	ld a,(score+1)
	cp (ix+1)
	jr c,.nx
	jr nz,.got
	ld a,(score+2)
	cp (ix+2)
	jr c,.nx
	jr nz,.got
.nx:	ld de,8
	add ix,de
	djnz .f
	or a
	ret
.got:	push ix
	ld a,b
	dec a
	jr z,.ns
	add a,a
	add a,a
	add a,a
	ld c,a
	ld b,0
	ld hl,hitab+4*8-1
	ld de,hitab+5*8-1
	lddr
.ns:	pop ix
	ld a,(score)
	ld (ix+0),a
	ld a,(score+1)
	ld (ix+1),a
	ld a,(score+2)
	ld (ix+2),a
	ld (ix+3),'A'
	ld (ix+4),'A'
	ld (ix+5),'A'
	ld (nm_ix),ix
	call f_begin
	ld a,$0F
	ld (big_k1),a
	ld a,$0B
	ld (big_k2),a
	ld hl,b_great
	ld a,1
	call cbig
	ld hl,s_enter
	ld c,$0E
	ld a,5
	call ctext
	ld hl,s_ent2
	ld c,$06
	ld a,12
	call ctext
	xor a
	ld (nm_i),a
	ld (nm_rep),a
	ld hl,stars_cb
	ld (mcb),hl
	call fire_up
.lt:	ld b,1
	call wait_frames
	call readinp
	ld hl,(nm_ix)
	inc hl
	inc hl
	inc hl
	ld a,(nm_i)
	ld e,a
	ld d,0
	add hl,de		; the letter
	ld a,(inp)
	and 3
	jr nz,.ud
	xor a
	ld (nm_rep),a
	jr .nd
.ud:	ld b,a
	ld a,(nm_rep)		; repeat every 6 frames while held
	or a
	jr z,.go
	dec a
	ld (nm_rep),a
	jr .nd
.go:	ld a,6
	ld (nm_rep),a
	bit 0,b
	jr z,.dn
	inc (hl)
	ld a,(hl)
	cp 'Z'+1
	jr c,.nd
	ld (hl),'A'
	jr .nd
.dn:	dec (hl)
	ld a,(hl)
	cp 'A'
	jr nc,.nd
	ld (hl),'Z'
.nd:	; the three letters, big; the current one flashes
	ld b,0
.sh:	push bc
	ld hl,(nm_ix)
	inc hl
	inc hl
	inc hl
	ld e,b
	ld d,0
	add hl,de
	ld a,(hl)
	sub 'A'-1		; big font index of the letter
	ld (bigbuf),a
	ld a,255
	ld (bigbuf+1),a
	ld a,(nm_i)
	cp b
	ld a,$0F
	ld c,$0E
	jr nz,.cl
	ld a,(fe_t)
	and 8
	ld a,$0B
	ld c,$09
	jr z,.cl
	ld a,$0F
	ld c,$0D
.cl:	ld (big_k1),a
	ld a,c
	ld (big_k2),a
	ld a,b
	add a,a
	add a,a
	add a,27
	ld b,a
	ld a,8
	ld hl,bigbuf
	call big
	pop bc
	inc b
	ld a,b
	cp 3
	jr c,.sh
	ld a,(inpedge)
	and $18			; fire or right: next letter
	jp z,.lt
	ld hl,nm_i
	inc (hl)
	ld a,(hl)
	cp 3
	jp c,.lt
	call fire_up
	scf
	ret

; ---------------------------------------------------------------------
	INCLUDE "../build/front.inc"

; ---- front-end state (reset each time the overlay is loaded)
fe_t	dw 0
fe_exit	db 0
page	db 0
pagetm	dw 0
msgn	db 0
tkey	db 0
gl_x	db 0
scr_p	dw 0
shipx	dw 0
shipcol	db 255
shipc0	db 0
shiprow	db 0
shipsrc	dw 0
nm_i	db 0
hof_n	db 0
nm_rep	db 0
nm_ix	dw 0
mt_loop	db 0
mt_ptr	dw 0
mt_start dw 0
mt_tk	db 0
mcb	dw stars_cb
m_p1	db 1
m_p2	db 1
m_c1	db 1
m_c2	db 1
m_s2	db 0
hsbuf	ds 18
bigbuf	ds 12
fst	ds FNSTAR*5
