; =====================================================================
;  PLAY: a level from start to end. Logic every other frame (12.5 a
;  second, as the original), drawing every frame, bilbies halfway between
;  their last two positions on the in-between frames.
; =====================================================================
NCRT	equ 40
CSZ	equ 16
NPART	equ 18
C_ST	equ 0
C_XL	equ 1
C_XH	equ 2
C_Y	equ 3
C_DIR	equ 4
C_AN	equ 5
C_FL	equ 6
C_CNT	equ 7
C_BT	equ 8
C_PXL	equ 9		; position before the last tick (for drawing in between)
C_PXH	equ 10
C_PY	equ 11
ST_NONE	equ 0
ST_WALK	equ 1
ST_FALL	equ 2
ST_FLOAT	equ 3
ST_CLIMB	equ 4
ST_HOIST	equ 5
ST_BLOCK	equ 6
ST_BUILD	equ 7
ST_SHRUG	equ 8
ST_BASH	equ 9
ST_MINE	equ 10
ST_DIG	equ 11
ST_SPLAT	equ 12
ST_DROWN	equ 13
ST_EXIT	equ 14
ST_OHNO	equ 15
ST_GONE	equ 16
ST_HOME	equ 17
STEPUP	equ 2
STEPDN	equ 2
DEATHFALL	equ 24
FLOATAT	equ 4
NBRICK	equ 12
BOMBTICKS	equ 63
SK_CLIMB	equ 0
SK_DIG	equ 7
BT_PAUSE	equ 10
BT_NUKE	equ 11
MASK	equ WMASK

; ---- start the level in the WORLD block (already unpacked there)
level_start:
	MEMV BLK_WORLD
	ld hl,WHDR+LH_N
	ld de,v_ncrt
	ld bc,4+8
	ldir			; n, rate, save, minutes, skills
	ld a,(v_rate)
	ld (v_minrate),a
	ld a,(WHDR+LH_LWB)
	ld (v_lwb),a
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	ld (v_lw),hl
	ld hl,WHDR+LH_LH
	ld de,v_lh
	ld bc,13
	ldir			; lh hx.w hy ex.w ey brick wy wx0.w wx1.w
	ld a,(monomode)		; mono: bright ink on dark paper everywhere, so the
	or a			; bilbies show without recolouring their cells
	ld a,0
	jr nz,.spk
	ld a,(WHDR+LH_SPRINK)
.spk:	ld (sprink),a
	ld a,(WHDR+LH_NSTEEL)
	ld (v_nsteel),a
	ld hl,WHDR+LH_STEEL
	ld de,v_steel
	ld bc,48
	ldir
	ld hl,WSCRIPT
	ld de,SCRIPT
	ld bc,128
	ldir
	; game state (as the original game_init)
	ld hl,CRT
	ld de,CRT+1
	ld bc,NCRT*CSZ+NPART*7-1
	ld (hl),0
	ldir
	xor a
	ld (v_released),a
	ld (v_saved),a
	ld (v_lost),a
	ld (v_reltimer),a
	ld (v_hatch),a
	ld (v_paused),a
	ld (v_nuke),a
	ld (v_nukeidx),a
	ld (v_end),a
	ld (v_hcount),a
	ld (v_secfr),a
	ld (v_loop),a
	ld (v_quit),a
	ld a,(v_title)		; everyone floats on the title
	or a
	jr z,.sf
	ld a,2
.sf:	ld (v_spawnfl),a
	ld hl,0
	ld (v_gtick),hl
	ld hl,-100
	ld (v_nukeask),hl
	ld a,(v_min)
	ld l,a
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	or a
	sbc hl,de
	add hl,hl
	add hl,hl		; x60
	ld (v_tleft),hl
	ld a,2+SK_DIG		; the first skill that's available
	ld (v_sel),a
	ld hl,v_skill
	ld b,8
	ld c,2
.fs:	ld a,(hl)
	or a
	jr nz,.got
	inc hl
	inc c
	djnz .fs
	jr .sc
.got:	ld a,c
	ld (v_sel),a
.sc:	; the view starts on the hatch: (hx*2 - 160) / 8
	ld hl,(v_hx)
	add hl,hl
	ld de,-160
	add hl,de
	jr c,.s1
	ld hl,0
.s1:	srl h
	rr l
	srl h
	rr l
	srl h
	rr l
	ld a,l
	call set_scroll
	ld a,(vscroll)
	ld (scr_want),a
	ld hl,256
	ld (cur_x),hl
	ld a,80
	ld (cur_y),a
	call render_reset
	call hud_init
	ld a,(v_demo)
	or a
	ld hl,SCRIPT
	call nz,demo_start
	ret

; A = wanted first column -> clamped to 0 .. lwb/2 - 64
set_scroll:
	ld c,a
	ld a,(v_lwb)
	srl a			; level width in Microbee byte columns = lwb*4*2/8
	sub 64
	jr nc,.p
	xor a
.p:	cp c
	jr nc,.ok
	ld c,a
.ok:	ld a,c
	ld (vscroll),a
	ret

; ---- play the level. Returns when it ends (or is abandoned).
play_level:
	call level_start
	call sfx_off
	xor a
	ld (fields),a
.loop:	call controls
	ld a,(v_quit)
	or a
	jp nz,sfx_off
	ld a,(v_loop)
	inc a
	ld (v_loop),a
	rra
	jr c,.half
	; logic frame: tick, then draw halfway between the old and new positions
	call save_prev
	MEMV BLK_WORLD
	call game_tick
	call demo_tick
	call sfx_tick
.tick_done:
	ld a,(heavy)
	xor 1
	ld (interp),a
	jr .draw
.half:	xor a
	ld (interp),a
	ld a,(heavy)
	or a
	jr z,.draw
	call clock		; busy: no in-between frame
	call hud_update
	ld a,2
	call waitfields
	jp .loop
.draw:	call clock
	call hover
	call draw_frame
	call hud_update
	; heavy when a logic frame's work ran past 3 fields (decided each tick)
	ld a,(v_loop)
	rra
	jr c,.nh
	ld a,(vcount)
	cp 3
	ld a,0
	jr c,.hs
	inc a
.hs:	ld (heavy),a
	ld a,(v_title)		; the title with music: draw on game updates only,
	ld hl,mus_on		; so the music gets most of the time
	and (hl)
	jr z,.nh
	ld (heavy),a
.nh:	ld a,2
	call waitfields
	ld a,(rpage)
	call show_page
	ld a,(rpage)
	xor 1
	ld (rpage),a
	ld a,(v_end)
	or a
	jp z,.loop
	; let the last sounds and sparks finish
	ld b,25
.w:	push bc
	MEMV BLK_WORLD
	call part_tick
	call draw_frame
	ld a,2
	call waitfields
	ld a,(rpage)
	call show_page
	ld a,(rpage)
	xor 1
	ld (rpage),a
	pop bc
	djnz .w
	ret

; keep each bilby's position before the tick
save_prev:
	ld hl,CRT+C_XL
	ld de,CRT+C_PXL
	ld a,NCRT
.l:	ldi
	ldi
	ldi
	ld bc,CSZ-3
	add hl,bc
	ex de,hl
	add hl,bc
	ex de,hl
	dec a
	jr nz,.l
.snd20:	call vschk
	SND 90
	ret

; ---- the clock (as the original: two fields a loop)
clock:
	ld a,(v_paused)
	or a
	ret nz
	ld a,(v_secfr)
	add a,2
	cp 50
	jr c,.s
	ld hl,(v_tleft)
	ld a,h
	or l
	jr z,.z
	dec hl
	ld (v_tleft),hl
.z:	xor a
.s:	ld (v_secfr),a
	ret

; ---------------------------------------------------------------------
;  drawing a frame on the hidden page
; ---------------------------------------------------------------------
draw_frame:
.snd24:	SND 16
	ld a,(scr_want)
	ld (vscroll),a
	call scroll_sync
	call render_begin
	call restore
	call draw_crts
	call draw_parts
	call draw_cursor
	jp apply_colours

; frame tables per state: (first index entry address, frames)
draw_crts:
	ld ix,CRT
	ld b,NCRT
.l:	push bc
	ld a,(ix+C_ST)
	or a
	jr z,.n
	cp ST_GONE
	jr nc,.n
	call draw_crt
	call vschk
.snd4:	SND 17
.n:	pop bc
	ld de,CSZ
	add ix,de
	djnz .l
	ret

; draw creature IX
draw_crt:
	push ix
	; frame: SFTAB[st] = base entry address (dw), frames (db)
	ld a,(ix+C_ST)
	ld l,a
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,de		; x3
	ld de,SFTAB-3
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)		; frames
	ld a,(ix+C_AN)
	cp c
	jr c,.f1
	ld a,c
	dec a
.f1:	bit 0,(ix+C_DIR)
	jr z,.f2
	add a,c			; facing left: the second half
.f2:	ld l,a
	ld h,0
	ld b,h
	ld c,l
	add hl,hl
	add hl,bc		; x3
	add hl,de
	push hl			; index entry
	; x: 2X (or X + PX between ticks)
	ld l,(ix+C_XL)
	ld h,(ix+C_XH)
	ld a,(interp)
	or a
	jr z,.x2
	ld e,(ix+C_PXL)
	ld d,(ix+C_PXH)
	push hl
	or a
	sbc hl,de
	inc hl
	inc hl
	ld a,h
	or a
	jr nz,.xj
	ld a,l
	cp 5
	jr nc,.xj
	pop hl
	add hl,de		; X + PX
	jr .xd
.xj:	pop hl
.x2:	add hl,hl
.xd:	; screen x of the frame's left edge = x - scroll*8 - AX
	ld a,(rs_scroll)
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ex de,hl
	or a
	sbc hl,de
	ld de,-SPR_AX
	add hl,de
	ld b,h
	ld c,l
	; y: top = 2Y + 1 - AY (+32)
	ld a,(ix+C_Y)
	ld e,a
	ld a,(interp)
	or a
	jr z,.y2
	ld a,(ix+C_PY)
	sub e
	add a,2
	cp 5
	ld a,e
	jr nc,.y2
	add a,(ix+C_PY)
	jr .yd
.y2:	ld a,e
	add a,a
.yd:	add a,1-SPR_AY+32
	ld e,a
	pop hl
	call draw_sprite
	pop ix
	; a bomber's countdown over its head
	bit 2,(ix+C_FL)
	ret z
	ld a,(ix+C_ST)
	cp ST_OHNO
	ret z
	ld a,(ix+C_BT)		; seconds left: 63 ticks = 5
	ld b,0
.dv:	inc b
	sub 13
	jr nc,.dv
	ld a,b
	cp 6
	jr c,.d5
	ld a,5
.d5:	dec a
	ld l,a
	ld h,0
	ld e,l
	ld d,h
	add hl,hl
	add hl,de
	ld de,SPRIDX+SF_DIGIT*3
	add hl,de
	push hl
	ld l,(ix+C_XL)
	ld h,(ix+C_XH)
	add hl,hl
	ld a,(rs_scroll)
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ex de,hl
	or a
	sbc hl,de
	ld de,-4
	add hl,de
	ld b,h
	ld c,l
	ld a,(ix+C_Y)
	add a,a
	sub 28
	jr nc,.dy
	xor a
.dy:	add a,32
	ld e,a
	pop hl
	jp draw_sprite

; sparks: x2.w (half VZ pixels), y2 (half rows), vx, vy, life, colour
draw_parts:
	ld ix,PART
	ld b,NPART
.l:	push bc
	ld a,(ix+5)
	or a
	jr z,.n
	ld l,(ix+0)		; Microbee x = x2 (2 per VZ pixel = 1 per half)
	ld h,(ix+1)
	ld a,(rs_scroll)
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ex de,hl
	or a
	sbc hl,de
	dec hl
	ld b,h
	ld c,l
	ld a,(ix+2)
	add a,32-1
	ld e,a
	ld hl,SPRIDX+SF_SPARK*3
	call draw_sprite
.n:
.snd19:	SND 6
	pop bc
	ld de,7
	add ix,de
	djnz .l
	ret

; the cursor: a cross, or a box over a bilby that can take the skill
draw_cursor:
	ld a,(cur_y)
	cp 160
	ret nc			; on the panel: the button lights instead
	ld hl,SPRIDX+SF_CURS*3
	ld a,(v_hcount)
	or a
	jr z,.c0
	ld hl,SPRIDX+(SF_CURS+1)*3
.c0:	push hl
	ld hl,(cur_x)
	ld de,-8
	add hl,de
	ld b,h
	ld c,l
	ld a,(cur_y)
	add a,32-8
	ld e,a
	ld a,(sprink)
	push af
	xor a
	ld (sprink),a
	pop af
	pop hl
	push af
	call draw_sprite
	pop af
	ld (sprink),a
	ret

; ---------------------------------------------------------------------
;  controls
; ---------------------------------------------------------------------
controls:
	ld a,(v_demo)
	or a
	jp nz,demo_controls
	call read_controls	; ct_now / kb_now, mouse movement into the cursor
	ld a,(kb_now)
	ld c,a
	ld a,(kb_old)
	cpl
	and c
	ld e,a			; E = keys newly down
	ld a,c
	ld (kb_old),a
	bit 6,e
	jr z,.nq
	ld a,1			; ESC: give up the level
	ld (v_quit),a
	ret
.nq:	push de
	ld a,(skill_key)
	or a
	jr z,.nsk
	ld (v_sel),a
	call sfx_click
.nsk:	pop de
	push de
	bit 0,e
	call nz,sel_prev
	pop de
	push de
	ld a,e
	and $82			; X or right mouse button
	call nz,sel_next
	pop de
	push de
	bit 4,e
	call nz,toggle_pause
	pop de
	push de
	bit 5,e
	call nz,nuke_press
	pop de
	; release rate keys repeat while held (every other loop)
	ld a,(v_loop)
	and 1
	jr nz,.nr
	ld a,(kb_now)
	bit 2,a
	call nz,rate_down
	ld a,(kb_now)
	bit 3,a
	call nz,rate_up
.nr:	call move_cursor
	; fire: new press
	ld a,(ct_old)
	cpl
	ld c,a
	ld a,(ct_now)
	ld (ct_old),a
	and c
	bit 4,a
	jr nz,click
	; held fire on the rate buttons repeats
	ld a,(ct_now)
	bit 4,a
	ret z
	ld a,(v_loop)
	and 1
	ret nz
	call hud_button
	cp 2
	ret nc
	or a
	jp z,rate_down
	jp rate_up

; fire pressed
click:	ld a,(cur_y)
	cp 160
	jr nc,.panel
	ld ix,(v_hptr)
	ld a,ixh
	or ixl
	ret z
	ld a,(v_sel)
	sub 2
	cp 8
	ret nc
	jp apply_skill
.panel:	call hud_button		; A = button 0-11, 12 = minimap, 255 = none
	cp 255
	ret z
	cp 12
	jr z,.mm
	cp 2
	jr c,.rate
	cp 10
	jr c,.skill
	jr z,toggle_pause
	jp nuke_press
.rate:	or a
	jp z,rate_down
	jp rate_up
.skill:	ld (v_sel),a
	jp sfx_click
.mm:	; minimap: centre the view there (a minimap pixel is 4 VZ pixels)
	call hud_mm_x		; A = minimap x (0-127)
	sub 16			; half a view (64 bytes = 512 px = 32 map px... )
	jr nc,.m1
	xor a
.m1:	call set_scroll
	ld a,(vscroll)
	ld (scr_want),a
	ret

sel_prev:
	ld a,(v_sel)
	dec a
	cp 2
	jr nc,.s
	ld a,9
.s:	ld (v_sel),a
	jp sfx_click
sel_next:
	ld a,(v_sel)
	inc a
	cp 10
	jr c,.s
	ld a,2
.s:	ld (v_sel),a
	jp sfx_click
toggle_pause:
	ld a,(v_paused)
	xor 1
	ld (v_paused),a
	jp sfx_click
; nuke needs two presses within a second
nuke_press:
	ld a,(v_nuke)
	or a
	ret nz
	ld hl,(v_gtick)
	ld de,(v_nukeask)
	or a
	sbc hl,de
	ld a,h
	or a
	jr nz,.first
	ld a,l
	cp 13
	jr nc,.first
	ld a,1
	ld (v_nuke),a
	ld a,SFX_OHNO
	jp sfx_play
.first:	ld hl,(v_gtick)
	ld (v_nukeask),hl
	jp sfx_click
rate_down:
	ld a,(v_minrate)
	ld c,a
	ld a,(v_rate)
	cp c
	ret z
	ret c
	dec a
	jr rate_set
rate_up:
	ld a,(v_rate)
	cp 99
	ret nc
	inc a
rate_set:
	ld (v_rate),a
	ld a,1
	ld (v_pdirty),a
	ret
sfx_click:
	ld a,SFX_CLICK
	jp sfx_play

; ---- read the keyboard, joystick and mouse
; ct_now: b0 up b1 down b2 left b3 right b4 fire
; kb_now: b0 Z b1 X b2 , b3 . b4 H b5 N b6 ESC b7 right button
read_controls:
	call kb_on
	ld hl,KEYMAP
	ld bc,0			; B = kb_now, C = ct_now
.k:
.snd12:	call vschk
	SND 7
	ld a,(hl)
	cp $FF
	jr z,.kd
	inc hl
	ld e,(hl)		; bit
	inc hl
	ld d,(hl)		; which
	inc hl
	call keytest
	jr z,.k
	ld a,e
	bit 7,d
	jr nz,.kb
	or c
	ld c,a
	jr .k
.kb:	or b
	ld b,a
	jr .k
.kd:	; skill keys 1-8
	push bc
	ld hl,SKEYS
	ld c,2
.s:
.snd13:	SND 6
	ld a,(hl)
	inc hl
	call keytest
	jr nz,.sg
	inc c
	ld a,c
	cp 10
	jr nz,.s
	ld c,0
.sg:	ld a,c
	ld (skill_key),a
	pop bc
	call kb_off
	call read_joy
	or c
	ld c,a
	; mouse: buttons, and the movement into the cursor
	di
	ld a,(ms_btn)
	ld d,a
	ld a,(ms_dx)
	ld e,a
	ld a,(ms_dy)
	ld (ms_dyq),a
	xor a
	ld (ms_dx),a
	ld (ms_dy),a
	ei
	bit 1,d			; left button = fire
	jr z,.m1
	set 4,c
.m1:	bit 0,d			; right button = next skill
	jr z,.m2
	set 7,b
.m2:	ld a,c
	ld (ct_now),a
	ld a,b
	ld (kb_now),a
	; skill key: only on a new press
	ld a,(skill_key)
	ld hl,sk_old
	cp (hl)
	ld (hl),a
	jr nz,.ms
	xor a
	ld (skill_key),a
.ms:	; mouse x: 2 pixels a count across, 1 down
	ld a,e
	or a
	ret z
	ld l,a
	add a,a
	sbc a,a
	ld d,a
	ld e,l
	ex de,hl
	add hl,hl
	ex de,hl
	ld hl,(cur_x)
	add hl,de
	jp clamp_x

; HL = cursor x wanted -> stored, scrolling at the edges
clamp_x:
	bit 7,h
	jr z,.p
	call scroll_left
	ld hl,0
.p:	ld de,512
	or a
	sbc hl,de
	add hl,de
	jr c,.ok
	call scroll_right
	ld hl,511
.ok:	ld (cur_x),hl
	ret

scroll_left:
	ld a,(scr_want)
	or a
	ret z
	dec a
	ld (scr_want),a
	ret
scroll_right:
	ld a,(v_lwb)
	srl a
	sub 64
	ld c,a
	ld a,(scr_want)
	cp c
	ret nc
	inc a
	ld (scr_want),a
	ret

; cursor by keys / joystick (speeds up while held); mouse y applied here
move_cursor:
	ld a,(ms_dyq)		; mouse up / down first
	or a
	jr z,.nm
	ld e,a
	ld a,(cur_y)
	bit 7,e
	jr nz,.mup
	add a,e
	jr nc,.ms
	ld a,255
	jr .ms
.mup:	add a,e
	jr c,.ms
	xor a
.ms:	ld (cur_y),a
.nm:	ld a,(ct_now)
	ld c,a
	and $0F
	jr nz,.held
	xor a
	ld (cur_held),a
	jr .mouse
.held:	ld a,(cur_held)
	inc a
	jr z,.h
	ld (cur_held),a
.h:	ld b,2
	cp 6
	jr c,.sp
	ld b,4
	cp 14
	jr c,.sp
	ld b,8
.sp:	bit 2,c			; left
	jr z,.nl
	push bc
	ld hl,(cur_x)
	ld e,b
	ld d,0
	or a
	sbc hl,de
	call clamp_x
	pop bc
.nl:	bit 3,c			; right
	jr z,.nr
	push bc
	ld hl,(cur_x)
	ld e,b
	ld d,0
	add hl,de
	call clamp_x
	pop bc
.nr:	bit 0,c			; up
	jr z,.nu
	ld a,(cur_y)
	sub b
	jr nc,.u1
	xor a
.u1:	ld (cur_y),a
.nu:	bit 1,c			; down
	jr z,.mouse
	ld a,(cur_y)
	add a,b
	jr c,.d0
	cp 255
	jr c,.d1
.d0:	ld a,255
.d1:	ld (cur_y),a
.mouse:	; at the left / right edge with the fire not held: keep scrolling
	ld a,(cur_y)
	cp 160
	ret nc
	ld hl,(cur_x)
	ld a,h
	or a
	jr nz,.re
	ld a,l
	cp 2
	jp c,scroll_left
	ret
.re:	ld a,l
	cp 255-2
	jp nc,scroll_right
	ret

; ---------------------------------------------------------------------
;  what's under the cursor (as the original, in VZ pixels)
; ---------------------------------------------------------------------
hover:
	xor a
	ld (v_hcount),a
	ld hl,0
	ld (v_hptr),hl
	ld a,(cur_y)
	cp 160
	ret nc
	srl a
	ld (v_hy2),a		; cursor level y
	ld a,(vscroll)		; cursor level x = (scroll*8 + x) / 2
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,(cur_x)
	add hl,de
	srl h
	rr l
	ld (v_hx2),hl
	ld ix,CRT
	ld b,NCRT
.l:	push bc
	ld a,(ix+C_ST)
	or a
	jr z,.n
	cp ST_SPLAT
	jr nc,.n
	ld hl,(v_hx2)
	ld e,(ix+C_XL)
	ld d,(ix+C_XH)
	or a
	sbc hl,de
	inc hl
	inc hl
	ld a,h
	or a
	jr nz,.n
	ld a,l
	cp 5
	jr nc,.n
	ld a,(v_hy2)
	sub (ix+C_Y)
	add a,5
	cp 7
	jr nc,.n
	ld hl,v_hcount
	ld a,(hl)
	inc (hl)
	or a
	jr nz,.nf
	ld a,(ix+C_ST)
	ld (v_hst),a
	bit 0,(ix+C_FL)
	jr z,.nf
	ld a,ST_CLIMB
	ld (v_hst),a
.nf:	ld hl,(v_hptr)
	ld a,h
	or l
	jr nz,.n
	ld a,(v_sel)
	sub 2
	cp 8
	jr nc,.n
	call can_take
	jr nz,.n
	ld (v_hptr),ix
.n:	ld de,CSZ
	add ix,de
	pop bc
	ld a,b
	and 7
	jr nz,.c
	call vschk
.snd23:	SND 29
.c:	djnz .l
	ret

; Z if creature IX can take skill A (0..7)
can_take:
	ld c,a
	add a,a
	ld l,a
	ld h,0
	ld de,SKMASK
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,(ix+C_ST)
	or a
	jr z,.no
.sh:	srl d
	rr e
	dec a
	jr nz,.sh
	jr nc,.no
	ld a,c
	cp 3
	jr nc,.yes
	inc a
	ld b,a
	ld a,(ix+C_FL)
.fb:	rrca
	djnz .fb
	jr c,.no
.yes:	xor a
	ret
.no:	or 1
	ret
SKMASK:	dw %11111111111
	dw %11111111111
	dw %11111111111
	dw %11111000001
	dw %11110000001
	dw %11011000001
	dw %10111000001
	dw %01111000001

; give skill A to creature IX (it can take it); uses one up
apply_skill:
	ld c,a
	ld e,a
	ld d,0
	ld hl,v_skill
	add hl,de
	ld a,(hl)
	or a
	ret z
	dec (hl)
	ld a,1
	ld (v_pdirty),a
	ld a,c
	or a
	jr nz,.a1
	set 0,(ix+C_FL)
	jr .snd
.a1:	dec a
	jr nz,.a2
	set 1,(ix+C_FL)
	jr .snd
.a2:	dec a
	jr nz,.a3
	set 2,(ix+C_FL)
	ld (ix+C_BT),BOMBTICKS
	jr .snd
.a3:	ld hl,SKST-3
	ld e,c
	ld d,0
	add hl,de
	ld a,(hl)
	ld (ix+C_ST),a
	ld (ix+C_AN),0
	ld (ix+C_CNT),0
.snd:	ld a,SFX_ASSIGN
	jp sfx_play
SKST:	db ST_BLOCK,ST_BUILD,ST_BASH,ST_MINE,ST_DIG

; ---------------------------------------------------------------------
;  demo / test player: scripted skills (as the original)
; ---------------------------------------------------------------------
demo_start:
	ld (v_dptr),hl
	ld hl,v_dfired
	ld b,8
.c:	ld (hl),0
	inc hl
	djnz .c
	ret

demo_tick:
	ld a,(v_demo)
	or a
	ret z
	ld hl,(v_dptr)
	ld c,0
.ev:	ld a,(hl)
	cp $FF
	ret z
	push hl
	push bc
	call .one
	pop bc
	pop hl
	ld de,8
	add hl,de
	inc c
	jr .ev
.one:	push hl
	call .bit
	pop hl
	ret nz
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push hl
	ld hl,(v_gtick)
	or a
	sbc hl,de
	pop hl
	ret c
	ld a,(hl)
	inc hl
	ld b,(hl)
	inc hl
	push bc
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (v_ev0),de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (v_ev1),de
	cp $FF
	jr z,.any
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,CRT
	add hl,de
	push hl
	pop ix
	pop bc
	ld a,b
	cp 8
	jr nz,.sk
	ld a,1
	ld (v_nuke),a
	jr .fire
.any:	pop bc
	ld ix,CRT
	ld a,NCRT
.al:	push af
	push bc
	ld a,(ix+C_ST)
	or a
	call nz,.try
	pop bc
	ld de,CSZ
	add ix,de
	pop af
	dec a
	jr nz,.al
	ret
.try:	ld e,(ix+C_XL)
	ld d,(ix+C_XH)
	ld hl,(v_ev0)
	or a
	sbc hl,de
	jr z,.t0
	ret nc
.t0:	ld hl,(v_ev1)
	or a
	sbc hl,de
	ret c
	push bc
	ld a,b
	call can_take
	pop bc
	ret nz
	ld a,b
	add a,2
	ld (v_sel),a
	ld a,b
	jp apply_skill
.sk:	ld e,(ix+C_XL)
	ld d,(ix+C_XH)
	ld hl,(v_ev0)
	or a
	sbc hl,de
	jr z,.x0
	ret nc
.x0:	ld hl,(v_ev1)
	or a
	sbc hl,de
	ret c
	push bc
	ld a,b
	call can_take
	pop bc
	ret nz
	ld a,b
	add a,2
	ld (v_sel),a
	push bc
	ld a,b
	call apply_skill
	pop bc
.fire:	call .bit
	or (hl)
	ld (hl),a
	ret
.bit:	push bc
	ld a,c
	rrca
	rrca
	rrca
	and 7
	ld hl,v_dfired
	add a,l
	ld l,a
	adc a,h
	sub l
	ld h,a
	ld a,c
	and 7
	ld b,a
	ld a,1
	jr z,.b1
.b0:	add a,a
	djnz .b0
.b1:	ld c,a
	and (hl)
	ld a,c
	pop bc
	ret

; the demo view follows the bilby the next event is for; a key ends it
demo_controls:
	ld a,(v_test)
	ld hl,v_title
	or (hl)
	jr nz,.nk
	call anykey
	jr z,.nk
	ld a,1
	ld (v_quit),a
	ret
.nk:	ld hl,(v_dptr)
	ld c,0
.f:	ld a,(hl)
	cp $FF
	jr z,.last
	push hl
	push bc
	call demo_tick.bit
	pop bc
	pop hl
	jr nz,.nx
	inc hl
	inc hl
	ld a,(hl)
	dec hl
	dec hl
	inc a
	jr nz,.got
.nx:	ld de,8
	add hl,de
	inc c
	jr .f
.last:	ld a,(v_dlast)
	jr .fol
.got:	inc hl
	inc hl
	ld a,(hl)
	ld (v_dlast),a
.fol:	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,CRT
	add hl,de
	push hl
	pop ix
	ld a,(ix+C_ST)
	dec a
	cp ST_EXIT-1
	jr c,.ok
	ld ix,CRT
	ld b,NCRT
	ld de,CSZ
.any:	ld a,(ix+C_ST)
	dec a
	cp ST_EXIT-1
	jr c,.ok
	add ix,de
	djnz .any
	ret
.ok:	; view: keep the bilby between a quarter and three quarters across
	ld l,(ix+C_XL)
	ld h,(ix+C_XH)
	srl h
	rr l
	srl h
	rr l			; its byte column (x*2/8)
	ld a,l
	sub 32
	jr nc,.v1
	xor a
.v1:	call set_scroll
	ld a,(vscroll)
	ld (scr_want),a
	; and the cursor on it
	ld l,(ix+C_XL)
	ld h,(ix+C_XH)
	add hl,hl
	ld a,(vscroll)
	ld e,a
	ld d,0
	ex de,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ex de,hl
	or a
	sbc hl,de
	ld (cur_x),hl
	ld a,(ix+C_Y)
	add a,a
	sub 6
	jr nc,.c1
	xor a
.c1:	ld (cur_y),a
	ret

anykey:	call read_controls
	ld a,(ct_now)
	ld c,a
	ld a,(kb_now)
	or c
	ret

; key map: code, bit, which (0 = ct_now, $80 = kb_now)
KEYMAP:	db K_Q,$01,0, K_A,$02,0, K_O,$04,0, K_P,$08,0
	db K_UP,$01,0, K_DOWN,$02,0, K_LEFT,$04,0, K_RIGHT,$08,0
	db K_SPACE,$10,0, K_RET,$10,0, K_M,$10,0
	db K_Z,$01,$80, K_X,$02,$80, K_COMMA,$04,$80, K_DOT,$08,$80
	db K_MINUS,$04,$80
	db K_H,$10,$80, K_N,$20,$80, K_ESC,$40,$80
	db $FF
SKEYS:	db K_1,K_1+1,K_1+2,K_1+3,K_1+4,K_1+5,K_1+6,K_1+7
