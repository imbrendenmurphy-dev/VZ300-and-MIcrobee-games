; Eight-pose pilot. RAM 30: eight 3840-byte maps. RAM 2: incoming deltas.
; The dictionary is shared by the gallery and combat; PCGs stay fixed at runtime.
native_anim_load:
            xor a
            ld (native_anim_enabled),a
            ld (native_anim_loading),a
            ld (native_anim_load_tick),a
            ld (native_anim_phase),a
            dec a
            ld (native_anim_cached),a
            ld a,(native32_group_index)     ; only the bestiary Ghost has poses
            ld hl,native_anim_assets
            cp 2
            jr z,.found
            ld hl,native_anim_assets+9
            cp 14
            ret nz
.found:
            ld a,1
            ld (native_anim_loading),a
            call native_anim_unpack
            push hl
            ld bc,(0)
            ld hl,2
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
            jr z,.maps
            ld de,$F800
            ldir
.maps:      ld a,$80
            out ($1C),a
            pop hl
            call native_anim_unpack
            push hl
            ld a,2
            ld (native32_from),a
            ld hl,0
            ld de,0
            ld bc,30720
            call native_anim_copy
            pop hl
            call native_anim_unpack
            xor a
            ld (native_anim_loading),a
            ld a,1
            ld (native_anim_enabled),a
            jp mb_bank

; HL points to bank/offset; return HL advanced, RAM 2 mapped.
native_anim_unpack:
            ld a,(hl)
            ld (native_bank),a
            inc hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (native_src),de
            push hl
            xor a
            ld (native_left),a
            ld a,2
            call mb_bank
            ld de,0
            call native_unpack
            pop hl
            ret

native_anim_tick:
            ld a,(native_anim_enabled)
            or a
            ret z
            ld hl,bt_anim
            ld (hl),8
native_anim_advance:
            ld a,(native_anim_phase)
            inc a
            and 7
            ld (native_anim_phase),a
            ret
native_anim_bob:
            ld a,(native_anim_enabled)
            or a
            ld a,0
            ret nz
            ld a,(bt_frame)
            ret
native_anim_gallery:
            ld a,(native_anim_enabled)
            or a
            ret z
.select:    ld a,(native_anim_phase)
            add a,4
            ld (native_frame),a
            ret
native_anim_battle:
            ld a,(bt_frame)
            ld (native_frame),a
            cp 2
            ret nc
            ld a,(bt_mhp)
            or a
            ret z
            jp native_anim_gallery

; A >= 4 uses the staged map at 5000, preserving the original attack pose.
native_anim_stage:
            ld a,(native_frame)
            cp 4
            ret c
            ld hl,native_anim_cached
            cp (hl)
            ret z
            ld (hl),a
            sub 4
            ld c,a
            add a,a
            add a,a
            add a,a
            add a,a
            sub c
            ld h,a
            ld l,0
            ld a,30
            ld (native32_from),a
            ld de,$5000
            ld bc,3840
            jp native32_copy

; Common fast-path eligibility, HP and HUD comparisons have already passed.
native_anim_fast:
            ld a,(native_frame)
            sub 4
            ld c,a
            dec a
            and 7
            add a,4
            ld hl,native32_last_frame
            cp (hl)
            jr nz,.slow
            ld a,c
            add a,a
            add a,a
            add a,a
            sub c
            ld h,a
            ld l,0
            ld a,2
            ld (native32_from),a
            ld de,$3240
            ld bc,1792
            call native32_copy
            ld hl,$3240
            push hl
            call native32_delta
            pop hl
            call native32_apply_packet
            scf
            ret
.slow:      or a
            ret

native_anim_end:
            noemit
            org $E3A0
native_anim_enabled: ds 1
native_anim_phase: ds 1
native_anim_cached: ds 1
native_copy_to: ds 1
native_anim_loading: ds 1
native_anim_load_tick: ds 1
            assert $ <= $E400
            emit
            org native_anim_end
