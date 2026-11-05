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
MS_BIT  equ 210                 ; djnz count: 77 T loop + 13*(n-1)+8 = 2802 T
MS_HALF equ 104                 ; first sample lands 1.5 bits after the edge

; measure the idle level: sample the line for ~20 ms; if it never moves
; the idle level is whatever it reads.  ms_ok = 0 until a valid packet.
mouse_init:
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
        ld de,120               ; 120 * ~70 T ~ 3 bit times
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
ms_rx:  ld b,MS_HALF
.h:     djnz .h
        ld c,0
        ld d,7
.bit:   ld b,MS_BIT
.d:     djnz .d
        in a,(P_PIOB)
        and 10h
        ld e,a
        ld a,(ms_idle)
        xor e                   ; 0 when the line is at mark (= data bit 1)
        sub 1                   ; carry if mark
        rr c
        dec d
        jr nz,.bit
        ; stop bit must be mark, else we locked on mid-byte: framing error
        ld b,MS_BIT
.s:     djnz .s
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
