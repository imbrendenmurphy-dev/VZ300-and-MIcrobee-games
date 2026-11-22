; =====================================================================
;  MINIMAP: 8 x 8 cells of bank-15 glyphs (C0h-FFh), 2 x 2 squares a
;  cell (4 x 5 pixels a square). Glyphs are built as squares are seen
;  and copied to the PCG in the blanking.
; =====================================================================

; mark what the view shows as seen (after compose)
mark_seen:
        ld hl,(ppos)
        call seen_sq
        ld a,(facing)
        inc a
        and 3
        call ahead_d
        call seen_sq
        ld a,(facing)
        add a,3
        and 3
        call ahead_d
        call seen_sq
        ; the squares whose faces won columns
        ld hl,slot_offp
        call facing_ptr
        ld (ms_off),hl
        ld c,0
.c:     ld a,c
        ld hl,zkey
        call add_a_hl
        ld a,(hl)
        inc a
        jr z,.cn
        ld a,c
        ld hl,zown
        call add_a_hl
        ld a,(hl)
        add a,a
        ld hl,(ms_off)
        call add_a_hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(ppos)
        add hl,de
        push bc
        call seen_sq
        pop bc
.cn:    inc c
        ld a,c
        cp VW
        jr nz,.c
        ; the open squares in front of their column's wall
        ld hl,sq_offp
        call facing_ptr
        ld (ms_off),hl
        ld ix,sq_tab
        ld b,NSQ
.s:     push bc
        ld a,(ix+2)
        add a,12
        cp VW
        jr nc,.sn
        ld hl,zkey
        call add_a_hl
        ld a,(ix+1)
        cp (hl)
        jr nc,.sn
        ld hl,(ms_off)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(ppos)
        add hl,de
        call seen_sq
.sn:    ld hl,(ms_off)
        inc hl
        inc hl
        ld (ms_off),hl
        inc ix
        inc ix
        inc ix
        pop bc
        djnz .s
        ; the player's own cell (the marker moves)
        call player_cell
        ld hl,last_cell
        cp (hl)
        jr z,.pc
        push af
        ld a,(hl)
        push af
        call mini_dirty_a
        pop af
        call cell_colour_a
        pop af
        ld (last_cell),a
        push af
        call cell_colour_a
        pop af
.pc:    jp mini_dirty_a

ms_off:     dw 0
last_cell:  db 0

; HL = A + HL
add_a_hl:
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; HL = square address -> A = SEEN index y*16+x (carry set: off the level)
sq_index:
        ld de,MAP
        or a
        sbc hl,de
        ld a,l
        and 31
        sub 8
        ret c
        cp 16
        ccf
        ret c
        ld e,a                  ; x
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h                  ; offset >> 5
        sub 8
        ret c
        cp 16
        ccf
        ret c
        add a,a
        add a,a
        add a,a
        add a,a
        add a,e
        or a
        ret

; HL = square: mark it seen, its minimap cell dirty
seen_sq:
        call sq_index
        ret c
        ld l,a
        ld h,high(SEEN)
        ld a,(hl)
        or a
        ret nz
        ld (hl),1
        ld a,l
        call sq_cell
        jp mini_dirty_a

; A = SEEN index (y*16+x) -> A = minimap cell (y/2)*8 + x/2
sq_cell:
        ld e,a
        and $E0                 ; (y & 14) * 16
        rrca
        rrca                    ; (y/2) * 8
        ld d,a
        ld a,e
        and $0E
        rrca
        add a,d
        ret

player_cell:
        ld hl,(ppos)
        call sq_index
        jp sq_cell

; A = cell: mark it for rebuilding
mini_dirty_a:
        push hl
        push bc
        ld c,a
        srl a
        srl a
        srl a
        ld hl,mini_dirty
        call add_a_hl
        ld a,c
        and 7
        ld b,a
        inc b
        ld a,$80
.r:     rlca
        djnz .r
        or (hl)
        ld (hl),a
        pop bc
        pop hl
        ret

; A = cell: place it on the screen in its colour (yellow: the player's)
cell_colour_a:
        ld (cc_cell),a
        ld c,a
        and 7
        add a,MAPCOL
        ld e,a
        ld a,c
        rrca
        rrca
        rrca
        and 7
        add a,MAPROW
        ld l,a
        ld h,0
        ld c,e
        call rowcol
        push hl
        call player_cell
        ld hl,cc_cell
        cp (hl)
        ld a,YELLOW
        jr z,.p
        ld a,(level)
        ld hl,mini_cols
        call add_a_hl
        ld a,(hl)
.p:     ld e,a
        ld a,(cc_cell)
        add a,$C0
        ld b,a
        ld c,BK_UI
        pop hl
        ld a,e
        jp put2

cc_cell:    db 0
mini_cols:  db GREY, GREEN, CYAN, BRED

; a whole new minimap: every glyph rebuilt, every screen cell placed
mini_all:
        ld hl,mini_dirty
        ld b,8
.d:     ld (hl),$FF
        inc hl
        djnz .d
        call player_cell
        ld (last_cell),a
        xor a
.c:     push af
        call cell_colour_a
        pop af
        inc a
        cp 64
        jr nz,.c
        ret

; in the blanking: rebuild and copy up to 8 dirty cells
vb_mini:
        ld b,8                  ; budget
        ld c,0                  ; cell
.l:     push bc
        ld a,c
        srl a
        srl a
        srl a
        ld hl,mini_dirty
        call add_a_hl
        ld a,c
        and 7
        ld b,a
        inc b
        ld a,$80
.r:     rlca
        djnz .r
        ld b,a
        and (hl)
        jr z,.n
        ld a,b
        cpl
        and (hl)
        ld (hl),a
        pop bc
        push bc
        ld a,c
        call mini_build
        pop bc
        dec b
        ret z
        push bc
.n:     pop bc
        inc c
        ld a,c
        cp 64
        jr nz,.l
        ret

; A = cell: build its glyph (from SEEN and MAP) and write it to the PCG
mini_build:
        ld (mb_cell),a
        ld c,a
        and 7
        add a,a
        ld e,a                  ; x of the top-left square
        ld a,c
        and $38                 ; (cell/8)*8
        add a,a
        add a,a                 ; (cell/8)*32 = (2*(cell/8))*16
        add a,e
        ld (mb_idx),a
        ld hl,mb_rows
        ld b,10
.z:     ld (hl),0
        inc hl
        djnz .z
        ld a,(mb_idx)
        ld de,mb_rows
        ld c,0
        call mb_square
        ld a,(mb_idx)
        inc a
        ld de,mb_rows
        ld c,1
        call mb_square
        ld a,(mb_idx)
        add a,16
        ld de,mb_rows+5
        ld c,0
        call mb_square
        ld a,(mb_idx)
        add a,17
        ld de,mb_rows+5
        ld c,1
        call mb_square
        ; to the PCG: bank 15, glyph 40h + cell
        ld a,LV_SCREEN|BK_UI
        out (P_LV),a
        ld a,(mb_cell)
        add a,$40
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,PCGWIN
        add hl,de
        ex de,hl
        ld hl,mb_rows
        ld bc,10
        ldir
        ld a,LV_SCREEN
        out (P_LV),a
        ret

mb_cell:    db 0
mb_idx:     db 0
mb_rows:    ds 10

; A = SEEN index, DE = 5 rows, C = 0 left half, 1 right half
mb_square:
        ld l,a
        ld h,high(SEEN)
        ld a,(hl)
        or a
        ret z                   ; never seen
        ; its square in MAP: (y+8)*32 + x+8
        ld a,l
        and 15
        add a,8
        ld b,a
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,8
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        add a,b
        ld l,a
        ld a,h
        adc a,high(MAP)
        ld h,a
        push de
        ld de,(ppos)
        or a
        sbc hl,de
        add hl,de
        pop de
        jr nz,.notp
        ld a,(facing)
        ld l,a
        add a,a
        add a,a
        add a,l                 ; *5
        ld hl,mp_player
        call add_a_hl
        jr .pat
.notp:  ld a,(hl)
        and 31
        ld hl,mp_types
        call add_a_hl
        ld a,(hl)
        ld l,a
        add a,a
        add a,a
        add a,l                 ; *5
        ld hl,mp_pats
        call add_a_hl
.pat:   ld b,5
.r:     ld a,(hl)
        inc hl
        bit 0,c
        jr nz,.right
        rlca
        rlca
        rlca
        rlca
.right: ex de,hl
        or (hl)
        ld (hl),a
        ex de,hl
        inc de
        djnz .r
        ret

; square type -> minimap pattern
mp_types:
        db 1,2,2,3,4,5,2,2,3,3,3,1,1,1,1,1
        db 6,6,7,8,9,1,1,1,1,1,1,1,1,1,1,1
mp_pats:
        db 0,0,0,0,0            ; 0 unused
        db 0,0,4,0,0            ; 1 floor: a dot
        db 15,15,15,15,15       ; 2 wall
        db 15,9,9,9,15          ; 3 door
        db 10,10,10,10,10       ; 4 gate
        db 15,11,13,11,15       ; 5 sealed
        db 15,0,15,0,15         ; 6 stairs
        db 0,6,9,6,0            ; 7 pit
        db 0,0,6,6,0            ; 8 plate
        db 9,6,6,9,0            ; 9 portal
mp_player:
        db 6,15,6,6,0           ; N
        db 4,6,15,6,4           ; E
        db 6,6,15,6,0           ; S
        db 2,6,15,6,2           ; W
