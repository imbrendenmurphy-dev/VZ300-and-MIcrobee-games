; =====================================================================
;  STARHIVE - the game: player, waves, enemies, bullets, collisions,
;  the Hive Queen, title / game over / level clear, sound effects.
;  Positions are x + 16 (16-bit pixels) and y + 16 (playfield lines).
;  VIBED BY BPM 2026
; =====================================================================

ST_TITLE equ 0
ST_PLAY	equ 1
ST_OVER	equ 2
ST_CLEAR equ 3

NENEMY	equ 12			; enemy slots, ESIZE bytes each
ESIZE	equ 16
E_TYPE	equ 0
E_XL	equ 1
E_XH	equ 2
E_Y	equ 3
E_YF	equ 4			; y fraction (1/256 line)
E_VYL	equ 5			; y speed, 8.8 lines a frame
E_VYH	equ 6
E_T	equ 7			; timer / phase
E_HP	equ 8
E_BXL	equ 9			; base x (sweeps)
E_BXH	equ 10
E_FIRE	equ 11
E_FLASH	equ 12
E_AMP	equ 13

T_DRONE	equ 1
T_DART	equ 2
T_POD	equ 3
T_EXPL	equ 4
T_QUEEN	equ 5

NBUL	equ 8			; enemy bullets: active, x*4 (2), y*4 (2), vx, vy
BSIZE	equ 8
NSHOT	equ 6			; player shots: y (0 = none), x (2)

PFH2	equ VROWS*CL		; playfield height (242 lines)
TX_SPARE equ $E1F8		; a spare byte (and E9F8) for unpassed cells
BOSS_ROW equ NROWS-26		; the scroll stops here for the Queen

; ---------------------------------------------------------------------
;  a new game from the title
; ---------------------------------------------------------------------
game_new:
	xor a
	ld hl,score
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	ld a,3
	ld (lives),a
	ld a,1
	ld (level),a
	ld a,ST_PLAY
	ld (state),a
	jp restart

; set up the state after the screen is rebuilt (restart calls this)
state_init:
	ld hl,objects		; no enemies, bullets, shots
	ld de,objects+1
	ld bc,objects_end-objects-1
	ld (hl),0
	ldir
	ld hl,wave_script
	ld (wave_ptr),hl
	ld hl,152+16
	ld (px),hl
	ld a,200+16
	ld (py),a
	xor a
	ld (dead),a
	ld (boss),a
	ld (stimer),a
	ld a,75
	ld (inv),a
	ld a,(state)
	cp ST_TITLE
	jr z,.title
	ld a,2
	ld (speed),a
	ld a,7
	ld hl,t_ready
	ld c,15
	ld e,YELLOW
	call text_at
	jp hud_build
.title:	xor a
	ld (speed),a
	ld hl,title_texts
.tt:	ld a,(hl)
	or a
	jp z,hud_build
	inc hl
	ld c,(hl)
	inc hl
	ld e,(hl)
	inc hl
	push hl
	call text_at
	pop hl
.sk:	ld a,(hl)
	inc hl
	or a
	jr nz,.sk
	jr .tt

; ---------------------------------------------------------------------
;  one frame of game logic (after the scroll has advanced)
; ---------------------------------------------------------------------
game_tick:
	ld hl,frame
	inc (hl)
	call readinp
	ld a,(state)
	cp ST_TITLE
	jp z,title_tick
	cp ST_PLAY
	jr z,.play
	; game over / level clear: everything carries on, then a timer
	call enemies_move
	call bullets_move
	call shots_move
	ld hl,stimer
	dec (hl)
	ret nz
	ld a,(state)
	cp ST_OVER
	jr nz,.next
	ld a,ST_TITLE
	ld (state),a
	jp restart
.next:	ld hl,level		; the next round: harder
	inc (hl)
	ld a,ST_PLAY
	ld (state),a
	jp restart
.play:	call waves
	call player_move
	call enemies_move
	call bullets_move
	call shots_move
	call vschk
	call collide
	ret

title_tick:
	ld a,(inpedge)
	and $10
	jp nz,game_new
	ld a,(frame)		; drones fly past now and then
	and 127
	ret nz
	call rnd
	and 31
	add a,4
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld b,5
.s:	push bc
	push hl
	ld a,T_DRONE
	call spawn
	pop hl
	pop bc
	djnz .s
	ret

; ---------------------------------------------------------------------
;  the wave script: dw map row; db type, column, count, gap (frames),
;  amplitude / step. Row FFFFh ends it.
; ---------------------------------------------------------------------
waves:	ld hl,(top)
	ld de,BOSS_ROW
	or a
	sbc hl,de
	jr c,.sp
	ld a,(boss)		; the Queen
	or a
	jr nz,.sp
	inc a
	ld (boss),a
	xor a
	ld (speed),a
	ld hl,160+16-20
	ld a,T_QUEEN
	call spawn
	call hud_build
.sp:	ld a,(sp_count)		; a group in progress
	or a
	jr z,.next
	ld hl,sp_wait
	dec (hl)
	jr nz,.next
	ld a,(sp_gap)
	ld (hl),a
	ld hl,sp_count
	dec (hl)
	ld a,(sp_type)
	cp T_DART
	jr nz,.fx
	call rnd		; darts: anywhere along the top
	and 31
	add a,4
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	jr .go
.fx:	ld hl,(sp_x)
.go:	ld a,(sp_amp)
	ld (sp_amp_now),a
	ld a,(sp_type)
	call spawn
.next:	ld hl,(wave_ptr)
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,d
	and e
	inc a
	ret z			; end of the script
	push hl
	ld hl,(top)
	or a
	sbc hl,de
	pop hl
	ret c			; not there yet
	ld a,(sp_count)
	or a
	ret nz			; (one group at a time)
	ld a,(hl)
	ld (sp_type),a
	inc hl
	ld a,(hl)		; column -> x + 16
	inc hl
	push hl
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,16
	add hl,de
	ld (sp_x),hl
	pop hl
	ld a,(hl)
	ld (sp_count),a
	inc hl
	ld a,(hl)
	ld (sp_gap),a
	inc hl
	ld a,(hl)
	ld (sp_amp),a
	inc hl
	ld (wave_ptr),hl
	ld a,1
	ld (sp_wait),a
	ret

; A = type, HL = x + 16: a new enemy at the top. IY = it (carry), or
; no free slot (no carry). IX is kept.
spawn:	ld iy,enemies
	ld de,ESIZE
	ld b,NENEMY
	ld c,a
.f:	ld a,(iy+E_TYPE)
	or a
	jr z,.got
	add iy,de
	djnz .f
	or a
	ret
.got:	push hl
	push iy
	pop hl
	ld d,h
	ld e,l
	inc de
	ld (hl),0
	ld b,0
	push bc
	ld bc,ESIZE-1
	ldir
	pop bc
	pop hl
	ld (iy+E_TYPE),c
	ld (iy+E_XL),l
	ld (iy+E_XH),h
	ld (iy+E_BXL),l
	ld (iy+E_BXH),h
	ld (iy+E_Y),4
	call rnd
	and 63
	add a,30
	ld (iy+E_FIRE),a
	ld a,(iy+E_TYPE)
	cp T_DRONE
	jr nz,.n1
	ld (iy+E_VYL),$80	; 1.5 lines a frame
	ld (iy+E_VYH),1
	ld (iy+E_HP),1
	ld a,(sp_amp_now)
	or a
	jr nz,.a
	ld a,40
.a:	ld (iy+E_AMP),a
	scf
	ret
.n1:	cp T_DART
	jr nz,.n2
	ld (iy+E_VYH),1
	ld (iy+E_HP),1
	scf
	ret
.n2:	cp T_POD
	jr nz,.n3
	ld (iy+E_HP),4
	ld (iy+E_FIRE),40
	scf
	ret
.n3:	cp T_QUEEN
	scf
	ret nz
	ld (iy+E_Y),0
	ld (iy+E_VYH),1
	ld a,(level)
	add a,a
	add a,a
	add a,a
	add a,a
	add a,40		; 56, 72, 88 ... hits
	ld (iy+E_HP),a
	ld (iy+E_FIRE),60
	scf
	ret

; an explosion where IX is (the slot becomes it)
explode:
	ld (ix+E_TYPE),T_EXPL
	ld (ix+E_T),0
	ld (ix+E_VYL),0
	ld (ix+E_VYH),0
	ld a,SND_BANG
	jp sound

; ---------------------------------------------------------------------
;  the player's ship
; ---------------------------------------------------------------------
player_move:
	ld a,(dead)
	or a
	jr z,.alive
	dec a
	ld (dead),a
	ret nz
	ld a,(lives)		; back in, or the end
	or a
	jr z,.over
	ld hl,152+16
	ld (px),hl
	ld a,200+16
	ld (py),a
	ld a,75
	ld (inv),a
	ret
.over:	ld a,ST_OVER
	ld (state),a
	ld a,150
	ld (stimer),a
	call hiscore
	ld a,12
	ld hl,t_over
	ld c,15
	ld e,BRED
	jp text_at
.alive:	ld a,(inv)
	or a
	jr z,.ni
	dec a
	ld (inv),a
.ni:	ld a,(inp)
	ld b,a
	ld hl,(px)
	bit 2,b
	jr z,.nl
	ld de,-3
	add hl,de
	ld a,h
	or a
	jr nz,.nl
	ld a,l
	cp 16
	jr nc,.nl
	ld l,16
.nl:	bit 3,b
	jr z,.nr
	ld de,3
	add hl,de
	ld de,-(16+320-16)
	push hl
	add hl,de
	pop hl
	jr nc,.nr
	ld hl,16+320-16
.nr:	ld (px),hl
	ld a,(py)
	bit 0,b
	jr z,.nu
	sub 3
	cp 16+30
	jr nc,.nu
	ld a,16+30
.nu:	bit 1,b
	jr z,.nd
	add a,3
	cp 16+PFH2-18
	jr c,.nd
	ld a,16+PFH2-18
.nd:	ld (py),a
	ld a,(firecd)		; fire (held = autofire)
	or a
	jr z,.fr
	dec a
	ld (firecd),a
	ret
.fr:	bit 4,b
	ret z
	ld hl,shots
	ld b,NSHOT
.s:	ld a,(hl)
	or a
	jr z,.sf
	inc hl
	inc hl
	inc hl
	djnz .s
	ret
.sf:	ld a,(py)
	sub 6
	ld (hl),a
	inc hl
	ld de,(px)
	ex de,hl
	ld bc,7
	add hl,bc
	ex de,hl
	ld (hl),e
	inc hl
	ld (hl),d
	ld a,5
	ld (firecd),a
	ld a,SND_SHOT
	jp sound

; ---------------------------------------------------------------------
;  enemies
; ---------------------------------------------------------------------
enemies_move:
	ld ix,enemies
	ld b,NENEMY
.e:	push bc
	ld a,(ix+E_TYPE)
	or a
	call nz,enemy_move
	call vschk
	pop bc
	ld de,ESIZE
	add ix,de
	djnz .e
	ret

enemy_move:
	inc (ix+E_T)
	ld a,(ix+E_FLASH)
	or a
	jr z,.nf
	dec (ix+E_FLASH)
.nf:	ld a,(ix+E_TYPE)
	cp T_EXPL
	jr nz,.ne
	ld a,(ix+E_T)		; explosions: 9 frames, riding the scroll
	cp 9
	jp c,ride
	ld (ix+E_TYPE),0
	ret
.ne:	cp T_POD
	jp z,ride_fire
	cp T_QUEEN
	jp z,queen_move
	; drones and darts: fall at their own speed
	call fall
	ld a,(ix+E_TYPE)
	cp T_DART
	jr z,.dart
	ld a,(ix+E_T)		; drones sweep: x = base + sin(4t) * amp / 64
	add a,a
	add a,a
	call sin8
	ld e,(ix+E_AMP)
	call muls8		; HL = A * E / 64 (signed)
	ld e,(ix+E_BXL)
	ld d,(ix+E_BXH)
	add hl,de
	ld (ix+E_XL),l
	ld (ix+E_XH),h
	jr maybe_fire
.dart:	ld a,(ix+E_VYH)		; speeds up to 5 lines a frame
	cp 5
	jr nc,.dn
	ld a,(ix+E_VYL)
	add a,$20
	ld (ix+E_VYL),a
	jr nc,.dn
	inc (ix+E_VYH)
.dn:	ld a,(ix+E_T)		; steers at the player for a while
	cp 24
	jr nc,maybe_fire
	ld l,(ix+E_XL)
	ld h,(ix+E_XH)
	ld de,(px)
	inc de
	inc de
	inc de
	or a
	sbc hl,de
	ld l,(ix+E_XL)
	ld h,(ix+E_XH)
	jr z,maybe_fire
	jr c,.r
	dec hl
	dec hl
	jr .st
.r:	inc hl
	inc hl
.st:	ld (ix+E_XL),l
	ld (ix+E_XH),h
maybe_fire:
	ld a,(state)
	cp ST_PLAY
	ret nz
	dec (ix+E_FIRE)
	ret nz
	call rnd		; next time
	and 63
	ld b,a
	ld a,(level)
	ld c,a
	ld a,110
.lv:	sub 10
	dec c
	jr nz,.lv
	add a,b
	ld (ix+E_FIRE),a
	ld a,(ix+E_Y)		; only from the upper part of the screen
	cp 16+150
	ret nc
	cp 16+8
	ret c
	jp aim

; pods and explosions move with the scenery
ride:	ld a,(scrolled)
	add a,(ix+E_Y)
	jr c,gone
	ld (ix+E_Y),a
	cp 250
	ret c
gone:	ld (ix+E_TYPE),0
	ret
ride_fire:
	call ride
	ld a,(ix+E_TYPE)
	or a
	ret z
	jr maybe_fire

; y += vy (8.8); off the bottom: gone
fall:	ld a,(ix+E_YF)
	add a,(ix+E_VYL)
	ld (ix+E_YF),a
	ld a,(ix+E_Y)
	adc a,(ix+E_VYH)
	jr c,.g
	ld (ix+E_Y),a
	cp 250
	ret c
.g:	pop hl			; (drop the caller)
	jr gone

queen_move:
	ld a,(ix+E_Y)		; comes down to her place
	cp 16+30
	jr nc,.at
	inc (ix+E_Y)
	ret
.at:	ld a,(ix+E_T)		; sways: x = 140 + sin(2t) * 1.75
	add a,a
	call sin8
	ld e,112
	call muls8
	ld de,140+16-20+16
	add hl,de
	ld (ix+E_XL),l
	ld (ix+E_XH),h
	ld a,(state)
	cp ST_PLAY
	ret nz
	dec (ix+E_FIRE)
	ret nz
	ld a,(level)		; spread of three, then an aimed one
	ld b,a
	ld a,50
.l:	sub 4
	djnz .l
	ld (ix+E_FIRE),a
	ld a,(ix+E_T)
	and 1
	jp nz,aim
	ld bc,$0BFC		; vy = 11/4, vx = -1
	call shoot
	ld bc,$0C00
	call shoot
	ld bc,$0B04
	jp shoot

; ---------------------------------------------------------------------
;  enemy bullets
; ---------------------------------------------------------------------
; aim at the player from IX: velocity of length ~2.5 px a frame
aim:	ld l,(ix+E_XL)
	ld h,(ix+E_XH)
	ld de,4
	add hl,de
	ex de,hl
	ld hl,(px)
	ld bc,7
	add hl,bc
	or a
	sbc hl,de		; dx (signed, |dx| < 340)
	ld a,(ix+E_Y)
	add a,4
	ld b,a
	ld a,(py)
	add a,8
	sub b			; dy
	jr nc,.dyp
	xor a			; (upwards: straight down instead)
.dyp:	ld c,a
	; m = max(|dx| / 4, dy / 4): v = d * 10 / m (units of 1/4 px)
	sra h
	rr l
	sra h
	rr l
	srl c
	srl c
	ld a,l
	bit 7,h
	jr z,.ax
	neg
.ax:	ld b,a			; |dx| / 4
	cp c
	jr nc,.m
	ld b,c
.m:	ld a,b
	or a
	jr nz,.nz
	inc b
.nz:	push bc
	ld a,l			; vx = (dx / 4) * 10 / m
	push bc
	call div10m
	pop bc
	ld e,a
	pop bc
	ld a,c			; vy = (dy / 4) * 10 / m
	push de
	call div10m
	pop de
	ld b,a
	ld c,e
	; BC = vy, vx (signed bytes, quarter pixels)
shoot:	push bc
	ld hl,buls
	ld de,BSIZE
	ld b,NBUL
.f:	ld a,(hl)
	or a
	jr z,.g
	add hl,de
	djnz .f
	pop bc
	ret
.g:	pop bc
	ld (hl),1
	inc hl
	push hl
	ld l,(ix+E_XL)		; x * 4 (+ 4 px: about the middle)
	ld h,(ix+E_XH)
	ld de,4
	ld a,(ix+E_TYPE)
	cp T_QUEEN
	jr nz,.nq
	ld e,18
.nq:	add hl,de
	add hl,hl
	add hl,hl
	ex de,hl
	pop hl
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld a,(ix+E_Y)
	add a,6
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,hl
	ex de,hl
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (hl),c
	inc hl
	ld (hl),b
	ret

; A (signed) * 10 / B (B > 0) -> A (signed)
div10m:	ld e,a
	bit 7,a
	jr z,.p
	neg
.p:	ld l,a
	ld h,0
	add hl,hl
	push hl
	add hl,hl
	add hl,hl
	pop bc
	add hl,bc		; * 10
	ld c,b
	ld b,16
	xor a
.d:	add hl,hl
	rla
	cp c
	jr c,.n
	sub c
	inc l
.n:	djnz .d
	ld a,l
	bit 7,e
	ret z
	neg
	ret

bullets_move:
	ld hl,buls
	ld b,NBUL
.b:	push bc
	ld a,(hl)
	or a
	jr z,.n
	push hl
	pop ix
	ld a,(ix+5)		; x += vx
	ld c,a
	add a,a
	sbc a,a
	ld b,a
	ld l,(ix+1)
	ld h,(ix+2)
	add hl,bc
	ld (ix+1),l
	ld (ix+2),h
	ld a,h			; x * 4 within 8 .. 352
	cp (352*4)>>8
	jr nc,.kill
	or l
	jr z,.kill
	ld a,(ix+6)		; y += vy
	ld c,a
	add a,a
	sbc a,a
	ld b,a
	ld l,(ix+3)
	ld h,(ix+4)
	add hl,bc
	ld (ix+3),l
	ld (ix+4),h
	ld a,h			; y * 4 below 1000: on
	cp 3
	jr c,.ok
	jr nz,.kill
	ld a,l
	cp $E8
	jr c,.ok
.kill:	ld (ix+0),0
.ok:	push ix
	pop hl
.n:	pop bc
	ld de,BSIZE
	add hl,de
	djnz .b
	ret

shots_move:
	ld hl,shots
	ld b,NSHOT
.s:	ld a,(hl)
	or a
	jr z,.n
	sub 12
	jr nc,.k
	xor a
.k:	cp 8
	jr nc,.w
	xor a
.w:	ld (hl),a
.n:	inc hl
	inc hl
	inc hl
	djnz .s
	ret

; ---------------------------------------------------------------------
;  collisions
; ---------------------------------------------------------------------
collide:
	; player shots against enemies
	ld hl,shots
	ld b,NSHOT
.s:	push bc
	ld a,(hl)
	or a
	jr z,.sn
	ld (c_y),a
	push hl
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (c_x),de
	call shot_hits
	call vschk
	pop hl
	jr nc,.sn
	ld (hl),0		; the shot is spent
.sn:	pop bc
	inc hl
	inc hl
	inc hl
	djnz .s
	; the player
	ld a,(dead)
	or a
	ret nz
	ld a,(inv)
	or a
	ret nz
	ld hl,buls		; enemy bullets: a small box in the middle
	ld b,NBUL
.b:	ld a,(hl)
	or a
	jr z,.bn
	push bc
	push hl
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	srl d			; x
	rr e
	srl d
	rr e
	ld c,(hl)
	inc hl
	ld a,(hl)
	srl a
	rr c
	srl a
	rr c			; C = y
	ld hl,(px)		; bx within px + 2 .. px + 10
	push de
	ld de,10
	add hl,de
	pop de
	or a
	sbc hl,de
	ld a,h
	or a
	jr nz,.bo
	ld a,l
	cp 9
	jr nc,.bo
	ld a,(py)		; by + 2 within py + 4 .. py + 13
	add a,4
	ld b,a
	ld a,c
	add a,2
	sub b
	cp 10
	jr nc,.bo
	pop hl
	pop bc
	ld (hl),0
	jp player_hit
.bo:	pop hl
	pop bc
.bn:	ld de,BSIZE
	add hl,de
	djnz .b
	; enemy bodies
	ld ix,enemies
	ld b,NENEMY
.e:	ld a,(ix+E_TYPE)
	or a
	jr z,.en
	cp T_EXPL
	jr z,.en
	ld l,(ix+E_XL)		; |ex - px| < 10
	ld h,(ix+E_XH)
	ld de,(px)
	or a
	sbc hl,de
	ld de,10
	add hl,de
	ld a,h
	or a
	jr nz,.en
	ld a,l
	cp 20
	jr nc,.en
	ld a,(py)		; ey within py - 6 .. py + 12
	sub 6
	ld c,a
	ld a,(ix+E_Y)
	sub c
	cp 18
	jr nc,.en
	ld a,(ix+E_TYPE)
	cp T_QUEEN
	call nz,explode
	jp player_hit
.en:	ld de,ESIZE
	add ix,de
	djnz .e
	ret

; does the shot at (c_x, c_y) hit an enemy? (carry: yes)
shot_hits:
	ld ix,enemies
	ld b,NENEMY
.e:	ld a,(ix+E_TYPE)
	or a
	jr z,.n
	cp T_EXPL
	jr z,.n
	ld c,12			; box width
	ld d,10			; and height
	cp T_QUEEN
	jr nz,.w
	ld c,38
	ld d,20
.w:	ld l,(ix+E_XL)		; c_x - ex in 0 .. width
	ld h,(ix+E_XH)
	push de
	ld de,(c_x)
	ex de,hl
	or a
	sbc hl,de
	pop de
	ld a,h
	or a
	jr nz,.n
	ld a,l
	cp c
	jr nc,.n
	ld a,(c_y)		; c_y - ey in -6 .. height
	add a,6
	sub (ix+E_Y)
	jr c,.n
	ld e,a
	ld a,d
	add a,6
	cp e
	jr c,.n
	; hit
	ld (ix+E_FLASH),4
	dec (ix+E_HP)
	jr z,.kill
	ld a,SND_TINK
	call sound
	scf
	ret
.kill:	ld a,(ix+E_TYPE)
	cp T_QUEEN
	jr z,.queen
	ld de,$0001		; drone 100, dart 150, pod 250 (D tens, E hundreds)
	cp T_DRONE
	jr z,.p
	ld de,$5001
	cp T_DART
	jr z,.p
	ld de,$5002
.p:	push bc
	call add_pts
	call explode
	pop bc
	scf
	ret
.n:	ld de,ESIZE
	add ix,de
	dec b
	jp nz,.e
	or a
	ret
.queen:	ld de,$0050		; the Queen: 5000
	call add_pts
	call explode
	ld b,4			; more explosions across her
.qe:	push bc
	ld l,(ix+E_XL)
	ld h,(ix+E_XH)
	ld a,b
	add a,a
	add a,a
	add a,a
	ld e,a
	ld d,0
	add hl,de
	ld a,T_EXPL
	call spawn
	pop bc
	jr nc,.qn
	ld a,b
	add a,a
	add a,a
	add a,(ix+E_Y)
	ld (iy+E_Y),a
.qn:	djnz .qe
	ld a,ST_CLEAR
	ld (state),a
	ld a,150
	ld (stimer),a
	call hiscore
	ld a,11
	ld hl,t_clear
	ld c,10
	ld e,BGREEN
	call text_at
	call hud_build
	scf
	ret

player_hit:
	ld a,(px)		; the ship explodes
	ld l,a
	ld a,(px+1)
	ld h,a
	ld de,3
	add hl,de
	ld a,T_EXPL
	call spawn
	jr nc,.nx
	ld a,(py)
	add a,4
	ld (iy+E_Y),a
.nx:	ld a,SND_DIE
	call sound
	ld a,60
	ld (dead),a
	ld hl,lives
	dec (hl)
	jp hud_build

; ---------------------------------------------------------------------
;  score (BCD, 3 bytes); E = hundreds to add
; ---------------------------------------------------------------------
add_pts:			; D = tens, E = hundreds (BCD)
	ld hl,score+2
	ld a,(hl)
	add a,d
	daa
	ld (hl),a
	dec hl
	ld a,(hl)
	adc a,e
	daa
	ld (hl),a
	dec hl
	ld a,(hl)
	adc a,0
	daa
	ld (hl),a
	jp hud_build

hiscore:			; the high score, if beaten
	ld hl,score
	ld de,hisc
	ld b,3
.c:	ld a,(de)
	cp (hl)
	jr c,.new
	ret nz
	inc hl
	inc de
	djnz .c
	ret
.new:	ld hl,score
	ld de,hisc
	ld bc,3
	ldir
	ret

; ---------------------------------------------------------------------
;  the sprites, back to front
; ---------------------------------------------------------------------
draw_game:
	ld hl,buls		; enemy bullets (overlays)
	ld b,NBUL
.b:	ld a,(hl)
	or a
	jr z,.bn
	push bc
	push hl
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	srl d
	rr e
	srl d
	rr e
	ld c,(hl)
	inc hl
	ld a,(hl)
	srl a
	rr c
	srl a
	rr c
	ld hl,ovl_bul
	ld a,BMAGENTA
	ld b,13
	call ovl_draw
	call vschk
	pop hl
	pop bc
.bn:	ld de,BSIZE
	add hl,de
	djnz .b
	ld ix,enemies		; enemies and explosions
	ld b,NENEMY
.e:	ld a,(ix+E_TYPE)
	or a
	jr z,.en
	push bc
	call enemy_frame
	jr nc,.ex
	ld e,(ix+E_XL)
	ld d,(ix+E_XH)
	ld c,(ix+E_Y)
	push ix
	call spr_draw
	pop ix
	call vschk
.ex:	pop bc
.en:	ld de,ESIZE
	add ix,de
	djnz .e
	ld hl,shots		; the player's shots (overlays)
	ld b,NSHOT
.s:	ld a,(hl)
	or a
	jr z,.sn
	push bc
	push hl
	ld c,a
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld hl,ovl_shot
	ld a,BCYAN
	ld b,15
	call ovl_draw
	call vschk
	pop hl
	pop bc
.sn:	inc hl
	inc hl
	inc hl
	djnz .s
	ld a,(state)		; the player (blinking while protected)
	cp ST_PLAY
	ret nz
	ld a,(dead)
	or a
	ret nz
	ld a,(inv)
	and 4
	ret nz
	ld a,(frame)
	and 2
	ld hl,SP_HORNET1
	jr z,.h
	ld hl,SP_HORNET2
.h:	ld de,(px)
	ld a,(py)
	ld c,a
	jp spr_draw

; IX = enemy -> HL = its frame (no carry: not drawn this frame)
enemy_frame:
	ld a,(ix+E_FLASH)	; hit: blink
	and 2
	ret nz
	ld a,(ix+E_TYPE)
	cp T_DRONE
	jr nz,.n1
	ld a,(ix+E_T)
	and 4
	ld hl,SP_DRONE1
	jr z,.y
	ld hl,SP_DRONE2
.y:	scf
	ret
.n1:	ld hl,SP_DART
	cp T_DART
	jr z,.y
	cp T_POD
	jr nz,.n3
	ld a,(ix+E_FIRE)
	cp 12
	ld hl,SP_POD1
	jr nc,.y
	ld hl,SP_POD2		; about to fire: red eye
	jr .y
.n3:	cp T_EXPL
	jr nz,.n4
	ld a,(ix+E_T)
	ld hl,SP_EXPL1
	cp 3
	jr c,.y
	ld hl,SP_EXPL2
	cp 6
	jr c,.y
	ld hl,SP_EXPL3
	jr .y
.n4:	ld hl,SP_QUEEN
	jr .y

; ---------------------------------------------------------------------
;  helpers
; ---------------------------------------------------------------------
sin8:	ld hl,sintab		; A = angle -> A = sin * 63 (signed)
	ld e,a
	ld d,0
	add hl,de
	ld a,(hl)
	ret

muls8:	ld b,a			; HL = A (signed) * E / 64
	bit 7,a
	jr z,.p
	neg
.p:	ld c,a
	ld d,0
	ld hl,0
	push bc
	ld b,8
.m:	add hl,hl
	sla c
	jr nc,.s
	add hl,de
.s:	djnz .m
	ld b,6
.d:	srl h
	rr l
	djnz .d
	pop bc
	bit 7,b
	ret z
	ld a,l
	cpl
	ld l,a
	ld a,h
	cpl
	ld h,a
	inc hl
	ret

rnd:	ld hl,(seed)		; xorshift
	ld a,h
	rra
	ld a,l
	rra
	xor h
	ld h,a
	ld a,l
	rra
	ld a,h
	rra
	xor l
	ld l,a
	xor h
	ld h,a
	ld (seed),hl
	ret

; A = display row, C = column, HL = text (0 ends), E = colour:
; written where the cells are space (not over scenery), shadows too
text_at:
	ld (tx_row),a
	push hl
	push de
	push bc
	call ring_of		; DE = ring offset of the row
	pop bc
	ld a,c
	add a,e
	ld e,a
	jr nc,$+3
	inc d
	pop bc			; C = colour
	ld a,BLK_W
	call blkport
	out (P_MEM),a
	pop hl
.c:	ld a,(hl)
	or a
	ret z
	push hl
	sub 32
	ld hl,font_map
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	ld (tx_code),a
	ld a,d
	and 7
	ld d,a
	or $78			; SHA
	ld h,a
	ld l,e
	ld a,(hl)
	cp STAR_BANK
	call nz,tx_unpass	; over scenery: out of the scroll pass
	res 3,h			; SHC
	ld a,(tx_code)
	ld (hl),a
	res 4,h			; SHK
	ld (hl),c
	ld a,d			; the screen
	or $F0
	ld h,a
	ld a,(tx_code)
	ld (hl),a
	ld a,COL_ON
	out (P_COLCTL),a
	set 3,h
	ld (hl),c
	xor a
	out (P_COLCTL),a
.s:	inc de
	pop hl
	inc hl
	jr .c

; the cell DE (ring offset) of display row (tx_row) is scenery: take it
; out of its row's pass segment (its entry now writes a spare byte),
; make it a plain cell (attribute 11). HL = its SHA address, kept.
tx_unpass:
	ld (hl),STAR_BANK
	push hl
	push bc
	ld a,LV_ATTR
	out (P_LV),a
	ld a,d
	or $F0
	ld h,a
	ld l,e
	ld (hl),STAR_BANK
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,(tx_row)		; its map row's segment
	sub 2
	ld c,a
	ld b,0
	ld hl,(top)
	or a
	sbc hl,bc
	ld a,l
	and 31
	or SEGS>>8
	ld h,a
	ld l,0
	ld a,d
	or $F0
	ld b,a
	ld c,e			; BC = the cell's address
.fa:	ld a,(hl)		; one-colour list (2 bytes an entry)
	inc hl
	cp c
	ld a,(hl)
	jr nz,.na
	cp b
	jr z,.hit
.na:	inc hl
	bit 7,a
	jr nz,.fa
	ld l,$58		; the other list (4 bytes an entry)
.fb:	ld a,(hl)
	inc hl
	cp c
	ld a,(hl)
	jr nz,.nb
	cp b
	jr z,.hit
.nb:	inc hl
	inc hl
	inc hl
	bit 7,a
	jr nz,.fb
	jr .e
.hit:	ld (hl),high(TX_SPARE)
	dec hl
	ld (hl),low(TX_SPARE)
.e:	pop bc
	pop hl
	ret

; ---------------------------------------------------------------------
;  sound: played while the frame waits for the picture
; ---------------------------------------------------------------------
SND_SHOT equ 0
SND_TINK equ 1
SND_BANG equ 2
SND_DIE	equ 3

sound:	ld e,a			; A = effect; a lower one doesn't cut in
	ld a,(snd_pri)
	cp e
	jr z,.go
	jr c,.go
	ld a,(snd_len)
	or a
	ret nz
.go:	ld a,e
	ld (snd_pri),a
	add a,a
	add a,a
	ld l,a
	ld h,0
	ld de,snd_tab
	add hl,de
	ld a,(hl)
	ld (snd_per),a
	ld (snd_cnt),a
	inc hl
	ld a,(hl)
	ld (snd_len),a
	inc hl
	ld a,(hl)
	ld (snd_nse),a
	inc hl
	ld a,(hl)
	ld (snd_slide),a
	ret
snd_tab:			; period, length (toggles), noise, slide
	db 3,40,0,1
	db 2,16,0,0
	db 6,120,1,0
	db 10,250,1,0

; one step of the sound, called in the wait loops (about every 60 T)
snd_step:
	ld a,(snd_len)
	or a
	ret z
	ld hl,snd_cnt
	dec (hl)
	ret nz
	ld a,(snd_nse)
	or a
	ld a,(snd_per)
	jr z,.t
	push hl
	call rnd
	pop hl
	and 15
	ld b,a
	ld a,(snd_per)
	add a,b
.t:	ld (hl),a
	ld a,(snd_slide)	; falling pitch
	ld b,a
	ld a,(snd_per)
	add a,b
	ld (snd_per),a
	ld hl,snd_len
	dec (hl)
	ld a,(spk)
	xor $40
	ld (spk),a
	out (P_PIOB),a
	ret

; ---------------------------------------------------------------------
;  texts and the wave script
; ---------------------------------------------------------------------
t_ready:	db "GET READY",0
t_over:		db "GAME OVER",0
t_clear:	db "HIVE QUEEN DESTROYED",0
title_texts:	; row, column, colour, text
	db 5,12,YELLOW,"S T A R H I V E",0
	db 8,10,WHITE,"PRESS FIRE TO START",0
	db 12,9,BGREEN,"DESTROY THE HIVE QUEEN",0
	db 16,4,BCYAN,"JOYSTICK OR CURSOR KEYS SPACE FIRE",0
	db 20,11,BMAGENTA,"VIBED BY BPM 2026",0
	db 0

; dw map row; db type, column, count, gap, amplitude
wave_script:
	dw 30
	db T_DRONE,8,5,8,40
	dw 50
	db T_DRONE,28,5,8,40
	dw 70
	db T_DART,0,3,14,0
	dw 90
	db T_POD,18,1,1,0
	dw 100
	db T_DRONE,18,6,7,80
	dw 125
	db T_DART,0,4,12,0
	dw 145
	db T_POD,6,1,1,0
	dw 148
	db T_POD,30,1,1,0
	dw 165
	db T_DRONE,10,5,8,60
	dw 185
	db T_DRONE,26,5,8,60
	dw 205
	db T_DART,0,5,10,0
	dw 230
	db T_POD,12,1,1,0
	dw 233
	db T_POD,24,1,1,0
	dw 250
	db T_DRONE,18,8,6,100
	dw 280
	db T_DART,0,6,9,0
	dw 305
	db T_DRONE,6,5,8,30
	dw 315
	db T_DRONE,30,5,8,30
	dw 335
	db T_POD,18,1,1,0
	dw 350
	db T_DART,0,6,8,0
	dw 375
	db T_DRONE,18,8,6,120
	dw 400
	db T_POD,8,1,1,0
	dw 403
	db T_POD,28,1,1,0
	dw 420
	db T_DART,0,8,8,0
	dw 450
	db T_DRONE,10,6,7,60
	dw 470
	db T_DRONE,26,6,7,60
	dw 490
	db T_POD,14,1,1,0
	dw 493
	db T_POD,22,1,1,0
	dw 510
	db T_DART,0,8,7,0
	dw 535
	db T_DRONE,18,8,6,100
	dw $FFFF
