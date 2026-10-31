; ---------------------------------------------------------------------------
; Core: boot, interrupt, latch/mode, frame timing, controls
; (frame interrupt handling as in the Scramble / Cybernoid conversions)
; ---------------------------------------------------------------------------
vz_boot:
        di
        ld sp,STACKTOP
        call sram_check
        ld a,L_MODE
        ld (LATCH),a
        ld hl,VARS              ; clear variables and creature tables
        ld de,VARS+1
        ld bc,IMTAB-VARS-1
        ld (hl),0
        ldir
        ld hl,IMTAB             ; IM2 table: 257 bytes of $7F -> ISR at $7F7F
        ld de,IMTAB+1
        ld bc,256
        ld (hl),$7F
        ldir
        ld a,$C3
        ld (ISRJP),a
        ld hl,vz_isr
        ld (ISRJP+1),hl
        ld a,IMTAB>>8
        ld i,a
        im 2
        ld hl,$3A71
        ld (v_seed),hl
        xor a
        call set_mode1
        call build_tables
        call joy_detect
        call snd_init
        ld a,1
        ld (v_musicon),a
        ld (v_sfxon),a
        ei
        jp front_main

; ---- interrupt: counts frames. The VZ holds INT low for the whole field
; sync, so the ISR returns with interrupts still off; int_poll turns them
; back on once the sync is over.
vz_isr:
        push af
        ld a,(LATCH)
        rla
        jr c,.sp                ; INT outside the sync: not a new frame
        ld a,(v_tick)
        inc a
        ld (v_tick),a
.sp:    ld a,1
        ld (v_hold),a
        pop af
        reti

int_poll:
        ld a,(v_title)          ; (the title's music keeps interrupts off)
        or a
        ret nz
        ld a,(v_hold)
        or a
        jr z,.e
        ld a,(LATCH)
        rla
        ret nc                  ; still in the sync: stay DI
        xor a
        ld (v_hold),a
.e:     ei
        ret

; ---- latch ------------------------------------------------------------------
setlatch:
        ld (v_latch),a
        push af
        or L_SPK0
        ld (v_spkoff),a
        ld (LATCH),a
        pop af
        or L_SPK1
        ld (v_spkon),a
        ret
set_mode1:                      ; A = 0 / L_CSS
        or L_MODE
        jr setlatch

; ---- wait until A frames have passed since the last call
frame_sync:
        ld b,a
.w:     ld a,(v_tick)
        ld hl,v_last
        sub (hl)
        cp b
        jr nc,.ok
        call snd_wait_step
        jr .w
.ok:    ld a,(v_tick)
        ld (v_last),a
        ret

; ---- random: A = random byte
rand:
        push hl
        ld hl,(v_seed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (v_seed),hl
        ld a,l
        xor h
        pop hl
        ret

; ---- controls -> A (and v_ctl): b0 left b1 right b2 down b3 up b4 fire b5 arm
read_controls:
        push bc
        push hl
        ld c,0
        ld a,(KR0)
        bit 4,a
        jr nz,.n1
        set 3,c                 ; Q up
.n1:    ld a,(KR1)
        bit 4,a
        jr nz,.n2
        set 2,c                 ; A down
.n2:    ld a,(KR6)
        bit 1,a
        jr nz,.n3
        set 0,c                 ; O left
.n3:    bit 4,a
        jr nz,.n4
        set 1,c                 ; P right
.n4:    ld a,(KR4)
        bit 4,a                 ; SPACE
        jr nz,.n5
        set 4,c
.n5:    bit 5,a                 ; M
        jr nz,.n6
        set 4,c
.n6:    call rjoy
        ld a,c
        ld (v_ctl),a
        pop hl
        pop bc
        ret

rjoy:
        ld a,(v_joyok)
        or a
        ret z
        push de
        ld hl,JMAP
        ld e,12
.jm:    ld a,(hl)
        inc hl
        push bc
        ld c,a
        in a,(c)
        pop bc
        and (hl)
        inc hl
        jr nz,.js
        ld a,c
        or (hl)
        ld c,a
.js:    inc hl
        dec e
        jr nz,.jm
        pop de
        ret

; joystick map: (port, active-low mask, result bits)
JMAP:
        ; J1: directions on $2C, FIRE $2E, ARM $2D;  J2: directions on $29, FIRE $2B, ARM $27
        db $2C,$01,$08, $2C,$02,$04, $2C,$04,$01, $2C,$08,$02, $2E,$10,$10, $2D,$10,$20
        db $29,$01,$08, $29,$02,$04, $29,$04,$01, $29,$08,$02, $2B,$10,$10, $27,$10,$20

joy_detect:
        ld b,8
        ld c,$FF
.l:     in a,($2E)
        and c
        ld c,a
        in a,($2D)
        and c
        ld c,a
        djnz .l
        ld a,c
        and $1F
        cp $1F
        ld a,1
        jr z,.ok
        xor a
.ok:    ld (v_joyok),a
        ret

; ---- NZ if any key / fire
anykey:
        push bc
        push hl
        call read_controls
        and $30
        jr nz,.y
        ld c,8
        ld hl,$68FE
.k:     ld a,(hl)
        and $3F
        cp $3F
        jr nz,.y
        rlc l
        dec c
        jr nz,.k
        pop hl
        pop bc
        xor a
        ret
.y:     pop hl
        pop bc
        or 1
        ret
waitrel:
.r:     ld a,1
        call frame_sync
        call anykey
        jr nz,.r
        ret

; ---- key test: A = row address low byte, B = bit mask -> Z if pressed
keyt:
        push hl
        ld h,$68
        ld l,a
        ld a,(hl)
        pop hl
        and b
        ret

; ---- tables built at boot ------------------------------------------------------
; SHT + s*$200: hi part / SHT + s*$200 + $100: lo part of a byte shifted right by
; 2*s bits (s = 1..3; s = 0 isn't used). OPQ: opaque-pixel mask of a sprite byte
; (blue pixels are transparent).
build_tables:
        ld b,1
.s:     push bc
        ld a,b
        dec a
        add a,a
        add a,SHT>>8
        ld h,a
        ld l,0
.b:     ; value L shifted right by 2*B bits into (hi, lo)
        ld d,l
        ld e,0
        push bc
.sh:    srl d
        rr e
        srl d
        rr e
        djnz .sh
        pop bc
        ld (hl),d
        inc h
        ld (hl),e
        dec h
        inc l
        jr nz,.b
        pop bc
        inc b
        ld a,b
        cp 4
        jr nz,.s
        ; opaque masks
        ld hl,OPQ
.o:     ld a,l
        ld c,0
        ld b,4
.op:    rlca
        rlca
        ld d,a
        and 3
        cp C_BLU
        ld a,c
        jr z,.tr
        scf
        rla
        scf
        rla
        jr .nx
.tr:    add a,a
        add a,a
.nx:    ld c,a
        ld a,d
        djnz .op
        ld (hl),c
        inc l
        jr nz,.o
        ret

; ---- the SRAM at $4000-$67FF must be writable (BennVenn mapping 1, as the
; DOS leaves it). If it isn't, set mapping 1 and try again; then give up.
sram_check:
        call .t
        jr z,.b3
        ld a,1
        out ($37),a
        call .t
        jr nz,.fail
.b3:    ; the level designs were unpacked into bank B ($37 = 3): still there
        ; after writing bank A?
        ld a,3
        out ($37),a
        ld hl,(LVBANK)
        ld a,1
        out ($37),a
        ld de,'B'+'L'*256
        or a
        sbc hl,de
        ret z
        ld hl,.msg2
        jr .show
.fail:  ld hl,.msg
.show:  push hl
        xor a
        ld (LATCH),a
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,511
        ld (hl),$20
        ldir
        pop hl
        ld de,VRAM+32*6
.m:     ld a,(hl)
        or a
        jr z,.h
        and $3F
        ld (de),a
        inc hl
        inc de
        jr .m
.h:     jr .h
.t:     ld hl,$4000
        call .b
        ret nz
        ld hl,$67FF
.b:     ld a,$5A
        ld (hl),a
        cp (hl)
        ret nz
        cpl
        ld (hl),a
        cp (hl)
        ret
.msg:   db "BILBIES NEEDS THE BENNVENN RAM  AT 4000-67FF, BUT IT ISN'T     WRITABLE.",0
.msg2:  db "BILBIES NEEDS BOTH 10K SRAM     BANKS OF THE BENNVENN 128K (MAPPING 1 AND 3).",0
