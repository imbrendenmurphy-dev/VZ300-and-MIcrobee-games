; =====================================================================
;  PENGUIN 2 - attract sequence, title, info pages, demo, hall of fame,
;  initials entry, dance intermission and the ending
; =====================================================================
attract:
        ld sp,STACKTOP
        xor a
        ld (demo),a
        ld (flashtim),a
        ld (goldmode),a
        ld a,MODE1|CSS1
        ld (palbase),a
.cycle: call title_screen
        jr nz,.go
        call how_to_play
        jr nz,.go
        call meet_monsters
        jr nz,.go
        call goodies_screen
        jr nz,.go
        call run_demo
        jr nz,.go
        call hiscore_screen
        jr nz,.go
        jr .cycle
.go:    ld sp,STACKTOP
        call stop_music
        xor a
        ld (demo),a
        ld (inpnew),a
        ld a,MODE1|CSS1
        ld (palbase),a
        jp start_game

; dl_add only when the sprite fits on screen (x < 120)
dl_add_cl:
        push af
        ld a,b
        cp 120
        jr nc,.no
        pop af
        jp dl_add
.no:    pop af
        ret

; ---------------------------------------------------------------------
; TITLE
title_screen:
        ld a,MODE1|CSS1
        ld (palbase),a
        call dl_reset
        call do_frame
        ld hl,title_pic
        ld de,BGBUF
        call unpack
        call title_msg_clear
        call wipe_show
        ld a,16
        ld (cbudget),a
        ld hl,mus_title_0
        ld de,mus_title_1
        call play_music
        ld hl,0
        ld (attr_t),hl
        ld hl,attr_v
        ld (hl),0               ; penguin x
        inc hl
        ld (hl),120             ; blob x
        inc hl
        ld (hl),0               ; blob state (0 walking, n = squashed timer)
        inc hl
        ld (hl),$FF             ; message index
        call init_popups
        call snow_init
.loop:  call dl_reset
        call title_scene
        call title_message
        ld a,(q_head)           ; text waiting to be copied? skip the flakes this
        ld b,a                  ; frame so the copy still fits in vblank
        ld a,(q_tail)
        cp b
        call z,snow_fall
        call update_popups
        call do_frame
        call check_world
        ret nz
        call check_start
        ret nz
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,700
        or a
        sbc hl,de
        jr nz,.loop
        call stop_music
        xor a
        ret

; keys 1-4 on the title pick the starting world -> NZ
check_world:
        ld a,($6FF7)
        cpl
        ld c,0
        bit 4,a
        jr nz,.w1
        bit 1,a
        jr nz,.w2
        bit 3,a
        jr nz,.w3
        bit 5,a
        ret z
        ld c,15
        jr .go
.w3:    ld c,10
        jr .go
.w2:    ld c,5
.w1:
.go:    ld a,c
        ld (startlevel),a
        or 1
        ret

; snowflakes: 12 x (x, y, phase)
snow_init:
        ld hl,snow
        ld b,5
.l:     push bc
        push hl
        call random
        pop hl
        and $7F
        ld (hl),a
        inc hl
        push hl
        call random
        pop hl
        and 31
        ld (hl),a
        inc hl
        push hl
        call random
        pop hl
        ld (hl),a
        inc hl
        pop bc
        djnz .l
        ret
snow_fall:
        ld hl,snow
        ld b,5
.l:     push bc
        inc hl
        inc hl
        inc (hl)                ; phase
        ld a,(hl)
        dec hl
        and 1
        jr nz,.nm
        inc (hl)                ; y
.nm:    ld a,(hl)
        cp 46
        jr c,.ok
        ld (hl),0
        dec hl
        push hl
        call random
        pop hl
        and $7F
        ld (hl),a
        inc hl
.ok:    ld c,(hl)
        dec hl
        ld a,(hl)
        ; drift left/right with the phase
        inc hl
        inc hl
        ld e,(hl)
        bit 4,e
        jr z,.d
        inc a
.d:     and $7F
        dec hl
        dec hl
        ld (hl),a
        ld b,a
        push hl
        ld e,0
        call dl_pixel
        pop hl
        inc hl
        inc hl
        inc hl
        pop bc
        djnz .l
        ret

; big penguin pushes an ice block into a blob
title_scene:
        ld a,(attr_t)
        and 1
        jr nz,.nm
        ld a,(attr_v)
        cp 92
        jr nc,.nm
        inc a
        ld (attr_v),a
.nm:    ; blob walks left every third frame until squashed
        ld a,(attr_v+2)
        or a
        jr nz,.sq
        ld a,(attr_t)
        and 3
        jr nz,.bd
        ld a,(attr_v+1)
        cp 40
        jr c,.bd
        dec a
        ld (attr_v+1),a
.bd:    ; block front reaches the blob?
        ld a,(attr_v)
        add a,16+8
        ld b,a
        ld a,(attr_v+1)
        cp b
        jr nc,.draw
        ld a,90
        ld (attr_v+2),a
        ld a,SFX_CRUSH
        call play_sfx
        jr .draw
.sq:    dec a
        ld (attr_v+2),a
        jr nz,.draw
        ; a new blob appears on the right
        ld a,120
        ld (attr_v+1),a
.draw:  ; blob
        ld a,(attr_v+1)
        ld b,a
        ld c,50
        ld a,(attr_v+2)
        or a
        ld a,SPR_SQUASH
        jr nz,.bs
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_BLOB0
.bs:    call dl_add_cl
        ; block, kept in front of the penguin (or resting against the blob)
        ld a,(attr_v)
        add a,16
        ld b,a
        ld c,50
        ld a,SPR_BICE
        call dl_add_cl
        ; penguin
        ld a,(attr_v)
        add a,4
        ld b,a
        ld c,45
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_BIGP0
        call dl_add_cl
        ret
bobtab: db 0,1,2,3,3,2,1,0

title_msg_clear:
        ld a,1
        ld (noq),a
        ld de,$0039
        ld bc,$2007
        xor a
        call fill_rect
        xor a
        ld (noq),a
        ret
title_message:
        ld hl,(attr_t)
        ld a,l
        and $7F
        ret nz
        ld a,h
        rlca
        ld b,a
        ld a,l
        rlca
        and 1
        or b
        and 3
        add a,a
        ld e,a
        ld d,0
        ld hl,title_msgs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld a,2
        ld b,0
        call set_ink
        pop hl
        ld e,58
        jp print_full
title_msgs: dw tm0,tm1,tm2,tm3
tm0:    db "PRESS FIRE OR SPACE TO PLAY",0
tm1:    db "THE SEQUEL TO VZ PENGUIN",0
tm2:    db "VIBED BY BPM 2026",0
tm3:    db "KEYS 1-4: START AT WORLD 1-4",0

; ---------------------------------------------------------------------
; info page helpers (white snow, big orange heading)
info_page:      ; HL = heading
        push hl
        ld a,MODE1|CSS1
        ld (palbase),a
        call dl_reset
        call do_frame
        xor a
        call cls_bg
        ld a,1
        ld (noq),a
        ld de,$003E
        ld bc,$2002
        ld a,$AA
        call fill_rect
        ld a,3
        ld b,0
        call set_ink
        pop hl
        ld e,2
        call print2_c
        xor a
        ld (noq),a
        ret
; text line: HL = string, D = col, E = row, A = ink
info_text:
        push hl
        push de
        ld b,0
        call set_ink
        pop de
        pop hl
        jp print
; run an info page: wait up to 330 frames animating via (attr_v+8) routine
info_wait:
        ld hl,mus_info_0
        ld de,mus_info_1
        call play_music
        ld hl,0
        ld (attr_t),hl
.l:     call dl_reset
        ld hl,(infohook)
        call .call
        call do_frame
        call check_start
        jr nz,.out
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,330
        or a
        sbc hl,de
        jr nz,.l
        xor a
.out:   push af
        call stop_music
        pop af
        ret
.call:  jp (hl)

how_to_play:
        ld hl,s_how
        call info_page
        ld hl,how_lines
        call info_lines
        ld hl,s_how_ctl
        ld de,$0038
        ld a,2
        call info_text
        call wipe_show
        ld hl,how_anim
        ld (infohook),hl
        jp info_wait
s_how:  db "HOW TO PLAY",0
s_how_ctl: db "Q A M , OR STICK  SPACE: PUSH",0
how_lines:
        db T_ICE : dw hl0
        db T_CR2 : dw hl1
        db T_EGG : dw hl2
        db T_CRYS : dw hl3
        db T_ROCK : dw hl4
        db $FF
hl0:    db "PUSH ICE TO SQUASH MONSTERS",0
hl1:    db "BLOCKED ICE CRUMBLES AWAY",0
hl2:    db "SMASH EGG BLOCKS: 500",0
hl3:    db "LINE UP 3 CRYSTALS: 10000",0
hl4:    db "PUSH THE WALL TO STUN FOES",0
; info_lines: HL -> (tile, string ptr)*, $FF ; rows 15, 23, 31...
info_lines:
        ld e,14
.l:     ld a,(hl)
        cp $FF
        ret z
        push hl
        push de
        ld d,1
        call draw_tile_at
        pop de
        pop hl
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        push de
        ld h,b
        ld l,c
        inc e
        ld d,4
        ld a,2
        call info_text
        pop de
        pop hl
        ld a,e
        add a,8
        ld e,a
        jr .l
how_anim:
        ld a,(attr_t)
        and 32
        ld a,SPR_PPR
        jr z,.p
        ld a,SPR_PR0
.p:     ld bc,$6C03
        jp dl_add

meet_monsters:
        ld hl,s_meet
        call info_page
        ld hl,meet_lines
        ld e,14
.l:     ld a,(hl)
        or a
        jr z,.d
        push hl
        push de
        ld d,3
        ld a,3
        call info_text
        pop de
        pop hl
.s:     ld a,(hl)
        inc hl
        or a
        jr nz,.s
        push hl
        push de
        ld d,11
        ld a,2
        call info_text
        pop de
        pop hl
.s2:    ld a,(hl)
        inc hl
        or a
        jr nz,.s2
        ld a,e
        add a,9
        ld e,a
        jr .l
.d:     call wipe_show
        ld hl,meet_anim
        ld (infohook),hl
        jp info_wait
s_meet: db "THE MONSTERS",0
meet_lines:
        db "BLOB",0,"WOBBLES AFTER YOU",0
        db "CHOMPER",0,"MUNCHES THRU ICE",0
        db "FLITTER",0,"FAST AND FLIGHTY",0
        db "WISP",0,"FLOATS THRU ICE",0
        db "DIZZY",0,"BUMP THEM FOR 100",0
        db 0
meet_anim:
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        ld e,a
        ld hl,meet_spr
        ld c,13
        ld b,5
.l:     push bc
        push de
        push hl
        ld a,(hl)
        add a,e
        ld b,2
        call dl_add
        pop hl
        pop de
        pop bc
        inc hl
        ld a,c
        add a,9
        ld c,a
        djnz .l
        ret
meet_spr: db SPR_BLOB0,SPR_CHOMP0,SPR_FLIT0,SPR_WISP0,SPR_BLOBS

goodies_screen:
        ld hl,s_goodies
        call info_page
        ld hl,good_lines
        call info_lines
        ld hl,s_good_ctl
        ld de,$0038
        ld a,2
        call info_text
        call wipe_show
        ld hl,vb_none
        ld (infohook),hl
        jp info_wait
s_goodies: db "ICE GOODIES",0
s_good_ctl: db "P: PAUSE   S: MUSIC/SFX/OFF",0
good_lines:
        db T_FISH : dw gl0
        db T_FLAKE : dw gl1
        db T_SKATE : dw gl2
        db T_HEART : dw gl3
        db T_GOLDB : dw gl4
        db $FF
gl0:    db "FISH: 500, 1000, 2000",0
gl1:    db "SNOWFLAKE: FREEZE THEM ALL",0
gl2:    db "SKATES: TURBO WADDLE",0
gl3:    db "HEART: AN EXTRA PENGUIN",0
gl4:    db "GOLD RUSH: SMASH FOR CASH",0

; ---------------------------------------------------------------------
; DEMO: the real engine with an AI penguin
run_demo:
        call stop_music
        ld a,1
        ld (demo),a
        call random
        and 7
        ld e,a
        ld d,0
        ld hl,demolevels
        add hl,de
        ld a,(hl)
        ld (level),a
        xor a
        ld (lap),a
        ld a,1
        ld (lives),a
        ld hl,0
        ld (score),hl
        xor a
        ld (score+2),a
        ld hl,$9999
        ld (nextlife),hl
        ld hl,1500
        ld (demotim),hl
        ld hl,s_demo
        ld (curlabel),hl
        call level_start
        push af
        xor a
        ld (demo),a
        ld (hurry),a
        ld (goldmode),a
        ld (inp),a
        ld (inpnew),a
        ld a,MODE1|CSS1
        ld (palbase),a
        call stop_music
        pop af
        ret
demolevels: db 0,1,2,3,5,6,7,8
s_demo: db "DEMO",0

; ---------------------------------------------------------------------
; HALL OF FAME
hiscore_screen:
        call dl_reset
        call do_frame
        ld a,$AA
        call cls_bg
        ld a,3
        ld b,2
        call set_ink
        ld hl,s_hof
        ld e,2
        call print2_c
        call draw_hitab
        ld de,$0031
        ld bc,$2009
        xor a
        call fill_rect
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_play
        ld e,58
        call print_c
        call wipe_show
        ld hl,0
        ld (attr_t),hl
        ld hl,mus_dance_0
        ld de,mus_dance_1
        call play_music
.loop:  call dl_reset
        ; parade: penguin chased by the monster gang along the bottom
        ld a,(attr_t)
        ld b,a
        ld a,150
        sub b
        ld b,a
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_PL0
        ld c,50
        call dl_add_cl
        ld a,(attr_t)
        ld b,a
        ld a,164
        sub b
        ld e,a
        ld d,4
        ld hl,parade
.p:     push de
        push hl
        ld b,e
        ld c,50
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,(hl)
        call dl_add_cl
        pop hl
        pop de
        inc hl
        ld a,e
        add a,11
        ld e,a
        dec d
        jr nz,.p
        call do_frame
        call check_start
        jr nz,.out
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,330
        or a
        sbc hl,de
        jr nz,.loop
        xor a
.out:   push af
        call stop_music
        pop af
        ret
parade: db SPR_BLOB0,SPR_CHOMP0,SPR_FLIT0,SPR_WISP0
s_hof:  db "HALL OF FAME",0
s_play: db "PRESS FIRE TO PLAY",0

draw_hitab:
        ld ix,hitab
        xor a
        ld (attr_v+5),a
.l:     ld a,(attr_v+5)
        and 1
        ld a,0
        jr z,.c
        ld a,1
.c:     ld b,2
        call set_ink
        ld a,(attr_v+5)
        ld b,a
        add a,a
        add a,a
        add a,a
        sub b
        add a,14
        ld (attr_v+6),a
        ld a,(attr_v+5)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,ranks
        add hl,de
        ld a,(attr_v+6)
        ld e,a
        ld d,7
        call print
        ld a,(ix+3)
        ld (nameb),a
        ld a,(ix+4)
        ld (nameb+1),a
        ld a,(ix+5)
        ld (nameb+2),a
        xor a
        ld (nameb+3),a
        ld hl,nameb
        ld a,(attr_v+6)
        ld e,a
        ld d,12
        call print
        push ix
        pop hl
        ld b,3
        ld a,(attr_v+6)
        ld e,a
        ld d,17
        call print_bcd
        ld de,6
        add ix,de
        ld a,(attr_v+5)
        inc a
        ld (attr_v+5),a
        cp 5
        jr nz,.l
        ret
ranks:  db "1ST",0,"2ND",0,"3RD",0,"4TH",0,"5TH",0

; ---------------------------------------------------------------------
; initials entry after game over
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
.lower: ld de,6
        add ix,de
        inc c
        ld a,c
        cp 5
        jr nz,.f
        ret
.found: ld a,4
        sub c
        jr z,.noshift
        ld b,a
        ld hl,hitab+23
        ld de,hitab+29
.sh:    push bc
        ld bc,6
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
        ld a,'A'
        ld (nameb),a
        ld (nameb+1),a
        ld (nameb+2),a
        xor a
        ld (nameb+3),a
        call dl_reset
        call do_frame
        ld a,MODE1|CSS1
        ld (palbase),a
        ld a,$AA
        call cls_bg
        ld a,3
        ld b,2
        call set_ink
        ld hl,s_nhs
        ld e,3
        call print2_c
        ld a,0
        ld b,2
        call set_ink
        ld hl,s_ent
        ld e,18
        call print_c
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_ent2
        ld e,52
        call print_c
        call wipe_show
        ld hl,mus_hiscore_0
        ld de,mus_hiscore_1
        call play_music
        xor a
        ld (attr_v+4),a
        ld hl,1500
        ld (attr_t),hl
.loop:  call dl_reset
        ld a,0
        ld b,2
        call set_ink
        ld hl,nameb
        ld de,$0D1E
        call print2
        ld a,(attr_v+4)
        add a,a
        add a,13
        add a,a
        add a,a
        ld b,a
        ld c,36
        ld a,(framecount)
        and 8
        jr z,.nc
        ld a,SPR_CURSOR
        call dl_add
.nc:    ld a,(inpnew)
        ld c,a
        ld a,(attr_v+4)
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
        ld a,(attr_v+4)
        or a
        jr z,.nl
        dec a
        ld (attr_v+4),a
.nl:    ld a,c
        and $11
        jr z,.nr
        ld a,SFX_POP
        call play_sfx
        ld a,(attr_v+4)
        inc a
        ld (attr_v+4),a
        cp 3
        jr z,.done
.nr:    ld a,(keysnew)
        and 4
        jr nz,.done
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
        ld bc,3
        ldir
        call stop_music
        call hiscore_screen
        ret
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
s_nhs:  db "NEW HI-SCORE",0
s_ent:  db "ENTER YOUR INITIALS",0
s_ent2: db "UP/DOWN, FIRE TO ACCEPT",0

; ---------------------------------------------------------------------
; INTERMISSION: the penguin dance (after world 2's gold rush)
run_dance:
        ld hl,s_dance
        call info_page
        ld a,2
        ld b,0
        call set_ink
        ld hl,s_dance2
        ld e,56
        call print_c
        call wipe_show
        ld hl,mus_dance_0
        ld de,mus_dance_1
        call play_music
        ld hl,0
        ld (attr_t),hl
.l:     call dl_reset
        ; five dancers in a row, alternating penguins and monsters
        ld hl,dancers
        ld b,6
        ld e,0
.d:     push bc
        push de
        push hl
        ld a,(attr_t)
        rrca
        rrca
        rrca
        rrca
        add a,e
        and 1
        add a,(hl)
        ld c,30
        bit 0,e
        jr z,.u
        ld c,28
.u:     push af
        ld a,e
        add a,a
        add a,a
        add a,a
        add a,a
        add a,e                 ; *17
        add a,4+17
        ld b,a
        pop af
        call dl_add_cl
        pop hl
        pop de
        pop bc
        inc hl
        inc e
        djnz .d
        call do_frame
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,420
        or a
        sbc hl,de
        jr nz,.l
        jp stop_music
s_dance: db "TAKE A BREAK!",0
s_dance2: db "WORLD 3: THE CRYSTAL CAVES",0
dancers: db SPR_BLOB0,SPR_PDANCE0,SPR_CHOMP0,SPR_PDANCE0,SPR_WISP0,SPR_PDANCE0

; ENDING: after the last world
run_ending:
        ld hl,s_end1
        call info_page
        ld a,2
        ld b,0
        call set_ink
        ld hl,s_end2
        ld e,15
        call print_c
        ld hl,s_end3
        ld e,22
        call print_c
        ld a,3
        ld b,0
        call set_ink
        ld hl,s_end4
        ld e,56
        call print_c
        call wipe_show
        ld hl,mus_ending_0
        ld de,mus_ending_1
        call play_music
        call init_popups
        ld hl,0
        ld (attr_t),hl
.l:     call dl_reset
        ; fireworks
        ld a,(attr_t)
        and 15
        jr nz,.nf
        call random
        and $7F
        cp 116
        jr c,.fx
        sub 20
.fx:    add a,6
        ld b,a
        call random
        and 15
        add a,30
        ld c,a
        call random
        and 3
        jr nz,.fc
        inc a
.fc:    call burst
.nf:    ; big penguin hops in the middle, little ones dance either side
        ld a,(attr_t)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_BIGP0
        ld bc,$3A2B
        call dl_add
        ld a,(attr_t)
        rrca
        rrca
        rrca
        rrca
        and 1
        add a,SPR_PDANCE0
        push af
        ld bc,$202F
        call dl_add
        pop af
        ld bc,$582F
        call dl_add
        call update_particles
        call do_frame
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,700
        or a
        sbc hl,de
        jr nz,.l
        call stop_music
        ; lap bonus
        ld de,$5000
        call add_score
        ret
s_end1: db "YOU DID IT!",0
s_end2: db "THE ICE AGE IS OVER...",0
s_end3: db "...OR IS IT? LAP 2: FASTER!",0
s_end4: db "BONUS 5000",0

; print_full: HL string centred in a full 32-character line at row E
print_full:
        push de
        push hl
        ld hl,wbuf
        ld b,32
.c:     ld (hl),' '
        inc hl
        djnz .c
        ld (hl),0
        pop hl
        push hl
        ld b,0
.l:     ld a,(hl)
        or a
        jr z,.d
        inc b
        inc hl
        jr .l
.d:     ld a,32
        sub b
        srl a
        ld e,a
        ld d,0
        ld hl,wbuf
        add hl,de
        ex de,hl
        pop hl
.cp:    ld a,(hl)
        or a
        jr z,.p
        ld (de),a
        inc hl
        inc de
        jr .cp
.p:     pop de                  ; print as two halves so each fits a frame's budget
        ld a,(wbuf+16)
        push af
        xor a
        ld (wbuf+16),a
        push de
        ld d,0
        ld hl,wbuf
        call print
        pop de
        pop af
        ld (wbuf+16),a
        ld d,16
        ld hl,wbuf+16
        jp print
