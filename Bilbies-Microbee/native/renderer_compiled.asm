        DEFINE COMPILED_ACTORS 1
n_patch_buffer EQU $E600
        INCLUDE "common.asm"
n_sprites:
        ld a,(n_anim) : add a,16 : call n_bank
        ld a,(n_mono) : or a : ld a,8 : jr z,.ink_ready
        ld a,15
.ink_ready: ld (n_actor_ink),a
        ld a,(n_map_init) : or a : jr nz,.initialized
        ld hl,$9000 : ld de,$9001 : ld bc,1119 : ld (hl),$FF : ldir
        ld a,1 : ld (n_map_init),a
.initialized:
        ; Only last frame's allocated cells need clearing. The complete map
        ; is initialised by the bank image. Split address planes let ordinary
        ; registers stream it without borrowing SP or damaging an IRQ stack.
        ld hl,$9500 : ld c,$FF : ld a,(n_slot) : ld (n_work_left),a
.clear_blocks: ld a,(n_work_left) : cp 16 : jp c,.clear_tail
        DUP 16
        ld e,(hl) : inc h : ld d,(hl) : dec h
        ld a,d : xor $60 : ld d,a : ld a,c : ld (de),a : inc l
        EDUP
        call n_poll
        ld a,(n_work_left) : sub 16 : ld (n_work_left),a : jp .clear_blocks
.clear_tail: or a : jr z,.cleared
        ld b,a
.clear: ld e,(hl) : inc h : ld d,(hl) : dec h
        ld a,d : xor $60 : ld d,a : ld a,c : ld (de),a : inc l
        djnz .clear
.cleared:
        call n_poll
        ld hl,n_dirty_rows : ld de,n_dirty_rows+1 : ld bc,15 : ld (hl),0 : ldir
        ld a,(n_patch_count) : or a : jr z,.no_patch_rows
        ld hl,n_dirty_rows : ld de,n_dirty_rows+1 : ld bc,13 : ld (hl),1 : ldir
.no_patch_rows:
        xor a : ld (n_slot),a
        ld (n_overflow),a
        call n_apply_patches
        ld ix,n_entities
        ld a,(n_count) : or a : jp z,n_flush_sprites
        cp 41 : jr c,.countok : ld a,40
.countok: ld (n_remaining),a
.entity:
        ld e,(ix+0) : ld d,(ix+1)
        ld hl,(n_camera) : ex de,hl : or a : sbc hl,de
        push hl : ld de,N_SPRITE_W : add hl,de
        bit 7,h : jr nz,.xout
        ld de,640+N_SPRITE_W : or a : sbc hl,de : jr nc,.xout
        pop hl : jr .xin
.xout: pop hl : jp .skip
.xin:
        ld a,l : and 7 : ld (n_xphase),a
        srl h : rr l : srl h : rr l : srl h : rr l
        ld a,l : ld (n_col),a
        ld a,(ix+2) : cp 225-N_SPRITE_H : jp nc,.skip
        push af : rrca : rrca : rrca : rrca : and 15
        ld l,a : ld h,0 : ld de,n_dirty_rows : add hl,de : ld (hl),1
        pop af : push af : and 15 : add a,N_SPRITE_H : cp 17 : jr c,.one_row
        inc hl : ld (hl),1
.one_row: pop af
        ld c,a : and 15 : ld (n_dy),a
        ld a,c : and $F0 : ld l,a : ld h,0
        ; y-cell * 80 = (y & F0h)*5
        ld e,l : ld d,h : add hl,hl : add hl,hl : add hl,de
        ld a,(n_col) : ld e,a : ld d,0
        bit 7,e : jr z,.positivecol : dec d
.positivecol: add hl,de
        ld de,$F000 : add hl,de : ld (n_topcell),hl
        ld a,h : xor $F0 : ld h,a
        ld e,(hl) : set 3,h : ld d,(hl) : ld (n_topcpu),de
        ld a,(n_col) : bit 7,a : jr z,.cpu_ready
        neg : ld b,a
        ld a,(ix+2) : and $F0 : ld l,a : ld h,$A0 : ld de,-224
.leftcpu: add hl,de : djnz .leftcpu
        ld (n_topcpu),hl
.cpu_ready:
        ; One of 128 complete drawing programs for this frame.
        ld a,(n_xphase) : rlca : rlca : rlca : rlca : ld e,a
        ld a,(n_dy) : or e : add a,a : ld l,a : ld h,0
        ld de,$1000 : add hl,de : ld e,(hl) : inc hl : ld d,(hl)
        ex de,hl : call n_call_hl
.skip:  ld de,4 : add ix,de
        call n_poll
        ld a,(n_remaining) : dec a : ld (n_remaining),a : jp nz,.entity
        jp n_flush_sprites
n_map_init: db 0
n_actor_ink: db 8
n_remaining: db 0
n_slot: db 0
n_xphase: db 0
n_col: db 0
n_dy: db 0
n_topcell: dw 0
n_topcpu: dw 0
n_sprite: dw 0
n_drawptr: dw 0
n_column_touch: db 0
n_columns: db 0
n_cell: dw 0
n_usedslot: db 0
n_tileptr: dw 0
n_wasnew: db 0
n_overflow: db 0
n_patch_count: db 0
n_work_left: db 0

; Native terrain-edit boundary. Up to 32 jobs at fixed 9C00h:
; viewport cell offset.word, 16 PCG rows, colour.byte (19 bytes/job).
; The simulation/worker supplies native geometry jobs, never screen pixels.
n_apply_patches:
        ld a,(n_patch_count) : or a : ret z : cp 33 : ret nc
        ld b,a : ld iy,n_patch_buffer
.job:   push bc
        ld e,(iy+0) : ld d,(iy+1)
        ld h,d : ld l,e : ld bc,1120 : or a : sbc hl,bc : jr nc,.skip
        ld h,d : ld l,e : ld bc,$F000 : add hl,bc : ld (n_cell),hl
        call n_allocate_cell : jr c,.skip
        push iy : pop hl : inc hl : inc hl
        ld de,(n_tileptr) : ld bc,16
        DUP 16
        ldi
        EDUP
        ld a,(n_usedslot) : ld l,a : ld h,$97
        ld a,(n_mono) : or a : ld a,(iy+18) : jr z,.patchcolour
        ld a,15
.patchcolour: ld (hl),a
.skip:  call n_poll
        ld de,19 : add iy,de
        pop bc : djnz .job
        ret

n_allocate_cell:
        xor a : ld (n_wasnew),a
        ld hl,(n_cell) : ld a,h : xor $60 : ld h,a
        ld a,(hl) : cp $FF : jr nz,.found
        ld a,(n_slot) : cp $FF : jp z,.full
        ld (hl),a : ld (n_usedslot),a
        inc a : ld (n_slot),a
        ld a,1 : ld (n_wasnew),a
        ld a,(n_usedslot) : ld l,a : ld h,$95
        ld de,(n_cell) : ld (hl),e : inc h : ld (hl),d
        call n_tile_address
        ld a,(n_usedslot) : ld l,a : ld h,$98
        ld de,(n_tileptr) : ld (hl),e : inc h : ld (hl),d
        or a : ret
.found: ld (n_usedslot),a
.address:
        call n_tile_address : or a : ret
.full:  ld a,1 : ld (n_overflow),a : scf : ret

; HL=screen cell, DE=column-major CPU glyph. No allocation or address
; recomputation is required for already touched cells. All overlapping
; actors share the same CPU pixels, even across vertical cell boundaries.
n_touch_cell:
        ld b,h : ld c,l
        ld a,h : xor $60 : ld h,a
        ld a,(hl) : cp $FF : jp nz,.existing
        ld a,(n_slot) : cp $FF : jp z,.full
        ld (hl),a : ld (n_usedslot),a
        inc a : ld (n_slot),a
        ld (n_cell),bc : ld (n_tileptr),de
        ld a,(n_usedslot) : ld l,a : ld h,$98
        ld (hl),e : inc h : ld (hl),d
        ld l,a : ld h,$95 : ld (hl),c : inc h : ld (hl),b
        xor a : out ($08),a
        ld a,$80 : out ($1C),a
        ld hl,(n_cell) : ld a,(hl) : and $7F : ld c,a
        ld a,$90 : out ($1C),a
        ld a,(hl) : and 15 : jr nz,.pcg_source
        ld a,c : or a : jr nz,.pcg_bank_zero
        ; Glyph zero is the blank sky tile in both generated palettes.
        ; Avoid selecting PCG and reading sixteen identical zero bytes.
        ld de,(n_tileptr) : xor a
        DUP 16
        ld (de),a : inc de
        EDUP
        jr .background_done
.pcg_bank_zero:
        xor a
.pcg_source:
        or $80 : out ($1C),a
        ld l,c : ld h,0 : add hl,hl : add hl,hl : add hl,hl : add hl,hl
        ld de,$F800 : add hl,de
        ld de,(n_tileptr) : ld bc,16
        DUP 16
        ldi
        EDUP
.background_done:
        ld a,$40 : out ($08),a
        ld hl,(n_cell) : set 3,h : ld a,(hl)
        ld e,a : ld a,(n_usedslot) : ld l,a : ld h,$97 : ld (hl),e
        xor a : out ($08),a
        ld a,(n_usedslot)
.existing:
        ld l,a : ld h,$97
        ld a,(hl) : and $F0 : ld e,a
        ld a,(n_actor_ink) : or e : ld (hl),a
        or a
        ret
.full:  ld a,1 : ld (n_overflow),a : scf : ret
n_call_hl: jp (hl)
n_tile_address:
        ld hl,(n_cell) : ld a,h : xor $F0 : ld h,a
        ld e,(hl) : set 3,h : ld d,(hl) : ld (n_tileptr),de
        ret

n_flush_sprites:
        xor a : ld (n_upload_slot),a
        ld a,(n_slot) : or a : jp z,n_home
        ld de,$F800
        ld a,$8E : out ($1C),a
        ld a,(n_slot) : cp 129 : jr c,.first
        ld a,128
.first: call n_upload_glyphs
        ld a,(n_slot) : sub 128 : jr c,.metadata : jr z,.metadata
        ld de,$F800 : ld a,$8F : out ($1C),a
        ld a,(n_slot) : sub 128 : call n_upload_glyphs
.metadata:
        ; Three bounded, interrupt-safe linear passes. SP remains the real
        ; stack throughout; a future mouse ISR must not push into cell data.
        ld a,$80 : out ($1C),a
        ld hl,$9500 : ld a,(n_slot) : ld (n_work_left),a
.char_blocks: ld a,(n_work_left) : cp 16 : jp c,.char_tail
        DUP 16
        ld e,(hl) : inc h : ld d,(hl) : dec h
        ld a,l : or $80 : ld (de),a : inc l
        EDUP
        call n_poll
        ld a,(n_work_left) : sub 16 : ld (n_work_left),a : jp .char_blocks
.char_tail: or a : jp z,.chars_done : ld b,a
.chars: ld e,(hl) : inc h : ld d,(hl) : dec h
        ld a,l : or $80 : ld (de),a : inc l
        djnz .chars
.chars_done:
        call n_poll
        ld a,$90 : out ($1C),a
        ld hl,$9500 : ld a,(n_slot) : ld (n_work_left),a
.attr_blocks: ld a,(n_work_left) : cp 16 : jp c,.attr_tail
        DUP 16
        ld e,(hl) : inc h : ld d,(hl) : dec h
        ld a,l : rlca : and 1 : add a,14 : ld (de),a : inc l
        EDUP
        call n_poll
        ld a,(n_work_left) : sub 16 : ld (n_work_left),a : jp .attr_blocks
.attr_tail: or a : jp z,.attrs_done : ld b,a
.attrs: ld e,(hl) : inc h : ld d,(hl) : dec h
        ld a,l : rlca : and 1 : add a,14 : ld (de),a : inc l : djnz .attrs
.attrs_done:
        call n_poll
        ld a,$40 : out ($08),a
        ld hl,$9500 : ld a,(n_slot) : ld (n_work_left),a
.colour_blocks: ld a,(n_work_left) : cp 16 : jp c,.colour_tail
        DUP 16
        ld e,(hl) : inc h : ld d,(hl) : inc h : ld a,(hl) : dec h : dec h
        set 3,d : ld (de),a : inc l
        EDUP
        call n_poll
        ld a,(n_work_left) : sub 16 : ld (n_work_left),a : jp .colour_blocks
.colour_tail: or a : jp z,.colours_done : ld b,a
.colours: ld e,(hl) : inc h : ld d,(hl) : inc h : ld a,(hl) : dec h : dec h
        set 3,d : ld (de),a : inc l
        djnz .colours
.colours_done:
        call n_poll
        xor a : out ($08),a
        jp n_home
n_upload_glyphs:
.glyph: push af
        ld a,(n_upload_slot) : ld l,a : ld h,$98
        ld a,(hl) : inc h : ld h,(hl) : ld l,a
        ld bc,16
        DUP 16
        ldi
        EDUP
        ; Poll after every 16 glyphs; maximum transfer gap is below vblank.
        ld a,(n_upload_slot) : and 15 : call z,n_poll
        ld a,(n_upload_slot) : inc a : ld (n_upload_slot),a
        pop af : dec a : jr nz,.glyph
        ret
n_upload_slot: db 0
n_initial_entities: INCBIN "../build/native/entities.bin"
n_demo_patches: INCBIN "../build/native/patches.bin"
n_end:
        ASSERT n_end < $9000
        IFDEF SLICE
        ORG $9A00
        INCLUDE "slice_bridge.asm"
        INCLUDE "slice_controls.asm"
slice_end:
        ASSERT slice_end <= $A000
        SAVEBIN "../build/native/ENGINE.HI",$8000,slice_end-$8000
        ELSE
        SAVEBIN "../build/native/ENGINE.HI",$8000,n_end-$8000
        ENDIF






        INCLUDE "../build/native/actor-programs.asm"
