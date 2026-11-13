; =====================================================================
;  VIDEO: hardware start-up, RAM blocks, the two screen pages, PCG
;  loading, pictures and text.
; =====================================================================

; The 40-column mode: 40 x 25 cells of 8 lines. Two things select it, and
; the real Premium Plus needs both (found with FRILLSEEKER): the dot clock
; (IN (09h) with A = 1) and the 6545 table of BPM's MODES40 test.
crtc_game:  db $35,$28,$2C,$34,$26,$01,$19,$21,$48,$07,$20,$07,0,0,0,0
DROWS       EQU 25

hw_init:
        di
        ld a,BLK_WORK
        call map_blk
        ld hl,VARS
        ld de,VARS+1
        ld bc,vars_end-VARS-1
        ld (hl),0
        ldir
        ; PIO A: input (joystick)
        ld a,$CF
        out (P_PIOAC),a
        ld a,$FF
        out (P_PIOAC),a
        ld a,$07
        out (P_PIOAC),a
        ; PIO B: bit control, b6 speaker out, no interrupts
        ld a,$CF
        out (P_PIOBC),a
        ld a,$BF
        out (P_PIOBC),a
        ld a,$07
        out (P_PIOBC),a
        xor a
        out (P_PIOB),a
        out (P_ROMLAT),a
        out (P_COLCTL),a
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,1
        in a,(P_CLK40)          ; the 40-column dot clock
        ld hl,crtc_game
        call crtc_set
        call display_off
        ld hl,$C0DE
        ld (rseed),hl
        ld a,1
        ld (sound_on),a
        ; the font and HUD glyphs
        ld a,BLK_GFX
        call map_blk
        ld hl,0
        ld a,BK_FONT
        ld bc,POOL0
        jp pcg_load

crtc_set:
        ld c,0
.l:     ld a,c
        out (P_CRTCA),a
        ld a,(hl)
        out (P_CRTCD),a
        inc hl
        inc c
        ld a,c
        cp 16
        jr nz,.l
        ret

; the display off (every line is blanking: video RAM at full speed)
display_off:
        ld a,6
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ret
display_on:
        ld a,6
        out (P_CRTCA),a
        ld a,DROWS
        out (P_CRTCD),a
        xor a
        ld (vlast),a
        ld (fields),a
        ret

; A = block: map it into 0000-7FFF (ROMs off, video window at F000)
map_blk:
        ld (cur_blk),a
        push hl
        push de
        ld l,a
        ld h,0
        ld de,blkport
        add hl,de
        ld a,(hl)
        out (P_MEM),a
        pop de
        pop hl
        ret
; port 50h for blocks 0..15: ((b & 1Ch) << 3) | ((b & 3) ^ 2) | 4
blkport:
        db $06,$07,$04,$05,$26,$27,$24,$25,$46,$47,$44,$45,$66,$67,$64,$65

win_screen:
        xor a
        out (P_COLCTL),a
        ld a,LV_SCREEN
        out (P_LV),a
        ret
win_attr:
        xor a
        out (P_COLCTL),a
        ld a,LV_ATTR
        out (P_LV),a
        ret
win_col:
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ret

; ---------------------------------------------------------------------
;  HL = patterns (8 bytes a glyph), A = first PCG bank, BC = glyphs
; ---------------------------------------------------------------------
pcg_load:
        ld (pl_bank),a
        xor a
        out (P_COLCTL),a
.bank:  ld a,(pl_bank)
        or LV_SCREEN
        out (P_LV),a
        ld de,PCGWIN
.g:     push bc
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        pop bc
        ld a,e
        add a,8
        ld e,a
        jr nc,.nc
        inc d
.nc:    dec bc
        ld a,b
        or c
        jr z,.done
        ld a,d
        or a
        jr nz,.g                ; D wraps to 0 at the end of the bank
        ld a,(pl_bank)
        inc a
        ld (pl_bank),a
        jr .bank
.done:  ld a,LV_SCREEN
        out (P_LV),a
        ret

; ---------------------------------------------------------------------
;  a fighter's glyphs: A = block, C = first PCG bank. The block holds
;  16 bytes a glyph (pattern, mask); the PCG takes the pattern.
; ---------------------------------------------------------------------
fighter_load:
        call map_blk
        ld a,c
        ld (pl_bank),a
        xor a
        out (P_COLCTL),a
        ld bc,(0)               ; glyphs
        ld hl,FB_GLYPHS
.bank:  ld a,(pl_bank)
        or LV_SCREEN
        out (P_LV),a
        ld de,PCGWIN
.g:     ld a,b
        or c
        jr z,.done
        push bc
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ld bc,8
        add hl,bc
        pop bc
        dec bc
        ld a,e
        add a,8
        ld e,a
        jr nc,.g
        inc d
        jr nz,.g
        ld a,(pl_bank)
        inc a
        ld (pl_bank),a
        jr .bank
.done:  ld a,LV_SCREEN
        out (P_LV),a
        ret

; ---------------------------------------------------------------------
;  pages. (drawpage) = offset of the page text and pictures go to.
; ---------------------------------------------------------------------
; show page A (0 / 1) now
show_page:
        ld (vispage),a
        add a,a
        add a,a
        ld b,a
        ld a,12
        out (P_CRTCA),a
        ld a,b
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ret
; draw to page A (0 / 1)
set_drawpage:
        push hl
        add a,a
        add a,a
        ld h,a
        ld l,0
        ld (drawpage),hl
        pop hl
        ret

; D = row, E = column -> HL = offset of the cell in a page
cell_off:
        push de
        ld a,e
        ld l,d
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de               ; row * 40
        ld e,a
        ld d,0
        add hl,de
        pop de
        ret

; clear the draw page to spaces, colour A
cls:    push af
        call win_screen
        ld hl,(drawpage)
        ld de,VIDEO
        add hl,de
        push hl
        ld (hl),$80
        call .fill
        call win_attr
        pop hl
        push hl
        ld (hl),BK_FONT
        call .fill
        call win_col
        pop hl
        set 3,h
        pop af
        ld (hl),a
        call .fill
        jp win_screen
.fill:  ld e,l
        ld d,h
        inc de
        ld bc,NCELL-1
        ldir
        ret

; ---------------------------------------------------------------------
;  text. HL = string (0 ends), D = row, E = column, C = colour.
;  Characters 32..95 are the font, 96.. the HUD glyphs.
; ---------------------------------------------------------------------
print:
        push hl
        call cell_off
        ld de,(drawpage)
        add hl,de
        ld de,VIDEO
        add hl,de
        ex de,hl                ; DE = video address
        pop hl
.ch:    ld a,(hl)
        or a
        ret z
        inc hl
        sub 32
        or $80
        ex de,hl
        ld b,a
        call win_screen
        ld (hl),b
        call win_attr
        ld (hl),BK_FONT
        call win_col
        set 3,h
        ld (hl),c
        res 3,h
        call win_screen
        inc hl
        ex de,hl
        jr .ch

; print the string centred on row D
print_mid:
        push hl
        ld b,0
.n:     ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc b
        jr .n
.e:     ld a,COLS
        sub b
        srl a
        ld e,a
        pop hl
        jr print

; the same text on both pages
print2: push hl
        push de
        push bc
        xor a
        call set_drawpage
        call print
        pop bc
        pop de
        pop hl
        ld a,1
        call set_drawpage
        call print
        xor a
        jp set_drawpage
print_mid2:
        push hl
        push de
        push bc
        xor a
        call set_drawpage
        call print_mid
        pop bc
        pop de
        pop hl
        ld a,1
        call set_drawpage
        call print_mid
        xor a
        jp set_drawpage

; ---------------------------------------------------------------------
;  pictures. A = picture number: its glyphs go to PCG banks 1..2 and
;  its cells to the draw page. Leaves the picture's block mapped and
;  (picbase) = its record.
; ---------------------------------------------------------------------
pic_find:
        ld b,BLK_GFX
        ld c,a
        ld a,b
        ld (picblk),a
        call map_blk
        ld hl,PIC_BASE
        ld de,PIC_SLOT
        ld a,c
        or a
        jr z,.f
.m:     add hl,de
        dec a
        jr nz,.m
.f:     ld (picbase),hl
        ret

pic_glyphs:
        ld hl,(picbase)
        ld de,PIC_N
        add hl,de
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld de,PIC_GLYPHS-PIC_N-1
        add hl,de
        ld a,BK_PIC
        jp pcg_load

; the cells of the mapped picture to the draw page
pic_cells:
        call win_screen
        ld hl,(drawpage)
        ld de,VIDEO
        add hl,de
        ex de,hl
        ld hl,(picbase)
        ld bc,NCELL
        push de
        ldir
        call win_attr
        pop de
        push de
        ld bc,NCELL
        ldir
        call win_col
        pop de
        set 3,d
        ld bc,NCELL
        ldir
        jp win_screen

; row D of the mapped picture back to both pages (rubs out a message)
pic_row:
        ld a,(picblk)
        call map_blk
        ld e,0
        call cell_off           ; HL = row offset
        push hl
        xor a
        call .one
        pop hl
        ld a,1
.one:   push hl
        call set_drawpage
        pop hl
        push hl
        ld de,(drawpage)
        ex de,hl
        add hl,de
        ld bc,VIDEO
        add hl,bc
        ex de,hl                ; DE = video, HL = row offset
        ld bc,(picbase)
        add hl,bc
        push hl
        push de
        call win_screen
        ld bc,COLS
        ldir
        call win_attr
        pop de
        pop hl
        push hl
        push de
        ld bc,PIC_BANKS
        add hl,bc
        ld bc,COLS
        ldir
        call win_col
        pop de
        pop hl
        ld bc,PIC_COLS
        add hl,bc
        set 3,d
        ld bc,COLS
        ldir
        call win_screen
        pop hl
        xor a
        jp set_drawpage
