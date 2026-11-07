; ===================================================================
;  input.asm - keyboard via the 6545 light-pen matrix scan
;  Procedure: R18/R19 = keycode<<4, write R31 to strobe, wait for status
;  bit 7 (update), then status bit 6 (light pen) set = key down.
; ===================================================================

key_test:                       ; sequence as used by the BIOS and The Lantern Deep
        push bc
        ld b,a
        ld a,10h
        out (P_CRTCA),a
        in a,(P_CRTCD)
        ld a,11h
        out (P_CRTCA),a
        in a,(P_CRTCD)
        ld a,12h
        out (P_CRTCA),a
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and 03h
        out (P_CRTCD),a
        ld a,13h
        out (P_CRTCA),a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        and 0F0h
        out (P_CRTCD),a
        ld a,1Fh
        out (P_CRTCA),a
        out (P_CRTCD),a
        nop
        ld b,0
.w:     in a,(P_CRTCA)
        bit 7,a
        jr nz,.d
        djnz .w
.d:     and 40h
        pop bc
        ret

; table of keys scanned each frame -> bitmap keys_now (4 bytes = 32 keys)
KEYTAB:
        db K_W,K_A,K_S,K_D,K_F,K_L,K_S,K_G              ; 0-3 movement, 4 F file, 5 L load, 6 S save
        db K_SPACE,K_RET,K_ESC,K_TAB,K_M,K_C,K_P,K_SHIFT  ; 8-15
        db K_1,K_1+1,K_1+2,K_1+3,K_1+4,K_1+5,K_1+6,K_1+7  ; 16-23 '1'-'8'
        db K_1+8,K_0,K_COMMA,K_DOT,K_H,K_Q,K_Y,K_N         ; 24-31
        db K_UP,K_LEFT,K_DOWN,K_RIGHT,K_RET,K_RET,K_RET,K_RET  ; 32-39 cursor keys
NKEYS   equ 40
KB_UP   equ 0
KB_LEFT equ 1
KB_DOWN equ 2
KB_RIGHT equ 3
KB_FILE equ 4
KB_LOAD equ 5
KB_SAVE equ 6
KB_SPACE equ 8
KB_RET  equ 9
KB_ESC  equ 10
KB_TAB  equ 11
KB_MAP  equ 12
KB_COL  equ 13
KB_PAUSE equ 14
KB_SHIFT equ 15
KB_1    equ 16
KB_0    equ 25
KB_SLOW equ 26
KB_FAST equ 27
KB_HELP equ 28
KB_Q    equ 29
KB_Y    equ 30
KB_N    equ 31

; scan all keys: keys_prev <- keys_now, keys_now <- scan; keys_hit = now & ~prev
scan_keys:
        ld hl,keys_now
        ld de,keys_prev
        ld bc,5
        ldir
        ld a,1
        out (P_ROMLAT),a
        ld ix,KEYTAB
        ld hl,keys_now
        ld c,5
.byte:  ld b,8
        ld e,0
.bit:   push hl
        push bc
        push de
        call mouse_poll         ; keep listening between key tests
        pop de
        pop bc
        pop hl
        ld a,1
        out (P_ROMLAT),a
        ld a,(ix+0)
        inc ix
        call key_test
        jr z,.up
        scf
        jr .sh
.up:    or a
.sh:    rr e
        djnz .bit
        ld (hl),e
        inc hl
        dec c
        jr nz,.byte
        xor a
        out (P_ROMLAT),a
        ; cursor keys -> same bits as W A S D
        ld a,(keys_now+4)
        and 0Fh
        ld b,a
        ; joystick on PIO A (reads 00 when none fitted)
        in a,(P_PIOA)
        or a
        jr z,.nj
        cpl
        ld c,a
        ; remap: KEYTAB order is up,left,down,right
        ld e,0
        bit 0,c
        jr z,.j1
        set 0,e
.j1:    bit 2,c
        jr z,.j2
        set 1,e
.j2:    bit 1,c
        jr z,.j3
        set 2,e
.j3:    bit 3,c
        jr z,.j4
        set 3,e
.j4:    ld a,e
        or b
        ld b,a
        bit 7,c                 ; fire = SPACE
        jr z,.nj
        ld a,(keys_now+1)
        set 0,a
        ld (keys_now+1),a
.nj:    ld a,(keys_now)
        or b
        ld (keys_now),a
        ; hits
        ld hl,keys_now
        ld de,keys_prev
        ld ix,keys_hit
        ld b,5
.h:     ld a,(de)
        cpl
        and (hl)
        ld (ix+0),a
        inc hl
        inc de
        inc ix
        djnz .h
        ret

; key_down: A = KB_ index -> NZ if held
key_down:
        ld hl,keys_now
        jr key_bit
; key_hit: A = KB_ index -> NZ if newly pressed this frame
key_hit:
        ld hl,keys_hit
key_bit:
        push bc
        ld b,a
        srl a
        srl a
        srl a
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,b
        and 7
        ld b,a
        ld a,(hl)
        inc b
.s:     dec b
        jr z,.t
        rrca
        jr .s
.t:     and 1
        pop bc
        ret

; any key newly hit? -> NZ
any_hit:
        ld hl,keys_hit
        ld a,(hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        ret

; wait until all scanned keys released
wait_release:
        call wait_frame
        call scan_keys
        ld hl,keys_now
        ld a,(hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        jr nz,wait_release
        ret

