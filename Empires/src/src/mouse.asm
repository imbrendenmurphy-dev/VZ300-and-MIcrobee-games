; ===================================================================
;  mouse.asm - Microsoft serial mouse on the Microbee serial port
;
;  RS232 input is PIO port B bit 4 (MAME mbee: "d4 rs232 input (0=mark)").
;  There is no UART: the line is polled while the game waits for the next
;  frame, and a packet is received with a cycle-counted loop.
;  Microsoft mouse: 1200 baud, 7 data bits, 1 stop, 3-byte packets:
;    byte 1: 1 L R Y7 Y6 X7 X6      byte 2: 0 X5..X0     byte 3: 0 Y5..Y0
;  The idle (mark) level is measured at start-up, so either line polarity
;  works.  One bit = 3,375,000 / 1200 = 2812 T-states.
; ===================================================================
MS_BIT  equ 110                 ; default bit delay at 3.375 MHz (25 * 110 + 69 = 2819 T)
MS_HALF equ 55                  ; first sample lands 1.5 bits after the edge

; ---- calibrate the bit timing against the screen's 50 Hz frame -------
; The 6545 frame (313 lines x 64 us = 20.03 ms) does not depend on the CPU
; clock, so counting a fixed 48 T-state loop over one frame gives
; N = T-states per frame / 48.  One bit at 1200 baud = frame / 24 = 2N T,
; so the delay count is (2N - 69) / 25 (fits 8 bits up to about 7 MHz).
; Call with interrupts off.
ms_calib:
        ld a,MS_BIT
        ld (ms_bitn),a
        ld a,MS_HALF
        ld (ms_half),a
        ld hl,0
        ld (ms_frameN),hl
        ld bc,0                 ; leave vblank (with a timeout)
.s1:    in a,(P_CRTCA)
        and 20h
        jr z,.s2
        dec bc
        ld a,b
        or c
        jr nz,.s1
        ret                     ; no frame flag: keep the defaults
.s2:    ld bc,0                 ; wait for vblank to start
.s3:    in a,(P_CRTCA)
        and 20h
        jr nz,.go
        dec bc
        ld a,b
        or c
        jr nz,.s3
        ret
.go:    ld hl,0
.p1:    in a,(P_CRTCA)          ; 11  count through the blanking ...
        and 20h                 ; 7
        jr z,.p2                ; 7
        inc hl                  ; 6
        ld b,0                  ; 7
        jp .p1                  ; 10  = 48
.p2:    in a,(P_CRTCA)          ; 11  ... and through the visible part
        and 20h                 ; 7
        jr nz,.dn               ; 7
        inc hl                  ; 6
        ld b,0                  ; 7
        jp .p2                  ; 10  = 48
.dn:    ld (ms_frameN),hl
        add hl,hl               ; 2N
        ld de,-69
        add hl,de
        ret nc                  ; nonsense: keep the defaults
        ld bc,25
        ld de,0
.dv:    or a
        sbc hl,bc
        jr c,.dd
        inc de
        jr .dv
.dd:    ld a,d
        or a
        ret nz                  ; too slow a frame count for 8 bits: keep defaults
        ld a,e
        cp 20
        ret c                   ; implausible: keep defaults
        ld (ms_bitn),a
        srl a
        ld (ms_half),a
        ret

; measure the idle level: sample the line for ~20 ms; if it never moves
; the idle level is whatever it reads.  ms_ok = 0 until a valid packet.
mouse_init:
        call ms_calib
        in a,(P_PIOB)
        and 10h
        ld (ms_idle),a
        ld bc,3000
.l:     in a,(P_PIOB)
        and 10h
        ld hl,ms_idle
        cp (hl)
        jr z,.n
        ; it moved: whichever level it rests at later wins - resample
        ld (hl),a
.n:     dec bc
        ld a,b
        or c
        jr nz,.l
        in a,(P_PIOB)
        and 10h
        ld (ms_idle),a
        xor a
        ld (ms_ok),a
        ld (ms_btn),a
        ld (ms_obtn),a
        ld hl,0
        ld (ms_ax),hl
        ld (ms_ay),hl
        ret

; poll: called from the frame-wait loop.  Fast exit when the line is idle.
mouse_poll:
        in a,(P_PIOB)
        and 10h
        ld hl,ms_idle
        cp (hl)
        ret z
        ; start bit: receive up to three bytes back to back
        call ms_rx
        ret c                   ; framing error
        bit 6,a
        ret z                   ; not a first byte: wait for the next packet
        ld (ms_b1),a
        call ms_next
        ret c
        bit 6,a
        ret nz
        ld (ms_b2),a
        call ms_next
        ret c
        bit 6,a
        ret nz
        ld (ms_b3),a
        ; decode
        ld a,(ms_b1)
        ld c,a
        and 3                   ; X7 X6
        rrca
        rrca
        ld b,a
        ld a,(ms_b2)
        and 3Fh
        or b
        ld e,a                  ; dx (signed 8)
        ld a,c
        and 0Ch                 ; Y7 Y6
        rlca
        rlca
        rlca
        rlca
        ld b,a
        ld a,(ms_b3)
        and 3Fh
        or b
        ld d,a                  ; dy (signed 8)
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and 3                   ; bit0 = R, bit1 = L
        ld (ms_btn),a
        ; accumulate
        ld a,e
        call .sx
        ld hl,(ms_ax)
        add hl,bc
        ld (ms_ax),hl
        ld a,d
        call .sx
        ld hl,(ms_ay)
        add hl,bc
        ld (ms_ay),hl
        ld a,1
        ld (ms_ok),a
        ret
.sx:    ld c,a                  ; BC = sign-extended A
        rla
        sbc a,a
        ld b,a
        ret

; wait for the next start bit (up to ~3 bit times), then receive it.
; returns C set on timeout.
ms_next:
        ld a,(ms_bitn)          ; timeout ~ 10 bit times at any CPU speed
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        add hl,hl
        ex de,hl
.w:     in a,(P_PIOB)
        and 10h
        ld hl,ms_idle
        cp (hl)
        jr nz,ms_rx_go
        dec de
        ld a,d
        or e
        jr nz,.w
        scf
        ret
ms_rx_go:
        jp ms_rx

; receive one byte; entered just after the start edge was seen -> A
; bit delay counts (ms_bitn / ms_half) come from the calibration
ms_rx:  ld a,(ms_bitn)
        ld h,a
        ld a,(ms_half)
        ld b,a
.h:     nop
        nop
        nop
        djnz .h
        ld c,0
        ld d,7
.bit:   ld b,h                  ; 4
.d:     nop                     ; 4
        nop                     ; 4
        nop                     ; 4
        djnz .d                 ; 13/8  -> 25 * b - 5
        in a,(P_PIOB)           ; 11
        and 10h                 ; 7
        ld e,a                  ; 4
        ld a,(ms_idle)          ; 13
        xor e                   ; 4
        sub 1                   ; 7   carry if mark (= data bit 1)
        rr c                    ; 8
        dec d                   ; 4
        jr nz,.bit              ; 12  -> one bit = 25 * b + 69 T-states
        ; stop bit must be mark, else we locked on mid-byte: framing error
        ld b,h
.s:     nop
        nop
        nop
        djnz .s
        in a,(P_PIOB)
        and 10h
        ld e,a
        ld a,(ms_idle)
        cp e
        jr nz,.ferr
        srl c                   ; 7 bits were shifted into bits 7..1
        ld a,c
        or a                    ; NC = good byte
        ret
.ferr:  ld a,0FFh
        scf
        ret

; ---- turn accumulated motion into cursor steps (called once per frame)
; sets mv_u/mv_d/mv_l/mv_r for one step when enough motion has built up,
; and mouse button edges into ms_click (bit1 = left, bit0 = right)
MS_STEPX equ 12
MS_STEPY equ 12
mouse_frame:
        xor a
        ld (ms_click),a
        ld (ms_mu),a
        ld (ms_md),a
        ld (ms_ml),a
        ld (ms_mr),a
        ld a,(ms_ok)
        or a
        ret z
        ld a,(ms_btn)
        ld b,a
        ld a,(ms_obtn)
        cpl
        and b
        ld (ms_click),a
        ld a,b
        ld (ms_obtn),a
        ld hl,(ms_ax)
        call .clamp
        ld (ms_ax),hl
        ld hl,(ms_ay)
        call .clamp
        ld (ms_ay),hl
        ; x
        ld hl,(ms_ax)
        call .step              ; A = +1 / -1 / 0, HL updated
        ld (ms_ax),hl
        or a
        jr z,.y
        ld hl,ms_mr
        jp p,.xs
        ld hl,ms_ml
.xs:    ld (hl),1
.y:     ld hl,(ms_ay)
        call .step
        ld (ms_ay),hl
        or a
        ret z
        ld hl,ms_md
        jp p,.ys
        ld hl,ms_mu
.ys:    ld (hl),1
        ret
.step:  ; HL signed accumulator; step size ms_sens
        ld a,(ms_sens)
        ld e,a
        ld d,0
        bit 7,h
        jr nz,.neg
        push hl
        or a
        sbc hl,de
        jr c,.none
        pop af
        ld a,1
        ret
.neg:   push hl
        add hl,de
        bit 7,h
        jr z,.none0
        pop af
        ld a,-1
        ret
.none0: pop hl
        xor a
        ret
.none:  pop hl
        xor a
        ret
.clamp: ; keep |HL| <= 3*step so fast flicks don't run away
        ld a,(ms_sens)
        ld e,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        bit 7,h
        jr nz,.cn
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        ret
.cn:    push hl
        add hl,de
        bit 7,h
        pop hl
        ret z
        ld hl,0
        or a
        sbc hl,de
        ret
