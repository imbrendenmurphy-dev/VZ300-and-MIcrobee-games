; =====================================================================
;  text.asm - 3x5 font (one byte per character), big 2x text, numbers
;  Strings: 0 ends; bytes 1-4 switch the ink to colour 0-3.
; =====================================================================

; A = ink, C = paper -> select the expansion table (tx_tabs, 16 x 8 bytes)
text_col:
            ld (tx_fg),a
            ld a,c
            ld (tx_bg),a
tx_rebuild:
            push hl
            push de
            ld a,(tx_fg)
            add a,a
            add a,a
            ld hl,tx_bg
            or (hl)
            add a,a
            add a,a
            add a,a                 ; (fg*4+bg)*8
            ld l,a
            ld h,0
            ld de,tx_tabs
            add hl,de
            ld (tx_ptr),hl
            pop de
            pop hl
            ret
tx_bits:    db 1,2,4                ; pixel 2 (right) .. pixel 0 (left)
tx_bg:      db 0

; HL = string, DE = destination (top row of the first character, stride 32)
print:
            ld a,(hl)
            inc hl
            or a
            ret z
            cp 5
            jr nc,.ch
            dec a
            ld (tx_fg),a
            push hl
            push de
            call tx_rebuild
            pop de
            pop hl
            jr print
.ch:        push hl
            call putc
            pop hl
            inc de
            jr print

; A = character, DE = destination (kept)
putc:
            cp 96
            jr c,.u
            sub 32
.u:         sub 32
            ld l,a
            ld h,0
            ld b,h
            ld c,l
            add hl,hl
            add hl,hl
            add hl,bc               ; *5
            ld bc,font
            add hl,bc
            push de
            ld b,5
.r:         ld a,(hl)
            inc hl
            push hl
            ld hl,(tx_ptr)
            add a,l
            ld l,a
            jr nc,.nc
            inc h
.nc:        ld a,(hl)
            ld (de),a
            ld a,e
            add a,32
            ld e,a
            jr nc,.n2
            inc d
.n2:        pop hl
            djnz .r
            pop de
            ret

; A = character, DE = destination: 2x size (2 bytes x 10 rows), tx colours
putc2:
            cp 96
            jr c,.u
            sub 32
.u:         sub 32
            ld l,a
            ld h,0
            ld b,h
            ld c,l
            add hl,hl
            add hl,hl
            add hl,bc
            ld bc,font
            add hl,bc
            push de
            ld b,5
.r:         push bc
            ld c,(hl)
            inc hl
            push hl
            ld a,c
            and 4
            call px2
            rlca
            rlca
            rlca
            rlca
            ld b,a
            ld a,c
            and 2
            call px2
            or b
            ld h,d
            ld l,e
            ld (hl),a
            ld a,c
            and 1
            call px2
            rlca
            rlca
            rlca
            rlca
            ld b,a
            xor a
            call px2                ; paper
            or b
            inc hl
            ld (hl),a
            dec hl
            ex de,hl
            ld bc,32
            add hl,bc
            ex de,hl
            ld a,(hl)
            ld (de),a
            inc hl
            inc de
            ld a,(hl)
            ld (de),a
            dec de
            ex de,hl
            ld bc,32
            add hl,bc
            ex de,hl
            pop hl
            pop bc
            djnz .r
            pop de
            ret
; Z -> paper, NZ -> ink ; A = that colour in two adjacent pixels (4 bits)
px2:        push de
            ld a,(tx_bg)
            jr z,.p
            ld a,(tx_fg)
.p:         ld e,a
            add a,a
            add a,a
            or e
            pop de
            ret

; HL = string, DE = destination: 2x size
print2:
            ld a,(hl)
            inc hl
            or a
            ret z
            cp 5
            jr nc,.ch
            dec a
            ld (tx_fg),a
            jr print2
.ch:        push hl
            call putc2
            pop hl
            inc de
            inc de
            jr print2

; HL -> 3-byte BCD, DE = destination: 6 digits + a fixed trailing 0
print_score:
            ld b,3
.l:         ld a,(hl)
            rrca
            rrca
            rrca
            rrca
            and 15
            add a,'0'
            push hl
            push bc
            call putc
            inc de
            pop bc
            pop hl
            ld a,(hl)
            and 15
            add a,'0'
            push hl
            push bc
            call putc
            inc de
            pop bc
            pop hl
            inc hl
            djnz .l
            ld a,'0'
            jp putc

; A = 0..99 (binary) -> two digits at DE
print_dec2:
            ld c,'0'-1
.t:         inc c
            sub 10
            jr nc,.t
            add a,10+'0'
            push af
            ld a,c
            call putc
            inc de
            pop af
            jp putc

; fill A bytes value C at DE in rows of 32, for B rows (box)
box:
            ld (.w+1),a
.r:         push bc
            push de
.w:         ld b,0
.c:         ld a,c
            ld (de),a
            inc de
            djnz .c
            pop de
            ex de,hl
            ld bc,32
            add hl,bc
            ex de,hl
            pop bc
            djnz .r
            ret
