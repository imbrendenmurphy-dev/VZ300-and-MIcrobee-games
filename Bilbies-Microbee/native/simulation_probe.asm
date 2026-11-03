; Original simulation and terrain-job worker for expanded bank 27.
; Collision MASK lives at 4000h; code 0600h, state 7800h. Terrain changes
; mark cells for native drawing; sound and direct legacy picture writes are omitted.
        DEVICE NOSLOT64K
        INCLUDE "../build/native-simulation/equ.asm"
        INCLUDE "../build/native-simulation/sound-equ.asm"
        INCLUDE "../src/vars.asm"
        ASSERT VARS_END <= CRT
        ORG $0600
sim_start:
; Native slice header is at 2E00h. A pristine collision mask at 5400h
; restores the editable MASK on both initial entry and level restart.
sim_init:
        ld hl,$5400 : ld de,MASK : ld bc,MASKSZ : ldir
        call st_init
        ld hl,VARS : ld de,VARS+1 : ld bc,VARS_END-VARS-1
        ld (hl),0 : ldir
        ld hl,CRT : ld de,CRT+1 : ld bc,NCRT*CSZ+NPART*PSZ-1
        ld (hl),0 : ldir
        ld hl,$2E00
.name: ld a,(hl) : inc hl : or a : jr nz,.name
        ld de,v_ncrt : ld bc,12 : ldir
        ld a,(v_rate) : ld (v_minrate),a
        ld a,(hl) : inc hl : ld (v_lwb),a
        push hl : ld l,a : ld h,0 : add hl,hl : add hl,hl
        ld (v_lw),hl : pop hl
        ld de,v_lh : ld bc,13 : ldir
        inc hl                    ; texture is not used by the collision code
        ld a,(hl) : inc hl : cp 9 : jr c,.steel_count : ld a,8
.steel_count:
        ld (v_nsteel),a : or a : jr z,.no_steel
        ld b,a : ld de,v_steel
.steel: push bc : ld bc,6 : ldir : pop bc : djnz .steel
.no_steel:
        ld a,(v_min) : ld l,a : ld h,0 : ld e,l : ld d,h
        add hl,hl : add hl,hl : add hl,hl : add hl,hl
        or a : sbc hl,de : add hl,hl : add hl,hl : ld (v_tleft),hl
        ld hl,$ACE1 : ld (v_seed),hl
        ret
; Snapshot authoritative game result for the fixed-bank HUD/level flow.
; A=end, B=saved, C=quota, D=lost, HL=seconds left.
sim_status:
        ld a,(v_saved) : ld b,a
        ld a,(v_tosave) : ld c,a
        ld a,(v_lost) : ld d,a
        ld hl,(v_tleft) : ld a,(v_end) : ret
        INCLUDE "../build/native-simulation/rand.asm"
int_poll:
sfx_play:
        ret
        INCLUDE "../build/native-simulation/game-probe.asm"
        INCLUDE "../build/native-simulation/skill-probe.asm"
        INCLUDE "../build/native-simulation/clock-probe.asm"
        ALIGN 256
PMSK:   db $C0,$30,$0C,$03
BITT:   db $80,$40,$20,$10,$08,$04,$02,$01
        INCLUDE "slice_terrain.asm"
sim_end:
        ASSERT sim_end < $2E00
        SAVEBIN "../build/native-simulation/SIM.BIN",sim_start,sim_end-sim_start
