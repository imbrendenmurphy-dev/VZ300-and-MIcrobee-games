; ---------------------------------------------------------------------------
; Incidental animation: fans turn, gauges twitch, terminal screens scroll,
; beacons sweep, LED panels and wall screens flicker, a failing lamp blinks.
; Each such decor tile has a partner frame (amb_pairs, from gen.py).  On entering
; a room the cells holding one are listed; every other frame one of them swaps
; to its partner (in the room map too, so the next swap knows where it is),
; unless Wren or a robot stands over it (that would cut a hole in the sprite).
; ---------------------------------------------------------------------------
AMB_MAX equ 24

; List the room's animated cells (after the room map is built).
amb_scan:
        xor a
        ld (amb_n),a
        ld (amb_i),a
        ld hl,ROOM_MAP
        ld c,0                  ; row
.r:     ld b,0                  ; column
.c:     ld a,(hl)
        call amb_partner
        jr nc,.n
        ld a,(amb_n)
        cp AMB_MAX
        ret nc
        push hl
        add a,a
        ld hl,amb_list
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld (hl),b
        inc hl
        ld (hl),c
        pop hl
        ld a,(amb_n)
        inc a
        ld (amb_n),a
.n:     inc hl
        inc b
        ld a,b
        cp COLS
        jr nz,.c
        inc c
        ld a,c
        cp ROOM_ROWS
        jr nz,.r
        ret

; A = tile -> carry and A = its partner, or no carry.  Preserves BC, HL.
amb_partner:
        push hl
        ld e,a
        ld hl,amb_pairs
.p:     ld a,(hl)
        cp 255
        jr z,.no
        cp e
        inc hl
        jr z,.a                 ; first of a pair: the second
        ld a,(hl)
        cp e
        jr z,.b                 ; second: the first
        inc hl
        jr .p
.a:     ld a,(hl)
        pop hl
        scf
        ret
.b:     dec hl
        ld a,(hl)
        pop hl
        scf
        ret
.no:    pop hl
        or a
        ret

; One step, every other frame (rooms only).
amb_step:
        ld a,(frames)
        and 1
        ret nz
        ld a,(amb_n)
        or a
        ret z
        ld b,a
        ld a,(amb_i)            ; the next one round
        inc a
        cp b
        jr c,.i
        xor a
.i:     ld (amb_i),a
        add a,a
        ld hl,amb_list
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (amb_c),a
        inc hl
        ld a,(hl)
        ld (amb_r),a
        ld a,(wx)               ; under Wren?  (her box in cells, a cell to spare)
        srl a
        srl a
        dec a
        ld b,a
        add a,5
        ld c,a
        ld a,(wy)
        ld e,a
        call amb_hit
        ret c
        ld a,(nrob)             ; under a robot?
        or a
        jr z,.go
        ld b,a
        ld ix,robots
.rb:    push bc
        ld a,(ix+RB_X)
        srl a
        srl a
        dec a
        ld b,a
        add a,5
        ld c,a
        ld a,(ix+RB_FLOOR)
        sub 2
        ld d,a                  ; rows floor-2 .. floor-1
        ld a,(amb_r)
        cp d
        jr c,.nx
        inc d
        inc d
        cp d
        jr nc,.nx
        ld a,(amb_c)
        cp b
        jr c,.nx
        cp c
        jr nc,.nx
        pop bc
        ret                     ; (busy: next time)
.nx:    pop bc
        ld de,RB_SIZE
        add ix,de
        djnz .rb
.go:    ld a,(amb_r)            ; swap it for its partner, in the map and on screen
        ld c,a
        ld a,(amb_c)
        call map_index
        push hl
        ld de,ROOM_MAP
        add hl,de
        ld a,(hl)
        call amb_partner
        ld (hl),a
        ld d,a
        pop hl
        ld bc,ROOM_COL
        add hl,bc
        ld e,(hl)
        ld a,(amb_r)
        ld c,a
        ld a,(amb_c)
        jp redraw_cell

; Columns B..C-1 and the rows of a box at pixel y E: carry if (amb_c, amb_r) is in it.
amb_hit:
        ld a,(amb_c)
        cp b
        ccf
        ret nc
        cp c
        ret nc
        ld a,e                  ; rows y/12 .. (y+23)/12
        ld l,a
        ld h,0
        ld de,ycell
        add hl,de
        ld b,(hl)
        ld de,23
        add hl,de
        ld c,(hl)
        ld a,(amb_r)
        cp b
        ccf
        ret nc
        dec a
        cp c
        ret
