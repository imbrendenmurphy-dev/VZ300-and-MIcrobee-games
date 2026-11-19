; Premium Plus banked graphics. Low 32K: game block 2; high 32K: common.
; Assets occupy expansion blocks 4..31. The first 128K stays available to
; CP/M while loading (its banked directory/file routines use the other banks).
; No DOS calls after hw_init.
ASSET_BUFFER equ $D800
BANK_COPY equ $E000

        INCLUDE "loader.inc"

runtime_copy:
        out ($50),a
        ldir
        ld a,$04
        out ($50),a
        ret
runtime_copy_end:

; HL descriptor: FF,bank port,offset,stride,width cells,height cells.
; Prepared variants: colour then mono, x=0/4, y=0/2/4/6/8.
prepared_asset:
        ld a,(blit_mode)
        or a
        jp z,prepared_tile
        push hl
        pop ix
        ld a,(ix+6)
        ld (prepared_width),a
        ld a,(ix+7)
        ld (prepared_height),a
        ld e,(ix+4)
        ld d,(ix+5)
        ld (prepared_size),de
        ld a,(blit_y)
.mod:   sub 10
        jr nc,.mod
        add a,10
        srl a
        ld b,a
        ld a,(blit_shift)
        or a
        jr z,.xzero
        ld a,b
        add a,5
        ld b,a
.xzero: ld a,(mono_mode)
        or a
        jr z,.colour
        ld a,b
        add a,10
        ld b,a
.colour:ld l,(ix+2)
        ld h,(ix+3)
        ld a,b
        or a
        jr z,.fetch
.offset:add hl,de
        djnz .offset
.fetch: ld bc,(prepared_size)
        ld a,(ix+1)
        ld de,ASSET_BUFFER
        call BANK_COPY
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
        and $F0
        ld e,a
        ld a,(blit_x)
        ld l,a
        ld h,0
        REPT 4
        add hl,hl
        ENDR
        add hl,de
        ld ix,ASSET_BUFFER
.row:   call hw_clock
        push hl
        ld a,(blit_x)
        ld (prepared_x),a
        ld a,(prepared_width)
        ld (prepared_cols),a
.cell:  ld a,(prepared_x)
        cp 40
        jp nc,.skip
        ld a,h
        cp $BE
        jr c,.inside
        jp nz,.skip
        ld a,l
        cp $80
        jp nc,.skip
.inside:
        xor a
        REPT 10,i
        or (ix+i)
        ENDR
        jp z,.skip
        call dirty_cell
        push hl
        REPT 10,i
        ld a,(ix+i)
        cpl
        and (hl)
        or (ix+10+i)
        ld (hl),a
        inc hl
        ENDR
        ld a,l
        or 14
        ld l,a
        ld a,(ix+20)
        ld c,a
        ld a,(native_flash)
        cp FLASHP
        ld a,c
        jr nz,$+4
        ld a,15
        ld (hl),a
        pop hl
.skip:  ld de,21
        add ix,de
        ld de,16
        add hl,de
        ld a,(prepared_x)
        inc a
        ld (prepared_x),a
        ld a,(prepared_cols)
        dec a
        ld (prepared_cols),a
        jp nz,.cell
        pop hl
        ld de,640
        add hl,de
        ld a,(prepared_height)
        dec a
        ld (prepared_height),a
        jp nz,.row
        ret

; Terrain is cell-aligned and fully opaque. Copy four prepared cells without
; per-pixel masking, shifting, or empty padding cells.
prepared_tile:
        push hl
        pop ix
        ld l,(ix+8)
        ld h,(ix+9)
        ld a,(mono_mode)
        or a
        jr z,.colour
        ld de,64
        add hl,de
.colour:ld a,(ix+1)
        ld de,ASSET_BUFFER
        ld bc,64
        call BANK_COPY
        ld a,(blit_y)
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
        ld de,ASSET_BUFFER
        call .pair
        push de
        ld de,608
        add hl,de
        pop de
.pair:  call hw_clock
        call .cell
.cell:  call dirty_cell
        ex de,hl
        ld bc,15
        ldir
        inc hl
        inc de
        ex de,hl
        ret

plus_title:
        call cls
        ld hl,plus_title_0
        ld a,(mono_mode)
        or a
        jr z,.colour
        ld hl,plus_title_1
.colour:ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,NATIVE
        ld bc,16000
        call BANK_COPY
        jp dirty_all

plus_hud:
        ld hl,NATIVE+1280
        ld de,plus_hud_data
        ld b,40
.cell:  push bc
        call dirty_cell
        push hl
        ex de,hl
        ld bc,10
        ldir
        ld a,(hl)
        inc hl
        ld c,a
        ex de,hl
        pop hl
        ld a,l
        or 14
        ld l,a
        ld a,(mono_mode)
        or a
        ld a,c
        jr z,$+4
        ld a,15
        ld (hl),a
        inc hl
        inc hl
        pop bc
        djnz .cell
        ret

; ---- title options readout ----
; D/T/L show "SKILL NORMAL  TRAINER OFF  START 1-4" in place of the bottom
; "PRESS FIRE TO START" row for about three seconds, then the row is restored
; from the title bitmap in banked RAM. Cell flag bytes (offset 15) are never
; overwritten, so the dirty lists stay consistent.
OPT_ROW equ NATIVE+23*640
OPT_TEXT_Y equ 59               ; text row whose native y is 230 (cell row 23)
plus_options:
        ld a,150
        ld (opt_show),a
        ld hl,OPT_ROW+16        ; columns 1..38: keep the marquee bulbs
        ld b,38
.clr:   call dirty_cell
        push bc
        push hl
        ld b,10
        xor a
.z:     ld (hl),a
        inc hl
        djnz .z
        inc hl
        inc hl
        inc hl
        inc hl
        ld (hl),a               ; colour byte: black
        pop hl
        ld de,16
        add hl,de
        pop bc
        djnz .clr
        xor a
        ld (text_origin),a      ; full-width text: columns 2..37
        ld a,1
        call fe_txt
        ld hl,s_opt_diff
        ld b,2
        ld c,OPT_TEXT_Y
        call draw_str
        ld a,(diff)
        add a,a
        ld hl,diff_names
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,3
        call fe_txt
        ld b,8
        ld c,OPT_TEXT_Y
        call draw_str
        ld a,1
        call fe_txt
        ld hl,s_opt_train
        ld b,16
        ld c,OPT_TEXT_Y
        call draw_str
        ld a,3
        call fe_txt
        ld hl,s_opt_on
        ld a,(trainer)
        or a
        jr nz,$+5
        ld hl,s_opt_off
        ld b,24
        ld c,OPT_TEXT_Y
        call draw_str
        ld a,1
        call fe_txt
        ld hl,s_opt_start
        ld b,29
        ld c,OPT_TEXT_Y
        call draw_str
        ld a,3
        call fe_txt
        ld hl,TEXT_POS+OPT_TEXT_Y*64+35
        ld a,(startst)
        call stage_label
        ld a,4
        ld (text_origin),a
        ret
s_opt_on:  db $0F,$0E,$00,$FF   ; "ON "
s_opt_off: db $0F,$06,$06,$FF   ; "OFF"

; Restore title cell rows 23-24 from the bitmap in banked RAM.
plus_title_rows:
        ld hl,plus_title_0
        ld a,(mono_mode)
        or a
        jr z,.colour
        ld hl,plus_title_1
.colour:ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,OPT_ROW-NATIVE
        add hl,de
        ld de,ASSET_BUFFER
        ld bc,1280
        call BANK_COPY
        ld hl,ASSET_BUFFER
        ld de,OPT_ROW
        ld b,80
.cell:  ex de,hl
        call dirty_cell
        ex de,hl
        push bc
        ld bc,15
        ldir
        inc hl
        inc de
        pop bc
        djnz .cell
        ret

plus_title_anim:
        call opt_keys
        ld a,(opt_show)         ; options readout times out
        or a
        jr z,.keys
        dec a
        ld (opt_show),a
        call z,plus_title_rows
.keys:  ld a,13
        call scan_key
        ld b,a
        ld a,(mono_key)
        cpl
        and b
        ld a,b
        ld (mono_key),a
        jr z,.animate
        xor a
        ld (opt_show),a         ; full redraw replaces any options readout
        ld a,(mono_mode)
        xor 1
        ld (mono_mode),a
        jp plus_title
.animate:
        ; Marquee bulbs chase along the top and bottom edges in PCG.
        ld a,(frame_cnt)
        and 7
        ret nz
        ld hl,NATIVE
        ld b,40
.bulb:  push bc
        push hl
        ld a,l
        or 14
        ld l,a
        ld a,(mono_mode)
        or a
        ld a,15
        jr nz,.ink
        ld a,(hl)
        xor 2
.ink:   ld (hl),a
        pop hl
        call dirty_cell
        ld de,16
        add hl,de
        pop bc
        djnz .bulb
        ret

