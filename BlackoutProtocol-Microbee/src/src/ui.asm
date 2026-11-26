; ---------------------------------------------------------------------------
; Information-screen furniture: bevelled panels, header tabs, key-caps, bullets,
; separators and the title logo, laid out by small page scripts.
;   PG_PANEL r0,c0,r1,c1,colour     PG_HEAD r,c,colour,"TEXT",0
;   PG_TEXT r,c,colour,"TEXT",0     PG_KEY r,c,"KEY",0
;   PG_BUL r,c                      PG_SEP r,c0,c1
;   PG_LOGO                         PG_END
; Colours are Premium colour bytes (background << 4 | ink).
; ---------------------------------------------------------------------------
PG_END   equ 0
PG_PANEL equ 1
PG_HEAD  equ 2
PG_TEXT  equ 3
PG_KEY   equ 4
PG_BUL   equ 5
PG_SEP   equ 6
PG_LOGO  equ 7
LOGO_BUF equ NATIVE              ; (PG_LOGO comes first in its script)
KEYCAP   equ $B0                ; black on yellow

; Tile A at (row B, col C) in colour E, into BACK.  Preserves BC, DE, HL.
put_tile:
        push bc
        push de
        push hl
        push de
        call tile_ptr           ; HL = tile
        push hl
        ld a,c
        ld c,b
        call cell_addr
        ld a,h
        sub $40
        ld d,a
        ld e,l
        pop hl
        pop bc                  ; C = colour
        ld a,c
        call put_cell
        pop hl
        pop de
        pop bc
        ret

; Run the page script at HL.
page_run:
        ld a,(hl)
        inc hl
        or a
        ret z
        dec a
        jr z,.panel
        dec a
        jr z,.head
        dec a
        jr z,.text
        dec a
        jr z,.key
        dec a
        jr z,.bul
        dec a
        jr z,.sep
        push hl
        call logo_draw
        pop hl
        jr page_run
.panel: ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        call panel
        pop hl
        jr page_run
.head:  call .rce               ; tab cap, the label on the colour, tab cap
        push hl
        ld a,e
        and $0F
        ld e,a
        ld a,T_TAB_L
        call put_tile
        pop hl
        ld a,e                  ; label: black on the tab's colour
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        inc c
        ld a,c
        push bc
        ld c,b
        call print_at
        pop bc
        push hl
        ld a,(pr_col)
        ld c,a
        ld a,(pr_ink)           ; (print_at used E)
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld e,a
        ld a,T_TAB_R
        call put_tile
        pop hl
        inc hl
        jr page_run
.text:  call .rce
        ld a,c
        ld c,b
        call print_at
        inc hl
        jr page_run
.key:   ld b,(hl)               ; key-cap: a space either side, black on yellow
        inc hl
        ld c,(hl)
        inc hl
        ld e,KEYCAP
        ld a,c
        ld c,b
        call print_at
        inc hl
        jp page_run
.bul:   ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,T_BUL
        ld e,$0B
        call put_tile
        jp page_run
.sep:   ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld d,(hl)
        inc hl
.sp:    ld a,T_SEP
        ld e,$04
        call put_tile
        inc c
        ld a,c
        cp d
        jr c,.sp
        jr z,.sp
        jp page_run
.rce:   ld b,(hl)               ; row, column, colour
        inc hl
        ld c,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ret

; Bevelled panel rows B..D, columns C..E, colour A (ink; background black).
panel:  ld (pn_col),a
        ld (pn_r1),de           ; (pn_r1 = E, pn_r1+1 = D)
        push bc
        ld a,(pn_col)
        ld e,a
        ld a,T_BZ_TL
        call put_tile
        ld a,(pn_r1)
        ld c,a
        ld a,T_BZ_TR
        call put_tile
        ld a,(pn_r1+1)
        ld b,a
        ld a,T_BZ_BR
        call put_tile
        pop bc
        push bc
        ld a,(pn_r1+1)
        ld b,a
        ld a,T_BZ_BL
        call put_tile
        pop bc
        push bc                 ; top and bottom edges
.h:     inc c
        ld a,(pn_r1)
        cp c
        jr z,.hd
        ld a,T_BZ_T
        call put_tile
        push bc
        ld a,(pn_r1+1)
        ld b,a
        ld a,T_BZ_B
        call put_tile
        pop bc
        jr .h
.hd:    pop bc
.v:     inc b                   ; left and right edges
        ld a,(pn_r1+1)
        cp b
        ret z
        ld a,T_BZ_L
        call put_tile
        push bc
        ld a,(pn_r1)
        ld c,a
        ld a,T_BZ_R
        call put_tile
        pop bc
        jr .v

; The title logo (rows 1..4, columns 13..28) from the core pack.
logo_draw:
        ld hl,logo_far
        ld de,LOGO_BUF
        call far_load
        ld hl,LOGO_BUF
        ld b,(hl)
        inc hl
.c:     push bc
        ld a,(hl)               ; row offset, column offset, colour, 12 bytes
        inc hl
        add a,1
        ld c,a
        ld a,(hl)
        inc hl
        add a,13
        push hl
        call cell_addr
        ld a,h
        sub $40
        ld d,a
        ld e,l
        pop hl
        ld a,(hl)               ; colour
        inc hl
        push af
        ld bc,12
        ldir
        pop af
        ld (de),a
        pop bc
        djnz .c
        ret
