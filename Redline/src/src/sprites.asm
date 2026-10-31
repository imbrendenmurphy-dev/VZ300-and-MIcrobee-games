; =====================================================================
;  sprites.asm - scaled scenery, traffic, player car, gantries, portals
;  Each visible thing becomes a draw-list entry; the list is sorted far
;  to near and drawn after the road.  Every entry carries the clip row of
;  the road in front of it, so objects behind a crest are cut off.
;
;  Sprite frame format:  db wb (bytes per row, incl. the shift byte),
;  db h, then phase 0 rows (wb*h), phase 1 rows (shifted 2 px).
;  Scenery uses colour 2 as transparent (mask table); cars and the
;  player car carry explicit mask bytes (interleaved mask,data).
; =====================================================================
T_LEVEL   equ $6000       ; bank 3: road half width -> scale level 0..11 (255 none)
MASK2     equ $5E00       ; bank 3: pixel value 2 -> keep background mask
DATA2     equ $5F00       ; bank 3: byte with colour-2 pixels cleared
DL_MAX    equ 20
DL_SIZE   equ 12          ; depth(2), kind, xl, xh, ybot, w, clip, arg, arg2, next(2)
K_SCEN    equ 0           ; scenery object: arg = type
K_CAR     equ 1           ; traffic car:    arg = car index
K_GANTRY  equ 2           ; overhead gantry: arg = banner
K_PORTAL  equ 3           ; tunnel entrance
K_SMOKE   equ 4

; ---------------------------------------------------------------- per-segment projections
; draw_road records, for each segment offset k (0..31) ahead of the camera:
;   PRJ_Y, PRJ_XL, PRJ_XH, PRJ_W, PRJ_C(lip)
record_k:
        ld a,(kidx)
        cp 32
        ret nc
        ld e,a
        ld d,0
        ld hl,prj_y
        add hl,de
        ld a,(cur_y)
        ld (hl),a
        ld bc,33
        add hl,bc
        ld a,(cur_w)
        ld (hl),a
        add hl,bc
        ld a,(clip)
        ld (hl),a
        add hl,bc
        ld a,(cur_x)
        ld (hl),a
        add hl,bc
        ld a,(cur_x+1)
        ld (hl),a
        ; skipped offsets before this one: the midpoint (gap of 1) or a copy
        ld a,e
        or a
        ret z
        dec a
        ld e,a
        ld hl,prj_y
        add hl,de
        ld a,(hl)
        cp 255
        ret nz
        ; gap: walk back over the empty entries, giving them our values
.g:     ld a,(cur_y)
        ld (hl),a
        push hl
        add hl,bc
        ld a,(cur_w)
        ld (hl),a
        add hl,bc
        ld a,(clip)
        ld (hl),a
        add hl,bc
        ld a,(cur_x)
        ld (hl),a
        add hl,bc
        ld a,(cur_x+1)
        ld (hl),a
        pop hl
        dec hl
        ld a,(hl)
        cp 255
        jr z,.g
        ret

prj_reset:
        ld hl,prj_y
        ld b,33
        ld a,255
.l:     ld (hl),a
        inc hl
        djnz .l
        xor a
        ld (kidx),a
        ret

; ---------------------------------------------------------------- build the draw list
build_dl:
        xor a
        ld (dl_n),a
        ld hl,dl_buf
        ld (dl_ptr),hl
        call dl_objects
        call dl_cars
        call dl_gantries
        ret

; add entry: A = kind, B = k (boundary index), C = frac (0..255),
; E = x offset (units/3, signed), args in (dla_arg),(dla_arg2)
; The position is interpolated between offsets k and k+1.
dl_add:
        ld (dla_kind),a
        ld a,(dl_n)
        cp DL_MAX
        ret nc
        ld a,b
        cp 31
        ret nc
        ld (dla_k),a
        ld a,c
        ld (dla_f),a
        ld a,e
        ld (dla_xo),a
        ; y, w, clip, x at k
        ld l,b
        ld h,0
        ld de,prj_y
        add hl,de
        ld a,(hl)
        cp 65
        ret nc                  ; not projected / below the screen
        ld (dla_y),a
        ld de,prj_w-prj_y
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld (dla_w),a
        ld de,prj_c-prj_w
        add hl,de
        ld a,(hl)
        ld (dla_c),a
        ld de,prj_xl-prj_c
        add hl,de
        ld e,(hl)
        ld bc,prj_xh-prj_xl
        add hl,bc
        ld d,(hl)
        ld (dla_x),de
        ld a,(dla_f)
        or a
        call nz,dl_lerp         ; cars between boundaries
        ; x += xo * w / 64   (log multiply)
        ld a,(dla_xo)
        or a
        jr z,.x0
        ld b,a
        bit 7,a
        jr z,.xp
        neg
.xp:    ld l,a
        ld h,high T_LOGL
        ld e,(hl)
        inc h
        ld d,(hl)               ; L(|xo|)
        ld a,(dla_w)
        ld l,a
        dec h
        ld c,(hl)
        inc h
        ld a,(hl)
        ld h,a
        ld l,c                  ; L(w)
        add hl,de
        ld de,64-384
        add hl,de
        bit 7,h
        jr nz,.x0
        ld de,T_EXPL
        add hl,de
        ld e,(hl)
        ld a,h
        add a,4
        ld h,a
        ld d,(hl)               ; DE = |xo| * w / 64
        bit 7,b
        jr z,.xa
        xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
.xa:    ld hl,(dla_x)
        add hl,de
        ld (dla_x),hl
.x0:    ; store entry
        ld hl,(dl_ptr)
        ld a,(dla_k)
        ld (hl),a
        inc hl
        ld a,(dla_f)
        ld (hl),a
        inc hl
        ld a,(dla_kind)
        ld (hl),a
        inc hl
        ld de,(dla_x)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(dla_y)
        ld (hl),a
        inc hl
        ld a,(dla_w)
        ld (hl),a
        inc hl
        ld a,(dla_c)
        ld (hl),a
        inc hl
        ld a,(dla_arg)
        ld (hl),a
        inc hl
        ld a,(dla_arg2)
        ld (hl),a
        inc hl
        inc hl
        inc hl
        ld (dl_ptr),hl
        ld hl,dl_n
        inc (hl)
        ret

; move y, w, x towards offset k+1 by the fraction (cars)
dl_lerp:
        ld a,(dla_k)
        ld l,a
        ld h,0
        ld de,prj_y+1
        add hl,de
        ld a,(hl)
        cp 255
        ret z
        ld c,a
        ld a,(dla_y)
        ld b,a
        ld a,c
        sub b
        call lerp_f
        add a,b
        ld (dla_y),a
        ld de,prj_w-prj_y
        add hl,de
        ld a,(dla_w)
        ld b,a
        ld a,(hl)
        sub b
        call lerp_f
        add a,b
        ld (dla_w),a
        ld de,prj_c-prj_w
        add hl,de
        ld a,(dla_c)
        cp (hl)
        jr c,.c
        ld a,(hl)
        ld (dla_c),a
.c:     ld de,prj_xl-prj_c
        add hl,de
        ld e,(hl)
        ld bc,prj_xh-prj_xl
        add hl,bc
        ld d,(hl)               ; x at k+1
        ld hl,(dla_x)
        ex de,hl
        or a
        sbc hl,de               ; delta (16-bit)
        ld a,(dla_f)
        push de
        call mul_s8
        pop de
        add hl,de
        ld (dla_x),hl
        ret
dla_x   dw 0
dla_kind db 0
dla_k   dw 0
dla_f   db 0
dla_xo  db 0
dla_y   db 0
dla_w   db 0
dla_c   db 0
dla_arg db 0
dla_arg2 db 0

; A = signed delta, (dla_f) = fraction -> A = delta * f / 256 (signed)
lerp_f: push bc                 ; ~ delta * f / 256 in eighths
        ld c,a
        ld a,(dla_f)
        rlca
        rlca
        rlca
        and 7
        ld b,a
        xor a
        inc b
        jr .s
.l:     add a,c
.s:     djnz .l
        sra a
        sra a
        sra a
        pop bc
        ret

; signed E * unsigned A -> HL (signed 16)
smul8:  ld d,0
        bit 7,e
        jr z,.p
        dec d
.p:     ld hl,0
        ld b,8
.l:     add hl,hl
        rla
        jr nc,.n
        add hl,de
.n:     djnz .l
        ret

; ---------------------------------------------------------------- scenery objects in view
dl_objects:
        ; walk the object list from obj_ptr (first object at/after pos_s)
        ld hl,(obj_ptr)
.skip:  ; drop objects now behind the camera
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec hl
        ld a,d
        cp $FF
        ret z                   ; end marker
        push hl
        ld hl,(pos_s)
        ex de,hl
        or a
        sbc hl,de               ; obj seg - pos_s
        pop hl
        jr nc,.ahead
        ld de,4
        add hl,de
        ld (obj_ptr),hl
        jr .skip
.ahead: ; HL = list pointer at the first object ahead
.lp:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        cp $FF
        ret z
        push hl
        ld hl,(pos_s)
        ex de,hl
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.done
        ld a,(det_k)
        ld b,a
        ld a,l
        cp b
        jr nc,.done
        ld b,a                  ; k
        pop hl
        ld a,(hl)               ; type
        inc hl
        ld e,(hl)               ; x offset
        inc hl
        push hl
        ld (dla_arg),a
        ld c,0
        ld a,K_SCEN
        call dl_add
        pop hl
        jr .lp
.done:  pop hl
        ret

; ---------------------------------------------------------------- gantries
dl_gantries:
        ld b,0
        ld a,(gan_seg+1)
        cp $FF
        ret z
        ld hl,(gan_seg)
        ld de,(pos_s)
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        ret nz
        ld a,l
        cp 30
        ret nc
        ld b,a
        ld c,0
        ld e,0
        ld a,(gan_kind)
        ld (dla_arg),a
        ld a,K_GANTRY
        jp dl_add

; ---------------------------------------------------------------- traffic cars
dl_cars:
        ld ix,cars
        ld b,NCARS
.l:     push bc
        ld a,(ix+C_ON)
        or a
        jr z,.n
        ld a,(pos_s)
        ld e,a
        ld a,(ix+C_SL)
        sub e
        ld e,a
        ld a,(pos_s+1)
        ld d,a
        ld a,(ix+C_SH)
        sbc a,d
        jr nz,.n                ; behind, or far ahead
        ld a,(det_k)
        add a,4
        ld b,a
        ld a,e
        cp b
        jr nc,.n
        ld b,a
        ld c,(ix+C_F)
        ld e,(ix+C_X)
        ld a,(ix+C_TYPE)
        ld (dla_arg2),a
        ld a,(ix+C_FRM)
        ld (dla_arg),a
        ld a,K_CAR
        push ix
        call dl_add
        pop ix
.n:     ld de,C_LEN
        add ix,de
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------- draw the list
draw_dl:
        ld a,(dl_n)
        or a
        ret z
        ; bucket by segment offset k (far first), entry+10 = next link
        ld hl,dl_bkt
        xor a
        REPT 64
        ld (hl),a
        inc l
        ENDR
        ld hl,dl_buf
        ld a,(dl_n)
        ld b,a
.ins:   push bc
        ld a,(hl)               ; k
        and 31
        add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,dl_bkt
        add hl,de               ; bucket slot
        ld c,(hl)
        inc hl
        ld b,(hl)               ; old head
        pop de                  ; entry
        ld (hl),d
        dec hl
        ld (hl),e
        ld hl,10
        add hl,de
        ld (hl),c
        inc hl
        ld (hl),b
        ld hl,DL_SIZE
        add hl,de
        pop bc
        djnz .ins
        ; draw buckets 31..0
        ld hl,dl_bkt+63
        ld b,32
.bk:    ld d,(hl)
        dec hl
        ld e,(hl)
        dec hl
        ld a,d
        or e
        jr nz,.wk0
        djnz .bk
        ret
.wk0:   push bc
        push hl
.wk:    push de
        call maybe_ei
        pop hl
        push hl
        call draw_entry
        pop hl
        ld de,10
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr nz,.wk
        pop hl
        pop bc
        djnz .bk
        ret

; HL -> entry
draw_entry:
        inc hl
        inc hl
        ld a,(hl)               ; kind
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (de_x),de
        ld a,(hl)
        ld (de_y),a
        inc hl
        ld a,(hl)
        ld (de_w),a
        inc hl
        ld a,(hl)
        ld (de_clip),a
        inc hl
        ld a,(hl)
        ld (de_arg),a
        inc hl
        ld a,(hl)
        ld (de_arg2),a
        dec hl
        dec hl
        dec hl
        dec hl
        dec hl
        dec hl
        dec hl
        ld a,(hl)
        or a
        jp z,draw_scenery
        dec a
        jp z,draw_car
        dec a
        jp z,draw_gantry
        ret
de_x    dw 0
de_y    db 0
de_w    db 0
de_clip db 0
de_arg  db 0
de_arg2 db 0

; ---------------------------------------------------------------- scenery
; type table (SCENERY): per type 8 level pointers (dw), level 7 = smallest
draw_scenery:
        ld a,(de_w)
        ld l,a
        ld h,high T_LEVEL
        ld a,(hl)               ; level 0..7, 255 = too small
        cp 12
        ret nc
        ld c,a
        ld a,(de_arg)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; 24 bytes per type
        ld de,SCENERY
        add hl,de
        ld a,c
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        ret z
        ex de,hl
        ld a,MAP_RACE
        ld (spr_map),a
        xor a
        ld (spr_masked),a
        jp draw_frame_c

; ---------------------------------------------------------------- traffic car
draw_car:
        ld a,(de_w)
        ld l,a
        ld h,high T_LEVEL
        ld a,(hl)
        cp 12
        ret nc
        add a,a
        ld c,a                  ; level*2
        ld a,(de_arg)           ; animation frame
        and 1
        jr z,.f0
        ld a,24
.f0:    add a,c
        ld c,a
        ld a,(de_arg2)          ; car type
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; 16
        ld d,h
        ld e,l
        add hl,hl               ; 32
        add hl,de               ; 48 per type
        ld de,CAR_LV
        add hl,de
        ld e,c
        ld d,0
        add hl,de
        ld a,MAP_FE
        out (BANKPORT),a        ; the table lives in upper bank 0 too
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,MAP_RACE
        out (BANKPORT),a
        ld a,d
        or e
        ret z
        ex de,hl
        ld a,MAP_FE
        ld (spr_map),a
        ld a,1
        ld (spr_masked),a
        jp draw_frame_c

; ---------------------------------------------------------------- frame drawing
; HL = frame (in bank spr_map), de_x = centre x, de_y = bottom row,
; de_clip = first hidden row (road in front)
draw_frame_c:
        ld a,(spr_map)
        out (BANKPORT),a
        ld a,(hl)
        ld (fr_wb),a
        inc hl
        ld a,(hl)
        ld (fr_h),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (fr_ph1),de
        ld (fr_src),hl
        ; left x = centre - width*2 (wb includes the shift byte: (wb-1)*4/2)
        ld a,(fr_wb)
        dec a
        add a,a                 ; half width in px = (wb-1)*2
        ld c,a
        ld b,0
        ld hl,(de_x)
        or a
        sbc hl,bc
        ; phase = bit 1 of x, byte = x >> 2 (signed)
        bit 1,l
        jr z,.p0
        push hl
        ld hl,(fr_ph1)          ; phase 1 data follows phase 0
        ld de,(fr_src)
        add hl,de
        ld (fr_src),hl
        pop hl
.p0:    sra h
        rr l
        sra h
        rr l                    ; byte column (signed)
        ld (fr_bx),hl
        ; rows: top = y - h + 1 ; draw rows [max(top,12), min(y+1, clip, 64))
        ld a,(de_y)
        inc a
        ld b,a                  ; bottom (exclusive)
        ld a,(de_clip)
        cp b
        jr nc,.c1
        ld b,a
.c1:    ld a,b
        cp 65
        jr c,.c2
        ld b,64
.c2:    ld a,(de_y)
        inc a
        ld hl,fr_h
        sub (hl)                ; top (may be negative)
        ld c,a
        ld d,0                  ; rows to skip at the top
        jp p,.t1
        neg
        ld d,a
        xor a
.t1:    cp 12
        jr nc,.t2
        ld e,a
        ld a,12
        sub e
        add a,d
        ld d,a
        ld a,12
.t2:    ld c,a                  ; first row
        ld a,b
        sub c
        jr z,.out
        jr c,.out
        ld (fr_rows),a
        ; skip D rows of source
        ld a,d
        or a
        jr z,.sk0
        ld a,(fr_wb)
        ld e,a
        ld a,d
        call mul8u
        ld a,(spr_masked)
        or a
        jr z,.sk1
        add hl,hl
.sk1:   ld de,(fr_src)
        add hl,de
        ld (fr_src),hl
.sk0:   ; horizontal clip: bytes [bx, bx+wb) against [0,32)
        ld hl,(fr_bx)
        ld a,(fr_wb)
        ld e,a
        ld d,0
        xor a
        ld (fr_skl),a
        bit 7,h
        jr z,.hp
        ; left part off screen
        ld a,l
        neg
        cp e
        jr nc,.out
        ld (fr_skl),a
        ld b,a
        ld a,e
        sub b
        ld e,a
        ld hl,0
.hp:    ld a,h
        or a
        jr nz,.out
        ld a,l
        cp 32
        jr nc,.out
        ld (fr_x0),a
        add a,e
        cp 33
        jr c,.hw
        ld a,32
.hw:    ld hl,fr_x0
        sub (hl)
        ld (fr_n),a             ; visible bytes per row
        ; destination
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,BBR0
        add hl,de
        ld a,(fr_x0)
        add a,l
        ld l,a
        ex de,hl                ; DE = dest
        ld a,(spr_masked)
        or a
        jp nz,blit_masked
        jp blit_trans
.out:   ld a,MAP_RACE
        out (BANKPORT),a
        ret

; colour-2-transparent blit
blit_trans:
        ld hl,(fr_src)
        ld a,(fr_skl)
        ld c,a
        ld b,0
        add hl,bc
        ld b,h
        ld c,l                  ; BC = source
        ld a,(fr_n)             ; entry into the unrolled row (10 code bytes per pixel byte)
        ld l,a
        add a,a
        add a,a
        add a,l
        add a,a                 ; *10
        push de                 ; dest
        ld e,a
        ld d,0
        ld hl,bt_end
        or a
        sbc hl,de
        ld (bt_jp+1),hl
        pop de
        ld a,(fr_wb)
        ld (bt_wb+1),a
        ld h,high MASK2
bt_row: push bc
        push de
bt_jp:  jp 0
        REPT 16
        ld a,(bc)
        ld l,a
        ld a,(de)
        and (hl)
        inc h
        or (hl)
        dec h
        ld (de),a
        inc bc
        inc e
        ENDR
bt_end: pop de
        pop bc
        ld a,e
        add a,32
        ld e,a
        jr nc,.d
        inc d
.d:
bt_wb:  ld a,0
        add a,c
        ld c,a
        jr nc,.s
        inc b
.s:     ld a,(fr_rows)
        dec a
        ld (fr_rows),a
        jp nz,bt_row
        ld a,MAP_RACE
        out (BANKPORT),a
        ret

; explicit-mask blit (mask, data pairs), unrolled 7 bytes per pixel byte
blit_masked:
        ld hl,(fr_src)
        ld a,(fr_skl)
        add a,a
        ld c,a
        ld b,0
        add hl,bc
        push hl
        ld a,(fr_n)
        ld l,a
        add a,a
        add a,a
        add a,a
        sub l                   ; *7
        push de
        ld e,a
        ld d,0
        ld hl,bm_end
        or a
        sbc hl,de
        ld (bm_jp+1),hl
        pop de
        ld a,(fr_wb)
        add a,a
        ld (bm_wb+1),a
        pop hl
bm_row: push hl
        push de
bm_jp:  jp 0
        REPT 16
        ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        ENDR
bm_end: pop de
        pop hl
        ld a,e
        add a,32
        ld e,a
        jr nc,.d
        inc d
.d:
bm_wb:  ld a,0
        add a,l
        ld l,a
        jr nc,.s
        inc h
.s:     ld a,(fr_rows)
        dec a
        ld (fr_rows),a
        jp nz,bm_row
        ld a,MAP_RACE
        out (BANKPORT),a
        ret

; E * A -> HL (unsigned)
mul8u:  ld d,0
        ld hl,0
        ld b,8
.l:     add hl,hl
        rla
        jr nc,.n
        add hl,de
.n:     djnz .l
        ret

spr_map    db 0
spr_masked db 0
fr_wb   db 0
fr_h    db 0
fr_src  dw 0
fr_ph1  dw 0
fr_bx   dw 0
fr_rows db 0
fr_skl  db 0
fr_x0   db 0
fr_n    db 0

; ---------------------------------------------------------------- gantry
; procedural: two pillars at +-1.25 road widths and a beam with a banner
draw_gantry:
        ld a,(de_w)
        cp 3
        ret c
        cp 150                  ; near enough to be overhead / off screen
        ret nc
        ld (g_w),a
        ; pillar height = 2.0 * w * (6/7) rows -> beam top row = y - h
        ld c,a
        srl a
        srl a
        ld b,a                  ; w/4
        ld a,c
        add a,b                 ; 1.25 w  (pillar offset)
        ld (g_off),a
        ld a,c
        srl a
        srl a
        srl a
        inc a
        ld (g_pw),a             ; pillar width = w/8 + 1
        ; vertical: road units -> rows: rows = units * w / 288; gantry 520 units
        ld a,c                  ; height 240 units = 0.84 w rows
        ld b,a
        srl b
        srl b
        srl b
        sub b
        srl b
        srl b
        sub b
        ld (g_h),a
        ld a,c
        srl a
        srl a
        srl a
        inc a
        ld (g_bh),a             ; beam thickness = w/8 + 1
        ; rows: beam from y-h .. y-h+bh ; pillars from y-h .. y
        ld a,(de_y)
        ld hl,g_h
        sub (hl)
        jr nc,.t0
        xor a
.t0:    ld (g_top),a
        ; pillars (rows top..min(y,clip))
        ld a,(de_y)
        inc a
        ld b,a
        ld a,(de_clip)
        cp b
        jr nc,.p1
        ld b,a
.p1:    ld a,b
        ld (g_bot),a
        ld a,(g_top)
        cp 12
        jr nc,.p2
        ld a,12
.p2:    ld (row),a
.pl:    ld a,(row)
        ld b,a
        ld a,(g_bot)
        cp b
        jr z,.pd
        jr c,.pd
        ld a,b
        call g_rowadr
        ; left pillar [x - off - pw, x - off)
        ld a,(g_off)
        ld c,a
        ld b,0
        ld hl,(de_x)
        or a
        sbc hl,bc
        push hl
        ld a,(g_pw)
        ld c,a
        or a
        sbc hl,bc
        ex de,hl
        pop hl
        ld a,(gan_col1)
        call span16
        ld a,(g_off)
        ld c,a
        ld b,0
        ld hl,(de_x)
        add hl,bc
        push hl
        ld a,(g_pw)
        ld c,a
        add hl,bc
        pop de
        ld a,(gan_col1)
        call span16
        ld hl,row
        inc (hl)
        jr .pl
.pd:    ; beam rows
        ld a,(g_top)
        ld hl,g_bh
        add a,(hl)
        ld b,a
        ld a,(g_bot)
        cp b
        jr nc,.b0
        ld b,a
.b0:    ld a,b
        ld (g_bot),a
        ld a,(g_top)
        cp 12
        jr nc,.b1
        ld a,12
.b1:    ld (row),a
.bl:    ld a,(row)
        ld b,a
        ld a,(g_bot)
        cp b
        jr z,.bd
        jr c,.bd
        ld a,b
        call g_rowadr
        ld a,(g_off)
        ld c,a
        ld a,(g_pw)
        add a,c
        ld c,a
        ld b,0
        ld hl,(de_x)
        or a
        sbc hl,bc
        ex de,hl
        ld hl,(de_x)
        add hl,bc
        ; rim rows (first and last) in the pillar colour
        ld a,(row)
        ld b,a
        ld a,(g_top)
        cp b
        jr z,.rim
        ld a,(g_bot)
        dec a
        cp b
        jr z,.rim
        ld a,(gan_col2)
        jr .bc
.rim:   ld a,(gan_col1)
.bc:    call span16
        ld hl,row
        inc (hl)
        jr .bl
.bd:    ; banner text on the beam when it is tall and wide enough
        ld a,(g_bh)
        cp 7
        ret c
        ld a,(de_arg)
        add a,a
        ld l,a
        ld h,0
        ld de,gan_text
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL = text
        push hl
        ld b,0
.tl:    ld a,(hl)
        or a
        jr z,.tz
        inc hl
        inc b
        jr .tl
.tz:    ld a,b                  ; text width in px = 4*len must fit in 2*off
        add a,a
        add a,a
        ld c,a
        ld a,(g_off)
        add a,a
        jr c,.fits
        cp c
        jr c,.no
.fits:  ; column = (x - 2*len) / 4
        ld a,b
        add a,a
        ld e,a
        ld d,0
        ld hl,(de_x)
        or a
        sbc hl,de
        bit 7,h
        jr nz,.no
        ld a,h
        or a
        jr nz,.no
        ld a,l
        srl a
        srl a
        ld c,a
        add a,b
        cp 33
        jr nc,.no
        ld a,(g_bh)             ; row = top + (bh-5)/2
        sub 5
        srl a
        ld hl,g_top
        add a,(hl)
        cp 12
        jr c,.no
        ld b,a
        ld a,(gan_col3)
        ld (bt_col),a
        pop hl
        jp bb_text
.no:    pop hl
        ret
gan_text: dw gt_start,gt_check,gt_check,gt_finish
gt_start: db "START",0
gt_check: db "CHECKPOINT",0
gt_finish: db "FINISH",0

g_rowadr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,BBR0
        add hl,de
        ld (rowadr),hl
        ld a,l
        ld (sp_rl+1),a
        ret
g_w     db 0
g_off   db 0
g_pw    db 0
g_h     db 0
g_bh    db 0
g_top   db 0
g_bot   db 0

; span16: DE = left x, HL = right x (signed, exclusive), A = colour
span16: ld b,a
        bit 7,h
        ret nz
        ld a,h
        or a
        ld a,128
        jr nz,.r
        ld a,l
        cp 129
        jr c,.r
        ld a,128
.r:     ld c,a
        bit 7,d
        jr z,.l
        ld e,0
        jp span
.l:     ld a,d
        or a
        ret nz
        ld a,e
        cp 128
        ret nc
        jp span
