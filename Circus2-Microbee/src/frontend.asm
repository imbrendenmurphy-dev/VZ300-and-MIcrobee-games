attract:
 call title_redraw
 ld hl,mus_title0
 ld de,mus_title1
 call play_music
 xor a
 ld (title_time),a
.wait:
 call snd_tick
 ld a,2
 call syncframe
 ld a,19
 call key_test
 jr z,.difficulty
 ld a,(snd_on)
 xor 1
 ld (snd_on),a
 call wait_release
 call title_redraw
.difficulty:
 ld a,4
 call key_test
 jr z,.help
 ld a,(difficulty)
 inc a
 cp 3
 jr c,$+3
 xor a
 ld (difficulty),a
 call wait_release
 call title_redraw
.help:
 ld a,13
 call key_test
 jr z,.notmono
 ld a,(mono_mode)
 xor 1
 ld (mono_mode),a
 call wait_release
 jp attract
.notmono:
 ld a,20
 call key_test
 jr z,.not_scores
 call show_scores
 jp attract
.not_scores:
 ld a,8
 call key_test
 jr z,.start
 call howto_screen
 jp attract
.start:
 call readinput
 and 16
 jr nz,.play
 ld a,$34
 call key_test
 jr nz,.play
 ld hl,title_time
 inc (hl)
 jr nz,.wait
 ld a,(demo_act)
 inc a
 cp 9
 jr c,$+3
 xor a
 ld (demo_act),a
 xor a
 ld (demo_key),a
 ld a,1
 call game_main
 ld a,(demo_key)
 or a
 jp nz,.play
 jp attract
.play:
 call wait_release
 xor a
 call game_main
 jp attract
title_redraw:
 ld a,9
 call load_scene
 call show_difficulty
 jp present
; status plaque on the ring: "NORMAL - SOUND ON"
show_difficulty:
 ld a,(difficulty)
 add a,a
 ld e,a
 ld d,0
 ld hl,diff_names
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 ex de,hl
 ld de,strbuf
 call strcpy
 ld hl,mb_sound
 call strcpy
 ld hl,mb_on
 ld a,(snd_on)
 or a
 jr nz,$+5
 ld hl,mb_off
 call strcpy
 ld hl,strbuf
 ld c,53
 jp textc
diff_names: dw txt_easy,txt_normal,txt_hard
mb_sound: db " - SOUND ",0
mb_on: db "ON",0
mb_off: db "OFF",0
howto_screen:
 xor a
 call load_scene
 ld hl,txt_howto
 ld c,5
 call bigc
 ld hl,mb_help1
 ld c,13
 call textc
 ld hl,mb_help2
 ld c,18
 call textc
 ld hl,mb_help3
 ld c,30
 call textc
 ld hl,mb_help4
 ld c,35
 call textc
 ld hl,mb_help5
 ld c,40
 call textc
 ld hl,mb_help6
 ld c,45
 call textc
 call present
 call wait_release
.wait: call anykey
 jr z,.wait
 jp wait_release
mb_help1: db "CATCH ON THE RAISED END",0
mb_help2: db "THE TIP GIVES A PERFECT LEAP",0
mb_help3: db "Z/X OR ARROWS MOVE. SPACE FLIPS",0
mb_help4: db "P PAUSES. Q QUITS WHEN PAUSED",0
mb_help5: db "GIFTS: WIDE SLOW NET DOUBLE",0
mb_help6: db "UMBRELLA FIREWORKS EXTRA LIFE",0

native_hud:
 ld hl,score
 ld de,strbuf
 ld b,3
.score: ld a,(hl)
 rrca
 rrca
 rrca
 rrca
 and 15
 add a,'0'
 ld (de),a
 inc de
 ld a,(hl)
 and 15
 add a,'0'
 ld (de),a
 inc de
 inc hl
 djnz .score
 xor a
 ld (de),a
 ld hl,strbuf
 ld b,1
 ld c,59
 call drawtext
 ld hl,mb_lives
 ld de,strbuf
 call strcpy
 ld a,(lives)
 call act_number
 ld hl,strbuf
 ld b,9
 ld c,59
 call drawtext
 ld hl,txt_act
 ld de,strbuf
 call strcpy
 ld a,(act)
 inc a
 call act_number
 ld hl,strbuf
 ld b,19
 ld c,59
 call drawtext
 ld hl,mb_combo
 ld de,strbuf
 call strcpy
 ld a,(combo)
 call act_number
 ld hl,strbuf
 ld b,26
 ld c,59
 jp drawtext
mb_lives: db "LIVES ",0
mb_combo: db "X",0
hiscore_check:
        ; find position: first entry with score < our score
        ld hl,hiscores+3
        ld b,0
.f:     push hl
        ld de,score
        ld c,3
.cmp:   ld a,(de)
        cp (hl)
        jr c,.lower             ; our digit smaller -> not here
        jr nz,.higher
        inc hl
        inc de
        dec c
        jr nz,.cmp
.lower: pop hl
        ld de,6
        add hl,de
        inc b
        ld a,b
        cp 5
        jr nz,.f
        ret                     ; not in the table
.higher:
        pop hl
        ; B = rank (0..4).  shift entries down
        ld a,b
        ld (hs_rank),a
        ld a,4
        sub b
        jr z,.noshift
        ; bytes to move = (4-b)*6, from end backwards
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; *6
        ld b,h
        ld c,l
        ld hl,hiscores+23
        ld de,hiscores+29
        lddr
.noshift:
        ; entry address
        ld a,(hs_rank)
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,hiscores
        add hl,de
        ld (hs_ptr),hl
        ld (hl),'-'             ; placeholders until typed
        inc hl
        ld (hl),'-'
        inc hl
        ld (hl),'-'
        inc hl
        ex de,hl
        ld hl,score
        ld bc,3
        ldir
 call clear_scene
 ld hl,txt_newhigh
 ld c,14
 call bigc
 ld hl,mb_initials
 ld c,24
 call textc
 call present
 ld a,3
 ld (hs_pos),a
 ld hl,(hs_ptr)
 ld (hs_entry_base),hl
 call show_initials
.name:
 ld a,1
.scan: push af
 call key_test
 jr nz,.got
 pop af
 inc a
 cp 27
 jr nz,.scan
 jr .name
.got: pop af
 add a,'A'-1
 ld hl,(hs_ptr)
 ld (hl),a
 inc hl
 ld (hs_ptr),hl
 call show_initials
 call wait_release
 ld hl,hs_pos
 dec (hl)
 jr nz,.name
 jp show_scores
mb_initials: db "TYPE THREE INITIALS",0

show_initials:
 ld hl,(hs_entry_base)
 ld de,strbuf
 ld bc,3
 ldir
 xor a
 ld (de),a
 ld hl,strbuf
 ld c,36
 call bigc
 jp present
show_scores:
 xor a
 call load_scene
 ld hl,mb_top
 ld c,7
 call bigc
 ld hl,hiscores
 ld c,30
 ld b,5
.row:
 push bc
 push hl
 ld de,strbuf
 call hs_fmt
 ld hl,strbuf
 pop de
 pop bc
 push bc
 push de
 call textc
 pop hl
 ld de,6
 add hl,de
 pop bc
 ld a,c
 add a,5
 ld c,a
 djnz .row
 call present
 call wait_release
.wait:
 call anykey
 jr z,.wait
 jp wait_release
mb_top: db "TOP CLOWNS",0

init_hiscores:
        ld hl,hs_default
        ld de,hiscores
        ld bc,30
        ldir
        ret

hs_default:
        db "BPM",$01,$50,$00
        db "BEE",$01,$00,$00
        db "PCG",$00,$75,$00
        db "BOZ",$00,$50,$00
        db "MOE",$00,$25,$00

; append "NAM 012345" for entry HL to DE
hs_fmt:
        ld b,3
.n:     ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .n
        ld a,' '
        ld (de),a
        inc de
        ld b,3
.s:     ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        ld (de),a
        inc de
        ld a,(hl)
        and 15
        add a,'0'
        ld (de),a
        inc de
        inc hl
        djnz .s
        xor a
        ld (de),a
        ret

