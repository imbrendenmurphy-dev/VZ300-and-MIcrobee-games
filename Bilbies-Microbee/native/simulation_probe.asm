; Standalone integration probe: original simulation in lower bank 1.
; Collision MASK lives at 4000h; code 0600h, state 7800h. Visual terrain
; editing and sound are deliberately stubbed by the generated game-probe.
        DEVICE NOSLOT64K
        INCLUDE "../build/native-simulation/equ.asm"
        INCLUDE "../build/native-simulation/sound-equ.asm"
        INCLUDE "../src/vars.asm"
        ASSERT VARS_END <= CRT
        ORG $0600
sim_start:
        INCLUDE "../build/native-simulation/rand.asm"
int_poll:
sfx_play:
        ret
        INCLUDE "../build/native-simulation/game-probe.asm"
        ALIGN 256
PMSK:   db $C0,$30,$0C,$03
BITT:   db $80,$40,$20,$10,$08,$04,$02,$01
sim_end:
        ASSERT sim_end < MASK
        SAVEBIN "../build/native-simulation/SIM.BIN",sim_start,sim_end-sim_start
