; Block 14 working layout. Per-cell maps contain 1120 entries.
R_MAP       EQU $1000
R_CELL_LO   EQU $1800
R_CELL_HI   EQU $1900
R_COLOUR    EQU $1A00
R_FLAGS     EQU $1B00
R_CPU_LO    EQU $1C00
R_CPU_HI    EQU $1D00
R_PREV_ROWS EQU $1E00
R_SEND_ROWS EQU $1F00
R_SEEN      EQU $3800
R_ROWS      EQU $4000
R_ACTIVE    EQU $4800
R_FREE      EQU $4900
R_CELLS     EQU $4A00
R_BASE_CHAR EQU $5500
R_BASE_ATTR EQU $5600
R_BASE_COL  EQU $5700
R_LAST_COL  EQU $5E00

n_renderer_work:
        ld a,(n_pool_valid) : or a : call z,n_reset_pool
        ld a,(n_generation) : inc a : and 127 : jr nz,.generation
        ld hl,R_SEEN : ld de,R_SEEN+1 : ld bc,1119 : ld (hl),0 : ldir
        ld a,1
.generation: ld (n_generation),a
        xor a : ld (n_slot),a : ld (n_overflow),a : ld (n_command_count),a
        ld (n_mark_kind),a
        ld hl,0 : ld (n_cell_count),hl
        ld hl,R_CELLS : ld (n_cells_write),hl
        ld hl,$EC00 : ld (n_command_write),hl
        call n_mark_patches
        ld a,128 : ld (n_mark_kind),a
        ld ix,n_entities
        ld a,(n_count) : or a : jp z,n_gather_done
        cp 41 : jr c,.count : ld a,40
.count: ld (n_remaining),a
.entity:
        ld e,(ix+0) : ld d,(ix+1)
        ld hl,(n_camera) : ex de,hl : or a : sbc hl,de
        push hl : ld de,N_SPRITE_W : add hl,de : bit 7,h : jr nz,.out
        ld de,640+N_SPRITE_W : or a : sbc hl,de : jr nc,.out
        pop hl : jr .visible
.out:   pop hl : jp .next_entity
.visible:
        ld a,l : and 7 : ld (n_xphase),a
        srl h : rr l : srl h : rr l : srl h : rr l
        ld a,l : ld (n_col),a
        ld a,(ix+2) : cp 225-N_SPRITE_H : jp nc,.next_entity
        ld c,a : and 15 : ld (n_dy),a
        ld a,c : and $F0 : ld l,a : ld h,0
        ld e,l : ld d,h : add hl,hl : add hl,hl : add hl,de
        ld a,(n_col) : ld e,a : ld d,0 : bit 7,e : jr z,.positive : dec d
.positive: add hl,de : ld de,$F000 : add hl,de : ld (n_topcell),hl
        ld a,(n_col) : bit 7,a : jr nz,.left_cpu
        ld a,h : xor $F0 : ld h,a : ld e,(hl) : set 3,h : ld d,(hl)
        ld (n_topcpu),de : jr .pose
.left_cpu: neg : ld b,a
        ld a,(ix+2) : and $F0 : ld l,a : ld h,$A0 : ld de,-224
.left:  add hl,de : djnz .left : ld (n_topcpu),hl
.pose:  ld a,(n_anim) : ld l,a : ld h,0
        add hl,hl : add hl,hl : add hl,hl : add hl,hl
        add hl,hl : add hl,hl : add hl,hl
        ld e,l : ld d,h : add hl,hl : add hl,de : add hl,hl
        ld a,(n_xphase) : ld e,a : ld d,0
        ex de,hl : add hl,hl : add hl,hl : add hl,hl : add hl,hl
        ld c,l : ld b,h : add hl,hl : add hl,bc : add hl,de
        or a : sbc hl,de : add hl,hl : add hl,de
        ld de,$2000 : add hl,de : ld (n_sprite),hl
        ld a,(n_xphase) : add a,N_SPRITE_W+7 : srl a : srl a : srl a
        ld (n_columns),a
.column:
        ld a,(n_col) : cp 80 : jp nc,.next_column
        ld hl,(n_sprite) : set 4,l
        ld a,(n_dy) : or l : ld l,a : ld a,(hl) : or a : jp z,.next_column
        ld (n_column_touch),a
        ld hl,(n_sprite) : inc hl : inc hl : ld e,(hl) : inc hl : ld c,(hl)
        ld a,(n_dy) : add a,e : ld (n_start_row),a
        add a,c : dec a : ld (n_end_row),a
        ld a,(n_start_row) : ld e,a : ld d,0
        ld hl,(n_topcpu) : add hl,de : ld (n_drawptr),hl
        ld a,(n_column_touch) : bit 0,a : jr z,.bottom
        call n_top_rows
        ld hl,(n_topcell) : call n_mark_cell
.bottom: ld a,(n_column_touch) : bit 1,a : jr z,.command
        call n_bottom_rows
        push af : ld hl,(n_topcell) : ld de,80 : add hl,de : pop af
        call n_mark_cell
.command:
        ld hl,(n_sprite) : ld c,(hl) : inc hl : ld b,(hl)
        ld hl,(n_command_write) : ld (hl),$11 : inc hl
        ld de,(n_drawptr) : ld (hl),e : inc hl : ld (hl),d : inc hl
        ld (hl),$CD : inc hl : ld (hl),c : inc hl : ld (hl),b : inc hl
        ld (n_command_write),hl
        ld a,(n_command_count) : inc a : ld (n_command_count),a
.next_column:
        ld hl,(n_sprite) : ld de,32 : add hl,de : ld (n_sprite),hl
        ld hl,(n_topcell) : inc hl : ld (n_topcell),hl
        ld hl,(n_topcpu) : ld de,224 : add hl,de : ld (n_topcpu),hl
        ld a,(n_col) : inc a : ld (n_col),a
        ld a,(n_columns) : dec a : ld (n_columns),a : jp nz,.column
.next_entity:
        ld hl,(n_command_write) : ld (hl),$CD : inc hl
        ld de,n_poll : ld (hl),e : inc hl : ld (hl),d : inc hl
        ld (n_command_write),hl
        ld de,4 : add ix,de : call n_poll
        ld a,(n_remaining) : dec a : ld (n_remaining),a : jp nz,.entity

n_gather_done:
        ld hl,(n_command_write) : ld (hl),$C9
        call n_free_old
        ld hl,(n_cell_count) : ld (n_cells_left),hl
        ld iy,R_CELLS
.cell:  ld hl,(n_cells_left) : ld a,h : or l : jr z,.prepared
        dec hl : ld (n_cells_left),hl
        ld l,(iy+0) : ld h,(iy+1) : inc iy : inc iy
        call n_prepare_cell : call n_poll : jr .cell
.prepared:
        call n_apply_resident_patches
        call n_execute_list
        call n_flush_resident
        ld a,1 : ld (n_pool_valid),a
        jp n_home

n_reset_pool:
        ld hl,R_MAP : ld de,R_MAP+1 : ld bc,1119 : ld (hl),$FF : ldir
        ld hl,R_FLAGS : ld de,R_FLAGS+1 : ld bc,254 : ld (hl),0 : ldir
        xor a : ld (n_pool_highwater),a : ld (n_free_count),a : ret

n_top_rows:
        ld a,(n_start_row) : ld c,a
        ld a,(n_end_row) : cp 16 : jr c,.end : ld a,15
.end:   rrca : rrca : rrca : rrca : or c : ret
n_bottom_rows:
        ld a,(n_start_row) : sub 16 : jr nc,.start : xor a
.start: ld c,a : ld a,(n_end_row) : and 15
        rrca : rrca : rrca : rrca : or c : ret

; A and B are packed inclusive min/max rows; return their union in A.
n_union_rows:
        ld c,a : and 15 : ld e,a : ld a,b : and 15 : cp e : jr c,.minimum
        ld a,e
.minimum: ld d,a
        ld a,c : and $F0 : ld e,a : ld a,b : and $F0 : cp e : jr nc,.maximum
        ld a,e
.maximum: or d : ret

; HL is a screen cell, A is its modified row interval.
n_mark_cell:
        ld (n_cell),hl : ld (n_rows_new),a
        ld a,h : sub $B8 : ld h,a
        ld a,(hl) : and 127 : ld b,a : ld a,(n_generation) : cp b : jr z,.seen
        ld b,a : ld a,(n_mark_kind) : or b : ld (hl),a
        ld a,h : add a,8 : ld h,a : ld a,(n_rows_new) : ld (hl),a
        ld hl,(n_cells_write) : ld de,(n_cell)
        ld (hl),e : inc hl : ld (hl),d : inc hl : ld (n_cells_write),hl
        ld hl,(n_cell_count) : inc hl : ld (n_cell_count),hl : ret
.seen:  ld a,(n_mark_kind) : or (hl) : ld (hl),a
        ld a,h : add a,8 : ld h,a
        ld a,(n_rows_new) : ld b,a : ld a,(hl) : push hl
        call n_union_rows : pop hl : ld (hl),a : ret

n_mark_patches:
        ld a,(n_patch_count) : or a : ret z : cp 33 : ret nc
        ld b,a : ld iy,n_patch_buffer
.job:   push bc
        ld e,(iy+0) : ld d,(iy+1) : ld h,d : ld l,e
        ld bc,1120 : or a : sbc hl,bc : jr nc,.next
        ld h,d : ld l,e : ld bc,$F000 : add hl,bc
        ld a,$F0 : call n_mark_cell
.next:  ld de,19 : add iy,de : pop bc : djnz .job : ret

n_get_cell:
        ld a,(n_usedslot) : ld l,a : ld h,$18
        ld e,(hl) : inc h : ld d,(hl) : ex de,hl : ret
n_get_cpu:
        ld a,(n_usedslot) : ld l,a : ld h,$1C
        ld e,(hl) : inc h : ld d,(hl) : ret
n_cache_address:
        ld a,(n_usedslot) : rrca : rrca : rrca : rrca
        ld l,a : and 15 : or $90 : ld h,a
        ld a,l : and $F0 : ld l,a : ret
n_cell_cpu:
        ld hl,(n_cell) : ld a,h : xor $F0 : ld h,a
        ld e,(hl) : set 3,h : ld d,(hl) : ld (n_tileptr),de : ret
n_decode_rows:
        ld b,a : and 15 : ld c,a : ld a,b
        rrca : rrca : rrca : rrca : and 15 : sub c : inc a : ret
n_copy_rows:
        cp 16 : jr z,.full
        ld c,a : ld b,0 : ldir : ret
.full:
        DUP 16
        ldi
        EDUP
        ret

n_free_old:
        xor a : ld (n_scan_slot),a
.slot:  ld a,(n_pool_highwater) : ld b,a : ld a,(n_scan_slot) : cp b : ret nc
        ld (n_usedslot),a : ld l,a : ld h,$1B : ld a,(hl) : or a : jr z,.next
        call n_get_cell : ld (n_cell),hl
        ld a,h : sub $B8 : ld h,a : ld a,(hl) : and 127
        ld b,a : ld a,(n_generation) : cp b : jr z,.next
        call n_restore_metadata
        ld hl,(n_cell) : ld a,h : xor $E0 : ld h,a : ld (hl),$FF
        ld a,(n_usedslot) : ld l,a : ld h,$1B : ld (hl),0
        ld a,(n_free_count) : ld l,a : ld h,$49
        ld a,(n_usedslot) : ld (hl),a
        ld a,(n_free_count) : inc a : ld (n_free_count),a
.next:  call n_poll
        ld a,(n_scan_slot) : inc a : ld (n_scan_slot),a : jp .slot

n_new_slot:
        ld a,(n_free_count) : or a : jr z,.grow
        dec a : ld (n_free_count),a : ld l,a : ld h,$49 : ld a,(hl) : or a : ret
.grow:  ld a,(n_pool_highwater) : cp 255 : jr z,.full
        inc a : ld (n_pool_highwater),a : dec a : or a : ret
.full:  ld a,1 : ld (n_overflow),a : scf : ret

n_prepare_cell:
        ld (n_cell),hl : call n_cell_cpu
        ld hl,(n_cell) : ld a,h : sub $B0 : ld h,a
        ld a,(hl) : ld (n_rows_current),a
        ld hl,(n_cell) : ld a,h : xor $E0 : ld h,a : ld a,(hl) : cp 255 : jr nz,.old
        push hl : call n_new_slot : pop hl : ret c
        ld (hl),a : ld (n_usedslot),a
        ld l,a : ld h,$18 : ld de,(n_cell) : ld (hl),e : inc h : ld (hl),d
        ld a,(n_usedslot) : ld l,a : ld h,$1C : ld de,(n_tileptr)
        ld (hl),e : inc h : ld (hl),d
        ld a,(n_usedslot) : ld l,a : ld h,$1B : ld (hl),2
        call n_clone_background
        ld a,(n_usedslot) : ld l,a : ld h,$1F : ld (hl),$F0
        jr .ready
.old:   ld (n_usedslot),a
        ld l,a : ld h,$1E : ld a,(hl) : ld (n_rows_old),a
        call n_restore_background
        ld a,(n_rows_current) : ld b,a : ld a,(n_rows_old) : call n_union_rows
        ld b,a : ld a,(n_usedslot) : ld l,a : ld h,$1F : ld (hl),b
.ready:
        ld a,(n_usedslot) : ld l,a : ld h,$1E : ld a,(n_rows_current) : ld (hl),a
        ld a,(n_usedslot) : ld l,a : ld h,$57 : ld a,(hl) : ld c,a
        ld hl,(n_cell) : ld a,h : sub $B8 : ld h,a : bit 7,(hl) : ld a,c : jr z,.colour
        and $F0 : ld c,a : ld a,(n_mono) : or a : ld a,8 : jr z,.ink : ld a,15
.ink:   or c
.colour: ld b,a : ld a,(n_usedslot) : ld l,a : ld h,$1A : ld (hl),b
        ld a,(n_slot) : ld l,a : ld h,$48 : ld a,(n_usedslot) : ld (hl),a
        ld a,(n_slot) : inc a : ld (n_slot),a : or a : ret

n_clone_background:
        xor a : out ($08),a
        ld a,$80 : out ($1C),a : ld hl,(n_cell) : ld a,(hl) : ld (n_basechar),a
        ld a,$90 : out ($1C),a : ld a,(hl) : ld (n_baseattr),a
        and 15 : or $80 : out ($1C),a
        ld a,(n_basechar) : and 127 : ld l,a : ld h,0
        add hl,hl : add hl,hl : add hl,hl : add hl,hl
        ld de,$F800 : add hl,de : ld de,(n_tileptr) : ld a,16 : call n_copy_rows
        call n_cache_address : ex de,hl : ld hl,(n_tileptr) : ld a,16 : call n_copy_rows
        ld a,$40 : out ($08),a : ld hl,(n_cell) : set 3,h : ld a,(hl)
        ld (n_basecolour),a : xor a : out ($08),a
        ld a,(n_usedslot) : ld l,a : ld h,$55 : ld a,(n_basechar) : ld (hl),a
        inc h : ld a,(n_baseattr) : ld (hl),a
        inc h : ld a,(n_basecolour) : ld (hl),a : ret

n_restore_background:
        ld a,(n_rows_old) : call n_decode_rows
        ld (n_copy_len),a : ld a,c : ld (n_copy_first),a
        call n_cache_address : ld e,c : ld d,0 : add hl,de : push hl
        call n_get_cpu : ld a,(n_copy_first) : or e : ld e,a : pop hl
        ld a,(n_copy_len) : jp n_copy_rows

n_restore_metadata:
        ld de,(n_cell)
        ld a,(n_usedslot) : ld l,a : ld h,$55 : ld a,$80 : out ($1C),a : ld a,(hl) : ld (de),a
        inc h : ld a,$90 : out ($1C),a : ld a,(hl) : ld (de),a
        inc h : ld a,$40 : out ($08),a : set 3,d : ld a,(hl) : ld (de),a
        xor a : out ($08),a : ret

n_apply_resident_patches:
        ld a,(n_patch_count) : or a : ret z : cp 33 : ret nc
        ld b,a : ld iy,n_patch_buffer
.job:   push bc
        ld e,(iy+0) : ld d,(iy+1) : ld h,d : ld l,e
        ld bc,1120 : or a : sbc hl,bc : jr nc,.next
        ld h,d : ld l,e : ld bc,$1000 : add hl,bc : ld a,(hl) : cp 255 : jr z,.next
        ld (n_usedslot),a : call n_get_cpu
        push iy : pop hl : inc hl : inc hl : ld a,16 : call n_copy_rows
        ld a,(iy+18) : ld c,a
        ld e,(iy+0) : ld d,(iy+1) : ld h,d : ld l,e : ld de,R_SEEN : add hl,de
        bit 7,(hl) : ld a,c : jr z,.colour
        and $F0 : ld c,a : ld a,(n_mono) : or a : ld a,8 : jr z,.ink : ld a,15
.ink:   or c
.colour: ld b,a : ld a,(n_mono) : or a : ld a,b : jr z,.store : ld a,15
.store: ld b,a : ld a,(n_usedslot) : ld l,a : ld h,$1A : ld (hl),b
.next:  call n_poll : ld de,19 : add iy,de : pop bc : dec b : jp nz,.job : ret

n_flush_resident:
        xor a : out ($08),a
        ld a,255 : ld (n_pcg_selected),a
        ld a,(n_slot) : ld (n_work_left),a : or a : ret z
        ld iy,R_ACTIVE
.glyph: ld a,(iy+0) : ld (n_usedslot),a
        rlca : and 1 : add a,$8E : ld b,a
        ld a,(n_pcg_selected) : cp b : jr z,.bank
        ld a,b : out ($1C),a : ld (n_pcg_selected),a
.bank:  ld a,(n_usedslot) : ld l,a : ld h,$1F : ld a,(hl) : call n_decode_rows
        ld (n_copy_len),a : ld a,c : ld (n_copy_first),a
        call n_get_cpu : ex de,hl : ld a,l : or c : ld l,a : push hl
        ld a,(n_usedslot) : and 127 : ld l,a : ld h,0
        add hl,hl : add hl,hl : add hl,hl : add hl,hl
        ld de,$F800 : add hl,de : ld a,(n_copy_first) : or l : ld l,a
        ex de,hl : pop hl : ld a,(n_copy_len) : call n_copy_rows
        call n_poll : inc iy
        ld a,(n_work_left) : dec a : ld (n_work_left),a : jp nz,.glyph
        ld a,(n_slot) : ld (n_work_left),a : ld iy,R_ACTIVE
.metadata:
        ld a,(iy+0) : ld (n_usedslot),a
        ld l,a : ld h,$1B : ld a,(hl) : cp 2 : jr nz,.old
        ld (hl),1 : call n_get_cell : ex de,hl
        ld a,$80 : out ($1C),a : ld a,(n_usedslot) : or $80 : ld (de),a
        ld a,$90 : out ($1C),a
        ld a,(n_usedslot) : rlca : and 1 : add a,14 : ld (de),a
        jr .colour
.old:   ld a,(n_usedslot) : ld l,a : ld h,$1A : ld b,(hl)
        ld h,$5E : ld a,(hl) : cp b : jr z,.next
.colour:
        call n_get_cell : ex de,hl : set 3,d
        ld a,(n_usedslot) : ld l,a : ld h,$1A : ld a,(hl)
        ld h,$5E : ld (hl),a : ld b,a
        ld a,$40 : out ($08),a : ld a,b : ld (de),a
.next:  call n_poll : inc iy
        ld a,(n_work_left) : dec a : ld (n_work_left),a : jp nz,.metadata
        xor a : out ($08),a : ret
