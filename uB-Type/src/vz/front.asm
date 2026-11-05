; =====================================================================
;  FRONT END (mode 1, 128x64, CSS0, blue space): title with logo
;  fly-in, parallax starfield and a ship firepower demo; hall of fame,
;  how to play, stage intro, game over, name entry, congratulations.
;  Everything draws straight into video RAM between music ticks.
; =====================================================================
FEBG	equ $AA			; blue space
FECACHE	equ LVLBUF		; front-end sprite cache (stage RAM is free here)
GLY	equ SP_BIG+1		; 7 logo glyph sprite ids
MIDY	equ 15			; middle region rows MIDY..56
MSGY	equ 58			; bottom message row

txcol	db 0
txA	db 1
txB	db 3
cpat	ds 16

; ---- switch to the mode(1) front end
fe_enter:
	xor a
	ld (sfxon),a
	ld a,$09
	ld (latch),a
	ld (LATCH),a
	ld a,(fe_built)
	or a
	jr nz,.b
	ld a,2
	ld (palT),a
	ld a,1
	ld (palA),a
	ld a,3
	ld (palB),a
	xor a
	ld (palC),a
	ld (bossW),a
	call build_remap
	ld hl,femask
	ld (cmaskp),hl
	ld hl,FECACHE
	ld (cachebase),hl
	call build_cache
	ld hl,LVLBUF+23
	ld (cmaskp),hl
	call build_glyphs
	call build_nbm
	ld a,1
	ld (fe_built),a
.b:	ld a,VRAM>>8
	ld (dsbase+1),a
	xor a
	ld (nrec),a
	ld (fe_t),a
	ld (fe_t+1),a
	; fall into fe_cls
fe_cls:	ld hl,VRAM
	ld de,VRAM+1
	ld bc,2047
	ld (hl),FEBG
	ldir
	jp stars_clrflags

build_glyphs:			; (continues after the sprite cache, at tmp2)
	ld ix,cache_tab+GLY*6
	ld de,logo_gly
	ld b,7
.g:	push bc
	ld hl,(tmp2)
	ld (ix+0),l
	ld (ix+1),h
	ld (ix+2),0
	ld (ix+3),0
	ld (ix+4),4
	ld (ix+5),GLH
	ld b,4*GLH
.c:	ld a,(de)
	inc de
	push bc
	push de
	call cput
	pop de
	pop bc
	djnz .c
	ld bc,6
	add ix,bc
	pop bc
	djnz .g
	ret

; non-background pixel mask table (for the logo glint)
NBM	equ LVLBUF+$D00
build_nbm:
	ld hl,NBM
.l:	ld a,l
	xor FEBG
	ld c,a
	ld b,0
	and $c0
	jr z,$+4
	set 7,b
	ld a,c
	and $30
	jr z,$+4
	set 5,b
	ld a,c
	and $0c
	jr z,$+4
	set 3,b
	ld a,c
	and $03
	jr z,$+4
	set 1,b
	ld a,b			; widen each set bit to its pixel pair
	srl a
	or b
	ld (hl),a
	inc l
	jr nz,.l
	ret

; ---------------------------------------------------------------------
;  text: small 3x5 font (4 px cells, 32 per line) and big 2x font
; ---------------------------------------------------------------------
setcol:	; A = physical colour 0..3 -> cpat[n] for 4-bit pixel patterns
	ld (txcol),a
	push hl
	push bc
	push de
	ld hl,cpat
	ld c,0
.l:	ld b,4
	ld d,0
	ld e,c
.p:	sla d
	sla d
	bit 3,e
	ld a,(txcol)
	jr nz,.s
	ld a,2
.s:	or d
	ld d,a
	sla e
	djnz .p
	ld (hl),d
	inc hl
	inc c
	ld a,c
	cp 16
	jr c,.l
	pop de
	pop bc
	pop hl
	ret
glyph:	; A = char -> DE = its 5 font rows
	sub 32
	jr nc,$+3
	xor a
	cp 59
	jr c,$+3
	xor a
	push hl
	ld l,a
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,hl
	add hl,de
	ld de,font35
	add hl,de
	ex de,hl
	pop hl
	ret
vaddr:	; B = byte column, C = row -> HL
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
	adc a,VRAM>>8
	ld h,a
	ret
cpatA:	; A = 4-bit pattern -> A = byte
	push hl
	ld hl,cpat
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	pop hl
	ret

; small text: HL = string, B = column, C = row, colour set with setcol
ptxt:	ld a,(hl)
	or a
	ret z
	inc hl
	push hl
	push bc
	call glyph
	call vaddr
	ld b,5
.r:	ld a,(de)
	inc de
	rrca
	rrca
	rrca
	rrca
	and 15
	call cpatA
	ld (hl),a
	ld a,l
	add a,32
	ld l,a
	jr nc,$+3
	inc h
	djnz .r
	pop bc
	pop hl
	inc b
	jr ptxt
strlen:	push hl
	ld b,0
.l:	ld a,(hl)
	or a
	jr z,.e
	inc b
	inc hl
	jr .l
.e:	pop hl
	ret
; centred small text on row C in colour A
ptxtc:	call setcol
	call strlen
	ld a,32
	sub b
	srl a
	ld b,a
	jr ptxt

; big text (6x10 per char, 8 px cells, 16 per line): HL, B col, C row,
; rows 0-4 in txA, rows 5-9 in txB
pbig:	ld (pb_s),hl
	ld (pb_bc),bc
	ld a,(txA)
	call setcol
	xor a
	call pbpass
	ld a,(txB)
	call setcol
	ld a,5
pbpass:	ld (pb_k0),a
	ld hl,(pb_s)
	ld bc,(pb_bc)
.ch:	ld a,(hl)
	or a
	ret z
	inc hl
	push hl
	push bc
	call glyph
	ld a,(pb_k0)
	add a,c
	ld c,a
	call vaddr		; HL = first output row
	ld a,(pb_k0)
	srl a
	add a,e
	ld e,a
	jr nc,$+3
	inc d			; DE = first glyph row used
	ld a,(pb_k0)
	ld b,5
.r:	push af
	push bc
	ld a,(de)		; pixels in bits 7,6,5
	ld c,0
	bit 7,a
	jr z,$+4
	set 3,c
	bit 7,a
	jr z,$+4
	set 2,c
	bit 6,a
	jr z,$+4
	set 1,c
	bit 6,a
	jr z,$+4
	set 0,c
	ld b,0
	bit 5,a
	jr z,$+4
	ld b,12
	ld a,c
	call cpatA
	ld (hl),a
	inc hl
	ld a,b
	call cpatA
	ld (hl),a
	dec hl
	ld a,l
	add a,32
	ld l,a
	jr nc,$+3
	inc h
	pop bc
	pop af
	inc a
	bit 0,a
	jr nz,.same		; two output rows per glyph row
	inc de
.same:	djnz .r
	pop bc
	pop hl
	inc b
	inc b
	jr .ch
pb_s	dw 0
pb_bc	dw 0
pb_k0	db 0
; centred big text on row C
pbigc:	call strlen
	ld a,16
	sub b
	ld b,a
	jp pbig

clrrows:	; C = first row, B = count : fill with background
	push bc
	ld b,0
	call vaddr
	pop bc
.r:	push bc
	ld b,32
.c:	ld (hl),FEBG
	inc hl
	djnz .c
	pop bc
	djnz .r
	ret

; ---------------------------------------------------------------------
;  parallax starfield: 3 layers (far red, mid green, near yellow)
; ---------------------------------------------------------------------
NST	equ 24
st_x	ds NST
st_y	ds NST
st_a	ds NST*2
st_m	ds NST
sty0	db 0
styn	db 64
stcol	db $ff,$00,$55
st_l	db 0

stars_clrflags:
	ld hl,st_a
	ld b,NST*2
.l:	ld (hl),0
	inc hl
	djnz .l
	ret
stars_init:	; random stars in rows sty0 .. sty0+styn-1
	call stars_clrflags
	ld b,NST
	ld hl,st_x
.x:	call rnd
	and 127
	ld (hl),a
	inc hl
	djnz .x
	ld b,NST
	ld hl,st_y
.y:	call starrow
	ld (hl),a
	inc hl
	djnz .y
	ret
starrow:	; random row in range -> A
	push bc
	push hl
	push de
	call rnd
	ld e,a
	ld a,(styn)
	call scale8
	ld hl,sty0
	add a,(hl)
	pop de
	pop hl
	pop bc
	ret
stcolA:	push hl
	ld a,(st_l)
	ld hl,stcol
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	pop hl
	ret
stars_step:
	ld c,0			; star index
.l:	ld a,c
.m3:	cp 3
	jr c,.lg
	sub 3
	jr .m3
.lg:	ld (st_l),a
	; ---- erase if plotted
	ld a,c
	add a,a
	ld e,a
	ld d,0
	ld hl,st_a
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,d
	or a
	jr z,.ne
	ld (hl),0
	push bc
	ld b,0
	ld hl,st_m
	add hl,bc
	ld b,(hl)		; mask
	call stcolA
	and b
	ld c,a
	ld a,(de)
	and b
	cp c
	jr nz,.ne2		; something else drew over it: leave it
	ld a,b
	cpl
	ld c,a
	ld a,(de)
	and c
	ld c,a
	ld a,FEBG
	and b
	or c
	ld (de),a
.ne2:	pop bc
.ne:	; ---- move (far layer every other tick)
	ld b,0
	ld hl,st_x
	add hl,bc
	ld a,(st_l)
	or a
	jr nz,.mv
	ld a,(fe_t)
	and 1
	jr nz,.nm
	ld a,1
.mv:	ld d,a
	ld a,(hl)
	sub d
	jp p,.ok
	add a,128
	ld (hl),a
	push hl
	ld hl,st_y
	add hl,bc
	call starrow
	ld (hl),a
	pop hl
	ld a,(hl)
.ok:	ld (hl),a
.nm:	; ---- plot at (x,y) if the pixel is open space
	ld e,(hl)		; x
	ld hl,st_y
	add hl,bc
	push bc
	ld c,(hl)
	ld a,e
	rrca
	rrca
	and 31
	ld b,a
	call vaddr
	ld a,e
	and 3
	ld e,a
	ld d,0
	push hl
	ld hl,pixmask
	add hl,de
	ld b,(hl)		; mask
	pop hl
	ld a,(hl)
	xor FEBG
	and b
	jr nz,.np		; not open space
	call stcolA
	and b
	ld c,a
	ld a,b
	cpl
	and (hl)
	or c
	ld (hl),a
	ld a,b
	ld (st_mk),a
	ex de,hl		; DE = address
	pop bc
	push bc
	ld l,c
	ld h,0
	add hl,hl
	ld bc,st_a
	add hl,bc
	ld (hl),e
	inc hl
	ld (hl),d
	pop bc
	push bc
	ld b,0
	ld hl,st_m
	add hl,bc
	ld a,(st_mk)
	ld (hl),a
.np:	pop bc
	inc c
	ld a,c
	cp NST
	jp c,.l
	ret
st_mk	db 0

; ---------------------------------------------------------------------
;  sprites straight to video RAM with rectangle erase
; ---------------------------------------------------------------------
NREC	equ 20
nrec	db 0
recs	ds NREC*4		; addr(2), w, h
drawrec:	; A = sprite, B = x+32, C = y+16
	push af
	push bc
	ld l,a
	ld h,0
	add hl,hl
	ld e,l
	ld d,h
	add hl,hl
	add hl,de
	ld de,cache_tab+4
	add hl,de
	ld a,(hl)
	ld (dr_w),a
	inc hl
	ld a,(hl)
	ld (dr_h),a
	ld a,b
	rrca
	rrca
	and $3f
	sub 8
	ld (dr_x),a
	ld a,c
	sub 16
	ld (dr_y),a
	call addrec
	pop bc
	pop af
	jp drawspr
addrec:	; clip dr_x,dr_y,dr_w,dr_h to the playfield and remember it
	ld a,(nrec)
	cp NREC
	ret nc
	ld a,(dr_x)
	bit 7,a
	jr z,.x0
	ld hl,dr_w
	add a,(hl)
	ret z
	ret m
	ld (hl),a
	xor a
	ld (dr_x),a
.x0:	ld a,(dr_x)
	cp 32
	ret nc
	ld hl,dr_w
	add a,(hl)
	cp 33
	jr c,.x1
	sub 32
	ld b,a
	ld a,(hl)
	sub b
	ret z
	ret c
	ld (hl),a
.x1:	ld a,(dr_y)
	bit 7,a
	jr z,.y0
	ld hl,dr_h
	add a,(hl)
	ret z
	ret m
	ld (hl),a
	xor a
	ld (dr_y),a
.y0:	ld a,(dr_y)
	cp PFH
	ret nc
	ld hl,dr_h
	add a,(hl)
	cp PFH+1
	jr c,.y1
	sub PFH
	ld b,a
	ld a,(hl)
	sub b
	ret z
	ret c
	ld (hl),a
.y1:	ld a,(dr_x)
	ld b,a
	ld a,(dr_y)
	ld c,a
	call vaddr
	ex de,hl
	ld a,(nrec)
	add a,a
	add a,a
	ld l,a
	ld h,0
	ld bc,recs
	add hl,bc
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld a,(dr_w)
	ld (hl),a
	inc hl
	ld a,(dr_h)
	ld (hl),a
	ld hl,nrec
	inc (hl)
	ret
dr_x	db 0
dr_y	db 0
dr_w	db 0
dr_h	db 0
eraserecs:
	ld a,(nrec)
	or a
	ret z
	ld b,a
	ld ix,recs
.r:	push bc
	ld l,(ix+0)
	ld h,(ix+1)
	ld c,(ix+3)
.row:	push hl
	ld b,(ix+2)
.c:	ld (hl),FEBG
	inc hl
	djnz .c
	pop hl
	ld de,32
	add hl,de
	dec c
	jr nz,.row
	ld de,4
	add ix,de
	pop bc
	djnz .r
	xor a
	ld (nrec),a
	ret

; ---------------------------------------------------------------------
;  logo: fly-in (bunch sweeps in, then spreads) and a travelling glint
; ---------------------------------------------------------------------
FLYN	equ 32
LOGOY	equ 1
LOGOCPY	equ LVLBUF+$E00
flyt	db FLYN
glx	db 0
fly_ease db 0,2,4,6,8,9,11,12,13,14,15,15,16,16,16,16
logo_draw:	; draw all 7 letters at time flyt
	ld c,0
.l:	push bc
	call fly_pos
	add a,8			; byte column -> (x+32)/4
	add a,a
	add a,a
	ld b,a
	ld a,c
	add a,GLY
	ld c,16+LOGOY
	call drawspr
	pop bc
	inc c
	ld a,c
	cp 7
	jr c,.l
	ret
fcolA:	; A = final column of letter C
	push hl
	ld hl,logo_fcol
	ld a,c
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	pop hl
	ret
fly_pos:	; C = letter -> A = byte column at time flyt
	ld a,(flyt)
	cp FLYN
	jr nc,fcolA
	cp 16
	jr nc,.b
	ld b,a			; phase 1: tight bunch sweeps in from the left
	srl a
	srl a
	add a,b
	sub 9
	add a,c
	ret
.b:	sub 16			; phase 2: ease out to the final columns
	ld e,a
	ld d,0
	ld hl,fly_ease
	add hl,de
	ld a,(hl)
	add a,a
	add a,a
	add a,a
	ld e,a			; 0..128
	call fcolA
	sub 9
	sub c			; final - start   (start = 9+c)
	push bc
	call smul
	pop bc
	add a,9
	add a,c
	ret
logo_tick:	; called each tick on every title page
	ld a,(flyt)
	cp FLYN
	jr nc,.glint
	ld c,LOGOY
	ld b,GLH
	call clrrows
	call logo_draw
	ld hl,flyt
	inc (hl)
	ld a,(hl)
	cp FLYN
	ret nz
	; settled: draw final and keep a copy for the glint
	ld c,LOGOY
	ld b,GLH
	call clrrows
	call logo_draw
	ld hl,VRAM+LOGOY*32
	ld de,LOGOCPY
	ld bc,GLH*32
	ldir
	xor a
	ld (glx),a
	ld hl,sfx_clank
	jp sfx
.glint:	ld a,(glx)
	inc a
	cp 120
	jr c,$+3
	xor a
	ld (glx),a
	cp 42
	ret nc
	; restore the logo, then lay the shine over a slanted band
	ld hl,LOGOCPY
	ld de,VRAM+LOGOY*32
	ld bc,GLH*32
	ldir
	ld c,0			; row
.r:	ld a,c
	srl a
	srl a
	ld b,a
	ld a,(glx)
	sub b
	sub 6
	jr c,.nx
	cp 32
	jr nc,.nx
	ld b,a
	push bc
	ld a,c
	add a,LOGOY
	ld c,a
	call vaddr
	pop bc
	ld a,(hl)
	push hl
	ld l,a
	ld h,NBM>>8
	ld d,(hl)		; non-space pixels
	pop hl
	ld a,d
	cpl
	and (hl)
	ld e,a
	ld a,$55		; yellow shine
	and d
	or e
	ld (hl),a
.nx:	inc c
	ld a,c
	cp GLH
	jr c,.r
	ret

; ---------------------------------------------------------------------
;  ship firepower demo (title page)
; ---------------------------------------------------------------------
NDO	equ 16
DO_SHOT	equ 1
DO_BEAM	equ 2
DO_SWIM	equ 3
DO_DART	equ 4
DO_EXPL	equ 5
DO_CAPS	equ 6
dobj	ds NDO*4		; type, x(+32), y(+16), t
dm_t	dw 0
dm_x	db 0
dm_y	db 0
dm_by	db 0
dm_bank	db 0
dm_pod	db 0			; 0 none, 1 docked, 2 out, 3 coming back
dm_px	db 0
dm_chg	db 0
dm_boost db 0
dm_sats	db 0
ds_x1	db 0
ds_y1	db 0
ds_x2	db 0
ds_y2	db 0

demo_reset:
	ld hl,0
	ld (dm_t),hl
	ld a,32-16
	ld (dm_x),a
	ld a,16+34
	ld (dm_y),a
	xor a
	ld (dm_pod),a
	ld (dm_chg),a
	ld (dm_bank),a
	ld (dm_boost),a
	ld (dm_sats),a
	ld hl,dobj
	ld b,NDO*4
.c:	ld (hl),0
	inc hl
	djnz .c
	ret

dnew:	; E = type, B = x, C = y -> IX slot (carry if full)
	ld ix,dobj
	ld d,NDO
.l:	ld a,(ix+0)
	or a
	jr z,.g
	inc ix
	inc ix
	inc ix
	inc ix
	dec d
	jr nz,.l
	scf
	ret
.g:	ld (ix+0),e
	ld (ix+1),b
	ld (ix+2),c
	ld (ix+3),0
	or a
	ret

wave:	; E = type: five in a line from the right
	ld b,32+132
	ld d,5
.l:	push de
	push bc
	ld c,16+34
	call dnew
	jr c,.x
	ld a,d
	add a,a
	add a,a
	add a,a
	add a,a
	ld (ix+3),a		; phase
.x:	pop bc
	pop de
	ld a,b
	add a,13
	ld b,a
	dec d
	jr nz,.l
	ret

demo_tick:
	ld hl,(dm_t)
	inc hl
	ld a,h
	or a
	jr z,.t
	ld a,l
	cp 160			; 416 ticks per loop
	jr c,.t
	call demo_reset
	ld hl,(dm_t)
.t:	ld (dm_t),hl
	; ---- script
	ld a,h
	or a
	jr nz,.late
	ld a,l
	cp 20
	ld c,0
	call z,dcaps
	ld a,(dm_t)
	cp 40
	ld e,DO_SWIM
	call z,wave
	ld a,(dm_t)
	cp 140
	ld e,DO_DART
	call z,wave
	ld a,(dm_t)
	cp 176
	ld c,1
	call z,dcaps
.s3:	ld a,(dm_t)
	cp 236
	ld e,DO_SWIM
	call z,wave
	jr .act
.late:	ld a,l			; 256+
	cp 4
	jr nz,.s5
	ld a,2
	ld (dm_pod),a		; launch the pod
	ld hl,sfx_pod
	call sfx
.s5:	cp 96
	jr c,.act
	ld a,1
	ld (dm_boost),a		; exit stage right
.act:	; ---- ship path
	ld a,(dm_t+1)
	or a
	jr nz,.fly
	ld a,(dm_t)
	cp 30
	jr nc,.fly
	ld a,(dm_x)
	inc a
	ld (dm_x),a
.fly:	ld a,(dm_boost)
	or a
	jr z,.wv
	ld a,(dm_x)
	add a,3
	jr c,.wv
	ld (dm_x),a
.wv:	; weave: y = 34 + 10 sin(t*4)
	ld a,(dm_t)
	add a,a
	add a,a
	ld l,a
	ld h,sint>>8
	ld a,(hl)
	ld e,8
	call smul
	add a,16+37
	ld b,a
	ld a,(dm_y)
	ld (dm_by),a
	ld a,b
	ld (dm_y),a
	; bank from vertical motion, one step per tick
	ld hl,dm_by
	sub (hl)
	ld b,0
	jr z,.bk
	ld b,2
	jp p,.bk
	ld b,-2
.bk:	ld a,(dm_bank)
	cp b
	jr z,.bd
	sub b
	ld a,(dm_bank)
	jp p,.bdn
	inc a
	jr .bs
.bdn:	dec a
.bs:	ld (dm_bank),a
.bd:	; ---- firing
	ld a,(dm_t+1)
	or a
	jr nz,.nf
	ld a,(dm_t)
	cp 44
	jr c,.nf
	cp 120
	jr nc,.chg
	and 7
	jr nz,.nf
	ld a,(dm_x)
	add a,8
	ld b,a
	ld a,(dm_y)
	add a,2
	ld c,a
	ld e,DO_SHOT
	call dnew
	ld a,(dm_sats)
	or a
	jr z,.ns1
	ld a,(ds_x1)
	add a,4
	ld b,a
	ld a,(ds_y1)
	inc a
	ld c,a
	ld e,DO_SHOT
	call dnew
	ld a,(ds_x2)
	add a,4
	ld b,a
	ld a,(ds_y2)
	inc a
	ld c,a
	ld e,DO_SHOT
	call dnew
.ns1:	ld hl,sfx_shot
	call sfx
	jr .nf
.chg:	cp 172
	jr nc,.rel
	ld a,(dm_chg)
	inc a
	ld (dm_chg),a
	jr .nf
.rel:	ld a,(dm_chg)
	or a
	jr z,.nf
	xor a
	ld (dm_chg),a
	ld a,(dm_x)
	add a,8
	ld b,a
	ld a,(dm_y)
	dec a
	ld c,a
	ld e,DO_BEAM
	call dnew
	ld hl,sfx_beam
	call sfx
.nf:	; ---- pod
	ld a,(dm_pod)
	cp 2
	jr nz,.p3
	ld a,(dm_px)
	add a,3
	ld (dm_px),a
	cp 32+112
	jr c,.pe
	ld a,3
	ld (dm_pod),a
	jr .pe
.p3:	cp 3
	jr nz,.pe
	ld a,(dm_x)
	add a,8
	ld b,a
	ld a,(dm_px)
	sub 3
	ld (dm_px),a
	cp b
	jr nc,.pe
	ld a,1
	ld (dm_pod),a
	ld hl,sfx_podback
	call sfx
.pe:	; ---- satellites ease after the ship
	ld a,(dm_x)
	add a,2
	ld b,a
	ld a,(dm_y)
	sub 6
	ld c,a
	ld hl,ds_x1
	call dease
	ld a,(dm_x)
	add a,2
	ld b,a
	ld a,(dm_y)
	add a,8
	ld c,a
	ld hl,ds_x2
	call dease
	; ---- objects
	ld ix,dobj
	ld b,NDO
.o:	push bc
	ld a,(ix+0)
	or a
	jr z,.on
	cp DO_EXPL
	jr z,.ex
	cp DO_CAPS
	jr nz,.nc
	call dcap_move
	jr .on
.nc:	cp DO_SWIM
	jr nc,.en
	; shot / beam: fly right
	ld a,(ix+1)
	add a,5
	ld (ix+1),a
	cp 32+130
	jr c,.on
	ld (ix+0),0
	jr .on
.en:	; enemy: drift left on a sine
	ld a,(ix+1)
	sub 2
	ld (ix+1),a
	cp 8
	jr nc,.e1
	ld (ix+0),0
	jr .on
.e1:	ld a,(ix+3)
	add a,3
	ld (ix+3),a
	ld l,a
	ld h,sint>>8
	ld a,(hl)
	ld e,12
	call smul
	add a,16+37
	ld (ix+2),a
	call dhits
	jr .on
.ex:	inc (ix+3)
	ld a,(ix+3)
	cp 12
	jr c,.on
	ld (ix+0),0
.on:	ld de,4
	add ix,de
	pop bc
	djnz .o
	ret

dhits:	; enemy IX vs pod / shots / beam
	ld a,(dm_pod)
	cp 2
	jr c,.ns
	ld a,(dm_px)
	sub (ix+1)
	add a,6
	cp 12
	jr nc,.ns
	ld a,(dm_y)
	sub (ix+2)
	add a,6
	cp 12
	jr c,.kill
.ns:	ld iy,dobj
	ld b,NDO
.l:	ld a,(iy+0)
	cp DO_SHOT
	jr z,.c
	cp DO_BEAM
	jr nz,.n
.c:	ld a,(ix+1)
	sub (iy+1)
	add a,4
	cp 18
	jr nc,.n
	ld a,(ix+2)
	sub (iy+2)
	add a,5
	cp 11
	jr nc,.n
	ld a,(iy+0)
	cp DO_BEAM
	jr z,.kill
	ld (iy+0),0
.kill:	ld (ix+0),DO_EXPL
	ld (ix+3),0
	ld hl,sfx_pop
	jp sfx
.n:	inc iy
	inc iy
	inc iy
	inc iy
	djnz .l
	ret

demo_draw:
	ld ix,dobj
	ld b,NDO
.o:	push bc
	ld a,(ix+0)
	or a
	jr z,.n
	ld e,SP_SHOT
	cp DO_SHOT
	jr z,.d
	ld e,SP_BEAM3
	cp DO_BEAM
	jr z,.d
	cp DO_EXPL
	jr nz,.en
	ld a,(ix+3)
	srl a
	srl a
	cp 4
	jr c,$+4
	ld a,3
	add a,SP_EXPL0
	ld e,a
	jr .d
.en:	cp DO_CAPS
	jr nz,.en2
	ld e,SP_CAPH
	ld a,(ix+3)
	or a
	jr z,.d
	ld a,(fe_t)		; weapon capsule cycles S L C
	rrca
	rrca
	rrca
	rrca
	and 15
.m3:	cp 3
	jr c,.m3d
	sub 3
	jr .m3
.m3d:	add a,SP_CAPW0
	ld e,a
	jr .d
.en2:	ld e,SP_SWIM0
	cp DO_SWIM
	jr z,.an
	ld e,SP_DART0
.an:	ld a,(fe_t)
	and 4
	jr z,.d
	inc e
.d:	ld a,e
	ld b,(ix+1)
	ld c,(ix+2)
	call drawrec
.n:	ld de,4
	add ix,de
	pop bc
	djnz .o
	; pod
	ld a,(dm_pod)
	or a
	jr z,.np
	cp 1
	jr nz,.pf
	ld a,(dm_x)
	add a,8
	ld (dm_px),a
.pf:	ld a,(dm_px)
	ld b,a
	ld a,(dm_y)
	inc a
	ld c,a
	ld a,(fe_t)
	and 2
	ld a,SP_POD0
	jr z,$+3
	inc a
	call drawrec
.np:	; helper satellites
	ld a,(dm_sats)
	or a
	jr z,.nsat
	ld a,(fe_t)
	and 4
	ld a,SP_SAT0
	jr z,$+3
	inc a
	push af
	ld hl,ds_x1
	ld b,(hl)
	ld hl,ds_y1
	ld c,(hl)
	call drawrec
	pop af
	ld hl,ds_x2
	ld b,(hl)
	ld hl,ds_y2
	ld c,(hl)
	call drawrec
.nsat:	; exhaust and ship
	ld e,SP_EXHN0
	ld a,(dm_boost)
	or a
	jr nz,.xb
	ld a,(dm_t+1)
	or a
	jr nz,.xs
	ld a,(dm_t)
	cp 30
	jr nc,.xs
.xb:	ld e,SP_EXHB0
.xs:	ld a,(fe_t)
	and 2
	jr z,$+3
	inc e
	ld a,(dm_x)
	sub 4
	ld b,a
	ld a,(dm_y)
	inc a
	ld c,a
	ld a,e
	call drawrec
	ld a,(dm_bank)
	add a,SP_SHIPU2+2
	ld hl,dm_x
	ld b,(hl)
	ld hl,dm_y
	ld c,(hl)
	dec c
	call drawrec
	; charge glow at the nose
	ld a,(dm_chg)
	cp 8
	ret c
	ld a,(fe_t)
	and 1
	ret nz
	ld a,(dm_x)
	add a,8
	ld b,a
	ld a,(dm_y)
	ld c,a
	ld a,SP_BEAM1
	jp drawrec

; ---------------------------------------------------------------------
;  title / attract
; ---------------------------------------------------------------------
fe_t	dw 0
page	db 0
pagetm	dw 0
msgn	db 0
tkey	db 0

title:	ld sp,$8000
	xor a
	ld (page),a
	jr title_go
title_hof:
	ld sp,$8000
	ld a,1
	ld (page),a
title_go:
	call fe_enter
	xor a
	ld (flyt),a
	ld (msgn),a
	ld hl,0
	ld (pagetm),hl
	call demo_reset
	call draw_page
	call show_msg
	ld hl,title_cb
	ld (mcb),hl
	ld hl,tune_title
	ld a,1
	call play_tune
.rel:	call firekey
	jr nz,.rel
	jp new_game

draw_page:
	ld c,MIDY
	ld b,MSGY-MIDY
	call clrrows
	ld a,MIDY+6
	ld (sty0),a
	ld a,PFH-MIDY-6
	ld (styn),a
	call stars_init
	xor a
	ld (nrec),a
	ld a,(page)
	or a
	jr z,.p0
	cp 1
	jr z,.p1
	; ---- how to play
	ld a,1
	ld (txA),a
	ld a,3
	ld (txB),a
	ld hl,s_howto
	ld c,MIDY+1
	call pbigc
	ld hl,help_txt
	ld c,MIDY+13
.hl:	ld a,(hl)
	or a
	ret z
	push bc
	ld a,0
	call ptxtc
	pop bc
.sk:	ld a,(hl)
	inc hl
	or a
	jr nz,.sk
	ld a,c
	add a,6
	ld c,a
	jr .hl
.p0:	ld hl,s_sub
	ld c,MIDY
	ld a,3
	jp ptxtc
.p1:	; ---- hall of fame
	ld a,1
	ld (txA),a
	ld a,0
	ld (txB),a
	ld hl,s_hof
	ld c,MIDY+1
	call pbigc
	ld ix,hitab
	ld c,MIDY+13
	ld b,1
.e:	push bc
	ld hl,hstr
	ld a,b
	add a,'0'
	ld (hl),a
	inc hl
	ld (hl),'.'
	inc hl
	ld (hl),' '
	inc hl
	ld a,(ix+3)
	ld (hl),a
	inc hl
	ld a,(ix+4)
	ld (hl),a
	inc hl
	ld a,(ix+5)
	ld (hl),a
	inc hl
	ld (hl),' '
	inc hl
	ld (hl),' '
	inc hl
	push ix
	pop de
	call bcd6
	ld (hl),0
	pop bc
	push bc
	ld hl,hstr
	ld a,b
	dec a
	ld a,1
	jr z,$+4
	ld a,0
	push ix
	call ptxtc
	pop ix
	ld de,8
	add ix,de
	pop bc
	inc b
	ld a,c
	add a,6
	ld c,a
	ld a,b
	cp 6
	jr c,.e
	ret

bcd6:	; write 6 digits of BCD at DE to HL
	ld b,3
.l:	ld a,(de)
	rrca
	rrca
	rrca
	rrca
	and 15
	add a,'0'
	ld (hl),a
	inc hl
	ld a,(de)
	and 15
	add a,'0'
	ld (hl),a
	inc hl
	inc de
	djnz .l
	ret
hiscore_str:
	ld hl,hstr
	ld de,s_hi
.c:	ld a,(de)
	or a
	jr z,.d
	ld (hl),a
	inc hl
	inc de
	jr .c
.d:	ld de,hitab
	call bcd6
	ld (hl),0
	ret
hstr	ds 32

; bottom line: hi score / press fire / trainer state, in turn
show_msg:
	ld c,MSGY
	ld b,5
	call clrrows
	ld a,(msgn)
	or a
	jr nz,.m1
	call hiscore_str
	ld hl,hstr
	ld a,1
	jr .p
.m1:	cp 1
	jr nz,.m2
	ld hl,s_fire
	ld a,1
	jr .p
.m2:	ld a,(trainer)
	or a
	ld hl,s_trn_off
	ld a,0
	jr z,.p
	ld hl,s_trn_on
	ld a,3
.p:	ld c,MSGY
	jp ptxtc

title_cb:
	ld hl,(fe_t)
	inc hl
	ld (fe_t),hl
	call sfx_frame
	call eraserecs
	call stars_step
	call logo_tick
	ld a,(page)
	or a
	jr nz,.np
	ld a,(flyt)
	cp FLYN
	jr c,.np
	call demo_tick
	call demo_draw
.np:	; bottom message every 64 ticks
	ld a,(fe_t)
	and 63
	jr nz,.nm
	ld a,(msgn)
	inc a
	cp 3
	jr c,$+3
	xor a
	ld (msgn),a
	call show_msg
.nm:	; page timer: demo 420 ticks, others 170
	ld hl,(pagetm)
	inc hl
	ld (pagetm),hl
	ld a,(page)
	or a
	ld de,420
	jr z,$+5
	ld de,170
	or a
	sbc hl,de
	jr c,.k
	ld hl,0
	ld (pagetm),hl
	ld a,(page)
	inc a
	cp 3
	jr c,$+3
	xor a
	ld (page),a
	call demo_reset
	call draw_page
.k:	; T toggles trainer mode
	ld a,($68FE)
	cpl
	and 1
	ld hl,tkey
	ld b,(hl)
	ld (hl),a
	jr z,.nt
	ld a,b
	or a
	jr nz,.nt
	ld a,(trainer)
	xor 1
	ld (trainer),a
	ld a,2
	ld (msgn),a
	call show_msg
	ld hl,sfx_caps
	call sfx
.nt:	call firekey
	ret z
	scf
	ret

firekey:	; NZ if SPACE or joystick fire
	ld a,($68EF)
	cpl
	and $10
	ret nz
	ld a,(joyok)
	or a
	ret z
	in a,($2E)
	cpl
	and $10
	ret

; ---------------------------------------------------------------------
;  simple screens: stars + text, the ship crossing below
; ---------------------------------------------------------------------
scr_begin:
	call fe_enter
	xor a
	ld (sty0),a
	ld a,64
	ld (styn),a
	call stars_init
	call demo_reset
	ld a,32-12
	ld (dm_x),a
	ld a,1
	ld (dm_boost),a
	ret
stars_cb:	; music callback for the simple screens
	ld hl,(fe_t)
	inc hl
	ld (fe_t),hl
	call eraserecs
	call stars_step
	ld a,(cross)
	or a
	jr z,.x
	ld a,(dm_x)
	add a,2
	jr c,.x
	ld (dm_x),a
	ld a,(fe_t)
	add a,a
	add a,a
	add a,a
	ld l,a
	ld h,sint>>8
	ld a,(hl)
	ld e,3
	call smul
	add a,16+48
	ld (dm_y),a
	call demo_draw
.x:	or a
	ret
cross	db 0
wait_ticks:	; B ticks of stars_cb, paced by the field sync
.w:	push bc
	call vsync1
	call vsync1
	call stars_cb
	pop bc
	djnz .w
	ret

; ---- stage intro --------------------------------------------------------
stage_intro:
	call scr_begin
	ld a,1
	ld (cross),a
	ld (txA),a
	ld a,3
	ld (txB),a
	ld hl,s_stage
	ld a,(lvlnum)
	inc a
	add a,'0'
	ld (s_stage+6),a
	ld c,10
	call pbigc
	ld a,(lvlnum)
	add a,a
	ld l,a
	ld h,0
	ld de,name_tab
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld c,27
	ld a,0
	call ptxtc
	ld hl,s_ready2
	ld c,36
	ld a,1
	call ptxtc
	ld hl,stars_cb
	ld (mcb),hl
	ld hl,tune_stage
	xor a
	call play_tune
	ld b,24
	call wait_ticks
	xor a
	ld (cross),a
	ret

; ---- game over ---------------------------------------------------------
game_over:
	ld sp,$8000
	call scr_begin
	xor a
	ld (cross),a
	ld a,3
	ld (txA),a
	ld a,1
	ld (txB),a
	ld hl,s_gameover
	ld c,10
	call pbigc
	ld hl,hstr
	ld de,s_score
.c:	ld a,(de)
	or a
	jr z,.d
	ld (hl),a
	inc hl
	inc de
	jr .c
.d:	ld de,score
	call bcd6
	ld (hl),0
	ld hl,hstr
	ld c,30
	ld a,1
	call ptxtc
	ld a,(trainer)
	or a
	jr z,.nt
	ld hl,s_trnover
	ld c,42
	ld a,0
	call ptxtc
.nt:	ld hl,stars_cb
	ld (mcb),hl
	ld hl,tune_over
	xor a
	call play_tune
	ld b,50
	call wait_ticks
	ld a,(trainer)
	or a
	call z,enter_name
	jp title_hof

; ---- name entry ----------------------------------------------------------
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
	call scr_begin
	ld a,1
	ld (txA),a
	ld a,3
	ld (txB),a
	ld hl,s_hi2
	ld c,4
	call pbigc
	ld hl,s_enter
	ld c,19
	ld a,0
	call ptxtc
	ld hl,s_ent3
	ld c,50
	ld a,0
	call ptxtc
	xor a
	ld (nm_i),a
.lt:	call vsync1
	call vsync1
	call vsync1
	call vsync1
	call stars_cb
	call readinp
	ld hl,(nm_ix)
	inc hl
	inc hl
	inc hl
	ld a,(nm_i)
	ld e,a
	ld d,0
	add hl,de		; letter address
	ld a,(inp)
	bit 0,a
	jr z,.nu
	inc (hl)
	ld a,(hl)
	cp 'Z'+1
	jr c,.nu
	ld (hl),'A'
.nu:	ld a,(inp)
	bit 1,a
	jr z,.nd
	dec (hl)
	ld a,(hl)
	cp 'A'
	jr nc,.nd
	ld (hl),'Z'
.nd:	; the three letters big, the current one flashing
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
	ld (nm_c),a
	ld a,(nm_i)
	cp b
	ld a,1
	jr nz,.cl
	ld a,(fe_t)
	and 1
	ld a,3
	jr z,.cl
	xor a
.cl:	ld (txA),a
	ld (txB),a
	ld a,b
	add a,a
	add a,b
	add a,12
	ld b,a
	ld c,30
	ld hl,nm_c
	call pbig
	pop bc
	inc b
	ld a,b
	cp 3
	jr c,.sh
	ld a,(inpedge)
	and $18			; fire or right confirms
	jp z,.lt
	call beep
	ld hl,nm_i
	inc (hl)
	ld a,(hl)
	cp 3
	jp c,.lt
	ret
nm_c	db 0,0
nm_i	db 0
nm_ix	dw 0
beep:	; quick blocking blip
	ld b,60
.b:	ld a,(latch)
	xor $21
	ld (latch),a
	ld (LATCH),a
	ld c,20
.d:	dec c
	jr nz,.d
	djnz .b
	ret

init_hiscores:
	ld hl,def_hi
	ld de,hitab
	ld bc,40
	ldir
	ret

; ---- congratulations -------------------------------------------------------
congrats:
	call scr_begin
	ld a,1
	ld (cross),a
	ld (txA),a
	ld a,0
	ld (txB),a
	ld hl,s_well
	ld c,6
	call pbigc
	ld hl,s_cong1
	ld c,24
	ld a,3
	call ptxtc
	ld hl,s_cong2
	ld c,32
	ld a,1
	call ptxtc
	ld hl,s_cong3
	ld c,40
	ld a,0
	call ptxtc
	ld hl,stars_cb
	ld (mcb),hl
	ld hl,tune_clear
	xor a
	call play_tune
	ld hl,tune_clear
	xor a
	call play_tune
	ld b,60
	call wait_ticks
	xor a
	ld (cross),a
	ret

; ---- demo power-ups
dcaps:	; C = kind (0 helpers, 1 weapon): a capsule floats in from the right
	push bc
	ld e,DO_CAPS
	ld b,32+132
	ld a,(dm_y)
	ld c,a
	call dnew
	pop bc
	ret c
	ld (ix+3),c
	ret
dcap_move:	; drift left, home on the ship's height, get collected
	ld a,(ix+1)
	sub 2
	ld (ix+1),a
	ld a,(dm_y)
	cp (ix+2)
	jr z,.y
	jr c,.yu
	inc (ix+2)
	jr .y
.yu:	dec (ix+2)
.y:	ld a,(dm_x)
	add a,4
	sub (ix+1)
	add a,6
	cp 12
	ret nc
	ld a,(dm_y)
	sub (ix+2)
	add a,6
	cp 12
	ret nc
	; collected
	ld (ix+0),0
	ld a,(ix+3)
	or a
	jr nz,.w
	ld a,1
	ld (dm_sats),a
	ld a,(dm_x)
	ld (ds_x1),a
	ld (ds_x2),a
	ld a,(dm_y)
	ld (ds_y1),a
	ld (ds_y2),a
	jr .s
.w:	ld a,1
	ld (dm_pod),a		; the pod docks
.s:	ld hl,sfx_power
	jp sfx
dease:	; (HL)=x,(HL+1)=y ease toward B,C by up to 2 px
	ld a,(hl)
	call .st
	ld (hl),a
	inc hl
	ld b,c
	ld a,(hl)
	call .st
	ld (hl),a
	ret
.st:	cp b
	ret z
	jr c,.up
	dec a
	cp b
	ret z
	dec a
	cp b
	ret nc
	ld a,b
	ret
.up:	inc a
	cp b
	ret z
	inc a
	cp b
	ret c
	ld a,b
	ret
