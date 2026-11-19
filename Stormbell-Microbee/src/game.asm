; =====================================================================
;  GAME: the title, the five duels, defeat and retry, the ending.
; =====================================================================
N_STAGES    EQU 5
HERO_HP     EQU 12
TICK_FIELDS EQU 2           ; a logic tick every 2 fields: 25 a second

; ---------------------------------------------------------------------
;  the frame clock. vschk polls the 6545's vertical blanking bit; at
;  the start of each blanking it counts a field, shows a finished page
;  and reads the controls. Keeps every register but AF.
; ---------------------------------------------------------------------
vschk:  in a,(P_CRTCA)
        and $20
        push hl
        ld hl,vlast
        cp (hl)
        jr z,.x
        ld (hl),a
        or a
        jr z,.x
        ld hl,fields
        inc (hl)
        ld a,(flip_ask)
        or a
        jr z,.nf
        ; a blanking (62 lines) holds one scenery copy or the flip: the
        ; far layer, then the midground, then the flip
        ld a,(far_pend)
        or a
        jr z,.nofar
        xor a
        ld (far_pend),a
        call blit_far
        jr .nf
.nofar: ld a,(mid_pend)
        or a
        jr z,.flip
        xor a
        ld (mid_pend),a
        call blit_mid
        jr .nf
.flip:  xor a
        ld (flip_ask),a
        ld a,(hidpage)
        call show_page
        ld a,(fl_ask)           ; the floor slides with the page shown
                                ; (done before the beam reaches it, 160
                                ; lines down: it needn't fit the blanking)
        ld hl,fl_shown
        cp (hl)
        call nz,floor_set
.nf:    push bc
        push de
        call read_input
        pop de
        pop bc
.x:     pop hl
        ret

; wait for the next tick, playing sound meanwhile
tick_wait:
        call sound_tick
.w:     call pump
        call vschk
        ld a,(fields)
        cp TICK_FIELDS
        jr c,.w
        xor a
        ld (fields),a
        ld hl,ticks
        inc (hl)
        ret

; a slice of sound (about 2.6 ms). Keeps HL.
pump:   push hl
        ld a,(flip_ask)
        ld hl,mid_pend
        or (hl)
        ld hl,far_pend
        or (hl)
        jr z,.free
        ; page work waits for the next blanking: the sound gives way the
        ; moment it starts (the blanking is only 62 lines)
        ld a,(vlast)
        or a
        jr nz,.free             ; this blanking is already dealt with
        in a,(P_CRTCA)
        and $20
        jr nz,.x                ; one has just begun: vschk's turn
        ld a,$20
        jr .go
.free:  xor a
.go:    ld (watch),a
        call sound_pump
.x:     pop hl
        ret

; wait until a page asked for has been shown
flip_wait:
.w:     call pump
        call vschk
        ld a,(flip_ask)
        or a
        jr nz,.w
        ret

; wait A ticks (render nothing)
pause_ticks:
        ld b,a
.l:     push bc
        call tick_wait
        pop bc
        djnz .l
        ret

; wait for a start press, A ticks at most (0 = forever) -> Z if pressed
wait_start:
        ld (wt),a
        call take_new
.l:     call tick_wait
        call mono_key
        call take_new
        ld (lastnew),a
        and 1 << PB_START | 1 << PB_ESC | 1 << PB_PUNCH | 1 << PB_KICK
        jr nz,.y
        ld a,(wt)
        or a
        jr z,.l
        dec a
        ld (wt),a
        jr nz,.l
        or 1
        ret
.y:     xor a
        ret

; ---------------------------------------------------------------------
;  A = picture: shown on both pages (display off while it loads)
; ---------------------------------------------------------------------
show_pic:
        push af
        call display_off
        pop af
        call pic_find
        call pic_glyphs
        ld a,1
        call set_drawpage
        call pic_cells
        xor a
        call set_drawpage
        call pic_cells
        xor a
        call show_page
        ld (hidpage),a
        xor a
        ld (flip_ask),a
        ld (mid_pend),a
        ld (far_pend),a
        ret

; ---------------------------------------------------------------------
;  the title
; ---------------------------------------------------------------------
title:
        ld sp,STACK
        call stop_music
        call title_pic
        call display_on
        ld a,SFX_THUNDER
        call sfx
        jr title_tune
; M on the title: colour or monochrome monitor
retitle:
        ld sp,STACK
        call stop_music
        call title_pic
        call display_on
title_tune:
        ld hl,tune_title
        call play_music
        jp title_blink

mono_key:
        ld a,(on_title)
        or a
        ret z
        ld a,1
        out (P_ROMLAT),a
        ld a,K_M
        call keytest
        ld b,a
        xor a
        out (P_ROMLAT),a
        ld a,(m_was)
        cpl
        and b
        ld a,b
        ld (m_was),a
        ret z
        ld a,(mono)
        xor 1
        ld (mono),a
        jp retitle

title_pic:
        xor a
        call show_pic
        ld hl,tt_story1
        ld d,16
        ld c,WHITE
        call print_mid2
        ld hl,tt_story2
        ld d,17
        ld c,WHITE
        call print_mid2
        ld hl,tt_keys1
        ld d,19
        ld c,BCYAN
        call print_mid2
        ld hl,tt_keys2
        ld d,20
        ld c,BCYAN
        call print_mid2
        ld hl,tt_keys3
        ld d,21
        ld c,CYAN
        call print_mid2
        ld hl,tt_credit
        ld d,24
        ld c,BMAGENTA
        call print_mid2
        ld hl,tt_mono
        ld a,(mono)
        or a
        jr z,.m
        ld hl,tt_colour
.m:     ld d,23
        ld c,GREY
        jp print_mid2

title_blink:
        ld a,1
        ld (on_title),a
.blink: ld hl,tt_press
        ld d,22
        ld c,YELLOW
        call print_mid2
        ld a,20
        call wait_start
        jr z,.go
        ld hl,tt_blank
        ld d,22
        ld c,YELLOW
        call print_mid2
        ld a,8
        call wait_start
        jr nz,.blink
.go:    ld a,(lastnew)
        bit PB_ESC,a
        jr nz,.blink
        xor a
        ld (on_title),a
        call stop_music
        ; Wren's glyphs stay in the PCG for the whole game
        call display_off
        ld a,BLK_FIGHT
        ld c,BK_HERO
        call fighter_load
        xor a
        ld (stage),a
        ; fall through

; ---------------------------------------------------------------------
;  a stage: the road, the run in, the opponent's entrance, the duel
; ---------------------------------------------------------------------
duel:
        ld sp,STACK
        call stop_music
        ld a,(stage)
        call stage_show         ; (display off)
        call foe_load
        call fighters_init
        ld a,4
        ld (hero+F_X),a
        ld a,60
        ld (foe+F_X),a          ; not on the road yet
        xor a
        ld (foe_in),a
        call hud_names
        call hud_bars
        call display_on
        call draw_frame
        call flip_wait
        ld a,SFX_GONG
        call sfx
        call stage_title
        ld hl,tt_run
        ld d,6
        ld c,BCYAN
        call print_mid2
        ld a,1
        ld (msg_on),a
        ; run to the arena
        ld a,(duel_c)
        call run_road
        ; the opponent comes to meet Wren
        call foe_enter
        jr duel_intro

; after a defeat: straight back into the arena
duel_retry:
        ld sp,STACK
        call stop_music
        call fighters_init
        ; both fighters were somewhere else on both pages: redraw each
        ; page's whole band once, so the old figures are painted over
        ld hl,hero+F_PL0
        call .whole
        ld hl,foe+F_PL0
        call .whole
        ld a,10
        ld (hero+F_X),a
        ld a,30
        ld (foe+F_X),a
        ld a,1
        ld (foe_in),a
        call hud_names
        call hud_bars
        call rub_messages
        call draw_frame
        call flip_wait
        ld a,SFX_GONG
        call sfx
        call stage_title

        jr duel_intro
.whole: ld (hl),0               ; F_PL0
        inc hl
        ld (hl),COLS            ; F_PR0
        inc hl
        ld (hl),0               ; F_PL1
        inc hl
        ld (hl),COLS            ; F_PR1
        ret

duel_intro:
        ; -- a hint about this opponent, the bows
        ld a,(stage)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,hinttab
        add hl,de
        push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld d,4
        ld c,WHITE
        call print_mid2
        pop hl
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld d,5
        ld c,WHITE
        call print_mid2
        ld a,30
        call intro_wait
        ld a,ST_BOW
        ld (hero+F_ST),a
        ld (foe+F_ST),a
        ld a,25
        call intro_wait
        ld a,ST_STAND
        ld (hero+F_ST),a
        ld (foe+F_ST),a
        ld a,30
        call intro_wait
        call rub_messages
        ld hl,tt_fight
        ld d,3
        ld c,BRED
        call print_mid2
        ld a,SFX_BELL
        call sfx
        ld a,ST_IDLE
        ld (hero+F_ST),a
        ld (foe+F_ST),a
        ld a,(stage)
        cp N_STAGES-1
        ld hl,tune_boss
        jr z,.tb
        ld hl,tune_fight
.tb:    call play_music
        ld a,18
        ld (msg_t),a
        call take_new

        call duel_dirty

; ---------------------------------------------------------------------
fight_loop:
        call tick_wait
        ld a,(msg_t)
        or a
        jr z,.nm
        dec a
        ld (msg_t),a
        call z,rub_messages
.nm:    ; the controls
        ld a,(padnew)
        bit PB_ESC,a
        jp nz,quit_ask
        bit PB_PAUSE,a
        jp nz,pause
        call take_new
        and C_PUNCH|C_KICK      ; presses (attack bits match the pad bits)
        ld b,a
        ld a,(pad)
        and C_FWD|C_BACK|C_GUARD
        ld c,a
        ld ix,hero
        call fighter_tick
        call brain
        xor a
        ld (blocked_flag),a
        ld ix,foe
        call fighter_tick
        call resolve
        ld a,(hud_dirty)
        or a
        call nz,hud_bars
        ld a,(counter_flash)
        or a
        jr z,.nc
        xor a
        ld (counter_flash),a
        ld hl,tt_counter
        ld d,3
        ld c,BCYAN
        call print_mid2
        ld a,12
        ld (msg_t),a
.nc:    call draw_duel
        ; a blow that lands holds the picture a moment
        ld a,(hitstop)
        or a
        jr z,.nh
        ld b,a
        xor a
        ld (hitstop),a
.hs:    push bc
        call tick_wait
        pop bc
        djnz .hs
.nh:    ; the end of the duel?
        ld a,(foe+F_ST)
        cp ST_DOWN
        jr nz,.nw
        ld a,(foe+F_T)
        cp 20
        jp nc,won
.nw:    ld a,(hero+F_ST)
        cp ST_DOWN
        jp nz,fight_loop
        ld a,(hero+F_T)
        cp 20
        jp nc,lost
        jp fight_loop

intro_wait:
        ld b,a
.l:     push bc
        call tick_wait
        ld bc,0
        ld ix,hero
        call fighter_tick
        ld bc,0
        ld ix,foe
        call fighter_tick
        call draw_frame
        pop bc
        djnz .l
        ret

; the stage's name on row 2
stage_title:
        ld a,(stage)
        add a,a
        ld e,a
        ld d,0
        ld hl,stagetab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld d,2
        ld c,YELLOW
        jp print_mid2

; the opponent's glyphs, brain, ranges (the display is off)
foe_load:
        ld a,(stage)
        add a,BLK_FIGHT+1
        ld c,BK_FOE
        call fighter_load
        ld a,(stage)
        add a,a
        ld l,a
        ld h,0
        ld de,brains
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (brainp),hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (scriptp),de
        ld a,(stage)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,rangetab
        add hl,de
        ld (rangep),hl
        ret

; both fighters fresh, standing
fighters_init:
        ld ix,hero
        call f_clear
        ld (ix+F_BLK),BLK_FIGHT
        ld (ix+F_BANK),BK_HERO
        ld (ix+F_DIR),1
        ld (ix+F_HP),HERO_HP
        ld (ix+F_MAX),HERO_HP
        ld hl,tim_hero
        ld (ix+F_TAB),l
        ld (ix+F_TAB+1),h
        ld ix,foe
        call f_clear
        ld a,(stage)
        add a,BLK_FIGHT+1
        ld (ix+F_BLK),a
        ld (ix+F_BANK),BK_FOE
        ld (ix+F_DIR),-1
        ld hl,(brainp)
        ld de,B_HP
        add hl,de
        ld a,(hl)
        ld (ix+F_HP),a
        ld (ix+F_MAX),a
        inc hl
        ld a,(hl)
        ld (ix+F_TAB),a
        inc hl
        ld a,(hl)
        ld (ix+F_TAB+1),a
        inc hl
        ld a,(hl)
        ld (ix+F_ARMOUR),a
        xor a
        ld (scr_pc),a
        ld (scr_t),a
        ld (guard_t),a
        ld (seen),a
        ld (punished),a
        ld (blocked_flag),a
        ld (counter_flash),a
        ret

; ---------------------------------------------------------------------
;  the road. Hold advance to run: Wren runs to column 10, then the
;  road scrolls past him. Returns when the camera reaches A.
; ---------------------------------------------------------------------
run_road:
        ld (run_lim),a
.l:     call tick_wait
        ld a,(padnew)
        bit PB_ESC,a
        jp nz,title
        call take_new
        ld a,(pad)
        bit PB_FWD,a
        jr z,.stop
        ld a,ST_RUN
        ld (hero+F_ST),a
        ld a,(msg_on)
        or a
        jr z,.nm
        xor a
        ld (msg_on),a
        call far_dirty          ; the messages go as Wren sets off
.nm:    ld a,(hero+F_X)
        cp 10
        jr nc,.cam
        ld a,(ticks)
        and 1
        jr nz,.draw
        ld hl,hero+F_X
        inc (hl)
        jr .draw
.cam:   ld a,(run_lim)
        call cam_step
        jr .draw
.stop:  ld a,ST_STAND
        ld (hero+F_ST),a
.draw:  ld bc,0
        ld ix,hero
        call fighter_tick
        ld bc,0
        ld ix,foe
        call fighter_tick
        call draw_frame
        ld a,(hero+F_X)
        cp 10
        jr c,.l
        ld a,(cam_c)
        ld hl,run_lim
        cp (hl)
        jr c,.l
        ret

; the opponent runs in from the right and squares up
foe_enter:
        ld a,ST_STAND
        ld (hero+F_ST),a
        ld a,44
        ld (foe+F_X),a
        ld a,ST_RUN
        ld (foe+F_ST),a
        ld a,1
        ld (foe_in),a
.l:     call tick_wait
        ld a,(ticks)
        and 1
        jr nz,.d
        ld hl,foe+F_X
        dec (hl)
.d:     ld bc,0
        ld ix,hero
        call fighter_tick
        ld bc,0
        ld ix,foe
        call fighter_tick
        call draw_frame
        ld a,(foe+F_X)
        cp 31
        jr nc,.l
        ld a,ST_STAND
        ld (foe+F_ST),a
        ld a,8
        jp intro_wait

; after a win: run on to the end of the road, and off it
run_on:
        ld hl,tt_runon
        ld d,6
        ld c,BCYAN
        call print_mid2
        ld a,1
        ld (msg_on),a
        ld a,(end_c)
        call run_road
        ld a,ST_RUN
        ld (hero+F_ST),a
.l:     call tick_wait
        ld hl,hero+F_X
        inc (hl)
        ld bc,0
        ld ix,hero
        call fighter_tick
        ld bc,0
        ld ix,foe
        call fighter_tick
        call draw_frame
        ld a,(hero+F_X)
        cp 46
        jr c,.l
        ret

; render: the hero under, the foe over, unless the hero is attacking
; the duel's frame: while both fighters hold their poses the page on
; show is already right, so nothing is drawn and the whole tick is free
; for sound
draw_duel:
        call flip_wait
        ld a,(hero+F_ST)
        cp ST_ATK
        ld a,0
        jr nz,.t
        inc a
.t:     ld (sig_now+4),a
        ld hl,(hero+F_X)        ; column and frame
        ld (sig_now),hl
        ld hl,(foe+F_X)
        ld (sig_now+2),hl
        ld hl,sig0
        ld a,(vispage)
        or a
        jr z,.p
        ld hl,sig1
.p:     ld de,sig_now
        ld b,5
.c:     ld a,(de)
        cp (hl)
        jr nz,.draw
        inc hl
        inc de
        djnz .c
        ret
.draw:  ld de,sig1              ; the hidden page gets it
        ld a,(vispage)
        or a
        jr z,.h
        ld de,sig0
.h:     ld hl,sig_now
        ld bc,5
        ldir
        jr draw_frame
fight_resume:
        call duel_dirty
        jp fight_loop
duel_dirty:
        ld a,$FF
        ld (sig0+4),a
        ld (sig1+4),a
        ret

draw_frame:
        ld a,(hero+F_ST)
        cp ST_ATK
        jr z,.hero_top
        ld ix,hero
        ld iy,foe
        jp .go
.hero_top:
        ld ix,foe
        ld iy,hero
.go:    call flip_wait
        jp render

f_clear:
        push ix
        pop hl
        ld b,F_SIZE
.c:     ld (hl),0
        inc hl
        djnz .c
        ld (ix+F_ST),ST_STAND
        ld (ix+F_FR),FR_IDLE
        ret                     ; (F_PLn = F_PRn = 0: nothing drawn yet)

; rows 2..6 back to the scenery (both pages, as they are next drawn)
rub_messages:
        jp far_dirty

; ---------------------------------------------------------------------
;  the HUD: names on row 0, health on row 24
; ---------------------------------------------------------------------
hud_names:
        ld hl,blank40
        ld d,0
        ld e,0
        ld c,WHITE
        call print2
        ld hl,(nametab)
        ld d,0
        ld e,1
        ld c,WHITE
        call print2
        ; the opponent's name, flush right
        ld a,(stage)
        inc a
        add a,a
        ld e,a
        ld d,0
        ld hl,nametab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld b,0
.n:     ld a,(hl)
        or a
        jr z,.e
        inc hl
        inc b
        jr .n
.e:     ld a,COLS-1
        sub b
        ld e,a
        pop hl
        ld d,0
        ld c,BRED
        call print2
        ; the stage number in the middle
        ld a,(stage)
        add a,'1'
        ld (tt_stage+6),a
        ld hl,tt_stage
        ld d,0
        ld c,GREY
        jp print_mid2

hud_bars:
        xor a
        ld (hud_dirty),a
        ; Wren: pips from the left
        ld hl,hudbuf
        ld de,hudbuf+1
        ld bc,39
        ld (hl),' '
        ldir
        xor a
        ld (hudbuf+40),a
        ld a,(hero+F_MAX)
        ld b,a
        ld a,(hero+F_HP)
        ld c,a
        ld hl,hudbuf+1
        call .pips
        ld hl,hudbuf
        ld d,24
        ld e,0
        ld c,YELLOW
        call print2
        ; the opponent: pips from the right
        ld hl,hudbuf
        ld de,hudbuf+1
        ld bc,39
        ld (hl),' '
        ldir
        ld a,(foe+F_MAX)
        ld b,a
        ld a,(foe+F_HP)
        ld c,a
        ld a,COLS-1
        sub b
        ld e,a
        ld d,0
        ld hl,hudbuf
        add hl,de
        push de
        ; the right side fills from the right: empty pips first
        ld a,b
        sub c
        jr z,.full
        push bc
        ld b,a
.ee:    ld (hl),'a'
        inc hl
        djnz .ee
        pop bc
.full:  ld a,c
        or a
        jr z,.pd
        ld b,c
.ff:    ld (hl),'`'
        inc hl
        djnz .ff
.pd:    ld (hl),0
        pop de
        ld hl,hudbuf
        add hl,de
        ld d,24
        ld c,BRED
        jp print2
; B = max, C = now: C full pips then empty ones at HL
.pips:  ld a,c
        or a
        jr z,.em
.f:     ld (hl),'`'
        inc hl
        dec b
        dec c
        jr nz,.f
.em:    ld a,b
        or a
        ret z
.e2:    ld (hl),'a'
        inc hl
        djnz .e2
        ret

; ---------------------------------------------------------------------
;  pause, quit, win, lose, the ending
; ---------------------------------------------------------------------
pause:
        call take_new
        call stop_music
        ld hl,tt_paused
        ld d,2
        ld c,YELLOW
        call print_mid2
        ld hl,tt_keys1
        ld d,4
        ld c,WHITE
        call print_mid2
        ld hl,tt_keys2
        ld d,5
        ld c,WHITE
        call print_mid2
.w:     call tick_wait
        call take_new
        and 1 << PB_PAUSE | 1 << PB_START
        jr z,.w
        call rub_messages
        call resume_music
        jp fight_resume

quit_ask:
        call take_new
        ld hl,tt_quit
        ld d,3
        ld c,YELLOW
        call print_mid2
.w:     call tick_wait
        call take_new
        bit PB_ESC,a
        jp nz,title
        and 1 << PB_START | 1 << PB_PAUSE | 1 << PB_PUNCH | 1 << PB_KICK | 1 << PB_FWD | 1 << PB_BACK
        jr z,.w
        call rub_messages
        jp fight_resume

won:
        call stop_music
        ld a,ST_BOW
        ld (hero+F_ST),a
        ld a,(stage)
        inc a
        add a,a
        ld e,a
        ld d,0
        ld hl,nametab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld d,3
        ld c,YELLOW
        call print_mid2
        ld hl,tt_falls
        ld d,4
        ld c,WHITE
        call print_mid2
        ld hl,tune_win
        call play_music
        ld a,60
        call idle_wait
        call run_on
        ld a,(stage)
        inc a
        ld (stage),a
        cp N_STAGES
        jp c,duel
        jp ending

lost:
        call stop_music
        ld hl,tt_fallen
        ld d,3
        ld c,BRED
        call print_mid2
        ld hl,tt_retry
        ld d,5
        ld c,WHITE
        call print_mid2
        ld hl,tune_lose
        call play_music
        call take_new
.w:     call tick_wait
        ld bc,0
        ld ix,foe
        ld a,(ix+F_ST)
        cp ST_FALL
        jr nc,.nf
        ld (ix+F_ST),ST_STAND
.nf:    call fighter_tick
        ld bc,0
        ld ix,hero
        call fighter_tick
        call draw_frame
        call take_new
        bit PB_ESC,a
        jp nz,title
        and 1 << PB_START | 1 << PB_PUNCH | 1 << PB_KICK
        jr z,.w
        jp duel_retry           ; the same opponent, straight away

idle_wait:
        ld b,a
.l:     push bc
        call tick_wait
        ld bc,0
        ld ix,hero
        call fighter_tick
        ld bc,0
        ld ix,foe
        call fighter_tick
        call draw_frame
        pop bc
        djnz .l
        ret

ending:
        call stop_music
        ld a,1
        call show_pic
        ld hl,tt_end1
        ld d,16
        ld c,YELLOW
        call print_mid2
        ld hl,tt_end2
        ld d,18
        ld c,WHITE
        call print_mid2
        ld hl,tt_end3
        ld d,19
        ld c,WHITE
        call print_mid2
        ld hl,tt_end4
        ld d,21
        ld c,BCYAN
        call print_mid2
        ld hl,tt_credit
        ld d,23
        ld c,BMAGENTA
        call print_mid2
        call display_on
        ld a,SFX_TOLL
        call sfx
        ld a,70
        call pause_ticks
        ld hl,tune_end
        call play_music
        ld a,40
        call pause_ticks
        ld hl,tt_again
        ld d,24
        ld c,GREY
        call print_mid2
        xor a
        call wait_start
        jp title

; ---------------------------------------------------------------------
tt_story1:  db "THE STORM LORD HAS SILENCED THE BELL.",0
tt_story2:  db "CLIMB THE MOUNTAIN. RING IT AGAIN.",0
tt_keys1:   db "D ADVANCE  A RETREAT  S GUARD",0
tt_keys2:   db "K PUNCH  L KICK  P PAUSE  ESC QUIT",0
tt_keys3:   db "OR ARROWS, UP KICKS. JOYSTICK TOO",0
tt_press:   db "PRESS SPACE OR FIRE",0
tt_blank:   db "                   ",0
tt_credit:  db "VIBED BY BPM 2026",0
tt_mono:    db "M  FOR A MONOCHROME MONITOR",0
tt_colour:  db "M  FOR A COLOUR MONITOR",0
tt_fight:   db "BEGIN!",0
tt_counter: db "COUNTER!",0
tt_paused:  db "PAUSED - P TO GO ON",0
tt_quit:    db "QUIT TO THE TITLE?  ESC YES",0
tt_falls:   db "IS BEATEN",0
tt_fallen:  db "YOU HAVE FALLEN",0
tt_retry:   db "SPACE: AGAIN   ESC: TITLE",0
tt_stage:   db "STAGE 1",0
tt_end1:    db "THE STORMBELL RINGS AT DAWN",0
tt_end2:    db "THE STORM LORD IS BEATEN, AND THE",0
tt_end3:    db "VALLEY WAKES TO CLEAR SKIES.",0
tt_end4:    db "WELL FOUGHT, WREN.",0
tt_again:   db "PRESS SPACE",0
tt_run:     db "HOLD D (OR RIGHT) TO RUN",0
tt_runon:   db "HOLD D TO RUN ON",0
blank40:    db "                                        ",0
