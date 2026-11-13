; =====================================================================
;  PART: LIVE ROTOZOOMER - computed as the picture is drawn. Each block
;  of a row is texture[base + O(i)]: base (row's texel, H = v, L = u) in
;  DE, O(i) the offset of block i along the row, the same for every row of
;  a frame, so it is patched into the op's code as immediates each frame.
;  Two blocks a scanline between the music samples, like the plasma: a
;  third of the 24 rows a frame, all in the scanlines: 16.7 pictures a second.
;  Textures: 128 rows of 256 bytes (a 64 x 32 tile repeated) in a RAM
;  block, bytes 80h-FFh: colour RAM bytes in colour, screen codes (dots)
;  in mono. The next texture is built in the background, a row a frame.
; =====================================================================
lv_t	equ pv+0
lv_args	equ pv+2		; the op's arguments' offset in the buffers
lv_y	equ pv+4
lv_seg	equ pv+5		; texture / motion segment 0..LV_NSEG-1
lv_st	equ pv+6		; frames into the segment (16 bit)
lv_a	equ pv+8		; angle 8.8
lv_s	equ pv+10		; zoom (64 = 1 texel a block)
lv_uc	equ pv+12		; the centre, 8.8
lv_vc	equ pv+14
lv_du	equ pv+16		; steps along a row, 8.8
lv_dv	equ pv+18
lv_ru	equ pv+20		; steps down a row
lv_rv	equ pv+22
lv_bu	equ pv+24		; row base accumulators
lv_bv	equ pv+26
lv_vb	equ pv+28		; video base
lv_sp	equ pv+30
lv_bt	equ pv+32		; the texture being built (0: none)
lv_br	equ pv+33		; its next tile row (0-31), then 4 target rows each
lv_bk	equ pv+34		; target row of the 4 (0-3)
lv_tex	equ pv+35		; the texture shown (a block)
lv_ru2	equ pv+36
lv_rv2	equ pv+38
lv_dst	equ pv+40
lv_ph	equ pv+42
lv_otab	equ LP2+256		; 32 words: O(i), i = 0..31 (block i - 16)

LV_LINE	equ 41			; bytes per line of the op
LV_NSEG	equ 5
LV_SEGLEN equ 300		; frames a texture
LV_TEXB	equ 24			; built textures in blocks 24 + n - 1 (n = 1..4)

live_part:
	dw live_jobs, live_init, live_frame, ORD_TUNNEL

; ---- the op. args: base (DE), destination (BC); B = 0 ends
op_live: jp .e
.r:	REPT 16,k
	AUD2
	ld hl,0			; 10  patched: O(2k + 1)
	add hl,de		; 11
	ld a,(hl)		; 7   the right block
	ex af,af'		; 4   A = the left one (computed before)
	ld (bc),a		; 7   the burst
	inc c			; 4
	ld (bc),a		; 7
	inc c			; 4
	ex af,af'		; 4
	ld (bc),a		; 7
	inc c			; 4
	ld (bc),a		; 7
	inc c			; 4
	inc hl			; 6   = 86
	AUD1
	ld hl,0			; 10  patched: O(2k + 2), the next left block
	add hl,de		; 11
	ld a,(hl)		; 7
	ex af,af'		; 4
	inc hl			; 6   = 38
	ENDR
.e:	AUD2
	pop de			; 10
	pop bc			; 10
	ld hl,0			; 10  patched: O(0)
	add hl,de		; 11
	ld a,(hl)		; 7
	ex af,af'		; 4   = 52
	DELAY 34
	AUD1
	ld a,b			; 4
	or a			; 4
	jp z,.x			; 10
	DELAY 10
	jp .r			; 10
.x:	ret
	ASSERT op_live.e - op_live.r == 16 * LV_LINE

live_init:
	ld bc,COLWIN+P_AREA
	ld a,(monomode)
	or a
	jr z,.c
	ld bc,VIDEO+P_AREA
.c:	ld (lv_vb),bc
	ld a,LVT_BLK0		; the first texture came from the disk
	ld (lv_tex),a
	ld a,1
	ld (lv_bt),a		; build texture 1 next
	call lv_seginit
	ld hl,live_build
	jp lp_both

; as the plasma's: 24 rows of 8 lines (2 not displayed: op_sync), S2, F
live_build:
	call lp_begin
	ld a,1
	call lp_top		; 0-2
	ld a,11
	call lp_idle		; 3-13
	ld hl,R12+(P_AREA>>8)*256
	ld de,R13+(P_AREA&255)*256
	call lp_w2		; 14
	ld hl,R9+7*256
	ld de,R4+(P_ROWS+1)*256
	call lp_w2		; 15
	ld hl,R6+P_ROWS*256
	call lp_w1		; 16
	ld de,op_live
	call lp_word		; 17-153
	ld hl,(lpp)
	ld a,l
	ld (lv_args),a
	ld a,h
	and 3
	ld (lv_args+1),a
	ld de,9*4		; 8 rows and the end marker
	add hl,de
	ld (lpp),hl
	ld a,30
	call lp_idle		; 154-183 (op_sync waits 40 lines at most)
	ld de,op_sync
	call lp_word		; to 208
	ld hl,R12+(P_S2>>8)*256
	ld de,R13+(P_S2&255)*256
	call lp_w2		; 208
	ld a,14
	call lp_idle
	ld hl,R9+15*256
	ld de,R4+0*256
	call lp_w2		; 223
	ld a,14
	call lp_idle
	ld hl,R12+(P_F>>8)*256
	ld de,R13+(P_F&255)*256
	call lp_w2		; 238
	ld hl,P_S1
	jp lp_bottom

; ---- a segment's start: its motion's parameters
lv_seginit:
	ld hl,0
	ld (lv_st),hl
	ret

; the motion table: per segment: angle speed (8.8, signed), zoom base,
; zoom swing, zoom speed, drift u, drift v (8.8 signed)
lv_motion:			; (per picture: 16.7 a second)
	dw $0040
	db 150, 30, 3
	dw $00C0, $0040
	dw -$0260
	db 155, 25, 5
	dw $0000, $0100
	dw $00A0
	db 140, 40, 2
	dw $0180, -$0080
	dw -$0100
	db 150, 30, 4
	dw -$00C0, $00C0
	dw $0300
	db 150, 30, 6
	dw $0080, $0140
LV_MSZ	equ 9

live_frame:
	ld hl,(lv_t)
	inc hl
	ld (lv_t),hl
	; ---- the segment
	ld hl,(lv_st)
	inc hl
	ld (lv_st),hl
	ld de,LV_SEGLEN
	or a
	sbc hl,de
	jr c,.ns
	ld hl,0
	ld (lv_st),hl
	ld a,(lv_seg)
	inc a
	cp LV_NSEG
	jr c,.s
	xor a
.s:	ld (lv_seg),a
	; its texture: 0 = the disk's, n = block LV_TEXB + n - 1 (if built)
	or a
	ld b,LVT_BLK0
	jr z,.tx
	ld c,a
	ld hl,lv_bt
	cp (hl)
	jr nc,.ns		; (not built yet: keep the old one)
	ld a,c
	add a,LV_TEXB-1
	ld b,a
.tx:	ld a,b
	ld (lv_tex),a
.ns:	; a new picture every 3 frames, a third of the rows each frame:
	; phase 0 works out the offsets, phase 1 moves (for the next picture)
	call lv_buildstep
	ld a,(lv_ph)
	inc a
	cp 3
	jr c,.p
	xor a
.p:	ld (lv_ph),a
	or a
	call z,lv_offsets
	ld a,(lv_ph)
	dec a
	call z,lv_motion_step
	ld a,(monomode)
	or a
	call z,win_col
	ld a,(monomode)
	or a
	call nz,win_screen
	ld a,(lv_tex)
	call map_blk
	; ---- the 8 rows y = ph + 21, ph + 18 .. ph (pushed downwards as the
	; op's arguments): base(y) = centre + (y - 12) R, the last's =
	; centre + (ph + 9) R
	ld a,(lv_ph)
	add a,9
	ld b,a
	ld hl,(lv_uc)
	ld de,(lv_ru)
.mu:	add hl,de
	djnz .mu
	push hl
	pop ix			; bu
	ld a,(lv_ph)
	add a,9
	ld b,a
	ld hl,(lv_vc)
	ld de,(lv_rv)
.mv:	add hl,de
	djnz .mv
	ld (lv_bv),hl
	; -3R
	ld hl,(lv_ru)
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	ex de,hl
	ld hl,0
	or a
	sbc hl,de
	ld (lv_ru2),hl
	ld hl,(lv_rv)
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	ex de,hl
	ld hl,0
	or a
	sbc hl,de
	ld (lv_rv2),hl
	; the last's destination: vbase + 64 (ph + 21)
	ld a,(lv_ph)
	add a,21
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,(lv_vb)
	add hl,de
	ld (lv_dst),hl
	; SP walks down from the end marker (after 8 rows)
	ld a,(lp_build)
	ld h,a
	ld l,0
	ld de,(lv_args)
	add hl,de
	ld de,35
	add hl,de
	ld (hl),0		; the end marker's B
	dec hl
	dec hl
	dec hl			; = the end of row 7's arguments + 1
	push iy
	ld (lv_sp),sp
	ld sp,hl
	ld iy,(lv_bv)
	ld hl,(lv_dst)
	ld bc,(lv_ru2)
	ld a,8
.r:	ex af,af'
	ld a,ixh
	and 63
	add a,96
	ld e,a
	ld a,iyh
	and 31
	add a,48
	ld d,a
	push hl
	push de
	ld de,(lv_rv2)
	add iy,de
	add ix,bc
	ld de,-192
	add hl,de
	ex af,af'
	dec a
	jr nz,.r
	ld sp,(lv_sp)
	pop iy
	ret

; ---- the motion (once a picture)
lv_motion_step:
	ld a,(lv_seg)
	ld l,a
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,de		; 9 x
	ld de,lv_motion
	add hl,de
	push hl
	pop ix
	; angle += speed
	ld hl,(lv_a)
	ld e,(ix+0)
	ld d,(ix+1)
	add hl,de
	ld (lv_a),hl
	; zoom = base + swing x sin(t x speed) / 128
	ld a,(lv_t)
	ld b,(ix+4)
	call lv_mul8
	ld l,a
	ld h,sin_tab>>8
	ld a,(hl)
	ld e,(ix+3)
	call lv_smul
	add hl,hl
	ld a,h
	add a,(ix+2)
	ld (lv_s),a
	; the centre drifts
	ld hl,(lv_uc)
	ld e,(ix+5)
	ld d,(ix+6)
	add hl,de
	ld (lv_uc),hl
	ld hl,(lv_vc)
	ld e,(ix+7)
	ld d,(ix+8)
	add hl,de
	ld (lv_vc),hl
	; the steps: du = cos x s / 32, dv = sin x s / 32 (8.8)
	ld a,(lv_a+1)
	add a,64
	ld l,a
	ld h,sin_tab>>8
	ld a,(hl)
	ld de,(lv_s)
	call lv_smul
	call lv_sra5
	ld (lv_du),hl
	ld a,(lv_a+1)
	ld l,a
	ld h,sin_tab>>8
	ld a,(hl)
	ld de,(lv_s)
	call lv_smul
	call lv_sra5
	ld (lv_dv),hl
	; down a row (blocks are 4:3): ru = -3/4 dv, rv = 3/4 du
	ld hl,(lv_dv)
	call lv_x34
	ex de,hl
	ld hl,0
	or a
	sbc hl,de
	ld (lv_ru),hl
	ld hl,(lv_du)
	call lv_x34
	ld (lv_rv),hl
	ret

; ---- O(i), i = 0..31 (block i - 16): O(16 + k) = round(k d), O(16 - k)
; = -O(16 + k); then patched into the op
lv_offsets:
	; pushed from i = 31 down: first the values for i = 31: 15 d + .5
	ld hl,(lv_du)
	call lv_x15
	push hl
	ld hl,(lv_dv)
	call lv_x15
	pop ix			; au
	push iy
	push hl
	pop iy			; av
	ld hl,(lv_du)		; BC = -du, DE = -dv
	ex de,hl
	ld hl,0
	or a
	sbc hl,de
	ld b,h
	ld c,l
	ld hl,(lv_dv)
	ex de,hl
	ld hl,0
	or a
	sbc hl,de
	ex de,hl
	ld (lv_sp),sp
	ld sp,lv_otab+64
	ld a,32
	ex af,af'
.o:	ld a,ixh		; O = (high(av) << 8) + sign-extended high(au)
	ld l,a
	ld a,iyh
	bit 7,l
	jr z,.op
	dec a
.op:	ld h,a
	push hl
	add ix,bc
	add iy,de
	ex af,af'
	dec a
	jr z,.od
	ex af,af'
	jr .o
.od:	ld sp,(lv_sp)
	pop iy
	; patch them into the op
	ld hl,(lv_otab)
	ld (op_live.e+12),hl
	REPT 16,k
	ld hl,(lv_otab+(2*k+1)*2)
	ld (op_live.r+k*LV_LINE+10),hl
	IF k < 15
	ld hl,(lv_otab+(2*k+2)*2)
	ld (op_live.r+k*LV_LINE+35),hl
	ENDIF
	ENDR
	ret

; ---- arithmetic
; HL = A (signed) x E (unsigned)
lv_smul:
	ld d,0
	ld hl,0
	ld b,8
	or a
	jp p,.p
	neg
	call .m
	ex de,hl
	ld hl,0
	or a
	sbc hl,de
	ret
.p:	call .m
	ret
.m:	ld c,a
	ld hl,0
	ld b,8
.l:	add hl,hl
	rl c
	jr nc,.n
	add hl,de
.n:	djnz .l
	ret
; HL >>= 5 (arithmetic)
lv_sra5:
	ld b,5
.l:	sra h
	rr l
	djnz .l
	ret
; HL = 3/4 HL
lv_x34:
	ld d,h
	ld e,l
	sra h
	rr l
	sra h
	rr l
	ex de,hl
	or a
	sbc hl,de
	ret
; HL = 15 HL + 128
lv_x15:
	ld d,h
	ld e,l
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	or a
	sbc hl,de
	ld de,128
	add hl,de
	ret
; A = A x B (low byte)
lv_mul8:
	ld c,a
	xor a
	inc b
	jr .t
.l:	add a,c
.t:	djnz .l
	ret

; ---- one step of the background texture build: per frame, either fetch
; tile row r (64 bytes) to LP2 (k = 0), or write it twice across into a
; half of one of the 4 target rows r + 32 m of the texture (k = 1..8).
lv_buildstep:
	ld a,(lv_bt)
	or a
	ret z
	cp LV_NSEG
	ret nc			; all built
	ld a,(lv_bk)
	or a
	jp nz,.wr
	; fetch: texture n's tile (n = 1..4) at LVT_TOFF + 2048 (n - 1) + 64 r
	ld a,LVT_TBLK
	call map_blk
	ld a,(lv_br)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,LVT_TOFF
	add hl,de
	ld a,(lv_bt)
	dec a
	add a,a
	add a,a
	add a,a
	add a,h
	ld h,a
	ld de,LP2
	call lv_ldi64
	ld a,1
	ld (lv_bk),a
	ret
.wr:	; k = 1..8: row r + 32 ((k - 1) >> 1), half (k - 1) & 1
	ld a,(lv_bt)
	add a,LV_TEXB-1
	call map_blk
	ld a,(lv_bk)
	dec a
	ld c,a
	and 6
	add a,a
	add a,a
	add a,a
	add a,a			; 32 m
	ld hl,lv_br
	add a,(hl)
	ld d,a
	ld a,c
	and 1
	rrca			; 0 or 128
	ld e,a
	ld hl,LP2
	call lv_ldi64
	ld hl,LP2
	call lv_ldi64
	ld a,(lv_bk)
	inc a
	cp 9
	jr c,.k
	; the tile row is done
	ld a,(lv_br)
	inc a
	and 31
	ld (lv_br),a
	jr nz,.r0
	ld a,(lv_bt)		; the texture is done
	inc a
	ld (lv_bt),a
.r0:	xor a
.k:	ld (lv_bk),a
	ret

lv_ldi64:
	ld a,4
.l:	REPT 16
	ldi
	ENDR
	dec a
	jr nz,.l
	ret
