; =====================================================================
;  INPUT: the keyboard (the 6545 light-pen scan, as the boot ROM does it)
;  and a joystick on PIO A.
;  held:  b0 forward  b1 back  b2 turn left  b3 turn right
;         b4 step left  b5 step right  b6 act (SPACE / fire)
;  cmd:   the newest command key pressed (ASCII-ish code), 0 = none
; =====================================================================
IN_FWD      EQU 0
IN_BACK     EQU 1
IN_LEFT     EQU 2
IN_RIGHT    EQU 3
IN_SLEFT    EQU 4
IN_SRIGHT   EQU 5
IN_ACT      EQU 6

; key code, held bit mask
movekeys:
        db K_UP,1, K_W,1, K_DOWN,2, K_S,2, K_LEFT,4, K_A,4, K_RIGHT,8, K_D,8
        db K_Q,16, K_Z,16, K_E,32, K_X,32, K_SPACE,64, K_RET,64
        db $FF
; key code, command
cmdkeys:
        db K_1,'1', K_2,'2', K_3,'3', K_M,'M', K_T,'T', K_ESC,27, K_P,'P', K_Y,'Y', K_N,'N', K_H,'H'
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

; once a frame
read_input:
        ld a,1
        out (P_ROMLAT),a
        ld c,0
        ld hl,movekeys
.m:     ld a,(hl)
        cp $FF
        jr z,.cmd
        inc hl
        call keytest
        jr z,.mn
        ld a,(hl)
        or c
        ld c,a
.mn:    inc hl
        jr .m
.cmd:   ld hl,cmdkeys
        ld e,0
.c:     ld a,(hl)
        cp $FF
        jr z,.cd
        inc hl
        call keytest
        jr z,.cn
        ld e,(hl)
.cn:    inc hl
        jr .c
.cd:    xor a
        out (P_ROMLAT),a
        ; a command: on its first frame only
        ld a,(cmdheld)
        cp e
        ld a,e
        ld (cmdheld),a
        jr z,.j
        or a
        jr z,.j
        ld (cmd),a
.j:     call read_joy
        or c
        ld c,a
        ld a,(held)
        cpl
        and c
        ld b,a
        ld a,(pressed)
        or b
        ld (pressed),a          ; new presses, until the logic takes them
        ld a,c
        ld (held),a
        ret

; joystick on PIO A (active low): b0 up b1 down b2 left b3 right b7 fire
read_joy:
        in a,(P_PIOA)
        cpl
        ld b,a
        and $0F
        cp $0F                  ; all four (or nothing fitted): ignore
        jr z,.none
        ld a,b
        and $0F
        bit 7,b
        ret z
        or 64
        ret
.none:  xor a
        ret

; any key or button newly pressed? NZ = yes (clears them)
any_new:
        ld a,(cmd)
        ld b,a
        ld a,(pressed)
        or b
        push af
        xor a
        ld (cmd),a
        ld (pressed),a
        pop af
        ret
