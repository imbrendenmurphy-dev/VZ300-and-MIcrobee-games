; =====================================================================
;  HAMBURGER SAM II - the game: Sam, pepper, the chasers, bonus items,
;  death and celebration, the demo autopilot, the kitchen loop
; =====================================================================
SAM_SPD   equ 196
R_CLEAR   equ 0
R_OVER    equ 1
R_QUIT    equ 2
R_START   equ 3
R_TIMEOUT equ 4

; background music only in "music + SFX" mode
bgm:
        ld a,(soundmode)
        cp 2
        jp nz,stop_music
        jp play_music
; jingles play in modes 1 and 2
jingle:
        ld a,(soundmode)
        or a
        ret z
        jp play_music
game_music:
        ld hl,mus_game_0
        ld de,mus_game_1
        jr bgm

; ---------------------------------------------------------------------
; new game: A = first kitchen (0-7), playclassic set by caller
; ---------------------------------------------------------------------
start_game:
        ld (kitchen),a
        ld a,1
        ld (mode),a
        xor a
        ld (lap),a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ld a,1
        ld (nextlife),a
        ld a,4
        ld (lives),a            ; 4 cooks and 6 peppers, like 1984
        ld a,6
        ld (peppers),a
.k:     call kitchen_card
        call play_kitchen
        cp R_CLEAR
        jr nz,.end
        ld a,(peppers)          ; an extra pepper every kitchen
        cp 9
        jr nc,.p
        inc a
        ld (peppers),a
.p:     ld a,(playclassic)
        or a
        jr z,.nx
        ld a,(lap)
        inc a
        ld (lap),a
        jr .k
.nx:    ld a,(kitchen)
        inc a
        ld (kitchen),a
        ld b,a
        ld a,(maxkit)
        cp b
        jr nc,.m
        ld a,b
        cp NKITCHEN+1
        jr nc,.m
        ld (maxkit),a
        call save_records
.m:     ld a,(kitchen)
        and 1
        jr nz,.nb
        call order_up           ; after every second kitchen
.nb:    ld a,(kitchen)
        cp NKITCHEN
        jr nz,.k
        call ending
        xor a
        ld (kitchen),a
        ld a,(lap)
        inc a
        ld (lap),a
        jr .k
.end:   cp R_QUIT
        jp z,attract
        call game_over
        call enter_hiscore
        jp attract

; ---------------------------------------------------------------------
; play_kitchen -> A = R_CLEAR / R_OVER / R_QUIT (game), R_START / R_TIMEOUT (demo)
; ---------------------------------------------------------------------
play_kitchen:
        ld a,(playclassic)
        or a
        ld a,8
        jr nz,.c
        ld a,(kitchen)
.c:     call load_kitchen
        xor a
        ld (it_seq),a
        ld (spawnidx),a
        ld (rosteri),a
        ld (pausef),a
        ld (ai_tgt),a
        ; chaser speeds: base + kitchen + lap
        ld a,(lap)
        add a,a
        add a,a
        ld b,a
        add a,a
        add a,a
        add a,b                 ; lap*20
        ld b,a
        ld a,(lvh+LV_SPD)
        add a,b
        ld c,a
        ld hl,espd_base
        ld de,espeed
        ld b,4
.sp:    ld a,(hl)
        add a,c
        jr nc,.s1
        ld a,236
.s1:    cp 236
        jr c,.s2
        ld a,236
.s2:    ld (de),a
        inc hl
        inc de
        djnz .sp
        ld a,(lap)
        or a
        ld a,170
        jr z,.st
        ld a,130
.st:    ld (stuntime),a
        xor a
        ld (pop_w),a
        ld (pop_tim),a
        call bgobjs_reset
        xor a
        ld (texttrans),a        ; kitchens: solid HUD/popups
        call draw_kitchen
        call setup_round
        call clear_erase
        call wipe_show
        ld a,16                 ; leave vblank time for the sprites
        ld (cbudget),a
        ld a,1
        ld (cbexact),a          ; keep_compute sets the budget each frame
        call game_music
.loop:  call game_frame
        cp $FF
        jr z,.loop
        push af
        ld a,28
        ld (cbudget),a
        xor a
        ld (cbexact),a
        call stop_music
        pop af
        ret
espd_base: db 140,128,152,186   ; hot dog, egg, pickle, chilli

setup_round:
        ld a,(lvh+LV_SAMX)
        ld (sx),a
        ld a,(lvh+LV_SAMF)
        ld (sf),a
        call fyrow
        dec a
        ld (sy),a
        xor a
        ld (sface),a
        ld (sst),a
        ld (stim),a
        ld (sacc),a
        ld (sanim),a
        ld (pep_tim),a
        ld (throwtim),a
        ld (spk_tim),a
        ld (it_on),a
        ld a,$FF
        ld (ai_tf),a
        ld a,2
        ld (svert),a
        ld iy,enemies
        ld b,MAXEN
        ld c,40
.e:     ld (iy+E_ST),0
        ld (iy+E_TIM),c
        ld a,c
        add a,70
        ld c,a
        ld de,ESIZE
        add iy,de
        djnz .e
        ld a,2
        ld (hudflag),a
        ret

; ---------------------------------------------------------------------
; one frame of play -> A = $FF to continue, else a result code
; ---------------------------------------------------------------------
game_frame:
        call dl_reset
        ld a,(mode)
        cp 2
        jr nz,.notdemo
        call check_start
        ld a,R_START
        ret nz
        ld hl,(gtim)
        dec hl
        ld (gtim),hl
        ld a,h
        or l
        ld a,R_TIMEOUT
        ret z
        jr .play
.notdemo:
        ld a,(keysnew)
        bit 1,a
        jp nz,do_pause
        bit 0,a
        call nz,cycle_sound
.play:  ld a,(sst)
        or a
        jr nz,.s1
        call sam_control
        call pepper_update
        call enemies_update
        call item_update
        call sam_hit
        jr .pc
.s1:    cp 1
        jr nz,.s2
        call death_update
        cp $FF
        ret nz
        jr .pc
.s2:    ld a,(stim)
        inc a
        ld (stim),a
        cp 130
        ld a,R_CLEAR
        ret z
.pc:    call update_pieces
        ; kitchen cleared?
        ld a,(sst)
        or a
        jr nz,.dr
        ld a,(lvh+LV_NCOL)
        ld b,a
        ld a,(burgers)
        cp b
        jr nz,.dr
        ld a,(sx)               ; cheer pose is byte-aligned
        add a,2
        and $FC
        ld (sx),a
        ld a,2
        ld (sst),a
        xor a
        ld (stim),a
        ld (pep_tim),a
        ld a,(mode)
        cp 2
        ld a,R_TIMEOUT
        ret z
        ld hl,mus_clear_0
        ld de,mus_clear_1
        call jingle
.dr:    call draw_sprites
        ld a,(hudflag)
        or a
        jr z,.nh
        ld b,a
        xor a
        ld (hudflag),a
        bit 1,b
        call nz,draw_hud
        bit 1,b
        call z,draw_score
.nh:    call keep_compute
        call do_frame
        ld a,$FF
        ret

do_pause:
        ld a,SFX_BLIP
        call play_sfx
        ; the HUD line says so (through the BG + commit queue, snow-free)
        ld a,1
        ld (noq),a
        ld de,$0000
        ld bc,$2006
        xor a
        call fill_rect
        ld a,1
        ld b,0
        call set_ink
        ld hl,s_paused
        ld e,0
        call print_c
        xor a
        ld (noq),a
        ld de,$0000
        ld bc,$2006
        call queue_rect
.l:     call dl_reset
        call draw_sprites_frozen
        call keep_compute
        call do_frame
        ld a,(keysnew)
        bit 3,a
        ld a,R_QUIT
        ret nz
        ld a,(keysnew)
        bit 1,a
        jr z,.l
        xor a
        ld (keysnew),a          ; don't let this P pause us again
        ld a,2
        ld (hudflag),a
        ld a,$FF
        ret
s_paused: db "PAUSED - P TO GO ON, X TO QUIT",0
; same sprites as last frame, nothing moves
draw_sprites_frozen:
        ld a,(pop_tim)          ; let draw_sprites do the work, popup clock held
        push af
        ld a,(spk_tim)
        push af
        call draw_sprites
        pop af
        ld (spk_tim),a
        pop af
        ld (pop_tim),a
        ret

cycle_sound:
        ld a,(soundmode)
        dec a
        jp p,.s
        ld a,2
.s:     ld (soundmode),a
        cp 2
        jp nz,stop_music
        ld a,(sst)
        or a
        ret nz
        jp game_music

; ---------------------------------------------------------------------
; Sam
; ---------------------------------------------------------------------
sam_control:
        ld a,(mode)
        cp 2
        jr z,.ai
        ld a,(autoplay)
        or a
        jr nz,.ai
        ld a,(inp)
        ld (pad),a
        ld a,(inpnew)
        ld (padnew),a
        ld a,($6FFB)            ; SHIFT throws pepper too (as in 1984)
        bit 2,a
        jr nz,.go
        ld a,(pad)
        set 4,a
        ld (pad),a
        ld a,(shiftold)
        or a
        jr nz,.go2
        ld a,(padnew)
        set 4,a
        ld (padnew),a
.go2:   ld a,1
        ld (shiftold),a
        jr .mv
.go:    xor a
        ld (shiftold),a
        jr .mv
.ai:    call ai_control
.mv:    ld a,(throwtim)
        or a
        jr z,.t
        dec a
        ld (throwtim),a
.t:     ld a,(padnew)
        bit 4,a
        call nz,throw_pepper
        ld a,(sacc)
        add a,SAM_SPD
        ld (sacc),a
        jp nc,sam_press
        ld a,(pad)
        ld c,a
        ld a,(sf)
        cp $FF
        jp z,.ladder
        ; ---- on a floor
        bit 2,c
        jr z,.nu
        ld e,2
        call ladder_near
        jr nc,.nu
        ld (sx),a
        ld a,(sf)
        dec a
        ld (slf),a
        ld a,$FF
        ld (sf),a
        ld a,1
        ld (svert),a
        ld hl,sy
        dec (hl)
        jp .moved
.nu:    bit 3,c
        jr z,.nd
        ld e,1
        call ladder_near
        jr nc,.nd
        ld (sx),a
        ld a,(sf)
        ld (slf),a
        ld a,$FF
        ld (sf),a
        ld a,2
        ld (svert),a
        ld hl,sy
        inc (hl)
        jp .moved
.nd:    bit 0,c
        jr z,.nr
        xor a
        ld (sface),a
        ld a,(sx)
        inc a
        ld b,a
        ld a,(sf)
        call walkable
        jp z,sam_press
        ld a,b
        ld (sx),a
        jp .moved
.nr:    bit 1,c
        jp z,sam_press
        ld a,1
        ld (sface),a
        ld a,(sx)
        or a
        jp z,sam_press
        dec a
        ld b,a
        ld a,(sf)
        call walkable
        jp z,sam_press
        ld a,b
        ld (sx),a
        jr .moved
        ; ---- on a ladder
.ladder:
        ld a,(slf)
        call fyrow
        dec a
        ld d,a                  ; top foot row
        ld a,(slf)
        inc a
        call fyrow
        dec a
        ld e,a                  ; bottom foot row
        ld a,c
        and $0C
        jr nz,.ud
        ld a,c
        and $03
        jp z,sam_press
        ; left/right on a ladder: slide to the nearer floor (cornering)
        ld a,(sy)
        sub d
        ld b,a
        ld a,e
        ld hl,sy
        sub (hl)
        cp b
        ld c,4
        jr nc,.ud
        ld c,8
.ud:    ld hl,sy
        bit 2,c
        jr z,.dn
        ld a,1
        ld (svert),a
        ld a,(hl)
        cp d
        jr z,.at
        dec (hl)
        jr .at
.dn:    ld a,2
        ld (svert),a
        ld a,(hl)
        cp e
        jr z,.at
        inc (hl)
.at:    ld a,(hl)
        cp d
        jr nz,.a2
        ld a,(slf)
        ld (sf),a
        jr .moved
.a2:    cp e
        jr nz,.moved
        ld a,(slf)
        inc a
        ld (sf),a
.moved: ld hl,sanim
        inc (hl)
        jp sam_press

; ladder_near: E = 1 down / 2 up -> carry set and A = ladder x if one is within 3 px of Sam
ladder_near:
        ld a,(sx)
        and 3
        ld d,a
        ld a,(sx)
        and $FC
        ld b,a
        ld a,d
        cp 3
        jr nc,.hi
        ld a,(sf)
        call ladder_at
        jr nz,.yes
        ld a,d
        or a
        jr z,.no
        ld a,b
        add a,4
        ld b,a
        ld a,(sf)
        call ladder_at
        jr nz,.yes
        jr .no
.hi:    ld a,b
        add a,4
        ld b,a
        ld a,(sf)
        call ladder_at
        jr nz,.yes
        ld a,b
        sub 4
        ld b,a
        ld a,(sf)
        call ladder_at
        jr nz,.yes
.no:    or a
        ret
.yes:   ld a,b
        scf
        ret

throw_pepper:
        ld a,(pep_tim)
        or a
        ret nz
        ld a,(peppers)
        or a
        jr nz,.ok
        ld a,SFX_EMPTY
        jp play_sfx
.ok:    dec a
        ld (peppers),a
        ld a,2
        ld (hudflag),a
        ld a,22
        ld (pep_tim),a
        ld a,10
        ld (throwtim),a
        ld a,SFX_PEPPER
        call play_sfx
        ld a,(sf)
        cp $FF
        jr z,.lad
        ld a,(sy)
        ld (pep_y),a
        ld a,(sface)
        or a
        ld a,(sx)
        jr nz,.left
        add a,9
        cp 117
        jr c,.px
        ld a,116
        jr .px
.left:  sub 9
        jr nc,.px
        xor a
.px:    ld (pep_x),a
        ret
.lad:   ld a,(sx)
        ld (pep_x),a
        ld a,(svert)
        cp 1
        ld a,(sy)
        jr nz,.pd
        sub 9
        cp 13
        jr nc,.py
        ld a,13
        jr .py
.pd:    add a,9
        cp 57
        jr c,.py
        ld a,56
.py:    ld (pep_y),a
        ret

pepper_update:
        ld a,(pep_tim)
        or a
        ret z
        dec a
        ld (pep_tim),a
        ld iy,enemies
        ld b,MAXEN
.l:     ld a,(iy+E_ST)
        cp 1
        jr nz,.nx
        ld a,(pep_x)
        sub (iy+E_X)
        call absa
        cp 8
        jr nc,.nx
        ld a,(pep_y)
        sub (iy+E_Y)
        call absa
        cp 7
        jr nc,.nx
        ld (iy+E_ST),2
        ld a,(stuntime)
        ld (iy+E_TIM),a
        ld a,SFX_STUN
        call play_sfx
.nx:    ld de,ESIZE
        add iy,de
        djnz .l
        ret

absa:   or a
        ret p
        neg
        ret

; caught?
sam_hit:
        ld a,(godmode)
        or a
        ret nz
        ld a,(mode)
        cp 2
        ret z                   ; the demo cook can't be caught
        ld iy,enemies
        ld b,MAXEN
.l:     ld a,(iy+E_ST)
        cp 1
        jr nz,.nx
        ld a,(sx)
        sub (iy+E_X)
        call absa
        cp 5
        jr nc,.nx
        ld a,(sy)
        sub (iy+E_Y)
        call absa
        cp 5
        jr c,sam_die
.nx:    ld de,ESIZE
        add iy,de
        djnz .l
        ret

sam_die:
        ld a,(sx)               ; the dizzy/fall poses are byte-aligned
        add a,2
        and $FC
        ld (sx),a
        ld a,1
        ld (sst),a
        xor a
        ld (stim),a
        ld (pep_tim),a
        call stop_music
        ld a,SFX_CAUGHT
        call play_sfx
        ret

; dizzy spin, then Sam falls off the girders (as the 1984 instructions say)
death_update:
        ld a,(stim)
        inc a
        ld (stim),a
        cp 40
        jr nz,.n1
        ld hl,mus_die_0
        ld de,mus_die_1
        call jingle
.n1:    ld a,(stim)
        cp 70
        jr c,.wait
        ld a,(sy)
        add a,2
        ld (sy),a
        cp 66
        jr c,.wait
        ; down and out
        ld a,(mode)
        cp 2
        ld a,R_TIMEOUT
        ret z
        ld a,(lives)
        dec a
        ld (lives),a
        ld a,2
        ld (hudflag),a
        ld a,(lives)
        or a
        ld a,R_OVER
        ret z
        call setup_round
        call game_music
.wait:  ld a,$FF
        ret

; ---------------------------------------------------------------------
; chasers
; ---------------------------------------------------------------------
enemies_update:
        xor a
        ld (movers),a
        ; how many are about?
        ld iy,enemies
        ld b,MAXEN
        ld c,0
.cn:    ld a,(iy+E_ST)
        or a
        jr z,.cz
        inc c
.cz:    ld de,ESIZE
        add iy,de
        djnz .cn
        ld a,c
        ld (tmpa),a
        ld iy,enemies
        ld b,MAXEN
.l:     push bc
        ld a,(iy+E_ST)
        or a
        jr nz,.s1
        ld a,(iy+E_TIM)
        or a
        jr z,.sp
        dec (iy+E_TIM)
        jp .nx
.sp:    ld a,(lvh+LV_MAXEN)
        ld b,a
        ld a,(tmpa)
        cp b
        jp nc,.nx
        call spawn_enemy
        jp .nx
.s1:    cp 1
        jr nz,.s2
        ; half the gang moves on even frames, half on odd (two steps' worth),
        ; so the other half can stay on screen untouched
        ld a,iyl
        and $10
        ld b,a
        ld a,(framecount)
        rlca
        rlca
        rlca
        rlca
        and $10
        cp b
        jr nz,.nx
        ld a,(movers)           ; at most two chasers redrawn per frame
        cp 2
        jr nc,.nx
        ld a,(iy+E_X)
        ld (tmpx),a
        ld a,(iy+E_Y)
        ld (tmpy),a
        call .mv2
        ld a,(iy+E_X)
        ld hl,tmpx
        cp (hl)
        jr nz,.cnt
        ld a,(iy+E_Y)
        ld hl,tmpy
        cp (hl)
        jr z,.nx
.cnt:   ld hl,movers
        inc (hl)
        jr .nx
.mv2:   ld a,(iy+E_ACC)
        add a,(iy+E_SPD)
        ld (iy+E_ACC),a
        jr nc,.s1b
        inc (iy+E_ANIM)
        call enemy_step
.s1b:   ld a,(iy+E_ST)
        cp 1
        ret nz
        ld a,(iy+E_ACC)
        add a,(iy+E_SPD)
        ld (iy+E_ACC),a
        ret nc
        inc (iy+E_ANIM)
        jp enemy_step
.s2:    cp 2
        jr nz,.s4
        dec (iy+E_TIM)
        jr nz,.nx
        ld (iy+E_ST),1
        jr .nx
.s4:    cp 4
        jr nz,.nx
        dec (iy+E_TIM)
        jr nz,.nx
        ld (iy+E_ST),0
        ld b,100
        call rand_n
        add a,90
        ld (iy+E_TIM),a
.nx:    ld de,ESIZE
        add iy,de
        pop bc
        dec b
        jp nz,.l
        ret

spawn_enemy:
        ld a,(spawnidx)
        inc a
        ld (spawnidx),a
        dec a
        and 3
        add a,a
        ld hl,lvh+LV_SPAWN
        call idx_ptr
        ld b,(hl)               ; x
        inc hl
        ld c,(hl)               ; floor
        ; not right on top of Sam
        ld a,(sf)
        cp c
        jr nz,.ok
        ld a,(sx)
        sub b
        call absa
        cp 28
        jr nc,.ok
        ld (iy+E_TIM),12
        ret
.ok:    ld (iy+E_X),b
        ld (iy+E_F),c
        ld a,c
        call fyrow
        dec a
        ld (iy+E_Y),a
        ld a,(rosteri)
        ld hl,lvh+LV_ROST
        call idx_byte
        ld (iy+E_T),a
        ld hl,espeed
        call idx_byte
        ld (iy+E_SPD),a
        ld a,(rosteri)
        inc a
        cp 6
        jr c,.r
        xor a
.r:     ld (rosteri),a
        xor a
        ld (iy+E_ACC),a
        ld (iy+E_DY),a
        ld (iy+E_ANIM),a
        ld a,b
        cp 60
        ld a,1
        ld c,0
        jr c,.d
        ld a,-1
        ld c,1
.d:     ld (iy+E_DX),a
        ld (iy+E_FACE),c
        ld (iy+E_ST),1
        ld a,(tmpa)
        inc a
        ld (tmpa),a
        ret

; one pixel of movement for IY
enemy_step:
        ld a,(iy+E_F)
        cp $FF
        jr nz,.floor
        ; climbing
        ld a,(iy+E_Y)
        add a,(iy+E_DY)
        ld (iy+E_Y),a
        ld b,a
        ld a,(iy+E_LF)
        call fyrow
        dec a
        cp b
        jr nz,.c2
        ld a,(iy+E_LF)
        ld (iy+E_F),a
        jp enemy_decide
.c2:    ld a,(iy+E_LF)
        inc a
        call fyrow
        dec a
        cp b
        ret nz
        ld a,(iy+E_LF)
        inc a
        ld (iy+E_F),a
        jp enemy_decide
.floor: ; at a junction, or blocked, or idle -> decide
        ld a,(iy+E_DX)
        or (iy+E_DY)
        jr z,.dec
        ld a,(iy+E_TIM)         ; just decided here: don't decide again
        or a
        jr z,.jn
        ld (iy+E_TIM),0
        jr .blk
.jn:    ld a,(iy+E_X)
        and 3
        jr nz,.blk
        ld a,(iy+E_X)
        add a,4
        rrca
        rrca
        and $3F
        ld c,a
        ld a,(iy+E_F)
        call nodeaddr
        ld a,(hl)
        and 3
        jr nz,.dec
.blk:   ld a,(iy+E_DY)
        or a
        jr nz,.go
        ld a,(iy+E_X)
        add a,(iy+E_DX)
        ld b,a
        cp 117
        jr nc,.dec
        ld a,(iy+E_F)
        call walkable
        jr nz,.go
.dec:   call enemy_decide
.go:    ld a,(iy+E_DY)
        or a
        jr z,.h
        ; onto the ladder
        ld b,a
        ld a,(iy+E_F)
        bit 7,b
        jr z,.lf
        dec a
.lf:    ld (iy+E_LF),a
        ld (iy+E_F),$FF
        ld a,(iy+E_Y)
        add a,b
        ld (iy+E_Y),a
        ret
.h:     ld a,(iy+E_X)
        add a,(iy+E_DX)
        ld (iy+E_X),a
        ret

; choose a direction at a junction (IY on floor E_F)
enemy_decide:
        ld (iy+E_TIM),1
        ld c,0                  ; options: 1 R, 2 L, 4 U, 8 D
        ld a,(iy+E_X)
        inc a
        ld b,a
        ld a,(iy+E_F)
        call walkable
        jr z,.o1
        set 0,c
.o1:    ld a,(iy+E_X)
        or a
        jr z,.o2
        dec a
        ld b,a
        ld a,(iy+E_F)
        call walkable
        jr z,.o2
        set 1,c
.o2:    ld b,(iy+E_X)
        ld a,(iy+E_F)
        ld e,2
        call ladder_at
        jr z,.o3
        set 2,c
.o3:    ld b,(iy+E_X)
        ld a,(iy+E_F)
        ld e,1
        call ladder_at
        jr z,.o4
        set 3,c
.o4:    ; don't turn straight back unless it's the only way
        ld b,0
        ld a,(iy+E_DX)
        cp 1
        jr nz,.r1
        ld b,2
.r1:    cp -1
        jr nz,.r2
        ld b,1
.r2:    ld a,(iy+E_DY)
        cp 1
        jr nz,.r3
        ld b,4
.r3:    cp -1
        jr nz,.r4
        ld b,8
.r4:    ld a,b
        cpl
        and c
        jr z,.keep
        ld c,a
.keep:  ld a,c
        or a
        jr nz,.have
        ; boxed in: reverse
        ld a,(iy+E_DX)
        neg
        ld (iy+E_DX),a
        ret
.have:  ld (tmpb),a
        ; chase Sam?
        ld a,(iy+E_T)
        ld hl,smart_tab
        call idx_byte
        ld b,a
        call random
        cp b
        jr nc,.rand
        call sam_floor          ; A = Sam's floor
        ld b,a
        ld a,(iy+E_F)
        cp b
        jr z,.hz
        jr c,.wantd
        ld a,(tmpb)
        and 4
        jr nz,.set
        jr .hz
.wantd: ld a,(tmpb)
        and 8
        jr nz,.set
.hz:    ld a,(sx)
        cp (iy+E_X)
        jr z,.rand
        jr c,.wl
        ld a,(tmpb)
        and 1
        jr nz,.set
        jr .rand
.wl:    ld a,(tmpb)
        and 2
        jr nz,.set
.rand:  ld b,4
        call rand_n
        ld b,a
        ld a,1
        inc b
.rs:    dec b
        jr z,.rt
        add a,a
        jr .rs
.rt:    ld c,a
        ld a,(tmpb)
        and c
        jr z,.rand
.set:   ld (iy+E_DX),0
        ld (iy+E_DY),0
        cp 1
        jr nz,.d2
        ld (iy+E_DX),1
        ld (iy+E_FACE),0
        ret
.d2:    cp 2
        jr nz,.d3
        ld (iy+E_DX),-1
        ld (iy+E_FACE),1
        ret
.d3:    cp 4
        jr nz,.d4
        ld (iy+E_DY),-1
        ret
.d4:    ld (iy+E_DY),1
        ret
smart_tab: db 170,120,205,190

; sam_floor -> A = Sam's floor (nearest end if climbing)
sam_floor:
        ld a,(sf)
        cp $FF
        ret nz
        ld a,(slf)
        call fyrow
        ld b,a
        ld a,(sy)
        sub b
        cp 4
        ld a,(slf)
        ret c
        inc a
        ret

; ---------------------------------------------------------------------
; bonus items: appear after 6 and 14 drops at the kitchen's item spot
; ---------------------------------------------------------------------
item_update:
        ld a,(it_on)
        or a
        jr nz,.on
        ld a,(it_seq)
        cp 2
        ret nc
        ld b,6
        or a
        jr z,.th
        ld b,14
.th:    ld a,(drops)
        cp b
        ret c
        ld a,(kitchen)
        ld b,a
        ld a,(it_seq)
        add a,b
        and 3
        ld (it_t),a
        ld a,(it_seq)
        inc a
        ld (it_seq),a
        ld a,1
        ld (it_on),a
        ld hl,520
        ld (it_tim),hl
        ret
.on:    ld hl,(it_tim)
        dec hl
        ld (it_tim),hl
        ld a,h
        or l
        jr nz,.c
        ld (it_on),a
        ret
.c:     ld a,(sst)
        or a
        ret nz
        ld a,(lvh+LV_ITX)
        ld b,a
        ld a,(sx)
        sub b
        call absa
        cp 6
        ret nc
        ld a,(lvh+LV_ITF)
        call fyrow
        dec a
        ld b,a
        ld a,(sy)
        sub b
        call absa
        cp 5
        ret nc
        xor a
        ld (it_on),a
        ld a,SFX_ITEM
        call play_sfx
        ld a,(sy)
        ld d,a
        ld a,(it_t)
        or a
        jr nz,.i1
        ; coffee: +1 pepper (from the 1984 original)
        ld a,(peppers)
        cp 9
        jr nc,.cf
        inc a
        ld (peppers),a
.cf:    ld a,2
        ld (hudflag),a
        push de
        ld de,$0200
        call add_score
        pop de
        ld e,P_PEPPER
        jr .pop
.i1:    cp 1
        jr nz,.i2
        push de
        ld de,$0500
        call add_score
        pop de
        ld e,P_500
        jr .pop
.i2:    cp 2
        jr nz,.i3
        push de
        ld de,$1000
        call add_score
        pop de
        ld e,P_1000
        jr .pop
.i3:    ; golden spatula: everyone's stunned
        push de
        ld de,$1500
        call add_score
        ld iy,enemies
        ld b,MAXEN
.sl:    ld a,(iy+E_ST)
        cp 1
        jr nz,.sn
        ld (iy+E_ST),2
        ld (iy+E_TIM),250
.sn:    ld de,ESIZE
        add iy,de
        djnz .sl
        pop de
        ld e,P_SUPER
.pop:   ld a,(lvh+LV_ITX)
        jp popup_at

; ---------------------------------------------------------------------
; draw everything that moves
; ---------------------------------------------------------------------
draw_sprites:
        call bg_update
        ; chasers
        ld iy,enemies
        ld b,MAXEN
.el:    push bc
        ld a,MAXEN+1
        sub b
        ld (dltag),a            ; tags 1-6: chasers
        ld a,(iy+E_ST)
        or a
        jr z,.en
        ld c,a
        ld a,(iy+E_T)
        ld b,a
        add a,a
        add a,b
        add a,a                 ; *6
        add a,SPR_HOTDOG_A
        ld b,a
        ld a,c
        cp 2
        jr nz,.e1
        ld a,(iy+E_TIM)
        cp 40
        jr nc,.est
        ld a,(framecount)
        and 4
        jr z,.e3
.est:   ld a,b
        add a,4
        jr .eput
.e1:    cp 4
        jr nz,.e3
        ld a,b
        add a,5
        jr .eput
.e3:    ld a,(iy+E_ANIM)
        and 4
        rrca
        add a,b
        ld b,a
        ld a,(iy+E_F)
        cp $FF
        ld a,(iy+E_FACE)
        jr nz,.ef
        ld a,(iy+E_ANIM)
        rrca
        rrca
        rrca
        and 1
.ef:    add a,b
.eput:  ld b,(iy+E_X)
        ld c,a
        ld a,(iy+E_Y)
        sub 7
        ld e,c
        ld c,a
        ld a,e
        call spr_put
.en:    ld de,ESIZE
        add iy,de
        pop bc
        djnz .el
        call sam_sprite
        ld a,SAM_TAG
        ld (dltag),a
        ld a,(sy)
        sub 7
        jr c,.ns
        ld c,a
        ld a,(sx)
        ld b,a
        ld a,(tmpa)
        call spr_put
.ns:    ld a,8                  ; back to the default (lean path, never kept)
        ld (dltag),a
        jp pop_tick

; bonus item, pepper cloud and sparkle live in the background buffer
bg_update:
        ld a,(it_on)
        or a
        jr z,.ic
        ld hl,(it_tim)
        ld a,h
        or a
        jr nz,.iv
        ld a,l
        cp 120
        jr nc,.iv
        ld a,(framecount)
        and 8
        jr z,.ic
.iv:    ld a,(lvh+LV_ITF)
        call fyrow
        sub 8
        ld e,a
        ld a,(lvh+LV_ITX)
        rrca
        rrca
        and $3F
        ld d,a
        ld a,(it_t)
        add a,SPR_COFFEE
        ld c,BO_ITEM
        call bgobj_set
        jr .pp
.ic:    ld c,BO_ITEM
        call bgobj_clear
.pp:    ld a,(pep_tim)
        or a
        jr z,.pc
        ld a,(pep_y)
        sub 7
        ld e,a
        ld a,(pep_x)
        rrca
        rrca
        and $3F
        ld d,a
        ld a,(pep_tim)
        rrca
        rrca
        and 1
        add a,SPR_PEPPER_A
        ld c,BO_PEP
        call bgobj_set
        jr .sk
.pc:    ld c,BO_PEP
        call bgobj_clear
.sk:    ld a,(spk_tim)
        or a
        jr z,.sc
        dec a
        ld (spk_tim),a
        ld a,(spk_x)
        rrca
        rrca
        and $3F
        ld d,a
        ld a,(spk_tim)
        and 8
        jr z,.s2
        inc d
        inc d
.s2:    ld a,(spk_y)
        ld e,a
        ld a,(spk_tim)
        rrca
        rrca
        and 1
        add a,SPR_SPARK_A
        ld c,BO_SPK
        jp bgobj_set
.sc:    ld c,BO_SPK
        jp bgobj_clear

; sam_sprite -> tmpa = sprite id
sam_sprite:
        ld a,(sst)
        or a
        jr z,.alive
        cp 1
        jr nz,.cheer
        ld a,(stim)
        cp 70
        ld a,SPR_SAM_UPSIDE
        jr nc,.set
        ld a,(stim)
        and 8
        ld a,SPR_SAM_DIZZY
        jr z,.set
        ld a,SPR_SAM_FRONT
        jr .set
.cheer: ld a,(stim)
        and 8
        ld a,SPR_SAM_CHEER
        jr z,.set
        ld a,SPR_SAM_FRONT
        jr .set
.alive: ld a,(sf)
        cp $FF
        jr nz,.fl
        ld a,(sanim)
        and 4
        ld a,SPR_SAM_CLIMB_A
        jr z,.set
        ld a,SPR_SAM_CLIMB_B
        jr .set
.fl:    ld a,(throwtim)
        or a
        jr z,.walk
        ld a,(sface)
        add a,SPR_SAM_THROW
        jr .set
.walk:  ld a,(sanim)
        and 4
        rrca
        ld b,a
        ld a,(sface)
        add a,b
        add a,SPR_SAM_A
.set:   ld (tmpa),a
        ret

; ---------------------------------------------------------------------
; demo autopilot: BFS distances over the floor/ladder graph to the
; chosen ingredient, then walk downhill; peppers anything in the way
; ---------------------------------------------------------------------
ai_control:
        xor a
        ld (pad),a
        ld (padnew),a
        ld a,(ai_tim)           ; unsticking wander
        or a
        jr z,.ns
        dec a
        ld (ai_tim),a
        ld a,(ai_wpad)
        ld (pad),a
        ret
.ns:    ; stuck?
        ld a,(sx)
        ld hl,ai_lastx
        cp (hl)
        jr nz,.mv
        ld a,(sy)
        ld hl,ai_lasty
        cp (hl)
        jr nz,.mv
        ld a,(ai_stuck)
        inc a
        ld (ai_stuck),a
        cp 40
        jr c,.ck
        xor a
        ld (ai_stuck),a
        ld a,(ai_tgt)
        inc a
        ld (ai_tgt),a
        ld a,$FF
        ld (ai_tf),a
        ld a,25
        ld (ai_tim),a
        ld b,4
        call rand_n
        ld b,a
        ld a,1
        inc b
.rb:    dec b
        jr z,.rbd
        add a,a
        jr .rb
.rbd:   ld (ai_wpad),a
        ret
.mv:    xor a
        ld (ai_stuck),a
        ld a,(sx)
        ld (ai_lastx),a
        ld a,(sy)
        ld (ai_lasty),a
.ck:    ; pepper an enemy close ahead
        call ai_pepper
        ; target still valid?
        ld a,(ai_tf)
        cp $FF
        jr z,.pick
        ld a,(ai_tp)
        call piece_ix
        ld a,(ix+PC_ST)
        or a
        jr z,.have
        ld a,(ai_tgt)
        inc a
        ld (ai_tgt),a
.pick:  call ai_choose
        ld a,(ai_tf)
        cp $FF
        ret z
.have:  ld a,(sf)
        cp $FF
        jp z,.lad
        ; on the target piece's floor and over it: finish the job
        ld b,a
        ld a,(ai_tf)
        cp b
        jr nz,.nav
        ld a,(ai_tp)
        call piece_ix
        ld a,(sx)
        add a,4
        sub (ix+PC_X)
        add a,4
        cp 24
        jr nc,.nav
        ; find an unpressed segment, walk to it
        ld a,(ix+PC_PR)
        ld c,(ix+PC_X)
        ld b,4
.sg:    rrca
        jr nc,.sgf
        push af
        ld a,c
        add a,4
        ld c,a
        pop af
        djnz .sg
        ret
.sgf:   ld a,c
        add a,2
        ld b,a                  ; segment centre
        ld a,(sx)
        add a,4
        cp b
        ret z
        ld a,1
        jr c,.pr
        ld a,2
.pr:    ld (pad),a
        ret
.nav:   ; best neighbour by distance
        ld a,(sx)
        add a,4
        rrca
        rrca
        and $3F
        ld c,a
        ld (tmpc),a
        ld a,(sf)
        call nodeidx            ; A = node index
        ld (tmpd),a
        call dist_of
        ld (tmpb),a             ; best so far
        xor a
        ld (tmpy),a             ; best move
        ld a,(tmpd)
        call node_of
        ld (tmpx),a             ; node flags
        ; left
        ld a,(tmpd)
        dec a
        call node_of
        bit 7,a
        jr z,.nl
        ld a,(tmpd)
        dec a
        ld c,2
        call .try
.nl:    ld a,(tmpd)
        inc a
        call node_of
        bit 7,a
        jr z,.nr
        ld a,(tmpd)
        inc a
        ld c,1
        call .try
.nr:    ld a,(tmpx)
        bit 0,a
        jr z,.nd
        ld a,(tmpd)
        add a,32
        ld c,8
        call .try
.nd:    ld a,(tmpx)
        bit 1,a
        jr z,.nu
        ld a,(tmpd)
        sub 32
        ld c,4
        call .try
.nu:    ld a,(tmpy)
        or a
        ret z
        cp 4
        jr nc,.vert
        ld (pad),a
        ret
.vert:  ; line up with the ladder first
        ld c,a
        ld a,(tmpc)
        dec a
        add a,a
        add a,a
        ld b,a
        ld a,(sx)
        sub b
        call absa
        cp 3
        jr nc,.line
        ld a,c
        ld (pad),a
        ret
.line:  ld a,(sx)
        cp b
        ld a,2
        jr nc,.lp
        ld a,1
.lp:    ld (pad),a
        ret
.try:   ; A = node index, C = move; keep if closer
        call dist_of
        ld b,a
        ld a,(tmpb)
        cp b
        ret c
        ret z
        ld a,b
        ld (tmpb),a
        ld a,c
        ld (tmpy),a
        ret
.lad:   ; climbing: head for the closer end
        ld a,(sx)
        add a,4
        rrca
        rrca
        and $3F
        ld c,a
        ld a,(slf)
        call nodeidx
        ld (tmpd),a
        call dist_of
        ld b,a
        ld a,(tmpd)
        add a,32
        call dist_of
        cp b
        ld a,8
        jr c,.lp2
        ld a,4
.lp2:   ld (pad),a
        ret

; A = floor, C = cell -> A = node index
nodeidx:
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        ret
node_of:
        ld hl,node
        jp idx_byte
dist_of:
        ld hl,dist
        jp idx_byte

ai_pepper:
        ld a,(peppers)
        or a
        ret z
        ld a,(pep_tim)
        or a
        ret nz
        ld iy,enemies
        ld b,MAXEN
.l:     ld a,(iy+E_ST)
        cp 1
        jr nz,.nx
        ld a,(sy)
        sub (iy+E_Y)
        call absa
        cp 4
        jr nc,.nx
        ld a,(iy+E_X)
        ld hl,sx
        sub (hl)
        ld c,a
        call absa
        cp 15
        jr nc,.nx
        ; face it and throw
        ld a,c
        rlca
        and 1
        ld (sface),a
        ld a,$10
        ld (padnew),a
        ret
.nx:    ld de,ESIZE
        add iy,de
        djnz .l
        ret

; choose the next ingredient to walk over; BFS from its cells
ai_choose:
        ld a,$FF
        ld (ai_tf),a
        ld a,(npc)
        or a
        ret z
        ld b,a
        ld a,(ai_tgt)
.m:     cp b
        jr c,.ok
        sub b
        jr .m
.ok:    ld (ai_tgt),a
        ld c,b
.l:     push bc
        ld a,(ai_tgt)
        call piece_ix
        ld a,(ix+PC_ST)
        or a
        jr nz,.nx
        ld a,(ix+PC_PR)
        cp 15
        jr nz,.got
.nx:    ld a,(ai_tgt)
        inc a
        pop bc
        cp b
        jr c,.n2
        xor a
.n2:    ld (ai_tgt),a
        dec c
        jr nz,.l
        ret
.got:   pop bc
        ld a,(ai_tgt)
        ld (ai_tp),a
        ld a,(ix+PC_F)
        ld (ai_tf),a
        ; BFS
        ld hl,dist
        ld b,160
.cl:    ld (hl),$FF
        inc hl
        djnz .cl
        ld a,(ix+PC_X)
        rrca
        rrca
        and $3F
        ld c,a
        ld a,(ix+PC_F)
        call nodeidx
        ld b,4
        ld de,bfsq
        ld hl,0
        ld (qhead),hl
.src:   push af
        push bc
        ld (de),a
        inc de
        ld hl,dist
        call idx_ptr
        ld (hl),0
        pop bc
        pop af
        inc a
        djnz .src
        ld (qtail),de
        ld hl,bfsq
        ld (qhead),hl
.bfs:   ld hl,(qhead)
        ld de,(qtail)
        or a
        sbc hl,de
        ret z
        ld hl,(qhead)
        ld a,(hl)
        inc l                   ; ring of 128 at $7C80
        jr nz,.q1
        ld l,$80
.q1:    ld (qhead),hl
        ld (tmpd),a
        call dist_of
        inc a
        ld (tmpb),a
        ld a,(tmpd)
        call node_of
        ld (tmpx),a
        ld a,(tmpd)
        and 31
        jr z,.b1
        ld a,(tmpd)
        dec a
        call .visit
.b1:    ld a,(tmpd)
        and 31
        cp 31
        jr z,.b2
        ld a,(tmpd)
        inc a
        call .visit
.b2:    ld a,(tmpx)
        bit 0,a
        jr z,.b3
        ld a,(tmpd)
        add a,32
        call .visitl
.b3:    ld a,(tmpx)
        bit 1,a
        jr z,.bfs
        ld a,(tmpd)
        sub 32
        call .visitl
        jr .bfs
.visit: ; walkable neighbour?
        ld c,a
        call node_of
        bit 7,a
        ret z
        ld a,c
.visitl:
        ld c,a
        ld hl,dist
        call idx_ptr
        ld a,(hl)
        cp $FF
        ret nz
        ld a,(tmpb)
        ld (hl),a
        ld hl,(qtail)
        ld (hl),c
        inc l
        jr nz,.q2
        ld l,$80
.q2:    ld (qtail),hl
        ret

; ---------------------------------------------------------------------
; keep_compute: which tagged sprites (Sam, chasers) are exactly where they
; were last frame and touch nothing that changes?  The renderer leaves those
; on screen (no erase, no redraw), which keeps vblank work snow-free.
; ---------------------------------------------------------------------
SAM_TAG equ 7
NTAG    equ 8
keep_compute:
        ld hl,KN_PRES           ; last frame's list is what is on screen now
        ld de,KT_PRES
        ld bc,$40
        ldir
        ld hl,KN_PRES
        ld b,16
        xor a
.c:     ld (hl),a
        inc l
        djnz .c
        ld (kent),a
        ld ix,drawlist
.s:     ld a,(ix+0)
        cp $FF
        jr z,.sd
        cp $FD
        jp nc,.none             ; text or pixels on the list: play safe
        ld a,(ix+3)
        or a
        jp z,.none
        add a,KN_PRES-KT
        ld l,a
        ld h,KT/256
        ld (hl),1
        add a,$10
        ld l,a
        ld a,(ix+0)
        ld (hl),a
        ld a,l
        add a,$10
        ld l,a
        ld a,(ix+1)
        ld (hl),a
        ld a,l
        add a,$10
        ld l,a
        ld a,(ix+2)
        ld (hl),a
        ld hl,kent
        inc (hl)
        ld de,4
        add ix,de
        jr .s
.sd:    ; candidates: on screen and unchanged
        ld c,1
.cl:    ld h,KT/256
        ld l,c
        ld (hl),0
        ld a,c
        add a,KN_PRES-KT
        ld l,a
        ld a,(hl)
        or a
        jr z,.cn
        ld a,c
        add a,KT_PRES-KT
        ld l,a
        ld a,(hl)
        or a
        jr z,.cn
        ld b,3
        ld a,c
        add a,KN_ID-KT
        ld e,a
        ld a,c
        add a,KT_ID-KT
        ld d,a
.cq:    ld l,e
        ld a,(hl)
        ld l,d
        cp (hl)
        jr nz,.cn
        ld a,e
        add a,$10
        ld e,a
        ld a,d
        add a,$10
        ld d,a
        djnz .cq
        ld l,c
        ld (hl),1
.cn:    inc c
        ld a,c
        cp NTAG
        jr nz,.cl
        ; changed rectangles: old and new places of every sprite not kept
        ld de,KCR
        ld c,1
.rl:    ld h,KT/256
        ld l,c
        ld a,(hl)
        or a
        jr nz,.rn
        ld a,c
        add a,KN_PRES-KT
        call .addr
        ld a,c
        add a,KT_PRES-KT
        call .addr
.rn:    inc c
        ld a,c
        cp NTAG
        jr nz,.rl
        ld (kcrend),de
        ; test each kept candidate; a drop adds its rect and restarts
.again: xor a
        ld (kpass),a
        ld c,1
.pl:    ld h,KT/256
        ld l,c
        ld a,(hl)
        or a
        jp z,.pn
        ld a,c
        add a,KN_X-KT
        ld l,a
        ld a,(hl)
        rrca
        rrca
        and $3F
        ld (kcol),a
        ld a,l
        add a,$10
        ld l,a
        ld a,(hl)
        ld (krow),a
        ld hl,KCR
.tl:    ld de,(kcrend)
        ld a,l
        cp e
        jr z,.tq
        ld a,(kcol)
        sub (hl)
        jr nc,.t1
        neg
.t1:    inc l
        cp 3
        jr nc,.tn
        ld a,(krow)
        sub (hl)
        jr nc,.t2
        neg
.t2:    cp 8
        jr c,.drop
.tn:    inc l
        jr .tl
.tq:    ; against the commit queue
        ld a,(q_head)
.ql:    ld e,a
        ld a,(q_tail)
        cp e
        jr z,.pn
        ld l,e
        ld h,qbuf/256
        ld a,(kcol)
        add a,2
        cp (hl)
        jr c,.qn
        ld d,(hl)
        inc l
        inc l
        ld a,(hl)
        add a,d
        ld d,a
        ld a,(kcol)
        cp d
        jr nc,.qn
        dec l
        ld a,(krow)
        add a,7
        cp (hl)
        jr c,.qn
        ld d,(hl)
        inc l
        inc l
        ld a,(hl)
        add a,d
        ld d,a
        ld a,(krow)
        cp d
        jr c,.drop
.qn:    ld a,e
        add a,4
        and $7F
        jr .ql
.drop:  ld h,KT/256
        ld l,c
        ld (hl),0
        ld de,(kcrend)
        ld a,(kcol)
        ld (de),a
        inc e
        ld a,(krow)
        ld (de),a
        inc e
        ld (kcrend),de
        ld a,1
        ld (kpass),a
.pn:    inc c
        ld a,c
        cp NTAG
        jp nz,.pl
        ld a,(kpass)
        or a
        jp nz,.again
        call kt_count
        cp 6
        call nc,force_keep      ; too many to draw: let a chaser lag a frame
        ; commit budget from what is left to draw
        ld hl,KT+1
        ld b,NTAG-1
        ld c,0
.k:     ld a,(hl)
        add a,c
        ld c,a
        inc l
        djnz .k
        ld a,(kent)
        sub c                   ; sprites to draw
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,b
        add a,b
        add a,b                 ; *11
        add a,c
        add a,c                 ; + 2 per kept
        ld b,a
        ld a,58
        sub b
        jr c,.mn
        cp 3
        jr nc,.bs
.mn:    xor a                   ; no time left for the queue this frame
.bs:    ld (cbudget),a
        ret
.addr:  ; A = offset of a PRES entry: if present, add its (col,row) to KCR at DE
        ld l,a
        ld a,(hl)
        or a
        ret z
        ld a,l
        add a,$10
        add a,$10
        ld l,a                  ; X
        ld a,(hl)
        rrca
        rrca
        and $3F
        ld (de),a
        inc e
        ld a,l
        add a,$10
        ld l,a
        ld a,(hl)               ; Y
        ld (de),a
        inc e
        ret
.none:  ld hl,KT
        ld b,16
        xor a
.nc:    ld (hl),a
        inc l
        djnz .nc
        ld a,8
        ld (cbudget),a
        ret

; kt_count -> A = sprites that will be drawn (entries - kept)
kt_count:
        ld hl,KT+1
        ld b,NTAG-1
        ld c,0
.k:     ld a,(hl)
        add a,c
        ld c,a
        inc l
        djnz .k
        ld a,(kent)
        sub c
        ret

; force_keep: keep one changed chaser at its OLD place this frame, if neither
; its old nor new rectangle touches another changing sprite or the queue
force_keep:
        ld c,1
.t:     ld h,KT/256
        ld l,c
        ld a,(hl)
        or a
        jr nz,.nx               ; already kept
        ld a,c
        add a,KN_PRES-KT
        ld l,a
        ld a,(hl)
        or a
        jr z,.nx
        ld a,c
        add a,KT_PRES-KT
        ld l,a
        ld a,(hl)
        or a
        jr z,.nx
        ; old rect
        ld a,c
        add a,KT_X-KT
        call .test
        jr c,.nx
        ld a,c
        add a,KN_X-KT
        call .test
        jr c,.nx
        ; keep it where it was: next frame's "on screen" is the old place
        ld h,KT/256
        ld l,c
        ld (hl),1
        ld b,3
        ld a,c
        add a,KT_ID-KT
        ld e,a
        add a,KN_ID-KT_ID
        ld d,a
.cp:    ld l,e
        ld a,(hl)
        ld l,d
        ld (hl),a
        ld a,e
        add a,$10
        ld e,a
        ld a,d
        add a,$10
        ld d,a
        djnz .cp
        ret
.nx:    inc c
        ld a,c
        cp SAM_TAG              ; chasers only (tags 1-6)
        jr nz,.t
        ret
.test:  ; A = X-table offset of a rect: carry if it touches another changing sprite or the queue
        ld l,a
        ld h,KT/256
        ld a,(hl)
        rrca
        rrca
        and $3F
        ld (kcol),a
        ld a,l
        add a,$10
        ld l,a
        ld a,(hl)
        ld (krow),a
        ld b,1
.u:     ld a,b
        cp c
        jr z,.un
        ld h,KT/256
        ld l,b
        ld a,(hl)
        or a
        jr nz,.un
        ld a,b
        add a,KN_PRES-KT
        ld l,a
        ld a,(hl)
        or a
        jr z,.u2
        ld a,b
        add a,KN_X-KT
        call .ov
        ret c
.u2:    ld a,b
        add a,KT_PRES-KT
        ld l,a
        ld a,(hl)
        or a
        jr z,.un
        ld a,b
        add a,KT_X-KT
        call .ov
        ret c
.un:    inc b
        ld a,b
        cp NTAG
        jr nz,.u
        ; queue
        ld a,(q_head)
.ql:    ld e,a
        ld a,(q_tail)
        cp e
        ret z                   ; (no carry: equal)
        ld l,e
        ld h,qbuf/256
        ld a,(kcol)
        add a,2
        cp (hl)
        jr c,.qn
        ld d,(hl)
        inc l
        inc l
        ld a,(hl)
        add a,d
        ld d,a
        ld a,(kcol)
        cp d
        jr nc,.qn
        dec l
        ld a,(krow)
        add a,7
        cp (hl)
        jr c,.qn
        ld d,(hl)
        inc l
        inc l
        ld a,(hl)
        add a,d
        ld d,a
        ld a,(krow)
        cp d
        ret c
.qn:    ld a,e
        add a,4
        and $7F
        jr .ql
.ov:    ld l,a
        ld h,KT/256
        ld a,(hl)
        rrca
        rrca
        and $3F
        ld d,a
        ld a,l
        add a,$10
        ld l,a
        ld e,(hl)
        ld a,(kcol)
        sub d
        jr nc,.o1
        neg
.o1:    cp 3
        ret nc
        ld a,(krow)
        sub e
        jr nc,.o2
        neg
.o2:    cp 8
        ret
