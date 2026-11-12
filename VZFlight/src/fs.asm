; =====================================================================
;  VZ FLIGHT SIMULATOR  v0.2      VIBED BY BPM 2026
;  An unofficial tribute to Dick Smith, aviator
;  Wireframe flight sim for the VZ300, mode(1) 128x64, loads at $8000
; =====================================================================
vram      equ $7000
latch     equ $6800
pitchrate equ 16384
rollrate  equ 32000
pmax      equ 9100
rmax      equ 12700
gpmax     equ 2200
vstall    equ 24
vr        equ 28

        org $8000
start:  di
        ld sp,stacktop
        ld hl,bssstart
        ld de,bssstart+1
        ld bc,bssend-bssstart-1
        ld (hl),0
        ldir
        ld hl,im2tab
        ld de,im2tab+1
        ld bc,256
        ld (hl),im2v
        ldir
        ld a,$c3
        ld (isrstub),a
        ld hl,isr
        ld (isrstub+1),hl
        ld a,high(im2tab)
        ld i,a
        im 2
        ld a,$08
        ld (latchv),a
        ld (latch),a
        ld hl,pchar
        ld (chout+1),hl
        jp attract

        include "flight.asm"
        include "front.asm"
        include "engine.asm"
        include "gen_code.asm"
        include "gen_data.asm"

; ---------------------------------------------------------------- variables (not in file)
        align 256
bssstart:
buf:    ds 1536
vtab:   ds 400
wpa:    ds 10
wpb:    ds 10
wpm:    ds 10
wpi:    ds 10
wpo:    ds 10
wps:    ds 10
latchv: ds 1
fcount: ds 1
flast:  ds 1
nf:     ds 1
engdly: ds 1
ctrl:   ds 1
ctrl2:  ds 1
ctrl2e: ds 1
kold:   ds 1
ftick:  ds 2
sny:    ds 2
csy:    ds 2
snp:    ds 2
csp:    ds 2
snr:    ds 2
csr:    ds 2
cyaw:   ds 2
cpitch: ds 2
croll:  ds 2
ta:     ds 2
tb:     ds 2
q00:    ds 2
q01:    ds 2
q02:    ds 2
q10:    ds 2
q11:    ds 2
q12:    ds 2
q20:    ds 2
q21:    ds 2
q22:    ds 2
m00:    ds 2
m01:    ds 2
m02:    ds 2
m10:    ds 2
m11:    ds 2
m12:    ds 2
m20:    ds 2
m21:    ds 2
m22:    ds 2
cxi:    ds 2
cyi:    ds 2
czi:    ds 2
cx16:   ds 2
cy16:   ds 2
cz16:   ds 2
dx:     ds 2
dy:     ds 2
dz:     ds 2
o0:     ds 2
o1:     ds 2
o2:     ds 2
acc0:   ds 2
acc1:   ds 2
acc2:   ds 2
kx:     ds 1
ky:     ds 1
kz:     ds 1
ksgn:   ds 1
vshift: ds 1
nearh:  ds 2
nv:     ds 1
ne:     ds 1
cullz:  ds 2
adx:    ds 1
adz:    ds 1
zn:     ds 1
zsh:    ds 1
psgn:   ds 1
msgn:   ds 1
lx0:    ds 1
ly0:    ds 1
lx1:    ds 1
ly1:    ds 1
ldx:    ds 1
ldy:    ds 1
linecol: ds 1
bux:    ds 2
buy:    ds 2
buz:    ds 2
aux:    ds 2
auy:    ds 2
auz:    ds 2
slope:  ds 2
bgx:    ds 4
bginc:  ds 4
bgrow:  ds 2
lcol:   ds 1
rcol:   ds 1
bgoth:  ds 1
ga0:    ds 2
ga1:    ds 2
ga2:    ds 2
gb0:    ds 2
gb1:    ds 2
gb2:    ds 2
ga40:   ds 2
ga41:   ds 2
ga42:   ds 2
gb40:   ds 2
gb41:   ds 2
gb42:   ds 2
gs0:    ds 2
gs1:    ds 2
gs2:    ds 2
msgptr: ds 2
msgtim: ds 1
lnstart: ds 2
skycol: ds 1
gndcol: ds 1
gridcol: ds 1
ovink:  ds 1
objp:   ds 2
obst:   ds 2
plats:  ds 2
shipobj: ds 2
water:  ds 1
shipz24: ds 3
shipz:  ds 2
shipx:  ds 2
heli:   ds 1
demo:   ds 1
demoend: ds 2
quitf:  ds 1
view:   ds 1
mapz:   ds 1
goalp:  ds 2
goalcnt: ds 1
goalidx: ds 1
goalobj: ds 10
tgx:    ds 2
tgz:    ds 2
tgalt:  ds 2
tdx:    ds 2
tdz:    ds 2
tdx2:   ds 2
tdz2:   ds 2
relx:   ds 2
relz:   ds 2
gdm:    ds 2
gdist:  ds 2
turnlv: ds 1
arrowp: ds 2
wpp:    ds 2
apon:   ds 1
aprol:  ds 2
appit:  ds 2
msec:   ds 2
mfld:   ds 1
mdone:  ds 1
crashes: ds 1
fuel:   ds 2
fuelmax: ds 2
ckfuel: ds 2
nofuel: ds 1
gh:     ds 2
onplat: ds 1
onship: ds 1
vtgt:   ds 2
tmpb:   ds 1
tmpw:   ds 2
musptr: ds 2
musloop: ds 2
mustim: ds 1
musblip: ds 1
musn:   ds 1
musc:   ds 1
bordon: ds 1
tickv:  ds 2
pgend:  ds 2
pgsec:  ds 1
atptr:  ds 2
tang:   ds 2
curloc: ds 2
curmis: ds 2
locidx: ds 1
misidx: ds 1
rowp:   ds 2
score:  ds 2
rank:   ds 1
newbest: ds 1
bestt:  ds 64
bestr:  ds 32
fltvars:
px:     ds 4
py:     ds 4
pz:     ds 4
spd:    ds 4
yaw3:   ds 3
pitch3: ds 3
roll3:  ds 3
thr:    ds 1
ongnd:  ds 1
stall:  ds 1
crash:  ds 1
airtime: ds 1
spdi:   ds 1
ysgn:   ds 1
vs88:   ds 2
vh88:   ds 2
vx88:   ds 2
vz88:   ds 2
prate:  ds 2
rrate:  ds 2
fltend:
ckbuf:  ds fltend-fltvars
bssend:
im2tab   equ (bssend+255) & $ff00
im2v     equ high(im2tab)+1
isrstub  equ im2v*257
stacktop equ (isrstub & $ff00) + $200
