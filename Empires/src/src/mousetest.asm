; ===================================================================
;  MOUSE.COM - serial mouse and port test for EMPIRES (Premium Plus)
;
;  Shows, twice a second:
;    - how many times each input bit of PIO port B (02h) and PIO port A
;      (00h) changed.  A Microsoft mouse on the serial port should make
;      bit B4 count up while it moves or a button is pressed.
;    - any Microsoft-mouse packets decoded from bit B4 (1200 baud, 7N1).
;  Also measures the CPU clock, which sets the serial bit timing.
;  Keys:  2 / 5  toggle PIO B output bits 2 (DTR) and 5 (TXD), in case the
;          mouse takes its power from those lines.  Any other key quits.
; ===================================================================
        include "defs.inc"
        org 0100h
        ld sp,0F00h
        ld de,t_hello
        call print
        di
        call mouse_init         ; calibrates and finds the line's idle level
        ld a,(pb_out)
        out (P_PIOB),a
        ei
        ; CPU clock = frame count N * 48 T * 50 Hz = N * 2400 Hz -> hundredths of MHz = N*24/100
        ld de,t_cpu
        call print
        ld hl,(ms_frameN)
        ld a,h
        or l
        jr nz,.cn
        ld de,t_unknown
        call print
        jr .cd
.cn:    ld de,6                 ; hundredths of MHz = N * 24 / 100 = N * 6 / 25
        call mul16
        ld c,25
        call div16
        ld c,100
        call div16              ; HL = MHz, A = remainder
        push af
        call pdec
        ld e,'.'
        call pch
        pop af
        ld l,a
        ld h,0
        ld a,l
        cp 10
        jr nc,.c2
        ld e,'0'
        call pch
.c2:    call pdec
        ld de,t_mhz
        call print
.cd:    ld de,t_bit
        call print
        ld a,(ms_bitn)
        ld l,a
        ld h,0
        call pdec
        ld de,t_idle
        call print
        ld a,(ms_idle)
        or a
        ld e,'0'
        jr z,.i0
        ld e,'1'
.i0:    call pch
        ld de,t_head
        call print

loop:   ld c,6                  ; key?
        ld e,0FFh
        call 5
        or a
        jp nz,key
        ; ---- phase 1: count bit changes on both ports (~ 0.4 s) ----
        di
        ld hl,cntB
        ld b,16
.z:     ld (hl),0
        inc hl
        djnz .z
        in a,(P_PIOB)
        ld (lastB),a
        in a,(P_PIOA)
        ld (lastA),a
        ld bc,7000
.s:     push bc
        in a,(P_PIOB)
        ld hl,lastB
        ld d,a
        xor (hl)
        ld (hl),d
        jr z,.sa
        ld hl,cntB
        call bump
.sa:    in a,(P_PIOA)
        ld hl,lastA
        ld d,a
        xor (hl)
        ld (hl),d
        jr z,.sn
        ld hl,cntA
        call bump
.sn:    pop bc
        dec bc
        ld a,b
        or c
        jr nz,.s
        ; ---- phase 2: listen for mouse packets (~ 0.2 s) ----
        xor a
        ld (ms_ok),a
        ld bc,12000
.m:     push bc
        call mouse_poll
        pop bc
        ld a,(ms_ok)
        or a
        jr nz,.pkt
        dec bc
        ld a,b
        or c
        jr nz,.m
        ei
        call status
        jp loop
.pkt:   ei
        call status
        ld de,t_pkt
        call print
        ld a,(ms_b1)
        call phex
        call space
        ld a,(ms_b2)
        call phex
        call space
        ld a,(ms_b3)
        call phex
        ld de,t_dx
        call print
        ld hl,(ms_ax)
        call psdec
        ld de,t_dy
        call print
        ld hl,(ms_ay)
        call psdec
        ld a,(ms_btn)
        bit 1,a
        jr z,.nl
        ld de,t_left
        call print
.nl:    ld a,(ms_btn)
        bit 0,a
        jr z,.nr
        ld de,t_right
        call print
.nr:    ld de,t_crlf
        call print
        ld hl,0
        ld (ms_ax),hl
        ld (ms_ay),hl
        jp loop

key:    cp '2'
        jr z,.k2
        cp '5'
        jr z,.k5
        ld a,20h                ; leave the serial line at mark, speaker off
        out (P_PIOB),a
        ld de,t_bye
        call print
        rst 0
.k2:    ld a,(pb_out)
        xor 04h
        jr .ko
.k5:    ld a,(pb_out)
        xor 20h
.ko:    ld (pb_out),a
        out (P_PIOB),a
        ld de,t_crlf
        call print
        ld de,t_out
        call print
        ld a,(pb_out)
        call pbin
        ld de,t_crlf
        call print
        jp loop

; changed bits in A (bit 7 first): bump the counters at HL (8 bytes, B7..B0), cap 99
bump:   ld b,8
.l:     rla
        jr nc,.n
        ld c,a
        ld a,(hl)
        cp 99
        jr z,.c
        inc (hl)
.c:     ld a,c
.n:     inc hl
        djnz .l
        ret

; status line, rewritten in place with CR
status: ld e,13
        call pch
        ld hl,cntB
        ld b,8
.b:     push bc
        push hl
        ld l,(hl)
        ld h,0
        call p2dec
        call space
        pop hl
        pop bc
        inc hl
        djnz .b
        ld e,'|'
        call pch
        call space
        ld b,8
.a:     push bc
        push hl
        ld l,(hl)
        ld h,0
        call p2dec
        call space
        pop hl
        pop bc
        inc hl
        djnz .a
        ret

; ---- output helpers ----
print:  ld c,9
        jp 5
pch:    push bc
        push de
        push hl
        ld c,2
        call 5
        pop hl
        pop de
        pop bc
        ret
space:  ld e,' '
        jr pch
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
        jr pch
pbin:   ld b,8
.l:     rla
        push af
        ld e,'0'
        jr nc,.z
        ld e,'1'
.z:     push bc
        call pch
        pop bc
        pop af
        djnz .l
        ret
p2dec:  ld a,l                  ; L = 0..99 as two digits
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10
        push af
        ld e,b
        call pch
        pop af
        add a,'0'
        ld e,a
        jr pch
psdec:  bit 7,h                 ; signed HL
        jr z,pdec
        ld e,'-'
        call pch
        ld a,h
        cpl
        ld h,a
        ld a,l
        cpl
        ld l,a
        inc hl
pdec:   ld c,10                 ; unsigned HL
        call div16
        push af
        ld a,h
        or l
        call nz,pdec
        pop af
        add a,'0'
        ld e,a
        jr pch
div16:  ; HL = HL / C, A = remainder
        xor a
        ld b,16
.l:     add hl,hl
        rla
        cp c
        jr c,.n
        sub c
        inc l
.n:     djnz .l
        ret
mul16:  ; HL = HL * DE (low 16 bits)
        push bc
        ld b,h
        ld c,l
        ld hl,0
.l:     ld a,d
        or e
        jr z,.d
        add hl,bc
        dec de
        jr .l
.d:     pop bc
        ret

t_hello: db 13,10,"EMPIRES serial mouse and port test",13,10
         db "Move the mouse and press its buttons.  2 / 5 toggle PIO B bits 2 and 5",13,10
         db "(mouse power).  Any other key returns to A>.",13,10,"$"
t_cpu:   db "CPU clock: $"
t_unknown: db "not measured (no frame flag)$"
t_mhz:   db " MHz$"
t_bit:   db "   serial bit delay: $"
t_idle:  db "   serial line idle level (B4): $"
t_head:  db 13,10,13,10,"Changes seen on each input bit (moving the mouse should make B4 count;",13,10
         db "B7 always counts - it is the screen frame signal):",13,10
         db "B7 B6 B5 B4 B3 B2 B1 B0 | A7 A6 A5 A4 A3 A2 A1 A0",13,10,"$"
t_pkt:   db 13,10,"mouse packet $"
t_dx:    db "   dx $"
t_dy:    db "   dy $"
t_left:  db "   LEFT$"
t_right: db "   RIGHT$"
t_out:   db "PIO B output now $"
t_bye:   db 13,10,"$"
t_crlf:  db 13,10,"$"
pb_out:  db 20h
lastB:   db 0
lastA:   db 0
cntB:    ds 8
cntA:    ds 8
        include "mouse.asm"
ms_idle:    db 0
ms_bitn:    db 110
ms_half:    db 55
ms_frameN:  dw 0
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
