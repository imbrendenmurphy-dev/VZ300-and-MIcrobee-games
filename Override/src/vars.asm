; =====================================================================
;  vars.asm - RAM variables and record layouts (not in the .VZ image)
; =====================================================================
; ---- object record (player and droids)
O_FLAGS     equ 0              ; bit 7 alive
O_TYPE      equ 1
O_XF        equ 2              ; x fraction (16ths)
O_XL        equ 3              ; x pixel (16 bits)
O_XH        equ 4
O_YF        equ 5
O_Y         equ 6              ; y row
O_VX        equ 7              ; velocity, 16ths of a pixel a frame (player)
O_VY        equ 8
O_EN        equ 9              ; energy
O_MAXE      equ 10
O_COOL      equ 11             ; weapon cooldown
O_SLOT      equ 12             ; sprite cache slot
O_FLASH     equ 13             ; hit flash
O_TGT       equ 14             ; waypoint heading for
O_PREV      equ 15             ; waypoint come from
O_TIMER     equ 16
O_SPAWN     equ 17             ; bit in the deck's alive mask
O_FACE      equ 18             ; direction 0-7
O_SEEN      equ 19             ; can see the player
O_RAM       equ 20             ; collision cooldown
O_THINK     equ 21             ; frames to the next sight test
O_INV       equ 22             ; invulnerable (player)
OSZ         equ 24
MAXDROIDS   equ 16

; ---- type stats (gen/types.inc)
T_NUM       equ 0
T_EN        equ 2
T_SPEED     equ 3
T_WEAPON    equ 4
T_AGGR      equ 5
T_CLASS     equ 6
T_SCORE     equ 7
TSZ         equ 10

; ---- deck info (from OVsDd.DAT)
DI_NAME     equ 0
DI_W        equ 13
DI_H        equ 14
DI_NWPT     equ 15
DI_NDROIDS  equ 16
DI_NLIFTS   equ 17
DI_LIFTS    equ 18             ; 3 x (shaft, tx, ty)
DI_DROIDS   equ 27             ; 16 x (type, waypoint)
DI_NCON     equ 59
DI_CONS     equ 60
DISZ        equ 64
; ---- ship info (from OVs.DAT)
SI_NAME     equ 0
SI_NDECKS   equ 16
SI_START    equ 17
SI_NSHAFTS  equ 18
SI_SHAFTS   equ 19
SI_DECKS    equ 24
SD_NAME     equ 0
SD_W        equ 13
SD_H        equ 14
SD_OFF      equ 15
SD_NDROIDS  equ 16
SD_SHAFTS   equ 17
SDSZ        equ 18
SISZ        equ SI_DECKS+8*SDSZ

MAXDOORS    equ 24
DOORSZ      equ 8
MAXSHOTS    equ 14
SHSZ        equ 10
MAXFX       equ 8
FXSZ        equ 5
MAXWPT      equ 80
WPT         equ $F600          ; waypoint table, upper bank 1 (80 x 8)
NSHIPS      equ 3
DEMO_FRAMES equ 750

EV_TRANSFER equ 1
EV_LIFT     equ 2
EV_CONSOLE  equ 3
EV_DEATH    equ 4
EV_CLEARED  equ 5

            noemit
            org VARS
; ---- system
fieldctr:   ds 1
lastcopy:   ds 1
ready:      ds 1
intoff:     ds 1
hud_dirty:  ds 1
isr_sp:     ds 2
frames:     ds 2
latchv:     ds 1
cur_map:    ds 1
dos_map:    ds 1
joyok:      ds 1
in_now:     ds 1
in_new:     ds 1
in_real:    ds 1
rng:        ds 2
fcp_n:      ds 2
snd_step:   ds 2
snd_mask:   ds 1
snd_noise:  ds 1
music_on:   ds 1
; ---- ring
rb_n:       ds 1
rb_x:       ds 1
rb_ring:    ds 2
rb_sr:      ds 1
rb_map:     ds 2
rr_ring:    ds 2
rr_base:    ds 2
rr_map:     ds 2
rr_x:       ds 1
rr_n:       ds 1
rf_n:       ds 1
rf_x:       ds 1
cam_x:      ds 2
cam_y:      ds 1
ring_vx:    ds 1
ring_vy:    ds 1
tp_x:       ds 1
tp_n:       ds 1
tp_r0:      ds 1
tp_rn:      ds 1
wc_ph:      ds 1
wc_s:       ds 1
wc_rs:      ds 2
wc_n:       ds 1
tset:       ds 2
; ---- sprites, text
bs_src:     ds 2
bs_dst:     ds 2
bs_p:       ds 1
bs_row:     ds 2
bs_d:       ds 4
bs_m:       ds 4
ds_blk:     ds 2
ds_n:       ds 1
ds_src:     ds 2
ds_sp:      ds 2
spr_sil:    ds 1
pd_c:       ds 1
txt_base:   ds 2
txt_stride: ds 1
txt_fg:     ds 1
txt_bg:     ds 1
txt_tab:    ds 8
; ---- deck
bh_mask:    ds 1
bh_x:       ds 2
bh_y:       ds 1
bh_dy:      ds 1
bh_yy:      ds 1
bh_attr:    ds 1
ndoors:     ds 1
doors:      ds MAXDOORS*DOORSZ
dr_cx:      ds 2
dr_cy:      ds 1
dr_near:    ds 1
dr_in:      ds 1
deck_w:     ds 1
deck_h:     ds 1
; ---- droids
sp_n:       ds 1
sp_i:       ds 1
cur_alive:  ds 2
slot_type:  ds 8
dm_step:    ds 1
dm_ax:      ds 1
dn_deg:     ds 1
dn_list:    ds 2
hn_best:    ds 1
hn_dist:    ds 2
hn_cand:    ds 1
ls_dx:      ds 2
ls_dy:      ds 1
ls_x:       ds 2
ls_y:       ds 1
df_w:       ds 1
d8_sx:      ds 1
d8_ax:      ds 1
d8_sy:      ds 1
d8_ay:      ds 1
plr:        ds OSZ
droids:     ds OSZ*MAXDROIDS
; ---- player
p_in:       ds 1
p_dirs:     ds 1
p_spd:      ds 1
p_tvx:      ds 1
p_tvy:      ds 1
p_acc:      ds 1
p_under:    ds 1
p_burn:     ds 1
mv_n:       ds 1
mv_d:       ds 1
p_push:     ds 1
p_held:     ds 1
p_tmode:    ds 1
p_low:      ds 1
; ---- shots, effects
fs_w:       ds 1
fs_dir:     ds 1
fs_own:     ds 1
fs_spd:     ds 1
fs_dmg:     ds 1
fs_life:    ds 1
fs_vx:      ds 1
fs_vy:      ds 1
fs_x:       ds 2
fs_y:       ds 2
sh_x:       ds 2
sh_y:       ds 1
sh_dmg:     ds 1
sh_col:     ds 1
shots:      ds SHSZ*MAXSHOTS
fxs:        ds FXSZ*MAXFX
; ---- hud, score
msg_t:      ds 1
msg_p:      ds 2
hud_all:    ds 1
hud_n:      ds 1
hud_e:      ds 1
hud_s:      ds 1
hud_buf:    ds 8
he_px:      ds 1
he_col:     ds 1
lives:      ds 1
score:      ds 3
hiscore:    ds 3
hitab:      ds 5*6            ; 5 x (3 BCD score, 3 initials)
; ---- sound
sfx_on:     ds 1
sfx_p:      ds 2
sfx_cur:    ds 1
sfx_n:      ds 1
snd_rd:     ds 1               ; sample ring read / write positions
snd_wr:     ds 1
; ---- game flow
fc_a:       ds 1
fc_hl:      ds 2
gm_on:      ds 1
demo:       ds 1
gn_map:     ds 1
gn_sp:      ds 2
ship:       ds 1
demo_t:     ds 2
demo_ship:  ds 1
deck_alive: ds 32
cur_deck:   ds 1
deck_loaded: ds 1
arr_lift:   ds 1
arr_shaft:  ds 1
event:      ds 1
xfer_obj:   ds 2
xf_enemy:   ds 1
xf_mine:    ds 1
xf_result:  ds 1
lf_deck:    ds 1
lf_shaft:   ds 1
nl_best:    ds 2
nl_shaft:   ds 1
wfg_n:      ds 1
; ---- autopilot
ap_keys:    ds 1
ap_tgt:     ds 2
ap_have:    ds 1
ap_dx:      ds 2
ap_dy:      ds 1
ap_node:    ds 1
ap_lastx:   ds 2
ap_lasty:   ds 1
ap_stuck:   ds 1
ap_best:    ds 2
ap_next:    ds 1
bf_start:   ds 1
bf_head:    ds 2
bf_tail:    ds 2
bf_cur:     ds 1
bf_nd:      ds 1
bfs_d:      ds MAXWPT
bfs_q:      ds MAXWPT+4
; ---- SD
sd_name:    ds 2
dat_id:     ds 2
sd_map:     ds 1
sd_savesp:  ds 2
sd_try:     ds 1
sd_cmap:    ds 1
sd_dst:     ds 2
sd_len:     ds 2
sd_left:    ds 2
sd_rd:      ds 2
; ---- ship / deck
shipinfo:   ds SISZ
dinfo:      ds DISZ
vars_end:
            assert vars_end <= DIV6
DIV6        equ $B500          ; y / 6, one page
            emit
