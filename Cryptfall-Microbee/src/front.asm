; =====================================================================
;  FRONT END: the title with its bats and falling stone, how to play,
;  the gravediggers' roll, the attract-mode demo, game over and the
;  name entry.  All of it is drawn straight on page 0.
; =====================================================================
start:  ld a,$FF
        ld (hi_mark),a
        ld hl,fe_slots
        call load_tiles
        xor a
        call draw_page
        ld a,$80
        ld bc,$0100
        call fill_page
        xor a
        call show_page
        call pcg_init
        ld a,1
        ld (sfxon),a
        ld (musicon),a
        ld (p_alive),a
        ld a,WHITE
        ld (txt_col),a
        ld hl,t_loading
        ld b,12
        call print_c
        call disk_init
        call hi_load
        call demo_load
        ld hl,(ncaves)
        ld a,h
        or l
        jr nz,front
        ld a,BRED               ; no caves file: nothing to play
        ld (txt_col),a
        ld hl,t_nocaves
        ld b,14
        call print_c
.h:     jr .h
t_loading: db "CRYPTFALL",0
t_nocaves: db "CAVES.DAT IS MISSING FROM THIS DISK",0

; ---- the cycle: title, roll, how to play, demo -------------------------
front:  ld sp,STACK
        xor a
        ld (demo_on),a
        ld (fe_page),a
front_next:
        ld sp,STACK
        xor a
        ld (demo_on),a
        ld (paused),a
        ld (flash),a
        ld (magic_st),a
        ld (exit_open),a
        ld (p_moving),a
        inc a
        ld (p_alive),a
        ld hl,fe_slots
        call load_tiles
        ld a,(fe_page)
        cp 7
        jr c,.ok
        xor a
        ld (fe_page),a
.ok:    ld hl,fe_page
        inc (hl)
        or a
        jp z,title
        dec a
        jp z,roll_page
        cp 5
        jp z,demo_start
        ; how to play, pages 1-4
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,help_pages
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call text_page
        ld hl,500
        call page_wait
        jr front_next
help_pages: dw help1, help2, help3, help4

; set the screen up for a front-end page: page 0 shown and drawn on, blank
fe_clear:
        xor a
        call draw_page
        call wait_vb
        xor a
        call show_page
        ld a,$80
        ld bc,$0100
        jp fill_page

; one front-end frame (2 fields): input, sound, tile animation
fe_frame:
        call read_input
        ld a,2
        call frame_end
        jp anim_frame

; wait HL frames, calling (fe_hook) each one.  SPACE starts a game; RETURN
; or the time running out goes on to the next page; ESC goes to the title
page_wait:
.f:     push hl
        call fe_frame
        ld hl,(fe_hook)
        ld a,h
        or l
        call nz,.call
        call fe_keys
        pop hl
        ret nz
        dec hl
        ld a,h
        or l
        jr nz,.f
        ret
.call:  jp (hl)

; the keys every front-end page knows.  NZ = leave the page
fe_keys:
        ld hl,padnew
        ld a,(hl)
        ld (hl),0
        ld b,a
        ld hl,keysnew
        ld a,(hl)
        ld (hl),0
        ld c,a
        bit 3,c
        call nz,sound_toggle
        bit 5,c
        call nz,fe_music
        bit 6,c
        call nz,joy_toggle
        bit 4,b
        jp nz,start_game
        bit 0,c
        jr z,.ne
        xor a
        ld (fe_page),a          ; ESC: back to the title
        or 1
        ret
.ne:    ld a,c
        and 16                  ; RETURN: next page
        ret
fe_music:
        ld a,(musicon)
        xor 1
        ld (musicon),a
        jp z,stop_music
        ret

start_game:
        xor a
        ld (demo_on),a
        ld (fe_hook),a
        ld (fe_hook+1),a
        call stop_music
        jp new_game

; wait (up to 2 seconds) for every key to be let go, and forget what was pressed
keys_up:
        ld b,50
.w:     push bc
        call fe_frame
        call any_key
        pop bc
        or a
        jr z,.up
        djnz .w
.up:    call read_input
        xor a
        ld (keysnew),a
        ld (padnew),a
        ret

; ---- text pages -----------------------------------------------------------
; HL = page: entries of  db row, column, colour, "text", 0   (column 255 =
; centred), or  db $FE, row, column, tile  (a tile picture);  $FF ends
text_page:
        push hl
        call fe_clear
        ld hl,0
        ld (fe_hook),hl
        pop hl
.e:     ld a,(hl)
        cp $FF
        ret z
        cp $FE
        jr z,.icon
        ld b,a
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (txt_col),a
        push hl
        ld a,c
        inc a
        jr z,.cen
        call print
        jr .nx
.cen:   call print_c
.nx:    pop hl
.sk:    ld a,(hl)
        inc hl
        or a
        jr nz,.sk
        jr .e
.icon:  inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        call tile_at
        pop hl
        jr .e

; A = tile, B = row, C = column: its 2 x 2 cells on page 0 (clipped to the screen)
tile_at:
        ld (ta_id),a
        ld d,0
.q:     ld a,d
        and 1
        add a,c
        cp COLS
        jr nc,.nx
        ld e,a
        ld a,d
        rrca
        and 1
        add a,b
        cp 25
        jr nc,.nx
        push bc
        push de
        call row_addr
        ld a,e
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ex de,hl                ; DE = cell, H = quadrant
        ld a,h
        rrca
        and 1
        add a,GT>>8
        ld b,a
        ld a,h
        and 1
        rrca
        rrca
        ld c,a
        ld a,(ta_id)
        or c
        ld c,a
        ld a,(bc)
        ld (de),a
        ld a,LV_ATTR
        out (P_LV),a
        xor a
        ld (de),a               ; PCG bank 0
        ld a,LV_SCREEN
        out (P_LV),a
        inc b
        inc b
        ld a,d
        add a,8
        ld d,a
        ld a,(bc)
        ld (de),a
        pop de
        pop bc
.nx:    inc d
        ld a,d
        cp 4
        jr nz,.q
        ret

help1:  db 1,255,YELLOW,"HOW TO PLAY",0
        db $FE,3,2,T_PLAYER
        db 3,6,WHITE,"MORT THE GRAVEDIGGER",0
        db 4,6,GREY,"ARROW KEYS OR JOYSTICK",0
        db $FE,6,2,T_DIRT1
        db $FE,6,5,T_DIRT2
        db 6,9,WHITE,"DIG THROUGH ANY EARTH",0
        db 7,9,GREY,"THE CRYPTS ARE BIG: EXPLORE",0
        db $FE,9,2,T_GEM
        db 9,6,WHITE,"COLLECT JEWELS UNTIL THE",0
        db 10,6,WHITE,"COUNT TURNS GREEN...",0
        db $FE,12,2,T_EXITO
        db 12,6,WHITE,"...THEN FIND THE GATE",0
        db 13,6,GREY,"BEFORE THE CANDLE BURNS OUT",0
        db 15,2,BCYAN,"LEAN ON A STONE TO PUSH IT SIDEWAYS",0
        db 16,2,BCYAN,"SPACE + ARROW: REACH WITHOUT STEPPING",0
        db 18,2,BCYAN,"P  PAUSE AND SEE THE MAP OF THE CRYPT",0
        db 19,2,BCYAN,"R R  TRAPPED? MORT GOES UP IN JEWELS",0
        db 20,5,GREY,"AND TRIES AGAIN. NO LIFE IS LOST",0
        db 21,2,BCYAN,"S SOUND   J JOYSTICK   ESC ESC QUIT",0
        db 23,255,GREY,"SPACE: PLAY     RETURN: MORE",0
        db $FF
help2:  db 1,255,YELLOW,"HEAVY THINGS AND JEWELS",0
        db $FE,3,2,T_BOULDER
        db 3,6,WHITE,"STONES FALL, AND ROLL OFF",0
        db 4,6,WHITE,"ROUND THINGS. STAND CLEAR!",0
        db $FE,6,2,T_SLAB
        db 6,6,WHITE,"SLABS FALL BUT NEVER ROLL",0
        db $FE,8,2,T_URN
        db 8,6,WHITE,"AN URN THAT FALLS BREAKS",0
        db 9,6,WHITE,"OPEN AND LEAVES A GEM",0
        db $FE,11,2,T_KEG
        db 11,6,WHITE,"A POWDER KEG BURSTS WHEN IT",0
        db 12,6,WHITE,"LANDS OR IS LANDED ON",0
        db $FE,14,2,T_CRACKED
        db 14,6,WHITE,"A STONE OR SLAB FALLING ON",0
        db 15,6,WHITE,"A CRACKED WALL BREAKS IT",0
        db $FE,17,2,T_GEM
        db $FE,17,5,T_RUBY
        db $FE,17,8,T_EMERALD
        db 17,11,WHITE,"GEM, RUBY, EMERALD:",0
        db 18,11,WHITE,"WORTH ONE, TWO, THREE",0
        db $FE,20,2,T_MAGIC
        db 20,6,WHITE,"THE GRATE MAKES STONES GEMS,",0
        db 21,6,WHITE,"SLABS RUBIES, URNS EMERALDS",0
        db 23,255,GREY,"SPACE: PLAY     RETURN: MORE",0
        db $FF
help3:  db 1,255,YELLOW,"WHO HAUNTS THE CASTLE",0
        db $FE,3,2,T_GHOST
        db 3,6,WHITE,"GHOSTS KEEP A HAND ON THE",0
        db 4,6,WHITE,"WALL TO THEIR LEFT",0
        db $FE,6,2,T_BAT
        db 6,6,WHITE,"BATS FOLLOW THE RIGHT WALL",0
        db 7,6,WHITE,"AND BURST INTO JEWELS",0
        db $FE,9,2,T_KNIGHT
        db 9,6,WHITE,"KNIGHTS MARCH TO AND FRO",0
        db $FE,12,2,T_SKULL
        db 12,6,WHITE,"THE SKULL HUNTS MORT DOWN.",0
        db 13,6,WHITE,"IT IS SLOW. OUTRUN IT",0
        db 15,2,BRED,"DO NOT LET THEM TOUCH YOU:",0
        db 16,2,BRED,"DROP A STONE ON THEM INSTEAD!",0
        db $FE,18,2,T_SLIME
        db 18,6,WHITE,"SLIME SPREADS. PEN IT IN AND",0
        db 19,6,WHITE,"IT HARDENS INTO JEWELS. LET",0
        db 20,6,WHITE,"IT GROW TOO BIG: STONES",0
        db 23,255,GREY,"SPACE: PLAY     RETURN: MORE",0
        db $FF
help4:  db 1,255,YELLOW,"TREASURES AND CHARMS",0
        db $FE,3,2,T_CROWN
        db 3,6,WHITE,"A CROWN: 1000 POINTS",0
        db $FE,5,2,T_CHALICE
        db 5,6,WHITE,"A CHALICE: 500 POINTS",0
        db $FE,7,2,T_WARD
        db 7,6,WHITE,"A WARD SAVES MORT ONCE. YOU",0
        db 8,6,WHITE,"START EVERY CRYPT WITH ONE",0
        db $FE,10,2,T_HOURGLASS
        db 10,6,WHITE,"HOURGLASS: 20 MORE SECONDS",0
        db $FE,12,2,T_HEART
        db 12,6,WHITE,"A HEART: ONE MORE LIFE",0
        db $FE,14,2,T_KEY
        db $FE,14,5,T_DOOR
        db 14,9,WHITE,"A KEY OPENS ONE DOOR",0
        db 17,2,BCYAN,"JEWEL STORMS ARE BONUS CRYPTS:",0
        db 18,2,BCYAN,"FAIL ONE AND NO LIFE IS LOST",0
        db 20,2,GREY,"A CRYPT YOU HAVE REACHED CAN BE",0
        db 21,2,GREY,"CHOSEN ON THE TITLE PAGE",0
        db 23,255,GREY,"SPACE: PLAY     RETURN: TITLE",0
        db $FF

; ---- the title ---------------------------------------------------------------
NBAT    equ 2
title:  call fe_clear
        ; the picture's glyphs: banks 2 up
        ld hl,title_pcg
        ld bc,TITLE_NG
        ld a,2
.bk:    push af
        push bc
        call pcg_bank
        pop bc
        push bc
        ld a,b
        or a
        jr nz,.full
        ld a,c
        cp 128
        jr c,.part
.full:  ld a,128
.part:  ld b,a
        push af
        xor a
        call pcg_put            ; HL moves on past the patterns
        pop af
        pop bc
        ld e,a
        ld a,c
        sub e
        ld c,a
        ld a,b
        sbc a,0
        ld b,a
        pop af
        inc a
        ld e,a
        ld a,b
        or c
        ld a,e
        jr nz,.bk
        xor a
        call pcg_bank
        ; the picture
        call wait_vb
        ld hl,title_lo
        ld de,VIDEO
        ld bc,1000
        ldir
        ld hl,title_col
        ld de,COLWIN
        ld bc,1000
        ldir
        ld a,LV_ATTR
        out (P_LV),a
        ld hl,title_hi
        ld de,VIDEO
        ld bc,880
        ldir
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,GREY
        ld (txt_col),a
        ld hl,t_vibed
        ld b,22
        call print_c
        call title_crypt
        ld a,(mplaying)
        or a
        jr nz,.mp
        ld hl,mus_title_0
        ld de,mus_title_1
        call play_music
.mp:    ; the bats and the stone
        ld hl,tbat
        ld (hl),-2
        inc hl
        ld (hl),9
        inc hl
        ld (hl),1
        inc hl
        ld (hl),0
        inc hl
        ld (hl),40
        inc hl
        ld (hl),3
        inc hl
        ld (hl),-1
        inc hl
        ld (hl),30
        xor a
        ld (tst_state),a
        ld a,40
        ld (tst_t),a
        ld hl,title_hook
        ld (fe_hook),hl
        ld hl,650
        call page_wait
        ld hl,0
        ld (fe_hook),hl
        jp front_next

t_vibed: db "VIBED BY BPM 2026",0
t_press: db "PRESS SPACE TO ENTER THE CASTLE",0
t_crsel: db "UP/DOWN: CRYPT ",0
t_help:  db "    RETURN: HOW TO PLAY",0

; row 24: the crypt to start at
title_crypt:
        ld a,24
        call row_addr
        ex de,hl
        ld a,BCYAN
        ld (txt_col),a
        ld hl,t_crsel
        call .s
        ld a,WHITE
        ld (txt_col),a
        ld a,(start_cave)
        inc a
        push de
        call bin2bcd
        ld a,l
        pop de
        call put_bcd
        ld a,GREY
        ld (txt_col),a
        ld hl,t_help
.s:     ld a,(hl)
        or a
        ret z
        inc hl
        call put_char
        jr .s

; every frame of the title
title_hook:
        ; UP / DOWN choose the crypt to start at (any reached so far)
        ld a,(padnew)
        ld c,a
        and PAD_U+PAD_D
        jr z,.nk
        ld a,(start_cave)
        bit 2,c
        jr z,.dn
        ld hl,hibuf+8
        cp (hl)
        jr nc,.nk
        inc a
        jr .set
.dn:    or a
        jr z,.nk
        dec a
.set:   ld (start_cave),a
        ld a,SFX_MENU
        call play_sfx
        call title_crypt
.nk:    ld a,(padnew)
        and PAD_FIRE
        ld (padnew),a           ; (the arrows are used up; fire is for fe_keys)
        ; the blinking invitation
        ld a,(framecount)
        and 31
        jr nz,.nb
        ld a,(framecount)
        and 32
        ld a,YELLOW
        jr z,.c
        ld a,WHITE
.c:     ld (txt_col),a
        ld hl,t_press
        ld b,23
        call print_c
.nb:    ; a window flickers
        ld a,(framecount)
        and 7
        jr nz,.nw
        call random
        and 15
        cp TITLE_NWIN
        jr nc,.nw
        add a,a
        ld e,a
        ld d,0
        ld hl,title_win
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,COLWIN
        add hl,de
        ld a,(hl)
        xor $80                 ; paper yellow <-> brown
        ld (hl),a
.nw:    ; on alternate frames: move the bats and the stone
        ld a,(framecount)
        rra
        ret c
        ld ix,tbat
        ld b,NBAT
.bat:   push bc
        call .onebat
        ld de,4
        add ix,de
        pop bc
        djnz .bat
        jp title_stone
.onebat:
        ld a,(ix+3)
        or a
        jr z,.fly
        dec (ix+3)              ; waiting off screen
        ret
.fly:   ld b,(ix+1)
        ld c,(ix+0)
        call title_restore
        ld a,(ix+0)
        add a,(ix+2)
        ld (ix+0),a
        cp 41
        jr z,.gone
        cp -3
        jr z,.gone
        ; it bobs as it goes
        and 7
        jr nz,.nb2
        call random
        and 1
        add a,a
        dec a
        add a,(ix+1)
        cp 2
        jr c,.nb2
        cp 17
        jr nc,.nb2
        ld (ix+1),a
.nb2:   ld b,(ix+1)
        ld c,(ix+0)
        ld a,T_BAT
        jp tile_at
.gone:  call random
        and 63
        add a,20
        ld (ix+3),a
        ld a,(ix+2)
        neg
        ld (ix+2),a             ; back the other way next time
        ret

; the stone that drops out of the name: 0 waiting, 1 falling, 2 lying there
title_stone:
        ld a,(tst_state)
        or a
        jr nz,.go
        ld hl,tst_t
        dec (hl)
        ret nz
        call random
        and 7
        add a,a
        add a,22
        ld (tst_x),a
        ld a,6
        ld (tst_y),a
        ld a,1
        ld (tst_state),a
        ret
.go:    dec a
        jr nz,.lying
        ld a,(tst_y)
        ld b,a
        ld a,(tst_x)
        ld c,a
        call title_restore
        ld a,(tst_y)
        inc a
        ld (tst_y),a
        cp 18
        jr c,.draw
        ld a,2
        ld (tst_state),a
        ld a,50
        ld (tst_t),a
        ld a,SFX_THUD
        call play_sfx
.draw:  ld a,(tst_y)
        ld b,a
        ld a,(tst_x)
        ld c,a
        ld a,T_BOULDER
        jp tile_at
.lying: ld hl,tst_t
        dec (hl)
        ret nz
        ld a,(tst_y)
        ld b,a
        ld a,(tst_x)
        ld c,a
        call title_restore
        xor a
        ld (tst_state),a
        call random
        and 63
        add a,30
        ld (tst_t),a
        ret

; B = row, C = column: put the title picture's own 2 x 2 cells back
title_restore:
        ld d,0
.q:     ld a,d
        and 1
        add a,c
        cp COLS
        jr nc,.nx
        ld e,a
        ld a,d
        rrca
        and 1
        add a,b
        cp 22
        jr nc,.nx
        push bc
        push de
        add a,a
        ld l,a
        ld h,0
        ld bc,row40
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld d,0
        add hl,de               ; HL = cell offset
        ex de,hl
        ld hl,title_lo
        add hl,de
        ld a,(hl)
        ld hl,VIDEO
        add hl,de
        ld (hl),a
        push hl
        ld hl,title_hi
        add hl,de
        ld b,(hl)
        ld hl,title_col
        add hl,de
        ld c,(hl)
        pop hl
        ld a,LV_ATTR
        out (P_LV),a
        ld (hl),b
        ld a,LV_SCREEN
        out (P_LV),a
        ld a,h
        add a,8
        ld h,a
        ld (hl),c
        pop de
        pop bc
.nx:    inc d
        ld a,d
        cp 4
        jr nz,.q
        ret

; ---- the gravediggers' roll ----------------------------------------------
roll_page:
        call roll_draw
        ld hl,400
        call page_wait
        jp front_next

; draw the high-score table.  (hi_mark) = entry to pick out (or $FF)
roll_draw:
        call fe_clear
        ld hl,0
        ld (fe_hook),hl
        ld a,YELLOW
        ld (txt_col),a
        ld hl,t_roll
        ld b,2
        call print_c
        ld a,DGREY
        ld (txt_col),a
        ld hl,t_rollh
        ld b,5
        ld c,7
        call print
        ld ix,hibuf+10
        ld c,0
.e:     push bc
        ld a,c
        add a,a
        add a,7
        call row_addr
        ld de,7
        add hl,de
        ex de,hl
        pop bc
        push bc
        ld a,(hi_mark)
        cp c
        ld a,WHITE
        jr nz,.nm
        ld a,BGREEN
.nm:    ld (txt_col),a
        ld a,c
        add a,'1'
        call put_char
        ld a,' '
        call put_char
        ld a,' '
        call put_char
        push ix
        pop hl
        ld b,8
.n:     ld a,(hl)
        inc hl
        call put_char
        djnz .n
        ld a,' '
        call put_char
        ld a,' '
        call put_char
        ld a,(hl)
        inc hl
        call put_bcd
        ld a,(hl)
        inc hl
        call put_bcd
        ld a,(hl)
        inc hl
        call put_bcd
        ld a,'0'
        call put_char
        ld a,' '
        call put_char
        ld a,' '
        call put_char
        ld a,' '
        call put_char
        ld a,(hl)
        push de
        call bin2bcd
        ld a,l
        pop de
        call put_bcd
        ld de,HI_SZ
        add ix,de
        pop bc
        inc c
        ld a,c
        cp HI_N
        jr nz,.e
        ld a,GREY
        ld (txt_col),a
        ld hl,t_rollf
        ld b,24
        jp print_c
t_roll:  db "THE GRAVEDIGGERS' ROLL",0
t_rollh: db "   NAME       SCORE   CRYPT",0
t_rollf: db "SPACE: PLAY     RETURN: MORE",0

; ---- the demo ----------------------------------------------------------------
demo_start:
        ld a,(DEMOBUF)
        ld hl,(ncaves)
        ld b,a
        ld a,h
        or a
        jr nz,.ok
        ld a,b
        cp l
        jp nc,front_next        ; no recording (or not for this caves file)
.ok:    ld a,b
        ld (start_cave),a
        ld hl,DEMOBUF+1
        ld (demo_ptr),hl
        xor a
        ld (demo_left),a
        ld (demo_pad),a
        ld (demo_end),a
        inc a
        ld (demo_on),a
        call stop_music
        jp new_game

; the next step's keys from the recording: pairs of (pad, steps), 0 steps ends
demo_next:
        xor a
        ld (tick_new),a
        ld a,(demo_left)
        or a
        jr nz,.use
        ld hl,(demo_ptr)
        ld c,(hl)
        inc hl
        ld a,(hl)
        inc hl
        or a
        jr nz,.more
        ld a,1
        ld (demo_end),a
        dec hl
        dec hl
        ld c,0
        ld a,255
.more:  ld (demo_ptr),hl
        ld (demo_left),a
        ld a,(demo_pad)
        cpl
        and c
        ld (tick_new),a
        ld a,c
        ld (demo_pad),a
.use:   ld hl,demo_left
        dec (hl)
        ld a,(demo_pad)
        ld (tick_pad),a
        ret

; ---- the end of a game -------------------------------------------------------
game_quit:
        ld a,(demo_on)
        or a
        jr z,game_over
        xor a
        ld (demo_on),a
        ld (start_cave),a
        ld (fe_page),a
        jp front_next

game_won:
        ld hl,score+1           ; 10,000 points for getting out
        ld a,(hl)
        add a,$10
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld hl,won_page
        call text_page
        ld hl,mus_won_0
        ld de,mus_won_1
        call play_music
        jr go_score
game_over:
        ld sp,STACK
        ld hl,over_page
        call text_page
        ld hl,mus_over_0
        ld de,mus_over_1
        call play_music
go_score:
        ld a,WHITE
        ld (txt_col),a
        ld a,14
        call row_addr
        ld de,11
        add hl,de
        ex de,hl
        ld hl,t_score
.s:     ld a,(hl)
        or a
        jr z,.sd
        inc hl
        call put_char
        jr .s
.sd:    ld a,YELLOW
        ld (txt_col),a
        ld a,(score)
        call put_bcd
        ld a,(score+1)
        call put_bcd
        ld a,(score+2)
        call put_bcd
        ld a,'0'
        call put_char
        ld b,110
.w:     push bc
        call fe_frame
        pop bc
        djnz .w
        xor a
        ld (padnew),a
        ld (keysnew),a
        ld (start_cave),a
        call hi_place
        ld a,$FF
        ld (hi_mark),a
        jr c,.show              ; not on the roll
        ld a,c
        ld (hi_mark),a
        call name_entry
        call hi_save
        ld (hi_state),a
        jr .st
.show:  xor a
        ld (hi_state),a
        ld a,(hi_dirty)
        or a
        jr z,.st
        call hi_save            ; the furthest crypt may have moved on
.st:    call roll_draw
        ld a,(hi_mark)
        inc a
        jr z,.nomsg
        ld a,(hi_state)
        or a
        ld hl,t_saved
        ld c,BGREEN
        jr z,.m
        dec a
        ld hl,t_prot
        ld c,BRED
        jr z,.m
        ld hl,t_nosave
.m:     ld a,c
        ld (txt_col),a
        ld b,23
        call print_c
.nomsg: ld a,$FF
        ld (hi_mark),a
        call keys_up            ; (the RETURN that ended the name is not "next page")
        ld hl,300
        call page_wait
        xor a
        ld (fe_page),a
        jp front_next

over_page:
        db 8,255,BRED,"MORT IS NO MORE",0
        db 10,255,GREY,"THE CASTLE KEEPS ITS TREASURE",0
        db $FE,4,19,T_GHOST
        db $FF
won_page:
        db 6,255,YELLOW,"YOU HAVE ESCAPED",0
        db 8,255,YELLOW,"CASTLE CRYPTFALL!",0
        db 10,255,WHITE,"EVERY CRYPT IS CLEARED",0
        db 12,255,BGREEN,"10,000 POINTS FOR GETTING OUT ALIVE",0
        db $FE,3,17,T_GEM
        db $FE,3,19,T_PLAYER
        db $FE,3,21,T_GEM
        db $FF
t_score:  db "YOUR SCORE  ",0
t_saved:  db "THE ROLL IS SAVED ON THE DISK",0
t_prot:   db "DISK WRITE-PROTECTED: ROLL NOT SAVED",0
t_nosave: db "THE ROLL COULD NOT BE SAVED",0

; where does (score) go on the roll?  -> C = entry and the table opened up
; for it (name blank), or carry if it is not high enough
hi_place:
        ld ix,hibuf+10
        ld c,0
.e:     ld a,(score)
        cp (ix+8)
        jr c,.nx
        jr nz,.in
        ld a,(score+1)
        cp (ix+9)
        jr c,.nx
        jr nz,.in
        ld a,(score+2)
        cp (ix+10)
        jr c,.nx
        jr z,.nx
.in:    ; shift the entries from C down one
        ld a,HI_N-1
        sub c
        jr z,.put
        ld b,a                  ; entries to move
        ld hl,hibuf+10+(HI_N-1)*HI_SZ-1
        ld de,hibuf+10+HI_N*HI_SZ-1
.sh:    push bc
        ld bc,HI_SZ
        lddr
        pop bc
        djnz .sh
.put:   push ix
        pop hl
        ld b,8
.b:     ld (hl),' '
        inc hl
        djnz .b
        ld a,(score)
        ld (hl),a
        inc hl
        ld a,(score+1)
        ld (hl),a
        inc hl
        ld a,(score+2)
        ld (hl),a
        inc hl
        ld a,(cave_no)
        inc a
        ld b,a
        ld a,(ncaves)
        cp b
        jr nc,.cv
        ld b,a
.cv:    ld (hl),b
        or a
        ret
.nx:    ld de,HI_SZ
        add ix,de
        inc c
        ld a,c
        cp HI_N
        jr nz,.e
        scf
        ret

; type a name (up to 8 letters) into roll entry (hi_mark)
name_entry:
        call roll_draw
        ld a,BCYAN
        ld (txt_col),a
        ld hl,t_name
        ld b,23
        call print_c
        ld hl,mus_hi_0
        ld de,mus_hi_1
        call play_music
        xor a
        ld (ne_len),a
        ld a,1
        ld (ne_last),a          ; wait for the keys to be let go first
.f:     call fe_frame
        call any_key
        ld hl,ne_last
        cp (hl)
        jr z,.cur
        ld (hl),a
        or a
        jr z,.cur
        dec a                   ; key code
        cp K_RET
        jp z,.done
        cp K_BS
        jr z,.bs
        ld b,' '
        cp K_SPACE
        jr z,.ch
        cp 27
        jr nc,.dig
        or a
        jr z,.cur
        add a,'A'-1
        ld b,a
        jr .ch
.dig:   cp $20
        jr c,.cur
        cp $2A
        jr nc,.cur
        add a,'0'-$20
        ld b,a
.ch:    ld a,(ne_len)
        cp 8
        jr nc,.cur
        ld e,a
        inc a
        ld (ne_len),a
        call .slot
        ld (hl),b
        ld a,SFX_MENU
        call play_sfx
        jr .cur
.bs:    ld a,(ne_len)
        or a
        jr z,.cur
        dec a
        ld (ne_len),a
        ld e,a
        call .slot
        ld (hl),' '
.cur:   ; show the name with a blinking cursor
        ld e,0
        call .slot
        ld de,msgbuf
        ld bc,8
        ldir
        xor a
        ld (de),a
        ld a,(framecount)
        and 8
        jr z,.nc
        ld a,(ne_len)
        cp 8
        jr nc,.nc
        ld e,a
        ld d,0
        ld hl,msgbuf
        add hl,de
        ld (hl),92              ; the cursor block
.nc:    ld a,BGREEN
        ld (txt_col),a
        ld a,(hi_mark)
        add a,a
        add a,7
        ld b,a
        ld c,10
        ld hl,msgbuf
        call print
        jp .f
.done:  ld a,(ne_len)
        or a
        jr nz,.ok
        ld e,0                  ; no name typed: MORT
        call .slot
        ex de,hl
        ld hl,t_mort
        ld bc,4
        ldir
.ok:    jp stop_music
; E = letter index -> HL = its place in the entry
.slot:  push de
        ld a,(hi_mark)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; x 12
        ld de,hibuf+10
        add hl,de
        pop de
        ld d,0
        add hl,de
        ret
t_name: db "TYPE YOUR NAME, THEN PRESS RETURN",0
t_mort: db "MORT"

; a new furthest crypt: note it and save it straight away
progress:
        ld a,(cave_no)
        ld b,a
        ld a,(ncaves)
        dec a
        cp b
        jr nc,.in
        ld b,a                  ; (past the last one: the last one)
.in:    ld a,(hibuf+8)
        cp b
        ret nc
        ld a,b
        ld (hibuf+8),a
        call hi_save
        or a
        ret z
        ld a,1
        ld (hi_dirty),a         ; could not save now: try again at the end
        ret

hi_init: INCLUDE "hidef.inc"
        INCLUDE "title.inc"
