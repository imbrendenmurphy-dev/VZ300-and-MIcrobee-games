; =====================================================================
;  ENGINE (8000h up, always in view): hardware, blocks, the stage's data,
;  text screens, the sprite compositor, the frame. The scroll itself and
;  the work done in the blanking are in the map block (map.asm).
;
;  THE SPRITES. As FRILLSEEKER: for each cell a sprite touches, a private
;  glyph is composed in RAM (the background quad's own picture at the
;  present phase, from SLOTPAT, with the sprite masked over it) in one of
;  two pools of the PCG that take turns, and the cell is pointed at it.
; =====================================================================
; BPM's MODES40 table: 40 x 25 cells of 8 x 10, 31 rows + 2 = 312 lines
crtc_game:  db $35,$28,$2C,$34,$1E,$02,$19,$1C,$48,$09,$20,$09,0,0,0,0
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
        ld a,YELLOW
        ld (hud_col),a
        ; the tables: n x 10, n / 10 and n mod 10, row x 40
        ld hl,0
        ld de,MUL10
        ld b,128
.m:     ld a,l
        ld (de),a
        set 7,e
        ld a,h
        ld (de),a
        res 7,e
        inc e
        ld a,l
        add a,10
        ld l,a
        jr nc,.m1
        inc h
.m1:    djnz .m
        ld hl,DIV10
        ld bc,0                 ; B = quotient, C = remainder
.d:     ld (hl),b
        inc h
        ld (hl),c
        dec h
        inc c
        ld a,c
        cp 10
        jr c,.d1
        ld c,0
        inc b
.d1:    inc l
        jr nz,.d
        ld hl,0
        ld de,ROW40
        ld b,DROWS
.r:     ld a,l
        ld (de),a
        inc e
        ld a,h
        ld (de),a
        inc e
        push de
        ld de,COLS
        add hl,de
        pop de
        djnz .r
        ; the font and the status line's glyphs
        ld a,BLK_MAP
        call map_blk
        ld hl,M_FONT
        ld a,BK_FONT
        ld b,64
        call pcg_load10
        ld hl,M_HUDG
        ld a,BK_HUD
        ld b,16
        jp pcg_load10

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
map_map:
        ld a,BLK_MAP
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

; HL = glyphs (10 bytes each), A = PCG bank, B = how many: codes 80h up
pcg_load10:
        or LV_SCREEN
        out (P_LV),a
        xor a
        out (P_COLCTL),a
        ld de,PCGWIN
.g:     push bc
        ld bc,10
        ldir
        ex de,hl
        ld bc,6
        add hl,bc
        ex de,hl
        pop bc
        djnz .g
        ld a,LV_SCREEN
        out (P_LV),a
        ret

; ---------------------------------------------------------------------
;  the cell-glyph map (block BLK_CGM: 32 a column). These are called from
;  the map block, which is mapped again before they return.
; ---------------------------------------------------------------------
; CGBUF = column (m_x), then column (m_x) + 1 (33 each: the last empty)
cg_col: ld a,BLK_CGM
        call map_blk
        ld hl,(m_x)
        call cg_addr0
        ld de,CGBUF
        ld bc,CGROWS2
        ldir
        xor a
        ld (de),a
        inc de
        ld bc,CGROWS2
        ldir
        xor a
        ld (de),a
        jp map_map
CGROWS2 EQU 32

; CGBUF = row (m_r), 41 columns from camcell, then row (m_r) + 1 (at +41)
cg_row: ld a,BLK_CGM
        call map_blk
        ld hl,(camcell)
        call cg_addr0
        ld a,(m_r)
        ld e,a
        ld d,0
        add hl,de
        ld de,CGBUF
        ld b,41
.l:     ld a,(hl)
        ld (de),a
        ld a,(m_r)
        cp CGROWS2-1
        ld a,0
        jr nc,.z
        inc hl
        ld a,(hl)
        dec hl
.z:     push hl
        ld hl,41
        add hl,de
        ld (hl),a
        pop hl
        inc de
        ld a,l
        add a,CGROWS2
        ld l,a
        jr nc,.n
        inc h
.n:     djnz .l
        jp map_map

; HL = column -> HL = its address in BLK_CGM (the map is mapped)
cg_addr0:
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ret

; A = cell glyph for (m_x, m_r)
cg_put: push af
        ld a,BLK_CGM
        call map_blk
        call cg_here
        pop af
        ld (hl),a
        jp map_map

; (m_x, m_r) -> B, C, D, E = the quad's four cell glyphs
cg_quad:
        ld a,BLK_CGM
        call map_blk
        call cg_here
        ld b,(hl)
        inc hl
        ld a,(m_r)
        cp CGROWS2-1
        ld d,0
        jr nc,.d
        ld d,(hl)
.d:     ld a,(m_r)
        ld e,a
        ld a,l
        add a,CGROWS2-1
        ld l,a
        jr nc,.n
        inc h
.n:     ld c,(hl)
        inc hl
        ld a,e
        cp CGROWS2-1
        ld e,0
        jr nc,.e
        ld e,(hl)
.e:     jp map_map

cg_here:
        ld hl,(m_x)
        call cg_addr0
        ld a,(m_r)
        ld e,a
        ld d,0
        add hl,de
        ret

; ---------------------------------------------------------------------
;  the quad blocks: record n is at block QDB_B0/1/2 (n / 240), (n mod 240) x 136
; ---------------------------------------------------------------------
; HL = record number -> its block mapped, HL = its address
qdb_addr:
        ld a,QDB_B0
        ld de,QPERBLK
.b:     or a
        sbc hl,de
        jr c,.f
        cp QDB_B0
        ld a,QDB_B1
        jr z,.b
        ld a,QDB_B2
        jr .b
.f:     add hl,de
        call map_blk
        ld d,h                  ; x 136 = x 128 + x 8
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl               ; x 8
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; x 128
        add hl,de
        ret

; HL = record number: REC -> its record (called from the map block)
qdb_put:
        call qdb_addr
        ex de,hl
        ld hl,REC
        ld bc,QREC
        ldir
        jp map_map

; HL = record number, C = slot: its 12 pictures -> SLOTPAT (each phase's at
; phase x 1280 + slot x 10), its inks and flags -> qd_tmp
qdb_load:
        push bc
        call qdb_addr
        pop bc
        push hl
        ld l,c                  ; DE = SLOTPAT + slot x 10
        ld h,MUL10 >> 8
        ld e,(hl)
        set 7,l
        ld d,(hl)
        ld hl,SLOTPAT
        add hl,de
        ex de,hl
        pop hl
        ld a,NPH
.p:     ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ex de,hl                ; on 1280 - 10
        ld bc,1280-10
        add hl,bc
        ex de,hl
        dec a
        jr nz,.p
        ld de,qd_tmp
        ld bc,13
        ldir
        jp map_map

; ---------------------------------------------------------------------
;  e_stage: A = stage (0..). Its data from its block: the cell glyphs and
;  the quad table to the map block, the cell map to BLK_CGM, the tile map,
;  spawn list and header to the game block. The display is left off.
; ---------------------------------------------------------------------
e_stage:
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de               ; x 3
        ld de,stg_tab
        add hl,de
        ld a,(hl)
        ld (stg_blk),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (stg_ofs),de
        call display_off
        ; the header
        ld hl,0
        ld bc,40
        call stg_fetch
        ld hl,SLOTPAT
        ld de,stg_hdr
        ld bc,40
        ldir
        ; the cell glyphs
        ld hl,(stg_hdr+12)
        ld a,(stg_hdr+8)
        ld c,a
        ld b,0
        push bc
        ld h,b
        ld l,c
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld b,h
        ld c,l
        ld hl,(stg_hdr+12)
        call stg_fetch
        call map_map
        pop bc
        ld b,c
        ld hl,SLOTPAT
        call M_CGSCATTER
        ; the tile cells
        ld hl,(stg_hdr+14)
        ld bc,256
        call stg_fetch
        call map_map
        ld hl,SLOTPAT
        ld de,M_TCELL
        ld bc,256
        ldir
        ld hl,stg_hdr+32
        ld de,M_LOGCG
        ld bc,6
        ldir
        call M_TABINIT
        ; the mixed inks
        ld a,(stg_hdr+11)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; x 12
        ld a,h
        or l
        jr z,.nm0
        ld b,h
        ld c,l
        push bc
        ld hl,(stg_hdr+18)
        call stg_fetch
        call map_map
        pop bc
        ld hl,SLOTPAT
        ld de,M_MIXINK
        ldir
.nm0:   ; the quads: into the table, then each one's record
        ld hl,(stg_hdr+9)       ; n x 6 bytes
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld b,h
        ld c,l
        ld hl,(stg_hdr+16)
        call stg_fetch
        call map_map
        ld hl,0
        ld (q_id),hl
        ld de,M_QINSERT
        call qloop
        ld hl,0
        ld (q_id),hl
        ld de,M_QBUILD
        call qloop
        ; the cell map, unpacked into BLK_CGM
        ld hl,(stg_hdr+22)
        ld de,(stg_hdr+20)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld (rl_left),bc
        ex de,hl
        call stg_fetch
        ld a,BLK_CGM
        call map_blk
        call unrle
        ; the tile map
        ld hl,(stg_hdr+24)
        ld de,(stg_hdr+22)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        push bc
        ex de,hl
        call stg_fetch
        call map_game
        pop bc
        ld hl,SLOTPAT
        ld de,MAP
        ldir
        ; the spawn list and the header
        ld hl,(stg_hdr+24)
        ld bc,$200
        call stg_fetch
        call map_game
        ld hl,SLOTPAT
        ld de,ENTLIST
        ld bc,$200
        ldir
        ld hl,stg_hdr
        ld de,LVHDR
        ld bc,32
        ldir
        call map_map
        call M_PCGCLEAR
        jp map_game
stg_hdr: ds 40

; DE = M_QINSERT or M_QBUILD: over the stage's quads (in SLOTPAT), 200 at a time
qloop:  ld (.call+1),de
        ld hl,(stg_hdr+9)
        ld ix,SLOTPAT
.q:     ld a,h
        or l
        ret z
        ld de,200
        or a
        sbc hl,de
        jr nc,.q200
        add hl,de
        ld b,l
        ld hl,0
        jr .qb
.q200:  ld b,200
.qb:    push hl
        push ix
        pop hl
        push bc
.call:  call 0
        pop bc
        ld c,b                  ; IX += 6 x B
        ld b,0
        ld h,b
        ld l,c
        add hl,hl
        add hl,bc
        add hl,hl
        ex de,hl
        add ix,de
        pop hl
        jr .q

; HL = offset in the stage's data, BC = bytes: copy them to SLOTPAT
stg_fetch:
        ld a,(stg_blk)
        call map_blk
        ld de,(stg_ofs)
        add hl,de
        ld de,SLOTPAT
        ldir
        ret

; the cell map, from SLOTPAT ((rl_left) bytes) to 0000h of the mapped block:
; 0xxxxxxx x+1 bytes follow; 10xxxxxx the next byte x+2 times; 11xxxxxx
; x+2 bytes from 32 back
unrle:  ld hl,SLOTPAT
        ld de,0
        ld bc,(rl_left)
        add hl,bc
        ld (rl_src),hl          ; the end
        ld hl,SLOTPAT
.t:     push hl
        ld bc,(rl_src)
        or a
        sbc hl,bc
        pop hl
        ret nc
        ld a,(hl)
        inc hl
        cp $80
        jr nc,.rep
        inc a                   ; literal
        ld c,a
        ld b,0
        ldir
        jr .t
.rep:   cp $C0
        jr nc,.cpy
        and $3F
        add a,2
        ld b,a
        ld a,(hl)
        inc hl
.r1:    ld (de),a
        inc de
        djnz .r1
        jr .t
.cpy:   and $3F
        add a,2
        ld c,a
        ld b,0
        push hl
        ld h,d
        ld l,e
        push bc
        ld bc,32
        or a
        sbc hl,bc
        pop bc
        ldir
        pop hl
        jr .t

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
        ld a,12
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        ld a,13
        out (P_CRTCA),a
        xor a
        out (P_CRTCD),a
        jp display_on

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

; e_snap: the whole picture at the camera (the display goes off while it
; is drawn), the sprites forgotten
e_snap: call display_off
        ld hl,CELLMAP
        ld de,CELLMAP+1
        ld bc,1023
        ld (hl),0
        ldir
        xor a
        ld (nslots),a
        ld (nold),a
        ld (sdirty),a
        call map_map
        call M_SNAP
        call display_on
        jp map_game

list_reset:
        ld hl,FLIPL
        ld (entptr),hl
        ld hl,CFLIPL
        ld (centptr),hl
        ld hl,0
        ld (nflip),hl
        xor a
        ld (ncflip),a
        ret

; ---------------------------------------------------------------------
;  e_frame: one frame. The game has moved things, set camx / camy, queued
;  its sprites (DRAWQ) and its map requests (MAPQ).
; ---------------------------------------------------------------------
e_frame:
        call frame_begin
        call list_reset
        call vpoll
        call map_map
        call M_SCROLL
        call M_QUEUE
        ld a,(phase)
        ld hl,oldphase
        cp (hl)
        call nz,M_MIXED
        call vpoll
        ; the line of the level at the top of the screen, for the sprites:
        ; camrow x 10 + the vertical step's lines - 10 (the status line)
        ld a,(camrow)
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld a,(phase)
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        push hl
        ld hl,voffs
        add hl,de
        ld e,(hl)
        pop hl
        add hl,de
        ld de,-10
        add hl,de
        ld (dispy),hl
        ld hl,POOLBUF+10        ; the pool buffers, from slot 1
        ld (gb_dst),hl
        ld a,(phase)            ; the backgrounds' pictures at this phase
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,SLOTPAT >> 8
        ld (gb_ph),a
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
.nospr: call map_map
        call M_RESTORES
        call M_PRESENT
        jp map_game

; e_present: the frame computed by e_frame to the screen, in the blankings
e_present:
        call map_map
        call M_SHOW
        jp map_game
voffs:  db 0,3,7,0
dispy:  dw 0

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
.c:     ld e,(hl)               ; the CELLMAP index
        inc hl
        ld d,(hl)
        inc hl
        inc hl
        inc hl
        ex de,hl
        push de
        ld de,CELLMAP
        add hl,de
        ld (hl),0
        pop de
        ex de,hl
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
; top left at screen pixel sd_x and level line sd_y, ink (ds_col)
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
        and 6
        ld (ds_sh),a            ; shift x 2 (0, 2, 4, 6)
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
        ld hl,(sd_y)            ; level line -> screen line, + 60 (so a sprite
        ld de,(dispy)           ; can hang off the top): t = 0..309
        or a
        sbc hl,de
        ld de,60
        add hl,de
        bit 7,h
        jr nz,.off
        ld b,0
        ld a,h
        or a
        jr nz,.t256
        ld a,l
        cp 200
        jr c,.div
        sub 200
        ld l,a
        ld b,20
        jr .div
.t256:  dec a
        jr nz,.off
        ld a,l
        cp 54
        jr nc,.off
        add a,56                ; t - 200
        ld l,a
        ld b,20
.div:   ld h,DIV10 >> 8
        ld a,(hl)
        add a,b
        sub 6
        ld (ds_cy),a
        inc h
        ld a,(hl)
        ld (ds_ry),a
        pop hl
        ld a,(hl)               ; the frame's four variants: a table in its block
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(ds_sh)
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
        push hl
        ld l,a
        ld h,DIV10 >> 8
        ld b,(hl)               ; rows down
        inc h
        ld e,(hl)               ; line in the cell
        pop hl
        ld a,(ds_cy)
        add a,b
        ld (ds_cyc),a
.seg:   ld a,10
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
        inc de
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
        push hl
        call vpoll
        pop hl
        ld a,(ds_cx)
        inc a
        ld (ds_cx),a
        ld a,(ds_n)
        dec a
        ld (ds_n),a
        jr nz,.col
        ret

; A = screen row (1..24), E = line in the cell -> DE = the cell's glyph
; buffer + line. A cell not yet in this frame gets the next pool slot: its
; buffer starts as the background quad's picture at the present phase,
; and its flip-list entry is written here.
getbuf:
        ld (gb_row),a
        add a,a
        ld l,a
        ld h,ROW40 >> 8
        ld a,l
        add a,ROW40 & 255
        ld l,a
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld a,(ds_cx)
        add a,l
        ld l,a
        jr nc,.g1
        inc h
.g1:    ld (gb_idx),hl
        ld a,h
        add a,CELLMAP >> 8
        ld h,a
        ld a,(hl)
        or a
        jr z,.alloc
        ld l,a                  ; POOLBUF + slot x 10 + line
        ld h,MUL10 >> 8
        ld a,l
        add a,MUL10 & 255
        ld l,a
        ld a,(hl)
        set 7,l
        ld h,(hl)
        ld l,a
        ld d,POOLBUF >> 8
        ld a,e
        add a,l
        ld e,a
        ld a,d
        adc a,h
        ld d,a
        ret
.alloc: ld a,(nslots)
        cp MAXSLOT
        jp nc,.full
        inc a
        ld (nslots),a
        ld (hl),a
        ld c,a                  ; slot
        push de                 ; the line
        ; the ring address
        ld a,(gb_row)
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
        jr nc,.g2
        inc h
.g2:    ld a,h
        and 7
        ld h,a
        ld (gb_ring),hl
        ; the list: CELLMAP index, ring
        ld hl,(listptr)
        ld de,(gb_idx)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(gb_ring)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (listptr),hl
        ; the flip: ring, code, pool bank, ink
        ld hl,(entptr)
        ld (hl),e
        inc hl
        ld a,d
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
        ld hl,nflip
        inc (hl)
        ; the background's picture: SLOTPAT + phase x 1280 + its slot x 10,
        ; to the next pool buffer (gb_dst)
        ld hl,(gb_ring)
        ld a,h
        or SCRSH >> 8
        ld h,a
        ld a,(hl)
        and $7F
        ld l,a
        ld h,MUL10 >> 8
        ld e,(hl)
        set 7,l
        ld a,(gb_ph)
        add a,(hl)
        ld h,a
        ld l,e
        ld de,(gb_dst)
        push de
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ld (gb_dst),de
        pop de
        pop hl                  ; L = the line
        ld a,l
        add a,e
        ld e,a
        ret nc
        inc d
        ret
.full:  ld a,e
        add a,scratch & 255
        ld e,a
        ld d,scratch >> 8
        ret
gb_row: db 0
gb_dst: dw 0
gb_ph:  db 0
gb_idx: dw 0
gb_ring: dw 0

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
        ld hl,POOLBUF+10
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
        ldi
        ldi
        ld a,e
        add a,6
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
