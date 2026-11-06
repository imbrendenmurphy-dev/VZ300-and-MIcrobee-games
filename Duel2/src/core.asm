; =====================================================================
;  DUEL II - core: frame sync + beeper, input, random, text, and the
;  snow-free display engine.
;
;  Three screen-sized pictures:
;    VRAM ($7000)  what you see - written ONLY in vblank, by commit
;    FBUF ($F800)  the finished frame, composed during the frame
;    BBUF ($F000)  the backdrop (terrain + HUD) used to erase objects
;  Every change to FBUF marks the byte-span it touched on its row in the
;  dirty table (dlo/dhi); commit copies just those spans to VRAM in the
;  next vblank (in "blinds" row order, within a byte budget). Objects
;  also note their spans in olo/ohi so they can be erased next frame.
;  (frame_wait / input / text adapted from Ghost Hunter 2 / Tennis II)
; =====================================================================

; ---------------------------------------------------------------------
; frame_wait: 2-channel pin-pulse sound until the next field-sync
; falling edge (start of vblank). Loop = 126 T (~28.15 kHz).
; ---------------------------------------------------------------------
frame_wait:
        xor a
        ld (latefs),a
        ld a,($6800)
        rla
        jr c,.out               ; not in field sync now
        ; inside field sync already: was its start counted by fs_poll?
        ld a,(fsprev)
        or a
        jr z,.cnt
        xor a
        ld (fsprev),a
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
.cnt:   ld a,(allowlate)
        or a
        jr z,.out
        ; the game ran a little long: this is our vblank, go straight on
        ; with a smaller VRAM budget (see commit)
        xor a
        ld (allowlate),a
        inc a
        ld (latefs),a
        ld hl,(acc1)
        exx
        ld hl,(acc2)
        exx
        jr .go2
.out:   xor a
        ld (allowlate),a
.nf:    ld iyl,0
        ld a,(latchcur)
        ld c,a
        ld hl,(acc1)
        ld de,(step1)
        exx
        ld hl,(acc2)
        ld de,(step2)
        exx
.low:
        exx
        add hl,de
        sbc a,a
        and $20
        exx
        ld b,a
        add hl,de
        sbc a,a
        and $01
        or b
        ld b,a
        or iyl
        ld iyl,b
        or c
        ld ($6800),a
        ld a,($6800)
        rla
        jr nc,.low
.high:
        exx
        add hl,de
        sbc a,a
        and $20
        exx
        ld b,a
        add hl,de
        sbc a,a
        and $01
        or b
        ld b,a
        or iyl
        ld iyl,b
        or c
        ld ($6800),a
        ld a,($6800)
        rla
        jr c,.high
        ld de,(framecount)
        inc de
        ld (framecount),de
.go2:   xor a
        ld (fsprev),a
        ld a,(latchbase)
        ld (latchcur),a
        ld ($6800),a            ; speaker rest + new mode/palette, in vblank
        ld (acc1),hl
        exx
        ld (acc2),hl
        exx
        ret

; fs_poll: called often during the game's work, so frames are counted even
; while the game is busy (the start of field sync is a frame boundary)
fs_poll:
        ld a,($6800)
        rla
        jr c,.hi
        ld a,(fsprev)
        or a
        ret z
        xor a
        ld (fsprev),a
        push hl
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
        pop hl
        ret
.hi:    ld a,1
        ld (fsprev),a
        ret

; ---------------------------------------------------------------------
; do_frame: palette flash, sound, wait for vblank, commit, input
; ---------------------------------------------------------------------
do_frame:
        ld a,(palbase)
        ld b,a
        ld a,(flashtim)
        or a
        jr z,.nf
        dec a
        ld (flashtim),a
        bit 1,a
        jr z,.nf
        ld a,b
        xor CSS1
        ld b,a
.nf:    ld a,b
        or MODE1
        ld (latchbase),a
        call sound_tick
        call frame_wait
        call commit
        ld ($7FFF),a            ; emulator marker: VRAM work for this frame done
        jp read_input

; ---------------------------------------------------------------------
; read_input
; pad bits: 0 RIGHT (turn), 1 LEFT, 2 UP (accelerate), 3 DOWN (slow), 4 FIRE
;  pad1 = the original's white-plane keys: A left, S right, Z faster,
;         W slower, SHIFT or X fire  + joystick 1 ($2E/$2D/$2C)
;  pad2 = the original's blue-plane keys:  L left, ; right, . faster,
;         P slower, SPACE or , fire   + joystick 2 ($2B/$27/$29)
; mnu/mnunew (menus): 0 R 1 L 2 UP 3 DOWN 4 SELECT
;  up = W Q P stick-up, down = Z . stick-down, left = A L, right = S ;
;  select = SPACE RETURN SHIFT X or fire
; keys/keysnew: bit0 M (sound), bit1 RETURN (pause), bit2 Q (quit),
;               bit3 C, bit4 N, bit5 Y
; ---------------------------------------------------------------------
read_input:
        call read_pads
        ; ---- system keys
        ld c,0
        ld a,($68EF)
        bit 5,a
        jr nz,.k1
        set 0,c                 ; M
.k1:    bit 0,a
        jr nz,.k1b
        set 4,c                 ; N
.k1b:   ld a,($68BF)
        bit 2,a
        jr nz,.k2
        set 1,c                 ; RETURN
.k2:    bit 0,a
        jr nz,.k2b
        set 5,c                 ; Y
.k2b:   ld a,($68FE)
        bit 4,a
        jr nz,.k3
        set 2,c                 ; Q
.k3:    ld a,($68FB)
        bit 3,a
        jr nz,.k4
        set 3,c                 ; C
.k4:    ld a,(keys)
        cpl
        and c
        ld (keysnew),a
        ld a,c
        ld (keys),a
        ; ---- menu bits
        ld a,(joyb1)
        ld b,a
        ld a,(joyb2)
        or b
        ld c,a                  ; joystick directions/fire as pad bits
        ld a,(pad1)
        ld b,a
        ld a,(pad2)
        or b
        and $13                 ; turn keys -> left/right, fire -> select
        or c
        ld c,a
        ld a,($68FE)            ; W (b1), Q (b4)
        cpl
        and $12
        jr z,.u1
        set 2,c
.u1:    ld a,($68BF)            ; P (b4), RETURN (b2)
        bit 4,a
        jr nz,.u2
        set 2,c
.u2:    bit 2,a
        jr nz,.u3
        set 4,c
.u3:    ld a,($68FB)            ; Z (b4)
        bit 4,a
        jr nz,.u4
        set 3,c
.u4:    ld a,($68EF)            ; . (b1)
        bit 1,a
        jr nz,.u5
        set 3,c
.u5:    ld a,(mnu)
        cpl
        and c
        ld (mnunew),a
        ld a,c
        ld (mnu),a
        ret

read_pads:
        ld c,0
        ld a,($68FD)            ; row1: A b4, S b1
        bit 4,a
        jr nz,.n1
        set 1,c
.n1:    bit 1,a
        jr nz,.n2
        set 0,c
.n2:    ld a,($68FB)            ; row2: Z b4, SHIFT b2, X b1
        bit 4,a
        jr nz,.n3
        set 2,c
.n3:    and $06
        cp $06
        jr z,.n4
        set 4,c
.n4:    ld a,($68FE)            ; row0: W b1
        bit 1,a
        jr nz,.n5
        set 3,c
.n5:    in a,($2E)
        ld b,a
        in a,($2D)
        and b
        ld b,a
        in a,($2C)
        and b
        call joybits
        ld (joyb1),a
        or c
        ld b,a
        ld a,(pad1)
        cpl
        and b
        ld (pad1new),a
        ld a,b
        ld (pad1),a
        ; ---- set 2
        ld c,0
        ld a,($687F)            ; row7: L b1, ; b4
        bit 1,a
        jr nz,.m1
        set 1,c
.m1:    bit 4,a
        jr nz,.m2
        set 0,c
.m2:    ld a,($68EF)            ; row4: . b1, SPACE b4, , b3
        bit 1,a
        jr nz,.m3
        set 2,c
.m3:    and $18
        cp $18
        jr z,.m4
        set 4,c
.m4:    ld a,($68BF)            ; row6: P b4
        bit 4,a
        jr nz,.m5
        set 3,c
.m5:    in a,($2B)
        ld b,a
        in a,($27)
        and b
        ld b,a
        in a,($29)
        or $10                  ; $29 also sees joystick 1's arm button: directions only
        and b
        call joybits
        ld (joyb2),a
        or c
        ld b,a
        ld a,(pad2)
        cpl
        and b
        ld (pad2new),a
        ld a,b
        ld (pad2),a
        ret

; joybits: A = raw joystick byte (active low) -> A = pad bits (0 if no interface)
joybits:
        cpl
        and $1F
        ld b,a
        and $0F
        cp $0F                  ; all four directions = no interface / noise
        jr nz,.ok
        xor a
        ret
.ok:    ld a,b
        or a
        ret z
        xor a
        bit 0,b
        jr z,.j1
        set 2,a
.j1:    bit 1,b
        jr z,.j2
        set 3,a
.j2:    bit 2,b
        jr z,.j3
        set 1,a
.j3:    bit 3,b
        jr z,.j4
        set 0,a
.j4:    bit 4,b
        ret z
        set 4,a
        ret

; select pressed? -> NZ if newly pressed
check_start:
        ld a,(mnunew)
        and $10
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

; unpack: packbits HL -> DE
unpack:
        ld a,(hl)
        inc hl
        cp 128
        ret z
        jr nc,.rep
        inc a
        ld c,a
        ld b,0
        ldir
        jr unpack
.rep:   neg
        inc a
        ld b,a
        ld a,(hl)
        inc hl
.r1:    ld (de),a
        inc de
        djnz .r1
        jr unpack

; ---------------------------------------------------------------------
; buffers
; fill BBUF with A
cls_b:
        ld hl,BBUF
        ld de,BBUF+1
        ld bc,2047
        ld (hl),a
        ldir
        ret
; cls_vram: start-up only
cls_vram:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),a
        ldir
        ret
; show_b: the whole backdrop becomes the frame; every row dirty
; (commit then reveals it over a few frames as a blinds wipe)
show_b:
        ld hl,BBUF
        ld de,FBUF
        ld bc,2048
        ldir
        call clear_objd
mark_all:
        call clear_dirty
        ld de,blinds
        ld b,64
.l:     ld a,(de)
        inc e
        ld l,a
        ld h,DLO/256
        call dq_push
        ld (hl),0
        set 6,l
        ld (hl),31
        djnz .l
        ret
; dq_push: L = row that just became dirty -> onto the commit queue
dq_push:
        push hl
        ld a,l
        ld hl,(dq_tp)
        ld (hl),a
        ld a,l
        inc a
        and 127
        ld l,a
        ld (dq_tp),hl
        pop hl
        ret
; wait until every dirty row has reached the screen
wipe_wait:
        call do_frame
        ld hl,DLO
        ld b,64
.l:     ld a,(hl)
        inc a
        jr nz,wipe_wait
        inc l
        djnz .l
        ret
clear_dirty:
        ld hl,DQ
        ld (dq_tp),hl
        xor a
        ld (dq_h),a
        ld hl,DLO
        ld b,64
.l:     ld (hl),$FF
        set 6,l
        ld (hl),0
        res 6,l
        inc l
        djnz .l
        ret
clear_objd:
        ld hl,OLO
        ld b,64
.l:     ld (hl),$FF
        set 6,l
        ld (hl),0
        res 6,l
        inc l
        djnz .l
        ret
; copy BBUF rows E..E+C-1 to FBUF and mark them dirty (HUD / page updates)
b2f_rows:
        push bc
        push de
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,BBUF/256
        ld h,a
        ld d,h
        set 3,d
        ld e,l
        ld b,0
        sla c
        rl b
        sla c
        rl b
        sla c
        rl b
        sla c
        rl b
        sla c
        rl b
        ldir
        pop de
        pop bc
        ld d,0
        ld b,32
        jp mark_rect

; ---------------------------------------------------------------------
; dirty marking
; mark_rect: D = column, E = screen row, B = width in bytes, C = rows
; (no row wrap; a span past column 31 marks the whole row)
; objmark=1 also records the span for erasing next frame
; ---------------------------------------------------------------------
mark_rect:
        ld a,d
        add a,b
        dec a
        cp 32
        jr c,.ok
        ld d,0
        ld a,31
.ok:    ld b,a                  ; B = hi
        ld l,e
        ld h,DLO/256
        ld a,(objmark)
        or a
        jr nz,.both
.row:
        ld a,(hl)
        inc a
        call z,dq_push
        ld a,d
        cp (hl)
        jr nc,.r1
        ld (hl),a
.r1:    set 6,l
        ld a,b
        cp (hl)
        jr c,.r2
        ld (hl),a
.r2:    res 6,l
        inc l
        dec c
        jr nz,.row
        ret
.both:
        ld a,(hl)
        inc a
        call z,dq_push
        ld a,d
        cp (hl)
        jr nc,.b1
        ld (hl),a
.b1:    set 6,l
        ld a,b
        cp (hl)
        jr c,.b2
        ld (hl),a
.b2:    set 7,l
        cp (hl)
        jr c,.b3
        ld (hl),a
.b3:    res 6,l
        ld a,d
        cp (hl)
        jr nc,.b4
        ld (hl),a
.b4:    res 7,l
        inc l
        dec c
        jr nz,.both
        ret

; restore_old: erase last frame's objects (and anything else queued in
; olo/ohi) by copying the backdrop over those spans; they become dirty
restore_old:
        ld l,0
.row:   ld a,l
        and 7
        call z,fs_poll
        ld h,OLO/256
        set 7,l
        ld a,(hl)               ; olo
        set 6,l
        cp (hl)                 ; ohi
        jr z,.go
        jr c,.go
        res 6,l
        res 7,l
        inc l
        ld a,l
        cp 64
        jr c,.row
        ret
.go:    ld c,(hl)               ; hi
        ld (hl),0
        res 6,l
        ld b,a                  ; lo
        ld (hl),$FF
        res 7,l
        ; merge into dirty
        ld a,(hl)
        inc a
        call z,dq_push
        ld a,b
        cp (hl)
        jr nc,.m1
        ld (hl),a
.m1:    set 6,l
        ld a,c
        cp (hl)
        jr c,.m2
        ld (hl),a
.m2:    res 6,l
        push hl
        ; copy BBUF -> FBUF span
        ld a,c
        sub b
        inc a
        ld c,a                  ; count
        ld e,l
        ld d,0
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or b
        ld l,a
        ld a,h
        add a,BBUF/256
        ld h,a
        ld d,h
        set 3,d
        ld e,l
        ld b,0
        ldir
        pop hl
        inc l
        ld a,l
        cp 64
        jr c,.row
        ret

; ---------------------------------------------------------------------
; commit (vblank): copy dirty spans FBUF -> VRAM in blinds order,
; within the byte budget; picks up where it left off next time
; ---------------------------------------------------------------------
commit:
        ld a,(latefs)
        or a
        ld a,(cbudget)
        jr z,.b
        ld a,18
.b:     ld c,a
.next:  ld a,(dq_h)
        ld e,a
        ld a,(dq_tp)
        cp e
        ret z                   ; queue empty
        ld d,DQ/256
        ld a,(de)               ; row
        ld l,a
        ld h,DLO/256
        ld a,(hl)
        set 6,l
        cp (hl)
        jr z,.dirty
        jr c,.dirty
.adv:   ld a,e
        inc a
        and 127
        ld (dq_h),a
        jr .next
.dirty: ld b,a                  ; lo
        ld a,(hl)
        sub b
        inc a
        push af                 ; count
        srl a
        srl a
        add a,3                 ; cost (4-byte units + row overhead)
        ld d,a
        ld a,c
        sub d
        jr nc,.ok
        pop af
        ret                     ; out of budget: this row waits for next time
.ok:    ld c,a
        ld (hl),0
        res 6,l
        ld (hl),$FF
        push bc
        push de
        ld e,l
        ld d,0
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or b
        ld l,a
        ld a,h
        add a,VRAM/256
        ld h,a
        ld d,h
        ld e,l                  ; DE = VRAM
        add a,FBUF/256-VRAM/256
        ld h,a                  ; HL = FBUF
        pop af                  ; drop the saved DE
        pop bc
        pop af
        push bc
        ld c,a
        ld b,0
        ldir
        pop bc
        ld a,(dq_h)
        ld e,a
        jr .adv

; ---------------------------------------------------------------------
; text: 3x5 font, 4 px per char.  txtoff = FBUF/BBUF high byte - $70
; set_ink: A = fg colour (0-3), B = bg colour
; ---------------------------------------------------------------------
set_ink:
        ld c,a
        ld a,(ink_fg)
        cp c
        jr nz,.do
        ld a,(ink_bg)
        cp b
        ret z
.do:    ld a,c
        ld (ink_fg),a
        ld a,b
        ld (ink_bg),a
        ld hl,inktab
        ld c,0
.lp:    ld e,0
        ld b,3
        ld d,c
        sla d
        sla d
        sla d
        sla d
        sla d
.px:    sla e
        sla e
        sla d
        ld a,(ink_bg)
        jr nc,.bgp
        ld a,(ink_fg)
.bgp:   or e
        ld e,a
        djnz .px
        sla e
        sla e
        ld a,(ink_bg)
        or e
        ld (hl),a
        inc hl
        inc c
        ld a,c
        cp 8
        jr nz,.lp
        ret
to_b:   ld a,BBUF/256-VRAM/256
        ld (txtoff),a
        xor a
        ld (objmark),a
        ret
to_f:   ld a,FBUF/256-VRAM/256
        ld (txtoff),a
        ret

; print: HL = string, D = column, E = row
print:
.go:    ld a,(hl)
        or a
        ret z
        push hl
        push de
        call putchar
        pop de
        pop hl
        inc hl
        inc d
        jr .go

; putchar: A = ascii, D = col, E = row
putchar:
        sub 32
        jr nc,.ok
        xor a
.ok:    cp 64
        jr c,.ok2
        sub 32
.ok2:   ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        ld bc,font3
        add hl,bc
        push de
        push hl
        call scraddr
        ld a,(txtoff)
        add a,h
        ld h,a
        pop de
        ld b,5
.row:   ld a,(de)
        inc de
        push de
        push hl
        ld e,a
        ld d,0
        ld hl,inktab
        add hl,de
        ld a,(hl)
        pop hl
        ld (hl),a
        ld de,32
        add hl,de
        pop de
        djnz .row
        pop de
        ld a,(txtoff)
        cp FBUF/256-VRAM/256
        ret nz
        ld bc,$0105
        jp mark_rect

; scraddr: D = column, E = row -> HL = VRAM + row*32 + col
scraddr:
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or d
        ld l,a
        ld a,h
        add a,VRAM/256
        ld h,a
        ret

; print_bcd: HL -> BCD bytes, B = count, D/E position
print_bcd:
.l:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and $0F
        add a,'0'
        push hl
        push bc
        push de
        call putchar
        pop de
        pop bc
        pop hl
        inc d
        ld a,(hl)
        and $0F
        add a,'0'
        push hl
        push bc
        push de
        call putchar
        pop de
        pop bc
        pop hl
        inc d
        inc hl
        djnz .l
        ret

; print_dec2: A = 0..99 as two digits at D/E
print_dec2:
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        push af
        ld a,b
        push de
        call putchar
        pop de
        inc d
        pop af
        jp putchar

; print centered: HL string, E row
print_c:
        call strlen
        ld a,32
        sub b
        srl a
        ld d,a
        jp print
strlen: push hl
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.d
        inc b
        inc hl
        jr .l
.d:     pop hl
        ret

; big print (2x): HL string, D column (2 cols/char), E row (10 rows)
print2:
.go:    ld a,(hl)
        or a
        ret z
        push hl
        push de
        call putchar2
        pop de
        pop hl
        inc hl
        inc d
        inc d
        jr .go
print2_c:
        call strlen
        ld a,16
        sub b
        ld d,a
        jr print2

putchar2:
        push de
        sub 32
        jr nc,.ok
        xor a
.ok:    ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        ld bc,font3
        add hl,bc
        push hl
        call scraddr
        ld a,(txtoff)
        add a,h
        ld h,a
        pop de
        ld b,5
.row:   ld a,(de)
        inc de
        push bc
        push de
        ld c,a
        ld a,(ink_bg)
        ld e,a
        ld a,(ink_fg)
        ld d,a
        call dbl_byte_left
        ld (hl),a
        ld b,a
        call dbl_byte_right
        ld c,a
        inc l
        ld (hl),a
        dec l
        ld de,32
        add hl,de
        ld (hl),b
        inc l
        ld (hl),c
        dec l
        add hl,de
        pop de
        pop bc
        djnz .row
        pop de
        ld a,(txtoff)
        cp FBUF/256-VRAM/256
        ret nz
        ld bc,$020A
        jp mark_rect
dbl_byte_left:
        push bc
        ld b,0
        bit 2,c
        call .pp
        bit 2,c
        call .pp
        bit 1,c
        call .pp
        bit 1,c
        call .pp
        ld a,b
        pop bc
        ret
.pp:    ld a,b
        rlca
        rlca
        jr z,.bg
        or d
        ld b,a
        ret
.bg:    or e
        ld b,a
        ret
dbl_byte_right:
        push bc
        ld b,0
        bit 0,c
        call dbl_byte_left.pp
        bit 0,c
        call dbl_byte_left.pp
        xor a
        call dbl_byte_left.pp
        xor a
        call dbl_byte_left.pp
        ld a,b
        pop bc
        ret

; fill_rect: D col, E row, B width, C height, A byte -> current text page
fill_rect:
        push bc
        push de
        push af
        call scraddr
        ld a,(txtoff)
        add a,h
        ld h,a
        pop af
.r:     push bc
        push hl
.b:     ld (hl),a
        inc l
        djnz .b
        pop hl
        ld de,32
        add hl,de
        pop bc
        dec c
        jr nz,.r
        pop de
        pop bc
        ld a,(txtoff)
        cp FBUF/256-VRAM/256
        ret nz
        jp mark_rect

; blit_pic: HL = raw picture (w bytes x C rows), B = width, D col, E row -> page
blit_pic:
        push hl
        call scraddr
        ld a,(txtoff)
        add a,h
        ld h,a
        ex de,hl
        pop hl
.r:     push bc
        push de
        ld c,b
        ld b,0
        ldir
        pop de
        ex de,hl
        ld bc,32
        add hl,bc
        ex de,hl
        pop bc
        dec c
        jr nz,.r
        ret
