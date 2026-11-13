; ============================================================================
;  START-UP (runs once; this memory then becomes the shadow screen)
; ============================================================================
boot:
        di
        ld sp,STACKTOP
        ld a,$28                ; mode 1, green/yellow/blue/red
        ld (LATCH),a
        ; clear the variables
        ld hl,VARS
        ld de,VARS+1
        ld bc,VARSLEN-1
        ld (hl),0
        ldir
        ld a,$28
        ld (latch),a
        ld a,SB>>8
        ld (txt_page),a
        ld a,$FF
        ld (slot_a),a
        ld (slot_b),a
        ld (stage_cur),a
        ld a,1
        ld (opt_diff),a
        ld a,2
        ld (tick_len),a
        ld hl,$A5C3
        ld (seed),hl
        ; blue screen
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,$7FF
        ld (hl),$AA
        ldir
        ; ---- is the DOS in RAM at $4000 (the 128K SD loader)?
        ld hl,$5FFF
        ld a,(hl)
        ld b,a
        cpl
        ld (hl),a
        cp (hl)
        ld (hl),b
        ld a,1                  ; error 1: no SD loader RAM
        jp nz,boot_fail
        ld a,1
        ld (dos_map),a
        ; ---- SRAM bank 1 must be separate from the DOS bank
        ld a,($4000)
        ld b,a                  ; a DOS byte
        ld a,MAP_H0
        out ($37),a
        ld a,b
        cpl
        ld ($4000),a
        ld a,($4000)
        xor b
        inc a                   ; = 0 if it held
        ld c,a
        ld a,1
        out ($37),a
        ld a,($4000)
        cp b
        ld a,2                  ; error 2: no second 10K bank
        jp nz,boot_fail
        ld a,c
        or a
        ld a,2
        jp nz,boot_fail
        ; ---- the second high bank must be separate from normal high memory
        ld hl,H1IMG+$40
        call .hi
        ld hl,$F7FF
        call .hi
        ; ---- interrupt table
        ld hl,IM2TAB
        ld de,IM2TAB+1
        ld bc,255
        ld (hl),ISRJP>>8
        ldir
        ld a,$C3
        ld (ISRJP),a
        ld hl,isr
        ld (ISRJP+1),hl
        ld a,IM2TAB>>8
        ld i,a
        im 2
        jp init2
.hi:    ld b,(hl)               ; normal high memory byte
        ld a,5
        out ($37),a
        ld a,b
        cpl
        ld (hl),a
        ld a,(hl)
        xor b
        inc a
        ld c,a
        ld a,1
        out ($37),a
        ld a,(hl)
        cp b
        ld a,3                  ; error 3: no second high bank
        jr nz,boot_fail
        ld a,c
        or a
        ret z
        ld a,3
; boot_fail: A = error number; say so on a red screen and stop
boot_fail:
        ld (err_code),a
        ld a,1
        out ($37),a
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,$7FF
        ld (hl),$FF
        ldir
        ld a,VRAM>>8
        ld (txt_page),a
        ld hl,bs_title
        ld bc,$0204
        ld a,1
        call text
        ld a,(err_code)
        ld hl,bs_e1
        dec a
        jr z,.t
        ld hl,bs_e2
        dec a
        jr z,.t
        ld hl,bs_e3
.t:     ld bc,$0214
        ld a,1
        call text
        ld hl,bs_need
        ld bc,$0224
        ld a,1
        call text
.stop:  jr .stop
bs_title: db "RED DUST RUMBLE CANNOT START",0
bs_e1:  db "NO SD LOADER MEMORY FOUND (1)",0
bs_e2:  db "128K: 2ND LOW BANK MISSING (2)",0
bs_e3:  db "128K: HIGH BANK MISSING (3)",0
bs_need: db "NEEDS BENNVENN SD + 128K",0
