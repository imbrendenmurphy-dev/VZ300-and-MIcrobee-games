; =====================================================================
;  boot.asm - start-up: DOS mapping, 128K check, common files
; =====================================================================
boot:
            ; how does the DOS sit in memory? (SRAM -> mapping 1, ROM -> 0) - as 13 Ghosts
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
            ; clear the variables (not the DOS byte)
            ld hl,VARS
            ld de,VARS+1
            ld bc,BB-VARS-1
            ld a,(dos_map)
            push af
            ld (hl),0
            ldir
            pop af
            ld (dos_map),a
            ld (cur_map),a
            ld hl,$7A3B
            ld (rng),hl
            ld a,L_MODE|L_SPK0
            ld (latchv),a
            ; SRAM bank 3 check (BennVenn 128K required)
            ld a,3
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
            ld a,(dos_map)
            out (BANKPORT),a
            call boot_msg
            call joy_detect
            ld hl,n_com
            call sd_load
            jp c,load_fail
            ld hl,n_w1
            call sd_load
            jp c,load_fail
            call init_im2
            ld a,1
            ld (world_ld),a
            ld (world),a
            call world_setup
            call cls_bb
            ld hl,BB
            ld de,VRAM
            ld bc,2048
            ldir
            ld a,12
            ld (msg_y),a
            ld a,1
            ld (diff),a
            ld a,$01                ; a modest first high score: 010000
            ld (hiscore),a
            ld (maxw),a
            ld (startw),a
            ld (gal_w),a
            xor a
            ld (attract_n),a
            ld (tsel_t),a
            ld hl,s_from
            ld de,from_buf
            ld bc,13
            ldir
            ld a,MAP_FE
            call setmap
            jp title_screen

s_from:     db "FROM STAGE 1",0
n_com:      db '"ZZCOM"',0
n_w1:       db '"ZZW1"',0

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
            ld de,VRAM+32*7+8
            jr print0
print0:     ld a,(hl)
            or a
            ret z
            and $3F
            ld (de),a
            inc hl
            inc de
            jr print0
str_boot:   db "ZEPHYR ZONE",0

no_sram:    ld hl,str_nosram
            jr fatal
load_fail:  ld hl,str_nofile
fatal:      push hl
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
str_nofile: db "CAN'T LOAD ZZ*.DAT FILES",0
str_ver:    db "ZZ*.DAT FILES DON'T MATCH",0
