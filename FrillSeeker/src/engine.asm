; =====================================================================
;  ENGINE: hardware start-up, the cell renderer, the frame clock
;
;  The renderer. Every screen cell can show any of 2048 glyphs, so a
;  sprite is not built from tiles: for each cell a sprite touches, a
;  private glyph is composed in RAM (the background's own glyph with
;  the sprite masked over it) and the cell is pointed at it. Two glyph
;  pools take turns, so the new frame's glyphs are written while the
;  old ones are still on show, and the only thing done in the vertical
;  blanking is a short list of cell changes: the picture never tears
;  and nothing is ever erased and redrawn in view.
; =====================================================================

; 64 x 32 cells of 6 lines: 52 rows x 6 + 1 = 313 lines
crtc_game:  db $6B,64,$51,$37,51,1,32,43,$48,5,$20,5,0,0,0,0

hw_init:
        di
        ld hl,VARS
        ld de,VARS+1
        ld bc,$FF
        ld (hl),0
        ldir
        ; PIO A: input (joystick)
        ld a,$CF
        out (P_PIOAC),a
        ld a,$FF
        out (P_PIOAC),a
        ld a,$07
        out (P_PIOAC),a
        ; PIO B: bit control, b6 speaker out
        ld a,$CF
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
        ld hl,crtc_game
        call crtc_set
        call display_off
        ld hl,LISTA
        ld (curlist),hl
        ld hl,LISTB
        ld (oldlist),hl
        ld a,BK_POOLA
        ld (poolbank),a
        ld hl,$5EED
        ld (rseed),hl
        ; the font
        ld a,BLK_GFX
        call map_blk
        ld hl,0
        ld a,BK_FONT
        ld bc,256
        call pcg_load
        ret

crtc_set:
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
        ld a,32
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

; HL = patterns (6 bytes a glyph), A = first PCG bank, BC = glyphs
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
        pop bc
        ld a,e
        add a,10
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

; clear the screen to font spaces, colour A
cls:    push af
        call win_screen
        ld hl,VIDEO
        ld de,VIDEO+1
        ld bc,2047
        ld (hl),$80
        ldir
        call win_attr
        ld hl,VIDEO
        ld de,VIDEO+1
        ld bc,2047
        ld (hl),BK_FONT
        ldir
        call win_col
        pop af
        ld hl,PCGWIN
        ld de,PCGWIN+1
        ld bc,2047
        ld (hl),a
        ldir
        jp win_screen

; ---------------------------------------------------------------------
;  text: the 8 x 12 font, four glyphs a letter (2 cells x 2 rows)
;  HL = string (0 ends), D = cell row, E = letter column (0..31), C = colour
; ---------------------------------------------------------------------
print:
.ch:    ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        push de
        call putch
        pop de
        pop hl
        inc e
        jr .ch

; A = character, D = cell row, E = letter column, C = colour
putch:  ld b,a
        ld a,(mono)
        or a
        jr z,.pc
        ld c,WHITE              ; a monochrome monitor shows ink only
.pc:    ld a,b
        sub 32
        ld b,a                  ; 0..63
        ; HL = VIDEO + row*64 + col*2
        ld a,d
        rrca
        rrca
        ld h,a
        and $C0
        ld l,a
        ld a,h
        and 7
        or VIDEO >> 8
        ld h,a
        ld a,e
        add a,a
        or l
        ld l,a
        ld a,b
        and 31
        add a,a
        add a,a
        or $80
        ld e,a                  ; first glyph code
        ld a,b
        rlca
        rlca
        rlca
        and 1
        add a,BK_FONT
        ld d,a                  ; bank
        push hl
        call win_screen
        ld (hl),e
        inc l
        inc e
        ld (hl),e
        ld a,l
        add a,63
        ld l,a
        jr nc,.a
        inc h
.a:     inc e
        ld (hl),e
        inc l
        inc e
        ld (hl),e
        pop hl
        push hl
        call win_attr
        ld (hl),d
        inc l
        ld (hl),d
        ld a,l
        add a,63
        ld l,a
        jr nc,.b
        inc h
.b:     ld (hl),d
        inc l
        ld (hl),d
        pop hl
        call win_col
        set 3,h
        ld (hl),c
        inc l
        ld (hl),c
        ld a,l
        add a,63
        ld l,a
        jr nc,.c
        inc h
.c:     ld (hl),c
        inc l
        ld (hl),c
        jp win_screen

; ---------------------------------------------------------------------
;  rooms
; ---------------------------------------------------------------------
room_map:
        ld a,(room)
        srl a
        ld b,a
        ld a,(roomblk0)
        add a,b
        call map_blk
        ld a,(room)
        and 1
        rrca
        rrca
        ld (roombase_h),a
        ret

; HL = offset in the room record -> HL = its address
room_ptr:
        ld a,(roombase_h)
        add a,h
        ld h,a
        ret

; A = room: load its picture, glyphs and map into the shadows and the PCG
; (the display is off; room_show puts it on the screen)
room_load:
        ld (room),a
        call display_off
        call room_map
        ld hl,R_SCR
        call room_ptr
        ld de,SCRSH
        ld bc,2048
        ldir
        ld hl,R_ATTR
        call room_ptr
        ld de,ATTSH
        ld bc,2048
        ldir
        ld hl,R_COL
        call room_ptr
        ld de,COLSH
        ld bc,2048
        ldir
        ld hl,R_TMAP
        call room_ptr
        ld de,TMAP
        ld bc,160
        ldir
        ld hl,R_NPAT
        call room_ptr
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (rm_npat),bc
        ld a,(hl)
        ld (nb_left),a
        inc hl
        ld a,(hl)
        ld (nb_right),a
        ; glyph patterns: to TILEPAT (for compositing) and to the PCG
        ld hl,(rm_npat)
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        add hl,hl               ; n * 6
        ld b,h
        ld c,l
        ld hl,R_PAT
        call room_ptr
        push hl
        ld de,TILEPAT
        ldir
        pop hl
        ld bc,(rm_npat)
        xor a
        call pcg_load
        call anim_init
        ; no sprites on show
        ld hl,CELLMAP
        ld de,CELLMAP+1
        ld bc,2047
        ld (hl),0
        ldir
        xor a
        ld (nslots),a
        ld (nold),a
        ret

; the shadows -> the screen
room_show:
        call win_screen
        ld hl,SCRSH
        ld de,VIDEO
        ld bc,2048
        ldir
        call win_attr
        ld hl,ATTSH
        ld de,VIDEO
        ld bc,2048
.at:    ld a,(hl)               ; bit 4 is the renderer's own flag
        and 15
        ld (de),a
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.at
        call win_col
        ld hl,COLSH
        ld de,PCGWIN
        ld bc,2048
        ldir
        jp win_screen

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
        ld hl,FLIPL
        ld (entptr),hl
        ld a,(poolbank)
        xor BK_POOLA ^ BK_POOLB
        ld (poolbank),a
        xor a
        ld (nslots),a
        ret

; sprite: frame (sd_frame), facing (sd_face: 0 right, 1 left), at
; playfield pixel (sd_x, sd_y) = its hot spot, ink colour (ds_col)
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
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; x 12
        ld de,sprtab
        add hl,de
        ld a,(cur_blk)
        cp (hl)
        jr z,.mapped
        ld a,(hl)
        call map_blk
.mapped:
        inc hl
        ld a,(hl)               ; x offset of the hot spot
        inc hl
        ld e,a
        rla
        sbc a,a
        ld d,a
        push hl
        ld hl,(sd_x)
        or a
        sbc hl,de               ; left edge, pixels
        ld a,l
        and 3
        ld (ds_sh),a
        sra h
        rr l
        sra h
        rr l
        ld a,l
        ld (ds_cx),a
        ; on the screen at all? cell column -16..79
        ld de,16
        add hl,de
        ld a,h
        or a
        jr nz,.off
        ld a,l
        cp 96
        jr nc,.off
        pop hl
        ld a,(hl)               ; y offset
        inc hl
        inc hl
        ld e,a
        rla
        sbc a,a
        ld d,a
        push hl
        ld hl,(sd_y)
        or a
        sbc hl,de
        ld de,60                ; + 12 lines of status panel + 48 table bias
        add hl,de
        ld a,h
        or a
        jr nz,.off
        ld h,div6tab >> 8
        ld a,(hl)
        ld (ds_cy),a
        inc h
        ld a,(hl)
        ld (ds_ry),a
        pop hl
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
; its first line, its line count n, and n x (mask, image). Empty parts
; of a column cost nothing and touch no cell.
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
        cp 64
        jr nc,.skipcol
        ld a,(ds_cy)
        ld b,a
        ld a,(ds_ry)
        add a,d
.m6:    cp 6
        jr c,.m6d
        sub 6
        inc b
        jr .m6
.m6d:   ld e,a                  ; line in the cell
        ld a,b
        ld (ds_cyc),a
.seg:   ld a,6
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
        cp 32
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
; as the background's glyph, and its flip-list entry is written here.
getbuf:
        rrca
        rrca
        ld h,a
        and $C0
        ld l,a
        ld a,h
        and $07
        or CELLMAP >> 8
        ld h,a
        ld a,(ds_cx)
        or l
        ld l,a
        ld a,(hl)
        or a
        jr z,.alloc
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,e
        or l
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
        add a,(VIDEO >> 8) - (CELLMAP >> 8)
        ld (hl),a
        inc hl
        ld a,c
        or $80
        ld (hl),a
        inc hl
        ld a,c
        rlca
        and 1
        ld b,a
        ld a,(poolbank)
        add a,b
        ld (hl),a
        inc hl
        push hl
        ld h,d
        ld l,e
        ld a,h
        sub 8
        ld h,a
        ld b,(hl)               ; glyph bank, b4 = busy cell: keep its ink
        sub 8
        ld h,a
        ld e,(hl)               ; screen code
        sub 8
        ld h,a
        ld a,(hl)               ; colours
        pop hl
        bit 4,b
        jr nz,.keep
        and $F0
        ld d,a
        ld a,(ds_col)
        or d
.keep:  ld (hl),a
        inc hl
        inc hl
        ld (entptr),hl
        ld a,e
        add a,a
        ld l,a
        ld a,b
        and 15
        ld h,a                  ; glyph id x 2
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; x 6
        ld de,TILEPAT
        add hl,de
        ex de,hl
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,POOLBUF >> 8
        ld h,a
        ex de,hl
        push de
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
        ld c,0
        ld a,(nold)
        or a
        jr z,.done
        ld b,a
        ld de,(oldlist)
        exx
        ld hl,(entptr)
        exx
.o:     ld a,(de)
        inc de
        ld l,a
        ld a,(de)
        inc de
        ld h,a
        ld a,(hl)
        or a
        jr nz,.on
        ld a,l
        exx
        ld (hl),a
        inc hl
        exx
        ld a,h
        add a,(VIDEO >> 8) - (CELLMAP >> 8)
        exx
        ld (hl),a
        inc hl
        exx
        ld a,h
        sub $10
        ld h,a
        ld a,(hl)               ; screen code
        exx
        ld (hl),a
        inc hl
        exx
        ld a,h
        add a,8
        ld h,a
        ld a,(hl)               ; glyph bank
        and 15
        exx
        ld (hl),a
        inc hl
        exx
        ld a,h
        sub $10
        ld h,a
        ld a,(hl)               ; colours
        exx
        ld (hl),a
        inc hl
        inc hl
        exx
        inc c
.on:    djnz .o
.done:  ld a,(nslots)
        add a,c
        ld l,a
        ld h,0
        jr nc,.nc
        inc h
.nc:    ld (nflip),hl
        ret
; ---------------------------------------------------------------------
;  present: write the new glyphs into the hidden pool, wait for the
;  blanking, then make the cell changes
; ---------------------------------------------------------------------
present:
        xor a
        ld (bl_edge),a
        call blast
        ld a,(bl_edge)
        or a
        jr nz,.flip
        in a,(P_CRTCA)
        and $20
        jr z,.wait
        ld hl,vlast
        cp (hl)
        jr z,.wait              ; this blanking is an old one
        ld (hl),a               ; it began this instant
        ld hl,fields
        inc (hl)
        jr .flip
.wait:  call snd_wait
.flip:  ; fall into do_flips

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
        inc hl
        inc hl
        ld a,e
        add a,10
        ld e,a
        jr nc,.nc
        inc d
        jr nz,.nc
        ld d,PCGWIN >> 8        ; glyph 128: the pool's second bank
        ld a,(poolbank)
        inc a
        or LV_SCREEN
        out (P_LV),a
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
;  keyboard (6545 light pen scan) and joystick -> pad, padnew
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

; in the game: the arrow keys or O P (left, right), Q (frill), A (down),
; SPACE (jump); a joystick too
keymap: db K_RIGHT,1, K_LEFT,2, K_UP,4, K_SPACE,16, K_DOWN,8, K_P,1, K_O,2, K_Q,4, K_A,8
        db $FF
keymenu: db K_M,32, K_C,64, K_SPACE,16, K_ESC,128
        db $FF

read_menu:
        ld hl,keymenu
        jr read_keys
read_input:
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
        set PB_FRILL,c
.j1:    bit 1,b
        jr z,.j2
        set PB_DOWN,c
.j2:    bit 2,b
        jr z,.j3
        set PB_LEFT,c
.j3:    bit 3,b
        jr z,.j4
        set PB_RIGHT,c
.j4:    bit 7,b
        jr z,.nj
        set PB_JUMP,c
.nj:    ld a,(pad)
        cpl
        and c
        ld (padnew),a
        ld a,c
        ld (pad),a
        ret

; random byte in A
rnd:    push hl
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
