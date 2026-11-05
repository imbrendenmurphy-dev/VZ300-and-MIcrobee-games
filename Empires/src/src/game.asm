; ===================================================================
;  game.asm - game state, tools, simulation, UI, overview, main loop
; ===================================================================

MAXBLD  equ 220
BREC    equ 4                   ; type, x, y, progress

; ---------------- tables ----------------
bld_g:  db 0, 0, G_TC_TL_L, G_TC_TR_L, G_TC_BL_L, G_TC_BR_L
        db G_HUT_L, G_HOUSE_L, G_MANOR_L, G_FARM_L, G_WOOD_L, G_QUARRY_L
        db G_WELL_L, G_MARKET_L, G_WINDMILL_L, G_TOWER_L
; build time (weeks) per object
bld_time: db 0,1,0,0,0,0, 2,3,4,3,3,4, 2,5,5,4
; workers needed per object
bld_jobs: db 0,0,0,0,0,0, 0,0,0,2,2,2, 0,2,1,1
; housing per object
bld_house: db 0,0,6,0,0,0, 4,8,14,0,0,0, 0,0,0,0
; reveal radius per object (on completion)
bld_view: db 0,0,7,0,0,0, 3,3,3,3,3,3, 3,4,3,9
; territory radius
bld_terr: db 0,0,7,0,0,0, 4,4,5,4,4,4, 4,5,4,9

tool_obj: db O_ROAD,O_HUT,O_FARM,O_WOOD,O_QUARRY,O_WELL,O_MARKET,O_MILL,O_TOWER,0
; cost: wood, stone, gold
tool_cost:
        db 0,1,1        ; road
        db 6,0,0        ; hut
        db 8,0,5        ; farm
        db 6,2,0        ; woodcutter
        db 8,0,4        ; quarry
        db 2,5,0        ; well
        db 12,8,20      ; market
        db 15,6,10      ; windmill
        db 6,12,8       ; tower
        db 0,0,1        ; clear
tool_icon:
        dw G_TI_ROAD_L,G_TI_HUT_L,G_TI_FARM_L,G_TI_WOOD_L,G_TI_QUARRY_L
        dw G_TI_WELL_L,G_TI_MARKET_L,G_TI_MILL_L,G_TI_TOWER_L,G_TI_CLEAR_L
tool_name:
        dw tn0,tn1,tn2,tn3,tn4,tn5,tn6,tn7,tn8,tn9
tn0:    db "ROAD      ",0
tn1:    db "HUT       ",0
tn2:    db "FARM      ",0
tn3:    db "WOODCUTTER",0
tn4:    db "QUARRY    ",0
tn5:    db "WELL      ",0
tn6:    db "MARKET    ",0
tn7:    db "WINDMILL  ",0
tn8:    db "WATCHTOWER",0
tn9:    db "CLEAR LAND",0
obj_name:
        dw on0,on1,on2,on2,on2,on2,on6,on7,on8,tn2,tn3,tn4,tn5,tn6,tn7,tn8
on0:    db "",0
on1:    db "ROAD",0
on2:    db "TOWN HALL",0
on6:    db "HUT",0
on7:    db "HOUSE",0
on8:    db "MANOR",0
tool_hint:
        dw th0,th1,th2,th3,th4,th5,th6,th7,th8,th9
th0:    db "ROADS LINK; BRIDGE RIVERS",0
th1:    db "HOMES 4; GROWS INTO HOUSE",0
th2:    db "PLOUGHS GRASS INTO FIELDS",0
th3:    db "TIMBER FROM NEARBY FOREST",0
th4:    db "STONE FROM HILLS AND ROCK",0
th5:    db "WATER: HAPPIER, HOMES GROW",0
th6:    db "TRADE GOLD; MANORS NEED IT",0
th7:    db "+FOOD EXCEPT IN WINTER",0
th8:    db "SEES FAR, WIDENS LANDS",0
th9:    db "FELL, DRAIN, DEMOLISH",0
season_name:
        dw sn0,sn1,sn2,sn3
sn0:    db "SPRING",0
sn1:    db "SUMMER",0
sn2:    db "AUTUMN",0
sn3:    db "WINTER",0
speed_frames: db 0,90,45,16

; ---------------- new game ----------------
new_game:
        ; resources
        ld hl,45
        ld (food),hl
        ld hl,40
        ld (wood),hl
        ld hl,16
        ld (stone),hl
        ld hl,60
        ld (gold),hl
        ld hl,6
        ld (pop),hl
        ld a,55
        ld (happy),a
        xor a
        ld (season),a
        ld (week),a
        ld (nbld),a
        ld (tool),a
        ld (msgtimer),a
        ld (tickc),a
        ld (overview),a
        ld hl,1
        ld (year),hl
        ld a,2
        ld (speed),a
        ; town centre at start
        ld bc,(startxy)
        ld a,O_TC_TL
        call set_obj
        inc c
        ld a,O_TC_TR
        call set_obj
        inc b
        ld a,O_TC_BR
        call set_obj
        dec c
        ld a,O_TC_BL
        call set_obj
        dec b
        ld a,O_TC_TL
        call add_record
        ld a,7
        call reveal
        inc b
        inc c
        ld a,7
        call reveal
        ld bc,(startxy)
        ld a,c
        ld (curx),a
        ld a,b
        ld (cury),a
        call centre_view
        ld hl,msg_welcome
        ld a,C_MSG
        jp set_msg

; set_obj: B=y C=x A=obj
set_obj:
        push hl
        push de
        call tile_addr
        ld de,OBJOFF
        add hl,de
        ld (hl),a
        pop de
        pop hl
        ret

; add_record: A=type (B,C pos) progress 0
add_record:
        push hl
        push de
        ld e,a
        ld a,(nbld)
        cp MAXBLD
        jr nc,.full
        push af
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld a,e
        ld de,blist
        add hl,de
        ld (hl),a
        inc hl
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld (hl),0
        pop af
        inc a
        ld (nbld),a
.full:  pop de
        pop hl
        ret

; centre the view on the cursor
centre_view:
        ld a,(curx)
        sub VIEWW/2
        jr nc,.x1
        xor a
.x1:    call clampvx
        ld (viewx),a
        ld a,(cury)
        sub VIEWH/2
        jr nc,.y1
        xor a
.y1:    call clampvy
        ld (viewy),a
        ret

; ---------------- fog of war ----------------
; reveal: B=y C=x A=radius ; marks EXPLORED, triggers ruins discovery
reveal: push bc
        ld (rv_r),a
        ld a,b
        ld (rv_y),a
        ld a,c
        ld (rv_x),a
        ld a,(rv_r)
        ld e,a
        call sq_a               ; HL = r*r
        ld de,0
        ld a,(rv_r)
        ld e,a
        add hl,de               ; r*r + r
        ld (rv_r2),hl
        ld a,(rv_r)
        neg
        ld (rv_dy),a
.y:     ld a,(rv_r)
        neg
        ld (rv_dx),a
.x:     ; dist check
        ld a,(rv_dx)
        call abs_a
        call sq_a
        push hl
        ld a,(rv_dy)
        call abs_a
        call sq_a
        pop de
        add hl,de
        ld de,(rv_r2)
        or a
        sbc hl,de
        jr z,.in
        jr nc,.skip
.in:    ld a,(rv_y)
        ld e,a
        ld a,(rv_dy)
        add a,e
        call cph
        jr nc,.skip
        ld b,a
        ld a,(rv_x)
        ld e,a
        ld a,(rv_dx)
        add a,e
        call cpw
        jr nc,.skip
        ld c,a
        call tile_addr
        ld a,(hl)
        bit 7,a
        jr nz,.skip
        or EXPLORED
        ld (hl),a
        and 1Fh
        cp T_RUINS
        jr nz,.skip
        ; ruins discovered!
        ld hl,(gold)
        ld de,25
        add hl,de
        ld (gold),hl
        ld hl,msg_ruins
        ld a,C_GOOD
        call set_msg
        ld a,1
        ld (want_jingle),a
.skip:  ld a,(rv_dx)
        inc a
        ld (rv_dx),a
        ld e,a
        ld a,(rv_r)
        cp e
        jp p,.x
        ld a,(rv_dy)
        inc a
        ld (rv_dy),a
        ld e,a
        ld a,(rv_r)
        cp e
        jp p,.y
        pop bc
        ret

abs_a:  bit 7,a
        ret z
        neg
        ret
sq_a:   push de                 ; HL = A*A
        push bc
        ld h,a
        ld e,a
        call mul8
        pop bc
        pop de
        ret

; ---------------- messages ----------------
set_msg:                        ; HL = text, A = colour
        ld (msgptr),hl
        ld (msgcol),a
        ld a,200
        ld (msgtimer),a
        ld a,1
        ld (dirty_msg),a
        ret

draw_msg:
        ld b,MSGROW
        ld c,1
        ld a,C_TEXT
        call shadow_clear_rows
        ld a,(msgtimer)
        or a
        jr z,.hint
        ld hl,(msgptr)
        ld a,(msgcol)
        ld b,MSGROW
        ld c,1
        call puts_at
        jr .p
.hint:  ld hl,msg_hint
        ld a,C_DIM
        ld b,MSGROW
        ld c,1
        call puts_at
.p:     ld b,MSGROW
        ld c,1
        jp present_rows

; ---------------- status bar (row 0) ----------------
draw_status:
        ld b,0
        ld c,1
        ld a,C_STATUS
        call shadow_clear_rows
        ld de,0
        ld hl,G_RI_CAL
        ld a,C_STATUS
        call put_g
        inc de
        inc de
        ld a,(season)
        add a,a
        ld l,a
        ld h,0
        ld bc,season_name
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,C_STATNUM
        call puts
        ld hl,txt_yr
        ld a,C_STATUS
        call puts
        ld a,C_STATNUM
        ld (txtcol),a
        ld hl,(year)
        call putnum
        ; population
        ld de,17
        ld hl,G_RI_POP
        ld a,COL(BCYAN,BLUE)
        call put_g
        inc de
        inc de
        ld a,C_STATNUM
        ld (txtcol),a
        ld hl,(pop)
        call putnum
        ld a,'/'
        ld hl,txtcol
        ld (hl),C_STATUS
        call putch
        call capacity
        call putnum
        ; food
        ld de,29
        ld hl,G_RI_FOOD
        ld a,COL(BYELLOW,BLUE)
        call put_g
        inc de
        inc de
        ld a,C_STATNUM
        ld (txtcol),a
        ld hl,(food)
        call putnum
        ; wood
        ld de,38
        ld hl,G_RI_WOOD
        ld a,COL(BYELLOW,BLUE)
        call put_g
        inc de
        inc de
        ld a,C_STATNUM
        ld (txtcol),a
        ld hl,(wood)
        call putnum
        ; stone
        ld de,47
        ld hl,G_RI_STONE
        ld a,COL(WHITE,BLUE)
        call put_g
        inc de
        inc de
        ld a,C_STATNUM
        ld (txtcol),a
        ld hl,(stone)
        call putnum
        ; gold
        ld de,56
        ld hl,G_RI_GOLD
        ld a,COL(BYELLOW,BLUE)
        call put_g
        inc de
        inc de
        ld a,C_STATNUM
        ld (txtcol),a
        ld hl,(gold)
        call putnum
        ; happiness
        ld de,66
        ld hl,G_RI_HAPPY
        ld a,(happy)
        cp 40
        jr nc,.hp
        ld hl,G_RI_SAD
.hp:    ld a,COL(BGREEN,BLUE)
        call put_g
        inc de
        inc de
        ld a,C_STATNUM
        ld (txtcol),a
        ld a,(happy)
        ld l,a
        ld h,0
        call putnum
        ld a,'%'
        call putch
        ; speed
        ld de,78
        ld a,(speed)
        ld hl,G_RI_PAUSE
        or a
        jr z,.sp
        ld hl,G_RI_PLAY
        cp 3
        jr nz,.sp
        ld hl,G_RI_FAST
.sp:    ld a,COL(BGREEN,BLUE)
        call put_g
        ld b,0
        ld c,1
        jp present_rows

; total housing capacity -> HL
capacity:
        push bc
        push de
        ld hl,0
        ld a,(nbld)
        or a
        jr z,.e
        ld b,a
        ld ix,blist
.l:     ld a,(ix+0)
        bit 7,a
        jr nz,.n
        ld e,a
        ld d,0
        push hl
        ld hl,bld_house
        add hl,de
        ld e,(hl)
        pop hl
        add hl,de
.n:     ld de,BREC
        add ix,de
        djnz .l
.e:     pop de
        pop bc
        ret

; ---------------- toolbar + info ----------------
draw_toolbar:
        ld b,TOOLROW
        ld c,2
        ld a,C_PANEL
        call shadow_clear_rows
        ld b,0
.t:     push bc
        ; offset TOOLROW*80 + i*3
        ld a,b
        add a,a
        add a,b
        ld c,a
        ld b,TOOLROW
        call cell_off
        pop bc
        push bc
        ld a,b
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,tool_icon
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                ; HL = G
        pop de
        call put_gc
        inc hl
        inc de
        call put_gc
        ; highlight selected
        pop bc
        push bc
        ld a,(tool)
        cp b
        jr nz,.nh
        dec de
        call .swap
        inc de
        call .swap
.nh:    pop bc
        inc b
        ld a,b
        cp NTOOLS
        jr nz,.t
        ; number labels on info row are drawn by draw_info; tool name + cost
        ld b,TOOLROW
        ld c,31
        call cell_off
        ld a,(tool)
        add a,a
        ld l,a
        ld h,0
        ld bc,tool_name
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,C_PANELHI
        call puts
        inc de
        ; costs
        ld a,(tool)
        ld l,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        ld bc,tool_cost
        add hl,bc
        push hl
        ld a,(hl)
        or a
        jr z,.nw
        ld hl,G_RI_WOOD
        ld a,COL(BYELLOW,BLUE)
        call put_g
        inc de
        pop hl
        push hl
        ld a,C_PANEL
        ld (txtcol),a
        ld l,(hl)
        ld h,0
        call putnum
        inc de
.nw:    pop hl
        inc hl
        push hl
        ld a,(hl)
        or a
        jr z,.ns
        ld hl,G_RI_STONE
        ld a,COL(WHITE,BLUE)
        call put_g
        inc de
        pop hl
        push hl
        ld a,C_PANEL
        ld (txtcol),a
        ld l,(hl)
        ld h,0
        call putnum
        inc de
.ns:    pop hl
        inc hl
        ld a,(hl)
        or a
        jr z,.ng
        push hl
        ld hl,G_RI_GOLD
        ld a,COL(BYELLOW,BLUE)
        call put_g
        inc de
        pop hl
        ld a,C_PANEL
        ld (txtcol),a
        ld l,(hl)
        ld h,0
        call putnum
.ng:    ; hint text on second toolbar line
        ld a,(tool)
        add a,a
        ld l,a
        ld h,0
        ld bc,tool_hint
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,TOOLROW
        ld c,54
        ld a,COL(BCYAN,BLUE)
        call puts_at
        ld b,TOOLROW
        ld c,1
        jp present_rows
.swap:  push hl
        ld hl,SCOL
        add hl,de
        ld a,(hl)
        call swapnib
        ld (hl),a
        pop hl
        ret

draw_info:
        ld b,INFOROW
        ld c,1
        ld a,C_PANEL
        call shadow_clear_rows
        ; key numbers under the icons
        ld de,INFOROW*COLS
        ld a,COL(GREY,BLUE)
        ld (txtcol),a
        ld b,0
.k:     ld a,b
        inc a
        cp 10
        jr nz,.k1
        xor a
.k1:    add a,'0'
        call putch
        inc de
        inc de
        inc b
        ld a,b
        cp NTOOLS
        jr nz,.k
        ; tile info at col 31
        ld b,INFOROW
        ld c,31
        call cell_off
        ld bc,(cursor_bc)
        call tile_addr
        ld a,(hl)
        bit 7,a
        jr nz,.known
        ld hl,txt_unexplored
        ld a,COL(GREY,BLUE)
        call puts
        jr .xy
.known: and 1Fh
        ; terrain name
        call terr_name
        ld a,C_PANEL
        call puts
        ld bc,(cursor_bc)
        call oget
        or a
        jr z,.xy
        push af
        ld a,' '
        call putch
        pop af
        push af
        and 7Fh
        add a,a
        ld l,a
        ld h,0
        ld bc,obj_name
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,C_PANELHI
        call puts
        pop af
        bit 7,a
        jr z,.xy
        ld hl,txt_building
        ld a,COL(BYELLOW,BLUE)
        call puts
.xy:    ld b,INFOROW
        ld c,1
        jp present_rows

terr_name:                      ; A = terrain id -> HL = name
        ld hl,terr_names
        or a
        ret z
        ld b,a
.l:     ld a,(hl)
        inc hl
        or a
        jr nz,.l
        djnz .l
        ret

; ---------------- placement ----------------
; check_place: tool in (tool), B,C -> Z ok ; NZ with HL = error message
check_place:
        call tile_addr
        ld a,(hl)
        bit 7,a
        jr nz,.expl
        ld hl,err_fog
        or 1
        ret
.expl:  and 1Fh
        ld (ptr),a
        ; territory
        call in_territory
        ld hl,err_terr
        ret nz
        ld a,(tool)
        cp 9
        jp z,.clear
        ; must be empty
        call oget
        or a
        ld hl,err_occ
        ret nz
        ld a,(tool)
        or a
        jr nz,.notroad
        ld a,(ptr)
        cp T_MOUNT
        jr z,.badt
        cp T_SNOW
        jr z,.badt
        cp T_DEEP
        jr z,.badt
        jr .cost
.notroad:
        ld a,(ptr)
        cp 3
        jr c,.badt              ; water
        cp T_FOREST
        jr z,.forest
        cp T_DENSE
        jr z,.forest
        cp T_MOUNT
        jr z,.badt
        cp T_SNOW
        jr z,.badt
        cp T_MARSH
        jr z,.badt
        cp T_RUINS
        jr z,.badt
        ld a,(tool)
        cp 2                    ; farm: grass or meadow only
        jr nz,.nf
        ld a,(ptr)
        cp T_GRASS
        jr z,.cost
        cp T_MEADOW
        jr z,.cost
        ld hl,err_farm
        or 1
        ret
.nf:    cp 3                    ; woodcutter: forest within 2
        jr nz,.nq
        ld a,T_FOREST
        ld (cnt_t1),a
        ld a,T_DENSE
        ld (cnt_t2),a
        call count2
        or a
        ld hl,err_wood
        jr z,.fail
        jr .cost
.nq:    cp 4                    ; quarry: hills/rock/mountain within 2
        jr nz,.cost
        ld a,T_HILLS
        ld (cnt_t1),a
        ld a,T_ROCK
        ld (cnt_t2),a
        call count2
        push af
        ld a,T_MOUNT
        ld (cnt_t1),a
        ld (cnt_t2),a
        call count2
        pop de
        add a,d
        ld hl,err_quarry
        jr z,.fail
        jr .cost
.forest:
        ld hl,err_forest
.fail:  or 1
        ret
.badt:  ld hl,err_terrain
        or 1
        ret
.clear: call oget
        and 7Fh
        cp O_TC_TL
        jr c,.cl1
        cp O_HUT
        ld hl,err_tc
        jr c,.fail
        jr .cost
.cl1:   or a
        jr nz,.cost             ; road
        ld a,(ptr)
        cp T_FOREST
        jr z,.cost
        cp T_DENSE
        jr z,.cost
        cp T_MARSH
        jr z,.cost
        cp T_ROCK
        jr z,.cost
        ld hl,err_nothing
        jr .fail
.cost:  ; affordable?
        call tool_costp         ; HL -> cost triple
        ld e,(hl)
        ld d,0
        push hl
        ld hl,(wood)
        or a
        sbc hl,de
        pop hl
        jr c,.poor
        inc hl
        ld e,(hl)
        push hl
        ld hl,(stone)
        or a
        sbc hl,de
        pop hl
        jr c,.poor
        inc hl
        ld e,(hl)
        ld hl,(gold)
        or a
        sbc hl,de
        jr c,.poor
        xor a
        ret
.poor:  ld hl,err_poor
        or 1
        ret

tool_costp:
        ld a,(tool)
        ld l,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        push de
        ld de,tool_cost
        add hl,de
        pop de
        ret

pay_cost:
        call tool_costp
        ld e,(hl)
        ld d,0
        push hl
        ld hl,(wood)
        or a
        sbc hl,de
        ld (wood),hl
        pop hl
        inc hl
        ld e,(hl)
        push hl
        ld hl,(stone)
        or a
        sbc hl,de
        ld (stone),hl
        pop hl
        inc hl
        ld e,(hl)
        ld hl,(gold)
        or a
        sbc hl,de
        ld (gold),hl
        ret

; count tiles of type cnt_t1/cnt_t2 within +-2 of B,C -> A
count2: push bc
        xor a
        ld (gcnt),a
        dec b
        dec b
        ld e,5
.y:     push bc
        dec c
        dec c
        ld d,5
.x:     call tget
        push hl
        ld hl,cnt_t1
        cp (hl)
        inc hl
        jr z,.c
        cp (hl)
        jr nz,.s
.c:     ld a,(gcnt)
        inc a
        ld (gcnt),a
.s:     pop hl
        inc c
        dec d
        jr nz,.x
        pop bc
        inc b
        dec e
        jr nz,.y
        pop bc
        ld a,(gcnt)
        ret

; in_territory: B,C -> Z if within reach of a completed building
in_territory:
        push bc
        ld a,(nbld)
        or a
        jr z,.no
        ld d,a
        ld ix,blist
.l:     ld a,(ix+0)
        bit 7,a
        jr nz,.n
        ld e,a
        push hl
        push de
        ld d,0
        ld hl,bld_terr
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ld e,a                  ; radius
        ld a,c
        sub (ix+1)
        call abs_a
        cp e
        jr z,.cy
        jr nc,.n
.cy:    ld a,b
        sub (ix+2)
        call abs_a
        cp e
        jr z,.yes
        jr c,.yes
.n:     push de
        ld de,BREC
        add ix,de
        pop de
        dec d
        jr nz,.l
.no:    pop bc
        or 1
        ret
.yes:   pop bc
        xor a
        ret

; do_place: apply tool at cursor (assumes check passed)
do_place:
        ld bc,(cursor_bc)
        call pay_cost
        ld a,(tool)
        cp 9
        jp z,.clear
        ld e,a
        ld d,0
        ld hl,tool_obj
        add hl,de
        ld a,(hl)
        cp O_ROAD
        jr nz,.bld
        call set_obj
        call refresh_around
        call sfx_click
        ret
.bld:   push af
        or BUILDING
        call set_obj
        pop af
        or BUILDING
        call add_record
        call refresh_tile
        call sfx_build
        ld hl,msg_started
        ld a,C_MSG
        jp set_msg
.clear: call oget
        or a
        jr z,.terr
        ; demolish (remove record if building)
        and 7Fh
        cp O_ROAD
        jr z,.rd
        call remove_record
.rd:    xor a
        call set_obj
        call refresh_around
        call sfx_click
        ret
.terr:  call tile_addr
        ld a,(hl)
        and 1Fh
        cp T_FOREST
        jr z,.fell
        cp T_DENSE
        jr nz,.drain
        ld a,(hl)
        and 0E0h
        or T_FOREST             ; dense thins to forest
        ld (hl),a
        jr .wood
.fell:  ld a,(hl)
        and 0E0h
        or T_GRASS
        ld (hl),a
.wood:  ld hl,(wood)
        ld de,3
        add hl,de
        ld (wood),hl
        jr .rt
.drain: ld a,(hl)
        and 0E0h
        or T_GRASS              ; marsh/rocks become grass
        ld (hl),a
.rt:    call refresh_around
        jp sfx_click

; refresh tile B,C and its 4 neighbours (connections)
refresh_around:
        push bc
        call refresh_tile
        pop bc
        push bc
        dec b
        call refresh_tile
        pop bc
        push bc
        inc b
        call refresh_tile
        pop bc
        push bc
        dec c
        call refresh_tile
        pop bc
        push bc
        inc c
        call refresh_tile
        pop bc
        ret

; remove building record at B,C
remove_record:
        push bc
        ld a,(nbld)
        or a
        jr z,.e
        ld d,a
        ld ix,blist
.l:     ld a,(ix+1)
        cp c
        jr nz,.n
        ld a,(ix+2)
        cp b
        jr nz,.n
        ; move last record here
        ld a,(nbld)
        dec a
        ld (nbld),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,blist
        add hl,de
        push ix
        pop de
        ld bc,4
        ldir
        jr .e
.n:     push de
        ld de,BREC
        add ix,de
        pop de
        dec d
        jr nz,.l
.e:     pop bc
        ret

; ---------------- simulation tick (one week) ----------------
sim_tick:
        ; ---- calendar
        ld a,(week)
        inc a
        cp 13
        jr c,.wk
        xor a
        ld (week),a
        ld a,(season)
        inc a
        and 3
        ld (season),a
        jr nz,.ns
        ld hl,(year)
        inc hl
        ld (year),hl
.ns:    ld a,1
        ld (dirty_view),a
        ld (want_season),a
        jr .wk2
.wk:    ld (week),a
.wk2:   ; ---- buildings: construction, production
        ld hl,(pop)
        ld (workers),hl
        xor a
        ld (nwell),a
        ld (nmarket),a
        ld (ntower),a
        ld hl,0
        ld (dfood),hl
        ld (dwood),hl
        ld (dstone),hl
        ld (dgold),hl
        ld a,(nbld)
        or a
        jp z,.people
        ld (loopn),a
        ld ix,blist
.bl:    ld a,(ix+0)
        bit 7,a
        jr z,.done
        ; under construction: needs 1 worker
        ld hl,(workers)
        ld a,h
        or l
        jp z,.next
        dec hl
        ld (workers),hl
        inc (ix+3)
        ld a,(ix+0)
        and 7Fh
        ld e,a
        ld d,0
        ld hl,bld_time
        add hl,de
        ld a,(ix+3)
        cp (hl)
        jp c,.next
        ; completed
        ld a,(ix+0)
        and 7Fh
        ld (ix+0),a
        ld (ix+3),0
        call complete_building
        jp .next
.done:  ; completed building: jobs
        ld e,a
        ld d,0
        ld hl,bld_jobs
        add hl,de
        ld a,(hl)
        or a
        jr z,.work
        ld e,a
        ld hl,(workers)
        or a
        sbc hl,de
        jp c,.next              ; not enough workers -> idle
        ld (workers),hl
.work:  ld a,(ix+0)
        cp O_FARM
        jr nz,.w1
        ; food = 1 + fields * season factor
        ld a,(season)
        ld e,a
        ld d,0
        ld hl,farm_factor
        add hl,de
        ld e,(hl)
        ld a,(ix+3)             ; fields count stored in progress byte
        ld b,a
        ld hl,(dfood)
        inc hl
        or a
        jr z,.f2
.f1:    add hl,de
        djnz .f1
.f2:    ld (dfood),hl
        jp .next
.w1:    cp O_WOOD
        jr nz,.w2
        ld a,(ix+3)
        srl a
        srl a
        inc a
        ld e,a
        ld d,0
        ld hl,(dwood)
        add hl,de
        ld (dwood),hl
        jr .next
.w2:    cp O_QUARRY
        jr nz,.w3
        ld a,(ix+3)
        srl a
        srl a
        inc a
        ld e,a
        ld d,0
        ld hl,(dstone)
        add hl,de
        ld (dstone),hl
        jr .next
.w3:    cp O_MARKET
        jr nz,.w4
        ld hl,nmarket
        inc (hl)
        ld hl,(dgold)
        ld de,4
        add hl,de
        ld (dgold),hl
        jr .next
.w4:    cp O_WELL
        jr nz,.w5
        ld hl,nwell
        inc (hl)
        jr .next
.w5:    cp O_TOWER
        jr nz,.w6
        ld hl,ntower
        inc (hl)
        jr .next
.w6:    cp O_MILL
        jr nz,.next
        ld a,(season)
        cp 3
        jr z,.next
        ld hl,(dfood)
        ld de,5
        add hl,de
        ld (dfood),hl
.next:  ld de,BREC
        add ix,de
        ld a,(loopn)
        dec a
        ld (loopn),a
        jp nz,.bl
.people:
        ; town hall foraging
        ld hl,(dfood)
        ld de,3
        add hl,de
        ld (dfood),hl
        ; tax
        ld hl,(pop)
        ld c,8
        call div_hl_c
        ld de,(dgold)
        add hl,de
        ld (dgold),hl
        ; apply production
        ld hl,(food)
        ld de,(dfood)
        add hl,de
        ld (food),hl
        ld hl,(wood)
        ld de,(dwood)
        add hl,de
        ld (wood),hl
        ld hl,(stone)
        ld de,(dstone)
        add hl,de
        ld (stone),hl
        ld hl,(gold)
        ld de,(dgold)
        add hl,de
        ld (gold),hl
        ; consumption = pop/3 + 1
        ld hl,(pop)
        ld c,3
        call div_hl_c
        inc hl
        ex de,hl
        ld hl,(food)
        or a
        sbc hl,de
        jr nc,.fed
        ; starvation
        ld hl,0
        ld (food),hl
        ld hl,(pop)
        ld c,12
        call div_hl_c
        inc hl
        ex de,hl
        ld hl,(pop)
        or a
        sbc hl,de
        jr nc,.p0
        ld hl,0
.p0:    ld a,h                  ; never fall below 3: the town hall's founders stay
        or a
        jr nz,.p1
        ld a,l
        cp 3
        jr nc,.p1
        ld hl,3
.p1:    ld (pop),hl
        ld a,(happy)
        sub 6
        jr nc,.h0
        xor a
.h0:    ld (happy),a
        ld hl,msg_starve
        ld a,C_WARN
        call set_msg
        ld a,1
        ld (want_warn),a
        jr .happy
.fed:   ld (food),hl
        ; growth
        call capacity
        ld de,(pop)
        or a
        sbc hl,de               ; HL = cap - pop
        jr c,.happy
        jr z,.happy
        ld a,(happy)
        cp 35
        jr c,.happy
        push hl
        ld c,6
        call div_hl_c
        inc hl
        ex de,hl                ; DE = growth
        pop hl                  ; HL = room
        or a
        sbc hl,de
        jr nc,.g
        add hl,de
        ex de,hl                ; growth = room
.g:     ld hl,(pop)
        add hl,de
        ld (pop),hl
.happy: ; happiness target
        ld a,50
        ld b,a
        ld a,(nwell)
        cp 4
        jr c,.h1
        ld a,4
.h1:    ld c,a
        add a,a
        add a,c
        add a,a                 ; *6
        add a,b
        ld b,a
        ld a,(nmarket)
        cp 4
        jr c,.h2
        ld a,4
.h2:    ld c,a
        add a,a
        add a,a
        add a,c                 ; *5
        add a,b
        ld b,a
        ld a,(ntower)
        cp 3
        jr c,.h3
        ld a,3
.h3:    add a,a
        add a,b
        ld b,a
        ; food surplus bonus
        ld hl,(food)
        ld de,(pop)
        or a
        sbc hl,de
        jr c,.h4
        ld a,b
        add a,8
        ld b,a
.h4:    ld a,(season)
        cp 3
        jr nz,.h5
        ld a,b
        sub 8
        ld b,a
.h5:    ; crowded?
        call capacity
        ld de,(pop)
        or a
        sbc hl,de
        jr nz,.h6
        ld a,b
        sub 6
        ld b,a
.h6:    ld a,b
        cp 101
        jr c,.h7
        ld a,100
        ld b,a
.h7:    ; move happy 1/4 of the way to target
        ld a,(happy)
        ld c,a
        ld a,b
        sub c                   ; target - happy (signed)
        sra a
        sra a
        jr nz,.h8
        ld a,b
        cp c
        jr z,.h9
        ld a,1
        jr nc,.h8
        ld a,-1
.h8:    add a,c
        ld (happy),a
.h9:    call evolve_houses
        call random_event
        ld a,1
        ld (dirty_status),a
        ret

farm_factor: db 1,2,3,0

div_hl_c:                       ; HL = HL / C
        push de
        push bc
        ld de,0
        ld b,0
.l:     or a
        sbc hl,bc
        jr c,.e
        inc de
        jr .l
.e:     ex de,hl
        pop bc
        pop de
        ret

; complete_building: IX -> record (type now final).  B,C from record.
complete_building:
        ld c,(ix+1)
        ld b,(ix+2)
        ld a,(ix+0)
        call set_obj
        ; reveal around
        ld e,a
        ld d,0
        ld hl,bld_view
        add hl,de
        ld a,(hl)
        or a
        jr z,.nr
        push bc
        call reveal
        pop bc
        ld a,1
        ld (dirty_view),a
.nr:    ld a,(ix+0)
        cp O_FARM
        jr nz,.nf
        call plough_fields      ; returns count in A
        ld (ix+3),a
        jr .msg
.nf:    cp O_WOOD
        jr nz,.nw
        ld a,T_FOREST
        ld (cnt_t1),a
        ld a,T_DENSE
        ld (cnt_t2),a
        call count2
        ld (ix+3),a
        jr .msg
.nw:    cp O_QUARRY
        jr nz,.msg
        ld a,T_HILLS
        ld (cnt_t1),a
        ld a,T_ROCK
        ld (cnt_t2),a
        call count2
        push af
        ld a,T_MOUNT
        ld (cnt_t1),a
        ld (cnt_t2),a
        call count2
        pop de
        add a,d
        ld (ix+3),a
.msg:   call refresh_tile
        ld hl,msg_complete
        ld a,C_GOOD
        call set_msg
        ld a,1
        ld (want_done),a
        ret

; convert orthogonal + diagonal grass neighbours to fields (max 6) -> A count
plough_fields:
        push bc
        xor a
        ld (gcnt),a
        ld hl,field_dirs
        ld e,8
.l:     push bc
        ld a,(hl)
        add a,b
        ld b,a
        inc hl
        ld a,(hl)
        add a,c
        ld c,a
        inc hl
        push hl
        push de
        call tget
        cp T_GRASS
        jr z,.ok
        cp T_MEADOW
        jr nz,.s
.ok:    call oget
        or a
        jr nz,.s
        ld a,(gcnt)
        cp 6
        jr nc,.s
        inc a
        ld (gcnt),a
        call tile_addr
        ld a,(hl)
        and 0E0h
        or T_FIELD
        ld (hl),a
        call refresh_tile
.s:     pop de
        pop hl
        pop bc
        dec e
        jr nz,.l
        pop bc
        ld a,(gcnt)
        ret
field_dirs: db 0,-1, 0,1, -1,0, 1,0, -1,-1, -1,1, 1,-1, 1,1

; houses grow: pick a random record each tick
evolve_houses:
        ld a,(nbld)
        or a
        ret z
        ld b,a
        call rand_n
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,blist
        add hl,de
        push hl
        pop ix
        ld a,(ix+0)
        cp O_HUT
        jr z,.hut
        cp O_HOUSE
        ret nz
        ; house -> manor: happy>=68, market within 6, pop >= 40
        ld a,(happy)
        cp 68
        ret c
        ld hl,(pop)
        ld de,40
        or a
        sbc hl,de
        ret c
        ld a,O_MARKET
        ld e,6
        call near_obj
        ret nz
        ld a,O_MANOR
        jr .up
.hut:   ld a,(happy)
        cp 52
        ret c
        ; needs road adjacent
        ld c,(ix+1)
        ld b,(ix+2)
        ld a,1
        ld (nbmode),a
        call neighbours
        ld a,(nb_n)
        ld hl,nb_s
        or (hl)
        ld hl,nb_w
        or (hl)
        ld hl,nb_e
        or (hl)
        ret z
        ld a,O_WELL
        ld e,5
        call near_obj
        ret nz
        ld a,O_HOUSE
.up:    ld (ix+0),a
        ld c,(ix+1)
        ld b,(ix+2)
        call set_obj
        call refresh_tile
        ld hl,msg_grow
        ld a,C_GOOD
        call set_msg
        ld a,1
        ld (want_grow),a
        ret

; near_obj: A = object type, E = radius, IX = record (centre) -> Z if found
near_obj:
        ld (nobj),a
        ld a,e
        ld (nrad),a
        ld a,(nbld)
        ld b,a
        ld iy,blist
.l:     ld a,(iy+0)
        ld hl,nobj
        cp (hl)
        jr nz,.n
        ld a,(iy+1)
        sub (ix+1)
        call abs_a
        ld hl,nrad
        cp (hl)
        jr z,.c
        jr nc,.n
.c:     ld a,(iy+2)
        sub (ix+2)
        call abs_a
        cp (hl)
        jr z,.y
        jr c,.y
.n:     ld de,BREC
        add iy,de
        djnz .l
        or 1
        ret
.y:     xor a
        ret

random_event:
        call rand
        and 31
        ret nz
        call rand
        and 7
        cp 5
        ret nc
        add a,a
        ld l,a
        ld h,0
        ld de,ev_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
ev_tab: dw ev_trade,ev_harvest,ev_migrant,ev_storm,ev_wolves
ev_trade:
        ld hl,(gold)
        ld de,30
        add hl,de
        ld (gold),hl
        ld hl,msg_ev_trade
        ld a,C_GOOD
        jp set_msg
ev_harvest:
        ld a,(season)
        cp 3
        ret z
        ld hl,(food)
        ld de,40
        add hl,de
        ld (food),hl
        ld hl,msg_ev_harvest
        ld a,C_GOOD
        jp set_msg
ev_migrant:
        call capacity
        ld de,(pop)
        or a
        sbc hl,de
        ld de,5
        or a
        sbc hl,de
        ret c
        ld hl,(pop)
        add hl,de
        ld (pop),hl
        ld hl,msg_ev_migrant
        ld a,C_GOOD
        jp set_msg
ev_storm:
        ld hl,(wood)
        ld de,10
        or a
        sbc hl,de
        ret c
        ld (wood),hl
        ld hl,msg_ev_storm
        ld a,C_WARN
        jp set_msg
ev_wolves:
        ld hl,(food)
        ld de,8
        or a
        sbc hl,de
        ret c
        ld (food),hl
        ld hl,msg_ev_wolves
        ld a,C_WARN
        jp set_msg

; ---------------- animation (PCG redefinition) ----------------
animate:
        ld a,BLK_ART            ; frames live in the art block
        call with_block
        ld a,(animf)
        inc a
        ld (animf),a
        ; water: 4 frames
        and 3
        ld (af4),a
        ld hl,anim_water
        ld b,ANIM_WATER_N
.w:     push bc
        ld a,(hl)               ; G
        inc hl
        push hl
        ld (ag),a
        ; colour frame
        ld a,(af4)
        call .frameptr          ; HL += frame*11
        ld c,0
        call .write
        pop hl
        push hl
        ld de,44
        add hl,de
        ld a,(af4)
        call .frameptr
        ld c,8
        call .write
        pop hl
        ld de,88
        add hl,de
        pop bc
        djnz .w
        ; others
        ld hl,anim_other
        ld b,ANIM_OTHER_N
.o:     push bc
        ld a,(hl)
        ld (ag),a
        inc hl
        ld a,(hl)               ; nframes
        ld (anf),a
        inc hl
        push hl
        ; frame = (animf>>1) mod nframes
        ld a,(animf)
        srl a
        ld c,a
        ld a,(anf)
        ld b,a
        ld a,c
.md:    sub b
        jr nc,.md
        add a,b
        ld (afr),a
        call .frameptr
        ld c,0
        call .write
        pop hl
        push hl
        ; mono frames start at nframes*11
        ld a,(anf)
        call .frameptr
        ld a,(afr)
        call .frameptr
        ld c,8
        call .write
        pop hl
        ; skip 2*nframes*11
        ld a,(anf)
        add a,a
        call .frameptr
        pop bc
        djnz .o
        ld a,EXT_ON
        out (P_EXT),a
        jp map_home
.frameptr:                      ; HL += A*11
        or a
        ret z
        push de
        ld de,11
.fp:    add hl,de
        dec a
        jr nz,.fp
        pop de
        ret
.write: ; HL = 11 bytes, C = bank base; writes glyph (ag)
        ld a,(ag)
        rlca
        and 1
        add a,c
        or EXT_ON
        out (P_EXT),a
        ld a,(ag)
        and 7Fh
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        or high(HIRAM)
        ld h,a
        ex de,hl
        ld bc,11
        ldir
        ret

; ---------------- world overview ----------------
OVCOL   equ 12
ov_class:                       ; terrain id -> overview glyph (low byte of G)
        db G_OV_DEEP-256,G_OV_SHAL-256,G_OV_SHAL-256,G_OV_BEACH-256
        db G_OV_GRASS-256,G_OV_GRASS-256,G_OV_FOREST-256,G_OV_FOREST-256
        db G_OV_HILLS-256,G_OV_MOUNT-256,G_OV_SNOW-256,G_OV_DESERT-256
        db G_OV_MARSH-256,G_OV_FIELD-256,G_OV_HILLS-256,G_OV_GRASS-256

draw_overview:
        ld b,1
        ld c,23
        ld a,C_TEXT
        call shadow_clear_rows
        ; columns of cells, centred
        ld a,(ovcw)
        ld c,a
        ld a,(mapwm1)
        call div_a_c
        inc a
        ld (ovcols),a
        ld b,a
        ld a,COLS
        sub b
        srl a
        ld (ovcol),a
        call ov_mark_towns
        ld a,(mono)
        ld (ov_mono),a
        xor a
        ld (ov_d),a
.r:     ; IX = shadow cell of this row
        ld a,(ov_d)
        inc a
        ld b,a
        ld a,(ovcol)
        ld c,a
        call cell_off
        ld ix,SCHR
        add ix,de
        ; sample row y = d*ovch + ovch/2 (clamped)
        ld a,(ovch)
        ld e,a
        ld a,(ov_d)
        ld h,a
        push ix
        call mul8
        pop ix
        ld a,(ovch)
        srl a
        add a,l
        jr c,.yc
        call cph
        jr c,.yo
.yc:    ld a,(maphm1)
.yo:    ld (ov_y),a
        xor a
        ld (ov_e),a
        ld (ov_x),a
.c:     ld a,(ov_y)
        ld b,a
        ld a,(ovcw)
        srl a
        ld c,a
        ld a,(ov_x)
        add a,c
        jr c,.xc
        call cpw
        jr c,.xo
.xc:    ld a,(mapwm1)
.xo:    ld c,a
        call tile_addr
        ld a,(hl)
        bit 7,a
        jr nz,.k
        ld a,G_OV_FOG-256
        jr .put
.k:     and 1Fh
        ld e,a
        call ov_is_town
        ld a,G_OV_TOWN-256
        jr nz,.put
        ld d,0
        ld hl,ov_class
        add hl,de
        ld a,(hl)
.put:   ; A = G low (G = 256 + A): code = A|80h, bank = 2 + (A>>7)
        ld e,a
        or 80h
        ld (ix+0),a
        ld a,e
        rlca
        and 1
        add a,2
        ld d,a
        ld a,(ov_mono)
        or a
        jr z,.cb
        ld a,d
        add a,8
        ld d,a
.cb:    push ix
        pop hl
        ld bc,SCRSIZE
        add hl,bc
        ld (hl),d
        add hl,bc
        ld a,(ov_mono)
        or a
        ld a,0Fh
        jr nz,.cs
        push hl
        ld d,0
        ld hl,char_col+256
        add hl,de
        ld a,(hl)
        pop hl
        call season_bg
.cs:    ld (hl),a
        inc ix
        ld a,(ovcw)
        ld b,a
        ld a,(ov_x)
        add a,b
        ld (ov_x),a
        ld a,(ov_e)
        inc a
        ld (ov_e),a
        ld hl,ovcols
        cp (hl)
        jr nz,.c
        ld hl,ov_d
        inc (hl)
        ld a,(hl)
        cp 22
        jp nz,.r
        ; view rectangle: invert the border cells under the view
        ld a,(ovch)
        ld c,a
        ld a,(viewy)
        call div_a_c
        ld (ovy0),a
        ld a,(viewy)
        add a,VIEWH-1
        call div_a_c
        ld (ovy1),a
        ld a,(ovcw)
        ld c,a
        ld a,(viewx)
        call div_a_c
        ld (ovx0),a
        ld a,(viewx)
        add a,VIEWW-1
        call div_a_c
        ld (ovx1),a
        ld a,(ovy0)
        ld b,a
.vr:    ld a,(ovx0)
        ld c,a
.vc:    ld a,b
        ld hl,ovy0
        cp (hl)
        jr z,.inv
        ld hl,ovy1
        cp (hl)
        jr z,.inv
        ld a,c
        ld hl,ovx0
        cp (hl)
        jr z,.inv
        ld hl,ovx1
        cp (hl)
        jr nz,.ni
.inv:   ld a,b
        cp 22
        jr nc,.ni
        push bc
        inc b
        ld a,(ovcol)
        add a,c
        ld c,a
        call cell_off
        ld hl,SCOL
        add hl,de
        ld a,(hl)
        call swapnib
        ld (hl),a
        pop bc
.ni:    inc c
        ld a,(ovx1)
        cp c
        jr nc,.vc
        inc b
        ld a,(ovy1)
        cp b
        jr nc,.vr
        ; legend
        ld b,2
        ld c,1
        ld hl,txt_worldmap
        ld a,C_MSG
        call puts_at
        ld hl,legend
        ld b,4
.lg:    ld a,(hl)
        cp 0FFh
        jr z,.lge
        inc hl
        inc hl
        push hl
        push bc
        ld l,a
        ld h,1
        ld c,1
        push hl
        call cell_off
        pop hl
        call put_gc
        inc de
        inc de
        pop bc
        pop hl
        push bc
        ld a,C_DIM
        call puts
        inc hl
        pop bc
        inc b
        inc b
        jr .lg
.lge:   ld b,22
        ld c,1
        ld hl,txt_ovhelp
        ld a,C_DIM
        call puts_at
        jp present_all

; mark overview cells containing a settlement (bit array 22 rows x 64 cols)
ov_mark_towns:
        ld hl,ovtown
        ld de,ovtown+1
        ld bc,22*8-1
        ld (hl),0
        ldir
        ld a,(nbld)
        or a
        ret z
        ld b,a
        ld ix,blist
.l:     push bc
        ld a,(ovcw)
        ld c,a
        ld a,(ix+1)
        call div_a_c
        ld e,a                  ; cell x
        ld a,(ovch)
        ld c,a
        ld a,(ix+2)
        call div_a_c            ; cell y
        cp 22
        jr nc,.n
        call ov_bitaddr
        or (hl)
        ld (hl),a
.n:     ld de,BREC
        add ix,de
        pop bc
        djnz .l
        ret
; A = cell y, E = cell x -> HL = byte, A = bit mask
ov_bitaddr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; y*8 bytes
        ld a,e
        rrca
        rrca
        rrca
        and 1Fh
        ld c,a
        ld b,0
        add hl,bc
        ld bc,ovtown
        add hl,bc
        ld a,e
        and 7
        ld b,a
        inc b
        ld a,80h
.s:     rlca
        djnz .s
        ret
; NZ if the current overview cell (ov_e, ov_d) has a settlement
ov_is_town:
        push de
        ld a,(ov_e)
        ld e,a
        ld a,(ov_d)
        call ov_bitaddr
        and (hl)
        pop de
        ret

legend: db G_OV_TOWN-256,0
        db "TOWN",0
        db G_OV_GRASS-256,0
        db "LAND",0
        db G_OV_FOREST-256,0
        db "FOREST",0
        db G_OV_HILLS-256,0
        db "HILLS",0
        db G_OV_MOUNT-256,0
        db "PEAKS",0
        db G_OV_DEEP-256,0
        db "SEA",0
        db G_OV_FOG-256,0
        db "UNKNOWN",0
        db 0FFh

clampvx:                        ; A = min(A, vxmax)
        push hl
        ld hl,vxmax
        cp (hl)
        jr c,.ok
        ld a,(hl)
.ok:    pop hl
        ret
clampvy:
        push hl
        ld hl,vymax
        cp (hl)
        jr c,.ok
        ld a,(hl)
.ok:    pop hl
        ret

div_a_c:                        ; A = A / C
        push bc
        ld b,0
.l:     sub c
        jr c,.e
        inc b
        jr .l
.e:     ld a,b
        pop bc
        ret

overview_mode:
        call draw_overview
.lp:    call wait_frame
        call scan_keys
        ld a,(frames)
        and 7
        call z,animate
        ld a,KB_MAP
        call key_hit
        jr nz,.exit
        ld a,KB_ESC
        call key_hit
        jr nz,.exit
        ld a,KB_SPACE
        call key_hit
        jr nz,.exit
        ld a,KB_RET
        call key_hit
        jr nz,.exit
        ; move view
        ld c,0
        ld a,KB_LEFT
        call key_hit
        jr z,.m1
        ld a,(ovcw)
        add a,a
        ld b,a
        ld a,(viewx)
        sub b
        jr nc,.m0
        xor a
.m0:    ld (viewx),a
        ld c,1
.m1:    ld a,KB_RIGHT
        call key_hit
        jr z,.m2
        ld a,(ovcw)
        add a,a
        ld b,a
        ld a,(viewx)
        add a,b
        call clampvx
.m3:    ld (viewx),a
        ld c,1
.m2:    ld a,KB_UP
        call key_hit
        jr z,.m4
        ld a,(ovch)
        ld b,a
        ld a,(viewy)
        sub b
        jr nc,.m5
        xor a
.m5:    ld (viewy),a
        ld c,1
.m4:    ld a,KB_DOWN
        call key_hit
        jr z,.m6
        ld a,(ovch)
        ld b,a
        ld a,(viewy)
        add a,b
        call clampvy
.m7:    ld (viewy),a
        ld c,1
.m6:    ld a,c
        or a
        call nz,draw_overview
        jr .lp
.exit:  ; put cursor in middle of view
        ld a,(viewx)
        add a,VIEWW/2
        ld (curx),a
        ld a,(viewy)
        add a,VIEWH/2
        ld (cury),a
        call sfx_click
        ret

; ---------------- full screen redraw ----------------
redraw_all:
        call draw_view
        ld b,VIEWROW
        ld c,VIEWH
        call present_rows
        call draw_status
        call draw_toolbar
        call draw_msg
        call update_cursor_bc
        call draw_info
        jp cursor_on_hw

update_cursor_bc:
        ld a,(curx)
        ld c,a
        ld a,(cury)
        ld b,a
        ld (cursor_bc),bc
        ret

; ---------------- main game loop ----------------
game_loop:
        call redraw_all
.lp:    call wait_frame
        call scan_keys
        ; animation every 6 frames
        ld a,(animt)
        inc a
        ld (animt),a
        cp 6
        jr c,.na
        xor a
        ld (animt),a
        call animate
.na:    call handle_keys
        ld a,(quit_flag)
        or a
        ret nz
        ; simulation timer
        ld a,(speed)
        or a
        jr z,.ns
        ld e,a
        ld d,0
        ld hl,speed_frames
        add hl,de
        ld a,(tickc)
        inc a
        ld (tickc),a
        cp (hl)
        jr c,.ns
        xor a
        ld (tickc),a
        call sim_tick
.ns:    ; message timer
        ld a,(msgtimer)
        or a
        jr z,.mt
        dec a
        ld (msgtimer),a
        jr nz,.mt
        ld a,1
        ld (dirty_msg),a
.mt:    ; deferred redraws
        ld a,(dirty_view)
        or a
        jr z,.dv
        xor a
        ld (dirty_view),a
        call cursor_off_hw
        call draw_view
        ld b,VIEWROW
        ld c,VIEWH
        call present_rows
        call cursor_on_hw
.dv:    ld a,(dirty_status)
        or a
        jr z,.ds
        xor a
        ld (dirty_status),a
        call draw_status
        call draw_info
.ds:    ld a,(dirty_msg)
        or a
        jr z,.dm
        xor a
        ld (dirty_msg),a
        call draw_msg
.dm:    ; sounds queued by simulation
        ld a,(want_season)
        or a
        jr z,.s1
        xor a
        ld (want_season),a
        ld (want_done),a
        ld a,(season)
        add a,a
        ld l,a
        ld h,0
        ld de,msg_seasons
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,C_MSG
        call set_msg
        ld hl,tune_season
        call play_tune
.s1:    ld a,(want_done)
        or a
        jr z,.s2
        xor a
        ld (want_done),a
        call sfx_done
.s2:    ld a,(want_grow)
        or a
        jr z,.s3
        xor a
        ld (want_grow),a
        ld hl,tune_grow
        call play_tune
.s3:    ld a,(want_warn)
        or a
        jr z,.s4
        xor a
        ld (want_warn),a
        call sfx_warn
.s4:    ld a,(want_jingle)
        or a
        jr z,.s5
        xor a
        ld (want_jingle),a
        ld hl,tune_grow
        call play_tune
.s5:    jp .lp

; ---------------- input ----------------
handle_keys:
        call mouse_frame
        ; movement with auto-repeat
        ld a,KB_UP
        call key_down
        ld b,a
        xor a
        or b
        ld (mv_u),a
        ld a,KB_DOWN
        call key_down
        ld b,a
        xor a
        or b
        ld (mv_d),a
        ld a,KB_LEFT
        call key_down
        ld b,a
        xor a
        or b
        ld (mv_l),a
        ld a,KB_RIGHT
        call key_down
        ld b,a
        xor a
        or b
        ld (mv_r),a
        ld a,(mv_u)
        ld hl,mv_d
        or (hl)
        ld hl,mv_l
        or (hl)
        ld hl,mv_r
        or (hl)
        jr nz,.moving
        xor a
        ld (rep),a
        ; mouse motion: one immediate step
        ld a,(ms_mu)
        ld (mv_u),a
        ld b,a
        ld a,(ms_md)
        ld (mv_d),a
        or b
        ld b,a
        ld a,(ms_ml)
        ld (mv_l),a
        or b
        ld b,a
        ld a,(ms_mr)
        ld (mv_r),a
        or b
        jp nz,.go
        jp .act
.moving:
        ld a,(rep)
        inc a
        ld (rep),a
        cp 1
        jr z,.go
        cp 12
        jp c,.act
        ld a,KB_SHIFT
        call key_down
        ld b,3
        jr nz,.fastr
        ld b,1
.fastr: ld a,(rep)
        and b
        jp nz,.act
        ld a,(rep)
        cp 200
        jr c,.go
        ld a,100
        ld (rep),a
.go:    call cursor_off_hw
        ld a,(mv_u)
        or a
        jr z,.g1
        ld a,(cury)
        or a
        jr z,.g1
        dec a
        ld (cury),a
.g1:    ld a,(mv_d)
        or a
        jr z,.g2
        ld a,(cury)
        call ishm1
        jr z,.g2
        inc a
        ld (cury),a
.g2:    ld a,(mv_l)
        or a
        jr z,.g3
        ld a,(curx)
        or a
        jr z,.g3
        dec a
        ld (curx),a
.g3:    ld a,(mv_r)
        or a
        jr z,.g4
        ld a,(curx)
        call iswm1
        jr z,.g4
        inc a
        ld (curx),a
.g4:    ; scroll view if cursor near edge
        ld a,(viewx)
        ld (sc_ox),a
        ld a,(viewy)
        ld (sc_oy),a
        ld c,0
        ld a,(viewx)
        ld b,a
        ld a,(curx)
        sub b
        cp 2
        jr nc,.s1
        ld a,b
        or a
        jr z,.s1
        sub 4
        jr nc,.s0
        xor a
.s0:    ld (viewx),a
        ld c,1
.s1:    ld a,(viewx)
        ld b,a
        ld a,(curx)
        sub b
        cp VIEWW-2
        jr c,.s2
        ld a,b
        push hl
        ld hl,vxmax
        cp (hl)
        pop hl
        jr z,.s2
        add a,4
        call clampvx
.s1b:   ld (viewx),a
        ld c,1
.s2:    ld a,(viewy)
        ld b,a
        ld a,(cury)
        sub b
        cp 2
        jr nc,.s3
        ld a,b
        or a
        jr z,.s3
        sub 3
        jr nc,.s2b
        xor a
.s2b:   ld (viewy),a
        ld c,1
.s3:    ld a,(viewy)
        ld b,a
        ld a,(cury)
        sub b
        cp VIEWH-2
        jr c,.s4
        ld a,b
        push hl
        ld hl,vymax
        cp (hl)
        pop hl
        jr z,.s4
        add a,3
        call clampvy
.s3b:   ld (viewy),a
        ld c,1
.s4:    ld a,c
        or a
        jr z,.nos
        call scroll_view
        ld b,VIEWROW
        ld c,VIEWH
        call present_rows
.nos:   call update_cursor_bc
        call cursor_on_hw
        call draw_info
.act:   ; ---- action keys (left mouse button = build, right = next tool)
        ld a,(ms_click)
        bit 1,a
        jr nz,.place
        ld a,KB_SPACE
        call key_hit
        jr nz,.place
        ld a,KB_RET
        call key_hit
        jr z,.k1
.place: ld bc,(cursor_bc)
        call check_place
        jr z,.ok
        ld a,C_WARN
        call set_msg
        call sfx_error
        jr .k1
.ok:    call cursor_off_hw
        call do_place
        call cursor_on_hw
        ld a,1
        ld (dirty_status),a
.k1:    ; tool selection keys 1-9,0
        ld b,0
.tk:    ld a,b
        add a,KB_1
        push bc
        call key_hit
        pop bc
        jr z,.tn
        ld a,b
        ld (tool),a
        call draw_toolbar
        call draw_info
        call sfx_click
        jr .k2
.tn:    inc b
        ld a,b
        cp NTOOLS
        jr nz,.tk
.k2:    ld a,(ms_click)
        bit 0,a
        jr nz,.tab
        ld a,KB_TAB
        call key_hit
        jr z,.k3
.tab:
        ld a,(tool)
        inc a
        cp NTOOLS
        jr c,.tb
        xor a
.tb:    ld (tool),a
        call draw_toolbar
        call draw_info
        call sfx_click
.k3:    ld a,KB_MAP
        call key_hit
        jr z,.k4
        call cursor_off_hw
        call overview_mode
        call wait_release
        call redraw_all
.k4:    ld a,KB_COL
        call key_hit
        jr z,.k5
        ld a,(mono)
        xor 1
        ld (mono),a
        call redraw_all
        call sfx_click
.k5:    ld a,KB_PAUSE
        call key_hit
        jr z,.k6
        ld a,(speed)
        or a
        jr z,.unp
        ld (lastspeed),a
        xor a
        jr .sps
.unp:   ld a,(lastspeed)
        or a
        jr nz,.sps
        ld a,2
.sps:   ld (speed),a
        ld a,1
        ld (dirty_status),a
        call sfx_click
.k6:    ld a,KB_FAST
        call key_hit
        jr z,.k7
        ld a,(speed)
        cp 3
        jr z,.k7
        inc a
        ld (speed),a
        ld a,1
        ld (dirty_status),a
.k7:    ld a,KB_SLOW
        call key_hit
        jr z,.k8
        ld a,(speed)
        cp 2
        jr c,.k8
        dec a
        ld (speed),a
        ld a,1
        ld (dirty_status),a
.k8:    ld a,KB_FILE
        call key_hit
        jr z,.k8b
        call cursor_off_hw
        call file_screen
        call redraw_all
.k8b:   ld a,KB_HELP
        call key_hit
        jr z,.k9
        call cursor_off_hw
        ld hl,help_screen
        call ovl_call
        call redraw_all
.k9:    ld a,KB_ESC
        call key_hit
        ret z
        ; confirm quit
        ld hl,msg_quit
        ld a,C_WARN
        call set_msg
        call draw_msg
.q:     call wait_frame
        call scan_keys
        ld a,KB_Y
        call key_hit
        jr nz,.yes
        ld a,KB_N
        call key_hit
        jr nz,.no
        ld a,KB_ESC
        call key_hit
        jr nz,.no
        jr .q
.yes:   ld a,1
        ld (quit_flag),a
        ret
.no:    xor a
        ld (msgtimer),a
        ld a,1
        ld (dirty_msg),a
        ret

; ---------------- text ----------------
msg_welcome:  db "YOUR SETTLERS HAVE FOUNDED A TOWN. BUILD HUTS, FARMS AND A WOODCUTTER!",0
msg_hint:     db "ARROWS MOVE  SPACE BUILD  1-0 TOOLS  M MAP  F SAVE/LOAD  P PAUSE  H HELP",0
msg_started:  db "CONSTRUCTION BEGUN.",0
msg_complete: db "CONSTRUCTION COMPLETE!",0
msg_grow:     db "A HUT HAS GROWN INTO A FINER HOME.",0
msg_starve:   db "FOOD HAS RUN OUT - PEOPLE ARE LEAVING! BUILD FARMS.",0
msg_ruins:    db "ANCIENT RUINS DISCOVERED! SCHOLARS FIND 25 GOLD.",0
msg_quit:     db "ABANDON THIS WORLD AND RETURN TO THE MENU? (Y/N)",0
msg_ev_trade: db "TRAVELLING TRADERS ARRIVE: +30 GOLD",0
msg_ev_harvest: db "A BUMPER HARVEST: +40 FOOD",0
msg_ev_migrant: db "MIGRANTS SETTLE IN YOUR TOWN: +5 PEOPLE",0
msg_ev_storm: db "A STORM DAMAGES THE TIMBER STORES: -10 WOOD",0
msg_ev_wolves: db "WOLVES RAID THE GRANARY: -8 FOOD",0
msg_seasons:  dw ms0,ms1,ms2,ms3
ms0:    db "SPRING ARRIVES. THE FIELDS ARE SOWN.",0
ms1:    db "SUMMER. THE CROPS GROW TALL.",0
ms2:    db "AUTUMN - HARVEST TIME!",0
ms3:    db "WINTER. SNOW COVERS THE LAND; FARMS LIE FALLOW.",0
err_fog:      db "YOU HAVE NOT EXPLORED THERE. BUILD A WATCHTOWER TO SEE FURTHER.",0
err_terr:     db "TOO FAR FROM YOUR SETTLEMENT. BUILD CLOSER, OR RAISE A TOWER.",0
err_occ:      db "THAT SPOT IS ALREADY OCCUPIED.",0
err_terrain:  db "YOU CANNOT BUILD ON THAT TERRAIN.",0
err_forest:   db "CLEAR THE FOREST FIRST (TOOL 0).",0
err_farm:     db "FARMS NEED OPEN GRASSLAND OR MEADOW.",0
err_wood:     db "A WOODCUTTER NEEDS FOREST WITHIN 2 TILES.",0
err_quarry:   db "A QUARRY NEEDS HILLS, ROCK OR MOUNTAINS NEARBY.",0
err_poor:     db "NOT ENOUGH RESOURCES.",0
err_tc:       db "THE TOWN HALL CANNOT BE DEMOLISHED.",0
err_nothing:  db "NOTHING TO CLEAR HERE.",0
txt_yr:       db " YR ",0
txt_unexplored: db "UNEXPLORED",0
txt_building: db " (BUILDING)",0
txt_worldmap: db "WORLD MAP",0
txt_ovhelp:   db "WASD MOVE",0

; ---------------- save / load panel (in game) ----------------
file_screen:
        ld hl,msg_reading
        ld a,C_MSG
        call set_msg
        call draw_msg
        call read_heads
        xor a
        ld (fm_mode),a
        ld hl,file_menu
        call ovl_call
        ld a,(ovl_ret)
        or a
        ret z
        cp 10h
        jr nc,.load
        ld (fm_slot),a
        ld hl,msg_saving
        ld a,C_MSG
        call set_msg
        call draw_msg
        ld a,(fm_slot)
        call save_game
        or a
        jr nz,.err
        ld hl,msg_saved
        ld a,C_GOOD
        call set_msg
        jp sfx_done
.load:  and 0Fh
        call load_game
        or a
        jr nz,.err
        ld hl,msg_loaded
        ld a,C_GOOD
        call set_msg
        ld a,1
        ld (dirty_status),a
        jp sfx_done
.err:   ; A = error 1..5
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,disk_errs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,C_WARN
        call set_msg
        jp sfx_error
disk_errs: dw de1,de2,de3,de4,de5
de1:    db "THERE IS NO SAVED WORLD IN THAT SLOT.",0
de2:    db "THE DISK IS WRITE-PROTECTED.",0
de3:    db "NO ROOM IN THE DISK DIRECTORY.",0
de4:    db "THE DISK IS FULL - THE SAVE IS INCOMPLETE.",0
de5:    db "THAT SAVE IS DAMAGED OR NOT AN EMPIRES SAVE.",0
msg_reading: db "READING THE DISK...",0
msg_saving:  db "SAVING YOUR WORLD TO DISK...",0
msg_saved:   db "YOUR WORLD HAS BEEN SAVED.",0
msg_loaded:  db "WORLD LOADED. WELCOME BACK!",0
