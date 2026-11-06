; =====================================================================
;  HAMBURGER SAM II - kitchens: loading, static background, ingredients
;  (pressing, falling, cascades, riders, squashes, plates), score + HUD
; =====================================================================
LV_NAME  equ 0
LV_LAD   equ 2
LV_PCS   equ 4
LV_CSS   equ 6
LV_GB    equ 7
LV_LC    equ 8
LV_SAMX  equ 9
LV_SAMF  equ 10
LV_ITX   equ 11
LV_ITF   equ 12
LV_MAXEN equ 13
LV_SPD   equ 14
LV_NCOL  equ 15
LV_COLS  equ 16
LV_SPAWN equ 20
LV_ROST  equ 28
LV_FMAP  equ 34
PLATE    equ 5                  ; "floor" 5 = the plate

; bgrow: A = row -> HL = BGBUF + row*32   (DE preserved)
bgrow:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,BGBUF/256
        ld h,a
        ret

; fyrow: A = floor 0-4 -> A = girder row
fyrow:
        push hl
        ld hl,fy_tab
        call idx_byte
        pop hl
        ret

; ---------------------------------------------------------------------
; load_kitchen: A = kitchen (0-7, 8 = classic)
; ---------------------------------------------------------------------
load_kitchen:
        ld hl,lvtab
        call idx_word
        ld de,lvh
        ld bc,LVHSIZE
        ldir
        ; ingredient records
        xor a
        ld (burgers),a
        ld (drops),a
        ld hl,ncolpc
        ld b,16
.z:     ld (hl),a               ; ncolpc, colstk, coldone, colfirst
        inc hl
        djnz .z
        ld hl,(lvh+LV_PCS)
        ld a,(hl)
        ld (npc),a
        inc hl
        ld ix,pieces
        ld c,0                  ; index
.p:     ld a,c
        ld b,a
        ld a,(npc)
        cp b
        jr z,.pd
        ld a,(hl)
        ld (ix+PC_X),a
        inc hl
        ld a,(hl)
        ld (ix+PC_F),a
        call fyrow
        sub 2
        ld (ix+PC_Y),a
        ld (ix+PC_OY),a
        inc hl
        ld a,(hl)
        ld (ix+PC_T),a
        inc hl
        ld a,(hl)
        ld (ix+PC_C),a
        inc hl
        xor a
        ld (ix+PC_PR),a
        ld (ix+PC_ST),a
        ld (ix+PC_N),a
        ; column bookkeeping
        push hl
        ld a,(ix+PC_C)
        ld hl,ncolpc
        call idx_ptr
        ld a,(hl)
        or a
        jr nz,.nf
        push hl
        ld a,(ix+PC_C)
        ld hl,colfirst
        call idx_ptr
        ld (hl),c
        pop hl
.nf:    inc (hl)
        pop hl
        ld de,PSIZE
        add ix,de
        inc c
        jr .p
.pd:    call build_nodes
        ; ladder colours
        ld a,(lvh+LV_LC)
        ld b,a
        add a,a
        add a,a
        ld c,a                  ; c<<2
        ld (rail1),a
        add a,a
        add a,a
        ld (rail0),a            ; c<<4
        ld a,b
        add a,c
        ld b,a                  ; c + c<<2
        ld a,(rail0)
        add a,b
        ld (rung0),a            ; c<<4|c<<2|c
        add a,a
        add a,a
        ld (rung1),a            ; c<<6|c<<4|c<<2
        ld a,(lvh+LV_CSS)
        or MODE1
        ld (palbase),a
        ret

; node table: node[f*32+cell] bit7 walkable (girder under a centre in cells 1..30),
; bit0 ladder down from here, bit1 ladder up from here
build_nodes:
        ld hl,node
        ld b,160
        xor a
.c:     ld (hl),a
        inc hl
        djnz .c
        ld ix,lvh+LV_FMAP
        ld hl,node
        ld c,5
.f:     ld b,4
.by:    ld a,(ix+0)
        inc ix
        ld e,8
.bi:    rla
        jr nc,.n0
        set 7,(hl)
.n0:    inc hl
        dec e
        jr nz,.bi
        djnz .by
        dec c
        jr nz,.f
        ; cells 0 and 31 are never stood on
        ld hl,node
        ld b,5
.ed:    res 7,(hl)
        ld de,31
        add hl,de
        res 7,(hl)
        inc hl
        djnz .ed
        ; ladders
        ld hl,(lvh+LV_LAD)
        ld b,(hl)
        inc hl
.l:     ld a,b
        or a
        ret z
        push bc
        ld a,(hl)               ; X
        inc hl
        rrca
        rrca
        and $3F
        inc a                   ; centre cell
        ld c,a
        ld a,(hl)               ; ftop
        inc hl
        push hl
        call nodeaddr           ; A floor, C cell -> HL
        set 0,(hl)
        ld de,32
        add hl,de
        set 1,(hl)
        pop hl
        pop bc
        dec b
        jr .l

; nodeaddr: A = floor, C = cell -> HL = node + f*32 + cell
nodeaddr:
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld l,a
        ld h,0
        ld de,node
        add hl,de
        ret

; walkable: A = floor, B = x -> NZ if a walker at x stands on girder there
walkable:
        push hl
        push de
        push bc
        ld c,a
        ld a,b
        cp 117
        jr nc,.no
        add a,4
        rrca
        rrca
        and $3F
        ld b,a
        ld a,c
        ld c,b
        call nodeaddr
        bit 7,(hl)
        pop bc
        pop de
        pop hl
        ret
.no:    pop bc
        pop de
        pop hl
        xor a
        ret

; ladder_at: A = floor, B = x (must be a multiple of 4), E = 1 down / 2 up -> NZ if ladder
ladder_at:
        push hl
        push de
        push bc
        ld c,a
        ld a,b
        and 3
        jr nz,.no
        ld a,b
        rrca
        rrca
        and $3F
        inc a
        ld b,a
        ld a,c
        ld c,b
        call nodeaddr
        pop bc
        pop de
        ld a,(hl)
        and e
        pop hl
        ret
.no:    pop bc
        pop de
        pop hl
        xor a
        ret

; ---------------------------------------------------------------------
; draw_kitchen: build STATBG (girders, ladders, plates), copy to BG,
; draw ingredients and the HUD
; ---------------------------------------------------------------------
draw_kitchen:
        ld hl,STATBG
        ld de,STATBG+1
        ld bc,2047
        ld (hl),0
        ldir
        ; girders
        ld ix,lvh+LV_FMAP
        xor a
        ld (tmpa),a
.gf:    ld a,(tmpa)
        call fyrow
        call bgrow
        ld a,h
        sub 8                   ; BGBUF -> STATBG
        ld h,a
        ld b,4
.gb:    ld a,(ix+0)
        inc ix
        ld e,8
.gi:    rla
        jr nc,.g0
        push af
        ld a,(lvh+LV_GB)
        ld (hl),a
        pop af
.g0:    inc hl
        dec e
        jr nz,.gi
        djnz .gb
        ld a,(tmpa)
        inc a
        ld (tmpa),a
        cp 5
        jr nz,.gf
        ; ladders
        ld hl,(lvh+LV_LAD)
        ld a,(hl)
        inc hl
        ld (tmpb),a
.ln:    ld a,(tmpb)
        or a
        jr z,.pl
        dec a
        ld (tmpb),a
        ld a,(hl)
        inc hl
        rrca
        rrca
        and $3F
        ld (tmpx),a             ; byte column
        ld a,(hl)
        inc hl
        push hl
        ld (tmpc),a
        call fyrow
        ld (tmpy),a             ; top girder row
        ld a,(tmpc)
        inc a
        call fyrow
        ld (tmpd),a             ; bottom girder row
        ld a,(tmpy)
        inc a
        ld c,1                  ; row-in-ladder counter
.lr:    push af
        call bgrow
        ld a,h
        sub 8
        ld h,a
        ld a,(tmpx)
        add a,l
        ld l,a
        ld a,c
        cp 3
        jr nz,.rail
        ld c,0
        ld a,(rung0)
        ld (hl),a
        inc hl
        ld a,(rung1)
        ld (hl),a
        jr .lx
.rail:  ld a,(rail0)
        ld (hl),a
        inc hl
        ld a,(rail1)
        ld (hl),a
.lx:    inc c
        pop af
        inc a
        ld b,a
        ld a,(tmpd)
        cp b
        ld a,b
        jr nz,.lr
        pop hl
        jr .ln
        ; plates under the columns (rows 62-63, 24 px from x-4)
.pl:    ld a,(lvh+LV_NCOL)
        ld b,a
        ld ix,lvh+LV_COLS
.pc:    push bc
        ld a,(ix+0)
        inc ix
        rrca
        rrca
        and $3F
        dec a
        ld e,a
        ld a,62
        call bgrow
        ld a,h
        sub 8
        ld h,a
        ld a,l
        add a,e
        ld l,a
        ex de,hl
        ld hl,plategfx
        ld bc,6
        ldir
        ex de,hl
        ld bc,26
        add hl,bc
        ex de,hl
        ld bc,6
        ldir
        pop bc
        djnz .pc
        ; to BG, plus ingredients and HUD
        ld hl,STATBG
        ld de,BGBUF
        ld bc,2048
        ldir
        call draw_all_pieces
        jp draw_hud

draw_all_pieces:
        ld a,(npc)
        or a
        ret z
        ld b,a
        ld ix,pieces
.l:     push bc
        call draw_piece
        ld de,PSIZE
        add ix,de
        pop bc
        djnz .l
        ret

; draw_piece: IX = piece -> into BG (masked; pressed segments 1 row lower)
draw_piece:
        ld a,(ix+PC_T)
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,piecegfx
        add hl,de
        ld (pgfx),hl
        ld a,(ix+PC_PR)
        ld (tmpd),a
        ld a,(ix+PC_X)
        rrca
        rrca
        and $3F
        ld (tmpx),a
        ld c,0
.seg:   ld a,(tmpd)
        srl a
        ld (tmpd),a
        ld a,(ix+PC_Y)
        adc a,0
        cp 62
        jr nc,.nx
        push bc
        call bgrow
        ld a,(tmpx)
        add a,c
        add a,l
        ld l,a
        ld de,(pgfx)
        ld a,e
        add a,c
        ld e,a
        jr nc,.ne
        inc d
.ne:    ; row 0: data at +0, mask at +8
        push de
        ex de,hl
        ld b,(hl)               ; d0
        ld a,l
        add a,8
        ld l,a
        jr nc,.n1
        inc h
.n1:    ld c,(hl)               ; m0
        ex de,hl
        ld a,(hl)
        and c
        or b
        ld (hl),a
        pop de
        ld bc,32
        add hl,bc
        ; row 1: data at +4, mask at +12
        ex de,hl
        ld bc,4
        add hl,bc
        ld b,(hl)
        ld a,l
        add a,8
        ld l,a
        jr nc,.n2
        inc h
.n2:    ld c,(hl)
        ex de,hl
        ld a,(hl)
        and c
        or b
        ld (hl),a
        pop bc
.nx:    inc c
        ld a,c
        cp 4
        jr nz,.seg
        ret

; restore_rect: D = byte column, E = row, B = width, C = height: STATBG -> BG
restore_rect:
.r:     push bc
        push de
        ld a,e
        call bgrow
        ld a,l
        add a,d
        ld l,a
        ld e,l
        ld d,h
        ld a,h
        sub 8
        ld h,a
        ld c,b
        ld b,0
        ldir
        pop de
        pop bc
        inc e
        ld a,e
        cp 64
        ret nc
        dec c
        jr nz,.r
        ret

; ---------------------------------------------------------------------
; Sam steps on ingredients.  Called after Sam moves on a floor.
; ---------------------------------------------------------------------
sam_press:
        ld a,(sf)
        cp $FF
        ret z
        ld c,a
        ld a,(sx)
        add a,4
        ld e,a                  ; centre x
        ld a,(npc)
        ld b,a
        ld ix,pieces
.l:     ld a,(ix+PC_ST)
        or a
        jr nz,.nx
        ld a,(ix+PC_F)
        cp c
        jr nz,.nx
        ld a,e
        sub (ix+PC_X)
        cp 16
        jr c,.hit
.nx:    push de
        ld de,PSIZE
        add ix,de
        pop de
        djnz .l
        ret
.hit:   rrca
        rrca
        and 3
        ld b,a
        ld a,1
        inc b
.sh:    dec b
        jr z,.shd
        add a,a
        jr .sh
.shd:   ld c,a
        ld a,(ix+PC_PR)
        and c
        ret nz                  ; already pressed
        ld a,(ix+PC_PR)
        or c
        ld (ix+PC_PR),a
        ld a,SFX_STEP
        call play_sfx
        call redraw_piece
        ld a,(ix+PC_PR)
        cp 15
        ret nz
        call grab_riders
        jp start_fall

; redraw one resting piece (repair its 3 rows)
redraw_piece:
        push ix
        ld a,(ix+PC_X)
        rrca
        rrca
        and $3F
        ld d,a
        ld e,(ix+PC_Y)
        ld bc,$0403
        call repair_rect
        pop ix
        ret

; enemies standing on the piece ride it down (extra floor each)
grab_riders:
        xor a
        ld (ride_n),a
        ld iy,enemies
        ld b,MAXEN
.l:     ld a,(iy+E_ST)
        dec a
        cp 2                    ; walking or stunned
        jr nc,.nx
        ld a,(iy+E_F)
        cp (ix+PC_F)
        jr nz,.nx
        ld a,(iy+E_X)
        add a,4
        sub (ix+PC_X)
        cp 16
        jr nc,.nx
        ld (iy+E_ST),3
        push ix
        pop hl
        ld (iy+E_PC),l          ; low byte identifies the piece
        ld a,(ride_n)
        inc a
        ld (ride_n),a
.nx:    ld de,ESIZE
        add iy,de
        djnz .l
        ld a,(ride_n)
        ld (ix+PC_N),a
        ret

; start_fall: IX = resting piece
start_fall:
        ld (ix+PC_ST),1
        xor a
        ld (ix+PC_PR),a
        ld a,(ix+PC_F)
        inc a
        ld (ix+PC_TF),a
        ; riders can't push it past the plate
        ld b,a
        ld a,PLATE
        sub b
        cp (ix+PC_N)
        jr nc,.ok
        ld (ix+PC_N),a
.ok:    ld a,(drops)
        inc a
        ld (drops),a
        ld a,SFX_DROP
        jp play_sfx

; ---------------------------------------------------------------------
; update_pieces: move falling ingredients, cascade, squash, land, redraw
; ---------------------------------------------------------------------
update_pieces:
        xor a
        ld (tmpc),a             ; column
.col:   ld a,(tmpc)
        ld b,a
        ld a,(lvh+LV_NCOL)
        cp b
        ret z
        ld a,255
        ld (ymin),a
        xor a
        ld (ymax),a
        ld (cmoved),a
        ; last piece in the column
        ld a,(tmpc)
        ld hl,ncolpc
        call idx_byte
        or a
        jp z,.next
        ld (cnt),a
        ld b,a
        ld a,(tmpc)
        ld hl,colfirst
        call idx_byte
        add a,b
        dec a
        ld (pidx),a
.pl:    ld a,(pidx)
        call piece_ix
        ld a,(ix+PC_ST)
        cp 1
        call z,fall_step
        ld a,(pidx)
        dec a
        ld (pidx),a
        ld a,(cnt)
        dec a
        ld (cnt),a
        jr nz,.pl
        ld a,(cmoved)
        or a
        jr z,.next
        ; restore + redraw the column strip
        ld a,(tmpc)
        ld hl,lvh+LV_COLS
        call idx_byte
        rrca
        rrca
        and $3F
        ld d,a
        ld a,(ymin)
        ld e,a
        ld a,(ymax)
        sub e
        inc a
        ld c,a
        ld b,4
        call repair_rect
.next:  ld a,(tmpc)
        inc a
        ld (tmpc),a
        jp .col

; piece_ix: A = index -> IX = record
piece_ix:
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl               ; *10
        ld de,pieces
        add hl,de
        push hl
        pop ix
        ret

redraw_column:
        ld a,(tmpc)
        ld hl,colfirst
        call idx_byte
        call piece_ix
        ld a,(tmpc)
        ld hl,ncolpc
        call idx_byte
        ld b,a
.l:     push bc
        call draw_piece
        ld de,PSIZE
        add ix,de
        pop bc
        djnz .l
        ret

; one frame of fall for IX
fall_step:
        ld a,1
        ld (cmoved),a
        ld a,(ix+PC_Y)
        ld (ix+PC_OY),a
        ld b,a
        ld a,(ymin)
        cp b
        jr c,.y1
        ld a,b
        ld (ymin),a
.y1:    ld a,b
        add a,2                 ; old drawing reached Y+2 (pressed segments)
        ld b,a
        ld a,(ymax)
        cp b
        jr nc,.y2
        ld a,b
        ld (ymax),a
.y2:    ; target row
        call target_row
        ld (trow),a
        ld a,(ix+PC_Y)
        add a,2
        ld b,a
        ld a,(trow)
        cp b
        jr nc,.t1
        ld b,a
.t1:    ld (ix+PC_Y),b
        ld a,b
        inc a
        ld c,a
        ld a,(ymax)
        cp c
        jr nc,.y3
        ld a,c
        ld (ymax),a
.y3:    ; bump the piece below (next index, same column)
        ld a,(cnt)
        ld b,a
        ld a,(tmpc)
        ld hl,ncolpc
        call idx_byte
        cp b
        jr z,.nob               ; this is the lowest piece
        ld a,(ix+PC_Y)
        add a,2
        ld (tmpy),a             ; first row under this piece
        push ix
        ld de,PSIZE
        add ix,de
        ld a,(ix+PC_ST)
        or a
        jr nz,.nob2
        ld a,(tmpy)
        cp (ix+PC_Y)
        jr c,.nob2
        call start_fall         ; cascade!
.nob2:  pop ix
.nob:   call move_riders
        call squash_check
        ; landed?
        ld a,(trow)
        cp (ix+PC_Y)
        ret nz
        ld de,$0050             ; 50 points a floor
        call add_score
        ld a,(ix+PC_N)
        or a
        jr z,.stop
        ld a,(ix+PC_TF)
        cp PLATE
        jr z,.stop
        dec (ix+PC_N)
        inc (ix+PC_TF)
        ret
.stop:  ld a,SFX_LAND
        call play_sfx
        call kill_riders
        ld a,(ix+PC_TF)
        cp PLATE
        jr z,.plate
        ld (ix+PC_F),a
        ld (ix+PC_ST),0
        ret
.plate: ld (ix+PC_F),a
        ld (ix+PC_ST),2
        ld a,(tmpc)
        ld hl,colstk
        call idx_ptr
        inc (hl)
        ld b,(hl)
        ld a,(tmpc)
        ld hl,ncolpc
        call idx_byte
        cp b
        ret nz
        ; burger complete!
        ld a,(tmpc)
        ld hl,coldone
        call idx_ptr
        ld (hl),1
        ld a,(burgers)
        inc a
        ld (burgers),a
        ld de,$1000
        call add_score
        ld a,(ix+PC_X)
        ld (spk_x),a
        ld a,52
        ld (spk_y),a
        ld a,50
        ld (spk_tim),a
        ld a,(ix+PC_X)
        ld d,62
        ld e,P_BURGER
        jp popup_at

; target_row: IX -> A = row the piece is falling to (plate stacks grow upward)
target_row:
        ld a,(ix+PC_TF)
        cp PLATE
        jr z,.p
        call fyrow
        sub 2
        ret
.p:     ld a,(ix+PC_C)
        ld hl,colstk
        call idx_byte
        add a,a
        ld b,a
        ld a,60
        sub b
        ret

move_riders:
        push ix
        pop hl
        ld c,l
        ld iy,enemies
        ld b,MAXEN
.l:     ld a,(iy+E_ST)
        cp 3
        jr nz,.nx
        ld a,(iy+E_PC)
        cp c
        jr nz,.nx
        ld a,(ix+PC_Y)
        inc a
        ld (iy+E_Y),a
.nx:    ld de,ESIZE
        add iy,de
        djnz .l
        ret

kill_riders:
        push ix
        pop hl
        ld c,l
        xor a
        ld (ride_n),a
        ld iy,enemies
        ld b,MAXEN
.l:     ld a,(iy+E_ST)
        cp 3
        jr nz,.nx
        ld a,(iy+E_PC)
        cp c
        jr nz,.nx
        call squash_enemy_q     ; quiet: bonus handled below
        ld a,(ride_n)
        inc a
        ld (ride_n),a
.nx:    ld de,ESIZE
        add iy,de
        djnz .l
        ld a,(ride_n)
        or a
        ret z
        ; 500 x 2^(n-1)
        dec a
        ld hl,ride_pts
        call idx_word
        ex de,hl
        call add_score
        ld a,SFX_RIDE
        call play_sfx
        ld a,(ride_n)
        add a,P_500-1
        ld e,a
        ld d,(ix+PC_Y)
        ld a,(ix+PC_X)
        jp popup_at
ride_pts: dw $0500,$1000,$2000,$4000,$8000,$8000

; enemies under a falling piece get squashed
squash_check:
        ld iy,enemies
        ld b,MAXEN
.l:     ld a,(iy+E_ST)
        dec a
        cp 2
        jr nc,.nx
        ld a,(iy+E_X)
        add a,4
        sub (ix+PC_X)
        add a,2
        cp 20
        jr nc,.nx
        ld a,(iy+E_Y)
        sub (ix+PC_Y)
        jr c,.nx                ; foot above the piece top
        cp 9
        jr nc,.nx
        push bc
        call squash_enemy
        pop bc
.nx:    ld de,ESIZE
        add iy,de
        djnz .l
        ret

; IY = enemy: squashed flat, 500 points
squash_enemy:
        push ix
        ld de,$0500
        call add_score
        ld a,SFX_SQUASH
        call play_sfx
        ld a,(iy+E_X)
        ld d,(iy+E_Y)
        ld e,P_500
        call popup_at
        pop ix
squash_enemy_q:
        ld (iy+E_ST),4
        ld (iy+E_TIM),40
        ret

; ---------------------------------------------------------------------
; score: DE = 4-digit BCD to add.  Extra cook every 10,000.
; ---------------------------------------------------------------------
add_score:
        ld a,(mode)
        cp 1
        ret nz                  ; no scoring in the demo
        ld hl,score+2
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld a,(hudflag)
        or 1
        ld (hudflag),a
        ld a,(nextlife)
        ld b,a
        ld a,(score)
        cp b
        ret c
        ld a,b
        add a,1
        daa
        ld (nextlife),a
        ld a,(lives)
        cp 9
        ret nc
        inc a
        ld (lives),a
        ld a,2
        ld (hudflag),a
        ld a,SFX_RIDE
        call play_sfx
        ld a,(sy)
        ld d,a
        ld a,(sx)
        ld e,P_1UP
        jp popup_at

; ---------------------------------------------------------------------
; HUD: score, cooks, pepper, hi score, kitchen
; ---------------------------------------------------------------------
draw_hud:
        push bc
        ld a,1
        ld (noq),a
        ld de,$0000
        ld bc,$2006
        xor a
        call fill_rect
        call hud_body
        xor a
        ld (noq),a
        ld de,$0000
        ld bc,$2006
        call queue_rect
        pop bc
        ret
; score only (small rect)
draw_score:
        push bc
        ld a,1
        ld b,0
        call set_ink
        ld hl,score
        ld b,3
        ld de,$0000
        call print_bcd
        pop bc
        ret
hud_body:
        ld a,1
        ld b,0
        call set_ink
        ld hl,score
        ld b,3
        ld de,$0000
        call print_bcd
        ld a,3
        ld b,0
        call set_ink
        ld hl,s_hudl
        ld de,$0800
        call print
        ld a,(lives)
        ld de,$0900
        call hud_digit
        ld a,2
        ld b,0
        call set_ink
        ld hl,s_hudp
        ld de,$0B00
        call print
        ld a,(peppers)
        ld de,$0C00
        call hud_digit
        ld a,2
        ld b,0
        call set_ink
        ld hl,s_hi
        ld de,$0F00
        call print
        ld hl,hitab
        ld b,3
        ld de,$1100
        call print_bcd
        ld a,3
        ld b,0
        call set_ink
        ld hl,s_hudk
        ld de,$1A00
        call print
        ld a,(playclassic)
        or a
        jr nz,.cl
        ld a,(kitchen)
        inc a
        ld de,$1D00
        call hud_digit
        ld a,(lap)
        or a
        ret z
        ld hl,s_plus
        ld de,$1E00
        jp print
.cl:    ld hl,s_84
        ld de,$1D00
        jp print
s_hudl: db "[",0
s_hudp: db "]",0
s_hi:   db "HI",0
s_hudk: db "KIT",0
s_plus: db "+",0
s_84:   db "84",0

; A = 0..9 at D/E
hud_digit:
        add a,'0'
        ld (nameb),a
        xor a
        ld (nameb+1),a
        ld hl,nameb
        jp print

; ---------------------------------------------------------------------
; popups: A = x pixel, E = popup string index
; ---------------------------------------------------------------------
popup_at:
        push de
        push af
        call pop_remove         ; one at a time
        pop af
        pop de
        rrca
        rrca
        and $3F
        ld (pop_x),a
        ld a,e
        ld hl,popstr
        call idx_word
        ld (pop_str),hl
        ld b,0
.ln:    ld a,(hl)
        or a
        jr z,.lnd
        inc b
        inc hl
        jr .ln
.lnd:   ld a,b
        ld (pop_w),a
        ld a,(pop_x)            ; keep it on screen
        add a,b
        cp 33
        jr c,.xo
        ld a,32
        sub b
        ld (pop_x),a
.xo:    ld a,d
        sub 12
        jr nc,.y
        xor a
.y:     cp 7
        jr nc,.y2
        ld a,7
.y2:    cp 58
        jr c,.y3
        ld a,57
.y3:    ld (pop_y),a
        ld a,45
        ld (pop_tim),a
        ld a,1
        ld b,0
        call set_ink
        ld hl,(pop_str)
        ld a,(pop_x)
        ld d,a
        ld a,(pop_y)
        ld e,a
        jp print

; per frame: count the popup down, remove it when it expires
pop_tick:
        ld a,(pop_tim)
        or a
        ret z
        dec a
        ld (pop_tim),a
        ret nz
; pop_remove: repair the popup's rectangle
pop_remove:
        ld a,(pop_w)
        or a
        ret z
        ld b,a
        xor a
        ld (pop_w),a
        ld (pop_tim),a
        ld a,(pop_x)
        ld d,a
        ld a,(pop_y)
        ld e,a
        ld c,5
        jp repair_rect

; ---------------------------------------------------------------------
; repair_rect: D col, E row, B width, C height.  Restore the clean kitchen
; there, redraw every ingredient, background object and popup that overlaps
; it, and queue it.  (Keeps the moving-sprite count down to Sam + chasers.)
; ---------------------------------------------------------------------
repair_rect:
        push ix
        push iy
        call .go
        pop iy
        pop ix
        ret
.go:    ld a,d
        ld (rr_c0),a
        add a,b
        dec a
        ld (rr_c1),a
        ld a,e
        ld (rr_r0),a
        add a,c
        dec a
        ld (rr_r1),a
        push de
        push bc
        call restore_rect
        ; ingredients: rows Y..Y+2, bytes X/4..X/4+3
        ld a,(npc)
        or a
        jr z,.bo
        ld b,a
        ld ix,pieces
.pl:    push bc
        ld a,(ix+PC_X)
        rrca
        rrca
        and $3F
        ld d,a                  ; c0'
        add a,3
        ld e,a                  ; c1'
        ld a,(ix+PC_Y)
        ld b,a
        add a,2
        ld c,a
        call rr_hit
        call c,draw_piece
        ld de,PSIZE
        add ix,de
        pop bc
        djnz .pl
.bo:    ; background objects
        ld iy,bgobjs
        ld b,NBGOBJ
.ol:    push bc
        ld a,(iy+0)
        or a
        jr z,.on
        ld d,(iy+2)
        ld a,d
        add a,2
        ld e,a
        ld b,(iy+3)
        ld a,b
        add a,7
        ld c,a
        call rr_hit
        call c,bgobj_paint
.on:    ld de,4
        add iy,de
        pop bc
        djnz .ol
        ; popup text
        ld a,(pop_w)
        or a
        jr z,.q
        ld a,(pop_x)
        ld d,a
        ld a,(pop_w)
        add a,d
        dec a
        ld e,a
        ld a,(pop_y)
        ld b,a
        add a,4
        ld c,a
        call rr_hit
        jr nc,.q
        ld a,1
        ld (noq),a
        ld a,1
        ld b,0
        call set_ink
        ld hl,(pop_str)
        ld a,(pop_x)
        ld d,a
        ld a,(pop_y)
        ld e,a
        call print
        xor a
        ld (noq),a
.q:     pop bc
        pop de
        jp queue_rect

; rr_hit: D..E columns, B..C rows overlap the repair rect? -> carry
rr_hit:
        ld a,(rr_c1)
        cp d
        jr c,.no                ; rect ends left of object
        ld a,e
        ld hl,rr_c0
        cp (hl)
        jr c,.no
        ld a,(rr_r1)
        cp b
        jr c,.no
        ld a,c
        ld hl,rr_r0
        cp (hl)
        jr c,.no
        scf
        ret
.no:    or a
        ret

; ---------------------------------------------------------------------
; background objects: 8x8 sprites painted into BG at a byte column
; (bonus item, pepper cloud, burger sparkle).  Record: on, id, col, row.
; ---------------------------------------------------------------------
NBGOBJ  equ 3
BO_ITEM equ 0
BO_PEP  equ 1
BO_SPK  equ 2
; bgobj_set: C = slot, A = sprite id, D = col, E = row
bgobj_set:
        push af
        push de
        ld a,c
        add a,a
        add a,a
        ld hl,bgobjs
        call idx_ptr
        push hl
        pop iy
        pop de
        pop af
        ld b,a
        ld a,(iy+0)
        or a
        jr z,.new
        ld a,(iy+1)
        cp b
        jr nz,.chg
        ld a,(iy+2)
        cp d
        jr nz,.chg
        ld a,(iy+3)
        cp e
        ret z                   ; unchanged
.chg:   push bc
        push de
        push iy
        call bgobj_off
        pop iy
        pop de
        pop bc
.new:   ld (iy+0),1
        ld (iy+1),b
        ld (iy+2),d
        ld (iy+3),e
        call bgobj_paint
        ld d,(iy+2)
        ld e,(iy+3)
        ld bc,$0308
        jp queue_rect
; bgobj_clear: C = slot
bgobj_clear:
        ld a,c
        add a,a
        add a,a
        ld hl,bgobjs
        call idx_ptr
        push hl
        pop iy
        ld a,(iy+0)
        or a
        ret z
bgobj_off:      ; IY = record: remove and repair
        ld (iy+0),0
        ld d,(iy+2)
        ld e,(iy+3)
        ld bc,$0308
        jp repair_rect
; bgobj_paint: IY = record -> masked draw of the unshifted sprite into BG
bgobj_paint:
        push ix
        ld a,(iy+1)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,shtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = (mask,data) pairs
        inc hl
        inc hl
        ld a,(hl)
        ld (tmpd),a             ; rows
        ld a,(iy+3)
        ld (tmpx),a
.r:     ld a,(tmpx)
        cp 64
        jr nc,.x
        call bgrow
        ld a,(iy+2)
        add a,l
        ld l,a
        ld b,3
.b:     ld a,(de)               ; mask
        and (hl)
        inc de
        ex de,hl
        or (hl)                 ; data
        ex de,hl
        inc de
        ld (hl),a
        inc hl
        djnz .b
        ld a,(tmpx)
        inc a
        ld (tmpx),a
        ld a,(tmpd)
        dec a
        ld (tmpd),a
        jr nz,.r
.x:     pop ix
        ret
bgobjs_reset:
        ld hl,bgobjs
        ld b,NBGOBJ*4
.c:     ld (hl),0
        inc hl
        djnz .c
        ret

P_500    equ 0
P_1000   equ 1
P_2000   equ 2
P_4000   equ 3
P_8000   equ 4
P_BURGER equ 5
P_PEPPER equ 6
P_200    equ 7
P_1500   equ 8
P_1UP    equ 9
P_SUPER  equ 10
P_RIGHT  equ 11
P_WRONG  equ 12
P_ORDER  equ 13
P_PAUSED equ 14
popstr: dw ps0,ps1,ps2,ps3,ps4,ps5,ps6,ps7,ps8,ps9,ps10,ps11,ps12,ps13,ps14
ps0:    db "500",0
ps1:    db "1000",0
ps2:    db "2000",0
ps3:    db "4000",0
ps4:    db "8000",0
ps5:    db "BURGER UP!",0
ps6:    db "+1 PEPPER",0
ps7:    db "200",0
ps8:    db "1500",0
ps9:    db "1UP!",0
ps10:   db "SPATULA!",0
ps11:   db "YUM!",0
ps12:   db "WRONG!",0
ps13:   db "ORDER UP!",0
ps14:   db "PAUSED",0
