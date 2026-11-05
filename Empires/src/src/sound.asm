; ===================================================================
;  sound.asm - single-bit beeper on PIO port B bit 6
;  Notes are kept short and separated by gaps (clean, not droney).
; ===================================================================

; tone: H = half-period (loop count), DE = number of half-cycles
tone:   ld a,(sound_on)
        or a
        ret z
        ld a,(spkbit)
.cyc:   xor 40h
        out (P_PIOB),a
        ld b,h
.w:     djnz .w
        dec de
        ld c,a
        ld a,d
        or e
        ld a,c
        jr nz,.cyc
        ld (spkbit),a
        ret

; play_tune: HL = list of (period, length) pairs, 0 terminates.
; period 1 = rest.  length is in ~10ms units.
play_tune:
        ld a,(hl)
        or a
        ret z
        inc hl
        ld c,(hl)
        inc hl
        push hl
        cp 1
        jr z,.rest
        ld (tperiod),a
        ld l,a
        call div_2500           ; HL = half-cycles per 10ms
        ld b,c
        ex de,hl
        ld hl,0
.acc:   add hl,de
        djnz .acc
        ex de,hl                ; DE = half-cycles
        ld a,(tperiod)
        ld h,a
        call tone
        ld b,6                  ; gap between notes
        call delay_ms_b
        pop hl
        jr play_tune
.rest:  ld b,c
        call delay_10ms_b
        pop hl
        jr play_tune

; HL = 2500 / L  (L = period, 1..255)   result in HL
div_2500:
        push bc
        ld c,l
        ld hl,2500
        ld de,0
.d:     ld a,l
        sub c
        ld l,a
        ld a,h
        sbc a,0
        ld h,a
        jr c,.e
        inc de
        jr .d
.e:     ex de,hl
        pop bc
        ret

delay_10ms_b:                   ; B * ~10ms
.o:     push bc
        ld bc,2400
.i:     dec bc
        ld a,b
        or c
        jr nz,.i
        pop bc
        djnz .o
        ret
delay_ms_b:                     ; B * ~1ms
.o:     push bc
        ld bc,240
.i:     dec bc
        ld a,b
        or c
        jr nz,.i
        pop bc
        djnz .o
        ret

; ---- effects ----
sfx_click:
        ld h,40
        ld de,10
        jp tone
sfx_build:
        ld h,90
        ld de,30
        call tone
        ld h,60
        ld de,40
        jp tone
sfx_error:
        ld h,200
        ld de,40
        call tone
        ld b,4
        call delay_ms_b
        ld h,240
        ld de,30
        jp tone
sfx_done:
        ld hl,tune_done
        jp play_tune
sfx_warn:
        ld hl,tune_warn
        jp play_tune

; note periods (loop counts; lower = higher pitch)
N_C4 equ 245
N_D4 equ 218
N_E4 equ 194
N_F4 equ 182
N_G4 equ 162
N_A4 equ 144
N_B4 equ 128
N_C5 equ 120
N_D5 equ 107
N_E5 equ 95
N_G5 equ 79
N_A5 equ 70
N_C6 equ 59
REST equ 1

tune_title:
        db N_C5,10, N_G4,6, N_C5,6, N_E5,10, N_G5,14, REST,6
        db N_E5,6, N_G5,6, N_A5,10, N_G5,8, N_E5,8, N_C5,14, REST,6
        db N_D5,8, N_E5,8, N_C5,8, N_G4,8, N_C5,20,0
tune_done:
        db N_C5,4, N_E5,4, N_G5,8,0
tune_warn:
        db N_E4,8, N_C4,12,0
tune_season:
        db N_G4,6, N_C5,6, N_E5,10,0
tune_grow:
        db N_E5,4, N_G5,4, N_C6,10,0
tune_start:
        db N_C5,6, N_C5,6, N_G5,12, N_E5,6, N_G5,18,0
