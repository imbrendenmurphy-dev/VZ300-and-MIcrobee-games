; =====================================================================
;  map.asm - the map block (BLK_MAP, 0000-7FFF): the scroll.
;
;  The world is a map of 8 x 10 cell glyphs, 32 to a column (in block
;  BLK_CGM). A screen cell shows a QUAD: the 2 x 2 cell glyphs it can
;  overlap, cut at one of twelve PHASES - 4 steps of 2 pixels across times
;  3 steps of 0, 3 and 7 lines down. The quads on show are kept in 127
;  SLOTS: slot s is screen code 80h + s, and its picture at phase k is in
;  PCG bank k. So a scroll step changes no code: it only writes every
;  cell's bank (attribute), the same for all, with a run of PUSHes.
;
;  A quad gets a slot when a cell showing it comes on to the screen, and
;  gives it up when the last such cell leaves; its 12 pictures are worked
;  out then (from the cell glyphs) and sent to the PCG in the next
;  blanking. The stage's quads (each with its ink at every phase) are in a
;  hash table, M_QTAB.
;
;  Cells are not written here at once: each gets an entry in the flip list
;  (written in the blanking that shows the frame), and the code it shows
;  is kept in the ring shadow SCRSH.
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "hw.inc"
        INCLUDE "gen.inc"
        INCLUDE "vars.inc"
        INCLUDE "engsym.inc"

        ORG $0000
        jp m_scroll             ; 0  M_SCROLL: follow the camera
        jp m_queue              ; 3  M_QUEUE:  the game's requests (MAPQ)
        jp m_mixed              ; 6  M_MIXED:  the phase changed: cells of two inks
        jp m_present            ; 9  M_PRESENT: the frame to the screen
        jp m_snap               ; 12 M_SNAP:   draw it all again (display off)
        jp m_qinsert            ; 15 M_QINSERT: HL = 6-byte quad records, B = how many
        jp m_tabinit            ; 18 M_TABINIT: an empty quad table, slots, phases
        jp m_cgscatter          ; 21 M_CGSCATTER: HL = n x 10 bytes, B = n
        jp m_pcgclear           ; 24 M_PCGCLEAR: the empty glyph in every bank
        jp m_hudfull            ; 27 M_HUDPUT: the status line, now (display off)
        jp m_platcells          ; 30 M_PLAT: a moving log's cells this frame
        jp m_restores           ; 33 M_RESTORES: the sprites' cells, last frame's
        jp m_qbuild             ; 36 M_QBUILD: HL = quad records, B = how many: their records
        jp m_show               ; 39 M_SHOW: the frame on show, in the blanking

CGROWS  EQU 32                  ; cell glyphs in a column of the map
CGCOL   EQU 33                  ; ... as fetched (with an empty one under them)

; ---------------------------------------------------------------------
;  M_SCROLL: the camera (camx: VZ pixels across, camy: lines down) ->
;  the phase, then a column at a time and a row at a time to it.
; ---------------------------------------------------------------------
m_scroll:
        xor a
        ld (colstep),a
        ld a,(phase)
        ld (oldphase),a
        ld hl,(camy)
        ld h,DIV10 >> 8
        ld b,(hl)               ; row
        inc h
        ld e,(hl)               ; line in it
        ld d,0
        ld hl,qv_tab
        add hl,de
        ld a,(hl)
        and $0F                 ; vertical step
        add a,a
        add a,a
        ld c,a
        ld a,(hl)
        rlca
        rlca
        rlca
        rlca
        and 1                   ; nearer the next row
        add a,b
        ld (scratch+2),a        ; the row wanted
        ld hl,(camx)
        ld a,l
        and 3
        or c
        ld (scratch+3),a        ; the phase wanted
        srl h
        rr l
        srl h
        rr l
        ld (scratch),hl         ; the column wanted
        ld a,(scratch+3)
        ld hl,phase
        cp (hl)
        jr z,.hs
        ld (hl),a
        ld a,1
        ld (sdirty),a
        call ink_base
.hs:    ld hl,(scratch)
        ld de,(camcell)
        or a
        sbc hl,de
        jr z,.vs
        jp m,.left
        call step_right
        jr .hs
.left:  call step_left
        jr .hs
.vs:    ld a,(scratch+2)
        ld hl,camrow
        cp (hl)
        ret z
        jr c,.up
        call step_down
        jr .vs
.up:    call step_up
        jr .vs
; a line within a row -> (next row ? 10h : 0) + vertical step
qv_tab: db 0,0,1,1,1,1,2,2,2,$10

; the ring offset HL (any) -> 0..2047
ringw:  ld a,h
        and 7
        ld h,a
        ret

step_right:
        ld hl,(sstart)          ; the playfield's first cell leaves: it is
        ld de,COLS              ; the status line's last now
        add hl,de
        call ringw
        call cell_leave
        ld hl,(camcell)
        inc hl
        ld (camcell),hl
        call new_start
        ld hl,hud_dirty         ; the status line moved with the start
        set 0,(hl)
        ld hl,(camcell)
        ld de,COLS-1
        add hl,de
        ld (m_x),hl
        ld a,1                  ; all but the last row were on show
        ld b,0
        jr col_go
step_left:
        ld hl,(sstart)          ; the playfield's last cell leaves
        ld de,COLS*(PFROWS+1)-1
        add hl,de
        call ringw
        call cell_leave
        ld hl,(camcell)
        dec hl
        ld (camcell),hl
        call new_start
        ld hl,hud_dirty
        set 0,(hl)
        ld hl,(camcell)
        ld (m_x),hl
        xor a                   ; the first row was the status line's
        ld b,1
col_go: ld (m_cfirst),a
        ld a,b
        ld (m_clast),a
        ld a,1
        ld (colstep),a
        jp col_draw

step_down:
        ld a,1
        ld (colstep),a
        ld hl,(sstart)          ; the playfield's top row leaves
        ld de,COLS
        add hl,de
        call row_leave
        ld hl,camrow
        inc (hl)
        call new_start
        ld hl,hud_dirty
        set 1,(hl)
        ld a,(camrow)
        add a,PFROWS-1
        jp row_draw
step_up:
        ld a,1
        ld (colstep),a
        ld hl,(sstart)          ; the playfield's bottom row leaves
        ld de,COLS*PFROWS
        add hl,de
        call row_leave
        ld hl,camrow
        dec (hl)
        call new_start
        ld hl,hud_dirty
        set 1,(hl)
        ld a,(camrow)
        jp row_draw

; HL = ring offset: 40 cells leave the screen
row_leave:
        ld b,COLS
.l:     ld a,h                  ; (ring offset & 7FFh) in SCRSH
        and 7
        or SCRSH >> 8
        ld h,a
        ld a,(hl)
        ld (hl),$80
        and $7F
        jr z,.n
        push bc
        push hl
        ld b,a
        call slot_dec
        pop hl
        pop bc
.n:     inc hl
        ld a,b
        and 7
        jr nz,.np
        push hl
        call mpoll              ; (keeps BC)
        pop hl
.np:    djnz .l
        ret

; HL = ring offset (0..2047): the cell is not on show any more
cell_leave:
        ld a,h
        or SCRSH >> 8
        ld h,a
        ld a,(hl)
        ld (hl),$80
        and $7F
        ret z
        ld b,a
        jp slot_dec

; the start address and the row table from org, camcell and camrow
new_start:
        ld a,(camrow)
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
        ld de,(org)
        add hl,de
        ld de,(camcell)
        add hl,de
        ld de,-COLS             ; the status line is above the playfield
        add hl,de
        call ringw
        ld (sstart),hl
        ex de,hl
        ld hl,ROWTAB
        ld b,PF_ROW1
.r:     ld (hl),e
        inc l
        ld (hl),d
        inc l
        ld a,e
        add a,COLS
        ld e,a
        jr nc,.r1
        inc d
        res 3,d
.r1:    djnz .r
        ret

; ---------------------------------------------------------------------
;  a column of the playfield: world column (m_x), rows camrow.. camrow+23.
;  (m_cfirst) / (m_clast): were its first / last cells on show before
; ---------------------------------------------------------------------
col_draw:
        call lq_reset
        call cg_col             ; (engine) CGBUF = columns m_x and m_x+1
        ld a,1
        ld (m_colclr),a
        ld a,(m_x)              ; this column's two-ink cells: forget them
        and 63
        add a,a
        add a,a
        ld l,a
        ld h,M_COLMIX >> 8
        xor a
        ld b,4
.z:     ld (hl),a
        ld h,M_VMIX >> 8
        ld (hl),a
        ld h,M_COLMIX >> 8
        inc l
        djnz .z
        ld a,(camrow)
        ld (m_r),a
        call ring_of            ; HL = ring of (m_x, m_r)
        ld (m_ring),hl
        ld a,(camrow)
        add a,CGBUF & 255
        ld (cd_src),a
        ld a,(m_cfirst)
        ld (m_cnt),a
        ld b,PFROWS
.l:     push bc
        ld a,(cd_src)           ; the quad: CGBUF rows r, r+1 of both columns
        ld l,a
        inc a
        ld (cd_src),a
        ld h,CGBUF >> 8
        ld b,(hl)
        inc l
        ld d,(hl)
        ld a,l
        add a,CGCOL-1
        ld l,a
        ld c,(hl)
        inc l
        ld e,(hl)
        call m_cell
        ld hl,(m_ring)
        ld de,COLS
        add hl,de
        ld a,h
        and 7
        ld h,a
        ld (m_ring),hl
        ld hl,m_r
        inc (hl)
        pop bc
        ld a,b
        and 3
        call z,mpoll            ; (keeps BC)
        ld a,b
        cp 2
        ld a,1
        jr nz,.nl
        ld a,(m_clast)
.nl:    ld (m_cnt),a
        djnz .l
        xor a
        ld (m_colclr),a
        ret
cd_src: db 0
m_cfirst: db 0
m_clast: db 0

; A = world row: its cells across the screen (none were on show)
row_draw:
        ld (m_r),a
        call lq_reset
        call cg_row             ; (engine) CGBUF = rows m_r and m_r+1 of 41 columns
        ld hl,(camcell)
        ld (m_x),hl
        call ring_of
        ld (m_ring),hl
        xor a
        ld (m_cnt),a
        ld b,COLS
        ld hl,CGBUF
.l:     push bc
        push hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        ld de,COLS
        add hl,de
        ld d,(hl)
        inc hl
        ld e,(hl)
        call m_cell
        ld hl,(m_ring)
        inc hl
        ld a,h
        and 7
        ld h,a
        ld (m_ring),hl
        ld hl,(m_x)
        inc hl
        ld (m_x),hl
        pop hl
        inc hl
        pop bc
        ld a,b
        and 3
        jr nz,.np
        push hl
        call mpoll              ; (keeps BC)
        pop hl
.np:    djnz .l
        ret

; (m_x), (m_r) -> HL = its ring offset
ring_of:
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
        add hl,de
        ld de,(m_x)
        add hl,de
        ld de,(org)
        add hl,de
        jp ringw

; ---------------------------------------------------------------------
;  m_cell: B, C (top left, right), D, E (bottom left, right) = the cell
;  glyphs of a quad; (m_ring) its ring offset, (m_x, m_r) its world cell,
;  (m_cnt) 1 if the cell was on show. It gets the quad's slot (and keeps
;  the counts right) and an entry in the flip list.
; ---------------------------------------------------------------------
m_cell:
        ld a,b
        or c
        or d
        or e
        jr z,.blank
        ld hl,(m_lq)            ; the same quad as the cell before?
        or a
        sbc hl,bc
        jr nz,.find
        ld hl,(m_lq+2)
        sbc hl,de
        jr nz,.find
        ld a,(m_lslot)
        jr .have
.find:  ld (m_lq),bc
        ld (m_lq+2),de
        call qfind
        jr z,.nf                ; not in the table: shown empty
        ld (m_ent),hl
        ld a,l
        or 6
        ld l,a
        ld a,(hl)
        or a
        call z,slot_alloc       ; -> A = slot (0: none free)
        ld (m_lslot),a
        jr .have
.nf:    xor a
        ld (m_lslot),a
.blank: xor a
        ld (m_ent+1),a          ; no quad
.have:  ld c,a                  ; C = the slot from here on
        ld hl,(m_ring)
        ld a,h
        or SCRSH >> 8
        ld h,a
        ld a,(m_cnt)
        or a
        jr z,.new
        ld a,(hl)
        and $7F
        cp c
        jr nz,.diff
        ld a,(m_force)          ; it shows this quad already
        or a
        ret z
        jr .write
.diff:  or a
        jr z,.new
        push hl
        ld b,a
        call slot_dec           ; (keeps C)
        pop hl
.new:   ld a,c
        or a
        jr z,.write
        ld e,l
        ld d,h
        ld l,a
        ld h,M_SLREF >> 8
        inc (hl)
        ex de,hl
.write: ld a,c
        or $80
        ld (hl),a
        ld c,a
        ; the flip: ring address, code, bank (the phase), colour
        ld a,(nflip)
        cp NFLIPMAX
        ret nc
        ld hl,(entptr)
        ld de,(m_ring)
        ld (hl),e
        inc hl
        ld a,d
        or VIDEO >> 8
        ld (hl),a
        inc hl
        ld (hl),c
        inc hl
        ld a,(phase)
        ld (hl),a
        inc hl
        ex de,hl
        ld a,c
        and $7F
        ld hl,(m_inkb)          ; its ink at this phase
        or l
        ld l,a
        ld a,(hl)
        ld (de),a
        inc de
        inc de
        ld (entptr),de
        ld hl,nflip             ; (never past NFLIPMAX: the list is long enough)
        inc (hl)
        ld a,c                  ; does its ink change across, or down?
        and $7F
        ld l,a
        ld h,M_SLFL >> 8
        ld a,(hl)
        and $18
        ld c,a
        jr nz,.bits
        ld a,(m_colclr)         ; a column drawn afresh has no bits set
        or a
        ret nz
.bits:  ; this cell's two-ink bits
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
        ld h,M_COLMIX >> 8
        ld a,e
        and 7
        ld e,a
        ld d,bitmask >> 8
        ld a,e
        add a,bitmask & 255
        ld e,a
        ld a,(de)
        ld e,a
        bit 4,c
        jr z,.clr
        or (hl)
        ld (hl),a
        jr .v
.clr:   cpl
        and (hl)
        ld (hl),a
.v:     ld h,M_VMIX >> 8
        ld a,e
        bit 3,c
        jr z,.clv
        or (hl)
        ld (hl),a
        ret
.clv:   cpl
        and (hl)
        ld (hl),a
        ret
        ALIGN 8
bitmask: db 1,2,4,8,16,32,64,128

; forget the last quad (its slot may have gone since)
lq_reset:
        ld hl,0
        ld (m_lq),hl
        ld (m_lq+2),hl
        ret

; the ink table at this phase: m_inkb = (phase & 1) x 128, its page
ink_base:
        ld a,(phase)
        rrca
        ld l,a
        and $80
        ld (m_inkb),a
        ld a,l
        and $7F
        add a,M_SLINK >> 8
        ld (m_inkb+1),a
        ret
m_inkb: dw 0
m_lq:   ds 4                    ; the last quad looked up (C B E D), and its slot
m_lslot: db 0
m_colclr: db 0

; A = slot -> A = its ink at the present phase
sl_ink: ld l,a
        ld a,(phase)
        rrca
        ld h,a
        and $80
        or l
        ld l,a
        ld a,h
        and $7F
        add a,M_SLINK >> 8
        ld h,a
        ld a,(hl)
        ret

; A = ink -> A = the ink for the monitor in use (keeps BC, DE, HL)
monomap:
        push hl
        ld l,a
        ld a,(mono)
        or a
        ld a,l
        jr z,.r
        push de
        ld h,0
        ld de,monotab
        add hl,de
        ld a,(hl)
        pop de
.r:     pop hl
        ret
; what a monochrome monitor gets: three brightnesses
monotab: db 0,15,7,7,8,7,7,7,8,15,15,15,7,15,15,15

; ---------------------------------------------------------------------
;  the quad table. B, C, D, E = the quad -> HL = its entry, NZ; or Z if
;  it is not there
; ---------------------------------------------------------------------
qfind:  ld a,c
        rlca
        xor b
        ld l,a
        ld a,d
        rlca
        rlca
        xor l
        ld l,a
        ld a,e
        rlca
        rlca
        rlca
        xor l
        ld l,a                  ; low: b ^ c<<1 ^ d<<2 ^ e<<3 (rotated)
        ld a,b
        add a,c
        add a,d
        add a,e
        and 3
        add a,a
        add a,a
        add a,a                 ; high x 8
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add a,h
        add a,M_QTAB >> 8
        ld h,a
.p:     ld a,(hl)
        cp b
        jr nz,.nx
        inc l
        ld a,(hl)
        cp c
        jr nz,.adv
        inc l
        ld a,(hl)
        cp d
        jr nz,.adv
        inc l
        ld a,(hl)
        cp e
        jr nz,.adv
        ld a,l
        and $F8
        ld l,a
        or $FF                  ; NZ: found
        ret
.nx:    inc a                   ; an empty entry: not there
        ret z
.adv:   ld a,l
        and $F8
        add a,8
        ld l,a
        jr nc,.p
        inc h
        ld a,h
        cp (M_QTAB >> 8) + $20
        jr c,.p
        ld h,M_QTAB >> 8
        jr .p

; M_QINSERT: HL = records (a, b, c, d, ink, flags), B = how many
m_qinsert:
.l:     push bc
        push hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        call qfind              ; -> HL at a free entry (or the same quad)
        ex de,hl
        pop hl
        ld bc,4
        ldir
        inc hl
        inc hl
        push hl
        ld hl,(q_id)            ; its record
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        inc de
        ld (q_id),de
        xor a
        ld (hl),a               ; no slot
        inc hl
        ld (hl),a
        pop hl
        pop bc
        djnz .l
        ret

; M_QBUILD: HL = quad records (a, b, c, d, ink, flags), B = how many: each
; one's 136-byte record (12 pictures, 12 inks, flags) into the quad blocks
m_qbuild:
.l:     push bc
        push hl
        call rec_build
        ld hl,(q_id)
        call qdb_put            ; (engine) REC -> record (q_id)
        ld hl,(q_id)
        inc hl
        ld (q_id),hl
        pop hl
        ld de,6
        add hl,de
        pop bc
        djnz .l
        ret

; HL = a quad record: its pictures at the 12 phases (REC + phase x 10), its
; inks (REC + 120), its flags (REC + 132)
rec_build:
        ld de,sb_k
        ld bc,4
        ldir
        ld a,(hl)
        ld (rb_ink),a
        inc hl
        ld a,(hl)
        ld (REC+132),a
        ld hl,REC
        ld (sb_dst),hl
        xor a
        ld (sb_vi),a
.vi:    xor a
        ld (sb_y),a
.y:     ld a,(sb_vi)            ; the source line: y + 0, 3 or 7
        ld e,a
        ld d,0
        ld hl,voff
        add hl,de
        ld a,(sb_y)
        add a,(hl)
        ld hl,sb_k
        cp 10
        jr c,.top
        sub 10
        inc hl
        inc hl
.top:   add a,M_CGROW >> 8
        ld d,a
        ld e,(hl)
        inc hl
        ld a,(de)
        ld b,a
        ld e,(hl)
        ld a,(de)
        ld l,a
        ld h,b
        ld de,(sb_dst)
        ld a,h
        ld (de),a               ; shift 0
        ld a,e
        add a,10
        ld e,a
        add hl,hl
        add hl,hl
        ld a,h
        ld (de),a               ; 2 pixels
        ld a,e
        add a,10
        ld e,a
        add hl,hl
        add hl,hl
        ld a,h
        ld (de),a               ; 4
        ld a,e
        add a,10
        ld e,a
        add hl,hl
        add hl,hl
        ld a,h
        ld (de),a               ; 6
        ld hl,sb_dst
        inc (hl)
        ld a,(sb_y)
        inc a
        ld (sb_y),a
        cp 10
        jr c,.y
        ld a,(sb_dst)           ; the next vertical step: 40 on, less the 10
        add a,30
        ld (sb_dst),a
        ld a,(sb_vi)
        inc a
        ld (sb_vi),a
        cp 3
        jr c,.vi
        ; the inks
        ld a,(REC+132)
        bit 6,a
        jr nz,.mix
        ld a,(rb_ink)
        call monomap
        ld hl,REC+120
        ld b,12
.o:     ld (hl),a
        inc hl
        djnz .o
        ret
.mix:   ld a,(rb_ink)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; x 12
        ld de,M_MIXINK
        add hl,de
        ld de,REC+120
        ld b,12
.m:     ld a,(hl)
        call monomap
        ld (de),a
        inc hl
        inc de
        djnz .m
        ret

; M_TABINIT: the quad table empty, every slot free, the phase table
m_tabinit:
        ld hl,M_QTAB
        ld de,M_QTAB+1
        ld bc,$2000-1
        ld (hl),$FF
        ldir
        ld hl,M_SLE
        ld de,M_SLE+1
        ld bc,$FF
        ld (hl),0
        ldir
        call slots_reset
        ld hl,M_PH1280
        ld de,SLOTPAT
        ld b,NPH
.ph:    ld (hl),e
        inc l
        ld (hl),d
        inc l
        ld a,d
        add a,5                 ; + 1280
        ld d,a
        djnz .ph
        ret

; every slot free and unused (the quads that had them lose them)
slots_reset:
        ld b,127
        ld c,1
.l:     ld l,c
        ld h,M_SLE >> 8
        ld e,(hl)
        set 7,l
        ld d,(hl)
        ld (hl),0
        res 7,l
        ld (hl),0
        ld a,d
        or a
        jr z,.n
        ld a,e
        or 6
        ld e,a
        xor a
        ld (de),a
.n:     inc c
        djnz .l
        ld hl,M_SLREF
        ld de,M_SLREF+1
        ld bc,127
        ld (hl),0
        ldir
        ld hl,M_FREEQ           ; the ring of free slots: 1..127
        ld b,127
        ld a,1
.f:     ld (hl),a
        inc l
        push hl
        ld l,a                  ; (bit 0 of its flags: it is in the ring)
        ld h,M_SLFL >> 8
        ld (hl),1
        pop hl
        inc a
        djnz .f
        xor a
        ld (fq_head),a
        ld a,127
        ld (fq_tail),a
        xor a
        ld (nload),a
        ld hl,M_COLMIX
        ld de,M_COLMIX+1
        ld bc,255
        ld (hl),0
        ldir
        ld hl,M_VMIX
        ld de,M_VMIX+1
        ld bc,255
        ld (hl),0
        ldir
        xor a                   ; slot 0 (empty): no ink, no flags
        ld (M_SLFL),a
        ld hl,M_SLINK
        ld b,6
.k:     ld (hl),a
        set 7,l
        ld (hl),a
        res 7,l
        inc h
        djnz .k
        ret

; ---------------------------------------------------------------------
;  slots
; ---------------------------------------------------------------------
; B = slot: one fewer cell shows it
slot_dec:
        ld l,b
        ld h,M_SLREF >> 8
        dec (hl)
        ret nz
slot_free:                      ; B = slot, shown nowhere: to the free ring
        ld l,b                  ; (once)
        ld h,M_SLFL >> 8
        bit 0,(hl)
        ret nz
        set 0,(hl)
        ld a,(fq_tail)          ; none: it may be reused
        ld l,a
        ld h,M_FREEQ >> 8
        ld (hl),b
        inc a
        ld (fq_tail),a
        ret

; (m_ent) = quad entry: give it a slot -> A = the slot (0 if none was free)
slot_alloc:
.pop:   ld a,(fq_head)
        ld hl,fq_tail
        cp (hl)
        jr z,.none
        ld l,a
        ld h,M_FREEQ >> 8
        ld c,(hl)
        inc a
        ld (fq_head),a
        ld l,c
        ld h,M_SLFL >> 8
        res 0,(hl)              ; out of the ring
        ld h,M_SLREF >> 8
        ld a,(hl)
        or a
        jr nz,.pop              ; it was taken again since: not free
        ld h,M_SLE >> 8         ; the quad that had it loses it
        ld e,(hl)
        set 7,l
        ld d,(hl)
        ld a,d
        or a
        jr z,.fr
        ld a,e
        or 6
        ld e,a
        xor a
        ld (de),a
.fr:    ld de,(m_ent)
        ld (hl),d
        res 7,l
        ld (hl),e
        ld a,e
        or 6
        ld e,a
        ld a,c
        ld (de),a               ; the quad's slot
        push bc
        ld hl,(m_ent)           ; its record: pictures to SLOTPAT, inks to qd_tmp
        ld a,l
        or 4
        ld l,a
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        call qdb_load           ; (engine) C = slot
        pop bc
        push bc
        call slot_inks
        pop bc
        ld a,(nload)
        add a,UPLQ & 255
        ld l,a
        ld h,UPLQ >> 8
        ld (hl),c
        ld hl,nload
        inc (hl)
        ld a,c
        ret
.none:  ld hl,ovf_count
        inc (hl)
        xor a
        ret

; C = slot: its inks at the 12 phases (qd_tmp) to M_SLINK, its flags
slot_inks:
        ld a,(qd_tmp+12)
        ld l,c
        ld h,M_SLFL >> 8
        ld (hl),a
        ld de,qd_tmp
        ld h,M_SLINK >> 8
        ld b,6
.m:     ld a,(de)
        ld (hl),a
        inc de
        set 7,l
        ld a,(de)
        ld (hl),a
        inc de
        res 7,l
        inc h
        djnz .m
        ret

voff:   db 0,3,7

; ---------------------------------------------------------------------
;  M_MIXED: the phase changed: the cells on show whose quad's ink changes
;  with it get their colour again (colour flips): those whose ink changes
;  across (M_COLMIX) - and, if the vertical step changed, those whose ink
;  changes down (M_VMIX)
; ---------------------------------------------------------------------
m_mixed:
        ; the rows on show, camrow .. camrow+23, as a mask of 32 bits (from
        ; a table), put into the AND instructions below
        ld a,(camrow)
        and 31
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,mx_masks
        add hl,de
        ld a,(hl)
        ld (mxh0+1),a
        ld (mxv0+1),a
        inc hl
        ld a,(hl)
        ld (mxh1+1),a
        ld (mxv1+1),a
        inc hl
        ld a,(hl)
        ld (mxh2+1),a
        ld (mxv2+1),a
        inc hl
        ld a,(hl)
        ld (mxh3+1),a
        ld (mxv3+1),a
        ; world row -> screen offset, for the rows on show (if they moved)
        ld a,(camrow)
        ld hl,mx_lrow
        cp (hl)
        jr z,.rs
        ld (hl),a
        ld b,a
        add a,a
        add a,rowoff & 255
        ld e,a
        ld d,rowoff >> 8
        ld a,32
        sub b
        cp PFROWS
        jr c,.rn
        ld a,PFROWS
.rn:    add a,a
        ld c,a
        ld b,0
        ld hl,ROW40
        ldir
.rs:
        ; the ink table at this phase
        ld a,(phase)
        rrca
        ld b,a
        and $80
        ld (mxil+1),a
        ld a,b
        and $7F
        add a,M_SLINK >> 8
        ld (mxih+1),a
        ld a,(oldphase)         ; and at the old one (no flip if it is the same)
        rrca
        ld b,a
        and $80
        ld (mxol+1),a
        ld a,b
        and $7F
        add a,M_SLINK >> 8
        ld (mxoh+1),a
        ; the flip list
        exx
        ld hl,(centptr)
        ld a,(ncflip)
        ld b,a
        ld a,NCFLIPMAX + 1
        sub b
        ld b,a
        exx
        ld hl,(camcell)
        ld (m_x),hl
        ld a,(camrow)
        ld (m_r),a
        call ring_of
        ld (mx_ring),hl
        ld a,(camcell)
        and 63
        add a,a
        add a,a
        ld l,a
        ld h,M_COLMIX >> 8
        ld b,COLS
        ld a,(oldphase)
        ld c,a
        ld a,(phase)
        xor c
        and $0C
        jp nz,mx_vcol
; the step across changed only: the cells whose ink changes across
mx_hcol: ld a,(hl)
mxh0:   and 0
        call nz,mx_b0
        inc l
        ld a,(hl)
mxh1:   and 0
        call nz,mx_b1
        inc l
        ld a,(hl)
mxh2:   and 0
        call nz,mx_b2
        inc l
        ld a,(hl)
mxh3:   and 0
        call nz,mx_b3
        inc l
        call mx_nextcol
        djnz mx_hcol
        jp mx_end
; and down
mx_vcol: ld a,(hl)
        inc h
        or (hl)
        dec h
mxv0:   and 0
        call nz,mx_b0
        inc l
        ld a,(hl)
        inc h
        or (hl)
        dec h
mxv1:   and 0
        call nz,mx_b1
        inc l
        ld a,(hl)
        inc h
        or (hl)
        dec h
mxv2:   and 0
        call nz,mx_b2
        inc l
        ld a,(hl)
        inc h
        or (hl)
        dec h
mxv3:   and 0
        call nz,mx_b3
        inc l
        call mx_nextcol
        djnz mx_vcol
        jp mx_end
        ASSERT M_VMIX == M_COLMIX + $100 * ((M_VMIX - M_COLMIX) / $100)

mx_end: exx
        ld (centptr),hl
        ld a,NCFLIPMAX + 1
        sub b
        ld (ncflip),a
        exx
        ret

; a poll of the blanking in the map's loops: if the middle blanking has
; just begun, the slots waiting go to the PCG now (keeps BC, DE)
mpoll:  call vpoll
        ld a,(fields)
        dec a
        ret nz
        ld a,(nload)
        or a
        ret z
        in a,(P_CRTCA)
        and $20
        ret z
        push bc
        push de
        ld a,UP_BLANK           ; as many as the blanking has room for
        ld (up_max),a
        call m_upload
        pop de
        pop bc
        ret
UP_BLANK EQU 4

mx_nextcol:
        ld a,b                  ; a poll every fourth column
        and 3
        ret nz
        push hl
        call mpoll
        pop hl
        ret

; A = a byte of a column's bits (rows 0-7, 8-15 ...): each one set gets a
; colour flip with its quad's ink at the new phase. The flip list's pointer
; is HL' and its room left B' (all through the pass).
mx_b0:  ld c,rowoff & 255
        jr mx_bits
mx_b1:  ld c,(rowoff & 255) + 16
        jr mx_bits
mx_b2:  ld c,(rowoff & 255) + 32
        jr mx_bits
mx_b3:  ld c,(rowoff & 255) + 48
mx_bits:
        push bc
        push hl
        ld e,a
        ld a,c
        ld (mxrb+1),a
        ld a,COLS               ; the column: COLS - columns left
        sub b
        ld b,e                  ; the set bits left
        ld hl,(mx_ring)         ; its ring address at camrow
        add a,l
        ld e,a
        ld a,h
        adc a,0
        and 7
        ld d,a
mxb_bit:
        ld l,b
        ld h,M_LSB >> 8
        ld a,(hl)               ; the lowest one
        add a,a
mxrb:   add a,0
        ld l,a
        ld h,rowoff >> 8
        ld a,(hl)               ; its row's offset on the screen
        inc l
        ld h,(hl)
        ld l,a
        add hl,de
        ld a,h
        and 7
        ld h,a                  ; its ring address
        push hl
        or SCRSH >> 8
        ld h,a
        ld a,(hl)               ; the slot it shows
        and $7F
        ld c,a
mxil:   or 0                    ; its ink at this phase
        ld l,a
mxih:   ld h,0
        ld a,c
        ld c,(hl)
mxol:   or 0                    ; and at the last
        ld l,a
mxoh:   ld h,0
        ld a,(hl)
        cp c
        jr z,mxb_same
        ld a,c
        exx
        pop de
        dec b
        jr z,mxb_full
        ld (hl),e
        inc hl
        ex af,af'
        ld a,d
        or PCGWIN >> 8
        ld (hl),a
        inc hl
        ex af,af'
        ld (hl),a
        inc hl
        inc hl
        exx
mxb_next:
        ld a,b
        dec a
        and b                   ; that bit off
        ld b,a
        jr nz,mxb_bit
        pop hl
        pop bc
        ret
mxb_same:
        pop hl
        jr mxb_next
mxb_full:  inc b
        exx
        pop hl
        pop bc
        ret
mx_ring: dw 0
mx_lrow: db $FF
mx_masks:                       ; camrow -> the rows on show, 32 bits
        db 255,255,255,0
        db 254,255,255,1
        db 252,255,255,3
        db 248,255,255,7
        db 240,255,255,15
        db 224,255,255,31
        db 192,255,255,63
        db 128,255,255,127
        db 0,255,255,255
        db 0,254,255,255
        db 0,252,255,255
        db 0,248,255,255
        db 0,240,255,255
        db 0,224,255,255
        db 0,192,255,255
        db 0,128,255,255
        db 0,0,255,255
        db 0,0,254,255
        db 0,0,252,255
        db 0,0,248,255
        db 0,0,240,255
        db 0,0,224,255
        db 0,0,192,255
        db 0,0,128,255
        db 0,0,0,255
        db 0,0,0,254
        db 0,0,0,252
        db 0,0,0,248
        db 0,0,0,240
        db 0,0,0,224
        db 0,0,0,192
        db 0,0,0,128
        ALIGN 64
rowoff: ds 64                   ; world row -> its offset on the screen (x 40)

; ---------------------------------------------------------------------
;  M_QUEUE: the game's requests: X (2), row, n, kind, argument
;   0 clear n cell glyphs of row r from column X (and show them)
;   1 the floating log: its six cell glyphs at row r from column X
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
        jr z,.log
        jp .tile
.clear: ld l,(ix+0)
        ld h,(ix+1)
        ld (q_x),hl
        ld a,(ix+2)
        ld (q_r),a
        ld b,(ix+3)
.c1:    push bc
        xor a
        call q_put
        ld hl,(q_x)
        inc hl
        ld (q_x),hl
        pop bc
        djnz .c1
        ld b,(ix+3)
        jr .shown
.log:   ld l,(ix+0)
        ld h,(ix+1)
        ld (q_x),hl
        ld a,(ix+2)
        ld (q_r),a
        ld hl,M_LOGCG
        ld b,6
.l1:    push bc
        push hl
        ld a,(hl)
        call q_put
        ld hl,(q_x)
        inc hl
        ld (q_x),hl
        pop hl
        inc hl
        pop bc
        djnz .l1
        ld b,6
.shown: ; show the columns X-1 .. X+n-1, rows r-1 .. r
        ld l,(ix+0)
        ld h,(ix+1)
        dec hl
        inc b
        ld a,(ix+2)
        dec a
        ld c,a
        ld a,2
        call q_area
.nextop:
        ld de,6
        add ix,de
        pop bc
        dec b
        jp nz,.op
        xor a
        ld (nmapq),a
        ret
.tile:  ld a,(ix+5)             ; the tile's four cell glyphs: TL TR BL BR
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,M_TCELL
        add hl,de
        ld de,tq_cells
        ld bc,4
        ldir
        ld l,(ix+0)
        ld h,(ix+1)
        add hl,hl               ; cell column
        ld (q_x),hl
        ld a,(ix+2)
        add a,a
        ld (q_r),a
        ld a,(tq_cells)
        call q_put              ; TL (x, r)
        ld hl,(q_x)
        inc hl
        ld (q_x),hl
        ld a,(tq_cells+1)
        call q_put              ; TR (x+1, r)
        ld hl,q_r
        inc (hl)
        ld a,(tq_cells+3)
        call q_put              ; BR (x+1, r+1)
        ld hl,(q_x)
        dec hl
        ld (q_x),hl
        ld a,(tq_cells+2)
        call q_put              ; BL (x, r+1)
        ; the 3 x 3 cells around it
        ld l,(ix+0)
        ld h,(ix+1)
        add hl,hl
        dec hl
        ld a,(ix+2)
        add a,a
        dec a
        ld c,a
        ld b,3
        ld a,3
        call q_area
        jp .nextop
tq_cells: ds 4
q_x:    dw 0
q_r:    db 0

; A = cell glyph for (q_x, q_r) in the map
q_put:  ld hl,(q_x)
        ld (m_x),hl
        ld e,a
        ld a,(q_r)
        ld (m_r),a
        ld a,e
        jp cg_put               ; (engine)

; HL = first column, B = columns, C = first row, A = rows: the cells of
; that area that are on show are worked out again
q_area: ld (qa_rows),a
        ld a,c
        ld (qa_r0),a
.c:     push bc
        push hl
        ld (m_x),hl
        ld de,(camcell)         ; on show across?
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.nc
        ld a,l
        cp COLS
        jr nc,.nc
        ld a,(qa_r0)
        ld (m_r),a
        ld a,(qa_rows)
        ld b,a
.r:     push bc
        ld a,(camrow)
        ld b,a
        ld a,(m_r)
        sub b
        cp PFROWS
        call c,cell_redo
        ld hl,m_r
        inc (hl)
        pop bc
        djnz .r
.nc:    pop hl
        inc hl
        pop bc
        djnz .c
        ret
qa_rows: db 0
qa_r0:  db 0

; (m_x, m_r) on show: work its quad out again from the map
cell_redo:
        call cg_quad            ; (engine) B, C, D, E = the four cell glyphs
        push bc
        push de
        call ring_of
        ld (m_ring),hl
        pop de
        pop bc
        call lq_reset
        ld a,1
        ld (m_cnt),a
        jp m_cell

; ---------------------------------------------------------------------
;  M_PLAT: a floating log at world pixel column (m_x) VZ pixels, cell row
;  (m_r): its cells, shifted by its pixels within the cell, as flips that
;  override the scroll's bank (and code) for this frame.  (Not yet used.)
; ---------------------------------------------------------------------
m_platcells:
        ret

; ---------------------------------------------------------------------
;  M_RESTORES. A sprite's cell over solid ground keeps the ground's ink;
;  the cells last frame's sprites covered and this frame's do not go back
;  to the background (flips after the sprites')
; ---------------------------------------------------------------------
m_restores:
        ld a,(nslots)
        or a
        jr z,.r0
        ld b,a
        ld ix,(sprstart)
.f:     ld l,(ix+0)
        ld a,(ix+1)
        and 7
        or SCRSH >> 8
        ld h,a
        ld a,(hl)
        and $7F
        jr z,.fn
        ld l,a
        ld h,M_SLFL >> 8
        bit 5,(hl)
        jr z,.fn
        call sl_ink
        ld (ix+4),a
.fn:    ld de,6
        add ix,de
        djnz .f
.r0:    ld a,(nold)
        or a
        ret z
        ld b,a
        ld hl,(oldlist)
.o:     push bc
        inc hl
        inc hl
        ld e,(hl)               ; its ring offset
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld (m_ring),de
        ld hl,(sstart)          ; its place on the screen now
        ex de,hl
        or a
        sbc hl,de
        call ringw
        ld de,COLS
        or a
        sbc hl,de
        jr c,.skip              ; in the status line
        ld de,COLS*PFROWS
        sbc hl,de
        jr nc,.skip             ; off the screen
        add hl,de               ; (undo): + 40 = the screen index
        ld de,COLS
        add hl,de
        ld de,CELLMAP
        add hl,de
        ld a,(hl)
        or a
        jr nz,.skip             ; a sprite is on it this frame
        ld hl,(nflip)
        ld de,NFLIPMAX
        or a
        sbc hl,de
        jr nc,.skip
        ld hl,(m_ring)
        ld a,h
        or SCRSH >> 8
        ld h,a
        ld a,(hl)
        ld c,a                  ; its code
        and $7F
        call sl_ink
        ld hl,(entptr)
        ld de,(m_ring)
        ld (hl),e
        inc hl
        ld e,a
        ld a,d
        or VIDEO >> 8
        ld (hl),a
        inc hl
        ld (hl),c
        inc hl
        ld a,(phase)
        ld (hl),a
        inc hl
        ld (hl),e
        inc hl
        inc hl
        ld (entptr),hl
        ld hl,(nflip)
        inc hl
        ld (nflip),hl
.skip:  pop hl
        pop bc
        dec b
        jp nz, .o
        ret

; ---------------------------------------------------------------------
;  M_PRESENT. The new quads' pictures and the sprites' glyphs go to the
;  PCG in the middle blanking of the frame's two fields, if they are ready
;  by then; the frame itself is shown at the second blanking: the start
;  address, every cell's bank (if the phase changed), the colours, the
;  cells. 25 frames a second.
; ---------------------------------------------------------------------
; M_PRESENT (the frame is built): the new slots' and the sprites' glyphs
; to the PCG in the middle blanking, if it is not past; then the game's
; logic runs, and M_SHOW puts the frame on show in the next blanking.
m_present:
        call snd_tick
        xor a
        ld (bl_edge),a
        ld (lateblast),a
        call vpoll              ; a blanking just begun is counted now
        ld a,(nslots)
        ld hl,nload
        or (hl)
        ret z
        ld a,(fields)
        or a
        jr nz,.f1
        call snd_wait           ; to the middle blanking
        call m_upload
        jp blast
.f1:    dec a
        jr nz,.late
        in a,(P_CRTCA)
        and $20
        jr z,.late
        call m_upload           ; it has begun: there is still time
        jp blast
.late:  ld a,1
        ld (lateblast),a
        ret

m_show: ld a,(fields)
        ld (pr_f0),a
        call vpoll
.vis:   ld a,(fields)
        cp 2
        jr nc,.over
.w:     call snd_wait
        ld a,(fields)
        cp 2
        jr c,.w
        jr .show
.over:  ld hl,perf_late
        inc (hl)
        ld a,(bl_edge)
        or a
        jr nz,.show
        ld a,(pr_f0)            ; the second blanking began just now: use it
        ld hl,fields
        cp (hl)
        jr nz,.show
        call snd_wait
.show:  ld a,(lateblast)
        or a
        jr z,.nb
        call m_upload
        call blast
.nb:    call set_start
        ld a,(hud_dirty)
        or a
        call nz,m_hudput
        ld a,(sdirty)
        or a
        call nz,m_fill
        xor a
        ld (sdirty),a
        call do_cflips
        call do_flips
        xor a
        ld (fields),a
        ld a,$20
        ld (vlast),a
        ret

pr_f0:  db 0

set_start:
        ld a,12
        out (P_CRTCA),a
        ld a,(sstart+1)
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        ld a,(sstart)
        out (P_CRTCD),a
        ret

; the slots waiting: their 12 pictures to PCG banks 0-11
m_upload: jp e_upload

; every playfield cell's bank = the phase (a run of PUSHes; the ring may
; wrap in the middle)
m_fill: xor a
        out (P_COLCTL),a
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(phase)
        ld d,a
        ld e,a
        ld hl,(sstart)
        ld bc,COLS
        add hl,bc
        call ringw
        ld (fl_end),hl          ; first cell
        ld bc,COLS*PFROWS
        add hl,bc               ; one past the last (may be past the ring)
        ld a,h
        cp RING >> 8
        jr c,.one
        ; two runs: [first, 2048) and [0, end - 2048)
        push hl
        ld bc,-RING
        add hl,bc
        ld b,h
        ld c,l                  ; end of the second run
        ld hl,0
        call fill_run
        pop hl
        ld hl,RING
.one:   ld b,h
        ld c,l
        ld hl,(fl_end)
        call fill_run
        ld a,LV_SCREEN
        out (P_LV),a
        ret

; HL = first ring cell, BC = one past the last: fill with DE
fill_run:
        ld a,c                  ; an odd end: its last cell by itself
        and 1
        jr z,.e
        dec bc
        push hl
        ld h,b
        ld l,c
        ld a,h
        or VIDEO >> 8
        ld h,a
        ld (hl),e
        pop hl
.e:     ld a,l                  ; an odd start: its first cell
        and 1
        jr z,.s
        push hl
        ld a,h
        or VIDEO >> 8
        ld h,a
        ld (hl),e
        pop hl
        inc hl
.s:     ld a,b                  ; pushes = (end - start) / 2
        sub h
        ld h,a
        ld a,c
        sub l
        ld l,a
        jr nc,.s1
        dec h
.s1:    srl h
        rr l
        ld a,h
        or l
        ret z
        push hl                 ; pushes
        ld a,b
        or VIDEO >> 8
        ld h,a
        ld l,c
        pop bc
        ld (savesp),sp
        ld sp,hl
        ld hl,push_end          ; enter the run of pushes that many from its end
        or a
        sbc hl,bc
        jp (hl)
push_run:
        REPT 512
        push de
        ENDR
push_end:
        ld sp,(savesp)
        ret

; the colour flips: address (in the colour window), colour
do_cflips:
        ld a,(ncflip)
        or a
        ret z
        ld b,a
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld (savesp),sp
        ld sp,CFLIPL
.l:     pop hl
        pop de
        ld (hl),e
        djnz .l
        ld sp,(savesp)
        xor a
        out (P_COLCTL),a
        ret

; the flips: address, code, bank, colour
do_flips:
        ld hl,(nflip)
        ld a,h
        or l
        ret z
        dec hl
        ld a,h
        inc hl
        ld ixh,a
        ld a,l
        ld ixl,a
        ld (savesp),sp
        ld sp,FLIPL
        ld a,COL_ON
        out (P_COLCTL),a
        ld c,P_LV
        ld b,LV_SCREEN
        ld a,LV_ATTR
.lp:    pop hl
        pop de
        out (c),b
        ld (hl),e
        out (c),a
        ld (hl),d
        set 3,h
        pop de
        ld (hl),e
        dec ixl
        jp nz,.lp
        dec ixh
        jp p,.lp
        ld sp,(savesp)
        xor a
        out (P_COLCTL),a
        ld a,LV_SCREEN
        out (P_LV),a
        ret

; M_HUDPUT: the status line (row 0): codes, banks, colours (in the blanking)
m_hudfull:
        ld a,2
        ld (hud_dirty),a
m_hudput:
        ld a,(hud_dirty)
        ld (hp_how),a
        xor a
        ld (hud_dirty),a
        ld hl,(sstart)          ; the ring may wrap within the line: two runs
        ld b,COLS
        ld a,h
        cp 7
        jr c,.one
        ld a,l
        neg
        jr z,.one
        cp COLS
        jr nc,.one
        ld b,a
.one:   ld a,b
        ld (hp_n1),a
        ld c,0
        call hp_run
        ld a,(hp_n1)
        cp COLS
        jr z,.done
        ld c,a
        neg
        add a,COLS
        ld b,a
        ld hl,0
        call hp_run
.done:  ld a,(hp_how)           ; banks: all after a row step, the ends after
        bit 1,a                 ; a column step
        jr nz,.done2
        and 1
        jr z,.done2
        ld a,LV_ATTR
        out (P_LV),a
        ld hl,(sstart)
        call hp_bank
        inc hl
        call hp_bank
        ld de,COLS-3
        add hl,de
        call hp_bank
        inc hl
        call hp_bank
.done2: ld a,LV_SCREEN
        out (P_LV),a
        ret
hp_bank: push hl
        call ringw
        ld a,h
        or VIDEO >> 8
        ld h,a
        ld (hl),BK_HUD
        pop hl
        ret
hp_n1:  db 0
hp_how: db 0
hp_v:   dw 0
; HL = ring, C = the first of HUDBUF's cells, B = how many: codes, colours
; (and banks after a row step)
hp_run: ld a,h
        or VIDEO >> 8
        ld h,a
        ld (hp_v),hl
        ex de,hl
        ld a,LV_SCREEN
        out (P_LV),a
        ld h,HUDBUF >> 8
        ld a,c
        add a,HUDBUF & 255
        ld l,a
        push bc
        ld c,b
        ld b,0
        ldir
        pop bc
        ld a,(hp_how)
        bit 1,a
        jr z,.nb
        ld a,LV_ATTR
        out (P_LV),a
        ld hl,(hp_v)
        push bc
.a:     ld (hl),BK_HUD
        inc hl
        djnz .a
        pop bc
.nb:    ld a,LV_ATTR
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld hl,(hp_v)
        set 3,h
        ex de,hl
        ld h,HUDCOL >> 8
        ld a,c
        add a,HUDCOL & 255
        ld l,a
        ld c,b
        ld b,0
        ldir
        xor a
        out (P_COLCTL),a
        ret

; M_PCGCLEAR: code 80h (the empty quad) empty in every scroll bank
m_pcgclear:
        xor a
        out (P_COLCTL),a
        ld c,0
.b:     ld a,c
        or LV_SCREEN
        out (P_LV),a
        ld hl,PCGWIN
        ld b,16
.z:     ld (hl),0
        inc hl
        djnz .z
        inc c
        ld a,c
        cp 16
        jr nz,.b
        ld a,LV_SCREEN
        out (P_LV),a
        ret

; M_CGSCATTER: HL = n cell glyphs (10 bytes each), B = n: to M_CGROW
m_cgscatter:
        ld c,0
.g:     push bc
        ld d,M_CGROW >> 8
        ld e,c
        ld b,10
.r:     ld a,(hl)
        ld (de),a
        inc hl
        inc d
        djnz .r
        pop bc
        inc c
        djnz .g
        ret

; ---------------------------------------------------------------------
;  M_SNAP: the whole picture at the camera, with the display off: every
;  slot freed, the ring empty, then every row of the playfield drawn
; ---------------------------------------------------------------------
m_snap: call slots_reset
        ld hl,SCRSH
        ld de,SCRSH+1
        ld bc,RING-1
        ld (hl),$80
        ldir
        xor a                   ; the ring: empty cells, bank 0, black
        out (P_COLCTL),a
        ld a,LV_SCREEN
        out (P_LV),a
        ld hl,VIDEO
        ld de,VIDEO+1
        ld bc,RING-1
        ld (hl),$80
        ldir
        ld a,LV_ATTR
        out (P_LV),a
        ld hl,VIDEO
        ld de,VIDEO+1
        ld bc,RING-1
        ld (hl),0
        ldir
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ld hl,PCGWIN
        ld de,PCGWIN+1
        ld bc,RING-1
        ld (hl),0
        ldir
        xor a
        out (P_COLCTL),a
        ld hl,0
        ld (org),hl
        ld hl,$7000             ; requests still waiting change the map only
        ld (camcell),hl
        ld a,$80
        ld (camrow),a
        call list_reset
        call m_queue
        ; the camera's place
        ld hl,(camy)
        ld h,DIV10 >> 8
        ld b,(hl)
        inc h
        ld e,(hl)
        ld d,0
        ld hl,qv_tab
        add hl,de
        ld a,(hl)
        and $0F
        add a,a
        add a,a
        ld c,a
        ld a,(hl)
        rlca
        rlca
        rlca
        rlca
        and 1
        add a,b
        ld (camrow),a
        ld hl,(camx)
        ld a,l
        and 3
        or c
        ld (phase),a
        call ink_base
        srl h
        rr l
        srl h
        rr l
        ld (camcell),hl
        call new_start
        ld a,(camrow)
        ld b,PFROWS
.r:     push bc
        push af
        call list_reset
        pop af
        push af
        call row_draw
        call m_upload
        call do_flips
        pop af
        inc a
        pop bc
        djnz .r
        call list_reset
        ld a,1
        ld (sdirty),a
        call m_fill
        xor a
        ld (sdirty),a
        call m_hudfull
        jp set_start

mapcode_end:
        ASSERT mapcode_end <= M_CGROW

        ORG M_LSB
	db 0,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0,4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db 5,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0,4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db 6,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0,4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db 5,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0,4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db 7,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0,4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db 5,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0,4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db 6,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0,4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db 5,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0,4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
        ORG M_HUDG
        INCBIN "../build/hudg.bin"
        ORG M_FONT
        INCBIN "../build/font.bin"
map_end2:
        SAVEBIN "../build/MAP.BNK",0,map_end2
