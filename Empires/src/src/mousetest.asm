; ===================================================================
;  MOUSE.COM - serial mouse diagnostic for EMPIRES (Microbee Premium Plus)
;  Shows the idle level of the RS232 input (PIO B bit 4) and every
;  Microsoft-mouse packet received: raw bytes, dx, dy, buttons.
;  Also counts line transitions, so you can see if anything arrives at all.
;  Press any key to return to CP/M.
; ===================================================================
        include "defs.inc"
        org 0100h
        ld de,t_hello
        ld c,9
        call 5
        di
        call mouse_init
        ei
        ld de,t_idle
        ld c,9
        call 5
        ld a,(ms_idle)
        call phex
        ld de,t_crlf
        ld c,9
        call 5
loop:   ld c,11                 ; key pressed?
        call 5
        or a
        jr nz,done
        ; listen for ~1/4 s with interrupts off, counting transitions
        di
        ld hl,0
        ld (trans),hl
        ld bc,6000
.l:     push bc
        in a,(P_PIOB)
        and 10h
        ld hl,lastlv
        cp (hl)
        jr z,.s
        ld (hl),a
        ld hl,(trans)
        inc hl
        ld (trans),hl
.s:     xor a
        ld (ms_ok),a
        call mouse_poll
        pop bc
        ld a,(ms_ok)
        or a
        jr nz,.got
        dec bc
        ld a,b
        or c
        jr nz,.l
        ei
        ld hl,(trans)
        ld a,h
        or l
        jr z,loop
        ld de,t_trans
        ld c,9
        call 5
        ld a,(trans+1)
        call phex
        ld a,(trans)
        call phex
        ld de,t_crlf
        ld c,9
        call 5
        jr loop
.got:   ei
        ld de,t_pkt
        ld c,9
        call 5
        ld a,(ms_b1)
        call phex
        call space
        ld a,(ms_b2)
        call phex
        call space
        ld a,(ms_b3)
        call phex
        ld de,t_dx
        ld c,9
        call 5
        ld a,(ms_ax)
        call phex
        ld de,t_dy
        ld c,9
        call 5
        ld a,(ms_ay)
        call phex
        ld de,t_btn
        ld c,9
        call 5
        ld a,(ms_btn)
        call phex
        ld de,t_crlf
        ld c,9
        call 5
        ld hl,0
        ld (ms_ax),hl
        ld (ms_ay),hl
        jp loop
done:   ld c,1                  ; eat the key
        call 5
        rst 0
phex:   push af
        rrca
        rrca
        rrca
        rrca
        call .n
        pop af
.n:     and 0Fh
        add a,'0'
        cp '9'+1
        jr c,.p
        add a,7
.p:     ld e,a
        ld c,2
        jp 5
space:  ld e,' '
        ld c,2
        jp 5
t_hello: db 13,10,"EMPIRES serial mouse test (1200 baud, 7N1, Microsoft mouse)",13,10
         db "Move the mouse and press its buttons. Any key quits.",13,10,"$"
t_idle:  db "Idle level of PIO B bit 4: $"
t_trans: db "line changes but no valid packet: $"
t_pkt:   db "packet $"
t_dx:    db "  dx $"
t_dy:    db "  dy $"
t_btn:   db "  buttons(L=2,R=1) $"
t_crlf:  db 13,10,"$"
trans:   dw 0
lastlv:  db 0
        include "mouse.asm"
ms_idle:    db 0
ms_ok:      db 0
ms_btn:     db 0
ms_obtn:    db 0
ms_click:   db 0
ms_b1:      db 0
ms_b2:      db 0
ms_b3:      db 0
ms_ax:      dw 0
ms_ay:      dw 0
ms_sens:    db 12
ms_mu:      db 0
ms_md:      db 0
ms_ml:      db 0
ms_mr:      db 0
