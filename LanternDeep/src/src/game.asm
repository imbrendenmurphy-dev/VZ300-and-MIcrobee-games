; =====================================================================
; THE LANTERN DEEP - game logic (lower "home" block)
; =====================================================================

; ---------------- entity records: 16 bytes, entity n at ENTS + n*16
EN_TYPE     EQU 0
EN_X        EQU 1
EN_Y        EQU 2
EN_CELL     EQU 3           ; FLAGS cell pointer (word)
EN_GLYPH    EQU 5           ; character
EN_BANK     EQU 6
EN_COL      EQU 7           ; colour (fg, black background)
EN_STATE    EQU 8
EN_TIMER    EQU 9           ; movement / life countdown
EN_HP       EQU 10
EN_DIR      EQU 11
EN_FRAME    EQU 12
EN_AUX      EQU 13          ; hurt flash countdown
EN_AUX2     EQU 14          ; attack cooldown
EN_COL0     EQU 15          ; normal colour

T_PLAYER    EQU 1
T_BAT       EQU 2
T_SKEL      EQU 3
T_FIRE      EQU 4
T_SLASH     EQU 5
T_MOTE      EQU 6
T_SPARK     EQU 7
T_DUST      EQU 8
T_BOOM      EQU 9
T_EMBER     EQU 10
T_BEETLE    EQU 11
T_GHOST     EQU 12
T_SPIDER    EQU 13
T_SLIME     EQU 14
T_IMP       EQU 15
T_SHADE     EQU 16
T_EBOLT     EQU 17

MAX_ENT     EQU 15

DIR_UP      EQU 0
DIR_DOWN    EQU 1
DIR_LEFT    EQU 2
DIR_RIGHT   EQU 3

; items (bit n of 'items')
IT_KEY      EQU 1
IT_LANTERN  EQU 2
IT_BLADE    EQU 3
IT_RING     EQU 4
IT_POTION   EQU 5
IT_HEART    EQU 6

; room record (ROOMINFO, written by tools/gen.py)
RI_EXITS    EQU ROOMINFO+1          ; N S W E (same order as DIR_*)
RI_AMB      EQU ROOMINFO+5
RI_REGION   EQU ROOMINFO+6
RI_NAME1    EQU ROOMINFO+8
RI_NAME2    EQU ROOMINFO+10
RI_OBJS     EQU ROOMINFO+12
RI_SPAWNS   EQU ROOMINFO+14
RI_GROUPS   EQU ROOMINFO+16
RI_CYCLERS  EQU ROOMINFO+18
RI_WATER    EQU ROOMINFO+20
RI_NWATER   EQU ROOMINFO+22
RI_FIRE     EQU ROOMINFO+24
RI_NFIRE    EQU ROOMINFO+26

; object records (10 bytes)
OB_KIND     EQU 0
OB_X        EQU 1
OB_Y        EQU 2
OB_W        EQU 3
OB_H        EQU 4
OB_A0       EQU 5
OB_A1       EQU 6
OB_A2       EQU 7
OB_A3       EQU 8
OB_BIT      EQU 9

; colours
C_BLK EQU 0
C_RED EQU 1
C_GRN EQU 2
C_YEL EQU 3
C_BLU EQU 4
C_MAG EQU 5
C_CYN EQU 6
C_GRY EQU 7
C_DGR EQU 8
C_BRED EQU 9
C_BGRN EQU 10
C_BYEL EQU 11
C_BBLU EQU 12
C_BMAG EQU 13
C_BCYN EQU 14
C_WHT EQU 15

F_EDGEALL   EQU (1<<F_EDGE)|(1<<F_OPAQUE)|(1<<F_SOLID)

; =====================================================================
; New game / continue
; =====================================================================
game_new:   ld a,3 : ld (lives),a
            xor a
            ld (items),a : ld (ck_valid),a : ld (gold),a : ld (gold+1),a
            ld hl,room_bits : ld bc,5*N_ROOMS : ld e,0 : call fill
            call seen_clear
            ld a,5 : ld (hp_max),a
            ld hl,ENTS+16
            ld (hl),T_PLAYER
            ld a,DIR_RIGHT : ld (ENTS+16+EN_DIR),a
            ld a,START_ROOM : ld bc,START_X*256+START_Y
            jr game_enter

game_continue:
            call lives_check
            ld a,(ck_dir) : ld (ENTS+16+EN_DIR),a
            ld a,(ck_room) : ld bc,(ck_xy)
game_enter: push af : push bc
            xor a
            ld (in_room),a : ld (dead),a : ld (msg_timer),a
            ld (prev_input),a : ld (atk_timer),a : ld (move_acc),a
            ld (cele_timer),a : ld (hall_spoken),a : ld (end_t),a : ld (king_spoke),a
            ld a,$FF : ld (cur_region),a
            ld a,(hp_max) : ld (hp),a
            ld a,5 : ld (mp),a
            call torch_select
            call q_reset
            ; the player record
            ld ix,ENTS+16
            ld (ix+EN_TYPE),T_PLAYER
            ld (ix+EN_BANK),SPRITE_BANK
            ld a,C_WHT : ld (ix+EN_COL),a : ld (ix+EN_COL0),a
            ld (ix+EN_AUX),0 : ld (ix+EN_FRAME),0
            call player_glyph_nd
            pop bc : pop af
            call enter_room
            call hud_draw
            ld hl,(frames) : ld (last_frames),hl
            ret

; the lantern decides which ray-trees light the way
torch_select:
            ld hl,trees_std : ld a,BLK_WORLD
            ld b,a
            ld a,(items) : bit IT_LANTERN,a
            ld a,b
            jr z,.s
            ld hl,trees_glim : ld a,BLK_WORLD2
.s:         ld (torch_blk),a
            ld (tree_tab),hl
            ld a,(ENTS+16+EN_DIR)
            jp set_tree
tree_tab:   DW trees_std
trees_std:  DW TREE_UP,TREE_DOWN,TREE_LEFT,TREE_RIGHT
trees_glim: DW TREE2_UP,TREE2_DOWN,TREE2_LEFT,TREE2_RIGHT

; =====================================================================
; Entering a room. A = room, B = x, C = y (player position)
; =====================================================================
enter_room: ld (er_room),a
            ld (er_xy),bc
            ld a,(in_room) : or a : jr z,.fresh
            ld a,(cur_room) : call seen_save
.fresh:     ld a,1 : ld (in_room),a
            call blank_play
            ; a new region: its tiles, tables and music
            ld a,(er_room) : ld l,a : ld h,0 : add hl,hl
            ld de,ROOM_TAB : add hl,de
            ld a,(hl) : ld hl,cur_region : cp (hl)
            jr z,.same
            push af
            call music_stop
            pop af
            push af
            call region_load
            pop af
            push af
            add a,a : add a,a : ld e,a : ld d,0
            ld hl,REG_MUSIC : add hl,de
            ld e,(hl) : inc hl : ld d,(hl) : inc hl
            ld a,(hl) : inc hl : ld h,(hl) : ld l,a
            ex de,hl
            ld de,0                         ; the melody alone, no accompaniment
            ld a,1 : call music_start
            pop af
            ld (announce),a
            ld a,1 : ld (announce_on),a
.same:      ld a,(er_room) : call room_load
            call derive_flags
            ld a,(er_room) : call seen_load
            call reset_room
            call apply_objects
            ; the bearer
            ld bc,(er_xy) : call xy_cell
            ld ix,ENTS+16
            ld a,b : ld (ix+EN_X),a
            ld a,c : ld (ix+EN_Y),a
            ld a,1 : call ent_place
            ld (player_cell),hl
            call spawn_foes
            call boss_setup
            call draw_seen
            ld a,1 : ld (need_relight),a : ld (hud_dirty),a
            ld a,(er_room) : ld e,a : ld d,0 : ld hl,visited : add hl,de : ld (hl),1
            ; checkpoint for CONTINUE
            ld a,(er_room) : ld (ck_room),a
            ld hl,(er_xy) : ld (ck_xy),hl
            ld a,(ENTS+16+EN_DIR) : ld (ck_dir),a
            ld a,(demo_on) : or a : jr nz,.nc
            ld a,1 : ld (ck_valid),a
.nc:        ld a,(announce_on) : or a : jr z,.na
            xor a : ld (announce_on),a
            ld a,(announce) : add a,a : ld e,a : ld d,0
            ld hl,REGION_NAMES : add hl,de
            ld a,(hl) : inc hl : ld h,(hl) : ld l,a
            call message
            ld a,(demo_on) : or a : jr nz,.na
            ld a,(announce) : or a : jr z,.na
            ; the region's name, spoken
            dec a : ld e,a : add a,a : add a,e : add a,a : ld e,a : ld d,0   ; *6
            ld hl,REG_SPEECH : add hl,de
            ld e,(hl) : inc hl : ld d,(hl) : inc hl
            ld c,(hl) : inc hl : ld b,(hl) : inc hl
            ld a,(hl)
            ex de,hl : ld d,b : ld e,c
            call speak
.na:        ; the Hollow King speaks, once
            ld a,(er_room) : cp 19 : jr nz,.nk
            ld a,(king_spoke) : or a : jr nz,.nk
            ld a,(demo_on) : or a : jr nz,.nk
            xor a : call bit_test : jr nz,.nk   ; not once he has fallen
            ld a,1 : ld (king_spoke),a
            ld hl,SPEECH_KING : ld de,SPEECH_KING_LEN : ld a,SPEECH_KING_BLK : call speak
.nk:        ld hl,(frames) : ld (last_frames),hl
            ret
king_spoke: DB 0
REG_SPEECH: DW SPEECH_R1,SPEECH_R1_LEN : DB SPEECH_R1_BLK,0
            DW SPEECH_R2,SPEECH_R2_LEN : DB SPEECH_R2_BLK,0
            DW SPEECH_R3,SPEECH_R3_LEN : DB SPEECH_R3_BLK,0
            DW SPEECH_R4,SPEECH_R4_LEN : DB SPEECH_R4_BLK,0
er_room:    DB 0
er_xy:      DW 0
in_room:    DB 0
announce:   DB 0
announce_on: DB 0

; black out the play area (colour RAM rows 0-21)
; Clear the play area (rows 0-21) for real: blank characters from the
; font bank as well as black colour. Black on black alone hides nothing
; on a monochrome monitor, which shows the characters whatever their colour.
blank_play: ld a,COL_ON : out (P_COLCTL),a
            ld hl,COLWIN : ld bc,22*80 : ld e,0 : call fill
            xor a : out (P_COLCTL),a
            ld a,LV_ATTR : out (P_LV),a
            ld hl,VIDEO : ld bc,22*80 : ld e,FONT_BANK : call fill
            ld a,LV_SCREEN : out (P_LV),a
            ld hl,VIDEO : ld bc,22*80 : ld e,$80 : jp fill

; FLAGS from the tiles: border cells are edge, play cells take their
; tile's flags
derive_flags:
            ld hl,FLAGS : ld bc,$0C00 : ld e,F_EDGEALL : call fill
            ld hl,FLAGS+STRIDE+1
            ld c,22
.r:         ld b,80
.c:         ld a,h : add a,D_TILE : ld d,a : ld e,l
            ld a,(de) : ld e,a : ld d,TD_FLAGS>>8
            ld a,(de) : ld (hl),a
            inc hl
            djnz .c
            ld de,STRIDE-80 : add hl,de
            dec c : jr nz,.r
            ret

reset_room: ld hl,LIGHT : ld bc,$0C00 : ld e,0 : call fill
            ld hl,ENT : ld bc,$0C00 : ld e,0 : call fill
            ld hl,SHCHR : ld bc,$0C00 : ld e,$80 : call fill
            ld hl,SHCOL : ld bc,$0C00 : ld e,0 : call fill
            ld hl,SHKEY : ld bc,$0C00 : ld e,KEY_BLACK : call fill
            ld hl,ENTS+32 : ld bc,256-32 : ld e,0 : call fill
            ld hl,LISTA : ld (lst_prev),hl : ld (lst_prev_end),hl
            ld hl,DIRTYQ : ld (dq_ptr),hl
            ld hl,0 : ld (xlight_cell),hl
            xor a
            ld (fire_ent),a : ld (mote_count),a : ld (boss_on),a
            ld (sw_on),a : ld (cur_zone),a
            call q_reset
            ret

; every explored cell drawn as remembered
draw_seen:  ld hl,FLAGS+STRIDE+1
            ld c,22
.r:         ld b,80
.c:         bit F_SEEN,(hl) : jr z,.n
            push bc : push hl
            call render_cell
            pop hl : pop bc
.n:         inc hl
            djnz .c
            ld de,STRIDE-80 : add hl,de
            push bc : call vb_poll : pop bc
            dec c : jr nz,.r
            jp flush_outq

; foes from the room's spawn list (type, x, y)
spawn_foes: ld hl,(RI_SPAWNS)
.s:         ld a,(hl) : or a : ret z
            inc hl
            ld b,(hl) : inc hl
            ld c,(hl) : inc hl
            push hl
            call spawn_foe
            pop hl
            jr .s

; A = type, B = x, C = y: a foe, if the cell is free
spawn_foe:  push af
            call xy_cell
            pop af
; A = type, HL = cell
spawn_foe_at:
            ld (sf_type),a
            ld a,(hl) : and (1<<F_EDGE)|(1<<F_OPAQUE) : ret nz
            push hl
            call ent_at
            pop hl
            or a : ret nz
            push hl
            call ent_alloc
            pop hl
            ret c
            ld a,(sf_type) : ld (ix+EN_TYPE),a
            sub T_BAT : ld e,a
            add a,a : add a,e : ld e,a : ld d,0      ; *3
            push hl
            ld hl,FOE_TAB : add hl,de
            ld a,(hl) : ld (ix+EN_GLYPH),a : inc hl
            ld a,(hl) : ld (ix+EN_COL),a : ld (ix+EN_COL0),a : inc hl
            ld a,(hl) : ld (ix+EN_HP),a
            pop hl
            ld (ix+EN_BANK),SPRITE_BANK
            ld (ix+EN_DIR),DIR_LEFT
            call rnd : and 15 : add a,20 : ld (ix+EN_TIMER),a
            ld a,(ent_num)
            jp ent_place
sf_type:    DB 0
; per type from T_BAT: glyph, colour, hit points
FOE_TAB:    DB S_BAT0,C_BMAG,1          ; bat
            DB S_SKEL0,C_GRY,3          ; skeleton
            DB 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0
            DB S_BEETLE0,C_YEL,1        ; beetle
            DB S_GHOST0,C_BCYN,2        ; ghost
            DB S_SPIDER0,C_WHT,2        ; spider
            DB S_SLIME0,C_BGRN,3        ; slime
            DB S_IMP0,C_BRED,2          ; imp
            DB S_SHADE0,C_MAG,3         ; shade
            DB S_EBOLT0,C_BMAG,1        ; bolt

; B = x, C = y -> HL = FLAGS cell (preserves BC, DE)
xy_cell:    ld a,c : inc a
            srl a : ld h,a
            ld a,0 : rra : ld l,a
            ld a,b : inc a : add a,l : ld l,a
            ld a,h : add a,FLAGS>>8 : ld h,a
            ret

; HL = FLAGS cell -> B = x, C = y
cell_xy:    ld a,l : and $7F : dec a : ld b,a
            ld a,l : rla
            ld a,h : rla
            sub ((FLAGS>>8)*2)&$FF
            dec a : ld c,a
            ret

; =====================================================================
; Room objects and their remembered state (32 bits per room)
; =====================================================================
; A = bit -> HL = byte in room_bits, C = mask
bit_addr:   ld e,a
            and 7 : ld b,a : ld a,1
            jr z,.k
.s:         rlca : djnz .s
.k:         ld c,a
            ld a,e : rrca : rrca : rrca : and 3 : ld e,a
            ld a,(cur_room) : add a,a : add a,a : add a,e
            ld e,a : ld d,0 : ld hl,room_bits : add hl,de
            ret
; A = bit -> NZ if set (bit $FF: never)
bit_test:   cp $FF : jr z,.no
            call bit_addr
            ld a,(hl) : and c
            ret
.no:        xor a
            ret
bit_set:    cp $FF : ret z
            call bit_addr
            ld a,(hl) : or c : ld (hl),a
            ret

; B = x, C = y -> IX = object covering the cell, carry clear (carry: none)
obj_find:   ld ix,(RI_OBJS)
.o:         ld a,(ix+OB_KIND) : or a : scf : ret z
            ld a,b : sub (ix+OB_X) : jr c,.nx
            cp (ix+OB_W) : jr nc,.nx
            ld a,c : sub (ix+OB_Y) : jr c,.nx
            cp (ix+OB_H) : jr nc,.nx
            or a
            ret
.nx:        ld de,10 : add ix,de
            jr .o

; objects already opened / taken / beaten in an earlier visit
apply_objects:
            ld ix,(RI_OBJS)
.o:         ld a,(ix+OB_KIND) : or a : ret z
            ld a,(ix+OB_BIT) : call bit_test
            call nz,obj_open
            ld de,10 : add ix,de
            jr .o

; IX = object: show it opened
obj_open:   ld a,(ix+OB_KIND)
            cp O_COLOSSUS : jr z,.rub
            cp O_KING : jr z,.rub
            cp O_HEART : jr z,.heart
            cp O_STAIRS : ret nc
            cp O_TABLET : ret z
            ld b,(ix+OB_X) : ld c,(ix+OB_Y) : call xy_cell
            ld a,(ix+OB_A1)
            jp set_tile
.rub:       ld hl,0 : ld (of_list),hl
            ld a,(ix+OB_A0)
            jr obj_fill
.heart:     ld l,(ix+OB_A0) : ld h,(ix+OB_A1) : ld (of_list),hl
            ; fall through

; IX = object, A = tile (or tiles from of_list): fill its rectangle
obj_fill:   ld (of_tile),a
            ld b,(ix+OB_X) : ld c,(ix+OB_Y)
            ld a,(ix+OB_H) : ld (of_h),a
.r:         push bc
            ld a,(ix+OB_W) : ld (of_w),a
.c:         push bc
            call xy_cell
            ld de,(of_list)
            ld a,d : or e
            ld a,(of_tile)
            jr z,.t
            ld a,(de) : inc de : ld (of_list),de
.t:         call set_tile
            pop bc
            inc b
            ld a,(of_w) : dec a : ld (of_w),a : jr nz,.c
            pop bc
            inc c
            ld a,(of_h) : dec a : ld (of_h),a : jr nz,.r
            ret
of_tile:    DB 0
of_w:       DB 0
of_h:       DB 0
of_list:    DW 0

; open every object sharing bit A (a gate of several bars, ...)
open_bit:   ld (ob_bit),a
            call bit_set
            ld ix,(RI_OBJS)
.o:         ld a,(ix+OB_KIND) : or a : ret z
            ld a,(ob_bit) : cp (ix+OB_BIT)
            call z,obj_open
            ld de,10 : add ix,de
            jr .o
ob_bit:     DB 0

; HL = cell, A = tile: change the map (flags follow the tile)
set_tile:   push hl
            ld e,a
            ld a,h : add a,D_TILE : ld h,a
            ld (hl),e
            pop hl
            ld d,TD_FLAGS>>8 : ld a,(de) : ld d,a
            ld a,(hl) : and $E0 : or d : ld (hl),a
            call mark_dirty
            ld a,1 : ld (need_relight),a
            ret

; =====================================================================
; Main loop
; =====================================================================
game_loop:
            call wait_frame
            call flush_outq
            call anim_tick
            ; elapsed frames since the last tick (capped)
            ld hl,(frames) : ld de,(last_frames)
            ld (last_frames),hl
            or a : sbc hl,de
            ld a,h : or a : jr nz,.cap
            ld a,l : cp 9 : jr c,.dt
.cap:       ld a,8
.dt:        or a : jr nz,.dt1
            inc a
.dt1:       ld (dt),a
            call snd_update
            call read_input
            ld a,(input) : bit 6,a
            jp nz,to_title
            ld a,(end_t) : or a : jp nz,ending_tick
            ; M: the journal
            ld a,1 : out (P_ROMLAT),a
            ld a,13 : call keytest
            ld b,a
            xor a : out (P_ROMLAT),a
            ld a,b : or a
            call nz,journal
            call player_update
            call fx_update
            call boss_update
            call ambient_spawn
            call zone_update
            call cycle_update
            ld a,(need_relight) : or a
            jr z,.nr
            xor a : ld (need_relight),a
            call relight
            jr .rd
.nr:        call flicker_update
.rd:        call render_dirty
            call hud_update
            jr game_loop

last_frames: DW 0
dt:         DB 1
need_relight: DB 0

to_title:   ld a,(in_room) : or a : jp z,title_screen
            ld a,(cur_room) : call seen_save
            xor a : ld (in_room),a
            jp title_screen

; =====================================================================
; Entities
; =====================================================================
; -> IX = free record, A = its number (ent_num). Carry set if none.
ent_alloc:  ld ix,ENTS+32
            ld a,2
.f:         ld (ent_num),a
            ld c,a
            ld a,(ix+EN_TYPE) : or a
            ld a,c
            ret z
            ld de,16 : add ix,de
            inc a : cp MAX_ENT+1
            jr nz,.f
            scf
            ret
ent_num:    DB 0

; IX = record, A = number, HL = cell. Puts the entity on the map.
ent_place:  ld (ix+EN_CELL),l : ld (ix+EN_CELL+1),h
            push hl
            ld b,a
            ld a,h : add a,D_ENT : ld h,a
            ld (hl),b
            pop hl
            jp mark_dirty

; IX = record: take it off the map and free it
ent_remove: ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            push hl
            ld a,h : add a,D_ENT : ld h,a
            ld (hl),0
            pop hl
            call mark_dirty
            ld (ix+EN_TYPE),0
            ret

; IX = record, HL = new cell. Moves the entity (map, coords, redraw).
ent_move:   push hl
            ld e,(ix+EN_CELL) : ld d,(ix+EN_CELL+1)
            ex de,hl
            ld a,h : add a,D_ENT : ld h,a
            ld b,(hl)                           ; our number
            ld (hl),0
            ld a,h : sub D_ENT : ld h,a
            call mark_dirty
            pop hl
            ld (ix+EN_CELL),l : ld (ix+EN_CELL+1),h
            push hl
            ld a,h : add a,D_ENT : ld h,a
            ld (hl),b
            pop hl
            call mark_dirty
            ld a,l : and $7F : dec a : ld (ix+EN_X),a
            ld a,l : rla
            ld a,h : rla
            sub ((FLAGS>>8)*2)&$FF
            dec a : ld (ix+EN_Y),a
            ret

; IX = record: redraw its cell (glyph or colour changed)
ent_dirty:  ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            jp mark_dirty

; HL = cell -> A = entity number there (0 = none), IY = its record
ent_at:     push hl
            ld a,h : add a,D_ENT : ld h,a
            ld a,(hl)
            pop hl
            or a : ret z
            push af
            add a,a : add a,a : add a,a : add a,a
            ld (.iy+2),a
.iy:        ld iy,ENTS
            pop af
            ret

; A = type -> A = properties (b0 foe, b1 ethereal, b2 flies)
TP_FOE      EQU 1
TP_ETH      EQU 2
TP_FLY      EQU 4
type_prop:  push hl : push de
            ld e,a : ld d,0
            ld hl,TPROP : add hl,de
            ld a,(hl)
            pop de : pop hl
            ret
TPROP:      DB 0,0,TP_FOE|TP_FLY,TP_FOE,0,0,TP_ETH,TP_ETH,TP_ETH,TP_ETH,TP_ETH
            DB 0,TP_FOE|TP_FLY,TP_FOE,TP_FOE,TP_FOE|TP_FLY,TP_FOE,0

; A = direction -> DE = cell delta
dir_delta:  ld hl,deltas
            add a,a : ld e,a : ld d,0 : add hl,de
            ld e,(hl) : inc hl : ld d,(hl)
            ret
deltas:     DW -STRIDE, STRIDE, -1, 1

; HL = cell: NZ if the player cannot enter (solid, or an entity)
blocked:    bit F_SOLID,(hl) : ret nz
            call ent_at
            or a : ret z
            ld a,(iy+EN_TYPE) : call type_prop
            and TP_ETH : jr nz,.eth
            or 1                                ; NZ: occupied
            ret
.eth:       push hl : push ix
            push iy : pop ix
            call ent_remove
            pop ix : pop hl
            xor a
            ret

; =====================================================================
; Player
; =====================================================================
player_update:
            ld ix,ENTS+16
            ld a,(dead) : or a : jp nz,player_dead
            ; hurt flash / invulnerability
            ld a,(ix+EN_AUX) : or a : jr z,.nh
            call tick_down
            ld (ix+EN_AUX),a
            jr nz,.nh
            ld a,(ix+EN_COL0) : ld (ix+EN_COL),a
            call player_glyph
.nh:        ; celebration pose
            ld a,(cele_timer) : or a : jr z,.nc
            call tick_down
            ld (cele_timer),a
            ret nz
            jp player_glyph
.nc:        ; strike in progress
            ld a,(atk_timer) : or a : jr z,.na
            call tick_down
            ld (atk_timer),a
            ret nz
            jp player_glyph
.na:        ld a,(input) : ld c,a
            ld a,(prev_input) : cpl : and c : ld b,a       ; newly pressed
            ld a,c : ld (prev_input),a
            bit 4,b : jp nz,player_action
            bit 5,b : jp nz,player_cast
            ld a,c : and $0F : jr nz,.dir
            ld a,(move_wait) : ld (move_acc),a            ; ready to step at once
            ld hl,idle_timer : inc (hl)
            ld a,(hl) : and $3F : ret nz
            ld a,(ix+EN_DIR) : cp DIR_DOWN : ret nz
            ld a,(ix+EN_GLYPH) : cp S_P_DOWN0
            ld a,S_P_IDLE1 : jr z,.ib
            ld a,S_P_DOWN0
.ib:        ld (ix+EN_GLYPH),a
            jp ent_dirty
.dir:       ld b,DIR_UP
            rrca : jr c,.gd
            inc b : rrca : jr c,.gd
            inc b : rrca : jr c,.gd
            inc b
.gd:        ld a,b
            cp (ix+EN_DIR) : jr z,.same
            ld (ix+EN_DIR),a
            call set_tree
            call player_glyph
            ld a,1 : ld (need_relight),a
            ld a,(move_wait) : sub 2 : ld (move_acc),a
            ret
.same:      ld c,3
            cp DIR_LEFT : jr nc,.mh
            ld c,5
.mh:        ld a,c : ld (move_wait),a
            ld a,(dt) : ld b,a
            ld a,(move_acc) : add a,b : ld (move_acc),a
            cp c : ret c
            xor a : ld (move_acc),a
            ; try to step
            ld a,(ix+EN_DIR) : call dir_delta
            ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            add hl,de
            bit F_EDGE,(hl) : jp nz,try_exit
            push hl
            call ent_at
            pop hl
            or a : jr z,.free
            ld a,(iy+EN_TYPE) : call type_prop
            and TP_FOE : jp nz,player_action            ; walking into a foe strikes it
.free:      call blocked
            jr nz,.wall
            call ent_move
            ld (player_cell),hl
            ld a,1 : ld (need_relight),a
            ld a,(ix+EN_FRAME) : xor 1 : ld (ix+EN_FRAME),a
            call player_glyph
            ld a,(ix+EN_FRAME) : and 1 : add a,SFX_STEP : call sfx
            ; what lies underfoot
            ld a,h : add a,D_TILE : ld d,a : ld e,l
            ld a,(de) : ld e,a : ld d,TD_CLASS>>8
            ld a,(de)
            cp C_STAIRS : jr z,take_stairs
            cp C_HOT : ret nz
            ld a,(items) : bit IT_RING,a : ret nz
            ld a,SFX_BURN : call sfx
            ld hl,msg_burn : call message
            jp player_hurt
.wall:      ld a,SFX_BUMP : jp sfx

; the player stands on stairs: down (or up) to another room
take_stairs:
            ld hl,(player_cell) : call cell_xy
            call obj_find : ret c
            ld a,(ix+OB_KIND) : cp O_STAIRS : jr z,.go
            cp O_STAIRS_UP : ret nz
.go:        ld b,(ix+OB_A1) : ld c,(ix+OB_A2)
            ld a,(ix+OB_A0)
            push af : push bc
            ld a,SFX_STAIRS : call sfx
            pop bc : pop af
            jp enter_room

; stepping off the edge of the room: through an exit, if there is one
try_exit:   ld a,(ix+EN_DIR) : ld e,a : ld d,0
            ld hl,RI_EXITS : add hl,de
            ld a,(hl) : cp $FF
            jr nz,.go
            ld a,SFX_BUMP : jp sfx
.go:        ld b,(ix+EN_X) : ld c,(ix+EN_Y)
            ld d,a
            ld a,e
            or a : jr nz,.d
            ld c,PLAY_ROWS-1 : jr .e            ; north: arrive at the bottom
.d:         dec a : jr nz,.l
            ld c,0 : jr .e                      ; south
.l:         dec a : jr nz,.r
            ld b,79 : jr .e                     ; west
.r:         ld b,0                              ; east
.e:         ld a,d
            jp enter_room

idle_timer: DB 0
move_acc:   DB 0
move_wait:  DB 3
prev_input: DB 0
atk_timer:  DB 0
cele_timer: DB 0

; IX = player: glyph from facing and walk frame
player_glyph:
            call player_glyph_nd
            jp ent_dirty
player_glyph_nd:
            ld a,(ix+EN_DIR) : add a,a
            add a,(ix+EN_FRAME)
            ld e,a : ld d,0
            ld hl,pglyphs : add hl,de
            ld a,(hl) : ld (ix+EN_GLYPH),a
            ret
pglyphs:    DB S_P_UP0,S_P_UP1,S_P_DOWN0,S_P_DOWN1,S_P_LEFT0,S_P_LEFT1,S_P_RIGHT0,S_P_RIGHT1
patk:       DB S_P_ATK_UP,S_P_ATK_DOWN,S_P_ATK_LEFT,S_P_ATK_RIGHT

; A = direction: choose the torch tree
set_tree:   add a,a : ld e,a : ld d,0
            ld hl,(tree_tab) : add hl,de
            ld a,(hl) : inc hl : ld h,(hl) : ld l,a
            ld (torch_tree),hl
            ret

; ---- SPACE: open / read / touch, or strike
player_action:
            ld ix,ENTS+16
            ld a,(ix+EN_DIR) : call dir_delta
            ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            add hl,de
            ld (front),hl
            call cell_xy
            call obj_find
            jr c,.noobj
            ld a,(ix+OB_KIND) : dec a
            add a,a : ld e,a : ld d,0
            ld hl,obj_handlers : add hl,de
            ld a,(hl) : inc hl : ld h,(hl) : ld l,a
            jp (hl)
.noobj:     ld hl,(front)
            ld a,h : add a,D_TILE : ld h,a
            ld e,(hl) : ld d,TD_CLASS>>8
            ld a,(de) : cp C_CRYSTAL : jp nz,strike
            ld a,5 : ld (mp),a
            ld a,1 : ld (hud_dirty),a
            ld hl,msg_crystal : call message
            ld a,SFX_CHIME : jp sfx
front:      DW 0
obj_handlers:
            DW act_chest, act_tablet, act_gate, act_secret, act_barrier, act_pedestal
            DW strike, strike, strike, strike, act_heart

act_chest:  ld a,(ix+OB_BIT) : call bit_test : jp nz,strike
            ld a,(ix+OB_BIT) : call bit_set
            call obj_open
            ld a,(ix+OB_A0)
            jp give_item

act_tablet: ld l,(ix+OB_A0) : ld h,(ix+OB_A1)
            call message
            ld a,SFX_CHIME : jp sfx

act_gate:   ld hl,msg_locked
            ld de,msg_unlock
            jr act_need
act_secret: ld hl,msg_cracked
            ld de,msg_secret
            jr act_need
act_barrier:
            ld hl,msg_barrier
            ld de,msg_cut
act_need:   push hl : push de
            ld a,(ix+OB_BIT) : call bit_test
            jr z,.closed
            pop de : pop hl
            jp strike
.closed:    ld a,(ix+OB_A0) : call have_item
            pop de : pop hl
            jr z,.no
            ex de,hl : call message
            ld a,(ix+OB_BIT) : call open_bit
            ld a,SFX_UNLOCK : jp sfx
.no:        call message
            ld a,(ix+OB_KIND) : cp O_BARRIER : jp z,strike
            ld a,SFX_BUMP : jp sfx

act_pedestal:
            ld a,(ix+OB_BIT) : call bit_test : jp nz,strike
            ld a,(ix+OB_A2) : cp $FF : jr z,.free
            call bit_test : jr nz,.free
            ld hl,msg_guarded : call message
            ld a,SFX_BUMP : jp sfx
.free:      ld a,(ix+OB_BIT) : call bit_set
            call obj_open
            ld a,(ix+OB_A0)
            jp give_item

act_heart:  ld a,(ix+OB_BIT) : call bit_test : ret nz
            ld a,(ix+OB_A2) : call bit_test : jr nz,.lit
            ld hl,msg_cold : call message
            ld a,SFX_BUMP : jp sfx
.lit:       ld a,(ix+OB_BIT) : call bit_set
            call obj_open
            jp ending_start

; A = item -> NZ if carried
have_item:  ld b,a : ld a,1
.s:         rlca : djnz .s
            ld b,a
            ld a,(items) : and b
            ret

; A = item: the bearer takes it
give_item:  ld (gi_item),a
            cp IT_POTION : jr nc,.cons
            ld b,a : ld a,1
.s:         rlca : djnz .s
            ld hl,items : or (hl) : ld (hl),a
            ld a,(gi_item) : cp IT_LANTERN : jr nz,.msg
            call torch_select
            ld a,1 : ld (need_relight),a
            jr .msg
.cons:      cp IT_HEART : jr nz,.pot
            ld a,(hp_max) : cp 8 : jr nc,.pot
            inc a : ld (hp_max),a
.pot:       ld a,(hp_max) : ld (hp),a
.msg:       ld a,(gi_item) : dec a : add a,a : ld e,a : ld d,0
            ld hl,item_msgs : add hl,de
            ld a,(hl) : inc hl : ld h,(hl) : ld l,a
            call message
            ld a,1 : ld (hud_dirty),a
            ld a,SFX_JINGLE : call sfx
            ld ix,ENTS+16
            ld (ix+EN_GLYPH),S_P_CHEER
            call ent_dirty
            ld a,60 : ld (cele_timer),a
            ret
gi_item:    DB 0
item_msgs:  DW msg_key,msg_lantern,msg_blade,msg_ring,msg_potion,msg_heart,msg_potion

; sword: an arc in front, hitting the front cell and both side cells
strike:     ld ix,ENTS+16
            ld a,10 : ld (atk_timer),a
            ld a,(ix+EN_DIR)
            ld e,a : ld d,0 : ld hl,patk : add hl,de
            ld a,(hl) : ld (ix+EN_GLYPH),a
            call ent_dirty
            ld a,SFX_SWISH : call sfx
            ld a,(ix+EN_DIR)
            ld de,1
            cp DIR_LEFT : jr nc,.side
            ld de,STRIDE
.side:      ld (side),de
            call sword_dmg
            ld hl,(front) : call hit_cell
            call sword_dmg
            ld hl,(front) : ld de,(side) : add hl,de
            call hit_cell
            call sword_dmg
            ld hl,(front) : ld de,(side) : or a : sbc hl,de
            call hit_cell
            ; the arc itself, if the front cell is free floor
            ld hl,(front)
            bit F_SOLID,(hl) : ret nz
            call ent_at : or a : ret nz
            call ent_alloc : ret c
            ld (ix+EN_TYPE),T_SLASH
            ld (ix+EN_BANK),SPRITE_BANK
            ld (ix+EN_COL),C_WHT
            ld a,(items) : bit IT_BLADE,a : jr z,.c
            ld (ix+EN_COL),C_BCYN
.c:         ld (ix+EN_TIMER),8
            ld a,(ENTS+16+EN_DIR)
            ld e,a : ld d,0
            ld hl,slash0 : add hl,de
            ld a,(hl) : ld (ix+EN_GLYPH),a
            ld (ix+EN_DIR),e
            ld hl,(front)
            ld a,(ent_num)
            jp ent_place
side:       DW 0
slash0:     DB S_SLVM0,S_SLV0,S_SLHM0,S_SLH0
slash1:     DB S_SLVM1,S_SLV1,S_SLHM1,S_SLH1

; -> B = sword damage (the moonsilver blade cuts twice as deep)
sword_dmg:  ld b,1
            ld a,(items) : bit IT_BLADE,a : ret z
            inc b
            ret

; HL = cell, B = damage: hurt a foe (or the boss) there
hit_cell:   push bc
            call ent_at
            pop bc
            or a : jr z,.boss
            ld a,(iy+EN_TYPE) : call type_prop
            and TP_FOE : ret z
            push iy : pop ix
            jr damage
.boss:      ld a,h : add a,D_TILE : ld d,a : ld e,l
            ld a,(de) : ld e,a : ld d,TD_CLASS>>8
            ld a,(de) : cp C_BOSS : ret nz
            jp boss_hit

; IX = foe, B = damage
damage:     ld a,(ix+EN_HP) : sub b : ld (ix+EN_HP),a
            jr z,.die
            jr c,.die
            ld (ix+EN_AUX),8                    ; white hurt flash
            ld (ix+EN_COL),C_WHT
            call ent_dirty
            ld a,SFX_HIT : jp sfx
.die:       ld a,SFX_KILL : call sfx
            ld (ix+EN_TYPE),T_DUST
            ld (ix+EN_GLYPH),S_FX_DUST0
            ld (ix+EN_COL),C_GRY
            ld (ix+EN_TIMER),16
            ld hl,(gold) : ld de,5 : add hl,de : ld (gold),hl
            ld a,1 : ld (hud_dirty),a
            jp ent_dirty

; ---- F: fire bolt (lights its way)
player_cast:
            ld a,(mp) : or a
            jr nz,.ok
            ld hl,msg_nomana : call message
            ld a,SFX_BUMP : jp sfx
.ok:        ld a,(fire_ent) : or a : ret nz       ; one bolt at a time
            ld ix,ENTS+16
            ld a,(ix+EN_DIR) : call dir_delta
            ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            add hl,de
            ld a,(hl) : and (1<<F_OPAQUE)|(1<<F_EDGE) : ret nz
            push hl
            call ent_at
            pop hl
            or a : ret nz
            ld a,(ix+EN_DIR) : ld b,a
            push hl : push bc
            call ent_alloc
            pop bc : pop hl
            ret c
            ld (fire_ent),a
            ld (ix+EN_TYPE),T_FIRE
            ld (ix+EN_BANK),SPRITE_BANK
            ld (ix+EN_GLYPH),S_FX_FIRE0
            ld (ix+EN_COL),C_BYEL
            ld (ix+EN_DIR),b
            ld (ix+EN_TIMER),0
            ld a,(ent_num)
            call ent_place
            ld (xlight_cell),hl
            ld a,1 : ld (need_relight),a
            ld a,(mp) : dec a : ld (mp),a
            ld a,1 : ld (hud_dirty),a
            ld ix,ENTS+16
            ld (ix+EN_GLYPH),S_P_CAST
            call ent_dirty
            ld a,8 : ld (atk_timer),a
            ld a,SFX_FIRE : jp sfx

; ---- the player is hurt
player_hurt:
            ld a,(demo_on) : or a : ret nz      ; the tour's bearer is never hurt
            push ix
            ld ix,ENTS+16
            ld a,(ix+EN_AUX) : or a : jr nz,.out  ; still flashing: invulnerable
            ld a,(dead) : or a : jr nz,.out
            ld a,(hp) : dec a : ld (hp),a
            ld a,1 : ld (hud_dirty),a
            ld (ix+EN_AUX),70
            ld (ix+EN_COL),C_BRED
            ld (ix+EN_GLYPH),S_P_HURT
            call ent_dirty
            ld a,SFX_HURT : call sfx
            ld a,(hp) : or a : jr nz,.out
            ld a,1 : ld (dead),a
            xor a : ld (dead_t),a
            call death_msg
            ld a,SFX_DIE : call sfx
.out:       pop ix
            ret

player_dead:
            ld hl,dead_t : ld a,(dt) : add a,(hl) : ld (hl),a
            ld b,S_P_DIE0
            cp 16 : jr c,.g
            ld b,S_P_DIE1
            cp 32 : jr c,.g
            ld b,S_P_DIE2
            cp 200 : jr c,.g
            jp lose_life
.g:         ld a,b : cp (ix+EN_GLYPH) : ret z
            ld (ix+EN_GLYPH),a
            ld (ix+EN_COL),C_RED
            jp ent_dirty
dead:       DB 0
dead_t:     DB 0

; =====================================================================
; Foes and effects
; =====================================================================
fx_update:  ; one pass over every entity but the player
            ld ix,ENTS+32
            ld b,MAX_ENT-1
.e:         push bc
            ld a,(ix+EN_TYPE)
            or a : jr z,.nx
            ld hl,.nx : push hl
            dec a : dec a                       ; types from 2
            add a,a : ld e,a : ld d,0
            ld hl,ent_handlers : add hl,de
            ld a,(hl) : inc hl : ld h,(hl) : ld l,a
            jp (hl)
.nx:        pop bc
            ld de,16 : add ix,de
            djnz .e
            ret
ent_handlers:
            DW bat_update, skel_update, fire_update, slash_update, mote_update
            DW spark_update, dust_update, boom_update, ember_update, beetle_update
            DW walker_update, walker_update, walker_update, walker_update, walker_update
            DW ebolt_update

; countdown helper: A = value, subtract dt (floor 0) -> A, Z if reached 0
tick_down:  ld c,a : ld a,(dt) : ld b,a : ld a,c
            sub b : jr nc,.k
            xor a
.k:         or a
            ret

; shared: hurt flash wears off
foe_flash:  ld a,(ix+EN_AUX) : or a : ret z
            call tick_down
            ld (ix+EN_AUX),a
            ret nz
            ld a,(ix+EN_COL0) : ld (ix+EN_COL),a
            jp ent_dirty

; IX = foe: dx, dy to the player -> D = dx (signed), E = dy
to_player:  ld a,(ENTS+16+EN_X) : sub (ix+EN_X) : ld d,a
            ld a,(ENTS+16+EN_Y) : sub (ix+EN_Y) : ld e,a
            ret

; |A| -> A
abs_a:      bit 7,a : ret z
            neg
            ret

; IX = foe, A = direction, B = 1 lets it fly over water and other low
; obstacles. Attacks the player when stepping into them. Z if it moved.
foe_step:   call dir_delta
            ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            add hl,de
            push hl
            call ent_at
            pop hl
            or a : jr z,.free
            cp 1 : jr nz,.no                    ; another foe
            ; the player: attack if ready
            ld a,(ix+EN_AUX2) : or a : jr nz,.no
            ld (ix+EN_AUX2),60
            ld a,(ix+EN_TYPE) : cp T_BAT : jr nz,.sk
            ld (ix+EN_AUX2),150                 ; a bat bites, then keeps away
.sk:        cp T_SKEL : jr nz,.bite
            ld (ix+EN_GLYPH),S_SKEL2
            call ent_dirty
.bite:      call player_hurt
            jr .no
.free:      ld a,(hl) : and (1<<F_OPAQUE)|(1<<F_EDGE) : jr nz,.no
            ld a,b : or a : jr nz,.go           ; fliers ignore low obstacles
            bit F_SOLID,(hl) : jr nz,.no
            ; walkers keep off burning stone
            push hl
            ld a,h : add a,D_TILE : ld h,a
            ld e,(hl) : ld d,TD_CLASS>>8
            ld a,(de)
            pop hl
            cp C_HOT : jr z,.no
.go:        call ent_move
            xor a
            ret
.no:        or 1
            ret

; ---- bat: flutters, swoops at the player when near
bat_update: call foe_flash
            ld a,(ix+EN_AUX2) : or a : jr z,.c
            call tick_down : ld (ix+EN_AUX2),a
.c:         ld a,(ix+EN_FRAME) : add a,1 : ld (ix+EN_FRAME),a
            and 3 : jr nz,.mv
            ld a,(ix+EN_GLYPH) : xor S_BAT0^S_BAT1 : ld (ix+EN_GLYPH),a
            call ent_dirty
.mv:        ld a,(ix+EN_TIMER) : call tick_down : ld (ix+EN_TIMER),a
            ret nz
            call rnd : and 7 : add a,6 : ld (ix+EN_TIMER),a
            call to_player
            ld a,d : call abs_a : cp 14 : jr nc,.rand
            ld a,e : call abs_a : cp 6 : jr nc,.rand
            ld a,(ix+EN_AUX2) : or a : jr nz,.flee
            call rnd : cp 110 : jr c,.rand
            call toward
            ld b,1 : jp foe_step
.flee:      call toward : xor 1
            ld b,1 : jp foe_step
.rand:      call rnd : and 3
            ld b,1 : jp foe_step

; D = dx, E = dy -> A = direction toward the player
toward:     ld a,d : call abs_a : srl a : ld c,a
            ld a,e : call abs_a
            cp c : jr c,.h
            bit 7,e : ld a,DIR_UP : ret nz
            ld a,DIR_DOWN : ret
.h:         bit 7,d : ld a,DIR_LEFT : ret nz
            ld a,DIR_RIGHT : ret

; ---- skeleton warden: patrols, chases when the player comes near
skel_update:
            call foe_flash
            ld a,(ix+EN_AUX2) : or a : jr z,.c
            call tick_down : ld (ix+EN_AUX2),a
            cp 30 : jr nz,.c
            ld (ix+EN_GLYPH),S_SKEL0
            call ent_dirty
.c:         ld a,(ix+EN_TIMER) : call tick_down : ld (ix+EN_TIMER),a
            ret nz
            call to_player
            ld a,d : call abs_a : cp 14 : jr nc,.patrol
            ld a,e : call abs_a : cp 7 : jr nc,.patrol
            call toward
            ld c,9
            cp DIR_LEFT : jr nc,.t
            ld c,15
.t:         ld (ix+EN_TIMER),c
            ld b,0 : call foe_step
            jr .anim
.patrol:    ld (ix+EN_TIMER),12
            ld a,(ix+EN_DIR)
            ld b,0 : call foe_step
            jr z,.anim
            ld a,(ix+EN_DIR) : xor 1 : ld (ix+EN_DIR),a
.anim:      ld a,(ix+EN_GLYPH) : cp S_SKEL2 : ret z
            xor S_SKEL0^S_SKEL1 : ld (ix+EN_GLYPH),a
            jp ent_dirty

; ---- the creatures of the deep: one routine, a row of parameters each
;      step delay, chase range x, y, flies, glyph pair xor, shuns light
WALK_TAB:   DB 13,16,7,1,S_GHOST0^S_GHOST1,0        ; ghost: drifts through the dark
            DB 6,18,8,0,S_SPIDER0^S_SPIDER1,0       ; spider: quick
            DB 16,10,5,0,S_SLIME0^S_SLIME1,0        ; slime: slow, stubborn
            DB 7,22,9,1,S_IMP0^S_IMP1,0             ; imp: darts over fire
            DB 9,20,8,0,S_SHADE0^S_SHADE1,1         ; shade: the Unlight, shuns the lantern
walker_update:
            call foe_flash
            ld a,(ix+EN_TYPE) : sub T_GHOST
            ld e,a : add a,a : add a,e : add a,a : ld e,a : ld d,0
            ld hl,WALK_TAB : add hl,de
            ld (wk_par),hl
            ld a,(ix+EN_AUX2) : or a : jr z,.c
            call tick_down : ld (ix+EN_AUX2),a
.c:         ld a,(ix+EN_FRAME) : inc a : ld (ix+EN_FRAME),a
            and 7 : jr nz,.mv
            ld hl,(wk_par) : inc hl : inc hl : inc hl : inc hl
            ld a,(ix+EN_GLYPH) : xor (hl) : ld (ix+EN_GLYPH),a
            call ent_dirty
.mv:        ld a,(ix+EN_TIMER) : call tick_down : ld (ix+EN_TIMER),a
            ret nz
            ld hl,(wk_par)
            call rnd : and 3 : add a,(hl) : ld (ix+EN_TIMER),a
            inc hl
            call to_player
            ld a,d : call abs_a : cp (hl) : jr nc,.rand
            inc hl
            ld a,e : call abs_a : cp (hl) : jr nc,.rand
            ; a shade will not stand in the lantern light
            ld hl,(wk_par) : ld de,5 : add hl,de
            ld a,(hl) : or a : jr z,.chase
            ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            ld a,h : add a,D_LIGHT : ld h,a
            ld a,(hl) : and 7 : cp 4 : jr c,.chase
            call to_player : call toward : xor 1
            jr .step
.chase:     call to_player : call toward
            jr .step
.rand:      call rnd : cp 100 : ret c
            and 3
.step:      ld hl,(wk_par) : inc hl : inc hl : inc hl
            ld b,(hl)
            jp foe_step
wk_par:     DW 0

; ---- a bolt of unlight from a boss: flies straight, hurts the player
ebolt_update:
            ld a,(ix+EN_FRAME) : inc a : ld (ix+EN_FRAME),a
            and 3 : jr nz,.mv
            ld a,(ix+EN_GLYPH) : xor S_EBOLT0^S_EBOLT1 : ld (ix+EN_GLYPH),a
            call ent_dirty
.mv:        ld a,(ix+EN_TIMER) : call tick_down : ld (ix+EN_TIMER),a
            ret nz
            ld c,2
            ld a,(ix+EN_DIR) : cp DIR_LEFT : jr nc,.h
            ld c,4
.h:         ld (ix+EN_TIMER),c
            ld a,(ix+EN_DIR) : call dir_delta
            ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            add hl,de
            ld a,(hl) : and (1<<F_OPAQUE)|(1<<F_EDGE) : jp nz,ent_remove
            push hl
            call ent_at
            pop hl
            or a : jr z,.f
            cp 1 : jp nz,ent_remove
            call player_hurt
            jp ent_remove
.f:         jp ent_move

; ---- fire bolt: flies, lights the walls, bursts on impact
fire_update:
            ld a,(ix+EN_FRAME) : inc a : ld (ix+EN_FRAME),a
            and 3 : jr nz,.mv
            ld a,(ix+EN_GLYPH) : xor S_FX_FIRE0^S_FX_FIRE1 : ld (ix+EN_GLYPH),a
            call ent_dirty
.mv:        ld a,(ix+EN_TIMER) : call tick_down : ld (ix+EN_TIMER),a
            ret nz
            ld c,1
            ld a,(ix+EN_DIR) : cp DIR_LEFT : jr nc,.h
            ld c,2
.h:         ld (ix+EN_TIMER),c
            ld a,(ix+EN_DIR) : call dir_delta
            ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            add hl,de
            push hl
            call ent_at
            pop hl
            or a : jr z,.f
            ld a,(iy+EN_TYPE) : call type_prop
            and TP_ETH : jr z,.burst_on
            push ix : push iy : pop ix : call ent_remove : pop ix
.f:         ld a,(hl) : and (1<<F_OPAQUE)|(1<<F_EDGE) : jr nz,.burst_w
            call ent_move
            ld (xlight_cell),hl
            ld a,1 : ld (need_relight),a
            ret
.burst_w:   ld b,2 : push ix : call hit_cell : pop ix     ; a boss wall
            jr .burst
.burst_on:  ld b,2 : push ix : call hit_cell : pop ix
.burst:     ld (ix+EN_TYPE),T_BOOM
            ld (ix+EN_GLYPH),S_FX_BOOM0
            ld (ix+EN_COL),C_BYEL
            ld (ix+EN_TIMER),15
            call ent_dirty
            xor a : ld (fire_ent),a
            ld a,SFX_BOOM : call sfx
            ; scorch everything around
            ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            ld de,-STRIDE-1 : add hl,de
            ld c,3
.r:         ld b,3
.cl:        push bc : push hl
            ld b,1 : push ix : call hit_cell : pop ix
            pop hl : pop bc
            inc hl
            djnz .cl
            ld de,STRIDE-3 : add hl,de
            dec c : jr nz,.r
            ld b,4
.sp:        push bc
            call rnd : and 3 : call dir_delta
            ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            add hl,de
            ld a,T_SPARK : ld c,C_BYEL : ld d,S_FX_SPARK
            call spawn_fx
            pop bc
            djnz .sp
            ret

; A = type, HL = cell, C = colour, D = glyph: an effect on a free cell
spawn_fx:   bit F_OPAQUE,(hl) : ret nz
            bit F_EDGE,(hl) : ret nz
            push af
            push hl
            call ent_at
            pop hl
            or a : jr nz,.no
            push hl : push de : push bc
            call ent_alloc
            pop bc : pop de : pop hl
            jr c,.no
            pop af
            ld (ix+EN_TYPE),a
            ld (ix+EN_GLYPH),d
            ld (ix+EN_BANK),SPRITE_BANK
            ld (ix+EN_COL),c : ld (ix+EN_COL0),c
            ld (ix+EN_TIMER),10
            ld (ix+EN_FRAME),0
            ld (ix+EN_STATE),0
            ld a,(ent_num)
            jp ent_place
.no:        pop af
            ret

boom_update:
            ld a,(ix+EN_TIMER) : call tick_down : ld (ix+EN_TIMER),a
            jr z,.end
            ld b,S_FX_BOOM0
            cp 10 : jr nc,.g
            ld b,S_FX_BOOM1
            cp 5 : jr nc,.g
            ld b,S_FX_BOOM2
.g:         ld a,b : cp (ix+EN_GLYPH) : ret z
            ld (ix+EN_GLYPH),a
            jp ent_dirty
.end:       ld hl,0 : ld (xlight_cell),hl
            ld a,1 : ld (need_relight),a
            jp ent_remove

slash_update:
            ld a,(ix+EN_TIMER) : call tick_down : ld (ix+EN_TIMER),a
            jp z,ent_remove
            cp 4 : ret nc
            ld e,(ix+EN_DIR) : ld d,0
            ld hl,slash1 : add hl,de
            ld a,(hl) : cp (ix+EN_GLYPH) : ret z
            ld (ix+EN_GLYPH),a
            jp ent_dirty

spark_update:
            ld a,(ix+EN_TIMER) : call tick_down : ld (ix+EN_TIMER),a
            jp z,ent_remove
            cp 5 : ret nc
            ld a,(ix+EN_COL) : cp C_RED : ret z
            ld (ix+EN_COL),C_RED
            jp ent_dirty

dust_update:
            ld a,(ix+EN_TIMER) : call tick_down : ld (ix+EN_TIMER),a
            jp z,ent_remove
            cp 8 : ret nc
            ld a,(ix+EN_GLYPH) : cp S_FX_DUST1 : ret z
            ld (ix+EN_GLYPH),S_FX_DUST1
            ld (ix+EN_COL),C_DGR
            jp ent_dirty

; motes drift slowly and twinkle; they fade when their time is up
mote_update:
            ld a,(ix+EN_STATE) : call tick_down : ld (ix+EN_STATE),a
            jp z,mote_die
            ld a,(ix+EN_FRAME) : inc a : ld (ix+EN_FRAME),a
            and 15 : jr nz,.mv
            ld a,(ix+EN_GLYPH) : xor S_FX_MOTE^S_FX_MOTE2 : ld (ix+EN_GLYPH),a
            call ent_dirty
.mv:        ld a,(ix+EN_TIMER) : call tick_down : ld (ix+EN_TIMER),a
            ret nz
            call rnd : and 7 : add a,10 : ld (ix+EN_TIMER),a
            call rnd : and 7 : cp 4 : jr c,.d
            xor a
.d:         call dir_delta
            ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            add hl,de
            ld a,(hl) : and (1<<F_OPAQUE)|(1<<F_EDGE) : ret nz
            push hl : call ent_at : pop hl
            or a : ret nz
            jp ent_move
mote_die:   ld hl,mote_count : dec (hl)
            jp ent_remove

ember_update:
            ld a,(ix+EN_STATE) : call tick_down : ld (ix+EN_STATE),a
            jp z,mote_die
            ld a,(ix+EN_TIMER) : call tick_down : ld (ix+EN_TIMER),a
            ret nz
            ld (ix+EN_TIMER),6
            ld a,(ix+EN_COL) : xor C_BYEL^C_BRED : ld (ix+EN_COL),a
            call rnd : and 3 : jr nz,.up
            call rnd : and 1 : add a,DIR_LEFT
            jr .s
.up:        xor a
.s:         call dir_delta
            ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            add hl,de
            ld a,(hl) : and (1<<F_OPAQUE)|(1<<F_EDGE) : jr nz,.stop
            push hl : call ent_at : pop hl
            or a : jr nz,.stop
            jp ent_move
.stop:      jp ent_dirty

; ---- beetle: scuttles about, and away from the light
beetle_update:
            ld a,(ix+EN_TIMER) : call tick_down : ld (ix+EN_TIMER),a
            ret nz
            call rnd : and 7 : add a,5 : ld (ix+EN_TIMER),a
            call to_player
            ld a,d : call abs_a : srl a : ld c,a
            ld a,e : call abs_a : add a,c
            cp 4 : jr nc,.wander
            call toward : xor 1
            jr .step
.wander:    call rnd : cp 90 : ret c
            and 3
.step:      call dir_delta
            ld l,(ix+EN_CELL) : ld h,(ix+EN_CELL+1)
            add hl,de
            bit F_SOLID,(hl) : ret nz
            push hl : call ent_at : pop hl
            or a : ret nz
            call ent_move
            ld a,(ix+EN_GLYPH) : xor S_BEETLE0^S_BEETLE1 : ld (ix+EN_GLYPH),a
            jp ent_dirty

; =====================================================================
; Bosses: the Bone Colossus and the Hollow King are set pieces of PCG
; tiles; the sword (or a fire bolt) hits their cells.
; =====================================================================
boss_setup: xor a : ld (boss_on),a
            ld ix,(RI_OBJS)
.o:         ld a,(ix+OB_KIND) : or a : ret z
            cp O_COLOSSUS : jr z,.b
            cp O_KING : jr nz,.nx
.b:         ld a,(ix+OB_BIT) : call bit_test : jr nz,.nx
            ld (boss_obj),ix
            ld a,(ix+OB_A1) : ld (boss_hp),a
            ld a,1 : ld (boss_on),a
            ld a,90 : ld (boss_t),a
            xor a : ld (boss_inv),a : ld (boss_n),a
            ret
.nx:        ld de,10 : add ix,de
            jr .o

; HL = cell struck, B = damage
boss_hit:   ld a,(boss_on) : or a : ret z
            ld a,(boss_inv) : or a : ret nz
            ld a,14 : ld (boss_inv),a
            push hl
            ld a,(boss_hp) : sub b : ld (boss_hp),a
            jr z,.dead
            jr c,.dead
            ld a,SFX_HIT : call sfx
            pop hl
            ; sparks fly from the stone
            ld de,STRIDE : add hl,de
            ld a,(hl) : and (1<<F_SOLID) : ret nz
            ld a,T_SPARK : ld c,C_WHT : ld d,S_FX_SPARK
            jp spawn_fx
.dead:      pop hl
            xor a : ld (boss_on),a
            ld ix,(boss_obj)
            ld a,(ix+OB_BIT) : call bit_set
            call obj_open
            ld a,SFX_BOOM : call sfx
            ld hl,msg_colossus
            ld a,(ix+OB_KIND) : cp O_KING : jr nz,.m
            ld hl,msg_king
.m:         call message
            ; dust where it stood
            ld b,(ix+OB_X) : ld c,(ix+OB_Y)
            ld a,(ix+OB_H) : add a,c : dec a : ld c,a
            ld a,(ix+OB_W) : ld e,a
.d:         push bc : push de
            call xy_cell
            ld a,T_DUST : ld c,C_GRY : ld d,S_FX_DUST0
            call spawn_fx
            pop de : pop bc
            inc b : dec e : jr nz,.d
            ld ix,ENTS+16
            ld (ix+EN_GLYPH),S_P_CHEER
            call ent_dirty
            ld a,90 : ld (cele_timer),a
            ret

boss_update:
            ld a,(boss_on) : or a : ret z
            ld a,(boss_inv) : or a : jr z,.t
            call tick_down : ld (boss_inv),a
.t:         ld a,(boss_t) : call tick_down : ld (boss_t),a
            ret nz
            ld ix,(boss_obj)
            ld a,85 : ld (boss_t),a
            ld a,(ix+OB_KIND) : cp O_KING : jr nz,.k
            ld a,60 : ld (boss_t),a
.k:         ; the cell below the middle of the boss
            ld a,(ix+OB_W) : srl a : add a,(ix+OB_X) : ld b,a
            ld a,(ix+OB_H) : add a,(ix+OB_Y) : ld c,a
            ld (boss_xy),bc
            ; is the bearer near enough to notice?
            ld a,(ENTS+16+EN_X) : sub b : call abs_a : cp 34 : ret nc
            ld a,(ENTS+16+EN_Y) : sub c : call abs_a : cp 14 : ret nc
            ld hl,boss_n : inc (hl)
            ld a,(hl) : and 3 : jr nz,.bolt
            ; every fourth time: a servant rises
            ld a,SFX_ROAR : call sfx
            ld ix,(boss_obj)
            ld a,(ix+OB_X) : dec a : ld b,a
            ld a,(ix+OB_Y) : add a,(ix+OB_H) : dec a : ld c,a
            ld a,(ix+OB_KIND) : cp O_KING
            ld a,T_SKEL : jr nz,.sm
            ld a,T_SHADE
.sm:        push af
            call spawn_foe
            pop af
            ld ix,(boss_obj)
            ld b,a
            ld a,(ix+OB_X) : add a,(ix+OB_W) : ld c,a
            ld a,b
            ld b,c
            ld c,(ix+OB_Y) : push af : ld a,(ix+OB_H) : add a,c : dec a : ld c,a : pop af
            jp spawn_foe
.bolt:      ; a bolt of unlight toward the bearer
            ld bc,(boss_xy) : call xy_cell
            ld a,(hl) : and (1<<F_SOLID) : ret nz
            push hl
            call ent_at
            pop hl
            or a : ret nz
            push hl
            call ent_alloc
            pop hl
            ret c
            ld (ix+EN_TYPE),T_EBOLT
            ld (ix+EN_BANK),SPRITE_BANK
            ld (ix+EN_GLYPH),S_EBOLT0
            ld (ix+EN_COL),C_BMAG
            ld (ix+EN_TIMER),3
            ld bc,(boss_xy)
            ld (ix+EN_X),b : ld (ix+EN_Y),c
            push hl
            call to_player : call toward
            pop hl
            ld (ix+EN_DIR),a
            ld a,(ent_num)
            call ent_place
            ld a,SFX_ZAP : jp sfx
boss_on:    DB 0
boss_obj:   DW 0
boss_hp:    DB 0
boss_t:     DB 0
boss_inv:   DB 0
boss_n:     DB 0
boss_xy:    DW 0

; =====================================================================
; The ending: the Heart is rekindled
; =====================================================================
ending_start:
            call music_stop
            ld hl,MUS_END_A : ld de,MUS_END_B : ld a,1 : call music_start
            ld a,SFX_JINGLE : call sfx
            ld hl,msg_rekindle : call message
            ld hl,SPEECH_END : ld de,SPEECH_END_LEN : ld a,SPEECH_END_BLK : call speak
            ld a,250 : ld (msg_timer),a
            ; the Heart's light floods the hall in a wave
            ld hl,FLAGS+STRIDE+1
            ld c,0
.r:         ld b,0
.c:         res F_REVEAL,(hl)
            ld a,b : sub 67 : call abs_a : srl a : ld e,a
            ld a,c : sub 9 : call abs_a : add a,e
            srl a : srl a
            ld e,a : ld a,7 : sub e : jr c,.lo
            cp 2 : jr nc,.ok
.lo:        ld a,2
.ok:        or $40|(3<<3)                   ; zone 1, fire-gold light
            push hl
            ld e,a : ld a,h : add a,D_STAT : ld h,a : ld (hl),e
            pop hl
            inc hl
            inc b : ld a,b : cp 80 : jr nz,.c
            ld de,STRIDE-80 : add hl,de
            inc c : ld a,c : cp PLAY_ROWS : jr nz,.r
            ld a,1 : ld (sw_new),a : ld (sw_on),a
            xor a : ld (sw_old),a
            ld a,67 : ld (sw_lo),a : ld (sw_hi),a
            ld a,1 : ld (end_t),a
            ld ix,ENTS+16
            ld (ix+EN_GLYPH),S_P_CHEER
            jp ent_dirty

ending_tick:
            call zone_update
            call render_dirty
            call hud_update
            ld hl,end_t : ld a,(dt) : add a,(hl) : ld (hl),a
            jr nc,.w
            ld (hl),255
.w:         ld a,(hl) : cp 255 : jp c,game_loop
            ld a,(cur_room) : call seen_save
            xor a : ld (in_room),a
            ld hl,page_end : jp text_page
end_t:      DB 0

; ---- ambient: dust motes in the torch beam, glints over water,
;      embers above fire, water dripping in the dark
ambient_spawn:
            ld a,(drip_t) : call tick_down : ld (drip_t),a
            jr nz,.nd
            call rnd : and 127 : add a,90 : ld (drip_t),a
            ld a,(RI_AMB) : or a : jr z,.nd
            ld a,(sfx_ptr+1) : or a : jr nz,.nd
            ld a,SFX_PLINK : call sfx
.nd:        ld a,(amb_t) : call tick_down : ld (amb_t),a
            ret nz
            call rnd : and 15 : add a,12 : ld (amb_t),a
            ld a,(mote_count) : cp 5 : ret nc
            call rnd : and 3
            jr z,.pool
            dec a : jr z,.ember
            ; a dust mote somewhere in the torch light
            ld hl,(lst_prev_end) : ld de,(lst_prev)
            or a : sbc hl,de
            ret z
            srl h : rr l
            call rnd_mod_hl
            add hl,hl : add hl,de
            ld e,(hl) : inc hl : ld d,(hl)
            ld a,(de) : and 7 : cp 3 : ret c
            ex de,hl
            ld a,h : sub D_LIGHT : ld h,a
            bit F_SOLID,(hl) : ret nz
            ld c,C_BYEL : ld a,T_MOTE
            jr .spawn
.pool:      ld hl,(RI_NWATER) : ld a,h : or l : ret z
            call rnd_mod_hl
            add hl,hl : ld de,(RI_WATER) : add hl,de
            ld e,(hl) : inc hl : ld d,(hl) : ex de,hl
            ld c,C_BCYN : ld a,T_MOTE
            jr .spawn
.ember:     ld hl,(RI_NFIRE) : ld a,h : or l : ret z
            call rnd_mod_hl
            add hl,hl : ld de,(RI_FIRE) : add hl,de
            ld e,(hl) : inc hl : ld d,(hl) : ex de,hl
            ld de,-STRIDE : add hl,de
            ld c,C_BYEL : ld a,T_EMBER
.spawn:     ld d,S_FX_MOTE
            push hl : push af : push bc : push de
            call spawn_fx
            pop de : pop bc : pop af : pop hl
            push af
            call ent_at
            ld b,a
            pop af
            ld c,a
            ld a,b : or a : ret z
            ld a,(iy+EN_TYPE) : cp c : ret nz
            ld a,(iy+EN_STATE) : or a : ret nz   ; already alive
            call rnd : and 63 : add a,70 : ld (iy+EN_STATE),a
            ld (iy+EN_TIMER),8
            ld hl,mote_count : inc (hl)
            ret
amb_t:      DB 20
drip_t:     DB 100
mote_count: DB 0

; =====================================================================
; Zones: a zone's own lights are revealed in a wave spreading out from
; where you stand as you enter it, column by column
; =====================================================================
zone_update:
            ld hl,(player_cell)
            ld a,h : add a,D_STAT : ld h,a
            ld a,(hl) : rlca : rlca : and 3
            ld hl,cur_zone
            cp (hl) : jr z,.sweep
            ld b,(hl) : ld (hl),a
            ld (sw_new),a
            ld a,b : ld (sw_old),a
            ld a,(ENTS+16+EN_X) : ld (sw_lo),a : ld (sw_hi),a
            ld a,1 : ld (sw_on),a : ld (hud_dirty),a
            ; first time in the Drowned Hall: a voice from the dark
            ld a,(cur_room) : or a : jr nz,.sweep
            ld a,(cur_zone) : cp 2 : jr nz,.sweep
            ld a,(hall_spoken) : or a : jr nz,.sweep
            inc a : ld (hall_spoken),a
            ld a,(demo_on) : or a : jr nz,.sweep
            ld hl,SPEECH_HALL : ld de,SPEECH_HALL_LEN : ld a,SPEECH_HALL_BLK : call speak
.sweep:     ld a,(sw_on) : or a : ret z
            ld b,2
.st:        push bc
            ld a,(sw_lo) : bit 7,a : call z,sweep_col
            ld a,(sw_hi) : cp 80 : jr nc,.s1
            ld hl,sw_lo : cp (hl) : call nz,sweep_col
.s1:        ld hl,sw_lo : dec (hl)
            ld hl,sw_hi : inc (hl)
            pop bc
            djnz .st
            ld a,(sw_lo) : bit 7,a : ret z
            ld a,(sw_hi) : cp 80 : ret c
            xor a : ld (sw_on),a
            ret
; A = column
sweep_col:  ld b,a : ld c,0
            call xy_cell
            ld b,PLAY_ROWS
.c:         push bc
            ld a,h : add a,D_STAT : ld d,a : ld e,l
            ld a,(de) : ld c,a
            and 7 : jr z,.n
            ld a,c : rlca : rlca : and 3 : ld c,a
            ld a,(sw_new) : cp c : jr nz,.old
            bit F_REVEAL,(hl) : jr nz,.n
            set F_REVEAL,(hl)
            call mark_dirty
            jr .n
.old:       ld a,(sw_old) : cp c : jr nz,.n
            bit F_REVEAL,(hl) : jr z,.n
            res F_REVEAL,(hl)
            call mark_dirty
.n:         ld de,STRIDE : add hl,de
            pop bc
            djnz .c
            ret
cur_zone:   DB 0
hall_spoken: DB 0
sw_on:      DB 0
sw_new:     DB 0
sw_old:     DB 0
sw_lo:      DB 0
sw_hi:      DB 0

; rune stones pulse
cycle_update:
            ld a,(cyc_t) : call tick_down : ld (cyc_t),a
            ret nz
            ld a,6 : ld (cyc_t),a
            ld hl,cyc_phase : inc (hl)
            ld hl,(RI_CYCLERS)
.c:         ld e,(hl) : inc hl : ld d,(hl) : inc hl
            ld a,d : or e : ret z
            ex de,hl : call mark_dirty : ex de,hl
            jr .c
cyc_t:      DB 6

flicker_update:
            ld a,(fl_t) : call tick_down : ld (fl_t),a
            ret nz
            call rnd : and 7 : add a,3 : ld (fl_t),a
            ld a,(flick_on) : xor 1 : ld (flick_on),a
            jp flicker_redraw
fl_t:       DB 4

; =====================================================================
; The journal (M): this region's map of the rooms you have visited,
; what you carry, and how you fare
; =====================================================================
JB_W        EQU 17
journal:    ld a,(demo_on) : or a : ret nz
            call blank_play
            ld hl,1*80 : ld de,t_journal : ld c,C_BYEL : call print_centre
            ld a,(cur_region) : add a,a : ld e,a : ld d,0
            ld hl,REGION_NAMES : add hl,de
            ld e,(hl) : inc hl : ld d,(hl)
            ld hl,2*80 : ld c,C_GRY : call print_centre
            ; the rooms
            ld a,(cur_region) : add a,a : ld e,a : ld d,0
            ld hl,MAP_TAB : add hl,de
            ld a,(hl) : inc hl : ld h,(hl) : ld l,a
.room:      ld a,(hl) : cp $FF : jp z,.items
            push hl
            ld e,a : ld d,0
            push hl : ld hl,visited : add hl,de : ld a,(hl) : pop hl
            or a : jp z,.next
            ld (jr_room),a
            ld a,e : ld (jr_room),a
            inc hl : ld a,(hl) : ld (jr_gx),a
            inc hl : ld a,(hl) : ld (jr_gy),a
            inc hl : ld a,(hl) : ld (jr_fl),a
            inc hl : ld e,(hl) : inc hl : ld d,(hl)
            ld (jr_name),de
            ; box origin: column 4+19*gx, row 5+5*gy
            ld a,(jr_gx) : ld b,a : add a,a : add a,a : add a,a : add a,b : add a,a : add a,b   ; *19
            add a,4 : ld (jr_col),a
            ld a,(jr_gy) : ld b,a : add a,a : add a,a : add a,b : add a,5 : ld (jr_row),a
            ; colours: the room you stand in glows
            ld c,C_WHT|(C_BLU<<4)
            ld a,(jr_room) : ld b,a : ld a,(cur_room) : cp b : jr nz,.c1
            ld c,C_BLK|(C_BYEL<<4)
.c1:        ld a,c : ld (jr_colr),a
            ld b,3
.br:        push bc
            ; edges drawn as ruled lines (a monochrome monitor shows no
            ; background colour), the middle row blank
            ld a,b : cp 2 : ld a,$80 : jr z,.bg
            ld a,G_RULE
.bg:        ld (jr_gl),a
            ld a,(jr_row) : add a,3 : sub b : call j_rowcol
            ld b,JB_W
.bc:        push bc
            ld a,(jr_colr) : ld c,a : ld a,(jr_gl) : ld b,FONT_BANK : call put_glyph
            pop bc
            djnz .bc
            pop bc
            djnz .br
            ; the room you stand in: a flame either side
            ld a,(jr_room) : ld b,a : ld a,(cur_room) : cp b : jr nz,.nf
            ld a,(jr_row) : inc a : call j_rowcol
            inc hl
            ld a,(jr_colr) : ld c,a : ld a,G_FLAME : ld b,FONT_BANK : call put_glyph
            ld de,JB_W-4 : add hl,de
            ld a,G_FLAME : call put_glyph
.nf:
            ; the name, centred in the middle row
            ld de,(jr_name)
            push de : ld b,0
.ln:        ld a,(de) : or a : jr z,.lnd
            inc b : inc de : jr .ln
.lnd:       pop de
            ld a,JB_W : sub b : srl a : ld b,a
            ld a,(jr_row) : inc a : call j_rowcol
            ld a,l : add a,b : ld l,a : jr nc,.n1
            inc h
.n1:        ld a,(jr_colr) : ld c,a
            call print
            ; a passage east
            ld a,(jr_fl) : bit 0,a : jr z,.ns
            ld a,(jr_row) : inc a : call j_rowcol
            ld de,JB_W : add hl,de
            ld b,2
.e:         push bc : ld a,'-'-$20+$80 : ld c,C_GRY : ld b,FONT_BANK : call put_glyph : pop bc
            djnz .e
.ns:        ld a,(jr_fl) : bit 1,a : jr z,.next
            ld b,2
.s:         push bc
            ld a,(jr_row) : add a,4 : sub b : inc a : call j_rowcol
            ld de,JB_W/2 : add hl,de
            ld a,':'-$20+$80 : ld c,C_GRY : ld b,FONT_BANK : call put_glyph
            pop bc
            djnz .s
.next:      pop hl
            ld de,6 : add hl,de
            jp .room
.items:     ; what the bearer carries
            ld hl,19*80+4 : ld de,t_carry : ld c,C_GRY : call print
            inc hl : inc hl
            ld b,IT_KEY : ld de,t_it1 : call j_item
            ld b,IT_LANTERN : ld de,t_it2 : call j_item
            ld b,IT_BLADE : ld de,t_it3 : call j_item
            ld b,IT_RING : ld de,t_it4 : call j_item
            call j_hint
            ld hl,21*80 : ld de,t_anykey : ld c,C_DGR : call print_centre
            ; wait for the key to be let go, then any key
.w1:        call j_frame : ld a,(input) : or a : jr nz,.w1
            ld a,1 : out (P_ROMLAT),a : ld a,13 : call keytest : ld b,a : xor a : out (P_ROMLAT),a
            ld a,b : or a : jr nz,.w1
.w2:        call j_frame
            call j_savekey
            ld a,1 : out (P_ROMLAT),a : ld a,13 : call keytest : ld b,a : xor a : out (P_ROMLAT),a
            ld a,(input) : or b : jr z,.w2
.w3:        call j_frame : ld a,(input) : or a : jr nz,.w3
            ld a,(input) : ld (prev_input),a
            ; the room again
            call blank_play
            ld hl,SHCHR : ld bc,$0C00 : ld e,$80 : call fill
            ld hl,SHCOL : ld bc,$0C00 : ld e,0 : call fill
            ld hl,SHKEY : ld bc,$0C00 : ld e,KEY_BLACK : call fill
            call draw_seen
            ld ix,ENTS+16
            ld b,MAX_ENT
.en:        push bc
            ld a,(ix+EN_TYPE) : or a : call nz,ent_dirty
            ld de,16 : add ix,de
            pop bc
            djnz .en
            ld a,1 : ld (need_relight),a : ld (hud_dirty),a
            ld hl,(frames) : ld (last_frames),hl
            ret
; one idle frame: the music plays on
j_frame:    call wait_frame
            ld a,1 : ld (dt),a
            call snd_update
            jp read_input
; A = row -> HL = screen offset of (row, jr_col)
j_rowcol:   push bc : push de
            ld l,a : call row_off
            ld a,(jr_col) : add a,l : ld l,a : jr nc,.r
            inc h
.r:         pop de : pop bc
            ret
; B = item, DE = name, HL = screen position: print it if carried
j_item:     push hl
            ld a,b : call have_item
            pop hl
            ret z
            ld c,C_BYEL
            call print
            inc hl : inc hl : inc hl
            ret
jr_room:    DB 0
jr_gx:      DB 0
jr_gy:      DB 0
jr_fl:      DB 0
jr_col:     DB 0
jr_row:     DB 0
jr_colr:    DB 0
jr_gl:      DB 0
jr_name:    DW 0
t_journal:  DB "JOURNAL OF THE LAST FLAME",0
t_carry:    DB "YOU CARRY:",0
t_it1:      DB "IRON KEY",0
t_it2:      DB "GLIMMER LANTERN",0
t_it3:      DB "MOONSILVER BLADE",0
t_it4:      DB "EMBER RING",0

; =====================================================================
; Random numbers (xorshift)
; =====================================================================
rnd:        push hl : push de
            ld hl,(seed)
            ld a,h : rra : ld a,l : rra : xor h : ld h,a
            ld a,l : rra : ld a,h : rra : xor l : ld l,a
            xor h : ld h,a
            ld (seed),hl
            ld a,l
            pop de : pop hl
            ret
seed:       DW $7A3D

; HL = n (1..65535) -> HL = random 0..n-1
rnd_mod_hl: push de : push bc
            call rnd : ld c,a               ; (rnd * n) >> 8
            ex de,hl
            ld hl,0 : xor a
            ld b,8
.m:         add hl,hl : rla
            sla c : jr nc,.n
            add hl,de : adc a,0
.n:         djnz .m
            ld l,h : ld h,a
            pop bc : pop de
            ret

; =====================================================================
; Status bar and messages (rows 22-23, drawn straight into video RAM)
; =====================================================================
; HL = screen offset, A = glyph, C = colour, B = PCG bank
put_glyph:  push hl : push af
            ld a,h : or $F0 : ld h,a
            ld a,LV_SCREEN : out (P_LV),a
            pop af : ld (hl),a : push af
            ld a,LV_ATTR : out (P_LV),a
            ld (hl),b
            ld a,LV_SCREEN : out (P_LV),a
            ld a,h : or $08 : ld h,a
            ld a,COL_ON : out (P_COLCTL),a
            ld (hl),c
            xor a : out (P_COLCTL),a
            pop af : pop hl
            inc hl
            ret

; HL = screen offset, DE = text (0 ends), C = colour
print:      ld a,(de) : or a : ret z
            inc de
            sub $20 : or $80
            ld b,FONT_BANK
            call put_glyph
            jr print

hud_draw:   ld hl,22*80
            ld b,80
.r:         push bc
            ld a,G_RULE : ld c,C_DGR : ld b,FONT_BANK
            call put_glyph
            pop bc
            djnz .r
            ld hl,22*80+40 : ld a,G_RULE_X : ld c,C_YEL : ld b,FONT_BANK : call put_glyph
            ld hl,22*80+1 : ld a,G_RULE_X : ld c,C_YEL : ld b,FONT_BANK : call put_glyph
            ld hl,22*80+78 : ld a,G_RULE_X : ld c,C_YEL : ld b,FONT_BANK : call put_glyph
            ld a,1 : ld (hud_dirty),a
            ret

hud_update: ld a,(msg_timer) : or a : jr z,.nm
            call tick_down : ld (msg_timer),a
            jr nz,.nm
            ld a,1 : ld (hud_dirty),a
.nm:        ld a,(hud_dirty) : or a : ret z
            xor a : ld (hud_dirty),a
            ld hl,23*80
            ld b,80
.c:         push bc : ld a,$80 : ld c,0 : ld b,FONT_BANK : call put_glyph : pop bc
            djnz .c
            ; a message takes the whole line
            ld a,(msg_timer) : or a : jr z,.hud
            ld de,(msg_ptr)
            ld hl,23*80 : ld c,C_BYEL
            jp print_centre
.hud:       ; hearts
            ld hl,23*80+1
            ld a,(hp_max) : ld b,a
            ld a,(hp) : ld e,a
            ld d,0
.h:         push bc
            ld a,d : cp e
            ld a,G_HEART : ld c,C_BRED
            jr c,.h1
            ld a,G_HEART_E : ld c,C_RED
.h1:        ld b,FONT_BANK : call put_glyph
            inc d
            pop bc
            djnz .h
            ; magic orbs
            ld hl,23*80+10
            ld a,(mp) : ld e,a
            ld d,0 : ld b,5
.o:         push bc
            ld a,d : cp e
            ld a,G_ORB : ld c,C_BCYN
            jr c,.o1
            ld a,G_ORB_E : ld c,C_BLU
.o1:        ld b,FONT_BANK : call put_glyph
            inc d
            pop bc
            djnz .o
            ; the blade and the spell
            ld c,C_WHT
            ld a,(items) : bit IT_BLADE,a : jr z,.sw
            ld c,C_BCYN
.sw:        ld hl,23*80+16 : ld a,G_SWORD : ld b,FONT_BANK : call put_glyph
            ld hl,23*80+18 : ld a,G_FLAME : ld c,C_BYEL : ld b,FONT_BANK : call put_glyph
            ; what the bearer carries
            ld hl,23*80+21
            ld a,(items) : ld e,a
            bit IT_KEY,e : jr z,.i1
            ld a,G_IT_KEY : ld c,C_GRY : ld b,FONT_BANK : call put_glyph
.i1:        bit IT_LANTERN,e : jr z,.i2
            ld a,G_IT_LANTERN : ld c,C_BYEL : ld b,FONT_BANK : call put_glyph
.i2:        bit IT_RING,e : jr z,.i3
            ld a,G_IT_RING : ld c,C_BRED : ld b,FONT_BANK : call put_glyph
.i3:        call hud_lives
            ; gold
            ld hl,23*80+74 : ld a,G_GEM : ld c,C_BYEL : ld b,FONT_BANK : call put_glyph
            ld hl,(gold) : call num3
            ld hl,23*80+76 : ld de,numbuf : ld c,C_YEL : call print
            ; the name of this place, centred in columns 26..72
            ld hl,(RI_NAME1)
            ld a,(cur_zone) : cp 2 : jr nz,.an
            ld hl,(RI_NAME2)
.an:        ex de,hl
            push de
            ld b,0
.ln:        ld a,(de) : or a : jr z,.lnd
            inc b : inc de : jr .ln
.lnd:       pop de
            ld a,46 : sub b : srl a : add a,26
            ld l,a : ld h,0 : ld bc,23*80 : add hl,bc
            ld c,C_GRY
            jp print

; HL = number -> numbuf, 3 digits
num3:       ld de,numbuf
            ld bc,-100 : call .d
            ld bc,-10 : call .d
            ld bc,-1 : call .d
            xor a : ld (de),a
            ret
.d:         ld a,'0'-1
.l:         inc a : add hl,bc : jr c,.l
            sbc hl,bc
            ld (de),a : inc de
            ret
numbuf:     DS 4

; HL = message text: shown for about four seconds
message:    ld (msg_ptr),hl
            ld a,200 : ld (msg_timer),a
            ld a,1 : ld (hud_dirty),a
            ret
msg_ptr:    DW 0
msg_timer:  DB 0
hud_dirty:  DB 1
hp:         DB 5
hp_max:     DB 5
mp:         DB 5
gold:       DW 0
fire_ent:   DB 0
items:      DB 0
ck_valid:   DB 0
ck_room:    DB 0
ck_xy:      DW 0
ck_dir:     DB 0
room_bits:  DS 4*N_ROOMS
visited:    DS N_ROOMS

REG_MUSIC:  DW MUS_HALL_A,0, MUS_OSS_A,0, MUS_CAV_A,0
            DW MUS_EMB_A,0, MUS_HRT_A,0

msg_crystal: DB "THE CRYSTAL HUMS. YOUR MAGIC RETURNS.",0
msg_nomana: DB "YOUR MAGIC IS SPENT.",0
msg_dead:   DB "THE DARKNESS TAKES YOU...",0
msg_burn:   DB "THE STONE BURNS! YOU NEED PROTECTION FROM FIRE.",0
msg_locked: DB "AN IRON GATE. IT IS LOCKED.",0
msg_unlock: DB "THE IRON KEY TURNS. THE GATE GROANS OPEN.",0
msg_cracked: DB "THE WALL IS COLD AND CRACKED.",0
msg_secret: DB "THE GLIMMER FINDS A HIDDEN WAY. THE WALL CRUMBLES!",0
msg_barrier: DB "THE CRYSTAL SINGS. YOUR BLADE CANNOT CUT IT.",0
msg_cut:    DB "MOONSILVER CUTS THE SINGING STONE!",0
msg_guarded: DB "SOMETHING VAST GUARDS IT.",0
msg_cold:   DB "THE HEART IS COLD. HE IS WATCHING YOU.",0
msg_colossus: DB "THE BONE COLOSSUS CRUMBLES TO DUST!",0
msg_king:   DB "THE HOLLOW KING FALLS. THE HEART AWAITS.",0
msg_rekindle: DB "THE HEART OF THE DEEP BURNS AGAIN!",0
