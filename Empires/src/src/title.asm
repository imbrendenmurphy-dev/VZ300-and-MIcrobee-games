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

; ---- title scene, built into the real map arrays and drawn by the renderer
SCENE_W equ 40
SCENE_H equ 6
scene:
        db "SSMMMMHHFFDDDFFHHMMMSSMMMHHFFFDDFFHHMMSS"
        db "MMHHFFDDDFFGGGFFHHHQHHGGFFFDDFFGGHHHFFDD"
        db "FFGGGEGGhGoGGTtGGWGGGEGGhGGXGGFFGGCGGFFF"
        db "GGffffRRRRRRUuRRRRRRRRRGoGGGRGGKGGGfffGG"
        db "BBGGffffGGGGGLGGEGGGGBBBBGGGRGGGGBBBBBBB"
        db "~~BBBB~~~~~~BBBB~~~~~~~~~~~~=~~~~~~~~~~~"
scene_key:      ; char, terrain, object
        db 'S',T_SNOW,0
        db 'M',T_MOUNT,0
        db 'H',T_HILLS,0
        db 'F',T_FOREST,0
        db 'D',T_DENSE,0
        db 'G',T_GRASS,0
        db 'E',T_MEADOW,0
        db 'f',T_FIELD,0
        db 'B',T_BEACH,0
        db '~',T_SHALLOW,0
        db 'R',T_GRASS,O_ROAD
        db '=',T_SHALLOW,O_ROAD
        db 'h',T_GRASS,O_HUT
        db 'o',T_GRASS,O_HOUSE
        db 'T',T_GRASS,O_TC_TL
        db 't',T_GRASS,O_TC_TR
        db 'U',T_GRASS,O_TC_BL
        db 'u',T_GRASS,O_TC_BR
        db 'W',T_GRASS,O_MILL
        db 'Q',T_HILLS,O_QUARRY
        db 'X',T_GRASS,O_TOWER
        db 'C',T_GRASS,O_WOOD
        db 'K',T_GRASS,O_MARKET
        db 'L',T_GRASS,O_WELL
        db 0

build_scene:
        call make_rowtab
        ld hl,TERR
        ld de,TERR+1
        ld (hl),0
        ld bc,2*MAPSIZE-1
        ldir
        ; clear the top rows of the map
        ld b,0
.r:     ld c,0
.c:     push bc
        ; char at scene[b*40 + c]
        ld a,b
        add a,a
        add a,a
        add a,b                 ; *5
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; *40
        ld e,c
        ld d,0
        add hl,de
        ld de,scene
        add hl,de
        ld a,(hl)
        ld hl,scene_key
.k:     cp (hl)
        jr z,.f
        inc hl
        inc hl
        inc hl
        jr .k
.f:     inc hl
        ld d,(hl)               ; terrain
        inc hl
        ld e,(hl)               ; object
        pop bc
        push bc
        call tile_addr
        ld a,d
        or EXPLORED
        ld (hl),a
        ld a,e
        call set_obj
        pop bc
        inc c
        ld a,c
        cp SCENE_W
        jr nz,.c
        ; blank row below scene so shorelines see water
        inc b
        ld a,b
        cp SCENE_H
        jr nz,.r
        ld c,0
.b:     call tile_addr
        ld (hl),T_SHALLOW|EXPLORED
        xor a
        call set_obj
        inc c
        ld a,c
        cp SCENE_W
        jr nz,.b
        ret

; ---- title screen.  returns A = 1 (new game) or 0 (exit)
title_screen:
        call build_scene
        ld a,1
        ld (season),a
        xor a
        ld (viewx),a
        ld (viewy),a
.redraw:
        ld a,C_TEXT
        call shadow_clear
        call draw_bigtitle
        ld b,5
        ld c,24
        ld hl,txt_living
        ld a,C_TITLE
        call puts_at
        ; landscape strip rows 7-12
        ld b,0
.sr:    ld c,0
.sc:    push bc
        ld a,b
        add a,7
        ld b,a
        ld a,c
        add a,a
        ld c,a
        call cell_off
        pop bc
        push bc
        call draw_tile
        pop bc
        inc c
        ld a,c
        cp SCENE_W
        jr nz,.sc
        inc b
        ld a,b
        cp SCENE_H
        jr nz,.sr
        call draw_menu
        ld b,21
        ld c,31
        ld hl,txt_vibed
        ld a,COL(BMAGENTA,BLACK)
        call puts_at
        ld b,23
        ld c,22
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
        ld a,KB_ESC
        call key_hit
        jr z,.loop
        call sfx_click
        xor a
        ret
.new:   call sfx_click
        ld a,1
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
        ld c,6
        call present_rows
        jr .loop
.disp:  ld a,(mono)
        xor 1
        ld (mono),a
        call sfx_click
        jp .redraw
.snd:   ld a,(sound_on)
        xor 1
        ld (sound_on),a
        call sfx_click
        call draw_menu
        ld b,15
        ld c,6
        call present_rows
        jp .loop
.help:  call sfx_click
        call help_screen
        jp .redraw

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
        ld c,6
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
txt_colour: db "COLOUR    ",0
txt_mono:   db "MONOCHROME",0
txt_on:  db "ON ",0
txt_off: db "OFF",0
txt_vibed:   db "ViBED by BPM  2026",0
txt_edition: db "MICROBEE PREMIUM PLUS  -  80 x 24 PCG",0

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
        db C_GOOD,"MOVE   ARROWS, W A S D, I J K L or joystick (SHIFT = faster)",0
        db C_GOOD,"BUILD  SPACE or RETURN places the selected tool at the cursor",0
        db C_GOOD,"TOOLS  1 ROAD  2 HUT  3 FARM  4 WOODCUTTER  5 QUARRY  6 WELL",0
        db C_GOOD,"       7 MARKET  8 WINDMILL  9 WATCHTOWER  0 CLEAR    TAB cycles",0
        db C_GOOD,"VIEW   M world map    C colour/monochrome    H this help",0
        db C_GOOD,"TIME   P pause    < slower    > faster    ESC leave world",0
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
