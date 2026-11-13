; ============================================================================
;  FRONT END AND MATCH FLOW
; ============================================================================

; ---------------------------------------------------------------------------
; TITLE AND MAIN MENU
; ---------------------------------------------------------------------------
front_main:
        call stop_sfx
        xor a
        ld (two_player),a
        ld (menu_pos),a
        ld (dbg_on),a
.title: call draw_title
        ld hl,tune_title
        call play_loop
        ld hl,0
        ld (idle_ticks),hl
        call clear_keys
.loop:  call menu_frame
        call menu_keys          ; A = pads, B = system keys
        ld c,a
        or b
        jr z,.idle
        ld hl,0
        ld (idle_ticks),hl
.idle:  ld hl,(idle_ticks)
        inc hl
        ld (idle_ticks),hl
        ld de,25*20             ; 20 seconds: CPU v CPU demo
        or a
        sbc hl,de
        jp nc,demo
        ; up / down
        ld a,c
        bit 0,a
        jr z,.nu
        ld a,(menu_pos)
        or a
        jr z,.nu
        dec a
        ld (menu_pos),a
        call blip
        jr .redraw
.nu:    ld a,c
        bit 1,a
        jr z,.nd
        ld a,(menu_pos)
        cp 4
        jr z,.nd
        inc a
        ld (menu_pos),a
        call blip
        jr .redraw
.nd:    ; left / right on the level line
        ld a,(menu_pos)
        cp 2
        jr nz,.nlr
        ld a,c
        and $0C
        jr z,.nlr
        ld a,c
        bit 3,a
        ld a,(opt_diff)
        jr z,.lft
        cp 2
        jr z,.nlr
        inc a
        jr .sd
.lft:   or a
        jr z,.nlr
        dec a
.sd:    ld (opt_diff),a
        call blip
        jr .redraw
.nlr:   ; select: A, B, RETURN or SPACE
        ld a,c
        and $30
        jr nz,.sel
        ld a,b
        and 3
        jr z,.loop
.sel:   ld a,(menu_pos)
        or a
        jr z,.one
        cp 1
        jr z,.two
        cp 2
        jr z,.lvl
        cp 3
        jp z,control_test
        jp quit_to_sd
.lvl:   ld a,(opt_diff)
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (opt_diff),a
        call blip
.redraw:
        call draw_menu
        jp .loop
.one:   ; ---- one player: the world tour
        xor a
        ld (two_player),a
        call stop_sfx
        call sfx_select
        call select_screen
        jp c,front_main
        ld a,1
        ld (tour_on),a
        ld a,TOURSTART
        ld (tour_pos),a
.stop:  call tour_next
        jr c,.won
.tf:    call play_match
        jp c,front_main
        ld a,(match_res)
        or a
        jr nz,.tf               ; lost or drew: have another go
        ld hl,tour_pos
        inc (hl)
        jr .stop
.won:   call ending
        jp front_main
.two:   ; ---- two players
        ld a,1
        ld (two_player),a
        xor a
        ld (tour_on),a
        call stop_sfx
        call sfx_select
        call select_screen
        jp c,front_main
        call random             ; at one fighter's home or the other's
        rrca
        ld a,(sel_p1)
        jr c,$+5
        ld a,(sel_p2)
        ld (sel_stage),a
.again: call play_match
        jp nc,.again            ; rematch
        jp front_main
menu_frame:
        ld a,2
        ld (tick_len),a
        jp frame_end

blip:   push bc
        ld hl,sfx_blip
        call play_sfx_keep
        pop bc
        ret
sfx_select:
        ld hl,sfx_sel
        jp play_sfx

; play_sfx_keep: a short sound over the title tune, which then restarts
play_sfx_keep:
        jp play_sfx

; play_loop: HL = tune to repeat
play_loop:
        di
        ld (sfx_loopp),hl
        ld a,1
        ld (sfx_loop),a
        ei
        jp play_sfx

draw_title:
        call title_base
        call draw_menu
        ret

; title_base: arena, logo, the two fighters
title_base:
        call stage_css
        call hide_msg
        call clean_floor
        call bg_to_sb
        ld hl,s_red_dust
        ld c,1
        call big_text
        ld a,$AA
        ld b,0
        ld c,10
        ld d,32
        ld e,16
        call fill_rect          ; dark band behind the second line of the logo
        ld hl,s_rumble
        ld c,13
        call big_text
        ; the two fighters, posing
        ld ix,p1
        ld a,(slot_a)
        ld b,0
        call setup_fighter
        ld hl,18*4
        ld (p1+F_XL),hl
        xor a
        ld (p1+F_FACE),a
        ld (p1+F_Y),a
        ld a,FR_IDLE
        ld (p1+F_FRM),a
        ld ix,p2
        ld a,(slot_b)
        ld b,1
        call setup_fighter
        ld hl,110*4
        ld (p2+F_XL),hl
        ld a,1
        ld (p2+F_FACE),a
        xor a
        ld (p2+F_Y),a
        ld a,FR_IDLE
        ld (p2+F_FRM),a
        xor a
        ld (p1+F_HIDE),a
        ld (p2+F_HIDE),a
        ld (clip_top),a
        ld ix,p1
        call draw_fighter
        ld ix,p2
        call draw_fighter
        ld hl,s_vibed
        ld c,58
        ld a,2
        call text_c
        ret

draw_menu:
        ; clear the menu panel and print the five lines
        ld b,8
        ld c,27
        ld d,16
        ld e,30
        ld a,$AA                ; dark panel behind the menu
        call fill_rect
        ld hl,menu_lines
        ld c,28
        ld b,0
.l:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld a,b
        cp 2
        jr nz,.nl
        ; level line: "LEVEL " + name
        ld a,(opt_diff)
        add a,a
        ld e,a
        ld d,0
        ld hl,lvl_names
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
.nl:    ld a,(menu_pos)
        cp b
        ld a,1
        jr z,$+3
        xor a
        push af
        push bc
        call text_c
        pop bc
        pop af
        ; cursor arrow at column 9
        cp 1
        jr nz,.nc
        ld hl,s_arrow
        ld b,8
        ld a,3
        call text
.nc:    pop hl
        pop bc
        ld a,c
        add a,6
        ld c,a
        inc b
        ld a,b
        cp 5
        jr nz,.l
        ld a,1
        ld (copy_full),a
        ret

menu_lines:
        dw s_1p, s_2p, 0, s_ctest, s_quit
lvl_names:
        dw s_easy, s_normal, s_hard

; ---------------------------------------------------------------------------
; setup_fighter: IX = record, A = fighter number, B = side (0 = player 1,
; blue, in SRAM bank 1; 1 = player 2, red, in the second high bank)
; ---------------------------------------------------------------------------
setup_fighter:
        ld (ix+F_CHAR),a
        ld hl,SLOT_A
        ld c,XF_ID
        dec b
        jr nz,.a
        ld hl,SLOT_B
        ld c,XF_RED
.a:     ld (ix+F_DEFL),l
        ld (ix+F_DEFH),h
        ld (ix+F_XF),c
        ld de,D_DIR
        add hl,de
        ld a,(hl)
        ld (ix+F_DIRL),a
        inc hl
        ld a,(hl)
        ld (ix+F_DIRH),a
        ret

; palettes
css0:   ld a,$28
        jr css_set
stage_css:
        ld a,(stage_cur)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,stage_info
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        or $28
        ld hl,sh_pat
        ld (hl),e
css_set:
        di
        ld (latch),a
        ld (LATCH),a
        ei
        ret

; blue_screen: a plain dark screen in the shadow screen
blue_screen:
        ld a,$AA
        jp cls_sb

; name_of: A = fighter number -> HL = name
name_of:
        add a,a
        ld e,a
        ld d,0
        ld hl,fighter_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret
; stage_text: A = stage, E = 0 name / 2 country -> HL
stage_text:
        add a,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        ld hl,stage_names
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; ---------------------------------------------------------------------------
; FIGHTER SELECT: eight fighters in a 4 x 2 grid (the picture comes from the
; SD card).  Carry set if backed out.
; ---------------------------------------------------------------------------
CELLH   equ 25
GRIDTOP equ 7
select_screen:
        call css0
.ld:    xor a
        call load_screen
        jr nc,.ok
        ld a,1
        ld (err_code),a
        call sd_error
        jr .ld
.ok:    xor a
        ld (sel_cur),a
        ld a,$FF
        ld (sel_p1),a
        ld hl,s_player1
        call .pick
        ret c
        ld (sel_p1),a
        ld a,(two_player)
        or a
        ret z
        ld hl,s_player2
        call .pick
        ret c
        ld (sel_p2),a
        or a
        ret
.pick:  ld (ld_name),hl          ; (a spare word: the prompt)
        call clear_keys
.draw:  call bg_to_sb
        ld hl,s_choose
        ld c,1
        ld a,1
        call text_c
        ; player 1's choice keeps a tag while player 2 picks
        ld a,(sel_p1)
        cp 8
        jr nc,.nt
        call .cell
        ld hl,s_p1
        ld a,3
        call text
.nt:    ld a,(sel_cur)
        call .cell
        call cell_frame
        ld hl,(ld_name)
        ld b,0
        ld c,58
        ld a,1
        call text
        ld a,(sel_cur)
        ld e,2
        call stage_text
        push hl
        call strlen
        ld b,a
        ld a,32
        sub b
        ld b,a
        pop hl
        ld c,58
        ld a,1
        call text
        ld a,1
        ld (copy_full),a
.w:     call menu_frame
        call menu_keys
        ld c,a
        ld a,b
        bit 2,a                 ; Q: back
        jr nz,.back
        ld a,c
        bit 5,a                 ; B: back
        jr nz,.back
        bit 4,a
        jr nz,.take
        ld a,b
        and 3
        jr nz,.take
        ld a,(sel_cur)
        ld e,a
        bit 2,c
        jr z,$+3
        dec a
        bit 3,c
        jr z,$+3
        inc a
        bit 0,c
        jr z,$+4
        sub 4
        bit 1,c
        jr z,$+4
        add a,4
        and 7
        cp e
        jr z,.w
        ld (sel_cur),a
        call blip
        jr .draw
.take:  call sfx_select
        ld a,(sel_cur)
        or a
        ret
.back:  scf
        ret
.cell:  ; A = cell -> B = byte column, C = row of its top
        ld b,a
        and 3
        add a,a
        add a,a
        add a,a
        ld d,a
        ld a,b
        and 4
        ld c,GRIDTOP
        jr z,$+4
        ld c,GRIDTOP+CELLH
        ld b,d
        ret
; cell_frame: a bright frame round the cell at byte column B, row C
cell_frame:
        push bc
        ld d,8
        ld e,1
        ld a,$55
        call fill_rect
        pop bc
        push bc
        ld a,c
        add a,CELLH-1
        ld c,a
        ld d,8
        ld e,1
        ld a,$55
        call fill_rect
        pop bc
        call sb_addr            ; HL = top-left byte
        ld b,CELLH
        ld de,32-7
.l:     ld a,(hl)
        and $3F
        or $40
        ld (hl),a
        push de
        ld de,7
        add hl,de
        pop de
        ld a,(hl)
        and $FC
        or $01
        ld (hl),a
        add hl,de
        djnz .l
        ret

; ---------------------------------------------------------------------------
; WORLD TOUR
; tour_next: set up fight number (tour_pos): the seven other fighters in
; order, each at home, then Sable.  Shows the map.  Carry = tour complete.
; ---------------------------------------------------------------------------
tour_next:
        ld a,(tour_pos)
        cp 8
        ccf
        ret c
        cp 7
        jr z,.boss
        ld hl,sel_p1
        cp (hl)
        jr c,.set
        inc a
        jr .set
.boss:  ld a,8
.set:   ld (sel_p2),a
        ld (sel_stage),a
        call map_screen
        or a
        ret

; map_screen: the world map with the next stop flashing
map_screen:
        call css0
        ld a,1
        call load_screen
        ret c                   ; no map: carry on without it
        call bg_to_sb
        ; "FIGHT n: PLACE, COUNTRY" along the bottom
        ld a,(tour_pos)
        add a,'1'
        ld (s_fightn+6),a
        ld hl,s_fightn
        ld b,0
        ld c,58
        ld a,1
        call text
        ld a,(sel_stage)
        ld e,0
        call stage_text
        ld b,9
        ld c,58
        ld a,1
        call text
        ld a,1
        ld (copy_full),a
        ; where it is on the map
        ld a,(sel_stage)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,stage_info+2
        add hl,de
        ld a,(hl)
        ld (map_px),a
        xor a
        ld (map_px+1),a
        inc hl
        ld a,(hl)
        ld (map_py),a
        ld hl,sfx_bell
        call play_sfx
        call clear_keys
        ld b,75
.l:     push bc
        ld a,b
        and 4
        ld a,1
        jr z,$+4
        ld a,3
        call set_colour
        ld hl,(map_px)
        ld (pt_x),hl
        ld a,(map_py)
        ld (pt_row),a
        xor a
        ld (pt_flip),a
        ld (clip_top),a
        ld hl,fx_mark
        call draw_points
        ld a,1
        ld (copy_full),a
        call menu_frame
        call menu_keys
        pop bc
        and $30
        ret nz
        djnz .l
        or a
        ret

; ---------------------------------------------------------------------------
; vs_card: who fights whom, and where, on a dark screen that stays up while
; the SD card is read
; ---------------------------------------------------------------------------
vs_card:
        call css0
        call blue_screen
        ld a,(tour_on)
        or a
        jr z,.nt
        ld a,(tour_pos)
        cp 7
        ld hl,s_final
        jr z,.t
        add a,'1'
        ld (s_fightof+6),a
        ld hl,s_fightof
.t:     ld c,1
        ld a,1
        call text_c
.nt:    ld a,(sel_p1)
        call name_of
        ld c,10
        call big_text
        ld hl,s_vs
        ld c,24
        ld a,3
        call text_c
        ld a,(sel_p2)
        call name_of
        ld c,32
        call big_text
        ld a,(sel_stage)
        ld e,0
        call stage_text
        ld c,49
        ld a,1
        call text_c
        ld a,(sel_stage)
        ld e,2
        call stage_text
        ld c,56
        ld a,1
        call text_c
        ld a,1
        ld (copy_full),a
        call menu_frame
        jp menu_frame

; ending: the tour is won
ending:
        call stop_sfx
        call css0
        call blue_screen
        ld hl,s_world
        ld c,6
        call big_text
        ld hl,s_champ
        ld c,18
        call big_text
        ld a,(sel_p1)
        call name_of
        ld c,34
        ld a,1
        call text_c
        ld hl,s_beat
        ld c,41
        ld a,1
        call text_c
        ld hl,s_vibed
        ld c,56
        ld a,3
        call text_c
        ld a,1
        ld (copy_full),a
        ld hl,tune_title
        call play_loop
        call clear_keys
        ld b,50
.d:     push bc
        call menu_frame
        pop bc
        djnz .d
        call clear_keys
.w:     call menu_frame
        call menu_keys
        and $30
        jr z,.w
        jp stop_sfx

; do_flash: the finisher's flash (the palette flips for a few ticks)
do_flash:
        ld a,(flash_t)
        or a
        ret z
        dec a
        ld (flash_t),a
        ld a,(latch)
        xor $10
        jp css_set

; clean_floor: menus show the middle of the stage; fighters drawn at
; screen positions (camera 0)
clean_floor:
        ld a,32
        ld (src_cam),a
        call bg_build
        xor a
        ld (cam),a
        ld (scrolled),a
        ld (bg_stale),a
        ret
