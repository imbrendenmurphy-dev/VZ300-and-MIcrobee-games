; =====================================================================
;  sprite.asm - clipped colour-key sprite blitter
;  Record: db wbytes, h, ax, ay, key ; then h rows of wbytes pixel bytes.
;  key 0: colour 0 is transparent (fast path: mask table only)
;  key 2: colour 2 is transparent (mask + clean tables)
;  Each sprite has two records: phase 0 and phase 1 (shifted right 2 px,
;  ax larger by 2), so any 2-pixel position is a byte-aligned copy.
;  Reads its source with POP under DI (a few hundred T at most).
; =====================================================================

; draw_sprite: HL = level entry (dw phase-0 record, dw phase-1 record)
;              in the current mapping; (spr_x), (spr_y) = anchor (signed 16-bit)
draw_sprite:
            push ix                 ; (the row loop uses IX)
            call .raw
            pop ix
            ret
.raw:       ld e,(hl)
            inc hl
            ld d,(hl)               ; DE = phase-0 record
            inc hl
            ex de,hl
            inc hl
            inc hl
            ld a,(spr_x)
            sub (hl)                ; x - ax
            dec hl
            dec hl
            bit 1,a
            jr z,.p0
            ex de,hl                ; phase 1: 2 pixels further right
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
.p0:        ; HL = chosen record
            ld a,(hl)
            ld (sp_wb),a
            inc hl
            ld a,(hl)
            ld (sp_h),a
            inc hl
            ld e,(hl)               ; ax
            inc hl
            ld c,(hl)               ; ay
            inc hl
            ld a,(hl)               ; key
            ld (sp_key),a
            inc hl
            ld (sp_src),hl
            ; left = x - ax (16-bit)
            ld hl,(spr_x)
            ld d,0
            or a
            sbc hl,de
            ; col = left >> 2 (arithmetic)
            sra h
            rr l
            sra h
            rr l
            ld (sp_col),hl
            ; top = y - ay
            ld hl,(spr_y)
            ld b,0
            or a
            sbc hl,bc
            ; ---- vertical clip against HUDROWS..63
            ld a,(sp_h)
            ld c,a                  ; C = rows
            ld b,0                  ; B = rows skipped at top
            ld a,h
            or a
            jp p,.tpos
            inc a
            jp nz,.off              ; top < -256
            jr .above
.tpos:      jp nz,.off              ; top >= 256
            ld a,l
            cp 64
            jp nc,.off
            cp HUDROWS
            jr nc,.topok
.above:     ; skip HUDROWS - top rows
            ld a,HUDROWS
            sub l
            ld b,a                  ; (top >= -255 assumed)
            ld a,c
            sub b
            ret c
            ret z
            ld c,a
            ld l,HUDROWS
.topok:     ; L = top row, C = rows, B = skipped rows
            ld a,l
            add a,c
            sub 64
            jr c,.botok
            jr z,.botok
            ld d,a
            ld a,c
            sub d
            ret c
            ret z
            ld c,a
.botok:     ld a,c
            ld (sp_rows),a
            ld a,l
            ld (sp_top),a

            ld hl,dirty_top
            cp (hl)
            jr nc,.nd
            ld (hl),a
.nd:        ; src += B * wb
            ld a,b
            or a
            jr z,.ns
            ld a,(sp_wb)
            ld e,b
            call mul_ae
            ex de,hl
            ld hl,(sp_src)
            add hl,de
            ld (sp_src),hl
.ns:        ; ---- horizontal clip: col (signed 16), wb
            ld hl,(sp_col)
            ld a,(sp_wb)
            ld c,a                  ; visible width
            ld b,0                  ; skipped bytes at left
            ld a,h
            or a
            jp m,.left
            jp nz,.off
            ld a,l
            cp 32
            jp nc,.off
            jr .lok
.left:      ; col < 0: skip -col bytes
            ld a,l
            neg
            ld b,a
            ld a,h
            inc a
            jp nz,.off              ; col < -255
            ld a,c
            sub b
            jp c,.off
            jp z,.off
            ld c,a
            ld l,0
.lok:       ld a,l
            add a,c
            sub 32
            jr c,.rok
            jr z,.rok
            ld d,a
            ld a,c
            sub d
            jp c,.off
            jp z,.off
            ld c,a
.rok:       ; L = first column, C = visible bytes, B = skipped bytes
            ld a,l
            ld (sp_c0),a
            ld a,b
            ld e,a
            ld d,0
            ld hl,(sp_src)
            add hl,de
            ld (sp_src),hl
            ; stride remainder for the source: wb - C (none: skip that step)
            ld a,(sp_wb)
            sub c
            ld (bl_srem+4),a        ; ld ix,nn operand low
            ld hl,$0818             ; jr +8 (over the IX/SP adjustment)
            jr z,.nos
            ld hl,0                 ; nop : nop
.nos:       ld (bl_srem),hl
            ; destination remainder: 32 - C
            ld a,c
            ld (bl_wrap+1),a
            ld a,32
            sub c
            ld (bl_drem+1),a
            ; destination address = BB + top*32 + col
            ld a,(sp_top)
            ld e,a
            ld d,0
            ex de,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,(sp_c0)
            add a,l
            ld l,a
            ld de,BB
            add hl,de
            push hl
            ; set up the unrolled entry for C bytes (C/2 pairs)
            ld a,c
            and $FE                 ; pairs * 2
            ld e,a
            ld d,0
            ld a,(sp_key)
            or a
            jr nz,.k2
            ld hl,bk0_ent
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld de,bk0_odd
            jr .e0
.k2:        ld hl,bk2_ent
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld de,bk2_odd
.e0:        ; HL = entry into pairs; odd -> go via the single-byte block
            bit 0,c
            jr z,.even
            ld a,(sp_key)
            or a
            jr nz,.o2
            ld (bk0_oddj+1),hl
            jr .oj
.o2:        ld (bk2_oddj+1),hl
.oj:        ex de,hl
.even:      ld (bl_entry+1),hl
            pop de                  ; DE = destination
            ld a,(sp_rows)
            exx
            ld b,a
            exx
            ld a,(sp_key)
            ld h,HIGH(MASK0)
            or a
            jr z,.go
            ld h,HIGH(MASK2)
.go:        di
            ld (bl_sp),sp
            ld sp,(sp_src)
            jp bl_entry
.off:       ret
bl_entry:   jp 0

; ---- key 0 (fast): mask table only
bk0_odd:    pop bc
            ld l,c
            ld a,(de)
            and (hl)
            or c
            ld (de),a
            inc e
            dec sp
bk0_oddj:   jp 0
bk0_pairs:
            REPT 8
            pop bc
            ld l,c
            ld a,(de)
            and (hl)
            or c
            ld (de),a
            inc e
            ld l,b
            ld a,(de)
            and (hl)
            or b
            ld (de),a
            inc e
            ENDR
bk0_pairs_end:
            jp bl_rowend
bk0_ent:    dw bk0_pairs_end,bk0_pairs_end-13,bk0_pairs_end-26,bk0_pairs_end-39,bk0_pairs_end-52
            dw bk0_pairs_end-65,bk0_pairs_end-78,bk0_pairs_end-91,bk0_pairs_end-104
bk2_ent:    dw bk2_pairs_end,bk2_pairs_end-17,bk2_pairs_end-34,bk2_pairs_end-51,bk2_pairs_end-68
            dw bk2_pairs_end-85,bk2_pairs_end-102,bk2_pairs_end-119,bk2_pairs_end-136

; ---- key 2: mask + clean tables (H = MASK2, H+1 = CLEAN2)
bk2_odd:    pop bc
            ld l,c
            ld a,(de)
            and (hl)
            inc h
            or (hl)
            dec h
            ld (de),a
            inc e
            dec sp
bk2_oddj:   jp 0
bk2_pairs:
            REPT 8
            pop bc
            ld l,c
            ld a,(de)
            and (hl)
            inc h
            or (hl)
            dec h
            ld (de),a
            inc e
            ld l,b
            ld a,(de)
            and (hl)
            inc h
            or (hl)
            dec h
            ld (de),a
            inc e
            ENDR
bk2_pairs_end:

bl_rowend:
bl_srem:    jr bl_drem              ; patched: "jr +8" or "nop : nop"
            ld ix,0                 ; source: skip the clipped bytes of this row
            add ix,sp
            ld sp,ix
            ld a,e                  ; the row ran off the end of a 256-byte page
bl_wrap:    cp 0                    ; (E < bytes drawn): INC E dropped the carry
            jr nc,bl_drem
            inc d
bl_drem:    ld a,32                 ; destination: next row
            add a,e
            ld e,a
            jr nc,.n
            inc d
.n:         exx
            dec b
            exx
            jp nz,bl_entry
            ld sp,(bl_sp)
            ld a,(intoff)           ; interrupts back on unless the ISR left them off
            or a
            ret nz
            ei
            ret

; HL = A * E (small unsigned)
mul_ae:
            ld hl,0
            ld d,0
            or a
            ret z
.l:         srl a
            jr nc,.s
            add hl,de
.s:         sla e
            rl d
            or a
            jr nz,.l
            ret
