; =====================================================================
;  vars.asm - RAM variables and object tables (not in the .VZ image)
; =====================================================================
            noemit
            org VARS
; ---- system
fieldctr:   ds 1
lastcopy:   ds 1
lastfr:     ds 1
ready:      ds 1
cphase:     ds 1
intoff:     ds 1
minfields:  ds 1
dtf:        ds 1
bbh:        ds 1               ; high byte of the buffer being drawn
cps:        ds 1               ; high byte of the buffer the ISR copies
tmark:      ds 1
frames:     ds 2
latchv:     ds 1
cur_map:    ds 1
dos_map:    ds 1
joyok:      ds 1
in_now:     ds 1
in_new:     ds 1
in_real:    ds 1
in_demokey: ds 1
demo_on:    ds 1
demo_in:    ds 1
kn_last:    ds 1
rng:        ds 2
dat_id:     ds 2
; ---- sound
snd_ph:     ds 2
snd_step:   ds 2
snd_mask:   ds 1
sfx_p:      ds 2
sfx_n:      ds 1
sfx_cur:    ds 1
mus_base:   ds 2
mus_p:      ds 2
mus_t:      ds 1
mus_on:     ds 1
mus_blipl:  ds 1
blip:       ds 1
music_off:  ds 1
; ---- SD
sd_name:    ds 2
sd_savesp:  ds 2
sd_try:     ds 1
sd_cmap:    ds 1
sd_map:     ds 1
sd_dst:     ds 2
sd_len:     ds 2
sd_left:    ds 2
sd_rd:      ds 2
; ---- scroller
scx:        ds 2               ; ground scroll in pixels
g_n:        ds 2               ; next ground column to put in the rings
g_prev:     ds 2               ; tile data of column g_n-1
gm_p:       ds 2               ; ground map pointer
gm_left:    ds 2               ; columns left in this map segment
gm_seg:     ds 1               ; segment number
s_n:        ds 2
s_prev:     ds 2
sm_i:       ds 1               ; skyline map index (0..SKY_C-1)
rp_rows:    ds 1
rp_base:    ds 2
rp_stride:  ds 2
rp_n:       ds 1
bg_sp:      ds 2
scroll_on:  ds 1
scroll_sub: ds 1               ; fraction for slower/faster scrolling
cloud_x:    ds 3
; ---- blitter
bl_sp:      ds 2
bl_ix:      ds 2
bl_id:      ds 1
bl_bc:      ds 2
bl_step:    ds 2
bl_flash:   ds 1
bl_rec:     ds 2
bl_wb:      ds 1
bl_h:       ds 1
bl_c0:      ds 1
bl_y:       ds 1
bl_x:       ds 1
bl_ys:      ds 1
; ---- text
tx_fg:      ds 1
tx_ptr:     ds 2
; ---- player
p_xf:       ds 1
p_x:        ds 1               ; stored +XOFF
p_yf:       ds 1
p_y:        ds 1               ; stored +YOFF
p_char:     ds 1               ; 0 GAZZA 1 CUPPA 2 TOASTIE
p_speed:    ds 1               ; 0..3   (power slots 1-4 in this order)
p_bomb:     ds 1               ; 0/1
p_shot:     ds 1               ; 0..2
p_buddy:    ds 1               ; 0..2
p_shield:   ds 1               ; hits left on the shield
p_health:   ds 1               ; 0..3
p_lives:    ds 1
p_inv:      ds 1               ; invulnerable fields
p_cool:     ds 1               ; fire cooldown
p_bcool:    ds 1               ; bomb cooldown
p_cursor:   ds 1               ; power bar cursor 0 (none) .. 5
p_dead:     ds 1               ; >0: exploding / respawn countdown
p_tilt:     ds 1
p_hits:     ds 1               ; hits taken this stage
p_hist:     ds 64              ; position history (x,y pairs) for buddies
p_hpos:     ds 1
score:      ds 3               ; BCD, high byte first
hiscore:    ds 3
chain:      ds 1               ; current kill chain (x1..x8)
chain_t:    ds 1               ; fields left to keep the chain alive
chain_max:  ds 1
extra_at:   ds 1               ; next extra life at score (x10000, BCD)
hud_dirty:  ds 1
bbar_dirty: ds 1
bar_dirty:  ds 1
; ---- stage
stg_phase:  ds 1               ; 0 play, 1 midboss, 2 boss, 3 clear, 4 game over
tl_p:       ds 2               ; timeline pointer
tl_col:     ds 2               ; ground column counter for the timeline
tl_hold:    ds 1               ; timeline paused (boss on screen)
route:      ds 1               ; 0 roof, 1 garden
secrets:    ds 1               ; bit0 golden gnome, bit1 route garden...
msg_p:      ds 2
msg_t:      ds 1
msg_row:    ds 1
msg_last:   ds 2
msg_c0:     ds 1
msg_w:      ds 1
msg_buf:    ds 160
wave_kills: ds 8               ; per formation: kills needed for the bonus
wave_left:  ds 8
spawn_q:    ds 2               ; pending formation spawn: pointer
spawn_n:    ds 1
spawn_t:    ds 1
spawn_gap:  ds 1
spawn_grp:  ds 1
boss_hp:    ds 2
boss_max:   ds 2
boss_ph:    ds 1
boss_t:     ds 2
boss_x:     ds 1
boss_y:     ds 1
boss_st:    ds 1
boss_slot:  ds 1
boss_bar:   ds 1
eshot_rate: ds 1
tick:       ds 1
attract_n:  ds 1
demo_t:     ds 2
clear_t:    ds 1
pause_on:   ds 1
coins:      ds 1
kills:      ds 2
work:       ds 16
; ---- engine scratch
scrolled:   ds 1               ; the ground moved this frame
cur_trec:   ds 2
aim_s:      ds 1
aim_dx:     ds 1
aim_dy:     ds 1
aim_m:      ds 1
aim_sg:     ds 1
eb_grav:    ds 1
hb_x:       ds 1
hb_y:       ds 1
hb_w:       ds 1
hb_h:       ds 1
pb_x:       ds 1
pb_y:       ds 1
kill_flags: ds 1
spawn_y:    ds 1
trainer:    ds 1
in_game:    ds 1
game_won:   ds 1               ; the last stage was cleared
start_stage: ds 1              ; (the trainer can start anywhere)
fe_skip:    ds 1               ; a key ended the demo: go to the cast select
seg_p:      ds 2               ; ground segment table pointer
mid_done:   ds 1
cloud_spr:  ds 1               ; sprite drifting across the sky (0 none)
stg_cnt:    ds 1               ; a counter for the stage's own use
boss_base:  ds 1
bs_kind:    ds 1               ; 0 midboss, 1 boss
bs_def:     ds 2
bs_php:     ds 2
bs_phase:   ds 1
bs_tell:    ds 1
bs_track:   ds 1
bs_mdx:     ds 1
bs_mdy:     ds 1
bs_spr:     ds 1
bs_armt:    ds 1
stage_tune: ds 2
wallet:     ds 1               ; coins to spend in the shop
; ---- game
stage_no:   ds 1               ; 1..
stage_ld:   ds 1               ; stage pack in memory (0 none)
round:      ds 1               ; 0 first time round, 1+ harder
diff:       ds 1               ; 0 easy 1 normal 2 hard
credits:    ds 1               ; continues used
bonus_sec:  ds 1               ; secret bonus collected this stage (x1000)
stg_time:   ds 2               ; frames spent in the stage
boss_hits0: ds 1               ; p_hits when the boss appeared
fe_t:       ds 2
fe_sel:     ds 1
fe_sub:     ds 1
ent_pos:    ds 1
ent_name:   ds 4
ent_rank:   ds 1
demo_tgt:   ds 1
demo_buy:   ds 1
logo_x:     ds 1
; ---- object tables
NOBJ        equ 22
OSZ         equ 16
O_T         equ 0              ; type (0 = free)
O_SPR       equ 1              ; sprite frame base
O_XF        equ 2
O_X         equ 3              ; x + XOFF
O_YF        equ 4
O_Y         equ 5              ; y + YOFF
O_VX        equ 6              ; 16-bit 8.8 signed
O_VY        equ 8
O_HP        equ 10
O_TM        equ 11
O_ST        equ 12
O_P         equ 13
O_FL        equ 14             ; flags (below)
O_GRP       equ 15
F_FLASH     equ 0              ; bit: hit flash this frame
F_GROUND    equ 1              ; moves with the ground scroll
F_FX        equ 2              ; effect: no collisions
F_ANIM      equ 3              ; two-frame animation
F_HARM      equ 5              ; hurts on touch
F_PICK      equ 6              ; pickup (player collects)
objs:       ds NOBJ*OSZ
objs_end:
NPS         equ 12             ; player shots
PSZ         equ 8
P_T         equ 0              ; kind (0 = free)
P_X         equ 1
P_XF        equ 2
P_Y         equ 3
P_YF        equ 4
P_VX        equ 5              ; signed, 1/16 px per field
P_VY        equ 6
P_A         equ 7              ; aux (life / target)
pshots:     ds NPS*PSZ
NEB         equ 18             ; enemy bullets
EBSZ        equ 8
E_T         equ 0              ; sprite id (0 = free)
E_XF        equ 1
E_X         equ 2
E_YF        equ 3
E_Y         equ 4
E_VX        equ 5              ; signed, 1/32 px per field
E_VY        equ 6
E_G         equ 7              ; gravity (1/32 px per field per field)
ebul:       ds NEB*EBSZ
vars_end:
            assert vars_end <= BB
            emit
