; Native exploration and text surfaces. Work RAM 1: 3200 ASCII, 3600 colours.
; RAM 2 retains the current atlas; RAM 3 holds the composed screen.
world_reset:
            push af
            push bc
            push de
            push hl
            ld a,(native_battle_active)
            or a
            jr nz,.done
            ld a,2
            ld (world_screen),a
            ld a,1
            ld (world_changed),a
            ld hl,$3A00
            ld b,64
.sig:       ld (hl),$A5
            inc l
            djnz .sig
            ld hl,$3200
            ld de,$3201
            ld bc,2047
            ld (hl),0
            ldir
.done:      pop hl
            pop de
            pop bc
            pop af
            ret

world_view:
            ld a,(world_screen)
            cp 1
            ld a,1
            ld (world_screen),a
            ld (vp_dirty),a
            ret z                   ; already exploring: redraw the view only
            ld (world_changed),a
            ret

; Each of the 32 text rows keeps a signature of what was written to it since
; the last present (RAM1 $3A00), next to the signature last shown ($3A40).
; A = text row, C = value to fold in. Zero means "not touched".
ui_mix:     push hl
            push de
            add a,a
            ld l,a
            ld h,$3A
            ld e,(hl)
            inc l
            ld d,(hl)
            ex de,hl
            add hl,hl
            jr nc,.n
            inc l
.n:         ld a,l
            xor c
            ld l,a
            or h
            jr nz,.ok
            inc l
.ok:        ex de,hl
            ld (hl),d
            dec l
            ld (hl),e
            pop de
            pop hl
            ret

; Hook original fills so erased text cannot survive in the native layer.
world_erase:
            push af
            push bc
            push de
            push hl
            ld a,(native_battle_active)
            or a
            jr nz,.done
            ld a,e
            or a
            jr z,.done
            ld a,d
            add a,e
            dec a
            srl a
            ld e,a
            srl d
.row:       push bc
            ld a,b
            rlca
            rlca
            rlca
            xor c
            xor $5A
            ld c,a
            ld a,d
            call ui_mix
            pop bc
            ld l,d
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            push bc
            ld b,$32
            add hl,bc
            pop bc
            push bc
.col:       ld (hl),0
            inc hl
            djnz .col
            pop bc
            ld a,d
            inc d
            cp e
            jr c,.row
.done:      pop hl
            pop de
            pop bc
            pop af
            ret

world_char:
            push af
            push bc
            push de
            push hl
            ld e,a
            ld a,(native_battle_active)
            or a
            jr nz,.done
            ld a,c
            cp 32
            jr nc,.done
            ld a,d
            cp 62
            jr nc,.done
            srl a
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld b,$32
            add hl,bc
            ld (hl),e
            push bc
            ld a,l
            rlca
            rlca
            rlca
            and 7
            ld b,a
            ld a,h
            sub $32
            add a,a
            add a,a
            add a,a
            or b
            ld b,a
            ld c,l
            call ui_mix
            ld a,b
            ld c,e
            call ui_mix
            ld a,(txt_bg)
            add a,a
            add a,a
            ld c,a
            ld a,(txt_fg)
            xor c
            ld c,a
            ld a,b
            call ui_mix
            pop bc
            ld a,h
            add a,4
            ld h,a
            ld a,(txt_bg)
            cp 3
            ld a,$F0
            jr z,.store
            ld a,(txt_fg)
            and 3
            ld de,world_inks
            push hl
            ld l,a
            ld h,0
            add hl,de
            ld a,(hl)
            pop hl
.store:     ld (hl),a
.done:      pop hl
            pop de
            pop bc
            pop af
            ret
world_inks: db 14,15,7,11

world_present:
            push ix
            call world_load
            ld a,(world_screen)
            cp 1
            jp z,world_present_maze
            ld a,3
            call mb_bank
            ld hl,$5F00
            ld de,0
            call native32_copy_local
            ld a,1
            call mb_bank
            ld a,(world_screen)
            cp 3
            call z,world_map
            ld a,(world_screen)
            cp 3
            call nz,world_text
            xor a
            call world_bounds
world_commit:
            ld a,2
            ld (native32_scene),a
            ld a,(world_changed)
            or a
            call nz,native32_blank
            xor a
            ld (world_changed),a
            call native32_commit
            pop ix
            ret

; Exploration. The first-person view is composed in VPBUF and copied straight
; to the screen; the panel and message text only go through the slower
; compare-and-update path when their signature says something changed.
world_present_maze:
            ld a,(vp_dirty)
            ld hl,world_changed
            or (hl)
            jr z,.drawn
            call vp_compose
            call snd_tick           ; drawing took a frame: keep the tune in time
.drawn:
            call ui_scan
            ld b,a
            ld a,(world_changed)
            or a
            jr nz,.full
            ld a,b
            or a
            call nz,ui_partial
            ld a,(vp_dirty)
            or a
            jr z,.done
            call wait_frame
            call vp_blit
            call snd_tick
            xor a
            ld (vp_dirty),a
.done:      pop ix
            ret
.full:      ld a,3
            call mb_bank
            ld hl,$6E00
            ld de,0
            call native32_copy_local
            ld a,1
            call mb_bank
            call world_text
            call world_stats
            call vp_to_target
            xor a
            ld (vp_dirty),a
            call world_bounds
            jp world_commit

; Which screen rows hold changed text or bars? Flags at RAM1 $3A80; A != 0 if any.
ui_scan:    ld hl,$3A80
            ld b,33
.clear:     ld (hl),0
            inc l
            djnz .clear
            ld hl,$3A00
            ld b,32
            ld c,0
.row:       ld e,(hl)
            inc l
            ld d,(hl)
            dec l
            ld a,d
            or e
            jr z,.next
            ld (hl),0
            inc l
            ld (hl),0
            dec l
            push hl
            set 6,l
            ld a,(hl)
            cp e
            jr nz,.diff
            inc l
            ld a,(hl)
            dec l
            cp d
            jr z,.same
.diff:      ld (hl),e
            inc l
            ld (hl),d
            ld a,l
            and $3E
            rrca
            or $80
            ld l,a
            ld (hl),1
            inc l
            ld (hl),1
            ld c,1
.same:      pop hl
.next:      inc l
            inc l
            djnz .row
            ld a,(hp)
            ld d,a
            ld a,(maxhp)
            rlca
            xor d
            ld d,a
            ld a,(mp)
            rlca
            rlca
            rlca
            xor d
            ld d,a
            ld a,(maxmp)
            rrca
            xor d
            ld hl,ui_stats
            cp (hl)
            jr z,.done
            ld (hl),a
            ld a,1
            ld ($3A80+11),a
            ld ($3A80+15),a
            ld c,a
.done:      ld a,c
            or a
            ret

; Redraw only the flagged rows of the panel and message area.
ui_partial: ld hl,$3A80
            ld de,$E300
            ld bc,33
            ldir
            ld a,3
            call mb_bank
            xor a
            ld hl,0
.row:       push af
            push hl
            ld e,a
            ld d,$E3
            ld a,(de)
            or a
            jr z,.next
            ld a,e
            cp 24
            ld bc,27
            jr c,.left
            ld c,0
.left:      add hl,bc
            ld a,40
            sub c
            ld c,a
            ld a,3
.plane:     push af
            push hl
            push bc
            ex de,hl
            ld hl,$6E00
            add hl,de
            ldir
            pop bc
            pop hl
            ld de,$0500
            add hl,de
            pop af
            dec a
            jr nz,.plane
.next:      pop hl
            ld de,40
            add hl,de
            pop af
            inc a
            cp 32
            jr nz,.row
            ld a,1
            call mb_bank
            ld a,1
            ld (ui_filter),a
            call world_text
            xor a
            ld (ui_filter),a
            ld a,($3A80+11)
            ld hl,$3A80+15
            or (hl)
            call nz,world_stats
            ld a,3
            call mb_bank
            xor a
            out ($0B),a
            out ($08),a
            ld a,$80
            out ($1C),a
            ld hl,0
            ld de,$F000
            call .pass
            ld a,$90
            out ($1C),a
            ld hl,$0500
            ld de,$F000
            call .pass
            ld a,$80
            out ($1C),a
            ld a,$40
            out ($08),a
            ld hl,$0A00
            ld de,$F800
            call .pass
            xor a
            out ($08),a
            ld a,1
            jp mb_bank
; HL = work plane, DE = screen plane: show flagged rows and note them as displayed
.pass:      ld ix,$E300
            ld b,32
.prow:      ld a,(ix+0)
            or a
            jr z,.skip
            push bc
            push hl
            push de
            ld a,b
            cp 9
            ld bc,40
            jr c,.copy
            ld c,27
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            ld c,13
.copy:      push hl
            push bc
            ldir
            pop bc
            pop hl
            ld d,h
            ld e,l
            ld a,d
            add a,$10
            ld d,a
            ldir
            pop de
            pop hl
            pop bc
.skip:      push bc
            ld bc,40
            add hl,bc
            ex de,hl
            add hl,bc
            ex de,hl
            pop bc
            inc ix
            djnz .prow
            ret

; A = first column to examine on the 24 view rows; text rows use every column.
world_bounds:
            push af
            ld a,3
            call mb_bank
            pop af
            ld hl,$3200
            ld b,24
.view:      ld (hl),a
            inc hl
            djnz .view
            ld b,8
.text:      ld (hl),0
            inc hl
            djnz .text
            ld b,32
.right:     ld (hl),39
            inc hl
            djnz .right
            ld a,1
            jp mb_bank

world_load:
            ld a,(world_screen)
            cp 1
            jr z,.maze
            sub 2
            add a,12
            ld c,a
            ld a,(mb_mode)
            add a,a
            add a,c
            jr .index
.maze:
            ld a,(cur_area)
            cp 6
            jr c,.area
            xor a
.area:      ld c,a
            ld a,(mb_mode)
            or a
            ld a,c
            jr z,.index
            add a,6
.index:     inc a
            ld c,a
            ld a,(world_loaded)
            cp c
            ret z
            ld a,1
            ld (world_changed),a
            push bc
            call native_enter
            call native32_blank
            call native32_font
            pop bc
            ld a,c
            ld (world_loaded),a
            dec a
            ld l,a
            ld h,0
            ld e,l
            ld d,h
            add hl,hl
            add hl,de
            ld de,world_assets
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
            ld (world_bank),a
            ld a,(world_screen)
            cp 1
            jr nz,.unpack
            ; The area's art stays resident in blocks 28 and 31, so coming
            ; back from the map or a fight only has to refill the PCG.
            ld a,28
            ld (world_bank),a
            ld a,(world_loaded)
            cp 7
            jr c,.which
            sub 6
.which:     ld hl,area_loaded
            cp (hl)
            jr z,.glyphs
            ld (hl),a
.unpack:    ld a,(world_bank)
            ld (unpack_bank),a
            call mb_bank
            ld de,0
            call native_unpack
            xor a
            ld (unpack_bank),a
            ld a,(world_screen)
            cp 1
            jr nz,.page
            ; ---- area atlas: glyphs and floor objects live in block 31
            ld a,(4)
            ld (world_decors),a
            ld hl,(0)
            ld (vp_n),hl
            ld hl,(48)
            ld (vp_objtab),hl
            ld a,(world_loaded)
            dec a
            cp 6
            jr c,.second
            sub 6
.second:    ld l,a
            ld h,0
            ld e,l
            ld d,h
            add hl,hl
            add hl,de
            ld de,world_assets2
            add hl,de
            ld a,1
            call mb_bank
            ld a,(hl)
            ld (native_bank),a
            inc hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            ld (native_src),de
            xor a
            ld (native_left),a
            ld a,31
            ld (unpack_bank),a
            call mb_bank
            ld de,0
            call native_unpack
            xor a
            ld (unpack_bank),a
.glyphs:    xor a
            out ($08),a
            out ($0B),a
            ld a,31
            call mb_bank
            ld hl,0
            ld bc,(vp_n)
            call vp_upload
            jr .done
.page:      ld bc,(0)
            ld hl,(2)
            ld a,(44)
            add a,$80
            ld d,a
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
            ld hl,0
            call world_piece
            ld a,(world_screen)
            cp 1
            jr nz,.cache
            ld a,(mb_mode)
            or a
            jr z,.cache
            ; one-colour monitors: the panel frame is plain white on black
            ld a,3
            call mb_bank
            ld hl,$0A00
            ld de,$0A01
            ld bc,1279
            ld (hl),15
            ldir
.cache:     ld a,3
            call mb_bank
            ld hl,0
            ld de,$6E00
            call native32_copy_local
            ld hl,1
            call world_piece
            ld a,3
            call mb_bank
            ld hl,0
            ld de,$5F00
            call native32_copy_local
            ld a,1
            jp mb_bank

; HL = component number; run stream in atlas: count, offset, code/attr/colour.
world_piece:
            add hl,hl
            ld de,64
            add hl,de
            ld a,(world_bank)
            call mb_bank
            ld e,(hl)
            inc hl
            ld d,(hl)
            ex de,hl
.run:       ld a,(hl)
            inc hl
            or a
            jr z,.done
            ld (world_count),a
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            push de
            ld a,(world_count)
            ld c,a
            add a,a
            add a,c
            ld c,a
            ld b,0
            ld de,$E300
            ldir
            pop de
            push hl
            ld hl,$E300
            ld a,3
            call mb_bank
            ld a,3
            ld (world_planes),a
.plane:     push de
            ld a,(world_count)
            ld c,a
            ld b,0
            ldir
            pop de
            ld a,d
            add a,5
            ld d,a
            ld a,(world_planes)
            dec a
            ld (world_planes),a
            jr nz,.plane
            pop hl
            ld a,(world_bank)
            call mb_bank
            ld a,(world_service)
            inc a
            and 15
            ld (world_service),a
            jr nz,.run
            push hl
            call wait_frame
            pop hl
            jr .run
.done:      ld a,1
            jp mb_bank

; ---------------------------------------------------------------------------
; First-person view. Every wall, decoration and background is a list of
; whole-cell runs aimed straight at the work buffer, so a scene is a handful
; of block copies. Floor objects are merged with what is behind them.
; ---------------------------------------------------------------------------
VPBUF       equ $DA60
VPPLANE     equ 640

vp_compose: call sample_view
            call max_depth
            ld (rv_d),a
            ld a,(world_bank)
            call mb_bank
            ld hl,(50)
            ld de,VPBUF
            ld bc,624
            ldir
            ld de,VPBUF+VPPLANE
            ld bc,624
            ldir
            ld de,VPBUF+2*VPPLANE
            ld bc,624
            ldir
            ld a,(pdir)
            or a
            jr nz,.walls
            ld hl,(46)
            ld a,h
            or l
            call nz,vp_runs
.walls:     ld a,1
            call mb_bank
.depth:     ld hl,lat_order
.lat:       ld a,(hl)
            cp $80
            jr z,.next
            inc hl
            push hl
            ld (rv_l),a
            call vp_cell
            pop hl
            jr .lat
.next:      ld a,(rv_d)
            dec a
            ld (rv_d),a
            jp p,.depth
            ld a,(mb_mode)
            or a
            ret z
            ld hl,VPBUF+2*VPPLANE
            ld de,VPBUF+2*VPPLANE+1
            ld bc,623
            ld (hl),15
            ldir
            ret

vp_cell:    ld a,(rv_d)
            ld c,a
            add a,a
            add a,a
            add a,c
            ld c,a
            ld a,(rv_l)
            add a,2
            add a,c
            ld (world_position),a
            ld l,a
            ld h,0
            ld de,view_cells
            add hl,de
            ld a,(hl)
            ld (rv_cell),a
            call classify
            ld (rv_kind),a
            ld a,c
            ld (rv_decor),a
            ld a,(rv_kind)
            or a
            jr z,.object
            dec a
            ld hl,3
            jr z,.wall
            ld hl,23
.wall:      ld a,(world_position)
            ld e,a
            ld d,0
            add hl,de
            call vp_piece
            ld a,(rv_decor)
            or a
            ret z
            dec a
            add a,a
            ld c,a
            ld a,(rv_kind)
            dec a
            add a,c
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            ld e,l
            ld d,h
            add hl,hl
            add hl,hl
            add hl,de
            ld de,43
            add hl,de
            ld a,(world_position)
            ld e,a
            ld d,0
            add hl,de
            jr vp_piece
.object:    ld a,(rv_cell)
            and 7
            ret nz
            ld a,(rv_cell)
            rrca
            rrca
            rrca
            and 31
            ret z
            call event_sprite
            or a
            ret z
            ld c,a
            ld a,(rv_l)
            or a
            ret nz
            ld a,(rv_d)
            or a
            ret z
            ld b,a
            jr vp_object

; HL = piece number
vp_piece:   add hl,hl
            ld de,64
            add hl,de
            ld a,(world_bank)
            call mb_bank
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            call vp_runs
            ld a,1
            jp mb_bank

; HL -> runs: count, buffer address, codes, attributes, colours
vp_runs:    ld b,0
.run:       ld a,(hl)
            or a
            ret z
            inc hl
            ld c,a
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            push de
            ldir
            pop de
            push hl
            ld hl,VPPLANE
            add hl,de
            ex de,hl
            pop hl
            ld c,a
            push de
            ldir
            pop de
            push hl
            ld hl,VPPLANE
            add hl,de
            ex de,hl
            pop hl
            ld c,a
            ldir
            jr .run

; C = object 1.., B = depth 1..3. Each cell: buffer address, ink, 8 mask
; bytes (1 = keep what is behind), 8 pattern bytes. The merged cells become
; temporary glyphs in PCG bank 13, in a fixed range per depth.
vp_object:  ld a,31
            call mb_bank
            xor a
            out ($08),a
            ld a,$8D
            out ($1C),a
            ld a,c
            dec a
            ld l,a
            ld h,0
            add hl,hl
            ld e,l
            ld d,h
            add hl,hl
            add hl,de
            ld a,b
            dec a
            add a,a
            ld e,a
            ld d,0
            add hl,de
            ld de,(vp_objtab)
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            or h
            jr z,.done
            push hl
            pop ix
            ld hl,vp_slots-1
            ld e,b
            ld d,0
            add hl,de
            ld a,(hl)
            ld (vp_slot),a
.cell:      ld e,(ix+0)
            ld d,(ix+1)
            ld a,d
            inc a
            jr z,.done
            ld hl,VPPLANE
            add hl,de
            ld b,(hl)
            ld a,(de)
            and 127
            ld c,a
            call vp_glyph
            push de
            ld a,(vp_slot)
            ld e,a
            ld d,0
            ex de,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,h
            or $F8
            ld h,a
            ex de,hl
            ld b,8
.line:      ld a,(hl)
            and (ix+3)
            or (ix+11)
            ld (de),a
            inc hl
            inc de
            inc ix
            djnz .line
            pop de
            ld a,(vp_slot)
            ld c,a
            inc a
            ld (vp_slot),a
            ld a,c
            or $80
            ld (de),a
            ld hl,VPPLANE
            add hl,de
            ld (hl),13
            ld a,(ix-6)
            or a
            jr z,.keep
            ld bc,VPPLANE
            add hl,bc
            ld (hl),a
.keep:      ld bc,11
            add ix,bc
            jr .cell
.done:      ld a,$80
            out ($1C),a
            ld a,1
            jp mb_bank
vp_slots:   db 0,80,112

; B = PCG bank of a cell, C = its slot -> HL = that glyph's 8 bytes (block 31)
vp_glyph:   ld a,b
            cp 13
            jr c,.atlas
            jr z,.blank
            ld a,c
            sub 96
            jr c,.blank
            ld l,a
            ld a,b
            sub 14
            rrca
            rrca
            rrca
            add a,l
            ld l,a
            ld h,0
            ld bc,1664
            add hl,bc
            jr .scale
.atlas:     ld h,b
            ld l,c
            srl h
            jr nc,.scale
            set 7,l
.scale:     add hl,hl
            add hl,hl
            add hl,hl
            ret
.blank:     ld hl,0
            ret

; HL = 26-wide source rows, DE = 40-wide destination rows, 24 rows
vp_rows:    ld a,24
.row:       ld bc,26
            ldir
            ex de,hl
            ld bc,14
            add hl,bc
            ex de,hl
            dec a
            jr nz,.row
            ret

vp_blit:    xor a
            out ($0B),a
            out ($08),a
            ld a,$80
            out ($1C),a
            ld hl,VPBUF
            ld de,$F000
            call vp_rows
            ld a,$90
            out ($1C),a
            ld hl,VPBUF+VPPLANE
            ld de,$F000
            call vp_rows
            ld a,$80
            out ($1C),a
            ld a,$40
            out ($08),a
            ld hl,VPBUF+2*VPPLANE
            ld de,$F800
            call vp_rows
            xor a
            out ($08),a
            ret

vp_to_target:
            ld a,3
            call mb_bank
            ld hl,VPBUF
            ld de,0
            call vp_rows
            ld hl,VPBUF+VPPLANE
            ld de,$0500
            call vp_rows
            ld hl,VPBUF+2*VPPLANE
            ld de,$0A00
            call vp_rows
            ld a,1
            jp mb_bank

; HL = glyph data (block 31), BC = glyph count. Banks 0..12 in full, then the
; 32 spare slots after the lettering in banks 14 and 15.
vp_upload:  ld a,$80
.bank:      ld (vp_port),a
            out ($1C),a
            ld de,$F800
            ld a,128
            call .some
            ret z
            ld a,(vp_port)
            inc a
            cp $8D
            jr nz,.bank
            ld a,$8E
            out ($1C),a
            ld de,$FE00
            ld a,32
            call .some
            ret z
            ld a,$8F
            out ($1C),a
            ld de,$FE00
            ld a,32
.some:      ld (vp_left),a
.glyph:     ld a,b
            or c
            ret z
            push bc
            ld bc,8
            ldir
            ex de,hl
            ld c,8
            add hl,bc
            ex de,hl
            pop bc
            dec bc
            ld a,(vp_left)
            dec a
            ld (vp_left),a
            jr nz,.glyph
            or 1
            ret

world_text:
            ld ix,$3200
            ld de,$F004
            ld b,31
.row:       ld a,(ui_filter)
            or a
            jr z,.go
            ld a,31
            sub b
            or $80
            ld l,a
            ld h,$3A
            ld a,(hl)
            inc l
            or (hl)
            jr nz,.go
            push bc
            ld bc,32
            add ix,bc
            pop bc
            ld hl,40
            add hl,de
            ex de,hl
            djnz .row
            ret
.go:        push bc
            ld c,0
.char:      ld a,(ix+0)
            or a
            jr z,.next
            push bc
            push de
            push af
            ld a,(world_screen)
            cp 1
            jr nz,.position
            ld a,c
            cp 20
            jr c,.position
            ld a,d
            cp $F4
            jr nc,.position
            inc de
            inc de
            inc de
.position:  push ix
            pop hl
            ld bc,$0400
            add hl,bc
            ld c,(hl)
            ld a,(mb_mode)
            or a
            jr z,.colour
            ld a,c
            cp $F0
            jr z,.colour
            ld c,15
.colour:    ld a,3
            call mb_bank
            pop af
            sub 32
            and 127
            or 128
            call native32_char
            ld a,1
            call mb_bank
            pop de
            pop bc
.next:      inc ix
            inc de
            inc c
            ld a,c
            cp 32
            jr nz,.char
            ld hl,8
            add hl,de
            ex de,hl
            pop bc
            dec b
            jp nz,.row
            ret

world_map:
            ld b,0
.row:       ld c,0
.cell:      push bc
            call map_cell_byte
            ld e,0
            cp $AA
            jr z,.kind
            inc e
            cp $FF
            jr z,.kind
            inc e
            cp $55
            jr z,.kind
            inc e
            cp $3C
            jr z,.kind
            inc e
.kind:      ld a,(px)
            cp c
            jr nz,.icon
            ld a,(py)
            cp b
            jr nz,.icon
            ld a,(map_blink)
            and 16
            jr nz,.icon
            ld a,(pdir)
            add a,5
            ld e,a
.icon:      ld a,e
            ld l,a
            ld h,0
            ld d,h
            add hl,hl
            add hl,de
            ld de,8
            add hl,de
            ld a,(world_bank)
            call mb_bank
            ld a,(hl)
            inc hl
            ld (world_icon),a
            ld a,(hl)
            inc hl
            ld (world_icon+1),a
            ld a,(hl)
            ld (world_icon+2),a
            ld a,1
            call mb_bank
            pop bc
            push bc
            ld a,b
            add a,10
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld e,l
            ld d,h
            add hl,hl
            add hl,hl
            add hl,de
            ld b,0
            add hl,bc
            ld de,$F006
            add hl,de
            ex de,hl
            ld a,3
            call mb_bank
            ld a,(world_icon+1)
            ld b,a
            ld a,(world_icon+2)
            ld c,a
            ld a,(world_icon)
            call native_battle_cell
            ld a,1
            call mb_bank
            pop bc
            inc c
            ld a,c
            cp 16
            jp nz,.cell
            inc b
            ld a,b
            cp 16
            jp nz,.row
            ld a,5
            ld de,$F000+14*40+25
            call world_symbol
            ld a,2
            ld de,$F000+17*40+25
            call world_symbol
            ld a,1
            ld de,$F000+20*40+25
            call world_symbol
            ld a,3
            ld de,$F000+23*40+25
            call world_symbol
            ld hl,world_map_title
            ld de,$F000+9*40+29
            call native_text
            ld hl,world_you
            ld de,$F000+14*40+27
            call world_paper_text
            ld hl,world_door
            ld de,$F000+17*40+27
            call world_paper_text
            ld hl,world_wall
            ld de,$F000+20*40+27
            call world_paper_text
            ld hl,world_object
            ld de,$F000+23*40+27
            call world_paper_text
            ld hl,world_back
            ld de,$F000+27*40+26
            call native_text
            ld hl,(area_name)
            ld de,$F000+7*40+6
            call world_paper_text
            ld a,1
            jp mb_bank
world_map_title: db "MAP",0
world_you: db "YOU",0
world_door: db "DOOR",0
world_wall: db "WALL",0
world_object: db "OBJECT",0
world_back: db "M: BACK",0
world_paper_text:
            ld c,$B0
            ld a,(mb_mode)
            or a
            jr z,.draw
            ld c,$F0
.draw:      jp native_text_colour

; A = atlas symbol, DE = screen cell. Preserve no scratch registers.
world_symbol:
            push de
            ld l,a
            ld h,0
            ld e,l
            ld d,h
            add hl,hl
            add hl,de
            ld de,8
            add hl,de
            ld a,(world_bank)
            call mb_bank
            ld a,(hl)
            ld (world_icon),a
            inc hl
            ld b,(hl)
            inc hl
            ld c,(hl)
            ld a,(mb_mode)
            or a
            jr z,.ink
            ld c,15
.ink:       pop de
            ld a,3
            call mb_bank
            ld a,(world_icon)
            call native_battle_cell
            ld a,1
            jp mb_bank

world_stats:
            ld a,9
            ld (world_barfull),a
            ld a,(maxhp)
            ld c,a
            ld a,(hp)
            ld de,$F000+11*40+28
            call world_bar
            ld a,11
            ld (world_barfull),a
            ld a,(maxmp)
            ld c,a
            ld a,(mp)
            ld de,$F000+15*40+28
world_bar:
            push de
            ld e,10
            call mul8
            call div_hl_c
            cp 11
            jr c,.bounded
            ld a,10
.bounded:   ld c,a
            pop de
            ld b,10
.cell:      ld a,c
            or a
            ld a,10
            jr z,.draw
            dec c
            ld a,(world_barfull)
.draw:      push bc
            push de
            call world_symbol
            pop de
            pop bc
            inc de
            djnz .cell
            ret

world_cutscene:
            cp 1
            ld a,1
            jr z,world_cinema
            ld a,3
world_cinema:
            ld (native_monster),a
            call native_enter
            call native_group_load
            xor a
            ld (native_frame),a
.pose:      call native_group_show
            ld b,12
            call wait_frames
            call read_input
            ld a,(any_key)
            or a
            jr nz,.finish
            ld a,(native_frame)
            inc a
            ld (native_frame),a
            cp 3
            jr c,.pose
            xor a
.finish:    push af
            call native_leave
            pop af
            ret

world_code_end:
            noemit
            org $E380
world_screen: ds 1
world_loaded: ds 1
world_changed: ds 1
world_decors: ds 1
world_count: ds 1
world_position: ds 1
world_icon: ds 3
world_service: ds 1
world_planes: ds 1
world_barfull: ds 1
vp_dirty:   ds 1
ui_filter:  ds 1
ui_stats:   ds 1
vp_objtab:  ds 2
vp_n:       ds 2
vp_slot:    ds 1
vp_port:    ds 1
vp_left:    ds 1
unpack_bank: ds 1
world_bank:  ds 1
area_loaded: ds 1
            assert $ <= $E400
            emit
            org world_code_end
