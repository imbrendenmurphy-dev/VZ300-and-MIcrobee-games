; ---------------------------------------------------------------------------
; PAL full-screen video: 42 x 24 cells of 8 x 12 = 336 x 288, 312-line frame.
; Screen position n (0..2047) permanently shows PCG character n (bank n>>7).
; Page 0 = positions 0..1007, page 1 = 1008..2015; flipped with R12/R13.
; NATIVE holds 16 bytes per cell: rows 0..11, colour (12), dirty flag (15).
; ---------------------------------------------------------------------------
hw_init:
        ld a,$04                ; video RAM at F000, ROMs out
        out ($50),a
        xor a
        out ($0B),a
        out ($08),a
        ld a,$CF                ; PIO B: mode 3, no interrupts
        out ($03),a
        ld a,$BF
        out ($03),a
        ld a,7
        out ($03),a
        ld a,1
        in a,($09)
        ld hl,crtc_table
        ld c,0
.crtc:  ld a,c
        out ($0C),a
        ld a,(hl)
        out ($0D),a
        inc hl
        inc c
        ld a,c
        cp 16
        jr nz,.crtc
        ld a,$80                ; screen RAM: position n -> PCG char n & 127
        out ($1C),a
        ld hl,$F000
        ld bc,2048
.scr:   ld a,l
        or $80
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.scr
        ld a,$90                ; attribute RAM: PCG bank = n >> 7
        out ($1C),a
        ld hl,$F000
        ld de,0
        ld bc,2048
.attr:  ld a,d
        add a,a
        bit 7,e
        jr z,.even
        inc a
.even:  ld (hl),a
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.attr
        ld a,$80
        out ($1C),a
        ld hl,1008              ; page 0 is shown first, so draw page 1
        ld (pagebase),hl
        ld a,$3F
        ld (pageoff),a
        ld hl,DIRTY_CUR
        ld (cur_end),hl
        ld hl,DIRTY_PREV
        ld (prev_end),hl
        ret
;               R0  R1  R2  R3  R4  R5  R6  R7  R8  R9 R10 R11 R12 R13
crtc_table: db $35,$2A,$2D,$34,$19,$00,$18,$19,$48,$0B,$20,$0B,0,0,0,0

; Wait for the start of vertical blanking (and count it as a field).
wait_vb:
.a:     in a,($0C)
        and $20
        jr nz,.a
.b:     in a,($0C)
        and $20
        jr z,.b
        ld (vb_last),a
        ld a,(vb_count)
        inc a
        ld (vb_count),a
        ret

; Count fields while working: a rising edge of vertical blanking is one more
; 50 Hz field gone.  Called often enough (every few thousand T) not to miss
; the 24-line blank.  Preserves everything but AF.
vb_poll:
        in a,($0C)
        and $20
        push hl
        ld hl,vb_last
        cp (hl)
        jr z,.s
        ld (hl),a
        or a
        jr z,.s
        ld hl,vb_count
        inc (hl)
.s:     pop hl
        ret

; Queue the cell containing HL for copying.  Preserves BC, DE, HL.
dirty_cell:
        push hl
        push de
        ld a,l
        or 15
        ld l,a
        ld a,(hl)
        or a
        jr nz,.done
        ld (hl),1
        ld a,l
        and $F0
        ld l,a
        ex de,hl
        ld hl,(cur_end)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (cur_end),hl
.done:  pop de
        pop hl
        ret

; Copy this frame's and last frame's dirty cells to the hidden page, then show it.
present:
        ld hl,(cur_end)
        ld (own_end),hl
        ld ix,DIRTY_PREV
.merge: ld hl,(prev_end)
        push ix
        pop de
        or a
        sbc hl,de
        jr z,.merged
        ld l,(ix+0)
        ld h,(ix+1)
        call dirty_cell
        inc ix
        inc ix
        jr .merge
.merged:
        ld a,(blanked)
        or a
        call z,wait_vb          ; the hidden page is now really hidden
        call shaft_pre
        ld a,$FF
        ld (fbank),a
        ld hl,DIRTY_CUR
.next:  call vb_poll
        ld de,(cur_end)
        or a
        sbc hl,de
        add hl,de
        jr z,.colours
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl                ; HL = cell
        ld a,h
        sub NATIVE/256
        ld c,a
        ld a,(pageoff)
        add a,c                 ; high byte of (char * 16)
        ld c,a
        rrca
        rrca
        rrca
        and $0F
        ld b,a
        ld a,(fbank)
        cp b
        jr z,.same
        ld a,b
        ld (fbank),a
        or $80
        out ($1C),a
.same:  ld a,c
        and 7
        or $F8
        ld d,a
        ld e,l
        REPT 12
        ldi
        ENDR
        pop hl
        jr .next
.colours:
        ld a,$80
        out ($1C),a
        ld a,$40                ; colour RAM at F800
        out ($08),a
        ld hl,DIRTY_CUR
.cnext: call vb_poll
        ld de,(cur_end)
        or a
        sbc hl,de
        add hl,de
        jr z,.cdone
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld a,l
        or 12
        ld l,a
        ld c,(hl)               ; colour
        or 15
        ld l,a
        ld (hl),0               ; clean again
        and $F0
        ld l,a
        ld a,h
        sub NATIVE/256
        ld h,a
        REPT 4
        srl h
        rr l
        ENDR
        ld de,(pagebase)
        add hl,de
        ld de,$F800
        add hl,de
        ld (hl),c
        pop hl
        jr .cnext
.cdone: xor a
        out ($08),a
        ; this frame's own cells become next frame's "previous"
        ld hl,(own_end)
        ld de,DIRTY_CUR
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld de,DIRTY_PREV
        ld a,b
        or c
        jr z,.none
        ld hl,DIRTY_CUR
        ldir
.none:  ld (prev_end),de
        ld hl,DIRTY_CUR
        ld (cur_end),hl
        call shaft_post
        ; show the page just drawn
        ld a,12
        out ($0C),a
        ld a,(pagebase+1)
        out ($0D),a
        ld a,13
        out ($0C),a
        ld a,(pagebase)
        out ($0D),a
        ld hl,(pagebase)
        ld a,h
        or l
        ld hl,1008
        ld a,$3F
        jr z,.set
        ld hl,0
        xor a
.set:   ld (pagebase),hl
        ld (pageoff),a
        ld hl,(frames)
        inc hl
        ld (frames),hl
        ret

; HL = NATIVE address of cell (column A, row C).  Preserves BC.
cell_addr:
        push de
        push af
        ld l,c
        ld h,0
        add hl,hl
        ld de,rowbase
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop af
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        pop de
        ret

; Copy BACK to NATIVE for a new scene (show_all then puts it on screen).
full_redraw:
        ld hl,DIRTY_CUR         ; every cell is queued below: drop the old lists
        ld (cur_end),hl
        ld hl,DIRTY_PREV
        ld (prev_end),hl
        ld hl,BACK
        ld de,NATIVE
        ld bc,CELLS*16
        ldir
        ret

; HL = tile A (12 bytes).  Preserves BC, DE.
tile_ptr:
        push de
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        ld de,tiles
        add hl,de
        pop de
        ret

; Tile at HL + colour A into the cell at DE; DE moves to the next cell.
; Preserves A, BC, HL.
put_cell:
        push bc
        push hl
        ld bc,12
        ldir
        ld (de),a
        ex de,hl
        ld bc,4
        add hl,bc
        ex de,hl
        pop hl
        pop bc
        ret

; Unpack a room (runs of count, tile, colour; 0 ends) at HL into BACK.
draw_rle:
        ld de,BACK
.run:   ld a,(hl)
        or a
        ret z
        ld b,a
        inc hl
        ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        call tile_ptr
        ld a,c
.c:     call put_cell
        djnz .c
        pop hl
        jr .run

; Fill BACK row C with tile A in colour E.
fill_row:
        push de
        call tile_ptr
        push hl
        xor a
        call cell_addr
        ld a,h
        sub $40                 ; NATIVE -> BACK
        ld d,a
        ld e,l
        pop hl
        pop bc                  ; C = colour
        ld a,c
        ld b,COLS
.c:     call put_cell
        djnz .c
        ret

; Print the 0-terminated string at HL at column A, row C, colour E,
; into BACK and NATIVE (queued).
print_at:
        ld (pr_col),a
        ld a,e
        ld (pr_ink),a
.ch:    ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        call put_char
        ld hl,pr_col
        inc (hl)
        pop hl
        jr .ch

; Character A at (pr_col, row C) in colour pr_ink.  Preserves C.
put_char:
        sub 32
        cp 64
        jr c,.ok
        sub 32                  ; lower case -> upper
.ok:    ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl               ; *12
        add hl,de
        add hl,hl
        add hl,hl
        ld de,font
        add hl,de
        push hl
        ld a,(pr_col)
        call cell_addr          ; HL = NATIVE cell
        pop de                  ; DE = glyph
        push hl
        ex de,hl
        push bc
        ld bc,12
        ldir
        ld a,(pr_ink)
        ld (de),a
        pop bc
        pop hl
        push hl
        push bc                 ; copy the cell to BACK = NATIVE - $4000
        ld d,h
        ld e,l
        ld a,d
        sub $40
        ld d,a
        ld bc,13
        ldir
        pop bc
        pop hl
        jp dirty_cell

; Screen off (no displayed rows: video RAM is free, no waits) / on.
blank_on:
        ld a,1
        ld (blanked),a
        ld a,6
        out ($0C),a
        xor a
        out ($0D),a
        ret
blank_off:
        xor a
        ld (blanked),a
        ld a,6
        out ($0C),a
        ld a,ROWS
        out ($0D),a
        ret

; Exchange which page is "hidden" without touching the display.
swap_hidden:
        ld hl,(pagebase)
        ld a,h
        or l
        ld hl,1008
        ld a,$3F
        jr z,.s
        ld hl,0
        xor a
.s:     ld (pagebase),hl
        ld (pageoff),a
        ret

; Copy every NATIVE cell to the hidden page (PCG + colour).  Screen off.
blit_page:
        ld hl,NATIVE
        ld bc,CELLS
.p:     push bc
        ld a,h
        sub NATIVE/256
        ld c,a
        ld a,(pageoff)
        add a,c
        ld c,a
        rrca
        rrca
        rrca
        and $0F
        or $80
        out ($1C),a
        ld a,c
        and 7
        or $F8
        ld d,a
        ld e,l
        REPT 12
        ldi
        ENDR
        ld bc,4
        add hl,bc
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,.p
        ld a,$80
        out ($1C),a
        ld a,$40
        out ($08),a
        ld hl,(pagebase)
        ld de,$F800
        add hl,de
        ex de,hl                ; DE = colour RAM of the page
        ld hl,NATIVE+12
        ld bc,CELLS
.c:     ld a,(hl)
        ld (de),a
        inc de
        ld a,l
        add a,16
        ld l,a
        jr nc,$+3
        inc h
        dec bc
        ld a,b
        or c
        jr nz,.c
        xor a
        out ($08),a
        ret

; With the screen off, put both pages back to ordinary cells showing NATIVE.
show_all:
        call blank_on
        xor a
        ld (lift_dir),a
        ld hl,page_vars
        ld b,4
.z:     ld (hl),a
        inc hl
        djnz .z
        ld hl,DIRTY_CUR
        ld (cur_end),hl
        ld hl,DIRTY_PREV
        ld (prev_end),hl
        call .page
        call swap_hidden
        call .page
        ld a,12                 ; show this one, draw into the other
        out ($0C),a
        ld a,(pagebase+1)
        out ($0D),a
        ld a,13
        out ($0C),a
        ld a,(pagebase)
        out ($0D),a
        call swap_hidden
        jp blank_off
.page:  ld b,0
        ld c,ROOM_ROWS-1
        call map_identity
        jp blit_page