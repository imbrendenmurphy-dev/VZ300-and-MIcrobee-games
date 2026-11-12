; =====================================================================
;  BOSS: drawn straight into the page from a bitmap pre-shifted 4 ways,
;  one glyph per cell in the page's boss bank (12 or 13), colours from
;  boss_pal (logical colours, so lights flash by changing the palette).
;  Stage 1: the COPYTRON 9000.
; =====================================================================
; ---------------------------------------------------------------------
; ; boss_same: Z if the boss looks exactly as it did when this page last drew
; it (same variant, x, y): its glyphs in the page's bank are still right
boss_same:
        ld a,(rpage)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,bsig
        add hl,de
        ld a,(boss_on)
        or a
        jr nz,.on
        ld a,$FF                ; no boss: next time it's drawn afresh
        ld (bsig),a
        ld (bsig+4),a
        or a                    ; NZ
        ret
.on:    ld a,(boss_var)
        cp (hl)
        ret nz
        inc hl
        ld a,(boss_x)
        cp (hl)
        ret nz
        inc hl
        ld a,(boss_x+1)
        cp (hl)
        ret nz
        inc hl
        ld a,(boss_y)
        cp (hl)
        ret
; boss_sig_reset: both pages draw the boss afresh
boss_sig_reset:
        ld a,$FF
        ld (bsig),a
        ld (bsig+4),a
        ret
bsig:   ds 8,$FF

boss_draw:
        ld a,(boss_on)
        or a
        ret z
        call boss_same
        jp z,boss_commit        ; unchanged: just put its cells back
        ; remember what this page shows
        ld a,(rpage)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,bsig
        add hl,de
        ld a,(boss_var)
        ld (hl),a
        inc hl
        ld a,(boss_x)
        ld (hl),a
        inc hl
        ld a,(boss_x+1)
        ld (hl),a
        inc hl
        ld a,(boss_y)
        ld (hl),a
        ld a,(boss_hdr)
        ld (bd_nc),a
        ld a,(boss_hdr+1)
        ld (bd_nr),a
        ld a,(boss_hdr+2)
        add a,16
        ld (bd_h),a
        ; the variant and shift
        ld hl,(boss_x)
        ld a,l
        and 6
        add a,a                 ; shift * 4
        ld c,a
        ld a,(boss_var)
        add a,a
        add a,a
        add a,a
        add a,a                 ; var * 16
        add a,c
        ld e,a
        ld d,0
        ld hl,boss_data
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (bd_ptr),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (bd_cm),de
        ld (bd_cmc),de
        ; screen position
        ld hl,(boss_x)
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld a,l
        ld (bd_c),a             ; first column (may be off the left: >= 40 skipped)
        ld a,(boss_y)
        sub 24
        ld b,a
        and 7
        ld (bd_dy),a
        ld a,b
        rrca
        rrca
        rrca
        and $1F
        ld (bd_r),a             ; first row
        ; the bitmap source of column 0, row 0: bd_ptr + 8 - dy
        ld a,(bd_dy)
        neg
        add a,8
        ld e,a
        ld d,0
        ld hl,(bd_ptr)
        add hl,de
        ld (bd_src),hl
        ; the list of this page's boss cells
        call boss_list
        ld (bd_lst),ix
        xor a
        ld (bd_cnt),a
        ld (bd_ci),a
        ld a,(stg_hdr+H_BOSSB)
        call map_blk
        ld a,(rpage)
        add a,BK_BOSS+LV_SCREEN
        out (P_LV),a
        ld de,$F800             ; the next glyph of the boss bank
        ld (bd_dst),de
.col:   ld a,(bd_ci)
        ld hl,bd_c
        add a,(hl)
        cp 40
        jp nc,.ncol
        ; the cell of (column, first row)
        ld d,a
        ld a,(bd_r)
        ld e,a
        call cell_of
        ld (bd_cell),hl
        ld a,(bd_r)
        ld (bd_sr),a
        ld hl,(bd_src)
        ld (bd_s),hl
        xor a
        ld (bd_ri),a
.row:   ld a,(bd_sr)
        cp PF_TOP
        jr c,.nrow
        cp PF_TOP+PF_ROWS
        jr nc,.nrow
        ; the ink: band r (or r-1 when dy > 4), else the other band
        ld hl,(bd_cmc)
        ld a,(bd_ri)
        ld e,a
        ld a,(bd_dy)
        cp 5
        ld a,e
        jr c,.b0
        dec a
.b0:    call .ink
        jr nz,.has
        ld a,(bd_dy)
        or a
        jr z,.nrow
        cp 5
        ld a,(bd_ri)
        jr nc,.b1
        dec a
.b1:    call .ink
        jr z,.nrow
.has:   ld c,a                  ; C = logical colour
        ld a,(bd_cnt)
        cp 120
        jr nc,.nrow
        ; 8 lines of bitmap to the glyph
        ld hl,(bd_s)
        ld de,(bd_dst)
        REPT 8
        ldi
        ENDR
        ld hl,8
        add hl,de
        ld (bd_dst),hl          ; (PCG glyphs are 16 bytes apart)
        ; the list: cell lo, hi, glyph, colour
        ld ix,(bd_lst)
        ld hl,(bd_cell)
        ld (ix+0),l
        ld (ix+1),h
        ld a,(bd_cnt)
        ld (ix+2),a
        ld (ix+3),c
        inc a
        ld (bd_cnt),a
        ld de,4
        add ix,de
        ld (bd_lst),ix
.nrow:  ld hl,(bd_s)
        ld de,8
        add hl,de
        ld (bd_s),hl
        ld hl,(bd_cell)
        ld de,40
        add hl,de
        ld (bd_cell),hl
        ld hl,bd_sr
        inc (hl)
        ld hl,bd_ri
        inc (hl)
        ld a,(bd_nr)
        cp (hl)
        jp nc,.row              ; rows 0..nr (the shift can add one)
.ncol:  ld hl,(bd_src)          ; the next column
        ld a,(bd_h)
        ld e,a
        ld d,0
        add hl,de
        ld (bd_src),hl
        ld hl,(bd_cmc)
        ld a,(bd_nr)
        ld e,a
        add hl,de
        ld (bd_cmc),hl
        ld hl,bd_ci
        inc (hl)
        ld a,(bd_nc)
        cp (hl)
        jp nz,.col
        ld a,LV_SCREEN
        out (P_LV),a
        ; this page's cell count
        ld a,(rpage)
        ld e,a
        ld d,0
        ld hl,bdn
        add hl,de
        ld a,(bd_cnt)
        ld (hl),a
        jp boss_commit
; .ink: A = band, HL = this column's colours -> A = logical colour, Z if none
.ink:   cp 128
        jr nc,.z
        ld e,a
        ld a,(bd_nr)
        cp e
        jr z,.z
        jr c,.z
        ld d,0
        add hl,de
        ld a,(hl)
        sbc hl,de               ; (carry is clear: add didn't overflow)
        or a
        ret
.z:     xor a
        ret

; IX -> this page's list of boss cells (SCRATCH: page 0, SCRATCH+200h: page 1)
boss_list:
        ld ix,SCRATCH
        ld a,(rpage)
        or a
        ret z
        ld ix,SCRATCH+$200
        ret
bdn:        db 0,0
bd_src:     dw 0
bd_s:       dw 0
bd_sr:      db 0
bd_dst:     dw 0
bd_lst:     dw 0
bd_cmc:     dw 0

; write this page's listed boss cells into the page and list them for restoring
boss_commit:
        ld a,(rpage)
        ld e,a
        ld d,0
        ld hl,bdn
        add hl,de
        ld a,(hl)
        ld (bd_cnt),a
        or a
        ret z
        call boss_list
        push ix
        pop hl
        ld (bc_lst),hl
        ld a,(vpg)
        ld c,a
        ; codes
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,(bd_cnt)
        ld b,a
        ld hl,(bc_lst)
.c1:    ld e,(hl)
        inc hl
        ld a,(hl)
        add a,c
        ld d,a
        inc hl
        ld a,(hl)
        or $80
        ld (de),a
        inc hl
        inc hl
        djnz .c1
        ; banks
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(bd_cnt)
        ld b,a
        ld hl,(bc_lst)
        ld a,(rpage)
        add a,BK_BOSS
        ld (tmp+5),a
.c2:    ld e,(hl)
        inc hl
        ld a,(hl)
        add a,c
        ld d,a
        inc hl
        inc hl
        inc hl
        ld a,(tmp+5)
        ld (de),a
        djnz .c2
        ; colours
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,(bd_cnt)
        ld b,a
        ld hl,(bc_lst)
.c3:    ld e,(hl)
        inc hl
        ld a,(hl)
        add a,c
        add a,8
        ld d,a
        inc hl
        inc hl
        ld a,(boss_flash)
        or a
        ld a,WHITE
        jr nz,.w
        push hl
        ld a,(hl)
        ld hl,boss_pal
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
.w:     ex af,af'
        ld a,(de)
        and $F0
        ld (tmp+6),a
        ex af,af'
        push hl
        ld hl,tmp+6
        or (hl)
        pop hl
        ld (de),a
        inc hl
        djnz .c3
        xor a
        out (P_COLCTL),a
        ; restore list
        ld a,(rpage)
        or a
        ld de,BL0
        jr z,.p0
        ld de,BL1
.p0:    ld a,(bd_cnt)
        ld b,a
        ld (blcnt_tmp),a
        ld hl,(bc_lst)
.c4:    ld a,(hl)
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        add a,c
        ld (de),a
        inc de
        inc hl
        inc hl
        inc hl
        djnz .c4
        ld a,(rpage)
        ld e,a
        ld d,0
        ld hl,blcnt
        add hl,de
        ld a,(blcnt_tmp)
        ld (hl),a
        ret
blcnt_tmp:  db 0
bc_lst:     dw 0
bd_ci:      db 0
bd_ri:      db 0
