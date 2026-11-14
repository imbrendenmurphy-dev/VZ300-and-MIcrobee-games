; =====================================================================
;  FX: the arena's thin rainbow border, the title's spinning balls, the
;  glowing dithered borders of the attract screens, and the expanding
;  rectangles between waves.
; =====================================================================
; arena_border: the border into the background map and onto both pages
arena_border:
        ld hl,BGMAP
        ld de,BGMAP+1
        ld bc,1023
        ld (hl),$80
        ldir
        ld ix,arenaperim
        ld iy,arenachars
        ld b,124
.l:     push bc
        ld l,(ix+0)
        ld h,(ix+1)
        ld b,(iy+0)
        push hl
        ld de,BGMAP
        add hl,de
        ld (hl),b
        pop hl
        ld c,WHITE
        call put_both
        inc ix
        inc ix
        inc iy
        pop bc
        djnz .l
        ret

; border_cols: a rainbow running round the arena border (hidden page).
; Half the border each frame, so each page's whole border every 4 frames.
border_cols:
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,(pgbase+1)
        add a,8
        ld c,a
        ld a,(gtick)
        srl a
        cpl
        ld l,a
        ld h,rainbow/256
        ld (sp_save),sp
        ld sp,arenaperim
        ld a,(gtick)
        and 2
        jr z,.h
        ld sp,arenaperim+124
        ld a,l
        add a,62
        ld l,a
.h:     ld b,62
.l:     pop de
        ld a,d
        add a,c
        ld d,a
        ld a,(hl)
        ld (de),a
        inc l
        djnz .l
        ld sp,(sp_save)
        xor a
        out (P_COLCTL),a
        ret

; title_balls: a train of spinning, colour-cycling balls round the edge
; of the title (page 0). (fxt) counts the frames.
title_balls:
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,(fxt)
        srl a
        ld c,a                  ; the train moves a cell every 2 frames
        ld (sp_save),sp
        ld sp,edgeperim
        ld b,126
.c:     pop hl
        ld a,h
        add a,$F0
        ld h,a
        ld a,b
        add a,c
        rra
        ld a,$80
        jr c,.blank
        ld a,b                  ; spin: one of 4 ball glyphs
        rra
        add a,c
        and 3
        add a,G_BALL1
.blank: ld (hl),a
        djnz .c
        ld sp,(sp_save)
        ld a,COL_ON
        out (P_COLCTL),a
        ld a,(fxt)
        ld e,a
        ld d,rainbow/256
        ld (sp_save),sp
        ld sp,edgeperim
        ld b,126
.k:     pop hl
        ld a,h
        add a,$F8
        ld h,a
        ld a,(de)
        ld (hl),a
        inc e
        djnz .k
        ld sp,(sp_save)
        xor a
        out (P_COLCTL),a
        ret

; glow_border: a dithered border round the screen edge (page 0) in
; glowing ink-and-paper colour pairs that chase round it
glow_border:
        ld a,(monomode)
        or a
        jr nz,march_border
        ld a,(fxt)
        and 3
        jr nz,.cols
        ld a,LV_SCREEN          ; every 4 frames the dither flips
        out (P_LV),a
        ld a,(fxt)
        rrca
        rrca
        and 1
        ld c,a
        ld (sp_save),sp
        ld sp,edgeperim
        ld b,126
.c:     pop hl
        ld a,h
        add a,$F0
        ld h,a
        ld a,b
        add a,c
        and 1
        add a,G_DITH1
        ld (hl),a
        djnz .c
        ld sp,(sp_save)
.cols:  ld a,COL_ON
        out (P_COLCTL),a
        ld a,(fxt)
        ld e,a
        ld d,glowtab/256
        ld (sp_save),sp
        ld sp,edgeperim
        ld b,126
.k:     pop hl
        ld a,h
        add a,$F8
        ld h,a
        ld a,(de)
        ld (hl),a
        dec e
        djnz .k
        ld sp,(sp_save)
        xor a
        out (P_COLCTL),a
        ret

; march_border: the monochrome glow: dither with solid blocks marching
; round it (no colours)
march_border:
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,(fxt)
        srl a
        ld c,a
        ld a,(fxt)
        rrca
        rrca
        and 1
        ld e,a
        ld (sp_save),sp
        ld sp,edgeperim
        ld b,126
.c:     pop hl
        ld a,h
        add a,$F0
        ld h,a
        ld a,b
        add a,c
        and 3
        ld a,G_BLOCK
        jr z,.s
        ld a,b
        add a,e
        and 1
        add a,G_DITH1
.s:     ld (hl),a
        djnz .c
        ld sp,(sp_save)
        ret

; logo_shine: a glint sweeps across the title logo (page 0), turning its
; cells to reverse video in a band that leans with the letters
logo_shine:
        ld a,(fxt)
        and 127
        cp 48
        ret nc
        ld (t_k2),a
        or a
        jr z,.in
        dec a                   ; the column it has left goes back
        ld b,0
        call shine_col
.in:    ld a,(t_k2)             ; the band: 3 columns in reverse video
        ld b,1
        call shine_col
        ld a,(t_k2)
        inc a
        ld b,1
        call shine_col
        ld a,(t_k2)
        add a,2
        ld b,1
; shine_col: glint column A (0-47) normal (B = 0) or reversed (B = 1)
shine_col:
        cp 48
        ret nc
        add a,a
        ld l,a
        ld h,0
        ld de,logostart
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; DE = first entry, HL = past the last
        or a
        sbc hl,de
        ret z
        ld a,l                  ; bytes / 7 = entries (< 256 x 7)
        ld c,0
.dv:    sub 7
        jr c,.n
        inc c
        jr .dv
.n:     ex de,hl
.l:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        inc hl                  ; (glint column)
        ld a,b
        or a
        jr z,.nm
        inc hl
        inc hl
.nm:    ld a,LV_SCREEN
        out (P_LV),a
        ld a,(hl)
        ld (de),a
        inc hl
        ld a,LV_ATTR
        out (P_LV),a
        ld a,(hl)
        ld (de),a
        ld a,LV_SCREEN
        out (P_LV),a
        inc hl
        ld a,b
        or a
        jr nz,.nx
        inc hl
        inc hl
.nx:    pop bc
        dec c
        jr nz,.l
        ret

; rainbow_rows: colour rows D..E-1 of page 0 in moving diagonal rainbow
; bands (the title logo)
rainbow_rows:
        ld a,COL_ON
        out (P_COLCTL),a
.r:     ld a,d
        cp e
        jr nc,.x
        push de
        call row_off
        ld bc,$F800
        add hl,bc
        pop de
        push de
        ld a,(fxt)
        sub d
        sub d
        ld e,a
        ld d,rainbow/256
        ld b,40
.c:     ld a,(de)
        ld (hl),a
        inc hl
        bit 0,b                 ; a colour every 2 cells: wide bands
        jr z,$+3
        inc e
        djnz .c
        pop de
        inc d
        jr .r
.x:     xor a
        out (P_COLCTL),a
        ret

; rect: an outline of G_DITH1 cells, half-size D (columns) x E (rows) round
; the middle of the arena, colour C; B = char (G_DITH1 or 80h to clear).
; Written to both pages.
rect:   ld a,20
        sub d
        ld (t_c0),a
        ld a,19
        add a,d
        ld (t_c1),a
        ld a,13
        sub e
        ld (t_r0),a
        ld a,12
        add a,e
        ld (t_r1),a
        ; top and bottom rows
        ld a,(t_c0)
        ld (t_k),a
.h:     ld a,(t_r0)
        call .cell
        ld a,(t_r1)
        call .cell
        ld hl,t_k
        inc (hl)
        ld a,(t_c1)
        cp (hl)
        jr nc,.h
        ld a,(t_r0)
        inc a
        ld (t_k2),a
.v:     ld a,(t_k2)
        ld hl,t_r1
        cp (hl)
        ret nc
        ld a,(t_c0)
        ld (t_k),a
        ld a,(t_k2)
        call .cell
        ld a,(t_c1)
        ld (t_k),a
        ld a,(t_k2)
        call .cell
        ld hl,t_k2
        inc (hl)
        jr .v
; cell at row A, column (t_k), inside the arena only
.cell:  cp 2
        ret c
        cp 24
        ret nc
        push bc
        call row_off
        ld a,(t_k)
        cp 1
        jr c,.no
        cp 39
        jr nc,.no
        ld e,a
        ld d,0
        add hl,de
        call put_both
.no:    pop bc
        ret
