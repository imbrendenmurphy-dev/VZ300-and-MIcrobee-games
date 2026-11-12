; =====================================================================
;  PLAYER: the pilot, options, the upgrade bar, the pilots' weapons.
;  y values are biased by 32 (32 = the top of the playfield).
; =====================================================================
; pilot table (16 bytes each)
PT_SPD      equ 0       ; dw speed at level 0 (8.8 px a frame)
PT_STEP     equ 2       ; dw extra speed per level
PT_HEART    equ 4       ; hearts +/-
PT_RATE     equ 5       ; frames between shots
PT_MIS      equ 6       ; missile type
PT_DBL      equ 7       ; double type
PT_LAS      equ 8       ; laser type
PT_INKA     equ 9       ; craft ink
PT_INKB     equ 10      ; rider ink
PT_INKO     equ 11      ; option ink
PT_FRAME    equ 12      ; first sprite frame (A0, B0, A1, B1, option)
PT_HIT      equ 13      ; hitbox half size
PT_BEAM     equ 14      ; beam length
M_BANANA    equ 1
M_PEGS      equ 2
M_GUMNUT    equ 3
M_BUGS      equ 4
D_BONE      equ 1
D_BACK      equ 2
D_SPREAD    equ 3
D_TWIN      equ 4
L_STINK     equ 1
L_RING      equ 2
L_BOOMER    equ 3
L_DOT       equ 4
pilot_tab:
        ; BAZZA: medium
        dw $0240,$0080 : db 0,4,M_BANANA,D_BONE,L_STINK,BGREEN,WHITE,BGREEN,SF_BAZZA_A0,3,72,0
        ; SHEILA: slow, wide
        dw $01E0,$0070 : db 0,4,M_PEGS,D_BACK,L_RING,GREY,GREY,BMAGENTA,SF_SHEILA_A0,3,0,0
        ; WALLY: slow, tough
        dw $01C0,$0070 : db 1,5,M_GUMNUT,D_SPREAD,L_BOOMER,BRED,YELLOW,YELLOW,SF_WALLY_A0,3,0,0
        ; QUEENIE: fast, small, fragile
        dw $02C0,$0090 : db -1,3,M_BUGS,D_TWIN,L_DOT,BCYAN,YELLOW,BBLUE,SF_QUEENIE_A0,2,40,0
        ; LOCKIE: fast mimic
        dw $0280,$0080 : db 0,4,M_GUMNUT,D_SPREAD,L_DOT,BROWN,GREY,BCYAN,SF_LOCKIE_A0,3,48,0

; IY -> the pilot's table entry
pilot_iy:
        ld a,(pilot)
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld iy,pilot_tab
        add iy,de
        ret

reset_powers:
        xor a
        ld (pspeed),a
        ld (pmissile),a
        ld (pdouble),a
        ld (plaser),a
        ld (poptions),a
        ld (pshield),a
        ld (barpos),a
        ld (bellpow),a
        ld (goldrun),a
        ret

; hearts for this pilot and difficulty
full_hearts:
        call pilot_iy
        ld a,(difficulty)
        ld hl,diff_hearts
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        add a,(iy+PT_HEART)
        cp 1
        jr nc,.k
        ld a,1
.k:     ld (maxhearts),a
        ld (hearts),a
        ret
diff_hearts:    db 5,3,1

player_start:
        call full_hearts
        ld hl,40
        ld (px),hl
        ld a,32+80
        ld (py),a
        xor a
        ld (pxf),a
        ld (pyf),a
        ld (pdead),a
        ld (pfire),a
        ld (mfire),a
        ld a,50
        ld (pinv),a
        ; the trail: everyone at the pilot
        ld hl,trail
        ld b,32
.t:     ld (hl),20
        inc hl
        ld (hl),32+80
        inc hl
        djnz .t
        xor a
        ld (trailpos),a
        ret

; ---------------------------------------------------------------------
player_update:
        ld a,(pfire)
        or a
        jr z,$+6
        dec a
        ld (pfire),a
        ld a,(mfire)
        or a
        jr z,$+6
        dec a
        ld (mfire),a
        ld a,(pinv)
        or a
        jr z,$+6
        dec a
        ld (pinv),a
        ld a,(pdead)
        or a
        jp nz,player_dead
        call pilot_iy
        ; speed = base + level * step
        ld l,(iy+PT_SPD)
        ld h,(iy+PT_SPD+1)
        ld a,(pspeed)
        or a
        jr z,.sp
        ld b,a
        ld e,(iy+PT_STEP)
        ld d,(iy+PT_STEP+1)
.sl:    add hl,de
        djnz .sl
.sp:    ld (tmp),hl
        ld a,(pad)
        ld c,a
        xor a
        ld (ptilt),a
        ; ---- x
        bit 0,c
        jr z,.nr
        ld a,(pxf)
        add a,l
        ld (pxf),a
        ld a,(px)
        adc a,h
        ld (px),a
        ld a,(px+1)
        adc a,0
        ld (px+1),a
.nr:    bit 1,c
        jr z,.nl
        ld a,(pxf)
        sub l
        ld (pxf),a
        ld a,(px)
        sbc a,h
        ld (px),a
        ld a,(px+1)
        sbc a,0
        ld (px+1),a
.nl:    ld hl,(px)
        bit 7,h
        jr z,.x0
        ld hl,0
.x0:    ld de,300
        or a
        sbc hl,de
        add hl,de
        jr c,.x1
        ex de,hl
.x1:    ld (px),hl
        ; ---- y
        ld hl,(tmp)
        bit 2,c
        jr z,.nu
        ld a,(pyf)
        sub l
        ld (pyf),a
        ld a,(py)
        sbc a,h
        ld (py),a
        ld a,1
        ld (ptilt),a
.nu:    bit 3,c
        jr z,.nd
        ld a,(pyf)
        add a,l
        ld (pyf),a
        ld a,(py)
        adc a,h
        ld (py),a
        ld a,2
        ld (ptilt),a
.nd:    ; ---- terrain: keep between the ceiling and the floor at the pilot's middle
        ld hl,(px)
        ld de,8
        add hl,de
        srl h
        rr l
        ld a,l
        call ceil_at
        add a,32
        ld b,a
        ld a,(py)
        cp b
        jr nc,.c1
        ld a,b
        ld (py),a
.c1:    ld hl,(px)
        ld de,8
        add hl,de
        srl h
        rr l
        ld a,l
        call floor_at
        add a,32-12
        ld b,a
        ld a,(py)
        cp b
        jr c,.f1
        ld a,b
        ld (py),a
.f1:    ; the screen edges
        ld a,(py)
        cp 32
        jr nc,.e0
        ld a,32
.e0:    cp 32+184-12
        jr c,.e1
        ld a,32+184-12
.e1:    ld (py),a
        ; ---- the trail (only when moving)
        ld a,(pad)
        and 15
        jr z,.nt
        ld a,(trailpos)
        add a,2
        and 63
        ld (trailpos),a
        ld e,a
        ld d,0
        ld hl,trail
        add hl,de
        ld de,(px)
        srl d
        rr e
        ld (hl),e
        inc hl
        ld a,(py)
        ld (hl),a
.nt:    call options_pos
        ; ---- fire
        ld a,(pad)
        and 16
        jr z,.nf
        ld a,(pfire)
        or a
        jr nz,.nf
        ld a,(iy+PT_RATE)
        ld b,a
        ld a,(bellpow)
        cp BP_RED
        jr nz,.r
        srl b
.r:     ld a,b
        ld (pfire),a
        call volley_all
.nf:    ; ---- take the lit upgrade
        ld a,(padnew)
        and 32
        call nz,take_upgrade
        ret

; options: positions along the trail, 8 and 16 moves behind
options_pos:
        ld a,(trailpos)
        sub 16
        call .one
        ld (optx),de
        ld (opty),a
        ld a,(trailpos)
        sub 32
        call .one
        ld (optx+2),de
        ld (opty+1),a
        ret
.one:   and 63
        ld e,a
        ld d,0
        ld hl,trail
        add hl,de
        ld e,(hl)
        ld d,0
        sla e
        rl d
        inc hl
        ld a,(hl)
        ret

; ---------------------------------------------------------------------
; the pilot is out: explode, then come back where he was
player_dead:
        dec a
        ld (pdead),a
        ret nz
        ; back in
        ld a,(lives)
        or a
        jr nz,.on
        ld a,GS_OVER
        ld (gstate),a
        ret
.on:    call full_hearts
        ld a,75
        ld (pinv),a
        ld a,1
        ld (hud_dirty),a
        ret

; hit_player: one hit (shield first, then a heart)
hit_player:
        ld a,(pinv)
        or a
        ret nz
        ld a,(pdead)
        or a
        ret nz
        ld a,(bellpow)
        cp BP_GREEN
        ret z
        ld a,(demo)
        or a
        ret nz
        ld a,(pshield)
        or a
        jr z,.h
        dec a
        ld (pshield),a
        ld a,25
        ld (pinv),a
        ld a,SFX_SHIELD
        jp play_sfx
.h:     ld a,1
        ld (hud_dirty),a
        ld a,(hearts)
        dec a
        ld (hearts),a
        jr z,.die
        ld a,50
        ld (pinv),a
        ld a,SFX_HURT
        jp play_sfx
.die:   ld a,SFX_DIE
        call play_sfx
        ld a,(lives)
        dec a
        ld (lives),a
        ld a,50
        ld (pdead),a
        ; a big bang and three capsules to catch
        ld hl,(px)
        ld a,(py)
        ld c,a
        call fx_boom
        ld b,3
.cp:    push bc
        ld hl,(px)
        ld a,b
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(py)
        sub 8
        add a,b
        add a,b
        add a,b
        ld c,a
        call capsule_at
        pop bc
        djnz .cp
        ; keep speed (at least 1), missile, double / laser; lose an option and the shield
        ld a,(pspeed)
        or a
        jr nz,.s1
        inc a
        ld (pspeed),a
.s1:    ld a,(poptions)
        or a
        jr z,.o1
        dec a
        ld (poptions),a
.o1:    xor a
        ld (pshield),a
        ld (bellpow),a
        ret

; ---------------------------------------------------------------------
; the upgrade bar
take_upgrade:
        ld a,(barpos)
        or a
        ret z
        call slot_maxed
        jr nc,.ok
        ld a,SFX_DENY
        jp play_sfx
.ok:    ld a,(barpos)
        dec a
        jr nz,.n1
        ld hl,pspeed
        inc (hl)
        jr .done
.n1:    dec a
        jr nz,.n2
        ld a,1
        ld (pmissile),a
        jr .done
.n2:    dec a
        jr nz,.n3
        ld a,1
        ld (pdouble),a
        xor a
        ld (plaser),a
        jr .done
.n3:    dec a
        jr nz,.n4
        ld a,1
        ld (plaser),a
        xor a
        ld (pdouble),a
        jr .done
.n4:    dec a
        jr nz,.n5
        ld hl,poptions
        inc (hl)
        jr .done
.n5:    dec a
        jr nz,.n6
        ld a,3
        ld (pshield),a
        jr .done
.n6:    call oi_shout
.done:  xor a
        ld (barpos),a
        ld a,1
        ld (hud_dirty),a
        ld a,SFX_POWER
        jp play_sfx

; slot_maxed: A = slot (1..7) -> C if it can't be taken
slot_maxed:
        dec a
        jr nz,.1
        ld a,(pspeed)
        cp 4
        ccf
        ret
.1:     dec a
        jr nz,.2
        ld a,(pmissile)
        cp 1
        ccf
        ret
.2:     dec a
        jr nz,.3
        ld a,(pdouble)
        cp 1
        ccf
        ret
.3:     dec a
        jr nz,.4
        ld a,(plaser)
        cp 1
        ccf
        ret
.4:     dec a
        jr nz,.5
        ld a,(poptions)
        cp 2
        ccf
        ret
.5:     dec a
        jr nz,.6
        ld a,(pshield)
        cp 3
        ccf
        ret
.6:     or a
        ret

; a capsule picked up: the light moves along
capsule_got:
        ld a,(barpos)
        inc a
        cp 8
        jr c,.k
        ld a,1
.k:     ld (barpos),a
        ld a,1
        ld (hud_dirty),a
        ld de,$0050
        call add_score
        ld a,SFX_CAPSULE
        jp play_sfx

; ---------------------------------------------------------------------
; volleys: the pilot and every option fire
volley_all:
        ld a,SFX_SHOT
        call play_sfx
        ld hl,(px)
        ld a,(py)
        ld c,a
        xor a
        call volley
        ld a,(poptions)
        or a
        ret z
        ld hl,(optx)
        ld a,(opty)
        sub 2
        ld c,a
        ld a,1
        call volley
        ld a,(poptions)
        cp 2
        ret c
        ld hl,(optx+2)
        ld a,(opty+1)
        sub 2
        ld c,a
        ld a,2
        jp volley

; volley: HL = x, C = y (biased, top of a 16 x 12 pilot), A = owner
volley:
        ld (vo_own),a
        ld (vo_x),hl
        ld a,c
        ld (vo_y),a
        ; ---- the main shot: dash, or the laser weapon
        ld a,(plaser)
        or a
        jr nz,.las
        ld b,1
        ld c,2
        call count_class
        jr nc,.dbl
        ld hl,(vo_x)
        ld de,14
        add hl,de
        ld a,(vo_y)
        add a,5
        ld c,a
        ld de,$0008             ; dx 8, dy 0
        ld a,ST_DASH
        call shot_new
        jr .dbl
.las:   ld a,(iy+PT_LAS)
        call laser_fire
.dbl:   ld a,(pdouble)
        or a
        call nz,double_fire
        ld a,(pmissile)
        or a
        ret z
        ld a,(vo_own)
        or a
        jr nz,.mo
        ld a,(mfire)
        or a
        ret nz
        ld a,18
        ld (mfire),a
.mo:    jp missile_fire

; count_class: B = class, C = limit -> NC if the owner has that many already
count_class:
        ld ix,shots
        ld de,SH_SIZE
        ld a,NSHOT
        ld (tmp+4),a
        ld l,0
.l:     ld a,(ix+0)
        or a
        jr z,.n
        ld a,(ix+10)
        cp b
        jr nz,.n
        ld a,(vo_own)
        cp (ix+8)
        jr nz,.n
        inc l
.n:     add ix,de
        ld a,(tmp+4)
        dec a
        ld (tmp+4),a
        jr nz,.l
        ld a,l
        cp c
        ret

; shot_new: A = type, HL = x, C = y, D = dy, E = dx; class (vo_class), owner (vo_own)
; -> IX = the shot (C set if none free)
shot_new:
        push af
        push de
        push hl
        ld ix,shots
        ld de,SH_SIZE
        ld b,NSHOT
.f:     ld a,(ix+0)
        or a
        jr z,.got
        add ix,de
        djnz .f
        pop hl
        pop de
        pop af
        scf
        ret
.got:   pop hl
        pop de
        pop af
        ld (ix+0),a
        ld (ix+1),l
        ld (ix+2),h
        ld (ix+3),c
        ld (ix+4),e
        ld (ix+5),d
        xor a
        ld (ix+6),a
        ld (ix+9),a
        ld (ix+11),a
        ld a,1
        ld (ix+7),a
        ld a,(vo_own)
        ld (ix+8),a
        ld a,(vo_class)
        ld (ix+10),a
        ld a,1
        ld (vo_class),a
        or a
        ret

double_fire:
        ld a,2
        ld (vo_class),a
        ld b,2
        ld c,2
        call count_class
        ret nc
        ld a,2
        ld (vo_class),a
        ld a,(iy+PT_DBL)
        cp D_BONE
        jr nz,.d2
        ld hl,(vo_x)
        ld de,10
        add hl,de
        ld a,(vo_y)
        ld c,a
        ld de,$FA06             ; dx 6, dy -6
        ld a,ST_DIAG
        jp shot_new
.d2:    cp D_BACK
        jr nz,.d3
        ld hl,(vo_x)
        ld a,(vo_y)
        add a,5
        ld c,a
        ld de,$00F8             ; dx -8
        ld a,ST_DASH
        jp shot_new
.d3:    cp D_SPREAD
        jr nz,.d4
        ld hl,(vo_x)
        ld de,12
        add hl,de
        ld a,(vo_y)
        ld c,a
        ld de,$FC07
        ld a,ST_DIAG
        call shot_new
        ld a,2
        ld (vo_class),a
        ld hl,(vo_x)
        ld de,12
        add hl,de
        ld a,(vo_y)
        add a,8
        ld c,a
        ld de,$0407
        ld a,ST_BLOB
        jp shot_new
.d4:    ld hl,(vo_x)            ; twin: a second dash below
        ld de,12
        add hl,de
        ld a,(vo_y)
        add a,10
        ld c,a
        ld de,$0008
        ld a,ST_DASH
        jp shot_new

missile_fire:
        ld a,3
        ld (vo_class),a
        ld b,3
        ld c,1
        ld a,(iy+PT_MIS)
        cp M_PEGS
        jr nz,.c
        ld c,2
.c:     call count_class
        ret nc
        ld a,3
        ld (vo_class),a
        ld a,(iy+PT_MIS)
        cp M_BANANA
        jr nz,.m2
        ld hl,(vo_x)
        ld de,6
        add hl,de
        ld a,(vo_y)
        add a,10
        ld c,a
        ld de,$0302             ; falls
        ld a,ST_GROUND
        jp shot_new
.m2:    cp M_PEGS
        jr nz,.m3
        ld hl,(vo_x)
        ld de,6
        add hl,de
        ld a,(vo_y)
        add a,10
        ld c,a
        ld de,$0302
        ld a,ST_GROUND
        call shot_new
        ld a,3
        ld (vo_class),a
        ld hl,(vo_x)
        ld de,6
        add hl,de
        ld a,(vo_y)
        ld c,a
        ld de,$FD02             ; rises
        ld a,ST_GROUND
        call shot_new
        ret c
        ld (ix+9),1             ; the ceiling one
        ret
.m3:    cp M_GUMNUT
        jr nz,.m4
        ld hl,(vo_x)
        ld de,10
        add hl,de
        ld a,(vo_y)
        add a,8
        ld c,a
        ld de,$FE04             ; lobbed
        ld a,ST_BOMB
        call shot_new
        ret c
        ld (ix+7),3
        ret
.m4:    ld hl,(vo_x)            ; byte bugs
        ld de,10
        add hl,de
        ld a,(vo_y)
        add a,6
        ld c,a
        ld de,$0005
        ld a,ST_HOMING
        jp shot_new

laser_fire:
        ld (tmp+5),a
        ld a,1
        ld (vo_class),a
        ld b,1
        ld c,1
        call count_class
        ret nc
        ld a,1
        ld (vo_class),a
        ld a,(tmp+5)
        cp L_RING
        jr z,.ring
        cp L_BOOMER
        jr z,.boom
        ld hl,(vo_x)            ; a beam
        ld de,16
        add hl,de
        ld a,(vo_y)
        add a,5
        ld c,a
        ld de,$000C
        ld a,ST_BEAM
        call shot_new
        ret c
        ld a,(iy+PT_BEAM)
        ld (ix+9),a             ; full length
        ret
.ring:  ld hl,(vo_x)
        ld de,12
        add hl,de
        ld a,(vo_y)
        sub 2
        ld c,a
        ld de,$0005
        ld a,ST_RING
        call shot_new
        ret c
        ld (ix+7),2
        ret
.boom:  ld hl,(vo_x)
        ld de,12
        add hl,de
        ld a,(vo_y)
        add a,2
        ld c,a
        ld de,$0009
        ld a,ST_BOOMER
        call shot_new
        ret c
        ld (ix+7),2
        ret

; ---------------------------------------------------------------------
; shots
ST_DASH     equ 1
ST_DIAG     equ 2
ST_BLOB     equ 3
ST_GROUND   equ 4
ST_BOMB     equ 5
ST_HOMING   equ 6
ST_BEAM     equ 7
ST_RING     equ 8
ST_BOOMER   equ 9

shots_update:
        ld ix,shots
        ld b,NSHOT
.l:     push bc
        ld a,(ix+0)
        or a
        call nz,.one
        ld de,SH_SIZE
        add ix,de
        pop bc
        djnz .l
        ret
.one:   inc (ix+6)
        cp ST_GROUND
        jp z,sh_ground
        cp ST_BOMB
        jp z,sh_bomb
        cp ST_HOMING
        jp z,sh_homing
        cp ST_BEAM
        jp z,sh_beam
        cp ST_BOOMER
        jp z,sh_boomer
        ; straight movers
sh_move:
        ld a,(ix+4)
        call sh_addx
        ld a,(ix+3)
        add a,(ix+5)
        ld (ix+3),a
        ; off screen?
sh_bounds:
        ld a,(ix+3)
        cp 24
        jr c,sh_kill
        cp 32+184
        jr nc,sh_kill
        ld l,(ix+1)
        ld h,(ix+2)
        call x_vis
        ret nc
sh_kill:
        ld (ix+0),0
        ret
; add signed A to x
sh_addx:
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld l,(ix+1)
        ld h,(ix+2)
        add hl,de
        ld (ix+1),l
        ld (ix+2),h
        ld a,h
        cp $FF
        jr nz,.ok
        ld (ix+0),0             ; off the left
.ok:    ld a,h
        or a
        ret z
        ld a,l
        cp 64                   ; past 320
        ret c
        ld (ix+0),0
        ret

; ground missile: falls (or rises) to the terrain, then runs along it
sh_ground:
        ld a,(ix+11)
        or a
        jr nz,.run
        ld a,(ix+4)
        call sh_addx
        ld a,(ix+3)
        add a,(ix+5)
        ld (ix+3),a
        call .terr
        ret
.run:   ld a,5
        call sh_addx
        ; follow the terrain height
.terr:  ld l,(ix+1)
        ld h,(ix+2)
        srl h
        rr l
        ld a,l
        ld c,(ix+9)
        bit 0,c
        jr nz,.up
        call floor_at
        add a,32-3
        ld c,a
        ld a,(ix+3)
        cp c
        jr c,.free
        ld (ix+3),c
        ld (ix+11),1
        jp sh_bounds
.up:    call ceil_at
        add a,32
        ld c,a
        ld a,(ix+3)
        cp c
        jr nc,.free
        ld (ix+3),c
        ld (ix+11),1
        jp sh_bounds
.free:  ld a,(ix+11)
        or a
        jp z,sh_bounds
        ld (ix+11),0            ; a drop: fall again
        jp sh_bounds

; gumnut bomb: lobbed, bursts on the floor
sh_bomb:
        ld a,(ix+4)
        call sh_addx
        ld a,(ix+6)
        and 1
        jr nz,.g
        inc (ix+5)              ; gravity
.g:     ld a,(ix+3)
        add a,(ix+5)
        ld (ix+3),a
        ld l,(ix+1)
        ld h,(ix+2)
        srl h
        rr l
        ld a,l
        call floor_at
        add a,32-3
        cp (ix+3)
        jp nc,sh_bounds
bomb_burst:                     ; IX = the bomb
        ld l,(ix+1)
        ld h,(ix+2)
        ld de,-6
        add hl,de
        ld a,(ix+3)
        sub 5
        ld c,a
        call fx_boom
        ld a,SFX_BOOM
        call play_sfx
        ; everything within 24 px takes 3
        ld l,(ix+1)
        ld h,(ix+2)
        ld a,(ix+3)
        ld c,a
        ld (ix+0),0
        ld b,24
        ld e,3
        jp area_damage

; byte bugs: steer at the nearest enemy
sh_homing:
        ld a,(ix+6)
        and 3
        jr nz,.mv
        call nearest_enemy      ; -> C = its middle y (biased) or Z if none
        jr z,.mv
        ld a,(ix+3)
        cp c
        ld a,(ix+5)
        jr z,.mv0
        jr c,.dn
        cp -3
        jr z,.mv
        dec (ix+5)
        jr .mv
.dn:    cp 3
        jr z,.mv
        inc (ix+5)
        jr .mv
.mv0:   ld (ix+5),0
.mv:    jp sh_move

; beam: grows to its length, the head runs on
sh_beam:
        ld a,12
        call sh_addx
        ld a,(ix+11)
        add a,12
        cp (ix+9)
        jr c,.k
        ld a,(ix+9)
.k:     ld (ix+11),a
        ret

; boomerang: slows, turns, comes home
sh_boomer:
        ld a,(ix+6)
        and 1
        jr nz,.m
        ld a,(ix+4)
        cp -9
        jr z,.m
        dec (ix+4)
.m:     ld a,(ix+4)
        call sh_addx
        ld a,(ix+4)
        bit 7,a
        ret z
        ; coming home: drift to the pilot's height, caught at the pilot
        ld a,(py)
        add a,2
        cp (ix+3)
        jr z,.c
        jr c,.u
        inc (ix+3)
        jr .c
.u:     dec (ix+3)
.c:     ld l,(ix+1)
        ld h,(ix+2)
        ld de,(px)
        or a
        sbc hl,de
        ret nc
        ld (ix+0),0
        ret

draw_shots:
        ld ix,shots
        ld b,NSHOT
.l:     push bc
        ld a,(ix+0)
        or a
        call nz,.one
        ld de,SH_SIZE
        add ix,de
        pop bc
        djnz .l
        ret
.one:   ld l,(ix+1)
        ld h,(ix+2)
        ld (spr_x),hl
        ld a,(ix+3)
        sub 24
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld c,a
        ld a,(ix+8)
        or a
        ld a,YELLOW
        jr z,.ink
        ld a,BCYAN
.ink:   ld (spr_ink),a
        ld a,(ix+0)
        cp ST_DIAG
        ld b,K_DIAG
        jr z,.k
        cp ST_DASH
        ld b,K_DASH
        jr z,.k
        cp ST_BEAM
        jr z,.beam
        cp ST_RING
        jr z,.ring
        cp ST_BOOMER
        jr z,.boom
        ld b,K_BLOB
.k:     ld a,b
        jp obj_draw
.beam:  ld a,BMAGENTA
        ld (spr_ink),a
        ld a,(ix+11)
        rrca
        rrca
        rrca
        and $1F
        ret z
        ld b,a
.bl:    push bc
        ld hl,(spr_x)
        ld de,-8
        add hl,de
        ld (spr_x),hl
        bit 7,h
        jr nz,.bx
        ld a,K_BEAM
        call obj_draw
        pop bc
        djnz .bl
        ret
.bx:    pop bc
        ret
.ring:  ld a,(ix+6)
        rrca
        rrca
        and 3
        add a,SF_RING0
        ld c,a
        ld a,WHITE
        ld (spr_ink),a
        ; centre the ring on the shot's line
        ld a,c
        sub SF_RING0
        add a,a
        add a,a
        neg
        ld e,a
        ld a,(spr_y)
        add a,e
        ld (spr_y),a
        ld a,c
        call spr_draw
        ld a,BLK_SPR
        jp map_blk
.boom:  ld a,(ix+6)
        rrca
        and 1
        add a,SF_BOOMER0
        ld c,a
        ld a,BROWN
        ld (spr_ink),a
        ld a,c
        call spr_draw
        ld a,BLK_SPR
        jp map_blk

; ---------------------------------------------------------------------
draw_player:
        ld a,(pdead)
        or a
        ret nz
        ld a,(pinv)
        and 2
        jr z,.vis
        ld a,(bellpow)
        cp BP_GREEN
        jr nz,.opts             ; flashing: every other frame
.vis:   call pilot_iy
        ld hl,(px)
        ld (spr_x),hl
        ld a,(py)
        sub 24
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(iy+PT_INKA)
        ld b,a
        ld a,(bellpow)
        cp BP_GREEN
        jr nz,.ia
        ld a,(ticks)
        and 7
        add a,8
        ld b,a
.ia:    ld a,b
        ld (spr_ink),a
        ld a,(ticks)
        and 4
        rrca
        add a,(iy+PT_FRAME)     ; A0 or A1
        push af
        call spr_draw
        ld a,(iy+PT_INKB)
        ld (spr_ink),a
        ld a,(ptilt)
        cp 1
        jr nz,.t
        ld hl,(spr_y)
        dec hl
        ld (spr_y),hl
.t:     pop af
        inc a
        call spr_draw
        ; the shield
        ld a,(pshield)
        or a
        jr z,.opts
        ld hl,(px)
        ld de,-3
        add hl,de
        ld (spr_x),hl
        ld a,(py)
        sub 26
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,BCYAN
        ld (spr_ink),a
        ld a,(ticks)
        rrca
        and 1
        add a,SF_SHIELD0
        call spr_draw
.opts:  ld a,(poptions)
        or a
        ret z
        call pilot_iy
        ld a,(iy+PT_INKO)
        ld (spr_ink),a
        ld hl,(optx)
        ld de,4
        add hl,de
        ld (spr_x),hl
        ld a,(opty)
        sub 22
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(iy+PT_FRAME)
        add a,4
        call spr_draw
        ld a,(poptions)
        cp 2
        ret c
        ld hl,(optx+2)
        ld de,4
        add hl,de
        ld (spr_x),hl
        ld a,(opty+1)
        sub 22
        ld l,a
        ld h,0
        ld (spr_y),hl
        ld a,(iy+PT_FRAME)
        add a,4
        jp spr_draw

; ---------------------------------------------------------------------
; bell powers (BP_* = the bell's colour index)
BP_GOLD     equ 1
BP_BLUE     equ 2
BP_GREEN    equ 3
BP_RED      equ 4
BP_WHITE    equ 5
powers_tick:
        ld a,(bellpow)
        or a
        ret z
        ld a,(ticks)
        and 1
        ret nz
        ld hl,belltime
        dec (hl)
        ret nz
        xor a
        ld (bellpow),a
        ld a,1
        ld (hud_dirty),a
        ret

; add_score: DE = points / 10 in BCD (D high, E low) -> score
add_score:
        ld a,(demo)
        or a
        ret nz
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
        ld (hud_dirty),a
        ; an extra life every 50,000 (score+1 holds the ten-thousands digit pair)
        ld a,(score+1)
        ld b,a
        ld a,(next_life)
        cp b
        ret z
        ret nc
        add a,$05
        daa
        ld (next_life),a
        ld hl,lives
        ld a,(hl)
        cp 9
        jr nc,.x
        inc (hl)
.x:     ld a,SFX_LIFE
        jp play_sfx

vo_own:     db 0
vo_x:       dw 0
vo_y:       db 0
vo_class:   db 1
