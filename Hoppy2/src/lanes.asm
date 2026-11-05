;=====================================================================
; Lanes: pre-shifted scrolling strips (P = 128 px period)
; moving lane memory: 4 planes x 6 rows x 64 bytes (32 + duplicate)
; static lane: 6 rows x 32 bytes.  collision map: 128 bytes / lane.
;=====================================================================
L_KIND	equ 0
L_FLAGS	equ 1		; bit0 moving, bit1 facing left (gfx mirrored)
L_BASE	equ 2
L_COL	equ 4
L_SF	equ 6
L_SI	equ 7
L_VEL	equ 8
L_DEF	equ 10
L_BG	equ 12
L_SPEC	equ 13
L_T	equ 14
L_DX	equ 15		; integer pixels moved this tick (signed, for riders/fx)
L_DV	equ 16		; effective velocity this tick (word)
L_BT	equ 18		; burst timer
L_SIZE	equ 32
MAXLANES equ 17

K_STATIC equ 0
K_ROAD	equ 1
K_WATER	equ 2
K_HOME	equ 3

C_EMPTY	equ 0
C_DEAD	equ 1
C_PLAT	equ 2

PLANE	equ 192		; 6*32

; object types
	STRUCT OBJT
gr	WORD
gl	WORD
w	BYTE		; width in bytes
col	BYTE
anim	BYTE
pad	BYTE
	ENDS

OT_CAR	equ 0
OT_BEETLE equ 1
OT_RACER equ 2
OT_TRUCK equ 3
OT_TRACTOR equ 4
OT_DOZER equ 5
OT_BUS	equ 6
OT_LOG2	equ 7
OT_LOG3	equ 8
OT_LOG4	equ 9
OT_LOG6	equ 10
OT_T2	equ 11
OT_T3	equ 12
OT_D2	equ 13		; diving 2
OT_D3	equ 14		; diving 3
OT_CROC	equ 15
OT_LILY	equ 16
OT_CLOUD1 equ 17
OT_CLOUD2 equ 18

A_NONE	equ 0
A_DIVE	equ 1
A_CROC	equ 2
A_RACER	equ 3

objtab:
	OBJT o_car_r,o_car_l,4,C_DEAD,A_NONE,0
	OBJT o_beetle_r,o_beetle_l,3,C_DEAD,A_NONE,0
	OBJT o_racer_r,o_racer_l,4,C_DEAD,A_RACER,0
	OBJT o_truck_r,o_truck_l,7,C_DEAD,A_NONE,0
	OBJT o_tractor_r,o_tractor_l,4,C_DEAD,A_NONE,0
	OBJT o_dozer_r,o_dozer_l,5,C_DEAD,A_NONE,0
	OBJT o_bus_r,o_bus_l,8,C_DEAD,A_NONE,0
	OBJT o_log2_r,o_log2_l,4,C_PLAT,A_NONE,0
	OBJT o_log3_r,o_log3_l,6,C_PLAT,A_NONE,0
	OBJT o_log4_r,o_log4_l,8,C_PLAT,A_NONE,0
	OBJT o_log6_r,o_log6_l,12,C_PLAT,A_NONE,0
	OBJT o_t2_up_r,o_t2_up_l,4,C_PLAT,A_NONE,0
	OBJT o_t3_up_r,o_t3_up_l,6,C_PLAT,A_NONE,0
	OBJT o_t2_up_r,o_t2_up_l,4,C_PLAT,A_DIVE,0
	OBJT o_t3_up_r,o_t3_up_l,6,C_PLAT,A_DIVE,0
	OBJT o_croc_r,o_croc_l,8,C_PLAT,A_CROC,0
	OBJT o_lily_r,o_lily_l,2,C_PLAT,A_NONE,0
	OBJT o_cloud1,o_cloud1,6,C_EMPTY,A_NONE,0
	OBJT o_cloud2,o_cloud2,4,C_EMPTY,A_NONE,0

bgtab:	dw bg_grass,bg_start,bg_median,bg_road,bg_roadk,bg_water,bg_water2,bg_blank,bg_sky
BG_GRASS equ 0
BG_START equ 1
BG_MEDIAN equ 2
BG_ROAD	equ 3
BG_ROADK equ 4
BG_WATER equ 5
BG_WATER2 equ 6
BG_BLANK equ 7
BG_SKY	equ 8

;---------------------------------------------------------------------
; heap
;---------------------------------------------------------------------
heap_reset:
	ld hl,$4000
	ld (heap_s),hl
	ld hl,heap_main
	ld (heap_m),hl
	ret
; alloc BC bytes -> HL
alloc:	ld hl,(heap_s)
	call align32
	ld (heap_s),hl
	ld hl,(heap_m)
	call align32
	ld (heap_m),hl
	ld hl,(heap_s)
	push hl
	add hl,bc
	ld de,$6800
	or a
	sbc hl,de
	jr z,.oks
	jr nc,.main
.oks:	add hl,de
	ld (heap_s),hl
	pop hl
	ret
.main:	pop hl
	ld hl,(heap_m)
	push hl
	add hl,bc
	ld (heap_m),hl
	pop hl
	ret

;---------------------------------------------------------------------
align32: ld a,l
	add a,31
	ld l,a
	jr nc,$+3
	inc h
	ld a,l
	and $e0
	ld l,a
	ret


lane_ptr:
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,lanes
	add hl,de
	push hl
	pop ix
	ret

;---------------------------------------------------------------------
; build_lane: IX = lane struct, HL = lane def
;  def: kind, bg, spec, speed.w (screen px/tick, + = right), objs (type,x4).. $FF
;---------------------------------------------------------------------
build_lane:
	ld (ix+L_DEF),l
	ld (ix+L_DEF+1),h
	ld a,(hl)
	ld (ix+L_KIND),a
	inc hl
	ld a,(hl)
	ld (ix+L_BG),a
	inc hl
	ld a,(hl)
	ld (ix+L_SPEC),a
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push hl			; objects
	; apply speed scale (lap 2+) : DE = DE * spdmul/4
	call scale_speed
	; vel = -speed
	xor a
	sub e
	ld (ix+L_VEL),a
	ld a,0
	sbc a,d
	ld (ix+L_VEL+1),a
	xor a
	ld (ix+L_SF),a
	ld (ix+L_T),a
	ld (ix+L_DX),a
	call rand
	and 127
	ld (ix+L_SI),a
	; flags
	ld c,0
	ld a,d
	or e
	jr z,.st
	set 0,c
	bit 7,d
	jr z,.st
	set 1,c
.st:	ld (ix+L_FLAGS),c
	; static lanes with the same definition share memory
	ld a,c
	or a
	jr nz,.alloc
	ld a,(ix+L_KIND)
	cp K_STATIC
	jr nz,.alloc
	push ix
	pop hl
	ld (sl_end),hl
	ld hl,lanes
.sh:	ld de,(sl_end)
	or a
	sbc hl,de
	jr z,.alloc
	add hl,de
	push hl
	pop iy
	ld a,(iy+L_DEF)
	cp (ix+L_DEF)
	jr nz,.sn
	ld a,(iy+L_DEF+1)
	cp (ix+L_DEF+1)
	jr nz,.sn
	ld a,(iy+L_BASE)
	ld (ix+L_BASE),a
	ld a,(iy+L_BASE+1)
	ld (ix+L_BASE+1),a
	ld hl,rowinfo		; static lanes never read their col map
	ld (ix+L_COL),l
	ld (ix+L_COL+1),h
	pop hl
	ret
.sn:	ld de,L_SIZE
	add hl,de
	jr .sh
.alloc:	; allocate
	ld bc,6*32
	bit 0,(ix+L_FLAGS)
	jr z,.al
	ld bc,4*PLANE
.al:	call alloc
	ld (ix+L_BASE),l
	ld (ix+L_BASE+1),h
	ld hl,rowinfo		; static lanes never read their col map
	ld a,(ix+L_FLAGS)
	or a
	jr nz,.ac
	ld a,(ix+L_KIND)
	cp K_STATIC
	jr z,.nc
.ac:	ld bc,128
	call alloc
	ld (ix+L_COL),l
	ld (ix+L_COL+1),h
	; clear col map
	ld (hl),C_EMPTY
	ld d,h
	ld e,l
	inc de
	ld bc,127
	ldir
	jr .bgk
.nc:	ld (ix+L_COL),l
	ld (ix+L_COL+1),h
.bgk:
	; background
	ld a,(ix+L_KIND)
	cp K_HOME
	jr nz,.bgt
	; home row: copy home_bg (32 wide, 6 rows)
	ld hl,home_bg+2
	ld e,(ix+L_BASE)
	ld d,(ix+L_BASE+1)
	ld bc,192
	ldir
	pop hl
	ret
.bgt:	ld a,(ix+L_BG)
	add a,a
	ld hl,bgtab
	call addhla
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a			; tile 6 rows x 8 bytes
	ld e,(ix+L_BASE)
	ld d,(ix+L_BASE+1)
	ld b,6
.bgr:	push bc
	ld b,4
.bg1:	push hl
	push bc
	ld bc,8
	ldir
	pop bc
	pop hl
	djnz .bg1
	ld bc,8
	add hl,bc
	pop bc
	djnz .bgr
	; objects
	pop hl
.obj:	ld a,(hl)
	cp $ff
	jr z,.objd
	inc hl
	ld c,(hl)
	inc hl
	push hl
	call place_obj
	pop hl
	jr .obj
.objd:	bit 0,(ix+L_FLAGS)
	ret z
	xor a
	ld b,32
	jp regen

; scale DE (signed speed) by spdmul (4 = x1)
scale_speed:
	ld a,(spdmul)
	cp 4
	ret z
	push hl
	ld b,a
	ld h,d
	ld l,e
	ld de,0
	ex de,hl
.m:	add hl,de
	djnz .m
	; /4 (arith)
	sra h
	rr l
	sra h
	rr l
	ex de,hl
	pop hl
	ret

;---------------------------------------------------------------------
; place_obj: IX lane, A = type, C = x4.  stamps gfx + col + anim slot
;---------------------------------------------------------------------
place_obj:
	ld (po_x),bc
	ld (po_t),a
	call objptr		; HL -> OBJT
	push hl
	pop iy
	; gfx by direction
	ld l,(iy+OBJT.gr)
	ld h,(iy+OBJT.gr+1)
	bit 1,(ix+L_FLAGS)
	jr z,.r
	ld l,(iy+OBJT.gl)
	ld h,(iy+OBJT.gl+1)
.r:	ld a,(po_x)
	call stamp
	; col
	ld a,(iy+OBJT.col)
	ld e,a
	ld a,(iy+OBJT.w)
	ld b,a
	ld a,(po_x)
	call col_fill
	; anim
	ld a,(iy+OBJT.anim)
	or a
	ret z
	cp A_CROC
	jr nz,.nc
	; croc: head deadly
	ld a,(po_x)
	bit 1,(ix+L_FLAGS)
	jr nz,.cl
	add a,6
.cl:	ld e,C_DEAD
	ld b,2
	call col_fill
	ld a,A_CROC
.nc:	jp anim_add

objptr:	; A = type -> HL = objtab entry
	add a,a
	add a,a
	add a,a
	ld hl,objtab
	jp addhla

; col_fill: IX lane, A = x4, B = bytes, E = value
col_fill:
	ld l,(ix+L_COL)
	ld h,(ix+L_COL+1)
	add a,a
	add a,a
	ld c,a
	ld a,b
	add a,a
	add a,a
	ld b,a
.l:	ld a,c
	and 127
	push hl
	call addhla
	ld (hl),e
	pop hl
	inc c
	djnz .l
	ret

;---------------------------------------------------------------------
; stamp: IX lane, HL = object gfx (db wb ; rows x wb x (mask,data)), A = x4
; writes plane 0 (and duplicate for moving lanes).  Does NOT regen planes.
;---------------------------------------------------------------------
stamp:
	ld (st_x),a
	ld a,(hl)
	ld (st_w),a
	inc hl
	ld e,(ix+L_BASE)
	ld d,(ix+L_BASE+1)
	ld (st_row),de
	ld b,6
.row:	push bc
	ld a,(st_x)
	ld c,a
	ld a,(st_w)
	ld b,a
.byte:	ld a,c
	and 31
	ld de,(st_row)
	add a,e
	ld e,a
	jr nc,$+3
	inc d
	ld a,(de)
	and (hl)
	inc hl
	or (hl)
	inc hl
	ld (de),a
	inc c
	djnz .byte
	ld de,(st_row)
	push hl
	ld hl,32
	add hl,de
	ld (st_row),hl
	pop hl
	pop bc
	djnz .row
	ret

;---------------------------------------------------------------------
; regen: IX moving lane, A = first byte j0, B = count. Builds planes 1..3
; (each plane k = plane 0 shifted left by k pixels) for those bytes.
;---------------------------------------------------------------------
regen:
	ld (rg_j0),a
	ld a,b
	ld (rg_n),a
	ld l,(ix+L_BASE)
	ld h,(ix+L_BASE+1)
	ld (rg_src),hl
	ld a,6
	ld (rg_k),a
.row:	ld a,(rg_j0)
	ld c,a
	ld a,(rg_n)
	ld b,a
.j:	push bc
	ld hl,(rg_src)
	ld a,c
	and 31
	or l
	ld l,a
	ld d,(hl)		; c[j]
	push hl
	ld a,c
	inc a
	and 31
	ld e,a
	ld a,l
	and $e0
	or e
	ld l,a
	ld e,(hl)		; c[j+1]
	pop hl
	ld bc,PLANE
	add hl,bc		; plane1[j]
	ex de,hl		; HL = data, DE = dest
	add hl,hl
	add hl,hl
	ld a,h
	ld (de),a
	ex de,hl
	add hl,bc
	ex de,hl
	add hl,hl
	add hl,hl
	ld a,h
	ld (de),a
	ex de,hl
	add hl,bc
	ex de,hl
	add hl,hl
	add hl,hl
	ld a,h
	ld (de),a
	pop bc
	inc c
	djnz .j
	ld hl,(rg_src)
	ld de,32
	add hl,de
	ld (rg_src),hl
	ld hl,rg_k
	dec (hl)
	jr nz,.row
	ret

; restamp: IX lane, HL gfx, A = x4  (stamp + regen of affected bytes)
restamp:
	push af
	ld b,(hl)
	push bc
	call stamp
	pop bc
	pop af
	bit 0,(ix+L_FLAGS)
	ret z
	dec a
	inc b
	jp regen

;---------------------------------------------------------------------
; Animated lane objects (diving turtles, croc jaws, racer smoke)
; slot: lane(1) x4(1) type(1) state(1) timer(1) otype(1) pad pad
;---------------------------------------------------------------------
MAXANIM	equ 16
AN_LANE	equ 0
AN_X	equ 1
AN_TYPE	equ 2
AN_ST	equ 3
AN_TM	equ 4
AN_OT	equ 5

anim_add:		; A = anim type, IX lane, po_x/po_t
	ld c,a
	ld a,(n_anim)
	cp MAXANIM
	ret nc
	inc a
	ld (n_anim),a
	dec a
	add a,a
	add a,a
	add a,a
	ld hl,anims
	call addhla
	ld a,(cur_lane)
	ld (hl),a
	inc hl
	ld a,(po_x)
	ld (hl),a
	inc hl
	ld (hl),c
	inc hl
	ld (hl),0		; state
	inc hl
	; timer: staggered by x
	ld a,(po_x)
	add a,a
	add a,a
	add a,20
	ld (hl),a
	inc hl
	ld a,(po_t)
	ld (hl),a
	ret

; diver states: 0 up, 1 warn, 2 half(sinking), 3 down, 4 half(rising)
dive_time: db 110,24,10,36,10
dive_gfx2: dw o_t2_up_r,o_t2_warn_r,o_t2_half_r,o_t2_down_r,o_t2_half_r
	dw o_t2_up_l,o_t2_warn_l,o_t2_half_l,o_t2_down_l,o_t2_half_l
dive_gfx3: dw o_t3_up_r,o_t3_warn_r,o_t3_half_r,o_t3_down_r,o_t3_half_r
	dw o_t3_up_l,o_t3_warn_l,o_t3_half_l,o_t3_down_l,o_t3_half_l

anim_tick:
	xor a
	ld (an_done),a
	ld a,(n_anim)
	or a
	ret z
	ld b,a
	ld hl,anims
.l:	push bc
	push hl
	call anim_one
	pop hl
	ld bc,8
	add hl,bc
	pop bc
	djnz .l
	ret

anim_one:
	push hl
	pop iy
	ld a,(iy+AN_TYPE)
	cp A_RACER
	ret z
	dec (iy+AN_TM)
	ret nz
	ld a,(an_done)		; one restamp per tick: others wait
	or a
	jr z,.go
	inc (iy+AN_TM)
	ret
.go:	inc a
	ld (an_done),a
	ld a,(iy+AN_LANE)
	call lane_ptr
	ld a,(iy+AN_TYPE)
	cp A_CROC
	jr z,.croc
	; diver
	ld a,(iy+AN_ST)
	inc a
	cp 5
	jr c,$+3
	xor a
	ld (iy+AN_ST),a
	ld hl,dive_time
	call addhla
	ld a,(hl)
	ld (iy+AN_TM),a
	ld a,(iy+AN_ST)
	cp 1
	jr nz,.nw
	; warn sound if frog is riding this lane
	ld a,(iy+AN_LANE)
	ld hl,frow_c
	cp (hl)
	jr nz,.nw
	push iy
	ld hl,sfx_bubble
	ld a,2
	call sfx_play
	pop iy
.nw:	ld a,(iy+AN_ST)
	add a,a
	ld hl,dive_gfx2
	ld c,4			; width bytes
	ld b,a
	ld a,(iy+AN_OT)
	cp OT_D3
	ld a,b
	jr nz,.d2
	ld hl,dive_gfx3
	ld c,6
.d2:	bit 1,(ix+L_FLAGS)
	jr z,.dr
	add a,10
.dr:	call addhla
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	push bc
	ld a,(iy+AN_LANE)
	call lane_inval
	ld a,(iy+AN_X)
	call restamp
	pop bc
	; collision: down -> empty, else plat
	ld e,C_PLAT
	ld a,(iy+AN_ST)
	cp 3
	jr nz,.cp
	ld e,C_EMPTY
.cp:	ld b,c
	ld a,(iy+AN_X)
	jp col_fill
.croc:	ld a,(iy+AN_LANE)
	call lane_inval
	ld a,(iy+AN_ST)
	xor 1
	ld (iy+AN_ST),a
	ld c,a
	ld a,30
	jr z,$+4
	ld a,60
	ld (iy+AN_TM),a
	ld a,c
	ld hl,o_crhc_r
	or a
	jr z,$+5
	ld hl,o_crho_r
	ld a,(iy+AN_X)
	bit 1,(ix+L_FLAGS)
	jr nz,.cl
	add a,6
	jp restamp
.cl:	ld hl,o_crhc_l
	ld c,a
	ld a,(iy+AN_ST)
	or a
	ld a,c
	jr z,$+5
	ld hl,o_crho_l
	jp restamp

;---------------------------------------------------------------------
; move lanes (per tick).  Sets L_DX = integer pixel delta of scroll.
;---------------------------------------------------------------------
lanes_move:
	ld a,(nlanes)
	or a
	ret z
	ld b,a
	ld ix,lanes
.l:	bit 0,(ix+L_FLAGS)
	jr z,.n
	ld e,(ix+L_VEL)
	ld d,(ix+L_VEL+1)
	; slow-mo halves, burst lanes multiply
	ld a,(ix+L_SPEC)
	cp 1
	jr nz,.nb
	ld a,(ix+L_T)
	cp 2
	jr nz,.nb
	ld h,d
	ld l,e
	add hl,hl
	add hl,de
	ex de,hl
.nb:	ld a,(slowmo)
	or a
	jr z,.ns
	sra d
	rr e
	sra d
	rr e
.ns:	ld (ix+L_DV),e
	ld (ix+L_DV+1),d
	ld l,(ix+L_SF)
	ld h,(ix+L_SI)
	ld c,h
	add hl,de
	ld (ix+L_SF),l
	ld (ix+L_SI),h
	ld a,h
	sub c
	ld (ix+L_DX),a
.n:	ld de,L_SIZE
	add ix,de
	djnz .l
	ret

; invalidate the screen rows showing lane A (preserves IX, IY)
lane_inval:
	ld b,a
	add a,a
	add a,b
	add a,a			; lane*6 = board y
	ld b,a
	ld a,(cam_y)
	ld c,a
	ld a,b
	sub c
	add a,6			; screen row (may be <6 or wrap)
	ld b,6
.l:	cp 64
	jr nc,.n
	push hl
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	push de
	ld de,rowinfo+2
	add hl,de
	pop de
	ld (hl),$ff
	pop hl
.n:	inc a
	djnz .l
	ret
