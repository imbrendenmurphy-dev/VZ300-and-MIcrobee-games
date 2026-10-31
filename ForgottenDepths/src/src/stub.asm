; =====================================================================
;  stub.asm : loader stub for THE FORGOTTEN DEPTHS
;  The .VZ is small (loads at $8000 well below the DOS area). The stub
;  moves itself to $7E00, moves the packed program to the top of RAM
;  and unpacks it upwards from $8000, then starts it.
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "../build/stubdefs.inc"     ; PLEN, ULEN
        org $8000
stub:
        di
        ld sp,$8000
        ld a,$30
        ld ($6800),a
        ld hl,reloc
        ld de,$7E00
        ld bc,reloc_end-reloc
        ldir
        jp $7E00
reloc:
        DISP $7E00
        ld hl,payload+PLEN-1
        ld de,$FFFF
        ld bc,PLEN
        lddr                    ; packed program -> top of RAM
        inc de
        ex de,hl                ; HL = packed start
        ld de,$8000
        call dzx0
        jp $8000
        INCLUDE "dzx0.asm"
        ENT
reloc_end:
payload:
        INCBIN "../build/pay.zx0"
stub_end:
        ASSERT $8000 + ULEN + 64 <= $10000    ; in-place margin (unpacked end stays below the packed end)
        SAVEBIN "../build/stub.bin", stub, stub_end - stub
        DISPLAY "VZ loads $8000-", stub_end-1
