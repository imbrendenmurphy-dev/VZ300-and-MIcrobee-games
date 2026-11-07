; ===================================================================
;  overlay.asm - code that runs from the overlay block in the lower
;  window (assembled at 0000h): start-up display choice, title logo and
;  menu, help.  Must not touch the map; may call any engine routine
;  that does not (screen, text, input, sound, animate).
; ===================================================================
; ===================================================================
;  title.asm - startup display choice, title screen + menu, help
; ===================================================================

; ---- startup: choose colour or monochrome (plain ROM text: readable on both)
startup_choice:
        ld a,C_TEXT
        call shadow_clear
        xor a
        ld (mono),a
        ld b,8
        ld c,26
        ld hl,txt_s1
        ld a,C_TEXT
        call puts_at
        ld b,9
        ld c,26
        ld hl,txt_s1u
        ld a,C_TEXT
        call puts_at
        ld b,12
        ld c,24
        ld hl,txt_s2
        ld a,C_TEXT
        call puts_at
        ld b,14
        ld c,24
        ld hl,txt_s3
        ld a,C_TEXT
        call puts_at
        ld b,18
        ld c,24
        ld hl,txt_s4
        ld a,C_DIM
        call puts_at
        call present_all
.w:     call wait_frame
        ld hl,(seed)
        inc hl
        ld (seed),hl
        call scan_keys
        ld a,KB_COL
        call key_hit
        jr nz,.col
        ld a,KB_MAP              ; 'M' = monochrome
        call key_hit
        jr nz,.mono
        jr .w
.mono:  ld a,1
        ld (mono),a
.col:   call sfx_click
        jp wait_release

txt_s1:  db "EMPIRES : THE LIVING WORLD",0
txt_s1u: db "--------------------------",0
txt_s2:  db "PRESS  C  FOR A COLOUR MONITOR",0
txt_s3:  db "PRESS  M  FOR A MONOCHROME MONITOR",0
txt_s4:  db "(CHANGE ANY TIME WITH  C  IN GAME)",0


title_menu:
        call scen_restore
        call draw_bigtitle
        ld b,5
        ld c,24
        ld hl,txt_living
        ld a,COL(BYELLOW,BLACK)
        call puts_at
        call draw_menu
        ld b,23
        ld c,4
        ld hl,txt_vibed
        ld a,COL(BMAGENTA,BLACK)
        call puts_at
        ld b,23
        ld c,34
        ld hl,txt_edition
        ld a,C_DIM
        call puts_at
        call present_all
        ld a,(title_played)
        or a
        jr nz,.loop
        inc a
        ld (title_played),a
        ld hl,mus_title
        call music_start
.loop:  call wait_frame
        ld hl,(seed)
        inc hl
        ld (seed),hl
        call scan_keys
        ld a,(frames)
        and 7
        call z,animate
        ld a,KB_1
        call key_hit
        jr nz,.new
        ld a,KB_1+1
        call key_hit
        jr nz,.wt
        ld a,KB_1+2
        call key_hit
        jr nz,.disp
        ld a,KB_1+3
        call key_hit
        jr nz,.snd
        ld a,KB_1+4
        call key_hit
        jr nz,.help
        ld a,KB_1+5
        call key_hit
        jr nz,.wsz
        ld a,KB_1+6
        call key_hit
        jr nz,.ld
        ld a,KB_ESC
        call key_hit
        jr z,.loop
        call sfx_click
        xor a
        ld (ovl_ret),a
        ret
.new:   call sfx_click
        call scen_screen
        ld a,(ovl_ret)
        or a
        jr nz,.go
        ld a,2                  ; back: redraw the title
        ld (ovl_ret),a
        ret
.go:    call music_stop
        ld a,1
        ld (ovl_ret),a
        ret
.wt:    ld a,(worldtype)
        inc a
        cp 5
        jr c,.wt1
        xor a
.wt1:   ld (worldtype),a
        call sfx_click
        call draw_menu
        ld b,15
        ld c,8
        call present_rows
        jr .loop
.ld:    call music_stop
        call sfx_click
        ld a,3
        ld (ovl_ret),a
        ret
.wsz:   ld a,(worldsize)
        xor 1
        ld (worldsize),a
        call sfx_click
        call draw_menu
        ld b,15
        ld c,8
        call present_rows
        jp .loop
.disp:  ld a,(mono)
        xor 1
        ld (mono),a
        call sfx_click
        ld a,2
        ld (ovl_ret),a
        ret
.snd:   ld a,(sound_on)
        xor 1
        ld (sound_on),a
        call sfx_click
        call draw_menu
        ld b,15
        ld c,8
        call present_rows
        jp .loop
.help:  call sfx_click
        call help_screen
        ld a,2
        ld (ovl_ret),a
        ret

draw_bigtitle:
        ; stone tablet behind the letters: rows 0-4, columns 21-58
        ld b,0
.tr:    ld c,21
.tc:    push bc
        call cell_off
        pop bc
        push bc
        call tab_glyph          ; HL = G for this cell, or 0 = plain stone
        ld a,h
        or l
        jr z,.ts
        ld a,COL(DGREY,BLACK)
        call put_g
        jr .tn
.ts:    ld a,' '
        ld hl,txtcol
        ld (hl),COL(DGREY,DGREY)
        call putch
.tn:    pop bc
        inc c
        ld a,c
        cp 59
        jr nz,.tc
        inc b
        ld a,b
        cp 5
        jr nz,.tr
        ld hl,bigword
        ld a,23
        ld (bg_x),a
.l:     ld a,(hl)
        or a
        ret z
        ld (bg_g),a
        push hl
        xor a
        ld (bg_row),a
.r:     xor a
        ld (bg_col),a
.c:     ld a,(bg_row)
        ld e,a
        ld d,0
        ld hl,bigcols
        add hl,de
        ld a,(hl)
        ld (bg_colr),a
        ld a,(bg_row)
        inc a
        ld b,a
        ld a,(bg_x)
        ld c,a
        ld a,(bg_col)
        add a,c
        ld c,a
        call cell_off
        ld a,(bg_row)
        add a,a
        add a,a
        ld c,a
        ld a,(bg_col)
        add a,c
        ld c,a
        ld a,(bg_g)
        add a,c
        ld l,a
        ld h,1
        ld a,(bg_colr)
        call put_g
        ld a,(bg_col)
        inc a
        ld (bg_col),a
        cp 4
        jr nz,.c
        ld a,(bg_row)
        inc a
        ld (bg_row),a
        cp 3
        jr nz,.r
        ld a,(bg_x)
        add a,5
        ld (bg_x),a
        pop hl
        inc hl
        jr .l
bigcols: db COL(WHITE,DGREY),COL(WHITE,DGREY),COL(GREY,DGREY)
; tablet edge glyph for B = row, C = column -> HL (0 = inside)
tab_glyph:
        ld a,b
        or a
        jr z,.top
        cp 4
        jr z,.bot
        ld a,c
        cp 21
        ld hl,G_TAB_L
        ret z
        cp 58
        ld hl,G_TAB_R
        ret z
        ld hl,0
        ret
.top:   ld a,c
        cp 21
        ld hl,G_TAB_TL
        ret z
        cp 58
        ld hl,G_TAB_TR
        ret z
        ld hl,G_TAB_T
        ret
.bot:   ld a,c
        cp 21
        ld hl,G_TAB_BL
        ret z
        cp 58
        ld hl,G_TAB_BR
        ret z
        ld hl,G_TAB_B
        ret
bigword: db G_BIG_E-256,G_BIG_M-256,G_BIG_P-256,G_BIG_I-256,G_BIG_R-256,G_BIG_E-256,G_BIG_S-256,0

draw_menu:
        ld b,15
        ld c,8
        ld a,C_TEXT
        call shadow_clear_rows
        ld b,15
        ld c,28
        ld hl,txt_m1
        ld a,C_TEXT
        call puts_at
        ld b,16
        ld c,28
        ld hl,txt_m2
        ld a,C_TEXT
        call puts_at
        ld a,(worldtype)
        add a,a
        ld l,a
        ld h,0
        ld bc,wt_names
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,C_MSG
        call puts
        ld b,17
        ld c,28
        ld hl,txt_m3
        ld a,C_TEXT
        call puts_at
        ld hl,txt_colour
        ld a,(mono)
        or a
        jr z,.c
        ld hl,txt_mono
.c:     ld a,C_MSG
        call puts
        ld b,18
        ld c,28
        ld hl,txt_m4
        ld a,C_TEXT
        call puts_at
        ld hl,txt_on
        ld a,(sound_on)
        or a
        jr nz,.s
        ld hl,txt_off
.s:     ld a,C_MSG
        call puts
        ld b,19
        ld c,28
        ld hl,txt_m5
        ld a,C_TEXT
        call puts_at
        ld b,20
        ld c,28
        ld hl,txt_m7
        ld a,C_TEXT
        call puts_at
        ld hl,txt_small
        ld a,(worldsize)
        or a
        jr z,.z
        ld hl,txt_large
.z:     ld a,C_MSG
        call puts
        ld b,21
        ld c,28
        ld hl,txt_m8
        ld a,C_TEXT
        call puts_at
        ld b,22
        ld c,28
        ld hl,txt_m6
        ld a,C_DIM
        jp puts_at

wt_names: dw wt0,wt1,wt2,wt3,wt4
wt0:    db "BALANCED   ",0
wt1:    db "ISLANDS    ",0
wt2:    db "CONTINENTAL",0
wt3:    db "FRONTIER   ",0
wt4:    db "HARSH      ",0
txt_living:  db "T H E   L I V I N G   W O R L D",0
txt_m1:  db "1  NEW GAME",0
txt_m2:  db "2  WORLD:   ",0
txt_m3:  db "3  DISPLAY: ",0
txt_m4:  db "4  SOUND:   ",0
txt_m5:  db "5  HOW TO PLAY",0
txt_m6:  db "ESC  EXIT TO DOS",0
txt_m7:  db "6  SIZE:    ",0
txt_m8:  db "7  LOAD A SAVED WORLD",0
txt_small: db "128 x 128",0
txt_large: db "256 x 256",0
txt_colour: db "COLOUR    ",0
txt_mono:   db "MONOCHROME",0
txt_on:  db "ON ",0
txt_off: db "OFF",0
txt_vibed:   db "VIBED BY BPM 2026",0
txt_edition: db "MICROBEE PREMIUM PLUS  -  1MB  -  80 x 24 PCG",0

; ---- help / how to play
help_screen:
        ld a,C_TEXT
        call shadow_clear
        ld hl,help_text
        ld b,0
.l:     ld a,(hl)
        cp 0FFh
        jr z,.done
        ld c,a                  ; colour code byte
        inc hl
        push bc
        ld a,c
        ld c,2
        call puts_at
        pop bc
        inc hl
        inc b
        jr .l
.done:  call present_all
        call wait_release
.w:     call wait_frame
        call scan_keys
        ld a,(frames)
        and 7
        call z,animate
        call any_hit
        jr z,.w
        call sfx_click
        jp wait_release

help_text:
        db C_MSG,"EMPIRES : THE LIVING WORLD  -  HOW TO PLAY",0
        db C_DIM,"",0
        db C_TEXT,"Lead a handful of settlers from a lonely town hall to a thriving town.",0
        db C_TEXT,"Every building costs wood, stone or gold and takes weeks to build.",0
        db C_DIM,"",0
        db C_GOOD,"MOVE   mouse, arrows, W A S D or joystick (SHIFT = faster)",0
        db C_GOOD,"BUILD  SPACE or RETURN places the selected tool at the cursor",0
        db C_GOOD,"TOOLS  1-0 pick a building, TAB or right button the next one, B more",0
        db C_GOOD,"       buildings.  A padlock means your scholars must discover it first",0
        db C_GOOD,"VIEW   M world map    C colour/monochrome    H this help   R research",0
        db C_GOOD,"TIME   P pause    < slower    > faster    ESC leave world",0
        db C_GOOD,"DISK   F save or load your world (3 slots on the game disk)",0
        db C_GOOD,"ENVOYS E envoys: gifts, trade and alliances with the peoples you meet",0
        db C_GOOD,"GOALS  V your goals and the five paths to victory",0
        db C_DIM,"",0
        db C_TEXT,"FOOD   Farms plough the grass around them into fields. Fields yield",0
        db C_TEXT,"       most in autumn and nothing in winter - store food for the snow!",0
        db C_TEXT,"PEOPLE Huts house 4. With a road beside them, a well nearby and happy",0
        db C_TEXT,"       people, huts grow into houses; houses near markets become manors.",0
        db C_TEXT,"WORK   Farms, woodcutters, quarries and markets each need 2 workers.",0
        db C_TEXT,"LAND   You may build only near your buildings. Watchtowers see far and",0
        db C_TEXT,"       extend your lands. Explore to find ancient ruins.",0
        db C_DIM,"",0
        db C_MSG,"PRESS ANY KEY",0
        db 0FFh

; ---- save / load panel.  fm_mode 0: in game (save or load), 1: title (load)
; returns ovl_ret: 0 back, 1-3 save to slot, 11h-13h load slot
file_menu:
        ld b,6
        ld c,13
        ld a,C_PANEL
        call shadow_clear_rows
        ld b,7
        ld c,4
        ld hl,txt_fm_title
        ld a,C_PANELHI
        call puts_at
        ld b,1                  ; slot
.sl:    push bc
        ld a,b
        add a,a
        add a,8                 ; rows 10, 12, 14
        ld b,a
        ld c,6
        call cell_off
        pop bc
        push bc
        ld a,b
        add a,'0'
        ld (txtcol),a
        ld a,C_PANELHI
        ld (txtcol),a
        ld a,b
        add a,'0'
        call putch
        inc de
        inc de
        ; header pointer
        ld a,b
        dec a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a                 ; *32
        ld l,a
        ld h,0
        ld bc,sv_heads
        add hl,bc
        push hl
        pop ix
        ld a,(ix+0)
        cp 'E'
        jr z,.full
        ld hl,txt_fm_empty
        ld a,COL(GREY,BLUE)
        call puts
        jr .ns
.full:  ld a,C_PANEL
        ld (txtcol),a
        ld hl,txt_fm_year
        call puts
        ld l,(ix+20)
        ld h,(ix+21)
        push ix
        call putnum
        pop ix
        ld a,' '
        call putch
        ld a,(ix+19)
        and 3
        add a,a
        ld l,a
        ld h,0
        ld bc,fm_seasons
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,C_PANEL
        call puts
        ld hl,txt_fm_pop
        ld a,C_PANEL
        call puts
        ld l,(ix+22)
        ld h,(ix+23)
        push ix
        call putnum
        pop ix
        ld hl,txt_fm_s128
        ld a,(ix+17)
        or a
        jr z,.sz
        ld hl,txt_fm_s256
.sz:    ld a,C_PANEL
        call puts
.ns:    pop bc
        inc b
        ld a,b
        cp 4
        jr nz,.sl
        ld hl,txt_fm_keys
        ld a,(fm_mode)
        or a
        jr z,.k
        ld hl,txt_fm_keys2
.k:     ld b,17
        ld c,6
        ld a,COL(BCYAN,BLUE)
        call puts_at
        ld b,6
        ld c,13
        call present_rows
        call wait_release
        ld a,(fm_mode)
        or a
        ld a,10h                ; title: load straight away
        jr nz,.act
        xor a
.act:   ld (fm_act),a
.lp:    call wait_frame
        call scan_keys
        ld a,KB_ESC
        call key_hit
        jr nz,.back
        ld a,KB_SAVE
        call key_hit
        jr z,.l1
        ld a,(fm_mode)
        or a
        jr nz,.l1
        xor a
        ld (fm_act),a
        ld hl,txt_fm_which_s
        call .prompt
.l1:    ld a,KB_LOAD
        call key_hit
        jr z,.l2
        ld a,10h
        ld (fm_act),a
        ld hl,txt_fm_which_l
        call .prompt
.l2:    ld b,0
.dg:    ld a,b
        add a,KB_1
        push bc
        call key_hit
        pop bc
        jr nz,.slot
        inc b
        ld a,b
        cp 3
        jr nz,.dg
        jr .lp
.slot:  inc b
        ld a,(fm_act)
        or b
        ld (ovl_ret),a
        jp sfx_click
.back:  xor a
        ld (ovl_ret),a
        jp sfx_click
.prompt:
        push hl
        ld b,17
        ld c,1
        ld a,C_PANEL
        call shadow_clear_rows
        pop hl
        ld b,17
        ld c,6
        ld a,C_PANELHI
        call puts_at
        ld b,17
        ld c,1
        call present_rows
        jp sfx_click
fm_seasons: dw fs0,fs1,fs2,fs3
fs0:    db "SPRING",0
fs1:    db "SUMMER",0
fs2:    db "AUTUMN",0
fs3:    db "WINTER",0
txt_fm_title: db "SAVE OR LOAD A WORLD  (SAVE1-3.EMP ON THE GAME DISK)",0
txt_fm_empty: db "- EMPTY -",0
txt_fm_year:  db "YEAR ",0
txt_fm_pop:   db "   POPULATION ",0
txt_fm_s128:  db "   128 x 128",0
txt_fm_s256:  db "   256 x 256",0
txt_fm_keys:  db "S THEN 1-3 SAVES     L THEN 1-3 LOADS     ESC BACK",0
txt_fm_keys2: db "1-3 LOADS THAT WORLD     ESC BACK",0
txt_fm_which_s: db "SAVE INTO WHICH SLOT?  1, 2 OR 3   (ESC BACK)",0
txt_fm_which_l: db "LOAD WHICH SLOT?  1, 2 OR 3   (ESC BACK)",0

; ---- research screen (R) ------------------------------------------------
; Lists every technology with its state.  Up/down (or the mouse) move the
; marker, SPACE / RETURN / left button study it, A-M pick directly.
research_screen:
        ld a,(cur_tech)
        cp 0FFh
        jr nz,.s
        xor a
.s:     ld (rs_sel),a
.redraw:
        ld a,C_TEXT
        call shadow_clear
        ld b,0
        ld c,2
        ld hl,txt_rs_title
        ld a,C_MSG
        call puts_at
        ld b,1
        ld c,2
        ld hl,txt_rs_rate
        ld a,C_TEXT
        call puts_at
        ld a,C_MSG
        ld (txtcol),a
        ld hl,(rp_week)
        call putnum
        ld hl,txt_rs_rate2
        ld a,C_TEXT
        call puts
        ld b,2
        ld c,2
        ld hl,txt_rs_head
        ld a,C_DIM
        call puts_at
        xor a
.row:   ld (rs_i),a
        call rs_line
        ld a,(rs_i)
        inc a
        cp NTECH
        jr nz,.row
        ld b,18
        ld c,2
        ld hl,txt_rs_help
        ld a,C_DIM
        call puts_at
        ld b,19
        ld c,2
        ld hl,txt_rs_help2
        ld a,C_DIM
        call puts_at
        call present_all
        call wait_release
.lp:    call wait_frame
        call scan_keys
        call mouse_frame
        ld a,(frames)
        and 7
        call z,animate
        ld a,KB_ESC
        call key_hit
        jp nz,.out
        ld a,KB_RESEARCH
        call key_hit
        jp nz,.out
        ld a,(ms_mu)
        or a
        jr nz,.up
        ld a,KB_UP
        call key_hit
        jr nz,.up
        ld a,32                 ; cursor up key
        call key_hit
        jr nz,.up
        ld a,(ms_md)
        or a
        jr nz,.dn
        ld a,KB_DOWN
        call key_hit
        jr nz,.dn
        ld a,34
        call key_hit
        jr nz,.dn
        ld a,(ms_click)
        bit 1,a
        jr nz,.pick
        ld a,KB_SPACE
        call key_hit
        jr nz,.pick
        ld a,KB_RET
        call key_hit
        jr nz,.pick
        ; letters A-M choose a row directly
        ld b,0
.lt:    ld a,b
        inc a                   ; key code: A = 1
        push bc
        call key_test
        pop bc
        jr nz,.let
        inc b
        ld a,b
        cp NTECH
        jr nz,.lt
        jr .lp
.let:   ld a,b
        ld (rs_sel),a
        call wait_release
        jr .pick
.up:    ld a,(rs_sel)
        or a
        jr z,.lp
        dec a
        jr .mv
.dn:    ld a,(rs_sel)
        inc a
        cp NTECH
        jr nc,.lp
.mv:    ld (rs_sel),a
        call sfx_click
        jp .redraw
.pick:  ld a,(rs_sel)
        call tech_available
        jr z,.no
        ld a,(rs_sel)
        ld (cur_tech),a
        call sfx_tool
        jp .redraw
.no:    call sfx_error
        jp .lp
.out:   call sfx_click
        jp wait_release

; one line of the list: row 3 + index
rs_line:
        ld a,(rs_i)
        add a,3
        ld b,a
        ld c,1
        call cell_off
        ; marker
        ld a,C_MSG
        ld (txtcol),a
        ld a,(rs_i)
        ld hl,rs_sel
        cp (hl)
        ld a,' '
        jr nz,.m
        ld a,'>'
.m:     call putch
        ld a,(rs_i)             ; letter
        add a,'A'
        ld hl,txtcol
        ld (hl),C_DIM
        call putch
        ld a,' '
        call putch
        ld a,(rs_i)             ; name
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,tech_name
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop de
        ld a,(rs_i)
        call has_tech
        ld a,C_GOOD
        jr nz,.nc
        ld a,(rs_i)
        call tech_available
        ld a,C_TEXT
        jr nz,.nc
        ld a,C_DIM
.nc:    call puts
        ; status column at 22
        ld a,(rs_i)
        add a,3
        ld b,a
        ld c,22
        call cell_off
        ld a,(rs_i)
        call has_tech
        jr z,.nk
        ld hl,txt_rs_known
        ld a,C_GOOD
        call puts
        jp .desc
.nk:    ld a,(rs_i)
        ld hl,cur_tech
        cp (hl)
        jr nz,.ns
        ; studying: bar of 10 + points/cost
        ld hl,txt_rs_study
        ld a,C_MSG
        call puts
        call rs_cost            ; HL = cost
        push hl
        ld a,C_MSG
        ld (txtcol),a
        ld hl,(rpoints)
        call putnum
        ld a,'/'
        call putch
        pop hl
        call putnum
        jr .desc
.ns:    ld a,(rs_i)
        call tech_available
        jr z,.lk
        ld hl,txt_rs_ready
        ld a,C_TEXT
        call puts
        call rs_cost
        ld a,C_TEXT
        ld (txtcol),a
        call putnum
        jr .desc
.lk:    ld hl,txt_rs_needs
        ld a,C_DIM
        call puts
.desc:  ; what it gives, column 44
        ld a,(rs_i)
        add a,3
        ld b,a
        ld c,44
        call cell_off
        ld a,(rs_i)
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,rs_descs
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop de
        ld a,C_DIM
        jp puts
rs_cost:
        ld a,(rs_i)
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,tech_cost
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop de
        ret

rs_sel: db 0
rs_i:   db 0
rs_descs: dw rd0,rd1,rd2,rd3,rd4,rd5,rd6,rd7,rd8,rd9,rd10,rd11,rd12
rd0:    db "FARMS",0
rd1:    db "ROADS, HUTS, WOODCUTTERS, TOWERS",0
rd2:    db "QUARRIES AND WELLS",0
rd3:    db "WINDMILLS",0
rd4:    db "MARKETS",0
rd5:    db "MINES (GOLD AND STONE)",0
rd6:    db "SCHOOLS (RESEARCH)",0
rd7:    db "EVERY BUILDING A WEEK FASTER",0
rd8:    db "HARBOURS",0
rd9:    db "HOSPITALS (GROWTH)",0
rd10:   db "TEMPLES (HAPPINESS)",0
rd11:   db "UNIVERSITIES (RESEARCH)",0
rd12:   db "THE GRAND FORUM - A WONDER",0
txt_rs_title: db "RESEARCH  -  WHAT SHOULD YOUR SCHOLARS STUDY?",0
txt_rs_rate:  db "YOUR SCHOLARS MAKE ",0
txt_rs_rate2: db " POINTS A WEEK",0
txt_rs_head:  db "  TECHNOLOGY          PROGRESS              GIVES YOU",0
txt_rs_known: db "KNOWN",0
txt_rs_study: db "STUDYING ",0
txt_rs_ready: db "READY - COST ",0
txt_rs_needs: db "LOCKED",0
txt_rs_help:  db "UP / DOWN OR LETTERS A - M CHOOSE.  SPACE, RETURN OR LEFT BUTTON STUDIES IT.",0
txt_rs_help2: db "LOCKED IDEAS NEED EARLIER ONES.  SCHOOLS SPEED RESEARCH.  ESC OR R: BACK",0

; ---- envoys / diplomacy screen (E) ---------------------------------------
envoy_screen:
        xor a
        ld (en_sel),a
        ld hl,txt_en_hint
        ld (en_res),hl
.redraw:
        ld a,C_TEXT
        call shadow_clear
        ld b,0
        ld c,2
        ld hl,txt_en_title
        ld a,C_MSG
        call puts_at
        ld b,2
        ld c,2
        ld hl,txt_en_head
        ld a,C_DIM
        call puts_at
        ld a,(nrivals)
        or a
        jr nz,.has
        ld b,4
        ld c,4
        ld hl,txt_en_none
        ld a,C_TEXT
        call puts_at
        jr .acts
.has:   xor a
.row:   ld (en_i),a
        call en_line
        ld a,(en_i)
        inc a
        ld hl,nrivals
        cp (hl)
        jr nz,.row
.acts:  ld hl,txt_en_a1
        ld b,10
        call .act
        ld hl,txt_en_a2
        ld b,11
        call .act
        ld hl,txt_en_a3
        ld b,12
        call .act
        ld hl,txt_en_a4
        ld b,14
        call .act
        ld b,16                 ; result of the last action
        ld c,4
        ld hl,(en_res)
        ld a,C_MSG
        call puts_at
        ld b,19
        ld c,2
        ld hl,txt_en_gold
        ld a,C_TEXT
        call puts_at
        ld a,C_MSG
        ld (txtcol),a
        ld hl,(gold)
        call putnum
        call present_all
        call wait_release
.lp:    call wait_frame
        call scan_keys
        call mouse_frame
        ld a,(frames)
        and 7
        call z,animate
        ld a,KB_ESC
        call key_hit
        jp nz,.out
        ld a,KB_ENVOY
        call key_hit
        jp nz,.out
        ld a,(ms_mu)
        or a
        jr nz,.up
        ld a,KB_UP
        call key_hit
        jr nz,.up
        ld a,32
        call key_hit
        jr nz,.up
        ld a,(ms_md)
        or a
        jr nz,.dn
        ld a,KB_DOWN
        call key_hit
        jr nz,.dn
        ld a,34
        call key_hit
        jr nz,.dn
        ld a,(nrivals)
        or a
        jr z,.lp
        ld a,7                  ; G: gift
        call key_test
        jp nz,en_gift
        ld a,(ms_click)
        bit 1,a
        jp nz,en_gift
        ld a,20                 ; T: trade
        call key_test
        jp nz,en_trade
        ld a,1                  ; A: alliance
        call key_test
        jp nz,en_ally
        jr .lp
.up:    ld a,(en_sel)
        or a
        jr z,.lp
        dec a
        jr .mv
.dn:    ld a,(en_sel)
        inc a
        ld hl,nrivals
        cp (hl)
        jr nc,.lp
.mv:    ld (en_sel),a
        call sfx_click
        jp .redraw
.out:   call sfx_click
        jp wait_release
.act:   ld c,4
        ld a,C_TEXT
        jp puts_at

; after an action: show the result and redraw
en_done:
        ld (en_res),hl
        call wait_release
        jp envoy_screen.redraw

; the selected rival -> IX; Z if not met yet
en_rival:
        ld a,(en_sel)
        call riv_ix
        ld a,(ix+R_STAT)
        or a
        ret

en_gift:
        call en_rival
        ld hl,txt_en_unmet
        jr z,.r
        ld hl,(gold)
        ld de,25
        or a
        sbc hl,de
        ex de,hl
        ld hl,txt_en_poor
        jr c,.r
        ld (gold),de
        ld a,(ix+R_PERS)
        cp P_TRADER
        ld a,16
        jr z,.g
        ld a,12
.g:     call riv_att
        call sfx_tool
        ld hl,txt_en_thanks
.r:     jr en_done

en_trade:
        call en_rival
        ld hl,txt_en_unmet
        jr z,.r
        ld a,(ix+R_STAT)
        cp ST_TRADE
        ld hl,txt_en_already
        jr nc,.r2               ; already trading or allied, or at war
        ld a,(nmarket)
        or a
        ld hl,txt_en_market
        jr z,.r
        ld a,(ix+R_PERS)        ; how friendly must they be?
        ld b,20
        cp P_ISOLATE
        jr nz,.t1
        ld b,40
.t1:    cp P_WARLIKE
        jr nz,.t2
        ld b,50
.t2:    ld a,(ix+R_ATT)
        bit 7,a
        ld hl,txt_en_refuse
        jr nz,.r
        cp b
        jr c,.r
        ld (ix+R_STAT),ST_TRADE
        ld a,5
        call riv_att
        call sfx_done
        ld hl,txt_en_traded
.r:     jr en_done
.r2:    cp ST_WAR
        jr nz,.r
        ld hl,txt_en_atwar
        jr .r

en_ally:
        call en_rival
        ld hl,txt_en_unmet
        jr z,.r
        ld a,(ix+R_STAT)
        cp ST_ALLY
        ld hl,txt_en_already
        jr z,.r
        cp ST_TRADE
        ld hl,txt_en_needtrade
        jr nz,.r
        ld a,(ix+R_PERS)
        ld b,60
        cp P_ISOLATE
        jr nz,.a1
        ld b,80
.a1:    cp P_WARLIKE
        jr nz,.a2
        ld b,75
.a2:    ld a,(ix+R_ATT)
        bit 7,a
        ld hl,txt_en_refuse
        jr nz,.r
        cp b
        jr c,.r
        ld (ix+R_STAT),ST_ALLY
        ld hl,fx_research
        call sfx
        ld hl,txt_en_allied
.r:     jp en_done

; one line of the table
en_line:
        ld a,(en_i)
        add a,4
        ld b,a
        ld c,1
        call cell_off
        ld a,C_MSG
        ld (txtcol),a
        ld a,(en_i)
        ld hl,en_sel
        cp (hl)
        ld a,' '
        jr nz,.m
        ld a,'>'
.m:     call putch
        ld a,(en_i)
        call riv_ix
        ld a,(ix+R_STAT)
        or a
        jr nz,.known
        inc de
        ld hl,txt_en_unknown
        ld a,C_DIM
        jp puts
.known: inc de
        ld a,(ix+R_NAME)
        ld hl,riv_names
        call en_ptr
        ld a,C_TEXT
        call puts
        ld a,(en_i)             ; temperament at 22
        add a,4
        ld b,a
        ld c,22
        call cell_off
        ld a,(ix+R_PERS)
        ld hl,en_pers
        call en_ptr
        ld a,C_TEXT
        call puts
        ld a,(en_i)             ; size at 37
        add a,4
        ld b,a
        ld c,37
        call cell_off
        ld a,C_TEXT
        ld (txtcol),a
        ld l,(ix+R_POP)
        ld h,(ix+R_POP+1)
        call putnum
        ld a,(en_i)             ; putnum uses IX
        call riv_ix
        ld a,(en_i)             ; feeling at 45
        add a,4
        ld b,a
        ld c,45
        call cell_off
        ld a,(ix+R_ATT)
        ld hl,txt_en_f5
        ld c,C_GOOD
        cp 60
        jr c,.f4p
        bit 7,a
        jr z,.fp
.f4p:   ld hl,txt_en_f4
        cp 20
        jr c,.f3p
        bit 7,a
        jr z,.fp
.f3p:   ld c,C_TEXT
        ld hl,txt_en_f3
        bit 7,a
        jr z,.fp
        cp -10
        jr nc,.fp
        ld c,C_WARN
        ld hl,txt_en_f2
        cp -40
        jr nc,.fp
        ld hl,txt_en_f1
.fp:    ld a,c
        call puts
        ld a,(en_i)             ; treaty at 60
        add a,4
        ld b,a
        ld c,60
        call cell_off
        ld a,(ix+R_STAT)
        ld hl,en_stat
        call en_ptr
        ld a,C_MSG
        jp puts
; HL = table of pointers, A = index -> HL = entry
en_ptr: add a,a
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

en_sel: db 0
en_i:   db 0
en_res: dw 0
en_pers: dw ep0,ep1,ep2,ep3,ep4
ep0:    db "TRADERS",0
ep1:    db "BUILDERS",0
ep2:    db "SCHOLARS",0
ep3:    db "WARLIKE",0
ep4:    db "ISOLATED",0
en_stat: dw es0,es1,es2,es3,es4
es0:    db "-",0
es1:    db "PEACE",0
es2:    db "TRADE",0
es3:    db "ALLIANCE",0
es4:    db "WAR",0
txt_en_f1: db "HOSTILE",0
txt_en_f2: db "WARY",0
txt_en_f3: db "NEUTRAL",0
txt_en_f4: db "FRIENDLY",0
txt_en_f5: db "LOYAL",0
txt_en_title: db "ENVOYS  -  YOUR DEALINGS WITH OTHER PEOPLES",0
txt_en_head:  db "  PEOPLE              TEMPERAMENT    SIZE    FEELING        TREATY",0
txt_en_none:  db "THIS WORLD HAS NO OTHER PEOPLES.",0
txt_en_unknown: db "AN UNKNOWN PEOPLE  (EXPLORE TO FIND THEM)",0
txt_en_a1:    db "G  SEND A GIFT OF 25 GOLD - THEY WILL THINK BETTER OF YOU",0
txt_en_a2:    db "T  PROPOSE TRADE (YOU NEED A MARKET; THEY MUST BE FRIENDLY): GOLD",0
txt_en_a3:    db "A  PROPOSE AN ALLIANCE (AFTER TRADE; THEY MUST BE LOYAL): LEARNING",0
txt_en_a4:    db "UP / DOWN CHOOSE A PEOPLE.    ESC OR E RETURNS TO YOUR TOWN.",0
txt_en_hint:  db "WARLIKE PEOPLES MAY RAID.  TWO WATCHTOWERS TURN RAIDERS BACK.",0
txt_en_gold:  db "YOUR TREASURY: ",0
txt_en_unmet: db "YOU HAVE NOT MET THAT PEOPLE YET.",0
txt_en_poor:  db "YOU CANNOT AFFORD A GIFT.",0
txt_en_thanks: db "YOUR GIFT IS RECEIVED WITH THANKS.",0
txt_en_already: db "YOU ALREADY HAVE THAT AGREEMENT.",0
txt_en_market: db "YOU NEED A MARKET BEFORE YOU CAN TRADE.",0
txt_en_refuse: db "THEY REFUSE. THEY DO NOT TRUST YOU ENOUGH YET - TRY GIFTS.",0
txt_en_traded: db "AGREED! CARAVANS WILL BRING GOLD EVERY MONTH.",0
txt_en_atwar: db "YOU ARE AT WAR. GIFTS MAY BRING PEACE.",0
txt_en_needtrade: db "FIRST AGREE TO TRADE WITH THEM.",0
txt_en_allied: db "AN ALLIANCE! THEIR SCHOLARS WILL SHARE THEIR LEARNING.",0

; ==== SCENARIOS, GOALS AND VICTORY ========================================
; scenario: worldtype, worldsize, rivals (FF = menu setting), bonus, goal
; (FF = free play: any of the five paths), name, two lines of description
SC_LEN  equ 11
scen_tab:
        db 0FFh,0FFh,0FFh,0,0FFh
        dw scn0,scd0a,scd0b
        db 0,0,0,1,5
        dw scn1,scd1a,scd1b
        db 1,0,1,0,6
        dw scn2,scd2a,scd2b
        db 2,0,3,0,4
        dw scn3,scd3a,scd3b
        db 4,0,1,0,7
        dw scn4,scd4a,scd4b
        db 3,1,3,1,8
        dw scn5,scd5a,scd5b
        db 0,1,2,2,2
        dw scn6,scd6a,scd6b
NSCEN   equ 7
scn0:  db "FREE PLAY",0
scd0a: db "YOUR OWN WORLD, MADE WITH THE SETTINGS ON THE TITLE MENU.",0
scd0b: db "ANY OF THE FIVE PATHS BRINGS VICTORY - THEN PLAY ON FOR EVER.",0
scn1:  db "THE FIRST SETTLEMENT",0
scd1a: db "A GENTLE BEGINNING: NO RIVALS AND A FULL STOREHOUSE.",0
scd1b: db "GOAL: GROW YOUR TOWN TO 50 PEOPLE.",0
scn2:  db "THE GREAT ISLAND",0
scd2a: db "AN ISLAND REALM. BUILD HARBOURS AND SEEK OUT TRADE.",0
scd2b: db "GOAL: 60 PEOPLE AND A TRADE AGREEMENT WITH ANOTHER PEOPLE.",0
scn3:  db "THE DIVIDED CONTINENT",0
scd3a: db "THREE OTHER PEOPLES SHARE THIS LAND WITH YOU.",0
scd3b: db "GOAL: DOMINION - SETTLE A THIRD OF THE WORLD.",0
scn4:  db "THE LOST VALLEY",0
scd4a: db "A HIDDEN VALLEY OF ROCK, MARSH AND HARD WINTERS.",0
scd4b: db "GOAL: GROW TO 80 PEOPLE.",0
scn5:  db "THE AGE OF DISCOVERY",0
scd5a: db "A VAST UNKNOWN WORLD. BUILD WATCHTOWERS AND EXPLORE.",0
scd5b: db "GOAL: MEET EVERY PEOPLE AND EXPLORE 12% OF THE WORLD.",0
scn6:  db "THE GREAT EMPIRE",0
scd6a: db "RULE AN ESTABLISHED REALM, RICH IN LEARNING AND GOLD.",0
scd6b: db "GOAL: CULTURE - THE GRAND FORUM, 100 PEOPLE, 75% HAPPY.",0

; A = scenario -> IY = its entry
scen_ptr:
        ld iy,scen_tab
        or a
        ret z
        push de
        ld de,SC_LEN
.l:     add iy,de
        dec a
        jr nz,.l
        pop de
        ret
; IY+o -> HL = word
sc_word:
        ld a,(iy+5)
        ld l,a
        ld a,(iy+6)
        ld h,a
        ret

; ---- the scenario list (from 1 on the title menu) ------------------------
; returns ovl_ret 1 = start, 0 = back
scen_screen:
        xor a
        ld (ss_sel),a
.redraw:
        ld a,C_TEXT
        call shadow_clear
        ld b,1
        ld c,2
        ld hl,txt_ss_title
        ld a,C_MSG
        call puts_at
        xor a
.row:   ld (ss_i),a
        call scen_ptr
        ld a,(ss_i)
        add a,a
        add a,4
        ld b,a
        ld c,1
        call cell_off
        ld a,(ss_i)
        ld hl,ss_sel
        cp (hl)
        ld a,C_DIM
        ld c,' '
        jr nz,.r1
        ld a,C_MSG
        ld c,'>'                ; a marker the monochrome screen shows too
.r1:    ld (txtcol),a
        ld a,c
        call putch
        inc de
        ld a,(ss_i)
        add a,'1'
        call putch
        inc de
        inc de
        ld a,(ss_i)
        ld hl,ss_sel
        cp (hl)
        ld a,C_TEXT
        jr nz,.r2
        ld a,C_GOOD
.r2:    push af
        call sc_word
        pop af
        call puts
        ld a,(ss_i)
        inc a
        cp NSCEN
        jr nz,.row
        ; the chosen one, described
        ld a,(ss_sel)
        call scen_ptr
        ld b,19
        ld c,4
        ld l,(iy+7)
        ld h,(iy+8)
        ld a,C_TEXT
        call puts_at
        ld b,20
        ld c,4
        ld l,(iy+9)
        ld h,(iy+10)
        ld a,C_MSG
        call puts_at
        ld b,22
        ld c,4
        ld hl,txt_ss_keys
        ld a,C_DIM
        call puts_at
        call present_all
        call wait_release
.lp:    call wait_frame
        call scan_keys
        call mouse_frame
        ld a,(frames)
        and 7
        call z,animate
        ld a,KB_ESC
        call key_hit
        jr nz,.back
        ld a,KB_RET
        call key_hit
        jr nz,.go
        ld a,KB_SPACE
        call key_hit
        jr nz,.go
        ld a,(ms_click)
        bit 1,a
        jr nz,.go
        ld a,(ms_mu)
        or a
        jr nz,.up
        ld a,KB_UP
        call key_hit
        jr nz,.up
        ld a,(ms_md)
        or a
        jr nz,.dn
        ld a,KB_DOWN
        call key_hit
        jr nz,.dn
        ld b,0                  ; number keys pick directly
.nk:    push bc
        ld a,b
        add a,KB_1
        call key_hit
        pop bc
        jr nz,.pick
        inc b
        ld a,b
        cp NSCEN
        jr nz,.nk
        jr .lp
.pick:  ld a,b
        ld (ss_sel),a
        call sfx_click
        jp .redraw
.up:    ld a,(ss_sel)
        or a
        jr z,.lp
        dec a
        jr .mv
.dn:    ld a,(ss_sel)
        inc a
        cp NSCEN
        jr nc,.lp
.mv:    ld (ss_sel),a
        call sfx_click
        jp .redraw
.back:  call sfx_click
        xor a
        ld (ovl_ret),a
        jp wait_release
.go:    call sfx_click
        ld a,(ss_sel)
        ld (scen),a
        call scen_ptr
        ld a,(worldtype)        ; keep the player's own settings for later
        ld (ss_wt),a
        ld a,(worldsize)
        ld (ss_ws),a
        ld a,1
        ld (ss_saved),a
        ld a,(iy+0)
        cp 0FFh
        jr z,.g1
        ld (worldtype),a
        ld a,(iy+1)
        ld (worldsize),a
.g1:    ld a,(iy+2)
        ld (opt_rivals),a
        ld a,1
        ld (ovl_ret),a
        jp wait_release

; back at the title: give the player's own world settings back
scen_restore:
        ld a,(ss_saved)
        or a
        ret z
        xor a
        ld (ss_saved),a
        ld a,(ss_wt)
        ld (worldtype),a
        ld a,(ss_ws)
        ld (worldsize),a
        ret

; after new_game: the scenario's starting gifts
scen_start:
        ld a,(scen)
        call scen_ptr
        ld a,(iy+3)
        or a
        ret z
        ld hl,200               ; bonus 1: a full storehouse
        ld (food),hl
        ld (wood),hl
        ld hl,100
        ld (stone),hl
        ld hl,250
        ld (gold),hl
        dec a
        ret z
        ld hl,600               ; bonus 2: an established realm
        ld (food),hl
        ld (wood),hl
        ld hl,300
        ld (stone),hl
        ld hl,800
        ld (gold),hl
        ld hl,12
        ld (pop),hl
        ld a,70
        ld (happy),a
        ld hl,(techs)           ; six arts already known
        ld a,l
        or 3Fh
        ld l,a
        ld (techs),hl
        jp pick_research        ; study something not yet known

; ---- goals --------------------------------------------------------------
; once a month from the simulation: victory or defeat?
goal_check:
        ld hl,(pop)
        ld a,h
        or a
        jr nz,.alive
        ld a,l
        cp 3
        jr nc,.alive
        ld a,0FFh               ; the people have scattered
        ld (gw_id),a
        ld a,2
        ld (want_goal),a
        ret
.alive: ld a,(scen)
        call scen_ptr
        ld a,(iy+4)
        cp 0FFh
        jr z,.free
        ld b,a
        ld a,(goal_done)
        bit 7,a
        ret nz
        ld a,b
        push bc
        call goal_test
        pop bc
        or a
        ret z
        ld hl,goal_done
        set 7,(hl)
        jr .won
.free:  ld b,0
.fl:    push bc
        ld a,b
        call goal_test
        pop bc
        or a
        jr z,.fn
        ld a,b                  ; new?
        call bit_of
        ld hl,goal_done
        ld c,a
        and (hl)
        jr nz,.fn
        ld a,c
        or (hl)
        ld (hl),a
.won:   ld a,b
        ld (gw_id),a
        ld a,1
        ld (want_goal),a
        ret
.fn:    inc b
        ld a,b
        cp 5
        jr nz,.fl
        ret
bit_of: ld c,a
        inc c
        ld a,80h
.b:     rlca
        dec c
        jr nz,.b
        ret

; A = goal -> A = 1 achieved, 0 not yet
goal_test:
        add a,a
        ld l,a
        ld h,0
        ld de,gt_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
gt_tab: dw gt_prosper,gt_science,gt_culture,gt_diplo,gt_dominion
        dw gt_settle,gt_island,gt_valley,gt_discover
gt_no:  xor a
        ret
gt_yes: ld a,1
        ret
cmp_pop:                        ; C if pop < DE
        ld hl,(pop)
        or a
        sbc hl,de
        ret
gt_prosper:
        ld de,150
        call cmp_pop
        jr c,gt_no
        ld hl,(gold)
        ld de,1000
        or a
        sbc hl,de
        jr c,gt_no
        call ntechs
        cp 8
        jr c,gt_no
        jr gt_yes
gt_science:
        call ntechs
        cp 13
        jr c,gt_no
        jr gt_yes
gt_culture:
        ld a,(forum_done)
        or a
        jr z,gt_no
        ld a,(happy)
        cp 75
        jr c,gt_no
        ld de,100
        call cmp_pop
        jr c,gt_no
        jr gt_yes
gt_diplo:
        call count_rel
        ld a,e
        or a
        jr z,gt_no
        cp b
        jr nz,gt_no
        jr gt_yes
gt_dominion:
        call expl_pct
        ld b,a
        call dom_pct
        ld c,a
        ld a,b
        cp c
        jr c,gt_no
        ld a,(nbld)
        cp 100
        jr c,gt_no
        jr gt_yes
dom_pct:
        ld a,(worldsize)
        or a
        ld a,30
        ret z
        ld a,15
        ret
gt_settle:
        ld de,50
        call cmp_pop
        jr c,gt_no
        jr gt_yes
gt_island:
        call count_rel
        ld a,d
        or a
        jr z,gt_no
        ld de,60
        call cmp_pop
        jr c,gt_no
        jr gt_yes
gt_valley:
        ld de,80
        call cmp_pop
        jr c,gt_no
        jr gt_yes
gt_discover:
        call count_rel
        ld a,e
        or a
        jr z,.d
        cp c
        jp nz,gt_no
.d:     call expl_pct
        cp 12
        jp c,gt_no
        jp gt_yes

; A = number of technologies known
ntechs: ld hl,(techs)
        ld b,16
        ld c,0
.l:     add hl,hl
        jr nc,.n
        inc c
.n:     djnz .l
        ld a,c
        ret
; A = percentage of the world explored
expl_pct:
        ld hl,(nexpl)
        ld de,164
        ld a,(worldsize)
        or a
        jr z,.s
        ld de,655
.s:     ld c,0
.l:     or a
        sbc hl,de
        jr c,.d
        inc c
        ld a,c
        cp 100
        jr c,.l
.d:     ld a,c
        ret
; B = allies, C = met, D = trading or allied, E = peoples in the world
count_rel:
        ld bc,0
        ld de,0
        ld a,(nrivals)
        or a
        ret z
        xor a
.l:     ld (cr_i),a
        push bc
        push de
        call riv_ix
        pop de
        pop bc
        ld a,(ix+R_ACT)
        or a
        jr z,.n
        inc e
        ld a,(ix+R_STAT)
        or a
        jr z,.n
        inc c
        cp ST_ALLY
        jr nz,.t
        inc b
.t:     cp ST_TRADE
        jr c,.n
        cp ST_WAR
        jr z,.n
        inc d
.n:     ld a,(cr_i)
        inc a
        ld hl,nrivals
        cp (hl)
        jr nz,.l
        ret

; ---- the goals screen (V) ------------------------------------------------
goals_screen:
        ld a,C_TEXT
        call shadow_clear
        ld a,(scen)
        call scen_ptr
        ld b,0
        ld c,2
        ld hl,txt_gs_title
        ld a,C_MSG
        call puts_at
        call sc_word
        ld a,C_GOOD
        call puts
        ld b,2
        ld c,2
        ld l,(iy+9)
        ld h,(iy+10)
        ld a,C_TEXT
        call puts_at
        ld b,4
        ld c,2
        ld hl,txt_gs_paths
        ld a,C_DIM
        call puts_at
        ; the five paths
        ld b,6
        ld c,2
        ld hl,txt_gp0
        call gs_head
        ld hl,txt_gpeople
        call gs_lbl
        ld hl,(pop)
        call gs_num
        ld hl,txt_g150
        call gs_lbl
        ld hl,txt_ggold
        call gs_lbl
        ld hl,(gold)
        call gs_num
        ld hl,txt_g1000
        call gs_lbl
        ld hl,txt_glearn
        call gs_lbl
        call ntechs
        call gs_numa
        ld hl,txt_g8
        call gs_lbl
        xor a
        call gs_done
        ld b,8
        ld c,2
        ld hl,txt_gp1
        call gs_head
        ld hl,txt_glearn
        call gs_lbl
        call ntechs
        call gs_numa
        ld hl,txt_g13
        call gs_lbl
        ld a,1
        call gs_done
        ld b,10
        ld c,2
        ld hl,txt_gp2
        call gs_head
        ld hl,txt_gforum
        call gs_lbl
        ld hl,txt_gno
        ld a,(forum_done)
        or a
        jr z,.f
        ld hl,txt_gyes
.f:     call gs_lbl
        ld hl,txt_gpeople
        call gs_lbl
        ld hl,(pop)
        call gs_num
        ld hl,txt_g100
        call gs_lbl
        ld hl,txt_ghappy
        call gs_lbl
        ld a,(happy)
        call gs_numa
        ld hl,txt_g75
        call gs_lbl
        ld a,2
        call gs_done
        call count_rel
        ld a,b
        ld (gs_a),a
        ld a,e
        ld (gs_b),a
        ld b,12
        ld c,2
        ld hl,txt_gp3
        call gs_head
        ld hl,txt_gallies
        call gs_lbl
        ld a,(gs_a)
        call gs_numa
        ld hl,txt_gof
        call gs_lbl
        ld a,(gs_b)
        call gs_numa
        ld a,3
        call gs_done
        ld b,14
        ld c,2
        ld hl,txt_gp4
        call gs_head
        ld hl,txt_gland
        call gs_lbl
        push de
        call expl_pct
        pop de
        call gs_numa
        ld hl,txt_gpct
        call gs_lbl
        call dom_pct
        call gs_numa
        ld hl,txt_gpct2
        call gs_lbl
        ld a,(nbld)
        call gs_numa
        ld hl,txt_g100
        call gs_lbl
        ld a,4
        call gs_done
        ; the scenario's own goal
        ld a,(scen)
        call scen_ptr
        ld a,(iy+4)
        cp 5
        jr c,.nos
        cp 0FFh
        jr z,.nos
        ld b,17
        ld c,2
        ld hl,txt_gs_own
        call gs_head
        ld a,(scen)
        call scen_ptr
        ld l,(iy+9)
        ld h,(iy+10)
        call gs_lbl
        ld a,(scen)
        call scen_ptr
        ld a,(iy+4)
        call gs_done
.nos:   ld b,20
        ld c,2
        ld hl,txt_gs_year
        ld a,C_DIM
        call puts_at
        ld hl,(year)
        call gs_num
        ld hl,txt_gs_any
        ld a,C_DIM
        call puts
        call present_all
        call wait_release
.lp:    call wait_frame
        call scan_keys
        call mouse_frame
        ld a,(frames)
        and 7
        call z,animate
        call gs_anykey
        jr z,.lp
        call sfx_click
        jp wait_release
gs_head:
        ld a,b
        ld (gs_row),a
        ld a,C_MSG
        jp puts_at
gs_lbl: ld a,C_TEXT
        jp puts
gs_numa:
        ld l,a
        ld h,0
gs_num: ld a,C_GOOD
        ld (txtcol),a
        jp putnum
; A = goal: "ACHIEVED" at the end of row gs_row if done
gs_done:
        call goal_test
        or a
        ret z
        ld a,(gs_row)
        ld b,a
        ld c,68
        ld hl,txt_gach
        ld a,C_GOOD
        jp puts_at
; NZ when the player wants to leave a screen
gs_anykey:
        ld a,(ms_click)
        or a
        ret nz
        ld a,KB_ESC
        call key_hit
        ret nz
        ld a,KB_RET
        call key_hit
        ret nz
        ld a,KB_SPACE
        call key_hit
        ret nz
        ld a,KB_GOALS
        jp key_hit

; ---- victory or defeat ---------------------------------------------------
; ovl_ret: 0 = play on, 1 = back to the title
goal_end:
        ld a,C_TEXT
        call shadow_clear
        ld a,(gw_id)
        cp 0FFh
        jp z,.lost
        call draw_bigtitle
        ld b,7
        ld hl,txt_ge_vic
        ld a,C_MSG
        call put_centre
        ld a,(gw_id)
        cp 5
        jr nc,.sc
        add a,a
        ld l,a
        ld h,0
        ld de,ge_paths
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr .p
.sc:    ld a,(scen)
        call scen_ptr
        call sc_word
        ld b,10
        ld a,C_GOOD
        call put_centre
        ld hl,txt_ge_done
.p:     ld b,12
        ld a,C_TEXT
        call put_centre
        ld b,15
        ld c,22
        ld hl,txt_ge_year
        ld a,C_TEXT
        call puts_at
        ld hl,(year)
        call gs_num
        ld hl,txt_ge_pop
        call gs_lbl
        ld hl,(pop)
        call gs_num
        ld hl,txt_ge_pop2
        call gs_lbl
        ld b,19
        ld hl,txt_ge_keys
        ld a,C_MSG
        call put_centre
        ld b,23
        ld hl,txt_vibed
        ld a,COL(BMAGENTA,BLACK)
        call put_centre
        call present_all
        ld hl,mus_title
        call music_start
        call wait_release
.lp:    call wait_frame
        call scan_keys
        call mouse_frame
        ld a,(frames)
        and 7
        call z,animate
        ld a,KB_COL             ; C: play on
        call key_hit
        jr nz,.on
        ld a,(ms_click)
        bit 1,a
        jr nz,.on
        ld a,KB_ESC
        call key_hit
        jr z,.lp
        call music_stop
        ld a,1
        ld (ovl_ret),a
        jp wait_release
.on:    call music_stop
        call sfx_click
        xor a
        ld (ovl_ret),a
        jp wait_release
.lost:  ld b,6
        ld hl,txt_ge_lost
        ld a,C_WARN
        call put_centre
        ld b,9
        ld hl,txt_ge_lost2
        ld a,C_TEXT
        call put_centre
        ld b,11
        ld hl,txt_ge_lost3
        ld a,C_TEXT
        call put_centre
        ld b,15
        ld c,30
        ld hl,txt_ge_year
        ld a,C_TEXT
        call puts_at
        ld hl,(year)
        call gs_num
        ld b,19
        ld hl,txt_ge_lkey
        ld a,C_DIM
        call put_centre
        call present_all
        ld hl,fx_bad
        call sfx
        call wait_release
.ll:    call wait_frame
        call scan_keys
        call mouse_frame
        call gs_anykey
        jr z,.ll
        ld a,1
        ld (ovl_ret),a
        jp wait_release

; B = row, HL = string, A = colour: centred on the 80 columns
put_centre:
        push af
        push hl
        ld c,0
.n:     ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc c
        jr .n
.e:     ld a,80
        sub c
        srl a
        ld c,a
        pop hl
        pop af
        jp puts_at

ge_paths: dw txt_win0,txt_win1,txt_win2,txt_win3,txt_win4
txt_win0: db "A PROSPERITY VICTORY - YOUR REALM IS WEALTHY AND WISE.",0
txt_win1: db "A VICTORY OF SCIENCE - ALL THE ARTS OF YOUR AGE ARE MASTERED.",0
txt_win2: db "A CULTURAL VICTORY - YOUR CITY IS THE LIGHT OF THE WORLD.",0
txt_win3: db "A DIPLOMATIC VICTORY - EVERY PEOPLE IS YOUR FRIEND AND ALLY.",0
txt_win4: db "A DOMINION VICTORY - YOUR LANDS STRETCH ACROSS THE WORLD.",0
txt_ge_vic:  db "V  I  C  T  O  R  Y",0
txt_ge_done: db "YOU HAVE ACHIEVED ALL THAT WAS ASKED OF YOU.",0
txt_ge_year: db "IN YEAR ",0
txt_ge_pop:  db " YOUR CITY HOLDS ",0
txt_ge_pop2: db " PEOPLE.",0
txt_ge_keys: db "C  CONTINUE YOUR REIGN          ESC  RETURN TO THE TITLE",0
txt_ge_lost: db "YOUR PEOPLE HAVE SCATTERED",0
txt_ge_lost2: db "HUNGER AND HARDSHIP HAVE EMPTIED YOUR TOWN.",0
txt_ge_lost3: db "THE FIELDS GROW WILD, AND YOUR TALE IS ENDED.",0
txt_ge_lkey: db "PRESS A KEY TO RETURN TO THE TITLE",0
txt_ss_title: db "CHOOSE YOUR TALE",0
txt_ss_keys:  db "1-7 OR UP/DOWN TO CHOOSE.   RETURN TO BEGIN.   ESC GOES BACK.",0
txt_gs_title: db "GOALS  -  ",0
txt_gs_paths: db "THE FIVE PATHS TO GREATNESS:",0
txt_gs_own:   db "THIS TALE:  ",0
txt_gs_year:  db "YEAR ",0
txt_gs_any:   db ".   PRESS ANY KEY TO RETURN.",0
txt_gp0:  db "PROSPERITY   ",0
txt_gp1:  db "SCIENCE      ",0
txt_gp2:  db "CULTURE      ",0
txt_gp3:  db "DIPLOMACY    ",0
txt_gp4:  db "DOMINION     ",0
txt_gpeople: db "PEOPLE ",0
txt_ggold:   db "   GOLD ",0
txt_glearn:  db "   LEARNING ",0
txt_gforum:  db "FORUM ",0
txt_ghappy:  db "   HAPPY ",0
txt_gallies: db "ALLIES ",0
txt_gland:   db "LAND SETTLED ",0
txt_g150:  db "/150",0
txt_g1000: db "/1000",0
txt_g8:    db "/8",0
txt_g13:   db "/13",0
txt_g100:  db "/100",0
txt_g75:   db "/75",0
txt_gof:   db " OF ",0
txt_gpct:  db "%/",0
txt_gpct2: db "%   BUILDINGS ",0
txt_gyes:  db "BUILT   ",0
txt_gno:   db "NOT YET   ",0
txt_gach:  db "ACHIEVED",0
ss_sel:   db 0
ss_i:     db 0
ss_wt:    db 0
ss_ws:    db 0
ss_saved: db 0
gw_id:    db 0
cr_i:     db 0
gs_row:   db 0
gs_a:     db 0
gs_b:     db 0
