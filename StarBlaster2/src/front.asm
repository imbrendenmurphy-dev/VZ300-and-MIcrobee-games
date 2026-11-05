; =====================================================================
;  STAR BLASTER II - front end: title, attract pages, demo, hall of fame,
;  initials entry, mission-complete screen
; =====================================================================

; fe_frame: one front-end tick (vblank commit, input, erase)
fe_frame:
        call prep_commit
        call wait_tick
        call commit
        call read_input
        call erase
        ld hl,(fe_t)
        inc hl
        ld (fe_t),hl
        ret

; fe_keys: global attract keys -> A = 0 nothing, 1 start game
fe_keys:
        call read_digit
        or a
        jr z,.nd
        ld (skill),a
        ld a,1
        ret
.nd:    ld a,(keysnew)
        bit 6,a
        jr z,.nt
        ld a,(trainer)
        xor 1
        ld (trainer),a
        ld a,SFX_BLIP
        call play_sfx
        call title_status
.nt:    ld a,(keysnew)
        and $14
        ret z
        ld a,1
        ret

; new page: clear BASE+BG to blue (shown later by blinds)
page_clear:
        ld a,$AA
        ld d,0
        ld e,64
        call fill_rows
        ld a,1
        ld (txtbase),a
        xor a
        ld (txtdbl),a
        ld a,64
        ld (clipbot),a
        ret
; snapshot BG into BASE (after drawing sprites onto a page)
bg_to_base:
        ld hl,BG
        ld de,BASE
        ld bc,2048
        ldir
        ret

; blinds: reveal the new page 8 rows a tick
blinds:
        xor a
        ld (txtbase),a
        ld (let_t),a
.s:     call fe_frame
        call fe_keys
        or a
        ret nz
        ld a,(let_t)
        ld e,a
        ld d,0
        ld hl,blindord
        add hl,de
        ld a,(hl)
        ld b,8
.r:     push af
        push bc
        call reveal_row
        pop bc
        pop af
        add a,8
        djnz .r
        ld a,(let_t)
        inc a
        ld (let_t),a
        cp 8
        jr nz,.s
        xor a
        ret
blindord: db 0,4,2,6,1,5,3,7

; hold a page for B ticks (A=1 if start pressed)
page_hold:
        ld a,b
        ld (let_t),a
.l:     call fe_frame
        call fe_keys
        or a
        ret nz
        ld a,(let_t)
        dec a
        ld (let_t),a
        jr nz,.l
        xor a
        ret

; ---------------------------------------------------------------------
attract:
        ld sp,STACKTOP
        xor a
        ld (demo),a
        ld (autoplay),a
        ld (godmode),a
        ld a,MODE1
        ld (latchbase),a
        call ranges_init
.cycle: call title_screen
        or a
        jr nz,.play
        call page_brief
        or a
        jr nz,.play
        call page_fleet
        or a
        jr nz,.play
        call page_controls
        or a
        jr nz,.play
        call run_demo
        or a
        jr nz,.play
        call page_hof
        or a
        jr nz,.play
        jr .cycle
.play:  call play_game
        jr attract

play_game:
        xor a
        ld (demo),a
        ld (autoplay),a
        call stop_music
        ld hl,(framecount)
        ld (seed),hl
        call new_game
        ; finished: game over (gstate 3) or quit
        call stop_music
        ld a,(gstate)
        cp 3
        ret nz
        ld a,(trainer)
        or a
        ret nz
        jp check_hiscore

; ---------------------------------------------------------------------
; title screen with flying logo letters, starfield and a fighter flyby
; ---------------------------------------------------------------------
title_screen:
        call page_clear
        ld hl,mus_title_0
        ld de,mus_title_1
        call play_music
        ; text
        ld a,3
        ld b,2
        call set_ink
        ld hl,s_t_sub
        ld e,27
        call print_c
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_t_vibe
        ld e,46
        call print_c
        call title_status
        xor a
        ld (fe_msg),a
        call title_msg
        call blinds
        or a
        ret nz
        ; letters start scattered
        ld hl,logo_layout
        ld de,lettpos
        ld c,0
.ls:    ld a,(hl)
        inc hl
        or (hl)
        jr z,.lsd
        inc hl
        inc hl
        inc hl
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,c
        and 31
        cp 28
        jr c,.c1
        sub 10
.c1:    ld (de),a
        inc de
        ld a,c
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b
        and 63
        sub 18
        ld (de),a
        inc de
        inc c
        jr .ls
.lsd:   xor a
        ld (title_ph),a
        ld hl,0
        ld (fe_t),hl
        ld a,4
        ld (warpk),a
        ld hl,0
        ld (dvaz),hl
        ld (dvel),hl
        call stars_init
        ld hl,PARTS
        ld de,PARTS+1
        ld bc,NPART*8-1
        ld (hl),0
        ldir
        ld hl,60*256
        ld (fy_z),hl
        xor a
        ld (fy_st),a
.loop:  call fe_frame
        call fe_keys
        or a
        ret nz
        ld hl,(fe_t)
        ld de,600
        or a
        sbc hl,de
        jr c,.go
        xor a
        ret
.go:    ld hl,(tick)
        inc hl
        ld (tick),hl
        ; message cycle
        ld a,(fe_t)
        and 127
        jr nz,.nm
        ld a,(fe_msg)
        inc a
        and 3
        ld (fe_msg),a
        call title_msg
.nm:    ld a,64
        ld (clipbot),a
        call title_stars
        call fs_check
        call title_letters
        call fs_check
        call title_flyby
        call update_parts
        call draw_parts
        jr .loop

s_t_sub: db "THE ENERMY RETURNS",0
s_t_vibe: db "VIBED BY BPM  2026",0

title_status:
        ld a,1
        ld (txtbase),a
        ld a,0
        ld b,2
        call set_ink
        ld hl,s_skill
        ld de,4*256+52
        call print
        ld a,(skill)
        add a,'0'
        ld de,10*256+52
        call putchar
        ld hl,s_troff
        ld a,(trainer)
        or a
        jr z,.p
        ld hl,s_tron
.p:     ld de,14*256+52
        call print
        xor a
        ld (txtbase),a
        ret
s_skill: db "SKILL",0
s_troff: db "TRAINER OFF",0
s_tron: db "TRAINER ON ",0

title_msg:
        ld a,1
        ld (txtbase),a
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_blank
        ld de,0*256+58
        call print
        ld a,(fe_msg)
        add a,a
        ld e,a
        ld d,0
        ld hl,msgtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld e,58
        call print_c
        xor a
        ld (txtbase),a
        ret
s_blank: db "                                ",0
msgtab: dw s_m1,s_m2,s_m3,s_m4
s_m1:   db "SPACE OR FIRE TO START",0
s_m2:   db "KEYS 1-5 START AT THAT SKILL",0
s_m3:   db "T TOGGLES TRAINER MODE",0
s_m4:   db "AFTER DUBOIS & MCNAMARA 1984",0

; stars only where the picture is plain space
title_stars:
        call update_stars
        ld ix,STARS
        ld b,NSTAR
.s:     push bc
        ld b,(ix+1)
        ld c,(ix+3)
        ld a,c
        call bgrow
        ld a,b
        rrca
        rrca
        and $1F
        or l
        ld l,a
        res 3,h
        ld a,(hl)
        cp $AA
        jr nz,.n
        ld a,(ix+4)
        xor 1
        ld e,a
        call pset_c
.n:     ld de,5
        add ix,de
        pop bc
        djnz .s
        ret

; letters ease towards their places; once all have landed they are
; stamped into BASE and no longer redrawn
title_letters:
        ld a,(title_ph)
        or a
        ret nz
        ld hl,logo_layout
        ld de,lettpos
        ld c,0                  ; letters still moving
.l:     ld a,(hl)
        inc hl
        or (hl)
        jr z,.done
        dec hl
        push hl
        push de
        push bc
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = letter data
        ld (letp),bc
        inc hl
        ld a,(hl)               ; final col
        inc hl
        ld l,(hl)               ; final row
        ld h,a
        ex de,hl                ; HL = current pos ptr, D = fcol, E = frow
        ; col
        ld a,(hl)
        cp d
        jr z,.cok
        jr c,.cup
        dec a
        jr .cst
.cup:   inc a
.cst:   ld (hl),a
        pop bc
        inc c
        push bc
.cok:   inc hl
        ld a,(hl)
        sub e
        jr z,.rok
        ; move 1/4 of the way (at least 1)
        sra a
        sra a
        jr nz,.rm
        ld a,(hl)
        cp e
        ld a,1
        jr nc,.rm
        ld a,-1
.rm:    ld d,a
        ld a,(hl)
        sub d
        ld (hl),a
        pop bc
        inc c
        push bc
.rok:   dec hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        ld hl,(letp)
        pop bc
        push bc
        call blit_let
        pop bc
        pop de
        pop hl
        inc de
        inc de
        inc hl
        inc hl
        inc hl
        inc hl
        jr .l
.done:  ld a,c
        or a
        ret nz
        ; all landed: stamp into BASE
        ld a,1
        ld (title_ph),a
        ld (txtbase),a
        ld hl,logo_layout
.st:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.std
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push hl
        ex de,hl
        ld d,b
        ld e,c
        call blit_let
        pop hl
        jr .st
.std:   xor a
        ld (txtbase),a
        ld a,SFX_BIGBOOM
        call play_sfx
        ld a,4
        ld (flasht),a
        ret

; blit_let: HL = letter (b, h, pairs), D = byte col, E = row (signed)
blit_let:
        ld a,(hl)
        ld (lb_b),a
        inc hl
        ld a,(hl)
        ld (lb_h),a
        inc hl
.r:     ld a,e
        cp 64
        jr nc,.skip             ; off screen (also negative)
        push de
        push hl
        ld a,e
        call bgrow
        ld a,l
        or d
        ld l,a
        ex de,hl                ; DE = BG
        pop hl
        ld a,(lb_b)
        ld b,a
.b:     ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        ld c,a
        ld a,(txtbase)
        or a
        jr z,.nb
        res 3,d
        ld a,c
        ld (de),a
        set 3,d
.nb:    inc e
        djnz .b
        pop de
        push hl
        push de
        ld c,d
        ld a,(lb_b)
        add a,d
        dec a
        ld b,a
        ld a,e
        call mark
        pop de
        pop hl
        jr .n
.skip:  ld a,(lb_b)
        add a,a
        ld c,a
        ld b,0
        add hl,bc
.n:     inc e
        ld a,(lb_h)
        dec a
        ld (lb_h),a
        jr nz,.r
        ret

; fighter flyby + blast on the title
title_flyby:
        ld a,(title_ph)
        or a
        ret z
        ld a,(fy_st)
        or a
        jr z,.fly
        dec a
        ld (fy_st),a
        ret nz
        ld hl,60*256
        ld (fy_z),hl
        ret
.fly:   ld hl,(fy_z)
        ld de,-110
        add hl,de
        ld (fy_z),hl
        ld a,h
        ld (fy_x),a
        ; x = 64 + sin(t*3)*0.25
        ld a,(fe_t)
        ld b,a
        add a,a
        add a,b
        call sinv
        sra a
        sra a
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld hl,CX
        add hl,de
        push hl
        ld a,(fy_z+1)
        ld e,a
        ld d,0
        ld hl,ztab_FHT
        add hl,de
        ld c,(hl)
        pop hl
        push hl
        ld a,SPR_FHT
        ld e,37
        call draw_spr
        pop hl
        ld a,(fy_z+1)
        cp 12
        ret nc
        ; blast it
        ld a,l
        ld (lx1),a
        ld (fy_x),a
        ld a,37
        ld (ly1),a
        xor a
        ld (lx0),a
        ld a,43
        ld (ly0),a
        ld a,1
        ld (lcol),a
        call line
        ld a,(fy_x)
        ld (lx1),a
        ld a,37
        ld (ly1),a
        ld a,127
        ld (lx0),a
        ld a,43
        ld (ly0),a
        ld a,3
        ld (lcol),a
        call line
        ld a,(fy_z+1)
        cp 9
        ret nc
        ld a,(fy_x)
        ld b,a
        ld c,37
        ld a,16
        call burst
        ld a,SFX_BOOM
        call play_sfx
        ld a,90
        ld (fy_st),a
        ret

; ---------------------------------------------------------------------
; information pages
; ---------------------------------------------------------------------
; print a list of lines: HL -> (row, string) ... row 255 = end
print_lines:
.l:     ld a,(hl)
        cp 255
        ret z
        ld e,a
        inc hl
        push hl
        call print_c
        pop hl
.z:     ld a,(hl)
        inc hl
        or a
        jr nz,.z
        jr .l

page_brief:
        call page_clear
        ld hl,mus_info_0
        ld de,mus_info_1
        call play_music
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_brief_t
        ld e,2
        call print_c
        ld a,0
        ld b,2
        call set_ink
        ld hl,brief_lines
        call print_lines
        call blinds
        or a
        ret nz
        ld b,220
        jp page_hold
s_brief_t: db "MISSION BRIEFING",0
brief_lines:
        db 10,"THE ENERMY ARE BACK!",0
        db 17,"THEIR FLEET HAS RETURNED WITH",0
        db 23,"ACES, MINES AND A MOTHERSHIP.",0
        db 30,"SCAN 360 DEGREES OF SPACE AND",0
        db 36,"WATCH THE RADAR. DESTROY EVERY",0
        db 42,"SHIP IN 8 SECTORS. ENERGY IS",0
        db 48,"YOUR LIFE: IT DRAINS ALL THE",0
        db 54,"TIME. SHOOT PODS FOR MORE.",0
        db 255

page_controls:
        call page_clear
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_ctl_t
        ld e,2
        call print_c
        ld a,0
        ld b,2
        call set_ink
        ld hl,ctl_lines
        call print_lines
        ld a,3
        ld b,2
        call set_ink
        ld hl,ctl_lines2
        call print_lines
        call blinds
        or a
        ret nz
        ld b,220
        jp page_hold
s_ctl_t: db "CONTROLS",0
ctl_lines:
        db 9,"M  SCAN LEFT   ,  SCAN RIGHT",0
        db 15,"Q  SCAN UP     A  SCAN DOWN ",0
        db 21,"Z OR SPACE    FIRE LASERS   ",0
        db 27,"N  NOVA BOMB   P  PAUSE     ",0
        db 33,"S  SOUND       X  QUIT(PAUSE)",0
        db 39,"JOYSTICK ON EITHER PORT",0
        db 255
ctl_lines2:
        db 47,"1-5 START AT SKILL LEVEL",0
        db 53,"(5 = HARD)  T = TRAINER MODE",0
        db 255

; the Enermy fleet gallery: sprites with names and points
page_fleet:
        call page_clear
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_fleet_t
        ld e,1
        call print_c
        ld hl,fleet_list
.f:     ld a,(hl)
        cp 255
        jr z,.fd
        push hl
        ld c,(hl)               ; sprite
        inc hl
        ld a,(hl)               ; size
        inc hl
        ld b,(hl)               ; x
        inc hl
        ld e,(hl)               ; y
        inc hl
        push hl
        ld l,b
        ld h,0
        ld b,c
        ld c,a
        ld a,b
        call draw_spr
        pop hl
        ld d,(hl)               ; text col
        inc hl
        ld e,(hl)               ; text row
        inc hl
        push de
        push hl
        ld a,0
        ld b,2
        call set_ink
        pop hl
        pop de
        call print
        pop hl
.sk:    ld a,(hl)
        inc hl
        cp 255
        jr z,.f
        jr .sk
.fd:    call bg_to_base
        call blinds
        or a
        ret nz
        ld b,240
        jp page_hold
s_fleet_t: db "THE ENERMY FLEET",0
; sprite, size, x, y, textcol, textrow, text, 255
fleet_list:
        db SPR_FHT,5,14,12,7,10,"FHT 250",0,255
        db SPR_ACE,5,14,24,7,22,"ACE 500",0,255
        db SPR_TNK,6,14,36,7,34,"TNK 100",0,255
        db SPR_FRT,6,14,47,7,45,"FRT 150",0,255
        db SPR_TRP,6,14,58,7,56,"TRP 200",0,255
        db SPR_ROCK,5,78,12,23,10,"ROCK 50",0,255
        db SPR_MINE,4,78,24,23,22,"MINE 100",0,255
        db SPR_POD,4,78,35,23,33,"POD ENERGY",0,255
        db SPR_BOSS,1,78,50,23,48,"MOTHER",0,255
        db 255

; ---------------------------------------------------------------------
; hall of fame
; ---------------------------------------------------------------------
page_hof:
        call page_clear
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_hof_t
        ld e,3
        call print_c
        ld a,0
        ld b,2
        call set_ink
        ld hl,s_hof_h
        ld e,12
        call print_c
        ld ix,hitab
        ld e,21
        ld b,HI_N
.h:     push bc
        push de
        ld a,HI_N+1
        sub b
        add a,'0'
        ld d,6
        push de
        call putchar
        pop de
        ld a,'.'
        inc d
        push de
        call putchar
        pop de
        ld d,9
        push ix
        pop hl
        ld b,3
        push de
        call print_bcd
        pop de
        ld a,(ix+3)
        add a,'0'
        ld d,17
        push de
        call putchar
        pop de
        ld d,21
        push ix
        pop hl
        inc hl
        inc hl
        inc hl
        inc hl
        ld b,3
.i:     ld a,(hl)
        push hl
        push bc
        push de
        call putchar
        pop de
        pop bc
        pop hl
        inc hl
        inc d
        djnz .i
        pop de
        ld a,e
        add a,7
        ld e,a
        ld bc,8
        add ix,bc
        pop bc
        djnz .h
        call blinds
        or a
        ret nz
        ld b,220
        jp page_hold
s_hof_t: db "HALL OF FAME",0
s_hof_h: db "   SCORE   SECTOR  NAME",0

; ---------------------------------------------------------------------
; demo: the computer plays a sector
; ---------------------------------------------------------------------
run_demo:
        ld a,1
        ld (demo),a
        ld (autoplay),a
        ld hl,999
        ld (energy),hl
        ld a,(dt_cnt)
        inc a
        ld (dt_cnt),a
        and 7
        ld e,a
        ld d,0
        ld hl,demo_secs
        add hl,de
        ld a,(hl)
        ld (sector),a
        xor a
        ld (lap),a
        ld a,1
        ld (novas),a
        ld hl,0
        ld (tick),hl
        call start_sector
        ld hl,s_demo
        ld (banner1),hl
        call game_loop
        ; ended: by key (carry from game_keys) or game over/timeout
        xor a
        ld (autoplay),a
        ld (demo),a
        call stop_music
        ld a,MODE1
        ld (latchbase),a
        ld a,(keysnew)
        and $14
        ld a,1
        ret nz
        xor a
        ret
s_demo: db "DEMO MODE",0
demo_secs: db 0,5,1,7,3,6,2,4

; ---------------------------------------------------------------------
; high score check + initials
; ---------------------------------------------------------------------
check_hiscore:
        ; find the slot: first entry with score < ours
        ld ix,hitab
        ld b,0
.f:     ld a,(score)
        cp (ix+0)
        jr c,.n
        jr nz,.got
        ld a,(score+1)
        cp (ix+1)
        jr c,.n
        jr nz,.got
        ld a,(score+2)
        cp (ix+2)
        jr c,.n
        jr z,.n
        jr .got
.n:     ld de,8
        add ix,de
        inc b
        ld a,b
        cp HI_N
        jr nz,.f
        ret
.got:   ld a,b
        ld (hi_pos),a
        ; shift lower entries down
        ld a,HI_N-1
        sub b
        jr z,.ins
        ld c,a
        ld b,0
        sla c
        sla c
        sla c                   ; bytes to move
        ld hl,hitab+HI_N*8-9
        ld de,hitab+HI_N*8-1
        lddr
.ins:   ld a,(score)
        ld (ix+0),a
        ld a,(score+1)
        ld (ix+1),a
        ld a,(score+2)
        ld (ix+2),a
        ld a,(sector)
        inc a
        ld (ix+3),a
        ld (ix+4),'A'
        ld (ix+5),'A'
        ld (ix+6),'A'
        ; entry screen
        call page_clear
        ld a,1
        ld b,2
        call set_ink
        ld hl,s_newhi
        ld e,8
        call print_c
        ld a,0
        ld b,2
        call set_ink
        ld hl,s_enter
        ld e,20
        call print_c
        ld hl,s_enter2
        ld e,50
        call print_c
        ld hl,mus_hiscore_0
        ld de,mus_hiscore_1
        call play_music
        call blinds
        xor a
        ld (hi_cur),a
.ed:    call fe_frame
        ; draw the three letters big (double height), cursor flashing
        ld a,1
        ld (txtdbl),a
        ld b,0
.dl:    push bc
        ld a,b
        ld hl,hi_cur
        cp (hl)
        ld a,1
        jr nz,.ci
        ld a,(fe_t)
        and 4
        ld a,3
        jr z,.ci
        ld a,1
.ci:    ld b,2
        call set_ink
        pop bc
        push bc
        push ix
        pop hl
        ld e,b
        ld d,0
        add hl,de
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        ld e,32
        ld a,b
        add a,a
        add a,14
        ld d,a
        ld a,(hl)
        call putchar
        pop bc
        inc b
        ld a,b
        cp 3
        jr nz,.dl
        xor a
        ld (txtdbl),a
        ; input
        push ix
        pop hl
        ld a,(hi_cur)
        ld e,a
        ld d,0
        add hl,de
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,(inpnew)
        bit 2,a
        jr z,.nu
        ld a,(hl)
        inc a
        cp 'Z'+1
        jr c,.u1
        ld a,' '
.u1:    cp ' '+1
        jr nz,.u2
        ld a,'A'
.u2:    ld (hl),a
        ld a,SFX_BLIP
        call play_sfx
.nu:    ld a,(inpnew)
        bit 3,a
        jr z,.nd
        ld a,(hl)
        dec a
        cp 'A'-1
        jr nz,.d1
        ld a,' '
.d1:    cp ' '-1
        jr nz,.d2
        ld a,'Z'
.d2:    ld (hl),a
        ld a,SFX_BLIP
        call play_sfx
.nd:    ld a,(inpnew)
        and $10
        jr z,.nf
        ld a,SFX_PICKUP
        call play_sfx
        ld a,(hi_cur)
        inc a
        ld (hi_cur),a
        cp 3
        jr nc,.done
.nf:    ld a,(keysnew)
        bit 2,a
        jr nz,.done
        jp .ed
.done:  ld b,40
        call page_hold
        jp page_hof
s_newhi: db "NEW HIGH SCORE!",0
s_enter: db "ENTER YOUR INITIALS",0
s_enter2: db "Q/A LETTER  FIRE NEXT",0

; ---------------------------------------------------------------------
; mission complete (between laps)
; ---------------------------------------------------------------------
ending_screen:
        call page_clear
        ld a,MODE1
        ld (latchbase),a
        ld hl,mus_ending_0
        ld de,mus_ending_1
        call play_music
        ld a,1
        ld b,2
        call set_ink
        ld a,1
        ld (txtdbl),a
        ld hl,s_mc
        ld e,4
        call print_c
        xor a
        ld (txtdbl),a
        ld a,0
        ld b,2
        call set_ink
        ld hl,end_lines
        call print_lines
        ld de,$5000
        call add_score
        call hud_score_end
        call blinds
        ld b,250
        call page_hold
        ld b,150
        call page_hold
        call stop_music
        ret
hud_score_end:
        ld a,3
        ld b,2
        call set_ink
        ld hl,score
        ld b,3
        ld de,13*256+46
        jp print_bcd
s_mc:   db "MISSION COMPLETE",0
end_lines:
        db 18,"THE MOTHERSHIP IS DUST AND",0
        db 24,"THE ENERMY FLEET IS SCATTERED.",0
        db 32,"BONUS 50000",0
        db 52,"BUT THE ENERMY RETURNS...",0
        db 58,"LAP 2 - FASTER AND MEANER",0
        db 255
