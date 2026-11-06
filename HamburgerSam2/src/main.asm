; =====================================================================
;  HAMBURGER SAM II - THE BURGER RUSH
;  for the Dick Smith VZ300 / VZ200 (Mode 1, 128x64, 4 colours)
;  with the BennVenn SD loader + 128K RAM expansion (RAM to $FFFF).
;  Sequel to the VZ200/VZ300 game HAMBURGER SAM (Dick Smith Electronics).
;  ViBED by BPM 2026.  Assemble: sjasmplus main.asm  (or tools/zasm.py)
; =====================================================================
        DEVICE NOSLOT64K
VRAM    equ $7000
BGBUF   equ $F800                ; working background (VRAM image)
STATBG  equ $F000                ; clean kitchen (girders, ladders, plates)
STACKTOP equ $7FFE
MODE1   equ $08
CSS1    equ $10
qbuf    equ $7C00               ; 128-byte commit ring (page aligned)
RMAP    equ $7D00               ; 256-byte recolour table
SAVEADR equ $6740               ; records, in BennVenn SRAM bank 3 ($6740-$67BF)

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
        ld a,1
        ld (maxkit),a
        ld hl,vb_none
        ld (vbhook),hl
        ld hl,hitab_init
        ld de,hitab
        ld bc,HIT_N*8
        ldir
        call build_sprites
        call load_records
        jp attract

HIT_N   equ 10
hitab_init:                     ; top ten: 3 BCD bytes + 5 letters (like the 1984 original)
        db $02,$00,$00,"BPM  "
        db $01,$50,$00,"SAM  "
        db $01,$20,$00,"VZ300"
        db $01,$00,$00,"PATTY"
        db $00,$80,$00,"BUNS "
        db $00,$60,$00,"EGGY "
        db $00,$50,$00,"FRANK"
        db $00,$40,$00,"DILL "
        db $00,$30,$00,"CHILI"
        db $00,$20,$00,"FRIES"

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

; =====================================================================
        include "core.asm"
        include "sound.asm"
        include "spr.asm"
        include "kitchen.asm"
        include "game.asm"
        include "front.asm"
        include "data.inc"

code_end:
        savebin "hamsam2.bin",start,code_end-start
shtab   equ code_end
SPRWORK equ shtab+NSPR*8
        assert SPRWORK+SHIFTSIZE <= STATBG, "out of memory for sprites"
        display "code+data end: ",/A,code_end, "  sprites end: ",/A,SPRWORK+SHIFTSIZE

; =====================================================================
;  variables (zeroed at start) at $7800
; =====================================================================
; piece record (10 bytes)
PC_X    equ 0                   ; left pixel (multiple of 4)
PC_F    equ 1                   ; floor it rests on / falls from (5 = plate)
PC_Y    equ 2                   ; top row now
PC_PR   equ 3                   ; pressed segments (bits 0-3)
PC_T    equ 4                   ; type 0-5
PC_C    equ 5                   ; column
PC_ST   equ 6                   ; 0 resting, 1 falling, 2 on the plate
PC_TF   equ 7                   ; target floor (5 = plate)
PC_N    equ 8                   ; extra floors still to fall (riders)
PC_OY   equ 9                   ; row before this frame's move
PSIZE   equ 10
MAXPC   equ 20
; enemy record (16 bytes)
E_ST    equ 0                   ; 0 off, 1 walk, 2 stunned, 3 riding, 4 squashed
E_T     equ 1                   ; type 0 hot dog, 1 egg, 2 pickle, 3 chilli
E_X     equ 2
E_Y     equ 3                   ; foot row
E_F     equ 4                   ; floor, or $FF on a ladder
E_DX    equ 5                   ; -1 / 0 / 1
E_DY    equ 6
E_ACC   equ 7
E_SPD   equ 8
E_TIM   equ 9
E_PC    equ 10                  ; piece ridden
E_LF    equ 11                  ; ladder top floor while climbing
E_ANIM  equ 12
E_FACE  equ 13                  ; 0 right, 1 left
ESIZE   equ 16
MAXEN   equ 6

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
drawlist: ds 4*16+1
eraselist: ds 4*16+2
noq:    db 0
prows:  db 0
savesp: dw 0
mapptr: dw 0
sprend: dw 0
bmap:   ds 4
lastsh: db 0
; game state
mode:   db 0                    ; 0 attract, 1 game, 2 demo
kitchen: db 0                   ; 0-7, 8 = classic
lap:    db 0
classic: db 0                   ; Classic 1984 unlocked
playclassic: db 0
maxkit: db 0                    ; highest kitchen reached (1-8)
startkit: db 0
menusel: db 0
score:  ds 3                    ; BCD, high byte first
nextlife: db 0                  ; next extra life at this many 10,000s (BCD)
lives:  db 0
peppers: db 0
lvh:    ds LVHSIZE              ; current kitchen header
npc:    db 0
pieces: ds PSIZE*MAXPC
ncolpc: ds 4                    ; pieces in each column
colstk: ds 4                    ; pieces on each plate
coldone: ds 4
burgers: db 0
drops:  db 0
enemies: ds ESIZE*MAXEN
spawnidx: db 0
rosteri: db 0
espeed: ds 4
stuntime: db 0
; Sam
sx:     db 0
sy:     db 0
sf:     db 0                    ; floor or $FF
slf:    db 0                    ; ladder top floor while climbing
sface:  db 0                    ; 0 right, 1 left
svert:  db 0                    ; last vertical dir (1 up, 2 down)
sacc:   db 0
sanim:  db 0
sst:    db 0                    ; 0 alive, 1 dying, 2 cheering
stim:   db 0
smoved: db 0
throwtim: db 0
pad:    db 0
padnew: db 0
; pepper
pep_tim: db 0
pep_x:  db 0
pep_y:  db 0
; bonus item
it_on:  db 0
it_t:   db 0
it_tim: dw 0
it_seq: db 0
; popups (score numbers) and sparkles
pop_tim: db 0
pop_x:  db 0
pop_y:  db 0
pop_idx: db 0
spk_tim: db 0
spk_x:  db 0
spk_y:  db 0
ride_n: db 0
deadtim: db 0
gtim:   dw 0
hudflag: db 0
pausef: db 0
; demo / autoplay pathing
ai_tf:  db 0
ai_tc:  db 0
ai_tim: db 0
ai_lastx: db 0
ai_lasty: db 0
ai_stuck: db 0
ai_tgt: db 0
dist:   ds 160                  ; BFS distances (floor*32+cell)
bfsq:   ds 160
; front end
attr_t: dw 0
tmsg:   db 0
infohook: dw 0
hiptr:  dw 0
nameb:  ds 6
hitab:  ds HIT_N*8
hpos:   db 0
hrow:   db 0
hy:     db 0
ch_t:   db 0
ch_x:   db 0
ch_dir: db 0
tmpa:   db 0
tmpb:   db 0
tmpc:   db 0
tmpd:   db 0
tmpx:   db 0
tmpy:   db 0
; Order Up! bonus round
ou_n:   db 0                    ; pieces left to drop
ou_want: db 0                   ; index of next layer wanted
ou_fx:  db 0
ou_fy:  db 0
ou_ft:  db 0
ou_on:  db 0
ou_spd: db 0
ou_orders: db 0
ou_score: ds 2
ou_delay: db 0
; records
srok:   db 0
probe1: db 0
probe3: db 0
recbuf: ds REC_LEN+1
; test hooks, only ever set from the emulator (-poke); always 0 on hardware
autoplay: db 0
godmode: db 0
vars_end:
        assert vars_end < qbuf, "vars overflow"
        display "vars end: ",/A,vars_end
