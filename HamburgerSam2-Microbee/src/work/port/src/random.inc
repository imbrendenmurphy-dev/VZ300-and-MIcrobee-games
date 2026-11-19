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
; random below B (B >= 1) -> A
rand_n:
        push bc
        call random
        pop bc
.m:     cp b
        ret c
        sub b
        jr .m

; ---------------------------------------------------------------------
; BG helpers
; 