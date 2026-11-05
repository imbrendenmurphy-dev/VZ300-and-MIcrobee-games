; =====================================================================
;   C I R C U S   2      for the Dick Smith VZ200 / VZ300
;   A deluxe sequel to CIRCUS for the VZ.  "VIBED BY BPM 2026"
;
;   Target : VZ200/VZ300 + RAM expansion covering $8000-$F9FF
;            (BennVenn SD + 128K as-is; no mapper writes, no DOS calls,
;             nothing touched at or above $FA00)
;   Display: Mode 1 (6847 CG2, 128x64, 4 colours) throughout
;   Build  : sjasmplus src/main.asm  (see build.sh)
; =====================================================================
        DEVICE NOSLOT64K

LATCH   = $6800
VRAM    = $7000
BG      = $7800         ; background buffer (VZ system RAM area, unused: no ROM calls)
VARS    = $DD00         ; variables (not part of the file image)
STRIPS  = $E200         ; balloon row strips 4 rows x 4 shifts x 160 bytes
BBM     = $EC00         ; back buffer incl. 8-row top margin
BB      = $ED00         ; visible back buffer (64 rows x 32), 8-row margin below
STACKTOP= $F800         ; stack $F600-$F7FF
IMTAB   = $F800         ; IM2 vector table (257 bytes of $F9)
ISRJP   = $F9F9         ; JP isr

        ORG $8000
start:
        di
        ld sp,STACKTOP
        ld a,$08
        ld (LATCH),a
        ; clear variables
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld hl,vars2_start
        ld de,vars2_start+1
        ld bc,vars2_end-vars2_start-1
        ld (hl),0
        ldir
        ld hl,$1F3A
        ld (seed),hl
        ld hl,$ACE1
        ld (nseed),hl
        ld a,1
        ld (snd_on),a
        ld (difficulty),a
        call init_hiscores
        call init_offtab
        call spans_clear
        call setup_im2
        call detect_joy
        ld a,(frames)
        ld (nextframe),a
        ld a,$08
        ld (latchbase),a
        jp attract

        INCLUDE "engine.asm"
        INCLUDE "sound.asm"
        INCLUDE "game.asm"
        INCLUDE "attract.asm"
        INCLUDE "data.asm"
        INCLUDE "../build/gfx.inc"

; y address table for back buffer: y = -16..79
ytab:
yy      DEFL -8
        DUP 80
        dw BB + yy*32
yy      DEFL yy+1
        EDUP

code_end:
        ASSERT code_end <= VARS, "code image overlaps variables"
        ORG VARS
        ASSERT low VARS == 0

; ---------------------------------------------------------------------
; variables (cleared at start-up)
; ---------------------------------------------------------------------
vars_start:
SPANS:          ds 256          ; dirty byte spans (page aligned)
rowcur:         ds 64           ; whole-row-changed flags (page aligned)
pr_y:           db 0
pr_n:           db 0
                ds 62
offtab:         ds 128          ; y*32 words  (= rowcur + $80)
fullpres:       db 0
frames:         db 0
nextframe:      db 0
fsflag:         db 0
cr_cnt:         db 0
latchbase:      db 0
curbg:          db 0
colpat:         ds 4
text_buf:       dw 0
seed:           dw 0
nseed:          dw 0
joyon:          db 0
ds_src:         dw 0
ds_sp:          dw 0
numbuf:         ds 8
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
hud_bdirty:     db 0
hud_vdirty:     db 0
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
poleph:         db 0
hud_part:       db 0
rowlast:        ds 8
dr_off:         db 0
dr_y:           db 0
dr_chg:         db 0
dr_ych:         db 0
dr_i:           db 0
dr_ly:          db 0
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

        ASSERT vars_end < STRIPS, "out of memory below strips"

; second variable block in the gap after the IM2 table ($F901-$F9F8)
        ORG IMTAB+$101
vars2_start:
tmpx:           db 0
tmpy:           db 0
strbuf:         ds 34
dsbase:         dw 0
bs_k:           db 0
ss_spr:         dw 0
dr_q:           db 0
dr_bg:          dw 0
demo_act:       db 0
demo_key:       db 0
title_first:    db 0
t_msg:          db 0
t_tick:         db 0
t_msgt:         db 0
t_bal:          ds 16
t_time:         dw 0
iw_n:           db 0
anim_hook:      dw 0
rr_w:           db 0
rr_h:           db 0
hs_rank:        db 0
hs_ptr:         dw 0
hs_pos:         db 0
hiscores:       ds 5*6
hs_new:         db 0
bc_tmp:         db 0
vars2_end:
        ASSERT vars2_end <= ISRJP, "vars2 overflow"

; ---------------------------------------------------------------------
        SAVEBIN "../build/circus2.bin", start, code_end-start
