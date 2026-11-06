; =====================================================================
;  TENNIS II - core engine: frame sync + beeper, input, text, sprites,
;  snow-free VRAM commit queue.  (from Penguin 2 / Ghost Hunter 2)
;  Rule: outside vblank, code only ever draws into the background
;  buffer (BGBUF) and queues the changed rectangle. VRAM is written
;  only by render (called straight after field-sync starts).
;  (frame_wait, input, text and sprite code adapted from Ghost Hunter 2)
; =====================================================================

; ---------------------------------------------------------------------
; frame_wait: 2-channel pin-pulse sound until the next field-sync
; falling edge (start of vblank). Loop = 126 T (~28.15 kHz).
; ---------------------------------------------------------------------
frame_wait:
        ld iyl,0                ; IY is a pointer elsewhere: clear the pulse-stretch byte
        ld a,(latchcur)         ; palette/mode changes wait for vblank
        ld c,a
        ld a,(noiseon)
        or a
        jp nz,frame_wait_noise
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
        ld a,(latchbase)
        ld (latchcur),a
        ld ($6800),a            ; speaker rest + new mode/palette, in vblank
        ld (acc1),hl
        exx
        ld (acc2),hl
        exx
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
        ret

; frame_wait_noise: as frame_wait, but channel 2 is white noise. HL' walks
; through the game's own code ($8000-$C4FF, two bytes a sample) and a pulse
; fires when the byte is below D' (the noise density, 0-255). Same 126 T loop,
; so channel 1 (melody) keeps its pitch; pulse stretching is dropped for the
; noise frames to pay for it. Never touches VRAM.
frame_wait_noise:
        ld hl,(acc1)
        ld de,(step1)
        exx
        ld hl,(acc2)
        ld a,h
        and $3F
        or $80
        ld h,a                  ; keep the walk inside $8000-$C4FF
        ld de,(step2)           ; D' = density
        exx
.low:
        exx                     ; 4
        ld a,(hl)               ; 7
        inc hl                  ; 6
        cp d                    ; 4   carry = byte < density
        sbc a,a                 ; 4
        and $20                 ; 7
        inc hl                  ; 6   (padding that also skips a byte)
        exx                     ; 4
        ld b,a                  ; 4
        add hl,de               ; 11
        sbc a,a                 ; 4
        and $01                 ; 7
        or b                    ; 4
        ld b,a                  ; 4   (padding)
        nop                     ; 4   (padding)
        or c                    ; 4
        ld ($6800),a            ; 13
        ld a,($6800)            ; 13
        rla                     ; 4
        jr nc,.low              ; 12  = 126
.high:
        exx
        ld a,(hl)
        inc hl
        cp d
        sbc a,a
        and $20
        inc hl
        exx
        ld b,a
        add hl,de
        sbc a,a
        and $01
        or b
        ld b,a
        nop
        or c
        ld ($6800),a
        ld a,($6800)
        rla
        jr c,.high
        ld a,(latchbase)
        ld (latchcur),a
        ld ($6800),a
        ld (acc1),hl
        exx
        ld (acc2),hl
        exx
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
        ret

; ---------------------------------------------------------------------
; read_input: both pads + system keys
; pad bits: 0 R, 1 L, 2 U, 3 D, 4 FIRE.
;  pad1 = keyboard Q A M , SPACE + joystick 1 ($2E/$2D/$2C)
;  pad2 = keyboard I K J L + H or ; (fire) + joystick 2 ($2B/$27/$29)
;  inp/inpnew = both pads together (menus, 1-player game)
; keys/keysnew: bit0 S, bit1 P, bit2 RETURN, bit3 X, bit4 N
; ---------------------------------------------------------------------
read_input:
        call read_pads
        ld a,(pad1)
        ld b,a
        ld a,(pad2)
        or b
        ld c,a
        ld a,(inp)
        cpl
        and c
        ld (inpnew),a
        ld a,c
        ld (inp),a
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
.k3:    ld a,($6FFB)
        bit 1,a
        jr nz,.k4
        set 3,c                 ; X
.k4:    ld a,($6FEF)
        bit 0,a
        jr nz,.k5
        set 4,c                 ; N
.k5:    ld a,(keys)
        cpl
        and c
        ld (keysnew),a
        ld a,c
        ld (keys),a
        ret

read_pads:
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
.n5:    in a,($2E)
        ld b,a
        in a,($2D)
        and b
        ld b,a
        in a,($2C)
        and b
        call joybits
        or c
        ld b,a
        ld a,(pad1)
        cpl
        and b
        ld (pad1new),a
        ld a,b
        ld (pad1),a
        ; set 2
        ld c,0
        ld a,($6FBF)            ; row6: I bit3
        bit 3,a
        jr nz,.m1
        set 2,c
.m1:    ld a,($6F7F)            ; row7: J bit5, ';' bit4, K bit3, L bit1, H bit0
        bit 3,a
        jr nz,.m2
        set 3,c
.m2:    bit 5,a
        jr nz,.m3
        set 1,c
.m3:    bit 1,a
        jr nz,.m4
        set 0,c
.m4:    bit 0,a
        jr z,.m5
        bit 4,a
        jr nz,.m6
.m5:    set 4,c
.m6:    in a,($2B)
        ld b,a
        in a,($27)
        and b
        ld b,a
        in a,($29)
        or $10                  ; $29 also sees joystick 1's arm button: directions only
        and b
        call joybits
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
        ld a,1
        ld (joyseen),a
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

; ---------------------------------------------------------------------
; BG helpers
; cls_bg: fill BG with A (no VRAM update)
cls_bg:
        ld hl,BGBUF
        ld de,BGBUF+1
        ld bc,2047
        ld (hl),a
        ldir
        ret
; cls_vram: only legal with the display blanked or at start-up
cls_vram:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),a
        ldir
        ret

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
; commit queue: rectangles to copy BG -> VRAM during vblank
; queue_rect: D = byte column, E = pixel row, B = width (bytes), C = height
; ---------------------------------------------------------------------
queue_rect:
        ld a,(noq)
        or a
        ret nz
        push hl
        ld a,(q_tail)
        ld l,a
        add a,4
        and $7F
        ld h,a
        ld a,(q_head)
        cp h
        jr z,.full              ; full: drop (caller redraws later anyway)
        ld a,h
        ld (q_tail),a
        ld h,qbuf/256
        ld (hl),d
        inc l
        ld (hl),e
        inc l
        ld (hl),b
        inc l
        ld (hl),c
.full:  pop hl
        ret
; wait until the queue has drained (keeps sprites as they are)
flush_queue:
        call do_frame
        ld a,(q_head)
        ld b,a
        ld a,(q_tail)
        cp b
        jr nz,flush_queue
        ret

; commit: copy queued rects within a byte budget (called in vblank)
commit:
        ; budget shrinks when the draw list is busy (4 units per entry)
        ld hl,(dlptr)
        ld de,drawlist
        or a
        sbc hl,de
        ld a,l
        srl a                   ; entries*2
        ld b,a
        ld a,(cbudget)
        sub b
        jr c,.mn
        cp 4
        jr nc,.bs
.mn:    ld a,4
.bs:    ld (budget_),a
        ld a,1
        ld (cfirst),a
.next:  ld a,(q_head)
        ld b,a
        ld a,(q_tail)
        cp b
        ret z
        ld l,b
        ld h,qbuf/256
        ld d,(hl)
        inc l
        ld e,(hl)
        inc l
        ld b,(hl)
        inc l
        ld c,(hl)
        ; cost = h * (w/8 + 1); always allow the first rect of a frame
        push bc
        ld a,b
        srl a
        srl a
        srl a
        inc a
        ld h,a
        xor a
.cm:    add a,h
        jr c,.big
        dec c
        jr nz,.cm
        jr .cd
.big:   ld a,255
.cd:    ld h,a
        pop bc
        ld a,(cfirst)
        or a
        ld a,(budget_)
        jr nz,.first
        sub h
        ret c
        jr .ok
.first: sub h
        jr nc,.ok
        ; too big for one vblank: copy the first rows now, leave the rest queued
        ld a,b
        srl a
        srl a
        srl a
        inc a
        ld l,a                  ; cost per row
        ld a,(budget_)
        ld h,0
.dv:    sub l
        jr c,.dd
        inc h
        jr .dv
.dd:    ld a,h
        or a
        jr nz,.d1
        inc a
.d1:    cp c
        jr nc,.all
        ld (prows),a
        ld a,(q_head)
        ld l,a
        ld h,qbuf/256
        inc l
        ld a,(prows)
        add a,(hl)              ; row += n
        ld (hl),a
        inc l
        inc l
        ld a,(hl)
        push hl
        ld hl,prows
        sub (hl)                ; height -= n
        pop hl
        ld (hl),a
        xor a
        ld (budget_),a
        ld (cfirst),a
        ld a,(prows)
        ld c,a
        jr .copy
.all:   xor a
.ok:    ld (budget_),a
        xor a
        ld (cfirst),a
        ld a,(q_head)
        add a,4
        and $7F
        ld (q_head),a
.copy:  call scraddr            ; HL = VRAM
.row:   push bc
        push hl
        ld e,l
        ld a,h
        ld d,a
        or $88
        ld h,a                  ; HL = BG, DE = VRAM
        ld c,b
        ld b,0
        ldir
        pop hl
        ld bc,32
        add hl,bc
        pop bc
        dec c
        jr nz,.row
        jp .next

; ---------------------------------------------------------------------
; text: 3x5 font, 4 px per char
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

; print: HL = string, D = column, E = row. textdirect=0: BG + queue,
; textdirect=1: straight to VRAM (render-time popups only)
print:
        push hl
        push de
        ld b,0
.len:   ld a,(hl)
        or a
        jr z,.l2
        inc b
        inc hl
        jr .len
.l2:    pop de
        pop hl
        ld a,(textdirect)
        or a
        jr nz,.go
        ld a,b
        or a
        ret z
        ld a,(noq)
        or a
        jr nz,.go
        push hl
        push de
        ld c,5
        call queue_rect
        pop de
        pop hl
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

; putchar: A = ascii, D = col, E = row (no queueing)
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
        push hl
        call scraddr
        ld a,(textdirect)
        or a
        jr nz,.v
        ld a,h
        or $88
        ld h,a
.v:     pop de
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

; print_bcd: HL -> BCD bytes, B = count, D/E position (BG + queue)
print_bcd:
        push hl
        push bc
        push de
        ld a,b
        add a,a
        ld b,a
        ld c,5
        call queue_rect
        pop de
        pop bc
        pop hl
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

; print_dec2: A = 0..99 as two digits at D/E (BG + queue)
print_dec2:
        push af
        push de
        ld b,2
        ld c,5
        call queue_rect
        pop de
        pop af
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

; big print (2x): HL string, D column (2 cols/char), E row (10 rows), BG + queue
print2:
        push hl
        push de
        ld b,0
.len:   ld a,(hl)
        or a
        jr z,.l2
        inc b
        inc b
        inc hl
        jr .len
.l2:    ld c,10
        call queue_rect
        pop de
        pop hl
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
; centred big print: HL, E row
print2_c:
        push hl
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.d
        inc b
        inc hl
        jr .l
.d:     ld a,16
        sub b
        ld d,a
        pop hl
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
        ld a,h
        or $88
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
        ret
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

; fill_rect: D col, E row, B width, C height, A byte -> BG + queue
fill_rect:
        push af
        push bc
        push de
        ld a,(noq)
        or a
        call z,queue_rect
        pop de
        pop bc
        call scraddr
        ld a,h
        or $88
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
        ret

; ---------------------------------------------------------------------
; SPRITES  (colour 00 = transparent, i.e. snow shows through)
; shtab entry (8 bytes): dw base, db pw, db h, dw shiftsize, dw 0
; ---------------------------------------------------------------------
dl_reset:
        ld hl,drawlist
        ld (dlptr),hl
        ld (hl),$FF
        ret
; dl_add: A = id, B = x, C = y
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
; dl_text: B = col, C = row, E = popup string index
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
; render (vblank): commit queued rects, erase old sprites, draw list
; ---------------------------------------------------------------------
render:
        call commit
        call special_vblank
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
        ld a,b
        cp 3
        jr z,.e3
.erow:  push bc
        ld d,h
        ld e,l
        ld a,h
        or $88
        ld h,a
        ld c,b
        ld b,0
        ldir
        ex de,hl
        pop bc
        ld a,32
        sub b
        add a,l
        ld l,a
        jr nc,.ern
        inc h
.ern:   dec c
        jr nz,.erow
        pop hl
        jp .e
.e3:    ld b,c                  ; fast path: 3 bytes wide
.e3r:   ld a,h
        or $88
        ld d,a
        ld e,l
        ld a,(de)
        ld (hl),a
        inc l
        inc e
        ld a,(de)
        ld (hl),a
        inc l
        inc e
        ld a,(de)
        ld (hl),a
        ld a,l
        add a,30
        ld l,a
        jr nc,.e3c
        inc h
.e3c:   djnz .e3r
        pop hl
        jp .e
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
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,shtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (pw_),a
        inc hl
        ld a,(hl)
        ld (h_),a
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld a,(ix+1)
        and 3
        jr z,.s0
.s1:    ex de,hl
        add hl,bc
        ex de,hl
        dec a
        jr nz,.s1
.s0:    ld a,(ix+1)
        srl a
        srl a
        ld (col_),a
        push de
        ld d,a
        ld e,(ix+2)
        call scraddr
        pop de
        ld a,(col_)
        ld b,a
        ld a,32
        sub b
        ld b,a
        ld a,(pw_)
        cp b
        jr c,.nw
        ld a,b
.nw:    ld (w_),a
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
        ld a,(w_)
        ld b,a
        ld a,(pw_)
        sub b
        ld (skip_),a
        ld a,(h_)
        ld (rowcnt),a
        ld b,d
        ld c,e
        ex de,hl
        ld a,(pw_)
        cp 3
        jr z,.fast
        ; wider sprites: same pre-masked pairs, looped
        ld l,a
        ld a,(w_)
        cp l
        jp nz,.next             ; clipped wide sprite: skipped (callers keep them on screen)
        ld (savesp),sp
        ld h,b
        ld l,c
        ld sp,hl
        ex de,hl
        ld iyh,a
        ld a,(h_)
        ld c,a
        ld a,l
        ld iyl,a
.fr:    ld b,iyh
.fb:    pop de
        ld a,(hl)
        and e
        or d
        ld (hl),a
        inc l
        djnz .fb
        ld a,iyl
        add a,32
        ld iyl,a
        ld l,a
        jr nc,.fn
        inc h
.fn:    dec c
        jr nz,.fr
        ld sp,(savesp)
        jp .next
.fast:  ; 8-px sprites: pre-masked (mask,data) pairs, read with POP (DI throughout)
        ld a,(w_)
        cp 3
        jp nz,.next             ; clipped narrow sprite: not drawn (never happens in play)
        ld (savesp),sp
        ld h,b
        ld l,c
        ld sp,hl
        ex de,hl                ; HL = VRAM
        ld a,(h_)
        ld b,a
.f3:    pop de
        ld a,(hl)
        and e
        or d
        ld (hl),a
        inc l
        pop de
        ld a,(hl)
        and e
        or d
        ld (hl),a
        inc l
        pop de
        ld a,(hl)
        and e
        or d
        ld (hl),a
        ld a,l
        add a,30
        ld l,a
        jr nc,.f3c
        inc h
.f3c:   djnz .f3
        ld sp,(savesp)
        jp .next
.text:  ld a,(ix+3)
        add a,a
        ld l,a
        ld h,0
        ld de,popstr
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
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
        ld a,(popbg)
        ld b,a
        ld a,(popcol)
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
        ld a,1
        ld (textdirect),a
.tp:    ld a,(hl)
        or a
        jr z,.tpe
        push hl
        push de
        call putchar
        pop de
        pop hl
        inc hl
        inc d
        jr .tp
.tpe:   xor a
        ld (textdirect),a
        jr .next
.pixel: ld a,(ix+2)
        add a,a
        ld l,a
        ld h,rowaddr/256
        ld a,(ix+1)
        ld c,a
        srl a
        srl a
        add a,(hl)
        inc l
        ld h,(hl)
        ld l,a
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
        ld a,1
        ld ($7FFF),a            ; timing marker (emulator watches this; harmless RAM)
        ret
pixtab: db $3F,$00,$CF,$00,$F3,$00,$FC,$00
        db $3F,$40,$CF,$10,$F3,$04,$FC,$01
        db $3F,$80,$CF,$20,$F3,$08,$FC,$02
        db $3F,$C0,$CF,$30,$F3,$0C,$FC,$03
colbyte: db $00,$55,$AA,$FF
