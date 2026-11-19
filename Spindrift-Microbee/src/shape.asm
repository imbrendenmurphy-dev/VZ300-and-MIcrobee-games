; =====================================================================
;  SCREEN SHAPE: how wide the vortex is drawn, so the ring is round on
;  whatever screen shows it. A CRT shows the 40-column pixel a little
;  wider than a line is tall; a screen that stretches the picture to fill
;  4:3 shows it narrower. The player picks the shape that looks round.
;
;  The position table (block 4) holds dx, dy for 128 radii x 65 angles.
;  dy never changes; dx is rebuilt from a pristine copy made for a
;  150-pixel orbit (block 6, DX136) through a 256-entry scale map.
; =====================================================================
NSHAPE      EQU 8
SHAPE_CRT   EQU 2                   ; the default: round on a CRT
MAPBUF      EQU POOLBUF             ; scratch (zeroed again afterwards)
CHUNK       EQU POOLBUF+$100

; orbit half-widths in pixels (the half-height is 115 lines: the arena is
; all 25 rows of 10 lines), as 8.8 steps of the scale map: RX * 256 / 150
shape_step:
        dw 89*256/150, 96*256/150, 105*256/150, 112*256/150
        dw 122*256/150, 132*256/150, 142*256/150, 150*256/150

; A = shape 0..7: rebuild the dx column of the position table
set_shape:
        ld (shape),a
        add a,a
        ld e,a
        ld d,0
        ld hl,shape_step
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,128               ; rounding
        ld bc,MAPBUF
.m:     ld a,h
        ld (bc),a
        add hl,de
        inc c
        jr nz,.m
        ld hl,DX136
        ld de,POSTAB
        ld b,128
.r:     push bc
        push de
        ld a,MP_PIC
        out (P_MEM),a
        ld de,CHUNK
        ld bc,65
        ldir                    ; one radius: 65 pristine dx values
        pop de
        push hl
        ld a,MP_TAB
        out (P_MEM),a
        ld hl,CHUNK
        ld b,65
        ld c,MAPBUF>>8
.x:     ld a,(hl)
        push hl
        ld l,a
        ld h,c
        ld a,(hl)
        pop hl
        ld (de),a               ; dx (dy, the next byte, stays)
        inc de
        inc de
        inc hl
        djnz .x
        pop hl
        pop bc
        djnz .r
        ld hl,MAPBUF            ; the glyph buffers must be clear
        ld bc,$200
        xor a
        jp fill

; ---------------------------------------------------------------------
; the screen-shape screen: a ring of ships; Z / X (or the stick) squash
; and stretch it until it looks round, then fire
; ---------------------------------------------------------------------
shape_ask:
        call screen_reset
        ld hl,0*40+14
        ld de,t_shape0
        ld c,YELLOW
        call print_s
        ld hl,24*40+2
        ld de,t_shape1
        ld c,WHITE
        call print_s
        call display_on
        call input_used
.f:     call read_input
        call fire_new
        jr nz,.done
        ld a,(padnew)
        and 1+32                ; right or Z: wider
        jr nz,.wide
        ld a,(padnew)
        and 2+64                ; left or X: narrower
        jr nz,.narrow
.draw:  call input_used
        call frame_begin
        ld a,MP_TAB
        out (P_MEM),a
        ld a,BCYAN
        call setcol
        ld b,16
        xor a
.s:     push bc
        push af
        ld b,PR_ORBIT
        call polar              ; HL = x, C = y
        pop af
        push af
        push hl
        push bc
        add a,4
        rrca
        rrca
        and $3E
        ld l,a
        ld h,0
        ld de,rec_ship
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop bc
        pop de
        call draw_spr
        pop af
        pop bc
        add a,16
        djnz .s
        call frame_end
        jr .f
.wide:  ld a,(shape)
        cp NSHAPE-1
        jr nc,.draw
        inc a
        jr .set
.narrow:
        ld a,(shape)
        or a
        jr z,.draw
        dec a
.set:   call set_shape
        jr .draw
.done:  call input_used
        jp screen_reset

t_shape0:   db "SCREEN SHAPE",0
t_shape1:   db "Z X SQUASH OR STRETCH  FIRE IF ROUND",0
