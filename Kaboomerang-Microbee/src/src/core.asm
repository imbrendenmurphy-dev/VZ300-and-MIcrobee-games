; =====================================================================
;  CORE: hardware set-up, banking, frame timing + the beeper during
;  idle time, keyboard and joystick, random numbers, unpacking.
;  Interrupts stay off all the time (DI), as in the VZ original.
; =====================================================================

hw_init:
        di
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld a,2
        ld (steps),a
        ; PIO A: input (joystick)
        ld a,$CF
        out (P_PIOAC),a
        ld a,$FF
        out (P_PIOAC),a
        ld a,$07
        out (P_PIOAC),a
        ; PIO B: bit control, b6 speaker out, no interrupts
        ld a,$CF
        out (P_PIOBC),a
        ld a,$BF
        out (P_PIOBC),a
        ld a,$07
        out (P_PIOBC),a
        xor a
        out (P_PIOB),a
        out (P_ROMLAT),a
        out (P_COLCTL),a
        ld a,BLK_RT
        call map_blk
        ld hl,0                 ; the RT block: lists, flags (all clear)
        ld de,1
        ld bc,RT_END-1
        ld (hl),0
        ldir
        ld hl,cellmap
        ld de,cellmap+1
        ld bc,$3FF
        ld (hl),0
        ldir
        call crtc_game
        ret

; 40 x 25 characters of 8 lines (320 x 200). The values follow BPM's
; MODES.COM 40-column test, proven on the Premium Plus: the 40-column modes
; need nothing but these CRTC registers (R0 35h with R1 28h). Its 40 x 24
; and 40 x 32 tables differ from this only in R6 and R7.
crtc_game:
        call clock40
        ld a,(crtc_vpos)
        or a
        jr nz,.v
        ld a,CRTC_V
        ld (crtc_vpos),a
.v:     ld hl,crtc_tab
        ld c,0
.ci:    ld a,c
        out (P_CRTCA),a
        ld a,(hl)
        out (P_CRTCD),a
        inc hl
        inc c
        ld a,c
        cp 16
        jr nz,.ci
        ret
        ld a,7
        out (P_CRTCA),a
        ld a,(crtc_vpos)
        out (P_CRTCD),a
        ret
CRTC_V  equ $21
;               R0  R1  R2  R3  R4  R5  R6  R7  R8  R9  R10 R11 R12 R13 R14 R15
crtc_tab:       db $35,$28,$2C,$34,$26,$01,$19,CRTC_V,$48,$07,$20,$07,$00,$00,$00,$00

; clock40: nothing to do. MODES.COM writes no clock port; kept as the
; one place to add a switch if a later board ever needs it.
clock40:
        ret

; A = block -> A = port 50h value (ROMs off, video window at F000)
bank_port:
        push bc
        ld b,a
        and 3
        xor 2
        ld c,a
        ld a,b
        and $1C
        rlca
        rlca
        rlca
        or c
        or 4
        pop bc
        ret
; map block A into the lower window (remembered in curblk as a port value)
map_blk:
        call bank_port
map_port:
        out (P_MEM),a
        ld (curblk),a
        ret

; copy BC bytes from block A offset HL to block (cb_dst) offset DE,
; through a 256-byte bounce buffer in the upper block
blk_copy:
        ld (cb_src),a
        ld a,(curblk)
        push af
.ch:    ld a,b
        or c
        jr z,.done
        push bc
        ld a,b
        or a
        jr z,.small
        ld bc,256
.small: push bc
        ld a,(cb_src)
        call map_blk
        push de
        ld de,bounce
        push bc
        ldir
        pop bc
        pop de
        push hl
        ld a,(cb_dst)
        call map_blk
        ld hl,bounce
        ldir
        pop hl
        pop bc
        ex (sp),hl
        or a
        sbc hl,bc
        ld b,h
        ld c,l
        pop hl
        jr .ch
.done:  pop af
        jp map_port

; ---------------------------------------------------------------------
;  frame timing: rising edges of the 6545 vertical blanking status
; ---------------------------------------------------------------------
vschk:  in a,(P_CRTCA)
        and $20
        jr z,.lo
        ld a,(vblast)
        or a
        ret nz
        ld a,$20
        ld (vblast),a
        ld a,(vcount)
        inc a
        ld (vcount),a
        ret
.lo:    ld (vblast),a
        ret

; ---------------------------------------------------------------------
; frame_wait: the 2-channel pin-pulse beeper (from TENNIS II on the VZ)
; plays until (vcount) reaches A fields since the last frame. Loop = 127 T
; (26.6 kHz). Channel 1 = acc1/step1, channel 2 = acc2/step2.
; Noise mode: channel 2 pulses when a byte of the program is below D'.
; ---------------------------------------------------------------------
frame_wait:
        ld (fw_need),a
        call vschk
        ld a,(vcount)
        ld hl,fw_need
        cp (hl)
        jp nc,.done
        ld a,(noiseon)
        or a
        jp nz,fw_noise
        ld hl,(acc1)
        ld de,(step1)
        exx
        ld hl,(acc2)
        ld de,(step2)
        ld a,(vblast)
        ld c,a                  ; C' = last vblank level
        exx
.lp:    add hl,de               ; 11  channel 1
        sbc a,a                 ; 4
        and $40                 ; 7
        ld b,a                  ; 4
        exx                     ; 4
        add hl,de               ; 11  channel 2
        sbc a,a                 ; 4
        and $40                 ; 7
        exx                     ; 4
        or b                    ; 4
        out (P_PIOB),a          ; 11
        nop                     ; 4 x 4: the same 127 T as the noise loop
        nop
        nop
        nop
        in a,(P_CRTCA)          ; 11
        and $20                 ; 7
        exx                     ; 4
        cp c                    ; 4
        exx                     ; 4
        jp z,.lp                ; 10 = 127 T
        exx
        ld c,a
        exx
        or a
        jr z,.lp                ; falling edge: keep going
        ld a,(vcount)           ; rising edge: one more field
        inc a
        ld (vcount),a
        push hl
        ld hl,fw_need
        cp (hl)
        pop hl
        jr c,.lp
        exx
        ld a,c
        ld (vblast),a
        exx
        xor a
        out (P_PIOB),a
        ld (acc1),hl
        exx
        ld (acc2),hl
        exx
.done:  ld a,(vcount)
        ld hl,fw_need
        sub (hl)
        cp 2
        jr c,.k
        ld a,1
.k:     ld (vcount),a
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
        ret

fw_noise:
        ld hl,(acc1)
        ld de,(step1)
        exx
        ld hl,(acc2)
        ld a,h
        and $3F
        or $80
        ld h,a                  ; walk the program bytes $8000-$BFFF
        ld de,(step2)           ; D' = density
        ld a,(vblast)
        ld c,a
        exx
.lp:    add hl,de               ; channel 1
        sbc a,a
        and $40
        ld b,a
        exx
        ld a,(hl)
        inc hl
        res 6,h
        cp d
        sbc a,a
        and $40
        exx
        or b
        out (P_PIOB),a
        exx
        in a,(P_CRTCA)
        and $20
        cp c
        exx
        jr z,.lp                ; = 127 T
        exx
        ld c,a
        exx
        or a
        jr z,.lp
        ld a,(vcount)
        inc a
        ld (vcount),a
        push hl
        ld hl,fw_need
        cp (hl)
        pop hl
        jr c,.lp
        exx
        ld a,c
        ld (vblast),a
        exx
        xor a
        out (P_PIOB),a
        ld (acc1),hl
        exx
        set 7,h
        ld (acc2),hl
        exx
        jp frame_wait.done

; ---------------------------------------------------------------------
random:
        ld hl,(seed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (seed),hl
        ld a,l
        xor h
        ret
; random below B (B >= 1) -> A
rand_n:
        push bc
        call random
        pop bc
.m:     cp b
        ret c
        sub b
        jr .m

