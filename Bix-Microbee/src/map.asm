; =====================================================================
;  map.asm - the map block (BLK_MAP, 0000-7FFF): the world as a map of
;  8 x 8 cell glyphs, 24 to a column, and the code that turns it into
;  screen cells.
;
;  A screen cell shows the join of two neighbouring cell glyphs (a
;  "pair") at one of four shifts. Every pair has a screen code and a set
;  (0-2); its four shifted pictures sit at that code in PCG banks
;  set * 4 + shift. So a cell's code never changes while it is on the
;  screen: scrolling two pixels only changes every cell's bank.
;
;  Cells are not written to the screen here. Each gets an entry in the
;  engine's flip list (made in the next vertical blanking) and its
;  background is noted in the ring shadows SCRSH / ATTSH.
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"
        INCLUDE "vars.inc"

        ORG $0000
        jp m_column             ; M_COLUMN: (m_x) = world column: the rows on show
        jp m_queue              ; M_QUEUE:  the game's requests (MAPQ)
        jp m_mixed              ; M_MIXED:  the shift changed: cells of two inks
        jp m_row                ; M_ROW:    (m_r) = world row: the columns on show

CGROWS  EQU 32                  ; cell glyphs in a column of the map

; ---------------------------------------------------------------------
m_column:
        ; a new column: forget the old one's two-ink cells
        ld a,(m_x)
        and 63
        add a,a
        add a,a
        ld l,a
        ld h,COLMIX >> 8
        xor a
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        ld a,(camrow)
        ld (m_r),a
        ld a,PFROWS
        ld (m_n),a
        ; fall through

; (m_x) = world column, (m_r) = first world row, (m_n) = rows: down a column.
; A cell that already shows what it should (most of the sky) is left alone.
m_rows: call m_setup
        ret c
        ld a,(m_n)
        ld b,a
.l:     push bc
        call m_cell
        pop bc
        inc hl
        inc ix
        ld a,e
        add a,COLS
        ld e,a
        jr nc,.n
        inc d
        res 3,d
.n:     ld a,(m_r)
        inc a
        ld (m_r),a
        djnz .l
        ld (entptr),iy
        ret

; (m_r) = world row: its 40 cells on show, along the row
m_row:  ld hl,(camcell)
        ld (m_x),hl
        call m_setup
        ret c
        ld b,COLS
.l:     push bc
        call m_cell
        pop bc
        ld a,l
        add a,CGROWS
        ld l,a
        jr nc,.n1
        inc h
.n1:    push de
        ld de,CGROWS
        add ix,de
        pop de
        inc e
        jr nz,.n2
        inc d
        res 3,d
.n2:    push hl
        ld hl,(m_x)
        inc hl
        ld (m_x),hl
        pop hl
        djnz .l
        ld (entptr),iy
        ret

; -> HL = the cell glyph at (m_x, m_r), IX = the one to its right, DE = the
; cell's place in SCRSH, IY = the flip list; carry if the list is full
m_setup:
        ld hl,(nflip)
        ld a,h
        or a
        scf
        ret nz
        ld a,l
        cp 180
        ccf
        ret c
        ld a,(m_r)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; row x 40
        ld de,(m_x)
        add hl,de
        ld de,(org)
        add hl,de
        ld a,h
        and 7
        or SCRSH >> 8
        ld h,a
        push hl
        ld hl,(m_x)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; x 32
        ld a,(m_r)
        ld e,a
        ld d,0
        add hl,de
        ld de,M_CGMAP
        add hl,de
        push hl
        pop ix
        ld de,CGROWS
        add ix,de
        pop de
        ld iy,(entptr)
        or a
        ret

; one cell: HL, IX = its two cell glyphs, DE = its place in SCRSH
m_cell: ld a,(hl)
        or (ix+0)
        jr nz,.full
        ld a,(de)               ; the empty pair
        cp $80
        jr nz,.emp
        set 3,d
        ld a,(de)
        res 3,d
        cp $80
        ret z
.emp:   ld bc,$8080
        jr .emit
.full:  push hl
        push de
        ld b,(hl)
        ld c,(ix+0)
        call m_lookup           ; D = code, E = attribute flags
        ld b,d
        ld c,e
        pop de
        pop hl
        ld a,(de)
        cp b
        jr nz,.emit
        set 3,d
        ld a,(de)
        res 3,d
        cp c
        jr nz,.emit
        bit 6,c
        ret z
.emit:  ld a,b                  ; B = code, C = flags
        ld (de),a
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        ld (iy+0),e
        ld a,d
        and 7
        or VIDEO >> 8
        ld (iy+1),a
        ld (iy+2),b
        ld (iy+5),c
        push hl
        ld a,(phase)
        ld l,a
        ld a,c
        and $0F
        or l
        ld (iy+3),a
        ld h,a
        ld a,b
        add a,a
        ld l,a
        ld a,h
        or a
        rra
        ld h,a
        rr l                    ; HL = attribute * 128 + code
        ld a,(pcol_h)
        add a,h
        ld h,a
        ld a,(hl)
        ld (iy+4),a
        ld hl,(nflip)
        inc hl
        ld (nflip),hl
        ld hl,ncq
        inc (hl)
        pop hl
        push de
        ld de,6
        add iy,de
        pop de
        bit 6,c
        ret z
        ; note that this cell takes its ink from the shift
        push hl
        push de
        ld a,(m_x)
        and 63
        add a,a
        add a,a
        ld l,a
        ld a,(m_r)
        ld e,a
        rrca
        rrca
        rrca
        and 3
        add a,l
        ld l,a
        ld h,COLMIX >> 8
        ld a,e
        and 7
        ld e,a
        ld d,0
        push hl
        ld hl,bitmask
        add hl,de
        ld a,(hl)
        pop hl
        or (hl)
        ld (hl),a
        pop de
        pop hl
        ret
bitmask: db 1,2,4,8,16,32,64,128

; B = left cell glyph, C = right -> D = screen code, E = attribute flags
m_lookup:
        ld a,b
        or c
        jr nz,.h
        ld de,$8080
        ret
.h:     ld a,c
        rrca
        rrca
        xor b
        ld l,a
        ld a,c
        and 3
        ld h,a
        add hl,hl
        add hl,hl
        ld a,h
        or M_HASH >> 8
        ld h,a
.p:     ld a,(hl)
        cp b
        jr nz,.nx
        inc l
        ld a,(hl)
        dec l
        cp c
        jr nz,.adv
        inc l
        inc l
        ld d,(hl)
        inc l
        ld e,(hl)
        ret
.nx:    inc a
        jr nz,.adv
        inc l
        ld a,(hl)
        dec l
        inc a
        jr z,.miss
.adv:   ld a,l
        add a,4
        ld l,a
        jr nc,.p
        inc h
        ld a,h
        and $0F
        or M_HASH >> 8
        ld h,a
        jr .p
.miss:  ld hl,miss_count
        inc (hl)
        ld de,$8080
        ret
miss_count: db 0

; ---------------------------------------------------------------------
;  the shift changed: every cell on the screen that joins two inks gets
;  its colour again (the ink of whichever side now shows more)
; ---------------------------------------------------------------------
m_mixed:
        ld a,(oldphase)         ; between shifts 0 and 1 the left side shows
        ld b,a                  ; more both times: no ink changes
        ld a,(phase)
        or b
        dec a
        ret z
        ld ix,(entptr)
        ld a,(camcell)
        and 63
        add a,a
        add a,a
        ld l,a
        ld h,COLMIX >> 8
        ld bc,COLS*256
.col:   ld a,(hl)
        inc l
        or (hl)
        inc l
        or (hl)
        inc l
        or (hl)
        jr nz,.work
.nxt:   inc l
        inc c
        djnz .col
        ld (entptr),ix
        ret
.work:  push hl
        push bc
        dec l
        dec l
        dec l
        push hl
        ld hl,(camcell)
        ld b,0
        add hl,bc
        ld de,(org)
        add hl,de
        ld (m_ring),hl
        pop hl
        ld c,0                  ; world row
.byte:  ld a,(hl)
        inc l
        push hl
        or a
        jr z,.nby
        ld b,a
.bit:   srl b
        jr nc,.nb
        push bc
        call .cellc
        pop bc
.nb:    inc c
        ld a,b
        or a
        jr nz,.bit
.nby:   ld a,c
        or 7
        inc a
        ld c,a
        pop hl
        cp CGROWS
        jr c,.byte
        pop bc
        pop hl
        jr .nxt
; C = world row: this column's cell of that row gets its colour again
.cellc: ld a,(nflip)
        cp 180
        ret nc
        ld a,(camrow)
        ld b,a
        ld a,c
        sub b
        cp PFROWS
        ret nc                  ; not on the screen
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,(m_ring)
        add hl,de
        ld a,h
        and 7
        ld h,a
        ld (ix+0),l
        or VIDEO >> 8
        ld (ix+1),a
        ld a,h
        or SCRSH >> 8
        ld h,a
        ld d,(hl)
        add a,(ATTSH - SCRSH) >> 8
        ld h,a
        ld e,(hl)
        bit 7,e
        ret z
        bit 6,e
        ret z
        ld (ix+2),d
        ld (ix+5),e
        ld a,(phase)
        call .inkof
        ld (ix+3),c
        ld (ix+4),a
        ld de,6
        add ix,de
        ld hl,(nflip)
        inc hl
        ld (nflip),hl
        ret
; A = shift, D = code, E = flags -> A = the ink, C = the bank
.inkof: ld b,a
        ld a,e
        and $0F
        or b
        ld c,a
        ld a,d
        add a,a
        ld l,a
        ld a,c
        or a
        rra
        ld h,a
        rr l
        ld a,(pcol_h)
        add a,h
        ld h,a
        ld a,(hl)
        ret

; ---------------------------------------------------------------------
;  the game's requests: X (2), row, n, kind, argument
;   0 clear n cell glyphs of row r from column X
;   1 the floating log, shifted arg pixels: 7 cell glyphs of row r
;   2 / 3 the lift, top / bottom row, shifted arg down: 6 cell glyphs
;   4 show n columns from X again, rows r .. r + arg - 1
;   5 tile (X, r) becomes tile arg
; ---------------------------------------------------------------------
m_queue:
        ld a,(nmapq)
        or a
        ret z
        ld b,a
        ld ix,MAPQ
.op:    push bc
        ld a,(ix+4)
        or a
        jr z,.clear
        dec a
        jr z,.plath
        dec a
        jr z,.platv
        dec a
        jr z,.platv2
        dec a
        jr z,.show
        jp .tile
.clear: call q_addr
        ld b,(ix+3)
        ld de,CGROWS
.c1:    ld (hl),0
        add hl,de
        djnz .c1
        jr .nextop
.plath: ld a,(ix+5)
        ld e,a
        add a,a
        add a,a
        add a,a
        sub e                   ; x 7
        ld e,a
        ld d,0
        ld hl,M_PLATH
        add hl,de
        ld b,7
        jr .copy
.platv2:
        ld de,6
        jr .pv
.platv: ld de,0
.pv:    ld a,(ix+5)
        add a,a
        add a,a
        ld l,a
        add a,a
        add a,l                 ; x 12
        ld l,a
        ld h,0
        add hl,de
        ld de,M_PLATV
        add hl,de
        ld b,6
.copy:  push hl
        call q_addr
        pop de
.cp:    ld a,(de)
        ld (hl),a
        inc de
        push de
        ld de,CGROWS
        add hl,de
        pop de
        djnz .cp
        jr .nextop
.show:  ld l,(ix+0)
        ld h,(ix+1)
        ld b,(ix+3)
.s1:    push bc
        push hl
        ld c,(ix+2)
        ld b,(ix+5)
        call q_show
        pop hl
        inc hl
        pop bc
        djnz .s1
.nextop:
        ld de,6
        add ix,de
        pop bc
        dec b
        jp nz,.op
        xor a
        ld (nmapq),a
        ret
.tile:  ; the tile's four cell glyphs
        ld a,(ix+5)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,M_TCELL
        add hl,de
        push hl
        ld l,(ix+0)
        ld h,(ix+1)
        add hl,hl               ; cell column
        ld (m_x),hl
        ld a,(ix+2)
        add a,a
        ld (m_r),a
        call q_addr2
        pop de
        ld a,(de)
        ld (hl),a               ; TL
        inc de
        push hl
        ld bc,CGROWS
        add hl,bc
        ld a,(de)
        ld (hl),a               ; TR
        inc de
        pop hl
        inc hl
        ld a,(de)
        ld (hl),a               ; BL
        inc de
        add hl,bc
        ld a,(de)
        ld (hl),a               ; BR
        ; show the three columns its joins are in
        ld hl,(m_x)
        dec hl
        ld b,3
.t1:    push bc
        push hl
        ld a,(ix+2)
        add a,a
        ld c,a
        ld b,2
        call q_show
        pop hl
        inc hl
        pop bc
        djnz .t1
        jr .nextop

; cell glyph address of (IX+0/1 column, IX+2 row)
q_addr: ld l,(ix+0)
        ld h,(ix+1)
        ld (m_x),hl
        ld a,(ix+2)
        ld (m_r),a
q_addr2:
        ld hl,(m_x)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(m_r)
        ld e,a
        ld d,0
        add hl,de
        ld de,M_CGMAP
        add hl,de
        ret

; HL = column, C = first world row, B = rows: build the part of it that is
; on the screen
q_show: push hl
        ld de,(camcell)
        or a
        sbc hl,de
        ld a,h
        or a
        pop de
        ret nz
        ld a,l
        cp COLS
        ret nc
        ld (m_x),de
        ld a,(camrow)           ; clip the rows to the picture
        ld e,a
        ld a,c
        add a,b
        ld d,a                  ; D = the row after the last
        ld a,c
        cp e
        jr nc,.t1
        ld a,e
.t1:    ld c,a                  ; C = first row
        ld a,e
        add a,PFROWS
        cp d
        jr nc,.t2
        ld d,a
.t2:    ld a,d
        sub c
        ret c
        ret z
        ld (m_n),a
        ld a,c
        ld (m_r),a
        push ix
        call m_rows
        pop ix
        ret
mapcode_end:
        ASSERT mapcode_end <= M_HASH

; M_HASH .. M_CGMAP and the cell-glyph map are filled from the stage's
; blocks when it starts (e_stage)
        ORG M_HUDG
        INCBIN "../build/hudg.bin"
        ORG M_FONT
        INCBIN "../build/font.bin"
map_end2:
        SAVEBIN "../build/MAP.BNK",0,map_end2
