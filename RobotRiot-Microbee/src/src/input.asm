; =====================================================================
;  INPUT: keyboard (6545 light-pen scan, as the boot ROM does) and the
;  joystick on PIO A.
;   pad:     b0 R  b1 L  b2 U  b3 D (move)  b4 FIRE (SPACE / joystick)
;   firepad: b0 R  b1 L  b2 U  b3 D (fire: I J K L or the arrow keys)
;   keys:    b0 ESC  b1 P (pause)  b2 M (sound)  b3 START (SPACE / RETURN)
;  *new = newly pressed since the logic last took them (input_used).
; =====================================================================
K_ESC   equ $30
K_RET   equ $34
K_SPACE equ $37
K_UP    equ $38
K_DOWN  equ $3A
K_LEFT  equ $3B
K_RIGHT equ $3E

; key code, target (0 pad, 1 firepad, 2 keys), bit mask
keymap:
        db 4,0,1, 1,0,2, 23,0,4, 19,0,8                 ; D A W S: move
        db 12,1,1, 10,1,2, 9,1,4, 11,1,8                ; L J I K: fire
        db K_RIGHT,1,1, K_LEFT,1,2, K_UP,1,4, K_DOWN,1,8 ; arrows: fire
        db K_SPACE,0,16, K_SPACE,2,8, K_RET,2,8
        db K_ESC,2,1, 16,2,2, 13,2,4                    ; ESC P M
        db $FF

; A = key code -> NZ if held (latch must be on)
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
        ld (rk),a
        ld (rk+1),a
        ld (rk+2),a
        ld hl,keymap
.s:     ld a,(hl)
        cp $FF
        jr z,.d
        inc hl
        call keytest
        jr z,.nk
        ld e,(hl)
        ld d,0
        inc hl
        ld a,(hl)
        dec hl
        push hl
        ld hl,rk
        add hl,de
        or (hl)
        ld (hl),a
        pop hl
.nk:    inc hl
        inc hl
        jr .s
.d:     xor a
        out (P_ROMLAT),a
        call read_joy
        ld hl,rk
        or (hl)
        ld (hl),a
        ld b,a                  ; pad edges add up until the logic takes them
        ld a,(pad)
        cpl
        and b
        ld c,a
        ld a,(padnew)
        or c
        ld (padnew),a
        ld a,b
        ld (pad),a
        ld a,(rk+1)
        ld (firepad),a
        ld a,(rk+2)
        ld b,a
        ld a,(keys)
        cpl
        and b
        ld c,a
        ld a,(keysnew)
        or c
        ld (keysnew),a
        ld a,b
        ld (keys),a
        ret

; joystick on PIO A (active low): b0 up b1 down b2 left b3 right b7 fire -> pad bits
read_joy:
        in a,(P_PIOA)
        cpl
        ld b,a
        and $0F
        cp $0F                  ; all four (or nothing fitted): ignore
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

; the logic took this frame's edges
input_used:
        xor a
        ld (padnew),a
        ld (keysnew),a
        ret
