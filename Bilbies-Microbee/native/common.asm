; Bespoke Premium Plus renderer: 640x256, native 8x16 PCG cells.
; No VZ framebuffer, packed-pixel conversion, BACK buffer or legacy blitter.
; Expanded blocks 8/9 PCG colour/mono, 10..13 native phase maps.
        DEVICE NOSLOT64K
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
        IFDEF SLICE
        call slice_init
        ELSE
        call n_demo_init
        ENDIF
        xor a : ld (n_frames),a : ld (n_vblank),a
        ld a,2 : ld (n_target),a
n_loop:
        call n_wait
        ; Schedule from the previous deadline. Scheduling from the end of
        ; rendering would add a full 40ms wait after every update.
        ld a,(n_target) : add a,2 : ld (n_target),a
        IFDEF SLICE
        call slice_unmark
        call slice_input
        call slice_tick
        ELSE
        call n_input
        call n_demo_tick
        ENDIF
        ld a,(n_frames) : ld (n_render_start),a
        IFDEF SLICE
        call slice_patches
        jr c,.slice_overflow
        ENDIF
        call n_present
        IFDEF SLICE
        ld a,(n_overflow) : or a : jr nz,.slice_overflow
        call slice_mark
        jr .slice_done
.slice_overflow:
        call slice_show_overflow
.slice_done:
        ENDIF
        call n_poll
        ld a,(n_frames) : ld hl,n_render_start : sub (hl) : call n_show_time
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
        xor a : ld (n_same_map),a
        ld a,(n_terrain_valid) : or a : jr z,.newmap
        ld hl,(n_camera) : ld de,(n_last_camera) : or a : sbc hl,de : jr nz,.newmap
        ld a,(n_mono) : ld hl,n_last_mono : cp (hl) : jr nz,.newmap
        ld a,1 : ld (n_same_map),a
.newmap:
        ld hl,(n_camera) : ld (n_last_camera),hl
        ld a,(n_mono) : ld (n_last_mono),a
        ld a,1 : ld (n_terrain_valid),a
        IFDEF RESIDENT_CACHE
        ld a,(n_same_map) : or a : jp nz,n_home
        xor a : ld (n_pool_valid),a
        ENDIF
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
        xor a : ld (n_present_valid),a : ld (n_terrain_valid),a
        IFDEF RESIDENT_CACHE
        ld (n_pool_valid),a
        ENDIF
        ret
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
        ld hl,n_patch_buffer : ld de,$1596 : ld bc,(n_patch_bytes)
        call n_same_bytes : jp z,n_home
.redraw:
        ld hl,n_signature : ld de,$14F0 : ld bc,6 : ldir
        ld hl,n_entities : ld de,$14F6 : ld bc,160 : ldir
        ld bc,(n_patch_bytes) : ld a,b : or c : jr z,.no_patches
        ld hl,n_patch_buffer : ld de,$1596 : ldir
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
        IFDEF SLICE
        db "BILBIES!  UP THE BANK      SAVED 00/00  T:000"
        ELSE
        db "BILBIES!    NATIVE MICROBEE ENGINE    UP THE BANK"
        ENDIF
        BLOCK 56-($-n_hud_text),32
        db "GFX:"
n_hud_digits: db "00F  H:PAUSE"
        BLOCK 80-($-n_hud_text),32
n_hud_line2:
        IFDEF SLICE
        db "LEFT/RIGHT SELECT  4 BLOCK  5 BUILD  8 DIG  SPACE ASSIGN   BILBY 00  SKILL 8"
        ELSE
        db "O/P PAN  C/M DISPLAY  1/4 TEN/FORTY BILBIES  D TERRAIN PATCH"
        ENDIF
        BLOCK 80-($-n_hud_line2),32
n_hud_end:
        ASSERT n_hud_end-n_hud_text == 160
        IFDEF SLICE
slice_show_overflow:
        ld a,1 : ld (n_paused),a : call n_bank
        xor a : out ($08),a
        ld a,$80 : out ($1C),a
        ld hl,.message : ld de,$F000+1120 : ld bc,.end-.message : ldir
        jp n_home
.message: db "TERRAIN LIMIT - PAUSED"
.end:
        ENDIF
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
.ten:
        IFDEF SLICE
        jp .done
        ELSE
        ld a,$21 : call n_key : jr z,.forty
        ld a,10 : ld (n_count),a
.forty: ld a,$24 : call n_key : jr z,.dig
        ld a,40 : ld (n_count),a
.dig:   ld a,4 : call n_key : jr z,.done
        ld hl,0 : ld (n_camera),hl
        ld hl,n_demo_patches : ld de,n_patch_buffer : ld bc,38 : ldir
        ld a,2 : ld (n_patch_count),a
        ENDIF
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
