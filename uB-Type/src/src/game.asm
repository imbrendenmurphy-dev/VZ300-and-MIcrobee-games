; =====================================================================
;  GAME: level setup, main loop, player, pod, shots, bullets, collisions
; =====================================================================

new_game:
	xor a
	ld (lvlnum),a
new_game_at:			; (the attract demo starts on other stages)
	xor a
	ld (score),a
	ld (score+1),a
	ld (score+2),a
	ld (loopn),a
	ld a,3
	ld (lives),a
	ld a,1
	ld (nextlife),a
	xor a
	ld (podst),a
	ld (podw),a
	ld (sats),a
	ld a,1
	ld (pspeed),a
level_start:
	call fe_stage_intro		; interstitial
	ld a,(lvlnum)
	ld (bossidx),a
	call stage_load			; PCG, tables, sprite set; level blob -> LVLBUF
	ld ix,LVLBUF
	ld (lvlptr),ix
	ld b,5
	ld hl,fixtab
.fx:	ld a,(hl)
	inc hl
	push hl
	ld e,a
	ld d,0
	ld hl,LVLBUF
	add hl,de		; HL -> pointer word
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,d
	or e
	jr z,.fz
	push hl
	ld hl,LVLBUF
	add hl,de
	ex de,hl
	pop hl
	ld (hl),d
	dec hl
	ld (hl),e
.fz:	pop hl
	djnz .fx
	jr lvfixd
fixtab:	db 9,11,13,15,19
lvfixd:
	ld ix,(lvlptr)
	ld a,(ix+2)
	ld (palcss),a
	ld a,(ix+3)
	ld (palT),a
	ld a,(ix+4)
	ld (palA),a
	ld a,(ix+5)
	ld (palB),a
	ld a,(ix+6)
	ld (palC),a
	ld l,(ix+7)
	ld h,(ix+8)
	ld (lvlcols),hl
	ld l,(ix+11)
	ld h,(ix+12)
	ld (objbase),hl
	ld l,(ix+13)
	ld h,(ix+14)
	ld (spnbase),hl
	call boss_setup
	call prof_reset
	ld hl,(dbgcol)		; debug start column (0 in normal play)
	ld (checkpt),hl
life_start:
	; clear objects
	ld hl,ENTS
	ld bc,NENT*ENTSZ+NSHOT*8+NBUL*8-1
	ld (hl),0
	ld d,h
	ld e,l
	inc de
	ldir
	ld hl,(checkpt)
	call setview
	ld a,1
	ld (scrollon),a
	xor a
	ld (pstate),a
	ld (pbank),a
	ld (charge),a
	ld (firehold),a
	ld (lvldone),a
	ld (sfxon),a
	ld (bossent+1),a
	ld (bgbaked),a
	ld (bodybaked),a
	ld a,32+12
	ld (px),a
	ld a,16+24
	ld (py),a
	ld a,60
	ld (pinv),a
	call hud_init
	call play_screen		; game display mode
	ld a,1
	ld (rpage),a			; the first render is page A
	call render
	call flip
	call hud_put
	xor a
	ld (vcount),a
; ---------------------------------------------------------------------
mainloop:
	call waitframe
	call flip
	call hud_put
	ld hl,frame
	inc (hl)
	call readinp
	call scroll_step
	call do_spawns
	call upd_player
	call upd_pod
	call upd_shots
	call upd_ents
	call upd_bullets
	call collide
	; render (into the page not on screen)
	call render
	call hud_update
	; end conditions
	ld a,(lvldone)
	or a
	jp nz,level_clear
	ld a,(pstate)
	cp 2
	jp z,lose_life
	; RETURN / ESC: abandon the game and go back to the title
	ld a,K_RET
	call key1
	jp nz,fe_quit
	ld a,K_ESC
	call key1
	jp nz,fe_quit
	; pause: H key
	ld a,K_H
	call key1
	call nz,pause
	ld a,(demomode)
	or a
	jp nz,demo_check
	jp mainloop

pause:	xor a
	ld (sfxon),a
	ld (spkbit),a
	out (P_PIOB),a
.w1:	call vsync1
	ld a,K_H
	call key1
	jr nz,.w1
.w2:	call vsync1
	ld a,K_X		; X while paused: end the game
	call key1
	jr z,.nq
	pop af
	jp fe_quit
.nq:	ld a,K_H
	call key1
	jr z,.w2
.w3:	call vsync1
	ld a,K_H
	call key1
	jr nz,.w3
	ret

checkpt	dw 0
fill4	db $00,$55,$aa,$ff

lose_life:
	ld a,(trainer)		; trainer mode: lives never run out
	or a
	jr nz,.keep
	ld a,(lives)
	dec a
	ld (lives),a
	jp z,fe_game_over
.keep:
	; checkpoint: halfway if passed
	ld hl,(lvlcols)
	srl h
	rr l
	ld de,(scol)
	ex de,hl
	or a
	sbc hl,de		; scol - half
	ld hl,0
	jr c,.cp
	ex de,hl
	ld de,-40
	add hl,de		; half-40
	ex de,hl
	ld hl,(lvlcols)
	srl h
	rr l
	ld de,-40
	add hl,de
.cp:	ld (checkpt),hl
	xor a
	ld (podst),a
	ld (podw),a
	ld (sats),a
	ld a,1
	ld (pspeed),a
	jp life_start

level_clear:
	ld a,(lvlnum)
	inc a
	cp 8
	jr c,.n
	call fe_congrats
	ld a,(loopn)
	inc a
	ld (loopn),a
	xor a
.n:	ld (lvlnum),a
	jp level_start

; ---------------------------------------------------------------------
;  spawning from the level list
; ---------------------------------------------------------------------
do_spawns:
	ld hl,(spnptr)
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,d
	and e
	inc a
	ret z
	push hl
	ld hl,(scol)
	ld bc,32
	add hl,bc
	or a
	sbc hl,de		; scol+32-col
	pop hl
	ret c
	inc hl
	ld a,(hl)		; type
	ld (sp_t),a
	inc hl
	ld a,(hl)
	ld (sp_y),a
	inc hl
	ld a,(hl)
	ld (sp_p),a
	inc hl
	ld (spnptr),hl
	ld (sp_col),de
	call spawn_from_list
	jr do_spawns
sp_t	db 0
sp_y	db 0
sp_p	db 0
sp_col	dw 0

; screen x (+32) of world column sp_col
col2sx:	push bc			; (keeps BC: callers hold y in C)
	ld hl,(sp_col)
	ld de,(scol)
	or a
	sbc hl,de
	ld a,l
	add a,a
	add a,a
	ld b,a
	ld a,(scrollx)
	and 3
	ld c,a
	ld a,b
	sub c
	add a,32
	pop bc
	ret

spawn_from_list:
	; thinning (Microbee): just over 4 in 9 ordinary enemies are left out
	ld a,(thin)
	or a
	jr z,.all
	ld a,(sp_t)
	cp T_CORE+1
	jr nc,.all
	ld e,a
	ld d,0
	ld hl,thintab
	add hl,de
	ld a,(hl)
	or a
	jr z,.all
	ld a,(thinc)		; keep 9 in 16 (about 56%)
	add a,9
	cp 16
	jr c,.skip
	sub 16
	ld (thinc),a
	jr .all
.skip:	ld (thinc),a
	ret
.all:	ld a,(sp_t)
	cp T_TURF
	jp z,.turf
	cp T_TURC
	jp z,.turc
	cp T_HOP
	jp z,.hop
	cp T_SWIM
	jp z,.swim
	cp T_BOSS
	jp z,start_boss
	cp T_CORE
	jr nz,.flier
	ld a,(sp_y)		; reactor node: fixed in its hull socket
	add a,16
	ld c,a
	call col2sx
	ld b,a
	ld e,T_CORE
	ld d,0
	call spawn
	ret c
	set 1,(ix+E_FL)		; starts shut
	ret
.flier:	; plain flier at right edge
	ld a,(sp_y)
	add a,16
	ld c,a
	ld b,164
	ld a,(sp_t)
	ld e,a
	ld a,(sp_p)
	ld d,a
	jp spawn
.swim:	; formation: count in low nibble, amplitude in high nibble
	ld a,(sp_p)
	and 15
	ld b,a
	ld a,(thin)		; thinning: 9/16 of a formation, at least one
	or a
	jr z,.sw0
	ld a,b
	add a,a
	add a,a
	add a,a
	add a,b			; 9n
	add a,8
	rrca
	rrca
	rrca
	rrca
	and 15
	ld b,a
	jr nz,.sw0
	inc b
.sw0:
	ld c,0			; index
.sl:	push bc
	ld a,c
	add a,a
	add a,a
	ld e,a
	add a,a
	add a,e			; 12*index
	add a,164
	ld b,a
	ld a,(sp_y)
	add a,16
	ld c,a
	ld a,(sp_p)
	ld d,a
	pop hl
	push hl
	ld a,l			; index -> phase via d? store in hl
	ld (sp_idx),a
	ld e,T_SWIM
	call spawn
	jr c,.sx
	ld a,(sp_idx)
	add a,a
	add a,a
	add a,a
	add a,a
	add a,a
	ld (ix+E_P2),a		; phase offset
.sx:	pop bc
	inc c
	djnz .sl
	ret
.turf:	; sits on the floor of its column (or at an explicit height)
	ld a,(sp_y)
	or a
	jr nz,.ty
	call colcf
	ld a,(dc_f)
	ld c,a
	ld a,NTR
	sub c
	add a,a
	add a,a			; floor y
	sub 5
.ty:	add a,16
	ld c,a
	call col2sx
	ld b,a
	ld e,T_TURF
	ld d,0
	jp spawn
.turc:	ld a,(sp_y)
	or a
	jr nz,.tc
	call colcf
	ld a,(dc_c)
	add a,a
	add a,a
.tc:	add a,16
	ld c,a
	call col2sx
	ld b,a
	ld e,T_TURC
	ld d,0
	jp spawn
.hop:	call colcf
	ld a,(dc_f)
	ld c,a
	ld a,NTR
	sub c
	add a,a
	add a,a
	sub 4
	add a,16
	ld c,a
	call col2sx
	ld b,a
	ld e,T_HOP
	ld d,0
	jp spawn
sp_idx	db 0
; types that thinning may leave out (not carriers, bosses or reactor nodes)
;		0 SWIM DART TURF TURC HOP CARR SPIN GUNS SPORE ...
thintab	db 0,0,1,1,1,1,0,1,0,1,0,0,0,0,0,0,0,0,0,0
thinc	db 0
thinb	db 0
colcf:	; dc_c / dc_f of column sp_col
	ld hl,(sp_col)
	push hl
	call prof_fill
	pop hl
	ld h,PROFR>>8
	ld a,(hl)
	and 15
	ld (dc_f),a
	ld a,(hl)
	rrca
	rrca
	rrca
	rrca
	and 15
	ld (dc_c),a
	ret

; ---------------------------------------------------------------------
;  player
; ---------------------------------------------------------------------
upd_player:
	ld a,(pstate)
	or a
	jr z,.alive
	; dying: count down then signal
	ld a,(deadtm)
	dec a
	ld (deadtm),a
	ret nz
	ld a,2
	ld (pstate),a
	ret
.alive:	ld a,(pinv)
	or a
	jr z,.ni
	dec a
	ld (pinv),a
.ni:	ld a,(pspeed)
	ld d,a
	ld a,(inp)
	ld e,a
	ld hl,py
	bit 0,e
	jr z,.nu
	ld a,(hl)
	sub d
	cp 16
	jr nc,$+4
	ld a,16
	ld (hl),a
.nu:	bit 1,e
	jr z,.nd
	ld a,(hl)
	add a,d
	cp 16+PFH-5
	jr c,$+4
	ld a,16+PFH-5
	ld (hl),a
.nd:	ld hl,px
	bit 2,e
	jr z,.nl
	ld a,(hl)
	sub d
	cp 32
	jr nc,$+4
	ld a,32
	ld (hl),a
.nl:	bit 3,e
	jr z,.nr
	ld a,(hl)
	add a,d
	cp 32+118
	jr c,$+4
	ld a,32+118
	ld (hl),a
.nr:	; banking: lean into vertical movement, level out when released
	ld a,(frame)
	and 1
	jr nz,.nb
	ld a,(inp)
	and 3
	ld b,0
	cp 1
	jr nz,$+4
	ld b,-2
	cp 2
	jr nz,$+4
	ld b,2
	ld a,(pbank)		; step one frame toward the target (-2..+2)
	sub b
	jr z,.nb
	ld a,(pbank)
	jp m,.inc		; (small signed values: no overflow)
	dec a
	jr .bs
.inc:	inc a
.bs:	ld (pbank),a
.nb:	call upd_sats
	; firing
	ld a,(inpedge)
	bit 4,a
	jr z,.nf
	call fire_normal
.nf:	ld a,(inp)
	bit 4,a
	jr z,.rel
	ld a,(firehold)
	inc a
	jr z,.ch
	ld (firehold),a
.ch:	cp 6
	jr c,.tc
	ld a,(charge)
	cp 48
	jr nc,.tc
	inc a
	ld (charge),a
	cp 8
	call nc,sfx_charge
	jr .tc
.rel:	ld a,(charge)
	cp 12
	jr c,.nobeam
	call fire_beam
.nobeam: xor a
	ld (charge),a
	ld (firehold),a
.tc:	; terrain collision
	ld a,(pinv)
	or a
	ret nz
	ld a,(px)
	sub 32
	ld (tmp1),a
	ld a,(py)
	sub 16
	ld (tmp1+1),a
	ld hl,ptpts
	ld b,5
.pt:	push bc
	ld a,(tmp1)
	add a,(hl)
	ld b,a
	inc hl
	ld a,(tmp1+1)
	add a,(hl)
	ld c,a
	inc hl
	push hl
	call solid
	pop hl
	pop bc
	jp nz,kill_player
	djnz .pt
	ret
ptpts:	db 6,2, 1,1, 1,3, 4,1, 4,3	; terrain test points (fins trimmed by a pixel)

kill_player:
	ld a,(demomode)		; the attract demo's ship can't be hit
	or a
	ret nz
	ld a,(pstate)
	or a
	ret nz
	ld a,(pinv)
	or a
	ret nz
	ld a,1
	ld (pstate),a
	ld a,70
	ld (deadtm),a
	xor a
	ld (charge),a
	ld hl,sfx_die
	call sfx
	; three explosions around the ship
	ld a,(px)
	ld b,a
	ld a,(py)
	ld c,a
	call boom
	ld a,(px)
	add a,5
	ld b,a
	ld a,(py)
	sub 3
	ld c,a
	call boom
	ld a,(px)
	sub 3
	ld b,a
	ld a,(py)
	add a,3
	ld c,a
	call boom
	; pod is lost
	xor a
	ld (podst),a
	ret

; spawn explosion at B,C (sprite top-left, offset coords)
boom:	ld e,T_EXPL
	ld d,0
	jp spawn

; ---- player shots -----------------------------------------------------
; shot record: type, x, y, dx, dy, spr, dmg, w
newshot:	; find free shot -> IY, carry if none
	ld iy,SHOTS
	ld b,NSHOT
.l:	ld a,(iy+0)
	or a
	ret z
	ld de,8
	add iy,de
	djnz .l
	scf
	ret
mkshot:	; A=spr, B=x, C=y, D=dx, E=dy, H=dmg, L=type
	push af
	push hl
	push bc
	push de
	call newshot
	pop de
	pop bc
	pop hl
	jr c,.no
	pop af
	ld (iy+0),l
	ld (iy+1),b
	ld (iy+2),c
	ld (iy+3),d
	ld (iy+4),e
	ld (iy+5),a
	ld (iy+6),h
	ret
.no:	pop af
	ret

fire_normal:
	; limit: count normal shots
	ld ix,SHOTS
	ld b,NSHOT
	ld c,0
.cn:	ld a,(ix+0)
	cp 1
	jr nz,$+3
	inc c
	ld de,8
	add ix,de
	djnz .cn
	ld a,c
	cp 3
	ret nc
	ld a,(px)
	add a,7
	ld b,a
	ld a,(py)
	add a,2
	ld c,a
	ld d,5
	ld e,0
	ld h,1
	ld l,1
	ld a,SP_SHOT
	call mkshot
	ld hl,sfx_shot
	call sfx
	; satellite shots
	ld a,(sats)
	or a
	jr z,.nsat
	ld a,(sx1)
	add a,4
	ld b,a
	ld a,(sy1)
	inc a
	ld c,a
	ld d,5
	ld e,0
	ld h,1
	ld l,1
	ld a,SP_SHOT
	call mkshot
	ld a,(sx2)
	add a,4
	ld b,a
	ld a,(sy2)
	inc a
	ld c,a
	ld d,5
	ld e,0
	ld h,1
	ld l,1
	ld a,SP_SHOT
	call mkshot
.nsat:	; pod shots
	ld a,(podst)
	or a
	ret z
	cp 3
	ret nc
	jp pod_fire

fire_beam:
	ld a,(charge)
	cp 44
	jr nc,.b3
	cp 28
	jr nc,.b2
	ld a,SP_BEAM1
	ld h,2
	ld e,1
	jr .go
.b2:	ld a,SP_BEAM2
	ld h,3
	ld e,2
	jr .go
.b3:	ld a,SP_BEAM3
	ld h,5
	ld e,3
.go:	push af
	push hl
	ld a,(px)
	add a,6
	ld b,a
	ld a,(py)
	add a,2
	sub e
	ld c,a
	pop hl
	ld l,7			; beam type (pierces)
	ld d,4
	ld e,0
	pop af
	call mkshot
	ld a,(charge)
	cp 28
	ld hl,sfx_beam
	jp nc,sfx
	ld hl,sfx_beam1
	jp sfx

upd_shots:
	ld iy,SHOTS
	ld b,NSHOT
.l:	push bc
	ld a,(iy+0)
	or a
	jr z,.nx
	ld a,(iy+1)
	add a,(iy+3)
	ld (iy+1),a
	cp 168
	jr nc,.kill
	cp 16
	jr c,.kill
	ld a,(iy+2)
	add a,(iy+4)
	ld (iy+2),a
	cp 16
	jr c,.kill
	cp 16+PFH
	jr nc,.kill
	; terrain (beams pierce terrain too? no - stopped)
	ld a,(iy+1)
	sub 32
	jr c,.nx
	cp 128
	jr nc,.nx
	ld b,a
	ld a,(iy+2)
	sub 16
	ld c,a
	call solid
	jr z,.nx
	ld a,(iy+0)
	cp 7
	jr z,.nx		; beams cut through scenery
.kill:	ld (iy+0),0
.nx:	ld de,8
	add iy,de
	pop bc
	djnz .l
	ret

; ---- pod -----------------------------------------------------------
upd_pod:
	ld a,(frame)
	and 4
	ld a,SP_POD0
	jr z,$+4
	ld a,SP_POD1
	ld (podfr),a
	ld a,(pstate)
	or a
	ret nz
	; pod key
	ld a,(inpedge)
	bit 5,a
	jr z,.nk
	ld a,(podst)
	or a
	jr z,.nk
	cp 3
	jr nc,.recall
	; launch
	ld b,3			; outward
	cp 1
	jr z,$+4
	ld b,4			; back-launch state 4? use 3 with dir
	ld a,3
	ld (podst),a
	ld a,b
	ld (poddir),a
	ld hl,sfx_pod
	call sfx
	jr .nk
.recall: ld a,5
	ld (podst),a
.nk:	ld a,(podst)
	cp 1
	jr z,.front
	cp 2
	jr z,.back
	cp 3
	jr z,.out
	cp 4
	jr z,.float
	cp 5
	jr z,.ret
	ret
.front:	ld a,(px)
	add a,8
	ld (podx),a
	ld a,(py)
	ld (pody),a
	ret
.back:	ld a,(px)
	sub 4
	ld (podx),a
	ld a,(py)
	ld (pody),a
	ret
.out:	ld a,(poddir)
	cp 3
	ld a,(podx)
	jr nz,.ol
	add a,3
	ld (podx),a
	cp 32+108
	jr nc,.stop
	jr .chk
.ol:	sub 3
	ld (podx),a
	cp 32+4
	jr c,.stop
.chk:	call podsolid
	ret z
.stop:	ld a,4
	ld (podst),a
	ret
.float: ; drift toward the player's height
	ld a,(frame)
	and 1
	ret nz
	ld a,(py)
	ld hl,pody
	cp (hl)
	ret z
	jr c,.up
	inc (hl)
	ret
.up:	dec (hl)
	ret
.ret:	; fly toward ship, attach on contact
	ld a,(px)
	ld hl,podx
	ld b,(hl)
	sub b			; px - podx
	jr z,.ry
	jp p,.rr
	cp -6
	jr nc,.near
	dec (hl)
	dec (hl)
	jr .ry
.rr:	cp 6
	jr c,.near
	inc (hl)
	inc (hl)
.ry:	ld a,(py)
	ld hl,pody
	cp (hl)
	jr z,.near0
	jr c,.ru
	inc (hl)
	inc (hl)
	ld a,(py)
	cp (hl)
	ret nc
	ld (hl),a
	ret
.ru:	dec (hl)
	dec (hl)
	ld a,(py)
	cp (hl)
	ret c
	ld (hl),a
	ret
.near0:	ld a,(px)
	ld hl,podx
	sub (hl)
	jp p,$+5
	neg
	cp 9
	ret nc
.near:	ld a,(py)
	ld hl,pody
	sub (hl)
	jp p,$+5
	neg
	cp 5
	ret nc
	; attach front if pod is ahead of ship
	ld a,(podx)
	ld hl,px
	cp (hl)
	ld a,1
	jr nc,$+4
	ld a,2
	ld (podst),a
	ld hl,sfx_podback
	jp sfx
poddir	db 3

podsolid: ; NZ if pod touches terrain
	ld a,(podx)
	sub 32-2
	ld b,a
	ld a,(pody)
	sub 16-2
	ld c,a
	jp solid

pod_fire:
	ld a,(podw)
	ld (pf_w),a
	ld a,(podst)
	cp 2
	ld d,5
	ld a,(podx)
	add a,4
	jr nz,$+6
	ld d,-5
	sub 8
	ld b,a
	ld a,(pody)
	add a,1
	ld c,a
	ld a,d
	ld (pf_dx),a
	ld a,(pf_w)
	or a
	jr z,.plain
	cp 1
	jr z,.red
	cp 2
	jr z,.blue
	; yellow: straight + up + down
	call .straight
	ld a,SP_CROSS
	ld d,0
	ld e,-4
	ld h,1
	ld l,2
	call mkshot
	ld a,SP_CROSS
	ld d,0
	ld e,4
	ld h,1
	ld l,2
	jp mkshot
.plain:
.straight:
	ld a,(pf_dx)
	ld d,a
	ld e,0
	ld h,1
	ld l,2
	ld a,SP_SHOT
	jp mkshot
.red:	call .straight
	ld a,(pf_dx)
	sra a
	ld d,a
	ld e,-2
	ld h,1
	ld l,2
	ld a,SP_SPRD
	call mkshot
	ld a,(pf_dx)
	sra a
	ld d,a
	ld e,2
	ld h,1
	ld l,2
	ld a,SP_SPRD
	jp mkshot
.blue:	ld a,(pf_dx)
	add a,a
	sra a
	ld d,7
	bit 7,a
	jr z,$+4
	ld d,-7
	ld e,0
	ld h,2
	ld l,2
	ld a,SP_LANCE
	jp mkshot
pf_w	db 0
pf_dx	db 0

; ---- enemy bullets ---------------------------------------------------
; record: act, xf, x, yf, y, dx, dy, fr
newbul:	ld iy,BULS
	ld b,NBUL
	ld a,(thin)		; thinning: fewer enemy bullets at once
	or a
	jr z,.l
	ld b,NBUL_THIN
.l:	ld a,(iy+0)
	or a
	ret z
	ld de,8
	add iy,de
	djnz .l
	scf
	ret
; fire bullet from B,C (offset coords) in direction A (0..15)
firedir:
	push hl
	ld hl,0
	ld (lastbul),hl		; (set below if a bullet is fired)
	pop hl
	; thinning (Microbee): every third enemy bullet is not fired
	push af
	ld a,(thin)
	or a
	jr z,.fire
	ld a,(thinb)
	inc a
	cp 3
	jr c,$+3
	xor a
	ld (thinb),a
	or a
	jr nz,.fire
	pop af
	xor a
	ld (bulslow),a
	ret
.fire:
	push bc
	call newbul
	pop bc
	jr c,.no
	ld (iy+0),1
	ld (lastbul),iy
	ld (iy+1),0
	ld (iy+2),b
	ld (iy+3),0
	ld (iy+4),c
	pop af
	and 15
	add a,a
	ld e,a
	ld d,0
	ld hl,dirtab
	add hl,de
	ld a,(hl)
	call bslow
	ld (iy+5),a
	inc hl
	ld a,(hl)
	call bslow
	ld (iy+6),a
	xor a
	ld (bulslow),a
	ret
.no:	xor a
	ld (bulslow),a
	pop af
	ret
bslow:	; all enemy bullets fly at ~5/8 of the table speed...
	ld c,a
	ld a,(bulslow)
	or a
	jr z,.n
	ld a,(thin)
	or a
	jr z,.n
	ld a,c			; ...except turret bullets when thinning
	sra a			; (Microbee): 5/4, so they leave the
	sra a			; turret instead of scrolling with it
	add a,c
	ret
.n:	ld a,c
	sra a
	ld c,a
	sra a
	sra a
	add a,c
	ret
bulslow	db 0			; 1 while a turret fires
lastbul	dw 0			; the bullet firedir fired last (0 = none)
; aimed bullet from B,C toward the player
fireaim:
	ld a,(pstate)
	or a
	ret nz
	push bc
	call aimdir
	pop bc
	jp firedir
; direction index 0..15 from (B,C) toward player centre
aimdir:	ld a,(px)
	add a,4
	srl a
	srl b
	sub b
	ld d,a			; dx/2
	ld a,(py)
	add a,2
	srl a
	srl c
	sub c
	ld e,a			; dy/2
	ld (aim_sx),de
	; abs
	ld a,d
	bit 7,a
	jr z,$+4
	neg
	ld b,a			; ax
	ld a,e
	bit 7,a
	jr z,$+4
	neg
	ld c,a			; ay
	; k by ratio
	ld h,0
	ld l,c
	push hl
	add hl,hl
	add hl,hl
	pop de
	push de
	add hl,de		; ay*5
	ld e,b
	ld d,0
	or a
	sbc hl,de
	pop de
	ld a,0
	jr c,.got		; ay*5 < ax
	; ay*3 < ax*2 ?
	ld h,0
	ld l,c
	add hl,hl
	add hl,de		; ay*3 (de=ay)
	push hl
	ld l,b
	ld h,0
	add hl,hl		; ax*2
	ex de,hl
	pop hl
	or a
	sbc hl,de
	ld a,1
	jr c,.got
	; ay*2 < ax*3
	ld l,c
	ld h,0
	add hl,hl
	push hl
	ld l,b
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,de		; ax*3
	ex de,hl
	pop hl
	or a
	sbc hl,de
	ld a,2
	jr c,.got
	; ay < ax*5
	ld l,b
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,hl
	add hl,de
	ex de,hl
	ld l,c
	ld h,0
	or a
	sbc hl,de
	ld a,3
	jr c,.got
	ld a,4
.got:	ld c,a			; k
	ld a,(aim_sx)		; dx (E? no: aim_sx holds E=dy low, D=dx high)
	ld a,(aim_sx+1)		; dx
	bit 7,a
	jr nz,.xneg
	ld a,(aim_sx)		; dy
	bit 7,a
	ld a,c
	ret z			; k
	neg
	and 15
	ret
.xneg:	ld a,(aim_sx)
	bit 7,a
	ld a,8
	jr nz,.both
	sub c
	ret
.both:	add a,c
	and 15
	ret
aim_sx	dw 0

upd_bullets:
	ld iy,BULS
	ld b,NBUL
.l:	ld a,(iy+0)
	or a
	jr z,.nx
	; x
	ld a,(iy+5)
	add a,(iy+1)
	ld c,a
	and 15
	ld (iy+1),a
	ld a,c
	sra a
	sra a
	sra a
	sra a
	add a,(iy+2)
	ld (iy+2),a
	cp 20
	jr c,.k
	cp 164
	jr nc,.k
	ld a,(iy+6)
	add a,(iy+3)
	ld c,a
	and 15
	ld (iy+3),a
	ld a,c
	sra a
	sra a
	sra a
	sra a
	add a,(iy+4)
	ld (iy+4),a
	cp 14
	jr c,.k
	cp 16+PFH
	jr c,.nx
.k:	ld (iy+0),0
.nx:	ld de,8
	add iy,de
	djnz .l
	ret

; ---------------------------------------------------------------------
;  collisions
; ---------------------------------------------------------------------
; box overlap: (B,C,D,E)=(x,y,w,h) A-box vs (H,L, xw, yh in hit2) ...
collide:
	; ---- shots vs enemies
	ld iy,SHOTS
	ld b,NSHOT
.sl:	push bc
	ld a,(iy+0)
	or a
	jp z,.snx
	; shot box
	ld a,(iy+5)
	call sprsz		; D=w E=h
	ld a,(iy+1)
	ld (cb_x),a
	ld a,(iy+2)
	ld (cb_y),a
	ld a,d
	ld (cb_w),a
	ld a,e
	ld (cb_h),a
	ld ix,ENTS
	ld b,NENT
.el:	push bc
	ld a,(ix+E_TYPE)
	or a
	jr z,.enx
	bit 1,(ix+E_FL)		; invulnerable/pass
	jr nz,.enx
	; quick x reject
	ld a,(ix+E_X)
	sub (iy+1)
	add a,24
	cp 40
	jr nc,.enx
	call cb_vs_ent
	jr nc,.enx
	; hit!
	ld a,(ix+E_TYPE)
	cp T_BORB
	jr z,.absorb
	cp T_BOSS
	jr nz,.dmg
	call boss_hit
	cp 2
	jr z,.dmg
	or a
	jr z,.enx
	ld (sbody),a		; armour hit: absorb only if nothing else is hit
	ld a,(frame)
	and 3
	jr nz,.enx
	push iy
	ld hl,sfx_clank
	call sfx
	pop iy
	jr .enx
.dmg:	ld a,(iy+6)
	call hit_ent
	ld a,(iy+0)
	cp 7
	jr z,.enx		; beam continues
.absorb: ld a,(iy+0)
	cp 7
	jr z,.enx
	ld (iy+0),0
	pop bc
	jr .snx
.enx:	ld de,ENTSZ
	add ix,de
	pop bc
	djnz .el
	ld a,(sbody)
	or a
	jr z,.snx
	xor a
	ld (sbody),a
	ld a,(iy+0)
	cp 7
	jr z,.snx		; the charged beam ploughs on
	ld (iy+0),0
.snx:	xor a
	ld (sbody),a
	ld de,8
	add iy,de
	pop bc
	dec b
	jp nz,.sl
	call vschk
	; ---- pod vs enemies & bullets
	ld a,(podst)
	or a
	jr z,.nopod
	ld a,(podx)
	ld (cb_x),a
	ld a,(pody)
	ld (cb_y),a
	ld a,4
	ld (cb_w),a
	ld (cb_h),a
	ld ix,ENTS
	ld b,NENT
.pl:	push bc
	ld a,(ix+E_TYPE)
	or a
	jr z,.pnx
	bit 1,(ix+E_FL)
	jr nz,.pnx
	cp T_BOSS
	jr z,.pnx
	cp T_BORB
	jr z,.pnx
	call cb_vs_ent
	jr nc,.pnx
	ld a,(frame)
	and 1
	jr nz,.pnx
	ld a,1
	call hit_ent
.pnx:	ld de,ENTSZ
	add ix,de
	pop bc
	djnz .pl
	ld iy,BULS
	ld b,NBUL
.pb:	ld a,(iy+0)
	or a
	jr z,.pbn
	ld a,(iy+2)
	ld hl,podx
	sub (hl)
	add a,2
	cp 7
	jr nc,.pbn
	ld a,(iy+4)
	ld hl,pody
	sub (hl)
	add a,2
	cp 7
	jr nc,.pbn
	ld (iy+0),0
.pbn:	ld de,8
	add iy,de
	djnz .pb
.nopod:	call sats_block
	; ---- player vs enemies / bullets
	ld a,(pstate)
	or a
	ret nz
	ld a,(px)
	add a,2
	ld (cb_x),a
	ld a,(py)
	add a,2
	ld (cb_y),a
	ld a,4			; hit box: 4 wide (nose trimmed), 2 tall
	ld (cb_w),a
	ld a,2
	ld (cb_h),a
	ld ix,ENTS
	ld b,NENT
.ql:	push bc
	ld a,(ix+E_TYPE)
	or a
	jr z,.qnx
	bit 2,(ix+E_FL)
	jr nz,.qnx
	call cb_vs_ent
	jr nc,.qnx
	ld a,(ix+E_TYPE)
	cp T_BOSS
	jr nz,.nb
	call boss_hit
	or a
	jr z,.qnx
	jr .die
.nb:	cp T_CAPS
	jr nz,.die
	call pickup
	jr .qnx
.die:	ld a,(pinv)
	or a
	jr nz,.qnx
	pop bc
	jp kill_player
.qnx:	ld de,ENTSZ
	add ix,de
	pop bc
	djnz .ql
	ld a,(pinv)
	or a
	ret nz
	ld iy,BULS
	ld b,NBUL
.qb:	ld a,(iy+0)
	or a
	jr z,.qbn
	ld a,(iy+2)
	ld hl,cb_x
	sub (hl)
	inc a
	cp 5
	jr nc,.qbn
	ld a,(iy+4)
	ld hl,cb_y
	sub (hl)
	inc a
	cp 3
	jr nc,.qbn
	ld (iy+0),0
	jp kill_player
.qbn:	ld de,8
	add iy,de
	djnz .qb
	ret

cb_x	db 0
sbody	db 0
cb_y	db 0
cb_w	db 0
cb_h	db 0
; carry set if cb box overlaps entity IX box
cb_vs_ent:
	; x: cb_x < ex+ew  and ex < cb_x+cb_w
	ld a,(ix+E_X)
	add a,(ix+E_W)
	ld hl,cb_x
	cp (hl)
	jr c,.no
	jr z,.no
	ld a,(cb_w)
	add a,(hl)
	cp (ix+E_X)
	jr c,.no
	jr z,.no
	ld a,(ix+E_Y)
	add a,(ix+E_H)
	ld hl,cb_y
	cp (hl)
	jr c,.no
	jr z,.no
	ld a,(cb_h)
	add a,(hl)
	cp (ix+E_Y)
	jr c,.no
	jr z,.no
	scf
	ret
.no:	or a
	ret

; sprite A size in pixels -> D=w, E=h
sprsz:	ld l,a
	ld h,0
	add hl,hl
	ld de,spr_px
	add hl,de
	ld d,(hl)
	inc hl
	ld e,(hl)
	ret

pickup:	; capsule IX collected
	ld a,$ff
	ld (hudflag),a		; redraw the status bar indicators
	ld a,(ix+E_P1)
	or a
	jr z,.wpn
	cp 2
	jr nz,.spd
	ld a,(sats)		; helper satellites
	or a
	jr nz,.done
	inc a
	ld (sats),a
	ld a,(px)
	ld (sx1),a
	ld (sx2),a
	ld a,(py)
	ld (sy1),a
	ld (sy2),a
	jr .done
.spd:	ld a,(pspeed)
	cp 3
	jr nc,.done
	inc a
	ld (pspeed),a
	jr .done
.wpn:	ld a,(ix+E_FR)
	inc a
	ld (podw),a
	ld a,(podst)
	or a
	jr nz,.done
	ld a,1
	ld (podst),a
.done:	ld (ix+E_TYPE),0
	ld a,1
	call addscore
	ld hl,sfx_power
	jp sfx

; ---------------------------------------------------------------------
;  drawing
; ---------------------------------------------------------------------
draw_all:
	call draw_boss_body
	; enemies
	ld ix,ENTS
	ld b,NENT
.el:	push bc
	ld a,(ix+E_TYPE)
	or a
	jr z,.en
	bit 3,(ix+E_FL)		; flash: skip every other frame
	jr z,.dr
	res 3,(ix+E_FL)
	ld a,(frame)
	and 1
	jr nz,.en
.dr:	ld a,(ix+E_SPR)
	cp SP_BIG
	jr z,.en
	ld b,(ix+E_X)
	ld c,(ix+E_Y)
	call drawspr
.en:	ld de,ENTSZ
	add ix,de
	call vschk
	pop bc
	djnz .el
	; enemy bullets
	ld iy,BULS
	ld b,NBUL
.bl:	push bc
	ld a,(iy+0)
	or a
	jr z,.bn
	ld a,(frame)
	and 2
	ld a,(palB)
	jr z,$+5
	ld a,(palA)
	ld e,a
	ld d,0
	ld hl,fill4
	add hl,de
	ld d,(hl)
	ld b,(iy+2)
	ld c,(iy+4)
	call bul2
.bn:	ld de,8
	add iy,de
	pop bc
	djnz .bl
	call vschk
	; player shots
	ld iy,SHOTS
	ld b,NSHOT
.sl:	push bc
	ld a,(iy+0)
	or a
	jr z,.sn
	ld a,(iy+5)
	ld b,(iy+1)
	ld c,(iy+2)
	call drawspr
.sn:	ld de,8
	add iy,de
	pop bc
	djnz .sl
	; pod
	ld a,(podst)
	or a
	jr z,.np
	ld a,(podx)
	ld b,a
	ld a,(pody)
	ld c,a
	ld a,(podfr)
	call drawspr
.np:	; player
	ld a,(pstate)
	or a
	ret nz
	ld a,(pinv)
	and 2
	ret nz
	; helper satellites
	ld a,(sats)
	or a
	jr z,.nsd
	ld a,(frame)
	and 4
	ld a,SP_SAT0
	jr z,$+3
	inc a
	push af
	ld hl,sx1
	ld b,(hl)
	ld hl,sy1
	ld c,(hl)
	call drawspr
	pop af
	ld hl,sx2
	ld b,(hl)
	ld hl,sy2
	ld c,(hl)
	call drawspr
.nsd:	; exhaust behind the ship: boost when pushing right, short when braking
	ld a,(inp)
	ld b,SP_EXHN0
	bit 3,a
	jr z,$+4
	ld b,SP_EXHB0
	bit 2,a
	jr z,$+4
	ld b,SP_EXHS0
	ld a,(frame)
	and 2
	jr z,$+3
	inc b
	ld a,b
	ld hl,px
	ld b,(hl)
	dec b
	dec b
	dec b
	dec b
	ld hl,py
	ld c,(hl)
	inc c
	call drawspr
	; ship body: bank frame -2..+2
	ld a,(pbank)
	add a,SP_SHIPU2+2
	ld hl,px
	ld b,(hl)
	ld hl,py
	ld c,(hl)
	dec c
	jp drawspr

; ---- helper satellites ride above and below the ship, easing after it
upd_sats:
	ld a,(sats)
	or a
	ret z
	ld a,(px)
	add a,2
	ld b,a
	ld a,(py)
	sub 6
	ld c,a
	ld hl,sx1
	call .ease
	ld a,(px)
	add a,2
	ld b,a
	ld a,(py)
	add a,8
	ld c,a
	ld hl,sx2
.ease:	; (HL)=x, (HL+1)=y move toward B,C by up to 2 px
	ld a,(hl)
	call .step
	ld (hl),a
	inc hl
	ld b,c
	ld a,(hl)
	call .step
	ld (hl),a
	ret
.step:	cp b
	ret z
	jr c,.up
	dec a
	cp b
	ret z
	dec a
	cp b
	ret nc
	ld a,b
	ret
.up:	inc a
	cp b
	ret z
	inc a
	cp b
	ret c
	ld a,b
	ret

sats_block:	; enemy bullets that touch a satellite are absorbed
	ld a,(sats)
	or a
	ret z
	ld iy,BULS
	ld b,NBUL
.l:	ld a,(iy+0)
	or a
	jr z,.n
	ld hl,sx1
	call .t
	jr c,.k
	ld hl,sx2
	call .t
	jr nc,.n
.k:	ld (iy+0),0
.n:	ld de,8
	add iy,de
	djnz .l
	ret
.t:	ld a,(iy+2)
	sub (hl)
	add a,1
	cp 6
	ret nc
	inc hl
	ld a,(iy+4)
	sub (hl)
	add a,1
	cp 5
	ret
