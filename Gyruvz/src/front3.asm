; =====================================================================
;  GYRUVZ - the front end.  Lives in the BennVenn SRAM's second bank
;  ($4000, port $37 = 3), unpacked there at power-up.  Runs with the
;  interrupt off: the screens are still pictures drawn straight on the
;  screen, so the whole CPU goes to the 3-channel music.
;
;  The attract sequence: title - comic - the swarm - comic - top pilots
;  - demo - comic - how to fly - ...   Any time: FIRE / SPACE / RETURN
;  plays, C continues, D changes the skill, M the sound.
; =====================================================================

; screen ids for the attract sequence
SC_TITLE  equ 0
SC_COMIC1 equ 1
SC_SWARM  equ 2
SC_COMIC2 equ 3
SC_TOP    equ 4
SC_DEMO   equ 5
SC_COMIC3 equ 6
SC_HOWTO  equ 7

; music stop reasons
MS_START  equ 1                 ; a game
MS_NEXT   equ 2                 ; next screen wants the CPU (the demo)
MS_DONE   equ 3                 ; name entry / one-more-go finished

attract:
        ld      sp,STACKTOP
        ld      a,VRAM/256
        ld      (drawh),a
        xor     a
        ld      (demo),a
        ld      (att_i),a
        call    mus_init
.show:  call    att_screen          ; draw this step's screen
        ld      a,(att_i)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,att_seq
        add     hl,de
        ld      a,(hl)
        cp      SC_DEMO
        jr      z,.demo
        inc     hl
        ld      a,(hl)              ; seconds
        call    secs_to_ticks
        ld      (att_t),hl
        ld      hl,att_cb
        ld      (mus_cb),hl
        call    mus_run
        ld      a,(mus_stop)
        cp      MS_START
        jr      z,.play
.nx:    ld      a,(att_i)
        inc     a
        cp      ATT_N
        jr      c,.ok
        xor     a
.ok:    ld      (att_i),a
        jr      .show
.demo:  call    run_demo
        jr      c,.play
        jr      .nx
.play:  call    play
        xor     a
        ld      (att_i),a
        jr      .show

att_seq:        ; screen, seconds
        db      SC_TITLE,14, SC_COMIC1,5, SC_SWARM,9, SC_COMIC2,5
        db      SC_TOP,8, SC_DEMO,0, SC_COMIC3,5, SC_HOWTO,9
ATT_N   equ ($-att_seq)/2

; A = seconds -> HL = music ticks (89 a second)
secs_to_ticks:
        ld      l,a
        ld      h,0
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      b,h
        ld      c,l                 ; 8x
        add     hl,hl
        add     hl,hl
        add     hl,hl               ; 64x
        add     hl,bc               ; 72x
        add     hl,bc               ; 80x
        add     hl,bc               ; 88x
        add     hl,de               ; 89x
        ret

; att_cb: every music tick on an attract screen
att_cb:
        call    fe_keys
        jr      nc,.t
        ld      a,MS_START
        ld      (mus_stop),a
        ret
.t:     ld      hl,(att_t)
        dec     hl
        ld      (att_t),hl
        ld      a,h
        or      l
        ret     nz
        ld      a,MS_NEXT
        ld      (mus_stop),a
        ret

; att_screen: draw the screen for step (att_i)
att_screen:
        ld      a,(att_i)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,att_seq
        add     hl,de
        ld      a,(hl)
        cp      SC_DEMO
        ret     z
        add     a,a
        ld      e,a
        ld      hl,scr_tab
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        jp      (hl)
scr_tab: dw draw_title, draw_comic1, draw_swarm, draw_comic2
         dw draw_top, 0, draw_comic3, draw_howto

; ---------------------------------------------------------------------
; keys on any attract screen -> carry = start ((start_sec) set)
; ---------------------------------------------------------------------
fe_keys:
        call    read_input
        ld      a,(keysnew)
        bit     0,a
        jr      z,.nm
        ld      a,(snd_mode)
        inc     a
        cp      3
        jr      c,.sm
        xor     a
.sm:    ld      (snd_mode),a
        call    mus_vol
        call    save_records
        call    opts_redraw
        ld      a,(keysnew)
.nm:    bit     3,a
        jr      z,.nd
        ld      a,(skill)
        inc     a
        cp      3
        jr      c,.sk
        xor     a
.sk:    ld      (skill),a
        call    save_records
        call    opts_redraw
        ld      a,(keysnew)
.nd:    bit     4,a
        jr      z,.nc
        ld      a,(cont_sec)
        or      a
        jr      z,.nc
        ld      (start_sec),a
        scf
        ret
.nc:    ld      a,(mnunew)
        bit     4,a
        ret     z
        xor     a
        ld      (start_sec),a
        scf
        ret

; the options line is on the title only
opts_redraw:
        ld      a,(att_i)
        or      a
        ret     nz
        ld      a,(in_att)
        or      a
        ret     z
        ; blank row 46..50 and draw it again
        ld      c,46
        ld      b,5
        call    blank_rows
        jp      opts_line

; blank_rows: C = first row, B = rows -> blue
blank_rows:
.r:     push    bc
        call    rowaddr
        ld      d,h
        ld      e,l
        inc     de
        ld      (hl),$AA
        ld      bc,31
        ldir
        pop     bc
        inc     c
        djnz    .r
        ret

; ---------------------------------------------------------------------
; the screens
; ---------------------------------------------------------------------
show_pic:       ; HL = packed picture -> the screen
        ld      de,VRAM
        jp      unlz

cls_blue:
        ld      hl,VRAM
        ld      de,VRAM+1
        ld      bc,2047
        ld      (hl),$AA
        ldir
        ret

draw_title:
        ld      a,1
        ld      (in_att),a
        ld      hl,pic_title
        call    show_pic
        ; the best score, under the logo
        ld      de,txtbuf
        ld      hl,s_hi
        call    strcpy
        push    de
        ld      hl,HISC
        call    bcd_to_str
        pop     de
        call    strcpy
        ld      a,' '
        ld      (de),a
        inc     de
        ld      hl,HISC+3
        ld      bc,3
        ldir
        xor     a
        ld      (de),a
        ld      hl,txtbuf
        ld      c,33
        ld      a,$FF
        call    text3c
        ld      hl,s_tfire
        ld      c,40
        ld      a,$55
        call    text3c
        call    opts_line
        ld      a,(cont_sec)
        or      a
        ret     z
        ld      hl,s_tcont
        ld      de,txtbuf
        call    strcpy
        ld      a,(cont_sec)
        add     a,'1'
        ld      (de),a
        inc     de
        xor     a
        ld      (de),a
        ld      hl,txtbuf
        ld      c,52
        ld      a,$FF
        jp      text3c

; opts_line: "D  PILOT    M  SOUND ON" at row 46
opts_line:
        ld      de,txtbuf
        ld      hl,s_od
        call    strcpy
        ld      a,(skill)
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,skill_names
        add     hl,bc
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        call    strcpy
        ld      hl,s_om
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
        ld      c,46
        xor     a
        jp      text3c

draw_comic1:
        ld      hl,pic_comic1
        jp      show_pic
draw_comic2:
        ld      hl,pic_comic2
        jp      show_pic
draw_comic3:
        ld      hl,pic_comic3
        jp      show_pic

; frame: the border used by the text screens
draw_frame:
        call    cls_blue
        ld      hl,pic_frame
        jp      show_pic

draw_swarm:
        call    draw_frame
        ld      hl,s_swarm
        ld      c,2
        ld      a,$FF
        call    text2xc
        ld      hl,swarm_tab
        ld      c,15
.row:   ld      a,(hl)
        cp      255
        ret     z
        push    hl
        push    bc
        ld      b,12
        inc     c
        inc     c
        call    draw_c
        pop     bc
        pop     hl
        inc     hl
        push    bc
        ld      b,6
        ld      a,$55
        call    text3               ; name and points
        pop     bc
        push    bc
        ld      a,$FF
        call    text3x              ; what it does
        pop     bc
        ld      a,c
        add     a,7
        ld      c,a
        jr      .row

; text3x: HL = string drawn right-aligned on row C
text3x:
        push    af
        call    strlen
        ld      a,30
        sub     b
        ld      b,a
        pop     af
        jp      text3

swarm_tab:      ; frame, name, what it does
        db      FT_GLINT+4, "GLINT 100",0, "DARTS",0
        db      FT_MOTH+4, "MOTH 150",0, "SHOOTS",0
        db      FT_SPIN+4, "SPINNER 200",0, "TWO HITS",0
        db      FT_HORNET+4, "HORNET 250",0, "RAMS",0
        db      FT_MINE+4, "MINE 300",0, "BURSTS",0
        db      FT_POD+4, "POD 1000",0, "TWIN SHOT",0
        db      255

draw_top:
        call    draw_frame
        ld      hl,s_top
        ld      (hs_title),hl
        ld      a,255
        ld      (hs_pos),a
        jp      hs_draw

draw_howto:
        call    draw_frame
        ld      hl,s_howto
        ld      c,2
        ld      a,$FF
        call    text2xc
        ld      hl,howto_txt
        ld      c,15
.r:     ld      a,(hl)
        or      a
        ret     z
        cp      '*'
        ld      a,$55
        jr      nz,.n
        inc     hl
        ld      a,$FF
.n:     push    bc
        call    text3c
        pop     bc
        ld      a,c
        add     a,6
        ld      c,a
        jr      .r

howto_txt:
        db      "STICK OR WASD: SWING ROUND",0
        db      "Z X: TURN   FIRE / SPACE: SHOOT",0
        db      "P: PAUSE   M: SOUND",0
        db      "*SHIELDS SOAK UP HITS",0
        db      "*WIPE OUT A FORMATION: BONUS",0
        db      "*HIT THEM CLOSE IN: DOUBLE",0
        db      "*BOSSES: STRIP THE PODS FIRST",0
        db      0

; hs_draw: the table, heading (hs_title); entry (hs_pos) in red
hs_draw:
        ld      hl,(hs_title)
        ld      c,2
        ld      a,$FF
        call    text2xc
        ld      b,0
.e:     push    bc
        call    hs_line
        ld      a,b
        ld      hl,hs_pos
        cp      (hl)
        ld      a,$55
        jr      nz,.c
        ld      a,$FF
.c:     push    af
        ld      a,b
        add     a,a
        add     a,b
        add     a,a                 ; *6
        add     a,15
        ld      c,a
        pop     af
        ld      hl,txtbuf
        ld      b,6
        call    text3
        pop     bc
        inc     b
        ld      a,b
        cp      8
        jr      c,.e
        ret

; ---------------------------------------------------------------------
; the demo: the computer flies sector 1 for half a minute
;   -> carry = quit with FIRE (straight into a game)
; ---------------------------------------------------------------------
run_demo:
        call    mus_silence
        ld      a,(skill)
        ld      (skill_sv),a
        ld      a,(cont_sec)
        ld      (cont_sv),a
        ld      a,(snd_mode)
        ld      (snd_sv),a
        or      a
        jr      nz,.s
        inc     a                   ; the demo plays effects, no tune
        ld      (snd_mode),a
.s:     ld      a,1
        ld      (skill),a
        ld      (demo),a
        xor     a
        ld      (demo_quit),a
        ld      hl,750
        ld      (demo_t),hl
        ld      hl,(score)
        push    hl
        ld      a,(score+2)
        push    af
        xor     a
        call    b1_game
        pop     af
        ld      (score+2),a
        pop     hl
        ld      (score),hl
        xor     a
        ld      (demo),a
        ld      a,(skill_sv)
        ld      (skill),a
        ld      a,(cont_sv)
        ld      (cont_sec),a
        ld      a,(snd_sv)
        ld      (snd_mode),a
        call    mus_vol
        ld      a,(mnu)
        bit     4,a
        ret     z
        xor     a
        ld      (start_sec),a
        scf
        ret

; ---------------------------------------------------------------------
; play: (start_sec) = first sector.  Game, high score, one more go?
; ---------------------------------------------------------------------
play:
        xor     a
        ld      (in_att),a
        call    mus_silence
.again: xor     a
        ld      (demo),a
        ld      (demo_quit),a
        ld      a,(start_sec)
        call    b1_game
        ld      a,(demo_quit)
        or      a
        ret     nz                  ; quit from the pause screen
        call    check_hiscore
        call    scr_again
        jr      c,.again
        ret

; ---------------------------------------------------------------------
; scr_again: GAME OVER, your score, one more go?  -> carry = play again
; ---------------------------------------------------------------------
scr_again:
        call    draw_frame
        ld      hl,s_gameover
        ld      c,4
        ld      a,$FF
        call    text2xc
        ld      de,txtbuf
        ld      hl,s_score
        call    strcpy
        push    de
        ld      hl,score
        call    bcd_to_str
        pop     de
        call    strcpy
        ld      hl,txtbuf
        ld      c,19
        ld      a,$55
        call    text3c
        ld      hl,s_again
        ld      c,29
        ld      a,$FF
        call    text3c
        ld      a,(cont_sec)
        or      a
        jr      z,.nc
        ld      hl,s_tcont
        ld      de,txtbuf
        call    strcpy
        ld      a,(cont_sec)
        add     a,'1'
        ld      (de),a
        inc     de
        xor     a
        ld      (de),a
        ld      hl,txtbuf
        ld      c,37
        ld      a,$55
        call    text3c
        ld      hl,s_contnote
        ld      c,43
        xor     a
        call    text3c
.nc:    ld      a,10
        ld      (ag_secs),a
        call    ag_digit
        ld      hl,89
        ld      (att_t),hl
        ld      hl,again_cb
        ld      (mus_cb),hl
        call    mus_run
        ld      a,(mus_stop)
        cp      MS_START
        scf
        ret     z
        or      a
        ret

again_cb:
        call    fe_keys
        jr      nc,.t
        ld      a,MS_START
        ld      (mus_stop),a
        ret
.t:     ld      hl,(att_t)
        dec     hl
        ld      (att_t),hl
        ld      a,h
        or      l
        ret     nz
        ld      hl,89
        ld      (att_t),hl
        ld      a,(ag_secs)
        dec     a
        ld      (ag_secs),a
        jr      z,.out
        jp      ag_digit
.out:   ld      a,MS_DONE
        ld      (mus_stop),a
        ret

ag_digit:       ; the countdown, big, at row 50
        ld      c,50
        ld      b,10
        call    blank_rows
        ld      a,(ag_secs)
        dec     a
        call    byte_to_str
        inc     hl
        ld      c,50
        ld      a,$FF
        jp      text2xc

; ---------------------------------------------------------------------
; high scores: is this one good enough?  then initials
; ---------------------------------------------------------------------
check_hiscore:
        ld      b,0
        ld      hl,HISC
.f:     push    hl
        ld      de,score
        ld      c,3
.c:     ld      a,(de)
        cp      (hl)
        jr      c,.lower
        jr      nz,.higher
        inc     hl
        inc     de
        dec     c
        jr      nz,.c
.lower: pop     hl
        ld      de,8
        add     hl,de
        inc     b
        ld      a,b
        cp      8
        jr      c,.f
        ret
.higher:
        pop     hl
        ld      a,b
        ld      (hs_pos),a
        ld      a,7
        sub     b
        jr      z,.put
        ld      c,a
        xor     a
        ld      b,a
        sla     c
        sla     c
        sla     c
        push    hl
        ld      hl,HISC+55
        ld      de,HISC+63
        lddr
        pop     hl
.put:   ld      de,score
        ex      de,hl
        ld      bc,3
        ldir
        ld      a,'A'
        ld      (de),a
        inc     de
        ld      a,' '
        ld      (de),a
        inc     de
        ld      (de),a
        inc     de
        ld      a,(sector)
        inc     a
        ld      (de),a
        ld      a,(loop)
        or      a
        jr      z,.e
        ld      a,9
        ld      (de),a
.e:     call    enter_name
        jp      save_records

; enter_name: initials for entry (hs_pos): type letters, or stick up /
;   down and FIRE to move on.  RETURN finishes.
enter_name:
        xor     a
        ld      (hs_cur),a
        ld      (last_letter),a
        ld      (hs_held),a
        call    draw_frame
        ld      hl,s_newhi
        ld      (hs_title),hl
        call    hs_draw
        call    ne_cursor
        ld      hl,30*89
        ld      (att_t),hl
        ld      hl,ne_cb
        ld      (mus_cb),hl
        call    mus_run
        ; a last look
        ld      a,(hs_pos)
        call    ne_line
        ret

ne_cb:
        call    read_input
        ld      hl,(att_t)
        dec     hl
        ld      (att_t),hl
        ld      a,h
        or      l
        jr      z,.done
        ; the letter being entered
        ld      a,(hs_pos)
        add     a,a
        add     a,a
        add     a,a
        add     a,3
        ld      hl,hs_cur
        add     a,(hl)
        ld      e,a
        ld      d,0
        ld      hl,HISC
        add     hl,de
        push    hl
        call    scan_letter
        pop     hl
        or      a
        jr      z,.nt
        ld      (hl),a
        jr      .next
.nt:    ld      a,(keysnew)
        bit     1,a                 ; RETURN: done
        jr      nz,.done
        ld      a,(joy1)
        ld      b,a
        ld      a,(jfire)
        or      b
        ld      b,a
        ld      a,(hs_held)
        cpl
        and     b
        ld      c,a
        ld      a,b
        ld      (hs_held),a
        ld      a,(keysnew)
        bit     7,a                 ; SPACE
        jr      z,.pad
        set     4,c
.pad:   bit     4,c
        jr      nz,.next
        ld      a,(hl)
        bit     2,c
        jr      z,.dn
        call    letter_up
        ld      (hl),a
        jr      ne_redraw
.dn:    bit     3,c
        ret     z
        call    letter_dn
        ld      (hl),a
        jr      ne_redraw
.next:  call    mus_click
        ld      a,(hs_cur)
        inc     a
        ld      (hs_cur),a
        cp      3
        jr      c,ne_redraw
.done:  ld      a,MS_DONE
        ld      (mus_stop),a
        ret
ne_redraw:
        ld      a,(hs_pos)
        call    ne_line
        jp      ne_cursor

; ne_line: A = entry -> redraw that row (red)
ne_line:
        ld      b,a
        add     a,a
        add     a,b
        add     a,a
        add     a,15
        ld      c,a
        push    bc
        ld      b,7
        call    blank_rows
        pop     bc
        push    bc
        call    hs_line
        pop     bc
        ld      hl,txtbuf
        ld      b,6
        ld      a,$FF
        jp      text3

; ne_cursor: a line under the letter being entered
ne_cursor:
        ld      a,(hs_cur)
        cp      3
        ret     nc
        ld      a,(hs_pos)
        ld      b,a
        add     a,a
        add     a,b
        add     a,a
        add     a,21
        ld      c,a
        ld      a,(hs_cur)
        add     a,9                 ; columns: entry at 6, initials from 9
        add     a,a
        add     a,a
        ld      b,a
        ld      d,a
        inc     d
        inc     d
        ld      e,$55
        jp      hline

; ---------------------------------------------------------------------
;  the 3-channel music engine.  Three pulse voices, mixed by taking turns
;  at the speaker within each sample; each voice has a duty-cycle
;  envelope that settles into a slow pulse-width sweep, fast arpeggio
;  chords, and the third voice doubles as the drum kit (kick, snare, hat).
; ---------------------------------------------------------------------
MUS_ITER equ 200                ; samples a tick (~11 ms)

; channel state, 8 bytes each
CH_INC  equ 0                   ; phase step (word)
CH_DUTY equ 2
CH_NOTE equ 3
CH_ARP  equ 4                   ; arpeggio: 0 none, else table index
CH_ARPI equ 5
CH_PWM  equ 6
CH_PWD  equ 7

mus_init:
        ld      hl,song
        ld      a,(hl)
        ld      (mus_speed),a
        inc     hl
        ld      de,mus_ins
        ld      bc,12
        ldir
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      (mus_chords),de
        ld      (mus_opos),hl
        ld      hl,mus_chs
        ld      de,mus_chs+1
        ld      bc,8*3-1
        ld      (hl),0
        ldir
        xor     a
        ld      (mus_tick),a
        ld      (mus_dr),a
        ld      (mus_atk),a
        call    mus_next_pat
        jp      mus_row

; mus_run: play until the callback sets (mus_stop)
mus_run:
        xor     a
        ld      (mus_stop),a
        call    mus_vol
mus_loop_enter:
        ld      a,(mus_ch1+CH_DUTY)
        ld      (mus_cp1+1),a
        ld      a,(mus_ch2+CH_DUTY)
        ld      (mus_cp2+1),a
        ld      a,(mus_ch3+CH_DUTY)
        ld      (mus_cp3+1),a
        exx
        ld      hl,(mus_ph2)
        ld      de,(mus_ch2+CH_INC)
        ld      bc,(mus_ch3+CH_INC)
        exx
        ld      hl,(mus_ph1)
        ld      de,(mus_ch1+CH_INC)
        ld      ix,(mus_ph3)
        ld      a,(mus_base)
        ld      c,a
        ld      b,MUS_ITER
mus_lp:
        add     hl,de
        ld      a,h
mus_cp1: cp     0
        sbc     a,a
mus_v1: and     $21
        xor     c
        ld      (LATCH),a
        exx
        add     hl,de
        ld      a,h
mus_cp2: cp     0
        sbc     a,a
mus_v2: and     $21
        exx
        xor     c
        exx
        ld      (LATCH),a
        add     ix,bc
mus_ch3op:
        ld      a,ixh
        nop
mus_cp3: cp     0
        sbc     a,a
mus_v3: and     $21
        exx
        xor     c
        ld      (LATCH),a
        djnz    mus_lp
        ld      (mus_ph1),hl
        ld      (mus_ph3),ix
        exx
        ld      (mus_ph2),hl
        exx
        call    mus_tick_proc
        ld      hl,(mus_cb)
        call    .jp
        ld      a,(mus_stop)
        or      a
        jp      z,mus_loop_enter
        jp      mus_silence
.jp:    jp      (hl)

; mus_vol: sound on/off from (snd_mode): only "SOUND ON" plays the tune
mus_vol:
        ld      a,(vmode)
        and     $DE
        or      $20
        ld      (mus_base),a
        ld      a,(snd_mode)
        or      a
        ld      a,$21
        jr      z,.on
        xor     a
.on:    ld      (mus_v1+1),a
        ld      (mus_v2+1),a
        ld      (mus_v3+1),a
        ret

mus_silence:
        ld      a,(vmode)
        and     $DE
        or      $20
        ld      (LATCH),a
        ret

; a short click (initials)
mus_click:
        ld      a,(mus_base)
        ld      c,a
        ld      b,40
.l:     ld      a,c
        xor     $21
        ld      c,a
        ld      (LATCH),a
        ld      a,12
.d:     dec     a
        jr      nz,.d
        djnz    .l
        ret

mus_next_pat:
        ld      hl,(mus_opos)
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,d
        cp      $FF
        jr      nz,.pat
        ld      e,(hl)              ; loop: next word = order position
        inc     hl
        ld      d,(hl)
        ld      (mus_opos),de
        jr      mus_next_pat
.pat:   ld      (mus_opos),hl
        ld      (mus_ppos),de
        ld      a,16
        ld      (mus_rowc),a
        ret

; mus_row: one row of the pattern (3 tokens)
mus_row:
        ld      hl,(mus_ppos)
        ld      ix,mus_ch1
        ld      iy,mus_ins
        call    .tok
        ld      ix,mus_ch2
        ld      iy,mus_ins+4
        call    .tok
        ld      a,(hl)
        inc     hl
        ld      (mus_ppos),hl
        or      a
        ret     z
        cp      $80
        jr      c,.t3
        cp      $C0
        jr      nc,.t3
        ; drums on voice 3: $80 kick, $81 snare, $82 hat
        sub     $7F
        ld      (mus_dr),a
        ld      b,a
        ld      a,$70
        ld      (mus_ch3+CH_DUTY),a
        dec     b
        jr      nz,.sn
        ld      hl,1300             ; kick: a falling thud
        ld      (mus_ch3+CH_INC),hl
        ld      a,$7C               ; ld a,ixh: a tone
        ld      (mus_ch3op+1),a
        ld      a,8
        ld      (mus_drt),a
        ret
.sn:    ld      a,$7E               ; ld a,(ix+0): reads noise
        ld      (mus_ch3op+1),a
        ld      hl,$0107
        ld      (mus_ch3+CH_INC),hl
        dec     b
        ld      a,7                 ; snare
        jr      z,.snl
        ld      a,2                 ; hat
.snl:   ld      (mus_drt),a
        ret
.t3:    push    af
        xor     a
        ld      (mus_dr),a
        ld      a,$7C
        ld      (mus_ch3op+1),a
        pop     af
        ld      ix,mus_ch3
        ld      iy,mus_ins+8
        dec     hl
        call    .tok
        ld      (mus_ppos),hl
        ret
; .tok: (HL) = token for the voice at IX with instrument IY
.tok:   ld      a,(hl)
        inc     hl
        or      a
        ret     z
        dec     a
        jr      nz,.n
        ld      (ix+CH_DUTY),a      ; off
        ld      (ix+CH_ARP),a
        ret
.n:     inc     a
        ld      b,0                 ; no arpeggio
        cp      $C0
        jr      c,.nt
        ; a chord: (root, arpeggio) from the chord table
        sub     $C0
        push    hl
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,(mus_chords)
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      b,(hl)
        pop     hl
.nt:    ld      (ix+CH_NOTE),a
        ld      (ix+CH_ARP),b
        ld      (ix+CH_ARPI),0
        call    note_inc
        ld      (ix+CH_INC),e
        ld      (ix+CH_INC+1),d
        ld      a,(iy+0)
        ld      (ix+CH_DUTY),a
        xor     a
        ld      (ix+CH_PWM),a
        ld      (ix+CH_PWD),a
        ret

; A = note token (2..) -> DE = phase step
note_inc:
        push    hl
        sub     2
        add     a,a
        ld      l,a
        ld      h,0
        ld      de,NOTETAB
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        pop     hl
        ret

; once a tick: envelopes, arpeggios, drums, then the next row
mus_tick_proc:
        ld      ix,mus_ch1
        ld      iy,mus_ins
        call    .env
        ld      ix,mus_ch2
        ld      iy,mus_ins+4
        call    .env
        ld      a,(mus_dr)
        or      a
        jr      nz,.drum
        ld      ix,mus_ch3
        ld      iy,mus_ins+8
        call    .env
        jr      .rows
.drum:  ld      hl,mus_drt
        dec     (hl)
        jr      nz,.dk
        xor     a
        ld      (mus_dr),a
        ld      (mus_ch3+CH_DUTY),a
        ld      a,$7C
        ld      (mus_ch3op+1),a
        jr      .rows
.dk:    cp      1
        jr      nz,.rows
        ld      hl,(mus_ch3+CH_INC) ; kick: the pitch falls
        ld      de,-140
        add     hl,de
        ld      (mus_ch3+CH_INC),hl
.rows:  ld      hl,mus_tick
        inc     (hl)
        ld      a,(mus_speed)
        cp      (hl)
        ret     nz
        ld      (hl),0
        ld      hl,mus_rowc
        dec     (hl)
        jr      nz,.row
        call    mus_next_pat
.row:   jp      mus_row

; .env: duty falls to the floor, then sweeps up and down (pulse width);
;   arpeggios step every other tick
.env:   ld      a,(ix+CH_DUTY)
        or      a
        ret     z
        ld      b,a
        ld      a,(iy+2)            ; floor
        ld      c,a
        ld      a,b
        cp      c
        jr      z,.pw
        jr      c,.pw
        sub     (iy+1)              ; decay
        jr      c,.fl
        cp      c
        jr      nc,.sd
.fl:    ld      a,c
.sd:    ld      (ix+CH_DUTY),a
        jr      .arp
.pw:    ld      a,(iy+3)            ; sweep depth (0 = none)
        or      a
        jr      z,.arp
        ld      d,a
        ld      a,(ix+CH_PWD)
        or      a
        ld      a,(ix+CH_PWM)
        jr      nz,.down
        inc     a
        cp      d
        jr      c,.ps
        ld      (ix+CH_PWD),1
        jr      .ps
.down:  dec     a
        jr      nz,.ps
        ld      (ix+CH_PWD),0
.ps:    ld      (ix+CH_PWM),a
        add     a,c
        ld      (ix+CH_DUTY),a
.arp:   ld      a,(ix+CH_ARP)
        or      a
        ret     z
        ld      a,(mus_tick)
        and     1
        ret     nz
        ld      a,(ix+CH_ARP)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,arp_tab-2
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a                 ; HL = offsets, $FF ends
        ld      a,(ix+CH_ARPI)
        inc     a
        ld      e,a
        add     hl,de
        ld      a,(hl)
        cp      $FF
        jr      nz,.ao
        ld      e,0
        ld      a,0
.ao:    ld      (ix+CH_ARPI),e
        add     a,(ix+CH_NOTE)
        call    note_inc
        ld      (ix+CH_INC),e
        ld      (ix+CH_INC+1),d
        ret

arp_tab: dw arp_min, arp_maj, arp_dim, arp_oct, arp_fif
arp_min: db 0, 3, 7, 12, $FF
arp_maj: db 0, 4, 7, 12, $FF
arp_dim: db 0, 3, 6, 9, $FF
arp_oct: db 0, 12, $FF
arp_fif: db 0, 7, 12, $FF

; ---------------------------------------------------------------------
; front-end text
; ---------------------------------------------------------------------
s_tfire:    db "PRESS FIRE TO PLAY",0
s_tcont:    db "C  CONTINUE FROM SECTOR ",0
s_contnote: db "(SCORE STARTS AGAIN)",0
s_hi:       db "HI ",0
s_od:       db "D  ",0
s_om:       db "    M  ",0
s_swarm:    db "THE SWARM",0
s_top:      db "TOP PILOTS",0
s_howto:    db "HOW TO FLY",0
s_score:    db "SCORE ",0
s_again:    db "FIRE  ONE MORE GO",0
s_newhi:    db "YOUR INITIALS",0
skill_names: dw s_cadet, s_pilot, s_ace
s_cadet:    db "CADET",0
s_pilot:    db "PILOT",0
s_ace:      db "ACE",0
