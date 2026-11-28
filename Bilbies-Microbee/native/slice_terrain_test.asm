; Standalone wrapper used only by slice_terrain_test.py.
        DEVICE NOSLOT64K
MASK EQU $4000
        ORG $0600
        INCLUDE "slice_terrain.asm"
        ALIGN 256
BITT:   db $80,$40,$20,$10,$08,$04,$02,$01
        ASSERT $ < $2E00
        SAVEBIN "../build/native-simulation/TERRTEST.BIN",$0600,$-$0600
