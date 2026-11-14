; =====================================================================
;  FRONT END: the monitor question, the title, the attract sequence
;  (hall of fame, how to play, a demo), initials, and the play loop
;  with pause, sound and restart.
; =====================================================================

; ---------------------------------------------------------------------
; first: what kind of monitor?
; ---------------------------------------------------------------------
monitor_ask:
        call screen_reset
        ld hl,8*40+11
        ld de,t_spindrift
        ld c,YELLOW
        call print_s
        ld hl,12*40+5
        ld de,t_mon1
        ld c,WHITE
        call print_s
        ld hl,14*40+5
        ld de,t_mon2
        ld c,WHITE
        call print_s
        ld hl,20*40+11
        ld de,t_vibed
        ld c,BCYAN
        call print_s
        call display_on
.w:     call read_input
        call input_used
        ld a,(keys)
        bit 3,a
        jr nz,.c
        bit 4,a
        jr nz,.m
        call snd_field
        jr .w
.c:     xor a
        jr .s
.m:     ld a,1
.s:     ld (mono),a
        call set_colour_mode
        ld a,2
        ld (sndmode),a
        ret

; ---------------------------------------------------------------------
; the attract sequence: title, then by turns the hall of fame, how to
; play, and a demo. Returns when a game is to start.
; ---------------------------------------------------------------------
attract:
.loop:  call title
        ret z                   ; start pressed
        ld a,(att_step)
        inc a
        cp 3
        jr c,.s
        xor a
.s:     ld (att_step),a
        or a
        jr nz,.h
        call scores_screen
        ret z
        jr .loop
.h:     dec a
        jr nz,.d
        ld a,2
        ld (demo),a
        call play_game
        ld a,(demo_quit)
        or a
        ret z                   ; fire was pressed in the demo: play
        jr .loop
.d:     ld a,1
        ld (demo),a
        call play_game
        ld a,(demo_quit)
        or a
        ret z
        jr .loop

; the title. Z = start a game, NZ = time for the next attract screen
title:
        call screen_reset
        call stars_init
        xor a
        ld (demo),a
        ld (warp),a
        ld a,BLUE
        ld (star_far),a
        ; the logo: its glyphs into bank 2, its cells on rows 2-6
        ld a,MP_PIC
        out (P_MEM),a
        ld hl,0
        ld a,BK_PIC
        ld bc,LOGO_NG
        call pcg_load10
        ld ix,LOGO_MAP
        ld hl,2*40+(40-LOGO_W)/2
        ld de,logo_cols
        ld b,LOGO_H
.r:     push bc
        push hl
        ld a,(de)
        ld c,a
        ld b,LOGO_W
.c:     push bc
        ld a,(ix+0)
        inc ix
        or a
        jr z,.e
        add a,$80
        ld b,BK_PIC
        call put_s
.e:     inc hl
        pop bc
        djnz .c
        pop hl
        ld bc,40
        add hl,bc
        inc de
        pop bc
        djnz .r
        ld hl,8*40+10
        ld de,t_tag
        ld c,BCYAN
        call print_s
        ; the best score
        ld hl,hiscore
        ld de,txtbuf
        call bcd_text
        ld hl,19*40+9
        ld de,t_best
        ld c,GREY
        call print_s
        ld hl,19*40+20
        ld de,txtbuf
        ld c,YELLOW
        call print_s
        ld hl,19*40+28
        ld de,hitab
        ld c,WHITE
        call print3_s
        ld hl,21*40+11
        ld de,t_vibed
        ld c,BCYAN
        call print_s
        ld hl,23*40
        ld de,t_keys
        ld c,DGREY
        call print_s
        ld hl,16*40+6
        ld de,t_press
        ld c,WHITE
        call print_s
        call tstars_init
        call display_on
        ; the title runs on SWIRL's ticks (src/titlemus.asm)
        call snd_off
        ld hl,TITLE_TICKS
        ld (scr_tim),hl
        xor a
        ld hl,16*40+PROMPT_C0
        call tm_setup
        ld de,title_hook
        call mus_run            ; A: 1 start, 2 time up, 3 colour, 4 mono
        cp 2
        jr z,.next
        jr nc,.mon
        call input_used
        xor a
        ret
.next:  or 1
        ret
.mon:   sub 3
        ld (mono),a
        call set_colour_mode
        call shape_ask          ; a new monitor may want a new shape
        jp title

; shots on the title: just fly (no enemies)
shots_title:
        ld ix,SHOTS
        ld b,NSHOT
.l:     push bc
        ld a,(ix+S_ST)
        or a
        jr z,.n
        ld a,(ix+S_R)
        sub 10
        jr c,.k
        cp 14
        jr c,.k
        ld (ix+S_R),a
        ld b,a
        ld a,(ix+S_A)
        call polar
        ld (ix+S_XL),l
        ld (ix+S_XH),h
        ld (ix+S_Y),c
        jr .n
.k:     ld (ix+S_ST),0
.n:     ld de,8
        add ix,de
        pop bc
        djnz .l
        ret

; S switches the sound (music + effects, effects, none)
front_keys:
        ld a,(keysnew)
        bit 2,a
        ret z
        ld a,(sndmode)
        dec a
        jp p,.s
        ld a,2
.s:     ld (sndmode),a
        cp 2
        ret nc
        xor a
        ld (mus_on),a
        ret

logo_cols:
        db YELLOW,YELLOW,BRED,RED,MAGENTA

; HL = cell, DE = three letters, C = colour (static)
print3_s:
        ld b,3
.l:     ld a,(de)
        inc de
        sub 32
        add a,$80
        push bc
        ld b,BK_FONT
        call put_s
        pop bc
        inc hl
        djnz .l
        ret

; ---------------------------------------------------------------------
; the hall of fame. Z = start a game
; ---------------------------------------------------------------------
scores_screen:
        call screen_reset
        call stars_init
        ld hl,2*40+12
        ld de,t_fame
        ld c,YELLOW
        call print_s
        ld ix,hitab
        ld hl,5*40+10
        ld b,0
.l:     push bc
        push hl
        ld a,b
        add a,'1'
        ld (txtbuf),a
        ld a,'.'
        ld (txtbuf+1),a
        xor a
        ld (txtbuf+2),a
        ld a,b
        or a
        ld a,YELLOW
        jr z,.c1
        ld a,WHITE
.c1:    ld (tmp1),a
        ld c,a
        ld de,txtbuf
        call print_s
        pop hl
        push hl
        ld de,4
        add hl,de
        push ix
        pop de
        ld a,(tmp1)
        ld c,a
        call print3_s
        push ix
        pop hl
        inc hl
        inc hl
        inc hl
        ld de,txtbuf
        call bcd_text
        pop hl
        push hl
        ld de,10
        add hl,de
        ld de,txtbuf
        ld a,(tmp1)
        ld c,a
        call print_s
        ld de,6
        add ix,de
        pop hl
        ld de,80
        add hl,de
        pop bc
        inc b
        ld a,b
        cp 8
        jr c,.l
        ld hl,23*40+6
        ld de,t_press
        ld c,BCYAN
        call print_s
        call tstars_init
        call display_on
        ; the hall of fame carries the title's music on (SWIRL)
        call snd_off
        ld hl,7*59
        ld (scr_tim),hl
        ld a,1
        ld hl,23*40+6
        call tm_setup
        ld de,title_hook
        call mus_run            ; A: 1 start, 2 time up
        cp 1
        jr z,.go
        or 1
        ret
.go:    call input_used
        xor a
        ret

; ---------------------------------------------------------------------
; the play loop (demo = 0 a game, 1 the demo, 2 how to play)
; ---------------------------------------------------------------------
play_game:
        call snd_off
        xor a
        ld (paused),a
        ld (demo_quit),a
        ld (cap_len),a
        ld (ai_t),a
        ld a,(demo)
        cp 2
        ld a,0
        jr nz,.q
        inc a
.q:     ld (demo_quiet),a
        ld hl,25*24
        ld (demo_tim),hl
        ld hl,$FFFF
        ld (cap_ptr),hl
        call new_game
.loop:  call read_input
        ld a,(demo)
        or a
        jr z,.player
        ; a demo: any key or fire ends it
        ld a,(padnew)
        and 16
        jr nz,.dq0
        ld a,(keysnew)
        or a
        jr nz,.dq1
        ld hl,(demo_tim)
        dec hl
        ld (demo_tim),hl
        ld a,h
        or l
        jr z,.dq1
        ld a,(phase)
        cp PH_OVER
        jr nc,.dq1
        call demo_input
        jr .run
.dq0:   ; fire: straight into a game
        xor a
        ld (demo_quit),a
        jr .end
.dq1:   ld a,1
        ld (demo_quit),a
        jr .end
.player:
        ld a,(pad)
        ld (ipad),a
        ld a,(padnew)
        ld (ipadnew),a
        ld a,(keysnew)
        bit 0,a
        jr nz,.esc
        bit 5,a
        jr nz,.restart
        bit 1,a
        call nz,toggle_pause
        call front_keys
        ld a,(paused)
        or a
        jr z,.run
        call input_used
        call snd_tick
        call draw_all
        call frame_end
        jr .loop
.run:   call input_used
        call phase_update
        call vbpoll
        call player_update
        call vbpoll
        call shots_update
        call vbpoll
        call enemies_update
        call vbpoll
        call bullets_update
        call vbpoll
        call fx_update
        call stars_update
        call vbpoll
        call hud_update
        call flash_reshow
        call vbpoll
        call snd_tick
        call draw_all
        call frame_end
        ld a,(phase)
        cp PH_DONE
        jp nz,.loop
.end:   call snd_off
        ld a,(demo)
        or a
        ret nz
        call new_best
        jp check_score
.esc:   call snd_off
        call new_best
        jp check_score
.restart:
        call snd_off
        call new_best
        call input_used
        jp play_game

toggle_pause:
        ld a,(paused)
        xor 1
        ld (paused),a
        jr z,.off
        ld de,t_paused
        ld a,2
        ld c,YELLOW
        call msg
        ld a,(sndmode)
        ld (snd_save),a
        xor a
        ld (sndmode),a
        ret
.off:   ld a,2
        call msg_clear
        ld a,(snd_save)
        ld (sndmode),a
        ret

; the best score of the session goes to the HUD's "HI"
new_best:
        ld hl,score+2
        ld de,hiscore+2
        ld b,3
.l:     ld a,(de)
        cp (hl)
        jr c,.new
        ret nz
        dec hl
        dec de
        djnz .l
        ret
.new:   ld hl,score
        ld de,hiscore
        ld bc,3
        ldir
        ret

; ---------------------------------------------------------------------
; the demo's pilot, and the scripted how-to-play
; ---------------------------------------------------------------------
demo_input:
        xor a
        ld (ipadnew),a
        ld a,(demo)
        cp 2
        jr nz,demo_ai
        ; how to play: a script of (until frame / 4, pad, caption)
        ld hl,(demo_tim)
        ld de,25*24
        ex de,hl
        or a
        sbc hl,de
        srl h
        rr l
        srl h
        rr l
        ld de,howto
.f:     ld a,(de)
        or a
        jr z,demo_ai            ; the script is over: fly by itself
        ld c,a
        ld b,0
        push hl
        or a
        sbc hl,bc
        pop hl
        jr c,.this
        inc de
        inc de
        inc de
        inc de
        jr .f
.this:  inc de
        ld a,(de)
        ld (ipad),a
        and 16
        jr z,.nf
        ld a,(frameno)
        and 6
        jr nz,.nf
        ld a,16
        ld (ipadnew),a
.nf:    inc de
        ld a,(de)
        ld l,a
        inc de
        ld a,(de)
        ld h,a
        ld de,(cap_ptr)
        or a
        sbc hl,de
        ret z
        add hl,de
        ld (cap_ptr),hl
        ex de,hl
        jp caption

; the pilot: chase the nearest enemy's angle and fire; dodge near fire
demo_ai:
        xor a
        ld (ipad),a
        ; dodge
        ld ix,BULLETS
        ld b,NBUL
.b:     bit 0,(ix+B_ST)
        jr z,.bn
        ld a,(ix+B_R)
        cp 160
        jr c,.bn
        ld a,(ix+B_A)
        ld c,a
        ld a,(p_a)
        sub c
        ld c,a
        call absa
        cp 12
        jr nc,.bn
        ld a,c
        or a
        ld a,1 << PAD_ACW
        jp p,.bd
        ld a,1 << PAD_CW
.bd:    ld (ipad),a
        ret
.bn:    ld de,BSIZE
        add ix,de
        djnz .b
        ; the enemy nearest the orbit
        ld ix,ENEMY
        ld b,NENEMY
        ld c,0                  ; best depth
        ld e,$FF                ; its angle
.e:     ld a,(ix+E_ST)
        or a
        jr z,.en
        ld a,(ix+E_R)
        cp c
        jr c,.en
        ld c,a
        ld e,(ix+E_A)
.en:    push de
        ld de,ESIZE
        add ix,de
        pop de
        djnz .e
        ld a,(bossmode)
        or a
        jr z,.nb
        ld a,(frameno)
        add a,a
        ld e,a
        ld c,1
.nb:    ld a,c
        or a
        jr z,.fire
        ld a,e
        ld hl,p_a
        sub (hl)
        ld c,a
        call absa
        ld b,a
        cp 6
        jr c,.fire
        ld a,c
        or a
        ld a,1 << PAD_ACW
        jp p,.ad
        ld a,1 << PAD_CW
.ad:    ld (ipad),a
        ld a,b
        cp 24
        ret nc
.fire:  ld a,(ipad)
        or 16
        ld (ipad),a
        ld a,(frameno)
        and 3
        ret nz
        ld a,16
        ld (ipadnew),a
        ret

; DE = caption (row 5, centred); 0 = none
caption:
        push de
        ld a,(cap_len)
        or a
        jr z,.n
        ld b,a
        ld a,40
        sub b
        srl a
        ld l,a
        ld h,0
        ld de,5*40
        add hl,de
        call clear_q
.n:     pop de
        ld a,d
        or e
        jr nz,.t
        ld (cap_len),a
        ret
.t:     ld b,0
        push de
.c:     ld a,(de)
        or a
        jr z,.l
        inc de
        inc b
        jr .c
.l:     pop de
        ld a,b
        ld (cap_len),a
        ld a,40
        sub b
        srl a
        ld l,a
        ld h,0
        ld bc,5*40
        add hl,bc
        ld c,YELLOW
        jp print_q

; ---------------------------------------------------------------------
; a place in the hall of fame?
; ---------------------------------------------------------------------
check_score:
        ; find the first entry the score beats
        ld ix,hitab
        ld b,0
.f:     ld a,(score+2)
        cp (ix+5)
        jr c,.n
        jr nz,.in
        ld a,(score+1)
        cp (ix+4)
        jr c,.n
        jr nz,.in
        ld a,(score)
        cp (ix+3)
        jr c,.n
        jr z,.n
        jr .in
.n:     ld de,6
        add ix,de
        inc b
        ld a,b
        cp 8
        jr c,.f
        ret
.in:    ; make room: entries B..6 move down one
        ld a,7
        sub b
        jr z,.last
        ld c,a
        ld hl,hitab+6*7-1
        ld de,hitab+6*8-1
        ld a,c
        add a,a
        add a,c
        add a,a
        ld c,a
        ld b,0
        lddr
.last:  push ix
        pop hl
        ld (hl),'A'
        inc hl
        ld (hl),'A'
        inc hl
        ld (hl),'A'
        inc hl
        ex de,hl
        ld hl,score
        ld bc,3
        ldir
        push ix
        pop hl
        ld (ent_ptr),hl
        jp enter_name

enter_name:
        call screen_reset
        call stars_init
        ld a,1
        ld (p_state),a
        ld hl,4*40+13
        ld de,t_newhi
        ld c,YELLOW
        call print_s
        ld hl,7*40+9
        ld de,t_initials
        ld c,WHITE
        call print_s
        ld hl,20*40+5
        ld de,t_enter1
        ld c,GREY
        call print_s
        ld hl,22*40+13
        ld de,t_enter2
        ld c,GREY
        call print_s
        call display_on
        ld hl,tune_hi
        call play_tune
        xor a
        ld (ent_i),a
        ld a,1
        ld (ent_dirty),a
        ld hl,25*60
        ld (scr_tim),hl
.loop:  call read_input
        ld a,(ent_dirty)
        or a
        call nz,.show
        ; typed letters
        ld a,1
        out (P_ROMLAT),a
        ld b,1
.k:     ld a,b
        call keytest
        jr nz,.typed
        inc b
        ld a,b
        cp 27
        jr c,.k
        xor a
        out (P_ROMLAT),a
        ld (last_typed),a
        ld a,(padnew)
        ld c,a
        and 1 | (1 << PAD_ACW) | 4
        jr nz,.up
        ld a,c
        and 2 | (1 << PAD_CW) | 8
        jr nz,.dn
        ld a,c
        and 16
        jr nz,.next
.tick:  call input_used
        call stars_update
        call snd_tick
        call draw_all
        call frame_end
        ld hl,(scr_tim)
        dec hl
        ld (scr_tim),hl
        ld a,h
        or l
        jr nz,.loop
        jr .done
.typed: xor a
        out (P_ROMLAT),a
        ld a,(last_typed)
        cp b
        jr z,.tick              ; still held
        ld a,b
        ld (last_typed),a
        add a,'A'-1
        call .set
        jr .next
.up:    call .get
        inc a
        cp 'Z'+1
        jr c,.u
        ld a,'A'
.u:     call .set
        jr .tick
.dn:    call .get
        dec a
        cp 'A'
        jr nc,.d
        ld a,'Z'
.d:     call .set
        jr .tick
.next:  ld hl,sfx_menu
        ld a,1
        call play_sfx
        ld hl,ent_i
        inc (hl)
        ld a,1
        ld (ent_dirty),a
        ld a,(hl)
        cp 3
        jr c,.tick
.done:  call snd_off
        jp scores_screen_once
.get:   ld hl,(ent_ptr)
        ld a,(ent_i)
        add a,l
        ld l,a
        jr nc,.g
        inc h
.g:     ld a,(hl)
        ret
.set:   push af
        call .get
        pop af
        ld (hl),a
        ld a,1
        ld (ent_dirty),a
        ret
.show:  xor a
        ld (ent_dirty),a
        ld b,0
.s:     push bc
        ld a,b
        add a,a
        ld l,a
        ld h,0
        ld de,11*40+17
        add hl,de
        push hl
        ld de,(ent_ptr)
        ld a,b
        add a,e
        ld e,a
        jr nc,.sn
        inc d
.sn:    ld a,(de)
        sub 32
        add a,$80
        ld e,a
        ld c,WHITE
        ld a,(ent_i)
        cp b
        jr nz,.sw
        ld c,YELLOW
.sw:    ld a,e
        ld b,BK_FONT
        call tq_put
        pop hl
        ld de,40
        add hl,de
        pop bc
        push bc
        ld a,(ent_i)
        cp b
        ld a,$80+('^'-32)
        jr z,.cu
        ld a,$80
.cu:    ld b,BK_FONT
        ld c,YELLOW
        call tq_put
        pop bc
        inc b
        ld a,b
        cp 3
        jr c,.s
        ret

; after entering a name: the hall of fame for a while
scores_screen_once:
        call scores_screen
        ret
