; =====================================================================
;  DUEL II - ACE OF ACES RETURNS
;  for the Dick Smith VZ300 / VZ200 (Mode 1, 128x64, 4 colours)
;  with the BennVenn SD loader + 128K RAM expansion (RAM to $FFFF).
;  Sequel to the VZ200/VZ300 game DUEL ("ACE OF ACES").
;  ViBED by BPM 2026.  Assemble: sjasmplus main.asm  (or tools/zasm.py)
; =====================================================================
        DEVICE NOSLOT64K
VRAM    equ $7000
BBUF    equ $F000               ; backdrop (terrain + HUD)
FBUF    equ $F800               ; composed frame
SPRWORK equ $4000               ; recoloured sprite copies, in the SD card's SRAM window
RMAP0   equ $6300               ; recolour tables (theatre map / map with 1<->2 swapped)
RMAP1   equ $6400
frames_ram equ $6500            ; frame table with pointers to the copies (NFRAMES*10)
DQ      equ $7C00               ; commit queue: rows waiting to be copied (128-entry ring)
DLO     equ $7D00               ; dirty spans: lo at +0, hi at +$40;
OLO     equ $7D80               ; erase spans: lo at +$80, hi at +$C0
STACKTOP equ $7FFE
MODE1   equ $08
CSS1    equ $10
ARENA_TOP equ 6
ARENA_H equ 58
SAVEADR equ $6780               ; records, in BennVenn SRAM bank 3
MODE_CAMP  equ 1
MODE_2P    equ 2
MODE_DEMO  equ 3
MODE_BONUS equ 4
MODE_TITLE equ 5

        org $8000
start:
        di
        ld sp,STACKTOP
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        call clear_dirty
        call clear_objd
        ld a,MODE1
        ld (latchbase),a
        ld (latchcur),a
        ld (palbase),a
        ld ($6800),a
        xor a
        call cls_vram           ; start-up only
        ld a,r
        ld l,a
        ld h,$5A
        ld (seed),hl
        ld a,2
        ld (soundmode),a
        ld a,100
        ld (cbudget),a
        ld a,3
        ld (rounds2p),a
        ld hl,hitab_init
        ld de,hitab
        ld bc,30
        ldir
        call load_records
        jp attract

hitab_init:
        db $02,$50,$00,"BPM"
        db $01,$80,$00,"ACE"
        db $01,$00,$00,"VZ3"
        db $00,$50,$00,"DUL"
        db $00,$25,$00,"RUD"

; =====================================================================
        include "core.asm"
        include "gfx.asm"
        include "sound.asm"
        include "game.asm"
        include "front.asm"
        include "data.inc"

code_end:
        savebin "duel2.bin",start,code_end-start
        assert code_end <= BBUF, "code too big"
        assert SPRWORK+FRAMEWORK <= RMAP0, "out of memory for sprites"
        assert frames_ram+NFRAMES*10 <= $6780, "frame table too big"
        display "code+data end: ",/A,code_end, "  sprites end: ",/A,SPRWORK+FRAMEWORK

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
drone:  dw 0
soundmode: db 0
keys:   db 0
keysnew: db 0
pad1:   db 0
pad2:   db 0
pad1new: db 0
pad2new: db 0
joyb1:  db 0
joyb2:  db 0
mnu:    db 0
mnunew: db 0
ink_fg: db 0
ink_bg: db 0
inktab: ds 8
txtoff: db 0
objmark: db 0
cbudget: db 0
budget_: db 0
dq_tp:  dw 0
dq_h:   db 0
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
; gfx
bw_dst: dw 0
bw_map: db 0
bl_y:   db 0
bl_col: db 0
bl_w:   db 0
bl_h:   db 0
bl_lo:  db 0
bl_hi:  db 0
bl_fill: db 0
bl_end: db 0
bl_s:   db 0
mc_x:   db 0
mc_old: db 0
tmap:   ds 4
; theatre
theatre: db 0
th_rec: ds TH_SIZE
col0:   db 0
col1:   db 0
col2:   db 0
col3:   db 0
cloudfill: db 0
accfill: db 0
wind:   dw 0
ncl:    db 0
clouds: ds MAXCL*CL_SIZE
; game state
mode:   db 0
quit:   db 0
guns_on: db 0
rend_t: db 0
roundno: db 0
need:   db 0
p2ace:  db 0
p1cpu:  db 0
nodamage: db 0
hud_dirty: db 0
pl0:    ds PSIZE
pl1:    ds PSIZE
bullets: ds NBUL*BUSIZE
parts:  ds NPART*PASIZE
partnext: db 0
pcol:   db 0
fxs:    ds NFX*FXSIZE
balloons: ds NBAL*BASIZE
bal_t:  dw 0
chute_x: dw 0
chute_y: dw 0
chute_t: db 0
banner: dw 0
banner_t: db 0
popup:  dw 0
popup_t: db 0
gust_t: db 0
gust_len: db 0
gustv:  dw 0
light_t: db 0
charge_t: db 0
charge_cl: db 0
bolt_x: db 0
bolt_h: db 0
ai_dx:  db 0
ai_dy:  db 0
ai_diff: db 0
tmpa:   db 0
tmpb:   db 0
tmpc:   db 0
tmpd:   db 0
tmpx:   db 0
; campaign
score:  ds 3
lives:  db 0
acen:   db 0
bn_left: db 0
bn_got: db 0
bn_secs: db 0
bn_fr:  db 0
bn_spt: db 0
; front end
menusel: db 0
th2p:   db 0
rounds2p: db 0
classic: db 0
attr_t: dw 0
tmsg:   db 0
hiptr:  dw 0
nameb:  ds 4
hitab:  ds 30
hpos:   db 0
hrow:   db 0
hy:     db 0
demot:  dw 0
; records
srok:   db 0
probe1: db 0
probe3: db 0
recbuf: ds REC_LEN+1
; test hooks, only ever set from the emulator (-poke); always 0 on hardware
autoplay: db 0
godmode: db 0
vars_end:
        assert vars_end < DQ, "vars overflow"
        display "vars end: ",/A,vars_end
