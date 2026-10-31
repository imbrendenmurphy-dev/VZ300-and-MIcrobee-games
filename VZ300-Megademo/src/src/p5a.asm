; =====================================================================
;  PART 5a : SEMIGRAPHICS SHOWCASE I              music orders 30..33
;  rotozoomer (main RAM), twister over a wobbling checkerboard (bank 1)
; =====================================================================
        INCLUDE "ovl.inc"
        INCLUDE "anim0.inc"
sections:
        db 32, 24, 2, 0
        dw roto
        db 34, 16, 2, 1
        dw $4000
        db 0
roto:   INCBIN "../build/p5a/roto.bin"
        ds 4,$80
p5a_end:
        ASSERT p5a_end <= $FA00
        SAVEBIN "../build/p5a.bin", OVL, p5a_end - OVL
