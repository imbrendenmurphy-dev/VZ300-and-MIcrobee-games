; Bank-27 native terrain-edit bridge. MASK remains the authoritative collision
; map (512x80 logical pixels). Each logical pixel is 2x2 native pixels, below
; a 64-pixel sky. Dirty world cells are persistent until st_init.
;
; st_mark: DE=logical x, C=logical y; preserves AF/BC/DE/HL.
; st_jobs: HL=camera (0..384), DE=19-byte job buffer, A=mono (0/1).
;          Returns A=number of jobs, carry set if >32 cells are visible.
;          Preserves BC/DE/HL/IX/IY. Caller must not present on overflow.
;          A repeated call reuses the output buffer until a mark/camera/mode
;          change. Call st_invalidate if another routine overwrites the buffer.
; Visible edited cells are rendered as distinct solid/air silhouettes; this
; deliberately replaces scenery within changed cells. Colour=63h / mono=0Fh.
; The 160-byte permanent bitset at 6800h marks 128x10 world cells. A dirty
; cell can straddle two viewport cells on fine scroll. Job lookup deduplicates
; adjacent world cells. This design is bounded, not a full-campaign editor.
ST_DIRTY EQU $6800

st_init:
        push af : push bc : push de : push hl
        ld hl,ST_DIRTY : ld de,ST_DIRTY+1 : ld bc,159
        xor a : ld (hl),a : ldir : ld (st_any),a : ld (st_valid),a
        pop hl : pop de : pop bc : pop af : ret

st_invalidate:
        push af : xor a : ld (st_valid),a : pop af : ret

st_mark:
        push af : push bc : push de : push hl
        ; row/8 * 16 + x/32, where x is a nine-bit value.
        ld a,e : rrca : rrca : rrca : rrca : rrca : and 7 : ld b,a
        ld a,d : and 1 : rlca : rlca : rlca : or b : ld b,a
        ld a,c : and $78 : add a,a : add a,b : ld l,a : ld h,$68
        ld a,e : rrca : rrca : and 7 : ld b,a
        push hl : ld hl,BITT : ld a,l : add a,b : ld l,a : ld a,(hl) : pop hl
        or (hl) : ld (hl),a : ld a,1 : ld (st_any),a : ld (st_changed),a
        pop hl : pop de : pop bc : pop af : ret

st_jobs:
        push bc : push de : push hl : push ix : push iy
        ld (st_newcamera),hl : ld (st_newbase),de : ld (st_newmono),a
        ld a,(st_valid) : or a : jr z,.rebuild
        ld a,(st_changed) : or a : jr nz,.rebuild
        ld hl,(st_camera) : ld de,(st_newcamera) : or a : sbc hl,de : jr nz,.rebuild
        ld hl,(st_base) : ld de,(st_newbase) : or a : sbc hl,de : jr nz,.rebuild
        ld a,(st_newmono) : ld hl,st_mono : cp (hl) : jp z,st_return
.rebuild:
        ld hl,(st_newcamera) : ld (st_camera),hl
        ld de,(st_newbase) : ld (st_base),de : ld (st_tail),de
        ld a,(st_newmono) : ld (st_mono),a
        xor a : ld (st_count),a : ld (st_overflow),a
        ld a,(st_any) : or a : jr z,st_done
        xor a : ld (st_row),a : ld (st_byte),a
.byte: ld a,(st_row) : rlca : rlca : rlca : rlca
        ld b,a : ld a,(st_byte) : add a,b : ld l,a : ld h,$68
        ld a,(hl) : or a : jr z,.nextbyte
        ld (st_bits),a : xor a : ld (st_bit),a
.bit:  ld a,(st_bits) : and $80 : call nz,st_world_cell
        ld a,(st_bits) : add a,a : ld (st_bits),a
        ld a,(st_bit) : inc a : ld (st_bit),a : cp 8 : jr nz,.bit
.nextbyte:
        ld a,(st_byte) : inc a : ld (st_byte),a : cp 16 : jr nz,.byte
        xor a : ld (st_byte),a : ld a,(st_row) : inc a : ld (st_row),a
        cp 10 : jr nz,.byte
st_done:
        ld a,1 : ld (st_valid),a : xor a : ld (st_changed),a
st_return:
        pop iy : pop ix : pop hl : pop de : pop bc
        ld a,(st_overflow) : or a : jr z,.ok
        ld a,(st_count) : scf : ret
.ok:   ld a,(st_count) : or a : ret

; The 8-pixel world cell starts at column*8. Find the one or two viewport
; columns it intersects; arithmetic shift handles a partially clipped left edge.
st_world_cell:
        ld a,(st_byte) : add a,a : add a,a : add a,a
        ld b,a : ld a,(st_bit) : add a,b : ld l,a : ld h,0
        add hl,hl : add hl,hl : add hl,hl
        ld de,(st_camera) : or a : sbc hl,de
        ld a,l : and 7 : ld (st_phase),a
        ld a,h : bit 7,a : jr z,.positive
        cp $FF : ret nz : ld a,l : cp $F9 : ret c : jr .divide
.positive:
        cp 2 : jr c,.divide : ret nz : ld a,l : cp $80 : ret nc
.divide:
        sra h : rr l : sra h : rr l : sra h : rr l
        ld (st_col),hl : call st_try_cell
        ld a,(st_phase) : or a : ret z
        ld hl,(st_col) : inc hl : ld (st_col),hl
        jp st_try_cell

st_try_cell:
        ld hl,(st_col) : ld a,h : or a : ret nz
        ld a,l : cp 80 : ret nc
        ; viewport offset = (dirty row + 4) * 80 + viewport column.
        ld c,l : ld a,(st_row) : add a,4
        rlca : rlca : rlca : rlca : ld l,a : ld h,0
        ld e,l : ld d,h : add hl,hl : add hl,hl : add hl,de
        ld e,c : ld d,0 : add hl,de : ld (st_offset),hl
        ld de,(st_base) : ld a,(st_count) : or a : jr z,.append
        ld b,a
.find: ld hl,(st_offset) : ld a,(de) : cp l : jr nz,.next
        inc de : ld a,(de) : dec de : cp h : ret z
.next: ld hl,19 : add hl,de : ex de,hl : djnz .find
.append:
        ld a,(st_count) : cp 32 : jr c,.room
        ld a,1 : ld (st_overflow),a : ret
.room: inc a : ld (st_count),a
        ld hl,(st_tail) : ld de,(st_offset)
        ld (hl),e : inc hl : ld (hl),d : inc hl : ld (st_write),hl
        ; source x = camera + viewport column*8, then x/2 logical pixels.
        ld hl,(st_col) : add hl,hl : add hl,hl : add hl,hl
        ld de,(st_camera) : add hl,de
        ld a,l : and 1 : ld (st_odd),a
        srl h : rr l
        ld a,l : and 7 : ld (st_shift),a
        srl h : rr l : srl h : rr l : srl h : rr l
        ld a,l : ld (st_xbyte),a
        ld a,(st_row) : add a,a : add a,a : add a,a : ld (st_maskrow),a
        ld a,8 : ld (st_rows_left),a
.row:  ld a,(st_maskrow) : and 3 : rrca : rrca
        ld b,a : ld a,(st_xbyte) : or b : ld l,a
        ld a,(st_maskrow) : rrca : rrca : and $3F : add a,MASK>>8 : ld h,a
        ld d,(hl) : inc hl : ld e,(hl)
        ld a,(st_shift) : or a : jr z,.shifted : ld b,a
.shift: sla e : rl d : djnz .shift
.shifted:
        ld a,d : and $F0 : rrca : rrca : rrca : rrca
        ld l,a : ld h,0 : ld bc,st_expand : add hl,bc : ld a,(hl)
        ld b,a : ld a,(st_odd) : or a : ld a,b : jr z,.pixels
        add a,a : bit 3,d : jr z,.pixels : or 1
.pixels:
        ld hl,(st_write) : ld (hl),a : inc hl : ld (hl),a : inc hl
        ld (st_write),hl
        ld a,(st_maskrow) : inc a : ld (st_maskrow),a
        ld a,(st_rows_left) : dec a : ld (st_rows_left),a : jr nz,.row
        ld a,(st_mono) : or a : ld a,$63 : jr z,.colour : ld a,$0F
.colour: ld (hl),a : inc hl : ld (st_tail),hl : ret

st_expand: db $00,$03,$0C,$0F,$30,$33,$3C,$3F,$C0,$C3,$CC,$CF,$F0,$F3,$FC,$FF
st_any: db 0
st_valid: db 0
st_changed: db 0
st_newcamera: dw 0
st_newbase: dw 0
st_newmono: db 0
st_camera: dw 0
st_base: dw 0
st_tail: dw 0
st_write: dw 0
st_offset: dw 0
st_col: dw 0
st_mono: db 0
st_count: db 0
st_overflow: db 0
st_row: db 0
st_byte: db 0
st_bit: db 0
st_bits: db 0
st_phase: db 0
st_shift: db 0
st_odd: db 0
st_xbyte: db 0
st_maskrow: db 0
st_rows_left: db 0
