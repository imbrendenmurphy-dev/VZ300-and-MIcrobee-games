; =====================================================================
;  GAME: the arena, bombs, flames, crumbling mounds, items, the HUD.
;  Logic runs once a frame (25 frames a second).
;  Positions are in 2-pixel units: a tile is 8 units (16 pixels).
; =====================================================================
NACT    equ 8               ; enemies
ASZ     equ 16
A_TYPE  equ 0               ; 0 none, 1 toad, 2 frill-neck, 3 bin chicken
A_HX    equ 1
A_HY    equ 2
A_DIR   equ 3
A_ANIM  equ 4
A_PAUSE equ 5
A_STEP  equ 6
A_STUN  equ 7
A_CARRY equ 8
A_CHARGE equ 9
ET_TOAD equ 1
ET_FRILL equ 2
ET_IBIS equ 3

NBOMB   equ 8
BSZ     equ 8
B_ON    equ 0
B_TX    equ 1
B_TY    equ 2
B_FUSE  equ 3
B_RANGE equ 4
B_CARRIED equ 5

NPART   equ 12
PSZ     equ 8
P_T     equ 0
P_X     equ 1               ; screen position in 2-pixel units
P_Y     equ 2
P_VX    equ 3
P_VY    equ 4
P_FR    equ 5
P_INK   equ 6
P_G     equ 7

M_FLOOR equ 0
M_BORDER equ 1
M_PILLAR equ 2
M_MOUND equ 3
M_BURROW equ 4

FUSE    equ 75              ; 3 seconds
WARN    equ 23              ; the last second: bombs flash red
FLAME   equ 14              ; flame life (frames)
FL_HURT equ 4               ; flames hurt while their time is above this
CRUMBLE equ 12

IT_FIRE equ 1
IT_NUT  equ 2
IT_HEART equ 3
IT_THONG equ 4
IT_EXIT equ 5

ACT_NONE equ 0
ACT_PLACE equ 1
ACT_STARTLE equ 2
ACT_COLLECT equ 3
ACT_HURT equ 4
ACT_WIN equ 5
ACT_DEAD equ 6

; ---------------------------------------------------------------------
; map helpers. D = tx, E = ty -> HL = ty*32 + tx (keeps BC, DE)
tidx:   ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or d
        ld l,a
        ret
; D, E -> A = amap value, HL -> amap entry
amap_at:
        call tidx
        push de
        ld de,amap
        add hl,de
        pop de
        ld a,(hl)
        ret
; walkable tile? (floor or burrow) -> Z = yes
walkable:
        ld a,d
        cp AW
        jr nc,.no
        ld a,e
        cp AH
        jr nc,.no
        call amap_at
        or a
        ret z
        cp M_BURROW
        ret
.no:    or 1
        ret
; is there a bomb at D, E? -> NZ = yes (A = bomb number + 1)
bomb_at:
        call tidx
        push de
        ld de,bmap
        add hl,de
        pop de
        ld a,(hl)
        or a
        ret

; can the thing at (C = hx, B = hy) enter tile D, E? -> Z = yes
; (a bomb blocks unless the thing is already overlapping that tile)
can_enter:
        call walkable
        ret nz
        call bomb_at
        jr nz,.bomb
        xor a
        ret
.bomb:  ld a,d                  ; |hx - tx*8| < 8 and |hy - ty*8| < 8 ?
        add a,a
        add a,a
        add a,a
        sub c
        jr nc,.p1
        neg
.p1:    cp 8
        jr nc,.no
        ld a,e
        add a,a
        add a,a
        add a,a
        sub b
        jr nc,.p2
        neg
.p2:    cp 8
        jr nc,.no
        xor a
        ret
.no:    or 1
        ret

; A = units -> A = nearest tile ((A + 4) / 8)
round_t:
        add a,4
        rrca
        rrca
        rrca
        and $1F
        ret

; ---------------------------------------------------------------------
; set_tile: D = tx, E = ty, A = tile number: its 4 cells into the screen
set_tile:
        push bc
        push de
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc               ; * 12
        ld bc,tile_tab
        add hl,bc
        ld (t_ptr),hl
        ld a,d
        add a,a
        dec a
        ld (t_c),a              ; column 2tx-1 (FFh: off the left edge)
        ld a,e
        add a,a
        ld (t_r),a              ; row 2ty
        ld a,(curblk)
        push af
        ld a,BLK_RT
        call map_blk
        ld b,0                  ; quadrant
.q:     ld a,(t_c)
        bit 0,b
        jr z,$+3
        inc a
        cp 40
        jr nc,.skip             ; off the left or right edge
        ld d,a
        ld a,(t_r)
        bit 1,b
        jr z,$+3
        inc a
        or a
        jr z,.skip              ; row 0 is the HUD
        cp 25
        jr nc,.skip
        ld e,a
        call cell_of            ; HL = cell
        push bc
        push hl
        ld hl,(t_ptr)
        ld a,b
        add a,a
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = glyph
        ld hl,(t_ptr)
        ld a,8
        add a,b
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld c,(hl)               ; colour
        pop hl
        call set_cell_rt
        pop bc
.skip:  inc b
        ld a,b
        cp 4
        jr nz,.q
        pop af
        call map_port
        pop hl
        pop de
        pop bc
        ret

; draw_tile: D = tx, E = ty: what the tile shows now (keeps BC, DE, HL, IX)
draw_tile:
        push bc
        push de
        push hl
        push ix
        call tidx
        ld (t_idx),hl
        call dt_which
        call set_tile
        pop ix
        pop hl
        pop de
        pop bc
        ret
; A = map BC at (t_idx)
mget:   ld hl,(t_idx)
        add hl,bc
        ld a,(hl)
        ret
dt_which:
        ld bc,amap
        call mget
        cp M_BORDER
        jr nz,.n1
        ld a,T_BORDER
        ret
.n1:    cp M_PILLAR
        jr nz,.n2
        ld a,T_PILLAR
        ret
.n2:    cp M_MOUND
        jr nz,.n3
        ld bc,cmap
        call mget               ; crumble time 0..11 -> stage 0..8
        ld c,a
        add a,a
        add a,c
        rrca
        rrca
        and $3F
        cp 9
        jr c,.ms
        ld a,8
.ms:    add a,T_MOUND0
        ret
.n3:    ld (t_dt),a              ; floor or burrow
        ld bc,fmap
        call mget
        or a
        jr z,.nofl
        cp FL_HURT+1            ; flame: phase from its time
        jr nc,.ph
        ld a,T_SMOKE
        ret
.ph:    ld (t_ph),a
        ld bc,fkind
        call mget
        ld c,a
        add a,a
        add a,c                 ; kind * 3
        ld c,a
        ld a,(t_ph)
        ld b,0
        cp 11
        jr nc,.p
        inc b
        cp 8
        jr nc,.p
        inc b
.p:     ld a,b
        add a,c
        add a,T_FL_c0
        ret
.nofl:  ld bc,bmap
        call mget
        or a
        jr z,.nob
        dec a                   ; a bomb
        call bomb_ix
        ld a,(ix+B_FUSE)
        cp WARN
        jr nc,.calm
        rrca
        and 1
        add a,2                 ; warn: fast red pulse (index 4..7)
        jr .bt
.calm:  rrca
        rrca
        and 1
.bt:    add a,a
        ld c,a
        ld a,(gtick)
        and 1
        add a,c
        add a,T_BOMB000
        ret
.nob:   ld a,(t_dt)
        cp M_BURROW
        jr nz,.nobur
        ld a,T_BURROW
        ret
.nobur: ld bc,imap
        call mget
        or a
        jp m,.noit
        jr z,.noit
        dec a
        add a,T_IT_FIRE
        ret
.noit:  ld bc,wmap
        call mget
        and 1
        jr z,.nowarn
        ld a,(gtick)
        and 2
        ld a,T_WARN
        ret z
        ld a,T_WARN2
        ret
.nowarn:                        ; floor: variety and a shadow under walls
        ld a,d
        add a,a
        add a,d
        ld c,a
        ld a,e
        add a,a
        add a,a
        add a,e
        add a,c
        and 3
        ld c,a
        ld a,e
        or a
        jr z,.nsh
        dec e
        call amap_at
        inc e
        or a
        jr z,.nsh
        cp M_BURROW
        jr z,.nsh
        ld a,c
        add a,T_FLOOR0S
        ret
.nsh:   ld a,c
        add a,T_FLOOR0
        ret

; A = bomb number -> IX = its record
bomb_ix:
        push de
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld ix,bombs
        add ix,de
        pop de
        ret

; draw every tile of the arena
draw_arena:
        ld e,0
.r:     ld d,0
.c:     call draw_tile
        inc d
        ld a,d
        cp AW
        jr nz,.c
        inc e
        ld a,e
        cp AH
        jr nz,.r
        ret

; ---------------------------------------------------------------------
; stage_init: build the arena for (stage)
stage_init:
        ld hl,amap
        ld de,amap+1
        ld bc,maps_end-amap-1
        ld (hl),0
        ldir
        ld hl,actors
        ld de,actors+1
        ld bc,NACT*ASZ+NBOMB*BSZ+NPART*PSZ-1
        ld (hl),0
        ldir
        ld a,(stage)
        ld l,a
        ld h,$5A
        add hl,hl
        ld de,$3C7B
        add hl,de
        ld (seed),hl
        ; border and pillars
        ld e,0
.r:     ld d,0
.c:     ld a,d
        or a
        jr z,.bd
        cp AW-1
        jr z,.bd
        ld a,e
        or a
        jr z,.bd
        cp AH-1
        jr z,.bd
        ld a,d
        or e
        and 1
        jr nz,.soft
        ld a,M_PILLAR
        jr .put
.bd:    ld a,M_BORDER
        jr .put
.soft:  call in_safe
        jr z,.nx
        call random
        cp 118                  ; 46% mounds
        jr nc,.nx
        ld a,M_MOUND
.put:   push af
        call tidx
        ld bc,amap
        add hl,bc
        pop af
        ld (hl),a
.nx:    inc d
        ld a,d
        cp AW
        jr nz,.c
        inc e
        ld a,e
        cp AH
        jr nz,.r
        ; items hidden in mounds
        ld hl,item_list
.it:    ld a,(hl)
        or a
        jr z,.itd
        push hl
        or $80
        ld (t_k),a
        ld c,200
.try:   dec c
        jr z,.give
        call rand_tile
        call amap_at
        cp M_MOUND
        jr nz,.try
        call tidx
        ld bc,imap
        add hl,bc
        ld a,(hl)
        or a
        jr nz,.try
        ld a,(t_k)
        ld (hl),a
.give:  pop hl
        inc hl
        jr .it
.itd:   ; two burrows on open floor
        ld b,2
.bu:    push bc
        ld c,200
.bt:    dec c
        jr z,.bg
        call rand_tile
        call in_safe
        jr z,.bt
        call amap_at
        or a
        jr nz,.bt
        ld (hl),M_BURROW
.bg:    pop bc
        djnz .bu
        ; enemies
        ld a,(stage)
        add a,3
        cp NACT+1
        jr c,.ne
        ld a,NACT
.ne:    ld (nenemy),a
        ld b,a
        ld ix,actors
        ld c,0                  ; enemy number
.en:    push bc
.ep:    call rand_tile
        ld a,d
        add a,e
        cp 8
        jr c,.ep
        call amap_at
        or a
        jr nz,.ep
        call enemy_type
        ld (ix+A_TYPE),a
        ld a,d
        add a,a
        add a,a
        add a,a
        ld (ix+A_HX),a
        ld a,e
        add a,a
        add a,a
        add a,a
        ld (ix+A_HY),a
        call random
        and 3
        ld (ix+A_DIR),a
        call random
        and 31
        ld (ix+A_PAUSE),a
        ld de,ASZ
        add ix,de
        pop bc
        inc c
        djnz .en
        ; the player
        ld a,8
        ld (p_hx),a
        ld (p_hy),a
        ld a,3
        ld (p_dir),a
        xor a
        ld (p_act),a
        ld (p_inv),a
        ld (p_buft),a
        ld (bm_on),a
        ld (gstate),a
        ld (allclear),a
        ld (msg_on),a
        ld (p_idle),a
        ld a,FUSE
        ld (gtimer),a
        call draw_screen
        ret

item_list:
        db IT_EXIT,IT_FIRE,IT_FIRE,IT_NUT,IT_NUT,IT_HEART,IT_THONG,IT_FIRE,0

; -> D, E = a random interior tile
rand_tile:
        ld b,AW-2
        call rand_n
        inc a
        ld d,a
        ld b,AH-2
        call rand_n
        inc a
        ld e,a
        ret
; the start corner stays clear: Z = in it
in_safe:
        ld a,d
        cp 4
        jr nc,.n
        ld a,e
        cp 3
        jr nc,.n2
        xor a
        ret
.n2:    ld a,d
        cp 3
        jr nc,.n
        ld a,e
        cp 4
        jr nc,.n
        xor a
        ret
.n:     or 1
        ret
; C = enemy number -> A = its type for this stage
enemy_type:
        ld a,(stage)
        or a
        ld a,ET_TOAD
        ret z
        ld a,c
        cp 2
        ld a,ET_TOAD
        ret c
        ld a,(stage)
        cp 2
        jr c,.fr
        ld a,c
        cp 4
        ld a,ET_IBIS
        ret z
.fr:    ld a,c
        and 1
        ld a,ET_FRILL
        ret z
        ld a,ET_TOAD
        ret

; the whole screen: the HUD row, the arena
draw_screen:
        call clear_screen
        call draw_arena
        call draw_hud
        ld a,$FF                ; nothing flies over the HUD
        ld e,0
        ld c,1
        call block_rows
        jp all_dirty

; print HL at D, E in colour A
print_at:
        ld (txt_col),a
        push hl
        ld hl,G_FONT
        ld (txt_font),hl
        pop hl
        jp print

s_world: db "RED CENTRE",0
s_score: db "SCORE",0

; the HUD, row 0:  1-3  hearts  nut x3  flame x2  boomerang thongs  WORLD  score
draw_hud:
        ld hl,numbuf            ; "1-n"
        ld (hl),'1'
        inc hl
        ld (hl),'-'
        inc hl
        ld a,(stage)
        ld b,7
.m7:    cp b
        jr c,.s
        sub b
        jr .m7
.s:     add a,'1'
        ld (hl),a
        inc hl
        ld (hl),0
        ld hl,numbuf
        ld de,0*256+0
        ld a,YELLOW
        call print_at
        ld hl,s_world
        ld de,23*256+0
        ld a,BRED
        call print_at
        call score_text
        ld hl,numbuf
        ld de,34*256+0
        ld a,WHITE
        call print_at
        ; hearts
        ld b,0
.h:     ld a,(p_maxh)
        cp b
        jr z,.hx
        ld c,BRED
        ld hl,IC_HEART
        ld a,(p_hearts)
        dec a
        cp b
        jr nc,.hl
        ld c,DGREY
        ld hl,IC_HEART_E        ; an empty heart: its own shape for mono
.hl:    ld a,b
        add a,4
        ld d,a
        ld e,0
        push bc
        call put_icon
        pop bc
        inc b
        jr .h
.hx:    ; bombs, range, boomerang, thongs
        ld d,10
        ld e,0
        ld hl,IC_NUT
        ld c,BGREEN
        call put_icon
        ld a,(p_bombs)
        ld d,11
        call put_count
        ld d,14
        ld e,0
        ld hl,IC_FLAME
        ld c,YELLOW
        call put_icon
        ld a,(p_range)
        ld d,15
        call put_count
        ld d,18
        ld e,0
        ld hl,IC_BOOM
        ld c,YELLOW
        ld a,(bm_on)
        or a
        jr z,.bo
        ld hl,0                 ; thrown: the slot is empty
.bo:    call put_icon
        ld d,20
        ld e,0
        ld hl,IC_THONG
        ld c,BCYAN
        ld a,(p_speed)
        or a
        jr nz,.th
        ld hl,0
.th:    jp put_icon

; icon HL at D, E in colour C
put_icon:
        push hl
        call cell_of
        pop de
        jp set_cell
; "xN" at D, row 0
put_count:
        add a,'0'
        ld (numbuf+1),a
        ld a,'X'
        ld (numbuf),a
        xor a
        ld (numbuf+2),a
        ld hl,numbuf
        ld e,0
        ld a,GREY
        jp print_at

; score (BCD) -> numbuf, 6 digits
score_text:
        ld hl,score
        ld de,numbuf
        ld b,3
.d:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        ld (de),a
        inc de
        ld a,(hl)
        and 15
        add a,'0'
        ld (de),a
        inc de
        inc hl
        djnz .d
        xor a
        ld (de),a
        ret
; add DE (4 BCD digits) to the score
add_score:
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
        ld a,1
        ld (hud_dirty),a
        ret

; ---------------------------------------------------------------------
; messages in a box across the middle of the arena (rows 11-13)
MSG_ROW equ 12
show_msg:
        ld (t_ptr),hl
        ld a,$FF
        ld e,MSG_ROW-1
        ld c,3
        call block_rows
        ld hl,0
        ld (fc_glyph),hl
        ld a,BLUE*16
        ld (txt_col),a
        ld de,1*256+MSG_ROW-1
        ld bc,38*256+3
        call fill_cells
        ld a,WHITE+BLUE*16
        ld (txt_col),a
        ld hl,G_FONT
        ld (txt_font),hl
        ld hl,(t_ptr)
        ld e,MSG_ROW
        call print_c
        ld a,1
        ld (msg_on),a
        ret
hide_msg:
        ld a,(msg_on)
        or a
        ret z
        xor a
        ld (msg_on),a
        ld e,MSG_ROW-1
        ld c,3
        call block_rows
        ld e,5                  ; tile rows 5 and 6 hold cell rows 10-13
.r:     ld d,0
.c:     call draw_tile
        inc d
        ld a,d
        cp AW
        jr nz,.c
        inc e
        ld a,e
        cp 7
        jr nz,.r
        ret

; ---------------------------------------------------------------------
; bombs
; place a bomb at the player's tile -> NC if placed
place_bomb:
        ld a,(p_hx)
        call round_t
        ld d,a
        ld a,(p_hy)
        call round_t
        ld e,a
        call amap_at
        or a
        jr nz,.no               ; burrow (or anything else)
        call bomb_at
        jr nz,.no
        ; count the live bombs; find a free slot
        ld ix,bombs
        ld b,NBOMB
        ld c,0
        ld hl,0
.f:     ld a,(ix+B_ON)
        or a
        jr z,.fr
        inc c
        jr .n
.fr:    ld a,h
        or l
        jr nz,.n
        push ix
        pop hl
.n:     push de
        ld de,BSZ
        add ix,de
        pop de
        djnz .f
        ld a,(p_bombs)
        dec a
        cp c
        jr c,.no                ; all out
        ld a,h
        or l
        jr z,.no
        push hl
        pop ix
        ld (ix+B_ON),1
        ld (ix+B_TX),d
        ld (ix+B_TY),e
        ld (ix+B_FUSE),FUSE
        ld a,(p_range)
        ld (ix+B_RANGE),a
        ld (ix+B_CARRIED),0
        push ix
        pop hl
        ld bc,bombs
        or a
        sbc hl,bc
        ld a,l
        rrca
        rrca
        rrca
        inc a
        push af
        call tidx
        ld bc,bmap
        add hl,bc
        pop af
        ld (hl),a
        call draw_tile
        ld a,SFX_PLACE
        call play_sfx
        or a
        ret
.no:    scf
        ret

; every bomb: fuse down; at 0 it goes off
bombs_update:
        xor a
        ld (chain),a
        ld ix,bombs
        ld b,NBOMB
.b:     push bc
        ld a,(ix+B_ON)
        or a
        jr z,.n
        dec (ix+B_FUSE)
        ld a,(ix+B_FUSE)
        cp WARN
        jr nz,.nw
        push af
        ld a,SFX_FIZZ
        call play_sfx
        pop af
.nw:    or a
        jr nz,.n
        call explode
.n:     ld de,BSZ
        add ix,de
        pop bc
        djnz .b
        ld a,(chain)
        cp 2
        ret c
        ld a,SFX_BIGBOOM
        jp play_sfx

; explode bomb IX
explode:
        ld (ix+B_ON),0
        ld a,(ix+B_CARRIED)
        or a
        jr z,.nc
        ld (ix+B_CARRIED),0
        xor a
        ld (bm_carry),a
        ; a carried bomb goes off where the boomerang is (or at Wally)
        ld a,(bm_hx)
        call round_t
        ld d,a
        ld a,(bm_hy)
        call round_t
        ld e,a
        call walkable
        jr z,.at
        ld a,(p_hx)
        call round_t
        ld d,a
        ld a,(p_hy)
        call round_t
        ld e,a
        jr .at
.nc:    ld d,(ix+B_TX)
        ld e,(ix+B_TY)
        call tidx
        ld bc,bmap
        add hl,bc
        ld (hl),0
.at:    ld a,(chain)
        inc a
        ld (chain),a
        ld a,SFX_BOOM
        call play_sfx
        ; sparks
        push de
        call tile_scr
        ld a,3
.sp:    push af
        ld a,SF_SPARK
        ld h,WHITE
        call spawn_part
        pop af
        dec a
        jr nz,.sp
        pop de
        ld a,d
        ld (t_sx),a
        ld a,e
        ld (t_sy),a
        xor a                   ; centre
        call set_flame
        ld a,(ix+B_RANGE)
        ld (t_rng),a
        ld c,0                  ; direction 0 R 1 L 2 U 3 D
.dir:   ld b,1
.step:  call dir_step
        call amap_at
        cp M_BORDER
        jr z,.stop
        cp M_PILLAR
        jr z,.stop
        cp M_MOUND
        jr nz,.open
        push bc
        ld bc,cmap
        call tidx
        add hl,bc
        pop bc
        ld a,(hl)
        or a
        jr nz,.stop
        ld (hl),1               ; it starts to crumble
        call debris
        push de
        ld de,$0010
        call add_score
        pop de
        jr .stop
.open:  ld a,(t_rng)
        cp b                    ; the last step of the range: a tip
        jr z,.tip
        inc b                   ; the next tile closed: a tip too
        call dir_step
        call walkable
        push af
        dec b
        call dir_step
        pop af
        jr nz,.tip
        ld a,c
        cp 2
        ld a,1                  ; h
        jr c,.k
        ld a,2                  ; v
        jr .k
.tip:   ld a,c
        push hl
        ld hl,tipkind
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
.k:     call set_flame
        call bomb_at
        jr z,.nob
        dec a
        push ix
        call bomb_ix
        ld a,(ix+B_FUSE)
        cp 3
        jr c,.fz
        ld (ix+B_FUSE),2        ; chain reaction
.fz:    pop ix
        jr .stop
.nob:   inc b
        ld a,(t_rng)
        cp b
        jr nc,.step
.stop:  inc c
        ld a,c
        cp 4
        jp nz,.dir
        ; Wally flinches at a blast near him
        ld a,(t_sx)
        ld d,a
        ld a,(t_sy)
        ld e,a
        ld a,(p_hx)
        call round_t
        sub d
        jr nc,$+4
        neg
        ld b,a
        ld a,(p_hy)
        call round_t
        sub e
        jr nc,$+4
        neg
        add a,b
        cp 5
        ret nc
        ld a,(p_act)
        or a
        ret nz
        ld a,ACT_STARTLE
        ld b,10
        jp set_act
tipkind: db 4,3,5,6             ; r l u d

; D, E = tile (t_sx, t_sy) moved B tiles in direction C (keeps BC, HL)
dir_step:
        ld a,(t_sx)
        ld d,a
        ld a,(t_sy)
        ld e,a
        ld a,c
        or a
        jr nz,.l
        ld a,d
        add a,b
        ld d,a
        ret
.l:     dec a
        jr nz,.u
        ld a,d
        sub b
        ld d,a
        ret
.u:     dec a
        jr nz,.d
        ld a,e
        sub b
        ld e,a
        ret
.d:     ld a,e
        add a,b
        ld e,a
        ret

; D, E -> B, C = the tile's centre in 2-pixel screen units (keeps DE)
tile_scr:
        ld a,d
        add a,a
        add a,a
        add a,a
        add a,OX/2+3
        ld b,a
        ld a,e
        add a,a
        add a,a
        add a,e
        add a,a                 ; ty * 10 (a tile is 20 lines)
        add a,OY/2+3
        ld c,a
        ret

; A = kind at D, E: flame there (crossing flames make a centre)
set_flame:
        push de
        push hl
        push bc
        ld b,a
        call tidx
        push hl
        ld de,fmap
        add hl,de
        ld a,(hl)
        ld (hl),FLAME
        pop hl
        ld de,fkind
        add hl,de
        or a
        jr z,.new
        ld a,(hl)
        cp b
        jr z,.new
        ld b,0
.new:   ld (hl),b
        pop bc
        pop hl
        pop de
        jp draw_tile

; debris from the mound at D, E
debris:
        push bc
        push de
        push hl
        call tile_scr
        ld a,4
.d:     push af
        and 1
        ld a,SF_DOT
        ld h,YELLOW
        jr z,.y
        ld h,BRED
.y:     call spawn_part
        pop af
        dec a
        jr nz,.d
        ld a,SFX_CRUMBLE
        call play_sfx
        pop hl
        pop de
        pop bc
        ret

; ---------------------------------------------------------------------
; tiles_pass: flames burn down, mounds crumble, bombs pulse, warnings
tiles_pass:
        ; the blast preview: mark (bit 1) the tiles warned bombs will hit
        ld a,(preview)
        or a
        jr z,.nopv
        ld ix,bombs
        ld b,NBOMB
.wb:    push bc
        ld a,(ix+B_ON)
        or a
        jr z,.wn
        ld a,(ix+B_CARRIED)
        or a
        jr nz,.wn
        ld a,(ix+B_FUSE)
        cp WARN
        jr nc,.wn
        call warn_bomb
.wn:    ld de,BSZ
        add ix,de
        pop bc
        djnz .wb
.nopv:  ld hl,bmap+33         ; quick look: anything going on at a tile?
        ld e,1
.r:     ld d,1
.c:     push hl
        ld a,(hl)               ; bomb
        ld bc,MAPSZ
        add hl,bc
        or (hl)                 ; flame
        add hl,bc
        add hl,bc
        or (hl)                 ; crumbling
        add hl,bc
        or (hl)                 ; warning
        pop hl
        call nz,tile_tick
        inc hl
        inc d
        ld a,d
        cp AW-1
        jr nz,.c
        ld bc,32-(AW-2)
        add hl,bc
        inc e
        ld a,e
        cp AH-1
        jr nz,.r
        ret

; one tile with something going on (D, E): keeps DE, HL
tile_tick:
        push hl
        call tidx
        ld (t_idx),hl
        xor a
        ld (t_k),a              ; changed?
        ld bc,wmap
        call mget
        ld b,a
        rrca
        xor b
        and 1
        ld (t_k),a              ; old != new
        ld a,b
        rrca
        and 1
        ld (hl),a               ; new -> bit 0
        ld bc,fmap
        call mget
        or a
        jr z,.tnof
        dec (hl)
        ld a,(hl)
        cp 11
        jr z,.tch
        cp 8
        jr z,.tch
        cp FL_HURT
        jr z,.tch
        or a
        jr nz,.tnof
.tch:    ld a,1
        ld (t_k),a
.tnof:   ld bc,cmap
        call mget
        or a
        jr z,.tnoc
        inc (hl)
        ld a,1
        ld (t_k),a
        ld a,(hl)
        cp CRUMBLE
        jr nz,.tnoc
        ld (hl),0
        call mound_gone
.tnoc:   ld bc,bmap
        call mget
        or a
        jr z,.tnob
        ld a,1
        ld (t_k),a
.tnob:   ld a,(t_k)
        or a
        call nz,draw_tile
        pop hl
        ret

; the mound at D, E has crumbled away: floor, its item shows, the tile
; below loses its shadow
mound_gone:
        ld hl,(t_idx)
        push hl
        call amap_at
        ld (hl),M_FLOOR
        call tidx
        ld bc,imap
        add hl,bc
        res 7,(hl)
        inc e
        call draw_tile
        dec e
        pop hl
        ld (t_idx),hl
        ret

; mark bit 1 of wmap on the floor tiles bomb IX will hit
warn_bomb:
        ld d,(ix+B_TX)
        ld e,(ix+B_TY)
        ld a,d
        ld (t_sx),a
        ld a,e
        ld (t_sy),a
        call .mark
        ld c,0
.dir:   ld b,1
.st:    call dir_step
        call amap_at
        cp M_BORDER
        jr z,.nd
        cp M_PILLAR
        jr z,.nd
        cp M_MOUND
        jr z,.nd
        call .mark
        inc b
        ld a,(ix+B_RANGE)
        cp b
        jr nc,.st
.nd:    inc c
        ld a,c
        cp 4
        jr nz,.dir
        ret
.mark:  push bc
        call tidx
        ld bc,wmap
        add hl,bc
        set 1,(hl)
        pop bc
        ret

; ---------------------------------------------------------------------
; particles: B = x, C = y (2-pixel screen units), A = frame, H = ink
spawn_part:
        push ix
        push de
        ld e,a
        ld ix,parts
        ld d,NPART
.f:     ld a,(ix+P_T)
        or a
        jr z,.got
        push de
        ld de,PSZ
        add ix,de
        pop de
        dec d
        jr nz,.f
        pop de
        pop ix
        ret
.got:   ld (ix+P_X),b
        ld (ix+P_Y),c
        ld (ix+P_FR),e
        ld (ix+P_INK),h
        ld (ix+P_G),1
        push bc
        call random
        and 3
        sub 2
        jr nz,$+3
        inc a
        ld (ix+P_VX),a
        call random
        and 1
        add a,2
        neg
        ld (ix+P_VY),a
        call random
        and 7
        add a,10
        ld (ix+P_T),a
        pop bc
        pop de
        pop ix
        ret
; a puff where an enemy was: B, C = position (2-pixel screen units)
spawn_puff:
        push ix
        ld ix,parts
        ld d,NPART
.f:     ld a,(ix+P_T)
        or a
        jr z,.got
        push de
        ld de,PSZ
        add ix,de
        pop de
        dec d
        jr nz,.f
        pop ix
        ret
.got:   ld (ix+P_X),b
        ld (ix+P_Y),c
        ld (ix+P_FR),SF_PUFF0
        ld (ix+P_INK),WHITE
        xor a
        ld (ix+P_VX),a
        ld (ix+P_VY),a
        ld (ix+P_G),a
        ld (ix+P_T),12
        pop ix
        ret

parts_update:
        ld ix,parts
        ld b,NPART
.p:     ld a,(ix+P_T)
        or a
        jr z,.n
        dec (ix+P_T)
        ld a,(ix+P_X)
        add a,(ix+P_VX)
        ld (ix+P_X),a
        ld a,(ix+P_Y)
        add a,(ix+P_VY)
        ld (ix+P_Y),a
        ld a,(ix+P_G)
        or a
        jr z,.ng
        ld a,(gtick)
        and 1
        jr z,.ng
        inc (ix+P_VY)
.ng:    ld a,(ix+P_FR)
        cp SF_PUFF0
        jr nz,.n
        ld a,(ix+P_T)
        cp 6
        jr nc,.n
        ld (ix+P_FR),SF_PUFF1
        ld (ix+P_INK),GREY
.n:     ld de,PSZ
        add ix,de
        djnz .p
        ret

parts_draw:
        ld ix,parts
        ld b,NPART
.p:     push bc
        ld a,(ix+P_T)
        or a
        jr z,.n
        ld a,(ix+P_X)
        ld l,a
        ld h,0
        add hl,hl
        ld (spr_x),hl
        ld a,(ix+P_Y)
        ld l,a
        ld h,0
        add hl,hl
        ld (spr_y),hl
        ld a,(ix+P_INK)
        ld (spr_ink),a
        ld a,(ix+P_FR)
        call spr_draw
.n:     ld de,PSZ
        add ix,de
        pop bc
        djnz .p
        ret
