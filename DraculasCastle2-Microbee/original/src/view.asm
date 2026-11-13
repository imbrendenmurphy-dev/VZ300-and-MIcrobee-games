; ===========================================================================
;  view.asm - first-person renderer
;  Area part 1 (bank 3 @ $4000): header + backgrounds + wall kinds
;    +0  dw bg[4]   (per facing)
;    +8  dw wallA, wallB   -> each: dw side[6], front[3]
;  Area part 2 (bank 1 @ $4000): decor + object tables
;    +0  dw decor_table, obj_table
;    decor entry (id 1..): dw f1,f2,f3,s0,s1,s2  (0 = none)
;    object entry (id 1..): dw d1,d2,d3
;  Masked sprite: db xb, y, wb, h ; then h*wb (mask,data) pairs
; ===========================================================================

VBUF        equ BACK            ; viewport lives in the back buffer (32 bytes/row)
P1          equ $4000           ; area part 1 base (bank 3)
P2          equ P2BASE          ; area part 2 base (main RAM)

bank3:      ld a,3
setbank:    ld (cur_bank),a
            out ($37),a
            ret

; geometry tables (generated in geom.inc): front faces per depth 1..3
;   front_y0, front_rows, front_wb (bytes), front_x (byte x of lateral-0 face)

; ---------------------------------------------------------------------------
; sample_view: fills view_cells[20] (d*5 + l+2) with raw cell bytes
; ---------------------------------------------------------------------------
sample_view:
            push ix
            call sv_inner
            pop ix
            ret
sv_inner:
            ld a,(pdir)
            add a,a
            ld e,a
            ld d,0
            ld hl,dir_vec
            add hl,de
            ld a,(hl)
            ld (fdx),a
            inc hl
            ld a,(hl)
            ld (fdy),a
            ; right vector = (-fdy, fdx)
            ld a,(fdy)
            neg
            ld (rdx),a
            ld a,(fdx)
            ld (rdy),a
            ld ix,view_cells
            ld a,(px)
            ld (cx0),a
            ld a,(py)
            ld (cy0),a
            ld b,4                  ; depth rows
.drow:      push bc
            ; start at lateral -2: cell = base - 2*right
            ld a,(rdx)
            add a,a
            ld c,a
            ld a,(cx0)
            sub c
            ld (cxl),a
            ld a,(rdy)
            add a,a
            ld c,a
            ld a,(cy0)
            sub c
            ld (cyl),a
            ld b,5
.lat:       push bc
            ld a,(cxl)
            ld c,a
            ld a,(cyl)
            ld b,a
            call get_cell
            ld (ix+0),a
            inc ix
            ld a,(rdx)
            ld c,a
            ld a,(cxl)
            add a,c
            ld (cxl),a
            ld a,(rdy)
            ld c,a
            ld a,(cyl)
            add a,c
            ld (cyl),a
            pop bc
            djnz .lat
            ; advance depth
            ld a,(fdx)
            ld c,a
            ld a,(cx0)
            add a,c
            ld (cx0),a
            ld a,(fdy)
            ld c,a
            ld a,(cy0)
            add a,c
            ld (cy0),a
            pop bc
            djnz .drow
            ret

; get_cell: C = x, B = y -> A = cell byte (out of bounds = wall A)
get_cell:
            ld a,c
            cp 16
            jr nc,.oob
            ld a,b
            cp 16
            jr nc,.oob
            ; addr = map_ptr + y*16 + x
            ld a,b
            add a,a
            add a,a
            add a,a
            add a,a
            add a,c
            ld l,a
            ld a,(map_page)
            ld h,a
            ld a,(hl)
            ret
.oob:       ld a,1
            ret

; ---------------------------------------------------------------------------
; classify a cell for drawing: A = cell -> A = kind (0 open, 1 A, 2 B), C = decor id
; ---------------------------------------------------------------------------
classify:
            ld b,a
            and 7
            jr z,.open
            cp 1
            jr z,.wa
            cp 2
            jr z,.wb
            cp 3
            jr z,.door
            cp 4
            jr z,.secret
            cp 5
            jr z,.exit
.open:      ld c,0
            xor a
            ret
.wa:        ld a,b
            rrca
            rrca
            rrca
            and $1F
            ld c,a
            ld a,1
            ret
.wb:        ld a,b
            rrca
            rrca
            rrca
            and $1F
            ld c,a
            ld a,2
            ret
.door:      ld a,(area_door_decor)
            ld c,a
            ld a,(area_door_kind)
            ret
.secret:    ld c,0
            ld a,b
            and $08
            ld a,1
            ret z
            inc a
            ret
.exit:      ; decor from exit table
            ld a,b
            rrca
            rrca
            rrca
            and $1F
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl               ; 8 bytes per exit entry
            ld de,(area_exits)
            add hl,de
            ld de,4
            add hl,de
            ld c,(hl)               ; decor
            inc hl
            ld a,(hl)               ; wall kind
            ret

; ---------------------------------------------------------------------------
; render_view: draw the complete first-person view into VBUF
; ---------------------------------------------------------------------------
render_view:
            call sample_view
            call bank3
            ; background for facing
            ld a,(pdir)
            add a,a
            ld l,a
            ld h,P1/256
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld de,VBUF
            ld b,52
.bg:        push bc
            ld bc,20
            ldir
            ex de,hl
            ld bc,12
            add hl,bc
            ex de,hl
            pop bc
            djnz .bg
            ; occlusion: find the deepest depth that can be visible
            call max_depth
.dl:        ld (rv_d),a
            ld hl,lat_order
.ll:        ld a,(hl)
            cp $80
            jr z,.dnext
            inc hl
            push hl
            ld (rv_l),a
            call draw_cell
            pop hl
            jr .ll
.dnext:     ld a,(rv_d)
            dec a
            jp p,.dl
            ret

lat_order:  db -2,2,-1,1,0,$80

; vsolid: C = cell index (d*5+l+2) -> NZ if solid
vsolid:     ld b,0
            ld hl,view_cells
            add hl,bc
            ld a,(hl)
            and 7
            ret

; A = 1 if (1,0) is a wall with both edges covered; 2 if (2,0) blocks depth 3; else 3
max_depth:
            ld c,7                  ; (1,0)
            call vsolid
            jr z,.d2
            ld c,1                  ; (0,-1)
            call vsolid
            jr nz,.l1
            ld c,6                  ; (1,-1)
            call vsolid
            jr z,.d2
.l1:        ld c,3                  ; (0,1)
            call vsolid
            jr nz,.one
            ld c,8                  ; (1,1)
            call vsolid
            jr z,.d2
.one:       ld a,1
            ret
.d2:        ld c,12                 ; (2,0)
            call vsolid
            jr z,.three
            ld c,6                  ; (1,-1)
            call vsolid
            jr nz,.r2
            ld c,11                 ; (2,-1)
            call vsolid
            jr z,.three
.r2:        ld c,8                  ; (1,1)
            call vsolid
            jr nz,.two
            ld c,13                 ; (2,1)
            call vsolid
            jr z,.three
.two:       ld a,2
            ret
.three:     ld a,3
            ret

; draw one cell (rv_d, rv_l)
draw_cell:
            ; fetch cell byte
            ld a,(rv_d)
            ld c,a
            add a,a
            add a,a
            add a,c                 ; d*5
            ld c,a
            ld a,(rv_l)
            add a,2
            add a,c
            ld e,a
            ld d,0
            ld hl,view_cells
            add hl,de
            ld a,(hl)
            ld (rv_cell),a
            call classify
            ld (rv_kind),a
            ld a,c
            ld (rv_decor),a
            ld a,(rv_kind)
            or a
            jp z,draw_floor_obj
            ; --- front face (d>=1) ---
            ld a,(rv_d)
            or a
            jr z,.side
            call front_ok
            jr nc,.side
            call draw_front
            ld a,(rv_decor)
            or a
            call nz,draw_front_decor
.side:      ld a,(rv_l)
            or a
            ret z
            call side_slot          ; A = slot index or $FF
            cp $FF
            ret z
            ld (rv_slot),a
            call draw_side
            ; side decor only for |l|=1, d<=2
            ld a,(rv_decor)
            or a
            ret z
            ld a,(rv_slot)
            cp 3
            ret nc                  ; slots 0,1,2 = (0,1),(1,1),(2,1)
            jp draw_side_decor

; front face exists for this lateral? (d=1,2: |l|<=1 ; d=3: |l|<=2) -> carry set if yes
front_ok:
            ld a,(rv_l)
            or a
            jp p,.p
            neg
.p:         ld c,a
            ld a,(rv_d)
            cp 3
            ld a,c
            jr z,.d3
            cp 2
            ret                     ; carry if |l| < 2
.d3:        cp 3
            ret

; side slot index for (d,|l|): (0,1)=0 (1,1)=1 (2,1)=2 (3,1)=3 (2,2)=4 (3,2)=5 else $FF
side_slot:
            ld a,(rv_l)
            or a
            jp p,.p
            neg
.p:         ld c,a
            ld a,(rv_d)
            dec c
            jr nz,.l2
            ret                     ; |l|=1 -> slot = d
.l2:        dec c
            jr nz,.no
            cp 2
            jr c,.no
            add a,2                 ; d=2 -> 4, d=3 -> 5
            ret
.no:        ld a,$FF
            ret

; wall table ptr for kind -> HL
wall_table:
            ld a,(rv_kind)
            dec a
            add a,a
            add a,8
            ld l,a
            ld h,P1/256
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ret

; ---------------------------------------------------------------------------
; draw_front: rect copy of front face texture with lateral clipping
; ---------------------------------------------------------------------------
draw_front:
            call bank3
            call wall_table
            ld a,(rv_d)
            dec a
            add a,a
            add a,12
            ld e,a
            ld d,0
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a                  ; hl = texture
            push hl
            ld a,(rv_d)
            dec a
            ld e,a
            ld d,0
            ld hl,front_wb
            add hl,de
            ld a,(hl)
            ld (fw_wb),a
            ld hl,front_x
            add hl,de
            ld b,(hl)               ; x of lateral-0 face (bytes)
            ld hl,front_y0
            add hl,de
            ld a,(hl)
            ld (fw_y0),a
            ld hl,front_rows
            add hl,de
            ld a,(hl)
            ld (fw_rows),a
            ; x = front_x + l*wb
            ld a,(rv_l)
            ld c,a
            ld a,(fw_wb)
            ld e,a
            ld a,b
            bit 7,c
            jr z,.pos
.neg:       sub e
            inc c
            jr nz,.neg
            jr .xd
.pos:       inc c
.posl:      dec c
            jr z,.xd
            add a,e
            jr .posl
.xd:        ; A = x (signed). clip
            ld (fw_x),a
            ld c,0                  ; src column offset
            bit 7,a
            jr z,.nl
            neg
            ld c,a                  ; skip -x columns
            xor a
.nl:        ld (fw_sx),a            ; start x
            ld a,c
            ld (fw_soff),a
            ; end = min(20, x+wb)
            ld a,(fw_x)
            ld e,a
            ld a,(fw_wb)
            add a,e
            cp 21
            jr c,.ne
            bit 7,a
            jr nz,.ne
            ld a,20
.ne:        ld e,a
            ld a,(fw_sx)
            ld c,a
            ld a,e
            sub c                   ; width to copy
            pop hl
            ret z
            ret c
            ld (fw_cw),a
            ; src += soff
            ld a,(fw_soff)
            ld e,a
            ld d,0
            add hl,de
            ; dst = VBUF + y0*32 + sx
            push hl
            ld a,(fw_y0)
            ld d,a
            ld a,(fw_sx)
            ld c,a
            call back_addr
            ex de,hl
            pop hl
            ld a,(fw_rows)
            ld b,a
.row:       push bc
            push hl
            push de
            ld a,(fw_cw)
            ld c,a
            ld b,0
            ldir
            pop hl
            ld bc,32
            add hl,bc
            ex de,hl
            pop hl
            ld a,(fw_wb)
            ld c,a
            ld b,0
            add hl,bc
            pop bc
            djnz .row
            ret

; ---------------------------------------------------------------------------
; draw_side: side piece sprite (slot rv_slot), mirrored when l > 0
; ---------------------------------------------------------------------------
draw_side:
            call bank3
            call wall_table
            ld a,(rv_slot)
            add a,a
            ld e,a
            ld d,0
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld a,(rv_l)
            or a
            jp m,blit_masked
            jp blit_mirror

draw_front_decor:
            ; A = decor id (1..)
            call decor_entry        ; hl -> entry (bank 1 selected)
            ld a,(rv_d)
            dec a
            add a,a
            ld e,a
            ld d,0
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            or h
            ret z
            ; x offset = l * wb (bytes)
            push hl
            ld a,(rv_d)
            dec a
            ld e,a
            ld d,0
            ld hl,front_wb
            add hl,de
            ld e,(hl)
            ld a,(rv_l)
            ld c,a
            xor a
            bit 7,c
            jr z,.p
.n:         sub e
            inc c
            jr nz,.n
            jr .d
.p:         inc c
.pl:        dec c
            jr z,.d
            add a,e
            jr .pl
.d:         pop hl
            ld (blit_dx),a
            jp blit_masked_off

draw_side_decor:
            ld a,(rv_decor)
            call decor_entry
            ld a,(rv_slot)
            add a,a
            add a,6
            ld e,a
            ld d,0
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            or h
            ret z
            ld a,(rv_l)
            or a
            jp m,blit_masked
            jp blit_mirror

; A = decor id -> HL = entry ptr (bank 1)
decor_entry:
            dec a
            ld l,a
            ld h,0
            add hl,hl
            ld e,l
            ld d,h
            add hl,hl
            add hl,de               ; *6
            add hl,hl               ; *12
            ld de,(P2)
            add hl,de
            ret

; floor cell: draw object (l = 0 at d>=1, or |l| = 1 at d = 2,3)
draw_floor_obj:
            ld a,(rv_d)
            or a
            ret z
            ld a,(rv_l)
            or a
            jr z,.l0
            cp 2
            ret z
            cp -2
            ret z
            ld a,(rv_d)
            cp 2
            ret c
.l0:        ld a,(rv_cell)
            and 7
            ret nz
            ld a,(rv_cell)
            rrca
            rrca
            rrca
            and $1F
            ret z
            call event_sprite       ; A = event id -> A = object sprite id (0 none)
            or a
            ret z
            ld c,a
            ld a,c
            dec a
            ld l,a
            ld h,0
            ld e,l
            ld d,h
            add hl,hl
            add hl,de
            add hl,hl               ; *6
            ld de,(P2+2)
            add hl,de
            ld a,(rv_d)
            dec a
            add a,a
            ld e,a
            ld d,0
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ; lateral offset: l * (7 bytes at d=2, 5 at d=3)
            ld a,(rv_d)
            cp 2
            ld b,7
            jr z,.w
            ld b,5
.w:         ld a,(rv_l)
            or a
            jr z,.z
            jp p,.p
            xor a
            sub b
            jr .z
.p:         ld a,b
.z:         ld (blit_dx),a
            ld a,(rv_l)
            or a
            ld a,(rv_jig)
            jr z,.j
            xor a
.j:         ld (blit_dy),a
            call blit_masked_off
            xor a
            ld (blit_dy),a
            ret

; ---------------------------------------------------------------------------
; Masked sprite blitters into the back buffer
;   blit_masked:      HL = sprite (header xb,y,wb,h)
;   blit_masked_off:  same with x offset (blit_dx, signed bytes); skipped if clipped
;   blit_mirror:      mirrored around the viewport centre (x' = 20 - xb - wb)
; ---------------------------------------------------------------------------
blit_masked:
            xor a
            ld (blit_dx),a
blit_masked_off:
            ld a,(blit_dx)
            add a,(hl)              ; xb + dx
            bit 7,a
            ret nz                  ; off left
            ld c,a
            inc hl
            ld a,(blit_dy)
            add a,(hl)              ; y
            ld d,a
            inc hl
            ld b,(hl)               ; wb
            inc hl
            ld a,c
            add a,b
            cp 21
            ret nc                  ; off right
            ld a,(hl)               ; h
            inc hl
            push hl
            push bc
            ld (bm_h),a
            call back_addr          ; hl = dst (uses b)
            pop bc
            ld a,b
            ld (bm_w),a
            ex de,hl                ; de = dst
            pop hl                  ; hl = src
.row:       push de
            ld a,(bm_w)
            ld b,a
.byte:      ld a,(de)
            and (hl)
            inc hl
            or (hl)
            inc hl
            ld (de),a
            inc de
            djnz .byte
            pop de
            ex de,hl
            ld bc,32
            add hl,bc
            ex de,hl
            ld a,(bm_h)
            dec a
            ld (bm_h),a
            jr nz,.row
            ret

blit_mirror:
            ld a,(hl)               ; xb
            inc hl
            ld d,(hl)               ; y
            inc hl
            ld b,(hl)               ; wb
            inc hl
            ld c,a
            ld a,20
            sub c
            sub b
            ld c,a                  ; x' (left)
            add a,b
            dec a
            ld c,a                  ; rightmost byte column
            ld a,(hl)
            inc hl
            ld (bm_h),a
            ld a,b
            ld (bm_w),a
            push hl
            call back_addr
            ex de,hl                ; de = dst (rightmost)
            pop hl
            ld b,FLIP/256
.row:       push de
            ld a,(bm_w)
            ld (bm_c),a
.byte:      ld c,(hl)               ; mask
            inc hl
            ld a,(bc)
            ex de,hl
            and (hl)
            ex de,hl
            ld (de),a
            ld c,(hl)               ; data
            inc hl
            ld a,(bc)
            ex de,hl
            or (hl)
            ld (hl),a
            ex de,hl
            dec de
            ld a,(bm_c)
            dec a
            ld (bm_c),a
            jr nz,.byte
            pop de
            ex de,hl
            ld c,32
            ld a,b
            ld b,0
            add hl,bc
            ld b,a
            ex de,hl
            ld a,(bm_h)
            dec a
            ld (bm_h),a
            jr nz,.row
            ret

; build pixel-pair flip table at FLIP
make_flip:
            ld hl,FLIP
            ld c,0
.l:         ld a,c
            and $03
            rrca
            rrca
            ld e,a
            ld a,c
            and $0C
            rlca
            rlca
            or e
            ld e,a
            ld a,c
            and $30
            rrca
            rrca
            or e
            ld e,a
            ld a,c
            and $C0
            rlca
            rlca
            or e
            ld (hl),a
            inc hl
            inc c
            jr nz,.l
            ret

dir_vec:    db 0,-1, 1,0, 0,1, -1,0
