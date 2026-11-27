; ---------------------------------------------------------------------------
; Packs.  Everything is on the one disk and is read into the 1 MB banks through
; CP/M at start-up (src/bank.asm, load_assets), so by the time the game runs
; every pack is already in RAM.  (Earlier versions read packs from drives B-D
; with their own WD2793 code; on a Premium Plus with SD-card disk images that
; doesn't reach the drives, so it's gone.)
; ---------------------------------------------------------------------------

; A = pack.  Always there.
pack_need:
        ret

; Carry if pack A isn't in RAM (only if start-up couldn't read it).
pack_try:
        or a
        ret z
        ld b,a
        ld a,(packs_in)
.bit:   rrca
        djnz .bit
        ccf
        ret
