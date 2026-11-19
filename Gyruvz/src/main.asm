; =====================================================================
;  GYRUVZ
;  An orbital arcade shooter for the Dick Smith VZ300 / VZ200
;  (Mode 1, 128x64, 4 colours) with the BennVenn SD loader + 128K.
;  VIBED BY BPM 2026.  Original code, graphics and music.
;  Assemble: sjasmplus main.asm   (see build.sh)
; =====================================================================
        DEVICE NOSLOT64K

VRAM    equ $7000
LATCH   equ $6800
BUF0    equ $E800               ; frame buffer 0
IMTAB   equ $F000               ; IM2 vector table ($F000-$F100 = $F1)
ISRJP   equ $F1F1               ; jp isr
VARS    equ $F200
STACKTOP equ $F800
BUF1    equ $F800               ; frame buffer 1

MODE1   equ $08
CSS1    equ $10

        org $8000
start:
        di
        ; the front end, packed above the game, goes into the SRAM's second
        ; bank before anything else touches the RAM it sits in
        ld      sp,$F9F0
        ld      a,3
        out     ($37),a
        ld      hl,payload
        ld      de,B3
        call    unlz
        ld      a,1
        out     ($37),a
        ld      sp,STACKTOP
        call    gen_polar           ; (into the RAM the packed front end was in)
        call    gen_shifts
        ld      hl,VARS
        ld      de,VARS+1
        ld      bc,STACKTOP-VARS-257
        ld      (hl),0
        ldir
        ; IM2: table full of $F1 -> handler at $F1F1 whatever the bus holds
        ld      hl,IMTAB
        ld      de,IMTAB+1
        ld      bc,256
        ld      (hl),$F1
        ldir
        ld      a,$C3
        ld      (ISRJP),a
        ld      hl,isr
        ld      (ISRJP+1),hl
        ld      a,IMTAB/256
        ld      i,a
        im      2
        ; screen
        ld      a,MODE1
        ld      (vmode),a
        ld      (next_vmode),a
        ld      (LATCH),a
        ld      hl,BUF0
        ld      de,BUF0+1
        ld      bc,2047
        ld      (hl),$AA
        ldir
        ld      hl,BUF1
        ld      de,BUF1+1
        ld      bc,2047
        ld      (hl),$AA
        ldir
        ld      a,BUF1/256
        ld      (drawh),a
        xor     a
        ld      (clip_top),a
        ld      a,64
        ld      (clip_bot),a
        ; the card's SRAM must be there: it holds the screen-copy code
        ld      hl,cpy0t
        ld      (hl),$A5
        ld      a,(hl)
        cp      $A5
        jr      nz,no_sram
        ld      (hl),$5A
        ld      a,(hl)
        cp      $5A
        jr      nz,no_sram
        call    gen_copy
        ld      hl,BSS2
        ld      de,BSS2+1
        ld      bc,BSS2_END-BSS2-1
        ld      (hl),0
        ldir
        ld      a,r
        ld      l,a
        ld      h,$B7
        ld      (seed),hl
        ld      a,$5A
        ld      (nlfsr),a
        ld      a,1
        ld      (skill),a           ; PILOT
        ld      hl,hisc_init
        ld      de,HISC
        ld      bc,64
        ldir
        ld      a,1
        ld      (home_bank),a
        call    load_records
        call    stars_init
        jp      front_enter         ; (the front end runs with the interrupt off)

; no_sram: say so on the screen and stop
no_sram:
        ld      a,VRAM/256
        ld      (drawh),a
        ld      hl,VRAM
        ld      de,VRAM+1
        ld      bc,2047
        ld      (hl),$AA
        ldir
        ld      hl,s_nosram1
        ld      c,24
        ld      a,$55
        call    text3c
        ld      hl,s_nosram2
        ld      c,32
        ld      a,$FF
        call    text3c
.h:     jr      .h
s_nosram1: db "GYRUVZ NEEDS THE",0
s_nosram2: db "BENNVENN SD + 128K",0

        include "engine.asm"
        include "game.asm"
        include "boss.asm"
        include "glue.asm"
        include "records.asm"

; ---------------------------------------------------------------------
; tables that must be page aligned
; ---------------------------------------------------------------------
        ALIGN   256
pixtab:
        db      $00,$00,$00,$00
        db      $40,$10,$04,$01
        db      $80,$20,$08,$02
        db      $C0,$30,$0C,$03
lmask:  db      $FF,$3F,$0F,$03
rmask:  db      $C0,$F0,$FC,$FF
colpat: db      $00,$55,$AA,$FF

        include "tables.inc"
; text2x's masks: 8 font pixels -> the left / right screen byte
        ALIGN   256
        include "expmask.inc"
        include "data.asm"
        include "music.inc"
        include "gfx.inc"

main_end:
        display "game code end: ",/A,main_end
; the projection table is built here at power-up (after the payload below
; has been unpacked out of the way)
polar   equ main_end
SHIFTRAM equ polar+64*33
        assert SHIFTRAM+SHIFT_BYTES <= BUF0, "code + built tables run into the frame buffer"
        display "built tables end: ",/A,SHIFTRAM+SHIFT_BYTES
; the front end, packed (unpacked into bank 3 at power-up; then this RAM
; becomes the frame buffers and variables)
payload:
        incbin  "payload.lz"
code_end:
        savebin "gyruvz.bin",start,code_end-start
        display "file end: ",/A,code_end
        assert code_end <= $F900, "the file runs too high (keep clear of the loader)"

; =====================================================================
;  bank 3: the front end (assembled here, packed by build.sh)
; =====================================================================
        org $4000
B3:
        include "front3.asm"
        include "hsutil.asm"
        include "music3.inc"
pic_title:  incbin "pics/title.lz"
pic_comic1: incbin "pics/comic1.lz"
pic_comic2: incbin "pics/comic2.lz"
pic_comic3: incbin "pics/comic3.lz"
pic_frame:  incbin "pics/frame.lz"
; front-end variables
att_i:      db 0
att_t:      dw 0
in_att:     db 0
ag_secs:    db 0
mus_speed:  db 0
mus_ins:    ds 12
mus_chords: dw 0
mus_opos:   dw 0
mus_ppos:   dw 0
mus_rowc:   db 0
mus_tick:   db 0
mus_stop:   db 0
mus_dr:     db 0
mus_drt:    db 0
mus_atk:    db 0
mus_base:   db 0
mus_cb:     dw 0
mus_ph1:    dw 0
mus_ph2:    dw 0
mus_ph3:    dw 0
mus_chs:
mus_ch1:    ds 8
mus_ch2:    ds 8
mus_ch3:    ds 8
B3_END:
        display "bank 3 end: ",/A,B3_END
        assert B3_END <= SAVEADR, "the front end runs into the high scores"
        savebin "bank3.bin",B3,B3_END-B3

; =====================================================================
;  big arrays (zeroed at start, not part of the file)
; =====================================================================
; the object arrays live in the BennVenn SRAM (bank 1, $4000-$47FF, below
; the screen-copy code); they are cleared at start-up after the SRAM check
        org $4000
BSS2:
ENEMY:      ds MAXE*E_SIZE
PSHOT:      ds NPS*4
ESHOT:      ds NES*6
PART:       ds NPART*8
STARS:      ds NSTAR*3
FLOATS:     ds NFLT*6
GROUPS:     ds NGRP*4
SLOTS:      ds NSLOT
BSS2_END:
HITL    equ $4500                   ; this frame's hittable enemies (6 bytes each)
        assert BSS2_END <= HITL
        assert HITL+MAXE*6+1 <= cpy0t
        display "sram arrays end: ",/A,BSS2_END

; =====================================================================
;  variables (zeroed at start)
; =====================================================================
        org VARS
; engine
isr_sp:     dw 0
fields:     dw 0
phase:      db 0
front:      db 0
ready:      db 0
shown:      db 0
vmode:      db 0
next_vmode: db 0
spk:        db 0
drawh:      db 0
drawh_sv:   db 0
gtick:      db 0
sp_save:    dw 0
sp_save2:   dw 0
sacc:       dw 0
sstep:      dw 0
snoise:     db 0
nlfsr:      db 0
sfx_ptr:    dw 0
sfx_prio:   db 0
music_on:   db 0
mus_ptr:    dw 0
mus_start:  dw 0
mus_loop:   db 0
mus_cnt:    db 0
mus_note:   dw 0
snd_mode:   db 0
seed:       dw 0
; drawing temps
sp_fr:      db 0
sp_kk:      db 0
sp_x:       db 0
sp_w:       db 0
sp_h:       db 0
clip_top:   db 0
clip_bot:   db 0
hl_l:       db 0
hl_r:       db 0
hl_lm:      db 0
hl_rm:      db 0
rc_x0:      db 0
rc_y0:      db 0
rc_x1:      db 0
rc_y1:      db 0
rc_col:     db 0
rc_pat:     db 0
txtcol:     db 0
tlimit:     db 0
dc_fr:      db 0
numbuf:     ds 8
; input
joy1:       db 0
jfire:      db 0
kmove:      db 0
keys:       db 0
keysnew:    db 0
mnu:        db 0
mnunew:     db 0
; options
skill:      db 0                ; 0 CADET, 1 PILOT, 2 ACE
; game
demo:       db 0
game_sp:    dw 0
sector:     db 0
wave:       db 0
loop:       db 0
level:      db 0
lives:      db 0
score:      ds 3
next_life:  ds 3
pips:       db 0
pips_max:   db 0
bonus_rnd:  db 0
nofire:     db 0
hits_taken: db 0
bon_hits:   db 0
start_sec:  db 0
cont_sec:   db 0
; difficulty (copied from difftab)
d_dive:     db 0
d_maxdiv:   db 0
d_fire:     db 0
d_espd:     dw 0
d_steer:    db 0
d_accel:    db 0
d_mine:     db 0
; wave spawner
spawn_ptr:  dw 0
spawn_wait: db 0
spawn_done: db 0
next_grp:   db 0
dive_t:     db 0
divers:     db 0
hold_rot:   db 0
alive_n:    db 0
spread_step: db 0
fm_base:    db 0
fm_k:       db 0
fm_data:    ds 8
; player
pa:         dw 0                ; angle 8.8 (high byte = angle)
pspd:       db 0                ; 1/16 units per frame
pdir:       db 0
palive:     db 0
pinv:       db 0
pdead_t:    db 0
pfire_cd:   db 0
ptwin:      db 0
px:         db 0
py:         db 0
fire_held:  db 0
; demo AI
ai_tgt:     db 0
ai_fire:    db 0
ai_has:     db 0
; effects
flash_t:    db 0
banner_t:   db 0
banner1:    dw 0
banner2:    dw 0
banner_c:   db 0
warp:       db 0
shake:      db 0
; boss
boss_on:    db 0
bstate:     db 0
bt:         db 0
bhp:        db 0
bhp_max:    db 0
brot:       db 0
brs:        db 0
beye:       db 0
beye_t:     db 0
bat:        db 0
bcharge:    db 0
bkind:      db 0
bvolley:    db 0
bnpod:      db 0
bpods:      db 0
bhit:       db 0
bdesign:    db 0
bvangle:    db 0
; front end
scr_t:      dw 0
hs_pos:     db 0
hs_cur:     db 0
srok:       db 0
probe1:     db 0
probe3:     db 0
tmp1:       db 0
tmp2:       db 0
txtbuf:     ds 40
att_step:   db 0
logo_t:     db 0
gover:      db 0
gover_t:    db 0
demo_t:     dw 0
demo_quit:  db 0
base_vm:    db 0
alive_c:    db 0
divers_c:   db 0
pods_c:     db 0
pts:        dw 0
fval:       dw 0
bx:         dw 0
bn:         db 0
bpodsp:     db 0
brearm:     db 0
lg_x:       db 0
lg_n:       db 0
lg_f:       db 0
hs_held:    db 0
last_letter: db 0
skill_sv:   db 0
cont_sv:    db 0
snd_sv:     db 0
hud_sig:    ds 14
hitp:       dw 0
gs_src:     dw 0
gs_s:       db 0
gs_wb0:     db 0
gs_wbs:     db 0
gs_h:       db 0
gs_pk:      db 0
gs_pp:      db 0
gs_j:       db 0
home_bank:  db 0
b1_sec:     db 0
hs_title:   dw 0
sp_part:    dw 0
full_clr:   db 0
hud_dirty:  db 0
HISC:       ds 64               ; (main RAM: the records code copies these
recbuf:     ds 72               ;  while the SRAM's other bank is mapped)
t2l:        db 0
t2r:        db 0
vars_end:
        assert vars_end <= $F700, "vars run into the stack"
