; =====================================================================
;  STARHIVE - SOFTSCRL: software fine scroll test (40 x 24, 8 x 11 cells)
;  The frame length never changes (R5 = 4, 312 lines). Coarse scroll is
;  the start address (proven on the real machine); the fine scroll k is
;  done by PCG banks: phase k of every scenery "pair" glyph is in bank k,
;  so moving the picture down a line is one attribute write per scenery
;  cell. Far stars (bank 11) are rotated at half speed for parallax.
;  Keys: 0-4 speed, F = 50 / 25 frames a second.
;  VIBED BY BPM 2026
; =====================================================================
	DEVICE NOSLOT64K
	INCLUDE "hw.inc"

COLT	equ $B000		; colour of slot s at phase k: COLT + 256 k + s
SEGS	equ $C000		; per map row (row & 31, 256 bytes each): its pair
				; cells on screen: address, colL, colU; 0 ends
HUDC	equ $E000		; HUD codes (80) and colours (80)
HUDK	equ $E050
VROWS	equ 22
R5FIX	equ 4			; 28 rows x 11 + 4 = 312 lines

	ORG $8000
start:	di
	ld sp,$EFF0
	call hw_init
	MEMV BLK_ROWS		; (video RAM window on)
	ld a,1
	in a,(P_CLK40)
	ld hl,crtc_tab
	ld c,0
.ci:	ld a,c
	out (P_CRTCA),a
	ld a,(hl)
	out (P_CRTCD),a
	inc hl
	inc c
	ld a,c
	cp 16
	jr nz,.ci
	call pcg_clear
	; font glyphs: bank 11, codes 81h..
	ld a,LV_SCREEN|STAR_BANK
	out (P_LV),a
	ld hl,font_gl
	ld de,PCGWIN+16
	ld bc,N_FONT*16
	ldir
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,2
	ld (speed),a
	ld a,1
	ld (fields),a

; ---------------------------------------------------------------------
restart:
	ld sp,$EFF0
	call cls
	ld hl,21
	ld (top),hl
	xor a
	ld (k),a
	ld (s88),a
	ld (acc),a
	ld (step),a
	ld hl,0
	ld (scrS),hl
	call hud_build
	; load every pair of the first screen (group 21)
	ld hl,21
	call group_ptr
.ld:	ld a,(load_left)
	or a
	jr z,.ldd
	call load_one
	jr .ld
.ldd:	ld hl,22
	call group_ptr
	; draw the playfield: display row d (2..23) = map row 21 - (d - 2)
	ld b,2
.dr:	push bc
	ld a,23
	sub b			; r = 23 - d
	ld l,a
	ld h,0
	ld a,b
	call ring_of		; DE = ring offset of display row d
	push hl
	push de
	call write_row
	pop de
	pop hl
	call seg_build
	pop bc
	inc b
	ld a,b
	cp 24
	jr nz,.dr
	ld a,1
	ld (hudd),a
	call star_off
main:	ld a,(fields)
	ld b,a
.w:	push bc
	call vblank
	pop bc
	djnz .w
	call commit
	call advance
	ld a,(fields)
	add a,a
	add a,2			; loads per frame: 4 at 50 fps, 6 at 25 fps
	ld b,a
.l:	ld a,(load_left)
	or a
	jr z,.ln
	push bc
	call load_one
	pop bc
	djnz .l
.ln:	call keys
	jp main

; ---------------------------------------------------------------------
;  commit, at the start of vertical blanking: top of the screen first
; ---------------------------------------------------------------------
commit:	ld a,(step)
	or a
	jr z,.ns
	ld hl,(scrS)		; start address (latched at the next frame)
	ld a,12
	out (P_CRTCA),a
	ld a,h
	out (P_CRTCD),a
	ld a,13
	out (P_CRTCA),a
	ld a,l
	out (P_CRTCD),a
	call hud_write
	ld hl,(top)		; the new top row
	ld a,2
	call ring_of
	call write_row
	jr .st
.ns:	ld a,(hudd)
	or a
	call nz,hud_write
.st:	call stars
	call pass
	ld a,(step)
	or a
	ret z
	xor a
	ld (step),a
	ld hl,(top)		; loads for the next step may start now
	inc hl
	jp group_ptr

; every pair cell on screen: attribute = bank k, colour by phase
pass:	ld a,LV_ATTR
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	ld (spsave),sp
	ld a,(top)		; segment page of the top row
	and 31
	or SEGS>>8
	ld (ps_page),a
	ld a,VROWS
	ld (ps_n),a
	ld a,(k)
	ld d,a			; D = bank = phase
	add a,COLT>>8
	ld e,a			; E = colour page of this phase
.rl:	ld a,(ps_page)
	ld h,a
	ld l,0
	ld sp,hl
.l:	pop hl
	bit 7,h
	jr z,.nl
	pop bc			; C = slot
	ld (hl),d
	ld b,e
	ld a,(bc)
	set 3,h
	ld (hl),a
	jp .l
.nl:	ld a,(ps_page)
	dec a
	and 31
	or SEGS>>8
	ld (ps_page),a
	ld hl,ps_n
	dec (hl)
	jr nz,.rl
	ld sp,(spsave)
	xor a
	out (P_COLCTL),a
	ld a,LV_SCREEN
	out (P_LV),a
	ret

; ---------------------------------------------------------------------
;  advance the scroll and prepare the next commit
; ---------------------------------------------------------------------
advance:
	ld a,(fields)
	ld b,a
	ld a,(speed)
	ld c,a
	ld a,(acc)
.m:	add a,c
	djnz .m
	ld c,a
	srl c			; C = whole lines
	and 1
	ld (acc),a
	ld a,(s88)
	add a,c
	cp 88
	jr c,.s
	sub 88
.s:	ld (s88),a
	ld a,(k)
	add a,c
	cp CL
	jr c,.nk
	sub CL
	ld (k),a
	; coarse step: top row + 1
	ld hl,(top)
	inc hl
	ld (top),hl
	ld de,-(NROWS-1)
	add hl,de
	jp nc,.ok
	jp restart		; end of the level: round again
.ok:	ld hl,(scrS)
	ld de,-40
	add hl,de
	ld a,h
	and 7
	ld h,a
	ld (scrS),hl
.fl:	ld a,(load_left)	; the new row's pairs must be in
	or a
	jr z,.fd
	call load_one
	jr .fl
.fd:	ld a,2			; the new top row's segment
	call ring_of
	ld hl,(top)
	call seg_build
	ld a,1
	ld (step),a
	jr star_off
.nk:	ld (k),a
star_off:			; off = (s88 / 2 - k) mod 44
	ld a,(s88)
	srl a
	ld hl,k
	sub (hl)
	jr nc,.p
	add a,44
.p:	cp 44
	jr c,.o
	sub 44
.o:	ld (soff),a
	ret

; ---------------------------------------------------------------------
;  HL = map row, DE = its ring offset: the row's segment (pair cells)
; ---------------------------------------------------------------------
seg_build:
	ld (bl_base),de
	ld a,l
	and 31
	or SEGS>>8
	ld d,a
	ld e,0
	ld (bl_dst),de
	call row_rec
	ld a,l
	add a,120
	ld l,a
	ld b,(hl)
	inc hl
	ld de,(bl_dst)
	ld a,b
	or a
	jr z,.e
.c:	ld a,(hl)		; column
	inc hl
	push hl
	ld hl,(bl_base)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,h
	and 7
	or $F0
	ex de,hl
	ld (hl),e
	inc hl
	ld (hl),a
	inc hl
	ex de,hl
	pop hl
	ld a,(hl)		; slot
	inc hl
	ld (de),a
	inc de
	inc de
	djnz .c
.e:	ex de,hl
	ld (hl),0
	inc hl
	ld (hl),0
	ret

; A = display row, uses (scrS) -> DE = ring offset (S + 40 A) & 7FFh
ring_of:
	push hl
	ld hl,(scrS)
	ld de,40
	or a
	jr z,.d
.a:	add hl,de
	dec a
	jr nz,.a
.d:	ld a,h
	and 7
	ld d,a
	ld e,l
	pop hl
	ret

; HL = map row -> its record mapped in the lower window, HL = address
row_rec:
	ld a,l
	and $7F
	push af
	add hl,hl		; H = row / 128
	ld a,h
	add a,BLK_ROWS
	call blkport
	out (P_MEM),a
	pop af
	ld h,a
	ld l,0
	ret

; A = block -> A = port 50h value (ROMs off, video window on)
blkport:
	push bc
	ld b,a
	and 3
	xor 2
	ld c,a
	ld a,b
	and $1C
	rlca
	rlca
	rlca
	or c
	or 4
	pop bc
	ret

; HL = map row, DE = ring offset: codes, attributes, colours of the row
write_row:
	push de
	call row_rec
	pop de
	push hl
	push de
	ld a,$F0
	ld bc,40
	call rcopy		; codes
	ld a,LV_ATTR
	out (P_LV),a
	pop de
	pop hl
	push hl
	push de
	ld bc,40
	add hl,bc
	ld a,$F0
	call rcopy		; attributes (pair cells bank 0, stars bank 11)
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	pop de
	pop hl
	ld bc,80
	add hl,bc
	ld bc,40
	ld a,$F8
	call rcopy		; colours
	xor a
	out (P_COLCTL),a
	ret

; HL = source, DE = ring offset, BC = count, A = window (F0h / F8h)
rcopy:	ld (rc_win),a
	push hl
	ld hl,$0800
	or a
	sbc hl,de		; room before the wrap
	push hl
	or a
	sbc hl,bc
	pop hl
	jr c,.split
	pop hl
	ld a,(rc_win)
	or d
	ld d,a
	ldir
	ret
.split:	push bc			; n1 = room, n2 = count - room
	ld b,h
	ld c,l
	pop hl
	or a
	sbc hl,bc
	ex (sp),hl		; (sp) = n2, HL = source
	ld a,(rc_win)
	or d
	ld d,a
	ldir
	pop bc
	ld a,(rc_win)
	ld d,a
	ld e,0
	ldir
	ret

; the two HUD rows at the top of the ring
hud_write:
	xor a
	ld (hudd),a
	ld de,(scrS)
	ld hl,HUDC
	ld bc,80
	ld a,$F0
	call rcopy
	ld a,LV_ATTR
	out (P_LV),a
	ld de,(scrS)
	ld hl,hud_attr
	ld bc,80
	ld a,$F0
	call rcopy
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	ld de,(scrS)
	ld hl,HUDK
	ld bc,80
	ld a,$F8
	call rcopy
	xor a
	out (P_COLCTL),a
	ret

; far stars: glyph (v, q) at code F0h + 4v + q shows texture v from line
; 11q + off (the textures are stored twice over)
stars:	ld a,LV_SCREEN|STAR_BANK
	out (P_LV),a
	ld de,PCGWIN+$700
	ld ix,star_texs
	ld c,4
.v:	ld a,(soff)
	ld b,4
.q:	push bc
	push af
	ld l,(ix+0)
	ld h,(ix+1)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	REPT 11
	ldi
	ENDR
	ld a,e
	add a,5
	ld e,a
	pop af
	add a,11
	cp 44
	jr c,$+4
	sub 44
	pop bc
	djnz .q
	inc ix
	inc ix
	dec c
	jr nz,.v
	ld a,LV_SCREEN
	out (P_LV),a
	ret
star_texs:	dw star_tex0,star_tex1,star_tex2,star_tex3

; ---------------------------------------------------------------------
;  pair loads: the schedule (SCHED block) has a group per coarse step
; ---------------------------------------------------------------------
group_ptr:			; HL = step -> load_ptr / load_left
	ld a,BLK_SCHED
	call blkport
	out (P_MEM),a
	add hl,hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,(de)
	ld (load_left),a
	inc de
	ld (load_ptr),de
	ret

load_one:			; next load of the group: slot, pair id
	ld a,BLK_SCHED
	call blkport
	out (P_MEM),a
	ld hl,(load_ptr)
	ld c,(hl)		; slot
	inc hl
	ld e,(hl)		; id lo
	inc hl
	ld d,(hl)		; id hi
	inc hl
	ld (load_ptr),hl
	ld hl,load_left
	dec (hl)
	ld a,c
	ld (ld_slot),a
	ld a,e			; block = BLK_PAIRS + id / 128
	rla
	ld a,d
	rla
	add a,BLK_PAIRS
	call blkport
	out (P_MEM),a
	ld a,e			; source = (id & 7Fh) * 256
	and $7F
	ld h,a
	ld l,0
	ld a,c			; destination F800h + slot * 16
	rrca
	rrca
	rrca
	rrca
	ld e,a
	and $0F
	or $F8
	ld d,a
	ld a,e
	and $F0
	ld e,a
	ld c,LV_SCREEN		; bank = phase
	ld b,CL
.k:	ld a,c
	out (P_LV),a
	push de
	push bc
	REPT 11
	ldi
	ENDR
	pop bc
	pop de
	inc c
	djnz .k
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,(ld_slot)		; HL = the 11 colours -> COLT + 256 k + slot
	ld e,a
	ld d,COLT>>8
	ld b,CL
.c:	ld a,(hl)
	ld (de),a
	inc hl
	inc d
	djnz .c
	ret

; ---------------------------------------------------------------------
cls:	ld a,LV_SCREEN		; codes 80h (black, bank 11)
	out (P_LV),a
	ld hl,$F000
	ld de,$F001
	ld bc,$7FF
	ld (hl),$80
	ldir
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,$F000
	ld de,$F001
	ld bc,$7FF
	ld (hl),STAR_BANK
	ldir
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,$F800
	ld de,$F801
	ld bc,$7FF
	ld (hl),0
	ldir
	xor a
	out (P_COLCTL),a
	; registers: start address 0
	ld a,12
	out (P_CRTCA),a
	xor a
	out (P_CRTCD),a
	ld a,13
	out (P_CRTCA),a
	xor a
	out (P_CRTCD),a
	ret

pcg_clear:			; all 16 banks
	ld c,0
.b:	ld a,c
	or LV_SCREEN
	out (P_LV),a
	ld hl,PCGWIN
	ld de,PCGWIN+1
	ld (hl),0
	push bc
	ld bc,$7FF
	ldir
	pop bc
	inc c
	ld a,c
	cp 16
	jr nz,.b
	ld a,LV_SCREEN
	out (P_LV),a
	ret

; HUD buffers from the texts
hud_build:
	ld hl,hud_t0
	ld de,HUDC
	ld b,80
.c:	ld a,(hl)
	sub 32
	push hl
	ld hl,font_map
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	pop hl
	ld (de),a
	inc hl
	inc de
	djnz .c
	ld hl,HUDK
	ld b,40
.k0:	ld (hl),YELLOW
	inc hl
	djnz .k0
	ld b,40
.k1:	ld (hl),BCYAN
	inc hl
	djnz .k1
	ld a,(speed)
	add a,$81		; digit codes: 81h + n
	ld (HUDC+33),a
	ld a,(fields)
	dec a
	ld hl,fps50
	jr z,.f
	ld hl,fps25
.f:	ld de,HUDC+35
	ld b,2
.fl:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	djnz .fl
	ld a,1
	ld (hudd),a
	ret
fps50:	db $86,$81
fps25:	db $83,$86
;            0123456789012345678901234567890123456789
hud_t0:	db "STARHIVE SOFT SCROLL TEST  SPEED 2 50FPS"
hud_t1:	db "VIBED BY BPM 2026     0-4 SPEED  F FPS  "
hud_attr:	ds 80,STAR_BANK

keys:	ld c,0
.k:	ld a,c
	add a,$20		; '0'.. = 20h..
	push bc
	call key1
	pop bc
	jr z,.n
	ld a,c
	ld (speed),a
	call hud_build
	jr .f
.n:	inc c
	ld a,c
	cp 5
	jr nz,.k
.f:	ld a,6			; F
	call key1
	ld hl,fkey
	jr z,.up
	ld a,(hl)
	or a
	ret nz
	ld (hl),1
	ld a,(fields)
	xor 3
	ld (fields),a
	jp hud_build
.up:	ld (hl),0
	ret

; wait for a rising edge of the 6545 vertical blanking status
vblank:	in a,(P_CRTCA)
	and $20
	jr nz,vblank
.w:	in a,(P_CRTCA)
	and $20
	jr z,.w
	ret

hw_init:
	ld a,$4F
	out (P_PIOAC),a
	ld a,$07
	out (P_PIOBC),a
	ld a,$CF
	out (P_PIOBC),a
	ld a,$BF
	out (P_PIOBC),a
	ld a,$07
	out (P_PIOBC),a
	xor a
	out (P_PIOB),a
	ld a,$CF
	out (P_PIOAC),a
	ld a,$FF
	out (P_PIOAC),a
	ld a,$07
	out (P_PIOAC),a
	xor a
	out (P_ROMLAT),a
	out (P_COLCTL),a
	ld a,LV_SCREEN
	out (P_LV),a
	ret

crtc_tab:	db $35,$28,$2C,$34, 27,R5FIX,DROWS,26, $48,CL-1,$20,CL-1, 0,0,0,0

	INCLUDE "input.asm"
	INCLUDE "../build/soft.inc"
code_end:
	ASSERT code_end <= SEGS

	ORG $E200
top	ds 2
scrS	ds 2
k	ds 1
s88	ds 1
acc	ds 1
step	ds 1
soff	ds 1
speed	ds 1
fields	ds 1
fkey	ds 1
hudd	ds 1
spsave	ds 2
bl_dst	ds 2
bl_base	ds 2
rc_win	ds 1
load_ptr ds 2
load_left ds 1
ld_slot ds 1
ps_page ds 1
ps_n ds 1
inp	ds 1
inpold	ds 1
inpedge	ds 1
joyraw	ds 1

	SAVEBIN "../build/SOFTSCRL.BIN",$8000,code_end-$8000
