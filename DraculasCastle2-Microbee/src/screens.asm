; ===========================================================================
;  screens.asm - automap, status/items, pause menu, save/load, cutscenes
; ===========================================================================

; ---------------------------------------------------------------------------
; AUTOMAP: 16x16 cells, 4x4 px each, left 64x64; legend on the right
; ---------------------------------------------------------------------------
map_screen:
            ld hl,sfx_select
            call play_sfx
            xor a
            ld (map_blink),a
.draw:      ld a,$AA
            call cls_back
            ld b,0                  ; y
.row:       ld c,0                  ; x
.cell:      push bc
            call map_cell_byte      ; A = byte pattern, E = row-variant
            ld (mc_pat),a
            ; draw 4 rows at (x byte = c, y = b*4)
            ld a,b
            add a,a
            add a,a
            ld d,a
            call back_addr
            ld a,(mc_pat2)          ; rows 0 and 3 = edge, rows 1-2 = middle
            ld de,32
            ld (hl),a
            add hl,de
            ld a,(mc_pat)
            ld (hl),a
            add hl,de
            ld (hl),a
            add hl,de
            ld a,(mc_pat2)
            ld (hl),a
            pop bc
            inc c
            ld a,c
            cp 16
            jr nz,.cell
            inc b
            ld a,b
            cp 16
            jr nz,.row
            ; legend
            ld b,1
            ld c,2
            call text_colors
            ld hl,(area_name)
            ld d,2
            ld b,16
            ld c,16
            call print_centre
            ld hl,map_legend
            ld c,17
            ld d,10
            call print_at
            call map_icons
            xor a                   ; the map always uses colour set 0
            call set_css
            call draw_player_arrow
            ld a,3
            ld (world_screen),a
            call present_full
.wait:      call wait_frame
            call read_input
            ; blink player marker
            ld hl,map_blink
            inc (hl)
            ld a,(hl)
            and 15
            jr nz,.nb
            call draw_player_arrow
            ld c,0
            ld b,16
            ld d,0
            ld e,64
            call present_rect
.nb:        ld a,(keys_new)
            and K_MAP|K_FIRE|K_MENU|K_ITEM
            jr z,.wait
            jp draw_explore_screen

map_legend: db 2,1,"  YOU",1,1
            db "  DOOR",1,1
            db "  WALL",1,1
            db "  OBJECT",1,1
            db "M: BACK",0

; legend icons: the same 4x4 cells the map uses, at byte column 17
map_icons:  ld hl,map_icon_tab
            ld d,11
            ld b,4
.i:         push bc
            push de
            push hl
            ld c,17
            call back_addr
            pop de
            ld b,4
.r:         ld a,(de)
            ld (hl),a
            inc de
            push de
            ld de,32
            add hl,de
            pop de
            djnz .r
            ex de,hl
            pop de
            ld a,d
            add a,12
            ld d,a
            pop bc
            djnz .i
            ret
map_icon_tab:
            db $04,$55,$55,$04      ; you (facing east)
            db $55,$55,$55,$55      ; door
            db $FF,$FF,$FF,$FF      ; wall
            db $00,$3C,$3C,$00      ; object

; map_cell_byte: C=x B=y -> A = top rows byte, mc_pat2 = bottom row byte
map_cell_byte:
            push bc
            call seen_addr
            and (hl)
            pop bc
            jr nz,.seen
            ld a,$AA
            ld (mc_pat2),a
            ret
.seen:      push bc
            call get_cell
            pop bc
            ld e,a
            and 7
            jr z,.floor
            cp 3
            jr z,.door
            cp 5
            jr z,.door
            ; wall / secret
            ld a,$FF
            ld (mc_pat2),a
            ret
.door:      ld a,$55                ; solid yellow
            ld (mc_pat2),a
            ret
.floor:     ld a,e
            rrca
            rrca
            rrca
            and $1F
            jr z,.plain
            push bc
            push ix
            call event_sprite
            pop ix
            pop bc
            or a
            jr z,.plain
            xor a                   ; object: red dot on green floor
            ld (mc_pat2),a
            ld a,$3C
            ret
.plain:     xor a                   ; floor: solid green
            ld (mc_pat2),a
            ret

draw_player_arrow:
            ld a,(px)
            ld c,a
            ld a,(py)
            add a,a
            add a,a
            ld d,a
            call back_addr
            ld a,(map_blink)
            and 16
            jr z,.on
            xor a                   ; blink off = floor
            ld (hl),a
            ld de,32
            add hl,de
            ld (hl),a
            add hl,de
            ld (hl),a
            add hl,de
            ld (hl),a
            ret
.on:        ld a,(pdir)
            add a,a
            add a,a
            ld e,a
            ld d,0
            push hl
            ld hl,arrows
            add hl,de
            ex de,hl
            pop hl
            ld b,4
.r:         ld a,(de)
            ld (hl),a
            inc de
            push de
            ld de,32
            add hl,de
            pop de
            djnz .r
            ret
; 4x4 arrows (yellow on green floor) per direction N E S W
arrows:     db $14,$55,$14,$14
            db $04,$55,$55,$04
            db $14,$14,$55,$14
            db $10,$55,$55,$10

; ---------------------------------------------------------------------------
; STATUS / ITEMS
; ---------------------------------------------------------------------------
status_screen:
            ld hl,sfx_select
            call play_sfx
.draw:      ld a,$AA
            call cls_back
            ld b,3
            ld c,2
            call text_colors
            ld hl,str_status
            ld d,1
            ld b,0
            ld c,32
            call print_centre
            ld b,1
            ld c,2
            call text_colors
            ; stats block
            ld de,msgbuf
            ld hl,str_lv
            call strcpy_de
            ld a,(lvl)
            ld l,a
            ld h,0
            call num3_left
            ld hl,str_xpn
            call strcpy_de
            ld hl,(xp)
            call num3_left
            ld hl,msgbuf
            ld c,1
            ld d,9
            call print_at
            ld de,msgbuf
            ld hl,str_atk
            call strcpy_de
            ld a,(atk)
            ld l,a
            ld h,0
            call num3_left
            ld hl,str_defn
            call strcpy_de
            ld a,(def)
            ld l,a
            ld h,0
            call num3_left
            ld hl,msgbuf
            ld c,1
            ld d,15
            call print_at
            call draw_stats_status
            ; items
            ld b,3
            ld c,2
            call text_colors
            ld hl,str_itemsh
            ld c,1
            ld d,29
            call print_at
            ld b,1
            ld c,2
            call text_colors
            ld d,35
            ld e,1                  ; item id
.it:        push de
            ld hl,items
            ld d,0
            add hl,de
            ld a,(hl)
            pop de
            or a
            jr z,.skip
            push de
            push af
            ld a,e
            add a,a
            ld l,a
            ld h,0
            ld bc,item_names
            add hl,bc
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld de,msgbuf
            call strcpy_de
            ld a,' '
            ld (de),a
            inc de
            ld a,'X'
            ld (de),a
            inc de
            pop af
            ld l,a
            ld h,0
            call num3_left
            pop de
            push de
            ld hl,msgbuf
            ld c,2
            call print_at
            pop de
            ld a,d
            add a,6
            ld d,a
.skip:      inc e
            ld a,e
            cp 6
            jr nz,.it
            ; spells
            ld a,(spells)
            and 1
            jr z,.nosp
            ld b,3
            ld c,2
            call text_colors
            ld hl,str_spellfire
            ld c,17
            ld d,29
            call print_at
.nosp:      ld b,0
            ld c,2
            call text_colors
            ld hl,str_usepotion
            ld d,58
            ld b,0
            ld c,32
            call print_centre
            ld a,(area_css)
            call set_css
            call present_full
.wait:      call wait_frame
            call read_input
            call mb_row_F7
            cpl
            bit 4,a                 ; '1' = drink potion
            jr nz,.drink
            ld a,(keys_new)
            and K_ITEM|K_FIRE|K_MAP|K_MENU
            jr z,.wait
            jp draw_explore_screen
.drink:     ld a,(items+IT_POTION)
            or a
            jr z,.wait
            dec a
            ld (items+IT_POTION),a
            ld a,(hp)
            add a,30
            ld b,a
            ld a,(maxhp)
            cp b
            jr c,.cap
            ld a,b
.cap:       ld (hp),a
            ld hl,sfx_heal
            call play_sfx
.rel:       call wait_frame
            call mb_row_F7
            cpl
            bit 4,a
            jr nz,.rel
            jp .draw

draw_stats_status:
            ld de,statbuf
            ld a,'H'
            ld (de),a
            inc de
            ld a,'P'
            ld (de),a
            inc de
            ld a,(hp)
            ld l,a
            ld h,0
            call num3_left
            ld a,'/'
            ld (de),a
            inc de
            ld a,(maxhp)
            ld l,a
            ld h,0
            call num3_left
            ld a,' '
            ld (de),a
            inc de
            ld a,'M'
            ld (de),a
            inc de
            ld a,'P'
            ld (de),a
            inc de
            ld a,(mp)
            ld l,a
            ld h,0
            call num3_left
            ld a,'/'
            ld (de),a
            inc de
            ld a,(maxmp)
            ld l,a
            ld h,0
            call num3_left
            ld a,' '
            ld (de),a
            inc de
            ld a,'G'
            ld (de),a
            inc de
            ld hl,(gold)
            call num3_left
            ld hl,statbuf
            ld c,1
            ld d,21
            jp print_at

str_status: db "- THE HUNTER -",0
str_xpn:    db "   XP ",0
str_atk:    db "ATTACK ",0
str_defn:   db "   DEFENCE ",0
str_itemsh: db "INVENTORY",0
str_spellfire: db "SPELLS: FIRE",0
str_usepotion: db "1: DRINK POTION   E: BACK",0

; ---------------------------------------------------------------------------
; PAUSE menu
; ---------------------------------------------------------------------------
pause_screen:
            ld hl,str_paused
            call show_msg
.w:         call wait_frame
            call read_input
            call mb_pause_display
            call mb_row_BF            ; U P I RET O Y  -> P toggles off
            ld a,(keys_new)
            bit 6,a
            jr nz,.out
            bit 4,a
            jr nz,.out
            call mb_row_FE            ; row 0: Q = quit to title (bit4)
            cpl
            bit 4,a
            jp nz,title_screen
            jr .w                   ; (N is handled by read_input everywhere)
.out:       call clear_msg_back
            jp present_msg

str_paused: db " - PAUSED - P:GO -/+:SOFT/VZ",1," C:COLOUR M:MONO N:MUSIC Q:QUIT",0

; ---------------------------------------------------------------------------
; SAVE / LOAD  (SRAM bank 3 @ $6400: magic, checksum, data)
; ---------------------------------------------------------------------------
SAVE_AT     equ $6400
SAVE_MAGIC  equ $D2C3

save_game:
            call bank3
            ld hl,SAVE_MAGIC
            ld (SAVE_AT),hl
            ld hl,vars_game
            ld de,SAVE_AT+4
            ld bc,SAVE_LEN
            ldir
            ld hl,PSTATE
            ld bc,$300              ; opened + seen + flags
            ldir
            call save_sum
            ld (SAVE_AT+2),hl
            ret

save_sum:   ld hl,SAVE_AT+4
            ld bc,SAVE_LEN+$300
            ld de,0
.l:         ld a,(hl)
            add a,e
            ld e,a
            ld a,d
            adc a,0
            rlca
            ld d,a
            inc hl
            dec bc
            ld a,b
            or c
            jr nz,.l
            ex de,hl
            ret

; load_game: carry set if no valid save
load_game:
            call bank3
            ld hl,(SAVE_AT)
            ld de,SAVE_MAGIC
            or a
            sbc hl,de
            scf
            ret nz
            call save_sum
            ld de,(SAVE_AT+2)
            or a
            sbc hl,de
            scf
            ret nz
            ld hl,SAVE_AT+4
            ld de,vars_game
            ld bc,SAVE_LEN
            ldir
            ld de,PSTATE
            ld bc,$300
            ldir
            or a
            ret

continue_game:
            ld a,(chk_area)
            ld (cur_area),a
            ld a,(chk_x)
            ld (px),a
            ld a,(chk_y)
            ld (py),a
            ld a,(chk_dir)
            ld (pdir),a
            xor a
            ld (show_intro),a
            call enter_area
            ld hl,str_welcome
            call show_msg
            jp explore_loop

str_welcome: db "WELCOME BACK, HUNTER.",0

; ---------------------------------------------------------------------------
; CUTSCENES in the exploration view
;   1 = skeleton rises from the bones,  2 = gargoyle awakens
; ---------------------------------------------------------------------------
cutscene:
            or a
            ret z
            jp world_cutscene
