; Native screen-code, PCG-bank and colour planes. Cached art in PCG.
MAP EQU $8000
ATTR EQU $8400
COL EQU $8800
init_video:
 xor a
 out ($08),a
 ld a,$80
 out ($1C),a
 call restore_bg
 jp present
clear_scene:
 call restore_bg
 jp present
set_theme:
 ret
restore_bg:
 call find_covered_rows
 ld hl,dirty_rows
 ld de,dirty_rows+1
 ld bc,24
 ld (hl),0
 ldir
 ld hl,$C000
 ld de,MAP
 call restore_plane
 ld hl,$C400
 ld de,ATTR
 call restore_plane
 ld hl,$C800
 ld de,COL
 ld a,(mono_mode)
 or a
 ret nz
 jp restore_plane
restore_game:
 ld a,1
 ld (restore_game_flag),a
 call restore_bg
 xor a
 ld (restore_game_flag),a
 ret
find_covered_rows:
 ld hl,covered_rows
 ld de,covered_rows+1
 ld bc,24
 ld (hl),0
 ldir
 ld a,(restore_game_flag)
 or a
 ret z
 ld a,(nrows)
 or a
 ret z
 ld b,a
 ld c,0
.row:
 push bc
 call row_y
 add a,a
 add a,a
 ld l,a
 ld h,0
 add hl,hl
 ld de,cache_yscale
 add hl,de
 ld e,(hl)
 ld d,0
 ld hl,covered_rows
 add hl,de
 ld (hl),1
 inc hl
 ld (hl),1
 inc hl
 ld (hl),1
 pop bc
 inc c
 djnz .row
 ret
restore_plane:
 ld ix,old_rows
 ld iy,covered_rows
 ld a,25
.row:
 push af
 ld a,(iy+0)
 or a
 jr nz,.skip
 ld a,(ix+0)
 or a
 jr z,.skip
 ld bc,40
 REPT 40
 ldi
 ENDR
 jr .next
.skip:
 ld bc,40
 add hl,bc
 ex de,hl
 add hl,bc
 ex de,hl
.next:
 call rearm
 inc ix
 inc iy
 pop af
 dec a
 jp nz,.row
 ret
present:
 xor a
 out ($08),a
 ld a,$80
 out ($1C),a
 ld hl,MAP
 ld de,$F000
 call upload
 ld a,$90
 out ($1C),a
 ld hl,ATTR
 ld de,$F000
 call upload
 ld a,$80
 out ($1C),a
 ld a,(mono_mode)
 or a
 jr nz,.no_colour
 ld a,$40
 out ($08),a
 ld hl,COL
 ld de,$F800
 call upload
 xor a
 out ($08),a
.no_colour:
 ld hl,dirty_rows
 ld de,old_rows
 ld bc,25
 ldir
 ld a,6
 out ($0C),a
 ld a,25
 out ($0D),a
 jp rearm
upload:
 ld ix,dirty_rows
 ld iy,old_rows
 ld a,25
.row:
 push af
 ld a,(ix+0)
 or (iy+0)
 jr z,.skip
 ld bc,40
 REPT 40
 ldi
 ENDR
 jr .next
.skip:
 ld bc,40
 add hl,bc
 ex de,hl
 add hl,bc
 ex de,hl
.next:
 call rearm
 inc ix
 inc iy
 pop af
 dec a
 jp nz,.row
 ret
mark_row:
 push hl
 push de
 ld e,a
 ld d,0
 ld hl,dirty_rows
 add hl,de
 ld (hl),1
 pop de
 pop hl
 ret
; Preserve original physics units, display at x*2.5 and y*4.
; Quantise to 2 horizontal / 5 vertical native pixels, never VZ pixels.
drawspr:
 ld a,c
 cp 62
 ret nc
 push hl
 add a,a
 add a,a
 ld e,a
 ld d,0
 ld a,e
 ld l,a
 ld h,0
 add hl,hl
 ld de,yscale
 add hl,de
 ld a,(hl)
 ld (draw_y),a
 inc hl
 ld a,(hl)
 ld c,a
 ld l,b
 ld h,0
 add hl,hl
 add hl,hl
 ld e,b
 ld d,0
 add hl,de
 srl h
 rr l
 ld a,l
 and 6
 add a,c
 ld c,a
 srl h
 rr l
 srl h
 rr l
 srl h
 rr l
 ld a,l
 ld (draw_x),a
 pop hl
.descriptor:
 ld e,c
 ld d,0
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 ex de,hl
 ld a,(hl)
 ld (draw_w),a
 inc hl
 ld a,(hl)
 ld (draw_h),a
 inc hl
.row:
 push hl
 ld a,(draw_y)
 cp 25
 jr nc,.skiprow
 call mark_row
 ld l,a
 ld h,0
 add hl,hl
 ld de,rowtable
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 ld a,(draw_x)
 add a,e
 ld e,a
 jr nc,$+3
 inc d
 push hl
 ld hl,(cache_offset)
 add hl,de
 ex de,hl
 pop hl
 ld a,d
.base: add a,$80
 ld d,a
 pop hl
 ld a,(draw_w)
 ld b,a
 ld a,(draw_x)
 ld c,a
.cell:
 ld a,c
 cp 40
 jr nc,.skipcell
 ld a,(hl)
.transparency:
 cp $80
 jr nz,.write
 inc hl
 ld a,(hl)
 or a
 dec hl
 jr z,.skipcell
.write:
 ld a,(hl)
 ld (de),a
 inc hl
 ld a,d
.xa: xor 4
 ld d,a
 ld a,(hl)
 ld (de),a
 inc hl
 ld a,d
.xc: xor 12
 ld d,a
 ld a,(hl)
 ld (de),a
 inc hl
 ld a,d
.xs: xor 8
 ld d,a
 jr .next
.skipcell:
 inc hl
 inc hl
 inc hl
.next:
 inc de
 inc c
 djnz .cell
 jr .nextrow
.skiprow:
 pop hl
 ld a,(draw_w)
 ld e,a
 add a,a
 add a,e
 ld e,a
 ld d,0
 add hl,de
.nextrow:
 ld a,(draw_y)
 inc a
 ld (draw_y),a
 ld a,(draw_h)
 dec a
 ld (draw_h),a
 jp nz,.row
 jp rearm
; A 6x9 font drawn on native 8x10 cells.
drawtext:
 ld a,b
 srl a
 srl a
 add a,b
 ld (text_x),a
 ld a,c
 ld (text_y),a
.loop:
 push hl
 ld a,(text_y)
 add a,a
 add a,a
 ld l,a
 ld h,0
 add hl,hl
 ld de,yscale
 add hl,de
 ld a,(hl)
 call mark_row
 ld l,a
 ld h,0
 add hl,hl
 ld de,rowtable
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 ld a,(text_x)
 add a,e
 ld e,a
 jr nc,$+3
 inc d
 ld a,d
 add a,$80
 ld d,a
 pop hl
.char:
 ld a,(hl)
 or a
 ret z
 inc hl
 push hl
 sub 32
 ld l,a
 ld h,0
 add hl,hl
 ld bc,font_ptrs
 add hl,bc
 ld a,(hl)
 inc hl
 ld h,(hl)
 ld l,a
 ld a,(hl)
 inc hl
 ld h,(hl)
 ld l,a
 inc hl
 inc hl
 ld a,(hl)
 ld (de),a
 inc hl
 set 2,d
 ld a,(hl)
 ld (de),a
 res 2,d
 set 3,d
 ld a,15
 ld (de),a
 res 3,d
 inc de
 pop hl
 jr .char

textc:
 push hl
 ld b,0
.len: ld a,(hl)
 or a
 jr z,.ready
 inc hl
 inc b
 jr .len
.ready:
 ld a,40
 sub b
 srl a
 ld (text_x),a
 ld a,c
 ld (text_y),a
 pop hl
 jp drawtext.loop
bigc:
 call strlen
 cp 20
 jp nc,textc
 ld b,a
 ld a,20
 sub b
 ld (text_x),a
 push hl
 ld a,c
 add a,a
 add a,a
 ld l,a
 ld h,0
 add hl,hl
 ld de,yscale
 add hl,de
 ld a,(hl)
 ld (big_y),a
 pop hl
.char:
 ld a,(hl)
 or a
 ret z
 inc hl
 push hl
 sub 32
 ld l,a
 ld h,0
 add hl,hl
 ld de,bigfont_ptrs
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 ex de,hl
 ld a,(text_x)
 ld (draw_x),a
 ld a,(big_y)
 ld (draw_y),a
 ld c,0
 call drawspr.descriptor
 ld hl,text_x
 inc (hl)
 inc (hl)
 pop hl
 jr .char
strlen:
 push hl
 push bc
 ld b,0
.loop: ld a,(hl)
 or a
 jr z,.done
 inc hl
 inc b
 jr .loop
.done: ld a,b
 pop bc
 pop hl
 ret

rowtable:
Y DEFL 0
 REPT 25
 dw Y*40
Y DEFL Y+1
 ENDR
yscale:
Y DEFL 0
 REPT 256
 IF (Y%10)>=6
 db Y/10,16
 ELSE
 db Y/10,((Y%10)/3)*8
 ENDIF
Y DEFL Y+1
 ENDR

cache_yscale:
Y DEFL 0
 REPT 256
 db Y/10,((Y%10)/5)*8
Y DEFL Y+1
 ENDR

; Velvet closes from the wings after an act, using this act's PCG velvet.
curtain_wipe:
 ld a,($C000+15*40+1)
 ld (curtain_column.code+1),a
 ld a,($C400+15*40+1)
 ld (curtain_column.attr+1),a
 ld a,($C800+15*40+1)
 ld (curtain_column.colour+1),a
 ld hl,dirty_rows
 ld de,dirty_rows+1
 ld bc,24
 ld (hl),1
 ldir
 ld c,0
.pair:
 push bc
 ld a,c
 call curtain_column
 pop bc
 push bc
 ld a,39
 sub c
 call curtain_column
 call present
 ld a,1
 call waitframes
 pop bc
 inc c
 ld a,c
 cp 20
 jr nz,.pair
 ret
curtain_column:
 ld l,a
 ld h,$80
 ld b,25
.row:
.code: ld (hl),$80
 set 2,h
.attr: ld (hl),0
 res 2,h
 set 3,h
.colour: ld (hl),$19
 res 3,h
 ld de,40
 add hl,de
 djnz .row
 ret
