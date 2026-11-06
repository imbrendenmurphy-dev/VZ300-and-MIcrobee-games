; =====================================================================
;  ROBOGEDDON - engine
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
; copy macros: one 16-byte chunk, front buffer -> VRAM
; ---------------------------------------------------------------------
        MACRO CPYCHUNK src, dst
        ld      sp,src
        pop     bc
        pop     de
        pop     hl
        exx
        pop     bc
        pop     de
        pop     hl
        pop     ix
        pop     iy
        ld      sp,dst+16
        push    iy
        push    ix
        push    hl
        push    de
        push    bc
        exx
        push    hl
        push    de
        push    bc
        ENDM

        MACRO CPYHALF srcbase, dstbase
cpy_n   defl    0
        DUP     64
        CPYCHUNK srcbase+cpy_n*16, dstbase+cpy_n*16
cpy_n   defl    cpy_n+1
        EDUP
        jp      isr_done
        ENDM

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

cpy0t:  CPYHALF BUF0, VRAM
cpy0b:  CPYHALF BUF0+1024, VRAM+1024
cpy1t:  CPYHALF BUF1, VRAM
cpy1b:  CPYHALF BUF1+1024, VRAM+1024

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
; backdrop: a third picture in the BennVenn SRAM at $4000 holding the
; still parts of a front-end screen, copied in at the start of each frame
; ---------------------------------------------------------------------
bd_open:
        ld      a,(drawh)
        ld      (drawh_sv),a
        ld      a,BD/256
        ld      (drawh),a
        ret
bd_begin:
        call    bd_open
        jp      clear_all
bd_end:
        ld      a,(drawh_sv)
        ld      (drawh),a
        ret
bd_copy:
        ld      a,(drawh)
        ld      d,a
        ld      e,0
        ld      hl,BD
        ld      bc,2048
.l:
        rept 32
        ldi
        endr
        jp      pe,.l
        ret

; ---------------------------------------------------------------------
; clearing (push-based)
; ---------------------------------------------------------------------
; clear_all: whole back buffer to 0
clear_all:
        ld      a,(drawh)
        add     a,8
        ld      h,a
        ld      l,0
        ld      (sp_save),sp
        ld      sp,hl
        ld      hl,0
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

; clear_arena: rows 8..62 to 0 except the 2-pixel side walls
clear_arena:
        ld      a,(drawh)
        add     a,7
        ld      h,a
        ld      l,$E0               ; end of row 62 = row 63 start
        ld      (sp_save),sp
        ld      sp,hl
        ld      a,(wallpat)
        and     $0F                 ; pixels 126,127
        ld      d,a
        ld      e,0                 ; bytes 30,31 = 0, wall
        ld      a,(wallpat)
        and     $F0                 ; pixels 0,1
        ld      c,a
        ld      b,0                 ; bytes 0,1 = wall, 0
        ld      hl,0
        ld      a,55
.l:     di
        push    de
        rept 14
        push    hl
        endr
        push    bc
        dec     a
        jr      z,.e
        ei
        jr      .l
.e:     ld      sp,(sp_save)
        ei
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
; frame_data: A = frame, B = x -> DE = shifted sprite (w,h,bytes...)
; ---------------------------------------------------------------------
frame_data:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,frametab
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

; ---------------------------------------------------------------------
; draw_frame: A = frame, B = x, C = y  (OR into the back buffer)
;   keeps IX, IY
; ---------------------------------------------------------------------
draw_frame:
        call    frame_data
        call    rowaddr
        ld      a,b
        rrca
        rrca
        and     $3F
        or      l
        ld      l,a
        ld      a,(de)
        inc     de
        ld      b,a
        ld      a,(de)
        inc     de
        ld      c,a
        ld      a,b
        cp      2
        jr      z,.w2
.row:   push    hl
        ld      a,b
.byte:  ex      af,af'
        ld      a,(de)
        or      (hl)
        ld      (hl),a
        inc     de
        inc     l
        ex      af,af'
        dec     a
        jr      nz,.byte
        pop     hl
        ld      a,l
        add     a,32
        ld      l,a
        jr      nc,.n1
        inc     h
.n1:    dec     c
        jr      nz,.row
        ret
.w2:    ld      a,(de)
        or      (hl)
        ld      (hl),a
        inc     de
        inc     l
        ld      a,(de)
        or      (hl)
        ld      (hl),a
        inc     de
        ld      a,l
        add     a,31
        ld      l,a
        jr      nc,.n2
        inc     h
.n2:    dec     c
        jr      nz,.w2
        ret

; ---------------------------------------------------------------------
; draw_spread: A = frame, B = x, C = y, D = spread k
;   the sprite's rows drawn k+1 lines apart around its centre, clipped to
;   clip_top..clip_bot (materialise / shatter effect).  keeps IX, IY
; ---------------------------------------------------------------------
draw_spread:
        ld      (sp_fr),a
        ld      a,d
        ld      (sp_kk),a
        ld      a,b
        ld      (sp_x),a
        ld      a,(sp_fr)
        push    bc
        call    frame_data
        pop     bc
        ld      a,(de)
        ld      (sp_w),a
        inc     de
        ld      a,(de)
        ld      (sp_h),a
        inc     de
        ; ystart = y + h/2 - (h/2)*(k+1)
        ld      a,(sp_h)
        srl     a
        ld      h,a                 ; h/2
        add     a,c
        ld      c,a                 ; y + h/2
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
        ld      c,a                 ; may wrap "negative" (>=192 treated as off)
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
        or      (hl)
        ld      (hl),a
        inc     de
        inc     l
        djnz    .bl
        jr      .nx
.skip:  ld      a,(sp_w)
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
; plot: B = x, C = y, A = colour 0..3 (OR).  keeps BC, IX, IY
; ---------------------------------------------------------------------
plot:
        add     a,a
        add     a,a
        ld      e,a
        ld      a,b
        and     3
        or      e
        ld      e,a
        ld      d,high pixtab
        call    rowaddr
        ld      a,b
        rrca
        rrca
        and     $3F
        or      l
        ld      l,a
        ld      a,(de)
        or      (hl)
        ld      (hl),a
        ret

; ---------------------------------------------------------------------
; hline: B = x0, D = x1 (incl), C = y, E = colour pattern ($55/$AA/$FF)
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
        and     e
        or      (hl)
        ld      (hl),a
        ret
.multi: ld      a,(hl_lm)
        and     e
        or      (hl)
        ld      (hl),a
        inc     l
        ld      a,(hl_l)
        ld      c,a
        ld      a,(hl_r)
        sub     c
        dec     a
        jr      z,.last
        ld      b,a
.mid:   ld      a,e
        or      (hl)
        ld      (hl),a
        inc     l
        djnz    .mid
.last:  ld      a,(hl_rm)
        and     e
        or      (hl)
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
        or      e
        ld      e,a
        push    de
        ld      d,high pixtab
        ld      a,(de)
        ld      (hl_lm),a
        pop     de
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
        ld      a,(hl_lm)
        ld      c,a
.l:     ld      a,c
        or      (hl)
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
.rw:    ld      a,(txtcol)
        and     (hl)
        ex      de,hl
        or      (hl)
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
; text2x: double-size text (8x10). HL = string, B = column, C = y, A = colour
; ---------------------------------------------------------------------
text2x:
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
        push    hl
        push    de
        sub     32
        and     63
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        ld      c,l
        ld      b,h
        add     hl,hl
        add     hl,hl
        add     hl,bc               ; *20
        ld      bc,font2x
        add     hl,bc
        ld      b,10
.rw:    ld      a,(txtcol)
        and     (hl)
        ex      de,hl
        or      (hl)
        ld      (hl),a
        inc     l
        ex      de,hl
        inc     hl
        ld      a,(txtcol)
        and     (hl)
        ex      de,hl
        or      (hl)
        ld      (hl),a
        ld      a,l
        add     a,31
        ld      l,a
        jr      nc,.nc
        inc     h
.nc:    ex      de,hl
        inc     hl
        djnz    .rw
        pop     de
        inc     e
        inc     e
        pop     hl
        jr      .ch

text2xc:
        push    af
        call    strlen
        ld      a,16
        sub     b
        ld      b,a
        pop     af
        jr      text2x

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
        ld      a,(demo)
        or      a
        ret     nz
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
        ld      a,2
        ld      (hud_dirty),a
        ; extra life each time the score reaches next_life (+25,000 each time)
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
.award: ld      hl,next_life+2      ; next_life += 025000
        ld      a,(hl)
        add     a,$00
        daa
        ld      (hl),a
        dec     hl
        ld      a,(hl)
        adc     a,$50
        daa
        ld      (hl),a
        dec     hl
        ld      a,(hl)
        adc     a,$02
        daa
        ld      (hl),a
        ld      a,(lives)
        cp      9
        jr      nc,.ms
        inc     a
        ld      (lives),a
.ms:    ld      a,24
        ld      (flash_t),a
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
;  movep = movement pad, firep = fire-direction pad (dual), fbtn = fire button
;  keys/keysnew: 0 M, 1 RETURN, 2 Q, 3 T, 4 '1', 5 '2', 6 '3', 7 SPACE
;  mnu/mnunew: 0 R 1 L 2 U 3 D 4 SELECT (SPACE, RETURN, any fire)
; ---------------------------------------------------------------------
read_input:
        ; ---- joysticks (0 when no interface)
        ld      a,(ctl_mode)
        cp      2
        jr      nz,.joy
        xor     a
        ld      (joy1),a
        ld      (joy2),a
        ld      (jfire),a
        jr      .keys
.joy:   in      a,($2C)
        call    joybits
        and     $0F
        ld      (joy1),a
        in      a,($29)
        or      $10
        call    joybits
        and     $0F
        ld      (joy2),a
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
.keys:  ; ---- WASD -> kmove
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
        ; ---- IJKL -> kfire
        ld      c,0
        ld      a,($68BF)           ; row 6: I b3
        bit     3,a
        jr      nz,.f1
        set     2,c
.f1:    ld      a,($687F)           ; row 7: J b5, K b3, L b1
        bit     5,a
        jr      nz,.f2
        set     1,c
.f2:    bit     3,a
        jr      nz,.f3
        set     3,c
.f3:    bit     1,a
        jr      nz,.f4
        set     0,c
.f4:    ld      a,c
        ld      (kfire),a
        ; ---- system keys
        ld      c,0
        ld      a,($68EF)           ; row 4: M b5, SPACE b4
        bit     5,a
        jr      nz,.s1
        set     0,c
.s1:    bit     4,a
        jr      nz,.s2
        set     7,c
.s2:    ld      a,($68BF)           ; RETURN b2
        bit     2,a
        jr      nz,.s3
        set     1,c
.s3:    ld      a,($68FE)           ; row 0: Q b4, T b0
        bit     4,a
        jr      nz,.s4
        set     2,c
.s4:    bit     0,a
        jr      nz,.s5
        set     3,c
.s5:    ld      a,($68F7)           ; row 3: 1 b4, 2 b1, 3 b3
        bit     4,a
        jr      nz,.s6
        set     4,c
.s6:    bit     1,a
        jr      nz,.s7
        set     5,c
.s7:    bit     3,a
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
