; =====================================================================
;  game.asm - stage setup, renderer, HUD, player, items, main loop
; =====================================================================
TL_SHADOW equ $06
MAXTRAPS equ 4

; ---- world table: css, cmap0..3, flash, outline(logical), hud_bg, hud_fg, hazlook,
;      wall(2) floor(2) shadow(2), music(2)  = 18 bytes
WSZ     equ 18
world_tab:
        ; W1 suburbs: green lawn, yellow brick, blue edges
        db 0, 0,1,2,3, 1, 2, 2,1, 0
        dw tl_W_BRICK, tl_T_GRASS, tl_T_GRASSSH, mus_game
        ; W2 cannery: buff tiles, magenta cans, orange edges
        db CSS, 0,1,2,3, 1, 3, 2,0, 1
        dw tl_W_CANS, tl_T_CHECK, tl_T_CHECKSH, mus_game2
        ; W3 lab: blue floor, green walls, yellow edges ('b' logical -> green)
        db 0, 2,1,0,3, 1, 1, 3,1, 2
        dw tl_W_LAB, tl_T_GRID, tl_T_GRIDSH, mus_game
        ; bonus: magenta floor party
        db CSS, 2,1,0,3, 1, 1, 0,2, 0
        dw tl_W_CANS, tl_T_PARTY, tl_T_PARTY, mus_bonus

; =====================================================================
;  cell helpers
; =====================================================================
; cell_addr: A = cell -> HL = screen address
cell_addr:
        push de
        ld e,a
        rrca
        rrca
        rrca
        rrca
        and $0F                 ; cy
        add a,a
        ld hl,rowbase
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,e
        and $0F
        add a,a
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        pop de
        ret
rowbase:
        dw VRAM+(MAZEY+0)*32, VRAM+(MAZEY+5)*32, VRAM+(MAZEY+10)*32, VRAM+(MAZEY+15)*32
        dw VRAM+(MAZEY+20)*32, VRAM+(MAZEY+25)*32, VRAM+(MAZEY+30)*32, VRAM+(MAZEY+35)*32
        dw VRAM+(MAZEY+40)*32, VRAM+(MAZEY+45)*32, VRAM+(MAZEY+50)*32

; tile_ptr: A = cell -> HL = &tilemap[cell]
tile_ptr:
        ld hl,tilemap
        add a,l
        ld l,a
        ret nc
        inc h
        ret
; tile_get: A = cell -> A = tile code (dirty bit stripped)
tile_get:
        push hl
        call tile_ptr
        ld a,(hl)
        pop hl
        bit 7,a
        ret nz
        and $3F
        ret
; tile_set: A = cell, C = code ; marks dirty
tile_set:
        push hl
        push af
        call tile_ptr
        ld a,(hl)
        and TL_DIRTY
        or c
        ld (hl),a
        pop af
        pop hl
        jp mark_cell
; base floor for a cell (shadow if wall above)
floor_of:
        cp 16
        jr c,.f
        push af
        sub 16
        call tile_get
        bit 7,a
        jr z,.nf
        pop af
        ld c,TL_SHADOW
        ret
.nf:    pop af
.f:     ld c,TL_FLOOR
        ret
; clear_tile: A = cell -> restore floor/shadow
clear_tile:
        push af
        call floor_of
        pop af
        jp tile_set

; neighbour: A = cell, B = dir -> A = new cell, carry set if off-map
neighbour:
        ld c,a
        ld a,b
        or a
        jr nz,.n1
        ld a,c
        sub 16
        ret                     ; carry if <0
.n1:    dec a
        jr nz,.n2
        ld a,c
        add a,16
        cp 176
        ccf
        ret
.n2:    dec a
        jr nz,.n3
        ld a,c
        and $0F
        scf
        ret z
        ld a,c
        dec a
        or a
        ret
.n3:    ld a,c
        and $0F
        cp 15
        scf
        ret z
        ld a,c
        inc a
        or a
        ret
; open_dir: A = cell, B = dir -> Z if passable (and A = new cell)
open_dir:
        call neighbour
        jr c,.no
        ld c,a
        call tile_get
        bit 7,a
        ld a,c
        ret                     ; Z if not wall
.no:    or 1
        ret
opposite:                       ; A = dir -> A = opposite
        xor 1
        ret

; =====================================================================
;  dirty cells
; =====================================================================
; mark_cell: A = cell (keeps all regs except flags). Appends to its row bucket.
mark_cell:
        push hl
        push af
        ld hl,tilemap
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        and $C0
        jr nz,.done             ; wall or already dirty
        set 6,(hl)
        pop af
        push af
        push de
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld e,a                  ; row
        ld d,0
        ld hl,dbn
        add hl,de
        ld a,(hl)
        cp 15
        jr nc,.full
        inc (hl)
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add a,l
        ld l,a
        ld de,dbk
        add hl,de
        pop de
        pop af
        ld (hl),a
        pop hl
        ret
.full:  pop de
.done:  pop af
        pop hl
        ret

; mark8: 8x5 sprite at B = x, C = y : mark the (up to 4) cells under it
mark8:
        ld a,c
        sub MAZEY
        ret c
        ld e,a
        ld d,0
        ld hl,div5
        add hl,de
        ld a,(hl)               ; row0
        inc hl
        inc hl
        inc hl
        inc hl
        ld d,(hl)               ; row1 (y+4)
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,b
        rrca
        rrca
        rrca
        and $0F
        add a,e
        call mark_cell
        ld e,a                  ; first cell
        ld a,b
        and 7
        jr z,.one
        ld a,e
        inc a
        call mark_cell
.one:   ld a,e
        and $F0
        ld h,a
        ld a,d
        add a,a
        add a,a
        add a,a
        add a,a
        cp h
        ret z                   ; same row
        ld h,a
        ld a,e
        and $0F
        or h
        call mark_cell
        ld e,a
        ld a,b
        and 7
        ret z
        ld a,e
        inc a
        jp mark_cell

; mark_rect: B = x, C = y, D = w, E = h (pixels) within maze
mark_rect:
        ld a,c
        sub MAZEY
        ret c
        ld hl,div5
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (tmp),a              ; row0
        ld a,c
        add a,e
        dec a
        sub MAZEY
        cp 55
        jr c,$+4
        ld a,54
        ld hl,div5
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (tmp+1),a            ; row1
        ld a,b
        rrca
        rrca
        rrca
        and $1F
        ld (tmp+2),a            ; col0
        ld a,b
        add a,d
        dec a
        rrca
        rrca
        rrca
        and $1F
        cp 16
        jr c,$+4
        ld a,15
        ld (tmp+3),a            ; col1
        ld a,(tmp)
.ry:    ld e,a
        ld a,(tmp+2)
.rx:    ld d,a
        ld a,e
        add a,a
        add a,a
        add a,a
        add a,a
        add a,d
        call mark_cell
        ld a,(tmp+3)
        cp d
        jr z,.nr
        ld a,d
        inc a
        jr .rx
.nr:    ld a,(tmp+1)
        cp e
        ret z
        ld a,e
        inc a
        jr .ry

; restore_row: A = row (0..10) : redraw that row's dirty cells, empty the bucket
restore_row:
        cp 11
        ret nc
        ld e,a
        ld d,0
        ld hl,dbn
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld b,a
        ld (hl),0
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,dbk
        add hl,de
        ex de,hl                ; DE = bucket
.lp:    push bc
        ld a,(de)
        inc de
        push de
        ld c,a
        call tile_ptr
        res 6,(hl)
        ld a,(hl)
        bit 7,a
        jr nz,.skip
        and $3F
        call draw_tile_c
.skip:  pop de
        pop bc
        djnz .lp
        ret
restore_all:
        xor a
.l:     push af
        call restore_row
        pop af
        inc a
        cp 11
        jr c,.l
        ret

; draw_tile_c: A = code, C = cell
draw_tile_c:
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl               ; *10
        ld de,tile_cache
        add hl,de
        ex de,hl
        ld a,c
        call cell_addr
        ld bc,31
        REPT 5
        ld a,(de)
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        ld (hl),a
        inc de
        add hl,bc
        ENDR
        ret

; =====================================================================
;  world / tiles
; =====================================================================
apply_world:                    ; A = world index
        ld (world),a
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de               ; *18
        ld de,world_tab
        add hl,de
        ld (wptr),hl
        ld a,(hl)
        or GFX
        call set_mode
        ld hl,(wptr)
        inc hl
        ld de,cmap
        ld bc,4
        ldir
        ld a,(hl)               ; flash colour
        call colpat
        ld (flashc),a
        call build_tables
        ret
; wget: A = offset -> A = byte of world entry
wget:
        ld hl,(wptr)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ret
wgetw:
        call wget
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; colourise 10 bytes: HL = src, DE = dst ; logical 0 -> cmap[0]
colourise:
        ld b,10
.b:     push bc
        ld a,(hl)
        inc hl
        push hl
        ld c,a
        ld b,4
        ld l,0
.p:     ld a,l
        add a,a
        add a,a
        ld l,a
        ld a,c
        rlca
        rlca
        ld c,a
        and 3
        push hl
        ld hl,cmap
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        or l
        ld l,a
        djnz .p
        ld a,l
        ld (de),a
        inc de
        pop hl
        pop bc
        djnz .b
        ret

build_tile_cache:
        ld de,tile_cache
        ld hl,tile_src
        ld b,32
.lp:    push bc
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,a
        ld l,c
        ld a,32
        sub b                   ; code
        call tile_override
        call colourise
        pop hl
        pop bc
        djnz .lp
        ret
; tile_override: A = code, HL = default src -> HL = src for this world
tile_override:
        or a
        jr nz,.n1
        ld a,12
        jp wgetw
.n1:    cp TL_SHADOW
        jr nz,.n2
        ld a,14
        jp wgetw
.n2:    cp TL_HAZ
        ret c
        cp TL_HOLE
        ret nc
        sub TL_HAZ              ; 0..2
        ld c,a
        ld a,(hz_look)
        ld b,a
        add a,a
        add a,b                 ; *3
        add a,c
        add a,a
        ld hl,hz_src
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; conveyor animation: rebuild conveyor tiles with frame conv_f
anim_conveyors:
        ld a,(nconv)
        or a
        ret z
        ld hl,conv_t
        dec (hl)
        ret p
        ld (hl),5
        ld a,(conv_f)
        xor 1
        ld (conv_f),a
        ld hl,conv_src0
        jr z,$+5
        ld hl,conv_src1
        ld de,tile_cache+TL_CONV*10
        ld b,4
.lp:    push bc
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,a
        ld l,c
        call colourise
        pop hl
        pop bc
        djnz .lp
        ld a,(nconv)
        ld b,a
        ld hl,convcells
.mk:    ld a,(hl)
        inc hl
        call mark_cell
        djnz .mk
        ret

; =====================================================================
;  maze build & draw
; =====================================================================
build_maze:
        ; HL = maze data: 22 bytes rows, start, spawn1, spawn2, objs..., $FF
        ld de,tilemap
        ld b,11
.row:   ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        ld h,a
        ld l,c
        push bc
        ld b,16
.bit:   add hl,hl
        ld a,TL_FLOOR
        jr nc,$+4
        ld a,TL_WALL
        ld (de),a
        inc de
        djnz .bit
        pop bc
        pop hl
        djnz .row
        ld a,(hl)
        ld (pstart),a
        inc hl
        ld a,(hl)
        ld (spawn1),a
        inc hl
        ld a,(hl)
        ld (spawn2),a
        inc hl
        xor a
        ld (nhaz),a
        ld (nconv),a
        ld (nholes),a
.obj:   ld a,(hl)
        cp $FF
        jr z,.shad
        inc hl
        ld c,a
        ld a,(hl)
        inc hl
        push hl
        push af
        call tile_ptr
        ld (hl),c
        pop af
        ld b,a                  ; cell
        ld a,c
        cp TL_HAZ
        jr nz,.o2
        ld hl,nhaz
        ld de,hazcells
        jr .add
.o2:    cp TL_HOLE
        jr nz,.o3
        ld hl,nholes
        ld de,holes
        jr .add
.o3:    ld hl,nconv
        ld de,convcells
.add:   ld a,(hl)
        inc (hl)
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        ld a,b
        ld (de),a
        pop hl
        jr .obj
.shad:  ; floor cells with wall above -> shadow
        ld hl,tilemap+16
        ld b,160
.sl:    ld a,(hl)
        or a
        jr nz,.sn
        push hl
        ld de,-16
        add hl,de
        bit 7,(hl)
        pop hl
        jr z,.sn
        ld (hl),TL_SHADOW
.sn:    inc hl
        djnz .sl
        ret

draw_maze:
        ld c,0
.lp:    push bc
        ld a,c
        call tile_ptr
        ld a,(hl)
        bit 7,a
        jr nz,.wall
        call draw_tile_c
        jr .nx
.wall:  ld a,c
        call draw_wall
.nx:    pop bc
        inc c
        ld a,c
        cp 176
        jr nz,.lp
        ret

; draw_wall: A = cell. base pattern + outline on edges facing floor
draw_wall:
        ld (tmp),a
        ld a,10
        call wgetw              ; wall src
        ld de,wallbuf
        call colourise
        ld a,6
        call wget               ; outline logical colour
        ld hl,cmap
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        call colpat
        ld (tmp+1),a            ; outline pattern
        ; up
        ld a,(tmp)
        ld b,0
        call wall_edge
        jr nz,.nu
        ld a,(tmp+1)
        ld (wallbuf),a
        ld (wallbuf+1),a
.nu:    ld a,(tmp)
        ld b,1
        call wall_edge
        jr nz,.nd
        ld a,(tmp+1)
        ld (wallbuf+8),a
        ld (wallbuf+9),a
.nd:    ld a,(tmp)
        ld b,2
        call wall_edge
        jr nz,.nl
        ld hl,wallbuf
        ld c,$C0
        call wall_col
.nl:    ld a,(tmp)
        ld b,3
        call wall_edge
        jr nz,.nr
        ld hl,wallbuf+1
        ld c,$03
        call wall_col
.nr:    ld a,(tmp)
        call cell_addr
        ld de,wallbuf
        ld bc,31
        REPT 5
        ld a,(de)
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        ld (hl),a
        inc de
        add hl,bc
        ENDR
        ret
; wall_edge: A = cell, B = dir -> Z if neighbour is floor (edge needed)
wall_edge:
        call neighbour
        jr c,.no
        call tile_get
        bit 7,a
        ret
.no:    or 1
        ret
; wall_col: HL = first byte, C = pixel mask; set that pixel column to outline in 5 rows
wall_col:
        ld b,5
.l:     ld a,(tmp+1)
        and c
        ld e,a
        ld a,c
        cpl
        and (hl)
        or e
        ld (hl),a
        inc hl
        inc hl
        djnz .l
        ret

; =====================================================================
;  HUD (y 0..7)
; =====================================================================
hud_colours:
        ld a,8
        call wget
        ld c,a                  ; fg
        ld a,7
        call wget               ; bg
        ld b,a
        ld a,c
        ld c,b
        jp set_txt

draw_hud_full:
        ld a,7
        call wget
        call colpat
        ld b,0
        ld c,0
        ld d,32
        ld e,8
        call fill_rect
        ; separator line y=7 in outline colour
        ld a,6
        call wget
        ld hl,cmap
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        call colpat
        ld hl,VRAM+7*32
        ld b,32
.sep:   ld (hl),a
        inc hl
        djnz .sep
        xor a
        ld (txt_mode),a
        ld a,$FF
        ld (hud_dirty),a
        ; fallthrough
draw_hud:
        ld a,(tick_t)
        or a
        ret nz
        ld a,(hud_dirty)
        or a
        ret z
        call hud_colours
        xor a
        ld (txt_mode),a
        ld a,(hud_dirty)
        bit 0,a
        jr z,.n0
        ld hl,score
        ld b,3
        ld de,VRAM+1*32+0
        call print_bcd
.n0:    ld a,(hud_dirty)
        bit 1,a
        jr z,.n1
        ld hl,VRAM+1*32+24
        ld a,G_MAN
        call draw_char
        inc hl
        ld a,(trainer)
        or a
        jr z,.lv
        ld a,G_T
        call draw_char
        jr .n1
.lv:    ld a,(lives)
        call print_dig
.n1:    ld a,(hud_dirty)
        bit 2,a
        jr z,.n2
        call hud_power
.n2:    ld a,(hud_dirty)
        bit 3,a
        jr z,.n3
        call hud_ammo
.n3:    ld a,(hud_dirty)
        bit 4,a
        jr z,.n4
        call hud_tomatoes
.n4:    ld a,(hud_dirty)
        bit 5,a
        jr z,.n5
        call hud_stage
.n5:    xor a
        ld (hud_dirty),a
        ret

hud_power:                      ; cols 7..10: multiplier / power icon
        ld hl,VRAM+1*32+7
        ld a,(pw_x2)
        or a
        ld a,G_SP
        jr z,.nx
        ld a,G_TIMES
.nx:    call draw_char
        inc hl
        ld a,(pw_x2)
        or a
        ld a,G_SP
        jr z,.n2
        ld a,G_0+2
.n2:    call draw_char
        ; letters collected S A U C E at cols 10..14
        ld hl,VRAM+1*32+10
        ld de,sauce_g
        ld a,(letters)
        ld (tmp+3),a
        ld b,5
.lt:    push bc
        ld a,(de)
        inc de
        ld c,a
        ld a,(tmp+3)
        rrca
        ld (tmp+3),a
        ld a,c
        jr c,.has
        ld a,G_DASH
.has:   push de
        call draw_char
        pop de
        inc hl
        pop bc
        djnz .lt
        ret
sauce_g: db G_S,G_A,G_U,G_C,G_E

hud_ammo:                       ; cols 16..18 "K" + ammo
        ld hl,VRAM+1*32+16
        ld a,(gun_ammo)
        or a
        jr nz,.has
        ld a,G_SP
        call draw_char
        inc hl
        ld a,G_SP
        jp draw_char
.has:   ld a,G_K
        call draw_char
        inc hl
        ld a,(gun_ammo)
        jp print_dig

hud_tomatoes:                   ; cols 20..22: tomato icon + count (or bonus timer)
        ld hl,VRAM+1*32+20
        ld a,G_HEART
        call draw_char
        inc hl
        ld a,(kind)
        cp 2
        ld a,(tleft)
        jr nz,.n
        ld a,(bonus_cnt)
.n:     ld b,a
        ld c,0
.t:     cp 10
        jr c,.d
        sub 10
        inc c
        jr .t
.d:     push af
        ld a,c
        add a,G_0
        call draw_char
        inc hl
        pop af
        add a,G_0
        jp draw_char

hud_stage:                      ; cols 28..30 "1-2", "1-B", "BON"
        ld hl,VRAM+1*32+28
        ld a,(kind)
        cp 2
        jr nz,.nb
        ld a,G_B
        call draw_char
        inc hl
        ld a,G_O
        call draw_char
        inc hl
        ld a,G_N
        jp draw_char
.nb:    ld a,(world)
        add a,G_0+1
        call draw_char
        inc hl
        ld a,G_DASH
        call draw_char
        inc hl
        ld a,(kind)
        or a
        ld a,G_B
        jr nz,.bs
        ld a,(stage_in_world)
        add a,G_0+1
.bs:    jp draw_char

; ticker: A = message index. Text is typed onto the HUD band a few chars per frame.
ticker:
        ld (tick_msg),a
        ld a,110
        ld (tick_t),a
        ld a,(tick_msg)
        add a,a
        ld hl,msg_tab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (tick_ptr),hl
        ; length -> start column
        ld b,0
.len:   ld a,(hl)
        inc hl
        cp $FF
        jr z,.ld
        inc b
        jr .len
.ld:    ld a,32
        sub b
        srl a
        ld (tick_col),a
        xor a
        ld (tick_clr),a         ; clear band first (8 bytes per frame)
        ret

tick_update:
        ld a,(tick_t)
        or a
        ret z
        dec a
        ld (tick_t),a
        jr z,.end
        ; phase 1: clear the band 8 columns per frame
        ld a,(tick_clr)
        cp 32
        jr nc,.type
        ld b,a
        add a,8
        ld (tick_clr),a
        call hud_colours
        ld a,(txt_bg)
        ld c,0
        ld d,8
        ld e,7
        jp fill_rect
.type:  ; phase 2: two characters per frame
        call hud_colours
        xor a
        ld (txt_mode),a
        ld b,2
.c:     push bc
        ld hl,(tick_ptr)
        ld a,(hl)
        cp $FF
        jr z,.cd
        inc hl
        ld (tick_ptr),hl
        push af
        ld a,(tick_col)
        ld b,a
        inc a
        ld (tick_col),a
        ld c,1
        call xyaddr_b
        pop af
        call draw_char
        pop bc
        djnz .c
        ld hl,sfx_type
        jp play_sfx_soft
.cd:    pop bc
        ret
.end:   ld a,$FF
        ld (hud_dirty),a
        jp draw_hud_full

; play_sfx_soft: only if nothing else is playing
play_sfx_soft:
        ld a,(sfx_timer)
        or a
        ret nz
        jp play_sfx

; =====================================================================
;  score
; =====================================================================
; add_score: DE = BCD value (D = high 2 digits, E = low 2 digits) * multiplier
add_score:
        ld a,(demo)
        or a
        ret nz
        ld b,1
        ld a,(pw_x2)
        or a
        jr z,.l
        inc b
.l:     push bc
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
        pop bc
        djnz .l
        ld hl,hud_dirty
        set 0,(hl)
        ; extra life every 20000 points
        ld a,(score)
        ld b,a
        and $0F
        ld c,a
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,a
        add a,c
        srl a
        ld hl,last_1up
        cp (hl)
        ret z
        ret c
        ld (hl),a
        jp extra_life

extra_life:
        ld a,(lives)
        cp 9
        jr nc,.n
        inc a
        ld (lives),a
.n:     ld hl,hud_dirty
        set 1,(hl)
        ld hl,sfx_1up
        jp play_sfx

; =====================================================================
;  particles
; =====================================================================
; spawn_burst: B = x, C = y, D = count, E = colour
spawn_burst:
        push ix
        call spawn_burst0
        pop ix
        ret
spawn_burst0:
        ld ix,parts
        ld a,NPART
.f:     push af
        ld a,(ix+6)
        or a
        jr nz,.used
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (ix+0),l
        ld (ix+1),h
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (ix+2),l
        ld (ix+3),h
        call rand
        and 31
        sub 16
        ld (ix+4),a
        call rand
        and 31
        sub 26
        ld (ix+5),a
        call rand
        and 15
        add a,12
        ld (ix+6),a
        ld (ix+7),e
        ld (ix+9),0
        dec d
        jr z,.done
.used:  push de
        ld de,PSIZE
        add ix,de
        pop de
        pop af
        dec a
        jr nz,.f
        ret
.done:  pop af
        ret

; restore particles (reverse order)
part_restore:
        ld hl,parts+(NPART-1)*PSIZE
        ld b,NPART
.l:     push hl
        push bc
        ld de,8
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or a
        jr z,.n
        ld a,(hl)
        ld (de),a
        dec hl
        ld (hl),0
.n:     pop bc
        pop hl
        ld de,-PSIZE
        add hl,de
        djnz .l
        ret

; move + draw particles
part_update:
        ld ix,parts
        ld b,NPART
.l:     push bc
        ld a,(ix+6)
        or a
        jr z,.n
        dec (ix+6)
        jr z,.n
        ; vy += 2 (gravity)
        ld a,(ix+5)
        add a,2
        jp m,.st
        cp 40
        jr c,.st
        ld a,40
.st:    ld (ix+5),a
        ; x16 += vx
        ld l,(ix+0)
        ld h,(ix+1)
        ld a,(ix+4)
        ld e,a
        rlca
        sbc a,a
        ld d,a
        add hl,de
        ld (ix+0),l
        ld (ix+1),h
        ; pixel x = hl >> 4
        call shr4
        cp 128
        jr nc,.kill
        ld b,a
        ld l,(ix+2)
        ld h,(ix+3)
        ld a,(ix+5)
        ld e,a
        rlca
        sbc a,a
        ld d,a
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        call shr4
        cp MAZEY
        jr c,.kill
        cp 64
        jr nc,.kill
        ld c,a
        ; save & plot
        push bc
        call xyaddr
        ld (ix+8),l
        ld (ix+9),h
        ld a,(hl)
        ld (ix+10),a
        pop bc
        ld a,(ix+7)
        call pset
        jr .n
.kill:  ld (ix+6),0
.n:     ld de,PSIZE
        add ix,de
        pop bc
        djnz .l
        ret
shr4:   ; HL >> 4 -> A
        ld a,l
        srl h
        rra
        srl h
        rra
        srl h
        rra
        srl h
        rra
        ret

; =====================================================================
;  popups (rising text with save-under)
; =====================================================================
; popup: HL = 4-char glyph string (pad with 0), B = x pixel, C = y pixel
popup:
        push ix
        call popup0
        pop ix
        ret
popup0:
        push hl
        ld ix,pops
        ld e,NPOP
.f:     ld a,(ix+2)
        or a
        jr z,.ok
        push de
        ld de,POPSZ
        add ix,de
        pop de
        dec e
        jr nz,.f
        pop hl
        ret
.ok:    pop hl
        ld a,b
        rrca
        rrca
        and $3F
        cp 28
        jr c,$+4
        ld a,28
        ld (ix+0),a
        ld a,c
        cp MAZEY+1
        jr nc,$+4
        ld a,MAZEY+1
        cp 58
        jr c,$+4
        ld a,58
        ld (ix+1),a
        ld (ix+2),40            ; life
        ld (ix+3),0             ; saved flag
        ld a,(hl)
        ld (ix+4),a
        inc hl
        ld a,(hl)
        ld (ix+5),a
        inc hl
        ld a,(hl)
        ld (ix+6),a
        inc hl
        ld a,(hl)
        ld (ix+7),a
        ret

pop_restore:
        ld ix,pops+(NPOP-1)*POPSZ
        ld b,NPOP
.l:     push bc
        ld a,(ix+3)
        or a
        jr z,.n
        ld (ix+3),0
        ld b,(ix+0)
        ld c,(ix+28)
        call xyaddr_b
        push ix
        pop de
        ld a,8
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        ld b,5
.r:     push bc
        push hl
        ex de,hl
        ld bc,4
        ldir
        ex de,hl
        pop hl
        ld bc,32
        add hl,bc
        pop bc
        djnz .r
.n:     ld de,-POPSZ
        add ix,de
        pop bc
        djnz .l
        ret

pop_update:
        ld ix,pops
        ld b,NPOP
.l:     push bc
        ld a,(ix+2)
        or a
        jr z,.n
        dec (ix+2)
        jr z,.n
        ld a,(ix+2)
        and 1
        jr nz,.nm
        ld a,(ix+1)
        cp MAZEY+2
        jr c,.nm
        dec (ix+1)
.nm:    ; save under
        ld b,(ix+0)
        ld c,(ix+1)
        ld (ix+28),c
        call xyaddr_b
        push hl
        push ix
        pop de
        ld a,8
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        ld b,5
.r:     push bc
        push hl
        ld bc,4
        ldir
        pop hl
        ld bc,32
        add hl,bc
        pop bc
        djnz .r
        ld (ix+3),1
        pop hl
        ; draw chars transparent, colour cycles
        ld a,1
        ld (txt_mode),a
        ld a,(ix+2)
        and 4
        ld a,(flashc)
        jr z,$+4
        ld a,$FF
        ld (txt_fg),a
        ld b,4
        push ix
        pop de
        inc de
        inc de
        inc de
        inc de
.c:     ld a,(de)
        inc de
        or a
        jr z,.cs
        push bc
        push de
        call draw_char
        pop de
        pop bc
.cs:    inc hl
        djnz .c
.n:     ld de,POPSZ
        add ix,de
        pop bc
        djnz .l
        xor a
        ld (txt_mode),a
        ret

; popup_pts: DE = BCD points (as shown), B = x, C = y : builds digit string
popup_pts:
        ld hl,tmp
        ld a,d
        rrca
        rrca
        rrca
        rrca
        and $0F
        jr z,.s1
        add a,G_0
        ld (hl),a
        inc hl
.s1:    ld a,d
        and $0F
        jr nz,.d1
        ld a,d
        or a
        jr z,.s2
        xor a
.d1:    add a,G_0
        ld (hl),a
        inc hl
.s2:    ld a,e
        rrca
        rrca
        rrca
        rrca
        and $0F
        add a,G_0
        ld (hl),a
        inc hl
        ld a,e
        and $0F
        add a,G_0
        ld (hl),a
        inc hl
        ld (hl),0
        ld hl,tmp
        jp popup
txt_snap: db G_S,G_N,G_A,G_P
txt_1up:  db G_0+1,G_U,G_P,0
txt_yum:  db G_Y,G_U,G_M,G_EXCL
txt_ouch: db G_B,G_O,G_N,G_K

; =====================================================================
;  entity rendering
; =====================================================================
; render_band: restore rows ahead of the beam and draw entities row by row
render_band:
        ; entity top rows -> counting sort into ord[]
        ld hl,rcnt
        ld b,11
.cz:    ld (hl),0
        inc hl
        djnz .cz
        ld ix,ents
        ld hl,erow
        ld b,NENTS
.e:     ld a,(ix+E_TYPE)
        or a
        ld a,$FF
        jr z,.es
        ld a,(ix+E_Y)
        sub MAZEY
        push hl
        ld e,a
        ld d,0
        ld hl,div5
        add hl,de
        ld e,(hl)
        ld hl,rcnt
        add hl,de
        inc (hl)
        ld a,e
        pop hl
.es:    ld (hl),a
        inc hl
        ld de,ESIZE
        add ix,de
        djnz .e
        ; prefix sums -> rpos
        ld hl,rcnt
        ld de,rpos
        ld b,11
        xor a
.ps:    ld (de),a
        add a,(hl)
        inc hl
        inc de
        djnz .ps
        ; place indices
        ld hl,erow
        ld c,0
.pl:    ld a,(hl)
        cp $FF
        jr z,.pn
        push hl
        ld e,a
        ld d,0
        ld hl,rpos
        add hl,de
        ld a,(hl)
        inc (hl)
        ld e,a
        ld hl,ord
        add hl,de
        ld (hl),c
        pop hl
.pn:    inc hl
        inc c
        ld a,c
        cp NENTS
        jr c,.pl
        ; render rows top to bottom
        ld hl,ord
        ld (ord_p),hl
        xor a
        call restore_row
        ld a,1
        call restore_row
        xor a
.row:   ld (cur_row),a
        add a,2
        call restore_row
        ld a,(cur_row)
        ld e,a
        ld d,0
        ld hl,rcnt
        add hl,de
        ld a,(hl)
        or a
        jr z,.rn
        ld b,a
.d:     push bc
        ld hl,(ord_p)
        ld a,(hl)
        inc hl
        ld (ord_p),hl
        rlca
        rlca
        rlca
        rlca
        ld e,a
        ld d,0
        ld ix,ents
        add ix,de
        call draw_ent
        pop bc
        djnz .d
.rn:    ld a,(cur_row)
        inc a
        cp 11
        jr c,.row
        ret

draw_ent:
        call ent_sprite         ; -> HL sprite, A = flags (bit0 flash, bit1 hide, bit2 big)
        bit 1,a
        ret nz
        ld (dflags),a
        bit 0,a
        jr z,.nf
        ld a,FLASHP
        call spr_page
.nf:    ld b,(ix+E_X)
        ld c,(ix+E_Y)
        push ix
        ld a,(dflags)
        bit 2,a
        jr nz,.big
        push bc
        call draw_spr
        pop bc
        call mark8
        jr .mk
.big:   push bc
        ld a,(bossrows)
        ld ixh,a
        ld a,(bossw)
        call draw_big
        pop bc
        ld a,(bossw)
        add a,a
        add a,a
        ld d,a
        ld a,(bossrows)
        ld e,a
        call mark_rect
.mk:    pop ix
        ld a,(dflags)
        bit 0,a
        ret z
        ld a,COLP
        jp spr_page

; =====================================================================
;  entity helpers (IX = entity)
; =====================================================================
ent_cell:                       ; -> A = cy*16+cx
        ld a,(ix+E_CY)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,(ix+E_CX)
        ret
ent_near:                       ; nearest cell -> A
        ld a,(ix+E_PROG)
        or a
        jr z,ent_cell
        add a,a
        ld c,a
        ld a,(ix+E_DIR)
        cp 2
        ld a,5
        jr c,$+4
        ld a,4
        cp c
        jr z,.next
        jr c,.next
        jr ent_cell
.next:  call ent_cell
        ld b,(ix+E_DIR)
        call neighbour
        ret
; set_cellpos: A = cell -> cx,cy,x,y, prog 0
ent_place:
        ld c,a
        and $0F
        ld (ix+E_CX),a
        add a,a
        add a,a
        add a,a
        ld (ix+E_X),a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld (ix+E_CY),a
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,MAZEY
        ld (ix+E_Y),a
        ld (ix+E_PROG),0
        ret
ent_reverse:
        call ent_cell
        ld b,(ix+E_DIR)
        call neighbour
        ld c,a
        and $0F
        ld (ix+E_CX),a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld (ix+E_CY),a
        ld a,(ix+E_DIR)
        cp 2
        ld a,5
        jr c,$+4
        ld a,4
        sub (ix+E_PROG)
        ld (ix+E_PROG),a
        ld a,(ix+E_DIR)
        xor 1
        ld (ix+E_DIR),a
        ret
; ent_advance: one step along E_DIR. carry set if arrived at new cell centre
ent_advance:
        inc (ix+E_PROG)
        ld a,(ix+E_DIR)
        cp 2
        jr nc,.h
        or a
        jr nz,.dn
        dec (ix+E_Y)
        jr .cv
.dn:    inc (ix+E_Y)
.cv:    ld a,(ix+E_PROG)
        cp 5
        jr .chk
.h:     cp 2
        jr nz,.rt
        dec (ix+E_X)
        dec (ix+E_X)
        jr .ch
.rt:    inc (ix+E_X)
        inc (ix+E_X)
.ch:    ld a,(ix+E_PROG)
        cp 4
.chk:   jr z,.arr
        or a
        ret
.arr:   call ent_cell
        ld b,(ix+E_DIR)
        call neighbour
        call ent_place
        ; teleport?
        call ent_cell
        call tile_get
        cp TL_HOLE
        jr nz,.nt
        ld a,(nholes)
        cp 2
        jr nz,.nt
        call ent_cell
        ld hl,holes
        cp (hl)
        jr nz,.h2
        inc hl
.h2:    ld a,(hl)
        call ent_place
        ld a,(ix+E_TYPE)
        cp T_PLAYER
        jr nz,.nt
        ld hl,sfx_tele
        call play_sfx
.nt:    scf
        ret
steps_of:                       ; A = dir -> A = steps per cell
        cp 2
        ld a,5
        ret c
        ld a,4
        ret

; pick_dir: A = input bits(0..3) -> A = dir or $FF (prefers turning)
pick_dir:
        and $0F
        ld c,a
        ld a,$FF
        ret z
        ld a,(ix+E_DIR)
        cp 2
        jr c,.vert
        ld b,0
        bit 0,c
        jr nz,.r
        inc b
        bit 1,c
        jr nz,.r
        inc b
        bit 2,c
        jr nz,.r
        inc b
        jr .r
.vert:  ld b,2
        bit 2,c
        jr nz,.r
        inc b
        bit 3,c
        jr nz,.r
        ld b,0
        bit 0,c
        jr nz,.r
        inc b
.r:     ld a,b
        ret

; =====================================================================
;  stage setup
; =====================================================================
STSZ    equ 13
setup_stage:
        ld a,(stage)
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; *3
        add hl,hl
        add hl,hl               ; *12
        add hl,de               ; *13
        ld de,stage_tab
        add hl,de
        ld (stage_ptr),hl
        ld a,(hl)               ; maze
        ld (tmp),a
        inc hl
        ld a,(hl)
        ld (world),a
        ld (hz_look),a
        inc hl
        ld a,(hl)
        ld (kind),a
        inc hl
        ld a,(hl)
        ld (hurry_t),a
        inc hl
        ld a,(hl)
        ld (pk_period),a
        inc hl
        ld a,(hl)
        ld (bossid),a
        inc hl
        ld a,(hl)
        ld (stage_in_world),a
        inc hl
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (wave_ptr),hl
        ld a,(kind)
        cp 2
        ld a,(world)
        jr nz,$+4
        ld a,3
        call apply_world
        ; maze
        ld a,(tmp)
        add a,a
        ld hl,maze_tab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call build_maze
        call build_tile_cache
        ; clear runtime tables
        ld hl,ents
        ld de,ents+1
        ld bc,NENTS*ESIZE+NPART*PSIZE+NPOP*POPSZ-1
        ld (hl),0
        ldir
        ld hl,dbn
        ld b,11
.cdb:   ld (hl),0
        inc hl
        djnz .cdb
        xor a
        ld (stime),a
        ld (stime+1),a
        ld (stime_sub),a
        ld (hurry),a
        ld (traps),a
        ld (pk_life),a
        ld (pw_sneak),a
        ld (pw_record),a
        ld (pw_x2),a
        ld (pw_disg),a
        ld (combo),a
        ld (combo_t),a
        ld (tick_t),a
        ld (dying),a
        ld (damaged),a
        ld (clear_t),a
        ld (letter_shown),a
        ld (gold_done),a
        ld (build_t),a
        ld (whack_t),a
        ld (haz_ph),a
        ld (quit),a
        ld (flash_scr),a
        ld a,150
        ld (haz_t),a
        ld a,80
        ld (news_t),a
        ld a,(pk_period)
        add a,a
        ld (pk_timer),a
        ; count tomatoes in waves
        ld hl,(wave_ptr)
        ld c,0
.cnt:   ld a,(hl)
        cp $FF
        jr z,.cd
        and $7F
        cp T_BOSS
        jr z,$+3
        inc c
        inc hl
        inc hl
        inc hl
        jr .cnt
.cd:    ld a,c
        ld (tleft),a
        ; draw
        ld a,(cmap)
        call colpat
        call cls
        call draw_maze
        call draw_hud_full
        ; player
        ld ix,ents
        ld (ix+E_TYPE),T_PLAYER
        ld a,(pstart)
        call ent_place
        ld (ix+E_DIR),$FF
        ld a,3
        ld (face),a
        ld a,75
        ld (invuln),a
        ld a,(kind)
        cp 2
        call z,bonus_setup
        cp 1
        call z,boss_setup
        ret

; =====================================================================
;  main stage loop -> result: 0 cleared, 1 game over, 2 quit
; =====================================================================
run_stage:
        call stage_intro
        call setup_stage
        ; music
        ld a,(kind)
        cp 1
        ld hl,mus_boss
        jr z,.m
        ld a,16
        call wgetw
.m:     ld de,0
        ld a,1
        call play_music
        ld a,(demo)
        or a
        ld a,M_DEMO
        call nz,ticker
.loop:  call frame_sync
        call draw_frame
        ld a,(demo)
        IFDEF AUTOPLAY
        or 1
        ENDIF
        or a
        jp z,.kb
        call bot_input
        IFDEF AUTOPLAY
        ld a,(demo)
        or a
        jr z,.nk
        ENDIF
        ld hl,(demo_timer)
        dec hl
        ld (demo_timer),hl
        ld a,h
        or l
        jr z,.dq
        call any_key
        jr z,.nk
        ld a,1
        ld (demo_key),a
.dq:    ld a,3
        ld (quit),a
        jr .nk
.kb:    call read_input
        ld a,(inp_new)
        bit I_PAUSE,a
        call nz,pause_menu
.nk:    call game_logic
        call sound_tick
        ld a,(quit)
        or a
        jr nz,.q
        ld a,(clear_t)
        or a
        jr z,.loop
        dec a
        ld (clear_t),a
        jr nz,.loop
        xor a
        ld (result),a
        ret
.q:     dec a
        ld (result),a           ; quit 1 -> 0? (quit=2 game over -> 1, 3 -> 2)
        ret

draw_frame:
        call pop_restore
        call part_restore
        call render_band
        call part_update
        call pop_update
        jp draw_hud

; =====================================================================
;  per-frame game logic
; =====================================================================
game_logic:
        ; screen flash (palette flip)
        ld a,(flash_scr)
        or a
        jr z,.nfl
        dec a
        ld (flash_scr),a
        ld b,a
        ld hl,(wptr)
        ld a,(hl)
        bit 0,b
        jr z,.f0
        xor CSS
.f0:    or GFX
        call set_mode
.nfl:   ; half-second tick
        ld hl,stime_sub
        inc (hl)
        ld a,(hl)
        cp 25
        jr c,.nh
        ld (hl),0
        call half_tick
.nh:    ld a,(invuln)
        or a
        jr z,$+6
        dec a
        ld (invuln),a
        ld a,(combo_t)
        or a
        jr z,$+6
        dec a
        ld (combo_t),a
        call tick_update
        call update_player
        call scan_armed
        call update_enemies
        call hazards
        call anim_conveyors
        call pickup_blink
        ; stage end check
        ld a,(clear_t)
        or a
        ret nz
        ld a,(dying)
        or a
        ret nz
        ld a,(tleft)
        or a
        ret nz
        ld a,(kind)
        cp 2
        ret z
        ld a,50
        ld (clear_t),a
        ret

half_tick:
        ld hl,(stime)
        inc hl
        ld (stime),hl
        ; power timers
        ld hl,pw_sneak
        call dec_nz
        ld hl,pw_disg
        call dec_nz
        ld hl,pw_x2
        ld a,(hl)
        call dec_nz
        or a
        jr z,.nx
        ld a,(hl)
        or a
        jr nz,.nx
        ld hl,hud_dirty
        set 2,(hl)
.nx:    ld hl,pw_record
        ld a,(hl)
        or a
        jr z,.nr
        dec (hl)
        jr nz,.nr
        ; record finished: back to normal music
        ld a,(kind)
        cp 1
        ld hl,mus_boss
        jr z,.rm
        ld a,16
        call wgetw
.rm:    ld de,0
        ld a,1
        call play_music
.nr:    ld a,(kind)
        cp 2
        jp z,bonus_tick
        call wave_tick
        call pickup_tick
        ; hurry
        ld a,(hurry)
        or a
        jr nz,.nhu
        ld a,(hurry_t)
        add a,a
        ld b,a
        ld a,(stime)
        cp b
        jr c,.nhu
        ld a,1
        ld (hurry),a
        ld a,M_HURRY
        call ticker
        ld hl,sfx_hurry
        call play_sfx
.nhu:   ; news flashes
        ld hl,news_t
        dec (hl)
        jr nz,.nn
        ld (hl),70
        ld a,(tick_t)
        or a
        jr nz,.nn
        ld a,4
        call rand_n
        add a,M_NEWS1
        call ticker
.nn:    ; golden tomato
        ld a,(kind)
        or a
        ret nz
        ld a,(gold_done)
        or a
        ret nz
        ld a,(stime)
        cp 50
        ret c
        ld a,1
        ld (gold_done),a
        call rand
        cp 120
        ret nc
        ld a,T_GOLD
        ld b,1
        call spawn_enemy
        ret c
        ld a,M_GOLDEN
        jp ticker

dec_nz: ld a,(hl)
        or a
        ret z
        dec (hl)
        ret

; waves: entries type, spawn idx, delay(half-secs)
wave_tick:
        ld hl,(wave_ptr)
        ld a,(hl)
        cp $FF
        ret z
        inc hl
        inc hl
        ld a,(stime)
        cp (hl)
        ret c
        dec hl
        dec hl
        ld a,(hl)
        inc hl
        ld b,(hl)
        inc hl
        inc hl
        push af
        ld (wave_ptr),hl
        pop af
        bit 7,a
        jr z,.n
        push af
        push bc
        ld a,M_GIANT
        call ticker
        ld hl,sfx_hurry
        call play_sfx
        pop bc
        pop af
        and $7F
        ld b,0                  ; random location
.n:     cp T_BOSS
        ret z
        call spawn_enemy
        ret nc
        ; no free slot: retry next tick
        ld hl,(wave_ptr)
        dec hl
        dec hl
        dec hl
        ld (wave_ptr),hl
        ret

; spawn_enemy: A = type, B = spawn index (1,2; 0 = random far cell). carry if no slot
spawn_enemy:
        ld c,a
        push bc
        call free_slot
        pop bc
        ret c
        ld (ix+E_TYPE),c
        ld a,b
        or a
        jr nz,.sp
        call far_cell
        jr .pl
.sp:    dec a
        ld a,(spawn1)
        jr z,.pl
        ld a,(spawn2)
.pl:    call ent_place
        ld (ix+E_STATE),S_SPAWN
        ld (ix+E_TIMER),30
        ld (ix+E_DIR),$FF
        ld a,(ix+E_TYPE)
        call type_info          ; HL -> info: speed, hp, pts(2)
        ld a,(hl)
        ld (ix+E_SPD),a
        inc hl
        ld a,(hl)
        ld (ix+E_HP),a
        ld (ix+E_AUX),0
        ld (ix+E_AUX2),0
        ld hl,sfx_spawn
        call play_sfx
        or a
        ret
; free_slot -> IX (slots 1..10), carry if none
free_slot:
        ld ix,ents+ESIZE
        ld b,10
.l:     ld a,(ix+E_TYPE)
        or a
        ret z
        ld de,ESIZE
        add ix,de
        djnz .l
        scf
        ret
; far_cell: random floor cell at least 5 away from player -> A
far_cell:
        ld b,40
.l:     push bc
        ld a,176
        call rand_n
        ld c,a
        call tile_get
        cp TL_FLOOR
        jr z,.ok
        cp TL_SHADOW
        jr nz,.no
.ok:    ld a,c
        call dist_player
        cp 6
        jr c,.no
        ld a,c
        pop bc
        ret
.no:    pop bc
        djnz .l
        ld a,(spawn1)
        ret
; dist_player: A = cell -> A = manhattan distance to player cell
dist_player:
        push bc
        ld c,a
        ld a,(ents+E_CX)
        ld b,a
        ld a,c
        and $0F
        sub b
        jr nc,$+4
        neg
        ld b,a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld c,a
        ld a,(ents+E_CY)
        sub c
        jr nc,$+4
        neg
        add a,b
        pop bc
        ret

; =====================================================================
;  player
; =====================================================================
PSPEED  equ $98
PSPEEDF equ $E0
update_player:
        ld ix,ents
        ld a,(dying)
        or a
        jp nz,pl_dying
        ld a,(inp_new)
        bit I_SHOOT,a
        call nz,try_shoot
        ld a,(inp)
        call pick_dir
        ld (want),a
        cp $FF
        jr z,.nf
        ld (face),a
.nf:    ld a,(inp)
        bit I_FIRE,a
        jr z,.nofire
        ld a,$FF
        ld (want),a
        ld a,(ix+E_PROG)
        or a
        jr nz,.move
        call do_action
        jr .move
.nofire: xor a
        ld (build_t),a
        ld (whack_t),a
.move:  ld ix,ents
        ld a,(pw_sneak)
        or a
        ld a,PSPEED
        jr z,$+4
        ld a,PSPEEDF
        call conv_adjust
        add a,(ix+E_ACC)
        ld (ix+E_ACC),a
        call c,pl_step
        jp pl_pickup

; conv_adjust: A = speed -> adjusted for conveyor under entity (IX)
conv_adjust:
        ld (tmp+2),a
        call ent_cell
        call tile_get
        sub TL_CONV
        cp 4
        ld a,(tmp+2)
        ret nc
        ; conveyor dir in A? recompute
        call ent_cell
        call tile_get
        sub TL_CONV
        ld b,a
        ld a,(ix+E_DIR)
        cp b
        jr nz,.ag
        ld a,(tmp+2)
        add a,$40
        ret nc
        ld a,$FF
        ret
.ag:    xor 1
        cp b
        ld a,(tmp+2)
        ret nz
        srl a
        ret

pl_step:
        ld a,(ix+E_PROG)
        or a
        jr nz,.mid
        ; on conveyor & no input -> carried
        ld a,(want)
        cp $FF
        jr nz,.w
        call ent_cell
        call tile_get
        sub TL_CONV
        cp 4
        jr nc,.stop
        ld (want),a
.w:     ld a,(want)
        ld b,a
        call ent_cell
        call open_dir
        jr nz,.cur
        ld a,(want)
        ld (ix+E_DIR),a
        jr .go
.cur:   ld a,(ix+E_DIR)
        cp $FF
        jr z,.stop
        ld b,a
        call ent_cell
        call open_dir
        jr nz,.stop
        jr .go
.stop:  ld (ix+E_DIR),$FF
        ret
.mid:   ld a,(want)
        cp $FF
        jr z,.go
        ld b,a
        ld a,(ix+E_DIR)
        xor 1
        cp b
        call z,ent_reverse
.go:    call ent_advance
        ret nc
        ; arrived: hazards checked in hazards()
        ret

pl_dying:
        dec a
        ld (dying),a
        cp 60
        jr nz,.n1
        ld b,(ix+E_X)
        ld c,(ix+E_Y)
        ld d,10
        ld e,3
        push ix
        call spawn_burst
        pop ix
.n1:    ld a,(dying)
        or a
        ret nz
        ; life lost
        ld a,(trainer)
        ld b,a
        ld a,(demo)
        or b
        jr nz,.keep
        ld a,(lives)
        dec a
        ld (lives),a
        ld hl,hud_dirty
        set 1,(hl)
        jr nz,.keep
        ld a,2
        ld (quit),a             ; -> result 1 game over
        ret
.keep:  ld a,(pstart)
        call ent_place
        ld (ix+E_DIR),$FF
        ld a,100
        ld (invuln),a
        xor a
        ld (pw_disg),a
        ret

kill_player:
        ld a,(dying)
        or a
        ret nz
        ld a,(invuln)
        or a
        ret nz
        ld a,(pw_disg)
        or a
        ret nz
        ld a,(shield)
        or a
        jr z,.die
        xor a
        ld (shield),a
        ld a,60
        ld (invuln),a
        ld a,M_SHIELD
        call ticker
        ld hl,sfx_bonk
        jp play_sfx
.die:   ld a,90
        ld (dying),a
        ld a,1
        ld (damaged),a
        ld a,4
        ld (flash_scr),a
        ld hl,sfx_die
        jp play_sfx

; ---- action button: whack or build ----
do_action:
        ld ix,ents
        call ent_cell
        ld a,(face)
        ld b,a
        call ent_cell
        call neighbour
        ret c
        ld (target_cell),a
        call find_whackable
        jr nc,.build
        ld a,(whack_t)
        or a
        jr z,.w
        dec a
        ld (whack_t),a
        ret
.w:     ld a,10
        ld (whack_t),a
        jp whack_ent            ; IY = entity
.build: ld a,(target_cell)
        call tile_get
        cp TL_SHADOW
        jr z,.new
        cp TL_TRAP1
        jr c,.new
        cp TL_TRAP3
        jr c,.cont
        ret nz
        ; reclaim an armed, empty trap (new press only)
        ld a,(inp_new)
        bit I_FIRE,a
        ret z
        ld a,(target_cell)
        call clear_tile
        ld hl,traps
        dec (hl)
        ld hl,sfx_trample
        jp play_sfx
.new:   ld a,(target_cell)
        call ent_on_cell
        ret c
        ld a,(traps)
        cp MAXTRAPS
        jr c,.cont
        ld a,(inp_new)
        bit I_FIRE,a
        ret z
        ld hl,sfx_deny
        call play_sfx
        ld a,M_NOTRAP
        jp ticker
.cont:  ld hl,build_t
        inc (hl)
        ld a,(hl)
        cp 9
        ret c
        ld (hl),0
        ld a,(target_cell)
        call tile_get
        cp TL_TRAP1
        jr nc,.up
        ld hl,traps
        inc (hl)
        ld a,TL_TRAP1-1
.up:    inc a
        ld c,a
        ld a,(target_cell)
        call tile_set
        ld a,c
        cp TL_TRAP3
        ld hl,sfx_build
        jr nz,.s
        ld hl,sfx_armed
        ; sparkle
        ld a,(target_cell)
        call cell_px
        ld d,4
        ld e,1
        call spawn_burst
        ld hl,sfx_armed
.s:     jp play_sfx

; cell_px: A = cell -> B = x+3, C = y+2 (centre)
cell_px:
        ld c,a
        and $0F
        add a,a
        add a,a
        add a,a
        add a,3
        ld b,a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld c,a
        add a,a
        add a,a
        add a,c
        add a,MAZEY+2
        ld c,a
        ret

; ent_on_cell: A = cell -> carry if any enemy's nearest cell == A
ent_on_cell:
        ld (tmp+3),a
        push ix
        ld ix,ents+ESIZE
        ld b,10
.l:     push bc
        ld a,(ix+E_TYPE)
        or a
        jr z,.n
        cp T_SHOT
        jr z,.n
        call ent_near
        ld b,a
        ld a,(tmp+3)
        cp b
        jr nz,.n
        pop bc
        pop ix
        scf
        ret
.n:     ld de,ESIZE
        add ix,de
        pop bc
        djnz .l
        pop ix
        or a
        ret

; find_whackable: target_cell -> IY = entity, carry if found
find_whackable:
        ld ix,ents+ESIZE
        ld b,10
.l:     push bc
        ld a,(ix+E_TYPE)
        or a
        jr z,.n
        cp T_BOSS
        jr z,.boss
        cp T_SHOT
        jr nc,.n
        ld a,(ix+E_STATE)
        cp S_CAUGHT
        jr z,.c
        cp S_STUN
        jr nz,.n
.c:     call ent_near
        ld b,a
        ld a,(target_cell)
        cp b
        jr nz,.n
.yes:   pop bc
        push ix
        pop iy
        ld ix,ents
        scf
        ret
.boss:  call boss_vulnerable
        jr nc,.n
        ld a,(target_cell)
        call boss_covers
        jr c,.yes
.n:     ld de,ESIZE
        add ix,de
        pop bc
        djnz .l
        ld ix,ents
        or a
        ret

; whack_ent: IY = entity
whack_ent:
        push iy
        pop ix
        ld (ix+E_FLASH),6
        ld de,$0010
        call add_score
        ld a,(target_cell)
        call cell_px
        ld d,3
        ld e,1
        call spawn_burst
        push iy
        pop ix
        ld b,(ix+E_X)
        ld c,(ix+E_Y)
        ld hl,txt_ouch
        call popup
        ld a,(ix+E_TYPE)
        cp T_BOSS
        jp z,boss_hit
        ld hl,sfx_bonk
        call play_sfx
        dec (ix+E_HP)
        jr z,.sq
        ; struggling tomato gets a little more time scared
        ld a,(ix+E_TIMER)
        add a,10
        jr nc,$+4
        ld a,250
        ld (ix+E_TIMER),a
        ld ix,ents
        ret
.sq:    call squash_ent
        ld ix,ents
        ret

try_shoot:
        ld a,(gun_ammo)
        or a
        ret z
        ld a,(ents+11*ESIZE+E_TYPE)
        or a
        ret nz
        ld a,(gun_ammo)
        dec a
        ld (gun_ammo),a
        ld hl,hud_dirty
        set 3,(hl)
        ld ix,ents
        call ent_near
        ld ix,ents+11*ESIZE
        call ent_place
        ld (ix+E_TYPE),T_SHOT
        ld a,(face)
        ld (ix+E_DIR),a
        ld (ix+E_STATE),S_WALK
        ld (ix+E_SPD),$FF
        ld (ix+E_TIMER),60
        ld ix,ents
        ld hl,sfx_shot
        jp play_sfx

pl_pickup:
        ld a,(pk_life)
        or a
        ret z
        ld a,(dying)
        or a
        ret nz
        ld ix,ents
        call ent_near
        ld b,a
        ld a,(pk_cell)
        cp b
        ret nz
        xor a
        ld (pk_life),a
        ld a,(pk_cell)
        call clear_tile
        ld hl,sfx_pickup
        call play_sfx
        ld de,$0050
        call add_score
        ld a,(pk_code)
        cp TL_LET
        jr nc,.let
        sub TL_GUN
        add a,a
        ld hl,.pk_jump
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
.pk_jump: dw pk_gun,pk_sneak,pk_record,pk_x2,pk_coland,pk_disg,pk_can
.let:   sub TL_LET
        ld b,a
        inc b
        ld a,0
        scf
.lb:    rla
        djnz .lb
        ld hl,letters
        or (hl)
        ld (hl),a
        ld hl,hud_dirty
        set 2,(hl)
        cp 31
        ld a,M_LETTER
        jp nz,ticker
        xor a
        ld (letters),a
        ld de,$5000
        call add_score
        call extra_life
        ld a,M_SAUCE
        jp ticker
pk_gun: ld a,(gun_lvl)
        cp 3
        jr nc,$+6
        inc a
        ld (gun_lvl),a
        ld a,(gun_ammo)
        add a,6
        cp 10
        jr c,$+4
        ld a,9
        ld (gun_ammo),a
        ld hl,hud_dirty
        set 3,(hl)
        ld a,(gun_lvl)
        add a,M_GUN-1
        jp ticker
pk_sneak: ld a,24
        ld (pw_sneak),a
        ld a,M_SNEAK
        jp ticker
pk_record:
        ld a,18
        ld (pw_record),a
        ld hl,mus_love
        ld de,0
        ld a,1
        call play_music
        ld a,(bossid)
        cp 3
        call z,boss_daze
        ld a,M_RECORD
        jp ticker
pk_x2:  ld a,30
        ld (pw_x2),a
        ld hl,hud_dirty
        set 2,(hl)
        ld a,M_X2
        jp ticker
pk_coland: ld a,1
        ld (shield),a
        ld a,M_COLAND
        jp ticker
pk_disg: ld a,16
        ld (pw_disg),a
        ld a,M_DISG
        jp ticker
pk_can: call extra_life
        ld hl,txt_1up
        ld a,(pk_cell)
        call cell_px
        call popup
        ld a,M_CAN
        jp ticker

; ---- pickups spawning ----
pickup_tick:
        ld a,(pk_period)
        or a
        ret z
        ld a,(pk_life)
        or a
        jr z,.none
        dec a
        ld (pk_life),a
        ret nz
        ld a,(pk_cell)
        jp clear_tile
.none:  ld hl,pk_timer
        dec (hl)
        ret nz
        ld a,(pk_period)
        add a,a
        ld (hl),a
        ; choose code
        ld a,(kind)
        or a
        jr nz,.tab
        ld a,(letter_shown)
        or a
        jr nz,.tab
        ld a,(stime)
        cp 24
        jr c,.tab
        ld a,1
        ld (letter_shown),a
        ; first missing letter
        ld a,(letters)
        ld c,TL_LET
.fl:    rrca
        jr nc,.got
        inc c
        jr .fl
.tab:   ld a,(hurry)            ; enraged and no ketchup? guarantee a gun
        or a
        jr z,.tb2
        ld a,(gun_ammo)
        or a
        ld c,TL_GUN
        jr z,.got
.tb2:   ld a,(bossid)
        cp 3
        ld hl,pk_tab_boss
        ld a,8
        jr z,.r
        ld hl,pk_tab
        ld a,14
.r:     call rand_n
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld c,(hl)
.got:   ld a,c
        ld (pk_code),a
        call far_cell2
        ld (pk_cell),a
        ld a,c
        ld a,(pk_code)
        ld c,a
        ld a,(pk_cell)
        call tile_set
        ld a,20
        ld (pk_life),a
        ret
pk_tab: db TL_GUN,TL_GUN,TL_GUN,TL_SNEAK,TL_SNEAK,TL_RECORD,TL_RECORD,TL_X2,TL_X2,TL_COLAND,TL_COLAND,TL_DISG,TL_CAN,TL_GUN
pk_tab_boss: db TL_RECORD,TL_RECORD,TL_RECORD,TL_RECORD,TL_GUN,TL_GUN,TL_CAN,TL_COLAND
far_cell2:
        push bc
        call far_cell
        pop bc
        ret

pickup_blink:
        ld a,(pk_life)
        or a
        ret z
        cp 6
        ret nc
        ld a,(frame_cnt)
        and 7
        ret nz
        ld a,(frame_cnt)
        and 8
        ld a,(pk_cell)
        jr z,.on
        jp clear_tile
.on:    ld c,a
        ld a,(pk_code)
        ld b,a
        ld a,c
        ld c,b
        jp tile_set

; =====================================================================
;  hazards (grills / vents / zappers)
; =====================================================================
hazards:
        ld a,(nhaz)
        or a
        ret z
        ld hl,haz_t
        dec (hl)
        jr nz,.chk
        ld a,(haz_ph)
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (haz_ph),a
        ld hl,haz_len
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (haz_t),a
        ld a,(haz_ph)
        cp 2
        jr nz,.ns
        ld hl,sfx_grill
        call play_sfx
.ns:    ld a,(nhaz)
        ld b,a
        ld hl,hazcells
.st:    push bc
        push hl
        ld a,(haz_ph)
        add a,TL_HAZ
        ld c,a
        ld a,(hl)
        call tile_set
        pop hl
        inc hl
        pop bc
        djnz .st
.chk:   ld a,(haz_ph)
        cp 2
        ret nz
        ; anything standing on an active hazard?
        ld ix,ents
        ld b,11
.e:     push bc
        ld a,(ix+E_TYPE)
        or a
        jr z,.en
        cp T_SHOT
        jr nc,.en
        call ent_near
        call tile_get
        cp TL_HAZ+2
        jr nz,.en
        ld a,(ix+E_TYPE)
        cp T_PLAYER
        jr nz,.tom
        call kill_player
        jr .en
.tom:   ld a,(ix+E_STATE)
        cp S_SQUASH
        jr nc,.en
        call squash_ent
        ld de,$0500
        call add_score
        ld b,(ix+E_X)
        ld c,(ix+E_Y)
        ld hl,txt_yum
        call popup
.en:    ld de,ESIZE
        add ix,de
        pop bc
        djnz .e
        ret
haz_len: db 150,45,50

; =====================================================================
;  pause
; =====================================================================
pause_menu:
        ld a,1
        ld (paused),a
        ld b,6
        ld c,22
        ld d,20
        ld e,32
        call draw_box
        call hud_colours
        ld hl,s_paused
        ld b,8
        ld c,25
        call draw_str
.w:     call sound_tick_quiet
        call frame_sync
        call read_input
        ld a,($68BF)            ; RETURN
        bit 2,a
        jr nz,.nr
        ld a,(inp_new)
        bit I_PAUSE,a
        jr nz,.out
.nr:    ld a,($68FE)            ; R key (row0 bit5)
        bit 5,a
        jr nz,.w
        ld a,3
        ld (quit),a
.out:   xor a
        ld (paused),a
        ; redraw everything
        ld hl,parts
        ld de,parts+1
        ld bc,NPART*PSIZE+NPOP*POPSZ-1
        ld (hl),0
        ldir
        call draw_maze
        call draw_hud_full
        xor a
        ld (inp_new),a
        ret
sound_tick_quiet:
        xor a
        ld (snd_period),a
        ret

; draw_box: B = xbyte, C = y, D = w bytes, E = h ; filled with hud bg, framed with outline
draw_box:
        push bc
        push de
        ld a,6
        call wget
        ld hl,cmap
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        call colpat
        call fill_rect
        pop de
        pop bc
        inc c
        dec e
        dec e
        inc b
        dec d
        dec d
        ld a,7
        push bc
        push de
        call wget
        call colpat
        pop de
        pop bc
        jp fill_rect

; =====================================================================
;  bonus round
; =====================================================================
bonus_setup:
        ld a,15
        ld (bonus_cnt),a
        ld b,10
.l:     push bc
        ld a,T_CHERRY
        ld b,0
        call spawn_enemy
        jr c,.n
        ld (ix+E_STATE),S_WALK
        ld (ix+E_AUX2),1        ; sleeping
.n:     pop bc
        djnz .l
        ld a,10
        ld (tleft),a
        ld a,(kind)
        ret
bonus_tick:
        ld a,(stime)
        and 1
        ret nz
        ld hl,bonus_cnt
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ld hl,hud_dirty
        set 4,(hl)
        ld a,(bonus_cnt)
        or a
        jr z,.end
        ld a,(tleft)
        or a
        ret nz
        ld de,$5000
        call add_score
        ld hl,txt_yum
        ld bc,$3820
        call popup
.end:   ld a,M_BONUSEND
        call ticker
        ld a,60
        ld (clear_t),a
        xor a
        ld (bonus_cnt),a
        ret
