        DEVICE NOSLOT64K
        include "defs.asm"

; ===================================================================== vars
        org $7800
fieldctr  db 0
lastcopy  db 0
ready     db 0
intoff    db 0
lastfr    db 0
dtf       db 3          ; fields used by the last frame
latchv    db L_MODE
spkoff    db L_MODE|L_SPK0
snd_acc   dw 0
snd_inc   dw 0
snd_noise db 0
sfx_n     db 0
sfx_p     dw 0
frames    dw 0
; camera / road
pos_ff    db 0
pos_f     db 0
pos_s     dw 0
camx      dw 0
camalt    dw 0
camref    dw 0
speed     dw 0          ; km/h * 64
adv       dw 0
dist      dw 0
panox     dw 0
xacc      dw 0
dxacc     dw 0
segp      dw 0
bidx      db 0
kidx      db 0
zi        dw 0
cur_ls    dw 0
cur_y     db 0
cur_x     dw 0
cur_w     db 0
prv_y     db 0
prv_x     dw 0
prv_w     db 0
clip      db 0
fs_n      db 0
fs_k      db 0
lodn      db 0
xstep     dw 0
wstep     dw 0
lnx       ds 3          ; x 16.8 (frac, lo, hi)
lnw       dw 0          ; w 8.8
row       db 0
rowadr    dw 0
; per-offset projections (33 each)
prj_y     ds 33
prj_w     ds 33
prj_c     ds 33
prj_xl    ds 33
prj_xh    ds 33
; draw list
dl_n      db 0
dl_ptr    dw 0
dl_buf    ds DL_MAX*DL_SIZE
          ALIGN 256
dl_bkt    ds 64
; game
gstate    db 0
keys      db 0
joyok     db 0
joyarm    db 0
demo      db 0
leg       db 0
section   db 0
sec_base_next dw 0
leg_time  db 60
traffic   db 6
tleft     db 0
tsub      db 0
score     ds 3          ; BCD (x10)
hiscore   ds 3
offroad   db 0
steerdir  db 0
steerhold db 0
wheelacc  db 0
pframe_spin db 0
crash_t   db 0
end_t     db 0
cnt_n     db 0
cnt_t     db 0
want_load db 0
seed      dw 0
obj_ptr   dw 0
gan_ptr   dw 0
gan_seg   dw 0
gan_kind  db 0
gan_time  db 0
msg_id    db 0
msg_t     db 0
hud_tdirty db 0
hud_sdirty db 0
; colours (copied as one block from the section header)
hud_fg    db 0
hud_bg    db 0
big_fg    db 0
big_bg    db 0
msg_col   db 0
msg_shadow db 0
gan_col1  db 0
gan_col2  db 0
gan_col3  db 0
tun_col   db 0
tun_col2  db 0
solid_tab ds 16
roofs     dw 0
roofy     db 0
roofc     db 0
tmark     db 0          ; written once per frame (emulator timing hook)
cars      ds NCARS*C_LEN
vars_end:
        ASSERT vars_end <= $7C00
stack_top equ $7E00

; ===================================================================== code
        org $8000
entry:
        di
        ld sp,stack_top
        ; DOS mapping: is $5FFF writable RAM? (as 13 Ghosts / NZ Story)
        ld hl,$5FFF
        ld b,(hl)
        ld a,b
        cpl
        ld (hl),a
        ld a,(hl)
        xor b
        ld (hl),b
        and 1
        ld (dosmap),a
        ld a,L_MODE|L_SPK0
        ld (LATCH),a
        ld hl,$7800             ; variables are not in the load image
        ld de,$7801
        ld bc,vars_end-$7800-1
        ld (hl),0
        ldir
        ld a,L_MODE
        ld (latchv),a
        ld a,L_MODE|L_SPK0
        ld (spkoff),a
        ld a,FPS_FIELDS
        ld (dtf),a
        ld hl,$4321
        ld (seed),hl
        ld a,$05
        ld (hiscore+1),a
        call init_im2
        call joy_detect
        ld a,MAP_FE
        ld (race_map),a
        ld hl,n_common
        call load_dat           ; tables -> bank 3, common sprites + art -> upper 0
        jr c,boot_fail
        bank MAP_FE
        ei
        jp FE_MAIN              ; front end (upper bank 0)

boot_fail:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,511
        ld (hl),$20
        ldir
        ld hl,t_nofile
        ld de,VRAM+32*7
.l:     ld a,(hl)
        or a
        jr z,.h
        and $3F
        ld (de),a
        inc hl
        inc de
        jr .l
.h:     xor a
        ld (LATCH),a
        jr .h
t_nofile: db "  REDLINE: CANNOT READ RLCOM.DAT",0
n_common: db '"RLCOM"',0

init_im2:
        ld hl,IM2TAB
        ld b,0
.l:     ld (hl),high IM2VEC
        inc hl
        djnz .l
        ld (hl),high IM2VEC
        ld a,$C3
        ld (IM2VEC),a
        ld hl,isr
        ld (IM2VEC+1),hl
        ld a,high IM2TAB
        ld i,a
        im 2
        ret

; ---------------------------------------------------------------- ISR
; INT is held for the 56 lines of field sync.  When a finished back buffer
; is waiting (and the frame has had its 3 fields), copy it to VRAM rows
; 12-63 racing ahead of the beam, one engine-sound sample per row;
; otherwise return with interrupts still off - maybe_ei re-enables them
; once sync has ended, so no time is burnt waiting for it.  (From BIX.)
isr:
        push af
        push hl
        ld hl,fieldctr
        inc (hl)
        ld a,(ready)
        or a
        jr z,.noc
        ld a,(lastcopy)
        ld l,a
        ld a,(fieldctr)
        sub l
        cp FPS_FIELDS
        jr nc,.copy
.noc:   ld a,1
        ld (intoff),a
        pop hl
        pop af
        ret                     ; interrupts stay off until maybe_ei
.copy:  push bc
        push de
        ex af,af'
        push af
        ex af,af'
        exx
        push bc
        push de
        push hl
        ld hl,(snd_acc)
        ld de,(snd_inc)
        sla e                   ; (half the sample rate: double the step)
        rl d
        ld a,(spkoff)
        ld c,a
        exx
        ld a,(fieldctr)
        ld (lastcopy),a
        ld hl,BB
        ld de,VRAM+BBTOP*32
        ld a,BBROWS/2
.row:   REPT 64                 ; two rows per engine-sound sample
        ldi
        ENDR
        exx
        add hl,de
        ex af,af'
        ld a,h
        rla
        sbc a,a
        and $21
        xor c
        ld (LATCH),a
        ex af,af'
        exx
        dec a
        jp nz,.row
        exx
        ld (snd_acc),hl
        pop hl
        pop de
        pop bc
        exx
        ex af,af'
        pop af
        ex af,af'
        xor a
        ld (ready),a
        ld (intoff),a
        pop de
        pop bc
        pop hl
        pop af
        ei
        reti

maybe_ei:
        ld a,(intoff)
        or a
        ret z
        ld a,(LATCH)
        rla
        ret nc                  ; still in field sync
        xor a
        ld (intoff),a
        ei
        ret

; hand the frame to the ISR and wait for the copy
present:
        ld a,1
        ld (ready),a
.w:     call maybe_ei
        ld a,(ready)
        or a
        jr nz,.w
        ld a,(lastcopy)
        ld hl,lastfr
        sub (hl)
        ld (dtf),a
        ld a,(lastcopy)
        ld (lastfr),a
        ld a,(dtf)
        ld (tmark),a
        ld hl,(frames)
        inc hl
        ld (frames),hl
        ret

; HL signed * A / 256 -> HL (once-a-frame use)
mul_s8: ld c,a
        bit 7,h
        jr z,.u
        NEGHL
        ld a,c
        call .u
        NEGHL
        ret
.u:     ex de,hl
        ld hl,0
        ld a,c
        ld b,8
.l:     rra
        jr nc,.n
        add hl,de
.n:     rr h
        rr l
        djnz .l
        ret

; trampolines for the front end (it lives in upper bank 0)
fe_race:                        ; A = leg -> A = result
        call race
        push af
        ld a,MAP_FE
        ld (race_map),a
        out (BANKPORT),a
        pop af
        ret
fe_load:                        ; HL = name -> C if missing
        ld a,MAP_FE
        ld (race_map),a
        call load_dat
        push af
        ld a,MAP_FE
        out (BANKPORT),a
        pop af
        ret

        include "bank.asm"
        include "road.asm"
        include "pano.asm"
        include "sprites.asm"
        include "game.asm"
        include "hud.asm"
        include "sound.asm"
        include "joy.asm"
        include "race.asm"
        include "loader.asm"
        include "demo.asm"
code_end:
        ASSERT code_end <= BB, "main code overflows the back buffer"
        DISPLAY "main code end ",/H,code_end," free ",/D,BB-code_end

; ===================================================================== front end (upper bank 0)
        org $B800
        include "front.asm"
fe_end:
        ASSERT fe_end <= TITLE_ART
        DISPLAY "front end end ",/H,fe_end
        SAVEBIN "../build/main.bin",$8000,BB-$8000
        SAVEBIN "../build/fe.bin",$B800,fe_end-$B800
