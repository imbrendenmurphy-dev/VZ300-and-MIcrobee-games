; =====================================================================
;  CORE: hardware set-up, banking, frame timing + the beeper during
;  idle time, keyboard and joystick, random numbers, unpacking.
;  Interrupts stay off all the time (DI), as in the VZ original.
; =====================================================================

hw_init:
        di
        ld hl,vars_start
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld a,2
        ld (steps),a
        ; PIO A: input (joystick)
        ld a,$CF
        out (P_PIOAC),a
        ld a,$FF
        out (P_PIOAC),a
        ld a,$07
        out (P_PIOAC),a
        ; PIO B: bit control, b6 speaker out, no interrupts
        ld a,$CF
        out (P_PIOBC),a
        ld a,$BF
        out (P_PIOBC),a
        ld a,$07
        out (P_PIOBC),a
        xor a
        out (P_PIOB),a
        out (P_ROMLAT),a
        out (P_COLCTL),a
        ld a,BLK_RT
        call map_blk
        ld hl,0                 ; the RT block: lists, flags (all clear)
        ld de,1
        ld bc,RT_END-1
        ld (hl),0
        ldir
        ld hl,cellmap
        ld de,cellmap+1
        ld bc,$3FF
        ld (hl),0
        ldir
        call crtc_game
        ret

; 64 x 16 characters of 16 lines
crtc_game:
        ld hl,crtc_tab
        ld c,0
.ci:    ld a,c
        out (P_CRTCA),a
        ld a,(hl)
        out (P_CRTCD),a
        inc hl
        inc c
        ld a,c
        cp 16
        jr nz,.ci
        ret
crtc_tab:       db $6B,$40,$51,$37,$12,$09,$10,$12,$48,$0F,$20,$0F,$00,$00,$00,$00

; A = block -> A = port 50h value (ROMs off, video window at F000)
bank_port:
        push bc
        ld b,a
        and 3
        xor 2
        ld c,a
        ld a,b
        and $1C
        rlca
        rlca
        rlca
        or c
        or 4
        pop bc
        ret
; map block A into the lower window (remembered in curblk as a port value)
map_blk:
        call bank_port
map_port:
        out (P_MEM),a
        ld (curblk),a
        ret

; copy BC bytes from block A offset HL to block (cb_dst) offset DE,
; through a 256-byte bounce buffer in the upper block
blk_copy:
        ld (cb_src),a
        ld a,(curblk)
        push af
.ch:    ld a,b
        or c
        jr z,.done
        push bc
        ld a,b
        or a
        jr z,.small
        ld bc,256
.small: push bc
        ld a,(cb_src)
        call map_blk
        push de
        ld de,bounce
        push bc
        ldir
        pop bc
        pop de
        push hl
        ld a,(cb_dst)
        call map_blk
        ld hl,bounce
        ldir
        pop hl
        pop bc
        ex (sp),hl
        or a
        sbc hl,bc
        ld b,h
        ld c,l
        pop hl
        jr .ch
.done:  pop af
        jp map_port

; ---------------------------------------------------------------------
;  frame timing: rising edges of the 6545 vertical blanking status
; ---------------------------------------------------------------------
vschk:  in a,(P_CRTCA)
        and $20
        jr z,.lo
        ld a,(vblast)
        or a
        ret nz
        ld a,$20
        ld (vblast),a
        ld a,(vcount)
        inc a
        ld (vcount),a
        ret
.lo:    ld (vblast),a
        ret

; ---------------------------------------------------------------------
; frame_wait: the 2-channel pin-pulse beeper (from TENNIS II on the VZ)
; plays until (vcount) reaches A fields since the last frame. Loop = 127 T
; (26.6 kHz). Channel 1 = acc1/step1, channel 2 = acc2/step2.
; Noise mode: channel 2 pulses when a byte of the program is below D'.
; ---------------------------------------------------------------------
frame_wait:
        ld (fw_need),a
        call vschk
        ld a,(vcount)
        ld hl,fw_need
        cp (hl)
        jp nc,.done
        ld a,(noiseon)
        or a
        jp nz,fw_noise
        ld hl,(acc1)
        ld de,(step1)
        exx
        ld hl,(acc2)
        ld de,(step2)
        ld a,(vblast)
        ld c,a                  ; C' = last vblank level
        exx
.lp:    add hl,de               ; 11  channel 1
        sbc a,a                 ; 4
        and $40                 ; 7
        ld b,a                  ; 4
        exx                     ; 4
        add hl,de               ; 11  channel 2
        sbc a,a                 ; 4
        and $40                 ; 7
        exx                     ; 4
        or b                    ; 4
        out (P_PIOB),a          ; 11
        nop                     ; 4 x 4: the same 127 T as the noise loop
        nop
        nop
        nop
        in a,(P_CRTCA)          ; 11
        and $20                 ; 7
        exx                     ; 4
        cp c                    ; 4
        exx                     ; 4
        jp z,.lp                ; 10 = 127 T
        exx
        ld c,a
        exx
        or a
        jr z,.lp                ; falling edge: keep going
        ld a,(vcount)           ; rising edge: one more field
        inc a
        ld (vcount),a
        push hl
        ld hl,fw_need
        cp (hl)
        pop hl
        jr c,.lp
        exx
        ld a,c
        ld (vblast),a
        exx
        xor a
        out (P_PIOB),a
        ld (acc1),hl
        exx
        ld (acc2),hl
        exx
.done:  ld a,(vcount)
        ld hl,fw_need
        sub (hl)
        cp 2
        jr c,.k
        ld a,1
.k:     ld (vcount),a
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
        ret

fw_noise:
        ld hl,(acc1)
        ld de,(step1)
        exx
        ld hl,(acc2)
        ld a,h
        and $3F
        or $80
        ld h,a                  ; walk the program bytes $8000-$BFFF
        ld de,(step2)           ; D' = density
        ld a,(vblast)
        ld c,a
        exx
.lp:    add hl,de               ; channel 1
        sbc a,a
        and $40
        ld b,a
        exx
        ld a,(hl)
        inc hl
        res 6,h
        cp d
        sbc a,a
        and $40
        exx
        or b
        out (P_PIOB),a
        exx
        in a,(P_CRTCA)
        and $20
        cp c
        exx
        jr z,.lp                ; = 127 T
        exx
        ld c,a
        exx
        or a
        jr z,.lp
        ld a,(vcount)
        inc a
        ld (vcount),a
        push hl
        ld hl,fw_need
        cp (hl)
        pop hl
        jr c,.lp
        exx
        ld a,c
        ld (vblast),a
        exx
        xor a
        out (P_PIOB),a
        ld (acc1),hl
        exx
        set 7,h
        ld (acc2),hl
        exx
        jp frame_wait.done

; ---------------------------------------------------------------------
;  keyboard (6545 light-pen scan, as the boot ROM does) and joystick
; ---------------------------------------------------------------------
; A = Microbee key code -> NZ if held (latch must be on: kb_on)
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

K_A     equ 1
K_C     equ 3
K_D     equ 4
K_H     equ 8
K_I     equ 9
K_J     equ 10
K_K     equ 11
K_L     equ 12
K_M     equ 13
K_N     equ 14
K_P     equ 16
K_Q     equ 17
K_S     equ 19
K_X     equ 24
K_Y     equ 25
K_COMMA equ $2C
K_ESC   equ $30
K_RET   equ $34
K_SPACE equ $37
K_UP    equ $38
K_DOWN  equ $3A
K_LEFT  equ $3B
K_RIGHT equ $3E

; table: key code, pad (0 = pad 1, 1 = pad 2, 2 = keys), bit
keymap:
        db K_Q,0,2, K_A,0,3, K_M,0,1, K_COMMA,0,0, K_SPACE,0,4
        db K_UP,0,2, K_DOWN,0,3, K_LEFT,0,1, K_RIGHT,0,0
        db K_I,1,2, K_K,1,3, K_J,1,1, K_L,1,0, K_H,1,4
        db K_S,2,0, K_P,2,1, K_RET,2,2, K_X,2,3, K_N,2,4, K_C,2,5, K_ESC,2,6, K_Y,2,7
        db $FF

; read_input: pad bits 0 R, 1 L, 2 U, 3 D, 4 FIRE.
;  pad1 = Q A M , SPACE + arrow keys (+ the joystick, except in a 2-player game)
;  pad2 = I K J L + H (+ the joystick in a 2-player game)
;  inp/inpnew = both pads (menus, 1-player game)
;  keys/keysnew: b0 S, b1 P, b2 RETURN, b3 X, b4 N, b5 C, b6 ESC, b7 Y
read_input:
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
        ld b,(hl)
        dec hl
        push hl
        ld hl,rk_pad
        add hl,de
        ld a,1
        inc b
.sh:    dec b
        jr z,.st
        add a,a
        jr .sh
.st:    or (hl)
        ld (hl),a
        pop hl
.nk:    inc hl
        inc hl
        jr .k
.kd:    xor a
        out (P_ROMLAT),a
        call read_joy
        ld b,a
        ld a,(twoplayer)
        or a
        ld hl,rk_pad
        jr z,.j1
        inc hl
.j1:    ld a,(hl)
        or b
        ld (hl),a
        ; edges
        ld a,(rk_pad)
        ld hl,pad1
        call .edge
        ld a,(rk_pad+1)
        ld hl,pad2
        call .edge
        ld a,(rk_pad+2)
        ld hl,keys
        call .edge
        ld a,(pad1)
        ld b,a
        ld a,(pad2)
        or b
        ld c,a
        ld a,(pad1new)
        ld b,a
        ld a,(pad2new)
        or b
        ld (inpnew),a
        ld a,c
        ld (inp),a
        ret
; (HL) = current, (HL+1) = new edges: A = this frame's bits
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
        cp $0F                  ; all four (or nothing fitted, reading 00): ignore
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
        ld (pad1new),a
        ld (pad2new),a
        ld (keysnew),a
        ld (inpnew),a
        ret

; start pressed? (SPACE / fire / RETURN) -> NZ if newly pressed
check_start:
        ld a,(inpnew)
        and $10
        ret nz
        ld a,(keysnew)
        and $04
        ret

; ---------------------------------------------------------------------
random:
        ld hl,(seed)
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
        ld (seed),hl
        ld a,l
        xor h
        ret
; random below B (B >= 1) -> A
rand_n:
        push bc
        call random
        pop bc
.m:     cp b
        ret c
        sub b
        jr .m

; ---- LZB unpack: HL = packed source, DE = destination (tools/lzb.py)
unlzb:  ld (lzb_tab),hl
        ld bc,16
        add hl,bc
        ld a,(hl)
        ld (lzb_n),a
        inc hl
        ld a,(hl)
        ld (lzb_n+1),a
        inc hl
        ld c,$80
.loop:  push hl
        ld hl,(lzb_n)
        ld a,h
        or l
        pop hl
        ret z
        call gbit
        jr c,.match
        call gbit
        jr c,.lit8
        ld b,4
        call gbits
        push hl
        ld hl,(lzb_tab)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        jr .put
.lit8:  ld b,8
        call gbits
.put:   ld (de),a
        inc de
        push hl
        ld hl,(lzb_n)
        dec hl
        ld (lzb_n),hl
        pop hl
        jr .loop
.match: ld b,1
.gz:    call gbit
        jr c,.g1
        inc b
        jr .gz
.g1:    ld a,1
        dec b
        jr z,.gd
.gl:    call gbit
        rla
        djnz .gl
.gd:    inc a
        ld (lzb_len),a
        call gbit
        jr c,.o12
        ld b,7
        call gbits
        ld b,0
        jr .od
.o12:   ld b,4
        call gbits
        ld (lzb_hi),a
        ld b,8
        call gbits
        push af
        ld a,(lzb_hi)
        ld b,a
        pop af
.od:    push hl
        push bc
        ld c,a
        ld a,e
        sub c
        ld l,a
        ld a,d
        sbc a,b
        ld h,a
        dec hl
        pop bc
        push bc
        ld a,(lzb_len)
        ld c,a
        ld b,0
        ldir
        pop bc
        ld hl,(lzb_n)
        ld a,(lzb_len)
        push de
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld (lzb_n),hl
        pop de
        pop hl
        jp .loop
gbits:  xor a
.l:     call gbit
        rla
        djnz .l
        ret
gbit:   sla c
        ret nz
        ld c,(hl)
        inc hl
        scf
        rl c
        ret

; ---- LZB unpack across blocks: packed data at HL in block A, written to
; DE in the block that is mapped now (the source is read through lzx_buf)
unlzb_x:
        ld (lzx_sblk),a
        ld (lzx_src),hl
        ld a,(curblk)
        ld (lzx_dblk),a
        ld hl,lzx_buf+256
        ld (lzx_ptr),hl         ; empty: refill on the first byte
        ld hl,lzx_tab
        ld b,16
.t:     call lzx_get
        ld (hl),a
        inc hl
        djnz .t
        call lzx_get
        ld (lzb_n),a
        call lzx_get
        ld (lzb_n+1),a
        ld c,$80
.loop:  ld hl,(lzb_n)
        ld a,h
        or l
        ret z
        call gbx
        jr c,.match
        call gbx
        jr c,.lit8
        ld b,4
        call gbxs
        ld hl,lzx_tab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        jr .put
.lit8:  ld b,8
        call gbxs
.put:   ld (de),a
        inc de
        ld hl,(lzb_n)
        dec hl
        ld (lzb_n),hl
        jr .loop
.match: ld b,1
.gz:    call gbx
        jr c,.g1
        inc b
        jr .gz
.g1:    ld a,1
        dec b
        jr z,.gd
.gl:    call gbx
        rla
        djnz .gl
.gd:    inc a
        ld (lzb_len),a
        call gbx
        jr c,.o12
        ld b,7
        call gbxs
        ld b,0
        jr .od
.o12:   ld b,4
        call gbxs
        ld (lzb_hi),a
        ld b,8
        call gbxs
        push af
        ld a,(lzb_hi)
        ld b,a
        pop af
.od:    push bc
        ld c,a
        ld a,e
        sub c
        ld l,a
        ld a,d
        sbc a,b
        ld h,a
        dec hl
        ld a,(lzb_len)
        ld c,a
        ld b,0
        ldir
        pop bc
        ld hl,(lzb_n)
        ld a,(lzb_len)
        push de
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld (lzb_n),hl
        pop de
        jp .loop
gbxs:   xor a
.l:     call gbx
        rla
        djnz .l
        ret
gbx:    sla c
        ret nz
        ld (gbx_a),a
        call lzx_get
        scf
        rla
        ld c,a
        ld a,(gbx_a)            ; (keeps the carry)
        ret
; next packed byte -> A (and lzx_last); keeps BC, DE, HL
lzx_get:
        push hl
        ld hl,(lzx_ptr)
        ld a,l
        or a
        jr nz,.have
        ld a,h
        cp (lzx_buf+256)/256
        jr nz,.have
        ; refill 256 bytes from the source block
        push bc
        push de
        ld a,(lzx_sblk)
        call map_blk
        ld hl,(lzx_src)
        ld de,lzx_buf
        ld bc,256
        ldir
        ld (lzx_src),hl
        ld a,(lzx_dblk)
        call map_port
        pop de
        pop bc
        ld hl,lzx_buf
.have:  ld a,(hl)
        inc hl
        ld (lzx_ptr),hl
        ld (lzx_last),a
        pop hl
        ret
