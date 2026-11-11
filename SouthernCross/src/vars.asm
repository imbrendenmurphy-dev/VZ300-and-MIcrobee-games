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
top:            ds 1            ; strip row shown on the top screen row
scroll_acc:     ds 1
scroll_rate:    ds 1            ; 0 = 1 row a frame, else rows*256 per frame
scroll_step:    ds 1            ; rows scrolled this frame (0/1)
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
