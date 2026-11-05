; =====================================================================
;  attract sequence: title, meet the ghosts, power-ups, demo, hiscores
;  plus intermissions and initials entry
; =====================================================================
attract:
        ld sp,STACKTOP
        xor a
        ld (demo),a
        ld (palbase),a
        ld (flashtim),a
        ld (sirenmode),a
.cycle: call title_screen
        jr nz,.go
        call meet_ghosts
        jr nz,.go
        call powerups_screen
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
        ld (palbase),a
        jp start_game

; ---------------------------------------------------------------------
; TITLE
title_screen:
        call wipe_out
        ld hl,title_pic
        ld de,BGBUF
        call unpack
        call wipe_in
        call clear_erase
        ld hl,mus_title_0
        ld de,mus_title_1
        call play_music
        ld hl,0
        ld (attr_t),hl
        ld a,$FF
        ld (attr_v),a           ; current message index
.loop:  call dl_reset
        call title_scene
        call title_twinkle
        call title_windows
        call title_glint
        call title_message
        ; lightning
        ld hl,(attr_t)
        ld a,l
        cp 150
        jr z,.lt
        cp 160
        jr nz,.nl
.lt:    ld a,h
        or a
        jr nz,.nl
        ld a,6
        ld (flashtim),a
        ld a,SFX_THUNDER
        call play_sfx
.nl:    call do_frame
        call check_start
        ret nz
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,600
        or a
        sbc hl,de
        jr nz,.loop
        call stop_music
        xor a
        ret

; hero & ghosts chase across the graveyard
title_scene:
        ld hl,(attr_t)
        ld a,h
        or a
        jr nz,.ph2
        ld a,l
        cp 240
        jr nc,.ph2
        ; phase 1: hero runs right, ghosts behind
        srl a
        ld (attr_v+1),a         ; hero x
        ld b,a
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_BHERO_0
        ld c,33
        call dl_add_cl
        ; ghosts
        ld hl,title_ghosts
        ld d,4
        ld a,(attr_v+1)
        sub 20
        ld e,a
.g1:    push de
        push hl
        ld a,e
        cp 128
        jr nc,.g1n              ; off screen (negative)
        ld b,e
        call bob
        add a,31
        ld c,a
        pop hl
        push hl
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        jr z,.g1a
        inc hl
.g1a:   ld a,(hl)
        call dl_add_cl
.g1n:   pop hl
        inc hl
        inc hl
        pop de
        ld a,e
        sub 15
        ld e,a
        dec d
        jr nz,.g1
        ret
.ph2:   ; phase 2: hero turns, ghosts flee frightened to the left
        ld hl,(attr_t)
        ld de,240
        or a
        sbc hl,de
        ld a,l
        srl a
        ld b,a
        ld a,118
        sub b
        ret c
        ld (attr_v+1),a
        ld b,a
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_BHERO_L0
        ld c,33
        call dl_add_cl
        ld a,(attr_v+1)
        ld e,a
        ld d,4
.g2:    ld a,e
        sub 16
        ld e,a
        jr c,.g2x
        push de
        ld b,e
        call bob
        add a,30
        ld c,a
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_BFRIGHT_0
        call dl_add_cl
        pop de
        ld a,e
        sub 2
        ld e,a
        jr c,.g2x
        dec d
        jr nz,.g2
.g2x:   ret
title_ghosts:
        db SPR_BGHOST_0,SPR_BGHOST_1
        db SPR_BGHOST_S,SPR_BGHOST_S
        db SPR_BGHOST_D,SPR_BGHOST_D
        db SPR_BGHOST_P,SPR_BEYES
; bob offset 0..3 from framecount + B
bob:
        ld a,(framecount)
        add a,b
        rrca
        rrca
        and 7
        cp 4
        ret c
        cpl
        add a,8
        ret
; add sprite only if x <= 120 (keep big sprites on screen)
dl_add_cl:
        push af
        ld a,b
        cp 117
        jr nc,.no
        pop af
        jp dl_add
.no:    pop af
        ret

; the haunted house's windows flicker (candles moving about inside)
title_windows:
        ld b,NWIN
        ld hl,winlist
.w:     push bc
        push hl
        call random
        pop hl
        cp 30
        jr nc,.n
        push hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        ld e,3
        call dl_pixel
        pop hl
.n:     inc hl
        inc hl
        pop bc
        djnz .w
        ret

title_twinkle:
        ld b,4
.l:     push bc
        ld a,(framecount)
        rrca
        rrca
        rrca
        add a,b
        add a,b
        add a,b
        add a,b
        add a,b
        ld c,a
        ld a,NSTARS
        ld b,a
        ld a,c
.m:     sub b
        jr nc,.m
        add a,b
        add a,a
        ld e,a
        ld d,0
        ld hl,starlist
        add hl,de
        ld b,(hl)
        inc hl
        ld c,(hl)
        ld e,2
        call dl_pixel
        pop bc
        djnz .l
        ret

; a gleam sweeps across the big "2" every 128 frames
title_glint:
        ld a,(framecount)
        and 127
        cp 40
        ret nc
        ld (attr_v+2),a         ; k
        ld e,0                  ; j
.j:     ld a,(attr_v+2)
        add a,70
        sub e
        ld b,a
        ld a,e
        add a,2
        ld c,a
        push de
        push bc
        call getpix_bg
        pop bc
        cp 3
        jr nz,.n
        ld e,1
        call dl_pixel
        ; second pixel to the right for a thicker gleam
        inc b
        push bc
        call getpix_bg
        pop bc
        cp 3
        jr nz,.n
        ld e,1
        call dl_pixel
.n:     pop de
        inc e
        inc e
        ld a,e
        cp 18
        jr c,.j
        ret
; getpix_bg: B = x, C = y -> A = colour in BG buffer
getpix_bg:
        ld a,b
        srl a
        srl a
        ld d,a
        ld e,c
        call scraddr
        res 4,h                 ; VRAM $70xx -> BGBUF $60xx
        ld a,b
        and 3
        inc a
        ld b,a
        ld a,(hl)
.r:     rlca
        rlca
        djnz .r
        and 3
        ret

title_message:
        ld hl,(attr_t)
        ld a,l
        and $3F
        ld b,a                  ; low 6 bits
        ; message index = (t / 128) & 7
        add hl,hl
        ld a,h
        and 7
        ld c,a
        ld a,(attr_v)
        cp c
        jr z,.same
        ld a,c
        ld (attr_v),a
        call .draw
        ret
.same:  ; flash "PRESS FIRE" (message 0) every 16 frames
        ld a,c
        or a
        ret nz
        ld a,(framecount)
        and 15
        ret nz
.draw:  xor a
        ld (textdest),a
        ld d,0
        ld e,57
        ld b,32
        ld c,7
        ld a,$AA
        call fill_rect
        ld a,(attr_v)
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
        ld a,(attr_v)
        or a
        ld a,0
        jr nz,.c
        ld a,(framecount)
        and 16
        ld a,1
        jr z,.c
        ld a,0
.c:     ld b,2
        call set_ink
        pop hl
        ld e,58
        jp print_c
title_msgs: dw tm0,tm1,tm2,tm4,tm3,tm0,tm1,tm2
tm0:    db "PRESS FIRE TO HUNT!",0
tm1:    db "ORIGINAL BY DUBOIS & MCNAMARA",0
tm2:    db "VIBED BY BPM 2026",0
tm4:    db "BLIPS AT THE EDGE: GHOSTS NEAR",0
tm3:    db "HAPPY HAUNTING!",0

; ---------------------------------------------------------------------
; MEET THE GHOSTS
meet_ghosts:
        call wipe_out
        ld a,$AA
        call cls_both
        call clear_erase
        ld a,1
        ld (textdest),a
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_meet
        ld de,$0101
        call print2
        ld hl,0
        ld (attr_t),hl
.loop:  call dl_reset
        ; reveal entries every 60 frames
        ld a,(attr_t)
        ld c,a
        ld a,(attr_t+1)
        or a
        jr nz,.all
        ld a,c
        cp 240
        jr nc,.all
        and 63
        jr nz,.nr
        ld a,c
        rlca
        rlca
        and 3
        call meet_text
        ld a,SFX_POP
        call play_sfx
.nr:    ld a,(attr_t)
        rlca
        rlca
        and 3
        inc a
        jr .spr
.all:   ld a,4
.spr:   ; draw A ghosts
        ld b,a
        ld hl,meet_tab
        ld c,0
.g:     push bc
        push hl
        ld a,(hl)
        ld e,a
        ; peekaboo vanishes now and then
        cp SPR_BGHOST_P
        jr nz,.np
        ld a,(framecount)
        and 64
        jr z,.np
        ld e,SPR_BEYES
.np:    ld a,c
        add a,a
        add a,c
        add a,a
        add a,a                 ; *12
        add a,13
        ld c,a
        ld b,c
        call bob
        add a,c
        sub 1
        ld c,a
        ld b,4
        ld a,e
        call dl_add
        pop hl
        inc hl
        pop bc
        inc c
        djnz .g
        call do_frame
        call check_start
        ret nz
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,480
        or a
        sbc hl,de
        jr nz,.loop
        xor a
        ret
meet_tab: db SPR_BGHOST_0,SPR_BGHOST_S,SPR_BGHOST_D,SPR_BGHOST_P
s_meet: db "MEET THE GHOSTS",0
; A = entry 0..3: print name + description
meet_text:
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,a                 ; *12
        add a,13
        ld e,a
        push de
        ld a,c
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,meet_strs
        add hl,de
        ld a,(hl)
        push hl
        ld b,2
        call set_ink
        pop hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ex de,hl
        pop de
        push de
        push hl
        ld d,5
        call print
        ld a,0
        ld b,2
        call set_ink
        pop hl
.skip:  ld a,(hl)
        inc hl
        or a
        jr nz,.skip
        pop de
        ld a,e
        add a,6
        ld e,a
        ld d,5
        jp print
meet_strs:
        db 1 : dw mg0 : db 0
        db 1 : dw mg1 : db 0
        db 1 : dw mg2 : db 0
        db 1 : dw mg3 : db 0
mg0:    db "GRUMBLE",0,"CHASES YOU. ALWAYS CROSS.",0
mg1:    db "SNEAKY",0,"CUTS YOU OFF UP AHEAD.",0
mg2:    db "DIZZY",0,"WANDERS ABOUT... MOSTLY.",0
mg3:    db "PEEKABOO",0,"NOW YOU SEE HIM, NOW...",0

; ---------------------------------------------------------------------
; POWER-UPS & CONTROLS
powerups_screen:
        call wipe_out
        ld a,$AA
        call cls_both
        call clear_erase
        ld a,1
        ld (textdest),a
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_pow
        ld de,$0701
        call print2
        ld hl,0
        ld (attr_t),hl
.loop:  call dl_reset
        ld a,(attr_t)
        ld c,a
        ld a,(attr_t+1)
        or a
        jr nz,.all
        ld a,c
        cp 7*24
        jr nc,.ctl
        ; reveal a line every 24 frames
        ld b,0
.dv:    sub 24
        jr c,.dd
        inc b
        jr .dv
.dd:    add a,24
        jr nz,.nr
        push bc
        ld a,b
        call pow_line
        ld a,SFX_POP
        call play_sfx
        pop bc
.nr:    ld a,b
        inc a
        jr .spr
.ctl:   cp 7*24
        jr nz,.all
        call pow_controls
.all:   ld a,7
.spr:   ld b,a
        ld hl,pow_icons
        ld c,12
.ic:    push bc
        push hl
        ld a,(hl)
        cp SPR_I_STAR
        jr nz,.ns
        ld a,(framecount)
        and 4
        ld a,SPR_I_STAR
        jr z,.ns
        ld a,SPR_I_STAR2
.ns:    ld b,5
        call dl_add
        pop hl
        inc hl
        pop bc
        ld a,c
        add a,6
        ld c,a
        djnz .ic
        call do_frame
        call check_start
        ret nz
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,480
        or a
        sbc hl,de
        jr nz,.loop
        xor a
        ret
s_pow:  db "POWER UP!",0
pow_icons: db SPR_I_ENERG,SPR_I_SPEED,SPR_I_FREEZE,SPR_I_DECOY,SPR_I_X2,SPR_I_SHIELD,SPR_I_STAR
pow_line:       ; A = line 0..6
        ld c,a
        add a,a
        add a,c
        add a,a                 ; *6
        add a,12
        ld e,a
        ld a,c
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,pow_strs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld a,c
        cp 6
        ld a,1
        jr nz,.c
        ld a,0
.c:     ld b,2
        call set_ink
        pop hl
        pop de
        ld d,3
        jp print
pow_strs: dw pw0,pw1,pw2,pw3,pw4,pw5,pw6
pw0:    db "POWER PILL: EAT THE GHOSTS",0
pw1:    db "SPEED: ZOOM, LEAVE A TRAIL",0
pw2:    db "FREEZE: GHOSTS ON ICE",0
pw3:    db "DECOY: A DUMMY TO CHASE",0
pw4:    db "DOUBLE: TWICE THE POINTS",0
pw5:    db "SHIELD: SHRUG OFF ONE HIT",0
pw6:    db "EAT ALL 4: HUNTER MODE!",0
pow_controls:
        ld a,0
        ld b,2
        call set_ink
        ld hl,s_ctl
        ld e,57
        jp print_c
s_ctl:  db "QAM, OR STICK  P:PAUSE S:SOUND",0

; ---------------------------------------------------------------------
; HALL OF FAME
hiscore_screen:
        call wipe_out
        ld a,$AA
        call cls_both
        call clear_erase
        ld a,1
        ld (textdest),a
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_hof
        ld de,$0401
        call print2
        call draw_hitab
        ld hl,0
        ld (attr_t),hl
        ld hl,mus_inter_0
        ld de,mus_inter_1
        call play_music
.loop:  call dl_reset
        ; parade: hero chased by 4 small ghosts along row 50
        ld a,(attr_t)
        ld b,a
        ld a,140
        sub b
        ld b,a                  ; hero x moves left
        cp 122
        jr nc,.nh
        ld a,(framecount)
        rrca
        and 1
        add a,SPR_HERO_L0
        ld c,52
        call dl_add
.nh:    ld a,(attr_t)
        ld b,a
        ld a,152
        sub b
        ld e,a
        ld d,4
        ld hl,parade
.p:     ld a,e
        cp 122
        jr nc,.pn
        push de
        push hl
        ld b,e
        ld c,52
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,(hl)
        call dl_add
        pop hl
        pop de
.pn:    inc hl
        ld a,e
        add a,9
        ld e,a
        dec d
        jr nz,.p
        ; flashing invitation
        ld a,(framecount)
        and 15
        jr nz,.nf
        xor a
        ld (textdest),a
        ld a,(framecount)
        and 16
        ld a,1
        jr z,.c
        ld a,0
.c:     ld b,2
        call set_ink
        ld hl,s_play
        ld e,58
        call print_c
.nf:    call do_frame
        call check_start
        jr nz,.out
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        ld de,360
        or a
        sbc hl,de
        jp nz,.loop
        xor a
.out:   push af
        call stop_music
        pop af
        ret
parade: db SPR_G_GRUMBLE_2,SPR_G_SNEAKY_2,SPR_G_DIZZY_2,SPR_G_PEEKA_2
s_hof:  db "HALL OF FAME",0
s_play: db "PRESS FIRE TO PLAY",0

draw_hitab:
        ld ix,hitab
        xor a
        ld (attr_v+5),a
.l:     ld a,(attr_v+5)
        ld e,a
        ld d,0
        ld hl,hi_cols
        add hl,de
        ld a,(hl)
        ld b,2
        call set_ink
        ld a,(attr_v+5)
        add a,a
        add a,a
        add a,a
        add a,13
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
        ld d,6
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
        ld d,18
        call print_bcd
        ld de,6
        add ix,de
        ld a,(attr_v+5)
        inc a
        ld (attr_v+5),a
        cp 5
        jr nz,.l
        ret
hi_cols: db 1,0,1,0,1
ranks:  db "1ST",0,"2ND",0,"3RD",0,"4TH",0,"5TH",0

; ---------------------------------------------------------------------
; initials entry after game over
enter_hiscore:
        ; find rank
        ld ix,hitab
        ld c,0
.f:     push ix
        pop hl
        ld de,score
        ld b,3
.cmp:   ld a,(de)
        cp (hl)
        jr c,.lower
        jr nz,.higher
        inc hl
        inc de
        djnz .cmp
        jr .lower               ; equal: not higher
.higher:
        jr .found
.lower: ld de,6
        add ix,de
        inc c
        ld a,c
        cp 5
        jr nz,.f
        ret
.found: ; shift lower entries down
        ld a,c
        ld (attr_v+3),a
        ld a,4
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
        ; screen
        call wipe_out
        ld a,$AA
        call cls_both
        call clear_erase
        ld a,1
        ld (textdest),a
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_nhs
        ld de,$0102
        call print2
        ld a,0
        ld b,2
        call set_ink
        ld hl,s_ent
        ld e,18
        call print_c
        ld a,0
        ld b,2
        call set_ink
        ld hl,s_ent2
        ld e,52
        call print_c
        ld hl,mus_hiscore_0
        ld de,mus_hiscore_1
        call play_music
        xor a
        ld (attr_v+4),a         ; cursor
        ld hl,1500
        ld (attr_t),hl
.loop:  call dl_reset
        ; draw name big
        ld a,1
        ld (textdest),a
        ld a,1
        ld b,2
        call set_ink
        ld hl,nameb
        ld b,3
        ld d,13
.nm:    push bc
        push hl
        push de
        ld a,(hl)
        ld e,30
        call putchar2
        pop de
        pop hl
        pop bc
        inc hl
        inc d
        inc d
        djnz .nm
        ; cursor bar under current letter
        ld a,(attr_v+4)
        add a,a
        add a,13
        ld d,a
        add a,a
        add a,a
        ld b,a
        ld c,42
        ld a,(framecount)
        and 8
        jr z,.nc
        ld a,SPR_I_ENERG
        inc b
        call dl_add
.nc:    ; input
        ld a,(inpnew)
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
.done:  ; store name
        ld de,(hiptr)
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
; INTERMISSIONS
run_intermission:
        push af
        call wipe_out
        ld a,$AA
        call cls_both
        ; ground
        ld a,0
        ld (textdest),a
        ld a,1
        ld (textdest),a
        ld d,0
        ld e,52
        ld b,32
        ld c,12
        ld a,$00
        call fill_rect
        call bg_to_vram
        call clear_erase
        ld hl,mus_inter_0
        ld de,mus_inter_1
        call play_music
        pop af
        push af
        ld hl,bgpat1
        ld de,$0101             ; drifting up and to the left
        cp 2
        jr nz,.p1
        ld hl,bgpat2
        ld de,$01FF             ; drifting down and to the left
.p1:    call bg_begin
        pop af
        call .go
        xor a
        ld (bghook),a
        ret
.go:    cp 2
        jp z,inter2
; --- 1: WHO'S HUNTING WHO?
inter1:
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_i1
        ld e,4
        call print_c
        ld hl,0
        ld (attr_t),hl
.loop:  call dl_reset
        ld hl,(attr_t)
        ld a,h
        or a
        jr nz,.p2
        ld a,l
        cp 200
        jr nc,.p2
        ; hero runs left, ghost chasing
        ld b,a
        srl b
        srl b
        ld a,b
        add a,b
        add a,b                 ; 0.75 px/frame
        ld b,a
        ld a,116
        sub b
        jr c,.h1
        ld b,a
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_BHERO_L0
        ld c,41
        push bc
        call dl_add
        pop bc
        ld a,b
        add a,22
        cp 117
        jr nc,.n1
        ld b,a
        ld a,(framecount)
        rrca
        rrca
        rrca
        and 1
        add a,SPR_BGHOST_0
        ld c,42
        call dl_add
        jr .n1
.h1:
.n1:    ld a,(attr_t)
        cp 60
        jr nz,.nb
        ld a,P_100
        ld de,$5014             ; reuse popup: "BOO!" via custom
        ld hl,popups
        ld (hl),40
        inc hl
        ld (hl),24
        inc hl
        ld (hl),34
        inc hl
        ld (hl),P_BOO
.nb:    jr .pop
.p2:    ; giant hero chases frightened ghost to the right
        ld hl,(attr_t)
        ld de,200
        or a
        sbc hl,de
        ld a,l
        cp 180
        jr nc,.end
        ld b,a
        srl b
        ld a,b
        add a,b
        ld b,a                  ; 1 px/frame
        ld a,b
        cp 117
        jr nc,.n2
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_BFRIGHT_0
        ld c,42
        push bc
        call dl_add
        pop bc
.n2:    ld a,b
        sub 26
        jr c,.n3
        cp 117
        jr nc,.n3
        ld b,a
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_BHERO_0
        ld c,41
        call dl_add
.n3:    ld a,l
        cp 40
        jr nz,.pop
        ld hl,popups
        ld (hl),40
        inc hl
        ld (hl),12
        inc hl
        ld (hl),34
        inc hl
        ld (hl),P_EEK
.pop:   call inter_popups
        call do_frame
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        jp .loop
.end:   call stop_music
        ret
s_i1:   db "WHO'S HUNTING WHO?",0
P_BOO equ 23
P_EEK equ 24
P_ZZZ equ 25
P_WOW equ 26

inter_popups:
        ld hl,popups
        ld b,3
.l:     ld a,(hl)
        or a
        jr z,.n
        dec (hl)
        push hl
        push bc
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld e,(hl)
        call dl_text
        pop bc
        pop hl
.n:     inc hl
        inc hl
        inc hl
        inc hl
        djnz .l
        ret

; --- 2: NIGHT SHIFT
inter2:
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_i2
        ld e,4
        call print_c
        ld hl,0
        ld (attr_t),hl
.loop:  call dl_reset
        ld hl,(attr_t)
        ld a,h
        or a
        jp nz,.end
        ld a,l
        cp 250
        jp nc,.end
        ; sleeping hero (closed mouth) at x=40; after waking he gives chase
        ld a,(attr_t)
        sub 150
        jr nc,.hw
        ld b,40
        ld a,SPR_BHERO_1
        jr .hd
.hw:    add a,40
        cp 116
        jr c,.hw1
        ld a,116
.hw1:   ld b,a
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_BHERO_0
.hd:    ld c,41
        call dl_add
        ld a,(attr_t)
        cp 150
        jr nc,.awake
        ; Zzz popups
        and 31
        jr nz,.nz
        ld hl,popups
        ld (hl),30
        inc hl
        ld (hl),14
        inc hl
        ld (hl),30
        inc hl
        ld (hl),P_ZZZ
.nz:    ; ghosts tiptoe from the right
        ld a,(attr_t)
        srl a
        srl a
        ld b,a
        ld a,116
        sub b                   ; x of first ghost
        ld e,a
        ld d,4
        ld hl,parade
.g:     push de
        push hl
        ld b,e
        ld a,(framecount)
        and 16
        ld c,44
        jr z,.gy
        dec c
.gy:    ld a,(hl)
        sub 2                   ; facing left frames (dir L = +2 from R base... use base)
        add a,2
        call dl_add
        pop hl
        pop de
        inc hl
        ld a,e
        add a,8
        cp 122
        jr nc,.gx
        ld e,a
        dec d
        jr nz,.g
.gx:    jp .fr
.awake: ; WOW! ghosts frightened flee right, hero hops
        ld a,(attr_t)
        cp 150
        jr nz,.na
        ld hl,popups
        ld (hl),40
        inc hl
        ld (hl),11
        inc hl
        ld (hl),30
        inc hl
        ld (hl),P_WOW
        ld a,8
        ld (flashtim),a
        ld a,SFX_POWER
        call play_sfx
.na:    ld a,(attr_t)
        sub 150
        ld b,a
        ld a,116-38+76
        ; ghosts start at x=78 and run right at 1.5 px/f
        ld a,b
        srl a
        add a,b
        srl a
        add a,b
        add a,64
        ld e,a
        ld d,4
.f:     ld a,e
        cp 120
        jr nc,.fx
        push de
        ld b,e
        ld c,44
        ld a,(framecount)
        rrca
        rrca
        and 1
        add a,SPR_FRIGHT_0
        call dl_add
        pop de
        ld a,e
        add a,8
        ld e,a
        dec d
        jr nz,.f
.fx:
.fr:    call inter_popups
        call do_frame
        ld hl,(attr_t)
        inc hl
        ld (attr_t),hl
        jp .loop
.end:   ld a,1
        ld b,2
        call set_ink
        ld a,24
        ld (bg_cap),a           ; the backdrop leaves the caption alone
        ld hl,s_i2b
        ld e,24
        call print_c
        ld b,90
.w:     push bc
        call blank_frame
        pop bc
        djnz .w
        call stop_music
        ret
s_i2:   db "THE NIGHT SHIFT",0
s_i2b:  db "GHOSTS... SO JUMPY!",0
