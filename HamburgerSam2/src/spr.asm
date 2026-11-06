; =====================================================================
;  HAMBURGER SAM II - run-time sprite build (4 pre-shifted copies of every
;  sprite, from Tennis II) and small helpers
; =====================================================================
build_sprites:
        ld hl,spr_src_start     ; sources out of the way first
        ld de,STATBG
        ld bc,spr_src_end-spr_src_start
        ldir
        xor a
        ld (bmap),a
        inc a
        ld (bmap+1),a
        inc a
        ld (bmap+2),a
        inc a
        ld (bmap+3),a
        jp build_sprites_m

; build a 256-byte recolour table at RMAP from the 4-entry map at HL
build_rmap:
        ld (mapptr),hl
        ld hl,RMAP
        ld c,0
.b:     ld b,4
        ld e,c
        ld d,0
.f:     ld a,e
        rlca
        rlca
        ld e,a
        and 3
        push hl
        push de
        ld hl,(mapptr)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        sla d
        sla d
        or d
        ld d,a
        djnz .f
        ld (hl),d
        inc l
        inc c
        jr nz,.b
        ret

; build_sprites_m: shift (4 positions) + recolour every sprite into SPRWORK,
; and fill shtab (dw base, db pw=3, db h, dw shiftsize, dw 0) for render.
build_sprites_m:
        ld hl,bmap
        call build_rmap
        ld ix,sprsrc-spr_src_start+STATBG
        ld iy,shtab
        ld de,SPRWORK
        ld b,NSPR
.spr:   push bc
        ld (iy+0),e
        ld (iy+1),d
        ld (iy+2),3
        ld a,(ix+2)
        ld (iy+3),a
        ld (rowcnt),a
        ; shift size = h*6
        ld l,a
        ld h,0
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        ld (iy+4),l
        ld (iy+5),h
        ld a,(ix+3)
        or a
        ld a,3
        jr z,.four
        ld (iy+4),0             ; single, byte-aligned copy
        ld (iy+5),0
        xor a
.four:  ld (lastsh),a
        xor a
.sh:    ld (shiftn),a
        ld l,(ix+0)
        ld h,(ix+1)
        ld a,(rowcnt)
        ld b,a
.row:   push bc
        ld a,(hl)
        ld (rowd),a
        inc hl
        ld a,(hl)
        ld (rowd+1),a
        inc hl
        ld a,(hl)
        ld (rowd+3),a
        inc hl
        ld a,(hl)
        ld (rowd+4),a
        inc hl
        xor a
        ld (rowd+2),a
        dec a
        ld (rowd+5),a
        ld a,(shiftn)
        add a,a
        jr z,.ns
        ld b,a
        push hl
.sb:    ld hl,rowd
        or a
        rr (hl)
        inc hl
        rr (hl)
        inc hl
        rr (hl)
        inc hl
        scf
        rr (hl)
        inc hl
        rr (hl)
        inc hl
        rr (hl)
        djnz .sb
        pop hl
.ns:    push hl
        ld hl,rowd
        ld b,3
.pr:    push bc
        ld a,(hl)               ; data
        inc hl
        inc hl
        inc hl
        ld c,(hl)               ; mask
        dec hl
        dec hl
        push hl
        ld h,RMAP/256
        ld l,a
        ld a,c
        cpl
        and (hl)
        pop hl
        ex de,hl
        ld (hl),c
        inc hl
        ld (hl),a
        inc hl
        ex de,hl
        pop bc
        djnz .pr
        pop hl
        pop bc
        djnz .row
        ld a,(lastsh)
        ld b,a
        ld a,(shiftn)
        cp b
        jr z,.sd
        inc a
        jr .sh
.sd:
        ld bc,4
        add ix,bc
        ld bc,8
        add iy,bc
        pop bc
        dec b
        jp nz,.spr
        ld (sprend),de
        ret


; spr_put: A = id, B = x, C = y. Skips sprites that would not fit on screen.
spr_put:
        push af
        ld a,b
        cp 120
        jr nc,.no
        pop af
        push af
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,shtab+3
        add hl,de
        ld a,64
        sub (hl)
        cp c
        jr c,.no
        pop af
        jp dl_add
.no:    pop af
        ret

; idx_byte: A = index, HL = table -> A = (HL+A)
idx_byte:
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        ret
; idx_ptr: A = index, HL = base, element size 1 -> HL = address
idx_ptr:
        add a,l
        ld l,a
        ret nc
        inc h
        ret
; idx_word: A = index, HL = table of words -> HL = word
idx_word:
        add a,a
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret
