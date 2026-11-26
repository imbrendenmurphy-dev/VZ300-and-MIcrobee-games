; A = Microbee matrix key (A..Z = 1..26, SPACE = 55, RETURN = 59).
; Tests one key through the 6545 update-address / light-pen latch.
; NZ if held.  Preserves BC, DE, HL.
scan_key:
        push bc
        push de
        ld c,a
        rrca
        rrca
        rrca
        rrca
        and 3
        ld d,a
        ld a,18
        out ($0C),a
        ld a,d
        out ($0D),a
        ld a,19
        out ($0C),a
        ld a,c
        rlca
        rlca
        rlca
        rlca
        out ($0D),a
        ld a,1
        out ($0B),a
        ld a,16
        out ($0C),a
        in a,($0D)
        ld a,31
        out ($0C),a
        out ($0D),a
        ld b,64
.wait:  in a,($0C)
        bit 7,a
        jr nz,.sample
        djnz .wait
        xor a
        jr .done
.sample:in a,($0C)
        and $40
.done:  ld d,a
        xor a
        out ($0B),a
        ld a,16
        out ($0C),a
        in a,($0D)
        ld a,d
        or a
        pop de
        pop bc
        ret
