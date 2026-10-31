; =====================================================================
;  PART 5b : SEMIGRAPHICS SHOWCASE II             music orders 34..37
;  rolling cylinder logo (main RAM), transparency layers (bank 1)
; =====================================================================
        INCLUDE "ovl.inc"
        INCLUDE "anim0.inc"
sections:
        db 36, 16, 2, 0
        dw cyl
        db 38, 16, 2, 1
        dw $4000
        db 0
cyl:    INCBIN "../build/p5b/cyl.bin"
        ds 4,$80
p5b_end:
        ASSERT p5b_end <= $FA00
        SAVEBIN "../build/p5b.bin", OVL, p5b_end - OVL
