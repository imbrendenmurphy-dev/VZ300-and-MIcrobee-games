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
            ld a,(mc_pat)
            ld de,32
            ld (hl),a
            add hl,de
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
            ld a,(area_css)
            call set_css
            call draw_player_arrow
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

map_legend: db 2,1,"> YOU",1,1
            db 2,0,"] DOOR",1,1
            db 2,3,"] WALL",1,1
            db 2,1,"$ OBJECT",1,1
            db 2,0,"M: BACK",0

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
.door:      ld a,$00                ; green
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
            ld a,$69                ; yellow/blue speckle = object
            ld (mc_pat2),a
            ld a,$96
            ret
.plain:     ld a,$66                ; floor: blue/yellow light
            ld (mc_pat2),a
            ld a,$66
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
            ld a,$66
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
; 4x4 arrows (red on yellow) per direction N E S W
arrows:     db $7D,$FF,$7D,$7D
            db $5D,$FF,$FF,$5D
            db $7D,$7D,$FF,$7D
            db $75,$FF,$FF,$75

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
            ld a,($68F7)
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
            ld a,($68F7)
            cpl
            bit 4,a
            jr nz,.rel
            jp .draw

draw_stats_status:
            ld de,statbuf
            ld a,'@'
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
            ld a,'%'
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
            ld a,'$'
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
            ld a,($68BF)            ; U P I RET O Y  -> P toggles off
            ld a,(keys_new)
            bit 6,a
            jr nz,.out
            bit 4,a
            jr nz,.out
            ld a,($68FE)            ; row 0: Q = quit to title (bit4)
            cpl
            bit 4,a
            jp nz,title_screen
            jr .w                   ; (N is handled by read_input everywhere)
.out:       call clear_msg_back
            jp present_msg

str_paused: db " - PAUSED -     P: CONTINUE",1," N: MUSIC ON/OFF  Q: QUIT",0

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
            ld (cs_id),a
            cp 1
            jr z,cs_skeleton
            jp cs_gargoyle

cs_skeleton:
            ; bones rattle: jiggle the view of the pile
            ld b,6
.r:         push bc
            ld hl,sfx_rattle
            call play_sfx
            ld a,1
            ld (rv_jig),a
            call render_view
            call present_view
            xor a
            ld (rv_jig),a
            call render_view
            call present_view
            pop bc
            djnz .r
            ; load the skeleton and raise it out of the floor
            call render_view
            ld a,2
            call battle_load
            call save_view
            ld hl,sfx_sting
            call play_sfx
            ld a,52
.rise:      ld (cs_y),a
            call restore_view
            xor a
            call cs_draw_mon
            call present_view
            ld a,(cs_y)
            sub 4
            cp 7
            jr nc,.rise
            ; sword raised, then swings
            ld b,25
            call wait_frames
            call restore_view
            ld a,2
            call cs_draw_mon
            call present_view
            ld hl,sfx_monatk
            call play_sfx
            ld b,15
            jp wait_frames

cs_gargoyle:
            ; eyes glow: flash the colour set while the statue stares
            ld b,3
.f:         push bc
            ld a,1
            call set_css
            ld b,4
            call wait_frames
            ld a,(area_css)
            call set_css
            ld b,8
            call wait_frames
            pop bc
            djnz .f
            call render_view
            ld a,4
            call battle_load
            call save_view
            ld hl,sfx_sting
            call play_sfx
            ; leap: drops in from the top of the view
            ld a,-40
.drop:      ld (cs_y),a
            call restore_view
            ld a,2
            call cs_draw_mon
            call present_view
            ld a,(cs_y)
            add a,8
            cp 8
            jr nz,.drop
            ld hl,sfx_monatk
            call play_sfx
            ld b,20
            jp wait_frames

; keep a copy of the rendered viewport in main RAM (VCACHE, 20 bytes/row)
save_view:
            ld hl,BACK
            ld de,VCACHE
            ld b,52
.r:         push bc
            ld bc,20
            ldir
            ld bc,12
            add hl,bc
            pop bc
            djnz .r
            ret
restore_view:
            ld hl,VCACHE
            ld de,BACK
            ld b,52
.r:         push bc
            ld bc,20
            ldir
            ex de,hl
            ld bc,12
            add hl,bc
            ex de,hl
            pop bc
            djnz .r
            ret

; draw monster frame A at viewport x byte 2, y = cs_y (signed), clipped to rows 0..51
cs_draw_mon:
            ld (bt_frame),a
            ld hl,MONB
            ld de,MON_FRAME
            or a
            jr z,.f0
.fl:        add hl,de
            dec a
            jr nz,.fl
.f0:        ld a,(cs_y)
            ld (cs_row),a
            ld b,MON_H
.r:         push bc
            ld a,(cs_row)
            cp 52
            jr nc,.skip             ; also skips negative (unsigned >= 52)
            ld d,a
            ld c,2
            push hl
            call back_addr
            ex de,hl
            pop hl
            ld b,MON_W
.b:         ld a,(de)
            and (hl)
            inc hl
            or (hl)
            inc hl
            ld (de),a
            inc de
            djnz .b
            jr .nx
.skip:      ld de,MON_W*2
            add hl,de
.nx:        ld a,(cs_row)
            inc a
            ld (cs_row),a
            pop bc
            djnz .r
            ret
