; =====================================================================
;  FRONT: start-up (colour or mono), the attract round (title, meet the
;  ghosts, power-ups, a demo game, the hall of fame), intermissions,
;  and the high-score table.
; =====================================================================
start:
        ld a,(boot_mono)
        ld (monomode),a
        ld a,1
        ld (musicon),a
        ld (sfxon),a
        ld a,r
        ld l,a
        ld h,$5A
        ld (seed),hl
        call clear_screen
        call load_store
        call frame_begin
        ld a,(boot_test)
        or a
        jr nz,play
        call choose_mono
attract:
        call title_page
        jr nz,play
        call ghosts_page
        jr nz,play
        call power_page
        jr nz,play
        ld a,1
        ld (demo),a
        call game_run
        ld a,(gresult)
        cp 3
        jr z,play
        call fame_page
        jr nz,play
        jr attract
play:   xor a
        ld (demo),a
        ld a,SFX_MENU
        call play_sfx
        call game_run
        call hs_check
        call fame_page
        jr nz,play
        jr attract

boot_mono:  db 0
boot_test:  db 0

; every cell blank (glyph 0), black: straight into the maps, both pages redrawn
clear_screen:
        xor a
        ld e,0
        ld c,25
        call block_rows
        ld hl,cur_lo
        ld (hl),$80
        ld de,cur_lo+1
        ld bc,1023
        ldir
        ld hl,cur_hi
        ld (hl),0
        ld de,cur_hi+1
        ld bc,2047              ; banks and colours
        ldir
        jp all_dirty

; the glyph store (colour or mono) into PCG banks 0-3 and into the sprite
; blocks at 0000h (sprites copy background glyphs from there)
load_store:
        ld a,BLK_GFX
        call map_blk
        ld hl,GFX_STORE_C
        ld a,(monomode)
        or a
        jr z,.c
        ld hl,GFX_STORE_M
.c:     push hl
        ld b,0
.bk:    ld a,b
        or LV_SCREEN
        out (P_LV),a
        push bc
        ld de,PCGWIN
        ld bc,2048
        ldir
        pop bc
        inc b
        ld a,b
        cp 4
        jr nz,.bk
        ld a,LV_SCREEN
        out (P_LV),a
        pop hl
        push hl
        ld a,BLK_SPR
        ld (cb_dst),a
        ld de,0
        ld bc,STORE_N*16
        ld a,BLK_GFX
        call blk_copy
        pop hl
        ld a,BLK_SPR+1
        ld (cb_dst),a
        ld de,0
        ld bc,STORE_N*16
        ld a,BLK_GFX
        call blk_copy
        ld a,BLK_RT
        jp map_blk

choose_mono:
        call clear_screen
        ld hl,s_name
        ld e,7
        ld a,YELLOW
        call print_mid
        ld hl,s_cm1
        ld de,6*256+11
        ld a,WHITE
        call print_at
        ld hl,s_cm2
        ld de,6*256+13
        ld a,WHITE
        call print_at
        ld hl,s_credit
        ld e,20
        ld a,GREY
        call print_mid
.w:     call frame_begin
        call read_input
        call sound_tick
        call frame_end
        ld a,(keysnew)
        ld b,a
        call input_used
        bit 3,b
        jr nz,.col
        bit 4,b
        jr z,.w
        ld a,1
        jr .set
.col:   xor a
.set:   ld (monomode),a
        ld a,SFX_MENU
        call play_sfx
        jp load_store
s_name: db "GHOST HUNTER '26",0
s_cm1:  db "C  FOR A COLOUR MONITOR",0
s_cm2:  db "M  FOR A MONOCHROME MONITOR",0
s_credit: db "VIBED BY BPM 2026",0

; ---------------------------------------------------------------------
;  page_loop: run a page for (att_end) frames, calling (att_cb) each frame.
;  -> NZ if start was pressed
; ---------------------------------------------------------------------
page_loop:
        ld hl,0
        ld (att_t),hl
.l:     call frame_begin
        call read_input
        ld hl,gtick
        inc (hl)
        call .cb
        call sound_tick
        call frame_end
        ld a,(keysnew)
        bit 2,a
        call nz,toggle_sound
        ld a,(padnew)
        and $10
        ld b,a
        ld a,(keysnew)
        and $20
        or b
        push af
        call input_used
        pop af
        jr nz,.go
        ld hl,(att_t)
        inc hl
        ld (att_t),hl
        ld de,(att_end)
        or a
        sbc hl,de
        jr nz,.l
        call stop_music
        xor a
        ret
.go:    call stop_music
        or 1
        ret
.cb:    ld hl,(att_cb)
        jp (hl)
no_cb:  ret

; A = frame, C = ink, HL = x, E = y (pixels)
put_px: ld (spr_x),hl
        ld l,e
        ld h,0
        ld (spr_y),hl
        push af
        ld a,c
        ld (spr_ink),a
        pop af
        jp spr_draw

; ---------------------------------------------------------------------
;  the chase: the hunter runs right with ghosts on his tail; then they
;  come back the other way, blue, with him behind them.
;  (t_c) = step 0..239, (t_n) = ghosts, (t_r) = y, (t_k) = 1: a giant hunter
; ---------------------------------------------------------------------
chase:  ld a,(t_c)
        cp 120
        jr nc,.back
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,-60
        add hl,de               ; the hunter's x
        push hl
        ld a,(t_r)
        ld e,a
        ld a,SF_HAT_R
        ld c,BRED
        call put_px
        pop hl
        push hl
        ld a,(t_r)
        ld e,a
        ld a,(t_c)
        rrca
        and 2
        add a,SF_FACE_R0
        ld c,YELLOW
        call put_px
        pop hl
        ld de,-34
        add hl,de
        ld b,0
.g:     push bc
        push hl
        ld a,(t_r)
        ld e,a
        ld a,b
        ld hl,gcols
        call tab_a
        ld c,a
        pop hl
        push hl
        ld a,(t_c)
        rrca
        rrca
        and 1
        ld d,a
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,d
        add a,SF_G0R0
        call put_px
        pop hl
        ld de,-22
        add hl,de
        pop bc
        inc b
        ld a,(t_n)
        cp b
        jr nz,.g
        ret
.back:  sub 120
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,330
        or a
        sbc hl,de               ; the first ghost's x
        ld b,0
.b:     push bc
        push hl
        ld a,(t_r)
        ld e,a
        ld a,(t_c)
        rrca
        rrca
        and 1
        add a,SF_FR0
        ld c,BBLUE
        call put_px
        pop hl
        ld de,22
        add hl,de
        pop bc
        inc b
        ld a,(t_n)
        cp b
        jr nz,.b
        ld de,14
        add hl,de
        ld a,(t_k)
        or a
        jr nz,.giant
        push hl
        ld a,(t_r)
        ld e,a
        ld a,SF_HAT_L
        ld c,BRED
        call put_px
        pop hl
        ld a,(t_r)
        ld e,a
        ld a,(t_c)
        rrca
        and 2
        add a,SF_FACE_L0
        ld c,YELLOW
        jp put_px
.giant: push hl
        ld a,(t_r)
        sub 18
        ld e,a
        ld a,SF_BIGHAT
        ld c,BRED
        call put_px
        pop hl
        ld a,(t_r)
        sub 2
        ld e,a
        ld a,(t_c)
        rrca
        rrca
        rrca
        and 1
        add a,SF_BIGFACE0
        ld c,YELLOW
        jp put_px
chase_step:
        ld a,(t_c)
        inc a
        cp 240
        jr c,.k
        xor a
.k:     ld (t_c),a
        ret

; ---------------------------------------------------------------------
title_page:
        ld hl,G_TITLE
        ld (lp_first),hl
        ld a,BLK_GFX
        ld hl,GFX_TITLE
        call load_picture
        ld a,BLK_RT
        call map_blk
        ld hl,s_credit
        ld e,24
        ld a,BRED
        call print_mid
        ld hl,mus_title_0
        ld de,mus_title_1
        call play_music
        xor a
        ld (t_c),a
        ld (t_k),a
        ld a,4
        ld (t_n),a
        ld a,132
        ld (t_r),a
        ld hl,title_cb
        ld (att_cb),hl
        ld hl,560
        ld (att_end),hl
        jp page_loop
title_cb:
        call chase
        call chase_step
        ; the line under the graveyard changes every couple of seconds
        ld a,(att_t)
        and 63
        ret nz
        ld de,0*256+22
        ld b,40
        call blank_cells
        ld a,(att_t)
        rlca
        rlca
        and 3
        add a,a
        ld hl,title_lines
        call tab_a
        push af
        ld a,(att_t)
        rlca
        rlca
        and 3
        add a,a
        inc a
        ld hl,title_lines
        call tab_a
        ld h,a
        pop af
        ld l,a
        ld e,22
        ld a,WHITE
        jp print_mid
title_lines: dw s_tl0,s_tl1,s_tl2,s_tl3
s_tl0:  db "PRESS SPACE OR FIRE TO HUNT!",0
s_tl1:  db "ARROWS, Q A O P OR JOYSTICK",0
s_tl2:  db "THE HUNT COMES TO THE MICROBEE",0
s_tl3:  db "H PAUSE   S SOUND   ESC QUIT",0

; ---------------------------------------------------------------------
ghosts_page:
        call clear_screen
        ld hl,s_meet
        ld e,1
        ld a,YELLOW
        call print_mid
        ld hl,meet_txt
        ld b,5
        ld e,4
.l:     push bc
        push de
        ld d,9
        ld a,(hl)
        inc hl
        push hl
        call print_at
        pop hl
        call .skip
        pop de
        inc e
        push de
        ld d,9
        ld a,GREY
        push hl
        call print_at
        pop hl
        call .skip
        pop de
        inc e
        inc e
        inc e
        pop bc
        djnz .l
        ld hl,s_hearts
        ld e,23
        ld a,BRED
        call print_mid
        ld hl,mus_fame_0
        ld de,mus_fame_1
        call play_music
        ld hl,meet_cb
        ld (att_cb),hl
        ld hl,300
        ld (att_end),hl
        jp page_loop
.skip:  ld a,(hl)               ; print keeps HL at the string start: step past it
        inc hl
        or a
        jr nz,.skip
        ret
meet_cb:
        ld b,0
.g:     push bc
        ld a,b
        add a,a
        add a,a
        add a,a
        ld d,a
        add a,a
        add a,a
        add a,d                 ; 40 lines (4 rows) apart
        add a,42
        ld e,a
        ld a,b
        ld hl,gcols
        call tab_a
        ld c,a
        ld a,(gtick)
        rrca
        rrca
        rrca
        and 1
        ld d,a
        ld a,(gtick)            ; they look about
        rlca
        rlca
        and 3
        add a,a
        add a,d
        ld d,a
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,d
        add a,SF_G0R0
        ld hl,40
        call put_px
        pop bc
        inc b
        ld a,b
        cp 4
        jr nz,.g
        ld hl,40
        ld e,202
        ld a,SF_HAT_R
        ld c,BRED
        call put_px
        ld a,(gtick)
        rrca
        rrca
        and 2
        add a,SF_FACE_R0
        ld hl,40
        ld e,202
        ld c,YELLOW
        jp put_px
s_meet: db "MEET THE GHOSTS",0
meet_txt:
        db BRED,"GRUMBLE",0,"CHASES YOU. ALWAYS CROSS.",0
        db BGREEN,"SNEAKY",0,"CUTS YOU OFF UP AHEAD.",0
        db BMAGENTA,"DIZZY",0,"WANDERS ABOUT... MOSTLY.",0
        db BCYAN,"PEEKABOO",0,"COMES ROUND THE OTHER SIDE.",0
        db YELLOW,"THE HUNTER",0,"THAT'S YOU. HAT AND ALL.",0
s_hearts: db "THREE HEARTS A LIFE - THREE LIVES",0

; ---------------------------------------------------------------------
power_page:
        call clear_screen
        ld hl,s_pup
        ld e,1
        ld a,YELLOW
        call print_mid
        ld hl,pup_txt
        ld b,6
        ld e,4
        xor a
.l:     push af
        push bc
        push de
        push hl
        ld d,4
        call put_tile
        pop hl
        pop de
        push de
        ld d,8
        ld a,(hl)
        inc hl
        push hl
        call print_at
        pop hl
.sk:    ld a,(hl)
        inc hl
        or a
        jr nz,.sk
        pop de
        inc e
        inc e
        inc e
        pop bc
        pop af
        inc a
        djnz .l
        ld hl,s_pup2
        ld e,23
        ld a,BCYAN
        call print_mid
        ld hl,no_cb
        ld (att_cb),hl
        ld hl,300
        ld (att_end),hl
        ld hl,mus_fame_0
        ld de,mus_fame_1
        call play_music
        jp page_loop
s_pup:  db "POWER UP!",0
pup_txt:
        db YELLOW,"SPEED: ZOOM, LEAVE A TRAIL",0
        db BCYAN,"FREEZE: GHOSTS ON ICE",0
        db BMAGENTA,"DOUBLE: TWICE THE POINTS",0
        db BBLUE,"SHIELD: SHRUG OFF ONE HIT",0
        db BRED,"HEART: ONE MORE HEART",0
        db WHITE,"EAT ALL 4: HUNTER MODE!",0
s_pup2: db "BIG PILLS TURN THE GHOSTS BLUE",0

; ---------------------------------------------------------------------
;  the hall of fame: five entries of 3 BCD score bytes + 3 letters
; ---------------------------------------------------------------------
hs_tab: db $01,$00,$00,"BPM"
        db $00,$75,$00,"GHO"
        db $00,$50,$00,"ST "
        db $00,$25,$00,"HUN"
        db $00,$10,$00,"TER"
hs_new: db $FF

fame_page:
        call clear_screen
        ld hl,s_fame
        ld e,2
        ld a,YELLOW
        call print_mid
        ld b,0
.l:     push bc
        ld a,b
        add a,a
        ld c,a
        add a,a
        add a,c                 ; x 6
        ld e,a
        ld d,0
        ld hl,hs_tab
        add hl,de
        push hl
        call score_text
        pop hl
        inc hl
        inc hl
        inc hl
        ld de,numbuf+6
        ld a,' '
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld bc,3
        ldir
        xor a
        ld (de),a
        pop bc
        push bc
        ld a,b
        add a,a
        add a,a
        sub b                   ; 3 rows apart
        add a,6
        ld e,a
        ld d,14
        ld a,(hs_new)
        cp b
        ld a,WHITE
        jr nz,.c
        ld a,BGREEN
.c:     ld hl,numbuf
        call print_at
        pop bc
        inc b
        ld a,b
        cp 5
        jr nz,.l
        ld hl,s_tl0
        ld e,23
        ld a,BCYAN
        call print_mid
        xor a
        ld (t_c),a
        ld (t_k),a
        ld a,4
        ld (t_n),a
        ld a,212
        ld (t_r),a
        ld hl,fame_cb
        ld (att_cb),hl
        ld hl,250
        ld (att_end),hl
        ld hl,mus_fame_0
        ld de,mus_fame_1
        call play_music
        call page_loop
        push af
        ld a,$FF
        ld (hs_new),a
        pop af
        ret
fame_cb:
        call chase
        jp chase_step
s_fame: db "HALL OF FAME",0

; after a game: does the score go on the table?
hs_check:
        ld a,$FF
        ld (hs_new),a
        ld b,0
        ld hl,hs_tab
.f:     push hl
        ld de,score
        ld c,3
.c:     ld a,(de)
        cp (hl)
        jr c,.lower
        jr nz,.here
        inc hl
        inc de
        dec c
        jr nz,.c
.lower: pop hl
        ld de,6
        add hl,de
        inc b
        ld a,b
        cp 5
        jr nz,.f
        ret
.here:  pop hl                  ; entry B: move the rest down
        ld a,b
        ld (hs_new),a
        push hl
        ld a,4
        sub b
        jr z,.ins
        ld c,a
        add a,a
        add a,c
        add a,a                 ; 6 x entries to move
        ld c,a
        ld b,0
        ld hl,hs_tab+23
        ld de,hs_tab+29
        lddr
.ins:   pop de
        push de
        ld hl,score
        ld bc,3
        ldir
        ld a,'A'
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        pop hl
        inc hl
        inc hl
        inc hl
        ld (t_ptr),hl           ; -> the three letters
        ; ---- the initials
        call clear_screen
        ld hl,s_hs1
        ld e,5
        ld a,YELLOW
        call print_mid
        ld hl,score
        call score_text
        ld hl,numbuf
        ld e,8
        ld a,WHITE
        call print_mid
        ld hl,s_hs2
        ld e,12
        ld a,BCYAN
        call print_mid
        ld hl,s_hs3
        ld e,20
        ld a,GREY
        call print_mid
        ld hl,mus_bonus_0
        ld de,mus_bonus_1
        call play_music
        xor a
        ld (hs_pos),a
.e:     call frame_begin
        call read_input
        ld hl,gtick
        inc (hl)
        ; show the letters, the current one flashing
        ld b,0
.sh:    push bc
        ld hl,(t_ptr)
        ld a,b
        call tab_a
        ld (numbuf),a
        xor a
        ld (numbuf+1),a
        ld a,b
        add a,a
        add a,17
        ld d,a
        ld e,15
        ld c,WHITE
        ld a,(hs_pos)
        cp b
        jr nz,.pc
        ld c,YELLOW
        ld a,(gtick)
        and 8
        jr z,.pc
        ld c,BRED
.pc:    ld a,c
        ld hl,numbuf
        call print_at
        pop bc
        inc b
        ld a,b
        cp 3
        jr nz,.sh
        call sound_tick
        call frame_end
        ld a,(padnew)
        ld b,a
        ld a,(keysnew)
        ld c,a
        push bc
        call input_used
        pop bc
        ld hl,(t_ptr)
        ld a,(hs_pos)
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        bit 2,b
        jr z,.nu
        ld a,(hl)
        inc a
        cp 'Z'+1
        jr c,.su
        ld a,' '
.su:    cp '!'
        jr nz,.su2
        ld a,'A'
.su2:   ld (hl),a
        ld a,SFX_MENU
        call play_sfx
.nu:    bit 3,b
        jr z,.nd
        ld a,(hl)
        dec a
        cp 'A'-1
        jr nz,.sd
        ld a,' '
.sd:    cp ' '-1
        jr nz,.sd2
        ld a,'Z'
.sd2:   ld (hl),a
        ld a,SFX_MENU
        call play_sfx
.nd:    ld a,b
        and $11                 ; fire or right: the next letter
        jr nz,.next
        bit 5,c
        jr nz,.next
        bit 1,b
        jp z,.e
        ld a,(hs_pos)
        or a
        jp z,.e
        dec a
        ld (hs_pos),a
        jp .e
.next:  ld a,SFX_ITEM
        call play_sfx
        ld a,(hs_pos)
        inc a
        ld (hs_pos),a
        cp 3
        jp nz,.e
        jp stop_music
s_hs1:  db "A NEW HIGH SCORE!",0
s_hs2:  db "ENTER YOUR INITIALS",0
s_hs3:  db "UP DOWN CHANGE - FIRE NEXT",0

; ---------------------------------------------------------------------
;  intermissions (A = 0: "WHO'S HUNTING WHO?", 1: "THE WHOLE GANG")
; ---------------------------------------------------------------------
intermission:
        push af
        call clear_screen
        pop af
        ld hl,s_int0
        ld b,1
        or a
        jr z,.s
        ld hl,s_int1
        ld b,4
.s:     ld a,b
        ld (t_n),a
        ld e,4
        ld a,YELLOW
        call print_mid
        xor a
        ld (t_c),a
        inc a
        ld (t_k),a
        ld a,132
        ld (t_r),a
        ld hl,mus_inter_0
        ld de,mus_inter_1
        call play_music
        ld hl,inter_cb
        ld (att_cb),hl
        ld hl,236
        ld (att_end),hl
        call page_loop
        ret
inter_cb:
        call chase
        call chase_step
        ld a,(t_c)
        cp 30
        jr nz,.n1
        ld hl,s_boo
        ld e,18
        ld a,BRED
        jp print_mid
.n1:    cp 120
        jr nz,.n2
        ld de,0*256+18
        ld b,40
        jp blank_cells
.n2:    cp 150
        ret nz
        ld hl,s_eek
        ld e,18
        ld a,BBLUE
        jp print_mid
s_int0: db "WHO'S HUNTING WHO?",0
s_int1: db "THE WHOLE GANG",0
s_boo:  db "BOO!",0
s_eek:  db "EEK!",0
