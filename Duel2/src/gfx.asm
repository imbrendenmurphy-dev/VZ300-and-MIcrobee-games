; =====================================================================
;  DUEL II - graphics: theatre recolouring, masked sprite blitter with
;  wrap-around, pixels, clouds (drawn over everything, so planes hide
;  under them as in the original)
; =====================================================================

; ---------------------------------------------------------------------
; build_frames: make the physical-colour copies of every frame for the
; theatre map in tmap (4 physical colours for logical 0..3). Frames with
; map 1 (the second plane) get colours 1 and 2 swapped.
; ---------------------------------------------------------------------
build_frames:
        ld hl,RMAP0
        call .table
        ld a,(tmap+1)
        ld b,a
        ld a,(tmap+2)
        ld (tmap+1),a
        ld a,b
        ld (tmap+2),a
        ld hl,RMAP1
        call .table
        ld a,(tmap+1)           ; swap back
        ld b,a
        ld a,(tmap+2)
        ld (tmap+1),a
        ld a,b
        ld (tmap+2),a
        ; frames
        ld hl,SPRWORK
        ld (bw_dst),hl
        ld hl,frametab
        ld de,frames_ram
        ld b,NFRAMES
.f:     push bc
        ld a,(hl)               ; ox
        ld (de),a
        inc hl
        inc de
        ld a,(hl)               ; oy
        ld (de),a
        inc hl
        inc de
        ld a,(hl)               ; map
        inc hl
        or a
        ld a,RMAP0/256
        jr z,.m0
        ld a,RMAP1/256
.m0:    ld (bw_map),a
        ld b,4
.s:     push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld hl,(bw_dst)
        ex de,hl                ; DE = dst, HL = frames_ram slot
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        push hl
        ld h,b
        ld l,c                  ; HL = source block
        call .copy
        ld (bw_dst),de
        pop de                  ; next frames_ram slot
        pop hl
        pop bc
        djnz .s
        pop bc
        djnz .f
        ret
; copy one block HL -> DE, recolouring data bytes through table (bw_map)
.copy:  ld a,(hl)
        ld (de),a
        inc hl
        inc de
        ld c,a
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        ld b,a
        xor a
.mul:   add a,c
        djnz .mul
        ld b,a                  ; pairs (w*h <= 255)
.p:     ld a,(hl)               ; mask
        ld (de),a
        inc hl
        inc de
        cpl
        ld c,a
        ld a,(hl)
        inc hl
        push hl
        ld l,a
        ld a,(bw_map)
        ld h,a
        ld a,(hl)
        and c
        pop hl
        ld (de),a
        inc de
        djnz .p
        ret
; HL = 256-byte table to fill from tmap
.table: ld c,0
.t:
        ld a,c
        and 3
        call .lk
        ld e,a                  ; pixel 3 (bits 1..0)
        ld a,c
        rrca
        rrca
        and 3
        call .lk
        rlca
        rlca
        or e
        ld e,a                  ; pixel 2
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and 3
        call .lk
        rlca
        rlca
        rlca
        rlca
        or e
        ld e,a                  ; pixel 1
        ld a,c
        rlca
        rlca
        and 3
        call .lk
        rrca
        rrca
        or e                    ; pixel 0 (bits 7..6)
        ld (hl),a
        inc l
        inc c
        jr nz,.t
        ret
.lk:    push hl
        ld hl,tmap
        add a,l
        ld l,a
        jr nc,.lk1
        inc h
.lk1:   ld a,(hl)
        pop hl
        ret

; ---------------------------------------------------------------------
; blit: A = frame, B = x (0..127), C = arena y (0..57)
; masked draw into FBUF with wrap-around in both directions; marks the
; spans dirty and for erasing next frame
; ---------------------------------------------------------------------
blit:
        push iy
        call .go
        pop iy
        ret
.go:    ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl               ; *10
        ld de,frames_ram
        add hl,de
        ld a,(hl)               ; ox
        add a,b
        and 127
        ld b,a
        inc hl
        ld a,(hl)               ; oy
        add a,c
        call wrap_y
        ld (bl_y),a
        inc hl
        ld a,b
        and 3
        add a,a
        add a,l
        ld l,a
        jr nc,.n1
        inc h
.n1:    ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = block
        ld a,b
        rrca
        rrca
        and 31
        ld (bl_col),a
        ld a,(de)
        ld (bl_w),a
        inc de
        ld a,(de)
        ld (bl_h),a
        inc de
        call span_of            ; bl_lo / bl_hi
.row:   call fs_poll
        ld a,(bl_y)
        add a,ARENA_TOP
        ld l,a
        call mark_row_obj
        ld h,rowlo/256
        ld a,(hl)
        ld iyl,a
        set 6,l
        ld a,(hl)
        add a,FBUF/256
        ld h,a
        ld a,(bl_col)
        ld c,a
        ld a,(bl_w)
        ld b,a
.byte:  ld a,c
        and 31
        or iyl
        ld l,a
        ld a,(de)               ; mask
        and (hl)
        inc de
        ex de,hl
        or (hl)                 ; data
        ex de,hl
        ld (hl),a
        inc de
        inc c
        djnz .byte
        ld a,(bl_y)
        inc a
        cp ARENA_H
        jr c,.y1
        xor a
.y1:    ld (bl_y),a
        ld a,(bl_h)
        dec a
        ld (bl_h),a
        jr nz,.row
        ret

; A = arena y possibly out of range by a little (signed) -> wrapped 0..57
wrap_y:
        bit 7,a
        jr nz,.neg
.pos:   cp ARENA_H
        ret c
        sub ARENA_H
        jr .pos
.neg:   add a,ARENA_H
        bit 7,a
        jr nz,.neg
        jr .pos

; bl_col, bl_w -> bl_lo, bl_hi (whole row if it wraps)
span_of:
        ld a,(bl_col)
        ld (bl_lo),a
        ld b,a
        ld a,(bl_w)
        add a,b
        dec a
        cp 32
        jr c,.ok
        xor a
        ld (bl_lo),a
        ld a,31
.ok:    ld (bl_hi),a
        ret

; L = screen row: merge bl_lo/bl_hi into the dirty and erase tables
mark_row_obj:
        ld h,DLO/256
        ld a,(hl)
        inc a
        call z,dq_push
        ld a,(bl_lo)
        cp (hl)
        jr nc,.a
        ld (hl),a
.a:     set 7,l
        cp (hl)
        jr nc,.b
        ld (hl),a
.b:     set 6,l
        ld a,(bl_hi)
        cp (hl)
        jr c,.c
        ld (hl),a
.c:     res 7,l
        cp (hl)
        jr c,.d
        ld (hl),a
.d:     res 6,l
        ret
; same, dirty table only
mark_row_d:
        ld h,DLO/256
        ld a,(hl)
        inc a
        call z,dq_push
        ld a,(bl_lo)
        cp (hl)
        jr nc,.a
        ld (hl),a
.a:     set 6,l
        ld a,(bl_hi)
        cp (hl)
        jr c,.c
        ld (hl),a
.c:     res 6,l
        ret

; ---------------------------------------------------------------------
; plot: B = x, C = arena y, E = physical colour
; ---------------------------------------------------------------------
plot:
        ld a,b
        rrca
        rrca
        and 31
        ld (bl_lo),a
        ld (bl_hi),a
        ld d,a
        ld a,c
        add a,ARENA_TOP
        ld l,a
        push de
        call mark_row_obj
        pop de
        ld h,rowlo/256
        ld a,(hl)
        or d
        ld c,a
        set 6,l
        ld a,(hl)
        add a,FBUF/256
        ld h,a
        ld l,c
        ld a,b
        and 3
        ld c,a
        ld a,3
        sub c
        ld d,e                  ; colour
        jr z,.s0
.sh:    rlc d
        rlc d
        dec a
        jr nz,.sh
.s0:    ld a,c
        push hl
        ld hl,pixtab
        add a,l
        ld l,a
        ld a,(hl)
        pop hl
        and (hl)
        or d
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; clouds.  cloud slot (CL_SIZE bytes):
;   +0 x (8.8, high byte = left pixel 0..127)  +2 vx (8.8 signed)
;   +4 y (arena row of top)  +5 shape  +6 fill byte  +7 on
; ---------------------------------------------------------------------
CL_X    equ 0
CL_VX   equ 2
CL_Y    equ 4
CL_SHAPE equ 5
CL_FILL equ 6
CL_ON   equ 7
CL_SIZE equ 8
MAXCL   equ 6

; HL -> cloudtab entry for shape A
cloud_ent:
        ld l,a
        ld h,0
        add hl,hl
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de               ; *10
        ld de,cloudtab
        add hl,de
        ret

; draw every cloud row that crosses a dirty span
draw_clouds:
        ld ix,clouds
        ld b,MAXCL
.c:     push bc
        ld a,(ix+CL_ON)
        or a
        call nz,draw_cloud
        ld de,CL_SIZE
        add ix,de
        pop bc
        djnz .c
        ret
draw_cloud:
        ld a,(ix+CL_SHAPE)
        call cloud_ent
        ld a,(ix+CL_X+1)
        and 3
        add a,a
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = mask block
        ld a,(ix+CL_X+1)
        rrca
        rrca
        and 31
        ld (bl_col),a
        ld a,(de)
        ld (bl_w),a
        inc de
        ld a,(de)
        ld (bl_h),a
        inc de
        ld a,(ix+CL_FILL)
        ld (bl_fill),a
        ld a,(bl_col)
        ld b,a
        ld a,(bl_w)
        add a,b
        dec a
        ld (bl_end),a           ; may exceed 31 (wraps)
        ld a,(ix+CL_Y)
        ld (bl_y),a
.row:   call fs_poll
        ld a,(bl_y)
        add a,ARENA_TOP
        ld l,a
        ld h,DLO/256
        ld a,(hl)               ; lo
        set 6,l
        ld c,(hl)               ; hi
        res 6,l
        cp c
        jr z,.chk
        jr nc,.skip             ; clean row
.chk:   ld b,a                  ; B = dirty lo, C = dirty hi
        ld a,(bl_end)
        cp 32
        jr nc,.whole            ; wrapping cloud: whole row
        cp b
        jr c,.skip              ; dirty span starts after the cloud
        ld a,(bl_col)
        ld (bl_s),a
        cp c
        jr z,.ov
        jr nc,.skip             ; dirty span ends before the cloud
.ov:    ; draw only the overlap: s = max(lo,col), e = min(hi,end)
        ld a,b
        ld hl,bl_s
        cp (hl)
        jr c,.s1
        ld (hl),a
.s1:    ld a,(bl_end)
        cp c
        jr c,.e1
        ld a,c
.e1:    sub (hl)
        inc a
        ld b,a                  ; count
        ld a,(bl_col)
        neg
        add a,(hl)              ; skip = s - col
        push de
        add a,e
        ld e,a
        jr nc,.d1
        inc d
.d1:    ld a,(hl)
        ld c,a
        jr .go
.whole: push de
        ld a,(bl_col)
        ld c,a
        ld a,(bl_w)
        ld b,a
.go:    ld a,(bl_y)
        add a,ARENA_TOP
        ld l,a
        ld h,rowlo/256
        ld a,(hl)
        ld iyl,a
        set 6,l
        ld a,(hl)
        add a,FBUF/256
        ld h,a
.byte:  ld a,c
        and 31
        or iyl
        ld l,a
        ld a,(de)
        inc de
        cp $FF
        jr z,.nb
        push bc
        ld b,a
        and (hl)
        ld c,a
        ld a,b
        cpl
        ld b,a
        ld a,(bl_fill)
        and b
        or c
        ld (hl),a
        pop bc
.nb:    inc c
        djnz .byte
        pop de
.skip:  ld a,(bl_w)
        add a,e
        ld e,a
        jr nc,.next
        inc d
.next:  ld a,(bl_y)
        inc a
        cp ARENA_H
        jr c,.y1
        xor a
.y1:    ld (bl_y),a
        ld a,(bl_h)
        dec a
        ld (bl_h),a
        jp nz,.row
        ret

; mark_cloud: IX = cloud, A = left pixel; objmark decides (old box -> erase)
mark_cloud:
        ld (mc_x),a
        ld a,(ix+CL_SHAPE)
        call cloud_ent
        ld de,8
        add hl,de
        ld a,(hl)               ; width px
        add a,6
        rrca
        rrca
        and 63
        ld (bl_w),a
        inc hl
        ld a,(hl)
        ld (bl_h),a
        ld a,(mc_x)
        rrca
        rrca
        and 31
        ld (bl_col),a
        call span_of
        ld a,(ix+CL_Y)
        ld (bl_y),a
.r:     ld a,(bl_y)
        add a,ARENA_TOP
        ld l,a
        ld a,(objmark)
        or a
        jr z,.d
        call mark_row_obj
        jr .n
.d:     call mark_row_d
.n:     ld a,(bl_y)
        inc a
        cp ARENA_H
        jr c,.y1
        xor a
.y1:    ld (bl_y),a
        ld a,(bl_h)
        dec a
        ld (bl_h),a
        jr nz,.r
        ret

; move clouds by their own speed + the wind; redraw any that shifted.
; One cloud per tick (round robin) moves 6 ticks' worth, so at most one
; cloud box is redrawn per tick.
move_clouds:
        ld a,(clrr)
        inc a
        cp MAXCL
        jr c,.r
        xor a
.r:     ld (clrr),a
        ld ix,clouds
        or a
        jr z,.c
        ld b,a
        ld de,CL_SIZE
.f:     add ix,de
        djnz .f
.c:     ld a,(ix+CL_ON)
        or a
        ret z
        ld a,(ix+CL_X+1)
        ld (mc_old),a
        ld e,(ix+CL_VX)
        ld d,(ix+CL_VX+1)
        ld hl,(wind)
        add hl,de               ; speed per tick
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl               ; * 6
        ld e,(ix+CL_X)
        ld d,(ix+CL_X+1)
        add hl,de
        ld a,h
        and 127
        ld h,a
        ld (ix+CL_X),l
        ld (ix+CL_X+1),h
        ld a,(mc_old)
        cp h
        ret z
        ld a,1
        ld (objmark),a
        ld a,(mc_old)
        call mark_cloud         ; old box: erase
        xor a
        ld (objmark),a
        ld a,(ix+CL_X+1)
        jp mark_cloud           ; new box: draw
; force a redraw of cloud IX (fill changed)
touch_cloud:
        xor a
        ld (objmark),a
        ld a,(ix+CL_X+1)
        jp mark_cloud
