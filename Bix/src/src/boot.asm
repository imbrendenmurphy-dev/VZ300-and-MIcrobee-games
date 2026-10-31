; =====================================================================
;  boot.asm - one-time start-up code.  Assembled after the staging data,
;  so it is loaded with the program, runs once, and is then overwritten by
;  the level map.  Nothing here may be called after start-up.
; =====================================================================
boot:
        ld a,LATBASE
        ld (LATCH),a
        call init_tables
        call bank_init
        call load_player
        call init_im2
        call detect_joy
        jp game_boot

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
; ---------------------------------------------------------------- boot
bank_init:
        bank BK_WORLD
        ld hl,stage_bank3
        ld de,$4000
        ld bc,BANK3_SIZE
        ldir
        ld hl,stage_bank3
        ld de,$4000
        ld bc,BANK3_SIZE
        call memcmp
        ld c,'3'
        jp nz,bank_fail
        bank BK_HOME
        ; the upper bank: packed overlay at $B800, more archive at B5BASE
        ld hl,stage_ovl
        ld de,UP_OVL
        ld bc,OVL_LZ
        xor a
        call farcopy
        ld hl,stage_b5x
        ld de,B5BASE
        ld bc,BANK5X_SIZE
        xor a
        call farcopy
        ld hl,UP_OVL
        ld de,stage_ovl
        ld bc,OVL_LZ
        ld a,2
        call farcopy
        ld c,'5'
        jp nz,bank_fail
        ld hl,B5BASE
        ld de,stage_b5x
        ld bc,BANK5X_SIZE
        ld a,2
        call farcopy
        ld c,'5'
        jp nz,bank_fail
        ret

memcmp: ; Z if equal
.l:     ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret

bank_fail:                      ; C = bank digit that failed
        push bc
        bank BK_HOME
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
