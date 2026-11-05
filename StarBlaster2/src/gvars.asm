; game variables (kept small: big tables live in high RAM, see equates)
vaz:    dw 0                    ; view azimuth (8.8, 256 units = 360 deg)
vel:    dw 0                    ; view pitch (8.8 rows)
vvaz:   dw 0                    ; scan speed
vvel:   dw 0
dvaz:   dw 0                    ; view change this tick (for stars)
dvel:   dw 0
energy: dw 0
drainc: db 0
score:  ds 3
sector: db 0                    ; 0..7
lap:    db 0
quota:  ds 5                    ; FRT TRP TNK FHT ACE still to destroy
gstate: db 0                    ; 0 play, 1 warp-in, 2 clear, 3 dying, 4 warp-out
gtimer: dw 0
tick:   dw 0
bolt_t: ds 2                    ; laser bolt progress (0 = idle)
firecd: db 0
novas:  db 0
chain:  db 0
chaint: db 0
crackt: db 0
shaket: db 0
flasht: db 0
hudflag: db 0                   ; bit0 tallies, bit1 energy, bit2 score, bit3 nova
spawnt: db 0
secflags: db 0                  ; bit0 rocks 1 mines 2 planet 3 cloak 4 boss
demo:   db 0
paused: db 0
lastkill: db 0
bossdead: db 0
turhp:  ds 4
corehp: db 0
bosst:  db 0
landed: db 0
sortn:  db 0
sortl:  ds 20
popt:   ds 4*5                  ; popups: col,row,timer,ptr
banner1: dw 0
banner2: dw 0
bannert: db 0
warpk:  db 0
tgtz:   db 0
aitimer: db 0
dt_cnt: db 0
endflag: db 0
ehold:  dw 0
eadd:   dw 0
dlast:  dw 0
hiflag: db 0
nameb:  ds 4
attr_t: dw 0
st_dx:  dw 0
bt_t:   db 0
bt_dx:  db 0
bt_dy:  db 0
bu_n:   db 0
bu_x:   db 0
bu_y:   db 0
fe_t:   dw 0
fe_msg: db 0
let_t:  db 0
title_ph: db 0
fy_z:   dw 0
fy_x:   db 0
fy_st:  db 0
hi_pos: db 0
hi_cur: db 0
lettpos: ds 2*16
letp:   dw 0
sdvaz:  dw 0
sdvel:  dw 0
lag:    db 0
sg_a:   db 0
sg_c:   db 0
sg_d:   db 0
