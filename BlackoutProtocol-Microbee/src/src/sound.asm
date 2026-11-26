; ---------------------------------------------------------------------------
; Sound on the 1-bit speaker (PIO B bit 6, port 02).  Everything here is
; played inline with interrupts off, so the picture holds while it plays:
;  * effects - a few milliseconds, during play
;  * MERIDIAN's speech - 1-bit delta-sigma samples from disk D, ~15.8 kHz
;  * music - two square-wave channels, on the title, wrist-deck, endings and
;    as short stings
; ---------------------------------------------------------------------------
SPK     equ $02
SP_DELAY equ 4                  ; speech: 112 T a bit + 46 T a byte = ~118 (28.7 kHz)

; ------------------------------------------------------------- music
; HL = tune (dw passes ; db period1, period2 ... dw 0).  A = key that stops it
; (0 = play to the end).  Returns NZ if stopped by the key.
mus_play:
        ld (mus_key),a
.ev:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        ret z
        push de
        pop ix                  ; IX = passes
        ld a,(hl)               ; channel 1
        inc hl
        or a
        ld b,$40
        jr nz,.c1
        ld b,0                  ; silent: no flips
        ld a,255
.c1:    ld (mus_p1),a
        ld a,b
        ld (.x1+1),a
        ld a,(hl)               ; channel 2
        inc hl
        or a
        ld b,$40
        jr nz,.c2
        ld b,0
        ld a,255
.c2:    ld (mus_p2),a
        ld a,b
        ld (.x2+1),a
        push hl
        ld a,(mus_p1)
        ld h,a
        ld b,a
        ld a,(mus_p2)
        ld l,a
        ld c,a
        ld de,0                 ; D = channel 1 level, E = channel 2 level
; one pass = 122 T: channel 1 on the speaker for half of it, channel 2 the other
.it:    ld a,d                  ; 4
        out (SPK),a             ; 11
        djnz .a                 ; 13 (8)
        ld b,h
        ld a,d
.x1:    xor $40
        ld d,a
.a:     dec ix                  ; 10
        ld a,ixh                ; 8
        or ixl                  ; 8
        jr z,.done              ; 7
        ld a,e                  ; 4
        out (SPK),a             ; 11
        dec c                   ; 4
        jr nz,.b                ; 12 (7)
        ld c,l
        ld a,e
.x2:    xor $40
        ld e,a
.b:     nop                     ; balance the two halves
        nop
        nop
        nop
        nop
        jp .it                  ; 10
.done:  xor a
        out (SPK),a
        pop hl
        ld a,(mus_key)
        or a
        jr z,.ev
        call scan_key
        ret nz                  ; NZ: stopped
        ld a,(mus_key2)
        or a
        jp z,.ev
        call scan_key
        jp z,.ev
        ret

; A tune that loops until key A is pressed.
mus_loop:
        ld (mus_lkey),a
        ld a,b                  ; B = a second key that also stops it (0 = none)
        ld (mus_key2),a
        ld a,(mus_lkey)
        ld (mus_lptr),hl
.l:     ld hl,(mus_lptr)
        ld a,(mus_lkey)
        call mus_play
        jr z,.l
        xor a
        ld (mus_key2),a
        or 1
        ret

; ------------------------------------------------------------- speech
; A = line (SPK_* below).  Silent if disk D isn't there.
say:
        ld b,a
        ld a,(speech_ok)
        or a
        ret z
        ld a,b
        ld l,a
        add a,a
        add a,a
        add a,l                 ; * 5
        ld hl,speech_far
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)               ; block
        call bank_port
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ex de,hl
        call sp_play            ; (in upper RAM: the block is switched in)
        xor a
        out (SPK),a
        ret

; ------------------------------------------------------------- effects
; B = half-cycles, C = delay per half-cycle (bigger = lower).
beep:   ld a,(spk)
.l:     xor $40
        out (SPK),a
        push bc
        ld b,c
.d:     djnz .d
        pop bc
        djnz .l
        ld (spk),a
        ret

; A sweep: B steps of 2 half-cycles, delay C, changing by D each step.
sweep:  ld a,(spk)
.s:     push bc
        ld b,2
.h:     xor $40
        out (SPK),a
        push bc
        ld b,c
.d:     djnz .d
        pop bc
        djnz .h
        pop bc
        ld e,a
        ld a,c
        add a,d
        ld c,a
        ld a,e
        djnz .s
        ld (spk),a
        ret

; Noise: B bursts, each held C loops.
noise:  ld a,r
        ld e,a
.n:     ld a,e                  ; a little LFSR
        rrca
        rrca
        xor e
        add a,b
        ld e,a
        and $40
        out (SPK),a
        push bc
        ld b,c
.d:     djnz .d
        pop bc
        djnz .n
        xor a
        out (SPK),a
        ret

sfx_found:
        ld bc,$3030
        call beep
        ld bc,$3020
        jp beep
sfx_blip:
        ld bc,$1818
        jp beep
sfx_tick:
        ld bc,$0812
        jp beep
sfx_deny:
        ld bc,$2060
        jp beep
sfx_zap:
        ld bc,$1008
        call beep
        ld bc,$1014
        jp beep
sfx_step:
        ld bc,$0610
        jp noise
sfx_vault:
        ld b,18                 ; rising whoosh
        ld c,60
        ld d,-3
        jp sweep
sfx_land:
        ld bc,$1028
        jp noise
sfx_hum:                        ; lifts and pads: a low motor click a frame
        ld bc,$0260
        jp beep
sfx_sleep:
        ld b,24                 ; robots powering down
        ld c,20
        ld d,4
        jp sweep
sfx_die:
        ld b,40                 ; falling tone, then static
        ld c,30
        ld d,3
        call sweep
        ld bc,$6018
        jp noise

; Speech line numbers (order as in tools/speech.py).
SPK_WELCOME equ 0
SPK_EIGHT equ 1
SPK_INTRUDER equ 2
SPK_AGAIN equ 3
SPK_DENIED equ 4
SPK_KEYOK equ 5
SPK_HOUR equ 6
SPK_CANCEL equ 7
SPK_DARK equ 8

        include "music.inc"
