; ===========================================================================
;  out_lay.inc - page layout shared by the PDF and print overlays.
;  Lines of at most 80 characters: a line feed ends a line (a final line feed
;  doesn't start an empty line); a longer line breaks after the last space in
;  its first 80 characters, or straight after the 80th if there is none.
;  Needs: zLP (2 bytes, the next logical position), zLB (81 bytes).
; ===========================================================================
zl_start: ld hl,0
        ld (zLP),hl
        ret

; the next line -> zLB, B = its length; C = there are no more lines
zl_next: call textlen
        ld de,(zLP)
        or a
        sbc hl,de           ; what is left
        scf
        ret z
        ld c,81             ; look at up to 81 characters
        ld a,h
        or a
        jr nz,zy_c
        ld a,l
        cp 81
        jr nc,zy_c
        ld c,l
zy_c:   ex de,hl
        call log2phys
        ld de,zLB
        ld b,0
zy_l:   ld a,b
        cp c
        jr z,zy_lim
        push de             ; (jump the gap)
        ld de,(gs)
        or a
        sbc hl,de
        add hl,de
        pop de
        jr nz,zy_g
        ld hl,(ge)
zy_g:   ld a,(hl)
        inc hl
        cp 10
        jr z,zy_lf
        ld (de),a
        inc de
        inc b
        jr zy_l
zy_lf:  ld e,b              ; B characters and the line feed
        ld d,0
        inc de
        jr zy_adv
zy_lim: ld a,b
        cp 81
        jr z,zy_wr
        ld e,b              ; the end of the text
        ld d,0
zy_adv: ld hl,(zLP)
        add hl,de
        ld (zLP),hl
        or a
        ret
zy_wr:  ld hl,zLB+79        ; too long: after the last space in the first 80
        ld b,80
zy_s:   ld a,(hl)
        cp ' '
        jr z,zy_x
        dec hl
        djnz zy_s
        ld b,80
zy_x:   ld e,b
        ld d,0
        jr zy_adv

; HL = a message in the overlay -> msgbuf (11 characters at most), shown
; after the overlay ends.  Returns NC, A = 0 (no key).
zl_msg: ld de,msgbuf
        ld bc,11
zl_cp:  ld a,(hl)
        ld (de),a
        or a
        jr z,zl_sh
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,zl_cp
        xor a
        ld (de),a
zl_sh:  ld hl,msgbuf
        call set_msg
        xor a
        ret
