; =====================================================================
;  GYRUVZ - main-RAM glue between the game (bank 1, interrupts on) and
;  the front end (SRAM bank 3, interrupts off), the unpacker, and the
;  big themed font.
; =====================================================================

; ---------------------------------------------------------------------
; unlz: HL = packed data, DE = where to unpack it.
;   token 0..$7F      : that many + 1 bytes follow as they are
;   token $80..$FE    : copy (token - $7D) bytes from DE - offset (2 bytes)
;   token $FF         : the end
; ---------------------------------------------------------------------
unlz:
        ld      a,(hl)
        inc     hl
        cp      $FF
        ret     z
        cp      $80
        jr      nc,.m
        ld      c,a
        ld      b,0
        inc     bc
        ldir
        jr      unlz
.m:     sub     $7D
        ld      c,a
        ld      b,0
        ld      a,(hl)
        inc     hl
        push    hl
        ld      h,(hl)
        ld      l,a                 ; HL = offset
        ex      de,hl               ; HL = dest, DE = offset
        push    hl
        or      a
        sbc     hl,de               ; HL = dest - offset
        pop     de
        ldir
        pop     hl
        inc     hl
        jr      unlz

; ---------------------------------------------------------------------
; gen_polar: build the projection table, polar[r][q] = r * cos(q), r 0..63,
;   q 0..32 (a quarter turn), from cos33 (cos x 255)
; ---------------------------------------------------------------------
gen_polar:
        ld      ix,polar
        ld      c,0                 ; r
.r:     ld      iy,cos33
        ld      b,33
.q:     push    bc
        ld      e,(iy+0)
        ld      d,0
        ld      a,c
        add     a,a
        add     a,a                 ; r's bit 5 to bit 7
        ld      hl,0
        ld      b,6
.m:     add     hl,hl
        add     a,a
        jr      nc,.n
        add     hl,de
.n:     djnz    .m
        ld      de,128
        add     hl,de
        ld      (ix+0),h
        inc     ix
        inc     iy
        pop     bc
        djnz    .q
        inc     c
        ld      a,c
        cp      64
        jr      c,.r
        ret

; ---------------------------------------------------------------------
; gen_shifts: the sprites are stored at pixel phase 0 only; make phases
;   1-3 (shifted right 1-3 pixels, transparent coming in from the left)
;   into SHIFTRAM, and point gframetab at them
; ---------------------------------------------------------------------
gen_shifts:
        ld      ix,gshift
        ld      de,SHIFTRAM
.f:     ld      a,(ix+0)
        cp      255
        ret     z
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,gframetab
        add     hl,bc
        ld      c,(hl)
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      (gs_src),bc
        ld      a,1
.s:     ld      (gs_s),a
        ld      (hl),e
        inc     hl
        ld      (hl),d
        inc     hl
        push    hl
        call    shift_one
        pop     hl
        ld      a,(gs_s)
        inc     a
        cp      4
        jr      c,.s
        inc     ix
        inc     ix
        jr      .f

shift_one:
        ld      hl,(gs_src)
        ld      a,(hl)
        ld      (gs_wb0),a
        inc     hl
        ld      a,(hl)
        ld      (gs_h),a
        inc     hl
        ld      a,(gs_s)
        add     a,(ix+1)
        add     a,3
        srl     a
        srl     a
        ld      (gs_wbs),a
        ld      (de),a
        inc     de
        ld      a,(gs_h)
        ld      (de),a
        inc     de
.row:   ld      a,$FF
        ld      (gs_pk),a
        xor     a
        ld      (gs_pp),a
        ld      (gs_j),a
.col:   ld      a,(gs_j)
        ld      b,a
        ld      a,(gs_wb0)
        cp      b
        ld      b,$FF               ; past the stored bytes: transparent
        ld      c,0
        jr      z,.pad
        jr      c,.pad
        ld      b,(hl)              ; keep-mask
        inc     hl
        ld      c,(hl)              ; pixels
        inc     hl
.pad:   push    hl
        ld      a,(gs_pk)
        ld      h,a
        ld      l,b
        call    .shr
        ld      a,l
        ld      (de),a
        inc     de
        ld      a,(gs_pp)
        ld      h,a
        ld      l,c
        call    .shr
        ld      a,l
        ld      (de),a
        inc     de
        pop     hl
        ld      a,b
        ld      (gs_pk),a
        ld      a,c
        ld      (gs_pp),a
        ld      a,(gs_j)
        inc     a
        ld      (gs_j),a
        ld      b,a
        ld      a,(gs_wbs)
        cp      b
        jr      nz,.col
        ld      a,(gs_h)
        dec     a
        ld      (gs_h),a
        jr      nz,.row
        ret
.shr:   ld      a,(gs_s)            ; HL >> 2s
        add     a,a
.sl:    srl     h
        rr      l
        dec     a
        jr      nz,.sl
        ret

; ---------------------------------------------------------------------
; front_enter: from the boot code (interrupts off): into bank 3 for good
; ---------------------------------------------------------------------
front_enter:
        di
        ld      hl,isr_off
        ld      (ISRJP+1),hl
        ld      a,3
        ld      (home_bank),a
        out     ($37),a
        jp      attract

; isr_off: the frame interrupt while the front end is up.  Some drawing
;   routines turn the interrupt back on when they finish; if one comes in,
;   it just goes back with the interrupt left off.
isr_off:
        reti

; ---------------------------------------------------------------------
; b1_game: called from the front end (bank 3, interrupts off) with
;   A = first sector.  Runs a game (or the demo) in bank 1 with the
;   frame interrupt, then comes back to bank 3 with the interrupt off.
; ---------------------------------------------------------------------
b1_game:
        ld      (b1_sec),a
        ld      a,1
        ld      (home_bank),a
        out     ($37),a
        ; a clean start for the frame swapper
        xor     a
        ld      (ready),a
        ld      (shown),a
        ld      (phase),a
        ld      (front),a
        ld      a,BUF1/256
        ld      (drawh),a
        ld      a,MODE1
        ld      (vmode),a
        ld      (next_vmode),a
        ld      hl,isr
        ld      (ISRJP+1),hl
        ; interrupts on at the top of a field sync
.w1:    ld      a,(LATCH)
        rla
        jr      nc,.w1
.w2:    ld      a,(LATCH)
        rla
        jr      c,.w2
        ei
        ld      a,(b1_sec)
        call    run_game
        di
        ld      hl,isr_off
        ld      (ISRJP+1),hl
        ld      a,MODE1
        ld      (vmode),a
        ld      (LATCH),a
        xor     a
        ld      (flash_t),a
        ld      (warp),a
        ld      a,3
        ld      (home_bank),a
        out     ($37),a
        ld      a,VRAM/256          ; the front end draws straight on the screen
        ld      (drawh),a
        ret

; ---------------------------------------------------------------------
; text2x: the big themed font (7x8 on an 8x10 cell, green drop shadow,
;   yellow top fading to the colour in A below).
;   HL = string, B = byte column, C = y, A = lower colour mask
; ---------------------------------------------------------------------
text2x:
        ld      (txtcol),a
        push    hl
        call    rowaddr
        ld      a,l
        or      b
        ld      l,a
        ex      de,hl               ; DE = screen
        pop     hl
.ch:    ld      a,(hl)
        inc     hl
        or      a
        ret     z
        push    hl
        push    de
        sub     32
        and     63
        ld      l,a
        ld      h,0
        ld      bc,bigindex
        add     hl,bc
        ld      l,(hl)              ; glyph number
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,bigfont
        add     hl,bc               ; HL = glyph
        ; the shadow, one row down, green
        push    hl
        push    de
        ex      de,hl
        ld      bc,32
        add     hl,bc
        ex      de,hl
        xor     a
        ld      (.k+1),a
        ld      (.k2+1),a
        ld      a,8
.sh:    push    af
        call    .row
        pop     af
        dec     a
        jr      nz,.sh
        pop     de
        pop     hl
        ; the letter: yellow, a mixed row, then the colour
        xor     a
.mn:    ld      (t2r),a
        cp      3
        ld      c,$55
        jr      c,.cc
        ld      a,(txtcol)
        ld      c,a
        jr      nz,.cc
        cp      $55
        jr      z,.cc
        ld      c,$77               ; yellow / red pixels
.cc:    ld      a,c
        ld      (.k+1),a
        ld      (.k2+1),a
        call    .row
        ld      a,(t2r)
        inc     a
        cp      8
        jr      c,.mn
        pop     de
        inc     e
        inc     e
        pop     hl
        jr      .ch
; .row: glyph row (HL) onto the screen at DE; HL + 1, DE + 32
.row:   ld      a,(hl)
        inc     hl
        push    hl
        ld      l,a
        ld      h,high expl
        ld      b,(hl)              ; left byte's mask
        inc     h
        ld      c,(hl)              ; right byte's
        ex      de,hl
        ld      a,(hl)
.k:     xor     0
        and     b
        xor     (hl)
        ld      (hl),a
        inc     l
        ld      a,(hl)
.k2:    xor     0
        and     c
        xor     (hl)
        ld      (hl),a
        dec     l
        ld      bc,32
        add     hl,bc
        ex      de,hl
        pop     hl
        ret

exp4:   db      $00,$03,$0C,$0F,$30,$33,$3C,$3F,$C0,$C3,$CC,$CF,$F0,$F3,$FC,$FF
