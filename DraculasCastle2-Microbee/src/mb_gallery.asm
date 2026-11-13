; A whole three-frame animation shares one immutable PCG dictionary.
; RAM block 2: glyph byte count, four map pointers, glyphs, three-plane maps.
; Maps and precomputed idle transfers are cached in RAM block 3.
native_group_load:
            push ix
            xor a                       ; the gallery reuses RAM 3's maze bases
            ld (maze_cached),a
            ld a,1
            ld (native32_scene),a
            ld a,(mb_mode)
            or a
            ld a,(native_monster)
            jr z,.index
            add a,12
.index:     ld c,a
            ld a,(native_battle_active)
            or a
            ld a,c
            jr z,.table
            add a,24
.table:     ld (native32_group_index),a
            ld l,a
            ld h,0
            ld e,l
            ld d,h
            add hl,hl
            add hl,de
            ld de,native_groups
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
            ld a,2
            call mb_bank
            ld de,0
            call native_unpack
            ; Blank only while replacing the dictionary on a monster change.
            call wait_frame
            ld a,1
            out ($0C),a
            xor a
            out ($0D),a
            out ($0B),a
            out ($08),a
            ld bc,(0)
            ld hl,10
            ld d,$80
.bank:      ld a,d
            out ($1C),a
            ld a,b
            cp 8
            jr c,.last
            push bc
            push de
            ld de,$F800
            ld bc,2048
            ldir
            pop de
            pop bc
            ld a,b
            sub 8
            ld b,a
            inc d
            jr .bank
.last:      ld a,b
            or c
            jr z,.font
            ld de,$F800
            ldir
.font:      call native32_load_maps
            call native32_font
            call native32_idle_load
            call native_anim_load
            ld a,1
            ld (native32_full),a
            pop ix
            ret

native_group_show:
            push ix
            ld a,1
            ld (native32_from),a
            ld hl,$3100
            ld de,$3100
            ld bc,256
            call native32_copy
            ld a,(native32_full)
            or a
            call nz,native32_dirty_init
            call native32_fast_try
            jr c,.finish
            call native_anim_stage
            ld a,(native_frame)
            call native32_frame_ptr
            push hl
            ld de,0
            call native32_copy_local
            pop hl
            call native32_commit
.finish:    call native32_fast_finish
            pop ix
            ret
