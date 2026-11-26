; =====================================================================
;  fecommon.asm - front-end drawing kit (upper bank 0, always resident):
;  the OVERRIDE display font, the digital backdrop, framed panels and
;  header bars; and the roster / high-score helpers that the console and
;  the overlay both use.
; =====================================================================

; ---------------------------------------------------------------------
; the display font: 6x8 glyphs on a 7-pixel pitch, two-tone with a drop
; shadow. bf_cols = top colour, bottom colour, shadow colour (0-3).
BF_GOLD     equ 0               ; styles for bf_style
BF_ALERT    equ 1
BF_SYSTEM   equ 2

bf_style:
            ld l,a
            add a,a
            add a,l
            ld l,a
            ld h,0
            ld de,bf_styles
            add hl,de
            ld de,bf_cols
            ld bc,3
            ldir
            ret
bf_styles:  db 1,0,3            ; gold: yellow over green, red shadow
            db 3,3,1            ; alert: red, yellow shadow
            db 0,0,3            ; system: green, red shadow

; HL = string, E = row: centred
big_strc:
            push hl
            ld b,0
.l:         ld a,(hl)
            or a
            jr z,.e
            inc b
            inc hl
            jr .l
.e:         pop hl
            ld a,b
            add a,a
            add a,a
            add a,a
            sub b                   ; 7n
            ld b,a
            ld a,129
            sub b
            srl a
            ld d,a
; HL = string, D = x pixel, E = row
big_str:
            ld (bf_s),hl
            ld (bf_xy),de
            ld a,e
            ld b,10
            call fe_mark
            ld a,(bf_cols+2)        ; pass 1: the shadow, one down and right
            call bf_fill
            ld (bf_top),a
            ld (bf_bot),a
            ld a,1
            call .pass
            ld a,(bf_cols)          ; pass 2: the face
            call bf_fill
            ld (bf_top),a
            ld a,(bf_cols+1)
            call bf_fill
            ld (bf_bot),a
            xor a
.pass:      ld (bf_off),a
            ld b,a
            ld a,(bf_xy+1)
            add a,b
            ld (bf_cx),a
            ld hl,(bf_s)
.ch:        ld a,(hl)
            or a
            ret z
            inc hl
            push hl
            call bf_glyph
            jr z,.nx
            ld a,(bf_off)
            ld c,a
            ld a,(bf_xy)
            add a,c
            ld c,a                  ; C = row
            ld d,8
            ld a,(bf_top)
            ld (bf_cb),a
.r:         ld a,d
            cp 4
            jr nz,.nb
            ld a,(bf_bot)
            ld (bf_cb),a
.nb:        ld e,(hl)
            ld a,(bf_cx)
            ld b,a
.b:         sla e
            call c,bf_plot
            inc b
            ld a,e
            or a
            jr nz,.b
            inc hl
            inc c
            dec d
            jr nz,.r
.nx:        ld a,(bf_cx)
            add a,7
            ld (bf_cx),a
            pop hl
            jr .ch

; A = colour 0-3 -> A = its fill byte
bf_fill:
            push hl
            ld hl,cfill
            add a,l
            ld l,a
            jr nc,.n
            inc h
.n:         ld a,(hl)
            pop hl
            ret

; A = character -> HL = its glyph, NZ (Z: no glyph)
bf_glyph:
            sub 32
            cp 64
            jr nc,.none
            ld e,a
            ld d,0
            ld hl,bf_map
            add hl,de
            ld a,(hl)
            cp $FF
            ret z
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,bf_glyphs
            add hl,de
            or 1
            ret
.none:      xor a
            ret

; set pixel B = x, C = y to the fill byte bf_cb (keeps BC DE HL)
bf_plot:
            ld a,b
            cp 128
            ret nc
            ld a,c
            cp 64
            ret nc
            push hl
            push de
            ld l,c
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,b
            rrca
            rrca
            and $3F
            add a,l
            ld l,a
            ld de,FEBB
            add hl,de
            ld a,b
            and 3
            ld e,a
            ld d,0
            push hl
            ld hl,bf_pm
            add hl,de
            ld e,(hl)
            pop hl
            ld a,(bf_cb)
            xor (hl)
            and e
            xor (hl)
            ld (hl),a
            pop de
            pop hl
            ret
bf_pm:      db $C0,$30,$0C,$03

; ---------------------------------------------------------------------
; a header bar: A = style, HL = text, E = text row. Clears rows E-2 to
; E+10 and rules them off in red above and below.
fe_header:
            push hl
            push de
            call bf_style
            pop de
            push de
            ld a,e
            sub 2
            ld b,13
            ld c,$AA
            call fe_rows
            pop de
            push de
            ld a,e
            sub 2
            ld c,$EE
            call .rule
            pop de
            push de
            ld a,e
            add a,10
            ld c,$BB
            call .rule
            pop de
            pop hl
            jp big_strc
.rule:      ld b,1
            jp fe_rows

; ---------------------------------------------------------------------
; the backdrop. A = parts: bit 0 the circuit grid, bit 1 stars,
; bit 2 corner brackets
BK_GRID     equ 1
BK_STARS    equ 2
BK_FRAME    equ 4

fe_back:
            ld (bk_f),a
            ld a,$AA
            call fe_cls
            ld a,(bk_f)
            rrca
            call c,bk_grid
            ld a,(bk_f)
            and BK_STARS
            call nz,bk_stars
            ld a,(bk_f)
            and BK_FRAME
            call nz,bk_frame
            jp fe_markall

; dotted rules every 12 rows (5, 17 ... 53), dotted columns every 16
; pixels, and a few lit traces with yellow nodes
bk_grid:
            ld hl,FEBB
            ld c,0                  ; row
.r:         ld a,c
            ld b,0
.m12:       sub 12
            jr nc,.m12
            add a,12                ; row mod 12
            cp 5
            jr nz,.v
            ; a dotted rule: a green dot every 8 pixels
            push hl
            ld b,16
.h:         ld (hl),$2A
            inc hl
            inc hl
            djnz .h
            pop hl
            jr .nx
.v:         ld b,a
            ld a,c
            and 1
            jr nz,.nx
            push hl                 ; dotted columns on even rows
            ld b,8
.vc:        ld (hl),$2A
            inc hl
            inc hl
            inc hl
            inc hl
            djnz .vc
            pop hl
.nx:        ld de,32
            add hl,de
            inc c
            ld a,c
            cp 64
            jr nz,.r
            ; traces: 10 random grid segments, lit green, with a yellow node
            ld b,10
.t:         push bc
            call random
            and 7
            add a,a
            add a,a                 ; byte column 0, 4 .. 28
            ld d,a
            call random
            and 3
            ld e,a
            add a,a
            add a,e
            add a,a
            add a,a                 ; 12 * (0..3)
            add a,5
            ld e,a                  ; its row
            call random
            rrca
            jr c,.vt
            ; horizontal: four solid bytes along the rule
            ld b,4
            ld c,1
            ld a,$00
            call fe_box
            jr .nd
.vt:        ; vertical: down the column to the next rule
            push de
            ld l,e
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,l
            add a,d
            ld l,a
            ld bc,FEBB
            add hl,bc
            ld b,12
            ld de,32
.vl:        ld a,(hl)
            and $3F
            ld (hl),a
            add hl,de
            djnz .vl
            pop de
.nd:        ld a,d                  ; the node: a yellow 2x2 at its start
            add a,a
            add a,a
            ld b,a
            ld c,e
            dec c
            ld a,1
            call bk_dot2
            pop bc
            djnz .t
            ret

; a 2x2 square of colour A at B, C
bk_dot2:
            call bf_fill
            ld (bf_cb),a
            call bf_plot
            inc b
            call bf_plot
            inc c
            call bf_plot
            dec b
            jp bf_plot

bk_stars:
            ld b,28
.s:         push bc
            call random
            and 127
            ld b,a
            call random
            and 63
            ld c,a
            call random
            and 3
            ld a,$55                ; mostly yellow
            jr nz,.y
            ld a,$00
.y:         ld (bf_cb),a
            call bf_plot
            pop bc
            djnz .s
            ret

; red corner brackets, 8 pixels each way
bk_frame:
            ld a,$FF
            ld (bf_cb),a
            ld bc,$0000
            call .h
            ld bc,$0000
            call .v
            ld bc,$7800
            call .h
            ld bc,$7F00
            call .v
            ld bc,$003F
            call .h
            ld bc,$0038
            call .v
            ld bc,$783F
            call .h
            ld bc,$7F38
.v:         ld d,8
.vl:        call bf_plot
            inc c
            dec d
            jr nz,.vl
            ret
.h:         ld d,8
.hl:        call bf_plot
            inc b
            dec d
            jr nz,.hl
            ret

; ---------------------------------------------------------------------
; a framed panel: D = byte column, E = row, B = width (bytes, 2+),
; C = height (3+), A = frame colour. Clears the inside to blue.
fe_panel:
            call bf_fill
            ld (pn_f),a
            ld (pn_wh),bc
            push de
            ld a,$AA
            call fe_box             ; the blue body (marks the rows)
            pop de
            ; top and bottom rules, corners cut
            push de
            call .rule
            pop de
            push de
            ld a,(pn_wh)            ; C = height
            dec a
            add a,e
            ld e,a
            call .rule
            pop de
            ; the sides (between the rules)
            inc e
            call pn_addr
            ld a,(pn_wh)
            sub 2
            ld c,a
            ld a,(pn_wh+1)
            dec a
            ld e,a
            ld d,0                  ; DE = width - 1
.sd:        ld a,(pn_f)
            and $C0
            ld b,a
            ld a,(hl)
            and $3F
            or b
            ld (hl),a
            push hl
            add hl,de
            ld a,(pn_f)
            and $03
            ld b,a
            ld a,(hl)
            and $FC
            or b
            ld (hl),a
            pop hl
            push de
            ld de,32
            add hl,de
            pop de
            dec c
            jr nz,.sd
            ret
.rule:      call pn_addr
            ld a,(pn_wh+1)
            ld b,a
            ld a,(pn_f)
.rl:        ld (hl),a
            inc hl
            djnz .rl
            dec hl                  ; the corners: one pixel of blue
            ld a,(hl)
            and $FC
            or $02
            ld (hl),a
            ld a,(pn_wh+1)
            ld e,a
            ld d,0
            or a
            sbc hl,de
            inc hl
            ld a,(hl)
            and $3F
            or $80
            ld (hl),a
            ret
; D = column, E = row -> HL in FEBB
pn_addr:
            ld l,e
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,l
            add a,d
            ld l,a
            ld bc,FEBB
            add hl,bc
            ret

; ---------------------------------------------------------------------
; the droid files (console and attract)
; A = top row: show droid r_page there, in a panel
roster_entry:
            ld (re_y),a
            ld d,0                  ; a panel 32 bytes x 17 rows
            ld e,a
            dec e
            ld bc,$2011
            ld a,0
            call fe_panel
            ld a,(r_page)
            ld d,7                  ; slot 7
            ld b,0
            push af
            call build_type
            ld a,(re_y)
            add a,3
            ld c,a
            ld b,5
            ld hl,SPRC+$700
            call fe_spr
            pop af
            ; number and name
            ld de,t_buf
            call type_num
            ld de,$0102
            call txt_colour
            ld hl,t_buf
            ld a,(re_y)
            ld e,a
            ld d,6
            call fe_str
            ld a,(r_page)
            call r_name
            ld a,(re_y)
            ld e,a
            ld d,10
            call fe_str
            ; class, energy, weapon
            ld de,$0002
            call txt_colour
            ld a,(r_page)
            call r_stats
            ld hl,t_buf
            ld a,(re_y)
            add a,5
            ld e,a
            ld d,6
            call fe_str
            ld de,$0302
            call txt_colour
            ld a,(r_page)
            call r_weapon
            ld a,(re_y)
            add a,10
            ld e,a
            ld d,6
            jp fe_str

; A = type -> HL = its name
r_name:
            ld hl,r_names
; HL = list of 0-ended strings, A = index -> HL = that string
str_index:
            or a
            ret z
            ld b,a
.l:         ld a,(hl)
            inc hl
            or a
            jr nz,.l
            djnz .l
            ret

; A = type -> HL = weapon name
r_weapon:
            ld c,T_WEAPON
            call type_stat
            ld hl,r_wnames
            jr str_index

; A = type -> t_buf "CLASS n  EN nnn"
r_stats:
            push af
            ld hl,class_txt
            ld de,t_buf
            ld bc,6
            ldir
            pop af
            push af
            ld c,T_CLASS
            call type_stat
            add a,'0'
            ld (de),a
            inc de
            ld a,' '
            ld (de),a
            inc de
            ld (de),a
            inc de
            ld a,'E'
            ld (de),a
            inc de
            ld a,'N'
            ld (de),a
            inc de
            ld a,' '
            ld (de),a
            inc de
            pop af
            ld c,T_EN
            call type_stat
            jp num3
class_txt:  db "CLASS "

; copy the 0-ended string HL to DE (DE ends on the 0)
copy0:
            ld a,(hl)
            ld (de),a
            or a
            ret z
            inc hl
            inc de
            jr copy0

; HL = label, DE = 3-byte BCD -> t_buf "LABEL 012345"
hi_line:
            push de
            ld de,t_buf
.c:         ld a,(hl)
            or a
            jr z,.e
            ld (de),a
            inc hl
            inc de
            jr .c
.e:         pop hl
            ld b,3
            jp bcd_str

hi_init:
            ld hl,hi_default
            ld de,hitab
            ld bc,30
            ldir
            ld hl,hitab
            ld de,hiscore
            ld bc,3
            ldir
            ret
hi_default: db $01,$50,$00,"BPM"
            db $01,$20,$00,"VZ3"
            db $00,$90,$00,"DSE"
            db $00,$60,$00,"LNK"
            db $00,$30,$00,"OVR"

            include "gen/bigfont.inc"

bf_cols:    db 1,0,3
bf_s:       ds 2
bf_xy:      ds 2
bf_top:     ds 1
bf_bot:     ds 1
bf_off:     ds 1
bf_cx:      ds 1
bf_cb:      ds 1
bk_f:       ds 1
pn_f:       ds 1
pn_wh:      ds 2
