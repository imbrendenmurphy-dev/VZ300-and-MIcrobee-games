; Experimental single-page 40x32 transfer backend, not yet linked into GAME.
; HL = prepared row-run stream in currently mapped RAM.
; Record: count (1..40), screen address, codes[count], banks[count], colours[count].
; Zero count ends. Runs must be sorted in ascending display order.
; Begin at vertical blank, then stay ahead of the next frame's scanout.

native32_delta:
            xor a
            out ($0B),a
            out ($08),a
            ld a,$80
            out ($1C),a
            push hl
            call wait_frame
            pop hl
.run:       ld a,(hl)
            inc hl
            or a
            ret z
            ld (native32_delta_count),a
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            push de
            ld c,a
            ld b,0
            ldir
            pop de
            push de
            ld a,$90
            out ($1C),a
            ld a,(native32_delta_count)
            ld c,a
            ld b,0
            ldir
            pop de
            ld a,d
            add a,8
            ld d,a
            ld a,$80
            out ($1C),a
            ld a,$40
            out ($08),a
            ld a,(native32_delta_count)
            ld c,a
            ld b,0
            ldir
            xor a
            out ($08),a
            jr .run
native32_delta_count: db 0
