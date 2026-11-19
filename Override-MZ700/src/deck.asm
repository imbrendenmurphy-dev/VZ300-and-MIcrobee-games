; =====================================================================
;  deck.asm - ships and decks: loading, doors, energizers, lights,
;             per-deck droid state
; =====================================================================

; ---------------------------------------------------------------------
; ship_init: A = ship number.  Sets ship_hdr and fills DSTATE from the
; deck droid lists.
; ---------------------------------------------------------------------
ship_init:
        ld (ship),a
        add a,a
        ld e,a
        ld d,0
        ld hl,SHIPTAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (ship_hdr),hl
        ld a,(hl)
        ld (ndecks),a
        ; DSTATE for each deck
        ld b,a
        ld c,0
.dk:    push bc
        ld a,c
        call deck_ptr               ; HL = deck header
        push hl
        pop iy
        ld a,c
        call dstate_ptr             ; DE = DSTATE entry
        xor a
        ld (de),a                   ; not cleared
        inc de
        ld a,(iy+DK_NDROID)
        ld (de),a
        inc de
        or a
        jr z,.nod
        ld b,a
        ld l,(iy+DK_DROIDS)
        ld h,(iy+DK_DROIDS+1)
.dr:    push bc
        ld a,(hl)                   ; type
        ld (de),a
        inc de
        push hl
        push de
        call roster_ptr
        ld bc,R_EN
        add hl,bc
        ld a,(hl)
        ld (tmp_en),a
        pop de
        pop hl
        inc hl
        ld a,(hl)                   ; node
        inc hl
        ld (tmp_node),a
        push hl
        ld l,(iy+DK_NODES)
        ld h,(iy+DK_NODES+1)
        add a,a
        ld c,a
        ld b,0
        add hl,bc
        ld a,(hl)
        ld (de),a                   ; x
        inc de
        inc hl
        ld a,(hl)
        ld (de),a                   ; y
        inc de
        ld a,(tmp_en)
        ld (de),a                   ; energy
        inc de
        ld a,(tmp_node)
        ld (de),a                   ; node
        inc de
        ld (de),a                   ; prev
        inc de
        pop hl
        pop bc
        djnz .dr
.nod:   pop bc
        inc c
        djnz .dk
        ret

; A = deck -> HL = deck header
deck_ptr:
        push de
        add a,a
        ld e,a
        ld d,0
        ld hl,(ship_hdr)
        add hl,de
        ld de,SH_DECKS
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        ret

; A = deck -> DE = DSTATE entry
dstate_ptr:
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                   ; *32
        ld d,h
        ld e,l
        add hl,hl                   ; *64
        add hl,de                   ; *96
        ld de,DSTATE
        add hl,de
        ex de,hl
        pop hl
        ret

; ---------------------------------------------------------------------
; load_deck: A = deck.  Builds the map, tables and droids.
; ---------------------------------------------------------------------
load_deck:
        ld (deck),a
        call deck_ptr
        ld (deck_hdr),hl
        push hl
        pop iy
        ; map: all void
        ld hl,MAP
        ld b,MAPROWS/2
.clr:   push bc
        ld d,h
        ld e,l
        inc de
        ld (hl),C_VOID
        ld bc,255
        ldir
        inc hl
        call poll
        pop bc
        djnz .clr
        ; the bare structure: rows of 2-bit-code runs, or "copy row k up"
        ld l,(iy+DK_RLE)
        ld h,(iy+DK_RLE+1)
        ld (rleptr),hl
        ld c,MY0
        ld b,(iy+DK_H)
.row:   push bc
        ld b,MX0
        call mapaddr
        ex de,hl                    ; DE = destination
        ld hl,(rleptr)
        ld a,(hl)
        cp 0FFh
        jr nz,.runs
        inc hl
        ld b,(hl)                   ; copy the row k rows up
        inc hl
        ld (rleptr),hl
        ld h,d
        ld l,e
.up:    push bc
        ld bc,-MAPW
        add hl,bc
        pop bc
        djnz .up
        ld b,0
        ld c,(iy+DK_W)
        ldir
        jr .rdone
.runs:  ld c,(iy+DK_W)
.r:     ld a,(hl)
        inc hl
        push hl
        ld b,a
        rlca
        rlca
        and 3
        ld hl,base_codes
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,b
        and 3Fh
        ld b,a
        ld a,(hl)
        pop hl
.f:     ld (de),a
        inc de
        dec c
        djnz .f
        ld a,c
        or a
        jr nz,.r
        ld (rleptr),hl
.rdone: call poll
        pop bc
        inc c
        djnz .row
        ; doors
        ld a,(iy+DK_NDOOR)
        ld (ndoors),a
        ld b,a
        ld l,(iy+DK_DOORS)
        ld h,(iy+DK_DOORS+1)
        ld ix,DOORS
.dr:    push bc
        ld a,(hl)
        ld (ix+DR_X),a
        inc hl
        ld a,(hl)
        ld (ix+DR_Y),a
        inc hl
        ld a,(hl)
        ld (ix+DR_KIND),a
        inc hl
        ld (ix+DR_ST),0
        push hl
        ld b,(ix+DR_X)
        ld c,(ix+DR_Y)
        call mapaddr
        ld (ix+DR_ADDR),l
        ld (ix+DR_ADDR+1),h
        push iy
        push ix
        pop iy
        xor a
        ld (dimmed),a
        call door_draw
        pop iy
        pop hl
        ld bc,DRSZ
        add ix,bc
        pop bc
        djnz .dr
        ; lifts (x, y, shaft, pad)
        ld a,(iy+DK_NLIFT)
        ld (nlifts),a
        add a,a
        add a,a
        ld c,a
        ld b,0
        ld l,(iy+DK_LIFTS)
        ld h,(iy+DK_LIFTS+1)
        ld de,LIFTS
        ldir
        ld a,(nlifts)
        ld b,a
        ld hl,LIFTS
.lp:    push bc
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        inc hl
        inc hl
        push hl
        ld a,C_LIFT0
        call put_3x2
        pop hl
        pop bc
        djnz .lp
        ; energizers
        ld a,(iy+DK_NENER)
        ld (neners),a
        add a,a
        ld c,a
        ld b,0
        ld l,(iy+DK_ENERS)
        ld h,(iy+DK_ENERS+1)
        ld de,ENERS
        ldir
        ; consoles
        ld a,(iy+DK_NCON)
        ld (ncons),a
        or a
        jr z,.nocon
        add a,a
        ld c,a
        ld b,0
        ld l,(iy+DK_CONS)
        ld h,(iy+DK_CONS+1)
        ld de,CONS
        ldir
        ld a,(ncons)
        ld b,a
        ld de,CONS
.cn:    push bc
        ld a,(de)
        ld b,a
        inc de
        ld a,(de)
        ld c,a
        inc de
        call mapaddr
        ld (hl),C_CON0
        inc hl
        ld (hl),C_CON1
        pop bc
        djnz .cn
.nocon: ; props: (x, y, code) triples
        ld b,(iy+DK_NPROP)
        ld l,(iy+DK_PROPS)
        ld h,(iy+DK_PROPS+1)
        ld a,b
        or a
        jr z,.noprop
.pr:    push bc
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        push af
        call mapaddr
        pop af
        ld (hl),a
        pop hl
        pop bc
        djnz .pr
.noprop:
        ; floor marks, wall faces
        call deck_decorate
        ; energizer pads last (they are not floor for the marks)
        push iy
        call ener_draw_all
        pop iy
        ; a sprinkling of stars
        ld b,90
.st:    push bc
        call rand
        ld e,a
        call rand
        and 3Fh
        add a,high MAP
        cp high MAP + MAPROWS/2
        jr nc,.sn
        ld d,a
        ld a,(de)
        cp C_VOID
        jr nz,.sn
        ld a,l
        and 3
        ld a,C_STAR2
        jr nz,$+4
        ld a,C_STAR1
        ld (de),a
.sn:    pop bc
        djnz .st        ; waypoints
        ld a,(iy+DK_NNODE)
        ld (nnodes),a
        add a,a
        ld c,a
        ld b,0
        ld l,(iy+DK_NODES)
        ld h,(iy+DK_NODES+1)
        ld de,NODES
        ldir
        ; adjacency: packed (count, list) -> 8-byte slots
        ld l,(iy+DK_ADJ)
        ld h,(iy+DK_ADJ+1)
        ld de,ADJ
        ld a,(nnodes)
        ld b,a
.adj:   push bc
        push de
        ld a,(hl)
        inc a
        ld c,a
        ld b,0
        ldir
        pop de
        ex de,hl
        ld bc,8
        add hl,bc
        ex de,hl
        pop bc
        djnz .adj
        ; clear moving things
        ld hl,SHOTS
        ld b,SHOTSZ*NSHOTS
        call zero_b
        ld hl,EXPLS
        ld b,EXPLSZ*NEXPL
        call zero_b
        ld hl,OVLBUF
        ld (ovlptr),hl
        ; droids
        call spawn_droids
        ; lights
        xor a
        ld (dimmed),a
        ld a,(deck)
        call dstate_ptr
        ld a,(de)
        or a
        call nz,dim_deck
        ld a,1
        ld (hud_deck),a
        ld (hud_dirty),a
        ret

zero_b:
        ld (hl),0
        inc hl
        djnz zero_b
        ret

base_codes:
        db C_VOID,C_FLOOR,C_WALL,C_VOID

; B,C = top-left, A = first of six consecutive codes: a 3x2 block
put_3x2:
        push af
        call mapaddr
        pop af
        ld (hl),a
        inc a
        inc hl
        ld (hl),a
        inc a
        inc hl
        ld (hl),a
        inc a
        ld de,MAPW-2
        add hl,de
        ld (hl),a
        inc a
        inc hl
        ld (hl),a
        inc a
        inc hl
        ld (hl),a
        ret

; floor marks and wall faces (not stored, to keep the RLE short)
deck_decorate:
        ld c,MY0
        xor a
        ld (dec_y3),a
        ld hl,(deck_hdr)
        inc hl
        ld b,(hl)                   ; H
.row:   push bc
        ld b,MX0
        call mapaddr
        ld de,(deck_hdr)
        ld a,(de)
        ld b,a                      ; W
        ld e,0                      ; x mod 4
.c:     ld a,(hl)
        cp C_FLOOR
        jr nz,.nf
        ld a,e
        cp 2
        jr nz,.nx
        ld a,(dec_y3)
        cp 1
        jr nz,.nx
        ld (hl),C_MARK
        jr .nx
.nf:    cp C_WALL
        jr nz,.nx
        push hl
        push de
        ld de,MAPW
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        cp C_WALL
        jr z,.nx
        cp C_VOID
        jr z,.nx
        push hl
        ld l,a
        ld h,high FLGTAB
        ld a,(hl)
        pop hl
        and F_DOOR
        jr nz,.nx
        ld (hl),C_FACE
.nx:    inc hl
        inc e
        ld a,e
        and 3
        ld e,a
        djnz .c
        ld a,(dec_y3)
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (dec_y3),a
        call poll
        pop bc
        inc c
        djnz .row
        ret

; turn the lights down: every code of the deck through DIMTAB
dim_deck:
        ld a,1
        ld (dimmed),a
        ld c,MY0
        ld hl,(deck_hdr)
        inc hl
        ld b,(hl)                   ; H
.row:   push bc
        ld b,MX0
        call mapaddr
        ld de,(deck_hdr)
        ld a,(de)
        ld b,a                      ; W
        ld d,high DIMTAB
.c:     ld e,(hl)
        ld a,(de)
        ld (hl),a
        inc hl
        djnz .c
        call poll
        pop bc
        inc c
        djnz .row
        ld a,1
        ld (hud_deck),a
        ret

; ---------------------------------------------------------------------
; droids from / to the deck state
; ---------------------------------------------------------------------
spawn_droids:
        ld ix,DROIDS+DSZ
        ld b,NDROIDS-1
.clr:   ld (ix+D_TYPE),0FFh
        ld de,DSZ
        add ix,de
        djnz .clr
        ld a,(deck)
        call dstate_ptr
        inc de
        ld a,(de)                   ; count
        inc de
        or a
        ret z
        ld b,a
        ld ix,DROIDS+DSZ
.d:     push bc
        ld a,(de)
        ld (ix+D_TYPE),a
        inc de
        ld a,(de)
        ld (ix+D_X),a
        inc de
        ld a,(de)
        ld (ix+D_Y),a
        inc de
        ld a,(de)
        ld (ix+D_EN),a
        inc de
        ld a,(de)
        ld (ix+D_NODE),a
        inc de
        ld a,(de)
        ld (ix+D_PREV),a
        inc de
        push de
        ld a,(ix+D_TYPE)
        cp 0FFh
        call nz,droid_setup
        pop de
        ld bc,DSZ
        add ix,bc
        pop bc
        djnz .d
        ret

; IX = droid with type set: fill in the derived fields
droid_setup:
        ld a,(ix+D_TYPE)
        call roster_ptr
        ld bc,R_CB
        add hl,bc
        ld a,(hl)
        push ix                     ; the player is always yellow
        pop hl
        ld bc,DROIDS
        or a
        sbc hl,bc
        ld (ix+D_CB),a
        jr nz,.en
        ld (ix+D_CB),C_DL4
.en:
        xor a
        ld (ix+D_FLASH),a
        ld (ix+D_WAIT),a
        ld (ix+D_DX),a
        ld (ix+D_DY),a
        call rand
        ld (ix+D_ACC),a
        res 4,(ix+D_ACC)
        res 5,(ix+D_ACC)
        res 6,(ix+D_ACC)
        res 7,(ix+D_ACC)
        ld (ix+D_ANIM),a
        and 15
        ld (ix+D_RELD),a
        ld (ix+D_THINK),a
        ret

save_droids:
        ld a,(deck)
        call dstate_ptr
        inc de
        ld a,(de)
        inc de
        or a
        ret z
        ld b,a
        ld ix,DROIDS+DSZ
.d:     ld a,(ix+D_TYPE)
        ld (de),a
        inc de
        ld a,(ix+D_X)
        ld (de),a
        inc de
        ld a,(ix+D_Y)
        ld (de),a
        inc de
        ld a,(ix+D_EN)
        ld (de),a
        inc de
        ld a,(ix+D_NODE)
        ld (de),a
        inc de
        ld a,(ix+D_PREV)
        ld (de),a
        inc de
        push de
        ld de,DSZ
        add ix,de
        pop de
        djnz .d
        ret

; A = number of enemies alive on this deck
count_enemies:
        ld ix,DROIDS+DSZ
        ld b,NDROIDS-1
        ld c,0
.l:     ld a,(ix+D_TYPE)
        cp 0FFh
        jr z,.n
        inc c
.n:     ld de,DSZ
        add ix,de
        djnz .l
        ld a,c
        ret

; ---------------------------------------------------------------------
; doors: open when any droid comes near (only doors near the view)
; ---------------------------------------------------------------------
doors_update:
        ld a,(frame)
        and 1
        ret nz
        ld a,(ndoors)
        or a
        ret z
        ld b,a
        ld iy,DOORS
.dl:    push bc
        ; near the view?
        ld a,(camx)
        ld c,a
        ld a,(iy+DR_X)
        sub c
        add a,8
        cp 56
        jr nc,.next
        ld a,(camy)
        ld c,a
        ld a,(iy+DR_Y)
        sub c
        add a,6
        cp 35
        jr nc,.next
        call door_wanted            ; A = 2 open / 0 closed
        ld c,a
        ld a,(iy+DR_ST)
        cp c
        jr z,.next
        jr c,.open
        dec a
        jr .set
.open:  inc a
        cp 1
        jr nz,.set
        push af                     ; starts opening: a hiss if close to us
        call door_sound
        pop af
.set:   ld (iy+DR_ST),a
        call door_draw
.next:  ld bc,DRSZ
        add iy,bc
        pop bc
        djnz .dl
        ret

; IY = door -> A = 2 if a droid is near, else 0
door_wanted:
        ld ix,DROIDS
        ld b,NDROIDS
.l:     ld a,(ix+D_TYPE)
        cp 0FFh
        jr z,.n
        ; door rectangle x0..x1, y0..y1 widened by 2; droid footprint x..x+2, y..y+1
        ld a,(iy+DR_X)
        sub 4                       ; droid x+2 >= door x-2  <=> x >= dx-4
        ld c,a
        ld a,(ix+D_X)
        cp c
        jr c,.n
        ld a,(iy+DR_KIND)
        or a
        ld a,(iy+DR_X)
        jr nz,.v
        add a,2
.v:     add a,3                     ; droid x <= door x1 + 2
        cp (ix+D_X)
        jr c,.n
        ld a,(iy+DR_Y)
        sub 3
        ld c,a
        ld a,(ix+D_Y)
        cp c
        jr c,.n
        ld a,(iy+DR_KIND)
        or a
        ld a,(iy+DR_Y)
        jr z,.h
        inc a
.h:     add a,2
        cp (ix+D_Y)
        jr c,.n
        ld a,2
        ret
.n:     ld de,DSZ
        add ix,de
        djnz .l
        xor a
        ret

door_sound:
        ld a,(DROIDS+D_X)
        ld c,a
        ld a,(iy+DR_X)
        sub c
        add a,12
        cp 26
        ret nc
        ld hl,SFX_DOOR
        ld a,1
        jp sfx

; IY = door: write its cells for the current state
door_draw:
        ld l,(iy+DR_ADDR)
        ld h,(iy+DR_ADDR+1)
        ld a,(iy+DR_KIND)
        or a
        jr nz,.vert
        ld a,(iy+DR_ST)
        ld de,doorh_codes
        add a,a
        add a,(iy+DR_ST)
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        ld b,3
.h:     ld a,(de)
        call dimcode
        ld (hl),a
        inc hl
        inc de
        djnz .h
        ret
.vert:  ld a,(iy+DR_ST)
        ld de,doorv_codes
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        ld a,(de)
        call dimcode
        ld (hl),a
        ld de,MAPW
        add hl,de
        ld (hl),a
        ret

; A = lit code -> code for the current lights
dimcode:
        push hl
        ld l,a
        ld a,(dimmed)
        or a
        ld a,l
        jr z,.x
        ld h,high DIMTAB
        ld a,(hl)
.x:     pop hl
        ret

doorh_codes:
        db C_DH0,C_DH0,C_DH0
        db C_DH1,C_DHO,C_DH1
        db C_DHO,C_DHO,C_DHO
doorv_codes:
        db C_DV0,C_DV1,C_DVO

; ---------------------------------------------------------------------
; energizers: colour-cycling pads
; ---------------------------------------------------------------------
ener_update:
        ld a,(frame)
        and 3
        ret nz
ener_draw_all:
        ld a,(neners)
        or a
        ret z
        ld b,a
        ld a,(frame)
        rrca
        rrca
        and 3
        add a,C_ENER0
        call dimcode
        ld e,a
        ld iy,ENERS
.l:     push bc
        ld b,(iy+0)
        ld c,(iy+1)
        call mapaddr
        ld (hl),e
        inc hl
        ld (hl),e
        inc hl
        ld (hl),e
        ld bc,MAPW-2
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),e
        inc hl
        ld (hl),e
        inc iy
        inc iy
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; footprint helpers
; ---------------------------------------------------------------------
; B = x, C = y -> A = OR of the flags of the 3x2 cells
fp_flags:
        push de
        push hl
        call mapaddr
        ld d,high FLGTAB
        ld e,(hl)
        ld a,(de)
        inc hl
        ld e,(hl)
        ex de,hl
        or (hl)
        ex de,hl
        inc hl
        ld e,(hl)
        ex de,hl
        or (hl)
        ex de,hl
        push bc
        ld bc,MAPW-2
        add hl,bc
        pop bc
        ld e,(hl)
        ex de,hl
        or (hl)
        ex de,hl
        inc hl
        ld e,(hl)
        ex de,hl
        or (hl)
        ex de,hl
        inc hl
        ld e,(hl)
        ex de,hl
        or (hl)
        pop hl
        pop de
        ret

; B = x, C = y -> A = flags of that cell
cell_flags:
        push hl
        call mapaddr
        ld l,(hl)
        ld h,high FLGTAB
        ld a,(hl)
        pop hl
        ret
