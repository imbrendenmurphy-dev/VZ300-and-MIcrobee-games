; =====================================================================
;  anim0.inc : table driven mode(0) animation player (512-byte frames)
;  Each section: db end_order, nframes, rate (1 = every frame, 2 = every
;  other frame), bank (0 main RAM, 1 SRAM bank 1), dw first frame
;  A frame is copied inside the music kernel ahead of the beam (tear free).
; =====================================================================
RC0     MACRO
        RASTC M0
        ENDM
SU_A0   MACRO
        SU_HLDE a0_src, VRAM
        ENDM

part_entry:
        ld a,(kernel_pairs)
        sub 44+1
        ld (a0_c2),a
        ld hl,sections
        ld (a0_sec),hl
        call a0_load
        call a0_logic
        call music_apply
a0_frame:
        FRAME_START a0_dummy
        SEG a0a, a0ax, RC0, 105, SU_A0, W_COPY, W_COPY, a0_c1
        SEG a0b, a0bx, RC0, 105, SU_NONE, W_IDLE, W_IDLE, a0_c2
        FRAME_END
        call a0_logic
        call music_apply
        ld a,(a0_done)
        or a
        jp z,a0_frame
        ld a,1
        out ($37),a
        ret

a0_c1:  db 43
a0_c2:  db 0
a0_dummy: dw 0
a0_done: db 0
a0_sec: dw 0
a0_src: dw 0
a0_end: db 0
a0_n:   db 0
a0_rate: db 1
a0_base: dw 0
a0_i:   db 0
a0_t:   db 0

a0_load:        ; load the section at (a0_sec)
        ld hl,(a0_sec)
        ld a,(hl)
        or a
        jr nz,.ok
        ld a,1
        ld (a0_done),a
        ret
.ok:    ld (a0_end),a
        inc hl
        ld a,(hl)
        ld (.nn),a
        inc hl
        ld a,(hl)
        ld (.rr),a
        inc hl
        ld a,(hl)               ; bank
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (a0_sec),hl
        or a
        ld a,1
        jr z,.mb
        ld a,(sram_ok)
        or a
        jr z,.keep              ; bank 1 unusable: keep showing the previous section
        ld a,3
.mb:    out ($37),a
        ld (a0_base),de
        ld a,(.nn)
        ld (a0_n),a
        ld a,(.rr)
        ld (a0_rate),a
        xor a
        ld (a0_i),a
        ld (a0_t),a
        ret
.keep:  ret
.nn:    db 0
.rr:    db 0

a0_logic:
        ld a,(m_ordnum)
        ld hl,a0_end
        cp (hl)
        jr c,.run
        call a0_load
        ld a,(a0_done)
        or a
        ret nz
.run:   ld hl,a0_t
        inc (hl)
        ld a,(a0_rate)
        cp (hl)
        jr nz,.same
        ld (hl),0
        ld a,(a0_i)
        inc a
        ld hl,a0_n
        cp (hl)
        jr c,.ok
        xor a
.ok:    ld (a0_i),a
.same:  ld a,(a0_i)
        add a,a
        ld h,a
        ld l,0                  ; *512
        ld de,(a0_base)
        add hl,de
        ld (a0_src),hl
        ret
