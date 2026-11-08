; =====================================================================
;  PART: VECTOR - a lit, dithered torus, every picture precomputed into
;  6 RAM blocks. The kernel streams the next picture into the hidden PCG
;  bank, 640 bytes a frame (4 bytes a scanline in one burst), so a new
;  picture shows every 3 frames; then screens A (bank 1) / B (bank 2)
;  are flipped.
; =====================================================================
vc_t	equ pv+0
vc_args	equ pv+2		; the op's arguments' offset in the buffers
vc_k	equ pv+4		; the third of the picture this frame (0-2)
vc_j	equ pv+5		; the picture within its block
vc_blk	equ pv+6
vc_show	equ pv+7		; 0: A shown (B written), 1: B shown

vector_part:
	dw vector_jobs, vector_init, vector_frame, ORD_CREDITS

vector_init:
	ld a,VC_BLK0
	ld (vc_blk),a
	ld hl,VC_S1
	ld (s1_addr),hl
	ld hl,vector_build
	jp lp_both

; 0-2 top, 14: the main screen's address, 15: 14 rows, 16-176: the copy,
; then op_sync, the bottom row's address, the bottom
vector_build:
	call lp_begin
	ld a,1
	call lp_top		; 0-2
	ld a,11
	call lp_idle		; 3-13
	ld hl,R12+(VC_A>>8)*256
	ld de,R13+(VC_A&255)*256
	call lp_w2		; 14 (patched: A or B)
	ld hl,R9+15*256
	ld de,R4+13*256
	call lp_w2		; 15: 14 rows of 16 lines
	ld hl,R6+12*256
	call lp_w1		; 16: the last two (208-239) not displayed: the
				; blanking flag rises at 208 for op_sync
	ld de,op_vcopy
	call lp_word		; 17-177
	ld hl,(lpp)
	ld a,l
	ld (vc_args),a
	ld a,h
	and 3
	ld (vc_args+1),a
	ld de,0
	call lp_word		; the source
	ld de,PCGWIN
	call lp_word		; the destination
	ld de,161
	call lp_word		; lines
	ld de,op_sync
	call lp_word		; to the next blanking flag edge (line ~208)
	ld a,30
	call lp_idle		; 208-237
	ld hl,R12+(VC_F>>8)*256
	ld de,R13+(VC_F&255)*256
	call lp_w2		; 238: inside the main frame's last row
	ld hl,VC_S1
	jp lp_bottom
VC_W0	equ 3*6+4+3		; the main address' R12 byte (R13 at +2)

vector_frame:
	ld hl,(vc_t)
	inc hl
	ld (vc_t),hl
	; the next third; after the third one, flip and move on a picture
	ld a,(vc_k)
	inc a
	cp 3
	jr c,.k
	ld a,(vc_show)
	xor 1
	ld (vc_show),a
	ld a,(vc_j)
	inc a
	cp VC_PER
	jr c,.j
	ld a,(vc_blk)
	inc a
	cp VC_BLK0+VC_NBLK
	jr c,.b
	ld a,VC_BLK0
.b:	ld (vc_blk),a
	xor a
.j:	ld (vc_j),a
	xor a
.k:	ld (vc_k),a
	; the shown screen's address
	ld a,(lp_build)
	ld h,a
	ld l,VC_W0
	ld de,VC_A
	ld a,(vc_show)
	or a
	jr z,.a
	ld de,VC_B
.a:	ld (hl),d
	inc hl
	inc hl
	ld (hl),e
	; the hidden bank (B's is 2 when A is shown) in the PCG window
	ld a,(vc_show)
	xor 1
	add a,LV_SCREEN+1
	out (P_LV),a
	xor a
	out (P_COLCTL),a
	ld a,(vc_blk)
	call map_blk
	; source = 1920 j + 640 k, destination = F800 + 640 k
	ld a,(vc_j)
	ld l,a
	ld h,0
	ld de,1920
	call mul16_8
	push hl
	ld a,(vc_k)
	ld l,a
	ld h,0
	ld de,640
	call mul16_8
	ex de,hl		; DE = 640 k
	pop hl
	add hl,de
	push hl			; the source
	ld hl,PCGWIN
	add hl,de
	ex de,hl		; DE = the destination
	ld a,(lp_build)
	ld h,a
	ld l,0
	ld bc,(vc_args)
	add hl,bc
	pop bc
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	ld (hl),e
	inc hl
	ld (hl),d
	ret

; HL = L x DE (L small)
mul16_8:
	ld b,l
	ld hl,0
	inc b
	jr .t
.m:	add hl,de
.t:	djnz .m
	ret
