; =====================================================================
;  BOARD: the scrolling sponsor board along the back of the court (cell
;  row 3). Its 64 cells show their own glyphs, 1152..1215 (PCG bank 9),
;  rewritten from the pre-shifted messages in RAM blocks 10, 11, 15, 16
;  (tools/mkboard.py): half the board a frame, the text moving 2 pixels
;  every other frame. Sprites over it read the glyphs back from the PCG.
; =====================================================================
BRD_ROW     equ 3
BRD_COL0    equ 11                  ; the end wall: cells 11..52 (tools/venues.py)
BRD_W       equ 42
BRD_BANK    equ 9                   ; glyphs 1152.. = bank 9, codes 0..63
BRD_DATA    equ $0010
brd_blocks: db 10,11,15,16          ; the messages at shift 0, 2, 4, 6 (tools/mkboard.py)

; after the court picture is loaded (RT block mapped)
board_init:
        ld a,(brd_blocks)
        call map_blk
        ld hl,(0)
        ld (brd_n),hl
        ld a,BLK_RT
        call map_blk
        ; colours: amber LEDs on black (the classic court: on blue)
        ld a,(monomode)
        or a
        ld c,BLACK<<4|WHITE
        jr nz,.c
        ld a,(surface)
        cp V_CLASSIC
        ld c,BLUE<<4|YELLOW
        jr z,.c
        ld c,BLACK<<4|YELLOW
.c:     ld hl,BRD_ROW*64+BRD_COL0
        ld b,BRD_W
        ld e,$80
.m:     push hl
        ld a,h
        add a,cur_lo/256
        ld h,a
        ld (hl),e
        pop hl
        push hl
        ld a,h
        add a,cur_hi/256
        ld h,a
        ld (hl),BRD_BANK
        pop hl
        push hl
        ld a,h
        add a,cur_col/256
        ld h,a
        ld (hl),c
        pop hl
        push hl
        ld a,h
        add a,RT_BASELO/256
        ld h,a
        ld (hl),e
        pop hl
        push hl
        ld a,h
        add a,RT_BASEHI/256
        ld h,a
        ld (hl),BRD_BANK
        pop hl
        push hl
        ld a,h
        add a,RT_BASECOL/256
        ld h,a
        ld (hl),c
        pop hl
        inc hl
        inc e
        djnz .m
        ld hl,0
        ld (brd_c),hl
        xor a
        ld (brd_k),a
        ld (brd_half),a
        call brd_copy               ; both halves now
        ld a,1
        ld (brd_half),a
        call brd_copy
        xor a
        ld (brd_half),a
        ld a,1
        ld (brd_on),a
        call fly_init
        jp cloud_init

; once a frame, while a court is shown
board_tick:
        ld a,(brd_on)
        or a
        ret z
        call cloud_tick
        call fly_tick
        ld a,(brd_half)
        xor 1
        ld (brd_half),a
        jr nz,brd_copy              ; second half: same position
        ld a,(brd_k)                ; first half: 2 pixels on
        add a,2
        cp 8
        jr c,.k
        ld hl,(brd_c)
        inc hl
        ld de,(brd_n)
        or a
        sbc hl,de
        add hl,de
        jr c,.n
        ld hl,0
.n:     ld (brd_c),hl
        xor a
.k:     ld (brd_k),a
; copy half (brd_half) of the board at (brd_c, brd_k) into the PCG
brd_copy:
        ld a,(curblk)
        push af
        ld a,(brd_k)                ; one RAM block per shift
        srl a
        ld e,a
        ld d,0
        ld hl,brd_blocks
        add hl,de
        ld a,(hl)
        call map_blk
        ; source = DATA + (c + half * W/2) * 16
        ld hl,(brd_c)
        ld a,(brd_half)
        or a
        jr z,.h0
        ld de,BRD_W/2
        add hl,de
.h0:    REPT 4
        add hl,hl
        ENDR
        ld de,BRD_DATA
        add hl,de
    ; destination: bank 9 at F800, half*512
        ld de,PCGWIN
        ld a,(brd_half)
        or a
        jr z,.d0
        ld de,PCGWIN+BRD_W/2*16
.d0:    ld a,LV_SCREEN+BRD_BANK
        out (P_LV),a
        ld bc,BRD_W/2*16
.cp:    REPT 16
        ldi
        ENDR
        jp pe,.cp
        ld a,LV_SCREEN
        out (P_LV),a
        pop af
        jp map_port

; ---------------------------------------------------------------------
;  CLOUDS: Kooyong's sky (row 0, columns 16..63) drifts left a pixel every
;  16 frames, one glyph row a frame (tools/mkboard.py, CLOUD.BNK).
;  Glyphs 1216..1263 (bank 9, codes 64..111).
BLK_CLOUD   equ 18
CL_COL0     equ 16
CL_N        equ 48
CL_DATA     equ $0010

cloud_init:
        xor a
        ld (cl_on),a
        ld a,(surface)
        or a                        ; V_KOOYONG
        ret nz
        ld a,(monomode)
        or a
        ld c,BCYAN<<4|WHITE
        jr z,.c
        ld c,BLACK<<4|WHITE
.c:     ld a,BLK_RT
        call map_blk
        ld hl,CL_COL0
        ld b,CL_N
        ld e,$80+64
.m:     push hl
        ld a,h
        add a,cur_lo/256
        ld h,a
        ld (hl),e
        add a,cur_hi/256-cur_lo/256
        ld h,a
        ld (hl),BRD_BANK
        add a,cur_col/256-cur_hi/256
        ld h,a
        ld (hl),c
        pop hl
        push hl
        ld a,h
        add a,RT_BASELO/256
        ld h,a
        ld (hl),e
        add a,RT_BASEHI/256-RT_BASELO/256
        ld h,a
        ld (hl),BRD_BANK
        add a,RT_BASECOL/256-RT_BASEHI/256
        ld h,a
        ld (hl),c
        pop hl
        inc hl
        inc e
        djnz .m
        ld hl,0
        ld (cl_p),hl
        xor a
        ld (cl_r),a
        ld a,1
        ld (cl_on),a
        ld b,16
.r:     push bc
        call cl_row
        ld hl,cl_r
        inc (hl)
        pop bc
        djnz .r
        xor a
        ld (cl_r),a
        ret

cloud_tick:
        ld a,(cl_on)
        or a
        ret z
        call cl_row
        ld a,(cl_r)
        inc a
        and 15
        ld (cl_r),a
        ret nz
        ld hl,(cl_p)                ; a pixel on, round the loop
        inc hl
        ld de,-384
        add hl,de
        jr c,.w
        sbc hl,de
.w:     ld (cl_p),hl
        ret

; write glyph row (cl_r) of the sky at position (cl_p)
cl_row:
        ld a,(curblk)
        push af
        ld a,BLK_CLOUD
        call map_blk
        ; mono: the sky's dots for this row
        ld a,(cl_r)
        ld l,a
        ld h,0
        ld c,0
        ld a,(monomode)
        or a
        jr z,.nm
        ld c,(hl)
.nm:    ; source: DATA + ((p & 7) * 16 + r) * 96 + (p >> 3)
        ld a,(cl_p)
        and 7
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld a,(cl_r)
        add a,l
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                   ; x 32
        ld d,h
        ld e,l
        add hl,hl
        add hl,de                   ; x 96
        ld de,CL_DATA
        add hl,de
        push hl
        ld hl,(cl_p)
        srl h
        rr l
        srl l
        srl l
        ex de,hl
        pop hl
        add hl,de
        ; destination: bank 9 glyph 64 + j, row r
        ld a,(cl_r)
        ld e,a
        ld d,(PCGWIN+64*16)/256
        ld a,LV_SCREEN+BRD_BANK
        out (P_LV),a
        ld b,CL_N
.j:     ld a,(hl)
        or c
        ld (de),a
        inc hl
        ld a,e
        add a,16
        ld e,a
        jr nc,.n
        inc d
.n:     djnz .j
        ld a,LV_SCREEN
        out (P_LV),a
        pop af
        jp map_port

; ---------------------------------------------------------------------
;  SKY VISITORS: now and then a gull crosses Kooyong's or Sydney's sky, or
;  a plane blinks across the night over Melbourne Park; right to left,
;  disappearing behind the scoreboard. (none at Perth or on the classic court)
fly_init:
        xor a
        ld (fly_on),a
        ld hl,300
        ld (fly_wait),hl
        ; no sprites over the scoreboard (rows 0-2, columns 0-15)
        ld hl,cellmap
        ld c,3
.r:     ld b,16
.c:     ld (hl),$FF
        inc hl
        djnz .c
        ld de,48
        add hl,de
        dec c
        jr nz,.r
        ret

fly_tick:
        ld a,(surface)
        cp V_PERTH
        ret z
        cp V_CLASSIC
        ret z
        ld a,(fly_on)
        or a
        jr nz,.fly
        ld hl,(fly_wait)
        dec hl
        ld (fly_wait),hl
        ld a,h
        or l
        ret nz
        ; take off: from just off the right edge, at a random height
        ld hl,524
        ld (fly_x),hl
        ld b,6
        call rand_n
        add a,5
        ld (fly_y),a
        ld a,1
        ld (fly_on),a
        ret
.fly:   ld hl,(fly_x)
        dec hl
        ld (fly_x),hl
        ld de,112
        or a
        sbc hl,de
        jr nc,.draw
        ; gone: wait 25 to 60 seconds for the next
        xor a
        ld (fly_on),a
        ld b,200
        call rand_n
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,600
        add hl,de
        ld (fly_wait),hl
        ret
.draw:  ld hl,(fly_x)
        ld (spr_x),hl
        ld a,(fly_y)
        ld l,a
        ld h,0
        ld (spr_y),hl
        call ink_white
        ld a,(surface)
        cp V_SYDNEY
        jr nz,.wh
        ld a,(monomode)
        or a
        jr nz,.wh
        ld a,DGREY                  ; a dark gull: the bridge keeps its colour
        ld (spr_ink),a
.wh:    ld a,(surface)
        cp V_MELBOURNE
        jr z,.plane
        ld a,(framecount)
        and 8
        ld a,SF_GULL0
        jr z,.g
        inc a
.g:     jp spr_draw
.plane: ld a,(framecount)
        and 16
        ld a,SF_PLANE0
        jr z,.g
        inc a
        jp spr_draw
