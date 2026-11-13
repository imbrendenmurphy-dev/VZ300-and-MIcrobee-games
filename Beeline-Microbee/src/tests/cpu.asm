; quick CPU self-test: results stored at 8000h
        org 100h
        ld sp,0E000h
        ld ix,8000h
; 1: 8x8 multiply 13*11 by shift-add
        ld a,13
        ld e,11
        ld hl,0
        ld d,0
        ld b,8
.m      add hl,hl
        rla
        jr nc,.n
        add hl,de
.n      djnz .m
        ld (ix+0),l       ; expect 143 = 8Fh
; 2: SBC/ADC 16
        ld hl,1000h
        ld de,0001h
        or a
        sbc hl,de          ; 0FFFh
        ld (8002h),hl
        scf
        adc hl,de          ; 1001h
        ld (8004h),hl
; 3: ldir copy
        ld hl,src
        ld de,8010h
        ld bc,4
        ldir
; 4: index regs + cp/flags
        ld iy,8020h
        ld (iy+1),5Ah
        ld a,(iy+1)
        cp 5Ah
        jr nz,fail
        ld a,10h
        sub 20h            ; carry set
        jr nc,fail
        ld (iy+2),a        ; F0h
; 5: DAA 15h+27h = 42h
        ld a,15h
        add a,27h
        daa
        ld (iy+3),a
; 6: rotates/bit
        ld a,81h
        rlca               ; 03h, C=1
        jr nc,fail
        ld (iy+4),a
        ld b,40h
        bit 6,b
        jr z,fail
        set 0,b            ; 41h
        ld (iy+5),b
; 7: push/pop/ex
        ld bc,1234h
        push bc
        pop hl
        ex de,hl
        ld (8030h),de
        ld a,0AAh
        ld (iy+6),a
        halt
fail:   ld a,0EEh
        ld (8020h+6),a
        halt
src:    db 1,2,3,4
