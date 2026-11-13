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
        jp m_column             ; M_COLUMN: (m_x) = world column: all 24 rows
        jp m_queue              ; M_QUEUE:  the game's requests (MAPQ)
        jp m_mixed              ; M_MIXED:  the shift changed: cells of two inks

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
        ld (m_r),a
        ld a,24
        ld (m_n),a
        ; fall through

; (m_x) = world column, (m_r) = first row (0..23), (m_n) = rows.
; A cell that already shows what it should (most of the sky) is left alone.
m_rows:
        ld hl,(nflip)           ; room in the flip list?
        ld a,h
        or a
        ret nz
        ld a,l
        cp 190
        ret nc
        ld hl,(m_x)
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl
        add hl,hl
        add hl,hl               ; x 24
        ld a,(m_r)
        ld e,a
        ld d,0
        add hl,de
        ld de,M_CGMAP
        add hl,de
        push hl
        ld a,(m_r)
        inc a                   ; screen row
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; x 40
        ld de,(m_x)
        add hl,de
        ld de,(org)
        add hl,de
        ld a,h
        and 7
        or SCRSH >> 8
        ld d,a
        ld e,l                  ; DE = the cell's place in SCRSH
        pop hl                  ; HL = the left cell glyph
        push hl
        pop ix
        ld bc,24
        add ix,bc               ; IX = the right one
        ld a,(m_n)
        ld b,a
        ld iy,(entptr)
.cell:  ld a,(hl)
        or (ix+0)
        jr nz,.full
        ld a,(de)               ; the empty pair
        cp $80
        jr nz,.emp
        set 3,d
        ld a,(de)
        res 3,d
        cp $80
        jp z,.next
.emp:   push bc
        ld bc,$8080
        jr .emit
.full:  push bc
        push hl
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
        jr nz,.emit
        pop bc
        jr .next
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
        jr z,.em2
        pop bc
        push bc
        ld a,(m_n)
        sub b
        ld c,a
        ld a,(m_r)
        add a,c
        call m_setmix
.em2:   pop bc
.next:  inc hl
        inc ix
        ld a,e
        add a,COLS
        ld e,a
        jr nc,.n2
        inc d
        res 3,d
.n2:    dec b
        jp nz, .cell
        ld (entptr),iy
        ret

; note that the cell at row A of column (m_x) takes its ink from the shift
m_setmix:
        push hl
        push de
        ld e,a
        ld a,(m_x)
        and 63
        add a,a
        add a,a
        ld l,a
        ld a,e
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
        jr nz,.work
.nxt:   inc l
        inc l
        inc c
        djnz .col
        ld (entptr),ix
        ret
.work:  push hl
        push bc
        dec l
        dec l
        push hl
        ld hl,(sstart)
        ld b,0
        add hl,bc
        ld (m_ring),hl
        pop hl
        ld c,0                  ; row
.byte:  ld a,(hl)
        inc l
        push hl
        or a
        jr z,.nby
        ld b,a                  ; this byte's rows
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
        cp 24
        jr c,.byte
        pop bc
        pop hl
        jr .nxt
; C = row: this column's cell of that row gets its colour again
.cellc: ld a,(nflip)
        cp 190
        ret nc
        ld l,c
        ld h,0
        add hl,hl
        ld de,rows40
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
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
        bit 6,e
        ret z
        ld (ix+2),d
        ld (ix+5),e
        ld a,(oldphase)         ; its ink at the last shift
        call .inkof
        push af
        ld a,(phase)
        call .inkof
        ld (ix+3),c
        ld (ix+4),a
        pop bc
        cp b
        ret z                   ; the same ink: leave the cell alone
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
rows40:
        dw 40,80,120,160,200,240,280,320,360,400,440,480
        dw 520,560,600,640,680,720,760,800,840,880,920,960

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
        ld de,24
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
        ld de,24
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
        ld bc,24
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
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
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

; HL = column, C = first row, B = rows: build its cells if it is on the screen
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
        ld a,c
        ld (m_r),a
        ld a,b
        ld (m_n),a
        push ix
        call m_rows
        pop ix
        ret
mapcode_end:
        ASSERT mapcode_end <= M_HASH

        ORG M_HASH
        INCBIN "../build/hash.bin"
        ORG M_TCELL
        INCBIN "../build/tcell.bin"
        ORG M_PLATH
        INCBIN "../build/plat.bin"
        ORG M_PCOL
        INCBIN "../build/pcol.bin"
        ORG M_CGMAP
        INCBIN "../build/cgmap.bin"
map_end:
        SAVEBIN "../build/MAP.BNK",0,map_end
