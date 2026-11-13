; =====================================================================
;  vars.asm - RAM variables (not part of the .VZ image)
; =====================================================================
            noemit
            org VARS
; ---- system
fieldctr:   ds 1
lastcopy:   ds 1
lastfr:     ds 1
ready:      ds 1
intoff:     ds 1
minfields:  ds 1
dtf:        ds 1
tmark:      ds 1
frames:     ds 2
copy_src:   ds 2
copy_dst:   ds 2
copy_rows:  ds 1
dirty_top:  ds 1
dirty_prev: ds 1
latchv:     ds 1
cur_map:    ds 1
dos_map:    ds 1
joyok:      ds 1
in_now:     ds 1
in_new:     ds 1
in_real:    ds 1
rng:        ds 2
fc_hl:      ds 2
fc_a:       ds 1
fc_tgt:     ds 2
; ---- sound (ISR)
snd_ph:     ds 2
snd_step:   ds 2
snd_mask:   ds 1
; ---- SD
sd_name:    ds 2
sd_savesp:  ds 2
sd_try:     ds 1
sd_cmap:    ds 1
sd_dst:     ds 2
sd_len:     ds 2
sd_left:    ds 2
sd_rd:      ds 2
; ---- background
hz:         ds 1
cam_cf:     ds 1
camx:       ds 2
zs:         ds 2
pano_x:     ds 1
sky_byte:   ds 1
bg_n:       ds 1
bg_sp:      ds 2
gr_dst:     ds 2
gr_left:    ds 1
; ---- sprite blitter
spr_x:      ds 2
spr_y:      ds 2
sp_wb:      ds 1
sp_h:       ds 1
sp_key:     ds 1
sp_src:     ds 2
sp_col:     ds 2
sp_rows:    ds 1
sp_top:     ds 1
sp_c0:      ds 1
bl_sp:      ds 2
; ---- objects / projection
pj_e:       ds 1
pj_m:       ds 1
pj_neg:     ds 1
pj_my:      ds 1
pj_zi:      ds 1
; ---- messages / HUD
msg_w:      ds 1
mt_b0:      ds 1
mt_b1:      ds 1
mt_cw:      ds 1
mt_n:       ds 1
hud_buf:    ds 8
mt_tab:     ds 2
msg_y:      ds 1
mb_y:       ds 1
; ---- wave spawner
wv_pat:     ds 1
wv_spr:     ds 1
wv_n:       ds 1
wv_x:       ds 1
wv_y:       ds 1
wv_amp:     ds 1
wv_spd:     ds 1
wv_fire:    ds 1
wv_pts:     ds 1
wv_hp:      ds 1
wv_i:       ds 1
cz_lo:      ds 2
cz_hi:      ds 2
tgt_n:      ds 1
tgt_p:      ds 2
tgt_list:   ds 2*NOBJ
; ---- game
            include "gvars.asm"
skyrow:     ds 32
bkt:        ds 56               ; depth buckets: first object index + 1
dl_t:       ds 2
vars_end:
            assert vars_end <= BB
            emit
