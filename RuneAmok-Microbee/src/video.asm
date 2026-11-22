; =====================================================================
;  VIDEO: the 40-column mode, two screen pages, PCG loading, the view
;  commit (shadow -> the hidden page, in the vertical blanking) and the
;  page flip, colour cycling, text.
;
;  Screen, attribute and colour RAM hold two pages (0 and 400h). The
;  6545 shows one; the view is committed to the other, then the start
;  address flips. Everything outside the view (frame, panel, messages)
;  is written to both pages.
; =====================================================================

; 40 x 25 cells of 8 x 10, 313 lines (the MODES.COM table, verified on
; the owner's Premium Plus)
crtc_tab:   db $35,$28,$2C,$34,$1E,$03,$19,$1C,$48,$09,$20,$09,0,0,0,0
crtc80:     db $6B,$50,$58,$37,$1B,$05,$18,$1A,$48,$0A,$2A,$0A,0,0,0,0
DROWS       EQU 25

hw_init:
        ld a,$CF                ; PIO A: inputs (joystick)
        out (P_PIOAC),a
        ld a,$FF
        out (P_PIOAC),a
        ld a,$07
        out (P_PIOAC),a
        ld a,$CF                ; PIO B: bit mode, b6 (speaker) out
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
        in a,(P_CLK40)
        ld hl,crtc_tab
        call crtc_set
        jp display_off

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
        ret

; set the 6545 start address to page A (0 / 1)
show_page:
        ld (vispage),a
        or a
        ld a,0
        jr z,.s
        ld a,PAGE1 >> 8
.s:     ld b,a
        ld a,12
        out (P_CRTCA),a
        ld a,b
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ret

; wait for the start of the vertical blanking (no sound)
vb_wait:
.a:     in a,(P_CRTCA)
        and $20
        jr nz,.a
.w:     in a,(P_CRTCA)
        and $20
        jr z,.w
        ret

; still in the vertical blanking? NZ = yes
in_vb:  in a,(P_CRTCA)
        and $20
        ret

; ---------------------------------------------------------------------
;  PCG loading: HL = source (10 bytes a glyph), A = first bank,
;  DE = glyph count. Lower window must hold the source.
; ---------------------------------------------------------------------
pcg_load:
        ld (pl_bank),a
.bank:  ld a,(pl_bank)
        or LV_SCREEN
        out (P_LV),a
        push de
        ld de,PCGWIN
        ld c,128
.g:     ld b,10
.b:     ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .b
        ld a,e
        add a,6
        ld e,a
        jr nc,.n
        inc d
.n:     ex (sp),hl              ; count
        dec hl
        ld a,h
        or l
        ex (sp),hl
        jr z,.done
        dec c
        jr nz,.g
        pop de
        ld a,(pl_bank)
        inc a
        ld (pl_bank),a
        jr .bank
.done:  pop de
        ld a,LV_SCREEN
        out (P_LV),a
        ret

; clear a PCG bank to zero: A = bank
pcg_clear:
        or LV_SCREEN
        out (P_LV),a
        ld hl,PCGWIN
        ld de,PCGWIN+1
        ld bc,$7FF
        ld (hl),0
        ldir
        ld a,LV_SCREEN
        out (P_LV),a
        ret

; fill both pages: every cell blank (font space), colour 0
screen_clear:
        ld hl,SCRSH
        ld de,SCRSH+1
        ld bc,$3FF
        ld (hl),$80
        ldir
        ld hl,COLSH
        ld de,COLSH+1
        ld bc,$3FF
        ld (hl),0
        ldir
        ld a,LV_SCREEN
        out (P_LV),a
        ld hl,VIDEO
        ld de,VIDEO+1
        ld bc,$7FF
        ld (hl),$80
        ldir
        ld a,LV_ATTR
        out (P_LV),a
        ld hl,VIDEO
        ld de,VIDEO+1
        ld bc,$7FF
        ld (hl),BK_FONT
        ldir
        ld a,COL_ON
        out (P_COLCTL),a
        ld hl,PCGWIN
        ld de,PCGWIN+1
        ld bc,$7FF
        ld (hl),0
        ldir
        xor a
        out (P_COLCTL),a
        ld a,LV_SCREEN
        out (P_LV),a
        ret

; ---------------------------------------------------------------------
;  one cell on both pages: HL = cell offset (row*40+col), B = code,
;  C = attribute, A = colour
; ---------------------------------------------------------------------
put2:   push de
        ld e,a
        ; unchanged? (the shadows SCRSH / COLSH, bank 15 marked by +80h)
        push hl
        ld a,c
        cp BK_UI
        ld a,e
        jr nz,.k
        or $80
.k:     ld d,a
        push de
        ld de,SCRSH
        add hl,de
        ld a,(hl)
        cp b
        ld (hl),b
        ld de,COLSH-SCRSH
        add hl,de
        pop de
        jr nz,.ch
        ld a,(hl)
        cp d
        jr nz,.ch
        pop hl
        ld a,e
        pop de
        ret
.ch:    ld (hl),d
        pop hl
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,h
        or VIDEO >> 8
        ld h,a
        ld (hl),b
        set 2,h
        ld (hl),b
        ld a,LV_ATTR
        out (P_LV),a
        ld (hl),c
        res 2,h
        ld (hl),c
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        set 3,h                 ; F000 -> F800 (colour window)
        ld (hl),e
        set 2,h
        ld (hl),e
        xor a
        out (P_COLCTL),a
        ld a,h
        and $03
        ld h,a
        ld a,e
        pop de
        ret

; ---------------------------------------------------------------------
;  text. print: HL = string (0 ends; 1 = next byte is a new colour),
;  DE = cell offset, A = colour. Characters 32..127 are font glyphs
;  80h+ in bank 14.
; ---------------------------------------------------------------------
print:  ld (pr_col),a
.c:     ld a,(hl)
        inc hl
        or a
        ret z
        cp 1
        jr nz,.ch
        ld a,(hl)
        inc hl
        ld (pr_col),a
        jr .c
.ch:    push hl
        add a,$80-32
        ld b,a
        ld c,BK_FONT
        ex de,hl
        ld a,(pr_col)
        call put2
        inc hl
        ex de,hl
        pop hl
        jr .c

; print at row B, column C
print_at:
        push af
        push hl
        ld h,0
        ld l,b
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; row * 40
        ld d,0
        ld e,c
        add hl,de
        ex de,hl
        pop hl
        pop af
        jr print

; A = number 0..65535 in HL -> decimal at DE (cell offset), colour (pr_col),
; right-aligned in B digits (spaces in front)
num_buf:    ds 6
print_num:
        push de
        ld de,num_buf+5
        xor a
        ld (de),a
        ld c,b
.d:     dec de
        push bc
        push de
        ld de,10
        call div16              ; HL = HL / 10, A = remainder
        pop de
        pop bc
        add a,'0'
        ld (de),a
        dec c
        ld a,h
        or l
        jr nz,.d
.sp:    ld a,c
        or a
        jr z,.p
        dec de
        ld a,' '
        ld (de),a
        dec c
        jr .sp
.p:     ex de,hl
        pop de
        ld a,(pr_col)
        jp print

; HL = HL / DE, A = remainder (DE < 256)
div16:  ld b,16
        xor a
.l:     add hl,hl
        rla
        cp e
        jr c,.n
        sub e
        inc l
.n:     djnz .l
        ret

; ---------------------------------------------------------------------
;  the view commit: copy the shadow (SHC/SHA/SHK) into the hidden page,
;  a row at a time while the vertical blanking lasts; then flip.
;  vb_commit is called at the start of each blanking.
; ---------------------------------------------------------------------
vb_commit:
        ld a,(cm_state)
        or a
        ret z
        cp 2
        jr z,.flip
.row:   call in_vb
        ret z                   ; the picture has started: carry on next time
        ld a,(cm_row)
        call commit_row
        ld a,(cm_row)
        inc a
        ld (cm_row),a
        cp VH
        jr nz,.row
        ld a,2
        ld (cm_state),a
        call in_vb
        ret z
.flip:  ld a,(vispage)
        xor 1
        call show_page
        xor a
        ld (cm_state),a
        ld (cm_row),a
        ret

; A = view row -> copy its 24 cells, 3 planes, to the hidden page
commit_row:
        ld l,a
        ld h,0
        add hl,hl
        ld de,row24
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = row * 24
        push de
        ld l,a
        ld h,0
        add hl,hl
        ld bc,row40
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; HL = (row+1)*40 + 1
        ld a,(vispage)
        xor 1
        jr z,.p0
        set 2,h                 ; page 1 = +400h
.p0:    ld a,h
        or VIDEO >> 8
        ld h,a
        ex de,hl                ; DE = video address
        pop hl
        push hl
        push de
        ld bc,SHC
        add hl,bc
        ld a,LV_SCREEN
        out (P_LV),a
        ld bc,VW
        ldir
        pop de
        pop hl
        push hl
        push de
        ld bc,SHA
        add hl,bc
        ld a,LV_ATTR
        out (P_LV),a
        ld bc,VW
        ldir
        ld a,LV_SCREEN
        out (P_LV),a
        pop de
        pop hl
        ld bc,SHK
        add hl,bc
        set 3,d                 ; colour window at F800
        ld a,COL_ON
        out (P_COLCTL),a
        ld bc,VW
        ldir
        xor a
        out (P_COLCTL),a
        ret

; row24 / row40 are in the generated include

; start a commit of the shadow (the caller composed it)
commit_start:
        xor a
        ld (cm_row),a
        inc a
        ld (cm_state),a
        ret

; wait until no commit is in progress (plays sound meanwhile)
commit_wait:
.w:     ld a,(cm_state)
        or a
        ret z
        call frame
        jr .w

; ---------------------------------------------------------------------
;  colour cycling of the animated view cells, on the shown page
; ---------------------------------------------------------------------
vb_anim:
        ld a,(cm_state)
        or a
        ret nz                  ; the list belongs to the page being built
        ld a,(nanim)
        or a
        ret z
        ld b,a
        ld a,(tick)
        and $0F
        ld c,a
        ld hl,ANIMS
        ld a,COL_ON
        out (P_COLCTL),a
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)               ; class 1..7
        inc hl
        push hl
        add a,a
        add a,a
        add a,a
        add a,a                 ; class * 16 (classes 1..15)
        add a,c
        ld l,a
        ld h,high(cyc_tab)
        ld a,(vispage)
        or a
        ld a,(hl)
        ex de,hl                ; HL = cell offset
        set 3,h
        jr z,.p0
        set 2,h
.p0:    ld e,a
        ld a,h
        or $F0
        ld h,a
        ld (hl),e
        pop hl
        djnz .l
        xor a
        out (P_COLCTL),a
        ret

        ALIGN 256
cyc_tab:    ds 16                   ; class 0: none
; ink cycles, 16 steps each (class 1 flame, 2 rune, 3 water, 4 portal,
; 5 glow, 6 hurt flash, 7 spark)
        db YELLOW,YELLOW,BRED,YELLOW,WHITE,YELLOW,BRED,BRED,YELLOW,YELLOW,BRED,YELLOW,YELLOW,WHITE,BRED,YELLOW
        db MAGENTA,MAGENTA,MAGENTA,BMAGENTA,BMAGENTA,WHITE,BMAGENTA,BMAGENTA,MAGENTA,MAGENTA,BLUE,BLUE,BLUE,MAGENTA,MAGENTA,MAGENTA
        db BLUE,CYAN,BCYAN,CYAN,BLUE,BLUE,CYAN,CYAN,BCYAN,WHITE,BCYAN,CYAN,BLUE,BLUE,BLUE,CYAN
        db BMAGENTA,BBLUE,BCYAN,WHITE,BCYAN,BBLUE,BMAGENTA,MAGENTA,BMAGENTA,BBLUE,BCYAN,WHITE,BCYAN,BBLUE,BMAGENTA,MAGENTA
        db GREEN,GREEN,BGREEN,BGREEN,BGREEN,WHITE,BGREEN,BGREEN,GREEN,GREEN,GREEN,CYAN,CYAN,GREEN,GREEN,GREEN
        db WHITE,WHITE,BRED,BRED,WHITE,WHITE,BRED,BRED,WHITE,WHITE,BRED,BRED,WHITE,WHITE,BRED,BRED
        db YELLOW,WHITE,BCYAN,WHITE,YELLOW,BRED,YELLOW,WHITE,BCYAN,BBLUE,BCYAN,WHITE,YELLOW,WHITE,BRED,YELLOW
