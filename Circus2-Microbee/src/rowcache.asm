; Four balloon rings, each with four horizontal and two vertical phases.
; 9000-9FFF codes, A000-AFFF PCG banks, B000-BFFF colours.
; Original collision bitfields remain independent of these native tile caches.
cached_rows:
 xor a
 ld (cache_row),a
.row:
 ld a,(cache_row)
 ld b,a
 ld a,(nrows)
 cp b
 ret z
 ld l,b
 ld h,0
 ld de,cache_dirty
 add hl,de
 ld a,(hl)
 or a
 call nz,cache_build
 ld a,(cache_row)
 ld c,a
 ld b,0
 call slot_x
 ld l,a
 ld h,0
 ld e,l
 ld d,h
 add hl,hl
 add hl,hl
 add hl,de
 srl h
 rr l
 ld a,l
 and 6
 ld b,a
 srl h
 rr l
 srl h
 rr l
 srl h
 rr l
 ld a,l
 ld (cache_column),a
 call row_y
 add a,a
 add a,a
 ld l,a
 ld h,0
 add hl,hl
 ld de,cache_yscale
 add hl,de
 ld a,(hl)
 ld (cache_line),a
 call mark_row
 inc a
 call mark_row
 inc a
 call mark_row
 inc hl
 ld a,(hl)
 add a,b
 srl a
 ld e,a
 ld d,0
 ld hl,phase_offsets
 add hl,de
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 ld a,(cache_row)
 add a,a
 add a,a
 add a,$90
 add a,d
 ld d,a
 ld (cache_src),de
 ld a,(cache_line)
 ld l,a
 ld h,0
 add hl,hl
 ld de,rowtable
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 ld a,d
 add a,$80
 ld d,a
 ld (cache_dst),de
 ld a,3
 ld (cache_page),a
.plane:
 ld hl,(cache_src)
 ld de,(cache_dst)
 ld b,3
.line:
 push bc
 push de
 ld a,(cache_column)
 ld c,a
 ld b,0
 ex de,hl
 add hl,bc
 ex de,hl
 ld a,40
 sub c
 ld c,a
 ldir
 pop de
 ld a,(cache_column)
 or a
 jr z,.norotate
 ld c,a
 ldir
.norotate:
 ld a,40
 ld b,a
 ld a,(cache_column)
 ld c,a
 ld a,b
 sub c
 add a,e
 ld e,a
 jr nc,$+3
 inc d
 pop bc
 call rearm
 djnz .line
 ld hl,(cache_src)
 ld de,$1000
 add hl,de
 ld (cache_src),hl
 ld hl,(cache_dst)
 ld de,$0400
 add hl,de
 ld (cache_dst),hl
 ld hl,cache_page
 dec (hl)
 jr nz,.plane
 ld hl,cache_row
 inc (hl)
 jp .row

cache_build:
 ld (hl),0
 ; Configure the sprite blitter for the three cache planes.
 call cache_config
 ld a,(drawspr.base+1)
 ld h,a
 ld l,0
 ld d,h
 ld e,1
 ld bc,1023
 ld (hl),$80
 ldir
 ld a,(cache_row)
 add a,a
 add a,a
 add a,$A0
 ld h,a
 ld l,0
 ld d,h
 ld e,1
 ld bc,1023
 ld (hl),0
 ldir
 xor a
 ld (cache_phase),a
.phase:
 call cache_phase_offset
 ld b,0
 ld a,(cache_row)
 ld c,a
.slot:
 push bc
 call slot_alive
 jr z,.next
 call slot_sprite
 call cache_draw_slot
.next:
 pop bc
 inc b
 ld a,b
 cp 16
 jr nz,.slot
 ld hl,cache_phase
 inc (hl)
 ld a,(hl)
 cp 8
 jr nz,.phase
 jp cache_reset
cache_config:
 ld a,$30
 ld (drawspr.xa+1),a
 ld a,$10
 ld (drawspr.xc+1),a
 ld a,$20
 ld (drawspr.xs+1),a
 ld a,(cache_row)
 add a,a
 add a,a
 add a,$90
 ld (drawspr.base+1),a
 ret
cache_phase_offset:
 ld a,(cache_phase)
 add a,a
 ld e,a
 ld d,0
 ld hl,phase_offsets
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 ld (cache_offset),de
 ret
cache_draw_slot:
 push hl
 ld a,b
 add a,a
 add a,a
 add a,a
 ld b,a
 ld a,(cache_phase)
 and 3
 add a,b
 ld b,a
 ld a,(cache_phase)
 and 4
 ; y=0 selects phase 0; y=2 maps 8 pixels to phase 5.
 srl a
 ld c,a
 pop hl
 jp drawspr
cache_reset:
 ld hl,0
 ld (cache_offset),hl
 ld a,$80
 ld (drawspr.base+1),a
 ld a,4
 ld (drawspr.xa+1),a
 ld a,12
 ld (drawspr.xc+1),a
 ld a,8
 ld (drawspr.xs+1),a
 ret
cache_patch:
 ld (ss_spr),hl
 ld a,b
 ld (cache_slot),a
 ld a,c
 ld (cache_row),a
 call cache_config
 ld a,$F6
 ld (drawspr.transparency),a
 xor a
 ld (cache_phase),a
.loop:
 call cache_phase_offset
 ld hl,(ss_spr)
 ld a,h
 or l
 jr nz,.has
 ld hl,BAL_ERASE
.has:
 ld a,(cache_slot)
 ld b,a
 call cache_draw_slot
 ld hl,cache_phase
 inc (hl)
 ld a,(hl)
 cp 8
 jr nz,.loop
 ld a,$FE
 ld (drawspr.transparency),a
 jp cache_reset
phase_offsets: dw 0,120,240,360,480,600,720,840
