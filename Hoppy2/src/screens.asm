;=====================================================================
; HOPPY 2 - presentation: scenes, title, story, info, scores, endings
;=====================================================================

;---------------------------------------------------------------------
; scene infrastructure
;---------------------------------------------------------------------
scene_begin:
	call heap_reset
	call jobs_clear
	call parts_clear
	call tick_scene
	xor a
	ld (nlanes),a
	ld (n_anim),a
	ld (cam_y),a
	ld (pcam),a
	ld (keys_acc),a
	ld hl,pops
	ld b,9*MAXPOP
.p:	ld (hl),0
	inc hl
	djnz .p
	ld hl,sc_list
	ld (sc_ptr),hl
	ld (hl),0
	call rows_invalidate
	xor a
	jp set_css

; scene_lane: HL = lane def -> lane added; adds to screen list with 6 rows
scene_lane:
	push hl
	ld a,(nlanes)
	ld (cur_lane),a
	call lane_ptr
	pop hl
	call build_lane
	ld a,(nlanes)
	ld c,a
	inc a
	ld (nlanes),a
	ld b,0			; kind 0 = lane
	ld a,6
	jr sc_add
; scene_static: HL = buffer (32 bytes/row), A = rows
scene_static:
	ld b,1
	ld c,l
	ld d,h
	jr sc_add2
sc_add:	ld d,0
sc_add2:			; B kind, C/D value, A rows
	ld hl,(sc_ptr)
	ld (hl),b
	inc hl
	ld (hl),c
	inc hl
	ld (hl),d
	inc hl
	ld (hl),a
	inc hl
	ld (sc_ptr),hl
	ld (hl),0
	inc hl
	inc hl
	inc hl
	ld (hl),0
	ret

; build full band list from sc_list then split at row 32
scene_bands:
	ld iy,bands
	ld hl,sc_list
.l:	ld a,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld e,(hl)		; rows
	inc hl
	ld a,e
	or a
	jr z,.end
	push hl
	dec hl
	dec hl
	dec hl
	dec hl
	ld a,(hl)
	or a
	jr nz,.st
	; lane C
	push de
	ld a,c
	call lane_ptr
	call lane_src0
	pop de
	jr .put
.st:	ld l,c
	ld h,d
	xor a
.put:	ld (iy+0),l
	ld (iy+1),h
	ld (iy+2),a
	ld (iy+4),e
	ld bc,5
	add iy,bc
	pop hl
	jr .l
.end:	ld (iy+4),0
	; split
	ld ix,bands
	ld iy,bands_top
	ld c,32			; rows left in top
.s:	ld a,(ix+4)
	or a
	jr z,.done
	cp c
	jr nc,.cross
	; whole band to top
	call .copy
	ld a,c
	sub (ix+4)
	ld c,a
	ld de,5
	add ix,de
	jr .s
.cross:	; top gets C rows (if any), rest to bottom
	ld a,c
	or a
	jr z,.bot
	call .copy
	ld (iy-1),c
	; bottom part: src += 32*C, rows -= C
	ld a,(ix+4)
	sub c
	ld (ix+4),a
	ld l,c
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld e,(ix+0)
	ld d,(ix+1)
	add hl,de
	ld (ix+0),l
	ld (ix+1),h
	ld c,0
	ld a,(ix+4)
	or a
	jr nz,.bot
	ld de,5
	add ix,de
.bot:	ld (iy+4),0
	ld iy,bands_bot
.b2:	ld a,(ix+4)
	or a
	jr z,.done2
	call .copy
	ld de,5
	add ix,de
	jr .b2
.done:	ld (iy+4),0
	ld iy,bands_bot
.done2:	ld (iy+4),0
	ret
.copy:	ld a,(ix+0)
	ld (iy+0),a
	ld a,(ix+1)
	ld (iy+1),a
	ld a,(ix+2)
	ld (iy+2),a
	ld a,(ix+4)
	ld (iy+4),a
	ld de,5
	add iy,de
	ret

; lane_src0: IX = lane -> HL = row-0 base (with plane), A = byte offset
lane_src0:
	ld l,(ix+L_BASE)
	ld h,(ix+L_BASE+1)
	bit 0,(ix+L_FLAGS)
	ld a,0
	ret z
	ld a,(ix+L_SI)
	and 3
	add a,a
	ld de,ptab
	add a,e
	ld e,a
	jr nc,$+3
	inc d
	ld a,(de)
	add a,l
	ld l,a
	inc de
	ld a,(de)
	adc a,h
	ld h,a
	ld a,(ix+L_SI)
	rrca
	rrca
	and 31
	ret

; invalidate screen rows A..A+B-1
rows_inval:
.l:	push af
	push bc
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,rowinfo+2
	add hl,de
	ld (hl),$ff
	pop bc
	pop af
	inc a
	djnz .l
	ret

; standard scene tick: render, then move lanes. returns NZ if a key pressed
scene_tick:
	call scene_bands
	call tick
	call lanes_move
	call anim_tick
	call parts_tick
	call pop_tick
	call jobs_reset
	call parts_queue
	call pops_queue
	ld a,(keys_acc)
	push af
	xor a
	ld (keys_acc),a
	pop af
	and K_FI|K_ANY|K_UP|K_DN|K_LT|K_RT
	ret

; draw a sprite into a buffer: DE sprite, C x, B row, HL buffer, A rows in buffer
spr_into:
	ld (ds_base),hl
	dec a
	ld (clip_bot),a
	xor a
	ld (clip_top),a
	call draw_spr
	ld hl,BUF
	ld (ds_base),hl
	ret

;---------------------------------------------------------------------
; big text: 3x5 font doubled (8x10 cells, 2 bytes wide), transparent
; HL = text, D = byte col, E = row, A = colour (0..3); target BUF w/ clip
;---------------------------------------------------------------------
text_big:
	ld c,a
	add a,a
	add a,a
	add a,c
	add a,a
	add a,a
	add a,c
	add a,a
	add a,a
	add a,c			; colour * $55
	ld (tb_fill),a
.ch:	ld a,(hl)
	inc hl
	or a
	ret z
	push hl
	push de
	call big_char
	pop de
	pop hl
	inc d
	inc d
	jr .ch
big_char:		; A = char, D col, E row
	cp 32
	ret c
	sub 32
	ld c,a
	ld b,0
	ld h,b
	ld l,c
	add hl,hl
	add hl,hl
	add hl,bc
	ld bc,font35
	add hl,bc		; glyph
	ld b,5
.r:	ld a,(hl)
	and 7
	push hl
	push bc
	add a,a
	ld hl,bigtab
	call addhla
	ld c,(hl)		; mask bits byte0
	inc hl
	ld b,(hl)		; byte1
	; two scanlines
	ld a,e
	call .row
	inc e
	ld a,e
	call .row
	inc e
	pop bc
	pop hl
	inc hl
	djnz .r
	ret
.row:	; A = row: clip
	push hl
	ld hl,clip_top
	cp (hl)
	jr c,.no
	inc hl
	ld l,(hl)
	cp l
	jr z,.ok
	jr nc,.no
.ok:	push af
	call mark_row
	pop af
	; addr = BUF + row*32 + D
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld a,d
	call addhla
	ld a,h
	or BUF/256
	ld h,a
	ld a,d
	cp 32
	jr nc,.no
	ld a,(tb_fill)
	and c
	push de
	ld e,a
	ld a,c
	cpl
	and (hl)
	or e
	ld (hl),a
	pop de
	inc hl
	ld a,d
	cp 31
	jr nc,.no
	ld a,(tb_fill)
	and b
	push de
	ld e,a
	ld a,b
	cpl
	and (hl)
	or e
	ld (hl),a
	pop de
.no:	pop hl
	ret
bigtab:	db $00,$00, $00,$f0, $0f,$00, $0f,$f0, $f0,$00, $f0,$f0, $ff,$00, $ff,$f0

; job: big text  p0 col, p1 row, p2/3 text ; colour from tb_col
job_big:
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld a,(tb_col)
	jp text_big
queue_big:		; HL text, D col, E row, A colour
	ld (tb_col),a
	ld c,d
	ld b,e
	ex de,hl
	ld hl,job_big
	jp add_job

; job: small text (transparent) p0 col p1 row p2/3 text, colour txt_qcol
job_small:
	ld d,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	push hl
	ld hl,BUF
	ld (txt_base),hl
	xor a
	ld (txt_opq),a
	ld a,(txt_qcol)
	call text_setcol
	pop hl
	jp text_at
queue_small:		; HL text, D col, E row, A colour
	ld (txt_qcol),a
	ld c,d
	ld b,e
	ex de,hl
	ld hl,job_small
	jp add_job

; print into a static buffer (opaque) : HL text, D col, E row, A colour fg+16bg, IX? -> txt_base preset
buf_text:
	push hl
	call text_setcol
	ld a,1
	ld (txt_opq),a
	xor a
	ld (clip_top),a
	ld a,63
	ld (clip_bot),a
	pop hl
	jp text_at

;=====================================================================
; ATTRACT LOOP
;=====================================================================
attract:
	call snd_off
	ld sp,STACK_TOP
	xor a
	ld (demo),a
.loop:	call title_run
	jp nz,.start
	call wipe
	call story_run
	jp nz,.start
	call wipe
	call demo_run
	jp nz,.start
	call info_run
	jp nz,.start
	call wipe
	call scores_run
	jp nz,.start
	call wipe
	jr .loop
.start:	call wipe
	call snd_off
	ld hl,sfx_pick
	ld a,9
	call sfx_play
	jp game_start

demo_exit:
	ld sp,STACK_TOP
	xor a
	ld (demo),a
	call snd_off
	ld a,(keys)
	and K_FI|K_ANY
	jp nz,game_start
	call info_run
	jp nz,game_start
	call scores_run
	jp nz,game_start
	jp attract

;---------------------------------------------------------------------
; TITLE
;---------------------------------------------------------------------
LOGO_ROWS equ 22
lt_cloud1: LANE K_WATER,BG_SKY,0,$0030
	db OT_CLOUD1,0, OT_CLOUD2,12, OT_CLOUD1,20, $ff
lt_cloud2: LANE K_WATER,BG_SKY,0,$0018
	db OT_CLOUD2,4, OT_CLOUD2,22, $ff
lt_road:   LANE K_WATER,BG_ROADK,0,-$00b0
	db OT_CAR,2, OT_TRACTOR,14, OT_RACER,24, $ff
lt_river1: LANE K_WATER,BG_WATER,0,$0040
	db OT_LOG4,6, OT_LOG3,22, $ff
lt_river2: LANE K_WATER,BG_WATER2,0,-$0030
	db OT_LILY,10, OT_T3,16, OT_LILY,28, $ff
lt_bank:   LANE K_STATIC,BG_START,0,0
	db $ff

LTRX:	db 16,32,48,64,80,100		; letter x
LSPR:	dw spr_LH,spr_LO,spr_LP,spr_LP,spr_LY,spr_L2

title_run:
	call scene_begin
	ld hl,lt_cloud1
	call scene_lane
	ld hl,lt_cloud2
	call scene_lane
	; logo area buffer
	ld bc,32*LOGO_ROWS
	call alloc
	ld (logo_buf),hl
	push hl
	ld (hl),$aa
	ld d,h
	ld e,l
	inc de
	ld bc,32*LOGO_ROWS-1
	ldir
	pop hl
	ld a,LOGO_ROWS
	call scene_static
	ld hl,lt_road
	call scene_lane
	ld hl,lt_river1
	call scene_lane
	ld hl,lt_river2
	call scene_lane
	ld hl,lt_bank
	call scene_lane
	; scroller buffer
	ld bc,192
	call alloc
	ld (scr_buf),hl
	push hl
	ld (hl),$aa
	ld d,h
	ld e,l
	inc de
	ld bc,191
	ldir
	pop hl
	ld a,6
	call scene_static
	; sun into logo area
	ld de,spr_sun
	ld c,116
	ld b,1
	ld hl,(logo_buf)
	ld a,LOGO_ROWS
	call spr_into
	; subtitle
	ld hl,(logo_buf)
	ld (txt_base),hl
	ld hl,txt_subtitle
	ld de,$0311
	ld a,$12
	call buf_text
	ld hl,BUF
	ld (txt_base),hl
	; letters start above the screen
	ld hl,ltr_y
	ld b,6
	ld a,-20
.ly:	ld (hl),a
	inc hl
	sub 14
	djnz .ly
	ld hl,ltr_vy
	ld b,6
.lv:	ld (hl),0
	inc hl
	djnz .lv
	xor a
	ld (ltr_done),a
	ld (t_tick),a
	ld (t_tick+1),a
	ld (tongue),a
	ld (mini_on),a
	ld a,90
	ld (fly_x),a
	ld a,40
	ld (fly_y),a
	ld hl,scroll_msg
	ld (scr_ptr),hl
	xor a
	ld (scr_ph),a
	ld a,1
	ld (scr_c),a
	xor a
	ld (theme_done),a
.loop:	call scene_tick
	jp nz,.key
	call title_logic
	ld hl,(t_tick)
	inc hl
	ld (t_tick),hl
	; play the theme once the logo has landed
	ld a,(theme_done)
	or a
	jr nz,.nt
	ld a,(ltr_done)
	cp $3f
	jr nz,.nt
	ld a,1
	ld (theme_done),a
	ld hl,title_cb
	ld (m2_cb),hl
	ld hl,m2_title
	call m2_play
	jr nz,.key
.nt:	ld hl,(t_tick)
	ld de,330
	or a
	sbc hl,de
	jr c,.loop
	xor a
	ret
.key:	or 1
	ret

; one animation step between theme notes: A = keys
title_cb:
	call scene_tick
	push af
	call title_logic
	ld hl,(t_tick)
	inc hl
	ld (t_tick),hl
	pop af
	ret

title_logic:
	; ---- letters drop & bounce
	ld b,0
.ll:	push bc
	ld hl,ltr_done
	ld a,b
	call bitmask
	and (hl)
	jp nz,.lnext
	ld hl,ltr_vy
	ld a,b
	call addhla
	ld a,(hl)
	inc a
	bit 7,a
	jr nz,.vneg
	cp 6
	jr c,.vneg
	ld a,6
.vneg:	ld (hl),a
	ld c,a
	ld hl,ltr_y
	ld a,b
	call addhla
	ld a,(hl)
	add a,c
	ld (hl),a
	bit 7,a
	jr nz,.ldraw
	cp 1
	jr c,.ldraw
	; hit floor: bounce
	ld (hl),1
	ld hl,ltr_vy
	ld a,b
	call addhla
	ld a,(hl)
	cp 3
	jr c,.settle
	neg
	sra a
	ld (hl),a
	push bc
	ld hl,sfx_bonk
	ld a,1
	call sfx_play
	pop bc
	jr .ldraw
.settle:	; stamp into logo buffer
	ld hl,ltr_done
	ld a,b
	call bitmask
	or (hl)
	ld (hl),a
	push bc
	call ltr_stamp
	ld hl,sfx_hop
	ld a,2
	call sfx_play
	pop bc
	ld a,b
	cp 5
	jr nz,.lnext
	; the "2" lands: palette flash + boing
	ld a,3
	ld (flash),a
	ld hl,sfx_1up
	ld a,5
	call sfx_play
	jr .lnext
.ldraw:	; draw falling letter as sprite (screen row = 12 + y)
	ld hl,ltr_y
	ld a,b
	call addhla
	ld a,(hl)
	add a,12
	ld e,a
	ld hl,LTRX
	ld a,b
	call addhla
	ld c,(hl)
	ld a,b
	add a,a
	ld hl,LSPR
	call addhla
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld b,e
	ex de,hl
	call queue_spr
.lnext:	pop bc
	inc b
	ld a,b
	cp 6
	jp nz,.ll
	; palette flash
	ld a,(flash)
	or a
	jr z,.nf
	dec a
	ld (flash),a
	and 1
	call set_css
.nf:	; ---- mascot
	call title_mascot
	; ---- scroller
	call scroller
	; ---- snail
	ld a,(t_tick)
	and 7
	jr nz,.ns
	ld hl,snail_x
	inc (hl)
	ld a,(hl)
	cp 122
	jr c,.ns
	ld (hl),0
	ld hl,txt_snailwin
	ld c,20
	ld b,46
	call popup_at
	ld hl,sfx_1up
	ld a,4
	call sfx_play
.ns:	ld a,(snail_x)
	ld c,a
	ld b,53
	ld de,spr_snailt
	call queue_spr
	; ---- froglet hopping over the logo once letters are down
	ld a,(ltr_done)
	cp $3f
	ret nz
	call mini_frog
	; ---- honk
	ld a,(t_tick)
	cp 200
	ret nz
	ld hl,txt_honk
	ld c,22
	ld b,28
	call popup_at
	ld hl,sfx_rev
	ld a,3
	call sfx_play
	ld a,25
	ld (wide_t),a
	ret

bitmask:	; A = bit -> A = 1<<bit
	ld c,a
	ld a,1
	inc c
.l:	dec c
	ret z
	add a,a
	jr .l

ltr_stamp:	; B = letter index
	ld hl,LTRX
	ld a,b
	call addhla
	ld c,(hl)
	ld a,b
	add a,a
	ld hl,LSPR
	call addhla
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld b,1
	ld hl,(logo_buf)
	ld a,LOGO_ROWS
	call spr_into
	ld a,12
	ld b,LOGO_ROWS
	jp rows_inval

; Hoppy on a lily pad; blinks, croaks, catches the fly
title_mascot:
	ld c,4
	ld b,48
	ld de,spr_pad
	call queue_spr
	; frame
	ld de,spr_hop
	ld a,(wide_t)
	or a
	jr z,.nw
	dec a
	ld (wide_t),a
	ld de,spr_hopw
	jr .fr
.nw:	ld a,(tongue)
	or a
	jr z,.nt
	ld de,spr_hopg
	jr .fr
.nt:	ld a,(t_tick)
	and 63
	cp 60
	jr c,.nb
	ld de,spr_hopb
	jr .fr
.nb:	ld a,(t_tick)
	and $7f
	cp $40
	jr nz,.nck
	ld a,(theme_done)
	or a
	jr z,.nck
	push de
	ld hl,sfx_croak
	ld a,3
	call sfx_play
	pop de
.nck:	ld a,(t_tick)
	and $70
	cp $40
	jr nz,.fr
	ld a,(t_tick)
	and 8
	jr z,.fr
	ld de,spr_hopc
.fr:	ld c,4
	ld b,32
	call queue_spr
	; fly
	ld a,(fly_dead)
	or a
	jr z,.fa
	dec a
	ld (fly_dead),a
	jr nz,.tg
	ld a,110
	ld (fly_x),a
	ld a,30
	ld (fly_y),a
	jr .tg
.fa:	call rand
	and 3
	dec a
	dec a
	ld c,a
	ld a,(fly_x)
	add a,c
	; drift toward the mouth
	cp 40
	jr nc,$+4
	ld a,40
	cp 120
	jr c,$+4
	ld a,119
	ld (fly_x),a
	call rand
	and 3
	sub 2
	ld c,a
	ld a,(fly_y)
	add a,c
	cp 26
	jr nc,$+4
	ld a,26
	cp 44
	jr c,$+4
	ld a,43
	ld (fly_y),a
	ld a,(fly_x)
	cp 60
	jr nc,.fd
	; close enough: zap!
	ld a,(tongue)
	or a
	jr nz,.fd
	ld a,8
	ld (tongue),a
	ld hl,sfx_gulp
	ld a,3
	call sfx_play
.fd:	ld a,(fly_x)
	ld c,a
	ld a,(fly_y)
	ld b,a
	ld de,spr_fly
	ld a,(t_tick)
	and 1
	jr z,$+5
	ld de,spr_fly2
	call queue_spr
.tg:	; tongue
	ld a,(tongue)
	or a
	ret z
	dec a
	ld (tongue),a
	cp 4
	jr nz,.tq
	; fly eaten
	ld a,60
	ld (fly_dead),a
	ld hl,txt_gulp
	ld c,8
	ld b,22
	call popup_at
	ld a,8
	ld (burp_t),a
.tq:	; draw tongue line from mouth (28,40) to fly x
	ld a,(fly_x)
	ld e,a
	ld c,28
	ld b,40
	ld hl,job_tongue
	jp add_job
job_tongue:	; p0 x0 p1 row p2 x1
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
.l:	ld a,c
	cp e
	ret nc
	push bc
	push de
	ld e,3
	call plot
	pop de
	pop bc
	inc c
	jr .l

; little frog hopping across the letter tops
mini_frog:
	ld a,(mini_on)
	or a
	jr nz,.go
	ld a,(t_tick)
	and 127
	cp 100
	ret nz
	ld a,1
	ld (mini_on),a
	xor a
	ld (mini_i),a
	ld (mini_t),a
	ret
.go:	ld hl,mini_t
	inc (hl)
	ld a,(hl)
	cp 8
	jr c,.air
	ld (hl),0
	ld hl,mini_i
	inc (hl)
	ld a,(hl)
	cp 6
	jr c,.land
	xor a
	ld (mini_on),a
	ret
.land:	ld hl,sfx_tock
	ld a,1
	call sfx_play
.air:	; x = LTRX[i] + 2*t ... from letter i to i+1
	ld a,(mini_i)
	ld hl,LTRX
	call addhla
	ld a,(hl)
	add a,5
	ld c,a
	ld a,(mini_t)
	add a,a
	add a,c
	ld c,a
	; y = 10 - parabola
	ld a,(mini_t)
	ld e,a
	ld a,8
	sub e
	ld d,a		; (8-t)
	ld a,e
	call mul8	; t*(8-t) -> a
	srl a
	srl a
	ld e,a
	ld a,10
	sub e
	ld b,a
	ld de,spr_mini
	jp queue_spr
mul8:	; A * D -> A (small)
	ld e,a
	xor a
	inc d
.l:	dec d
	ret z
	add a,e
	jr .l

; scroller: 2 pixels per tick using RLD
scroller:
	ld a,(scr_ph)
	or a
	jr nz,.have
	ld hl,(scr_ptr)
.get:	ld a,(hl)
	or a
	jr nz,.ok
	ld hl,scroll_msg
	jr .get
.ok:	inc hl
	cp 2
	jr nz,.nc
	ld a,(hl)
	inc hl
	ld (scr_c),a
	jr .get
.nc:	ld (scr_ptr),hl
	sub 32
	ld l,a
	ld h,0
	ld c,a
	ld b,0
	add hl,hl
	add hl,hl
	add hl,bc
	ld bc,font35
	add hl,bc
	ld de,scr_glyph
	ld bc,5
	ldir
.have:	ld hl,(scr_buf)
	ld de,32+31
	add hl,de
	ld ix,scr_glyph
	ld b,5
.row:	push bc
	ld a,(ix+0)
	ld c,a
	ld a,(scr_ph)
	or a
	ld a,c
	jr nz,.s2
	rrca
	and 3
	jr .mk
.s2:	and 1
	add a,a
.mk:	ld c,a
	ld a,(scr_c)
	ld d,a
	ld a,2
	bit 1,c
	jr z,$+3
	ld a,d
	add a,a
	add a,a
	ld e,a
	ld a,2
	bit 0,c
	jr z,$+3
	ld a,d
	or e
	ld b,32
.rl:	rld
	dec hl
	djnz .rl
	ld de,64
	add hl,de
	inc ix
	pop bc
	djnz .row
	ld a,(scr_ph)
	xor 1
	ld (scr_ph),a
	ld a,58
	ld b,6
	jp rows_inval

;---------------------------------------------------------------------
; STORY
;---------------------------------------------------------------------
st_pond1: LANE K_WATER,BG_WATER,0,$0018
	db OT_LILY,4, OT_LILY,18, $ff
st_pond2: LANE K_WATER,BG_WATER2,0,-$0018
	db OT_LILY,10, OT_LILY,26, $ff
st_grass: LANE K_STATIC,BG_GRASS,0,0
	db $ff

story_run:
	call scene_begin
	ld bc,32*28
	call alloc
	ld (logo_buf),hl
	push hl
	ld (hl),$aa
	ld d,h
	ld e,l
	inc de
	ld bc,32*28-1
	ldir
	pop hl
	ld a,28
	call scene_static
	ld hl,st_grass
	call scene_lane
	ld hl,st_pond1
	call scene_lane
	ld hl,st_pond2
	call scene_lane
	ld hl,st_pond1
	call scene_lane
	ld hl,st_grass
	call scene_lane
	ld hl,st_grass
	call scene_lane
	ld hl,story_txt
	ld (sty_ptr),hl
	ld hl,(logo_buf)
	ld (txt_base),hl
	ld de,$0102
	ld (sty_pos),de
	xor a
	ld (sty_t),a
	ld (t_tick),a
	ld (t_tick+1),a
	ld a,120
	ld (dz_x),a
	; froglets
	ld hl,frogl
	ld b,6*4
.fz:	ld (hl),0
	inc hl
	djnz .fz
.loop:	call scene_tick
	ret nz
	call story_logic
	ld hl,(t_tick)
	inc hl
	ld (t_tick),hl
	ld de,380
	or a
	sbc hl,de
	jr c,.loop
	xor a
	ret

story_logic:
	; typewriter
	ld hl,(sty_ptr)
	ld a,(hl)
	or a
	jp z,.nt
	cp 1
	jr nz,.ch
	inc hl
	ld (sty_ptr),hl
	ld de,(sty_pos)
	ld d,1
	ld a,e
	add a,6
	ld e,a
	ld (sty_pos),de
	jp .nt
.ch:	cp 3			; clear panel (new page) after pause
	jr nz,.ch2
	ld a,(sty_t)
	inc a
	ld (sty_t),a
	cp 20
	jp c,.nt
	xor a
	ld (sty_t),a
	inc hl
	ld (sty_ptr),hl
	ld hl,(logo_buf)
	push hl
	ld (hl),$aa
	ld d,h
	ld e,l
	inc de
	ld bc,32*28-1
	ldir
	pop hl
	ld de,$0102
	ld (sty_pos),de
	xor a
	ld b,28
	call rows_inval
	jp .nt
.ch2:	inc hl
	ld (sty_ptr),hl
	push af
	ld hl,(logo_buf)
	ld (txt_base),hl
	ld a,1
	ld (txt_opq),a
	xor a
	ld (clip_top),a
	ld a,63
	ld (clip_bot),a
	ld a,$21
	call text_setcol
	pop af
	ld de,(sty_pos)
	cp ' '
	call nz,text_char_keep
	ld de,(sty_pos)
	inc d
	ld (sty_pos),de
	ld hl,BUF
	ld (txt_base),hl
	ld a,e
	ld b,6
	call rows_inval
	ld hl,sfx_type
	ld a,1
	call sfx_play
.nt:	; bulldozer drives in and drains the pond
	ld a,(t_tick)
	and 1
	jr nz,.nd
	ld a,(dz_x)
	cp 70
	jr c,.nd
	dec a
	ld (dz_x),a
.nd:	ld a,(dz_x)
	ld c,a
	ld b,28
	ld de,spr_dozer
	ld a,(t_tick)
	and 2
	jr z,$+5
	ld de,spr_dozer2
	call queue_spr
	; exhaust smoke
	ld a,(t_tick)
	and 3
	jr nz,.ns
	ld a,(dz_x)
	add a,5
	ld c,a
	ld b,28
	ld e,1
	ld d,$e0
	call part_add_xy
.ns:	; froglets leap out of the pond when the dozer arrives
	ld a,(dz_x)
	cp 71
	jr nc,.nfr
	ld a,(t_tick)
	cp 150
	jr nz,.nfr
	call froglets_go
	ld hl,txt_eek
	ld c,10
	ld b,26
	call popup_at
.nfr:	call froglets_tick
	; Hoppy rises at the end
	ld hl,(t_tick)
	ld de,280
	or a
	sbc hl,de
	ret c
	ld a,l
	cp 17
	jr c,$+4
	ld a,17
	ld b,a
	ld a,63
	sub b
	ld b,a
	ld c,8
	ld de,spr_hop
	ld a,(t_tick)
	and 16
	jr z,$+5
	ld de,spr_hopc
	jp queue_spr

text_char_keep:
	push de
	call text_char
	pop de
	ret

; froglets: 6 x (x, y, vx, vy) in frogl
froglets_go:
	ld hl,frogl
	ld b,6
	ld c,20
.l:	ld (hl),c		; x
	inc hl
	ld (hl),40		; y
	inc hl
	push hl
	call rand
	pop hl
	and 3
	inc a
	bit 0,b
	jr z,$+4
	neg
	ld (hl),a		; vx
	inc hl
	push hl
	call rand
	pop hl
	and 3
	add a,5
	neg
	ld (hl),a		; vy
	inc hl
	ld a,c
	add a,14
	ld c,a
	djnz .l
	ld hl,sfx_splash
	ld a,3
	jp sfx_play
froglets_tick:
	ld hl,frogl
	ld b,6
.l:	push bc
	ld a,(hl)
	or a
	jr z,.n
	push hl
	pop ix
	ld a,(ix+0)
	add a,(ix+2)
	ld (ix+0),a
	cp 125
	jr c,.ok
	ld (ix+0),0
	jr .n
.ok:	ld a,(ix+1)
	add a,(ix+3)
	ld (ix+1),a
	ld a,(ix+3)
	inc a
	ld (ix+3),a
	ld a,(ix+1)
	cp 58
	jr c,.dr
	ld (ix+1),58
	ld (ix+3),-5		; bounce hop
.dr:	push hl
	ld c,(ix+0)
	ld b,(ix+1)
	ld de,spr_mini
	call queue_spr
	pop hl
.n:	ld de,4
	add hl,de
	pop bc
	djnz .l
	ret

;---------------------------------------------------------------------
; DEMO: computer plays a random early level
;---------------------------------------------------------------------
demo_run:
	call snd_off
	call game_new
	ld a,1
	ld (demo),a
	call rand
	and 3
	ld (level),a
	ld a,0
	ld (demo_t),a		; 256 ticks ~ 10 s
	ld sp,STACK_TOP
	jp game_start.demo

;---------------------------------------------------------------------
; INFO pages (how to play / troublemakers / treats)
;---------------------------------------------------------------------
info_run:
	ld hl,page1
	call page_run
	ret nz
	ld hl,page2
	call page_run
	ret nz
	ld hl,page3
	jp page_run

; page: text block (with colour codes) + list of (sprite, x, y) pairs, 0 end
page_run:
	push hl
	call scene_begin
	ld bc,2048
	call alloc
	ld (page_buf),hl
	push hl
	ld (hl),$aa
	ld d,h
	ld e,l
	inc de
	ld bc,2047
	ldir
	pop hl
	ld a,64
	call scene_static
	pop hl
	; header: title string pointer, body string pointer, sprite list
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push hl
	ex de,hl
	ld de,(page_buf)
	ld (txt_base),de
	ld de,$0401
	ld a,$23
	call buf_text
	pop hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld (pg_spr),hl
	ex de,hl
	ld de,$0109
	ld a,$21
	call buf_text
	ld hl,BUF
	ld (txt_base),hl
	ld hl,0
	ld (t_tick),hl
.loop:	call scene_tick
	ret nz
	; animated sprites
	ld hl,(pg_spr)
.sl:	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,d
	or e
	jr z,.sd
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	; alternate frame: next sprite in list pair if frame odd (2nd ptr)
	push hl
	ld a,(t_tick)
	and 8
	jr z,.f0
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	or h
	jr z,.f0
	ex de,hl
.f0:	call queue_spr
	pop hl
	inc hl
	inc hl
	jr .sl
.sd:	ld hl,(t_tick)
	inc hl
	ld (t_tick),hl
	ld a,l
	cp 150
	jr c,.loop
	xor a
	ret

;---------------------------------------------------------------------
; HIGH SCORES (8 entries: 3 BCD + 3 chars)
;---------------------------------------------------------------------
NHI	equ 8
hiscore_init:
	ld hl,hi_default
	ld de,hitab
	ld bc,NHI*6
	ldir
	ret

scores_run:
	call scene_begin
	ld bc,2048
	call alloc
	ld (page_buf),hl
	push hl
	ld (hl),$aa
	ld d,h
	ld e,l
	inc de
	ld bc,2047
	ldir
	pop hl
	ld a,64
	call scene_static
	call scores_draw
	ld hl,0
	ld (t_tick),hl
.loop:	call scene_tick
	ret nz
	; hopping frogs either side of the title
	ld a,(t_tick)
	and 7
	ld b,a
	ld a,4
	sub b
	jp p,$+5
	neg
	ld b,a
	ld c,8
	ld de,spr_fup
	push bc
	call queue_spr
	pop bc
	ld c,112
	ld de,spr_fup
	call queue_spr
	; flash the newest entry
	ld a,(hi_new)
	cp NHI
	jr nc,.nn
	ld a,(t_tick)
	and 4
	jr z,.nn
	ld a,(hi_new)
	ld b,a
	add a,a
	add a,b
	add a,a
	add a,12
	ld e,a
	ld d,4
	ld hl,txt_arrow
	ld a,3
	call queue_small
.nn:	ld hl,(t_tick)
	inc hl
	ld (t_tick),hl
	ld a,l
	cp 160
	jr c,.loop
	ld a,NHI
	ld (hi_new),a
	xor a
	ret

scores_draw:
	ld hl,(page_buf)
	ld (txt_base),hl
	ld hl,txt_hiscores
	ld de,$0802
	ld a,$23
	call buf_text
	xor a
	ld (sd_i),a
.l:	ld a,(sd_i)
	ld c,a
	add a,a
	add a,c
	add a,a
	ld (sd_off),a		; i*6
	add a,12
	ld (sd_row),a
	; rank
	ld a,(sd_i)
	add a,'1'
	ld (numbuf),a
	xor a
	ld (numbuf+1),a
	ld hl,numbuf
	ld a,(sd_row)
	ld e,a
	ld d,7
	ld a,$21
	call buf_text
	; score digits
	ld a,(sd_off)
	ld hl,hitab
	call addhla
	ld de,numbuf
	ld b,3
.sd:	ld a,(hl)
	call bcd_out
	inc hl
	djnz .sd
	xor a
	ld (de),a
	ld hl,numbuf
	ld a,(sd_row)
	ld e,a
	ld d,10
	ld a,$20
	call buf_text
	; name
	ld a,(sd_off)
	add a,3
	ld hl,hitab
	call addhla
	ld de,numbuf
	ld bc,3
	ldir
	xor a
	ld (de),a
	ld hl,numbuf
	ld a,(sd_row)
	ld e,a
	ld d,18
	ld a,$21
	call buf_text
	ld hl,sd_i
	inc (hl)
	ld a,(hl)
	cp NHI
	jr nz,.l
	ld hl,BUF
	ld (txt_base),hl
	ret

; insert score; returns A = position (NHI = not placed)
hi_insert:
	ld b,0
	ld hl,hitab
.l:	push hl
	ld de,score
	ld a,(de)
	cp (hl)
	jr nz,.c
	inc de
	inc hl
	ld a,(de)
	cp (hl)
	jr nz,.c
	inc de
	inc hl
	ld a,(de)
	cp (hl)
.c:	pop hl
	jr z,.nx
	jr nc,.ins
.nx:	ld de,6
	add hl,de
	inc b
	ld a,b
	cp NHI
	jr nz,.l
	ld a,NHI
	ret
.ins:	; shift down entries b..NHI-2
	push bc
	push hl
	ld a,NHI-1
	sub b
	jr z,.sk
	ld c,a
	ld b,0
	ld h,b
	ld l,c
	add hl,hl
	add hl,bc
	add hl,hl
	ld b,h
	ld c,l
	ld hl,hitab+NHI*6-7
	ld de,hitab+NHI*6-1
	lddr
.sk:	pop hl
	ld de,score
	ex de,hl
	ldi
	ldi
	ldi
	ld a,'A'
	ld (de),a
	inc de
	ld (de),a
	inc de
	ld (de),a
	pop bc
	ld a,b
	ret

;---------------------------------------------------------------------
; name entry: 3 letters
;---------------------------------------------------------------------
name_entry:
	ld (hi_new),a
	call scene_begin
	ld bc,2048
	call alloc
	ld (page_buf),hl
	push hl
	ld (hl),$aa
	ld d,h
	ld e,l
	inc de
	ld bc,2047
	ldir
	pop hl
	ld a,64
	call scene_static
	ld hl,(page_buf)
	ld (txt_base),hl
	ld hl,txt_newhi
	ld de,$0303
	ld a,$23
	call buf_text
	ld hl,txt_entername
	ld de,$012e
	ld a,$21
	call buf_text
	ld hl,BUF
	ld (txt_base),hl
	ld a,(hi_new)
	ld b,a
	add a,a
	add a,b
	add a,a
	add a,3
	ld hl,hitab
	call addhla
	ld (ne_ptr),hl
	xor a
	ld (ne_i),a
	call scene_tick
	call scene_tick
	ld hl,m2_hi
	call m2_jingle
.loop:	call scene_bands
	call tick
	call parts_tick
	call jobs_reset
	call parts_queue
	; input
	ld a,(keys_acc)
	ld c,a
	xor a
	ld (keys_acc),a
	ld hl,(ne_ptr)
	ld a,(ne_i)
	call addhla
	bit 0,c
	jr z,.nu
	inc (hl)
	ld a,(hl)
	cp 'Z'+1
	jr c,.snd
	ld (hl),' '
	jr .snd
.nu:	bit 1,c
	jr z,.nd
	dec (hl)
	ld a,(hl)
	cp ' '
	jr nc,.snd
	ld (hl),'Z'
	jr .snd
.nd:	ld a,c
	and K_FI|K_RT
	jr z,.nl
	ld a,(hl)
	cp '!'
	jr nc,$+4
	ld (hl),' '
	ld hl,ne_i
	inc (hl)
	ld a,(hl)
	cp 3
	jr nc,.done
	ld hl,(ne_ptr)
	call addhla
	ld (hl),'A'
	ld hl,sfx_pick
	ld a,2
	call sfx_play
	jr .nl
.snd:	ld a,(hl)
	cp 'A'-1
	jr nz,$+4
	ld (hl),' '
	ld hl,sfx_type
	ld a,1
	call sfx_play
.nl:	; draw the three letters big, current one flashing
	ld hl,(ne_ptr)
	ld de,ne_txt
	ld bc,3
	ldir
	xor a
	ld (de),a
	ld hl,ne_txt
	ld de,$0b16
	ld a,1
	call queue_big
	; cursor
	ld a,(t_tick)
	inc a
	ld (t_tick),a
	and 4
	jp z,.loop
	ld a,(ne_i)
	add a,a
	add a,$0b
	ld d,a
	ld e,$22
	ld hl,txt_caret
	ld a,3
	call queue_big
	jp .loop
.done:	ld hl,sfx_1up
	ld a,5
	call sfx_play
	ret

;---------------------------------------------------------------------
; GAME OVER (+ continue)
;---------------------------------------------------------------------
game_over:
	ld a,(demo)
	or a
	jp nz,demo_exit
	ld a,100
	ld (intro_t),a
.l:	call tickA
	call lanes_move
	call anim_tick
	call cam_update
	call build_view
	call queue_world
	ld a,(intro_t)
	srl a
	srl a
	ld b,a
	ld a,30
	sub b
	jp p,$+4
	xor a
	cp 20
	jr c,$+4
	ld a,20
	ld e,a
	ld hl,txt_gameover
	ld d,7
	ld a,3
	call queue_big
	call tickB
	call parts_tick
	ld hl,intro_t
	dec (hl)
	jr nz,.l
	ld hl,m2_over
	call m2_jingle
	; continue?
	ld a,(continues)
	or a
	jr z,.nocont
	ld a,10
	ld (cont_n),a
	ld a,0
	ld (cont_t),a
	xor a
	ld (keys_acc),a
.cl:	call tickA
	call lanes_move
	call build_view
	call queue_world
	ld hl,txt_continue
	ld de,$0414
	ld a,1
	call queue_big
	ld a,(cont_n)
	add a,'0'-1
	ld (ne_txt),a
	xor a
	ld (ne_txt+1),a
	ld hl,ne_txt
	ld de,$0f20
	ld a,3
	call queue_big
	ld hl,txt_contkey
	ld de,$0230
	ld a,1
	call queue_small
	call tickB
	ld a,(keys_acc)
	and K_FI|K_ANY
	jr nz,.cont
	ld hl,cont_t
	inc (hl)
	ld a,(hl)
	cp 25
	jr c,.cl
	ld (hl),0
	ld hl,sfx_tock
	ld a,2
	call sfx_play
	ld hl,cont_n
	dec (hl)
	jr nz,.cl
.nocont:
	call hi_insert
	cp NHI
	jr nc,.nohi
	call name_entry
.nohi:	call snd_off
	call scores_run
	jp attract
.cont:	; continue: score reset, keep level
	call snd_off
	ld hl,continues
	dec (hl)
	call hi_insert
	cp NHI
	call c,name_entry
	xor a
	ld (score),a
	ld (score+1),a
	ld (score+2),a
	ld a,$02
	ld (nextlife),a
	ld a,4
	ld (lives),a
	ld sp,STACK_TOP
	jp game_start.level

;---------------------------------------------------------------------
; LEVEL TALLY
;---------------------------------------------------------------------
tally:
	call scene_begin
	ld bc,2048
	call alloc
	ld (page_buf),hl
	push hl
	ld (hl),$aa
	ld d,h
	ld e,l
	inc de
	ld bc,2047
	ldir
	pop hl
	ld a,64
	call scene_static
	ld hl,(page_buf)
	ld (txt_base),hl
	ld hl,txt_clear
	ld de,$0802
	ld a,$23
	call buf_text
	ld hl,BUF
	ld (txt_base),hl
	call scene_tick
	call scene_tick
	ld hl,m2_clear
	call m2_jingle
	; lines: all home (1000), flies x200 (shown), flawless 3000, tidy 2000
	ld hl,$1000
	ld (tl_pts),hl
	ld hl,txt_t_home
	ld e,12
	call tally_line
	ld a,(flies_lvl)
	or a
	jr z,.nofl
	ld hl,0
	ld b,a
.fl:	ld a,h
	add a,2
	daa
	ld h,a
	djnz .fl
	ld (tl_pts),hl
	ld hl,txt_t_flies
	ld e,20
	call tally_line_shown
.nofl:	ld a,(deaths_lvl)
	or a
	jr nz,.nofw
	ld hl,$3000
	ld (tl_pts),hl
	ld hl,txt_t_flawless
	ld e,28
	call tally_line
.nofw:	ld a,(bays_order)
	cp 5
	jr nz,.notidy
	ld hl,$2000
	ld (tl_pts),hl
	ld hl,txt_t_tidy
	ld e,36
	call tally_line
.notidy:
	ld hl,txt_t_score
	ld e,48
	call tally_total
	ld b,60
.w:	push bc
	call scene_tick
	pop bc
	jr nz,.x
	djnz .w
.x:	ret

tally_line:	; HL text, E row, tl_pts BCD -> counts up and adds
	ld (tl_txt),hl
	ld a,e
	ld (tl_row),a
	ld hl,(page_buf)
	ld (txt_base),hl
	ld hl,(tl_txt)
	ld d,2
	ld a,$21
	call buf_text
	ld hl,(tl_pts)
	ld a,h
	call bcd2
	ld (numbuf),de
	ld a,l
	call bcd2
	ld (numbuf+2),de
	xor a
	ld (numbuf+4),a
	ld hl,numbuf
	ld a,(tl_row)
	ld e,a
	ld d,24
	ld a,$23
	call buf_text
	ld hl,BUF
	ld (txt_base),hl
	ld hl,(tl_pts)
	call add_score
	ld hl,sfx_home
	ld a,3
	call sfx_play
	ld a,(tl_row)
	ld b,8
	call rows_inval
	ld b,20
.w:	push bc
	call scene_tick
	pop bc
	djnz .w
	ret
tally_line_shown equ tally_line
tally_total:
	ld (tl_txt),hl
	ld a,e
	ld (tl_row),a
	ld hl,(page_buf)
	ld (txt_base),hl
	ld hl,(tl_txt)
	ld d,2
	ld a,$21
	call buf_text
	ld hl,score
	ld de,numbuf
	ld b,3
.sd:	ld a,(hl)
	call bcd_out
	inc hl
	djnz .sd
	xor a
	ld (de),a
	ld hl,numbuf
	ld a,(tl_row)
	ld e,a
	ld d,22
	ld a,$23
	call buf_text
	ld hl,BUF
	ld (txt_base),hl
	ld a,(tl_row)
	ld b,8
	jp rows_inval
bcd_out:	; A = BCD -> 2 chars at DE (DE += 2), preserves HL, BC
	push af
	rrca
	rrca
	rrca
	rrca
	and 15
	add a,'0'
	ld (de),a
	inc de
	pop af
	and 15
	add a,'0'
	ld (de),a
	inc de
	ret
bcd2:	; A = BCD -> E = hi char, D = lo char
	push af
	rrca
	rrca
	rrca
	rrca
	and 15
	add a,'0'
	ld e,a
	pop af
	and 15
	add a,'0'
	ld d,a
	ret

;---------------------------------------------------------------------
; VICTORY (after level 8)
;---------------------------------------------------------------------
victory:
	call scene_begin
	ld hl,lt_cloud1
	call scene_lane
	ld hl,lt_cloud2
	call scene_lane
	ld bc,32*28
	call alloc
	ld (logo_buf),hl
	push hl
	ld (hl),$aa
	ld d,h
	ld e,l
	inc de
	ld bc,32*28-1
	ldir
	pop hl
	ld a,28
	call scene_static
	ld hl,lt_river1
	call scene_lane
	ld hl,lt_river2
	call scene_lane
	ld hl,lt_bank
	call scene_lane
	ld hl,lt_bank
	call scene_lane
	ld hl,(logo_buf)
	ld (txt_base),hl
	ld hl,txt_saved
	ld de,$0302
	ld a,$23
	call buf_text
	ld hl,BUF
	ld (txt_base),hl
	call scene_tick
	call scene_tick
	ld hl,m2_win
	call m2_jingle
	ld hl,0
	ld (t_tick),hl
.l:	call scene_tick
	; fireworks
	ld a,(t_tick)
	and 7
	jr nz,.nf
	call rand
	and 127
	ld (bx),a
	call rand
	and 15
	add a,6
	ld (by),a
	ld b,12
.fw:	push bc
	call rand
	and 63
	sub 32
	ld e,a
	call rand
	and 63
	sub 40
	ld d,a
	call rand
	and 3
	or $80
	ld c,a
	ld a,(bx)
	ld l,a
	ld a,(by)
	ld h,a
	call part_add
	pop bc
	djnz .fw
	ld hl,sfx_pop
	ld a,2
	call sfx_play
.nf:	; family: big hoppy + froglets hopping
	ld c,52
	ld b,30
	ld de,spr_hop
	ld a,(t_tick)
	and 16
	jr z,$+5
	ld de,spr_hopc
	call queue_spr
	ld b,0
.fr:	push bc
	ld a,b
	add a,a
	add a,a
	add a,a
	add a,a
	add a,6
	cp 48
	jr c,$+4
	add a,32
	ld c,a
	ld a,(t_tick)
	add a,b
	add a,b
	and 7
	cp 4
	jr c,$+4
	xor 7
	ld e,a
	ld a,50
	sub e
	ld b,a
	ld de,spr_mini
	call queue_spr
	pop bc
	inc b
	ld a,b
	cp 6
	jr nz,.fr
	ld hl,(t_tick)
	inc hl
	ld (t_tick),hl
	ld a,l
	cp 250
	jp c,.l
	ret

;---------------------------------------------------------------------
; curtain wipe: green hedge closes from top and bottom (VRAM, in blank)
;---------------------------------------------------------------------
wipe:
	ld b,0
.l:	push bc
	call wait_vb
	pop bc
	push bc
	; rows 2b,2b+1 and 62-2b, 63-2b
	ld a,b
	add a,a
	call .row2
	pop bc
	push bc
	ld a,b
	add a,a
	ld c,a
	ld a,62
	sub c
	call .row2
	call snd_tick
	pop bc
	inc b
	ld a,b
	cp 16
	jr nz,.l
	ret
.row2:	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,VRAM
	add hl,de
	ld a,$00		; green
	ld b,32
.a:	ld (hl),a
	inc hl
	djnz .a
	ld a,$d5		; red/yellow edge
	ld b,32
.b:	ld (hl),a
	inc hl
	djnz .b
	ret
