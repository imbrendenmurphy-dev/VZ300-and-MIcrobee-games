;=====================================================================
; HOPPY 2 - gameplay
;=====================================================================
FS_PLAY	equ 0
FS_DYING equ 1
FS_WAIT	equ 2
FS_CLEAR equ 3
FS_INTRO equ 4

D_SQUASH equ 0
D_DROWN	equ 1
D_CHOMP	equ 2
D_TIME	equ 3

LF_FLY	equ 1
LF_HOPPINA equ 2
LF_SNAKE equ 4
LF_BAYCROC equ 8
LF_PICK	equ 16
LF_SNAIL equ 32

BAYX:	db 12,36,60,84,108	; frog x (left) for each bay

;---------------------------------------------------------------------
; new game
;---------------------------------------------------------------------
game_new:
	xor a
	ld (score),a
	ld (score+1),a
	ld (score+2),a
	ld (level),a
	ld (lap),a
	ld (snails),a
	ld (shield),a
	ld a,4
	ld (lives),a
	ld (spdmul),a
	ld a,$02		; next extra life at 20000 (BCD hi byte)
	ld (nextlife),a
	IFDEF HITEST
	ld a,$60
	ld (score+1),a
	xor a
	ld (lives),a
	ENDIF
	ld a,3
	ld (continues),a
	ret

;---------------------------------------------------------------------
; load level (level var) - builds all lanes
;---------------------------------------------------------------------
level_load:
	call heap_reset
	xor a
	ld (n_anim),a
	ld (n_ent),a
	ld (slowmo),a
	ld (x2time),a
	ld (deaths_lvl),a
	ld (flies_lvl),a
	ld (bays_order),a
	ld hl,bays
	ld b,5
.cb:	ld (hl),0
	inc hl
	djnz .cb
	call parts_clear
	IFDEF TESTCLEAR
	ld hl,bays+1
	ld (hl),1
	inc hl
	ld (hl),1
	inc hl
	ld (hl),1
	inc hl
	ld (hl),1
	ENDIF
	ld a,(level)
	add a,a
	ld hl,level_tab
	call addhla
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld (lvl_ptr),hl
	ld a,(hl)
	ld (lvl_css),a
	inc hl
	ld a,(hl)
	ld (lvl_fpu),a
	inc hl
	ld a,(hl)
	ld (lvl_flags),a
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (lvl_name),de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (lvl_intro),de
	; lanes
	xor a
	ld (cur_lane),a
.ll:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,d
	or e
	jr z,.ld
	push hl
	push de
	ld a,(cur_lane)
	call lane_ptr
	pop hl
	call build_lane
	ld a,(ix+L_SPEC)
	cp 1
	jr nz,.nb
	call rand
	and 63
	add a,60
	ld (ix+L_BT),a
.nb:	pop hl
	ld a,(cur_lane)
	inc a
	ld (cur_lane),a
	jr .ll
.ld:	ld a,(cur_lane)
	ld (nlanes),a
	ld b,a
	add a,a
	add a,b
	add a,a			; *6
	ld (board_h),a
	sub 58
	ld (cam_max),a
	; snake
	xor a
	ld (snake_on),a
	ld a,(lvl_flags)
	and LF_SNAKE
	jr z,.ns
	call snake_init
.ns:	call bfly_init
	ld a,150
	ld (fly_t),a
	ld a,200
	ld (bc_t),a
	ld a,250
	ld (pick_t),a
	ld a,255
	ld (hop_t),a
	xor a
	ld (hop_on),a
	ld (hop_carry),a
	IFDEF TESTCLEAR
	call home_redraw
	ENDIF
	ret

;---------------------------------------------------------------------
; frog spawn
;---------------------------------------------------------------------
frog_spawn:
	ld a,(nlanes)
	dec a
	ld (fbest),a
	ld b,a
	add a,a
	add a,b
	add a,a
	ld (fy),a
	ld a,60
	ld (fx+1),a
	xor a
	ld (fx),a
	ld (fhop),a
	ld (fq),a
	ld (fdir),a
	ld (hop_carry),a
	ld a,FS_PLAY
	ld (fstate),a
	ld a,40
	ld (finv),a
	ld a,52
	ld (tbar),a
	ld a,(lvl_fpu)
	ld (tsub),a
	ld a,1
	ld (hud_dirty),a
	ret

;---------------------------------------------------------------------
; lane under frog centre -> A (and frow_c)
;---------------------------------------------------------------------
frog_row:
	ld a,(fy)
	add a,3
	ld c,0
.d:	sub 6
	jr c,.e
	inc c
	jr .d
.e:	ld a,c
	ld (frow_c),a
	ret

; sample collision: IX lane, A = screen x -> A = col value
col_at:
	add a,(ix+L_SI)
	and 127
	ld l,(ix+L_COL)
	ld h,(ix+L_COL+1)
	call addhla
	ld a,(hl)
	ret

;---------------------------------------------------------------------
; per-tick game update while playing
;---------------------------------------------------------------------
game_update2:
	call bfly_tick
	call lanes_move
	call anim_tick
	call burst_tick
	call home_tick
	call snake_tick
	call ent_tick
	call parts_tick
	call pop_tick
	ld a,(hud_dirty)
	or a
	ret z
	cp 3
	jr nz,.h2
	call hud_score
	jr .hd
.h2:	cp 2
	jr nz,.hf
	call hud_bar
	jr .hd
.hf:	call hud_draw
.hd:	xor a
	ld (hud_dirty),a
	ld a,1
	ld (hud_copy),a
	ret
game_update:
	ld a,(slowmo)
	or a
	jr z,.s1
	dec a
	ld (slowmo),a
	jr nz,.s1
	ld a,1
	ld (hud_dirty),a
.s1:	ld a,(x2time)
	or a
	jr z,.s2
	dec a
	ld (x2time),a
	jr nz,.s2
	ld a,1
	ld (hud_dirty),a
.s2:	ld a,(fstate)
	cp FS_PLAY
	jp z,frog_play
	cp FS_DYING
	jp z,frog_dying
	ret

;---------------------------------------------------------------------
frog_play:
	; power use: fire = snail slow-mo
	ld a,(keys_acc)
	and K_FI
	jr z,.nf
	ld a,(snails)
	or a
	jr z,.nf
	ld a,(slowmo)
	or a
	jr nz,.nf
	ld a,(snails)
	dec a
	ld (snails),a
	ld a,100
	ld (slowmo),a
	ld a,1
	ld (hud_dirty),a
	ld hl,sfx_slow
	ld a,4
	call sfx_play
.nf:	; timer
	ld a,(slowmo)
	or a
	jr nz,.tdone
	ld hl,tsub
	dec (hl)
	jr nz,.tdone
	ld a,(lvl_fpu)
	ld (hl),a
	ld hl,tbar
	dec (hl)
	ld a,(hud_dirty)
	or a
	jr nz,$+7
	ld a,2
	ld (hud_dirty),a
	ld a,(hl)
	or a
	jp z,die_time
	cp 10
	jr nc,.tdone
	ld hl,sfx_tick
	ld a,1
	call sfx_play
.tdone:	; invulnerability
	ld a,(finv)
	or a
	jr z,.ni
	dec a
	ld (finv),a
.ni:	; hop in progress?
	ld a,(fhop)
	or a
	jr nz,.hopping
	; queued or new input
	ld a,(fq)
	or a
	jr nz,.useq
	ld a,(keys)
	and K_UP|K_DN|K_LT|K_RT
	jr z,.idle
	ld c,a
	ld a,(hold_t)
	or a
	jr z,.gok
	dec a
	ld (hold_t),a
	ld a,(keys_acc)
	and K_UP|K_DN|K_LT|K_RT
	jr z,.idle
	ld c,a
.gok:	ld a,c
	jr .start
.useq:	ld c,a
	xor a
	ld (fq),a
	ld a,c
.start:	call hop_start
	jr .ride
.idle:	jr .ride
.hopping:
	; buffer next move
	ld a,(keys_acc)
	and K_UP|K_DN|K_LT|K_RT
	jr z,.nb
	ld (fq),a
.nb:	call hop_step
.ride:	call frog_row
	call lane_ptr
	ld a,(ix+L_KIND)
	cp K_WATER
	jr nz,.nr
	ld a,(finv_float)
	or a
	jr nz,.nr
	ld hl,(fx)
	ld e,(ix+L_DV)
	ld d,(ix+L_DV+1)
	or a
	sbc hl,de
	ld (fx),hl
.nr:	jp frog_collide

; hop_start: A = direction bits
hop_start:
	ld c,a
	ld a,2
	ld (hold_t),a
	bit 0,c
	jr nz,.up
	bit 1,c
	jr nz,.dn
	bit 2,c
	jr nz,.lt
	; right
	ld a,1
	ld (fdir),a
	ld a,(fx+1)
	cp 113
	jr c,.go
	cp 120
	jp nc,bonk
	jr .go
.lt:	ld a,3
	ld (fdir),a
	ld a,(fx+1)
	cp 1
	jp c,bonk
	jr .go
.dn:	ld a,2
	ld (fdir),a
	call frog_row
	inc a
	ld hl,nlanes
	cp (hl)
	jp nc,bonk
	jr .go
.up:	xor a
	ld (fdir),a
	call frog_row
	dec a
	jr nz,.go
	; into home row: bay check
	ld a,(fx+1)
	add a,4
	ld c,a
	ld hl,BAYX
	ld b,0
.bl:	ld a,(hl)
	add a,4
	sub c
	jr nc,$+4
	neg
	cp 7
	jr c,.bay
	inc hl
	inc b
	ld a,b
	cp 5
	jr nz,.bl
	jp bonk
.bay:	ld a,b
	ld (fbay),a
	ld hl,bays
	call addhla
	ld a,(hl)
	cp 1
	jp z,bonk
	; snap x
	ld hl,BAYX
	ld a,b
	call addhla
	ld a,(hl)
	ld (fx+1),a
	xor a
	ld (fx),a
.go:	ld a,3
	ld (fhop),a
	ld hl,sfx_hop
	ld a,1
	call sfx_play
	; dust puff at the feet
	ld a,(fx+1)
	add a,2
	ld c,a
	ld a,(fy)
	add a,5
	ld b,a
	ld e,1
	ld d,$f8
	call part_add_xy
	ld a,(fx+1)
	add a,5
	ld c,a
	ld a,(fy)
	add a,5
	ld b,a
	ld e,1
	ld d,$f8
	jp part_add_xy

bonk:	xor a
	ld (fhop),a
	ld hl,sfx_bonk
	ld a,2
	jp sfx_play

hopdx:	db 2,3,3
hop_step:
	ld a,(fhop)
	dec a
	ld (fhop),a
	ld hl,hopdx
	call addhla
	ld c,(hl)
	ld a,(fdir)
	or a
	jr z,.u
	cp 2
	jr z,.d
	cp 1
	jr z,.r
	ld a,(fx+1)
	sub c
	jr nc,$+3
	xor a
	ld (fx+1),a
	jr .end
.r:	ld a,(fx+1)
	add a,c
	cp 121
	jr c,$+4
	ld a,120
	ld (fx+1),a
	jr .end
.u:	ld a,(fy)
	sub 2
	ld (fy),a
	jr .end
.d:	ld a,(fy)
	add a,2
	ld (fy),a
.end:	ld a,(fhop)
	or a
	ret nz
	; landed
	ld a,(fdir)
	or a
	ret nz
	call frog_row
	or a
	jp z,frog_home
	ld hl,fbest
	cp (hl)
	ret nc
	ld (hl),a
	ld hl,$0010
	jp add_score_m

;---------------------------------------------------------------------
frog_collide:
	call frog_row
	call lane_ptr
	; edges
	ld a,(fx+1)
	cp 122
	jr c,.ine
	ld a,(ix+L_KIND)
	cp K_WATER
	jp z,die_drown
	ld a,(fx+1)		; on land just clamp
	cp 200
	ld a,120
	jr c,$+3
	xor a
	ld (fx+1),a
.ine:	ld a,(ix+L_KIND)
	cp K_ROAD
	jr z,.road
	cp K_WATER
	jr z,.water
	; static: snake / pickups
	call snake_hit
	jp ent_collect
.road:	ld a,(finv)
	or a
	jp nz,ent_collect
	ld a,(fx+1)
	inc a
	call col_at
	cp C_DEAD
	jp z,die_squash
	ld a,(fx+1)
	add a,4
	call col_at
	cp C_DEAD
	jp z,die_squash
	ld a,(fx+1)
	add a,6
	call col_at
	cp C_DEAD
	jp z,die_squash
	jp ent_collect
.water:	ld a,(fdir)		; mid-air vertical hop: safe
	or a
	jr z,.vh
	cp 2
	jr nz,.wl
.vh:	ld a,(fhop)
	or a
	jp nz,ent_collect
.wl:	ld a,(finv_float)
	or a
	jr z,.wl2
	dec a
	ld (finv_float),a
	jp ent_collect
.wl2:	ld a,(fx+1)
	add a,3
	call col_at
	ld c,a
	ld a,(fx+1)
	add a,4
	call col_at
	cp C_DEAD
	jp z,die_chomp
	or c
	cp C_DEAD
	jp z,die_chomp
	and C_PLAT
	jp z,die_drown
	call hoppina_pick
	jp ent_collect

;---------------------------------------------------------------------
; deaths
;---------------------------------------------------------------------
die_squash:
	ld a,D_SQUASH
	jr die
die_drown:
	ld a,D_DROWN
	jr die
die_chomp:
	ld a,D_CHOMP
	jr die
die_time:
	ld a,D_TIME
die:	ld c,a
	; shield saves (not time)
	cp D_TIME
	jr z,.real
	ld a,(shield)
	or a
	jr z,.real
	xor a
	ld (shield),a
	ld a,1
	ld (hud_dirty),a
	ld a,25
	ld (finv),a
	ld a,c
	cp D_SQUASH
	jr z,.pop
	ld a,25
	ld (finv_float),a
.pop:	ld hl,sfx_pop
	ld a,5
	call sfx_play
	ld a,8
	ld c,2
	jp burst_at_frog
.real:	ld a,c
	ld (fdeath),a
	ld a,FS_DYING
	ld (fstate),a
	ld a,30
	ld (ftimer),a
	ld hl,deaths_lvl
	inc (hl)
	xor a
	ld (hop_carry),a
	ld (finv),a
	ld (fhop),a
	ld (fq),a
	ld a,c
	cp D_DROWN
	jr z,.dr
	cp D_TIME
	jr z,.tm
	ld hl,sfx_squash
	ld a,6
	call sfx_play
	ld a,8
	ld c,3
	call burst_at_frog
	ld a,4
	ld c,1
	jp burst_at_frog
.dr:	ld hl,sfx_splash
	ld a,6
	call sfx_play
	ld a,10
	ld c,0
	jp burst_at_frog
.tm:	ld hl,sfx_faint
	ld a,6
	jp sfx_play

frog_dying:
	ld hl,ftimer
	dec (hl)
	ret nz
	ld a,(lives)
	or a
	jr z,.over
	IFNDEF AUTOPLAY
	IFNDEF INFLIVES
	dec a
	ENDIF
	ENDIF
	ld (lives),a
	call frog_spawn
	ret
.over:	ld a,FS_WAIT
	ld (fstate),a
	ld a,1
	ld (gameover),a
	ret

;---------------------------------------------------------------------
; home bays
;---------------------------------------------------------------------
frog_home:
	ld a,(fbay)
	ld hl,bays
	call addhla
	ld a,(hl)
	cp 4
	jp z,die_chomp
	push af
	ld (hl),1
	pop af
	cp 2
	jr nz,.nf
	; fly bonus
	ld hl,flies_lvl
	inc (hl)
	ld hl,$0200
	call add_score_m
	ld hl,txt_200
	call popup_frog
	ld hl,sfx_gulp
	ld a,5
	call sfx_play
.nf:	; bay order bonus tracking: count bays filled in left-to-right order
	ld a,(fbay)
	ld hl,bays_order
	cp (hl)
	jr nz,.no
	inc (hl)
	jr .o2
.no:	ld (hl),$80		; broken
.o2:	; base + time bonus
	ld hl,$0050
	call add_score_m
	ld a,(tbar)
	ld b,a
.tb:	push bc
	ld hl,$0010
	call add_score_m
	pop bc
	djnz .tb
	; hoppina
	ld a,(hop_carry)
	or a
	jr z,.nh
	xor a
	ld (hop_carry),a
	ld (hop_on),a
	ld hl,$1000
	call add_score_m
	ld hl,txt_love
	call popup_frog
	ld a,16
	ld c,3
	call burst_at_frog
.nh:	ld a,12
	ld c,1
	call burst_at_frog
	ld hl,sfx_home
	ld a,5
	call sfx_play
	call home_redraw
	; all five?
	ld hl,bays
	ld b,5
.ck:	ld a,(hl)
	cp 1
	jr nz,.notall
	inc hl
	djnz .ck
	ld a,FS_CLEAR
	ld (fstate),a
	ret
.notall:
	jp frog_spawn

; redraw home strip (bays with frogs)
home_redraw:
	xor a
	call lane_inval
	xor a
	call lane_ptr
	ld l,(ix+L_BASE)
	ld h,(ix+L_BASE+1)
	push hl
	ex de,hl
	ld hl,home_bg+2
	ld bc,192
	ldir
	pop hl
	ld (ds_base),hl
	ld a,(clip_top)
	push af
	ld a,(clip_bot)
	push af
	xor a
	ld (clip_top),a
	ld a,5
	ld (clip_bot),a
	ld b,0
.l:	push bc
	ld hl,bays
	ld a,b
	call addhla
	ld a,(hl)
	cp 1
	jr nz,.n
	ld hl,BAYX
	ld a,b
	call addhla
	ld c,(hl)
	ld b,0
	ld de,spr_fdn
	call draw_spr
.n:	pop bc
	inc b
	ld a,b
	cp 5
	jr nz,.l
	pop af
	ld (clip_bot),a
	pop af
	ld (clip_top),a
	ld hl,BUF
	ld (ds_base),hl
	ret

; bay events: flies and crocs
home_tick:
	ld a,(lvl_flags)
	and LF_FLY
	jr z,.nofly
	ld hl,fly_t
	dec (hl)
	jr nz,.nofly
	ld (hl),130
	; remove existing fly, place new
	ld hl,bays
	ld b,5
.rf:	ld a,(hl)
	cp 2
	jr nz,$+4
	ld (hl),0
	inc hl
	djnz .rf
	call rand
	and 7
	cp 5
	jr nc,.nofly
	ld hl,bays
	call addhla
	ld a,(hl)
	or a
	jr nz,.nofly
	ld (hl),2
.nofly:	ld a,(lvl_flags)
	and LF_BAYCROC
	ret z
	ld hl,bc_t
	dec (hl)
	ret nz
	; advance croc states
	ld hl,bays
	ld b,5
	ld c,0
.cs:	ld a,(hl)
	cp 3
	jr nz,.c4
	ld (hl),4
	ld c,1
	jr .cn
.c4:	cp 4
	jr nz,.cn
	ld (hl),0
	ld c,2
.cn:	inc hl
	djnz .cs
	ld a,c
	cp 1
	ld a,60
	jr z,.set
	; place new peek
	call rand
	and 7
	cp 5
	jr nc,.nc
	ld hl,bays
	call addhla
	ld a,(hl)
	or a
	jr nz,.nc
	ld (hl),3
	ld a,40
	jr .set
.nc:	ld a,90
.set:	ld (bc_t),a
	ret

;---------------------------------------------------------------------
; racer burst lanes: L_SPEC=1.  L_T: 0 cruise, 1 warn, 2 burst
;---------------------------------------------------------------------
burst_tick:
	ld a,(nlanes)
	ld b,a
	ld ix,lanes
	xor a
	ld (cur_lane),a
.l:	push bc
	ld a,(ix+L_SPEC)
	cp 1
	jr nz,.n
	dec (ix+L_BT)
	jr nz,.smoke
	ld a,(ix+L_T)
	inc a
	cp 3
	jr c,$+3
	xor a
	ld (ix+L_T),a
	ld c,a
	ld hl,.times
	call addhla
	ld a,(hl)
	ld (ix+L_BT),a
	ld a,c
	cp 1
	jr nz,.n
	ld hl,sfx_rev
	ld a,3
	call sfx_play
	jr .n
.smoke:	ld a,(ix+L_T)
	cp 1
	jr nz,.n
	ld a,(ix+L_BT)
	and 3
	jr nz,.n
	call racer_smoke
.n:	ld de,L_SIZE
	add ix,de
	ld hl,cur_lane
	inc (hl)
	pop bc
	djnz .l
	ret
.times:	db 120,30,30

; puff of smoke behind each racer in lane IX (cur_lane)
racer_smoke:
	ld l,(ix+L_DEF)
	ld h,(ix+L_DEF+1)
	ld de,5
	add hl,de
.o:	ld a,(hl)
	cp $ff
	ret z
	inc hl
	ld c,(hl)
	inc hl
	cp OT_RACER
	jr nz,.o
	push hl
	; screen x = x4*4 - SI (+ tail)
	ld a,c
	add a,a
	add a,a
	sub (ix+L_SI)
	bit 1,(ix+L_FLAGS)
	jr nz,.lf
	sub 1
	jr .xs
.lf:	add a,16
.xs:	and 127
	ld c,a
	ld a,(cur_lane)
	ld b,a
	add a,a
	add a,b
	add a,a
	add a,2
	ld b,a
	ld e,1
	ld d,$f0
	call part_add_xy
	pop hl
	jr .o

;---------------------------------------------------------------------
; snake on the median
;---------------------------------------------------------------------
snake_init:
	; find median lane: first static lane below row 0 with bg median
	ld b,1
.f:	ld a,b
	push bc
	call lane_ptr
	pop bc
	ld a,(ix+L_BG)
	cp BG_MEDIAN
	jr z,.got
	inc b
	ld a,(nlanes)
	cp b
	jr nz,.f
	ret
.got:	ld a,b
	ld (snake_row),a
	ld a,1
	ld (snake_on),a
	ld a,20
	ld (snake_x),a
	ld a,1
	ld (snake_dir),a
	ret
snake_tick:
	ld a,(snake_on)
	or a
	ret z
	ld hl,snake_an
	inc (hl)
	ld a,(hl)
	and 1
	ret nz
	ld a,(snake_dir)
	ld c,a
	ld a,(snake_x)
	add a,c
	ld (snake_x),a
	cp 4
	jr c,.flip
	cp 108
	ret c
.flip:	ld a,c
	neg
	ld (snake_dir),a
	ret
snake_hit:
	ld a,(snake_on)
	or a
	ret z
	ld a,(frow_c)
	ld hl,snake_row
	cp (hl)
	ret nz
	ld a,(finv)
	or a
	ret nz
	ld a,(fhop)
	or a
	ret nz
	ld a,(snake_x)
	add a,2
	ld c,a
	ld a,(fx+1)
	add a,4
	sub c
	ret c
	cp 12
	ret nc
	pop hl			; drop return (we die)
	jp die_chomp

;---------------------------------------------------------------------
; entities: pickups and Hoppina
; ent: type, lane, x(int), ride, life, pad*3   (8 bytes)
;---------------------------------------------------------------------
E_TYPE	equ 0
E_LANE	equ 1
E_X	equ 2
E_RIDE	equ 3
E_LIFE	equ 4
MAXENT	equ 4
ET_BUBBLE equ 1
ET_SNAIL equ 2
ET_STAR	equ 3
ET_HEART equ 4

ent_tick:
	; spawn pickups
	ld a,(lvl_flags)
	and LF_PICK
	jr z,.np
	ld hl,pick_t
	dec (hl)
	jr nz,.np
	ld (hl),220
	call pick_spawn
.np:	; hoppina spawn
	ld a,(lvl_flags)
	and LF_HOPPINA
	jr z,.nh
	ld a,(hop_on)
	or a
	jr nz,.nh
	ld hl,hop_t
	dec (hl)
	jr nz,.nh
	ld (hl),250
	call hoppina_spawn
.nh:	; age entities
	ld hl,ents
	ld b,MAXENT
.l:	ld a,(hl)
	or a
	jr z,.n
	push hl
	pop iy
	dec (iy+E_LIFE)
	jr nz,.ride
	ld (iy+E_TYPE),0
	jr .n
.ride:	ld a,(iy+E_RIDE)
	or a
	jr z,.n
	push hl
	push bc
	ld a,(iy+E_LANE)
	call lane_ptr
	ld a,(iy+E_X)
	sub (ix+L_DX)
	ld (iy+E_X),a
	pop bc
	pop hl
.n:	ld de,8
	add hl,de
	djnz .l
	; hoppina rides too
	ld a,(hop_on)
	or a
	ret z
	ld a,(hop_carry)
	or a
	ret nz
	ld hl,hop_life
	dec (hl)
	jr nz,.hl
	xor a
	ld (hop_on),a
	ret
.hl:	ld a,(hop_lane)
	call lane_ptr
	ld a,(hop_x)
	sub (ix+L_DX)
	ld (hop_x),a
	ret

; find a free entity slot -> IY (Z if none)
ent_free:
	ld iy,ents
	ld b,MAXENT
	ld de,8
.l:	ld a,(iy+0)
	or a
	jr z,.f
	add iy,de
	djnz .l
	xor a
	ret
.f:	or 1
	ret

pick_spawn:
	call ent_free
	ret z
	; type
	call rand
	and 15
	ld c,ET_BUBBLE
	cp 6
	jr c,.t
	ld c,ET_STAR
	cp 11
	jr c,.t
	ld c,ET_SNAIL
	ld a,(lvl_flags)
	and LF_SNAIL
	jr nz,.t2
	ld c,ET_STAR
.t2:	call rand
	and 7
	jr nz,.t
	ld c,ET_HEART
.t:	ld (iy+E_TYPE),c
	ld (iy+E_LIFE),250
	; lane: random 1..nlanes-2
.lr:	call rand
	and 31
	or a
	jr z,.lr
	ld c,a
	ld a,(nlanes)
	dec a
	cp c
	jr c,.lr
	jr z,.lr
	ld a,c
	ld (iy+E_LANE),a
	call lane_ptr
	ld a,(ix+L_KIND)
	cp K_WATER
	jr z,.wat
	ld (iy+E_RIDE),0
	call rand
	and 127
	cp 112
	jr c,$+4
	sub 64
	ld (iy+E_X),a
	ret
.wat:	; find a platform spot, ride with it
	ld (iy+E_RIDE),1
	ld b,40
.ws:	push bc
	call rand
	and 127
	cp 112
	jr c,$+4
	sub 64
	ld c,a
	add a,4
	call col_at
	pop bc
	cp C_PLAT
	jr z,.wok
	djnz .ws
	ld (iy+E_TYPE),0
	ret
.wok:	ld (iy+E_X),c
	ret

hoppina_spawn:
	; pick top water lane 1..5 that has logs; place on platform
	ld b,30
.t:	push bc
	call rand
	and 3
	inc a
	ld (hop_lane),a
	call lane_ptr
	ld a,(ix+L_KIND)
	cp K_WATER
	jr nz,.nx
	call rand
	and 63
	add a,20
	ld (hop_x),a
	add a,4
	call col_at
	cp C_PLAT
	jr nz,.nx
	pop bc
	ld a,1
	ld (hop_on),a
	ld a,255
	ld (hop_life),a
	ret
.nx:	pop bc
	djnz .t
	ret

hoppina_pick:
	ld a,(hop_on)
	or a
	ret z
	ld a,(hop_carry)
	or a
	ret nz
	ld a,(frow_c)
	ld hl,hop_lane
	cp (hl)
	ret nz
	ld a,(hop_x)
	ld c,a
	ld a,(fx+1)
	sub c
	jr nc,$+4
	neg
	cp 6
	ret nc
	ld a,1
	ld (hop_carry),a
	ld hl,sfx_kiss
	ld a,4
	call sfx_play
	ld a,10
	ld c,3
	jp burst_at_frog

; collect pickups at frog position
ent_collect:
	ld a,(fhop)
	or a
	ret nz
	ld iy,ents
	ld b,MAXENT
.l:	ld a,(iy+0)
	or a
	jr z,.n
	ld a,(frow_c)
	cp (iy+E_LANE)
	jr nz,.n
	ld a,(iy+E_X)
	ld c,a
	ld a,(fx+1)
	sub c
	jr nc,$+4
	neg
	cp 7
	jr nc,.n
	push bc
	call collect
	pop bc
.n:	ld de,8
	add iy,de
	djnz .l
	ret
collect:
	ld a,(iy+E_TYPE)
	ld (iy+E_TYPE),0
	cp ET_BUBBLE
	jr nz,.c2
	ld a,1
	ld (shield),a
	ld hl,txt_shield
	jr .done
.c2:	cp ET_SNAIL
	jr nz,.c3
	ld a,(snails)
	cp 3
	jr nc,.c2x
	inc a
	ld (snails),a
.c2x:
	ld hl,txt_snail
	jr .done
.c3:	cp ET_STAR
	jr nz,.c4
	ld a,250
	ld (x2time),a
	ld hl,txt_x2
	jr .done
.c4:	ld hl,lives
	inc (hl)
	ld hl,txt_1up
.done:	call popup_frog
	ld hl,$0100
	call add_score_m
	ld a,1
	ld (hud_dirty),a
	ld hl,sfx_pick
	ld a,4
	call sfx_play
	ld a,10
	ld c,1
	jp burst_at_frog

;---------------------------------------------------------------------
; score (BCD, 3 bytes big-endian: score = hi, mid, lo)
;---------------------------------------------------------------------
add_score_m:		; HL = BCD points (4 digits), doubled if x2 active
	ld a,(x2time)
	or a
	jr z,add_score
	push hl
	call add_score
	pop hl
add_score:
	ld a,(demo)
	cp 1
	ret z
	ld a,(score+2)
	add a,l
	daa
	ld (score+2),a
	ld a,(score+1)
	adc a,h
	daa
	ld (score+1),a
	ld a,(score)
	adc a,0
	daa
	ld (score),a
	ld a,(hud_dirty)
	cp 1
	jr z,.hd
	ld a,3
	ld (hud_dirty),a
.hd:
	; extra life every 20000
	ld a,(nextlife)
	ld c,a
	ld a,(score)
	cp c
	ret c
	ld a,c
	add a,2
	daa
	ld (nextlife),a
	ld hl,lives
	inc (hl)
	ld hl,sfx_1up
	ld a,7
	jp sfx_play

;---------------------------------------------------------------------
; HUD (rows 0..5 of BUF)
;---------------------------------------------------------------------
hud_draw:
	ld hl,BUF
	ld de,BUF+1
	ld bc,191
	ld (hl),$aa
	ldir
	ld hl,BUF
	ld (txt_base),hl
	ld a,1
	ld (txt_opq),a
	xor a
	ld (clip_top),a
	ld a,63
	ld (clip_bot),a
	call hud_score
	jr hud_rest
hud_score:
	ld hl,BUF
	ld (txt_base),hl
	ld a,1
	ld (txt_opq),a
	xor a
	ld (clip_top),a
	ld a,63
	ld (clip_bot),a
	ld a,$21		; yellow on blue
	call text_setcol
	; score digits
	ld hl,score
	ld de,numbuf
	ld b,3
.sd:	ld a,(hl)
	rrca
	rrca
	rrca
	rrca
	and 15
	add a,'0'
	ld (de),a
	inc de
	ld a,(hl)
	and 15
	add a,'0'
	ld (de),a
	inc de
	inc hl
	djnz .sd
	xor a
	ld (de),a
	ld hl,numbuf
	ld de,$0000
	jp text_at
hud_rest:
	; lives
	ld a,$23
	call text_setcol
	ld a,(lives)
	cp 5
	jr c,$+4
	ld a,4
	or a
	jr z,.nl
	ld b,a
	ld d,7
.lv:	push bc
	push de
	ld a,'#'
	ld e,0
	call text_char
	pop de
	pop bc
	inc d
	djnz .lv
.nl:	; powers
	ld a,(shield)
	or a
	jr z,.p1
	ld a,$21
	call text_setcol
	ld a,'@'
	ld de,$0b00
	call text_char
.p1:	ld a,(snails)
	or a
	jr z,.p2
	ld b,a
	ld a,(slowmo)
	or a
	ld a,$21
	jr z,$+4
	ld a,$23
	call text_setcol
	ld d,13
.sn:	push bc
	push de
	ld a,'$'
	ld e,0
	call text_char
	pop de
	pop bc
	inc d
	djnz .sn
.p2:	ld a,(x2time)
	or a
	jr z,.p3
	ld a,$23
	call text_setcol
	ld a,'%'
	ld de,$0c00
	call text_char
.p3:
hud_bar:	; time bar: cols 18..30 (52 px) rows 1..3
	ld hl,BUF+32+17
	ld de,BUF+32+18
	ld (hl),$aa
	ld bc,12
	ldir
	ld hl,BUF+64+17
	ld de,BUF+64+18
	ld (hl),$aa
	ld bc,12
	ldir
	ld hl,BUF+96+17
	ld de,BUF+96+18
	ld (hl),$aa
	ld bc,12
	ldir
	ld a,(tbar)
	ld c,a
	ld e,$55
	ld hl,partY
	cp 13
	jr nc,.tok
	ld e,$ff
	ld hl,partR
.tok:	ld (hb_tab),hl
	ld a,e
	ld (hb_full),a
	ld hl,BUF+32+17
	ld b,3
.trow:	push bc
	push hl
	ld a,c
	srl a
	srl a
	or a
	jr z,.tnf
	ld b,a
	ld a,(hb_full)
.tf:	ld (hl),a
	inc hl
	djnz .tf
.tnf:	ld a,c
	and 3
	jr z,.tdn
	dec a
	push hl
	ld hl,(hb_tab)
	call addhla
	ld a,(hl)
	pop hl
	ld (hl),a
.tdn:	pop hl
	ld de,32
	add hl,de
	pop bc
	djnz .trow
	ld a,(hud_dirty)
	cp 2
	ret z
	; level number
	ld a,$21
	call text_setcol
	ld a,(level)
	inc a
	ld l,a
	ld h,0
	call num5
	ld hl,numbuf+4
	ld de,$1f00
	call text_at
	ret

;---------------------------------------------------------------------
; particles: x.int, x.frac, y.int, y.frac, vx(s8 /16), vy(s8 /16), life, colour|grav<<7
;---------------------------------------------------------------------
MAXPART	equ 24
parts_clear:
	ld hl,parts
	ld de,parts+1
	ld bc,MAXPART*8-1
	ld (hl),0
	ldir
	ret

; burst_at_frog: A = count, C = colour
burst_at_frog:
	ld b,a
	ld a,(fx+1)
	add a,3
	ld (bx),a
	ld a,(fy)
	add a,2
	ld (by),a
.l:	push bc
	call rand
	and 63
	sub 32
	ld d,a			; vy
	call rand
	and 63
	sub 32
	ld e,a			; vx
	ld a,(bx)
	ld l,a
	ld a,(by)
	ld h,a
	ld a,c
	or $80
	ld c,a
	call part_add
	pop bc
	djnz .l
	ret

; part_add_xy: C = screen x, B = board y, E = colour, D = vy (vx random small)
part_add_xy:
	push bc
	push de
	call rand
	and 15
	sub 8
	ld (tmpvx),a
	pop de
	pop bc
	ld l,c
	ld h,b
	ld c,e
	ld a,(tmpvx)
	ld e,a
; part_add: L = x, H = board y, E = vx, D = vy, C = colour|grav
part_add:
	ld (pv_e),de
	push hl
	ld hl,parts+6
	ld b,MAXPART
	ld de,8
.f:	ld a,(hl)
	or a
	jr z,.got
	add hl,de
	djnz .f
	pop hl
	ret
.got:	ld de,-6
	add hl,de
	pop de
	ld (hl),e
	inc hl
	ld (hl),$80
	inc hl
	ld (hl),d
	inc hl
	ld (hl),$80
	inc hl
	ld de,(pv_e)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	push hl
	ld a,(pv_life)
	or a
	jr nz,.pl
	call rand
	and 7
	add a,10
.pl:	pop hl
	ld (hl),a
	xor a
	ld (pv_life),a
	inc hl
	ld (hl),c
	ld a,1
	ld (parts_live),a
	ret

parts_tick:
	ld a,(parts_live)
	or a
	ret z
	xor a
	ld (parts_live),a
	ld ix,parts
	ld b,MAXPART
.l:	ld a,(ix+6)
	or a
	jr z,.n
	dec (ix+6)
	ld hl,parts_live
	inc (hl)
	; x += vx*16
	ld a,(ix+4)
	ld l,a
	add a,a
	sbc a,a
	ld h,a
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld e,(ix+1)
	ld d,(ix+0)
	add hl,de
	ld (ix+1),l
	ld (ix+0),h
	bit 7,h
	jr z,$+8
	ld (ix+6),0
	jr .n
	ld a,(ix+5)
	ld l,a
	add a,a
	sbc a,a
	ld h,a
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld e,(ix+3)
	ld d,(ix+2)
	add hl,de
	ld (ix+3),l
	ld (ix+2),h
	bit 7,(ix+7)
	jr z,.n
	ld a,(ix+5)
	add a,5
	jp pe,.n
	ld (ix+5),a
.n:	ld de,8
	add ix,de
	djnz .l
	ret

; parts_queue: precompute plot ops for both halves (addr.w, mask, colour, row)
parts_queue:
	xor a
	ld (pq_nt),a
	ld (pq_nb),a
	ld a,(parts_live)
	or a
	ret z
	ld a,(cam_y)
	sub 6
	ld (pcam),a
	ld ix,parts
	ld b,MAXPART
.l:	ld a,(ix+6)
	or a
	jr z,.n
	ld a,(pcam)
	ld c,a
	ld a,(ix+2)
	sub c
	cp 64
	jr nc,.n
	ld c,a			; screen row
	ld a,(tv_top0)
	dec a
	cp c
	jr nc,.n
	ld a,(ix+0)
	bit 7,a
	jr nz,.n
	push bc
	; pick list
	ld a,(tv_bot0)
	dec a
	cp c
	ld hl,pq_nt
	ld de,pq_top
	jr nc,.tl
	ld hl,pq_nb
	ld de,pq_bot
.tl:	ld a,(hl)
	cp MAXPART
	jr nc,.full
	inc (hl)
	ld l,a			; index*5
	add a,a
	add a,a
	add a,l
	ld l,a
	ld h,0
	add hl,de
	ex de,hl		; DE -> entry
	; address
	ld l,c
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,(ix+0)
	rrca
	rrca
	and 31
	or l
	ld l,a
	ld a,h
	or BUF/256
	ld h,a
	ex de,hl
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	; mask + colour
	ld a,(ix+7)
	and 3
	add a,a
	add a,a
	ld e,a
	ld a,(ix+0)
	and 3
	or e
	add a,a
	ld e,a
	ld d,0
	push hl
	ld hl,pixtab2
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	pop hl
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (hl),c		; row
.full:	pop bc
.n:	ld de,8
	add ix,de
	dec b
	jp nz,.l
	ret

; draw the precomputed particle pixels for the current half
parts_draw:
	ld a,(clip_top)
	ld b,a
	ld a,(tv_bot0)
	cp b
	ld hl,pq_top
	ld a,(pq_nt)
	jr nz,.t
	ld hl,pq_bot
	ld a,(pq_nb)
.t:	or a
	ret z
	ld b,a
.l:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(de)
	and (hl)
	inc hl
	or (hl)
	inc hl
	ld (de),a
	ld a,(hl)
	inc hl
	push hl
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,rowinfo+4
	add hl,de
	ld (hl),1
	inc hl
	ld (hl),1
	pop hl
	djnz .l
	ret
pixtab2: db $3f,$00,$cf,$00,$f3,$00,$fc,$00
	db $3f,$40,$cf,$10,$f3,$04,$fc,$01
	db $3f,$80,$cf,$20,$f3,$08,$fc,$02
	db $3f,$c0,$cf,$30,$f3,$0c,$fc,$03

;---------------------------------------------------------------------
; popups: text rising.  slot: x col, y(board), life, text[6]
;---------------------------------------------------------------------
MAXPOP	equ 4
popup_frog:		; HL = text
	push hl
	ld a,(fx+1)
	srl a
	srl a
	dec a
	jp p,$+4
	xor a
	cp 28
	jr c,$+4
	ld a,27
	ld c,a
	ld a,(fy)
	sub 6
	jr nc,$+3
	xor a
	ld b,a
	pop hl
popup_at:		; C = col, B = board y, HL = text
	push hl
	ld hl,pops
	ld e,MAXPOP
.f:	push hl
	pop iy
	ld a,(iy+2)
	or a
	jr z,.g
	push de
	ld de,9
	add hl,de
	pop de
	dec e
	jr nz,.f
	ld iy,pops
.g:	ld (iy+0),c
	ld (iy+1),b
	ld (iy+2),24
	pop hl
	push iy
	pop de
	inc de
	inc de
	inc de
	ld bc,6
	ldir
	ret
pop_tick:
	ld hl,pops
	ld b,MAXPOP
.l:	push hl
	pop iy
	ld a,(iy+2)
	or a
	jr z,.n
	dec (iy+2)
	and 1
	jr z,.n
	ld a,(iy+1)
	or a
	jr z,.n
	dec (iy+1)
.n:	ld de,9
	add hl,de
	djnz .l
	ret
pops_queue:
	ld hl,pops
	ld b,MAXPOP
.l:	push hl
	pop iy
	ld a,(iy+2)
	or a
	jr z,.n
	push hl
	push bc
	ld a,(cam_y)
	ld b,a
	ld a,(iy+1)
	sub b
	jr c,.sk
	add a,6
	ld b,a
	ld c,(iy+0)
	push iy
	pop de
	inc de
	inc de
	inc de
	ld hl,job_text
	call add_job
.sk:	pop bc
	pop hl
.n:	ld de,9
	add hl,de
	djnz .l
	ret

; text job: p0 = col, p1 = row, p2/p3 = text ptr (transparent, flashing)
job_text:
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	push de
	push bc
	ld hl,BUF
	ld (txt_base),hl
	xor a
	ld (txt_opq),a
	ld a,(frame_cnt)
	and 4
	ld a,$01
	jr z,$+4
	ld a,$03
	call text_setcol
	pop bc
	ld d,c
	ld e,b
	pop hl
	jp text_at

partY:	db $6a,$5a,$56
partR:	db $ea,$fa,$fe

;---------------------------------------------------------------------
; butterflies: ambient, flutter over the start verge and the median
;---------------------------------------------------------------------
bfly_init:
	ld a,(nlanes)
	dec a
	ld b,a
	add a,a
	add a,b
	add a,a
	add a,2
	ld (bf_y),a		; start verge
	ld a,30
	ld (bf_x),a
	ld a,(snake_row)
	or a
	jr nz,.m
	ld a,6
.m:	ld b,a
	add a,a
	add a,b
	add a,a
	add a,2
	ld (bf_y+1),a
	ld a,90
	ld (bf_x+1),a
	ret
bfly_tick:
	ld hl,bf_x
	ld b,2
.l:	push bc
	push hl
	call rand
	pop hl
	and 3
	dec a
	dec a
	add a,(hl)
	cp 4
	jr c,.n
	cp 122
	jr nc,.n
	ld (hl),a
.n:	inc hl
	pop bc
	djnz .l
	ret
bfly_queue:
	ld hl,bf_x
	ld b,2
.l:	push bc
	push hl
	ld c,(hl)
	inc hl
	inc hl
	ld a,(hl)		; board y
	ld e,a
	ld a,(frame_cnt)
	add a,c
	and 8
	jr z,$+3
	dec e			; bob
	ld a,e
	call scr_y
	ld a,(frame_cnt)
	and 2
	ld e,a
	ld d,b
	ld hl,job_bfly
	call add_job
	pop hl
	inc hl
	pop bc
	djnz .l
	ret
; job: p0 x, p1 y, p2 flap
job_bfly:
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld e,(hl)
	ld a,(clip_top)
	cp b
	jr z,.ok
	ret nc
.ok:	ld a,(clip_bot)
	dec a
	cp b
	ret c
	ld a,c
	cp 126
	ret nc
	or a
	ret z
	ld a,b
	call mark_row
	inc a
	call mark_row
	push de
	push bc
	ld e,3			; body
	call plot
	pop bc
	pop de
	ld a,e
	or a
	jr z,.closed
	dec c			; wings open
	push bc
	ld e,1
	call plot
	pop bc
	inc c
	inc c
	ld e,1
	jp plot
.closed:
	dec b
	ld e,1
	jp plot
