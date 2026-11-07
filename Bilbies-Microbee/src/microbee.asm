; Native Premium Plus bring-up backend. Original simulation coordinates.
; All bank-switching code/stack are above 8000h. Video is normally hidden.
mb_boot:
        di
        ld a,$0F : out ($50),a
        ld sp,STACKTOP
        ld hl,VARS : ld de,VARS+1 : ld bc,IMTAB-VARS-1
        ld (hl),0 : ldir
        ld hl,$3A71 : ld (v_seed),hl
        call build_tables
        call mb_init
        ld a,($6FFE) : and 1 : ld (mb_drive),a
        ld a,1 : ld (v_unlock),a
        call load_game
        call mb_settings
        jp front_main

int_poll:
set_mode1:
setlatch:
snd_init:
snd_step:
snd_nstep:
snd_wait_step:
sfx_play:
sfx_tick:
noise_crack:
noise_burst:
mus_init:
mus_tick:
        ret
mus_endf: db 0
mus_frame:
        ld a,1
frame_sync:
        push af : push bc : push de : push hl
        ld (mb_wait),a
        call mb_present
        ld a,(mb_wait) : ld b,a
.f:     in a,($0C) : and $20 : jr nz,.f
.w:     in a,($0C) : and $20 : jr z,.w
        ld a,(v_tick) : inc a : ld (v_tick),a
        djnz .f
        call mb_scan
        call mb_settings_key
        pop hl : pop de : pop bc : pop af
        ret
mb_wait: db 0

mb_init:
        ld a,$CF : out ($01),a
        ld a,$FF : out ($01),a
        ld a,$07 : out ($01),a
        xor a : out ($0B),a
        ld hl,mb_crtc : ld c,0
.c:     ld a,c : out ($0C),a
        ld a,(hl) : out ($0D),a
        inc hl : inc c : ld a,c : cp 16 : jr nz,.c
        ; PCG bank 8 contains 8K of colour and monochrome definitions.
        ; Copy 4 x 2K from expansion block 8 without lower-RAM access.
        ld (mb_sp),sp : ld sp,$6FF0
        ld a,$46 : out ($50),a
        xor a : out ($08),a
        ld hl,0 : ld c,0
.p:     ld a,c : or $80 : out ($1C),a
        ld de,$F800 : ld bc,$0800 : ldir
        ld a,(mb_bank) : inc a : ld (mb_bank),a
        ld c,a : cp 4 : jr nz,.p
        ld a,$0F : out ($50),a
        ld sp,(mb_sp)
        ret
mb_bank: db 0
mb_sp: dw 0
; 80-column dot timing, 64 displayed cells; 52*6=312 scanlines.
; This unusual 8x6-cell mode needs real monitor verification.
mb_crtc: db $6B,$40,$50,$37,$33,0,$20,$29,$48,5,$20,5,0,0,0,0

; Gather cell keys while RAM at F000 is visible. Output arrays live in
; unused lower home RAM. No simulation data is read under the video window.
mb_present:
        ld (mb_sp),sp : ld sp,$6FF0
        ld a,7 : out ($50),a
        ld hl,VRAM : ld ix,$2800 : ld iy,$F000
        ld a,32 : ld (mb_rows),a
.row:   ld b,32
.byte:  ld a,(hl) : ld (mb_t),a
        ld c,0 : cp (ix+0) : jr z,.same1 : inc c
.same1: ld (ix+0),a
        push hl : ld de,32 : add hl,de
        ld a,(hl) : ld (mb_b),a : pop hl
        cp (ix+1) : jr z,.same2 : inc c
.same2: ld (ix+1),a
        ld a,(mb_force) : or c : jr z,.skip
        push bc
        ld a,(mb_t) : and $F0 : ld c,a
        ld a,(mb_b) : rrca : rrca : rrca : rrca : and 15 : or c
        call mb_emit
        ld a,(mb_t) : rlca : rlca : rlca : rlca : and $F0 : ld c,a
        ld a,(mb_b) : and 15 : or c
        call mb_emit
        pop bc
        jr .next
.skip:  inc iy : inc iy
.next:  inc ix : inc ix : inc hl
        djnz .byte
        ld de,32 : add hl,de
        ld a,(mb_rows) : dec a : ld (mb_rows),a : jr nz,.row
        ld a,$0F : out ($50),a
        ld sp,(mb_sp)
        xor a : ld (mb_force),a
        ret
mb_emit:
        push hl : push de
        ld c,a
        ld a,$80 : out ($1C),a
        ld a,c : or $80 : ld (iy+0),a
        ld a,$90 : out ($1C),a
        ld a,c : rlca : and 1 : ld e,a
        ld a,(mb_mono) : add a,a : or e : ld (iy+0),a
        ld l,c : ld h,mb_colours>>8 : ld a,(hl) : ld e,a
        ld a,(mb_mono) : or a : ld a,e : jr z,.colour
        ld a,15
.colour:ld e,a
        ld a,$40 : out ($08),a
        push iy : pop hl : set 3,h : ld (hl),e
        inc iy
        pop de : pop hl : ret
mb_t: db 0
mb_b: db 0
mb_rows: db 0
mb_force: db 1
mb_mono: db 0
        ALIGN 256
mb_colours: INCBIN "../build/colours.bin"

; Light-pen key scan, from the repository's Premium Plus driver.
mb_keytest:
        push bc : ld b,a
        ld a,$10 : out ($0C),a : in a,($0D)
        ld a,$11 : out ($0C),a : in a,($0D)
        ld a,$12 : out ($0C),a
        ld a,b : rrca : rrca : rrca : rrca : and 3 : out ($0D),a
        ld a,$13 : out ($0C),a
        ld a,b : rlca : rlca : rlca : rlca : and $F0 : out ($0D),a
        ld a,$1F : out ($0C),a : out ($0D),a
        nop
        ld b,0
.w:     in a,($0C) : bit 7,a : jr nz,.d : djnz .w
.d:     and $40 : pop bc : ret

mb_scan:
        push af : push bc : push de : push hl
        ld hl,$68FE : ld b,8
.clear: ld (hl),$FF : rlc l : djnz .clear
        ld a,1 : out ($0B),a
        ld hl,mb_keys
.k:     ld a,(hl) : cp $FF : jr z,.done
        inc hl : call mb_keytest
        ld e,(hl) : inc hl : ld d,(hl) : inc hl
        jr z,.k
        push hl : ld h,$68 : ld l,e : ld a,(hl) : and d : ld (hl),a
        pop hl : jr .k
.done:  xor a : out ($0B),a
        pop hl : pop de : pop bc : pop af : ret
; key code, VZ row low address, complement of bit to clear.
mb_keys:
        db 17,$FE,$EF, 1,$FD,$EF, 15,$BF,$FD, 16,$BF,$EF
        db $38,$FE,$EF, $3A,$FD,$EF, $3B,$BF,$FD, $3E,$BF,$EF
        db $37,$EF,$EF, $34,$BF,$FB, 20,$FE,$DF
        db 13,$EF,$DF, $2C,$EF,$F7, $2E,$EF,$FD
        db 19,$FD,$FD, 11,$7F,$EF, 26,$FB,$EF, 24,$FB,$FD
        db 8,$7F,$FE, 14,$EF,$FE, $39,$FD,$FB
        db $21,$F7,$EF, $22,$F7,$FD, $23,$F7,$F7, $24,$F7,$DF
        db $25,$F7,$FE, $26,$DF,$FE, $27,$DF,$DF, $28,$DF,$F7
        db $FF

; Upper-RAM temporary storage for decompression when the lower bank changes.
mb_stamp: ds 512
mb_rx: db 0
mb_ry: db 0

SFX_LETSGO equ 1
SFX_ASSIGN equ 2
SFX_CLICK equ 3
SFX_DIG equ 4
SFX_CLINK equ 5
SFX_TINK equ 6
SFX_SPLAT equ 7
SFX_SPLASH equ 8
SFX_HOME equ 9
SFX_OHNO equ 10
SFX_BOOM equ 11
