;=====================================================================
; HOPPY 2 - core: frame sync, renderer, jobs, sprites, text, sound, input
;=====================================================================

VRAM	equ $7000
LATCH	equ $6800
FSPORT	equ $6FFF		; keyboard read with no row selected: bit7 = field sync

;---------------------------------------------------------------------
; wait_frame: idle until field sync falls, generating current sound.
; Returns at start of vertical blank.  If already in FS-low on entry
; (frame overrun) returns immediately so the render still beats the beam.
;---------------------------------------------------------------------
wait_frame:
	ld hl,FSPORT
	ld a,(hl)
	rla
	jr nc,.late
	ld a,(latch_v)
	ld e,a
	ld a,(snd_n)
	or a
	jr z,.silent
	jp m,.noise
	ld c,a
.tl:	ld a,e
	xor $21
	ld e,a
	ld (LATCH),a
	ld b,c
.td:	ld a,(hl)
	rla
	jr nc,.done
	djnz .td
	jp .tl
.noise:	and $7f
	ld c,a
	ld a,(nseed)
	ld d,a
.nl:	ld a,d
	add a,a
	jr nc,.n1
	xor $1d
.n1:	ld d,a
	rra
	jr nc,.n2
	ld a,e
	xor $21
	ld e,a
	ld (LATCH),a
.n2:	ld b,c
.nd:	ld a,(hl)
	rla
	jr nc,.ndone
	djnz .nd
	jp .nl
.ndone:	ld a,d
	ld (nseed),a
	jr .done
.silent:
	ld a,(hl)
	rla
	jr c,.silent
.done:	ld a,e
	ld (latch_v),a
	ld hl,frame_cnt
	inc (hl)
	ret
.late:	ld a,(overruns)
	inc a
	ld (overruns),a
.lw:	ld a,(hl)		; overran into blanking: skip to the next field
	rla			; so VRAM is only written right after FS falls
	jr nc,.lw
	jp wait_frame

; wait_vb: plain wait for next field sync fall (no overrun shortcut)
wait_vb:
	ld hl,FSPORT
.a:	ld a,(hl)
	rla
	jr nc,.a
	jp wait_frame

; set latch (mode/css) keeping speaker bits
set_css:		; A = 0 or 1
	or a
	ld a,(latch_v)
	res 4,a
	jr z,.z
	set 4,a
.z:	set 3,a
	ld (latch_v),a
	ld (LATCH),a
	ret

;---------------------------------------------------------------------
; Renderer (snow-free): everything is composed in BUF (same layout as
; VRAM) and copied to VRAM only during vertical blank, half per field.
; bands: list of (src.w, stride.w, rows.b), rows=0 ends; drawn from
; screen row in A into BUF.
;---------------------------------------------------------------------
; rowinfo (8 bytes/row): +0,1 key rowbase, +2 key B, +3 sprite last tick,
;                        +4 sprite this tick, +5 needs blit
render_bands:
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	push hl
	ld de,rowinfo
	add hl,de
	push hl
	pop ix
	pop hl
	add hl,hl
	add hl,hl
	ld de,BUF
	add hl,de
	ex de,hl
.band:	ld a,(iy+4)
	or a
	ret z
	ex af,af'
	ld a,(iy+2)		; byte offset B
	ld (.addb+1),a
	ld (.bst+3),a
	ld (.bcp+1),a
	ld c,a
	push de
	add a,a
	ld e,a
	ld d,0
	ld hl,ldi_end
	or a
	sbc hl,de
	ld (.e2+1),hl
	ld a,32
	sub c
	add a,a
	ld e,a
	ld hl,ldi_end
	or a
	sbc hl,de
	ld (.e1+1),hl
	pop de
	ld l,(iy+0)
	ld h,(iy+1)
.row:	ld a,(ix+0)
	cp l
	jr nz,.do
	ld a,(ix+1)
	cp h
	jr nz,.do
	ld a,(ix+2)
.bcp:	cp 0
	jr nz,.do
	ld a,(ix+3)
	or a
	jr nz,.do
	; unchanged: skip
	ld bc,32
	add hl,bc
	ex de,hl
	add hl,bc
	ex de,hl
	jr .nx
.do:	ld (ix+0),l
	ld (ix+1),h
.bst:	ld (ix+2),0
	ld (ix+5),1
	push hl
	ld a,l
.addb:	add a,0
	ld l,a
.e1:	call 0
	pop hl
.e2:	call 0
	ld a,l
	or 31
	ld l,a
	inc hl
.nx:	ld bc,8
	add ix,bc
	ex af,af'
	dec a
	jr z,.nb
	ex af,af'
	jp .row
.nb:	ld bc,5
	add iy,bc
	jp .band
ldi_chain:
	REPT 32
	ldi
	ENDR
ldi_end: ret

; copy rows from BUF to VRAM: A = first row, B = row count (vblank only!)
blit_rows:
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	push hl
	ld de,VRAM
	add hl,de
	ex de,hl
	pop hl
	push bc
	ld bc,BUF
	add hl,bc
	pop bc
	ld a,b
.r:	REPT 32
	ldi
	ENDR
	dec a
	jp nz,.r
	ret

; blit only rows flagged in rowinfo (+5), clearing the flags
blit_dirty:
	ld (bd_n),a		; temp: first row
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,rowinfo+5
	add hl,de
	push hl
	pop ix
	ld a,(bd_n)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	push hl
	ld de,VRAM
	add hl,de
	ex de,hl
	pop hl
	push bc
	ld bc,BUF
	add hl,bc
	pop bc
	ld a,b
.r:	bit 0,(ix+0)
	jr z,.sk
	ld (ix+0),0
	REPT 32
	ldi
	ENDR
	ld bc,8
	add ix,bc
	dec a
	jp nz,.r
	ret
.sk:	ld bc,32
	add hl,bc
	ex de,hl
	add hl,bc
	ex de,hl
	ld bc,8
	add ix,bc
	dec a
	jp nz,.r
	ret

; invalidate all row keys (after restamps / screen changes)
rows_invalidate:
	ld hl,rowinfo+2
	ld de,8
	ld b,64
.l:	ld (hl),$ff
	inc hl
	inc hl
	inc hl
	ld (hl),1		; +5 blit
	dec hl
	dec hl
	dec hl
	add hl,de
	djnz .l
	ret

; end of tick: sprite flags this tick -> last tick
rows_swap:
	ld hl,rowinfo+3
	ld de,8
	ld b,64
.l:	inc hl
	ld a,(hl)
	ld (hl),0
	dec hl
	ld (hl),a
	add hl,de
	djnz .l
	ret

; mark row A as sprite-touched (preserves all but AF)
mark_row:
	cp 64
	ret nc
	push hl
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	push de
	ld de,rowinfo+4
	add hl,de
	pop de
	ld (hl),1
	inc hl
	ld (hl),1
	pop hl
	ret

;---------------------------------------------------------------------
; Draw list: records (handler.w, p0,p1,p2,p3).  Drawn into BUF with
; clipping rows [clip_top,clip_bot] so each half can be drawn separately.
;---------------------------------------------------------------------
jobs_reset:
	ld hl,jobpool
	ld (job_ptr),hl
	ld (hl),0
	inc hl
	ld (hl),0
	ret
jobs_clear	equ jobs_reset

; add_job: HL = handler, C,B,E,D = params
add_job:
	push de
	ex de,hl
	ld hl,(job_ptr)
	push bc
	ld bc,jobpool_end-8
	or a
	sbc hl,bc
	add hl,bc
	pop bc
	jr nc,.full
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	pop de
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (job_ptr),hl
	ld (hl),0
	inc hl
	ld (hl),0
	ret
.full:	pop de
	ret

; draw all jobs with current clip
run_jobs:
	ld hl,jobpool
.l:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,d
	or e
	ret z
	push hl
	call jp_de
	pop hl
	inc hl
	inc hl
	inc hl
	inc hl
	jr .l
jp_de:	push de
	ret
jp_hl:	jp (hl)

; draw one half: A = first row, B = last row, IY = bands
draw_half:
	ld (clip_top),a
	ld c,a
	ld a,b
	ld (clip_bot),a
	ld a,c
	call render_bands
	call run_jobs
	jp parts_draw

; queue_spr: C = x (signed), B = y (signed screen row), DE = sprite
queue_spr:
	ld hl,job_spr
	jp add_job

job_spr:
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	; fall into draw_spr

;---------------------------------------------------------------------
; draw_spr: C = x signed, B = y signed (rows), DE = sprite def.
; target = ds_base (32 bytes/row), clip rows [clip_top, clip_bot]
;---------------------------------------------------------------------
draw_spr:
	; quick reject if no rows fall inside [clip_top, clip_bot]
	ld a,(clip_bot)
	cp b
	jr nc,.y1
	bit 7,b
	ret z			; top below clip_bot (and not negative)
.y1:	ld a,(de)
	add a,b
	dec a			; bottom row (signed)
	bit 7,a
	ret nz
	ld l,a
	ld a,(clip_top)
	dec a
	cp l
	jr c,.y2
	ld a,(clip_top)
	or a
	ret nz
.y2:	ld a,(de)
	ld (ds_h),a
	inc de
	ld a,(de)
	ld (ds_wb),a
	inc de
	ld a,c
	and 3
	add a,a
	ld l,a
	ld h,0
	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld (ds_src),hl
	ld a,c
	sra a
	sra a
	ld (ds_col),a		; signed col
	; jskip = max(0,-col)
	ld d,0
	bit 7,a
	jr z,.c1
	neg
	ld d,a			; jskip
.c1:	; jend = min(wb, 32-col)
	ld a,(ds_col)
	ld e,a
	ld a,32
	sub e			; 32-col  (col may be negative -> >32)
	jp c,.none		; col>32
	ld e,a
	ld a,(ds_wb)
	cp e
	jr c,.c2
	ld a,e
.c2:	; a=jend
	sub d
	jp z,.none
	jp c,.none
	ld (ds_n),a
	ld a,d
	add a,a
	ld (ds_pre),a
	; post = 2*(wb - jend) = 2*wb - 2*jskip - 2*n
	ld a,(ds_wb)
	add a,a
	ld e,a
	ld a,(ds_n)
	add a,a
	ld l,a
	ld a,e
	sub l
	sub d
	sub d
	ld (ds_post),a
	; colstart = col + jskip
	ld a,(ds_col)
	add a,d
	ld (ds_cs),a
	; rows
	ld a,(ds_h)
	ld c,a			; row counter
	ld hl,(ds_src)
.rowl:	; B = current y
	ld a,b
	bit 7,a
	jr nz,.skiprow
	ld e,a
	ld a,(clip_top)
	ld d,a
	ld a,e
	cp d
	jr c,.skiprow
	ld a,(clip_bot)
	cp e
	ret c
	ld a,e
	call mark_row
	; dest = ds_base + y*32 + cs
	push bc
	ld a,e
	ld e,0
	srl a
	rr e
	srl a
	rr e
	srl a
	rr e
	ld d,a
	ld a,(ds_cs)
	or e
	ld e,a
	push hl
	ld hl,(ds_base)
	add hl,de
	ex de,hl
	pop hl
	ld a,(ds_pre)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld a,(ds_n)
	ld b,a
.bl:	ld a,(de)
	and (hl)
	inc hl
	or (hl)
	inc hl
	ld (de),a
	inc de
	djnz .bl
	ld a,(ds_post)
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	pop bc
	jr .nextrow
.skiprow:
	ld a,(ds_wb)
	add a,a
	add a,l
	ld l,a
	jr nc,$+3
	inc h
.nextrow:
	inc b
	dec c
	jr nz,.rowl
.none:	ret

;---------------------------------------------------------------------
; pixels: queue_pix C=x(0..127) B=y E=colour
;---------------------------------------------------------------------
queue_pix:
	bit 7,c
	ret nz
	ld a,b
	cp 64
	ret nc
	ld hl,job_pix
	jp add_job
job_pix:
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld e,(hl)
	ld a,(clip_top)
	ld d,a
	ld a,b
	cp d
	ret c
	ld a,(clip_bot)
	cp b
	ret c
	ld a,b
	call mark_row
plot:			; C=x B=y E=colour (VRAM, no clipping)
	ld a,c
	and 3
	ld d,a
	ld a,e
	add a,a
	add a,a
	add a,d
	ld e,a
	push de
	ld a,b
	ld l,0
	srl a
	rr l
	srl a
	rr l
	srl a
	rr l
	or BUF/256
	ld h,a
	ld a,c
	srl a
	srl a
	or l
	ld l,a
	pop de
	push hl
	ld hl,pixmask
	ld a,d
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld d,(hl)
	ld hl,pixcol
	ld a,e
	add a,l
	ld l,a
	jr nc,$+3
	inc h
	ld e,(hl)
	pop hl
	ld a,(hl)
	and d
	or e
	ld (hl),a
	ret
pixmask: db $3f,$cf,$f3,$fc
pixcol:	db $00,$00,$00,$00, $40,$10,$04,$01, $80,$20,$08,$02, $c0,$30,$0c,$03

;---------------------------------------------------------------------
; Text.  3x5 font in 4-pixel cells.
; text_at: HL = string (0 term, 1 = newline (+6 rows)), D = byte col, E = row
;          (txt_fg, txt_bg) colours, txt_base = buffer, opaque if txt_opq
;---------------------------------------------------------------------
text_setcol:		; A = fg + 16*bg  -> selects precomputed table
	ld (txt_col),a
	push hl
	push de
	ld e,a
	and 3
	ld d,a
	ld a,e
	rrca
	rrca
	and $0c
	or d			; idx = fg + 4*bg
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,txt_tabs
	add hl,de
	ld (txt_tp),hl
	pop de
	pop hl
	ret

txt_init:
	ld hl,txt_tabs
	ld c,0
.l:	ld a,c
	and 3
	ld b,a
	ld a,c
	and $0c
	add a,a
	add a,a
	or b
	push bc
	push hl
	call txt_build
	pop hl
	ld de,16
	add hl,de
	pop bc
	inc c
	ld a,c
	cp 16
	jr nz,.l
	ret

txt_build:		; A = fg + 16*bg, HL = dest table (16 bytes)
	push hl
	push de
	push bc
	ld c,a
	and 3
	ld d,a
	ld a,c
	rrca
	rrca
	rrca
	rrca
	and 3
	ld e,a
	xor a
.v:	push af
	rrca
	rrca
	rrca
	ld c,a
	xor a
	ld (tpat),a
	ld (tmsk),a
	ld b,4
.p:	ld a,(tpat)
	add a,a
	add a,a
	ld (tpat),a
	ld a,(tmsk)
	add a,a
	add a,a
	ld (tmsk),a
	sla c
	jr nc,.bgp
	ld a,(tpat)
	or d
	ld (tpat),a
	jr .np
.bgp:	ld a,(tpat)
	or e
	ld (tpat),a
	ld a,(tmsk)
	or 3
	ld (tmsk),a
.np:	djnz .p
	ld a,(tpat)
	ld (hl),a
	push hl
	ld a,8
	call addhla
	ld a,(tmsk)
	ld (hl),a
	pop hl
	inc hl
	pop af
	inc a
	cp 8
	jr nz,.v
	pop bc
	pop de
	pop hl
	ret

text_at:
	ld (txt_x0),de
	call .mk
.ch:	ld a,(hl)
	inc hl
	or a
	ret z
	cp 1
	jr nz,.nc
	ld de,(txt_x0)
	ld a,e
	add a,6
	ld e,a
	ld (txt_x0),de
	call .mk
	jr .ch
.mk:	ld a,e
	cp 6
	ret c
	ld b,5
.mkl:	push af
	call mark_row
	pop af
	inc a
	djnz .mkl
	ret
.nc:	cp 2			; colour change: next byte
	jr nz,.nc2
	ld a,(hl)
	inc hl
	call text_setcol
	jr .ch
.nc2:	push hl
	push de
	call text_char
	pop de
	pop hl
	inc d
	jr .ch

; text_char: A = ascii, D = col, E = row  (clips col>=32, row 0..63)
text_char:
	ld c,a
	ld a,d
	cp 32
	ret nc
	ld a,c
	cp 96
	jr c,$+4
	sub 32			; lower case -> upper
	sub 32
	ret c
	ld c,a
	ld b,0
	ld h,b
	ld l,c
	add hl,hl
	add hl,hl
	add hl,bc		; *5
	ld bc,font35
	add hl,bc
	push de
	; dest
	ld a,e
	ld c,0
	srl a
	rr c
	srl a
	rr c
	srl a
	rr c
	ld b,a
	ld a,c
	or d
	ld c,a
	ex de,hl		; DE = glyph
	ld hl,(txt_base)
	add hl,bc
	ex de,hl		; HL = glyph, DE = dest
	pop bc			; B = col, C = row
	; fast path: opaque and fully inside clip
	ld a,(txt_opq)
	or a
	jr z,.slow
	ld a,(clip_top)
	cp c
	jr z,.ft
	jr nc,.slow
.ft:	ld a,c
	add a,4
	ld b,a
	ld a,(clip_bot)
	cp b
	jr c,.slow
	ld bc,(txt_tp)
	REPT 5
	ld a,(hl)
	inc hl
	and 7
	or c
	push hl
	ld l,a
	ld h,b
	ld a,(hl)
	pop hl
	ld (de),a
	ld a,e
	add a,32
	ld e,a
	jr nc,$+3
	inc d
	ENDR
	ret
.slow:	ld b,5
.r:	push hl
	ld hl,clip_top
	ld a,c
	cp (hl)
	jr c,.sk1
	inc hl
	ld a,(hl)
	cp c
.sk1:	pop hl
	jr c,.skip
	push bc
	push hl
	ld a,(hl)
	and 7
	ld hl,(txt_tp)
	call addhla
	ld a,(txt_opq)
	or a
	jr z,.tr
	ld a,(hl)
	ld (de),a
	jr .rd
.tr:	ld c,(hl)
	ld a,8
	call addhla
	ld b,(hl)
	ld a,b
	cpl
	and c
	ld c,a
	ld a,(de)
	and b
	or c
	ld (de),a
.rd:	pop hl
	pop bc
.skip:	inc hl
	ex de,hl
	push bc
	ld bc,32
	add hl,bc
	pop bc
	ex de,hl
	inc c
	djnz .r
	ret

; print number: HL = value (16-bit), digits into buffer numbuf (5 chars, 0 term)
num5:	ld de,numbuf
	ld bc,-10000
	call .d
	ld bc,-1000
	call .d
	ld bc,-100
	call .d
	ld bc,-10
	call .d
	ld bc,-1
	call .d
	xor a
	ld (de),a
	ret
.d:	ld a,'0'-1
.l:	inc a
	add hl,bc
	jr c,.l
	sbc hl,bc
	ld (de),a
	inc de
	ret

; strip leading zeros of numbuf (keep last) -> HL points to first significant
num_trim:
	ld hl,numbuf
.l:	ld a,(hl)
	cp '0'
	ret nz
	inc hl
	ld a,(hl)
	or a
	jr nz,.l
	dec hl
	ret

;---------------------------------------------------------------------
; Sound: two channels (music, sfx).  Data: (n, frames) pairs; n=0 rest,
; n>=128 noise; frames=0 end.  sfx overrides music.  snd_tick per frame.
;---------------------------------------------------------------------
sfx_play:		; HL = sfx, A = priority
	ld c,a
	ld a,(m2_on)
	or a
	ret nz
	ld a,(sfx_cnt)
	or a
	jr z,.go
	ld a,(sfx_pri)
	cp c
	jr z,.go
	ret nc
.go:	ld a,c
	ld (sfx_pri),a
	ld a,(hl)
	ld (sfx_n),a
	inc hl
	ld a,(hl)
	ld (sfx_cnt),a
	inc hl
	ld (sfx_ptr),hl
	ret
mus_play:		; HL = tune (loops if mus_loop set)
	ld (mus_start),hl
	ld a,(hl)
	ld (mus_n),a
	inc hl
	ld a,(hl)
	ld (mus_cnt),a
	inc hl
	ld (mus_ptr),hl
	ret
mus_stop:
	xor a
	ld (mus_cnt),a
	ld (mus_n),a
	ret
snd_off:
	xor a
	ld (sfx_cnt),a
	ld (sfx_n),a
	ld (snd_n),a
	jr mus_stop

snd_tick:
	; music
	ld a,(mus_cnt)
	or a
	jr z,.s
	dec a
	ld (mus_cnt),a
	jr nz,.s
	ld hl,(mus_ptr)
	ld a,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld (mus_ptr),hl
	ld (mus_n),a
	ld a,c
	ld (mus_cnt),a
	or a
	jr nz,.s
	ld a,(mus_loop)
	or a
	jr z,.s
	ld hl,(mus_start)
	call mus_play
.s:	ld a,(sfx_cnt)
	or a
	jr z,.out
	dec a
	ld (sfx_cnt),a
	jr nz,.out
	ld hl,(sfx_ptr)
	ld a,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld (sfx_ptr),hl
	ld (sfx_n),a
	ld a,c
	ld (sfx_cnt),a
.out:	ld a,(sfx_cnt)
	or a
	ld a,(sfx_n)
	jr nz,.o2
	ld a,(mus_cnt)
	or a
	ld a,(mus_n)
	jr nz,.o2
	xor a
.o2:	ld (snd_n),a
	ret

;---------------------------------------------------------------------
; Input.  keys bits: 0 up 1 down 2 left 3 right 4 fire 5 pause 6 quit 7 any
;---------------------------------------------------------------------
K_UP equ 1
K_DN equ 2
K_LT equ 4
K_RT equ 8
K_FI equ 16
K_PA equ 32
K_QU equ 64
K_ANY equ 128

read_input:
	ld c,0
	ld a,($68FE)		; row0: Q bit4
	bit 4,a
	jr nz,$+4
	set 0,c
	ld a,($68FD)		; row1: A bit4
	bit 4,a
	jr nz,$+4
	set 1,c
	ld a,($68BF)		; row6: O bit1, P bit4, RETURN bit2
	bit 1,a
	jr nz,$+4
	set 2,c
	bit 4,a
	jr nz,$+4
	set 3,c
	bit 2,a
	jr nz,$+4
	set 5,c
	ld a,($68EF)		; row4: M bit5, ',' bit3, SPACE bit4
	bit 5,a
	jr nz,$+4
	set 2,c
	bit 3,a
	jr nz,$+4
	set 3,c
	bit 4,a
	jr nz,$+4
	set 4,c
	ld a,($68FB)		; row2: X bit1
	bit 1,a
	jr nz,$+4
	set 6,c
	ld a,($6800)		; all rows: any key
	and $3f
	cp $3f
	jr z,$+4
	set 7,c
	ld a,(joy_on)
	or a
	jr z,.nj
	in a,($2c)
	cpl
	and $1f
	or c
	ld c,a
	and $1f
	jr z,.nj
	set 7,c
.nj:	ld a,(keys)
	ld (keys_old),a
	cpl
	and c
	ld (keys_new),a
	ld a,c
	ld (keys),a
	ret

; joystick detection: interface reads idle as all ones (nothing pressed)
joy_detect:
	ld b,16
	ld c,$1f
.l:	in a,($2c)
	and c
	ld c,a
	djnz .l
	ld a,c
	cp $1f
	ld a,1
	jr z,.y
	xor a
.y:	ld (joy_on),a
	ret

;---------------------------------------------------------------------
; misc
;---------------------------------------------------------------------
rand:	; 16-bit xorshift -> A, HL
	ld hl,(seed)
	ld a,h
	rra
	ld a,l
	rra
	xor h
	ld h,a
	ld a,l
	rra
	ld a,h
	rra
	xor l
	ld l,a
	xor h
	ld h,a
	ld (seed),hl
	ret

; HL = HL + A
addhla:	add a,l
	ld l,a
	ret nc
	inc h
	ret

cls_vram:		; A = fill byte
	ld hl,VRAM
	ld de,VRAM+1
	ld bc,2047
	ld (hl),a
	ldir
	ret

; fill a 32-byte "fill row" buffer with byte A (used for solid bands)
fillrow_set:
	ld hl,fillrow
	ld b,32
.l:	ld (hl),a
	inc hl
	djnz .l
	ret
