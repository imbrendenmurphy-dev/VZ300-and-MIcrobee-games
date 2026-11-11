; =====================================================================
;  STARHIVE - SCROLL DIAGNOSTIC (40 x 24 mode, 8 x 11 cells)
;  The whole 2K screen is a numbered grid: every cell has a line along
;  its top and left edge, each row is numbered (left) and coloured.
;  Keys 1-8 choose a test; the test number shows at the top left.
;   1 STEADY      R5 = 5, nothing moves
;   2 SLOW R5     R5 steps 0..10, one step a second
;   3 FAST R5     R5 steps 0..10, one step every field (sawtooth)
;   4 COARSE      start address back one row a second
;   5 SMOOTH 50   full fine + coarse scroll, 1 line every field
;   6 SMOOTH 25   2 lines every second field
;   7 LATE WRITE  as 5, registers written in mid-picture
;   8 R5 THEN S   as 5, start address written a field after R5
;  VIBED BY BPM 2026
; =====================================================================
	DEVICE NOSLOT64K
	INCLUDE "hw.inc"

	ORG $8000
start:	di
	ld sp,$EFF0
	call hw_init
	MEMV BLK_WORK		; video RAM window on at F000h (the loader leaves it off)
	ld a,1
	in a,(P_CLK40)
	call crtc_tab_load
	; glyphs in PCG bank 0: 80h grid, 81h-8Ah grid + digit
	ld a,LV_SCREEN
	out (P_LV),a
	ld hl,PCGWIN
	ld bc,$0800
.cl:	ld (hl),0
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,.cl
	ld hl,PCGWIN		; 80h: top line + left pixel column
	ld (hl),$FF
	inc hl
	ld b,10
.g:	ld (hl),$80
	inc hl
	djnz .g
	ld de,PCGWIN+16		; 81h..8Ah: digits 0-9 on the grid
	ld hl,digits
	ld c,10
.d:	ld a,$FF
	ld (de),a
	inc de
	ld a,$80
	ld (de),a
	inc de
	ld b,7
.dl:	ld a,(hl)
	srl a
	or $80
	ld (de),a
	inc hl
	inc de
	djnz .dl
	ld a,$80
	ld (de),a
	inc de
	ld (de),a
	inc de
	ld a,e
	add a,16-11
	ld e,a
	jr nc,$+3
	inc d
	dec c
	jr nz,.d
	; fill the 2K ring: row number in columns 1-2, colours by row
	ld hl,0			; cell address
	ld de,0			; D = row, E = column
.f:	ld a,e
	cp 1
	jr z,.tens
	cp 2
	jr z,.units
	ld c,$80
	jr .put
.tens:	ld a,d
	call div10
	ld a,b
	add a,$81
	ld c,a
	jr .put
.units:	ld a,d
	call div10
	add a,$81
	ld c,a
.put:	push hl
	ld a,h
	or $F0
	ld h,a
	ld (hl),c		; screen
	ld a,LV_ATTR
	out (P_LV),a
	ld (hl),0		; PCG bank 0
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	set 3,h
	ld a,d
	and 7
	push hl
	ld hl,rowcols
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	pop hl
	ld (hl),a		; colour
	xor a
	out (P_COLCTL),a
	pop hl
	inc e
	ld a,e
	cp 40
	jr nz,.nr
	ld e,0
	inc d
.nr:	inc hl
	ld a,h
	cp 8
	jr nz,.f
	ld a,1
	ld (test),a
	call show_test
; ---------------------------------------------------------------------
main:	call vblank		; at the start of vertical blanking
	ld hl,(fields)
	inc hl
	ld (fields),hl
	call keys
	ld a,(test)
	dec a
	jr z,t1
	dec a
	jr z,t2
	dec a
	jp z,t3
	dec a
	jp z,t4
	dec a
	jp z,t5
	dec a
	jp z,t6
	dec a
	jp z,t7
	jp t8

t1:	ld a,5
	ld (k),a
	ld hl,0
	ld (sa),hl
	call write_regs
	jp main
t2:	call every50
	jr nz,.w
	call k_inc
.w:	call write_regs
	jp main
t3:	call k_inc
	call write_regs
	jp main
t4:	call every50
	jr nz,.w
	call s_back
.w:	call write_regs
	jp main
t5:	call k_step
	call write_regs
	jp main
t6:	ld a,(fields)
	and 1
	jr nz,.w
	call k_step
	call k_step
.w:	call write_regs
	jp main
t7:	call k_step
	ld bc,2200		; ~30000 T: the beam is mid-picture
.l:	dec bc
	ld a,b
	or c
	jr nz,.l
	call write_regs
	jp main
t8:	; R5 at once, the start address one field later
	ld a,(pend)
	or a
	jr z,.n
	xor a
	ld (pend),a
	ld hl,(sa2)
	ld (sa),hl
	call write_s
.n:	ld a,(k)
	inc a
	cp 11
	jr c,.k
	xor a
	ld hl,(sa2)
	ld de,-40
	add hl,de
	ld a,h
	and 7
	ld h,a
	ld (sa2),hl
	ld a,1
	ld (pend),a
	xor a
.k:	ld (k),a
	call write_r5
	jp main

; ---------------------------------------------------------------------
every50:			; Z once every 50 fields
	ld a,(cnt)
	inc a
	cp 50
	jr c,.s
	xor a
.s:	ld (cnt),a
	ret
k_inc:	ld a,(k)
	inc a
	cp 11
	jr c,.s
	xor a
.s:	ld (k),a
	ret
s_back:	ld hl,(sa)
	ld de,-40
	add hl,de
	ld a,h
	and 7
	ld h,a
	ld (sa),hl
	ret
k_step:	ld a,(k)		; one line on: k + 1, past 10 -> 0 and S - 40
	inc a
	cp 11
	jr c,.s
	call s_back
	xor a
.s:	ld (k),a
	ret
write_regs:
	call write_r5
write_s:
	ld hl,(sa)
	ld a,12
	out (P_CRTCA),a
	ld a,h
	out (P_CRTCD),a
	ld a,13
	out (P_CRTCA),a
	ld a,l
	out (P_CRTCD),a
	ret
write_r5:
	ld a,5
	out (P_CRTCA),a
	ld a,(k)
	out (P_CRTCD),a
	ret

; wait for a rising edge of the 6545 vertical blanking status
vblank:	in a,(P_CRTCA)
	and $20
	jr nz,vblank
.w:	in a,(P_CRTCA)
	and $20
	jr z,.w
	ret

keys:	ld c,1
.k:	ld a,c
	add a,$20		; '1'.. key codes 21h..
	push bc
	call key1
	pop bc
	jr z,.n
	ld a,c
	ld (test),a
	xor a
	ld (k),a
	ld (pend),a
	ld hl,0
	ld (sa),hl
	ld (sa2),hl
	jp show_test
.n:	inc c
	ld a,c
	cp 9
	jr nz,.k
	ret

; the test number in the top-left cell of every row (it scrolls too)
show_test:
	ld hl,$F000
	ld de,40
	ld b,52
	ld a,(test)
	add a,$81
.s:	ld (hl),a
	add hl,de
	ld c,a
	ld a,h
	and 7
	or $F0
	ld h,a
	ld a,c
	djnz .s
	ret

div10:	ld b,0			; A -> B = A / 10, A = A mod 10
.d:	cp 10
	ret c
	sub 10
	inc b
	jr .d

crtc_tab_load:
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
	ret
crtc_tab:	db $35,$28,$2C,$34, 27,0,DROWS,26, $48,CL-1,$20,CL-1, 0,0,0,0

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

	INCLUDE "input.asm"

rowcols: db WHITE,YELLOW,BCYAN,BGREEN,BMAGENTA,BRED,GREY,BBLUE
digits:	; 7 lines each, 0-9 (7 pixels wide, shifted right one)
	db $3C,$66,$6E,$76,$66,$66,$3C
	db $18,$38,$18,$18,$18,$18,$7E
	db $3C,$66,$06,$0C,$30,$60,$7E
	db $3C,$66,$06,$1C,$06,$66,$3C
	db $0C,$1C,$3C,$6C,$7E,$0C,$0C
	db $7E,$60,$7C,$06,$06,$66,$3C
	db $3C,$60,$7C,$66,$66,$66,$3C
	db $7E,$06,$0C,$18,$30,$30,$30
	db $3C,$66,$66,$3C,$66,$66,$3C
	db $3C,$66,$66,$3E,$06,$0C,$38
code_end:

	ORG $E000
test	ds 1
k	ds 1
cnt	ds 1
pend	ds 1
sa	ds 2
sa2	ds 2
fields	ds 2
inp	ds 1
inpold	ds 1
inpedge	ds 1
joyraw	ds 1

	SAVEBIN "../build/SCRLDIAG.BIN",$8000,code_end-$8000
