; =====================================================================
;  REDBACK - Uridium-style shoot-'em-up for the Microbee Premium Plus
;  PHASE 1: technical demo - 40 x 25 PAL, PCG-bitmap capital ship deck,
;  1-pixel smooth scrolling both ways at 50 Hz, animated fighter.
;
;  How the scroll works
;    Scenery is drawn with "pair glyphs": a pair glyph at phase k shows the
;    8 pixels starting k pixels into two neighbouring 8-pixel deck cells.
;    Phase k of every pair slot lives in PCG bank k, so moving the picture
;    one pixel is one attribute write (the bank number) per scenery cell: a
;    PUSH fill of the attribute RAM. Every 8 pixels the CRTC start address
;    moves one cell and one new column of glyph codes is written.
;    Sprites are composited into non-displayed pool banks 8/9.
;  VIBED BY BPM 2026
; =====================================================================
	DEVICE NOSLOT64K
	INCLUDE "hw.inc"
	INCLUDE "../build/data.inc"

SPRIDX	EQU $4000		; sprite index in the PAIRS block

AX	EQU 90			; horizontal thrust, 8.8 px/frame^2
DRAG	EQU 40
VMAX	EQU $0680		; 6.5 px/frame
AY	EQU 110
DRAGY	EQU 60
VYMAX	EQU $0300
TXR	EQU 80			; ship screen x when facing right / left
TXL	EQU 212
NENEMY	EQU 4
POOLMAX	EQU 80
LOADMAX	EQU 6

	ORG $8000
start:	di
	ld sp,STACK
	call hw_init
	ld a,MV_PAIRS
	out (P_MEM),a
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
	ld a,LV_SCREEN|BK_HUD	; HUD font
	out (P_LV),a
	ld hl,font_gl
	ld de,PCGWIN
	ld bc,N_FONT*16
	ldir
	ld a,LV_SCREEN
	out (P_LV),a
	call init_tables
	call init_vars
	call hud_build
	; ---- first screen
	call preload
	call draw_first
	jp main

init_tables:			; Y10 / YM, RES, PCOL, CMAP, SHC
	ld hl,Y10
	ld de,YM
	ld bc,0			; B = quotient, C = remainder
.y:	ld (hl),b
	ld a,c
	ld (de),a
	inc hl
	inc de
	inc c
	ld a,c
	cp 10
	jr nz,.y2
	ld c,0
	inc b
.y2:	ld a,l
	or a
	jr nz,.y
	ld hl,RES
	ld de,RES+1
	ld bc,255
	ld (hl),$FF
	ldir
	ld hl,PCOL
	ld de,PCOL+1
	ld bc,127
	ld (hl),0
	ldir
	ld hl,TOPA
	ld de,TOPA+1
	ld bc,BOTB+$180-TOPA-1
	ld (hl),0
	ldir
	ld hl,SHC
	ld de,SHC+1
	ld bc,$7FF
	ld (hl),$80
	ldir
	ret

init_vars:
	ld hl,VARS
	ld de,VARS+1
	ld bc,$FF
	ld (hl),0
	ldir
	ld hl,S0*8
	ld (xpos),hl
	ld hl,S0
	ld (sdeck),hl
	ld hl,RING0+S0
	ld (sphys),hl
	ld hl,LDQ
	ld (ldqr),hl
	ld (ldqp),hl
	ld hl,TOPA
	ld (tbase),hl
	ld hl,BOTA
	ld (bbase),hl
	ld hl,TOPB
	ld (tprev),hl
	ld hl,BOTB
	ld (bprev),hl
	ld hl,80
	ld (psx),hl
	ld a,60
	ld (pyf+1),a
	ld hl,enemy_init
	ld de,enemies
	ld bc,NENEMY*8
	ldir
	ld a,1
	ld (dirty),a
	ld (hudd),a
	ret
S0	EQU 24

; preload every pair of the resident window [S-2, S+41]
preload:
	ld hl,S0-2
.l:	push hl
	ld a,MV_DECK
	out (P_MEM),a
	call scan_col
	call flush_loads
	pop hl
	inc hl
	ld a,l
	cp S0+42
	jr nz,.l
	ret

; write the first screen: columns, HUD rows, registers
draw_first:
	ld a,LV_SCREEN		; clear everything: codes 80h, attr 0, colour 0
	out (P_LV),a
	ld hl,VIDEO
	ld de,VIDEO+1
	ld bc,$7FF
	ld (hl),$80
	ldir
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,VIDEO
	ld de,VIDEO+1
	ld bc,$7FF
	ld (hl),0
	ldir
	ld a,COL_ON
	out (P_COLCTL),a
	ld hl,PCGWIN
	ld de,PCGWIN+1
	ld bc,$7FF
	ld (hl),0
	ldir
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,MV_DECK
	out (P_MEM),a
	ld b,0			; screen columns 0..39
.c:	push bc
	ld hl,(sphys)
	ld de,40
	add hl,de
	ld e,b
	ld d,0
	add hl,de
	ld (ea0),hl
	ld hl,(sdeck)
	ld e,b
	ld d,0
	add hl,de
	call ent_col
	call commit_ent
	pop bc
	inc b
	ld a,b
	cp 40
	jr nz,.c
	ld a,MV_PAIRS
	out (P_MEM),a
	; the attribute of every playfield cell: bank 0
	ld a,1
	ld (dirty),a
	call set_crtc
	ld a,LV_ATTR
	out (P_LV),a
	call fill
	call hud_edges_all
	ld a,LV_SCREEN
	out (P_LV),a
	call hud_codes
	ld hl,(sphys)
	ld de,PCGWIN
	add hl,de
	ld d,h
	ld e,l
	inc de
	ld (hl),YELLOW
	ld bc,39
	ldir
	ld hl,(sphys)
	ld de,PCGWIN+960
	add hl,de
	ld d,h
	ld e,l
	inc de
	ld (hl),BCYAN
	ld bc,39
	ldir
	xor a
	out (P_COLCTL),a
	ret

set_crtc:
	ld hl,(sphys)
	ld a,12
	out (P_CRTCA),a
	ld a,h
	out (P_CRTCD),a
	ld a,13
	out (P_CRTCA),a
	ld a,l
	out (P_CRTCD),a
	ret

; ---------------------------------------------------------------------
;  the frame loop
; ---------------------------------------------------------------------
main:	call frame_wait
	call commit
	call logic
	jp main

; wait for the start of vertical blanking, counting spare time
frame_wait:
	ld hl,0
.a:	in a,(P_CRTCA)
	and $20
	jr nz,.a
.w:	inc hl
	in a,(P_CRTCA)
	and $20
	jr z,.w
	ld (idle),hl
	ret

; ---------------------------------------------------------------------
;  commit: everything that touches video RAM, in the blanking
; ---------------------------------------------------------------------
commit:	ld a,(stepd)
	or a
	jr z,.ns
	call set_crtc
.ns:	ld a,LV_ATTR
	out (P_LV),a
	ld a,(dirty)
	or a
	call nz,fill
	ld a,(stepd)
	or a
	call nz,hud_edge_attr
	ld a,LV_SCREEN		; codes + colours
	out (P_LV),a
	ld a,COL_ON
	out (P_COLCTL),a
	ld a,(stepd)
	or a
	jr z,.nh
	call hud_codes
	call hud_edge_col
	call commit_ent
	jr .hd
.nh:	ld a,(hudd)
	or a
	call nz,hud_codes
.hd:	xor a
	ld (hudd),a
	ld (stepd),a
	ld (dirty),a
	; ---- the sprite cells: old ones back to scenery, new ones in
	ld a,LV_ATTR
	out (P_LV),a
	ld a,(kph)
	ld c,a
	ld hl,(tprev)
	call restore1
	ld hl,(bprev)
	call restore1
	ld a,(pbank)
	ld e,a
	ld hl,(tbase)
	call new1
	ld hl,(bbase)
	call new1
	ld a,LV_SCREEN
	out (P_LV),a
	ld hl,(tprev)
	call restore2
	ld hl,(bprev)
	call restore2
	ld hl,(tbase)
	call new2
	ld hl,(bbase)
	call new2
	xor a
	out (P_COLCTL),a
	ret

; old sprite cells: attribute k (C) and the scenery colour (LV_ATTR + COL_ON)
restore1:
	ld (csp),sp
	ld sp,hl
.l:	pop hl
	bit 7,h
	jr z,.e
	inc sp
	inc sp
	ld (hl),c
	ld a,h
	and 7
	or SHC>>8
	ld d,a
	ld e,l
	ld a,(de)
	and $7F
	ld e,a
	ld d,PCOL>>8
	ld a,(de)
	set 3,h
	ld (hl),a
	jp .l
.e:	ld sp,(csp)
	ret
; old sprite cells: the scenery code (LV_SCREEN)
restore2:
	ld (csp),sp
	ld sp,hl
.l:	pop hl
	bit 7,h
	jr z,.e
	inc sp
	inc sp
	ld a,h
	and 7
	or SHC>>8
	ld d,a
	ld e,l
	ld a,(de)
	ld (hl),a
	jp .l
.e:	ld sp,(csp)
	ret
; new sprite cells: attribute E (the pool bank) and colour
new1:	ld (csp),sp
	ld sp,hl
.l:	pop hl
	bit 7,h
	jr z,.e
	pop bc
	ld (hl),e
	set 3,h
	ld (hl),b
	jp .l
.e:	ld sp,(csp)
	ret
; new sprite cells: codes
new2:	ld (csp),sp
	ld sp,hl
.l:	pop hl
	bit 7,h
	jr z,.e
	pop bc
	ld (hl),c
	jp .l
.e:	ld sp,(csp)
	ret

; attribute RAM: bank k for every playfield cell (rows 1..23), PUSH fill
fill:	ld a,(kph)
	ld b,a
	ld c,a
	ld hl,(sphys)
	ld de,960
	add hl,de
	ld a,h
	or $F0
	ld h,a
	ld (fsp),sp
	bit 0,l
	jr z,.even
	dec hl
	ld (hl),c		; odd top byte
	ld sp,hl
	ld a,25
.o:	REPT 18
	push bc
	ENDR
	dec a
	jp nz,.o
	REPT 9
	push bc
	ENDR
	ld sp,(fsp)
	ld hl,(sphys)
	ld de,VIDEO+40
	add hl,de
	ld (hl),c		; odd bottom byte
	ret
.even:	ld sp,hl
	ld a,25
.e:	REPT 18
	push bc
	ENDR
	dec a
	jp nz,.e
	REPT 10
	push bc
	ENDR
	ld sp,(fsp)
	ret

; the new column of scenery: codes from SHC, colours from PCOL.
; (ea0) = ring address of its row-1 cell. Needs LV_SCREEN and COL_ON.
commit_ent:
	ld hl,(ea0)
	ld de,VIDEO
	add hl,de
	ex de,hl		; DE = video address
	ld hl,(ea0)
	ld bc,SHC
	add hl,bc		; HL = shadow address
	ld b,PCOL>>8
	ld (csp),sp
	ld sp,40
	ld a,23
.l:	ex af,af'
	ld a,(hl)
	ld (de),a
	and $7F
	ld c,a
	ld a,(bc)
	set 3,d
	ld (de),a
	res 3,d
	add hl,sp
	ex de,hl
	add hl,sp
	ex de,hl
	ex af,af'
	dec a
	jr nz,.l
	ld sp,(csp)
	ret

; the HUD cells entering at the edge: attribute 12 (LV_ATTR window)
hud_edge_attr:
	ld hl,(ea0)		; row-1 cell; the edge cell of row 0 is 40 earlier
	ld de,-40
	add hl,de
	ld a,h
	or $F0
	ld h,a
	ld (hl),BK_HUD
	ld de,960
	add hl,de
	ld (hl),BK_HUD
	ret
; colours of the same two cells (LV_SCREEN + COL_ON)
hud_edge_col:
	ld hl,(ea0)
	ld de,-40+$F800
	add hl,de
	ld (hl),YELLOW
	ld de,960
	add hl,de
	ld (hl),BCYAN
	ret
hud_edges_all:			; attribute RAM, whole HUD rows (LV_ATTR)
	ld hl,(sphys)
	ld de,VIDEO
	add hl,de
	ld d,h
	ld e,l
	inc de
	ld (hl),BK_HUD
	ld bc,39
	ldir
	ld hl,(sphys)
	ld de,VIDEO+960
	add hl,de
	ld d,h
	ld e,l
	inc de
	ld (hl),BK_HUD
	ld bc,39
	ldir
	ret
; HUD codes (LV_SCREEN); colours of the two rows too (COL_ON on)
hud_codes:
	ld hl,(sphys)
	ld de,VIDEO
	add hl,de
	ex de,hl
	ld hl,HUDC
	ld bc,40
	ldir
	ld hl,(sphys)
	ld de,VIDEO+960
	add hl,de
	ex de,hl
	ld hl,HUDC+40
	ld bc,40
	ldir
	ret

; ---------------------------------------------------------------------
;  logic
; ---------------------------------------------------------------------
logic:	call readinp
	ld a,(inp)
	bit 6,a
	jp nz,quit
	ld a,(frameno)
	inc a
	ld (frameno),a
	call player_update
	call scroll_update
	call do_loads
	call sprites_build
	call hud_update
	ret

; ---------------------------------------------------------------------
;  player: thrust, turn state machine, banking, lead
; ---------------------------------------------------------------------
player_update:
	ld a,(inp)
	ld c,a
	ld hl,(vx)
	bit 3,c
	jr z,.nr
	ld de,AX
	add hl,de
	jr .lim
.nr:	bit 2,c
	jr z,.drag
	ld de,-AX
	add hl,de
	jr .lim
.drag:	ld a,h
	or l
	jr z,.lim
	bit 7,h
	jr nz,.dn
	ld de,-DRAG
	add hl,de
	bit 7,h
	jr z,.lim
	ld hl,0
	jr .lim
.dn:	ld de,DRAG
	add hl,de
	bit 7,h
	jr nz,.lim
	ld hl,0
.lim:	push hl
	ld de,VMAX
	or a
	sbc hl,de
	pop hl
	jp m,.l2
	ld hl,VMAX
.l2:	push hl
	ld de,-VMAX
	or a
	sbc hl,de		; hl - (-VMAX): negative if below the limit
	pop hl
	jp p,.l3
	ld hl,-VMAX
.l3:	ld (vx),hl
	; ---- turning
	ld a,(tcount)
	or a
	jr nz,.turning
	bit 2,c			; wants left?
	jr z,.nl
	ld a,(dface)
	or a
	jr nz,.vert		; already left
	ld a,1
	ld (dface),a
	jr .tstart
.nl:	bit 3,c
	jr z,.vert
	ld a,(dface)
	or a
	jr z,.vert
	xor a
	ld (dface),a
.tstart: ld a,1
	ld (tcount),a
	jr .vert
.turning: inc a
	cp 11
	jr c,.ts
	ld a,(dface)
	ld (face),a
	xor a
.ts:	ld (tcount),a
	; ---- vertical
.vert:	ld hl,(vy)
	bit 0,c
	jr z,.nu
	ld de,-AY
	add hl,de
	jr .vl
.nu:	bit 1,c
	jr z,.vd
	ld de,AY
	add hl,de
	jr .vl
.vd:	ld a,h
	or l
	jr z,.vl
	bit 7,h
	jr nz,.vdn
	ld de,-DRAGY
	add hl,de
	bit 7,h
	jr z,.vl
	ld hl,0
	jr .vl
.vdn:	ld de,DRAGY
	add hl,de
	bit 7,h
	jr nz,.vl
	ld hl,0
.vl:	push hl
	ld de,VYMAX
	or a
	sbc hl,de
	pop hl
	jp m,.v2
	ld hl,VYMAX
.v2:	push hl
	ld de,-VYMAX
	or a
	sbc hl,de
	pop hl
	jp p,.v3
	ld hl,-VYMAX
.v3:	ld (vy),hl
	ex de,hl
	ld hl,(pyf)
	add hl,de
	bit 7,d
	jr z,.yp
	jr c,.y2		; moving up: carry = no underflow
	ld hl,0
	ld de,0
	ld (vy),de
	jr .y2
.yp:	push hl
	ld de,(230-12)*256
	or a
	sbc hl,de
	pop hl
	jr c,.y2
	ld hl,(230-12)*256
	ld de,0
	ld (vy),de
.y2:	ld (pyf),hl
	; ---- lead: ease the ship's screen x towards its target
	ld a,(dface)
	or a
	ld hl,TXR
	jr z,.tg
	ld hl,TXL
.tg:	ld de,(psx)
	or a
	sbc hl,de		; diff = target - x
	jr z,.fr
	jr c,.neg
	ld a,h
	or a
	jr nz,.big
	ld a,l
	cp 4
	jr c,.fine
.big:	ld hl,3
	jr .mv
.neg:	ld a,h
	cp $FF
	jr nz,.nbig
	ld a,l
	cp -3
	jr nc,.fine
.nbig:	ld hl,-3
.fine:
.mv:	add hl,de
	ld (psx),hl
	; ---- frame
.fr:	ld a,(tcount)
	or a
	jr z,.nt
	dec a
	srl a			; 0..4
	ld c,a
	ld a,(face)
	or a
	jr nz,.tl
	ld a,F_P_T30
	add a,c
	jr .fs
.tl:	ld a,F_P_T150
	sub c
	jr .fs
.nt:	ld a,(face)
	or a
	ld a,F_P_R
	jr z,.r
	ld a,F_P_L
.r:	ld c,a
	ld hl,(vy)
	ld de,-$00A0
	add hl,de
	bit 7,h
	jr nz,.nd		; vy < 160 / 256: not diving
	ld a,c
	add a,2			; down
	ld c,a
	jr .fe
.nd:	ld hl,(vy)
	ld de,$00A0
	add hl,de
	bit 7,h
	jr z,.fe		; level
	inc c			; up
.fe:	ld a,c
.fs:	ld (pframe),a
	ret

; ---------------------------------------------------------------------
;  scroll: X += vx; the start address and the entering column
; ---------------------------------------------------------------------
scroll_update:
	ld hl,(vx)
	ld a,(xfrac)
	add a,l
	ld (xfrac),a
	ld e,h
	ld d,0
	bit 7,h
	jr z,.p
	ld d,$FF
.p:	ld hl,(xpos)
	adc hl,de
	bit 7,h
	jr z,.nn
	ld hl,0
	ld de,0
	ld (vx),de
	xor a
	ld (xfrac),a
.nn:	push hl
	ld de,XMAX
	or a
	sbc hl,de
	pop hl
	jr c,.ok
	ld hl,XMAX
	ld de,0
	ld (vx),de
	xor a
	ld (xfrac),a
.ok:	ld (xpos),hl
	ld a,l
	and 7
	ld c,a
	ld a,(kph)
	cp c
	jr z,.k1
	ld a,1
	ld (dirty),a
.k1:	ld a,c
	ld (kph),a
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld de,(sdeck)
	ld (sdeck),hl
	or a
	sbc hl,de
	ld a,l
	ld (stepd),a
	or a
	ret z
	ld a,1
	ld (dirty),a
	ld hl,(sdeck)
	ld de,RING0
	add hl,de
	ld (sphys),hl
	ld a,(stepd)
	cp 1
	jr nz,.rev
	; moving right: new column S+39 enters at screen column 39, S+41 must be resident
	ld de,79
	add hl,de
	ld (ea0),hl
	ld a,MV_DECK
	out (P_MEM),a
	ld hl,(sdeck)
	ld de,41
	add hl,de
	call scan_col
	ld hl,(sdeck)
	ld de,39
	add hl,de
	call ent_col
	ret
.rev:	ld de,40
	add hl,de
	ld (ea0),hl
	ld a,MV_DECK
	out (P_MEM),a
	ld hl,(sdeck)
	dec hl
	dec hl
	call scan_col
	ld hl,(sdeck)
	call ent_col
	ret

; HL = deck column q (any value): queue the loads its pairs need (DECK mapped)
scan_col:
	bit 7,h
	ret nz
	push hl
	ld de,NCOLS
	or a
	sbc hl,de
	pop hl
	ret nc
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	add hl,hl
	add hl,hl
	add hl,hl		; 24 q
	ld d,h
	ld e,l
	add hl,hl		; 48 q
	ld bc,REFS_AT
	add hl,bc
	ex de,hl		; HL = slots, DE = refs
	ld b,23
.r:	ld a,(hl)
	or a
	jr z,.sk
	push hl
	push bc
	ld c,a
	add a,a
	ld l,a
	ld h,RES>>8
	ld a,(de)
	cp (hl)
	jr nz,.d
	inc hl
	inc de
	ld a,(de)
	dec de
	cp (hl)
	dec hl
	jr z,.same
.d:	ld a,(de)
	ld (hl),a
	push hl
	ld hl,(ldqp)
	ld (hl),c
	inc hl
	ld (hl),a
	inc hl
	inc de
	ld a,(de)
	dec de
	ld (hl),a
	inc hl
	ld (ldqp),hl
	pop hl
	inc hl
	ld (hl),a
.same:	pop bc
	pop hl
.sk:	inc hl
	inc de
	inc de
	djnz .r
	ret

; HL = deck column jj, (ea0) = ring address of its row-1 cell: SHC codes
ent_col:
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	add hl,hl
	add hl,hl
	add hl,hl
	ex de,hl		; DE = slots
	ld hl,(ea0)
	ld bc,SHC
	add hl,bc
	ld bc,40
	ld a,23
	ex af,af'
.l:	ld a,(de)
	or $80
	ld (hl),a
	inc de
	add hl,bc
	ex af,af'
	dec a
	ret z
	ex af,af'
	jr .l

; carry out the queued pair loads (maps the PAIRS block), at most LOADMAX per
; call; flush_loads takes them all. A column is scanned two columns before it
; can be seen, so a spike is spread over the next frames.
flush_loads:
	ld a,255
	jr dl0
do_loads:
	ld a,LOADMAX
dl0:	ld (ldcnt),a
	ld a,MV_PAIRS
	out (P_MEM),a
	ld hl,(ldqr)
	ld de,(ldqp)
	or a
	sbc hl,de
	ret z
.l:	ld hl,(ldqr)
	ld de,(ldqp)
	or a
	sbc hl,de
	jr z,.empty
	add hl,de
	ld c,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (ldqr),hl
	ex de,hl
	call load_pair
	ld a,(ldcnt)
	dec a
	ld (ldcnt),a
	jr nz,.l
	ret
.empty:	ld hl,LDQ
	ld (ldqr),hl
	ld (ldqp),hl
	ret

; HL = ref in the PAIRS block, C = slot: 8 phases to PCG banks 0-7, colour
load_pair:
	ld a,c
	ld (lp_slot),a
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,h
	or $F8
	ld h,a
	ex de,hl		; DE = F800 + 16 slot, HL = ref
	ld c,LV_SCREEN
	ld b,8
.k:	ld a,c
	out (P_LV),a
	push de
	push bc
	REPT 10
	ldi
	ENDR
	pop bc
	pop de
	inc c
	djnz .k
	ld a,LV_SCREEN
	out (P_LV),a
	ld a,(lp_slot)
	ld e,a
	ld d,PCOL>>8
	ld a,(hl)
	ld (de),a
	ret

; ---------------------------------------------------------------------
;  sprites: composite into the pool bank, build the commit list
; ---------------------------------------------------------------------
sprites_build:
	ld hl,(tbase)
	ld (tprev),hl
	ld hl,(bbase)
	ld (bprev),hl
	ld a,(pool)
	xor 1
	ld (pool),a
	add a,BK_POOL0
	ld (pbank),a
	or LV_SCREEN		; the pool bank stays in the PCG window while we draw
	out (P_LV),a
	ld a,(pool)
	or a
	ld hl,TOPA
	ld de,BOTA
	jr z,.la
	ld hl,TOPB
	ld de,BOTB
.la:	ld (tbase),hl
	ld (tnext),hl
	ex de,hl
	ld (bbase),hl
	ld (bnext),hl
	xor a
	ld (poolcnt),a
	ld hl,PCGWIN
	ld (poolptr),hl
	ld a,(nospr)
	or a
	jr nz,.end
	call enemies_draw	; enemies first, the player last: it wins a shared cell
	ld a,(pframe)
	ld (sp_f),a
	ld hl,(psx)
	ld (sp_x),hl
	ld a,(pyf+1)
	ld (sp_y),a
	call spr_draw
.end:	ld hl,(tnext)		; sentinels
	xor a
	ld (hl),a
	inc hl
	ld (hl),a
	ld hl,(bnext)
	xor a
	ld (hl),a
	inc hl
	ld (hl),a
	ld a,LV_SCREEN
	out (P_LV),a
	ret

; the demo enemies
enemies_draw:
	ld ix,enemies
	ld b,NENEMY
.e:	push bc
	ld a,(ix+4)
	add a,(ix+5)
	ld (ix+4),a
	ld l,a
	ld h,sine>>8		; sine is page aligned
	ld a,(hl)		; signed -63..63
	ld e,a
	rla
	sbc a,a
	ld d,a
	ld l,(ix+0)
	ld h,(ix+1)
	add hl,de
	ld de,(xpos)
	or a
	sbc hl,de		; screen x
	ld (sp_x),hl
	; skip when far off screen
	bit 7,h
	jr z,.pos
	ld a,h
	cp $FF
	jr nz,.skip
	ld a,l
	cp -40
	jr c,.skip
	jr .vis
.pos:	ld a,h
	cp 2
	jr nc,.skip
	cp 1
	jr nz,.vis
	ld a,l
	cp 64
	jr nc,.skip
.vis:	ld a,(ix+4)
	add a,64
	ld l,a
	ld h,sine>>8
	ld a,(hl)
	sra a
	sra a
	add a,(ix+2)
	ld (sp_y),a
	ld a,(frameno)
	rrca
	rrca
	rrca
	and 1
	add a,(ix+3)
	ld (sp_f),a
	call spr_draw
.skip:	ld de,8
	add ix,de
	pop bc
	djnz .e
	ret

; sp_f, sp_x (screen x, signed), sp_y (line in the playfield)
; The index (PAIRS block, 4000h) holds, for each frame / shift / line offset,
; the sprite block's port value, a pointer and the ink. The sprite block
; holds N, then N cells of [dcol, ring delta, row, 10 bytes].
spr_draw:
	ld hl,(sp_x)
	sra h
	rr l
	sra h
	rr l
	sra h
	rr l
	ld a,l
	ld (sp_cx),a
	add a,4			; on screen? cx -4..39
	cp 44
	ret nc
	ld a,(sp_y)
	cp 200
	jr c,.yok
	ld a,199
.yok:	ld l,a
	ld h,Y10>>8
	ld a,(hl)
	ld (sp_r0),a
	inc a			; screen row
	ld e,a
	ld d,0
	ld h,YM>>8
	ld a,(hl)
	ld (sp_yo),a		; line offset
	ld l,e			; a0 = sphys + 40 * row + cx
	ld h,d
	add hl,hl
	add hl,hl
	add hl,hl
	ld b,h
	ld c,l
	add hl,hl
	add hl,hl
	add hl,bc
	ld de,(sphys)
	add hl,de
	ld a,(sp_cx)
	ld e,a
	rla
	sbc a,a
	ld d,a
	add hl,de
	ld (sp_a0),hl
	; index entry = SPRIDX + 4 * (80 f + 10 s + yo)
	ld a,(sp_f)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld d,h
	ld e,l
	add hl,hl
	add hl,hl
	add hl,de		; 80 f
	ld a,(sp_x)
	and 7
	add a,a
	ld b,a
	add a,a
	add a,a
	add a,b			; 10 s
	ld b,0
	ld c,a
	add hl,bc
	ld a,(sp_yo)
	ld c,a
	add hl,bc
	add hl,hl
	add hl,hl
	ld bc,SPRIDX
	add hl,bc
	ld a,(hl)		; port value of the sprite block
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)		; ink
	ld hl,sp_ink
	ld (hl),c
	out (P_MEM),a
	ex de,hl
	ld a,(hl)		; cell count
	inc hl
	or a
	jr z,.done
	ex af,af'
	jp sp_cell
.done:	ld a,MV_PAIRS
	out (P_MEM),a
	ret

; HL = stream, A' = cells left
SPCELL	MACRO ptr
	ld hl,(sp_a0)
	ld e,c
	ld d,0
	add hl,de
	ld a,h			; shadow code and colour
	or $F0
	ld d,a
	ld e,l			; DE = video address
	ld a,h
	add a,SHC>>8
	ld b,a
	ld c,l
	ld a,(bc)
	and $7F
	ld c,a
	ld b,PCOL>>8
	ld a,(bc)
	and $F0
	ld hl,sp_ink
	or (hl)
	ld b,a			; colour
	ld a,(poolcnt)
	ld c,a
	inc a
	ld (poolcnt),a
	ld a,c
	or $80
	ld c,a			; code
	ld hl,(ptr)
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	ld (ptr),hl
	jp sp_copy
	ENDM

sp_cell:
	ld b,(hl)		; dcol
	inc hl
	ld a,(sp_cx)
	add a,b
	cp 40
	jp nc,sp_skip12
	ld c,(hl)		; delta
	inc hl
	ld b,(hl)		; row
	inc hl
	ld a,(poolcnt)
	cp POOLMAX
	jp nc,sp_skip10
	push hl
	ld a,(sp_r0)
	add a,b
	cp 4
	jp c,sp_top
	SPCELL bnext
sp_top:	SPCELL tnext
sp_copy:
	ld de,(poolptr)
	pop hl
	REPT 10
	ldi
	ENDR
	ld a,e
	or 15
	ld e,a
	inc de
	ld (poolptr),de
sp_next:
	ex af,af'
	dec a
	jp z,spr_draw.done
	ex af,af'
	jp sp_cell
sp_skip12: inc hl
	inc hl
sp_skip10: ld de,10
	add hl,de
	jp sp_next

; ---------------------------------------------------------------------
;  HUD
; ---------------------------------------------------------------------
hud_build:
	ld hl,hud_t0
	ld de,HUDC
	ld b,80
.c:	ld a,(hl)
	sub 32
	push hl
	ld hl,fmap
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
	ret

hud_update:
	ld a,(frameno)
	and 7
	ret nz
	ld a,1
	ld (hudd),a
	; idle: iterations * 7 / 128 = percent (36 T per iteration)
	ld hl,(idle)
	ld b,h
	ld c,l
	add hl,hl
	add hl,hl
	add hl,hl
	or a
	sbc hl,bc		; 7 * idle
	ld a,l			; / 128 = H * 2 + L / 128
	rlca
	and 1
	ld b,a
	ld a,h
	add a,a
	add a,b
	cp 100
	jr c,.p
	ld a,99
.p:	ld c,0
.t:	cp 10
	jr c,.t2
	sub 10
	inc c
	jr .t
.t2:	add a,$81
	ld (HUDC+IDLEC+1),a
	ld a,c
	add a,$81
	ld (HUDC+IDLEC),a
	; X
	ld hl,(xpos)
	ld de,HUDC+XC
	ld bc,-1000
	call .dig
	ld bc,-100
	call .dig
	ld bc,-10
	call .dig
	ld a,l
	add a,$81
	ld (de),a
	; velocity: sign and integer part
	ld hl,(vx)
	ld a,(fmap+'+'-32)
	ld c,a
	bit 7,h
	jr z,.vp
	ld a,(fmap+'-'-32)
	ld c,a
	ex de,hl
	ld hl,0
	or a
	sbc hl,de
.vp:	ld a,c
	ld (HUDC+VC),a
	ld a,h
	add a,$81
	ld (HUDC+VC+1),a
	ret
.dig:	ld a,$80
.d1:	inc a
	add hl,bc
	jr c,.d1
	sbc hl,bc
	; (restores HL)
	ld (de),a
	inc de
	ret

XC	EQU 11
VC	EQU 19
IDLEC	EQU 28
hud_t0:	db "REDBACK  X:0000  V:+0  IDLE:00%         "
hud_t1:	db "VIBED BY BPM 2026   PHASE 1 TECH DEMO   "
	ASSERT $-hud_t0 == 80

; ---------------------------------------------------------------------
;  hardware
; ---------------------------------------------------------------------
pcg_clear:
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

; ESC: give CP/M its screen back and warm-boot (what MODES.COM does)
quit:	di
	ld sp,STACK
	xor a
	in a,(P_CLK40)		; the normal dot clock
	ld hl,crtc80
	ld c,0
.r:	ld a,c
	out (P_CRTCA),a
	ld a,(hl)
	out (P_CRTCD),a
	inc hl
	inc c
	ld a,c
	cp 16
	jr nz,.r
	ld a,(EXIT_VID)
	or MV_SAVE
	out (P_MEM),a		; block 16 low, video window as CP/M has it
	ld a,$81
	out (P_LV),a
	ld hl,$2000
	ld de,PCGWIN
	ld bc,$800
	ldir
	ld a,$80
	out (P_LV),a
	ld hl,$1800
	ld de,PCGWIN
	ld bc,$800
	ldir
	ld a,COL_ON
	out (P_COL),a
	ld hl,$1000
	ld de,PCGWIN
	ld bc,$800
	ldir
	xor a
	out (P_COL),a
	ld a,LV_ATTR
	out (P_LV),a
	ld hl,$0800
	ld de,VIDEO
	ld bc,$800
	ldir
	ld a,LV_SCREEN
	out (P_LV),a
	ld hl,$0000
	ld de,VIDEO
	ld bc,$800
	ldir
	xor a
	out (P_LV),a
	out (P_PIOB),a		; speaker off
	ld a,(EXIT_PORT)
	out (P_MEM),a		; CP/M's own lower block
	ei
	jp 0			; CP/M warm boot

; the usual 80 x 24 table (13.5 MHz dot clock)
crtc80: db $6B,$50,$58,$37,$1B,$05,$18,$1A,$48,$0A,$2A,$0A,0,0,0,0

; 40 x 25 cells of 8 x 10, 313 lines (MODES.COM table, verified)
crtc_tab: db $35,$28,$2C,$34,$1E,$03,$19,$1C,$48,$09,$20,$09,0,0,0,0

enemy_init:			; bx lo, bx hi, y, frame, phase, speed, -, -
	dw 330
	db 40, F_D_0, 0, 3, 0, 0
	dw 420
	db 120, F_I_0, 40, 2, 0, 0
	dw 470
	db 80, F_D_0, 90, 4, 0, 0
	dw 560
	db 150, F_D_0, 140, 3, 0, 0
	dw 700
	db 60, F_I_0, 10, 2, 0, 0
	dw 790
	db 130, F_D_0, 200, 5, 0, 0
	dw 900
	db 100, F_I_0, 70, 3, 0, 0
	dw 1000
	db 40, F_D_0, 30, 4, 0, 0

	INCLUDE "input.asm"
	INCLUDE "../build/font.inc"
	ALIGN 256
	INCLUDE "../build/sine.inc"
code_end:
	ASSERT code_end <= SHC

; ---------------------------------------------------------------------
;  variables
; ---------------------------------------------------------------------
	ORG VARS
xpos	ds 2
xfrac	ds 1
vx	ds 2
sdeck	ds 2
kph	ds 1
sphys	ds 2
stepd	ds 1
dirty	ds 1
hudd	ds 1
pool	ds 1
poolcnt	ds 1
tbase	ds 2
tnext	ds 2
tprev	ds 2
bbase	ds 2
bnext	ds 2
bprev	ds 2
pbank	ds 1
poolptr	ds 2
csp	ds 2
fsp	ds 2
ea0	ds 2
ldqp	ds 2
ldqr	ds 2
ldcnt	ds 1
lp_slot	ds 1
idle	ds 2
frameno	ds 1
nospr	ds 1
psx	ds 2
pyf	ds 2
vy	ds 2
face	ds 1
dface	ds 1
tcount	ds 1
pframe	ds 1
sp_f	ds 1
sp_x	ds 2
sp_y	ds 1
sp_cols	ds 1
sp_h	ds 1
sp_r0	ds 1
sp_ink	ds 1
sp_ptr	ds 2
sp_cx	ds 1
sp_cc	ds 1
sp_yo	ds 1
sp_a0	ds 2
sp_n1	ds 1
sp_n2	ds 1
sp_n3	ds 1
sd_a	ds 2
sd_yl	ds 1
sd_n	ds 1
dc_n	ds 1
dc_s	ds 1
ap_sp	ds 2
ap_ent	ds 2
inp	ds 1
inpold	ds 1
inpedge	ds 1
joyraw	ds 1
enemies	ds NENEMY*8
vars_end:
	ASSERT vars_end < STACK-64

	SAVEBIN "../build/REDBACK.BIN",$8000,code_end-$8000
