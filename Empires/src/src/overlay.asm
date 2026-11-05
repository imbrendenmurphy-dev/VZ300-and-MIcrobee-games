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
        call draw_bigtitle
        ld b,5
        ld c,24
        ld hl,txt_living
        ld a,C_TITLE
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
        ld hl,tune_title
        call play_tune
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
.ld:    call sfx_click
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
bigcols: db COL(WHITE,BLACK),COL(BYELLOW,BLACK),COL(BRED,BLACK)
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
txt_m1:  db "1  NEW WORLD",0
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
txt_vibed:   db "ViBED by BPM  2026",0
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
        db C_GOOD,"TOOLS  1 ROAD  2 HUT  3 FARM  4 WOODCUTTER  5 QUARRY  6 WELL",0
        db C_GOOD,"       7 MARKET  8 WINDMILL  9 WATCHTOWER  0 CLEAR    TAB cycles",0
        db C_GOOD,"VIEW   M world map    C colour/monochrome    H this help",0
        db C_GOOD,"TIME   P pause    < slower    > faster    ESC leave world",0
        db C_GOOD,"DISK   F save or load your world (3 slots on the game disk)",0
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
