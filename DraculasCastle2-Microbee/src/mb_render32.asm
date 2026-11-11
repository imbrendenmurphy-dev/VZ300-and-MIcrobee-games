; 40x32 single-page renderer. RAM block 3:
; 0000 target, 1000 last display, 2000 backdrop (3840 bytes each),
; 3100 UI shadow, 4000 row-run packet, 5000/5F00/6E00 cached frames.
native32_blank:
            call wait_frame
            ld a,1
            out ($0C),a
            xor a
            out ($0D),a
            ld a,1
            ld (native32_full),a
            ret

; Copy BC bytes (multiple of 128) from selected block to block 3.
; native32_copy_body also accepts A = destination bank for world caches.
; HL/DE advance. The upper 128-byte stream buffer is shared with decompression.
native32_copy:
            ld a,3
            jr native32_copy_body
native_anim_copy:
            ld a,30
native32_copy_body:
            ld (native_copy_to),a
.block:     ld a,(native32_from)
            call mb_bank
            push de
            push bc
            ld de,$E300
            ld bc,128
            ldir
            pop bc
            pop de
            push hl
            ld a,(native_copy_to)
            call mb_bank
            ld hl,$E300
            push bc
            ld bc,128
            ldir
            pop bc
            pop hl
            ld a,c
            sub 128
            ld c,a
            ld a,b
            sbc a,0
            ld b,a
            ld a,(native_copy_to)
            cp 30
            jr nz,.next
            ld a,c
            or a
            jr nz,.next
            ld a,b
            and 7
            jr nz,.next
            push bc
            push de
            push hl
            call wait_frame
            pop hl
            pop de
            pop bc
.next:      ld a,b
            or c
            jr nz,.block
            ret

native32_frame_ptr:
            cp 4
            jr c,.base
            ld hl,$5000
            ret
.base:
            add a,a
            ld l,a
            ld h,0
            ld de,native32_frames
            add hl,de
            ld e,(hl)
            inc hl
            ld d,(hl)
            ex de,hl
            ret
native32_frames: dw $5000,$5F00,$6E00,$2000

; Two precomputed idle transitions keep the common animation path short.
native32_idle_load:
            ld a,(native32_group_index)
            ld l,a
            ld h,0
            ld e,l
            ld d,h
            add hl,hl
            add hl,de
            ld de,native_idle_assets
            add hl,de
            ld a,(hl)
            ld (native_bank),a
            inc hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            ld (native_src),de
            xor a
            ld (native_left),a
            ld (native32_fast_ok),a
            ld a,2
            call mb_bank
            ld de,$6000
            call native_unpack
            ld a,2
            ld (native32_from),a
            ld hl,$6000
            ld de,$3240
            ld bc,3456
            call native32_copy
            ld a,1
            jp mb_bank

native32_fast_try:
            xor a
            ld (native32_now_ok),a
            ld a,(native_battle_active)
            or a
            jr z,.eligible
            ld a,(bt_dx)
            or a
            ret nz
            ld a,(bt_dy)
            or a
            ret nz
            ld a,(bt_flash)
            or a
            ret nz
            ld a,(bt_dying)
            or a
            ret nz
            ld a,(fx_kind)
            or a
            ret nz
            ld a,(latch_base)
            and 16
            rrca
            rrca
            rrca
            rrca
            ld hl,bt_css
            cp (hl)
            jr z,.eligible
            or a
            ret
.eligible:  ld a,1
            ld (native32_now_ok),a
            ld a,(native32_full)
            or a
            ret nz
            ld a,(native32_fast_ok)
            or a
            ret z
            ld a,(native_frame)
            cp 4
            jr nc,.extended
            cp 2
            jr nc,.slow
            ld a,(native32_last_frame)
            cp 2
            jr nc,.slow
            jr .common
.extended:  ld a,(native_anim_enabled)
            or a
            jr z,.slow
            ld a,(native32_last_frame)
            cp 4
            jr c,.slow
            cp 12
            jr nc,.slow
.common:
            ld a,(bt_mhp)
            ld hl,native32_last_hp
            cp (hl)
            jr nz,.slow
            ld hl,$3100
            ld de,$3000
            ld b,192
.ui:        ld a,(de)
            cp (hl)
            jr nz,.slow
            inc hl
            inc de
            djnz .ui
            ld a,(native_frame)
            ld hl,native32_last_frame
            cp (hl)
            jr z,.done
            cp 4
            jp nc,native_anim_fast
            ld hl,$3240
            or a
            jr nz,.packet
            ld hl,$3900
.packet:    push hl
            call native32_delta
            pop hl
            call native32_apply_packet
.done:      scf
            ret
.slow:      or a
            ret

native32_fast_finish:
            ld a,3
            call mb_bank
            ld hl,$3100
            ld de,$3000
            ld bc,192
            ldir
            ld a,(native32_now_ok)
            ld (native32_fast_ok),a
            ld a,(native_frame)
            ld (native32_last_frame),a
            ld a,(bt_mhp)
            ld (native32_last_hp),a
            ld a,1
            jp mb_bank

; Mirror a displayed packet into target/cache without touching video memory.
native32_apply_packet:
.run:       ld a,(hl)
            inc hl
            or a
            ret z
            ld (native32_count),a
            ld e,(hl)
            inc hl
            ld a,(hl)
            sub $F0
            ld d,a
            inc hl
            ld a,3
            ld (native32_planes),a
.plane:     push hl
            push de
            ld a,(native32_count)
            ld c,a
            ld b,0
            ldir
            pop de
            pop hl
            push de
            ld a,d
            add a,$10
            ld d,a
            ld a,(native32_count)
            ld c,a
            ld b,0
            ldir
            pop de
            ld bc,1280
            ex de,hl
            add hl,bc
            ex de,hl
            ld a,(native32_planes)
            dec a
            ld (native32_planes),a
            jr nz,.plane
            jr .run

; Bound uninterrupted work while copying a full software frame.
native32_copy_local:
            ld bc,1920
            ldir
            push hl
            push de
            call wait_frame
            pop de
            pop hl
            ld bc,1920
            ldir
            ret

native32_load_maps:
            ld a,2
            ld (native32_from),a
            xor a
            ld (native32_index),a
.map:       ld a,2
            call mb_bank
            ld a,(native32_index)
            add a,a
            add a,2
            ld l,a
            ld h,0
            ld e,(hl)
            inc hl
            ld d,(hl)
            ld a,d
            or e
            jr z,.next
            push de
            ld a,(native32_index)
            call native32_frame_ptr
            ex de,hl
            pop hl
            ld bc,3840
            call native32_copy
.next:      ld hl,native32_index
            inc (hl)
            ld a,(hl)
            cp 4
            jr nz,.map
            ret

; Font top and bottom halves occupy PCG banks 14 and 15.
native32_font:
            xor a
            out ($0B),a
            out ($08),a
            ld a,(native_font_asset)
            call mb_bank
            ld hl,(native_font_asset+1)
            ld a,$8E
            out ($1C),a
            ld de,$F800
            ld bc,2048
            ldir
            ld a,$8F
            out ($1C),a
            ld de,$F800
            ld bc,2048
            ldir
            ld a,$80
            out ($1C),a
            ld a,1
            jp mb_bank

; A screen code, C colour, DE F000-based position. Two rows, 8x16 text.
native32_char:
            push de
            push af
            ld b,14
            call native_battle_cell
            ld a,e
            add a,40
            ld e,a
            jr nc,.bottom
            inc d
.bottom:    pop af
            ld b,15
            call native_battle_cell
            pop de
            ret

native32_commit:
            ld a,3
            call mb_bank
            ld a,(native32_scene)
            or a
            call z,native32_dirty_init
            ld a,(native32_full)
            or a
            jr nz,.full
            call native32_packet_build
            ld a,(hl)
            or a
            jr z,.done
            call native32_delta
            jr .done
.full:      xor a
            out ($0B),a
            out ($08),a
            ld a,$80
            out ($1C),a
            ld hl,0
            ld de,$F000
            ld bc,1280
            ldir
            ld a,$90
            out ($1C),a
            ld de,$F000
            ld bc,1280
            ldir
            ld a,$80
            out ($1C),a
            ld a,$40
            out ($08),a
            ld de,$F800
            ld bc,1280
            ldir
            xor a
            out ($08),a
            ld hl,0
            ld de,$1000
            ld bc,3840
            ldir
            call wait_frame
            ld a,1
            out ($0C),a
            ld a,40
            out ($0D),a
            xor a
            ld (native32_full),a
.done:      ld a,1
            jp mb_bank

; Conservative scan bounds. Effects expand their rows before composition.
native32_dirty_init:
            ld hl,$3200
            ld de,$3201
            ld bc,63
            ld (hl),$FF
            ldir
            ld a,(native32_scene)
            or a
            jr nz,.scene
            ld hl,$3218
            ld b,8
.title:     ld (hl),0
            push hl
            ld de,32
            add hl,de
            ld (hl),39
            pop hl
            inc hl
            djnz .title
            ret
.scene:     ld hl,$3202
            ld b,25
.sprite:    ld (hl),9
            push hl
            ld de,32
            add hl,de
            ld (hl),30
            pop hl
            inc hl
            djnz .sprite
            ld a,(native_battle_active)
            or a
            ret z
            ld hl,$3200
            ld (hl),0
            inc hl
            ld (hl),0
            ld hl,$3220
            ld (hl),39
            inc hl
            ld (hl),39
            ld hl,$3219
            ld b,6
.hud:       ld (hl),0
            push hl
            ld de,32
            add hl,de
            ld (hl),39
            pop hl
            inc hl
            djnz .hud
            ret

; HL cell offset, touch its two text rows; preserve caller registers.
native32_touch:
            push af
            push bc
            push de
            push hl
            ld bc,40
            ld e,0
.divide:    or a
            sbc hl,bc
            jr c,.position
            inc e
            jr .divide
.position:  add hl,bc
            ld c,l
            ld d,$32
            ld b,2
.row:       ld a,(de)
            cp c
            jr c,.right
            ld a,c
            ld (de),a
.right:     ld a,e
            add a,32
            ld e,a
            ld a,(de)
            cp $FF
            jr z,.set
            cp c
            jr nc,.next
.set:       ld a,c
            ld (de),a
.next:      ld a,e
            sub 31
            ld e,a
            djnz .row
            pop hl
            pop de
            pop bc
            pop af
            ret

; Compare complete composed target to previous frame. One bounded run per row.
; Update the cache as cells are discovered; no visible RAM is touched here.
native32_packet_build:
            ld hl,0
            ld (native32_rowptr),hl
            ld hl,$4000
            ld (native32_packet),hl
            ld a,32
            ld (native32_rows),a
.row:       ld a,$FF
            ld (native32_left),a
            xor a
            ld (native32_right),a
            ld a,(native32_rows)
            ld b,a
            ld a,32
            sub b
            ld e,a
            ld d,$32
            ld a,(de)
            cp $FF
            jp z,.nextrow
            ld (native32_x),a
            ld c,a
            ld a,e
            add a,32
            ld e,a
            ld a,(de)
            sub c
            inc a
            ld (native32_scan_count),a
            ld hl,(native32_rowptr)
            ld b,0
            add hl,bc
            ld de,$1000
            add hl,de
            ex de,hl
            ld hl,(native32_rowptr)
            add hl,bc
            ld a,3
            ld (native32_planes),a
.scan:      push hl
            push de
            ld a,(native32_scan_count)
            ld b,a
            ld a,(native32_x)
            ld c,a
.cell:      ld a,(de)
            cp (hl)
            jr z,.same
            ld a,(hl)
            ld (de),a
            ld a,(native32_left)
            cp c
            jr c,.right
            ld a,c
            ld (native32_left),a
.right:     ld a,(native32_right)
            cp c
            jr nc,.same
            ld a,c
            ld (native32_right),a
.same:      inc hl
            inc de
            inc c
            djnz .cell
            pop de
            pop hl
            ld bc,1280
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            ld a,(native32_planes)
            dec a
            ld (native32_planes),a
            jr nz,.scan
            ld a,(native32_left)
            cp $FF
            jr z,.nextrow
            ld c,a
            ld a,(native32_right)
            sub c
            inc a
            ld (native32_count),a
            ld hl,(native32_packet)
            ld (hl),a
            inc hl
            ld de,(native32_rowptr)
            ld a,e
            add a,c
            ld e,a
            jr nc,.address
            inc d
.address:   ld (hl),e
            inc hl
            ld a,d
            add a,$F0
            ld (hl),a
            inc hl
            ex de,hl
            ld a,3
            ld (native32_planes),a
.plane:     push hl
            ld a,(native32_count)
            ld c,a
            ld b,0
            ldir
            pop hl
            ld bc,1280
            add hl,bc
            ld a,(native32_planes)
            dec a
            ld (native32_planes),a
            jr nz,.plane
            ld (native32_packet),de
.nextrow:   ld hl,(native32_rowptr)
            ld de,40
            add hl,de
            ld (native32_rowptr),hl
            ld a,(native32_rows)
            dec a
            ld (native32_rows),a
            jr z,.finished
            and 7
            call z,wait_frame
            jp .row
.finished:
            ld hl,(native32_packet)
            ld (hl),0
            ld hl,$4000
            ret

            include "gen/delta32.inc"
