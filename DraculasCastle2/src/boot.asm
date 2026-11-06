; ===========================================================================
;  boot.asm - start-up
; ===========================================================================
boot:
            ; how does the DOS sit in memory? (SRAM -> mapping 1, ROM -> 0), as 13 Ghosts does
            ld hl,$5FFF
            ld b,(hl)
            ld a,b
            cpl
            ld (hl),a
            ld a,(hl)
            xor b
            ld (hl),b
            and 1
            push af
            ld hl,$EE00             ; variables
            ld de,$EE01
            ld bc,$01FF
            ld (hl),0
            ldir
            ld hl,MAPS
            ld de,MAPS+1
            ld bc,$03FF
            ld (hl),0
            ldir
            pop af
            ld (dos_map),a
            ld hl,$7A3B
            ld (rng),hl
            ld a,1
            ld (music_on),a
            ld a,$08
            call set_latch
            ; SRAM bank 3 check (BennVenn 128K required)
            ld a,3
            out ($37),a
            ld hl,$5000
            ld (hl),$A5
            ld a,(hl)
            cp $A5
            jr nz,no_sram
            ld (hl),$5A
            ld a,(hl)
            cp $5A
            jr nz,no_sram
            call make_flip
            call detect_joy
            xor a
            call cls_back
            call present_full
            jp title_screen

no_sram:    ; no expansion: say so on the (mode 0) text screen
            xor a
            ld (LATCH),a
            ld hl,str_nosram
            ld de,VRAM+32*7
.c:         ld a,(hl)
            or a
            jr z,.h
            and $3F
            ld (de),a
            inc hl
            inc de
            jr .c
.h:         jr .h
str_nosram: db "  NEEDS BENNVENN SD + 128K RAM",0

; load_area: A = area number. part 1 -> SRAM bank 3 $4000, part 2 -> main RAM P2BASE
load_area:
            push af
            add a,a
            add a,a
            ld e,a
            ld d,0
            ld hl,area_files
            add hl,de
            push hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            push de
            pop ix
            ld de,$4000
            ld a,1
            call sd_load
            pop hl
            pop af
reload_p2_hl:
            inc hl
            inc hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            push de
            pop ix
            ld de,P2BASE
            xor a
            jp sd_load
