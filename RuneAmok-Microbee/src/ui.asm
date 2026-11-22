; =====================================================================
;  UI: the frame, the panel (stats, keys, sigils, minimap, compass) and
;  the message log.
;
;   col 0 | view 1-24 | 25 | panel 26-38 | 39      rows 1-16 view,
;   row 17 rule, rows 18-23 the log (cols 1-24), row 24 the foot.
;  The log is kept as text (TEXTBUF) and copied to both pages in the
;  blanking; the panel is printed through the cell shadows, so only
;  what changed is written.
; =====================================================================
LOGROW      EQU 18
LOGLINES    EQU 6
LOGW        EQU 24
PCOL        EQU 26          ; panel column
MAPCOL      EQU 28          ; minimap: 8 x 8 cells
MAPROW      EQU 13
C_FRAME     EQU BROWN
C_KNOT      EQU YELLOW
C_LABEL     EQU YELLOW
C_VALUE     EQU WHITE

ui_init:
        call display_off
        ld a,MP_UI
        out (P_MEM),a
        ld hl,0
        ld de,128
        ld a,BK_FONT
        call pcg_load
        ld a,BK_UI
        call pcg_clear
        call screen_clear
        xor a
        call show_page
        ret

; the frame and the panel labels (both pages)
ui_frame:
        call screen_clear
        ; top and bottom rules
        ld hl,0
        ld b,40
.t:     push bc
        push hl
        ld b,F_H
        call frame_cell
        ld de,24*40
        add hl,de
        call frame_cell
        ld de,-7*40
        add hl,de
        call frame_cell         ; row 17
        pop hl
        pop bc
        inc hl
        djnz .t
        ; the verticals
        ld hl,40
        ld b,23
.v:     push bc
        push hl
        ld b,F_V
        call frame_cell
        ld de,25
        add hl,de
        call frame_cell
        ld de,14
        add hl,de
        call frame_cell
        pop hl
        ld de,40
        add hl,de
        pop bc
        djnz .v
        ; knots
        ld hl,knots
.k:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        cp $FF
        ret z
        ld b,(hl)
        inc hl
        push hl
        ex de,hl
        ld c,BK_FONT
        ld a,C_KNOT
        call put2
        pop hl
        jr .k

knots:  dw 0
        db F_TL
        dw 25
        db F_TD
        dw 39
        db F_TR
        dw 17*40
        db F_TRT
        dw 17*40+25
        db F_X
        dw 17*40+39
        db F_TLT
        dw 24*40
        db F_BL
        dw 24*40+25
        db F_TU
        dw 24*40+39
        db F_BR
        dw $FFFF

; HL = cell, B = glyph: a frame cell (bank 15, the frame colour)
frame_cell:
        ld c,BK_FONT
        ld a,C_FRAME
        jp put2

; ---------------------------------------------------------------------
;  a new level: frame, name, the whole panel
; ---------------------------------------------------------------------
ui_level:
        call ui_frame
        ; the level's name, centred on row 0 of the panel
        ld a,(lvl_mpb)
        out (P_MEM),a
        ld hl,(10)              ; text table: entry 0 = the name
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,msgbuf
        call copy_str
        ld hl,msgbuf
        call str_len
        ld a,13
        sub c
        srl a
        add a,PCOL
        ld c,a
        ld b,1
        ld hl,msgbuf
        ld a,(level)
        ld e,a
        ld d,0
        push hl
        ld hl,lvl_colours
        add hl,de
        ld a,(hl)
        pop hl
        call print_at
        ; labels
        ld hl,panel_labels
.l:     ld a,(hl)
        cp $FF
        jr z,.ld
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,C_LABEL
        push hl
        call print_at
        pop hl
.s:     ld a,(hl)               ; past the string
        inc hl
        or a
        jr nz,.s
        jr .l
.ld:    call mini_all
        call ui_compass
        call log_redraw
        ld a,$FF
        ld (st_hp),a            ; force every stat
        ld (st_mp),a
        ld (st_lvl),a
        ld (st_atk),a
        ld (st_gold),a
        jp ui_stats

lvl_colours: db WHITE, BGREEN, BCYAN, YELLOW

panel_labels:
        db 3,PCOL
        db "Health",0
        db 5,PCOL
        db "Magic",0
        db 7,PCOL
        db "Lvl",0
        db 8,PCOL
        db "XP",0
        db 9,PCOL
        db "Atk",0
        db 9,PCOL+7
        db "Def",0
        db 10,PCOL
        db "Gold",0
        db $FF

; HL = string -> C = its length
str_len:
        push hl
        ld c,0
.l:     ld a,(hl)
        or a
        jr z,.d
        inc hl
        inc c
        jr .l
.d:     pop hl
        ret

; copy a 0-ended string HL -> DE
copy_str:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,copy_str
        ret

; ---------------------------------------------------------------------
;  the stats
; ---------------------------------------------------------------------
ui_stats:
        ; health: "30/30" right-aligned at col 33..38
        ld a,(hp)
        ld l,a
        ld a,(hpmax)
        ld h,a
        ld de,(st_hp)
        or a
        sbc hl,de
        add hl,de
        jr z,.mp
        ld (st_hp),hl
        ld b,3
        ld c,PCOL+6
        ld a,(hp)
        ld e,a
        ld a,(hpmax)
        ld d,a
        call print_frac
        ld a,(hp)
        ld e,a
        ld a,(hpmax)
        ld d,a
        ld b,4
        ld a,BRED
        call draw_bar
.mp:    ld a,(mp)
        ld l,a
        ld a,(mpmax)
        ld h,a
        ld de,(st_mp)
        or a
        sbc hl,de
        add hl,de
        jr z,.lv
        ld (st_mp),hl
        ld b,5
        ld c,PCOL+6
        ld a,(mp)
        ld e,a
        ld a,(mpmax)
        ld d,a
        call print_frac
        ld a,(mp)
        ld e,a
        ld a,(mpmax)
        ld d,a
        ld b,6
        ld a,BBLUE
        call draw_bar
.lv:    ld a,(lvl)
        ld hl,st_lvl
        cp (hl)
        jr z,.xp
        ld (hl),a
        ld l,a
        ld h,0
        ld de,7*40+PCOL+4
        ld b,2
        ld a,C_VALUE
        ld (pr_col),a
        call print_num
.xp:    ld hl,(xp)
        ld de,8*40+PCOL+3
        ld b,5
        ld a,C_VALUE
        ld (pr_col),a
        call print_num
        ld a,'/'
        ld de,8*40+PCOL+8
        call put_char
        ld a,(lvl)
        call xp_need
        ld de,8*40+PCOL+9
        ld b,4
        call print_num_l
        ld a,(atk)
        ld l,a
        ld a,(def)
        ld h,a
        ld de,(st_atk)
        or a
        sbc hl,de
        add hl,de
        jr z,.gd
        ld (st_atk),hl
        ld a,(atk)
        ld l,a
        ld h,0
        ld de,9*40+PCOL+4
        ld b,2
        call print_num
        ld a,(def)
        ld l,a
        ld h,0
        ld de,9*40+PCOL+11
        ld b,2
        call print_num
.gd:    ld hl,(gold)
        ld de,10*40+PCOL+5
        ld b,5
        call print_num
        jp ui_items

; DE = value (E) / max (D) at row B, column C: "vvv/mmm"
print_frac:
        push de
        ld h,0
        ld l,b
        call rowcol
        ex de,hl                ; DE = cell
        pop hl                  ; L = value, H = max
        push hl
        ld h,0
        ld b,3
        ld a,C_VALUE
        ld (pr_col),a
        call print_num
        ld a,'/'
        call put_char
        inc de
        pop hl
        ld l,h
        ld h,0
        ld b,3
        jp print_num_l

; HL = row (L), C = column -> HL = cell offset
rowcol: add hl,hl
        add hl,hl
        add hl,hl
        push de
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld e,c
        ld d,0
        add hl,de
        pop de
        ret

; A = char at cell DE (colour pr_col)
put_char:
        push hl
        push bc
        push de
        add a,$80-32
        ld b,a
        ld c,BK_FONT
        ex de,hl
        ld a,(pr_col)
        call put2
        pop de
        pop bc
        pop hl
        ret

; left-aligned number: HL at DE, at most B digits (padded with spaces after)
print_num_l:
        push de
        push bc
        ld de,num_buf+5
        xor a
        ld (de),a
.d:     dec de
        push de
        ld de,10
        call div16
        pop de
        add a,'0'
        ld (de),a
        ld a,h
        or l
        jr nz,.d
        pop bc
        ex de,hl                ; HL = digits
        pop de
.p:     ld a,(hl)
        or a
        jr z,.pad
        inc hl
        call put_char
        inc de
        dec b
        jr nz,.p
        ret
.pad:   ld a,b
        or a
        ret z
        ld a,' '
        call put_char
        inc de
        dec b
        jr .pad

; a bar of 13 cells at row B: E = value, D = max, A = ink
draw_bar:
        ld (bar_ink),a
        ; filled pixels = value * 104 / max
        push bc
        ; simpler: HL = value * 104
        ld h,0
        ld l,e
        add hl,hl
        add hl,hl
        add hl,hl               ; *8
        push hl
        add hl,hl               ; *16
        add hl,hl               ; *32
        add hl,hl               ; *64
        pop bc
        push bc
        add hl,bc               ; *72
        pop bc
        add hl,bc
        add hl,bc
        add hl,bc
        add hl,bc               ; *104
        ld e,d
        ld d,0
        ld a,e
        or a
        jr nz,.dv
        ld hl,0
        inc e
.dv:    call div16              ; HL = pixels (0..104)
        pop bc
        ld a,l
        ld (bar_px),a
        ld h,0
        ld l,b
        ld c,PCOL
        call rowcol             ; HL = first cell
        ld b,13
.c:     push bc
        ld a,(bar_px)
        cp 8
        jr c,.part
        sub 8
        ld (bar_px),a
        ld a,8
        jr .put
.part:  ld c,a
        xor a
        ld (bar_px),a
        ld a,c
.put:   add a,I_BAR0
        ld b,a
        ld c,BK_FONT
        ld a,(bar_ink)
        call put2
        inc hl
        pop bc
        djnz .c
        ret

bar_ink:    db 0
bar_px:     db 0
st_hp:      dw 0
st_mp:      dw 0
st_lvl:     db 0
st_atk:     dw 0
st_gold:    db 0

; the item line (row 11): potions, three keys; row 12: sigils, spells
ui_items:
        ld de,11*40+PCOL
        ld b,I_POTION
        ld a,BMAGENTA
        call put_icon
        inc de
        ld a,(potions)
        ld l,a
        ld h,0
        ld b,1
        ld a,C_VALUE
        ld (pr_col),a
        call print_num_l
        inc de
        inc de
        ld hl,keys
        ld c,0
.k:     push bc
        push hl
        ld a,(hl)
        or a
        ld a,BLACK
        jr z,.kc
        ld a,c
        push de
        ld e,a
        ld d,0
        ld hl,key_cols
        add hl,de
        ld a,(hl)
        pop de
.kc:    ld b,I_KEY
        call put_icon
        inc de
        pop hl
        push hl
        ld a,(hl)
        cp 2
        ld a,' '
        jr c,.k1
        ld a,(hl)
        add a,'0'
.k1:    call put_char
        inc de
        pop hl
        inc hl
        pop bc
        inc c
        ld a,c
        cp 3
        jr nz,.k
        ; sigils (row 12)
        ld de,12*40+PCOL
        ld a,(sigils)
        ld (tmp_sig),a
        ld b,3
.s:     push bc
        ld hl,tmp_sig
        srl (hl)
        ld a,DGREY
        jr nc,.sc
        ld a,BMAGENTA
.sc:    ld b,I_SIGIL
        call put_icon
        inc de
        pop bc
        djnz .s
        inc de
        ld a,(spells)
        rra
        ld a,DGREY
        jr nc,.f
        ld a,BRED
.f:     ld b,I_FLAME
        call put_icon
        inc de
        ld a,(spells)
        rra
        rra
        ld a,DGREY
        jr nc,.m
        ld a,BGREEN
.m:     ld b,I_MEND
        call put_icon
        ret

key_cols:   db BROWN, GREY, YELLOW
tmp_sig:    db 0

; B = icon, A = colour, at DE
put_icon:
        push hl
        push de
        push bc
        ex de,hl
        ld c,BK_FONT
        call put2
        pop bc
        pop de
        pop hl
        ret

; A = level -> HL = XP needed for the next
xp_need:
        add a,a
        ld e,a
        ld d,0
        ld hl,xp_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret
xp_tab: dw 0,20,50,100,170,260,380,530,720,999,9999

; ---------------------------------------------------------------------
;  compass: row 22, "Facing North"
; ---------------------------------------------------------------------
ui_compass:
        ld a,(facing)
        add a,a
        ld e,a
        ld d,0
        ld hl,dir_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,22
        ld c,PCOL
        ld a,C_LABEL
        call print_at
        ld a,1
        ld (mini_moved),a
        ret
dir_names:  dw d_n, d_e, d_s, d_w
d_n:    db " Facing North",0
d_e:    db " Facing East ",0
d_s:    db " Facing South",0
d_w:    db " Facing West ",0

; ---------------------------------------------------------------------
;  the message log. log_msg: HL = text (0 ends, '|' breaks a line),
;  in the colour (msg_col), then reset to white
; ---------------------------------------------------------------------
log_clear:
        ld hl,TEXTBUF
        ld b,LOGLINES*LOGW
.c:     ld (hl),' '
        inc hl
        djnz .c
        ld b,LOGLINES
.k:     ld (hl),WHITE
        inc hl
        djnz .k
        ld a,3
        ld (log_dirty),a
        ret

log_redraw:
        ld a,3
        ld (log_dirty),a
        ret

; A = colour, HL = text
log_msgc:
        ld (msg_col),a
log_msg:
        push bc
        push de
.line:  ; scroll the log up one line
        push hl
        ld hl,TEXTBUF+LOGW
        ld de,TEXTBUF
        ld bc,(LOGLINES-1)*LOGW
        ldir
        ld hl,TEXTBUF+LOGLINES*LOGW+1
        ld de,TEXTBUF+LOGLINES*LOGW
        ld bc,LOGLINES-1
        ldir
        ld a,(msg_col)
        ld (de),a
        ; dim the older lines
        ld hl,TEXTBUF+LOGLINES*LOGW
        ld b,LOGLINES-1
.dm:    ld a,(hl)
        cp WHITE
        jr nz,.dn
        ld (hl),GREY
.dn:    inc hl
        djnz .dm
        ld hl,TEXTBUF+(LOGLINES-1)*LOGW
        ld b,LOGW
.cl:    ld (hl),' '
        inc hl
        djnz .cl
        pop hl
        ; how much fits: up to LOGW chars, broken at a space
        push hl
        ld c,0                  ; chars to take
        ld b,0                  ; last break
.f:     ld a,(hl)
        or a
        jr z,.all
        cp '|'
        jr z,.all
        cp ' '
        jr nz,.nb
        ld b,c
.nb:    inc hl
        inc c
        ld a,c
        cp LOGW+1
        jr c,.f
        ; too long: break at the last space
        ld a,b
        or a
        jr nz,.brk
        ld b,LOGW
.brk:   ld c,b
.all:   pop hl
        ld de,TEXTBUF+(LOGLINES-1)*LOGW
        ld a,c
        or a
        jr z,.put0
        ld b,0
        ldir
.put0:  ld a,(hl)
        or a
        jr z,.done
        inc hl                  ; past the space or '|'
        ld a,(hl)
        or a
        jr z,.done
        jr .line
.done:  ld a,WHITE
        ld (msg_col),a
        ld a,3
        ld (log_dirty),a
        pop de
        pop bc
        ret

msg_col:    db WHITE
log_dirty:  db 0
mini_moved: db 0

        INCLUDE "mini.asm"

; A = text number in the level's text table -> to the log (in yellow)
show_text:
        push af
        ld a,(lvl_mpb)
        out (P_MEM),a
        pop af
        ld l,a
        ld h,0
        add hl,hl
        ld de,(10)
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,msgbuf
        ld bc,127
        ldir
        xor a
        ld (de),a
        ld hl,msgbuf
        ld a,BCYAN
        jp log_msgc

; ---------------------------------------------------------------------
;  in the blanking: the log, then the minimap glyphs (not while a view
;  commit is running)
; ---------------------------------------------------------------------
vb_ui:
        ld a,(cm_state)
        or a
        ret nz
        ld a,(log_dirty)
        or a
        jp z,vb_mini
        bit 0,a
        jr z,.col
        res 0,a
        ld (log_dirty),a
        ld a,LV_SCREEN
        out (P_LV),a
        ld hl,TEXTBUF
        ld de,VIDEO+LOGROW*40+1
        call .rows
        ld hl,TEXTBUF
        ld de,VIDEO+PAGE1+LOGROW*40+1
        call .rows
        ret
.col:   res 1,a
        ld (log_dirty),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld de,PCGWIN+LOGROW*40+1
        call .cols
        ld de,PCGWIN+PAGE1+LOGROW*40+1
        call .cols
        xor a
        out (P_COLCTL),a
        ret
; codes: chars -> font codes
.rows:  ld b,LOGLINES
.r:     push bc
        ld b,LOGW
.rc:    ld a,(hl)
        add a,$80-32
        ld (de),a
        inc hl
        inc de
        djnz .rc
        ex de,hl
        ld bc,40-LOGW
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
        ret
.cols:  ld hl,TEXTBUF+LOGLINES*LOGW
        ld b,LOGLINES
.k:     push bc
        ld a,(hl)
        inc hl
        ld b,LOGW
.kc:    ld (de),a
        inc de
        djnz .kc
        ex de,hl
        ld bc,40-LOGW
        add hl,bc
        ex de,hl
        pop bc
        djnz .k
        ret
