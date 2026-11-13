; =====================================================================
;  VARIABLES (EC00h-EEFFh, cleared at start-up)
; =====================================================================
        ORG VARS
; engine
save_sp:    DS 2
page:       DS 1
nslots:     DS 1
lcount:     DS 1
lnew:       DS 1
lback:      DS 1
lfront:     DS 1
vdelta:     DS 2
dcol:       DS 1
vlast:      DS 1
vb_age:     DS 1
fields:     DS 1
frameno:    DS 2
commit_late:DS 1
flashcnt:   DS 1
flashcol:   DS 1
flashpaper: DS 1
tq_mark:    DS 1            ; 80h while the HUD queues its text
tqcur:      DS 1
tqprev:     DS 1
tq_page:    DS 1
tq_pool:    DS 1
tq_cell:    DS 2
tq_code:    DS 1
star_code:  DS 1
rseed:      DS 2
pl_bank:    DS 1
shape:      DS 1
tm_tick:    DS 1
tm_where:   DS 1
tm_prow:    DS 2
tm_col:     DS 1
tm_pcol:    DS 1
tm_phase:   DS 1
tm_held:    DS 1
tm_fire:    DS 1
tstars:     DS 2*28
mus_pos:    DS 2            ; SWIRL: where the title music is
mus_left:   DS 1
mdrum:      DS 1
acc_a:      DS 2
acc_b:      DS 2
acc_bass:   DS 2
acc_arp:    DS 2
mono:       DS 1
colmap:     DS 16
rowcell:    DS 50
d_neg:      DS 1
d_col0:     DS 1
d_ncol:     DS 1
d_h:        DS 1
d_data:     DS 2
d_skip:     DS 1
d_vis:      DS 1
d_sub:      DS 1
d_row:      DS 2
lp_addr:    DS 2
lp_code:    DS 2
lp_cell:    DS 2
nextbuf:    DS 2
nextcode:   DS 1
alloc_hl:   DS 2
; sound
spk:        DS 1
v1per:      DS 1
v2per:      DS 1
nz_on:      DS 1
sfx_on:     DS 1
sfx_pri:    DS 1
sfx_ptr:    DS 2
sfx_left:   DS 1
sfx_cur:    DS 1
mus_hdr:    DS 2
sa_m:       DS 2            ; the in-game voices' phase counters
sa_m2:      DS 2
sa_b:       DS 2
sa_f:       DS 2
lfsr:       DS 1
sndmode:    DS 1
snd_save:   DS 1
mus_on:     DS 1
mus_gate:   DS 1
mus_p1:     DS 2            ; channel: pointer, base, left, note, gate
mus_b1:     DS 2
mus_l1:     DS 1
mus_n1:     DS 1
mus_g1:     DS 1
            DS 1
mus_a1:     DS 1            ; age (ix+7)
mus_p2:     DS 2
mus_b2:     DS 2
mus_l2:     DS 1
mus_n2:     DS 1
mus_g2:     DS 1
            DS 1
mus_a2:     DS 1
; input
rk_pad:     DS 1
rk_keys:    DS 1
pad:        DS 1
padnew:     DS 1
keys:       DS 1
keysnew:    DS 1
ipad:       DS 1
ipadnew:    DS 1
; score
score:      DS 3
next_life:  DS 3
hiscore:    DS 3
lives:      DS 1
hud_dirty:  DS 1
demo:       DS 1
demo_quiet: DS 1
demo_quit:  DS 1
demo_tim:   DS 2
; the wave (header in this order: see data.asm)
w_atk1:     DS 1
w_atk2:     DS 1
w_aint:     DS 1
w_amax:     DS 1
w_fire:     DS 1
w_bspd:     DS 1
w_ffire:    DS 1
w_spin0:    DS 1
w_spin1:    DS 1
w_home:     DS 1
w_ng:       DS 1
w_ptr:      DS 2
w_esc:      DS 2
wave_on:    DS 1
nenemy:     DS 1
attackers:  DS 1
att_tim:    DS 1
ring_grp:   DS 2
sp_n:       DS 1
sp_gap:     DS 1
sp_tim:     DS 1
sp_i:       DS 1
sp_ring:    DS 1
sp_grp:     DS 1
sp_type:    DS 1            ; the group record, in this order
sp_entry:   DS 1
sp_ang:     DS 1
sp_flag:    DS 1
sp_col:     DS 1
sp_hp:      DS 1
sp_cnt:     DS 1
grp_next:   DS 1
grp_n:      DS 6
grp_tot:    DS 6
grp_kill:   DS 6
grp_bonus:  DS 1
kills:      DS 1
bonus_hits: DS 1
bonus_shots:DS 1
form_a0:    DS 2
form_a1:    DS 2
spin0:      DS 2
spin1:      DS 2
breath:     DS 1
tmp1:       DS 1
tmp2:       DS 2
; the run
sector:     DS 1
lap:        DS 1
twin:       DS 1
wave:       DS 1
phase:      DS 1
ph_tim:     DS 1
sec_ptr:    DS 2
star_far:   DS 1
hudcol:     DS 1
warp:       DS 1
nodmg:      DS 1
bossmode:   DS 1
boss_id:    DS 1
msg_len:    DS 3
msg_ptr:    DS 6            ; each message row's text and colour, to
msg_col:    DS 3            ;  show again after a flash
txtbuf:     DS 44
; the player
p_af:       DS 1
p_a:        DS 1
p_v:        DS 2
p_state:    DS 1
p_tim:      DS 1
p_inv:      DS 1
p_shield:   DS 1
p_fcd:      DS 1
p_hitfl:    DS 1
p_x:        DS 2
p_y:        DS 1
stars:      DS 5*24
; the Guardian
boss_ptr:   DS 2
core_hp:    DS 1
core_max:   DS 1
ring_spin:  DS 2
ring_a:     DS 2
boss_alive: DS 1
eye:        DS 1
eye_tim:    DS 1
core_hurt:  DS 1
core_shown: DS 1
spiral_n:   DS 1
spiral_a:   DS 1
atk_i:      DS 1
batk_tim:   DS 1
flip_tim:   DS 1
pods:       DS 8*8
; the front end
att_step:   DS 1
paused:     DS 1
cap_len:    DS 1
cap_ptr:    DS 2
ai_t:       DS 1
ent_ptr:    DS 2
ent_i:      DS 1
ent_dirty:  DS 1
last_typed: DS 1
scr_tim:    DS 2
vars_end:
        ASSERT vars_end <= STACK - $100
