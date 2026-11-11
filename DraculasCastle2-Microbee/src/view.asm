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
            ; assets stay in the Microbee work block
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
            call world_view
            jp sample_view
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
