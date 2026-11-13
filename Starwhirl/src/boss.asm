; =====================================================================
;  STARWHIRL - bosses, the bonus round, the ending
;
;  A boss sits in the eye of the storm, ringed by armour pods.
;   phase 1  pods turn round the core; one at a time, a pod lights up
;            and then fires at you.  The core's eye opens now and then.
;   phase 2  (pods gone, or the core a third down) the core charges
;            (rising whine, flashing) and throws a ring of 8 plasma
;            bolts, a little further round each time; every other ring
;            it also launches a pair of hornets.
;   phase 3  (core two thirds down) it alternates the ring with an aimed
;            three-bolt burst (two-tone alarm), and turns faster.
;  The core only takes damage while its eye is open; shots off a closed
;  eye glance away with a "tink".
; =====================================================================
BS_ENTER equ 1
BS_FIGHT equ 2
BS_DYING equ 3
BS_DONE  equ 4

do_boss:
        call    clear_objs
        call    stop_music
        ld      hl,s_warning
        call    banner_msg
        ld      a,(sector)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,boss_names
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      (banner2),hl
        ld      a,70
        ld      (banner_t),a
        ld      a,SFX_ALARM
        call    play_sfx
        ld      b,60
.w:     push    bc
        call    gf
        pop     bc
        djnz    .w
        call    boss_init
        ld      hl,mus_boss
        ld      a,1
        call    start_music
.l:     call    gf
        ld      a,(bstate)
        cp      BS_DONE
        jr      nz,.l
        xor     a
        ld      (boss_on),a
        ld      (bhp),a
        ; 5,000 a sector number, and 10,000 more for a sector without a scratch
        ld      a,(sector)
        inc     a
        ld      b,a
.aw:    push    bc
        ld      de,$5000
        call    add_score
        pop     bc
        djnz    .aw
        ld      hl,s_secclear
        call    banner_msg
        ld      a,(hits_taken)
        or      a
        jr      nz,.nh
        ld      de,$5000
        call    add_score
        ld      de,$5000
        call    add_score
        ld      hl,s_nodamage
        ld      (banner2),hl
.nh:    ld      a,80
        ld      (banner_t),a
        ld      hl,mus_bossdown
        xor     a
        call    start_music
        ; the extra pip a boss is worth
        ld      a,(pips_max)
        ld      b,a
        ld      a,(pips)
        cp      b
        jr      nc,.p
        inc     a
        ld      (pips),a
.p:     ld      b,80
.c:     push    bc
        call    gf
        pop     bc
        djnz    .c
        ret

boss_init:
        ld      a,(sector)
        ld      e,a
        ld      d,0
        ld      hl,bdes_tab
        add     hl,de
        ld      a,(hl)
        ld      (bdesign),a
        ld      hl,bpod_tab
        add     hl,de
        ld      a,(hl)
        ld      (bnpod),a
        ld      hl,bhp_tab
        add     hl,de
        ld      b,(hl)
        ld      a,(loop)
        add     a,a
        add     a,a
        add     a,b
        cp      61
        jr      c,.h
        ld      a,60
.h:     ld      (bhp),a
        ld      (bhp_max),a
        ld      a,BS_ENTER
        ld      (bstate),a
        ld      a,60
        ld      (bt),a
        ld      (beye_t),a
        ld      a,70
        ld      (bat),a
        xor     a
        ld      (brot),a
        ld      (beye),a
        ld      (bcharge),a
        ld      (bvolley),a
        ld      (bhit),a
        ld      (bvangle),a
        ld      (bpods),a
        inc     a
        ld      (boss_on),a
        ; pod spacing = 256 / pods
        ld      a,(bnpod)
        ld      c,a
        ld      b,0
        ld      hl,256
        ld      d,0
.dv:    or      a
        sbc     hl,bc
        jr      c,.dd
        inc     d
        jr      .dv
.dd:    ld      a,d
        ld      (bpodsp),a
        xor     a
        ld      (tmp1),a
.pod:   call    alloc_enemy
        ret     c
        ld      (ix+E_TYPE),T_ARMOR
        ld      (ix+E_ST),S_POD
        ld      a,(level)
        srl     a
        srl     a
        add     a,3
        ld      (ix+E_HP),a
        ld      a,(tmp1)
        ld      (ix+E_K),a
        inc     a
        ld      (tmp1),a
        ld      hl,bnpod
        cp      (hl)
        jr      c,.pod
        ret

; st_pod: an armour pod turning round the core
st_pod:
        ld      a,(ix+E_R)
        cp      16
        jr      nc,.r
        inc     (ix+E_R)
.r:     ld      a,(bpodsp)
        ld      c,a
        ld      b,(ix+E_K)
        xor     a
        inc     b
        dec     b
        jr      z,.a1
.a0:    add     a,c
        djnz    .a0
.a1:    ld      hl,brot
        add     a,(hl)
        ld      (ix+E_A),a
        ld      a,(ix+E_T)
        or      a
        jp      z,e_draw
        dec     (ix+E_T)
        jr      nz,.fl
        ld      a,(ix+E_A)
        ld      c,(ix+E_R)
        ld      b,1
        call    fire_shot
        ld      a,SFX_EFIRE
        call    play_sfx
        jp      e_draw
.fl:    ld      a,(gtick)           ; lights up before it fires
        and     2
        ret     nz
        jp      e_draw

; ---------------------------------------------------------------------
; boss_frame: once a game frame while a boss is on
; ---------------------------------------------------------------------
boss_frame:
        ld      a,(bhit)
        or      a
        jr      z,.nh
        dec     a
        ld      (bhit),a
.nh:    ld      a,(bstate)
        cp      BS_ENTER
        jr      z,.enter
        cp      BS_FIGHT
        jr      z,.fight
        cp      BS_DYING
        jp      z,.dying
        ret
.enter: ld      hl,bt
        dec     (hl)
        jr      nz,.ed
        ld      a,BS_FIGHT
        ld      (bstate),a
.ed:    ld      a,(bt)
        cp      40
        ld      a,F_BSEED0
        jr      nc,.df
        ld      a,(bt)
        cp      20
        ld      a,F_BSEED1
        jr      nc,.df
        call    core_frame
        inc     a                   ; closed
.df:    ld      bc,64*256+32
        jp      draw_c

.fight: call    boss_phase
        ld      (tmp1),a
        ; turn
        ld      b,1
        cp      3
        jr      nz,.t1
        inc     b
.t1:    ld      a,(brot)
        add     a,b
        ld      (brot),a
        ; the eye opens and shuts
        ld      hl,beye_t
        dec     (hl)
        jr      nz,.ne
        ld      a,(beye)
        xor     1
        ld      (beye),a
        ld      a,(tmp1)
        add     a,a
        ld      b,a
        add     a,a
        add     a,a
        add     a,b                 ; phase * 10
        ld      b,a
        ld      a,(beye)
        or      a
        jr      z,.shut
        ld      a,40
        add     a,b                 ; open 50 / 60 / 70
        jr      .se
.shut:  ld      a,90
        sub     b
        sub     b                   ; shut 70 / 50 / 30
.se:    ld      (beye_t),a
.ne:    ; a charged attack going off?
        ld      a,(bcharge)
        or      a
        jr      z,.nc
        dec     a
        ld      (bcharge),a
        call    z,boss_fire
.nc:    ld      hl,bat
        dec     (hl)
        jp      nz,.draw
        ld      a,(palive)
        or      a
        jr      nz,.go
        ld      (hl),20             ; hold fire while you're down
        jp      .draw
.go:    ld      a,(tmp1)
        cp      1
        jr      nz,.p2
        ; phase 1: the pod nearest your angle lights up, then fires
        call    pod_near
        ld      a,(level)
        add     a,a
        add     a,a
        ld      b,a
        ld      a,58
        sub     b
        ld      (bat),a
        jr      .draw
.p2:    cp      2
        jr      nz,.p3
.volley:
        ld      a,1
        ld      (bkind),a
        ld      a,24
        ld      (bcharge),a
        ld      a,SFX_CHARGE
        call    play_sfx
        ld      a,(level)
        add     a,a
        ld      b,a
        ld      a,84
        sub     b
        ld      (bat),a
        ld      hl,bvolley
        inc     (hl)
        ld      a,(hl)
        and     1
        call    z,boss_hornets
        jr      .draw
.p3:    ld      hl,bvolley
        inc     (hl)
        ld      a,(hl)
        and     1
        jr      z,.volley
        ld      a,2
        ld      (bkind),a
        ld      a,15
        ld      (bcharge),a
        ld      a,SFX_BURST
        call    play_sfx
        ld      a,46
        ld      (bat),a
.draw:  ld      a,(bcharge)         ; winding up: a ring of sparks closes in
        or      a
        call    nz,charge_ring
        call    core_frame
        ld      b,a
        ld      a,(beye)
        or      a
        ld      a,b
        jr      nz,.op
        inc     a
.op:    ld      b,a
        ld      a,(bcharge)
        or      a
        jr      z,.fc
        ld      a,(gtick)           ; charging: flickers
        and     2
        jr      z,.fc
        ld      a,b
        xor     1
        ld      b,a
.fc:    ld      a,b
        ld      bc,64*256+32
        call    draw_c
        ld      a,(bhit)
        or      a
        ret     z
        ld      a,F_EXA
        ld      bc,64*256+32
        jp      draw_c

.dying: ld      hl,bt
        dec     (hl)
        jr      nz,.dy
        ld      a,BS_DONE
        ld      (bstate),a
        ret
.dy:    ld      a,(bt)
        and     3
        jr      nz,.dd
        ld      a,20
        call    rnd_n
        add     a,54
        ld      b,a
        ld      a,12
        call    rnd_n
        add     a,26
        ld      c,a
        ld      a,7
        call    burst
        ld      a,(bt)
        and     7
        jr      nz,.dd
        ld      a,SFX_BIGKILL
        call    play_sfx
.dd:    ld      a,(bt)
        cp      24
        ret     c
        and     2
        ret     z
        call    core_frame
        ld      bc,64*256+32
        jp      draw_c

; charge_ring: 12 sparks at radius 8 + bcharge, turning
charge_ring:
        add     a,8
        cp      40
        jr      c,.r
        ld      a,40
.r:     ld      (tmp1),a
        ld      a,(brot)
        add     a,a
        add     a,a
        ld      (tmp2),a
        ld      b,12
.l:     push    bc
        ld      a,(tmp1)
        ld      c,a
        ld      a,(tmp2)
        call    proj
        ld      a,(gtick)
        and     1
        add     a,a
        inc     a                   ; yellow / red flicker
        call    plot_c
        ld      a,(tmp2)
        add     a,21
        ld      (tmp2),a
        pop     bc
        djnz    .l
        ret

; core_frame -> A = this boss's eye-open frame (+1 = shut)
core_frame:
        ld      a,(bdesign)
        add     a,a
        add     a,F_BWARDEN_O
        ret

; boss_phase -> A = 1, 2 or 3
boss_phase:
        ld      a,(bhp)
        ld      b,a
        add     a,a
        add     a,b
        ld      c,a                 ; 3 x strength
        ld      a,(bhp_max)
        cp      c
        jr      z,.n3
        jr      nc,.ph3
.n3:    ld      a,(bpods)
        or      a
        jr      z,.ph2
        ld      a,(bhp_max)
        add     a,a
        cp      c
        jr      z,.ph1
        jr      nc,.ph2
.ph1:   ld      a,1
        ret
.ph2:   ld      a,2
        ret
.ph3:   ld      a,3
        ret

; pod_near: light up the pod closest to your angle
pod_near:
        ld      ix,ENEMY
        ld      b,MAXE
        ld      c,255               ; best distance
        ld      iy,0
.l:     ld      a,(ix+E_ST)
        cp      S_POD
        jr      nz,.n
        ld      a,(ix+E_TYPE)
        cp      T_ARMOR
        jr      nz,.n
        ld      a,(pa+1)
        sub     (ix+E_A)
        jp      p,.p
        neg
.p:     cp      c
        jr      nc,.n
        ld      c,a
        push    ix
        pop     iy
.n:     ld      de,E_SIZE
        add     ix,de
        djnz    .l
        push    iy
        pop     hl
        ld      a,h
        or      l
        ret     z
        ld      (iy+E_T),16
        ret

; boss_fire: the charged attack goes off
boss_fire:
        ld      a,(bkind)
        cp      2
        jr      z,.burst
        ; a ring of 8, turned a little further each time
        ld      a,(bvangle)
        add     a,12
        ld      (bvangle),a
        ld      b,8
.v:     push    bc
        ld      c,8
        ld      b,1
        call    fire_shot
        pop     bc
        ld      a,(bvangle)
        ld      e,a
        ld      a,8
        sub     b
        inc     a
        rrca
        rrca
        rrca                        ; k * 32
        add     a,e
        djnz    .v2
        jr      .vs
.v2:    jr      .v
.vs:    ld      a,SFX_HIT
        jp      play_sfx
.burst: ld      a,(pa+1)
        ld      c,8
        ld      b,1
        call    fire_shot
        ld      a,(pa+1)
        add     a,12
        ld      c,8
        ld      b,1
        call    fire_shot
        ld      a,(pa+1)
        sub     12
        ld      c,8
        ld      b,1
        call    fire_shot
        ld      a,SFX_HIT
        jp      play_sfx

; boss_hornets: two hornets burst out of the eye
boss_hornets:
        ld      a,(alive_n)
        cp      16
        ret     nc
        ld      b,2
.l:     push    bc
        call    alloc_enemy
        pop     bc
        ret     c
        ld      (ix+E_TYPE),T_HORNET
        ld      (ix+E_ST),S_DIVE
        ld      (ix+E_HP),1
        ld      (ix+E_R),6
        ld      (ix+E_V),8
        ld      (ix+E_K),b
        call    rnd
        ld      (ix+E_A),a
        djnz    .l
        ret

; boss_shot: IY = player shot -> carry if it struck the core
boss_shot:
        ld      a,(bstate)
        cp      BS_FIGHT
        jr      nz,.no
        ld      a,(iy+0)
        cp      13
        jr      nc,.no
        ld      a,(iy+2)
        sub     64
        jp      p,.x
        neg
.x:     cp      7
        jr      nc,.no
        ld      a,(iy+3)
        sub     32
        jp      p,.y
        neg
.y:     cp      5
        jr      nc,.no
        ld      a,(beye)
        or      a
        jr      z,.tink
        ld      a,3
        ld      (bhit),a
        ld      de,$0050
        call    add_score
        ld      hl,bhp
        dec     (hl)
        jr      z,.die
        ld      a,SFX_HIT
        call    play_sfx
        scf
        ret
.tink:  ld      a,SFX_DEFLECT
        call    play_sfx
        scf
        ret
.no:    or      a
        ret
.die:   ld      a,BS_DYING
        ld      (bstate),a
        ld      a,72
        ld      (bt),a
        ld      a,10
        ld      (flash_t),a
        ld      a,SFX_BIGKILL
        call    play_sfx
        call    clear_eshots
        ; everything still flying goes up with it
        push    iy
        ld      ix,ENEMY
        ld      b,MAXE
.k:     push    bc
        ld      a,(ix+E_TYPE)
        or      a
        jr      z,.kn
        ld      a,(ix+E_ST)
        cp      S_BOOM
        jr      z,.kn
        ld      a,(ix+E_ST)
        cp      S_WAIT
        jr      z,.kz
        ld      b,(ix+E_X)
        ld      c,(ix+E_Y)
        ld      a,6
        call    burst
        ld      (ix+E_ST),S_BOOM
        ld      (ix+E_T),8
        jr      .kn
.kz:    ld      (ix+E_TYPE),0
.kn:    ld      de,E_SIZE
        add     ix,de
        pop     bc
        djnz    .k
        pop     iy
        ld      bc,64*256+32
        ld      a,20
        call    burst
        scf
        ret

; ---------------------------------------------------------------------
; the bonus round: STARFALL - 40 harmless stars; hit them all
; ---------------------------------------------------------------------
do_bonus:
        call    clear_objs
        ld      a,1
        ld      (bonus_rnd),a
        xor     a
        ld      (bon_hits),a
        ld      hl,s_bonusrnd
        call    banner_msg
        ld      hl,s_shootall
        ld      (banner2),hl
        ld      a,70
        ld      (banner_t),a
        ld      hl,mus_bonus
        ld      a,1
        call    start_music
        ld      a,(sector)
        and     1
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,bonustab
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        call    start_spawn
        ld      a,50
        ld      (spawn_wait),a
.l:     call    wave_tick
        call    gf
        ld      a,(spawn_done)
        or      a
        jr      z,.l
        ld      a,(alive_n)
        or      a
        jr      nz,.l
        ; results
        call    stop_music
        ld      hl,s_hits
        ld      de,txtbuf
        call    strcpy
        push    de
        ld      a,(bon_hits)
        call    byte_to_str
        pop     de
        call    strcpy
        ld      hl,txtbuf
        call    banner_msg
        ld      hl,s_each
        ld      (banner2),hl
        ld      a,(bon_hits)
        cp      BONUS_COUNT
        jr      nz,.np
        ld      hl,s_perfect
        ld      (banner2),hl
        ld      de,$5000
        call    add_score
        ld      de,$5000
        call    add_score
        ld      hl,mus_hiscore
        xor     a
        call    start_music
.np:    ld      a,80
        ld      (banner_t),a
        ld      b,80
.r:     push    bc
        call    gf
        pop     bc
        djnz    .r
        xor     a
        ld      (bonus_rnd),a
        ret

; ---------------------------------------------------------------------
; the ending: the storm stills - for a while
; ---------------------------------------------------------------------
do_ending:
        call    clear_objs
        ld      a,1
        ld      (warp),a
        ld      hl,mus_ending
        xor     a
        call    start_music
        ld      hl,s_end1
        call    banner_msg
        ld      hl,s_end2
        ld      (banner2),hl
        ld      a,250
        ld      (banner_t),a
        ld      b,10
.aw:    push    bc
        ld      de,$5000
        call    add_score
        pop     bc
        djnz    .aw
        ld      b,0
.l:     push    bc
        ld      a,b
        cp      140
        jr      nz,.m
        ld      hl,s_end3
        call    banner_msg
        ld      hl,s_end4
        ld      (banner2),hl
        ld      a,110
        ld      (banner_t),a
        xor     a
        ld      (warp),a
.m:     call    gf
        pop     bc
        djnz    .l
        ret
