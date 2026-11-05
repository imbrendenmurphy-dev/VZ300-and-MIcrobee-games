;=====================================================================
; Demo AI: picks a hop each idle tick by predicting lane positions.
;=====================================================================

; ai_pred: IX = lane, B = dt ticks, C = screen x -> A = col value
ai_pred:
	push bc
	ld l,(ix+L_SF)
	ld h,(ix+L_SI)
	ld e,(ix+L_VEL)
	ld d,(ix+L_VEL+1)
	ld a,(slowmo)
	or a
	jr z,.m
	sra d
	rr e
	sra d
	rr e
.m:	ld a,b
	or a
	jr z,.d
.l:	add hl,de
	djnz .l
.d:	ld a,h
	add a,c
	and 127
	ld l,(ix+L_COL)
	ld h,(ix+L_COL+1)
	call addhla
	ld a,(hl)
	pop bc
	ret

; ai_safe: A = row, C = frog x, B = dt -> Z = safe, NZ = unsafe
ai_safe:
	push bc
	call lane_ptr
	pop bc
	ld a,(ix+L_KIND)
	cp K_ROAD
	jr z,.road
	cp K_WATER
	jr z,.water
	xor a
	ret
.road:	push bc
	inc c
	call ai_pred
	pop bc
	cp C_DEAD
	jr z,.bad
	push bc
	ld a,c
	add a,4
	ld c,a
	call ai_pred
	pop bc
	cp C_DEAD
	jr z,.bad
	push bc
	ld a,c
	add a,6
	ld c,a
	call ai_pred
	pop bc
	cp C_DEAD
	jr z,.bad
	xor a
	ret
.water:	push bc
	ld a,c
	add a,3
	ld c,a
	call ai_pred
	pop bc
	cp C_PLAT
	jr nz,.bad
	push bc
	ld a,c
	add a,5
	ld c,a
	call ai_pred
	pop bc
	cp C_PLAT
	jr nz,.bad
	xor a
	ret
.bad:	or 1
	ret

; safe over a window dt = B..B+3 : A = row, C = x
ai_safe_win:
	ld (aw_row),a
	ld e,4
.l:	push de
	push bc
	ld a,(aw_row)
	call ai_safe
	pop bc
	pop de
	ret nz
	inc b
	dec e
	jr nz,.l
	xor a
	ret

ai_think:		; -> A = direction key bits (0 = wait)
	ld a,(fstate)
	cp FS_PLAY
	ld a,0
	ret nz
	ld a,(fhop)
	or a
	ld a,0
	ret nz
	ld a,(ai_wait)
	or a
	jr z,.go
	dec a
	ld (ai_wait),a
	xor a
	ret
.go:	call frog_row
	ld (ai_row),a
	ld a,(fx+1)
	ld (ai_x),a
	; at row 1: steer to a free bay
	ld a,(ai_row)
	cp 1
	jr nz,.notop
	call ai_bay
	ret nz
.notop:	; edge danger on water
	ld a,(ai_row)
	call lane_ptr
	ld a,(ix+L_KIND)
	cp K_WATER
	jr nz,.ne
	ld a,(ai_x)
	cp 10
	ld a,K_RT
	ret c
	ld a,(ai_x)
	cp 108
	ld a,K_LT
	ret nc
.ne:	ld a,(ai_row)
	cp 2
	jr nz,.ne2
	call ai_reach
	jr nz,.skipup
.ne2:	ld a,(ai_x)
	ld c,a
	ld b,3
	ld a,(ai_row)
	dec a
	jr z,.skipup
	call ai_safe_win
	jr nz,.skipup
	call rand
	and 1
	ld (ai_wait),a
	ld a,K_UP
	ret
.skipup:
	; staying safe?
	ld a,(ai_x)
	ld c,a
	ld b,1
	ld a,(ai_row)
	call ai_safe_win
	jr nz,.flee
	; idle a little
	call rand
	and 3
	jr nz,.w
	; occasional side step toward centre on land
	xor a
	ret
.w:	xor a
	ret
.flee:	; try left, right, down
	ld a,(ai_x)
	cp 10
	jr c,.nl
	sub 8
	ld c,a
	ld b,3
	ld a,(ai_row)
	call ai_safe_win
	ld a,K_LT
	ret z
.nl:	ld a,(ai_x)
	cp 110
	jr nc,.nr
	add a,8
	ld c,a
	ld b,3
	ld a,(ai_row)
	call ai_safe_win
	ld a,K_RT
	ret z
.nr:	ld a,(ai_row)
	inc a
	ld hl,nlanes
	cp (hl)
	jr nc,.stay
	ld b,a
	ld a,(ai_x)
	ld c,a
	ld a,b
	ld b,3
	call ai_safe_win
	ld a,K_DN
	ret z
.stay:	xor a
	ret

; on row 1: line up under the nearest empty bay, then hop up
ai_bay:
	ld hl,BAYX
	ld b,5
	ld e,255		; best dist
	ld d,0			; best x
	ld c,0
.l:	push hl
	ld hl,bays
	ld a,c
	call addhla
	ld a,(hl)
	pop hl
	cp 1
	jr z,.n
	cp 4
	jr z,.n
	ld a,(ai_x)
	sub (hl)
	jr nc,$+4
	neg
	cp e
	jr nc,.n
	ld e,a
	ld d,(hl)
.n:	inc hl
	inc c
	djnz .l
	ld a,e
	cp 255
	jr z,.none
	cp 5
	jr nc,.move
	ld a,K_UP
	or a
	ret
.move:	call ai_reach
	jr nz,.mv0
	xor a
	ret
.mv0:	ld a,(ai_x)
	cp d
	ld a,K_RT
	jr c,.mv
	ld a,K_LT
.mv:	; only if destination stays on a platform
	push af
	ld a,(ai_x)
	ld c,a
	pop af
	push af
	cp K_RT
	ld a,c
	jr nz,.ml
	add a,8
	jr .mc
.ml:	sub 8
.mc:	ld c,a
	ld b,3
	ld a,1
	call ai_safe_win
	jr nz,.no
	pop af
	or a
	ret
.no:	pop af
.none:	xor a
	ret

; is a free bay reachable by drifting along row 1 from x = ai_x ?  Z = yes
ai_reach:
	ld a,1
	call lane_ptr
	ld a,(ix+L_VEL+1)
	ld (ar_dir),a		; bit7 set -> lane moves right
	ld hl,BAYX
	ld c,0
.l:	push hl
	ld hl,bays
	ld a,c
	call addhla
	ld a,(hl)
	pop hl
	cp 1
	jr z,.n
	cp 4
	jr z,.n
	ld a,(ar_dir)
	bit 7,a
	ld a,(ai_x)
	jr z,.left
	; moving right: need bay.x >= x-4  ->  bay.x + 4 >= x
	ld b,a
	ld a,(hl)
	add a,4
	cp b
	jr nc,.yes
	jr .n
.left:	add a,4
	cp (hl)
	jr nc,.yes
.n:	inc hl
	inc c
	ld a,c
	cp 5
	jr nz,.l
	or 1
	ret
.yes:	xor a
	ret
