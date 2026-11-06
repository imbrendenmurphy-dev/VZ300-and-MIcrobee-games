; =====================================================================
;  ROBOGEDDON 2085
;  A Robotron-style twin-stick arena shooter for the Dick Smith VZ300
;  (Mode 1, 128x64, 4 colours) with the BennVenn SD loader + 128K.
;  ViBED by BPM 2026.  Original code, graphics and music.
;  Assemble: sjasmplus main.asm
; =====================================================================
        DEVICE NOSLOT64K

VRAM    equ $7000
LATCH   equ $6800
OBJ     equ $F380               ; 64 objects x 8 bytes
EBUL    equ $F580               ; 12 enemy bullets x 8
SHOTS   equ $F5E0               ; 6 player shots x 8
HISC    equ $F610               ; high-score table 8 x 8 (to $F650)
BUF0    equ $E800               ; frame buffer 0
BD      equ $4000               ; front-end backdrop (BennVenn SRAM)
IMTAB   equ $F000               ; IM2 vector table ($F000-$F100 = $F1)
ISRJP   equ $F1F1               ; jp isr
VARS    equ $F200
STACKTOP equ $F800
BUF1    equ $F800               ; frame buffer 1

MAXOBJ  equ 64
NEBUL   equ 12
NSHOT   equ 6
MODE1   equ $08
CSS1    equ $10

; key row addresses
KR0     equ $68FE
KR1     equ $68FD
KR2     equ $68FB
KR3     equ $68F7
KR4     equ $68EF
KR5     equ $68DF
KR6     equ $68BF
KR7     equ $687F

        org $8000
start:
        di
        ld      sp,STACKTOP
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
        ld      (hl),0
        ldir
        ld      hl,BUF1
        ld      de,BUF1+1
        ld      bc,2047
        ld      (hl),0
        ldir
        ld      a,BUF1/256
        ld      (drawh),a
        ld      a,8
        ld      (clip_top),a
        ld      a,63
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
        xor     a
        call    build_dither
        ld      a,r
        ld      l,a
        ld      h,$B7
        ld      (seed),hl
        ld      a,$5A
        ld      (nlfsr),a
        ld      hl,hisc_init
        ld      de,HISC
        ld      bc,64
        ldir
        call    load_records
        ei
        jp      attract

; no_sram: say so on the screen and stop
no_sram:
        ld      a,VRAM/256
        ld      (drawh),a
        ld      hl,VRAM
        ld      de,VRAM+1
        ld      bc,2047
        ld      (hl),0
        ldir
        ld      hl,s_nosram1
        ld      c,24
        ld      a,$FF
        call    text3c
        ld      hl,s_nosram2
        ld      c,32
        ld      a,$AA
        call    text3c
.h:     jr      .h
s_nosram1: db "ROBOGEDDON NEEDS THE",0
s_nosram2: db "BENNVENN SD + 128K",0

        include "engine.asm"
        include "game.asm"
        include "front.asm"

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
cyc_pat:                ; green > yellow > red > blue > green, dithered between
        db      $00,$11,$55,$77,$FF,$EE,$AA,$88
        db      $00,$44,$55,$DD,$FF,$BB,$AA,$22
accel_tab:
        db      100,175,250
ring_cols:
        db      0,1,3,1

        include "data.asm"
        include "music.inc"
        include "gfx.inc"

code_end:
        savebin "robogedn.bin",start,code_end-start
        assert code_end <= BUF0, "code too big"
        display "code end: ",/A,code_end

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
bd_dirty:   db 0
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
numbuf:     ds 8
        ALIGN 16
dith:                           ; built from dith_t: 8 side bytes, then rows
sidetab:    ds 8
dith_top:   ds 1
dith_div:   ds 1
dith_bot:   ds 1
DITH_N      equ $-dith
; input
joy1:       db 0
joy2:       db 0
jfire:      db 0
kmove:      db 0
kfire:      db 0
keys:       db 0
keysnew:    db 0
mnu:        db 0
mnunew:     db 0
ctl_mode:   db 0                ; 0 dual stick, 1 one stick, 2 keys
trainer:    db 0
; game
demo:       db 0
gstate:     db 0
gtimer:     dw 0
logic_on:   db 0
mat_t:      db 0
mat_k:      db 0
wave:       db 0
lives:      db 0
score:      ds 3
next_life:  ds 3
hud_dirty:  db 0
flash_t:    db 0
kills_left: db 0
rescue_n:   db 0
fam_total:  db 0
fam_saved:  db 0
fam_lost:   db 0
droid_spd:  db 0
droid_acc:  db 0
droid_min:  db 0
easy:       db 0
safe_box:   ds 4
wave_lvl:   db 0
pick_t:     dw 0
nshots:     db 0
nebul:      db 0
cur_frame:  db 0
cur_wh:     dw 0
hit_dx:     db 0
hit_dy:     db 0
; player
pxf:        db 0
px:         db 0
pyf:        db 0
py:         db 0
pdir:       db 0
panim:      db 0
palive:     db 0
pshield:    db 0
ptriple:    db 0
pfirecd:    db 0
moveb:      db 0
fireb:      db 0
firing:     db 0
fdir:       db 0
; demo AI
ai_move:    db 0
ai_fire:    db 0
ai_t:       db 0
; wave row being spawned
wrow:       ds 10
; front end
scr_t:      dw 0
logo_t:     db 0
hs_pos:     db 0
hs_name:    ds 4
hs_cur:     db 0
tlimit:     db 0
att_step:   db 0
tmp1:       db 0
cb_p:       ds 8
cb_tab:     ds 50
badge_pos:  dw 0
srok:       db 0
probe1:     db 0
probe3:     db 0
recbuf:     ds 72
st_ptr:     dw 0
st_col:     db 0
st_y:       db 0
banner_t:   db 0
demo_quit:  db 0
txtbuf:     ds 40
tmp2:       db 0
vars_end:
        assert vars_end <= OBJ, "vars overflow into the object table"
