; Bespoke Premium Plus renderer: 640x256, native 8x16 PCG cells.
; No VZ framebuffer, packed-pixel conversion, BACK buffer or legacy blitter.
; Expanded blocks 8/9 PCG colour/mono, 10..13 native phase maps.
        DEVICE NOSLOT64K
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
        call n_terrain
        call n_sprites
        ld a,(n_target) : add a,2 : ld (n_target),a
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
        ld a,(n_mono) : add a,8 : call n_bank
        xor a : out ($08),a : ld (n_pcg_bank),a
        ld hl,0
.bank:  ld a,(n_pcg_bank) : or $80 : out ($1C),a
        ld de,$F800 : ld bc,2048 : ldir
        ld a,(n_pcg_bank) : inc a : ld (n_pcg_bank),a
        cp 16 : jr nz,.bank
        jp n_home
n_pcg_bank: db 0

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
        ld de,$F000 : call n_plane
        ld hl,(n_map) : ld de,$0800 : add hl,de
        ld a,$90 : out ($1C),a
        ld de,$F000 : call n_plane
        ld hl,(n_map) : ld de,$1000 : add hl,de
        ld a,$40 : out ($08),a
        ld de,$F800 : call n_plane
        xor a : out ($08),a
        jp n_home
n_plane:
        ld a,14
.row:   push af
        ld bc,80 : ldir
        ld bc,48 : add hl,bc
        call n_poll
        pop af : dec a : jr nz,.row
        ret
n_map: dw 0
n_camera: dw 0
n_mono: db 0

n_hud:
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
        BLOCK 80-($-n_hud_text),32
n_hud_line2:
        db "O/P PAN  C/M DISPLAY  1/4 TEN/FORTY BILBIES  D TERRAIN PATCH"
        BLOCK 80-($-n_hud_line2),32
n_hud_end:
        ASSERT n_hud_end-n_hud_text == 160

; Keyboard light-pen scan directly on the Microbee, no synthetic VZ rows.
n_key:
        push bc : ld b,a
        ld a,$10 : out ($0C),a : in a,($0D)
        ld a,$11 : out ($0C),a : in a,($0D)
        ld a,$12 : out ($0C),a
        ld a,b : rrca : rrca : rrca : rrca : and 3 : out ($0D),a
        ld a,$13 : out ($0C),a
        ld a,b : rlca : rlca : rlca : rlca : and $F0 : out ($0D),a
        ld a,$1F : out ($0C),a : out ($0D),a : nop
        ld b,0
.wait:  in a,($0C) : bit 7,a : jr nz,.ok : djnz .wait
.ok:    and $40 : pop bc : ret
n_input:
        ld a,1 : out ($0B),a
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
        ld hl,n_demo_patches : ld de,$3000 : ld bc,38 : ldir
        ld a,2 : ld (n_patch_count),a
.done:  xor a : out ($0B),a : ret

; Standalone stress harness. Replaced by simulation entity commands at the
; gameplay integration boundary; the renderer never reads a legacy screen.
n_demo_init:
        ld hl,n_initial_entities : ld de,n_entities : ld bc,160 : ldir
        ret
n_demo_tick:
        ld a,(n_frames) : rrca : and 7 : ld (n_anim),a : ret
n_anim: db 0
n_count: db 10
n_entities: ds 40*4

; Foreground composition uses native preshifted 16x16 bilby silhouettes.
; 256 private glyphs, at most six touched cells per bilby (40*6=240).
n_sprites:
        ld a,1 : call n_bank
        ld hl,$1000 : ld de,$1001 : ld bc,1119 : ld (hl),$FF : ldir
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
        push hl : ld de,16 : add hl,de
        bit 7,h : jr nz,.xout
        ld de,656 : or a : sbc hl,de : jr nc,.xout
        pop hl : jr .xin
.xout: pop hl : jp .skip
.xin:
        ld a,l : and 7 : ld (n_xphase),a
        srl h : rr l : srl h : rr l : srl h : rr l
        ld a,l : ld (n_col),a
        ld a,(ix+2) : cp 209 : jp nc,.skip
        ld c,a : and 15 : ld (n_dy),a
        ld a,c : and $F0 : ld l,a : ld h,0
        ; y-cell * 80 = (y & F0h)*5
        ld e,l : ld d,h : add hl,hl : add hl,hl : add hl,de
        ld a,(n_col) : ld e,a : ld d,0
        bit 7,e : jr z,.positivecol : dec d
.positivecol: add hl,de
        ld de,$F000 : add hl,de : ld (n_topcell),hl
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
        ld de,n_sprite_data : add hl,de : ld (n_sprite),hl
        ld a,(n_xphase) : or a : ld a,3 : jr nz,.three
        dec a
.three: ld (n_columns),a
.column:
        ld a,(n_col) : cp 80 : jr nc,.nextcol
        ld hl,(n_topcell) : ld (n_cell),hl
        ld hl,(n_sprite) : ld (n_source),hl
        ld a,(n_dy) : ld (n_scan),a : neg : add a,16 : ld (n_lines),a
        call n_compose_cell
        ld a,(n_dy) : or a : jr z,.nextcol
        ld (n_lines),a : xor a : ld (n_scan),a
        ld hl,(n_topcell) : ld de,80 : add hl,de : ld (n_cell),hl
        ; The first compose advanced n_source by 2*top-scanline-count.
        call n_compose_cell
.nextcol:
        ld hl,(n_sprite) : ld de,32 : add hl,de : ld (n_sprite),hl
        ld hl,(n_topcell) : inc hl : ld (n_topcell),hl
        ld a,(n_col) : inc a : ld (n_col),a
        ld a,(n_columns) : dec a : ld (n_columns),a : jr nz,.column
.skip:  ld de,4 : add ix,de
        ld a,(n_remaining) : dec a : ld (n_remaining),a : jp nz,.entity
        jp n_flush_sprites
n_remaining: db 0
n_slot: db 0
n_xphase: db 0
n_col: db 0
n_dy: db 0
n_topcell: dw 0
n_sprite: dw 0
n_columns: db 0
n_cell: dw 0
n_source: dw 0
n_scan: db 0
n_lines: db 0
n_ink: db 0
n_usedslot: db 0
n_tileptr: dw 0
n_wasnew: db 0
n_overflow: db 0
n_patch_count: db 0

; Native terrain-edit boundary. Up to 32 jobs at home 3000h:
; viewport cell offset.word, 16 PCG rows, colour.byte (19 bytes/job).
; The simulation/worker supplies native geometry jobs, never screen pixels.
n_apply_patches:
        ld a,(n_patch_count) : or a : ret z : cp 33 : ret nc
        ld b,a : ld iy,$3000
.job:   push bc
        ld e,(iy+0) : ld d,(iy+1)
        ld h,d : ld l,e : ld bc,1120 : or a : sbc hl,bc : jr nc,.skip
        ld h,d : ld l,e : ld bc,$F000 : add hl,bc : ld (n_cell),hl
        call n_allocate_cell : jr c,.skip
        push iy : pop hl : inc hl : inc hl
        ld de,(n_tileptr) : ld bc,16 : ldir
        ld a,(n_usedslot) : ld l,a : ld h,$1A
        ld a,(n_mono) : or a : ld a,(iy+18) : jr z,.patchcolour
        ld a,15
.patchcolour: ld (hl),a
.skip:  ld de,19 : add iy,de
        pop bc : djnz .job
        ret

n_allocate_cell:
        xor a : ld (n_wasnew),a
        ld hl,(n_cell) : ld a,h : xor $E0 : ld h,a
        ld a,(hl) : cp $FF : jr nz,.found
        ld a,(n_slot) : cp $FF : jr z,.full
        ld (hl),a : ld (n_usedslot),a
        inc a : ld (n_slot),a
        ld a,1 : ld (n_wasnew),a
        ld a,(n_usedslot) : ld l,a : ld h,0 : add hl,hl
        ld de,$1800 : add hl,de
        ld de,(n_cell) : ld (hl),e : inc hl : ld (hl),d
        jr .address
.found: ld (n_usedslot),a
.address:
        call n_tile_address : or a : ret
.full:  ld a,1 : ld (n_overflow),a : scf : ret

; One composite per touched screen cell. Read its background only once,
; combine every overlapping bilby in CPU scratch, then upload once.
; Lower-home 1000..145F: cell->slot; 1800..19FF: slot->cell.
; Fixed upper C000..CFFF: at most 256 native 16-byte PCG composites.
n_compose_cell:
        call n_allocate_cell : jr nc,.allocated
        ; Keep the source row pointer coherent if the bounded cache is full.
        ld a,(n_lines) : add a,a : ld e,a : ld d,0
        ld hl,(n_source) : add hl,de : ld (n_source),hl : ret
.allocated:
        ld a,(n_wasnew) : or a : jr z,.existing
        xor a : out ($08),a
        ld a,$80 : out ($1C),a
        ld hl,(n_cell) : ld a,(hl) : and $7F : ld c,a
        ld a,$90 : out ($1C),a
        ld a,(hl) : and 15 : or $80 : out ($1C),a
        ld l,c : ld h,0 : add hl,hl : add hl,hl : add hl,hl : add hl,hl
        ld de,$F800 : add hl,de
        ld de,(n_tileptr) : ld bc,16 : ldir
        ld a,$40 : out ($08),a
        ld hl,(n_cell) : set 3,h : ld a,(hl)
        ld e,a : ld a,(n_usedslot) : ld l,a : ld h,$1A : ld (hl),e
        xor a : out ($08),a
.existing:
        ld a,(n_usedslot) : ld l,a : ld h,$1A
        ld a,(hl) : and $F0 : ld e,a
        ld a,(n_mono) : or a : ld a,8 : jr z,.ink
        ld a,15
.ink:   or e : ld (hl),a
.blend: ld a,(n_scan) : ld e,a : ld d,0
        ld hl,(n_tileptr) : add hl,de : ex de,hl
        ld hl,(n_source) : ld a,(n_lines) : ld b,a
.row:   ld c,(hl) : inc hl : ld a,(de) : and c : or (hl)
        ld (de),a : inc hl : inc de : djnz .row
        ld (n_source),hl
        call n_poll
        ret
n_tile_address:
        ld a,(n_usedslot) : ld l,a : ld h,0
        add hl,hl : add hl,hl : add hl,hl : add hl,hl
        ld de,$C000 : add hl,de : ld (n_tileptr),hl
        ret

n_flush_sprites:
        ld a,(n_slot) : or a : jp z,n_home
        ld hl,$C000 : ld de,$F800
        ld a,$8E : out ($1C),a
        ld a,(n_slot) : cp 129 : jr c,.first
        ld a,128
.first: call n_upload_glyphs
        ld a,(n_slot) : sub 128 : jr c,.metadata : jr z,.metadata
        ld de,$F800 : ld a,$8F : out ($1C),a
        ld a,(n_slot) : sub 128 : call n_upload_glyphs
.metadata:
        ld a,$40 : out ($08),a
        ld iy,$1800 : ld c,0 : ld a,(n_slot) : ld b,a
.cell:  ld e,(iy+0) : ld d,(iy+1)
        ld a,$80 : out ($1C),a
        ld a,c : or $80 : ld (de),a
        ld a,$90 : out ($1C),a
        ld a,c : rlca : and 1 : add a,14 : ld (de),a
        set 3,d : ld l,c : ld h,$1A : ld a,(hl) : ld (de),a
        inc iy : inc iy : inc c
        call n_poll
        djnz .cell
        xor a : out ($08),a
        jp n_home
n_upload_glyphs:
.glyph: push af
        ld bc,16 : ldir
        call n_poll
        pop af : dec a : jr nz,.glyph
        ret
n_tile: ds 16
n_initial_entities: INCBIN "../build/native/entities.bin"
n_demo_patches: INCBIN "../build/native/patches.bin"
        ALIGN 256
n_sprite_data: INCBIN "../build/native/sprites.bin"
n_end:
        ASSERT n_end < $C000
        SAVEBIN "../build/native/ENGINE.HI",$8000,n_end-$8000
