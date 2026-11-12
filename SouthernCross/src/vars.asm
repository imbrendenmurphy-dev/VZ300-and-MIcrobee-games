; ============================================================================
;  VARIABLES (cleared at start-up)
; ============================================================================
VARS:
latch:          ds 1            ; current latch value (mode 1, CSS, speaker off)
latch_next:     ds 1            ; applied with the next frame
frame_ready:    ds 1
fieldcnt:       ds 1
irqflag:        ds 1
hud_dirty:      ds 1
isr_sp:         ds 2
ticks:          ds 2
seed:           ds 2
; audio
acc1:           ds 2
acc2:           ds 2
out1_step:      ds 2
out1_duty:      ds 1
out2_step:      ds 2
out2_duty:      ds 1
MCH1:           ds MCSIZE
MCH2:           ds MCSIZE
sfx_ptr:        ds 2
sfx_prio:       ds 1
song_done:      ds 1
opt_sound:      ds 1
opt_music:      ds 1
shotsnd:        ds 1
; timing measurement
spare_last:     ds 2            ; idle audio-loop passes in the last frame (x139 T)
spare_min:      ds 2
late_frames:    ds 2
frames:         ds 2
cpubar_tm:      ds 1
ds_rows:        ds 1
ds_wb:          ds 1
; input
keys:           ds 1
keys_old:       ds 1
keys_new:       ds 1
; mode
mode:           ds 1            ; 0 title, 1 play, 2 game over
mode_tm:        ds 2
paused:         ds 1
; scrolling
dist:           ds 2            ; stage rows travelled (bottom screen row)
scroll_acc:     ds 1
scroll_rate:    ds 1            ; 0 = 1 row a frame, else rows*256 per frame
scroll_step:    ds 1            ; rows scrolled this frame (0/1)
cb_k:           ds 2
cb_left:        ds 1
; stage progress
cp_ptr:         ds 2            ; checkpoint: wave pointer, delay, distance
cp_tm:          ds 1
cp_dist:        ds 2
warn_tm:        ds 1
clear_tm:       ds 2
cont_tm:        ds 2
tink_tm:        ds 1
; boss
boss_ph:        ds 1            ; 0 none 1 arriving 2 arms 3 core 4 dying
bx:             ds 1
by:             ds 1
bang:           ds 1
bspeed:         ds 1
bdir:           ds 1
bsway:          ds 1
bfire_tm:       ds 1
bnext:          ds 1
barms:          ds 1
bdie_tm:        ds 1
bvolley:        ds 1
lb_cx:          ds 1
lb_cy:          ds 1
lb_dx:          ds 1
lb_dy:          ds 1
lb_x:           ds 4
lb_y:           ds 4
en_top:         ds 1
txtbuf:         ds 24
dt_col:
dt_paper:       ds 1
dt_ink:         ds 1
flash_tm:       ds 1
; player
px:             ds 1
py:             ds 1            ; y16 (screen y + 16)
pbank:          ds 1            ; 0 centre 1 left 2 right
pinv:           ds 1            ; invulnerable frames
pdead:          ds 1            ; death countdown
lives:          ds 1
wlevel:         ds 1            ; weapon level 1-3
firecd:         ds 1
anim:           ds 1
stars_mask:     ds 1            ; attached stars (for the HUD)
score:          ds 4            ; BCD, 8 digits, most significant first
hiscore:        ds 4
score_dirty:    ds 1
game_song:      ds 1
; waves
wave_ptr:       ds 2
wave_tm:        ds 1
spawn_left:     ds 1
spawn_tm:       ds 1
spawn_type:     ds 1
spawn_path:     ds 2
spawn_x:        ds 1
spawn_sp:       ds 1
spawn_grp:      ds 1
grp_next:       ds 1
GRP:            ds 8*GRSIZE
; object tables
ETAB:           ds NEN*EOSIZE
EBTAB:          ds NEB*EBSIZE
PSTAB:          ds NPS*PSSIZE
EXTAB:          ds NEX*EXSIZE
PUTAB:          ds NPU*PUSIZE
STTAB:          ds 4*STSIZE
VARS_END:
; title player (cleared on the title)
TITLEVARS:
TCH1:           ds TCSIZE
TCH2:           ds TCSIZE
TCH3:           ds TCSIZE
td_ptr:         ds 2
td_dur:         ds 1
t_acc1:         ds 2
t_acc2:         ds 2
t_acc3:         ds 2
t_cnt:          ds 1
t_nlen:         ds 1
t_npos:         ds 2
t_upload:       ds 1
t_upsrc:        ds 2
t_updst:        ds 2
TITLEVARS_END:
; SD loader
DOSMAP:         ds 1
ld_dest:        ds 2
ld_left:        ds 2
ld_bank:        ds 1
ld_name:        ds 2
ld_sp:          ds 2
