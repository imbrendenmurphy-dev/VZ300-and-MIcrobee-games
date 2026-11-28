; ---------------------------------------------------------------------------
; Graphics: playfield composition, sprites, text, screen helpers
; ---------------------------------------------------------------------------

; ---- clear the whole screen to A (fill byte) --------------------------------
cls:
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),a
        ldir
        ret

; ---- fill rows: A = fill byte, B = first row, C = number of rows ------------
fill_rows:
        push af
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,VRAM
        add hl,de
        ld a,c
        ld b,a
        pop af
.r:     push bc
        ld b,32
.c:     ld (hl),a
        inc hl
        djnz .c
        pop bc
        djnz .r
        ret

; ---- copy the viewport from the terrain into BACK ---------------------------
; v_scrb = first terrain byte (0..32)
comp_terrain:
        ld a,(v_scry)
        ld l,a
        ld h,0
        srl h
        rr l                    ; (row * 128 = row/2 * 256 + (row&1) * 128)
        ld a,(v_scry)
        rrca
        and $80
        ld l,a
        ld a,(v_scry)
        srl a
        add a,TERR>>8
        ld h,a
        ld a,(v_scrb)
        add a,l
        ld l,a
        ld de,BACK+2
        ld a,PFH
.r:     push hl
        REPT 32
        ldi
        ENDR
        pop hl
        ld bc,TSTR
        add hl,bc
        ex de,hl
        ld bc,BSTR-32
        add hl,bc
        ex de,hl
        push af
        call int_poll
        pop af
        dec a
        jr nz,.r
        ret

; ---- copy BACK to the screen (rows 0..43) -----------------------------------
blit_back:
        ld hl,BACK+2
        ld de,VRAM
        ld a,PFH
.r:     REPT 32
        ldi
        ENDR
        ld bc,BSTR-32
        add hl,bc
        push af
        call snd_step
        pop af
        dec a
        jr nz,.r
        ret

; ---- sprite: HL = frame (7 rows x 2 bytes, blue = clear), B = x (signed,
; viewport pixels, left edge), C = y (signed, top row). Into BACK.
draw_spr:
        ld a,b
        add a,8
        cp 133
        ret nc
        ld e,a
        and 3
        ld (ds_sh),a
        ld a,e
        rrca
        rrca
        and $3F
        ld (ds_col),a
        ld (ds_ptr),hl
        ld a,7
draw_spr_n:                     ; (A = rows)
        ld (ds_n),a
.row:   ld a,c
        cp PFH
        jp nc,.next
        push bc
        add a,a
        ld l,a
        ld a,(ds_rows)
        ld h,a
        ld e,(hl)
        inc l
        ld d,(hl)
        ld a,(ds_col)
        add a,e
        ld e,a
        adc a,d
        sub e
        ld d,a                  ; DE = destination
        ld hl,(ds_ptr)
        ld b,(hl)
        inc hl
        ld c,(hl)
        ld a,b
        and c
        cp BG
        jr nz,.go
        ld a,b
        cp BG
        jp z,.pop               ; an empty row
.go:    ld h,OPQ>>8
        ld a,(ds_sh)
        or a
        jr nz,.shf
        ; unshifted: two bytes
        ld l,b
        ld l,(hl)
        ld a,(de)
        xor b
        and l
        ld l,a
        ld a,(de)
        xor l
        ld (de),a
        inc de
        ld l,c
        ld l,(hl)
        ld a,(de)
        xor c
        and l
        ld l,a
        ld a,(de)
        xor l
        ld (de),a
        jp .pop
.shf:   ; masks and cleaned data
        ld l,b
        ld a,(hl)
        ld (ds_o0),a
        and b
        ld b,a                  ; d0
        ld l,c
        ld a,(hl)
        ld (ds_o1),a
        and c
        ld c,a                  ; d1
        ld a,(ds_sh)
        dec a
        add a,a
        add a,SHT>>8
        ld h,a                  ; hi page
        ; data bytes
        ld l,b
        ld a,(hl)
        ld (ds_d0),a
        inc h
        ld a,(hl)
        dec h
        ld l,c
        or (hl)
        ld (ds_d1),a
        inc h
        ld a,(hl)
        ld (ds_d2),a
        dec h
        ; mask bytes
        ld a,(ds_o0)
        ld l,a
        ld b,(hl)               ; O0
        inc h
        ld c,(hl)
        dec h
        ld a,(ds_o1)
        ld l,a
        ld a,(hl)
        or c
        ld c,a                  ; O1
        inc h
        ld l,(hl)               ; O2
        ; apply: dst = dst ^ ((dst ^ D) & O)
        ld a,(ds_d0)
        ex de,hl                ; HL = dest, E = O2
        xor (hl)
        and b
        xor (hl)
        ld (hl),a
        inc hl
        ld a,(ds_d1)
        xor (hl)
        and c
        xor (hl)
        ld (hl),a
        inc hl
        ld a,(ds_d2)
        xor (hl)
        and e
        xor (hl)
        ld (hl),a
.pop:   pop bc
.next:  ld hl,(ds_ptr)
        inc hl
        inc hl
        ld (ds_ptr),hl
        inc c
        ld a,(ds_n)
        dec a
        ld (ds_n),a
        jp nz,.row
        ret

; ---- plot one pixel into BACK: B = x (viewport), C = y, A = colour 0..3 ----
plot_back:
        ld e,a
        ld a,c
        cp PFH
        ret nc
        ld a,b
        cp 128
        ret nc
        ld a,c
        add a,a
        ld l,a
        ld h,BROW>>8
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,b
        rrca
        rrca
        and $3F
        add a,2
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a                  ; HL = byte
        ld a,b
        and 3
        ld d,a
        ld a,e
        rrca
        rrca                    ; colour in bits 7-6
        ld e,$C0
        inc d
        jr .s1
.s0:    rrca
        rrca
        srl e
        srl e
.s1:    dec d
        jr nz,.s0
        xor (hl)
        and e
        xor (hl)
        ld (hl),a
        ret

; ---- text -------------------------------------------------------------------
; 3x5 font, one byte per character cell (4 pixels: 3 + a gap).
; set the colours: A = foreground 0-3, B = background 0-3
txt_colour:
        ld (t_fg),a
        ld a,b
        ld (t_bg),a
        ; EXPT[n] for a 4-bit pixel pattern n (bit 3 = leftmost pixel)
        ld hl,EXPT
        ld c,0
.n:     ld b,4
        ld e,0
        ld a,c
        ld d,a
.p:     sla e
        sla e
        bit 3,d
        ld a,(t_bg)
        jr z,.b
        ld a,(t_fg)
.b:     or e
        ld e,a
        sla d
        djnz .p
        ld (hl),e
        inc hl
        inc c
        ld a,c
        cp 16
        jr nz,.n
        ret

; print: HL = zero-terminated string, DE = screen address (top line)
; returns DE after the last character
print:
        ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        call pchar
        pop hl
        inc de
        jr print

; A = character -> cell at DE (5 lines)
pchar:
        sub 32
        jr nc,.ok
        xor a
.ok:    cp 64
        jr c,.ok2
        sub 32                  ; lower case
.ok2:   ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc               ; x5
        ld bc,FONT
        add hl,bc
        push de
        ld b,5
.l:     push hl
        ld a,(hl)
        ld hl,EXPT
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        ld (de),a
        pop hl
        inc hl
        ld a,e
        add a,32
        ld e,a
        jr nc,.nc
        inc d
.nc:    djnz .l
        pop de
        ret

; big text (each font pixel 2 x 2): cell is 2 bytes x 10 lines
print2:
        ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        call pchar2
        pop hl
        inc de
        inc de
        jr print2
pchar2:
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
        ld bc,FONT
        add hl,bc
        push de
        ld b,5
.l:     push bc
        ld a,(hl)
        inc hl
        push hl
        ld c,a
        rrca
        rrca
        and 3                   ; pixels a b
        call .px
        ld (de),a
        inc de
        ld a,c
        and 3                   ; pixels c d
        call .px
        ld (de),a
        dec de
        ; copy this line to the next
        ld h,d
        ld l,e
        ld a,e
        add a,32
        ld e,a
        jr nc,.n1
        inc d
.n1:    ldi
        ldi
        dec de
        dec de
        ld a,e
        add a,32
        ld e,a
        jr nc,.n2
        inc d
.n2:    pop hl
        pop bc
        djnz .l
        pop de
        ret
.px:    ld hl,DBL2
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        ld hl,EXPT
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        ret
DBL2:   db %0000,%0011,%1100,%1111

; ---- address of screen row A, byte column C -> DE
scr_addr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,0
        add hl,bc
        ld de,VRAM
        add hl,de
        ex de,hl
        ret

; print centred on row A (32 cells across): HL = string
print_c:
        push hl
        push af
        ld c,0
.l:     ld a,(hl)
        or a
        jr z,.e
        inc c
        inc hl
        jr .l
.e:     ld a,32
        sub c
        srl a
        ld c,a
        pop af
        call scr_addr
        pop hl
        jp print
print2_c:
        push hl
        push af
        ld c,0
.l:     ld a,(hl)
        or a
        jr z,.e
        inc c
        inc c
        inc hl
        jr .l
.e:     ld a,32
        sub c
        srl a
        ld c,a
        pop af
        call scr_addr
        pop hl
        jp print2

; ---- number -> text -----------------------------------------------------------
; A (0..255) -> numbuf, no leading zeros; HL = numbuf
num_str:
        ld hl,numbuf
        ld c,0                  ; started
        ld b,100
        call .dig
        ld b,10
        call .dig
        add a,'0'
        ld (hl),a
        inc hl
        ld (hl),0
        ld hl,numbuf
        ret
.dig:   ld d,'0'-1
.s:     inc d
        sub b
        jr nc,.s
        add a,b
        ld e,a
        ld a,d
        cp '0'
        jr nz,.put
        bit 0,c
        jr z,.skip
.put:   ld (hl),a
        inc hl
        ld c,1
.skip:  ld a,e
        ret
; A -> two digits (with leading zero) at numbuf
num_str2:
        ld hl,numbuf
        ld d,'0'-1
.s:     inc d
        sub 10
        jr nc,.s
        add a,10+'0'
        ld (hl),d
        inc hl
        ld (hl),a
        inc hl
        ld (hl),0
        ld hl,numbuf
        ret

; ---- small masked image to the screen: HL = data (w bytes x h rows, blue
; clear), DE = screen address, B = rows, C = bytes wide
put_img:
.r:     push bc
        push de
.c:     ld a,(hl)
        push hl
        ld h,OPQ>>8
        ld l,a
        ld l,(hl)               ; opaque mask
        ex de,hl
        xor (hl)
        and e
        xor (hl)
        ld (hl),a
        ex de,hl
        pop hl
        inc hl
        inc de
        dec c
        jr nz,.c
        pop de
        ld a,e
        add a,32
        ld e,a
        jr nc,.n
        inc d
.n:     pop bc
        djnz .r
        ret
; same, opaque (plain copy)
put_raw:
.r:     push bc
        push de
        ld b,0
        ldir
        pop de
        ld a,e
        add a,32
        ld e,a
        jr nc,.n
        inc d
.n:     pop bc
        djnz .r
        ret
