boot:       call mb_init
            call mb_mode_menu
            jp title_screen

; load_area: A = area number. part 1 -> SRAM bank 3 $4000, part 2 -> main RAM P2BASE,
; pack (map, events, exits, texts, song) -> AREA_RAM; then builds MAPBUF
load_area:
            call area_files_ptr
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
            push hl
            ld de,4
            add hl,de
            ld e,(hl)
            inc hl
            ld d,(hl)
            push de
            pop ix
            ld de,AREA_RAM
            xor a
            call sd_load
            pop hl
            call reload_p2_hl
            jp build_map

; HL = area_files entry (p1, p2, pack) for area A
area_files_ptr:
            ld l,a
            ld h,0
            add hl,hl
            ld e,l
            ld d,h
            add hl,hl
            add hl,de               ; *6
            ld de,area_files
            add hl,de
            ret

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
