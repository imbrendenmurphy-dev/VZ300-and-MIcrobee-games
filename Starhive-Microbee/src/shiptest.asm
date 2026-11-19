; =====================================================================
;  STARHIVE - SHIPTEST: the software scroll with sprites
;  (40 x 24, 8 x 11 cells; the frame is always 312 lines)
;  Scenery fine scroll by PCG phase banks 0-10, far stars in bank 11,
;  sprites composed into double-buffered pools (banks 12-15) and written
;  row by row just ahead of the beam.
;  Joystick or keys: move, fire. 0-4 scroll speed, W drones on/off,
;  F 25 / 50 frames a second.
;  VIBED BY BPM 2026
; =====================================================================
	DEVICE NOSLOT64K
	INCLUDE "hw.inc"

COLT	equ $B000		; colour of slot s at phase k: COLT + 256 k + s
SEGS	equ $C000		; per map row (row & 31, 256 bytes each): its pair
				; cells on screen: address, colL, colU; 0 ends
BLK_W	equ 19		; WORK: sprite library, lists, stream, shadows
ROWBUF	equ $E0A0		; a row record's codes, attributes, colours
HUDC	equ $E000		; HUD codes (80) and colours (80)
HUDK	equ $E050
VROWS	equ 22
R5FIX	equ 4			; 28 rows x 11 + 4 = 312 lines

	ORG $8000
start:	di
	ld sp,$EFF0
	call hw_init
	MEMV BLK_ROWS		; (video RAM window on)
	ld a,1
	in a,(P_CLK40)
	ld hl,crtc_tab
	ld c,0
.ci:	ld a,c
	out (P_CRTCA),a
	ld a,(hl)
	out (P_CRTCD),a
	inc hl
	inc c
	ld a,c
	cp 16
	jr nz,.ci
	call pcg_clear
	; font glyphs: bank 11, codes 81h..
	ld a,LV_SCREEN|STAR_BANK
	out (P_LV),a
	ld hl,font_gl
	ld de,PCGWIN+16
	ld bc,N_FONT*16
	ldir
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,2
	ld (speed),a
	ld (fields),a
	ld (spdshow),a

; ---------------------------------------------------------------------
restart:
	ld sp,$EFF0
	call cls
	ld hl,21
	ld (top),hl
	xor a
	ld (k),a
	ld (s88),a
	ld (acc),a
	ld (step),a
	ld hl,0
	ld (scrS),hl
	ld (page),a
	ld (nslot),a
	ld (frame),a
	ld hl,score
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	ld a,BLK_W		; no sprite cells yet
	call blkport
	out (P_MEM),a
	call buckets_clear
	ld hl,objs_init
	ld de,px
	ld bc,objs_init_end-objs_init
	ldir
	call hud_build
	; load every pair of the first screen (group 21)
	ld hl,21
	call group_ptr
.ld:	ld a,(load_left)
	or a
	jr z,.ldd
	call load_one
	jr .ld
.ldd:	ld hl,22
	call group_ptr
	; draw the playfield: display row d (2..23) = map row 21 - (d - 2)
	ld b,2
.dr:	push bc
	ld a,23
	sub b			; r = 23 - d
	ld l,a
	ld h,0
	ld a,b
	call ring_of		; DE = ring offset of display row d
	push hl
	push de
	call write_row
	pop de
	pop hl
	push hl
	push de
	call seg_build
	pop de
	pop hl
	call shadow_row
	pop bc
	inc b
	ld a,b
	cp 24
	jr nz,.dr
	ld a,1
	ld (hudd),a
	call star_off
main:	call vschk		; (fields) fields since the last commit?
	ld a,(vbcount)
	ld hl,fields
	cp (hl)
	jr nc,.late
.wt:	call vblank		; no: wait for them
	ld hl,vbcount
	inc (hl)
	ld a,(hl)
	ld hl,fields
	cp (hl)
	jr c,.wt
	jr .ok
.late:	call vblank		; overran: on the next edge
	ld hl,vbcount
	inc (hl)
.ok:	ld a,(vbcount)		; fields this frame took (for the scroll)
	ld (elapsed),a
	xor a
	ld (vbcount),a
	ld a,$20
	ld (vbprev),a
	call commit
	call advance
	call vschk
	call readinp
	ld a,(frame)		; option keys every 4th frame
	and 3
	call z,keys
	call move_player
	call move_drones
	call move_shots
	ld a,BLK_W
	call blkport
	out (P_MEM),a
	call frame_begin
	call draw_all
	call vschk
	call finish_frame
	call vschk
	call hud_score
	ld a,(fields)
	add a,a
	add a,2			; loads per frame: 4 at 50 fps, 6 at 25 fps
	ld b,a
.l:	ld a,(load_left)
	or a
	jr z,.ln
	push bc
	call load_one
	call vschk
	pop bc
	djnz .l
.ln:	jp main

; ---------------------------------------------------------------------
;  commit, at the start of vertical blanking: top of the screen first
; ---------------------------------------------------------------------
commit:	ld a,(step)
	or a
	jr z,.ns
	ld hl,(scrS)		; start address (latched at the next frame)
	ld a,12
	out (P_CRTCA),a
	ld a,h
	out (P_CRTCD),a
	ld a,13
	out (P_CRTCA),a
	ld a,l
	out (P_CRTCD),a
	call hud_write
	ld hl,(top)		; the new top row
	ld a,2
	call ring_of
	call write_row
	jr .st
.ns:	ld a,(hudd)
	or a
	call nz,hud_write
.st:	call stars
	call rows_commit
	ld a,(page)		; the composed page is on show now
	xor 1
	ld (page),a
	ld a,(step)
	or a
	ret z
	xor a
	ld (step),a
	ld hl,(top)		; loads for the next step may start now
	inc hl
	jp group_ptr

; ---------------------------------------------------------------------
;  advance the scroll and prepare the next commit
; ---------------------------------------------------------------------
advance:
	ld a,(elapsed)
	ld b,a
	ld a,(speed)
	ld c,a
	ld a,(acc)
.m:	add a,c
	djnz .m
	ld c,a
	srl c			; C = whole lines (at most 10: one step)
	and 1
	ld (acc),a
	ld a,c
	cp CL
	jr c,.cl
	ld c,CL-1
.cl:
	ld a,(s88)
	add a,c
	cp 88
	jr c,.s
	sub 88
.s:	ld (s88),a
	ld a,(k)
	add a,c
	cp CL
	jr c,.nk
	sub CL
	ld (k),a
	; coarse step: top row + 1
	ld hl,(top)
	inc hl
	ld (top),hl
	ld de,-(NROWS-1)
	add hl,de
	jp nc,.ok
	jp restart		; end of the level: round again
.ok:	ld hl,(scrS)
	ld de,-40
	add hl,de
	ld a,h
	and 7
	ld h,a
	ld (scrS),hl
.fl:	ld a,(load_left)	; the new row's pairs must be in
	or a
	jr z,.fd
	call load_one
	call vschk
	jr .fl
.fd:	ld a,2			; the new top row's segment and shadows
	call ring_of
	ld hl,(top)
	push hl
	push de
	call seg_build
	call vschk
	pop de
	pop hl
	call shadow_row
	call vschk
	ld a,1
	ld (step),a
	jr star_off
.nk:	ld (k),a
star_off:			; off = (s88 / 2 - k) mod 44
	ld a,(s88)
	srl a
	ld hl,k
	sub (hl)
	jr nc,.p
	add a,44
.p:	cp 44
	jr c,.o
	sub 44
.o:	ld (soff),a
	ret

; ---------------------------------------------------------------------
;  HL = map row, DE = its ring offset: the row's segment (pair cells)
; ---------------------------------------------------------------------
seg_build:			; two lists: cells of one colour (address),
	ld (bl_base),de		; from +0; cells whose colour changes with the
	ld a,l			; phase (address, slot, 0), from +58h
	and 31
	or SEGS>>8
	ld d,a
	ld e,0
	ld (bl_dst),de
	ld e,$58
	ld (bl_dstb),de
	call row_rec
	ld a,l
	add a,120
	ld l,a
	ld b,(hl)
	inc hl
	ld a,b
	or a
	jr z,.e
.c:	ld a,(hl)		; column
	inc hl
	push hl
	ld hl,(bl_base)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,h
	and 7
	or $F0
	ld h,a
	ex de,hl		; DE = the cell's address
	pop hl
	ld a,(hl)		; slot (+80h: colour changes)
	inc hl
	push hl
	bit 7,a
	jr nz,.v
	ld hl,(bl_dst)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (bl_dst),hl
	jr .nx
.v:	and $7F
	ld hl,(bl_dstb)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (hl),a
	inc hl
	inc hl
	ld (bl_dstb),hl
.nx:	pop hl
	djnz .c
.e:	ld hl,(bl_dst)
	ld (hl),0
	inc hl
	ld (hl),0
	ld hl,(bl_dstb)
	ld (hl),0
	inc hl
	ld (hl),0
	ret

; A = display row, uses (scrS) -> DE = ring offset (S + 40 A) & 7FFh
ring_of:
	push hl
	ld hl,(scrS)
	ld de,40
	or a
	jr z,.d
.a:	add hl,de
	dec a
	jr nz,.a
.d:	ld a,h
	and 7
	ld d,a
	ld e,l
	pop hl
	ret

; HL = map row -> its record mapped in the lower window, HL = address
row_rec:
	ld a,l
	and $7F
	push af
	add hl,hl		; H = row / 128
	ld a,h
	add a,BLK_ROWS
	call blkport
	out (P_MEM),a
	pop af
	ld h,a
	ld l,0
	ret

; A = block -> A = port 50h value (ROMs off, video window on)
blkport:
	push bc
	ld b,a
	and 3
	xor 2
	ld c,a
	ld a,b
	and $1C
	rlca
	rlca
	rlca
	or c
	or 4
	pop bc
	ret

; HL = map row, DE = ring offset: codes, attributes, colours of the row
write_row:
	push de
	call row_rec
	pop de
	push hl
	push de
	ld a,$F0
	ld bc,40
	call rcopy		; codes
	ld a,LV_ATTR
	out (P_LV),a
	pop de
	pop hl
	push hl
	push de
	ld bc,40
	add hl,bc
	ld a,$F0
	call rcopy		; attributes (pair cells bank 0, stars bank 11)
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	pop de
	pop hl
	ld bc,80
	add hl,bc
	ld bc,40
	ld a,$F8
	call rcopy		; colours
	xor a
	out (P_COLCTL),a
	ret

; HL = map row, DE = ring offset: the row's codes, attributes and
; colours into the WORK shadows (for the sprites and the put-backs)
shadow_row:
	push de
	call row_rec
	ld de,ROWBUF
	ld bc,120
	ldir
	ld a,BLK_W
	call blkport
	out (P_MEM),a
	pop de
	push de
	ld hl,ROWBUF
	ld bc,40
	ld a,$70
	call rcopy		; codes
	pop de
	push de
	ld hl,ROWBUF+40
	ld bc,40
	ld a,$78
	call rcopy		; attributes
	pop de
	ld hl,ROWBUF+80
	ld bc,40
	ld a,$68
	jp rcopy		; colours

; HL = source, DE = ring offset, BC = count, A = window (F0h / F8h)
rcopy:	ld (rc_win),a
	push hl
	ld hl,$0800
	or a
	sbc hl,de		; room before the wrap
	push hl
	or a
	sbc hl,bc
	pop hl
	jr c,.split
	pop hl
	ld a,(rc_win)
	or d
	ld d,a
	ldir
	ret
.split:	push bc			; n1 = room, n2 = count - room
	ld b,h
	ld c,l
	pop hl
	or a
	sbc hl,bc
	ex (sp),hl		; (sp) = n2, HL = source
	ld a,(rc_win)
	or d
	ld d,a
	ldir
	pop bc
	ld a,(rc_win)
	ld d,a
	ld e,0
	ldir
	ret

; the two HUD rows at the top of the ring
hud_write:
	xor a
	ld (hudd),a
	ld de,(scrS)
	ld hl,HUDC
	ld bc,80
	ld a,$F0
	call rcopy
	ld a,LV_ATTR
	out (P_LV),a
	ld de,(scrS)
	ld hl,hud_attr
	ld bc,80
	ld a,$F0
	call rcopy
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	ld de,(scrS)
	ld hl,HUDK
	ld bc,80
	ld a,$F8
	call rcopy
	xor a
	out (P_COLCTL),a
	ret

; far stars: glyph (v, q) at code F0h + 4v + q shows texture v from line
; 11q + off (the textures are stored twice over)
stars:	ld a,LV_SCREEN|STAR_BANK
	out (P_LV),a
	ld de,PCGWIN+$700
	ld ix,star_texs
	ld c,4
.v:	ld a,(soff)
	ld b,4
.q:	push bc
	push af
	ld l,(ix+0)
	ld h,(ix+1)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	REPT 11
	ldi
	ENDR
	ld a,e
	add a,5
	ld e,a
	pop af
	add a,11
	cp 44
	jr c,$+4
	sub 44
	pop bc
	djnz .q
	inc ix
	inc ix
	dec c
	jr nz,.v
	ld a,LV_SCREEN
	out (P_LV),a
	ret
star_texs:	dw star_tex0,star_tex1,star_tex2,star_tex3

; ---------------------------------------------------------------------
;  pair loads: the schedule (SCHED block) has a group per coarse step
; ---------------------------------------------------------------------
group_ptr:			; HL = step -> load_ptr / load_left
	ld a,BLK_SCHED
	call blkport
	out (P_MEM),a
	add hl,hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,(de)
	ld (load_left),a
	inc de
	ld (load_ptr),de
	ret

load_one:			; next load of the group: slot, pair id
	ld a,BLK_SCHED
	call blkport
	out (P_MEM),a
	ld hl,(load_ptr)
	ld c,(hl)		; slot
	inc hl
	ld e,(hl)		; id lo
	inc hl
	ld d,(hl)		; id hi
	inc hl
	ld (load_ptr),hl
	ld hl,load_left
	dec (hl)
	ld a,c
	ld (ld_slot),a
	ld a,e			; block = BLK_PAIRS + id / 128
	rla
	ld a,d
	rla
	add a,BLK_PAIRS
	call blkport
	out (P_MEM),a
	ld a,e			; source = (id & 7Fh) * 256
	and $7F
	ld h,a
	ld l,0
	ld a,c			; destination F800h + slot * 16
	rrca
	rrca
	rrca
	rrca
	ld e,a
	and $0F
	or $F8
	ld d,a
	ld a,e
	and $F0
	ld e,a
	ld c,LV_SCREEN		; bank = phase
	ld b,CL
.k:	ld a,c
	out (P_LV),a
	push de
	push bc
	REPT 11
	ldi
	ENDR
	pop bc
	pop de
	inc c
	djnz .k
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,(ld_slot)		; HL = the 11 colours -> COLT + 256 k + slot
	ld e,a
	ld d,COLT>>8
	ld b,CL
.c:	ld a,(hl)
	ld (de),a
	inc hl
	inc d
	djnz .c
	ret

; ---------------------------------------------------------------------
cls:	ld a,LV_SCREEN		; codes 80h (black, bank 11)
	out (P_LV),a
	ld hl,$F000
	ld de,$F001
	ld bc,$7FF
	ld (hl),$80
	ldir
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,$F000
	ld de,$F001
	ld bc,$7FF
	ld (hl),STAR_BANK
	ldir
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,$F800
	ld de,$F801
	ld bc,$7FF
	ld (hl),0
	ldir
	xor a
	out (P_COLCTL),a
	; registers: start address 0
	ld a,12
	out (P_CRTCA),a
	xor a
	out (P_CRTCD),a
	ld a,13
	out (P_CRTCA),a
	xor a
	out (P_CRTCD),a
	ret

pcg_clear:			; all 16 banks
	ld c,0
.b:	ld a,c
	or LV_SCREEN
	out (P_LV),a
	ld hl,PCGWIN
	ld de,PCGWIN+1
	ld (hl),0
	push bc
	ld bc,$7FF
	ldir
	pop bc
	inc c
	ld a,c
	cp 16
	jr nz,.b
	ld a,LV_SCREEN
	out (P_LV),a
	ret

; HUD buffers from the texts
hud_build:
	ld hl,hud_t0
	ld de,HUDC
	ld b,80
.c:	ld a,(hl)
	sub 32
	push hl
	ld hl,font_map
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(hl)
	pop hl
	ld (de),a
	inc hl
	inc de
	djnz .c
	ld hl,HUDK
	ld b,40
.k0:	ld (hl),YELLOW
	inc hl
	djnz .k0
	ld b,40
.k1:	ld (hl),BCYAN
	inc hl
	djnz .k1
	ld a,(spdshow)
	add a,$81		; digit codes: 81h + n
	ld (HUDC+32),a
	ld a,(fields)
	dec a
	ld hl,fps50
	jr z,.f
	ld hl,fps25
.f:	ld de,HUDC+34
	ld b,2
.fl:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	djnz .fl
	ld a,(ndr)
	add a,$81
	ld (HUDC+79),a
	ld a,1
	ld (hudd),a
	ret
fps50:	db $86,$81
fps25:	db $83,$86
;            0123456789012345678901234567890123456789
hud_t0:	db "SCORE 000000   STARHIVE   SPEED 2 25FPS "
hud_t1:	db "VIBED BY BPM 2026  0-4 SPEED  W DRONES 4"
hud_attr:	ds 80,STAR_BANK

keys:	ld hl,speedkeys
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
	ld (speed),a
	ld a,6
	sub b
	ld (spdshow),a
	push hl
	push bc
	call hud_build
	pop bc
	pop hl
.n:	inc hl
	djnz .k
	ld a,6			; F: frame rate
	call key1
	ld hl,fkey
	jr z,.fu
	ld a,(hl)
	or a
	jr nz,.w
	ld (hl),1
	ld a,(fields)
	xor 3
	ld (fields),a
	call hud_build
	jr .w
.fu:	ld (hl),0
.w:	ld a,K_W		; W: drones
	call key1
	ld hl,wkey
	jr z,.wu
	ld a,(hl)
	or a
	ret nz
	ld (hl),1
	ld a,(ndr)		; 0, 2, 4, 6, 8 drones
	add a,2
	cp NDRONE+1
	jr c,.dn
	xor a
.dn:	ld (ndr),a
	jp hud_build
.wu:	ld (hl),0
	ret
speedkeys: db $20,0, $21,1, $22,2, $23,4, $24,6

; the score (BCD, 3 bytes) goes up every 16 frames in this test
hud_score:
	ld a,(frame)
	and 15
	ret nz
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
	ld de,HUDC+6
	ld b,3
.d:	ld a,(hl)
	rrca
	rrca
	rrca
	rrca
	and 15
	add a,$81
	ld (de),a
	inc de
	ld a,(hl)
	and 15
	add a,$81
	ld (de),a
	inc de
	inc hl
	djnz .d
	ld a,1
	ld (hudd),a
	ret

; count rising edges of vertical blanking (call at least every ~8000 T)
vschk:	push af
	in a,(P_CRTCA)
	and $20
	push hl
	ld hl,vbprev
	cp (hl)
	jr z,.s
	ld (hl),a
	or a
	jr z,.s
	ld hl,vbcount
	inc (hl)
.s:	pop hl
	pop af
	ret

; wait for a rising edge of the 6545 vertical blanking status
vblank:	in a,(P_CRTCA)
	and $20
	jr nz,vblank
.w:	in a,(P_CRTCA)
	and $20
	jr z,.w
	ret

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

crtc_tab:	db $35,$28,$2C,$34, 27,R5FIX,DROWS,26, $48,CL-1,$20,CL-1, 0,0,0,0

	INCLUDE "input.asm"
	INCLUDE "sprite.asm"
	INCLUDE "objs.asm"
sintab:
	INCLUDE "../build/sin.inc"
objs_init:			; px, py, drones (copied at the start)
	dw 152+16
	db 190+16, 4
objs_init_end:
	INCLUDE "../build/soft.inc"
code_end:
	ASSERT code_end <= COLT

	ORG $E200
top	ds 2
scrS	ds 2
k	ds 1
s88	ds 1
acc	ds 1
step	ds 1
soff	ds 1
speed	ds 1
fields	ds 1
fkey	ds 1
hudd	ds 1
spsave	ds 2
bl_dst	ds 2
bl_base	ds 2
bl_dstb	ds 2
rc_win	ds 1
load_ptr ds 2
load_left ds 1
inp	ds 1
inpold	ds 1
inpedge	ds 1
joyraw	ds 1
ld_slot	ds 1
ps_page	ds 1
ps_n	ds 1
ps_de	ds 2
st_at	ds 2
spdshow	ds 1
vbcount	ds 1
elapsed	ds 1
vbprev	ds 1
sr_ring	ds 2
sr_flag	ds 1
ps_bkt	ds 1
ps_old	ds 1
ps_bk16	ds 2
ps_old16 ds 2
sd_flag	ds 1
bk_s	ds 2*VROWS
pgbank	ds 1
sr_bpa	ds 2
sr_bp	ds 2
sr_strip ds 2
sr_mset	ds 1
sr_dbk	ds 1
sr_dst	ds 2
sd_strip ds 2
sd_sstr	ds 2
sd_ring	ds 2
sd_bpa	ds 2
sr_sp	ds 2
wkey	ds 1
score	ds 3
page	ds 1
nslot	ds 1
nold	ds 1
listcur	ds 2
listold	ds 2
nextent	ds 2
sd_y	ds 1
sd_wb	ds 1
sd_h	ds 1
sd_h2	ds 1
sd_bnd	ds 2
sd_data	ds 2
sd_cx	ds 1
sd_row	ds 1
sd_j	ds 1
sd_n	ds 1
sd_i2	ds 1
sd_rn	ds 1
sr_slot	ds 1
sr_ent	ds 2
sr_pap	ds 1
bs_bank	ds 1
bs_ent	ds 2
bs_pp	ds 2
st_cnt	ds 44
st_ptr	ds 88
frame	ds 1
firecd	ds 1
dphase	ds 1
dl_frame ds 2
px	ds 2
py	ds 1
ndr	ds 1
drones	ds NDRONE*3
shots	ds NSHOTS*3
buls	ds NBULS*3

	SAVEBIN "../build/SHIPTEST.BIN",$8000,code_end-$8000
