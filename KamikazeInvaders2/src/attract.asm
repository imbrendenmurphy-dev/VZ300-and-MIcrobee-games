; =====================================================================
;  KAMIKAZE INVADERS 2 - attract mode, info pages, demo, Top Ten,
;  letter-grid name entry (as in the original), ending.
; =====================================================================
attract:
        ld sp,STACKTOP
        xor a
        ld (demo),a
        ld (bonusmode),a
        ld (startsector),a
        ld a,MODE1
        ld (palbase),a
        call title_screen
        jr nz,.go
        call how_to_play
        jr nz,.go
        call enemy_page
        jr nz,.go
        call power_page
        jr nz,.go
        call run_demo
        jr nz,.go
        call hiscore_screen
        jr nz,.go
        jr attract
.go:    call stop_music
        ld a,SFX_MENU
        call play_sfx
        ld a,MODE1
        ld (palbase),a
        call start_game
        jp attract

; keys 1-4 -> NZ and startsector set
check_sector_keys:
        ld a,($6FF7)            ; row3: 1 bit4, 2 bit1, 3 bit3, 4 bit5
        ld b,0
        bit 4,a
        jr z,.k
        inc b
        bit 1,a
        jr z,.k
        inc b
        bit 3,a
        jr z,.k
        inc b
        bit 5,a
        jr z,.k
        xor a
        ret
.k:     ld a,b
        ld (startsector),a
        or $80
        ret

; ---------------------------------------------------------------------
; TITLE
; ---------------------------------------------------------------------
title_screen:
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
        call play_music
        xor a
        ld (attr_t),a
        ld (attr_t+1),a
        ld a,$FF
        ld (tmpd),a             ; current message
.lp:    call dl_reset
        ; message line on the planet, changes every 256 frames
        ld a,(attr_t)
        or a
        call z,title_message
        ; two big kamikazes hover above the planet
        ld a,(attr_t)
        rrca
        rrca
        and 31
        ld l,a
        ld h,0
        ld de,bobtab
        add hl,de
        ld a,(hl)
        add a,27
        ld c,a
        ld (tmpy),a
        ld a,(attr_t)
        and 16
        ld a,SPR_BIGK0
        jr z,.f0
        inc a
.f0:    ld (tmpx),a
        ld b,22
        call dl_add
        ld a,(tmpy)
        neg
        add a,27+27+7
        ld c,a
        ld a,(tmpx)
        xor SPR_BIGK0^SPR_BIGK1
        ld b,64
        call dl_add
        ; a grunt sweeps across (more would push the frame past vblank)
        ld b,1
.sq:    push bc
        ld a,b
        ld c,a
        add a,a
        add a,a
        add a,a
        add a,c
        add a,a
        add a,c
        add a,c
        add a,c
        add a,c                 ; 24*b
        add a,a                 ; 48*b: spread them across the screen
        ld c,a
        ld a,(attr_t)
        add a,c
        and 127
        cp 120
        jr nc,.sqn
        ld b,a
        rrca
        rrca
        and 31
        ld e,a
        ld d,0
        ld hl,bobtab
        add hl,de
        ld a,(hl)
        add a,40
        ld c,a
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_GRUNT0
        call dl_add
.sqn:   pop bc
        djnz .sq
        call do_frame
        call check_sector_keys
        jr nz,.start
        call check_start
        jr nz,.start
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,800
        or a
        sbc hl,de
        jp c,.lp
        xor a
        ret
.start: ld a,1
        or a
        ret
bobtab: db 0,1,2,3,4,5,6,6,7,7,7,6,6,5,4,3,2,1,0,0,0,1,1,2,2,3,3,2,2,1,1,0

title_message:
        ld a,(tmpd)
        inc a
        and 3
        ld (tmpd),a
        add a,a
        ld l,a
        ld h,0
        ld de,title_msgs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld a,1
        ld (noq),a              ; draw into BG only, commit below in small pieces
        ld de,$003A
        ld bc,$2005
        ld a,0                  ; green planet
        call fill_rect
        ld a,3
        ld b,0
        call set_ink
        pop hl
        ld e,58
        call print_c
        xor a
        ld (noq),a
        ; four 8-byte slices, one per frame, keep the title inside vblank
        ld d,0
.q:     push de
        ld e,58
        ld bc,$0805
        call queue_rect
        pop de
        ld a,d
        add a,8
        ld d,a
        cp 32
        jr nz,.q
        ret
title_msgs: dw tm0,tm1,tm2,tm3
tm0:    db "PRESS FIRE OR SPACE TO PLAY",0
tm1:    db "THE SEQUEL TO KAMIKAZE INVADERS",0
tm2:    db "VIBED BY BPM 2026",0
tm3:    db "KEYS 1-4: START AT SECTOR 1-4",0

; ---------------------------------------------------------------------
; INFO PAGES
; ---------------------------------------------------------------------
; info_page: HL = heading; clears the BG to space and prints it big.
; The caller draws the rest, then calls wipe_show to reveal the whole page
; (so nothing is committed piecemeal and the queue can't overflow).
info_page:
        push hl
        call dl_reset
        call do_frame
        ld a,$AA
        call cls_bg
        ld a,1
        ld b,2
        call set_ink
        pop hl
        ld e,1
        jp print2_c
; info_lines: HL -> list of (col,row,colour) + string, terminated by $FF
info_lines:
        ld a,(hl)
        cp $FF
        ret z
        ld d,a
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push hl
        push de
        ld b,2
        call set_ink
        pop de
        pop hl
        call print
.z:     ld a,(hl)
        inc hl
        or a
        jr nz,.z
        jr info_lines
; info_wait: B frames (x2), drawing the sprite list at IX each frame
; (list of id,x,y; $FF ends). NZ if start pressed.
info_wait:
        ld (attr_v),ix
        ld b,0
.l:     push bc
        call dl_reset
        ld ix,(attr_v)
.s:     ld a,(ix+0)
        cp $FF
        jr z,.sd
        ld b,(ix+1)
        ld c,(ix+2)
        ld e,a
        ld a,(framecount)
        and 16
        ld a,e
        jr z,.f
        ; animate pairs (kamikaze leg frames)
        cp SPR_GRUNT0
        jr c,.f
        cp SPR_WARN
        jr nc,.f
        inc a
.f:     call dl_add
        inc ix
        inc ix
        inc ix
        jr .s
.sd:    call do_frame
        pop bc
        call check_start
        ret nz
        ld a,(framecount)
        and 1
        jr z,.l
        djnz .l
        xor a
        ret

how_to_play:
        ld hl,mus_info_0
        ld de,mus_info_1
        call play_music
        ld hl,s_how
        call info_page
        ld hl,how_lines
        call info_lines
        call wipe_show
        ld ix,how_spr
        jp info_wait
s_how:  db "HOW TO PLAY",0
how_lines:
        db 1,14,0,"THE MOTHERSHIP FILLS 10 COLUMNS",0
        db 1,21,0,"A 5TH ARRIVAL PUSHES ONE OUT:",0
        db 1,28,0,"IT DIVES AND BLASTS THE GROUND",0
        db 1,35,0,"SHOOT THE BOMB IN THE CENTRE!",0
        db 1,42,3,"EMPTY SHIP? BREACH ITS CORE!",0
        db 1,52,1,"M , OR STICK MOVE  SPACE: FIRE",0
        db 3,58,1,"P PAUSE   S SOUND   ",0
        db $FF
how_spr: db $FF

enemy_page:
        ld hl,s_enemy
        call info_page
        ld hl,enemy_lines
        call info_lines
        call wipe_show
        ld ix,enemy_spr
        jp info_wait
s_enemy: db "THE ENEMY",0
enemy_lines:
        db 6,14,1,"GRUNT",0
        db 14,14,0,"10, DIVING 30",0
        db 6,21,1,"ARMOUR",0
        db 14,21,0,"TAKES TWO HITS",0
        db 6,28,1,"ZIGZAG",0
        db 14,28,0,"WEAVES AS IT DIVES",0
        db 6,35,1,"SPARKER",0
        db 14,35,0,"BIGGER BLAST",0
        db 6,42,1,"BOMB",0
        db 14,42,0,"500 - SHOOT IT!",0
        db 6,51,3,"CORE",0
        db 14,51,0,"2000 - BREACH IT!",0
        db $FF
enemy_spr:
        db SPR_GRUNT0,10,14
        db SPR_ARMOR0,10,21
        db SPR_ZIG0,10,28
        db SPR_SPARK0,10,35
        db SPR_BOMB0,10,41
        db $FF

power_page:
        ld hl,s_power
        call info_page
        ld hl,power_lines
        call info_lines
        call wipe_show
        ld ix,power_spr
        jp info_wait
s_power: db "CAPSULES",0
power_lines:
        db 1,13,0,"SHOOT KAMIKAZES IN FLIGHT TO",0
        db 1,19,0,"KNOCK CAPSULES LOOSE - CATCH!",0
        db 6,27,1,"TWIN SHOT",0
        db 6,34,1,"RAPID FIRE",0
        db 6,41,1,"SHIELD: SAVES YOU ONCE",0
        db 6,48,1,"NOVA: CLEARS THE SCREEN",0
        db 1,57,3,"EXTRA SHIP AT 10000 + 20000S",0
        db $FF
power_spr:
        db SPR_CAPT,12,27
        db SPR_CAPR,12,34
        db SPR_CAPS,12,41
        db SPR_CAPN,12,48
        db $FF

; ---------------------------------------------------------------------
; DEMO (the AI plays a real game for ~30 s)
; ---------------------------------------------------------------------
run_demo:
        call stop_music
        ld a,1
        ld (demo),a
        xor a
        ld (lap),a
        ld (startsector),a
        ld hl,0
        ld (score),hl
        ld (score+1),hl
        ld a,3
        ld (lives),a
        ld hl,1600
        ld (demotim),hl
        ld b,4
        call rand_n
        ld (sector),a
        call sector_start_demo
        push af
        xor a
        ld (demo),a
        ld (bonusmode),a
        call stop_music
        call clear_objects_quiet
        ld a,MODE1
        ld (palbase),a
        pop af
        ret
sector_start_demo:
        xor a
        ld (wave),a
        ld (bonusmode),a
        call setup_sector
        ld hl,s_demo
        call hud_label
        jp sector_start_d2
s_demo: db "DEMO",0

; ---------------------------------------------------------------------
; TOP TEN
; ---------------------------------------------------------------------
hiscore_screen:
        ld hl,mus_info_0
        ld de,mus_info_1
        call play_music
        ld hl,s_hof
        call info_page
        call draw_hitab
        ld a,3
        ld b,2
        call set_ink
        ld hl,s_play
        ld e,58
        call print_c
        call wipe_show
        ; a parade of kamikazes along row 50
        ld hl,0
        ld (attr_t),hl
.l:     call dl_reset
        ld a,(attr_t)
        ld (tmpx),a
        ld hl,parade
        ld b,6
.p:     push bc
        push hl
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b
        add a,b
        add a,b
        add a,b
        ld c,a
        ld a,(tmpx)
        add a,c
        and 127
        cp 120
        jr nc,.pn
        ld b,a
        ld c,50
        ld a,(hl)
        ld e,a
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,e
        call dl_add
.pn:    pop hl
        pop bc
        inc hl
        djnz .p
        call do_frame
        call check_start
        ret nz
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,500
        or a
        sbc hl,de
        jr c,.l
        xor a
        ret
parade: db SPR_GRUNT0,SPR_ARMOR0,SPR_ZIG0,SPR_SPARK0,SPR_GRUNT0,SPR_ZIG0
s_hof:  db "TOP TEN",0
s_play: db "PRESS FIRE TO PLAY",0

; two columns of five: " 1 NAME  012345"
draw_hitab:
        ld hl,hitab
        xor a
        ld (cnt),a
.l:     push hl
        ld a,(cnt)
        ld b,a
        ld de,$000E             ; column 0, row 14
        cp 5
        jr c,.c
        sub 5
        ld d,16
.c:     ld c,a
        add a,a
        add a,a
        add a,a
        sub c
        add a,e
        ld e,a                  ; row 14 + 7*n
        push de
        ; rank
        ld a,(hirank)
        dec a
        cp b
        ld a,1
        jr nz,.ink
        ld a,3                  ; the new entry is highlighted
.ink:   ld b,2
        call set_ink
        ld hl,tbuf
        ld a,(cnt)
        inc a
        cp 10
        ld b,' '
        jr c,.r1
        ld b,'1'
        sub 10
.r1:    ld (hl),b
        inc hl
        add a,'0'
        ld (hl),a
        inc hl
        ld (hl),' '
        inc hl
        ex de,hl
        pop bc                  ; B = col, C = row
        pop hl                  ; entry
        push hl
        push bc
        inc hl
        inc hl
        inc hl
        ld b,5
.n:     ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .n
        ld a,' '
        ld (de),a
        inc de
        xor a
        ld (de),a
        pop de
        push de
        ld hl,tbuf
        call print
        pop de
        ld a,d
        add a,9
        ld d,a
        pop hl
        push hl
        ld b,3
        call print_bcd
        pop hl
        ld de,HIENT
        add hl,de
        ld a,(cnt)
        inc a
        ld (cnt),a
        cp 10
        jr nz,.l
        ret

; ---------------------------------------------------------------------
; NAME ENTRY: the original's way - a box moved over a letter grid
; ---------------------------------------------------------------------
enter_hiscore:
        xor a
        ld (hirank),a
        ; find the rank: first entry with a lower score
        ld hl,hitab
        ld c,0
.f:     push hl
        ld de,score
        ld b,3
.cmp:   ld a,(de)
        cp (hl)
        jr c,.lower             ; ours < theirs
        jr nz,.higher           ; ours > theirs
        inc hl
        inc de
        djnz .cmp
.lower: pop hl
        ld de,HIENT
        add hl,de
        inc c
        ld a,c
        cp 10
        jr nz,.f
        ret                     ; not good enough
.higher: pop hl
        ld a,c
        inc a
        ld (hirank),a
        ; shift the entries below down one place
        push hl
        ld a,9
        sub c
        jr z,.ns
        ld b,a
        ld hl,0
        ld de,HIENT
.m:     add hl,de
        djnz .m
        ld b,h
        ld c,l
        ld hl,hitab+HIENT*9-1
        ld de,hitab+HIENT*10-1
        lddr
.ns:    pop hl
        ld (hiptr),hl
        ld de,score
        ex de,hl
        ldi
        ldi
        ldi
        ld b,5
.sp:    ld a,' '
        ld (de),a
        inc de
        djnz .sp
        ; screen
        ld hl,mus_hiscore_0
        ld de,mus_hiscore_1
        call play_music
        ld hl,s_nhs
        call info_page
        ld a,0
        ld b,2
        call set_ink
        ld hl,s_ent
        ld e,13
        call print_c
        xor a
        ld (gridsel),a
        ld (cnt),a              ; name length
        ld hl,nameb
        ld b,6
.cl:    ld (hl),' '
        inc hl
        djnz .cl
        call grid_draw_all
        call name_draw
        call wipe_show
        ld hl,3000
        ld (attr_t),hl
.lp:    call dl_reset
        call do_frame
        ld hl,(attr_t)
        dec hl
        ld (attr_t),hl
        ld a,h
        or l
        jp z,.done
        call music_busy
        jr nz,.mb
        ld hl,mus_info_0
        ld de,mus_info_1
        call play_music
.mb:    ld a,(inpnew)
        ld b,a
        ld a,(gridsel)
        ld c,a
        bit 1,b
        jr z,.n1
        or a
        jr z,.n1
        dec a
.n1:    bit 0,b
        jr z,.n2
        cp 29
        jr nc,.n2
        inc a
.n2:    bit 2,b
        jr z,.n3
        cp 8
        jr c,.n3
        sub 8
.n3:    bit 3,b
        jr z,.n4
        cp 22
        jr nc,.n4
        add a,8
.n4:    cp c
        jr z,.nomove
        ld (gridsel),a
        push af
        ld a,c
        call grid_draw
        pop af
        call grid_draw
        ld a,SFX_TICK
        call play_sfx
.nomove:
        ld a,(inpnew)
        and $10
        jr nz,.sel
        ld a,(keysnew)
        and 4
        jr z,.lp
.sel:   ld a,SFX_MENU
        call play_sfx
        ld a,(gridsel)
        cp 29
        jr z,.done
        cp 28
        jr z,.del
        ld b,' '
        cp 27
        jr z,.add
        ld b,'.'
        cp 26
        jr z,.add
        add a,'A'
        ld b,a
.add:   ld a,(cnt)
        cp 5
        jp nc,.lp
        ld l,a
        ld h,0
        ld de,nameb
        add hl,de
        ld (hl),b
        inc a
        ld (cnt),a
        cp 5
        jr nz,.ad
        ; full: jump the box to END
        ld a,(gridsel)
        push af
        ld a,29
        ld (gridsel),a
        pop af
        call grid_draw
        ld a,29
        call grid_draw
.ad:    call name_draw
        jp .lp
.del:   ld a,(cnt)
        or a
        jp z,.lp
        dec a
        ld (cnt),a
        ld l,a
        ld h,0
        ld de,nameb
        add hl,de
        ld (hl),' '
        call name_draw
        jp .lp
.done:  ; store the name
        ld hl,(hiptr)
        inc hl
        inc hl
        inc hl
        ex de,hl
        ld hl,nameb
        ld bc,5
        ldir
        call stop_music
        ld hl,s_hof
        call info_page
        call draw_hitab
        call wipe_show
        ld hl,mus_hiscore_0
        ld de,mus_hiscore_1
        call play_music
        ld b,200
        call wait_frames
        xor a
        ld (hirank),a
        ret
s_nhs:  db "TOP TEN!",0
s_ent:  db "MOVE THE BOX, PRESS FIRE",0

; the name so far, big-ish, row 21
name_draw:
        ld a,1
        ld b,2
        call set_ink
        ld hl,tbuf
        ld de,nameb
        ld b,5
.c:     ld a,(de)
        cp ' '
        jr nz,.p
        ld a,'_'
.p:     ld (hl),a
        inc hl
        inc de
        djnz .c
        ld (hl),0
        ld hl,tbuf
        ld de,$0B14
        jp print2

; draw all 30 grid cells
grid_draw_all:
        ld a,1
        ld (noq),a
        xor a
.l:     push af
        call grid_draw
        pop af
        inc a
        cp 30
        jr nz,.l
        xor a
        ld (noq),a
        ; commit one grid row per frame (keeps each frame inside vblank)
        ld e,31
.q:     push de
        ld d,0
        ld bc,$2005
        call queue_rect
        pop de
        ld a,e
        add a,7
        ld e,a
        cp 31+28
        jr c,.q
        ret
; grid_draw: A = cell (0..29), 8 per row; selected cell drawn inverted
grid_draw:
        ld c,a
        ld b,a
        and 7
        add a,a
        add a,a
        inc a
        ld d,a                  ; col = 1 + 4*(cell mod 8)
        ld a,b
        and $18
        rrca
        rrca
        rrca
        ld b,a
        add a,a
        add a,a
        add a,a
        sub b
        add a,31
        ld e,a                  ; row = 31 + 7*(cell / 8)
        push de
        ld a,(gridsel)
        cp c
        ld a,1
        ld b,2
        jr nz,.ink
        ld a,2
        ld b,1
.ink:   push bc
        call set_ink
        pop bc
        ; cell text
        ld a,c
        ld hl,s_spc
        cp 27
        jr z,.pr
        ld hl,s_del
        cp 28
        jr z,.pr
        ld hl,s_end
        cp 29
        jr z,.pr
        ld b,'.'
        cp 26
        jr z,.ch
        add a,'A'
        ld b,a
.ch:    ld hl,tbuf
        ld (hl),' '
        inc hl
        ld (hl),b
        inc hl
        ld (hl),' '
        inc hl
        ld (hl),0
        ld hl,tbuf
.pr:    pop de
        jp print
s_spc:  db "SPC",0
s_del:  db "DEL",0
s_end:  db "END",0

; ---------------------------------------------------------------------
; ENDING (after sector 4's bonus round)
; ---------------------------------------------------------------------
run_ending:
        call stop_music
        ld de,$5000             ; bonus first: the HUD updates before the page wipes in
        call add_score
        ld de,$5000
        call add_score
        ld hl,s_end1
        call info_page
        ld hl,end_lines
        call info_lines
        call wipe_show
        ld hl,mus_ending_0
        ld de,mus_ending_1
        call play_music
        ld ix,end_spr
        call info_wait
        call stop_music
        ret
s_end1: db "WELL DONE!",0
end_lines:
        db 2,14,0,"THE HIVE IS BROKEN AND THE",0
        db 2,20,0,"KAMIKAZES SCATTER INTO SPACE.",0
        db 2,28,1,"COMPLETION BONUS 10000",0
        db 2,36,0,"BUT ANOTHER FLEET IS COMING...",0
        db 2,43,3,"NEXT LAP: FASTER AND MEANER!",0
        db $FF
end_spr:
        db SPR_BIGK0,4,53
        db SPR_BIGK1,112,53
        db $FF
