; =====================================================================
;  text.asm - 3x5 font (one byte column a character) and a 2x font,
;  drawn into whichever buffer txt_base / txt_stride name. Lives in main
;  RAM so the game and the front end can both use it.
; =====================================================================

; select the game back buffer (40-byte rows, guard bytes skipped)
txt_game:
            ld hl,BB+BBG
            ld (txt_base),hl
            ld a,BBW
            ld (txt_stride),a
            ret

; set colours: D = ink, E = paper (0-3). Builds the 3-bit -> byte table.
txt_colour:
            ld a,d
            ld (txt_fg),a
            ld a,e
            ld (txt_bg),a
            ld hl,txt_tab
            ld c,0
.p:         ld e,c
            ld d,0
            ld b,3
.k:         ld a,d
            add a,a
            add a,a
            ld d,a
            ld a,(txt_bg)
            bit 2,e
            jr z,.z
            ld a,(txt_fg)
.z:         or d
            ld d,a
            sla e
            djnz .k
            ld a,d
            add a,a
            add a,a
            ld d,a
            ld a,(txt_bg)
            or d
            ld (hl),a
            inc hl
            inc c
            ld a,c
            cp 8
            jr nz,.p
            ret

; HL = address of byte column D, pixel row E in the text buffer
txt_addr:
            push de
            ld a,(txt_stride)
            ld l,a
            ld h,0
            ld a,e
            call mul16x8
            pop de
            ld a,d
            add a,l
            ld l,a
            jr nc,.n
            inc h
.n:         ld bc,(txt_base)
            add hl,bc
            ret

; DE = glyph pointer for character A
glyph:
            sub 32
            jr nc,.ok
            xor a
.ok:        cp 64
            jr c,.ok2
            xor a
.ok2:       ld l,a
            ld h,0
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,de
            ld de,font
            add hl,de
            ex de,hl
            ret

; draw_char: A = character, D = byte column, E = pixel row
draw_char:
            push de
            push af
            call txt_addr
            pop af
            push hl
            call glyph
            pop hl
            ld b,5
.r:         ld a,(de)
            inc de
            push hl
            ld hl,txt_tab
            add a,l
            ld l,a
            jr nc,.n
            inc h
.n:         ld a,(hl)
            pop hl
            ld (hl),a
            ld a,(txt_stride)
            add a,l
            ld l,a
            jr nc,.m
            inc h
.m:         djnz .r
            pop de
            ret

; draw_str: HL = string (0 ends), D = byte column, E = pixel row.
; Returns D = the column after the last character.
draw_str:
            ld a,(hl)
            or a
            ret z
            inc hl
            push hl
            call draw_char
            pop hl
            inc d
            jr draw_str

; draw_str centred on the 32-column line: HL = string, E = pixel row
draw_strc:
            push hl
            ld b,0
.l:         ld a,(hl)
            or a
            jr z,.e
            inc b
            inc hl
            jr .l
.e:         pop hl
            ld a,32
            sub b
            srl a
            ld d,a
            jr draw_str

; ---------------------------------------------------------------------
; 2x text: each character 2 byte columns x 10 rows
; A = byte (4 pixels) -> B = first 4 doubled pixels, C = last 4
dbl:
            push hl
            push de
            ld e,a
            ld hl,0
            ld b,4
.k:         add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            xor a
            sla e
            rla
            sla e
            rla
            ld d,a
            add a,a
            add a,a
            or d
            or l
            ld l,a
            djnz .k
            ld b,h
            ld c,l
            pop de
            pop hl
            ret

; draw_char2: A = character, D = byte column, E = pixel row
draw_char2:
            push de
            push af
            call txt_addr
            pop af
            push hl
            call glyph
            pop hl
            ld a,5
.r:         push af
            ld a,(de)
            inc de
            push hl
            ld hl,txt_tab
            add a,l
            ld l,a
            jr nc,.n
            inc h
.n:         ld a,(hl)
            pop hl
            call dbl
            ld (hl),b
            inc hl
            ld (hl),c
            dec hl
            call .down
            ld (hl),b
            inc hl
            ld (hl),c
            dec hl
            call .down
            pop af
            dec a
            jr nz,.r
            pop de
            ret
.down:      ld a,(txt_stride)
            add a,l
            ld l,a
            ret nc
            inc h
            ret

; draw_str2: HL = string, D = byte column, E = row (2 columns a char)
draw_str2:
            ld a,(hl)
            or a
            ret z
            inc hl
            push hl
            call draw_char2
            pop hl
            inc d
            inc d
            jr draw_str2

draw_str2c:
            push hl
            ld b,0
.l:         ld a,(hl)
            or a
            jr z,.e
            inc b
            inc hl
            jr .l
.e:         pop hl
            ld a,16
            sub b
            ld d,a
            jr draw_str2

; ---------------------------------------------------------------------
; numbers
; bcd_str: HL = BCD bytes (most significant first), B = bytes,
; DE = output buffer. Writes 2B digits and a 0.
bcd_str:
            ld a,(hl)
            rrca
            rrca
            rrca
            rrca
            and 15
            add a,'0'
            ld (de),a
            inc de
            ld a,(hl)
            and 15
            add a,'0'
            ld (de),a
            inc de
            inc hl
            djnz bcd_str
            xor a
            ld (de),a
            ret

; num3: A = 0-255 -> 3 decimal digits at DE (and a 0)
num3:
            ld c,100
            call .d
            ld c,10
            call .d
            add a,'0'
            ld (de),a
            inc de
            xor a
            ld (de),a
            ret
.d:         ld b,'0'
.l:         cp c
            jr c,.w
            sub c
            inc b
            jr .l
.w:         push af
            ld a,b
            ld (de),a
            inc de
            pop af
            ret

; droid number for type A -> 3 digits at DE
type_num:
            push de
            ld l,a
            ld h,0
            add hl,hl
            ld de,type_nums
            add hl,de
            ld e,(hl)
            inc hl
            ld d,(hl)               ; DE = number 0..999
            ex de,hl
            pop de
            ld bc,100
            call .d
            ld bc,10
            call .d
            ld a,l
            add a,'0'
            ld (de),a
            inc de
            xor a
            ld (de),a
            ret
.d:         ld a,'0'
.l:         or a
            sbc hl,bc
            jr c,.w
            inc a
            jr .l
.w:         add hl,bc
            ld (de),a
            inc de
            ret
