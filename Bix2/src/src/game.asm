; =====================================================================
;  game.asm - main loop, input, player physics, camera, level setup
; =====================================================================

game_loop:
.lp:    call maybe_ei
        call read_input
        call player_update
        call camera_update
        call maybe_ei
        call ring_update
        call maybe_ei
        call ents_update
        call parts_update
        call star_twinkle
        call music_tick
        call hud_update
.w:     call maybe_ei
        ld a,(ready)
        or a
        jr nz,.w
        call shake_on
        call draw_bg
        call maybe_ei
        call ents_draw
        call player_draw
        call parts_draw
        call shake_off
        ld a,1
        ld (ready),a
        ld hl,frame
        inc (hl)
        ld a,(pstate)
        cp ST_WIN
        jr z,.nt
        cp ST_DIE
        jr z,.nt
        ld a,(mode)             ; time attack clock
        or a
        jr z,.story
        ld hl,(timer)
        inc hl
        ld (timer),hl
        ld a,l
        and 1
        ld (hudflag),a
        ld a,h                  ; left alone for 10 minutes: give up the run
        cp $3A
        jr c,.nt
        ld (gameover),a
        jr .nt
.story: ld a,(demo)
        or a
        jr nz,.nt
        ld hl,tsub              ; story: count the level clock down each second
        inc (hl)
        ld a,(hl)
        cp 25
        jr c,.nt
        ld (hl),0
        ld hl,(tsec)
        ld a,h
        or l
        jr z,.nt
        dec hl
        ld (tsec),hl
        ld a,1
        ld (hudflag),a
        ld a,h
        or l
        jr nz,.tk
        call player_die         ; TIME UP
        jr .nt
.tk:    ld a,h                  ; hurry-up tick for the last 30 seconds
        or a
        jr nz,.nt
        ld a,l
        cp 31
        jr nc,.nt
        ld a,SFX_STAR
        call sfx_play
.nt:    ld a,(levdone)
        or a
        ret nz
        ld a,(gameover)
        or a
        ret nz
        jp .lp

; wait until the ISR has shown the last frame (used before leaving gameplay)
flush_frame:
.w:     call maybe_ei
        ld a,(ready)
        or a
        jr nz,.w
        ret

; ---------------------------------------------------------------- input
; keyboard: O/Z left, P/X right, Q up, A down, SPACE/M jump ; joystick #1 via $2C
read_input:
        ld c,0
        ld a,($68BF)            ; U P I RET O Y
        bit 1,a
        jr nz,.k1
        set KB_L,c
.k1:     bit 4,a
        jr nz,.k2
        set KB_R,c
.k2:     ld a,($68FB)            ; V Z C SHIFT X B
        bit 4,a
        jr nz,.k3
        set KB_L,c
.k3:     bit 1,a
        jr nz,.k4
        set KB_R,c
.k4:     ld a,($68FE)            ; R Q E - W T
        bit 4,a
        jr nz,.k5
        set KB_U,c
.k5:     ld a,($68FD)            ; F A D CTRL S G
        bit 4,a
        jr nz,.k6
        set KB_D,c
.k6:     ld a,($68EF)            ; M SPACE , - . N
        and $30
        cp $30
        jr z,.k7
        set KB_J,c
.k7:     call joy_read           ; either joystick
        ld b,a
        bit 0,b
        jr z,.j1
        set KB_U,c
.j1:    bit 1,b
        jr z,.j2
        set KB_D,c
.j2:    bit 2,b
        jr z,.j3
        set KB_L,c
.j3:    bit 3,b
        jr z,.j4
        set KB_R,c
.j4:    bit 4,b
        jr z,.k8
        set KB_J,c
.k8:    ld a,($68FD)            ; S: music on/off (on the key's press)
        cpl
        and 2
        ld hl,skey
        ld b,(hl)
        ld (hl),a
        cpl
        and b
        jr z,.k9
        ld hl,musoff
        ld a,(hl)
        xor 1
        ld (hl),a
.k9:    ld a,(demo)
        or a
        call nz,demo_input
        ld a,(keys)
        ld (keysold),a
        cpl
        and c
        ld (kedge),a
        ld a,c
        ld (keys),a
        ret

; ---------------------------------------------------------------- helpers
getpos:                         ; px16,py16 -> ppx (16) , ppy (signed 8)
        ld hl,(px16)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld (ppx),hl
        ld hl,(py16)
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ld a,l
        ld (ppy),a
        ret
setposx:                        ; ppx -> px16 (subpixel cleared)
        ld hl,(ppx)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (px16),hl
        ret
setposy:                        ; ppy -> py16
        ld a,(ppy)
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (py16),hl
        ret

; tile_at: HL = world x (pixels), A = world y (signed). Returns A = attr,
; B = tile id, HL = map address (valid only when B/A come from the map).
tile_at:
        bit 7,a
        jr nz,.sky
        cp RROWS
        jr nc,.sky
        srl a
        srl a
        srl a
        ld c,a
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        push de
        call mul12
        ld b,0
        add hl,bc
        ld de,MAP
        add hl,de
        ld a,(hl)
        ld b,a
        ld e,a
        ld d,high tattr
        ld a,(de)
        pop de
        ret
.sky:   xor a
        ld b,a
        ret

; set_tile: HL = map address, A = new tile; re-render it in the ring.
; (Levels are reloaded from the world bank, so no undo log is needed.)
set_tile_log:
set_tile:
        ld (hl),a
        ; tx = (addr-MAP)/12 , ty = remainder
        ld de,MAP
        or a
        sbc hl,de
        ld c,12
        call div16_8            ; HL = quotient, A = remainder
        ld c,a
        jp patch_tile

div16_8:                        ; HL / C -> HL quotient, A remainder
        xor a
        ld b,16
.l:     add hl,hl
        rla
        cp c
        jr c,.n
        sub c
        inc l
.n:     djnz .l
        ret

; ---------------------------------------------------------------- level setup
new_game:
        ld a,3
        ld (lives),a
        ld a,START_LEVEL
        ld (levnum),a
        xor a
        ld (nstars),a
        ld (score),a
        ld (score+1),a
        ld (score+2),a
        ret

camxmax dw 0
pxmax16 dw 0
level_start:
        ld a,(levnum)
        call load_level
        ld a,(demo)
        or a
        jr nz,.nd
        ld hl,OVL_INTRO
        call ovl_call
.nd:    ; limits for camera and player
        ld hl,(levw)
        add hl,hl
        add hl,hl
        add hl,hl
        push hl
        ld de,128
        or a
        sbc hl,de
        ld (camxmax),hl
        pop hl
        ld de,8
        or a
        sbc hl,de
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (pxmax16),hl
        ld hl,(lv_sx)
        ld (chkx),hl
        ld a,(lv_sy)
        ld (chky),a
        ld hl,ENTST
        ld b,64
.e:     ld (hl),0
        inc hl
        djnz .e
        ld hl,$1234
        ld (rnd),hl
        xor a
        ld (frame),a
        call build_starlist
        call demo_start
        ; fall through to respawn
respawn:
        di
        xor a
        ld (ready),a
        ld (pstate),a
        ld (vx),a
        ld (vy),a
        ld (invuln),a
        ld (shield),a
        ld (levdone),a
        ld (gameover),a
        ld (onplat),a
        ld (ridedx),a
        ld (ridedy),a
        ld (burstt),a
        ld (look),a
        ld (facing),a
        ld a,3
        ld (health),a
        ld (tsub),a
        ld hl,TIME_LEVEL        ; a fresh, generous clock for every life
        ld a,(bossmode)
        or a
        jr z,.tl
        ld hl,TIME_BOSS
.tl:    ld (tsec),hl
        ld a,1
        ld (spawnall),a
        ; spawn records: active -> available (dead stay dead)
        ld hl,ENTST
        ld b,64
.e:     ld a,(hl)
        cp 1
        jr nz,.e1
        ld (hl),0
.e1:    inc hl
        djnz .e
        ld hl,POOL
        ld b,NENT*16
.p:     ld (hl),0
        inc hl
        djnz .p
        ld hl,PARTS
        ld b,NPART*8
.q:     ld (hl),0
        inc hl
        djnz .q
        ; player position from checkpoint tile
        ld hl,(chkx)
        add hl,hl
        add hl,hl
        add hl,hl
        ld (ppx),hl
        call setposx
        ld a,(chky)
        add a,a
        add a,a
        add a,a
        sub 2
        ld (ppy),a
        call setposy
        ld a,(ppy)
        ld (refy),a
        ld (safey),a
        ld hl,(ppx)
        ld (safex),hl
        call camera_snap
        call cls_vram
        call hud_draw_all
        ld a,(latchv)
        ld (LATCH),a
        call ring_fill
        call spawn_scan         ; enemies in view appear with the scene
        call music_start_level
        xor a
        ld (lastcopy),a
        ld (fieldctr),a
        ei
        ret

cls_vram:
        ld a,(tiles)
        ld hl,VRAM
        ld de,VRAM+1
        ld bc,2047
        ld (hl),a
        ldir
        ret

; ---------------------------------------------------------------- camera
camera_snap:
        call cam_target
        ld (camx),hl
        ld a,c
        ld (camy),a
        ret

; cam_target -> HL = target camx (clamped), C = target camy
cam_target:
        ld hl,(ppx)
        ld a,(look)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        add hl,de
        ld de,64-4
        or a
        sbc hl,de
        bit 7,h                 ; signed: looking left near the level start goes
        jr z,.x1                ; below zero - clamp to 0 (was sent to the far end)
        ld hl,0
.x1:    ld de,(camxmax)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.x2
        ex de,hl
.x2:    ; vertical: follow the height Bix last stood at (no bobbing on jumps)
        ld a,(pstate)
        cp ST_BURROW
        jr z,.ref
        ld a,(onground)
        or a
        jr z,.nref
.ref:   ld a,(ppy)
        ld (refy),a
.nref:  ld a,(lv_world)
        ld b,22
        cp 2
        jr c,.cw
        cp 4
        jr nc,.cw
        ld b,30                 ; caverns: frame a little higher to show the ceiling
.cw:    ld a,(refy)
        sub b
        jr nc,.y1
        xor a
.y1:    bit 7,a
        jr z,.y0
        xor a
.y0:    cp RROWS-PFROWS
        jr c,.y2
        ld a,RROWS-PFROWS
.y2:    ld c,a
        ; keep Bix inside rows 2..44 of the view
        ld a,(ppy)
        sub c
        bit 7,a
        jr nz,.hi
        cp 2
        jr c,.hi
        cp 45
        ret c
        ld a,(ppy)
        sub 44
        cp RROWS-PFROWS
        jr c,.lo
        ld a,RROWS-PFROWS
.lo:    ld c,a
        ret
.hi:    ld a,(ppy)
        sub 2
        jr c,.h0
        bit 7,a
        jr z,.h1
.h0:    xor a
.h1:    ld c,a
        ret
refy    db 0

camera_update:
        ; look-ahead drifts toward vx (speed) plus a little facing bias
        ld a,(vx)
        sra a
        ld b,a
        ld a,(facing)
        or a
        ld a,16                 ; show a bit more of what's ahead
        jr z,.f
        ld a,-16
.f:     add a,b
        ld b,a                  ; desired look
        ld hl,look
        ld a,b
        sub (hl)
        jr z,.l3
        jp m,.ldec
        inc (hl)
        jr .l3
.ldec:  dec (hl)
.l3:    call cam_target
        ; x: step = (target - camx)/4 clamped to +-4, at least 1
        ld de,(camx)
        push bc
        or a
        sbc hl,de               ; diff (signed 16)
        ld a,h
        or l
        jr z,.ydo
        bit 7,h
        jr nz,.xneg
        ld a,h
        or a
        jr nz,.xp4
        ld a,l
        srl a
        srl a
        jr nz,.xp
        inc a
.xp:    cp 5
        jr c,.xpa
.xp4:   ld a,4
.xpa:   ld l,a
        ld h,0
        add hl,de
        ld (camx),hl
        jr .ydo
.xneg:  ; negative diff
        ld a,h
        cp $FF
        jr nz,.xn4
        ld a,l
        neg
        srl a
        srl a
        jr nz,.xn
        inc a
.xn:    cp 5
        jr c,.xna
.xn4:   ld a,4
.xna:   ld l,a
        ld h,0
        ex de,hl
        or a
        sbc hl,de
        ld (camx),hl
.ydo:   pop bc
        ld a,(camy)
        ld b,a
        ld a,c
        sub b
        ret z
        jr c,.yup
        srl a
        jr nz,.yd1
        inc a
.yd1:   cp 4
        jr c,.yd2
        ld a,3
.yd2:   add a,b
        ld (camy),a
        ret
.yup:   neg
        srl a
        jr nz,.yu1
        inc a
.yu1:   cp 4
        jr c,.yu2
        ld a,3
.yu2:   ld c,a
        ld a,b
        sub c
        ld (camy),a
        ret

; ---------------------------------------------------------------- player
onplat  db 0
ridedy  db 0

player_update:
        ld a,(pstate)
        cp ST_BURROW
        jp z,burrow_update
        cp ST_DIE
        jp z,die_update
        cp ST_WIN
        jp z,win_update
        ; ---- timers
        ld hl,invuln
        call dec_nz
        ld hl,shield
        call dec_nz
        ld hl,burstt
        call dec_nz
        ld hl,landt
        call dec_nz
        ld hl,jbuf
        call dec_nz
        ld a,(kedge)
        and K_J|K_U
        jr z,.nb
        ld a,5
        ld (jbuf),a
.nb:    ; ---- ride a platform
        ld a,(onplat)
        or a
        jr z,.nr
        ld a,(ridedx)
        call add_px
        ld a,(ridedy)
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(py16)
        add hl,de
        ld (py16),hl
.nr:    ; ---- horizontal control
        call p_horiz
        ; ---- jump
        ld hl,wings
        call dec_nz
        ld a,(jbuf)
        or a
        jr z,.nj
        ld a,(onground)
        ld b,a
        ld a,(coyote)
        or b
        jr nz,.dj
        ; in the air: Wattle Wings give one extra jump
        ld a,(wings)
        or a
        jr z,.nj
        ld a,(dblused)
        or a
        jr nz,.nj
        ld a,1
        ld (dblused),a
        ld a,SFX_SPRING
        call sfx_play
.dj:    call do_jump
.nj:    ; variable height: release cuts upward speed
        ld a,(keys)
        and K_J|K_U
        jr nz,.held
        ld a,(vy)
        bit 7,a
        jr z,.grav
        cp 256-CUTV
        jr nc,.grav
        ld a,256-CUTV
        ld (vy),a
        jr .grav
.held:
.grav:  ld a,(vy)
        ld b,GRAV
        bit 7,a
        jr z,.g1
        ld c,a
        ld a,(keys)
        and K_J|K_U
        ld a,c
        jr z,.g1
        ld b,GRAVHI
.g1:    add a,b
        bit 7,a
        jr nz,.g2
        cp MAXFALL
        jr c,.g2
        ld a,MAXFALL
.g2:    ld (vy),a
        ; ---- move & collide
        call getpos
        ld a,(ppy)
        ld (oldppy),a
        ld a,(vx)
        call add_px
        call getpos
        call p_collide_x
        ld a,(vy)
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        ld de,(py16)
        add hl,de
        ld (py16),hl
        call getpos
        ld a,(onground)
        ld (wasground),a
        xor a
        ld (onground),a
        ld (onplat),a
        call p_collide_y
        ld a,(onground)
        or a
        jr z,.air
        xor a
        ld (dblused),a
        ld a,(onplat)           ; remember solid ground for rescues
        or a
        jr nz,.nsf
        ld hl,(ppx)
        ld (safex),hl
        ld a,(ppy)
        ld (safey),a
.nsf:   ld a,4
        ld (coyote),a
        ld a,(wasground)
        or a
        jr nz,.ck
        ; just landed: dust + squash
        ld a,3
        ld (landt),a
        call dust_puff
        jr .ck
.air:   ld hl,coyote
        call dec_nz
.ck:    call conveyor
        call p_checks
        jp p_anim

conveyor:                       ; factory belts carry Bix to the right
        ld a,(lv_world)
        cp 4
        jp nc,updraft           ; sky winds and volcanic heat vents
        cp 3
        ret nz
        ld a,(onground)
        or a
        ret z
        ld hl,(ppx)
        ld de,4
        add hl,de
        ld a,(ppy)
        add a,10
        call tile_at
        ld a,b
        cp T_LOG
        ret nz
        ld a,16
        call add_px
        call getpos
        jp p_collide_x_push
updraft:                        ; Skyward Isles: wind columns lift Bix
        ld hl,(ppx)
        ld de,4
        add hl,de
        ld a,(ppy)
        add a,5
        call tile_at
        ld a,b
        cp T_FERN
        ret nz
        ld a,(vy)
        sub 14
        bit 7,a
        jr z,.s
        cp 256-44
        jr nc,.s
        ld a,256-44
.s:     ld (vy),a
        xor a
        ld (dblused),a          ; the wind restores the double jump
        ret
wings   db 0
dblused db 0

p_collide_x_push:               ; belts never push Bix into a wall
        ld a,(vx)
        push af
        ld a,1
        ld (vx),a
        call p_collide_x
        pop af
        ld b,a
        ld a,(vx)
        or a
        jr z,.z
        ld a,b
.z:     ld (vx),a
        ret
wasground db 0

dec_nz: ld a,(hl)
        or a
        ret z
        dec (hl)
        ret

; add_px: px16 += sign-extended A, clamped to the level
add_px:
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld hl,(px16)
        add hl,de
        bit 7,d
        jr z,.pos
        jr c,.ok
        ld hl,0
        jr .ok
.pos:   push hl
        ld de,(pxmax16)
        or a
        sbc hl,de
        pop hl
        jr c,.ok
        ld hl,(pxmax16)
.ok:    ld (px16),hl
        ret

p_horiz:
        xor a
        ld (skidding),a
        ld a,(keys)
        and K_L|K_R
        ld c,a
        ld a,(vx)
        ld b,a
        ld a,c
        cp K_L
        jr z,.left
        cp K_R
        jr z,.right
        ; no input: friction
        ld a,(onground)
        or a
        ld d,1
        jr z,.f0
        ld d,FRIC
.f0:    ld a,b
        or a
        jr z,.done
        jp m,.fn
        sub d
        jr nc,.fset
        xor a
        jr .fset
.fn:    add a,d
        jr nc,.fset
        xor a
.fset:  ld b,a
        jr .done
.left:  ld a,1
        ld (facing),a
        ld a,b
        dec a
        bit 7,a                 ; b <= 0 ?
        jr nz,.accl
        ld a,b
        sub SKID
        ld b,a
        ld a,(onground)
        ld (skidding),a
        jr .done
.accl:  call get_acc
        ld d,a
        ld a,b
        sub d
        ld b,a
        bit 7,b
        jr z,.done
        ld a,b
        cp 256-MAXV
        jr nc,.done
        ld b,256-MAXV
        jr .done
.right: xor a
        ld (facing),a
        ld a,b
        bit 7,a
        jr z,.accr
        add a,SKID
        ld b,a
        ld a,(onground)
        ld (skidding),a
        jr .done
.accr:  call get_acc
        add a,b
        ld b,a
        bit 7,b
        jr nz,.done
        cp MAXV+1
        jr c,.done
        ld b,MAXV
.done:  ld a,b
        ld (vx),a
        ret
get_acc:
        ld a,(onground)
        or a
        ld a,ACC
        ret nz
        ld a,AIRACC
        ret

do_jump:
        ld a,(vx)
        call abs_a
        srl a
        srl a
        add a,JUMPV
        neg
        ld (vy),a
        xor a
        ld (onground),a
        ld (coyote),a
        ld (jbuf),a
        ld (onplat),a
        call dust_puff
        ld a,SFX_JUMP
        jp sfx_play

abs_a:  or a
        ret p
        neg
        ret

; horizontal collision against solid tiles at three heights
p_collide_x:
        ld a,(vx)
        ld b,a
        ld a,(ridedx)
        or b
        ret z
        ld a,(vx)
        or a
        jp m,.left
        jr nz,.right
        ld a,(ridedx)
        or a
        jp m,.left
.right: ld hl,(ppx)
        ld de,6
        add hl,de
        call col3
        ret z
        ; snap: ppx = (xr & ~7) - 7
        ld hl,(ppx)
        ld de,6
        add hl,de
        ld a,l
        and $F8
        ld l,a
        ld de,7
        or a
        sbc hl,de
        jr .snap
.left:  ld hl,(ppx)
        inc hl
        call col3
        ret z
        ld hl,(ppx)
        inc hl
        ld a,l
        or 7
        ld l,a
        ; ppx = (xl|7)+1-1
.snap:  ld (ppx),hl
        call setposx
        xor a
        ld (vx),a
        ret
col3:   ; HL = x: NZ if any of y = ppy+1, +5, +9 is solid
        ld (tmp1),hl
        ld a,(ppy)
        inc a
        call tile_at
        and A_SOLID
        ret nz
        ld hl,(tmp1)
        ld a,(ppy)
        add a,5
        call tile_at
        and A_SOLID
        ret nz
        ld hl,(tmp1)
        ld a,(ppy)
        add a,6                 ; (not 9: lets Bix step up slopes and small lips)
        call tile_at
        and A_SOLID
        ret

p_collide_y:
        ld a,(vy)
        bit 7,a
        jp nz,.up
        call slope_land
        ret nz
        ; ---- falling / standing: probe below the feet
        ld hl,(ppx)
        inc hl
        ld a,(ppy)
        add a,10
        call feet_probe
        jr nz,.land
        ld hl,(ppx)
        ld de,6
        add hl,de
        ld a,(ppy)
        add a,10
        call feet_probe
        jr nz,.land
        jp plat_probe
.land:  ld (tmp2),a             ; attr of the landing tile
        ld a,(ppy)
        add a,10
        and $F8
        sub 10
        ld (ppy),a
        call setposy
        ld a,(vy)
        cp 50
        jr c,.soft
        ld a,4
        ld (shake),a
.soft:  xor a
        ld (vy),a
        ld a,1
        ld (onground),a
        ld a,(tmp2)
        and A_SPRING
        ret z
        ld a,256-SPRINGV
        ld (vy),a
        xor a
        ld (onground),a
        ld a,SFX_SPRING
        call sfx_play
        ld a,(burstt)
        cp 6
        ret nc
        ld a,6
        ld (burstt),a           ; springing up also stomps
        ret
.up:    ; ---- rising: probe the head
        ld hl,(ppx)
        inc hl
        ld a,(ppy)
        call tile_at
        and A_SOLID
        jr nz,.bump1
        ld hl,(ppx)
        ld de,6
        add hl,de
        ld a,(ppy)
        call tile_at
        and A_SOLID
        ret z
.bump1: ; hit our head: maybe a block
        push hl
        push bc
        ld a,(ppy)
        or 7
        inc a
        ld (ppy),a
        call setposy
        xor a
        ld (vy),a
        pop bc
        pop hl
        ld a,b
        cp T_TERMITE
        jr z,.brk
        cp T_BONUS
        ret nz
        ; bonus block: becomes used, releases the hidden item above it
        push hl
        ld a,T_USED
        call set_tile_log
        pop hl
        call reveal_bonus       ; HL = map address of the block
        ld a,SFX_BONUS
        jp sfx_play
.brk:   push hl
        ld a,T_SKY
        call set_tile_log
        pop hl
        call block_debris
        ld a,5
        call add_score_a
        ld a,SFX_BREAK
        jp sfx_play

; slope_land: stand on a 45-degree ramp under Bix's centre (vy >= 0).
; NZ if Bix is now standing on a slope.
slope_land:
        ld hl,(ppx)
        ld de,4
        add hl,de
        ld (sl_x),hl
        ld a,(ppy)
        add a,10
        ld (sl_f),a
        call .try
        ret nz
        ld a,(wasground)        ; walking down: look a little lower
        or a
        ret z
        ld a,(sl_f)
        add a,5
        call .try2
        ret
.try:   ld a,(sl_f)
        dec a                   ; the tile just above the feet
.try2:  ld (sl_p),a
        ld hl,(sl_x)
        call tile_at
        ld a,(sl_x)
        and 7
        ld c,a
        ld a,b
        cp T_SLOPEL
        jr z,.l
        cp T_SLOPER
        jr nz,.no
        ld a,7
        sub c
        ld c,a
.l:     ld a,(sl_p)
        and $F8
        add a,c                 ; surface y
        ld c,a
        ld a,(sl_f)
        cp c
        jr c,.no                ; feet still above the surface
        ld a,c
        sub 10
        ld (ppy),a
        call setposy
        xor a
        ld (vy),a
        inc a
        ld (onground),a
        ret                     ; NZ
.no:    xor a
        ret
sl_x    dw 0
sl_f    db 0
sl_p    db 0

; feet_probe: HL=x, A=y -> NZ (A=attr) if we may stand on it
feet_probe:
        ld (tmp3),a
        call tile_at
        ld c,a
        and A_SOLID
        jr nz,.yes
        ld a,c
        and A_ONEWAY
        ret z
        ; one-way: only if feet were above the tile top last frame
        ld a,(tmp3)
        and $F8
        ld b,a
        ld a,(oldppy)
        add a,10
        cp b
        jr z,.yes
        jr c,.yes
        xor a
        ret
.yes:   ld a,c
        or a
        ret

plat_probe:
        ld a,(vy)
        bit 7,a
        ret nz
        ld ix,POOL
        ld b,NENT
.l:     ld a,(ix+0)
        cp E_PLATH
        jr z,.t
        cp E_PLATV
        jr nz,.n
.t:     ; x overlap: ppx+1 <= px+15 and ppx+6 >= px
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,(ppx)
        push hl
        inc de
        ld a,23                 ; platform is 24 pixels wide
        add a,l
        ld l,a
        jr nc,.c1
        inc h
.c1:    or a
        sbc hl,de
        pop hl
        jr c,.n
        ld de,(ppx)
        ld a,6
        add a,e
        ld e,a
        jr nc,.c2
        inc d
.c2:    ex de,hl
        or a
        sbc hl,de
        jr c,.n
        ; y: oldfeet <= py and newfeet >= py
        ld a,(oldppy)
        add a,10
        ld c,(ix+4)
        cp c
        jr z,.y1
        jr nc,.n
.y1:    ld a,(ppy)
        add a,10
        cp c
        jr c,.n
        ; land on platform
        ld a,c
        sub 10
        ld (ppy),a
        call setposy
        xor a
        ld (vy),a
        inc a
        ld (onground),a
        ld (onplat),a
        ld (platix),ix
        ret
.n:     ld de,16
        add ix,de
        djnz .l
        ret

; tile interactions at the body: hazards, stars, checkpoints, exit, pits, dig
p_checks:
        ld a,(ppy)
        bit 7,a
        jr nz,.top
        cp 100
        jp nc,rescue            ; fell out of the world
.top:   ld hl,(ppx)
        ld de,4
        add hl,de
        ld a,(ppy)
        add a,2
        call body_tile
        ld hl,(ppx)
        ld de,4
        add hl,de
        ld a,(ppy)
        add a,8
        call body_tile
        ; dig in: standing on diggable ground and pressing down
        ld a,(onground)
        or a
        ret z
        ld a,(onplat)
        or a
        ret nz
        ld a,(keys)
        and K_D
        ret z
        ld hl,(ppx)
        ld de,4
        add hl,de
        ld a,(ppy)
        add a,11
        call tile_at
        and A_DIG
        ret z
        ; enter the ground
        ld a,ST_BURROW
        ld (pstate),a
        ld a,(ppy)
        add a,6
        ld (ppy),a
        call setposy
        xor a
        ld (vx),a
        ld (vy),a
        ld (onground),a
        ld a,SFX_DIG
        call sfx_play
        jp dirt_spray

body_tile:
        push hl
        ld (tmp1),hl
        ld (tmp3),a
        call tile_at
        pop de
        or a
        ret z
        ld c,a
        and A_HAZ
        jr z,.nh
        ld a,b                  ; water / lava: rescue instead of instant death
        cp T_WATERT
        jp z,rescue
        cp T_WATER
        jp z,rescue
        jp player_hurt
.nh:    ld a,c
        and A_STAR
        jr z,.ns
        ld a,T_SKY
        call set_tile_log
        jp got_star
.ns:    ld a,c
        and A_SPECIAL
        ret z
        ld a,b
        cp T_CHECK
        jr z,.chk
        cp T_EXITT
        jr z,.win
        cp T_EXITB
        ret nz
.win:   ld a,ST_WIN
        ld (pstate),a
        ld a,60
        ld (statet),a
        xor a
        ld (vx),a
        call music_stop
        ld a,SFX_WIN
        jp sfx_play
.chk:   push hl
        ld a,T_CHECKON
        call set_tile_log
        pop hl
        ; checkpoint = this tile (stand at tile row)
        ld hl,(tmp1)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld (chkx),hl
        ld a,(tmp3)
        srl a
        srl a
        srl a
        ld (chky),a
        ld a,SFX_CHECK
        call sfx_play
        ld hl,(tmp1)
        ld a,(tmp3)
        jp sparkle_burst

got_star:
        ld a,SFX_STAR
        call sfx_play
        ld a,1
        call add_score_a
        ld hl,(tmp1)
        ld a,(tmp3)
        call sparkle_burst
        ld a,(nstars)
        inc a
        cp 100
        jr c,.s
        ld hl,lives
        inc (hl)
        ld a,SFX_ONEUP
        call sfx_play
        xor a
.s:     ld (nstars),a
        ld a,1
        ld (hudflag),a
        ret

player_hurt:
        ld a,(invuln)
        ld b,a
        ld a,(shield)
        or b
        ret nz
        ld a,(pstate)
        cp ST_DIE
        ret z
        ld a,(health)
        dec a
        ld (health),a
        ld a,1
        ld (hudflag),a
        ld a,(health)
        or a
        jp z,player_die
        ld a,50
        ld (invuln),a
        ld a,-44
        ld (vy),a
        ld a,(facing)
        or a
        ld a,-24
        jr z,.k
        ld a,24
.k:     ld (vx),a
        ld a,4
        ld (shake),a
        ld a,SFX_HURT
        jp sfx_play

; rescue: fell into water, lava or a pit.  Costs one health point (unless
; flashing) and puts Bix back on the last solid ground he stood on.
rescue:
        ld a,(invuln)
        or a
        jr nz,.keep
        ld a,(health)
        dec a
        ld (health),a
        jp z,player_die
.keep:  ld hl,(safex)
        ld (ppx),hl
        call setposx
        ld a,(safey)
        ld (ppy),a
        call setposy
        xor a
        ld (vx),a
        ld (vy),a
        ld (look),a
        ld a,60
        ld (invuln),a
        ld a,1
        ld (hudflag),a
        ld a,(safey)
        ld (refy),a
        ; snap the view to Bix (the ring is rebuilt, as on a respawn)
        call flush_frame
        call camera_snap
        call ring_fill
        ld a,1
        ld (spawnall),a
        call spawn_scan
        ld a,SFX_HURT
        jp sfx_play
safex   dw 0
safey   db 0

player_die:
        ld a,(pstate)
        cp ST_DIE
        ret z
        ld a,ST_DIE
        ld (pstate),a
        ld a,45
        ld (statet),a
        ld a,-70
        ld (vy),a
        xor a
        ld (vx),a
        ld (health),a
        ld a,1
        ld (hudflag),a
        call music_stop
        ld a,SFX_DIE
        jp sfx_play

die_update:
        ld a,PF_HURT
        ld (pframe),a
        ld a,(vy)
        add a,6
        bit 7,a
        jr nz,.d1
        cp MAXFALL
        jr c,.d1
        ld a,MAXFALL
.d1:    ld (vy),a
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        ld de,(py16)
        add hl,de
        ld (py16),hl
        call getpos
        ld hl,statet
        dec (hl)
        ret nz
        ; life lost
        ld a,(demo)
        or a
        jr z,.nd
        ld a,1
        ld (levdone),a
        ret
.nd:    ld a,(mode)             ; time attack: no lives, the clock keeps running
        or a
        jr z,.nl
        call flush_frame
        jp respawn
.nl:    ld hl,lives
        dec (hl)
        jr z,.go
        call flush_frame
        call respawn
        ret
.go:    ld a,1
        ld (gameover),a
        ret

win_update:
        ld a,(statet)
        and 8
        ld a,PF_CHEER
        jr z,.w
        ld a,PF_IDLE
.w:     ld (pframe),a
        ld hl,statet
        dec (hl)
        ld a,(hl)
        and 7
        jr nz,.n
        call getpos
        ld hl,(ppx)
        ld a,(ppy)
        call sparkle_burst
.n:     ld a,(statet)
        or a
        ret nz
        ld a,1
        ld (levdone),a
        ret

; ---------------------------------------------------------------- burrowing
; Underground Bix travels freely (8 ways) through diggable earth.  The
; burrow point is (ppx+4, ppy+7).  At the surface, JUMP bursts out with a
; launch higher than a normal jump that also defeats anything above.
burrow_update:
        ld hl,invuln
        call dec_nz
        ld hl,shield
        call dec_nz
        call getpos
        ; x movement
        ld a,(keys)
        ld c,0
        bit KB_L,a
        jr z,.x1
        ld c,256-DIGV
        ld a,1
        ld (facing),a
.x1:    ld a,(keys)
        bit KB_R,a
        jr z,.x2
        ld c,DIGV
        xor a
        ld (facing),a
.x2:    ld a,c
        or a
        jr z,.ydo
        ld hl,(px16)
        ld (tmp2),hl
        call add_px
        call getpos
        call bpoint_ok
        jr nz,.ydo
        ld hl,(tmp2)            ; blocked: undo
        ld (px16),hl
        call getpos
.ydo:   ld a,(keys)
        ld c,0
        bit KB_U,a
        jr z,.y1
        ld c,256-DIGV
.y1:    bit KB_D,a
        jr z,.y2
        ld c,DIGV
.y2:    bit KB_J,a              ; holding JUMP underground: tunnel straight up fast
        jr z,.y3
        ld c,256-DIGV*2
.y3:    ld a,c
        or a
        jr z,.burst
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        ld de,(py16)
        ld (tmp2),de
        add hl,de
        ld (py16),hl
        call getpos
        call bpoint_ok
        jr nz,.burst
        ld hl,(tmp2)
        ld (py16),hl
        call getpos
.burst: ; at the surface?  (point within the top soil tile and air above)
        ld hl,(ppx)
        ld de,4
        add hl,de
        ld a,(ppy)
        add a,7-8
        call tile_at
        and A_SOLID
        jr nz,.dig
        ld a,(keys)
        and K_J|K_U
        jr z,.dig
        ; BURST!
        ld a,(ppy)
        add a,7
        and $F8
        sub 10
        ld (ppy),a
        call setposy
        ld a,256-BURSTV
        ld (vy),a
        ld a,ST_NORM
        ld (pstate),a
        ld a,10
        ld (burstt),a
        ld a,SFX_BURST
        call sfx_play
        jp dirt_spray
.dig:   ; convert the tile at the burrow point into a dug tunnel
        ld hl,(ppx)
        ld de,4
        add hl,de
        ld a,(ppy)
        add a,7
        ld (tmp3),a
        ld (tmp1),hl
        call tile_at
        ld a,b
        cp T_BSTAR
        jr nz,.d1
        ld a,T_SOILD
        call set_tile_log
        call got_star
        jr .anim
.d1:    cp T_SOIL
        jr z,.d2
        cp T_SOIL2
        jr nz,.d3
.d2:    ld a,T_SOILD
        call set_tile
        jr .anim
.d3:    cp T_GRASS
        jr nz,.anim
        ld a,T_GRASSD
        call set_tile
.anim:  ld a,(frame)
        and 4
        ld a,PF_BURROW1
        jr z,.a1
        ld a,PF_BURROW2
.a1:    ld (pframe),a
        ld a,(keys)
        and K_L|K_R|K_U|K_D
        ret z
        ld a,(frame)
        and 3
        ret nz
        ld a,SFX_DIGSTEP
        call sfx_play
        jp dirt_bit

bpoint_ok:                      ; NZ if the burrow point is inside diggable earth
        ld hl,(ppx)
        ld de,4
        add hl,de
        ld a,(ppy)
        add a,7
        call tile_at
        and A_DIG
        ret

; ---------------------------------------------------------------- animation
p_anim:
        ld a,(onground)
        or a
        jr nz,.gnd
        ld a,(vy)
        bit 7,a
        ld a,PF_JUMP
        jr nz,.set
        ld a,PF_FALL
        jr .set
.gnd:   ld a,(skidding)
        or a
        ld a,PF_SKID
        jr nz,.set
        ld a,(landt)
        or a
        ld a,PF_LAND
        jr nz,.set
        ld a,(vx)
        call abs_a
        cp 5
        jr c,.idle
        ld b,a
        ld a,(panim)
        add a,b
        ld (panim),a
        xor a
        ld (idlet),a
        ld a,(panim)
        rlca
        rlca
        rlca
        and 3
        add a,PF_RUN1
        jr .set
.idle:  ld hl,idlet
        inc (hl)
        ld a,(hl)
        cp 200
        jr c,.i1
        ld (hl),100
.i1:    ; personality: blinks, an ear twitch, and after a while a dig-sniff
        ld a,(hl)
        cp 120
        jr c,.i2
        and 16
        ld a,PF_DIG
        jr z,.set
        ld a,PF_IDLE
        jr .set
.i2:    and 63
        cp 60
        ld a,PF_BLINK
        jr nc,.set
        ld a,(hl)
        cp 80
        jr c,.i3
        cp 96
        ld a,PF_TWITCH
        jr c,.set
.i3:    ld a,PF_IDLE
.set:   ld (pframe),a
        ret

player_draw:
        ld a,(invuln)
        and 2
        ret nz                  ; flicker while invulnerable
        ld a,(pstate)
        cp ST_DIE
        jr z,.d
        call getpos
.d:     ; shield: sparkle trail
        ld a,(shield)
        ld b,a
        ld a,(wings)
        or b
        jr z,.ns
        ld a,(frame)
        and 1
        jr nz,.ns
        ld hl,(ppx)
        ld a,(ppy)
        call sparkle_one
.ns:    ld hl,(ppx)
        ld de,(camx)
        or a
        sbc hl,de
        ld a,l
        and 3
        ld c,a                  ; phase
        sra h
        rr l
        sra h
        rr l                    ; byte column (signed)
        ld a,h
        inc a
        cp 2
        ret nc                  ; way off screen
        ld b,l
        ; table index ((frame*2+dir)*4+phase)*2
        ld a,(pframe)
        add a,a
        ld hl,facing
        add a,(hl)
        add a,a
        add a,a
        add a,c
        add a,a
        ld e,a
        ld d,0
        ld hl,ptab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld c,b
        ld a,(camy)
        ld b,a
        ld a,(ppy)
        sub b
        ld b,10
        ld e,3
        jp drawspr
