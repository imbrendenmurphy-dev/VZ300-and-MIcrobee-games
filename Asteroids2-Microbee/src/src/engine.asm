; ===========================================================================
;  ASTEROIDS II  -  Microbee Premium Plus engine (upper 32K, block 0)
;  VIBED BY BPM 2026.  Original VZ300 game by the same author.
;
;  Display: 64x16 cells of 8x16, 512x256 pixels, every playfield cell a PCG
;  character.  Two complete screens ("pages") are kept: page 0 uses PCG
;  banks 0-7 and screen/colour RAM 000-3FF, page 1 banks 8-15 and 400-7FF.
;  The page not on view is drawn, then shown by moving the 6545 start
;  address during vertical blanking - flicker-free and tear-free.
;
;  Bitmap layout (column-major): byte column cx of a page lives in PCG bank
;  page*8 + cx/8 at F800h + (cx&7)*256 + y.  One column is 256 bytes, so
;  sprites walk down with 'inc l' and wrap vertically for free.  Row 0 of the
;  screen is the HUD (character ROM text) and hides bitmap lines 0-15.
;
;  Game logic: the original VZ300 code runs unchanged in block 1 (lower 32K)
;  at a fixed 25 ticks per second whatever the frame rate.
; ===========================================================================
        DEVICE NOSLOT64K
        INCLUDE "abi.inc"
        INCLUDE "spr-ids.inc"

MAP_SIM     equ $07         ; lower 32K = block 1, ROMs off, video at F000
STACK       equ $EFF0
P_LV        equ $1C
P_COLR      equ $08
SIM_INIT    equ $0000
SIM_NEWGAME equ $0003
SIM_STEP    equ $0006
SIM_TICK    equ $0009
SIM_MUSON   equ $000C
SIM_MUSOFF  equ $000F
SIM_SFX     equ $0012
SIM_EXPORT  equ $0015
SIM_SNDX    equ $0018
SFX_CLINK   equ 10
SFX_PICKUP  equ 16
SFX_EFIRE   equ 19
DIRTY_MAX   equ 100
PIX_MAX     equ 72

        ORG $8000
        jp start
        jp vb_poll_sim          ; $8003: the simulation's fs_poll (A, flags only)
; ---- $8006: compiled sprites call this when H wraps past FFh: next PCG
; bank of the same page (wrapping 63 -> 0 horizontally)
next_bank:
        ASSERT next_bank == $8006
        ld a,(cur_bank) : ld h,a : inc a : xor h : and 7 : xor h
        ld (cur_bank),a : out (P_LV),a
        ld h,$F8
        ret

start:
        di
        ld sp,STACK
        ld a,MAP_SIM : out ($50),a : ld (cur50),a
        ld hl,dot_masks : ld de,dot_mask_src : ld b,8
.dm:    ld a,(de) : ld (hl),a : inc hl : inc de : djnz .dm
        ld hl,DLIST : ld de,DLIST+1 : ld bc,$03FF : ld (hl),0 : ldir   ; exchange area
        ld hl,PLIST : ld de,PLIST+1 : ld bc,3*PLIST_MAX : ld (hl),0 : ldir
        ld hl,HUD_R0 : ld b,64                          ; HUD redraw ranges: none
.hr:    ld (hl),0 : inc h : ld (hl),0 : dec h : inc l : djnz .hr
        xor a : ld (HUD_ANY),a : ld (HUD_ANY+1),a
        ld hl,erase_chain : ld b,64
.ec:    ld (hl),$77 : inc hl : ld (hl),$2C : inc hl : djnz .ec
        ld (hl),$C9
        call pio_init
        call video_init
        call SIM_INIT
        call hs_init
        ld a,1 : ld (music_on),a
        jp attract

; ---------------------------------------------------------------------------
; hardware set-up
; ---------------------------------------------------------------------------
pio_init:
        ld a,$CF : out ($01),a : ld a,$FF : out ($01),a     ; PIO A: joystick in
        ld a,$07 : out ($01),a
        ld a,$CF : out ($03),a : ld a,$BF : out ($03),a     ; PIO B: b6 speaker out
        ld a,$07 : out ($03),a
        xor a : out ($02),a
        ret

video_init:
        xor a : out ($0B),a : out (P_COLR),a
        ld hl,crtc_tab : ld c,0
.cr:    ld a,c : out ($0C),a : ld a,(hl) : out ($0D),a
        inc hl : inc c : ld a,c : cp 16 : jr nz,.cr
        ; clear all 16 PCG banks
        ld c,$80
.bk:    ld a,c : out (P_LV),a
        ld hl,$F800 : ld de,$F801 : ld bc,$7FF : ld (hl),0 : ldir
        ld a,(.bk_c) : inc a : ld (.bk_c),a : ld c,a : cp $90 : jr nz,.bk
        ld hl,TEXT_MAP : ld de,TEXT_MAP+1 : ld bc,1023 : ld (hl),0 : ldir
        ld hl,tqf : ld de,tqf+1 : ld bc,1023 : ld (hl),0 : ldir
        ld hl,0 : ld (tqn0),hl : ld (tqn1),hl
        call screen_map
        xor a : ld (back),a
        call set_page_vars
        ld a,1 : ld (front),a
        jp show_front
.bk_c:  db $80

crtc_tab: db $6B,$40,$50,$37,$12,$08,$10,$11,$48,$0F,$20,$0F,$00,$00,$00,$00

; build screen, attribute and colour RAM for both pages and drop all text.
; Every cell of both pages is a bitmap PCG character - there is no
; character-ROM text at all; text is drawn into the bitmap (text layer).
screen_map:
        call text_clear
        ld a,$80 : out (P_LV),a         ; F000 = screen RAM
        ld hl,$F000
.s:     call cell_rc                    ; B = row, C = column, D = page
        ld a,c : and 7 : rlca : rlca : rlca : rlca : or b : or $80
        ld (hl),a : inc hl : ld a,h : cp $F8 : jr nz,.s
        ld a,$90 : out (P_LV),a         ; F000 = attribute RAM
        ld hl,$F000
.a:     call cell_rc
        ld a,c : rrca : rrca : rrca : and 7 : ld e,a
        ld a,d : add a,a : add a,a : add a,a : or e
        ld (hl),a : inc hl : ld a,h : cp $F8 : jr nz,.a
        ld a,$80 : out (P_LV),a
        ld a,$40 : out (P_COLR),a
        ld a,STAR_FAR : call make_col
        ld hl,$F800 : ld de,$F801 : ld bc,$7FF : ld (hl),a : ldir
        xor a : out (P_COLR),a
        ld a,1 : ld (hud_force),a
        ret
; HL = F000+pos or F800+pos -> B = row, C = col, D = page
cell_rc:
        ld a,l : and 63 : ld c,a
        ld a,h : and 3 : rlca : rlca : ld b,a
        ld a,l : rlca : rlca : and 3 : or b : ld b,a
        ld a,h : rrca : rrca : and 1 : ld d,a
        ret

; ---------------------------------------------------------------------------
; TEXT LAYER.  TEXT_MAP holds a character per cell (0 = none).  Text cells
; are drawn into each page's bitmap with the retro font; whenever a sprite
; or text change touches a text cell, the cell is queued for that page and
; redrawn after the sprites (text_redraw), so text always sits on top.
; ---------------------------------------------------------------------------
; drop all text: every text cell is queued (both pages) to be cleared
text_clear:
        ld hl,TEXT_MAP
.l:     ld a,(hl) : or a : jr z,.n
        ld (hl),0
        push hl : ld a,h : and 3 : ld h,a
        call tq_push0 : call tq_push1
        pop hl
.n:     inc hl : ld a,h : cp high TEXT_MAP + 4 : jr nz,.l
        ld hl,row_prot : ld b,16
.r:     ld (hl),0 : inc hl : djnz .r
        ld hl,ROW_LO : ld b,16                  ; text column spans: empty
.r2:    ld (hl),$FF : inc hl : djnz .r2
        ld b,16
.r3:    ld (hl),0 : inc hl : djnz .r3
        ld a,1 : ld (row_prot),a        ; HUD row always holds text
        xor a : ld (text_rows),a
        ld hl,ovl_cur : ld b,3*34
.o:     ld (hl),a : inc hl : djnz .o
        ret

; HL = cell (row*64+col), A = character (0 clears), C = colour
text_set:
        cp 96 : jr c,.u : sub 32        ; fold lower case
.u:     push bc : push de : push hl
        ld b,a
        ld de,TEXT_MAP : add hl,de
        ld a,(hl) : cp b : jr z,.same
        ld (hl),b
        pop hl : push hl
        call tq_push0 : call tq_push1
        ld a,b : or a : jr z,.clr
        ; flag the row as holding text
        push hl
        ld a,l : rlca : rlca : and 3 : ld e,a : ld a,h : add a,a : add a,a : or e
        ld e,a : ld d,0 : ld hl,row_prot : add hl,de : ld (hl),1
        pop hl : push hl
        ld a,l : and 63 : ld d,a                ; widen the row's text span
        ld a,e : add a,low ROW_LO : ld l,a : ld h,high ROW_LO
        ld a,d : cp (hl) : jr nc,$+3 : ld (hl),a
        ld a,l : add a,16 : ld l,a
        ld a,d : cp (hl) : jr c,$+3 : ld (hl),a
        pop hl
        ld a,c : jr .col
.clr:   ld a,STAR_FAR
.col:   call make_col : ld e,a
        ld a,$40 : out (P_COLR),a
        ld a,h : or $F8 : ld h,a : ld (hl),e
        set 2,h : ld (hl),e
        xor a : out (P_COLR),a
.same:  pop hl : pop de : pop bc
        ret

; HL = cell -> queue for page 0 / page 1 / the back page (keeps all regs)
tq_push0:
        push hl : push de
        ld de,tqf : add hl,de : bit 0,(hl) : jr nz,.x          ; already queued
        set 0,(hl) : or a : sbc hl,de : ex de,hl
        ld hl,(tqn0) : ld a,h : cp 2 : jr nc,.x
        inc hl : ld (tqn0),hl : dec hl
        add hl,hl : push de : ld de,tq0 : add hl,de : pop de
        ld (hl),e : inc hl : ld (hl),d
.x:     pop de : pop hl
        ret
tq_push1:
        push hl : push de
        ld de,tqf : add hl,de : bit 1,(hl) : jr nz,.x          ; already queued
        set 1,(hl) : or a : sbc hl,de : ex de,hl
        ld hl,(tqn1) : ld a,h : cp 2 : jr nc,.x
        inc hl : ld (tqn1),hl : dec hl
        add hl,hl : push de : ld de,tq1 : add hl,de : pop de
        ld (hl),e : inc hl : ld (hl),d
.x:     pop de : pop hl
        ret
tq_back:
        ld a,(back) : or a : jr z,tq_push0 : jr tq_push1

; redraw this page's queued text cells
text_redraw:
        ld a,(back) : or a : ld hl,tqn0 : ld de,tq0 : ld b,$FE : jr z,.p
        ld hl,tqn1 : ld de,tq1 : ld b,$FD
.p:     ld a,b : ld (.mask),a
        ld c,(hl) : inc hl : ld b,(hl) : xor a : ld (hl),a : dec hl : ld (hl),a
        ld a,b : or c : ret z
.l:     push bc
        ld a,c : and 3 : jr nz,.np
        call vb_poll
        call snd_slice
.np:    ld a,(de) : ld l,a : inc de : ld a,(de) : ld h,a : inc de
        push de
        push hl : ld de,tqf : add hl,de : ld a,(.mask) : and (hl) : ld (hl),a : pop hl
        push hl : ld de,TEXT_MAP : add hl,de : ld a,(hl) : pop hl
        ld (.ch),a
        ld a,l : and 63 : ld c,a                       ; column
        ld a,l : rlca : rlca : and 3 : ld b,a
        ld a,h : and 3 : add a,a : add a,a : or b      ; row
        rlca : rlca : rlca : rlca : ld e,a             ; L = row*16
        ld a,c : rrca : rrca : rrca : and 7 : ld hl,bank_base : or (hl)
        out (P_LV),a
        ld a,c : and 7 : or $F8 : ld h,a : ld l,e
        ld a,(.ch) : or a : jr z,.zero
        jp m,.n                                ; 80h+: static art, leave it
        ex de,hl                               ; DE = cell
        sub 32 : ld l,a : ld h,0
        add hl,hl : add hl,hl : add hl,hl : add hl,hl
        ld bc,font : add hl,bc                 ; HL = glyph, DE = cell
        REPT 16
        ldi
        ENDR
        jr .n
.zero:  REPT 16
        ld (hl),a
        inc l
        ENDR
.n:     pop de : pop bc
        dec bc : ld a,b : or c : jp nz,.l
        ret
.ch:    db 0
.mask:  db 0

; A = foreground colour -> colour byte for the playfield (colour or mono)
make_col:
        push hl
        and 15 : ld hl,col_and : and (hl) : inc hl : or (hl)
        pop hl
        ret
; A = colour -> HUD colour byte (black background)
hud_colour:
        push hl
        ld hl,col_and : and (hl)
        ld hl,mono : bit 0,(hl) : jr z,.c : ld a,15
.c:     pop hl
        ret
col_and: db $0F
col_or:  db $00
mono:    db 0

set_colour_mode:                ; from (mono)
        ld a,(mono) : or a : ld hl,$000F : jr z,.c : ld hl,$0F00
.c:     ld a,l : ld (col_and),a : ld a,h : ld (col_or),a
        ret

; ---------------------------------------------------------------------------
; pages
; ---------------------------------------------------------------------------
set_page_vars:
        ld a,(back) : add a,a : add a,a : add a,a : or $80 : ld (bank_base),a
        ld a,(back) : add a,a : add a,a : add a,$F8 : ld (colpage),a
        ld a,(back) : add a,a : add a,a : add a,$F0 : ld (scrpage),a
        ret
; show page (front) - call during vertical blanking
show_front:
        ld a,12 : out ($0C),a : ld a,(front) : add a,a : add a,a : out ($0D),a
        ld a,13 : out ($0C),a : xor a : out ($0D),a
        ret
; finished drawing the back page: wait for the next vertical blank (playing
; sound meanwhile) and show it
present:
        ld hl,(flips) : inc hl : ld (flips),hl
        ld a,MAP_SIM : out ($50),a : ld (cur50),a
        call SIM_SNDX
        call snd_edge
        ld a,(back) : ld (front),a
        call show_front
        ld a,(back) : xor 1 : ld (back),a
        jp set_page_vars

; count vertical blanking edges (game timing) - uses A only
vb_poll:
        in a,($0C) : and $20 : jr z,.lo
        ld a,(vb_state) : or a : ret nz
        inc a : ld (vb_state),a
        ld a,(fields) : inc a : ld (fields),a
        ld a,(snd_min) : or a : ret z
        jp snd_field
.lo:    ld (vb_state),a
        ret

; ---------------------------------------------------------------------------
; frame pacing: game ticks at 25 Hz (every 2nd field) whatever the frame rate
; returns A = ticks due (1..3); waits (with sound) until at least one is due
tick_wait:
.w:     call vb_poll
        ld a,(sim_fields) : ld b,a : ld a,(fields) : sub b
        cp 2 : jr nc,.due
        call snd_edge
        jr .w
.due:   cp 12 : jr c,.ok                ; hopelessly behind: drop the backlog
        ld a,(fields) : sub 2 : ld (sim_fields),a : ld a,2
.ok:    srl a : cp 3 : jr c,.n : ld a,3
.n:     ld b,a
        add a,a : ld c,a : ld a,(sim_fields) : add a,c : ld (sim_fields),a
        ld a,b
        ret

; ---------------------------------------------------------------------------
; 3-voice 1-bit mixer (the original VZ mixer, speaker on PIO B bit 6),
; running until the next rising edge of vertical blanking.  Padded to the
; original sample rate (~16.6 kHz) so pitches match the VZ.
; ---------------------------------------------------------------------------
        MACRO SNDBODY pa, pb, mc, pc
        add hl,de
        ld a,h
pa:     cp 0
        sbc a,a
        and $40
        out ($02),a
        exx
        add hl,de
        add ix,bc
        ld a,h
pb:     cp 0
        sbc a,a
        and $40
        exx
        out ($02),a
mc:     db $DD,$7C,$00          ; ld a,ixh : nop   /  ld a,(ix+0) for noise
pc:     cp 0
        sbc a,a
        and $40
        out ($02),a
        ld a,($0000)            ; padding: 21 T
        nop
        nop
        ENDM
        MACRO SNDBODYC pa, pb, mc, pc
        add hl,de
        ld a,h
pa:     cp 0
        sbc a,a
        and $40
        out ($02),a
        exx
        add hl,de
        add ix,bc
        ld a,h
pb:     cp 0
        sbc a,a
        and $40
        exx
        out ($02),a
mc:     db $DD,$7C,$00          ; ld a,ixh : nop   /  ld a,(ix+0) for noise
pc:     cp 0
        sbc a,a
        and $40
        out ($02),a
        inc bc                  ; count samples (padding: 21 T)
        ld a,0
        nop
        nop
        ENDM

snd_edge:
        push bc : push de : push hl : push ix
        ld a,(fields) : ld (snd_f0),a
        call vb_poll
        ld a,(snd_f0) : ld hl,fields : cp (hl) : jp nz,snd_quick   ; a new blank began
        call snd_apply
        exx
        ld hl,(snd_accB) : ld de,(snd_frqB) : ld bc,(snd_frqC)
        exx
        ld ix,(snd_accC)
        ld hl,(snd_accA) : ld de,(snd_frqA)
        ld bc,(snd_cnt)
        ld a,(vb_state) : or a : jp z,snd_w2      ; not in a blank: wait for one
snd_w1: SNDBODYC pA1, pB1, mC1, pC1
        in a,($0C) : and $20 : jp nz,snd_w1
snd_w2: SNDBODYC pA2, pB2, mC2, pC2
        in a,($0C) : and $20 : jp z,snd_w2
        xor a : out ($02),a
        ld (snd_cnt),bc
        ld (snd_accA),hl : ld (snd_accC),ix
        exx
        ld (snd_accB),hl
        exx
        ld a,1 : ld (vb_state),a
        ld a,(fields) : inc a : ld (fields),a
        ld hl,0 : ld (snd_cnt),hl
        ld a,(snd_min) : or a : call nz,snd_ftick
snd_quick: pop ix : pop hl : pop de : pop bc
        ret
snd_f0: db 0

; channel records (exported by the simulation) -> mixer patches
CH_FRQ equ 3
CH_DUTY equ 7
CH_MODE equ 10
snd_apply:
        ld a,(SND+CH_DUTY) : ld (pA1+1),a : ld (pA2+1),a
        ld hl,(SND+CH_FRQ) : ld (snd_frqA),hl
        ld a,(SND+11+CH_DUTY) : ld (pB1+1),a : ld (pB2+1),a
        ld hl,(SND+11+CH_FRQ) : ld (snd_frqB),hl
        ld a,(SND+22+CH_DUTY) : ld (pC1+1),a : ld (pC2+1),a
        ld hl,(SND+22+CH_FRQ) : ld (snd_frqC),hl
        ld a,(SND+22+CH_MODE) : or a
        ld a,$7C : jr z,.t : ld a,$7E
.t:     ld (mC1+1),a : ld (mC2+1),a : ld (mC3+1),a
        ld a,(SND+CH_DUTY) : ld (pA3+1),a : ld b,a
        ld a,(SND+11+CH_DUTY) : ld (pB3+1),a : or b : ld b,a
        ld a,(SND+22+CH_DUTY) : ld (pC3+1),a : or b
        ld (snd_on),a
        ret
snd_on: db 0
; the effects sequencer steps once per field (50 Hz), here, whatever the
; frame rate, so sweeps and decays keep their shape in busy frames
snd_ftick:
        push bc : push de : push hl : push ix : push iy
        ld a,MAP_SIM : out ($50),a
        call SIM_TICK
        call SIM_SNDX
        call snd_apply
        ld a,(cur50) : out ($50),a
        pop iy : pop ix : pop hl : pop de : pop bc
        ret
cur50:   db MAP_SIM     ; what the lower 32K holds now
snd_cnt: dw 0           ; mixer samples played in this field so far
snd_min: db 0           ; in a game: guarantee every field some sound
SND_MIN equ 40          ; samples per 20 ms field at least (~2.4 ms)

; a new field has begun (in a game): if the field just ended had less than
; SND_MIN samples of an effect, play the rest now.  Effects then sound at
; least every 20 ms, however long the frame takes.  Keeps all but AF.
snd_field:
        call snd_ftick
        ld a,(snd_on) : or a : jr z,.r
        push hl : push de
        ld hl,(snd_cnt) : ld de,SND_MIN : or a : sbc hl,de
        ld a,l : pop de : pop hl
        jr nc,.r
        neg : rrca : rrca : and $3F : jr z,.r     ; shortfall / SLICE
.b:     push af : call snd_slice_go : pop af : dec a : jr nz,.b
        xor a : out ($02),a
.r:     push hl : ld hl,0 : ld (snd_cnt),hl : pop hl
        ret

; snd_keep: called through long page-change work (screen wipe, static art,
; text) so the music keeps playing: the sequencer ticks once per field as
; usual and the mixer gets a short burst each call.  Keeps all but AF.
snd_keep:
        call vb_poll
        ld a,(keep_on) : or a : ret z
        push hl
        ld hl,fields : ld a,(snd_kf) : cp (hl) : jr z,.mix
        ld a,(hl) : ld (snd_kf),a
        ld hl,sim_fields : inc (hl)             ; this field's tick is done here
        push bc : push de : push ix : push iy
        exx : push bc : push de : push hl : exx
        ld a,MAP_SIM : out ($50),a : ld (cur50),a
        call SIM_TICK
        call SIM_SNDX
        call snd_apply
        exx : pop hl : pop de : pop bc : exx
        pop iy : pop ix : pop de : pop bc
.mix:   pop hl
        ld a,(snd_on) : or a : ret z
        ld a,6
.m:     push af : call snd_slice_go : pop af : dec a : jr nz,.m
        ret
keep_on: db 0
snd_kf:  db 0
frame_f0: db 0
sim_pc: db 0

; ---------------------------------------------------------------------------
; snd_slice: a short burst of the mixer (SLICE samples, ~1.2 ms) slipped in
; between drawing steps while an effect is sounding, so sound keeps going
; through the frame instead of only in its idle time.  Keeps all but AF.
; ---------------------------------------------------------------------------
SLICE equ 4
vb_poll_sim:                    ; simulation polls: a burst every 4th call
        call vb_poll
        ld a,(sim_pc) : inc a : ld (sim_pc),a : and 3 : ret nz
snd_slice:
        ld a,(snd_on) : or a : ret z
        ld a,(frame_f0) : push hl : ld hl,fields : cp (hl) : pop hl
        ret nz                                  ; frame running late: no burst
snd_slice_go:
        push bc : push de : push hl : push ix
        ld hl,(snd_cnt) : ld bc,SLICE : add hl,bc : ld (snd_cnt),hl
        exx
        ld hl,(snd_accB) : ld de,(snd_frqB) : ld bc,(snd_frqC)
        exx
        ld ix,(snd_accC)
        ld hl,(snd_accA) : ld de,(snd_frqA)
        ld b,SLICE
snd_w3: SNDBODY pA3, pB3, mC3, pC3
        nop : nop : nop : nop           ; djnz loop matched to 16.6 kHz
        dec b : jp nz,snd_w3
        ld (snd_accA),hl : ld (snd_accC),ix
        exx
        ld (snd_accB),hl
        exx
        pop ix : pop hl : pop de : pop bc
        ret

; ---------------------------------------------------------------------------
; input: keyboard (light pen scan), Microbee joystick on PIO A
; bits: 0 left 1 right 2 thrust 3 fire 4 hyperspace 5 bomb 6 start
; ---------------------------------------------------------------------------
read_input:
        ld a,1 : out ($0B),a
        ld c,0
        ; six redefinable actions, each with a fixed alternative key
        ld hl,keymap : ld b,1
.k:     ld a,(hl) : call keytest : jr nz,.on
        inc hl : ld a,(hl) : dec hl : cp $FF : jr z,.nx
        call keytest : jr z,.nx
.on:    ld a,c : or b : ld c,a
.nx:    inc hl : inc hl
        sla b : ld a,b : cp $40 : jr nz,.k
        ld a,$34 : call keytest : jr nz,.s1       ; RETURN
        ld a,$21 : call keytest : jr z,.j         ; 1
.s1:    set 6,c
.j:     ; joystick: active low on PIO A
        in a,($00) : cpl : ld b,a : and 15 : cp 15 : jr z,.done   ; nothing fitted
        ld a,b : and 3 : cp 3 : jr z,.done
        bit 2,b : jr z,$+4 : set 0,c
        bit 3,b : jr z,$+4 : set 1,c
        bit 0,b : jr z,$+4 : set 2,c
        bit 1,b : jr z,$+4 : set 5,c
        bit 7,b : jr z,$+4 : set 3,c
        bit 4,b : jr z,$+4 : set 6,c
        bit 5,b : jr z,$+4 : set 4,c
.done:  xor a : out ($0B),a
        ld a,(in_last) : cpl : and c : ld (in_new),a
        ld a,c : ld (in_last),a : ld (INPUT_BITS),a
        ret

; action keys: (redefinable key, fixed alternative or FFh)
; left, right, thrust, fire, hyperspace, smart bomb
keymap:
        db 21,$3B               ; U      / cursor left
        db 9,$3E                ; I      / cursor right
        db 15,$38               ; O      / cursor up
        db $37,26               ; SPACE  / Z
        db 16,$FF               ; P
        db 2,$3A                ; B      / cursor down

; A = Microbee key code -> NZ if held
keytest:
        push bc
        ld b,a
        ld a,$10 : out ($0C),a : in a,($0D)
        ld a,$11 : out ($0C),a : in a,($0D)
        ld a,$12 : out ($0C),a
        ld a,b : rrca : rrca : rrca : rrca : and 3 : out ($0D),a
        ld a,$13 : out ($0C),a
        ld a,b : rlca : rlca : rlca : rlca : and $F0 : out ($0D),a
        ld a,$1F : out ($0C),a : out ($0D),a
        nop : ld b,0
.wait:  in a,($0C) : bit 7,a : jr nz,.ready : djnz .wait
.ready: and $40
        pop bc
        ret
; scan one key with edge detect: A = code, HL -> state byte. NZ on press
key_edge:
        call keytest
        ld a,0 : jr z,.u : inc a
.u:     cp (hl) : ld (hl),a : ret z
        or a
        ret

; ---------------------------------------------------------------------------
; RENDERER
; ---------------------------------------------------------------------------
render:
        call erase_dirty
        call erase_pixels
        call vb_poll
        call draw_stars
        call draw_particles
        call pix_close
        call draw_sprites
        call draw_overlays
        call text_redraw
        call hud_restore
        ld a,MAP_SIM : out ($50),a : ld (cur50),a
        ld a,$80 : out (P_LV),a
        ret

; ---- erase everything drawn in this page last time
erase_dirty:
        ld a,(back) : or a : ld ix,dirty0 : ld hl,dcount0 : jr z,.p
        ld ix,dirty1 : ld hl,dcount1
.p:     ld a,(hl) : ld (hl),0 : or a : ret z
        ld b,a
.e:     push bc
        call vb_poll
        ld a,b : and 1 : call z,snd_slice
        ld a,(ix+0) : out ($50),a : ld (cur50),a
        ld a,(ix+1) : ld (cur_bank),a : out (P_LV),a
        ld h,(ix+2) : ld c,(ix+3) : ld b,(ix+4)
        ld e,(ix+5) : ld d,(ix+6)
        ld a,c : ld (d_y0),a : ld a,b : ld (d_cols),a : ld a,(ix+7) : ld (d_h),a
        ld a,(ix+1) : and 7 : rlca : rlca : rlca : ld l,a : ld a,h : and 7 : or l : ld (d_col),a
.col:   ld a,(de) : inc de : add a,c : ld l,a           ; first row
        ld a,(de) : inc de : ld (.cc+1),a               ; erase_chain entry
        xor a
.cc:    call erase_chain
.nx:    inc h : call z,next_bank
        djnz .col
        ; erased pixels under text must be redrawn: only rows holding text
        ; (row_prot) need the paint pass.  Cell colours are left as they
        ; are: every dot and sprite paints its own cells.
        ld a,(d_y0) : ld l,a : and 15 : add a,(ix+7) : add a,15
        rrca : rrca : rrca : rrca : and 15 : ld b,a
        ld a,l : rrca : rrca : rrca : rrca : and 15 : ld c,a
.pc:    ld a,c : add a,low row_prot : ld l,a : ld h,high row_prot : ld a,(hl)
        or a : jr nz,.pp
        ld a,c : inc a : and 15 : ld c,a : djnz .pc
        jr .pd
.pp:    xor a : ld (paint_rows),a
        call paint_rect
.pd:
        ld de,8 : add ix,de
        pop bc
        dec b : jp nz,.e
        ret

; ---- dots (particles, bullets, stars): (bank, H, L) entries, two lines each
erase_pixels:
        call vb_poll
        ld a,(back) : or a : ld hl,PIXL0 : ld de,(pix_end0) : jr z,.p
        ld hl,PIXL1 : ld de,(pix_end1)
.p:     ld (pix_ptr),hl
.e:     ld a,l : cp e : jr nz,.go
        ld a,h : cp d : ret z
.go:    ld a,(hl) : out (P_LV),a : inc hl
        ld b,(hl) : inc hl : ld c,(hl) : inc hl
        xor a : ld (bc),a : inc c : ld (bc),a
        jr .e
pix_close:
        ld hl,(pix_ptr)
        ld a,(back) : or a : jr nz,.b
        ld (pix_end0),hl : ret
.b:     ld (pix_end1),hl : ret

; A = x/2 (0..255), E = y, C = colour (0 = leave the cell colour),
; B = 0 two-pixel dot (2 lines) / 1 one-pixel dot (1 line).
; Dots are hidden behind text (and the HUD), never drawn into it.
plot_dot:
        ld d,a
        rrca : rrca : and 63 : ld l,a                   ; column
        ld a,e : and 15 : cp 15 : jr nz,.r : ld b,1     ; don't cross a cell row
.r:     ld a,e : and $30 : rlca : rlca : or l : ld l,a
        ld a,e : rlca : rlca : and 3 : or high TEXT_MAP : ld h,a
        ld a,(hl) : or a : ret nz                       ; text: hidden
        push hl                                         ; cell
        ld a,d : rlca : rlca : rlca : and 7 : ld h,a    ; column / 8
        ld a,(bank_base) : or h : out (P_LV),a
        ld hl,(pix_ptr) : ld (hl),a : inc hl
        ld a,d : rrca : rrca : and 7 : or $F8 : ld (hl),a : inc hl
        ld (hl),e : inc hl : ld (pix_ptr),hl
        ld h,a : ld l,e                                 ; bitmap byte
        ld a,d : and 3 : add a,a : add a,b : add a,low dot_masks
        ld e,a : ld d,high dot_masks : ld a,(de)
        ld d,a : or (hl) : ld (hl),a
        djnz .two                                       ; B = 0: two lines
        jr .col
.two:   inc l : ld a,d : or (hl) : ld (hl),a
.col:   pop hl
        ld a,c : or a : ret z
        ld a,h : and 3 : ld h,a : ld a,(colpage) : add a,h : ld h,a
        ld a,(col_and) : and c : ld c,a : ld a,(col_or) : or c : ld c,a
        ld a,$40 : out (P_COLR),a
        ld (hl),c
        xor a : out (P_COLR),a
        ret
dot_hi: db 0
dot_lo: db 0
dot_col: db 0
dot_mask_src: db $C0,$80, $30,$20, $0C,$08, $03,$02

; ---- particles and bullets from the export list
draw_particles:
        ld a,(PCOUNT) : or a : ret z : ld b,a
        ld hl,PLIST
.p:     push bc
        ld a,b : and 3 : call z,vb_poll
        ld a,b : and 7 : call z,snd_slice
        ld a,(hl) : inc hl : ld e,(hl) : inc hl : ld c,(hl) : inc hl
        push hl
        ld b,0 : call plot_dot
        pop hl
        pop bc : djnz .p
        ret

; ---- parallax star field: 12 near (2 px) and 12 far (1 px) stars
N_STARS equ 12
stars_init:
        ld hl,star_x : ld b,N_STARS*4
.s:     call srand : ld (hl),a : inc hl
        djnz .s
        ret
srand:  push hl
        ld hl,(seed) : ld a,h : rra : ld a,l : rra : xor h : ld h,a
        ld a,l : rra : ld a,h : rra : xor l : ld l,a : xor h : ld h,a
        ld (seed),hl
        pop hl
        ret
seed:   dw $5A3C
star_cols: db 15,14,11,13            ; near stars: white, cyan, yellow, pink
STAR_FAR equ 8                       ; far stars / empty space: dark grey

; drift opposite the ship's velocity (8.8 VZ units per tick).  x is kept in
; px/2 units, y in pixels: near stars move at half the ship's apparent speed,
; far ones at an eighth.  Once per tick.
stars_move:
        ld hl,(ST_VX) : call neg_hl : ld (sdx),hl
        ld hl,(ST_VY) : call neg_hl : add hl,hl : ld (sdy),hl
        ld de,(sdx) : ld hl,star_x : call .add12
        call .quarter : call .add12
        ld de,(sdy) : call .add12
        call .quarter
.add12: ld b,N_STARS/2
.a:     ld a,(hl) : add a,e : ld (hl),a : inc hl
        ld a,(hl) : adc a,d : ld (hl),a : inc hl
        djnz .a
        ret
.quarter:
        sra d : rr e : sra d : rr e
        ret
neg_hl: xor a : sub l : ld l,a : sbc a,a : sub h : ld h,a
        ret
sdx:    dw 0
sdy:    dw 0

draw_stars:
        ld a,(stars_on) : or a : ret z
        ld a,STAR_FAR : call make_col : ld (.fc+1),a
        ld hl,star_x+1 : ld b,N_STARS
.s:     push bc : push hl
        ld a,b : and 3 : call z,vb_poll
        ld a,b : cp N_STARS/2+1 : ld b,0 : jr nc,.near : inc b
.near:  ld de,N_STARS*2 : add hl,de : ld e,(hl)
        ld a,e : cp 16 : jr c,.n                  ; under the HUD
        pop hl : push hl : ld a,(hl)
.fc:    ld c,0 : dec b : jr z,.far
        ld a,l : rrca : and 3 : add a,low star_cols : push hl : ld l,a : ld h,high star_cols : jr nc,$+3 : inc h
        ld c,(hl) : pop hl : ld a,(hl)
.far:   inc b
        call plot_dot
.n:     pop hl : inc hl : inc hl
        pop bc : djnz .s
        ret

; ---- sprites from the display list
draw_sprites:
        ld a,(back) : or a : ld iy,dirty0 : jr z,.p : ld iy,dirty1
.p:     xor a : ld (dcount),a
        ld a,(DCOUNT) : or a : jr z,.done
        ld b,a : ld ix,DLIST
.s:     push bc
        call vb_poll
        call snd_slice
        ld a,(dcount) : cp DIRTY_MAX : jr nc,.skip
        call draw_one
.skip:  ld de,5 : add ix,de
        pop bc : djnz .s
.done:  ld a,(back) : or a : ld hl,dcount0 : jr z,.q : ld hl,dcount1
.q:     ld a,(dcount) : ld (hl),a
        ret

draw_one:
        ld l,(ix+3) : ld h,0 : add hl,hl : ld de,spr_ptr : add hl,de
        ld a,(hl) : inc hl : ld h,(hl) : ld l,a
        ld a,(hl) : ld (d_cols),a : inc hl
        ld a,(hl) : ld (d_h),a : inc hl
        ld e,(hl) : inc hl                          ; half width
        ld a,(ix+2) : sub (hl) : ld (d_y0),a : inc hl
        push hl
        ld a,(ix+0) : sub e : ld e,a
        ld a,(ix+1) : sbc a,0 : and 1 : ld d,a      ; DE = x0 (0..511)
        ld a,e : rrca : and 3 : ld c,a              ; shift
        ld a,e : rrca : rrca : rrca : and 31
        bit 0,d : jr z,$+4 : or 32
        ld (d_col),a
        pop hl
        ld a,c : add a,a : add a,a : add a,c : ld e,a : ld d,0 : add hl,de
        ld a,(hl) : out ($50),a : ld (cur50),a : ld (iy+0),a : inc hl
        ld e,(hl) : inc hl : ld d,(hl) : inc hl
        ld (.call+1),de
        ld a,(hl) : ld (iy+5),a : inc hl : ld a,(hl) : ld (iy+6),a
        ld a,(d_col) : ld c,a
        rrca : rrca : rrca : and 7 : ld hl,bank_base : or (hl)
        ld (cur_bank),a : out (P_LV),a : ld (iy+1),a
        ld a,c : and 7 : or $F8 : ld h,a : ld (iy+2),a
        ld a,(d_y0) : ld l,a : ld c,a : ld (iy+3),a
        ld a,(d_cols) : ld (iy+4),a
.call:  call 0
        ld de,8 : add iy,de
        ld hl,dcount : inc (hl)
        ld a,(d_h) : ld (iy-1),a
        ; ---- paint the character cells it covers
        ld a,(ix+4) : rrca : rrca : rrca : rrca : and 15 : jr nz,.c2 : ld a,(ix+4)
.c2:    call make_col : ld (col2),a
        ld a,(ix+4) : call make_col : ld e,a
        ld a,16 : ld (paint_rows),a
; paint_rect: colour the cells of d_col/d_cols x d_y0/d_h: E for the top
; row, col2 below, only the first (paint_rows) rows.  Text cells are never
; coloured; any text cell the rectangle touches is queued for redraw.
paint_rect:
        ld a,(d_y0) : and 15 : ld hl,d_h : add a,(hl) : add a,15
        rrca : rrca : rrca : rrca : and 15 : ld b,a        ; rows
        ld a,(d_y0) : rrca : rrca : rrca : rrca : and 15 : ld c,a
        ld a,(paint_rows) : ld (.left),a
        ld a,(d_cols) : add a,a : ld l,a : ld a,low erase_chain_end : sub l : ld l,a
        ld a,high erase_chain_end : sbc a,0 : ld h,a : ld (.uj+1),hl
        ld a,(d_col) : ld d,a : ld a,(d_cols) : add a,d : ld l,a : dec a : ld (.last),a
        ld a,l : cp 65 : sbc a,a : ld (.nowrap),a
        ld a,$40 : out (P_COLR),a
.row:   ld a,c : or a : jr nz,.r1
        ; the HUD row: never coloured; the HUD columns under the rectangle
        ; are flagged and redrawn in one pass after the sprites
        call hud_mark
        jp .next
.r1:    add a,low row_prot : ld l,a : ld h,high row_prot : ld a,(hl)
        or a : jr z,.free
        ; a row with text: does the rectangle reach its text span?
        ld a,(.nowrap) : or a : jr z,.addr
        ld a,c : add a,low ROW_HI : ld l,a : ld a,(d_col) : cp (hl) : jr z,.addr : jr nc,.free
        ld a,c : add a,low ROW_LO : ld l,a : ld a,(.last) : cp (hl) : jr nc,.addr
.free:  ld a,(.left) : or a : jr z,.next                   ; nothing to do here
        ld a,(.nowrap) : or a : jr z,.addr
        ; ordinary row, no wrap: unrolled stores
        ld a,c : rrca : rrca : ld h,a : and $C0 : ld l,a : ld a,(d_col) : or l : ld l,a
        ld a,h : and 3 : ld h,a : ld a,(colpage) : add a,h : ld h,a
        ld a,e
.uj:    call erase_chain_end
        jr .next
.addr:  push bc
        ld a,c : rrca : rrca : and $C0 : ld d,a            ; row low bits
        ld a,(d_col) : or d : ld l,a
        ld a,c : rrca : rrca : and 3 : ld h,a : ld a,(colpage) : add a,h : ld h,a
        ld a,(d_cols) : ld b,a
        ld a,c : add a,low row_prot : push hl : ld l,a : ld h,high row_prot : ld a,(hl) : pop hl
        or a : jr nz,.sc
.cell:  ld (hl),e
        ld a,l : inc a : and 63 : or d : ld l,a
        djnz .cell
        jr .rowd
.sc:    ; row with text: queue text cells, colour the others
        push hl : ld a,h : and 3 : or high TEXT_MAP : ld h,a : ld a,(hl) : pop hl
        or a : jr z,.nt
        push hl : ld a,h : and 3 : ld h,a : call tq_back : pop hl
        jr .sk
.nt:    ld a,(.left) : or a : jr z,.sk
        ld (hl),e
.sk:    ld a,l : inc a : and 63 : or d : ld l,a
        djnz .sc
.rowd:  pop bc
.next:  ld a,c : inc a : and 15 : ld c,a
        ld a,(col2) : ld e,a
        ld a,(.left) : or a : jr z,.lz : dec a : ld (.left),a
.lz:    dec b : jp nz,.row
        xor a : out (P_COLR),a
        ret
.nowrap: db 0
.last:  db 0
.left:  db 0
paint_rows: db 16
; flag HUD columns d_col.. (d_cols of them, wrapping) on the back page
hud_mark:
        push bc
        ld hl,HUD_ANY : ld a,(back) : or a : jr z,$+3 : inc l : ld (hl),1
        ld h,high HUD_R0 : jr z,$+3 : inc h
        ld a,(d_cols) : ld b,a
        ld a,(d_col) : ld c,low HUD_R0
.m:     and 63 : or c : ld l,a : ld (hl),c : inc a : djnz .m      ; nonzero flag
        pop bc
        ret
; redraw the flagged HUD cells of the back page from the text layer
hud_restore:
        ld a,(back) : or a : ld hl,HUD_ANY : jr z,$+3 : inc l
        ld a,(hl) : or a : ret z
        ld (hl),0
        ld a,(back) : or a : ld h,high HUD_R0 : jr z,$+3 : inc h
        ld l,low HUD_R0 : ld c,0
.c:     ld a,(hl) : or a : jr nz,.go
.n:     inc l : inc c : bit 6,c : jr z,.c
        ret
.go:    ld (hl),0
        push hl : push bc
        call vb_poll                                    ; every cell (~350 T)
        ld a,c : rrca : rrca : rrca : and 7 : ld hl,bank_base : or (hl) : out (P_LV),a
        ld l,c : ld h,high TEXT_MAP : ld b,(hl)         ; character
        ld a,c : and 7 : or $F8 : ld d,a : ld e,0       ; DE = HUD cell bitmap
        ld a,b : or a : jr z,.z
        jp m,.x                                         ; static art: leave
        sub 32 : ld l,a : ld h,0
        add hl,hl : add hl,hl : add hl,hl : add hl,hl
        ld bc,font : add hl,bc
        REPT 16
        ldi
        ENDR
        jr .x
.z:     ex de,hl
        REPT 16
        ld (hl),a
        inc l
        ENDR
.x:     pop bc : pop hl
        jp .n

; ---------------------------------------------------------------------------
; text overlays (banners): up to 3 requested lines per frame; a line is
; rewritten in the text layer only when it changes
; ---------------------------------------------------------------------------
draw_overlays:
        ld ix,ovl_req : ld iy,ovl_cur : ld b,3
.s:     push bc
        ; build the requested line into ovl_tmp (empty if none)
        ld de,ovl_tmp : xor a : ld (de),a
        ld a,(ix+0) : or a : jr z,.cmp
        ld l,(ix+2) : ld h,(ix+3) : ld b,31
.cp:    ld a,(hl) : ld (de),a : or a : jr z,.cmp : inc hl : inc de : djnz .cp
        xor a : ld (de),a
.cmp:   ; same row, colour and text as now?
        ld a,(ix+0) : cp (iy+0) : jr nz,.chg
        ld a,(ix+1) : cp (iy+1) : jr nz,.chg
        push iy : pop hl : ld de,2 : add hl,de : ld de,ovl_tmp
.c2:    ld a,(de) : cp (hl) : jr nz,.chg : or a : jr z,.next : inc hl : inc de : jr .c2
.chg:   ; clear the old line
        ld a,(iy+0) : or a : jr z,.new
        ld b,a : push iy : pop hl : inc hl : inc hl : xor a : ld c,a : call text_line
.new:   ld a,(ix+0) : ld (iy+0),a : ld a,(ix+1) : ld (iy+1),a
        push iy : pop de : inc de : inc de : ld hl,ovl_tmp : ld bc,32 : ldir
        ld a,(ix+0) : or a : jr z,.next
        ld b,a : ld c,(ix+1) : push iy : pop hl : inc hl : inc hl : ld a,1 : call text_line
.next:  ld de,4 : add ix,de : ld de,34 : add iy,de
        pop bc : dec b : jp nz,.s
        ret
; centred line at row B: HL = text, C = colour, A = 1 write / 0 clear
text_line:
        ld (.mode),a
        push hl : ld e,0
.n:     ld a,(hl) : or a : jr z,.e : inc e : inc hl : jr .n
.e:     pop hl
        ld a,64 : sub e : srl a : ld e,a
        ld a,(.mode) : or a : jp nz,text_at
        ; clear: same cells, character 0
.cl:    ld a,(hl) : or a : ret z
        call vb_poll
        push hl : call cell_of : xor a : call text_set : pop hl
        inc hl : inc e : jr .cl
.mode:  db 0
; B = row, E = column -> HL = cell index (keeps BC, DE)
cell_of:
        ld a,b : rrca : rrca : and $C0 : or e : ld l,a
        ld a,b : rrca : rrca : and 3 : ld h,a
        ret

; ---------------------------------------------------------------------------
; static text (front-end pages)
; HL = text, B = row, C = colour
; ---------------------------------------------------------------------------
text_centre:
        push hl : ld e,0
.l:     ld a,(hl) : or a : jr z,.e : inc e : inc hl : jr .l
.e:     pop hl
        ld a,64 : sub e : srl a : ld e,a
text_at:                ; HL = text, B = row, E = column, C = colour
        ld a,1 : ld (text_rows),a
.w:     ld a,(hl) : or a : ret z
        ld a,e : and 3 : call z,snd_keep
        call vb_poll
        ld a,(hl)
        push hl : push af : call cell_of : pop af : call text_set : pop hl
        inc hl : inc e : jr .w

; ---------------------------------------------------------------------------
; HUD (screen row 0, both pages, character ROM)
; ---------------------------------------------------------------------------
hud_cols:       ; colour per column: grey labels, white values, cyan accents
        db 7,7,7,7,7,7, 15,15,15,15,15,15, 0,0
        db 7,7,7, 14,14,14,14,14,14, 0,0
        db 7,7,7,7,7, 15,15, 0,0
        db 7,7,7,7,7,7, 15, 0,0
        db 7,7,7,7,7,7, 15, 0
        db 14,14,14,14,14,14, 0
        db 7,7,7,7,7, 15
        ASSERT $-hud_cols == 64
hud_text:
        db "SCORE 000000  HI 000000  WAVE 01  SHIPS 3  BOMBS 3 "
        db "      "," ","SHLD 0"
        ASSERT $-hud_text == 64
hud_last: ds 12,$FF

hud_update:
        ld a,(hud_force) : or a : jr nz,.go
        ; live high score
        ld hl,ST_SCORE : ld de,hi_score : ld b,3
.hc:    ld a,(de) : cp (hl) : jr c,.hi : jr nz,.hn
        inc hl : inc de : djnz .hc
        jr .hn
.hi:    ld hl,ST_SCORE : ld de,hi_score : ld bc,3 : ldir
.hn:    ld hl,STATUS : ld de,hud_last : ld b,9
.cmp:   ld a,(de) : cp (hl) : jr nz,.go
        inc hl : inc de : djnz .cmp
        ld hl,hi_score : ld b,3
.cmh:   ld a,(de) : cp (hl) : jr nz,.go
        inc hl : inc de : djnz .cmh
        ret
.go:    xor a : ld (hud_force),a
        ld hl,STATUS : ld de,hud_last : ld bc,9 : ldir
        ld hl,hi_score : ld bc,3 : ldir
        ld hl,ST_SCORE : ld de,hud_text+6 : call bcd6
        ld hl,hi_score : ld de,hud_text+17 : call bcd6
        ld a,(ST_WAVE) : ld de,hud_text+30 : call bcd2
        ld a,(ST_LIVES) : cp 10 : jr c,$+4 : ld a,9 : add a,'0' : ld (hud_text+40),a
        ld a,(ST_BOMBS) : cp 10 : jr c,$+4 : ld a,9 : add a,'0' : ld (hud_text+49),a
        ld a,(ST_SHIELD) : cp 10 : jr c,$+4 : ld a,9 : add a,'0' : ld (hud_text+63),a
        ld a,(ST_WEAPON) : ld hl,txt_wnone : or a : jr z,.w
        ld hl,txt_wspread : dec a : jr z,.w : ld hl,txt_wrapid
.w:     ld de,hud_text+51 : ld bc,6 : ldir
        ld hl,hud_text : ld de,hud_cols : ld b,0
.t:     push bc : push hl
        ld a,(de) : ld c,a : ld a,(hl)
        ld l,b : ld h,high TEXT_MAP : cp (hl) : jr z,.same   ; unchanged
        ld h,0 : call text_set
        call vb_poll
.same:  pop hl : pop bc
        inc hl : inc de : inc b : ld a,b : cp 64 : jr nz,.t
        ret
hud_force: db 1
txt_wnone:   db "      "
txt_wspread: db "SPREAD"
txt_wrapid:  db "RAPID "
; HL -> 3 BCD bytes, DE -> 6 chars
bcd6:   ld b,3
.l:     ld a,(hl) : inc hl : call bcd2 : djnz .l
        ret
bcd2:   push af : rrca : rrca : rrca : rrca : and 15 : add a,'0' : ld (de),a : inc de
        pop af : and 15 : add a,'0' : ld (de),a : inc de
        ret

; ---------------------------------------------------------------------------
; one complete frame of the running game / demo
; ---------------------------------------------------------------------------
; tick the simulation A times
sim_ticks:
        ld b,a
.t:     push bc
        call vb_poll
        call SIM_STEP                   ; (sound steps per field: snd_ftick)
        call stars_move
        ld hl,(ticks) : inc hl : ld (ticks),hl
        pop bc
        djnz .t
        ret

clear_ovl_req:
        ld hl,ovl_req : ld b,12
.c:     ld (hl),0 : inc hl : djnz .c
        ret
; A = slot (0..2), B = row, C = colour, HL = text
ovl_set:
        push hl
        add a,a : add a,a : ld e,a : ld d,0 : ld hl,ovl_req : add hl,de
        ld (hl),b : inc hl : ld (hl),c : inc hl
        pop de : ld (hl),e : inc hl : ld (hl),d
        ret

game_overlays:
        call clear_ovl_req
        ld a,(ST_BANNER) : or a : jr z,.nb
        ld hl,ST_BTEXT : ld b,6 : ld c,11 : xor a : call ovl_set
.nb:    ld a,(ST_GOVER) : or a : jr z,.ng
        ld hl,txt_gameover : ld b,7 : ld c,9 : ld a,1 : call ovl_set
.ng:    ld a,(ST_DEMO) : or a : ret z
        ld a,(ST_FRAME) : and 32 : ret z
        ld hl,txt_demo : ld b,14 : ld c,9 : ld a,2 : jp ovl_set
txt_gameover: db "G A M E   O V E R",0
txt_demo:     db "DEMO  -  PRESS FIRE TO PLAY",0

; ---------------------------------------------------------------------------
; PLAY
; ---------------------------------------------------------------------------
play:
        call SIM_MUSOFF
        xor a : call SIM_NEWGAME
        call stars_init
        ld a,1 : ld (stars_on),a : ld (hud_force),a : ld (snd_min),a
.loop:  call tick_wait
        push af : ld a,(fields) : ld (frame_f0),a : call read_input : pop af
        call sim_ticks
        call SIM_SNDX : call snd_apply          ; effects as of this tick
        call SIM_EXPORT
        call game_overlays
        call hud_update
        call render
        call present
        ld a,(ST_DONE) : or a : jr z,.loop
        xor a : ld (snd_min),a
        call hs_check
        jp attract

; ---------------------------------------------------------------------------
; ATTRACT: title over a live demo, enemy files, treasure, high scores
; ---------------------------------------------------------------------------
attract:
        call reset_screen
        ld a,(music_on) : or a : call nz,SIM_MUSON
.cycle: call title_page : jr c,.start
        call controls_page : jr c,.start
        call roster_page : jr c,.start
        call treasure_page : jr c,.start
        call demo_page : jr c,.start
        call scores_page : jr c,.start
        jr .cycle
.start: ld a,(want_keys) : or a : jr z,.play
        xor a : ld (want_keys),a
        call define_keys
        jr attract
.play:  call reset_screen
        jp play

; wipe both pages (dirty lists drawn away) and rebuild the screen map
reset_screen:
        ld a,1 : ld (keep_on),a
        ld a,(fields) : ld (snd_kf),a
        xor a : ld (DCOUNT),a : ld (PCOUNT),a
        call clear_ovl_req
        call wipe_pages                 ; both bitmaps blank, nothing to erase
        call set_colour_mode
        call text_reset
        ld a,$40 : out (P_COLR),a       ; colour RAM: far-star grey
        ld a,STAR_FAR : call make_col
        ld hl,$F800 : ld de,$F801 : ld bc,$7FF : ld (hl),a : ldir
        xor a : out (P_COLR),a
        ld (keep_on),a
        ld a,1 : ld (hud_force),a
        ret

; clear all 32K of PCG (both pages' bitmaps) with PUSH, 1K at a time, and
; forget everything that was drawn
wipe_pages:
        ld c,$80
.b:     ld a,c : out (P_LV),a
.h:     ld (.save+1),sp
.top:   ld sp,0
        ld hl,0 : ld e,32
.p:     REPT 16
        push hl
        ENDR
        dec e : jr nz,.p
.save:  ld sp,0
        call snd_keep
        ld a,(.top+2) : xor $FC : ld (.top+2),a     ; FFFF-FC00, then FBFF-F800
        jr nz,.h
        inc c : ld a,c : cp $90 : jr nz,.b
        ld a,$80 : out (P_LV),a
        xor a : ld (dcount0),a : ld (dcount1),a
        ld hl,PIXL0 : ld (pix_end0),hl : ld (pix_ptr),hl
        ld hl,PIXL1 : ld (pix_end1),hl
        ld hl,HUD_ANY : ld (hl),a : inc l : ld (hl),a
        ret

; drop all text without redrawing it (the bitmaps have been wiped)
text_reset:
        ld hl,TEXT_MAP : ld de,TEXT_MAP+1 : ld bc,1023 : ld (hl),0 : ldir
        ld hl,tqf : ld de,tqf+1 : ld bc,1023 : ld (hl),0 : ldir
        ld hl,0 : ld (tqn0),hl : ld (tqn1),hl
        jp text_clear                   ; (nothing left to queue) rows, spans, overlays

; front-end keys: C colour/mono, M music. Carry = start pressed
front_keys:
        ld a,1 : out ($0B),a
        ld a,3 : ld hl,k_c : call key_edge : jr z,.m
        xor a : out ($0B),a             ; release the character ROM latch first
        ld a,(mono) : xor 1 : ld (mono),a
        call set_colour_mode : call screen_map : call page_redraw
        ld a,1 : ld (hud_force),a
.m:     ld a,1 : out ($0B),a
        ld a,13 : ld hl,k_m : call key_edge : jr z,.s
        xor a : out ($0B),a
        ld a,(music_on) : xor 1 : ld (music_on),a
        or a : jr z,.off
        call SIM_MUSON : jr .s
.off:   call SIM_MUSOFF
.s:     ld a,1 : out ($0B),a
        ld a,11 : ld hl,k_k : call key_edge : jr z,.s2   ; K: define keys
        xor a : out ($0B),a
        ld a,1 : ld (want_keys),a
        scf
        ret
.s2:    xor a : out ($0B),a
        call read_input
        ld a,(in_new) : and $48
        ret z
        scf
        ret
k_c:    db 0
k_m:    db 0
k_k:    db 0
k_s:    db 0
want_keys: db 0
page_redraw:
        ld hl,(page_texts) : ld a,h : or l : ret z
        jp (hl)
page_texts: dw 0

; generic front page loop: HL = per-tick routine, DE = text routine, A = ticks
page_run:
        ld (page_len),a
        ld (page_tick),hl
        ld (page_texts),de
        call reset_screen
        ld a,1 : ld (keep_on),a
        call page_redraw
        xor a : ld (keep_on),a
        ld a,1 : ld (hud_force),a
.loop:  call tick_wait
        ld b,a : ld a,(fields) : ld (frame_f0),a
.t:     push bc
        call front_keys : jr c,.go
        call SIM_TICK : call SIM_TICK
        ld hl,(page_tick) : call jp_hl
        call stars_move
        pop bc
        ld hl,page_len : dec (hl) : jr z,.end
        djnz .t
        call hud_update
        call render
        call present
        jr .loop
.go:    pop bc
        scf
        ret
.end:   or a
        ret
jp_hl:  jp (hl)
page_len:  db 0
page_tick: dw 0

; ---- title: chrome logo (drawn once, static) over a drifting star field;
; the page is nearly idle so the title music plays at full quality
title_page:
        ld a,1 : ld (stars_on),a
        call stars_init
        ld hl,title_tick : ld de,title_texts : ld a,250
        jp page_run
title_texts:
        ld hl,logo_list : call draw_static
        ld hl,txt_t1 : ld b,8 : ld c,7 : call text_centre
        ld hl,txt_t2 : ld b,13 : ld c,6 : call text_centre
        ld hl,txt_t3 : ld b,15 : ld c,8 : call text_centre
        ret
title_tick:
        xor a : ld (DCOUNT),a : ld (PCOUNT),a
        ld hl,$0040 : ld (ST_VX),hl : ld hl,$0010 : ld (ST_VY),hl   ; gentle drift
        call clear_ovl_req
        ld a,(page_len) : and 16 : ret z
        ld hl,txt_press : ld b,10 : ld c,15 : xor a : jp ovl_set
read_input_demo:
        xor a : ld (INPUT_BITS),a : ret
txt_t1:    db "~ THE ROCKS ARE BACK ~",0
txt_press: db "PRESS FIRE TO PLAY",0
txt_t2:    db "M MUSIC     C MONO     K DEFINE KEYS",0
txt_t3:    db "VIBED BY BPM 2026   ORIGINAL VZ300 BY DUBOIS + MCNAMARA",0

; ---- demo: the computer plays (silently - the music pauses)
demo_page:
        call SIM_MUSOFF
        ld a,1 : call SIM_NEWGAME
        ld a,1 : ld (stars_on),a
        call stars_init
        ld hl,demo_tick : ld de,0 : ld a,0          ; 256 ticks (~10 s)
        call page_run
        push af
        ld a,(music_on) : or a : call nz,SIM_MUSON
        pop af
        ret
demo_tick:
        call read_input_demo
        call SIM_STEP
        call SIM_EXPORT
        jp game_overlays

; draw a list (count, 6-byte entries x,x,y,spr,col,frames) permanently into
; both pages and protect its cells (TEXT_MAP 80h) from dots and colour
draw_static:
        ld (.list),hl
        xor a : ld (DCOUNT),a
        ld de,DLIST : ld b,(hl) : inc hl
.c:     push bc : ld bc,5 : ldir : inc hl : pop bc
        ld a,(DCOUNT) : inc a : ld (DCOUNT),a
        djnz .c
        ld a,(back) : push af
        xor a : call .page
        ld a,1 : call .page
        pop af : ld (back),a : call set_page_vars
        ; protect: TEXT_MAP cells under each drawn rectangle
        ld ix,static_rects : ld a,(DCOUNT) : ld b,a
.p:     push bc
        ld a,(ix+2) : and 15 : add a,(ix+3) : add a,15
        rrca : rrca : rrca : rrca : and 15 : ld b,a            ; rows
        ld a,(ix+2) : rrca : rrca : rrca : rrca : and 15 : ld c,a
.pr:    push bc
        ld a,c : rrca : rrca : and $C0 : or (ix+0) : ld l,a
        ld a,c : rrca : rrca : and 3 : or high TEXT_MAP : ld h,a
        ld b,(ix+1)
.pc:    ld a,(hl) : or a : jr nz,$+4 : ld (hl),$80
        ld a,l : and $C0 : ld e,a : ld a,l : inc a : and 63 : or e : ld l,a
        djnz .pc
        pop bc
        ld a,c : inc a : and 15 : ld c,a
        djnz .pr
        ld de,4 : add ix,de
        pop bc : djnz .p
        xor a : ld (DCOUNT),a
        ret
.page:  ld (back),a : call set_page_vars
        ld ix,DLIST : ld hl,static_rects : ld (.rp),hl
        ld a,(DCOUNT) : ld b,a
.d:     push bc
        call snd_keep
        ld iy,static_dirty
        call draw_one
        ld hl,(.rp)
        ld a,(d_col) : ld (hl),a : inc hl : ld a,(d_cols) : ld (hl),a : inc hl
        ld a,(d_y0) : ld (hl),a : inc hl : ld a,(d_h) : ld (hl),a : inc hl
        ld (.rp),hl
        ld de,5 : add ix,de
        pop bc : djnz .d
        ld a,MAP_SIM : out ($50),a : ld (cur50),a
        ret
.list:  dw 0
.rp:    dw 0
static_rects: ds 4*16
static_dirty: ds 8

; HL -> list: count, then 5-byte display entries; appended to DLIST
add_list:
        ld b,(hl) : inc hl
.a:     ld a,(DCOUNT) : cp DLIST_MAX : ret nc
        push bc
        ld e,a : add a,a : add a,a : add a,e : ld e,a : ld d,0
        push hl : ld hl,DLIST : add hl,de : ex de,hl : pop hl
        ld bc,5 : ldir
        ld a,(DCOUNT) : inc a : ld (DCOUNT),a
        pop bc : djnz .a
        ret

; ---- enemy files
roster_page:
        xor a : ld (stars_on),a
        ld hl,roster_tick : ld de,roster_texts : ld a,175
        jp page_run
roster_texts:
        ld hl,roster_list : call draw_static
        ld hl,txt_roster : ld b,1 : ld c,14 : call text_centre
        ld hl,txt_r1 : ld b,3 : ld e,30 : ld c,13: call text_at
        ld hl,txt_r2 : ld b,6 : ld e,30 : ld c,9  : call text_at
        ld hl,txt_r3 : ld b,9 : ld e,30 : ld c,11 : call text_at
        ld hl,txt_r4 : ld b,12 : ld e,30 : ld c,9 : call text_at
        ld hl,txt_r5 : ld b,14 : ld e,30 : ld c,9 : call text_at
        ld hl,txt_r6 : ld b,15 : ld e,30 : ld c,11 : call text_at
        ret
roster_tick:
treasure_tick:
        xor a : ld (DCOUNT),a : ld (PCOUNT),a
        jp clear_ovl_req
txt_roster: db "- ENEMY FILES -",0
txt_r1: db "RAIDER SAUCER      200",0
txt_r2: db "HUNTER - AIMS!    1000",0
txt_r3: db "STINGER - DIVES    500",0
txt_r4: db "MINE               150",0
txt_r5: db "VOLATILE ROCK: SHRAPNEL",0
txt_r6: db "ORE ROCK: JEWELS",0

; ---- controls: each action's keys (as currently set) with a ship acting
; it out beside it
controls_page:
        xor a : ld (stars_on),a
        ld hl,roster_tick : ld de,controls_texts : ld a,250
        jp page_run
controls_texts:
        ld hl,controls_list : call draw_static
        ld hl,txt_ctl : ld b,1 : ld c,14 : call text_centre
        xor a
.l:     push af
        add a,a : ld e,a : ld d,0 : ld hl,dk_actions : add hl,de
        ld a,(hl) : inc hl : ld h,(hl) : ld l,a
        pop af : push af
        add a,a : add a,3 : ld b,a : ld e,24 : ld c,7 : call text_at
        pop af : push af
        call ctl_keys
        pop af : inc a : cp 6 : jr c,.l
        ld hl,txt_ctl2 : ld b,15 : ld c,8 : call text_centre
        ret
; A = action: its key, and the fixed alternative if it has one
ctl_keys:
        ld (.a),a
        add a,a : ld e,a : ld d,0 : ld hl,keymap : add hl,de
        ld a,(hl) : inc hl : ld c,(hl)
        push bc
        call key_name
        ld a,(.a) : add a,a : add a,3 : ld b,a : ld e,40 : ld c,15 : call text_at
        pop bc : ld a,c : cp $FF : ret z
        push bc
        ld hl,txt_or : ld a,(.a) : add a,a : add a,3 : ld b,a : ld e,47 : ld c,8 : call text_at
        pop bc : ld a,c : call key_name
        ld a,(.a) : add a,a : add a,3 : ld b,a : ld e,50 : ld c,15 : jp text_at
.a:     db 0
; A = key code -> HL = its name
key_name:
        and 63 : ld l,a : ld h,0 : ld e,l : ld d,h
        add hl,hl : add hl,hl : add hl,hl : or a : sbc hl,de        ; *7
        ld de,key_names : add hl,de
        ret

txt_ctl:  db "- CONTROLS -",0
txt_ctl2: db "RETURN OR 1 TO START  -  JOYSTICK WORKS TOO",0
txt_or:   db "OR",0

; ---- treasure + power
treasure_page:
        xor a : ld (stars_on),a
        ld hl,treasure_tick : ld de,treasure_texts : ld a,175
        jp page_run
treasure_texts:
        ld hl,treasure_list : call draw_static
        ld hl,txt_treasure : ld b,1 : ld c,14 : call text_centre
        ld hl,txt_j1 : ld b,3 : ld e,14 : ld c,11 : call text_at
        ld hl,txt_j2 : ld b,5 : ld e,14 : ld c,9 : call text_at
        ld hl,txt_j3 : ld b,7 : ld e,14 : ld c,10 : call text_at
        ld hl,txt_p1 : ld b,3 : ld e,44 : ld c,15 : call text_at
        ld hl,txt_p2 : ld b,6 : ld e,44 : ld c,15 : call text_at
        ld hl,txt_p3 : ld b,9 : ld e,44 : ld c,15 : call text_at
        ld hl,txt_p4 : ld b,12 : ld e,44 : ld c,15 : call text_at
        ld hl,txt_p5 : ld b,14 : ld e,44 : ld c,15 : call text_at
        ld hl,txt_chain : ld b,11 : ld e,3 : ld c,14 : call text_at
        ld hl,txt_chain2 : ld b,12 : ld e,3 : ld c,14 : call text_at
        ret
txt_treasure: db "- TREASURE + POWER -",0
txt_j1: db "TOPAZ     250",0
txt_j2: db "RUBY      500",0
txt_j3: db "EMERALD  1000",0
txt_p1: db "SHIELD - 3 HITS",0
txt_p2: db "SMART BOMB",0
txt_p3: db "SPREAD SHOT",0
txt_p4: db "RAPID FIRE",0
txt_p5: db "EXTRA SHIP",0
txt_chain:  db "CRACK ORE FOR JEWELS",0
txt_chain2: db "CHAIN THEM: UP TO X4",0
anim:   db 0
; list with per-entry animation step: (count) then entries; sprite += anim*step
; entry: x lo, x hi, y, sprite, colour, frames(1/2/4)
add_list_anim:
        ld b,(hl) : inc hl
.a:     push bc
        ld a,(DCOUNT) : ld e,a : add a,a : add a,a : add a,e : ld e,a : ld d,0
        push hl : ld hl,DLIST : add hl,de : ex de,hl : pop hl
        ld bc,5 : ldir
        ld a,(hl) : inc hl : dec a : ld c,a
        ld a,(anim) : and c : ex de,hl : dec hl : dec hl : add a,(hl) : ld (hl),a : ex de,hl
        ld a,(DCOUNT) : inc a : ld (DCOUNT),a
        pop bc : djnz .a
        ret

; ---- high score table
scores_page:
        ld a,1 : ld (stars_on),a
        ld hl,scores_tick : ld de,scores_texts : ld a,150
        jp page_run
scores_tick:
        xor a : ld (DCOUNT),a : ld (PCOUNT),a
        jp clear_ovl_req
scores_texts:
        ld hl,txt_hs : ld b,2 : ld c,14 : call text_centre
        ld ix,hs_table : ld b,5 : ld c,5
.l:     push bc
        ; "1.  ACE   010000"
        ld a,6 : sub b : add a,'0' : ld (hs_line),a
        ld a,(ix+3) : ld (hs_line+4),a
        ld a,(ix+4) : ld (hs_line+5),a
        ld a,(ix+5) : ld (hs_line+6),a
        push ix : pop hl : ld de,hs_line+10 : call bcd6
        pop bc : push bc
        ld a,b : ld hl,hs_colours-1 : add a,l : ld l,a : jr nc,$+3 : inc h : ld a,(hl)
        ld hl,hs_line : ld b,c : ld c,a : call text_centre
        pop bc
        ld de,8 : add ix,de
        inc c : inc c
        djnz .l
        ret
txt_hs:  db "- HIGH SCORES -",0
hs_line: db "1.  ACE   000000",0
hs_colours: db 8,7,7,14,15

hs_init:
        ld hl,hs_defaults : ld de,hs_table : ld bc,40 : ldir
        ld hl,hs_table : ld de,hi_score : ld bc,3 : ldir
        ret
hs_defaults:
        db $01,$00,$00,"ACE",0,0
        db $00,$75,$00,"VZ3",0,0
        db $00,$50,$00,"DSE",0,0
        db $00,$25,$00,"DUB",0,0
        db $00,$10,$00,"MCN",0,0

; did the last score make the table?  then enter initials
hs_check:
        ld ix,hs_table : ld b,5
.r:     push ix : pop hl : ld de,ST_SCORE
        ld a,(de) : cp (hl) : jr nz,.c
        inc hl : inc de : ld a,(de) : cp (hl) : jr nz,.c
        inc hl : inc de : ld a,(de) : cp (hl) : jr z,.lo
.c:     jr nc,.ins
.lo:    ld de,8 : add ix,de
        djnz .r
        ret
.ins:   ld a,b : dec a : jr z,.nos
        add a,a : add a,a : add a,a : ld c,a : ld b,0
        ld hl,hs_table+8*4-1 : ld de,hs_table+8*5-1 : lddr
.nos:   push ix : pop de
        ld hl,ST_SCORE : ld bc,3 : ldir
        ld a,'A' : ld (de),a : inc de : ld (de),a : inc de : ld (de),a
        dec de : dec de : ld (entry_ptr),de
        ld hl,hs_table : ld de,hi_score : ld bc,3 : ldir
        ; ---- entry screen
        call reset_screen
        xor a : ld (stars_on),a : ld (entry_pos),a
        ld (DCOUNT),a : ld (PCOUNT),a
        ld a,(music_on) : or a : call nz,SIM_MUSON
        ld hl,entry_texts : ld (page_texts),hl : call entry_texts
        ld a,$FF : ld (in_last),a
.loop:  call tick_wait
        call SIM_TICK : call SIM_TICK
        call read_input
        ld a,(in_new) : and 3 : jr nz,.chg
        ld a,(in_last) : and 3 : jr z,.norep
        ld hl,rep_ct : inc (hl) : ld a,(hl) : cp 6 : jr c,.show
        ld (hl),3
.chg:   ld hl,(entry_ptr) : ld a,(entry_pos) : ld e,a : ld d,0 : add hl,de
        ld a,(in_last) : and 1 : ld a,(hl) : jr z,.up
        dec a : cp 'A' : jr nc,.st : ld a,'Z' : jr .st
.up:    inc a : cp 'Z'+1 : jr c,.st : ld a,'A'
.st:    ld (hl),a
        ld a,SFX_CLINK : call SIM_SFX
        jr .show
.norep: xor a : ld (rep_ct),a
.show:  ld a,(in_new) : and $48 : jr z,.draw
        ld a,SFX_PICKUP : call SIM_SFX
        ld hl,entry_pos : inc (hl) : ld a,(hl) : cp 3 : ret nc
.draw:  call entry_draw
        call hud_update
        call render
        call present
        jr .loop
rep_ct: db 0
entry_texts:
        ld hl,txt_newhigh : ld b,3 : ld c,9 : call text_centre
        ld hl,txt_enter : ld b,6 : ld c,10 : call text_centre
        ld hl,txt_enter2 : ld b,7 : ld c,10 : call text_centre
        ret
entry_draw:
        ld hl,(entry_ptr) : ld de,entry_txt : ld bc,3 : ldir
        ; blink the current letter
        ld a,(ST_FRAME) : inc a : ld (ST_FRAME),a : and 8 : jr z,.o
        ld a,(entry_pos) : ld e,a : ld d,0 : ld hl,entry_txt : add hl,de : ld (hl),'_'
.o:     ; spaced out: "A B C"
        ld a,(entry_txt) : ld (entry_show),a
        ld a,(entry_txt+1) : ld (entry_show+2),a
        ld a,(entry_txt+2) : ld (entry_show+4),a
        call clear_ovl_req
        ld hl,entry_show : ld b,10 : ld c,15 : xor a : jp ovl_set
txt_newhigh: db "NEW HIGH SCORE!",0
txt_enter:   db "LEFT / RIGHT CHOOSE A LETTER",0
txt_enter2:  db "FIRE TO ENTER IT",0
entry_txt:   db "AAA"
entry_show:  db "A A A",0
entry_ptr:   dw 0
entry_pos:   db 0

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; DEFINE KEYS (K on the title)
; ---------------------------------------------------------------------------
define_keys:
        call reset_screen
        xor a : ld (stars_on),a : ld (DCOUNT),a : ld (PCOUNT),a : ld (dk_i),a
        ld hl,keymap : ld de,dk_save : ld bc,12 : ldir     ; for ESC
        ld hl,dk_texts : ld (page_texts),hl : call dk_texts
.act:   ; prompt for action dk_i
        ld a,(dk_i) : add a,a : ld e,a : ld d,0 : ld hl,dk_actions : add hl,de
        ld a,(hl) : inc hl : ld h,(hl) : ld l,a
        ld de,dk_prompt+14 : ld bc,13 : ldir
        call clear_ovl_req
        ld hl,dk_prompt : ld b,14 : ld c,15 : xor a : call ovl_set
        ; wait until no key is held, then for a key
.rel:   call dk_frame : call scan_keys : cp $FF : jr nz,.rel
.wait:  call dk_frame : call scan_keys : cp $FF : jr z,.wait
        cp K_ESC : jr z,.esc
        cp K_TAB : jr z,.dflt
        ld c,a
        call dk_taken : jr z,.taken
        ld a,(dk_i) : add a,a : ld e,a : ld d,0 : ld hl,keymap : add hl,de : ld (hl),c
        ld a,(dk_i) : call dk_show
        ld a,SFX_CLINK : call SIM_SFX
        ld hl,dk_i : inc (hl) : ld a,(hl) : cp 6 : jp c,.act
        ld hl,txt_keysset : ld c,14
.fin:   push hl : push bc
        call clear_ovl_req
        pop bc : pop hl : ld b,14 : xor a : call ovl_set
        ld b,40
.done:  push bc : call dk_frame : pop bc : djnz .done
        ret
.taken: ; that key already does something else: say so, ask again
        ld a,SFX_EFIRE : call SIM_SFX
        call clear_ovl_req
        ld hl,txt_taken : ld b,14 : ld c,9 : xor a : call ovl_set
        ld b,30
.tw:    push bc : call dk_frame : pop bc : djnz .tw
        jp .act
.esc:   ld hl,dk_save : ld de,keymap : ld bc,12 : ldir    ; as they were
        ld hl,txt_cancel : ld c,7
        jr .shown
.dflt:  ld hl,dk_default : ld de,keymap : ld bc,12 : ldir
        ld a,SFX_PICKUP : call SIM_SFX
        ld hl,txt_dflt : ld c,14
.shown: push hl : push bc
        xor a
.sh:    push af : call dk_show : pop af : inc a : cp 6 : jr c,.sh
        pop bc : pop hl
        jr .fin
; C = key: Z if it already belongs to another action (an earlier one in
; this pass, or any action's fixed alternative)
dk_taken:
        ld hl,keymap : ld b,0
.t:     ld a,b : ld de,dk_i : ex de,hl : cp (hl) : ex de,hl
        jr nc,.alt                              ; later actions: not yet set
        ld a,(hl) : cp c : ret z
.alt:   inc hl
        ld a,b : ld de,dk_i : ex de,hl : cp (hl) : ex de,hl
        jr z,.n                                 ; its own alternative is fine
        ld a,(hl) : cp c : ret z
.n:     inc hl : inc b : ld a,b : cp 6 : jr nz,.t
        or 1                                    ; NZ: free
        ret
K_ESC   equ 48
K_TAB   equ 50
dk_save:    ds 12
dk_default: db 21,$3B, 9,$3E, 15,$38, $37,26, 16,$FF, 2,$3A
txt_taken:  db "THAT KEY IS TAKEN - TRY ANOTHER",0
txt_cancel: db "CANCELLED - KEYS UNCHANGED",0
txt_dflt:   db "DEFAULT KEYS RESTORED",0
dk_frame:
        call tick_wait
        call SIM_TICK : call SIM_TICK
        call hud_update
        call render
        jp present
dk_texts:
        ld hl,txt_dk : ld b,1 : ld c,14 : call text_centre
        xor a
.l:     push af
        add a,a : ld e,a : ld d,0 : ld hl,dk_actions : add hl,de
        ld a,(hl) : inc hl : ld h,(hl) : ld l,a
        pop af : push af
        add a,a : add a,3 : ld b,a : ld e,18 : ld c,7 : call text_at
        pop af : push af
        call dk_show
        pop af : inc a : cp 6 : jr c,.l
        ld hl,txt_dk2 : ld b,15 : ld c,8 : call text_centre
        ret
; A = action -> show its key name on its line
dk_show:
        push af
        add a,a : ld e,a : ld d,0 : ld hl,keymap : add hl,de
        ld a,(hl) : and 63 : ld l,a : ld h,0 : ld e,l : ld d,h
        add hl,hl : add hl,hl : add hl,hl : or a : sbc hl,de        ; *7
        ld de,key_names : add hl,de
        pop af : add a,a : add a,3 : ld b,a : ld e,38 : ld c,11
        jp text_at
; scan the whole keyboard: A = first held key code, FFh if none
scan_keys:
        ld a,1 : out ($0B),a
        ld c,0
.s:     ld a,c : call keytest : jr nz,.got
        inc c : ld a,c : cp 64 : jr nz,.s
        ld c,$FF
.got:   xor a : out ($0B),a
        ld a,c
        ret
dk_i:   db 0
dk_actions: dw dka0,dka1,dka2,dka3,dka4,dka5
dka0:   db "ROTATE LEFT  ",0
dka1:   db "ROTATE RIGHT ",0
dka2:   db "THRUST       ",0
dka3:   db "FIRE         ",0
dka4:   db "HYPERSPACE   ",0
dka5:   db "SMART BOMB   ",0
dk_prompt:  db "PRESS KEY FOR XXXXXXXXXXXXX",0
txt_dk:     db "- DEFINE KEYS -",0
txt_dk2:    db "ESC CANCEL   TAB DEFAULTS   ARROWS, Z, JOYSTICK ALWAYS WORK",0
txt_keysset: db "KEYS SET!",0
        INCLUDE "keynames.inc"

        INCLUDE "lists.inc"
        INCLUDE "sprites.inc"
font:   INCBIN "../build/font.bin"

; ---------------------------------------------------------------------------
; variables
back:       db 0
front:      db 1
bank_base:  db $80
colpage:    db $F8
scrpage:    db $F0
cur_bank:   db 0
fields:     db 0
flips:      dw 0
ticks:      dw 0
sim_fields: db 0
vb_state:   db 0
in_last:    db 0
in_new:     db 0
music_on:   db 1
text_rows:  db 0
col2:       db 0
stars_on:   db 0
dcount:     db 0
d_cols:     db 0
d_h:        db 0
d_y0:       db 0
d_col:      db 0
dcount0:    db 0
dcount1:    db 0
snd_accA:   dw 0
snd_accB:   dw 0
snd_accC:   dw 0
snd_frqA:   dw 0
snd_frqB:   dw 0
snd_frqC:   dw 0
ovl_cur:    ds 3*34
ovl_tmp:    ds 32
tqn0:       dw 0
tqn1:       dw 0
ovl_req:    ds 12
hi_score:   ds 3
hs_table:   ds 40
star_x:     ds N_STARS*2
star_y:     ds N_STARS*2
pix_ptr:    dw PIXL0
pix_end0:   dw PIXL0
pix_end1:   dw PIXL1
row_prot    equ $DE00       ; per row: 0 free, 1 has static text, 2 HUD
ROW_LO      equ $DE10       ; per row: first / last column holding text
ROW_HI      equ $DE20
HUD_ANY     equ $DE30       ; 2 bytes: any HUD cell flagged on page 0 / 1
HUD_R0      equ $DE80       ; HUD redraw rows, page 0 ($DE80) / page 1 ($DF80)
dot_masks   equ $DE40       ; page-aligned copy of dot_mask_src
TEXT_MAP    equ $E000       ; 1K: text layer character per cell
code_end:
; uninitialised buffers after the program (not stored in AST2.HI)
tq0         equ code_end            ; text redraw queues
tq1         equ tq0 + 1024              ; (512 cells each: a page is ~400)
tqf         equ tq1 + 1024          ; queued flags: bit 0 page 0, bit 1 page 1
buf_end     equ tqf + 1024
        ASSERT buf_end <= $D000

; fixed buffers above the exchange area
dirty0      equ $D400               ; 8 bytes x DIRTY_MAX
dirty1      equ dirty0 + 8*DIRTY_MAX
PIXL0       equ $E400               ; dot erase lists, 3 bytes x 160
PIXL1       equ $E600
        ASSERT dirty1 + 8*DIRTY_MAX <= $DC00

erase_chain     equ $DC00       ; built at start-up: 64 x (ld (hl),a : inc l), ret
erase_chain_end equ $DC80

        SAVEBIN "../build/AST2.HI",$8000,code_end-$8000
