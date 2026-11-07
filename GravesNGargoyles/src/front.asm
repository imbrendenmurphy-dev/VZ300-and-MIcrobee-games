; ============================================================================
;  FRONT END: title, attract mode, menu, story, cards, high scores, demo
; ============================================================================

front_main:
        call title_screen       ; returns A: 0 = start (menu), 1 = idle -> attract
        or a
        jr nz,.attract
.menu:  call menu_screen        ; returns A: 0 start game, 1 back to title
        or a
        jr nz,front_main
        call run_game
        jr front_main
.attract:
        call attract
        or a
        jr nz,front_main        ; finished without input
        jr .menu

; full-screen presentation frame: FB rows 0..63 -> screen
show_full:
        xor a
        ld (hud_mode),a
        ld a,1
        ld (top_dirty),a
        jp frame_end

; clear FB to sky colour
fb_fill:
        jp cls_fb

; ---------------------------------------------------------------- run game
run_game:
        call new_game
        ld a,(cur_stage)
        cp 1
        call z,story_card       ; the story only when starting from the beginning
.stage: call stage_card
        call play_stage
        push af
        call css_reset
        pop af
        or a
        jr z,.clear
        cp 1
        jr z,.over
        ret
.clear: call clear_card         ; advances cur_stage, shows the password
        ld a,(cur_stage)
        cp 8
        jr nc,.end
        call stage_reset
        jr .stage
.end:   call ending_card
        jp hiscore_check
.over:  call gameover_card      ; A = 1 continue
        or a
        jp z,hiscore_check
        ; continue: keep armour progress, reset score and lives
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld a,(opt_diff)
        ld e,a
        ld d,0
        ld hl,START_LIVES
        add hl,de
        ld a,(hl)
        ld (lives),a
        jr .stage

; ---------------------------------------------------------------- title
title_screen:
        call ensure_front
        call stop_music
        call unpack_title
        xor a
        ld (t_t),a
        ld (t_t+1),a
        ld (logo_y),a
        ld hl,-30
        ld (bat1_x),hl
        ld hl,160
        ld (bat2_x),hl
        ld a,$28
        ld (latch_next),a
        ld hl,SONG_TITLE
        call play_song
.lp:    ld hl,(t_t)
        inc hl
        ld (t_t),hl
        ; darkness for the first second, then lightning reveals the castle
        ld a,h
        or a
        jr nz,.lit
        ld a,l
        cp 40
        jr nc,.lit
        call cls_fb
        jp .show
.lit:   ld a,h
        or a
        jr nz,.nfl
        ld a,l
        cp 40
        jr nz,.nfl
        ld a,6
        ld (flash_t),a
        ld a,SFX_THUNDER_ID
        call play_sfx
.nfl:   call copy_title
        call flicker_windows
        call title_bats
        call title_ghost
        ; logo descends
        ld hl,(t_t)
        ld a,h
        or a
        jr nz,.lg
        ld a,l
        cp 60
        jr c,.nlogo
.lg:    ld a,(logo_y)
        cp 4
        jr nc,.lgd
        inc a
        ld (logo_y),a
        ld a,1
        ld (top_dirty),a
.lgd:   call draw_logo
        ; prompt + credits once settled
        ld hl,(t_t)
        ld a,h
        or a
        jr nz,.pr
        ld a,l
        cp 100
        jr c,.nlogo
.pr:    ld a,(t_t)
        and 16
        jr z,.np
        ld hl,STR_PRESS
        ld c,46
        ld a,(col_yel)
        call text_fbc
.np:    ld hl,STR_COPY
        ld c,58
        ld a,(col_yel)
        call text_fbc
.nlogo: ; random lightning
        call rand
        cp 3
        jr nc,.nr
        ld a,4
        ld (flash_t),a
        ld a,SFX_THUNDER_ID
        call play_sfx
.nr:
.show:  call fx_palette
        ld a,(t_t)
        and 7
        jr nz,.nt
        ld a,1
        ld (top_dirty),a
.nt:    call show_full
        ; input
        call read_input
        ld a,(keys_new)
        and (1<<K_FIRE)|(1<<K_SWAP)
        jr z,.ni
        ld a,SFX_SELECT_ID
        call play_sfx
        xor a
        ret
.ni:    ld hl,(t_t)
        ld de,900
        or a
        sbc hl,de
        jp c,.lp
        ld a,1
        ret

; unpack the RLE title art into SRAM
unpack_title:
        call unpack_logo
        ld hl,TITLE_RLE
        ld de,TITLEBUF
.lp:    ld a,(hl)
        inc hl
        or a
        ret z
        bit 7,a
        jr nz,.lit
        ld b,a
        ld a,(hl)
        inc hl
.run:   ld (de),a
        inc de
        djnz .run
        jr .lp
.lit:   and $7F
        ld b,a
.l2:    ld a,(hl)
        inc hl
        ld (de),a
        inc de
        djnz .l2
        jr .lp

; rebuild the logo sprite (mask + data) from its pixel data
unpack_logo:
        ld hl,LOGO_DAT
        ld de,LOGOBUF
        ld bc,LOGO_W*LOGO_H
.lp:    push bc
        ld a,(hl)
        ld c,a
        ld b,4
        ld a,0
.px:    rlca
        rlca
        rlc c
        rlc c
        push af
        ld a,c
        and 3
        jr nz,.op
        pop af
        or 3
        jr .nx
.op:    pop af
.nx:    djnz .px
        ld (de),a               ; mask (11 where transparent)
        inc de
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,.lp
        ret

copy_title:
        ld hl,TITLEBUF
        ld de,FB+4
        ld b,64
.r:     push bc
        call LDI32
        ex de,hl
        ld bc,FBW-32
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
        ret

draw_stars:
        ld hl,TITLEBUF
        ld de,FB+4
        ld b,24
.r:     push bc
        ld b,32
.c:     ld a,(hl)
        ld c,a
        ld a,(col_sky)
        cp c
        jr z,.s
        ; keep only yellow pixels on blue (stars) - approximate: copy if
        ; the byte differs from sky in a single pixel
        ld a,c
        xor $AA
        and $AA
        ld a,(col_sky)
        jr nz,.s
        ld a,c
.s:     ld (de),a
        inc hl
        inc de
        djnz .c
        ex de,hl
        ld bc,FBW-32
        add hl,bc
        ex de,hl
        pop bc
        djnz .r
        ret

flicker_windows:
        ld hl,TITLE_WINS
.lp:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        cp $FF
        ret z
        ld c,(hl)               ; pixel mask
        inc hl
        push hl
        push de
        call rand
        pop de
        pop hl
        and 7
        jr nz,.lp
        ; this window goes dark for a frame (red = castle colour)
        push hl
        ex de,hl
        ; row/col -> FB address: offset = y*32+x ; FB = FB + y*40 + 4 + x
        ld a,l
        and 31
        ld e,a
        ld d,0
        add hl,hl
        add hl,hl
        add hl,hl               ; y*256 + ...
        ld l,h
        ld h,0                  ; y
        push de
        add hl,hl
        ld de,YTAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        add hl,de
        ld de,4
        add hl,de
        ld a,(col_red)
        and c
        ld b,a
        ld a,c
        cpl
        and (hl)
        or b
        ld (hl),a
        ld de,FBW
        add hl,de
        ld a,c
        cpl
        and (hl)
        or b
        ld (hl),a
        pop hl
        jr .lp

title_bats:
        ld hl,(bat1_x)
        inc hl
        inc hl
        ld (bat1_x),hl
        ld de,200
        or a
        sbc hl,de
        jr c,.b1
        ld hl,-40
        ld (bat1_x),hl
.b1:    ld hl,(bat2_x)
        dec hl
        dec hl
        ld (bat2_x),hl
        ld a,h
        cp $FF
        jr nz,.b2
        ld a,l
        cp -60
        jr nc,.b2
        ld hl,190
        ld (bat2_x),hl
.b2:    ld hl,F_BAT_0
        ld a,(t_t)
        and 4
        jr z,$+5
        ld hl,F_BAT_1
        push hl
        ld bc,(bat1_x)
        ld a,(t_t)
        and 15
        cp 8
        jr c,$+4
        neg
        add a,24
        sra a
        add a,16
        ld e,0
        call draw_spr
        pop hl
        ld bc,(bat2_x)
        ld a,(t_t)
        rrca
        and 7
        add a,30
        ld e,1
        jp draw_spr

title_ghost:
        ld hl,(t_t)
        ld a,h
        or a
        jr nz,.on
        ld a,l
        cp 80
        ret c
.on:    ld a,(t_t)
        and 3
        ret z
        ld hl,F_GHOST_0
        ld a,(t_t)
        and 8
        jr z,$+5
        ld hl,F_GHOST_1
        ld a,(t_t)
        rrca
        rrca
        rrca
        and 3
        add a,30
        ld bc,62
        ld e,0
        jp draw_spr

draw_logo:
        ; logo sprite, masked, at row logo_y (screen), byte column 1
        ld a,(logo_y)
        add a,a
        ld l,a
        ld h,YTAB>>8
        set 7,l                 ; YTAB is at $7D80
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld de,LOGO_X
        add hl,de
        ld de,LOGOBUF
        ld b,LOGO_H
.r:     push bc
        push hl
        ld b,LOGO_W
.c:     ld a,(de)
        inc de
        and (hl)
        ld c,a
        ld a,(de)
        inc de
        or c
        ld (hl),a
        inc hl
        djnz .c
        pop hl
        ld bc,FBW
        add hl,bc
        pop bc
        djnz .r
        ret

; ---------------------------------------------------------------- menu
MENU_N equ 7
menu_screen:
        call ensure_front
        call unpack_title
        xor a
        ld (menu_sel),a
        ld (t_t),a
.lp:    ld hl,t_t
        inc (hl)
        call menu_bg
        ld hl,STR_MENUTITLE
        ld c,12
        ld a,(col_yel)
        call text_fbc
        ; items
        ld b,0
.it:    push bc
        ld a,b
        add a,a
        ld c,a
        add a,a
        add a,c                 ; *6
        add a,20
        ld c,a
        ld a,(menu_sel)
        cp b
        ld a,(col_grn)
        jr nz,$+5
        ld a,(col_yel)
        push af
        push bc
        call menu_item          ; HL = item string
        pop bc
        pop af
        call text_fbc
        pop bc
        inc b
        ld a,b
        cp MENU_N
        jr c,.it
        call show_full
        call read_input
        ld a,(keys_new)
        bit K_UP,a
        jr z,.nu
        ld a,(menu_sel)
        or a
        jr z,.nu
        dec a
        ld (menu_sel),a
        call .tick
.nu:    ld a,(keys_new)
        bit K_DOWN,a
        jr z,.nd
        ld a,(menu_sel)
        cp MENU_N-1
        jr nc,.nd
        inc a
        ld (menu_sel),a
        call .tick
.nd:    ld a,(keys_new)
        and (1<<K_FIRE)|(1<<K_LEFT)|(1<<K_RIGHT)|(1<<K_SWAP)
        jp z,.lp
        call .tick
        ld a,(menu_sel)
        or a
        jr nz,.n0
        ret                     ; start
.n0:    dec a
        jr nz,.n1
        call password_screen
        ret nc                  ; valid password: start the game
        jp .lp
.n1:    cp 1
        jr nz,.n2
        ld a,(opt_diff)
        inc a
        cp 3
        jr c,$+3
        xor a
        ld (opt_diff),a
        jp .lp
.n2:
.n3:    cp 2
        jr nz,.n4
        ld a,(opt_music)
        xor 1
        ld (opt_music),a
        jp .lp
.n4:    cp 3
        jr nz,.n5
        call controls_card
        jp .lp
.n5:    cp 4
        jr nz,.n6
        call hiscore_card
        jp .lp
.n6:    call credits_card
        jp .lp
.tick:  ld a,SFX_SELECT_ID
        jp play_sfx

; B = item -> HL = string (built in num_buf for options)
menu_item:
        ld a,b
        or a
        ld hl,STR_M_START
        ret z
        dec a
        ld hl,STR_M_PASS
        ret z
        cp 1
        jr nz,.i2
        ld hl,STR_M_DIFF
        ld de,DIFFNAMES
        ld a,(opt_diff)
        jr .cat
.i2:
.i3:    cp 2
        jr nz,.i4
        ld hl,STR_M_MUSIC
        ld de,ONOFF
        ld a,(opt_music)
        xor 1
        jr .cat
.i4:    cp 3
        ld hl,STR_M_CTRL
        ret z
        cp 4
        ld hl,STR_M_HIGH
        ret z
        ld hl,STR_M_CRED
        ret
.cat:   ; copy label then option name into text_buf
        push af
        push de
        ld de,text_buf
.c1:    ld a,(hl)
        or a
        jr z,.c2
        ld (de),a
        inc hl
        inc de
        jr .c1
.c2:    pop hl                  ; option table
        pop af
        add a,a
        ld c,a
        ld b,0
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
.c3:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.c3
        ld hl,text_buf
        ret

menu_bg:
        call copy_title
        ; darken a panel: dither rows 10..61 with the sky
        ld b,52
        ld hl,FB+10*FBW+4+3
.r:     push bc
        push hl
        ld b,26
.c:     ld a,(col_sky)
        ld (hl),a
        inc hl
        djnz .c
        pop hl
        ld bc,FBW
        add hl,bc
        pop bc
        djnz .r
        ret

; ---------------------------------------------------------------- cards
; clear FB for a card: sky with a sparse dotted graveyard drifting slowly
; up and left behind it (a 32x32 tile of single dots, repeated 4x2)
cls_card:
        call cls_fb
        ld a,(col_sky)
        ld (txt_op),a
        ld hl,bg_t
        inc (hl)
        ld a,(hl)
        rrca
        and 31
        ld (cc_ox+1),a
        ld a,(hl)
        rrca
        rrca
        and 31
        ld (cc_oy+1),a
        ld hl,DOTS
        ld b,NDOTS
cc_dot: push bc
        ld a,(hl)
        inc hl
cc_ox:  add a,0
        and 31
        ld c,a                  ; x in tile
        ld a,(hl)
        inc hl
cc_oy:  add a,0
        and 31                  ; y in tile
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; y*40
        ld a,c
        rrca
        rrca
        and 7
        add a,4
        ld e,a
        ld d,FB>>8
        add hl,de               ; FB is page aligned
        ld a,c
        and 3
        ld e,a
        ld d,0
        push hl
        ld hl,DMASK
        add hl,de
        ld c,(hl)
        pop hl
        ld b,2
.row:   push hl
        ld e,4
.col:   ld a,(hl)
        and c                   ; a colour-0 dot
        ld (hl),a
        ld a,l
        add a,8
        ld l,a
        jr nc,$+3
        inc h
        dec e
        jr nz,.col
        pop hl
        ld de,32*FBW
        add hl,de
        djnz .row
        pop hl
        pop bc
        djnz cc_dot
        ret
DMASK:  db $3F,$CF,$F3,$FC
; tile dots (x,y): a tall stone with a cross, a small stone, a little dust
DOTS:   db 6,5, 8,5, 5,7, 9,7, 7,8, 5,9, 9,9
        db 3,11, 5,11, 7,11, 9,11, 11,11
        db 21,21, 20,23, 22,23, 20,25, 22,25
        db 19,27, 21,27, 23,27
        db 28,4, 13,18, 2,24
NDOTS   equ ($-DOTS)/2
; card_text: HL = list of (row, colour index, string) terminated by $FF
; colour index: 0 yellow 1 red 2 green
card_text:
.lp:    ld a,(hl)
        cp $FF
        ret z
        ld c,a
        inc hl
        ld a,(hl)
        inc hl
        push hl
        add a,a
        ld e,a
        ld d,0
        ld hl,CARDCOL
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(de)
        pop hl
        push hl
        push af
        ; skip to end of string after drawing
        pop af
        call text_fbc
        pop hl
.sk:    ld a,(hl)
        inc hl
        or a
        jr nz,.sk
        jr .lp
CARDCOL: dw col_yel,col_red,col_grn

; show a card until fire or timeout: HL = timeout frames, DE = routine that
; draws the card (redrawn every frame over the panning graveyard backdrop)
card_wait:
        ld (cw_t),hl
        ld (cw_draw),de
.lp:    call cls_card
        ld hl,.drawn
        push hl
        ld hl,(cw_draw)
        jp (hl)
.drawn: call show_full
        call read_input
        ld a,(keys_new)
        and (1<<K_FIRE)|(1<<K_SWAP)
        ret nz
        ld hl,(cw_t)
        dec hl
        ld (cw_t),hl
        ld a,h
        or l
        jr nz,.lp
        ret

story_card:
        ld hl,STORY1
        call story_page
        ret nz
        ld hl,STORY2
        call story_page
        ret nz
        ld hl,STORY3
        jp story_page

; story page with a small knight walking along the bottom -> NZ if fire
story_page:
        ld (sp_txt),hl
        xor a
        ld (t_t),a
.lp:    call cls_card
        ld hl,(sp_txt)
        call card_text
        ; ground strip
        ld hl,FB+56*FBW+4
        ld b,32
        ld a,(col_grn)
.g:     ld (hl),a
        inc hl
        djnz .g
        ; walking knight
        ld a,(t_t)
        ld c,a
        ld b,0
        ld a,(t_t)
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        ld hl,RUNSEQ
        add hl,de
        ld a,(hl)
        ld l,a
        add a,a
        add a,l
        add a,a
        ld e,a
        ld hl,HERO_DESC
        add hl,de
        ld a,40                 ; screen y 48 = world 40
        ld e,0
        call draw_spr
        ld hl,t_t
        inc (hl)
        inc (hl)
        call show_full
        call read_input
        ld a,(keys_new)
        and (1<<K_FIRE)|(1<<K_SWAP)
        ret nz
        ld a,(t_t)
        cp 250
        jr c,.lp
        xor a
        ret

stage_card:
        call ensure_stage
        call stop_music
        call build_hero
        ld de,.d
        ld hl,150
        jp card_wait
.d:     ld hl,(STG_CARD)
        call card_text
        ; a portrait of the stage's guardian
        ld hl,(STG_PORT)
        ld bc,58
        ld a,22
        ld e,0
        jp draw_spr

clear_card:
        call stop_music
        ld hl,SONG_J_CLEAR
        call play_song
        ld a,$30
        call add_score_k
        ld hl,cur_stage
        inc (hl)
        ld a,(hl)
        cp 8
        call c,pw_encode        ; the password for the next stage
        ld de,.d
        ld hl,400
        jp card_wait
.d:     ld hl,CARD_CLEAR
        call card_text
        ; "SUNSTONE n OF 7"
        ld hl,STR_SUNOF
        ld de,text_buf
        ld bc,STR_SUNOF_END-STR_SUNOF
        ldir
        ld a,(cur_stage)
        add a,'0'-1
        ld (text_buf+9),a
        ld hl,text_buf
        ld c,17
        ld a,(col_grn)
        call text_fbc
        ld hl,score
        call bcd_to_str
        ld hl,num_buf
        ld c,33
        ld a,(col_yel)
        call text_fbc
        ld a,(cur_stage)
        cp 8
        ret nc
        ld hl,STR_PWIS
        ld c,45
        ld a,(col_grn)
        call text_fbc
        ld hl,pw_text
        ld c,54
        ld a,(col_red)
        jp text_fbc
STR_SUNOF:   db "SUNSTONE n OF 7",0
STR_SUNOF_END:
STR_PWIS:    db "PASSWORD FOR THE NEXT STAGE",0

ending_card:
        ld de,.d
        ld hl,500
        jp card_wait
.d:     ld hl,CARD_END
        jp card_text

; game over with continue countdown -> A = 1 if continuing
gameover_card:
        ld hl,SONG_J_OVER
        call play_song
        ld a,9
        ld (cont_n),a
        ld a,50
        ld (cont_t),a
.lp:    call cls_card
        ld hl,CARD_OVER
        call card_text
        ld a,(cont_n)
        add a,'0'
        ld (num_buf),a
        xor a
        ld (num_buf+1),a
        ld hl,num_buf
        ld c,40
        ld a,(col_grn)
        call text_fbc
        call show_full
        call read_input
        ld a,(keys_new)
        and (1<<K_FIRE)|(1<<K_SWAP)
        jr z,.nf
        ld a,1
        ret
.nf:    ld hl,cont_t
        dec (hl)
        jr nz,.lp
        ld (hl),25
        ld hl,cont_n
        ld a,(hl)
        or a
        ret z
        dec (hl)
        jr .lp

controls_card:
        ld hl,CARD_CTRL
        jr text_card
credits_card:
        ld hl,CARD_CRED
text_card:
        ld (cw_list),hl
        ld de,.d
        ld hl,600
        jp card_wait
.d:     ld hl,(cw_list)
        jp card_text

; ---------------------------------------------------------------- high scores
; table: 5 entries x (3 BCD score + 3 initials)
; demo: play the stage with recorded input -> NZ if interrupted by a key
demo_game:
        ; each demo shows the next stage in turn
        ld a,(demo_stage)
        inc a
        cp 8
        jr c,$+4
        ld a,1
        ld (demo_stage),a
        ld (cur_stage),a
        call ensure_stage
        ld hl,1987
        ld (seed),hl
        ld a,(opt_diff)
        push af
        ld a,1
        ld (opt_diff),a
        ld a,1
        ld (demo_mode),a
        ld hl,DEMO_INPUT
        ld (demo_p),hl
        xor a
        ld (demo_n),a
        ld (frame_no),a
        ld hl,700
        ld (demo_t),hl
        call new_game
        ld a,(demo_stage)
        ld (cur_stage),a
        ld a,2
        ld (arm_max),a
        ld hl,(STG_SONG)
        call play_song
        call play_stage
        push af
        call css_reset
        pop af
        ld b,a
        xor a
        ld (demo_mode),a
        pop af
        ld (opt_diff),a
        ld a,b
        cp 2
        jr nz,.no
        ld hl,(demo_t)
        ld a,h
        or l
        ret z                   ; timed out -> Z (not interrupted)
        or 1
        ret
.no:    xor a
        ret

; recorded input: (frames, keys) pairs
demo_input:
        ld a,(demo_n)
        or a
        jr nz,.cur
        ld hl,(demo_p)
        ld a,(hl)
        or a
        jr nz,.ok
        ld hl,DEMO_INPUT
.ok:    ld a,(hl)
        ld (demo_n),a
        inc hl
        ld a,(hl)
        ld (demo_k),a
        inc hl
        ld (demo_p),hl
.cur:   ld hl,demo_n
        dec (hl)
        ld a,(demo_k)
        ld c,a
        jp store_keys

KL equ 1
KR equ 2
KU equ 4
KD equ 8
KF equ 16
DEMO_INPUT:
        db 20,KR, 6,KR|KF, 10,KR, 4,KR|KU, 14,KR, 4,KF, 6,0, 12,KR
        db 4,KR|KU, 12,KR, 4,KF, 8,KR, 4,KR|KF, 12,KR, 6,KR|KU, 10,KR
        db 4,KR|KF, 8,KR, 6,KR|KU, 14,KR, 4,KF, 6,0, 4,KF, 10,KR
        db 6,KR|KU, 12,KR, 4,KR|KF, 12,KR, 6,KR|KU, 16,KR, 4,KF, 10,KR
        db 6,KR|KU, 10,KR, 6,KR|KU, 10,KR, 4,KF, 14,KR, 6,KR|KU, 12,KR
        db 0
