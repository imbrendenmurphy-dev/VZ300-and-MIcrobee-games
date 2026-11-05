;=====================================================================
;  HOPPY 2  -  for the Dick Smith VZ300 (BennVenn SD + 128K)
;  A remake of HOPPY by Dubois & McNamara
;=====================================================================
	DEVICE NOSLOT64K
	OPT --syntax=abf

BUF	equ $F800		; 2K composition buffer (2K aligned)
STACK_TOP equ $F800		; stack grows down below BUF

	ORG $8000
start:
	di
	ld sp,STACK_TOP
	ld a,$28		; mode 1, speaker bits 0/5 opposite
	ld (latch_v),a
	ld (LATCH),a
	; clear bss
	ld hl,bss_start
	ld de,bss_start+1
	ld bc,bss_end-bss_start-1
	ld (hl),0
	ldir
	ld hl,lowbss
	ld de,lowbss+1
	ld bc,lowbss_end-lowbss-1
	ld (hl),0
	ldir
	ld a,$28		; mode 1, speaker bits 0/5 opposite
	ld (latch_v),a
	ld hl,$1234
	ld (seed),hl
	ld a,4			; lane speed scale x1 (needed before the first title)
	ld (spdmul),a
	ld a,$5a
	ld (nseed),a
	ld hl,BUF
	ld (ds_base),hl
	ld (txt_base),hl
	ld a,63
	ld (clip_bot),a
	ld hl,bg_road
	ld de,dashrow
	call tile4
	ld hl,bg_roadk
	ld de,kerbrow
	call tile4
	call txt_init
	call joy_detect
	call hiscore_init
	ld a,8
	ld (hi_new),a
	xor a
	call cls_vram
	IFDEF AUTOPLAY
	jp game_start
	ENDIF
	jp attract

tile4:	ld a,4
.l:	push hl
	ld bc,8
	ldir
	pop hl
	dec a
	jr nz,.l
	ret

;=====================================================================
; Two-field tick: blit top half in VB-A, render top; blit bottom in
; VB-B, render bottom.  All VRAM writes happen in vertical blank.
;=====================================================================
TOP0	equ 6
TOPN	equ 29
BOT0	equ 35
BOTN	equ 29

; tickA: blit top half (previous frame).  Caller then runs logic and
; calls tickB, which renders the new top+bottom around the 2nd blank.
tickA:
	call wait_frame
	ld a,(hud_copy)
	or a
	jr z,.nh
	xor a
	ld (hud_copy),a
	ld b,6
	call blit_rows
.nh:	ld a,(tv_top0)
	ld b,a
	ld a,(tv_bot0)
	sub b
	ld c,a
	ld a,b
	ld b,c
	call blit_dirty
	call read_acc
	jp snd_tick
tickB:
	ld iy,bands_top
	ld a,(tv_bot0)
	dec a
	ld b,a
	ld a,(tv_top0)
	call draw_half
	call wait_frame
	ld a,(tv_bot0)
	ld b,a
	ld a,64
	sub b
	ld b,a
	ld a,(tv_bot0)
	call blit_dirty
	call read_acc
	call snd_tick
	ld iy,bands_bot
	ld a,(tv_bot0)
	ld b,63
	call draw_half
	jp rows_swap

; select tick layout: game (HUD + 6..34 / 35..63) or scene (0..31 / 32..63)
tick_game:
	ld a,TOP0
	ld (tv_top0),a
	ld a,BOT0
	ld (tv_bot0),a
	ret
tick_scene:
	xor a
	ld (tv_top0),a
	ld a,32
	ld (tv_bot0),a
	ret

tick:	call tickA
	jp tickB

read_acc:
	call read_input
	ld a,(keys_new)
	ld hl,keys_acc
	or (hl)
	ld (hl),a
	ret

; full-screen page: BUF rows 0..63 to VRAM over two blanks
page_blit:
	call wait_vb
	xor a
	ld b,32
	call blit_rows
	call snd_tick
	call wait_frame
	ld a,32
	ld b,32
	call blit_rows
	jp snd_tick

; idle for A ticks showing current BUF (page), returns Z if timed out, NZ if key
page_wait:
	ld (pw_n),a
.l:	call page_blit
	call read_input
	ld a,(keys_new)
	and K_FI|K_UP|K_DN|K_LT|K_RT|K_PA|K_ANY
	ret nz
	ld hl,pw_n
	dec (hl)
	jr nz,.l
	ret

cls_buf:		; A = fill
	ld hl,BUF
	ld de,BUF+1
	ld bc,2047
	ld (hl),a
	ldir
	ret

;=====================================================================
; band building for the board view
;=====================================================================
build_view:
	ld a,(cam_y)
	ld iy,bands_top
	ld c,TOPN
	call build_bands
	ld a,(cam_y)
	add a,TOPN
	ld iy,bands_bot
	ld c,BOTN
	; fall through
; A = board y, C = rows, IY = list.  band = (rowbase.w, B, -, rows)
build_bands:
	ld d,0
.dv:	cp 6
	jr c,.dd
	sub 6
	inc d
	jr .dv
.dd:	ld e,a			; r
	ld a,d
	push de
	push bc
	call lane_ptr
	pop bc
	pop de
.lp:	; IX = lane d, E = r, C = rows left
	ld a,6
	sub e
	cp c
	jr c,$+3
	ld a,c
	ld (iy+4),a
	ld b,a
	ld (iy+2),0
	ld a,e
	or a
	jr nz,.nr0
	ld a,(ix+L_KIND)
	cp K_ROAD
	jr nz,.nr0
	ld hl,dashrow
	ld a,(ix+L_BG)
	cp BG_ROADK
	jr nz,$+5
	ld hl,kerbrow
	ld (iy+4),1
	ld b,1
	ld (iy+0),l
	ld (iy+1),h
	ld a,5
	add a,iyl
	ld iyl,a
	jr nc,$+4
	inc iyh
	inc e
	dec c
	jr nz,.lp
	jr .end
.nr0:	ld a,e
	rrca
	rrca
	rrca
	ld l,a
	and $1f
	ld h,a
	ld a,l
	and $e0
	add a,(ix+L_BASE)
	ld l,a
	ld a,h
	adc a,(ix+L_BASE+1)
	ld h,a
	bit 0,(ix+L_FLAGS)
	jr z,.set
	ld a,(ix+L_SI)
	rrca
	rrca
	and 31
	ld (iy+2),a
	ld a,(ix+L_SI)
	and 3
	add a,a
	push de
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
	pop de
.set:	ld (iy+0),l
	ld (iy+1),h
	ld a,5
	add a,iyl
	ld iyl,a
	jr nc,$+4
	inc iyh
	ld a,c
	sub b
	ld c,a
	jr z,.end
	ld e,0
	inc d
	push bc
	ld bc,L_SIZE
	add ix,bc
	pop bc
	jp .lp
.end:	ld (iy+4),0
	ret
ptab:	dw 0,PLANE,PLANE*2,PLANE*3

;=====================================================================
; camera
;=====================================================================
cam_update:
	ld a,(fy)
	sub 34
	jr nc,$+3
	xor a
	ld c,a
	ld a,(cam_max)
	cp c
	jr nc,$+3
	ld c,a
cam_toward:		; C = target
	ld a,(cam_y)
	cp c
	ret z
	jr c,.dn
	sub 2
	jr c,.set
	cp c
	jr nc,.st
.set:	ld a,c
.st:	ld (cam_y),a
	ret
.dn:	add a,2
	cp c
	jr c,.st
	ld a,c
	jr .st

;=====================================================================
; sprite queueing for the board
;=====================================================================
; board y (A) -> screen y (B) signed
scr_y:	ld b,a
	ld a,(cam_y)
	neg
	add a,b
	add a,6
	ld b,a
	ret

queue_world:
	call jobs_reset
	; bay contents (flies / crocs)
	ld b,0
.bay:	push bc
	ld hl,bays
	ld a,b
	call addhla
	ld a,(hl)
	ld de,spr_fly
	cp 2
	jr z,.bq
	ld de,spr_bcpeek
	cp 3
	jr z,.bq
	ld de,spr_bcroc
	cp 4
	jr nz,.bn
.bq:	ld a,(frame_cnt)
	and 4
	jr z,.bq2
	ld a,e
	cp low spr_fly
	jr nz,.bq2
	ld de,spr_fly2
.bq2:	ld hl,BAYX
	ld a,b
	call addhla
	ld c,(hl)
	xor a
	call scr_y
	call queue_spr
.bn:	pop bc
	inc b
	ld a,b
	cp 5
	jr nz,.bay
	; snake
	ld a,(snake_on)
	or a
	jr z,.ns
	ld a,(snake_row)
	ld b,a
	add a,a
	add a,b
	add a,a
	call scr_y
	ld a,(snake_x)
	ld c,a
	ld a,(snake_an)
	and 4
	ld de,spr_snake
	jr z,$+5
	ld de,spr_snake2
	ld a,(snake_dir)
	or a
	jp p,.sq
	ld de,spr_snakel
	ld a,(snake_an)
	and 4
	jr z,.sq
	ld de,spr_snake2l
.sq:	call queue_spr
.ns:	; pickups
	ld iy,ents
	ld b,MAXENT
.el:	push bc
	ld a,(iy+0)
	or a
	jr z,.en
	ld a,(iy+E_LIFE)
	cp 60
	jr nc,.ev
	ld a,(frame_cnt)
	and 2
	jr z,.en
.ev:	ld a,(iy+E_TYPE)
	dec a
	add a,a
	ld hl,picktab
	call addhla
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,(iy+E_LANE)
	ld b,a
	add a,a
	add a,b
	add a,a
	call scr_y
	; bob
	ld a,(frame_cnt)
	and 8
	jr z,$+3
	dec b
	ld c,(iy+E_X)
	ld a,c
	cp 122
	jr nc,.en
	push iy
	call queue_spr
	pop iy
.en:	ld de,8
	add iy,de
	pop bc
	djnz .el
	; hoppina (not carried)
	ld a,(hop_on)
	or a
	jr z,.nh
	ld a,(hop_carry)
	or a
	jr nz,.nh
	ld a,(hop_x)
	cp 122
	jr nc,.nh
	ld c,a
	ld a,(hop_lane)
	ld b,a
	add a,a
	add a,b
	add a,a
	call scr_y
	ld de,spr_hoppina
	call queue_spr
.nh:	; frog
	call bfly_queue
	call queue_frog
	call parts_queue
	call pops_queue
	ld a,(demo)
	cp 1
	ret nz
	ld a,(frame_cnt)
	and 16
	ret z
	ld hl,txt_demo
	ld de,$0738
	ld a,1
	jp queue_small

picktab: dw spr_bubble,spr_snail,spr_star,spr_heart

queue_frog:
	ld a,(fstate)
	cp FS_INTRO
	ret z
	cp FS_WAIT
	ret z
	cp FS_DYING
	jp z,.dying
	cp FS_CLEAR
	ret z
	ld a,(finv)
	or a
	jr z,.vis
	ld a,(finv_float)
	or a
	jr nz,.vis
	ld a,(frame_cnt)
	and 2
	ret z
.vis:	ld a,(fdir)
	add a,a
	ld c,a
	ld a,(fhop)
	or a
	jr z,$+3
	inc c
	ld a,c
	add a,a
	ld hl,frogpose
	call addhla
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,(fy)
	call scr_y
	ld a,(fx+1)
	ld c,a
	push bc
	call queue_spr
	pop bc
	; hoppina piggyback
	ld a,(hop_carry)
	or a
	jr z,.nc
	push bc
	dec b
	dec b
	dec b
	ld de,spr_hoppina
	call queue_spr
	pop bc
.nc:	; shield ring
	ld a,(shield)
	ld e,a
	ld a,(finv_float)
	or e
	ret z
	ld a,(frame_cnt)
	and 2
	ret z
	; sparkle ring: direct plot job
	ld hl,job_ring
	jp add_job
.dying:	ld a,(fy)
	call scr_y
	ld a,(fx+1)
	ld c,a
	ld a,(ftimer)
	ld e,a
	ld a,(fdeath)
	cp D_DROWN
	jr z,.dr
	cp D_TIME
	jr z,.tm
	ld de,spr_squash
	ld a,(ftimer)
	cp 20
	jr nc,$+5
	ld de,spr_squash2
	jp queue_spr
.dr:	ld de,spr_ring1
	ld a,e
	cp 24
	jr nc,.dq
	ld de,spr_ring2
	cp 16
	jr nc,.dq
	ld de,spr_ring3
	cp 8
	ret c
.dq:	jp queue_spr
.tm:	ld de,spr_faint
	ld a,e
	cp 18
	jr nc,.dq
	; angel floats up
	ld a,18
	sub e
	ld d,a
	ld a,b
	sub d
	ld b,a
	ld de,spr_angel
	jp queue_spr

; ring of sparkles around the frog: p0 x, p1 y (screen)
job_ring:
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld hl,ringpts
	ld d,8
.l:	push bc
	push de
	ld a,c
	add a,(hl)
	ld c,a
	inc hl
	ld a,b
	add a,(hl)
	ld b,a
	inc hl
	push hl
	ld a,c
	cp 128
	jr nc,.sk
	ld a,(clip_top)
	ld e,a
	ld a,b
	cp e
	jr c,.sk
	ld a,(clip_bot)
	cp b
	jr c,.sk
	ld a,b
	call mark_row
	ld e,1
	call plot
.sk:	pop hl
	pop de
	pop bc
	dec d
	jr nz,.l
	ret
ringpts: db -1,-1, 3,-2, 8,-1, 9,2, 8,5, 3,6, -1,5, -2,2
frogpose: dw spr_fup,spr_fupj,spr_frt,spr_frtj,spr_fdn,spr_fdnj,spr_flt,spr_fltj

;=====================================================================
; GAME
;=====================================================================
game_start:
	call game_new
	xor a
	IFDEF AUTOPLAY
	ld a,2
	ENDIF
	ld (demo),a
	IFDEF STARTLEVEL
	ld a,STARTLEVEL
	ld (level),a
	ENDIF
.demo:
.level:	call level_card
	call level_load
	call frog_spawn
	ld a,(lvl_css)
	call set_css
	call tick_game
	call hud_draw
	ld a,1
	ld (hud_copy),a
	call jobs_clear
	call rows_invalidate
	; fly-over: camera from top to the frog
	ld a,FS_INTRO
	ld (fstate),a
	xor a
	ld (cam_y),a
	call build_view
	call jobs_reset
	ld (keys_acc),a
	ld a,45
	ld (intro_t),a
.intro:	call tick
	call lanes_move
	call anim_tick
	call parts_tick
	ld a,(intro_t)
	cp 25
	jr nc,.i1
	ld a,(cam_max)
	ld c,a
	call cam_toward
.i1:	call build_view
	call jobs_reset
	call queue_world
	call queue_banner
	ld hl,intro_t
	dec (hl)
	jr nz,.intro
	ld a,FS_PLAY
	ld (fstate),a
	ld a,40
	ld (finv),a
	xor a
	ld (keys_acc),a
	ld (gameover),a
.play:	call tickA
	ld a,(demo)
	or a
	jr z,.nd
	cp 2
	jr z,.ai
	ld a,(keys)
	and K_ANY|K_FI
	jp nz,demo_exit
	ld hl,demo_t
	dec (hl)
	jp z,demo_exit
.ai:	call ai_think
	ld (keys_acc),a
	ld (keys),a
.nd:	; pause
	ld a,(keys_acc)
	and K_PA
	call nz,pause
	ld a,(quit)
	or a
	jp nz,game_quit
	call game_update
	xor a
	ld (keys_acc),a
	ld a,(fstate)
	cp FS_CLEAR
	jp z,.clear
	ld a,(gameover)
	or a
	jp nz,game_over
	call cam_update
	call build_view
	call queue_world
	call tickB
	call game_update2
	jp .play
.clear:	call level_clear
	ld a,(level)
	inc a
	cp NLEVELS
	jr c,.nl
	call victory
	ld a,(lap)
	inc a
	ld (lap),a
	ld a,(spdmul)
	inc a
	ld (spdmul),a
	xor a
.nl:	ld (level),a
	jp .level

game_quit:
	xor a
	ld (quit),a
	call snd_off
	jp attract

;---------------------------------------------------------------------
; pause
;---------------------------------------------------------------------
pause:
	call snd_off
	ld hl,BUF
	ld de,BUF+1
	ld bc,191
	ld (hl),$ff
	ldir
	ld hl,BUF
	ld (txt_base),hl
	ld a,1
	ld (txt_opq),a
	xor a
	ld (clip_top),a
	ld a,63
	ld (clip_bot),a
	ld a,$31
	call text_setcol
	ld hl,txt_paused
	ld de,$0000
	call text_at
.w:	call wait_vb
	xor a
	ld b,6
	call blit_rows
	call read_input
	ld a,(keys_new)
	and K_PA
	jr nz,.out
	ld a,(keys_new)
	and K_QU
	jr z,.w
	ld a,1
	ld (quit),a
.out:	call hud_draw
	ld a,1
	ld (hud_copy),a
	xor a
	ld (keys_acc),a
	ret

;---------------------------------------------------------------------
; banner text during intro: level name centred
;---------------------------------------------------------------------
queue_banner:
	ld a,(frame_cnt)
	ld hl,(lvl_name)
	ld c,2
	ld b,24
	ex de,hl
	ld hl,job_banner
	jp add_job
job_banner:		; p0 col p1 row p2/3 text: opaque band with text
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	push de
	push bc
	; dark band rows b-1 .. b+5
	ld a,(clip_top)
	cp 30
	jr nc,.skip
	ld hl,BUF+23*32
	ld de,BUF+23*32+1
	ld bc,7*32-1
	ld (hl),$aa
	ldir
	ld a,23
	ld b,7
.mk:	push af
	call mark_row
	pop af
	inc a
	djnz .mk
	ld hl,BUF
	ld (txt_base),hl
	ld a,1
	ld (txt_opq),a
	ld a,$21
	call text_setcol
	pop bc
	pop hl
	ld d,c
	ld e,b
	jp text_at
.skip:	pop bc
	pop de
	ret

;---------------------------------------------------------------------
; level card (static page) shown while lanes are built
;---------------------------------------------------------------------
level_card:
	call snd_off
	xor a
	call set_css
	ld a,$aa
	call cls_buf
	ld hl,BUF
	ld (txt_base),hl
	xor a
	ld (clip_top),a
	ld a,63
	ld (clip_bot),a
	ld a,1
	ld (txt_opq),a
	ld a,$21
	call text_setcol
	ld a,(level)
	add a,a
	ld hl,level_tab
	call addhla
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld de,3
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push hl
	push de
	ld hl,txt_level
	ld de,$0b0a
	call text_at
	ld a,(level)
	inc a
	ld l,a
	ld h,0
	call num5
	call num_trim
	ld de,$110a
	call text_at
	ld a,$23
	call text_setcol
	pop hl
	ld de,$0214
	call text_at
	ld a,$20
	call text_setcol
	pop hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld de,$0222
	call text_at
	ld a,(lap)
	or a
	jr z,.nl
	ld a,$23
	call text_setcol
	ld hl,txt_lap
	ld de,$0a36
	call text_at
.nl:	call page_blit
	ld a,(demo)
	or a
	ret nz
	ld hl,m2_go
	jp m2_jingle

;---------------------------------------------------------------------
; level clear: celebration + tally
;---------------------------------------------------------------------
level_clear:
	ld hl,sfx_1up
	ld a,5
	call sfx_play
	ld a,60
	ld (intro_t),a
.l:	call tick
	call lanes_move
	call anim_tick
	call parts_tick
	call pop_tick
	ld a,(intro_t)
	and 3
	jr nz,.nf
	; firework over a random bay
	call rand
	and 7
	cp 5
	jr nc,.nf
	ld hl,BAYX
	call addhla
	ld a,(hl)
	add a,3
	ld (bx),a
	call rand
	and 7
	add a,4
	ld (by),a
	ld b,10
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
.nf:	ld c,0
	call cam_toward
	call build_view
	call jobs_reset
	; dancing frogs in bays
	ld b,0
.df:	push bc
	ld hl,BAYX
	ld a,b
	call addhla
	ld c,(hl)
	ld a,(intro_t)
	add a,b
	and 4
	ld a,0
	jr z,$+4
	ld a,-2
	call scr_y
	ld de,spr_fupj
	call queue_spr
	pop bc
	inc b
	ld a,b
	cp 5
	jr nz,.df
	call parts_queue
	call pops_queue
	ld hl,intro_t
	dec (hl)
	jp nz,.l
	jp tally

;=====================================================================
; data
;=====================================================================
	INCLUDE "core.asm"
	INCLUDE "lanes.asm"
	INCLUDE "game.asm"
	INCLUDE "ai.asm"
	INCLUDE "levels.asm"
	INCLUDE "screens.asm"
	INCLUDE "sound.asm"
	INCLUDE "music2.asm"
	INCLUDE "strings.asm"
	INCLUDE "gfx.inc"
code_end:

;=====================================================================
; BSS (not saved; cleared at start)
;=====================================================================
bss_start:
dashrow	ds 32
kerbrow	ds 32
fillrow	ds 32
latch_v	db 0
frame_cnt db 0
overruns db 0
seed	dw 0
nseed	db 0
snd_n	db 0
sfx_n	db 0
sfx_cnt	db 0
sfx_pri	db 0
sfx_ptr	dw 0
mus_n	db 0
mus_cnt	db 0
mus_ptr	dw 0
mus_start dw 0
mus_loop db 0
keys	db 0
keys_old db 0
keys_new db 0
keys_acc db 0
joy_on	db 0
r_first	db 0
clip_top db 0
clip_bot db 0
ds_base	dw 0
ds_h	db 0
ds_wb	db 0
ds_src	dw 0
ds_col	db 0
ds_n	db 0
ds_pre	db 0
ds_post	db 0
ds_cs	db 0
txt_base dw 0
txt_opq	db 0
txt_col	db 0
txt_x0	dw 0
txt_tp	dw 0
tpat	db 0
tmsk	db 0
numbuf	ds 8
job_ptr	dw 0
buckets	ds 2
bands_top ds 5*12
bands_bot ds 5*12
bands	ds 5*13
heap_s	dw 0
heap_m	dw 0
nlanes	db 0
cur_lane db 0
board_h	db 0
cam_max	db 0
cam_y	db 0
po_x	dw 0
po_t	db 0
st_x	db 0
st_w	db 0
st_row	dw 0
rg_j0	db 0
rg_n	db 0
rg_k	db 0
rg_src	dw 0
rg_dst	dw 0
n_anim	db 0
anims	ds 8*MAXANIM
spdmul	db 0
slowmo	db 0
x2time	db 0
; level
level	db 0
lap	db 0
lvl_ptr	dw 0
lvl_css	db 0
lvl_fpu	db 0
lvl_flags db 0
lvl_name dw 0
lvl_intro dw 0
; frog
fx	dw 0
fy	db 0
fdir	db 0
fhop	db 0
fq	db 0
fstate	db 0
fdeath	db 0
ftimer	db 0
finv	db 0
finv_float db 0
fbest	db 0
fbay	db 0
frow_c	db 0
hold_t	db 0
tbar	db 0
tsub	db 0
lives	db 0
score	ds 3
nextlife db 0
continues db 0
shield	db 0
snails	db 0
hud_dirty db 0
hud_copy db 0
gameover db 0
quit	db 0
demo	db 0
intro_t	db 0
bays	ds 5
bays_order db 0
deaths_lvl db 0
flies_lvl db 0
fly_t	db 0
bc_t	db 0
pick_t	db 0
snake_on db 0
snake_row db 0
snake_x	db 0
snake_dir db 0
snake_an db 0
n_ent	db 0
ents	ds 8*MAXENT
hop_on	db 0
hop_carry db 0
hop_lane db 0
hop_x	db 0
hop_t	db 0
hop_life db 0
parts	ds 8*MAXPART
pv_e	db 0
pv_d	db 0
tmpvx	db 0
bx	db 0
by	db 0
pops	ds 9*MAXPOP
pop_col	db 0
hb_tab	dw 0
hb_full	db 0
pw_n	db 0
m2_ptr	dw 0
m2_cb	dw 0
m2_f	db 0
m2_ia	dw 0
m2_ib	dw 0
m2_n	dw 0
m2_pa	dw 0
m2_pb	dw 0
m2_on	db 0
theme_done db 0
bf_x	ds 2
bf_y	ds 2
pq_nt	db 0
pq_nb	db 0
pv_life	db 0
tv_top0	db 0
tv_bot0	db 0
sl_end	dw 0
pcam	db 0
parts_live db 0
bd_n	db 0
demo_t	db 0
ai_wait	db 0
ai_row	db 0
ai_x	db 0
aw_row	db 0
an_done	db 0
ar_dir	db 0
sc_list	ds 4*14
sc_ptr	dw 0
logo_buf dw 0
scr_buf	dw 0
page_buf dw 0
pg_spr	dw 0
ltr_y	ds 6
ltr_vy	ds 6
ltr_done db 0
t_tick	dw 0
tongue	db 0
mini_on	db 0
mini_i	db 0
mini_t	db 0
fly_x	db 0
fly_y	db 0
fly_dead db 0
burp_t	db 0
wide_t	db 0
flash	db 0
snail_x	db 0
scr_ptr	dw 0
scr_ph	db 0
scr_c	db 0
scr_glyph ds 5
sty_ptr	dw 0
sty_pos	dw 0
sty_t	db 0
dz_x	db 0
frogl	ds 24
hitab	ds 6*8
hi_new	db 0
ne_ptr	dw 0
ne_i	db 0
ne_txt	ds 4
cont_n	db 0
cont_t	db 0
tl_pts	dw 0
tl_txt	dw 0
tl_row	db 0
tb_fill	db 0
tb_col	db 0
txt_qcol db 0
sd_i	db 0
sd_off	db 0
sd_row	db 0
bss_end:
heap_main:

	ASSERT heap_main < $F700-800, "main heap too small"

; low RAM ($7800-$7FFF, free once the ROM is no longer used)
	ORG $7800
lowbss:
txt_tabs ds 256
rowinfo	ds 64*8
lanes	ds 32*MAXLANES
jobpool	ds 8*56
jobpool_end:
pq_top	ds 5*MAXPART
pq_bot	ds 5*MAXPART
lowbss_end:
	ASSERT lowbss_end <= $8000
	SAVEBIN "../build/hoppy2.bin",start,code_end-start
	DISPLAY "code_end=",/H,code_end," bss_end=",/H,bss_end
