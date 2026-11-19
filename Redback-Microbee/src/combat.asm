; =====================================================================
;  REDBACK - PHASE 2 combat: enemy waves, shots, bullets, collisions,
;  explosions, score and ships.
;
;  Every object (enemy, player shot, enemy bullet) is a 16-byte record:
;    +0 state   0 free, 1 alive, 2 exploding (enemies only)
;    +1 type    enemies: 0 drone, 1 interceptor
;    +2/3 wx    world x in pixels (screen x = wx - xpos)
;    +4 y       playfield line of the sprite's top
;    +5 vx      signed px/frame          +6 vy  signed px/frame (bullets)
;    +7 frame   sprite frame to draw     +8/9 sx  screen x, set every frame
;    +10 timer  explosion / fire countdown, shot and bullet lifetime
;    +11 ybase  +12 phase  +13 dphase   (the drones' sine path)
;    +14 w      +15 h      collision box (sprite size)
;  Collision is box against box in screen coordinates; the player's box
;  is a little smaller than its sprite. All of this runs in the logic part
;  of the frame; nothing here touches video RAM.
;  VIBED BY BPM 2026
; =====================================================================

combat:	call pstate_update
	call spawn_update
	call enemies_update
	call shots_update
	call bullets_update
	jp collide

; ---------------------------------------------------------------------
;  helpers
; ---------------------------------------------------------------------
; 16-bit Galois LFSR -> A. (Not mixed with R, so test runs repeat exactly;
; the waves still vary with play, as spawns wait for free slots.)
rnd:	ld hl,(seed)
	add hl,hl
	jr nc,.n
	ld a,l
	xor $2D
	ld l,a
.n:	ld (seed),hl
	ld a,l
	xor h
	ret

; the player's sprite line, as drawn (spr_draw clamps at 199)
player_y:
	ld a,(pyf+1)
	cp 200
	ret c
	ld a,199
	ret

; IX: wx += vx, then sx = wx - xpos. Carry = far off screen (x < -48 or >= 368)
obj_move:
	ld a,(ix+5)
	ld e,a
	rla
	sbc a,a
	ld d,a
	ld l,(ix+2)
	ld h,(ix+3)
	add hl,de
	ld (ix+2),l
	ld (ix+3),h
obj_sx:	ld l,(ix+2)
	ld h,(ix+3)
	ld de,(xpos)
	or a
	sbc hl,de
	ld (ix+8),l
	ld (ix+9),h
	ld de,48
	add hl,de
	ld de,416
	or a
	sbc hl,de		; carry if sx + 48 < 416
	ccf
	ret

; IY = table, B = slots -> IY = a free slot (NC), or carry if none
find_free:
	ld de,OBJSZ
.l:	ld a,(iy+0)
	or a
	ret z
	add iy,de
	djnz .l
	scf
	ret

; ---------------------------------------------------------------------
;  the player's state: alive / exploding / GAME OVER
; ---------------------------------------------------------------------
pstate_update:
	ld a,(invul)
	or a
	jr z,.i
	dec a
	ld (invul),a
.i:	ld a,(pstate)
	or a
	ret z
	ld hl,ptimer
	dec (hl)
	ret nz
	cp 2
	jr z,new_game
	; the explosion is over: next ship, or GAME OVER
	ld hl,lives
	dec (hl)
	jr z,.over
	call clear_objs
	jr new_ship
.over:	ld a,2
	ld (pstate),a
	ld a,OVER_T
	ld (ptimer),a
	ld hl,t_over
	ld de,HUDC+40+20
	ld b,20
	call hud_text
	ld a,1
	ld (hudd),a
	ret
new_game:
	xor a
	ld hl,score
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	ld a,LIVES0
	ld (lives),a
	ld hl,t_phase
	ld de,HUDC+40+20
	ld b,20
	call hud_text
	call clear_objs
new_ship:
	xor a
	ld (pstate),a
	ld a,INVUL_T
	ld (invul),a
	ld a,50
	ld (spt),a
	ld a,1
	ld (hudd),a
	ret

clear_objs:
	ld hl,objs
	ld de,objs+1
	ld bc,NOBJ*OBJSZ-1
	ld (hl),0
	ldir
	xor a
	ld (wleft),a
	ret

; the player is hit
player_die:
	ld a,1
	ld (pstate),a
	ld a,PDIE_T
	ld (ptimer),a
	ret

; ---------------------------------------------------------------------
;  waves: drones (4, one behind the other on a sine path) or interceptors
;  (2, chase the player's height and fire), entering ahead of the ship
; ---------------------------------------------------------------------
spawn_update:
	ld a,(pstate)
	or a
	ret nz
	ld hl,spt
	ld a,(hl)
	or a
	jr z,.go
	dec (hl)
	ret
.go:	ld a,(wleft)
	or a
	jr nz,.member
	call rnd		; a new wave
	and 3
	cp 3			; 1 in 4: interceptors
	ld a,0
	ld b,4
	jr nz,.d
	inc a
	ld b,2
.d:	ld (wtype),a
	ld a,b
	ld (wleft),a
	call rnd
	and $7F
	add a,32
	ld (wy),a		; base line 32..159
	call rnd
	and 3
	add a,2
	ld (wdp),a
	ld a,(face)
	ld (wside),a		; ahead of the ship
.member:
	ld iy,enemies
	ld b,NENEMY
	call find_free
	jr nc,.free
	ld a,4			; all slots busy: try again soon
	ld (spt),a
	ret
.free:	ld (iy+0),1
	ld a,(wtype)
	ld (iy+1),a
	ld b,a			; B = type
	ld a,(wy)
	ld (iy+4),a
	ld (iy+11),a
	xor a
	ld (iy+6),a
	ld (iy+12),a
	ld a,(wdp)
	ld (iy+13),a
	ld a,30
	ld (iy+10),a		; first shot after 0.6 s
	ld a,b
	or a
	ld a,W_D
	ld c,H_D
	jr z,.wd
	ld a,W_I
	ld c,H_I
.wd:	ld (iy+14),a
	ld (iy+15),c
	ld a,b			; speed: drones 2, interceptors 3 px/frame
	add a,2
	ld c,a
	ld hl,(xpos)
	ld a,(wside)
	or a
	jr nz,.left
	ld de,330		; ship faces right: enter at the right, fly left
	add hl,de
	xor a
	sub c
	jr .pos
.left:	ld de,-40		; ship faces left: enter at the left, fly right
	add hl,de
	ld a,c
.pos:	ld (iy+5),a
	ld (iy+2),l
	ld (iy+3),h
	ld hl,wleft
	dec (hl)
	ld a,14			; the next member 14 frames later
	jr nz,.st
	call rnd		; the next wave 1.0 .. 2.3 s later
	and 63
	add a,50
.st:	ld (spt),a
	ret

; ---------------------------------------------------------------------
;  enemies: move, animate, fire; explosions count down
; ---------------------------------------------------------------------
enemies_update:
	ld ix,enemies
	ld b,NENEMY
.l:	push bc
	ld a,(ix+0)
	or a
	jp z,.n
	cp 2
	jr nz,.alive
	call obj_sx		; exploding: stays where it was hit
	dec (ix+10)
	jr nz,.xf
	ld (ix+0),0
	jp .n
.xf:	ld a,16
	sub (ix+10)
	srl a
	srl a
	add a,F_X_0
	ld (ix+7),a
	jp .n
.alive:	call obj_move
	jr nc,.on
	ld (ix+0),0		; gone off the screen
	jp .n
.on:	ld a,(ix+1)
	or a
	jr nz,.int
	; drone: y = base + sine / 2
	ld a,(ix+12)
	add a,(ix+13)
	ld (ix+12),a
	ld l,a
	ld h,sine>>8
	ld a,(hl)
	sra a
	add a,(ix+11)
	ld (ix+4),a
	ld a,(frameno)
	rrca
	rrca
	rrca
	and 1
	add a,F_D_0
	ld (ix+7),a
	jp .n
	; interceptor: climb / dive 1 line per frame towards the player
.int:	call player_y
	cp (ix+4)
	jr z,.ify
	jr c,.up
	inc (ix+4)
	jr .ify
.up:	dec (ix+4)
.ify:	ld a,(frameno)
	rrca
	rrca
	and 1
	ld c,a
	ld a,(ix+5)
	or a
	ld a,F_I_0		; flying left: nose left
	jp m,.il
	ld a,F_J_0
.il:	add a,c
	ld (ix+7),a
	ld a,(pstate)
	or a
	jp nz,.n
	dec (ix+10)
	jp nz,.n
	ld (ix+10),45		; fire every 0.9 s while on screen (x 0..299)
	ld a,(ix+9)
	or a
	jr z,.fs
	dec a
	jp nz,.n
	ld a,(ix+8)
	cp 300-256
	jp nc,.n
.fs:	ld iy,buls
	ld b,NBUL
	call find_free
	jp c,.n
	ld (iy+0),1
	ld l,(ix+2)
	ld h,(ix+3)
	ld de,9
	add hl,de
	ld (iy+2),l
	ld (iy+3),h
	ld a,(ix+4)
	add a,3
	ld (iy+4),a
	ld l,(ix+8)		; towards the player
	ld h,(ix+9)
	ld de,(psx)
	or a
	sbc hl,de
	ld a,-BULV
	jp p,.bd
	ld a,BULV
.bd:	ld (iy+5),a
	ld (iy+6),0
	ld (iy+7),F_B_0
	ld (iy+10),70
	ld (iy+14),W_B
	ld (iy+15),H_B
	ld l,(iy+2)		; its screen x for this frame's checks
	ld h,(iy+3)
	ld de,(xpos)
	or a
	sbc hl,de
	ld (iy+8),l
	ld (iy+9),h
.n:	ld de,OBJSZ
	add ix,de
	pop bc
	dec b
	jp nz,.l
	ret

; ---------------------------------------------------------------------
;  player shots: fire (held = auto-fire), move, expire
; ---------------------------------------------------------------------
shots_update:
	ld hl,scool
	ld a,(hl)
	or a
	jr z,.c0
	dec (hl)
	jr .mv
.c0:	ld a,(pinp)
	bit 4,a
	jr z,.mv
	ld a,(tcount)		; not while turning
	or a
	jr nz,.mv
	ld iy,shots
	ld b,NSHOT
	call find_free
	jr c,.mv
	ld (iy+0),1
	ld a,(face)
	or a
	ld hl,(psx)
	ld de,22		; from the nose
	jr z,.fr
	ld de,-7
.fr:	add hl,de
	ld de,(xpos)
	add hl,de
	ld (iy+2),l
	ld (iy+3),h
	ld a,(vx+1)		; the ship's speed, whole pixels
	ld c,a
	ld a,(face)
	or a
	ld a,SHOTV
	ld b,F_S_R
	jr z,.f2
	ld a,-SHOTV
	ld b,F_S_L
.f2:	add a,c
	ld (iy+5),a
	ld (iy+7),b
	call player_y
	add a,5
	ld (iy+4),a
	ld (iy+10),24		; lifetime
	ld (iy+14),W_S
	ld (iy+15),H_S
	ld a,SHOTCOOL
	ld (scool),a
.mv:	ld ix,shots
	ld b,NSHOT
.l:	push bc
	ld a,(ix+0)
	or a
	jr z,.n
	call obj_move
	jr c,.k
	ld l,(ix+8)		; gone once it leaves the screen (x < -16 or >= 320)
	ld h,(ix+9)
	ld de,16
	add hl,de
	ld de,336
	or a
	sbc hl,de
	jr nc,.k
	dec (ix+10)
	jr nz,.n
.k:	ld (ix+0),0
.n:	ld de,OBJSZ
	add ix,de
	pop bc
	djnz .l
	ret

; enemy bullets: move, expire
bullets_update:
	ld ix,buls
	ld b,NBUL
.l:	push bc
	ld a,(ix+0)
	or a
	jr z,.n
	call obj_move
	jr c,.k
	ld a,(ix+4)
	add a,(ix+6)
	ld (ix+4),a
	cp 210
	jr nc,.k
	dec (ix+10)
	jr nz,.n
.k:	ld (ix+0),0
.n:	ld de,OBJSZ
	add ix,de
	pop bc
	djnz .l
	ret

; ---------------------------------------------------------------------
;  collisions: shots vs enemies, then the ship vs enemies and bullets
; ---------------------------------------------------------------------
collide:
	ld hl,(psx)		; the ship's box: 3 px in from each side, 2 lines top and bottom
	ld de,3
	add hl,de
	ld (pobj+8),hl
	call player_y
	add a,2
	ld (pobj+4),a
	ld a,W_P-6
	ld (pobj+14),a
	ld a,H_P-4
	ld (pobj+15),a
	ld ix,shots
	ld b,NSHOT
.s:	push bc
	ld a,(ix+0)
	or a
	jr z,.sn
	ld iy,enemies
	ld b,NENEMY
.e:	push bc
	ld a,(iy+0)
	dec a
	jr nz,.en
	call hitc
	jr nc,.en
	ld (ix+0),0		; the shot is spent
	call enemy_boom
	ld a,(iy+1)		; drone 100, interceptor 250
	or a
	ld a,$00
	ld c,$01
	jr z,.sc
	ld a,$50
	ld c,$02
.sc:	call add_score
	pop bc
	jr .sn
.en:	ld de,OBJSZ
	add iy,de
	pop bc
	djnz .e
.sn:	ld de,OBJSZ
	add ix,de
	pop bc
	djnz .s
	; the ship
	ld a,(pstate)
	or a
	ret nz
	ld a,(invul)
	or a
	ret nz
	ld ix,pobj
	ld iy,enemies
	ld b,NENEMY
.p:	push bc
	ld a,(iy+0)
	dec a
	jr nz,.pn
	call hitc
	jr nc,.pn
	call enemy_boom		; a collision destroys both
	pop bc
	jp player_die
.pn:	ld de,OBJSZ
	add iy,de
	pop bc
	djnz .p
	ld iy,buls
	ld b,NBUL
.b:	push bc
	ld a,(iy+0)
	or a
	jr z,.bn
	call hitc
	jr nc,.bn
	ld (iy+0),0
	pop bc
	jp player_die
.bn:	ld de,OBJSZ
	add iy,de
	pop bc
	djnz .b
	ret

; do the boxes of IX and IY overlap? -> carry. Per axis:
; overlap <=> (p1 - p2 + len1 - 1), as an unsigned number, < len1 + len2 - 1
hitc:	ld l,(ix+8)		; x: 16-bit screen positions
	ld h,(ix+9)
	ld e,(iy+8)
	ld d,(iy+9)
	or a
	sbc hl,de
	ld a,(ix+14)
	dec a
	ld e,a
	add a,l
	ld l,a
	jr nc,.x1
	inc h
.x1:	ld a,h
	or a
	ret nz			; NC: apart
	ld a,e
	add a,(iy+14)
	ld e,a
	ld a,l
	cp e
	ret nc
	ld a,(ix+4)		; y: lines 0..229, the difference made 16-bit
	sub (iy+4)
	ld l,a
	sbc a,a
	ld h,a
	ld a,(ix+15)
	dec a
	ld e,a
	add a,l
	ld l,a
	jr nc,.y1
	inc h
.y1:	ld a,h
	or a
	ret nz
	ld a,e
	add a,(iy+15)
	ld e,a
	ld a,l
	cp e
	ret

; IY: the enemy blows up (16 frames, X_0..X_3)
enemy_boom:
	ld (iy+0),2
	ld (iy+10),16
	ld (iy+7),F_X_0
	ret

; add A (tens and units, BCD) and C (thousands and hundreds) to the score
add_score:
	ld hl,score
	add a,(hl)
	daa
	ld (hl),a
	inc hl
	ld a,c
	adc a,(hl)
	daa
	ld (hl),a
	inc hl
	ld a,0
	adc a,(hl)
	daa
	ld (hl),a
	ret
