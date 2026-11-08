; =====================================================================
;  DRAW: the court on the Microbee - projection, players, ball, effects,
;  scoreboard, umpire's calls and banners, the crowd and the umpire.
; =====================================================================

; ---------------------------------------------------------------------
; do_frame: two sound ticks (50 Hz), finish + show the frame, input, next
do_frame:
        call sound_tick
        call sound_tick
        call frame_end
        call read_input
        jp frame_begin

; ---------------------------------------------------------------------
; proj_hr: B = X int, C = Y int -> HL = screen x (signed), A = ground row
proj_hr:
        ld h,ysc/256
        ld l,c
        ld e,(hl)               ; scale * 128
        ld a,b
        sub 128
        push bc
        call mul_s8u8           ; HL = dx * scale
        pop bc
        add hl,hl               ; carry = sign, H = (dx*scale) >> 7
        ld l,h
        ld h,0
        jr nc,.p
        dec h
.p:     inc h                   ; + 256
        push hl
        ld h,ysy/256
        ld l,c
        ld a,(hl)
        pop hl
        ret

; HL = A (signed) * E (unsigned)
mul_s8u8:
        or a
        jp p,.pos
        neg
        ld h,a
        call umul8
        jp neghl
.pos:   ld h,a
        jp umul8

; ball_screen: -> (bs_x) screen x, (bs_gy) ground row, (bs_y) ball row,
; (bs_yi) world Y int.  B = x/2 (clamped 0..255), C = ground row (VZ style)
ball_screen:
        ld hl,(ball_y)
        call to_int
        ld (bs_yi),a
        ld c,a
        push bc
        ld hl,(ball_x)
        call to_int
        pop bc
        ld b,a
        call proj_hr
        ld (bs_x),hl
        ld (bs_gy),a
        ; height
        ld hl,(ball_z)
        bit 7,h
        ld a,0
        jr nz,.z0
        call to_int
.z0:    ld e,a
        ld a,(bs_yi)
        ld l,a
        ld h,yzs/256
        ld a,(hl)
        ld h,a
        call umul8              ; z * zscale*128
        add hl,hl
        ld a,(bs_gy)
        sub h
        jr nc,.y
        xor a
.y:     ld (bs_y),a
        ld hl,(bs_x)
        srl h
        rr l
        ld a,h
        or a
        jr z,.x
        ld l,255
        bit 7,h
        jr z,.x
        ld l,0
.x:     ld b,l
        ld a,(bs_gy)
        ld c,a
        ret

; ---------------------------------------------------------------------
; match_draw: the sprites of this frame
match_draw:
        ; bounce puff
        ld a,(puff_tim)
        or a
        jr z,.np
        ld a,(puff_x)
        ld b,a
        ld a,(puff_y)
        ld c,a
        call proj_hr
        ld (spr_x),hl
        ld l,a
        ld h,0
        ld (spr_y),hl
        call ink_white
        ld a,(puff_tim)
        cp 5
        ld a,SF_PUFF0
        jr nc,.p1
        ld a,SF_PUFF1
.p1:    call spr_draw
.np:    ld a,(mode)
        cp MODE_PRACTICE
        call z,practice_draw
        ; ball shadow
        ld a,(ball_st)
        cp 4
        jr z,.nosh
        call ball_screen
        ld a,(ball_st)
        or a
        jr z,.nosh
        ld hl,(bs_x)
        ld (spr_x),hl
        ld a,(bs_gy)
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(monomode)
        or a
        ld a,BLACK
        jr z,.sk
        ld a,WHITE
.sk:    ld (spr_ink),a
        ld a,(bs_yi)
        cp 128
        ld a,SF_SHADOW0
        jr c,.sh
        ld a,SF_SHADOW1
.sh:    call spr_draw
.nosh:  ; players: far end first
        call top_player
        push iy
        call draw_player
        pop ix
        call draw_player
        ; ball
        ld a,(ball_st)
        cp 4
        ret z
        call ball_screen
        ld hl,(bs_x)
        ld (spr_x),hl
        ld a,(bs_y)
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(ball_fire)
        or a
        jr z,.nfire
        ld a,(ball_st)
        cp 2
        jr nz,.nfire
        ld a,(monomode)
        or a
        ld a,BRED
        jr z,.fi
        ld a,WHITE
.fi:    ld (spr_ink),a
        ld a,(framecount)
        and 1
        ld a,SF_FIRE0
        jr z,.f1
        ld a,SF_FIRE1
.f1:    call spr_draw
.nfire: ld a,(monomode)
        or a
        ld a,YELLOW
        jr z,.bi
        ld a,WHITE
.bi:    ld (spr_ink),a
        ld a,(bs_y)
        cp 118
        ld a,SF_BALL0
        jr c,.bs
        ld a,(bs_y)
        cp 190
        ld a,SF_BALL1
        jr c,.bs
        ld a,SF_BALL2
.bs:    jp spr_draw

ink_white:
        ld a,WHITE
        ld (spr_ink),a
        ret

; draw_player: IX
draw_player:
        ld a,(ix+P_CTL)
        cp CTL_NONE
        ret z
        ld l,(ix+P_X)
        ld h,(ix+P_X+1)
        call to_int
        ld b,a
        push bc
        ld l,(ix+P_Y)
        ld h,(ix+P_Y+1)
        call to_int
        pop bc
        ld c,a
        push bc
        call proj_hr
        ld (spr_x),hl
        ld l,a
        ld h,0
        ld (spr_y),hl
        pop bc
        call player_frame       ; A = 0..35
        ld (dp_fr),a
        ld c,a
        ld a,(ix+P_END)
        or a
        ld a,c
        jr nz,.n
        add a,NFR               ; far view frames follow the near ones
.n:     ld (dp_id),a
        ld a,(ix+P_IDX)
        ld e,a
        ld d,0
        ld hl,pl_ink
        add hl,de
        ld a,(hl)
        ld (spr_ink),a
        ld a,(dp_id)
        add a,SF_BODY
        call spr_draw
        ; head
        ld a,(dp_id)
        ld l,a
        ld h,0
        add hl,hl
        ld de,hd_tab
        add hl,de
        ld a,(hl)
        inc hl
        push hl
        ld e,a
        ld d,0
        bit 7,a
        jr z,$+3
        dec d
        ld hl,(spr_x)
        add hl,de
        ld (spr_x),hl
        pop hl
        ld a,(hl)
        ld e,a
        ld d,0
        bit 7,a
        jr z,$+3
        dec d
        ld hl,(spr_y)
        add hl,de
        ld (spr_y),hl
        ld a,(ix+P_CHAR)
        ld c,a
        ld a,(ix+P_END)
        or a
        ld a,c
        jr z,.hf
        add a,SF_HEADN
        jp spr_draw
.hf:    add a,SF_HEADF
        jp spr_draw

; draw_you: A = near-view body frame at (spr_x, spr_y), with YOUR head
draw_you:
        push af
        call spr_draw
        pop af
        ld l,a
        ld h,0
        add hl,hl
        ld de,hd_tab
        add hl,de
        ld e,(hl)
        inc hl
        ld a,(hl)
        push af
        ld a,e
        ld d,0
        bit 7,a
        jr z,$+3
        dec d
        ld hl,(spr_x)
        add hl,de
        ld (spr_x),hl
        pop af
        ld e,a
        ld d,0
        bit 7,a
        jr z,$+3
        dec d
        ld hl,(spr_y)
        add hl,de
        ld (spr_y),hl
        ld a,SF_HEADN+8
        jp spr_draw

; frame numbers in the body sets (tools/players.py order)
FR_B_IDLE equ 0
FR_B_RUNR equ 2
FR_B_RUNL equ 8
FR_B_RUNV equ 14
FR_B_FH   equ 18
FR_B_BH   equ 22
FR_B_SV   equ 26
FR_B_JOY  equ 33
FR_B_SAD  equ 35

; player_frame: IX, B = X int, C = Y int -> A = body frame 0..35
player_frame:
        ; direction of travel since the last frame
        ld a,b
        sub (ix+P_LX)
        ld d,a                  ; dx
        ld a,c
        sub (ix+P_LY)
        ld e,a                  ; dy
        ld (ix+P_LX),b
        ld (ix+P_LY),c
        ld a,d
        or e
        jr z,.nd
        ld a,d
        call abs_a
        ld h,a
        ld a,e
        call abs_a
        cp h
        ld a,3
        jr nc,.sd               ; mostly up/down the court
        ld a,d
        or a
        ld a,1
        jp p,.sd
        ld a,2
.sd:    ld (ix+P_DIR),a
.nd:    ; swinging
        ld a,(ix+P_SWING)
        or a
        jr z,.ns
        ld c,a
        ld a,(ix+P_SWFR)
        cp FR_SERVE2
        jr nz,.shot
        ld a,c
        cp 8
        ld a,FR_B_SV+3
        ret nc
        inc a
        ret
.shot:  cp FR_FORE
        ld a,0
        jr z,.s1
        inc a
.s1:    xor (ix+P_END)          ; near view: forehand stays; far view swaps
        xor 1
        ld a,FR_B_FH
        jr z,.s2
        ld a,FR_B_BH
.s2:    ld b,a
        ld a,c
        cp 8
        jr c,.s3
        ld a,b
        inc a                   ; contact
        ret
.s3:    cp 5
        ld a,b
        jr c,.s4
        add a,2
        ret
.s4:    add a,3
        ret
.ns:    ld a,(ix+P_POSE)
        or a
        jr z,.np
        cp FR_SAD
        ld a,FR_B_SAD
        ret z
        ld a,(framecount)
        and 8
        ld a,FR_B_JOY
        ret z
        inc a
        ret
.np:    ; serving
        ld a,(ball_st)
        cp 2
        jr nc,.nsv
        ld a,(server)
        cp (ix+P_IDX)
        jr nz,.nsv
        ld a,(ball_st)
        or a
        ld a,FR_B_SV
        ret z
        ld hl,(ball_vz)
        bit 7,h
        ld a,FR_B_SV+1
        ret z
        inc a
        ret
.nsv:   ; ready for an incoming ball: the backswing
        ld a,(ball_st)
        cp 2
        jr nz,.nb
        ld a,(ball_last)
        cp (ix+P_IDX)
        jr z,.nb
        ld a,(ball_cross)
        or a
        jr z,.nb
        ld hl,(ball_y)
        call to_int
        sub (ix+P_LY)
        call abs_a
        cp 36
        jr nc,.nb
        ld hl,(ball_x)
        call to_int
        sub (ix+P_LX)
        ld a,0
        jr nc,.b1
        inc a                   ; ball to the screen left
.b1:    xor (ix+P_END)
        xor 1
        ld a,FR_B_FH
        ret z
        ld a,FR_B_BH
        ret
.nb:    ld a,(ix+P_MOVED)
        or a
        jr z,.idle
        ld a,(ix+P_ANIM)
        rrca
        rrca
        and 63
        ld b,a
        ld a,(ix+P_DIR)
        cp 3
        jr z,.v
        ld c,a
        ld a,b
.m6:    cp 6
        jr c,.m6d
        sub 6
        jr .m6
.m6d:   ld b,a
        ld a,c
        ; far view is mirrored: a run to the right uses the RUNL frames
        dec a
        xor (ix+P_END)
        xor 1
        ld a,FR_B_RUNR
        jr z,.r
        ld a,FR_B_RUNL
.r:     add a,b
        ret
.v:     ld a,b
        and 3
        add a,FR_B_RUNV
        ret
.idle:  ld a,(framecount)
        and 16
        ld a,FR_B_IDLE
        ret z
        inc a
        ret

; IX = the far player, IY = the near one
top_player:
        ld ix,pl0
        ld iy,pl1
        ld a,(ix+P_END)
        or a
        ret z
        ld ix,pl1
        ld iy,pl0
        ret

idx_byte:
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        ret

sprites_for_ends:
        ret

; ---------------------------------------------------------------------
; effects: popups, line calls, bounce puff
POPROW  equ 0
popup_ball:     ; A = popup index: words by the ball
        push af
        call popup_clear
        call ball_screen
        pop af
        add a,a
        ld l,a
        ld h,0
        ld de,popstr
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (pop_str),hl
        call strlen
        ld (pop_w),a
        ; column: centred on the ball, on screen
        ld hl,(bs_x)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l                    ; cell column (may be off screen)
        ld a,h
        or a
        ld a,l
        jr z,.c0
        ld a,0
        bit 7,h
        jr nz,.c0
        ld a,63
.c0:    ld b,a
        ld a,(pop_w)
        srl a
        ld c,a
        ld a,b
        sub c
        jr nc,.c1
        xor a
.c1:    ld b,a
        ld a,(pop_w)
        add a,b
        cp 63
        jr c,.c2
        ld a,63
        ld hl,pop_w
        sub (hl)
        ld b,a
.c2:    ld a,b
        ld (pop_x),a
        ; row: two cells above the ball
        ld a,(bs_y)
        rrca
        rrca
        rrca
        rrca
        and 15
        sub 2
        jr nc,.r0
        xor a
.r0:    cp 4
        jr nc,.r1
        ld a,4
.r1:    cp 14
        jr c,.r2
        ld a,13
.r2:    ld (pop_y),a
        ld hl,(pop_str)
        ld a,(pop_x)
        ld d,a
        ld a,(pop_y)
        ld e,a
        ld a,YELLOW
        call print_over
        ld a,1
        ld (pop_on),a
        ld a,45
        ld (pop_tim),a
        ret

popup_clear:
        ld a,(pop_on)
        or a
        ret z
        xor a
        ld (pop_on),a
        ld (pop_tim),a
        ld a,(pop_x)
        ld d,a
        ld a,(pop_y)
        ld e,a
        ld a,(pop_w)
        ld b,a
        ld c,1
        jp restore_rect

; the line judge's call: the umpire's arm goes up
show_flag:
        ld a,3
        ld b,50
        call ump_hold
        ld a,SFX_OUT
        jp play_sfx

fx_update:
        ld hl,pop_tim
        ld a,(hl)
        or a
        jr z,.p
        dec (hl)
        call z,popup_clear
.p:     ld hl,puff_tim
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret

; print_over: HL = string at col D row E, ink A on each cell's own paper
print_over:
        ld (po_ink),a
        push de
        ld de,ptbuf
        ld bc,64
        ldir
        pop de
        ld hl,ptbuf
        ld a,(curblk)
        push af
        ld a,BLK_RT
        call map_blk
.l:     ld a,(hl)
        or a
        jr z,.x
        inc hl
        push hl
        push de
        sub 32
        ld l,a
        ld h,0
        ld bc,(txt_font)
        add hl,bc
        push hl
        call cell_of_de         ; HL = cell
        ld a,h
        add a,cur_col/256
        ld b,a
        ld c,l
        ld a,(bc)
        and $F0
        ld b,a
        ld a,(po_ink)
        or b
        ld c,a
        pop de
        call set_cell_rt
        pop de
        pop hl
        inc d
        jr .l
.x:     pop af
        jp map_port

; D = col, E = row -> HL = row*64 + col
cell_of_de:
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or d
        ld l,a
        ret

; ---------------------------------------------------------------------
; banner: HL = line 1, DE = line 2 (or 0): a scoreboard-style box over the far court
BAN_X   equ 16
BAN_W   equ 32
BAN_Y   equ 5
banner:
        push de
        push hl
        ld a,$FF
        ld e,BAN_Y
        ld c,2
        call block_rows
        ld a,(monomode)
        or a
        ld a,BLUE<<4|WHITE
        jr z,.c
        ld a,BLACK<<4|WHITE
.c:     ld (txt_col),a
        ld hl,G_FONT1
        ld (fc_glyph),hl
        ld de,BAN_X*256+BAN_Y
        ld bc,BAN_W*256+2
        call fill_cells
        ld hl,G_FONT1
        ld (txt_font),hl
        ld a,(monomode)
        or a
        ld a,BLUE<<4|YELLOW
        jr z,.c2
        ld a,BLACK<<4|WHITE
.c2:    ld (txt_col),a
        pop hl
        ld e,BAN_Y
        call print_c
        pop hl
        ld a,h
        or l
        ret z
        ld a,(monomode)
        or a
        ld a,BLUE<<4|WHITE
        jr z,.c3
        ld a,BLACK<<4|WHITE
.c3:    ld (txt_col),a
        ld e,BAN_Y+1
        jp print_c

court_restore:
        xor a
        ld e,BAN_Y
        ld c,2
        call block_rows
        ld de,BAN_X*256+BAN_Y
        ld bc,BAN_W*256+2
        jp restore_rect

; ---------------------------------------------------------------------
; scoreboard: top-left, rows 0-2, columns 0-15 (LED font)
hud_draw:
        ld hl,G_FONT2
        ld (txt_font),hl
        ld a,(monomode)
        or a
        ld a,BLACK<<4|YELLOW
        jr z,.c
        ld a,BLACK<<4|WHITE
.c:     ld (txt_col),a
        ld hl,G_FONT2
        ld (fc_glyph),hl
        ld de,$0000
        ld bc,$1003
        call fill_cells
        ; the venue on the top line
        ld hl,G_FONT1
        ld (txt_font),hl
        ld a,(monomode)
        or a
        ld a,BLACK<<4|BCYAN
        jr z,.h
        ld a,BLACK<<4|WHITE
.h:     ld (txt_col),a
        ld hl,(s_name)
        call strlen
        ld b,a
        ld a,16
        sub b
        srl a
        ld d,a
        ld e,0
        call print
        ld hl,G_FONT2
        ld (txt_font),hl
        ld a,(monomode)
        or a
        ld a,BLACK<<4|YELLOW
        jr z,.c2
        ld a,BLACK<<4|WHITE
.c2:    ld (txt_col),a
        ld a,(mode)
        cp MODE_PRACTICE
        jp z,hud_practice
        call top_player
        push iy
        ld e,1
        call hud_line
        pop ix
        ld e,2
        call hud_line
        ld hl,G_FONT1
        ld (txt_font),hl
        ret
; hud_line: IX, row E: [serve mark] NAME  sets games points
hud_line:
        ld d,0
        push de
        ld a,(server)
        cp (ix+P_IDX)
        ld hl,s_srv
        jr z,.s
        ld hl,s_nosrv
.s:     call print
        pop de
        ld d,1
        push de
        ld l,(ix+P_NAME)
        ld h,(ix+P_NAME+1)
        call print
        pop de
        ld d,9
        push de
        ld hl,sets
        ld a,(ix+P_IDX)
        call idx_byte
        call hud_digit
        pop de
        ld d,11
        push de
        ld hl,games
        ld a,(ix+P_IDX)
        call idx_byte
        call hud_digit
        pop de
        ld d,13
        push de
        call points_text
        pop de
        jp print
hud_digit:      ; A = 0..9 at D,E
        add a,'0'
        ld (tbuf2),a
        xor a
        ld (tbuf2+1),a
        ld hl,tbuf2
        jp print
s_srv:   db 96,0                ; the server marker
s_nosrv: db " ",0

; points_text: IX = player -> HL = "00"/"15"/"30"/"40"/"AD"/tie-break count
points_text:
        ld a,(ix+P_IDX)
        ld e,a
        xor 1
        ld hl,pts
        call idx_byte
        ld d,a                  ; opponent's points
        ld a,e
        ld hl,pts
        call idx_byte           ; mine
        ld e,a
        ld a,(tiebreak)
        or a
        jr z,.reg
        ld a,e
        ld de,tbuf2
        push de
        call num_de
        xor a
        ld (de),a
        pop hl
        ret
.reg:   ld a,e
        cp 4
        jr c,.n
        ld a,d
        cp e
        ld hl,s_ad
        ret c
        ld hl,s_40
        ret
.n:     add a,a
        ld l,a
        ld h,0
        ld de,ptnames
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret
ptnames: dw s_00,s_15,s_30,s_40
s_00:   db " 0",0
s_15:   db "15",0
s_30:   db "30",0
s_40:   db "40",0
s_ad:   db "AD",0

hud_practice:
        ld hl,s_balls
        ld de,$0001
        call print
        ld a,(pr_balls)
        ld de,$0601
        call print_n2
        ld hl,s_hits
        ld de,$0901
        call print
        ld a,(pr_hits)
        ld de,$0E01
        call print_n2
        ld hl,s_pts
        ld de,$0002
        call print
        ld hl,pr_score
        ld b,2
        ld de,$0602
        call print_bcd
        ld hl,G_FONT1
        ld (txt_font),hl
        ret
s_balls: db "BALLS",0
s_hits:  db "HITS",0
s_pts:   db "POINTS",0

; A = 0..99 at D,E (two characters)
print_n2:
        push de
        ld de,tbuf2
        cp 10
        jr nc,.t
        push af
        ld a,' '
        ld (de),a
        inc de
        pop af
.t:     call num_de
        xor a
        ld (de),a
        pop de
        ld hl,tbuf2
        jp print

; print_bcd: HL = BCD bytes (high first), B = count, at D,E
print_bcd:
        push de
        ld de,tbuf2
.l:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        ld (de),a
        inc de
        ld a,(hl)
        and 15
        add a,'0'
        ld (de),a
        inc de
        inc hl
        djnz .l
        xor a
        ld (de),a
        pop de
        ld hl,tbuf2
        jp print

; ---------------------------------------------------------------------
; the crowd. Records (RT_CROWD): dw n, then n x (dw cell, db column,
; lo1 hi1 col1 (cheering), lo2 hi2 col2 (standing)), sorted by column;
; then 64 counts per column. RT_CSTATE: each spectator cell's pose.
crowd_cheer:    ; A = ticks
        ld (crowdtim),a
        xor a
        ld (crowdmode),a
        ret
crowd_wave:     ; A = ticks
        ld (crowdtim),a
        ld a,1
        ld (crowdmode),a
        xor a
        ld (crowdph),a
        ld (crowddir),a
        ret
crowd_reset:
        xor a
        ld (crowdtim),a
        jp crowd_idle

crowd_tick:
        ld a,(crowdtim)
        or a
        ret z
        dec a
        ld (crowdtim),a
        jp z,crowd_idle
        and 3
        ret nz
        ld a,(crowdmode)
        or a
        jr nz,.wave
        ; cheering: a dozen spectators jump up or sit down
        ld b,12
.ch:    push bc
        call random
        ld e,a
        call random
        and 1
        ld d,a                  ; DE = 0..511
        ld hl,(crowd_n)
        ld a,h
        or l
        jr z,.chx
.m:     push hl
        scf
        sbc hl,de               ; n - 1 - k
        pop hl
        jr nc,.ok
        ex de,hl
        or a
        sbc hl,de
        ex de,hl
        jr .m
.ok:    ex de,hl                ; HL = spectator
        call crowd_state
        xor 1
        and 1
        call crowd_set
.chx:   pop bc
        djnz .ch
        ret
.wave:  ; the crest moves a column at a time, out and back
        ld a,(crowdph)
        ld c,a
        ld a,2
        call crowd_col          ; column crest stands
        ld a,(crowdph)
        ld b,a
        ld a,(crowddir)
        or a
        ld a,b
        jr nz,.back
        sub 3
        ld c,a
        xor a
        call crowd_col          ; three behind sit down
        ld a,(crowdph)
        inc a
        ld (crowdph),a
        cp 67
        ret c
        ld a,1
        ld (crowddir),a
        ret
.back:  add a,3
        ld c,a
        xor a
        call crowd_col
        ld a,(crowdph)
        dec a
        ld (crowdph),a
        cp $FD
        ret nz
        xor a
        ld (crowddir),a
        ret

; everyone sits
crowd_idle:
        ld hl,(crowd_n)
.l:     ld a,h
        or l
        ret z
        dec hl
        push hl
        call crowd_state
        or a
        ld a,0
        call nz,crowd_set
        pop hl
        jr .l

; set every spectator of column C (0..63, others ignored) to pose A
crowd_col:
        ld (cc_pose),a
        ld a,c
        cp 64
        ret nc
        ; first record of the column: sum of the counts before it
        ld a,(curblk)
        push af
        ld a,BLK_RT
        call map_blk
        ld hl,(crowd_n)
        ld de,(crowd_n)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de               ; 9n
        ld de,RT_CROWD+2
        add hl,de               ; counts
        ld de,0
        ld b,c
        inc b
        jr .s1
.s:     ld a,(hl)
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        inc hl
.s1:    djnz .s
        ld b,(hl)               ; this column's count
        pop af
        call map_port
        ex de,hl
.c:     ld a,b
        or a
        ret z
        push bc
        push hl
        ld a,(cc_pose)
        call crowd_set
        pop hl
        inc hl
        pop bc
        dec b
        jr .c

; spectator HL -> A = pose
crowd_state:
        ld a,(curblk)
        push af
        ld a,BLK_RT
        call map_blk
        push hl
        ld de,RT_CSTATE
        add hl,de
        ld b,(hl)
        pop hl
        pop af
        call map_port
        ld a,b
        ret

; crowd_set: spectator HL to pose A (0 seated, 1 cheering, 2 standing)
crowd_set:
        ld c,a
        ld a,(curblk)
        push af
        ld a,BLK_RT
        call map_blk
        push hl
        ld de,RT_CSTATE
        add hl,de
        ld a,(hl)
        cp c
        ld (hl),c
        pop hl
        jr z,.x
        ; record = RT_CROWD + 2 + 9*k
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld de,RT_CROWD+2
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; cell
        inc hl
        inc hl
        ld a,c
        or a
        jr z,.base
        dec a
        jr z,.v
        inc hl
        inc hl
        inc hl
.v:     ld a,(hl)               ; lo
        inc hl
        ld b,(hl)               ; bank
        inc hl
        ld c,(hl)               ; colour
        ex de,hl
        call put_cell_rt
.x:     pop af
        jp map_port
.base:  ex de,hl
        ld bc,1
        call restore_base
        jr .x

; put_cell_rt: HL = cell, A = lo code, B = bank, C = colour (RT mapped)
put_cell_rt:
        push de
        ld e,a
        ld a,h
        add a,cur_lo/256
        ld d,a
        ld a,e
        ld e,l
        ld (de),a
        ld a,d
        add a,4
        ld d,a
        ld a,b
        ld (de),a
        ld a,d
        add a,4
        ld d,a
        ld a,c
        ld (de),a
        pop de
        jp md_rt

; ---------------------------------------------------------------------
; the umpire. RT_UMP: 4 lists (poses 1..4: look left, look right,
; arm up, lean in): db n, n x (dw cell, db lo, bank, colour)
; ump_hold: A = pose, B = ticks to keep it
ump_hold:
        push bc
        call ump_set
        pop bc
        ld a,b
        ld (ump_tim),a
        ret

ump_tick:
        ld a,(ump_tim)
        or a
        jr z,.look
        dec a
        ld (ump_tim),a
        ret nz
        xor a
        jp ump_set
.look:  ld a,(framecount)
        and 7
        ret nz
        ld a,(ball_st)
        cp 2
        ld a,0
        jr c,.s
        ld hl,(ball_x)
        call to_int
        cp 96
        ld a,1
        jr c,.s
        ld hl,(ball_x)
        call to_int
        cp 160
        ld a,2
        jr nc,.s
        xor a
.s:     jp ump_set

; ump_set: A = pose 0..4
ump_set:
        ld hl,ump_pose
        cp (hl)
        ret z
        push af
        ld a,(curblk)
        push af
        ld a,BLK_RT
        call map_blk
        ld a,(ump_pose)
        or a
        call nz,.cells          ; back to the base picture
        pop af
        pop bc
        push af
        ld a,b
        ld (ump_pose),a
        or a
        jr z,.x
        ld a,b
        ld c,1
        call .cells
.x:     pop af
        jp map_port
; .cells: A = pose, C = 0 restore / 1 apply (RT mapped)
.cells: ld b,a
        ld a,c
        ld (us_mode),a
        ld hl,RT_UMP
.f1:    dec b
        jr z,.go
        ld e,(hl)               ; skip a list: 1 + n*5 bytes
        inc hl
        ld d,0
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,de
        ex de,hl
        pop hl
        add hl,de
        jr .f1
.go:    ld b,(hl)
        inc hl
        ld a,b
        or a
        ret z
.c:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        ex de,hl
        ld e,a
        ld a,(us_mode)
        or a
        ld a,e
        jr z,.rb
        call put_cell_rt
        jr .nx
.rb:    ld bc,1
        call restore_base
.nx:    pop hl
        pop bc
        djnz .c
        ret
