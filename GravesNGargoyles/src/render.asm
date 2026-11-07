; ============================================================================
;  RENDERER
;  Background: the level is pre-rendered into two 64-byte-wide ring buffers in
;  SRAM bank B, one per 2-pixel scroll phase.  New columns are rendered at the
;  edges as the camera moves.  Each frame the visible 32x56 window is copied
;  to the off-screen frame buffer, sprites are composed over it, and the ISR
;  copies the finished frame to video RAM during vertical blank.
; ============================================================================

; ---------------------------------------------------------------- world column
; get_wcol: DE = world byte column (0..2*LEVEL_W-1), HL = 56-byte dest buffer
get_wcol:
        push hl
        ld a,e
        and 1
        ld c,a                  ; half (0 left byte, 1 right byte)
        srl d
        rr e                    ; tile column
        ld hl,(lvl_map)
        add hl,de
        ld l,(hl)               ; column dictionary index
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(lvl_cols)
        add hl,de               ; column pointer
        pop de                  ; dest
        ld b,7
.row:   push bc
        ld a,(hl)               ; tile id
        inc hl
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,0
        add hl,bc               ; + half
        ld bc,(lvl_tiles)
        add hl,bc               ; tile gfx
        ld bc,2
        ldi
        inc hl
        ldi
        inc hl
        ldi
        inc hl
        ldi
        inc hl
        ldi
        inc hl
        ldi
        inc hl
        ldi
        inc hl
        ldi
        pop hl
        pop bc
        djnz .row
        ret

; ring offset of world byte column HL -> A = HL mod 48
ring_mod:
        ld de,RINGW
.l2:    or a
        sbc hl,de
        jr nc,.l2
        add hl,de
        ld a,l
        ret

; render_pair: HL = world byte column a.  Fills ring0[a], ring0[a+1], ring2[a]
render_pair:
        ld (rp_col),hl
        ex de,hl
        ld hl,WB0
        call get_wcol
        ld de,(rp_col)
        inc de
        ld hl,WB1
        call get_wcol
        ld hl,(rp_col)
        call ring_mod
        ld (rp_m0),a
        inc a
        cp 48
        jr c,$+3
        xor a
        ld (rp_m1),a
        ld ix,WB0
        ld hl,RING0
        ld b,56
.lp:    push bc
        push hl
        ; ring0[a]
        ld a,(rp_m0)
        ld e,a
        ld d,0
        add hl,de
        ld a,(ix+0)
        ld (hl),a
        ; ring2[a] = WB0<<4 | WB1>>4
        rlca
        rlca
        rlca
        rlca
        and $F0
        ld c,a
        ld a,(ix+56)
        rrca
        rrca
        rrca
        rrca
        and $0F
        or c
        ld de,RING2-RING0
        add hl,de
        ld (hl),a
        pop hl
        push hl
        ; ring0[a+1]
        ld a,(rp_m1)
        ld e,a
        ld d,0
        add hl,de
        ld a,(ix+56)
        ld (hl),a
        pop hl
        ld de,RINGW
        add hl,de
        inc ix
        pop bc
        djnz .lp
        ret

; camera_cols: keep the rings valid for the window at cam_draw
camera_cols:
        ld hl,(cam_draw)
        srl h
        rr l
        srl h
        rr l                    ; j0
        ld (cc_j0),hl
        ld de,31
        add hl,de
        ex de,hl                ; de = j0+31
        ld hl,(ring_hi)
        or a
        sbc hl,de
        jp p,.okhi
        ld hl,(ring_hi)
        inc hl
        ld (ring_hi),hl
        call render_pair
        ld hl,(ring_hi)
        ld de,(ring_lo)
        or a
        sbc hl,de
        ld de,46
        or a
        sbc hl,de
        ret m
        ret z
        ld hl,(ring_lo)
        inc hl
        ld (ring_lo),hl
        ret
.okhi:  ld hl,(ring_lo)
        ld de,(cc_j0)
        or a
        sbc hl,de               ; lo - j0
        ret z
        ret m
        ld hl,(ring_lo)
        dec hl
        ld (ring_lo),hl
        call render_pair
        ld hl,(ring_hi)
        ld de,(ring_lo)
        or a
        sbc hl,de
        ld de,46
        or a
        sbc hl,de
        ret m
        ret z
        ld hl,(ring_hi)
        dec hl
        ld (ring_hi),hl
        ret

; full ring rebuild for the window at cam_x
camera_reset:
        ld hl,(cam_x)
        ld (cam_draw),hl
        srl h
        rr l
        srl h
        rr l
        ld (ring_lo),hl
        dec hl
        ld (ring_hi),hl
.lp:    ld hl,(ring_hi)
        inc hl
        ld (ring_hi),hl
        call render_pair
        ld hl,(ring_lo)
        ld de,32
        add hl,de
        ld de,(ring_hi)
        or a
        sbc hl,de
        jr nc,.lp
        ret

; ---------------------------------------------------------------- bg copy
; copy the 32x56 window at cam_draw from the ring to FB rows 8..63
bg_copy:
        ld hl,(cam_draw)
        ld a,l
        and 2
        ld de,RING0
        jr z,.p0
        ld de,RING2
.p0:    ld (bg_base),de
        srl h
        rr l
        srl h
        rr l
        call ring_mod
        ld (bg_j),a
        ld b,a
        ld a,RINGW
        sub b                   ; bytes before wrap
        cp 32
        jr c,.split
        ld hl,LDI32
        ld (.c1+1),hl
        ld hl,LDI32+64          ; zero-length second part (just ret)
        ld (.c2+1),hl
        jr .go
.split: ld c,a                  ; n1
        neg
        add a,32
        ld b,a                  ; n2
        ld a,c
        neg
        add a,32
        add a,a
        ld e,a
        ld d,0
        ld hl,LDI32
        add hl,de
        ld (.c1+1),hl
        ld a,b
        neg
        add a,32
        add a,a
        ld e,a
        ld hl,LDI32
        add hl,de
        ld (.c2+1),hl
.go:    ld de,FB+8*FBW+4
        ld hl,(bg_base)
        ld a,56
.row:   ex af,af'
        push de
        push hl
        ld a,(bg_j)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
.c1:    call LDI32
        pop hl
        push hl
.c2:    call LDI32
        pop hl
        ld bc,RINGW
        add hl,bc
        pop de
        ex de,hl
        ld bc,FBW
        add hl,bc
        ex de,hl
        ex af,af'
        dec a
        jr nz,.row
        ret

LDI32:
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ret

; ---------------------------------------------------------------- sprites
; draw_spr: HL = frame descriptor (w,h,p0,p2), BC = screen x (signed),
;           A = y (signed), E bit0 = flip. spr_rows limits rows drawn.
draw_spr:
        ld (ds_y),a
        ld a,e
        ld (ds_flags),a
        xor a
        ld (ds_skip),a
        ; cull x: -16 <= x <= 136
        ld a,b
        or a
        jr z,.xpos
        inc a
        ret nz                  ; x < -256
        ld a,c
        cp -16
        ret c                   ; x < -16
        jr .xok
.xpos:  ld a,c
        cp 137
        ret nc
.xok:   ; column = (x+16)>>2
        ld a,c
        add a,16
        ld d,a
        srl a
        srl a
        ld (ds_col),a
        ld a,(hl)
        ld (ds_w),a
        inc hl
        ld a,(hl)
        ld (ds_h),a
        inc hl
        ld e,(hl)
        inc hl
        ld a,d
        and 2
        jr z,.ph0
        ; phase 2 (if the sprite has one)
        inc hl
        ld a,(hl)
        inc hl
        or (hl)
        jr z,.nop2
        ld d,(hl)
        dec hl
        ld e,(hl)
        ld a,(ds_w)
        inc a
        ld (ds_w),a
        jr .ph
.nop2:  dec hl
        dec hl
.ph0:   ld d,(hl)
.ph:    ; de = pixel data; rows to draw
        ld a,(spr_rows)
        or a
        jr z,.fullh
        ld b,a
        ld a,(ds_h)
        cp b
        jr c,.fullh
        ld a,b
        ld (ds_h),a
.fullh: ; vertical: FB row = y + 8
        ld a,(ds_y)
        add a,8
        bit 7,a
        jr z,.notop
        ; above the frame buffer: skip -row source rows
        neg
        ld b,a
        ld a,(ds_h)
        sub b
        ret z
        ret c
        ld (ds_h),a
        ; de += skip * w * 2
        ld a,(ds_w)
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,0
.sk:    ex de,hl
        push de
        add hl,de
        pop de
        ex de,hl
        djnz .sk
        ex de,hl                ; hl = skip bytes
        pop de
        add hl,de
        ex de,hl
        xor a
.notop: cp FBROWS
        ret nc
        ld (ds_row),a
        ; clip rows below the FB
        ld b,a
        ld a,(ds_h)
        add a,b
        sub FBROWS
        jr c,.noclip
        jr z,.noclip
        ld b,a
        ld a,(ds_h)
        sub b
        ret z
        ret c
        ld (ds_h),a
.noclip:
        ; dest = YTAB[row] + col
        ld a,(ds_row)
        add a,a
        ld l,a
        ld h,YTAB>>8
        set 7,l                 ; YTAB is at $7D80
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,(ds_col)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(ds_flags)
        rra
        jp c,draw_flip
        ; ---- normal
        ld a,(ds_w)
        ld c,a
        ld a,(ds_h)
        ld b,a
.row:   push bc
        push hl
        ld b,c
.byte:  ld a,(de)
        inc de
        and (hl)
        ld c,a
        ld a,(de)
        inc de
        or c
        ld (hl),a
        inc hl
        djnz .byte
        pop hl
        ld bc,FBW
        add hl,bc
        pop bc
        djnz .row
        ret

; ---- mirrored (source row read backwards through the FLIP table)
draw_flip:
        exx
        ld h,FLIPT>>8
        exx
        ld a,(ds_w)
        add a,a
        ld (ds_w2),a
        ld a,(ds_h)
        ld b,a
.row:   push bc
        push hl
        push de
        ld a,(ds_w2)
        dec a
        add a,e
        ld e,a
        jr nc,$+3
        inc d                   ; de -> data byte of last pair
        ld a,(ds_w)
        ld b,a
.byte:  ld a,(de)
        dec de
        exx
        ld l,a
        ld c,(hl)
        exx
        ld a,(de)
        dec de
        exx
        ld l,a
        ld a,(hl)
        exx
        and (hl)
        exx
        or c
        exx
        ld (hl),a
        inc hl
        djnz .byte
        pop de
        ld a,(ds_w2)
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        pop hl
        ld bc,FBW
        add hl,bc
        pop bc
        djnz .row
        ret

; draw_spr_world: like draw_spr but HL=frame, DE = world x, A = y, C=flip
draw_world:
        push af
        push hl
        ld hl,(cam_draw)
        ex de,hl
        or a
        sbc hl,de
        ld b,h
        ld e,c
        ld c,l
        pop hl
        pop af
        jp draw_spr

; ---------------------------------------------------------------- moon
; drawn only over pure sky bytes, so scenery passes in front of it
draw_moon:
        ld hl,(STG_MOON)
        ld a,h
        or l
        ret z
        inc hl
        ld b,(hl)               ; rows
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; p0 data
        ld hl,FB+9*FBW+4+26
        ld a,(col_sky)
        ld c,a
.row:   push bc
        push hl
        ld b,3
.byte:  ld a,(hl)
        cp c
        jr nz,.skip
        ld a,(de)
        and c
        inc de
        ex de,hl
        or (hl)
        ex de,hl
        ld (hl),a
        inc de
        jr .nx
.skip:  inc de
        inc de
.nx:    inc hl
        djnz .byte
        pop hl
        ld bc,FBW
        add hl,bc
        pop bc
        djnz .row
        ret

; ---------------------------------------------------------------- pixels
; plot: BC = screen x (0..127 valid), A = y (0..55), E = colour byte (all 4 px)
plot:
        ld d,a
        ld a,b
        or a
        ret nz
        ld a,c
        cp 128
        ret nc
        ld a,d
        cp 56
        ret nc
        add a,8
        add a,a
        ld l,a
        ld h,YTAB>>8
        set 7,l                 ; YTAB is at $7D80
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,c
        srl a
        srl a
        add a,4
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,c
        and 3
        ld c,a
        ld b,0
        push hl
        ld hl,PIXMASK
        add hl,bc
        ld a,(hl)
        pop hl
        ld b,a                  ; pixel mask
        cpl
        and (hl)
        ld c,a
        ld a,e
        and b
        or c
        ld (hl),a
        ret
PIXMASK: db $C0,$30,$0C,$03

; ---------------------------------------------------------------- text
; text: HL = zero-terminated string, DE = destination, A = colour byte,
;       stride in (txt_stride).  Opaque: background byte in (txt_bg).
; Each character is one byte (4 px) wide, 5 rows tall.
text:
        ld (txt_fg),a
.ch:    ld a,(hl)
        inc hl
        or a
        ret z
        cp 32
        jr nc,.pr
        ; control: 1 = colour change (next byte)
        ld a,(hl)
        inc hl
        ld (txt_fg),a
        jr .ch
.pr:    push hl
        push de
        cp 96
        jr c,$+4
        sub 32                  ; lower case -> upper
        sub 32
        ld l,a
        ld h,0
        ld c,l
        ld b,h
        add hl,hl
        add hl,hl
        add hl,bc               ; *5
        ld bc,FONT
        add hl,bc
        ld b,5
.rw:    push bc
        ld a,(txt_bg)
        cp 1
        jr z,.trans
        ld a,(hl)               ; glyph pixels
        ld c,a
        ld a,(txt_fg)
        and c
        ld b,a
        ld a,c
        cpl
        push hl
        ld hl,txt_bg
        and (hl)
        pop hl
        or b
        ld (de),a
        jr .nx
.trans: ld a,(hl)
        ld c,a
        cpl
        ex de,hl
        and (hl)
        ld b,a
        ld a,(txt_fg)
        and c
        or b
        ld (hl),a
        ex de,hl
.nx:    inc hl
        ld a,(txt_stride)
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        pop bc
        djnz .rw
        pop de
        inc de
        pop hl
        jr .ch

; text_fb: text at FB screen position. B = column (0..31), C = screen row
;          (0..63), HL = string, A = colour.  Transparent background.
text_fb:
        push af
        push hl
        ld a,c
        add a,a
        ld l,a
        ld h,YTAB>>8
        set 7,l                 ; YTAB is at $7D80
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,b
        add a,4
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ex de,hl
        ld a,FBW
        ld (txt_stride),a
        ld a,(txt_op)           ; cards draw text opaque over their backdrop
        or a
        jr nz,$+3
        inc a
        ld (txt_bg),a
        pop hl
        pop af
        jp text

; text_fbc: centred text (string length computed) on row C, colour A
text_fbc:
        push af
        push hl
        ld b,0
.ln:    ld a,(hl)
        inc hl
        or a
        jr z,.dn
        cp 32
        jr nc,.ok
        inc hl
        jr .ln
.ok:    inc b
        jr .ln
.dn:    ld a,32
        sub b
        srl a
        ld b,a
        pop hl
        pop af
        jp text_fb

; text_hud: B = column, C = row (0..7) in HUD buffer, HL string, A colour
text_hud:
        push af
        push hl
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld c,b
        ld b,0
        add hl,bc
        ld bc,HUDBUF
        add hl,bc
        ex de,hl
        ld a,32
        ld (txt_stride),a
        ld a,(col_hud)
        ld (txt_bg),a
        pop hl
        pop af
        jp text

; number to 6 decimal digits at num_buf (from 24-bit in num_val..+2 BCD)
; score is stored as 3 BCD bytes (big endian)
bcd_to_str:
        ld de,num_buf
        ld b,3
.lp:    ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and $0F
        add a,'0'
        ld (de),a
        inc de
        ld a,(hl)
        and $0F
        add a,'0'
        ld (de),a
        inc de
        inc hl
        djnz .lp
        ld a,'0'                ; scores are in tens
        ld (de),a
        inc de
        xor a
        ld (de),a
        ret

; add_score_k: A = BCD thousands of points (added to the hundreds-of-tens byte)
add_score_k:
        ld hl,score+1
        add a,(hl)
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld a,1
        ld (hud_need),a
        ret

; add_score: A = BCD amount in hundreds? -> adds A (BCD, units of 10) to score
add_score:
        ld hl,score+2
        add a,(hl)
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld a,1
        ld (hud_need),a
        ret

; ---------------------------------------------------------------- HUD
; HUD buffer layout (32 bytes per row, 8 rows):
;  [0-1] heart  [2] lives  [4-5] weapon icon  [6] weapon level
;  [8-10] magic  [13-18] score  [21-25] armour pips  row 7: divider / boss bar
hud_draw:
        xor a
        ld (hud_need),a
        ld hl,HUDBUF
        ld de,HUDBUF+1
        ld bc,383
        ld a,(col_hud)
        ld (hl),a
        ldir
        ; heart icon
        ld hl,S_HEART_0
        ld de,HUDBUF
        call hud_icon
        ld a,(lives)
        add a,'0'
        ld (num_buf),a
        xor a
        ld (num_buf+1),a
        ld hl,num_buf
        ld bc,$0201
        ld a,(col_yel)
        call text_hud
        ; weapon icon
        ld a,(weapon)
        add a,a
        ld e,a
        ld d,0
        ld hl,WICONS
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,HUDBUF+4
        call hud_icon
        ld a,(weapon)
        ld e,a
        ld d,0
        ld hl,wlevel
        add hl,de
        ld a,(hl)
        or a
        jr z,.nolv
        ld hl,STR_STAR
        ld bc,$0601
        ld a,(col_red)
        call text_hud
.nolv:  ; magic pips
        ld a,(magic)
        ld b,a
        ld c,8
.mg:    ld a,b
        or a
        jr z,.mgd
        push bc
        ld b,c
        ld hl,STR_MAGIC
        ld c,1
        ld a,(col_yel)
        call text_hud
        pop bc
        inc c
        dec b
        jr .mg
.mgd:   ; score
        ld hl,score
        call bcd_to_str
        ld hl,num_buf
        ld bc,$0D01
        ld a,(col_yel)
        call text_hud
        ; armour pips: filled = current, hollow up to max
        ld b,0
.ap:    ld a,b
        cp 5
        jr z,.apd
        push bc
        ld a,b
        ld hl,arm_cur
        cp (hl)
        ld hl,STR_PIPF
        jr c,.apf
        ld a,b
        ld hl,arm_max
        cp (hl)
        ld hl,STR_PIPH
        jr c,.apf
        ld hl,STR_SPACE
.apf:   ld a,b
        add a,21
        ld b,a
        ld c,1
        ld a,(col_grn)
        ld a,(col_yel)
        call text_hud
        pop bc
        inc b
        jr .ap
.apd:   call hp_hud
        ; row 7: divider or boss health bar
        ld hl,HUDBUF+7*32
        ld a,(boss_hp)
        or a
        jr nz,.boss
        ld b,32
        ld a,(col_dim)
.dv:    ld (hl),a
        inc hl
        djnz .dv
        jr .done
.boss:  ; bar length = boss_hp scaled to 32 bytes
        ld b,a
        ld a,(boss_hpmax)
        ld c,a
        ; len = hp*32/max
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,0
        ld e,0
.dvd:   or a
        sbc hl,bc
        jr c,.dvdd
        inc e
        jr .dvd
.dvdd:  ld hl,HUDBUF+7*32
        ld b,32
        ld a,(col_red)
        ld c,a
.bb:    ld a,e
        or a
        jr z,.bz
        dec e
        ld (hl),c
        jr .bn
.bz:    ld a,(col_hud)
        ld (hl),a
.bn:    inc hl
        djnz .bb
.done:  ; bottom border: divider line then a dark band
        ld hl,HUDBUF+8*32
        ld b,32
        ld a,(col_dim)
.bt:    ld (hl),a
        inc hl
        djnz .bt
        ld a,1
        ld (top_dirty),a
        ret

; hud_icon: HL = sprite descriptor (2 bytes wide, 8 rows), DE = HUD address
hud_icon:
        inc hl
        ld b,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
.r:     push bc
        ld b,2
.c:     ld a,(de)
        inc de
        and (hl)
        ld c,a
        ld a,(de)
        inc de
        or c
        ld (hl),a
        inc hl
        djnz .c
        ld bc,30
        add hl,bc
        pop bc
        djnz .r
        ret

WICONS: dw S_WLANCE_0,S_WDAGGER_0,S_WAXE_0,S_WTORCH_0
STR_STAR:  db "*",0
STR_MAGIC: db "*",0
STR_PIPF:  db "#",0
STR_PIPH:  db "=",0
STR_SPACE: db " ",0

; ---------------------------------------------------------------- particles
; particle: +0 xlo +1 xhi +2 y +3 vx +4 vy +5 life +6 colour  (8 bytes)
PSIZE equ 8
NPART equ 20

; spawn: DE = world x, A = y, B = vx, C = vy, L = colour byte, H = life
part_spawn:
        push ix
        call .sp
        pop ix
        ret
.sp:    push hl
        push af
        ld ix,parts
        ld a,NPART
.f:     ex af,af'
        ld a,(ix+5)
        or a
        jr z,.got
        push de
        ld de,PSIZE
        add ix,de
        pop de
        ex af,af'
        dec a
        jr nz,.f
        pop af
        pop hl
        ret
.got:   pop af
        pop hl
        ld (ix+0),e
        ld (ix+1),d
        ld (ix+2),a
        ld (ix+3),b
        ld (ix+4),c
        ld (ix+5),h
        ld (ix+6),l
        ret

; burst: DE = world x, A = y, B = count, C = colour byte
part_burst:
        ld (pb_x),de
        ld (pb_y),a
        ld a,c
        ld (pb_col),a
.lp:    push bc
        call rand
        and 7
        sub 4
        add a,a
        ld (pb_vx),a
        call rand
        and 7
        sub 6
        ld (pb_vy),a
        call rand
        and 7
        add a,8
        ld h,a
        ld a,(pb_col)
        ld l,a
        ld a,(pb_vx)
        ld b,a
        ld a,(pb_vy)
        ld c,a
        ld de,(pb_x)
        ld a,(pb_y)
        call part_spawn
        pop bc
        djnz .lp
        ret

parts_update:
        ld ix,parts
        ld b,NPART
.lp:    ld a,(ix+5)
        or a
        jr z,.nx
        dec (ix+5)
        ld a,(ix+3)             ; vx (signed) /2
        sra a
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld l,(ix+0)
        ld h,(ix+1)
        add hl,de
        ld (ix+0),l
        ld (ix+1),h
        ld a,(ix+4)
        sra a
        add a,(ix+2)
        ld (ix+2),a
        cp 60
        jr c,.ok
        ld (ix+5),0
.ok:    ld a,(frame_no)
        and 1
        jr nz,.nx
        inc (ix+4)              ; gravity
.nx:    ld de,PSIZE
        add ix,de
        djnz .lp
        ret

parts_draw:
        ld ix,parts
        ld b,NPART
.lp:    push bc
        ld a,(ix+5)
        or a
        jr z,.nx
        ld l,(ix+0)
        ld h,(ix+1)
        ld de,(cam_draw)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,(ix+2)
        ld e,(ix+6)
        call plot
.nx:    ld de,PSIZE
        add ix,de
        pop bc
        djnz .lp
        ret
