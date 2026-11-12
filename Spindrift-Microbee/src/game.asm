; =====================================================================
;  GAME: the run through the sectors, the player, the HUD, the stars,
;  and drawing a frame.
; =====================================================================
PH_INTRO    EQU 0
PH_PLAY     EQU 1
PH_CLEAR    EQU 2
PH_WARN     EQU 3
PH_BOSS     EQU 4
PH_BOSSEND  EQU 5
PH_BONUSI   EQU 6
PH_BONUS    EQU 7
PH_BONUSR   EQU 8
PH_OVER     EQU 9
PH_DONE     EQU 10

PR_ORBIT    EQU 224
NSTAR       EQU 18
NSECT       EQU 8

; ---------------------------------------------------------------------
new_game:
        xor a
        ld hl,score
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld (sector),a
        ld (lap),a
        ld (twin),a
        ld a,3
        ld (lives),a
        ; extra ships from 20 000 (BCD of points / 10)
        ld hl,next_life
        ld (hl),$00
        inc hl
        ld (hl),$20
        inc hl
        ld (hl),$00
        ld a,(demo)
        or a
        jr z,.nd
        ld a,1
        ld (lives),a
.nd:    call game_screen
        call player_spawn
        jp sector_start

; the play screen: HUD and an empty field
game_screen:
        call screen_reset
        call enemies_clear
        call stars_init
        ld a,(sector)
        call sector_ptr
        ld de,SC_HUD
        add hl,de
        ld a,(hl)
        ld (hudcol),a
        ld c,a
        ld hl,0
        ld de,t_score
        call print_s
        ld hl,15
        ld de,t_hi
        call print_s
        ld hl,28
        ld de,t_sector
        call print_s
        ld hl,24*40+8
        ld de,t_shield
        ld c,GREY
        call print_s
        ; mark the HUD rows so nothing is drawn over them
        ld hl,CELLHI
        ld b,40
.m:     ld (hl),TRASH >> 8
        set 2,h
        ld (hl),TRASH & 255
        res 2,h
        inc hl
        djnz .m
        ld hl,CELLHI+24*40
        ld b,40
.m2:    ld (hl),TRASH >> 8
        set 2,h
        ld (hl),TRASH & 255
        res 2,h
        inc hl
        djnz .m2
        ld a,$FF
        ld (hud_dirty),a
        xor a
        ld (msg_len),a
        ld (msg_len+1),a
        ld (msg_len+2),a
        call display_on
        ret

; A = sector -> HL = its record
sector_ptr:
        and 7
        ld l,a
        ld h,0
        add hl,hl
        ld de,sector_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

player_spawn:
        xor a
        ld (p_state),a
        ld (p_af),a
        ld (p_hitfl),a
        ld hl,0
        ld (p_v),hl
        ld a,3
        ld (p_shield),a
        ld a,60
        ld (p_inv),a
        ld a,(hudcol)
        ld a,$FF
        ld (hud_dirty),a
        ret

; ---------------------------------------------------------------------
; a sector begins: its name, the warp, then the first wave
; ---------------------------------------------------------------------
sector_start:
        ld a,(sector)
        call sector_ptr
        ld (sec_ptr),hl
        ld de,SC_STAR
        add hl,de
        ld a,(hl)
        ld (star_far),a
        inc hl
        ld a,(hl)
        ld (hudcol),a
        xor a
        ld (wave),a
        ld (wave_on),a
        ld (bossmode),a
        ld a,$FF
        ld (hud_dirty),a
        call msg_clear_all
        ; "SECTOR n" and the name
        ld de,t_sectorn
        ld hl,txtbuf
        call strcpy
        dec hl
        ld a,(sector)
        add a,'1'
        ld (hl),a
        inc hl
        ld (hl),0
        ld a,(lap)
        or a
        jr z,.nl
        ld (hl),'+'
        inc hl
        ld (hl),0
.nl:    ld de,txtbuf
        ld a,0
        ld c,WHITE
        call msg
        ld hl,(sec_ptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(hudcol)
        ld c,a
        ld a,1
        call msg
        ld a,PH_INTRO
        ld (phase),a
        ld a,75
        ld (ph_tim),a
        ld a,1
        ld (warp),a
        ld hl,sfx_warp
        ld a,7
        call play_sfx
        ld a,1
        ld (nodmg),a
        ld hl,tune_sector
        jp play_tune

; the next wave of this sector (or the Guardian)
next_wave:
        call msg_clear_all
        ld a,1
        ld (nodmg),a
        ld hl,(sec_ptr)
        ld de,SC_WAVE0
        add hl,de
        ld a,(wave)
        add a,a
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call wave_start
        call lap_harder
        ld a,PH_PLAY
        ld (phase),a
        ld hl,tune_wave
        jp play_tune

; the second time round, everything is fiercer
lap_harder:
        ld a,(lap)
        or a
        ret z
        ld a,(w_aint)
        sub 20
        cp 30
        jr nc,.a
        ld a,30
.a:     ld (w_aint),a
        ld a,(w_amax)
        inc a
        ld (w_amax),a
        ld a,(w_fire)
        add a,60
        jr nc,.f
        ld a,$F0
.f:     ld (w_fire),a
        ld a,(w_bspd)
        add a,12
        ld (w_bspd),a
        ld a,(w_ffire)
        add a,2
        ld (w_ffire),a
        ld a,2
        ld (w_home),a
        ret

; ---------------------------------------------------------------------
; the phases
; ---------------------------------------------------------------------
phase_update:
        ld hl,ph_tim
        ld a,(hl)
        or a
        jr z,.t
        dec (hl)
.t:     ld a,(phase)
        add a,a
        ld l,a
        ld h,0
        ld de,.tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
.tab:   dw ph_intro,ph_play,ph_clear,ph_warn,ph_boss,ph_bossend
        dw ph_bonusi,ph_bonus,ph_bonusr,ph_over,ph_none

ph_none:
        ret

ph_intro:
        ld a,(ph_tim)
        cp 25
        jr nz,.w
        xor a
        ld (warp),a
.w:     or a
        ret nz
        jp next_wave

ph_play:
        call wave_update
        call wave_done
        ret nz
        xor a
        ld (wave_on),a
        ; wave clear
        ld de,t_clear
        ld a,0
        ld c,WHITE
        call msg
        ld a,(nodmg)
        or a
        jr z,.nb
        ld de,t_nodmg
        ld a,1
        ld c,BGREEN
        call msg
        ld de,$0200             ; 2000 points
        ld a,(sector)
        cp 4
        jr c,.s
        ld de,$0400
.s:     call add_score
.nb:    ; a shield segment back
        ld a,(p_state)
        or a
        jr nz,.ns
        ld a,(p_shield)
        cp 3
        jr nc,.ns
        inc a
        ld (p_shield),a
        ld a,$FF
        ld (hud_dirty),a
.ns:    ld a,PH_CLEAR
        ld (phase),a
        ld a,60
        ld (ph_tim),a
        ld hl,tune_clear
        jp force_tune_if

ph_clear:
        ld a,(ph_tim)
        or a
        ret nz
        ld a,(p_state)
        or a
        ret nz                  ; wait for the player to be back
        call msg_clear_all
        ld hl,wave
        inc (hl)
        ld a,(hl)
        cp 2
        jp c,next_wave
        ; both waves done: the Guardian on even sectors
        ld hl,(sec_ptr)
        ld de,SC_BOSS
        add hl,de
        ld a,(hl)
        cp $FF
        jp z,sector_next
        ld (boss_id),a
        ld de,t_warning
        xor a
        ld c,BRED
        call msg
        ld de,t_guardian
        ld a,1
        ld c,YELLOW
        call msg
        ld a,PH_WARN
        ld (phase),a
        ld a,80
        ld (ph_tim),a
        call snd_off
        ld hl,sfx_siren
        ld a,7
        jp play_sfx

ph_warn:
        ld a,(ph_tim)
        and 15
        jr nz,.n
        ld a,BRED
        call flash
.n:     ld a,(ph_tim)
        or a
        ret nz
        call msg_clear_all
        call boss_start
        ld a,PH_BOSS
        ld (phase),a
        ld hl,tune_boss
        jp play_tune

ph_boss:
        call wave_update
        call boss_update
        ld a,(boss_alive)
        or a
        ret nz
        ld a,PH_BOSSEND
        ld (phase),a
        ld a,70
        ld (ph_tim),a
        ret

ph_bossend:
        call wave_update
        call boss_dying
        ld a,(ph_tim)
        or a
        ret nz
        ld a,(p_state)
        or a
        ret nz
        ld a,(nenemy)
        or a
        ret nz
        xor a
        ld (bossmode),a
        ; the Guardian's gift: the twin cannon
        ld a,1
        ld (twin),a
        ld de,t_chance
        xor a
        ld c,BMAGENTA
        call msg
        ld de,t_chance2
        ld a,1
        ld c,WHITE
        call msg
        ld a,PH_BONUSI
        ld (phase),a
        ld a,70
        ld (ph_tim),a
        ld hl,tune_bonus
        jp play_tune

ph_bonusi:
        ld a,(ph_tim)
        or a
        ret nz
        call msg_clear_all
        xor a
        ld (bonus_hits),a
        ld (bonus_shots),a
        ld hl,wave_bonus
        call wave_start
        ld a,PH_BONUS
        ld (phase),a
        ret

ph_bonus:
        call wave_update
        call wave_done
        ret nz
        xor a
        ld (wave_on),a
        ; the results
        ld hl,txtbuf
        ld de,t_hits
        call strcpy
        dec hl
        ex de,hl
        ld a,(bonus_hits)
        call dec2
        ex de,hl
        ld de,t_of40
        call strcpy
        ld de,txtbuf
        xor a
        ld c,WHITE
        call msg
        ; 100 a hit, 10 000 for all forty
        ld a,(bonus_hits)
        ld b,a
        ld de,0
        or a
        jr z,.z
.h:     ld a,e
        add a,$10
        daa
        ld e,a
        ld a,d
        adc a,0
        daa
        ld d,a
        djnz .h
.z:     call add_score
        ld a,(bonus_hits)
        cp 40
        jr c,.np
        ld de,t_perfect
        ld a,1
        ld c,YELLOW
        call msg
        ld de,$1000
        call add_score
        ld a,WHITE
        call flash
        ld hl,sfx_life
        ld a,7
        call play_sfx
.np:    ld a,PH_BONUSR
        ld (phase),a
        ld a,90
        ld (ph_tim),a
        ret

ph_bonusr:
        ld a,(ph_tim)
        or a
        ret nz
        jp sector_next

sector_next:
        call msg_clear_all
        ld a,(sector)
        inc a
        cp NSECT
        jr c,.s
        ; round again, fiercer
        ld hl,lap
        inc (hl)
        xor a
.s:     ld (sector),a
        jp sector_start

ph_over:
        ld a,(ph_tim)
        or a
        ret nz
        ld a,PH_DONE
        ld (phase),a
        ret

game_over:
        call msg_clear_all
        ld de,t_gameover
        xor a
        ld c,BRED
        call msg
        ld a,PH_OVER
        ld (phase),a
        ld a,100
        ld (ph_tim),a
        xor a
        ld (wave_on),a
        ld hl,tune_over
        jp force_tune_if

force_tune_if:
        ld a,(sndmode)
        cp 2
        ret c
        jp force_tune

; ---------------------------------------------------------------------
; messages, centred on rows 9, 11 and 13 (A = 0, 1, 2), DE = text
; ---------------------------------------------------------------------
msg:    push bc
        push de
        push af
        call msg_clear
        ld b,0
.n:     ld a,(de)
        or a
        jr z,.l
        inc de
        inc b
        jr .n
.l:     pop af
        push af
        ld e,a
        ld d,0
        ld hl,msg_len
        add hl,de
        ld (hl),b
        pop af
        call msg_cell
        pop de
        pop bc
        jp print_q

; A = message row -> HL = its first cell (centred by msg_len)
msg_cell:
        push de
        push bc
        ld e,a
        ld d,0
        ld hl,msg_len
        add hl,de
        ld a,40
        sub (hl)
        srl a
        ld c,a
        ld a,e
        add a,a
        add a,9
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld b,0
        add hl,bc
        pop bc
        pop de
        ret

msg_clear:
        push bc
        push de
        push af
        ld e,a
        ld d,0
        ld hl,msg_len
        add hl,de
        ld a,(hl)
        or a
        jr z,.x
        ld b,a
        ld a,e
        call msg_cell
        call clear_q
        ld hl,msg_len
        add hl,de
        ld (hl),0
.x:     pop af
        pop de
        pop bc
        ret

msg_clear_all:
        xor a
        call msg_clear
        ld a,1
        call msg_clear
        ld a,2
        jp msg_clear

; DE = source (0 ends), HL = destination -> HL past the 0
strcpy: ld a,(de)
        ld (hl),a
        inc de
        inc hl
        or a
        jr nz,strcpy
        ret

; ---------------------------------------------------------------------
; the player
; ---------------------------------------------------------------------
; the angle each stick direction points the ship to (pad bits R L U D)
dirtab: db $FF,64,192,$FF,128,96,160,128,0,32,224,0,$FF,64,192,$FF

player_update:
        ld a,(p_state)
        or a
        jp nz,.dead
        ld hl,p_inv
        ld a,(hl)
        or a
        jr z,.i
        dec (hl)
.i:     ld hl,p_hitfl
        ld a,(hl)
        or a
        jr z,.h
        dec (hl)
.h:     ld a,(ipad)
        ld c,0                  ; direction: -1 clockwise, +1 anticlockwise
        bit PAD_CW,a
        jr z,.c1
        dec c
.c1:    bit PAD_ACW,a
        jr z,.c2
        inc c
.c2:    ld b,0                  ; near the target
        ld a,c
        or a
        jr nz,.go
        ld a,(ipad)
        and 15
        ld e,a
        ld d,0
        ld hl,dirtab
        add hl,de
        ld a,(hl)
        cp $FF
        jr z,.go
        ld e,a
        ld hl,p_a
        sub (hl)
        ld d,a                  ; signed difference
        call absa
        cp 5
        jr nc,.far
        ld (hl),e               ; there: settle on it
        xor a
        ld (p_af),a
        jr .go
.far:   cp 14
        jr nc,.f2
        inc b
.f2:    ld c,1
        bit 7,d
        jr z,.go
        ld c,-1
.go:    ; speed
        ld hl,(p_v)
        ld a,c
        or a
        jr nz,.mv
        ld hl,0
        jr .sv
.mv:    bit 7,c
        jr nz,.neg
        ; anticlockwise: start at 1.5, gain 0.75 a frame, up to 4.5
        bit 7,h
        jr nz,.ps
        ld a,h
        or l
        jr z,.ps
        ld de,$00C0
        add hl,de
        ld de,$0480
        call clamp_up
        jr .near
.ps:    ld hl,$0180
        jr .near
.neg:   bit 7,h
        jr z,.ns
        ld de,-$00C0
        add hl,de
        ld de,-$0480
        call clamp_dn
        jr .near
.ns:    ld hl,-$0180
.near:  ld a,b
        or a
        jr z,.sv
        ; close to the target: no faster than 2
        bit 7,h
        jr nz,.nn
        ld de,$0200
        call clamp_up
        jr .sv
.nn:    ld de,-$0200
        call clamp_dn
.sv:    ld (p_v),hl
        ex de,hl
        ld hl,(p_af)
        add hl,de
        ld (p_af),hl
        ; where
        ld a,MP_TAB
        out (P_MEM),a
        ld a,(p_a)
        ld b,PR_ORBIT
        call polar
        ld (p_x),hl
        ld a,c
        ld (p_y),a
        ; fire
        ld hl,p_fcd
        ld a,(hl)
        or a
        jr z,.f
        dec (hl)
.f:     ld a,(ipadnew)
        and 16
        jr nz,.shoot
        ld a,(ipad)
        and 16
        ret z
        ld a,(hl)
        or a
        ret nz
.shoot: ld (hl),4
        ld a,(twin)
        or a
        jr nz,.two
        ld a,(p_a)
        call shot_new
        jr .snd
.two:   ld a,(p_a)
        sub 3
        call shot_new
        ld a,(p_a)
        add a,3
        call shot_new
.snd:   ld hl,sfx_shot
        ld a,1
        jp play_sfx
.dead:  ld hl,p_tim
        dec (hl)
        ret nz
        ld a,(lives)
        or a
        jp z,game_over
        call bullets_clear
        jp player_spawn

; HL = signed speed, DE = limit: HL = min(HL, DE) (positive side)
clamp_up:
        push hl
        or a
        sbc hl,de
        pop hl
        ret m
        ex de,hl
        ret
clamp_dn:
        push hl
        or a
        sbc hl,de
        pop hl
        ret p
        ex de,hl
        ret

; A = angle: a shot from the orbit inward
shot_new:
        ld c,a
        ld hl,SHOTS
        ld de,8
        ld b,NSHOT
.f:     ld a,(hl)
        or a
        jr z,.g
        add hl,de
        djnz .f
        ret
.g:     ld (hl),1
        inc hl
        ld (hl),c
        inc hl
        ld (hl),PR_ORBIT-12
        ld de,4
        add hl,de
        ld (hl),PR_ORBIT-12
        ld hl,bonus_shots
        inc (hl)
        ret

player_hit:
        ld a,(demo)
        or a
        jr nz,.d
        xor a
        ld (nodmg),a
.d:     ld a,$FF
        ld (hud_dirty),a
        ld hl,p_shield
        dec (hl)
        jr z,.die
        ld a,RED
        call flash
        ld a,50
        ld (p_inv),a
        ld a,8
        ld (p_hitfl),a
        ld hl,sfx_shield
        ld a,6
        jp play_sfx
.die:   ld a,1
        ld (p_state),a
        ld a,75
        ld (p_tim),a
        ld hl,lives
        dec (hl)
        ld a,(demo)
        or a
        jr z,.nd
        ld (hl),0
.nd:    ld a,WHITE
        call flash
        ld hl,(p_x)
        ld a,(p_y)
        ld b,a
        ld a,5
        ld c,YELLOW
        call fx_new
        ld hl,(p_x)
        ld de,8
        add hl,de
        ld a,(p_y)
        sub 6
        ld b,a
        ld a,3
        ld c,WHITE
        call fx_new
        ld hl,(p_x)
        ld de,-8
        add hl,de
        ld a,(p_y)
        add a,5
        ld b,a
        ld a,3
        ld c,BRED
        call fx_new
        ld hl,sfx_die
        ld a,8
        jp play_sfx

; ---------------------------------------------------------------------
; stars stream out of the vanishing point
; ---------------------------------------------------------------------
stars_init:
        ld ix,stars
        ld b,NSTAR
.l:     push bc
        call star_new
        call random
        ld (ix+2),a             ; anywhere along the way to begin with
        ld de,5
        add ix,de
        pop bc
        djnz .l
        ret

; IX = star: a new one near the vanishing point
star_new:
        call random
        ld (ix+0),a
        ld (ix+1),0
        call random
        and 15
        add a,4
        ld (ix+2),a
        call random
        and $7F
        add a,$80               ; 0.5 - 1 a frame (depth is already in
        ld (ix+3),a             ; perspective: they speed up outward)
        ld (ix+4),0
        ret

stars_update:
        ld ix,stars
        ld b,NSTAR
.l:     ld e,(ix+3)
        ld d,(ix+4)
        ld a,(warp)
        or a
        jr z,.w
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
.w:     ld l,(ix+1)
        ld h,(ix+2)
        add hl,de
        jr c,.new
        ld a,h
        cp 250
        jr nc,.new
        ld (ix+1),l
        ld (ix+2),h
        jr .n
.new:   push bc
        call star_new
        pop bc
.n:     ld de,5
        add ix,de
        djnz .l
        ret

stars_draw:
        ld a,MP_TAB
        out (P_MEM),a
        ld ix,stars
        ld b,NSTAR
.l:     push bc
        ld a,(ix+0)
        ld b,(ix+2)
        call polar
        ld a,(ix+2)
        ld b,DGREY
        cp 80
        jr c,.c
        ld a,(star_far)
        ld b,a
        ld a,(ix+2)
        cp 170
        jr c,.c
        ld b,WHITE
.c:     ld a,(warp)
        or a
        jr z,.nw
        ld b,WHITE
.nw:    ld a,b
        push hl
        ld hl,colmap
        add a,l
        ld l,a
        jr nc,.cm
        inc h
.cm:    ld b,(hl)
        pop hl
        call star_cell
        ld de,5
        add ix,de
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; the HUD
; ---------------------------------------------------------------------
hud_update:
        ld a,(hud_dirty)
        or a
        ret z
        ld b,a
        xor a
        ld (hud_dirty),a
        push bc
        ld hl,score
        ld de,txtbuf
        call bcd_text
        ld hl,6
        ld de,txtbuf
        ld c,WHITE
        call print_q
        pop bc
        ld a,b
        and $FC
        jr nz,.full
        bit 1,b                 ; the Guardian's health only
        ret z
        ld a,(bossmode)
        or a
        ret z
        jp boss_bar
.full:
        ld hl,hiscore
        ld de,txtbuf
        call bcd_text
        ld hl,18
        ld de,txtbuf
        ld c,YELLOW
        call print_q
        ; sector
        ld a,(sector)
        add a,'1'
        ld (txtbuf),a
        ld a,(lap)
        or a
        ld a,' '
        jr z,.l
        ld a,'+'
.l:     ld (txtbuf+1),a
        xor a
        ld (txtbuf+2),a
        ld hl,35
        ld de,txtbuf
        ld c,WHITE
        call print_q
        ; ships in reserve
        ld hl,24*40
        ld a,(lives)
        ld c,a
        ld b,6
.sh:    ld a,c
        or a
        ld a,$80+64
        jr nz,.s1
        ld a,$80
.s1:    push bc
        ld b,BK_FONT
        ld c,BCYAN
        call tq_put
        pop bc
        ld a,c
        or a
        jr z,.s2
        dec c
.s2:    inc hl
        djnz .sh
        ; the shield
        ld hl,24*40+15
        ld a,(p_shield)
        ld c,BGREEN
        cp 2
        jr nc,.pc
        ld c,BRED
.pc:    ld e,a
        ld b,3
.p:     ld a,e
        or a
        ld a,$80+65
        jr nz,.p1
        ld a,$80+66
.p1:    push bc
        ld b,BK_FONT
        call tq_put
        pop bc
        ld a,e
        or a
        jr z,.p3
        dec e
.p3:    inc hl
        djnz .p
        ld a,(bossmode)
        or a
        jp nz,boss_bar
        ; the sector's name, right-aligned (over spaces)
        ld hl,24*40+19
        ld de,t_spaces
        ld c,WHITE
        call print_q
        ld hl,(sec_ptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de
        ld b,0
.nl:    ld a,(de)
        or a
        jr z,.ne
        inc de
        inc b
        jr .nl
.ne:    pop de
        ld a,40
        sub b
        ld l,a
        ld h,0
        ld bc,24*40
        add hl,bc
        ld a,(hudcol)
        ld c,a
        jp print_q

; ---------------------------------------------------------------------
; drawing a frame. The first thing to claim a cell gives it its colour:
; the ship, then enemy fire, then shots, then enemies, then the rest.
; ---------------------------------------------------------------------
draw_all:
        call frame_begin
        ld a,MP_TAB
        out (P_MEM),a
        ; the ship
        ld a,(p_state)
        or a
        jr nz,.noship
        ld a,(p_hitfl)
        or a
        ld a,BRED
        jr nz,.sc
        ld a,(p_inv)
        and 4
        ld a,BCYAN
        jr z,.sc
        ld a,WHITE
.sc:    call setcol
        ld a,(p_a)
        add a,4
        rrca
        rrca
        and $3E
        ld l,a
        ld h,0
        ld de,rec_ship
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,(p_x)
        ld a,(p_y)
        ld c,a
        call draw_spr
.noship:
        ; enemy fire
        ld a,(frameno)
        and 2
        ld a,WHITE
        jr z,.bc
        ld a,BMAGENTA
.bc:    call setcol
        ld ix,BULLETS
        ld b,NBUL
.bl:    push bc
        bit 0,(ix+B_ST)
        jr z,.bn
        ld a,(ix+B_R)
        ld c,0
        cp 120
        jr c,.bs
        ld c,2
        cp 180
        jr c,.bs
        ld c,4
.bs:    ld a,(frameno)
        rrca
        and 1
        add a,c
        add a,a
        ld l,a
        ld h,0
        ld de,rec_bul
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,(ix+B_XL)
        ld d,(ix+B_XH)
        ld c,(ix+B_Y)
        call draw_spr
.bn:    ld de,BSIZE
        add ix,de
        pop bc
        djnz .bl
        ; shots
        ld a,YELLOW
        call setcol
        ld ix,SHOTS
        ld b,NSHOT
.sl:    push bc
        ld a,(ix+S_ST)
        or a
        jr z,.sn
        ld a,(ix+S_R)
        ld c,0
        cp 150
        jr nc,.ss
        inc c
        cp 80
        jr nc,.ss
        inc c
.ss:    ld a,c
        add a,a
        ld l,a
        ld h,0
        ld de,rec_shot
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,(ix+S_XL)
        ld d,(ix+S_XH)
        ld c,(ix+S_Y)
        call draw_spr
.sn:    ld de,8
        add ix,de
        pop bc
        djnz .sl
        ; enemies and the Guardian
        ld a,MP_ENM
        out (P_MEM),a
        ld a,(bossmode)
        or a
        call nz,boss_draw
        ld ix,ENEMY
        ld b,NENEMY
.el:    push bc
        ld a,(ix+E_ST)
        or a
        call nz,draw_enemy
        ld de,ESIZE
        add ix,de
        pop bc
        djnz .el
        ; popups
        ld ix,POPS
        ld b,NPOPS
.pl:    push bc
        ld a,(ix+O_T)
        or a
        jr z,.pn
        ld a,(ix+O_COL)
        call setcol
        ld a,(ix+O_REC)
        add a,a
        ld l,a
        ld h,0
        ld de,rec_pop
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,(ix+O_XL)
        ld d,(ix+O_XH)
        ld c,(ix+O_Y)
        call draw_spr
.pn:    ld de,8
        add ix,de
        pop bc
        djnz .pl
        ; explosions
        ld ix,FX
        ld b,NFX
.xl:    push bc
        ld a,(ix+X_T)
        or a
        jr z,.xn
        ; frame = (12 - t) / 3: white hot, yellow, then its own colour
        ld c,a
        ld a,12
        sub c
        ld e,-1
.d3:    inc e
        sub 3
        jr nc,.d3
        ld a,e
        ld c,WHITE
        or a
        jr z,.xc
        ld c,YELLOW
        dec a
        jr z,.xc
        ld c,(ix+X_COL)
.xc:    ld a,c
        call setcol
        ld a,e
        ld c,a
        add a,a
        add a,c                 ; frame * 3
        add a,(ix+X_SZ)
        add a,a
        ld l,a
        ld h,0
        ld de,rec_boom
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,(ix+X_XL)
        ld d,(ix+X_XH)
        ld c,(ix+X_Y)
        call draw_spr
.xn:    ld de,8
        add ix,de
        pop bc
        djnz .xl
        jp stars_draw

; IX = enemy (BLK_ENM mapped)
draw_enemy:
        ; colour: bright near, dim far; white while warning or hit
        ld a,(ix+E_HIT)
        or a
        jr nz,.white
        ld a,(ix+E_WARN)
        and 2
        jr nz,.white
        ld a,(ix+E_COL)
        ld c,a
        ld a,(ix+E_SZ)
        cp 2
        ld a,c
        jr nc,.br
        rrca
        rrca
        rrca
        rrca
.br:    and 15
        jr .sc
.white: ld a,WHITE
.sc:    call setcol
        ld a,(frameno)
        rrca
        rrca
        rrca
        add a,(ix+E_ANIM)
        and 1
        ld c,a
        ld a,(ix+E_TYPE)
        add a,a
        add a,c                 ; type * 2 + frame
        ld c,a
        add a,a
        add a,c
        add a,a                 ; * 6
        add a,(ix+E_SZ)
        ld l,a
        ld h,0
        add hl,hl
        ld de,rec_enm
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,(ix+E_XL)
        ld d,(ix+E_XH)
        ld c,(ix+E_Y)
        jp draw_spr
