; Fixed upper-memory interface to the original-rule simulation in bank 27.
; Include at ORG 9A00h, after renderer code. Use the actual stack throughout.
; SIM.BNK provides JP vectors at 0000 init, 0003 tick, 0006 can_take,
; 0009 apply_skill, 000C st_jobs, 000F clock. slice_slots maps
; compact displayed records back to original 0..39 creature records.
        INCLUDE "../build/native-simulation/simvars.inc"

slice_init:
        ld a,27 : call n_bank
        call $0000
        call slice_convert
        call slice_get_status
        jp n_home

slice_tick:
        ld a,(n_paused) : or a : ret nz
        ld a,(slice_goal_end) : or a : ret nz
        ld a,27 : call n_bank
        call $000F                 ; original 25 Hz game clock
        ld a,(slice_half_tick) : xor 1 : ld (slice_half_tick),a : jp nz,n_home
        call $0003
        call slice_convert
        call slice_get_status
        ld a,(n_anim) : inc a : and 7 : ld (n_anim),a
        jp n_home

; Requires bank 27; result copied to fixed RAM so the HUD can read it.
slice_get_status:
        call $0012
        ld (slice_goal_end),a
        ld a,b : ld (slice_saved),a
        ld a,c : ld (slice_quota),a
        ld a,d : ld (slice_lost),a
        ld (slice_seconds),hl
        ret
slice_goal_end: db 0
slice_saved: db 0
slice_quota: db 0
slice_lost: db 0
slice_seconds: dw 0

; Reconstruct all currently visible changed cells on every frame. A partial
; job list must never be presented: return carry and pause on exhaustion.
slice_patches:
        ld a,27 : call n_bank
        ld hl,(n_camera) : ld de,n_patch_buffer : ld a,(n_mono) : call $000C
        jr nc,.ok
        xor a : ld (n_patch_count),a
        inc a : ld (slice_terrain_overflow),a : ld (n_paused),a
        call n_home : scf : ret
.ok:    ld (n_patch_count),a
        xor a : ld (slice_terrain_overflow),a
        call n_home : or a : ret
slice_terrain_overflow: db 0

; Caller has selected bank 27. Store all active creatures, including those
; offscreen; clipping is the renderer's job. Exclude NONE/GONE/HOME states.
slice_convert:
        ld ix,$7B00
        ld iy,n_entities
        ld hl,slice_slots : ld (slice_slot_write),hl
        xor a : ld (n_count),a : ld (slice_source_index),a
        ld b,40
.loop:  push bc
        ld a,(ix+0) : or a : jr z,.next
        cp 16 : jr nc,.next
        ld (iy+3),a
        ld l,(ix+1) : ld h,(ix+2)
        add hl,hl
        ld de,-6 : add hl,de
        ld (iy+0),l : ld (iy+1),h
        ld a,(ix+3) : add a,a : add a,64-N_SPRITE_H
        ld (iy+2),a
        ld de,4 : add iy,de
        ld hl,(slice_slot_write) : ld a,(slice_source_index)
        ld (hl),a : inc hl : ld (slice_slot_write),hl
        ld a,(n_count) : inc a : ld (n_count),a
.next:  ld de,16 : add ix,de
        ld a,(slice_source_index) : inc a : ld (slice_source_index),a
        pop bc : djnz .loop
        ; Signature compares all 40 records, so remove stale tail records.
        ld a,(n_count) : cp 40 : ret z
        ld b,a : ld a,40 : sub b : add a,a : add a,a : ld b,a
        xor a
.clear: ld (iy+0),a : inc iy : djnz .clear
        ret

slice_slot_write: dw 0
slice_half_tick: db 0
slice_source_index: db 0
slice_slots: ds 40
