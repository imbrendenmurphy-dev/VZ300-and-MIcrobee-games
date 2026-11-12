; =====================================================================
;  BOSS: drawn straight into the page from a bitmap pre-shifted 4 ways,
;  one glyph per cell in the page's boss bank (12 or 13), colours from
;  boss_pal (logical colours, so lights flash by changing the palette).
;  Stage 1: the COPYTRON 9000.
; =====================================================================
; ---------------------------------------------------------------------
; boss_draw: into the page being drawn (after the strips, before sprites)
; ---------------------------------------------------------------------
boss_draw:
        ld a,(boss_on)
        or a
        ret z
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
        ; screen position
        ld hl,(boss_x)
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld a,l
        ld (bd_c),a             ; first column
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
        xor a
        ld (bd_k),a
        ld (bd_cnt),a
        ld a,(stg_hdr+H_BOSSB)
        call map_blk
        ld a,(rpage)
        add a,BK_BOSS+LV_SCREEN
        out (P_LV),a
        ; ---- each column, each row
        xor a
        ld (bd_ci),a
        ld hl,0
        ld (bd_coff),hl
        ld (bd_colc),hl
.col:   ld a,(bd_ci)
        ld hl,bd_c
        add a,(hl)
        cp 40
        jp nc,.ncol
        ld (tmp),a              ; screen column
        xor a
        ld (bd_ri),a
.row:   ld a,(bd_ri)
        ld hl,bd_r
        add a,(hl)
        cp PF_TOP
        jp c,.nrow
        cp PF_TOP+PF_ROWS
        jp nc,.nrow
        ld (tmp+1),a            ; screen row
        ; the colour: band r (dy <= 4) or r-1; else the other one
        ld a,(bd_dy)
        cp 5
        ld a,(bd_ri)
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
.has:   ld (tmp+2),a
        ld a,(bd_k)
        cp 120
        jr nc,.nrow
        ; the source: column c, line 8 + r*8 - dy
        ld a,(bd_ri)
        add a,a
        add a,a
        add a,a
        add a,8
        ld hl,bd_dy
        sub (hl)
        ld e,a
        ld d,0
        ld hl,(bd_ptr)
        add hl,de
        ld de,(bd_coff)
        add hl,de
        ; destination: glyph k of the boss bank
        ld a,(bd_k)
        or $80
        ld e,a
        ld d,$0F
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        REPT 8
        ldi
        ENDR
        ; the list: cell, k, colour
        ld a,(tmp+1)
        ld e,a
        ld a,(tmp)
        ld d,a
        call cell_of
        ex de,hl
        ld a,(bd_cnt)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld bc,SCRATCH
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(bd_k)
        ld (hl),a
        inc hl
        ld a,(tmp+2)
        ld (hl),a
        ld hl,bd_k
        inc (hl)
        ld hl,bd_cnt
        inc (hl)
.nrow:  ld hl,bd_ri
        inc (hl)
        ld a,(bd_nr)
        inc a
        cp (hl)
        jp nz,.row
.ncol:  ld hl,(bd_coff)
        ld a,(bd_h)
        ld e,a
        ld d,0
        add hl,de
        ld (bd_coff),hl
        ld hl,(bd_colc)
        ld a,(bd_nr)
        ld e,a
        add hl,de
        ld (bd_colc),hl
        ld hl,bd_ci
        inc (hl)
        ld a,(bd_nc)
        cp (hl)
        jp nz,.col
        ld a,LV_SCREEN
        out (P_LV),a
        jp boss_commit
; .ink: A = band -> A = logical colour of (column c, band), Z if none
.ink:   cp 128
        jr nc,.z
        ld hl,bd_nr
        cp (hl)
        jr nc,.z
        ld e,a
        ld d,0
        ld hl,(bd_cm)
        add hl,de
        ld de,(bd_colc)
        add hl,de
        ld a,(hl)
        or a
        ret
.z:     xor a
        ret

; write the listed boss cells into the page, list them for restoring
boss_commit:
        ld a,(bd_cnt)
        or a
        ret z
        ld a,(vpg)
        ld c,a
        ; codes
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,(bd_cnt)
        ld b,a
        ld hl,SCRATCH
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
        ld hl,SCRATCH
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
        ld hl,SCRATCH
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
        ld hl,SCRATCH
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
bd_colc:    dw 0
bd_coff:    dw 0
bd_ci:      db 0
bd_ri:      db 0

