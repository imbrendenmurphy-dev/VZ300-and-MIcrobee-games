; =====================================================================
;  INPUT: the keyboard (the 6545 light-pen scan, as the boot ROM does it)
;  and a joystick on PIO A.
;   pad:  b0 right  b1 left  b2 up  b3 down  b4 fire
;         b5 sweep clockwise  b6 sweep anticlockwise
;   keys: b0 ESC  b1 H (pause)  b2 S (sound)  b3 C  b4 M  b5 R (restart)
;  padnew / keysnew = newly pressed since the logic last took them.
; =====================================================================
PAD_CW      EQU 5
PAD_ACW     EQU 6

; key code, target (0 pad, 1 keys), bit mask
keymap:
        db K_RIGHT,0,1, K_LEFT,0,2, K_UP,0,4, K_DOWN,0,8
        db K_P,0,1, K_O,0,2, K_Q,0,4, K_A,0,8
        db K_SPACE,0,16, K_Z,0,32, K_X,0,64
        db $FE                  ; the rest, every fourth frame
        db K_ESC,1,1, K_H,1,2, K_S,1,4, K_C,1,8, K_M,1,16, K_R,1,32
        db $FF

; A = key code -> NZ if held (the keyboard latch must be on)
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
        ld a,(frameno)
        and 3
        jr nz,.k0
        ld (rk_keys),a
.k0:    ld hl,keymap
.scan:  ld a,(hl)
        cp $FF
        jr z,.done
        inc hl
        cp $FE
        jr nz,.key
        ld a,(frameno)
        and 3
        jr z,.scan
        ld a,(rk_keys)          ; keep last time's
        ld (rk_keys),a
        jr .done
.key:
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
        call read_joy
        ld hl,rk_pad
        or (hl)
        ld (hl),a
        ; edges, gathered until the logic takes them
        ld a,(rk_pad)
        ld hl,pad
        call .edge
        ld a,(rk_keys)
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

input_used:
        xor a
        ld (padnew),a
        ld (keysnew),a
        ret

; NZ if fire or SPACE newly pressed
fire_new:
        ld a,(padnew)
        and 16
        ret
