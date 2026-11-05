; =====================================================================
;  STAR BLASTER II - THE ENERMY RETURNS
;  for the Dick Smith VZ300 / VZ200 (Mode 1, 128x64, 4 colours)
;  with the BennVenn SD loader + 128K RAM expansion.
;  Sequel to STAR BLASTER (Dubois & McNamara). All new code, art and music.
;  ViBED by BPM 2026.   Assemble: sjasmplus main.asm (see build.sh)
; =====================================================================
        DEVICE NOSLOT64K
VRAM    equ $7000
BG      equ $F800               ; back buffer (= VRAM | $8800)
BASE    equ $F000               ; persistent picture that "erase" restores
RLO     equ $7C00               ; per-row dirty spans: new lo/hi, old lo/hi
CCODE   equ $ED00               ; generated VRAM copy code (<= 768 bytes)
STACKTOP equ $7FFE
MODE1   equ $08
CSS1    equ $10
CBUDGET equ 12288               ; (multiple of 4096: 16-T units)               ; T-states of VRAM copying per vblank
VIEWH   equ 44                  ; cockpit view rows 0..43, HUD below
CX      equ 64
CY      equ 22

        org $8000
start:
        di
        ld sp,STACKTOP
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld hl,gvars_start
        ld de,gvars_start+1
        ld bc,gvars_end-gvars_start-1
        ld (hl),0
        ldir
        ld a,MODE1
        ld (latchbase),a
        ld (latchcur),a
        ld ($6800),a
        ld hl,VRAM              ; start-up only: blank the screen to blue
        ld de,VRAM+1
        ld bc,2047
        ld (hl),$AA
        ldir
        call build_library      ; also selects SRAM bank 3
        ld a,r
        ld l,a
        ld h,$5B
        ld (seed),hl
        ld a,2
        ld (soundmode),a
        ld a,2
        ld (ticklen),a
        ld a,2
        ld (skill),a
        ld hl,hitab_init
        ld de,hitab
        ld bc,HI_N*8
        ldir
        call ranges_init
        ld a,$C9
        ld (CCODE),a
        jp attract

hitab_init:     ; score (3 BCD), sector reached, initials (3), pad
        db $02,$00,$00,8,"BPM",0
        db $01,$50,$00,6,"VZ3",0
        db $01,$00,$00,5,"DUB",0
        db $00,$50,$00,3,"MAC",0
        db $00,$25,$00,1,"ACE",0
HI_N    equ 5

typecol: db 3,3,1,1,1,0,3,0,3,3,1,1     ; dot colour per object type
        ALIGN 32
colpx:  db $00,$00,$00,$00
        db $40,$10,$04,$01
        db $80,$20,$08,$02
        db $C0,$30,$0C,$03
pxmask: db $3F,$CF,$F3,$FC

        include "core.asm"
        include "sound.asm"
        include "game.asm"
        include "front.asm"
        include "data.inc"
code_end:
        display "code end: ",/A,code_end
        ASSERT code_end <= LIBHI

        savebin "sb2.bin",start,code_end-start

; ---------------------------------------------------------------------
; variables ($7B00-$7BFF, $7D00-$7DFF) and tables
; ---------------------------------------------------------------------
        org $7AE8
vars_start:
latchbase: db 0
latchcur: db 0
acc1:   dw 0
acc2:   dw 0
step1:  dw 0
step2:  dw 0
framecount: dw 0
tickframe: dw 0
ticklen: db 0
elapsed: db 0
fslow:  db 0
seed:   dw 0
inp:    db 0
inpnew: db 0
keys:   db 0
keysnew: db 0
autoplay: db 0
godmode: db 0
forceclear: db 0
trainer: db 0
skill:  db 0
soundmode: db 0
budget: dw 0
psbase: db 0
cptr:   dw 0
clipbot: db 0
ink_fg: db 0
ink_bg: db 0
inktab: ds 8
txtbase: db 0
txtdbl: db 0
pc_col: db 0
pc_row: db 0
pc_byte: db 0
numbuf: ds 6
ps_row: db 0
ps_col: db 0
lx0:    db 0
ly0:    db 0
lx1:    db 0
ly1:    db 0
lcol:   db 0
ldx:    db 0
ldy:    db 0
lsx:    db 0
lsy:    db 0
lerr:   db 0
lcnt:   db 0
ds_sx:  dw 0
ds_sy:  db 0
ds_type: db 0
ds_b:   db 0
ds_h:   db 0
ds_data: dw 0
ds_shift: db 0
ds_col: db 0
ds_cs:  db 0
ds_n:   db 0
ds_y0:  db 0
ds_rs:  db 0
ds_rows: db 0
ds_r0:  db 0
ds_c0:  db 0
ds_scr: dw 0
spr_hw: db 0
spr_hh: db 0
save_sp: dw 0
lb_b:   db 0
lb_h:   db 0
lb_sz:  dw 0
fr_byte: db 0
; sound
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
hitab:  ds 8*5
vars_end:
        ASSERT vars_end <= RLO
        org $7D00
gvars_start:
        include "gvars.asm"
gvars_end:
        ASSERT gvars_end <= $7E00
