; ---------------------------------------------------------------------------
; The third overlay (BLACKOUT.OV3, block 29): the two terminal mini-games.
;
; SPLICE TERMINAL - each wing's override key is a 4 x 4 punch card cut into three
;   connected fragments: the wing's shards, found turned and flipped.  Pick a shard
;   (1-3), turn it (R) and flip it (F) until the three overlaid fill every hole of
;   the card exactly once.  H asks MERIDIAN's own diagnostics to straighten one
;   shard, for ten minutes of the clock.
; TONE LOCK - one security terminal in each wing is locked by a tone sequence:
;   MERIDIAN plays it on six pads, you repeat it on keys 1-6, three rounds of four,
;   five and six tones.  It opens for a SLEEP and a RESET code.
; ---------------------------------------------------------------------------
        jp card_open
        jp tone_open

KEY_F    equ 6
KEY_H    equ 8
INK_DIM  equ $08
CP_ROW   equ 5                  ; shard grids: rows 5-8, columns 4 + 10 * i
CARD_ROW equ 12                 ; the card: rows 12-15, columns 17-24
CARD_COL equ 17

; ---------------------------------------------------------- splice terminal
card_open:
        ld a,(sp_key)           ; this wing's shards: cards + wing * 9
        ld l,a
        add a,a
        add a,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        ld de,cards
        add hl,de
        ld (cp_src),hl
        ld de,cp_cur            ; scramble them: each solved shard through its turn/flip
        ld b,3
.sc:    push bc
        push de
        ld hl,(cp_src)
        ld a,3
        sub b
        ld c,a
        add a,a
        ld e,a
        ld d,0
        add hl,de               ; its solved pattern
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(cp_src)
        ld a,6
        add a,c
        ld b,0
        ld c,a
        add hl,bc
        ld a,(hl)               ; its scramble
        ex de,hl
        call xform
        pop de
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ex de,hl
        pop bc
        djnz .sc
        xor a
        ld (cp_sel),a
        ld (cp_last),a
        call page_begin
        ld hl,card_page
        call page_run
        ld a,9                  ; "KEY n"
        ld (pr_col),a
        ld a,$0D
        ld (pr_ink),a
        ld c,3
        ld a,(sp_key)
        inc a
        call put_digit
        call cp_drawall
        call page_show
.loop:  call present
        call cp_key             ; A = the key just pressed (0 = none)
        or a
        jr z,.loop
        cp KEY_X
        jp z,resume_room
        cp KEY_R
        jr z,.turn
        cp KEY_F
        jr z,.flip
        cp KEY_H
        jr z,.help
        sub KEY_1               ; 1-3: pick a shard
        cp 3
        jr nc,.loop
        ld (cp_sel),a
        call sfx_blip
        call cp_drawall
        jr .loop
.turn:  ld a,2                  ; one quarter turn
        jr .xf
.flip:  ld a,1
.xf:    push af
        call cp_ptr
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop af
        call xform
        ex de,hl
        call cp_ptr
        ld (hl),e
        inc hl
        ld (hl),d
        call sfx_blip
        call cp_drawall
        call cp_solved
        jr nz,.loop
        jp cp_done
.help:  ld b,0                  ; the first shard that isn't its solved self
.h:     push bc
        ld a,b
        ld (cp_sel),a
        call cp_ptr
        ex de,hl                ; DE -> current
        ld hl,(cp_src)
        ld a,b
        add a,a
        add a,l
        ld l,a
        jr nc,$+3
        inc h                   ; HL -> solved
        ld a,(de)
        cp (hl)
        jr nz,.fix
        inc de
        inc hl
        ld a,(de)
        cp (hl)
        dec hl
        dec de
        jr nz,.fix
        pop bc
        inc b
        ld a,b
        cp 3
        jr nz,.h
        jr .loop
.fix:   pop bc
        ldi                     ; straighten it
        ldi
        ld a,10                 ; for ten minutes of the clock
        call clock_minus
        ld hl,str_help
        ld a,5
        ld c,17
        ld e,$0B
        call print_at
        call sfx_found
        call cp_drawall
        call cp_solved
        jp nz,.loop
cp_done:
        ld a,(sp_key)           ; key online
        ld b,a
        ld a,1
        inc b
.bit:   dec b
        jr z,.set
        add a,a
        jr .bit
.set:   ld hl,keys_done
        or (hl)
        ld (hl),a
        ld hl,str_cp_done
        ld a,15
        ld c,17
        ld e,$A0
        call print_at
        call present
        call present
        ld hl,mus_keyok
        xor a
        call mus_play
        ld a,SPK_KEYOK
        call say
        call autosave           ; a key online: the autosave slot
        ld b,25
.w:     push bc
        call present
        pop bc
        djnz .w
        jp resume_room

; HL -> cp_cur[cp_sel]
cp_ptr: ld a,(cp_sel)
        add a,a
        ld hl,cp_cur
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; Z if the three tile the card: every hole covered exactly once.
cp_solved:
        ld hl,(cp_cur)
        ld de,(cp_cur+2)
        ld bc,(cp_cur+4)
        ld a,l                  ; no overlaps: (a&b)|(a&c)|(b&c) = 0, low then high
        and e
        ret nz
        ld a,l
        and c
        ret nz
        ld a,e
        and c
        ret nz
        ld a,h
        and d
        ret nz
        ld a,h
        and b
        ret nz
        ld a,d
        and b
        ret nz
        ld a,l                  ; and no gaps: a|b|c = FFFF
        or e
        or c
        inc a
        ret nz
        ld a,h
        or d
        or b
        inc a
        ret

; HL = a 16-hole pattern, A = orientation (bit 0 flip, bits 1-2 quarter turns)
; -> HL turned (bit r*4+c = hole r, c; a turn takes r, c to c, 3-r).
xform:  push af
        rra
        jr nc,.nf
        ld ix,flip_tab
        call remap
.nf:    pop af
        rra
        and 3
        ret z
        ld b,a
.r:     push bc
        ld ix,rot_tab
        call remap
        pop bc
        djnz .r
        ret
remap:  ld de,0                 ; hole i -> hole (ix+i)
        ld b,16
.b:     srl h
        rr l
        jr nc,.n
        ld a,(ix+0)
        push hl
        ld hl,1
        or a
        jr z,.s
.m:     add hl,hl
        dec a
        jr nz,.m
.s:     ld a,e
        or l
        ld e,a
        ld a,d
        or h
        ld d,a
        pop hl
.n:     inc ix
        djnz .b
        ex de,hl
        ret
flip_tab: db 3,2,1,0, 7,6,5,4, 11,10,9,8, 15,14,13,12
rot_tab:  db 3,7,11,15, 2,6,10,14, 1,5,9,13, 0,4,8,12

; The three shards and the card.
cp_drawall:
        ld b,0
.s:     push bc
        ld a,b
        add a,a
        ld hl,cp_cur
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,b                  ; ink: the shard's colour, bright when picked
        ld hl,cp_ink
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld c,(hl)
        ld a,(cp_sel)
        cp b
        jr z,.br
        res 3,c
.br:    ld a,b                  ; column 4 + 10 * i
        add a,a
        ld l,a
        add a,a
        add a,a
        add a,l
        add a,4
        ld (g_col),a
        ld a,CP_ROW
        ld (g_row),a
        ld a,c
        ld (g_ink),a
        ex de,hl
        call grid_draw
        pop bc                  ; the picked one gets a marker
        push bc
        ld a,(cp_sel)
        cp b
        ld d,T_EMPTY
        jr nz,.nm
        ld d,T_BUL
.nm:    ld a,(g_col)
        add a,3
        ld c,CP_ROW+4
        ld e,$0B
        call redraw_cell
        pop bc
        inc b
        ld a,b
        cp 3
        jr nz,.s
        ld c,0                  ; the card: hole by hole, who covers it
.h:     push bc
        ld b,0                  ; count
        ld e,INK_DIM            ; ink of the last cover
        ld hl,cp_cur
        ld d,3
.o:     push de
        push hl
        ld e,(hl)
        inc hl
        ld h,(hl)
        ld l,e
        ld a,c                  ; bit c of this shard
        or a
        jr z,.t
.sh:    srl h
        rr l
        dec a
        jr nz,.sh
.t:     bit 0,l
        pop hl
        pop de
        jr z,.no
        inc b
        ld a,3                  ; its colour
        sub d
        push hl
        ld hl,cp_ink
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        pop hl
.no:    inc hl
        inc hl
        dec d
        jr nz,.o
        ld a,b                  ; 0 empty, 1 its shard's colour, 2+ a clash
        ld d,T_SLOT_OFF
        or a
        jr z,.dr
        ld d,T_SLOT_ON
        dec a
        jr z,.dr
        ld d,T_HAZARD
        ld e,$09
.dr:    pop bc
        push bc
        ld a,c                  ; row 12 + c / 4, column 17 + (c & 3) * 2
        rrca
        rrca
        and 3
        add a,CARD_ROW
        ld b,a
        ld a,c
        and 3
        add a,a
        add a,CARD_COL
        ld c,b
        call cell2
        pop bc
        inc c
        ld a,c
        cp 16
        jp nz,.h
        ret

; Pattern HL at (g_row, g_col), holes in g_ink, two cells wide each.
grid_draw:
        ld c,0
.h:     push bc
        push hl
        ld a,c
        or a
        jr z,.t
.sh:    srl h
        rr l
        dec a
        jr nz,.sh
.t:     ld d,T_SLOT_OFF
        ld e,INK_DIM
        bit 0,l
        jr z,.e
        ld d,T_SLOT_ON
        ld a,(g_ink)
        ld e,a
.e:     ld a,c
        rrca
        rrca
        and 3
        ld hl,g_row
        add a,(hl)
        ld b,a
        ld a,c
        and 3
        add a,a
        ld hl,g_col
        add a,(hl)
        ld c,b
        call cell2
        pop hl
        pop bc
        inc c
        ld a,c
        cp 16
        jr nz,.h
        ret

; A = the key pressed since last time (0 = none): 1-6, R, F, H, X.
cp_key: ld hl,cp_keys
.k:     ld a,(hl)
        or a
        jr z,.none
        push hl
        call scan_key
        pop hl
        jr nz,.dn
        inc hl
        jr .k
.dn:    ld a,(cp_last)          ; held since last time?
        cp (hl)
        ld a,0
        ret z
        ld a,(hl)
        ld (cp_last),a
        ret
.none:  xor a
        ld (cp_last),a
        ret
cp_keys: db KEY_1,KEY_1+1,KEY_1+2,KEY_1+3,KEY_1+4,KEY_1+5,KEY_R,KEY_F,KEY_H,KEY_X,0

; A minutes off the clock (H in the splice terminal).
clock_minus:
        ld b,a
        ld a,(clk_m)
        sub b
        jr nc,.m
        add a,60
        ld hl,clk_h
        dec (hl)
        jp m,game_over
.m:     ld (clk_m),a
        ret

; ---------------------------------------------------------------- tone lock
tone_open:
        ld a,(frames)           ; a fresh sequence of six
        ld b,a
        ld a,r
        xor b
        ld hl,tl_seq
        ld b,6
.g:     ld c,a
        and 7
        cp 6
        jr c,.ok
        sub 3
.ok:    ld (hl),a
        inc hl
        ld a,c
        rrca
        rrca
        add a,$1B               ; (and a few more bits)
        xor b
        djnz .g
        ld a,4                  ; round one: four tones
        ld (tl_len),a
        xor a
        ld (cp_last),a
        call page_begin
        ld hl,tone_page
        call page_run
        call tl_pads
        call page_show
.round: ld b,25
.p0:    push bc
        call present
        pop bc
        djnz .p0
        call tl_play            ; MERIDIAN plays it
        ld hl,tl_seq
        ld (tl_pos),hl
        ld a,(tl_len)
        ld (tl_left),a
.in:    call present
        call cp_key
        or a
        jr z,.in
        cp KEY_X
        jp z,resume_room
        sub KEY_1
        cp 6
        jr nc,.in
        push af                 ; light it, sound it
        call tl_light
        pop af
        ld hl,(tl_pos)
        cp (hl)
        jr nz,.wrong
        inc hl
        ld (tl_pos),hl
        ld hl,tl_left
        dec (hl)
        jr nz,.in
        ld a,(tl_len)           ; the round is done
        inc a
        ld (tl_len),a
        cp 7
        jr c,.round
        ld a,(cur_room)         ; open: this wing's lock is done
        ld hl,room_wing
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld b,(hl)
        inc b
        ld a,1
.wb:    dec b
        jr z,.ws
        rlca
        jr .wb
.ws:    ld hl,tones_done
        or (hl)
        ld (hl),a
        ld hl,n_sleep
        inc (hl)
        ld hl,n_reset
        inc (hl)
        ld hl,str_tl_open
        ld a,7
        ld c,17
        ld e,$0A
        call print_at
        call present
        call present
        call sfx_found
        ld b,75
.w:     push bc
        call present
        pop bc
        djnz .w
        jp resume_room
.wrong: call sfx_deny
        ld hl,str_tl_again
        ld a,7
        ld c,17
        ld e,$09
        call print_at
        jp .round

; MERIDIAN plays tl_len tones.
tl_play:
        ld hl,str_tl_listen
        ld a,7
        ld c,17
        ld e,$0F
        call print_at
        ld hl,tl_seq
        ld a,(tl_len)
        ld b,a
.t:     push bc
        push hl
        ld a,(hl)
        call tl_light
        ld b,10
.g:     push bc
        call present
        pop bc
        djnz .g
        pop hl
        inc hl
        pop bc
        djnz .t
        ld hl,str_tl_you
        ld a,7
        ld c,17
        ld e,$0B
        jp print_at

; Pad A lights and sounds, then goes dark.
tl_light:
        ld (tl_pad),a
        ld d,T_SLOT_ON
        call tl_pad_draw
        call present
        call present
        ld a,(tl_pad)           ; its tone
        ld hl,tl_pitch
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld c,(hl)
        ld a,(tl_pad)
        ld hl,tl_cycles
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld b,(hl)
        ld a,8
.bp:    push af
        push bc
        call beep
        pop bc
        pop af
        dec a
        jr nz,.bp
        ld a,(tl_pad)
        ld d,T_SLOT_OFF
        call tl_pad_draw
        jp present
tl_pads:
        ld b,6
.p:     push bc
        ld a,6
        sub b
        ld (tl_pad),a
        ld d,T_SLOT_OFF
        call tl_pad_draw
        pop bc
        djnz .p
        ret
; Pad tl_pad (0-5) in tile D: a 4 x 2 block at row 8, column 6 + 5 * pad.
tl_pad_draw:
        ld a,(tl_pad)
        ld hl,tl_ink
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)
        ld a,(tl_pad)
        ld c,a
        add a,a
        add a,a
        add a,c
        add a,6
        ld (g_col),a
        ld c,8
.r:     ld a,(g_col)
        call cell2
        add a,2
        call cell2
        inc c
        ld a,c
        cp 10
        jr nz,.r
        ret

; Tile D in colour E at (column A, row C) and the cell to its right.  Keeps all.
cell2:  push af
        push bc
        push de
        call redraw_cell
        pop de
        pop bc
        pop af
        push af
        push bc
        push de
        inc a
        call redraw_cell
        pop de
        pop bc
        pop af
        ret

tl_ink:    db $0E,$0B,$0D,$0A,$0C,$09
tl_pitch:  db 160,135,114,96,81,68      ; delay per half-cycle (higher = lower): ~790-1760 Hz
tl_cycles: db 39,46,55,64,76,89         ; x 8 bursts: about 0.2 s each
cp_ink:    db $0E,$0B,$0D               ; shard colours (bright; dim when not picked)

str_help:     db "DIAGNOSTICS: -10 MIN",0
str_cp_done:  db " KEY ONLINE ",0
str_tl_listen: db "LISTEN...                 ",0
str_tl_you:    db "YOUR TURN: KEYS 1-6       ",0
str_tl_again:  db "WRONG. LISTEN AGAIN       ",0
str_tl_open:   db "OPEN: +1 SLEEP +1 RESET   ",0

card_page:
        db PG_PANEL,1,2,21,39,$0D
        db PG_HEAD,1,4,$0D,"SPLICE TERMINAL",0
        db PG_TEXT,3,5,$0F,"KEY",0
        db PG_TEXT,3,17,$08,"TURN THE SHARDS TO",0
        db PG_TEXT,4,17,$08,"FILL THE CARD EXACTLY",0
        db PG_KEY,10,5," 1 ",0
        db PG_KEY,10,15," 2 ",0
        db PG_KEY,10,25," 3 ",0
        db PG_TEXT,11,19,$08,"CARD",0
        db PG_SEP,16,4,37
        db PG_KEY,18,4," R ",0
        db PG_TEXT,18,8,$0F,"TURN",0
        db PG_KEY,18,14," F ",0
        db PG_TEXT,18,18,$0F,"FLIP",0
        db PG_KEY,18,24," H ",0
        db PG_TEXT,18,28,$0F,"HELP -10M",0
        db PG_KEY,20,4," X ",0
        db PG_TEXT,20,8,$0F,"LEAVE THE TERMINAL",0
        db PG_END
tone_page:
        db PG_PANEL,1,2,21,39,$0E
        db PG_HEAD,1,4,$0E,"TONE LOCK",0
        db PG_TEXT,4,5,$0F,"MERIDIAN PLAYS A SEQUENCE.",0
        db PG_TEXT,5,5,$0F,"PLAY IT BACK ON KEYS 1-6.",0
        db PG_KEY,11,7," 1 ",0
        db PG_KEY,11,12," 2 ",0
        db PG_KEY,11,17," 3 ",0
        db PG_KEY,11,22," 4 ",0
        db PG_KEY,11,27," 5 ",0
        db PG_KEY,11,32," 6 ",0
        db PG_SEP,15,4,37
        db PG_TEXT,19,5,$08,"THREE ROUNDS OPEN IT",0
        db PG_KEY,20,5," X ",0
        db PG_TEXT,20,9,$0F,"LEAVE THE TERMINAL",0
        db PG_END

        include "cards.inc"
        include "music_ov3.inc"

cp_src:  dw 0
cp_cur:  ds 6                   ; the three shards as they now lie
cp_sel:  db 0
cp_last: db 0
g_row:   db 0
g_col:   db 0
g_ink:   db 0
tl_seq:  ds 6
tl_len:  db 0
tl_left: db 0
tl_pos:  dw 0
tl_pad:  db 0
