; =====================================================================
;  CORE: hardware set-up, banking, frame timing, page flip, keyboard,
;  joystick, the mouse (interrupt driven), random numbers, unpacking
; =====================================================================

hw_init:
	di
	; variables: all zero, then the defaults (only code is in the file)
	ld hl,vars_start
	ld de,vars_start+1
	ld bc,tables_end-vars_start-1
	ld (hl),0
	ldir
	ld hl,gvars_start
	ld de,gvars_start+1
	ld bc,gtab_end-gvars_start-1
	ld (hl),0
	ldir
	ld hl,mouse_isr
	ld (IMTAB),hl
	ld hl,$3A71
	ld (rseed),hl
	ld (v_seed),hl		; the original's seed, set once at power-up
	ld a,$5B
	ld (snd_nz),a
	ld a,1
	ld (sfx_on),a		; (the saved settings may turn it off)
	ld a,1
	ld (rpage),a
	ld a,255
	ld (pscroll),a
	ld (pscroll+1),a
	ld a,YELLOW
	ld (sprink),a
	MEMV BLK_WORLD
	; PIO A: input (joystick), no interrupts
	ld a,$CF
	out (P_PIOAC),a
	ld a,$FF
	out (P_PIOAC),a
	ld a,$07
	out (P_PIOAC),a
	; PIO B: bit control; inputs b0-b5 and b7, b6 speaker out;
	; interrupts on b2 (the mouse's bit clock) going high
	ld a,IMTAB&$FF
	out (P_PIOBC),a		; vector
	ld a,$CF
	out (P_PIOBC),a
	ld a,$BF
	out (P_PIOBC),a		; direction: all in except b6
	ld a,$B7		; int enable, OR, active high, mask follows
	out (P_PIOBC),a
	ld a,$FB		; monitor b2 only
	out (P_PIOBC),a
	xor a
	ld (spkbit),a
	out (P_PIOB),a
	xor a
	out (P_ROMLAT),a
	; interrupts: IM 2 through IMTAB
	ld a,IMTAB>>8
	ld i,a
	im 2
	call crtc_game
	call cls_all
	ei
	ret

; 64 x 16 characters of 16 lines (the boot ROM's 64-column table)
crtc_game:
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
crtc_tab:	db $6B,$40,$51,$37,$12,$09,$10,$12,$48,$0F,$20,$0F,$00,$00,$00,$00

; screen blank, colours black, attributes 0 (both pages)
cls_all:
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,COLWIN
	ld bc,$0800
	ld e,0
	call fill
	xor a
	out (P_COLCTL),a
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,VIDEO
	ld bc,$0800
	ld e,BK_HUD
	call fill
	ld a,LV_SCREEN
	out (P_LV),a
	ld hl,VIDEO
	ld bc,$0800
	ld e,BLANK_CODE
	jp fill

; HL = start, BC = count, E = value
fill:	ld (hl),e
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,fill
	ret

; A = block -> A = port 50h value (ROMs off, video window at F000)
bank_port:
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
; map block A into the lower window
map_blk:
	call bank_port
	out (P_MEM),a
	ret

; copy BC bytes from block A offset HL to block (cb_dst) offset DE,
; through a 256-byte bounce buffer in the upper block
blk_copy:
	ld (cb_src),a
.ch:	ld a,b
	or c
	ret z
	push bc
	ld a,b
	or a
	jr z,.small
	ld bc,256
.small:	push bc
	ld a,(cb_src)
	call map_blk
	push de
	ld de,BOUNCE
	push bc
	ldir
	pop bc
	pop de
	push hl
	ld a,(cb_dst)
	call map_blk
	ld hl,BOUNCE
	ldir
	pop hl
	pop bc			; this chunk
	ex (sp),hl		; HL = remaining
	or a
	sbc hl,bc
	ld b,h
	ld c,l
	pop hl
	jr .ch

; ---------------------------------------------------------------------
;  frame timing: rising edges of the 6545 vertical blanking status
; ---------------------------------------------------------------------
vschk:	in a,(P_CRTCA)
	and $20
	jr z,.lo
	ld a,(vblast)
	or a
	ret nz
	ld a,$20
	ld (vblast),a
	ld a,(vcount)
	inc a
	ld (vcount),a
	ld a,(fields)
	inc a
	ld (fields),a
	ret
.lo:	ld (vblast),a
	ret

; wait until at least A fields have passed since the last frame
waitfields:
	ld b,a
.w:	push bc
	ld a,(mus_on)
	or a
	jr z,.nm
	call mus_wait
	jr .wm
.nm:	call vschk
.snd9:	SND 5
.wm:	pop bc
	ld a,(vcount)
	cp b
	jr c,.w
	sub b			; keep any extra field (at most one) for the next frame
	cp 2
	jr c,.k
	ld a,1
.k:	ld (vcount),a
	ret

; wait for one vertical blanking edge
vsync1:	xor a
	ld (vcount),a
.l:	ld a,(mus_on)
	or a
	jr z,.nm
	call mus_wait
	jr .m
.nm:	call vschk
.snd10:	SND 2
.m:	ld a,(vcount)
	or a
	jr z,.l
	jp snd_menu

; show page A (0/1) from the next field on
show_page:
	ld (dpage),a
	add a,a
	add a,a			; start address high byte: 0 or 4
	ld b,a
	ld a,12
	out (P_CRTCA),a
	ld a,b
	out (P_CRTCD),a
	ld a,13
	out (P_CRTCA),a
	xor a
	out (P_CRTCD),a
	ret

; ---------------------------------------------------------------------
;  keyboard (6545 light-pen scan, as the boot ROM does) and joystick
; ---------------------------------------------------------------------
; A = Microbee key code -> NZ if held (latch must be set: kb_on)
keytest:
	push bc
	ld b,a
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
	ld a,$10
	out (P_CRTCA),a
	in a,(P_CRTCD)		; clear any pending light pen strobe
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

kb_on:	ld a,1
	out (P_ROMLAT),a
	ret
kb_off:	xor a
	out (P_ROMLAT),a
	ret

; single key: A = code -> NZ if held
key1:	push af
	call kb_on
	pop af
	call keytest
	push af
	call kb_off
	pop af
	ret

; key codes
K_A	equ 1
K_B	equ 2
K_C	equ 3
K_D	equ 4
K_E	equ 5
K_F	equ 6
K_G	equ 7
K_H	equ 8
K_I	equ 9
K_J	equ 10
K_K	equ 11
K_L	equ 12
K_M	equ 13
K_N	equ 14
K_O	equ 15
K_P	equ 16
K_Q	equ 17
K_R	equ 18
K_S	equ 19
K_T	equ 20
K_U	equ 21
K_V	equ 22
K_W	equ 23
K_X	equ 24
K_Y	equ 25
K_Z	equ 26
K_0	equ $20
K_1	equ $21
K_COMMA	equ $2C
K_MINUS	equ $2D
K_DOT	equ $2E
K_ESC	equ $30
K_TAB	equ $32
K_RET	equ $34
K_SPACE	equ $37
K_UP	equ $38
K_CTRL	equ $39
K_DOWN	equ $3A
K_LEFT	equ $3B
K_RIGHT	equ $3E
K_SHIFT	equ $3F

; joystick on PIO A (active low): b0 up b1 down b2 left b3 right b7 fire
; -> A = b0 up b1 down b2 left b3 right b4 fire (active high)
read_joy:
	in a,(P_PIOA)
	or a
	jr nz,.j1
	dec a			; reads 00: no joystick fitted
.j1:	cpl
	ld b,a
	and $0F
	bit 7,b
	ret z
	or $10
	ret

; ---------------------------------------------------------------------
;  the Microbee mouse: a Microsoft serial mouse through the interface on
;  the RS232 port. PIO B b2 is a clock: one interrupt per serial bit;
;  b3 is the bit, inverted. 1 start + 7 data + 1 stop bits a byte, three
;  bytes a packet (b6 set in the first). The ISR collects the bits and
;  adds the movement into ms_dx / ms_dy; buttons in ms_btn.
; ---------------------------------------------------------------------
mouse_isr:
	push af
	push hl
	in a,(P_PIOB)
	and $08			; CTS: 1 = a 0 bit (inverted)
	ld hl,ms_nbit
	ld a,(hl)
	or a
	jr nz,.data
	; expecting a start bit (a 0, read back as CTS set)
	in a,(P_PIOB)
	and $08
	jp z,.out		; not a start bit: stay in sync hunt
	inc (hl)
	jp .out
.data:	cp 8
	jr z,.stop
	inc (hl)
	in a,(P_PIOB)
	and $08
	sub 1			; C set if CTS was 0, i.e. a 1 bit
	ld a,(ms_cur)
	rra			; shift the bit in from the top (LSB first)
	ld (ms_cur),a
	jp .out
.stop:	ld (hl),0		; stop bit: byte complete
	in a,(P_PIOB)
	and $08
	jr nz,.bad		; a stop bit must read back as CTS clear
	ld a,(ms_cur)
	rra			; 7 bits arrived into b7..b1: move to b6..b0
	and $7F
	ld l,a
	bit 6,a
	jr z,.nb1
	; first byte of a packet
	ld (ms_b1),a
	ld a,1
	ld (ms_bytes),a
	jp .out
.nb1:	ld a,(ms_bytes)
	or a
	jp z,.out		; not in a packet
	cp 1
	jr nz,.b3
	ld a,l
	ld (ms_b2),a
	ld a,2
	ld (ms_bytes),a
	jp .out
.b3:	xor a
	ld (ms_bytes),a
	; packet complete: b1 = 1 L R Y7 Y6 X7 X6, b2 = X5-0, b3 = Y5-0
	push bc
	ld a,(ms_b1)
	rrca
	rrca
	and $C0
	ld c,a
	ld a,(ms_b2)
	and $3F
	or c			; dx
	ld c,a
	ld a,(ms_dx)
	add a,c
	jp pe,.ovx
	ld (ms_dx),a
.ovx:	ld a,(ms_b1)
	rlca
	rlca
	rlca
	rlca
	and $C0
	ld c,a
	ld a,l
	and $3F
	or c			; dy
	ld c,a
	ld a,(ms_dy)
	add a,c
	jp pe,.ovy
	ld (ms_dy),a
.ovy:	ld a,(ms_b1)
	rrca
	rrca
	rrca
	rrca
	and 3			; b1 = left, b0 = right
	ld (ms_btn),a
	ld a,1
	ld (ms_seen),a
	pop bc
	jp .out
.bad:	xor a
	ld (ms_bytes),a
.out:	pop hl
	pop af
	ei
	reti

; ---------------------------------------------------------------------
;  utilities
; ---------------------------------------------------------------------
jphl:	jp (hl)

; A = random byte
rand:	push hl
	ld hl,(rseed)
	add hl,hl
	jr nc,.n
	ld a,l
	xor $2d
	ld l,a
.n:	ld (rseed),hl
	ld a,l
	add a,h
	pop hl
	ret

; ---- LZB unpack: HL = packed source, DE = destination (tools/lzb.py)
unlzb:	ld (lzb_tab),hl
	ld bc,16
	add hl,bc
	ld a,(hl)
	ld (lzb_n),a
	inc hl
	ld a,(hl)
	ld (lzb_n+1),a
	inc hl
	ld c,$80
.loop:	push hl
	ld hl,(lzb_n)
	ld a,h
	or l
	pop hl
	ret z
	call gbit
	jr c,.match
	call gbit
	jr c,.lit8
	ld b,4
	call gbits
	push hl
	ld hl,(lzb_tab)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	pop hl
	jr .put
.lit8:	ld b,8
	call gbits
.put:	ld (de),a
	inc de
	push hl
	ld hl,(lzb_n)
	dec hl
	ld (lzb_n),hl
	pop hl
	jr .loop
.match:	ld b,1
.gz:	call gbit
	jr c,.g1
	inc b
	jr .gz
.g1:	ld a,1
	dec b
	jr z,.gd
.gl:	call gbit
	rla
	djnz .gl
.gd:	inc a
	ld (lzb_len),a
	call gbit
	jr c,.o12
	ld b,7
	call gbits
	ld b,0
	jr .od
.o12:	ld b,4
	call gbits
	ld (lzb_hi),a
	ld b,8
	call gbits
	push af
	ld a,(lzb_hi)
	ld b,a
	pop af
.od:	push hl
	push bc
	ld c,a
	ld a,e
	sub c
	ld l,a
	ld a,d
	sbc a,b
	ld h,a
	dec hl
	pop bc
	push bc
	ld a,(lzb_len)
	ld c,a
	ld b,0
	ldir
	pop bc
	ld hl,(lzb_n)
	ld a,(lzb_len)
	push de
	ld e,a
	ld d,0
	or a
	sbc hl,de
	ld (lzb_n),hl
	pop de
	pop hl
	jp .loop
gbits:	xor a
.l:	call gbit
	rla
	djnz .l
	ret
gbit:	sla c
	ret nz
	ld c,(hl)
	inc hl
	scf
	rl c
	ret
