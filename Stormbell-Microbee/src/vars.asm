; =====================================================================
;  variables (upper RAM, cleared at start)
; =====================================================================
        ORG VARS
hero:       ds F_SIZE
foe:        ds F_SIZE
pad:        db 0
padnew:     db 0
lastnew:    db 0
wt:         db 0
fields:     db 0
vlast:      db 0
ticks:      db 0
vispage:    db 0
hidpage:    db 0
flip_ask:   db 0
drawpage:   dw 0
pl_bank:    db 0
picblk:     db 0
picbase:    dw 0
rseed:      dw 0
stage:      db 0
msg_t:      db 0
hud_dirty:  db 0
counter_flash: db 0
blocked_flag: db 0
gap:        db 0
seen:       db 0
punished:   db 0
guard_t:    db 0
brainp:     dw 0
scriptp:    dw 0
scr_pc:     db 0
scr_t:      db 0
rangep:     dw 0
; render
rng_a:      dw 0
rng_b:      dw 0
rng_n:      db 0
rng:        ds 4
r_fn:       dw 0
r_wbase:    dw 0
r_vofs:     dw 0
r_c0:       db 0
r_c1:       db 0
r_n:        db 0
r_top:      db 0
r_have:     dw 0
r_vid:      dw 0
poolused:   db 0
d_w:        db 0
d_h:        db 0
d_x0:       db 0
d_row:      dw 0
c_want:     dw 0
c_ink:      db 0
c_code:     db 0
c_top:      ds 20
c_bot:      ds 10
; sound
sound_on:   db 0
sfx_p:      dw 0
sfx_n:      db 0
sfx_pri:    db 0
mus_base:   dw 0
mus_on:     db 0
mus_hold:   db 0
saved_tune: dw 0
ch1:        ds CH_SIZE
ch2:        ds CH_SIZE
sseed:      dw 0
hitstop:    db 0
mono:       db 0             ; 1: scenery drawn for a monochrome monitor
m_was:      db 0
on_title:   db 0
watch:      db 0
mx_n:       db 0
sig_now:    ds 5
sig0:       ds 5
sig1:       ds 5
spk:        db 0
hudbuf:     ds 41
; scrolling
cur_blk:    db 0
stg_blk:    db 0
cam_c:      db 0            ; the midground's first column on screen
cam_sub:    db 0            ; pixels into that column (0..7)
far_c:      db 0            ; the far layer's first column (cam_c / 4)
base_c:     db 0            ; the camera BASE was built for
pg_mid:     ds 2            ; per page: the camera its midground shows
pg_far:     ds 2            ; per page: the far column it shows
fl_ph:      db 0            ; the floor's phase now (0..47)
fl_ask:     db 0            ; the phase the page waiting to be shown wants
fl_shown:   db 0            ; the phase the floor glyphs have
fs_rowp:    dw 0
fs_php:     dw 0
fs_r:       db 0
fs_k:       db 0
fs_q:       db 0
fs_g:       dw 0
fs_tab:     dw 0
fs_end:     dw 0
fs_bank:    db 0
pr_src:     dw 0
pr_w:       dw 0
pr_plane:   dw 0
pr_row:     db 0
duel_c:     db 0
end_c:      db 0
foe_in:     db 0            ; the opponent is on the road
run_t:      db 0
run_lim:    db 0
msg_on:     db 0
r_mid:      db 0
r_rows:     db 0
r_skip:     dw 0
mid_pend:   db 0            ; MIDBUF waits to go to (blit_pg) at a blanking
far_pend:   db 0            ; FARBUF likewise
blit_pg:    db 0
bp_str:     dw 0
b3_n:       db 0
b3_v:       dw 0
b3_s:       dw 0
b3_str:     dw 0
vars_end:
