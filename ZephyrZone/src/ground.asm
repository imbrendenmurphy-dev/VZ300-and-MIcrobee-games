; =====================================================================
;  ground.asm - sky, panorama and the perspective checkerboard
;  Each ground row d (1 = just below the horizon) copies 32 bytes out of
;  a precomputed strip (tools/tables.py) at a pixel offset:
;    o = (floor(d*cf/256) + K_d) mod d        cf = frac(camx/64)
;    o += half_d   when bit 6 of (Z_d + zs) is set (the checker's z parity)
;  The strip has 4 pre-shifted versions so any pixel offset is one copy.
;  Rows d <= 10 are the horizon haze band (stripes + dither, no parity).
;  Must run with mapping 7 (bank 3 tables, world panorama in upper 1).
; =====================================================================

render_bg:
            call bb_wait            ; (last frame's bottom half still to copy?)
            ; ---- sky: rows from the top of last frame's drawing to the panorama
            ld a,(hz)
            sub PANH
            ld (dirty_top),a        ; this frame draws from the panorama down
            ld c,a                  ; first panorama row
            ld a,(dirty_prev)
            cp c
            jr nc,.nosky            ; nothing above the panorama to restore
            ld b,a                  ; first sky row
            ld a,c
            sub b
            ld (bg_n),a
            ; HL = end of row b (fill backwards with PUSH)
            ld l,b
            ld h,0
            inc l
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,BB
            add hl,de
            ld a,(sky_byte)
            ld e,a
            ld d,a
            ld a,(bg_n)
            ld b,a
            di
            ld (bg_sp),sp
.sk:        ld sp,hl
            REPT 16
            push de
            ENDR
            ld sp,32
            add hl,sp
            djnz .sk
            ld sp,(bg_sp)
            ld a,(intoff)
            or a
            jr nz,.nosky
            ei
.nosky:
            ; ---- panorama rows hz-12 .. hz-1, scrolled by camx/4
            ld a,(pano_x)
            ld c,a
            rrca
            rrca
            and $3F                 ; byte offset
            ld e,a
            ld d,0
            ld hl,(W_PANO)
            add hl,de
            bit 1,c
            jr z,.ph0
            ld de,PANH*96
            add hl,de
.ph0:       push hl
            ld a,(hz)
            sub PANH
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,BB
            add hl,de
            ex de,hl
            pop hl
            ld b,PANH
.pr:        push bc
            REPT 32
            ldi
            ENDR
            ld bc,96-32
            add hl,bc
            pop bc
            djnz .pr
            call maybe_ei
            ; ---- ground rows
            ld a,(hz)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,BB
            add hl,de
            ld (gr_dst),hl
            ld a,(zs)
            ld (gr_zs+1),a
            exx
            ld de,0                 ; acc = d * cf
            ld a,(cam_cf)
            ld c,a
            ld a,(hz)
            neg
            add a,64
            ld b,a                  ; rows
            exx
            ld hl,GROW
gr_row:
            exx
            ld a,e
            add a,c
            ld e,a
            ld a,d
            adc a,0
            ld d,a                  ; A = floor(d*cf/256)
            exx
            add a,(hl)              ; + K
            inc l
            cp (hl)
            jr c,.w
            sub (hl)                ; mod d
.w:         inc l
            ld c,a                  ; o
            ld b,(hl)               ; half
            inc l
            ld a,(hl)               ; Z_d low byte
            inc l
gr_zs:      add a,0                 ; + zs (self-modified)
            and $40
            ld a,c
            jr z,.np
            add a,b
.np:        ld c,a
            and 3
            add a,a
            add a,l
            ld l,a
            ld e,(hl)
            inc l
            ld d,(hl)               ; strip base for this phase
            ld a,c
            rrca
            rrca
            and $3F
            add a,e
            ld e,a
            jr nc,.nc
            inc d
.nc:        ld a,l                  ; next entry (16-byte aligned)
            or 15
            inc a
            ld l,a
            jr nz,.np2
            inc h
.np2:       push hl
            ex de,hl
            ld de,(gr_dst)
            REPT 32
            ldi
            ENDR
            ld (gr_dst),de
            pop hl
            ld a,(intoff)           ; field sync over? interrupts back on
            or a
            call nz,maybe_ei
            exx
            dec b
            exx
            jp nz,gr_row
            ret


