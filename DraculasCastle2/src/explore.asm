; ===========================================================================
;  explore.asm - exploration mode: movement, events, doors, HUD, messages
; ===========================================================================

EV_SIGN     equ 1
EV_CHEST    equ 2
EV_NPC      equ 3
EV_SCRIPT   equ 4
EV_SHRINE   equ 5
EV_STEP     equ 6
EV_BOSS     equ 7
EV_ITEM     equ 8
EV_PLAQUE   equ 9

IT_POTION   equ 1
IT_HOLY     equ 2
IT_IRONKEY  equ 3
IT_DAGGER   equ 4
IT_FIRE     equ 5

EXPLORED    equ $7E00           ; 2 x 32 bytes seen-bits
FLAGS       equ $7E40           ; event flags (bytes)

; ---------------------------------------------------------------------------
; new game
; ---------------------------------------------------------------------------
new_game:
            ; clear game variables
            ld hl,vars_game
            ld de,vars_game+1
            ld bc,vars_end-vars_game-1
            ld (hl),0
            ldir
            ld hl,EXPLORED
            ld de,EXPLORED+1
            ld bc,$FF
            ld (hl),0
            ldir
            ld a,1
            ld (lvl),a
            ld a,30
            ld (hp),a
            ld (maxhp),a
            ld a,8
            ld (mp),a
            ld (maxmp),a
            ld a,7
            IF DEBUG
            ld a,40
            ENDIF
            ld (atk),a
            ld a,2
            ld (def),a
            ld hl,20
            ld (gold),hl
            ld a,1
            ld (items+IT_POTION),a
            ; runtime maps from compressed originals
            xor a
            call reset_map
            ld a,1
            call reset_map
            ; start
            xor a
            ld (cur_area),a
            call area_start_pos
            call set_checkpoint
            ld a,1
            ld (show_intro),a
            call enter_area
            jp explore_loop

; A = area -> decompress its map into MAPS + area*256
reset_map:
            push af
            call area_info_ptr
            ld e,(hl)
            inc hl
            ld d,(hl)
            pop af
            add a,MAPS/256
            ex de,hl
            ld d,a
            ld e,0
            jp lz_unpack

; HL = area_info entry for area A
area_info_ptr:
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            ld e,l
            ld d,h
            add hl,hl
            add hl,hl
            add hl,de               ; *20
            ld de,area_info
            add hl,de
            ret

area_start_pos:
            ld a,(cur_area)
            call area_info_ptr
            ld de,12
            add hl,de
            ld a,(hl)
            ld (px),a
            inc hl
            ld a,(hl)
            ld (py),a
            inc hl
            ld a,(hl)
            ld (pdir),a
            ret

set_checkpoint:
            ld a,(cur_area)
            ld (chk_area),a
            ld a,(px)
            ld (chk_x),a
            ld a,(py)
            ld (chk_y),a
            ld a,(pdir)
            ld (chk_dir),a
            ret

; ---------------------------------------------------------------------------
; enter_area: load assets for cur_area, set up tables, draw everything
; ---------------------------------------------------------------------------
enter_area:
            ld a,(cur_area)
            call area_info_ptr
            inc hl
            inc hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (area_events),de
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (area_exits),de
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (area_name),de
            ld a,(hl)
            inc hl
            ld (area_door_decor),a
            ld a,(hl)
            inc hl
            ld (area_door_kind),a
            ld a,(hl)
            inc hl
            ld (area_css),a
            ld a,(hl)
            inc hl
            ld (area_music),a
            inc hl
            inc hl
            inc hl
            ld a,(hl)
            inc hl
            ld (enc_rate),a
            ld de,enc_list
            ld bc,3
            ldir
            ld a,(hl)
            ld (area_intro),a
            ld a,(cur_area)
            add a,MAPS/256
            ld (map_page),a
            ; blank screen while loading
            call fade_out
            ld a,(cur_area)
            call load_area
            ld a,(area_music)
            call play_music
            call mark_seen
            call draw_explore_screen
            ld a,(show_intro)
            or a
            ret z
            xor a
            ld (show_intro),a
            ld a,(area_intro)
            jp show_text

; full redraw of the exploration screen (view, HUD, message box)
draw_explore_screen:
            ld a,(area_css)
            call set_css
            call render_view
            call draw_hud_panel
            call clear_msg_back
            jp present_full

; quick black-out (blue) of the screen
fade_out:
            ld a,$AA
            call cls_back
            jp present_full

; ---------------------------------------------------------------------------
; main exploration loop
; ---------------------------------------------------------------------------
explore_loop:
            call wait_frame
            call read_input
            call tick_time
            ld a,(keys_now)
            bit 0,a
            jr z,.noup
            ld a,(keys_new)
            bit 0,a
            jr nz,.fwd
            ld hl,rep_timer
            dec (hl)
            jr nz,.chk
.fwd:       ld a,12
            ld (rep_timer),a
            call try_forward
            jr explore_loop
.noup:      ld a,(keys_new)
            bit 2,a
            jr nz,.left
            bit 3,a
            jr nz,.right
            bit 1,a
            jr nz,.back
            bit 4,a
            jr nz,.act
            bit 5,a
            jp nz,.map
            bit 7,a
            jp nz,.status
            bit 6,a
            jp nz,.pause
.chk:       jr explore_loop
.left:      ld a,(pdir)
            dec a
            jr .turn
.right:     ld a,(pdir)
            inc a
            jr .turn
.back:      ld a,(pdir)
            add a,2
.turn:      and 3
            ld (pdir),a
            ld hl,sfx_turn
            call play_sfx
            call after_move
            jr explore_loop
.act:       call interact
            jr explore_loop
.map:       call map_screen
            jp explore_loop
.status:    call status_screen
            jp explore_loop
.pause:     call pause_screen
            jp explore_loop

tick_time:
            ld hl,play_time
            inc (hl)
            ret nz
            inc hl
            inc (hl)
            ret nz
            inc hl
            inc (hl)
            ret

; refresh after moving/turning: re-render view and HUD compass, check auto-events
after_move:
            call mark_seen
            call render_view
            call draw_compass
            call present_view
            call present_panel_top
            jp check_auto_event

; ---------------------------------------------------------------------------
; try moving forward
; ---------------------------------------------------------------------------
cell_ahead:     ; -> C,B = x,y ahead ; A = cell byte
            ld a,(pdir)
            add a,a
            ld e,a
            ld d,0
            ld hl,dir_vec
            add hl,de
            ld a,(px)
            add a,(hl)
            ld c,a
            inc hl
            ld a,(py)
            add a,(hl)
            ld b,a
            ld (ahead_x),a
            ld a,c
            ld (ahead_x),a
            ld a,b
            ld (ahead_y),a
            push bc
            call get_cell
            pop bc
            ld (ahead_cell),a
            ret

try_forward:
            call cell_ahead
            and 7
            jr z,.floor
            cp 3
            jp z,try_door
            cp 5
            jp z,try_exit
            ; wall / secret: bump
            ld hl,sfx_bump
            jp play_sfx
.floor:     ld a,(ahead_cell)
            rrca
            rrca
            rrca
            and $1F
            jr z,.go
            ; event cell: blocking unless it is a step/boss trigger without object
            call event_ptr
            ld a,(ix+0)
            or a
            jr z,.go                ; no object -> walkable
            call event_done
            jr z,.blocked
            ; done events: chests stay, others (bones/boss) vanish -> walkable
            ld a,(ix+1)
            cp EV_SCRIPT
            jr z,.go
            cp EV_BOSS
            jr z,.go
.blocked:   ld hl,sfx_bump
            jp play_sfx
.go:        ld a,(ahead_x)
            ld (px),a
            ld a,(ahead_y)
            ld (py),a
            ld hl,sfx_step
            call play_sfx
            ld hl,steps
            inc (hl)
            call after_move
            call step_event
            jp random_encounter

; event_ptr: A = event id (1..) -> IX = entry
event_ptr:
            dec a
            add a,a
            add a,a
            add a,a
            ld e,a
            ld d,0
            ld ix,(area_events)
            add ix,de
            ret

; event_done: IX = event -> Z if NOT done, NZ if done (A = flag value)
event_done:
            ld e,(ix+6)
            ld d,0
            ld hl,FLAGS
            add hl,de
            ld a,(hl)
            or a
            ret
set_event_done:
            ld e,(ix+6)
            ld d,0
            ld hl,FLAGS
            add hl,de
            ld (hl),1
            ret

; called by the renderer: A = event id -> A = object sprite id
event_sprite:
            push ix
            push hl
            push de
            call event_ptr
            ld a,(ix+0)
            or a
            jr z,.out
            call event_done
            ld a,(ix+0)
            jr z,.out
            ; done: chest -> open chest sprite (next id); script/boss -> nothing
            ld a,(ix+1)
            cp EV_CHEST
            jr nz,.gone
            ld a,(ix+0)
            inc a
            jr .out
.gone:      cp EV_NPC
            jr z,.keep
            cp EV_SIGN
            jr z,.keep
            cp EV_SHRINE
            jr z,.keep
            xor a
            jr .out
.keep:      ld a,(ix+0)
.out:       pop de
            pop hl
            pop ix
            ret

; ---------------------------------------------------------------------------
; doors & exits
; ---------------------------------------------------------------------------
try_door:
            ld a,(ahead_cell)
            rrca
            rrca
            rrca
            and $1F
            jr z,.open
            ; locked: needs item A
            ld e,a
            ld d,0
            ld hl,items
            add hl,de
            ld a,(hl)
            or a
            jr nz,.unlock
            ld a,TX_LOCKED
            jp show_text
.unlock:    ld a,TX_UNLOCK
            call show_text
.open:      ; door becomes floor
            ld a,(ahead_x)
            ld c,a
            ld a,(ahead_y)
            call cell_addr
            ld (hl),0
            ld hl,sfx_door
            call play_sfx
            ld a,TX_CREAK
            call show_text
            call render_view
            jp present_view

; HL = map address of cell (C = x, A = y)
cell_addr:
            add a,a
            add a,a
            add a,a
            add a,a
            add a,c
            ld l,a
            ld a,(map_page)
            ld h,a
            ret

try_exit:
            ld a,(ahead_cell)
            rrca
            rrca
            rrca
            and $1F
            ld l,a
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            ld de,(area_exits)
            add hl,de
            push hl
            pop ix
            ld a,(ix+6)             ; lock item
            or a
            jr z,.go
            ld e,a
            ld d,0
            ld hl,items
            add hl,de
            ld a,(hl)
            or a
            jr nz,.unl
            ld a,TX_LOCKED
            jp show_text
.unl:       ld a,(ix+7)
            or a
            jr nz,.go
            ld (ix+7),1             ; first time: announce the unlock
            push ix
            ld hl,sfx_door
            call play_sfx
            ld a,TX_UNLOCK
            call show_text_wait
            pop ix
.go:        ld a,(ix+0)
            cp 98
            jp z,chapter_end
            cp 99
            jp z,forgotten_maze
            ld (cur_area),a
            ld a,(ix+1)
            ld (px),a
            ld a,(ix+2)
            ld (py),a
            ld a,(ix+3)
            ld (pdir),a
            ld hl,sfx_door
            call play_sfx
            ; first visit intro
            ld a,(cur_area)
            ld e,a
            ld d,0
            ld hl,visited
            add hl,de
            ld a,(hl)
            or a
            ld (hl),1
            ld a,1
            jr z,.intro
            xor a
.intro:     ld (show_intro),a
            call enter_area
            jp set_checkpoint

; ---------------------------------------------------------------------------
; interact with the cell ahead (FIRE)
; ---------------------------------------------------------------------------
interact:
            call cell_ahead
            and 7
            jr z,.floor
            cp 3
            jp z,try_door
            cp 5
            jp z,try_exit
            cp 4
            jr z,.secret
            ; plain wall: flavour text
            ld a,(ahead_cell)
            and 7
            cp 1
            ld a,TX_WALL
            jr nz,.w
            ld a,(cur_area)
            or a
            ld a,TX_HEDGE
            jr z,.w
            ld a,TX_WALL
.w:         jp show_text
.secret:    ld a,(ahead_x)
            ld c,a
            ld a,(ahead_y)
            call cell_addr
            ld (hl),0
            ld hl,secrets
            inc (hl)
            ld hl,sfx_secret
            call play_sfx
            ld a,(cur_area)
            or a
            ld a,TX_HEDGEX
            jr z,.sx
            ld a,TX_SECRET
.sx:        call show_text
            call render_view
            jp present_view
.floor:     ld a,(ahead_cell)
            rrca
            rrca
            rrca
            and $1F
            ret z
            call event_ptr
            ld a,(ix+1)
            cp EV_SIGN
            jr z,ev_sign
            cp EV_CHEST
            jp z,ev_chest
            cp EV_NPC
            jp z,ev_npc
            cp EV_SHRINE
            jp z,ev_shrine
            cp EV_SCRIPT
            jp z,ev_script
            cp EV_BOSS
            jp z,ev_boss
            ret

ev_sign:    ld a,(ix+2)
            jp show_text

ev_chest:   call event_done
            ld a,TX_EMPTY
            jp nz,show_text
            call set_event_done
            ld hl,treasure
            inc (hl)
            ld hl,sfx_item
            call play_sfx
            call render_view
            call present_view
            ld a,(ix+2)
            ld b,(ix+3)
            jp give_item

ev_npc:     call event_done
            jr z,.first
            ld a,(ix+5)
            jp show_text
.first:     call set_event_done
            ld a,(ix+2)
            call show_text_wait
            ld a,(ix+3)
            ld b,(ix+4)
            jp give_item

ev_shrine:  ld a,(hp)
            ld a,(maxhp)
            ld (hp),a
            ld a,(maxmp)
            ld (mp),a
            call set_checkpoint
            ld hl,sfx_heal
            call play_sfx
            call save_game
            call draw_hud_panel
            call present_panel
            ld a,TX_SHRINE
            jp show_text

ev_script:
ev_boss:    call event_done
            jp z,start_scripted
            ld a,TX_NOTHING
            jp show_text

; auto-triggered events: scripted/boss directly ahead and not done
check_auto_event:
            call cell_ahead
            ld b,a
            and 7
            ret nz
            ld a,b
            rrca
            rrca
            rrca
            and $1F
            ret z
            call event_ptr
            ld a,(ix+1)
            cp EV_SCRIPT
            jr z,.chk
            cp EV_BOSS
            ret nz
.chk:       call event_done
            ret nz
            jp start_scripted

; step events on the current cell (none in the slice yet)
step_event:
            ret

; ---------------------------------------------------------------------------
; scripted encounter: cutscene in the view, then battle
; ---------------------------------------------------------------------------
start_scripted:
            push ix
            ld a,(ix+5)             ; text
            call show_text
            pop ix
            push ix
            ld a,(ix+3)             ; cutscene id
            call cutscene
            pop ix
            push ix
            ld a,(ix+2)             ; monster
            ld (battle_boss),a
            call battle
            pop ix
            or a
            jr nz,.notwon
            call set_event_done
            ; reward
            ld a,(ix+4)
            or a
            jr z,.redraw
            ld b,1
            push af
            call draw_explore_screen
            pop af
            ld b,1
            jp give_item
.redraw:    jp draw_explore_screen
.notwon:    jp after_battle_loss

; ---------------------------------------------------------------------------
; random encounters
; ---------------------------------------------------------------------------
random_encounter:
            ld a,(steps_safe)
            or a
            jr z,.roll
            dec a
            ld (steps_safe),a
            ret
.roll:      ld a,(enc_rate)
            IF DEBUG
            xor a
            ENDIF
            or a
            ret z
            ld b,a
            call rand_n
            or a
            ret nz
            ; pick monster from list
            ld b,3
            call rand_n
            ld e,a
            ld d,0
            ld hl,enc_list
            add hl,de
            ld a,(hl)
            ld (battle_boss),a
            xor a
            ld (battle_boss+1),a
            call battle
            or a
            jp nz,after_battle_loss
            jp draw_explore_screen

; outcome 1 = fled, 2 = died
after_battle_loss:
            cp 1
            jp z,draw_explore_screen
            ; died: back to checkpoint
            ld a,(maxhp)
            ld (hp),a
            ld a,(maxmp)
            ld (mp),a
            ld hl,(gold)
            srl h
            rr l
            ld (gold),hl
            ld a,(chk_x)
            ld (px),a
            ld a,(chk_y)
            ld (py),a
            ld a,(chk_dir)
            ld (pdir),a
            ld a,(chk_area)
            ld (cur_area),a
            xor a
            ld (show_intro),a
            call enter_area
            ld a,TX_DEFEAT
            jp show_text

; ---------------------------------------------------------------------------
; items
; ---------------------------------------------------------------------------
; give_item: A = item, B = count
give_item:
            or a
            ret z
            push af
            push bc
            ld e,a
            ld d,0
            ld hl,items
            add hl,de
            ld a,(hl)
            add a,b
            ld (hl),a
            pop bc
            pop af
            ; special handling
            cp IT_FIRE
            jr nz,.nf
            ld hl,spells
            set 0,(hl)
.nf:        cp IT_DAGGER
            jr nz,.nd
            ld (weapon),a
.nd:        push af
            ; message "FOUND <ITEM>" (+ count)
            ld hl,msgbuf
            ld de,msgbuf
            ld hl,str_found
            call strcpy_de
            pop af
            push af
            add a,a
            ld l,a
            ld h,0
            ld bc,item_names
            add hl,bc
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            call strcpy_de
            ld a,'!'
            ld (de),a
            inc de
            xor a
            ld (de),a
            call draw_hud_panel
            call present_panel
            ld hl,msgbuf
            call show_msg
            pop af
            cp IT_FIRE
            ld b,TX_LEARNFIRE
            jr z,.extra
            cp IT_DAGGER
            ld b,TX_DAGGER
            ret nz
.extra:     push bc
            call wait_key
            pop bc
            ld a,b
            jp show_text

str_found:  db "YOU FOUND: ",0

; copy 0-terminated HL -> DE (DE left at terminator)
strcpy_de:
            ld a,(hl)
            ld (de),a
            or a
            ret z
            inc hl
            inc de
            jr strcpy_de

; ---------------------------------------------------------------------------
; seen map
; ---------------------------------------------------------------------------
mark_seen:
            ld a,(py)
            dec a
            ld b,a
            ld d,3
.r:         ld a,(px)
            dec a
            ld c,a
            ld e,3
.c:         call set_seen
            inc c
            dec e
            jr nz,.c
            inc b
            dec d
            jr nz,.r
            ret

; set seen bit for C,B (ignores out of range)
set_seen:
            ld a,c
            cp 16
            ret nc
            ld a,b
            cp 16
            ret nc
            push bc
            push de
            call seen_addr
            or (hl)
            ld (hl),a
            pop de
            pop bc
            ret

; seen_addr: C=x B=y -> HL = byte, A = bit mask
seen_addr:
            ld a,b
            add a,a                 ; y*2 bytes per row
            ld l,a
            ld a,c
            srl a
            srl a
            srl a
            add a,l
            ld l,a
            ld a,(cur_area)
            add a,a
            add a,a
            add a,a
            add a,a
            add a,a
            add a,l
            ld l,a
            ld h,EXPLORED/256
            ld a,c
            and 7
            ld b,a
            ld a,1
            inc b
.s:         dec b
            ret z
            add a,a
            jr .s

; ---------------------------------------------------------------------------
; HUD panel (bytes 20..31, rows 0..51)
; ---------------------------------------------------------------------------
PANEL_X     equ 20

draw_hud_panel:
            ; background
            ld c,PANEL_X
            ld b,12
            ld d,0
            ld e,52
            ld a,$AA
            call fill_rect
            ; red rule on the left edge
            ld d,0
.rule:      push de
            ld c,PANEL_X
            call back_addr
            ld (hl),$EA             ; red pixel + blue
            pop de
            inc d
            ld a,d
            cp 52
            jr nz,.rule
            ; area name (yellow on blue)
            ld b,1
            ld c,2
            call text_colors
            ld hl,(area_name)
            ld d,1
            ld b,PANEL_X+1
            ld c,11
            call print_centre
            call draw_compass
            ; HP / MP / level / gold
            call draw_stats
            ret

draw_compass:
            ; compass row at y=8: "N" in red, others yellow, current facing highlighted
            ld c,PANEL_X+1
            ld b,11
            ld d,8
            ld e,6
            ld a,$AA
            call fill_rect
            ld b,1
            ld c,2
            call text_colors
            ld hl,str_facing
            ld c,PANEL_X+2
            ld d,8
            call print_at
            ld a,(pdir)
            ld e,a
            ld d,0
            ld hl,dir_letters
            add hl,de
            ld a,(hl)
            push af
            ld b,3
            ld c,2
            call text_colors
            pop af
            ld c,PANEL_X+9
            ld d,8
            jp draw_char

str_facing: db "FACING",0
dir_letters: db "NESW"

draw_stats:
            ld b,1
            ld c,2
            call text_colors
            ; HP
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
            ld hl,statbuf
            ld c,PANEL_X+1
            ld d,16
            call print_at
            call hp_bar
            ; MP
            ld de,statbuf
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
            ld hl,statbuf
            ld c,PANEL_X+1
            ld d,25
            call print_at
            ; level
            ld de,statbuf
            ld hl,str_lv
            call strcpy_de
            ld a,(lvl)
            ld l,a
            ld h,0
            call num3_left
            ld hl,statbuf
            ld c,PANEL_X+1
            ld d,33
            call print_at
            ; gold
            ld de,statbuf
            ld a,'$'
            ld (de),a
            inc de
            ld hl,(gold)
            call num3_left
            ld hl,statbuf
            ld c,PANEL_X+1
            ld d,39
            call print_at
            ; weapon / key icons
            ld de,statbuf
            ld a,'['
            ld (de),a
            inc de
            ld a,(weapon)
            or a
            ld hl,str_stake
            jr z,.ws
            ld hl,str_dagger
.ws:        call strcpy_de
            ld hl,statbuf
            ld c,PANEL_X+1
            ld d,45
            call print_at
            ld a,(items+IT_IRONKEY)
            or a
            ret z
            ld b,1
            ld c,2
            call text_colors
            ld a,'#'
            ld c,PANEL_X+10
            ld d,39
            jp draw_char

str_lv:     db "LEVEL ",0
str_stake:  db "STAKE",0
str_dagger: db "SILVER",0

; hp bar under the HP line (y=22, 2 rows), 40px wide
hp_bar:
            ld c,PANEL_X+1
            ld b,10
            ld d,22
            ld e,1
            ld a,$AA
            call fill_rect
            ; width = hp*40/maxhp pixels
            ld a,(hp)
            ld e,40
            call mul8               ; hl = hp*40
            ld a,(maxhp)
            ld c,a
            call div_hl_c           ; a = result
            ld b,a
            ld d,22
            ld c,PANEL_X+1
            push bc
            call back_addr
            pop bc
.full:      ld a,b
            cp 4
            jr c,.part
            ld (hl),$FF
            inc hl
            sub 4
            ld b,a
            jr .full
.part:      or a
            ret z
            ; partial byte: b pixels red then blue
            ld c,$AA
            ld a,$C0
            ld e,b
.pp:        push af
            ld a,c
            and $3F
            ld c,a
            pop af
            or c
            ld c,a
            rrca
            rrca
            dec e
            jr nz,.pp
            ld (hl),c
            ret

; HL / C -> A (8-bit result)
div_hl_c:
            ld b,0
            ld a,c
            or a
            ret z
.l:         ld a,l
            sub c
            ld l,a
            ld a,h
            sbc a,0
            ld h,a
            jr c,.d
            inc b
            jr .l
.d:         ld a,b
            ret

; left-aligned number HL -> DE (DE advanced past digits, 0-terminated)
num3_left:
            push de
            ld de,numtmp
            call num3
            pop de
            ld hl,numtmp
            ld b,3
.s:         ld a,(hl)
            cp ' '
            jr nz,.c
            inc hl
            djnz .s
.c:         ld a,(hl)
            ld (de),a
            inc hl
            inc de
            djnz .c
            xor a
            ld (de),a
            ret

present_panel:
            ld c,PANEL_X
            ld b,12
            ld d,0
            ld e,52
            jp present_rect

present_panel_top:
            ld c,PANEL_X
            ld b,12
            ld d,8
            ld e,14
            jp present_rect

; ---------------------------------------------------------------------------
; message box (rows 52..63)
; ---------------------------------------------------------------------------
clear_msg_back:
            ld c,0
            ld b,32
            ld d,52
            ld e,12
            ld a,$FF                ; red band
            call fill_rect
            ld c,0
            ld b,32
            ld d,53
            ld e,11
            ld a,$AA
            jp fill_rect

present_msg:
            ld c,0
            ld b,32
            ld d,52
            ld e,64
            jp present_rect

; show_msg: HL = plain text (1 = newline) - draws and presents
show_msg:
            push hl
            call clear_msg_back
            ld b,1
            ld c,2
            call text_colors
            pop hl
            ld c,0
            ld d,53
            call print_at
            jp present_msg

; show_text: A = text id. Multi-page texts wait for a key between pages.
show_text:
            ld e,0
            jr show_text_x
show_text_wait:
            ld e,1
show_text_x:
            ld d,a
            ld a,e
            ld (st_waitlast),a
            ld a,d
            add a,a
            ld l,a
            ld h,0
            ld de,text_table
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
.page:      ; copy one page into msgbuf
            ld de,msgbuf
.cp:        ld a,(hl)
            inc hl
            cp 4
            jr z,.brk
            ld (de),a
            inc de
            or a
            jr nz,.cp
            ; last page
            ld hl,msgbuf
            call show_msg
            ld a,(st_waitlast)
            or a
            ret z
            jp wait_key
.brk:       xor a
            ld (de),a
            push hl
            ld hl,msgbuf
            call show_msg
            ; "more" marker
            ld b,3
            ld c,2
            call text_colors
            ld a,'>'
            ld c,31
            ld d,59
            call draw_char
            call present_msg
            call wait_key
            pop hl
            jr .page

play_music:
            ; A = song number (0 = none)
            or a
            jp z,stop_song
            dec a
            add a,a
            ld l,a
            ld h,0
            ld de,song_table
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld de,(cur_song)
            or a
            sbc hl,de
            ret z                   ; already playing
            add hl,de
            jp play_song
