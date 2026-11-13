; =====================================================================
;  ATTRACT: start-up, then round and round:
;   TITLE   - the rainbow logo, a train of spinning balls round the edge,
;             the hero and two robots dancing; the title jingle
;   STORY   - typed out, with the last human family
;   GALLERY - the robots beam in one by one, double size and animated
;   LEGENDS - the hall of legends (high scores)
;   DEMO    - the game plays itself
;  SPACE, RETURN, a fire key or joystick fire starts a game.
; =====================================================================
ATT_TITLE   equ 0
ATT_STORY   equ 1
ATT_GALLERY equ 2
ATT_LEGENDS equ 3
ATT_DEMO    equ 4

start:
        ld a,r
        ld l,a
        ld h,$A7
        ld (seed),hl
        ld a,2
        ld (soundmode),a
        call apply_sound
        ld hl,hs_default
        ld de,hs_tab
        ld bc,8*6
        ldir
        ld a,64
        ld (blade_spd),a
        call load_pcg
        ld a,(boot_test)
        or a
        jp nz,game_new
        ; fall into the title

title:
        ld sp,STACK
        xor a
        ld (att),a
        ld (demo),a
        ld (paused),a
att_loop:
        ld sp,STACK
        xor a
        ld (fxt),a
        ld (fxt+1),a
        call stop_music
        ld a,(att)
        or a
        jp z,att_title
        dec a
        jp z,att_story
        dec a
        jp z,att_gallery
        dec a
        jp z,att_legends
        jp demo_start

; next_att: on to the next screen of the round
next_att:
        ld a,(att)
        inc a
        cp 5
        jr c,$+3
        xor a
        ld (att),a
        jp att_loop

; att_frame: one attract frame: keys (a start key starts the game, M the
; sound), sound, wait. NZ when the screen's time (HL frames) is up.
att_frame:
        push hl
        call read_input
        ld a,(keysnew)
        ld b,a
        ld a,(padnew)
        ld c,a
        call input_used
        bit 3,b
        jp nz,game_new
        bit 4,c
        jp nz,game_new
        ld a,(firepad)
        or a
        jr z,.nf
        ld a,(firewait)         ; a fire key held from the last game
        or a                    ; must be let go of first
        jp z,game_new
        jr .f2
.nf:    xor a
        ld (firewait),a
.f2:    bit 2,b
        call nz,toggle_sound
        call sound_tick
        ld a,2
        call frame_wait
        ld hl,(fxt)
        inc hl
        ld (fxt),hl
        pop de
        or a
        sbc hl,de
        ld a,h
        or l
        ret                     ; Z = time up (fxt == HL)

; ---------------------------------------------------------------------
att_title:
        call clear_both
        call show_title_pic
        ld hl,s_hiscore
        ld de,23*40+10
        ld c,GREY
        call p0_text
        ld hl,hiscore
        ld de,23*40+21
        ld c,BCYAN
        call p0_bcd
        ld hl,hs_tab+3
        ld de,23*40+28
        ld c,YELLOW
        call p0_n3
        ld hl,mus_title_0
        ld de,mus_title_1
        call song
.f:     call title_balls
        ld d,3
        ld e,12
        call rainbow_rows
        ; the hero between a stomper and a crusher, dancing
        ld a,(fxt)
        and 7
        jr nz,.nd
        ld a,(fxt)
        rrca
        rrca
        rrca
        and 1
        ld (t_k),a
        add a,BF_BSTOMP
        ld hl,14*40+7
        ld c,YELLOW
        ld b,BRED
        call big2
        ld a,(t_k)
        add a,BF_HERO
        ld hl,14*40+18
        ld c,WHITE
        ld b,BCYAN
        call big2
        ld a,(t_k)
        add a,BF_BCRUSH
        ld hl,14*40+30
        ld c,BGREEN
        ld b,GREEN
        call big2
        ; blink the start prompt
        ld a,(fxt)
        and 16
        ld hl,s_start
        jr z,$+5
        ld hl,s_blank28
        ld e,21
        ld c,WHITE
        call p0_ctext
.nd:    ld hl,300
        call att_frame
        jp nz,.f
        jp next_att

; big2: big frame A at offset HL, top colour C, bottom colour B
big2:   push af
        ld a,b
        ld (ds_col2),a
        pop af
        jp p0_big

; ---------------------------------------------------------------------
story_text:
        db "THE YEAR IS 2086.",0
        db 0
        db "THE ROBOT FACTORIES HAVE",0
        db "RISEN UP. THEIR MACHINES",0
        db "SWARM THE CITY, AND THEY",0
        db "MEAN TO WIPE OUT HUMANITY.",0
        db 0
        db "ONE CYBORG HERO STANDS IN",0
        db "THEIR WAY, PLASMA GUN BLAZING.",0
        db 0
        db "SAVE THE LAST HUMAN FAMILY!",0
        db $FF

att_story:
        call clear_both
        call show0
        ld hl,story_text
        ld (typ_p),hl
        ld hl,3*40+5
        ld (typ_o),hl
        ld (typ_l),hl
.f:     call glow_border
        call typewriter
        ld a,(fxt)
        cp 220
        jr nz,.nf
        ld a,BF_BFAM            ; the family appears
        ld hl,17*40+11
        ld c,BCYAN
        ld b,BBLUE
        call big2
        ld a,BF_BFAM+2
        ld hl,17*40+16
        ld c,YELLOW
        ld b,BMAGENTA
        call big2
        ld a,BF_BFAM+4
        ld hl,17*40+21
        ld c,YELLOW
        ld b,BGREEN
        call big2
        ld a,BF_HERO
        ld hl,17*40+28
        ld c,WHITE
        ld b,BCYAN
        call big2
        ld a,SFX_RESCUE
        call play_sfx
.nf:    ld a,(fxt)
        cp 221
        jr c,.nw
        and 7
        jr nz,.nw
        ld a,(fxt)              ; and waves
        rrca
        rrca
        rrca
        and 1
        add a,BF_BFAM
        ld hl,17*40+11
        ld c,BCYAN
        ld b,BBLUE
        call big2
.nw:    ld hl,330
        call att_frame
        jp nz,.f
        jp next_att

; typewriter: the next character of the story
typewriter:
        ld hl,(typ_p)
        ld a,(hl)
        cp $FF
        ret z
        inc hl
        ld (typ_p),hl
        or a
        jr z,.nl
        add a,$A0
        ld b,a
        ld hl,(typ_o)
        ld c,BGREEN
        ld d,0
        call p0_put
        inc hl
        ld (typ_o),hl
        ld a,b
        cp $C0                  ; a space makes no click
        ret z
        ld a,SFX_TYPE
        jp play_sfx
.nl:    ld hl,(typ_l)
        ld de,40
        add hl,de
        ld (typ_l),hl
        ld (typ_o),hl
        ret

; ---------------------------------------------------------------------
;  the gallery: big frame, top colour, bottom colour, name, points, words
gallery:
        db BF_BSTOMP,YELLOW,BRED
        dw .n1,.p1,.d1
        db BF_BZAP,BCYAN,BMAGENTA
        dw .n2,.p2,.d2
        db BF_BCRUSH,BGREEN,GREEN
        dw .n3,.p3,.d3
        db BF_BWHIRL,BCYAN,WHITE
        dw .n4,.p4,.d4
        db BF_BNODE,BMAGENTA,BBLUE
        dw .n5,.p5,.d5
.n1:    db "STOMPER",0
.p1:    db "100",0
.d1:    db "STOMPS STRAIGHT FOR YOU",0
.n2:    db "ZAPPER",0
.p2:    db "200",0
.d2:    db "ZAPS WHERE YOU ARE GOING",0
.n3:    db "CRUSHER",0
.p3:    db "500",0
.d3:    db "4 HITS. SQUASHES HUMANS",0
.n4:    db "WHIRLER",0
.p4:    db "150",0
.d4:    db "SPINS IN FROM THE CORNERS",0
.n5:    db "SHOCK NODE",0
.p5:    db "25",0
.d5:    db "DON'T TOUCH. FRIES STOMPERS",0
s_riot: db "MEET THE RIOT",0

att_gallery:
        call clear_both
        call show0
        ld hl,s_riot
        ld e,1
        ld c,YELLOW
        call p0_ctext
        xor a
        ld (t_n),a
.f:     call glow_border
        ; every 50 frames another robot beams in (20 frames of sparkle)
        ld a,6
        ld (t_k),a
        ld a,(fxt+1)
        or a
        jr nz,.all
        ld a,(fxt)
        ld b,50
        call div8
        ld (t_k),a              ; quotient = robot number
        ld a,c
        ld (t_k2),a             ; frames into its turn
.all:
        ld a,(t_k)
        cp 5
        jr nc,.anim
        ld a,(t_k2)
        or a
        jr nz,.sp
        ld a,SFX_BEAM
        call play_sfx
.sp:    ld a,(t_k2)
        cp 20
        jr nc,.show
        ld a,(t_k)              ; sparkle: random cells round where it lands
        call sparkle
        jr .anim
.show:  cp 20
        jr nz,.anim
        ld a,(t_k)
        call gal_draw
        ld a,(t_k)
        call gal_text
.anim:  ld a,(fxt)              ; the ones already here dance
        and 7
        jr nz,.w
        ld a,(t_k)
        cp 6
        jr c,$+4
        ld a,5
        ld b,a
        or a
        jr z,.w
.al:    push bc
        ld a,b
        dec a
        call gal_draw
        pop bc
        djnz .al
.w:     ld hl,340
        call att_frame
        jp nz,.f
        jp next_att

; gal_draw: draw robot A (frame by (fxt))
gal_draw:
        call gal_ent
        ld a,(fxt)
        rrca
        rrca
        rrca
        and 1
        add a,(ix+0)
        ld c,(ix+1)
        ld b,(ix+2)
        jp big2

; gal_ent: robot A -> IX = entry, HL = screen offset of its big sprite
gal_ent:
        ld b,a
        ld e,a
        add a,a
        add a,a
        add a,a
        add a,e                 ; x 9
        ld e,a
        ld d,0
        ld ix,gallery
        add ix,de
        ld hl,3*40+4
        ld de,4*40
        inc b
.l:     dec b
        ret z
        add hl,de
        jr .l

gal_text:
        call gal_ent
        ld de,6                 ; name and points on the top row
        add hl,de
        push hl
        ex de,hl
        ld l,(ix+3)
        ld h,(ix+4)
        ld c,(ix+1)
        call p0_text
        pop hl
        push hl
        ld de,25
        add hl,de
        ex de,hl
        ld l,(ix+5)
        ld h,(ix+6)
        ld c,WHITE
        call p0_text
        pop hl
        ld de,40
        add hl,de
        ex de,hl
        ld l,(ix+7)
        ld h,(ix+8)
        ld c,GREY
        jp p0_text

; sparkle: a few random sparkles in the 3 x 3 cells at HL (+ a beam sound)
sparkle:
        call gal_ent
        ld b,3
.r:     push bc
        push hl
        ld b,3
.c:     push bc
        push hl
        call random
        ld e,a
        call random
        pop hl
        ld c,a
        ld a,e
        and 3
        ld b,$80
        jr nz,.e
        ld a,e
        rrca
        rrca
        and 7
        add a,G_SPARK
        ld b,a
.e:     ld a,c
        and 7
        add a,8
        ld c,a
        ld d,0
        call p0_put
        inc hl
        pop bc
        djnz .c
        pop hl
        ld de,40
        add hl,de
        pop bc
        djnz .r
        ret

; div8: A / B -> A = quotient, C = remainder
div8:   ld c,0
.l:     cp b
        jr c,.x
        sub b
        inc c
        jr .l
.x:     ld b,a
        ld a,c
        ld c,b
        ret

; ---------------------------------------------------------------------
;  the hall of legends
s_legends: db "HALL OF LEGENDS",0
s_hiscore: db "HIGH SCORE",0
s_start: db "SPACE OR A FIRE KEY TO START",0
s_blank28: db "                            ",0

hs_default:
        db $05,$00,$00,"BPM"
        db $04,$00,$00,"ZAK"
        db $03,$00,$00,"VIC"
        db $02,$50,$00,"MEG"
        db $02,$00,$00,"RIO"
        db $01,$50,$00,"ACE"
        db $01,$00,$00,"BOB"
        db $00,$50,$00,"DOT"

att_legends:
        call clear_both
        call show0
        ld hl,s_legends
        ld e,2
        ld c,YELLOW
        call p0_ctext
        ld hl,mus_fame_0
        ld de,mus_fame_1
        call song
        call draw_legends
.f:     call glow_border
        ld a,(fxt)
        and 3
        call z,legend_cols
        ld hl,200
        call att_frame
        jp nz,.f
        jp next_att

; draw_legends: the 8 entries, rows 5, 7 .. 19
draw_legends:
        ld ix,hs_tab
        ld b,0
.l:     push bc
        ld a,b
        add a,a
        add a,5
        call row_off
        ld de,11
        add hl,de
        ex de,hl                ; DE = offset
        pop bc
        push bc
        ld a,b
        inc a
        add a,$D0               ; rank digit
        push bc
        ld b,a
        ex de,hl
        ld d,0
        ld c,WHITE
        call p0_put
        ex de,hl
        inc de
        inc de
        inc de
        push ix
        pop hl
        inc hl
        inc hl
        inc hl
        ld c,YELLOW
        call p0_n3
        inc de
        inc de
        inc de
        inc de
        push ix
        pop hl
        ld c,WHITE
        call p0_bcd
        pop bc
        pop bc
        ld de,6
        add ix,de
        inc b
        ld a,b
        cp 8
        jr nz,.l
        ret

; legend_cols: the rows of the hall in colours that roll down
legend_cols:
        ld a,COL_ON
        out (P_COLCTL),a
        ld b,0
.l:     push bc
        ld a,b
        add a,a
        add a,5
        call row_off
        ld de,$F800+11
        add hl,de
        pop bc
        push bc
        ld a,(fxt)
        rrca
        rrca
        sub b
        and 7
        add a,a
        ld e,a
        ld d,rainbow/256
        ld a,(hs_new)
        cp b
        jr nz,.n
        ld a,(fxt)              ; the new entry flashes
        and 4
        ld a,WHITE
        jr z,.s
        ld a,BRED
        jr .s
.n:     ld a,(de)
.s:     ld b,16
.c:     ld (hl),a
        inc hl
        djnz .c
        pop bc
        inc b
        ld a,b
        cp 8
        jr nz,.l
        xor a
        out (P_COLCTL),a
        ret

; p0_n3: the 3 letters at HL to offset DE (DE moves on 3), colour C
p0_n3:  ld b,3
.l:     push bc
        ld a,(hl)
        add a,$A0
        ld b,a
        push hl
        ex de,hl
        ld d,0
        call p0_put
        ex de,hl
        pop hl
        inc hl
        inc de
        pop bc
        djnz .l
        ret

; p0_bcd: 3 BCD bytes at HL as 6 digits to offset DE (moves on), colour C
p0_bcd: ld b,3
.l:     push bc
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        call .d
        ld a,(hl)
        call .d
        inc hl
        pop bc
        djnz .l
        ret
.d:     and 15
        add a,$D0
        push hl
        push bc
        ld b,a
        ex de,hl
        ld d,0
        call p0_put
        ex de,hl
        inc de
        pop bc
        pop hl
        ret

; ---------------------------------------------------------------------
;  a new high score: type the initials
s_great: db "GREAT SHOOTING, HERO!",0
s_made: db "YOU MADE THE HALL OF LEGENDS",0
s_type: db "TYPE YOUR INITIALS",0
s_orjoy: db "(OR UP / DOWN AND FIRE)",0

; check_hi: is the score in the hall? -> hs_new = its place (0-7) or $FF;
; makes room for it (initials "   ")
check_hi:
        ld a,$FF
        ld (hs_new),a
        ld ix,hs_tab
        ld b,0
.l:     ld hl,score
        ld a,(ix+0)
        cp (hl)
        jr c,.in
        jr nz,.n
        inc hl
        ld a,(ix+1)
        cp (hl)
        jr c,.in
        jr nz,.n
        inc hl
        ld a,(ix+2)
        cp (hl)
        jr c,.in
.n:     ld de,6
        add ix,de
        inc b
        ld a,b
        cp 8
        jr nz,.l
        ret
.in:    ld a,b
        ld (hs_new),a
        ; move the entries below down one
        ld a,7
        sub b
        jr z,.put
        ld c,a
        ld b,0
        ld h,b
        ld l,c
        add hl,hl
        add hl,bc
        add hl,hl               ; x 6
        ld b,h
        ld c,l
        ld hl,hs_tab+6*7-1
        ld de,hs_tab+6*8-1
        lddr
.put:   push ix
        pop de
        ld hl,score
        ld bc,3
        ldir
        ld a,' '
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        ret

hs_entry:
        ld sp,STACK
        call stop_music
        call clear_both
        call show0
        ld hl,s_great
        ld e,4
        ld c,YELLOW
        call p0_ctext
        ld hl,s_made
        ld e,6
        ld c,WHITE
        call p0_ctext
        ld hl,s_type
        ld e,10
        ld c,BGREEN
        call p0_ctext
        ld hl,s_orjoy
        ld e,11
        ld c,GREY
        call p0_ctext
        ld hl,mus_fame_0
        ld de,mus_fame_1
        call song
        xor a
        ld (fxt),a
        ld (fxt+1),a
        ld (ent_pos),a
        ld (ent_last),a
        ld a,'A'
        ld (ent_ch),a
.f:     call glow_border
        call ent_show
        call read_input
        call scan_letter
        ld hl,ent_last
        cp (hl)
        ld (hl),a
        jr z,.nk
        or a
        jr z,.nk
        add a,'A'-1
        call ent_add
        jr .chk
.nk:    ld a,(keysnew)          ; RETURN: done
        bit 3,a
        jr z,.nr
        ld a,(pad)
        and 16
        jr z,.done              ; (RETURN, not SPACE-fire)
.nr:    ld a,(padnew)           ; joystick: up / down choose, fire takes
        ld b,a
        ld a,(firepad)
        ld c,a
        ld a,(ent_fp)
        cpl
        and c
        or b
        ld b,a
        ld a,c
        ld (ent_fp),a
        bit 2,b
        jr z,.nu
        ld a,(ent_ch)
        inc a
        cp 'Z'+1
        jr c,$+4
        ld a,'A'
        ld (ent_ch),a
        ld a,SFX_TYPE
        call play_sfx
.nu:    bit 3,b
        jr z,.nd
        ld a,(ent_ch)
        dec a
        cp 'A'
        jr nc,$+4
        ld a,'Z'
        ld (ent_ch),a
        ld a,SFX_TYPE
        call play_sfx
.nd:    bit 4,b
        jr z,.chk
        ld a,(ent_ch)
        call ent_add
.chk:   ld a,(ent_pos)
        cp 3
        jr nc,.done
        call input_used
        call sound_tick
        ld a,2
        call frame_wait
        ld hl,(fxt)
        inc hl
        ld (fxt),hl
        ld de,750               ; 30 seconds
        or a
        sbc hl,de
        jp nz,.f
.done:  call input_used
        ld a,SFX_LIFE
        call play_sfx
        ld a,1
        ld (firewait),a
        ld a,ATT_LEGENDS
        ld (att),a
        jp att_loop

; ent_add: letter A goes in the next place
ent_add:
        ld b,a
        ld a,(ent_pos)
        cp 3
        ret nc
        call ent_ptr
        ld (hl),b
        ld hl,ent_pos
        inc (hl)
        ld a,'A'
        ld (ent_ch),a
        ld a,SFX_RESCUE
        jp play_sfx

; ent_ptr: HL = the new entry's letter number (ent_pos)
ent_ptr:
        ld a,(hs_new)
        ld e,a
        add a,a
        add a,e
        add a,a
        add a,3
        ld e,a
        ld a,(ent_pos)
        add a,e
        ld e,a
        ld d,0
        ld hl,hs_tab
        add hl,de
        ret

; ent_show: the three letters, big and bright, the current one blinking
ent_show:
        ld a,(hs_new)
        ld e,a
        add a,a
        add a,e
        add a,a
        add a,3
        ld e,a
        ld d,0
        ld hl,hs_tab
        add hl,de
        ld de,14*40+18
        ld b,0
.l:     push bc
        ld a,(ent_pos)
        cp b
        ld a,(hl)
        ld c,WHITE
        jr nz,.s
        ld a,(fxt)
        and 8
        ld a,(ent_ch)
        ld c,YELLOW
        jr z,.s
        ld a,'_'
.s:     add a,$A0
        push hl
        push de
        ld b,a
        ex de,hl
        ld d,0
        call p0_put
        pop de
        pop hl
        inc hl
        inc de
        inc de
        pop bc
        inc b
        ld a,b
        cp 3
        jr nz,.l
        ret

; scan_letter: A = the letter key held (1-26) or 0
scan_letter:
        ld a,1
        out (P_ROMLAT),a
        ld c,1
.l:     ld a,c
        push bc
        call keytest
        pop bc
        jr nz,.y
        inc c
        ld a,c
        cp 27
        jr nz,.l
        xor a
        out (P_ROMLAT),a
        ret
.y:     xor a
        out (P_ROMLAT),a
        ld a,c
        ret

; ---------------------------------------------------------------------
;  the demo: wave 3 played by the machine, for 20 seconds or a life
demo_start:
        ld a,1
        ld (demo),a
        ld hl,500
        ld (demo_t),hl
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld (paused),a
        inc a
        ld (lives),a
        ld a,3
        ld (wave),a
        jp game_screen

; ai_input: the demo's pad and fire, from the nearest robot and family member
ai_input:
        ld a,$FF
        ld (t_best),a
        xor a
        ld (ai_fire),a
        ld (ai_move),a
        ld iy,actors
        ld b,NACT
.l:     ld a,(iy+A_T)
        dec a
        cp T_HUMAN
        jr nc,.n
        push bc
        ld a,(px)
        sub (iy+A_X)
        ld d,a
        ld a,(py)
        sub (iy+A_Y)
        ld e,a
        call cheb
        ld hl,t_best
        cp (hl)
        jr nc,.nb
        ld (hl),a
        ld a,d                  ; away from it, and fire at it
        call sgn
        ld (t_tx),a
        ld a,e
        call sgn
        ld (t_ty),a
.nb:    pop bc
.n:     ld de,ASZ
        add iy,de
        djnz .l
        ld a,(t_best)
        cp $FF
        ret z
        ld a,(t_tx)             ; fire towards it (the opposite of "away")
        neg
        ld d,a
        ld a,(t_ty)
        neg
        ld e,a
        call bits_of
        ld (firepad),a
        ld a,(t_best)
        cp 12
        jr nc,.far
        ld a,(t_tx)
        ld d,a
        ld a,(t_ty)
        ld e,a
        call bits_of
        ld (pad),a
        ret
.far:   ld a,(gtick)            ; wander, drifting back to the middle
        and 63
        jr nz,.keep
        ld a,CX
        ld hl,px
        sub (hl)
        call sgn
        ld d,a
        ld a,CY
        ld hl,py
        sub (hl)
        call sgn
        ld e,a
        call random
        and 1
        jr z,$+3
        ld d,0
        call bits_of
        ld (ai_last),a
.keep:  ld a,(ai_last)
        ld (pad),a
        ret

; bits_of: D, E (-1, 0, 1) -> R L U D bits
bits_of:
        xor a
        bit 7,d
        jr z,.d1
        or 2
        jr .dy
.d1:    inc d
        dec d
        jr z,.dy
        or 1
.dy:    bit 7,e
        jr z,.e1
        or 4
        ret
.e1:    inc e
        dec e
        ret z
        or 8
        ret

boot_test: db 0
