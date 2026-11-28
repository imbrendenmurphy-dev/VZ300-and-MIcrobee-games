; =====================================================================
;  deck.asm - tile queries, the box test, doors, the deck's droid list
;  Object records (player and droids, IX): see O_* in vars.asm.
; =====================================================================

; tile_at: BC = x (pixels), E = y (rows) -> A = attributes, HL = map cell
tile_at:
            call snd_ptn
            ld a,c
            srl b
            rra
            srl b
            rra
            srl b
            rra
            ld c,a                  ; tx
            ld h,HIGH(DIV6)
            ld l,e
            ld l,(hl)               ; ty
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,l
            or c
            ld l,a
            ld a,h
            add a,HIGH(MAP)
            ld h,a
            ld a,(hl)
            push hl
            ld hl,tattr
            add a,l
            ld l,a
            jr nc,.n
            inc h
.n:         ld a,(hl)
            pop hl
            ret

; box_hit: is the droid box at (HL = x px, E = y row) on a tile with any
; of the attribute bits in A? Tests x+1, x+6, x+11 by y, y+4, y+7.
; Returns NZ with bh_attr = the tile's attributes if so.
box_hit:
            ld (bh_mask),a
            ld (bh_x),hl
            ld a,e
            ld (bh_y),a
            xor a
            ld (bh_dy),a
.yl:        ld a,(bh_y)
            ld hl,bh_dy
            add a,(hl)
            ld (bh_yy),a
            ld hl,(bh_x)
            inc hl
            call .pt
            ret nz
            ld hl,(bh_x)
            ld bc,6
            add hl,bc
            call .pt
            ret nz
            ld hl,(bh_x)
            ld bc,11
            add hl,bc
            call .pt
            ret nz
            ld a,(bh_dy)
            add a,4
            cp 8
            jr c,.nx
            cp 11
            jr nc,.none
            ld a,7
.nx:        ld (bh_dy),a
            jr .yl
.none:      xor a
            ret
.pt:        ld b,h
            ld c,l
            ld a,(bh_yy)
            ld e,a
            call tile_at
            ld (bh_attr),a
            ld hl,bh_mask
            and (hl)
            ret

; ---------------------------------------------------------------------
; doors: find the door halves in the map (left / top halves)
door_scan:
            xor a
            ld (ndoors),a
            ld ix,doors
            ld hl,MAP
            ld e,0                  ; ty
.y:         ld d,0                  ; tx
.x:         ld a,(hl)
            cp T_DVL
            jr z,.dv
            cp T_DHT
            jr z,.dh
.nx:        inc hl
            inc d
            ld a,d
            cp MAPW
            jr nz,.x
            inc e
            ld a,(deck_h)
            cp e
            jr nz,.y
            ret
.dv:        xor a
            jr .add
.dh:        ld a,1
.add:       ld (ix+0),a             ; kind: 0 = parts left/right, 1 = up/down
            ld (ix+1),d
            ld (ix+2),e
            ld (ix+3),0             ; state 0 closed .. 2 open
            ; centre point
            push hl
            ld l,d
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld bc,8
            or a
            jr z,.c
            ld bc,4
.c:         add hl,bc
            ld (ix+4),l
            ld (ix+5),h
            ld a,e
            add a,a
            add a,e
            add a,a
            add a,3
            ld c,a
            ld a,(ix+0)
            or a
            ld a,c
            jr z,.c2
            add a,3
.c2:        ld (ix+6),a
            pop hl
            ld bc,DOORSZ
            add ix,bc
            ld a,(ndoors)
            inc a
            ld (ndoors),a
            cp MAXDOORS
            ret z
            jr .nx

; door_update: doors open when the player or a droid comes near, and
; close (when nothing is in the way) once they have gone
door_update:
            ld a,(ndoors)
            or a
            ret z
            ld b,a
            ld ix,doors
.d:         push bc
            call door_one
            ld de,DOORSZ
            add ix,de
            pop bc
            djnz .d
            ret

door_one:
            call snd_pt
            ld l,(ix+4)
            ld h,(ix+5)
            ld (dr_cx),hl
            ld a,(ix+6)
            ld (dr_cy),a
            xor a
            ld (dr_near),a
            ld (dr_in),a
            push ix
            ld ix,plr
            call door_obj
            ld ix,droids
            ld b,MAXDROIDS
.o:         push bc
            bit 7,(ix+O_FLAGS)
            call nz,door_obj
            ld de,OSZ
            add ix,de
            pop bc
            djnz .o
            pop ix
            ld a,(dr_near)
            or a
            ld a,(ix+3)
            jr z,.close
            cp 2
            ret z
            or a
            jr nz,.op
            push af
            ld a,SFX_DOOR
            call sfx_near_door
            pop af
.op:        inc a
            jr .set
.close:     or a
            ret z
            ld a,(dr_in)
            or a
            ret nz                  ; something in the doorway
            ld a,(ix+3)
            dec a
.set:       ld (ix+3),a
            ; write both halves and re-render them
            ld c,a
            ld d,(ix+1)
            ld e,(ix+2)
            ld a,(ix+0)
            or a
            jr nz,.dh
            ld a,T_DVL
            add a,c
            call set_tile
            ld a,T_DVR
            add a,c
            inc d
            jp set_tile
.dh:        ld a,T_DHT
            add a,c
            call set_tile
            ld a,T_DHB
            add a,c
            inc e
            jp set_tile

; IX = object: near the door (dr_cx, dr_cy)? sets dr_near / dr_in
door_obj:
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld bc,6
            add hl,bc
            ld bc,(dr_cx)
            or a
            sbc hl,bc
            call abs_hl
            ld a,h
            or a
            ret nz
            ld a,l
            cp 26
            ret nc
            ld c,a                  ; |dx|
            ld a,(ix+O_Y)
            add a,4
            ld hl,dr_cy
            sub (hl)
            jr nc,.p
            neg
.p:         cp 17
            ret nc
            ld b,a                  ; |dy|
            ld a,1
            ld (dr_near),a
            ld a,c
            cp 12
            ret nc
            ld a,b
            cp 10
            ret nc
            ld a,1
            ld (dr_in),a
            ret

; set_tile: map cell (D = tx, E = ty) := A, and re-render it
set_tile:
            push de
            push bc
            push af
            ld l,e
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld a,l
            or d
            ld l,a
            ld a,h
            add a,HIGH(MAP)
            ld h,a
            pop af
            ld (hl),a
            pop bc
            pop de
            push de
            push bc
            call tile_patch
            pop bc
            pop de
            ret

; door sound only if the door is on screen
sfx_near_door:
            push af
            ld hl,(dr_cx)
            ld bc,(cam_x)
            or a
            sbc hl,bc
            ld a,h
            or a
            jr nz,.no
            ld a,l
            cp 128
            jr nc,.no
            ld a,(cam_y)
            ld b,a
            ld a,(dr_cy)
            sub b
            cp VIEWROWS
            jr nc,.no
            pop af
            jp sfx
.no:        pop af
            ret

; map_row: A = tile row -> its 64 tiles in BOUNCE (for the front end)
map_row:
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,MAP
            add hl,de
            ld a,MAP_GAME
            out (BANKPORT),a
            ld de,BOUNCE
            ld bc,64
            ldir
            ld a,(cur_map)
            out (BANKPORT),a
            ret

; the front end borrows sprite slot 7: put this deck's droid back in it
slot7_fix:
            ld a,(slot_type+7)
            cp $FF
            ret z
            ld d,7
            ld b,0
            jp build_type