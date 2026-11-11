; ============================================================================
;  GAME: title, play loop, player, stars, enemies, bullets, collisions
; ============================================================================

NEN     equ 12          ; enemies
EOSIZE  equ 17
NEB     equ 12          ; enemy bullets
EBSIZE  equ 10
NPS     equ 16          ; player shots
PSSIZE  equ 4
NEX     equ 8           ; explosions
EXSIZE  equ 4
NPU     equ 3           ; pickups
PUSIZE  equ 6
STSIZE  equ 8           ; stars (4 slots: N W E S)
GRSIZE  equ 6           ; wave groups: left, killed, total, lastx, lasty, type

; enemy fields (fraction before integer, so a 16-bit load gets x.8)
EO_T    equ 0
EO_XF   equ 1
EO_X    equ 2
EO_YF   equ 3
EO_Y    equ 4           ; y16 = screen y + 16
EO_HP   equ 5
EO_TM   equ 6
EO_PL   equ 7
EO_PH   equ 8
EO_DX   equ 9           ; last path step, 1/16 px
EO_DY   equ 10
EO_FL   equ 11          ; hit flash
EO_FC   equ 12          ; fire telegraph countdown
EO_ST   equ 13          ; boat: 0 submerged, 1 surfaced
EO_G    equ 14          ; wave group
EO_W    equ 15          ; hit width (0 = can't be hit: free slot or submerged)
EO_H2   equ 16          ; hit height + 2 (shots are 3 rows)

T_DRONE equ 1
T_DART  equ 2
T_BOAT  equ 3

ST_NONE equ 0
ST_ON   equ 1           ; attached to the ship
ST_LOOSE equ 2          ; knocked loose, can be caught again
ST_BURST equ 3          ; flung outward by a Cross Burst
ST_BACK equ 4           ; flying home after a burst

; ---------------------------------------------------------------- title
title:
        xor a
        ld (mode),a
        ld (paused),a
        ld (scroll_rate),a
        ld hl,0
        ld (mode_tm),hl
        call clear_objects
        ld a,1
        ld (wlevel),a
        call stop_music
        ld hl,SONG_GAME
        call play_song
        call hud_all
.loop:  call read_input
        call tick_mode
        call scroll_one
        call compose_bg
        ld hl,SPR_LOGO1
        ld b,0
        ld c,8+4
        call draw_spr
        ld hl,SPR_LOGO2
        ld b,18
        ld c,8+17
        call draw_spr
        ld hl,SPR_T_TEST
        ld b,26
        ld c,8+31
        call draw_spr
        ld a,(mode_tm)
        and 16
        jr z,.nop
        ld hl,SPR_T_PRESS
        ld b,28
        ld c,8+42
        call draw_spr
.nop:   ld hl,SPR_T_VIBED
        ld b,14
        ld c,8+54
        call draw_spr
        call hud_cpu
        call frame_end
        ld a,(keys_new)
        bit K_FIRE,a
        jr nz,start_game
        bit K_BURST,a
        jr nz,start_game
        jr .loop

tick_mode:
        ld hl,(mode_tm)
        inc hl
        ld (mode_tm),hl
        ld hl,anim
        inc (hl)
        ret

scroll_one:
        ld a,(scroll_rate)
        or a
        jr z,.full
        ld b,a
        ld a,(scroll_acc)
        add a,b
        ld (scroll_acc),a
        ld a,0
        adc a,0
        jr .st
.full:  ld a,1
.st:    ld (scroll_step),a
        or a
        ret z
        ld hl,top
        dec (hl)
        ret

clear_objects:
        ld hl,GRP
        ld de,GRP+1
        ld bc,VARS_END-GRP-1
        ld (hl),0
        ldir
        ret

; ---------------------------------------------------------------- start
start_game:
        ld a,1
        ld (mode),a
        ld hl,0
        ld (mode_tm),hl
        ld (score),hl
        ld (score+2),hl
        call clear_objects
        ld a,3
        ld (lives),a
        ld a,1
        ld (wlevel),a
        ld a,44
        ld (px),a
        ld a,16+48
        ld (py),a
        ld a,60
        ld (pinv),a
        xor a
        ld (pdead),a
        ld (firecd),a
        ld (spawn_left),a
        ld (game_song),a
        ; start with the two wing stars
        ld ix,STTAB+1*STSIZE
        ld (ix+0),ST_ON
        ld ix,STTAB+2*STSIZE
        ld (ix+0),ST_ON
        call place_stars
        ld hl,WAVES
        ld (wave_ptr),hl
        ld a,(hl)
        ld (wave_tm),a
        call hud_all
        call stop_music
        ld hl,SONG_JINGLE
        call play_song

; ---------------------------------------------------------------- play loop
game_loop:
        call read_input
        ld a,(keys_new)
        bit K_PAUSE,a
        jr z,.np
        ld a,(paused)
        xor 1
        ld (paused),a
.np:    ld a,(paused)
        or a
        jp nz,.pause
        ld a,(keys_new)
        bit K_SPEED,a           ; test key: cycle the scroll speed
        jr z,.ns
        ld a,(scroll_rate)
        sub 64
        cp 64
        jr nc,.sr
        xor a
.sr:    ld (scroll_rate),a
.ns:    call tick_mode
        call scroll_one
        call upd_player
        call upd_stars
        call upd_shots
        call spawner
        call upd_enemies
        call upd_ebullets
        call upd_pickups
        call upd_expl
        call collide
        ld a,(score_dirty)
        or a
        jr z,.nsd
        xor a
        ld (score_dirty),a
        call hud_score
.nsd:   call hud_cpu
        ; after the start jingle, the stage theme
        ld a,(game_song)
        or a
        jr nz,.gs
        ld a,(song_done)
        or a
        jr z,.gs
        ld a,1
        ld (game_song),a
        ld hl,SONG_GAME
        call play_song
.gs:    call draw_all
        call do_flash
        call frame_end
        ld a,(mode)
        cp 2
        jr nz,game_loop
        ld hl,(mode_tm)
        ld a,h
        or a
        jr nz,.tt
        ld a,l
        cp 150
        jr c,game_loop
.tt:    jp title
.pause: call draw_all
        ld hl,SPR_T_PAUSE
        ld b,35
        ld c,8+29
        call draw_spr
        call frame_end
        jp game_loop

; Cross Burst flash: the other colour set for a few frames
do_flash:
        ld a,(latch)
        and $EF
        ld b,a
        ld a,(flash_tm)
        or a
        jr z,.n
        dec a
        ld (flash_tm),a
        ld a,b
        or $10
        ld b,a
.n:     ld a,b
        ld (latch_next),a
        ret

; ---------------------------------------------------------------- player
upd_player:
        ld a,(mode)
        cp 1
        ret nz
        ld a,(pdead)
        or a
        jr z,.alive
        dec a
        ld (pdead),a
        ret nz
        ld a,(lives)
        or a
        jp z,game_over
        ; respawn: centre bottom, invulnerable, a star to help
        ld a,44
        ld (px),a
        ld a,16+48
        ld (py),a
        ld a,75
        ld (pinv),a
        ld a,(stars_mask)
        or a
        jr nz,.hs
        ld ix,STTAB
        ld (ix+0),ST_ON
.hs:    call clear_ebullets
        ret
.alive: ld a,(pinv)
        or a
        jr z,.ni
        dec a
        ld (pinv),a
.ni:    ld a,(keys)
        ld c,a
        xor a
        ld (pbank),a
        ld a,(px)
        bit K_LEFT,c
        jr z,.nl
        sub 2
        cp 5
        jr nc,.l1
        ld a,5
.l1:    ld b,a
        ld a,1
        ld (pbank),a
        ld a,b
.nl:    bit K_RIGHT,c
        jr z,.nr
        add a,2
        cp 84
        jr c,.r1
        ld a,83
.r1:    ld b,a
        ld a,2
        ld (pbank),a
        ld a,b
.nr:    ld (px),a
        ld a,(py)
        bit K_UP,c
        jr z,.nu
        dec a
        cp 22
        jr nc,.nu
        ld a,22
.nu:    bit K_DOWN,c
        jr z,.nd
        inc a
        cp 68
        jr c,.nd
        ld a,67
.nd:    ld (py),a
        ; fire
        ld a,(firecd)
        or a
        jr z,.cf
        dec a
        ld (firecd),a
        jr .burst
.cf:    bit K_FIRE,c
        jr z,.burst
        call fire_shots
        ld a,4
        ld (firecd),a
.burst: ld a,(keys_new)
        bit K_BURST,a
        ret z
        jp do_burst

fire_shots:
        ld a,(wlevel)
        cp 1
        jr nz,.twin
        ld a,(px)
        add a,3
        ld b,a
        ld a,(py)
        sub 3
        ld c,a
        call add_shot
        jr .stars
.twin:  ld a,(px)
        add a,2
        ld b,a
        ld a,(py)
        sub 2
        ld c,a
        call add_shot
        ld a,(px)
        add a,5
        ld b,a
        ld a,(py)
        sub 2
        ld c,a
        call add_shot
.stars: ld ix,STTAB
        ld b,3                  ; N, W, E fire with the ship (S guards)
.sl:    push bc
        ld a,(ix+0)
        cp ST_ON
        jr nz,.sn
        ld a,(ix+2)
        inc a
        ld b,a
        ld a,(ix+4)
        sub 3
        ld c,a
        call add_shot
.sn:    ld de,STSIZE
        add ix,de
        pop bc
        djnz .sl
        ld hl,shotsnd
        inc (hl)
        bit 0,(hl)
        ret nz
        ld a,FX_SHOT
        jp play_sfx

; B = x, C = y16
add_shot:
        ld hl,PSTAB
        ld de,PSSIZE
        ld a,NPS
.f:     push af
        ld a,(hl)
        or a
        jr z,.got
        pop af
        add hl,de
        dec a
        jr nz,.f
        ret
.got:   pop af
        ld (hl),1
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        ret

do_burst:
        ld a,(pdead)
        or a
        ret nz
        ld a,(stars_mask)
        or a
        ret z
        ld ix,STTAB
        ld hl,BURSTV
        ld b,4
.l:     ld a,(ix+0)
        cp ST_ON
        jr nz,.n
        ld (ix+0),ST_BURST
        ld a,(hl)
        ld (ix+5),a
        inc hl
        ld a,(hl)
        ld (ix+6),a
        dec hl
        ld (ix+7),10
.n:     inc hl
        inc hl
        ld de,STSIZE
        add ix,de
        djnz .l
        call clear_ebullets
        ld a,3
        ld (flash_tm),a
        ld a,FX_BURST
        jp play_sfx

clear_ebullets:
        ld hl,EBTAB
        ld de,EBTAB+1
        ld bc,NEB*EBSIZE-1
        ld (hl),0
        ldir
        ret

; star slot offsets from the ship's top-left, and their velocities
STOFFX: db 3,-5,10,3
STOFFY: db -6,2,2,10
BURSTV: db 0,-40, -56,0, 56,0, 0,36
LOOSEV: db 0,-20, -24,8, 24,8, 0,18

; ---------------------------------------------------------------- stars
place_stars:                    ; attached stars follow the ship
        ld ix,STTAB
        ld b,0
.l:     ld a,(ix+0)
        cp ST_ON
        jr nz,.n
        ld hl,STOFFX
        ld e,b
        ld d,0
        add hl,de
        ld a,(px)
        add a,(hl)
        ld (ix+2),a
        ld hl,STOFFY
        add hl,de
        ld a,(py)
        add a,(hl)
        ld (ix+4),a
        ld (ix+1),0
        ld (ix+3),0
.n:     ld de,STSIZE
        add ix,de
        inc b
        ld a,b
        cp 4
        jr nz,.l
        ret

upd_stars:
        call place_stars
        ld ix,STTAB
        ld b,0
.l:     push bc
        ld a,(ix+0)
        cp ST_LOOSE
        jr z,.loose
        cp ST_BURST
        jr z,.burst
        cp ST_BACK
        jr z,.back
.n:     pop bc
        ld de,STSIZE
        add ix,de
        inc b
        ld a,b
        cp 4
        jr nz,.l
        ; HUD diagram
        ld ix,STTAB
        ld c,0
        ld b,4
        ld e,1
.m:     ld a,(ix+0)
        cp ST_ON
        jr nz,.m1
        ld a,c
        or e
        ld c,a
.m1:    sla e
        push de
        ld de,STSIZE
        add ix,de
        pop de
        djnz .m
        ld a,(stars_mask)
        cp c
        ret z
        ld a,c
        ld (stars_mask),a
        jp hud_stars

.loose: ld a,(ix+5)
        call mv_x
        ld a,(ix+6)
        call mv_y
        ld a,(ix+5)             ; slow down
        sra a
        sra a
        sra a
        neg
        add a,(ix+5)
        ld (ix+5),a
        ld a,(ix+6)
        sra a
        sra a
        sra a
        neg
        add a,(ix+6)
        ld (ix+6),a
        ld a,(scroll_step)      ; drift with the ground
        add a,(ix+4)
        ld (ix+4),a
        dec (ix+7)
        jr z,.lost
        ld a,(ix+2)             ; off the playfield -> gone
        cp 93
        jr nc,.lost
        ld a,(ix+4)
        cp 10
        jr c,.lost
        cp 80
        jr nc,.lost
        ; caught by the ship?
        ld a,(pdead)
        or a
        jr nz,.n
        call star_touch_ship
        jr nc,.n
        ld (ix+0),ST_ON
        ld a,FX_CATCH
        call play_sfx
        jr .n
.lost:  ld (ix+0),ST_NONE
        jr .n

.burst: ld a,(ix+5)
        call mv_x
        ld a,(ix+6)
        call mv_y
        dec (ix+7)
        jr nz,.n
        ld (ix+0),ST_BACK
        jr .n

.back:  pop bc
        push bc
        ld hl,STOFFX            ; home position
        ld e,b
        ld d,0
        add hl,de
        ld a,(px)
        add a,(hl)
        ld c,a                  ; target x
        ld hl,STOFFY
        add hl,de
        ld a,(py)
        add a,(hl)
        ld d,a                  ; target y
        ld e,0                  ; e = 'arrived' count
        ld a,(ix+2)
        sub c
        jr z,.bx0
        jr c,.bxr
        cp 4
        jr c,.bxs
        ld a,(ix+2)
        sub 3
        ld (ix+2),a
        jr .by
.bxr:   neg
        cp 4
        jr c,.bxs
        ld a,(ix+2)
        add a,3
        ld (ix+2),a
        jr .by
.bxs:   ld (ix+2),c
.bx0:   inc e
.by:    ld a,(ix+4)
        sub d
        jr z,.by0
        jr c,.byr
        cp 3
        jr c,.bys
        ld a,(ix+4)
        sub 2
        ld (ix+4),a
        jr .bd
.byr:   neg
        cp 3
        jr c,.bys
        ld a,(ix+4)
        add a,2
        ld (ix+4),a
        jr .bd
.bys:   ld (ix+4),d
.by0:   inc e
.bd:    ld a,e
        cp 2
        jp nz,.n
        ld (ix+0),ST_ON
        jp .n

; star (IX) overlaps the ship's 8x8 box?  -> carry
star_touch_ship:
        ld a,(px)
        sub 2
        ld b,a
        ld a,(ix+2)
        sub b                   ; star x - (px-2)
        cp 10
        ret nc
        ld a,(py)
        sub 2
        ld b,a
        ld a,(ix+4)
        sub b
        cp 10
        ret

; A = velocity (signed, 1/16 px) -> add to x.8 at IX+1/IX+2
mv_x:   ld l,a
        add a,a
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,(ix+1)
        ld d,(ix+2)
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        ret
mv_y:   ld l,a
        add a,a
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,(ix+3)
        ld d,(ix+4)
        add hl,de
        ld (ix+3),l
        ld (ix+4),h
        ret

; knock star IX (slot B) loose
knock_loose:
        ld (ix+0),ST_LOOSE
        ld (ix+7),55            ; about two seconds to catch it again
        ld hl,LOOSEV
        ld a,b
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        ld (ix+5),a
        inc hl
        ld a,(hl)
        ld (ix+6),a
        ld a,FX_LOST
        jp play_sfx

; ---------------------------------------------------------------- shots
upd_shots:
        ld hl,PSTAB
        ld b,NPS
.l:     ld a,(hl)
        or a
        jr z,.n
        inc hl
        inc hl
        ld a,(hl)
        sub 5
        ld (hl),a
        dec hl
        dec hl
        cp 6
        jr nc,.n
        ld (hl),0
.n:     ld de,PSSIZE
        add hl,de
        djnz .l
        ret

; ---------------------------------------------------------------- waves
spawner:
        ld a,(mode)
        cp 1
        ret nz
        ld a,(spawn_left)
        or a
        jr z,.wave
        ld hl,spawn_tm
        dec (hl)
        ret nz
        ld a,(spawn_sp)
        ld (hl),a
        call spawn_enemy
        ld hl,spawn_left
        dec (hl)
        ret
.wave:  ld hl,wave_tm
        dec (hl)
        ret nz
        ld hl,(wave_ptr)
        inc hl
        ld a,(hl)               ; type
        cp $FF
        jr nz,.go
        ld hl,WAVES
        ld (wave_ptr),hl
        ld a,(hl)
        ld (wave_tm),a
        ret
.go:    ld (spawn_type),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (spawn_path),de
        ld b,(hl)               ; x
        inc hl
        ld c,(hl)               ; count
        inc hl
        ld a,(hl)               ; spacing
        inc hl
        ld (wave_ptr),hl
        or a
        jr nz,$+3
        inc a
        ld (spawn_sp),a
        ld a,(hl)               ; next entry's delay
        ld (wave_tm),a
        ld a,(spawn_type)
        or a
        ret z                   ; a pause
        ld a,b
        ld (spawn_x),a
        ld a,c
        ld (spawn_left),a
        ld a,1
        ld (spawn_tm),a
        ; wave group record
        ld a,(grp_next)
        ld (spawn_grp),a
        inc a
        and 7
        ld (grp_next),a
        ld a,(spawn_grp)
        call grp_addr
        ld (hl),c               ; left
        inc hl
        ld (hl),0               ; killed
        inc hl
        ld (hl),c               ; total
        inc hl
        inc hl
        inc hl
        ld a,(spawn_type)
        ld (hl),a
        ret

; A = group -> HL
grp_addr:
        ld l,a
        add a,a
        add a,l
        add a,a                 ; *6
        ld l,a
        ld h,0
        ld de,GRP
        add hl,de
        ret

spawn_enemy:
        ld ix,ETAB
        ld b,NEN
        ld de,EOSIZE
.f:     ld a,(ix+EO_T)
        or a
        jr z,.got
        add ix,de
        djnz .f
        ; no room: count it as gone so the group can still resolve
        ld a,(spawn_grp)
        call grp_addr
        dec (hl)
        ret
.got:   push ix
        pop hl
        ld b,EOSIZE
.cl:    ld (hl),0
        inc hl
        djnz .cl
        ld a,(spawn_type)
        ld (ix+EO_T),a
        ld a,(spawn_x)
        ld (ix+EO_X),a
        ld (ix+EO_Y),8
        ld hl,(spawn_path)
        ld (ix+EO_PL),l
        ld (ix+EO_PH),h
        ld a,(spawn_grp)
        ld (ix+EO_G),a
        ld a,(spawn_type)
        ld hl,HPTAB-1
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        ld (ix+EO_HP),a
        ld hl,EHTAB-1
        add hl,de
        ld a,(hl)
        add a,2
        ld (ix+EO_H2),a
        ld a,e
        cp T_BOAT
        ret z
        ld hl,EWTAB-1
        add hl,de
        ld a,(hl)
        ld (ix+EO_W),a
        ret

HPTAB:  db 1,2,6
EWTAB:  db 8,7,12
EHTAB:  db 6,8,8
PTSTAB: dw $0100,$0150,$0500

; ---------------------------------------------------------------- enemies
upd_enemies:
        ld ix,ETAB
        ld b,NEN
.l:     push bc
        ld a,(ix+EO_T)
        or a
        jr z,.n
        inc (ix+EO_TM)
        ld a,(ix+EO_FL)
        or a
        jr z,.nf
        dec (ix+EO_FL)
.nf:    ld a,(ix+EO_T)
        cp T_BOAT
        jr z,.boat
        call follow_path
        ; left the playfield?
        ld a,(ix+EO_X)
        cp 88
        jr nc,.gone
        ld a,(ix+EO_Y)
        cp 84
        jr nc,.gone
        cp 4
        jr c,.gone
        ld a,(ix+EO_T)
        cp T_DRONE
        call z,drone_fire
.n:     pop bc
        ld de,EOSIZE
        add ix,de
        djnz .l
        ret
.gone:  call enemy_escaped
        jr .n
.boat:  ld a,(scroll_step)
        add a,(ix+EO_Y)
        ld (ix+EO_Y),a
        cp 84
        jr nc,.gone
        ld a,(ix+EO_ST)
        or a
        jr nz,.surf
        ld a,(ix+EO_Y)
        cp 24
        jr c,.n
        ld (ix+EO_ST),1
        ld (ix+EO_W),12         ; now it can be hit
        ld (ix+EO_DX),30        ; boats keep their fire timer here
        jr .n
.surf:  call boat_fire
        jr .n

follow_path:
        ld l,(ix+EO_PL)
        ld h,(ix+EO_PH)
        ld a,h
        or l
        jr z,.mv
        ld a,(hl)
        cp $80
        jr z,.end
        ld (ix+EO_DX),a
        inc hl
        ld a,(hl)
        ld (ix+EO_DY),a
        inc hl
        ld (ix+EO_PL),l
        ld (ix+EO_PH),h
        jr .mv
.end:   ld (ix+EO_PL),0
        ld (ix+EO_PH),0
        ld a,(ix+EO_T)
        cp T_DART
        jr nz,.mv
        ; darts dive at where the ship is now
        ld b,(ix+EO_X)
        ld c,(ix+EO_Y)
        call aim
        jr c,.mv
        ; HL = vx, DE = vy in 1/256 px: dive at twice bullet speed -> 1/16 units = v/8
        ld a,l
        sra h
        rra
        sra h
        rra
        sra h
        rra
        ld (ix+EO_DX),a
        ld a,e
        sra d
        rra
        sra d
        rra
        sra d
        rra
        ld (ix+EO_DY),a
        ld a,FX_HIT
        call play_sfx
.mv:    ld a,(ix+EO_DX)
        call mv_x
        ld a,(ix+EO_DY)
        jp mv_y

; aim from (B,C) at the ship: HL = vx, DE = vy (1/256 px per frame)
; carry set if the ship is above (no shot)
aim:
        ld a,(pdead)
        or a
        scf
        ret nz
        ld a,(py)
        add a,3
        sub c
        ret c
        cp 128
        jr c,.dy
        ld a,127
.dy:    rrca
        rrca
        rrca
        and $0F
        ld e,a                  ; dyq
        ld a,(px)
        add a,3
        sub b                   ; signed dx
        jp pe,.ov
        jp p,.pos
        cp -64
        jr nc,.ok
        ld a,-64
        jr .ok
.ov:    ld a,63                 ; unreachable on a 96 px field
.pos:   cp 64
        jr c,.ok
        ld a,63
.ok:    sra a
        sra a
        sra a
        add a,8                 ; dxq 0..15
        ld d,a
        ld a,e
        add a,a
        add a,a
        add a,a
        add a,a
        add a,d                 ; dyq*16+dxq
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,AIMTAB
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        or a
        ret

; drones: telegraph for 8 frames (yellow glint), then fire
drone_fire:
        ld a,(ix+EO_FC)
        or a
        jr z,.idle
        dec (ix+EO_FC)
        ret nz
        ld a,(ix+EO_X)
        add a,3
        ld b,a
        ld a,(ix+EO_Y)
        add a,5
        ld c,a
        jp fire_at
.idle:  ld a,(ix+EO_TM)
        cp 20
        ret c
        ld a,(ix+EO_Y)
        cp 20
        ret c
        cp 60
        ret nc
        call rand
        cp 5
        ret nc
        ld (ix+EO_FC),9
        ret

boat_fire:
        ld a,(ix+EO_FC)
        or a
        jr z,.idle
        dec (ix+EO_FC)
        ret nz
        ld a,(ix+EO_X)
        add a,5
        ld b,a
        ld a,(ix+EO_Y)
        add a,3
        ld c,a
        jp fire_at
.idle:  dec (ix+EO_DX)
        ret nz
        ld (ix+EO_DX),48
        ld (ix+EO_FC),9
        ret

; fire an aimed bullet from (B,C)
fire_at:
        ld a,b
        and $FE
        ld b,a
        push bc
        call aim
        pop bc
        ret c
        push hl
        push de
        ld hl,EBTAB
        ld de,EBSIZE
        ld a,NEB
.f:     push af
        ld a,(hl)
        or a
        jr z,.got
        pop af
        add hl,de
        dec a
        jr nz,.f
        pop de
        pop hl
        ret
.got:   pop af
        ld (hl),1
        inc hl
        ld (hl),0
        inc hl
        ld (hl),b
        inc hl
        ld (hl),0
        inc hl
        ld (hl),c
        inc hl
        pop de                  ; vy
        pop bc                  ; vx
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; ---------------------------------------------------------------- groups
; enemy IX left the screen alive
enemy_escaped:
        ld (ix+EO_T),0
        ld (ix+EO_W),0
        ld a,(ix+EO_G)
        call grp_addr
        dec (hl)
        ret

; enemy IX destroyed
kill_enemy:
        ld a,(ix+EO_T)
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,PTSTAB
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        call add_score
        ld b,(ix+EO_X)
        ld c,(ix+EO_Y)
        ld a,(ix+EO_T)
        cp T_BOAT
        jr z,.big
        call add_expl
        ld a,FX_SMALLX
        call play_sfx
        jr .grp
.big:   inc b
        inc b
        call add_expl
        ld a,b
        sub 4
        ld b,a
        ld a,c
        add a,3
        ld c,a
        call add_expl
        ld a,b
        add a,6
        ld b,a
        call add_expl
        ld a,FX_BIGX
        call play_sfx
.grp:   ld (ix+EO_T),0
        ld (ix+EO_W),0
        ld a,(ix+EO_G)
        call grp_addr
        dec (hl)
        inc hl
        inc (hl)                ; killed
        inc hl
        ld a,(ix+EO_X)
        inc hl
        ld (hl),a
        ld a,(ix+EO_Y)
        inc hl
        ld (hl),a
        dec hl
        dec hl
        dec hl
        dec hl                  ; back to 'left'
        ld a,(hl)
        or a
        ret nz
        inc hl
        ld a,(hl)               ; killed == total?
        inc hl
        cp (hl)
        ret nz
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        cp T_BOAT
        ld a,2                  ; boats drop a weapon pod
        jr z,add_pickup
        ld a,1                  ; whole formation down: a star shard
; A = type, B = x, C = y16
add_pickup:
        ld e,a
        ld hl,PUTAB
        ld a,NPU
.f:     push af
        ld a,(hl)
        or a
        jr z,.got
        pop af
        push de
        ld de,PUSIZE
        add hl,de
        pop de
        dec a
        jr nz,.f
        ret
.got:   pop af
        ld (hl),e
        inc hl
        ld a,b
        cp 90
        jr c,$+4
        ld a,89
        ld (hl),a
        inc hl
        ld (hl),0
        inc hl
        ld (hl),c
        inc hl
        ld (hl),0
        ld a,FX_SHARD
        jp play_sfx

; B = x, C = y16
add_expl:
        ld hl,EXTAB
        ld de,EXSIZE
        ld a,NEX
.f:     push af
        ld a,(hl)
        or a
        jr z,.got
        pop af
        add hl,de
        dec a
        jr nz,.f
        ret
.got:   pop af
        ld (hl),1
        inc hl
        ld a,b
        cp 88
        jr c,$+4
        ld a,87
        ld (hl),a
        inc hl
        ld (hl),c
        ret

; DE = BCD points (D = hundreds/thousands, E = tens/units)
add_score:
        ld hl,score+3
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
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        ld a,1
        ld (score_dirty),a
        ret

; ---------------------------------------------------------------- bullets
upd_ebullets:
        ld ix,EBTAB
        ld b,NEB
.l:     ld a,(ix+0)
        or a
        jr z,.n
        ld l,(ix+1)
        ld h,(ix+2)
        ld e,(ix+5)
        ld d,(ix+6)
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        ld a,h
        cp 95
        jr nc,.k
        ld l,(ix+3)
        ld h,(ix+4)
        ld e,(ix+7)
        ld d,(ix+8)
        add hl,de
        ld (ix+3),l
        ld (ix+4),h
        ld a,h
        cp 82
        jr nc,.k
        cp 6
        jr nc,.n
.k:     ld (ix+0),0
.n:     ld de,EBSIZE
        add ix,de
        djnz .l
        ret

upd_pickups:
        ld ix,PUTAB
        ld b,NPU
.l:     ld a,(ix+0)
        or a
        jr z,.n
        inc (ix+4)
        ld a,(ix+2)
        add a,$70
        ld (ix+2),a
        ld a,(ix+3)
        adc a,0
        ld (ix+3),a
        cp 82
        jr c,.n
        ld (ix+0),0
.n:     ld de,PUSIZE
        add ix,de
        djnz .l
        ret

upd_expl:
        ld hl,EXTAB
        ld b,NEX
.l:     ld a,(hl)
        or a
        jr z,.n
        inc a
        cp 9
        jr c,.s
        xor a
.s:     ld (hl),a
.n:     ld de,EXSIZE
        add hl,de
        djnz .l
        ret

; ---------------------------------------------------------------- collisions
collide:
        call col_shots
        call col_burst
        call col_ebullets
        call col_bodies
        jp col_pickups

; player shots against enemies
col_shots:
        ld hl,PSTAB
        ld b,NPS
.l:     ld a,(hl)
        or a
        jr z,.n
        push bc
        push hl
        inc hl
        ld b,(hl)               ; shot x
        inc hl
        ld c,(hl)               ; shot y16 (3 rows)
        call hit_enemy_at
        pop hl
        pop bc
        jr nc,.n
        ld (hl),0
.n:     ld de,PSSIZE
        add hl,de
        djnz .l
        ret

; point-ish hit test: shot at (B,C..C+2) against every enemy.
; Free slots and submerged boats have width 0, so they never match.
; carry = hit (the enemy has been damaged)
hit_enemy_at:
        ld h,b
        ld a,c
        add a,2
        ld l,a                  ; L = shot bottom row
        ld ix,ETAB
        ld de,EOSIZE
        ld b,NEN
.l:     ld a,h
        sub (ix+EO_X)
        cp (ix+EO_W)
        jr nc,.n
        ld a,l
        sub (ix+EO_Y)
        cp (ix+EO_H2)
        jr nc,.n
        ld a,1
        call damage_enemy
        scf
        ret
.n:     add ix,de
        djnz .l
        or a
        ret

; A = damage to enemy IX
damage_enemy:
        ld d,a
        ld a,(ix+EO_HP)
        sub d
        jr z,.k
        jr c,.k
        ld (ix+EO_HP),a
        ld (ix+EO_FL),2
        push bc
        push de
        push hl
        ld a,FX_HIT
        call play_sfx
        pop hl
        pop de
        pop bc
        ret
.k:     push bc
        push de
        push hl
        call kill_enemy
        pop hl
        pop de
        pop bc
        ret

; burst stars smash enemies and bullets they touch
col_burst:
        ld iy,STTAB
        ld b,4
.l:     push bc
        ld a,(iy+0)
        cp ST_BURST
        jr nz,.n
        ; enemies: test a 5x5 box round the star with the shot test
        ld b,(iy+2)
        ld c,(iy+4)
        dec c
        call hit_enemy_at
        ld a,(iy+2)
        add a,2
        ld b,a
        ld c,(iy+4)
        dec c
        call hit_enemy_at
.n:     pop bc
        ld de,STSIZE
        add iy,de
        djnz .l
        ret

; enemy bullets against the cockpit and attached stars
col_ebullets:
        ld ix,EBTAB
        ld b,NEB
.l:     push bc
        ld a,(ix+0)
        or a
        jr z,.n
        ld a,(pdead)
        or a
        jr nz,.n
        ; cockpit: pixels px+3..px+4, rows py+3..py+4
        ld a,(pinv)
        or a
        jr nz,.st
        ld a,(px)
        add a,2
        ld c,a
        ld a,(ix+2)
        sub c                   ; bx - (px+2) in 0..2 -> overlap
        cp 3
        jr nc,.st
        ld a,(py)
        add a,2
        ld c,a
        ld a,(ix+4)
        sub c
        cp 3
        jr nc,.st
        ld (ix+0),0
        call player_hit
        jr .n
.st:    ; stars
        ld iy,STTAB
        ld b,0
.sl:    ld a,(iy+0)
        cp ST_ON
        jr nz,.sn
        ld a,(iy+2)
        dec a
        ld c,a
        ld a,(ix+2)
        sub c
        cp 4
        jr nc,.sn
        ld a,(iy+4)
        dec a
        ld c,a
        ld a,(ix+4)
        sub c
        cp 4
        jr nc,.sn
        ld (ix+0),0
        push ix
        push iy
        pop ix
        call knock_loose
        pop ix
        jr .n
.sn:    ld de,STSIZE
        add iy,de
        inc b
        ld a,b
        cp 4
        jr nz,.sl
.n:     pop bc
        ld de,EBSIZE
        add ix,de
        dec b
        jp nz,.l
        ret

; flying enemies against the ship and its stars
col_bodies:
        ld a,(pdead)
        or a
        ret nz
        ld ix,ETAB
        ld b,NEN
.l:     push bc
        ld a,(ix+EO_T)
        or a
        jr z,.n
        cp T_BOAT
        jr z,.n
        ; ship: enemy box (x+1..x+5, y+1..y+4) against px+2..px+5, py+2..py+5
        ld a,(pinv)
        or a
        jr nz,.st
        ld a,(px)
        sub (ix+EO_X)           ; px - ex
        add a,4                 ; overlap when -4 <= px-ex <= 3
        cp 8
        jr nc,.st
        ld a,(py)
        sub (ix+EO_Y)
        add a,4
        cp 7
        jr nc,.st
        ld a,2
        call damage_enemy
        call player_hit
        jr .n
.st:    ld iy,STTAB
        ld b,0
.sl:    ld a,(iy+0)
        cp ST_ON
        jr nz,.sn
        ld a,(iy+2)
        sub (ix+EO_X)
        add a,2
        cp 8
        jr nc,.sn
        ld a,(iy+4)
        sub (ix+EO_Y)
        add a,2
        cp 7
        jr nc,.sn
        push bc
        ld a,2
        call damage_enemy
        pop bc
        push ix
        push iy
        pop ix
        call knock_loose
        pop ix
        jr .n
.sn:    ld de,STSIZE
        add iy,de
        inc b
        ld a,b
        cp 4
        jr nz,.sl
.n:     pop bc
        ld de,EOSIZE
        add ix,de
        djnz .l
        ret

; pickups against the ship
col_pickups:
        ld a,(pdead)
        or a
        ret nz
        ld ix,PUTAB
        ld b,NPU
.l:     push bc
        ld a,(ix+0)
        or a
        jr z,.n
        ld a,(px)
        sub (ix+1)
        add a,5
        cp 13
        jr nc,.n
        ld a,(py)
        sub (ix+3)
        add a,5
        cp 13
        jr nc,.n
        ld a,(ix+0)
        ld (ix+0),0
        cp 2
        jr z,.pod
        ; star shard: a new star in the first free slot (W, E, N, S)
        ld hl,FILLORD
        ld b,4
.fs:    ld a,(hl)
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,STTAB
        add hl,de
        ld a,(hl)
        or a
        jr z,.free
        pop hl
        inc hl
        djnz .fs
        ld de,$1000             ; all four stars: bonus
        call add_score
        ld a,FX_POWER
        call play_sfx
        jr .n
.free:  ld (hl),ST_ON
        pop hl
        ld de,$0300
        call add_score
        ld a,FX_CATCH
        call play_sfx
        jr .n
.pod:   ld a,(wlevel)
        cp 3
        jr nc,.full
        inc a
        ld (wlevel),a
        call hud_weapon
        ld a,FX_POWER
        call play_sfx
        jr .n
.full:  ld de,$2000
        call add_score
        ld a,FX_POWER
        call play_sfx
.n:     pop bc
        ld de,PUSIZE
        add ix,de
        dec b
        jp nz,.l
        ret

FILLORD: db 1,2,0,3

; the ship has been hit: a star takes it if there is one
player_hit:
        ld a,(pinv)
        or a
        ret nz
        ld a,(pdead)
        or a
        ret nz
        push ix
        push iy
        ld hl,LOSEORD
        ld b,4
.f:     ld a,(hl)
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,STTAB
        add hl,de
        ld a,(hl)
        cp ST_ON
        jr z,.got
        pop hl
        inc hl
        djnz .f
        ; no stars: the ship is lost
        pop iy
        pop ix
        ld a,50
        ld (pdead),a
        ld hl,lives
        dec (hl)
        ld a,(wlevel)
        cp 2
        jr c,.wl
        dec a
        ld (wlevel),a
.wl:    ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        call add_expl
        ld a,b
        sub 4
        ld b,a
        ld a,c
        add a,3
        ld c,a
        call add_expl
        ld a,b
        add a,7
        ld b,a
        call add_expl
        call hud_lives
        call hud_weapon
        ld a,FX_DIE
        jp play_sfx
.got:   pop de
        ld a,(de)
        ld b,a                  ; slot
        push hl
        pop ix
        call knock_loose
        ld a,20
        ld (pinv),a
        pop iy
        pop ix
        ret

LOSEORD: db 3,1,2,0

game_over:
        ld a,1
        ld (pdead),a            ; keeps the ship out of play
        ld a,2
        ld (mode),a
        ld hl,0
        ld (mode_tm),hl
        call stop_music
        ; new high score?
        ld hl,score
        ld de,hiscore
        ld b,4
.c:     ld a,(de)
        cp (hl)
        jr c,.new
        jr nz,.old
        inc hl
        inc de
        djnz .c
        jr .old
.new:   ld hl,score
        ld de,hiscore
        ld bc,4
        ldir
        call hud_hi
.old:   ld a,(lives)
        ret

; ---------------------------------------------------------------- drawing
draw_all:
        call compose_bg
        ; boats and their wakes (on the water, under everything)
        ld ix,ETAB
        ld b,NEN
.bt:    push bc
        ld a,(ix+EO_T)
        cp T_BOAT
        jr nz,.btn
        ld a,(ix+EO_X)
        cp 84
        jr nc,.btn
        ld hl,SPR_BOAT0
        ld a,(ix+EO_ST)
        or a
        jr nz,.bs
        ld hl,SPR_RIPPLE0
        bit 2,(ix+EO_TM)
        jr z,.bs
        ld hl,SPR_RIPPLE1
        jr .bd
.bs:    ld a,(ix+EO_FL)
        or a
        jr z,.bd
        ld hl,SPR_BOAT0W
.bd:    ld b,(ix+EO_X)
        ld c,(ix+EO_Y)
        call draw_obj
.btn:   pop bc
        ld de,EOSIZE
        add ix,de
        djnz .bt
        ; player shots
        ld hl,PSTAB
        ld b,NPS
.ps:    ld a,(hl)
        or a
        jr z,.psn
        push bc
        push hl
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        call draw_shot
        pop hl
        pop bc
.psn:   ld de,PSSIZE
        add hl,de
        djnz .ps
        ; flying enemies
        ld ix,ETAB
        ld b,NEN
.en:    push bc
        ld a,(ix+EO_T)
        cp T_DRONE
        jr z,.dr
        cp T_DART
        jr nz,.enn
        ld hl,SPR_DART0
        bit 1,(ix+EO_TM)
        jr z,.da
        ld hl,SPR_DART1
.da:    ld a,(ix+EO_FL)
        or a
        jr z,.ed
        ld hl,SPR_DART0W
        jr .ed
.dr:    ld hl,SPR_DRONE0
        bit 2,(ix+EO_TM)
        jr z,.dw
        ld hl,SPR_DRONE1
.dw:    ld a,(ix+EO_FL)
        or a
        jr z,.ed
        ld hl,SPR_DRONE0W
.ed:    ld a,(ix+EO_X)
        cp 88
        jr nc,.enn
        ld b,a
        ld c,(ix+EO_Y)
        call draw_obj
.enn:   pop bc
        ld de,EOSIZE
        add ix,de
        djnz .en
        ; pickups
        ld ix,PUTAB
        ld b,NPU
.pu:    push bc
        ld a,(ix+0)
        or a
        jr z,.pun
        ld hl,SPR_POD0
        cp 2
        jr z,.pd
        ld hl,SPR_SHARD0
        bit 2,(ix+4)
        jr z,.pd
        ld hl,SPR_SHARD1
.pd:    ld b,(ix+1)
        ld c,(ix+3)
        call draw_obj
.pun:   pop bc
        ld de,PUSIZE
        add ix,de
        djnz .pu
        ; explosions
        ld ix,EXTAB
        ld b,NEX
.ex:    push bc
        ld a,(ix+0)
        or a
        jr z,.exn
        dec a
        srl a
        add a,a
        ld e,a
        ld d,0
        ld hl,EXPLTAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,(ix+1)
        ld c,(ix+2)
        call draw_obj
.exn:   pop bc
        ld de,EXSIZE
        add ix,de
        djnz .ex
        ; stars
        ld ix,STTAB
        ld b,4
.sr:    push bc
        ld a,(ix+0)
        or a
        jr z,.srn
        cp ST_LOOSE
        jr nz,.sv
        ld a,(ix+7)             ; loose: blink, faster as time runs out
        cp 20
        ld a,(anim)
        jr nc,.sb
        add a,a
.sb:    and 2
        jr nz,.srn
.sv:    ld a,(ix+2)
        cp 94
        jr nc,.srn
        ld hl,SPR_STAR0
        ld a,(anim)
        and 4
        jr z,.sd
        ld hl,SPR_STAR1
.sd:    ld b,(ix+2)
        ld c,(ix+4)
        call draw_obj
.srn:   pop bc
        ld de,STSIZE
        add ix,de
        djnz .sr
        ; the ship
        ld a,(mode)
        cp 1
        jr nz,.nos
        ld a,(pdead)
        or a
        jr nz,.nos
        ld a,(pinv)
        or a
        jr z,.vis
        ld a,(anim)
        and 2
        jr nz,.nos
.vis:   ld a,(pbank)
        add a,a
        ld e,a
        ld a,(anim)
        and 1
        add a,e
        add a,a
        ld e,a
        ld d,0
        ld hl,CRUXTAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(px)
        ld b,a
        ld a,(py)
        ld c,a
        call draw_obj
.nos:   ; enemy bullets on top: red and yellow, alternating
        ld ix,EBTAB
        ld b,NEB
.eb:    push bc
        ld a,(ix+0)
        or a
        jr z,.ebn
        ld e,$FF
        ld a,(anim)
        and 1
        jr z,.ec
        ld e,$55
.ec:    ld b,(ix+2)
        ld c,(ix+4)
        call draw_dot
.ebn:   pop bc
        ld de,EBSIZE
        add ix,de
        djnz .eb
        ; firing glints: a flashing yellow dot where the shot will come from
        ld ix,ETAB
        ld b,NEN
.tg:    push bc
        ld a,(ix+EO_T)
        or a
        jr z,.tgn
        ld a,(ix+EO_FC)
        or a
        jr z,.tgn
        ld a,(anim)
        and 1
        jr z,.tgn
        ld a,(ix+EO_X)
        add a,3
        ld b,a
        ld a,(ix+EO_Y)
        add a,4
        ld c,a
        ld a,(ix+EO_T)
        cp T_BOAT
        jr nz,.tgd
        inc b
        inc b
        dec c
.tgd:   ld e,$55
        call draw_dot
.tgn:   pop bc
        ld de,EOSIZE
        add ix,de
        djnz .tg
        ; captions
        ld a,(mode)
        cp 2
        jr z,.over
        ld hl,(mode_tm)
        ld a,h
        or a
        ret nz
        ld a,l
        cp 60
        ret nc
        ld hl,SPR_T_READY
        ld b,36
        ld c,8+28
        jp draw_spr
.over:  ld hl,SPR_T_OVER
        ld b,30
        ld c,8+28
        jp draw_spr

CRUXTAB: dw SPR_CRUX_C0,SPR_CRUX_C1,SPR_CRUX_L0,SPR_CRUX_L1,SPR_CRUX_R0,SPR_CRUX_R1
EXPLTAB: dw SPR_EXPL0,SPR_EXPL1,SPR_EXPL2,SPR_EXPL3
