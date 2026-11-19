; =====================================================================
;  HARDWARE: start-up, the 6545, frame timing with the beeper running in
;  the idle time, random numbers.  Interrupts stay off while the game
;  owns the machine; they are only let back on around BDOS calls.
; =====================================================================
hw_init:
        di
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld a,MEM_GAME
        out (P_MEM),a
        xor a
        out (P_ROMLAT),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,LV_SCREEN
        out (P_LV),a
        ld hl,$C0DE
        ld (seed),hl
        call crtc_game
        ret

; after any BDOS call: the video window and latches back as the game has them
hw_video:
        di
        ld a,MEM_GAME
        out (P_MEM),a
        xor a
        out (P_ROMLAT),a
        ld a,COL_ON             ; the colour RAM is in the F800h window, except
        out (P_COLCTL),a        ; while PCG patterns are being written
        ld a,LV_SCREEN
        out (P_LV),a
        ret

; 40 x 25 characters of 10 lines (320 x 250: a full PAL picture, and the
; tallest whose two pages still fit the 2K of screen RAM; the table is the
; 40X25 8X10 one from BPM's MODES.COM) on the 40-column dot clock
; (6.75 MHz: 54 characters a 64 us line).  The clock is chosen by reading
; port 09h with address line A8 high (LD A,1 / IN A,(09h)), as BPM's
; MODES.COM and HULLBREACH do on the Premium Plus.  Without it the 6545
; runs these values at twice the line rate and the monitor shows four
; small pictures.
crtc_game:
        ld a,1
        in a,($09)
        ld hl,crtc_tab
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
;               R0  R1  R2  R3  R4  R5  R6  R7  R8  R9  R10 R11 R12 R13 R14 R15
crtc_tab:   db $35,$28,$2C,$34,$1E,$03,$19,$1C,$48,$09,$20,$09,$00,$00,$00,$00

; show page A (0 or 1): only ever called in vertical blanking
show_page:
        ld (dpage),a
        add a,a
        add a,a                 ; start address high: 0 or 4 (page 1 = cell 1024)
        ld b,a
        ld a,12
        out (P_CRTCA),a
        ld a,b
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ret

; ---------------------------------------------------------------------
;  field counting: rising edges of the 6545 vertical blanking status.
;  Long jobs call vschk often enough never to miss one.
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

; wait for the start of the next vertical blanking (no sound)
wait_vb:
.a:     in a,(P_CRTCA)
        and $20
        jr nz,.a
.b:     in a,(P_CRTCA)
        and $20
        jr z,.b
        ld a,$20
        ld (vblast),a
        ret

; ---------------------------------------------------------------------
;  frame_end: fill the rest of the frame (A fields long) with the beeper,
;  one sound step a field, and come back at the start of vertical
;  blanking.  The 2-voice pin-pulse engine is the one from TENNIS II:
;  loop = 127 T (26.6 kHz), channel 1 = acc1/step1, channel 2 = acc2/step2,
;  or noise when (noiseon): channel 2 pulses when a program byte is below D'.
; ---------------------------------------------------------------------
frame_end:
        ld (fe_need),a
        xor a
        ld (fe_ticks),a
.lp:    call vschk
        ld a,(vcount)
        ld hl,fe_need
        cp (hl)
        jr nc,.done
        call sound_tick
        ld hl,fe_ticks
        inc (hl)
        call beep_field
        jr .lp
.done:  ; keep the music's tempo when the frame's work ate whole fields
        ld a,(fe_ticks)
        ld hl,fe_need
        cp (hl)
        jr nc,.ok
        inc a
        ld (fe_ticks),a
        call sound_tick
        jr .done
.ok:    xor a
        ld (vcount),a
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
        ret

; play until the next rising edge of vertical blanking; counts the field
beep_field:
        ld a,(noiseon)
        or a
        jp nz,bf_noise
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
        nop
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
        ld (vblast),a
        xor a
        out (P_PIOB),a
        ld (acc1),hl
        exx
        ld (acc2),hl
        exx
        ld hl,vcount
        inc (hl)
        ret

; the same with channel 2 as noise: a 16-bit shift register stepped every
; pass, a pulse whenever its high byte is under the density in D'.  (It must
; be real noise: patterned bytes make a harsh buzz.)
bf_noise:
        ld hl,(acc1)
        ld de,(step1)
        exx
        ld hl,(nseed)
        ld a,h
        or l
        jr nz,.sd
        ld hl,$ACE1
.sd:    ld de,(step2)           ; D' = density
        ld a,(vblast)
        ld c,a
        exx
.lp:    add hl,de               ; channel 1
        sbc a,a
        and $40
        ld b,a
        exx
        add hl,hl               ; x^16 + x^5 + x^3 + x^2 + 1
        jr nc,.n
        ld a,l
        xor $2D
        ld l,a
.n:     ld a,h
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
        jr z,.lp
        exx
        ld c,a
        exx
        or a
        jr z,.lp
        ld (vblast),a
        xor a
        out (P_PIOB),a
        ld (acc1),hl
        exx
        ld (nseed),hl
        exx
        ld hl,vcount
        inc (hl)
        ret

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
