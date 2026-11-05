; ===================================================================
;  banks.asm - 1MB banked RAM (Microbee Premium Plus)
;
;  Port 50h (as established for The Lantern Deep from ubee512's Premium
;  Plus model, and checked by its loader's RAM test on real hardware):
;  only the lower 32K (0000-7FFF) is a window onto one of 32 blocks of
;  32K; 8000-FFFF is always block 0.  block bits 4-2 = port bits 7-5,
;  block bits 1-0 = port bits 1-0 with bit 1 inverted while ROMs are off
;  (bit 2 = 1).  Bit 3 = 1 removes the video window from F000-FFFF.
;
;  EMPIRES keeps its engine in block 0 (8000-EFFF) and maps the world map
;  into the lower window.  The map is banded: row stride 256, 64 rows per
;  block, terrain at 0000h and objects at 4000h within each block.
; ===================================================================
P_MEM     equ 50h
BLK_MAP   equ 8                 ; 8-11: world map bands (up to 256 rows)
BLK_ART   equ 16                ; PCG patterns + animation frames (at 4000h)
BLK_OVL   equ 17                ; overlay code (title, menus, help) at 0000h
BLK_CPM   equ 18                ; snapshot of CP/M's 8000-EFFF
BLK_GAME  equ 19                ; snapshot of the game's 8000-EFFF during disk I/O
BLK_STAGE equ 20                ; loader staging for the engine image
OBJOFF    equ 4000h             ; object layer offset within a map block

; A = block -> A = port 50h value (ROMs off, video window at F000)
blk_port:
        push bc
        ld b,a
        and 3
        xor 2
        ld c,a
        ld a,b
        and 1Ch
        rlca
        rlca
        rlca
        or c
        or 4
        pop bc
        ret

; tile_addr: B = y, C = x -> HL = terrain byte (object byte = HL + OBJOFF)
; switches the lower window to the right band.  Preserves BC, DE.
tile_addr:
        ld a,b
        rlca
        rlca
        and 3                   ; band = y >> 6
        ld hl,curband
        cp (hl)
        jr z,.same
        ld (hl),a
        add a,BLK_MAP
        call blk_port
        ld (lowport),a
        out (P_MEM),a
.same:  ld a,b
        and 3Fh
        ld h,a
        ld l,c
        ret

; map_home: make sure a map band is mapped (after using other blocks)
map_home:
        ld a,(lowport)
        out (P_MEM),a
        ret

; map band select without coordinates: A = band
map_band:
        ld (curband),a
        add a,BLK_MAP
        call blk_port
        ld (lowport),a
        out (P_MEM),a
        ret

; temporarily map block A into the lower window (restore with map_home)
with_block:
        call blk_port
        out (P_MEM),a
        ret

; ovl_call: HL = overlay routine.  Runs it with the overlay block mapped,
; then puts the previous lower window back.  Overlay code must not touch
; the map (no tile_addr); it may use any screen, input or sound routine.
ovl_call:
        ld a,(lowport)
        push af
        ld a,BLK_OVL
        call blk_port
        ld (lowport),a
        out (P_MEM),a
        ld de,.back
        push de
        jp (hl)
.back:  pop af
        ld (lowport),a
        out (P_MEM),a
        ret

; clear the whole map (all bands): terrain 0 (deep water, unexplored), no objects
map_clear:
        xor a
.b:     push af
        call map_band
        ld hl,0
        ld de,1
        ld bc,7FFFh
        ld (hl),0
        ldir
        pop af
        inc a
        cp 4
        jr nz,.b
        xor a
        jp map_band

; bounds: carry if A is inside the map width / height
cpw:    push bc
        ld b,a
        ld a,(mapwm1)
        cp b
        ccf
        ld a,b
        pop bc
        ret
cph:    push bc
        ld b,a
        ld a,(maphm1)
        cp b
        ccf
        ld a,b
        pop bc
        ret
; Z if A = last column / row
iswm1:  push hl
        ld hl,mapwm1
        cp (hl)
        pop hl
        ret
ishm1:  push hl
        ld hl,maphm1
        cp (hl)
        pop hl
        ret

; set world size from (worldsize): 0 = 128 x 128, 1 = 256 x 256
set_world_size:
        ld a,(worldsize)
        or a
        ld a,127
        jr z,.s
        ld a,255
.s:     ld (mapwm1),a
        ld (maphm1),a
        inc a                   ; 128 or 0 (=256)
        srl a                   ; 64 or 0
        jr nz,.c
        ld a,128
.c:     ld (mapcx),a
        ld (mapcy),a
        ld a,(mapwm1)
        sub VIEWW-1
        ld (vxmax),a
        ld a,(maphm1)
        sub VIEWH-1
        ld (vymax),a
        ; overview cell size: 128 -> 3 x 6 (43 x 22 cells), 256 -> 5 x 12 (52 x 22)
        ld a,(worldsize)
        or a
        ld a,3
        ld b,6
        jr z,.o
        ld a,5
        ld b,12
.o:     ld (ovcw),a
        ld a,b
        ld (ovch),a
        ret
