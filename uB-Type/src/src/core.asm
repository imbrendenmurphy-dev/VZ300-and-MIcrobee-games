; =====================================================================
;  CORE: hardware set-up, banking, frame timing, page flip, input,
;  sound effects (the VZ-TYPE effect engine, retimed for 3.375 MHz)
; =====================================================================

hw_init:
	MEMV BLK_WORK
	; PIO set-up as the earlier Premium conversions: B6 speaker out, A in
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
	ld (spkbit),a
	out (P_PIOB),a
	ld a,$CF
	out (P_PIOAC),a
	ld a,$FF
	out (P_PIOAC),a
	ld a,$07
	out (P_PIOAC),a
	xor a
	out (P_ROMLAT),a
	call crtc_game
	; colour RAM black, attributes 0, screen blank
	call cls_all
	ret

; 64 x 16 characters of 16 lines: the boot ROM's own 64-column table
; (6B 40 51 37 12 09 10 12 48 0F), cursor off
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
	ld e,0
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
	jr z,.done
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
.done:	MEMV BLK_WORK
	ret
cb_src	db 0
cb_dst	db 0

; ---------------------------------------------------------------------
;  frame timing: rising edges of the 6545 vertical blanking status
; ---------------------------------------------------------------------
; count an edge if one happened (keeps all registers but AF)
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
	ret
.lo:	ld (vblast),a
	ret

; wait until two fields have passed since the last frame (25 fps), playing
; the current sound effect. One pass of the loop is 180 T-states (53.3 us,
; one pass of the VZ original's idle loop), so the effect periods give the
; same pitches as on the VZ300.
waitframe:
.w:	call vschk		; 17+53
	ld a,(vcount)		; 13
	cp 2			; 7
	jr nc,.done		; 7
	ld a,(sfxon)		; 13
	or a			; 4
	jr z,.quiet		; 7 / 12
	ld hl,sfxcnt		; 10
	dec (hl)		; 11
	jr z,.tog		; 7
	inc hl			; 6   (pad)
	ld a,(sfxon)		; 13  (pad)
	jr .w			; 12  = 180
.tog:	call sfx_tog
	jr .w
.quiet:	inc hl			; 6
	ld b,2			; 7
	djnz $			; 21
	nop			; 4
	nop			; 4
	jr .w			; 12  = 180
.done:	xor a
	ld (vcount),a
	jp sfx_frame

; wait for one vertical blanking edge (front end)
vsync1:	xor a
	ld (vcount),a
.l:	call vschk
	ld a,(vcount)
	or a
	jr z,.l
	ret

; ---------------------------------------------------------------------
;  page flip: show the page rendered last (latched at the next frame)
; ---------------------------------------------------------------------
flip:	ld hl,(nextstart)
	ld (dispstart),hl
	ld a,12
	out (P_CRTCA),a
	ld a,h
	out (P_CRTCD),a
	ld a,13
	out (P_CRTCA),a
	ld a,l
	out (P_CRTCD),a
	ret

; ---------------------------------------------------------------------
;  SOUND EFFECTS (VZ-TYPE's engine). An effect is: priority, then
;  segments of (frames, period, delta/frame, flags) ending with 0.
;  flags: 1 = noise. The period counts idle-loop passes (53.3 us).
; ---------------------------------------------------------------------
; per-cell speaker service from the renderer: A = time units elapsed
sndsvc:	push hl
	ld l,a
	ld a,(sfxon)
	or a
	jr z,.x
	ld a,(sfxcnt)
	sub l
	jr z,.t
	jr c,.t
	ld (sfxcnt),a
.x:	pop hl
	ret
.t:	call sfx_tog
	pop hl
	ret
sfx_tog:	; toggle the speaker and reload the period counter (keeps BC,DE)
	ld a,(spkbit)
	xor $40
	ld (spkbit),a
	out (P_PIOB),a
	ld a,(sfxnz)
	or a
	ld a,(sfxper)
	jr z,.s
	ld hl,(rseed)
	add hl,hl
	jr nc,$+4
	ld a,l
	xor $2d
	ld l,a
	ld (rseed),hl
	ld a,(sfxper)
	and l
	or 1
.s:	ld (sfxcnt),a
	ret

sfx_frame:
	ld a,(sfxon)
	or a
	ret z
	ld a,(sfxdp)
	ld hl,sfxper
	add a,(hl)
	jr nz,$+4
	ld a,1
	ld b,a
	ld a,(sfxdp)
	bit 7,a
	ld a,b
	jr nz,.dn
	cp (hl)
	jr nc,.ok
	ld a,255
	jr .ok
.dn:	cp (hl)
	jr c,.ok
	jr z,.ok
	ld a,1
.ok:	ld (hl),a
	ld hl,sfxfr
	dec (hl)
	ret nz
	ld hl,(sfxptr)
	jr sfx_seg

sfx:	ld a,(sfxon)
	or a
	jr z,.go
	ld a,(sfxpri)
	cp (hl)
	jr z,.go
	ret nc
.go:	ld a,(hl)
	ld (sfxpri),a
	inc hl
sfx_seg:
	ld a,(hl)
	or a
	jr z,.end
	ld (sfxfr),a
	inc hl
	ld a,(hl)
	ld (sfxper),a
	ld (sfxcnt),a
	inc hl
	ld a,(hl)
	ld (sfxdp),a
	inc hl
	ld a,(hl)
	ld (sfxnz),a
	inc hl
	ld (sfxptr),hl
	ld a,1
	ld (sfxon),a
	ret
.end:	xor a
	ld (sfxon),a
	ret

sfx_charge:
	ld a,(sfxon)
	or a
	jr z,.go
	ld a,(sfxpri)
	cp 2
	ret nc
.go:	ld a,1
	ld (sfxpri),a
	ld (sfxfr),a
	ld (sfxon),a
	ld a,(charge)
	srl a
	cpl
	add a,44
	ld (sfxper),a
	xor a
	ld (sfxdp),a
	ld (sfxnz),a
	ld hl,sfx_null
	ld (sfxptr),hl
	ret
sfx_null	db 0

; ---- effects (VZ-TYPE originals): pri, {frames,period,delta,noise}..., 0
sfx_shot:	db 2,  1,5,0,1, 1,20,0,0, 1,36,0,0, 1,56,0,0, 0	; a pop: a click, then a falling thud
sfx_beam:	db 5,  2,6,-1,0, 3,4,2,0, 10,5,2,1, 0
sfx_beam1:	db 4,  2,10,-2,0, 6,8,3,1, 0
sfx_pop:	db 3,  2,5,0,0, 6,6,3,1, 0
sfx_hit:	db 2,  1,5,0,0, 1,30,0,1, 0
sfx_clank:	db 3,  1,4,0,0, 2,9,4,0, 2,8,0,1, 0
sfx_boom:	db 6,  3,8,4,1, 12,24,3,1, 0
sfx_bigboom:	db 8,  4,6,2,1, 10,18,3,1, 20,40,4,1, 0
sfx_die:	db 9,  4,8,-1,0, 4,10,6,0, 30,20,3,1, 0
sfx_power:	db 7,  3,28,0,0, 3,22,0,0, 3,18,0,0, 5,14,0,0, 0
sfx_life:	db 9,  3,20,0,0, 3,16,0,0, 3,13,0,0, 3,10,0,0, 3,13,0,0, 6,10,0,0, 0
sfx_pod:	db 4,  6,40,-5,0, 0
sfx_podback:	db 4,  6,12,5,0, 0
sfx_caps:	db 5,  2,12,0,0, 2,9,0,0, 2,12,0,0, 2,9,0,0, 0
sfx_open:	db 2,  4,30,-4,0, 0
sfx_expose:	db 8,  4,30,-3,0, 4,40,-3,0, 6,50,-4,0, 0
sfx_ebul:	db 1,  2,20,6,0, 0
sfx_warn:	db 7,  6,20,0,0, 6,28,0,0, 6,20,0,0, 6,28,0,0, 6,20,0,0, 6,28,0,0, 0
sfx_clear:	db 9,  4,24,0,0, 4,20,0,0, 4,16,0,0, 4,12,0,0, 10,10,0,0, 0

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
K_Z	equ 26
K_ESC	equ $30
K_RET	equ $34
K_SPACE	equ $37
K_UP	equ $38
K_DOWN	equ $3A
K_LEFT	equ $3B
K_RIGHT	equ $3E

; inp: b0 up, b1 down, b2 left, b3 right, b4 fire, b5 pod (as VZ-TYPE)
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
	ld a,(demomode)
	or a
	call nz,demo_input	; attract mode: scripted input in C
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

; ---------------------------------------------------------------------
;  utilities (VZ-TYPE)
; ---------------------------------------------------------------------
jphl:	jp (hl)

rnd:	push hl
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

; ---- LZB unpack: HL = packed source, DE = destination (see vz/lzb.py)
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
lzb_tab	dw 0
lzb_n	dw 0
lzb_len	db 0
lzb_hi	db 0
