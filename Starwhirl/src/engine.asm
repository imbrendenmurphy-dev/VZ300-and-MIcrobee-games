; =====================================================================
;  STARWHIRL - engine (from ROBOGEDDON 2085, proven on the real VZ300)
;
;  Two frame buffers (BUF0 $E800, BUF1 $F800).  The game draws a whole
;  frame into the back buffer, then calls present.  The field-sync
;  interrupt (IM2, every 50 Hz field) copies the FRONT buffer to video
;  RAM in two halves - top half in one vblank, bottom half in the next -
;  using POP/PUSH so each half is done ~20 lines before the picture
;  starts: no snow.  A finished back buffer is swapped in only at the
;  start of a top half, so the game runs at a steady 25 frames/second.
;  The beeper plays while the game waits for the swap.
; =====================================================================

; ---------------------------------------------------------------------
; the copy routines are built at start-up in the BennVenn SRAM (bank 1),
; one per buffer half: 64 chunks of  ld sp,src / pop x8 / ld sp,dst+16 /
; push x8  (16 bytes each, about 13 T-states a byte), then jp isr_done
; ---------------------------------------------------------------------
CPYLEN  equ 64*28+3
cpy0t   equ $4800
cpy0b   equ cpy0t+CPYLEN
cpy1t   equ cpy0b+CPYLEN
cpy1b   equ cpy1t+CPYLEN
        assert cpy1b+CPYLEN <= SAVEADR, "copy code runs into the records"

gen_copy:
        ld      hl,cpy0t
        ld      de,BUF0
        call    .rt
        ld      de,BUF0+1024
        call    .rt
        ld      de,BUF1
        call    .rt
        ld      de,BUF1+1024
.rt:    ld      bc,VRAM+16
        ld      a,d
        and     4                   ; bottom half -> VRAM+1024
        jr      z,.v
        ld      b,(VRAM+1024+16)/256
.v:     ld      a,64
.ch:    push    af
        ld      (hl),$31            ; ld sp,src
        inc     hl
        ld      (hl),e
        inc     hl
        ld      (hl),d
        inc     hl
        push    de
        ld      de,cpy_pops
        call    .put11
        ld      (hl),$31            ; ld sp,dst+16
        inc     hl
        ld      (hl),c
        inc     hl
        ld      (hl),b
        inc     hl
        ld      de,cpy_push
        call    .put11
        pop     de
        ex      de,hl
        push    bc
        ld      bc,16
        add     hl,bc
        pop     bc
        ex      de,hl
        push    hl
        ld      hl,16
        add     hl,bc
        ld      b,h
        ld      c,l
        pop     hl
        pop     af
        dec     a
        jr      nz,.ch
        ld      (hl),$C3            ; jp isr_done
        inc     hl
        ld      (hl),low isr_done
        inc     hl
        ld      (hl),high isr_done
        inc     hl
        ret
.put11: ld      a,11
.p:     push    af
        ld      a,(de)
        ld      (hl),a
        inc     de
        inc     hl
        pop     af
        dec     a
        jr      nz,.p
        ret
cpy_pops:
        pop     bc
        pop     de
        pop     hl
        exx
        pop     bc
        pop     de
        pop     hl
        pop     ix
        pop     iy
cpy_push:
        push    iy
        push    ix
        push    hl
        push    de
        push    bc
        exx
        push    hl
        push    de
        push    bc

; ---------------------------------------------------------------------
; the interrupt
; ---------------------------------------------------------------------
isr:
        push    af
        push    bc
        push    de
        push    hl
        exx
        push    bc
        push    de
        push    hl
        exx
        push    ix
        push    iy
        ld      (isr_sp),sp
        ld      hl,(fields)
        inc     hl
        ld      (fields),hl
        ; ---- swap in a finished frame once the last one has had two fields
        ;      (25 fps cap; at either half, so a long frame costs 3, not 4)
        ld      hl,shown
        inc     (hl)
        ld      a,(ready)
        or      a
        jr      z,.noswap
        ld      a,(hl)
        cp      2
        jr      c,.noswap
        ld      (hl),0
        ld      a,(front)
        xor     1
        ld      (front),a
        xor     a
        ld      (ready),a
        ld      a,(next_vmode)
        ld      (vmode),a
        ld      b,a
        ld      a,(spk)
        or      b
        ld      (LATCH),a
.noswap:
        ld      a,(phase)
        xor     1
        ld      (phase),a
        jr      z,.bottom
        ld      a,(front)
        or      a
        jp      z,cpy0t
        jp      cpy1t
.bottom:
        ld      a,(front)
        or      a
        jp      z,cpy0b
        jp      cpy1b

isr_done:
        ld      sp,(isr_sp)
.w:     ld      a,(LATCH)           ; stay until field sync has ended
        rla
        jr      nc,.w
        pop     iy
        pop     ix
        exx
        pop     hl
        pop     de
        pop     bc
        exx
        pop     hl
        pop     de
        pop     bc
        pop     af
        ei
        reti


; ---------------------------------------------------------------------
; present: hand the finished back buffer over; make sound while waiting
; ---------------------------------------------------------------------
present:
        ld      a,1
        ld      (ready),a
.w:     ld      a,(snoise)
        or      a
        ld      hl,(sacc)
        ld      de,(sstep)
        jr      nz,.nz
        add     hl,de
        ld      (sacc),hl
        ld      a,h
.o:     rlca
        sbc     a,a
        and     $21
        xor     $20
        ld      (spk),a
        ld      hl,vmode
        or      (hl)
        ld      (LATCH),a
        ld      a,(ready)
        or      a
        jr      nz,.w
        jr      .done
.nz:    add     hl,de
        ld      (sacc),hl
        ld      a,(nlfsr)
        jr      nc,.o
        add     a,a
        jr      nc,.nk
        xor     $1D
.nk:    ld      (nlfsr),a
        jr      .o
.done:  ld      a,(front)           ; draw into the other one
        or      a
        ld      a,BUF1/256
        jr      z,.s
        ld      a,BUF0/256
.s:     ld      (drawh),a
        ld      hl,gtick
        inc     (hl)
        call    sound_tick
        jp      read_input

; ---------------------------------------------------------------------
; clearing (push-based)
; ---------------------------------------------------------------------
; clear_all: whole back buffer to blue
clear_all:
        ld      a,(drawh)
        add     a,8
        ld      h,a
        ld      l,0
        ld      (sp_save),sp
        ld      sp,hl
        ld      hl,$AAAA
        ld      b,64
.l:     di                          ; the interrupt must never push into a cleared row
        rept 16
        push    hl
        endr
        dec     b
        jr      z,.e
        ei
        jr      .l
.e:     ld      sp,(sp_save)
        ei
        ret

; clear_play: clear_all for the game, leaving the HUD corners (columns
;   0-5 and 26-31 of rows 0-4 and 52-63) as they are.  Nothing on the
;   orbit reaches them; the HUD redraws them only when it changes.
;   While SP is inside a partial row the interrupt stays off (its pushes
;   would land in a corner); between full rows it may come in.
clear_play:
        ld      (sp_save),sp
        ld      de,$AAAA
        ; rows 63..52: the middle 20 bytes
        ld      a,(drawh)
        add     a,7
        ld      h,a
        ld      l,$E0+26            ; row 63, column 26
        ld      bc,-32
        ld      a,12
        call    .part
        ; rows 51..5 in full: SP runs on down from the start of row 52
        ld      bc,6                ; (HL is on row 51 col 26: -> row 52 col 0)
        add     hl,bc
        ld      bc,-32
        ld      a,47
        di
        ld      sp,hl
.f:     rept 16
        push    de
        endr
        dec     a
        jr      z,.fe               ; (row 5 done: keep the interrupt off)
        ei
        nop                         ; (the interrupt can come in here)
        di
        jr      .f
.fe:    ld      sp,(sp_save)
        ei
        ; rows 4..0: the middle 20 bytes
        ld      a,(drawh)
        add     a,0
        ld      h,a
        ld      l,4*32+26
        ld      a,5
.part:  ld      (sp_part),sp        ; (SP here may include a return address)
        di
        ld      sp,hl
        rept 10
        push    de
        endr
        ld      sp,(sp_part)
        ei
        add     hl,bc
        dec     a
        jr      nz,.part
        ret

; fill_rows: C = first row, B = count, A = pattern
fill_rows:
        push    af
        call    rowaddr
        pop     af
.r:     push    bc
        ld      b,32
.b:     ld      (hl),a
        inc     hl
        djnz    .b
        pop     bc
        djnz    .r
        ret

; ---------------------------------------------------------------------
; rowaddr: C = y -> HL = back buffer + y*32   (A trashed)
; ---------------------------------------------------------------------
rowaddr:
        ld      a,c
        rrca
        rrca
        rrca
        ld      h,a
        and     $E0
        ld      l,a
        ld      a,h
        and     $07
        ld      h,a
        ld      a,(drawh)
        add     a,h
        ld      h,a
        ret

; ---------------------------------------------------------------------
; masked game sprites (blue arena): each byte is a (keep-mask, pixels) pair
; frame_data_g: A = frame, B = x -> DE ; draw_frame_g / draw_spread_g as above
; ---------------------------------------------------------------------
frame_data_g:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,gframetab
        add     hl,de
        ld      a,b
        and     3
        add     a,a
        add     a,l
        ld      l,a
        jr      nc,.n
        inc     h
.n:     ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ret

draw_frame_g:
        call    frame_data_g
        call    rowaddr
        ld      a,b
        rrca
        rrca
        and     $3F
        or      l
        ld      l,a
        ld      a,(de)
        inc     de
        ld      b,a                 ; width in bytes (1..3)
        ld      a,(de)
        inc     de
        ld      c,a                 ; rows
        ; the (keep-mask, pixels) pairs are read with POP: no interrupt
        ; may push while SP points into the sprite
        di
        ld      (sp_save2),sp
        ex      de,hl
        ld      sp,hl
        ex      de,hl
        ld      a,b
        cp      2
        jr      z,.w2
        jr      c,.w1
        cp      4
        jr      z,.w4
.w3:    pop     de
        ld      a,(hl)
        and     e
        or      d
        ld      (hl),a
        inc     l
        pop     de
        ld      a,(hl)
        and     e
        or      d
        ld      (hl),a
        inc     l
        pop     de
        ld      a,(hl)
        and     e
        or      d
        ld      (hl),a
        ld      a,l
        add     a,30
        ld      l,a
        jr      nc,.n3
        inc     h
.n3:    dec     c
        jr      nz,.w3
        jr      .done
.w4:    pop     de                  ; the big logo letters
        ld      a,(hl)
        and     e
        or      d
        ld      (hl),a
        inc     l
        pop     de
        ld      a,(hl)
        and     e
        or      d
        ld      (hl),a
        inc     l
        pop     de
        ld      a,(hl)
        and     e
        or      d
        ld      (hl),a
        inc     l
        pop     de
        ld      a,(hl)
        and     e
        or      d
        ld      (hl),a
        ld      a,l
        add     a,29
        ld      l,a
        jr      nc,.n4
        inc     h
.n4:    dec     c
        jr      nz,.w4
        jr      .done
.w2:    pop     de
        ld      a,(hl)
        and     e
        or      d
        ld      (hl),a
        inc     l
        pop     de
        ld      a,(hl)
        and     e
        or      d
        ld      (hl),a
        ld      a,l
        add     a,31
        ld      l,a
        jr      nc,.n2
        inc     h
.n2:    dec     c
        jr      nz,.w2
        jr      .done
.w1:    pop     de
        ld      a,(hl)
        and     e
        or      d
        ld      (hl),a
        ld      a,l
        add     a,32
        ld      l,a
        jr      nc,.n1
        inc     h
.n1:    dec     c
        jr      nz,.w1
.done:  ld      sp,(sp_save2)
        ei
        ret

draw_spread_g:
        ld      (sp_fr),a
        ld      a,d
        ld      (sp_kk),a
        ld      a,b
        ld      (sp_x),a
        ld      a,(sp_fr)
        push    bc
        call    frame_data_g
        pop     bc
        ld      a,(de)
        ld      (sp_w),a
        inc     de
        ld      a,(de)
        ld      (sp_h),a
        inc     de
        ld      a,(sp_h)
        srl     a
        ld      h,a
        add     a,c
        ld      c,a
        ld      a,(sp_kk)
        inc     a
        ld      l,a
        xor     a
        ld      b,h
        inc     b
        dec     b
        jr      z,.m2
.m1:    add     a,l
        djnz    .m1
.m2:    ld      b,a
        ld      a,c
        sub     b
        ld      c,a
        ld      a,(sp_h)
        ld      b,a
.rl:    push    bc
        ld      a,(clip_top)
        ld      h,a
        ld      a,c
        cp      h
        jr      c,.skip
        ld      a,(clip_bot)
        ld      h,a
        ld      a,c
        cp      h
        jr      nc,.skip
        call    rowaddr
        ld      a,(sp_x)
        rrca
        rrca
        and     $3F
        or      l
        ld      l,a
        ld      a,(sp_w)
        ld      b,a
.bl:    ld      a,(de)
        and     (hl)
        ld      c,a
        inc     de
        ld      a,(de)
        or      c
        ld      (hl),a
        inc     de
        inc     l
        djnz    .bl
        jr      .nx
.skip:  ld      a,(sp_w)
        add     a,a
        add     a,e
        ld      e,a
        jr      nc,.nx
        inc     d
.nx:    pop     bc
        ld      a,(sp_kk)
        inc     a
        add     a,c
        ld      c,a
        djnz    .rl
        ret

; ---------------------------------------------------------------------
; plot: B = x, C = y, A = colour 0..3 (sets the pixel).  keeps BC, IX, IY
; ---------------------------------------------------------------------
plot:
        add     a,a
        add     a,a
        ld      e,a
        ld      a,b
        and     3
        ld      d,a
        or      e
        ld      e,a
        call    rowaddr
        ld      a,b
        rrca
        rrca
        and     $3F
        or      l
        ld      l,a
        push    hl
        ld      h,high pixtab
        ld      a,d
        add     a,12
        ld      l,a
        ld      a,(hl)              ; the pixel's bits
        cpl
        ld      d,a
        ld      l,e
        ld      e,(hl)              ; its new value
        pop     hl
        ld      a,(hl)
        and     d
        or      e
        ld      (hl),a
        ret

; ---------------------------------------------------------------------
; hline: B = x0, D = x1 (incl), C = y, E = colour pattern ($00/$55/$AA/$FF)
; ---------------------------------------------------------------------
hline:
        push    de
        call    rowaddr
        pop     de
        ld      a,b
        rrca
        rrca
        and     $3F
        ld      (hl_l),a
        or      l
        ld      l,a
        ld      a,d
        rrca
        rrca
        and     $3F
        ld      (hl_r),a
        push    hl
        ld      h,high pixtab
        ld      a,b
        and     3
        add     a,low lmask
        ld      l,a
        ld      a,(hl)
        ld      (hl_lm),a
        ld      a,d
        and     3
        add     a,low rmask
        ld      l,a
        ld      a,(hl)
        ld      (hl_rm),a
        pop     hl
        ld      a,(hl_r)
        ld      b,a
        ld      a,(hl_l)
        cp      b
        jr      nz,.multi
        ld      a,(hl_lm)
        ld      b,a
        ld      a,(hl_rm)
        and     b
        jr      .put
.multi: ld      a,(hl_lm)
        call    .put
        inc     l
        ld      a,(hl_l)
        ld      c,a
        ld      a,(hl_r)
        sub     c
        dec     a
        jr      z,.last
        ld      b,a
.mid:   ld      (hl),e
        inc     l
        djnz    .mid
.last:  ld      a,(hl_rm)
.put:   ld      c,a                 ; C = the pixels to set
        cpl
        and     (hl)
        ld      d,a
        ld      a,c
        and     e
        or      d
        ld      (hl),a
        ret

; ---------------------------------------------------------------------
; vline: B = x, C = y0, D = y1 (incl), A = colour
; ---------------------------------------------------------------------
vline:
        add     a,a
        add     a,a
        ld      e,a
        ld      a,b
        and     3
        push    af
        or      e
        ld      e,a
        ld      d,high pixtab
        ld      a,(de)
        ld      (hl_lm),a           ; value
        pop     af
        add     a,12
        ld      e,a
        ld      a,(de)
        cpl
        ld      (hl_rm),a           ; keep-mask
        ld      a,(rc_y1)
        ld      d,a
        call    rowaddr
        ld      a,b
        rrca
        rrca
        and     $3F
        or      l
        ld      l,a
        ld      a,d
        sub     c
        inc     a
        ld      b,a
        ld      de,32
.l:     ld      a,(hl_rm)
        and     (hl)
        ld      c,a
        ld      a,(hl_lm)
        or      c
        ld      (hl),a
        add     hl,de
        djnz    .l
        ret

; ---------------------------------------------------------------------
; rect: B=x0 C=y0 D=x1 E=y1, A = colour 1..3 (outline)
; ---------------------------------------------------------------------
rect:
        ld      (rc_x0),bc
        ld      (rc_x1),de
        ld      (rc_col),a
        ld      h,high pixtab
        add     a,low colpat
        ld      l,a
        ld      a,(hl)
        ld      (rc_pat),a
        ld      bc,(rc_x0)
        ld      a,(rc_x1)
        ld      d,a
        ld      a,(rc_pat)
        ld      e,a
        call    hline
        ld      a,(rc_x0)
        ld      b,a
        ld      a,(rc_y1)
        ld      c,a
        ld      a,(rc_x1)
        ld      d,a
        ld      a,(rc_pat)
        ld      e,a
        call    hline
        ld      bc,(rc_x0)
        ld      a,(rc_y1)
        ld      d,a
        ld      a,(rc_col)
        call    vline
        ld      a,(rc_x1)
        ld      b,a
        ld      a,(rc_y0)
        ld      c,a
        ld      a,(rc_y1)
        ld      d,a
        ld      a,(rc_col)
        jp      vline

; ---------------------------------------------------------------------
; text3: HL = string (0 end), B = column (0..31), C = y, A = colour mask
;   ($55 yellow/cyan, $AA blue/magenta, $FF red/orange).  -> HL past end
; ---------------------------------------------------------------------
text3:
        ld      (txtcol),a
        push    hl
        call    rowaddr
        ld      a,l
        or      b
        ld      l,a
        ex      de,hl
        pop     hl
.ch:    ld      a,(hl)
        inc     hl
        or      a
        ret     z
        ld      c,a
        ld      a,(tlimit)          ; typing effect: 0 = no limit
        or      a
        jr      z,.go
        dec     a
        jr      z,.stop
        ld      (tlimit),a
.go:    ld      a,c
        push    hl
        push    de
        sub     32
        and     63
        ld      l,a
        ld      h,0
        ld      c,l
        ld      b,h
        add     hl,hl
        add     hl,hl
        add     hl,bc
        ld      bc,font3
        add     hl,bc
        ld      b,5
.rw:    ld      a,(hl)              ; letter pixels replace what's there
        cpl
        ex      de,hl
        and     (hl)
        ld      c,a
        ex      de,hl
        ld      a,(txtcol)
        and     (hl)
        or      c
        ex      de,hl
        ld      (hl),a
        ld      a,l
        add     a,32
        ld      l,a
        jr      nc,.nc
        inc     h
.nc:    ex      de,hl
        inc     hl
        djnz    .rw
        pop     de
        inc     e
        pop     hl
        jr      .ch
.stop:  inc     a                   ; stays at 1; skip to the end of the string
        ld      (tlimit),a
.sk:    ld      a,(hl)
        inc     hl
        or      a
        jr      nz,.sk
        ret

; text3c: centred.  HL = string, C = y, A = colour
text3c:
        push    af
        call    strlen
        ld      a,32
        sub     b
        srl     a
        ld      b,a
        pop     af
        jr      text3

; strlen: HL = string -> B = length (HL kept)
strlen:
        push    hl
        ld      b,0
.l:     ld      a,(hl)
        or      a
        jr      z,.e
        inc     hl
        inc     b
        jr      .l
.e:     pop     hl
        ret

; ---------------------------------------------------------------------
; text2x: double-size text (8x10), built from the 3x5 font as it goes.
;   HL = string, B = column, C = y, A = colour mask
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
        ld      c,l
        ld      b,h
        add     hl,hl
        add     hl,hl
        add     hl,bc               ; *5
        ld      bc,font3
        add     hl,bc
        ld      b,5
.rw:    push    bc
        ld      a,(hl)
        rrca
        rrca
        rrca
        rrca
        call    .dbl
        ld      (t2l),a
        ld      a,(hl)
        call    .dbl
        ld      (t2r),a
        ld      c,2                 ; each font row twice
.r2:    ld      a,(t2l)
        call    .px
        inc     e
        ld      a,(t2r)
        call    .px
        dec     e
        ex      de,hl
        ld      a,l
        add     a,32
        ld      l,a
        jr      nc,.nc
        inc     h
.nc:    ex      de,hl
        dec     c
        jr      nz,.r2
        inc     hl
        pop     bc
        djnz    .rw
        pop     de
        inc     e
        inc     e
        pop     hl
        jr      .ch
.dbl:   and     15                  ; two pixels -> four
        push    hl
        ld      hl,dbltab
        add     a,l
        ld      l,a
        jr      nc,.d1
        inc     h
.d1:    ld      a,(hl)
        pop     hl
        ret
.px:    push    bc                  ; A = letter pixels, DE = screen
        ld      b,a
        cpl
        ex      de,hl
        and     (hl)
        ld      c,a
        ld      a,(txtcol)
        and     b
        or      c
        ld      (hl),a
        ex      de,hl
        pop     bc
        ret
dbltab: db      $00,$00,$00,$0F,$00,$00,$00,$00,$00,$00,$00,$00,$F0,$00,$00,$FF

text2xc:
        push    af
        call    strlen
        ld      a,16
        sub     b
        ld      b,a
        pop     af
        jp      text2x

; ---------------------------------------------------------------------
; numbers
; ---------------------------------------------------------------------
; bcd_to_str: HL = 3-byte BCD score (big-endian) -> numbuf "012345",0
bcd_to_str:
        ld      de,numbuf
        ld      b,3
.l:     ld      a,(hl)
        rrca
        rrca
        rrca
        rrca
        and     15
        add     a,'0'
        ld      (de),a
        inc     de
        ld      a,(hl)
        and     15
        add     a,'0'
        ld      (de),a
        inc     de
        inc     hl
        djnz    .l
        xor     a
        ld      (de),a
        ld      hl,numbuf
        ret

; byte_to_str: A = 0..99 -> numbuf "nn",0  (HL = numbuf)
byte_to_str:
        ld      b,'0'-1
.t:     inc     b
        sub     10
        jr      nc,.t
        add     a,'0'+10
        ld      hl,numbuf
        ld      (hl),b
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),0
        ld      hl,numbuf
        ret

; add_score: DE = 4-digit BCD amount (e.g. $0150 = 150) added to the score
add_score:
        ld      hl,score+2
        ld      a,(hl)
        add     a,e
        daa
        ld      (hl),a
        dec     hl
        ld      a,(hl)
        adc     a,d
        daa
        ld      (hl),a
        dec     hl
        ld      a,(hl)
        adc     a,0
        daa
        ld      (hl),a
        ; extra life each time the score reaches next_life (+50,000 each time)
        ld      hl,score
        ld      de,next_life
        ld      b,3
.cmp:   ld      a,(de)
        cp      (hl)
        jr      c,.award            ; next_life byte < score byte
        ret     nz                  ; next_life byte > score byte
        inc     hl
        inc     de
        djnz    .cmp
.award: ld      hl,next_life        ; next_life += 050000
        ld      a,(hl)
        add     a,$05
        daa
        ld      (hl),a
        ld      a,(demo)
        or      a
        ret     nz
        ld      a,(lives)
        cp      9
        jr      nc,.ms
        inc     a
        ld      (lives),a
.ms:    ld      hl,s_extra
        call    banner_msg
        ld      a,SFX_LIFE
        jp      play_sfx

; ---------------------------------------------------------------------
; random numbers.  rnd -> A (keeps everything else); rnd_n: A=N -> [0,N)
; ---------------------------------------------------------------------
rnd:
        push    hl
        ld      hl,(seed)
        ld      a,h
        rra
        ld      a,l
        rra
        xor     h
        ld      h,a
        ld      a,l
        rra
        ld      a,h
        rra
        xor     l
        ld      l,a
        xor     h
        ld      h,a
        ld      (seed),hl
        pop     hl
        ret

rnd_n:
        push    bc
        push    de
        push    hl
        ld      e,a
        call    rnd
        ld      h,a
        ld      l,0
        ld      d,l
        ld      b,8
.m:     add     hl,hl
        jr      nc,.n
        add     hl,de
.n:     djnz    .m
        ld      a,h
        pop     hl
        pop     de
        pop     bc
        ret

; ---------------------------------------------------------------------
; sound
; ---------------------------------------------------------------------
play_sfx:
        push    hl
        push    de
        ld      l,a
        ld      h,0
        add     hl,hl
        ld      de,sfxtab
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      a,(de)
        ld      hl,sfx_prio
        cp      (hl)
        jr      c,.no
        ld      (hl),a
        inc     de
        ld      (sfx_ptr),de
.no:    pop     de
        pop     hl
        ret

sound_tick:
        ld      hl,(sfx_ptr)
        ld      a,h
        or      l
        jr      z,.mus
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,d
        and     e
        inc     a
        jr      nz,.fx
        ld      hl,0
        ld      (sfx_ptr),hl
        xor     a
        ld      (sfx_prio),a
        jr      .mus
.fx:    ld      (sfx_ptr),hl
        jr      .out
.mus:   ld      de,0
        ld      a,(music_on)
        or      a
        jr      z,.out
        call    music_tick
        ld      a,(snd_mode)
        or      a
        jr      z,.out
        ld      de,0
.out:   ld      a,(snd_mode)
        cp      2
        jr      c,.on
        ld      de,0
.on:    ld      a,d
        and     $80
        ld      (snoise),a
        res     7,d
        ld      (sstep),de
        ret

; music_tick -> DE = step (0 = rest)
music_tick:
        ld      a,(mus_cnt)
        or      a
        jr      nz,.play
        ld      hl,(mus_ptr)
        ld      a,(hl)
        inc     hl
        and     (hl)
        inc     a
        dec     hl
        jr      nz,.ok
        ld      a,(mus_loop)
        or      a
        jr      nz,.rs
        xor     a
        ld      (music_on),a
        ld      de,0
        ret
.rs:    ld      hl,(mus_start)
.ok:    ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      (mus_note),de
        ld      a,(hl)
        inc     hl
        ld      (mus_cnt),a
        ld      (mus_ptr),hl
.play:  ld      a,(mus_cnt)
        dec     a
        ld      (mus_cnt),a
        ld      de,0
        ret     z                   ; the last frame of each note is silent
        ld      de,(mus_note)
        ret

; start_music: HL = tune, A = 1 to loop
start_music:
        ld      (mus_loop),a
        ld      (mus_start),hl
        ld      (mus_ptr),hl
        xor     a
        ld      (mus_cnt),a
        inc     a
        ld      (music_on),a
        ret

stop_music:
        xor     a
        ld      (music_on),a
        ret

; ---------------------------------------------------------------------
; input
;  pad bits: 0 RIGHT, 1 LEFT, 2 UP, 3 DOWN, 4 FIRE
;  joy1 = joystick 1 directions, jfire = any fire button, kmove = W A S D
;  keys/keysnew: 0 M, 1 RETURN or P, 2 Q, 3 D, 4 C, 5 Z, 6 X, 7 SPACE
;  mnu/mnunew: 0 R 1 L 2 U 3 D 4 SELECT (SPACE, RETURN, any fire)
; ---------------------------------------------------------------------
read_input:
        in      a,($2C)
        call    joybits
        and     $0F
        ld      (joy1),a
        in      a,($2E)
        ld      b,a
        in      a,($2D)
        and     b
        ld      b,a
        in      a,($2B)
        and     b
        ld      b,a
        in      a,($27)
        and     b
        cpl
        and     $10
        ld      c,a
        ; ignore "fire" if the port floats (all 5 bits low = no interface)
        in      a,($2C)
        and     $1F
        jr      nz,.fok
        ld      c,0
.fok:   ld      a,c
        ld      (jfire),a
        ; ---- WASD -> kmove
        ld      c,0
        ld      a,($68FE)           ; row 0: W b1
        bit     1,a
        jr      nz,.k1
        set     2,c
.k1:    ld      a,($68FD)           ; row 1: A b4, S b1, D b3
        bit     4,a
        jr      nz,.k2
        set     1,c
.k2:    bit     1,a
        jr      nz,.k3
        set     3,c
.k3:    bit     3,a
        jr      nz,.k4
        set     0,c
.k4:    ld      a,c
        ld      (kmove),a
        ; ---- system keys
        ld      c,0
        ld      a,($68EF)           ; row 4: M b5, SPACE b4
        bit     5,a
        jr      nz,.s1
        set     0,c
.s1:    bit     4,a
        jr      nz,.s2
        set     7,c
.s2:    ld      a,($68BF)           ; row 6: P b4, RETURN b2
        bit     2,a
        jr      nz,.s2b
        set     1,c
.s2b:   bit     4,a
        jr      nz,.s3
        set     1,c
.s3:    ld      a,($68FE)           ; row 0: Q b4
        bit     4,a
        jr      nz,.s4
        set     2,c
.s4:    ld      a,($68FD)           ; row 1: D b3 (also moves right)
        bit     3,a
        jr      nz,.s5
        set     3,c
.s5:    ld      a,($68FB)           ; row 2: Z b4, C b3, X b1
        bit     3,a
        jr      nz,.s6
        set     4,c
.s6:    bit     4,a
        jr      nz,.s7
        set     5,c
.s7:    bit     1,a
        jr      nz,.s8
        set     6,c
.s8:    ld      a,(keys)
        cpl
        and     c
        ld      (keysnew),a
        ld      a,c
        ld      (keys),a
        ; ---- menu pad
        ld      a,(joy1)
        ld      b,a
        ld      a,(kmove)
        or      b
        ld      b,a
        ld      a,(jfire)
        or      b
        ld      c,a
        ld      a,(keys)
        and     $82                 ; SPACE or RETURN
        jr      z,.m1
        set     4,c
.m1:    ld      a,(mnu)
        cpl
        and     c
        ld      (mnunew),a
        ld      a,c
        ld      (mnu),a
        ret

; joybits: A = raw joystick byte (active low) -> pad bits (0 = nothing / no interface)
joybits:
        cpl
        and     $1F
        ld      b,a
        and     $0F
        cp      $0F
        jr      nz,.ok
        xor     a
        ret
.ok:    ld      a,b
        or      a
        ret     z
        xor     a
        bit     0,b
        jr      z,.j1
        set     2,a
.j1:    bit     1,b
        jr      z,.j2
        set     3,a
.j2:    bit     2,b
        jr      z,.j3
        set     1,a
.j3:    bit     3,b
        jr      z,.j4
        set     0,a
.j4:    bit     4,b
        ret     z
        set     4,a
        ret

; ---------------------------------------------------------------------
; draw_c: A = frame, B = centre x, C = centre y.  Clipped top and bottom.
; ---------------------------------------------------------------------
draw_c:
        ld      (dc_fr),a
        ld      l,a
        ld      h,0
        ld      e,l
        ld      d,h
        add     hl,hl
        add     hl,de
        ld      de,fsize
        add     hl,de
        ld      a,b
        sub     (hl)
        ld      b,a
        inc     hl
        ld      a,c
        sub     (hl)
        ld      c,a
        cp      64
        jr      nc,.clip            ; above the top (negative) or below
        inc     hl
        add     a,(hl)
        cp      65
        jr      nc,.clip
        ld      a,(dc_fr)
        jp      draw_frame_g
.clip:  ld      a,(dc_fr)
        ld      d,0
        jp      draw_spread_g

; ---------------------------------------------------------------------
; proj: A = angle (256 a turn, 0 = right, 64 = down), C = radius 0..63
;   -> B = x, C = y on the 128x64 screen (centre 64,32; x radius 3/4 r,
;   y radius 1/2 r, so the orbit looks round on a 4:3 screen).  Keeps IX, IY
; ---------------------------------------------------------------------
proj:
        srl     a                   ; 128 steps a turn
        ld      e,a
        ld      a,c
        add     a,a
        add     a,low ptrow
        ld      l,a
        ld      h,high ptrow
        ld      a,(hl)
        inc     l
        ld      h,(hl)
        ld      l,a                 ; HL = this radius's row
        ld      a,e
        and     31
        ld      c,a
        ld      b,0
        push    hl
        add     hl,bc
        ld      d,(hl)              ; D = r cos q
        pop     hl
        ld      a,32
        sub     c
        ld      c,a
        add     hl,bc
        ld      c,(hl)              ; C = r sin q
        ld      a,e
        and     $60
        jr      z,.q0
        cp      $20
        jr      z,.q1
        cp      $40
        jr      z,.q2
        ; q3: x = +s, y = -c
        ld      a,c
        srl     a
        srl     a
        neg
        add     a,c
        add     a,64
        ld      b,a
        ld      a,d
        srl     a
        neg
        add     a,32
        ld      c,a
        ret
.q0:    ld      a,d                 ; x = +c, y = +s   (x scale 3/4)
        srl     a
        srl     a
        neg
        add     a,d
        add     a,64
        ld      b,a
        ld      a,c
        srl     a
        add     a,32
        ld      c,a
        ret
.q1:    ld      a,c                 ; x = -s, y = +c
        srl     a
        srl     a
        sub     c
        add     a,64
        ld      b,a
        ld      a,d
        srl     a
        add     a,32
        ld      c,a
        ret
.q2:    ld      a,d                 ; x = -c, y = -s
        srl     a
        srl     a
        sub     d
        add     a,64
        ld      b,a
        ld      a,c
        srl     a
        neg
        add     a,32
        ld      c,a
        ret

; plot_c: B = x, C = y, A = colour; ignores points off the screen
plot_c:
        ld      e,a
        ld      a,b
        cp      128
        ret     nc
        ld      a,c
        cp      64
        ret     nc
        ld      a,e
        jp      plot
