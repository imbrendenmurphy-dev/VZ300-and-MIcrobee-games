; =====================================================================
;  CIRCUS 2 - engine: frame interrupt, buffers, sprites, text, input
; =====================================================================

; ---------------------------------------------------------------------
; IM2 frame interrupt.  The ISR deliberately returns with interrupts
; DISABLED: the VZ's INT line follows field sync (low for ~56 lines), so
; re-enabling inside the ISR would re-trigger.  REARM is called from all
; long-running loops and re-enables once field sync has ended.
; ---------------------------------------------------------------------
isr:
        push af
        ld a,1
        ld (fsflag),a
        ld a,(frames)
        inc a
        ld (frames),a
        pop af
        reti

rearm:  ; re-enable interrupts when it is safe (A, flags clobbered)
        ld a,(LATCH)
        rla
        jr nc,.low
        xor a
        ld (fsflag),a
        ei
        ret
.low:   ld a,(fsflag)
        or a
        ret nz
        ei
        ret

init_offtab:
        ld hl,offtab
        ld de,0
        ld b,64
.l:     ld (hl),e
        inc l
        ld (hl),d
        inc l
        push hl
        ld hl,32
        add hl,de
        ex de,hl
        pop hl
        djnz .l
        ret

setup_im2:
        di
        ld hl,IMTAB
        ld de,IMTAB+1
        ld bc,256
        ld (hl),high ISRJP
        ldir
        ld a,$C3
        ld (ISRJP),a
        ld hl,isr
        ld (ISRJP+1),hl
        ld a,high IMTAB
        ld i,a
        im 2
        xor a
        ld (fsflag),a
        call rearm
        ret

; wait until 'frames' reaches 'nextframe', making sound meanwhile,
; then advance nextframe by A frames (A = frames per update)
syncframe:
        ld (.step+1),a
        call snd_idle           ; plays until frames >= nextframe
        ld a,(frames)
        ld b,a
        ld a,(nextframe)
        sub b
        jp p,.ok                ; nextframe >= frames (not behind)
        ld a,b                  ; behind: resync
        ld (nextframe),a
.ok:    ld a,(nextframe)
.step:  add a,2
        ld (nextframe),a
        ret

; plain wait of A frames with sound
waitframes:
        ld b,a
        ld a,(frames)
        add a,b
        ld (nextframe),a
        call snd_idle
        ret

; ---------------------------------------------------------------------
; Buffer copies (unrolled LDI, 16 T/byte)
; ---------------------------------------------------------------------
; copy what changed to VRAM.  Dirty tracking is per row and per byte span:
;   SPANS+$00/$40 : first/last byte column drawn this render (restore needed)
;   SPANS+$80/$C0 : the same for the previous render
;   rowcur bit1   : whole row changed (balloon strip lines)
; A row span is copied if drawn now or last render (old content erased).
present:
        ld a,(fullpres)
        or a
        jr z,.dirty
        dec a
        ld (fullpres),a
        ld hl,BB
        ld de,VRAM
        ld b,57
        call copyrows
        call spans_shift
        jp .hud
.dirty: ld hl,SPANS
.lp:    ld a,l
        ld (pr_y),a
        ld h,high rowcur
        ld a,(hl)
        ld (hl),0
        ld h,high SPANS
        or a
        jr z,.span
        ld c,0
        ld b,31
        jr .shift
.span:  ld c,(hl)               ; cur first
        set 7,l
        ld a,(hl)               ; prev first
        cp c
        jr nc,$+3
        ld c,a                  ; C = min
        set 6,l
        ld b,(hl)               ; prev last
        res 7,l
        ld a,(hl)               ; cur last
        cp b
        jr c,$+3
        ld b,a                  ; B = max
        res 6,l
.shift: ; prev <- cur ; cur <- empty   (L = y)
        ld a,(hl)
        ld (hl),$FF
        set 7,l
        ld (hl),a
        res 7,l
        set 6,l
        ld a,(hl)
        ld (hl),0
        set 7,l
        ld (hl),a
        ld a,b
        sub c
        jr c,.nx
        inc a
        ld (pr_n),a
        ld a,(pr_y)
        add a,a
        or $80
        ld l,a
        ld h,high rowcur
        ld e,(hl)
        inc l
        ld d,(hl)
        ld h,0
        ld l,c
        add hl,de
        push hl
        ld de,BB
        add hl,de
        ex (sp),hl
        ld de,VRAM
        add hl,de
        ex de,hl
        pop hl
        ld a,(pr_n)
        call ldi_n
        ld a,(pr_y)
        and 7
        call z,rearm
.nx:    ld a,(pr_y)
        inc a
        cp 57
        ld l,a
        ld h,high SPANS
        jp nz,.lp
.hud:   ld a,(hud_vdirty)
        or a
        ret z
        dec a
        ld (hud_vdirty),a
        ld hl,BG+57*32          ; HUD goes straight from BG to the screen
        ld de,VRAM+57*32
        ld b,7
        jp copyrows

spans_shift:
        ld hl,SPANS
        ld de,SPANS+$80
        ld bc,$80
        ldir
spans_clear:
        ld hl,SPANS
        ld b,64
.a:     ld (hl),$FF
        inc l
        djnz .a
        ld b,64
.b:     ld (hl),0
        inc l
        djnz .b
        ld hl,rowcur
        ld b,64
.c:     ld (hl),0
        inc l
        djnz .c
        ret

copyrows:       ; B rows of 32 bytes HL->DE (rearms interrupts every 8 rows)
        ld a,b
        ld (cr_cnt),a
.lp:
        REPT 32
        ldi
        ENDR
        ld a,(cr_cnt)
        dec a
        ld (cr_cnt),a
        ret z
        and 7
        call z,rearm
        jp .lp

; restore the byte spans drawn into during the last render from BG
restore_bg:
        ld a,(fullpres)
        or a
        jr z,.dirty
        ld hl,BG
        ld de,BB
        ld b,57
        jp copyrows
.dirty: ld l,$80
.lp:    ld h,high SPANS
        ld c,(hl)               ; prev first
        set 6,l
        ld a,(hl)               ; prev last
        res 6,l
        sub c
        jr c,.nx
        inc a
        ld (pr_n),a
        ld a,l
        ld (pr_y),a
        add a,a                 ; ($80+y)*2 = $100+2y -> low byte 2y
        or $80
        ld l,a
        ld h,high rowcur
        ld e,(hl)
        inc l
        ld d,(hl)
        ld h,0
        ld l,c
        add hl,de
        push hl
        ld de,BB
        add hl,de
        ex (sp),hl
        ld de,BG
        add hl,de
        pop de
        ld a,(pr_n)
        call ldi_n
        ld a,(pr_y)
        and 7
        call z,rearm
        ld a,(pr_y)
        ld l,a
.nx:    inc l
        ld a,l
        cp $80+57
        jr nz,.lp
        ret

; copy A bytes (HL)->(DE), A = 0..32, via unrolled LDI chain
ldi_n:
        neg
        add a,32
        add a,a
        ld (.j+1),a
.j:     jr .chain
.chain:
        REPT 32
        ldi
        ENDR
        ret

full_present:   ; copy entire back buffer to VRAM
        ld hl,BB
        ld de,VRAM
        ld b,64
        jp copyrows

; fill 2K at HL with A
fill2k:
        ld (hl),a
        ld d,h
        ld e,l
        inc de
        ld bc,2047
        ldir
        ret

; ---------------------------------------------------------------------
; LZ decoder: HL=src, DE=dst.  n<$80: n+1 literals; $80..$FE: copy n-$7D
; bytes from 1-byte offset back; $FF end
; ---------------------------------------------------------------------
unlz:
        ld a,(hl)
        inc hl
        cp $FF
        ret z
        cp $80
        jr nc,.copy
        ld c,a
        ld b,0
        inc bc
        ldir
        jr unlz
.copy:  sub $7D
        ld c,a
        ld b,0
        ld a,(hl)
        inc hl
        push hl
        ld h,d
        ld l,e
        push bc
        ld c,a
        ld b,0
        or a
        sbc hl,bc
        pop bc
        ldir
        pop hl
        jr unlz

; ---------------------------------------------------------------------
; Theme recolouring.  newbg (0..3) -> XOR sprite data with (delta & ~mask)
; ---------------------------------------------------------------------
set_theme:      ; A = physical background colour (0..3), B = css (0/1)
        ld c,a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        or $08                  ; graphics mode
        ld (latchbase),a
        ld (LATCH),a
        ld b,0
        ld de,colpat
.cp:    ld a,b
        xor c
        ld hl,colpat_log
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (de),a
        inc de
        inc b
        ld a,b
        cp 4
        jr nz,.cp
        ld a,(curbg)
        xor c
        ld e,a
        ld a,c
        ld (curbg),a
        ld a,e
        or a
        ret z
        ld hl,colpat_log
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)               ; E = delta byte pattern
        ld hl,sprdata_start
        ld bc,(sprdata_end-sprdata_start)/2
.lp:    ld a,(hl)               ; mask
        cpl
        and e
        inc hl
        xor (hl)
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.lp
        ret

; XOR a 2K buffer (HL) with physical bg pattern (logical->physical)
xorbuf_bg:
        ld a,(curbg)
        push hl
        ld hl,colpat_log
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        pop hl
        ld bc,2048
.lp:    ld a,(hl)
        xor e
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.lp
        ret

; ---------------------------------------------------------------------
; Sprite drawing into back buffer.
;   HL = sprite header, B = x (0..127), C = y (signed, -16..79)
; Pre-shifted (mask,data) pairs; popped with SP under DI for speed.
; ---------------------------------------------------------------------
drawspr:        ; HL = header, B = x, C = y
        call ds_setup
        push de
        ld a,b
        rrca
        rrca
        and $1F
        ld h,a
        add a,e
        dec a
        cp 32
        jr c,$+4
        ld a,31
        ld e,h
        call markspan
        pop de
        ld a,c
        add a,8
        ld l,a
        ld h,0
        add hl,hl
        ld a,l
        add a,low ytab
        ld l,a
        ld a,h
        adc a,high ytab
        ld h,a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr ds_go

drawspr_b:      ; HL = header, B = x, destination row base in (dsbase)
        call ds_setup
        ld hl,(dsbase)
ds_go:  ld a,b
        rrca
        rrca
        and $1F
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ; HL = dest, E = nb, D = rows
        ld a,32
        sub e
        ld (ds_stride+1),a
        ld a,e
        cp 2
        jr z,ds2
        cp 3
        jr z,ds3
        ld (ds_nb+1),a
        ld (ds_sp),sp
        di
        ld sp,(ds_src)
ds_row:
ds_nb:  ld e,0
.b:     pop bc
        ld a,(hl)
        and c
        or b
        ld (hl),a
        inc hl
        dec e
        jr nz,.b
ds_stride:
        ld bc,0
        add hl,bc
        dec d
        jr nz,ds_row
ds_done:
        ld sp,(ds_sp)
        jp rearm

; mark rows C .. C+D-1 (signed y), byte columns E..A, as drawn.
; Preserves BC, DE, HL.
markspan:
        push hl
        push de
        push bc
        ld b,a
        ld h,high SPANS
        ld l,c
.l:     ld a,l
        cp 64
        jr nc,.s
        ld a,(hl)
        cp e
        jr c,$+3
        ld (hl),e
        set 6,l
        ld a,(hl)
        cp b
        jr nc,$+3
        ld (hl),b
        res 6,l
.s:     inc l
        dec d
        jr nz,.l
        pop bc
        pop de
        pop hl
        ret

; header HL, x in B -> (ds_src)=shift data, E=nb, D=height. Preserves B,C.
ds_setup:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,b
        and 3
        add a,a
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (ds_src),hl
        ret

ds2:    ld (ds_sp),sp
        di
        ld sp,(ds_src)
.r:     pop bc
        ld a,(hl)
        and c
        or b
        ld (hl),a
        inc l
        pop bc
        ld a,(hl)
        and c
        or b
        ld (hl),a
        ld a,l
        add a,31
        ld l,a
        jr nc,.n
        inc h
.n:     dec d
        jr nz,.r
        jr ds_done

ds3:    ld (ds_sp),sp
        di
        ld sp,(ds_src)
.r:     pop bc
        ld a,(hl)
        and c
        or b
        ld (hl),a
        inc l
        pop bc
        ld a,(hl)
        and c
        or b
        ld (hl),a
        inc l
        pop bc
        ld a,(hl)
        and c
        or b
        ld (hl),a
        ld a,l
        add a,30
        ld l,a
        jr nc,.n
        inc h
.n:     dec d
        jr nz,.r
        jp ds_done

; address in back buffer for (B=x, C=y) -> HL, A = x&3
bbaddr:
        ld a,c
        add a,8
        ld l,a
        ld h,0
        add hl,hl
        ld a,l
        add a,low ytab
        ld l,a
        ld a,h
        adc a,high ytab
        ld h,a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,b
        rrca
        rrca
        and $1F
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,b
        and 3
        ret

; plot pixel: B=x C=y E=physical colour pattern byte
plot:
        ld a,b
        cp 128
        ret nc
        ld a,c
        cp 64
        ret nc
        push de
        ld a,b
        rrca
        rrca
        and $1F
        ld e,a
        ld d,1
        call markspan
        pop de
        call bbaddr
        push hl
        ld hl,pixmask
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld d,(hl)
        pop hl
        ld a,d
        and e
        ld e,a
        ld a,d
        cpl
        and (hl)
        or e
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; Text.  3x5 font in 4-pixel cells -> one byte per glyph row.
; drawtext: HL = zero-terminated string, B = column (0..31), C = y,
;           E = physical colour pattern, D = target buffer high flag
;           (text_buf holds base address of the 2K buffer)
; ---------------------------------------------------------------------
drawtext:
        ld a,(text_buf+1)
        cp high BB
        jr nz,drawtext_nm
        push de
        call strlen
        or a
        jr z,.z
        dec a
        add a,b
        cp 32
        jr c,$+4
        ld a,31
        ld e,b
        ld d,5
        call markspan
.z:     pop de
drawtext_nm:
        ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        push bc
        push de
        call drawchar
        pop de
        pop bc
        pop hl
        inc b
        jr drawtext_nm

; draw char A at column B, row C, colour pattern E into buffer at (text_buf)
drawchar:
        sub 32
        ret c
        ld l,a
        ld h,0
        ld d,h
        push de
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; *5
        ld de,font
        add hl,de
        ex de,hl                ; DE = glyph
        ; dest = text_buf + C*32 + B
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld bc,(text_buf)
        add hl,bc
        pop bc                  ; C = colour pattern (was E)
        REPT 4
        ld a,(de)
        inc de
        ld b,a
        cpl
        and (hl)
        ld (hl),a
        ld a,b
        and c
        or (hl)
        ld (hl),a
        ld a,l
        add a,32
        ld l,a
        jr nc,$+3
        inc h
        ENDR
        ld a,(de)
        ld b,a
        cpl
        and (hl)
        ld (hl),a
        ld a,b
        and c
        or (hl)
        ld (hl),a
        ret

; text with background box: same as drawtext but clears the cell first
; (used for HUD); not needed - HUD is drawn on solid floor colour.

; double-size text: HL=string, B=column (must allow 2 bytes per char), C=y
; E = colour pattern.  Glyph rows doubled vertically too (10 rows high).
drawbig:
        ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        push bc
        push de
        call bigchar
        pop de
        pop bc
        pop hl
        inc b
        inc b
        jr drawbig

bigchar:
        sub 32
        ret c
        push af
        ld a,(text_buf+1)
        cp high BB
        jr nz,.nm
        push de
        ld e,b
        ld a,b
        inc a
        ld d,10
        call markspan
        pop de
.nm:    pop af
        ld l,a
        ld h,0
        ld d,h
        push de
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,font
        add hl,de
        ex de,hl
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld bc,(text_buf)
        add hl,bc
        pop bc                  ; C = colour
        ld b,5
.r:     ld a,(de)
        inc de
        push de
        push bc
        push hl
        ld e,a
        rrca
        rrca
        rrca
        rrca
        and 15
        ld hl,dbl16
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld d,(hl)
        ld a,e
        and 15
        ld hl,dbl16
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        pop hl
        call .wr2
        call .wr2
        pop bc
        pop de
        djnz .r
        ret
.wr2:   ld a,d
        cpl
        and (hl)
        ld b,a
        ld a,d
        and c
        or b
        ld (hl),a
        inc hl
        ld a,e
        cpl
        and (hl)
        ld b,a
        ld a,e
        and c
        or b
        ld (hl),a
        ld a,l
        add a,31
        ld l,a
        ret nc
        inc h
        ret

; length of string HL -> A
strlen:         ; preserves BC, HL
        push hl
        push bc
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc b
        jr .l
.e:     ld a,b
        pop bc
        pop hl
        ret

; centred small text: HL=string C=y E=colour
textc:
        call strlen
        ld b,a
        ld a,32
        sub b
        srl a
        ld b,a
        jp drawtext

; centred big text
bigc:
        call strlen
        add a,a
        ld b,a
        ld a,32
        sub b
        srl a
        ld b,a
        jp drawbig

; print 16-bit number HL as 5 digits (or 6 with trailing 0 for scores)
; numbuf <- ascii
num5:
        ld de,numbuf
        ld bc,-10000
        call .d
        ld bc,-1000
        call .d
        ld bc,-100
        call .d
        ld bc,-10
        call .d
        ld a,l
        add a,'0'
        ld (de),a
        inc de
        xor a
        ld (de),a
        ret
.d:     ld a,'0'-1
.l:     inc a
        add hl,bc
        jr c,.l
        sbc hl,bc
        ld (de),a
        inc de
        ret

; ---------------------------------------------------------------------
; random number (xorshift-ish 16 bit) -> A
; ---------------------------------------------------------------------
rand:
        push hl
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
        pop hl
        ret

; ---------------------------------------------------------------------
; Input.  Returns A = bits: 0 left, 1 right, 2 up, 3 down, 4 fire
; Keys: Z / M / , = left  X / . / / = right ; Q/A up down ; SPACE fire
; Joystick on port $2C ($2E dirs + $2D arm) if detected.
; ---------------------------------------------------------------------
readinput:
        ld c,0
        ld a,($68FB)            ; row 2: B X SHIFT C Z V
        cpl
        bit 4,a                 ; Z
        jr z,$+4
        set 0,c
        bit 1,a                 ; X
        jr z,$+4
        set 1,c
        ld a,($68EF)            ; row 4: N . - , SPACE M
        cpl
        bit 5,a                 ; M  (VZ cursor left)
        jr z,$+4
        set 0,c
        bit 3,a                 ; ,  (VZ cursor right)
        jr z,$+4
        set 1,c
        bit 4,a                 ; SPACE
        jr z,$+4
        set 4,c
        bit 1,a                 ; .  (up)
        jr z,$+4
        set 2,c
        ld a,($68FE)            ; row 0: T W - E Q R
        cpl
        bit 4,a                 ; Q up
        jr z,$+4
        set 2,c
        ld a,($68FD)            ; row 1: G S CTRL D A F
        cpl
        bit 4,a                 ; A down
        jr z,$+4
        set 3,c
        ld a,($68BF)            ; row 6: Y O RET I P U
        cpl
        bit 2,a                 ; RETURN = fire too
        jr z,$+4
        set 4,c
        ld a,(joyon)
        or a
        jr z,.nj
        in a,($2C)              ; J1 directions + fire/arm (both arm lines low)
        cpl
        and $1F
        ld b,a
        rra                     ; up
        jr nc,$+4
        set 2,c
        rr b
        rr b                    ; down
        jr nc,$+4
        set 3,c
        ld a,b
        rra
        jr nc,$+4
        set 0,c                 ; left (bit2 of port)
        rra
        jr nc,$+4
        set 1,c                 ; right
        rra
        jr nc,$+4
        set 4,c                 ; fire
.nj:    ld a,c
        ret

; any key pressed? -> NZ if any key on the whole matrix or joystick fire
anykey:
        ld a,($6800)
        cpl
        and $3F
        ret nz
        ld a,(joyon)
        or a
        ret z
        in a,($2C)
        cpl
        and $10
        ret

; read a specific key: B = row address low byte, C = bit mask -> NZ if down
keydown:
        ld h,$68
        ld l,b
        ld a,(hl)
        cpl
        and c
        ret

; joystick detect: port must read idle (all 5 bits high) consistently
detect_joy:
        xor a
        ld (joyon),a
        ld b,16
.l:     in a,($2C)
        and $1F
        cp $1F
        ret nz
        djnz .l
        ld a,1
        ld (joyon),a
        ret
