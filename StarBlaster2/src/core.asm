; =====================================================================
;  STAR BLASTER II - core engine
;  * frame sync + 2-voice beeper (frame_wait from Ghost Hunter 2 / Penguin 2)
;  * input, random, text
;  * "range" renderer: everything is drawn into the back buffer BG ($F800),
;    each drawn byte span is recorded per row (RLO/RHI). Next tick the spans
;    are restored from the BASE image ($F000) and the union of old and new
;    spans is copied BG -> VRAM straight after field sync starts, within a
;    T-state budget, so the VZ never shows snow.
;  * masked, clipped, pre-shifted sprite blitter (POP based, ~38 T/byte)
; =====================================================================

; ---------------------------------------------------------------------
; frame_wait: 2-channel pin-pulse sound until the next field-sync
; falling edge (start of vblank). Loop = 126 T (~28.15 kHz).
; ---------------------------------------------------------------------
frame_wait:
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
        ld a,(latchbase)
        ld (latchcur),a
        ld ($6800),a            ; speaker rest + new mode/palette, in vblank
        ld (acc1),hl
        exx
        ld (acc2),hl
        exx
        ld a,1
        ld (fslow),a            ; this vblank is counted
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
        ret

; next_frame: tick the sequencer and wait for the next vblank
next_frame:
        push ix
        call sound_tick
        pop ix
        jp frame_wait

; fs_check: call between heavy jobs; counts a vblank that arrives while
; we are busy (so music and game timing stay right)
fs_check:
        ld a,($6800)
        rla
        jr c,.high
        ld a,(fslow)
        or a
        ret nz
        inc a
        ld (fslow),a
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
        push bc
        push de
        push ix
        call sound_tick
        pop ix
        pop de
        pop bc
        ret
.high:  xor a
        ld (fslow),a
        ret

; wait_tick: wait (at least one vblank) until TICKLEN frames have passed
; since the last tick; returns at the start of a vblank.
wait_tick:
        call next_frame
        ld hl,(framecount)
        ld de,(tickframe)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.go
        ld a,(ticklen)
        dec a
        cp l
        jr nc,wait_tick
.go:    ld a,l
        ld (elapsed),a
        ld hl,(framecount)
        ld (tickframe),hl
        ret

; ---------------------------------------------------------------------
; input -> inp (bit0 R,1 L,2 U,3 D,4 FIRE), inpnew (new presses)
; keyboard: Q up, A down, M left, ',' right, SPACE / Z fire (as the original)
; keys: bit0 S(sound) 1 P(pause) 2 RETURN 3 X 4 start 5 N(nova) 6 T 7 ESC-ish(Q+X)
; ---------------------------------------------------------------------
read_input:
        ld a,(autoplay)
        or a
        jr nz,read_keys_only    ; AI fills inp
        call read_dirs
        ld a,(inp)
        cpl
        and c
        ld (inpnew),a
        ld a,c
        ld (inp),a
read_keys_only:
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
        set 5,c                 ; N
.k5:    ld a,($6FFE)
        bit 0,a
        jr nz,.k6
        set 6,c                 ; T
.k6:    push bc
        call read_dirs
        ld a,c
        pop bc
        and $10
        jr z,.k7
        set 4,c
.k7:    ld a,(keys)
        cpl
        and c
        ld (keysnew),a
        ld a,c
        ld (keys),a
        ret

; read_dirs -> C = direction/fire bits (keyboard + every joystick port)
read_dirs:
        ld c,0
        ld a,($6FFE)            ; row0: Q bit4
        bit 4,a
        jr nz,.n1
        set 2,c
.n1:    ld a,($6FFD)            ; row1: A bit4
        bit 4,a
        jr nz,.n2
        set 3,c
.n2:    ld a,($6FFB)            ; row2: Z bit4
        bit 4,a
        jr nz,.n2b
        set 4,c
.n2b:   ld a,($6FEF)            ; row4: M bit5, SPACE bit4, ',' bit3
        bit 5,a
        jr nz,.n3
        set 1,c
.n3:    bit 3,a
        jr nz,.n4
        set 0,c
.n4:    bit 4,a
        jr nz,.n5
        set 4,c
.n5:    in a,($2C)
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
        cp $0F                  ; all four directions = no interface / noise
        jr nz,.jok
        xor a
.jok:   or a
        ret z
        ld b,a
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
        ret z
        set 4,c
        ret

; read_digit: A = 1..5 if that number key is held, else 0
read_digit:
        ld a,($6FF7)            ; row3: 1 b4, 2 b1, 3 b3, 4 b5, 5 b0
        ld c,a
        ld a,1
        bit 4,c
        ret z
        inc a
        bit 1,c
        ret z
        inc a
        bit 3,c
        ret z
        inc a
        bit 5,c
        ret z
        inc a
        bit 0,c
        ret z
        xor a
        ret

; start pressed? (SPACE / Z / fire / RETURN) -> NZ if newly pressed
check_start:
        ld a,(keysnew)
        and $14
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

; HL = A * E (unsigned)
mul8:
        ld hl,0
        ld d,0
        ld b,8
.l:     add hl,hl
        rla
        jr nc,.n
        add hl,de
.n:     djnz .l
        ret

; ---------------------------------------------------------------------
; range bookkeeping
; ---------------------------------------------------------------------
; clear all range arrays (new + old)
ranges_init:
        ld hl,RLO
        ld b,64
.a:     ld (hl),$FF
        inc l
        djnz .a
        ld b,64
.b:     ld (hl),0
        inc l
        djnz .b
        ld b,64
.c:     ld (hl),$FF
        inc l
        djnz .c
        ld b,64
.d:     ld (hl),0
        inc l
        djnz .d
        ret

; mark: A = row (0..63), C = first byte col, B = last byte col
mark:
        ld h,RLO/256
        ld l,a
        ld a,c
        cp (hl)
        jr nc,.m1
        ld (hl),c
.m1:    set 6,l
        ld a,(hl)
        cp b
        ret nc
        ld (hl),b
        ret

; mark_all: whole screen dirty (BG -> VRAM over the next vblanks)
mark_all:
        ld hl,RLO
        ld b,64
.a:     ld (hl),0
        inc l
        djnz .a
        ld b,64
.b:     ld (hl),31
        inc l
        djnz .b
        ret

; row address: A = row -> HL = $F800 + row*32 (BG)
bgrow:
        rrca
        rrca
        rrca
        ld l,a
        and 7
        add a,BG/256
        ld h,a
        ld a,l
        and $E0
        ld l,a
        ret

; copyn: HL = src, DE = dst, A = count (1..32), via an LDI chain
copyn:
        add a,a
        ld c,a
        ld a,low ldi_end
        sub c
        ld c,a
        ld a,high ldi_end
        sbc a,0
        ld b,a
        push bc
        ret
ldi_chain:
        DUP 32
        ldi
        EDUP
ldi_end:
        ret

; erase: restore last tick's spans from BASE into BG
erase:
        ld e,0
.r:     ld h,RLO/256
        ld a,e
        or $80
        ld l,a
        ld a,(hl)               ; old lo
        cp $FF
        jr z,.nx
        ld c,a
        set 6,l
        ld a,(hl)               ; old hi
        sub c
        jr c,.nx
        inc a
        push de
        push af
        ld a,e
        call bgrow
        ld a,l
        or c
        ld l,a                  ; HL = BG
        ld d,h
        ld e,l
        ld a,h
        sub 8
        ld h,a                  ; HL = BASE
        pop af
        call copyn
        pop de
.nx:    inc e
        ld a,e
        cp 64
        ret z
        and 15
        jr nz,.r
        push de
        call fs_check
        pop de
        jr .r

; prep_commit: (outside vblank) roll new -> old and generate the code that
; copies every (old U new) span BG -> VRAM:  ld hl,src : ld de,dst :
; call ldi_chain+k ... When the T-state budget for one vblank is used up a
; "call next_frame" is inserted, so the rest lands in the next vblank.
prep_commit:
        exx
        ld de,0                 ; DE' = budget in 16-T units
        exx
        ld de,CCODE             ; DE = code pointer
        ld hl,RLO               ; L = row
.r:     ld a,(hl)               ; new lo
        set 7,l
        and (hl)                ; old lo
        inc a
        jp z,.skip              ; both empty
        ld c,(hl)               ; old lo
        res 7,l
        ld a,(hl)               ; new lo
        ld (hl),$FF
        set 7,l
        ld (hl),a               ; old lo := new lo
        cp c
        jr nc,.m1
        ld c,a                  ; C = min lo
.m1:    set 6,l
        ld b,(hl)               ; old hi
        res 7,l
        ld a,(hl)               ; new hi
        ld (hl),0
        set 7,l
        ld (hl),a               ; old hi := new hi
        cp b
        jr c,.m2
        ld b,a                  ; B = max hi
.m2:    ld a,l
        and $3F
        ld l,a
        ld a,b
        sub c
        jp c,.skip
        inc a                   ; A = n
        push af
        exx
        add a,4                 ; cost = n + 4 units
        ld c,a
        add a,e
        ld e,a
        jr nc,.b1
        inc d
.b1:    ld a,d
        cp CBUDGET/4096
        jr c,.b2
        ld e,c                  ; new vblank starts with this span
        ld d,0
        exx
        ex de,hl
        ld (hl),$CD             ; call next_frame
        inc hl
        ld (hl),low next_frame
        inc hl
        ld (hl),high next_frame
        inc hl
        ex de,hl
        exx
.b2:    exx
        ld a,l
        rrca
        rrca
        rrca
        ld b,a
        and $E0
        or c
        ld c,a
        ld a,b
        and 7
        or BG/256
        ld b,a                  ; BC = BG source
        ex de,hl
        ld (hl),$21             ; ld hl,BG
        inc hl
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld (hl),$11             ; ld de,VRAM
        inc hl
        ld (hl),c
        inc hl
        ld a,b
        sub $88
        ld (hl),a
        inc hl
        ld (hl),$CD             ; call ldi_chain + (32-n)*2
        inc hl
        pop af
        add a,a
        ld c,a
        ld a,low ldi_end
        sub c
        ld (hl),a
        inc hl
        ld a,high ldi_end
        sbc a,0
        ld (hl),a
        inc hl
        ex de,hl
.skip:  ld a,l
        and $3F
        inc a
        ld l,a
        cp 64
        jp z,.end
        and 15
        jp nz,.r
        push hl
        push de
        call fs_check
        pop de
        pop hl
        jp .r
.end:
        ld a,$C9                ; ret
        ld (de),a
        ret

; commit: run the generated copy code. Call right at the start of vblank.
commit  equ CCODE

; ---------------------------------------------------------------------
; text: 3x5 font, 4 px per char (column = byte), opaque background
; set_ink: A = fg colour (0-3), B = bg colour
; txtbase=1: also write into BASE (so the text survives erase)
; txtdbl=1: double height (10 rows)
; ---------------------------------------------------------------------
set_ink:
        ld c,a
        ld a,c
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

; print: HL = string (0-terminated), D = column, E = row
print:
.go:    ld a,(hl)
        or a
        ret z
        push hl
        push de
        call putchar
        call fs_check
        pop de
        pop hl
        inc hl
        inc d
        jr .go

; print_c: centred: HL = string, E = row
print_c:
        push hl
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.e
        inc b
        inc hl
        jr .l
.e:     pop hl
        ld a,32
        sub b
        srl a
        ld d,a
        jr print

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
        ex de,hl                ; DE = glyph, H = col, L = row
        ld a,h
        ld (pc_col),a
        ld a,l
        ld (pc_row),a
        ld b,5
.row:   ld a,(de)
        inc de
        push de
        push bc
        ld e,a
        ld d,0
        ld hl,inktab
        add hl,de
        ld a,(hl)
        ld (pc_byte),a
        ld a,(txtdbl)
        or a
        jr z,.one
        call .put
.one:   call .put
        pop bc
        pop de
        djnz .row
        ret
.put:   ld a,(pc_row)
        cp 64
        jr nc,.skip
        call bgrow
        ld a,(pc_col)
        or l
        ld l,a
        ld a,(pc_byte)
        ld (hl),a
        ld a,(txtbase)
        or a
        jr z,.nb
        ld a,(pc_byte)
        res 3,h                 ; BG $F8xx -> BASE $F0xx
        ld (hl),a
.nb:    ld a,(pc_col)
        ld c,a
        ld b,a
        ld a,(pc_row)
        call mark
.skip:  ld hl,pc_row
        inc (hl)
        ret

; print_num: HL = 16-bit value, D/E position, B = digits (3..5), leading zeros kept
print_num:
        push de
        ld de,numbuf+5
        xor a
        ld (de),a
        ld c,5
.d:     push bc
        call div10
        pop bc
        add a,'0'
        dec de
        ld (de),a
        dec c
        jr nz,.d
        ld a,5
        sub b
        ld l,a
        ld h,0
        ld de,numbuf
        add hl,de
        pop de
        jp print
; HL = HL / 10, A = remainder
div10:
        push bc
        ld b,16
        xor a
.l:     add hl,hl
        rla
        cp 10
        jr c,.n
        sub 10
        inc l
.n:     djnz .l
        pop bc
        ret

; print_bcd: HL -> BCD bytes (big end first), B = byte count, D/E position
print_bcd:
.l:     ld a,(hl)
        push hl
        push bc
        push af
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        push de
        call putchar
        pop de
        inc d
        pop af
        and 15
        add a,'0'
        push de
        call putchar
        pop de
        inc d
        pop bc
        pop hl
        inc hl
        djnz .l
        ret

; ---------------------------------------------------------------------
; pixels
; ---------------------------------------------------------------------
; pset_c: B = x (0..127), C = y, E = colour; clipped to 0..clipbot-1
pset_c:
        ld a,b
        cp 128
        ret nc
        ld a,(clipbot)
        dec a
        cp c
        ret c
; pset: unclipped. psbase=1: draw into BASE and mark the OLD span
; (so erase copies it to BG and it is committed)
pset:
        ld a,c
        rrca
        rrca
        rrca
        ld l,a
        and 7
        add a,BG/256
        ld h,a
        ld a,l
        and $E0
        ld l,a
        ld a,b
        rrca
        rrca
        and $1F
        ld d,a
        or l
        ld l,a
        ld a,(psbase)
        or a
        jr z,.bg
        res 3,h
.bg:    ld a,b
        and 3
        ld b,a
        ld a,e
        add a,a
        add a,a
        or b
        push hl
        ld hl,colpx
        add a,l
        ld l,a
        ld e,(hl)               ; colour bits (table is page-safe)
        ld a,b
        add a,low pxmask
        ld l,a
        ld a,(hl)
        pop hl
        and (hl)
        or e
        ld (hl),a
        ; mark row C, col D (new spans, or old spans for BASE drawing)
        ld h,RLO/256
        ld l,c
        ld a,(psbase)
        or a
        jr z,.nm
        set 7,l
.nm:    ld a,d
        cp (hl)
        jr nc,.m1
        ld (hl),d
.m1:    set 6,l
        cp (hl)
        ret c
        ld (hl),d
        ret
; line: (lx0,ly0)-(lx1,ly1) in colour lcol, clipped per pixel (Bresenham)
line:
        ld a,(lx1)
        ld hl,lx0
        sub (hl)
        ld b,1
        jr nc,.dxp
        neg
        ld b,-1
.dxp:   ld (ldx),a
        ld a,b
        ld (lsx),a
        ld a,(ly1)
        ld hl,ly0
        sub (hl)
        ld b,1
        jr nc,.dyp
        neg
        ld b,-1
.dyp:   ld (ldy),a
        ld a,b
        ld (lsy),a
        ; err = dx - dy (signed 16 not needed: |d| < 128)
        ld a,(ldx)
        ld hl,ldy
        sub (hl)
        ld (lerr),a
        ld a,(ldx)
        ld hl,ldy
        cp (hl)
        jr nc,.n1
        ld a,(hl)
.n1:    inc a
        ld (lcnt),a
.lp:    ld a,(lx0)
        ld b,a
        ld a,(ly0)
        ld c,a
        ld a,(lcol)
        ld e,a
        call pset_c
        ld a,(lcnt)
        dec a
        ret z
        ld (lcnt),a
        and 15
        call z,fs_check
        ld a,(lerr)
        add a,a                 ; e2 = 2*err
        ld c,a
        ; if e2 > -dy : err -= dy, x += sx
        ld a,(ldy)
        neg
        ld b,a
        ld a,c
        sub b
        jp m,.ny
        jr z,.ny
        ld a,(lerr)
        ld hl,ldy
        sub (hl)
        ld (lerr),a
        ld a,(lsx)
        ld hl,lx0
        add a,(hl)
        ld (hl),a
.ny:    ; if e2 < dx : err += dx, y += sy
        ld a,(ldx)
        ld b,a
        ld a,c
        sub b
        jp p,.lp
        ld a,(lerr)
        ld hl,ldx
        add a,(hl)
        ld (lerr),a
        ld a,(lsy)
        ld hl,ly0
        add a,(hl)
        ld (hl),a
        jr .lp

; ---------------------------------------------------------------------
; sprites
; draw_spr: A = type, C = size index (FE invisible, FF dot), HL = centre x
; (signed 16), E = centre y (signed 8). Clips to x 0..127, y 0..clipbot-1.
; Sets spr_hw / spr_hh (half size). Carry set if nothing was drawn.
; ---------------------------------------------------------------------
draw_spr:
        ld (ds_sx),hl
        ld b,a
        ld (ds_type),a
        ld a,e
        ld (ds_sy),a
        ld a,c
        cp $FE
        jp z,ds_off
        cp $FF
        jp z,ds_dot
        ld l,b
        ld h,0
        add hl,hl
        ld de,sprtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld l,c
        ld h,0
        add hl,hl
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL = entry
        ld a,(hl)
        ld (ds_b),a
        inc hl
        ld a,(hl)
        ld (ds_h),a
        inc hl
        ld a,(hl)
        ld (spr_hw),a
        inc hl
        ld a,(hl)
        ld (spr_hh),a
        inc hl
        ld (ds_data),hl
        ; x0 = sx - hw
        ld hl,(ds_sx)
        ld a,(spr_hw)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.xneg
        ld a,l
        cp 128
        jp nc,ds_off
        jr .xok
.xneg:  inc a
        jp nz,ds_off              ; below -256
        ; x0 in -256..-1 : visible if -x0 < 4b
        push hl
        xor a
        sub l
        ld e,a                  ; -x0 (low)
        ld a,(ds_b)
        add a,a
        add a,a
        jr c,.xv                ; 4b >= 256: visible
        cp e
        pop hl
        jp c,ds_off
        jp z,ds_off
        push hl
.xv:    pop hl
.xok:   ld a,l
        and 3
        ld (ds_shift),a
        sra h
        rr l
        sra h
        rr l
        ld a,l
        ld (ds_col),a           ; signed byte column
        ; cstart / cend
        ld c,0
        bit 7,a
        jr z,.cs
        neg
        ld c,a
.cs:    ld a,c
        ld (ds_cs),a
        ld a,(ds_col)
        ld b,a
        ld a,32
        sub b                   ; 32 - col (may exceed b)
        ld b,a
        ld a,(ds_b)
        cp b
        jr c,.ce
        ld a,b
.ce:    sub c                   ; n = cend - cstart
        jp c,ds_off
        jp z,ds_off
        ld (ds_n),a
        ; rows: y0 = sy - hh
        ld a,(spr_hh)
        ld b,a
        ld a,(ds_sy)
        sub b
        ld (ds_y0),a
        ld c,0
        bit 7,a
        jr z,.rs
        neg
        ld c,a
.rs:    ld a,c
        ld (ds_rs),a
        ld a,(ds_y0)
        bit 7,a
        jr nz,.rok
        ld b,a
        ld a,(clipbot)
        sub b                   ; clipbot - y0
        jp c,ds_off
        jp z,ds_off
        ld b,a
        ld a,(ds_h)
        cp b
        jr c,.re
        ld a,b
        jr .re
.rok:   ld a,(ds_h)
.re:    sub c
        jp c,ds_off
        jp z,ds_off
        ld (ds_rows),a
        ; data = data + shift*(2*b*h) + (rs*b + cs)*2
        ld a,(ds_b)
        ld e,a
        ld a,(ds_h)
        call mul8               ; HL = b*h
        add hl,hl
        ld b,h
        ld c,l                  ; BC = 2bh
        ld hl,(ds_data)
        ld a,(ds_shift)
        or a
        jr z,.s0
.sh:    add hl,bc
        dec a
        jr nz,.sh
.s0:    push hl
        ld a,(ds_b)
        ld e,a
        ld a,(ds_rs)
        call mul8
        ld a,(ds_cs)
        ld e,a
        ld d,0
        add hl,de
        add hl,hl
        pop de
        add hl,de
        ld (ds_data),hl
        ; screen = BG + (y0+rs)*32 + col + cs
        ld a,(ds_y0)
        ld b,a
        ld a,(ds_rs)
        add a,b
        ld (ds_r0),a
        call bgrow
        ld a,(ds_col)
        ld b,a
        ld a,(ds_cs)
        add a,b
        ld (ds_c0),a
        or l
        ld l,a
        ld (ds_scr),hl
        ; patch the blitter
        ld a,(ds_n)
        ld b,a
        add a,a
        ld c,a
        add a,a
        add a,c                 ; 6n
        ld c,a
        ld hl,blit_end
        ld a,l
        sub c
        ld l,a
        jr nc,.p1
        dec h
.p1:    ld (blit_jp+1),hl
        ld a,(ds_b)
        sub b
        add a,a
        ld l,a
        ld h,0
        ld (blit_rs+2),hl
        ld a,32
        sub b
        ld l,a
        ld (blit_ss+1),hl
        ; mark rows
        ld a,(ds_c0)
        ld c,a
        add a,b
        dec a
        ld b,a
        ld a,(ds_rows)
        ld e,a
        ld a,(ds_r0)
.mk:    push af
        push de
        push bc
        call mark
        pop bc
        pop de
        pop af
        inc a
        dec e
        jr nz,.mk
        ; blit
        ld (save_sp),sp
        ld hl,(ds_data)
        ld sp,hl
        ld hl,(ds_scr)
blit_row:
blit_jp: jp 0
        DUP 32
        pop bc
        ld a,(hl)
        and c
        or b
        ld (hl),a
        inc hl
        EDUP
blit_end:
blit_rs: ld ix,0
        add ix,sp
        ld sp,ix
blit_ss: ld de,0
        add hl,de
        ld a,(ds_rows)
        dec a
        ld (ds_rows),a
        jp nz,blit_row
        ld sp,(save_sp)
        or a
        ret
ds_dot: ; a single pixel in the type's colour
        xor a
        ld (spr_hw),a
        ld (spr_hh),a
        ld hl,(ds_sx)
        ld a,h
        or a
        jr nz,ds_off
        ld a,l
        cp 128
        jr nc,ds_off
        ld a,(ds_sy)
        bit 7,a
        jr nz,ds_off
        ld c,a
        ld b,l
        ld a,(ds_type)
        ld e,a
        ld d,0
        ld hl,typecol
        add hl,de
        ld e,(hl)
        call pset_c
        or a
        ret
ds_off: scf
        ret

; ---------------------------------------------------------------------
; build_library: unpack shift-0 sprites to their homes (bank 3 / high RAM)
; and generate the other three pixel shifts.
; ---------------------------------------------------------------------
build_library:
        ld a,3
        out ($37),a             ; BennVenn SRAM bank 3 at $4000-$67FF
        ld hl,libsrc
.e:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        ret z
        ld a,(hl)
        ld (lb_b),a
        inc hl
        ld a,(hl)
        ld (lb_h),a
        dec hl
        ld bc,4
        ldir                    ; header
        push de
        ld a,(lb_b)
        ld e,a
        ld a,(lb_h)
        push hl
        call mul8
        add hl,hl
        ld (lb_sz),hl
        ld b,h
        ld c,l
        pop hl
        pop de
        ldir                    ; shift 0
        push hl
        ld a,3
.s:     push af
        ; copy previous block
        ld hl,(lb_sz)
        ex de,hl
        push hl
        or a
        sbc hl,de               ; HL = DE_old - size = previous block
        pop de
        ld bc,(lb_sz)
        push de
        ldir
        pop hl                  ; HL = new block start
        push de
        ld a,(lb_h)
        ld c,a
.row:   push bc
        ld a,(lb_b)
        ld b,a
        call shift_row
        ld a,(lb_b)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        pop bc
        dec c
        jr nz,.row
        pop de
        pop af
        dec a
        jr nz,.s
        pop hl
        jr .e

; shift_row: HL = row of B (mask,data) pairs, shift right one pixel
shift_row:
        ld c,2
.tw:    push hl
        push bc
        scf
.m:     rr (hl)
        inc hl
        inc hl
        djnz .m
        pop bc
        pop hl
        push hl
        push bc
        inc hl
        or a
.d:     rr (hl)
        inc hl
        inc hl
        djnz .d
        pop bc
        pop hl
        dec c
        jr nz,.tw
        ret

; fill_base: A = byte, rows D..E-1 of BASE and BG (no marking)
fill_rows:
        ld (fr_byte),a
.r:     ld a,d
        cp e
        ret nc
        call bgrow
        ld a,(fr_byte)
        ld b,32
.b:     ld (hl),a
        res 3,h
        ld (hl),a
        set 3,h
        inc l
        djnz .b
        inc d
        jr .r

; reveal_row: A = row: mark the whole row for commit (BG already = BASE)
reveal_row:
        ld c,0
        ld b,31
        jp mark
