; =====================================================================
;  PANIK 2 - attract sequence, title, info pages, demo, hall of fame,
;  initials entry, coffee-break intermission and the ending
;  (structure adapted from Penguin 2)
; =====================================================================
attract:
        ld sp,STACKTOP
        xor a
        ld (demo),a
        ld (flashtim),a
        ld (lv_kind),a
        ld (labelheld),a
        ld (labeltim),a
        ld a,MODE1
        ld (palbase),a
.cycle: call title_screen
        jr nz,.go
        call how_to_play
        jr nz,.go
        call meet_aliens
        jr nz,.go
        call pickups_screen
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
        ld (labelheld),a
        ld a,MODE1
        ld (palbase),a
        jp start_game

; dl_add only when the sprite fits on screen (x < 121)
dl_add_cl:
        push af
        ld a,b
        cp 121
        jr nc,.no
        pop af
        jp dl_add
.no:    pop af
        ret

; ---------------------------------------------------------------------
; TITLE: the digger traps an alien on the station deck, again and again
; attr_v: 0 phase, 1 digger x, 2 alien x, 3 alien y, 4 hole, 5 timer
; ---------------------------------------------------------------------
TGY     equ 44                  ; sprite y on the title girder (row 52)
title_screen:
        ld a,MODE1
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
        call title_reset
        call init_popups
.loop:  call dl_reset
        call title_scene
        call title_message
        call update_particles
        call update_popups_t
        call do_frame
        call check_world
        ret nz
        call check_start
        ret nz
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,900
        or a
        sbc hl,de
        jr nz,.loop
        call stop_music
        xor a
        ret
title_reset:
        ld hl,attr_v
        ld (hl),0               ; phase
        inc hl
        ld (hl),16              ; digger x
        inc hl
        ld (hl),124             ; alien x (off to the right)
        inc hl
        ld (hl),TGY
        inc hl
        ld (hl),0
        inc hl
        ld (hl),0
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

title_scene:
        ld ix,attr_v
        inc (ix+5)
        ld a,(ix+0)
        or a
        jp nz,.p1
        ; 0: digger strolls to x=40, alien creeps in from the right
        ld a,(ix+1)
        cp 40
        jp nc,.p0d
        ld a,(attr_t)
        and 1
        jp nz,.draw
        inc (ix+1)
        jp .draw
.p0d:   ld (ix+0),1
        ld (ix+5),0
        jp .draw
.p1:    cp 1
        jp nz,.p2
        ; 1: three shovel strokes
        ld a,(ix+5)
        and 15
        jp nz,.draw
        inc (ix+4)
        ld a,(ix+4)
        call title_hole
        ld a,SFX_DIG
        call play_sfx
        ld a,(ix+4)
        cp 3
        jp nz,.draw
        ld (ix+0),2
        jp .draw
.p2:    cp 2
        jp nz,.p3
        ; 2: wait for the alien to walk into the hole (slot at x=48)
        ld a,(ix+2)
        cp 49
        jp nc,.draw
        ld (ix+2),48
        ld (ix+3),TGY+4
        ld (ix+0),3
        ld (ix+5),0
        ld a,SFX_TRAP
        call play_sfx
        jp .draw
.p3:    cp 3
        jp nz,.p4
        ; 3: bash, bash -> drop
        ld a,(ix+5)
        cp 40
        jp z,.bash
        cp 70
        jp nz,.draw
        ld (ix+0),4
        ld a,SFX_DROP
        call play_sfx
.bash:  ld a,SFX_BASH
        call play_sfx
        ld bc,$3430
        ld a,1
        call burst
        jp .draw
.p4:    cp 4
        jp nz,.p5
        ; 4: falls through, splat at the bottom: 100
        ld a,(ix+3)
        add a,2
        ld (ix+3),a
        cp 56
        jp c,.draw
        ld (ix+0),5
        ld (ix+5),0
        ld bc,$343A
        ld a,2
        call burst
        ld a,SFX_SPLAT
        call play_sfx
        ld bc,$0C2A
        ld e,P_100
        call popup_add_t
        jp .draw
.p5:    ; 5: the hole fills, the digger walks off, start again
        ld a,(ix+5)
        cp 30
        jp nz,.p5b
        ld (ix+4),0
        xor a
        call title_hole
.p5b:   ld a,(ix+5)
        cp 30
        jp c,.draw
        ld a,(ix+1)
        cp 121
        jp nc,.again
        inc (ix+1)
        jp .draw
.again: call title_reset
        ret
.draw:  ; alien walks left until it is trapped
        ld a,(ix+0)
        cp 3
        jp nc,.ad
        ld a,(attr_t)
        and 3
        jp nz,.ad
        ld a,(ix+2)
        cp 49
        jp c,.ad
        dec (ix+2)
.ad:    ld a,(ix+0)
        cp 5
        jp z,.dig
        ld b,(ix+2)
        ld c,(ix+3)
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_GRUB0
        call dl_add_cl
.dig:   ; the digger: digging / bashing poses, otherwise walking
        ld b,(ix+1)
        ld c,TGY
        ld a,(ix+0)
        cp 1
        jp z,.dpose
        cp 3
        jp z,.dpose
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_DR0
        jp dl_add_cl
.dpose: ld a,(ix+5)
        and 8
        ld a,SPR_DG0
        jp z,.dp
        inc a
.dp:    jp dl_add_cl

; title_hole: A = state (0-3) for the slot at x=48 on the title girder
title_hole:
        add a,a
        ld b,a
        add a,a
        add a,b
        ld e,a
        ld d,0
        ld hl,holemask
        add hl,de
        ex de,hl
        ld hl,BGBUF+52*32+12
        ld bc,tgird
        ld a,3
.r:     push af
        ld a,(bc)
        ex de,hl
        and (hl)
        ex de,hl
        ld (hl),a
        inc bc
        inc de
        inc hl
        ld a,(bc)
        ex de,hl
        and (hl)
        ex de,hl
        ld (hl),a
        inc bc
        inc de
        push de
        ld de,31
        add hl,de
        pop de
        pop af
        dec a
        jr nz,.r
        ld de,$0C34
        ld bc,$0203
        jp queue_rect
tgird:  db $55,$55,$AA,$A5,$55,$55

; title popups live in the BG over the title picture: no CLEAN copy, so
; they are simply removed by repainting that bit of the picture's colour
popup_add_t:
        jp popup_add
update_popups_t:
        ld hl,popups
        ld d,4
.l:     ld a,(hl)
        cp $FF
        jr z,.n
        push hl
        inc hl
        inc hl
        dec (hl)
        pop hl
        jr nz,.n
        push hl
        push de
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        inc hl
        ld b,(hl)
        ld c,5
        xor a
        call fill_rect
        pop de
        pop hl
        ld (hl),$FF
.n:     inc hl
        inc hl
        inc hl
        inc hl
        dec d
        jr nz,.l
        ret

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
tm1:    db "THE SEQUEL TO VZ PANIK",0
tm2:    db "VIBED BY BPM 2026",0
tm3:    db "KEYS 1-4: START AT WORLD 1-4",0

; ---------------------------------------------------------------------
; info page helpers (green deck, big red heading)
info_page:      ; HL = heading
        push hl
        ld a,MODE1
        ld (palbase),a
        call dl_reset
        call do_frame
        xor a
        call cls_bg
        call init_popups
        ld a,1
        ld (noq),a
        ld de,$003E
        ld bc,$2002
        ld a,$55
        call fill_rect
        ld de,$000D
        ld bc,$2001
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
; run an info page: up to 330 frames, animating via infohook
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
; info_lines: HL -> (ink, string)*, 0 ; from row E, 8 rows apart, col D
info_lines:
.l:     ld a,(hl)
        or a
        ret z
        inc hl
        push de
        push af
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        pop af
        push hl
        ld h,b
        ld l,c
        call info_text
        pop hl
        pop de
        ld a,e
        add a,8
        ld e,a
        jr .l

how_to_play:
        ld hl,s_how
        call info_page
        ld hl,how_lines
        ld de,$0111
        call info_lines
        ld hl,s_how_ctl
        ld de,$0039
        ld a,2
        call info_text
        call wipe_show
        ld hl,how_anim
        ld (infohook),hl
        jp info_wait
s_how:  db "HOW TO PLAY",0
s_how_ctl: db "Q A M , STICK. P:PAUSE S:SOUND",0
how_lines:
        db 1 : dw hl0
        db 2 : dw hl1
        db 1 : dw hl2
        db 2 : dw hl3
        db 3 : dw hl4
        db 0
hl0:    db "SPACE: DIG A HOLE",0
hl1:    db "ALIENS FALL IN - BASH THEM",0
hl2:    db "DOWN THROUGH THE FLOOR!",0
hl3:    db "BIG ONES NEED LONGER DROPS",0
hl4:    db "AND WATCH YOUR OXYGEN!",0
how_anim:
        ld a,(attr_t)
        and 16
        ld a,SPR_DG0
        jr z,.p
        inc a
.p:     ld bc,$6C12
        call dl_add
        ld a,(attr_t)
        rrca
        and 1
        add a,SPR_GRUB0
        ld bc,$7419
        jp dl_add

meet_aliens:
        ld hl,s_meet
        call info_page
        ld hl,meet_lines
        ld e,16
.l:     ld a,(hl)
        or a
        jr z,.d
        push hl
        push de
        ld d,4
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
        ld a,1
        call info_text
        pop de
        pop hl
.s2:    ld a,(hl)
        inc hl
        or a
        jr nz,.s2
        ld a,e
        add a,10
        ld e,a
        jr .l
.d:     ld hl,s_meet2
        ld de,$0039
        ld a,2
        call info_text
        call wipe_show
        ld hl,meet_anim
        ld (infohook),hl
        jp info_wait
s_meet: db "THE ALIENS",0
s_meet2: db "LAND ONE ON ANOTHER: 1000",0
meet_lines:
        db "GRUB",0,"1 FLOOR DROP  100+",0
        db "BRUTE",0,"2 FLOOR DROP  300+",0
        db "KING",0,"3 FLOOR DROP  800+",0
        db "ANGRY",0,"ESCAPED: FASTER!",0
        db 0
meet_anim:
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        ld e,a
        ld hl,meet_spr
        ld c,14
        ld b,4
.l:     push bc
        push de
        push hl
        ld a,(hl)
        add a,e
        ld b,4
        call dl_add
        pop hl
        pop de
        pop bc
        inc hl
        ld a,c
        add a,10
        ld c,a
        djnz .l
        ret
meet_spr: db SPR_GRUB0,SPR_BRUTE0,SPR_KING0,SPR_GRUBA0

pickups_screen:
        ld hl,s_goodies
        call info_page
        ld hl,good_lines
        ld de,$0410
        call info_lines
        ld hl,s_good2
        ld de,$0039
        ld a,2
        call info_text
        call wipe_show
        ld hl,good_anim
        ld (infohook),hl
        jp info_wait
s_goodies: db "PICK-UPS",0
s_good2: db "GEM DIG: A TIMED BONUS ROUND",0
good_lines:
        db 1 : dw gl0
        db 2 : dw gl1
        db 1 : dw gl2
        db 2 : dw gl3
        db 3 : dw gl4
        db 0
gl0:    db "OXYGEN TANK: AIR +1/3",0
gl1:    db "SPEED BOOTS: RUN!",0
gl2:    db "POWER DRILL: ONE-HIT HOLES",0
gl3:    db "FREEZE: ALIENS STOP DEAD",0
gl4:    db "GEMS: 500, 1000, 2000",0
good_anim:
        ld a,(attr_t)
        and 16
        ret nz
        ld hl,good_spr
        ld c,14
        ld b,5
.l:     push bc
        push hl
        ld a,(hl)
        ld b,2
        call dl_add
        pop hl
        pop bc
        inc hl
        ld a,c
        add a,8
        ld c,a
        djnz .l
        ret
good_spr: db SPR_ITO2,SPR_ITBOOT,SPR_ITDRILL,SPR_ITFREEZ,SPR_ITGEM

; ---------------------------------------------------------------------
; DEMO: the real engine with the computer playing
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
        ld (aiprev),a
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
        call level_start
        push af
        xor a
        ld (demo),a
        ld (hurry),a
        ld (lv_kind),a
        ld (inp),a
        ld (inpnew),a
        ld (labelheld),a
        ld a,MODE1
        ld (palbase),a
        call stop_music
        pop af
        ret
demolevels: db 0,1,2,5,6,10,11,15

; ---------------------------------------------------------------------
; HALL OF FAME
hiscore_screen:
        ld a,MODE1
        ld (palbase),a
        call dl_reset
        call do_frame
        xor a
        call cls_bg
        call init_popups
        ld a,3
        ld b,0
        call set_ink
        ld hl,s_hof
        ld e,2
        call print2_c
        call draw_hitab
        ld a,1
        ld (noq),a
        ld de,$0037
        ld bc,$2003
        ld a,$55
        call fill_rect
        ld de,$0038
        ld bc,$2001
        ld a,$AA
        call fill_rect
        xor a
        ld (noq),a
        ld a,2
        ld b,0
        call set_ink
        ld hl,s_play
        ld e,59
        call print_c
        call wipe_show
        ld hl,0
        ld (attr_t),hl
        ld hl,mus_inter_0
        ld de,mus_inter_1
        call play_music
.loop:  call dl_reset
        ; parade: the digger chased by the gang along the girder
        ld a,(attr_t)
        ld b,a
        ld a,150
        sub b
        ld b,a
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_DL0
        ld c,47
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
        ld c,47
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
parade: db SPR_GRUB0,SPR_BRUTE0,SPR_KING0,SPR_GRUBA0
s_hof:  db "HALL OF FAME",0
s_play: db "PRESS FIRE TO PLAY",0

draw_hitab:
        ld ix,hitab
        xor a
        ld (attr_v+5),a
.l:     ld a,(attr_v+5)
        and 1
        ld a,1
        jr z,.c
        ld a,2
.c:     ld b,0
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
        ld (labelheld),a
        call dl_reset
        call do_frame
        ld a,MODE1
        ld (palbase),a
        xor a
        call cls_bg
        ld a,3
        ld b,0
        call set_ink
        ld hl,s_nhs
        ld e,3
        call print2_c
        ld a,1
        ld b,0
        call set_ink
        ld hl,s_ent
        ld e,18
        call print_c
        ld a,2
        ld b,0
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
        ld a,1
        ld b,0
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
; INTERMISSION after world 2's gem dig: "COFFEE BREAK!"
; a grub chases the digger across; then the digger, with a drill,
; chases the whole gang back the other way
inter_floor:
        ld a,1
        ld (noq),a
        ld de,$0034
        ld bc,$2001
        ld a,$55
        call fill_rect
        ld de,$0035
        ld bc,$2001
        ld a,$A5
        call fill_rect
        ld de,$0036
        ld bc,$2001
        ld a,$55
        call fill_rect
        xor a
        ld (noq),a
        ret
run_inter:
        ld hl,s_inter
        call info_page
        call inter_floor
        ld a,2
        ld b,0
        call set_ink
        ld hl,s_inter2
        ld e,58
        call print_c
        call wipe_show
        ld hl,mus_inter_0
        ld de,mus_inter_1
        call play_music
        ld hl,0
        ld (attr_t),hl
.l:     call dl_reset
        ld hl,(attr_t)
        ld a,h
        or a
        jr nz,.back
        ld a,l
        cp 170
        jr nc,.back
        ; act 1: left to right, alien close behind
        ld b,a
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_DR0
        ld c,44
        push bc
        call dl_add_cl
        pop bc
        ld a,b
        sub 14
        jr c,.n1
        ld b,a
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_GRUBA0
        call dl_add_cl
.n1:    jr .f
.back:  ; act 2: right to left, the gang fleeing, digger with the drill
        ld de,170
        or a
        sbc hl,de
        ld a,l
        ld b,a
        ld a,140
        sub b
        jr c,.f
        ld e,a
        ld hl,parade
        ld d,3
.g:     push de
        push hl
        ld b,e
        ld c,44
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,(hl)
        call dl_add_cl
        pop hl
        pop de
        inc hl
        ld a,e
        add a,10
        ld e,a
        dec d
        jr nz,.g
        ld a,e
        add a,6
        ld b,a
        ld c,44
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_DL0
        push bc
        call dl_add_cl
        pop bc
        ld a,b
        sub 9
        ld b,a
        ld c,45
        ld a,SPR_ITDRILL
        call dl_add_cl
.f:     call do_frame
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,420
        or a
        sbc hl,de
        jp nz,.l
        jp stop_music
s_inter: db "COFFEE BREAK!",0
s_inter2: db "NEXT: THE MARS MINES",0

; ENDING: after the mothership
run_ending:
        ld hl,s_end1
        call info_page
        call inter_floor
        ld a,1
        ld b,0
        call set_ink
        ld hl,s_end2
        ld e,17
        call print_c
        ld hl,s_end3
        ld e,25
        call print_c
        ld a,3
        ld b,0
        call set_ink
        ld hl,s_end4
        ld e,58
        call print_c
        call wipe_show
        ld hl,mus_ending_0
        ld de,mus_ending_1
        call play_music
        ld hl,0
        ld (attr_t),hl
.l:     call dl_reset
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
        and 7
        add a,34
        ld c,a
        call random
        and 3
        jr nz,.fc
        inc a
.fc:    call burst
.nf:    ld a,(attr_t)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_DWIN0
        ld bc,$3C2C
        call dl_add
        ; aliens bounce about either side
        ld a,(attr_t)
        rrca
        rrca
        rrca
        rrca
        and 1
        ld e,a
        add a,SPR_GRUB0
        ld bc,$142C
        call dl_add
        ld a,e
        add a,SPR_KING0
        ld bc,$642C
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
        ld hl,score             ; 10000 lap bonus
        ld a,(hl)
        add a,1
        daa
        ld (hl),a
        ld de,0
        jp add_score
s_end1: db "MISSION DONE!",0
s_end2: db "THE MOTHERSHIP IS EMPTY...",0
s_end3: db "...OR IS IT? LAP 2: FASTER!",0
s_end4: db "BONUS 10000",0

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
.p:     pop de
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
