; =====================================================================
;  INPUT: keyboard (6545 light-pen scan, as the boot ROM does) through a
;  key map built from the chosen preset, plus the joystick on PIO A.
;   pad:  b0 R  b1 L  b2 U  b3 D  b4 FIRE      (movement + fire)
;   aim:  b0 R  b1 L  b2 U  b3 D               (twin-stick: shoot that way)
;   keys: b0 BREACH b1 EJECT b2 MAP b3 PAUSE b4 RETURN b5 EMP b6 ESC b7 Y
;  *new = newly pressed since the logic last took them (input_used).
; =====================================================================
K_A     equ 1
K_B     equ 2
K_C     equ 3
K_D     equ 4
K_E     equ 5
K_H     equ 8
K_I     equ 9
K_J     equ 10
K_K     equ 11
K_L     equ 12
K_M     equ 13
K_N     equ 14
K_O     equ 15
K_P     equ 16
K_Q     equ 17
K_S     equ 19
K_W     equ 23
K_X     equ 24
K_Y     equ 25
K_ESC   equ $30
K_RET   equ $34
K_SPACE equ $37
K_UP    equ $38
K_DOWN  equ $3A
K_LEFT  equ $3B
K_RIGHT equ $3E

; presets: key code, target (0 pad, 1 aim, 2 keys), bit mask
km_arrows:
        db K_RIGHT,0,1, K_LEFT,0,2, K_UP,0,4, K_DOWN,0,8, K_SPACE,0,16
        db K_D,1,1, K_A,1,2, K_W,1,4, K_S,1,8
        db $FF
km_qaop:
        db K_P,0,1, K_O,0,2, K_Q,0,4, K_A,0,8, K_SPACE,0,16
        db K_L,1,1, K_J,1,2, K_I,1,4, K_K,1,8
        db $FF
; keys common to every preset
km_common:
        db K_B,2,1, K_E,2,2, K_M,2,4, K_H,2,8, K_RET,2,16, K_X,2,32, K_ESC,2,64, K_Y,2,128
        db $FF

; build the key map from (preset): 0 arrows, 1 QAOP, 2 custom
keys_build:
        ld de,keymap
        ld a,(preset)
        cp 2
        jr z,.custom
        ld hl,km_arrows
        or a
        jr z,.cp
        ld hl,km_qaop
.cp:    call .copy
        jr .common
.custom:
        ld hl,ck_custom
        ld bc,$0004             ; up, down, left, right -> pad bits 4, 8, 2, 1
        ld a,(hl)
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ld a,4
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ld a,8
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ld a,2
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ld a,1
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        ld a,16
        ld (de),a
        inc de
        inc hl
        ld a,(hl)               ; breach key
        ld (de),a
        inc de
        ld a,2
        ld (de),a
        inc de
        ld a,1
        ld (de),a
        inc de
.common:
        ld hl,km_common
        call .copy
        ld a,$FF
        ld (de),a
        ret
.copy:  ld a,(hl)
        cp $FF
        ret z
        ldi
        ldi
        ldi
        jr .copy

; default custom keys: arrows, SPACE, B
ck_default:
        db K_UP,K_DOWN,K_LEFT,K_RIGHT,K_SPACE,K_B

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
        ld a,(demo_on)
        or a
        jp nz,demo_input
        ld a,1
        out (P_ROMLAT),a
        xor a
        ld (rk_pad),a
        ld (rk_pad+1),a
        ld (rk_pad+2),a
        ld hl,keymap
.k:     ld a,(hl)
        cp $FF
        jr z,.kd
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
        jr .k
.kd:    xor a
        out (P_ROMLAT),a
        call read_joy
        ld hl,rk_pad
        or (hl)
        ld (hl),a
        ld a,(rec_on)
        or a
        call nz,rec_input
set_edges:
        ld a,(rk_pad)
        ld hl,pad
        call .edge
        ld a,(rk_pad+1)
        ld hl,aim
        call .edge
        ld a,(rk_pad+2)
        ld hl,keys
        ; fall through
.edge:  ld b,a
        ld a,(hl)
        cpl
        and b
        inc hl
        or (hl)                 ; edges add up until a logic step takes them
        ld (hl),a
        dec hl
        ld (hl),b
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
        ld (aimnew),a
        ld (keysnew),a
        ret

; any "go" press: fire / RETURN -> NZ
check_start:
        ld a,(padnew)
        and $10
        ret nz
        ld a,(keysnew)
        and $10
        ret

; any key or button at all held -> NZ (attract mode exit)
any_input:
        ld a,(pad)
        ld hl,aim
        or (hl)
        ld hl,keys
        or (hl)
        ret

; ---- attract-mode demo: the recorded inputs replace the keyboard. The
; recording is three bytes a logic step (pad, aim, keys) in BLK_DEMO;
; a real key press ends the demo (checked by the caller with the
; keyboard read directly).
demo_input:
        ld a,(curblk)
        push af
        ld a,BLK_DEMO
        call map_blk
        ld hl,(demo_ptr)
        ld a,(hl)
        cp $FF
        jr nz,.go
        ld (demo_on),a          ; end of the recording: $FF = finished
        xor a
        ld (rk_pad),a
        ld (rk_pad+1),a
        ld (rk_pad+2),a
        jr .x
.go:    ld (rk_pad),a
        inc hl
        ld a,(hl)
        ld (rk_pad+1),a
        inc hl
        ld a,(hl)
        ld (rk_pad+2),a
        inc hl
        ld (demo_ptr),hl
.x:     pop af
        call map_port
        jp set_edges

; recording (used to make the attract demo, from the emulator)
rec_input:
        ld a,(curblk)
        push af
        ld a,BLK_DEMO
        call map_blk
        ld hl,(rec_ptr)
        ld a,h
        cp $7F
        jr nc,.x
        ld a,(rk_pad)
        ld (hl),a
        inc hl
        ld a,(rk_pad+1)
        ld (hl),a
        inc hl
        ld a,(rk_pad+2)
        ld (hl),a
        inc hl
        ld (hl),$FF
        ld (rec_ptr),hl
.x:     pop af
        jp map_port
