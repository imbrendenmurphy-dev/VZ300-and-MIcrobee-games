; ===================================================================
;  render.asm - map tile appearance and view drawing
; ===================================================================

; terrain at B=y,C=x with bounds (outside map = deep water) -> A (id, no flags)
tget:   ld a,b
        call cph
        jr nc,.out
        ld a,c
        call cpw
        jr nc,.out
        push hl
        call tile_addr
        ld a,(hl)
        and 1Fh
        pop hl
        ret
.out:   xor a
        ret
; object at B,C (outside = 0)
oget:   ld a,b
        call cph
        jr nc,.out
        ld a,c
        call cpw
        jr nc,.out
        push hl
        push de
        call tile_addr
        ld de,OBJOFF
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ret
.out:   xor a
        ret

iswater:                        ; A = terrain -> C flag set if water (0,1,2)
        cp 3
        ret

; neighbour flags for current tile (B,C): sets nb_n, nb_s, nb_w, nb_e = 1 if
; predicate true.  Predicate selected by (nbmode): 0 = land, 1 = road-like
neighbours:
        push bc
        dec b
        call .p
        ld (nb_n),a
        inc b
        inc b
        call .p
        ld (nb_s),a
        dec b
        dec c
        call .p
        ld (nb_w),a
        inc c
        inc c
        call .p
        ld (nb_e),a
        pop bc
        ret
.p:     ld a,(nbmode)
        or a
        jr nz,.road
        call tget
        cp 3
        ld a,0
        ret c
        inc a
        ret
.road:  call oget
        and 7Fh
        cp O_ROAD
        ld a,1
        ret z
        ; buildings also connect roads
        call oget
        and 7Fh
        cp O_TC_TL
        ld a,0
        ret c
        inc a
        ret

; ---- tile appearance -------------------------------------------------
; in: B = y, C = x (in range)
; out: tL, tR (G 0-255), cL, cR colours
tile_look:
        call tile_addr
        ld a,(hl)
        bit 7,a
        jp z,.fog
        and 1Fh
        ld (tterr),a
        ld de,OBJOFF
        add hl,de
        ld a,(hl)
        or a
        jp nz,.obj
        ld a,(tterr)
.terr:  cp T_DEEP
        jr nz,.nd
        call hash_xy
        and 1
        add a,a
        add a,G_DEEP
        ld (tL),a
        inc a
        ld (tR),a
        ld a,COL(BBLUE,BLUE)
        jr .same
.nd:    cp 3
        jr nc,.land
        ; shallow / river : shoreline chars from land neighbours
        push af
        xor a
        ld (nbmode),a
        call neighbours
        call .shoreidx          ; A = n*4+s*2
        ld e,a
        ld a,(nb_w)
        add a,e
        add a,G_SHORE
        ld (tL),a
        ld a,(nb_e)
        add a,e
        add a,G_SHORE+8
        ld (tR),a
        pop af
        cp T_RIVER
        ld a,COL(BCYAN,BBLUE)
        jr nz,.same
        ld a,COL(WHITE,BBLUE)
        jr .same
.land:  ; table lookup: first G, nvariants
        ld e,a
        ld d,0
        ld hl,terr_tab
        add hl,de
        add hl,de
        ld a,(hl)               ; first
        inc hl
        ld d,(hl)               ; n variants
        ld e,a
        call hash_xy
        and 3
        cp d
        jr c,.v
        sub d
        cp d
        jr c,.v
        xor a
.v:     add a,a
        add a,e
        ld (tL),a
        inc a
        ld (tR),a
        ; colour = terr_col[season*16 + terrain]
        ld a,(season)
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,(tterr)
        add a,e
        ld e,a
        ld d,0
        ld hl,terr_col
        add hl,de
        ld a,(hl)
.same:  ld (cL),a
        ld (cR),a
        ret
.shoreidx:
        ld a,(nb_n)
        add a,a
        ld e,a
        ld a,(nb_s)
        add a,e
        add a,a
        ret
.fog:   ld a,G_FOG_L
        ld (tL),a
        inc a
        ld (tR),a
        ld a,COL(DGREY,BLACK)
        jr .same
.obj:   ; A = object
        bit 7,a
        jr nz,.scaff
        cp O_ROAD
        jr z,.road
        ; building: G from bld_g table
        ld e,a
        ld d,0
        ld hl,bld_g
        add hl,de
        ld a,(hl)
.bg:    ld (tL),a
        ld e,a
        ld d,0
        ld hl,char_col
        add hl,de
        ld a,(hl)
        call season_bg
        ld (cL),a
        inc hl
        ld a,(hl)
        call season_bg
        ld (cR),a
        ld a,(tL)
        inc a
        ld (tR),a
        ret
.scaff: ld a,G_SCAFF_L
        jr .bg
.road:  ld a,(tterr)
        cp 3
        jr c,.bridge
        ld a,1
        ld (nbmode),a
        call neighbours
        call .shoreidx
        ld e,a
        ld a,(nb_w)
        add a,e
        add a,G_ROADS
        ld (tL),a
        ld a,(nb_e)
        add a,e
        add a,G_ROADS+8
        ld (tR),a
        ld a,COL(BYELLOW,GREEN)
        call season_bg
        jp .same
.bridge:
        ld a,1
        ld (nbmode),a
        call neighbours
        ld a,(nb_w)
        ld e,a
        ld a,(nb_e)
        or e
        ld a,G_BRIDGEH
        jr nz,.bh
        ; also horizontal if land west/east
        push bc
        dec c
        call tget
        pop bc
        cp 3
        ld a,G_BRIDGEH
        jr nc,.bh
        ld a,G_BRIDGEV
.bh:    ld (tL),a
        inc a
        ld (tR),a
        ld a,COL(BYELLOW,BBLUE)
        jp .same

; replace GREEN background with the season's ground colour
season_bg:
        push bc
        push de
        ld c,a
        and 0F0h
        cp GREEN*16
        ld a,c
        jr nz,.x
        and 0Fh
        ld c,a
        push hl
        ld a,(season)
        ld e,a
        ld d,0
        ld hl,season_grass_bg
        add hl,de
        ld a,(hl)
        pop hl
        cp WHITE
        jr nz,.nw
        ; snow ground: keep white/grey foregrounds visible
        ld a,c
        cp WHITE
        jr z,.dk
        cp GREY
        jr nz,.wh
.dk:    ld c,DGREY
.wh:    ld a,WHITE
.nw:    add a,a
        add a,a
        add a,a
        add a,a
        or c
.x:     pop de
        pop bc
        ret

; ---- draw one map tile to shadow at offset DE (B,C = map y,x) ----
draw_tile:
        push de
        push bc
        call tile_look
        pop bc
        pop de
        ld a,(tL)
        ld h,a
        call .gc
        ld a,(cL)
        call put_cell
        inc de
        ld a,(tR)
        ld h,a
        call .gc
        ld a,(cR)
        call put_cell
        dec de
        ret
.gc:    ; H = G (0-255) -> H = code, L = bank
        ld a,h
        rlca
        and 1
        ld l,a
        ld a,h
        or 80h
        ld h,a
        ret

; ---- draw whole view into shadow ----
draw_view:
        xor a
        ld (dv_x0),a
        ld (dv_y0),a
        ld a,VIEWW
        ld (dv_w),a
        ld a,VIEWH
        ld (dv_h),a
; draw rectangle of view tiles dv_x0,dv_y0,dv_w,dv_h (screen tile coords)
draw_rect:
        ld a,(mono)
        or a
        jr z,.b
        ld a,8
.b:     ld (dv_bank),a
        ld a,(dv_y0)
        ld (dv_r),a
        ld a,(dv_h)
        ld (dv_rn),a
.row:   ld a,(dv_r)
        add a,VIEWROW
        ld b,a
        ld a,(dv_x0)
        add a,a
        ld c,a
        call cell_off
        ld ix,SCHR
        add ix,de
        ld a,(viewy)
        ld b,a
        ld a,(dv_r)
        add a,b
        ld b,a
        ld a,(viewx)
        ld c,a
        ld a,(dv_x0)
        add a,c
        ld c,a
        ld a,(dv_w)
        ld (dv_c),a
.col:   push bc
        call tile_look
        call st2
        pop bc
        inc c
        inc ix
        inc ix
        ld hl,dv_c
        dec (hl)
        jr nz,.col
        ld hl,dv_r
        inc (hl)
        ld hl,dv_rn
        dec (hl)
        jr nz,.row
        ret

; ---- scroll the view by (A = dx tiles signed, sc_dy signed) using plane shifts
; caller has already updated viewx/viewy; old values in sc_ox/sc_oy
scroll_view:
        ld a,(viewx)
        ld hl,sc_ox
        sub (hl)
        ld (sc_dx),a
        ld a,(viewy)
        ld hl,sc_oy
        sub (hl)
        ld (sc_dy),a
        ; too big a jump -> full redraw
        ld a,(sc_dx)
        call abs_a
        cp VIEWW/2
        jp nc,draw_view
        ld a,(sc_dy)
        call abs_a
        cp VIEWH/2
        jp nc,draw_view
        ; ---- horizontal
        ld a,(sc_dx)
        or a
        jr z,.vert
        add a,a                 ; bytes per tile = 2
        ld (sc_nb),a
        ld b,VIEWROW
.hr:    push bc
        call row_off            ; DE = row start
        ld hl,SCHR
        call .hshift
        ld hl,SATR
        call .hshift
        ld hl,SCOL
        call .hshift
        pop bc
        inc b
        ld a,b
        cp VIEWROW+VIEWH
        jr nz,.hr
        ; draw exposed columns
        ld a,(sc_dx)
        bit 7,a
        jr nz,.hl
        ld e,a
        ld a,VIEWW
        sub e
        ld (dv_x0),a
        ld a,e
        jr .hd
.hl:    neg
        ld e,a
        xor a
        ld (dv_x0),a
        ld a,e
.hd:    ld (dv_w),a
        xor a
        ld (dv_y0),a
        ld a,VIEWH
        ld (dv_h),a
        call draw_rect
.vert:  ld a,(sc_dy)
        or a
        ret z
        bit 7,a
        jr nz,.up
        ; view moved down: rows move up by n
        ld (sc_n),a
        ld b,a
        ld a,VIEWH
        sub b
        ld l,a
        ld h,0
        call mul80
        ld (sc_len),hl
        ld hl,SCHR
        call .vup
        ld hl,SATR
        call .vup
        ld hl,SCOL
        call .vup
        ld a,(sc_n)
        ld b,a
        ld a,VIEWH
        sub b
        ld (dv_y0),a
        jr .vd
.up:    neg
        ld (sc_n),a
        ld b,a
        ld a,VIEWH
        sub b
        ld l,a
        ld h,0
        call mul80
        ld (sc_len),hl
        ld hl,SCHR
        call .vdn
        ld hl,SATR
        call .vdn
        ld hl,SCOL
        call .vdn
        xor a
        ld (dv_y0),a
.vd:    ld a,(sc_n)
        ld (dv_h),a
        xor a
        ld (dv_x0),a
        ld a,VIEWW
        ld (dv_w),a
        jp draw_rect
.hshift:                        ; HL = plane, DE = row offset ; shift by sc_nb (signed bytes)
        push de
        add hl,de               ; HL = row start in plane
        ld a,(sc_nb)
        bit 7,a
        jr nz,.right
        ; left: dst = row, src = row + n, length = 80 - n
        ld c,a
        ld b,0
        ld d,h
        ld e,l                  ; DE = dst
        add hl,bc               ; HL = src
        ld a,COLS
        sub c
        ld c,a                  ; BC = 80 - n
        ldir
        pop de
        ret
.right: neg
        ld c,a
        ld b,0                  ; BC = n
        ld de,COLS-1
        add hl,de               ; HL = row end
        ld d,h
        ld e,l                  ; DE = dst = row end
        or a
        sbc hl,bc               ; HL = src = row end - n
        ld a,COLS
        sub c
        ld c,a                  ; BC = 80 - n
        lddr
        pop de
        ret
.vup:   ; HL = plane: dst = row VIEWROW, src = row VIEWROW+n
        ld de,VIEWROW*COLS
        add hl,de
        push hl
        ld a,(sc_n)
        ld l,a
        ld h,0
        call mul80
        pop de
        add hl,de               ; src
        ld bc,(sc_len)
        ldir
        ret
.vdn:   ; dst end = last view row end; src end = dst end - n*80
        ld de,(VIEWROW+VIEWH)*COLS-1
        add hl,de
        push hl
        ld a,(sc_n)
        ld e,l
        ld d,h
        ld l,a
        ld h,0
        call mul80
        ex de,hl                ; HL = dst end, DE = n*80
        or a
        sbc hl,de               ; src end
        pop de                  ; dst end
        ld bc,(sc_len)
        lddr
        ret

; store tile (tL,tR,cL,cR) at IX in the three shadow planes
st2:    ld a,(tL)
        or 80h
        ld (ix+0),a
        ld a,(tR)
        or 80h
        ld (ix+1),a
        push ix
        pop hl
        ld bc,SCRSIZE
        add hl,bc
        ld a,(dv_bank)
        ld e,a
        ld a,(tL)
        rlca
        and 1
        add a,e
        ld (hl),a
        inc hl
        ld a,(tR)
        rlca
        and 1
        add a,e
        ld (hl),a
        add hl,bc
        ld a,e
        or a
        jr nz,.m
        ld a,(cR)
        ld (hl),a
        dec hl
        ld a,(cL)
        ld (hl),a
        ret
.m:     ld (hl),0Fh
        dec hl
        ld (hl),0Fh
        ret

; redraw a single map tile if visible, directly to hardware too. B,C map
refresh_tile:
        ld a,(viewx)
        ld e,a
        ld a,c
        sub e
        ret c
        cp VIEWW
        ret nc
        ld e,a                  ; sx
        ld a,(viewy)
        ld d,a
        ld a,b
        sub d
        ret c
        cp VIEWH
        ret nc
        ld d,a                  ; sy
        push bc
        push de
        ld a,d
        add a,VIEWROW
        ld b,a
        ld a,e
        add a,a
        ld c,a
        call cell_off
        pop hl                  ; H=sy L=sx (unused)
        pop bc
        push de
        call draw_tile
        pop de
        ; copy these two cells to hardware
        jp flush_cells2

; copy 2 cells at offset DE from shadow to hardware (all three planes)
flush_cells2:
        push de
        ld a,EXT_ON
        out (P_EXT),a
        ld hl,SCHR
        add hl,de
        push hl
        ld hl,SCRN
        add hl,de
        ex de,hl
        pop hl
        ldi
        ldi
        pop de
        push de
        ld a,EXT_ATTR
        out (P_EXT),a
        ld hl,SATR
        add hl,de
        push hl
        ld hl,SCRN
        add hl,de
        ex de,hl
        pop hl
        ldi
        ldi
        ld a,EXT_ON
        out (P_EXT),a
        pop de
        push de
        ld a,40h
        out (P_COL),a
        ld hl,SCOL
        add hl,de
        push hl
        ld hl,HIRAM
        add hl,de
        ex de,hl
        pop hl
        ldi
        ldi
        xor a
        out (P_COL),a
        pop de
        ret

; ---- tile cursor ---------------------------------------------------
; The two cells under the cursor are shown with two reserved PCG
; characters holding inverted copies of their patterns.  Unlike a colour
; swap this shows on a monochrome monitor too (the mono output carries
; only pixels).  Colour mode uses the colour set (bank 0), mono mode the
; mono set (bank 8); the cell colours are left as they are.
CUR_CODE equ 80h+(G_CURSOR&7Fh)
CUR_BANK equ G_CURSOR>>7

cursor_off_hw:
        ld a,(curshown)
        or a
        ret z
        xor a
        ld (curshown),a
        ld de,(curoff)
        jp flush_cells2         ; shadow -> hardware for both cells

cursor_on_hw:
        ld a,(cury)
        ld b,a
        ld a,(viewy)
        ld c,a
        ld a,b
        sub c
        add a,VIEWROW
        ld b,a
        ld a,(viewx)
        ld c,a
        ld a,(curx)
        sub c
        add a,a
        ld c,a
        call cell_off
        ld (curoff),de
        ld a,1
        ld (curshown),a
        ld c,0
        call .one
        inc de
        ld c,1
        call .one
        ld a,EXT_ON
        out (P_EXT),a
        ret
.one:   ; DE = cell offset, C = 0 / 1 (which cursor character)
        push de
        ld hl,SCHR
        add hl,de
        ld a,(hl)
        ld (cu_code),a
        ld hl,SATR
        add hl,de
        ld a,(hl)
        and 0Fh
        ld (cu_bank),a
        ; source pattern (11 rows) from PCG, inverted into cu_buf
        ld hl,cu_buf
        ld b,11
        ld a,(cu_code)
        bit 7,a
        jr nz,.pcg
.blank: ld (hl),0FFh            ; ROM character: show a solid block
        inc hl
        djnz .blank
        jr .put
.pcg:   ld a,(cu_bank)
        or EXT_ON
        out (P_EXT),a
        ld a,(cu_code)
        and 7Fh
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,HIRAM
        add hl,de               ; HL = pattern in the PCG window
        ld de,cu_buf
.cp:    ld a,(hl)
        cpl
        ld (de),a
        inc hl
        inc de
        djnz .cp
.put:   ; write it to the cursor character of the same set (colour / mono)
        ld a,(cu_bank)
        and 8
        add a,CUR_BANK
        ld (cu_set),a
        or EXT_ON
        out (P_EXT),a
        ld a,G_CURSOR&7Fh
        add a,c
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,HIRAM
        add hl,de
        ex de,hl
        ld hl,cu_buf
        push bc
        ld bc,11
        ldir
        pop bc
        ld a,EXT_ON
        out (P_EXT),a
        ; point the hardware cell at it
        pop de
        push de
        ld hl,SCRN
        add hl,de
        ld a,CUR_CODE
        add a,c
        ld (hl),a
        ld a,EXT_ATTR
        out (P_EXT),a
        ld a,(cu_set)
        ld (hl),a
        ld a,EXT_ON
        out (P_EXT),a
        pop de
        ret

; called every frame by the game loop: steady while moving, otherwise a
; slow blink (on 26 frames, off 6) so the cursor is easy to find
cursor_tick:
        ld a,(rep)
        or a
        jr nz,.on
        ld a,(frames)
        and 31
        cp 26
        jp nc,cursor_off_hw
.on:    ld a,(curshown)
        or a
        jp z,cursor_on_hw
        ld a,(frames)
        and 7                   ; refresh now and then: the cells may have changed
        ret nz
        jp cursor_on_hw
