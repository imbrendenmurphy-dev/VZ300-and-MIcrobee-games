; =====================================================================
;  ENEMIES & BOSSES
; =====================================================================

; spawn: E=type, B=x(+32), C=y(+16), D=param  -> IX entity, carry if full
spawn:	ld ix,ENTS
	push bc
	ld b,NENT
.f:	ld a,(ix+E_TYPE)
	or a
	jr z,.got
	push de
	ld de,ENTSZ
	add ix,de
	pop de
	djnz .f
	pop bc
	scf
	ret
.got:	pop bc
	push hl
	; clear slot
	push ix
	pop hl
	push bc
	ld b,ENTSZ
.c:	ld (hl),0
	inc hl
	djnz .c
	pop bc
	pop hl
	ld (ix+E_TYPE),e
	ld (ix+E_X),b
	ld (ix+E_Y),c
	ld (ix+E_P1),d
	; per-type defaults from table: hp, spr, flags
	ld a,e
	dec a
	ld l,a
	add a,a
	add a,l			; *3
	ld l,a
	ld h,0
	push de
	ld de,etype_tab
	add hl,de
	pop de
	ld a,(hl)
	ld (ix+E_HP),a
	inc hl
	ld a,(hl)
	ld (ix+E_SPR),a
	inc hl
	ld a,(hl)
	ld (ix+E_FL),a
	call setbox
	; type-specific init
	ld a,e
	cp T_SWIM
	jr nz,.n1
	ld a,d
	rrca
	rrca
	rrca
	rrca
	and 15
	add a,a
	add a,4
	ld (ix+E_P3),a		; amplitude
	ld a,c
	ld (ix+E_P1),a		; base y
	ld (ix+E_VX),1
	ld a,(lvlnum)
	cp 4
	jr c,.n0
	ld (ix+E_VX),2
.n0:	or a
	ret
.n1:	cp T_SPIN
	jr nz,.n2
	ld (ix+E_VY),1
	or a
	ret
.n2:	cp T_EXPL
	jr nz,.n3
	ld hl,sfx_pop
	call sfx
	or a
	ret
.n3:	cp T_TURF
	jr z,.tur
	cp T_TURC
	jr nz,.n4
.tur:	call rnd
	and 31
	ld (ix+E_TM),a
	or a
	ret
.n4:	cp T_SNAKE
	jr nz,.n5
	; segments follow the head's position history
	push ix
	pop hl
	ld (snkhead),hl
	ld a,b
	ld (tmp1),a
	ld a,c
	ld (tmp1+1),a
	ld (ix+E_P1),c		; base y
	ld hl,snkhist
	ld b,32
.hi:	ld a,(tmp1)
	ld (hl),a
	inc hl
	ld a,(tmp1+1)
	ld (hl),a
	inc hl
	djnz .hi
	ld b,6
	ld d,4
.sg:	push bc
	push de
	ld a,(tmp1)
	ld b,a
	ld a,(tmp1+1)
	ld c,a
	ld e,T_SEG
	call spawn
	pop de
	pop bc
	jr c,.sgx
	ld (ix+E_P1),d		; history delay
	ld a,d
	add a,4
	ld d,a
	djnz .sg
.sgx:	or a
	ret
.n5:	or a
	ret

setbox:	; set E_W/E_H from sprite size
	push de
	push hl
	ld a,(ix+E_SPR)
	call sprsz
	ld (ix+E_W),d
	ld (ix+E_H),e
	pop hl
	pop de
	ret

;            hp, sprite, flags
etype_tab:
	db 1,SP_SWIM0,0			; 1 swim
	db 2,SP_DART0,0			; 2 dart
	db 3,SP_TURF0,FL_TERR		; 3 floor turret
	db 3,SP_TURC0,FL_TERR		; 4 ceiling turret
	db 2,SP_HOP0,FL_TERR		; 5 hopper
	db 4,SP_CARR0,0			; 6 carrier
	db 2,SP_SPIN0,0			; 7 spinner
	db 12,SP_GUNS0,0		; 8 gunship
	db 2,SP_SPORE0,0		; 9 spore
	db 1,SP_FRAG,0			; 10 fragment
	db 1,SP_CAPW0,FL_INV		; 11 capsule
	db 1,SP_EXPL0,FL_INV|FL_HARM	; 12 explosion
	db 255,SP_SERPH0,0		; 13 boss body / serpent head
	db 1,SP_BORB,0			; 14 boss orb
	db 5,SP_SERPA,0		; 15 snake head
	db 3,SP_SERPB,0		; 16 snake segment
	db 4,SP_SERPA,0			; 17 serpent segment
	db 10,SP_CORE0,0		; 18 boss part
	db 6,SP_CORE1,FL_TERR		; 19 dreadnought reactor node

; points (BCD hundreds) per type
escore:	db 1,2,3,3,2,5,1,$10,2,0,0,0,$99,0,$10,1,2,5,$10

; damage entity IX by A
hit_ent:
	ld b,a
	ld a,(ix+E_HP)
	sub b
	jr c,.dead
	jr z,.dead
	ld (ix+E_HP),a
	set 3,(ix+E_FL)
	ld hl,sfx_hit
	jp sfx
.dead:	ld (ix+E_HP),0
	ld a,(ix+E_TYPE)
	cp T_BOSS
	jp z,boss_die
	cp T_BPART
	jp z,part_die
	cp T_SSEG
	jp z,seg_break
	; score
	push af
	dec a
	ld e,a
	ld d,0
	ld hl,escore
	add hl,de
	ld a,(hl)
	or a
	call nz,addscore
	pop af
	cp T_GUNS
	jr nz,.ng
	ld hl,sfx_boom
	call sfx
	ld a,T_GUNS
.ng:	cp T_CARR
	jr z,.drop
	cp T_SPORE
	jr z,.split
	cp T_SNAKE
	jr z,.snk
.ex:	; become an explosion
	ld (ix+E_TYPE),T_EXPL
	ld (ix+E_SPR),SP_EXPL0
	ld (ix+E_FL),FL_INV|FL_HARM
	ld (ix+E_TM),0
	ld hl,sfx_pop
	jp sfx
.drop:	ld (ix+E_TYPE),T_CAPS
	ld a,(ix+E_P1)		; capsule kind from carrier param
	ld (ix+E_P1),a
	ld (ix+E_SPR),SP_CAPW0
	cp 1
	jr nz,$+6
	ld (ix+E_SPR),SP_CAPS
	cp 2
	jr nz,$+6
	ld (ix+E_SPR),SP_CAPH
	ld (ix+E_FL),FL_INV
	ld (ix+E_TM),0
	call setbox
	ld hl,sfx_caps
	jp sfx
.split:	ld b,(ix+E_X)
	ld c,(ix+E_Y)
	push ix
	ld hl,fragdirs
	ld a,4
.sp:	push af
	push hl
	push bc
	ld e,T_FRAG
	ld d,0
	call spawn
	pop bc
	pop hl
	jr c,.spx
	ld a,(hl)
	ld (ix+E_VX),a
	inc hl
	ld a,(hl)
	ld (ix+E_VY),a
	inc hl
	ld (ix+E_TM),40
	pop af
	dec a
	jr nz,.sp
	push af
.spx:	pop af
	pop ix
	jr .ex
.snk:	; kill all segments
	push ix
	ld ix,ENTS
	ld b,NENT
.sk:	ld a,(ix+E_TYPE)
	cp T_SEG
	jr nz,.skn
	ld (ix+E_TYPE),T_EXPL
	ld (ix+E_SPR),SP_EXPL0
	ld (ix+E_FL),FL_INV|FL_HARM
	ld (ix+E_TM),0
.skn:	ld de,ENTSZ
	add ix,de
	djnz .sk
	pop ix
	jp .ex
fragdirs: db 2,2, 2,-2, -2,2, -2,-2

; ---------------------------------------------------------------------
upd_ents:
	ld ix,ENTS
	ld b,NENT
.l:	push bc
	ld a,(ix+E_TYPE)
	or a
	jr z,.nx
	bit 0,(ix+E_FL)
	jr z,.ns
	ld a,(scrolled)
	or a
	jr z,.ns
	dec (ix+E_X)
.ns:	ld a,(ix+E_TYPE)
	dec a
	add a,a
	ld l,a
	ld h,0
	ld de,ebeh
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	call jphl
	; cull off-screen (not bosses / orbs)
	ld a,(ix+E_TYPE)
	or a
	jr z,.nx
	cp T_BOSS
	jr z,.nx
	cp T_BORB
	jr z,.nx
	cp T_BPART
	jr z,.nx
	cp T_SSEG
	jr z,.nx
	ld a,(ix+E_X)
	cp 8
	jr c,.cull
	cp 210
	jr nc,.cull
	ld a,(ix+E_Y)
	cp 2
	jr c,.cull
	cp 16+PFH+10
	jr c,.nx
.cull:	ld (ix+E_TYPE),0
.nx:	ld de,ENTSZ
	add ix,de
	call vschk
	pop bc
	djnz .l
	ret

ebeh:	dw b_swim,b_dart,b_turf,b_turc,b_hop,b_carr,b_spin,b_guns
	dw b_spore,b_frag,b_caps,b_expl,b_boss,b_borb,b_snake,b_seg
	dw b_sseg,b_bpart,b_core

anim2:	; toggle sprite between base and base+1 every 4 frames; A=base
	ld b,a
	ld a,(frame)
	and 4
	ld a,b
	jr z,$+3
	inc a
	ld (ix+E_SPR),a
	ret

; firing rate helper: returns NZ when it's time; A=base interval
firetime:
	ld b,a
	ld a,(lvlnum)
	add a,a
	ld c,a
	ld a,(loopn)
	add a,a
	add a,a
	add a,c
	ld c,a
	ld a,b
	sub c
	cp 16
	jr nc,$+4
	ld a,16
	ld b,a
	inc (ix+E_TM)
	ld a,(ix+E_TM)
	cp b
	ret c
	ld (ix+E_TM),0
	xor a
	inc a
	ret
onscreen: ; carry set if entity well on screen (x 40..150)
	ld a,(ix+E_X)
	cp 40
	ccf
	ret nc
	cp 150
	ret

b_swim:	ld a,(ix+E_X)
	sub (ix+E_VX)
	ld (ix+E_X),a
	ld a,(ix+E_P2)
	add a,6
	ld (ix+E_P2),a
	ld l,a
	ld h,sint>>8
	ld a,(hl)		; -127..127
	ld e,(ix+E_P3)		; amplitude 4..34
	call smul		; A = sin*amp/128
	add a,(ix+E_P1)
	ld (ix+E_Y),a
	ld a,SP_SWIM0
	jp anim2
smul:	; A (signed) * E (unsigned) / 128 -> A (signed)
	push bc
	push hl
	ld c,a
	bit 7,a
	jr z,$+4
	neg
	ld h,0
	ld l,a
	ld d,0
	; hl = |a| * e
	ld b,8
	ld a,l
	ld hl,0
.m:	add hl,hl
	rla
	jr nc,$+3
	add hl,de
	djnz .m
	add hl,hl
	ld a,h
	bit 7,c
	jr z,$+4
	neg
	pop hl
	pop bc
	ret

b_dart:	ld a,(ix+E_ST)
	or a
	jr nz,.s1
	ld a,(ix+E_X)
	sub 2
	ld (ix+E_X),a
	cp 32+92
	ret nc
	ld (ix+E_ST),1
	ld (ix+E_TM),12
	ret
.s1:	cp 1
	jr nz,.s2
	ld a,SP_DART0
	call anim2
	dec (ix+E_TM)
	ret nz
	ld (ix+E_ST),2
	ld b,(ix+E_X)
	ld c,(ix+E_Y)
	call aimdir
	add a,a
	ld e,a
	ld d,0
	ld hl,dirtab
	add hl,de
	ld a,(hl)
	sra a
	sra a
	ld (ix+E_VX),a
	inc hl
	ld a,(hl)
	sra a
	sra a
	ld (ix+E_VY),a
	ld (ix+E_SPR),SP_DART0
	ret
.s2:	; dash (velocity in px*... /4 of 24 => 6, i.e. ~1.5px per step; do twice)
	ld a,(ix+E_X)
	add a,(ix+E_VX)
	add a,(ix+E_VX)
	ld (ix+E_X),a
	ld a,(ix+E_Y)
	add a,(ix+E_VY)
	ld (ix+E_Y),a
	ret

b_turf:	ld c,0
	jr turret
b_turc:	ld c,1
turret:	; aim frame
	ld a,(px)
	add a,8
	cp (ix+E_X)
	ld a,0
	jr c,$+4
	ld a,1
	add a,a
	add a,c
	; sprite table: turf0,turf1 / turc0,turc1 interleave
	ld b,a
	ld a,c
	or a
	ld a,SP_TURF0
	jr z,$+4
	ld a,SP_TURC0
	bit 1,b
	jr z,$+3
	inc a
	ld (ix+E_SPR),a
	call onscreen
	ret nc
	ld a,90
	call firetime
	ret z
	ld b,(ix+E_X)
	inc b
	inc b
	ld c,(ix+E_Y)
	ld a,1
	ld (bulslow),a		; turret bullets are slower
	call fireaim
	xor a
	ld (bulslow),a
	ret

b_hop:	ld a,(ix+E_ST)
	or a
	jr nz,.air
	ld a,SP_HOP0
	ld (ix+E_SPR),a
	inc (ix+E_TM)
	ld a,(ix+E_TM)
	cp 30
	ret c
	ld (ix+E_TM),0
	ld (ix+E_ST),1
	ld (ix+E_VY),-6
	ld a,(px)
	cp (ix+E_X)
	ld a,-1
	jr c,$+4
	ld a,2
	ld (ix+E_VX),a
	ret
.air:	ld (ix+E_SPR),SP_HOP1
	ld a,(ix+E_X)
	add a,(ix+E_VX)
	ld (ix+E_X),a
	ld a,(frame)
	and 1
	jr nz,.g
	ld a,(ix+E_VY)
	inc a
	cp 5
	jr nc,.g
	ld (ix+E_VY),a
.g:	ld a,(ix+E_Y)
	add a,(ix+E_VY)
	ld (ix+E_Y),a
	; landed?
	ld a,(ix+E_VY)
	bit 7,a
	ret nz
	ld a,(ix+E_X)
	sub 32-3
	ld b,a
	ld a,(ix+E_Y)
	sub 16-4
	ld c,a
	call solid
	ret z
	ld a,(ix+E_Y)
	sub 16-4
	and $fc
	add a,16-4
	ld (ix+E_Y),a
	ld (ix+E_ST),0
	ret

b_carr:	ld a,(frame)
	and 1
	jr nz,.a
	dec (ix+E_X)
.a:	ld a,SP_CARR0
	jp anim2

b_spin:	dec (ix+E_X)
	ld a,(ix+E_Y)
	add a,(ix+E_VY)
	ld (ix+E_Y),a
	; bounce off terrain
	ld a,(ix+E_X)
	sub 32-1
	ld b,a
	ld a,(ix+E_VY)
	bit 7,a
	ld a,(ix+E_Y)
	jr nz,.up
	sub 16-3
	jr .t
.up:	sub 16+1
.t:	ld c,a
	call solid
	jr z,.ok
	ld a,(ix+E_VY)
	neg
	ld (ix+E_VY),a
.ok:	ld a,SP_SPIN0
	jp anim2

b_guns:	ld a,(ix+E_ST)
	or a
	jr nz,.s1
	dec (ix+E_X)
	ld a,(ix+E_X)
	cp 32+100
	ret nc
	ld (ix+E_ST),1
	ret
.s1:	cp 1
	jr nz,.s2
	ld a,(ix+E_P2)
	add a,3
	ld (ix+E_P2),a
	ld l,a
	ld h,sint>>8
	ld a,(hl)
	sra a
	sra a
	sra a
	sra a
	ld b,a
	ld a,(ix+E_P1)
	add a,b
	cp 16+2
	jr nc,$+4
	ld a,16+2
	cp 16+PFH-9
	jr c,$+4
	ld a,16+PFH-9
	ld (ix+E_Y),a
	inc (ix+E_P3)
	ld a,(ix+E_P3)
	cp 250
	jr c,.f
	ld (ix+E_ST),2
	ret
.f:	ld a,70
	call firetime
	ret z
	ld b,(ix+E_X)
	ld a,(ix+E_Y)
	add a,3
	ld c,a
	push bc
	ld a,7
	call firedir
	pop bc
	push bc
	ld a,8
	call firedir
	pop bc
	ld a,9
	jp firedir
.s2:	inc (ix+E_X)
	inc (ix+E_X)
	ret

b_spore:
	dec (ix+E_X)
	ld a,(frame)
	and 3
	ret nz
	inc (ix+E_P2)
	ld a,(ix+E_P2)
	and 8
	ld a,(ix+E_Y)
	jr z,$+5
	inc a
	jr $+3
	dec a
	ld (ix+E_Y),a
	ld a,SP_SPORE0
	jp anim2

b_frag:	ld a,(ix+E_X)
	add a,(ix+E_VX)
	ld (ix+E_X),a
	ld a,(ix+E_Y)
	add a,(ix+E_VY)
	ld (ix+E_Y),a
	dec (ix+E_TM)
	ret nz
	ld (ix+E_TYPE),0
	ret

b_caps:	ld a,(frame)
	and 1
	jr nz,.a
	dec (ix+E_X)
.a:	ld a,(ix+E_P1)
	or a
	ret nz
	; weapon capsule cycles red/blue/yellow every 24 frames
	inc (ix+E_TM)
	ld a,(ix+E_TM)
	cp 24
	jr c,.s
	ld (ix+E_TM),0
	ld a,(ix+E_FR)
	inc a
	cp 3
	jr c,$+3
	xor a
	ld (ix+E_FR),a
.s:	ld a,(ix+E_FR)
	add a,SP_CAPW0
	ld (ix+E_SPR),a
	ret

b_expl:	inc (ix+E_TM)
	ld a,(ix+E_TM)
	srl a
	srl a
	cp 4
	jr nc,.done
	add a,SP_EXPL0
	ld (ix+E_SPR),a
	ret
.done:	ld (ix+E_TYPE),0
	ret

b_snake:
	; head: sinuous path leftwards, records history
	ld a,(frame)
	and 1
	jr nz,.m
	dec (ix+E_X)
.m:	dec (ix+E_X)
	ld a,(ix+E_P2)
	add a,5
	ld (ix+E_P2),a
	ld l,a
	ld h,sint>>8
	ld a,(hl)
	ld e,20
	call smul
	add a,(ix+E_P1)
	ld (ix+E_Y),a
	; push history (shift)
	ld hl,snkhist+61
	ld de,snkhist+63
	ld bc,62
	lddr
	ld a,(ix+E_X)
	ld (snkhist),a
	ld a,(ix+E_Y)
	ld (snkhist+1),a
	ret
b_seg:	ld a,(ix+E_P1)		; delay in frames
	add a,a
	ld l,a
	ld h,0
	ld de,snkhist
	add hl,de
	ld a,(hl)
	inc a
	ld (ix+E_X),a
	inc hl
	ld a,(hl)
	inc a
	ld (ix+E_Y),a
	; die if head gone
	ld hl,(snkhead)
	ld a,(hl)
	cp T_SNAKE
	ret z
	cp T_BOSS
	ret z
	ld (ix+E_TYPE),T_EXPL
	ld (ix+E_FL),FL_INV|FL_HARM
	ld (ix+E_TM),0
	ret


; ---- dreadnought reactor node: set in a hull socket, irises open and shut.
;      Only hittable while open; fires at the player now and then.
b_core:	inc (ix+E_TM)
	ld a,(ix+E_TM)
	bit 0,(ix+E_ST)
	jr nz,.open
	cp 30
	ret c
	ld (ix+E_TM),0
	set 0,(ix+E_ST)
	res 1,(ix+E_FL)
	ld (ix+E_SPR),SP_CORE0
	ret
.open:	cp 16
	jr nz,.o2
	call onscreen
	jr nc,.o2
	ld b,(ix+E_X)
	ld a,(ix+E_Y)
	add a,3
	ld c,a
	call fireaim
.o2:	ld a,(ix+E_TM)
	cp 44
	ret c
	ld (ix+E_TM),0
	res 0,(ix+E_ST)
	set 1,(ix+E_FL)
	ld (ix+E_SPR),SP_CORE1
	ret
