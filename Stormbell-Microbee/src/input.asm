; =====================================================================
;  INPUT: the keyboard (6545 light pen scan, as the boot ROM does) and
;  a joystick on PIO port A. Read every field (50 times a second);
;  presses are remembered in (padnew) until the game logic takes them,
;  so a quick tap between two logic ticks is never lost.
;
;   pad: b0 advance  b1 retreat  b2 guard  b3 punch  b4 kick
;        b5 start (SPACE / RETURN)  b6 ESC  b7 P (pause)
; =====================================================================
keymap: db K_D,1, K_RIGHT,1
        db K_A,2, K_LEFT,2
        db K_S,4, K_DOWN,4
        db K_K,8
        db K_L,16, K_UP,16
        db K_SPACE,32, K_RET,32
        db K_ESC,64
        db K_P,128
        db $FF

; A = key code -> NZ if held (the ROM latch must be on)
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
        ld c,0
        ld hl,keymap
.scan:  ld a,(hl)
        cp $FF
        jr z,.end
        inc hl
        call keytest
        jr z,.nk
        ld a,(hl)
        or c
        ld c,a
.nk:    inc hl
        jr .scan
.end:   xor a
        out (P_ROMLAT),a
        ; joystick (active low): b0 up b1 down b2 left b3 right b7 fire
        in a,(P_PIOA)
        cpl
        ld b,a
        and $8F
        jr z,.nojoy
        ld a,b
        cp $FF                  ; nothing plugged in reads all low
        jr z,.nojoy
        bit 3,b
        jr z,.j1
        set PB_FWD,c
.j1:    bit 2,b
        jr z,.j2
        set PB_BACK,c
.j2:    bit 1,b
        jr z,.j3
        set PB_GUARD,c
.j3:    bit 0,b
        jr z,.j4
        set PB_KICK,c
.j4:    bit 7,b
        jr z,.nojoy
        set PB_PUNCH,c
        set PB_START,c
.nojoy: ld hl,pad
        ld a,(hl)
        cpl
        and c                   ; newly down
        ld (hl),c
        inc hl
        or (hl)
        ld (hl),a               ; (padnew) gathers until taken
        ret

; take the presses gathered so far -> A
take_new:
        ld hl,padnew
        ld a,(hl)
        ld (hl),0
        ret
