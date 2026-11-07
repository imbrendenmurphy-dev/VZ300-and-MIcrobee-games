; ===================================================================
;  vars.asm - variables and buffers (uninitialised area)
; ===================================================================
curband:    db 0FFh
lowport:    db 0
ovl_ret:    db 0
ovcols:     db 0
ovcol:      db 0
ov_x:       db 0
ov_y:       db 0
ovtown:     ds 22*8
ovriv:      ds 22*8
opt_rivals: db 0FFh
pr_r:       db 0
pr_try:     db 0
ri_cur:     db 0
ri_try:     db 0
tcol:       db 0
frames:     dw 0
mono:       db 0
sound_on:   db 1
snd_type:   db 0
snd_hi:     db 0
snd_lo:     db 0
snd_cnt:    db 0
snd_ph:     db 0
fx_ptr:     dw 0
fx_left:    db 0
fx_per:     db 0
fx_wide:    db 0
mu_ptr:     dw 0
mu_start:   dw 0
mu_left:    db 0
mu_len:     db 0
mu_per:     db 0
mu_on:      db 0
dos_colour: db 0
title_played: db 0
quit_flag:  db 0
txtcol:     db 0
cellcol:    db 0
pr_off:     dw 0
pr_len:     dw 0
numbuf:     ds 8
txtbuf:     ds 96
ms_idle:    db 0
ms_bitn:    db 110
ms_half:    db 55
ms_frameN:  dw 0
ms_seen:    db 0
ms_ok:      db 0
ms_btn:     db 0
ms_obtn:    db 0
ms_click:   db 0
ms_b1:      db 0
ms_b2:      db 0
ms_b3:      db 0
ms_ax:      dw 0
ms_ay:      dw 0
ms_sens:    db 12
ms_mu:      db 0
ms_md:      db 0
ms_ml:      db 0
ms_mr:      db 0
keys_now:   ds 5
keys_prev:  ds 5
keys_hit:   ds 5
; world gen
gdest:  dw 0
gout:   dw 0
gptr:   dw 0
gmode:  db 0
gshift: db 0
gamp:   db 0
gsp:    db 0
gcells: db 0
ggw:    db 0
gy:     db 0
gyi:    db 0
gfy:    db 0
gta:    db 0
gfall:  db 0
graise: db 0
gmbias: db 0
gcount: db 0
gtries: db 0
gsteps: db 0
gcur:   db 0
glow:   db 0
glowxy: dw 0
gcnt:   db 0
grad:   db 0
barval: db 0
grid:   ds 1200                 ; world generation only ...
rowbuf  equ grid                ; ... shared with save/load (never at the same time)
st_buf  equ grid+512
colv:   ds 40
colacc: ds 40*4
th_desert: db 46
th_marsh: db 200
th_dense: db 168
th_forest: db 126
; render
tterr:  db 0
tL:     db 0
tR:     db 0
cL:     db 0
cR:     db 0
nbmode: db 0
nb_n:   db 0
nb_s:   db 0
nb_w:   db 0
nb_e:   db 0
dv_bank: db 0
dv_x0:  db 0
dv_y0:  db 0
dv_w:   db 0
dv_h:   db 0
dv_rn:  db 0
sc_ox:  db 0
sc_oy:  db 0
sc_dx:  db 0
sc_dy:  db 0
sc_nb:  db 0
sc_n:   db 0
sc_len: dw 0
dv_r:   db 0
dv_c:   db 0
cursor_bc: dw 0
curoff: dw 0
curshown: db 0
cu_code: db 0
cu_bank: db 0
cu_set:  db 0
cu_buf:  ds 11
; game
overview: db 0
loopn:  db 0
workers: dw 0
dfood:  dw 0
dwood:  dw 0
dstone: dw 0
dgold:  dw 0
nwell:  db 0
nmarket: db 0
ntower: db 0
nobj:   db 0
nrad:   db 0
ptr:    db 0
cnt_t1: db 0
cnt_t2: db 0
rv_r:   db 0
rv_x:   db 0
rv_y:   db 0
rv_dx:  db 0
rv_dy:  db 0
rv_r2:  dw 0
msgptr: dw 0
msgcol: db 0
msgtimer: db 0
hintptr: dw 0
dirty_view: db 0
dirty_status: db 0
dirty_msg: db 0
want_season: db 0
want_done: db 0
want_grow: db 0
want_warn: db 0
want_jingle: db 0
want_goal: db 0
want_research: db 0
dirty_tools: db 0
animf:  db 0
animt:  db 0
af4:    db 0
ag:     db 0
anf:    db 0
afr:    db 0
mv_u:   db 0
mv_d:   db 0
mv_l:   db 0
mv_r:   db 0
rep:    db 0
ov_d:   db 0
ov_e:   db 0
ov_row: dw 0
ov_mono: db 0
ovx0:   db 0
ovx1:   db 0
ovy0:   db 0
ovy1:   db 0
bg_x:   db 0
bg_g:   db 0
bg_row: db 0
bg_col: db 0
bg_colr: db 0
; ---- everything below up to sv_end is saved with the world ----
sv_start:
worldtype: db 0
worldsize: db 0
mapwm1: db 127
maphm1: db 127
mapcx: db 64
mapcy: db 64
vxmax: db 88
vymax: db 108
ovcw: db 3
ovch: db 6
seed: dw 1234h
food: dw 0
wood: dw 0
stone: dw 0
gold: dw 0
pop: dw 0
happy: db 0
season: db 0
week: db 0
year: dw 0
speed: db 0
lastspeed: db 0
tickc: db 0
tool: db 0
tpage: db 0
cur_tech: db 0
forum_done: db 0
techs: dw 0
rpoints: dw 0
nrivals: db 0
rivals: ds 3*16
scen: db 0
goal_done: db 0
nexpl: dw 0
nbld: db 0
viewx: db 0
viewy: db 0
curx: db 0
cury: db 0
startxy: dw 0
blist:  ds MAXBLD*BREC
sv_end:

; random table for stable per-tile variation
rtab:
        db 157,44,203,9,118,240,77,31,192,63,140,5,88,229,116,19
        db 251,70,134,200,13,97,166,58,221,36,180,121,2,149,84,239
        db 45,190,26,111,214,67,153,8,248,100,175,52,129,16,207,92
        db 33,236,141,73,197,24,105,162,57,218,124,1,186,79,145,233
        db 10,171,94,48,226,137,20,199,86,252,65,114,40,183,159,3
        db 127,212,55,96,244,29,168,142,75,6,195,110,50,224,133,17
        db 89,232,61,178,12,151,103,206,39,250,82,125,164,27,217,60
        db 4,147,192,99,35,241,117,68,185,14,209,156,46,135,80,227
        db 173,21,108,254,66,139,201,7,90,160,42,230,119,187,53,95
        db 213,30,144,76,246,11,169,128,59,198,102,37,181,84,15,234
        db 64,155,25,120,219,72,193,0,138,47,247,109,163,32,205,98
        db 18,177,87,228,54,131,210,62,113,243,38,170,79,148,22,196
        db 255,104,49,184,126,6,216,71,152,91,23,237,57,174,130,43
        db 202,15,161,83,245,34,123,189,51,107,222,1,146,68,180,253
        db 28,136,211,93,41,167,115,250,74,19,194,143,56,231,101,9
        db 172,85,238,116,12,158,69,208,132,36,245,97,179,26,220,63
; buffers
SCHR:   ds SCRSIZE
SATR:   ds SCRSIZE
SCOL:   ds SCRSIZE


; save/load
svc_sp:   dw 0
tb_t:     db 0
nschool:  db 0
nuniv:    db 0
nhosp:    db 0
ntemple:  db 0
nforum:   db 0
rp_week:  dw 0
msgbuf:   ds 96
fm_mode:  db 0
fm_slot:  db 0
fm_act:   db 0
sv_res:   db 0
sv_name:  ds 11
sv_hdr:   ds 128
sv_heads: ds 96
sv_cnt:   ds 3
st_blk:   db 0
st_off:   dw 0
st_n:     db 0
st_rp:    db 0
st_total: ds 3
st_sum:   dw 0
rle_val:  db 0
rle_len:  db 0

        ds 256
stacktop:
