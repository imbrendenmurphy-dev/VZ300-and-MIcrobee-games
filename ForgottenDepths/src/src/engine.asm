; =====================================================================
;  engine.asm : level map, window rendering, lighting, tile animation
; =====================================================================
scr_x:   db 0
scr_y:   db 0
wx:      db 0
wy:      db 0
light_old:  dw LISTA         ; previous update's change list
light_oend: dw LISTA
light_dirty: db 0
light_var:  db 0
cast_sp:    dw 0
cast_next:  dw 0

; ---------------------------------------------------------------------
; set_window: from scr_x/scr_y
; ---------------------------------------------------------------------
set_window:
        ld a,(scr_x)
        rrca
        rrca
        rrca                    ; *32
        ld (wx),a
        ld (rc_col+1),a
        ld (cv_col+1),a
        ld a,(scr_y)
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,a
        sub b                   ; *15
        ld (wy),a
        add a,MAPH
        ld (rc_row+1),a
        ld (cv_row+1),a
        ret

; ---------------------------------------------------------------------
; cell_vram:
cell_vram:
        res 7,l
        ld a,h
cv_row: sub 0
        cp WINH
        ccf
        ret c
        ld e,a
        ld a,l
cv_col: sub 0
        cp WINW
        ccf
        ret c
        ld d,a
        ld a,e
        rrca
        rrca
        rrca
        ld e,a
        and $E0
        or d
        ld d,a
        ld a,e
        and 1
        or VRAM>>8
        ld e,d
        ld d,a
        or a
        ret

; ---------------------------------------------------------------------
; render_cell: HL = map/light address.  Draws the tile glyph for its light.
; ---------------------------------------------------------------------
render_cell:
        res 7,l
        ld a,h
rc_row: sub 0
        cp WINH
        ret nc
        ld e,a
        ld a,l
rc_col: sub 0
        cp WINW
        ret nc
        ld d,a
        ld a,e
        rrca
        rrca
        rrca
        ld b,a
        and $E0
        or d
        ld e,a
        ld a,b
        and 1
        or VRAM>>8
        ld d,a
        ld c,(hl)
        set 7,l
        ld a,(hl)
        res 7,l
        and 7
        jr z,.dk
        set 7,c
        ld (hl),c
.dk:    add a,GPAGES>>8
        ld b,a
        ld a,(bc)
        ld (de),a
        ret

; ---------------------------------------------------------------------
; render_window: draw all 32x15 cells
; ---------------------------------------------------------------------
render_window:
        ld a,(wy)
        add a,MAPH
        ld h,a
        ld de,VRAM
        ld a,WINH
.row:   push af
        ld a,(wx)
        ld l,a
.col:   ld c,(hl)
        set 7,l
        ld a,(hl)
        res 7,l
        and 7
        jr z,.dk
        set 7,c
        ld (hl),c
.dk:    add a,GPAGES>>8
        ld b,a
        ld a,(bc)
        ld (de),a
        inc l
        inc e
        ld a,e
        and 31
        jr nz,.col
        ld a,e
        or a
        jr nz,.nd
        inc d
.nd:    inc h
        pop af
        dec a
        jr nz,.row
        ret

; ---------------------------------------------------------------------
; cast: HL = origin map address, DE = ray table, IX = change list pointer
; Walks rays (SP-driven), raising the current light level of each cell
; and stopping after opaque cells.  Newly raised cells are appended to
; the list (bit 3 of the light byte marks list membership).
; ---------------------------------------------------------------------
cast:
        di
        ld (.base+1),hl
        ld (cast_sp),sp
        ex de,hl
        ld sp,hl
.node:  pop de
        ld a,d
        cp $80
        jr z,.done
        pop bc                  ; c = level, b = descendants
.base:  ld hl,0
        add hl,de
        ld a,(hl)
        and $40
        ex af,af'
        set 7,l
        ld a,(hl)
        and 7
        cp c
        jr nc,.nr
        ld a,(hl)
        bit 3,a
        jr nz,.inl
        or 8
        ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
.inl:   and $F8
        or c
        ld (hl),a
.nr:    ex af,af'
        jr z,.node
        ld a,b                  ; opaque: skip the cells it shadows
        or a
        jr z,.node
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,sp
        ld sp,hl
        jr .node
.done:  ld sp,(cast_sp)
        ret

; ---------------------------------------------------------------------
; restore_list: HL = start, DE = end.  current level := static, clear flag
; ---------------------------------------------------------------------
restore_list:
.l:     ld a,l
        cp e
        jr nz,.go
        ld a,h
        cp d
        ret z
.go:    ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(bc)
        and $70
        ld (.s+1),a
        rrca
        rrca
        rrca
        rrca
.s:     or 0
        ld (bc),a
        jr .l

; render_list: HL = start, DE = end ; skip_flag: skip cells still in a list (bit 3)
render_list:
.l:     ld a,l
        cp e
        jr nz,.go
        ld a,h
        cp d
        ret z
.go:    push de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
.skip:  ld a,(hl)
        and 0                   ; smc: 8 = skip cells flagged in the new list
        call z,render_cell
        pop hl
        pop de
        jr .l

; ---------------------------------------------------------------------
; light_update: recompute dynamic light (player lantern, fireball, blast)
; ---------------------------------------------------------------------
light_update:
        xor a
        ld (light_dirty),a
        ld hl,(light_old)
        ld de,(light_oend)
        call restore_list
        ; new list buffer = the other one
        ld hl,(light_old)
        ld a,h
        cp LISTA>>8
        ld ix,LISTB
        jr z,.b
        ld ix,LISTA
.b:     push ix
        ; player lantern
        ld a,(p_dir)
        add a,a                 ; NVAR = 2
        ld b,a
        ld a,(light_var)
        add a,b
        add a,a
        ld e,a
        ld d,0
        ld hl,PRAYS0
        ld a,(p_sun)
        or a
        jr z,.ps
        ld hl,PRAYS1
.ps:    add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(p_addr)
        ld a,(p_dead)
        or a
        call z,cast
        ; fireball
        ld a,(fb_on)
        or a
        jr z,.nofb
        ld hl,(fb_addr)
        ld de,RL_fball
        call cast
.nofb:  ld a,(boom_t)
        or a
        jr z,.noboom
        ld hl,(boom_addr)
        ld de,RL_boom
        call cast
.noboom:
        ; render cells that lost light (old list, not re-raised), then new list
        ld a,8
        ld (render_list.skip+2),a
        ld hl,(light_old)
        ld de,(light_oend)
        call render_list
        xor a
        ld (render_list.skip+2),a
        pop hl
        ld (light_old),hl
        ld (light_oend),ix
        push ix
        pop de
        jp render_list

; ---------------------------------------------------------------------
; room_enter: static lights, animation list, full redraw
; ---------------------------------------------------------------------
room_enter:
        ; restore previous dynamic list
        ld hl,(light_old)
        ld de,(light_oend)
        call restore_list
        ld hl,LISTA
        ld (light_old),hl
        ld (light_oend),hl
        call set_window
        call room_statics
        call anim_build
        call light_update_noren
        jp render_window

; compute static light for the window (also used after a wall breaks)
room_statics:
        ; clear window light bytes
        ld a,(wy)
        add a,MAPH
        ld h,a
        ld c,WINH
.cr:    ld a,(wx)
        or $80
        ld l,a
        ld b,WINW
        xor a
.cc:    ld (hl),a
        inc l
        djnz .cc
        inc h
        dec c
        jr nz,.cr
        ; cast every light source tile (static trees live in bank 1)
        call bank1
        ld ix,LISTA
        ld a,(wy)
        add a,MAPH
        ld h,a
        ld c,WINH
.sr:    ld a,(wx)
        ld l,a
        ld b,WINW
.sc:    ld a,(hl)
        and $7F
        ld e,a
        ld d,TLITE>>8
        ld a,(de)
        or a
        jr z,.ns
        push bc
        push hl
        add a,a
        ld e,a
        ld d,0
        ld hl,LITETAB
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        push hl
        call cast
        ld ix,LISTA             ; list content not needed for statics
        pop hl
        pop bc
.ns:    inc l
        djnz .sc
        inc h
        dec c
        jr nz,.sr
        call bank0
        ; commit: static := current, clear flag
        ld a,(wy)
        add a,MAPH
        ld h,a
        ld c,WINH
.mr:    ld a,(wx)
        or $80
        ld l,a
        ld b,WINW
.mc:    ld a,(hl)
        and 7
        ld e,a
        rlca
        rlca
        rlca
        rlca
        or e
        ld (hl),a
        inc l
        djnz .mc
        inc h
        dec c
        jr nz,.mr
        ret

; light update without drawing (used before a full window redraw)
light_update_noren:
        ld a,$C9
        ld (render_list),a
        call light_update
        ld a,$7D                ; ld a,l (first opcode of render_list)
        ld (render_list),a
        ret

; ---------------------------------------------------------------------
; tile animation
; ---------------------------------------------------------------------
ANIMMAX EQU 120
anim_n:   db 0
anim_list: ds ANIMMAX*2

anim_build:
        ld ix,anim_list
        xor a
        ld (anim_n),a
        ld a,(wy)
        add a,MAPH
        ld h,a
        ld b,WINH
.r:     push bc
        ld a,(wx)
        ld l,a
        ld b,WINW
.c:     ld a,(hl)
        and $7F
        ld e,a
        ld d,TPROP>>8
        ld a,(de)
        and 2
        jr z,.n
        ld a,(anim_n)
        cp ANIMMAX
        jr nc,.n
        inc a
        ld (anim_n),a
        ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
.n:     inc l
        djnz .c
        inc h
        pop bc
        djnz .r
        ret

; anim_tick: advance animated tiles by their speed class, redraw visible ones
anim_tick:
        ld a,(anim_n)
        or a
        ret z
        ld b,a
        ld ix,anim_list
.l:     push bc
        ld l,(ix+0)
        ld h,(ix+1)
        ld a,(hl)
        and $7F
        ld e,a
        ld d,TANIM>>8
        ld a,(de)
        bit 7,a
        jr nz,.rnd
        ld c,a
        ld a,(frame)
        add a,l                 ; per-cell phase offset
        and c
        jr nz,.skip
        jr .adv
.rnd:   call rnd
        and $3F
        jr nz,.skip
.adv:   ld a,(hl)
        ld c,a
        inc a
        and 3
        ld b,a
        ld a,c
        and $FC
        or b
        ld (hl),a
        set 7,l
        ld a,(hl)
        and 7
        call nz,render_cell
.skip:  inc ix
        inc ix
        pop bc
        djnz .l
        ret
