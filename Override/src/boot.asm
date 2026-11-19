; =====================================================================
;  boot.asm - start-up: DOS mapping, 128K check, common files, tables
; =====================================================================
boot:
            ; how does the DOS sit in memory? (SRAM -> mapping 1, ROM -> 0)
            ld hl,$5FFF
            ld b,(hl)
            ld a,b
            cpl
            ld (hl),a
            ld a,(hl)
            xor b
            ld (hl),b
            and 1
            ld (dos_map),a
            ld (cur_map),a
            ; clear the variables (keeping the DOS byte)
            ld hl,VARS
            ld de,VARS+1
            ld bc,BOUNCE-VARS-1
            ld (hl),0
            ldir
            ld (dos_map),a
            ld (cur_map),a
            ld hl,$7A3B
            ld (rng),hl
            ld a,LATCH_GAME
            ld (latchv),a
            ld (LATCH),a
            ; SRAM bank 3 and upper bank 1 (the 128K card)
            ld a,MAP_GAME
            out (BANKPORT),a
            ld hl,$5000
            ld (hl),$A5
            ld a,(hl)
            cp $A5
            jp nz,no_sram
            ld (hl),$5A
            ld a,(hl)
            cp $5A
            jp nz,no_sram
            ld hl,$D000
            ld (hl),$C3
            ld a,(hl)
            cp $C3
            jp nz,no_sram
            ld a,(dos_map)
            out (BANKPORT),a
            call boot_msg
            call joy_detect
            ld hl,n_com
            call sd_load
            jp c,load_fail
            ; tables in main RAM
            call make_div6
            ld a,MAP_GAME
            call setmap
            ld a,$01                ; a modest first high score
            ld (hiscore+1),a
            xor a
            ld (demo_ship),a
            ld a,1
            ld (sfx_on),a
            ld (music_on),a
            ; on to the front end (never returns)
            call fe_call
            dw fe_main
            jp boot

; DIV6[y] = y / 6 for y = 0..255
make_div6:
            ld hl,DIV6
            xor a
            ld c,a                  ; quotient
            ld b,a                  ; remainder
.l:         ld (hl),c
            inc b
            ld a,b
            cp 6
            jr nz,.n
            ld b,0
            inc c
.n:         inc l
            jr nz,.l
            ret

n_com:      db '"OVCOM"',0

; text screen message while loading
boot_msg:
            xor a
            ld (LATCH),a
            ld hl,VRAM
            ld de,VRAM+1
            ld bc,511
            ld (hl),$60             ; inverse space (green block)
            ldir
            ld hl,str_boot
            ld de,VRAM+32*7+9
            jr print0
print0:     ld a,(hl)
            or a
            ret z
            and $3F
            ld (de),a
            inc hl
            inc de
            jr print0
str_boot:   db "OVERRIDE",0

no_sram:    ld hl,str_nosram
            jr fatal
fatal:      di
            push hl
            ld a,(dos_map)
            out (BANKPORT),a
            xor a
            ld (LATCH),a
            ld hl,VRAM
            ld de,VRAM+1
            ld bc,511
            ld (hl),$20
            ldir
            pop hl
            ld de,VRAM+32*7+1
            call print0
.h:         jr .h
str_nosram: db "NEEDS BENNVENN SD + 128K RAM",0
str_nofile: db "CAN'T LOAD OV*.DAT FILES",0
str_ver:    db "OV*.DAT FILES DON'T MATCH",0
