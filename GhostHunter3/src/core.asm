; =====================================================================
;  GHOST HUNTER 2 - core engine: frame sync + beeper, input, gfx, text
; =====================================================================

; ---------------------------------------------------------------------
; frame_wait: generate 2-channel pin-pulse sound until the next field
; sync falling edge (start of vblank). HL/HL' accumulators persist.
; Loop = 126 T-states (~28.15 kHz); each pulse lasts 2 loops (~70us)
; ---------------------------------------------------------------------
frame_wait:
        ld a,(latchbase)
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
        ; vblank begins
        ld a,c
        ld ($6800),a            ; speaker rest + current mode/palette
        ld (acc1),hl
        exx
        ld (acc2),hl
        exx
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
        ret

; ---------------------------------------------------------------------
; read_input -> inp (bit0 R,1 L,2 U,3 D,4 FIRE), inpnew (newly pressed)
; keyboard: Q up, A down, M left, ',' right, SPACE fire
; joysticks: both, every port read and combined (active low)
; ---------------------------------------------------------------------
read_input:
        ld c,0
        ld a,($6FFE)            ; row0: Q bit4
        bit 4,a
        jr nz,.n1
        set 2,c
.n1:    ld a,($6FFD)            ; row1: A bit4
        bit 4,a
        jr nz,.n2
        set 3,c
.n2:    ld a,($6FEF)            ; row4: M bit5, SPACE bit4, ',' bit3
        bit 5,a
        jr nz,.n3
        set 1,c
.n3:    bit 3,a
        jr nz,.n4
        set 0,c
.n4:    bit 4,a
        jr nz,.n5
        set 4,c
.n5:    ; joysticks (bits: 0 up,1 down,2 left,3 right,4 fire; active low)
        in a,($2C)
        ld b,a
        in a,($29)
        and b
        ld b,a
        in a,($2E)
        and b
        ld b,a
        in a,($2B)
        and b
        ld b,a
        in a,($2D)
        and b
        ld b,a
        in a,($27)
        and b
        cpl
        and $1F
        cp $0F                  ; all four directions at once = bus noise/no interface
        jr nz,.jok
        xor a
.jok:   ld b,a
        bit 0,b
        jr z,.j1
        set 2,c
.j1:    bit 1,b
        jr z,.j2
        set 3,c
.j2:    bit 2,b
        jr z,.j3
        set 1,c
.j3:    bit 3,b
        jr z,.j4
        set 0,c
.j4:    bit 4,b
        jr z,.j5
        set 4,c
.j5:    ld a,(inp)
        cpl
        and c
        ld (inpnew),a
        ld a,c
        ld (inp),a
        ; extra keys: S (row1 bit1), P (row6 bit4), RETURN (row6 bit2)
        ld c,0
        ld a,($6FFD)
        bit 1,a
        jr nz,.k1
        set 0,c                 ; S
.k1:    ld a,($6FBF)
        bit 4,a
        jr nz,.k2
        set 1,c                 ; P
.k2:    bit 2,a
        jr nz,.k3
        set 2,c                 ; RETURN
.k3:    ld a,(keys)
        cpl
        and c
        ld (keysnew),a
        ld a,c
        ld (keys),a
        ret

; start pressed?  (S, SPACE, RETURN or fire)  -> NZ if newly pressed
check_start:
        ld a,(inpnew)
        and $10
        ret nz
        ld a,(keysnew)
        and $05
        ret

; ---------------------------------------------------------------------
; random: 16-bit xorshift -> A (and HL)
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

; ---------------------------------------------------------------------
; cls_both: fill VRAM and BG buffer with A
; ---------------------------------------------------------------------
cls_both:
        push af
        ld hl,BGBUF
        ld de,BGBUF+1
        ld bc,2047
        ld (hl),a
        ldir
        pop af
cls_vram:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),a
        ldir
        ret

; copy BG buffer to VRAM
bg_to_vram:
        ld hl,BGBUF
        ld de,VRAM
        ld bc,2048
        ldir
        ret

; ---------------------------------------------------------------------
; unpack: packbits HL -> DE
; ---------------------------------------------------------------------
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
.rep:   neg                     ; 256-n
        inc a                   ; 257-n
        ld b,a
        ld a,(hl)
        inc hl
.r1:    ld (de),a
        inc de
        djnz .r1
        jr unpack

; ---------------------------------------------------------------------
; text: 3x5 font, one byte column per char (4 px)
; set_ink: A = fg colour (0-3), B = bg colour  -> builds 8-entry table
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
        ld c,0                  ; pattern 0..7 (bit2 = left px)
.lp:    ld e,0                  ; result byte
        ld b,3
        ld d,c
        sla d                   ; align: bit2 -> bit3 position for loop
        sla d
        sla d
        sla d
        sla d                   ; pattern bits now in d bits 7..5
.px:    sla e
        sla e
        sla d
        ld a,(ink_bg)
        jr nc,.bgp
        ld a,(ink_fg)
.bgp:   or e
        ld e,a
        djnz .px
        sla e                   ; 4th pixel = bg
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

; print: HL = zero-terminated string, D = column (0-31), E = pixel row
; (textdest: 0 = VRAM only, 1 = VRAM + BG)
print:
        ld a,(hl)
        or a
        ret z
        push hl
        push de
        call putchar
        pop de
        pop hl
        inc hl
        inc d
        jr print

; putchar: A = ascii, D = col, E = row
putchar:
        sub 32
        jr nc,.ok
        xor a
.ok:    cp 64
        jr c,.ok2
        sub 32                  ; lowercase -> uppercase
.ok2:   ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc               ; *5
        ld bc,font3
        add hl,bc
        push hl
        call scraddr            ; HL = VRAM addr for (D,E)
        pop de                  ; DE = glyph
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
        ld c,a
        ld a,(textdest)
        or a
        jr z,.nobg
        ld a,(gmode)
        or a
        jr nz,.nobg
        ld a,h
        and $EF
        ld d,a
        ld e,l
        ld a,c
        ld (de),a
.nobg:  ld de,32
        add hl,de
        pop de
        djnz .row
        ret

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

; print_bcd: HL -> BCD bytes (msb first), B = number of bytes, D/E pos
print_bcd:
        ld a,(hl)
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
        djnz print_bcd
        ret

; print_dec: A = 0..99 as two digits at D/E
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

; print centered: HL string, E row  (32 columns)
print_c:
        push hl
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.d
        inc b
        inc hl
        jr .l
.d:     ld a,32
        sub b
        srl a
        ld d,a
        pop hl
        jp print

; big print (2x scale): HL string, D = column (each char 2 cols), E row (10 rows)
print2:
        ld a,(hl)
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
        jr print2

putchar2:
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
        ret
; C = 3-bit pattern ; D = fg, E = bg -> A = byte
dbl_byte_left:
        push bc
        ld a,0
        ld b,a
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
        call dbl_byte_left.pp   ; Z set -> bg
        xor a
        call dbl_byte_left.pp
        ld a,b
        pop bc
        ret

; fill_rect: D = col, E = row, B = width (bytes), C = height, A = byte
; writes VRAM and (if textdest) BG
fill_rect:
        ld (.v+1),a
        push bc
        call scraddr
        pop bc
.r:     push bc
        push hl
.v:     ld a,0
.b:     ld (hl),a
        push af
        ld a,(textdest)
        or a
        jr z,.nb
        ld a,(gmode)
        or a
        jr nz,.nb
        ld a,h
        and $EF
        ld d,a
        ld e,l
        pop af
        ld (de),a
        push af
.nb:    pop af
        inc l
        djnz .b
        pop hl
        ld de,32
        add hl,de
        pop bc
        dec c
        jr nz,.r
        ret

; ---------------------------------------------------------------------
; SPRITES
; shtab entry (8 bytes): dw base, db pw, db h, dw shiftsize, dw 0
; ---------------------------------------------------------------------
init_sprites:
        ; mask / clean tables: blue (10) pixels are transparent
        ld hl,MASKTAB
.mt:    ld a,l
        ld b,4
        ld c,0                  ; mask
        ld e,a
.mp:    rlc c
        rlc c
        ld a,e
        and $C0
        cp $80
        jr nz,.mo
        ld a,c
        or 3
        ld c,a
.mo:    rlc e
        rlc e
        djnz .mp
        ld (hl),c
        inc h
        ld a,c
        cpl
        and l
        ld (hl),a               ; clean data (transparent pixels -> 00)
        dec h
        inc l
        jr nz,.mt
        ld ix,sprtab
        ld iy,shtab
        ld de,SHIFTBUF          ; output pointer
        ld b,NSPR
.spr:   ld a,b
        cp NSPR-NSMALL
        jr nz,.small
        ld de,BIGSHIFT          ; big (attract) sprites go to bank B
.small: push bc
        ld l,(ix+0)
        ld h,(ix+1)             ; src
        ld a,(ix+2)             ; sw
        ld (sw_),a
        inc a
        ld (pw_),a
        ld c,(ix+3)             ; h
        ld (iy+0),e
        ld (iy+1),d
        ld (iy+2),a
        ld (iy+3),c
        ; shiftsize = pw*h
        push hl
        push de
        ld e,c
        ld d,0
        ld b,a
        ld hl,0
.mul:   add hl,de
        djnz .mul
        pop de
        ld (iy+4),l
        ld (iy+5),h
        pop hl
        ld (srcptr),hl
        xor a
.sh:    ld (shiftn),a
        ld hl,(srcptr)
        ld a,(iy+3)
        ld b,a
.row:   push bc
        call shift_row          ; HL src row -> rowd (pw bytes), HL advanced
        push hl
        ld hl,rowd
        ld a,(pw_)
        ld c,a
        ld b,0
        ldir
        pop hl
        pop bc
        djnz .row
        ld a,(shiftn)
        inc a
        cp 4
        jr nz,.sh
        ld bc,4
        add ix,bc
        ld bc,8
        add iy,bc
        pop bc
        dec b
        jp nz,.spr
        ld (shiftend),de
        ret
; shift_row: HL = source row (sw bytes) -> rowd[pw], shifted right by shiftn pixels
shift_row:
        push de
        ld de,rowd
        ld a,(sw_)
        ld c,a
        ld b,0
        ldir
        ld a,$AA
        ld (de),a               ; spill = transparent
        pop de
        ld a,(shiftn)
        or a
        ret z
        push hl
        ld b,a
.px:    push bc
        or a                    ; first bit in = 0
        call .rr
        scf                     ; second bit in = 1  -> new pixel = 10 (transparent)
        call .rr
        pop bc
        djnz .px
        pop hl
        ret
.rr:    ld hl,rowd
        ld a,(pw_)
        ld b,a
.r:     rr (hl)
        inc hl
        djnz .r
        ret

; clear the draw list (logic side)
dl_reset:
        ld hl,drawlist
        ld (dlptr),hl
        ld (hl),$FF
        ret

; dl_add: A = id, B = x, C = y   (pixel coords, x 0-127)
dl_add:
        ld hl,(dlptr)
        ld (hl),a
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),0
        inc hl
        ld (hl),$FF
        ld (dlptr),hl
        ret
; dl_text: B = col, C = row, E = string index (popup), A = $FE
dl_text:
        ld hl,(dlptr)
        ld (hl),$FE
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),e
        inc hl
        ld (hl),$FF
        ld (dlptr),hl
        ret
; dl_pixel: B = x, C = y, E = colour
dl_pixel:
        ld hl,(dlptr)
        ld (hl),$FD
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),e
        inc hl
        ld (hl),$FF
        ld (dlptr),hl
        ret

; ---------------------------------------------------------------------
; render: erase previous sprites from BG, draw current draw list
; ---------------------------------------------------------------------
render:
        ld hl,eraselist
.e:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or a
        jr z,.edone
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        ex de,hl
.erow:  push bc
        push hl
        ld a,h
        and $EF
        ld d,a
.eb:    ld e,l
        ld a,(de)
        ld (hl),a
        inc l
        djnz .eb
        pop hl
        ld de,32
        add hl,de
        pop bc
        dec c
        jr nz,.erow
        pop hl
        jr .e
.edone: ld hl,eraselist
        ld (elptr),hl
        ld ix,drawlist
.d:     ld a,(ix+0)
        cp $FF
        jp z,.ddone
        cp $FE
        jp z,.text
        cp $FD
        jp z,.pixel
        ; ---- sprite
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,shtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; base
        inc hl
        ld a,(hl)
        ld (pw_),a
        inc hl
        ld a,(hl)
        ld (h_),a
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; shiftsize
        ld a,(ix+1)
        and 3
        jr z,.s0
.s1:    ex de,hl
        add hl,bc
        ex de,hl
        dec a
        jr nz,.s1
.s0:    ; DE = data. VRAM addr
        ld a,(ix+1)
        srl a
        srl a
        ld (col_),a
        push de
        ld d,a
        ld e,(ix+2)
        call scraddr
        pop de
        ; clip width
        ld a,(col_)
        ld b,a
        ld a,32
        sub b                   ; bytes available
        ld b,a
        ld a,(pw_)
        cp b
        jr c,.nw
        ld a,b
.nw:    ld (w_),a
        ; record erase
        push hl
        push de
        ex de,hl
        ld hl,(elptr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(w_)
        ld (hl),a
        inc hl
        ld a,(h_)
        ld (hl),a
        inc hl
        ld (elptr),hl
        pop de
        pop hl
        ; skip bytes per row = pw-w
        ld a,(w_)
        ld b,a
        ld a,(pw_)
        sub b
        ld (skip_),a
        ld a,(h_)
        ld (rowcnt),a
        ld b,d
        ld c,e                  ; BC = sprite data
        ex de,hl                ; DE = VRAM
        ld h,MASKTAB/256
        ld a,(w_)
        cp 3
        jr z,.row3
.row:   push de
        ld a,(w_)
        ld iyl,a
.byte:  ld a,(bc)
        ld l,a
        ld a,(de)
        and (hl)
        inc h
        or (hl)
        dec h
        ld (de),a
        inc bc
        inc e
        dec iyl
        jr nz,.byte
        ld a,(skip_)
        add a,c
        ld c,a
        jr nc,.nsk
        inc b
.nsk:   pop de
        ld a,e
        add a,32
        ld e,a
        jr nc,.nc
        inc d
.nc:    ld a,(rowcnt)
        dec a
        ld (rowcnt),a
        jr nz,.row
        jp .next
.row3:  ; fast path: 3 bytes, no clipping (pw = 3)
        ld a,(bc)
        ld l,a
        ld a,(de)
        and (hl)
        inc h
        or (hl)
        dec h
        ld (de),a
        inc bc
        inc e
        ld a,(bc)
        ld l,a
        ld a,(de)
        and (hl)
        inc h
        or (hl)
        dec h
        ld (de),a
        inc bc
        inc e
        ld a,(bc)
        ld l,a
        ld a,(de)
        and (hl)
        inc h
        or (hl)
        dec h
        ld (de),a
        inc bc
        ld a,e
        add a,30
        ld e,a
        jr nc,.r3c
        inc d
.r3c:   ld a,(rowcnt)
        dec a
        ld (rowcnt),a
        jr nz,.row3
        jp .next
.text:  ; text popup: col=(ix+1), row=(ix+2), string index (ix+3)
        ld a,(ix+3)
        add a,a
        ld l,a
        ld h,0
        ld de,popstr
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ; length
        push hl
        ld b,0
.tl:    ld a,(hl)
        or a
        jr z,.tld
        inc b
        inc hl
        jr .tl
.tld:   pop hl
        push bc
        push hl
        ld a,1
        ld b,2
        call set_ink
        pop hl
        pop bc
        ld d,(ix+1)
        ld e,(ix+2)
        push hl
        push de
        push bc
        call scraddr
        ex de,hl
        ld hl,(elptr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        pop bc
        ld (hl),b
        inc hl
        ld (hl),5
        inc hl
        ld (elptr),hl
        pop de
        pop hl
        xor a
        ld (textdest),a
        call print
        jr .next
.pixel: ld a,(ix+1)
        ld c,a
        srl a
        srl a
        ld d,a
        ld e,(ix+2)
        call scraddr
        ex de,hl
        ld hl,(elptr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),1
        inc hl
        ld (hl),1
        inc hl
        ld (elptr),hl
        ld a,(ix+3)
        add a,a
        add a,a
        ld b,a
        ld a,c
        and 3
        or b
        add a,a
        ld l,a
        ld h,0
        ld bc,pixtab
        add hl,bc
        ld b,(hl)
        inc hl
        ld c,(hl)
        ex de,hl
        ld a,(hl)
        and b
        or c
        ld (hl),a
.next:  ld de,4
        add ix,de
        jp .d
.ddone: ld hl,(elptr)
        ld (hl),0
        inc hl
        ld (hl),0
        ret
pixtab: db $3F,$00,$CF,$00,$F3,$00,$FC,$00
        db $3F,$40,$CF,$10,$F3,$04,$FC,$01
        db $3F,$80,$CF,$20,$F3,$08,$FC,$02
        db $3F,$C0,$CF,$30,$F3,$0C,$FC,$03

pixmask: db $3F,$CF,$F3,$FC
colbyte: db $00,$55,$AA,$FF
