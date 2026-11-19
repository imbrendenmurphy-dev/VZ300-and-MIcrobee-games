; Native 8x10 glyph surface. No VZ pixel buffer exists.
        include "helpers.inc"
        include "random.inc"
        include "numbers.inc"

; One displayed frame. Music, sound effects and (in play) the game rules
; advance once per elapsed 50 Hz field, so a busy frame that takes two or
; three fields to draw keeps the original VZ pacing instead of slowing down.
do_frame:
        ld a,(fields)
        or a
        jr nz,.snd
        inc a
.snd:   ld b,a
.tick:  push bc
        call sound_tick
        pop bc
        djnz .tick
        call frame_wait
        call render
        jp read_input
frame_wait:
        call hw_clock
        ld a,(hw_pending)
        or a
        jr nz,.ready
.wait:  call hw_clock
        call audio_sample
        ld a,(hw_pending)
        or a
        jr z,.wait
.ready: ld (fields),a
        xor a
        ld (hw_pending),a
        ld hl,(framecount)
        inc hl
        ld (framecount),hl
        ret
audio_sample:
        ld hl,(acc1)
        ld de,(step1)
        add hl,de
        ld (acc1),hl
        ld a,h
        and $80
        rrca
        out ($02),a
        ret
read_input:
        ld hl,padkeys
        ld b,5
        call key_group
        ld a,(inp)
        cpl
        and c
        ld (inpnew),a
        ld (pad1new),a
        ld a,c
        ld (inp),a
        ld (pad1),a
        ld hl,syskeys
        ld b,6
        call key_group
        ld a,(keys)
        cpl
        and c
        ld (keysnew),a
        ld a,c
        ld (keys),a
        ld a,22
        call scan_key
        ld b,a
        ld a,(v_old)
        cpl
        and b
        ld a,b
        ld (v_old),a
        ret z
        ld a,(mode)
        or a
        ret nz
        ld a,(mono_mode)
        xor 1
        ld (mono_mode),a
        call dl_reset
        call cls_bg
        ld a,(scene_id)
        call scene_load
        jp wipe_show
key_group:
        ld c,0
        ld e,1
.key:   ld a,(hl)
        inc hl
        call scan_key
        jr z,.next
        ld a,c
        or e
        ld c,a
.next:  sla e
        djnz .key
        ret
padkeys: db 44,13,17,1,55
syskeys: db 19,16,59,24,14,3
check_start:
        ld a,(inpnew)
        and 16
        ret nz
        ld a,(keysnew)
        and 4
        ret

; The clean background is a cell-for-cell mirror of NATIVE in bank 5 at
; native-$8000 ($1000-$4E7F), so finding a cell's copy is one RES 7,H.
snapshot:
        ld hl,NATIVE
        ld b,0
        ld de,1000
.cell:  push de
        call save_cell
        ld de,16
        add hl,de
        pop de
        dec de
        ld a,d
        or e
        jr nz,.cell
        ret

cls_bg:
cls_vram:
        ld hl,NATIVE
        ld de,NATIVE+1
        ld bc,15999
        ld (hl),0
        ldir
        ld hl,DIRTY_LIST
        ld (dirty_end),hl
        ld hl,OLD_LIST
        ld (old_end),hl
        ld hl,NATIVE
        ld bc,1000
.loop:  call dirty_cell
        ld de,16
        add hl,de
        dec bc
        ld a,b
        or c
        jr nz,.loop
        ret
clear_erase:
        ret
dl_reset:
        call restore_old
        ld hl,drawlist
        ld (dlptr),hl
        ld (hl),255
        ret
spr_put:
dl_add:
        cp NSPR
        ret nc
        ld hl,(dlptr)
        ld (hl),a
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),0
        inc hl
        ld (hl),255
        ld (dlptr),hl
        ret
render:
        call save_dirty
        ld a,1
        ld (sprite_phase),a
        ld ix,drawlist
.loop:  call hw_clock
        ld a,(ix+0)
        cp 255
        jr z,.done
        ld b,(ix+1)
        ld c,(ix+2)
        push ix
        call sprite_draw
        pop ix
        ld de,4
        add ix,de
        jr .loop
.done:  xor a
        ld (sprite_phase),a
        jp present
wipe_show:
flush_queue:
        call save_dirty
        jp present
queue_rect:
keep_compute:
dl_pixel:
dl_text:
vb_none:
special_vblank:
        ret

; A logical x -> native pixel x (5/2), then byte column and phase.
map_x:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld e,a
        ld d,0
        add hl,de
        srl h
        rr l
pixel_x:
        ld a,l
        and 7
        ld (blit_shift),a
        REPT 3
        srl h
        rr l
        ENDR
        ld a,l
        ld (blit_x),a
        ret
sprite_draw:
        cp 46
        ret nc
        ld (sprite_id),a
        ld a,c
        cp 60
        ret nc
        add a,a
        add a,a
        add a,2
        ld (blit_y),a
        ld a,b
        call map_x
        ld a,(sprite_id)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(blit_shift)
        ld e,a
        ld d,0
        add hl,de
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,sprite_cache_table
        add hl,de
        ld a,(hl)
        inc hl
        ld c,a
        ld a,(mono_mode)
        add a,a
        add a,c
        call block_port
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,$E400
        ld bc,160
        call resident_fetch
        xor a
        ld (blit_shift),a
        ld hl,$E400
asset:
        ld a,(hl)
        inc hl
        ld (blit_w),a
        ld a,(hl)
        inc hl
        ld (blit_h),a
        ld a,(hl)
        inc hl
        ld (blit_col),a
        and 128
        ld (blit_multi),a
        ld (blit_src),hl
        xor a
        ld (blit_mode),a
        ld a,(blit_multi)
        or a
        jp nz,cached_blit
        jp blit
; Prepared X phases let the playfield's common sprite path avoid bit shifts.
; Record: colour byte + 4 pixel bytes per row.  Straight-line fast path for
; sprites wholly inside the 40 columns; the general loop handles the edge.
cached_blit:
        ld a,(blit_x)
        cp 37
        jp nc,cached_blit_clip
        ld a,(blit_y)
        cp 250
        ret nc
        ld l,a
        ld h,0
        add hl,hl
        ld de,native_rows
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,e
        and 15
        ld (cb_mod),a           ; row inside the first cell
        ld a,(blit_x)
        ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        add hl,de               ; HL = first destination byte
        ld a,(blit_y)
        ld b,a
        ld a,250
        sub b
        ld b,a
        ld a,(blit_h)
        cp 29                   ; the art is 28 rows; the last two are blank
        jr c,.h28
        ld a,28
.h28:   cp b
        jr c,.hok
        ld a,b
.hok:   ld (cb_rows),a
        ; mark the 4 x n cells covered (n = (mod+rows-1)/10 + 1)
        push hl
        ld a,l
        and $F0
        ld l,a
        ld a,(cb_mod)
        ld b,a
        ld a,(cb_rows)
        add a,b
        dec a
        call div10
        inc a
        ld c,a
.mrow:  push hl
        ld b,4
.mcol:  call sprite_mark
        ld a,l
        add a,16
        ld l,a
        jr nc,.mnc
        inc h
.mnc:   djnz .mcol
        pop hl
        ld de,640
        add hl,de
        dec c
        jr nz,.mrow
        pop hl
        ld de,(blit_src)
.row:   ld a,(de)               ; this row's colour
        inc de
        ld c,a
        push hl
        ld a,(de)
        inc de
        or a
        jr z,.s0
        or (hl)
        ld (hl),a
        ld b,l
        ld a,l
        or 14
        ld l,a
        ld (hl),c
        ld l,b
.s0:    ld a,l
        add a,16
        ld l,a
        jr nc,.c0
        inc h
.c0:    ld a,(de)
        inc de
        or a
        jr z,.s1
        or (hl)
        ld (hl),a
        ld b,l
        ld a,l
        or 14
        ld l,a
        ld (hl),c
        ld l,b
.s1:    ld a,l
        add a,16
        ld l,a
        jr nc,.c1
        inc h
.c1:    ld a,(de)
        inc de
        or a
        jr z,.s2
        or (hl)
        ld (hl),a
        ld b,l
        ld a,l
        or 14
        ld l,a
        ld (hl),c
        ld l,b
.s2:    ld a,l
        add a,16
        ld l,a
        jr nc,.c2
        inc h
.c2:    ld a,(de)
        inc de
        or a
        jr z,.s3
        or (hl)
        ld (hl),a
        ld a,l
        or 14
        ld l,a
        ld (hl),c
.s3:    pop hl
        ld a,(cb_rows)
        dec a
        ret z
        ld (cb_rows),a
        ld a,(cb_mod)
        inc a
        cp 10
        jr z,.wrap
        ld (cb_mod),a
        inc l
        jp .row
.wrap:  xor a
        ld (cb_mod),a
        ld a,l
        and $F0
        ld l,a
        push de
        ld de,640
        add hl,de
        pop de
        jp .row
; HL = cell base (kept).  Queue it for the display and, while sprites are
; being drawn, for restoring next frame.  Destroys A, DE.
sprite_mark:
        ld a,(sprite_phase)
        or a
        jr z,.old
        ld a,l
        or 13
        ld l,a
        ld a,(hl)
        or a
        jr nz,.old
        ld (hl),1
        ld de,(old_end)
        ld a,l
        and $F0
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld (old_end),de
.old:   ld a,l
        or 15
        ld l,a
        ld a,(hl)
        or a
        jr nz,.done
        ld (hl),1
        ld de,(dirty_end)
        ld a,l
        and $F0
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld (dirty_end),de
.done:  ld a,l
        and $F0
        ld l,a
        ret
cached_blit_clip:
        ld a,(blit_y)
        ld l,a
        ld h,0
        add hl,hl
        ld de,native_rows
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,e
        and 15
        add a,29
        ld b,1
.div:   sub 10
        jr c,.count
        inc b
        jr .div
.count: ld c,b
        ld a,e
        and $F0
        ld e,a
        ld a,(blit_x)
        ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        add hl,de
.markrow:
        push hl
        ld b,4
.markcol:
        ld a,h
        cp $CE
        jr c,.mark
        jr nz,.marked
        ld a,l
        cp $80
        jr nc,.marked
.mark:  call dirty_cell
.marked:ld de,16
        add hl,de
        djnz .markcol
        pop hl
        ld de,640
        add hl,de
        dec c
        jr nz,.markrow
.row:   ld a,(blit_y)
        cp 250
        ret nc
        ld l,a
        ld h,0
        add hl,hl
        ld de,native_rows
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(blit_x)
        ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        add hl,de
        ld de,(blit_src)
        ld a,(de)
        inc de
        ld (blit_col),a
        ld b,4
.pixel: ld a,(de)
        inc de
        or a
        jr z,.next
        or (hl)
        ld (hl),a
        push hl
        ld a,l
        or 14
        ld l,a
        ld a,(blit_col)
        ld (hl),a
        pop hl
.next:  ld a,l
        add a,16
        ld l,a
        jr nc,.nocarry
        inc h
.nocarry:djnz .pixel
        ld (blit_src),de
        ld hl,blit_y
        inc (hl)
        ld hl,blit_h
        dec (hl)
        jr nz,.row
        ret
blit:
        ld a,(blit_y)
        cp 250
        ret nc
        ld l,a
        ld h,0
        add hl,hl
        ld de,native_rows
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(blit_x)
        ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        add hl,de
        ld de,(blit_src)
        ld a,(blit_multi)
        or a
        jr z,.plain
        ld a,(de)
        inc de
        ld (blit_col),a
.plain: ld a,(blit_x)
        ld b,a
        ld a,40
        sub b
        ld (blit_rem),a
        ld a,(blit_w)
        ld c,a
        xor a
        ld (blit_carry),a
        ld (blit_tail),a
.byte:  ld a,(de)
        inc de
        push de
        ld e,a
        ld d,0
        ld a,(blit_shift)
        or a
        jr z,.shifted
        ld b,a
.shift: srl e
        rr d
        djnz .shift
.shifted:
        ld a,(blit_carry)
        or e
        call blit_byte
        ld a,d
        ld (blit_carry),a
        ld de,16
        add hl,de
        pop de
        dec c
        jr nz,.byte
        ld a,(blit_shift)
        or a
        jr z,.end
        ld a,1
        ld (blit_tail),a
        ld a,(blit_carry)
        call blit_byte
.end:   ld (blit_src),de
        ld hl,blit_y
        inc (hl)
        ld hl,blit_h
        dec (hl)
        jp nz,blit
        ret
blit_byte:
        push bc
        push de
        ld c,a
        ld a,(blit_rem)
        or a
        jr z,.exit
        dec a
        ld (blit_rem),a
        ld a,h
        cp $CE
        jr c,.safe
        jr nz,.exit
        ld a,l
        cp $80
        jr nc,.exit
.safe:  ld a,(blit_mode)
        cp 2
        jr z,.text
        or a
        ld a,c
        jr nz,.write
        or a
        jr z,.exit
        or (hl)
        jr .write
.text:  ld a,(blit_shift)
        ld b,a
        ld a,255
        inc b
        jr .test
.mask:  srl a
.test:  djnz .mask
        ld b,a
        ld a,(blit_tail)
        or a
        ld a,b
        jr nz,.masked
        cpl
.masked:and (hl)
        or c
.write: ld (hl),a
        call dirty_cell
        push hl
        ld a,l
        or 14
        ld l,a
        ld a,(blit_col)
        ld (hl),a
        pop hl
.exit:  pop de
        pop bc
        ret

set_ink:
        push hl
        and 3
        ld hl,text_palette
        call idx_byte
        ld (ink_fg),a
        pop hl
        ret
text_palette: db 0,15,14,11
print:
.next:  ld a,(hl)
        or a
        ret z
        push hl
        push de
        call putchar
        pop de
        pop hl
        inc hl
        inc d
        jr .next
putchar:
        push af
        xor a
        ld (blit_multi),a
        push de
        ld l,d
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        call pixel_x
        pop de
        ld a,e
        add a,a
        add a,a
        ld (blit_y),a
        pop af
        sub 32
        cp 64
        ret nc
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        REPT 4
        add hl,hl
        ENDR
        ld de,font_native
        ld a,(hud_mode)
        or a
        jr z,.font
        ld de,font_hud
.font:
        add hl,de
        ld (blit_src),hl
        ld a,1
        ld (blit_w),a
        ld a,2
        ld (blit_mode),a
        ld a,16
        ld b,a
        ld a,(hud_mode)
        or a
        ld a,b
        jr z,.height
        ld a,10
.height:
        ld (blit_h),a
        ld a,(ink_fg)
        ld (blit_col),a
        ; fast path unless the glyph is clipped by the right or bottom edge
        ld a,(blit_x)
        cp 39
        jp nc,blit
        ld a,(blit_y)
        cp 250-16
        jp nc,blit
        jp fast_char

; One 8-pixel-wide glyph (mode 2: replaces the 8 pixels it covers), any
; phase.  Colour is set once per covered cell instead of once per byte;
; about a third of the generic blitter's time.
fast_char:
        ld a,(blit_shift)
        ld (fc_shift),a
        ld b,a
        ld a,$FF
        inc b
        jr .mt
.ms:    srl a
.mt:    djnz .ms
        ld (fc_m2),a            ; keep the right part of the second byte
        cpl
        ld (fc_m1),a            ; keep the left part of the first byte
        ld a,(blit_y)
        ld l,a
        ld h,0
        add hl,hl
        ld de,native_rows
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,e
        and 15
        ld (cb_mod),a
        ld a,(blit_x)
        ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        add hl,de
        ; queue the covered cells and give them the ink
        push hl
        ld a,l
        and $F0
        ld l,a
        ld a,(cb_mod)
        ld b,a
        ld a,(blit_h)
        add a,b
        dec a
        call div10
        inc a
        ld c,a                  ; cell rows
.mrow:  push hl
        call .ink
        ld a,(fc_shift)
        or a
        jr z,.mone
        ld de,16
        add hl,de
        call .ink
.mone:  pop hl
        ld de,640
        add hl,de
        dec c
        jr nz,.mrow
        pop hl
        ld de,(blit_src)
        ld a,(blit_h)
        ld (cb_rows),a
.row:   ld a,(de)
        inc de
        push de
        ld d,a
        ld e,0
        ld a,(fc_shift)
        or a
        jr z,.ns
        ld b,a
.sh:    srl d
        rr e
        djnz .sh
.ns:    ld a,(fc_m1)
        and (hl)
        or d
        ld (hl),a
        ld a,(fc_shift)
        or a
        jr z,.one
        push hl
        ld bc,16
        add hl,bc
        ld a,(fc_m2)
        and (hl)
        or e
        ld (hl),a
        pop hl
.one:   pop de
        ld a,(cb_rows)
        dec a
        ret z
        ld (cb_rows),a
        ld a,(cb_mod)
        inc a
        cp 10
        jr z,.wrap
        ld (cb_mod),a
        inc l
        jr .row
.wrap:  xor a
        ld (cb_mod),a
        ld a,l
        and $F0
        ld l,a
        push de
        ld de,640
        add hl,de
        pop de
        jr .row
.ink:   call dirty_cell         ; HL = cell base (kept)
        push hl
        ld a,l
        or 14
        ld l,a
        ld a,(blit_col)
        ld (hl),a
        pop hl
        ret
; Cell-aligned text: A = character, D = cell column (0-39), E = cell row
; (0-24), colour byte from (cp_col).  The 8x10 glyph replaces the cell.
; About 400 T-states a character.  Keeps BC, DE, HL.
cell_putc:
        push hl
        push de
        push bc
        ld b,a
        ld c,d
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; row*40
        ld e,c
        ld d,0
        add hl,de
        REPT 4
        add hl,hl
        ENDR
        ld de,NATIVE
        add hl,de
        ex de,hl                ; DE = cell
        ld a,b
        sub 32
        cp 64
        jr c,.ok
        xor a
.ok:    ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        ld bc,font_hud
        add hl,bc
        push de
        REPT 10
        ldi
        ENDR
        pop hl
        ld a,l
        or 14
        ld l,a
        ld a,(mono_mode)        ; mono dithers by colour: keep text solid
        or a
        ld a,$0F
        jr nz,.solid
        ld a,(cp_col)
.solid: ld (hl),a
        ld a,l
        and $F0
        ld l,a
        call dirty_cell
        pop bc
        pop de
        pop hl
        ret
; HL = zero-terminated string from column D, row E (HL ends on the 0)
cell_print:
        ld a,(hl)
        or a
        ret z
        call cell_putc
        inc hl
        inc d
        jr cell_print
print2:
        jp print
print2_c:
        jp print_c
putchar2:
        jp putchar

tex_rect:
        xor a
fill_rect:
        push af
        xor a
        ld (blit_multi),a
        ; the whole screen (every info page starts this way)?
        ld a,d
        or e
        jr nz,.part
        ld a,b
        cp $20
        jr nz,.part
        ld a,c
        cp $40
        jr nz,.part
        pop af
        jp fast_cls
.part:  pop af
        push ix
        push bc
        push de
        ld (fill_value),a
        ld a,d
        add a,a
        add a,a
        call map_x
        pop de
        push de
        ld a,e
        add a,a
        add a,a
        ld (blit_y),a
        pop de
        pop bc
        ld a,b
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add a,l
        srl a
        srl a
        add a,2
        cp 41
        jr c,.w
        ld a,40
.w:     ld (fill_w),a
        ld a,c
        add a,a
        add a,a
        jr nz,.height
        ld a,250
.height:ld (fill_h),a
        call fast_fill
        pop ix
        ret

; A = value: every cell's ten rows set to it, colour 14, all queued.
fast_cls:
        push bc
        push de
        call .go
        pop de
        pop bc
        ret
.go:    ld c,a
        ld hl,NATIVE
        ld de,(dirty_end)
        ld b,0                  ; 1000 = 250 x 4
        ld a,250
.outer: push af
        ld b,4
.cell:  ld a,c
        REPT 10
        ld (hl),a
        inc l
        ENDR
        inc l
        inc l
        inc l
        inc l
        ld (hl),14
        inc l
        ld a,(hl)
        or a
        jr nz,.queued
        ld (hl),1
        ld a,l
        and $F0
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
.queued:inc hl                  ; next cell (may carry into H)
        djnz .cell
        pop af
        dec a
        jr nz,.outer
        ld (dirty_end),de
        ret

; Fill fill_w bytes (plus the shifted tail byte) x fill_h rows from
; blit_x/blit_y with fill_value, exactly as the byte blitter's mode 1 did
; (first byte v>>s, tail v<<(8-s), colour 14), but cell by cell: a full
; screen clear drops from ~3,000,000 to ~300,000 T-states.
fast_fill:
        ld a,(blit_shift)
        ld b,a
        ld a,(fill_value)
        ld (ff_mid),a
        inc b
        jr .f2
.f1:    srl a
.f2:    djnz .f1
        ld (ff_first),a
        ld a,(blit_shift)
        ld b,a
        ld a,8
        sub b
        ld b,a
        ld a,(fill_value)
.t1:    sla a
        djnz .t1
        ld (ff_tail),a
        ld a,(blit_shift)
        or a
        ld a,255
        jr z,.ti
        ld a,(fill_w)
.ti:    ld (ff_tidx),a
        ld a,(blit_shift)
        or a
        ld a,(fill_w)
        jr z,.c0
        inc a
.c0:    ld b,a
        ld a,(blit_x)
        ld c,a
        ld a,40
        sub c
        ret c
        ret z
        cp b
        jr nc,.c1
        ld b,a
.c1:    ld a,b
        ld (ff_cols),a
        ld a,(blit_y)
        ld (ff_y),a
        ld c,a
        ld a,250
        sub c
        ret c
        ret z
        ld b,a
        ld a,(fill_h)
        cp b
        jr c,.h1
        ld a,b
.h1:    add a,c
        ld (ff_y1),a
.crow:  ld a,(ff_y)
        ld hl,ff_y1
        cp (hl)
        ret nc
        ld c,a
        call div10
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,a                 ; 10 * (y / 10)
        ld b,a
        ld a,c
        sub b
        ld b,a
        ld a,10
        sub b                   ; rows left in this cell
        ld b,a
        ld a,(ff_y1)
        sub c
        cp b
        jr c,.cnt
        ld a,b
.cnt:   ld (ff_cnt),a
        ld l,c
        ld h,0
        add hl,hl
        ld de,native_rows
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(blit_x)
        ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        add hl,de
        ld a,(ff_cols)
        ld b,a
        ld c,0
.col:   push bc
        push hl
        ld a,c
        or a
        ld a,(ff_first)
        jr z,.v
        ld a,(ff_tidx)
        cp c
        ld a,(ff_tail)
        jr z,.v
        ld a,(ff_mid)
.v:     ld e,a
        ld a,(ff_cnt)
        ld b,a
        ld a,e
.w:     ld (hl),a
        inc l
        djnz .w
        ld a,l
        and $F0
        ld l,a
        call dirty_cell
        ld a,l
        or 14
        ld l,a
        ld (hl),14
        pop hl
        ld de,16
        add hl,de
        pop bc
        inc c
        djnz .col
        ld a,(ff_y)
        ld hl,ff_cnt
        add a,(hl)
        ld (ff_y),a
        jp .crow

draw_piece:
        push ix
        ld a,(ix+PC_X)
        call map_x
        ld a,(ix+PC_Y)
        add a,a
        add a,a
        sub 2
        ld (blit_y),a
        ld a,(ix+PC_T)
        ld (piece_t),a
        ld hl,food_table
        call idx_word
        ; resting/falling ingredients sit on even pixel phases: use the
        ; pre-shifted copies unless clipped or at an odd phase
        ld a,(blit_shift)
        rrca
        jr c,.slow
        ld a,(blit_x)
        cp 35
        jr nc,.slow
        ld a,(blit_y)
        cp 243
        jr nc,.slow
        call piece_fast
        pop ix
        ret
.slow:  call asset
        pop ix
        ret

; HL = food asset (for its colour).  Draw the pre-shifted 6x8 image.
piece_fast:
        inc hl
        inc hl
        ld a,(hl)
        ld (blit_col),a
        ld a,(piece_t)
        add a,a
        add a,a
        ld b,a
        ld a,(blit_shift)
        rrca
        add a,b                 ; type*4 + phase
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl               ; *48
        ld de,piece_shifted
        add hl,de
        ex de,hl                ; DE = source rows
        ld a,(blit_y)
        ld l,a
        ld h,0
        add hl,hl
        ld bc,native_rows
        add hl,bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld a,c
        and 15
        ld (cb_mod),a
        ld a,(blit_x)
        ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        add hl,bc
        ld a,8
        ld (cb_rows),a
.row:   push hl
        ld b,6
.col:   ld a,(de)
        inc de
        or a
        jr z,.skip
        or (hl)
        ld (hl),a
        ld c,l
        ld a,l
        or 15
        ld l,a
        ld a,(hl)
        or a
        jr nz,.marked
        ld a,l
        and $F0
        ld l,a
        call dirty_cell
        ld a,l
        or 15
        ld l,a
.marked:dec l
        ld a,(blit_col)
        ld (hl),a
        ld l,c
.skip:  ld a,l
        add a,16
        ld l,a
        jr nc,.nc
        inc h
.nc:    djnz .col
        pop hl
        ld a,(cb_rows)
        dec a
        ret z
        ld (cb_rows),a
        ld a,(cb_mod)
        inc a
        cp 10
        jr z,.wrap
        ld (cb_mod),a
        inc l
        jr .row
.wrap:  xor a
        ld (cb_mod),a
        ld a,l
        and $F0
        ld l,a
        push de
        ld de,640
        add hl,de
        pop de
        jr .row

native_title:
        ld a,9
        jp scene_load
load_backdrop:
        ld a,(playclassic)
        or a
        ld a,8
        jr nz,scene_load
        ld a,(kitchen)
scene_load:
        ld (scene_id),a
        add a,4
        call block_port
        ld (scene_port),a
        ld hl,0
        ld a,(mono_mode)
        or a
        jr z,.colour
        ld h,$40
.colour:ld de,NATIVE
        ld bc,16000
        ld a,(scene_port)
        call resident_fetch
        ld hl,DIRTY_LIST
        ld (dirty_end),hl
        jp mark_all
mark_all:
        ld hl,NATIVE
        ld bc,1000
.loop:  call dirty_cell
        ld de,16
        add hl,de
        dec bc
        ld a,b
        or c
        jr nz,.loop
        ret
background_cell:
        push hl
        push hl
        ld a,l
        or 15
        ld l,a
        ld a,(hl)
        ld (restore_flag),a
        pop hl
        ld d,h
        ld e,l
        ld bc,-NATIVE
        add hl,bc
        ld a,(mono_mode)
        or a
        jr z,.colour
        ld bc,$4000
        add hl,bc
.colour:ld bc,16
        ld a,(scene_port)
        call resident_fetch
        pop hl
        push hl
        ld a,l
        or 15
        ld l,a
        ld a,(restore_flag)
        ld (hl),a
        pop hl
        jp dirty_cell

; Restore the cells under a logical rectangle from native static tile data.
restore_rect:
        push ix
        push iy
        ld a,d
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add a,l
        srl a
        srl a
        ld (rect_x),a
        ld a,b
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add a,l
        srl a
        srl a
        add a,2
        ld (rect_w),a
        ; Ingredients are drawn 2 px above their logical row, so the clean
        ; area starts at 4*E-2 (missing that left 2-row crumbs behind falls).
        ld a,e
        add a,a
        add a,a
        sub 2
        jr nc,.ytop
        xor a
.ytop:  call div10
        ld (rect_y),a
        ld (rect_y0),a
        cp 3                    ; reaching the marquee/HUD rows: the scene
        jr nc,.ynohud           ; has no HUD, so have it redrawn this frame
        ld hl,hudflag
        set 1,(hl)
.ynohud:
        ld a,e
        add a,c                 ; first logical row below the rect
        cp 61
        jr c,.ybot
        ld a,61
.ybot:  add a,a
        add a,a
        add a,5                 ; a little slack under the rect, as before
        call div10
        inc a
        ld (rect_y1),a
        ld hl,rect_y
        sub (hl)
        ld (rect_h),a
.row:   ld a,(rect_y)
        cp 25
        jr nc,.done
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld a,(rect_x)
        ld e,a
        ld d,0
        add hl,de
        push hl
        ld de,MAP
        add hl,de
        push hl
        pop iy
        pop hl
        REPT 4
        add hl,hl
        ENDR
        ld de,NATIVE
        add hl,de
        ld a,(rect_w)
        ld b,a
.cell:  push bc
        push hl
        ld a,(iy+0)
        call background_cell
        pop hl
        ld de,16
        add hl,de
        inc iy
        pop bc
        djnz .cell
        ld hl,rect_y
        inc (hl)
        ld hl,rect_h
        dec (hl)
        jr nz,.row
.done:  pop iy
        pop ix
        ret

bankcopy_load:
        DISP $EC00
bankcopy_start:
; HL = native cell base: copy rows 0-9 and the colour byte to the bank-5
; mirror.  Bank 5 already selected.  Destroys BC, DE, HL.
save_one:
        ld d,h
        ld e,l
        res 7,d
        REPT 10
        ldi
        ENDR
        ld a,l
        or 14
        ld l,a
        ld e,a
        ld a,(hl)
        ld (de),a
        ret
save_cell:
        push hl
        push bc
        push de
        ld a,5
        out ($50),a
        call save_one
        ld a,4
        out ($50),a
        pop de
        pop bc
        pop hl
        ret
; Save every cell on the dirty list (one bank switch for the lot).
save_dirty:
        ld hl,(dirty_end)
        ld (list_stop),hl
        ld hl,DIRTY_LIST
        ld a,5
        out ($50),a
.next:  ld de,(list_stop)
        or a
        sbc hl,de
        add hl,de
        jr z,.done
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        call save_one
        pop hl
        ld a,l
        and 31
        call z,hw_clock
        jr .next
.done:  ld a,4
        out ($50),a
        ret
; Restore every cell sprites covered last frame from the bank-5 mirror,
; clear its "listed" mark and queue it for the display.
restore_old:
        ld hl,OLD_LIST
        ld a,5
        out ($50),a
.next:  ld de,(old_end)
        or a
        sbc hl,de
        add hl,de
        jr z,.done
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl                ; HL = native cell base
        ld a,l
        or 13
        ld l,a
        ld (hl),0
        and $F0
        ld l,a
        ld d,h
        ld e,l
        res 7,h
        REPT 10
        ldi
        ENDR
        ld a,l
        or 14
        ld l,a
        ld e,a
        ld a,(hl)
        ld (de),a
        ex de,hl
        inc l                   ; dirty flag
        ld a,(hl)
        or a
        jr nz,.listed
        ld (hl),1
        ld a,l
        and $F0
        ld e,a
        ld d,h
        ld hl,(dirty_end)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (dirty_end),hl
.listed:pop hl
        ld a,l
        and 31
        call z,hw_clock
        jr .next
.done:  ld a,4
        out ($50),a
        ld hl,OLD_LIST
        ld (old_end),hl
        ret
; Count real PAL fields (CRTC status bit 5 = vertical blank).
hw_clock:
        push af
        push hl
        in a,($0C)
        and $20
        ld hl,hw_vblank
        cp (hl)
        jr z,.done
        ld (hl),a
        or a
        jr z,.done
        ld hl,hw_pending
        ld a,(hl)
        cp 4
        jr nc,.done
        inc (hl)
.done:  pop hl
        pop af
        ret
resident_fetch:
        out ($50),a
        ldir
        ld a,4
        out ($50),a
        ret
bankcopy_end:
        ASSERT bankcopy_end < $EE00     ; leave 256 bytes of stack below $EF00
        ENT
