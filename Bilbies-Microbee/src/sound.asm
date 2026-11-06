; =====================================================================
;  SOUND: the original's effects on the Microbee speaker (PIO B bit 6)
;
;  There is no timer to drive the speaker, so, as on the VZ, the busy
;  loops call the speaker service (SND n) with n = the time since the
;  previous call in units of 64 T-states (19 us). Each call site's n was
;  measured in the emulator (tools/sndcal.py). The service toggles the
;  speaker when a half period has run out (or, for noise, sets it from a
;  random bit). When no effect is playing the service is a single RET.
;
;  The effect scripts are the VZ's: one step per game update, each step
;  a tone, noise or silence at the VZ rate (f = rate * 6300 / 65536 Hz).
; =====================================================================
SFX_LETSGO	equ 1
SFX_ASSIGN	equ 2
SFX_CLICK	equ 3
SFX_DIG		equ 4
SFX_CLINK	equ 5
SFX_TINK	equ 6
SFX_SPLAT	equ 7
SFX_SPLASH	equ 8
SFX_HOME	equ 9
SFX_OHNO	equ 10
SFX_BOOM	equ 11

; (the SND macro is in hw.inc)

; A = units elapsed (keeps all registers but AF)
sndsvc:	ret			; patched: RET when quiet, NOP when an effect plays
	push hl
	ld l,a
	ld a,(snd_cnt)
	sub l
	jr c,.t
	jr z,.t
	ld (snd_cnt),a
	pop hl
	ret
.t:	neg			; overshoot
	ld l,a
	ld a,(snd_per)
	sub l
	jr z,.r
	jr nc,.k
.r:	ld a,(snd_per)		; (lost a whole period: start a new one)
.k:	ld (snd_cnt),a
	ld a,(snd_mode)
	or a
	ld a,(spkbit)
	jr z,.tog
	ld a,(snd_nz)		; noise: a new random level
	add a,a
	jr nc,.n1
	xor $1D
.n1:	ld (snd_nz),a
	and $40
	ld l,a
	ld a,(spkbit)
	and $BF
	or l
	jr .o
.tog:	xor $40
.o:	ld (spkbit),a
	out (P_PIOB),a
	pop hl
	ret

; ---- start an effect (higher or equal priority replaces)
sfx_play:
	push hl
	push de
	push bc
	ld c,a
	ld a,(v_demo)
	or a
	jr nz,.x
	ld a,(sfx_on)
	or a
	jr z,.x
	ld a,c
	dec a
	add a,a
	add a,a
	ld e,a
	ld d,0
	ld hl,SFXTAB
	add hl,de
	ld a,(sfx_pri)
	cp (hl)
	jr z,.ok
	jr nc,.x
.ok:	ld a,(hl)
	ld (sfx_pri),a
	inc hl
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (sfx_ptr),de
.x:	pop bc
	pop de
	pop hl
	ret

; ---- per game update (and every 4 fields in the menus): the next step
; script steps: mode (0 end, 1 tone, 2 noise, 3 silence), period (units)
sfx_tick:
	ld hl,(sfx_ptr)
	ld a,h
	or l
	jr z,sfx_off
	ld a,(hl)
	or a
	jr z,.end
	inc hl
	ld c,(hl)
	inc hl
	ld (sfx_ptr),hl
	cp 3
	jr z,.quiet
	dec a
	ld (snd_mode),a
	ld a,c
	ld (snd_per),a
	ld (snd_cnt),a
	xor a			; NOP: the service runs
	ld (sndsvc),a
	ret
.quiet:	ld a,$C9
	ld (sndsvc),a
	ret
.end:	ld hl,0
	ld (sfx_ptr),hl
sfx_off:
	xor a
	ld (sfx_pri),a
	ld a,$C9		; RET: silent
	ld (sndsvc),a
	ld a,(spkbit)
	and $BF
	ld (spkbit),a
	out (P_PIOB),a
	ret

; menus: one step every 4 fields
snd_menu:
	ld hl,snd_div
	inc (hl)
	ld a,(hl)
	and 3
	ret nz
	jp sfx_tick

; priority, -, script
SFXTAB:	db 6,0
	dw sx_letsgo
	db 3,0
	dw sx_assign
	db 2,0
	dw sx_click
	db 1,0
	dw sx_dig
	db 2,0
	dw sx_clink
	db 2,0
	dw sx_tink
	db 5,0
	dw sx_splat
	db 5,0
	dw sx_splash
	db 4,0
	dw sx_home
	db 5,0
	dw sx_ohno
	db 7,0
	dw sx_boom

; VZ rates to half periods (tone) or change periods (noise) in 64-T units
TN	MACRO r
	; high tones lose half periods between the service calls: ask for
	; shorter ones (measured in the model, tools/sndtest.py)
	IF r > 13000
	db 1, (274289 * 10 / 15 + r / 2) / r
	ELSE
	IF r > 10000
	db 1, (274289 * 10 / 12 + r / 2) / r
	ELSE
	IF r < 4000
	db 1, (274289 * 112 / 100 + r / 2) / r
	ELSE
	db 1, (274289 + r / 2) / r
	ENDIF
	ENDIF
	ENDIF
	ENDM
NZ	MACRO r
	db 2, (548578 + r / 2) / r
	ENDM
SL	MACRO
	db 3, 1
	ENDM
sx_letsgo:	TN 5200
	TN 5200
	SL
	TN 6900
	TN 6900
	SL
	TN 8700
	TN 9200
	TN 9800
	TN 10400
	db 0
sx_assign:	TN 12000
	TN 9000
	db 0
sx_click:	TN 14000
	db 0
sx_dig:	NZ 9000
	NZ 6000
	db 0
sx_clink:	TN 20000
	TN 19000
	SL
	TN 20000
	db 0
sx_tink:	TN 16000
	SL
	db 0
sx_splat:	NZ 30000
	NZ 20000
	NZ 12000
	NZ 7000
	NZ 4000
	db 0
sx_splash:	NZ 65535
	NZ 50000
	NZ 40000
	TN 3000
	TN 2600
	TN 2200
	TN 1900
	db 0
sx_home:	TN 7800
	TN 9800
	TN 11600
	TN 13800
	TN 15600
	db 0
sx_ohno:	TN 9000
	TN 9000
	TN 8400
	SL
	TN 6400
	TN 6200
	TN 6000
	TN 5800
	TN 5600
	db 0
sx_boom:	NZ 65535
	NZ 65535
	NZ 58000
	NZ 50000
	NZ 42000
	NZ 34000
	NZ 27000
	NZ 21000
	NZ 16000
	NZ 12000
	NZ 8000
	db 0
