; =====================================================================
;  RENDER: two screen pages (offsets 000h and 400h) flipped with the
;  6545 start address. Every moving thing is drawn into a draw list of
;  cells (address, character, PCG bank, colour) for the hidden page.
;  The list is written in three quick passes (characters, banks,
;  colours); next time that page comes round, the same cells are put
;  back to character 80h - glyph 0 of every PCG bank is blank, so the
;  bank and colour can stay as they were.
;
;  A sprite is 12 x 12 pixels on a 4-pixel grid and always covers 2 x 2
;  cells: each frame has 16 glyphs ready made (4 grid offsets x 4 cells).
; =====================================================================
DLMAX   equ 252                 ; cells in a draw list

; pgbase = F000h or F400h: the hidden page (rpage)
set_page:
        ld a,(rpage)
        add a,a
        add a,a
        add a,$F0
        ld (pgbase+1),a
        xor a
        ld (pgbase),a
        ret

; Draw list entry, 6 bytes: address (2), char, bank, 0, colour. The
; passes read it with POP (interrupts are always off): DE = address,
; HL = char/bank, AF = colour.

; dl_begin: put back the hidden page's cells from last time (from the
; background map: blank, or the border, whose glyphs are 1-8 in every PCG
; bank), start its new list
dl_begin:
        call set_page
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,(rpage)
        or a
        ld hl,DL0
        ld a,(dln0)
        jr z,.p
        ld hl,DL1
        ld a,(dln1)
.p:     ld (dlp),hl
        ld (dlbase),hl
        or a
        jr z,.done
        ld b,a
        ld (sp_save),sp
        ld sp,hl
.l:     pop de
        pop hl
        pop hl
        ld a,d                  ; the background map: 80h, or a border glyph
        and 3
        or BGMAP/256
        ld h,a
        ld l,e
        ld a,(hl)
        ld (de),a
        djnz .l
        ld sp,(sp_save)
.done:  xor a
        ld (dln),a
        jp vschk

; dl_flush: write the list to the hidden page
dl_flush:
        call vschk
        ld a,(dln)
        ld b,a
        ld a,(rpage)
        or a
        ld a,b
        jr nz,.p1
        ld (dln0),a
        jr .p
.p1:    ld (dln1),a
.p:     or a
        ret z
        ld c,a
        ld (sp_save),sp
        ld sp,(dlbase)          ; characters
.c:     pop de
        pop hl
        pop af
        ld a,l
        ld (de),a
        djnz .c
        ld sp,(sp_save)
        call vschk
        ld a,LV_ATTR            ; PCG banks
        out (P_LV),a
        ld b,c
        ld sp,(dlbase)
.a:     pop de
        pop hl
        pop af
        ld a,h
        ld (de),a
        djnz .a
        ld sp,(sp_save)
        ld a,LV_SCREEN
        out (P_LV),a
        call vschk
        ld a,COL_ON             ; colours (F800h + the screen offset)
        out (P_COLCTL),a
        ld b,c
        ld sp,(dlbase)
.k:     pop de
        pop hl
        pop af
        set 3,d
        ld (de),a
        djnz .k
        ld sp,(sp_save)
        xor a
        out (P_COLCTL),a
        jp vschk

; show_page: wait out the frame (the beeper plays), then show the page
; just drawn and draw the other one next
show_page:
        ld a,2
        call frame_wait
        ld a,(rpage)
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
        ld a,(rpage)
        xor 1
        ld (rpage),a
        ret

; DLPUT: (HL) <- address DE, char B, bank A', 0, colour C; HL += 6
DLPUT   MACRO
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),b
        inc hl
        ex af,af'
        ld (hl),a
        ex af,af'
        inc hl
        inc hl
        ld (hl),c
        inc hl
        ENDM

; dl_put: as DLPUT (HL = address, B char, C colour, bank (ds_bk), DE = list)
dl_put: ex de,hl
        ld a,(ds_bk)
        ex af,af'
        DLPUT
        ex de,hl
        ret

; draw_sprite: A = frame, D = x, E = y (4-pixel units), C = colour of the
; top two cells, (ds_col2) the bottom two
draw_sprite:
        ld b,a
        ld a,(dln)
        cp DLMAX-3
        ret nc
        add a,4
        ld (dln),a
        ld a,b
        add a,a
        ld l,a
        ld h,frametab/256
        ld a,e
        and 1
        add a,a
        ld b,a
        ld a,d
        and 1
        or b
        add a,a
        add a,a
        add a,(hl)
        ld b,a                  ; the first character
        inc l
        ld a,(hl)
        ex af,af'               ; A' = bank
        ld l,e
        ld h,ytlo/256
        ld a,d
        srl a
        add a,(hl)
        inc h
        ld e,a
        ld a,(hl)
        adc a,0
        ld hl,pgbase+1
        add a,(hl)
        ld d,a                  ; DE = top left cell
        ld hl,(dlp)
        DLPUT
        inc de
        inc b
        DLPUT
        ld a,e
        add a,39
        ld e,a
        jr nc,.n
        inc d
.n:     inc b
        ld a,(ds_col2)
        ld c,a
        DLPUT
        inc de
        inc b
        DLPUT
        ld (dlp),hl
        ret

; draw_sprite1: one colour C for the whole sprite
draw_sprite1:
        ld b,a
        ld a,c
        ld (ds_col2),a
        ld a,b
        jp draw_sprite

; unit_addr: D = x, E = y (4-pixel units) -> HL = cell on the hidden page,
; A = quarter of the cell (y&1)*2 + (x&1). Keeps C, DE.
unit_addr:
        ld l,e
        ld h,ytlo/256
        ld a,d
        srl a
        add a,(hl)
        inc h
        ld b,a
        ld a,(hl)
        adc a,0
        ld hl,pgbase+1
        add a,(hl)
        ld h,a
        ld l,b
        ld a,e
        and 1
        add a,a
        ld b,a
        ld a,d
        and 1
        or b
        ret

; dl_cell: HL = address, B = char, C = colour (bank 0). Keeps BC, HL.
dl_cell:
        ld a,(dln)
        cp DLMAX
        ret nc
        inc a
        ld (dln),a
        xor a
        ld (ds_bk),a
        ld de,(dlp)
        call dl_put
        ld (dlp),de
        ret

; scr_addr: D = column, E = row -> HL on the hidden page. Keeps BC, DE.
scr_addr:
        push bc
        ld l,e
        ld h,0
        add hl,hl
        ld bc,rowtab
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,0
        ld c,d
        add hl,bc
        ld bc,(pgbase)
        add hl,bc
        pop bc
        ret

; draw_msg: the 0-terminated string HL centred on row E, colour C
draw_msg:
        push hl
        ld b,0
.n:     ld a,(hl)
        or a
        jr z,.l
        inc hl
        inc b
        jr .n
.l:     ld a,40
        sub b
        srl a
        ld d,a
        pop hl
; draw_text: string HL at column D, row E, colour C (into the draw list)
draw_text:
        ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        push de
        add a,$A0
        ld b,a
        call scr_addr
        call dl_cell
        pop de
        pop hl
        inc d
        jr draw_text

; ---------------------------------------------------------------------
;  fixed cells, written to both pages at once (HUD, fence)
; ---------------------------------------------------------------------
; put_both: HL = screen offset (0..999), B = char, C = colour (bank 0)
put_both:
        ld de,$F000
        add hl,de
        ld a,LV_SCREEN
        out (P_LV),a
        ld (hl),b
        set 2,h
        ld (hl),b
        ld a,LV_ATTR
        out (P_LV),a
        ld (hl),0
        res 2,h
        ld (hl),0
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        set 3,h
        ld (hl),c
        set 2,h
        ld (hl),c
        xor a
        out (P_COLCTL),a
        ret

; text_both: string HL at screen offset DE, colour C
text_both:
        ld a,(hl)
        or a
        ret z
        push hl
        push de
        add a,$A0
        ld b,a
        ex de,hl
        call put_both
        pop de
        pop hl
        inc hl
        inc de
        jr text_both

; digit_both: digit A at offset DE (DE moves on), colour C
digit_both:
        push hl
        push de
        push bc
        add a,$D0
        ld b,a
        ex de,hl
        call put_both
        pop bc
        pop de
        pop hl
        inc de
        ret

; bcd_both: 3 BCD bytes at HL as 6 digits at offset DE, colour C
bcd_both:
        ld b,3
.l:     push bc
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        call digit_both
        ld a,(hl)
        and 15
        call digit_both
        inc hl
        pop bc
        djnz .l
        ret

; row_off: A = row -> HL = row * 40
row_off:
        ld l,a
        ld h,0
        add hl,hl
        ld de,rowtab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret
rowtab:
        dw 0,40,80,120,160,200,240,280,320,360,400,440,480,520,560,600,640,680,720,760,800,840,880,920,960

; clear_both: every cell blank on both pages
clear_both:
        ld a,LV_SCREEN
        out (P_LV),a
        ld hl,$F000
        ld (hl),$80
        ld de,$F001
        ld bc,$7FF
        ldir
        ld a,LV_ATTR
        out (P_LV),a
        ld hl,$F000
        ld (hl),0
        ld de,$F001
        ld bc,$7FF
        ldir
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld hl,$F800
        ld (hl),$0F
        ld de,$F801
        ld bc,$7FF
        ldir
        xor a
        out (P_COLCTL),a
        ld (dln0),a
        ld (dln1),a
        ld (rpage),a
        ret

; load_pcg: the 2048 glyphs (8 bytes each in GFX.BNK) into the 16 PCG banks
load_pcg:
        ld a,BLK_GFX
        call map_blk
        ld hl,0
        ld b,0
.bk:    ld a,b
        or LV_SCREEN
        out (P_LV),a
        ld de,PCGWIN
        ld c,128
.g:     push bc
        ld bc,8
        ldir
        xor a
        REPT 8
        ld (de),a
        inc de
        ENDR
        pop bc
        dec c
        jr nz,.g
        inc b
        ld a,b
        cp 16
        jr nz,.bk
        ld a,LV_SCREEN
        out (P_LV),a
        ret

; show_title_pic: the logo picture onto page 0 (shown)
show_title_pic:
        ld a,BLK_GFX
        call map_blk
        ld hl,PIC_TITLE
        ld a,LV_SCREEN
        out (P_LV),a
        ld de,$F000
        ld bc,1000
        ldir
        ld a,LV_ATTR
        out (P_LV),a
        ld de,$F000
        ld bc,1000
        ldir
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld de,$F800
        ld bc,1000
        ldir
        xor a
        out (P_COLCTL),a
        jp show0

; show0: display page 0
show0:  ld a,12
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ret

; ---------------------------------------------------------------------
;  page 0 cells for the attract screens
; ---------------------------------------------------------------------
; p0_put: HL = offset, B = char, C = colour, D = bank. Keeps BC, DE, HL.
p0_put: push hl
        ld a,h
        add a,$F0
        ld h,a
        ld a,LV_SCREEN
        out (P_LV),a
        ld (hl),b
        ld a,LV_ATTR
        out (P_LV),a
        ld (hl),d
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        set 3,h
        ld (hl),c
        xor a
        out (P_COLCTL),a
        pop hl
        ret

; p0_text: string HL at offset DE, colour C
p0_text:
        ld a,(hl)
        or a
        ret z
        push hl
        push de
        add a,$A0
        ld b,a
        ex de,hl
        ld d,0
        call p0_put
        pop de
        pop hl
        inc hl
        inc de
        jr p0_text

; p0_ctext: string HL centred on row E, colour C
p0_ctext:
        push hl
        ld b,0
.n:     ld a,(hl)
        or a
        jr z,.l
        inc hl
        inc b
        jr .n
.l:     ld a,40
        sub b
        srl a
        push af
        ld a,e
        call row_off
        pop af
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        jr p0_text

; p0_big: double-size frame A at offset HL; C = top row colour,
; (ds_col2) the two rows below
p0_big: push hl
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de               ; x 18
        ex de,hl
        ld ix,bigtab
        add ix,de
        pop hl
        ld b,3
.r:     push bc
        push hl
        ld b,3
.c:     push bc
        ld b,(ix+0)
        ld d,(ix+1)
        call p0_put
        inc ix
        inc ix
        inc hl
        pop bc
        djnz .c
        pop hl
        ld de,40
        add hl,de
        pop bc
        ld a,(ds_col2)
        ld c,a
        djnz .r
        ret

; p0_clear: blank page 0 (and show it)
p0_clear:
        call clear_both
        jp show0
