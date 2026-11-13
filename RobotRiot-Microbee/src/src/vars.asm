; =====================================================================
;  variables (zeroed at start-up) in the upper block below the stack
; =====================================================================
vars_start:
actors:  ds NACT*ASZ            ; (actors, shots and blades are cleared together)
shots:   ds NSHOT*SSZ
blades:  ds NBLADE*BSZ
; ---- core
curblk:  db 0
vblast:  db 0
vcount:  db 0
fw_need: db 0
framecount: dw 0
seed:    dw 0
; ---- input
rk:      ds 3
pad:     db 0
padnew:  db 0
firepad: db 0
keys:    db 0
keysnew: db 0
t_keys:  db 0
t_padnew: db 0
; ---- render
rpage:   db 0
pgbase:  dw 0
dlp:     dw 0
dlbase:  dw 0
dln:     db 0
dln0:    db 0
dln1:    db 0
ds_bk:   db 0
ds_col2: db 0
sp_save: dw 0
; ---- sound
acc1:    dw 0
acc2:    dw 0
step1:   dw 0
step2:   dw 0
noiseon: db 0
musicon: db 0
sfxon:   db 0
soundmode: db 0
want0:   dw 0
want1:   dw 0
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
; ---- attract
att:     db 0
fxt:     dw 0
demo:    db 0
demo_t:  dw 0
firewait: db 0
typ_p:   dw 0
typ_o:   dw 0
typ_l:   dw 0
ent_pos: db 0
ent_last: db 0
ent_ch:  db 0
ent_fp:  db 0
ai_fire: db 0
ai_move: db 0
ai_last: db 0
; ---- the game
wave:    db 0
state:   db 0
stimer:  db 0
gtick:   db 0
paused:  db 0
hud_dirty: db 0
hud_all: db 0
enemies_left: db 0
rescued: db 0
respawned: db 0
score:   ds 3               ; BCD, high byte first
hs_tab:  ds 8*6              ; the hall of legends: score (BCD), initials
hiscore equ hs_tab
hs_new:  db 0
nextlife: ds 2
lives:   db 0
w_heel:  db 0               ; the wave's row of wavetab (8 bytes, in order)
w_shear: db 0
w_harv:  db 0
w_mag:   db 0
w_pyl:   db 0
w_hum:   db 0
heel_per: db 0
shear_gap: db 0
heel_min: db 0
blade_spd: db 0
speed_t: dw 0
pyl_ptr: dw 0
; Jo
px:      db 0
py:      db 0
pface:   db 0               ; 0 R 1 L 2 U 3 D
panim:   db 0
pinv:    db 0               ; safe (flickering) frames left
pcells:  db 0
firecd:  db 0
mvdx:    db 0
mvdy:    db 0
lastdx:  db 0
lastdy:  db 0
lockon:  db 0
lockdx:  db 0
lockdy:  db 0
; scratch
t_dx:    db 0
t_dy:    db 0
t_sx:    db 0
t_sy:    db 0
t_best:  db 0
t_tx:    db 0
t_ty:    db 0
t_n:     db 0
t_k:     db 0
t_rel:   db 0
t_k2:    db 0
t_c0:    db 0
t_c1:    db 0
t_r0:    db 0
t_r1:    db 0
nodraw:  db 0
node_shape: db 0
msgbuf:  ds 24
vars_end:
