; =====================================================================
;  boot.asm - one-time start-up code.  Assembled after the staging data,
;  so it is loaded with the program, runs once, and is then overwritten by
;  the level map.  Nothing here may be called after start-up.
; =====================================================================
boot:
        ld a,LATBASE
        ld (LATCH),a
        ; We arrive with the DOS's mapping (it just loaded us).  Where does the
        ; DOS run from - SRAM (mapping 1) or ROM (0)?  As 13 Ghosts / Galahxy.
        call dos_probe
        ; keep a copy of the ROM/DOS system area: the game uses $7800-$7BFF and
        ; puts this back around every DOS call
        ld hl,$7800
        ld de,SYSSAVE
        ld bc,$400
        ldir
        ld a,LATBASE
        ld (latchv),a
        bank BK_UPPER           ; the game's own low bank from here on
        call init_tables
        call bank_test
        call init_im2
        call detect_joy
        ld a,$FF
        ld (packlv),a
        ld a,(dos_m)
        ld (dosmap),a
        jp boot_done            ; (resident: switches to upper bank 1)

dos_m   db 1
dos_probe:
        ld hl,$5FFF
        ld b,(hl)
        ld a,b
        cpl
        ld (hl),a
        ld a,(hl)
        xor b
        ld (hl),b
        and 1
        ld (dos_m),a
        ret

; ---------------------------------------------------------------- tables
init_tables:
        ; shift tables: page LS1+2k = (v << 2s) , LS1+2k+1 = (v >> (8-2s)), s=k+1
        ld h,LS1
        ld c,2                  ; shift amount in bits (2,4,6)
.tl:    ld l,0
.t1:    ld a,l
        ld b,c
.t2:    add a,a
        djnz .t2
        ld (hl),a
        inc h
        ld a,l
        ld b,c
        ld e,a
        ld a,8
        sub c
        ld b,a
        ld a,e
.t3:    srl a
        djnz .t3
        ld (hl),a
        dec h
        inc l
        jr nz,.t1
        inc h
        inc h
        inc c
        inc c
        ld a,c
        cp 8
        jr nz,.tl
        ; mask table: pixel 00 -> 11 (keep background), else 00
        ld hl,MASKPG*256
.m1:    ld a,l
        ld b,4
        ld e,0
.m2:    rlc e
        rlc e
        rlca
        rlca
        ld d,a
        and 3
        jr nz,.m3
        ld a,e
        or 3
        ld e,a
.m3:    ld a,d
        djnz .m2
        ld (hl),e
        inc l
        jr nz,.m1
        ret

init_im2:
        ld hl,IM2TAB
        ld b,0
.l:     ld (hl),high IM2VEC
        inc hl
        djnz .l
        ld (hl),high IM2VEC
        ld a,$C3
        ld (IM2VEC),a
        ld hl,isr
        ld (IM2VEC+1),hl
        ld a,high IM2TAB
        ld i,a
        im 2
        ret

; Both joysticks, interchangeably.  On this interface joystick 1 reads on $2C
; (directions + fire) and its buttons on $2E/$2D; joystick 2's directions
; read on $29 and its buttons on $2B/$27.  Every port that sits idle ($1F) at
; boot is enabled, and joy_read ANDs them together (all active low).
detect_joy:
        ld hl,joyports
        ld d,1                  ; bit for this port
        ld e,0                  ; mask being built
.p:     ld c,(hl)
        ld b,8                  ; must read idle 8 times
.s:     push bc
        ld b,0
        in a,(c)
        pop bc
        and $1F
        cp $1F
        jr nz,.no
        djnz .s
        ld a,e
        or d
        ld e,a
.no:    inc hl
        sla d
        ld a,d
        cp 1<<NJOYP
        jr nz,.p
        ld a,e
        ld (joymask),a
        ld (joyok),a
        ret

; joy_read -> A = pressed bits (bit0 up 1 down 2 left 3 right 4 fire), any stick
; ---------------------------------------------------------------- bank test
; The game's low bank (1) must not be the DOS's, and upper bank 1 must not be
; upper bank 0.  Each probe puts back what it found.
bank_test:
        ld a,(dos_m)
        or a
        jr z,.up                ; DOS in ROM: nothing of ours can hurt it
        ld hl,$5F00
        ld a,(dos_m)
        out (BANKPORT),a
        ld b,(hl)               ; a DOS byte
        bank BK_UPPER
        ld c,(hl)               ; ours
        ld a,b
        cpl
        ld (hl),a               ; write ours to the complement of the DOS byte
        ld a,(dos_m)
        out (BANKPORT),a
        ld a,(hl)
        ld (hl),b               ; (if they are one bank, this repairs the DOS)
        cp b
        ld a,BK_UPPER
        out (BANKPORT),a
        ld (hl),c
        ld c,'1'
        jp nz,bank_fail
.up:    ret                     ; (upper banks: tested by boot_done, resident)
bank2_fail:
        ld c,'2'
        jp bank_fail

bank_fail:                      ; C = bank digit that failed
        push bc
        bank BK_UPPER
        ld a,LATBASE
        ld (LATCH),a
        ld a,$FF
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),a
        ldir
        ld hl,txt_bankerr
        ld c,0
.l:     ld a,(hl)
        or a
        jr z,.d
        push hl
        push bc
        call hud_char
        pop bc
        pop hl
        inc hl
        inc c
        jr .l
.d:     pop bc
        ld a,c
        ld c,29
        call hud_char
.halt:  jr .halt
txt_bankerr: db "128K SRAM BANK TEST FAILED: ",0
