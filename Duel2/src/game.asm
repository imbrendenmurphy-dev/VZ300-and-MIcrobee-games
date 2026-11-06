; =====================================================================
;  DUEL II - the dogfight: planes, guns, AI aces, balloons, hazards,
;  rounds and duels
; =====================================================================

; ---- plane record (IX)
P_X     equ 0           ; 8.8 pixels (0..127)
P_Y     equ 2           ; 8.8 arena rows (0..57)
P_HEAD  equ 4           ; 0..15, 0 = up, clockwise
P_LEVEL equ 5           ; throttle 0..5
P_HP    equ 6
P_STATE equ 7           ; 0 gone, 1 flying, 2 going down, 3 bailed out
P_TURNT equ 8
P_THRT  equ 9
P_FIRET equ 10
P_FRAME equ 11          ; FR_P1_0 or FR_P2_0
P_CTL   equ 12          ; 0 pad1, 1 pad2, 2 computer
P_PAD   equ 13
P_PWR   equ 14          ; 0 none, 1 twin guns, 2 turbo
P_PWRT  equ 15          ; 16-bit
P_FLASH equ 17
P_SMOKET equ 18
P_FALLT equ 19
P_THINK equ 20
P_TURND equ 21
P_COL   equ 22          ; physical colour (bullets, HUD)
P_WINS  equ 23
P_ID    equ 24
P_BREAK equ 25
P_BRDIR equ 26
P_COLLT equ 27
P_VX    equ 28
P_VY    equ 30
P_HITS  equ 32
P_SHIELD equ 33         ; 16-bit
P_AIM   equ 35          ; ai: heading error allowed when firing
P_EVAD  equ 36          ; ai: evade chance /256
P_MAXL  equ 37          ; ai: top throttle
P_HIDE  equ 38          ; ai: hides in clouds
P_THINKD equ 39         ; ai: frames between decisions
P_LEAD  equ 40          ; ai: leads the target
P_WOB   equ 41          ; ai: hesitation chance /256
PSIZE   equ 42

; ---- bullets
BU_X    equ 0
BU_Y    equ 2
BU_VX   equ 4
BU_VY   equ 6
BU_LIFE equ 8
BU_OWN  equ 9
BU_COL  equ 10
BUSIZE  equ 11
NBUL    equ 14
; ---- particles
PA_X    equ 0
PA_Y    equ 2
PA_VX   equ 4
PA_VY   equ 6
PA_LIFE equ 8
PA_COL  equ 9
PASIZE  equ 10
NPART   equ 28
; ---- sprite effects
FX_X    equ 0
FX_Y    equ 1
FX_FR   equ 2
FX_T    equ 3
FX_KIND equ 4
FXSIZE  equ 5
NFX     equ 5
; ---- balloons
BA_X    equ 0
BA_Y    equ 2
BA_VX   equ 4
BA_VY   equ 6
BA_ON   equ 8
BA_T    equ 9
BASIZE  equ 10
NBAL    equ 6

TH_SIZE equ 16

; =====================================================================
;  THEATRES
; =====================================================================
; css, map L0..L3, cloud logical colour, clouds, wind, hazard,
; dw backdrop, dw name, balloons, heading step, spare
theatres:
        db 0,      0,1,2,3, 1, 4,  10, 0 : dw bd_meadow, tn0 : db 1,1,0
        db CSS1,   1,0,2,3, 1, 5, -18, 0 : dw bd_ocean,  tn1 : db 1,1,0
        db CSS1,   3,0,2,1, 1, 4,  14, 1 : dw bd_desert, tn2 : db 1,1,0
        db 0,      2,1,3,0, 3, 5, -10, 2 : dw bd_night,  tn3 : db 1,1,0
        db 0,      0,1,2,3, 1, 6,   7, 0 : dw bd_classic,tn4 : db 0,2,0
tn0:    db "THE MEADOWS",0
tn1:    db "THE OCEAN",0
tn2:    db "THE DESERT",0
tn3:    db "NIGHT STORM",0
tn4:    db "CLASSIC 1984",0
theatre_names: dw tn0,tn1,tn2,tn3,tn4

; set_theatre: A = theatre. Palette, colours, backdrop into BBUF,
; sprites rebuilt, clouds placed. (Display untouched until show_b.)
set_theatre:
        ld (theatre),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,theatres
        add hl,de
        ld de,th_rec
        ld bc,TH_SIZE
        ldir
        ld a,(th_rec)
        ld (palbase),a
        ld hl,th_rec+1
        ld de,tmap
        ld bc,4
        ldir
        call build_frames
        ; colour helpers
        ld a,(tmap+1)
        ld (col1),a
        ld a,(tmap+2)
        ld (col2),a
        ld a,(tmap+3)
        ld (col3),a
        ld a,(tmap)
        ld (col0),a
        ld a,(th_rec+5)
        call phys_fill
        ld (cloudfill),a
        ld a,(tmap+3)
        call fillbyte
        ld (accfill),a
        jp load_backdrop
load_backdrop:  ; backdrop: unpack logical, recolour; fresh clouds
        ld a,(tmap)
        call fillbyte
        call cls_b
        ld hl,(th_rec+9)
        ld de,BBUF+ARENA_TOP*32
        call unpack
        ld hl,BBUF+ARENA_TOP*32
        ld bc,ARENA_H*32
.rc:    ld e,(hl)
        ld d,RMAP0/256
        ld a,(de)
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.rc
        ; clouds
        ld a,(th_rec+7)
        ld l,a
        rla
        sbc a,a
        ld h,a
        ld (wind),hl
        call place_clouds
        ret

; A = logical colour -> A = physical fill byte
phys_fill:
        ld hl,tmap
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
fillbyte:               ; A = physical colour 0..3 -> byte of 4 pixels
        and 3
        ld b,a
        add a,a
        add a,a
        or b
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,a
        or b
        ret

; clouds spread over the arena: one per band of rows, random x/shape
place_clouds:
        ld hl,clouds
        ld de,clouds+1
        ld bc,MAXCL*CL_SIZE-1
        ld (hl),0
        ldir
        ld a,(th_rec+6)
        ld (ncl),a
        ld ix,clouds
        xor a
        ld (tmpa),a
.c:     ld a,(ncl)
        ld b,a
        ld a,(tmpa)
        cp b
        ret nc
        ld (ix+CL_ON),1
        ld a,(cloudfill)
        ld (ix+CL_FILL),a
        ; y: band = i * (58 / n) + small random
        ld a,(ncl)
        ld c,a
        ld a,ARENA_H
        ld b,0
.dv:    cp c
        jr c,.dv2
        sub c
        inc b
        jr .dv
.dv2:   ld a,(tmpa)
        ld c,a
        xor a
.ml:    inc c
        dec c
        jr z,.ml2
        add a,b
        dec c
        jr .ml
.ml2:   ld b,a
.dd:    push bc
        ld b,6
        call rand_n
        pop bc
        add a,b
        call wrap_y
        ld (ix+CL_Y),a
        call random
        and 127
        ld (ix+CL_X+1),a
        ; shape: classic uses the little puffs
        ld a,(theatre)
        cp 4
        jr nz,.sh
        ld a,(tmpa)
        and 1
        add a,a
        add a,2
        jr .sh2
.sh:    ld b,4
        call rand_n
.sh2:   ld (ix+CL_SHAPE),a
        ; own drift: -12..+12 /256 px per frame
        ld b,25
        call rand_n
        sub 12
        ld (ix+CL_VX),a
        rla
        sbc a,a
        ld (ix+CL_VX+1),a
        ld de,CL_SIZE
        add ix,de
        ld a,(tmpa)
        inc a
        ld (tmpa),a
        jr .c

; =====================================================================
;  HUD (rows 0..5 of the backdrop)
; =====================================================================
draw_hud:
        xor a
        ld (hud_dirty),a
        ld a,(mode)
        cp MODE_TITLE
        ret z
        call to_b
        ld a,(col0)
        call fillbyte
        ld de,0
        ld bc,$2005
        call fill_rect
        ; separator: dotted accent line on row 5
        ld a,(col3)
        call fillbyte
        and $33
        ld c,a
        ld a,(col0)
        call fillbyte
        and $CC
        or c
        ld hl,BBUF+5*32
        ld b,32
.sp:    ld (hl),a
        inc hl
        djnz .sp
        ; pips
        ld ix,pl0
        ld c,1
        ld b,0
        call hud_pips
        ld ix,pl1
        ld c,125
        ld b,1
        call hud_pips
        ; centre
        ld a,(col1)
        ld b,a
        ld a,(col0)
        ld b,a
        ld a,(col3)
        call set_ink
        ld a,(mode)
        cp MODE_CAMP
        jr z,.camp
        cp MODE_BONUS
        jr z,.bonus
        ; two players / demo: wins  "1 - 0"
        ld a,(col1)
        ld b,a
        ld a,(col0)
        ld b,a
        ld a,(col1)
        call set_ink
        ld a,(pl0+P_WINS)
        add a,'0'
        ld de,$0D00
        call putchar
        ld a,(col3)
        ld b,0
        ld a,(col0)
        ld b,a
        ld a,(col3)
        call set_ink
        ld hl,s_dash
        ld de,$0E00
        call print
        ld a,(col0)
        ld b,a
        ld a,(col2)
        call set_ink
        ld a,(pl1+P_WINS)
        add a,'0'
        ld de,$1200
        call putchar
        jr .done
.camp:  ld hl,score
        ld b,3
        ld de,$0D00
        call print_bcd
        ld a,(col0)
        ld b,a
        ld a,(col1)
        call set_ink
        ld a,(pl0+P_WINS)
        add a,'0'
        ld de,$0B00
        call putchar
        ld a,(col0)
        ld b,a
        ld a,(col2)
        call set_ink
        ld a,(pl1+P_WINS)
        add a,'0'
        ld de,$1400
        call putchar
        jr .done
.bonus: ld hl,score
        ld b,3
        ld de,$0D00
        call print_bcd
        ld a,(col0)
        ld b,a
        ld a,(col1)
        call set_ink
        ld a,(bn_secs)
        ld de,$0200
        call print_dec2
        ld a,(bn_got)
        ld de,$1C00
        call print_dec2
.done:  ld de,0
        ld c,6
        jp b2f_rows
s_dash: db " - ",0
; pips: IX plane, C = x of first pip, B = direction (0 right, 1 left)
hud_pips:  ld a,b
        ld (tmpb),a
        ld a,c
        ld (tmpx),a
        ld a,(mode)
        cp MODE_BONUS
        ret z
        xor a
        ld (tmpa),a
.pl:    ld a,(tmpa)
        ld b,a
        ld a,(ix+P_HP)
        cp b
        jr z,.lost
        jr c,.lost
        ld a,(ix+P_COL)
        ld e,a
        ld a,(tmpx)
        ld b,a
        ld c,1
        call hplot2
        ld c,2
        call hplot2
        ld c,3
        call hplot2
        jr .pn
.lost:  ld a,(col3)
        ld e,a
        ld a,(tmpx)
        ld b,a
        ld c,2
        call hplot
.pn:    ld a,(tmpb)
        or a
        ld a,(tmpx)
        jr nz,.left
        add a,3
        jr .px
.left:  sub 3
.px:    ld (tmpx),a
        ld a,(tmpa)
        inc a
        ld (tmpa),a
        cp 15
        jr nz,.pl
        ret
; two pixels at B,C (screen row) colour E into BBUF
hplot2: push bc
        call hplot
        pop bc
        push bc
        inc b
        call hplot
        pop bc
        ret
hplot:  push de
        ld a,b
        rrca
        rrca
        and 31
        ld d,a
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or d
        ld l,a
        ld a,h
        add a,BBUF/256
        ld h,a
        ld a,b
        and 3
        ld c,a
        ld a,3
        sub c
        ld d,e
        jr z,.s0
.sh:    rlc d
        rlc d
        dec a
        jr nz,.sh
.s0:    push hl
        ld hl,pixtab
        ld a,c
        add a,l
        ld l,a
        ld a,(hl)
        pop hl
        and (hl)
        or d
        ld (hl),a
        pop de
        ret

; =====================================================================
;  ROUND / DUEL SET-UP
; =====================================================================
; init_plane: IX, A = id (0/1)
init_plane:
        push af
        push ix
        pop hl
        ld d,h
        ld e,l
        inc de
        ld bc,PSIZE-1
        ld (hl),0
        ldir
        pop af
        ld (ix+P_ID),a
        ld (ix+P_STATE),1
        ld (ix+P_HP),15
        ld (ix+P_LEVEL),2
        ld (ix+P_TURND),3
        ld (ix+P_TURNT),1
        ld (ix+P_THRT),1
        or a
        jr nz,.p2
        ld (ix+P_Y+1),14
        ld (ix+P_X+1),24
        ld (ix+P_HEAD),4
        ld (ix+P_FRAME),FR_P1_0
        ld a,(col1)
        ld (ix+P_COL),a
        ret
.p2:    ld (ix+P_Y+1),43
        ld (ix+P_X+1),104
        ld (ix+P_HEAD),12
        ld (ix+P_FRAME),FR_P2_0
        ld a,(col2)
        ld (ix+P_COL),a
        ret

; ai_setup: IX = plane, A = ace number 0..7 (copies the ace's style)
ai_setup:
        ld (ix+P_CTL),2
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,ace_style
        add hl,de
        ld a,(hl)
        ld (ix+P_TURND),a
        inc hl
        ld a,(hl)
        ld (ix+P_THINKD),a
        inc hl
        ld a,(hl)
        ld (ix+P_AIM),a
        inc hl
        ld a,(hl)
        ld (ix+P_EVAD),a
        inc hl
        ld a,(hl)
        ld (ix+P_MAXL),a
        inc hl
        ld a,(hl)
        ld (ix+P_HIDE),a
        inc hl
        ld a,(hl)
        ld (ix+P_LEAD),a
        inc hl
        ld a,(hl)
        ld (ix+P_WOB),a
        ret
; turn delay, think delay, aim, evade, top throttle, hides, leads, hesitates
ace_style:
        db 5, 8, 0,  10, 3, 0, 0, 70     ; Rookie Rudy
        db 4, 7, 1,  20, 4, 0, 0, 50     ; Farmer Fritz
        db 4, 6, 1,  50, 4, 0, 1, 40     ; Salty Sue
        db 4, 5, 1,  40, 5, 0, 1, 30     ; Captain Kraken
        db 3, 5, 1,  80, 5, 0, 1, 26     ; Dune Raider
        db 3, 4, 0, 110, 5, 0, 1, 18     ; Scorpion
        db 3, 3, 0, 140, 5, 1, 1, 12     ; Night Owl
        db 2, 3, 0, 170, 5, 1, 1, 6      ; The Phantom
        db 4, 6, 1,  60, 4, 0, 1, 30     ; demo / title pilots

; start_round: planes in place, everything else cleared
start_round:
        ld hl,bullets
        ld de,bullets+1
        ld bc,NBUL*BUSIZE-1
        ld (hl),0
        ldir
        ld hl,parts
        ld de,parts+1
        ld bc,NPART*PASIZE-1
        ld (hl),0
        ldir
        ld hl,fxs
        ld de,fxs+1
        ld bc,NFX*FXSIZE-1
        ld (hl),0
        ldir
        ld hl,balloons
        ld de,balloons+1
        ld bc,NBAL*BASIZE-1
        ld (hl),0
        ldir
        xor a
        ld (chute_t),a
        ld (guns_on),a
        ld (rend_t),a
        ld (popup_t),a
        ld (gust_len),a
        ld (charge_t),a
        ld hl,600
        ld (bal_t),hl
        ld a,200
        ld (gust_t),a
        ld (light_t),a
        ; keep wins, reset the rest
        ld a,(pl0+P_WINS)
        push af
        ld a,(pl0+P_CTL)
        push af
        ld ix,pl0
        xor a
        call init_plane
        pop af
        ld (pl0+P_CTL),a
        pop af
        ld (pl0+P_WINS),a
        ld a,(pl1+P_WINS)
        push af
        ld ix,pl1
        ld a,1
        call init_plane
        pop af
        ld (pl1+P_WINS),a
        ld a,1
        ld (pl1+P_CTL),a
        ld a,(p2ace)
        cp $FF
        jr z,.hum
        ld ix,pl1
        call ai_setup
.hum:   ld a,(p1cpu)
        cp $FF
        jr z,.hum1
        ld ix,pl0
        call ai_setup
.hum1:  ld a,(autoplay)        ; test hook: the computer flies both
        or a
        jr z,.na
        ld ix,pl0
        ld a,8
        call ai_setup
        ld a,(mode)
        cp MODE_BONUS
        jr z,.na
        ld ix,pl1
        ld a,(p2ace)
        cp $FF
        jr nz,.na
        ld a,8
        call ai_setup
.na:    ld a,(mode)
        cp MODE_BONUS
        jr nz,.nb
        xor a
        ld (pl1+P_STATE),a
        ld a,64
        ld (pl0+P_X+1),a
        xor a
        ld (pl0+P_HEAD),a
.nb:    ld a,1
        ld (hud_dirty),a
        ret

; play_round: -> A = winner (0 / 1), 2 = both down, 3 = quit / demo abort
play_round:
        call start_round
        call draw_hud
        call show_b
        ; "ROUND n" then "FIGHT!"
        ld a,(roundno)
        add a,'0'
        ld (s_round+6),a
        ld hl,s_round
        ld (banner),hl
        ld a,70
        ld (banner_t),a
        ld hl,mus_round_0
        ld de,mus_round_1
        call jingle
.intro: call game_frame
        ld a,(quit)
        or a
        jr nz,.quit
        ld a,(banner_t)
        or a
        jr nz,.intro
        ld hl,s_fight
        ld (banner),hl
        ld a,35
        ld (banner_t),a
        ld a,1
        ld (guns_on),a
        call battle_music
.loop:  call game_frame
        ld a,(quit)
        or a
        jr nz,.quit
        ld a,(rend_t)
        or a
        jr z,.loop
        dec a
        ld (rend_t),a
        jr nz,.loop
        call stop_music
        xor a
        ld (drone),a
        ld (drone+1),a
        ld a,(pl0+P_STATE)
        cp 1
        jr nz,.p1d
        xor a                   ; P1 still flying
        ret
.p1d:   ld a,(pl1+P_STATE)
        cp 1
        ld a,1
        ret z
        ld a,2
        ret
.quit:  call stop_music
        xor a
        ld (drone),a
        ld (drone+1),a
        ld a,3
        ret
s_round: db "ROUND 1",0
s_fight: db "FIGHT!",0

battle_music:
        ld a,(mode)
        cp MODE_DEMO
        ret z
        ld hl,mus_battle_0
        ld de,mus_battle_1
        cp MODE_BONUS
        jr nz,bgm
        ld hl,mus_bonus_0
        ld de,mus_bonus_1
; background music only in "music + SFX" mode
bgm:
        ld a,(soundmode)
        cp 2
        jp nz,stop_music
        jp play_music
; jingles play unless the sound is off
jingle:
        ld a,(soundmode)
        or a
        ret z
        jp play_music

; =====================================================================
;  ONE FRAME
; =====================================================================
game_frame:
        ld a,(mode)
        cp MODE_DEMO
        jr nz,.nd
        ld hl,(demot)
        dec hl
        ld (demot),hl
        ld a,h
        or l
        jr nz,.nd
        inc a
        ld (quit),a
.nd:    call do_frame
        call sys_keys
        call update_world
        jp draw_world

; M = sound mode, RETURN = pause (Q quits while paused); demo: any key
sys_keys:
        ld a,(mode)
        cp MODE_DEMO
        jr nz,.nd
        ld a,(mnunew)
        and $10
        jr nz,.ab
        ld a,(keysnew)
        or a
        ret z
.ab:    ld a,1
        ld (quit),a
        ret
.nd:    ld a,(keysnew)
        bit 0,a
        jr z,.ns
        ld a,(soundmode)
        or a
        jr nz,.s1
        ld a,3
.s1:    dec a
        ld (soundmode),a
        cp 2
        jr nz,.s2
        call battle_music
        jr .s3
.s2:    call stop_music
.s3:    ld hl,snd_names
        ld a,(soundmode)
        add a,a
        add a,l
        ld l,a
        jr nc,.s4
        inc h
.s4:    ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (popup),hl
        ld a,50
        ld (popup_t),a
.ns:    ld a,(keysnew)
        bit 1,a
        ret z
        ; pause
        call stop_music
        xor a
        ld (drone),a
        ld (drone+1),a
        call to_f
        ld a,1
        ld (objmark),a
        ld a,(col0)
        ld b,a
        ld a,(col3)
        call set_ink
        ld hl,s_paused
        ld e,30
        call print_c
        xor a
        ld (objmark),a
.pl:    call do_frame
        ld a,(keysnew)
        bit 2,a
        jr nz,.q
        bit 1,a
        jr z,.pl
        call battle_music
        ret
.q:     ld a,1
        ld (quit),a
        ret
s_paused: db " PAUSED - RETURN: GO  Q: QUIT ",0
snd_names: dw sn0,sn1,sn2
sn0:    db "SOUND OFF",0
sn1:    db "SFX ONLY",0
sn2:    db "MUSIC + SFX",0

update_world:
        ld a,(banner_t)
        or a
        jr z,.b
        dec a
        ld (banner_t),a
.b:     ld a,(popup_t)
        or a
        jr z,.p
        dec a
        ld (popup_t),a
.p:     ld ix,pl0
        ld iy,pl1
        call update_plane
        ld ix,pl1
        ld iy,pl0
        call update_plane
        call update_bullets
        call collide
        call update_parts
        call update_fx
        call update_balloons
        call update_chute
        call hazards
        call move_clouds
        call engine_drone
        ; round ends a while after someone goes down
        ld a,(rend_t)
        or a
        ret nz
        ld a,(mode)
        cp MODE_BONUS
        ret z
        ld a,(pl0+P_STATE)
        cp 1
        jr nz,.end
        ld a,(pl1+P_STATE)
        cp 1
        ret z
.end:   ld a,170
        ld (rend_t),a
        jp round_banner

engine_drone:
        ld hl,0
        ld a,(soundmode)
        or a
        jr z,.set
        ld a,(pl0+P_CTL)
        or a
        jr nz,.set
        ld a,(pl0+P_STATE)
        cp 1
        jr nz,.set
        ld a,(pl0+P_LEVEL)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,100
        ld l,a
        ld a,(framecount)
        and 2
        add a,l
        ld l,a
.set:   ld (drone),hl
        ret

; ---------------------------------------------------------------------
; update_plane: IX = plane, IY = the other one
; ---------------------------------------------------------------------
update_plane:
        ld a,(ix+P_STATE)
        cp 1
        jp z,.fly
        cp 2
        ret nz
        ; ---- going down: spin, smoke, then blow up and bail out
        ld a,(framecount)
        and 3
        jr nz,.sp
        ld a,(ix+P_HEAD)
        inc a
        and 15
        ld (ix+P_HEAD),a
.sp:    ld a,1
        ld (ix+P_LEVEL),a
        call set_velocity
        call move_plane
        ld a,(framecount)
        and 1
        call z,smoke_puff
        dec (ix+P_FALLT)
        ret nz
        ld (ix+P_STATE),3
        ld a,(ix+P_X+1)
        ld b,a
        ld a,(ix+P_Y+1)
        ld c,a
        push bc
        ld a,0
        call add_fx
        pop bc
        push bc
        ld a,18
        call debris
        pop bc
        ld a,b
        ld (chute_x+1),a
        ld a,c
        ld (chute_y+1),a
        ld a,140
        ld (chute_t),a
        ld a,10
        ld (flashtim),a
        ld a,SFX_BOOM
        jp play_sfx
.fly:   ; ---- controls
        ld a,(ix+P_CTL)
        cp 2
        jr nz,.hum
        call ai_think
        ld a,(autoplay)
        jr .gotpad
.hum:   ld a,(autoplay)
        or a
        jr z,.h1
        call ai_think
        jr .h2
.h1:    ld a,(ix+P_CTL)
        or a
        ld a,(pad1)
        jr z,.h0
        ld a,(pad2)
.h0:    ld (ix+P_PAD),a
.h2:
.gotpad:
        ld a,(ix+P_PAD)
        ld c,a
        ; turning
        and 3
        jr nz,.turn
        ld (ix+P_TURNT),1
        jr .thr
.turn:  dec (ix+P_TURNT)
        jr nz,.thr
        ld a,(ix+P_TURND)
        ld (ix+P_TURNT),a
        ld a,(th_rec+14)        ; heading step (2 in Classic)
        ld b,a
        ld a,(ix+P_HEAD)
        bit 0,c
        jr z,.tl
        add a,b
        jr .ts
.tl:    sub b
.ts:    and 15
        ld (ix+P_HEAD),a
.thr:   ld a,c
        and $0C
        jr nz,.th
        ld (ix+P_THRT),1
        jr .mv
.th:    dec (ix+P_THRT)
        jr nz,.mv
        ld (ix+P_THRT),10
        bit 2,c
        jr z,.slow
        ld a,(ix+P_LEVEL)
        cp 5
        jr nc,.mv
        inc (ix+P_LEVEL)
        jr .mv
.slow:  ld a,(ix+P_LEVEL)
        or a
        jr z,.mv
        dec (ix+P_LEVEL)
.mv:    call set_velocity
        call move_plane
        ld c,(ix+P_PAD)
        ; ---- guns
        ld a,(ix+P_FIRET)
        or a
        jr z,.f0
        dec (ix+P_FIRET)
        jr .tm
.f0:    bit 4,c
        jr z,.tm
        ld a,(guns_on)
        or a
        jr z,.tm
        call fire
.tm:    ; ---- timers
        ld a,(ix+P_FLASH)
        or a
        jr z,.t1
        dec (ix+P_FLASH)
.t1:    ld a,(ix+P_COLLT)
        or a
        jr z,.t2
        dec (ix+P_COLLT)
.t2:    ld l,(ix+P_PWRT)
        ld h,(ix+P_PWRT+1)
        ld a,h
        or l
        jr z,.t3
        dec hl
        ld (ix+P_PWRT),l
        ld (ix+P_PWRT+1),h
        ld a,h
        or l
        jr nz,.t3
        ld (ix+P_PWR),0
.t3:    ld l,(ix+P_SHIELD)
        ld h,(ix+P_SHIELD+1)
        ld a,h
        or l
        jr z,.t4
        dec hl
        ld (ix+P_SHIELD),l
        ld (ix+P_SHIELD+1),h
.t4:    ; ---- smoke when badly hurt
        ld a,(ix+P_HP)
        cp 6
        ret nc
        dec (ix+P_SMOKET)
        ret p
        cp 3
        ld a,7
        jr nc,.s1
        ld a,3
.s1:    ld (ix+P_SMOKET),a
        jp smoke_puff

; velocity from heading + throttle (+2 with turbo) -> P_VX / P_VY
set_velocity:
        ld a,(ix+P_LEVEL)
        ld b,a
        ld a,(ix+P_PWR)
        cp 2
        jr nz,.n
        inc b
        inc b
.n:     ld a,b
        ld c,(ix+P_HEAD)
        call vel_of
        ld (ix+P_VX),e
        ld (ix+P_VX+1),d
        ld (ix+P_VY),l
        ld (ix+P_VY+1),h
        ret
; A = level, C = heading -> DE = vx, HL = vy
vel_of:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *64
        ld a,c
        and 15
        add a,a
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld de,veltab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

move_plane:
        ld l,(ix+P_X)
        ld h,(ix+P_X+1)
        ld e,(ix+P_VX)
        ld d,(ix+P_VX+1)
        add hl,de
        ld a,(gust_len)
        or a
        jr z,.ng
        ld de,(gustv)
        add hl,de
.ng:    ld a,h
        and 127
        ld (ix+P_X),l
        ld (ix+P_X+1),a
        ld l,(ix+P_Y)
        ld h,(ix+P_Y+1)
        ld e,(ix+P_VY)
        ld d,(ix+P_VY+1)
        add hl,de
        ld a,h
        call wrap_y
        ld (ix+P_Y),l
        ld (ix+P_Y+1),a
        ret

; ---------------------------------------------------------------------
; fire: IX = plane. One shot from the nose (two with twin guns)
; ---------------------------------------------------------------------
fire:
        ld (ix+P_FIRET),8
        ld a,(ix+P_PWR)
        cp 1
        jr z,.twin
        ld de,0
        ld hl,0
        call spawn_bullet
        ld a,SFX_GUN
        jp play_sfx
.twin:  ld (ix+P_FIRET),9
        ld a,(ix+P_HEAD)
        add a,4
        ld c,a
        ld a,4
        call vel_of             ; sideways offset ~ 1.4 px
        push de
        push hl
        add hl,hl
        ex de,hl
        add hl,hl
        ex de,hl
        call spawn_bullet
        pop hl
        pop de
        add hl,hl
        ex de,hl
        add hl,hl
        ex de,hl
        ; negate both
        xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        call spawn_bullet
        ld a,SFX_TWIN
        jp play_sfx
; spawn_bullet: DE = x offset, HL = y offset (8.8) from the nose
spawn_bullet:
        push hl
        push de
        ld hl,bullets
        ld b,NBUL
.f:     push hl
        pop iy
        ld a,(iy+BU_LIFE)
        or a
        jr z,.got
        ld de,BUSIZE
        add hl,de
        djnz .f
        pop de
        pop hl
        ret
.got:   ld a,8
        ld c,(ix+P_HEAD)
        call vel_of             ; bullet velocity
        ld (iy+BU_VX),e
        ld (iy+BU_VX+1),d
        ld (iy+BU_VY),l
        ld (iy+BU_VY+1),h
        ; start 2 frames ahead of the plane's centre
        push hl
        ld l,(ix+P_X)
        ld h,(ix+P_X+1)
        add hl,de
        add hl,de
        pop de                  ; DE = vy
        ex (sp),hl              ; HL = x offset, stack = x
        pop bc                  ; BC = x
        add hl,bc
        ld a,h
        and 127
        ld (iy+BU_X),l
        ld (iy+BU_X+1),a
        ld l,(ix+P_Y)
        ld h,(ix+P_Y+1)
        add hl,de
        add hl,de
        pop bc                  ; y offset
        add hl,bc
        ld a,h
        call wrap_y
        ld (iy+BU_Y),l
        ld (iy+BU_Y+1),a
        ; plus the plane's own speed
        ld l,(iy+BU_VX)
        ld h,(iy+BU_VX+1)
        ld e,(ix+P_VX)
        ld d,(ix+P_VX+1)
        add hl,de
        ld (iy+BU_VX),l
        ld (iy+BU_VX+1),h
        ld l,(iy+BU_VY)
        ld h,(iy+BU_VY+1)
        ld e,(ix+P_VY)
        ld d,(ix+P_VY+1)
        add hl,de
        ld (iy+BU_VY),l
        ld (iy+BU_VY+1),h
        ld (iy+BU_LIFE),21
        ld a,(ix+P_ID)
        ld (iy+BU_OWN),a
        ld a,(ix+P_COL)
        ld (iy+BU_COL),a
        ret

; ---------------------------------------------------------------------
; bullets: move, expire, hit planes and balloons
; ---------------------------------------------------------------------
update_bullets:
        ld iy,bullets
        ld b,NBUL
.l:     push bc
        ld a,(iy+BU_LIFE)
        or a
        jr z,.n
        dec (iy+BU_LIFE)
        ld l,(iy+BU_X)
        ld h,(iy+BU_X+1)
        ld e,(iy+BU_VX)
        ld d,(iy+BU_VX+1)
        add hl,de
        ld a,h
        and 127
        ld (iy+BU_X),l
        ld (iy+BU_X+1),a
        ld l,(iy+BU_Y)
        ld h,(iy+BU_Y+1)
        ld e,(iy+BU_VY)
        ld d,(iy+BU_VY+1)
        add hl,de
        ld a,h
        call wrap_y
        ld (iy+BU_Y),l
        ld (iy+BU_Y+1),a
        ; target = the other plane
        ld ix,pl1
        ld a,(iy+BU_OWN)
        or a
        jr z,.t
        ld ix,pl0
.t:     ld a,(ix+P_STATE)
        cp 1
        jr nz,.bal
        ld a,(ix+P_X+1)
        ld b,a
        ld a,(ix+P_Y+1)
        ld c,a
        call bullet_near
        jr nc,.bal
        ld (iy+BU_LIFE),0
        call plane_hit
        jr .n
.bal:   call bullet_balloons
.n:     ld de,BUSIZE
        add iy,de
        pop bc
        djnz .l
        ret

; bullet IY near point B,C?  (|dx| <= 4, |dy| <= 3) -> carry
bullet_near:
        ld a,(iy+BU_X+1)
        sub b
        call wrap_dx
        add a,4
        cp 9
        ret nc
        ld a,(iy+BU_Y+1)
        sub c
        call wrap_dy
        add a,3
        cp 7
        ret
; A = raw x difference -> signed -64..63
wrap_dx:
        and 127
        cp 64
        ret c
        sub 128
        ret
; A = raw y difference (-57..57) -> signed -29..28
wrap_dy:
        bit 7,a
        jr nz,.n
        cp 29
        ret c
        sub ARENA_H
        ret
.n:     cp -29
        ret nc
        add a,ARENA_H
        ret

; plane_hit: IX = plane hit by bullet IY (owner = the other plane)
plane_hit:
        ld a,(ix+P_SHIELD)
        or (ix+P_SHIELD+1)
        jr z,.dmg
        ld a,SFX_SHIELD
        jp play_sfx
.dmg:   call sparks
        ld a,(iy+BU_OWN)
        or a
        jr nz,.no
        ld a,(pl0+P_HITS)
        inc a
        ld (pl0+P_HITS),a
        ld de,$0025
        call score_p1
.no:    ld a,1
damage:                 ; IX = plane, A = hits
        ld b,a
        ld a,(nodamage)
        or a
        ret nz
        ld a,(godmode)
        or a
        jr z,.dm
        ld a,(ix+P_ID)
        or a
        ret z
.dm:
        ld a,(ix+P_STATE)
        cp 1
        ret nz
        ld a,1
        ld (hud_dirty),a
        ld (ix+P_FLASH),8
        ld a,(ix+P_HP)
        sub b
        jr z,.down
        jr c,.down
        ld (ix+P_HP),a
        ld a,SFX_HIT
        jp play_sfx
.down:  ld (ix+P_HP),0
        ld (ix+P_STATE),2
        ld (ix+P_FALLT),70
        ld a,SFX_FALL
        call play_sfx
        ; the winner's points
        ld a,(ix+P_ID)
        or a
        ret z
        ld de,$0500
        jp score_p1

; score_p1: DE = BCD points, only in the campaign / bonus round
score_p1:
        ld a,(mode)
        cp MODE_CAMP
        jr z,add_score
        cp MODE_BONUS
        ret nz
add_score:
        ld hl,score+2
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld a,1
        ld (hud_dirty),a
        ret

; mid-air collision: both lose 2, one bump per 40 frames
collide:
        ld a,(pl0+P_STATE)
        cp 1
        ret nz
        ld a,(pl1+P_STATE)
        cp 1
        ret nz
        ld a,(pl0+P_COLLT)
        or a
        ret nz
        ld a,(pl0+P_X+1)
        ld b,a
        ld a,(pl1+P_X+1)
        sub b
        call wrap_dx
        add a,4
        cp 9
        ret nc
        ld a,(pl0+P_Y+1)
        ld b,a
        ld a,(pl1+P_Y+1)
        sub b
        call wrap_dy
        add a,3
        cp 7
        ret nc
        ld a,60
        ld (pl0+P_COLLT),a
        ld (pl1+P_COLLT),a
        ld a,4
        ld (flashtim),a
        ld ix,pl0
        call .bump
        ld ix,pl1
        call .bump
        ld a,SFX_CRASH
        jp play_sfx
.bump:  ld a,(ix+P_X+1)
        ld b,a
        ld a,(ix+P_Y+1)
        ld c,a
        ld a,6
        call debris
        ld a,(ix+P_HEAD)        ; knocked off course, bounced back
        add a,5
        and 15
        ld (ix+P_HEAD),a
        ld c,a
        ld a,5
        call vel_of
        ld a,(ix+P_X+1)
        add a,d
        add a,d
        add a,d
        and 127
        ld (ix+P_X+1),a
        ld a,h
        add a,h
        add a,h
        add a,(ix+P_Y+1)
        call wrap_y
        ld (ix+P_Y+1),a
        ld a,1
        jp damage

; ---------------------------------------------------------------------
; particles: smoke, sparks, debris (single pixels)
; ---------------------------------------------------------------------
; new particle: B,C = position, DE = vx, HL = vy, A = life, (pcol) colour
new_part:
        push af
        push hl
        push de
        ld hl,parts
        ld a,(partnext)
        inc a
        cp NPART
        jr c,.ok
        xor a
.ok:    ld (partnext),a
        ld e,a
        add a,a
        add a,a
        add a,e
        add a,a                 ; *10
        ld e,a
        ld d,0
        add hl,de
        push hl
        pop iy
        pop de
        pop hl
        pop af
        ld (iy+PA_LIFE),a
        ld (iy+PA_X),$80
        ld (iy+PA_X+1),b
        ld (iy+PA_Y),$80
        ld (iy+PA_Y+1),c
        ld (iy+PA_VX),e
        ld (iy+PA_VX+1),d
        ld (iy+PA_VY),l
        ld (iy+PA_VY+1),h
        ld a,(pcol)
        ld (iy+PA_COL),a
        ret
; smoke_puff: behind plane IX
smoke_puff:
        push iy
        ld a,(ix+P_STATE)
        cp 2
        ld a,(col3)
        jr z,.c
        ld a,(framecount)
        and 4
        ld a,(col3)
        jr z,.c
        ld a,(col1)
.c:     ld (pcol),a
        ld a,(ix+P_HEAD)
        add a,8
        ld c,a
        ld a,5
        call vel_of             ; a little behind
        ld a,(ix+P_X+1)
        add a,d
        and 127
        ld b,a
        ld a,(ix+P_Y+1)
        add a,h
        call wrap_y
        ld c,a
        ld de,0
        ld hl,-12
        ld a,26
        call new_part
        pop iy
        ret
; sparks at plane IX (3 random)
sparks:
        push iy
        ld a,(col3)
        ld (pcol),a
        ld a,3
        ld (tmpc),a
.l:     call rnd_vel
        ld a,(ix+P_X+1)
        ld b,a
        ld a,(ix+P_Y+1)
        ld c,a
        ld a,10
        call new_part
        ld a,(tmpc)
        dec a
        ld (tmpc),a
        jr nz,.l
        pop iy
        ret
; debris: B,C position, A = count
debris:
        push iy
        ld (tmpc),a
.l:     push bc
        call random
        and 1
        ld a,(col1)
        jr z,.c
        ld a,(col3)
.c:     ld (pcol),a
        call rnd_vel
        ld a,24
        call new_part
        pop bc
        ld a,(tmpc)
        dec a
        ld (tmpc),a
        jr nz,.l
        pop iy
        ret
; random velocity: DE = vx, HL = vy (about +-1.2 px)
rnd_vel:
        call random
        ld e,a
        rlca
        sbc a,a
        ld d,a
        sla e
        rl d
        call random
        ld l,a
        rlca
        sbc a,a
        ld h,a
        ret
update_parts:
        ld iy,parts
        ld b,NPART
.l:     ld a,(iy+PA_LIFE)
        or a
        jr z,.n
        dec (iy+PA_LIFE)
        ld l,(iy+PA_X)
        ld h,(iy+PA_X+1)
        ld e,(iy+PA_VX)
        ld d,(iy+PA_VX+1)
        add hl,de
        ld a,h
        and 127
        ld (iy+PA_X),l
        ld (iy+PA_X+1),a
        ld l,(iy+PA_Y)
        ld h,(iy+PA_Y+1)
        ld e,(iy+PA_VY)
        ld d,(iy+PA_VY+1)
        add hl,de
        ld a,h
        call wrap_y
        ld (iy+PA_Y),l
        ld (iy+PA_Y+1),a
        ; slow down
        ld l,(iy+PA_VX)
        ld h,(iy+PA_VX+1)
        sra h
        rr l
        ld e,l
        ld d,h
        sra h
        rr l
        add hl,de
        ld (iy+PA_VX),l
        ld (iy+PA_VX+1),h
        ld l,(iy+PA_VY)
        ld h,(iy+PA_VY+1)
        sra h
        rr l
        ld e,l
        ld d,h
        sra h
        rr l
        add hl,de
        ld (iy+PA_VY),l
        ld (iy+PA_VY+1),h
.n:     ld de,PASIZE
        add iy,de
        djnz .l
        ret

; ---------------------------------------------------------------------
; sprite effects: kind 0 explosion (3 frames), 1 burst, 2 lightning bolt
; add_fx: A = kind, B,C = position
; ---------------------------------------------------------------------
add_fx:
        ld hl,fxs
        ld e,NFX
.f:     push hl
        pop iy
        ld d,a
        ld a,(iy+FX_T)
        or a
        ld a,d
        jr z,.got
        push de
        ld de,FXSIZE
        add hl,de
        pop de
        dec e
        jr nz,.f
        ret
.got:   ld (iy+FX_KIND),a
        ld (iy+FX_X),b
        ld (iy+FX_Y),c
        or a
        ld d,FR_EXP1
        ld e,21
        jr z,.s
        dec a
        ld d,FR_BURST
        ld e,10
        jr z,.s
        ld d,FR_BOLT
        ld e,10
.s:     ld (iy+FX_FR),d
        ld (iy+FX_T),e
        ret
update_fx:
        ld iy,fxs
        ld b,NFX
.l:     ld a,(iy+FX_T)
        or a
        jr z,.n
        dec a
        ld (iy+FX_T),a
        ld c,a
        ld a,(iy+FX_KIND)
        or a
        jr nz,.n
        ld a,c                  ; explosion: 21..14 EXP1, 13..7 EXP2, else EXP3
        cp 14
        ld a,FR_EXP1
        jr nc,.s
        ld a,c
        cp 7
        ld a,FR_EXP2
        jr nc,.s
        ld a,FR_EXP3
.s:     ld (iy+FX_FR),a
.n:     ld de,FXSIZE
        add iy,de
        djnz .l
        ret

; ---------------------------------------------------------------------
; supply balloons (duels) - shoot one for a power-up
; ---------------------------------------------------------------------
update_balloons:
        ld a,(mode)
        cp MODE_BONUS
        jp z,bonus_spawn
        ld a,(th_rec+13)
        or a
        jr z,.move
        ld a,(guns_on)
        or a
        jr z,.move
        ld hl,(bal_t)
        dec hl
        ld (bal_t),hl
        ld a,h
        or l
        jr nz,.move
        call random             ; 0..255
        ld l,a
        ld h,2
        ld (bal_t),hl           ; next one in 512..767 frames
        call spawn_balloon
.move:
move_balloons:
        ld iy,balloons
        ld b,NBAL
.l:     ld a,(iy+BA_ON)
        or a
        jr z,.n
        dec (iy+BA_T)
        jr nz,.mv
        ld (iy+BA_ON),0
        jr .n
.mv:    ld l,(iy+BA_X)
        ld h,(iy+BA_X+1)
        ld e,(iy+BA_VX)
        ld d,(iy+BA_VX+1)
        add hl,de
        ld a,h
        and 127
        ld (iy+BA_X),l
        ld (iy+BA_X+1),a
        ld l,(iy+BA_Y)
        ld h,(iy+BA_Y+1)
        ld e,(iy+BA_VY)
        ld d,(iy+BA_VY+1)
        add hl,de
        ld a,h
        call wrap_y
        ld (iy+BA_Y),l
        ld (iy+BA_Y+1),a
.n:     ld de,BASIZE
        add iy,de
        djnz .l
        ret
spawn_balloon:
        ld iy,balloons
        ld b,NBAL
.f:     ld a,(iy+BA_ON)
        or a
        jr z,.got
        ld de,BASIZE
        add iy,de
        djnz .f
        ret
.got:   ld (iy+BA_ON),1
        ld (iy+BA_T),250
        call random
        and 127
        ld (iy+BA_X+1),a
        ld (iy+BA_Y+1),ARENA_H-1
        ld b,41
        call rand_n
        sub 20
        ld (iy+BA_VX),a
        rla
        sbc a,a
        ld (iy+BA_VX+1),a
        ld b,24
        call rand_n
        add a,40
        neg
        ld (iy+BA_VY),a
        ld (iy+BA_VY+1),$FF
        ret
; bullet IY against every balloon
bullet_balloons:
        ld ix,balloons
        ld b,NBAL
.l:     push bc
        ld a,(ix+BA_ON)
        or a
        jr z,.n
        ld a,(ix+BA_X+1)
        ld b,a
        ld a,(ix+BA_Y+1)
        ld c,a
        call bullet_near
        jr nc,.n
        ld (ix+BA_ON),0
        ld (iy+BU_LIFE),0
        ld a,1
        call add_fx
        ld a,SFX_POP
        call play_sfx
        pop bc
        jp balloon_prize
.n:     ld de,BASIZE
        add ix,de
        pop bc
        djnz .l
        ret
; the shooter (bullet IY's owner) wins a prize
balloon_prize:
        ld a,(mode)
        cp MODE_BONUS
        jr nz,.duel
        ld a,(bn_got)
        inc a
        ld (bn_got),a
        ld de,$0200
        jp add_score
.duel:  ld ix,pl0
        ld a,(iy+BU_OWN)
        or a
        jr z,.o
        ld ix,pl1
.o:     ld de,$0100
        or a
        call z,score_p1
        ld b,4
        call rand_n
        or a
        jr nz,.p1
        ; repair +5
        ld a,(ix+P_HP)
        add a,5
        cp 16
        jr c,.r
        ld a,15
.r:     ld (ix+P_HP),a
        ld a,1
        ld (hud_dirty),a
        ld hl,s_repair
        jr .msg
.p1:    dec a
        jr nz,.p2
        ld (ix+P_PWR),1
        ld hl,s_twin
        jr .tim
.p2:    dec a
        jr nz,.p3
        ld (ix+P_PWR),2
        ld hl,s_turbo
.tim:   ld (ix+P_PWRT),$58
        ld (ix+P_PWRT+1),$02    ; 600 frames
        jr .msg
.p3:    ld (ix+P_SHIELD),$90
        ld (ix+P_SHIELD+1),$01  ; 400 frames
        ld hl,s_shield
.msg:   ld (popup),hl
        ld a,(ix+P_ID)
        add a,'1'
        inc hl
        ld (hl),a
        dec hl
        ld a,70
        ld (popup_t),a
        ld hl,mus_power_0
        ld de,mus_power_1
        ld a,(mplaying)
        or a
        jp z,jingle
        ld a,SFX_POWER
        jp play_sfx
s_repair: db "P1 REPAIRED!",0
s_twin:   db "P1 TWIN GUNS!",0
s_turbo:  db "P1 TURBO!",0
s_shield: db "P1 SHIELD!",0

; parachute drifting down after a bail-out
update_chute:
        ld a,(chute_t)
        or a
        ret z
        dec a
        ld (chute_t),a
        cp 139
        jr nz,.n
        ld a,SFX_CHUTE
        call play_sfx
.n:     ld hl,(chute_y)
        ld de,22
        add hl,de
        ld a,h
        call wrap_y
        ld h,a
        ld (chute_y),hl
        ret

; ---------------------------------------------------------------------
; hazards: desert gusts, night-storm lightning
; ---------------------------------------------------------------------
hazards:
        ld a,(guns_on)
        or a
        ret z
        ld a,(th_rec+8)
        dec a
        jr z,gusts
        dec a
        jr z,lightning
        ret
gusts:
        ld a,(gust_len)
        or a
        jr z,.wait
        dec a
        ld (gust_len),a
        ret nz
        ld a,(th_rec+7)         ; calm again
        ld l,a
        rla
        sbc a,a
        ld h,a
        ld (wind),hl
        ret
.wait:  ld a,(gust_t)
        dec a
        ld (gust_t),a
        ret nz
        ld b,200
        call rand_n
        add a,40
        ld (gust_t),a           ; next gust in 240..440 frames... (plus this one)
        ld a,130
        ld (gust_len),a
        call random
        and 1
        ld hl,95
        ld de,s_gustr
        jr z,.d
        ld hl,-95
        ld de,s_gustl
.d:     ld (gustv),hl
        add hl,hl
        ld (wind),hl
        ld (popup),de
        ld a,60
        ld (popup_t),a
        ld a,SFX_GUST
        jp play_sfx
s_gustr: db "GUST! >>>",0
s_gustl: db "<<< GUST!",0
lightning:
        ld a,(charge_t)
        or a
        jr nz,.charging
        ld a,(light_t)
        dec a
        ld (light_t),a
        ret nz
        ld b,150
        call rand_n
        add a,90
        ld (light_t),a
        ; pick a cloud
        ld a,(ncl)
        ld b,a
        call rand_n
        ld (charge_cl),a
        ld a,64
        ld (charge_t),a
        ld hl,s_storm
        ld (popup),hl
        ld a,50
        ld (popup_t),a
        ret
.charging:
        dec a
        ld (charge_t),a
        call charge_ix
        ld a,(charge_t)
        or a
        jr z,.strike
        and 7
        ret nz
        ; flicker the cloud between yellow and its own colour
        ld a,(charge_t)
        and 8
        ld a,(cloudfill)
        jr z,.f
        ld a,(col1)
        call fillbyte
.f:     ld (ix+CL_FILL),a
        call touch_cloud
        ld a,(charge_t)
        and 15
        ret nz
        ld a,SFX_CHARGE
        jp play_sfx
.strike:
        ld a,(cloudfill)
        ld (ix+CL_FILL),a
        call touch_cloud
        ld a,14
        ld (flashtim),a
        ld a,SFX_THUNDER
        call play_sfx
        ; bolt under the cloud's middle
        ld a,(ix+CL_SHAPE)
        call cloud_ent
        ld de,8
        add hl,de
        ld a,(hl)
        srl a
        add a,(ix+CL_X+1)
        and 127
        ld b,a
        ld (bolt_x),a
        inc hl
        ld a,(hl)
        ld (bolt_h),a
        add a,(ix+CL_Y)
        call wrap_y
        ld c,a
        ld a,2
        call add_fx
        ; planes under the cloud take two hits
        push ix
        pop iy
        ld ix,pl0
        call .zap
        ld ix,pl1
.zap:   ld a,(ix+P_STATE)
        cp 1
        ret nz
        ld a,(ix+P_SHIELD)
        or (ix+P_SHIELD+1)
        ret nz
        ld a,(iy+CL_SHAPE)
        call cloud_ent
        ld de,8
        add hl,de
        ld a,(ix+P_X+1)
        sub (iy+CL_X+1)
        and 127
        cp (hl)
        ret nc
        inc hl
        ld a,(ix+P_Y+1)
        sub (iy+CL_Y)
        jr nc,.y
        add a,ARENA_H
.y:     add a,2
        cp (hl)
        ret nc
        call sparks
        ld a,2
        jp damage
charge_ix:
        ld a,(charge_cl)
        ld ix,clouds
        or a
        ret z
        ld b,a
        ld de,CL_SIZE
.l:     add ix,de
        djnz .l
        ret
s_storm: db "LIGHTNING!",0

; =====================================================================
;  COMPUTER PILOTS
; =====================================================================
; ai_think: IX = computer plane, IY = target. Sets P_PAD like a player.
ai_think:
        dec (ix+P_THINK)
        ret p
        ld a,(ix+P_THINKD)
        ld (ix+P_THINK),a
        ld a,(iy+P_STATE)
        cp 1
        jr z,.tgt
        ; nobody to fight: cruise, gentle circles
        ld a,1
        ld (ix+P_PAD),a
        ret
.tgt:   ; ---- breaking away?
        ld a,(ix+P_BREAK)
        or a
        jr z,.nb
        dec (ix+P_BREAK)
        ld a,(ix+P_BRDIR)
        or 4                    ; full throttle while breaking
        ld (ix+P_PAD),a
        ret
.nb:    ; vector to the target (with lead)
        ld a,(iy+P_X+1)
        ld b,(ix+P_X+1)
        sub b
        ld (ai_dx),a
        ld a,(iy+P_Y+1)
        sub (ix+P_Y+1)
        ld (ai_dy),a
        ld a,(ix+P_LEAD)
        or a
        jr z,.nl
        ld l,(iy+P_VX)
        ld h,(iy+P_VX+1)
        call div32
        ld b,a
        ld a,(ai_dx)
        add a,b
        ld (ai_dx),a
        ld l,(iy+P_VY)
        ld h,(iy+P_VY+1)
        call div32
        ld b,a
        ld a,(ai_dy)
        add a,b
        ld (ai_dy),a
.nl:    ld a,(ai_dx)
        call wrap_dx
        ld (ai_dx),a
        ld a,(ai_dy)
        call wrap_dy
        ld (ai_dy),a
        ; ---- is the target lined up on me? maybe break away
        ld a,(ix+P_EVAD)
        or a
        jr z,.ne
        ld a,(ai_dx)
        neg
        ld d,a
        ld a,(ai_dy)
        neg
        ld e,a
        call atan16             ; direction target -> me
        sub (iy+P_HEAD)
        add a,1
        and 15
        cp 3
        jr nc,.ne
        call ai_dist
        cp 30
        jr nc,.ne
        call random
        cp (ix+P_EVAD)
        jr nc,.ne
        ld (ix+P_BREAK),3
        call random
        and 1
        inc a
        ld (ix+P_BRDIR),a
        ; hiders head for the nearest cloud instead
        ld a,(ix+P_HIDE)
        or a
        jr z,.ne
        ld a,(ix+P_HP)
        cp (iy+P_HP)
        jr nc,.ne
        call nearest_cloud
.ne:    ld a,(ai_dx)
        ld d,a
        ld a,(ai_dy)
        ld e,a
        call atan16
        sub (ix+P_HEAD)
        and 15
        ld (ai_diff),a
        ld c,0
        jr z,.aim
        cp 8
        jr nc,.lt
        set 0,c                 ; turn right
        jr .aim
.lt:    set 1,c
.aim:   ; too close: break right to avoid a collision
        call ai_dist
        cp 10
        jr nc,.aim2
        ld a,(ai_diff)
        add a,3
        and 15
        cp 7
        jr nc,.aim2
        ld a,c
        and $FC
        or 1
        ld c,a
.aim2:  ; fire when lined up and in range (snap shots up close)
        ld a,(ix+P_AIM)
        ld b,a
        call ai_dist
        cp 16
        jr nc,.a3
        inc b
.a3:    ld a,(ai_diff)
        add a,b
        and 15
        ld e,a
        ld a,b
        add a,a
        cp e
        jr c,.nf
        call ai_dist
        cp 40
        jr nc,.nf
        set 4,c
.nf:    ; throttle: slow down to out-turn, speed up to close in
        ld a,(ai_diff)
        add a,3
        and 15
        cp 7
        jr c,.ahead             ; target within +-3 headings
        call ai_dist
        cp 28
        jr nc,.fast
        ld a,(ix+P_LEVEL)
        or a
        jr z,.wb
        set 3,c
        jr .wb
.ahead: call ai_dist
        cp 14
        jr c,.near
.fast:  ld a,(ix+P_LEVEL)
        cp (ix+P_MAXL)
        jr nc,.wb
        set 2,c
        jr .wb
.near:  ld a,(ix+P_LEVEL)
        cp 3
        jr c,.wb
        set 3,c
.wb:    ; hesitation
        call random
        cp (ix+P_WOB)
        jr nc,.st
        ld a,c
        and $1C
        ld c,a
.st:    ld (ix+P_PAD),c
        ret

; HL = 8.8 velocity -> A = HL / 32 (signed), i.e. 8 frames of travel
div32:
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld a,l
        ret
; distance-ish of (ai_dx, ai_dy): max(a,b) + min(a,b)/2, a = |dx|*2/3
ai_dist:
        push bc
        call .d
        pop bc
        ret
.d:     ld a,(ai_dx)
        call absa
        ld b,a
        srl a
        srl a
        ld c,a
        ld a,b
        sub c                   ; ~ *3/4
        ld b,a
        ld a,(ai_dy)
        call absa
        cp b
        jr nc,.s
        ld c,a
        ld a,b
        ld b,c
.s:     srl b
        add a,b
        ret
absa:   bit 7,a
        ret z
        neg
        ret
; steer for the nearest cloud's middle: rewrites ai_dx / ai_dy
nearest_cloud:
        ld a,255
        ld (tmpd),a
        push iy
        ld iy,clouds
        ld b,MAXCL
.l:     push bc
        ld a,(iy+CL_ON)
        or a
        jr z,.n
        ld a,(iy+CL_X+1)
        add a,10
        sub (ix+P_X+1)
        call wrap_dx
        ld d,a
        ld a,(iy+CL_Y)
        add a,4
        sub (ix+P_Y+1)
        call wrap_dy
        ld e,a
        call absa
        ld c,a
        ld a,d
        call absa
        add a,c
        jr c,.n
        ld c,a
        ld a,(tmpd)
        cp c
        jr c,.n
        ld a,c
        ld (tmpd),a
        ld a,d
        ld (ai_dx),a
        ld a,e
        ld (ai_dy),a
.n:     ld de,CL_SIZE
        add iy,de
        pop bc
        djnz .l
        pop iy
        xor a
        ld (ix+P_BREAK),a
        ret

; atan16: D = dx (px, signed), E = dy (rows, signed) -> A = heading 0..15
atan16:
        ld a,d
        call absa
        ld b,a
        srl a
        srl a
        ld c,a
        ld a,b
        sub c                   ; a ~ |dx| * 3/4 (aspect)
        srl b
        srl b
        srl b
        srl b
        add a,b                 ; ~ 0.69
        ld b,a                  ; B = horizontal size
        ld a,e
        call absa
        ld c,a                  ; C = vertical size
        ; sector s from the vertical axis
        ld h,0
        ld a,b
        add a,a
        add a,a
        add a,b                 ; 5a
        cp c
        jr c,.got               ; 5a < b
        inc h
        ld a,b
        add a,a
        add a,b                 ; 3a
        ld l,a
        ld a,c
        add a,a                 ; 2b
        cp l
        jr z,.s2
        jr nc,.got              ; 3a < 2b
.s2:    inc h
        ld a,b
        add a,a                 ; 2a
        ld l,a
        ld a,c
        add a,a
        add a,c                 ; 3b
        cp l
        jr z,.s3
        jr nc,.got              ; 2a < 3b
.s3:    inc h
        ld a,c
        add a,a
        add a,a
        add a,c                 ; 5b
        cp b
        jr z,.s4
        jr nc,.got              ; a < 5b
.s4:    inc h
.got:   ; quadrant
        bit 7,d
        jr nz,.left
        bit 7,e
        jr nz,.ur
        ld a,8                  ; down-right: 8 - s
        sub h
        ret
.ur:    ld a,h                  ; up-right: s
        ret
.left:  bit 7,e
        jr nz,.ul
        ld a,8                  ; down-left: 8 + s
        add a,h
        ret
.ul:    ld a,16                 ; up-left: 16 - s
        sub h
        and 15
        ret

; =====================================================================
;  DRAWING
; =====================================================================
draw_world:
        call restore_old
        ld a,1
        ld (objmark),a
        ; balloons
        ld iy,balloons
        ld b,NBAL
.ba:    push bc
        ld a,(iy+BA_ON)
        or a
        jr z,.ban
        ld b,(iy+BA_X+1)
        ld c,(iy+BA_Y+1)
        ld a,FR_BALLOON
        call blit
.ban:   ld de,BASIZE
        add iy,de
        pop bc
        djnz .ba
        ; parachute
        ld a,(chute_t)
        or a
        jr z,.nc
        ld a,(chute_x+1)
        ld b,a
        ld a,(chute_y+1)
        ld c,a
        ld a,FR_CHUTE
        call blit
.nc:    ; particles
        ld iy,parts
        ld b,NPART
.pa:    push bc
        ld a,(iy+PA_LIFE)
        or a
        jr z,.pan
        ld b,(iy+PA_X+1)
        ld c,(iy+PA_Y+1)
        ld e,(iy+PA_COL)
        call plot
.pan:   ld de,PASIZE
        add iy,de
        pop bc
        djnz .pa
        ; bullets (2 pixels long)
        ld iy,bullets
        ld b,NBUL
.bu:    push bc
        ld a,(iy+BU_LIFE)
        or a
        jr z,.bun
        ld b,(iy+BU_X+1)
        ld c,(iy+BU_Y+1)
        ld e,(iy+BU_COL)
        call plot
        ld a,(iy+BU_X+1)
        ld b,a
        ld a,(iy+BU_VX+1)
        bit 7,a
        ld a,b
        jr z,.b1
        inc a
        inc a
.b1:    dec a
        and 127
        ld b,a
        ld c,(iy+BU_Y+1)
        ld e,(iy+BU_COL)
        call plot
.bun:   ld de,BUSIZE
        add iy,de
        pop bc
        djnz .bu
        ; planes
        ld ix,pl0
        call draw_plane
        ld ix,pl1
        call draw_plane
        ; effects
        ld iy,fxs
        ld b,NFX
.fx:    push bc
        ld a,(iy+FX_T)
        or a
        jr z,.fxn
        ld b,(iy+FX_X)
        ld c,(iy+FX_Y)
        ld a,(iy+FX_FR)
        call blit
.fxn:   ld de,FXSIZE
        add iy,de
        pop bc
        djnz .fx
        ; clouds over the lot
        call draw_clouds
        ; banner + popup text
        call to_f
        ld a,1
        ld (objmark),a
        ld a,(banner_t)
        or a
        jr z,.nbn
        ld a,(col0)
        ld b,a
        ld a,(col3)
        call set_ink
        ld hl,(banner)
        ld e,30
        call print2_c
.nbn:   ld a,(popup_t)
        or a
        jr z,.npp
        ld a,(col0)
        ld b,a
        ld a,(col1)
        call set_ink
        ld hl,(popup)
        ld e,8
        call print_c
.npp:   xor a
        ld (objmark),a
        ld a,(hud_dirty)
        or a
        ret z
        jp draw_hud

draw_plane:
        ld a,(ix+P_STATE)
        or a
        ret z
        cp 3
        ret nc
        ld a,(ix+P_FLASH)
        and 2
        ret nz                  ; hit flicker
        ld a,(ix+P_HEAD)
        add a,(ix+P_FRAME)
        ld b,(ix+P_X+1)
        ld c,(ix+P_Y+1)
        call blit
        ; shield: four dots circling
        ld a,(ix+P_SHIELD)
        or (ix+P_SHIELD+1)
        ret z
        ld a,(framecount)
        rrca
        and 15
        ld (tmpa),a
        ld b,4
.sd:    push bc
        ld a,(tmpa)
        ld c,a
        ld a,3
        call vel_of
        ; offset = v * 8 (about 6 px across, 4 rows)
        ld a,d
        ld b,e
        sla b
        rla
        sla b
        rla
        sla b
        rla
        add a,(ix+P_X+1)
        and 127
        ld b,a
        ld a,h
        ld c,l
        sla c
        rla
        sla c
        rla
        sla c
        rla
        add a,(ix+P_Y+1)
        call wrap_y
        ld c,a
        ld a,(col3)
        ld e,a
        call plot
        ld a,(tmpa)
        add a,4
        and 15
        ld (tmpa),a
        pop bc
        djnz .sd
        ret
