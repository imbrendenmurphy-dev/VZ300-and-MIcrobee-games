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
BRD_CYC     equ 3                   ; frames per 2-pixel step (the reading speed)
BRD_BANK    equ 9                   ; glyphs 1152.. = bank 9, codes 0..63
BRD_SEGTAB  equ $0010                ; (tools/mkboard.py) NSEG x (dw first glyph, db length)
BRD_DATA    equ $0080
brd_blocks: db 10,11,15,16          ; the messages at shift 0, 2, 4, 6 (tools/mkboard.py)

; after the court picture is loaded (RT block mapped)
board_init:
        ; this match's running order: the messages shuffled (stir the
        ; random seed with the time spent so far first)
        ld hl,(framecount)
        ld de,(seed)
        ld a,r
        xor e
        xor l
        ld e,a
        ld a,d
        xor h
        ld d,a
        ld (seed),de
        ld a,(brd_blocks)
        call map_blk
        ld a,(0)
        ld (brd_n),a
        ld b,a
        ld hl,brd_pl
        xor a
.pl:    ld (hl),a
        inc hl
        inc a
        djnz .pl
        ld a,(brd_n)                ; Fisher-Yates: for i = n-1 .. 1, swap i with rand(i+1)
        dec a
.sh:    ld (brd_i),a
        inc a
        ld b,a
        call rand_n                 ; A < i+1
        ld e,a
        ld d,0
        ld hl,brd_pl
        add hl,de
        ex de,hl                    ; DE -> entry j
        ld a,(brd_i)
        ld l,a
        ld h,0
        ld bc,brd_pl
        add hl,bc                   ; HL -> entry i
        ld a,(de)
        ld c,(hl)
        ld (hl),a
        ld a,c
        ld (de),a
        ld a,(brd_i)
        dec a
        jr nz,.sh
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
        xor a
        ld (brd_i),a
        ld (brd_o),a
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
        ld a,(brd_ph)               ; a BRD_CYC-frame cycle: move + left half,
        inc a                       ; right half, then rest
        cp BRD_CYC
        jr c,.p
        xor a
.p:     ld (brd_ph),a
        cp 2
        ret nc
        ld (brd_half),a
        or a
        jr nz,brd_copy              ; second half: same position
        ld a,(brd_k)                ; first half: 2 pixels on
        add a,2
        cp 8
        jr c,.k
        ld a,(curblk)
        push af
        ld a,(brd_blocks)
        call map_blk
        ld a,(brd_o)                ; a character on
        inc a
        ld e,a
        ld a,(brd_i)
        ld c,a
        call brd_seg                ; B = this segment's length
        ld a,e
        cp b
        jr c,.o
        call brd_next               ; into the next message
        ld a,c
        ld (brd_i),a
        xor a
.o:     ld (brd_o),a
        pop af
        call map_port
        xor a
.k:     ld (brd_k),a
; copy half (brd_half) of the board at (brd_i, brd_o, brd_k) into the PCG
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
        ; where this half starts: C = running-order index, E = character
        ld a,(brd_i)
        ld c,a
        ld a,(brd_o)
        ld e,a
        ld hl,PCGWIN
        ld a,(brd_half)
        or a
        jr z,.h0
        call brd_seg                ; skip W/2 characters (segments are longer)
        ld a,b
        sub e                       ; left in this segment
        cp BRD_W/2+1
        jr c,.h1
        ld a,e
        add a,BRD_W/2
        ld e,a
        jr .h2
.h1:    ld d,a
        ld a,BRD_W/2
        sub d
        ld e,a
        call brd_next
.h2:    ld hl,PCGWIN+BRD_W/2*16
.h0:    ld (brd_dst),hl
        ld a,BRD_W/2
        ld (brd_left),a
        ld a,LV_SCREEN+BRD_BANK
        out (P_LV),a
.run:   call brd_seg                ; HL = first glyph, B = length
        ld a,b
        sub e                       ; glyphs left in the segment
        ld b,a
        ld a,(brd_left)
        cp b
        jr nc,.n
        ld b,a                      ; B = glyphs to copy now
.n:     ld a,(brd_left)
        sub b
        ld (brd_left),a
        ld d,0
        add hl,de                   ; + the character
        REPT 4
        add hl,hl
        ENDR
        ld de,BRD_DATA
        add hl,de
        ld de,(brd_dst)
        push bc
        ld a,b
        ld c,b                      ; BC = B * 16
        ld b,0
        REPT 4
        sla c
        rl b
        ENDR
.cp:    REPT 16
        ldi
        ENDR
        jp pe,.cp
        pop bc
        ld (brd_dst),de
        ld a,(brd_left)
        or a
        jr z,.done
        call brd_next
        ld e,0
        jr .run
.done:
        ld a,LV_SCREEN
        out (P_LV),a
        pop af
        jp map_port

; C = running-order index -> HL = its segment's first glyph, B = its length
; (a board block mapped)
brd_seg:
        push de
        ld e,c
        ld d,0
        ld hl,brd_pl
        add hl,de
        ld a,(hl)                   ; the segment
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,BRD_SEGTAB
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld b,(hl)
        ex de,hl
        pop de
        ret
; C = the next running-order index (round to the start)
brd_next:
        inc c
        ld a,(brd_n)
        cp c
        ret nz
        ld c,0
        ret

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
