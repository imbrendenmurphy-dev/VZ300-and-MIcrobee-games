; Clear BACK to black (all 24 rows).
page_begin:
        ld c,0
.r:     push bc
        ld a,T_EMPTY
        ld e,0
        call fill_row
        pop bc
        inc c
        ld a,c
        cp ROWS
        jr nz,.r
        ret

; HL = text, A = column, C = row, E = ink (into BACK and NATIVE).
page_text equ print_at

page_show:
        call full_redraw
        jp show_all

; Wait until no game key is held.
wait_up:
        call read_keys
        ld a,(kbits)
        or a
        jr nz,wait_up
        ret

; Wait for key A to be released, then pressed, then released.
wait_key:
        ld (wk_key),a
.up:    ld a,(wk_key)
        call scan_key
        jr nz,.up
.dn:    ld a,(wk_key)
        call scan_key
        jr z,.dn
.up2:   ld a,(wk_key)
        call scan_key
        jr nz,.up2
        ret

; A digit 0..9 (A) at pr_col, row C, ink pr_ink.
put_digit:
        add a,'0'
        jp put_c1

; ------------------------------------------------------------ wrist-deck
; HL-free test: NZ if shard A is held.
shard_have:
        push bc
        call shard_bit
        and (hl)
        pop bc
        ret

; NZ if room B has been visited.  Preserves BC.
visited_bit:
        push bc
        ld a,b
        ld hl,visited
        call flag_bit
        and (hl)
        pop bc
        ret

; HL = flag array, A = index -> HL = its byte, A = its mask.  Uses B.
flag_bit:
.b:     cp 8
        jr c,.m
        sub 8
        inc hl
        jr .b
.m:     ld b,a
        ld a,1
        inc b
.s:     dec b
        ret z
        add a,a
        jr .s

; ------------------------------------------------------------ splice puzzle
; At the splice terminal: rebuild the next key whose three shards are held.
splice_open:
        ld a,(cur_room)         ; MERIDIAN's own terminal: the end
        cp CORE_ROOM
        jp z,game_won
        ld a,1
        ld (srch_lock),a
        ld a,(cur_room)         ; this wing's terminal builds this wing's key
        ld hl,room_wing
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld b,(hl)
        ld a,(keys_done)
        ld c,b
        inc c
.kb:    rrca
        dec c
        jr nz,.kb
        ld hl,str_keyon
        jr c,.m                 ; already online
        ld a,b
        add a,a
        add a,b
        ld c,a
        call shard_have
        jr z,.need
        ld a,c
        inc a
        call shard_have
        jr z,.need
        ld a,c
        add a,2
        call shard_have
        jr nz,.go
.need:  ld hl,str_noready
.m:     call sfx_deny
        jp msg_show
.go:    ld a,b
        ld (sp_key),a
        ld a,OVL_CARD
        jp ovl_call
; ------------------------------------------------------------ rooms, again
; Rebuild the current room after a page, keeping Wren, robots, pads and finds.
resume_room:
        ld a,(gmode)            ; (back from the wrist-deck in a lift shaft)
        or a
        jp nz,shaft_resume
        ld a,(cur_room)         ; the overlay used STAGE: read the record again
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,room_far
        add hl,de
        ld de,STAGE
        call far_load
        ld hl,(STAGE+6)
        ld de,STAGE
        add hl,de
        call draw_rle
        ld a,(npads)
        or a
        jr z,.np
        ld b,a
        ld ix,pads
.p:     push bc
        ld a,(ix+P_DIR)
        or a
        call z,pad_bake
        ld de,P_SIZE
        add ix,de
        pop bc
        djnz .p
.np:    call marks_apply
        ld hl,(STAGE+0)
        ld de,STAGE
        add hl,de
        call hud_draw
        call room_signs_draw
        call full_redraw
        call show_all
        ld a,(nrob)             ; nothing of theirs is on screen now
        or a
        jr z,.nr
        ld b,a
        ld ix,robots
.r:     ld (ix+RB_DRAWN),0
        ld (ix+SP_DRAWN),0
        ld de,RB_SIZE
        add ix,de
        djnz .r
.nr:    xor a
        ld (gmode),a
        ld (wstate),a
        ld a,1
        ld (srch_lock),a
        ld a,F_STAND
        ld (wframe),a
        call objs_reset
        ld hl,(pend_msg)        ; a word left by a page ("GAME SAVED")
        ld a,h
        or l
        ret z
        ld de,0
        ld (pend_msg),de
        jp msg_show

; ------------------------------------------------------------ overlay
; The information screens live in BLACKOUT.OVL (block OVL_BLOCK); A = which.
OVL_TITLE equ 0
OVL_DECK equ 1
OVL_SPLICE equ OVL_CARD
OVL_WON equ 3
OVL_OVER equ 4
OVL_SAVE equ 5                  ; (the second overlay from here)
OVL_LOAD equ 6
OVL_LEVEL equ 7
OVL_CARD  equ 8                 ; (the third overlay from here)
OVL_TONE  equ 9
ovl_call:
        push af
        ld hl,ovl_far
        cp OVL_SAVE
        jr c,.one
        ld hl,ovl2_far
        cp OVL_CARD
        jr c,.one
        ld hl,ovl3_far
.one:   ld de,DATA_WIN
        call far_load
        pop af
        cp OVL_SAVE
        jr c,.jt
        sub OVL_SAVE
        cp OVL_CARD-OVL_SAVE
        jr c,.jt
        sub OVL_CARD-OVL_SAVE
.jt:
        ld l,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        ld de,DATA_WIN
        add hl,de
        jp (hl)
; The wrist-deck borrowed the shaft's pair map: draw the shaft again at this floor,
; with Wren where she was.
shaft_resume:
        ld a,(wx)
        push af
        ld a,(cur_level)
        ld b,2
        call enter_shaft
        call wren_erase
        pop af
        ld (wx),a
        call wren_place
        ld hl,(pend_msg)        ; ("GAME SAVED")
        ld a,h
        or l
        ret z
        ld de,0
        ld (pend_msg),de
        jp msg_show

ovl_far: db OVL_BLOCK
        dw 0,OVL_LEN
ovl2_far: db OVL2_BLOCK
        dw 0,OVL2_LEN
ovl3_far: db OVL3_BLOCK
        dw 0,OVL3_LEN
title:  ld sp,STACKTOP
        ld a,OVL_TITLE
        jp ovl_call
deck_open:
        ld a,OVL_DECK
        jp ovl_call
game_won:
        ld sp,STACKTOP
        ld a,OVL_WON
        jp ovl_call
game_over:
        ld sp,STACKTOP
        xor a                   ; the clock ran out: it reads 00:00:00, not a wrapped hour
        ld (clk_h),a
        ld (clk_m),a
        ld (clk_s),a
        ld a,OVL_OVER
        jp ovl_call

new_game:
        call game_init
        xor a
        ld (cur_shaft),a
        ld b,2                  ; on the lift at the top of shaft A
        call enter_shaft
        ld a,SPK_EIGHT
        call say
        jp loop

game_init:
        ld hl,game_vars
        ld de,game_vars+1
        ld bc,game_vars_end-game_vars-1
        ld (hl),0
        ldir
        ld a,8
        ld (clk_h),a
        xor a
        ld (clk_m),a
        ld (clk_s),a
        ld (said_hour),a
        ld (wings_seen),a
        ret

; Test hook: a fresh game on the lift of shaft dbg_r at floor dbg_side.
dbg_shaft:
        ld sp,STACKTOP
        call game_init
        ld a,(dbg_r)
        ld (cur_shaft),a
        ld a,(dbg_side)
        ld b,2
        call enter_shaft
        jp loop

; Test hook (only ever reached from the emulator: pc dbg_room): a fresh game
; dropped into room dbg_r through door dbg_side.
dbg_room:
        ld sp,STACKTOP
        call game_init
        ld a,(dbg_side)
        ld b,a
        ld a,(dbg_r)
        call enter_room
        jp loop
; Test hook: into room dbg_r through door dbg_side, keeping the game as it is.
dbg_goto:
        ld sp,STACKTOP
        ld a,(dbg_side)
        ld b,a
        ld a,(dbg_r)
        call enter_room
        jp loop
dbg_r:   db 0
dbg_side: db 0


str_noready: db "NEED 3 SHARDS",0
str_keyon:   db "KEY IS ONLINE",0
