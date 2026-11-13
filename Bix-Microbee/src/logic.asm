; =====================================================================
;  logic.asm - Bix, the enemies and the items: the VZ300 game's own
;  routines, lifted from its source. They work in VZ pixels (a tile is
;  8 x 8 of them) and sixteenths, 25 frames a second, and never touch
;  the display.
; =====================================================================
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
        ld d,tattr >> 8
        ld a,(de)
        pop de
        ret
.sky:   xor a
        ld b,a
        ret

; set_tile: HL = map address, A = new tile; re-render it in the ring.
; (Levels are reloaded from the world bank, so no undo log is needed.)
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
camxmax dw 0
pxmax16 dw 0
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

wings   db 0
dblused db 0

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
        cp 116
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

platix  dw 0
spawnpend db 0

; ---------------------------------------------------------------- spawning
spawn_scan:
        ; Records spawn only in a band just off either screen edge, so an
        ; enemy never appears out of thin air in view (a record whose slot was
        ; full, or whose enemy wandered off, waits until it is off-screen).
        ; After a (re)spawn or a camera snap, spawnall lets everything in.
        ld hl,(camx)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l                    ; camera tile x
        push hl
        ld de,24
        add hl,de
        ld (tmp2),hl            ; window right
        pop hl
        push hl
        ld de,20
        add hl,de
        ld (svhi),hl            ; last tile that could be on screen
        pop hl
        ld de,3
        or a
        sbc hl,de
        jr nc,.c1
        ld hl,0
.c1:    ld (svlo),hl            ; first tile that could be on screen
        ld de,2
        or a
        sbc hl,de
        jr nc,.c0
        ld hl,0
.c0:    ld (tmp1),hl            ; window left
        ld iy,ENTLIST
        ld c,0                  ; record index
.l:     ld a,(iy+0)
        and (iy+1)
        cp $FF
        jr z,.end
        ld a,(iy+3)
        cp E_START
        jr z,.n
        cp E_GLOW
        jr nz,.v
        ld a,(iy+4)
        or a
        jr nz,.n                ; hidden in a bonus block
.v:     ld b,0
        ld hl,ENTST
        add hl,bc
        ld a,(hl)
        or a
        jr nz,.n
        ; within window?
        ld e,(iy+0)
        ld d,(iy+1)
        ld hl,(tmp1)
        ex de,hl
        or a
        sbc hl,de
        jr c,.n
        ld e,(iy+0)
        ld d,(iy+1)
        ld hl,(tmp2)
        or a
        sbc hl,de
        jr c,.n
        ld a,(spawnall)
        or a
        jr nz,.go
        ld a,(iy+3)             ; logs and lifts are scenery: always let them
        cp E_PLATH              ; in, even on screen (a missing one is far
        jr z,.go                ; worse than one appearing)
        cp E_PLATV
        jr z,.go
        ld e,(iy+0)             ; on screen? then not yet
        ld d,(iy+1)
        ld hl,(svlo)
        ex de,hl
        or a
        sbc hl,de
        jr c,.go
        ld e,(iy+0)
        ld d,(iy+1)
        ld hl,(svhi)
        or a
        sbc hl,de
        jr nc,.n
.go:    push bc
        call spawn_rec
        pop bc
.n:     ld de,5
        add iy,de
        inc c
        jr .l
.end:   xor a
        ld (spawnall),a
        ret
svlo    dw 0
svhi    dw 0
spawnall db 1

; spawn_rec: IY = record, C = record index
spawn_rec:
        call free_slot
        ret nc
        ld b,0
        ld hl,ENTST
        add hl,bc
        ld (hl),1
        ld (ix+10),c
        ld a,(iy+3)
        ld (ix+0),a
        ld l,(iy+0)
        ld h,(iy+1)
        add hl,hl
        add hl,hl
        add hl,hl
        ld (ix+2),l
        ld (ix+3),h
        ld (ix+11),l
        ld (ix+12),h
        ld a,(iy+2)
        add a,a
        add a,a
        add a,a
        ld (ix+4),a
        ld (ix+13),a
        ld a,(iy+4)
        add a,a
        add a,a
        add a,a
        ld (ix+14),a
        ld (ix+9),1             ; face left (towards an approaching player)
        ld a,(ix+0)
        cp E_MAG
        jr nz,.nm
        ld (ix+15),15           ; magpies start their patrol at home, not 30px off
.nm:    cp E_PLATH
        jr nz,.n1
        ld (ix+9),0
        jp plat_new
.n1:    cp E_PLATV
        ret nz
        ld (ix+9),1
        jp plat_new

; free_slot -> IX = free pool slot, carry set if found
free_slot:
        ld ix,POOL
        ld b,NENT
        ld de,16
.l:     ld a,(ix+0)
        or a
        jr z,.f
        add ix,de
        djnz .l
        or a
        ret
.f:     push ix
        pop hl
        ld b,16
.z:     ld (hl),0
        inc hl
        djnz .z
        scf
        ret

; reveal_bonus: HL = map address of a bonus block -> pop a Wattle Glow out
reveal_bonus:
        ld de,MAP
        or a
        sbc hl,de
        ld c,16
        call div16_8
        push af
        push hl
        call free_slot
        pop hl
        pop bc                  ; b = ty
        ret nc
        add hl,hl
        add hl,hl
        add hl,hl
        ld (ix+2),l
        ld (ix+3),h
        ld a,b
        add a,a
        add a,a
        add a,a
        ld (ix+4),a
        sub 10
        ld (ix+13),a            ; rise to just above the block
        ld (ix+0),E_GLOW
        ld (ix+10),$FF
        ret

; ---------------------------------------------------------------- update
ents_update:
        xor a
        ld (ridedx),a
        ld (ridedy),a
        ld a,(frame)
        and 3
        jr nz,.sp1
        ld a,1
        ld (spawnpend),a
.sp1:   ld a,(colgen)           ; not on frames that rendered a ring column
        or a
        jr nz,.nsc
        ld a,(spawnpend)
        or a
        jr z,.nsc
        xor a
        ld (spawnpend),a
        call spawn_scan
.nsc:
        ld ix,POOL
        ld b,NENT
.l:     ld a,(ix+0)
        or a
        jr z,.n
        push bc
        call ent_far
        jr c,.desp
        ld a,(ix+0)
        add a,a
        ld e,a
        ld d,0
        ld hl,ent_jt-2
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call jp_hl
        ld a,(ix+0)
        or a
        call nz,ent_touch
        jr .nn
.desp:  call ent_release
.nn:    pop bc
.n:     ld de,16
        add ix,de
        djnz .l
        ret
jp_hl:  jp (hl)

ent_nop: ret

; release a slot; spawn record becomes available again unless dead
ent_release0:
        ld (ix+0),0
        ld a,(ix+10)
        cp $FF
        ret z
        ld e,a
        ld d,0
        ld hl,ENTST
        add hl,de
        ld a,(hl)
        cp 2
        ret z
        ld (hl),0
        ret

; carry set if the entity is far outside the camera
ent_far:
        ld l,(ix+2)
        ld h,(ix+3)
        call .far1
        ret nc                  ; near: keep
        ld a,(ix+0)             ; moving logs/platforms stay while their home
        cp E_PLATH              ; point is near too: otherwise one could vanish
        scf                     ; and not come back until that point had
        ret nz                  ; scrolled off screen
        ld l,(ix+11)
        ld h,(ix+12)
.far1:  ld de,(camx)
        or a
        sbc hl,de               ; sx
        ld de,48
        add hl,de               ; sx+48 must be 0..224
        bit 7,h
        jr nz,.far
        ld a,h
        or a
        jr nz,.far
        ld a,l
        or a                    ; within 48 pixels of a 160 pixel screen
        ret
.far:   scf
        ret

; ---------------------------------------------------------------- behaviours
; tile probe for entities: HL = x, A = y -> attr
ent_tile:
        push bc
        push de
        call tile_at
        pop de
        pop bc
        ret

anim2:  ; toggle frame bit every 4 frames -> A = 0/1
        ld a,(frame)
        rrca
        rrca
        and 1
        ret

ant_upd:
        call anim2
        ld (ix+8),a
        ld a,(frame)
        and 1
        jr nz,.go               ; ants scuttle at 1px every other frame... plus bursts
        ld a,(ix+7)
        inc (ix+7)
        and 3
        ret nz
.go:    ; probe ahead
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,8
        bit 0,(ix+9)
        jr z,.r
        ld de,-1
.r:     add hl,de
        push hl
        ld a,(ix+4)
        add a,4
        call ent_tile
        pop hl
        and A_SOLID
        jr nz,.turn
        ld a,(ix+4)
        add a,9
        call ent_tile
        and A_SOLID|A_ONEWAY
        jr z,.turn
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,1
        bit 0,(ix+9)
        jr z,.m
        ld de,-1
.m:     add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ret
.turn:  ld a,(ix+9)
        xor 1
        ld (ix+9),a
        ret

mag_upd:
        ld a,(frame)
        rrca
        and 1
        ld (ix+8),a
        ld a,(ix+1)
        or a
        jr z,.patrol
        dec a
        jp z,.dive
        ; rising back home
        dec (ix+4)
        ld a,(ix+4)
        cp (ix+13)
        ret nz
        ld (ix+1),0
        ld (ix+7),40            ; cooldown
        ret
.patrol:
        inc (ix+15)
        ld a,(ix+15)
        ; triangle wave -24..+24 over 96 frames
        and 63
        cp 32
        jr c,.t1
        cpl
        and 31
        ld b,a
        ld a,1
        ld (ix+9),a
        ld a,b
        jr .t2
.t1:    ld (ix+9),0
.t2:    sub 16
        add a,a                 ; -32..+30
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(ix+11)
        ld h,(ix+12)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ; bob
        ld a,(ix+15)
        rrca
        rrca
        rrca
        and 3
        add a,(ix+13)
        ld (ix+4),a
        ; cooldown, then watch for Bix below
        ld a,(ix+7)
        or a
        jr z,.watch
        dec (ix+7)
        ret
.watch: ld a,(pstate)
        cp ST_BURROW
        ret z
        call dx_player          ; HL = player x - x (signed)
        ld a,h
        inc a
        cp 2
        ret nc
        ld a,l
        add a,40
        cp 80
        ret nc
        ld a,(ppy)
        sub (ix+4)
        ret c
        cp 8
        ret c
        ; swoop!
        ld (ix+1),1
        ld a,(ppy)
        ld (ix+14),a            ; target y
        ld a,l
        bit 7,a
        ld a,2
        ld (ix+9),0
        jr z,.d1
        ld a,-2
        ld (ix+9),1
.d1:    ld (ix+5),a
        ld a,SFX_SWOOP
        jp sfx_play
.dive:  ld a,(ix+5)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        inc (ix+4)
        inc (ix+4)
        ld a,(ix+4)
        cp (ix+14)
        jr nc,.up
        ld l,(ix+2)
        ld h,(ix+3)
        ld a,(ix+4)
        add a,8
        call ent_tile
        and A_SOLID
        ret z
.up:    ld (ix+1),2
        ld a,(ix+2)
        ld (ix+11),a
        ld a,(ix+3)
        ld (ix+12),a
        ret

drop_upd:
        ld a,(ix+1)
        or a
        jr nz,.fall
        ld (ix+8),0
        ld a,(ix+7)             ; cooldown (pistons)
        or a
        jr z,.armed
        dec (ix+7)
        ret
.armed: call dx_player
        ld a,h
        inc a
        cp 2
        ret nc
        ld a,l
        add a,14
        cp 28
        ret nc
        ld a,(ppy)
        sub (ix+4)
        ret c
        ld (ix+1),1
        ld (ix+6),0
        ld a,SFX_SWOOP
        jp sfx_play
.fall:  dec a
        jr z,.fall1
        dec a
        jp z,.walk
        ; state 3: piston retracting
        ld (ix+8),0
        dec (ix+4)
        ld a,(ix+4)
        cp (ix+13)
        ret nz
        ld (ix+1),0
        ld (ix+7),20
        ret
.fall1: ld (ix+8),1
        ld a,(ix+6)
        cp 6
        jr nc,.f1
        inc (ix+6)
.f1:    ld a,(ix+4)
        add a,(ix+6)
        ld (ix+4),a
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,4
        add hl,de
        ld a,(ix+4)
        add a,8
        call ent_tile
        and A_SOLID|A_ONEWAY
        ret z
        ld a,(ix+4)
        add a,8
        and $F8
        sub 8
        ld (ix+4),a
        ld (ix+1),2
        ld a,3
        ld (shake),a
        ld a,(lv_world)
        cp 3
        jr nz,.nw3
        ld (ix+1),3             ; factory: crusher pistons retract
        ld a,SFX_STOMP
        jp sfx_play
.nw3:   cp 2
        jr z,.shat
        cp 4
        jr z,.shat
        cp 5
        ret nz
.shat:  ; caverns / sky: stalactites and hail shatter on impact
        ld (ix+0),E_BOOM
        ld (ix+7),0
        call mark_dead
        ld a,SFX_BREAK
        jp sfx_play
.walk:  call anim2
        ld (ix+8),a
        ld a,(frame)
        and 1
        ret z
        call dx_player
        bit 7,h
        ld de,1
        ld (ix+9),0
        jr z,.w1
        ld de,-1
        ld (ix+9),1
.w1:    push de
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        bit 7,d
        jr nz,.w2
        ld de,7
        add hl,de
.w2:    ld a,(ix+4)
        add a,4
        call ent_tile
        pop de
        and A_SOLID
        ret nz
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        ret

toad_upd:
        ld a,(ix+1)
        or a
        jr nz,.air
        ld (ix+8),0
        ld a,(ix+7)
        inc (ix+7)
        cp 36
        ret c
        ; hop towards Bix
        ld (ix+7),0
        ld (ix+1),1
        ld (ix+6),-6
        call dx_player
        bit 7,h
        ld a,1
        ld (ix+9),0
        jr z,.h
        ld a,-1
        ld (ix+9),1
.h:     ld (ix+5),a
        ld a,SFX_HOP
        jp sfx_play
.air:   ld (ix+8),1
        ld a,(ix+5)
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        push hl
        ld de,4
        add hl,de
        ld a,(ix+4)
        add a,4
        call ent_tile
        pop hl
        and A_SOLID
        jr nz,.nx
        ld (ix+2),l
        ld (ix+3),h
.nx:    ld a,(frame)
        and 1
        jr z,.ny
        inc (ix+6)
.ny:    ld a,(ix+4)
        add a,(ix+6)
        ld (ix+4),a
        bit 7,(ix+6)
        ret nz
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,4
        add hl,de
        ld a,(ix+4)
        add a,8
        call ent_tile
        and A_SOLID|A_ONEWAY
        ret z
        ld a,(ix+4)
        add a,8
        and $F8
        sub 8
        ld (ix+4),a
        ld (ix+1),0
        ret

plath_move:
        ld a,(frame)            ; half speed: move on every other frame
        and 1
        ret nz
        ld e,1
        bit 0,(ix+9)
        jr z,.r
        ld e,-1
.r:     ld a,e
        ld d,0
        bit 7,e
        jr z,.r1
        dec d
.r1:    ld l,(ix+2)
        ld h,(ix+3)
        add hl,de
        ld (ix+2),l
        ld (ix+3),h
        call plat_ride
        ld (ridedx_tmp),a
        ld a,(ridedx_tmp)
        or a
        jr z,.nr
        ld a,e                  ; carry Bix a whole pixel (px16 is 1/16 pixel)
        add a,a
        add a,a
        add a,a
        add a,a
        ld (ridedx),a
.nr:    ; bounds
        ld l,(ix+2)
        ld h,(ix+3)
        ld e,(ix+11)
        ld d,(ix+12)
        or a
        sbc hl,de
        jr z,.go_r
        jr c,.go_r
        ld a,h
        or a
        jr nz,.go_l
        ld a,l
        cp (ix+14)
        ret c
.go_l:  ld (ix+9),1
        ret
.go_r:  ld (ix+9),0
        ret
ridedx_tmp db 0

; plat_ride -> A = 1 if Bix is standing on this platform
plat_ride:
        ld a,(onplat)
        or a
        ret z
        push ix
        pop hl
        ld bc,(platix)
        or a
        sbc hl,bc
        ld a,0
        ret nz
        inc a
        ret

platv_move:
        ld a,(frame)
        and 1
        ret z
        ld a,1
        bit 0,(ix+9)
        jr z,.d
        ld a,-1
.d:     ld e,a
        add a,(ix+4)
        ld (ix+4),a
        push de
        call plat_ride
        pop de
        or a
        jr z,.nr
        ld a,e
        ld (ridedy),a
.nr:    ld a,(ix+4)
        cp (ix+13)
        jr nc,.up
        ld b,a
        ld a,(ix+13)
        sub (ix+14)
        cp b
        ret c
        ld (ix+9),0             ; reached the top: go down
        ret
.up:    ld (ix+9),1             ; reached the bottom: go up
        ret

glow_upd:
        call anim2
        ld (ix+8),a
        ld a,(ix+4)
        cp (ix+13)
        ret z
        ret c
        dec (ix+4)
        ret

oneup_upd:
        ld (ix+8),0
        ret

; worm / witchetty grub: hides in the ground, pops up when Bix comes near
worm_upd:
        ld a,(ix+1)
        or a
        jr nz,.up
        ld a,(ix+7)
        or a
        jr z,.w
        dec (ix+7)
        ret
.w:     call dx_player
        ld a,h
        inc a
        cp 2
        ret nc
        ld a,l
        add a,36
        cp 72
        ret nc
        ld (ix+1),1
        ld (ix+7),55
        ld a,SFX_HOP
        call sfx_play
        ld l,(ix+2)
        ld h,(ix+3)
        ld (tmp2),hl
        ld a,(ix+4)
        ld (tmp3),a
        ld a,1
        ld (pgrav),a
        ld hl,(tmp2)
        inc hl
        inc hl
        ld a,(tmp3)
        add a,6
        ld bc,$FFFD
        ld de,$0308
        call spawn_part
        ld hl,(tmp2)
        ld de,5
        add hl,de
        ld a,(tmp3)
        add a,6
        ld bc,$01FD
        ld de,$0308
        jp spawn_part
.up:    call anim2
        ld (ix+8),a
        call dx_player
        ld a,h
        rla
        and 1
        ld (ix+9),a
        dec (ix+7)
        ret nz
        ld (ix+1),0
        ld (ix+7),60
        ret

boom_upd:
        inc (ix+7)
        ld a,(ix+7)
        cp 7
        ret c
        ld (ix+0),0
        ret

; HL = player x - entity x
dx_player:
        ld hl,(ppx)
        ld e,(ix+2)
        ld d,(ix+3)
        or a
        sbc hl,de
        ret

; ---------------------------------------------------------------- collisions
ent_touch:
        ld a,(pstate)
        cp ST_DIE
        ret z
        cp ST_WIN
        ret z
        ld a,(ix+0)
        cp E_PLATH
        ret z
        cp E_PLATV
        ret z
        cp E_BOOM
        ret z
        cp E_BOSS
        ret z
        cp E_WORM
        jr nz,.nw
        ld a,(ix+1)
        or a
        ret z
.nw:    ; boxes: player x+1..x+6 , y..y+9 ; entity x+1..x+6 , y+1..y+7
        call dx_player          ; px - ex
        ld a,h
        inc a
        cp 2
        ret nc
        ld a,l
        add a,6
        cp 12
        ret nc
        ld a,(ppy)
        sub (ix+4)
        add a,9                 ; (py - ey) in -9..7 overlaps
        cp 17
        ret nc
        ld a,(ix+0)
        cp E_GLOW
        jr z,.glow
        cp E_ONEUP
        jr z,.oneup
        ld a,(pstate)
        cp ST_BURROW
        ret z
        ld a,(shield)
        ld b,a
        ld a,(burstt)
        or b
        jr nz,.kill
        ld a,(vy)
        bit 7,a
        jr nz,.hurt
        or a
        jr z,.hurt
        ld a,(ppy)
        add a,10
        sub (ix+4)
        cp 6
        jr nc,.hurt
        ; stomp!
        ld a,256-STOMPV
        ld (vy),a
        ld a,(keys)
        and K_J
        jr z,.kill
        ld a,256-STOMPV-24
        ld (vy),a
.kill:  ld (ix+0),E_BOOM
        ld (ix+7),0
        ld (ix+8),0
        call mark_dead
        ld a,$10
        call add_score_a        ; 100 points
        ld a,SFX_STOMP
        jp sfx_play
.hurt:  jp player_hurt
.glow:  ld a,(lv_world)
        cp 4
        jr nz,.gs
        ld a,250                ; Skyward Isles: Wattle Wings (double jump)
        ld (wings),a
        jr .gw
.gs:    ld a,250
        ld (shield),a
.gw:
        ld (ix+0),0
        call mark_dead
        ld a,SFX_POWER
        jp sfx_play
.oneup: ld hl,lives
        inc (hl)
        ld a,1
        ld (hudflag),a
        ld (ix+0),0
        call mark_dead
        ld a,SFX_ONEUP
        jp sfx_play

mark_dead:
        ld a,(ix+10)
        cp $FF
        ret z
        ld e,a
        ld d,0
        ld hl,ENTST
        add hl,de
        ld (hl),2
        ret

; ---------------------------------------------------------------- drawing
random:                         ; A = pseudo random (xorshift-ish)
        push hl
        ld hl,(rnd)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (rnd),hl
        pop hl
        ret

; ---------------------------------------------------------------- particles
; entry: +0 life +1/2 x +3 y +4 vx +5 vy +6 colour +7 gravity
; spawn_part: HL = x, A = y, B = vx, C = vy, D = colour, E = life,
;             (pgrav) = gravity flag
add_score_a:
        ld hl,score+2
        add a,(hl)
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
        ld (hudflag),a
        ret

; ---------------------------------------------------------------- HUD
; VRAM rows 0..6 red bar with yellow 3x5 text, row 7 divider
