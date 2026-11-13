; =====================================================================
;  variables (zeroed at start-up) in the upper block below the stack
; =====================================================================
vars_start:
ghosts:  ds NG*GSZ
parts:   ds NPART*PSZ
; ---- hardware / core
curblk:  db 0
cb_src:  db 0
cb_dst:  db 0
vblast:  db 0
vcount:  db 0
fw_need: db 0
steps:   db 2
framecount: dw 0
seed:    dw 0
crtc_vpos: db 0
monomode: db 0
; ---- input
rk_pad:  ds 2
pad:     db 0
padnew:  db 0
keys:    db 0
keysnew: db 0
qaop:    db 0
; ---- render
dpage:   db 0
rpage:   db 0
rl_all:  ds 2
rl_cnt:  ds 8
rs_n:    db 0
rs_q:    db 0
rs_l:    db 0
rs_pg:   db 0
rs_vp:   db 0
fb_blk:  db 0
poolcnt: db 0
poolport: db 0
ca_idx:  db 0
spr_x:   dw 0
spr_y:   dw 0
spr_ink: db 0
sd_blk:  db 0
sd_sblk: db 0
sd_col:  dw 0
sd_top:  dw 0
sd_src:  dw 0
sd_cn:   db 0
sd_cx:   db 0
cb_s:    dw 0
cb_n:    db 0
cb_y:    dw 0
cb_r:    db 0
cb_left: db 0
cb_cell: dw 0
sb_sp:   dw 0
shake_off: db 0
txt_font: dw 0
txt_col: db 0
fc_glyph: dw 0
lp_n:    dw 0
lp_first: dw 0
glyphbuf: ds 16
ptbuf:   ds 64
; ---- sound
acc1:    dw 0
acc2:    dw 0
step1:   dw 0
step2:   dw 0
noiseon: db 0
musicon: db 0
sfxon:   db 0
mptr0:  dw 0
mbase0: dw 0
mleft0: db 0
mstep0: dw 0
mfin0:  db 0
mage0:  db 0
mptr1:  dw 0
mbase1: dw 0
mleft1: db 0
mstep1: dw 0
mfin1:  db 0
mage1:  db 0
mplaying: db 0
sfxstep: dw 0
sfxdelta: dw 0
sfxleft: db 0
sfxmode: db 0
sfxprio: db 0
sfxpend: db 0
tune:    db 0               ; the in-play tune now playing (1 game, 2 fright, 3 hunter)
; ---- the game
round:   db 0               ; 0-based
mazeidx: db 0
rtype:   db 0               ; 0 normal, 1 GHOST BUFFET, 2 PELLET PANIC
lvl:     db 0
score:   ds 3               ; BCD, high byte first
nextlife: db 0              ; BCD ten-thousands for the next extra life
lives:   db 0
hearts:  db 0
gtick:   db 0
paused:  db 0
demo:    db 0
gstate:  db 0
gtimer:  db 0
gresult: db 0
hud_dirty: db 0             ; b0 score, b1 hearts and lives
dots_left: dw 0
dotcol:  db 0
flashcol: db 0
mzname:  ds 17
mzrec:   dw 0
en_flash: db 0
p_spd:   db 0
g_spd:   db 0
fr_len:  db 0
; the hunter
p_x:     db 0               ; node i is at 12 * (i + 1); one unit = 2 pixels
p_y:     db 0
p_dir:   db 0               ; 0 R 1 L 2 U 3 D
p_want:  db 0               ; the direction asked for (4 = none)
p_acc:   db 0
p_moving: db 0
p_anim:  db 0
p_inv:   db 0
pn_x:    db 0               ; the node nearest the hunter
pn_y:    db 0
trail:   ds 16              ; where the hunter has been (speed trail)
shield:  db 0
streak:  db 0
streak_t: db 0
; timers (units of 2 frames, except bonus_t: 4 frames)
fr_time: db 0
fr_chain: db 0
t_hunter: db 0
t_freeze: db 0
t_speed: db 0
t_double: db 0
bonus_t: db 0
phase:   db 0
phase_t: db 0
; items
it_type: db 0
it_timer: db 0
it_count: db 0
it_seq:  db 0
it_shown: db 0
; the score that pops up
pop_t:   db 0
pop_x:   db 0
pop_y:   db 0
pop_f:   db 0
; HUD
bar_lab: db 0
bar_px:  db 0
say_t:   db 0
; scratch
a_ox:    db 0
a_oy:    db 0
g_node:  db 0
g_nx:    db 0
g_ny:    db 0
g_exits: db 0
g_best:  db 0
g_bdir:  db 0
g_id:    db 0
t_tx:    db 0
t_ty:    db 0
t_k:     db 0
t_n:     db 0
t_c:     db 0
t_r:     db 0
t_ptr:   dw 0
numbuf:  ds 8
; attract
att_t:   dw 0
att_end: dw 0
att_cb:  dw 0
hs_pos:  db 0
hs_ch:   db 0
vars_end:
