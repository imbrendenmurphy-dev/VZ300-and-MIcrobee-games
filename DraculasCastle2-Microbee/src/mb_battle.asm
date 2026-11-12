; Native combat presentation. Rules and the original back buffer remain intact.
; Work block 1: 3100..315F ASCII UI, 3160..31BF UI colours.
native_battle_enter:
            call native_enter
            ld a,1
            ld (native_battle_active),a
            xor a
            ld (native_death),a
            ld (bt_flash),a
            ld (bt_dx),a
            ld (bt_dy),a
            ld (bt_dying),a
            ld (fx_kind),a
            ld a,(bt_mon)
            dec a
            ld (native_monster),a
            call native_battle_clear
            call bt_load
            jp bt_prepare

native_battle_leave:
            xor a
            ld (native_battle_active),a
            call wait_frame             ; clear to black before the mode change,
            xor a                       ; so no stale cells flash on the way out
            out ($0B),a
            ld a,$80
            out ($1C),a
            ld hl,$F000
            ld de,$F001
            ld bc,2047
            ld (hl),32
            ldir
            ld a,$40
            out ($08),a
            ld hl,$F800
            ld de,$F801
            ld bc,2047
            ld (hl),0
            ldir
            xor a
            out ($08),a
            jp native_leave

native_battle_char:
            push af
            push bc
            push de
            push hl
            ld b,a
            ld a,(native_battle_active)
            or a
            jr z,.done
            ld a,c
            cp 32
            jr nc,.done
            ld a,d
            sub 47
            jr c,.done
            cp 17
            jr nc,.done
            ld e,c
.row:       sub 6
            jr c,.store
            ld d,a
            ld a,e
            add a,32
            ld e,a
            ld a,d
            jr .row
.store:     ld d,$31
            ld a,b
            cp '@'
            jr z,.hp
            cp '%'
            jr nz,.ascii
            ld a,'M'
            jr .prefix
.hp:        ld a,'H'
.prefix:    dec de
            ld (de),a
            inc de
            ld a,'P'
.ascii:
            call .put
            ld a,e
            add a,96
            ld e,a
            ld a,(txt_bg)
            cp 3
            ld a,$0F
            jr nz,.colour
            ld a,c              ; the selected command: a pointer before it
            cp 1                ; (seen in both modes) and yellow lettering
            jr z,.cursor
            cp 8
            jr nz,.lit
.cursor:    dec e
            ld a,$0B
            call .put
            ld a,e
            sub 96
            ld e,a
            ld a,'>'
            call .put
            ld a,e
            add a,97
            ld e,a
.lit:       ld a,$0B
.colour:    call .put
.done:      pop hl
            pop de
            pop bc
            pop af
            ret
.put:       ex de,hl
            cp (hl)
            ex de,hl
            ret z
            ld (de),a
            ld a,1
            ld (bt_uidirty),a
            ret

native_battle_clear:
            push af
            push bc
            push de
            push hl
            ld a,(native_battle_active)
            or a
            jr z,.done
            ld (bt_uidirty),a
            ld hl,$3100
            ld b,96
.cell:      ld (hl),32
            inc hl
            djnz .cell
            ld b,96
.colour:    ld (hl),15
            inc hl
            djnz .colour
.done:      pop hl
            pop de
            pop bc
            pop af
            ret

native_battle_clear_stats:
            push af
            push bc
            push hl
            ld a,(native_battle_active)
            or a
            jr z,.done
            ld (bt_uidirty),a
            ld hl,$3114
            ld c,3
.row:       ld b,12
.cell:      ld (hl),32
            inc hl
            djnz .cell
            ld a,l
            add a,20
            ld l,a
            dec c
            jr nz,.row
.done:      pop hl
            pop bc
            pop af
            ret

; ---------------------------------------------------------------------------
; Battle presenter. Each call recomposes only what changed and writes it to
; video in one pass straight after the frame sync: no full-screen compares,
; no extra frame waits. RAM block 3:
;   0000 target, 2000 backdrop, 5000/5F00/6E00 frames 0..2 (5000 also holds
;   a staged extra pose), 3200 bounds touched now (32 left, 32 right),
;   7D00 monster masks: 4 slots x 23 rows x 3 bytes (20 cells per row),
;   7E20 bounds shown last time, 7E60 bounds to write, 7EA0 state keys.
BT_MASK     equ $7D00
BT_PREV     equ $7E20
BT_UNION    equ $7E60
BT_KEY      equ $7EA0           ; 8 shown, 8 wanted, then the mask tag
BT_TAG      equ $7EB0
BT_VAR      equ $7EB4           ; fptr 2, mptr 2, src 2, shift 2, brow 2, flags 1

native_battle_present:
            call native_anim_battle     ; a slain monster stays until fx_death
.key:       ld a,3
            call mb_bank
            ld de,BT_KEY+8
            ld a,(native_frame)
            ld (de),a
            inc de
            ld a,(bt_dx)
            ld (de),a
            inc de
            ld a,(bt_dy)
            ld (de),a
            inc de
            ld a,(bt_flash)
            ld (de),a
            inc de
            ld a,(native_death)
            ld (de),a
            inc de
            ld a,(fx_kind)
            or a
            jr z,.nofx
            ld a,(fx_step)
            add a,a
            add a,a
            ld hl,fx_kind
            or (hl)
.nofx:      ld (de),a
            inc de
            ld a,(bt_mhp)
            ld (de),a
            inc de
            ld a,(latch_base)
            and 16
            ld (de),a
            ; flags: bit0 scene changed, bit1 panel changed, bit2 whole screen,
            ; bit3 the monster itself changed (not just an effect stroke)
            ld c,0
            ld hl,BT_KEY
            ld de,BT_KEY+8
            ld b,5
.scene:     ld a,(de)
            cp (hl)
            jr z,.same
            ld c,9
.same:      inc hl
            inc de
            djnz .scene
            ld a,(de)
            cp (hl)
            jr z,.stroke
            set 0,c
.stroke:    inc hl
            inc de
            ld a,(de)
            cp (hl)
            jr nz,.panel
            inc hl
            inc de
            ld a,(de)
            cp (hl)
            jr nz,.panel
            ld a,(bt_uidirty)
            or a
            jr z,.full
.panel:     set 1,c
.full:      ld a,(native32_full)
            or a
            jr z,.flags
            ld c,15
.flags:     ld a,c
            ld (BT_VAR+10),a
            or a
            jp z,bt_done
bt_general:
            ld a,(native_frame)
            cp 4
            jr c,.ptr
            call bt_stage
.ptr:       ld a,(native_frame)
            call native32_frame_ptr
            ld (BT_VAR),hl
            ld a,(native_frame)
            cp 4
            jr c,.slot
            xor a
.slot:      ld c,a
            add a,a
            add a,a
            ld b,a
            add a,a
            add a,a
            add a,a
            add a,a
            add a,b
            add a,c             ; 69 * slot
            ld l,a
            ld h,BT_MASK>>8
            ld (BT_VAR+2),hl
            ; bounds wanted now
            ld hl,$3200
            ld de,$3201
            ld bc,63
            ld (hl),$FF
            ldir
            ld a,(BT_VAR+10)
            ld c,a
            bit 2,c
            jr nz,.all
            bit 3,c
            jr z,.ui
            ld hl,$3202
            ld de,$091E         ; columns 9..30: the window and a one-cell shake
            ld b,23
            call bt_fill
.ui:        bit 1,c
            jr z,.ready
            ld hl,$3200
            ld de,$0027
            ld b,2
            call bt_fill
            ld hl,$3219
            ld b,7
            call bt_fill
            jr .ready
.all:       ld hl,$3200
            ld de,$0027
            ld b,32
            call bt_fill
.ready:     ; panel first: it reloads the UI shadow through the bounce buffer
            ld a,(BT_VAR+10)
            and 2
            jr z,.compose
            ld a,1
            ld (native32_from),a
            ld hl,$3100
            ld de,$3100
            ld bc,256
            call native32_copy
            ld hl,$2000
            ld de,0
            ld bc,80
            call bt_planes
            ld hl,$2000+25*40
            ld de,25*40
            ld bc,280
            call bt_planes
            call native_battle_overlay
            ld a,3
            call mb_bank
            xor a
            ld (bt_uidirty),a
.compose:   ld hl,BT_UNION
            ld de,BT_UNION+1
            ld bc,63
            ld (hl),$FF
            ldir
            ld a,(BT_VAR+10)
            rrca
            jp nc,.write
            ld hl,BT_UNION
            ld de,BT_PREV
            call bt_merge
            ld hl,BT_UNION
            ld de,$3200
            call bt_merge
            ld hl,(BT_VAR)
            ld (BT_VAR+4),hl
            ld a,(bt_dx)
            ld c,a
            ld a,(bt_dy)
            ld b,a
            or c
            ld hl,native_death
            or (hl)
            ld hl,bt_flash
            or (hl)
            jr nz,.moved
            ld a,(fx_kind)
            or a
            jr z,.marks             ; still pose: write straight from its map
            jr .strokes
.moved:     ld hl,$2000
            ld (BT_VAR+4),hl
.strokes:   ld a,(fx_kind)          ; a first, unseen pass finds the stroke rows
            or a
            jr z,.rows
            call native_battle_effect
            ld a,3
            call mb_bank
            ld hl,BT_UNION
            ld de,$3200
            call bt_merge
.rows:      call bt_rows
            ld hl,(BT_VAR+4)
            ld a,h
            cp $20
            jr nz,.fx
            ld a,(native_frame)
            cp 3
            jr z,.fx
            ld hl,(BT_VAR+2)
            ld a,l
            or a
            jr nz,.sprite
            ld a,(native_anim_cached)   ; slot 0 follows whatever pose is staged
            ld hl,BT_TAG
            cp (hl)
            jr z,.sprite
            ld (hl),a
            xor a
            call bt_mask_build
.sprite:    call bt_sprite
.fx:        ld a,(fx_kind)
            or a
            call nz,native_battle_effect
            ld a,3
            call mb_bank
            ld hl,0
            ld (BT_VAR+4),hl
.marks:     ld hl,BT_UNION
            ld de,$3200
            call bt_merge
            ld hl,$3202             ; remember scene rows only
            ld de,BT_PREV+2
            ld bc,23
            ldir
            ld hl,$3222
            ld de,BT_PREV+34
            ld bc,23
            ldir
            jr .blit
.write:     ld hl,$3200
            ld de,BT_UNION
            ld bc,64
            ldir
            ld hl,0
            ld (BT_VAR+4),hl
.blit:      call wait_frame
            call bt_blit
            ld a,(BT_VAR+10)
            and 4
            jr z,bt_keep
            ld a,1
            out ($0C),a
            ld a,40
            out ($0D),a
            xor a
            ld (native32_full),a
bt_keep:    ld hl,BT_KEY+8
            ld de,BT_KEY
            ld bc,8
            ldir
bt_done:    ld a,1
            jp mb_bank

; HL bounds row, D left, E right, B rows
bt_fill:    ld (hl),d
            push hl
            ld a,l
            add a,32
            ld l,a
            ld (hl),e
            pop hl
            inc hl
            djnz bt_fill
            ret

; Merge bounds table DE into HL (32 left then 32 right, $FF = none).
bt_merge:   ld b,32
.row:       ld a,(de)
            cp $FF
            jr z,.next
            ld c,a
            ld a,(hl)
            cp $FF
            jr z,.take
            cp c
            jr c,.right
            ld (hl),c
.right:     push hl
            push de
            ld a,e
            add a,32
            ld e,a
            ld a,l
            add a,32
            ld l,a
            ld a,(de)
            cp (hl)
            jr c,.kept
            ld (hl),a
.kept:      pop de
            pop hl
            jr .next
.take:      ld (hl),c
            push hl
            push de
            ld a,e
            add a,32
            ld e,a
            ld a,l
            add a,32
            ld l,a
            ld a,(de)
            ld (hl),a
            pop de
            pop hl
.next:      inc hl
            inc de
            djnz .row
            ret

; Copy BC bytes of all three planes HL -> DE inside block 3.
bt_planes:  ld a,3
.p:         push af
            push bc
            push de
            push hl
            ldir
            pop hl
            pop de
            ld bc,1280
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            pop bc
            pop af
            dec a
            jr nz,.p
            ret

; A row -> HL = row * 40
bt_row40:   ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,de
            ret

; Scene rows 2..24 of the bounds to write, from (BT_VAR+4) into the target.
bt_rows:    ld a,2
.row:       push af
            ld e,a
            ld d,BT_UNION>>8
            ld a,e
            add a,BT_UNION&255
            ld e,a
            ld a,(de)
            cp $FF
            jr z,.next
            ld c,a
            ld a,e
            add a,32
            ld e,a
            ld a,(de)
            sub c
            inc a
            ld b,a
            pop af
            push af
            push bc
            call bt_row40
            pop bc
            ld a,l
            add a,c
            ld l,a
            jr nc,.nc
            inc h
.nc:        ld c,b
            ld b,0
            ex de,hl
            ld hl,(BT_VAR+4)
            add hl,de
            call bt_planes
.next:      pop af
            inc a
            cp 25
            jr c,.row
            ret

; Write the bounds to video. Scene rows come from (BT_VAR+4), the rest from the target.
bt_blit:    xor a
            out ($0B),a
            out ($08),a
.row:       push af
            ld e,a
            add a,BT_UNION&255
            ld l,a
            ld h,BT_UNION>>8
            ld a,(hl)
            cp $FF
            jr z,.next
            ld c,a
            ld a,l
            add a,32
            ld l,a
            ld a,(hl)
            sub c
            inc a
            ld (BT_VAR+11),a
            ld a,e
            call bt_row40
            ld a,l
            add a,c
            ld l,a
            jr nc,.nc
            inc h
.nc:        ex de,hl            ; DE = cell offset
            pop af
            push af
            ld hl,0
            cp 2
            jr c,.base
            cp 25
            jr nc,.base
            ld hl,(BT_VAR+4)
.base:      add hl,de
            ld a,d
            add a,$F0
            ld d,a
            ld a,$80
            out ($1C),a
            call .copy
            ld a,$90
            out ($1C),a
            call .copy
            ld a,$80
            out ($1C),a
            ld a,$40
            out ($08),a
            ld a,d
            add a,8
            ld d,a
            call .copy
            xor a
            out ($08),a
.next:      pop af
            inc a
            cp 32
            jr c,.row
            ret
.copy:      push hl
            push de
            ld a,(BT_VAR+11)
            ld c,a
            ld b,0
            ldir
            pop de
            pop hl
            ld bc,1280
            add hl,bc
            ret

; Lay the moved, flashing or dissolving monster over the backdrop rows.
bt_sprite:  xor a                   ; nop: colours as drawn
            ld (.neg),a
            ld a,(bt_flash)
            or a
            jr z,.mode
            ld a,(mb_mode)          ; one-colour screens blink the monster out
            or a
            ret nz
            ld a,$2F                ; cpl: a hit shows the monster in negative
            ld (.neg),a
.mode:      ld a,(native_death)
            ld (BT_VAR+12),a
            ld ix,(BT_VAR+2)
            ld hl,0
            ld a,(bt_dy)
            or a
            jr z,.dx
            ld hl,40
            dec a
            jr z,.dx
            add hl,hl
.dx:        ld a,(bt_dx)
            ld e,a
            add a,a
            sbc a,a
            ld d,a
            add hl,de
            ld de,90
            add hl,de
            ex de,hl            ; DE target cell
            ld hl,(BT_VAR)
            ld bc,90
            add hl,bc           ; HL source cell
            ld a,(bt_dy)
            cpl
            add a,24            ; 23 - dy rows
            ld b,a
            xor a
.row:       push bc
            push af
            and 3
            add a,a
            add a,a
            add a,bt_bayer&255
            ld c,a
            ld a,bt_bayer>>8
            adc a,0
            ld b,a
            ld (BT_VAR+8),bc
            ld c,(ix+0)
            ld b,8
            call .span
            ld c,(ix+1)
            ld b,8
            call .span
            ld c,(ix+2)
            ld b,4
            call .span
            inc ix
            inc ix
            inc ix
            ld bc,20
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            pop af
            inc a
            pop bc
            djnz .row
            ret
.span:      ld a,(BT_VAR+12)
            or a
            jr nz,.slow
.fast:      sla c
            jr nc,.fnext
            ld a,(hl)
            ld (de),a
            ld a,h
            add a,5
            ld h,a
            ld a,d
            add a,5
            ld d,a
            ld a,(hl)
            ld (de),a
            ld a,h
            add a,5
            ld h,a
            ld a,d
            add a,5
            ld d,a
            ld a,(hl)
.neg:       nop
            ld (de),a
            ld a,h
            sub 10
            ld h,a
            ld a,d
            sub 10
            ld d,a
.fnext:     inc hl
            inc de
            djnz .fast
            ret
.slow:      sla c
            jr nc,.skip
            push hl
            ld a,l
            and 3
            ld hl,(BT_VAR+8)
            add a,l
            ld l,a
            ld a,(hl)
            ld hl,native_death
            cp (hl)
            pop hl
            jr c,.skip
            push hl
            push de
            ld a,(hl)
            ld (de),a
            ld a,h
            add a,5
            ld h,a
            ld a,d
            add a,5
            ld d,a
            ld a,(hl)
            ld (de),a
            ld a,h
            add a,5
            ld h,a
            ld a,d
            add a,5
            ld d,a
            ld a,(hl)
            ld (de),a
            pop de
            pop hl
.skip:      inc hl
            inc de
            djnz .slow
            ret


; A slot (0..2): mark the cells of rows 2..24, columns 10..29 that differ
; from the backdrop. Built once per loaded or staged pose.
bt_mask_build:
            ld c,a
            add a,a
            add a,a
            add a,a
            add a,a
            sub c
            add a,$50
            ld h,a
            ld l,90
            ld a,c
            add a,a
            add a,a
            ld b,a
            add a,a
            add a,a
            add a,a
            add a,a
            add a,b
            add a,c
            ld e,a
            ld d,BT_MASK>>8
            push de
            pop ix
            ld de,$2000+90
            ld b,23
.row:       push bc
            ld c,3
.byte:      push bc
            ld a,c
            cp 1
            ld b,8
            jr nz,.bits
            ld b,4
.bits:      xor a
            ld (BT_VAR+11),a
.bit:       push bc
            ld a,(de)
            cp (hl)
            jr nz,.diff
            push hl
            push de
            ld bc,1280
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            ld a,(de)
            cp (hl)
            jr nz,.pop
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            ld a,(de)
            cp (hl)
.pop:       pop de
            pop hl
.diff:      ld a,(BT_VAR+11)
            jr z,.zero
            scf
.zero:      rla
            ld (BT_VAR+11),a
            inc hl
            inc de
            pop bc
            djnz .bit
            pop bc
            ld a,c
            cp 1
            ld a,(BT_VAR+11)
            jr nz,.store
            rlca
            rlca
            rlca
            rlca
.store:     ld (ix+0),a
            inc ix
            dec c
            jr nz,.byte
            ld bc,20
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            pop bc
            djnz .row
            ret

; Called once the monster group and its maps are in place.
bt_prepare: ld a,3
            call mb_bank
            ld hl,BT_PREV
            ld de,BT_PREV+1
            ld bc,BT_TAG-BT_PREV
            ld (hl),$FF
            ldir
            xor a
            call bt_mask_build
            ld a,1
            call bt_mask_build
            ld a,2
            call bt_mask_build
            ld a,(native_anim_cached)
            ld (BT_TAG),a
            ld a,1
            jp mb_bank

            align 4
bt_bayer:   db 0,8,2,10, 12,4,14,6, 3,11,1,9, 15,7,13,5

; Software target already contains the scene. Add retained game UI and FX.
native_battle_overlay:
            ld de,$F000+25*40+4
            ld a,(native_page)
            or a
            jr z,.page
            ld de,$F400+25*40+4
.page:      ld hl,$3100
            xor a
            ld (native_ui_index),a
.char:      ld a,(hl)
            sub 32
            or $80
            push hl
            push af
            ld a,l
            add a,96
            ld l,a
            ld c,(hl)
            ld b,14
            pop af
            call native32_char
            pop hl
            inc hl
            inc de
            ld a,(native_ui_index)
            inc a
            ld (native_ui_index),a
            cp 96
            jr z,.name
            and 31
            jr nz,.char
            push hl
            ld hl,48
            add hl,de
            ex de,hl
            pop hl
            jr .char
.name:      ld de,statbuf
            call mon_name_de
            ld hl,statbuf
            ld de,$F001
            call native_text
            ld a,(bt_mhp)
            ld e,16
            call mul8
            ld a,(bt_mhpmax)
            ld c,a
            call div_hl_c
            ld c,a
            ld b,16
            ld hl,statbuf
.bar:       ld a,c
            or a
            ld a,'.'
            jr z,.empty
            dec c
            ld a,'='
.empty:     ld (hl),a
            inc hl
            djnz .bar
            ld (hl),0
            ld hl,statbuf
            ld de,$F000+22
            call native_text
            ; Original CSS flashes become a clear inverse status panel.
            ld a,(latch_base)
            and 16
            rrca
            rrca
            rrca
            rrca
            ld hl,bt_css
            cp (hl)
            ret z
            ld hl,$0A00+25*40
            ld a,(native_page)
            or a
            jr z,.tint
            ld hl,$0A00+25*40
.tint:
            ld b,240
.invert:    ld a,(hl)
            xor $FF
            ld (hl),a
            inc hl
            djnz .invert
            xor a
            out ($08),a
            ret

native_battle_css:
            push af
            ld a,(native_battle_active)
            or a
            jr z,.done
            push bc
            push de
            push hl
            call native_battle_present
            pop hl
            pop de
            pop bc
.done:      pop af
            ret

; A screen code, B PCG bank, C colour, DE absolute screen address.
native_battle_cell:
            push de
            push af
            ld a,d
            sub $F0
            ld d,a
            pop af
            ld (de),a
            ld a,d
            add a,5
            ld d,a
            ld a,b
            ld (de),a
            ld a,d
            add a,5
            ld d,a
            ld a,c
            ld (de),a
            pop de
            ret

; Native effects use font glyphs over the native scene; no VZ pixel scaling.
native_battle_effect:
            ld a,(fx_kind)
            or a
            ret z
            cp 1
            jr z,.slash
            cp 2
            jr z,.fire
            ; Ten deterministic sparkles. Never consume gameplay RNG.
            ld b,10
            ld hl,2*40+11
.holy:      push bc
            push hl
            ld a,(fx_step)
            and 7
            ld e,a
            ld d,0
            add hl,de
            ld a,'+'
            call native_battle_mark
            pop hl
            ld de,57
            add hl,de
            pop bc
            djnz .holy
            ret
.slash:     ld a,(fx_step)
            inc a
            add a,a
            add a,a
            cp 17
            jr c,.length
            ld a,16
.length:    ld b,a
            ld hl,2*40+27
.stroke:    push bc
            push hl
            ld a,'/'
            call native_battle_mark
            pop hl
            ld de,39
            add hl,de
            pop bc
            djnz .stroke
            ret
.fire:      ld a,(fx_step)
            cp 6
            jr nc,.burst
            ld b,a
            ld hl,22*40+19
            or a
            jr z,.ball
            ld de,-120
.rise:      add hl,de
            djnz .rise
.ball:      push hl
            ld a,'*'
            call native_battle_mark
            pop hl
            inc hl
            ld a,'*'
            jp native_battle_mark
.burst:     ld b,8
            ld hl,5*40+16
.spark:     push bc
            push hl
            ld a,'*'
            call native_battle_mark
            pop hl
            ld de,43
            add hl,de
            pop bc
            djnz .spark
            ret

; A ASCII effect glyph, HL native cell offset.
native_battle_mark:
            call native32_touch
            sub 32
            or $80
            push af
            ld de,$F000
            ld a,(native_page)
            or a
            jr z,.page
            ld de,$F400
.page:      add hl,de
            ex de,hl
            ld bc,$0F0F
            pop af
            jp native32_char

; Encounter: black blinds close over the maze in eight frames, so the room
; is never seen again while the monster's art loads.
native_battle_wipe:
            ld b,0
.step:      push bc
            call wait_frame
            pop bc
            push bc
            xor a
            out ($0B),a
            ld a,$40
            out ($08),a
            ld a,b
            call bt_row40
            ld de,$F800
            add hl,de
            ld c,4
.rows:      ld b,40
.cell:      ld (hl),0
            inc hl
            djnz .cell
            ld de,7*40
            add hl,de
            dec c
            jr nz,.rows
            xor a
            out ($08),a
            pop bc
            inc b
            ld a,b
            cp 8
            jr nz,.step
            ret

; ---------------------------------------------------------------------------
; Load combat art. Bosses keep their own lairs (native_group_load); ordinary
; monsters are laid into the room the hero is standing in (battle_rooms.py).
bt_load:    ld a,(mb_mode)
            or a
            ld a,(native_monster)
            jr z,.index
            add a,12
.index:     ld l,a
            ld h,0
            ld e,l
            ld d,h
            add hl,hl
            add hl,de
            ld de,bt_sprites
            add hl,de
            ld a,(hl)
            or a
            jp z,native_group_load
            ld a,1
            ld (native32_scene),a
            xor a
            ld (native_anim_enabled),a
            call wait_frame
            ld a,1                  ; screen off while the art changes
            out ($0C),a
            xor a
            out ($0D),a
            ; the room: glyphs to PCG banks 0..4, map to the backdrop cache.
            ; Rooms and monsters stay unpacked in RAM 27 / 29 between battles.
            ld a,(mb_mode)
            or a
            ld a,(cur_area)
            jr z,.room
            add a,6
.room:      ld hl,bt_rooms
            ld de,bt_room_tag
            ld b,27
            call bt_cache
            ld d,$80
            call bt_pcg
            ld de,$2000
            ld bc,3840
            call native32_copy
            ; the monster: glyphs to banks 5..13, windows to block 3 (3240)
            ld a,(mb_mode)
            or a
            ld a,(native_monster)
            jr z,.sprite
            add a,12
.sprite:    ld hl,bt_sprites
            ld de,bt_sprite_tag
            ld b,29
            call bt_cache
            ld d,$85
            call bt_pcg
            push hl
            ld de,$3240
            ld bc,3 * 1408
            call native32_copy
            pop hl
            ld a,(native_monster)
            cp 2                    ; the Ghost floats through eight phases
            jr nz,.frames
            ld de,3 * 1380
            add hl,de
            ld de,0
            ld bc,8 * 1408
            call native_anim_copy
            ld a,1
            ld (native_anim_enabled),a
.frames:    xor a
            ld (native_anim_phase),a
            dec a
            ld (native_anim_cached),a
            ld a,3
            call mb_bank
            ld hl,$5000
            ld de,$3240
.frame:     push hl
            push de
            ex de,hl
            ld hl,$2000
            ld bc,3840
            ldir
            pop hl
            pop de
            push de
            push hl
            ex de,hl
            ld bc,90
            add hl,bc
            ex de,hl
            call bt_overlay
            pop hl
            ld bc,1380
            add hl,bc
            ex de,hl
            pop hl
            ld bc,$0F00
            add hl,bc
            ld a,h
            cp $7D
            jr c,.frame
            call native32_font
            ld a,1
            ld (native32_full),a
            jp mb_bank

; A packet index, HL its table, DE its cache tag, B the cache block. Unpack
; unless that block already holds it; return HL = data, BC = glyph bytes,
; the block mapped and native32_from set to it.
bt_cache:   push bc
            ld c,a
            inc a
            ex de,hl
            cp (hl)
            ld (hl),a
            ex de,hl
            jr z,.open
            ld a,c
            ld e,a
            ld d,0
            add hl,de
            add hl,de
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
            pop af                  ; A = cache block
            push af
            ld (unpack_bank),a
            call mb_bank
            ld de,0
            call native_unpack
            xor a
            ld (unpack_bank),a
.open:      pop af
            ld (native32_from),a
            call mb_bank
            ld bc,(0)
            ld hl,2
            ret

; HL glyphs, BC bytes, D first PCG bank | $80. Returns HL past the glyphs.
bt_pcg:     xor a
            out ($0B),a
            out ($08),a
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
            jr z,.done
            ld de,$F800
            ldir
.done:      ld a,$80
            out ($1C),a
            ret

; HL 20x23 window (codes, banks, colours; code 0 = room), DE map cell (2,10).
bt_overlay: ld b,23
.row:       push bc
            ld b,20
.cell:      ld a,(hl)
            or a
            jr z,.skip
            push bc
            push hl
            push de
            ld (de),a
            ld bc,460
            add hl,bc
            ld a,d
            add a,5
            ld d,a
            ld a,(hl)
            ld (de),a
            add hl,bc
            ld a,d
            add a,5
            ld d,a
            ld a,(hl)
            ld (de),a
            pop de
            pop hl
            pop bc
.skip:      inc hl
            inc de
            djnz .cell
            ex de,hl
            ld bc,20
            add hl,bc
            ex de,hl
            pop bc
            djnz .row
            ret

; The Ghost's staged phase: its window over the room in the frame-0 slot.
bt_stage:   ld a,(native_frame)
            ld hl,native_anim_cached
            cp (hl)
            jr z,.done
            ld (hl),a
            sub 4
            ld hl,0
            ld de,1380
            or a
.mul:       jr z,.copy
            add hl,de
            dec a
            jr .mul
.copy:      ld a,30
            ld (native32_from),a
            ld de,$3240
            ld bc,1408
            call native32_copy
            ld hl,$2000+90
            ld de,$5000+90
            ld b,23
.restore:   push bc
            push hl
            push de
            ld bc,20
            call bt_planes
            pop de
            pop hl
            ld bc,40
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            pop bc
            djnz .restore
            ld hl,$3240
            ld de,$5000+90
            call bt_overlay
.done:      ld a,3
            jp mb_bank
