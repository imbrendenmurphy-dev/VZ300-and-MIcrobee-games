; =====================================================================
;  ENGINE (8000h up, always in view): hardware, the scrolling cell
;  screen, the sprite compositor, the frame.
;
;  THE SCROLL. The 6545's start address moves the picture a whole cell
;  (the screen RAM is a ring of 2048 cells; a world cell keeps its ring
;  address for as long as it is on the screen, so a cell scrolled on is
;  written once). The two-pixel steps in between come from the PCG: a
;  cell's four shifted pictures are at the same code in four banks, so
;  shifting the picture means writing every cell's bank (attribute).
;  That is done by a "ladder": 500 LD DE,nn / PUSH DE, with the stack
;  pointer in the attribute RAM, entered and left at the edges of the
;  picture - 10.5 T a cell, all inside one vertical blanking. There are
;  four ladders, one a shift, and their operands are kept up to date as
;  cells come on to the screen, so nothing is worked out when it runs.
;
;  THE SPRITES. As FRILLSEEKER: for each cell a sprite touches, a
;  private glyph is composed in RAM (the background's own glyph at its
;  present shift, with the sprite masked over it) in one of two pools
;  of the PCG that take turns, and the cell is pointed at it.
; =====================================================================
crtc_game:  db $35,$28,$2C,$34,$26,$01,$19,$21,$48,$07,$20,$07,0,0,0,0
DROWS       EQU 25

hw_init:
        ld hl,VARS
        ld de,VARS+1
        ld bc,$FF
        ld (hl),0
        ldir
        ld a,$CF                ; PIO A: input (joystick)
        out (P_PIOAC),a
        ld a,$FF
        out (P_PIOAC),a
        ld a,$07
        out (P_PIOAC),a
        ld a,$CF                ; PIO B: b6 speaker out
        out (P_PIOBC),a
        ld a,$BF
        out (P_PIOBC),a
        ld a,$07
        out (P_PIOBC),a
        xor a
        out (P_PIOB),a
        out (P_ROMLAT),a
        out (P_COLCTL),a
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,1
        in a,(P_CLK40)          ; the 40-column dot clock
        ld hl,crtc_game
        ld c,0
.l:     ld a,c
        out (P_CRTCA),a
        ld a,(hl)
        out (P_CRTCD),a
        inc hl
        inc c
        ld a,c
        cp 16
        jr nz,.l
        call display_off
        ld hl,LISTA
        ld (curlist),hl
        ld hl,LISTB
        ld (oldlist),hl
        ld a,BK_POOLA
        ld (poolbank),a
        ld hl,$5EED
        ld (rseed),hl
        ld a,M_PCOL >> 8
        ld (pcol_h),a
        ld a,YELLOW
        ld (hud_col),a
        call lad_init
        ; the font
        ld a,BLK_GFX
        call map_blk
        ld hl,GF_FONT
        ld a,BK_FONT
        ld bc,64
        jp pcg_load

; the ladders: LD DE,nn / PUSH DE for each pair of cells, from the top of
; the ring down, then a jump back. Every cell starts as the empty pair.
lad_init:
        ld a,BLK_LAD
        call map_blk
        ld hl,0
        ld c,0
.k:     ld de,RING/2
.i:     ld (hl),$11
        inc hl
        ld (hl),c
        inc hl
        ld (hl),c
        inc hl
        ld (hl),$D5
        inc hl
        dec de
        ld a,d
        or e
        jr nz,.i
        ld (hl),$C3
        inc hl
        ld (hl),blast_ret & 255
        inc hl
        ld (hl),blast_ret >> 8
        inc c
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld h,a
        ld l,0
        ld a,c
        cp 4
        jr nz,.k
        ret

display_off:
        ld a,6
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ret
display_on:
        ld a,6
        out (P_CRTCA),a
        ld a,DROWS
        out (P_CRTCD),a
        xor a
        ld (vlast),a
        ld (fields),a
        ret

; A = block: map it into 0000-7FFF
map_blk:
        push hl
        ld (cur_blk),a
        ld l,a
        ld h,0
        push de
        ld de,blkport
        add hl,de
        pop de
        ld a,(hl)
        out (P_MEM),a
        pop hl
        ret
blkport:
        db 6,7,4,5,38,39,36,37,70,71,68,69,102,103,100,101
        db 134,135,132,133,166,167,164,165,198,199,196,197,230,231,228,229
map_game:
        ld a,BLK_GAME
        jr map_blk

win_screen:
        xor a
        out (P_COLCTL),a
        ld a,LV_SCREEN
        out (P_LV),a
        ret
win_attr:
        xor a
        out (P_COLCTL),a
        ld a,LV_ATTR
        out (P_LV),a
        ret
win_col:
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,COL_ON
        out (P_COLCTL),a
        ret

; HL = patterns (8 bytes a glyph), A = first PCG bank, BC = glyphs
pcg_load:
        ld (pl_bank),a
        xor a
        out (P_COLCTL),a
.bank:  ld a,(pl_bank)
        or LV_SCREEN
        out (P_LV),a
        ld de,PCGWIN
.g:     push bc
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        pop bc
        ld a,e
        add a,8
        ld e,a
        jr nc,.nc
        inc d
.nc:    dec bc
        ld a,b
        or c
        jr z,.done
        ld a,d
        or a
        jr nz,.g
        ld a,(pl_bank)
        inc a
        ld (pl_bank),a
        jr .bank
.done:  ld a,LV_SCREEN
        out (P_LV),a
        ret

; the level's scroll glyphs: block GFX -> TILEPAT -> PCG banks 0-11
e_gfx:  call display_off
        ld a,BLK_GFX
        call map_blk
        ld hl,GF_PAT
        ld de,TILEPAT
        ld bc,12*1024
        ldir
        ld hl,TILEPAT
        xor a
        ld bc,12*128
        call pcg_load
        ld a,BLK_MAP
        call map_blk
        ld hl,M_HUDG
        ld a,BK_HUD
        ld bc,128
        call pcg_load
        jp map_game

; the cell-glyph map as it is at the start of the level: GFX -> MAP,
; through a buffer up here
e_mapreset:
        ld hl,GF_CGMAP
        ld de,M_CGMAP
        ld b,(CGLEN + 511) / 512
.l:     push bc
        ld a,BLK_GFX
        call map_blk
        push de
        ld de,POOLBUF
        ld bc,512
        ldir
        pop de
        ld a,BLK_MAP
        call map_blk
        push hl
        ld hl,POOLBUF
        ld bc,512
        ldir
        pop hl
        pop bc
        djnz .l
        jp map_game

; ---------------------------------------------------------------------
;  text screens: the picture at the start of the ring, every cell a
;  font glyph. A = colour of the cleared screen
; ---------------------------------------------------------------------
e_text: push af
        call display_off
        call win_screen
        ld hl,VIDEO
        ld de,VIDEO+1
        ld bc,RING-1
        ld (hl),$80
        ldir
        call win_attr
        ld hl,VIDEO
        ld de,VIDEO+1
        ld bc,RING-1
        ld (hl),BK_FONT
        ldir
        call win_col
        pop af
        ld hl,PCGWIN
        ld de,PCGWIN+1
        ld bc,RING-1
        ld (hl),a
        ldir
        call win_screen
        ld hl,0
        ld (sstart),hl
        xor a
        ld (slide),a
        call set_start
        jp display_on

set_start:
        ld a,12
        out (P_CRTCA),a
        ld a,(sstart+1)
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        ld a,(sstart)
        out (P_CRTCD),a
        ld a,5                  ; the vertical total adjust: the fine slide
        out (P_CRTCA),a
        ld a,(slide)
        inc a
        out (P_CRTCD),a
        ret

; HL = string (0 ends), D = row, E = column, C = colour (text screens)
e_print:
        ld a,(mono)
        or a
        jr z,.c
        ld a,c
        or a
        jr z,.c
        ld c,WHITE
.c:     push hl
        ld l,d
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld a,l
        add hl,hl
        add hl,hl
        ld d,b
        ld b,e
        ld e,a
        add hl,de               ; row x 40
        ld e,b
        ld d,VIDEO >> 8
        add hl,de
        ex de,hl
        pop hl
.ch:    ld a,(hl)
        or a
        ret z
        inc hl
        sub 32
        or $80
        ld b,a
        call win_screen
        ld a,b
        ld (de),a
        call win_col
        set 3,d
        ld a,c
        ld (de),a
        res 3,d
        inc de
        jr .ch

; ---------------------------------------------------------------------
;  the frame clock: the 6545's vertical blanking bit, polled
; ---------------------------------------------------------------------
vpoll:  in a,(P_CRTCA)
        and $20
        ld hl,vlast
        cp (hl)
        ret z
        ld (hl),a
        or a
        ret z
        ld hl,fields
        inc (hl)
        ret

; ---------------------------------------------------------------------
;  e_snap: draw the whole picture at the camera (the display is off
;  while it is done), and forget the sprites
; ---------------------------------------------------------------------
e_snap: call display_off
        ; the whole ring empty: screen, colours, the shadows, the ladders
        call win_screen
        ld a,$80
        ld hl,VIDEO
        call fill2k
        call win_col
        xor a
        ld hl,PCGWIN
        call fill2k
        call win_screen
        ld a,$80
        ld hl,SCRSH
        call fill2k
        ld a,$80
        ld hl,ATTSH
        call fill2k
        xor a
        ld hl,CELLMAP
        call fill2k
        call lad_init
        ld hl,COLMIX
        ld de,COLMIX+1
        ld bc,255
        ld (hl),0
        ldir
        xor a
        ld (nslots),a
        ld (nold),a
        ld (sdirty),a
        ld hl,0
        ld (org),hl
        ld hl,$7000             ; requests still waiting change the map only
        ld (camcell),hl
        ld a,BLK_MAP
        call map_blk
        call list_reset
        call M_QUEUE
        call cam_cell
        ld (camcell),hl
        ld a,c
        ld (phase),a
        call v_target
        ld a,c
        ld (camrow),a
        add a,a
        add a,a
        add a,a
        sub b
        ld (slide),a
        call new_start
        ld b,COLS
        ld hl,(camcell)
.c:     push bc
        push hl
        ld (m_x),hl
        ld a,BLK_MAP
        call map_blk
        call list_reset
        call M_COLUMN
        call lad_apply
        call do_flips
        pop hl
        inc hl
        pop bc
        djnz .c
        call list_reset
        ld hl,(sstart)
        ld b,COLS*2
        call hud_mark
        call hud_build
        ld a,4
        ld (hud_dirty),a
        call hud_put
        call set_start
        call display_on
        ld a,1                  ; the first frame sets every cell's bank
        ld (sdirty),a
        jp map_game

; fill 2K at HL with A
fill2k: ld d,h
        ld e,l
        inc de
        ld bc,RING-1
        ld (hl),a
        ldir
        ret

list_reset:
        ld hl,FLIPL
        ld (entptr),hl
        ld hl,0
        ld (nflip),hl
        xor a
        ld (ncq),a
        ret

; camx -> HL = world cell column, C = shift
cam_cell:
        ld hl,(camx)
        ld a,l
        and 3
        ld c,a
        srl h
        rr l
        srl h
        rr l
        ret

; the start address and the row table from org, camcell and camrow
new_start:
        ld a,(camrow)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de               ; x 40
        ld de,(org)
        add hl,de
        ld de,(camcell)
        add hl,de
        ld de,-COLS*2           ; the status band is above the playfield
        add hl,de
        ld a,h
        and 7
        ld h,a
        ld (sstart),hl
        ex de,hl
        ld hl,ROWTAB
        ld b,DROWS
.r:     ld (hl),e
        inc l
        ld (hl),d
        inc l
        ld a,e
        add a,COLS
        ld e,a
        jr nc,.r1
        inc d
        res 3,d
.r1:    djnz .r
        ret

; camy -> B = the camera's line, C = the cell row at the top of the playfield
v_target:
        ld a,(camy)
        add a,a
        ld b,a
        ld a,(smooth)
        or a
        jr nz,.sm
        ld a,b
        add a,4
        and $F8
        ld b,a
.sm:    ld a,b
        add a,7
        rrca
        rrca
        rrca
        and $1F
        ld c,a
        ret

; ---------------------------------------------------------------------
;  THE STATUS BAND. The 6545's vertical total adjust (R5) holds the whole
;  picture down 0, 2, 4 or 6 lines: that is the smooth vertical scroll,
;  and a row step of the start address carries it on. The status line
;  would slide with it, so it is two cell rows of glyphs drawn the same
;  amount UP: it stays where it is on the monitor.
;  A glyph's code: slide / 2 x 32 + (bottom row ? 16 : 0) + glyph (0-15).
; ---------------------------------------------------------------------
; HL = ring offset, B = cells: they are status cells now, not background
hud_mark:
        ld a,h
        and 7
        or ATTSH >> 8
        ld h,a
.l:     ld (hl),BK_HUD
        inc l
        jr nz,.n
        inc h
        ld a,h
        and 7
        or ATTSH >> 8
        ld h,a
.n:     djnz .l
        ret

; a column came on: the status band's new cell in each of its rows.
; A = that column (0 or 39)
hud_newcol:
        ld e,a
        ld d,0
        ld hl,(sstart)
        add hl,de
        push hl
        call .one
        pop hl
        ld de,COLS
        add hl,de
.one:   ld a,h
        and 7
        ld h,a
        push hl
        ld b,1
        call hud_mark
        pop de
        ld hl,(entptr)
        ld (hl),e
        inc hl
        ld a,d
        or VIDEO >> 8
        ld (hl),a
        inc hl
        ld (hl),$80
        inc hl
        ld (hl),BK_HUD
        inc hl
        ld a,(hud_col)
        ld (hl),a
        inc hl
        ld (hl),BK_HUD
        inc hl
        ld (entptr),hl
        ld hl,(nflip)
        inc hl
        ld (nflip),hl
        ld hl,ncq
        inc (hl)
        ret

; the band's 80 screen codes for the present slide
hud_build:
        xor a
        ld (hud_rb),a
        ld a,(slide)
        rrca
        rrca
        rrca
        rrca
        and $60
        or $80
        ld c,a
        ld hl,HUDBUF
        ld de,HUDCODE
        ld b,COLS
.l:     ld a,(hl)
        or c
        ld (de),a
        or $10
        push de
        push af
        ld a,e
        add a,COLS
        ld e,a
        pop af
        ld (de),a
        pop de
        inc hl
        inc e
        djnz .l
        ret

; the band -> the screen, in the blanking. (hud_dirty): 1 the codes,
; 2 / 3 and the bank and colour of row 0 / row 1 (new after a row step),
; 4 and of both
hud_put:
        ld a,(hud_dirty)
        ld c,a
        xor a
        ld (hud_dirty),a
        push bc
        call win_screen
        ld hl,(sstart)
        ld a,h
        or VIDEO >> 8
        ld d,a
        ld e,l
        ld hl,RING
        ld bc,(sstart)
        or a
        sbc hl,bc               ; cells to the end of the ring
        ld a,h
        or a
        jr nz,.one
        ld a,l
        cp COLS*2
        jr nc,.one
        ld c,a
        ld b,0
        ld a,COLS*2
        sub c
        push af
        ld hl,HUDCODE
        ldir
        ld de,VIDEO
        pop af
        ld c,a
        ld b,0
        ldir
        jr .attr
.one:   ld hl,HUDCODE
        ld bc,COLS*2
        ldir
.attr:  pop bc
        ld a,c
        cp 2
        ret c
        ld hl,(sstart)
        ld b,COLS
        jr z,.go
        cp 3
        jr nz,.all
        ld de,COLS
        add hl,de
        jr .go
.all:   ld b,COLS*2
.go:    push hl
        push bc
        call win_attr
        ld a,BK_HUD
        ld c,VIDEO >> 8
        call .fill
        pop bc
        pop hl
        call win_col
        ld a,(hud_col)
        ld c,PCGWIN >> 8
        call .fill
        jp win_screen
; HL = ring offset, B = cells, C = the window's high byte, A = the value
.fill:  ld e,a
        ld a,h
        and 7
        or c
        ld h,a
.f:     ld (hl),e
        inc l
        jr nz,.n
        inc h
        ld a,h
        and 7
        or c
        ld h,a
.n:     djnz .f
        ret

; ---------------------------------------------------------------------
;  the vertical scroll: follow the camera's line. A row step brings a
;  row of 40 cells on, and moves the status band a row along the ring.
;  It waits a frame if a column came on in this one.
; ---------------------------------------------------------------------
vscroll:
        call v_target           ; B = line, C = row
        ld a,(camrow)
        cp c
        jr z,.fine
        ld a,(colstep)
        or a
        ret nz
        ld a,(camrow)
        cp c
        jr c,.down
        dec a
        ld (camrow),a
        cp c
        jr z,.u1
        add a,a                 ; more than a row to go: as far as this row lets it
        add a,a
        add a,a
        sub 6
        ld b,a
.u1:    push bc
        call new_start
        ld hl,(sstart)          ; the band's top row is new cells
        ld b,COLS
        call hud_mark
        ld a,(camrow)
        ld (m_r),a
        call M_ROW
        pop bc
        ld a,2
        jr .stepped
.down:  inc a
        ld (camrow),a
        cp c
        jr z,.d1
        add a,a
        add a,a
        add a,a
        ld b,a
.d1:    push bc
        call new_start
        ld hl,(sstart)          ; the band's bottom row was the playfield's top
        ld de,COLS
        add hl,de
        ld b,COLS
        call hud_mark
        ld a,(camrow)
        add a,PFROWS-1
        ld (m_r),a
        call M_ROW
        pop bc
        ld a,3
.stepped:
        ld (hud_dirty),a
.fine:  ld a,(camrow)
        add a,a
        add a,a
        add a,a
        sub b
        ld hl,slide
        cp (hl)
        ret z
        ld (hl),a
        ld a,1
        ld (hud_rb),a
        ld a,(hud_dirty)
        or a
        ret nz
        inc a
        ld (hud_dirty),a
        ret

; ---------------------------------------------------------------------
;  e_frame: one frame. The game has moved things, set camx, queued its
;  sprites (DRAWQ) and its map requests (MAPQ).
; ---------------------------------------------------------------------
e_frame:
        call frame_begin
        call list_reset
        call vpoll
        ld a,BLK_MAP
        call map_blk
        xor a
        ld (colstep),a
        ; ---- the scroll
        call cam_cell           ; HL = cell, C = shift
        ld a,(phase)
        ld (oldphase),a
        cp c
        ld a,0
        jr z,.ph
        ld a,c
        ld (phase),a
        ld a,1
        ld (sdirty),a
        ld a,2
.ph:    ld (scratch+7),a        ; 2: the shift changed
        ld (scratch+4),hl       ; the cell wanted
.step:  ld hl,(scratch+4)
        ld de,(camcell)
        or a
        sbc hl,de
        jr z,.steady
        ld a,1
        ld (sdirty),a
        ld (hud_dirty),a
        ld (colstep),a
        jp m,.left
        inc de
        ld (camcell),de
        call new_start
        ld a,COLS-1
        call hud_newcol
        ld hl,(camcell)
        ld de,COLS-1
        add hl,de
        jr .col
.left:  dec de
        ld (camcell),de
        call new_start
        xor a
        call hud_newcol
        ld hl,(camcell)
.col:   ld (m_x),hl
        call M_COLUMN
        jr .step
.steady:
        call vscroll
        ld a,(hud_rb)
        or a
        call nz,hud_build
ef_queue:
        call M_QUEUE
        ld a,(scratch+7)
        or a
        call nz,M_MIXED
        call vpoll
        call lad_apply
        call vpoll
        ; ---- the sprites
ef_sprites:
        ld hl,(entptr)
        ld (sprstart),hl
        ld a,(ndraw)
        or a
        jr z,.nospr
        ld b,a
        ld hl,DRAWQ
.spr:   push bc
        ld a,(hl)
        ld (sd_frame),a
        inc l
        ld a,(hl)
        ld (sd_face),a
        inc l
        ld e,(hl)
        inc l
        ld d,(hl)
        inc l
        ld (sd_x),de
        ld e,(hl)
        inc l
        ld d,(hl)
        inc l
        ld (sd_y),de
        ld a,(mono)
        or a
        ld a,(hl)
        jr z,.ink
        ld a,WHITE
.ink:   ld (ds_col),a
        inc l
        inc l
        push hl
        call sprite
        call vpoll
        pop hl
        pop bc
        djnz .spr
        xor a
        ld (ndraw),a
.nospr: call restores
        call present
        jp map_game

; ---------------------------------------------------------------------
;  the ladders' operands for the background cells at the head of the
;  flip list (the cells that came on to the screen or changed)
; ---------------------------------------------------------------------
lad_apply:
        ld a,(ncq)
        or a
        ret z
        ld b,a
        ld a,BLK_LAD
        call map_blk
        ld ix,FLIPL
.e:     ld l,(ix+0)
        ld a,(ix+1)
        and 7
        ld h,a
        ld a,l
        and 1
        ld c,a
        add hl,hl
        ex de,hl
        ld hl,RING*2-3
        or a
        sbc hl,de
        ld a,c
        or a
        jr z,.ev
        inc hl
        inc hl
        inc hl
.ev:    ld a,(ix+5)
        ld de,LADSTEP
        bit 7,a
        jr z,.flat
        and $0C
        ld (hl),a
        add hl,de
        inc a
        ld (hl),a
        add hl,de
        inc a
        ld (hl),a
        add hl,de
        inc a
        ld (hl),a
        jr .n
.flat:                          ; a status cell: the ladders never reach it
.n:     ld de,6
        add ix,de
        djnz .e
        ret

; ---------------------------------------------------------------------
;  shift the picture: run this shift's ladder over the cells on show
; ---------------------------------------------------------------------
blast_attr:
        ld a,BLK_LAD
        call map_blk
        xor a
        out (P_COLCTL),a
        ld a,LV_ATTR
        out (P_LV),a
        ld hl,(sstart)          ; the playfield: below the status band
        ld de,COLS*2
        add hl,de
        ld a,h
        and 7
        ld h,a
        ld (bl_start),hl
        ld de,COLS*PFROWS
        add hl,de               ; its end in the ring
        ld a,h
        cp RING >> 8
        jr c,.one
        jr nz,.two
        ld a,l
        or a
        jr z,.one
.two:   ld de,1-RING            ; the part past the end of the ring
        add hl,de
        res 0,l
        ld de,0
        call blast_run
        ld hl,RING-1
.one:   inc hl
        res 0,l
        ld de,(bl_start)
        res 0,e
        call blast_run
        ld hl,(bl_start)        ; the ladder works in pairs of cells: if it began
        bit 0,l                 ; a cell early, that was the status band's last
        jr z,.ev
        dec hl
        ld a,h
        or VIDEO >> 8
        ld h,a
        ld (hl),BK_HUD
.ev:    ld a,LV_SCREEN
        out (P_LV),a
        ret

; DE = first ring cell (even), HL = the cell after the last (even)
blast_run:
        ld (bl_hi),hl
        ld a,(phase)            ; this ladder's end: phase * LADSTEP + 4096
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        add a,(RING*2) >> 8
        ld b,a
        ld c,0
        ex de,hl
        add hl,hl
        ex de,hl
        ld h,b
        ld l,c
        or a
        sbc hl,de               ; where to leave it
        ld (bl_lo),hl
        ld de,bl_save
        ld a,(hl)
        ld (de),a
        ld (hl),$C3
        inc hl
        inc de
        ld a,(hl)
        ld (de),a
        ld (hl),blast_ret & 255
        inc hl
        inc de
        ld a,(hl)
        ld (de),a
        ld (hl),blast_ret >> 8
        ld hl,(bl_hi)
        add hl,hl
        ex de,hl
        ld h,b
        ld l,c
        or a
        sbc hl,de               ; where to enter it
        ex de,hl
        ld hl,(bl_hi)
        ld a,h
        or VIDEO >> 8
        ld h,a
        ld (savesp),sp
        ld sp,hl
        ex de,hl
        jp (hl)
blast_ret:
        ld sp,(savesp)
        ld hl,(bl_lo)
        ld de,bl_save
        ld a,(de)
        ld (hl),a
        inc hl
        inc de
        ld a,(de)
        ld (hl),a
        inc hl
        inc de
        ld a,(de)
        ld (hl),a
        ret

; ---------------------------------------------------------------------
;  a frame of sprites
; ---------------------------------------------------------------------
frame_begin:
        ld a,(nslots)
        ld (nold),a
        or a
        jr z,.sw
        ld b,a
        ld hl,(curlist)
.c:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        xor a
        ld (de),a
        djnz .c
.sw:    ld hl,(curlist)
        ld de,(oldlist)
        ld (oldlist),hl
        ld (curlist),de
        ld (listptr),de
        ld a,(poolbank)
        xor BK_POOLA ^ BK_POOLB
        ld (poolbank),a
        xor a
        ld (nslots),a
        ret

; sprite: frame (sd_frame), facing (sd_face: 0 right, 1 left), with its
; top left at screen pixel (sd_x, sd_y), ink colour (ds_col)
sprite:
        ld a,(sd_frame)
        add a,a
        ld l,a
        ld a,(sd_face)
        or l
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,sprtab
        add hl,de
        ld a,(cur_blk)
        cp (hl)
        jr z,.mapped
        ld a,(hl)
        call map_blk
.mapped:
        inc hl
        inc hl
        push hl
        ld hl,(sd_x)
        ld a,l
        and 7
        ld (ds_sh),a
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld a,l
        ld (ds_cx),a
        ld de,8                 ; on the screen at all? cell column -8..47
        add hl,de
        ld a,h
        or a
        jr nz,.off
        ld a,l
        cp 56
        jr nc,.off
        ld a,(camrow)           ; the game gives y in the level: the picture
        add a,a                 ; starts camrow rows down it
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,(sd_y)
        or a
        sbc hl,de
        ld de,64                ; a bias, so a sprite can hang off the top
        add hl,de
        ld a,h
        or a
        jr nz,.off
        ld a,l
        and 7
        ld (ds_ry),a
        ld a,l
        rrca
        rrca
        rrca
        and $1F
        sub 8
        ld (ds_cy),a
        pop hl
        ld a,(hl)               ; the frame's eight variants: a table in its block
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(ds_sh)
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp spr_draw
.off:   pop hl
        ret

; HL = variant data: the number of cell columns, then for each column
; its first line, its line count n, and n x (mask, image)
spr_draw:
        ld a,(hl)
        inc hl
        ld (ds_n),a
.col:   ld d,(hl)               ; lines to skip
        inc hl
        ld c,(hl)               ; lines
        inc hl
        ld a,c
        or a
        jr z,.colnext
        ld a,(ds_cx)
        cp COLS
        jr nc,.skipcol
        ld a,(ds_ry)
        add a,d
        ld e,a
        rrca
        rrca
        rrca
        and $1F
        ld b,a
        ld a,(ds_cy)
        add a,b
        ld (ds_cyc),a
        ld a,e
        and 7
        ld e,a                  ; line in the cell
.seg:   ld a,8
        sub e
        cp c
        jr c,.n1
        ld a,c
.n1:    ld b,a                  ; lines in this cell
        ld a,c
        sub b
        ld c,a
        ld a,(ds_cyc)
        cp PF_ROW0
        jr c,.skipseg
        cp PF_ROW1
        jr nc,.skipseg
        push bc
        push hl
        call getbuf
        pop hl
        pop bc
.ln:    ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        djnz .ln
        jr .next
.skipseg:
        ld a,b
        add a,a
        add a,l
        ld l,a
        jr nc,.next
        inc h
.next:  ld e,0
        ld a,(ds_cyc)
        inc a
        ld (ds_cyc),a
        ld a,c
        or a
        jr nz,.seg
        jr .colnext
.skipcol:
        ld a,c
        add a,a
        add a,l
        ld l,a
        jr nc,.colnext
        inc h
.colnext:
        ld a,(ds_cx)
        inc a
        ld (ds_cx),a
        ld a,(ds_n)
        dec a
        ld (ds_n),a
        jr nz,.col
        ret

; A = cell row, E = line in the cell -> DE = the cell's glyph buffer + line.
; A cell not yet in this frame gets the next pool slot: its buffer starts
; as the background's glyph at the present shift, and its flip-list entry
; is written here.
getbuf:
        add a,a
        ld l,a
        ld h,ROWTAB >> 8
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,(ds_cx)
        add a,l
        ld l,a
        jr nc,.g1
        inc h
.g1:    ld a,h
        and 7
        or CELLMAP >> 8
        ld h,a
        ld a,(hl)
        or a
        jr z,.alloc
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or e
        ld e,a
        ld a,h
        add a,POOLBUF >> 8
        ld d,a
        ret
.alloc: ld a,(nslots)
        cp MAXSLOT
        jr nc,.full
        inc a
        ld (nslots),a
        ld (hl),a
        ld c,a                  ; slot
        push de                 ; the line
        ex de,hl                ; DE = CELLMAP address
        ld hl,(listptr)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (listptr),hl
        ld hl,(entptr)
        ld (hl),e
        inc hl
        ld a,d
        and 7
        or VIDEO >> 8
        ld (hl),a
        inc hl
        ld a,c
        or $80
        ld (hl),a
        inc hl
        ld a,(poolbank)
        ld (hl),a
        inc hl
        ld a,(ds_col)
        ld (hl),a
        inc hl
        inc hl
        ld (entptr),hl
        ld hl,(nflip)
        inc hl
        ld (nflip),hl
        ld a,d
        add a,(SCRSH - CELLMAP) >> 8
        ld h,a
        ld l,e
        ld b,(hl)               ; the background's code
        add a,(ATTSH - SCRSH) >> 8
        ld h,a
        ld a,(hl)
        and $0F
        ld l,a
        ld a,(phase)
        or l                    ; its bank
        ld h,a
        ld a,b
        add a,a
        ld l,a
        ld a,h
        or a
        rra
        ld h,a
        rr l                    ; bank * 128 + code
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,TILEPAT >> 8
        ld h,a
        push hl
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,POOLBUF >> 8
        ld d,a
        ld e,l
        pop hl
        push de
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        pop de
        pop hl                  ; L = the line
        ld a,l
        or e
        ld e,a
        ret
.full:  ld a,e
        add a,scratch & 255
        ld e,a
        ld d,scratch >> 8
        ret

; ---------------------------------------------------------------------
;  cells the last frame's sprites covered and this frame's do not go
;  back to the background: add them to the flip list
; ---------------------------------------------------------------------
restores:
        ld a,BLK_MAP
        call map_blk
        ; a sprite's cell over solid ground keeps the ground's ink
        ld a,(nslots)
        or a
        jr z,.r0
        ld b,a
        ld ix,(sprstart)
.f:     ld l,(ix+0)
        ld a,(ix+1)
        and 7
        or ATTSH >> 8
        ld h,a
        ld e,(hl)
        bit 5,e
        jr z,.fn
        sub (ATTSH - SCRSH) >> 8
        ld h,a
        ld d,(hl)
        ld a,e
        and $0F
        ld c,a
        ld a,(phase)
        or c
        ld c,a
        ld a,d
        add a,a
        ld l,a
        ld a,c
        or a
        rra
        ld h,a
        rr l
        ld a,(pcol_h)
        add a,h
        ld h,a
        ld a,(hl)
        ld (ix+4),a
.fn:    ld de,6
        add ix,de
        djnz .f
.r0:    ld a,(nold)
        or a
        ret z
        ld b,a
        ld de,(oldlist)
.o:     ld a,(de)
        ld l,a
        inc de
        ld a,(de)
        ld h,a
        inc de
        ld a,(hl)
        or a
        jr nz,.on
        push bc
        push de
        ld a,h
        and 7
        ld h,a                  ; the ring offset
        push hl
        ld de,(sstart)          ; in the status line now? leave it
        or a
        sbc hl,de
        ld a,h
        and 7
        jr nz,.pf
        ld a,l
        cp COLS*2
        jr nc,.pf
        pop hl
        jr .skip
.pf:    pop hl
        ld ix,(entptr)
        ld (ix+0),l
        ld a,h
        or VIDEO >> 8
        ld (ix+1),a
        ld a,h
        or SCRSH >> 8
        ld h,a
        ld d,(hl)
        add a,(ATTSH - SCRSH) >> 8
        ld h,a
        ld e,(hl)
        ld (ix+2),d
        ld (ix+5),e
        ld a,e
        and $0F
        ld c,a
        ld a,(phase)
        or c
        ld (ix+3),a
        ld c,a
        ld a,d
        add a,a
        ld l,a
        ld a,c
        or a
        rra
        ld h,a
        rr l
        ld a,(pcol_h)
        add a,h
        ld h,a
        ld a,(hl)
        ld (ix+4),a
        ld de,6
        add ix,de
        ld (entptr),ix
        ld hl,(nflip)
        inc hl
        ld (nflip),hl
.skip:  pop de
        pop bc
.on:    djnz .o
        ret

; ---------------------------------------------------------------------
;  present. The sprites' new glyphs go into the pool that is not on
;  show in the middle blanking of the frame's two fields, if they are
;  ready by then; the frame itself is shown at the second blanking:
;  the start address, the shift, the cells. 25 frames a second.
; ---------------------------------------------------------------------
present:
        call snd_tick
        xor a
        ld (bl_edge),a
        ld (lateblast),a
        ld a,(nslots)
        or a
        jr z,.vis
        call vpoll
        ld a,(fields)
        or a
        jr nz,.f1
        call snd_wait           ; to the middle blanking
        call blast
        jr .vis
.f1:    dec a
        jr nz,.late
        in a,(P_CRTCA)
        and $20
        jr z,.late
        call blast              ; it has begun: there is still time
        jr .vis
.late:  ld a,1
        ld (lateblast),a
.vis:   ld a,(fields)
        cp 2
        jr nc,.over
.w:     call snd_wait
        ld a,(fields)
        cp 2
        jr c,.w
        jr .show
.over:  ld hl,perf_late
        inc (hl)
        ld a,(bl_edge)
        or a
        jr nz,.show
        call snd_wait
.show:  ld a,(sdirty)
        or a
        push af
        call set_start
        pop af
        jr z,.nb
        call blast_attr
        xor a
        ld (sdirty),a
.nb:    ld a,(lateblast)
        or a
        call nz,blast
        call do_flips
        ld a,(hud_dirty)
        or a
        call nz,hud_put
        xor a
        ld (fields),a
        ld a,$20
        ld (vlast),a
        ret

do_flips:
        ld hl,(nflip)
        ld a,h
        or l
        ret z
        dec hl
        ld a,h
        inc hl
        ld ixh,a
        ld a,l
        ld ixl,a
        ld (savesp),sp
        ld sp,FLIPL
        ld a,COL_ON
        out (P_COLCTL),a
        ld c,P_LV
        ld b,LV_SCREEN
        ld a,LV_ATTR
.lp:    pop hl
        pop de
        out (c),b
        ld (hl),e
        out (c),a
        ld (hl),d
        set 3,h
        pop de
        ld (hl),e
        dec ixl
        jp nz,.lp
        dec ixh
        jp p,.lp
        ld sp,(savesp)
        xor a
        out (P_COLCTL),a
        ld a,LV_SCREEN
        out (P_LV),a
        ret

; the composed glyphs -> the pool that is not on show
blast:  ld a,(nslots)
        or a
        ret z
        ld ixl,a
        ld a,(vlast)
        ld ixh,a
        xor a
        out (P_COLCTL),a
        ld a,(poolbank)
        or LV_SCREEN
        out (P_LV),a
        ld hl,POOLBUF+8
        ld de,PCGWIN+16
        ld bc,$7FFF
.g:     ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ld a,e
        add a,8
        ld e,a
        jr nc,.nc
        inc d
.nc:    in a,(P_CRTCA)
        and $20
        cp ixh
        call nz,.chg
        dec ixl
        jr nz,.g
        ld a,ixh
        ld (vlast),a
        ld a,LV_SCREEN
        out (P_LV),a
        ret
.chg:   ld ixh,a
        or a
        ret z
        push hl
        ld hl,fields
        inc (hl)
        ld hl,bl_edge
        ld (hl),1
        pop hl
        ret

; ---------------------------------------------------------------------
;  keyboard (6545 light pen scan) and joystick -> C = the game's keys
; ---------------------------------------------------------------------
keytest:
        push bc
        ld b,a
        ld a,$12
        out (P_CRTCA),a
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and $03
        out (P_CRTCD),a
        ld a,$13
        out (P_CRTCA),a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        and $F0
        out (P_CRTCD),a
        ld a,$10
        out (P_CRTCA),a
        in a,(P_CRTCD)
        ld a,$1F
        out (P_CRTCA),a
        out (P_CRTCD),a
        nop
        ld b,0
.w:     in a,(P_CRTCA)
        bit 7,a
        jr nz,.d
        djnz .w
.d:     and $40
        pop bc
        ret

keymap: db K_RIGHT,K_R, K_LEFT,K_L, K_UP,K_U, K_DOWN,K_D, K_SPACE,K_J
        db K_P,K_R, K_O,K_L, K_Q,K_U, K_A,K_D, K_M,K_J, K_X,K_R, K_Z,K_L
        db K_S,K_MUS, K_ESC,K_QUIT
        db $FF
keymenu: db K_M,K_MONO, K_C,K_MUS, K_SPACE,K_J, K_ESC,K_QUIT
        db $FF

e_menukeys:
        ld hl,keymenu
        jr read_keys
e_input:
        ld hl,keymap
read_keys:
        ld a,1
        out (P_ROMLAT),a
        ld c,0
.k:     ld a,(hl)
        cp $FF
        jr z,.kd
        inc hl
        call keytest
        jr z,.nk
        ld a,(hl)
        or c
        ld c,a
.nk:    inc hl
        jr .k
.kd:    xor a
        out (P_ROMLAT),a
        ; joystick: b0 up b1 down b2 left b3 right b7 fire, active low
        in a,(P_PIOA)
        cpl
        ld b,a
        and $8F
        jr z,.nj
        ld a,b
        cp $FF                  ; nothing plugged in reads all low? ignore
        jr z,.nj
        bit 0,b
        jr z,.j1
        set KB_U,c
.j1:    bit 1,b
        jr z,.j2
        set KB_D,c
.j2:    bit 2,b
        jr z,.j3
        set KB_L,c
.j3:    bit 3,b
        jr z,.j4
        set KB_R,c
.j4:    bit 7,b
        jr z,.nj
        set KB_J,c
.nj:    ld a,(pad)
        cpl
        and c
        ld (padnew),a
        ld a,c
        ld (pad),a
        ret

; random byte in A
rnd8:   push hl
        ld hl,(rseed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (rseed),hl
        pop hl
        ret
