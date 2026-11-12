; =====================================================================
;  VARIABLES (E400h up). Cleared at start-up.
; =====================================================================
vars_start:
; ---- core
steps:      db 0
curblk:     db 0
cb_src:     db 0
cb_dst:     db 0
vblast:     db 0
vcount:     db 0
fw_need:    db 0
noiseon:    db 0
acc1:       dw 0
acc2:       dw 0
step1:      dw 0
step2:      dw 0
framecount: dw 0
seed:       dw 0
crtc_vpos:  db 0
shake_off:  db 0
monomode:   db 0
; ---- render
rpage:      db 0
dpage:      db 0
vpg:        db 0
cpg:        db 0
poolport:   db 0
poolcnt:    db 0
dlcnt:      db 0
rl_cur:     dw 0
bl_cur:     dw 0
rlcnt:      db 0,0
blcnt:      db 0,0
rs_ptr:     dw 0
rs_n:       db 0
rs_blk:     db 0
rs_sp:      dw 0
rs_full:    db 0
rs_c:       db 0
nstrip:     db 0
st_blk:     db 0
st_pg:      db 0
scr_p:      db 0
scr_m:      dw 0
far_p:      db 0
far_m:      dw 0
spr_x:      dw 0
spr_y:      dw 0
spr_ink:    db 0
sd_cn:      db 0
sd_top:     dw 0
sd_col:     dw 0
sd_src:     dw 0
sd_cx:      db 0
cb_s:       dw 0
cb_n:       db 0
cb_y:       dw 0
cb_left:    db 0
cb_r:       db 0
cb_cell:    dw 0
sb_sp:      dw 0
pn_k:       db 0
gp_g:       dw 0
gp_d:       db 0
gp_code:    db 0
gp_bank:    db 0
od_c:       dw 0
od_r:       dw 0
cm_cnt:     dw 0
fb_blk:     db 0
pb_bank:    db 0
txt_col:    db 0
fc_glyph:   dw 0
; ---- input
rk_pad:     db 0,0
pad:        db 0
padnew:     db 0
keys:       db 0
keysnew:    db 0
qaop:       db 0
; ---- sound
musicon:    db 0
sfxon:      db 0
mptr0:      dw 0
mbase0:     dw 0
mleft0:     db 0
mstep0:     dw 0
mfin0:      db 0
mptr1:      dw 0
mbase1:     dw 0
mleft1:     db 0
mstep1:     dw 0
mfin1:      db 0
mplaying:   db 0
sfxleft:    db 0
sfxprio:    db 0
sfxstep:    dw 0
sfxdelta:   dw 0
sfxmode:    db 0
sfxpend:    db 0
; ---- the stage
stage:      db 0            ; 1..5
stg_a:      db 0            ; its blocks
stg_b:      db 0
stg_hdr:    ds 64           ; the stage header
strip_tab:  ds 3*12*12      ; [plane][row][phase] port, address
row_dst:    ds 12*3         ; dw (row+1)*40, db far
scrollx:    dw 0            ; pixels
scroll_end: dw 0            ; pixels: the scroll stops here
scrolling:  db 0            ; 2 px a frame when 1
wave_ptr:   dw 0
boss_pal:   ds 16
; ---- the game
gstate:     db 0
pilot:      db 0            ; 0 HONK 1 TRUFFLE 2 BOLT 3 QUEENIE 4 POLLY
difficulty: db 0            ; 0 easy 1 normal 2 hard
score:      ds 4            ; BCD, 8 digits (high byte first)
hiscore:    ds 4
lives:      db 0
hearts:     db 0
maxhearts:  db 0
next_life:  db 0            ; BCD ten-thousands for the next extra life
ticks:      db 0
; the pilot (y values are biased: 32 + playfield y)
px:         dw 0
pxf:        db 0
py:         db 0
pyf:        db 0
pinv:       db 0            ; invulnerable frames
pdead:      db 0            ; >0: exploding / respawning
ptilt:      db 0
pfire:      db 0            ; autofire cooldown
pshield:    db 0            ; hits left
pspeed:     db 0            ; 0..4
pmissile:   db 0
pdouble:    db 0            ; 1 = DOUBLE
plaser:     db 0            ; 1 = LASER
poptions:   db 0            ; 0..2
barpos:     db 0            ; 0 none, 1..7 the lit slot
bellpow:    db 0            ; active bell power (0 none, 2 blue .. 5 white)
belltime:   db 0            ; its frames left (/2)
goldrun:    db 0            ; gold bells in a row
mfire:      db 0            ; missile cooldown
trail:      ds 64           ; the pilot's last 32 positions (x/2, y)
trailpos:   db 0
optx:       ds 4
opty:       ds 4
hud_dirty:  db 0
sc_tab:     ds 16           ; live shots per owner (0-2) and class (1-3)
; objects
NSHOT       equ 20
SH_SIZE     equ 12
shots:      ds NSHOT*SH_SIZE
NENEMY      equ 18
EN_SIZE     equ 20
enemies:    ds NENEMY*EN_SIZE
NBUL        equ 20
BU_SIZE     equ 9
bullets:    ds NBUL*BU_SIZE
NFX         equ 12
FX_SIZE     equ 5
effects:    ds NFX*FX_SIZE
NCAP        equ 6
CA_SIZE     equ 5
capsules:   ds NCAP*CA_SIZE
NBELL       equ 3
BE_SIZE     equ 12
bells:      ds NBELL*BE_SIZE
; the boss
boss_on:    db 0
boss_x:     dw 0            ; screen pixels
boss_y:     db 0            ; biased y
boss_var:   db 0
boss_hp:    dw 0
boss_hpmax: dw 0
boss_st:    db 0
boss_t:     dw 0
boss_flash: db 0
boss_jam:   db 0
boss_n:     db 0
warn_msg:   db 0
boss_hdr:   ds 4
boss_data:  ds 4*4*4        ; [variant][shift]: dw bitmap, dw colmap
bd_nc:      db 0
bd_nr:      db 0
bd_h:       db 0
bd_ptr:     dw 0
bd_cm:      dw 0
bd_dy:      db 0
bd_c:       db 0
bd_r:       db 0
bd_cell:    dw 0
bd_k:       db 0
bd_cnt:     db 0
; scratch
tmp:        ds 8
; the saved things (SAVE.DAT): the hall of fame, unlocks, settings
sv_first:
hof:        ds 8*7          ; 8 x (4 bytes BCD score, 3 letters)
unlocked:   db 0            ; b0 POLLY, b1 the game has been cleared
automode:   db 0            ; 1: upgrades are taken automatically
sv_diff:    db 0
sv_end:
vars_end:
