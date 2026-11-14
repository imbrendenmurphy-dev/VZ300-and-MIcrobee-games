; =====================================================================
;  THE GUARDIANS: an armoured eye at the vanishing point inside a
;  turning ring of shield pods. Every shot flies to the centre, so the
;  ring is the whole fight: slip shots through its gaps (or blast a pod
;  out of it) while the eye is open. Closed, the eye shrugs shots off.
; =====================================================================
RINGB       EQU 116         ; the shield ring's depth
COREZ       EQU 72          ; shots this deep reach the core
NPOD        EQU 8

; boss record: pods, pod hp, core hp, ring spin (1/64), eye open, eye
; shut (frames), attack list (4), pod colour, core colour, minion type,
; regrow (frames / 4)
BR_PODS     EQU 0
BR_PODHP    EQU 1
BR_HP       EQU 2
BR_SPIN     EQU 3
BR_OPEN     EQU 4
BR_SHUT     EQU 5
BR_ATK      EQU 6
BR_PCOL     EQU 10
BR_CCOL     EQU 11
BR_MIN      EQU 12
BR_REGROW   EQU 13

A_RADIAL    EQU 0
A_AIMED     EQU 1
A_SPIRAL    EQU 2
A_LAUNCH    EQU 3

boss_start:
        ld a,(boss_id)
        and 3
        ld l,a
        ld h,0
        add hl,hl
        ld de,boss_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (boss_ptr),hl
        push hl
        pop iy
        ld a,(iy+BR_HP)
        ld b,a
        ld a,(lap)
        or a
        ld a,b
        jr z,.h
        add a,a
.h:     ld (core_hp),a
        ld (core_max),a
        ld a,(iy+BR_SPIN)
        call sx4
        ld (ring_spin),de
        ld hl,0
        ld (ring_a),hl
        ld a,$FE
        ld (core_shown),a       ; not shown yet: the first draw places it
        ld a,1
        ld (boss_alive),a
        ld (bossmode),a
        xor a
        ld (eye),a
        ld (core_hurt),a
        ld (spiral_n),a
        ld (atk_i),a
        ld a,(iy+BR_SHUT)
        ld (eye_tim),a
        ld a,90
        ld (batk_tim),a
        ld a,250
        ld (flip_tim),a
        ; the pods grow out of the core
        ld hl,pods
        ld b,NPOD
        ld c,(iy+BR_PODS)
.p:     xor a
        ld (hl),a               ; hp
        ld a,c
        or a
        jr z,.pn
        dec c
        ld a,(iy+BR_PODHP)
        ld (hl),a
.pn:    inc hl
        ld (hl),0               ; regrow timer
        inc hl
        ld (hl),0               ; grow-in depth
        ld de,6
        add hl,de
        djnz .p
        ld a,$FF
        ld (hud_dirty),a
        ret

; IY = the boss record
boss_rec:
        ld iy,(boss_ptr)
        ret

boss_update:
        call boss_rec
        ; the ring turns; now and then it turns back
        ld hl,(ring_a)
        ld de,(ring_spin)
        add hl,de
        ld (ring_a),hl
        ld hl,flip_tim
        dec (hl)
        jr nz,.nf
        call random
        or $80
        ld (hl),a
        ld hl,(ring_spin)
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ld (ring_spin),hl
.nf:    ; the eye
        ld a,(core_hurt)
        or a
        jr z,.nh
        dec a
        ld (core_hurt),a
.nh:    ld hl,eye_tim
        dec (hl)
        jr nz,.ne
        ld a,(eye)
        xor 1
        ld (eye),a
        ld a,(iy+BR_OPEN)
        jr nz,.o
        ld a,(iy+BR_SHUT)
.o:     ld (hl),a
        ld a,(eye)
        or a
        jr z,.ne
        ld hl,sfx_eye
        ld a,3
        call play_sfx
.ne:    ; the pods: where they are, and growing back
        ld a,MP_TAB
        out (P_MEM),a
        ld ix,pods
        ld b,0
.pl:    push bc
        ld a,(iy+BR_PODS)
        cp b
        jr z,.pend
        jr c,.pend
        ld a,(ix+0)
        or a
        jr nz,.alive
        ; regrowing
        ld a,(frameno)
        and 3
        jr nz,.pnx
        inc (ix+1)
        ld a,(ix+1)
        cp (iy+BR_REGROW)
        jr c,.pnx
        ld (ix+1),0
        ld a,(iy+BR_PODHP)
        ld (ix+0),a
        ld (ix+2),0
        jr .pnx
.alive: ld a,(ix+2)             ; growing out to the ring
        cp RINGB
        jr nc,.at
        add a,4
        ld (ix+2),a
.at:    ; angle = ring + b * 256 / pods
        ld a,b
        ld c,(iy+BR_PODS)
        call pod_angle
        ld (ix+3),a
        ld b,(ix+2)
        call polar
        ld (ix+4),l
        ld (ix+5),h
        ld (ix+6),c
.pnx:   pop bc
        push bc
        ld de,8
        add ix,de
        pop bc
        inc b
        jr .pl
.pend:  pop bc
        ; shots against the ring and the core
        ld ix,SHOTS
        ld b,NSHOT
.sl:    push bc
        ld a,(ix+S_ST)
        or a
        call nz,boss_shot
        ld de,8
        add ix,de
        pop bc
        djnz .sl
        ; attacks
        ld a,(p_state)
        or a
        ret nz
        ld a,(spiral_n)
        or a
        jr z,.ns
        dec a
        ld (spiral_n),a
        and 3
        jr nz,.ns
        ld a,(spiral_a)
        add a,23
        ld (spiral_a),a
        ld b,COREZ
        call bullet_new
.ns:    ld hl,batk_tim
        dec (hl)
        ret nz
        call random
        and 31
        add a,70
        ld (hl),a
        ld a,(lap)
        or a
        jr z,.nl
        ld a,(hl)
        sub 25
        ld (hl),a
.nl:    ld a,(atk_i)
        inc a
        and 3
        ld (atk_i),a
        ld e,a
        ld d,0
        push iy
        pop hl
        add hl,de
        ld de,BR_ATK
        add hl,de
        ld a,(hl)
        or a
        jr z,.radial
        dec a
        jr z,.aimed
        dec a
        jr z,.spiral
        ; launch two raiders from the core
        ld a,(nenemy)
        cp 6
        ret nc
        ld a,(p_a)
        add a,40
        call raider
        ld a,(p_a)
        sub 40
        jp raider
.radial:
        call random
        ld c,a
        ld b,8
.r:     push bc
        ld a,c
        ld b,COREZ
        call bullet_new
        pop bc
        ld a,c
        add a,32
        ld c,a
        djnz .r
        ret
.aimed: ld a,(p_a)
        ld b,COREZ
        call bullet_new
        ld a,(p_a)
        add a,12
        ld b,COREZ
        call bullet_new
        ld a,(p_a)
        sub 12
        ld b,COREZ
        jp bullet_new
.spiral:
        ld a,48
        ld (spiral_n),a
        ld a,(p_a)
        add a,128
        ld (spiral_a),a
        ret

; A = pod index, C = pods -> A = its angle
pod_angle:
        push de
        push hl
        ld e,a
        ld a,c
        ld hl,podstep-1
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld d,(hl)               ; 256 / pods
        xor a
        ld b,e
        inc b
.m:     dec b
        jr z,.d
        add a,d
        jr .m
.d:     ld hl,ring_a+1
        add a,(hl)
        pop hl
        pop de
        ret
podstep:
        db 0,128,85,64,51,43,36,32

; A = angle: a raider from the core that rushes the orbit
raider: push af
        call enemy_free
        pop bc
        ret c
        ld hl,nenemy
        inc (hl)
        ld (ix+E_ST),ST_PATH
        ld (ix+E_A),b
        ld (ix+E_AF),0
        ld (ix+E_R),COREZ
        ld (ix+E_RF),0
        ld (ix+E_TIM),0
        ld a,(iy+BR_MIN)
        ld (ix+E_TYPE),a
        ld a,(iy+BR_PCOL)
        ld (ix+E_COL),a
        ld (ix+E_HP),1
        ld (ix+E_GRP),$FF
        ld (ix+E_FLG),0
        ld (ix+E_ANIM),0
        ld (ix+E_WARN),0
        ld (ix+E_HIT),0
        ld hl,path_raider
        ld (ix+E_PL),l
        ld (ix+E_PH),h
        ld a,b
        ld b,COREZ
        call polar
        ld (ix+E_XL),l
        ld (ix+E_XH),h
        ld (ix+E_Y),c
        ld (ix+E_SZ),2
        ld hl,sfx_warn
        ld a,3
        jp play_sfx

; shot IX against the ring, then the core
boss_shot:
        ld a,(ix+S_R)
        cp RINGB+6
        jr nc,.core
        ld a,(ix+S_OLD)
        cp RINGB-6
        jr c,.core
        ; crossing the ring this frame
        ld iy,pods
        ld a,(boss_ptr)
        ld b,NPOD
.p:     ld a,(iy+0)
        or a
        jr z,.pn
        ld a,(iy+2)
        cp RINGB-8
        jr c,.pn
        ld a,(ix+S_A)
        sub (iy+3)
        call absa
        cp 9
        jr nc,.pn
        ; a pod takes it
        ld (ix+S_ST),0
        dec (iy+0)
        jr z,.pod
        ld hl,sfx_tink
        ld a,2
        call play_sfx
        jp boss_rec
.pod:   ld l,(iy+4)
        ld h,(iy+5)
        ld b,(iy+6)
        call boss_rec
        ld c,(iy+BR_PCOL)
        ld a,4
        call fx_new
        ld de,$0030
        call add_score
        ld hl,sfx_boom
        ld a,4
        call play_sfx
        jp boss_rec
.pn:    ld de,8
        add iy,de
        djnz .p
        call boss_rec
.core:  ld a,(ix+S_R)
        cp COREZ
        ret nc
        ld (ix+S_ST),0
        ld a,(eye)
        or a
        jr nz,.hit
        ld hl,sfx_tink
        ld a,2
        jp play_sfx
.hit:   ld a,4
        ld (core_hurt),a
        ld a,(hud_dirty)
        or 2
        ld (hud_dirty),a
        ld de,$0010
        call add_score
        ld hl,core_hp
        dec (hl)
        jr z,.dead
        ld hl,sfx_core
        ld a,4
        jp play_sfx
.dead:  xor a
        ld (boss_alive),a
        ld (spiral_n),a
        ; 10 000 for the first Guardian, 5 000 more for each after
        ld a,(boss_id)
        and 3
        add a,a
        ld e,a
        ld d,0
        ld hl,boss_pts
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        call add_score
        ld a,WHITE
        call flash
        ld hl,sfx_die
        ld a,9
        jp play_sfx
boss_pts:
        dw $1000,$1500,$2000,$3000

; the Guardian comes apart (PH_BOSSEND)
boss_dying:
        ld a,(ph_tim)
        cp 20
        jr nc,.go
        xor a
        ld (bossmode),a
        ld a,$FF
        ld (hud_dirty),a        ; the sector's name back in place of the bar
        jp core_hide
.go:    and 3
        ret nz
        call random
        and 63
        sub 32
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        ld hl,CX
        add hl,de
        push hl
        call random
        and 31
        add a,CY-16
        ld b,a
        call random
        and 7
        ld c,a
        pop hl
        ld a,4
        call fx_new
        ld a,(ph_tim)
        and 15
        ret nz
        ld a,YELLOW
        call flash
        ld hl,sfx_boom
        ld a,5
        jp play_sfx

; draw the core and its pods (BLK_ENM mapped)
; The core never moves, so it is not a sprite: its three faces are 60
; glyphs in PCG bank 12, placed as fixed cells through the text queue,
; and re-queued only when the face or its colour changes. Sprites that
; cross it (its own bullets leaving, shots arriving) pass behind it.
boss_draw:
        call boss_rec
        ld a,(boss_alive)
        or a
        jr nz,.al
        ld a,(ph_tim)
        cp 20
        jr c,.hid
        and 2
        jr nz,.al
.hid:   ld a,$FF                ; dying: it flickers
        jr .sig
.al:    ld a,(core_hurt)
        or a
        ld b,2
        ld a,WHITE
        jr nz,.c
        ld a,(eye)
        ld b,a
        ld a,(iy+BR_CCOL)
.c:     and 15
        ld c,a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        or c                    ; face << 4 | colour
.sig:   ld hl,core_shown
        cp (hl)
        call nz,core_put
        ld a,(boss_alive)
        or a
        ret z
        ; the pods
        ld ix,pods
        ld b,0
.p:     push bc
        ld a,(iy+BR_PODS)
        cp b
        jr z,.e
        jr c,.e
        ld a,(ix+0)
        or a
        jr z,.n
        ld a,(iy+BR_PCOL)
        and 15
        call setcol
        ld a,(frameno)
        rrca
        rrca
        and 1
        add a,7*2               ; the pod, type 7
        ld c,a
        add a,a
        add a,c
        add a,a
        ld c,a
        ld a,(ix+2)
        cp RINGB
        ld a,3                  ; 10 lines near (fewer cells than 13)
        jr nc,.sz
        ld a,2
.sz:    add a,c
        ld l,a
        ld h,0
        add hl,hl
        ld de,rec_enm
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld e,(ix+4)
        ld d,(ix+5)
        ld c,(ix+6)
        call draw_spr
.n:     ld de,8
        add ix,de
        pop bc
        inc b
        jr .p
.e:     pop bc
        ret

; A = face << 4 | colour, or FFh to take the core away
CORE_C  EQU 18                  ; its 4 x 4 cells start at column 18, row 11
CORE_R  EQU 11
core_put:
        ld (core_shown),a
        cp $FF
        jr z,core_clear
        ld b,a
        and 15
        ld hl,colmap
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld c,(hl)               ; the colour, through the monitor's map
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,a
        add a,a
        add a,a
        add a,a
        add a,$80               ; the face's first glyph: 80h + face * 16
        ld hl,CORE_R*40+CORE_C
        ld e,4
.r:     ld d,4
.c:     ld b,BK_CORE
        call tq_put
        inc a
        inc hl
        dec d
        jr nz,.c
        push de
        ld de,40-4
        add hl,de
        pop de
        dec e
        jr nz,.r
        ret
core_clear:
        ld hl,CORE_R*40+CORE_C
        ld e,4
.r:     ld b,4
        call clear_q
        push de
        ld de,40-4
        add hl,de
        pop de
        dec e
        jr nz,.r
        ret
; take the core away if it is shown
core_hide:
        ld a,(core_shown)
        cp $FF
        ret z
        ld a,$FF
        jp core_put

; the Guardian's health instead of the sector's name
boss_bar:
        ld hl,22*40+32          ; bottom right, where the warps were
        ld de,t_core
        ld c,YELLOW
        call print_q
        ; segments lit = hp * 8 / max
        ld a,(core_hp)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; hp * 8
        ld a,(core_max)
        ld c,a
        call sdiv
        ld e,l
        ld a,(core_hp)
        or a
        jr z,.z
        ld a,e
        or a
        jr nz,.z
        inc e
.z:     ld hl,23*40+32
        ld b,8
.l:     ld a,e
        or a
        ld a,$80+67
        ld c,BRED
        jr nz,.on
        ld c,DGREY
.on:    push bc
        ld b,BK_FONT
        call tq_put
        pop bc
        ld a,e
        or a
        jr z,.n
        dec e
.n:     inc hl
        djnz .l
        ret
