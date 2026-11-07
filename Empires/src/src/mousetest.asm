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
        ld a,0CFh               ; PIO A: mode 3, all inputs (joystick / parallel devices)
        out (P_PIOAC),a
        ld a,0FFh
        out (P_PIOAC),a
        ld a,07h
        out (P_PIOAC),a
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
        ; ---- which line is the mouse on?  the busier of B3 and B4 ----
        ld a,(cntB+4)           ; B3 changes
        ld b,a
        ld a,(cntB+3)           ; B4 changes
        ld c,a
        cp b
        jr c,.b3
        cp 4
        jr c,.same
        ld a,10h
        jr .pick
.b3:    ld a,b
        cp 4
        jr c,.same
        ld a,08h
.pick:  ld hl,ms_mask
        cp (hl)
        jr z,.same
        ld (ms_cand),a
        ld b,200                ; find a quiet moment: that level is idle
.qt:    push bc
        call ms_quiet
        pop bc
        jr nc,.got
        djnz .qt
        jr .same
.got:   ld (ms_idle),a
        ld a,(ms_cand)
        ld (ms_mask),a
        call ms_setmask
.same:  xor a
        ld (ms_cand),a
        ; ---- phase 2: capture raw serial bytes on that line (~ 0.35 s) ----
        xor a
        ld (nraw),a
        ld bc,12000
.m:     push bc
        in a,(P_PIOB)
mt_s1 equ $+1
        and 10h
        ld hl,ms_idle
        cp (hl)
        jr z,.mn
        call ms_rx              ; start bit seen: receive one byte (C = framing error)
        jr nc,.ok
        ld a,0FFh               ; show a framing error as FF
.ok:    ld e,a
        ld a,(nraw)
        cp 24
        jr nc,.mn
        ld hl,rawbuf
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld (hl),e
        ld hl,nraw
        inc (hl)
.mn:    pop bc
        dec bc
        ld a,b
        or c
        jr nz,.m
        ei
        call status
        ld a,(nraw)
        or a
        jp z,loop
        ; print the bytes, then any Microsoft packets in them
        ld de,t_raw
        call print
        ld a,(ms_mask)
        cp 08h
        ld e,'3'
        jr z,.ln
        ld e,'4'
.ln:    call pch
        ld de,t_raw2
        call print
        ld hl,rawbuf
        ld a,(nraw)
        ld b,a
.pr:    push bc
        push hl
        ld a,(hl)
        call phex
        call space
        pop hl
        pop bc
        inc hl
        djnz .pr
        ld de,t_crlf
        call print
        ld hl,rawbuf
        ld a,(nraw)
        ld b,a
.pk:    ld a,b
        cp 3
        jp c,loop
        ld a,(hl)
        cp 0FFh
        jr z,.skip
        bit 6,a                 ; first byte of a packet has bit 6 set
        jr z,.skip
        inc hl
        ld a,(hl)
        dec hl
        bit 6,a
        jr nz,.skip
        push bc
        push hl
        call packet
        pop hl
        pop bc
        inc hl
        inc hl
        dec b
        dec b
.skip:  inc hl
        djnz .pk
        jp loop

; decode the packet at HL and print it
packet: ld a,(hl)
        ld (ms_b1),a
        inc hl
        ld a,(hl)
        ld (ms_b2),a
        inc hl
        ld a,(hl)
        ld (ms_b3),a
        ld de,t_pkt
        call print
        ld a,(ms_b1)            ; dx = X7 X6 (b1 bits 1-0) : b2 bits 5-0
        rrca
        rrca
        and 0C0h
        ld b,a
        ld a,(ms_b2)
        and 3Fh
        or b
        ld l,a
        rla
        sbc a,a
        ld h,a
        push hl
        ld de,t_dx
        call print
        pop hl
        call psdec
        ld a,(ms_b1)            ; dy = Y7 Y6 (b1 bits 3-2) : b3 bits 5-0
        rlca
        rlca
        rlca
        rlca
        and 0C0h
        ld b,a
        ld a,(ms_b3)
        and 3Fh
        or b
        ld l,a
        rla
        sbc a,a
        ld h,a
        push hl
        ld de,t_dy
        call print
        pop hl
        call psdec
        ld a,(ms_b1)
        bit 5,a
        jr z,.nl
        ld de,t_left
        call print
.nl:    ld a,(ms_b1)
        bit 4,a
        jr z,.nr
        ld de,t_right
        call print
.nr:    ld de,t_crlf
        jp print

key:    cp '2'
        jr z,.k2
        cp '5'
        jr z,.k5
        ld a,20h                ; leave the serial line at mark, speaker off
        out (P_PIOB),a
        ld a,0Fh                ; PIO A back to output mode for the printer
        out (P_PIOAC),a
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
         db "Move the mouse and press its buttons.  A Microsoft mouse on the serial",13,10
         db "port should make B4 count and show serial bytes.  If B4 stays at 00,",13,10
         db "the mouse may need power from the port: press 2 and/or 5 to switch",13,10
         db "PIO B outputs 2 (DTR) and 5 (TXD), then move it again.  A mouse that",13,10
         db "has just been powered usually sends 4D ('M').  Other keys quit.",13,10,"$"
t_cpu:   db "CPU clock: $"
t_unknown: db "not measured (no frame flag)$"
t_mhz:   db " MHz$"
t_bit:   db "   serial bit delay: $"
t_idle:  db "   serial line idle level (B4): $"
t_head:  db 13,10,13,10,"Changes seen on each input bit (moving the mouse should make B4 or B3 count;",13,10
         db "B7 always counts - it is the screen frame signal):",13,10
         db "B7 B6 B5 B4 B3 B2 B1 B0 | A7 A6 A5 A4 A3 A2 A1 A0",13,10,"$"
t_pkt:   db "  mouse packet:$"
t_raw:   db 13,10,"serial bytes on B$"
t_raw2:  db ": $"
t_dx:    db "   dx $"
t_dy:    db "   dy $"
t_left:  db "   LEFT$"
t_right: db "   RIGHT$"
t_out:   db "PIO B output now $"
t_bye:   db 13,10,"$"
t_crlf:  db 13,10,"$"
pb_out:  db 20h
nraw:    db 0
rawbuf:  ds 24
lastB:   db 0
lastA:   db 0
cntB:    ds 8
cntA:    ds 8
        include "mouse.asm"
ms_mask:    db 10h
ms_cand:    db 0
ms_other:   db 0
ms_last:    db 0
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

ms_sites: dw ms_s1,ms_s2,ms_s3,ms_s4,ms_s5,ms_s6,ms_s7,mt_s1,0
