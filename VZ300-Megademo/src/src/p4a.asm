; =====================================================================
;  PART 4a : 3D MADNESS I                         music orders 22..25
;  Pre-rendered flat-shaded solids streamed into a 64x48 mode(1) window
;  (copied behind the beam, tear free), FLD bounce, border raster bars.
;  The octahedron's frames live in SRAM bank 1 (port $37 = 3).
; =====================================================================
        INCLUDE "ovl.inc"

P4A_END_ORDER EQU 26
WIN     EQU VRAM + 4*32 + 8
FRAME_BYTES EQU 768

SU_W    MACRO
        SU_HLDE srcp, WIN
        ENDM
SU_F    MACRO
        SU_SP fldp
        ENDM

part_entry:
        ld hl,bg
        ld de,VRAM
        ld bc,2048
        ld a,M1G
        call kcopy
        ld hl,cube
        ld (srcp),hl
        call logic
        call music_apply
frame:
        FRAME_START tnorm
        SEG a1, a1x, RASTHL, 103, SU_NONEH, W_IDLEH, W_IDLEH, c1
        SEG a2, a2x, RASTHL, 103, SU_F, W_IDLEH, W_IDLEH, c2
        SEG16 a3, a3x, SU_W, c3
        SEG a4, a4x, RAST, 105, SU_NONE, W_IDLE, W_IDLE, c4
        FRAME_END
        call logic
        call music_apply
        ld a,(done)
        or a
        jp z,frame
        ld a,1
        out ($37),a
        ret

c1:     db 30           ; lines 0..61
c2:     db 7
c3:     db 48
c4:     db 1
done:   db 0
tnorm:  dw fldtab+2*120
fldp:   dw fldtab+2*120
srcp:   dw 0
anim:   db 0
bounce_i: db 0
pf:     dw 0
usebank: db 0

logic:
        ld hl,(pf)
        inc hl
        ld (pf),hl
        ld a,(m_ordnum)
        cp P4A_END_ORDER
        jr c,.run
        ld a,1
        ld (done),a
        ret
.run:   ; which object: cube for orders 22,23 ; octahedron (bank 1) for 24,25
        cp 24
        jr c,.cube
        ld a,(sram_ok)
        or a
        jr z,.cube
        ld a,3
        out ($37),a
        ld a,12
        ld de,$4000
        jr .obj
.cube:  ld a,1
        out ($37),a
        ld a,16
        ld de,cube
.obj:   ld c,a                  ; number of frames
        ; advance animation every 2 frames
        ld a,(pf)
        rrca
        jr nc,.same
        ld a,(anim)
        inc a
        cp c
        jr c,.ok
        xor a
.ok:    ld (anim),a
.same:  ld a,(anim)
        cp c
        jr c,.ok2
        xor a
        ld (anim),a
.ok2:   ; srcp = base + anim*768
        ld b,a
        add a,a
        add a,b                 ; 3*anim
        ld h,a
        ld l,0                  ; *768
        add hl,de
        ld (srcp),hl
        ; bounce (orders 24,25): FLD push p (even), copy follows
        ld a,(m_ordnum)
        cp 24
        ld a,0
        jr c,.nob
        ld a,(bounce_i)
        inc a
        cp 150
        jr c,.bi
        xor a
.bi:    ld (bounce_i),a
        ld l,a
        ld h,0
        ld de,btraj
        add hl,de
        ld a,(hl)
        and $FE
.nob:   ; a = p (0..36, even)
        cp 19
        jr c,.pok
        ld a,18
.pok:   ld b,a
        ; fld pointer = fldtab + 2*(120 - p)
        ld a,120
        sub b
        ld l,a
        ld h,0
        add hl,hl
        ld de,fldtab
        add hl,de
        ld (fldp),hl
        ; segment counts: c2 = 7 + p/2 - 1 ; c4 = kernel_pairs - 25 - (7+p/2) - 97 - 1
        ld a,b
        srl a
        add a,7
        ld (c2),a
        ld c,a
        ld a,(kernel_pairs)
        sub 31+1+97+1
        sub c
        ld (c4),a
        ret

        ALIGN 2
fldtab: INCBIN "../build/p4a/fld.bin"
btraj:  INCBIN "../build/p4a/bounce.bin"
bg:     INCBIN "../build/p4a/bg.bin"
cube:   INCBIN "../build/p4a/cube.bin"
p4a_end:
        DISPLAY "p4a end: ", p4a_end
        ASSERT p4a_end <= $FA00
        SAVEBIN "../build/p4a.bin", OVL, p4a_end - OVL
