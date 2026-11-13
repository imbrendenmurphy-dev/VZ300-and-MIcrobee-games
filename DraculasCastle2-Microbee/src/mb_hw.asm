; Microbee compatibility-stage backend. Native artwork is a later stage.
; 64x32 cells, eight scanlines/cell, static PCG patterns for 2x2 VZ pixels.
; Code/stack live above 8000; lower 32K work block is normally block 1.

mb_init:
            ld a,1
            call mb_bank
            ld hl,$EE00
            ld de,$EE01
            ld bc,$01FF
            ld (hl),0
            ldir
            ld hl,$E200
            ld de,$E201
            ld bc,$01FF
            ld (hl),0
            ldir
            ld hl,MAPBUF
            ld de,MAPBUF+1
            ld bc,$03FF
            ld (hl),0
            ldir
            ld hl,$7A3B
            ld (rng),hl
            ld a,1
            ld (music_on),a
            ld a,1                  ; SOFT voicing for the Microbee speaker
            ld (music_vol),a
            ld a,$08
            call set_latch
            ld a,$CF
            out ($01),a
            ld a,$FF
            out ($01),a
            ld a,7
            out ($01),a
            ld a,$CF
            out ($03),a
            ld a,$BF
            out ($03),a
            ld a,7
            out ($03),a
            xor a
            out ($02),a
            out ($08),a
            out ($0B),a
            ld hl,mb_crtc
            ld b,16
            ld c,0
.cr:        ld a,c
            out ($0C),a
            ld a,(hl)
            out ($0D),a
            inc hl
            inc c
            djnz .cr
            ld a,14
            call mb_bank
            ld hl,0
            ld d,$80
.pcg:       ld a,d
            out ($1C),a
            push de
            ld de,$F800
            ld bc,$0800
            ldir
            pop de
            inc d
            ld a,d
            cp $90
            jr nz,.pcg
            ld a,1
            call mb_bank
            ld a,$80
            out ($1C),a
            call make_flip
            call detect_joy
            call mb_invalidate
            xor a
            call cls_back
            jp present_full

mb_crtc:    db $6B,$40,$51,$37,$26,$00,$20,$23,$48,$07,$20,$00,0,0,0,0

; A = physical 32K block, preserve BC.
mb_bank:    push bc
            ld b,a
            and 3
            xor 2
            ld c,a
            ld a,b
            and $1C
            rlca
            rlca
            rlca
            or c
            or 4
            out ($50),a
            pop bc
            ret

; D..E original bitmap rows; widen partial rectangles to whole rows.
mb_present:
            ld a,(native_battle_active)
            or a
            jp nz,native_battle_present
            ld a,e
            sub d
            ret z
            ret c
            ld a,(latch_base)
            and 8
            jp z,mb_m0_present
            jp world_present
mb_upload:  call wait_frame
            xor a
            out ($0B),a
            out ($08),a
            ld a,$80
            out ($1C),a
            ld hl,$E240
            ld de,(mb_vaddr)
            ld bc,64
            ldir
            ld a,$90
            out ($1C),a
            ld hl,$E280
            ld de,(mb_vaddr)
            ld bc,64
            ldir
            ld a,$80
            out ($1C),a
            ld a,$40
            out ($08),a
            ld hl,$E2C0
            ld de,(mb_vaddr)
            ld a,d
            add a,8
            ld d,a
            ld bc,64
            ldir
            xor a
            out ($08),a
            ret

; Original 1984 text and semigraphics screens, expanded to four PCG cells.
mb_m0_present:
            push ix
            call mb_invalidate
            xor a
            ld (mb_y),a
.row:       ld a,(mb_y)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,$F000
            add hl,de
            ld (mb_vaddr),hl
            ld a,(mb_y)
            srl a
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,BACK
            add hl,de
            xor a
            ld (mb_cellpos),a
            ld b,32
.char:      push bc
            push hl
            ld l,(hl)
            ld h,0
            push hl
            ld de,mb_eggcolours
            add hl,de
            ld c,(hl)
            pop hl
            add hl,hl
            add hl,hl
            ld a,(mb_y)
            and 1
            add a,a
            ld e,a
            ld d,2
            add hl,de
            call mb_eggcell
            inc hl
            call mb_eggcell
            pop hl
            inc hl
            pop bc
            djnz .char
            call mb_upload
            ld hl,mb_y
            inc (hl)
            ld a,(hl)
            cp 32
            jr nz,.row
            pop ix
            ret

mb_invalidate:
            ld hl,$3000
            ld b,32
.loop:      ld (hl),$FF
            inc hl
            djnz .loop
            ret

mb_eggcell:
            push hl
            push de
            push bc
            ld a,l
            or $80
            ld e,a
            ld a,h
            add a,a
            ld d,a
            ld a,l
            rlca
            and 1
            or d
            ld d,a
            ld a,(mb_cellpos)
            add a,$40
            ld l,a
            ld h,$E2
            ld (hl),e
            ld a,l
            add a,$40
            ld l,a
            ld (hl),d
            ld a,l
            add a,$40
            ld l,a
            ld a,(mb_mode)
            or a
            jr z,.colour_value
            ld c,$0F
.colour_value:
            ld (hl),c
            ld hl,mb_cellpos
            inc (hl)
            pop bc
            pop de
            pop hl
            ret

            include "mb_native.asm"
            include "mb_gallery.asm"
            include "mb_animation.asm"
            include "mb_battle.asm"
            include "mb_render32.asm"
            include "mb_front.asm"
            include "mb_display.asm"
            include "mb_world.asm"
            include "mb_keys.asm"
            include "gen/mb_colours.inc"

; - and + (the ;+ key) choose the music's voicing: 1 SOFT (made for the
; Microbee's speaker: no hair-thin pulses, a touch slower) or 2 VZ (exactly
; as the VZ300 played it).
vol_keys:   push bc
            ld a,1
            out ($0B),a
            ld c,0
            ld a,45                 ; -
            call mb_keytest
            jr z,.plus
            set 0,c
.plus:      ld a,43                 ; ; +
            call mb_keytest
            jr z,.read
            set 1,c
.read:      xor a
            out ($0B),a
            ld a,(vol_prev)
            cpl
            and c
            ld b,a
            ld a,c
            ld (vol_prev),a
            ld a,b
            or a
            jr z,.done
            ld a,1
            bit 0,b
            jr nz,.set
            inc a
.set:       ld (music_vol),a
            ld a,1
            ld (music_on),a
            ld (n_hit),a
.done:      pop bc
            ret

; A = duty of a music voice: silent when the music is off. SOFT voicing
; keeps every pulse at least about a tenth of the cycle wide (d -> 24 + 3d/4):
; on the Microbee's cone speaker the VZ's hair-thin decaying pulses come out
; as a scratchy buzz, wider ones as a rounder note with the same envelope.
nz_mute:    push bc
            ld c,a
            ld a,(music_on)
            or a
            jr z,.off
            ld a,c
            or a
            jr z,.done
            ld a,(music_vol)
            dec a
            ld a,c
            jr nz,.done
            srl a
            srl a
            neg
            add a,c
            add a,24
            jr .done
.off:       xor a
.done:      pop bc
            ret

; Z: skip this frame's music step. SOFT voicing plays at 15/16 tempo.
music_beat: ld a,(music_vol)
            dec a
            ret nz
            ld a,(music_skip)
            inc a
            and 15
            ld (music_skip),a
            ret

mb_hw_end:
            noemit
            org $E200
mb_filebank: ds 1
mb_filesrc: ds 2
mb_y:       ds 1
mb_yend:    ds 1
mb_vaddr:   ds 2
mb_cellpos: ds 1
mb_force:   ds 1
mb_mode:    ds 1
native_bank: ds 1
native_src: ds 2
native_read: ds 2
native_left: ds 1
native_active: ds 1
native_monster: ds 1
native_frame: ds 1
native_timer: ds 1
native_page: ds 1
native_battle_active: ds 1
native_death: ds 1
native_ui_index: ds 1
native_fx_count: ds 1
bt_uidirty: ds 1
fx_loaded:  ds 1
dec_dest:   ds 1
bt_room_tag: ds 1
bt_slot_tag: ds 4
bt_kept:    ds 1
music_vol:  ds 1
vol_prev:   ds 1
music_skip: ds 1
world_flow: ds 1
world_prev: ds 1
world_adv:  ds 1
native32_full: ds 1
native32_from: ds 1
native32_index: ds 1
native32_rowptr: ds 2
native32_packet: ds 2
native32_rows: ds 1
native32_x: ds 1
native32_left: ds 1
native32_right: ds 1
native32_count: ds 1
native32_planes: ds 1
native32_scan_count: ds 1
native32_scene: ds 1
native32_group_index: ds 1
native32_fast_ok: ds 1
native32_now_ok: ds 1
native32_last_frame: ds 1
native32_last_hp: ds 1
            assert $ <= $E240
            emit
            org mb_hw_end
