; print_bcd: HL -> BCD bytes, B = count, D/E position (BG + queue)
print_bcd:
        push hl
        push bc
        push de
        ld a,b
        add a,a
        ld b,a
        ld c,5
        call queue_rect
        pop de
        pop bc
        pop hl
.l:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and $0F
        add a,'0'
        push hl
        push bc
        push de
        call putchar
        pop de
        pop bc
        pop hl
        inc d
        ld a,(hl)
        and $0F
        add a,'0'
        push hl
        push bc
        push de
        call putchar
        pop de
        pop bc
        pop hl
        inc d
        inc hl
        djnz .l
        ret

; print_dec2: A = 0..99 as two digits at D/E (BG + queue)
print_dec2:
        push af
        push de
        ld b,2
        ld c,5
        call queue_rect
        pop de
        pop af
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        push af
        ld a,b
        push de
        call putchar
        pop de
        inc d
        pop af
        jp putchar

; print centered: HL string, E row
print_c:
        push hl
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.d
        inc b
        inc hl
        jr .l
.d:     ld a,32
        sub b
        srl a
        ld d,a
        pop hl
        jp print

