; =====================================================================
;  INPUT: keyboard (6545 light-pen scan, as the boot ROM does) and the
;  joystick on PIO A. From uB-TYPE.
; =====================================================================
; ---------------------------------------------------------------------
;  keyboard (6545 light-pen scan, as the boot ROM does) and joystick
; ---------------------------------------------------------------------
; A = Microbee key code -> NZ if held
keytest:
	push bc
	ld b,a
	ld a,$10
	out (P_CRTCA),a
	in a,(P_CRTCD)
	ld a,$11
	out (P_CRTCA),a
	in a,(P_CRTCD)
	ld a,$12
	out (P_CRTCA),a
	ld a,b
	rrca
	rrca
	rrca
	rrca
	and $03
	out (P_CRTCD),a
	ld a,$13
	out (P_CRTCA),a
	ld a,b
	rlca
	rlca
	rlca
	rlca
	and $F0
	out (P_CRTCD),a
	ld a,$1F
	out (P_CRTCA),a
	out (P_CRTCD),a
	nop
	ld b,0
.w:	in a,(P_CRTCA)
	bit 7,a
	jr nz,.d
	djnz .w
.d:	and $40
	pop bc
	ret

; key codes
K_A	equ 1
K_C	equ 3
K_H	equ 8
K_M	equ 13
K_O	equ 15
K_P	equ 16
K_Q	equ 17
K_T	equ 20
K_X	equ 24
K_W	equ 23
K_Z	equ 26
K_ESC	equ $30
K_RET	equ $34
K_SPACE	equ $37
K_UP	equ $38
K_DOWN	equ $3A
K_LEFT	equ $3B
K_RIGHT	equ $3E

; inp: b0 up, b1 down, b2 left, b3 right, b4 fire, b5 smoke bomb
readinp:
	ld a,1
	out (P_ROMLAT),a
	ld hl,keymap
	ld c,0
.k:	ld a,(hl)
	cp $FF
	jr z,.joy
	inc hl
	call keytest
	ld a,(hl)
	inc hl
	jr z,.k
	or c
	ld c,a
	jr .k
.joy:	xor a
	out (P_ROMLAT),a
	in a,(P_PIOA)
	or a
	jr nz,.j1
	dec a			; reads 00: no joystick fitted
.j1:	cpl
	ld b,a
	and $0F
	or c
	ld c,a
	bit 7,b
	jr z,.nf
	set 4,c
.nf:	ld a,b
	ld (joyraw),a
	ld a,(inp)
	ld (inpold),a
	cpl
	and c
	ld (inpedge),a
	ld a,c
	ld (inp),a
	ret
keymap:	db K_Q,$01, K_A,$02, K_O,$04, K_P,$08
	db K_UP,$01, K_DOWN,$02, K_LEFT,$04, K_RIGHT,$08
	db K_SPACE,$10, K_M,$20, K_Z,$20
	db $FF

; single key with the keyboard latch set: A = code -> NZ if held
key1:	push af
	ld a,1
	out (P_ROMLAT),a
	pop af
	call keytest
	push af
	xor a
	out (P_ROMLAT),a
	pop af
	ret

anykey:	; NZ if any of the game keys / fire is held
	call readinp
	ld a,(inp)
	or a
	ret
