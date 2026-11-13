; =====================================================================
;  RENDER: the PCG screen engine.
;
;  The screen is 64 x 16 cells; every cell shows one of the 2048 PCG
;  glyphs (code 80h+n, attribute = bank) in its own ink/paper colour.
;  The background is a picture of glyphs (cur_lo/cur_hi/cur_col).
;  Two pages (screen offsets 000h and 400h) are flipped with the 6545
;  start address; each page keeps a list of the cells that differ from
;  the background (RT block) and puts them back before it is drawn again.
;  Sprites are drawn by giving each cell they touch a private glyph from
;  the page's pool bank (14/15): the background glyph is copied in, the
;  pre-shifted sprite (mask, data) is blitted on top, and the cell takes
;  the sprite's ink.
; =====================================================================

; ---------------------------------------------------------------------
; Restore lists (RT block): page p, quarter q (cells q*256..q*256+255) is a
; byte list at RT_LIST + (p*4+q)*256 of the cells' low bytes, rl_cnt[p*4+q]
; entries; RT_FLAGp marks the cells already listed. A full quarter makes the
; page redraw everything instead (rl_all).
; ---------------------------------------------------------------------
; md_rt: HL = cell -> into both pages' lists (RT mapped). Keeps all but AF.
md_rt:  push bc
        push hl
        ld bc,RT_FLAG0
        add hl,bc
        ld a,(hl)
        or a
        jr nz,.n0
        inc (hl)
        pop hl
        push hl
        ld c,h                  ; q
        ld b,0
        call md_add
.n0:    pop hl
        push hl
        ld bc,RT_FLAG1
        add hl,bc
        ld a,(hl)
        or a
        jr nz,.n1
        inc (hl)
        pop hl
        push hl
        ld a,h
        add a,4
        ld c,a
        ld b,1
        call md_add
.n1:    pop hl
        pop bc
        ret
; C = list number (p*4+q), B = page, L = cell low byte
md_add: push hl
        push de
        ld e,l
        ld hl,rl_cnt
        ld a,l
        add a,c
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        cp 255
        jr z,.full
        inc (hl)
        ld l,a
        ld a,c
        add a,RT_LIST/256
        ld h,a
        ld (hl),e
        pop de
        pop hl
        ret
.full:  ld hl,rl_all
        ld a,l
        add a,b
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),1
        pop de
        pop hl
        ret

; set_cell: HL = cell, DE = glyph number (0..2047), C = colour. Keeps HL,DE.
set_cell:
        ld a,(curblk)
        push af
        ld a,BLK_RT
        call map_blk
        call set_cell_rt
        pop af
        jp map_port
set_cell_rt:
        push hl
        push bc
        ld b,h
        ld a,h
        add a,cur_col/256
        ld h,a
        ld (hl),c
        ld a,d
        add a,a
        ld c,a
        ld a,e
        rla
        ld a,c
        adc a,0                 ; bank = glyph >> 7
        ld c,a
        ld a,b
        add a,cur_hi/256
        ld h,a
        ld (hl),c
        ld a,b
        add a,cur_lo/256
        ld h,a
        ld a,e
        or $80
        ld (hl),a
        ld h,b
        pop bc
        call md_rt
        pop hl
        ret

; whole picture changed: both pages redraw everything
all_dirty:
        ld a,1
        ld (rl_all),a
        ld (rl_all+1),a
        ret

; restore_base: cells HL.. count BC back to the loaded picture (RT base maps)
restore_base:
        ld a,(curblk)
        push af
        ld a,BLK_RT
        call map_blk
.l:     push bc
        push hl
        ld bc,RT_BASELO
        add hl,bc
        ld a,(hl)
        ld b,h
        pop hl
        push hl
        ld c,a
        ld a,h
        add a,cur_lo/256
        ld h,a
        ld (hl),c
        ld a,b
        add a,(RT_BASEHI-RT_BASELO)/256
        ld b,a
        ld h,a
        ld a,(hl)               ; L unchanged: base bank
        ld c,a
        pop hl
        push hl
        ld a,h
        add a,cur_hi/256
        ld h,a
        ld (hl),c
        ld a,b
        add a,(RT_BASECOL-RT_BASEHI)/256
        ld h,a
        ld a,(hl)
        ld c,a
        pop hl
        push hl
        ld a,h
        add a,cur_col/256
        ld h,a
        ld (hl),c
        pop hl
        call md_rt
        inc hl
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,.l
        pop af
        jp map_port

; restore a rectangle: D = col, E = row, B = width, C = height
restore_rect:
.r:     push bc
        push de
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,d
        add a,l
        ld l,a
        ld c,b
        ld b,0
        call restore_base
        pop de
        pop bc
        inc e
        dec c
        jr nz,.r
        ret

; ---------------------------------------------------------------------
; frame_begin: start drawing the hidden page (the pool is empty)
frame_begin:
        call vschk
        xor a
        ld (poolcnt),a
        ld a,(rpage)
        add a,BK_POOL+LV_SCREEN
        ld (poolport),a
        ret

; frame_end: put the page's listed cells back to the background (except
; those a sprite covers now), give the sprite cells their pool glyphs and
; colours, list them; wait for the frame time (the beeper plays); show it.
frame_end:
        call vschk
        ld a,(curblk)
        ld (fb_blk),a
        ld a,BLK_RT
        call map_blk
        ld a,(rpage)
        add a,a
        add a,a
        ld (rs_pg),a
        ld a,(rpage)
        ld e,a
        ld d,0
        ld hl,rl_all
        add hl,de
        ld a,(hl)
        or a
        jr z,.lists
        ld (hl),0
        call fe_all
        jp .new
.lists: xor a
        ld (rs_q),a
.q:     ld a,(rs_pg)
        ld hl,rs_q
        add a,(hl)
        ld (rs_l),a
        ld e,a
        ld d,0
        ld hl,rl_cnt
        add hl,de
        ld a,(hl)
        or a
        jp z,.nq
        ld b,a
        ld a,(rs_q)
        ld c,a
        add a,cellmap/256
        ld (.pcm+1),a
        ld a,c
        add a,cur_lo/256
        ld (.pcl+1),a
        ld a,(rs_pg)
        add a,c
        add a,VIDEO/256
        ld (.pvp+1),a
        ld (rs_vp),a
        ld a,(rpage)
        or a
        ld a,RT_FLAG0/256
        jr z,.f0
        ld a,RT_FLAG1/256
.f0:    add a,c
        ld (.pfl+1),a
        ld a,(rs_l)
        add a,RT_LIST/256
        ld d,a
        ld e,0
        exx
        ld hl,rs_tmp
        exx
        ld c,0                  ; kept entries
        ld a,LV_SCREEN
        out (P_LV),a
.p1:    ld a,(de)
        inc e
        ld l,a
.pcm:   ld h,0
        ld a,(hl)
        inc a
        cp 2
        jr nc,.keep             ; a sprite cell (FFh = blocked: restore it)
.pcl:   ld h,0
        ld a,(hl)
.pvp:   ld h,0
        ld (hl),a
.pfl:   ld h,0
        ld (hl),0
        ld a,l
        exx
        ld (hl),a
        inc l
        exx
        djnz .p1
        jr .p1d
.keep:  ld a,l
        ld l,c
        ld h,d
        ld (hl),a
        inc c
        djnz .p1
.p1d:   ld a,(rs_l)
        ld e,a
        ld d,0
        ld hl,rl_cnt
        add hl,de
        ld (hl),c
        exx
        ld a,l
        exx
        or a
        jr z,.nq
        ld (rs_n),a
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(rs_q)
        add a,cur_hi/256
        ld b,a
        ld a,(rs_vp)
        ld c,a
        call .pass
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,(rs_q)
        add a,cur_col/256
        ld b,a
        ld a,(rs_vp)
        add a,8
        ld c,a
        call .pass
        xor a
        out (P_COLCTL),a
        call vschk
.nq:    ld hl,rs_q
        inc (hl)
        ld a,(hl)
        cp 4
        jp nz,.q
        jp .new
; restored-cell pass: B = source table page, C = destination page
.pass:  ld a,(rs_n)
        ld ixl,a
        ld de,rs_tmp
.pl:    ld a,(de)
        inc e
        ld l,a
        ld h,b
        ld a,(hl)
        ld h,c
        ld (hl),a
        dec ixl
        jr nz,.pl
        ret
        ; ---- the new sprite cells
.new:   ld a,(poolcnt)
        or a
        jp z,.show
        ld a,(rs_pg)
        add a,VIDEO/256
        ld c,a
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,(poolcnt)
        ld b,a
        ld l,0
.c:     ld h,nc_lo/256
        ld e,(hl)
        inc h
        ld a,(hl)
        add a,c
        ld d,a
        ld a,l
        or $80
        ld (de),a
        ld a,d
        sub c
        add a,cellmap/256
        ld d,a
        xor a
        ld (de),a
        inc l
        djnz .c
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(rpage)
        add a,BK_POOL
        ld ixl,a
        ld a,(poolcnt)
        ld b,a
        ld l,0
.a:     ld h,nc_lo/256
        ld e,(hl)
        inc h
        ld a,(hl)
        add a,c
        ld d,a
        ld a,ixl
        ld (de),a
        inc l
        djnz .a
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,c
        add a,8
        ld c,a
        ld a,(poolcnt)
        ld b,a
        ld l,0
.k:     ld h,nc_lo/256
        ld e,(hl)
        inc h
        ld a,(hl)
        add a,cur_col/256
        ld d,a
        ld a,(de)
        and $F0
        inc h
        or (hl)
        ex af,af'
        ld a,d
        sub cur_col/256
        add a,c
        ld d,a
        ex af,af'
        ld (de),a
        inc l
        djnz .k
        xor a
        out (P_COLCTL),a
        call vschk
        ld a,(poolcnt)
        ld b,a
        ld l,0
.r:     ld h,nc_lo/256
        ld e,(hl)
        inc h
        ld d,(hl)
        push hl
        push bc
        ld a,(rpage)
        or a
        ld a,RT_FLAG0/256
        jr z,.r0
        ld a,RT_FLAG1/256
.r0:    add a,d
        ld h,a
        ld l,e
        ld a,(hl)
        or a
        jr nz,.r1
        inc (hl)
        ld a,(rs_pg)
        add a,d
        ld c,a
        ld a,(rpage)
        ld b,a
        call md_add
.r1:    pop bc
        pop hl
        inc l
        djnz .r
.show:  ld a,(fb_blk)
        call map_port
        ; two fields a frame; three when a sound is playing and the frame
        ; was busy (so the beeper gets its time), the game logic keeps step
        call vschk
        ld a,(vcount)
        or a
        ld a,2
        jr z,.two
        ld hl,sfxleft
        ld a,(mplaying)
        or (hl)
        ld hl,noiseon
        or (hl)
        ld a,2
        jr z,.two
        inc a
.two:   ld (steps),a
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
        xor a
        out (P_CRTCD),a
        ld a,(rpage)
        xor 1
        ld (rpage),a
        ret

; everything on the drawn page: copy the three maps, clear flags and lists
fe_all: ld a,LV_SCREEN
        out (P_LV),a
        ld a,(rs_pg)
        add a,VIDEO/256
        ld d,a
        ld e,0
        ld hl,cur_lo
        ld bc,1024
        ldir
        call vschk
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(rs_pg)
        add a,VIDEO/256
        ld d,a
        ld e,0
        ld hl,cur_hi
        ld bc,1024
        ldir
        call vschk
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,(rs_pg)
        add a,COLWIN/256
        ld d,a
        ld e,0
        ld hl,cur_col
        ld bc,1024
        ldir
        xor a
        out (P_COLCTL),a
        call vschk
        ld a,(rpage)
        or a
        ld hl,RT_FLAG0
        jr z,.a0
        ld hl,RT_FLAG1
.a0:    ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,1023
        ldir
        ld hl,rl_cnt
        ld a,(rs_pg)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; spr_draw: A = sprite frame id, (spr_x) = anchor x (signed 16),
; (spr_y) = anchor y (signed 16), (spr_ink) = colour. Clipped to the screen.
; Frame: db w, h, ax, ay; dw offsets of shifts 0..3; per shift, per byte
; column: db first row, db rows, rows x (and mask, data).
; ---------------------------------------------------------------------
spr_draw:
        push ix
        call .go
        pop ix
        ret
.go:    ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,spr_tab
        add hl,de
        ld a,(curblk)
        ld (sd_blk),a
        ld a,(hl)               ; block
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; header
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
        ; top = y - ay
        push hl
        ld hl,(spr_y)
        ld e,b
        ld d,0
        or a
        sbc hl,de
        ld (sd_top),hl
        ; left = x - ax: shift and first column
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
        ld a,c
        or a
        jr z,.skipc
        ld (cb_n),a
        ld a,(sd_col+1)
        or a
        jr nz,.skipc            ; < 0 or > 255
        ld a,(sd_col)
        cp 64
        jr nc,.skipc
        ld (sd_cx),a
        ; y = top + first row
        ld hl,(cb_s)
        dec hl
        dec hl
        ld e,(hl)
        ld d,0
        ld hl,(sd_top)
        add hl,de
        ld (cb_y),hl
        call col_blit
        call vschk
.skipc: ld hl,(sd_col)
        inc hl
        ld (sd_col),hl
        ld hl,sd_cn
        dec (hl)
        jr nz,.col
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,(sd_blk)
        jp map_port

; col_blit: column (sd_cx) from row (cb_y), (cb_n) rows, source (cb_s)
col_blit:
        ld hl,(cb_y)
        ld a,(cb_n)
        ld c,a
        bit 7,h
        jr z,.pos
        ld a,l                  ; clip the top
        neg
        cp c
        ret nc
        ld b,a
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
        add a,c
        jr nc,.ok
        ld a,l                  ; clip the bottom
        neg
        ld c,a
.ok:    ld a,c
        ld (cb_left),a
        ld a,l
        and 15
        ld (cb_r),a
        ld a,l
        and $F0
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld a,(sd_cx)
        or l
        ld l,a
        ld (cb_cell),hl
.seg:   ld a,(cb_r)
        ld e,a
        ld a,16
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
        ld de,64
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

; seg_blit: HL = destination glyph row, A = rows (1..16), source (cb_s)
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
sb_tab: dw sb_0,sb_1,sb_2,sb_3,sb_4,sb_5,sb_6,sb_7,sb_8,sb_9,sb_10,sb_11,sb_12,sb_13,sb_14,sb_15,sb_16
        ; sb_tab[n] = entry for n rows (index 0 is unused)
SBROW   MACRO
        pop bc
        ld a,(hl)
        and c
        or b
        ld (hl),a
        inc l
        ENDM
sb_16:  SBROW
sb_15:  SBROW
sb_14:  SBROW
sb_13:  SBROW
sb_12:  SBROW
sb_11:  SBROW
sb_10:  SBROW
sb_9:   SBROW
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

; cell_alloc: HL = cell -> A = pool glyph for it this frame (C = pool full)
; The background glyph is copied in: glyph 0 is blank (zeros); glyphs below
; STORE_N come from the copy at 0000h of every sprite block; others are read
; back from the PCG (slow, rare).
cell_alloc:
        ld d,h
        ld e,l
        ld a,h
        add a,cellmap/256
        ld h,a
        ld a,(hl)
        or a
        jr z,.new
        inc a
        jp z,.blocked           ; FFh: no sprites here (a banner)
        dec a
        dec a
        ld l,a                  ; this sprite's ink for the cell
        ld h,nc_ink/256
        ld c,a
        ld a,(spr_ink)
        ld (hl),a
        ld a,c
        or a
        ret
.new:   ld a,(poolcnt)
        cp POOLN
        jp nc,.full
        inc a
        ld (hl),a
        ld (poolcnt),a
        dec a
        ld (ca_idx),a
        ; record: lo, q, ink
        ld l,a
        ld h,nc_lo/256
        ld (hl),e
        inc h
        ld (hl),d
        inc h
        ld a,(spr_ink)
        ld (hl),a
        ; destination: F800 + idx*16
        ld a,(ca_idx)
        or $80
        ld l,a
        ld h,$0F                ; (F80h + idx) * 16 = F800h + idx*16
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ; source glyph number = bank*128 + (code & 7Fh)
        ld a,d
        add a,cur_hi/256
        ld h,a
        ld l,e
        ld a,(hl)               ; bank
        ld h,a
        ld a,d
        add a,cur_lo/256
        ld d,a                  ; DE -> cur_lo[cell]
        ld a,(de)
        and $7F
        ld l,a
        srl h
        jr nc,$+4
        or $80
        ld l,a                  ; HL = glyph number
        or h
        jr z,.blank
        ld a,h
        cp STORE_N/256
        jr nc,.slow
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; store at 0000h
        ld d,b
        ld e,c
        REPT 16
        ldi
        ENDR
        ld a,(ca_idx)
        or a
        ret
.blank: ld h,b
        ld l,c
        xor a
        REPT 16
        ld (hl),a
        inc l
        ENDR
        ld a,(ca_idx)
        or a
        ret
.slow:  push bc
        ld a,h
        add a,a
        bit 7,l
        jr z,$+3
        inc a
        or LV_SCREEN
        out (P_LV),a            ; the glyph's bank
        ld a,l
        or $80
        ld l,a
        ld h,$0F
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,glyphbuf
        REPT 16
        ldi
        ENDR
        ld a,(poolport)
        out (P_LV),a
        pop de
        ld hl,glyphbuf
        REPT 16
        ldi
        ENDR
        ld a,(ca_idx)
        or a
        ret
.full:
.blocked:
        scf
        ret

; block_rows: cells of rows E.. (C rows) take no sprites (A = FFh) or do again (A = 0)
block_rows:
        ld b,a
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,cellmap
        add hl,de
.r:     push bc
        ld c,64
.c:     ld (hl),b
        inc hl
        dec c
        jr nz,.c
        pop bc
        dec c
        jr nz,.r
        ret

; ---------------------------------------------------------------------
; text: print the 0-terminated string HL at column D, row E in font
; (txt_font = first glyph number) and colour (txt_col). -> D after the text
; ---------------------------------------------------------------------
print:
        ; the string may be in the lower window (the front end): copy it up first
        push de
        ld de,ptbuf
        ld b,63
.cp:    ld a,(hl)
        ld (de),a
        or a
        jr z,.cd
        inc hl
        inc de
        djnz .cp
        xor a
        ld (de),a
.cd:    pop de
        ld hl,ptbuf
        ld a,(curblk)
        push af
        ld a,BLK_RT
        call map_blk
.l:     ld a,(hl)
        or a
        jr z,.x
        inc hl
        push hl
        push de
        sub 32
        ld l,a
        ld h,0
        ld bc,(txt_font)
        add hl,bc
        ex de,hl                ; DE = glyph, H = col, L = row
        ld a,l
        ld l,h
        ld h,0
        rrca
        rrca
        ld c,a
        and $3F
        ld b,a
        ld a,c
        and $C0
        or l
        ld l,a
        ld h,b                  ; HL = row*64 + col
        ld a,(txt_col)
        ld c,a
        call set_cell_rt
        pop de
        pop hl
        inc d
        jr .l
.x:     pop af
        jp map_port

; length of string HL -> A
strlen: push hl
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.x
        inc hl
        inc b
        jr .l
.x:     ld a,b
        pop hl
        ret

; print centred on row E
print_c:
        call strlen
        ld b,a
        ld a,64
        sub b
        srl a
        ld d,a
        jp print

; fill_cells: D = col, E = row, B = width, C = height with glyph (fc_glyph), colour (txt_col)
fill_cells:
        ld a,(curblk)
        push af
        ld a,BLK_RT
        call map_blk
.r:     push bc
        push de
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        add a,d
        ld l,a
.c:     push bc
        ld de,(fc_glyph)
        ld a,(txt_col)
        ld c,a
        call set_cell_rt
        inc hl
        pop bc
        djnz .c
        pop de
        pop bc
        inc e
        dec c
        jr nz,.r
        pop af
        jp map_port

; ---------------------------------------------------------------------
; load_picture: unpacked picture at HL in the lower window (block A):
;   dw n glyphs, n*16 patterns, 1024 lo codes, 1024 banks, 1024 colours.
; Glyphs go to PCG from glyph number (lp_first); the maps become the
; background and the RT base maps. The whole screen is redrawn.
load_picture:
        push af
        push hl
        xor a
        ld (brd_on),a           ; no sponsor board (court_load turns it on)
        ld e,0
        ld c,16
        call block_rows         ; (no rows blocked)
        pop hl
        pop af
        call map_blk
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (lp_n),de
        ; glyphs: bank by bank
        ld de,(lp_first)
.g:     ld bc,(lp_n)
        ld a,b
        or c
        jr z,.gd
        dec bc
        ld (lp_n),bc
        ld a,e
        rla
        ld a,d
        rla                     ; bank = glyph >> 7
        or LV_SCREEN
        out (P_LV),a
        push de
        ld a,e
        and $7F
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,PCGWIN
        add hl,bc
        ex de,hl
        ld bc,16
        ldir
        pop de
        inc de
        jr .g
.gd:    ld a,LV_SCREEN
        out (P_LV),a
        ; maps: lo codes, banks, colours
        ld de,cur_lo
        ld bc,2048+1024
        ldir
        ld (lp_end),hl
        ; banks offset by the first glyph's bank
        ld a,(lp_first)
        rla
        ld a,(lp_first+1)
        rla
        or a
        jr z,.nb
        ld c,a
        ld hl,cur_hi
        ld de,1024
.ob:    ld a,(hl)
        add a,c
        ld (hl),a
        inc hl
        dec de
        ld a,d
        or e
        jr nz,.ob
.nb:    ; copy into the RT base maps
        ld a,(curblk)
        push af
        ld a,BLK_RT
        call map_blk
        ld hl,cur_lo
        ld de,RT_BASELO
        ld bc,3072
        ldir
        pop af
        call map_port
        call all_dirty
        ld hl,(lp_end)
        ret
