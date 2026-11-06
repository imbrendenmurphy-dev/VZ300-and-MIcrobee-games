; =====================================================================
;  HAMBURGER SAM II - title, attract cycle, menu, kitchen cards,
;  Order Up! bonus round, ending, game over, Top Ten, records
; =====================================================================

attract:
        ld sp,STACKTOP
        xor a
        ld (mode),a
        ld (flashtim),a
        ld (playclassic),a
.cycle: call title_screen
        jr nz,.go
        call how_to_play
        jr nz,.go
        call meet_menu
        jr nz,.go
        call run_demo
        jr nz,.go
        call hiscore_screen
        jr nz,.go
        jr .cycle
.go:    ld sp,STACKTOP
        call stop_music
        jp main_menu

; ---------------------------------------------------------------------
; page helpers (from Tennis II)
; page: HL = big title (0 = none). Clears BG, rule under the title.
page:
        push hl
        ld a,MODE1
        ld (palbase),a
        call dl_reset
        call do_frame
        ld a,1
        ld (noq),a
        ld (texttrans),a        ; see-through text (the specks pass behind it)
        ld (specks_on),a
        ld de,$0000
        ld bc,$2040
        call tex_rect
        ld a,1
        ld b,0
        call set_ink
        pop hl
        ld a,h
        or l
        jr z,.n
        ld e,1
        call print2_c
.n:     ld a,$FF
        ld de,$000C
        ld bc,$2001
        call fill_rect
        xor a
        ld (noq),a
        ret
; text: HL string, D col, E row, A ink (on green)
text:
        push hl
        push de
        ld b,0
        call set_ink
        pop de
        pop hl
        jp print
; centred text: HL, E row, A ink
text_c:
        push hl
        push de
        ld b,0
        call set_ink
        pop de
        pop hl
        jp print_c
; list of lines: HL -> (db ink, row : dw string), terminated by $FF
text_list:
        ld a,(hl)
        cp $FF
        ret z
        ld b,a
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        ld a,b
        call text_c
        pop hl
        inc hl
        jr text_list
; wait up to BC frames (start aborts -> NZ); HL = per-frame hook or 0
page_wait:
        ld (infohook),hl
.l:     push bc
        call dl_reset
        ld hl,(infohook)
        ld a,h
        or l
        call nz,.call
        call speck_tick
        call do_frame
        pop bc
        call check_start
        ret nz
        ld a,(keysnew)
        and $20                 ; C: unlock the 1984 kitchen
        jr z,.nk
        push bc
        call unlock_classic
        pop bc
.nk:    dec bc
        ld a,b
        or c
        jr nz,.l
        ret
.call:  jp (hl)

unlock_classic:
        ld a,(classic)
        or a
        ret nz
        ld a,1
        ld (classic),a
        ld a,12
        ld (flashtim),a
        ld hl,mus_item_0
        ld de,mus_item_1
        call jingle
        call save_records
        xor a
        ret

; ---------------------------------------------------------------------
; TITLE: bubble logo, rotating messages, a chase along the counter
; ---------------------------------------------------------------------
title_screen:
        xor a
        ld (specks_on),a
        ld (cbexact),a
        ld a,MODE1
        ld (palbase),a
        call dl_reset
        call do_frame
        ld hl,title_pic
        ld de,BGBUF
        call unpack
        call wipe_show
        ld hl,mus_title_0
        ld de,mus_title_1
        call bgm
        xor a
        ld (tmsg),a
        ld (ch_t),a
        ld (ch_dir),a
        ld a,200
        ld (ch_x),a
        call title_msg
        ld hl,0
        ld (attr_t),hl
        ld a,8                  ; chase sprites + message: spread the commit
        ld (cbudget),a
.l:     call dl_reset
        call title_chase
        call do_frame
        call check_start
        jr nz,.out
        ld a,(keysnew)
        and $20
        call nz,unlock_classic
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld a,l
        and 127
        jr nz,.nm
        call title_msg
.nm:    ld hl,(attr_t)
        ld de,820
        or a
        sbc hl,de
        jr nz,.l
        ld a,28
        ld (cbudget),a
        call stop_music
        xor a
        ret
.out:   ld a,28
        ld (cbudget),a
        call stop_music
        or 1
        ret

title_msg:
        ld a,1
        ld (noq),a
        xor a
        ld de,TITLE_MSG_Y
        ld bc,$2005
        call fill_rect
        ld a,(tmsg)
        ld hl,tmsgs
        call idx_word
        ld a,(tmsg)
        and 1
        ld a,1
        jr z,.c
        ld a,2
.c:     ld e,TITLE_MSG_Y
        call text_c
        xor a
        ld (noq),a
        ld d,0                  ; queue it as narrow strips (light per-frame commits)
.q:     push de
        ld e,TITLE_MSG_Y
        ld bc,$0405
        call queue_rect
        pop de
        ld a,d
        add a,4
        ld d,a
        cp 32
        jr nz,.q
        ld a,(tmsg)
        inc a
        cp NTMSG
        jr c,.s
        xor a
.s:     ld (tmsg),a
        ret
NTMSG   equ 7
tmsgs:  dw tm0,tm1,tm2,tm3,tm4,tm5,tm6
tm0:    db "PRESS FIRE TO PLAY",0
tm1:    db "THE SEQUEL TO HAMBURGER SAM",0
tm2:    db "8 KITCHENS - 1 BIG ORDER",0
tm3:    db "PRESS FIRE TO PLAY",0
tm4:    db "WATCH OUT FOR MR CHILLI!",0
tm5:    db "KEYS OR JOYSTICK",0
tm6:    db "(C) 2026 VIBED BY BPM",0

; Sam legs it with the gang behind him, then turns the tables with pepper
title_chase:
        ld a,(ch_x)
        ld b,a
        ld a,(ch_dir)
        or a
        jr nz,.right
        dec b
        ld a,b
        ld (ch_x),a
        cp 10
        jr nz,.d
        ld a,1
        ld (ch_dir),a
        jr .d
.right: inc b
        ld a,b
        ld (ch_x),a
        cp 250
        jr nz,.d
        xor a
        ld (ch_dir),a
.d:     ld a,(framecount)
        and 4
        rrca
        ld (tmpb),a             ; 0 / 2 walk frame
        ld a,(ch_dir)
        or a
        jr nz,.r2
        ; leftwards: Sam first, chasers behind (to his right)
        ld a,(tmpb)
        add a,SPR_SAM_A_L
        ld c,0
        call .put
        ld a,(tmpb)
        add a,SPR_HOTDOG_A_L
        ld c,16
        call .put
        ld a,(tmpb)
        add a,SPR_EGG_A_L
        ld c,28
        call .put
        ld a,(tmpb)
        add a,SPR_PICKLE_A_L
        ld c,40
        jr .put
.r2:    ; rightwards: the gang flees, Sam peppers them
        ld a,SPR_HOTDOG_STUN
        ld c,52
        call .put
        ld a,SPR_EGG_STUN
        ld c,40
        call .put
        ld a,SPR_CHILLI_STUN
        ld c,28
        call .put
        ld a,SPR_SAM_THROW
        ld c,10
.put:   ; A = sprite, C = offset; screen x = ch_x - 64 + offset (skip if off screen)
        ld e,a
        ld a,(ch_x)
        add a,c
        sub 64
        ret c
        cp 120
        ret nc
        ld b,a
        ld c,TITLE_RUN_Y-7
        ld a,e
        jp spr_put

; ---------------------------------------------------------------------
; HOW TO PLAY (2 pages)
; ---------------------------------------------------------------------
how_to_play:
        ld hl,s_how
        call page
        ld hl,how1
        call text_list
        call wipe_show
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        ld bc,330
        ld hl,0
        call page_wait
        jr nz,.x
        ld hl,s_ctl
        call page
        ld hl,how2
        call text_list
        call wipe_show
        ld bc,330
        ld hl,0
        call page_wait
.x:     push af
        call stop_music
        pop af
        ret
s_how:  db "HOW TO COOK",0
s_ctl:  db "CONTROLS",0
how1:   db 1,15 : dw h1a
        db 1,21 : dw h1b
        db 1,27 : dw h1c
        db 3,35 : dw h1d
        db 3,41 : dw h1e
        db 2,49 : dw h1f
        db 2,55 : dw h1g
        db $FF
h1a:    db "WALK OVER EVERY INGREDIENT",0
h1b:    db "TO DROP IT A FLOOR. BUILD",0
h1c:    db "EVERY BURGER ON ITS PLATE!",0
h1d:    db "DROP FOOD ON THE CHASERS,",0
h1e:    db "OR GIVE THEM A RIDE DOWN!",0
h1f:    db "PEPPER STUNS THEM. COFFEE",0
h1g:    db "GIVES YOU MORE PEPPER.",0
how2:   db 1,16 : dw h2a
        db 1,22 : dw h2b
        db 1,28 : dw h2c
        db 3,36 : dw h2d
        db 3,42 : dw h2e
        db 2,50 : dw h2f
        db 2,56 : dw h2g
        db $FF
h2a:    db "M , OR JOYSTICK - WALK",0
h2b:    db "Q A OR JOYSTICK - CLIMB",0
h2c:    db "SPACE SHIFT FIRE - PEPPER",0
h2d:    db "P PAUSE   S SOUND",0
h2e:    db "X QUITS WHILE PAUSED",0
h2f:    db "EXTRA COOK EVERY 10000",0
h2g:    db "BONUS ROUND EVERY 2 KITCHENS",0

; ---------------------------------------------------------------------
; MEET THE MENU: the chasers and the goodies
; ---------------------------------------------------------------------
meet_menu:
        ld hl,s_meet
        call page
        ld hl,meet_t
        call .rows
        xor a
        ld (framecount),a
        call meet_anim
        call wipe_show
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        ld bc,330
        ld hl,meet_anim
        call page_wait
        jr nz,.x
        ld hl,s_good
        call page
        ld hl,good_t
        call .rows
        xor a
        ld (framecount),a
        call good_anim
        call wipe_show
        ld bc,300
        ld hl,good_anim
        call page_wait
.x:     push af
        call stop_music
        pop af
        ret
.rows:  ; HL -> 4 x (dw name, dw desc), rows 15, 27, 39, 51
        ld e,15
        ld b,4
.r:     push bc
        push de
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        ld d,6
        ld a,1
        push de
        call text
        pop de
        pop hl
        inc hl
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        ld a,e
        add a,6
        ld e,a
        ld d,6
        ld a,3
        call text
        pop hl
        inc hl
        pop de
        ld a,e
        add a,12
        ld e,a
        pop bc
        djnz .r
        ret
s_meet: db "MEET THE MENU",0
s_good: db "GOODIES",0
meet_t: dw mn0,md0,mn1,md1,mn2,md2,mn3,md3
mn0:    db "MR HOT DOG",0
md0:    db "A SAUSAGE WITH A GRUDGE",0
mn1:    db "MR EGG",0
md1:    db "SUNNY SIDE UP, MEAN INSIDE",0
mn2:    db "MR PICKLE",0
md2:    db "SOUR, SNEAKY AND QUICK",0
mn3:    db "MR CHILLI - NEW!",0
md3:    db "TOO HOT TO HANDLE. FAST!",0
good_t: dw gn0,gd0,gn1,gd1,gn2,gd2,gn3,gd3
gn0:    db "COFFEE",0
gd0:    db "+1 PEPPER AND 200",0
gn1:    db "FRIES",0
gd1:    db "500 POINTS",0
gn2:    db "ICE CREAM",0
gd2:    db "1000 POINTS",0
gn3:    db "GOLDEN SPATULA - NEW!",0
gd3:    db "STUNS THE LOT! 1500",0
meet_anim:
        ld a,(framecount)       ; repaint the walkers every 8 frames (no sprites)
        and 7
        ret nz
        ld a,(framecount)
        and 8
        rrca
        rrca
        ld b,a                  ; 0 / 2: walk frame
        ld a,SPR_HOTDOG_A
        add a,b
        ld c,6                  ; step between characters
        jr paint4
good_anim:
        ld a,(framecount)
        and 63
        ret nz                  ; static: paint once in a while (first frame paints)
        ld a,SPR_COFFEE
        ld c,1
; paint4: A = first sprite id, C = id step -> four icons at col 2, rows 13/25/37/49
paint4:
        ld (tmpa),a
        ld a,c
        ld (tmpb),a
        ld e,13
        ld b,4
.l:     push bc
        push de
        ld d,2
        ld bc,$0308
        push de
        call tex_rect
        pop de
        ld a,(tmpa)
        call bg_icon
        pop de
        ld a,e
        add a,12
        ld e,a
        ld a,(tmpb)
        ld b,a
        ld a,(tmpa)
        add a,b
        ld (tmpa),a
        pop bc
        djnz .l
        ret
; bg_icon: A = sprite id, D = col, E = row -> paint unshifted into BG (queued by caller)
bg_icon:
        push iy
        ld iy,bgtmp
        ld (iy+1),a
        ld (iy+2),d
        ld (iy+3),e
        call bgobj_paint
        pop iy
        ret
; ---------------------------------------------------------------------
; DEMO: the autopilot cooks a random kitchen
; ---------------------------------------------------------------------
run_demo:
        ld a,2
        ld (mode),a
        xor a
        ld (playclassic),a
        ld (lap),a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld b,4
        call rand_n
        ld (kitchen),a
        ld a,1
        ld (lives),a
        ld a,9
        ld (peppers),a
        ld hl,1600
        ld (gtim),hl
        call play_kitchen
        ld b,a
        xor a
        ld (mode),a
        ld a,b
        cp R_START
        jr z,.go
        xor a
        ret
.go:    or 1
        ret

; ---------------------------------------------------------------------
; TOP TEN (5-letter names, like the 1984 original)
; ---------------------------------------------------------------------
hiscore_screen:
        ld hl,s_top
        call page
        call draw_hitab
        call wipe_show
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        ld bc,400
        ld hl,0
        call page_wait
        push af
        call stop_music
        pop af
        ret
s_top:  db "TOP TEN COOKS",0

draw_hitab:
        ld ix,hitab
        xor a
        ld (hrow),a
.l:     ld a,(hrow)
        or a
        ld a,3
        jr z,.c
        ld a,(hrow)
        and 1
        ld a,1
        jr z,.c
        ld a,2
.c:     ld b,0
        call set_ink
        ld a,(hrow)
        ld b,a
        add a,a
        add a,a
        add a,b                 ; *5
        add a,14
        ld (hy),a
        ld a,(hrow)
        inc a
        cp 10
        jr c,.r1
        ld a,'1'
        ld (nameb),a
        ld a,'0'
        ld (nameb+1),a
        jr .r2
.r1:    add a,'0'
        ld (nameb+1),a
        ld a,' '
        ld (nameb),a
.r2:    ld a,'.'
        ld (nameb+2),a
        xor a
        ld (nameb+3),a
        ld hl,nameb
        ld a,(hy)
        ld e,a
        ld d,7
        call print
        ld b,5
        push ix
        pop hl
        inc hl
        inc hl
        inc hl
        ld de,nameb
.cp:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .cp
        xor a
        ld (de),a
        ld hl,nameb
        ld a,(hy)
        ld e,a
        ld d,11
        call print
        push ix
        pop hl
        ld b,3
        ld a,(hy)
        ld e,a
        ld d,18
        call print_bcd
        ld de,8
        add ix,de
        ld a,(hrow)
        inc a
        ld (hrow),a
        cp HIT_N
        jp nz,.l
        ret

; new entry for (score)?
enter_hiscore:
        ld ix,hitab
        ld c,0
.f:     push ix
        pop hl
        ld de,score
        ld b,3
.cmp:   ld a,(de)
        cp (hl)
        jr c,.lower
        jr nz,.found
        inc hl
        inc de
        djnz .cmp
.lower: ld de,8
        add ix,de
        inc c
        ld a,c
        cp HIT_N
        jr nz,.f
        ret
.found: ld a,HIT_N-1
        sub c
        jr z,.noshift
        ld b,a
        ld hl,hitab+(HIT_N-1)*8-1
        ld de,hitab+HIT_N*8-1
.sh:    push bc
        ld bc,8
        lddr
        pop bc
        djnz .sh
.noshift:
        ld (hiptr),ix
        ld hl,score
        push ix
        pop de
        ld bc,3
        ldir
        ld hl,nameb
        ld b,5
.ia:    ld (hl),' '
        inc hl
        djnz .ia
        ld a,'A'
        ld (nameb),a
        xor a
        ld (nameb+5),a
        ld hl,s_nhs
        call page
        ld hl,s_ent
        ld e,17
        ld a,1
        call text_c
        ld hl,s_ent2
        ld e,52
        ld a,2
        call text_c
        ld hl,s_ent3
        ld e,58
        ld a,2
        call text_c
        ld hl,score
        ld b,3
        ld de,$0D2A
        call print_bcd
        call wipe_show
        ld hl,mus_hiscore_0
        ld de,mus_hiscore_1
        call jingle
        xor a
        ld (hpos),a
        ld hl,1800
        ld (attr_t),hl
.loop:  call dl_reset
        ld a,1
        ld (noq),a
        ld de,$0B1E
        ld bc,$0A0A
        call tex_rect
        xor a
        ld (noq),a
        ld a,3
        ld b,0
        call set_ink
        ld hl,nameb
        ld de,$0B1E
        call print2
        ld a,(framecount)
        and 8
        jr z,.nc
        ld a,(hpos)
        add a,a
        add a,11
        add a,a
        add a,a
        ld b,a
        ld c,24
        ld a,SPR_ARROW
        call spr_put
.nc:    ld a,(inpnew)
        ld c,a
        ld a,(hpos)
        ld e,a
        ld d,0
        ld hl,nameb
        add hl,de
        bit 2,c
        jr z,.nu
        ld a,(hl)
        call next_letter
        ld (hl),a
        ld a,SFX_TICK
        call play_sfx
.nu:    bit 3,c
        jr z,.nd
        ld a,(hl)
        call prev_letter
        ld (hl),a
        ld a,SFX_TICK
        call play_sfx
.nd:    bit 1,c
        jr z,.nl
        ld a,(hpos)
        or a
        jr z,.nl
        dec a
        ld (hpos),a
.nl:    ld a,c
        and $11
        jr z,.nr
        ld a,SFX_BLIP
        call play_sfx
        ld a,(hpos)
        inc a
        ld (hpos),a
        cp 5
        jr z,.done
        ld e,a
        ld d,0
        ld hl,nameb
        add hl,de
        ld a,(hl)
        cp ' '
        jr nz,.nr
        dec hl
        ld a,(hl)
        inc hl
        ld (hl),a               ; new slot starts on the previous letter
.nr:    ld a,(keysnew)
        and 4
        jr nz,.done
        call speck_tick
        call do_frame
        ld hl,(attr_t)
        dec hl
        ld (attr_t),hl
        ld a,h
        or l
        jp nz,.loop
.done:  ld de,(hiptr)
        inc de
        inc de
        inc de
        ld hl,nameb
        ld bc,5
        ldir
        call stop_music
        call save_records
        jp hiscore_screen
next_letter:
        cp 'Z'
        jr z,.sp
        cp ' '
        jr z,.a
        inc a
        ret
.sp:    ld a,' '
        ret
.a:     ld a,'A'
        ret
prev_letter:
        cp 'A'
        jr z,.sp
        cp ' '
        jr z,.z
        dec a
        ret
.sp:    ld a,' '
        ret
.z:     ld a,'Z'
        ret
s_nhs:  db "TOP COOK!",0
s_ent:  db "ENTER YOUR NAME",0
s_ent2: db "UP/DOWN LETTER, FIRE NEXT",0
s_ent3: db "RETURN WHEN DONE",0

; ---------------------------------------------------------------------
; MAIN MENU
; ---------------------------------------------------------------------
MENU_N  equ 4
main_menu:
        ld sp,STACKTOP
        xor a
        ld (mode),a
        ld (menusel),a
        ld a,1
        ld (startkit),a
        ld hl,s_menu
        call page
        call menu_draw
        call wipe_show
        ld hl,mus_info_0
        ld de,mus_info_1
        call bgm
        ld hl,1500
        ld (attr_t),hl
.l:     call dl_reset
        ; Sam points at the selected line
        ld a,(menusel)
        ld b,a
        add a,a
        add a,b
        add a,a
        add a,a                 ; *12
        add a,15
        ld c,a
        ld a,(framecount)
        and 16
        rrca
        rrca
        rrca
        add a,4
        ld b,a
        ld a,SPR_SAM_A
        call spr_put
        call speck_tick
        call do_frame
        ld a,(keysnew)
        and $20
        jr z,.nc
        call unlock_classic
        call menu_draw
.nc:    ld a,(inpnew)
        ld c,a
        or a
        jr z,.ni
        ld hl,1500
        ld (attr_t),hl
.ni:    bit 2,c
        jr z,.nu
        ld a,(menusel)
        or a
        jr z,.nu
        dec a
        ld (menusel),a
        ld a,SFX_BLIP
        call play_sfx
.nu:    bit 3,c
        jr z,.nd
        ld a,(menusel)
        cp MENU_N-1
        jr z,.nd
        inc a
        ld (menusel),a
        ld a,SFX_BLIP
        call play_sfx
.nd:    ld a,c
        and 3
        jr z,.nlr
        call menu_change
        call menu_draw
.nlr:   ld a,(keysnew)
        bit 0,a
        jr z,.ns
        call menu_sound
        call menu_draw
.ns:    call check_start
        jr nz,.go
        ld hl,(attr_t)
        dec hl
        ld (attr_t),hl
        ld a,h
        or l
        jp nz,.l
        call stop_music
        jp attract
.go:    ld a,SFX_SELECT
        call play_sfx
        ld a,(menusel)
        cp 3
        jr nz,.g1
        call menu_sound
        call menu_draw
        jp .l
.g1:    cp 2
        jr nz,.g2
        ld a,(classic)
        or a
        jp z,.l
        call stop_music
        ld a,1
        ld (playclassic),a
        xor a
        jp start_game
.g2:    call stop_music
        xor a
        ld (playclassic),a
        ld a,(menusel)
        or a
        ld a,0
        jp z,start_game
        ld a,(startkit)
        dec a
        jp start_game

menu_change:    ; left / right on a line
        ld a,(menusel)
        cp 1
        jr nz,.s
        ld a,c
        and 1
        ld a,(startkit)
        jr z,.dn
        inc a
        ld hl,maxkit
        cp (hl)
        jr c,.k
        jr z,.k
        ld a,(hl)
        jr .k
.dn:    dec a
        jr nz,.k
        inc a
.k:     ld (startkit),a
        ld a,SFX_TICK
        jp play_sfx
.s:     cp 3
        ret nz
menu_sound:
        ld a,(soundmode)
        dec a
        jp p,.s
        ld a,2
.s:     ld (soundmode),a
        call save_records
        ld a,(soundmode)
        cp 2
        jp nz,stop_music
        ld hl,mus_info_0
        ld de,mus_info_1
        jp bgm

menu_draw:
        ld a,1
        ld (noq),a              ; one queued rect for the lot (below)
        ld de,$040E
        ld bc,$1C30
        call tex_rect
        ld a,1
        ld hl,mi0
        ld de,$0610
        call text
        ld a,1
        ld hl,mi1
        ld de,$061C
        call text
        ld a,(startkit)
        add a,'0'
        ld (nameb),a
        xor a
        ld (nameb+1),a
        ld a,3
        ld hl,nameb
        ld de,$171C
        call text
        ld a,(classic)
        or a
        ld hl,mi2b
        ld a,2
        jr z,.c
        ld hl,mi2
        ld a,1
.c:     ld de,$0628
        call text
        ld a,1
        ld hl,mi3
        ld de,$0634
        call text
        ld a,(soundmode)
        ld hl,sndnames
        call idx_word
        ld a,3
        ld de,$1034
        call text
        ld a,2
        ld hl,mhelp
        ld e,59
        call text_c
        xor a
        ld (noq),a
        ld de,$040E
        ld bc,$1C32
        jp queue_rect
s_menu: db "MAIN MENU",0
mi0:    db "PLAY FROM KITCHEN 1",0
mi1:    db "START AT KITCHEN",0
mi2:    db "PLAY CLASSIC 1984",0
mi2b:   db "CLASSIC 1984 - LOCKED",0
mi3:    db "SOUND:",0
sndnames: dw sn0,sn1,sn2
sn0:    db "OFF          ",0
sn1:    db "EFFECTS ONLY ",0
sn2:    db "MUSIC + SFX  ",0
mhelp:  db "UP/DOWN, LEFT/RIGHT, FIRE",0

; ---------------------------------------------------------------------
; kitchen card before each kitchen
; ---------------------------------------------------------------------
kitchen_card:
        ld hl,0
        call page
        ld a,(playclassic)
        or a
        jr z,.k
        ld hl,s_classic
        ld e,16
        ld a,1
        ld b,0
        call set_ink
        call print2_c
        ld hl,s_cl2
        ld e,32
        ld a,3
        call text_c
        jr .rd
.k:     ld a,1
        ld b,0
        call set_ink
        ld hl,s_kit
        ld de,$0610
        call print2
        ld a,(kitchen)
        add a,'1'
        ld (nameb),a
        xor a
        ld (nameb+1),a
        ld a,3
        ld b,0
        call set_ink
        ld hl,nameb
        ld de,$1810
        call print2
        ld a,(kitchen)
        ld hl,lvtab
        call idx_word
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,32
        ld a,3
        call text_c
.rd:    ld a,(lap)
        or a
        jr z,.nl
        ld hl,s_lap
        ld e,40
        ld a,2
        call text_c
.nl:    ld hl,s_ready
        ld e,50
        ld a,1
        call text_c
        ; lives and pepper
        ld a,2
        ld hl,s_cooks
        ld de,$0602
        call text
        ld a,(lives)
        add a,'0'
        ld (s_cn),a
        ld a,(peppers)
        add a,'0'
        ld (s_pn),a
        ld a,1
        ld hl,s_cn
        ld de,$0702
        call text
        ld a,1
        ld hl,s_pn
        ld de,$1202
        call text
        call wipe_show
        ld hl,mus_start_0
        ld de,mus_start_1
        call jingle
        ld bc,110
        ld hl,card_anim
        jp page_wait
card_anim:
        ld a,(framecount)
        and 8
        rrca
        rrca
        add a,SPR_SAM_A
        ld bc,$3A37
        jp spr_put
s_kit:  db "KITCHEN",0
s_classic: db "CLASSIC",0
s_cl2:  db "THE 1984 KITCHEN",0
s_lap:  db "LAP 2 - THEY'RE FASTER!",0
s_ready: db "GET READY, SAM!",0
s_cooks: db "[  COOKS   ]  PEPPER",0
s_cn:   db "0",0
s_pn:   db "0",0

; ---------------------------------------------------------------------
; game over: "ALL COOKS DEAD", as the 1984 original put it
; ---------------------------------------------------------------------
game_over:
        ld hl,s_over
        call page
        ld hl,s_dead
        ld e,20
        ld a,3
        call text_c
        ld hl,s_yscore
        ld e,34
        ld a,1
        call text_c
        ld a,1
        ld b,0
        call set_ink
        ld hl,score
        ld b,3
        ld de,$0A2A
        call print_bcd2
        call wipe_show
        ld hl,mus_over_0
        ld de,mus_over_1
        call jingle
        ld bc,250
        ld hl,over_anim
        call page_wait
        jp stop_music
over_anim:
        ld a,SPR_SAM_DIZZY
        ld bc,$3A36
        jp spr_put
s_over: db "GAME OVER",0
s_dead: db "ALL COOKS DEAD",0
s_yscore: db "YOUR SCORE WAS",0

; print_bcd2: HL BCD, B bytes, D/E -> big digits
print_bcd2:
        ld de,nameb
        ld c,b
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
        dec c
        jr nz,.l
        xor a
        ld (de),a
        ld hl,nameb
        ld e,$2A
        jp print2_c

; ---------------------------------------------------------------------
; ORDER UP! bonus round: catch the layers in order on Sam's plate
; ---------------------------------------------------------------------
OU_PIECES equ 24
order_up:
        xor a
        ld (specks_on),a
        ld (cbexact),a
        ld a,MODE1
        ld (palbase),a
        call dl_reset
        call do_frame
        ld a,1
        ld (noq),a
        ld (texttrans),a
        ld de,$0000
        ld bc,$2040
        call tex_rect
        ld a,1
        ld b,0
        call set_ink
        ld hl,s_ou
        ld de,$0000
        call print
        ld a,$55                ; counter
        ld de,$0038
        ld bc,$1801
        call fill_rect
        ld a,$AA                ; ticket panel edge
        ld de,$1806
        ld bc,$0139
        call fill_rect
        ld a,3
        ld b,0
        call set_ink
        ld hl,s_tick
        ld de,$1A18
        call print
        ld hl,s_next
        ld de,$1A08
        call print
        xor a
        ld (noq),a
        ; STATBG = this backdrop
        ld hl,BGBUF
        ld de,STATBG
        ld bc,2048
        ldir
        xor a
        ld (ou_want),a
        ld (ou_on),a
        ld (ou_orders),a
        ld (pop_tim),a
        ld (pop_w),a
        ld (npc),a
        ld (sst),a
        ld hl,0
        ld (ou_score),hl
        ld a,OU_PIECES
        ld (ou_n),a
        ld a,44
        ld (sx),a
        ld a,55
        ld (sy),a
        ld a,30
        ld (ou_delay),a
        ld a,2
        ld (ou_spd),a
        call ou_next_icon
        call ou_hud
        call wipe_show
        ld hl,mus_order_0
        ld de,mus_order_1
        call jingle
        ld bc,60
        ld hl,0
        call page_wait
        ld hl,mus_bonus_0
        ld de,mus_bonus_1
        call bgm
.loop:  call dl_reset
        ; move Sam (fast, plate held high)
        ld a,(inp)
        ld c,a
        ld a,(autoplay)
        or a
        call nz,ou_ai
        ld a,(framecount)       ; 4 px every other frame (plate pose is byte-aligned)
        and 1
        jr nz,.nl0
        ld a,(sx)
        bit 0,c
        jr z,.nr
        cp 88
        jr nc,.nr
        add a,4
.nr:    bit 1,c
        jr z,.nl
        cp 4
        jr c,.nl
        sub 4
.nl:    ld (sx),a
.nl0:
        call ou_piece
        ; draw
        ld a,(sx)
        ld b,a
        ld c,48
        ld a,SPR_SAM_PLATE
        call spr_put
        call pop_tick
.np:    call do_frame
        ld a,(ou_n)
        or a
        jr nz,.loop
        ld a,(ou_on)
        or a
        jr nz,.loop
        ; tally
        call stop_music
        call pop_remove
        ld bc,40
        ld hl,0
        call page_wait
        ld hl,s_ou2
        call page
        ld hl,s_filled
        ld e,20
        ld a,1
        call text_c
        ld a,(ou_orders)
        add a,'0'
        ld (nameb),a
        xor a
        ld (nameb+1),a
        ld a,3
        ld b,0
        call set_ink
        ld hl,nameb
        ld e,28
        call print2_c
        ld hl,s_bonus
        ld e,44
        ld a,1
        call text_c
        ld a,(ou_score+1)
        ld (tmpx),a
        ld a,(ou_score)
        ld (tmpy),a
        ld a,2
        ld b,0
        call set_ink
        ld hl,tmpx
        ld b,2
        ld de,$0E33
        call print_bcd
        ld de,(ou_score)
        ld a,1
        ld (mode),a
        call add_score
        call wipe_show
        ld hl,mus_clear_0
        ld de,mus_clear_1
        call jingle
        ld bc,180
        ld hl,0
        jp page_wait
s_ou:   db "ORDER UP!  CATCH IN ORDER",0
s_ou2:  db "ORDER UP!",0
s_tick: db "ORDER",0
s_next: db "NEXT",0
s_filled: db "ORDERS FILLED",0
s_bonus: db "BONUS POINTS",0
ou_seq: db 5,3,2,1,0            ; bottom bun, meat, cheese, lettuce, top bun

; the falling layer (uses pieces[0] as its record)
ou_piece:
        ld ix,pieces
        ld a,(ou_on)
        or a
        jr nz,.fall
        ld a,(ou_delay)
        or a
        jr z,.new
        dec a
        ld (ou_delay),a
        ret
.new:   ld a,(ou_n)
        or a
        ret z
        dec a
        ld (ou_n),a
        ld b,21
        call rand_n
        add a,a
        add a,a
        ld (ix+PC_X),a
        ld (ix+PC_Y),7
        ld (ix+PC_PR),0
        ld b,100
        call rand_n
        cp 55
        jr nc,.rt
        ld a,(ou_want)
        ld hl,ou_seq
        call idx_byte
        jr .st
.rt:    ld b,6
        call rand_n
.st:    ld (ix+PC_T),a
        ld a,1
        ld (ou_on),a
        jp ou_hud
.fall:  ld a,(ix+PC_Y)
        ld (ix+PC_OY),a
        add a,(ix+PC_Y)         ; speed: ou_spd rows
        ld a,(ou_spd)
        add a,(ix+PC_Y)
        ld (ix+PC_Y),a
        ; caught?
        cp 46
        jp c,.draw
        ld a,(ix+PC_OY)
        cp 46
        jp nc,.miss
        ld a,(ix+PC_X)
        add a,8
        ld b,a
        ld a,(sx)
        add a,4
        sub b
        call absa
        cp 10
        jp nc,.draw
        ; caught it
        call ou_erase
        xor a
        ld (ou_on),a
        ld a,12
        ld (ou_delay),a
        ld a,(ou_want)
        ld hl,ou_seq
        call idx_byte
        cp (ix+PC_T)
        jr nz,.wrong
        ld a,SFX_CATCH
        call play_sfx
        call ou_stack_add
        ld de,$0200
        call ou_add
        ld e,P_200
        ld a,(ou_want)
        inc a
        ld (ou_want),a
        cp 5
        jr nz,.pop
        ; order complete!
        xor a
        ld (ou_want),a
        ld a,(ou_orders)
        inc a
        ld (ou_orders),a
        ld de,$1000
        call ou_add
        ld a,(ou_spd)
        cp 4
        jr nc,.sp
        inc a
        ld (ou_spd),a
.sp:    ld a,SFX_RIDE
        call play_sfx
        call ou_clear_ticket
        ld e,P_ORDER
.pop:   ld a,32                 ; fixed spot, clear of the ticket panel
        ld d,34
        call popup_at
        jp ou_next_icon
.wrong: ld a,SFX_WRONG
        call play_sfx
        ld e,P_WRONG
        ld a,32
        ld d,34
        jp popup_at
.miss:  ld a,(ix+PC_Y)
        cp 54
        jr c,.draw
        call ou_erase
        xor a
        ld (ou_on),a
        ld a,10
        ld (ou_delay),a
        ld a,SFX_SPLAT
        jp play_sfx
.draw:  ld a,(ix+PC_X)
        rrca
        rrca
        and $3F
        ld d,a
        ld e,(ix+PC_OY)
        ld a,(ix+PC_Y)
        sub e
        add a,2
        ld c,a
        ld b,4
        push de
        push bc
        call restore_rect
        call draw_piece
        pop bc
        pop de
        jp queue_rect
ou_erase:
        ld a,(ix+PC_X)
        rrca
        rrca
        and $3F
        ld d,a
        ld e,(ix+PC_OY)
        ld bc,$0406
        push de
        call restore_rect
        pop de
        ld bc,$0406
        jp queue_rect
ou_add:         ; DE = BCD to add to the bonus
        ld hl,ou_score
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        ret
; caught layer joins the ticket stack (x 104, rows 52 upward), into BG + STATBG
ou_stack_add:
        push ix
        ld a,(ix+PC_T)
        ld ix,pieces+PSIZE
        ld (ix+PC_T),a
        ld (ix+PC_X),104
        ld (ix+PC_PR),0
        ld a,(ou_want)
        add a,a
        ld b,a
        ld a,52
        sub b
        ld (ix+PC_Y),a
        call draw_piece
        ld a,(ix+PC_Y)
        ld e,a
        ld d,26
        ld bc,$0402
        push de
        push bc
        call bg_to_stat
        pop bc
        pop de
        call queue_rect
        pop ix
        ret
ou_clear_ticket:
        ld de,$1A2C
        ld bc,$040A
        call clear_both
        ret
; "next" icon: the wanted layer at x 104, row 34
ou_next_icon:
        push ix
        ld de,$1A0F
        ld bc,$0403
        call clear_both
        ld a,(ou_want)
        ld hl,ou_seq
        call idx_byte
        ld ix,pieces+2*PSIZE
        ld (ix+PC_T),a
        ld (ix+PC_X),104
        ld (ix+PC_Y),15
        ld (ix+PC_PR),0
        call draw_piece
        ld de,$1A0F
        ld bc,$0402
        push de
        push bc
        call bg_to_stat
        pop bc
        pop de
        call queue_rect
        pop ix
        ret
; clear_both: D col, E row, B w, C h -> zero in BG and STATBG, queued
clear_both:
        push de
        push bc
        ld a,1
        ld (noq),a
        call tex_rect
        xor a
        ld (noq),a
        pop bc
        pop de
        push de
        push bc
        call bg_to_stat
        pop bc
        pop de
        jp queue_rect
; bg_to_stat: D col, E row, B w, C h
bg_to_stat:
.r:     push bc
        push de
        ld a,e
        call bgrow
        ld a,l
        add a,d
        ld l,a
        ld e,l
        ld a,h
        sub 8
        ld d,a
        ld c,b
        ld b,0
        ldir
        pop de
        pop bc
        inc e
        dec c
        jr nz,.r
        ret
ou_hud:
        ld a,1
        ld (noq),a
        ld de,$1C00
        ld bc,$0205
        call tex_rect
        xor a
        ld (noq),a
        ld a,(ou_n)
        ld b,0
        ld c,a
        ld a,2
        ld b,0
        call set_ink
        ld a,(ou_n)
        ld b,0
.d:     cp 10
        jr c,.dd
        sub 10
        inc b
        jr .d
.dd:    add a,'0'
        ld (nameb+1),a
        ld a,b
        add a,'0'
        ld (nameb),a
        xor a
        ld (nameb+2),a
        ld hl,nameb
        ld de,$1C00
        jp print
; test autopilot for the bonus round
ou_ai:
        ld c,0
        ld a,(ou_on)
        or a
        ret z
        ld a,(pieces+PC_X)
        add a,4
        ld b,a
        ld a,(sx)
        cp b
        ret z
        ld c,1
        ret c
        ld c,2
        ret

; ---------------------------------------------------------------------
; ending after kitchen 8
; ---------------------------------------------------------------------
ending:
        ld hl,s_end
        call page
        ld hl,endt
        call text_list
        ld de,$1000
        call add_score
        ld de,$9000
        call add_score
        call wipe_show
        ld hl,mus_ending_0
        ld de,mus_ending_1
        call bgm
        ld bc,700
        ld hl,end_anim
        call page_wait
        jp stop_music
end_anim:
        ld a,(framecount)
        and 8
        ld a,SPR_SAM_CHEER
        jr z,.s
        ld a,SPR_SAM_FRONT
.s:     ld bc,$3A2A
        jp spr_put
s_end:  db "ORDER COMPLETE!",0
endt:   db 1,16 : dw e1
        db 1,22 : dw e2
        db 3,28 : dw e3
        db 2,50 : dw e4
        db 2,56 : dw e5
        db $FF
e1:     db "ALL 8 KITCHENS SERVED!",0
e2:     db "SAM'S BURGERS ARE THE TALK",0
e3:     db "OF THE TOWN! BONUS 10000",0
e4:     db "BUT THE CHASERS ARE BACK..",0
e5:     db "AND NOW THEY'RE FASTER!",0

; ---------------------------------------------------------------------
; Records in BennVenn SRAM bank 3 ($6740-$67BF, clear of Tennis II's
; block at $67C0): kept until power-off.  Saving is only enabled if a
; probe shows the bank switch really works (as in Tennis II / Penguin 2).
; ---------------------------------------------------------------------
REC_LEN equ 4+HIT_N*8+3
load_records:
        xor a
        ld (srok),a
        ld a,1
        out ($37),a             ; the DOS mapping the loader leaves (a no-op re-write)
        ld a,($67FF)
        ld (probe1),a
        ld a,3
        out ($37),a
        ld a,($67FF)
        ld (probe3),a
        ld a,(probe1)
        cpl
        ld ($67FF),a
        ld a,1
        out ($37),a
        ld a,($67FF)
        ld b,a
        ld a,(probe1)
        cp b
        jr nz,.restore          ; bank 1 changed: no banking here, undo
        ld a,3
        out ($37),a
        ld a,($67FF)
        ld b,a
        ld a,(probe1)
        cpl
        cp b
        jr nz,.nosram
        ld a,(probe3)
        ld ($67FF),a
        ld a,1
        ld (srok),a
        ld hl,SAVEADR
        ld de,recbuf
        ld bc,REC_LEN+1
        ldir
        ld a,1
        out ($37),a
        ld hl,recbuf
        ld de,rec_sig
        ld b,4
.sg:    ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .sg
        call rec_sum
        ld hl,recbuf+REC_LEN
        cp (hl)
        ret nz
        ld hl,recbuf+4
        ld de,hitab
        ld bc,HIT_N*8
        ldir
        ld a,(hl)
        cp 3
        jr nc,.s
        ld (soundmode),a
.s:     inc hl
        ld a,(hl)
        and 1
        ld (classic),a
        inc hl
        ld a,(hl)
        or a
        ret z
        cp NKITCHEN+1
        ret nc
        ld (maxkit),a
        ret
.restore:
        ld a,(probe1)
        ld ($67FF),a
.nosram:
        ld a,1
        out ($37),a
        ret
rec_sig: db "HS2R"
rec_sum:        ; A = sum of recbuf[0..REC_LEN-1]
        ld hl,recbuf
        ld b,REC_LEN
        xor a
.l:     add a,(hl)
        inc hl
        djnz .l
        ret
save_records:
        ld a,(srok)
        or a
        ret z
        ld hl,rec_sig
        ld de,recbuf
        ld bc,4
        ldir
        ld hl,hitab
        ld bc,HIT_N*8
        ldir
        ld a,(soundmode)
        ld (de),a
        inc de
        ld a,(classic)
        ld (de),a
        inc de
        ld a,(maxkit)
        ld (de),a
        call rec_sum
        ld (recbuf+REC_LEN),a
        ld a,3
        out ($37),a
        ld hl,recbuf
        ld de,SAVEADR
        ld bc,REC_LEN+1
        ldir
        ld a,1
        out ($37),a
        ret

; ---------------------------------------------------------------------
; speck_tick: the salt (yellow) and pepper (blue) planes drift past each
; other in a shaker rhythm - shake-shake-shake ... pause.  Specks are
; drawn as single pixels in vblank and slip behind anything already on
; the page.  Also sets the commit budget for the frame.
; ---------------------------------------------------------------------
speck_tick:
        ld a,(specks_on)
        or a
        ret z
        ; budget: what the sprites already listed leave over
        ld hl,(dlptr)
        ld de,drawlist
        or a
        sbc hl,de
        srl l
        srl l                   ; sprites listed
        ld a,l
        add a,a
        add a,l
        add a,a
        add a,a                 ; *12
        ld b,a
        ld a,20
        sub b
        jr c,.b0
        cp 4
        jr nc,.b1
.b0:    ld a,4
.b1:    ld (cbudget),a
        ld a,1
        ld (cbexact),a
        ; rhythm: three shakes of 8 frames, 2 apart, then a pause (64-frame bar)
        xor a
        ld (tmpx),a             ; x jitter
        ld a,(framecount)
        and 63
        cp 30
        jr nc,.still
        ld b,10
.m10:   sub b
        jr nc,.m10
        add a,b
        cp 8
        jr nc,.still
        ld a,(framecount)
        and 2
        dec a                   ; +1 / -1
        ld (tmpx),a
        ld a,(framecount)
        and 1
        jr nz,.still
        ld hl,salt_off
        inc (hl)
        ld hl,pep_off
        inc (hl)
.still: ld ix,spk_tab
        ld c,0
.l:     ld a,c
        cp SPK_N/2
        ld a,(tmpx)
        jr nc,.pep
        ; salt: drifts right, jiggles with the shake
        ld e,a
        ld a,(salt_off)
        add a,(ix+0)
        add a,e
        and 127
        ld b,a
        ld a,(ix+1)
        sub e
        ld d,1
        jr .put
.pep:   ; pepper: drifts left, jiggles the other way
        ld e,a
        ld a,(pep_off)
        ld d,a
        ld a,(ix+0)
        sub d
        sub e
        and 127
        ld b,a
        ld a,(ix+1)
        add a,e
        ld d,2
.put:   push bc
        ld c,a
        ; only where the page is bare background
        push de
        ld a,c
        call bgrow
        ld a,b
        rrca
        rrca
        and $3F
        add a,l
        ld l,a
        ld a,b
        and 3
        ld e,a
        ld d,0
        push hl
        ld hl,spk_mask
        add hl,de
        ld a,(hl)
        pop hl
        and (hl)
        jr nz,.sk2
        push de                 ; keep clear of anything drawn: this byte and its
        dec hl                  ; neighbours, two rows up and down
        ld de,-64
        add hl,de
        ld e,5
        xor a
.cr:    or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        push de
        ld de,30
        add hl,de
        pop de
        dec e
        jr nz,.cr
        pop de
        or a
.sk2:   pop de
        jr nz,.skip
        ld e,d
        call dl_pixel
.skip:  pop bc
        inc ix
        inc ix
        inc c
        ld a,c
        cp SPK_N
        jr nz,.l
        ret
spk_mask: db $C0,$30,$0C,$03
