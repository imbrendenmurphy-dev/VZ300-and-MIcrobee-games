; =====================================================================
;  THE FRONT END - RAM block 22, mapped at 0000-7FFF when it runs.
;  The music player and its songs, the attract sequence (title,
;  information pages, region cards) and the demonstration scripts live
;  here, out of the way of the game's 11K in upper memory. It calls up
;  into the engine for text and keys; the engine calls down through the
;  jump table.
; =====================================================================
        ORG $0100
        jp f_attract            ; A: b7 = from the top -> A = 0 play, else demo of region A-1 (HL = its script)
        jp f_jingle             ; A = jingle -> Z: it ended, NZ: a key (A = pad bits)
        jp f_end                ; A = 1 region clear, 2 game over -> A = 0 next region, 1 again, 2 title

; =====================================================================
;  MUSIC: three pulse voices and a drum voice on one speaker bit.
;  Each voice is a 16-bit phase accumulator; the speaker is high while
;  any voice's phase is under its pulse width, so narrow pulses mix like
;  a sum and wide ones growl over each other. A sample is 205 T (16.5
;  kHz). Fifty times a second (on the vertical blanking) the tick steps
;  the note streams, the pulse-width envelopes, slides and arpeggios.
;  The drum voice takes over voice 3 while it sounds.
;
;  stream bytes
;    $00          rest (for the current length)
;    $01-$5F      note (1 = C1)
;    $60-$7F      length = b-$5F ticks
;    $80-$8F      instrument
;    $91 n        length n
;    $93 n        transpose by n semitones
;    $F0 lo hi    call a pattern      $F1  return
;    $FE lo hi    jump                $FF  stop
; =====================================================================
CH_PTR      EQU 0
CH_WAIT     EQU 2
CH_LEN      EQU 3
CH_STEP     EQU 4
CH_DUTY     EQU 6
CH_DECAY    EQU 7
CH_DMIN     EQU 8
CH_DSTART   EQU 9
CH_RET      EQU 10
CH_FLAGS    EQU 12          ; b0 noise, b7 resting
CH_SLIDE    EQU 13
CH_ARP      EQU 15
CH_NOTE     EQU 16
CH_TRANS    EQU 17
CH_ACNT     EQU 18
CH_SIZE     EQU 20

; HL = song (four stream pointers: bass, lead, third voice, drums)
m_play: ld ix,m_ch1
        ld b,4
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ix+CH_PTR),e
        ld (ix+CH_PTR+1),d
        ld (ix+CH_WAIT),1
        ld (ix+CH_LEN),6
        xor a
        ld (ix+CH_DUTY),a
        ld (ix+CH_SLIDE),a
        ld (ix+CH_SLIDE+1),a
        ld (ix+CH_FLAGS),a
        ld (ix+CH_ARP),a
        ld (ix+CH_TRANS),a
        ld de,CH_SIZE
        add ix,de
        djnz .l
        ret

; one field: the tick, then samples until the next vertical blanking begins
m_frame:
        call m_tick
        ld hl,(m_ph2)
        exx
        ld hl,(m_ph1)
        ld ix,(m_ph3)
        in a,(P_CRTCA)
        and $20
        jr z,.low               ; the caller's work ran past the blanking
        ld a,$C2                ; JP NZ: while it blanks
        ld (ml_cond),a
        ld (ml_cond2),a
        call mloop
.low:   ld a,$CA                ; JP Z: while it displays
        ld (ml_cond),a
        ld (ml_cond2),a
        call mloop
        ld (m_ph1),hl
        exx
        ld (m_ph2),hl
        exx
        ld (m_ph3),ix
        xor a
        out (P_PIOB),a
        ret

mloop:
ml_s1:  ld bc,0                 ; 10
        add hl,bc               ; 11
        ld a,h                  ; 4
ml_d1:  cp 0                    ; 7
        sbc a,a                 ; 4
        ld e,a                  ; 4
        exx                     ; 4
ml_s2:  ld bc,0                 ; 10
        add hl,bc               ; 11
        ld a,h                  ; 4
ml_d2:  cp 0                    ; 7
        exx                     ; 4
        sbc a,a                 ; 4
        or e                    ; 4
        ld e,a                  ; 4
ml_j3:  jp ml_tone              ; 10
ml_tone:
ml_s3:  ld bc,0                 ; 10
        add ix,bc               ; 15
        ld a,r                  ; 9: the noise path's length
        ld a,ixh                ; 8
ml_d3:  cp 0                    ; 7
        sbc a,a                 ; 4
        or e                    ; 4
        and $40                 ; 7
        out (P_PIOB),a          ; 11
        in a,(P_CRTCA)          ; 11
        and $20                 ; 7
ml_cond: jp z,mloop             ; 10 = 205 T
        ret
ml_noise:                       ; a 16-bit shift register; the width sets how dense
        add ix,ix               ; 15
        sbc a,a                 ; 4
        and $2D                 ; 7
        xor ixl                 ; 8
        ld ixl,a                ; 8
ml_d3n: cp 0                    ; 7
        sbc a,a                 ; 4
        or e
        and $40
        out (P_PIOB),a
        in a,(P_CRTCA)
        and $20
ml_cond2: jp z,mloop
        ret

m_tick: ld ix,m_ch1
        call ch_tick
        ld ix,m_ch2
        call ch_tick
        ld ix,m_ch3
        call ch_tick
        ld ix,m_chd
        call ch_tick
        ld hl,(m_ch1+CH_STEP)
        ld (ml_s1+1),hl
        ld a,(m_ch1+CH_DUTY)
        ld (ml_d1+1),a
        ld hl,(m_ch2+CH_STEP)
        ld (ml_s2+1),hl
        ld a,(m_ch2+CH_DUTY)
        ld (ml_d2+1),a
        ld a,(ix+CH_DUTY)       ; the drums, while they sound
        or a
        jr nz,.d
        ld ix,m_ch3
        ld a,(ix+CH_DUTY)
.d:     ld (ml_d3+1),a
        ld (ml_d3n+1),a
        ld l,(ix+CH_STEP)
        ld h,(ix+CH_STEP+1)
        ld (ml_s3+1),hl
        ld hl,ml_tone
        bit 0,(ix+CH_FLAGS)
        jr z,.t
        ld hl,m_ph3
        set 0,(hl)              ; the shift register must not be empty
        ld hl,ml_noise
.t:     ld (ml_j3+1),hl
        ret

; IX = voice
ch_tick:
        ld a,(ix+CH_PTR+1)
        or a
        jr nz,.act
        ld (ix+CH_DUTY),a
        ret
.act:   bit 7,(ix+CH_FLAGS)
        jr nz,.wait
        ld a,(ix+CH_DUTY)       ; the pulse narrows from its start to its floor
        sub (ix+CH_DECAY)
        jr c,.dmin
        cp (ix+CH_DMIN)
        jr nc,.dok
.dmin:  ld a,(ix+CH_DMIN)
.dok:   ld (ix+CH_DUTY),a
        ld e,(ix+CH_SLIDE)
        ld d,(ix+CH_SLIDE+1)
        ld a,d
        or e
        jr z,.arp
        ld l,(ix+CH_STEP)
        ld h,(ix+CH_STEP+1)
        add hl,de
        ld (ix+CH_STEP),l
        ld (ix+CH_STEP+1),h
        jr .wait
.arp:   ld a,(ix+CH_ARP)
        or a
        jr z,.wait
        dec a
        add a,a
        add a,a
        ld e,a
        ld a,(ix+CH_ACNT)
        inc a
        ld (ix+CH_ACNT),a
        and 3
        add a,e
        ld e,a
        ld d,0
        ld hl,arps
        add hl,de
        ld a,(ix+CH_NOTE)
        add a,(hl)
        call set_step
.wait:  dec (ix+CH_WAIT)
        ret nz
        ld l,(ix+CH_PTR)
        ld h,(ix+CH_PTR+1)
.next:  ld a,(hl)
        inc hl
        cp $60
        jp c,.note
        cp $80
        jr c,.len
        cp $90
        jr c,.inst
        cp $91
        jr z,.llen
        cp $93
        jr z,.trans
        cp $F0
        jr z,.call
        cp $F1
        jr z,.ret
        cp $FE
        jr z,.jump
        xor a                   ; stop
        ld (ix+CH_PTR+1),a
        ld (ix+CH_DUTY),a
        ret
.len:   sub $5F
        ld (ix+CH_LEN),a
        jr .next
.llen:  ld a,(hl)
        inc hl
        ld (ix+CH_LEN),a
        jr .next
.trans: ld a,(hl)
        inc hl
        ld (ix+CH_TRANS),a
        jr .next
.inst:  and $0F
        push hl
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,instruments
        add hl,de
        ld a,(hl)
        ld (ix+CH_DSTART),a
        inc hl
        ld a,(hl)
        ld (ix+CH_DECAY),a
        inc hl
        ld a,(hl)
        ld (ix+CH_DMIN),a
        inc hl
        ld a,(hl)
        ld (ix+CH_FLAGS),a
        inc hl
        ld a,(hl)
        ld (ix+CH_SLIDE),a
        inc hl
        ld a,(hl)
        ld (ix+CH_SLIDE+1),a
        inc hl
        ld a,(hl)
        ld (ix+CH_ARP),a
        pop hl
        jr .next
.call:  ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ix+CH_RET),l
        ld (ix+CH_RET+1),h
        ex de,hl
        jr .next
.ret:   ld l,(ix+CH_RET)
        ld h,(ix+CH_RET+1)
        jp .next
.jump:  ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jp .next
.note:  ld (ix+CH_PTR),l
        ld (ix+CH_PTR+1),h
        ld b,a
        ld a,(ix+CH_LEN)
        ld (ix+CH_WAIT),a
        ld a,b
        or a
        jr z,.rest
        add a,(ix+CH_TRANS)
        ld (ix+CH_NOTE),a
        call set_step
        ld a,(ix+CH_DSTART)
        ld (ix+CH_DUTY),a
        ld (ix+CH_ACNT),0
        res 7,(ix+CH_FLAGS)
        ret
.rest:  ld (ix+CH_DUTY),a
        set 7,(ix+CH_FLAGS)
        ret

; A = note -> the voice's step
set_step:
        add a,a
        ld e,a
        ld d,0
        ld hl,note_steps-2
        add hl,de
        ld a,(hl)
        ld (ix+CH_STEP),a
        inc hl
        ld a,(hl)
        ld (ix+CH_STEP+1),a
        ret

; ---------------------------------------------------------------------
;  A = jingle: play it to its end, or until SPACE / fire / ESC
; ---------------------------------------------------------------------
f_jingle:
        add a,a
        ld e,a
        ld d,0
        ld hl,jingles
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call m_play
        xor a
        ld (fa_tune),a          ; the title tune starts over after this
.l:     call m_frame
        call read_menu
        ld a,(padnew)
        and $90
        ret nz
        ld a,(m_ch1+CH_PTR+1)
        or a
        jr nz,.l
        ret

; ---------------------------------------------------------------------
;  The end of a region, of a game, or of the whole thing.
;  A = 1 region clear, 2 game over -> A = 0 next region, 1 again, 2 title
; ---------------------------------------------------------------------
f_end:  push af
        call display_off
        ld a,$0F
        call cls
        xor a
        ld (fa_tune),a          ; the title tune starts over after this
        pop af
        dec a
        jp nz,.over
        ld a,(region)
        inc a
        cp NREGIONS
        jp nc,ending
        call sv_progress
        ld (fe_saved),a
        ld a,(region)
        call reg_name_a
        ld d,3
        ld c,YELLOW
        call print_centred
        ld hl,t_isclear
        ld d,5
        ld c,YELLOW
        call print_centred
        ld de,$090A
        call tally
        ld hl,t_next
        ld d,14
        ld c,WHITE
        call print_centred
        ld a,(region)
        inc a
        call reg_name_a
        ld d,16
        ld c,BCYAN
        call print_centred
        ld a,(fe_saved)
        or a
        jr nz,.ns
        ld hl,t_kept
        ld d,19
        ld c,GREY
        call print_centred
.ns:    ld hl,t_again
        ld d,22
        ld c,BGREEN
        call print_centred
        call display_on
        xor a
        call f_jingle
        call z,wait_key
        xor a
        ret
.over:  ld hl,pg_over
        call page
        ld a,1
        call f_jingle
        call z,wait_choice
        and $80
        ld a,1
        ret z
        inc a
        ret

; "BUGS FOUND nn OF nn" at DE, for the regions so far
tally:  push de
        ld hl,t_found
        ld c,WHITE
        call print
        pop de
        push de
        ld a,e
        add a,11
        ld e,a
        ld a,(bugs)
        ld c,YELLOW
        call print_num
        ld a,(region)
        ld hl,reg_total
        call index_hl
        pop de
        ld b,a
        ld a,e
        add a,17
        ld e,a
        ld a,b
        ld c,YELLOW
        jp print_num

; King Bufo is beaten: the story's end, the count, the credits
ending: xor a
        call sv_progress
        ld hl,song_end
        call m_play
        ld hl,pg_end1
        call page
        ld bc,150
        call fa_hold
        ld bc,1500
        call fa_wait
        ld hl,pg_end2
        call page
        ld de,$0B0A
        call tally
        ld a,(bugs)
        cp TOTAL_BUGS
        jr c,.some
        ld hl,t_every
        ld d,14
        ld c,BGREEN
        call print_centred
.some:  ld bc,150
        call fa_hold
        ld bc,3000
        call fa_wait
        ld a,2
        ret
; BC fields of music with the keys ignored (so a held button does not skip a page)
fa_hold:
.l:     push bc
        call m_frame
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret

t_isclear: db "IS CLEAR!",0
t_found:  db "BUGS FOUND    OF",0
t_next:   db "NEXT STOP",0
t_again:  db "PRESS SPACE",0
t_every:  db "EVERY LAST ONE. LEGEND.",0
t_kept:   db "YOUR PLACE IS KEPT ON THE DISK",0

; =====================================================================
;  THE ATTRACT SEQUENCE: the title, then a page of information, then a
;  region's card and the game playing that region by itself; round and
;  round, one region after another. The theme plays through the pages
;  and picks up where it left off after each demonstration.
; =====================================================================
ST_TITLE    EQU 0
ST_PAGE     EQU 1
ST_DEMO     EQU 2

f_attract:
        rla
        jr nc,.keep
        xor a
        ld (fa_stage),a
        ld (fa_tune),a
.keep:  ld a,(fa_tune)
        or a
        jr nz,.stage
        inc a
        ld (fa_tune),a
        ld hl,song_title
        call m_play
.stage: ld a,(fa_stage)
        add a,a
        ld e,a
        ld d,0
        ld hl,stages
        add hl,de
        ld a,(hl)
        inc hl
        ld c,(hl)               ; its argument
        cp $FF
        jr nz,.go
        xor a
        ld (fa_stage),a
        jr .stage
.go:    ld hl,fa_stage
        inc (hl)
        or a
        jr z,.title
        dec a
        jp z,.page
        ; a region's card, then out to the demonstration
        ld a,c
        ld (fa_region),a
        ld hl,pg_card
        call page
        ld bc,260
        call fa_wait
        jp nz,.key
        ld a,(fa_region)
        add a,a
        ld e,a
        ld d,0
        ld hl,demos
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(fa_region)
        inc a
        ret
.title: call sv_load            ; (the first time: what the disk remembers)
        call far_title
        xor a
        ld (fa_count),a
        ld hl,title_hook
        ld (fa_hook+1),hl
        call display_on
        ld a,(sv_region)        ; K for the keys; C if there is a game to carry on with
        or a
        ld a,$B0
        jr z,.m
        ld a,$F0
.m:     ld (fa_mask),a
        ld bc,900
        call fa_wait
        push af
        ld a,$90
        ld (fa_mask),a
        pop af
        jp z,.stage
        bit 5,a
        jr nz,.keys
        bit 6,a
        jr z,.key
        ; carry on: the region reached, and the bugs found on the way
        ld a,(sv_region)
        ld (region),a
        ld a,(sv_bugs)
        ld (bugs),a
        ld hl,sv_coll
        ld de,collected
        ld bc,24
        ldir
        ld a,$FF
        ret
.keys:  call keys_page
        xor a
        ld (fa_stage),a
        jp .stage
.page:  ld a,c
        add a,a
        ld e,a
        ld d,0
        ld hl,pages
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call page
        ld bc,650
        call fa_wait
        jp z,.stage
.key:   rla                     ; ESC: back to the title; SPACE: play
        jr nc,.play
        xor a
        ld (fa_stage),a
        jp .stage
.play:  xor a
        ret

; BC = fields to wait, the music playing -> Z: time up; NZ: A = the key
fa_wait:
fa_wl:     push bc
        call m_frame
fa_hook: call hook_none
        call read_menu
        pop bc
        ld a,(padnew)
        ld hl,fa_mask
        and (hl)
        jr nz,fa_wo
        dec bc
        ld a,b
        or c
        jr nz,fa_wl
fa_wo:   ld hl,hook_none
        ld (fa_hook+1),hl
        or a
        ret

; the line under the title picture changes every second and a bit
title_hook:
        ld hl,fa_count
        ld a,(hl)
        inc (hl)
        and $3F
        ret nz
        ld a,(hl)
        rlca
        rlca
        and 3
        ld e,a
        cp 1
        jr nz,.t
        ld a,(sv_region)        ; "C - CONTINUE" only when there is something to continue
        or a
        jr nz,.t
        ld e,0
.t:     ld d,0
        ld hl,t_lines
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,$160A
        ld c,WHITE
        jp print

t_lines:  dw t_press,t_cont,t_keys,t_credit
t_press:  db "PRESS SPACE TO PLAY",0
t_cont:   db "  C TO CARRY ON    ",0
t_keys:   db "K TO CHOOSE KEYS   ",0

; ---------------------------------------------------------------------
;  choosing the keys: five presses, kept on the disk
; ---------------------------------------------------------------------
keys_page:
        ld hl,pg_keys
        call page
        xor a
        ld (kp_i),a
.next:  ld a,'?'
        ld c,YELLOW
        call kp_put
.up:    call m_frame            ; every key up, then one down
        call kp_scan
        jr c,.up
.dn:    call m_frame
        call kp_scan
        jr nc,.dn
        cp K_SPACE
        jr z,.ok
        or a
        jr z,.dn
        cp $30                  ; letters, digits and punctuation
        jr nc,.dn
.ok:    ld b,a
        ld a,(kp_i)
        ld e,a
        ld d,0
        ld hl,sv_keys
        add hl,de
        ld (hl),b
        ld a,b
        call kp_name
        ld hl,kp_i
        inc (hl)
        ld a,(hl)
        cp 5
        jr c,.next
        call keys_apply
        call sv_save
        ld hl,t_saved
        or a
        jr z,.s
        ld hl,t_nosave
.s:     ld d,21
        ld c,BGREEN
        call print_centred
        ld bc,120
        jp fa_hold

; C = colour, A = a character: at this key's place
kp_put: push af
        ld a,(kp_i)
        ld b,a
        add a,a
        add a,b
        add a,5
        ld d,a
        ld e,24
        pop af
        jp putch
; A = key code: its name
kp_name:
        ld c,WHITE
        cp K_SPACE
        jr nz,.ch
        ld a,(kp_i)
        ld b,a
        add a,a
        add a,b
        add a,5
        ld d,a
        ld e,24
        ld hl,t_space
        jp print
.ch:    cp $20
        jr nc,.dig
        add a,'@'
        jr kp_put
.dig:   sub $20
        ld e,a
        ld d,0
        ld hl,t_digits
        add hl,de
        ld a,(hl)
        jr kp_put
t_digits: db "0123456789:;,-./"
t_space:  db "SPACE",0
t_saved:  db "KEPT ON THE DISK",0
t_nosave: db "(NOT KEPT: NO DISK TO WRITE)",0
; any key down? C set: A = its code
kp_scan:
        ld a,1
        out (P_ROMLAT),a
        ld c,0
.l:     ld a,c
        call keytest
        jr nz,.hit
        inc c
        ld a,c
        cp 64
        jr c,.l
        xor a
        out (P_ROMLAT),a
        ret
.hit:   xor a
        out (P_ROMLAT),a
        ld a,c
        scf
        ret
; the chosen keys into the game's key table
keys_apply:
        ld hl,sv_keys
        ld de,key_slots
        ld b,5
.l:     ld a,(de)
        inc de
        push de
        ld e,a
        ld d,0
        ld a,(hl)
        inc hl
        push hl
        ld hl,keymap
        add hl,de
        ld (hl),a
        pop hl
        pop de
        djnz .l
        ret
key_slots: db 12,10,14,16,6     ; left, right, frill, down, jump: their codes in keymap

; ---------------------------------------------------------------------
;  SAVE.DAT on the game's own disk: the region reached, the bugs found,
;  the keys. Read at the first title; written when a region is cleared
;  and when keys are chosen. The directory is checked before every
;  write, every wait is bounded, and no disk just means nothing is kept.
; ---------------------------------------------------------------------
SVBUF   EQU $7C00
SV_LEN  EQU sv_rec_end-sv_rec
        INCLUDE "fdisk.inc"
sv_sig: db "FRILLSEEKER1"
sv_sum: ld hl,SVBUF+12
        ld b,SV_LEN
        xor a
.b:     add a,(hl)
        rlca
        inc hl
        djnz .b
        ret
sv_load:
        ld hl,sv_done
        ld a,(hl)
        or a
        ret nz
        inc (hl)
        call sv_dir
        ret nz
        ld a,SV_DATSEC
        ld (sv_sec),a
        call sv_read
        ret nz
        ld hl,SVBUF
        ld de,sv_sig
        ld b,12
.s:     ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .s
        call sv_sum
        ld hl,SVBUF+12+SV_LEN
        cp (hl)
        ret nz
        ld a,(SVBUF+12)
        cp NREGIONS
        ret nc
        ld hl,SVBUF+12+SV_LEN-5 ; five sensible keys, or none of it
        ld b,5
.k:     ld a,(hl)
        cp 64
        ret nc
        inc hl
        djnz .k
        ld hl,SVBUF+12
        ld de,sv_rec
        ld bc,SV_LEN
        ldir
        jp keys_apply
; -> A = 0 written and read back, else not
sv_save:
        call sv_dir
        jr nz,.bad
        ld hl,SVBUF
        ld b,0
.c:     ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        djnz .c
        ld hl,sv_sig
        ld de,SVBUF
        ld bc,12
        ldir
        ld hl,sv_rec
        ld bc,SV_LEN
        ldir
        call sv_sum
        ld (SVBUF+12+SV_LEN),a
        ld a,SV_DATSEC
        ld (sv_sec),a
        call sv_write
        jr nz,.bad
        call sv_read
        jr nz,.bad
        call sv_sum
        ld hl,SVBUF+12+SV_LEN
        cp (hl)
        jr nz,.bad
        xor a
        ret
.bad:   ld a,1
        ret
; the game so far into the record, and on to the disk. A = the region to carry on from
sv_progress:
        ld (sv_region),a
        ld a,(bugs)
        ld (sv_bugs),a
        ld hl,collected
        ld de,sv_coll
        ld bc,24
        ldir
        or a
        jr nz,sv_save
        ld (sv_bugs),a          ; (the whole game done: a clean sheet)
        ld hl,sv_coll
        ld b,24
.z:     ld (hl),a
        inc hl
        djnz .z
        jr sv_save

; ---------------------------------------------------------------------
;  a page: text and pictures on black. HL = its items:
;    1, row, column ($FF = centred), colour, text, 0
;    2, picture, row, column
;    3, row, colour             the region's name, centred
;    4, row, colour             the region's line, centred
;    0                          the end
; ---------------------------------------------------------------------
page:   push hl
        call display_off
        ld a,$0F
        call cls
        ld hl,0
        ld (pg_glyph),hl
        pop hl
.item:  ld a,(hl)
        inc hl
        or a
        jr z,.done
        dec a
        jr z,.text
        dec a
        jr z,.pic
        dec a
        jr z,.name
        ; the region's line
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        ld a,(fa_region)
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,reg_lines
        add hl,de
        pop de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call print_centred
        pop hl
        jr .item
.name:  ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        push de
        push bc
        ld a,(fa_region)
        call reg_name_a
        pop bc
        pop de
        call print_centred
        pop hl
        jr .item
.text:  ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,e
        inc a
        jr nz,.at
        push hl
        call print_centred
        pop hl
        jr .skip
.at:    push hl
        call print
        pop hl
.skip:  ld a,(hl)
        inc hl
        or a
        jr nz,.skip
        jr .item
.pic:   ld a,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        push hl
        call picture
        pop hl
        jp .item
.done:  jp display_on

; A = picture, D = row, E = column. A picture is w, h, then w*h glyphs
; for colour, w*h for a monochrome monitor, then w*h colours. Its
; glyphs go into the PCG after the page's last picture's.
picture:
        add a,a
        ld l,a
        ld h,0
        ld bc,pictures
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(hl)
        ld (pc_w),a
        inc hl
        ld b,(hl)               ; rows
        inc hl
        ld (pc_pat),hl
        ; its size in cells -> HL' = colours
        push de
        push bc
        ld e,a
        ld d,0
        ld hl,0
.m:     add hl,de
        djnz .m
        ld (pc_n),hl
        add hl,hl
        add hl,hl
        add hl,hl               ; bytes of glyphs in one set
        ex de,hl
        ld hl,(pc_pat)
        add hl,de
        ld a,(mono)
        or a
        jr z,.col
        ld (pc_pat),hl
.col:   add hl,de
        ld (pc_col),hl
        pop bc
        pop de
        ; the first cell's address
        push bc
        ld a,d
        call row_addr
        ld a,h
        add a,(VIDEO >> 8) - (CELLMAP >> 8)
        ld h,a
        ld d,0
        add hl,de
        ld (pc_cell),hl
        pop bc
.row:   push bc
        ld a,(pc_w)
        ld b,a
        ld hl,(pc_cell)
.cell:  push bc
        push hl
        ; the glyph into the PCG
        ld de,(pg_glyph)
        ld a,e
        add a,a
        ld a,d
        rla                     ; the bank
        ld (pc_bank),a
        or LV_SCREEN
        ld c,a
        xor a
        out (P_COLCTL),a
        ld a,c
        out (P_LV),a
        ld a,e
        and $7F
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,PCGWIN
        add hl,bc
        ex de,hl
        ld hl,(pc_pat)
        ld bc,8
        ldir
        ld (pc_pat),hl
        pop hl
        ; the cell
        call win_screen
        ld a,(pg_glyph)
        or $80
        ld (hl),a
        call win_attr
        ld a,(pc_bank)
        ld (hl),a
        call win_col
        ld de,(pc_col)
        ld a,(mono)
        or a
        ld a,(de)
        jr z,.cc
        ld a,$0F
.cc:    set 3,h
        ld (hl),a
        res 3,h
        inc de
        ld (pc_col),de
        ld de,(pg_glyph)
        inc de
        ld (pg_glyph),de
        inc hl
        pop bc
        djnz .cell
        ld hl,(pc_cell)
        ld de,COLS
        add hl,de
        ld (pc_cell),hl
        pop bc
        djnz .row
        jp win_screen

        INCLUDE "pages.inc"
        INCLUDE "songs.inc"
        INCLUDE "demos.inc"

; ---- the front end's own variables (this block is RAM)
fa_mask:    db $90
fe_saved:   db 0
kp_i:       db 0
sv_done:    db 0
sv_sec:     db 0
sv_st:      db 0
; the record kept on the disk
sv_rec:
sv_region:  db 0
sv_bugs:    db 0
sv_coll:    ds 24
sv_keys:    db K_O,K_P,K_Q,K_A,K_SPACE
sv_rec_end:
fa_stage:   db 0
fa_tune:    db 0
fa_region:  db 0
fa_count:   db 0
pg_glyph:   dw 0
pc_w:       db 0
pc_bank:    db 0
pc_n:       dw 0
pc_pat:     dw 0
pc_col:     dw 0
pc_cell:    dw 0
m_ph1:      dw 0
m_ph2:      dw 0
m_ph3:      dw 0
m_ch1:      ds CH_SIZE
m_ch2:      ds CH_SIZE
m_ch3:      ds CH_SIZE
m_chd:      ds CH_SIZE
front_end:
        ASSERT front_end <= SVBUF
