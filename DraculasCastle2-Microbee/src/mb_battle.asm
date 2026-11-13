; Native combat presentation. Rules and the original back buffer remain intact.
; Work block 1: 3100..315F ASCII UI, 3160..31BF UI colours.
native_battle_enter:
            call native_enter
            ld a,1
            ld (native_battle_active),a
            xor a
            ld (maze_cached),a          ; combat reuses RAM 3's maze bases
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
            xor a
            ld (fx_loaded),a
            ld a,(ovl_asset)            ; combat code into the maze work buffer
            call mb_bank
            ld hl,(ovl_asset+1)
            ld de,$DA60
            ld bc,(ovl_asset+3)
            ldir
            ld a,1
            call mb_bank
            call bt_load
            jp bt_prepare

native_battle_leave:
            xor a
            ld (native_battle_active),a
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

; Black blinds close over the screen in eight frames (codes become spaces,
; colours black, so it works on colour and one-colour screens alike), then
; all of video RAM is cleared. Used for encounters and moving between areas.
native_battle_wipe:
            ld b,0
.step:      push bc
            call wait_frame
            pop bc
            push bc
            ld l,b
            ld h,0
            ld c,4
.rows:      push hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,de               ; row * 40
            ld de,$F000
            add hl,de
            ld b,40
            call vram_fill
            pop hl
            ld a,l
            add a,8
            ld l,a
            dec c
            jr nz,.rows
            pop bc
            inc b
            ld a,b
            cp 8
            jr nz,.step
; Clear all of video RAM to black spaces.
vram_black:
            ld hl,$F000
            ld b,0
            call vram_fill
            ld hl,$F100
            ld c,7
.page:      ld b,0
            call vram_fill
            inc h
            dec c
            jr nz,.page
            ret
; HL screen address ($F000..), B cells (0 = 256): space code, black colour.
vram_fill:  push bc
            push hl
            xor a
            out ($0B),a
            ld a,$80
            out ($1C),a
.code:      ld (hl),32
            inc hl
            djnz .code
            pop hl
            pop bc
            push hl
            ld a,h
            add a,8
            ld h,a
            ld a,$40
            out ($08),a
.col:       ld (hl),0
            inc hl
            djnz .col
            xor a
            out ($08),a
            pop hl
            ret

; ---------------------------------------------------------------------------
; Battle effects (tools/battle_fx.py): each step is a list of cells whose
; pixels are merged over what is already in the cell, in spare PCGs of bank
; 12 or 13 (alternating each present, so the cells on screen are never
; rewritten under the beam). The effect's steps are copied to RAM block 3
; $1000 when it starts. Called with block 3 mapped; A = 0 only marks the rows
; a step covers (so they can be recomposed first), A = 1 draws it.
FX_BUF      equ $1000
FX_VAR      equ $7EE0           ; slot, ink, mode, bank, then 8 glyph bytes
fx_draw:    ld (FX_VAR+2),a
            ld a,(fx_kind)
            or a
            ret z
            ld hl,fx_loaded
            cp (hl)
            call nz,fx_load
            ld a,(FX_VAR+2)
            or a
            jr z,.step
            ld a,(FX_VAR+3)
            xor 1
            and 1
            ld (FX_VAR+3),a
.step:      xor a
            ld (FX_VAR),a
            out ($0B),a
            out ($08),a
            ld a,(fx_step)
            add a,a
            ld l,a
            ld h,FX_BUF>>8
            ld e,(hl)
            inc hl
            ld d,(hl)
            ld hl,FX_BUF
            add hl,de
.cell:      ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            bit 7,d
            jr nz,.end
            ld a,d                  ; column | row << 6 | ink << 11
            rrca
            rrca
            rrca
            and 15
            ld (FX_VAR+1),a
            ld a,e
            and 63
            ld c,a
            ld a,e
            rlca
            rlca
            and 3
            ld b,a
            ld a,d
            and 7
            add a,a
            add a,a
            or b
            ld b,a                  ; B row, C column
            push hl                 ; the step's pixels for this cell
            ld h,$32                ; widen the row's bounds
            ld l,b
            ld a,(hl)
            cp c
            jr c,.right
            ld (hl),c
.right:     ld a,l
            add a,32
            ld l,a
            ld a,(hl)
            cp $FF
            jr z,.set
            cp c
            jr nc,.drawn
.set:       ld (hl),c
.drawn:     ld a,(FX_VAR+2)
            or a
            jr z,.next
            ld l,b
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld d,h
            ld e,l
            add hl,hl
            add hl,hl
            add hl,de
            ld e,c
            ld d,0
            add hl,de
            call fx_cell
.next:      pop hl
            ld bc,8
            add hl,bc
            jr .cell
.end:       ld a,$80
            out ($1C),a
            ret

; HL target cell; (SP+2) its pixels. Merge into the next spare PCG.
fx_cell:    ld b,(hl)               ; code
            push hl
            ld de,1280
            add hl,de
            ld c,(hl)               ; PCG bank
            ld a,(FX_VAR+3)
            add a,12
            ld (hl),a
            add hl,de
            ld a,(hl)               ; keep the cell's background, ink the rest
            and $F0
            ld e,a
            ld a,(FX_VAR+1)
            or e
            ld (hl),a
            pop hl
            ld a,(FX_VAR)
            or $80
            ld (hl),a
            ld de,FX_VAR+8          ; the glyph under it, from PCG RAM
            ld a,b
            add a,a
            jr nc,.blank            ; a ROM character: nothing to keep
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,h
            add a,$F8
            ld h,a
            ld a,c
            and 15
            or $80
            out ($1C),a
            ld bc,8
            ldir
            jr .merge
.blank:     ld b,8
            xor a
.zero:      ld (de),a
            inc de
            djnz .zero
.merge:     ld a,(FX_VAR+3)
            add a,$8C
            out ($1C),a
            ld a,(FX_VAR)
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,h
            add a,$F8
            ld h,a                  ; HL spare PCG
            pop bc                  ; return
            pop de                  ; the step's pixels
            push de
            push bc
            ld bc,FX_VAR+8
            ld a,8
.or:        ex af,af'
            ld a,(bc)
            ex de,hl
            or (hl)
            ex de,hl
            ld (hl),a
            inc hl
            inc de
            inc bc
            ex af,af'
            dec a
            jr nz,.or
            ld hl,FX_VAR
            inc (hl)
            ret

fx_load:    ld (hl),a
            dec a
            ld l,a
            ld h,0
            ld e,l
            ld d,h
            add hl,hl
            add hl,hl
            add hl,de
            ld de,fx_assets
            add hl,de
            ld a,(hl)
            ld (native32_from),a
            inc hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld c,(hl)
            inc hl
            ld b,(hl)
            ex de,hl
            ld de,FX_BUF
            jp native32_copy

; ---------------------------------------------------------------------------
; Battle art caches. The current area's room stays unpacked in RAM 27 ($0000)
; and its likely monsters in four slots, loaded when the area is entered, so
; a random encounter only has to copy its art into the PCG.
bt_slots:   db 27,$40, 29,$00, 29,$40, 26,$00      ; block, page (26: the Ghost)

bt_room_index:
            ld a,(mb_mode)
            or a
            ld a,(cur_area)
            ret z
            add a,6
            ret

; Unpack the current room if RAM 27 does not hold it; open it.
bt_room:    call bt_room_index
            ld c,a
            inc a
            ld hl,bt_room_tag
            ld de,27*256
            cp (hl)
            jr z,bt_open
            ld (hl),a
            ld a,c
            ld hl,bt_rooms
            push de
            call bt_unpack_to
            pop de
; D block, E page: map it; HL = packet data, BC = glyph bytes.
bt_open:    ld a,d
            ld (native32_from),a
            call mb_bank
            ld h,e
            ld l,0
            ld c,(hl)
            inc hl
            ld b,(hl)
            inc hl
            ret

; A monster packet: from its cache slot, or unpacked into RAM 2; opened.
bt_monster: call bt_find
            jr z,bt_open
            ld hl,bt_sprites
            ld de,2*256
            push de
            call bt_unpack_to
            pop de
            jr bt_open

; A packet index. Z: DE = its slot (block, page), A = slot number.
; NZ: not cached, A unchanged.
bt_find:    ld c,a
            inc a
            ld hl,bt_slot_tag
            ld b,0
.f:         cp (hl)
            jr z,.hit
            inc hl
            inc b
            bit 2,b
            jr z,.f
            ld a,c
            ret                     ; NZ from bit 2,b
.hit:       ld a,b
            add a,a
            ld e,a
            ld d,0
            ld hl,bt_slots
            add hl,de
            ld d,(hl)
            inc hl
            ld e,(hl)
            ld a,b
            cp a
            ret

; HL packet table, A index, D block, E page: unpack it there.
bt_unpack_to:
            push de
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
            pop de
            ld a,d
            ld (unpack_bank),a
            call mb_bank
            ld d,e
            ld e,0
            call native_unpack
            xor a
            ld (unpack_bank),a
            ret

; A encounter monster (1-based) -> its packet index; carry if none or a boss.
bt_wanted:  or a
            scf
            ret z
            dec a
            ld c,a
            ld a,(mb_mode)
            or a
            ld a,c
            jr z,.ix
            add a,12
.ix:        ld c,a
            ld l,a
            ld h,0
            ld e,l
            ld d,h
            add hl,hl
            add hl,de
            ld de,bt_sprites
            add hl,de
            ld a,(hl)
            cp 1                    ; bank 0: composed lair, not a room fight
            ld a,c
            ret

; Entering an area: unpack its room and its encounter monsters ahead of time.
bt_preload: call bt_room
            xor a
            ld (bt_kept),a
            ld hl,enc_list          ; keep the slots that already hold one
            ld b,3
.keep:      push bc
            push hl
            ld a,(hl)
            call bt_wanted
            jr c,.k1
            call bt_find
            jr nz,.k1
            ld b,a
            inc b
            ld a,$80
.bit:       rlca
            djnz .bit
            ld hl,bt_kept
            or (hl)
            ld (hl),a
.k1:        pop hl
            pop bc
            inc hl
            djnz .keep
            ld hl,enc_list          ; then unpack the rest into free slots
            ld b,3
.load:      push bc
            push hl
            ld a,(hl)
            call bt_wanted
            jr c,.l1
            call bt_find
            jr z,.l1
            ld c,a
            ld b,3                  ; the Ghost needs all of RAM 26
            cp 2
            jr z,.slot
            cp 14
            jr z,.slot
            ld a,(bt_kept)
            ld b,0
.free:      rrca
            jr nc,.slot
            inc b
            ld e,a
            ld a,b
            cp 3
            ld a,e
            jr c,.free
            jr .l1                  ; (cannot happen: three slots for three)
.slot:      push bc
            ld a,1                  ; mark the slot used
            inc b
.mask:      dec b
            jr z,.marked
            rlca
            jr .mask
.marked:    ld hl,bt_kept
            or (hl)
            ld (hl),a
            pop bc
            ld a,c
            inc a
            ld e,b
            ld d,0
            ld hl,bt_slot_tag
            add hl,de
            ld (hl),a               ; the tag
            ld hl,bt_slots
            add hl,de
            add hl,de
            ld d,(hl)
            inc hl
            ld e,(hl)
            ld a,c
            ld hl,bt_sprites
            call bt_unpack_to
.l1:        pop hl
            pop bc
            inc hl
            djnz .load
            ld a,1
            jp mb_bank
