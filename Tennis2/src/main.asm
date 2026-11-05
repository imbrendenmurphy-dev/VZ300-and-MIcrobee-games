; =====================================================================
;  TENNIS II - GRAND SLAM
;  for the Dick Smith VZ300 / VZ200 (Mode 1, 128x64, 4 colours)
;  with the BennVenn SD loader + 128K RAM expansion (RAM to $FFFF).
;  Sequel to the VZ200/VZ300 game TENNIS.
;  ViBED by BPM 2026.  Assemble: sjasmplus main.asm  (or tools/zasm.py)
; =====================================================================
        DEVICE NOSLOT64K
VRAM    equ $7000
BGBUF   equ $F800
STACKTOP equ $7FFE
MODE1   equ $08
CSS1    equ $10
qbuf    equ $7C00               ; 128-byte commit ring (page aligned)
RMAP    equ $7D00               ; 256-byte recolour table
SAVEADR equ $67C0               ; records, in BennVenn SRAM bank 3

        org $8000
start:
        di
        ld sp,STACKTOP
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld hl,qbuf
        ld de,qbuf+1
        ld bc,255
        ld (hl),0
        ldir
        ld a,MODE1
        ld (latchbase),a
        ld (latchcur),a
        ld (palbase),a
        ld ($6800),a
        xor a
        call cls_vram           ; start-up only
        xor a
        call cls_bg
        ld a,r
        ld l,a
        ld h,$5A
        ld (seed),hl
        ld a,2
        ld (soundmode),a
        ld a,28
        ld (cbudget),a
        ld a,4
        ld (gamesper),a
        ld hl,vb_none
        ld (vbhook),hl
        ld hl,hitab_init
        ld de,hitab
        ld bc,30
        ldir
        call load_records
        jp attract

hitab_init:
        db $03,$00,$00,"BPM"
        db $02,$00,$00,"VZ3"
        db $01,$00,$00,"ACE"
        db $00,$50,$00,"LOB"
        db $00,$25,$00,"NET"

vb_none:
        ret
special_vblank:
        ld hl,(vbhook)
        jp (hl)

; ---------------------------------------------------------------------
; do_frame: palette, sound, wait for vblank, render, input
; ---------------------------------------------------------------------
do_frame:
        ld a,(palbase)
        ld b,a
        ld a,(flashtim)
        or a
        jr z,.nf
        dec a
        ld (flashtim),a
        bit 1,a
        jr z,.nf
        ld a,b
        xor CSS1
        ld b,a
.nf:    ld a,b
        or MODE1
        ld (latchbase),a
        call sound_tick
        call frame_wait
        call render
        jp read_input

; reveal the whole BG buffer in "blinds" order (8 rows per frame)
wipe_show:
        call dl_reset
        call clear_erase
        xor a
        ld (q_head),a
        ld (q_tail),a
        ld a,120
        ld (cbudget),a
        ld c,0
.p:     push bc
        ld e,c
.r:     push de
        ld d,0
        ld bc,$2001
        call queue_rect
        pop de
        ld a,e
        add a,8
        ld e,a
        cp 64
        jr c,.r
        call do_frame
        pop bc
        inc c
        ld a,c
        cp 8
        jr nz,.p
        call flush_queue
        ld a,28
        ld (cbudget),a
        ret

clear_erase:
        xor a
        ld (eraselist),a
        ld (eraselist+1),a
        ret

; Z if IX is under computer control (the test hook 'autoplay' lets the
; computer drive the human players too, for soak tests in the emulator)
ctl_cpu:
        ld a,(ix+P_CTL)
        cp CTL_NONE
        jr z,.no
        or a
        ret z
        ld a,(autoplay)
        or a
        jr z,.no
        xor a
        ret
.no:    or 1
        ret

; =====================================================================
        include "core.asm"
        include "math.asm"
        include "sound.asm"
        include "court.asm"
        include "match.asm"
        include "front.asm"
        include "data.inc"

code_end:
        savebin "tennis2.bin",start,code_end-start
shtab   equ code_end
SPRWORK equ shtab+NSPR*8
        assert SPRWORK+SHIFTSIZE <= BGBUF, "out of memory for sprites"
        display "code+data end: ",/A,code_end, "  sprites end: ",/A,SPRWORK+SHIFTSIZE

; =====================================================================
;  variables (zeroed at start) at $7800
; =====================================================================
        org $7800
vars_start:
latchbase: db 0
latchcur: db 0
palbase: db 0
flashtim: db 0
framecount: dw 0
seed:   dw 0
acc1:   dw 0
acc2:   dw 0
step1:  dw 0
step2:  dw 0
soundmode: db 0
inp:    db 0
inpnew: db 0
keys:   db 0
keysnew: db 0
pad1:   db 0
pad2:   db 0
pad1new: db 0
pad2new: db 0
joyseen: db 0
ink_fg: db 0
ink_bg: db 0
inktab: ds 8
textdirect: db 0
popcol: db 0
popbg:  db 0
cbudget: db 0
budget_: db 0
cfirst: db 0
q_head: db 0
q_tail: db 0
vbhook: dw 0
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
; sprite engine
sw_:    db 0
pw_:    db 0
h_:     db 0
w_:     db 0
col_:   db 0
skip_:  db 0
rowcnt: db 0
shiftn: db 0
srcptr: dw 0
shiftend: dw 0
rowd:   ds 6
dlptr:  dw 0
elptr:  dw 0
drawlist: ds 4*24+1
eraselist: ds 4*24+2
noq:    db 0
prows:  db 0
savesp: dw 0
mapptr: dw 0
sprend: dw 0
bmap:   ds 4
lastsh: db 0
ur_w:   db 0
; surface (copied from surftab, 16 bytes)
s_latch: db 0
s_bgmap: ds 4
s_sprmap: ds 4
s_shadow: db 0
s_style: db 0
s_rest: db 0
s_keep: db 0
s_name: dw 0
s_pad:  db 0
surface: db 0
crowdtim: db 0
crowdflip: db 0
; game set-up
mode:   db 0
intour: db 0
tourn:  db 0
round:  db 0
gamesper: db 0
setsneed: db 0
classic: db 0
menusel: db 0
exopp:  db 0
excourt: db 0
curopp: db 0
tourpts: ds 3
; players
pl0:    ds PSIZE
pl1:    ds PSIZE
; ball
ball_x: dw 0
ball_y: dw 0
ball_z: dw 0
ball_vx: dw 0
ball_vy: dw 0
ball_vz: dw 0
ball_st: db 0
ball_bnc: db 0
ball_last: db 0
ball_cross: db 0
ball_serve: db 0
ball_net: db 0
ball_cord: db 0
ball_fire: db 0
prev_y: dw 0
land_x: db 0
land_y: db 0
shotT:  db 0
shottype: db 0
tmpz:   db 0
tmpnet: db 0
hit_d:  db 0
hit_dx: db 0
tmp_dy: db 0
tmp_k:  db 0
srv_tim: db 0
srv_hitz: db 0
srv_x:  db 0
rally:  db 0
; score
pts:    ds 2
games:  ds 2
sets:   ds 2
tiebreak: db 0
tbtarget: db 0
server: db 0
servenum: db 0
match_over: db 0
match_win: db 0
pt_over: db 0
pt_win: db 0
pt_reason: db 0
aw:     db 0
al:     db 0
lastsetg: db 0
cs:     db 0
cr:     db 0
pf:     db 0
callline2: dw 0
tbuf:   ds 34
tbuf2:  ds 24
; effects
pop_tim: db 0
pop_on: db 0
pop_w:  db 0
pop_str: dw 0
popsave: ds 5*12
pop_idx: db 0
pop_x:  db 0
pop_y:  db 0
flag_tim: db 0
flag_x: db 0
flag_y: db 0
puff_tim: db 0
puff_x: db 0
puff_y: db 0
bscr:   dw 0
; front end
demotim: dw 0
attr_t: dw 0
tmsg:   db 0
infohook: dw 0
hiptr:  dw 0
nameb:  ds 4
hitab:  ds 30
hpos:   db 0
hrow:   db 0
hy:     db 0
ra_t:   db 0
ra_dir: db 0
ra_x0:  db 0
ra_x1:  db 0
ra_pf:  db 0
ra_pn:  db 0
ra_sw0: db 0
ra_sw1: db 0
ra_bx:  db 0
ra_by:  db 0
mt_i:   db 0
cp_c:   db 0
cp_r:   db 0
tmpa:   db 0
tmpy:   db 0
; practice
pr_balls: db 0
pr_hits: db 0
pr_score: ds 2
feedtim: db 0
cone_x: ds 3
cone_y: ds 3
cone_t: ds 3
; records
srok:   db 0
probe1: db 0
probe3: db 0
recbuf: ds REC_LEN+1
; test hooks, only ever set from the emulator (-poke); always 0 on hardware
autoplay: db 0
dbg_why: ds 8
vars_end:
        assert vars_end < qbuf, "vars overflow"
        display "vars end: ",/A,vars_end
