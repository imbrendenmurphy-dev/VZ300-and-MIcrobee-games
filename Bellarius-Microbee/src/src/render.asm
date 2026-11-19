; =====================================================================
;  RENDER: the BELLARIUS screen engine (40 x 25 cells of 8 x 8).
;
;  Two pages (video 000h and 400h) flipped with the 6545 start address.
;  The real Premium Plus in the 40-column mode garbles the picture when
;  the CPU touches video RAM while a line is being drawn (BPM's photos,
;  Nov 2026), so a frame is made in two halves:
;
;  PREPARE (while the picture shows; no video RAM touched at all)
;   1. frame_begin, strips: where each terrain row's runs are this frame
;   2. the boss: its list of cells (boss.asm)
;   3. sprites: composed into pool glyphs in RAM (POOLRAM) over the base
;      picture worked out from RAM (base_at: strip runs, boss, sky)
;   4. small objects (bullets, shots, beams): ready-made glyphs in sky
;      cells, OR-ed into a pool glyph anywhere else
;   5. commit_prep: the cells to put back, the colours of the new cells
;  BLAST (in the vertical blanking only, a budget of T-states per blanking,
;  as many blankings as it takes): put back, terrain rows, boss glyphs and
;  cells, pool glyphs, new cells, queued text; then the page is shown.
; =====================================================================

; ---------------------------------------------------------------------
; frame_begin: start preparing page (rpage)
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
        ld (blank_n),a
        ld (bl_step),a
        ld (bl_i),a
        ld (early_ok),a
        ld (brw_n),a
        ld a,NSTEPS
        ld (bl_last),a
        ld a,(rpage)
        or a
        ld hl,RL0
        jr z,.p0
        ld hl,RL1
.p0:    ld (rl_cur),hl
        ret

; rs_list: B = cells (1..255) of the word list HL (video addresses of the page):
; back to the base picture: the blank glyph, bank 0, the base colour.
; (vertical blanking only; the RT block is mapped here)
rs_list:
        ld (rs_ptr),hl
        ld a,b
        ld (rs_n),a
        ld a,(curblk)
        ld (rs_blk),a
        ld a,BLK_RT
        call map_blk
        ld (rs_sp),sp
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
        ld a,LV_SCREEN
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

; ---------------------------------------------------------------------
; strips: where each terrain row's runs are this frame. strip_tab: for
; each plane k (0 codes, 1 banks, 2 colours), each strip row i, each phase
; p: db port, dw address (the run of map columns 0..). row_dst: dw (row+1)
; *40 per strip row (the cell of its column 0); row_far: 1 = half speed.
; -> strip_src: per strip row, per plane: db port, dw address of column 0
; ---------------------------------------------------------------------
strips:
        ld a,(nstrip)
        or a
        ret z
        ld ix,strip_tab
        ld hl,strip_src
        ld c,0                  ; plane
.pl:    ld iy,row_dst
        ld a,(nstrip)
        ld b,a
        push hl
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
        ld (hl),a               ; port
        inc hl
        push hl
        ld l,(ix+1)
        ld h,(ix+2)
        add hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ld bc,7                 ; the next strip row's entry for this plane
        add hl,bc
        pop ix
        ld bc,12
        add ix,bc
        ld bc,3
        add iy,bc
        pop bc
        djnz .row
        pop hl
        ld de,3                 ; the next plane's slot
        add hl,de
        inc c
        ld a,c
        cp 3
        jr nz,.pl
        ; does this page show these runs already? (the signature)
        ld a,(rpage)
        ld e,a
        add a,a
        add a,e
        add a,a                 ; *6
        ld e,a
        ld d,0
        ld hl,stsig
        add hl,de
        ld de,scr_p
        ld b,6
        ld c,0
.sg:    ld a,(de)
        cp (hl)
        jr z,.se
        ld c,1
        ld (hl),a
.se:    inc hl
        inc de
        djnz .sg
        ld a,c
        ld (st_new),a
        or a
        ret nz
        ; the runs haven't moved: the terrain rows this page last put sprites
        ; on are copied again (before any blanking could take the strips)
        ld a,(rpage)
        ld e,a
        ld d,0
        ld hl,rlcnt
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld b,a
        ld hl,(rl_cur)
.rl:    ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        bit 7,a
        jr z,.rn
        and $03
        ld d,a
        call row_of
        push hl
        ld l,a
        ld h,0
        ld de,rowstrip
        add hl,de
        ld a,(hl)
        cp $FF
        jr z,.rx
        ld l,a
        ld h,0
        ld de,sdirty
        add hl,de
        ld (hl),1
.rx:    pop hl
.rn:    djnz .rl
        ret

; strips_mark: both pages need their terrain rows again
strips_mark:
        ld hl,stsig
        ld b,12
.l:     ld (hl),$FF
        inc hl
        djnz .l
        ret

; rows_init (stage load): rowstrip[row] = strip row index, or FFh
rows_init:
        ld hl,rowstrip
        ld b,25
.c:     ld (hl),$FF
        inc hl
        djnz .c
        ld a,(nstrip)
        or a
        ret z
        ld b,a
        ld c,0
        ld iy,row_dst
.r:     ld l,(iy+0)
        ld h,(iy+1)
        ld e,0                  ; row = cell / 40
        ld a,l
.d:     ld a,h
        or a
        jr nz,.sub
        ld a,l
        cp 40
        jr c,.dn
.sub:   push de
        ld de,40
        or a
        sbc hl,de
        pop de
        inc e
        jr .d
.dn:    ld d,0
        ld hl,rowstrip
        add hl,de
        ld (hl),c
        inc c
        inc iy
        inc iy
        inc iy
        djnz .r
        ret

; ---------------------------------------------------------------------
; base_at: (lk_row), (lk_col), DE = the cell -> what the page will show
; there before sprites: B = code, C = bank, A = colour. From RAM only:
; this frame's boss, the terrain runs, or the sky. Keeps DE, HL, IX.
; ---------------------------------------------------------------------
base_at:
        push hl
        push de
        ld a,(lk_row)
        ld l,a
        ld h,0
        ld de,rowstrip
        add hl,de
        ld a,(hl)
        ld (lk_si),a
        inc a
        jr z,.ns
        ld a,$80
.ns:    ld (lk_strip),a         ; 80h: a terrain row
        pop de
        ld a,d
        add a,CELLMAP/256
        ld h,a
        ld l,e
        ld a,(hl)
        cp CM_BOSS
        jr z,.boss
        ld a,(lk_si)
        cp $FF
        jr nz,.strip
        ; the sky: blank glyph, bank 0, the row's colour
        ld a,(lk_row)
        ld l,a
        ld h,0
        push de
        ld de,rowpaper
        add hl,de
        pop de
        ld a,(hl)
        ld bc,$8000
        pop hl
        ret
.strip: push de
        ld l,a                  ; strip row i: strip_src + i*9
        add a,a
        add a,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        ld de,strip_src
        add hl,de
        ld a,(lk_col)
        ld e,a
        ld d,0
        ; plane 0: the code
        ld a,(hl)
        out (P_MEM),a
        inc hl
        push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        add hl,de
        ld b,(hl)
        pop hl
        inc hl
        inc hl
        ; plane 1: the bank
        ld a,(hl)
        out (P_MEM),a
        inc hl
        push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        add hl,de
        ld c,(hl)
        pop hl
        inc hl
        inc hl
        ; plane 2: the colour
        ld a,(hl)
        out (P_MEM),a
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        add hl,de
        ld e,(hl)
        ld a,(curblk)
        out (P_MEM),a
        ld a,e
        pop de
        pop hl
        ret
.boss:  call boss_k             ; A = k
        ld c,a
        push de
        ld e,a
        ld d,0
        call bcol_ptr
        add hl,de
        ld e,(hl)
        ld a,c
        or $80
        ld b,a
        ld a,(rpage)
        add a,BK_BOSS
        ld c,a
        ld a,e
        pop de
        pop hl
        ret

; boss_k: (lk_row), (lk_col) -> A = the boss glyph there on this page
boss_k:
        push de
        push hl
        call bossk_at
        ld a,(hl)
        dec a
        pop hl
        pop de
        ret
; bossk_at: (lk_row), (lk_col) -> HL -> this page's BOSSK entry (no check)
bossk_at:
        ld a,(rpage)
        add a,a
        add a,a                 ; 4 bytes a page
        ld e,a
        ld d,0
        ld hl,bk_org
        add hl,de
        ld a,(lk_col)
        sub (hl)
        ld e,a                  ; column in the box
        inc hl
        ld a,(lk_row)
        sub (hl)                ; row in the box
        add a,a
        add a,a
        ld d,a
        add a,a
        add a,d                 ; *12
        add a,e
        ld e,a
        ld d,0
        ld hl,bossk0
        ld a,(rpage)
        or a
        jr z,.p
        ld hl,bossk1
.p:     add hl,de
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
        ld de,SPRTAB_AT         ; (the frame table is in the common sprite block)
        add hl,de
        ld a,BLK_SPR
        call map_blk
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
.skipc: call vschk
        ld hl,(sd_col)
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
        ld (lk_row),a
        ld a,(sd_cx)
        ld (lk_col),a
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
        ld h,POOLRAM/2048
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
        ld hl,lk_row
        inc (hl)
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
; cell_alloc: HL = cell, (lk_row), (lk_col) -> A = the pool glyph for it
; this frame (C = full). A new pool glyph starts as a copy of the base.
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
        cp CM_BOSS
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
.new:   call base_at            ; B = code, C = bank, A = colour
        ld (ca_col),a
        ld (ca_bc),bc
        call pool_new           ; (HL -> the CELLMAP entry, DE = cell)
        ret c
        push af
        ld l,a
        set 7,l                 ; (the paper tables are at +80h)
        ld h,PL_PAP/256
        ld a,(ca_col)
        and $F0
        ld (hl),a
        ld hl,(ca_bc)           ; H = code, L = bank
        ld e,l
        ld a,h
        call bg_copy
        pop af
        ret

; pool_new: DE = cell, HL -> its CELLMAP entry (0). -> A = k, BC = its
; 8 bytes in POOLRAM
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
        ld a,(lk_strip)
        or d
        ld (hl),a               ; b7: a terrain row (strips put it back)
        inc h
        ld a,(spr_ink)
        ld (hl),a
        ld a,c
        ld (pn_k),a
        or $80
        ld l,a
        ld h,POOLRAM/2048
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
; (a sprite block is in the lower window: banks 0..11 come from its store)
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
.slow:  and $FE                 ; the boss banks (12, 13): its bitmap
        cp BK_BOSS
        jr nz,.blank
        push bc
        push ix
        ld a,l                  ; k: this page's boss list + k*5
        call boss_ent
        ld l,(ix+3)
        ld h,(ix+4)
        ld a,(curblk)
        push af
        ld a,(stg_hdr+H_BOSSB)
        call map_blk
        ld de,GLYPHBUF
        REPT 8
        ldi
        ENDR
        pop af
        call map_port
        pop ix
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
        ld a,d
        ld (lk_col),a
        ld a,e
        ld (lk_row),a
        call cell_of
        call gput
.no:    call vschk
        pop hl
        pop bc
        djnz .p
        ret

; gput: HL = cell, (lk_row), (lk_col), BC = ready-made glyph number. Into the cell.
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
        cp CM_BOSS
        jr z,.free
        jp p,.pool
        ; a direct cell already: it becomes a pool glyph
        and $7F
        ld (gp_d),a
        xor a
        ld (lk_strip),a         ; (direct cells are all in the sky)
        push hl
        call pool_new
        pop hl
        ret c
        push bc
        ld a,(pn_k)
        ld e,a
        ld a,(gp_d)
        ld l,a
        set 7,l
        ld h,DL_PAP/256
        ld a,(hl)
        ld h,PL_PAP/256
        ld l,e
        set 7,l
        ld (hl),a
        ld a,(gp_d)
        ld l,a
        ld h,DL_BANK/256
        ld e,(hl)
        ld (hl),$FF             ; void
        ld h,DL_CODE/256
        ld a,(hl)
        call bg_copy
        pop bc
        jp .or
.pool:  dec a
        ld l,a
        ld h,PL_INK/256
        ld c,a
        ld a,(spr_ink)
        ld (hl),a
        ld a,c
        or $80
        ld l,a
        ld h,POOLRAM/2048
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        jr .or
.free:  push hl
        call base_at            ; B = code, C = bank, A = colour
        ld (ca_col),a
        ld a,b
        ld (gp_code),a
        ld a,c
        ld (gp_bank),a
        pop hl
        ld a,(gp_code)
        cp $80
        jr nz,.comp
        ld a,(gp_bank)
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
        ld a,(ca_col)
        and $F0
        set 7,l
        ld h,DL_PAP/256
        ld (hl),a
        ret
.comp:  call pool_new           ; (HL -> the CELLMAP entry, DE = cell)
        ret c
        push bc
        ld l,a
        set 7,l
        ld h,PL_PAP/256
        ld a,(ca_col)
        and $F0
        ld (hl),a
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
; put_back: DE = cell, A = its row: next blast it goes back to the base
; picture (a terrain row is simply copied again; sky goes in BLANKS)
; ---------------------------------------------------------------------
put_back:
        push hl
        ld l,a
        ld h,0
        push de
        ld de,rowstrip
        add hl,de
        pop de
        ld a,(hl)
        cp $FF
        jr z,.sky
        ld l,a
        ld h,0
        push de
        ld de,sdirty
        add hl,de
        pop de
        ld (hl),1
        pop hl
        ret
.sky:   ld a,(blank_n)
        cp 192
        jr z,.x
        inc a
        ld (blank_n),a
        dec a
        ld l,a
        ld h,0
        add hl,hl
        push bc
        ld bc,BLANKS
        add hl,bc
        pop bc
        ld (hl),e
        inc hl
        ld a,(vpg)
        add a,d
        ld (hl),a
.x:     pop hl
        ret

; row_of: DE = cell -> A = its row (q = cell/8; row = q*205/1024, exact here)
row_of:
        push hl
        push de
        push bc
        ld h,d
        ld l,e
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l                    ; q
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; t = 5q
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl               ; 8t
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl               ; 32t
        add hl,bc
        add hl,de               ; 41t = 205q
        ld a,h
        rrca
        rrca
        and $3F
        pop bc
        pop de
        pop hl
        ret

; ---------------------------------------------------------------------
; commit_prep: the new cells' colours; the cells this page showed last
; time that nothing covers now go back to the base picture
; ---------------------------------------------------------------------
commit_prep:
        ; direct cells: paper | ink
        ld a,(dlcnt)
        or a
        jr z,.pl
        ld b,a
        ld l,0
.d:     set 7,l
        ld h,DL_PAP/256
        ld a,(hl)
        res 7,l
        ld h,DL_INK/256
        or (hl)
        ld (hl),a
        inc l
        djnz .d
.pl:    ld a,(poolcnt)
        or a
        jr z,.rl
        ld b,a
        ld l,0
.p:     set 7,l
        ld h,PL_PAP/256
        ld a,(hl)
        res 7,l
        ld h,PL_INK/256
        and $F0
        or (hl)
        ld (hl),a
        inc l
        djnz .p
        ; last time's cells
.rl:    ld a,(rpage)
        ld e,a
        ld d,0
        ld hl,rlcnt
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld b,a
        ld hl,(rl_cur)
.r:     ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld d,a
        and $7F
        ld c,a                  ; cell hi
        push hl
        bit 7,d                 ; a terrain row? (strips: copied again)
        jr nz,.n
        ld a,c
        add a,CELLMAP/256
        ld h,a
        ld l,e
        ld a,(hl)
        cp CM_BOSS
        jr z,.bc
        or a
        jr nz,.n                ; covered again this frame
        ld d,c
        call row_of
        call put_back
        jr .n
.bc:    ld d,c                  ; a boss cell: put the boss back there
        call brw_add
.n:     pop hl
        djnz .r
        ret

; post_blast: the page is on show. Its cells to put back next time (the
; restore list), and the cell map cleared for the next frame.
post_blast:
        ld hl,(rl_cur)
        ld c,0                  ; count
        ld a,(dlcnt)
        or a
        jr z,.pl
        ld b,a
        ld e,0
.d:     ld d,DL_BANK/256
        ld a,(de)
        inc a
        jr z,.dn                ; void: it became a pool cell
        ld d,DL_LO/256
        ld a,(de)
        ld (hl),a
        inc hl
        ld d,DL_HI/256
        ld a,(de)
        ld (hl),a
        inc hl
        inc c
.dn:    ld d,DL_HI/256
        ld a,(de)
        add a,CELLMAP/256
        push hl
        ld h,a
        ld d,DL_LO/256
        ld a,(de)
        ld l,a
        ld (hl),0
        pop hl
        inc e
        djnz .d
.pl:    ld a,(poolcnt)
        or a
        jr z,.bs
        ld b,a
        ld e,0
.p:     ld d,PL_LO/256
        ld a,(de)
        ld (hl),a
        inc hl
        ld d,PL_HI/256
        ld a,(de)
        ld (hl),a
        inc hl
        inc c
        and $03
        add a,CELLMAP/256
        push hl
        ld h,a
        ld d,PL_LO/256
        ld a,(de)
        ld l,a
        ld (hl),0
        pop hl
        inc e
        djnz .p
.bs:    ld a,(rpage)
        ld e,a
        ld d,0
        ld hl,rlcnt
        add hl,de
        ld (hl),c
        ; the boss's cells
        call boss_unmark
        ; the terrain rows' dirt
        ld hl,sdirty
        ld b,12
.z:     ld (hl),0
        inc hl
        djnz .z
        ret

; ---------------------------------------------------------------------
; THE BLAST: steps run in the vertical blanking. Each takes work in
; batches whose worst-case cost (T-states) it takes from (bud) first;
; C = the budget ran out (wait for the next blanking and carry on).
; ---------------------------------------------------------------------
BUDGET      EQU 21000           ; of 24 408 T in a blanking (113 lines)

bud_take:                       ; HL = cost -> C if there isn't enough
        in a,(P_CRTCA)          ; (and never once the picture has started)
        and $20
        scf
        ret z
        ex de,hl
        ld hl,(bud)
        or a
        sbc hl,de
        ret c
        ld (bud),hl
        ret

; (the first three only need this frame's scroll and boss: they can go in
; a blanking that comes while the sprites are still being prepared)
bl_tab: dw st_strips, st_bossg, st_bossc, st_blanks, st_brw, st_pool, st_direct, st_pcells, st_text
NSTEPS      EQU 9
NEARLY      EQU 3
EARLY_BUD   EQU 14000           ; (vschk is polled at least every 8000 T or so)

early_blast:
        push af
        push bc
        push de
        push hl
        push ix
        push iy
        ld hl,EARLY_BUD
        ld (bud),hl
        ld a,NEARLY
        ld (bl_last),a
        call blast_run
        jr c,.x
        xor a
        ld (early_ok),a         ; all done
.x:     ld a,NSTEPS
        ld (bl_last),a
        pop iy
        pop ix
        pop hl
        pop de
        pop bc
        pop af
        ret

early_on:
        call vschk              ; (a blanking already begun is not used:
        ld a,1                  ; how much of it is left isn't known)
        ld (early_ok),a
        ret

blast_run:
.l:     ld a,(bl_step)
        ld hl,bl_last
        cp (hl)
        ret nc
        add a,a
        ld e,a
        ld d,0
        ld hl,bl_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call .jp
        ret c
        ld hl,bl_step
        inc (hl)
        xor a
        ld (bl_i),a
        jr .l
.jp:    jp (hl)

; ---- 1: cells back to the sky, 16 at a time
st_blanks:
.l:     ld a,(blank_n)
        ld hl,bl_i
        sub (hl)
        ret z
        cp 16
        jr c,.n
        ld a,16
.n:     ld (bl_m),a
        ld hl,3200              ; (16 x 131 T and the set-up)
        call bud_take
        ret c
        ld a,(bl_i)
        ld l,a
        ld h,0
        add hl,hl
        ld de,BLANKS
        add hl,de
        ld a,(bl_m)
        ld b,a
        call rs_list
        ld a,(bl_m)
        ld hl,bl_i
        add a,(hl)
        ld (hl),a
        jr .l

; ---- 2: the terrain rows (all when the scroll moved, else the dirty ones)
st_strips:
.l:     ld a,(bl_i)
        ld hl,nstrip
        cp (hl)
        ret nc
        ld a,(st_new)
        or a
        jr nz,.go
        ld a,(bl_i)
        ld e,a
        ld d,0
        ld hl,sdirty
        add hl,de
        ld a,(hl)
        or a
        jr z,.nx
.go:    ld hl,3300              ; (3 x 870 T and the checks)
        call bud_take
        ret c
        call strip_row
.nx:    ld hl,bl_i
        inc (hl)
        jr .l

strip_row:
        ld a,(bl_i)
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld e,a
        ld d,0
        ld ix,strip_src
        add ix,de
        ld a,c
        add a,a
        add a,c
        ld e,a
        ld iy,row_dst
        add iy,de
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,(vpg)
        call .cp
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(vpg)
        call .cp
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,(cpg)
        call .cp
        xor a
        out (P_COLCTL),a
        ld a,(curblk)
        out (P_MEM),a
        ret
.cp:    ld e,(iy+0)
        add a,(iy+1)
        ld d,a
        ld a,(ix+0)
        out (P_MEM),a
        ld l,(ix+1)
        ld h,(ix+2)
        REPT 40
        ldi
        ENDR
        inc ix
        inc ix
        inc ix
        ret

; ---- 3: the boss's glyphs, when it has changed on this page (8 at a time)
st_bossg:
        call bnew_ptr
        ld a,(hl)
        or a
        ret z
.l:     call bdn_ptr
        ld a,(hl)
        ld hl,bl_i
        sub (hl)
        jr nz,.go
        call bnew_ptr
        ld (hl),0
        ret                     ; (NC)
.go:    cp 8
        jr c,.n
        ld a,8
.n:     ld (bl_m),a
        ld hl,3300              ; (8 x 250 T and 900 of set-up)
        call bud_take
        ret c
        ld a,(curblk)
        push af
        ld a,(stg_hdr+H_BOSSB)
        call map_blk
        ld a,(rpage)
        add a,BK_BOSS+LV_SCREEN
        out (P_LV),a
        ld a,(bl_i)             ; entry k: list + k*5; glyph k: F800h + k*16
        ld c,a
        call boss_ent
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PCGWIN
        add hl,de
        ex de,hl                ; DE = the glyph
        ld a,(bl_m)
        ld b,a
.g:     push bc
        ld l,(ix+3)
        ld h,(ix+4)
        REPT 8
        ldi
        ENDR
        ld hl,8
        add hl,de
        ex de,hl
        ld bc,5
        add ix,bc
        pop bc
        djnz .g
        ld a,LV_SCREEN
        out (P_LV),a
        pop af
        call map_port
        ld a,(bl_m)
        ld hl,bl_i
        add a,(hl)
        ld (hl),a
        jp .l

; ---- 4: the boss's cells: all of them when it changed, its colours when
; they changed (8 at a time)
st_bossc:
        call bdn_ptr
        ld a,(hl)
        or a
        ret z
        call bcl_ptr
        ld a,(hl)
        or a
        jr nz,.l
        call bcd_ptr
        ld a,(hl)
        or a
        ret z
.l:     call bdn_ptr
        ld a,(hl)
        ld hl,bl_i
        sub (hl)
        jr nz,.go
        call bcl_ptr            ; (NC)
        ld (hl),0
        call bcd_ptr
        ld (hl),0
        ret
.go:    cp 8
        jr c,.n
        ld a,8
.n:     ld (bl_m),a
        ld hl,3600              ; (8 x 310 T and 600 of set-up)
        call bud_take
        ret c
        ld a,(bl_i)
        ld c,a
        call boss_ent
        call bcl_ptr
        ld a,(hl)
        or a
        jr z,.col               ; the colours alone
        ld a,(bl_m)
        ld b,a
        ld a,(bl_i)
        ld c,a
        push ix
.cb:    ld a,(vpg)
        add a,(ix+1)
        ld d,a
        ld e,(ix+0)
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,c
        or $80
        ld (de),a
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(rpage)
        add a,BK_BOSS
        ld (de),a
        inc c
        ld de,5
        add ix,de
        djnz .cb
        ld a,LV_SCREEN
        out (P_LV),a
        pop ix
.col:   ld a,(bl_m)
        ld b,a
        ld a,(bl_i)
        ld e,a
        ld d,0
        call bcol_ptr
        add hl,de
        ld a,COL_ON
        out (P_COLCTL),a
.cc:    ld a,(cpg)
        add a,(ix+1)
        ld d,a
        ld e,(ix+0)
        ld a,(hl)
        ld (de),a
        inc hl
        ld de,5
        add ix,de
        djnz .cc
        xor a
        out (P_COLCTL),a
        ld a,(bl_m)
        ld hl,bl_i
        add a,(hl)
        ld (hl),a
        jp .l

; boss_ent: A = k -> IX -> entry k of this page's boss list (keeps BC, HL)
boss_ent:
        ld e,a
        ld d,0
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,de
        ex de,hl
        pop hl
        call boss_list
        add ix,de
        ret

; brw_add: DE = a boss cell a sprite covered last time -> its index in brw
brw_add:
        ld a,(brw_n)
        cp BRWN
        ret nc                  ; (too many: those stay as they are)
        push hl
        call row_of
        ld (lk_row),a
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,rowtab
        add hl,de
        pop de
        ld a,e
        sub (hl)
        ld (lk_col),a
        call boss_k
        ld e,a
        ld a,(brw_n)
        ld l,a
        inc a
        ld (brw_n),a
        ld h,0
        push de
        ld de,brw
        add hl,de
        pop de
        ld (hl),e
        pop hl
        ret
BRWN    EQU 32

; ---- 4b: boss cells put back where sprites were (after the blanks)
st_brw:
.l:     ld a,(brw_n)
        ld hl,bl_i
        sub (hl)
        ret z
        ld hl,800
        call bud_take
        ret c
        ld a,(bl_i)
        ld e,a
        ld d,0
        ld hl,brw
        add hl,de
        ld a,(hl)               ; k
        ld c,a
        call boss_ent
        ld a,(vpg)
        add a,(ix+1)
        ld d,a
        ld e,(ix+0)
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,c
        or $80
        ld (de),a
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(rpage)
        add a,BK_BOSS
        ld (de),a
        ld a,LV_SCREEN
        out (P_LV),a
        ld b,0
        call bcol_ptr
        add hl,bc
        ld a,(hl)
        ex af,af'
        ld a,COL_ON
        out (P_COLCTL),a
        set 3,d
        ex af,af'
        ld (de),a
        xor a
        out (P_COLCTL),a
        ld hl,bl_i
        inc (hl)
        jr .l

; ---- 5: the pool glyphs, POOLRAM -> the page's pool bank (8 at a time)
st_pool:
.l:     ld a,(poolcnt)
        ld hl,bl_i
        sub (hl)
        ret z
        cp 8
        jr c,.n
        ld a,8
.n:     ld b,a
        ld hl,2200              ; (8 x 191 T and the set-up)
        call bud_take
        ret c
        ld a,(poolport)
        out (P_LV),a
        ld a,(bl_i)
        ld l,a
        or $80
        ld e,a
        ld d,$0F
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; F800h + k*16
        ex de,hl
        ld h,POOLRAM/2048
        set 7,l
        add hl,hl
        add hl,hl
        add hl,hl               ; POOLRAM + k*8
        ld a,b
        ld (bl_m),a
.g:     push bc
        REPT 8
        ldi
        ENDR
        ex de,hl
        ld bc,8
        add hl,bc
        ex de,hl
        pop bc
        djnz .g
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,(bl_m)
        ld hl,bl_i
        add a,(hl)
        ld (hl),a
        jr .l

; ---- 6: the direct cells (ready-made glyphs in the sky), 16 at a time
st_direct:
.l:     ld a,(dlcnt)
        ld hl,bl_i
        sub (hl)
        ret z
        cp 16
        jr c,.n
        ld a,16
.n:     ld b,a
        ld hl,4600              ; (16 x 250 T and the set-up)
        call bud_take
        ret c
        ld a,(vpg)
        ld c,a
        ld a,(bl_i)
        ld l,a
.c:     ld h,DL_BANK/256
        ld a,(hl)
        cp $FF
        jr z,.cn                ; void
        ex af,af'               ; A' = bank
        ld h,DL_HI/256
        ld a,(hl)
        add a,c
        ld d,a
        ld h,DL_LO/256
        ld e,(hl)
        ld a,LV_SCREEN
        out (P_LV),a
        ld h,DL_CODE/256
        ld a,(hl)
        ld (de),a
        ld a,LV_ATTR
        out (P_LV),a
        ex af,af'
        ld (de),a
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        set 3,d
        ld h,DL_INK/256
        ld a,(hl)
        ld (de),a
        xor a
        out (P_COLCTL),a
.cn:    inc l
        djnz .c
        ld a,l
        ld (bl_i),a
        jr .l

; ---- 7: the pool cells, 16 at a time
st_pcells:
.l:     ld a,(poolcnt)
        ld hl,bl_i
        sub (hl)
        ret z
        cp 16
        jr c,.n
        ld a,16
.n:     ld b,a
        ld hl,4600              ; (16 x 250 T and the set-up)
        call bud_take
        ret c
        ld a,(vpg)
        ld c,a
        ld a,(rpage)
        add a,BK_POOL
        ld ixl,a
        ld a,(bl_i)
        ld l,a
.c:     ld h,PL_HI/256
        ld a,(hl)
        and $03
        add a,c
        ld d,a
        ld h,PL_LO/256
        ld e,(hl)
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,l
        or $80
        ld (de),a
        ld a,LV_ATTR
        out (P_LV),a
        ld a,ixl
        ld (de),a
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        set 3,d
        ld h,PL_INK/256
        ld a,(hl)
        ld (de),a
        xor a
        out (P_COLCTL),a
        inc l
        djnz .c
        ld a,l
        ld (bl_i),a
        jr .l

; ---- 8: queued text (both pages), 8 at a time
st_text:
.l:     ld a,(tq_n)
        ld hl,bl_i
        sub (hl)
        jr nz,.go
        xor a
        ld (tq_n),a
        ret
.go:    cp 8
        jr c,.n
        ld a,8
.n:     ld b,a
        ld hl,3400              ; (8 x 330 T and the set-up)
        call bud_take
        ret c
        ld a,(bl_i)
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,tq
        add hl,de               ; entry: cell (2), code, bank, colour
.c:     push bc
        ld e,(hl)
        inc hl
        ld a,(hl)
        add a,VIDEO/256
        ld d,a
        inc hl
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,(hl)
        ld (de),a
        set 2,d
        ld (de),a
        inc hl
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(hl)
        ld (de),a
        res 2,d
        ld (de),a
        inc hl
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        set 3,d
        ld a,(hl)
        ld (de),a
        set 2,d
        ld (de),a
        inc hl
        xor a
        out (P_COLCTL),a
        ld a,(bl_i)
        inc a
        ld (bl_i),a
        pop bc
        djnz .c
        jr .l

; tq_flush: the queued text onto the screen now (in blankings)
tq_flush:
        ld a,(tq_n)
        or a
        ret z
        ld a,(fw_fresh)
        or a
        call z,vb_wait
        xor a
        ld (fw_fresh),a
        xor a
        ld (bl_i),a
.b:     ld hl,BUDGET
        ld a,(dispoff)
        or a
        jr z,.r
        ld hl,$FFFF
.r:     ld (bud),hl
        call st_text
        jr nc,.x
        call vb_wait
        jr .b
.x:     xor a
        ld (fw_fresh),a         ; this blanking is used up
        ret

; ---------------------------------------------------------------------
; frame_end: wait out the frame (the beeper plays), blast the page in the
; blanking(s), show it. Two fields a frame at least (25 frames a second).
; ---------------------------------------------------------------------
frame_end:
        xor a
        ld (early_ok),a
        call commit_prep
        ld a,(curblk)
        ld (fb_blk),a
        call vschk
        ld a,2
        call fw_core
        ld a,(fw_fresh)
        or a
        call z,vb_wait
.b:     ld hl,BUDGET
        ld a,(dispoff)
        or a
        jr z,.r
        ld hl,$FFFF
.r:     ld (bud),hl
        call blast_run
        jr nc,.show
        call vb_wait
        jr .b
.show:  ld a,(rpage)
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
        xor a
        ld (vcount),a
        ld (fw_fresh),a
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
        call post_blast
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
; Text and static cells. These go to BOTH pages (score line, bar, front-end
; screens) and to the base picture in the RT block. With the picture on
; they wait in a queue for the vertical blanking (st_text, tq_flush).
; put_both: HL = cell, DE = glyph number, C = colour
; ---------------------------------------------------------------------
TQN     EQU 32
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
        ld a,(dispoff)
        or a
        jr nz,.now
        ; the queue
        ld a,(tq_n)
        cp TQN
        jr c,.q
        push hl
        push de
        push bc
        call tq_flush
        pop bc
        pop de
        pop hl
.q:     ld (tq_tmp),hl
        ld a,(tq_n)
        ld l,a
        inc a
        ld (tq_n),a
        ld h,0
        push de
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,tq
        add hl,de               ; entry: cell (2), code, bank, colour
        pop de
        ld a,(tq_tmp)
        ld (hl),a
        inc hl
        ld a,(tq_tmp+1)
        ld (hl),a
        inc hl
        ld (hl),e
        inc hl
        ld a,(pb_bank)
        ld (hl),a
        inc hl
        ld (hl),c
        jr .x
.now:   ld a,h
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
.x:     pop af
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
cls:    call display_off
        ld hl,0
        ld (fc_glyph),hl
        ld de,0
        ld bc,40*256+25
        call fill_cells
        xor a
        ld (rlcnt),a
        ld (rlcnt+1),a
        jp display_on

; glyphs_in: BC patterns of 8 bytes at HL (lower window) to the PCG from glyph DE
; (with the picture off: the PCG is written all at once)
glyphs_in:
        ld a,(dispoff)
        push af
        call display_off
        call .g
        pop af
        or a
        ret nz
        jp display_on
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
