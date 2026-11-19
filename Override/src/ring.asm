; =====================================================================
;  ring.asm - the 4-phase ring buffer (low bank 3, $4000-$5FFF)
;  Phase p, ring row (Y & 63), ring column (X & 31) holds the deck's
;  pixels 4X+p .. 4X+p+3 of row Y. Valid area: columns ring_vx ..
;  ring_vx+31, rows ring_vy .. ring_vy+53.
;  Tileset layout: [sub-row 0..5][tile 0..63][2 bytes]; tset is page
;  aligned, so every sub-row is one half page.
; =====================================================================

; tile sub-row base: A = sub-row -> H = page, L = 0 / 128 (rb_base)
sr_base:
            ld l,a
            srl a
            ld h,a
            ld a,(tset+1)
            add a,h
            ld h,a
            ld a,l
            rrca
            and $80
            ld l,a
            ret

; ---------------------------------------------------------------------
; render_blk: B = byte column X, C = first row Y, A = rows (> 0)
; renders all four phases. Trashes everything except IY.
; ---------------------------------------------------------------------
render_blk:
            ld (rb_n),a
            ld a,b
            ld (rb_x),a
            ld a,c
            and 63
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,b
            and 31
            or l
            ld l,a
            ld a,h
            add a,HIGH(RING)
            ld h,a
            ld (rb_ring),hl
            ld a,c
            ld e,0
.dv:        cp 6
            jr c,.dd
            sub 6
            inc e
            jr .dv
.dd:        ld (rb_sr),a
            ld l,e
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,b
            srl a
            add a,l
            ld l,a
            ld de,MAP
            add hl,de
            ld (rb_map),hl
            call rb_tiles
            ld hl,(rb_ring)
.row:       exx
            ld a,(de)               ; w
            ex af,af'
            ld a,(hl)               ; u
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            exx
            ld c,a
            ex af,af'
            ld b,a
            call emit4
            ld a,(rb_n)
            dec a
            ret z
            ld (rb_n),a
            ld a,l
            add a,32
            ld l,a
            jr nc,.nc
            inc h
            ld a,h
            cp HIGH(RING)+8
            jr nz,.nc
            ld h,HIGH(RING)
.nc:        ld a,(rb_sr)
            inc a
            cp 6
            jr z,.nt
            ld (rb_sr),a
            jr .row
.nt:        xor a
            ld (rb_sr),a
            push hl
            ld hl,(rb_map)
            ld de,MAPW
            add hl,de
            ld (rb_map),hl
            call rb_tiles
            pop hl
            jr .row

; C = u, B = w, HL = phase-0 ring byte: write the four phases (keeps HL)
emit4:
            ld (hl),c               ; phase 0: u
            ld a,b
            rlca
            rlca
            and 3
            ld e,a
            ld a,c
            add a,a
            add a,a
            or e
            set 3,h
            ld (hl),a               ; phase 1: u<<2 | w>>6
            ld a,b
            rrca
            rrca
            rrca
            rrca
            and $0F
            ld e,a
            ld a,c
            add a,a
            add a,a
            add a,a
            add a,a
            or e
            res 3,h
            set 4,h
            ld (hl),a               ; phase 2: u<<4 | w>>4
            ld a,b
            rrca
            rrca
            and $3F
            ld e,a
            ld a,c
            rrca
            rrca
            and $C0
            or e
            set 3,h
            ld (hl),a               ; phase 3: u<<6 | w>>2
            ld a,h
            and $E7
            ld h,a
            ret

; set the alternate registers for the tile row at rb_map, sub-row rb_sr:
; HL' = u pointer, DE' = w pointer, BC' = 128
rb_tiles:
            ld a,(rb_sr)
            call sr_base            ; HL = sub-row base (page aligned)
            ex de,hl
            ld hl,(rb_map)
            ld a,(rb_x)
            rra
            jr c,.odd
            ld a,(hl)
            add a,a
            add a,e
            ld e,a                  ; u = base + 2A, w = u + 1
            ld h,d
            ld l,e
            inc e
            jr .set
.odd:       ld a,(hl)
            add a,a
            inc a
            add a,e
            ld b,a                  ; u = base + 2A + 1
            inc hl
            ld a,(hl)
            add a,a
            add a,e
            ld e,a                  ; w = base + 2B
            ld h,d
            ld l,b
.set:       push hl
            push de
            exx
            pop de
            pop hl
            ld bc,128
            exx
            ret

; ---------------------------------------------------------------------
; render_row: A = row Y. Renders byte columns ring_vx .. ring_vx+31.
; ---------------------------------------------------------------------
render_row:
            ld c,a
            and 63
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,h
            add a,HIGH(RING)
            ld h,a
            ld (rr_ring),hl         ; phase-0 row start
            ld a,c
            ld e,0
.dv:        cp 6
            jr c,.dd
            sub 6
            inc e
            jr .dv
.dd:        call sr_base
            ld (rr_base),hl
            ld l,e
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,MAP
            add hl,de
            ld (rr_map),hl
            ld a,(ring_vx)
            ld (rr_x),a
            ld a,32
            ld (rr_n),a
.x:         ld a,(rr_x)
            ld b,a
            srl a
            ld hl,(rr_map)
            add a,l
            ld l,a
            jr nc,.m
            inc h
.m:         ld de,(rr_base)
            ld a,b
            rra
            jr c,.odd
            ld a,(hl)
            add a,a
            add a,e
            ld e,a
            ld a,(de)
            ld c,a                  ; u = A.b0
            inc e
            ld a,(de)
            ld b,a                  ; w = A.b1
            jr .emit
.odd:       ld a,(hl)
            add a,a
            inc a
            add a,e
            ld c,a                  ; offset of A.b1
            inc hl
            ld a,(hl)
            add a,a
            add a,e
            ld b,a                  ; offset of B.b0
            ld e,c
            ld a,(de)
            ld c,a                  ; u = A.b1
            ld e,b
            ld a,(de)
            ld b,a                  ; w = B.b0
.emit:      ld a,(rr_x)
            and 31
            ld hl,(rr_ring)
            or l
            ld l,a
            call emit4
            ld hl,rr_x
            inc (hl)
            ld hl,rr_n
            dec (hl)
            jr nz,.x
            ret

; ---------------------------------------------------------------------
; ring_full: render the whole window at the camera (deck entry)
; ---------------------------------------------------------------------
ring_full:
            call cam_cols
            ld (ring_vx),a
            ld a,(cam_y)
            ld (ring_vy),a
            ld a,32
            ld (rf_n),a
            ld a,(ring_vx)
            ld (rf_x),a
.c:         ld a,(rf_x)
            ld b,a
            ld a,(ring_vy)
            ld c,a
            ld a,VIEWROWS
            call render_blk
            ld hl,rf_x
            inc (hl)
            ld hl,rf_n
            dec (hl)
            jr nz,.c
            ret

; A = camera byte column (cam_x >> 2)
cam_cols:
            ld hl,(cam_x)
            srl h
            rr l
            srl h
            rr l
            ld a,l
            ret

; ---------------------------------------------------------------------
; ring_update: render what the camera move uncovered
; ---------------------------------------------------------------------
ring_update:
.h:         call maybe_ei
            call cam_cols
            ld hl,ring_vx
            cp (hl)
            jr z,.v
            jr c,.left
            ld a,(hl)
            add a,32
            ld b,a
            inc (hl)
            ld a,(ring_vy)
            ld c,a
            ld a,VIEWROWS
            call render_blk
            jr .h
.left:      dec (hl)
            ld b,(hl)
            ld a,(ring_vy)
            ld c,a
            ld a,VIEWROWS
            call render_blk
            jr .h
.v:         call maybe_ei
            ld a,(cam_y)
            ld hl,ring_vy
            cp (hl)
            ret z
            jr c,.up
            ld a,(hl)
            inc (hl)
            add a,VIEWROWS
            call render_row
            jr .v
.up:        dec (hl)
            ld a,(hl)
            call render_row
            jr .v

; ---------------------------------------------------------------------
; tile_patch: the map tile at (D = tx, E = ty) changed: re-render it in
; the ring if it is inside the valid area
; ---------------------------------------------------------------------
tile_patch:
            ld a,d
            add a,a
            dec a                   ; first byte column touched: 2tx-1
            ld (tp_x),a
            ld a,3
            ld (tp_n),a
            ld a,e
            add a,a
            add a,e
            add a,a                 ; first row: 6ty
            ld c,a
            ; clip rows 6ty..6ty+5 to ring_vy..ring_vy+53
            ld a,(ring_vy)
            ld b,a
            ld a,c
            sub b
            jr nc,.below
            add a,6                 ; tile starts above the window
            ret z
            ret nc                  ; (wholly above: offset <= -6)
            ld (tp_rn),a
            ld a,b
            ld (tp_r0),a
            jr .c
.below:     cp VIEWROWS
            ret nc
            ld e,a
            ld a,VIEWROWS
            sub e
            cp 6
            jr c,.part
            ld a,6
.part:      ld (tp_rn),a
            ld a,c
            ld (tp_r0),a
.c:         ld a,(tp_x)
            ld hl,ring_vx
            sub (hl)
            cp 32
            jr nc,.next             ; column not in the ring
            ld a,(tp_x)
            ld b,a
            ld a,(tp_r0)
            ld c,a
            ld a,(tp_rn)
            call render_blk
.next:      ld hl,tp_x
            inc (hl)
            ld hl,tp_n
            dec (hl)
            jr nz,.c
            ret

; ---------------------------------------------------------------------
; win_copy: copy the visible window from the ring into the back buffer
; (54 rows, two LDI runs a row for the column wrap), one effects sample
; a row
; ---------------------------------------------------------------------
win_copy:
            ld hl,(cam_x)
            ld a,l
            and 3
            add a,a
            add a,a
            add a,a                 ; phase * 8 = high-byte offset
            add a,HIGH(RING)
            ld (wc_ph),a
            srl h
            rr l
            srl h
            rr l
            ld a,l
            and 31
            ld (wc_s),a             ; first ring column
            ; entry points into the LDI chain
            ld c,a
            add a,a
            ld e,a
            ld d,0
            ld hl,ldi32
            add hl,de
            ld (.c1+1),hl         ; copies 32-s bytes
            ld a,32
            sub c
            add a,a
            ld e,a
            ld hl,ldi32
            add hl,de
            ld (.c2+1),hl         ; copies s bytes
            ld a,(cam_y)
            and 63
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,(wc_ph)
            add a,h
            ld h,a
            ld (wc_rs),hl           ; ring row start
            ld de,VIEWTOP
            ld a,VIEWROWS
            ld (wc_n),a
.row:       ld a,(wc_s)
            or l
            ld l,a
.c1:        call ldi32
            ld hl,(wc_rs)
.c2:        call ldi32
            ld hl,BBW-32
            add hl,de
            ex de,hl                ; next back-buffer row
            ld hl,(wc_rs)
            ld a,l
            add a,32
            ld l,a
            jr nc,.nw
            inc h
            ld a,h
            and 7
            jr nz,.nw
            ld a,h
            sub 8                   ; wrapped past row 63 of this phase
            ld h,a
.nw:        ld (wc_rs),hl
            ld a,(wc_n)
            dec a
            ld (wc_n),a
            ret z
            ld hl,snd_rd            ; one sample a row from the ring
            ld a,(hl)
            inc (hl)
            ld l,a
            ld h,HIGH(SNDBUF)
            ld a,(hl)
            ld (LATCH),a
            ld a,(hl)               ; (pads the row to the ISR's
            ld a,(hl)               ;  sample spacing, ~875 T)
            ld a,(snd_rd)
            ld a,(snd_rd)
            ld a,(snd_rd)
            ld hl,(wc_rs)
            jr .row

ldi32:      REPT 32
            ldi
            ENDR
            ret
