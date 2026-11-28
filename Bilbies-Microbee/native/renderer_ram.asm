; Bespoke Premium Plus renderer: 640x256, native 8x16 PCG cells.
; No VZ framebuffer, packed-pixel conversion, BACK buffer or legacy blitter.
; Expanded blocks 8/9 PCG colour/mono, 10..13 native phase maps.
        DEVICE NOSLOT64K
n_patch_buffer EQU $E600
        INCLUDE "../build/native/config.inc"
        ORG $8000
n_boot:
        di
        ld sp,$EFF0
        ld a,$0F : out ($50),a
        xor a : out ($0B),a
        ld a,$CF : out ($01),a
        ld a,$FF : out ($01),a
        ld a,$07 : out ($01),a
        ld hl,n_crtc : ld c,0
.c:     ld a,c : out ($0C),a : ld a,(hl) : out ($0D),a
        inc hl : inc c : ld a,c : cp 16 : jr nz,.c
        call n_load_pcg
        call n_hud
        call n_demo_init
        xor a : ld (n_frames),a : ld (n_vblank),a
        ld a,2 : ld (n_target),a
n_loop:
        call n_wait
        call n_input
        call n_demo_tick
        ld a,(n_frames) : ld (n_render_start),a
        call n_present
        call n_poll
        ld a,(n_frames) : ld hl,n_render_start : sub (hl) : call n_show_time
        ld a,(n_frames) : add a,2 : ld (n_target),a
        jp n_loop

; 108 character clocks x 19*16+8 scanlines = 50Hz PAL timing.
; 80x16 cells = 640x256. Hardware monitor verification still required.
n_crtc: db $6B,$50,$58,$37,$12,8,$10,$11,$48,15,$20,15,0,0,0,0

; A=32K block, video at F000. Stack/code remain in fixed upper memory.
n_bank:
        push bc
        ld b,a : and 3 : xor 2 : ld c,a
        ld a,b : and $1C : rlca : rlca : rlca : or c : or 4
        out ($50),a
        pop bc : ret
n_home:
        ld a,$0F : out ($50),a : ret

n_load_pcg:
        call n_invalidate
        ld a,(n_mono) : add a,8 : call n_bank
        xor a : out ($08),a : ld (n_pcg_bank),a
        ld hl,0
.bank:  ld a,(n_pcg_bank) : or $80 : out ($1C),a
        ld de,$F800 : ld bc,2048 : ldir
        ld a,(n_pcg_bank) : inc a : ld (n_pcg_bank),a
        cp 16 : jr nz,.bank
        jp n_load_mode
n_pcg_bank: db 0

; Selected display mode's eight native terrain rasters occupy blocks 16..23.
; Both ZX0 packs stay in blocks 24/25. Mode changes use A000..CFFF as staging
; while the frame is invalid; no live sprite bitmap is preserved across them.
n_load_mode:
        ld a,(n_mono) : or a : ld a,8 : jr z,.ink
        ld a,15
.ink:   ld (n_sprite_ink),a
        xor a : ld (n_mode_phase),a
.phase: ld a,(n_mono) : add a,24 : call n_bank
        ld a,(n_mode_phase) : add a,a : add a,a : ld l,a : ld h,0
        ld e,(hl) : inc hl : ld d,(hl) : inc hl
        ld c,(hl) : inc hl : ld b,(hl)
        ex de,hl : ld de,$A000 : ldir
        ld a,(n_mode_phase) : add a,16 : call n_bank
        ld hl,$A000 : ld de,0 : call dzx0_standard
        ld a,(n_mode_phase) : inc a : ld (n_mode_phase),a : cp 8 : jr nz,.phase
        jp n_home
n_mode_phase: db 0
n_sprite_ink: db 8
        INCLUDE "../src/dzx0.asm"

; Edge counter is sampled inside the transfer loops, not just at frame end.
; No interrupt/RTC assumptions are used by this renderer benchmark.
n_poll:
        push af
        in a,($0C) : and $20 : jr z,.out
        ld a,(n_vblank) : or a : jr nz,.done
        ld a,1 : ld (n_vblank),a
        ld a,(n_frames) : inc a : ld (n_frames),a
        jr .done
.out:   xor a : ld (n_vblank),a
.done:  pop af : ret
n_wait:
        call n_poll
        ld a,(n_frames) : ld hl,n_target : sub (hl) : jp m,n_wait
        ret
n_frames: db 0
n_vblank: db 0
n_target: db 2

; Stream three native cell planes straight from expanded RAM to video.
; Eight resident fine-scroll phases share a deduplicated terrain PCG library.
n_terrain:
        xor a : ld (n_same_map),a
        ld a,(n_terrain_valid) : or a : jr z,.newmap
        ld hl,(n_camera) : ld de,(n_last_camera) : or a : sbc hl,de : jr nz,.newmap
        ld a,(n_mono) : ld hl,n_last_mono : cp (hl) : jr nz,.newmap
        ld a,1 : ld (n_same_map),a
.newmap:
        ld hl,(n_camera) : ld (n_last_camera),hl
        ld a,(n_mono) : ld (n_last_mono),a
        ld a,1 : ld (n_terrain_valid),a
        ld hl,(n_camera)
        ld a,l : and 7 : ld c,a
        and 4 : rrca : rrca : add a,10 : ld b,a
        ld a,(n_mono) : add a,a : add a,b : call n_bank
        ld a,c : and 3 : ld d,a
        add a,a : add a,d : add a,a : add a,a : add a,a
        ld d,a : ld e,0             ; phase-in-bank * 1800h
        ld hl,(n_camera)
        srl h : rr l : srl h : rr l : srl h : rr l
        add hl,de : ld (n_map),hl
        xor a : out ($08),a
        ld a,$80 : out ($1C),a
        ld de,$F000 : call n_output_plane
        ld hl,(n_map) : ld de,$0800 : add hl,de
        ld a,$90 : out ($1C),a
        ld de,$F000 : call n_output_plane
        ld hl,(n_map) : ld de,$1000 : add hl,de
        ld a,$40 : out ($08),a
        ld de,$F800 : call n_output_plane
        xor a : out ($08),a
        jp n_home
n_output_plane:
        ld a,(n_same_map) : or a : jp z,n_plane
        ld iy,n_dirty_rows : ld a,14
.row:   push af
        bit 0,(iy+0) : inc iy : jp z,.skip
        ld bc,80
        DUP 80
        ldi
        EDUP
        ld bc,48 : add hl,bc : jr .next
.skip:  ld bc,128 : add hl,bc
        ex de,hl : ld bc,80 : add hl,bc : ex de,hl
.next:  call n_poll
        pop af : dec a : jp nz,.row
        ret
n_plane:
        ld a,14
.row:   push af
        ld bc,80
        DUP 80
        ldi
        EDUP
        ld bc,48 : add hl,bc
        call n_poll
        pop af : dec a : jp nz,.row
        ret
n_map: dw 0
n_camera: dw 0
n_mono: db 0
n_invalidate:
        xor a : ld (n_present_valid),a : ld (n_terrain_valid),a : ret
n_terrain_valid: db 0
n_last_camera: dw 0
n_last_mono: db 0
n_same_map: db 0
n_dirty_rows: ds 16

; Exact unchanged-frame rejection. This is useful for pause/menu screens;
; it is not used as a substitute for measuring moving-actor throughput.
; Bank 14's 14F0h history stores a six-byte header, all 40 entity records,
; and the bounded native patch stream. All compared bytes are authoritative.
n_present:
        ld a,14 : call n_bank
        ld hl,(n_camera) : ld (n_signature),hl
        ld a,(n_mono) : ld (n_signature+2),a
        ld a,(n_anim) : ld (n_signature+3),a
        ld a,(n_count) : ld (n_signature+4),a
        ld a,(n_patch_count) : ld (n_signature+5),a
        cp 33 : jr c,.bounded : ld a,0
.bounded: ld l,a : ld h,0
        add hl,hl : add hl,hl : add hl,hl : add hl,hl
        ld e,a : ld d,0 : add hl,de : add hl,de : add hl,de
        ld (n_patch_bytes),hl
        ld a,(n_present_valid) : or a : jr z,.redraw
        ld hl,n_signature : ld de,$14F0 : ld bc,6 : call n_same_bytes : jr nz,.redraw
        ld hl,n_entities : ld de,$14F6 : ld bc,160 : call n_same_bytes : jr nz,.redraw
        ld hl,$E600 : ld de,$1596 : ld bc,(n_patch_bytes)
        call n_same_bytes : jp z,n_home
.redraw:
        ld hl,n_signature : ld de,$14F0 : ld bc,6 : ldir
        ld hl,n_entities : ld de,$14F6 : ld bc,160 : ldir
        ld bc,(n_patch_bytes) : ld a,b : or c : jr z,.no_patches
        ld hl,$E600 : ld de,$1596 : ldir
.no_patches:
        call n_home : call n_terrain : call n_sprites
        ld a,(n_overflow) : xor 1 : ld (n_present_valid),a
        ret
n_same_bytes:
        ld a,b : or c : ret z
.byte:  ld a,(de) : cp (hl) : ret nz
        inc hl : inc de : dec bc : ld a,b : or c : jr nz,.byte
        ret
n_present_valid: db 0
n_signature: ds 6
n_patch_bytes: dw 0

n_hud:
        xor a : out ($0B),a
        ld a,1 : call n_bank
        xor a : out ($08),a
        ld a,$80 : out ($1C),a
        ld hl,n_hud_text : ld de,$F000+1120 : ld b,160
.text:  ld a,(hl) : ld (de),a : inc hl : inc de : djnz .text
        ld a,$90 : out ($1C),a
        ld hl,$F000+1120 : ld b,160
.attr:  ld (hl),0 : inc hl : djnz .attr
        ld a,$40 : out ($08),a
        ld hl,$F800+1120 : ld b,160
.col:   ld (hl),15 : inc hl : djnz .col
        xor a : out ($08),a
        jp n_home
n_hud_text:
        db "BILBIES!    NATIVE MICROBEE ENGINE    UP THE BANK"
        BLOCK 56-($-n_hud_text),32
        db "GFX:"
n_hud_digits: db "00F  H:PAUSE"
        BLOCK 80-($-n_hud_text),32
n_hud_line2:
        db "O/P PAN  C/M DISPLAY  1/4 TEN/FORTY BILBIES  D TERRAIN PATCH"
        BLOCK 80-($-n_hud_line2),32
n_hud_end:
        ASSERT n_hud_end-n_hud_text == 160
n_show_time:
        cp 100 : jr c,.bounded : ld a,99
.bounded: ld d,'0'
.tens:  cp 10 : jr c,.digits : sub 10 : inc d : jr .tens
.digits: add a,'0' : ld e,a
        ld a,1 : call n_bank
        ld a,$80 : out ($1C),a
        ld hl,$F000+1120+n_hud_digits-n_hud_text
        ld (hl),d : inc hl : ld (hl),e
        inc hl : inc hl : inc hl
        ld a,(n_paused) : or a : ld a,' ' : jr z,.status : ld a,'P'
.status: ld (hl),a
        jp n_home
n_render_start: db 0

; Keyboard light-pen scan directly on the Microbee, no synthetic VZ rows.
n_key:
        push bc : ld b,a
        ld a,1 : out ($0B),a
        ld a,$10 : out ($0C),a : in a,($0D)
        ld a,$11 : out ($0C),a : in a,($0D)
        ld a,$12 : out ($0C),a
        ld a,b : rrca : rrca : rrca : rrca : and 3 : out ($0D),a
        ld a,$13 : out ($0C),a
        ld a,b : rlca : rlca : rlca : rlca : and $F0 : out ($0D),a
        ld a,$1F : out ($0C),a : out ($0D),a : nop
        ld b,0
.wait:  in a,($0C) : bit 7,a : jr nz,.ok : djnz .wait
.ok:    and $40 : pop bc : push af
        xor a : out ($0B),a : pop af : ret
n_input:
        ld a,15 : call n_key : jr z,.right
        ld hl,(n_camera) : ld a,h : or l : jr z,.right
        dec hl : ld (n_camera),hl
        xor a : ld (n_patch_count),a
.right: ld a,16 : call n_key : jr z,.colour
        ld hl,(n_camera) : ld de,384 : or a : sbc hl,de : jr nc,.colour
        ld hl,(n_camera) : inc hl : ld (n_camera),hl
        xor a : ld (n_patch_count),a
.colour:ld a,3 : call n_key : jr z,.mono
        ld a,(n_mono) : or a : jr z,.mono
        xor a : ld (n_mono),a : call n_load_pcg : call n_hud
.mono:  ld a,13 : call n_key : jr z,.ten
        ld a,(n_mono) : or a : jr nz,.ten
        ld a,1 : ld (n_mono),a : call n_load_pcg : call n_hud
.ten:   ld a,$21 : call n_key : jr z,.forty
        ld a,10 : ld (n_count),a
.forty: ld a,$24 : call n_key : jr z,.dig
        ld a,40 : ld (n_count),a
.dig:   ld a,4 : call n_key : jr z,.done
        ld hl,0 : ld (n_camera),hl
        ld hl,n_demo_patches : ld de,$E600 : ld bc,38 : ldir
        ld a,2 : ld (n_patch_count),a
.done:  ld a,8 : call n_key
        ld hl,n_h_down : cp (hl) : jr z,.no_h
        ld (hl),a : or a : jr z,.no_h
        ld a,(n_paused) : xor 1 : ld (n_paused),a
.no_h:  xor a : out ($0B),a : ret
n_h_down: db 0
n_paused: db 0

; Standalone stress harness. Replaced by simulation entity commands at the
; gameplay integration boundary; the renderer never reads a legacy screen.
n_demo_init:
        ld hl,n_initial_entities : ld de,n_entities : ld bc,160 : ldir
        ret
n_demo_tick:
        ld a,(n_paused) : or a : ret nz
        ld a,(n_frames) : rrca : and 7 : ld (n_anim),a : ret
n_anim: db 0
n_count: db 10
n_entities: ds 40*4

; Foreground composition uses native preshifted 16x16 bilby silhouettes.
; 256 private glyphs, at most six touched cells per bilby (40*6=240).
n_sprites:
        ld a,14 : call n_bank
        ; Only last frame's allocated cells need clearing. The complete map
        ; is initialised by the bank image. Split address planes let ordinary
        ; registers stream it without borrowing SP or damaging an IRQ stack.
        ld hl,$1800 : ld c,$FF : ld a,(n_slot) : ld (n_work_left),a
.clear_blocks: ld a,(n_work_left) : cp 16 : jp c,.clear_tail
        DUP 16
        ld e,(hl) : inc h : ld d,(hl) : dec h
        ld a,d : xor $E0 : ld d,a : ld a,c : ld (de),a : inc l
        EDUP
        call n_poll
        ld a,(n_work_left) : sub 16 : ld (n_work_left),a : jp .clear_blocks
.clear_tail: or a : jr z,.cleared
        ld b,a
.clear: ld e,(hl) : inc h : ld d,(hl) : dec h
        ld a,d : xor $E0 : ld d,a : ld a,c : ld (de),a : inc l
        djnz .clear
.cleared:
        call n_poll
        ld hl,n_dirty_rows : ld de,n_dirty_rows+1 : ld bc,15 : ld (hl),0 : ldir
        ld a,(n_patch_count) : or a : jr z,.no_patch_rows
        ld hl,n_dirty_rows : ld de,n_dirty_rows+1 : ld bc,13 : ld (hl),1 : ldir
.no_patch_rows:
        xor a : ld (n_slot),a
        ld (n_overflow),a
        ld (n_command_count),a
        ld hl,$EC00 : ld (n_command_write),hl
        call n_request_patches
        ld ix,n_entities
        ld a,(n_count) : or a : jp z,n_compose_commands
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
        ld a,(n_anim) : ld l,a : ld h,0
        ; frame * 768
        add hl,hl : add hl,hl : add hl,hl : add hl,hl
        add hl,hl : add hl,hl : add hl,hl
        ld e,l : ld d,h : add hl,hl : add hl,de
        add hl,hl
        ld a,(n_xphase) : ld e,a : ld d,0
        ex de,hl : add hl,hl : add hl,hl : add hl,hl : add hl,hl
        ld c,l : ld b,h : add hl,hl : add hl,bc : add hl,de
        ; phase pitch is 96 bytes, twice the 48-byte unmasked pitch.
        ; DE is the frame base; double only the phase offset.
        or a : sbc hl,de : add hl,hl : add hl,de
        ; The 32-byte record pitch matches the original native atlas offset.
        ld de,$2000 : add hl,de : ld (n_sprite),hl
        ld a,(n_xphase) : add a,N_SPRITE_W+7 : srl a : srl a : srl a
.three: ld (n_columns),a
.column:
        ld a,(n_col) : cp 80 : jp nc,.nextcol
        ld hl,(n_sprite) : set 4,l
        ld a,(n_dy) : or l : ld l,a : ld a,(hl) : or a : jp z,.nextcol
        ld (n_column_touch),a
        ld hl,(n_sprite) : inc hl : inc hl : ld e,(hl)
        ld a,(n_dy) : add a,e
        ld e,a : ld d,0 : ld hl,(n_topcpu) : add hl,de
        ld (n_drawptr),hl
        ld a,(n_column_touch) : bit 0,a : jr z,.bottom
        ld hl,(n_topcell) : ld de,(n_topcpu)
        call n_touch_cell : jp c,.nextcol
.bottom:
        ld a,(n_column_touch) : bit 1,a : jr z,.draw
        ld hl,(n_topcpu) : ld de,16 : add hl,de : push hl
        ld hl,(n_topcell) : ld de,80 : add hl,de : pop de
        call n_touch_cell
        jp c,.nextcol
        jr .draw
.draw:
        ld hl,(n_sprite) : ld e,(hl) : inc hl : ld d,(hl)
        ld hl,(n_command_write) : ld (hl),e : inc hl : ld (hl),d : inc hl
        ld de,(n_drawptr) : ld (hl),e : inc hl : ld (hl),d : inc hl
        ld (n_command_write),hl
        ld a,(n_command_count) : inc a : ld (n_command_count),a
.nextcol:
        ld hl,(n_sprite) : ld de,32 : add hl,de : ld (n_sprite),hl
        ld hl,(n_topcell) : inc hl : ld (n_topcell),hl
        ld hl,(n_topcpu) : ld de,224 : add hl,de : ld (n_topcpu),hl
        ld a,(n_col) : inc a : ld (n_col),a
        ld a,(n_columns) : dec a : ld (n_columns),a : jp nz,.column
.skip:  ld de,4 : add ix,de
        call n_poll
        ld a,(n_remaining) : dec a : ld (n_remaining),a : jp nz,.entity
        jp n_compose_commands
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
n_command_count: db 0
n_command_write: dw $EC00
n_background_offset: dw 0

; Native terrain-edit boundary. Up to 32 jobs at fixed E600h:
; viewport cell offset.word, 16 PCG rows, colour.byte (19 bytes/job).
; The simulation/worker supplies native geometry jobs, never screen pixels.
n_apply_patches:
        ld a,(n_patch_count) : or a : ret z : cp 33 : ret nc
        ld b,a : ld iy,$E600
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
        ld a,(n_mono) : or a : ld a,15 : jr nz,.patchcolour
        ld a,(iy+18) : ld c,a
        ld a,(n_usedslot) : ld l,a : ld h,0 : add hl,hl
        ld de,$E900 : add hl,de : bit 0,(hl) : ld a,c : jr z,.patchcolour
        and $F0 : ld hl,n_sprite_ink : or (hl)
.patchcolour: push af
        ld a,(n_usedslot) : ld l,a : ld h,$EB : pop af : ld (hl),a
.skip:  call n_poll
        ld de,19 : add iy,de
        pop bc : dec b : jp nz,.job
        ret

n_request_patches:
        ld a,(n_patch_count) : or a : ret z : cp 33 : ret nc
        ld b,a : ld iy,$E600
.job:   push bc
        ld e,(iy+0) : ld d,(iy+1)
        ld h,d : ld l,e : ld bc,1120 : or a : sbc hl,bc : jr nc,.next
        ld h,d : ld l,e : ld bc,$F000 : add hl,bc : ld (n_cell),hl
        call n_allocate_cell
.next:  call n_poll : ld de,19 : add iy,de : pop bc : dec b : jp nz,.job
        ret

n_allocate_cell:
        xor a : ld (n_wasnew),a
        ld hl,(n_cell) : ld a,h : xor $E0 : ld h,a
        ld a,(hl) : cp $FF : jr nz,.found
        ld a,(n_slot) : cp $FF : jp z,.full
        ld (hl),a : ld (n_usedslot),a
        inc a : ld (n_slot),a
        ld a,1 : ld (n_wasnew),a
        ld a,(n_usedslot) : ld l,a : ld h,$18
        ld de,(n_cell) : ld (hl),e : inc h : ld (hl),d
        call n_tile_address
        ld a,(n_usedslot) : ld l,a : ld h,$1C
        ld de,(n_tileptr) : ld (hl),e : inc h : ld (hl),d
        call n_record_background
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
        ld a,h : xor $E0 : ld h,a
        ld a,(hl) : cp $FF : jp nz,.existing
        ld a,(n_slot) : cp $FF : jp z,.full
        ld (hl),a : ld (n_usedslot),a
        inc a : ld (n_slot),a
        ld (n_cell),bc : ld (n_tileptr),de
        ld a,(n_usedslot) : ld l,a : ld h,$1C
        ld (hl),e : inc h : ld (hl),d
        ld l,a : ld h,$18 : ld (hl),c : inc h : ld (hl),b
        call n_record_background
        ld a,(n_usedslot)
.existing:
        ld l,a : ld h,0 : add hl,hl : ld de,$E900 : add hl,de
        set 0,(hl) : or a
        ret
.full:  ld a,1 : ld (n_overflow),a : scf : ret
n_call_hl: jp (hl)
n_record_background:
        ld a,(n_usedslot) : ld l,a : ld h,0 : add hl,hl
        ld bc,$E900 : add hl,bc : ld de,(n_tileptr)
        ld (hl),e : inc hl : ld (hl),d : ret

; Copy native background glyphs from RAM in one bank selection, then draw
; the recorded columns in entity order. Record bit 0 flags a sprite-bearing
; cell; the underlying CPU destination is always 16-byte aligned.
n_compose_commands:
        call n_fill_backgrounds
        call n_apply_patches
        ld a,(n_command_count) : or a : jr z,.flush
        ld b,a : ld iy,$EC00
.command: ld l,(iy+0) : ld h,(iy+1) : ld e,(iy+2) : ld d,(iy+3)
        call n_call_hl
        ld de,4 : add iy,de : call n_poll : djnz .command
.flush: jp n_flush_sprites

n_fill_backgrounds:
        ld a,(n_slot) : or a : ret z
        ld hl,(n_camera)
        srl h : rr l : srl h : rr l : srl h : rr l
        ld d,l : ld e,0
        add hl,hl : add hl,hl : add hl,hl : add hl,hl : add hl,hl
        ex de,hl : or a : sbc hl,de : ld (n_background_offset),hl
        ld a,(n_camera) : and 7 : add a,16 : call n_bank
        ld ix,$E900 : ld iy,$EB00 : ld a,(n_slot) : ld b,a
.cell:  push bc
        ld e,(ix+0) : ld d,(ix+1) : push de : res 0,e
        ld h,d : ld l,e : ld a,h : sub $A0 : ld h,a
        ld bc,(n_background_offset) : add hl,bc : ld bc,16
        DUP 16
        ldi
        EDUP
        srl h : rr l : srl h : rr l : srl h : rr l : srl h : rr l
        ld de,$6FFF : add hl,de : ld c,(hl)
        pop de : bit 0,e : ld a,c : jr z,.colour
        and $F0 : ld hl,n_sprite_ink : or (hl)
.colour: ld (iy+0),a : inc iy : inc ix : inc ix
        pop bc : ld a,b : and 15 : call z,n_poll : djnz .cell
        ld a,14 : jp n_bank
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
        ld hl,$1800 : ld a,(n_slot) : ld (n_work_left),a
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
        ld hl,$1800 : ld a,(n_slot) : ld (n_work_left),a
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
        ld hl,$1800 : ld a,(n_slot) : ld (n_work_left),a
.colour_blocks: ld a,(n_work_left) : cp 16 : jp c,.colour_tail
        DUP 16
        ld e,(hl) : inc h : ld d,(hl) : ld h,$EB : ld a,(hl) : ld h,$18
        set 3,d : ld (de),a : inc l
        EDUP
        call n_poll
        ld a,(n_work_left) : sub 16 : ld (n_work_left),a : jp .colour_blocks
.colour_tail: or a : jp z,.colours_done : ld b,a
.colours: ld e,(hl) : inc h : ld d,(hl) : ld h,$EB : ld a,(hl) : ld h,$18
        set 3,d : ld (de),a : inc l
        djnz .colours
.colours_done:
        call n_poll
        xor a : out ($08),a
        jp n_home
n_upload_glyphs:
.glyph: push af
        ld a,(n_upload_slot) : ld l,a : ld h,$1C
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
        ASSERT n_end < $9C00
        SAVEBIN "../build/native/ENGINE.HI",$8000,n_end-$8000






