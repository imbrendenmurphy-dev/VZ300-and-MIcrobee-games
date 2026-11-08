; =====================================================================
;  COURTS: the five venues, loading a court, player colours, practice
; =====================================================================
V_KOOYONG   equ 0
V_PERTH     equ 1
V_SYDNEY    equ 2
V_MELBOURNE equ 3
V_CLASSIC   equ 4
SURF_CLASSIC equ V_CLASSIC

; per venue: bounce rest, bounce keep, court colour, alternative court colour, dw name
surftab:
        db 140,236, GREEN,BGREEN    : dw sn_kooyong
        db 196,196, BROWN,RED       : dw sn_perth
        db 172,220, CYAN,BCYAN      : dw sn_sydney
        db 160,232, BBLUE,BLUE      : dw sn_melbourne
        db 150,236, GREEN,BGREEN    : dw sn_classic
sn_kooyong:   db "KOOYONG LAWN",0
sn_perth:     db "PERTH RED CLAY",0
sn_sydney:    db "SYDNEY HARBOUR",0
sn_melbourne: db "MELBOURNE PARK",0
sn_classic:   db "CLASSIC 1984",0

; the players' kit colours (character order)
char_ink: db BRED, BMAGENTA, BCYAN, YELLOW, GREY, BROWN, WHITE, YELLOW, WHITE

; set_surface: A = venue
set_surface:
        ld (surface),a
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        add hl,hl               ; *6
        ld de,surftab
        add hl,de
        ld a,(hl)
        ld (s_rest),a
        inc hl
        ld a,(hl)
        ld (s_keep),a
        inc hl
        ld a,(hl)
        ld (s_court),a
        inc hl
        ld a,(hl)
        ld (s_court2),a
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (s_name),hl
        ret

; player colours for this court: each its own, never the court's, never the same
set_inks:
        ld a,(monomode)
        or a
        jr z,.col
        ld a,WHITE
        ld (pl_ink),a
        ld (pl_ink+1),a
        ret
.col:   ld a,(surface)
        cp V_CLASSIC
        jr nz,.n
        ld a,BBLUE              ; the 1984 colours: blue and red
        ld (pl_ink),a
        ld a,BRED
        ld (pl_ink+1),a
        ret
.n:     ld ix,pl0
        call .one
        ld (pl_ink),a
        ld ix,pl1
        call .one
        ld b,a
        ld a,(pl_ink)
        cp b
        ld a,b
        jr nz,.s
        cp WHITE
        ld a,YELLOW
        jr nz,.s
        ld a,WHITE
        cp b
        jr nz,.s
        ld a,YELLOW
.s:     ld (pl_ink+1),a
        ret
.one:   ld a,(ix+P_CHAR)
        ld e,a
        ld d,0
        ld hl,char_ink
        add hl,de
        ld a,(hl)
        ld hl,s_court
        cp (hl)
        jr z,.w
        inc hl
        cp (hl)
        ret nz
.w:     ld a,WHITE
        ret

; ---------------------------------------------------------------------
; court_load: unpack this venue's court (colour or mono), put it on screen,
; set up the crowd and umpire lists, and copy the glyphs the sprites may
; cover into every sprite block.
court_load:
        ld a,(surface)
        add a,a
        ld hl,monomode
        add a,(hl)
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,court_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push af
        push de
        ld a,BLK_UNP
        call map_blk
        pop hl
        pop af
        ld de,0
        call unlzb_x
        ; the picture
        ld hl,0
        ld (lp_first),hl
        ld a,BLK_UNP
        ld hl,0
        call load_picture       ; HL -> after the colour map
        push hl
        ; crowd records + counts -> RT_CROWD
        ld a,BLK_UNP
        call map_blk
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec hl
        ld (crowd_n),de
        ex de,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,bc
        ld bc,2+64
        add hl,bc
        ld b,h
        ld c,l                  ; length
        ex de,hl
        push hl
        add hl,bc
        ex (sp),hl              ; (sp) = umpire lists
        ld a,BLK_RT
        ld (cb_dst),a
        ld de,RT_CROWD
        ld a,BLK_UNP
        call blk_copy
        pop hl
        ld a,BLK_RT
        ld (cb_dst),a
        ld de,RT_UMP
        ld bc,RT_UMP_LEN
        ld a,BLK_UNP
        call blk_copy
        pop hl
        ; nobody standing, the umpire looking ahead
        ld a,BLK_RT
        call map_blk
        ld hl,RT_CSTATE
        ld de,RT_CSTATE+1
        ld bc,RT_CSTATE_LEN-1
        ld (hl),0
        ldir
        xor a
        ld (ump_pose),a
        ld (ump_tim),a
        ld (crowdtim),a
        ; the first STORE_N glyphs into every sprite block
        ld a,BLK_UNP
        call map_blk
        ld hl,(0)
        ld de,STORE_N
        or a
        sbc hl,de
        add hl,de
        jr c,.sn
        ex de,hl
.sn:    add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (cl_len),hl
        ld a,BLK_SPR
.sb:    ld (cb_dst),a
        ld hl,2
        ld de,0
        ld bc,(cl_len)
        push af
        ld a,BLK_UNP
        call blk_copy
        pop af
        inc a
        cp BLK_SPR+NSPRBLK
        jr nz,.sb
        ld a,BLK_RT
        jp map_blk

; court_show: the court on screen with the scoreboard
court_show:
        call set_inks
        call court_load
        call hud_draw
        call frame_begin
        ret

; ---------------------------------------------------------------------
; practice: cones, the ball machine
practice_start:
        xor a
        ld (server),a           ; the machine "serves"
        ld (pr_hits),a
        ld (pr_score),a
        ld (pr_score+1),a
        ld (ball_st),a
        ld a,20
        ld (pr_balls),a
        ld a,50
        ld (feedtim),a
        ld a,1
        ld (pl1+P_HITOK),a
        ld ix,pl1
        ld a,128
        ld c,236
        call place_ix
        ld ix,pl0
        ld a,128
        ld c,14
        call place_ix
        ld a,4
        ld (ball_st),a
        ld b,3
        ld hl,cone_x
.c:     push bc
        push hl
        call cone_new
        pop hl
        pop bc
        inc hl
        djnz .c
        call court_show
        ld hl,s_tp
        ld de,s_tp2
        call banner
        ld b,80
        call hold
        call court_restore
        xor a
        ld (ball_st),a
        ld hl,mus_prac_0
        ld de,mus_prac_1
        call bgm
.loop:  call match_step
        ld a,(match_over)
        or a
        jr z,.loop
        call stop_music
        ld a,1
        ret
s_tp:   db "TARGET PRACTICE",0
s_tp2:  db "20 BALLS. HIT THE CONES!",0

; cone_new: HL -> cone_x[k]; new random position (and cone_y, cone_t)
cone_new:
        push hl
        ld b,150
        call rand_n
        add a,52
        pop hl
        ld (hl),a
        push hl
        ld de,3
        add hl,de
        push hl
        ld b,70
        call rand_n
        add a,38
        pop hl
        ld (hl),a
        add hl,de
        ld (hl),0
        pop hl
        ret

practice_feed:
        ld a,(ball_st)
        or a
        ret nz
        ld a,(pr_balls)
        or a
        ret z
        ld hl,feedtim
        dec (hl)
        ret nz
        ld hl,pr_balls
        dec (hl)
        ld hl,128*64
        ld (ball_x),hl
        ld hl,22*64
        ld (ball_y),hl
        ld hl,14*64
        ld (ball_z),hl
        ld b,130
        call rand_n
        add a,62
        ld b,a
        push bc
        ld b,28
        call rand_n
        pop bc
        add a,196
        ld c,a
        ld a,48
        call make_vel
        ld a,2
        ld (ball_st),a
        xor a
        ld (ball_last),a
        ld (ball_bnc),a
        ld (ball_cross),a
        ld (ball_serve),a
        ld (ball_net),a
        ld (ball_cord),a
        ld (ball_fire),a
        ld a,1
        ld (pl1+P_HITOK),a
        ld a,SFX_FEED
        call play_sfx
        ld ix,pl1
        call ai_plan
        jp hud_draw

; practice_bounce: B = X, C = Y of the first bounce
practice_bounce:
        ld a,(ball_last)
        or a
        ret z                   ; the machine's feed: play on
        ld a,40
        ld (pt_over),a
        ld a,3
        ld (ball_st),a
        ld a,b
        cp XL-2
        jr c,.out
        cp XR+3
        jr nc,.out
        ld a,c
        cp YFAR-2
        jr c,.out
        cp YNET
        jr nc,.out
        ld hl,cone_x
        ld e,3
.k:     ld a,(hl)
        sub b
        call abs_a
        cp 13
        jr nc,.nx
        push hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        pop hl
        sub c
        call abs_a
        cp 11
        jr c,.hit
.nx:    inc hl
        dec e
        jr nz,.k
        ld de,$0050
        call pr_add
        ld a,POP_IN
        jp popup_ball
.hit:   inc hl
        inc hl
        inc hl
        inc hl
        inc hl
        inc hl
        ld (hl),40              ; cone_t
        ld hl,pr_hits
        inc (hl)
        ld de,$0500
        call pr_add
        ld a,SFX_CONE
        call play_sfx
        ld a,24
        call crowd_cheer
        ld a,POP_TARGET
        jp popup_ball
.out:   ld a,POP_OUT
        call popup_ball
        jp show_flag

pr_add:         ; BCD DE into pr_score (2 bytes, high first)
        ld hl,pr_score+1
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        ret

practice_next:
        ld hl,cone_t
        ld b,3
.c:     ld a,(hl)
        or a
        jr z,.n
        ld (hl),0
        push bc
        push hl
        ld de,-6
        add hl,de
        call cone_new
        pop hl
        pop bc
.n:     inc hl
        djnz .c
        xor a
        ld (ball_st),a
        ld a,30
        ld (feedtim),a
        call hud_draw
        ld a,(pr_balls)
        or a
        ret nz
        ld a,1
        ld (match_over),a
        ld (match_win),a
        ret

practice_draw:
        ; the ball machine at the far baseline
        ld bc,128*256+14
        call proj_hr
        ld (spr_x),hl
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(monomode)
        or a
        ld a,GREY
        jr z,.mi
        ld a,WHITE
.mi:    ld (spr_ink),a
        ld a,SF_MACHINE
        call spr_draw
        ; cones
        ld hl,cone_x
        ld e,3
.k:     push hl
        push de
        ld b,(hl)
        inc hl
        inc hl
        inc hl
        ld c,(hl)
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        or a
        jr z,.nt
        dec (hl)
.nt:    push af
        call proj_hr
        ld (spr_x),hl
        ld l,a
        ld h,0
        ld (spr_y),hl
        pop af
        ld b,SF_CONE
        jr z,.s
        ld a,(framecount)
        and 4
        ld b,SF_CONEHIT
        jr z,.s
        ld b,SF_CONE
.s:     ld a,(monomode)
        or a
        ld a,BRED
        jr z,.ci
        ld a,WHITE
.ci:    ld (spr_ink),a
        ld a,b
        call spr_draw
        pop de
        pop hl
        inc hl
        dec e
        jr nz,.k
        ret

; Z if IX is under computer control (autoplay: the computer drives
; the human players too, for soak tests in the emulator)
ctl_cpu:
        ld a,(ix+P_CTL)
        cp CTL_NONE
        jr z,.no
        or a
        ret z
        ld a,(autoplay)
        or a
        jr z,.no
        xor a
        ret
.no:    or 1
        ret

; background music (unless the sound is set to effects only / off)
bgm:
        ld a,(soundmode)
        cp 2
        ret nz
        jp play_music
