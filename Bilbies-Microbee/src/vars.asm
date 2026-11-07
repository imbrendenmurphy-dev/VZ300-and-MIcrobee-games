; =====================================================================
;  variables and tables in the upper 32K (block 0), below the video window
; =====================================================================
	ORG VARBASE
vars_start:
; ---- frame / hardware
vblast	db 0
vcount	db 0
fields	db 0
spkbit	db 0
snd_cnt	db 0
snd_per	db 0
snd_mode	db 0
snd_nz	db 0
snd_div	db 0
sfx_pri	db 0
sfx_ptr	dw 0
; music (music.asm)
mch	ds 4*MCH	; ptr, timer, note, inst, pos, ret, envp, arpp, arps, vib
mv1	ds 3		; voice outputs: increment, duty
mv2	ds 3
mv3	ds 3
ma1	dw 0		; phase accumulators
ma2	dw 0
ma3	dw 0
mnoise	dw 0
mf_sp	dw 0
dr_t	db 0
dr_f	db 0
dr_n	db 0
mus_endf	db 0
mgap	db 0		; samples the last pause lasted
mus_fl	db 0		; fields count at the last tick
mus_on	db 0		; a song is playing
mus_en	db 0		; music wanted (settings)
mus_song	dw 0
ms_line	db 0		; the mouse's clock line when the music started
ms_act	db 0		; fields to stay quiet: the mouse is sending
rseed	dw $3A71
dpage	db 0		; page shown
rpage	db 1		; page being drawn
sp_save	dw 0
cb_src	db 0
cb_dst	db 0
lzb_tab	dw 0
lzb_n	dw 0
lzb_len	db 0
lzb_hi	db 0
; ---- mouse
ms_nbit	db 0
ms_cur	db 0
ms_bytes	db 0
ms_b1	db 0
ms_b2	db 0
ms_dx	db 0
ms_dy	db 0
ms_btn	db 0
ms_seen	db 0
; ---- render
vscroll	db 0		; view: first world byte column shown
pscroll	db 255,255	; each page's scroll (255 = nothing loaded)
crmin	db 255,255	; rows that may hold sprite cells, per page
crmax	db 0,0
dr_min	db 0
dr_max	db 0
ac_r0	db 0
ac_r1	db 0
ac_scr	dw 0
ac_wld	dw 0
rs_bank	dw 0
rs_end	dw 0
ms_bp	dw 0
ca_page	db 0
ca_row	db 0
ca_wc	db 0
ca_lo	db 0
ca_hi	db 0
ca_mark	dw 0
ds_page	dw 0
ds_dirty	dw 0
ds_sct	dw 0
ds_last	db 0
ac_ink	db 0
ds_ybase	db 0
ds_ymin	db 0
ds_ymax	db 0
ds_dhi	db 0
ds_slowf	db 0
ds_ncol	db 0
ds_sc0	db 0
rs_dl	dw 0
rs_gc	db 0
rs_cnt	db 0
ms_scr	db 0
rs_scroll	db 0
ds_y32	db 0
ds_x	dw 0
ds_cols	db 0
ds_n	db 0
ds_ptr	dw 0
ds_next	dw 0
ds_sc	db 0
ds_row	db 0
sprink	db YELLOW
monomode	db 0
vars_end:

; ---- tables (aligned)
	ALIGN 256
COLBASE	ds 128		; glyph column addresses (F800h + (gc mod 12)*160)
BANKP	ds 128		; page 0 / page 1 PCG bank port values per gc
ATTRS	ds 256		; attribute bytes: page 0 (x2), page 1 (x2)
WCADDR	ds 256		; world byte-column addresses (wc * 160)
CODES	ds 128*PFROWS	; screen codes per row, gc 0-63 twice
	ALIGN 2048
PAGE0	ds PG_SIZE
PAGE1	ds PG_SIZE
BOUNCE	ds 256
tables_end:
	ALIGN 256
IMTAB	dw mouse_isr	; IM 2 vector 00h (PIO B, the only interrupt source)
	ASSERT $ <= GVARS	; the tables must not run into the game variables

; ---- the game (variable names as in the VZ300 original)
	ORG GVARS
gvars_start:
v_seed	dw 0
v_demo	db 0		; scripted skills (attract mode / tests)
v_test	db 0		; test run: keys don't stop it
v_quit	db 0
v_lvl	db 0
v_ncrt	db 0		; (these 12 are copied from the level header)
v_rate	db 0
v_tosave	db 0
v_min	db 0
v_skill	ds 8
v_lwb	db 0
v_lw	dw 0
v_lh	db 0		; (these 13 are copied from the header)
v_hx	dw 0
v_hy	db 0
v_ex	dw 0
v_ey	db 0
v_brick	db 0
v_wy	db 0
v_wx0	dw 0
v_wx1	dw 0
v_nsteel	db 0
v_steel	ds 6*8
v_minrate	db 0
v_released	db 0
v_saved	db 0
v_lost	db 0
v_reltimer	db 0
v_hatch	db 0
v_paused	db 0
v_nuke	db 0
v_nukeidx	db 0
v_nukeask	dw 0
v_end	db 0
v_gtick	dw 0
v_tleft	dw 0
v_secfr	db 0
v_loop	db 0
v_dug	db 0
v_spawnfl	db 0
v_nblock	db 0
v_sel	db 0
v_hcount	db 0
v_hst	db 0
v_hptr	dw 0
v_hx2	dw 0
v_hy2	db 0
v_dptr	dw 0
v_dlast	db 0
v_ev0	dw 0
v_ev1	dw 0
v_dfired	ds 8
v_pdirty	db 0
; Microbee play state
wp_mask	db 0
wp_wc	db 0
wp_row	db 0
cur_x	dw 0		; cursor, screen pixels (0-511, 0-255)
cur_y	db 0
cur_held	db 0
kb_now	db 0		; keys a loop: b0 Z b1 X b2 , b3 . b4 H b5 N b6 ESC b7 R-button
kb_old	db 0
ct_now	db 0		; b0 up b1 down b2 left b3 right b4 fire
ct_old	db 0
interp	db 0		; 1 = drawing halfway between the last two ticks
skill_key	db 0
sk_old	db 0
ms_dyq	db 0
scr_want	db 0
hud_nbuf	ds 25
hud_sbuf	ds 64
hud_n2	ds 3
hud_sold	ds 64
sl_buf	ds 40
br_buf	ds 64
t_idle	dw 0
t_choice	db 0
t_drawn	db 0
t_demo	db 0
mk_rep	db 0
mk_kb	db 0
ls_cur	db 0
v_unlock	db 0
v_train	db 0
v_title	db 0
sfx_on	db 0
sv_error	db 0
sv_sec	db 0
sv_st	db 0
bk_nx	dw 0
hud_alt	db 0
bk_dr	dw 0
ub_src	db 0
ub_dst	db 0
ub_tab	ds 18
heavy	db 0
hud_sel	db 0
hud_pause	db 0
gvars_end:
	ALIGN 16
CRT	ds NCRT*CSZ
PART	ds NPART*7
SCRIPT	ds 128
gtab_end:
