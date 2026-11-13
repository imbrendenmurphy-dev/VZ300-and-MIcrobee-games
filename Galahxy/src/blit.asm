; =====================================================================
;  blit.asm - masked sprite blitter with clipping (stack reads)
;  Record: db nph, wb, h ; then nph phases x h rows x wb x (mask, data)
;  A = frame id (<128 common table, >=128 stage table), B = x+XOFF,
;  C = y+YOFF. bl_flash <> 0 draws a yellow silhouette (hit flash).
;  Interrupts are held off while SP walks the sprite (a few hundred T).
; =====================================================================
; ---------------------------------------------------------------------
; blit: fast path for sprites wholly inside the playfield (most of them);
; anything touching an edge goes to blit_slow, which clips.
; ---------------------------------------------------------------------
blit:
            ld (bl_id),a
            ld (bl_bc),bc
            ld l,a
            ld h,0
            add hl,hl
            ld de,com_spr_tab
            bit 7,a
            jr z,.t
            ld de,STG_SPRTAB-256
.t:         add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a                  ; HL = record
            ld a,(hl)               ; nph
            inc hl
            cp 4
            jr z,.p4
            ld a,b
            and $FC
            ld b,a
.p4:        ld e,(hl)               ; wb
            inc hl
            ld d,(hl)               ; h
            inc hl
            ld a,b
            rrca
            rrca
            and $3F
            sub 8                   ; first column
            jp m,.clip
            ld (bl_c0),a
            add a,e
            cp 33
            jp nc,.clip
            ld a,c
            sub PF_TOP+YOFF
            jp c,.clip
            add a,d
            cp COPYEND-PF_TOP+1
            jp nc,.clip
            ld a,b                  ; phase
            and 3
            jr z,.ph0
            push de
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
.ph:        add hl,de
            dec a
            jr nz,.ph
            pop de
            jr .ph1
.ph0:       inc hl
            inc hl
.ph1:       push hl                 ; source
            ; dest = buffer + (y-YOFF)*32 + c0
            ld a,c
            sub YOFF
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,(bl_c0)
            or l
            ld l,a
            ld a,(bbh)
            add a,h
            ld h,a
            ; row advance and the unrolled entry for width E
            ld a,32
            sub e
            ld (.adv+1),a
            ld (.fadv+1),a
            ld a,(bl_flash)
            or a
            jr nz,.fl
            ld a,e
            add a,a
            ld c,a
            add a,a
            add a,c                 ; 6w
            cpl
            inc a                   ; -6w
            ld c,a
            ld b,$FF
            push hl
            ld hl,.blkend
            add hl,bc
            ld (.jp+1),hl
            pop hl
            pop bc                  ; source
            ld (.src+1),bc
            ld e,d                  ; rows
            di
            ld (bl_sp),sp
.src:       ld sp,0                 ; SP walks the source (rows run on contiguously)
.row:
.jp:        jp .blkend
            REPT 10
            pop bc
            ld a,(hl)
            and c
            or b
            ld (hl),a
            inc l
            ENDR
.blkend:    ld a,l
.adv:       add a,0
            ld l,a
            jr nc,.nc
            inc h
.nc:        dec e
            jp nz,.row
            ld sp,(bl_sp)
            jp re_ei
.clip:      ld a,(bl_id)
            ld bc,(bl_bc)
            jp blit_slow
            ; ---- hit-flash: opaque pixels drawn yellow
.fl:        ld a,e
            add a,a
            add a,a
            add a,a
            add a,e
            add a,e
            add a,e                 ; 11w
            cpl
            inc a
            ld c,a
            ld b,$FF
            push hl
            ld hl,.fblkend
            add hl,bc
            ld (.fjp+1),hl
            pop hl
            pop bc
            ld (.fsrc+1),bc
            ld e,d
            di
            ld (bl_sp),sp
.fsrc:      ld sp,0
.frow:
.fjp:       jp .fblkend
            REPT 10
            pop bc
            ld a,c
            cpl
            and $55
            ld b,a
            ld a,(hl)
            and c
            or b
            ld (hl),a
            inc l
            ENDR
.fblkend:   ld a,l
.fadv:      add a,0
            ld l,a
            jr nc,.fnc
            inc h
.fnc:       dec e
            jp nz,.frow
            ld sp,(bl_sp)
            jp re_ei


blit_slow:
            ld l,a
            ld h,0
            add hl,hl
            bit 7,a
            jr nz,.stg
            ld de,com_spr_tab
            jr .t
.stg:       ld de,STG_SPRTAB-256
.t:         add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a                  ; HL = record
            ld a,(hl)               ; nph
            inc hl
            ld e,(hl)               ; wb
            inc hl
            ld d,(hl)               ; h
            inc hl
            ld (bl_wb),de           ; bl_wb, bl_h
            cp 4
            jr z,.p4
            ld a,b
            and $FC                 ; byte-aligned sprite
            ld b,a
.p4:        ld a,b
            ld (bl_x),a
            ld a,c
            ld (bl_ys),a
            ld e,(hl)               ; bytes per phase
            inc hl
            ld d,(hl)
            inc hl
            ld a,b
            and 3
            jr z,.ph0
            ld b,a
.ph:        add hl,de
            djnz .ph
.ph0:       ld a,(bl_x)
            rrca
            rrca
            and $3F
            sub 8
            ld (bl_c0),a            ; signed first column
            ; ---- rows
            ld a,(bl_ys)
            ld c,0                  ; rows skipped
            cp PF_TOP+YOFF
            jr nc,.ytop
            ld b,a
            ld a,PF_TOP+YOFF
            sub b
            ld c,a
            ld a,(bl_h)
            sub c
            ret c
            ret z
            ld (bl_h),a
            ld a,PF_TOP+YOFF
.ytop:      sub YOFF
            cp 64
            ret nc
            ld (bl_y),a
            ld b,a
            ld a,64
            sub b
            ld b,a
            ld a,(bl_h)
            cp b
            jr c,.hb
            ld a,b
.hb:        ld (bl_h),a
            ld a,c
            or a
            jr z,.nsk
            ld b,a
            ld a,(bl_wb)
            add a,a
            ld e,a
            ld d,0
.sk:        add hl,de
            djnz .sk
.nsk:       ; ---- columns: skip = max(0,-c0), end = min(wb, 32-c0)
            ld a,(bl_c0)
            ld c,0
            bit 7,a
            jr z,.cl0
            neg
            ld c,a
            ld a,(bl_wb)
            cp c
            ret c
            ret z
            ld a,(bl_c0)
.cl0:       ld b,a
            ld a,32
            sub b                   ; 32-c0
            ret c
            ret z
            ld b,a
            ld a,(bl_wb)
            cp b
            jr c,.we
            ld a,b
.we:        sub c
            ret c
            ret z
            cp 11
            ret nc
            ld b,a                  ; B = width in bytes
            ld a,c
            add a,a
            add a,l
            ld l,a
            jr nc,.s2
            inc h
.s2:        push hl                 ; source
            ld a,(bl_wb)
            add a,a
            ld l,a
            ld h,0
            ld (bl_step),hl
            ld a,(bl_y)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,(bl_c0)
            add a,c
            ld e,a
            ld d,0
            add hl,de
            ld a,(bbh)
            add a,h
            ld h,a                  ; HL = dest
            ld a,32
            sub b
            ld (.adv+1),a
            ld (.adv2+1),a
            ld a,(bl_flash)
            or a
            jr nz,.fl
            ld a,b                  ; entry = blkend - 6*w
            add a,a
            ld e,a
            add a,a
            add a,e
            ld e,a
            ld d,0
            push hl
            ld hl,.blkend
            or a
            sbc hl,de
            ld (.jp+1),hl
            pop hl
            pop de                  ; DE = source
            ld a,(bl_h)
            push de
            exx
            pop hl                  ; HL' = source
            ld de,(bl_step)         ; DE' = step
            exx
            ld e,a                  ; E = rows
            di
            ld (bl_sp),sp
.row:       exx
            ld sp,hl
            add hl,de
            exx
.jp:        jp .blkend
            REPT 10
            pop bc
            ld a,(hl)
            and c
            or b
            ld (hl),a
            inc l
            ENDR
.blkend:    ld a,l
.adv:       add a,0
            ld l,a
            jr nc,.nc
            inc h
.nc:        dec e
            jp nz,.row
            ld sp,(bl_sp)
            jp re_ei
            ; ---- hit-flash variant: opaque pixels drawn yellow
.fl:        ld a,b                  ; entry = fblkend - 11*w
            add a,a
            add a,a
            add a,a                 ; 8w
            add a,b
            add a,b
            add a,b                 ; 11w
            ld e,a
            ld d,0
            push hl
            ld hl,.fblkend
            or a
            sbc hl,de
            ld (.fjp+1),hl
            pop hl
            pop de
            ld a,(bl_h)
            push de
            exx
            pop hl
            ld de,(bl_step)
            exx
            ld e,a
            di
            ld (bl_sp),sp
.frow:      exx
            ld sp,hl
            add hl,de
            exx
.fjp:       jp .fblkend
            REPT 10
            pop bc
            ld a,c
            cpl
            and $55
            ld b,a
            ld a,(hl)
            and c
            or b
            ld (hl),a
            inc l
            ENDR
.fblkend:   ld a,l
.adv2:      add a,0
            ld l,a
            jr nc,.fnc
            inc h
.fnc:       dec e
            jp nz,.frow
            ld sp,(bl_sp)
            jp re_ei

; HL = H * E (8x8 -> 16); uses B, D
mul8:
            ld d,0
            ld l,d
            ld b,8
.l:         add hl,hl
            jr nc,.n
            add hl,de
.n:         djnz .l
            ret
