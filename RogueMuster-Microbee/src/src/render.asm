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

; dl_begin: blank the hidden page's cells from last time, start its new list
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
        ld a,$80
.l:     pop de
        pop hl
        pop hl
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

; draw_sprite: A = frame, D = x, E = y (4-pixel units), C = colour
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
        DLPUT
        inc de
        inc b
        DLPUT
        ld (dlp),hl
        ret

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
        add a,$60
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
        add a,$60
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
        add a,$90
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

; show_pic: A = 0 title, 1 the rogue mob. Shown on page 0.
show_pic:
        ld hl,PIC_TITLE
        or a
        jr z,$+5
        ld hl,PIC_INFO
        push hl
        ld a,BLK_GFX
        call map_blk
        pop hl
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
        ld a,12
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ret
