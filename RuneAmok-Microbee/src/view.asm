; =====================================================================
;  VIEW: compose the first-person view into the shadow (SHC/SHA/SHK)
;  from tile lists - no pixel is drawn at run time.
;
;  1. the backdrop (ceiling and floor) of the level
;  2. walls, near to far: the first solid slot over a column fills it
;     (its depth key goes in zkey[], the slot in zown[])
;  3. decorations on front faces that won their columns
;  4. sprites (items, then creatures) far to near, only in columns whose
;     wall is farther than the square they stand in
;  5. cells with an animated colour (high nibble) are listed for cycling
;
;  Level block B (mapped low): +0 backdrop, +2 wall table.
;  Level block A: +SPRIDX sprite index (dw per sprite and depth).
; =====================================================================
SPRIDX      EQU $4800

; HL = table of 4 pointers -> HL = the one for (facing)
facing_ptr:
        ld a,(facing)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

compose:
        ld a,(lvl_mpb)
        out (P_MEM),a
        xor a
        ld (nanim),a
        ld hl,zkey
        ld b,VW*2               ; zkey and zown
.z:     ld (hl),255
        inc hl
        djnz .z
        xor a
        ld (nfill),a
        ; 2. walls
        ld hl,slot_offp
        call facing_ptr
        ld (cp_off),hl
        ld ix,slot_tab
        xor a
        ld (cp_slot),a
.slot:  ld hl,(cp_off)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (cp_off),hl
        ld hl,(ppos)
        add hl,de
        ld l,(hl)               ; square type
        ld h,high(kindtab)
        ld a,(hl)
        or a
        jp z,.next
        ; wall table entry: (kind-1) * 64 + slot * 2
        dec a
        rrca
        rrca                    ; (kind-1) * 64 (kind <= 4 fits... kind 5 too: 256 wraps -> use 16 bit)
        ld e,a
        and $C0
        ld l,a
        ld a,e
        and $03
        ld h,a
        ld a,(cp_slot)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld de,(2)               ; wall table
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = column set
        ex de,hl
        ld c,(ix+0)             ; first column
.col:   ld a,c
        cp (ix+1)
        jp z,.next
        ; is the column free?
        ld de,zkey
        ld a,e
        add a,c
        ld e,a
        jr nc,.zz
        inc d
.zz:    ld a,(de)
        inc a
        jr z,.fill
        ; taken: skip the record
        inc hl
        ld a,(hl)               ; n
        inc hl
        ld e,a
        add a,a
        add a,e                 ; 3n
        ld e,a
        ld d,0
        add hl,de
        inc c
        jr .col
.fill:  ld a,(ix+2)
        ld (de),a               ; zkey = depth key
        ld a,e
        add a,zown-zkey
        ld e,a
        jr nc,.zo
        inc d
.zo:    ld a,(cp_slot)
        ld (de),a
        ld a,(nfill)
        inc a
        ld (nfill),a
        ld a,(hl)               ; r0
        inc hl
        ld b,(hl)               ; n
        inc hl
        push bc
        ; DE = SHC + r0*24 + column
        add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,row24
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,SHC
        add hl,de
        ld e,c
        ld d,0
        add hl,de
        ex de,hl                ; DE = destination
        pop hl                  ; HL = codes
        ld a,b
        or a
        jr z,.empty
        call col3
.empty: pop bc
        inc c
        ld a,(nfill)
        cp VW
        jr z,.walls_done
        jp .col
.next:  ld de,5
        add ix,de
        ld a,(cp_slot)
        inc a
        ld (cp_slot),a
        cp NSLOT
        jp nz,.slot
.walls_done:
        ; the backdrop in the columns no wall filled
        ld a,(nfill)
        cp VW
        jr z,.bdone
        ld c,0
.bc:    ld hl,zkey
        ld a,c
        call add_a_hl
        ld a,(hl)
        inc a
        jr nz,.bn
        push bc
        ld l,c                  ; 50 = 32 + 16 + 2
        ld h,0
        add hl,hl               ; 2c
        push hl
        add hl,hl
        add hl,hl
        add hl,hl               ; 16c
        push hl
        add hl,hl               ; 32c
        pop de
        add hl,de
        pop de
        add hl,de               ; 50c
        ld de,(0)
        add hl,de
        inc hl
        inc hl                  ; past r0, n
        ld de,SHC
        ld a,c
        add a,e
        ld e,a
        jr nc,.b1
        inc d
.b1:    ld b,VH
        call col3
        pop bc
.bn:    inc c
        ld a,c
        cp VW
        jr nz,.bc
.bdone: call decor_pass
        call sprite_pass
        jp anim_fix

; ---------------------------------------------------------------------
; col3: B cells, three planes, from HL (codes, then attributes, then
; colours, B each) to DE (row stride 24 in the shadow planes)
; ---------------------------------------------------------------------
col3:   push de
        call .one
        pop de
        push de
        inc d                   ; +384 = +180h
        ld a,e
        add a,$80
        ld e,a
        jr nc,.a
        inc d
.a:     call .one
        pop de
        inc d
        inc d
        inc d                   ; +768
.one:   push bc
        ex de,hl                ; HL = destination, DE = source
        ld a,b
        add a,a
        add a,a                 ; 4 bytes a step
        ld c,a
        ld a,low(.end)
        sub c
        ld (.jp+1),a
        ld a,high(.end)
        sbc a,0
        ld (.jp+2),a
        ld bc,VW
.jp:    jp 0
        REPT VH
        ld a,(de)
        ld (hl),a
        inc de
        add hl,bc
        ENDR
.end:   ex de,hl                ; HL = source, past this plane
        pop bc
        ret

; ---------------------------------------------------------------------
;  decorations: for each front face that can carry one and won its
;  columns, look the face up in the decoration list and draw its sprite
;  DECOR entries: square offset lo, hi (from MAP), side (0-3 = the face
;  looking N E S W), sprite id. FF ends.
; ---------------------------------------------------------------------
decor_pass:
        ld a,(ndecor)
        or a
        ret z
        ld a,(facing)
        add a,2
        and 3
        ld (dp_side),a          ; the face we see looks back at us
        ld hl,df_offp
        call facing_ptr
        ld (dp_off),hl
        ld ix,df_tab
        ld b,NDF
.f:     push bc
        ld hl,(dp_off)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (dp_off),hl
        ld hl,(ppos)
        add hl,de               ; the square
        ld a,(hl)
        or a
        jr z,.n                 ; open floor carries nothing
        cp 16
        jr nc,.n
        call find_decor         ; -> A = sprite id + 1, or 0
        or a
        jr z,.n
        dec a
        ld (sp_id),a
        ld a,(ix+1)
        ld (sp_dz),a
        ld a,(ix+2)
        ld (sp_shift),a
        ld a,(ix+0)
        ld (sp_slot),a
        ld a,255
        ld (sp_key),a           ; drawn where its own face won
        call draw_sprite
.n:     inc ix
        inc ix
        inc ix
        pop bc
        djnz .f
        ; the side walls beside the corridor, one square ahead: their own
        ; sprites (decoration + SDECOR), drawn where their face won
        ld hl,ds_offp
        call facing_ptr
        ld (dp_off),hl
        ld ix,ds_tab
        ld b,NDS
.sf:    push bc
        ld hl,(dp_off)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (dp_off),hl
        ld a,(facing)
        add a,(ix+2)
        and 3
        ld (dp_side),a          ; the face looks across the corridor
        ld hl,(ppos)
        add hl,de
        ld a,(hl)
        or a
        jr z,.sn
        cp 16
        jr nc,.sn
        call find_decor
        or a
        jr z,.sn
        add a,SDECOR-1
        ld (sp_id),a
        ld a,(ix+1)
        ld (sp_dz),a
        xor a
        ld (sp_shift),a
        ld a,(ix+0)
        ld (sp_slot),a
        ld a,255
        ld (sp_key),a
        call draw_sprite
.sn:    inc ix
        inc ix
        inc ix
        pop bc
        djnz .sf
        ret

; HL = square address -> A = decoration sprite + 1 on the side we see, or 0
; (DECOR: 8 bytes an entry: offset lo, hi, side, sprite, kind, param, state)
find_decor:
        ld de,MAP
        or a
        sbc hl,de               ; square offset
        ld de,DECOR
        ld a,(ndecor)
        or a
        ret z
        ld b,a
.l:     ld a,(de)
        cp l
        jr nz,.s
        inc de
        ld a,(de)
        dec de
        cp h
        jr nz,.s
        inc de
        inc de
        ld a,(de)
        dec de
        dec de
        ld c,a
        ld a,(dp_side)
        cp c
        jr nz,.s
        inc de
        inc de
        inc de
        ld a,(de)
        inc a
        ret
.s:     ld a,e
        add a,8
        ld e,a
        jr nc,.n
        inc d
.n:     djnz .l
        xor a
        ret

; ---------------------------------------------------------------------
;  sprites standing on the squares in sight, far to near
; ---------------------------------------------------------------------
sprite_pass:
        ld hl,sq_offp
        call facing_ptr
        ld (dp_off),hl
        ld ix,sq_tab
        ld b,NSQ
.s:     push bc
        ld hl,(dp_off)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (dp_off),hl
        ld hl,(ppos)
        add hl,de
        ld (sp_sq),hl
        ld a,(ix+0)
        ld (sp_dz),a
        ld a,(ix+1)
        ld (sp_key),a
        ld a,(ix+2)
        ld (sp_shift),a
        ; a feature in the floor?
        xor a
        ld (sp_flash),a
        ld a,(hl)
        cp 32
        jr nc,.it
        push hl
        ld hl,floorspr
        call add_a_hl
        ld a,(hl)
        pop hl
        or a
        jr z,.it
        ld (sp_id),a
        push hl
        call draw_sprite
        pop hl
.it:    ; an item on the square?
        ld de,ITEMMAP-MAP
        add hl,de
        ld a,(hl)
        or a
        jr z,.m
        call item_sprite        ; A = item -> A = sprite id (0 = none)
        or a
        jr z,.m
        ld (sp_id),a
        call draw_sprite
.m:     ; a creature?
        ld hl,(sp_sq)
        ld de,MONMAP-MAP
        add hl,de
        ld a,(hl)
        or a
        jr z,.n
        push ix                 ; (mon_sprite points IX at the monster)
        call mon_sprite         ; A = monster + 1 -> A = sprite id, (sp_flash)
        pop ix
        or a
        jr z,.n
        ld (sp_id),a
        call draw_sprite
.n:     inc ix
        inc ix
        inc ix
        pop bc
        djnz .s
        ; a spell in flight, straight ahead
        ld a,(fx_sprite)
        or a
        ret z
        ld (sp_id),a
        xor a
        ld (sp_shift),a
        ld (sp_flash),a
        ld a,(fx_dz)
        ld (sp_dz),a
        add a,a
        add a,a
        ld (sp_key),a
        jp draw_sprite

; ---------------------------------------------------------------------
;  draw_sprite: sprite (sp_id) at depth (sp_dz) 1..3, shifted (sp_shift)
;  columns. A cell is drawn if its column's wall key > (sp_key), or, for
;  a decoration (sp_key = 255), if the column belongs to slot (sp_slot).
;  Sprite list: count, then per cell: column (signed, from the view's
;  left), row, code, attribute, colour.
;  (sp_flash) <> 0: every cell's colour is replaced by that class.
; ---------------------------------------------------------------------
draw_sprite:
        ld a,(lvl_mpa)
        out (P_MEM),a
        ld a,(sp_id)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; id * 8 (4 depths x dw; depth 0 unused)
        ld a,(sp_dz)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld de,SPRIDX
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr z,.out
        ex de,hl
        ld b,(hl)               ; cells
        inc hl
.c:     push bc
        ld a,(sp_shift)
        add a,(hl)              ; column
        inc hl
        cp VW
        jr nc,.skip             ; off the view (negative wraps high)
        ld c,a
        ; may it go there?
        ld de,zkey
        add a,e
        ld e,a
        jr nc,.k
        inc d
.k:     ld a,(sp_key)
        cp 255
        jr z,.dec
        ex de,hl
        cp (hl)                 ; key < zkey: in front of the wall
        ex de,hl
        jr nc,.skip
        jr .ok
.dec:   ld a,e
        add a,zown-zkey
        ld e,a
        jr nc,.k2
        inc d
.k2:    ld a,(de)
        ld e,a
        ld a,(sp_slot)
        cp e
        jr nz,.skip
.ok:    ; destination: SHC + row*24 + column
        ld a,(hl)               ; row
        inc hl
        push hl
        add a,a
        ld e,a
        ld d,0
        ld hl,row24
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,SHC
        add hl,de
        ld e,c
        ld d,0
        add hl,de
        ex de,hl                ; DE = shadow cell
        pop hl
        ld a,(hl)               ; code
        inc hl
        ld (de),a
        inc d                   ; +384
        ld a,e
        add a,$80
        ld e,a
        jr nc,.a1
        inc d
.a1:    ld a,(hl)               ; attribute
        inc hl
        ld (de),a
        inc d                   ; +768 in all
        ld a,e
        add a,$80
        ld e,a
        jr nc,.a2
        inc d
.a2:    ld a,(sp_flash)
        or a
        jr nz,.fl
        ld a,(hl)               ; colour
        cp 16
        call nc,anim_add        ; DE = the shadow colour cell
.fl:    inc hl
        ld (de),a
        pop bc
        djnz .c
.out:   ld a,(lvl_mpb)
        out (P_MEM),a
        ret
.skip:  inc hl
        inc hl
        inc hl
        inc hl
        pop bc
        djnz .c
        jr .out

; ---------------------------------------------------------------------
;  animated colours: draw_sprite lists a cell whose colour carries a class
;  (high nibble); anim_fix then keeps the cells still showing it (a nearer
;  sprite may have covered one), strips the class from the shadow and
;  turns shadow offsets into screen offsets. ANIMS: offset lo, hi, class.
; ---------------------------------------------------------------------
anim_add:
        push af
        push hl
        ld a,(nanim)
        cp 60
        jr nc,.full
        inc a
        ld (nanim),a
        dec a
        ld l,a
        add a,a
        add a,l
        ld l,a
        ld h,high(ANIMS)
        ld (hl),e
        inc hl
        ld (hl),d
.full:  pop hl
        pop af
        ret

anim_fix:
        ld a,(nanim)
        or a
        ret z
        ld b,a
        ld hl,ANIMS
        ld de,ANIMS             ; the kept ones
        xor a
        ld (nanim),a
.l:     push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        inc hl
        ld a,(bc)
        cp 16
        jr c,.drop
        push hl
        ; class, and the ink alone in the shadow
        ld l,a
        and $0F
        ld (bc),a
        ld a,l
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld (af_cls),a
        ; shadow offset (BC - SHK) = row*24 + col -> (row+1)*40 + col+1
        ld h,b
        ld l,c
        push de
        ld de,-SHK
        add hl,de
        ld de,24
        ld c,0
.dv:    or a
        sbc hl,de
        jr c,.dd
        inc c
        jr .dv
.dd:    add hl,de               ; L = column, C = row
        ld a,l
        ld l,c
        ld h,0
        add hl,hl
        ld de,row40
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call add_a_hl           ; HL = screen offset
        pop de
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(af_cls)
        ld (hl),a
        inc hl
        ex de,hl
        ld a,(nanim)
        inc a
        ld (nanim),a
        pop hl
.drop:  pop bc
        djnz .l
        ret

af_cls:     db 0
