; ===========================================================================
;  text.asm - 3x5 font printing into the back buffer (4x6 cells, 1 byte wide)
;  Control codes in strings: 0 end, 1 newline, 2 c = set fg colour, 3 c = set bg
; ===========================================================================

; set colours: B = fg, C = bg
text_colors:
            ld a,b
            ld (txt_fg),a
            ld a,c
            ld (txt_bg),a
build_ttab:
            push bc
            push de
            push hl
            ld hl,ttab
            ld d,0
.p:         ld e,0
            ld c,4
.px:        ld a,d
            and c
            ld a,(txt_bg)
            jr z,.b
            ld a,(txt_fg)
.b:         sla e
            sla e
            or e
            ld e,a
            srl c
            jr nz,.px
            sla e
            sla e
            ld a,(txt_bg)
            or e
            ld (hl),a
            inc hl
            inc d
            ld a,d
            cp 8
            jr nz,.p
            pop hl
            pop de
            pop bc
            ret

; print string: HL = text, C = x (byte column), D = y (pixel row)
print_at:
            ld a,c
            ld (txt_x0),a
.loop:      ld a,(hl)
            inc hl
            or a
            ret z
            cp 1
            jr z,.nl
            cp 2
            jr z,.fg
            cp 3
            jr z,.bgc
            push hl
            push bc
            push de
            call draw_char
            pop de
            pop bc
            pop hl
            inc c
            jr .loop
.nl:        ld a,(txt_x0)
            ld c,a
            ld a,d
            add a,6
            ld d,a
            jr .loop
.fg:        ld a,(hl)
            inc hl
            ld (txt_fg),a
            call build_ttab
            jr .loop
.bgc:       ld a,(hl)
            inc hl
            ld (txt_bg),a
            call build_ttab
            jr .loop

; draw_char: A = char, C = x, D = y   (clobbers all)
draw_char:
            call world_char
            jp native_battle_char

; centred print: HL = text (no control codes), D = y, B = field x, C = field width
print_centre:
            push hl
            push bc
            call strlen
            pop bc
            ld e,a
            ld a,c
            sub e
            srl a
            add a,b
            ld c,a
            pop hl
            jp print_at

strlen:     ld b,0
.l:         ld a,(hl)
            or a
            ld a,b
            ret z
            inc hl
            inc b
            jr .l

; print a single char at C,D with current colours
putc:       jp draw_char
