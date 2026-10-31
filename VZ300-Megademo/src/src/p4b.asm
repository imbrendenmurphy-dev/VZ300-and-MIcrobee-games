; =====================================================================
;  PART 4b : 3D MADNESS II                        music orders 26..29
;  50fps semigraphics tunnel (24 pre-rendered frames copied inside the
;  music kernel ahead of the beam), then a shaded torus from SRAM bank 1.
; =====================================================================
        INCLUDE "ovl.inc"

P4B_END_ORDER EQU 30
WIN     EQU VRAM + 4*32 + 8

RC0     MACRO
        RASTC M0
        ENDM
SU_T    MACRO
        SU_HLDE srcp, VRAM
        ENDM
SU_W    MACRO
        SU_HLDE srcp, WIN
        ENDM

part_entry:
        ld a,(kernel_pairs)
        sub 44+1
        ld (t2),a
        ld a,(kernel_pairs)
        sub 39+97+1
        ld (w3),a
        ld hl,tunnel
        ld (srcp),hl
        call logic
        call music_apply
tframe:
        FRAME_START dummy
        SEG ta, tax, RC0, 105, SU_T, W_COPY, W_COPY, t1
        SEG tb, tbx, RC0, 105, SU_NONE, W_IDLE, W_IDLE, t2
        FRAME_END
        call logic
        call music_apply
        ld a,(sect)
        or a
        jp z,tframe
        ; ---- torus ----
        ld hl,bg
        ld de,VRAM
        ld bc,2048
        ld a,M1G
        call kcopy
        call logic
        call music_apply
wframe:
        FRAME_START wtab
        SEG wa, wax, RAST, 105, SU_NONE, W_IDLE, W_IDLE, w1
        SEG16 wb, wbx, SU_W, w2
        SEG wc, wcx, RAST, 105, SU_NONE, W_IDLE, W_IDLE, w3
        FRAME_END
        call logic
        call music_apply
        ld a,(sect)
        cp 1
        jp z,wframe
        ld a,1
        out ($37),a
        ret

t1:     db 43
t2:     db 0
w1:     db 38           ; copy starts at line 78
w2:     db 48
w3:     db 0
sect:   db 0
dummy:  dw 0
wtab:   dw rtab
srcp:   dw 0
anim:   db 0
pf:     dw 0

logic:
        ld hl,(pf)
        inc hl
        ld (pf),hl
        ld a,(m_ordnum)
        cp P4B_END_ORDER
        jr c,.r
        ld a,2
        ld (sect),a
        ret
.r:     cp 28
        jr c,.tun
        ld a,(sram_ok)          ; no SRAM bank 1 -> keep the tunnel
        or a
        jr z,.tun
        ld a,1
        ld (sect),a
        ; torus: 12 frames in bank 1 (or none -> show tunnel frame 0 region? use cube-less fallback)
        ld a,(sram_ok)
        or a
        jr z,.nob
        ld a,3
        out ($37),a
.nob:   ld a,(pf)
        rrca
        jr nc,.s
        ld a,(anim)
        inc a
        cp 12
        jr c,.a
        xor a
.a:     ld (anim),a
.s:     ld a,(anim)
        ld b,a
        add a,a
        add a,b
        ld h,a
        ld l,0
        ld de,$4000
        add hl,de
        ld (srcp),hl
        ret
.tun:   ; 24 frames, one per display frame
        ld a,(anim)
        inc a
        cp 24
        jr c,.t
        xor a
.t:     ld (anim),a
        ld l,a
        ld h,0
        add hl,hl               ; *512 = <<9
        ld h,l
        ld l,0
        ld de,tunnel
        add hl,de
        ld (srcp),hl
        ret

rtab:   ; mode(1) CSS0 lines, a few CSS1 bands
        DUP 300
        db $28,$28
        EDUP
bg:     INCBIN "../build/p4b/bg.bin"
tunnel: INCBIN "../build/p4b/tunnel.bin"
        ds 4,$80
p4b_end:
        DISPLAY "p4b end: ", p4b_end
        ASSERT p4b_end <= $FA00
        SAVEBIN "../build/p4b.bin", OVL, p4b_end - OVL
