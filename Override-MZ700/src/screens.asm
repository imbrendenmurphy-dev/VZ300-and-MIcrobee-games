; =====================================================================
;  screens.asm - title, attract pages, lift, console, end screens,
;                high scores
; =====================================================================

LOGO_ROW        equ 2
PARADE_ROW      equ 13
SCROLL_ROW      equ 23

; ---------------------------------------------------------------------
; page helpers
; ---------------------------------------------------------------------
; wait up to A*25 fields (A half-seconds) for FIRE; NZ = fire pressed.
; Calls (page_fx) every field for animation.
page_wait:
        ld b,a
        ld c,25
        call wait_release_fire
.l:     push bc
        call wait_field
        ld hl,(page_fx)
        call jp_hl
        call read_keys
        pop bc
        and K_FIRE
        ret nz
        ld a,(key_pause)
        or a
        jr z,.n
        or a                        ; CR also starts
        ret
.n:     dec c
        jr nz,.l
        ld c,25
        djnz .l
        xor a
        ret

jp_hl:  jp (hl)

no_fx:  ret

wait_release_fire:
.w:     call poll
        call read_keys
        and K_FIRE
        jr nz,.w
        ret

; ---------------------------------------------------------------------
; title screen
; ---------------------------------------------------------------------
title_screen:
        ld a,(mus_on)
        or a
        jr nz,.playing
        ld hl,SONG_TITLE
        call mus_play
.playing:
        ld a,BLACK
        call cls
        ; logo
        ld hl,LOGO
        ld de,VRAM+LOGO_ROW*40
        ld bc,LOGO_H*40
        ldir
        call logo_colours
        ld hl,txt_sub
        ld c,10
        ld a,CYAN*16
        call print_centre
        ld hl,txt_credit
        ld c,20
        ld a,BLUE*16
        call print_centre
        ld hl,txt_press
        ld c,17
        ld a,WHITE*16
        call print_centre
        ; best score
        ld hl,txt_best
        ld b,10
        ld c,22
        ld a,CYAN*16
        call print_at
        ld hl,HISCORES+5
        ld b,3
        ld c,WHITE*16
        call print_bcd
        inc de
        inc de
        ld hl,HISCORES
        ld b,3
.nm:    ld a,(hl)
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld c,YELLOW*16
        call putc
        inc hl
        inc de
        djnz .nm
        ; stars
        ld hl,STARPOS
        ld b,32
        call zero_b
        ; scroller
        ld hl,scroll_text
        ld (scroll_ptr),hl
        xor a
        ld (scroll_tick),a
        ld (parade_x),a
        ld (logo_phase),a
        ld hl,title_fx
        ld (page_fx),hl
        ld a,40                     ; 20 seconds
        jp page_wait

title_fx:
        ld hl,logo_phase
        inc (hl)
        ld a,(hl)
        and 3
        call z,logo_colours
        ld a,(logo_phase)
        and 1
        call z,parade
        call scroller
        call twinkle
        ; flash "press space"
        ld a,(logo_phase)
        and 16
        ld a,WHITE*16
        jr z,$+4
        ld a,YELLOW*16
        ld de,VRAM+17*40
        ld b,40
        jp fill_attr

; twinkling stars in the empty rows: one of 16 stars moves every field
twinkle:
        call rand
        and 15
        add a,a
        ld e,a
        ld d,0
        ld hl,STARPOS
        add hl,de
        push hl
        ld e,(hl)                   ; old star: erase if still a star
        inc hl
        ld d,(hl)
        ld a,d
        or a
        jr z,.new
        ld a,(de)
        cp 2Eh
        jr nz,.new
        xor a
        ld (de),a
.new:   call rand
        and 7
        ld e,a
        ld d,0
        ld hl,star_rows
        add hl,de
        ld a,(hl)
        ld c,a
        ld b,40
        call rand_below
        ld b,a
        call vaddr                  ; DE = cell
        pop hl
        ld a,(de)
        or a
        jr nz,.busy
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,2Eh
        ld (de),a
        push de
        call rand
        and 3
        ld e,a
        ld d,0
        ld hl,star_cols
        add hl,de
        ld a,(hl)
        pop de
        set 3,d
        ld (de),a
        ret
.busy:  xor a
        ld (hl),a
        inc hl
        ld (hl),a
        ret

star_rows:      db 0,1,9,11,12,15,16,18
star_cols:      db WHITE*16,BLUE*16,CYAN*16,BLUE*16

; logo rows: a fixed gradient with a white glint sweeping down
logo_colours:
        ld a,(logo_phase)
        rrca
        rrca
        and 31
        ld c,a                      ; glint row (0..31, visible 0..6)
        ld de,VRAM+LOGO_ROW*40
        ld hl,logo_grad
        ld b,0
.r:     ld a,b
        cp c
        ld a,(hl)
        jr nz,.nc
        ld a,WHITE*16
.nc:    push bc
        push hl
        ld b,40
        call fill_attr              ; (advances DE by 40)
        pop hl
        pop bc
        inc hl
        inc b
        ld a,b
        cp LOGO_H
        jr c,.r
        ret

logo_grad:
        db YELLOW*16,YELLOW*16,RED*16,RED*16,MAGENTA*16,MAGENTA*16,BLUE*16,BLUE*16

; droids marching across rows 13-14 (drawn in PBUF, then copied)
parade:
        ld hl,parade_x
        inc (hl)
        ld hl,PBUF
        ld b,80
.c:     ld (hl),C_VOID
        inc hl
        djnz .c
        ld c,0
.d:     ld a,c                      ; 11*c + t/2, mod 60
        add a,a
        add a,a
        add a,a
        add a,c
        add a,c
        add a,c
        ld b,a
        ld a,(parade_x)
        srl a
        add a,b
.mod:   cp 60
        jr c,.m
        sub 60
        jr .mod
.m:     ld b,a
        ld a,57
        sub b
        ld b,a                      ; column (may be off-screen)
        push bc
        ld e,c
        ld d,0
        ld hl,parade_types
        add hl,de
        ld a,(hl)
        call parade_droid
        pop bc
        inc c
        ld a,c
        cp 5
        jr c,.d
        ; copy to the screen
        ld a,PARADE_ROW
        call row_addr
        ld de,PBUF
        ld b,80
.cp:    ld a,(de)
        push de
        ld e,a
        ld d,high CHRTAB
        ld a,(de)
        ld (hl),a
        inc d
        ld a,(de)
        call fe_attr
        set 3,h
        ld (hl),a
        res 3,h
        pop de
        inc de
        inc hl
        djnz .cp
        ret

parade_types:
        db 0,4,8,13,18

; A = type, B = column: droid into PBUF
parade_droid:
        push bc
        call roster_ptr
        push hl
        ld de,R_CB
        add hl,de
        ld a,(hl)
        ld (fd_cb),a
        pop hl
        ld de,R_D0
        add hl,de
        ex de,hl                    ; DE = digits
        pop bc
        ld a,(fd_cb)
        ld c,a
        ld a,b
        ld (pd_col),a
        xor a
        ld (pd_row),a
        ld a,c
        call .put
        ld a,(parade_x)
        rrca
        and 3
        push de
        ld e,a
        ld d,0
        ld hl,eyeseq
        add hl,de
        ld a,(hl)
        pop de
        add a,c
        add a,4
        call .put
        ld a,c
        inc a
        call .put
        ld a,(pd_col)
        sub 3
        ld (pd_col),a
        ld a,1
        ld (pd_row),a
        ld b,3
.dg:    ld a,(de)
        add a,c
        add a,7
        call .put
        inc de
        djnz .dg
        ret
.put:   push de
        push hl
        ld e,a
        ld a,(pd_col)
        ld l,a
        inc a
        ld (pd_col),a
        ld a,l
        cp 40
        jr nc,.clip
        ld a,(pd_row)
        or a
        jr z,.r0
        ld a,l
        add a,40
        ld l,a
.r0:    ld h,0
        push de
        ld de,PBUF
        add hl,de
        pop de
        ld (hl),e
.clip:  pop hl
        pop de
        ret
; text scroller on the bottom row
scroller:
        ld hl,scroll_tick
        inc (hl)
        ld a,(hl)
        and 1
        ret nz
        ld hl,VRAM+SCROLL_ROW*40+1
        ld de,VRAM+SCROLL_ROW*40
        ld bc,39
        ldir
        ld hl,(scroll_ptr)
        ld a,(hl)
        or a
        jr nz,.ok
        ld hl,scroll_text
        ld a,(hl)
.ok:    inc hl
        ld (scroll_ptr),hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        ld (VRAM+SCROLL_ROW*40+39),a
        ld a,(scroll_tick)
        and 6
        ret nz
        ld de,VRAM+SCROLL_ROW*40
        ld b,40
        ld a,GREEN*16
        jp fill_attr

; ---------------------------------------------------------------------
; droid gallery: two pages of the roster
; ---------------------------------------------------------------------
roster_pages:
        xor a
        call roster_page
        ret nz
        ld a,10
        call roster_page
        ret

; A = first type (10 types per page, two columns of five)
roster_page:
        push af
        ld a,BLACK
        call cls
        ld hl,txt_gallery
        ld c,0
        ld a,WHITE*16+BLUE
        push hl
        ld b,0
        ld c,1
        call clear_rows
        pop hl
        ld c,0
        ld a,WHITE*16+BLUE
        call print_centre
        pop af
        ld c,a                      ; type
        ld b,0                      ; slot
.e:     ld a,c
        cp NTYPES
        jr nc,.done
        push bc
        ; position: column (slot / 5) * 20, row 2 + (slot mod 5) * 4
        ld a,b
        ld d,0
        cp 5
        jr c,.c0
        sub 5
        ld d,20
.c0:    add a,a
        add a,a
        add a,2
        ld e,a                      ; row
        ld a,c
        call gallery_entry
        pop bc
        inc b
        inc c
        ld a,b
        cp 10
        jr c,.e
.done:  ld hl,no_fx
        ld (page_fx),hl
        ld a,16
        jp page_wait

; A = type, D = column, E = row
gallery_entry:
        ld (ge_type),a
        ld a,d
        ld (ge_col),a
        ld a,e
        ld (ge_row),a
        ld a,(ge_type)
        call roster_ptr
        ld bc,R_CB
        add hl,bc
        ld e,(hl)
        ld a,(ge_type)
        or a
        jr nz,$+4
        ld e,C_DL4                  ; the probe is ours: yellow
        ld a,(ge_col)
        inc a
        ld b,a
        ld a,(ge_row)
        ld c,a
        ld a,(ge_type)
        call fe_droid
        ; name
        ld a,(ge_type)
        call roster_ptr
        ld bc,R_NAME
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(ge_col)
        add a,5
        ld b,a
        ld a,(ge_row)
        ld c,a
        ld a,YELLOW*16
        call print_at
        ; energy and weapon
        ld a,(ge_type)
        call roster_ptr
        push hl
        ld bc,R_WNAME
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(ge_col)
        add a,5
        ld b,a
        ld a,(ge_row)
        inc a
        ld c,a
        ld a,CYAN*16
        call print_at
        pop hl
        ld bc,R_EN
        add hl,bc
        ld a,(hl)
        push af
        ld a,(ge_col)
        add a,5
        ld b,a
        ld a,(ge_row)
        add a,2
        ld c,a
        ld hl,txt_energy
        ld a,GREEN*16
        call print_at
        pop af
        ld c,WHITE*16
        jp print_dec3

; ---------------------------------------------------------------------
; how to play
; ---------------------------------------------------------------------
howto_page:
        ld a,BLACK
        call cls
        ld hl,howto_text
        ld c,0
.l:     ld a,(hl)                   ; first byte: colour
        cp 0FFh
        jr z,.done
        inc hl
        push bc
        rlca
        rlca
        rlca
        rlca
        ld (tmp_attr),a
        push hl
        ld b,1
        call vaddr
        pop hl
        ld a,(tmp_attr)
        ld c,a
        call print
        pop bc
        inc c
        jr .l
.done:  ld hl,no_fx
        ld (page_fx),hl
        ld a,24
        jp page_wait

; ---------------------------------------------------------------------
; high scores
; ---------------------------------------------------------------------
hiscore_init:
        ld hl,hiscore_default
        ld de,HISCORES
        ld bc,64
        ldir
        ret

hiscore_page:
        call hiscore_draw
        ld hl,hs_fx
        ld (page_fx),hl
        ld a,16
        jp page_wait

hs_fx:  ld hl,logo_phase
        inc (hl)
        ld a,(hl)
        and 7
        ret nz
        ld a,(hl)
        and 8
        ld a,YELLOW*16
        jr z,$+4
        ld a,WHITE*16
        ld de,VRAM+5*40
        ld b,40
        jp fill_attr

hiscore_draw:
        ld a,BLACK
        call cls
        ld hl,txt_hiscores
        ld b,0
        ld c,1
        ld a,WHITE*16+BLUE
        push hl
        call clear_rows
        pop hl
        ld c,0
        ld a,WHITE*16+BLUE
        call print_centre
        ld hl,txt_hshead
        ld b,5
        ld c,3
        ld a,CYAN*16
        call print_at
        xor a
        ld (hs_i),a
.e:     ld a,(hs_i)
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,HISCORES
        add hl,de
        ld (hs_ent),hl
        ld a,(hs_i)
        add a,a
        add a,5
        ld c,a
        ld b,5
        call vaddr
        ld a,(hs_i)
        add a,21h
        ld c,WHITE*16
        call putc
        inc de
        ld a,2Eh
        call putc
        inc de
        inc de
        inc de
        ld hl,(hs_ent)
        ld b,3
.n:     ld a,(hl)
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld c,YELLOW*16
        call putc
        inc de
        inc hl
        djnz .n
        inc de
        inc de
        inc de
        inc hl
        inc hl                      ; most significant score byte
        ld b,3
        ld c,WHITE*16
        call print_bcd
        ld a,(hs_i)
        add a,a
        add a,5
        ld c,a
        ld b,26
        call vaddr
        ld hl,txt_ship
        ld c,CYAN*16
        call print
        ld hl,(hs_ent)
        ld bc,6
        add hl,bc
        ld a,(hl)
        add a,21h
        ld c,WHITE*16
        call putc
        ld a,(hs_i)
        inc a
        ld (hs_i),a
        cp 8
        jr c,.e
        ret

; enter the score in the table if it is good enough
hiscore_entry:
        ; find the rank
        ld hl,HISCORES+3+2
        ld b,0
.f:     push hl
        ld a,(score+2)
        cp (hl)
        jr nz,.cmp
        dec hl
        ld a,(score+1)
        cp (hl)
        jr nz,.cmp
        dec hl
        ld a,(score)
        cp (hl)
.cmp:   pop hl
        jr z,.next
        jr nc,.found
.next:  ld de,8
        add hl,de
        inc b
        ld a,b
        cp 8
        jr c,.f
        ret                         ; not good enough
.found: ld a,b
        ld (hiscore_rank),a
        ; shift lower entries down
        ld a,7
        sub b
        jr z,.ins
        ld c,a
        ld b,0
        sla c
        sla c
        sla c                       ; bytes to move
        ld hl,HISCORES+7*8-1
        ld de,HISCORES+8*8-1
        lddr
.ins:   ld a,(hiscore_rank)
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,HISCORES
        add hl,de
        ld (hs_ptr),hl
        ld (hl),'A'
        inc hl
        ld (hl),'A'
        inc hl
        ld (hl),'A'
        inc hl
        ld a,(score)
        ld (hl),a
        inc hl
        ld a,(score+1)
        ld (hl),a
        inc hl
        ld a,(score+2)
        ld (hl),a
        inc hl
        ld a,(ship)
        ld (hl),a
        inc hl
        ld a,(deck)
        ld (hl),a
        ld hl,SONG_TITLE
        call mus_play
        call hiscore_draw
        ld hl,txt_entername
        ld c,21
        ld a,GREEN*16
        call print_centre
        ld hl,txt_enterhelp
        ld c,22
        ld a,CYAN*16
        call print_centre
        ; name entry: up/down letter, fire next, 3 letters
        xor a
        ld (hs_pos),a
        call wait_release_fire
        call fe_reset
.loop:  call wait_field
        ld hl,logo_phase
        inc (hl)
        call hs_draw_name
        call fe_keys
        ld b,a
        bit B_UP,b
        jr z,.nu
        call .cur
        ld a,(hl)
        cp ' '
        jr nz,.u1
        ld a,'A'
        jr .su
.u1:    cp 'Z'
        jr nz,.u2
        ld a,' '
        jr .su
.u2:    inc a
.su:    ld (hl),a
        call .click
.nu:    bit B_DOWN,b
        jr z,.nd
        call .cur
        ld a,(hl)
        cp ' '
        jr nz,.d1
        ld a,'Z'
        jr .sd
.d1:    cp 'A'
        jr nz,.d2
        ld a,' '
        jr .sd
.d2:    dec a
.sd:    ld (hl),a
        call .click
.nd:    bit B_FIRE,b
        jr z,.loop
        ld hl,SFX_PULSE
        ld a,1
        call sfx
        ld hl,hs_pos
        inc (hl)
        ld a,(hl)
        cp 3
        jr c,.loop
        call hiscore_draw
        ld hl,txt_welldone
        ld c,21
        ld a,YELLOW*16
        call print_centre
        ld a,6
        call page_wait_nofx
        call mus_stop
        ret
.click: push bc
        ld hl,SFX_CLICK
        ld a,1
        call sfx
        pop bc
        ret
.cur:   ld hl,(hs_ptr)
        ld a,(hs_pos)
        ld e,a
        ld d,0
        add hl,de
        ret

page_wait_nofx:
        ld hl,no_fx
        ld (page_fx),hl
        jp page_wait

; flash the name being entered
hs_draw_name:
        ld a,(hiscore_rank)
        add a,a
        add a,5
        ld c,a
        ld b,9
        call vaddr
        ld hl,(hs_ptr)
        ld b,0
.l:     ld a,(hl)
        push hl
        ld l,a
        ld h,high ATOD
        ld a,(hl)
        pop hl
        ld (de),a
        set 3,d
        ld a,(hs_pos)
        cp b
        ld a,YELLOW*16
        jr nz,.n
        ld a,(logo_phase)
        and 4
        ld a,WHITE*16+RED
        jr z,.n
        ld a,BLACK*16+YELLOW
.n:     ld (de),a
        res 3,d
        inc hl
        inc de
        inc b
        ld a,b
        cp 3
        jr c,.l
        ret

; ---------------------------------------------------------------------
; end screens
; ---------------------------------------------------------------------
game_over_screen:
        call sfx_stop
        ld hl,SONG_GAMEOVER
        call mus_play
        ld a,BLACK
        call cls
        ld hl,txt_gameover
        ld c,9
        ld a,RED*16
        call print_centre
        call show_final
        ld a,12
        call page_wait_nofx
        call mus_stop
        ret

show_final:
        ld hl,txt_finalscore
        ld b,12
        ld c,13
        ld a,CYAN*16
        call print_at
        ld hl,score+2
        ld b,3
        ld c,WHITE*16
        jp print_bcd

ship_clear_screen:
        call sfx_stop
        ld hl,SONG_SHIP
        call mus_play
        ld a,BLACK
        call cls
        ld hl,txt_shipclear
        ld c,8
        ld a,YELLOW*16
        call print_centre
        ld hl,txt_shipbonus
        ld c,11
        ld a,GREEN*16
        call print_centre
        ld de,5000h
        call add_score
        call show_final
        ld hl,txt_nextship
        ld c,17
        ld a,CYAN*16
        call print_centre
        ld a,12
        call page_wait_nofx
        call mus_stop
        ret

victory_screen:
        call sfx_stop
        ld hl,SONG_VICTORY
        call mus_play
        ld a,BLACK
        call cls
        ld hl,txt_victory1
        ld c,6
        ld a,YELLOW*16
        call print_centre
        ld hl,txt_victory2
        ld c,9
        ld a,WHITE*16
        call print_centre
        ld hl,txt_victory3
        ld c,10
        ld a,WHITE*16
        call print_centre
        ld de,9999h
        call add_score
        call show_final
        ld a,30
        call page_wait_nofx
        call mus_stop
        ret

; ---------------------------------------------------------------------
; boarding a ship: its side view and a briefing
; ---------------------------------------------------------------------
ship_intro:
        ld a,(demo)
        or a
        ret nz
        call sfx_stop
        ld hl,SONG_BOARD
        call mus_play
        xor a
        ld (lift_sel),a
        ld (lift_shaft),a
        call lift_draw
        ld b,19
        ld c,5
        xor a
        call clear_rows
        ld hl,txt_boarding
        ld c,19
        ld a,YELLOW*16
        call print_centre
        ld a,(ship)
        add a,21h
        ld (VRAM+19*40+30),a
        ld hl,txt_brief1
        ld c,21
        ld a,CYAN*16
        call print_centre
        ld hl,txt_brief2
        ld c,22
        ld a,CYAN*16
        call print_centre
        ld a,10
        call page_wait_nofx
        call mus_stop
        ret

; ---------------------------------------------------------------------
; lift: pick a deck along the current shaft
; ---------------------------------------------------------------------
lift_screen:
        call sfx_stop
        ld a,(deck)
        ld (lift_sel),a
        call lift_draw
        ld hl,SFX_LIFT
        ld a,2
        call sfx
        xor a
        ld (lift_ai_t),a
        call fe_reset
.loop:  call wait_frame
        ld hl,frame
        inc (hl)
        call lift_draw_sel
        ld a,(demo)
        or a
        jr z,.kb
        call lift_ai
        jr .k
.kb:    call fe_keys
.k:     ld b,a
        bit B_UP,b
        jr z,.nu
        ld c,-1
        call lift_move
.nu:    bit B_DOWN,b
        jr z,.nd
        ld c,1
        call lift_move
.nd:    bit B_FIRE,b
        jr z,.loop
        ld a,(event)
        cp EV_QUIT
        ret z
        ld hl,SFX_LIFT
        ld a,2
        call sfx
        ld a,(lift_sel)
        ret

; C = -1 / +1: next deck in that direction that the shaft reaches
lift_move:
        ld a,(lift_sel)
.l:     add a,c
        cp 0FFh
        ret z
        ld hl,ndecks
        cp (hl)
        ret nc
        push af
        push bc
        ld e,a
        ld a,(lift_shaft)
        ld d,a
        ld a,e
        ld e,d
        call deck_has_shaft
        pop bc
        jr c,.ok
        pop af
        jr .l
.ok:    pop af
        push af
        ld a,(lift_sel)
        call lift_draw_deck_plain
        pop af
        ld (lift_sel),a
        call lift_draw_info
        ld hl,SFX_CLICK
        ld a,1
        jp sfx

; A = deck, E = shaft: carry if the deck has a pad on that shaft (E kept)
deck_has_shaft:
        call deck_ptr
        push hl
        pop iy
        ld b,(iy+DK_NLIFT)
        ld l,(iy+DK_LIFTS)
        ld h,(iy+DK_LIFTS+1)
        inc hl
        inc hl
        ld a,e
.l:     cp (hl)
        scf
        ret z
        inc hl
        inc hl
        inc hl
        inc hl
        djnz .l
        or a
        ret

lift_draw:
        ld a,BLACK
        call cls
        ; ship name
        ld hl,(ship_hdr)
        ld de,SH_NAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,0
        ld a,WHITE*16+BLUE
        push hl
        ld b,0
        ld c,1
        call clear_rows
        pop hl
        ld c,0
        ld a,WHITE*16+BLUE
        call print_centre
        ; decks
        ld a,(ndecks)
        ld b,a
        ld c,0
.d:     push bc
        ld a,c
        call lift_draw_deck_plain
        pop bc
        inc c
        djnz .d
        ; shafts: a line in the gap between two decks it connects
        ld hl,(ship_hdr)
        ld de,SH_NSHAFT
        add hl,de
        ld a,(hl)
        ld (ls_n),a
        inc hl
        ld (ls_ptr),hl
        xor a
        ld (ls_shaft),a
.s:     ld hl,(ls_ptr)
        ld a,(ls_shaft)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        srl a
        inc a
        ld (ls_col),a
        xor a
        ld (ls_deck),a
.sr:    ld a,(ls_shaft)
        ld e,a
        ld a,(ls_deck)
        call deck_has_shaft
        jr nc,.ns
        ld a,(ls_deck)
        inc a
        ld hl,ndecks
        cp (hl)
        jr nc,.ns
        call deck_has_shaft
        jr nc,.ns
        ld a,(ls_deck)
        add a,a
        add a,LIFT_TOP+1
        ld c,a
        ld a,(ls_col)
        ld b,a
        call vaddr
        ld a,(ls_shaft)
        ld hl,lift_shaft
        cp (hl)
        ld c,WHITE*16
        jr z,$+4
        ld c,BLUE*16
        ld a,79h
        call putc
.ns:    ld a,(ls_deck)
        inc a
        ld (ls_deck),a
        ld hl,ndecks
        cp (hl)
        jr c,.sr
        ld a,(ls_shaft)
        inc a
        ld (ls_shaft),a
        ld hl,ls_n
        cp (hl)
        jr c,.s
        ld hl,txt_lifthelp
        ld c,23
        ld a,CYAN*16
        call print_centre
        jp lift_draw_info

LIFT_TOP        equ 3

; A = deck: draw its bar (colour by state)
lift_draw_deck_plain:
        ld (ld_deck),a
        call deck_ptr
        push hl
        pop iy
        ld a,(ld_deck)
        call dstate_ptr
        ld a,(de)
        or a
        ld a,CYAN*16+BLACK
        jr z,$+4
        ld a,BLUE*16+BLACK
        ld (ld_attr),a
lift_bar:
        ld a,(ld_deck)
        add a,a
        add a,LIFT_TOP
        ld c,a
        ld a,(iy+DK_OFF)
        srl a
        inc a
        ld b,a
        call vaddr
        ld a,(iy+DK_W)
        srl a
        ld b,a
.l:     ld a,43h
        ld (de),a
        set 3,d
        ld a,(ld_attr)
        ld (de),a
        res 3,d
        inc de
        djnz .l
        ret

; highlight the selected deck with the car
lift_draw_sel:
        ld a,(lift_sel)
        ld (ld_deck),a
        call deck_ptr
        push hl
        pop iy
        ld a,(frame)
        and 4
        ld a,YELLOW*16+BLACK
        jr z,$+4
        ld a,WHITE*16+BLACK
        ld (ld_attr),a
        call lift_bar
        ; car on the shaft
        ld hl,(ship_hdr)
        ld de,SH_NSHAFT+1
        add hl,de
        ld a,(lift_shaft)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        srl a
        inc a
        ld b,a
        ld a,(lift_sel)
        add a,a
        add a,LIFT_TOP
        ld c,a
        call vaddr
        ld a,47h
        ld (de),a
        set 3,d
        ld a,RED*16+BLACK
        ld (de),a
        ret

; deck name and status under the ship
lift_draw_info:
        ld b,19
        ld c,3
        xor a
        call clear_rows
        ld a,(lift_sel)
        call deck_ptr
        ld de,DK_NAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,19
        ld a,YELLOW*16
        call print_centre
        ld a,(lift_sel)
        call dstate_ptr
        ld a,(de)
        or a
        ld hl,txt_lift_clear
        jr nz,.p
        ; droids left there
        inc de
        ld a,(de)
        ld b,a
        inc de
        ld c,0
.cnt:   ld a,(de)
        cp 0FFh
        jr z,$+3
        inc c
        push hl
        ld hl,DSRECSZ
        add hl,de
        ex de,hl
        pop hl
        djnz .cnt
        ld a,c
        ld (ld_count),a
        ld hl,txt_lift_droids
.p:     ld c,20
        ld a,CYAN*16
        call print_centre
        ld a,(lift_sel)
        call dstate_ptr
        ld a,(de)
        or a
        ret nz
        ; number in front of "DROIDS ACTIVE"
        ld de,VRAM+20*40+12
        ld a,(ld_count)
        ld c,WHITE*16
        jp print_dec3

; demo: ride to the nearest deck with droids left, then get out
lift_ai:
        call anykey
        jr z,.nk
        ld a,1
        ld (demo_abort),a
        ld a,EV_QUIT
        ld (event),a
        ld a,K_FIRE
        ret
.nk:    ld hl,lift_ai_t
        inc (hl)
        ld a,(hl)
        cp 20
        jr c,.wait
        ld (hl),12
        ld a,(lift_sel)
        call dstate_ptr
        ld a,(de)
        or a
        jr nz,.move
        ld a,(lift_sel)
        ld hl,deck
        cp (hl)
        jr nz,.go
.move:  ; try down first, then up
        ld a,(lift_sel)
        ld (ls_save),a
        ld c,1
        call lift_move
        ld a,(lift_sel)
        ld hl,ls_save
        cp (hl)
        jr nz,.wait
        ld c,-1
        call lift_move
        ld a,(lift_sel)
        ld hl,ls_save
        cp (hl)
        jr nz,.wait
.go:    ld a,K_FIRE
        ret
.wait:  xor a
        ret

; ---------------------------------------------------------------------
; console: deck map and host data
; ---------------------------------------------------------------------
console_screen:
        call sfx_stop
        ld hl,SFX_CONSOLE
        ld a,2
        call sfx
        ld a,BLACK
        call cls
        ld hl,txt_console
        ld b,0
        ld c,1
        ld a,BLACK*16+GREEN
        push hl
        call clear_rows
        pop hl
        ld c,0
        ld a,BLACK*16+GREEN
        call print_centre
        ; deck name
        ld hl,(deck_hdr)
        ld de,DK_NAME
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,2
        ld a,YELLOW*16
        call print_centre
        call console_map
        call console_host
        ld hl,console_fx
        ld (page_fx),hl
        ld a,60
        call page_wait
        call wait_release_fire
        ret

; deck map, two cells per quarter block, rows 4..18
console_map:
        ld hl,(deck_hdr)
        ld a,(hl)
        inc a
        srl a
        ld (cm_w),a
        inc hl
        ld a,(hl)
        inc a
        srl a
        ld (cm_h),a
        ld a,(cm_w)
        ld b,a
        ld a,40
        sub b
        srl a
        ld (cm_x0),a
        ld c,0                      ; char row
.r:     ld b,0                      ; char col
.c:     push bc
        ; mask from the four cells (2b+i, 2c+j)
        ld a,b
        add a,a
        add a,MX0
        ld d,a
        ld a,c
        add a,a
        add a,MY0
        ld e,a
        ld h,0                      ; mask
        push bc
        ld b,d
        ld c,e
        call cm_wall
        jr z,$+4
        set 0,h
        inc b
        call cm_wall
        jr z,$+4
        set 1,h
        dec b
        inc c
        call cm_wall
        jr z,$+4
        set 2,h
        inc b
        call cm_wall
        jr z,$+4
        set 3,h
        pop bc
        ld a,h
        push af
        ld a,(cm_x0)
        add a,b
        ld b,a
        ld a,c
        add a,4
        ld c,a
        call vaddr
        pop af
        or 0F0h
        ld (de),a
        set 3,d
        ld a,CYAN*16
        ld (de),a
        pop bc
        inc b
        ld a,(cm_w)
        cp b
        jr nz,.c
        call poll
        inc c
        ld a,(cm_h)
        cp c
        jr nz,.r
        ret

; NZ if map cell (B,C) is a wall (solid but not void, not a droid)
cm_wall:
        push hl
        call cell_flags
        pop hl
        ld l,a
        and F_VOID
        ld a,l
        jr z,$+3
        xor a
        and F_SOLID
        ret

; blink droids on the map
console_fx:
        ld hl,logo_phase
        inc (hl)
        ld a,(hl)
        and 7
        ret nz
        ld ix,DROIDS
        ld b,NDROIDS
.l:     push bc
        ld a,(ix+D_TYPE)
        cp 0FFh
        jr z,.n
        ld a,(ix+D_X)
        sub MX0-1
        srl a
        ld b,a
        ld a,(cm_x0)
        add a,b
        ld b,a
        ld a,(ix+D_Y)
        sub MY0
        srl a
        add a,4
        ld c,a
        call vaddr
        ld a,(logo_phase)
        and 8
        jr z,.off
        ld a,47h
        ld (de),a
        set 3,d
        push ix
        pop hl
        ld a,l
        cp low DROIDS
        ld a,RED*16
        jr nz,$+4
        ld a,YELLOW*16
        ld (de),a
        jr .n
.off:   ld a,0F0h
        ld (de),a
        set 3,d
        ld a,CYAN*16
        ld (de),a
.n:     ld bc,DSZ
        add ix,bc
        pop bc
        djnz .l
        ret

; host droid data at the bottom
console_host:
        ld a,(DROIDS+D_TYPE)
        ld b,1
        ld c,20
        ld e,C_DL4
        call fe_droid
        ld a,(DROIDS+D_TYPE)
        call roster_ptr
        push hl
        ld bc,R_NAME
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,6
        ld c,20
        ld a,YELLOW*16
        call print_at
        pop hl
        push hl
        ld bc,R_TXT1
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,6
        ld c,21
        ld a,WHITE*16
        call print_at
        pop hl
        ld bc,R_TXT2
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,6
        ld c,22
        ld a,WHITE*16
        call print_at
        ; enemies left
        ld hl,txt_con_left
        ld b,24
        ld c,20
        ld a,CYAN*16
        call print_at
        push de
        call count_enemies
        pop de
        ld c,WHITE*16
        jp print_dec3
