; =====================================================================
;  HUGE BOSSES (v1.1). Body = one big pre-cached image (SP_BIG) whose
;  silhouette is described by a per-row left-edge table; separate part
;  entities (core / guns / hatches / fan guns) ride on it.
;  Stage 3 instead has the ARMOURED SERPENT (head + plated segments).
;  bossdef: W,H,hp,move,interval,atk*4,orbs,nparts, parts*5, gfx W*H, edges H
; =====================================================================
BD_W	equ 0
BD_H	equ 1
BD_HP	equ 2
BD_MOVE	equ 3
BD_INT	equ 4
BD_ATK	equ 5
BD_ORB	equ 9
BD_NP	equ 10
BD_PARTS equ 11
; part kinds
PK_CORE	equ 1
PK_GUN	equ 2
PK_HATCH equ 3
PK_FAN	equ 4
NSEG	equ 13			; serpent segments (last one is the tail)

bossdef	dw 0
bossW	db 0
bossH	db 0
bossgfx	dw 0
bossedge dw 0
bossamp	db 0
bhome	db 0
serparm	db 0

; ---- level start: find the boss definition and its silhouette table
;      (the body itself is drawn from PCG glyphs: see draw_boss_body)
boss_setup:
	ld hl,(LVLBUF+19)
	ld (bossdef),hl
	push hl
	pop iy
	xor a
	ld (bossW),a
	ld a,h
	or l
	ret z
	ld a,(iy+BD_W)
	ld (bossW),a
	or a
	ret z
	ld a,(iy+BD_H)
	ld (bossH),a
	ld a,(iy+BD_NP)
	ld b,a
	add a,a
	add a,a
	add a,b
	add a,BD_PARTS
	ld e,a
	ld d,0
	add hl,de
	ld (bossedge),hl
	ld a,(bossH)
	ld e,a
	add hl,de
	ld (bossgfx),hl
	ret


; ---- spawn the boss (from the level's spawn list)
start_boss:
	ld a,(bossent+1)
	or a
	ret nz			; already active
	ld hl,sfx_warn
	call sfx
	ld iy,(bossdef)
	ld a,(bossW)
	or a
	jp z,start_serpent
	; home x (right aligned, 4px margin) and centred y
	add a,a
	add a,a
	ld b,a
	ld a,32+124
	sub b
	ld (bhome),a
	ld a,(bossH)
	ld b,a
	ld a,PFH
	sub b
	srl a
	ld c,a
	or a
	jr z,$+3
	dec a
	ld (bossamp),a
	ld a,c
	add a,16
	ld c,a
	ld b,164
	ld e,T_BOSS
	ld d,0
	call spawn
	ret c
	ld (bossent),ix
	ld (ix+E_SPR),SP_BIG
	ld a,(bossW)
	add a,a
	add a,a
	ld (ix+E_W),a
	ld a,(bossH)
	ld (ix+E_H),a
	ld (ix+E_P1),c		; base y
	ld (ix+E_HP),255
	; ---- parts
	ld iy,(bossdef)
	ld a,(iy+BD_NP)
	or a
	jp z,.orbs
	ld b,a
	push iy
	pop hl
	ld de,BD_PARTS
	add hl,de
.p:	push bc
	push hl
	ld a,(hl)		; kind
	ld (sb_k),a
	inc hl
	ld a,(hl)
	ld (sb_dx),a
	inc hl
	ld a,(hl)
	ld (sb_dy),a
	inc hl
	ld a,(hl)
	ld (sb_hp),a
	inc hl
	ld a,(hl)
	ld (sb_pm),a
	ld ix,(bossent)
	ld a,(ix+E_X)
	ld hl,sb_dx
	add a,(hl)
	ld b,a
	ld a,(ix+E_Y)
	ld hl,sb_dy
	add a,(hl)
	ld c,a
	ld e,T_BPART
	ld a,(sb_k)
	ld d,a
	call spawn
	jr c,.pn
	ld a,(sb_dx)
	ld (ix+E_P2),a
	ld a,(sb_dy)
	ld (ix+E_P3),a
	ld a,(sb_pm)
	ld (ix+E_VX),a
	ld a,(loopn)
	add a,a
	add a,a
	ld hl,sb_hp
	add a,(hl)
	ld (ix+E_HP),a
	ld a,(sb_k)
	ld hl,partspr-1
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	ld (ix+E_SPR),a
	call setbox
	call rnd
	and 31
	ld (ix+E_TM),a
	ld a,(sb_k)
	cp PK_CORE
	jr nz,.pn
	set 1,(ix+E_FL)		; core starts shut
	ld (ix+E_SPR),SP_CORE1
.pn:	pop hl
	ld de,5
	add hl,de
	pop bc
	dec b
	jp nz,.p
.orbs:	ld iy,(bossdef)
	ld a,(iy+BD_ORB)
	or a
	ret z
	ld b,a
	ld c,0
.ob:	push bc
	ld e,T_BORB
	ld b,170
	ld c,40
	ld d,0
	push bc
	call spawn
	pop bc
	pop bc
	ret c
	ld (ix+E_P2),c		; angle
	ld a,c
	add a,64
	ld c,a
	djnz .ob
	ret
sb_k	db 0
sb_dx	db 0
sb_dy	db 0
sb_hp	db 0
sb_pm	db 0
partspr	db SP_CORE0,SP_BGUN0,SP_HATCH0,SP_BGUN0

; ---- boss body behaviour
b_boss:	ld a,(bossW)
	or a
	jp z,b_serp
	ld iy,(bossdef)
	ld a,(ix+E_ST)
	or a
	jr nz,.act
	; entering: travels with the scenery in 4 px steps, then the scroll stops
	ld a,(scrollon)
	or a
	jr z,.e1
	ld a,(scrolled)
	or a
	ret z
	ld a,(scrollx)
	and 3
	ret nz
	jr .e2
.e1:	ld a,(frame)
	and 3
	ret nz
.e2:	ld a,(ix+E_X)
	sub 4
	ld (ix+E_X),a
	ld hl,bhome
	cp (hl)
	ret nc
	ld a,(hl)
	ld (ix+E_X),a
	xor a
	ld (scrollon),a
	ld (ix+E_ST),1
	ld hl,sfx_boom
	jp sfx
.act:	cp 2
	jp z,.dying
	jr .atk0		; huge bodies stay put (their parts animate)
	inc (ix+E_P2)
	ld a,(iy+BD_MOVE)
	cp 1
	jr z,.mstat
	cp 2
	jr z,.mslow
	; 0: steady vertical sweep
	ld a,(ix+E_P2)
	add a,a
	jr .msin
.mslow:	ld a,(ix+E_P2)
	jr .msin
.mstat:	ld a,(ix+E_P2)
	add a,a
	add a,a
	ld l,a
	ld h,sint>>8
	ld a,(hl)
	ld e,2
	call smul
	jr .my
.msin:	ld l,a
	ld h,sint>>8
	ld a,(hl)
	ld hl,bossamp
	ld e,(hl)
	call smul
.my:	add a,(ix+E_P1)
	ld (ix+E_Y),a
	; ---- attack cycle from the body
.atk0:	ld a,(iy+BD_INT)
	call firetime
	ret z
	ld a,(ix+E_P3)
	inc a
	and 3
	ld (ix+E_P3),a
	add a,BD_ATK
	ld e,a
	ld d,0
	push iy
	pop hl
	add hl,de
	ld a,(hl)
	ld b,(ix+E_X)
	ld c,a
	ld a,(bossH)
	srl a
	add a,(ix+E_Y)
	ld e,c
	ld c,a			; B,C = left-middle of the body
	ld a,e
	jp boss_attack
.dying:	; explosions all over the body, then the stage is done
	inc (ix+E_TM)
	ld a,(ix+E_TM)
	cp 90
	jr nc,.fin
	and 3
	ret nz
	call rnd
	ld e,a
	ld a,(ix+E_W)
	call scale8
	add a,(ix+E_X)
	ld b,a
	call rnd
	ld e,a
	ld a,(ix+E_H)
	call scale8
	add a,(ix+E_Y)
	ld c,a
	push ix
	call boom
	pop ix
	ld hl,sfx_boom
	jp sfx
.fin:	ld (ix+E_TYPE),0
	ld a,1
	ld (lvldone),a
	ret
scale8:	; A = A * E / 256
	ld d,0
	ld h,d
	ld l,d
	ld b,8
.l:	add hl,hl
	rla
	jr nc,$+3
	add hl,de
	djnz .l
	ld a,h
	ret

; A = attack kind, B,C = origin. 1 aimed burst, 2 fan, 3 ring, 4 swimmers, 5 darts, 6 spores
boss_attack:
	cp 1
	jr z,.aim
	cp 2
	jr z,.fan
	cp 3
	jr z,.ring
	push af
	call count_ents
	ld e,a
	ld a,(thin)		; thinning: fewer minions at once
	or a
	ld a,e
	jr z,$+4
	add a,4
	cp 14
	jr c,.room
	pop af
	ret
.room:	pop af
	cp 4
	jr z,.swims
	cp 5
	jr z,.darts
	ld e,T_SPORE
	ld d,0
	jp spawn
.aim:	push bc
	call fireaim
	pop bc
	ld a,c
	sub 6
	ld c,a
	push bc
	call fireaim
	pop bc
	ld a,c
	add a,12
	ld c,a
	jp fireaim
.fan:	ld a,6
.fl:	push af
	push bc
	call firedir
	pop bc
	pop af
	inc a
	cp 11
	jr c,.fl
	ret
.ring:	xor a
.rl:	push af
	push bc
	call firedir
	pop bc
	pop af
	add a,2
	cp 16
	jr c,.rl
	ret
.swims:	ld e,T_SWIM
	ld d,$22
	push bc
	ld a,c
	sub 10
	ld c,a
	call spawn
	pop bc
	ld a,c
	add a,10
	ld c,a
	ld e,T_SWIM
	ld d,$22
	jp spawn
.darts:	ld e,T_DART
	ld d,0
	ld c,16+8
	push bc
	call spawn
	pop bc
	ld c,16+44
	ld e,T_DART
	ld d,0
	jp spawn

; ---- parts ride on the body
b_bpart:
	ld hl,(bossent)
	ld a,(hl)
	cp T_BOSS
	jp nz,.gone
	push hl
	pop iy
	ld a,(iy+E_ST)
	cp 2
	jp z,.gone
	ld a,(iy+E_X)
	add a,(ix+E_P2)
	ld (ix+E_X),a
	ld a,(iy+E_Y)
	add a,(ix+E_P3)
	ld (ix+E_Y),a
	ld a,(iy+E_ST)
	or a
	ret z			; entering: idle
	ld a,(ix+E_P1)
	cp PK_CORE
	jr z,.core
	cp PK_HATCH
	jr z,.hatch
	cp PK_FAN
	jr z,.fan
	; gun: barrel tracks the player, aimed shots
	ld a,(py)
	cp (ix+E_Y)
	ld a,SP_BGUN0
	jr c,$+3
	inc a
	ld (ix+E_SPR),a
	ld a,70
	call firetime
	ret z
	ld b,(ix+E_X)
	ld c,(ix+E_Y)
	inc c
	jp fireaim
.fan:	ld a,90
	call firetime
	ret z
	ld b,(ix+E_X)
	ld c,(ix+E_Y)
	inc c
	ld a,7
.fl:	push af
	push bc
	call firedir
	pop bc
	pop af
	inc a
	cp 10
	jr c,.fl
	ret
.hatch:	ld a,(frame)
	and 8
	ld a,SP_HATCH0
	jr z,$+3
	inc a
	ld (ix+E_SPR),a
	ld a,120
	call firetime
	ret z
	call count_ents
	cp 14
	ret nc
	ld b,(ix+E_X)
	ld c,(ix+E_Y)
	ld a,(ix+E_VX)
	ld e,T_SWIM
	ld d,$21
	cp 1
	jr z,.hs
	ld e,T_DART
	ld d,0
	cp 2
	jr z,.hs
	ld e,T_SPORE
.hs:	jp spawn
.core:	; iris cycle: open 56 frames, shut 36
	inc (ix+E_TM)
	ld a,(ix+E_TM)
	bit 0,(ix+E_ST)
	jr nz,.open
	cp 36
	ret c
	ld (ix+E_TM),0
	set 0,(ix+E_ST)
	res 1,(ix+E_FL)
	ld (ix+E_SPR),SP_CORE0
	ld hl,sfx_open
	jp sfx
.open:	cp 56
	ret c
	ld (ix+E_TM),0
	res 0,(ix+E_ST)
	set 1,(ix+E_FL)
	ld (ix+E_SPR),SP_CORE1
	ret
.gone:	ld (ix+E_TYPE),T_EXPL
	ld (ix+E_SPR),SP_EXPL0
	ld (ix+E_FL),FL_INV|FL_HARM
	ld (ix+E_TM),0
	ret

; ---- a part was destroyed (IX)
part_die:
	ld a,(ix+E_P1)
	cp PK_CORE
	jr nz,.p
	ld ix,(bossent)
	jp boss_die
.p:	ld a,$05
	call addscore
	ld (ix+E_TYPE),T_EXPL
	ld (ix+E_SPR),SP_EXPL0
	ld (ix+E_FL),FL_INV|FL_HARM
	ld (ix+E_TM),0
	ld hl,sfx_boom
	jp sfx

; ---- collision with the boss body. IX = T_BOSS entity, cb box overlaps its bbox
;      returns A: 0 = miss, 1 = absorbed by armour, 2 = damage
boss_hit:
	ld a,(bossW)
	or a
	jr z,.serp
	ld a,(cb_h)
	srl a
	ld hl,cb_y
	add a,(hl)
	sub (ix+E_Y)
	jr c,.miss
	ld hl,bossH
	cp (hl)
	jr nc,.miss
	ld e,a
	ld d,0
	ld hl,(bossedge)
	add hl,de
	ld a,(hl)
	cp 255
	jr z,.miss
	add a,(ix+E_X)
	ld e,a			; left edge of this row
	ld a,(cb_x)
	ld hl,cb_w
	add a,(hl)
	cp e
	jr c,.miss
	jr z,.miss
	ld a,1
	ret
.miss:	xor a
	ret
.serp:	ld a,(serparm)
	or a
	ld a,1
	ret nz
	inc a
	ret

; ---- draw the big body first so parts and everything else sit on top
draw_boss_body:
	ld a,(bossent+1)
	or a
	ret z
	ld ix,(bossent)
	ld a,(ix+E_TYPE)
	cp T_BOSS
	ret nz
	ld a,(ix+E_SPR)
	cp SP_BIG
	ret nz
	ld b,(ix+E_X)
	ld c,(ix+E_Y)
	jp boss_cells

; ---- boss destroyed (IX = body or serpent head)
boss_die:
	ld (ix+E_ST),2
	ld (ix+E_TM),0
	ld (ix+E_HP),255
	set 1,(ix+E_FL)
	set 2,(ix+E_FL)
	ld a,$99
	call addscore
	ld a,$01
	call addscore
	push ix
	ld ix,ENTS
	ld b,NENT
.o:	ld a,(ix+E_TYPE)
	cp T_BORB
	jr z,.k
	cp T_BPART
	jr z,.k
	cp T_SSEG
	jr z,.k
	cp T_SWIM
	jr z,.k
	cp T_DART
	jr z,.k
	cp T_SPORE
	jr z,.k
	cp T_FRAG
	jr nz,.n
.k:	ld (ix+E_TYPE),T_EXPL
	ld (ix+E_SPR),SP_EXPL0
	ld (ix+E_FL),FL_INV|FL_HARM
	ld (ix+E_TM),0
.n:	ld de,ENTSZ
	add ix,de
	djnz .o
	pop ix
	ld hl,BULS
	ld b,NBUL*8
.c:	ld (hl),0
	inc hl
	djnz .c
	ld hl,sfx_bigboom
	jp sfx

count_ents: ; A = number of active entities (keeps BC)
	push bc
	push hl
	push de
	ld hl,ENTS
	ld de,ENTSZ
	ld bc,NENT<<8
.l:	ld a,(hl)
	or a
	jr z,$+3
	inc c
	add hl,de
	djnz .l
	ld a,c
	pop de
	pop hl
	pop bc
	ret

; ---- shield orbs sweep in front of the boss
b_borb:	ld hl,(bossent)
	ld a,(hl)
	cp T_BOSS
	jr z,.ok
	ld (ix+E_TYPE),0
	ret
.ok:	push hl
	pop iy
	ld a,(ix+E_P2)
	add a,3
	ld (ix+E_P2),a
	ld l,a
	ld h,sint>>8
	ld a,(hl)
	ld e,24
	call smul
	add a,(iy+E_X)
	ld (ix+E_X),a
	ld a,(ix+E_P2)
	add a,64
	ld l,a
	ld a,(hl)
	ld e,30
	call smul
	ld b,a
	ld a,(iy+E_H)
	srl a
	add a,(iy+E_Y)
	add a,b
	dec a
	ld (ix+E_Y),a
	ret

; =====================================================================
;  ARMOURED SERPENT: a horned head coils a figure-of-eight through the
;  cavern, trailing hex-plated segments. Break every plate to expose the
;  head, then destroy it.
; =====================================================================
start_serpent:
	; clear any small snakes still around (they share the history buffer)
	ld ix,ENTS
	ld b,NENT
.cs:	ld a,(ix+E_TYPE)
	cp T_SNAKE
	jr z,.ck
	cp T_SEG
	jr nz,.cn
.ck:	ld (ix+E_TYPE),0
.cn:	ld de,ENTSZ
	add ix,de
	djnz .cs
	ld b,170
	ld c,16+26
	ld e,T_BOSS
	ld d,0
	call spawn
	ret c
	ld (bossent),ix
	ld (snkhead),ix
	ld (ix+E_SPR),SP_SERPH0
	call setbox
	ld iy,(bossdef)
	ld a,(loopn)
	add a,a
	add a,a
	add a,a
	add a,(iy+BD_HP)
	ld (ix+E_HP),a
	ld (ix+E_P2),0		; phase x
	ld (ix+E_P3),0		; phase y
	ld (ix+E_ST),1
	; history all at the entry point
	ld hl,snkhist
	ld b,64
.h:	ld (hl),170
	inc hl
	ld (hl),16+26
	inc hl
	djnz .h
	; segments
	ld a,NSEG-1
	ld (serparm),a
	ld b,NSEG
	ld d,4
.sg:	push bc
	push de
	ld e,T_SSEG
	ld b,170
	ld c,16+26
	call spawn
	pop de
	pop bc
	jr c,.sx
	ld (ix+E_P1),d
	ld a,(loopn)
	add a,4
	ld (ix+E_HP),a
	ld a,b
	dec a
	jr nz,.nt
	ld (ix+E_ST),2		; tail
	ld (ix+E_SPR),SP_SERPT
	set 1,(ix+E_FL)
	call setbox
.nt:	ld a,d
	add a,4
	ld d,a
	djnz .sg
.sx:	ret

b_serp:	ld a,(ix+E_ST)
	cp 2
	jp z,b_boss.dying
	; figure-of-eight path over the arena (half speed once the head is exposed)
	ld a,(serparm)
	or a
	jr nz,.mv
	ld a,(frame)
	and 1
	jr nz,.nomv
.mv:	inc (ix+E_P2)
	ld a,(ix+E_P3)
	add a,2
	ld (ix+E_P3),a
.nomv:
	ld a,(ix+E_P2)
	add a,64		; cos
	ld l,a
	ld h,sint>>8
	ld a,(hl)
	ld e,56
	call smul
	add a,32+58
	ld (ix+E_X),a
	ld a,(ix+E_P3)
	ld l,a
	ld h,sint>>8
	ld a,(hl)
	ld e,40
	call smul
	add a,16+23
	ld (ix+E_Y),a
	; mouth
	ld a,(frame)
	and 8
	ld a,SP_SERPH0
	jr z,$+3
	inc a
	ld (ix+E_SPR),a
	; exposed head flashes
	ld a,(serparm)
	or a
	jr nz,.hist
	ld a,(frame)
	and 3
	jr nz,.hist
	set 3,(ix+E_FL)
.hist:	; push position into the history
	ld hl,snkhist+125
	ld de,snkhist+127
	ld bc,126
	lddr
	ld a,(ix+E_X)
	ld (snkhist),a
	ld a,(ix+E_Y)
	ld (snkhist+1),a
	; head attacks: aimed burst, faster once exposed
	ld iy,(bossdef)
	ld a,(serparm)
	or a
	ld a,(iy+BD_INT)
	jr nz,$+4
	srl a
	call firetime
	ret z
	ld b,(ix+E_X)
	ld a,(ix+E_Y)
	add a,4
	ld c,a
	ld a,(serparm)
	or a
	jp z,boss_attack.fan
	jp fireaim

b_sseg:	; follow the head's path, delayed by E_P1 positions
	ld hl,(snkhead)
	ld a,(hl)
	cp T_BOSS
	jr nz,.die
	push hl
	pop iy
	ld a,(iy+E_ST)
	cp 2
	jr z,.die
	ld a,(ix+E_P1)
	add a,a
	ld l,a
	ld h,0
	ld de,snkhist
	add hl,de
	ld a,(hl)
	add a,2
	ld (ix+E_X),a
	inc hl
	ld a,(hl)
	ld (ix+E_Y),a
	ld a,(ix+E_ST)
	or a
	ret nz			; bare or tail: harmless to shoot through
	; armoured segments occasionally spit at the player
	call rnd
	cp 3
	ret nc
	call onscreen
	ret nc
	ld b,(ix+E_X)
	ld c,(ix+E_Y)
	jp fireaim
.die:	ld (ix+E_TYPE),T_EXPL
	ld (ix+E_SPR),SP_EXPL0
	ld (ix+E_FL),FL_INV|FL_HARM
	ld (ix+E_TM),0
	ret

seg_break:	; plate destroyed -> bare segment
	ld (ix+E_ST),1
	ld (ix+E_SPR),SP_SERPB
	set 1,(ix+E_FL)
	ld (ix+E_HP),255
	call setbox
	ld a,$02
	call addscore
	ld a,(serparm)
	dec a
	ld (serparm),a
	ld hl,sfx_clank
	jp nz,sfx
	ld hl,sfx_expose	; all plates gone: the head is exposed
	jp sfx
