; =====================================================================
;  INPUT: keyboard (6545 light-pen scan, as the boot ROM does it) and,
;  when switched on with J, a joystick on PIO A.
;   pad:  b0 R  b1 L  b2 U  b3 D  b4 FIRE (space)
;   keys: b0 ESC  b1 P/H pause  b2 R restart  b3 S sound  b4 RETURN
;         b5 M music  b6 J joystick
;  padnew / keysnew collect new presses until the logic takes them.
; =====================================================================
K_H     equ 8
K_J     equ 10
K_M     equ 13
K_N     equ 14
K_P     equ 16
K_R     equ 18
K_S     equ 19
K_Y     equ 25
K_ESC   equ $30
K_BS    equ $31
K_RET   equ $34
K_SPACE equ $37
K_UP    equ $38
K_DOWN  equ $3A
K_LEFT  equ $3B
K_RIGHT equ $3E

; key code, target (0 pad, 1 keys), bit mask
keymap:
        db K_RIGHT,0,1, K_LEFT,0,2, K_UP,0,4, K_DOWN,0,8, K_SPACE,0,16
        db K_ESC,1,1, K_P,1,2, K_H,1,2, K_R,1,4, K_S,1,8, K_RET,1,16, K_M,1,32, K_J,1,64
        db $FF

; A = key code -> NZ if held (the latch must be on)
keytest:
        push bc
        ld b,a
        ld a,$12
        out (P_CRTCA),a
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and $03
        out (P_CRTCD),a
        ld a,$13
        out (P_CRTCA),a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        and $F0
        out (P_CRTCD),a
        ld a,$10
        out (P_CRTCA),a
        in a,(P_CRTCD)          ; clear any pending light pen strobe
        ld a,$1F
        out (P_CRTCA),a
        out (P_CRTCD),a
        nop
        ld b,0
.w:     in a,(P_CRTCA)
        bit 7,a
        jr nz,.d
        djnz .w
.d:     and $40
        pop bc
        ret

read_input:
        ld a,1
        out (P_ROMLAT),a
        xor a
        ld (rk_pad),a
        ld (rk_pad+1),a
        ld hl,keymap
.scan:  ld a,(hl)
        cp $FF
        jr z,.done
        inc hl
        call keytest
        jr z,.nk
        ld e,(hl)
        ld d,0
        inc hl
        ld a,(hl)
        dec hl
        push hl
        ld hl,rk_pad
        add hl,de
        or (hl)
        ld (hl),a
        pop hl
.nk:    inc hl
        inc hl
        jr .scan
.done:  xor a
        out (P_ROMLAT),a
        ld a,(joyon)
        or a
        call nz,read_joy
        ld hl,rk_pad
        or (hl)
        ld (hl),a
        ld a,(rk_pad)
        ld hl,pad
        call .edge
        ld a,(rk_pad+1)
        ld hl,keys
.edge:  ld b,a
        ld a,(hl)
        cpl
        and b
        inc hl
        or (hl)
        ld (hl),a
        dec hl
        ld (hl),b
        ret

; joystick on PIO A (active low): b0 up b1 down b2 left b3 right b7 fire
read_joy:
        in a,(P_PIOA)
        cpl
        ld b,a
        and $0F
        cp $0F                  ; all four at once (nothing fitted): ignore
        jr z,.none
        ld c,0
        bit 0,b
        jr z,.a
        set 2,c
.a:     bit 1,b
        jr z,.b
        set 3,c
.b:     bit 2,b
        jr z,.c
        set 1,c
.c:     bit 3,b
        jr z,.d
        set 0,c
.d:     bit 7,b
        jr z,.e
        set 4,c
.e:     ld a,c
        ret
.none:  xor a
        ret
; J: PIO A to input mode and the joystick on (or off again)
joy_toggle:
        ld a,(joyon)
        xor 1
        ld (joyon),a
        ret z
        ld a,$CF
        out (P_PIOAC),a
        ld a,$FF
        out (P_PIOAC),a
        ld a,$07
        out (P_PIOAC),a
        ret

; any key at all held? (codes 0..63) -> A = code + 1, or 0
any_key:
        ld a,1
        out (P_ROMLAT),a
        ld c,0
.k:     ld a,c
        call keytest
        jr nz,.hit
        inc c
        ld a,c
        cp 64
        jr nz,.k
        xor a
        out (P_ROMLAT),a
        ret
.hit:   xor a
        out (P_ROMLAT),a
        ld a,c
        inc a
        ret
