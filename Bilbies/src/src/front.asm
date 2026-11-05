; ---------------------------------------------------------------------------
; Front end: title (live bilby scene + music), attract demos, level select,
; briefing, results
; ---------------------------------------------------------------------------
front_main:
        ld a,1
        ld (v_unlock),a         ; level 1 open (index 0)
.title: call title_screen       ; A = 0 play, 1 attract
        or a
        jr z,.sel
        call attract
        jr .title
.sel:   call level_select       ; NZ = back to the title
        jr nz,.title
.brief: call briefing
        jr nz,.title
        xor a
        ld (v_demo),a
        ld (v_test),a
        ld (v_quit),a
        ld a,(v_lvl)
        call level_load
        call play_level
        ld a,(v_quit)
        or a
        jr nz,.sel
        call results            ; A = 0 next, 1 retry, 2 menu
        or a
        jr z,.next
        dec a
        jr z,.brief
        jr .sel
.next:  ld a,(v_lvl)
        inc a
        cp LVCOUNT
        jr c,.n2
        call finale
        jr .title
.n2:    ld (v_lvl),a
        inc a
        ld hl,v_unlock
        cp (hl)
        jr c,.brief
        ld (hl),a
        jr .brief

; ===========================================================================
; title screen
; ===========================================================================
TBG         equ BACK            ; title background: 44 rows x 32

title_screen:
        di
        xor a
        call set_mode1
        ld a,LV_TITLE
        call level_load
        xor a
        ld (v_scry),a
        ld a,2
        ld (v_spawnfl),a        ; everyone floats on the title
        ld a,1
        ld (v_demo),a
        ld (v_title),a
        xor a
        ld (v_scrb),a
        ld hl,NOSCRIPT
        call demo_start
        ; background: terrain + hatch + burrow, drawn through BACK
        call title_bg
        ld hl,TBG
        ld de,VRAM
        ld bc,PFH*32
        ldir
        ; menu area
        ld a,BG
        ld b,PFH
        ld c,20
        call fill_rows
        call title_menu
        ld a,$FF
        ld hl,v_pcol
        ld b,NCRT
.pc:    ld (hl),a
        inc hl
        djnz .pc
        ld hl,0
        ld (v_idle),hl
        xor a
        ld (v_tframe),a
        ld (v_infoi),a
        ld hl,SONG_T
        call mus_init
        call waitrel
        ld a,(v_tick)
        ld (v_last),a
.loop:  ; ---- one frame: a slice of work, then music until the next sync
        di
        call mus_tick
        ld a,(v_tframe)
        inc a
        ld (v_tframe),a
        rra
        jr c,.odd
        call game_tick
        call title_loop
        jr .w
.odd:   call render_dirty
        call title_flash
.w:     ld a,(v_musicon)
        or a
        jr z,.nm
        call mus_frame
        jr .k
.nm:    ei
        ld a,1
        call frame_sync
.k:     ; keys
        call title_keys
        cp $FF
        jr z,.loop
        push af
        call silence
        xor a
        ld (v_title),a
        ld (v_demo),a
        ld a,(v_lvl)
        pop af
        ret

; restart the scene when everyone is home
title_loop:
        ld a,(v_end)
        or a
        ret z
        call game_init
        ld a,2
        ld (v_spawnfl),a
        ret

silence:
        ld a,(v_spkoff)
        ld (LATCH),a
        call snd_init
        ld a,(v_tick)
        ld (v_last),a
        ei
        ret

; A = $FF carry on, 0 play, 1 attract
title_keys:
        ld hl,(v_idle)
        inc hl
        ld (v_idle),hl
        ld de,50*30             ; 30 seconds
        or a
        sbc hl,de
        ld a,1
        ret nc
        ; FIRE / SPACE
        call read_controls
        and $10
        jr z,.nf
        xor a
        ret
.nf:    ; T trainer, K music, S sound
        ld a,(KR0)
        bit 0,a                 ; T
        jr nz,.nt
        ld hl,v_train
        call .tog
        jr .dn
.nt:    ld a,(KR1)
        bit 1,a
        jr nz,.ns
        ld hl,v_sfxon
        call .tog
        jr .dn
.ns:    ld a,(KR6)
        bit 2,a                 ; RETURN plays too
        jr nz,.nr
        xor a
        ret
.nr:    ld a,(KR7)
        bit 3,a                 ; K: music on/off
        jr nz,.nk
        ld hl,v_musicon
        call .tog
        jr .dn
.nk:    ld a,$FF
        ret
.dn:    call title_menu
        call silence
        ld a,(v_title)          ; the tune runs with interrupts off; waitrel needs them
        push af
        xor a
        ld (v_title),a
        ei
        call waitrel
        pop af
        ld (v_title),a
        ld hl,SONG_T
        call mus_init
        di
        ld hl,0
        ld (v_idle),hl
        ld a,$FF
        ret
.tog:   ld a,(hl)
        xor 1
        ld (hl),a
        ret

; menu text under the scene
title_menu:
        ld a,C_YEL
        ld b,C_BLU
        call txt_colour
        ld a,46
        ld hl,s_t1
        call print_c
        ld a,C_GRN
        ld b,C_BLU
        call txt_colour
        ld a,59
        ld c,0
        call scr_addr
        ld hl,s_t3
        call print
        ld a,(v_train)
        ld hl,s_off
        or a
        jr z,.t
        ld hl,s_on
.t:     call print
        ld hl,s_t4
        call print
        ld a,(v_musicon)
        ld hl,s_off
        or a
        jr z,.m
        ld hl,s_on
.m:     call print
        ld hl,s_t5
        call print
        ld a,(v_sfxon)
        ld hl,s_off
        or a
        jr z,.s
        ld hl,s_on
.s:     jp print
s_t1:   db "PRESS FIRE TO PLAY",0
s_t3:   db "T TRAIN:",0
s_t4:   db " K MUSIC:",0
s_t5:   db " S FX:",0
s_on:   db "ON ",0
s_off:  db "OFF",0

; the info line (row 52) changes every 4 seconds; "PRESS FIRE" flashes
title_flash:
        ld a,(v_tframe)
        and $7F
        cp 1
        ret nz
        ld a,(v_infoi)
        inc a
        cp 6
        jr c,.i
        xor a
.i:     ld (v_infoi),a
        add a,a
        ld l,a
        ld h,0
        ld de,INFOS
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld a,BG
        ld b,52
        ld c,5
        call fill_rows
        ld a,(v_infoi)
        and 1
        ld a,C_YEL
        jr z,.c
        ld a,C_RED
.c:     ld b,C_BLU
        call txt_colour
        pop hl
        ld a,52
        jp print_c
INFOS:  dw s_i0,s_i1,s_i2,s_i3,s_i4,s_i5
s_i0:   db "GUIDE THE BILBIES HOME",0
s_i1:   db "Q A O P / JOYSTICK: CURSOR",0
s_i2:   db "FIRE: GIVE A SKILL  ARM: NEXT",0
s_i3:   db "1-8 SKILL  H PAUSE  N N NUKE",0
s_i4:   db ", . RELEASE RATE",0
s_i5:   db "VZ300 2026  BENNVENN 128K",0

; title background into TBG: terrain + objects (stride 32)
title_bg:
        ld a,(v_hatch)
        push af
        ld a,16
        ld (v_hatch),a          ; draw the hatch open
        call comp_terrain
        call draw_objects
        pop af
        ld (v_hatch),a
        ; BACK (stride 36, from byte 2) -> TBG (stride 32): in place, forwards
        ld hl,BACK+2
        ld de,TBG
        ld a,PFH
.r:     ld bc,32
        ldir
        inc hl
        inc hl
        inc hl
        inc hl
        dec a
        jr nz,.r
        ret

; ---- title rendering straight to the screen: restore old rects, draw new ----
render_dirty:
        ld a,VROW>>8
        ld (ds_rows),a
        ; restore
        ld hl,v_pcol
        ld de,v_prow2
        ld b,NCRT
.r:     ld a,(hl)
        cp $FF
        jr z,.rn
        push bc
        push hl
        push de
        ld c,a
        ld a,(de)
        ld b,a
        call restore_rect
        pop de
        pop hl
        pop bc
.rn:    inc hl
        inc de
        djnz .r
        ; draw
        ld ix,CRT
        ld hl,v_pcol
        ld b,NCRT
.d:     push bc
        push hl
        ld (hl),$FF
        ld a,(ix+C_ST)
        or a
        jr z,.dn
        cp ST_GONE
        jr nc,.dn
        ld a,(ix+C_XL)
        sub 3
        ld (v_sx),a
        ld b,a
        add a,8
        rrca
        rrca
        and $3F
        sub 2
        ld (hl),a               ; byte column
        ld de,NCRT
        add hl,de
        ld a,(ix+C_Y)
        sub 6
        ld (hl),a               ; top row
        call frame_of
        ld a,(v_sx)
        ld b,a
        ld a,(ix+C_Y)
        sub 6
        ld c,a
        call draw_spr
.dn:    pop hl
        pop bc
        inc hl
        ld de,CSZ
        add ix,de
        djnz .d
        ld a,BROW>>8
        ld (ds_rows),a
        ret

; C = byte column (may be -1..31), B = top row (signed): 3 bytes x 7 rows
restore_rect:
        ld e,7
.r:     ld a,b
        cp PFH
        jr nc,.n
        push bc
        push de
        ; TBG + row*32 + col
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push hl
        ld de,TBG
        add hl,de
        ex (sp),hl
        ld de,VRAM
        add hl,de
        ex de,hl                ; DE = screen row
        pop hl                  ; HL = TBG row
        ld b,3
.c:     ld a,c
        cp 32
        jr nc,.cs
        push hl
        push de
        ld a,l
        add a,c
        ld l,a
        jr nc,.c1
        inc h
.c1:    ld a,e
        add a,c
        ld e,a
        jr nc,.c2
        inc d
.c2:    ld a,(hl)
        ld (de),a
        pop de
        pop hl
.cs:    inc c
        djnz .c
        pop de
        pop bc
.n:     inc b
        dec e
        jr nz,.r
        ret

; ===========================================================================
; attract mode: a few levels played by script
; ===========================================================================
attract:
        ld a,(v_lvl)
        push af
        call .run
        pop af
        ld (v_lvl),a
        ret
.run:   ld a,(v_demoidx)
        inc a
        cp NDEMO
        jr c,.d
        xor a
.d:     ld (v_demoidx),a
        ld l,a
        ld h,0
        ld de,DEMOS
        add hl,de
        ld a,(hl)               ; level
        ld (v_lvl),a
        call level_load
        ld a,(v_lvl)
        call script_get
        call demo_start
        ld a,1
        ld (v_demo),a
        xor a
        ld (v_quit),a
        ld (v_test),a
        call play_level
        xor a
        ld (v_demo),a
        call waitrel
        ret

; ===========================================================================
; level select / briefing
; ===========================================================================
; NZ = back
level_select:
        call waitrel
.redraw:
        ld a,(v_lvl)
        call level_load
        call make_preview
        call brief_page
        ld a,C_GRN
        ld b,C_BLU
        call txt_colour
        ld a,58
        ld hl,s_sel1
        call print_c
        ld a,(v_lvl)
        call locked
        jr z,.k
        ld a,C_RED
        ld b,C_BLU
        call txt_colour
        ld a,40
        ld hl,s_lock
        call print_c
.k:     call waitrel
.key:   ld a,1
        call frame_sync
        call read_controls
        ld c,a
        bit 4,c
        jr nz,.fire
        ld a,(KR0)
        bit 4,a
        jr nz,.nq
        ld a,(KR1)
        bit 2,a
        jr z,.nq                ; (CTRL+Q is ignored here)
        or 1
        ret                     ; Q: back to the title
.nq:    ld a,c
        and $0F
        jr z,.key
        ld a,(v_lvl)
        bit 0,c
        jr z,.n0
        or a
        jr z,.key
        dec a
        jr .set
.n0:    bit 1,c
        jr z,.n1
        inc a
        cp LVCOUNT
        jr nc,.key
        jr .set
.n1:    bit 3,c                 ; up: previous rating
        jr z,.n2
        sub PERRATE
        jr c,.key
        jr .set
.n2:    add a,PERRATE           ; down: next rating
        cp LVCOUNT
        jr nc,.key
.set:   ld (v_lvl),a
        ld a,SFX_CLICK
        call sfx_play
        jp .redraw
.fire:  ld a,(v_lvl)
        call locked
        jr nz,.key
        xor a
        ret
s_sel1: db "O P LEVEL  Q A RATING  FIRE",0
s_lock: db "  LOCKED - PLAY ON TO OPEN  ",0

; NZ if level A can't be played yet
locked:
        ld c,a
        ld a,(v_train)
        or a
        jr nz,.open
        ld a,(v_unlock)
        dec a
        cp c
        jr c,.shut
.open:  xor a
        ret
.shut:  or 1
        ret

; briefing before playing: NZ = back to the title
briefing:
        ld a,(v_lvl)
        call level_load
        call make_preview
        call brief_page
        ld a,C_YEL
        ld b,C_BLU
        call txt_colour
        ld a,58
        ld hl,s_brf
        call print_c
        ld hl,SONG_J
        call jingle_wait        ; plays until a key; NZ if Q
        ret
s_brf:  db "PRESS FIRE",0

; the page: rating + number, name, preview, the numbers
brief_page:
        di
        call cls_blue
        ; "TRICKY 4"
        ld a,(v_lvl)
        ld c,0
.r:     sub PERRATE
        jr c,.rd
        inc c
        jr .r
.rd:    add a,PERRATE+1
        ld (v_res),a            ; number within the rating
        ld a,c
        add a,a
        ld l,a
        ld h,0
        ld de,RATINGS
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,sbuf
.cp:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.cp
        dec de
        ld a,' '
        ld (de),a
        inc de
        push de
        ld a,(v_res)
        call num_str
        pop de
.c2:    ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.c2
        ld a,C_YEL
        ld b,C_BLU
        call txt_colour
        ld a,2
        ld hl,sbuf
        call print2_c
        ; name
        ld a,C_GRN
        ld b,C_BLU
        call txt_colour
        ld a,14
        ld hl,(v_lname)
        call print_c
        ; preview with a frame
        ld a,21
        call show_preview
        ; numbers
        ld a,C_YEL
        ld b,C_BLU
        call txt_colour
        ld hl,sbuf
        ld (hl),0
        ld de,s_b1
        call strcat
        ld a,(v_ncrt)
        call num_str
        call strcat_hl
        ld de,s_b2
        call strcat
        ld a,(v_tosave)
        ld l,a
        ld a,(v_ncrt)
        push af
        ld a,l
        ld (v_saved),a
        pop af
        call pct_saved
        call num_str
        call strcat_hl
        ld de,s_pc
        call strcat
        ld a,45
        ld hl,sbuf
        call print_c
        ld hl,sbuf
        ld (hl),0
        ld de,s_b3
        call strcat
        ld a,(v_rate)
        call num_str
        call strcat_hl
        ld de,s_b4
        call strcat
        ld a,(v_min)
        call num_str
        call strcat_hl
        ld de,s_b5
        call strcat
        ld a,51
        ld hl,sbuf
        call print_c
        xor a
        ld (v_saved),a
        ret
s_b1:   db "BILBIES ",0
s_b2:   db "   SAVE ",0
s_pc:   db "%",0
s_b3:   db "RATE ",0
s_b4:   db "   TIME ",0
s_b5:   db " MIN",0
RATINGS: dw r_0,r_1,r_2,r_3
r_0:    db "MILD",0
r_1:    db "TRICKY",0
r_2:    db "TOUGH",0
r_3:    db "WILD",0

; append string DE to sbuf / append HL
strcat: ex de,hl
strcat_hl:
        push hl
        ld hl,sbuf
.e:     ld a,(hl)
        or a
        jr z,.f
        inc hl
        jr .e
.f:     ex de,hl
        pop hl
.c:     ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.c
        ret

; play a song until a key (or its end, then keep waiting). NZ if Q pressed.
jingle_wait:
        call mus_init
        call waitrel
.l:     di
        call mus_tick
        ld a,(v_musicon)
        or a
        jr z,.q
        ld a,(mus_endf)
        or a
        jr nz,.q
        call mus_frame
        jr .k
.q:     call snd_init           ; (the tune leaves its own values in B' C')
        ei
        ld a,1
        call frame_sync
.k:     call read_controls
        and $10
        jr nz,.go
        ld a,(KR0)
        bit 4,a
        jr nz,.l
        call silence
        or 1
        ret
.go:    call silence
        call waitrel
        xor a
        ret

; ===========================================================================
; results: A = 0 next, 1 retry, 2 menu
; ===========================================================================
results:
        di
        call cls_blue
        call pct_saved
        ld (v_res),a
        ld c,a
        ld a,(v_tosave)
        ld l,a
        ld a,(v_saved)
        cp l
        ld a,0
        jr nc,.ok
        inc a
.ok:    ld (v_end),a            ; 0 passed, 1 failed
        ; headline
        ld hl,s_r0
        ld a,(v_end)
        or a
        jr nz,.h
        ld hl,s_r1
        ld a,(v_res)
        cp 100
        jr c,.h
        ld hl,s_r2
.h:     push hl
        ld a,C_YEL
        ld b,C_BLU
        call txt_colour
        pop hl
        ld a,4
        call print2_c
        ; numbers
        ld a,C_GRN
        ld b,C_BLU
        call txt_colour
        ld hl,sbuf
        ld (hl),0
        ld de,s_r3
        call strcat
        ld a,(v_res)
        call num_str
        call strcat_hl
        ld de,s_pc
        call strcat
        ld a,20
        ld hl,sbuf
        call print_c
        ld hl,sbuf
        ld (hl),0
        ld de,s_r4
        call strcat
        ld a,(v_saved)
        push af
        ld a,(v_tosave)
        ld (v_saved),a
        call pct_saved
        ld c,a
        pop af
        ld (v_saved),a
        ld a,c
        call num_str
        call strcat_hl
        ld de,s_pc
        call strcat
        ld a,27
        ld hl,sbuf
        call print_c
        ; comment
        ld a,C_YEL
        ld b,C_BLU
        call txt_colour
        ld a,(v_end)
        ld hl,s_c1
        or a
        jr z,.cm
        ld hl,s_c0
.cm:    ld a,37
        call print_c
        ; options
        ld a,C_GRN
        ld b,C_BLU
        call txt_colour
        ld hl,s_o1
        ld a,(v_end)
        or a
        jr z,.o
        ld hl,s_o2
.o:     ld a,52
        call print_c
        ld a,58
        ld hl,s_o3
        call print_c
        ld hl,SONG_W
        ld a,(v_end)
        or a
        jr z,.s
        ld hl,SONG_L
.s:     call jingle_wait
        ld a,2
        ret nz
        ld a,(v_end)
        ret                     ; 0 next / 1 retry
s_r0:   db "OH DEAR",0
s_r1:   db "WELL DONE",0
s_r2:   db "PERFECT!",0
s_r3:   db "YOU RESCUED ",0
s_r4:   db "YOU NEEDED  ",0
s_c0:   db "HAVE ANOTHER GO",0
s_c1:   db "ON TO THE NEXT BURROW",0
s_o1:   db "FIRE: NEXT LEVEL",0
s_o2:   db "FIRE: TRY AGAIN",0
s_o3:   db "Q: LEVEL MENU",0

; all levels done
finale:
        di
        call cls_blue
        ld a,C_YEL
        ld b,C_BLU
        call txt_colour
        ld a,10
        ld hl,s_f0
        call print2_c
        ld a,C_GRN
        ld b,C_BLU
        call txt_colour
        ld a,30
        ld hl,s_f1
        call print_c
        ld a,38
        ld hl,s_f2
        call print_c
        ld hl,SONG_W
        call jingle_wait
        ret
s_f0:   db "BRILLIANT!",0
s_f1:   db "EVERY BURROW CONQUERED",0
s_f2:   db "THE BILBIES THANK YOU",0

; A = level -> HL = its solution script, fetched from bank B into SCRBUF
script_get:
        add a,a
        ld l,a
        ld h,0
        ld de,SCRTAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        or h
        jr nz,.got
        ld hl,NOSCRIPT
        ret
.got:   di
        ld a,3
        out (MAPPER),a
        ld c,(hl)
        inc hl
        ld b,0
        ld de,SCRBUF
        ldir
        ld a,1
        out (MAPPER),a
        call int_poll
        ld hl,SCRBUF
        ret

; ---- test entry (emulator): play v_lvl with its solution script -------------
test_run:
        ld sp,STACKTOP
        call snd_init
        ei
        ld a,(v_lvl)
        call level_load
        ld a,(v_lvl)
        call script_get
        call demo_start
        ld a,1
        ld (v_demo),a
        ld (v_test),a
        call play_level
        ld a,$AA
        ld (v_res),a
.h:     ld a,1
        call frame_sync
        jr .h
