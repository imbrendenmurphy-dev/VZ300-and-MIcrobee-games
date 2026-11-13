; ===========================================================================
;  ASTEROIDS II  -  for the Dick Smith VZ300 + BennVenn SD loader / 128K
;  sjasmplus source.  Loads as a .VZ binary at $8000 from SD.
; ===========================================================================
        DEVICE NONE
        INCLUDE "hw.inc"
        OUTPUT "../build/ast2.bin"
        ORG $8000
start:
        di
        ld sp,STACK_TOP
        ld a,$08
        ld (LATCH),a
        ld (latch_base),a
        xor a
        call cls_vram
        ld hl,$ACE1
        ld (rnd_seed),hl
        call check_sram
        jr z,.ram_ok
        ; no BennVenn SRAM bank: say so and stop
        xor a
        ld (LATCH),a            ; text mode
        ld a,$60
        call cls_vram
        ld hl,txt_needram
        ld de,VRAM+32*7+5
        call print_text
        ld hl,txt_needram2
        ld de,VRAM+32*8+3
        call print_text
.halt:  jr .halt
.ram_ok:
        ld hl,VARS
        ld bc,512
        call clear_mem
        ld a,$08
        ld (latch_base),a
        ld hl,no_tick
        ld (tick_hook),hl
        call snd_off
        call init_rowtab
        call preshift_all
        call detect_joy
        ld hl,PARTS
        ld (part_next),hl
        ld hl,$ACE1
        ld (rnd_seed),hl
        ld hl,hs_defaults
        ld de,hs_table
        ld bc,40
        ldir
        ld a,1
        ld (music_on),a
main_loop:
        call attract
        call play_game
        call check_hiscore
        jr main_loop

; text-mode print (mode 0): HL = string, DE = screen address
print_text:
        ld a,(hl)
        or a
        ret z
        and $3F
        ld (de),a
        inc hl
        inc de
        jr print_text

        INCLUDE "video.asm"
        INCLUDE "sound.asm"
        INCLUDE "game.asm"
        INCLUDE "enemies.asm"
        INCLUDE "front.asm"
        INCLUDE "data.asm"
code_end:
        ; init-only data is loaded into the back-buffer area and consumed by
        ; preshift_all before the buffer is ever used
        ASSERT code_end <= RAM0, "program overlaps runtime RAM"
        DS RAM0 - $, 0
        SPRITE_SOURCE
        ASSERT $ <= SPRDESC, "sprite source overlaps descriptors"
        ASSERT CACHE_MAIN + CACHE_OVERFLOW <= CACHE_MAIN_END, "sprite cache overflow"
        INCLUDE "vars.asm"
        DISPLAY "code end: ",/H,code_end
        DISPLAY "vars end: ",/H,vars_end
        ASSERT code_end <= RAM0, "program overlaps runtime RAM"
