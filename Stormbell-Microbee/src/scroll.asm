; =====================================================================
;  SCROLL: the stage's three layers (as Tiger Gate layers its scenery).
;
;    rows 1..7    far layer, a cell at a time, at a quarter of the run
;    rows 8..15   midground, a cell at a time, with the run
;    rows 16..23  floor: eight strips. Their cells never move; the game
;                 rewrites the strips' glyphs at each page flip, so the
;                 floor slides a pixel at a time, near rows faster.
;
;  Each page remembers which camera its scenery shows (pg_mid, pg_far);
;  render brings the hidden page up to date before it is shown.
; =====================================================================

; HL = word at offset A of the mapped stage block
sb_word:
        ld l,a
        ld h,0
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; ---------------------------------------------------------------------
;  A = stage (0..4): its glyphs into the PCG, both pages drawn with the
;  camera at 0, the band's BASE built. The display is off meanwhile.
; ---------------------------------------------------------------------
stage_show:
        ld b,a
        ld a,(mono)
        or a
        ld a,BLK_STG
        jr z,.c
        ld a,BLK_STGM
.c:     add a,b
        ld (stg_blk),a
        call display_off
        ld a,(stg_blk)
        call map_blk
        ld a,(SB_DUELC)
        ld (duel_c),a
        ld a,(SB_ENDC)
        ld (end_c),a
        ld a,SB_GLYPHS
        call sb_word
        ld bc,(SB_NGLYPH)
        ld a,BK_SCN
        call pcg_load
        xor a
        ld (mid_pend),a
        ld (far_pend),a
        ld (cam_c),a
        ld (cam_sub),a
        ld (far_c),a
        ld (fl_ph),a
        ld (fl_ask),a
        ld (fl_shown),a
        ; both pages: blank, the layers, the floor
        ld a,1
        call .page
        xor a
        call .page
        call base_mid
        call base_floor
        ld hl,BASE
        ld de,HAVE0
        ld bc,$600
        ldir
        ld hl,BASE
        ld de,HAVE1
        ld bc,$600
        ldir
        xor a
        ld (pg_mid),a
        ld (pg_mid+1),a
        ld (pg_far),a
        ld (pg_far+1),a
        call show_page
        ld a,1
        ld (hidpage),a
        xor a
        ld (flip_ask),a
        ret
.page:  ld (hidpage),a
        call set_drawpage
        ld a,BLACK<<4|WHITE
        call cls
        call far_rows
        call mid_rows_all
        ; the floor's cells, rows 16..23
        ld a,(stg_blk)
        call map_blk
        ld a,SB_FCELL
        call sb_word
        ld (pr_src),hl
        ld hl,320
        ld (pr_plane),hl
        ld b,FLOOR_ROWS
        ld c,FLOOR_ROW
.fl:    push bc
        ld a,c
        call put_row
        ld hl,(pr_src)
        ld de,COLS
        add hl,de
        ld (pr_src),hl
        pop bc
        inc c
        djnz .fl
        xor a
        jp set_drawpage

; ---------------------------------------------------------------------
;  put_row: A = screen row; (pr_src) = the code plane's first byte for
;  this row, (pr_plane) = the distance between planes. 40 cells of code,
;  bank and colour go to the hidden page. The stage block is mapped.
; ---------------------------------------------------------------------
put_row:
        ld d,a
        ld e,0
        call cell_off
        ld a,(hidpage)
        add a,a
        add a,a
        add a,h
        ld h,a
        ld de,VIDEO
        add hl,de               ; HL = the row in the hidden page
        ex de,hl
        call win_screen
        ld hl,(pr_src)
        push de
        ld bc,COLS
        ldir
        call win_attr
        pop de
        push de
        ld hl,(pr_src)
        ld bc,(pr_plane)
        add hl,bc
        ld bc,COLS
        ldir
        call win_col
        pop de
        set 3,d
        ld hl,(pr_src)
        ld bc,(pr_plane)
        add hl,bc
        add hl,bc
        ld bc,COLS
        ldir
        jp win_screen

; the far rows (1..7) at far_c, to the hidden page
far_rows:
        ld a,(stg_blk)
        call map_blk
        ld a,(SB_FARW)
        ld l,a
        ld h,0
        ld (pr_w),hl
        ld e,a                  ; plane = 7 x FARW
        ld d,0
        ld hl,0
        ld b,FAR_ROWS
.m:     add hl,de
        djnz .m
        ld (pr_plane),hl
        ld a,SB_FAR
        call sb_word
        ld a,(far_c)
        ld e,a
        ld d,0
        add hl,de
        ld (pr_src),hl
        ld a,FAR_ROW
        ld b,FAR_ROWS
        jr rows_out

; midground rows A..A+B-1 (A >= 8), at cam_c, to the hidden page
mid_rows_all:
        ld a,MID_ROW
        ld b,MID_ROWS
mid_rows:
        push af
        push bc
        ld a,(stg_blk)
        call map_blk
        ld a,(SB_MIDW)
        ld l,a
        ld h,0
        ld (pr_w),hl
        add hl,hl
        add hl,hl
        add hl,hl               ; plane = 8 x MIDW
        ld (pr_plane),hl
        ld a,SB_MID
        call sb_word
        ld a,(cam_c)
        ld e,a
        ld d,0
        add hl,de
        pop bc
        pop af
        push af
        push bc
        sub MID_ROW
        jr z,.r0
        ld de,(pr_w)
.sk:    add hl,de
        dec a
        jr nz,.sk
.r0:    ld (pr_src),hl
        pop bc
        pop af
; B rows from screen row A, source rows (pr_w) apart
rows_out:
.r:     push af
        push bc
        call put_row
        ld hl,(pr_src)
        ld de,(pr_w)
        add hl,de
        ld (pr_src),hl
        pop bc
        pop af
        inc a
        djnz .r
        ret

; ---------------------------------------------------------------------
;  BASE: the empty band (rows 10..20) the fighters are drawn over
; ---------------------------------------------------------------------
; rows 10..15 from the midground at cam_c
base_mid:
        ld a,(cam_c)
        ld (base_c),a
        ld a,(stg_blk)
        call map_blk
        ld a,(SB_MIDW)
        ld l,a
        ld h,0
        ld (pr_w),hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (pr_plane),hl
        ld a,SB_MID
        call sb_word
        ld a,(cam_c)
        ld e,a
        ld d,0
        add hl,de
        ld de,(pr_w)
        add hl,de
        add hl,de               ; midground row 2 = screen row 10
        ld de,BASE
        ld b,6
.r:     push bc
        push hl
        push de
        call .plane3
        pop de
        pop hl
        ld bc,(pr_w)
        add hl,bc
        ex de,hl
        ld bc,COLS
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
        ret
; 40 bytes of each plane from HL to DE (BASE planes are 200h apart)
.plane3:
        push hl
        push de
        ld bc,COLS
        ldir
        pop de
        pop hl
        ld bc,(pr_plane)
        add hl,bc
        inc d
        inc d
        push hl
        push de
        ld bc,COLS
        ldir
        pop de
        pop hl
        ld bc,(pr_plane)
        add hl,bc
        inc d
        inc d
        ld bc,COLS
        ldir
        ret

; rows 16..20 from the floor's cells
base_floor:
        ld a,(stg_blk)
        call map_blk
        ld hl,320
        ld (pr_plane),hl
        ld a,SB_FCELL
        call sb_word
        ld de,BASE+6*COLS
        ld b,5
.r:     push bc
        push hl
        push de
        call base_mid.plane3
        pop de
        pop hl
        ld bc,COLS
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
        ret

; ---------------------------------------------------------------------
;  the camera
; ---------------------------------------------------------------------
; move the camera RUN_PX pixels on (not past A = its limit) -> NZ if
; it moved a whole cell this tick
cam_step:
        ld b,a
        ld a,(cam_c)
        cp b
        jr c,.go
        xor a
        ret                     ; at the limit (Z)
.go:    ld a,(fl_ph)
        add a,RUN_PX
        cp FLOOR_T
        jr c,.p
        sub FLOOR_T
.p:     ld (fl_ph),a
        ld a,(cam_sub)
        add a,RUN_PX
        cp 8
        jr nc,.cell
        ld (cam_sub),a
        xor a
        ret
.cell:  sub 8
        ld (cam_sub),a
        ld hl,cam_c
        inc (hl)
        ld a,(hl)
        rrca
        rrca
        and $3F
        ld (far_c),a
        ; the opponent on the road moves with the scenery
        ld a,(foe_in)
        or a
        jr z,.nf
        ld a,(foe+F_X)
        cp -20
        jr z,.nf
        dec a
        ld (foe+F_X),a
.nf:    call base_mid
        or 1
        ret

; ---------------------------------------------------------------------
;  Video RAM touched while a line is being drawn holds the CPU until
;  that line's end (the Premium Plus's 6545), so a page's scenery is
;  composed in ordinary RAM (MIDBUF, FARBUF) and copied whole in a
;  vertical blanking, where video RAM runs at full speed: the midground
;  in one blanking, the far layer with the page flip in the next.
; ---------------------------------------------------------------------
; render's part, after the band: rows 8..9 and the far layer, if the
; hidden page needs them, and the floor phase it wants
scenery_page:
        ld a,(hidpage)
        ld (blit_pg),a
        ld e,a
        ld d,0
        ld hl,pg_mid
        add hl,de
        ld a,(cam_c)
        cp (hl)
        jr z,.mid_ok
        ld (hl),a
        push de
        call mid_buf
        pop de
.mid_ok:
        ld hl,pg_far
        add hl,de
        ld a,(far_c)
        cp (hl)
        jr z,.far_ok
        ld (hl),a
        call far_buf
.far_ok:
        ld a,(fl_ph)
        ld (fl_ask),a
        ret

; band rows 0..5 of WANT -> the hidden page's HAVE and MIDBUF rows 10..15
mid_capture:
        ld a,(hidpage)
        or a
        ld de,HAVE0
        jr z,.h
        ld de,HAVE1
.h:     ld hl,WANT
        push de
        ld a,6*COLS/8
        call copy8
        pop de
        inc d
        inc d
        push de
        ld hl,WANT+$200
        ld a,6*COLS/8
        call copy8
        pop de
        inc d
        inc d
        ld hl,WANT+$400
        ld a,6*COLS/8
        call copy8
        ld a,1
        ld (mid_pend),a
        ret

; midground rows 8..9 at cam_c -> MIDBUF (3 planes of 80 bytes)
mid_buf:
        ld a,(stg_blk)
        call map_blk
        ld a,(SB_MIDW)
        ld l,a
        ld h,0
        ld (pr_w),hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (pr_plane),hl
        ld a,SB_MID
        call sb_word
        ld a,(cam_c)
        ld e,a
        ld d,0
        add hl,de
        ld (pr_src),hl
        ld hl,2*COLS
        ld (bp_str),hl
        ld de,MIDBUF
        ld b,2
        jr map_to_buf

; the far rows 1..7 at far_c -> FARBUF
far_buf:
        ld a,(stg_blk)
        call map_blk
        ld a,(SB_FARW)
        ld l,a
        ld h,0
        ld (pr_w),hl
        ld e,a
        ld d,0
        ld hl,0
        ld b,FAR_ROWS
.m:     add hl,de
        djnz .m
        ld (pr_plane),hl
        ld a,SB_FAR
        call sb_word
        ld a,(far_c)
        ld e,a
        ld d,0
        add hl,de
        ld (pr_src),hl
        ld hl,280
        ld (bp_str),hl
        ld de,FARBUF
        ld b,FAR_ROWS
        ld a,1
        ld (far_pend),a
; B rows of a map (pr_src, pr_w apart, planes pr_plane apart) into the
; buffer at DE (rows 40 apart, planes bp_str apart)
map_to_buf:
.r:     push bc
        push de
        ld hl,(pr_src)
        call .pl
        call .pl
        ld bc,COLS
        ldir
        ld hl,(pr_src)
        ld bc,(pr_w)
        add hl,bc
        ld (pr_src),hl
        pop de
        ld hl,COLS
        add hl,de
        ex de,hl
        pop bc
        djnz .r
        ret
.pl:    push hl
        push de
        ld bc,COLS
        ldir
        pop de
        pop hl
        ld bc,(pr_plane)
        add hl,bc
        ex de,hl
        ld bc,(bp_str)
        add hl,bc
        ex de,hl
        ret

; in a blanking: rows 8..9 from MIDBUF and rows 10..15 straight from
; WANT (left as render composed them: nothing touches WANT until the
; next render, which waits for this page's flip) -> page (blit_pg)
blit_mid:
        push bc
        push de
        push hl
        ld hl,2*COLS
        ld (b3_str),hl
        ld hl,MID_ROW*COLS
        ld de,MIDBUF
        ld a,2*COLS/8
        call blit3
        ld hl,$200
        ld (b3_str),hl
        ld hl,BAND_ROW*COLS
        ld de,WANT
        ld a,6*COLS/8
        call blit3
        pop hl
        pop de
        pop bc
        ret
; in a blanking: FARBUF -> rows 1..7 of page (blit_pg)
blit_far:
        push bc
        push de
        push hl
        ld hl,280
        ld (b3_str),hl
        ld hl,FAR_ROW*COLS
        ld de,FARBUF
        ld a,280/8
        call blit3
        pop hl
        pop de
        pop bc
        ret
; HL = offset in the page, DE = source, A = bytes / 8 a plane;
; the source's three planes are (b3_str) apart
blit3:  ld (b3_n),a
        ld (b3_s),de
        ld a,(blit_pg)
        add a,a
        add a,a
        add a,h
        ld h,a
        ld bc,VIDEO
        add hl,bc
        ld (b3_v),hl
        ex de,hl                ; HL = source, DE = video
        call win_screen
        ld a,(b3_n)
        call copy8
        call win_attr
        ld hl,(b3_s)
        ld bc,(b3_str)
        add hl,bc
        ld (b3_s),hl
        ld de,(b3_v)
        ld a,(b3_n)
        call copy8
        call win_col
        ld hl,(b3_s)
        ld bc,(b3_str)
        add hl,bc
        ld de,(b3_v)
        set 3,d
        ld a,(b3_n)
        call copy8
        jp win_screen
; A x 8 bytes from HL to DE
copy8:  ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        dec a
        jr nz,copy8
        ret

; is the hidden page's midground stale? -> NZ if so
mid_stale:
        ld a,(hidpage)
        ld e,a
        ld d,0
        ld hl,pg_mid
        add hl,de
        ld a,(cam_c)
        cp (hl)
        ret

; both pages' far rows to be redrawn (rubs out messages)
far_dirty:
        ld a,$FF
        ld (pg_far),a
        ld (pg_far+1),a
        ret

; ---------------------------------------------------------------------
;  the floor's glyphs to phase A. Called at a page flip, in the vertical
;  blanking. Keeps every register; leaves the mapped block as it was.
; ---------------------------------------------------------------------
x10:    add hl,hl               ; HL x 10 (10 bytes a glyph); uses BC
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        ret
floor_set:
        push bc
        push de
        push hl
        ld (fl_shown),a
        ld c,a
        ld a,(cur_blk)
        push af
        ld a,(stg_blk)
        call map_blk
        ; fs_php = the phase row: 8 offsets, one per strip
        ld a,SB_PHASE
        call sb_word
        ex de,hl
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld (fs_php),hl
        ld a,SB_FDESC
        call sb_word
        ld (fs_rowp),hl
        ld a,FLOOR_ROWS
        ld (fs_r),a
        xor a
        out (P_COLCTL),a
.row:   ld hl,(fs_rowp)
        ld a,(hl)
        ld (fs_k),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (fs_g),de            ; the strip's first glyph
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = the strip's table
        inc hl
        ld (fs_rowp),hl
        ld hl,(fs_php)
        ld a,(hl)               ; the strip's pixel offset at this phase
        inc hl
        ld (fs_php),hl
        ld c,a
        rrca
        rrca
        rrca
        and $1F
        ld (fs_q),a             ; whole bytes
        ld a,c
        and 7
        ld b,a                  ; the bit shift
        jr z,.s0
        ld a,(fs_k)
        ld c,a
        xor a
.sm:    add a,c
        djnz .sm                ; A = shift x k
.s0:    ld l,a
        ld h,0
        call x10
        add hl,de
        ld (fs_tab),hl          ; this shift's k glyph images
        ; HL = the image for strip byte q, wrapping at fs_end
        ld a,(fs_k)
        ld l,a
        ld h,0
        call x10
        ld de,(fs_tab)
        add hl,de
        ld (fs_end),hl
        ld a,(fs_q)
        ld l,a
        ld h,0
        call x10
        add hl,de
        push hl
        ; DE = the first glyph's place in the PCG window, its bank selected
        ld de,(fs_g)
        ld a,e
        rla
        ld a,d
        rla                     ; A = glyph / 128
        add a,BK_SCN
        ld (fs_bank),a
        or LV_SCREEN
        out (P_LV),a
        ld a,e
        and $7F
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PCGWIN
        add hl,de
        ex de,hl
        pop hl
        ld a,(fs_k)
        ld b,a
.g:     push bc
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        push de
        ld de,(fs_end)
        or a
        sbc hl,de
        jr nz,.nw
        ld hl,(fs_tab)
        jr .w2
.nw:    add hl,de
.w2:    pop de
        ld a,e                  ; the next glyph: 16 bytes on
        add a,6
        ld e,a
        jr nc,.d
        inc d
        jr nz,.d
        ld d,$F8                ; past the bank's end: the next bank
        ld a,(fs_bank)
        inc a
        ld (fs_bank),a
        or LV_SCREEN
        out (P_LV),a
.d:     pop bc
        djnz .g
.row_end:
        ld hl,fs_r
        dec (hl)
        jp nz,.row
        ld a,LV_SCREEN
        out (P_LV),a
        pop af
        call map_blk
        pop hl
        pop de
        pop bc
        ret
