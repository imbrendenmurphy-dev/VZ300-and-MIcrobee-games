; =====================================================================
;  speech.asm : 1-bit digitised speech at 15556 Hz (one bit per 228T)
;  HL = bitstream (MSB first), DE = number of bytes, C = latch base value
;  Music is silent while speech plays (stop-time), screen is static.
; =====================================================================
speech_play:
        di
.byte:
        ld b,(hl)               ; 7
        inc hl                  ; 6
        ; bit 7
        rlc b
        sbc a,a
        and $21
        xor c
        ld (LATCH),a
        WAIT 228-13-36
        REPT 6
        rlc b
        sbc a,a
        and $21
        xor c
        ld (LATCH),a
        WAIT 228-36
        ENDR
        rlc b
        sbc a,a
        and $21
        xor c
        ld (LATCH),a
        WAIT 228-36-24
        dec de                  ; 6
        ld a,d                  ; 4
        or e                    ; 4
        jp nz,.byte             ; 10
        ld a,c
        ld (LATCH),a
        ret
