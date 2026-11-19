frames:         db 0
nextframe:      db 0
colpat:         ds 4
seed:           dw 0
nseed:          dw 0
; sound
snd_on:         db 0
v0per:          db 0
v1per:          db 0
mus_on:         db 0
mus_ch0:        ds 8
mus_ch1:        ds 8
sfx_ptr:        dw 0
; options
difficulty:     db 0
; input
inp:            db 0
inp_prev:       db 0
inp_new:        db 0
demo:           db 0
demo_timer:     dw 0
; game
GAMEVARS:
score:          ds 3
lives:          db 0
act:            db 0
encore:         db 0
nextlife:       db 0
actflags:       db 0
nrows:          db 0
balloons_left:  db 0
balloons_total: db 0
misses_act:     db 0
combo:          db 0
streak:         db 0
best_streak:    db 0
see_x:          dw 0            ; 8.8 pivot x
see_v:          dw 0
see_hw:         db 0
tilt:           db 0            ; 0 = left end low, 1 = right end low
flipcool:       db 0
flipanim:       db 0
piestick:       db 0
pw_wide:        db 0
pw_slow:        db 0
pw_x2:          db 0
pw_umb:         db 0
pw_net:         db 0
tickpar:        db 0
endtimer:       db 0
gameresult:     db 0
substeps:       db 0
bonus_time:     dw 0
bonus_pops:     db 0
spawn_t:        db 0
rowphase:       db 0
ai_target:      db 0
ai_t:           db 0
respawn_side:   db 0
clown0:         ds 16
clown1:         ds 16
rows:           ds 4*8
rowtype:        ds 4*16
rowspr:         ds 4
rowy:           ds 4            ; current y incl. bob
parts:          ds 16*12
popups:         ds 5*14
tokens:         ds 3*8
freeb:          ds 12*8
monkey:         ds 8
pies:           ds 3*8
hoop:           ds 4
hud_req:        db 0
prev_cy:        db 0
rowleft:        db 0
mult:           db 0
nomiss:         db 0
fw_n:           db 0
fw_try:         db 0
pb_col:         db 0
pb_style:       db 0
ai_x:           dw 0
ai_y:           dw 0
ai_vx:          dw 0
cel_t:          db 0
GAMEVARS_END:
vars_end:


vars2_start:
tmpx:           db 0
tmpy:           db 0
strbuf:         ds 34
ss_spr:         dw 0
demo_act:       db 0
demo_key:       db 0
hs_ptr:         dw 0
hs_pos:         db 0
hiscores:       ds 5*6
vars2_end:
