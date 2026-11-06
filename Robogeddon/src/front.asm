; =====================================================================
;  ROBOGEDDON - attract sequence, title, menus, high scores
;  Each screen draws its still parts once into the backdrop (BD) and,
;  every frame, copies that in and adds only what moves.
; =====================================================================

attract:
        xor     a
        ld      (demo),a
        ld      (att_step),a
        call    front_setup
        ld      hl,mus_title
        ld      a,1
        call    start_music
.loop:  call    front_setup
        ld      a,(att_step)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,att_seq
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        call    jp_hl
        jr      nz,.start
        ld      a,(att_step)
        inc     a
        and     7
        ld      (att_step),a
        ld      a,(music_on)
        or      a
        jr      nz,.loop
        ld      hl,mus_title
        ld      a,1
        call    start_music
        jr      .loop
.start: ld      a,SFX_SELECT
        call    play_sfx
        call    save_records        ; keeps the control / sound choice
        call    run_game
        jp      attract

att_seq:
        dw      scr_title, scr_story, scr_gallery, scr_hiscores
        dw      scr_title, scr_controls, scr_demo, scr_hiscores

front_setup:
        ld      a,MODE1
        ld      (next_vmode),a
        xor     a
        ld      (clip_top),a
        ld      (tlimit),a
        ld      (bd_dirty),a
        ld      a,64
        ld      (clip_bot),a
        ld      a,$FF
        ld      (hs_pos),a
        ret

; run_game: a real game, then the high-score check
run_game:
        call    stop_music
        call    new_game
        xor     a
        ld      (demo),a
        call    game_clip
        call    play_game
        call    stop_music
        call    front_setup
        ld      a,(trainer)
        or      a
        ret     nz
        jp      check_hiscore

game_clip:
        ld      a,8
        ld      (clip_top),a
        ld      a,63
        ld      (clip_bot),a
        ret

; att_keys: handles 1/2/3/T/M on the front screens -> NZ = start a game
att_keys:
        ld      a,(keysnew)
        bit     0,a
        jr      z,.k0
        call    cycle_sound
        ld      a,1
        ld      (bd_dirty),a
.k0:    ld      a,(keysnew)
        bit     3,a
        jr      z,.k1
        ld      a,(trainer)
        xor     1
        ld      (trainer),a
        ld      a,1
        ld      (bd_dirty),a
        ld      a,SFX_SELECT
        call    play_sfx
.k1:    ld      a,(keysnew)
        ld      c,0
        bit     4,a
        jr      nz,.set
        inc     c
        bit     5,a
        jr      nz,.set
        inc     c
        bit     6,a
        jr      z,.st
.set:   ld      a,c
        ld      (ctl_mode),a
        ld      a,60
        ld      (banner_t),a
        ld      a,1
        ld      (bd_dirty),a
        ld      a,SFX_SELECT
        call    play_sfx
.st:    ld      a,(mnunew)
        and     $10
        ret

; att_frame: shared end of every front-screen frame
;   draws the control banner, presents, reads keys, counts down scr_t
;   -> NZ = start pressed;  Z,C = time's up;  Z,NC = carry on
att_frame:
        ld      a,(banner_t)
        or      a
        jr      z,.nb
        dec     a
        ld      (banner_t),a
        ld      c,55
        ld      b,9
        xor     a
        call    fill_rows
        ld      c,55
        ld      b,1
        ld      a,$AA
        call    fill_rows
        ld      c,63
        ld      b,1
        ld      a,$AA
        call    fill_rows
        call    ctl_text
        ld      hl,txtbuf
        ld      c,57
        ld      a,$FF
        call    text3c
.nb:    call    present
        call    att_keys
        ret     nz
        ld      hl,(scr_t)
        dec     hl
        ld      (scr_t),hl
        ld      a,h
        or      l
        jr      z,.to
        xor     a
        ret
.to:    scf
        ret

; ctl_text -> txtbuf = "CONTROLS: <mode>"
ctl_text:
        ld      de,txtbuf
        ld      hl,s_ctl
        call    strcpy
        ld      a,(ctl_mode)
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,mode_names
        add     hl,bc
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        jp      strcpy

; marquee: rows 0 and 63 run in opposite directions
marquee:
        ld      c,0
        call    rowaddr
        ld      a,(gtick)
        call    .row
        ld      c,63
        call    rowaddr
        ld      a,(gtick)
        neg
.row:   ld      e,a
        ld      b,32
.t:     ld      a,e
        and     3
        add     a,low marq_pat
        push    hl
        ld      l,a
        ld      h,high marq_pat
        ld      a,(hl)
        pop     hl
        ld      (hl),a
        inc     hl
        inc     e
        djnz    .t
        ret

; ---------------------------------------------------------------------
; TITLE
; ---------------------------------------------------------------------
scr_title:
        ld      hl,300
        ld      (scr_t),hl
        xor     a
        ld      (logo_t),a
        call    bd_begin
        call    bd_end
.l:     call    bd_copy
        call    marquee
        ld      a,(logo_t)
        cp      42
        jr      nc,.set
        call    draw_logo           ; still flying
        jr      .adv
.set:   jr      nz,.nb
        ld      a,1                 ; just settled: build the backdrop
        ld      (bd_dirty),a
.nb:    ld      a,(bd_dirty)
        or      a
        call    nz,title_bd
        ld      hl,s_2085
        ld      c,21
        ld      a,(gtick)
        and     8
        ld      a,$AA
        jr      z,.c1
        ld      a,$FF
.c1:    call    text2xc
        ld      a,(gtick)
        and     8
        jr      z,.adv
        ld      hl,s_start
        ld      c,52
        ld      a,$55
        call    text3c
.adv:   ld      hl,logo_t
        ld      a,(hl)
        cp      60
        jr      nc,.x
        inc     (hl)
.x:     call    att_frame
        ret     nz
        ret     c
        jr      .l

title_bd:
        xor     a
        ld      (bd_dirty),a
        call    bd_begin
        call    draw_logo
        ld      hl,s_vibed
        ld      c,33
        ld      a,$55
        call    text3c
        call    ctl_text
        ld      hl,txtbuf
        ld      c,40
        ld      a,$FF
        call    text3c
        ld      hl,s_modes
        ld      c,46
        ld      a,$AA
        call    text3c
        call    opts_line
        jp      bd_end

; opts_line: "T TRAINER OFF  M SOUND ALL" at the bottom
opts_line:
        ld      de,txtbuf
        ld      hl,s_trn_opt
        call    strcpy
        ld      a,(trainer)
        or      a
        ld      hl,s_off
        jr      z,.t
        ld      hl,s_on
.t:     call    strcpy
        ld      hl,s_snd_opt
        call    strcpy
        ld      a,(snd_mode)
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,snd_names
        add     hl,bc
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        call    strcpy
        ld      hl,txtbuf
        ld      c,57
        ld      a,$AA
        jp      text3c

; draw_logo: ROBOGEDDON flies up as a bunch, then spreads out
draw_logo:
        ld      b,0
.l:     push    bc
        ld      a,b
        ld      (tmp1),a
        ; bunch x = 47 + 2i, final x = 4 + 12i
        add     a,a
        add     a,47
        ld      d,a
        ld      a,b
        add     a,a
        add     a,b
        add     a,a
        add     a,a
        add     a,4
        ld      e,a
        ld      a,(logo_t)
        cp      18
        jr      nc,.spread
        ; phase 1: rise from y 46 to 4, at bunch x
        call    ease
        ld      l,a
        ld      a,42
        call    mulfrac
        ld      c,a
        ld      a,46
        sub     c
        ld      c,a
        ld      b,d
        jr      .draw
.spread:
        sub     18
        cp      24
        jr      c,.s1
        ld      a,24
.s1:    call    ease24
        ld      l,a
        ld      a,e
        sub     d
        jr      c,.neg
        call    mulfrac
        add     a,d
        jr      .sx
.neg:   neg
        call    mulfrac
        ld      c,a
        ld      a,d
        sub     c
.sx:    ld      b,a
        ld      c,4
.draw:  ld      a,(tmp1)
        ld      e,a
        ld      d,0
        ld      hl,logo_letters
        add     hl,de
        ld      a,(hl)
        call    draw_frame
        pop     bc
        inc     b
        ld      a,b
        cp      10
        jr      c,.l
        ret

; ease: A = t (0..17) -> A = 0..64 ease-out ; ease24: A = 0..24 -> 0..64
ease:
        push    de
        ld      e,a
        ld      d,0
        ld      hl,ease18
        add     hl,de
        ld      a,(hl)
        pop     de
        ret
ease24:
        push    de
        ld      e,a
        ld      d,0
        ld      hl,ease25
        add     hl,de
        ld      a,(hl)
        pop     de
        ret

; mulfrac: A (0..127) * L (0..64) / 64 -> A   (keeps D,E)
mulfrac:
        push    de
        ld      e,a
        ld      d,0
        ld      h,d
        ld      b,8
        ld      a,l
        ld      l,d
.m:     add     hl,hl
        rla
        jr      nc,.n
        add     hl,de
.n:     djnz    .m
        add     hl,hl
        add     hl,hl
        ld      a,h
        pop     de
        ret

; ---------------------------------------------------------------------
; STORY: typed out a letter at a time, with a robot chase underneath
; ---------------------------------------------------------------------
scr_story:
        ld      hl,420
        ld      (scr_t),hl
        call    bd_begin
        call    marquee_bd
        ld      hl,s_story_h
        ld      c,3
        ld      a,$FF
        call    text3c
        call    bd_end
        ld      hl,story
        ld      (st_ptr),hl
        ld      a,1
        ld      (st_col),a
        ld      a,10
        ld      (st_y),a
.l:     call    bd_copy
        call    marquee
        ; type the next letter into the backdrop
        ld      hl,(st_ptr)
        ld      a,(hl)
        cp      $FF
        jr      z,.ch
        inc     hl
        ld      (st_ptr),hl
        or      a
        jr      nz,.chr
        ld      a,1
        ld      (st_col),a
        ld      a,(st_y)
        add     a,6
        ld      (st_y),a
        jr      .ch
.chr:   ld      (txtbuf),a
        xor     a
        ld      (txtbuf+1),a
        call    bd_open
        ld      hl,txtbuf
        ld      a,(st_col)
        ld      b,a
        ld      a,(st_y)
        ld      c,a
        ld      a,$55
        call    text3
        call    bd_end
        ld      hl,st_col
        inc     (hl)
        ld      a,(txtbuf)
        cp      ' '
        ld      a,SFX_TICK
        call    nz,play_sfx
.ch:    ; the chase: a human runs, droids follow
        ld      a,(gtick)
        ld      (logo_t),a
        ld      b,0
.cr:    push    bc
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      c,a
        ld      a,(logo_t)
        sub     c
        and     127
        cp      120
        jr      nc,.cn
        ld      d,a
        ld      a,b
        or      a
        ld      a,(gtick)
        jr      nz,.dr
        rra
        and     1
        add     a,F_KID0
        jr      .dd
.dr:    rra
        rra
        and     1
        add     a,F_GRUNT0
.dd:    ld      b,d
        ld      c,57
        call    draw_frame
.cn:    pop     bc
        inc     b
        ld      a,b
        cp      6
        jr      c,.cr
        call    att_frame
        ret     nz
        ret     c
        jp      .l

marquee_bd:
        ret

; ---------------------------------------------------------------------
; GALLERY: meet the robots
; ---------------------------------------------------------------------
scr_gallery:
        ld      hl,330
        ld      (scr_t),hl
        xor     a
        ld      (logo_t),a
        call    bd_begin
        ld      hl,s_meet
        ld      c,1
        ld      a,$FF
        call    text2xc
        call    bd_end
.l:     call    bd_copy
        ld      ix,gallery
        ld      b,0
.e:     push    bc
        ; entry i appears at t = i*12 and takes 10 frames to materialise
        ld      a,b
        add     a,a
        add     a,a
        ld      c,a
        add     a,a
        add     a,c
        ld      c,a
        ld      a,(logo_t)
        sub     c
        jr      c,.skip
        ld      c,a
        jr      nz,.ns
        ld      a,SFX_SPAWN
        call    play_sfx
.ns:    ld      a,10
        sub     c
        jr      c,.skip             ; done earlier: it's in the backdrop
        jr      z,.bake
        ld      d,a
        ld      a,(ix+0)
        ld      b,(ix+1)
        ld      c,(ix+2)
        call    draw_spread
        jr      .skip
.bake:  call    bd_open
        ld      a,(ix+0)
        ld      b,(ix+1)
        ld      c,(ix+2)
        call    draw_frame
        ld      l,(ix+4)
        ld      h,(ix+5)
        ld      b,(ix+3)
        ld      a,(ix+2)
        inc     a
        ld      c,a
        ld      a,$55
        call    text3
        call    bd_end
        ld      a,(ix+0)            ; and this frame too
        ld      b,(ix+1)
        ld      c,(ix+2)
        call    draw_frame
        ld      l,(ix+4)
        ld      h,(ix+5)
        ld      b,(ix+3)
        ld      a,(ix+2)
        inc     a
        ld      c,a
        ld      a,$55
        call    text3
.skip:  ld      de,6
        add     ix,de
        pop     bc
        inc     b
        ld      a,b
        cp      10
        jr      c,.e
        ld      a,(logo_t)
        cp      125
        jr      nz,.nf
        call    bd_open
        ld      hl,s_zap
        ld      c,58
        ld      a,$AA
        call    text3c
        call    bd_end
.nf:    ld      hl,logo_t
        ld      a,(hl)
        cp      200
        jr      nc,.x
        inc     (hl)
.x:     call    att_frame
        ret     nz
        ret     c
        jp      .l

; ---------------------------------------------------------------------
; CONTROLS
; ---------------------------------------------------------------------
scr_controls:
        ld      hl,300
        ld      (scr_t),hl
        call    bd_begin
        ld      hl,s_controls
        ld      c,2
        ld      a,$FF
        call    text2xc
        ld      hl,ctl_lines
        ld      c,15
        ld      d,0
.ln:    ld      a,(hl)
        cp      $FF
        jr      z,.dn
        push    de
        push    bc
        ld      a,d
        and     1
        ld      a,$AA
        jr      z,.col
        ld      a,$55
.col:   ld      b,1
        call    text3
        pop     bc
        pop     de
        inc     d
        ld      a,c
        add     a,6
        ld      c,a
        jr      .ln
.dn:    ld      hl,s_keyhelp
        ld      c,57
        ld      a,$AA
        call    text3c
        call    bd_end
.l:     call    bd_copy
        call    marquee
        ; the chosen mode's heading flashes red
        ld      a,(gtick)
        and     4
        jr      z,.f
        ld      a,(ctl_mode)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,ctl_heads
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      a,(ctl_mode)
        add     a,a
        add     a,a
        ld      c,a
        add     a,a
        add     a,c                 ; *12
        add     a,15
        ld      c,a
        ld      b,1
        ld      a,$FF
        call    text3
.f:     call    att_frame
        ret     nz
        ret     c
        jr      .l

; ---------------------------------------------------------------------
; DEMO
; ---------------------------------------------------------------------
scr_demo:
        call    stop_music
        call    new_game
        ld      a,(fields)
        and     3
        inc     a
        ld      (wave),a
        ld      a,1
        ld      (demo),a
        xor     a
        ld      (demo_quit),a
        ld      hl,750
        ld      (scr_t),hl
        call    game_clip
        call    play_game
        xor     a
        ld      (demo),a
        call    front_setup
        ld      a,(demo_quit)
        or      a
        ret     z
        ld      a,(mnu)
        and     $10                 ; quit with fire / SPACE = start a game
        ret

; ---------------------------------------------------------------------
; HIGH SCORES
; ---------------------------------------------------------------------
scr_hiscores:
        ld      hl,200
        ld      (scr_t),hl
hs_show:
        call    bd_begin
        ld      hl,s_hiscores
        ld      c,2
        ld      a,$FF
        call    text2xc
        ld      b,0
.e:     ld      a,(hs_pos)
        cp      b
        jr      z,.sk
        push    bc
        call    hs_draw
        pop     bc
.sk:    inc     b
        ld      a,b
        cp      8
        jr      c,.e
        call    bd_end
.l:     call    bd_copy
        call    marquee
        ld      a,(hs_pos)
        cp      8
        jr      nc,.f
        ld      a,(gtick)
        and     4
        jr      z,.f
        ld      a,(hs_pos)
        ld      b,a
        call    hs_draw
.f:     call    att_frame
        ret     nz
        ret     c
        jr      .l

; hs_draw: B = entry, drawn on its line
hs_draw:
        push    bc
        call    hs_line
        pop     bc
        ld      a,b
        add     a,a
        ld      c,a
        add     a,a
        add     a,c
        add     a,15
        ld      c,a
        ld      a,(hs_pos)
        cp      b
        ld      a,$FF
        jr      z,.pr
        ld      a,b
        and     1
        ld      a,$55
        jr      z,.pr
        ld      a,$AA
.pr:    ld      hl,txtbuf
        ld      b,8
        jp      text3

; hs_line: B = entry -> txtbuf "1 BPM 050000 W15"
hs_line:
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      h,HISC/256
        ld      a,l
        add     a,HISC&255
        ld      l,a
        push    hl
        ld      de,txtbuf
        ld      a,b
        add     a,'1'
        ld      (de),a
        inc     de
        ld      a,' '
        ld      (de),a
        inc     de
        ld      bc,3
        add     hl,bc
        ldir
        ld      a,' '
        ld      (de),a
        inc     de
        pop     hl
        push    hl
        push    de
        call    bcd_to_str
        pop     de
        call    strcpy
        ld      a,' '
        ld      (de),a
        inc     de
        ld      a,'W'
        ld      (de),a
        inc     de
        pop     hl
        ld      bc,6
        add     hl,bc
        ld      a,(hl)
        push    de
        call    byte_to_str
        pop     de
        jp      strcpy

; ---------------------------------------------------------------------
; check_hiscore: insert the score, take initials, show the table
; ---------------------------------------------------------------------
check_hiscore:
        ld      ix,HISC
        ld      b,0
.f:     ld      a,(score)
        cp      (ix+0)
        jr      c,.n
        jr      nz,.ins
        ld      a,(score+1)
        cp      (ix+1)
        jr      c,.n
        jr      nz,.ins
        ld      a,(score+2)
        cp      (ix+2)
        jr      z,.n
        jr      nc,.ins
.n:     ld      de,8
        add     ix,de
        inc     b
        ld      a,b
        cp      8
        jr      c,.f
        ret
.ins:   ld      a,b
        ld      (hs_pos),a
        ld      a,7
        sub     b
        jr      z,.put
        add     a,a
        add     a,a
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,HISC+55
        ld      de,HISC+63
        lddr
.put:   ld      hl,score
        push    ix
        pop     de
        ld      bc,3
        ldir
        ld      a,'A'
        ld      (de),a
        inc     de
        ld      (de),a
        inc     de
        ld      (de),a
        inc     de
        ld      a,(wave)
        ld      (de),a
        ld      hl,mus_hiscore
        xor     a
        call    start_music
        call    enter_name
        call    save_records
        ld      hl,250
        ld      (scr_t),hl
        call    hs_show
        ld      a,$FF
        ld      (hs_pos),a
        ret

; enter_name: initials for entry hs_pos (IX = the entry)
enter_name:
        xor     a
        ld      (hs_cur),a
        ld      (tmp2),a            ; auto-repeat counter
        ld      hl,750
        ld      (scr_t),hl
        call    bd_begin
        ld      hl,s_initials
        ld      c,20
        ld      a,$55
        call    text3c
        ld      hl,s_namehelp
        ld      c,48
        ld      a,$AA
        call    text3c
        call    bd_end
.l:     call    bd_copy
        call    marquee
        ld      hl,s_great
        ld      c,4
        ld      a,(gtick)
        and     4
        ld      a,$FF
        jr      z,.c
        ld      a,$55
.c:     call    text2xc
        ; the three letters
        ld      b,0
.lt:    push    bc
        ld      e,b
        ld      d,0
        push    ix
        pop     hl
        add     hl,de
        inc     hl
        inc     hl
        inc     hl
        ld      a,(hl)
        ld      (txtbuf),a
        xor     a
        ld      (txtbuf+1),a
        ld      a,(hs_cur)
        cp      b
        ld      a,$AA
        jr      nz,.cl
        ld      a,(gtick)
        and     4
        ld      a,$FF
        jr      z,.cl
        ld      a,$55
.cl:    push    af
        ld      a,b
        add     a,a
        add     a,a
        add     a,11
        ld      b,a
        pop     af
        ld      hl,txtbuf
        ld      c,30
        call    text2x
        pop     bc
        inc     b
        ld      a,b
        cp      3
        jr      c,.lt
        call    present
        ; ---- input
        ld      a,(hs_cur)
        ld      e,a
        ld      d,0
        push    ix
        pop     hl
        add     hl,de
        inc     hl
        inc     hl
        inc     hl                  ; HL = current letter
        ld      a,(mnu)
        and     $0C
        jr      z,.norep
        ld      a,(tmp2)
        inc     a
        ld      (tmp2),a
        cp      8
        jr      c,.edge
        ld      a,5
        ld      (tmp2),a
        ld      a,(mnu)
        jr      .ud
.norep: xor     a
        ld      (tmp2),a
.edge:  ld      a,(mnunew)
.ud:    bit     2,a
        jr      z,.d
        ld      a,(hl)
        inc     a
        cp      'Z'+1
        jr      c,.s1
        ld      a,' '
.s1:    cp      ' '+1
        jr      nz,.s2
        ld      a,'A'
.s2:    ld      (hl),a
        ld      a,SFX_TICK
        call    play_sfx
        jr      .nx
.d:     bit     3,a
        jr      z,.nx
        ld      a,(hl)
        dec     a
        cp      ' '
        jr      z,.s4
        cp      'A'
        jr      nc,.s4
        ld      a,'Z'
.s4:    ld      (hl),a
        ld      a,SFX_TICK
        call    play_sfx
.nx:    ld      a,(mnunew)
        and     $11                 ; right or fire/SPACE: next letter
        jr      z,.bk
        ld      a,SFX_SELECT
        call    play_sfx
        ld      a,(hs_cur)
        inc     a
        ld      (hs_cur),a
        cp      3
        ret     nc
.bk:    ld      a,(mnunew)
        bit     1,a
        jr      z,.tm
        ld      a,(hs_cur)
        or      a
        jr      z,.tm
        dec     a
        ld      (hs_cur),a
.tm:    ld      hl,(scr_t)
        dec     hl
        ld      (scr_t),hl
        ld      a,h
        or      l
        ret     z
        jp      .l

; ---------------------------------------------------------------------
; high scores (and the control/sound choices) kept in the BennVenn SRAM's
; second bank, so they survive a reset or reload while the machine is on.
; Bank probe and signature check as in DUEL II; ROBOGEDDON keeps its
; records at $6700 so the two games don't trample each other.
; ---------------------------------------------------------------------
SAVEADR equ $6700
REC_LEN equ 4+64+2

load_records:
        xor     a
        ld      (srok),a
        di
        ld      a,1
        out     ($37),a
        ld      a,($67FF)
        ld      (probe1),a
        ld      a,3
        out     ($37),a
        ld      a,($67FF)
        ld      (probe3),a
        ld      a,(probe1)
        cpl
        ld      ($67FF),a
        ld      a,1
        out     ($37),a
        ld      a,($67FF)
        ld      b,a
        ld      a,(probe1)
        cp      b
        jr      nz,.restore         ; bank 1 changed: no banking here, undo
        ld      a,3
        out     ($37),a
        ld      a,($67FF)
        ld      b,a
        ld      a,(probe1)
        cpl
        cp      b
        jr      nz,.nosram
        ld      a,(probe3)
        ld      ($67FF),a
        ld      a,1
        ld      (srok),a
        ld      hl,SAVEADR
        ld      de,recbuf
        ld      bc,REC_LEN+1
        ldir
        ld      a,1
        out     ($37),a
        ei
        ld      hl,recbuf
        ld      de,rec_sig
        ld      b,4
.sg:    ld      a,(de)
        cp      (hl)
        ret     nz
        inc     hl
        inc     de
        djnz    .sg
        call    rec_sum
        ld      hl,recbuf+REC_LEN
        cp      (hl)
        ret     nz
        ld      hl,recbuf+4
        ld      de,HISC
        ld      bc,64
        ldir
        ld      a,(hl)
        cp      3
        jr      nc,.s
        ld      (ctl_mode),a
.s:     inc     hl
        ld      a,(hl)
        cp      3
        ret     nc
        ld      (snd_mode),a
        ret
.restore:
        ld      a,(probe1)
        ld      ($67FF),a
.nosram:
        ld      a,1
        out     ($37),a
        ei
        ret

rec_sig: db "RBG1"

rec_sum:        ; A = sum of recbuf[0..REC_LEN-1] + $5A
        ld      hl,recbuf
        ld      b,REC_LEN
        ld      a,$5A
.l:     add     a,(hl)
        inc     hl
        djnz    .l
        ret

save_records:
        ld      a,(srok)
        or      a
        ret     z
        ld      hl,rec_sig
        ld      de,recbuf
        ld      bc,4
        ldir
        ld      hl,HISC
        ld      bc,64
        ldir
        ld      a,(ctl_mode)
        ld      (de),a
        inc     de
        ld      a,(snd_mode)
        ld      (de),a
        call    rec_sum
        ld      (recbuf+REC_LEN),a
        di
        ld      a,3
        out     ($37),a
        ld      hl,recbuf
        ld      de,SAVEADR
        ld      bc,REC_LEN+1
        ldir
        ld      a,1
        out     ($37),a
        ei
        ret
