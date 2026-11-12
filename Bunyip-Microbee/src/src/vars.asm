; ==========================================================================
; vars.asm - variables and buffers (upper RAM, after the code)
;   VIBED BY BPM 2026
; ==========================================================================

; ---- test builds (poked by the emulator scripts)
dbg_on: db 0
dbg_zone: db 0
dbg_x:  db 0
dbg_y:  db 0
dbg_a:  dw 0
dbg_frz: db 0                   ; test builds: creatures stand still

; ---- the player
px:     db 0,80h,7              ; x: 1/65536, 1/256, cell
py:     db 0,80h,5
pa:     dw 0                    ; facing, 0..2047 (0 = east, clockwise)
nx:     ds 3
nstep:  db 1
mvneg:  db 0
walking: db 0
bobt:   db 0
health: db 100
charges: db 30
keys:   db 0
score:  dw 0
pwrt:   dw 0                    ; double zaps left, fields
hurtt:  db 0
bumpcd: db 0
firecd: db 0
fdmg:   db 0
fwall:  db 0
fbest:  db 0
fbz:    db 0
icell:  dw 0
lmask:  db 0

; ---- the zone
zone:   db 0
zdone:  db 0
bossdead: db 0
bosshp0: db 20
bossbar: db 0
kills:  db 0
ncreat: db 0
opals:  db 0
nopals: db 0
secrets: db 0
losn:   db 0
act_i:  db 0
crn:    db 0                    ; creatures in CRL
cri:    db 0
spn:    db 0
CRL:    ds NENT                 ; their slots, for the sight checks

; ---- creatures
pdx:    dw 0
pdy:    dw 0
adx:    dw 0
ady:    dw 0
dist:   dw 0
spd:    db 0
shtype: db 0
shn:    db 0
shk:    db 0
shm:    dw 0
svx:    db 0
svy:    db 0
lsx:    dw 0
lsy:    dw 0
lx:     dw 0
ly:     dw 0

; ---- display
mono:   db 0
cpaper: db 0
fpaper: db 0
floorc: db CBROWN
clsink: db 0
lastf:  db 1
flast:  dw 0
page:   db 1
colx:   dw 0
cnt:    db 0
n_tmin: db 0
o_tmin: db 0
d_col:  db 0
d_pat:  db 0
cur_e:  db 0
cur_sk: db 0
cur_key: db 0
nxt_e:  db 0
nxt_sk: db 0
nxt_key: db 0
rp:     dw 0
lfxp:   dw 0
lfxn:   dw 0
lfyp:   dw 0
lfyn:   dw 0
rz:     db 0
cur_z:  db 0
nxt_z:  db 0

; ---- HUD and sound
hud_dirty: db 1
msgid:  db 0
msgt:   db 0
keyst:  ds NKEYS
keyold: ds NKEYS
NUMBUF: ds 8
spk:    db 0
sndfx:  db 0
sndper: db 0
sndcnt: db 0
snddp:  db 0
sndnz:  db 0
sndlen: db 0
sndsw:  db 0
sw_f0:  dw 0
seed:   dw 1234h

; ---- sprites
show_gun: db 0
gun_fire: db 0
gun_bob: db 0
gun_ink: db CGREY
nvis:   db 0
cur_ent: db 0
pz:     dw 0
pxr:    dw 0
pyb:    db 0
cmag:   db 0
smag:   db 0
csgn:   db 0
ssgn:   db 0
msv_m:  db 0
msv_lo: db 0
nslot:  db 0
poolbk: db 13
pool15: db 0
dshift: db 0
dc0:    db 0
dbw:    db 0
dbase:  dw 0
dcs:    db 0
dblk:   db 0
dyt:    dw 0
dy0:    dw 0
dy1:    dw 0
dr0:    db 0
dr1:    db 0
dr:     db 0
dk:     db 0
dcx:    db 0
dvis:   db 0
caddr:  dw 0
rl_ptr: dw 0
rl_head: dw 0
drow0:  dw 0
cslot:  db 0
VORD:   ds NVIS
DCOPY:  ds 8                    ; draw_one's copy of a sprite directory entry
IMGH0:  ds NIMAGES

; ---- start-up scaler
ps_img: db 0
ps_cnt: db 0
litn:   dw 0
ps_moff: dw 0
ps_nb:  db 0
ps_h0:  db 0
ps_xoff: dw 0
ps_cs:  db 0
ps_csz: dw 0
ps_cur: dw 0
ps_xp:  dw 0
ps_s:   db 0
ps_r:   db 0
ps_j:   db 0
ps_t:   db 0
ps_pm:  db 0
ps_pd:  db 0
PSDIR:  ds 8
PSBUILT: ds NIMAGES             ; 1 once an image has been made

; ---- page-aligned tables
        align 256
VIS:    ds 256                  ; NVIS x VSIZE
ZB:     ds 256                  ; wall depth per half column (80 used)
ROWMAP: ds 256                  ; scanline -> 2 * source row
WTAB:   ds 768                  ; image * 16 + size -> width in dots (48 images)
PIX:    ds 256                  ; scaler: one master row as pixels
POPC:   ds 256                  ; bits set in each byte
ROW40:  ds 256                  ; screen row -> VRAM address (word)
C10:    ds 512                  ; code * 10: low bytes, then high bytes
LITC:   ds 2048                 ; lit pixels of each glyph of banks 0-12 (0-15)
STATE:  ds 1024                 ; per-column state, 2 pages x 512
SHADOW: ds POOLN*16             ; private sprite glyphs (also scratch)
RLIST0: ds 1+POOLN*5            ; count, then 5 bytes per cell
RLIST1: ds 1+POOLN*5
ENT:    ds NENT*ESIZE
ZH:     ds ZHN                  ; the zone header (name, start, levers, ...)
        align 32
TMPM:   ds 32                   ; a cell's sprite lines: NOT mask, then data at +16
TMPD    equ TMPM+16
MBUF    equ SHADOW              ; scaler scratch (start-up only)
XBUF    equ SHADOW+1024
XBUFN   equ 2048
VARS_END:
        assert VARS_END <= 0EF00h
