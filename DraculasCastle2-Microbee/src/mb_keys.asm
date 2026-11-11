mb_keytest:
        push bc
        ld b,a
        ld a,$12
        out ($0C),a
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and $03
        out ($0D),a
        ld a,$13
        out ($0C),a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        and $F0
        out ($0D),a
        ld a,$10
        out ($0C),a
        in a,($0D)          ; clear any pending light pen strobe
        ld a,$1F
        out ($0C),a
        out ($0D),a
        nop
        ld b,0
.w:     in a,($0C)
        bit 7,a
        jr nz,.d
        djnz .w
.d:     and $40
        pop bc
        ret


mb_row_FE:
            push bc
            push de
            push hl
            ld c,$3F
            ld a,1
            out ($0B),a
            ld a,20
            call mb_keytest
            jr z,.k0
            res 0,c
.k0:
            ld a,23
            call mb_keytest
            jr z,.k1
            res 1,c
.k1:
            ld a,56
            call mb_keytest
            jr z,.a1
            res 1,c
.a1:
            ld a,5
            call mb_keytest
            jr z,.k3
            res 3,c
.k3:
            ld a,17
            call mb_keytest
            jr z,.k4
            res 4,c
.k4:
            ld a,18
            call mb_keytest
            jr z,.k5
            res 5,c
.k5:
            xor a
            out ($0B),a
            ld a,c
            pop hl
            pop de
            pop bc
            ret

mb_row_FD:
            push bc
            push de
            push hl
            ld c,$3F
            ld a,1
            out ($0B),a
            ld a,7
            call mb_keytest
            jr z,.k0
            res 0,c
.k0:
            ld a,19
            call mb_keytest
            jr z,.k1
            res 1,c
.k1:
            ld a,58
            call mb_keytest
            jr z,.a1
            res 1,c
.a1:
            ld a,4
            call mb_keytest
            jr z,.k3
            res 3,c
.k3:
            ld a,62
            call mb_keytest
            jr z,.a3
            res 3,c
.a3:
            ld a,1
            call mb_keytest
            jr z,.k4
            res 4,c
.k4:
            ld a,59
            call mb_keytest
            jr z,.a4
            res 4,c
.a4:
            ld a,6
            call mb_keytest
            jr z,.k5
            res 5,c
.k5:
            xor a
            out ($0B),a
            ld a,c
            pop hl
            pop de
            pop bc
            ret

mb_row_EF:
            push bc
            push de
            push hl
            ld c,$3F
            ld a,1
            out ($0B),a
            ld a,14
            call mb_keytest
            jr z,.k0
            res 0,c
.k0:
            ld a,55
            call mb_keytest
            jr z,.k4
            res 4,c
.k4:
            ld a,13
            call mb_keytest
            jr z,.k5
            res 5,c
.k5:
            xor a
            out ($0B),a
            ld a,c
            pop hl
            pop de
            pop bc
            ret

mb_row_BF:
            push bc
            push de
            push hl
            ld c,$3F
            ld a,1
            out ($0B),a
            ld a,25
            call mb_keytest
            jr z,.k0
            res 0,c
.k0:
            ld a,15
            call mb_keytest
            jr z,.k1
            res 1,c
.k1:
            ld a,52
            call mb_keytest
            jr z,.k2
            res 2,c
.k2:
            ld a,9
            call mb_keytest
            jr z,.k3
            res 3,c
.k3:
            ld a,16
            call mb_keytest
            jr z,.k4
            res 4,c
.k4:
            ld a,21
            call mb_keytest
            jr z,.k5
            res 5,c
.k5:
            xor a
            out ($0B),a
            ld a,c
            pop hl
            pop de
            pop bc
            ret

mb_row_7F:
            push bc
            push de
            push hl
            ld c,$3F
            ld a,1
            out ($0B),a
            ld a,8
            call mb_keytest
            jr z,.k0
            res 0,c
.k0:
            ld a,12
            call mb_keytest
            jr z,.k1
            res 1,c
.k1:
            ld a,11
            call mb_keytest
            jr z,.k3
            res 3,c
.k3:
            ld a,10
            call mb_keytest
            jr z,.k5
            res 5,c
.k5:
            xor a
            out ($0B),a
            ld a,c
            pop hl
            pop de
            pop bc
            ret

mb_row_F7:
            push bc
            push de
            push hl
            ld c,$3F
            ld a,1
            out ($0B),a
            ld a,37
            call mb_keytest
            jr z,.k0
            res 0,c
.k0:
            ld a,34
            call mb_keytest
            jr z,.k1
            res 1,c
.k1:
            ld a,35
            call mb_keytest
            jr z,.k3
            res 3,c
.k3:
            ld a,33
            call mb_keytest
            jr z,.k4
            res 4,c
.k4:
            ld a,36
            call mb_keytest
            jr z,.k5
            res 5,c
.k5:
            xor a
            out ($0B),a
            ld a,c
            pop hl
            pop de
            pop bc
            ret

mb_any:     push bc
            ld b,$3F
            call mb_row_FE
            and b
            ld b,a
            call mb_row_FD
            and b
            ld b,a
            call mb_row_EF
            and b
            ld b,a
            call mb_row_BF
            and b
            ld b,a
            call mb_row_7F
            and b
            ld b,a
            call mb_row_F7
            and b
            ld b,a
            pop bc
            ret
