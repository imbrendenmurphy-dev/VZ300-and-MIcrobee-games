; =====================================================================
;  RENDER: the fighters' band (cell rows 10..20).
;
;  A fighter frame is a rectangle of cells, each naming one of the
;  fighter's own glyphs, already in the PCG. Drawing a fighter is
;  therefore just pointing cells at glyphs: three bytes a cell, nothing
;  to erase, no pixels moved. Where the two fighters share a cell (a
;  fist on a chin), one glyph is composed for it in a small pool: the
;  under fighter's pattern, the upper fighter's mask cut out of it,
;  the upper fighter's pattern on top.
;
;  The band is composed in RAM (WANT), compared with what the hidden
;  page already shows (HAVE0 / HAVE1), and only the cells that differ
;  are written. The pages are then swapped in the vertical blanking,
;  so nothing is ever seen half drawn.
; =====================================================================

; ---- fighter record (IX / IY)
F_X         EQU 0           ; anchor column
F_FR        EQU 1           ; frame
F_BLK       EQU 2           ; RAM block
F_BANK      EQU 3           ; first PCG bank
F_ST        EQU 4           ; state
F_T         EQU 5           ; ticks left in this phase
F_PH        EQU 6           ; phase of the state
F_ATK       EQU 7           ; 0 punch, 1 kick
F_HP        EQU 8
F_MAX       EQU 9
F_DIR       EQU 10          ; +1 hero, -1 foe: forwards
F_STRIKE    EQU 11          ; this tick: 1 punch lands, 2 kick lands
F_GUARDT    EQU 12          ; ticks the guard has been up
F_COOL      EQU 13          ; ticks until the guard can go up again
F_TAB       EQU 14          ; dw timing table
F_BUF       EQU 16          ; a buffered attack (hero)
F_BUFT      EQU 17
F_L         EQU 18          ; this frame's left and right columns (set by the draw)
F_R         EQU 19
F_WHIFF     EQU 20          ; this attack missed: a longer recovery
F_ARMOUR    EQU 21          ; 1: blows don't stop this fighter's own attack
F_PL0       EQU 22          ; the columns its frame covered when page 0,
F_PR0       EQU 23          ; and page 1, were last drawn
F_PL1       EQU 24
F_PR1       EQU 25
F_SIZE      EQU 26

; (unused since the stages scroll: kept for pictures with a band)
band_init:
        ld hl,(picbase)
        ld de,BAND_OFF
        add hl,de
        push hl
        ld de,BASE
        ld bc,BAND_N
        ldir
        pop hl
        push hl
        ld de,PIC_BANKS
        add hl,de
        ld de,BASE+$200
        ld bc,BAND_N
        ldir
        pop hl
        ld de,PIC_COLS
        add hl,de
        ld de,BASE+$400
        ld bc,BAND_N
        ldir
        ld hl,BASE
        ld de,HAVE0
        ld bc,$600
        ldir
        ld hl,BASE
        ld de,HAVE1
        ld bc,$600
        ldir
        ret

; ---------------------------------------------------------------------
;  render: compose both fighters into the hidden page and ask for the
;  swap. IX = the under fighter, IY = the upper one.
;
;  Only the columns around each fighter are looked at: where it is now
;  and where it was when this page was last drawn. Two fighters far
;  apart are two narrow strips, not one wide one.
; ---------------------------------------------------------------------
render:
        ld a,(vispage)
        xor 1
        ld (hidpage),a
        call frame_extent
        push ix
        push iy
        pop ix
        call frame_extent
        call fr_range           ; the upper fighter's strip
        ld (rng_b),bc
        pop ix
        call fr_range           ; the under fighter's strip
        ld (rng_a),bc
        ; one strip or two? strip a = B..C, strip b = D..E
        xor a
        ld (rng_n),a
        ld de,(rng_b)           ; D = b0 (left), E = b1 (right)
        ld a,c
        cp b
        jr z,.aempty            ; strip a is empty
        ld a,e
        cp d
        jr z,.one_a             ; strip b is empty
        ; they overlap or touch when b0 <= a1 and a0 <= b1
        ld a,c
        cp d
        jr c,.two
        ld a,e
        cp b
        jr c,.two
        ld a,d                  ; merge
        cp b
        jr nc,.m0
        ld b,d
.m0:    ld a,e
        cp c
        jr c,.one_a
        ld c,e
.one_a: call .add
        jr .strips
.aempty:
        ld a,e
        cp d
        jr z,.strips            ; no fighter to draw (the scenery may be)
        ld b,d
        ld c,e
        jr .one_a
.two:   call .add
        ld bc,(rng_b)
        call .add
.strips:
        ; a page whose midground shows an older camera gets band rows
        ; 0..5 (screen rows 10..15) redrawn across the whole width; the
        ; floor rows below never move, so they stay strips
        xor a
        ld (r_mid),a
        call mid_stale
        jr z,.fresh
        ld a,1
        ld (r_mid),a
.fresh: ld a,(rng_n)
        ld hl,r_mid
        or (hl)
        jr z,.scen
        ; WANT = BASE and OWN = 0 over the strips, and the midground rows
        ld a,BAND_ROWS
        ld (r_rows),a
        ld a,(rng_n)
        or a
        jr z,.np
        ld hl,.prep
        call .each
.np:    ld a,(r_mid)
        or a
        jr z,.nm
        call .midset
        call .prep
.nm:    call vschk
        xor a
        ld (poolused),a
        ld (r_top),a
        call draw_fighter       ; the under fighter
        call vschk
        push ix
        push iy
        pop ix
        pop iy                  ; IX = upper, IY = under
        ld a,1
        ld (r_top),a
        call draw_fighter
        push ix
        push iy
        pop ix
        pop iy
        call vschk
        ; write what differs: the midground rows, then the strips below
        ld hl,0
        ld (r_skip),hl
        ld a,BAND_ROWS
        ld (r_rows),a
        ld a,(r_mid)
        or a
        jr z,.ns
        call mid_capture        ; rows 10..15 go whole, in the blanking
        ld hl,6*COLS
        ld (r_skip),hl
        ld a,BAND_ROWS-6
        ld (r_rows),a
.ns:    ld a,(rng_n)
        or a
        jr z,.scen
        ld hl,.diffs
        call .each
.scen:  call scenery_page
        ld a,1
        ld (flip_ask),a
        ret

; B = first column, C = one past the last: add a strip
.add:   ld a,(rng_n)
        add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,rng
        add hl,de
        ld (hl),b
        inc hl
        ld a,c
        sub b
        ld (hl),a
        pop hl
        ld a,(rng_n)
        inc a
        ld (rng_n),a
        ret

; call (HL) once per strip with r_c0, r_n set
.each:  ld (r_fn),hl
        ld a,(rng_n)
        ld b,a
        ld hl,rng
.e:     ld a,(hl)
        ld (r_c0),a
        inc hl
        ld a,(hl)
        ld (r_n),a
        inc hl
        push bc
        push hl
        ld hl,.ret
        push hl
        ld hl,(r_fn)
        jp (hl)
.ret:   pop hl
        pop bc
        djnz .e
        ret

; the midground pass: band rows 0..5, all 40 columns
.midset:
        xor a
        ld (r_c0),a
        ld a,COLS
        ld (r_n),a
        ld a,6
        ld (r_rows),a
        ret

.prep:  ld hl,BASE
        ld de,WANT
        call .span
        ld hl,BASE+$200
        ld de,WANT+$200
        call .span
        ld hl,BASE+$400
        ld de,WANT+$400
        call .span
        jp .ownclr

; write what differs in this strip to the hidden page
.diffs: ld a,(hidpage)
        or a
        ld hl,HAVE0
        ld de,VIDEO+BAND_OFF
        jr z,.p0
        ld hl,HAVE1
        ld de,VIDEO+PAGE1+BAND_OFF
.p0:    ld bc,(r_skip)
        add hl,bc
        ld (r_have),hl
        ex de,hl
        add hl,bc
        ld (r_vid),hl
        call win_screen
        ld hl,WANT
        call .dplane
        call win_attr
        ld hl,(r_have)
        inc h
        inc h
        ld (r_have),hl
        ld hl,WANT+$200
        call .dplane
        call win_col
        ld hl,(r_have)
        inc h
        inc h
        ld (r_have),hl
        ld hl,(r_vid)
        set 3,h
        ld (r_vid),hl
        ld hl,WANT+$400
        call .dplane
        jp win_screen
.dplane:
        ld bc,(r_skip)
        add hl,bc
        jp diff

; copy columns r_c0.. of every band row from HL to DE
.span:  ld a,(r_c0)
        ld c,a
        ld b,0
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        ld a,(r_rows)
.sr:    push af
        push hl
        push de
        ld a,(r_n)
        cp COLS
        jr nz,.sl
        ld a,COLS/8
        call copy8
        jr .sd
.sl:    ld c,a
        ld b,0
        ldir
.sd:    pop de
        pop hl
        ld bc,COLS
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        pop af
        dec a
        jr nz,.sr
        ret
.ownclr:
        ld hl,OWN
        ld a,(r_c0)
        ld c,a
        ld b,0
        add hl,bc
        ld a,(r_rows)
.or:    push af
        push hl
        ld a,(r_n)
        ld b,a
        xor a
.oc:    ld (hl),a
        inc hl
        djnz .oc
        pop hl
        ld bc,COLS
        add hl,bc
        pop af
        dec a
        jr nz,.or
        ret

; IX = fighter -> B, C = the strip it needs on the hidden page (its
; frame now and its frame when this page was last drawn); remembers
; the frame now for next time
fr_range:
        ld a,(hidpage)
        or a
        jr nz,.p1
        ld b,(ix+F_PL0)
        ld c,(ix+F_PR0)
        ld a,(ix+F_L)
        ld (ix+F_PL0),a
        ld a,(ix+F_R)
        ld (ix+F_PR0),a
        jr .m
.p1:    ld b,(ix+F_PL1)
        ld c,(ix+F_PR1)
        ld a,(ix+F_L)
        ld (ix+F_PL1),a
        ld a,(ix+F_R)
        ld (ix+F_PR1),a
.m:     ld a,c
        cp b
        jr nz,.ne
        ; nothing there before: just the frame now
        ld b,(ix+F_L)
        ld c,(ix+F_R)
        ret
.ne:    ld a,(ix+F_L)
        cp b
        jr nc,.1
        ld b,a
.1:     ld a,(ix+F_R)
        cp c
        ret c
        ld c,a
        ret

; HL = a WANT plane; (r_have), (r_vid) the matching HAVE plane and video
; address of the band. Writes the cells that differ, columns r_c0..
diff:
        ld (r_wbase),hl
        ld a,(r_c0)
        ld c,a
        ld b,0
        add hl,bc
        ex de,hl
        ld hl,(r_have)
        add hl,bc
        ex de,hl                ; HL = want, DE = have
        ; video = want + (vid - wantbase)
        push hl
        push de
        ld hl,(r_vid)
        ld de,(r_wbase)
        or a
        sbc hl,de
        ld (r_vofs),hl
        pop de
        pop hl
        ld a,(r_rows)
        ld c,a
.row:   ld a,(r_n)
        ld b,a
.cell:  ld a,(de)
        cp (hl)
        jr nz,.chg
.nx:    inc hl
        inc de
        djnz .cell
        ; on to the next row
        ld a,(r_n)
        neg
        add a,COLS
        push bc
        ld c,a
        ld b,0
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        call vschk
        pop bc
        dec c
        jr nz,.row
        ret
.chg:   ld a,(hl)
        ld (de),a
        push hl
        push bc
        ld bc,(r_vofs)
        add hl,bc
        ld (hl),a
        pop bc
        pop hl
        jr .nx

; ---------------------------------------------------------------------
;  IX = fighter: F_L, F_R = the columns its frame covers (clipped)
; ---------------------------------------------------------------------
frame_extent:
        ld a,(ix+F_BLK)
        call map_blk
        call frame_ptr
        ld b,(hl)               ; w
        inc hl
        inc hl
        ld a,(ix+F_X)
        sub (hl)                ; left column (may be negative)
        ld c,a
        jp p,.lp
        xor a
.lp:    cp COLS
        jr c,.lok
        ld a,COLS
.lok:   ld (ix+F_L),a
        ld a,c
        add a,b
        jp p,.rp
        xor a
.rp:    cp COLS+1
        jr c,.rok
        ld a,COLS
.rok:   ld (ix+F_R),a
        ret

; IX = fighter (its block mapped) -> HL = its frame record
frame_ptr:
        ld l,(ix+F_FR)
        ld h,0
        add hl,hl
        ld de,FB_FRAMES
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; ---------------------------------------------------------------------
;  draw IX's frame into WANT. (r_top) = 1: it goes over the other
;  fighter (IY), composing the cells they share.
; ---------------------------------------------------------------------
draw_fighter:
        ld a,(ix+F_BLK)
        call map_blk
        call frame_ptr
        ld a,(hl)
        ld (d_w),a
        inc hl
        ld a,(hl)
        ld (d_h),a
        inc hl
        ld a,(ix+F_X)
        sub (hl)
        ld (d_x0),a             ; left column, signed
        inc hl
        ld a,(hl)               ; top row in the band
        inc hl
        push hl
        ; DE = WANT + row * 40
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        ld de,WANT
        add hl,de
        ld (d_row),hl
        pop hl                  ; HL = cells
.row:   ld a,(d_x0)
        ld c,a                  ; C = column
        ld a,(d_w)
        ld b,a
.cell:  ld a,(hl)
        or a
        jr z,.skip
        ld a,c
        cp COLS
        jr nc,.skip             ; off the screen (or negative)
        push hl
        push bc
        ex de,hl                ; DE = cell record
        ld hl,(d_row)
        ld b,0
        add hl,bc               ; HL = WANT cell
        ld a,(r_top)
        or a
        jr z,.plain
        push hl
        ld bc,OWN-WANT
        add hl,bc
        ld a,(hl)
        pop hl
        or a
        jr nz,.share
.plain: ld a,(de)
        ld (hl),a
        inc de
        inc h
        inc h
        ld a,(de)
        ld (hl),a
        inc de
        inc h
        inc h
        call fpaper
        ld a,(de)
        or b
        ld (hl),a
        ld a,(r_top)
        or a
        jr nz,.done
        ld bc,OWN-WANT-$400
        add hl,bc
        ld (hl),1
.done:  pop bc
        pop hl
.skip:  inc hl
        inc hl
        inc hl
        inc c
        djnz .cell
        push hl
        ld hl,(d_row)
        ld bc,COLS
        add hl,bc
        ld (d_row),hl
        pop hl
        ld a,(d_h)
        dec a
        ld (d_h),a
        jr nz,.row
        ret

; a shared cell: HL = WANT cell (holding the under fighter's glyph),
; DE = the upper fighter's cell record
.share: ld a,(poolused)
        cp POOLN
        jr nc,.plain            ; pool full: the upper fighter simply wins
        ld (c_want),hl
        ; the upper glyph's 20 bytes -> c_top
        ld a,(de)
        and $7F
        ld c,a
        inc de
        ld a,(de)
        sub (ix+F_BANK)
        inc de
        ld a,(de)
        ld (c_ink),a
        dec de
        ld a,(de)
        sub (ix+F_BANK)
        call .gaddr
        ld de,c_top
        ld bc,20
        ldir
        ; the under glyph's pattern -> c_bot
        ld hl,(c_want)
        ld a,(hl)
        and $7F
        ld c,a
        inc h
        inc h
        ld a,(hl)
        sub (iy+F_BANK)
        push af
        ld a,(iy+F_BLK)
        call map_blk
        pop af
        call .gaddr
        ld de,c_bot
        ld bc,10
        ldir
        ld a,(ix+F_BLK)
        call map_blk
        ; the pool glyph for this cell
        ld a,(poolused)
        ld b,a
        inc a
        ld (poolused),a
        ld a,(hidpage)
        or a
        ld a,b
        jr z,.pg
        add a,POOLN
.pg:    add a,POOL0
        ld (c_code),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PCGWIN
        add hl,de
        ex de,hl                ; DE = the glyph in the PCG window
        xor a
        out (P_COLCTL),a
        ld a,LV_SCREEN+BK_FONT
        out (P_LV),a
        ld hl,c_top
        ld b,10
.mix:   push bc
        push hl
        ld bc,10
        add hl,bc
        ld a,(hl)               ; mask
        cpl
        ld bc,10
        add hl,bc
        and (hl)                ; under pattern with the mask cut out
        pop hl
        or (hl)                 ; upper pattern
        ld (de),a
        inc hl
        inc de
        pop bc
        djnz .mix
        ; point the cell at it
        ld hl,(c_want)
        ld a,(c_code)
        or $80
        ld (hl),a
        inc h
        inc h
        ld (hl),BK_FONT
        inc h
        inc h
        call fpaper
        ld a,(c_ink)
        or b
        ld (hl),a
        jp .done

; A = bank number within the fighter (0..6), C = glyph in the bank
; -> HL = its 20-byte record in the mapped block
.gaddr: rrca                    ; A * 128 + C, times 20
        ld h,a
        and $80
        or c
        ld l,a
        ld a,h
        and $7F
        ld h,a                  ; HL = glyph number (bank*128 + c)
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc               ; x 20
        ld bc,FB_GLYPHS
        add hl,bc
        ret

; HL = a WANT colour cell -> B = the paper a fighter stands on there:
; the scenery's paper, dropped to its dark shade, so a silhouette always
; stands out from the patch of background around it
fpaper: ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and $0F
        push hl
        ld hl,darkpaper
        add a,l
        ld l,a
        ld b,(hl)
        pop hl
        ret
        ALIGN 16
;               BLK RED GRN BRN BLU MAG CYN GRY DGR BRD BGR YEL BBL BMG BCY WHT
darkpaper:  db $00,$10,$20,$30,$40,$50,$60,$80,$80,$10,$20,$30,$40,$50,$60,$80
