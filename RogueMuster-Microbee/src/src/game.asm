; =====================================================================
;  GAME: waves, Jo, the welder, blades, scoring, the game loop.
;
;  The paddock is 38 x 22 cells (columns 1-38, rows 2-23). Everything is
;  placed in 4-pixel units: x 0..75, y 0..43. A 12 x 12 sprite at (x, y)
;  covers units x..x+2, y..y+2, so its x runs 0..73 and y 0..41.
; =====================================================================
AX_MAX  equ 73
AY_MAX  equ 41
CX      equ 36                  ; Jo starts here
CY      equ 20

; ---- actors
NACT    equ 44
ASZ     equ 12
A_T     equ 0                   ; type
A_X     equ 1
A_Y     equ 2
A_DX    equ 3
A_DY    equ 4
A_TM    equ 5                   ; move timer
A_AN    equ 6                   ; animation
A_HP    equ 7                   ; hits left (harvester), look (station hand), value (pop-up)
A_FL    equ 8                   ; hit flash (harvester), throw pose (shearer)
A_AUX   equ 9                   ; throw / turn / effect timer
A_FACE  equ 10                  ; 0 right 1 left
A_COL   equ 11                  ; colour of an explosion

T_HEEL  equ 1
T_SHEAR equ 2
T_HARV  equ 3
T_MAG   equ 4
T_PYL   equ 5
T_HUMAN equ 6
T_BOOM  equ 7
T_POP   equ 8

NSHOT   equ 5                   ; Jo's welder bolts: on, x, y, dx, dy, first glyph
SSZ     equ 6
NBLADE  equ 6                   ; blades: on, x (8.8), y (8.8), vx, vy (16 bit), spin
BSZ     equ 10

ST_PLAY  equ 0
ST_INTRO equ 1
ST_CLEAR equ 2
ST_DYING equ 3
ST_OVER  equ 4

; ---------------------------------------------------------------------
;  the waves: heelers, shearers, harvesters, maggies, pylons, station
;  hands, heeler step time (frames), shearer throw gap (frames)
; ---------------------------------------------------------------------
wavetab:
        db 10,0,0,0,3,3, 5,0
        db 14,0,0,0,5,4, 5,0
        db 10,3,0,0,4,4, 4,90
        db 12,4,1,0,5,5, 4,80
        db 8,2,4,0,4,6, 4,80
        db 12,3,0,5,5,5, 3,70
        db 14,5,2,3,6,6, 3,60
        db 10,8,2,0,6,6, 3,50
        db 15,4,3,4,6,6, 3,50
        db 16,6,4,4,6,6, 3,40
wavetext:
        dw s_w1,s_w2,s_w3,s_w4,s_w5,s_w6,s_w7,s_w8,s_w9,s_w10
s_w1:   db "BRING THE STATION HANDS HOME",0
s_w2:   db "STEER CLEAR OF THE LIVE PYLONS",0
s_w3:   db "SHEARERS THROW WHERE YOU ARE GOING",0
s_w4:   db "A HARVESTER TAKES FOUR HITS",0
s_w5:   db "HARVEST TIME",0
s_w6:   db "THE MAGGIES ARE SWOOPING",0
s_w7:   db "THE WHOLE MOB",0
s_w8:   db "BLADES EVERYWHERE",0
s_w9:   db "KEEP MOVING, JO",0
s_w10:  db "THE BIG MUSTER",0
s_wmore: db "THEY ARE GETTING FASTER",0
s_wave: db "WAVE ",0
s_ready: db "GET READY",0
s_clear: db "PADDOCK CLEAR",0
s_over: db "GAME OVER",0
s_again: db "SPACE OR FIRE TO MUSTER AGAIN",0
s_paused: db "PAUSED",0
s_score: db "SCORE",0
s_hi:   db "HI",0
s_wv:   db "WAVE",0

typecol: db 0,BRED,BMAGENTA,YELLOW,BCYAN,BBLUE,BGREEN
typepts: dw 0,$0100,$0200,$0500,$0150,$0025

; =====================================================================
game_new:
        ld sp,STACK
        xor a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld (paused),a
        ld a,3
        ld (lives),a
        ld a,$02
        ld (nextlife),a
        ld a,$50
        ld (nextlife+1),a
        ld a,1
        ld (wave),a
        call clear_both
        call draw_fence
        call wave_setup
        ; fall into the loop
game_loop:
        call read_input
        ld a,(keysnew)
        ld (t_keys),a
        ld a,(padnew)
        ld (t_padnew),a
        call input_used
        ld a,(t_keys)
        bit 0,a
        jp nz,title
        bit 2,a
        call nz,toggle_sound
        ld a,(t_keys)
        bit 1,a
        jr z,.np
        ld a,(state)
        cp ST_OVER
        jr z,.np
        ld a,(paused)
        xor 1
        ld (paused),a
.np:    ld a,(paused)
        or a
        jr nz,.pz
        call update
        call vschk
        call sound_tick
        jr .dr
.pz:    ld hl,0
        ld (step1),hl
        ld (step2),hl
.dr:    call dl_begin
        call draw_world
        call dl_flush
        call hud_update
        call show_page
        jp game_loop

update:
        ld hl,gtick
        inc (hl)
        ld a,(state)
        or a
        jp z,play_update
        dec a
        jp z,intro_update
        dec a
        jp z,clear_update
        dec a
        jp z,dying_update
        jp over_update

play_update:
        call player_update
        call shots_update
        call blades_update
        call actors_update
        call speedup
        ld a,(state)
        or a
        ret nz
        ld a,(enemies_left)
        or a
        ret nz
        ld a,ST_CLEAR
        ld (state),a
        ld a,60
        ld (stimer),a
        call clear_missiles
        ld hl,mus_clear_0
        ld de,mus_clear_1
        jp song

intro_update:
        call actors_update
        ld hl,stimer
        dec (hl)
        ret nz
        xor a
        ld (state),a
        ld hl,mus_game_0
        ld de,mus_game_1
        jp song

clear_update:
        call actors_update
        ld hl,stimer
        dec (hl)
        ret nz
        ld hl,wave
        inc (hl)
        jp wave_setup

dying_update:
        call actors_update
        ld hl,stimer
        dec (hl)
        ret nz
        ld a,1
        ld (hud_dirty),a
        ld hl,lives
        dec (hl)
        jr z,.over
        call player_reset
        ld a,90
        ld (pinv),a
        call clear_missiles
        call scatter
        ld a,1
        ld (respawned),a
        ld a,ST_INTRO
        ld (state),a
        ld a,40
        ld (stimer),a
        ret
.over:  ld a,ST_OVER
        ld (state),a
        xor a
        ld (t_rel),a
        ld a,150
        ld (stimer),a
        call check_hi
        ld hl,mus_over_0
        ld de,mus_over_1
        jp song

over_update:
        call actors_update
        ld hl,stimer
        dec (hl)
        jp z,title
        ld a,(stimer)
        cp 125
        ret nc
        ld a,(firepad)          ; a fire key starts again once let go of
        ld b,a
        ld a,(pad)
        and 16
        or b
        jr nz,.held
        ld a,1
        ld (t_rel),a
.held:  ld a,(t_keys)
        bit 3,a
        jp nz,game_new
        ld a,(t_padnew)
        bit 4,a
        jp nz,game_new
        ld a,(t_rel)
        or a
        ret z
        ld a,b
        or a
        jp nz,game_new
        ret

; the heelers get quicker as a wave goes on
speedup:
        ld hl,(speed_t)
        dec hl
        ld (speed_t),hl
        ld a,h
        or l
        ret nz
        ld hl,150
        ld (speed_t),hl
        ld a,(heel_min)
        ld b,a
        ld a,(heel_per)
        cp b
        ret z
        ret c
        dec a
        ld (heel_per),a
        ret

clear_missiles:
        ld hl,shots
        ld de,shots+1
        ld bc,NSHOT*SSZ+NBLADE*BSZ-1
        ld (hl),0
        ldir
        ret

player_reset:
        ld a,CX
        ld (px),a
        ld a,CY
        ld (py),a
        ld a,3
        ld (pface),a
        ld (pcells),a
        xor a
        ld (lockon),a
        ld (firecd),a
        ld (mvdx),a
        ld (mvdy),a
        ld (lastdy),a
        inc a
        ld (lastdx),a
        ret

; ---------------------------------------------------------------------
;  a new wave
; ---------------------------------------------------------------------
wave_setup:
        ld hl,actors
        ld de,actors+1
        ld bc,NACT*ASZ+NSHOT*SSZ+NBLADE*BSZ-1
        ld (hl),0
        ldir
        ld a,(wave)
        dec a
        cp 10
        jr c,.r
        sub 10
.m5:    cp 5
        jr c,.m
        sub 5
        jr .m5
.m:     add a,5
.r:     ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,wavetab
        add hl,de
        ld de,w_heel
        ld bc,8
        ldir
        ld a,(wave)             ; later waves: quicker heelers, more blades
        cp 11
        jr c,.nf
        ld a,(heel_per)
        dec a
        cp 2
        jr nc,$+4
        ld a,2
        ld (heel_per),a
        ld a,(shear_gap)
        sub 10
        ld (shear_gap),a
.nf:    ld a,(wave)
        cp 6
        ld a,3
        jr c,$+3
        dec a
        ld (heel_min),a
        ld hl,150
        ld (speed_t),hl
        xor a
        ld (rescued),a
        ld (respawned),a
        call player_reset
        xor a
        ld (pinv),a
        ; the station hands, then pylons (the first ones beside them), then the mob
        ld iy,actors
        ld a,(w_hum)
        ld b,a
        ld c,T_HUMAN
        call spawn_n
        ld (pyl_ptr),iy
        ld a,(w_pyl)
        ld b,a
        ld c,T_PYL
        call spawn_n
        ld a,(w_harv)
        ld b,a
        ld c,T_HARV
        call spawn_n
        ld a,(w_shear)
        ld b,a
        ld c,T_SHEAR
        call spawn_n
        ld a,(w_mag)
        ld b,a
        ld c,T_MAG
        call spawn_n
        ld a,(w_heel)
        ld b,a
        ld c,T_HEEL
        call spawn_n
        ld a,(w_heel)
        ld hl,w_shear
        add a,(hl)
        inc hl
        add a,(hl)
        inc hl
        add a,(hl)
        ld (enemies_left),a
        ld a,ST_INTRO
        ld (state),a
        ld a,60
        ld (stimer),a
        ld a,1
        ld (hud_dirty),a
        ld hl,mus_ready_0
        ld de,mus_ready_1
        jp song

; spawn_n: B actors of type C from IY on (IY moves on)
spawn_n:
        ld a,b
        or a
        ret z
        xor a
        ld (t_n),a
.l:     push bc
        ld (iy+A_T),c
        call place
        call init_actor
        ld de,ASZ
        add iy,de
        ld hl,t_n
        inc (hl)
        pop bc
        djnz .l
        ret

place:
        ld a,(iy+A_T)
        cp T_HUMAN
        jr z,place_edge
        cp T_PYL
        jr z,place_pyl
; somewhere away from the middle, where Jo starts
place_rand:
        ld b,AX_MAX+1
        call rand_n
        ld (iy+A_X),a
        ld b,AY_MAX+1
        call rand_n
        ld (iy+A_Y),a
        ld a,(iy+A_X)
        sub CX
        call absa
        cp 13
        ret nc
        ld a,(iy+A_Y)
        sub CY
        call absa
        cp 10
        ret nc
        jr place_rand

; station hands start out near the fence, away from the safe middle
place_edge:
        call place_rand
        ld b,4
        call rand_n
        or a
        jr nz,.1
        ld b,7
        call rand_n
        ld (iy+A_X),a
        ret
.1:     dec a
        jr nz,.2
        ld b,7
        call rand_n
        add a,AX_MAX-6
        ld (iy+A_X),a
        ret
.2:     dec a
        jr nz,.3
        ld b,5
        call rand_n
        ld (iy+A_Y),a
        ret
.3:     ld b,5
        call rand_n
        add a,AY_MAX-4
        ld (iy+A_Y),a
        ret

; the first pylons stand between a station hand and the middle
place_pyl:
        ld a,(t_n)
        ld hl,w_hum
        cp (hl)
        jr nc,place_rand
        call idx_actor          ; IX = station hand t_n
        ld a,(ix+A_X)
        cp CX+1
        ld b,5
        jr c,$+4
        ld b,$FB
        add a,b
        cp AX_MAX+1
        jr c,$+5
        ld a,(ix+A_X)
        ld (iy+A_X),a
        ld b,7
        call rand_n
        sub 3
        add a,(ix+A_Y)
        cp AY_MAX+1
        jr c,$+5
        ld a,(ix+A_Y)
        ld (iy+A_Y),a
        ret

; IX = actor number A
idx_actor:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,actors
        add hl,de
        push hl
        pop ix
        ret

init_actor:
        ld a,(iy+A_T)
        ld e,a
        ld d,0
        ld hl,typecol
        add hl,de
        ld a,(hl)
        ld (iy+A_COL),a
        call random
        ld (iy+A_AN),a
        ld a,(heel_per)
        ld b,a
        call rand_n
        inc a
        ld (iy+A_TM),a
        ld a,(iy+A_T)
        cp T_SHEAR
        jr nz,.n1
        call random
        and 63
        add a,60
        ld (iy+A_AUX),a
        jp rand_dirs
.n1:    cp T_HARV
        jr nz,.n2
        ld (iy+A_HP),4
        ld (iy+A_TM),7
        ret
.n2:    cp T_MAG
        jr nz,.n3
        ld (iy+A_AUX),20
        ld (iy+A_TM),2
        call random
        and 1
        add a,a
        dec a
        ld (iy+A_DX),a
        call random
        and 1
        add a,a
        dec a
        ld (iy+A_DY),a
        ret
.n3:    cp T_HUMAN
        ret nz
        call random
        and 1
        ld (iy+A_HP),a
        ld (iy+A_AUX),1
        ld (iy+A_TM),8
        ret

; A_DX, A_DY = -1, 0 or 1 at random
rand_dirs:
        ld b,3
        call rand_n
        dec a
        ld (iy+A_DX),a
        ld b,3
        call rand_n
        dec a
        ld (iy+A_DY),a
        ret

; after Jo goes down: the mob is scattered again away from the middle
scatter:
        ld iy,actors
        ld b,NACT
.l:     push bc
        ld a,(iy+A_T)
        cp T_PYL
        jr nc,.n
        or a
        jr z,.n
        call place_rand
.n:     ld de,ASZ
        add iy,de
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
;  Jo
; ---------------------------------------------------------------------
; dir_of: A = R L U D bits -> D = dx, E = dy
dir_of: ld d,0
        ld e,0
        bit 0,a
        jr z,$+3
        inc d
        bit 1,a
        jr z,$+3
        dec d
        bit 2,a
        jr z,$+3
        dec e
        bit 3,a
        jr z,$+3
        inc e
        ret

player_update:
        ld a,(pad)
        call dir_of
        ld a,d
        ld (mvdx),a
        ld a,e
        ld (mvdy),a
        ld a,(px)
        add a,d
        cp AX_MAX+1
        jr nc,.nx
        ld (px),a
.nx:    ld a,(py)
        add a,e
        cp AY_MAX+1
        jr nc,.ny
        ld (py),a
.ny:    ld a,d
        or e
        jr z,.still
        ld a,(lockon)
        or a
        jr nz,.nl
        ld a,d
        ld (lastdx),a
        ld a,e
        ld (lastdy),a
.nl:    ld a,d
        or a
        jr z,.vert
        rlca
        and 1                   ; 0 right, 1 left
        jr .face
.vert:  ld a,e
        rlca
        and 1
        xor 3                   ; down 3, up 2
.face:  ld (pface),a
        ld hl,panim
        inc (hl)
.still: ; the welder: I J K L / arrows aim; SPACE or the joystick fire
        ; button shoots the way Jo faced when it went down
        ld a,(firepad)
        call dir_of
        ld a,d
        or e
        jr nz,.fire
        ld a,(pad)
        bit 4,a
        jr z,.nofb
        ld a,(lockon)
        or a
        jr nz,.lk
        inc a
        ld (lockon),a
        ld a,(lastdx)
        ld (lockdx),a
        ld a,(lastdy)
        ld (lockdy),a
.lk:    ld a,(lockdx)
        ld d,a
        ld a,(lockdy)
        ld e,a
        jr .fire
.nofb:  xor a
        ld (lockon),a
        jr .cd
.fire:  ld a,(firecd)
        or a
        call z,spawn_shot
.cd:    ld a,(firecd)
        or a
        jr z,.ci
        dec a
        ld (firecd),a
.ci:    ld a,(pinv)
        or a
        ret z
        dec a
        ld (pinv),a
        ret

; spawn_shot: D, E = direction
spawn_shot:
        ld a,d
        ld (t_dx),a
        ld a,e
        ld (t_dy),a
        ld ix,shots
        ld b,NSHOT
        ld de,SSZ
.f:     ld a,(ix+0)
        or a
        jr z,.got
        add ix,de
        djnz .f
        ret
.got:   ld a,(t_dx)
        ld (ix+3),a
        ld c,a
        ld a,(t_dy)
        ld (ix+4),a
        ld b,a
        or a
        ld a,0                  ; level: across
        jr z,.k
        ld a,c
        or a
        ld a,1                  ; up and down
        jr z,.k
        ld a,c
        cp b
        ld a,2                  ; \ diagonal
        jr z,.k
        ld a,3                  ; / diagonal
.k:     add a,a
        add a,a
        add a,G_SHOT
        ld (ix+5),a
        ld a,(px)
        inc a
        ld (ix+1),a
        ld a,(py)
        inc a
        ld (ix+2),a
        ld (ix+0),1
        ld a,3
        ld (firecd),a
        ld a,SFX_FIRE
        jp play_sfx

player_hit:
        ld a,(pinv)
        or a
        ret nz
        ld a,(state)
        or a
        ret nz
        ld a,50
        ld (pinv),a
        ld a,1
        ld (hud_dirty),a
        ld hl,pcells
        dec (hl)
        jr z,.die
        ld a,SFX_HURT
        jp play_sfx
.die:   ld a,ST_DYING
        ld (state),a
        ld a,50
        ld (stimer),a
        call stop_music
        ld a,SFX_DIE
        jp play_sfx

; ---------------------------------------------------------------------
;  welder bolts
; ---------------------------------------------------------------------
shots_update:
        ld ix,shots
        ld b,NSHOT
.l:     push bc
        ld a,(ix+0)
        or a
        call nz,shot_one
        call vschk
        ld de,SSZ
        add ix,de
        pop bc
        djnz .l
        ret

shot_one:
        ld a,(ix+1)
        add a,(ix+3)
        add a,(ix+3)
        add a,(ix+3)
        cp 76
        jp nc,.off
        ld (ix+1),a
        ld (t_sx),a
        ld a,(ix+2)
        add a,(ix+4)
        add a,(ix+4)
        add a,(ix+4)
        cp 44
        jp nc,.off
        ld (ix+2),a
        ld (t_sy),a
        ; robots (HL walks the actor table: quicker than IY)
        ld a,(t_sx)
        inc a
        ld c,a                  ; C = bolt x + 1
        ld hl,actors
        ld b,NACT
        ld de,ASZ
.l:     ld a,(hl)
        dec a
        cp T_PYL
        jr nc,.n
        inc hl
        ld a,c
        sub (hl)
        cp 4
        jr nc,.n1
        inc hl
        ld a,(t_sy)
        inc a
        sub (hl)
        cp 4
        jr nc,.n2
        dec hl
        dec hl
        push hl
        pop iy
        ld (ix+0),0
        jp hit_actor
.n2:    dec hl
.n1:    dec hl
.n:     add hl,de
        djnz .l
        ; blades can be shot down
        ld iy,blades
        ld b,NBLADE
.b:     ld a,(iy+0)
        or a
        jr z,.bn
        ld a,(t_sx)
        sub (iy+2)
        inc a
        cp 3
        jr nc,.bn
        ld a,(t_sy)
        sub (iy+4)
        inc a
        cp 3
        jr nc,.bn
        ld (iy+0),0
        ld (ix+0),0
        ld a,SFX_CLINK
        jp play_sfx
.bn:    ld de,BSZ
        add iy,de
        djnz .b
        ret
.off:   ld (ix+0),0
        ret

; hit_actor: bolt IX hit robot IY
hit_actor:
        ld a,(iy+A_T)
        cp T_HARV
        jr nz,kill_actor
        ld a,(ix+3)             ; a harvester is knocked back and takes 4
        add a,(iy+A_X)
        cp AX_MAX+1
        jr nc,.kx
        ld (iy+A_X),a
.kx:    ld a,(ix+4)
        add a,(iy+A_Y)
        cp AY_MAX+1
        jr nc,.ky
        ld (iy+A_Y),a
.ky:    ld (iy+A_FL),4
        dec (iy+A_HP)
        jr z,kill_actor
        ld a,SFX_THUD
        jp play_sfx

; kill_actor: robot IY is destroyed (scores, explodes)
kill_actor:
        ld a,(iy+A_T)
        push af
        add a,a
        ld e,a
        ld d,0
        ld hl,typepts
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        call add_score
        ld (iy+A_T),T_BOOM
        ld (iy+A_AUX),0
        pop af
        cp T_PYL
        jr z,.pyl
        ld hl,enemies_left
        dec (hl)
        cp T_HARV
        ld a,SFX_BIGKILL
        jp z,play_sfx
.pyl:   ld a,SFX_KILL
        jp play_sfx

; ---------------------------------------------------------------------
;  shearers' blades
; ---------------------------------------------------------------------
blades_update:
        ld ix,blades
        ld b,NBLADE
.l:     push bc
        ld a,(ix+0)
        or a
        call nz,blade_one
        ld de,BSZ
        add ix,de
        pop bc
        djnz .l
        ret

blade_one:
        inc (ix+9)
        ld l,(ix+1)
        ld h,(ix+2)
        ld e,(ix+5)
        ld d,(ix+6)
        add hl,de
        ld a,h
        cp 76
        jr nc,.off
        ld (ix+1),l
        ld (ix+2),h
        ld l,(ix+3)
        ld h,(ix+4)
        ld e,(ix+7)
        ld d,(ix+8)
        add hl,de
        ld a,h
        cp 44
        jr nc,.off
        ld (ix+3),l
        ld (ix+4),h
        ld a,(pinv)
        or a
        ret nz
        ld a,(ix+2)
        ld hl,px
        sub (hl)
        cp 3
        ret nc
        ld a,(ix+4)
        ld hl,py
        sub (hl)
        cp 3
        ret nc
        ld (ix+0),0
        jp player_hit
.off:   ld (ix+0),0
        ret

; throw_blade: shearer IY throws at where Jo is heading
throw_blade:
        ld ix,blades
        ld b,NBLADE
        ld de,BSZ
.f:     ld a,(ix+0)
        or a
        jr z,.g
        add ix,de
        djnz .f
        ret
.g:     ld a,(mvdx)             ; aim 8 steps ahead of Jo
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(px)
        add a,b
        sub (iy+A_X)
        ld d,a
        ld a,(mvdy)
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(py)
        add a,b
        sub (iy+A_Y)
        ld e,a
        call cheb
        or a
        jr nz,$+3
        inc a
        ld c,a
        ld a,(blade_spd)
        ld l,a
        ld h,1                  ; speed: 1.25 units a frame (+ a little later on)
        call div16_8
        push hl
        ld a,d
        call mul_s8_16
        ld (ix+5),l
        ld (ix+6),h
        pop hl
        ld a,e
        call mul_s8_16
        ld (ix+7),l
        ld (ix+8),h
        ld a,(iy+A_X)
        inc a
        ld (ix+2),a
        ld (ix+1),$80
        ld a,(iy+A_Y)
        inc a
        ld (ix+4),a
        ld (ix+3),$80
        ld (ix+0),1
        ld (ix+9),0
        ld (iy+A_FL),8
        ld a,SFX_BLADE
        jp play_sfx

; ---------------------------------------------------------------------
;  arithmetic
; ---------------------------------------------------------------------
sgn:    or a
        ret z
        jp m,.n
        ld a,1
        ret
.n:     ld a,$FF
        ret
absa:   or a
        ret p
        neg
        ret
; cheb: D, E signed -> A = max(|D|, |E|). Keeps DE.
cheb:   ld a,d
        call absa
        ld b,a
        ld a,e
        call absa
        cp b
        ret nc
        ld a,b
        ret
; div16_8: HL / C -> HL (A = remainder)
div16_8:
        push bc
        xor a
        ld b,16
.l:     add hl,hl
        rla
        jr c,.s
        cp c
        jr c,.n
.s:     sub c
        inc l
.n:     djnz .l
        pop bc
        ret
; mul_s8_16: A (signed) x HL -> HL (signed). Keeps BC, DE.
mul_s8_16:
        push de
        push bc
        ld b,a
        or a
        jp p,.p
        neg
.p:     ex de,hl
        ld hl,0
        ld c,8
.l:     add hl,hl
        add a,a
        jr nc,.n
        add hl,de
.n:     dec c
        jr nz,.l
        bit 7,b
        jr z,.x
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
.x:     pop bc
        pop de
        ret

; ---------------------------------------------------------------------
;  score
; ---------------------------------------------------------------------
; add_score: DE = 4 BCD digits
add_score:
        push hl
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
        ; an extra life every 25000
        ld a,(score)
        ld hl,nextlife
        cp (hl)
        jr c,.no
        jr nz,.yes
        ld a,(score+1)
        inc hl
        cp (hl)
        jr c,.no
.yes:   ld hl,nextlife+1
        ld a,(hl)
        add a,$50
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,$02
        daa
        ld (hl),a
        ld a,(lives)
        cp 9
        jr nc,.no
        inc a
        ld (lives),a
        ld a,SFX_LIFE
        call play_sfx
.no:    pop hl
        ret

check_hi:
        ld hl,score
        ld de,hiscore
        ld b,3
.c:     ld a,(de)
        cp (hl)
        jr c,.new
        ret nz
        inc hl
        inc de
        djnz .c
        ret
.new:   ld hl,score
        ld de,hiscore
        ld bc,3
        ldir
        ret

; ---------------------------------------------------------------------
;  the HUD (row 0) and the fence, on both pages
; ---------------------------------------------------------------------
hud_update:
        ld a,(hud_dirty)
        or a
        ret z
        xor a
        ld (hud_dirty),a
        ld hl,s_score
        ld de,0
        ld c,GREY
        call text_both
        ld hl,score
        ld de,6
        ld c,WHITE
        call bcd_both
        ld hl,s_hi
        ld de,14
        ld c,GREY
        call text_both
        ld hl,hiscore
        ld de,17
        ld c,BCYAN
        call bcd_both
        ld hl,s_wv
        ld de,25
        ld c,GREY
        call text_both
        ld a,(wave)
        ld b,0
.t:     cp 10
        jr c,.u
        sub 10
        inc b
        jr .t
.u:     push af
        ld a,b
        ld de,30
        ld c,YELLOW
        call digit_both
        pop af
        call digit_both
        ld hl,33
        ld b,G_LIFE
        ld c,WHITE
        call put_both
        ld a,(lives)
        ld de,34
        ld c,WHITE
        call digit_both
        ; charge cells
        ld a,(pcells)
        ld (t_k),a
        ld hl,36
.p:     push hl
        ld b,G_PIP
        ld c,YELLOW
        ld a,(t_k)
        or a
        jr nz,.on
        ld b,G_PIPOFF
        ld c,DGREY
        inc a
.on:    dec a
        ld (t_k),a
        call put_both
        pop hl
        inc hl
        ld a,l
        cp 39
        jr nz,.p
        ret

draw_fence:
        xor a
        ld (t_k),a
.top:   ld a,(t_k)
        ld b,G_WIRE
        and 3
        jr nz,$+4
        ld b,G_POST
        ld a,(t_k)
        or a
        jr z,.cor
        cp 39
        jr nz,.nc
.cor:   ld b,G_CORNER
.nc:    ld c,BROWN
        ld a,(t_k)
        ld l,a
        ld h,0
        ld de,40
        add hl,de
        push hl
        call put_both
        pop hl
        ld de,920
        add hl,de
        call put_both
        ld hl,t_k
        inc (hl)
        ld a,(hl)
        cp 40
        jr nz,.top
        ld a,2
        ld (t_k),a
.sd:    ld b,G_SIDE
        and 3
        jr nz,$+4
        ld b,G_SIDEP
        ld c,BROWN
        ld a,(t_k)
        call row_off
        push hl
        call put_both
        pop hl
        ld de,39
        add hl,de
        call put_both
        ld hl,t_k
        inc (hl)
        ld a,(hl)
        cp 24
        jr nz,.sd
        ld a,1
        ld (hud_dirty),a
        ret

; ---------------------------------------------------------------------
;  sound on / effects only / off (M)
; ---------------------------------------------------------------------
toggle_sound:
        ld a,(soundmode)
        dec a
        jp p,$+5
        ld a,2
        ld (soundmode),a
        ld a,SFX_MENU
        call play_sfx
apply_sound:
        ld a,(soundmode)
        cp 2
        ld a,0
        jr nz,$+3
        inc a
        ld (musicon),a
        or a
        call z,stop_music
        ld a,(soundmode)
        or a
        ld a,0
        jr z,$+3
        inc a
        ld (sfxon),a
        ld a,(musicon)
        or a
        ret z
        ld hl,(want0)
        ld de,(want1)
        jp play_music

; song: HL, DE = the two channels (remembered for sound back on)
song:   ld (want0),hl
        ld (want1),de
        jp play_music
