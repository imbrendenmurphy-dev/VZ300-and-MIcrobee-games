; =====================================================================
;  variables (zeroed at start-up) in the upper block below the stack
; =====================================================================
vars_start:
; ---- actors: NACT x ASZ (enemies)
actors:  ds NACT*ASZ
bombs:   ds NBOMB*BSZ
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
mptr1:  dw 0
mbase1: dw 0
mleft1: db 0
mstep1: dw 0
mfin1:  db 0
mplaying: db 0
sfxstep: dw 0
sfxdelta: dw 0
sfxleft: db 0
sfxmode: db 0
sfxprio: db 0
sfxpend: db 0
; ---- the game
stage:   db 0               ; 0-based stage number
score:   ds 3               ; BCD, high byte first
hiscore: ds 3
gtick:   db 0
paused:  db 0
quit:    db 0
gstate:  db 0               ; 0 playing, 1 stage clear, 2 game over
gtimer:  db 0
msg_on:  db 0
allclear: db 0
nenemy:  db 0
hud_dirty: db 0
chain:   db 0               ; explosions this frame (chain reactions)
; the player
p_hx:    db 0               ; position in 2-pixel units (tile = 8)
p_hy:    db 0
p_dir:   db 0               ; 0 R 1 L 2 U 3 D
p_anim:  db 0
p_idle:  db 0
p_moving: db 0
p_act:   db 0               ; ACT_*
p_actt:  db 0
p_inv:   db 0
p_safe:  db 0
p_hearts: db 0
p_maxh:  db 0
p_bombs: db 0
p_range: db 0
p_speed: db 0
p_last:  db 0               ; newest direction pressed (bit number)
p_buf:   db 0               ; tapped direction remembered
p_buft:  db 0
bomb_edge: db 0
; the boomerang
bm_on:   db 0
bm_hx:   db 0
bm_hy:   db 0
bm_dx:   db 0
bm_dy:   db 0
bm_dist: db 0
bm_out:  db 0
bm_f:    db 0
bm_carry: db 0              ; bomb number + 1 being carried
; scratch
t_tx:    db 0
t_ty:    db 0
t_k:     db 0
t_n:     db 0
t_dir:   db 0
t_best:  db 0
t_ptr:   dw 0
t_idx:   dw 0
t_sx:    db 0
t_sy:    db 0
t_rng:   db 0
t_dt:    db 0
t_ph:    db 0
preview: db 0
msg_t:   db 0
said_log: db 0
numbuf:  ds 8
vars_end:
