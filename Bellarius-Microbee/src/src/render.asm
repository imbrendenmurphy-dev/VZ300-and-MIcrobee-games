; =====================================================================
;  RENDER: the BELLARIUS screen engine (40 x 25 cells of 8 x 8).
;
;  Two pages (video 000h and 400h) flipped with the 6545 start address.
;  Each frame the hidden page is rebuilt in this order:
;   1. restore: cells that held sprites, shots or the boss two frames ago
;      go back to the base picture (RT block: cur_lo / cur_hi / cur_col)
;   2. strips: every terrain row is copied in from the stage's pre-shifted
;      strip runs (40 bytes per row per plane, unrolled LDI)
;   3. the boss: written straight into the page (boss.asm)
;   4. sprites: pre-shifted, masked, composited into the page's pool bank
;   5. small objects (bullets, shots, beams): ready-made glyphs written
;      straight into sky cells, OR-ed into a pool glyph anywhere else
;   6. commit: codes, banks and colours of the new cells; restore lists
;  then the beeper plays until the frame's time is up and the page shows.
; =====================================================================

; ---------------------------------------------------------------------
; frame_begin: start drawing page (rpage)
; ---------------------------------------------------------------------
frame_begin:
        call vschk
        ld a,(rpage)
        add a,a
        add a,a
        ld b,a
        add a,VIDEO/256
        ld (vpg),a
        ld a,b
        add a,COLWIN/256
        ld (cpg),a
        ld a,(rpage)
        add a,BK_POOL+LV_SCREEN
        ld (poolport),a
        xor a
        ld (poolcnt),a
        ld (dlcnt),a
        ; the restore lists of this page
        ld a,(rpage)
        or a
        ld hl,RL0
        ld de,BL0
        jr z,.p0
        ld hl,RL1
        ld de,BL1
.p0:    ld (rl_cur),hl
        ld (bl_cur),de
        ld a,(rpage)
        ld c,a
        ld b,0
        ld hl,rlcnt
        add hl,bc
        ld a,(hl)
        ld (hl),0
        or a
        jr z,.nb
        ld b,a
        ld hl,(rl_cur)
        call rs_list
.nb:    call boss_same          ; the boss as this page has it: its cells stay
        ret z
        ld a,(rpage)
        ld c,a
        ld b,0
        ld hl,blcnt
        add hl,bc
        ld a,(hl)
        ld (hl),0
        or a
        ret z
        ld b,a
        ld hl,(bl_cur)
        jp rs_list

; rs_list: B = cells (1..255) of the word list HL (video addresses of the page):
; back to the base picture. Plain rows hold the blank glyph in their own colour
; (rs_full = 0, the game), or any glyph (rs_full = 1, the front end).
rs_list:
        ld (rs_ptr),hl
        ld a,b
        ld (rs_n),a
        ld a,(curblk)
        ld (rs_blk),a
        ld a,BLK_RT
        call map_blk
        ld (rs_sp),sp
        ld a,(rs_full)
        or a
        jr nz,.full
        ; codes: the blank glyph
        ld a,LV_SCREEN
        out (P_LV),a
        ld sp,(rs_ptr)
        ld c,$80
.s:     pop hl
        ld (hl),c
        djnz .s
        ; banks: 0
        ld a,LV_ATTR
        out (P_LV),a
        ld sp,(rs_ptr)
        ld a,(rs_n)
        ld b,a
        ld c,0
.a:     pop hl
        ld (hl),c
        djnz .a
        jr .col
.full:  ld a,LV_SCREEN
        out (P_LV),a
        ld sp,(rs_ptr)
        ld c,RT_CURLO/256
        call .from
        ld a,LV_ATTR
        out (P_LV),a
        ld sp,(rs_ptr)
        ld a,(rs_n)
        ld b,a
        ld c,RT_CURHI/256
        call .from
.col:   ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld sp,(rs_ptr)
        ld a,(rs_n)
        ld b,a
.c:     pop hl                  ; 10
        ld a,h                  ; 4
        and 3                   ; 7
        or RT_CURCOL/256        ; 7
        ld d,a                  ; 4
        ld e,l                  ; 4
        ld a,(de)               ; 7
        set 3,h                 ; 8  F0xx -> F8xx
        ld (hl),a               ; 7
        djnz .c                 ; 13 = 71
        xor a
        out (P_COLCTL),a
        ld sp,(rs_sp)
        ld a,(rs_blk)
        jp map_port
; (the stack is the list here: no calls inside the loop)
.from:  ld (rs_c),a
.f:     pop hl
        ld a,h
        and 3
        or c
        ld d,a
        ld e,l
        ld a,(de)
        ld (hl),a
        djnz .f
        ret

; ---------------------------------------------------------------------
; strips: copy the terrain rows into the page. strip_tab: for each plane
; k (0 codes, 1 banks, 2 colours), each strip row i, each phase p: db port,
; dw address (the run of map columns 0..). row_dst: dw (row+1)*40 per strip
; row; row_far: 1 = the row scrolls at half speed.
; ---------------------------------------------------------------------
strips:
        ld a,(nstrip)
        or a
        ret z
        ld a,(curblk)
        ld (st_blk),a
        ld ix,strip_tab
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,(vpg)
        call .plane
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(vpg)
        call .plane
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,(cpg)
        call .plane
        xor a
        out (P_COLCTL),a
        call vschk
        ld a,(st_blk)
        jp map_port
.plane: ld (st_pg),a
        ld iy,row_dst
        ld a,(nstrip)
        ld b,a
.row:   push bc
        ld a,(iy+2)             ; far row?
        or a
        ld a,(scr_p)
        ld de,(scr_m)
        jr z,.near
        ld a,(far_p)
        ld de,(far_m)
.near:  ld c,a
        add a,a
        add a,c                 ; p*3
        ld c,a
        ld b,0
        push ix
        add ix,bc
        ld a,(ix+0)
        out (P_MEM),a
        ld l,(ix+1)
        ld h,(ix+2)
        pop ix
        add hl,de
        ld e,(iy+0)
        ld a,(st_pg)
        add a,(iy+1)
        ld d,a
        REPT 40
        ldi
        ENDR
        ld bc,12
        add ix,bc
        ld bc,3
        add iy,bc
        pop bc
        dec b
        jp nz,.row
        call vschk
        ret

; ---------------------------------------------------------------------
; spr_draw: HL = sprite frame number, (spr_x) = left x (signed 16, screen
; pixels), (spr_y) = top y (signed 16, screen pixels), (spr_ink) = colour.
; Clipped to the playfield. Frame: db w (byte columns), h, ax, ay; dw offsets
; of shifts 0..3 (0,2,4,6 px); per shift, per byte column: db first row,
; db rows, rows x (and mask, data).  spr_tab: dw address, db block.
; ---------------------------------------------------------------------
spr_draw:
        push ix
        call .go
        pop ix
        ret
.go:    ld l,a                  ; A = frame id
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,spr_tab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; header
        inc hl
        ld a,(hl)               ; block
        call map_blk
        ex de,hl
        push hl                 ; header
        ld a,(hl)
        ld (sd_cn),a            ; columns
        inc hl
        inc hl
        ld c,(hl)               ; ax
        inc hl
        ld b,(hl)               ; ay
        push hl
        ld hl,(spr_y)
        ld e,b
        ld d,0
        or a
        sbc hl,de
        ld (sd_top),hl
        ld hl,(spr_x)
        ld e,c
        or a
        sbc hl,de
        ld a,l
        and 6                   ; shift * 2
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld (sd_col),hl
        pop hl
        inc hl                  ; -> offsets
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        add hl,de
        ld (sd_src),hl
        ld a,(poolport)
        out (P_LV),a
.col:   ld hl,(sd_src)
        ld a,(hl)               ; first row
        inc hl
        ld c,(hl)               ; rows
        inc hl
        ld (cb_s),hl
        ld b,0
        add hl,bc
        add hl,bc
        ld (sd_src),hl          ; the next column
        ld e,a
        ld a,c
        or a
        jr z,.skipc
        ld (cb_n),a
        ld a,(sd_col+1)
        or a
        jr nz,.skipc            ; < 0 or > 255
        ld a,(sd_col)
        cp 40
        jr nc,.skipc
        ld (sd_cx),a
        ld d,0
        ld hl,(sd_top)
        add hl,de
        ld (cb_y),hl
        call col_blit
.skipc: ld hl,(sd_col)
        inc hl
        ld (sd_col),hl
        ld hl,sd_cn
        dec (hl)
        jr nz,.col
        call vschk
        ret

; col_blit: column (sd_cx) from screen line (cb_y), (cb_n) lines, source (cb_s)
col_blit:
        ld hl,(cb_y)
        ld a,(cb_n)
        ld c,a
        ; clip the top at PF_Y0
        ld de,PF_Y0
        or a
        sbc hl,de
        jr nc,.pos
        ld a,l                  ; lines above the playfield (negative)
        neg
        ld b,a
        ld a,h
        inc a
        ret nz                  ; far above
        ld a,b
        cp c
        ret nc
        ld a,c
        sub b
        ld c,a
        ld l,b
        ld h,0
        add hl,hl
        ld de,(cb_s)
        add hl,de
        ld (cb_s),hl
        ld hl,0
.pos:   ld a,h
        or a
        ret nz                  ; below the screen
        ld a,l
        cp PF_Y1-PF_Y0
        ret nc
        add a,c
        cp PF_Y1-PF_Y0+1
        jr c,.ok
        ld a,PF_Y1-PF_Y0        ; clip the bottom
        sub l
        ld c,a
.ok:    ld a,c
        ld (cb_left),a
        ld a,l
        add a,PF_Y0
        ld l,a
        and 7
        ld (cb_r),a
        ld a,l
        rrca
        rrca
        rrca
        and $1F
        ld e,a
        ld a,(sd_cx)
        ld d,a
        call cell_of
        ld (cb_cell),hl
.seg:   ld a,(cb_r)
        ld e,a
        ld a,8
        sub e
        ld hl,cb_left
        cp (hl)
        jr c,.k
        ld a,(hl)
.k:     ld (cb_n),a
        ld hl,(cb_cell)
        call cell_alloc
        jr c,.full
        or $80
        ld l,a
        ld h,$0F
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(cb_r)
        or l
        ld l,a
        ld a,(cb_n)
        call seg_blit
        jr .nx
.full:  ld a,(cb_n)
        ld l,a
        ld h,0
        add hl,hl
        ld de,(cb_s)
        add hl,de
        ld (cb_s),hl
.nx:    ld hl,(cb_cell)
        ld de,40
        add hl,de
        ld (cb_cell),hl
        xor a
        ld (cb_r),a
        ld a,(cb_left)
        ld hl,cb_n
        sub (hl)
        ld (cb_left),a
        jr nz,.seg
        ret

; seg_blit: HL = destination glyph row, A = rows (1..8), source (cb_s)
seg_blit:
        ld (sb_sp),sp
        add a,a
        ld e,a
        ld d,0
        ld ix,sb_tab
        add ix,de
        ld e,(ix+0)
        ld d,(ix+1)
        ld ixl,e
        ld ixh,d
        ld sp,(cb_s)
        jp (ix)
sb_tab: dw sb_0,sb_1,sb_2,sb_3,sb_4,sb_5,sb_6,sb_7,sb_8
SBROW   MACRO
        pop bc
        ld a,(hl)
        and c
        or b
        ld (hl),a
        inc l
        ENDM
sb_8:   SBROW
sb_7:   SBROW
sb_6:   SBROW
sb_5:   SBROW
sb_4:   SBROW
sb_3:   SBROW
sb_2:   SBROW
sb_1:   SBROW
sb_0:   ld (cb_s),sp
        ld sp,(sb_sp)
        ret

; ---------------------------------------------------------------------
; cell_alloc: HL = cell -> A = the pool glyph for it this frame (C = full).
; A new pool glyph starts as a copy of the page's glyph in the cell.
; ---------------------------------------------------------------------
cell_alloc:
        ld d,h
        ld e,l
        ld a,h
        add a,CELLMAP/256
        ld h,a
        ld a,(hl)
        or a
        jr z,.new
        dec a                   ; pool glyph already (sprites come before objects)
        ld l,a
        ld h,PL_INK/256
        ld c,a
        ld a,(spr_ink)
        ld (hl),a
        ld a,c
        or a
        ret
.new:   call pool_new
        ret c
        push af
        ; the page's glyph: code and bank
        ld a,(vpg)
        add a,d
        ld h,a
        ld l,e
        ld a,(poolport)
        or $10
        out (P_LV),a
        ld e,(hl)               ; bank
        ld a,(poolport)
        out (P_LV),a
        ld a,(hl)               ; code
        call bg_copy
        pop af
        ret

; pool_new: DE = cell, HL -> its CELLMAP entry (0). -> A = k, BC = F800h+k*16
pool_new:
        ld a,(poolcnt)
        cp POOLN
        jr nc,.full
        ld c,a
        inc a
        ld (hl),a
        ld (poolcnt),a
        ld l,c
        ld h,PL_LO/256
        ld (hl),e
        inc h
        ld (hl),d
        inc h
        ld a,(spr_ink)
        ld (hl),a
        ld a,c
        ld (pn_k),a
        or $80
        ld l,a
        ld h,$0F
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ld a,(pn_k)
        or a                    ; NC
        ret
.full:  scf
        ret

; bg_copy: A = glyph code, E = bank: its 8 lines to the pool glyph at BC
; (the PCG window shows the pool bank; a sprite block is in the lower window)
bg_copy:
        bit 7,a
        jr z,.blank
        and $7F
        ld l,a
        ld a,e
        and $0F
        jr nz,.nz
        or l
        jr z,.blank
        xor a
.nz:    cp STORE_TOP
        jr nc,.slow
        add a,a
        add a,a
        ld e,a                  ; bank * 4: high byte of bank * 1024
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,e
        ld h,a
        ld d,b
        ld e,c
        REPT 8
        ldi
        ENDR
        ret
.blank: ld h,b
        ld l,c
        xor a
        REPT 8
        ld (hl),a
        inc l
        ENDR
        ret
.slow:  push bc                 ; read it back from its PCG bank
        or LV_SCREEN
        out (P_LV),a
        ld a,l
        or $80
        ld l,a
        ld h,$0F
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,GLYPHBUF
        REPT 8
        ldi
        ENDR
        ld a,(poolport)
        out (P_LV),a
        pop de
        ld hl,GLYPHBUF
        REPT 8
        ldi
        ENDR
        ret

; ---------------------------------------------------------------------
; obj_draw: a small object from ready-made glyphs. A = kind, (spr_x),
; (spr_y) = its top-left (screen pixels, signed 16), (spr_ink).
; gk_tab: dw per kind -> 32 x dw (x phase 0..3, y 0..7) -> piece list:
; db n, n x (db dc, db dr, dw glyph)
; ---------------------------------------------------------------------
obj_draw:
        ld l,a
        ld h,0
        add hl,hl
        ld de,GK_TAB
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(spr_x)
        and 6
        add a,a
        add a,a
        add a,a                 ; xphase * 16
        ld c,a
        ld a,(spr_y)
        and 7
        add a,a
        add a,c
        ld l,a
        ld h,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; the piece list
        ; base cell column, row (signed)
        ld hl,(spr_x)
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld (od_c),hl
        ld hl,(spr_y)
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld (od_r),hl
        ex de,hl
        ld b,(hl)
        inc hl
.p:     push bc
        ld a,(od_c)
        add a,(hl)
        ld d,a                  ; column
        inc hl
        ld a,(od_r)
        add a,(hl)
        ld e,a                  ; row
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; glyph
        inc hl
        push hl
        ; clip (rough: the object is never more than a cell or two off)
        ld a,(od_c+1)
        or a
        jr z,.cx
        inc a
        jr nz,.no               ; far off
        ld a,d
        cp $FE
        jr nc,.no
        jr .cy
.cx:    ld a,d
        cp 40
        jr nc,.no
.cy:    ld a,(od_r+1)
        or a
        jr nz,.no
        ld a,e
        cp PF_TOP
        jr c,.no
        cp PF_TOP+PF_ROWS
        jr nc,.no
        call cell_of
        call gput
.no:    pop hl
        pop bc
        djnz .p
        ret

; gput: HL = cell, BC = ready-made glyph number. Into the cell (see above).
gput:
        ld (gp_g),bc
        ld d,h
        ld e,l
        ld a,h
        add a,CELLMAP/256
        ld h,a
        ld a,(hl)
        or a
        jr z,.free
        jp p,.pool
        ; a direct cell already: it becomes a pool glyph
        and $7F
        ld (gp_d),a
        push hl
        call pool_new
        pop hl
        ret c
        push bc
        ld a,(gp_d)
        ld l,a
        ld h,DL_BANK/256
        ld e,(hl)
        ld (hl),$FF             ; void
        ld h,DL_CODE/256
        ld a,(hl)
        call bg_copy
        pop bc
        jr .or
.pool:  dec a
        ld l,a
        ld h,PL_INK/256
        ld c,a
        ld a,(spr_ink)
        ld (hl),a
        ld a,c
        or $80
        ld l,a
        ld h,$0F
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        jr .or
.free:  push hl
        ld a,(vpg)
        add a,d
        ld h,a
        ld l,e
        ld a,(hl)               ; code
        ld (gp_code),a
        ld a,(poolport)
        or $10
        out (P_LV),a
        ld c,(hl)               ; bank
        ld a,(poolport)
        out (P_LV),a
        pop hl
        ld a,(gp_code)
        cp $80
        jr nz,.comp
        ld a,c
        or a
        jr nz,.comp
        ; sky: a direct cell
        ld a,(dlcnt)
        cp DLN
        jr nc,.comp
        ld c,a
        inc a
        ld (dlcnt),a
        ld a,c
        or $80
        ld (hl),a               ; CELLMAP
        ld l,c
        ld h,DL_LO/256
        ld (hl),e
        ld h,DL_HI/256
        ld (hl),d
        ld bc,(gp_g)
        ld a,c
        or $80
        ld h,DL_CODE/256
        ld (hl),a
        ld a,c
        rla
        ld a,b
        rla
        ld h,DL_BANK/256
        ld (hl),a
        ld a,(spr_ink)
        ld h,DL_INK/256
        ld (hl),a
        ret
.comp:  ld a,c
        ld (gp_bank),a
        call pool_new           ; (HL -> the CELLMAP entry, DE = cell)
        ret c
        push bc
        ld a,(gp_bank)
        ld e,a
        ld a,(gp_code)
        call bg_copy
        pop bc
        ; OR the ready-made glyph in: store address = glyph * 8
.or:    ld hl,(gp_g)
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,b
        ld e,c
        REPT 8
        ld a,(de)
        or (hl)
        ld (de),a
        inc l
        inc e
        ENDR
        ret

; ---------------------------------------------------------------------
; commit: write the frame's new cells into the page and list them
; ---------------------------------------------------------------------
commit:
        call vschk
        ld a,(vpg)
        ld c,a
        ld de,(rl_cur)
        ld a,(rpage)
        ld l,a
        ld h,0
        push de
        ld de,rlcnt
        add hl,de
        ld (cm_cnt),hl
        pop de
        ; ---- direct cells
        ld a,(dlcnt)
        or a
        jp z,.pool
        ld b,a
        ld a,LV_SCREEN
        out (P_LV),a
        ld l,0
.d1:    ld h,DL_BANK/256
        ld a,(hl)
        inc a
        jr z,.d1n               ; void
        ld h,DL_CODE/256
        ld a,(hl)
        ex af,af'
        ld h,DL_HI/256
        ld a,(hl)
        add a,c
        ld d,a
        ld h,DL_LO/256
        ld e,(hl)
        ex af,af'
        ld (de),a
.d1n:   inc l
        djnz .d1
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(dlcnt)
        ld b,a
        ld l,0
.d2:    ld h,DL_BANK/256
        ld a,(hl)
        cp $FF
        jr z,.d2n
        ex af,af'
        ld h,DL_HI/256
        ld a,(hl)
        add a,c
        ld d,a
        ld h,DL_LO/256
        ld e,(hl)
        ex af,af'
        ld (de),a
.d2n:   inc l
        djnz .d2
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,(dlcnt)
        ld b,a
        ld l,0
.d3:    ld h,DL_BANK/256
        ld a,(hl)
        cp $FF
        jr z,.d3n
        ld h,DL_HI/256
        ld a,(hl)
        add a,c
        add a,8
        ld d,a
        ld h,DL_LO/256
        ld e,(hl)
        ld a,(de)
        and $F0
        ld h,DL_INK/256
        or (hl)
        ld (de),a
.d3n:   inc l
        djnz .d3
        xor a
        out (P_COLCTL),a
        ; list them, clear CELLMAP
        ld a,(dlcnt)
        ld b,a
        ld l,0
.d4:    ld h,DL_HI/256
        ld d,(hl)
        ld h,DL_LO/256
        ld e,(hl)
        push hl
        ld a,d
        add a,CELLMAP/256
        ld h,a
        ld l,e
        ld (hl),0
        ld a,d
        add a,c
        ld d,a
        call rl_add
        pop hl
        inc l
        djnz .d4
        ; ---- pool cells
.pool:  ld a,(poolcnt)
        or a
        jp z,.done
        ld b,a
        ld a,LV_SCREEN
        out (P_LV),a
        ld l,0
.p1:    ld h,PL_HI/256
        ld a,(hl)
        add a,c
        ld d,a
        ld h,PL_LO/256
        ld e,(hl)
        ld a,l
        or $80
        ld (de),a
        inc l
        djnz .p1
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(poolcnt)
        ld b,a
        ld a,(rpage)
        add a,BK_POOL
        ld ixl,a
        ld l,0
.p2:    ld h,PL_HI/256
        ld a,(hl)
        add a,c
        ld d,a
        ld h,PL_LO/256
        ld e,(hl)
        ld a,ixl
        ld (de),a
        inc l
        djnz .p2
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,(poolcnt)
        ld b,a
        ld l,0
.p3:    ld h,PL_HI/256
        ld a,(hl)
        add a,c
        add a,8
        ld d,a
        ld h,PL_LO/256
        ld e,(hl)
        ld a,(de)
        and $F0
        ld h,PL_INK/256
        or (hl)
        ld (de),a
        inc l
        djnz .p3
        xor a
        out (P_COLCTL),a
        ld a,(poolcnt)
        ld b,a
        ld l,0
.p4:    ld h,PL_HI/256
        ld d,(hl)
        ld h,PL_LO/256
        ld e,(hl)
        push hl
        ld a,d
        add a,CELLMAP/256
        ld h,a
        ld l,e
        ld (hl),0
        ld a,d
        add a,c
        ld d,a
        call rl_add
        pop hl
        inc l
        djnz .p4
.done:  call vschk
        ret

; rl_add: DE = video address -> the page's restore list (max 255)
rl_add: ld hl,(cm_cnt)
        ld a,(hl)
        cp 255
        ret z
        inc (hl)
        ld l,a
        ld h,0
        add hl,hl
        push bc
        ld bc,(rl_cur)
        add hl,bc
        pop bc
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; ---------------------------------------------------------------------
; frame_end: commit, play the beeper until the frame's time is up, show
; the page. Two fields a frame at least (25 frames a second).
; ---------------------------------------------------------------------
frame_end:
        call commit
        ld a,(curblk)
        ld (fb_blk),a
        call vschk
        ld a,2
        call frame_wait
        ld a,(rpage)
        ld (dpage),a
        add a,a
        add a,a
        ld b,a
        ld a,12
        out (P_CRTCA),a
        ld a,b
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        ld a,(shake_off)
        out (P_CRTCD),a
        ld a,(rpage)
        xor 1
        ld (rpage),a
        ld a,(fb_blk)
        jp map_port

; cell_of: D = col, E = row -> HL = row*40 + col (keeps BC, DE)
cell_of:
        push de
        ld l,e
        ld h,0
        add hl,hl
        ld de,rowtab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        ld a,d
        add a,l
        ld l,a
        ret nc
        inc h
        ret
rowtab:
        dw 0,40,80,120,160,200,240,280,320,360,400,440,480,520,560,600,640,680,720,760,800,840,880,920,960,1000,1040,1080

; ---------------------------------------------------------------------
; Text and static cells. These write to BOTH pages (score line, bar,
; front-end screens) and to the base picture in the RT block.
; put_both: HL = cell, DE = glyph number, C = colour
; ---------------------------------------------------------------------
put_both:
        push hl
        push de
        push bc
        ld a,(curblk)
        push af
        ld a,BLK_RT
        call map_blk
        ; base picture
        ld b,h
        push hl
        ld a,e
        or $80
        ld (hl),a               ; RT_CURLO = 0000h
        ld a,h
        add a,RT_CURHI/256
        ld h,a
        ld a,e
        rla
        ld a,d
        rla
        and $0F
        ld (pb_bank),a
        ld (hl),a
        ld a,b
        add a,RT_CURCOL/256
        ld h,a
        ld (hl),c
        pop hl
        ld a,e
        or $80
        ld e,a                  ; E = code
        ld a,h
        add a,VIDEO/256
        ld h,a
        ld a,LV_SCREEN
        out (P_LV),a
        ld (hl),e
        set 2,h
        ld (hl),e
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(pb_bank)
        ld (hl),a
        res 2,h
        ld (hl),a
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
        pop af
        call map_port
        pop bc
        pop de
        pop hl
        ret

; print: the 0-terminated string HL at column D, row E in colour (txt_col).
; Characters 32..95 are glyphs 32..95 of bank 0 (lower case prints as upper).
print:
.l:     ld a,(hl)
        or a
        ret z
        inc hl
        cp 'a'
        jr c,.u
        cp 'z'+1
        jr nc,.u
        sub 32
.u:     push hl
        push de
        ld c,a
        call cell_of
        ld e,c
        ld d,0
        ld a,(txt_col)
        ld c,a
        call put_both
        pop de
        pop hl
        inc d
        jr .l

; print centred on row E
print_c:
        push hl
        ld b,0
.n:     ld a,(hl)
        or a
        jr z,.x
        inc hl
        inc b
        jr .n
.x:     pop hl
        ld a,40
        sub b
        srl a
        ld d,a
        jr print

; fill: D = col, E = row, B = width, C = height with glyph (fc_glyph), colour (txt_col)
fill_cells:
.r:     push bc
        push de
        call cell_of
.c:     push bc
        ld de,(fc_glyph)
        ld a,(txt_col)
        ld c,a
        call put_both
        inc hl
        pop bc
        djnz .c
        pop de
        pop bc
        inc e
        dec c
        jr nz,.r
        ret

; clear the whole screen (both pages and the base) to blank in colour (txt_col)
cls:    ld hl,0
        ld (fc_glyph),hl
        ld de,0
        ld bc,40*256+25
        call fill_cells
        xor a
        ld (rlcnt),a
        ld (rlcnt+1),a
        ld (blcnt),a
        ld (blcnt+1),a
        ret

; glyphs_in: BC patterns of 8 bytes at HL (lower window) to the PCG from glyph DE
glyphs_in:
.g:     ld a,b
        or c
        jr z,.gd
        dec bc
        push bc
        ld a,e
        rla
        ld a,d
        rla                     ; bank = glyph >> 7
        and $0F
        or LV_SCREEN
        out (P_LV),a
        push de
        ld a,e
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
        pop de
        inc de
        pop bc
        jr .g
.gd:    ld a,LV_SCREEN
        out (P_LV),a
        ret
