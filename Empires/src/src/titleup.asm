; ===================================================================
;  titleup.asm - title screen, engine side: the landscape scene lives in
;  the map, so it is built and drawn here; the logo, menu and loop are in
;  the overlay (overlay.asm).
; ===================================================================
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
        call map_clear
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


; title_screen: returns A = 1 new game, 0 exit to DOS
title_screen:
        ld a,1
        ld (season),a
        xor a
        ld (viewx),a
        ld (viewy),a
        call build_scene
.redraw:
        ld a,C_TEXT
        call shadow_clear
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
        ld hl,title_menu
        call ovl_call
        ld a,(ovl_ret)
        cp 2
        jr z,.redraw
        ret
