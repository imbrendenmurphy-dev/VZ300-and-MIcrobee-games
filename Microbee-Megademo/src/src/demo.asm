; =====================================================================
;  DEMO: start-up, the monitor choice, the part runner, set-up streaming
; =====================================================================

start:	call hw_init
	ld hl,common_jobs
	call jobs_direct
	call select_screen
	ld hl,song
	call mus_start
	ld hl,script
	; (tests: start at part boot_part, the music seeked to it)
	ld a,(boot_part)
	or a
	jr z,.p
	ld b,a
.sk:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push hl
	ex de,hl
	ld de,6
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)		; that part's end position
.sm:	push de
	push bc
	call mus_next_pattern
	pop bc
	pop de
	ld hl,(m_opos)
	or a
	sbc hl,de
	jr c,.sm
	pop hl
	djnz .sk
	ld a,1
	ld (m_tick),a
	xor a
	ld (m_row),a
.p:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,d
	or e
	jr z,.end
	push hl
	ex de,hl
	call part_run
	pop hl
	jr .p
.end:	jp start

boot_part	db 0		; (poked by the tests)

; ---------------------------------------------------------------------
;  part_run: HL = part descriptor:
;    dw jobs, dw init, dw frame, dw end (music order position)
;  The set-up jobs are streamed with the screen blank (the music plays),
;  then init runs once (it must be short), then frame every frame (in
;  the vertical blanking: it builds the next line program) until the
;  music reaches the end position or SPACE is pressed.
; ---------------------------------------------------------------------
part_run:
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push hl
	ex de,hl
	call jobs_stream
	pop hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld (pr_frame),bc
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld (pr_end),bc
	; clear the part variables
	push de
	ld hl,pv
	ld de,pv+1
	ld bc,PV_SIZE-1
	ld (hl),0
	ldir
	call crtc_park		; the init may take longer than a frame
	ld a,64
	ld (r1val),a
	pop hl
	call jphl		; init
.f:	call mus_tick
	ld hl,(pr_frame)
	call jphl
	call lp_swap
	call kernel_run
	ld hl,(pframes)
	inc hl
	ld (pframes),hl
	; the end?
	ld a,(pv_done)
	or a
	ret nz
	ld hl,(m_opos)
	ld de,(pr_end)
	or a
	sbc hl,de
	ret nc
	ld a,K_SPACE
	call key1
	jr z,.f
	; skip: wait for the key to be released (still playing)
.rel:	call mus_tick
	ld hl,(pr_frame)
	call jphl
	call lp_swap
	call kernel_run
	ld a,K_SPACE
	call key1
	jr nz,.rel
	ret

; ---------------------------------------------------------------------
;  set-up jobs. HL = list: db kind, dw dst, dw len, db block, dw src.
;  kind: 0 screen RAM, 1 attribute RAM, 2 colour RAM, 10h+n PCG bank n;
;  +40h mono only, +20h colour only; FFh the end.
; ---------------------------------------------------------------------
; job_open: HL = job -> sets the window, maps the source, st_src/st_dst,
; BC = length; HL = next job. Z if the job is skipped (wrong mode).
job_open:
	ld a,(hl)
	ld (jb_kind),a
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld a,(hl)
	inc hl
	push af			; block
	ld a,(hl)
	inc hl
	push hl
	ld h,(hl)
	ld l,a
	ld (st_src),hl
	pop hl
	inc hl
	pop af
	; the mode flags
	push af
	ld a,(jb_kind)
	and $60
	jr z,.any
	cp $40
	ld a,(monomode)
	jr z,.mo
	xor 1
.mo:	or a
	jr nz,.any
	pop af
	xor a			; Z: skip
	ret
.any:	pop af
	call map_blk
	ld a,(jb_kind)
	and $1F
	cp $10
	jr nc,.pcg
	push hl
	ld hl,VIDEO
	add hl,de
	ld (st_dst),hl
	pop hl
	or a
	jr z,.scr
	dec a
	jr z,.att
	call win_col
	ld a,(jb_kind)		; colour RAM is at F800
	push hl
	ld hl,COLWIN
	add hl,de
	ld (st_dst),hl
	pop hl
	jr .ok
.scr:	call win_screen
	jr .ok
.att:	call win_attr
	jr .ok
.pcg:	call win_pcg
	push hl
	ld hl,PCGWIN
	add hl,de
	ld (st_dst),hl
	pop hl
.ok:	or 1			; NZ
	ret

; outside the kernel: all at once (start-up only)
jobs_direct:
.j:	ld a,(hl)
	cp $FF
	ret z
	call job_open
	jr z,.j
	push hl
	ld hl,(st_src)
	ld de,(st_dst)
	ldir
	pop hl
	jr .j

; inside the kernel: streamed, the screen blank, the music playing
jobs_stream:
	xor a
	ld (r1val),a
	ld (js_left),a
	ld (js_left+1),a
.f:	ld (js_ptr),hl
	; this frame's chunk
	ld hl,(js_left)
	ld a,h
	or l
	jr nz,.cont
	; the next job
	ld hl,(js_ptr)
.nj:	ld a,(hl)
	cp $FF
	jp z,.done
	call job_open
	jr z,.nj
	ld (js_ptr),hl
	ld (js_left),bc
	jr .chunk
.cont:	; the job's window and block are still set (nothing else changed them)
	ld a,(cur_blk)
	call map_blk
.chunk:	; small rest: copy it now
	ld hl,(js_left)
	ld de,8
	or a
	sbc hl,de
	jr nc,.big
	ld bc,(js_left)
	ld hl,(st_src)
	ld de,(st_dst)
	ldir
	ld hl,0
	ld (js_left),hl
	ld hl,(js_ptr)
	jr .f
.big:	; m = min(230, (left - 3) / 5)
	ld hl,(js_left)
	ld de,3
	or a
	sbc hl,de
	ld c,5
	call div16_8		; HL = (left-3)/5
	ld a,h
	or a
	jr nz,.max
	ld a,l
	cp 230
	jr c,.m
.max:	ld a,230
.m:	ld (js_m),a
	; left -= 5m + 3
	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,hl
	add hl,de
	inc hl
	inc hl
	inc hl
	ex de,hl
	ld hl,(js_left)
	or a
	sbc hl,de
	ld (js_left),hl
	; the line program: blank screen, the stream, the bottom
	call mus_tick
	call lp_begin
	ld a,1
	call lp_top		; 0-2
	ld a,(js_m)
	call lp_stream		; 3 .. m + 4
	ld a,(js_m)
	ld b,a
	ld a,239-5
	sub b
	call lp_idle
	ld hl,0
	call lp_bottom
	call lp_swap
	call kernel_run
	ld hl,(js_ptr)
	jp .f
.done:	ret

; HL / C -> HL (quotient)
div16_8:
	xor a
	ld b,16
.l:	add hl,hl
	rla
	cp c
	jr c,.n
	sub c
	inc l
.n:	djnz .l
	ret

; ---------------------------------------------------------------------
;  the monitor choice (before the music; the standard 64 x 16 screen)
; ---------------------------------------------------------------------
select_screen:
	call win_attr
	ld hl,VIDEO
	ld bc,$800
	ld e,BK_FONT
	call fill
	call win_col
	ld hl,COLWIN
	ld bc,$800
	ld e,WHITE
	call fill
	call win_screen
	ld hl,VIDEO
	ld bc,$800
	ld e,$80
	call fill
	ld hl,sel_text
.l:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,d
	or e
	jr z,.k
	ex de,hl
	ld bc,VIDEO
	add hl,bc
	ex de,hl
	call print
	jr .l
.k:	call crtc_text
.w:	ld a,K_C
	call key1
	ld b,0
	jr nz,.set
	ld a,K_M
	call key1
	ld b,1
	jr z,.w
.set:	ld a,b
	ld (monomode),a
	jp crtc_safe

; HL = string (0-terminated), DE = screen RAM address (window set)
print:	ld a,(hl)
	inc hl
	or a
	ret z
	add a,$80-32
	ld (de),a
	inc de
	jr print

sel_text:
	dw 3*64+21
	db "MICROBEE  MEGADEMO",0
	dw 4*64+22
	db "VIBED BY BPM 2026",0
	dw 7*64+14
	db "FOR THE MICROBEE PREMIUM PLUS",0
	dw 8*64+14
	db "1 MEGABYTE RAM  -  32K PCG RAM",0
	dw 11*64+15
	db "PRESS  C  FOR A COLOUR MONITOR",0
	dw 12*64+15
	db "PRESS  M  FOR A MONOCHROME ONE",0
	dw 14*64+16
	db "(SPACE SKIPS TO THE NEXT PART)",0
	dw 0
