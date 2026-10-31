; =====================================================================
;  THE FORGOTTEN DEPTHS
;  An atmospheric dungeon crawler for the Dick Smith VZ300
;  with BennVenn SD loader + 128K RAM expansion.
;  VIBED BY BPM - 2026
;
;  Loads at $8000 (low, like the proven Xevious v1.2 / Cybernoid
;  loaders): no mapper writes, the SD DOS RAM at $FA00+ is untouched.
; =====================================================================
        DEVICE NOSLOT64K
        INCLUDE "defs.inc"
        INCLUDE "../build/consts.inc"

        org $8000
start:
        di
        ld sp,STACKTOP
        im 1
        ld a,M0O
        ld (LATCH),a
        call stage_banks        ; unpack + verify both SRAM banks
        call joy_detect
        call music_stop
        IFDEF DEMOREC
        jp demo_record
        ENDIF
.title: call bank1
        call title
        call bank0
        ld a,(t_mode)
        cp 2
        jr z,.res
        call game_new
        jr .title
.res:   call game_run
        jr .title

        INCLUDE "sound.asm"
        INCLUDE "input.asm"
        INCLUDE "engine.asm"
        INCLUDE "game.asm"
        INCLUDE "screens.asm"
        INCLUDE "level.asm"
        INCLUDE "boss.asm"
        INCLUDE "demo.asm"
        INCLUDE "dzx0.asm"
; SRAM bank switching: bank 1 holds cold data; bank 0 is the SD DOS (left intact)
bank1:  ld a,3
        jr bank_set
bank0:  ld a,1
bank_set:
        ld (bank_cur),a
        out ($37),a
        ret
bank_cur: db 1
; clear the text screen to A
cls:    ld hl,VRAM
        ld de,VRAM+1
        ld bc,511
        ld (hl),a
        ldir
        ret
; run the routine at HL with bank 1 mapped, then restore the previous mapping
with_bank1:
        ld a,(bank_cur)
        push af
        call bank1
        call .jp
        pop af
        jr bank_set
.jp:    jp (hl)

code_end:
        INCLUDE "../build/lvsec.inc"
        INCLUDE "../build/data.inc"
DEMO_DATA:
        IFNDEF DEMOREC
        INCLUDE "../build/demo.inc"
        ENDIF
        db 0
hot_end:
; ---------------------------------------------------------------------
; power-on: common data -> bank 3, chapter archive -> home bank (over the
; DOS). Both are ZX0-packed in the load image (which lies in the map
; area and is not needed afterwards) and checked after unpacking.
; ---------------------------------------------------------------------
stage_banks:
        call bank1
        ld hl,COLD_Z
        ld de,$4000
        call dzx0
        ld hl,$4000
        ld bc,COLD_SIZE
        call sum16
        ld de,COLD_SUM
        or a
        sbc hl,de
        ld c,'3'
        jr nz,bank_fail
        call bank0
        ld hl,ARCH_Z
        ld de,$4000
        call dzx0
        ld hl,$4000
        ld bc,ARCH_SIZE
        call sum16
        ld de,ARCH_SUM
        or a
        sbc hl,de
        ld c,'1'
        jr nz,bank_fail
        call bank1              ; bank 3 must still hold the common data
        ld hl,$4000
        ld bc,COLD_SIZE
        call sum16
        ld de,COLD_SUM
        or a
        sbc hl,de
        ld c,'3'
        jr nz,bank_fail
        jp bank0

; HL = start, BC = length -> HL = 16-bit sum of the bytes
sum16:  ex de,hl
        ld hl,0
.l:     ld a,(de)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret

bank_fail:
        call bank0
        ld a,M0G
        ld (LATCH),a
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,511
        ld (hl),32
        ldir
        ld hl,txt_bankerr
        ld de,VRAM+7*32+2
.t:     ld a,(hl)
        or a
        jr z,.d
        call ascii2vz
        ld (de),a
        inc hl
        inc de
        jr .t
.d:     ld a,c
        ld (de),a
.h:     jr .h
txt_bankerr: db "128K SRAM BANK TEST FAILED: ",0

        INCLUDE "../build/stage.inc"
COLD_Z:
        INCBIN "../build/cold.zx0"
ARCH_Z:
        INCBIN "../build/arch.zx0"
prog_end:

; ---- data that lives in the SRAM banks (assembled for $4000, not part of
;      the load image except in packed form above)
        ORG $4000
cold_start:
        INCLUDE "../build/cold.inc"
cold_end:
COLD_SIZE EQU cold_end - cold_start
        SAVEBIN "../build/cold.bin", cold_start, COLD_SIZE

        DISPLAY "code end: ", code_end, "  hot end: ", hot_end, "  cold size: ", COLD_SIZE, "  archive: ", ARCH_SIZE, "  image end: ", prog_end
        ASSERT hot_end <= LVBUF
        ASSERT COLD_SIZE <= LSLOT - $4000
        ASSERT ARCH_SIZE <= $2800
        ASSERT prog_end <= $FA00
        SAVEBIN "../build/depths.bin", start, prog_end - start
