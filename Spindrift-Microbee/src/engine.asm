; =====================================================================
;  ENGINE: start-up, the two screen pages, the cell compositor, the
;  commit in the vertical blanking, the text queue.
;
;  The screen is 40 x 25 cells of 8 x 8. Every cell can show any of the
;  2048 PCG glyphs. Two screen pages (0000h and 0400h of screen RAM) and
;  two glyph banks (14 and 15) take turns: while one page is on show,
;  the other is rebuilt, and the 6545's start address is switched in the
;  vertical blanking. For every cell a sprite touches this frame, a
;  private glyph is composed in ordinary RAM (sprites ORed together), so
;  sprites move a pixel at a time, overlap freely and never flicker.
;
;  Only the commit touches video RAM, and it runs in the vertical
;  blanking, where the 6545 does not hold the CPU.
; =====================================================================

; The 40-column mode: dot clock select (IN (09h) with A = 1) and the
; 6545 table proven by BPM's MODES40 test on the real Premium Plus.
crtc_game:  db $35,$28,$2C,$34,$26,$01,$19,$21,$48,$07,$20,$07,0,0,0,0
DROWS       EQU 25

hw_init:
        di
        ld hl,VARS
        ld de,VARS+1
        ld bc,$2FF
        ld (hl),0
        ldir
        ; PIO A: input (joystick)
        ld a,$CF
        out (P_PIOAC),a
        ld a,$FF
        out (P_PIOAC),a
        ld a,$07
        out (P_PIOAC),a
        ; PIO B: bit control, b6 speaker out
        ld a,$CF
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
        in a,(P_CLK40)          ; the 40-column dot clock
        ld hl,crtc_game
        call crtc_set
        call display_off
        ld hl,$ACE1
        ld (rseed),hl
        ; row -> CELLHI address table
        ld hl,CELLHI
        ld de,40
        ld ix,rowcell
        ld b,25
.rc:    ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        add hl,de
        djnz .rc
        ; colour map: colour monitor = itself
        call set_colour_mode
        ; the font and icons into bank 0, the star dots into both pools
        ld a,MP_TAB
        out (P_MEM),a
        ld hl,FONTPAT
        ld a,BK_FONT
        ld bc,NFONT
        call pcg_load
        ld hl,STARPAT
        ld a,BK_POOL0
        ld bc,17
        call pcg_load
        ld hl,STARPAT
        ld a,BK_POOL1
        ld bc,17
        call pcg_load
        ld a,LISTA >> 8
        ld (lnew),a
        ld a,LISTB >> 8
        ld (lback),a
        ld a,LISTC >> 8
        ld (lfront),a
        ld a,TQA >> 8
        ld (tqcur),a
        ld a,TQB >> 8
        ld (tqprev),a
        jp screen_reset

; colour map: (mono) = 0 colour, else every ink is drawn bright
set_colour_mode:
        ld hl,colmap
        ld b,16
        ld c,0
.l:     ld a,(mono)
        or a
        ld a,c
        jr z,.s
        or a
        jr z,.s
        ld a,WHITE
.s:     ld (hl),a
        inc hl
        inc c
        djnz .l
        ret

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

win_screen:
        xor a
        out (P_COLCTL),a
        ld a,LV_SCREEN
        out (P_LV),a
        ret
win_attr:
        xor a
        out (P_COLCTL),a
        ld a,LV_ATTR
        out (P_LV),a
        ret
win_col:
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ret

; HL = patterns (8 bytes a glyph, in the mapped block), A = first PCG
; bank, BC = glyphs
pcg_load:
        ld (pl_bank),a
        xor a
        out (P_COLCTL),a
.bank:  ld a,(pl_bank)
        or LV_SCREEN
        out (P_LV),a
        ld de,PCGWIN
.g:     push bc
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        pop bc
        ld a,e
        add a,8
        ld e,a
        jr nc,.nc
        inc d
.nc:    dec bc
        ld a,b
        or c
        jr z,.done
        ld a,d
        or a
        jr nz,.g
        ld a,(pl_bank)
        inc a
        ld (pl_bank),a
        jr .bank
.done:  ld a,LV_SCREEN
        out (P_LV),a
        ret

; HL = start, BC = count (>= 2), A = value
fill:   ld (hl),a
        ld d,h
        ld e,l
        inc de
        dec bc
        ldir
        ret

; ---------------------------------------------------------------------
; A blank, dark screen on both pages, every table reset. The display is
; left off: draw the static parts, then display_on.
; ---------------------------------------------------------------------
screen_reset:
        call display_off
        call win_screen
        ld hl,VIDEO
        ld bc,$800
        ld a,$80
        call fill
        call win_attr
        ld hl,VIDEO
        ld bc,$400
        ld a,BK_POOL0
        call fill
        ld hl,VIDEO+PAGE1
        ld bc,$400
        ld a,BK_POOL1
        call fill
        call win_col
        ld hl,PCGWIN
        ld bc,$800
        ld a,WHITE
        call fill
        call win_screen
        ld hl,CELLHI
        ld bc,$800
        xor a
        call fill
        xor a
        ld (nslots),a
        ld (lcount),a
        ld (flashcnt),a
        ld hl,LISTA+$1FE
        ld (hl),a
        ld hl,LISTB+$1FE
        ld (hl),a
        ld hl,LISTC+$1FE
        ld (hl),a
        ld hl,TQA+$3FF
        ld (hl),a
        ld hl,TQB+$3FF
        ld (hl),a
        ; page 0 on show, page 1 is the back page
        ld a,12
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ld a,1
        ld (page),a
        ret

; ---------------------------------------------------------------------
; The frame. frame_begin, then draw sprites and stars, then frame_end.
; ---------------------------------------------------------------------
frame_begin:
        xor a
        ld (nslots),a
        ld (lcount),a
        ld l,a
        ld a,(lnew)
        ld h,a
        ld (lp_addr),hl
        add a,2
        ld h,a
        ld (lp_code),hl
        ld hl,CELLPTR
        ld (lp_cell),hl
        ld hl,POOLBUF
        ld (nextbuf),hl
        ld a,$91
        ld (nextcode),a
        ; vdelta = VIDEO + back page offset - CELLHI
        ld a,(page)
        add a,a
        add a,a
        add a,(VIDEO - CELLHI) >> 8
        ld h,a
        ld l,0
        ld (vdelta),hl
        ret

; A = colour -> the colour new cells are given (through the mono map)
setcol: push hl
        ld hl,colmap
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        ld (dcol),a
        pop hl
        ret

; Count vertical blankings seen while working: the game is locked to
; 25 frames a second (a frame is shown at the second blanking).
vbpoll: push af
        in a,(P_CRTCA)
        and $20
        push hl
        ld hl,vlast
        cp (hl)
        jr z,.s
        ld (hl),a
        or a
        jr z,.s
        ld hl,fields
        inc (hl)
.s:     pop hl
        pop af
        ret

frame_end:
        ld a,(lp_code)
        ld (lcount),a
        ld a,(lnew)
        inc a
        ld h,a
        ld l,$FE
        ld a,(lcount)
        ld (hl),a
        ; the time the frame's work took, for the measurements
        call vbpoll
.w:     ld a,(fields)
        cp 2
        jr nc,.late
        call snd_field
        jr .w
.late:  in a,(P_CRTCA)
        and $20
        call z,snd_field        ; not in a blanking now: wait for the next
        xor a
        ld (fields),a
        ld a,$20
        ld (vlast),a
        call commit
        call cleanup
        ld hl,(frameno)
        inc hl
        ld (frameno),hl
        ret

; ---------------------------------------------------------------------
; The commit, in the vertical blanking: the back page gets this frame.
; ---------------------------------------------------------------------
commit:
        ; ---- the composed glyphs into the back page's PCG bank
        xor a
        out (P_COLCTL),a
        ld a,(page)
        add a,BK_POOL0 | LV_SCREEN
        out (P_LV),a
        ld a,(nextcode)
        sub $91
        jr z,.nog
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,pcg_end
        or a
        sbc hl,de
        call .pcg
.nog:   ld a,LV_SCREEN
        out (P_LV),a
        ; ---- blank the cells this page showed last time
        ld a,(lback)
        inc a
        ld h,a
        ld l,$FE
        ld a,(hl)
        or a
        jr z,.noclr
        ld b,a
        ld a,(lback)
        ld h,a
        ld l,0
        ld (save_sp),sp
        ld sp,hl
        ld c,$80
.cl:    pop hl
        ld (hl),c
        djnz .cl
        ld sp,(save_sp)
.noclr:
        ; ---- text, and a flash of the background
        call tq_apply
        ld a,(flashcnt)
        or a
        call nz,flash_fill
        ; ---- the new cells
        ld a,(lcount)
        or a
        jr z,.show
        ld b,a
        ld a,(lnew)
        ld h,a
        ld l,0
        add a,2
        ld d,a
        ld e,l
        ld (save_sp),sp
        ld sp,hl
.cd:    pop hl
        ld a,(de)
        ld (hl),a
        inc e
        djnz .cd
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,(lcount)
        ld b,a
        ld a,(lnew)
        ld h,a
        ld l,0
        add a,3
        ld d,a
        ld e,l
        ld sp,hl
.cc:    pop hl
        set 3,h
        ld a,(de)
        ld (hl),a
        inc e
        djnz .cc
        ld sp,(save_sp)
        xor a
        out (P_COLCTL),a
.show:  ; ---- and show it
        ld a,12
        out (P_CRTCA),a
        ld a,(page)
        add a,a
        add a,a
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ld a,(page)
        xor 1
        ld (page),a
        ; ---- the lists move on: back <- front <- new <- (old back)
        ld a,(lback)
        ld b,a
        ld a,(lfront)
        ld (lback),a
        ld a,(lnew)
        ld (lfront),a
        ld a,b
        ld (lnew),a
        ; how long the commit took (for the measurements)
        in a,(P_CRTCA)
        and $20
        jr nz,.inv
        ld hl,commit_late
        inc (hl)
.inv:   ret
.pcg:   ld (save_sp),sp
        jp (hl)

; the slots' cells back to "no glyph" (ordinary RAM: any time)
cleanup:
        ld a,(nextcode)
        sub $91
        ret z
        ld b,a
        ld hl,CELLPTR
        xor a
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (de),a
        djnz .l
        ret

; the background of the playfield (rows 1-23) flashes: two frames of the
; flash colour (one on each page), then two of black to put it back
flash_fill:
        dec a
        ld (flashcnt),a
        cp 2
        ld a,(flashcol)
        jr nc,.f
        ld a,WHITE
.f:     ld c,a
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,(page)
        add a,a
        add a,a
        add a,$F8
        ld h,a
        ld l,40
        ld de,23*40/8
.l:     ld (hl),c
        inc hl
        ld (hl),c
        inc hl
        ld (hl),c
        inc hl
        ld (hl),c
        inc hl
        ld (hl),c
        inc hl
        ld (hl),c
        inc hl
        ld (hl),c
        inc hl
        ld (hl),c
        inc hl
        dec de
        ld a,d
        or e
        jr nz,.l
        xor a
        out (P_COLCTL),a
        ret

; A = paper colour: flash the background
flash:  rlca
        rlca
        rlca
        rlca
        or WHITE
        ld (flashcol),a
        ld a,(mono)
        or a
        ret nz
        ld a,4
        ld (flashcnt),a
        ret

        INCLUDE "pcgcopy.inc"

; ---------------------------------------------------------------------
; draw_spr: HL = sprite record (its block mapped), DE = x of its centre
; (signed), C = y of its centre. The cells it touches get colour (dcol)
; unless something drawn earlier this frame has them already.
;   record: hotx, hoty, 8 pointers (one a pixel shift); a variant:
;   columns, lines, then each column's bytes top to bottom
; ---------------------------------------------------------------------
draw_spr:
        call vbpoll
        ld a,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ex de,hl                ; HL = x, DE = shifts
        push bc
        ld c,a
        ld b,0
        or a
        sbc hl,bc               ; HL = left
        pop bc
        ld a,c
        sub b
        ld c,a                  ; C = top
        sbc a,a
        ld (d_neg),a
        ld a,h                  ; reject far off either side
        inc a
        cp 3
        ret nc                  ; H not FFh, 0 or 1
        ld a,l
        and 7
        add a,a
        push af
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld a,l
        ld (d_col0),a
        pop af
        ld l,a
        ld h,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = the variant
        ld a,(de)
        ld (d_ncol),a
        inc de
        ld a,(de)
        ld (d_h),a
        ld b,a                  ; B = lines
        inc de
        ld (d_data),de
        ; vertical clipping
        ld a,(d_neg)
        or a
        ld a,0
        jr z,.top
        ld a,c
        neg                     ; lines above the top
        cp b
        ret nc
        ld e,a
        ld a,b
        sub e
        ld b,a
        ld a,e                  ; A = skip
        ld c,0
.top:   ld (d_skip),a
        ld a,c
        cp 200
        ret nc
        add a,b
        jr c,.clip
        cp 201
        jr c,.vok
.clip:  ld a,200
        sub c
        ld b,a
.vok:   ld a,b
        ld (d_vis),a
        ld a,c
        and 7
        ld (d_sub),a
        ld a,c
        rrca
        rrca
        rrca
        and 31
        add a,a
        ld l,a
        ld h,0
        ld de,rowcell
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (d_row),de
        ; the columns
        ld a,(d_ncol)
        ld b,a
        ld a,(d_col0)
        ld c,a
        ld hl,(d_data)
        ld a,(d_skip)
        ld e,a
        ld d,0
        add hl,de
.col:   push bc
        push hl
        ld a,c
        cp 40
        jr nc,.skip             ; off the left (negative) or the right
        ex de,hl                ; DE = this column's source
        ld hl,(d_row)
        ld b,0
        ld c,a
        add hl,bc
        push hl
        exx
        pop hl
        exx
        ld a,(d_vis)
        ld c,a
        ld a,(d_sub)
        call col_draw
.skip:  pop hl
        ld a,(d_h)
        ld e,a
        ld d,0
        add hl,de
        pop bc
        inc c
        djnz .col
        ret

; one column: DE = source bytes, C = lines (>= 1), A = line within the
; first cell, HL' = the CELLHI entry of the first cell
col_draw:
        ld b,a
.run:   exx
        ld a,(hl)
        or a
        call z,alloc
        ld d,a
        set 2,h
        ld e,(hl)
        res 2,h
        push de
        ld de,40
        add hl,de
        exx
        pop hl
        ld a,l
        add a,b
        ld l,a
        ld a,8
        sub b
        cp c
        jr c,.part
        ld b,c
        ld c,0
        jr .orl
.part:  ld b,a
        ld a,c
        sub b
        ld c,a
.orl:   ld a,(de)
        or (hl)
        ld (hl),a
        inc de
        inc l
        djnz .orl
        ld a,c
        or a
        ret z
        ld b,0
        jr .run

; a glyph for the cell at CELLHI entry HL (alternate set active).
; Out: A = buffer high byte; the CELLLO entry = its low byte. Keeps HL.
alloc:
        ld a,(nextcode)
        or a
        jr z,.full              ; past FFh: no glyphs left
        ld b,a
        inc a
        ld (nextcode),a
        ld (alloc_hl),hl
        ; the slot's cell, for the clean-up
        ex de,hl
        ld hl,(lp_cell)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (lp_cell),hl
        ; this frame's list: screen address, code, colour
        ld hl,(vdelta)
        add hl,de
        ex de,hl
        ld hl,(lp_addr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (lp_addr),hl
        ld hl,(lp_code)
        ld (hl),b
        inc h
        ld a,(dcol)
        ld (hl),a
        dec h
        inc l
        ld (lp_code),hl
        ; the glyph buffer, cleared
        ld hl,(nextbuf)
        ld d,h
        ld e,l
        xor a
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc hl
        ld (nextbuf),hl
        ld hl,(alloc_hl)
        ld (hl),d
        set 2,h
        ld (hl),e
        res 2,h
        ld a,d
        ret
.full:  set 2,h
        ld (hl),TRASH & 255
        res 2,h
        ld a,TRASH >> 8
        ret

; a star: HL = x (signed), C = y, B = colour. Only on empty cells.
star_cell:
        ld a,h
        cp 2
        ret nc
        ld a,c
        cp 200
        ret nc
        ld a,l
        rrca
        and 3
        ld e,a
        ld a,c
        and 6
        add a,a
        add a,e
        add a,$81
        ld (star_code),a
        ld a,l
        rrca
        rrca
        rrca
        and 31
        bit 0,h
        jr z,.c
        or 32
.c:     cp 40
        ret nc
        ld e,a
        ld d,0
        ld a,c
        rrca
        rrca
        rrca
        and 31
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,rowcell
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop de
        add hl,de
        ld a,(hl)
        or a
        ret nz                  ; a sprite (or text) has this cell
        ld a,(lp_code)
        cp MAXLIST
        ret nc
        ld de,(vdelta)
        add hl,de
        ex de,hl
        ld hl,(lp_addr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (lp_addr),hl
        ld hl,(lp_code)
        ld a,(star_code)
        ld (hl),a
        inc h
        ld (hl),b
        dec h
        inc l
        ld (lp_code),hl
        ret

; ---------------------------------------------------------------------
; The text queue: cells that hold text are written to each page in turn
; in the commit, and the compositor leaves them alone.
; ---------------------------------------------------------------------
; HL = cell, A = code, B = attribute (PCG bank, FFh = the page's pool),
; C = colour
tq_put: ld (tq_cell),hl
        ld (tq_code),a
        push hl
        push de
        ld de,CELLHI
        add hl,de
        ld a,b
        inc a
        jr z,.free
        ld (hl),TRASH >> 8
        set 2,h
        ld (hl),TRASH & 255
        jr .q
.free:  ld (hl),0
.q:     ld a,(tqcur)
        add a,3
        ld h,a
        ld l,$FF
        ld a,(hl)
        cp MAXTQ
        jr nc,.full
        inc (hl)
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld a,(tqcur)
        add a,h
        ld h,a
        ld de,(tq_cell)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(tq_code)
        ld (hl),a
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
.full:  pop de
        pop hl
        ld a,(tq_code)
        ret

; HL = cell: back to an empty cell
tq_clr: push af
        push bc
        ld a,$80
        ld b,$FF
        ld c,WHITE
        call tq_put
        pop bc
        pop af
        ret

; HL = cell, DE = text (0 ends it), C = colour
print_q:
.l:     ld a,(de)
        or a
        ret z
        inc de
        sub 32
        add a,$80
        ld b,BK_FONT
        call tq_put
        inc hl
        jr .l

; HL = cell, B = cells
clear_q:
.l:     call tq_clr
        inc hl
        djnz .l
        ret

; the queues are written to the back page: last frame's, then this one's
tq_apply:
        ld a,(page)
        add a,a
        add a,a
        add a,VIDEO >> 8
        ld (tq_page),a
        ld a,(page)
        add a,BK_POOL0
        ld (tq_pool),a
        ld a,(tqprev)
        call .one
        ld a,(tqcur)
        call .one
        ; this frame's queue becomes last frame's
        ld a,(tqprev)
        ld b,a
        ld a,(tqcur)
        ld (tqprev),a
        ld a,b
        ld (tqcur),a
        add a,3
        ld h,a
        ld l,$FF
        ld (hl),0
        ret
.one:   ld h,a
        add a,3
        ld d,a
        ld e,$FF
        ld a,(de)
        or a
        ret z
        ld b,a
        ld l,0
.e:     ld e,(hl)
        inc hl
        ld a,(tq_page)
        add a,(hl)
        ld d,a
        inc hl
        ld a,(hl)               ; code
        inc hl
        ld (de),a
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(hl)               ; attribute
        inc hl
        cp $FF
        jr nz,.a
        ld a,(tq_pool)
.a:     ld (de),a
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        set 3,d
        ld a,(hl)               ; colour
        inc hl
        ld (de),a
        xor a
        out (P_COLCTL),a
        djnz .e
        ret

; ---------------------------------------------------------------------
; Static text, written straight to both pages (for screens set up with
; the display off). HL = cell, DE = text, C = colour
; ---------------------------------------------------------------------
print_s:
.l:     ld a,(de)
        or a
        ret z
        inc de
        sub 32
        add a,$80
        ld b,BK_FONT
        call put_s
        inc hl
        jr .l

; HL = cell, A = code, B = bank, C = colour: both pages, and marked
put_s:  push hl
        push de
        push af
        ld de,CELLHI
        add hl,de
        ld (hl),TRASH >> 8
        set 2,h
        ld (hl),TRASH & 255
        pop af
        pop de
        pop hl
        push hl
        push de
        ld de,VIDEO
        add hl,de
        call .one
        ld de,PAGE1
        add hl,de
        call .one
        pop de
        pop hl
        ret
.one:   ld e,a
        xor a
        out (P_COLCTL),a
        ld a,LV_SCREEN
        out (P_LV),a
        ld (hl),e
        ld a,LV_ATTR
        out (P_LV),a
        ld (hl),b
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        set 3,h
        ld (hl),c
        res 3,h
        xor a
        out (P_COLCTL),a
        ld a,e
        ret

; ---------------------------------------------------------------------
random: push hl
        ld hl,(rseed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (rseed),hl
        pop hl
        ret
