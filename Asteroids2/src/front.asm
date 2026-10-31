; ---------------------------------------------------------------------------
; front.asm - music player, title, attract sequence, demo AI, high scores
; ---------------------------------------------------------------------------

; ======================= music =======================
; per-channel RAM programs for the SFX engine
mus_start:
        call snd_off
        ld hl,mus_order_tab
        ld (mus_order),hl
        ld a,1
        ld (mus_tmr),a
        ld a,6
        ld (mus_tempo),a
        call mus_next_pat
        ld hl,mus_tick
        ld (tick_hook),hl
        ret

mus_stop:
        ld hl,no_tick
        ld (tick_hook),hl
        jp snd_off

mus_next_pat:
        ld hl,(mus_order)
        ld a,(hl)
        cp $FF
        jr nz,.ok
        ld hl,mus_order_tab+MUS_LOOP
        ld a,(hl)
.ok:    inc hl
        ld (mus_order),hl
        add a,a
        ld e,a
        ld d,0
        ld hl,mus_pat_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (mus_ptr),hl
        ld a,16
        ld (mus_row),a
        ret

mus_tick:
        ld hl,mus_tmr
        dec (hl)
        jr nz,.env
        ld a,(mus_tempo)
        ld (hl),a
        call mus_do_row
.env:   jp sfx_tick

mus_do_row:
        ld hl,(mus_ptr)
        ld a,(hl)
        inc hl
        push hl
        ld ix,ch0
        ld iy,mprog0
        ld c,0
        call mus_event
        pop hl
        ld a,(hl)
        inc hl
        push hl
        ld ix,ch1
        ld iy,mprog1
        ld c,1
        call mus_event
        pop hl
        ld a,(hl)
        inc hl
        push hl
        ld ix,ch2
        ld iy,mprog2
        ld c,2
        call mus_event
        pop hl
        ld (mus_ptr),hl
        ld hl,mus_row
        dec (hl)
        ret nz
        jp mus_next_pat

; A = event byte, IX = channel, IY = program buffer, C = channel number
mus_event:
        or a
        ret z
        cp $FE
        jr nz,.n1
        xor a
        ld (ix+CH_PTR),a
        ld (ix+CH_PTR+1),a
        ret
.n1:    cp $F1
        jr c,.note
        ; drum: point channel at a fixed program
        sub $F1
        add a,a
        ld e,a
        ld d,0
        ld hl,drum_progs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp .set
.note:  ld b,0                  ; arp flag
        ld d,a
        ld a,c
        cp 2
        ld a,d
        jr nz,.plain
        ; ch2 chord: >100 major
        ld b,3                  ; minor third
        cp 101
        jr c,.arp
        sub 100
        ld b,4
.arp:   ; three 1-tick segments: root, third, fifth, looping
        ld (tmp1),a
        push iy
        pop hl
        ld e,a
        call .seg1
        ld a,(tmp1)
        add a,b
        ld e,a
        call .seg1
        ld a,(tmp1)
        add a,7
        ld e,a
        call .seg1
        ld (hl),$FF
        inc hl
        push iy
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        push iy
        pop hl
        jr .set
.seg1:  ; HL = buffer, E = note -> 8-byte segment, 1 tick, quiet pad
        ld (hl),1
        inc hl
        call .freq
        ld (hl),40
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ret
.freq:  ; write freq of note E (1-based), df = 0
        push hl
        ld d,0
        dec e
        ld hl,note_frq
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        ret
.plain: ; ch0 bass / ch1 lead: gate then cut (notes stay separate)
        ld e,a
        push iy
        pop hl
        ld a,c
        or a
        jr nz,.lead
        ld (hl),5               ; bass: 5 ticks
        inc hl
        call .freq
        ld (hl),110
        inc hl
        ld (hl),-10
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0               ; end
        push iy
        pop hl
        jr .set
.lead:  ld (hl),9               ; lead: 9 ticks with decay
        inc hl
        call .freq
        ld (hl),96
        inc hl
        ld (hl),-7
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
        push iy
        pop hl
.set:   ld (ix+CH_PTR),l
        ld (ix+CH_PTR+1),h
        ld (ix+CH_CNT),0
        ld (ix+CH_PRIO),0
        ret

drum_progs: dw dr_kick, dr_snare, dr_hat
dr_kick:  SEG 3, 900, -250, 128, -36, 0
          db 0
dr_snare: SEG 1, 1, 0, 120, 0, 1
          SEG 3, 2, 0, 100, -30, 1
          db 0
dr_hat:   SEG 1, 3, 0, 44, 0, 1
          db 0

; ======================= screen helpers =======================
; map ROWTAB to VRAM rows 6..63 so draw_spr / plot can XOR straight onto the screen
rowtab_vram:
        ld a,32
        ld (row_stride),a
        xor a
        ld (ds_lastwb),a
        ld hl,VRAM+6*32
        ld ix,ROWTAB
        ld b,PF_ROWS
        ld de,32
.l:     ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        add hl,de
        djnz .l
        ret

; print HL at text row B (pixel row), centred, colour A
print_centre:
        ld (txt_col),a
        push hl
        push bc
        call centre_col
        pop bc
        call vram_addr
        pop hl
        jp print_v

; print HL at column A, pixel row B, colour C
print_at:
        push hl
        push bc
        call vram_addr
        pop bc
        ld a,c
        ld (txt_col),a
        pop hl
        jp print_v

; fill pixel rows B..B+C-1 with blue
clear_rows:
        ld a,0
        call vram_addr          ; DE = row start (A=0)
        ex de,hl
        ld a,c
.r:     ld b,32
.c:     ld (hl),D_B
        inc hl
        djnz .c
        dec a
        jr nz,.r
        ret

; copy a packed image: HL = data, DE = VRAM address, B = rows, C = bytes per row
blit_vram:
        push bc
        push de
        ld b,0
        ldir
        pop de
        ex de,hl
        ld bc,32
        add hl,bc
        ex de,hl
        pop bc
        djnz blit_vram
        ret

; swap yellow<->red inside a VRAM rectangle (shine): HL = addr, B = rows, C = cols
shine_rect:
.r:     push bc
        push hl
.c:     ld a,(hl)
        and $55
        add a,a
        xor (hl)
        ld (hl),a
        inc hl
        dec c
        jr nz,.c
        pop hl
        ld de,32
        add hl,de
        pop bc
        djnz .r
        ret

; ======================= title starfield (direct to VRAM, background-checked) =======================
N_TSTAR equ 14
tstars_init:
        ld hl,tstar
        ld b,N_TSTAR
.l:     call rnd
        and 127
        ld (hl),a               ; x
        inc hl
.y:     call rnd
        and 63
        cp 51
        jr nc,.y
        cp 17
        jr c,.ok
        cp 31
        jr c,.y                 ; keep clear of the emblem / rocks band
.ok:    ld (hl),a               ; y (buffer row -> screen row y+6)
        inc hl
        ld a,b
        and 3
        jr nz,.s
        inc a
.s:     ld (hl),a               ; speed 1..3
        inc hl
        ld (hl),0               ; drawn flag
        inc hl
        djnz .l
        ret

; HL -> VRAM byte, A -> pixel mask for D = x, E = y (via ROWTAB)
tpix:   ld a,e
        add a,a
        ld l,a
        ld h,ROWTAB/256
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,d
        rrca
        rrca
        and 31
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld a,d
        and 3
        add a,pixmask & 255
        ld e,a
        ld d,pixmask/256
        ld a,(de)
        ret

tstars_step:                    ; half the stars each field (alternating)
        ld hl,tstar
        ld a,(title_tmr)
        and 1
        jr z,.h
        ld hl,tstar+4
.h:     ld b,N_TSTAR/2
.l:     push bc
        push hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        ld (tmp1),a
        inc hl
        ld a,(hl)
        ld (hl),0
        or a
        jr z,.nd
        call tpix               ; erase if still our green star
        ld c,a
        and (hl)
        jr nz,.nd               ; pixel not green any more: leave it
        ld a,c
        and D_B
        or (hl)
        ld (hl),a
.nd:    pop hl
        push hl
        ld a,(tmp1)
        ld b,a
        ld a,(hl)
        sub b
        and 127
        ld (hl),a
        ld d,a
        inc hl
        ld e,(hl)
        inc hl
        inc hl
        push hl
        call tpix               ; draw only onto blue background
        ld c,a
        and (hl)
        ld b,a
        ld a,c
        and D_B
        cp b
        pop de
        jr nz,.nb
        ld a,c
        cpl
        and (hl)
        ld (hl),a               ; green pixel
        ld a,1
        ld (de),a
.nb:    pop hl
        ld de,8
        add hl,de
        pop bc
        djnz .l
        ret

; ======================= attract =======================
; returns when the player presses fire/start
attract:
        call mus_start
.loop:  call title_page
        ret c
        call roster_page
        ret c
        call treasure_page
        ret c
        call demo_play
        ret c
        call scores_page
        ret c
        jr .loop

; wait one field, Carry set if start pressed (also handles 'M' music toggle)
front_frame:
        call wait_fs
        ld a,(KBD+ROW4)
        bit 5,a                 ; M toggles music
        jr nz,.nm
        ld a,(last_key)
        or a
        jr nz,.nm2
        ld a,1
        ld (last_key),a
        ld a,(music_on)
        xor 1
        ld (music_on),a
        jr z,.off
        call mus_start
        jr .nm2
.off:   call mus_stop
        jr .nm2
.nm:    xor a
        ld (last_key),a
.nm2:   call read_input
        ld a,(in_new)
        and IN_FIRE|IN_START
        ret z
        scf
        ret

; run B*256+C fields of a page, calling (page_anim) each field. Carry = start
page_run:
        ld (attract_tmr),bc
.l:     call front_frame
        ret c
        ld hl,(page_anim)
        call jp_hl
        ld hl,(attract_tmr)
        dec hl
        ld (attract_tmr),hl
        ld a,h
        or l
        jr nz,.l
        or a
        ret

new_screen:
        ld a,D_B
        call cls_vram
        call rowtab_vram
        ld a,$08
        ld (latch_base),a
        ret

; ---------------- title ----------------
title_page:
        call new_screen
        ; logo
        ld hl,logo_data
        ld de,VRAM+3*32+2
        ld b,LOGO_H
        ld c,LOGO_WB
        call blit_vram
        ld hl,emblem_data
        ld de,VRAM+23*32+14
        ld b,EMB_H
        ld c,EMB_WB
        call blit_vram
        ld hl,txt_press
        ld b,41
        ld a,D_Y
        call print_centre
        ld hl,txt_credit1
        ld b,48
        ld a,D_R
        call print_centre
        xor a
        ld (list_frame),a
        ld (list_frame+1),a
        ld a,SPR_ROCK_1_L
        ld de,36*256+24
        call draw_spr
        ld a,SPR_ROCK_2_L
        ld de,92*256+24
        call draw_spr
        call tstars_init
        ld a,-8
        ld (shine_x),a
        ld hl,txt_scroll
        ld (scroll_ptr),hl
        xor a
        ld (scroll_sub),a
        ld (title_tmr),a
        ld hl,title_anim
        ld (page_anim),hl
        ld bc,750
        jp page_run

title_anim:
        ld hl,title_tmr
        inc (hl)
        call tstars_step
        call scroller
        ; logo shine: move a 2-byte band across every 2 fields
        ld a,(title_tmr)
        and 1
        jr nz,.ns
        ld a,(shine_x)
        cp 27
        jr nc,.nr
        ld e,a
        ld d,0
        ld hl,VRAM+3*32+2
        add hl,de
        ld b,LOGO_H
        ld c,1
        call shine_rect         ; restore (swap back) leftmost of band
.nr:    ld a,(shine_x)
        inc a
        cp 60
        jr c,.sx
        ld a,-8
.sx:    ld (shine_x),a
        add a,1
        cp 27
        jr nc,.ns
        ld e,a
        ld d,0
        ld hl,VRAM+3*32+2
        add hl,de
        ld b,LOGO_H
        ld c,1
        call shine_rect
.ns:    ; emblem pulse every 16 fields
        ld a,(title_tmr)
        and 15
        jr nz,.ne
        ld hl,VRAM+23*32+14
        ld b,EMB_H
        ld c,EMB_WB
        call shine_rect
.ne:    ; tumbling rocks beside the emblem (XOR: erase old frame, draw new)
        ld a,(title_tmr)
        and 7
        jr nz,.nk
        ld a,(title_tmr)
        and 8
        ld bc,SPR_ROCK_1_L*256+36
        jr z,.rk
        ld bc,SPR_ROCK_2_L*256+92
.rk:    push bc
        ld hl,list_frame
        jr z,.rf
        inc hl
.rf:    ld a,(hl)
        push hl
        add a,b
        ld d,c
        ld e,24
        call draw_spr           ; erase old frame
        pop hl
        ld a,(hl)
        inc a
        and 7
        ld (hl),a
        pop bc
        add a,b
        ld d,c
        ld e,24
        call draw_spr
.nk:    ; blink PRESS FIRE + credit line
        ld a,(title_tmr)
        and 31
        jr nz,.nb
        ld hl,VRAM+41*32
        ld b,5
        ld c,32
        call shine_rect
        ; cycle credit line every 128 fields
        ld a,(title_tmr)
        and 127
        jr nz,.nb
        ld b,48
        ld c,5
        call clear_rows
        ld a,(title_tmr)
        rlca
        and 1
        ld hl,txt_credit1
        jr z,.c1
        ld hl,txt_credit2
.c1:    ld b,48
        ld a,D_R
        jp print_centre
.nb:    ret

; scroller on pixel rows 58..62: 2 pixels (one nibble) every other field, using RLD
scroller:
        ld a,(title_tmr)
        and 1
        ret nz
        ld hl,(scroll_ptr)
        ld a,(hl)
        or a
        jr nz,.ch
        ld hl,txt_scroll
        ld (scroll_ptr),hl
        ld a,(hl)
.ch:    call char_addr          ; HL = glyph
        ld de,VRAM+58*32+31
        ld b,5
.row:   push bc
        ld a,(scroll_sub)
        or a
        ld a,(hl)
        jr nz,.lo
        rrca
        rrca
        rrca
        rrca
.lo:    and $0F                 ; glyph mask nibble (2 px)
        ld c,a
        and D_Y & $0F
        ld b,a
        ld a,c
        cpl
        and D_B & $0F
        or b                    ; A low nibble = new pixels
        ex de,hl
        push hl
        DUP 32
        rld
        dec hl
        EDUP
        pop hl
        ld bc,32
        add hl,bc
        ex de,hl
        inc hl
        pop bc
        dec b
        jp nz,.row
        ld hl,scroll_sub
        ld a,(hl)
        xor 1
        ld (hl),a
        ret nz
        ld hl,(scroll_ptr)
        inc hl
        ld (scroll_ptr),hl
        ret

; ---------------- roster: enemies ----------------
roster_page:
        xor a
        ld (list_frame),a
        call new_screen
        ld hl,txt_roster
        ld b,1
        ld a,D_R
        call print_centre
        ld hl,roster_list
        call draw_list
        ld hl,list_anim
        ld (page_anim),hl
        xor a
        ld (title_tmr),a
        ld bc,400
        jp page_run

treasure_page:
        xor a
        ld (list_frame),a
        call new_screen
        ld hl,txt_treasure
        ld b,1
        ld a,D_Y
        call print_centre
        ld hl,treasure_list
        call draw_list
        ld hl,list_anim
        ld (page_anim),hl
        xor a
        ld (title_tmr),a
        ld bc,400
        jp page_run

; list entries: sprite id, frames-1 mask, y (0..57 buffer row), text ptr ; terminated by $FF
; draws first frame of each sprite at x=14 and its text at column 7
draw_list:
        ld (list_ptr),hl
.l:     ld a,(hl)
        cp $FF
        ret z
        push hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,e
        add a,4                 ; screen pixel row = y + 6 - 2
        ld b,a
        ld a,7
        ld c,D_Y
        push de
        call print_at
        pop de
        pop hl
        push hl
        ld a,(hl)
        ld d,14
        call draw_spr
        pop hl
        ld de,5
        add hl,de
        jr .l

; animate list sprites: every 6 fields XOR old frame off, new frame on
list_anim:
        ld hl,title_tmr
        inc (hl)
        ld a,(hl)
        cp 6
        ret c
        ld (hl),0
        ld hl,list_frame
        ld a,(hl)
        inc (hl)
        ld (tmp2),a
        ld hl,(list_ptr)
.l:     ld a,(hl)
        cp $FF
        ret z
        push hl
        ld c,a                  ; base sprite
        inc hl
        ld b,(hl)               ; frame mask
        inc hl
        ld e,(hl)
        ld a,(tmp2)
        and b
        ld (tmp3),a
        add a,c
        push bc
        push de
        ld d,14
        call draw_spr           ; erase old
        pop de
        pop bc
        ld a,(tmp3)
        inc a
        and b
        add a,c
        ld d,14
        call draw_spr           ; draw new
        pop hl
        ld de,5
        add hl,de
        jr .l

roster_list:
        db SPR_SAUCER, 1, 6
        dw txt_r_saucer
        db SPR_HUNTER, 1, 15
        dw txt_r_hunter
        db SPR_STING, 7, 24
        dw txt_r_sting
        db SPR_MINE, 1, 33
        dw txt_r_mine
        db SPR_ROCK_2_M, 7, 42
        dw txt_r_volat
        db SPR_ROCK_1_M, 7, 51
        dw txt_r_ore
        db $FF
treasure_list:
        db SPR_JEWEL_TOPAZ, 3, 4
        dw txt_t_topaz
        db SPR_JEWEL_RUBY, 3, 11
        dw txt_t_ruby
        db SPR_JEWEL_EMERALD, 3, 18
        dw txt_t_emerald
        db SPR_PICK_SPREAD, 1, 26
        dw txt_t_spread
        db SPR_PICK_RAPID, 1, 33
        dw txt_t_rapid
        db SPR_PICK_SHIELD, 1, 40
        dw txt_t_shield
        db SPR_PICK_BOMB, 1, 47
        dw txt_t_bomb
        db SPR_PICK_LIFE, 1, 54
        dw txt_t_life
        db $FF

; ---------------- high score page ----------------
scores_page:
        call new_screen
        ld hl,txt_hiscores
        ld b,4
        ld a,D_R
        call print_centre
        call draw_scores
        ld hl,list_anim_none
        ld (page_anim),hl
        ld bc,350
        jp page_run
list_anim_none:
        ret

draw_scores:
        ld ix,hs_table
        ld b,5
        ld c,16                 ; pixel row
.l:     push bc
        ; rank digit
        ld a,6
        sub b
        add a,'0'
        ld (numbuf),a
        ld a,'.'
        ld (numbuf+1),a
        xor a
        ld (numbuf+2),a
        ld b,c
        ld a,8
        ld c,D_G
        push bc
        ld hl,numbuf
        call print_at
        pop bc
        ; score
        push bc
        ld a,11
        call vram_addr
        ld a,D_Y
        ld (txt_col),a
        push ix
        pop hl
        call print_bcd3
        pop bc
        ; initials
        ld a,(ix+3)
        ld (numbuf),a
        ld a,(ix+4)
        ld (numbuf+1),a
        ld a,(ix+5)
        ld (numbuf+2),a
        xor a
        ld (numbuf+3),a
        ld a,19
        ld c,D_R
        ld hl,numbuf
        call print_at
        ld de,8
        add ix,de
        pop bc
        ld a,c
        add a,8
        ld c,a
        djnz .l
        ret

hs_defaults:
        db $01,$00,$00,"ACE",0,0
        db $00,$75,$00,"VZ3",0,0
        db $00,$50,$00,"DSE",0,0
        db $00,$25,$00,"DUB",0,0
        db $00,$10,$00,"MCN",0,0

; ---------------- demo ----------------
demo_play:
        call mus_stop
        ld a,1
        ld (demo_mode),a
        ld hl,450
        ld (attract_tmr),hl
        call init_rowtab
        call play_game_demo
        push af
        xor a
        ld (demo_mode),a
        ld (in_cur),a
        call mus_start
        pop af
        ret

; ---------------- demo AI ----------------
; aims at the nearest rock/enemy, fires when lined up, thrusts now and then,
; hyperspaces when something is about to hit it
ai_input:
        ld c,0
        ld a,(ship_state)
        or a
        jp nz,set_input
        ; find nearest target (rocks + enemies)
        ld a,255
        ld (tmp2),a
        ld hl,0
        ld (tmp3),hl
        ld iy,OBJ_ROCK
        ld b,N_ROCK+N_ENEMY
.f:     ld a,(iy+O_TYPE)
        or a
        jr z,.nf
        push bc
        call vec_to_ship
        ld a,d
        call abs_a
        ld b,a
        ld a,e
        call abs_a
        ld c,a
        add a,a
        add a,c
        srl a
        add a,b                 ; ~distance
        jr c,.nf2
        ld hl,tmp2
        cp (hl)
        jr nc,.nf2
        ld (hl),a
        ld (tmp3),iy
.nf2:   pop bc
.nf:    ld de,OBJSZ
        add iy,de
        djnz .f
        ld c,0
        ld hl,(tmp3)
        ld a,h
        or l
        jr z,.done
        push hl
        pop iy
        ; danger: very close -> hyperspace (if allowed), else shoot
        ld a,(tmp2)
        cp 7
        jr nc,.far
        ld a,(hyper_cd)
        or a
        jr nz,.far
        ld a,(invuln)
        or a
        jr nz,.far
        ld c,IN_HYPER
        jr .done
.far:   call vec_to_ship        ; D,E = ship - target ; want target - ship
        ld a,d
        neg
        ld d,a
        ld (at_dx),a
        ld a,e
        neg
        ld e,a
        ld (at_dy),a
        call atan64             ; A = 0..63 angle to target
        ld b,a
        ld a,(ship_ang)
        rrca
        rrca
        and 63
        sub b
        and 63                  ; diff
        ld c,0
        cp 2
        jr c,.aim
        cp 62
        jr nc,.aim
        cp 32
        ld c,IN_LEFT
        jr c,.rot
        ld c,IN_RIGHT
.rot:   jr .thr
.aim:   ld c,0
        ld a,(tmp2)
        cp 60
        jr nc,.thr              ; too far: line up, don't waste shots
        ld c,IN_FIRE
        ld a,(frame_ct)
        and 2
        jr z,.thr
        ld c,0                  ; release so the fire is re-triggered
.thr:   ; thrust towards distant targets now and then
        ld a,(tmp2)
        cp 40
        jr c,.done
        ld a,(frame_ct)
        and 24
        jr nz,.done
        ld a,c
        or IN_THRUST
        ld c,a
.done:  jp set_input

; ---------------- high score entry ----------------
; after a game: insert score if it qualifies, ask for initials
check_hiscore:
        ; find rank: first entry with score < player score
        ld ix,hs_table
        ld b,5
.r:     push ix
        pop hl
        ld de,score
        ld a,(de)
        cp (hl)
        jr nz,.cmp
        inc hl
        inc de
        ld a,(de)
        cp (hl)
        jr nz,.cmp
        inc hl
        inc de
        ld a,(de)
        cp (hl)
        jr z,.lo
.cmp:   jr nc,.ins              ; player > entry
.lo:    ld de,8
        add ix,de
        djnz .r
        ret                     ; not good enough
.ins:   ; shift lower entries down
        ld a,b
        ld (hs_rank),a
        dec a
        jr z,.noshift
        ; move entries ix..end-8 down by 8 (from the bottom up)
        add a,a
        add a,a
        add a,a
        ld c,a
        ld b,0
        ld hl,hs_table+8*4-1
        ld de,hs_table+8*5-1
        lddr
.noshift:
        push ix
        pop hl
        ld de,score
        ex de,hl
        ld bc,3
        ldir
        ld a,'A'
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        ld (entry_ptr),de
        ; initials entry screen
        call new_screen
        ld hl,txt_newhigh
        ld b,8
        ld a,D_R
        call print_centre
        ld hl,txt_enter
        ld b,18
        ld a,D_G
        call print_centre
        ld hl,txt_enter2
        ld b,26
        ld a,D_G
        call print_centre
        call mus_start
        xor a
        ld (entry_pos),a
        ld (in_cur),a
.loop:  call wait_fs
        call read_input
        ; draw the three letters (current one blinks)
        call draw_entry
        ld a,(in_new)
        and IN_LEFT|IN_RIGHT
        jr nz,.chg
        ld a,(in_cur)
        and IN_LEFT|IN_RIGHT
        jr z,.nochg
        ld hl,ship_rot          ; autorepeat
        inc (hl)
        ld a,(hl)
        cp 12
        jr c,.nochg
        ld (hl),8
.chg:   ld hl,(entry_ptr)
        ld a,(entry_pos)
        ld e,a
        ld d,0
        dec hl
        dec hl
        add hl,de
        ld a,(in_cur)
        and IN_LEFT
        ld a,(hl)
        jr z,.up
        dec a
        cp 'A'
        jr nc,.st
        ld a,'Z'
        jr .st
.up:    inc a
        cp 'Z'+1
        jr c,.st
        ld a,'A'
.st:    ld (hl),a
        ld a,SFX_CLINK
        call sfx_play
        jr .ok
.nochg: xor a
        ld (ship_rot),a
.ok:    ld a,(in_new)
        and IN_FIRE|IN_START
        jr z,.loop
        ld a,SFX_PICKUP
        call sfx_play
        ld hl,entry_pos
        inc (hl)
        ld a,(hl)
        cp 3
        jr c,.loop
        call draw_entry
        ; show the table
        call scores_page
        ret

draw_entry:
        ld hl,(entry_ptr)
        dec hl
        dec hl
        ld b,0
.l:     push bc
        push hl
        ld a,(hl)
        ld (numbuf),a
        xor a
        ld (numbuf+1),a
        ld c,D_Y
        ld a,(entry_pos)
        cp b
        jr nz,.nb
        ld a,(frame_ct)
        and 8
        jr z,.nb
        ld c,D_R
.nb:    ld a,b
        add a,a
        add a,14
        ld b,38
        ld hl,numbuf
        call print_at
        pop hl
        inc hl
        pop bc
        inc b
        ld a,b
        cp 3
        jr c,.l
        ret
