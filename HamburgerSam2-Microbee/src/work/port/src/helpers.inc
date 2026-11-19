; idx_byte: A = index, HL = table -> A = (HL+A)
idx_byte:
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        ret
; idx_ptr: A = index, HL = base, element size 1 -> HL = address
idx_ptr:
        add a,l
        ld l,a
        ret nc
        inc h
        ret
; idx_word: A = index, HL = table of words -> HL = word
idx_word:
        add a,a
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret
