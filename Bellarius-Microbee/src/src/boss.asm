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
        jr nz,.on
        ; no boss: this page's old boss cells go back to the base picture
        call boss_sig_reset
        call bdn_ptr
        ld a,(hl)
        or a
        ret z
        ld (hl),0
        ld b,a
        call boss_list
.gone:  push bc
        ld e,(ix+0)
        ld d,(ix+1)
        call row_of
        call put_back
        ld bc,5
        add ix,bc
        pop bc
        djnz .gone
        ret
.on:    call boss_same
        jp z,.same
        ; ---- the boss has changed on this page: its old cells are marked
        call bdn_ptr
        ld a,(hl)
        or a
        jr z,.nold
        ld b,a
        call boss_list
.mo:    ld l,(ix+0)
        ld a,(ix+1)
        add a,CELLMAP/256
        ld h,a
        ld (hl),CM_OLDBOSS
        ld de,5
        add ix,de
        djnz .mo
.nold:  ; remember what this page shows
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
        ; the old box (to sweep afterwards), the new box
        ld a,(rpage)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,bk_org
        add hl,de
        ld a,(hl)
        ld (ob_c),a
        ld a,(bd_c)
        ld (hl),a
        inc hl
        ld a,(hl)
        ld (ob_r),a
        ld a,(bd_r)
        ld (hl),a
        inc hl
        ld a,(hl)
        ld (ob_nc),a
        ld a,(bd_nc)
        ld (hl),a
        inc hl
        ld a,(hl)
        ld (ob_nr),a
        ld a,(bd_nr)
        inc a
        ld (hl),a
        ; this page's BOSSK: none
        ld hl,bossk0
        ld a,(rpage)
        or a
        jr z,.k0
        ld hl,bossk1
.k0:    ld b,120
.kz:    ld (hl),0
        inc hl
        djnz .kz
        ; the bitmap source of column 0, row 0: bd_ptr + 8 - dy
        ld a,(bd_dy)
        neg
        add a,8
        ld e,a
        ld d,0
        ld hl,(bd_ptr)
        add hl,de
        ld (bd_src),hl
        call boss_list
        ld (bd_lst),ix
        call bdn_ptr
        ld a,(hl)
        ld (ob_cnt),a
        ld a,1
        ld (bd_same),a
        xor a
        ld (bd_cnt),a
        ld (bd_ci),a
.col:   ld a,(bd_ci)
        ld hl,bd_c
        add a,(hl)
        cp 40
        jp nc,.ncol
        ld (bd_col),a
        ld a,(bd_r)
        ld (bd_sr),a
        ld hl,(bd_src)
        ld (bd_s),hl
        xor a
        ld (bd_ri),a
        ld (bd_cv),a            ; (the cell is worked out at the first row on screen)
        ld hl,bossk0
        ld a,(rpage)
        or a
        jr z,.kc
        ld hl,bossk1
.kc:    ld a,(bd_ci)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (bd_kp),hl
.row:   ld a,(bd_sr)
        cp PF_TOP
        jp c,.nrow
        cp PF_TOP+PF_ROWS
        jp nc,.nrow
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
        jp z,.nrow
        cp 5
        ld a,(bd_ri)
        jr nc,.b1
        dec a
.b1:    call .ink
        jp z,.nrow
.has:   ld c,a                  ; C = logical colour
        ld a,(bd_cnt)
        cp BOSSN
        jp nc,.nrow
        ; this cell (cell_of once a column, then a row down each time)
        ld a,(bd_cv)
        or a
        jr nz,.cv
        inc a
        ld (bd_cv),a
        push bc
        ld a,(bd_col)
        ld d,a
        ld a,(bd_sr)
        ld e,a
        call cell_of
        ld (bd_cell),hl
        pop bc
.cv:    ; the paper under it: the row's sky, or the terrain there
        ld a,(bd_sr)
        ld l,a
        ld h,0
        ld de,rowstrip
        add hl,de
        ld a,(hl)
        cp $FF
        jr nz,.pst
        ld de,rowpaper-rowstrip
        add hl,de
        ld a,(hl)
        jr .pp
.pst:   ld a,(bd_col)
        ld (lk_col),a
        ld a,(bd_sr)
        ld (lk_row),a
        push bc
        call paper_at
        pop bc
.pp:    and $F0
        or c
        ld c,a
        ; the list: cell, paper << 4 | logical colour, bitmap source
        ld hl,(bd_cell)
        ld ix,(bd_lst)
        ld a,(ix+0)             ; the same cell as last time?
        cp l
        jr nz,.dif
        ld a,(ix+1)
        cp h
        jr z,.sm
.dif:   xor a
        ld (bd_same),a
.sm:    ld (ix+0),l
        ld (ix+1),h
        ld (ix+2),c
        ld a,h                  ; the cell map: a boss cell
        add a,CELLMAP/256
        ld h,a
        ld (hl),CM_BOSS
        ld hl,(bd_s)
        ld (ix+3),l
        ld (ix+4),h
        ld de,5
        add ix,de
        ld (bd_lst),ix
        ; BOSSK[ri*12+ci] = k+1
        ld hl,(bd_kp)
        ld a,(bd_cnt)
        inc a
        ld (hl),a
        ld (bd_cnt),a
.nrow:  ld hl,(bd_s)
        ld de,8
        add hl,de
        ld (bd_s),hl
        ld hl,(bd_kp)
        ld de,12
        add hl,de
        ld (bd_kp),hl
        ld a,(bd_cv)
        or a
        jr z,.nc
        ld hl,(bd_cell)
        ld de,40
        add hl,de
        ld (bd_cell),hl
.nc:
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
        ; this page's cell count; its glyphs to the PCG this blast
        call bdn_ptr
        ld a,(bd_cnt)
        ld (hl),a
        call bnew_ptr
        ld (hl),1
        ld a,(ob_cnt)           ; the same cells (only the glyphs moved)?
        ld hl,bd_cnt
        cp (hl)
        jr z,.sc0
        xor a
        ld (bd_same),a
.sc0:   call bcl_ptr
        ld a,(bd_same)
        xor 1
        ld (hl),a               ; 1: write the codes and banks too
        call bcol_fast
        ; sweep the old box: old cells the boss no longer covers go back
        ld a,(bd_same)
        or a
        ret nz                  ; (the very same cells: nothing uncovered)
        ld a,(ob_nr)
        or a
        ret z
        ld b,a
        ld a,(ob_r)
        ld (bd_sr),a
.sr:    push bc
        ld a,(bd_sr)
        cp PF_TOP
        jr c,.snr
        cp PF_TOP+PF_ROWS
        jr nc,.snr
        ld a,(ob_nc)
        or a
        jr z,.snr
        ld b,a
        ld a,(ob_c)
        ld c,a
        ld d,a
        ld a,(bd_sr)
        ld e,a
        call cell_of            ; HL = the row's first cell (column ob_c)
.sc:    ld a,c
        cp 40
        jr nc,.snc
        ld a,h
        add a,CELLMAP/256
        ld d,a
        ld e,l
        ld a,(de)
        cp CM_OLDBOSS
        jr nz,.snc
        xor a
        ld (de),a
        ld d,h
        ld e,l
        ld a,(bd_sr)
        call put_back
.snc:   inc hl
        inc c
        djnz .sc
.snr:   ld hl,bd_sr
        inc (hl)
        pop bc
        djnz .sr
        ret
        ; ---- the same as last time on this page: mark its cells
.same:  call bdn_ptr
        ld a,(hl)
        or a
        ret z
        ld b,a
        call boss_list
.ms:    ld l,(ix+0)
        ld a,(ix+1)
        add a,CELLMAP/256
        ld h,a
        ld (hl),CM_BOSS
        ld de,5
        add ix,de
        djnz .ms
        ; its colours again only if the palette (or what's under it) changed
.cols:  ld a,(st_new)
        or a
        jr nz,bcol_calc         ; the terrain moved under it: papers again
        call bcs_now
        call bcs_ptr
        ld a,(bcs_v)
        cp (hl)
        ret z
        jr bcol_fast
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

; bcs_now: (bcs_v) = a check value of the boss palette and its flash
bcs_now:
        ld hl,boss_pal
        ld a,(boss_flash)
        ld b,16
.l:     rlca
        add a,(hl)
        inc hl
        djnz .l
        ld (bcs_v),a
        ret
bcs_ptr:
        ld hl,bcsig
        jp bpg

; bcol_calc: the paper under each boss cell again (into its entry), then
; bcol_fast: each cell's colour = its paper | its ink now (BCOL); the
; blast writes them if any changed
bcol_calc:
        call bdn_ptr
        ld a,(hl)
        or a
        ret z
        ld b,a
        call boss_list
.p:     push bc
        ld e,(ix+0)
        ld d,(ix+1)
        call row_of
        ld (lk_row),a
        add a,a
        ld l,a
        ld h,0
        ld bc,rowtab
        add hl,bc
        ld a,e
        sub (hl)
        ld (lk_col),a
        call paper_at
        and $F0
        ld c,a
        ld a,(ix+2)
        and $0F
        or c
        ld (ix+2),a
        ld de,5
        add ix,de
        pop bc
        djnz .p
bcol_fast:
        call bcs_now
        call bcs_ptr
        ld a,(bcs_v)
        ld (hl),a
        call bdn_ptr
        ld a,(hl)
        or a
        ret z
        ld b,a
        call boss_list
        call bcol_ptr
        ld c,0                  ; any change?
.cl:    ld a,(boss_flash)
        or a
        ld a,WHITE
        jr nz,.w
        ld a,(ix+2)
        and $0F
        ld de,boss_pal
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        ld a,(de)
.w:     ld e,a
        ld a,(ix+2)
        and $F0
        or e
        cp (hl)
        jr z,.s
        ld (hl),a
        ld c,1
.s:     inc hl
        ld de,5
        add ix,de
        djnz .cl
        ld a,c
        or a
        ret z
        call bcd_ptr
        ld (hl),1
        ret

; HL -> this page's boss cell colours
bcol_ptr:
        ld hl,BCOL0
        ld a,(rpage)
        or a
        ret z
        ld hl,BCOL1
        ret

BOSSN   EQU 100                 ; boss cells at most (5 bytes each in a 512-byte list)

; paper_at: (lk_row), (lk_col) -> A = the colour under a boss cell (terrain or sky)
paper_at:
        ld a,(lk_row)
        ld l,a
        ld h,0
        ld de,rowstrip
        add hl,de
        ld a,(hl)
        cp $FF
        jr nz,.st
        ld a,(lk_row)
        ld l,a
        ld h,0
        ld de,rowpaper
        add hl,de
        ld a,(hl)
        ret
.st:    ld l,a                  ; strip_src + i*9 + 6: the colour plane
        add a,a
        add a,a
        add a,a
        add a,l
        add a,6
        ld l,a
        ld h,0
        ld de,strip_src
        add hl,de
        ld a,(hl)
        out (P_MEM),a
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(lk_col)
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        ld a,(curblk)
        out (P_MEM),a
        ld a,e
        ret

; boss_unmark: (after the blast) this page's boss cells off the cell map
boss_unmark:
        call bdn_ptr
        ld a,(hl)
        or a
        ret z
        ld b,a
        call boss_list
.l:     ld l,(ix+0)
        ld a,(ix+1)
        add a,CELLMAP/256
        ld h,a
        ld (hl),0
        ld de,5
        add ix,de
        djnz .l
        ret

; IX -> this page's list of boss cells (SCRATCH: page 0, SCRATCH+200h: page 1)
boss_list:
        ld ix,SCRATCH
        ld a,(rpage)
        or a
        ret z
        ld ix,SCRATCH+$200
        ret
; HL -> this page's boss cell count / "new glyphs" flag
bdn_ptr:
        ld hl,bdn
        jr bpg
bnew_ptr:
        ld hl,bnew
bpg:    ld a,(rpage)
        add a,l
        ld l,a
        ret nc
        inc h
        ret
bcd_ptr:
        ld hl,bcdirty
        jr bpg
bcl_ptr:
        ld hl,bcells
        jr bpg
bcells:     db 0,0
bd_cv:      db 0
bd_kp:      dw 0
ob_cnt:     db 0
bd_same:    db 0
bdn:        db 0,0
bnew:       db 0,0
bcdirty:    db 0,0
bcsig:      db 0,0
bcs_v:      db 0
bd_src:     dw 0
bd_s:       dw 0
bd_sr:      db 0
bd_lst:     dw 0
bd_cmc:     dw 0
bd_col:     db 0
bd_ci:      db 0
bd_ri:      db 0
ob_c:       db 0
ob_r:       db 0
ob_nc:      db 0
ob_nr:      db 0
