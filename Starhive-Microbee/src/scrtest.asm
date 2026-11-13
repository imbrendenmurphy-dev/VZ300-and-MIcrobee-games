; =====================================================================
;  STARHIVE - SCROLL TEST (hardware proof for the Premium Plus)
;  40 x 24 characters of 8 x 11, hardware smooth vertical scrolling by
;  the 6545's vertical total adjust (R5), a still HUD band and window
;  edges, parallax stars, sprites composed in PCG.
;  VIBED BY BPM 2026
;
;  Keys: Q A O P / cursor keys / joystick = fly, SPACE = fire,
;        1 2 3 4 = scroll at 25, 50, 100, 150 lines a second, 0 = stop,
;        W = drones on/off
; =====================================================================
	DEVICE NOSLOT64K
	INCLUDE "hw.inc"
	INCLUDE "../build/data.inc"

FIELDS	equ 2			; 25 frames a second

; upper-RAM buffers
LISTA	equ $D800		; 256 x 4
LISTB	equ $DC00
RESTLIST equ $E000		; 255 x 5

NDRONE	equ 8
NSHOTS	equ 6
NBULS	equ 6

	ORG $8000
start:	di
	ld sp,$EFF0
	ld hl,vars
	ld de,vars+1
	ld bc,vars_end-vars-1
	ld (hl),0
	ldir
	call hw_init
	ld hl,LISTA
	ld (listcur),hl
	ld hl,LISTB
	ld (listold),hl
	MEMV BLK_WORK
	call pcg_clear
	call cls_all
	ld hl,MIRROR		; scenery glyphs -> PCG banks 0-4
	ld bc,$0500
	call pcg_banks
	; HUD labels
	ld hl,hud_texts
.ht:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,d
	or e
	jr z,.hd
	push de
	pop ix
	ld b,0
	call hud_print
	inc hl			; past the 0
	push hl
	call hud_render_all
	pop hl
	jr .ht
.hd:	; scroll
	ld hl,DROWS-1-EROW0	; display row 2 shows map row 21
	ld (m_top),hl
	ld a,2			; one line a field (50 lines a second)
	ld (scrollSpd),a
	ld a,2
	ld (elapsed),a
	call scroll_init
	call hud_place
	ld a,1
	ld (drones_on),a
	ld hl,152+16
	ld (px),hl
	ld a,190+16
	ld (py),a
	call compose
	ld a,1
	ld (stepped),a		; first commit sets every edge and HUD cell
	call crtc_init
	call waitframe
	call commit
	call idle_latch
	ld a,1
	ld (stepped),a
loop:	call compose
	call waitframe
	call commit
	call idle_latch
	jr loop

; ---------------------------------------------------------------------
compose:
	call vschk
	call readinp
	call vschk
	call controls
	call move_player
	call move_drones
	call move_shots
	call vschk
	MEMV BLK_WORK
	call frame_begin
	call scroll_step
	MEMV BLK_WORK
	call star_update
	call vschk
	call draw_all
	call vschk
	call edge_slots_mask
	call rest_build
	call vschk
	call hud_update
	jp vschk

controls:
	ld hl,speedkeys
	ld b,5
.k:	ld a,(hl)
	inc hl
	push hl
	push bc
	call key1
	pop bc
	pop hl
	jr z,.n
	ld a,(hl)
	ld (scrollSpd),a
.n:	inc hl
	djnz .k
	ld a,K_W
	call key1
	ld hl,wkey
	jr z,.wup
	ld a,(hl)
	or a
	ret nz
	ld (hl),1
	ld a,(drones_on)
	xor 1
	ld (drones_on),a
	ret
.wup:	ld (hl),0
	ret
speedkeys: db $20,0, $21,1, $22,2, $23,4, $24,6
wkey	db 0

move_player:
	ld a,(frame)
	inc a
	ld (frame),a
	ld a,(inp)
	ld b,a
	ld hl,(px)
	bit 2,b
	jr z,.nl
	ld de,-4
	add hl,de
	ld de,16
	or a
	sbc hl,de
	jr nc,.l1
	ld hl,0
.l1:	add hl,de
.nl:	bit 3,b
	jr z,.nr
	ld de,4
	add hl,de
	push hl
	ld de,16+PFW-16
	or a
	sbc hl,de
	pop hl
	jr c,.nr
	ld hl,16+PFW-16
.nr:	ld (px),hl
	ld a,(py)
	bit 0,b
	jr z,.nu
	sub 4
	cp 16+4
	jr nc,.nu
	ld a,16+4
.nu:	bit 1,b
	jr z,.nd
	add a,4
	cp 16+PFH-18
	jr c,.nd
	ld a,16+PFH-18
.nd:	ld (py),a
	; fire
	bit 4,b
	ret z
	ld a,(firecd)
	or a
	jr z,.f
	dec a
	ld (firecd),a
	ret
.f:	ld a,2
	ld (firecd),a
	ld hl,shots
	ld b,NSHOTS
.s:	ld a,(hl)
	or a
	jr z,.got
	inc hl
	inc hl
	inc hl
	djnz .s
	ret
.got:	ld a,(py)
	sub 4
	ld (hl),a		; y (0 = free)
	inc hl
	ld de,(px)
	ld a,e
	add a,7
	ld (hl),a
	inc hl
	ld a,d
	adc a,0
	ld (hl),a
	ret

move_shots:
	ld hl,shots
	ld b,NSHOTS
.s:	ld a,(hl)
	or a
	jr z,.n
	sub 12
	cp 8
	jr nc,.k
	xor a
.k:	ld (hl),a
.n:	inc hl
	inc hl
	inc hl
	djnz .s
	ld hl,buls
	ld b,NBULS
.b:	ld a,(hl)
	or a
	jr z,.bn
	add a,5
	cp 16+PFH
	jr c,.bk
	xor a
.bk:	ld (hl),a
.bn:	inc hl
	inc hl
	inc hl
	djnz .b
	ret

; drones: a figure-of-eight formation, each with its own phase
move_drones:
	ld a,(dphase)
	add a,3
	ld (dphase),a
	ld ix,drones
	ld b,NDRONE
	ld c,0
.w:	push bc
	ld a,(dphase)
	add a,c
	call sin8		; -63..63
	ld l,a
	add a,a
	sbc a,a
	ld h,a			; sign extend
	add hl,hl		; x = 154 + 2 sin
	ld de,154+16-6
	add hl,de
	ld (ix+0),l
	ld (ix+1),h
	ld a,(dphase)
	add a,a
	add a,c
	add a,c
	call sin8
	sra a
	add a,70+16
	ld (ix+2),a
	ld a,(frame)
	add a,c
	and 31
	jr nz,.nb
	ld hl,buls
	ld b,NBULS
.f:	ld a,(hl)
	or a
	jr z,.g
	inc hl
	inc hl
	inc hl
	djnz .f
	jr .nb
.g:	ld a,(ix+2)
	add a,10
	ld (hl),a
	inc hl
	ld a,(ix+0)
	add a,4
	ld (hl),a
	inc hl
	ld a,(ix+1)
	adc a,0
	ld (hl),a
.nb:	ld de,3
	add ix,de
	pop bc
	ld a,c
	add a,32
	ld c,a
	djnz .w
	ret

sin8:	ld hl,sintab
	ld e,a
	ld d,0
	add hl,de
	ld a,(hl)
	ret

; list of (y + 16, x + 16 (2 bytes)) objects -> sprites; y = 0: none
draw_list:
.o:	push bc
	ld a,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	or a
	jr z,.n
	push hl
	ld c,a
	ld hl,(dl_frame)
	call spr_draw
	pop hl
.n:	pop bc
	djnz .o
	ret

draw_all:
	ld hl,SP_BULLET
	ld (dl_frame),hl
	ld hl,buls
	ld b,NBULS
	call draw_list
	call vschk
	ld a,(drones_on)
	or a
	jr z,.nw
	ld hl,SP_DRONE1
	ld a,(frame)
	and 2
	jr z,.w1
	ld hl,SP_DRONE2
.w1:	ld (dl_frame),hl
	ld ix,drones
	ld b,NDRONE
.w:	push bc
	ld e,(ix+0)
	ld d,(ix+1)
	ld c,(ix+2)
	ld hl,(dl_frame)
	push ix
	call spr_draw
	pop ix
	ld de,3
	add ix,de
	call vschk
	pop bc
	djnz .w
.nw:	ld hl,SP_SHOT
	ld (dl_frame),hl
	ld hl,shots
	ld b,NSHOTS
	call draw_list
	ld de,(px)
	ld a,(py)
	ld c,a
	ld a,(frame)
	and 1
	ld hl,SP_HORNET1
	jr z,.p1
	ld hl,SP_HORNET2
.p1:	jp spr_draw

hud_update:
	; score: frames run (a counter for the test), every 8th frame
	ld a,(frame)
	and 15
	jr nz,.ns
	ld hl,score+2
	ld a,(hl)
	add a,1
	daa
	ld (hl),a
	dec hl
	ld a,(hl)
	adc a,0
	daa
	ld (hl),a
	dec hl
	ld a,(hl)
	adc a,0
	daa
	ld (hl),a
	ld ix,hr_score
	ld hl,score
	ld b,0
	call hud_score
	call hud_render
.ns:	ld a,(stepped)
	or a
	jr z,.nr
	ld ix,hr_rows
	ld hl,(m_top)
	ld b,0
	call hud_num5
	call hud_render
.nr:	ld a,(frame)		; idle passes in the last frame
	and 15
	cp 8
	ret nz
	ld ix,hr_idle
	ld hl,(idlelast)
	ld b,0
	call hud_num5
	jp hud_render

; "sound" for the test: count idle passes (a measure of spare time)
snd_idle:
	ld hl,(idlecnt)
	inc hl
	ld (idlecnt),hl
	ret
idle_latch:
	ld hl,(idlecnt)
	ld (idlelast),hl
	ld hl,0
	ld (idlecnt),hl
	ret

; ---------------------------------------------------------------------
hw_init:
	ld a,$4F
	out (P_PIOAC),a
	ld a,$07
	out (P_PIOBC),a
	ld a,$CF
	out (P_PIOBC),a
	ld a,$BF
	out (P_PIOBC),a
	ld a,$07
	out (P_PIOBC),a
	xor a
	out (P_PIOB),a
	ld a,$CF
	out (P_PIOAC),a
	ld a,$FF
	out (P_PIOAC),a
	ld a,$07
	out (P_PIOAC),a
	xor a
	out (P_ROMLAT),a
	out (P_COLCTL),a
	ld a,LV_SCREEN
	out (P_LV),a
	ret

	INCLUDE "input.asm"
	INCLUDE "video.asm"
	INCLUDE "frame.asm"
	INCLUDE "commit.asm"
	INCLUDE "hud.asm"
	INCLUDE "../build/tables.inc"
sintab:
	INCLUDE "../build/sin.inc"

code_end:
	ASSERT code_end <= LISTA

; ---------------------------------------------------------------------
;  variables (cleared at start)
	ORG $E500
vars:
vcount	ds 1
vtotal	ds 1
elapsed	ds 1
scr_half ds 1
vblast	ds 1
lagged	ds 1
frame	ds 1
page	ds 1
scrS	ds 2
fineK	ds 1
stepped	ds 1
scrollSpd ds 1
m_top	ds 2
st_ph0	ds 1
rowbase	ds NROWB*2
nslot	ds 1
nold	ds 1
nrest	ds 1
listcur	ds 2
listold	ds 2
nextent	ds 2
pr_vid	ds 1
pr_half	ds 1
pr_base	ds 2
pr_col	ds 1
rowtmp	ds SCOLS*3
sd_y	ds 1
sd_wb	ds 1
sd_h	ds 1
sd_h2	ds 1
sd_cx	ds 1
sd_n	ds 1
sd_j	ds 1
sd_i2	ds 1
sd_rn	ds 1
sd_row	ds 1
sd_data	ds 2
sd_bnd	ds 2
sd_sp	ds 2
sr_src	ds 2
nedges	ds 1
edgeslots ds 96
eu0	ds SCOLS
eu1	ds SCOLS
egm0	ds SCOLS*2
egm1	ds SCOLS*2
nu0	ds 1
nu1	ds 1
inp	ds 1
inpold	ds 1
inpedge	ds 1
joyraw	ds 1
px	ds 2
py	ds 1
firecd	ds 1
dphase	ds 1
drones_on ds 1
dl_frame ds 2
drones	ds NDRONE*3
shots	ds NSHOTS*3
buls	ds NBULS*3
score	ds 3
idlecnt	ds 2
idlelast ds 2
vars_end:
	ASSERT vars_end <= $EF00

	SAVEBIN "../build/SCRLTEST.BIN",$8000,code_end-$8000
