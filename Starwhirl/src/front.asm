; =====================================================================
;  STARWHIRL - front end
;  title -> the swarm -> demo -> top pilots -> how to fly -> title ...
;  Any screen: FIRE / SPACE / RETURN starts a game, C continues from the
;  last sector reached, D changes the skill, M the sound.
; =====================================================================

attract:
        ld      sp,STACKTOP
        xor     a
        ld      (demo),a
        ld      (warp),a
        ld      (flash_t),a
.title: call    scr_title
        jr      c,.play
        call    scr_swarm
        jr      c,.play
        call    scr_demo
        jr      c,.play
        call    scr_hiscores
        jr      c,.play
        call    scr_howto
        jr      c,.play
        jr      .title
.play:  call    play
        jr      .title

; play: (start_sec) = first sector.  Game, high score, "one more go?"
play:
        call    stop_music
.again: xor     a
        ld      (demo),a
        ld      (demo_quit),a
        ld      a,MODE1
        ld      (next_vmode),a
        ld      a,(start_sec)
        call    run_game
        ld      a,MODE1
        ld      (next_vmode),a
        xor     a
        ld      (flash_t),a
        ld      (warp),a
        ld      a,(demo_quit)
        or      a
        ret     nz                  ; quit from the pause screen
        call    check_hiscore
        call    scr_again
        jr      c,.again
        ret

; ---------------------------------------------------------------------
; shared front-end frame parts
; ---------------------------------------------------------------------
fe_begin:       ; clear, stream the stars
        call    clear_all
        jp      stars

; fe_keys: after present.  -> carry = start a game ((start_sec) set)
fe_keys:
        ld      a,(keysnew)
        bit     0,a
        jr      z,.nm
        ld      a,(snd_mode)
        inc     a
        cp      3
        jr      c,.sm
        xor     a
.sm:    ld      (snd_mode),a
        call    save_records
        ld      a,SFX_SELECT
        call    play_sfx
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
        ld      a,SFX_SELECT
        call    play_sfx
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

; fe_wait: count down scr_t -> Z when it runs out
fe_wait:
        ld      hl,(scr_t)
        dec     hl
        ld      (scr_t),hl
        ld      a,h
        or      l
        ret

; title music, unless it is already playing
title_music:
        ld      a,(music_on)
        or      a
        ret     nz
        ld      hl,mus_title
        ld      a,1
        jp      start_music

; ---------------------------------------------------------------------
; the title: a waving logo over the storm
; ---------------------------------------------------------------------
LOGO_X  equ 12
scr_title:
        call    title_music
        ld      hl,500
        ld      (scr_t),hl
.l:     call    fe_begin
        call    draw_vortex
        call    draw_logo
        ld      hl,s_tsub
        ld      c,24
        ld      a,$55
        call    text3c
        ld      a,(gtick)
        and     8
        jr      z,.np
        ld      hl,s_tfire
        ld      c,38
        ld      a,$FF
        call    text3c
.np:    call    opts_line
        ; continue offer, or the best score
        ld      a,(cont_sec)
        or      a
        jr      z,.hi
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
        ld      a,$55
        call    text3c
        jr      .cr
.hi:    call    best_line
.cr:    ld      hl,s_credit
        ld      c,59
        xor     a
        call    text3c
        call    present
        call    fe_keys
        ret     c
        call    fe_wait
        jr      nz,.l
        or      a
        ret

; best_line: "HI 050000 BPM" at row 52
best_line:
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
        ld      c,52
        ld      a,$55
        jp      text3c

; opts_line: "D: PILOT   M: SOUND ON" at row 45
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
        ld      c,45
        ld      a,$FF
        jp      text3c

skill_names: dw s_cadet, s_pilot, s_ace
s_cadet: db "CADET",0
s_pilot: db "PILOT",0
s_ace:   db "ACE",0

; draw_logo: STARWHIRL in big letters, each bobbing on its own beat
draw_logo:
        ld      hl,logo_tab
        ld      a,LOGO_X
        ld      (lg_x),a
        xor     a
        ld      (lg_n),a
.l:     ld      a,(hl)
        cp      255
        ret     z
        ld      (lg_f),a
        inc     hl
        ld      a,(hl)              ; advance
        inc     hl
        push    hl
        push    af
        ld      a,(lg_n)
        ld      b,a
        add     a,a
        add     a,a
        add     a,a
        add     a,b                 ; letter * 9
        ld      b,a
        ld      a,(gtick)
        add     a,a
        add     a,b
        and     63
        ld      e,a
        ld      d,0
        ld      hl,sin64
        add     hl,de
        ld      a,(hl)
        sra     a
        sra     a
        sra     a
        sra     a
        sra     a                   ; -2..+2
        add     a,6
        ld      c,a
        ld      a,(lg_x)
        ld      b,a
        ld      a,(lg_f)
        call    draw_frame_g
        pop     af
        ld      hl,lg_x
        add     a,(hl)
        ld      (hl),a
        ld      hl,lg_n
        inc     (hl)
        pop     hl
        jr      .l

logo_tab:       ; frame, advance
        db      F_BIG_S,12, F_BIG_T,12, F_BIG_A,12, F_BIG_R,12, F_BIG_W,12
        db      F_BIG_H,12, F_BIG_I,8, F_BIG_R,12, F_BIG_L,12, 255

; ---------------------------------------------------------------------
; meet the swarm
; ---------------------------------------------------------------------
scr_swarm:
        ld      hl,300
        ld      (scr_t),hl
.l:     call    fe_begin
        ld      hl,s_swarm
        ld      c,1
        ld      a,$55
        call    text2xc
        ld      hl,swarm_tab
        ld      c,14
.row:   ld      a,(hl)
        cp      255
        jr      z,.done
        push    hl
        push    bc
        ; sprite (two-frame animation) centred at x 10
        ld      b,a
        ld      a,(gtick)
        and     4
        rrca
        rrca
        add     a,b
        ld      b,10
        inc     c
        inc     c
        call    draw_c
        pop     bc
        pop     hl
        inc     hl
        push    bc
        ld      b,5
        ld      a,$55
        call    text3               ; name and points
        pop     bc
        push    bc
        ld      a,$FF
        call    text3x              ; (text3 left HL on the next string)              ; what it does, on the same row, right
        pop     bc
        ld      a,c
        add     a,7
        ld      c,a
        jr      .row
.done:  call    present
        call    fe_keys
        ret     c
        call    fe_wait
        jr      nz,.l
        or      a
        ret

; text3x: HL = string drawn right-aligned on row C (column 31 - len)
text3x:
        push    af
        call    strlen
        ld      a,32
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

; ---------------------------------------------------------------------
; the demo: the computer flies sector 1 for half a minute
; ---------------------------------------------------------------------
scr_demo:
        call    stop_music
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
        call    run_game
        pop     af
        ld      (score+2),a
        pop     hl
        ld      (score),hl
        xor     a
        ld      (demo),a
        ld      (flash_t),a
        ld      (warp),a
        ld      a,MODE1
        ld      (next_vmode),a
        ld      a,(skill_sv)
        ld      (skill),a
        ld      a,(cont_sv)
        ld      (cont_sec),a
        ld      a,(snd_sv)
        ld      (snd_mode),a
        call    stop_music
        ; quit with FIRE / SPACE / RETURN: straight into a game
        ld      a,(mnu)
        bit     4,a
        ret     z
        xor     a
        ld      (start_sec),a
        scf
        ret

; ---------------------------------------------------------------------
; top pilots
; ---------------------------------------------------------------------
scr_hiscores:
        call    title_music
        ld      hl,250
        ld      (scr_t),hl
.l:     call    fe_begin
        ld      a,255
        ld      (hs_pos),a
        ld      hl,s_top
        ld      (hs_title),hl
        call    hs_draw
        call    present
        call    fe_keys
        ret     c
        call    fe_wait
        jr      nz,.l
        or      a
        ret

; hs_draw: the table; entry (hs_pos) flashes
hs_draw:
        ld      hl,(hs_title)
        ld      c,1
        ld      a,$55
        call    text2xc
        ld      b,0
.e:     push    bc
        call    hs_line
        ld      a,b
        ld      hl,hs_pos
        cp      (hl)
        ld      a,$55
        jr      nz,.c
        ld      a,(gtick)
        and     4
        ld      a,$FF
        jr      z,.c
        ld      a,$00
.c:     push    af
        ld      a,b
        add     a,a
        add     a,b
        add     a,a                 ; *6
        add     a,15
        ld      c,a
        pop     af
        ld      hl,txtbuf
        ld      b,5
        call    text3
        pop     bc
        inc     b
        ld      a,b
        cp      8
        jr      c,.e
        ret

; hs_line: B = entry -> txtbuf "1  BPM  050000  S5"
hs_line:
        push    bc
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,HISC
        add     hl,de
        push    hl
        ld      de,txtbuf
        ld      a,b
        add     a,'1'
        ld      (de),a
        inc     de
        ld      a,' '
        ld      (de),a
        inc     de
        ld      (de),a
        inc     de
        pop     hl
        push    hl
        inc     hl
        inc     hl
        inc     hl
        ld      bc,3
        ldir
        ld      a,' '
        ld      (de),a
        inc     de
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
        ld      (de),a
        inc     de
        ld      a,'S'
        ld      (de),a
        inc     de
        pop     hl
        ld      bc,6
        add     hl,bc
        ld      a,(hl)
        add     a,'0'
        ld      (de),a
        inc     de
        xor     a
        ld      (de),a
        pop     bc
        ret

; ---------------------------------------------------------------------
; how to fly
; ---------------------------------------------------------------------
scr_howto:
        ld      hl,300
        ld      (scr_t),hl
.l:     call    fe_begin
        ld      hl,s_howto
        ld      c,1
        ld      a,$55
        call    text2xc
        ld      hl,howto_txt
        ld      c,14
.r:     ld      a,(hl)
        or      a
        jr      z,.d
        ld      a,(hl)
        cp      '*'
        ld      a,$FF
        jr      nz,.n
        inc     hl
        ld      a,$55
.n:     push    bc
        call    text3c
        pop     bc
        ld      a,c
        add     a,6
        ld      c,a
        jr      .r
.d:     call    present
        call    fe_keys
        ret     c
        call    fe_wait
        jr      nz,.l
        or      a
        ret

howto_txt:
        db      "STICK OR W A S D: SWING ROUND",0
        db      "TO THAT SIDE OF THE ORBIT",0
        db      "Z AND X: TURN ROUND STEADILY",0
        db      "FIRE OR SPACE: SHOOT (HOLD IT)",0
        db      "*SHIELDS SOAK UP HITS",0
        db      "*WIPE OUT A FORMATION: BONUS",0
        db      "*HIT THEM CLOSE IN: DOUBLE",0
        db      "*SHOOT THE POD: TWIN SHOT",0
        db      0

; ---------------------------------------------------------------------
; game over: one more go?
; ---------------------------------------------------------------------
scr_again:
        call    stop_music
        ld      hl,250
        ld      (scr_t),hl
.l:     call    fe_begin
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
        ld      c,20
        ld      a,$55
        call    text3c
        ld      a,(gtick)
        and     8
        jr      z,.nf
        ld      hl,s_again
        ld      c,32
        ld      a,$FF
        call    text3c
.nf:    ld      a,(cont_sec)
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
        ld      c,40
        ld      a,$55
        call    text3c
        ld      hl,s_contnote
        ld      c,46
        xor     a
        call    text3c
.nc:    ; countdown
        ld      hl,(scr_t)
        ld      a,l
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l                   ; /32 -> 7..0
        ld      a,l
        call    byte_to_str
        inc     hl                  ; one digit
        ld      c,53
        ld      a,$55
        call    text2xc
        call    present
        call    fe_keys
        ret     c
        call    fe_wait
        jp      nz,.l
        or      a
        ret

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
.lower: pop     hl                  ; equal or lower: try the next
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
        ; move the ones below down a place
        ld      a,7
        sub     b
        jr      z,.put
        ld      c,a
        xor     a
        ld      b,a
        sla     c
        sla     c
        sla     c                   ; bytes to move
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
        ld      a,9                 ; went round: show S9
        ld      (de),a
.e:     call    enter_name
        jp      save_records

; enter_name: initials for entry (hs_pos).  Type letters on the keyboard,
;   or stick up/down to pick and FIRE to move on.  RETURN finishes.
enter_name:
        ld      hl,mus_hiscore
        xor     a
        call    start_music
        xor     a
        ld      (hs_cur),a
        ld      hl,3000
        ld      (scr_t),hl
.l:     call    fe_begin
        ld      hl,s_newhi
        ld      (hs_title),hl
        call    hs_draw
        ; cursor under the letter being entered
        ld      a,(hs_pos)
        ld      b,a
        add     a,a
        add     a,b
        add     a,a
        add     a,21
        ld      c,a
        ld      a,(hs_cur)
        add     a,8                 ; column 5+3+cur -> pixel *4
        add     a,a
        add     a,a
        ld      b,a
        ld      d,a
        inc     d
        inc     d
        ld      e,$FF
        call    hline
        call    present
        ; this entry's letter
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
        add     hl,de               ; HL -> the letter
        ; typed?
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
        bit     2,c                 ; up
        jr      z,.dn
        call    letter_up
        ld      (hl),a
.dn:    bit     3,c
        jr      z,.to
        call    letter_dn
        ld      (hl),a
.to:    call    fe_wait
        jp      nz,.l
.done:  jp      stop_music
.next:  ld      a,SFX_SELECT
        call    play_sfx
        ld      a,(hs_cur)
        inc     a
        ld      (hs_cur),a
        cp      3
        jp      c,.l
        ; a last look
        ld      b,40
.w:     push    bc
        call    fe_begin
        call    hs_draw
        call    present
        pop     bc
        djnz    .w
        jp      stop_music

; letter_up / letter_dn: A = letter -> next / previous (A-Z, space)
letter_up:
        cp      ' '
        jr      z,.a
        inc     a
        cp      'Z'+1
        ret     c
        ld      a,' '
        ret
.a:     ld      a,'A'
        ret
letter_dn:
        cp      ' '
        jr      z,.z
        dec     a
        cp      'A'
        ret     nc
        ld      a,' '
        ret
.z:     ld      a,'Z'
        ret

; scan_letter -> A = a newly pressed letter key (0 = none)
scan_letter:
        ld      hl,$68FE
        ld      de,key_letters
        ld      c,0                 ; found
.r:     ld      a,(hl)
        cpl
        and     $3F
        add     a,a
        add     a,a
        ld      b,6
.b:     add     a,a                 ; bit 5 first
        push    af
        jr      nc,.nk
        ld      a,(de)
        or      a
        jr      z,.nk
        ld      c,a
.nk:    pop     af
        inc     de
        djnz    .b
        ld      a,l                 ; next row
        rlca
        ld      l,a
        cp      $FE
        jr      nz,.r
        ; only report it on the press
        ld      a,(last_letter)
        cp      c
        ld      a,c
        ld      (last_letter),a
        ret     nz
        xor     a
        ret

key_letters:    ; rows 0..7, bit 5 down to bit 0
        db      "RQE",0,"WT"
        db      "FAD",0,"SG"
        db      "VZC",0,"XB"
        db      0,0,0,0,0,0
        db      "M",0,0,0,0,"N"
        db      0,0,0,0,0,0
        db      "UPI",0,"OY"
        db      "J",0,"K",0,"LH"

; ---------------------------------------------------------------------
; records: high scores, skill and sound kept in the BennVenn SRAM's second
; bank, so they last through a reload while the machine stays on.  Same
; bank probe as DUEL II and ROBOGEDDON, at an address of its own.
; ---------------------------------------------------------------------
SAVEADR equ $6500
REC_LEN equ 4+64+2

; (called once at start-up, with the interrupt off; it leaves it off)
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
        ld      (skill),a
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
        ret

rec_sig: db "SWL1"

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
        ld      a,(skill)
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

; ---------------------------------------------------------------------
; front-end text
; ---------------------------------------------------------------------
s_tsub:     db "THE STORM AT THE CORE",0
s_tfire:    db "PRESS FIRE TO PLAY",0
s_tcont:    db "C  CONTINUE FROM SECTOR ",0
s_contnote: db "(SCORE STARTS AGAIN)",0
s_credit:   db "VIBED BY BPM 2026",0
s_hi:       db "HI ",0
s_od:       db "D ",0
s_om:       db "   M ",0
s_swarm:    db "THE SWARM",0
s_top:      db "TOP PILOTS",0
s_howto:    db "HOW TO FLY",0
s_score:    db "SCORE ",0
s_again:    db "FIRE  ONE MORE GO",0
s_newhi:    db "YOUR INITIALS",0
