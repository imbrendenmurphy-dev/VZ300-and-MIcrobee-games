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
            jp native_group_load

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
            ld (de),a
            ld a,e
            add a,96
            ld e,a
            ld a,(txt_bg)
            cp 3
            ld a,$0F
            jr nz,.colour
            ld a,$F0            ; selected command: reverse video in both modes
.colour:    ld (de),a
.done:      pop hl
            pop de
            pop bc
            pop af
            ret

native_battle_clear:
            push af
            push bc
            push de
            push hl
            ld a,(native_battle_active)
            or a
            jr z,.done
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

native_battle_present:
            call native_anim_battle
            ld a,(bt_mhp)
            or a
            jr nz,.show
            ld a,(bt_dying)
            or a
            jr nz,.dissolve
            ld a,3
            ld (native_frame),a
            jr .show
.dissolve:  call native_battle_dissolve
.show:      jp native_group_show

; HL selected frame map in block 3. Recompose displaced monster cells over
; the clean backdrop into 0000, leaving every original animation map intact.
native_battle_prepare:
            ld a,(native_battle_active)
            or a
            ret z
            ld a,(bt_dx)
            ld c,a
            ld a,(bt_dy)
            or c
            ret z
            ld (native_map_src),hl
            ld a,(bt_dx)
            ld e,a
            add a,a
            sbc a,a
            ld d,a
            ld hl,0
            ld a,(bt_dy)
            or a
            jr z,.offset
            ld b,a
            ld hl,40
            dec b
            jr z,.offset
            add hl,hl
.offset:    add hl,de
            ld (native_shift),hl
            ld hl,$2000
            ld de,$0000
            call native32_copy_local
            ld hl,(native_map_src)
            ld de,90
            add hl,de
            ld de,$2000+90
            ld b,23
.row:       push bc
            ld bc,20
.cell:      push bc
            push hl
            push de
            call native_battle_equal
            jr z,.next
            push hl
            ld de,(native_map_src)
            or a
            sbc hl,de
            ld de,$0000
            add hl,de
            ld de,(native_shift)
            add hl,de
            ex de,hl
            pop hl
            ld a,(hl)
            ld (de),a
            ld bc,1280
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            ld a,(hl)
            ld (de),a
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            ld a,(hl)
            ld (de),a
.next:      pop de
            pop hl
            pop bc
            inc hl
            inc de
            dec bc
            ld a,b
            or c
            jr nz,.cell
            ld bc,20
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            pop bc
            ld a,b
            and 7
            jr nz,.rowdone
            push bc
            push de
            push hl
            call wait_frame
            pop hl
            pop de
            pop bc
.rowdone:   djnz .row
            ld hl,$0000
            ret

native_battle_equal:
            push hl
            push de
            ld a,(de)
            cp (hl)
            jr nz,.done
            ld bc,1280
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            ld a,(de)
            cp (hl)
            jr nz,.done
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            ld a,(de)
            cp (hl)
.done:      pop de
            pop hl
            ret

; Replace a growing, spatially distributed set of cells with the backdrop.
; Mutate cached maps only; shared glyphs stay intact.
native_battle_dissolve:
            ld a,(native_death)
            inc a
            cp 17
            jr c,.level
            ld a,16
.level:     ld (native_death),a
            ld a,3
            call mb_bank
            ld a,(native_frame)
            call native32_frame_ptr
            ex de,hl
            ld hl,$2000
            ld bc,3840
.byte:      ld a,c
            and 15
            push hl
            ld hl,native_death
            cp (hl)
            pop hl
            jr nc,.skip
            ld a,(hl)
            ld (de),a
.skip:      inc hl
            inc de
            dec bc
            ld a,b
            or c
            jr nz,.byte
            ld a,1
            jp mb_bank

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
            ld a,(bt_flash)
            or a
            call nz,native_battle_flash
            call native_battle_effect
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

; Flash the monster's central silhouette region without changing its bitmap.
native_battle_flash:
            ld hl,$0A00+2*40+10
            ld a,(native_page)
            or a
            jr z,.page
            ld hl,$0A00+2*40+10
.page:      ld b,23
.row:       push bc
            ld b,20
.cell:      ld a,(hl)
            ld c,a
            ld a,(mb_mode)
            or a
            ld a,c
            jr z,.colour
            xor $FF
            jr .store
.colour:    and $F0
            or 15
.store:     ld (hl),a
            inc hl
            djnz .cell
            ld de,20
            add hl,de
            pop bc
            djnz .row
            xor a
            out ($08),a
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
