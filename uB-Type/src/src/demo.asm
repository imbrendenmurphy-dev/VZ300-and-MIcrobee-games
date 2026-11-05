; =====================================================================
;  FRONT-END HOOKS AND THE ATTRACT-MODE PILOT (resident code)
;
;  The front end (title, info pages, stage intro, game over, name
;  entry, music) is an overlay kept in memory block 1. It runs in the
;  upper block on top of the game's level buffers, so it is copied in
;  every time it is entered. These stubs do that.
; =====================================================================
FE_BOOT	equ FEBASE
FE_TITLE equ FEBASE+3
FE_HOF	equ FEBASE+6
FE_INTRO equ FEBASE+9
FE_CONGR equ FEBASE+12
FE_OVER	equ FEBASE+15

fe_load:
	push af
	push bc
	push de
	push hl
	MEMV BLK_FRONT
	ld hl,0
	ld de,FEBASE
	ld bc,FE_SIZE
	ldir
	MEMV BLK_WORK
	pop hl
	pop de
	pop bc
	pop af
	ret

fe_boot:
	call fe_load
	jp FE_BOOT
title:
fe_quit:
	xor a
	ld (demomode),a
	ld sp,STACKTOP
	call fe_load
	jp FE_TITLE
fe_game_over:
	ld sp,STACKTOP
	call fe_load
	jp FE_OVER
fe_stage_intro:
	ld a,(demomode)
	or a
	ret nz
	call fe_load
	jp FE_INTRO		; (returns to level_start)
fe_congrats:
	ld a,(demomode)
	or a
	ret nz
	call fe_load
	jp FE_CONGR

; ---------------------------------------------------------------------
;  attract mode: the real game on a stage of its own, flown by the pilot
;  below; the ship can't be destroyed. Ends after a while or on a key.
; ---------------------------------------------------------------------
DEMO_FRAMES equ 650		; game frames (25 a second)

; start the demo (called from the title overlay): A = stage
demo_start:
	ld (lvlnum),a
	ld a,1
	ld (demomode),a
	ld hl,DEMO_FRAMES
	ld (demotm),hl
	xor a
	ld (dm_t),a
	ld sp,STACKTOP
	MEMV BLK_WORK
	jp new_game_at

demo_check:
	ld hl,(demotm)
	dec hl
	ld (demotm),hl
	ld a,h
	or l
	jr z,.end
	; keys (the pilot overrides the game's input, so look directly)
	ld a,K_SPACE
	call key1
	jr nz,.end
	ld a,(joyraw)
	bit 7,a			; joystick fire (joyraw is active high)
	jr nz,.end
	jp mainloop
.end:	xor a
	ld (demomode),a
	ld (sfxon),a
	ld (spkbit),a
	out (P_PIOB),a
	jp title

; the pilot: returns C = input bits (1 up, 2 down, 4 left, 8 right,
; 10h fire, 20h pod)
demo_input:
	ld hl,dm_t
	inc (hl)
	ld a,(hl)
	; ---- trigger: taps, then every 128 frames a long hold for the beam
	ld c,0
	and 127
	cp 90
	jr nc,.hold
	ld a,(hl)
	and 2
	jr z,.fdone
	ld c,$10
	jr .fdone
.hold:	cp 126
	jr nc,.fdone		; release: the beam fires
	ld c,$10
.fdone:	ld a,(hl)
	or a
	jr nz,.nopod
	set 5,c			; now and then: launch / recall the pod
.nopod:	; ---- where to go: a capsule if there is one, else the nearest
	; enemy ahead, else stay put
	ld a,(py)
	sub 16
	ld (dm_ty),a
	ld a,32+30
	ld (dm_tx),a
	ld ix,ENTS
	ld b,NENT
	ld e,255		; best distance
.en:	ld a,(ix+E_TYPE)
	or a
	jr z,.enx
	cp T_CAPS
	jr nz,.notcap
	ld a,(ix+E_Y)
	sub 16
	ld (dm_ty),a
	ld a,(ix+E_X)
	cp 32+8
	jr nc,$+4
	ld a,32+8
	cp 32+100
	jr c,$+4
	ld a,32+100
	ld (dm_tx),a
	ld e,0			; nothing beats a capsule
	jr .enx
.notcap:
	cp T_BOSS
	jr z,.enx
	ld a,(px)
	ld d,a
	ld a,(ix+E_X)
	sub d
	jr c,.enx		; behind us
	cp e
	jr nc,.enx
	ld e,a
	ld a,(ix+E_Y)
	sub 16
	ld (dm_ty),a
.enx:	ld a,e
	or a
	jr z,.tgt
	push de
	ld de,ENTSZ
	add ix,de
	pop de
	djnz .en
.tgt:	; ---- terrain: rows blocked in the next few columns ahead
	ld hl,(scrollx)
	ld a,(px)
	sub 32+2		; screen x of the tail
	jr nc,$+3
	xor a
	ld e,a
	ld d,0
	add hl,de
	srl h
	rr l
	srl h
	rr l			; first column
	ld a,l
	ld (dm_c),a
	ld hl,0			; mask of blocked rows
	ld b,9
.col:	push bc
	ld a,(dm_c)
	and 63
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld bc,TRING
	add hl,bc
	ex de,hl		; DE -> column
	ld bc,1			; bit for row 0
	ld a,14
.row:	push af
	ld a,(de)
	or a
	jr z,.free
	cp 48
	jr nc,.free
	ld a,l
	or c
	ld l,a
	ld a,h
	or b
	ld h,a
.free:	inc de
	sla c
	rl b
	pop af
	dec a
	jr nz,.row
	ld a,(dm_c)
	inc a
	ld (dm_c),a
	pop bc
	djnz .col
	ld (dm_mask),hl
	; ---- choose the free gap closest to the wanted height: three rows
	; clear if possible, else two
	ld a,(dm_ty)
	srl a
	srl a
	ld (dm_want),a		; wanted row
	ld a,7
	call dm_gap
	jr nc,.found
	ld a,3
	call dm_gap
	jr c,.steer_x		; nowhere free: hold height
.found:
	ld a,(dm_br)
	add a,a
	add a,a
	add a,16+2		; target py
	ld e,a
	ld a,(py)
	sub e
	jr z,.steer_x
	jr c,.down
	cp 2
	jr c,.steer_x
	set 0,c
	jr .steer_x
.down:	cp -1
	jr z,.steer_x
	set 1,c
.steer_x:
	ld a,(dm_tx)
	ld e,a
	ld a,(px)
	sub e
	ret z
	jr c,.right
	cp 3
	ret c
	set 2,c
	ret
.right:	cp -2
	ret nc
	set 3,c
	ret

; A = run of rows that must be free (bits) -> dm_br = best row, NC if any
dm_gap:	ld (.m+1),a
	ld a,255
	ld (dm_bd),a
	ld hl,(dm_mask)
	ld b,0			; row
.g:	ld a,l
.m:	and 7
	jr nz,.n		; blocked
	ld a,(dm_want)
	sub b
	jr nc,$+4
	neg
	ld e,a
	ld a,(dm_bd)
	cp e
	jr c,.n
	jr z,.n
	ld a,e
	ld (dm_bd),a
	ld a,b
	ld (dm_br),a
.n:	srl h
	rr l
	inc b
	ld a,b
	cp 13
	jr c,.g
	ld a,(dm_bd)
	cp 255			; carry unless something was found
	ccf
	ret

demotm	dw 0
dm_t	db 0
dm_tx	db 0
dm_ty	db 0
dm_c	db 0
dm_mask	dw 0
dm_want	db 0
dm_bd	db 0
dm_br	db 0
demostage db 0
protostage db $FF		; test harness: stage to start in (FFh = normal)
mono	db 0			; monochrome monitor (chosen at start-up)
dbgcol	dw 0			; test harness: start column (0 in play)
