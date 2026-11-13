; =====================================================================
;  STARWHIRL - the game
;  Everything moves in polar coordinates around the eye of the storm:
;  angle 0..255 (0 = right, 64 = down), radius 0..63 (56 = the orbit).
;  proj turns (angle, radius) into a screen point each frame.
; =====================================================================
RIM     equ 56
MAXE    equ 28
E_SIZE  equ 16
NPS     equ 8
NES     equ 16
NPART   equ 40
NSTAR   equ 20
NFLT    equ 4
NGRP    equ 8
NSLOT   equ 24

; enemy record
E_TYPE  equ 0
E_ST    equ 1
E_A     equ 2
E_R     equ 3
E_RF    equ 4
E_PL    equ 5
E_PH    equ 6
E_T     equ 7
E_FL    equ 8
E_GRP   equ 9
E_HP    equ 10
E_X     equ 11
E_Y     equ 12
E_SLOT  equ 13
E_V     equ 14
E_K     equ 15

; states
S_WAIT  equ 1
S_PATH  equ 2
S_SEEK  equ 3
S_HOLD  equ 4
S_WARN  equ 5
S_DIVE  equ 6
S_SWEEP equ 7
S_RET   equ 8
S_EXIT  equ 9
S_BOOM  equ 10
S_MINE  equ 11
S_POD   equ 12

; types
T_GLINT equ 1
T_MOTH  equ 2
T_SPIN  equ 3
T_HORNET equ 4
T_MINE  equ 5
T_POD   equ 6
T_SPARK equ 7
T_ARMOR equ 8

; flags
F_MIR   equ 1
F_SWDIR equ 2
F_FIRED equ 4
F_ALARM equ 8
F_EXITP equ 16                  ; leaving for good (pod, bonus star)

; ---------------------------------------------------------------------
; run_game: A = first sector (0..4).  Returns when the game is over, the
;   demo ends or the player quits (game_sp unwinds from anywhere).
; ---------------------------------------------------------------------
run_game:
        ld      (start_sec),a
        ld      (game_sp),sp
        call    game_init
.sec:   call    set_level
        call    sector_intro
        xor     a
        ld      (wave),a
.w:     call    do_wave
        ld      hl,wave
        inc     (hl)
        ld      a,(hl)
        cp      4
        jr      c,.w
        call    do_boss
        call    do_bonus
        ld      a,(sector)
        inc     a
        cp      5
        jr      c,.ns
        call    do_ending
        ld      hl,loop
        inc     (hl)
        xor     a
.ns:    ld      (sector),a
        ld      (cont_sec),a
        jr      .sec

game_exit:
        ld      sp,(game_sp)
        call    stop_music
        xor     a
        ld      (boss_on),a
        ld      (warp),a
        ret

game_init:
        ld      hl,score
        xor     a
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        ld      (loop),a
        ld      (gover),a
        ld      (ptwin),a
        ld      (boss_on),a
        ld      (bonus_rnd),a
        ld      (banner_t),a
        ld      (hits_taken),a
        ld      a,2
        ld      (full_clr),a
        ld      hl,next_life
        ld      (hl),$03            ; first extra ship at 30,000
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        ld      a,3
        ld      (lives),a
        ld      a,(skill)
        ld      e,a
        ld      d,0
        ld      hl,skill_pips
        add     hl,de
        ld      a,(hl)
        ld      (pips_max),a
        ld      (pips),a
        ld      a,(start_sec)
        ld      (sector),a
        ld      (cont_sec),a
        call    clear_objs
        ld      hl,$4000            ; the ship starts at the bottom
        ld      (pa),hl
        xor     a
        ld      (pspd),a
        ld      (pinv),a
        inc     a
        ld      (palive),a
        ret

skill_pips: db 5,3,1

; clear_objs: every enemy, shot, particle, slot and float gone
clear_objs:
        ld      hl,ENEMY
        ld      de,ENEMY+1
        ld      bc,MAXE*E_SIZE+NPS*4+NES*6+NPART*8-1
        ld      (hl),0
        ldir
        ld      hl,FLOATS
        ld      de,FLOATS+1
        ld      bc,NFLT*6+NGRP*4+NSLOT-1
        ld      (hl),0
        ldir
        xor     a
        ld      (alive_n),a
        ld      (divers),a
        ld      (spawn_done),a
        ret

; set_level: copy this level's row of the difficulty table
set_level:
        ld      a,(loop)
        ld      b,a
        add     a,a
        add     a,b
        ld      b,a
        ld      a,(sector)
        add     a,b
        ld      b,a
        ld      a,(skill)
        or      a
        jr      nz,.n1
        ld      a,b                 ; CADET: one level gentler
        or      a
        jr      z,.ok
        dec     a
        jr      .ok
.n1:    cp      2
        ld      a,b
        jr      nz,.ok
        add     a,2                 ; ACE: two levels harder
.ok:    cp      12
        jr      c,.ok2
        ld      a,11
.ok2:   ld      (level),a
        add     a,a
        add     a,a
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,difftab
        add     hl,de
        ld      de,d_dive
        ld      bc,8
        ldir
        ; this sector's palette
        ld      a,(sector)
        ld      e,a
        ld      d,0
        ld      hl,sec_css
        add     hl,de
        ld      a,(hl)
        or      MODE1
        ld      (base_vm),a
        ld      (next_vmode),a
        ret

; ---------------------------------------------------------------------
; gf: one game frame - update and draw everything, show it, read keys
; ---------------------------------------------------------------------
gf:
        ld      a,(full_clr)        ; the first two frames clear everything
        or      a
        jr      z,.cp
        dec     a
        ld      (full_clr),a
        call    clear_all
        ld      a,2
        ld      (hud_dirty),a
        jr      .hc
.cp:    call    clear_play
.hc:    call    hud_check
        ld      a,(boss_on)
        or      a
        call    z,draw_vortex
        call    stars
        call    enemies
        ld      a,(boss_on)
        or      a
        call    nz,boss_frame
        call    pshots
        call    eshots
        call    particles
        call    player
        call    hud_bar
        call    floats
        call    banner
        ld      a,(demo)
        or      a
        call    nz,demo_ai
        ; screen flash (a quick palette swap) for the big bangs
        ld      a,(base_vm)
        ld      b,a
        ld      a,(flash_t)
        or      a
        jr      z,.nf
        dec     a
        ld      (flash_t),a
        and     2
        jr      z,.nf
        ld      a,b
        xor     CSS1
        ld      b,a
.nf:    ld      a,b
        ld      (next_vmode),a
        call    present
        ; game over countdown
        ld      a,(gover)
        or      a
        jr      z,.ng
        ld      hl,gover_t
        dec     (hl)
        jp      z,game_exit
.ng:    ld      a,(demo)
        or      a
        jr      z,.nd
        ld      a,(mnunew)
        ld      b,a
        ld      a,(keysnew)
        or      b
        jr      nz,.dq
        ld      hl,(demo_t)
        dec     hl
        ld      (demo_t),hl
        ld      a,h
        or      l
        ret     nz
.dq:    ld      a,1
        ld      (demo_quit),a
        jp      game_exit
.nd:    ld      a,(keysnew)
        bit     0,a
        call    nz,sound_cycle
        ld      a,(keysnew)
        bit     1,a
        call    nz,pause
        ret

; sound_cycle: M = music + effects -> effects only -> silent
sound_cycle:
        ld      a,(snd_mode)
        inc     a
        cp      3
        jr      c,.s
        xor     a
.s:     ld      (snd_mode),a
        ld      e,a
        ld      d,0
        ld      hl,snd_names
        add     hl,de
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        call    banner_msg
        ld      a,SFX_SELECT
        jp      play_sfx

; pause: freeze on the last frame; RETURN/P goes on, Q quits, M = sound
pause:
        ld      a,SFX_SELECT
        call    play_sfx
.l:     ld      a,(front)
        or      a
        ld      h,BUF0/256
        jr      z,.f
        ld      h,BUF1/256
.f:     ld      l,0
        ld      a,(drawh)
        ld      d,a
        ld      e,0
        ld      bc,2048
        ldir
        ld      a,(gtick)
        and     8
        jr      z,.np
        ld      hl,s_paused
        ld      c,22
        ld      a,$55
        call    text2xc
.np:    ld      hl,s_pausehelp
        ld      c,36
        ld      a,$FF
        call    text3c
        call    present
        ld      a,(keysnew)
        bit     0,a
        call    nz,sound_cycle
        ld      a,(keysnew)
        bit     2,a
        jr      nz,.quit
        bit     1,a
        jr      z,.l
        ret
.quit:  ld      a,1
        ld      (demo_quit),a
        jp      game_exit

; ---------------------------------------------------------------------
; the sequences
; ---------------------------------------------------------------------
sector_intro:
        call    clear_objs
        ld      a,1
        ld      (warp),a
        ld      a,SFX_WARP
        call    play_sfx
        ld      hl,mus_sector
        xor     a
        call    start_music
        ld      a,(sector)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,sec_titles
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      (banner1),hl
        ld      hl,sec_names
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      (banner2),hl
        ld      a,75
        ld      (banner_t),a
        ; a fresh sector tops the shields up by one
        ld      a,(pips_max)
        ld      b,a
        ld      a,(pips)
        cp      b
        jr      nc,.p
        inc     a
        ld      (pips),a
.p:     xor     a
        ld      (hits_taken),a
        ld      b,75
.l:     push    bc
        ld      a,b
        cp      30
        jr      nz,.w
        xor     a
        ld      (warp),a
.w:     call    gf
        pop     bc
        djnz    .l
        ld      hl,mus_game
        ld      a,1
        jp      start_music

do_wave:
        ld      a,(sector)
        add     a,a
        add     a,a
        ld      b,a
        ld      a,(wave)
        add     a,b
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,wavetab
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        call    start_spawn
        ; sector 1 wave 1 of the first loop: nobody shoots yet
        ld      a,(loop)
        ld      b,a
        ld      a,(sector)
        or      b
        ld      b,a
        ld      a,(wave)
        or      b
        ld      a,1
        jr      z,.nf
        xor     a
.nf:    ld      (nofire),a
        xor     a
        ld      (bonus_rnd),a
        ld      a,(wave)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,wave_msgs
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        call    banner_msg
        ld      a,(music_on)
        or      a
        jr      nz,.l
        ld      hl,mus_game
        ld      a,1
        call    start_music
.l:     call    wave_tick
        call    gf
        ld      a,(spawn_done)
        or      a
        jr      z,.l
        ld      a,(alive_n)
        or      a
        jr      nz,.l
        ld      a,(palive)
        or      a
        jr      z,.l
        ; wave clear: a beat to breathe
        ld      a,SFX_BONUS
        call    play_sfx
        ld      b,20
.c:     push    bc
        call    gf
        pop     bc
        djnz    .c
        ret

; start_spawn: HL = wave script
start_spawn:
        ld      (spawn_ptr),hl
        ld      a,(hl)
        ld      (spawn_wait),a
        xor     a
        ld      (spawn_done),a
        ld      hl,SLOTS
        ld      b,NSLOT
.s:     ld      (hl),a
        inc     hl
        djnz    .s
        ld      a,60
        ld      (dive_t),a
        ret

; ---------------------------------------------------------------------
; wave_tick: start formations from the script, launch dives
; ---------------------------------------------------------------------
wave_tick:
        ld      a,(spawn_done)
        or      a
        jr      nz,.dives
        ld      a,(spawn_wait)
        or      a
        jr      z,.read
        dec     a
        ld      (spawn_wait),a
        jr      .dives
.read:  ld      hl,(spawn_ptr)
        ld      a,(hl)
        cp      255
        jr      nz,.form
        ld      a,1
        ld      (spawn_done),a
        jr      .dives
.form:  inc     hl
        inc     hl
        ld      b,(hl)              ; count
        call    count_free
        cp      b
        jr      c,.dives            ; wait for room
        ld      hl,(spawn_ptr)
        ld      de,fm_data
        ld      bc,8
        ldir
        ld      (spawn_ptr),hl
        call    spawn_formation
        ; the next one waits its own delay plus this one's stagger
        ld      hl,(spawn_ptr)
        ld      a,(hl)
        cp      255
        jr      z,.z
        ld      b,a
        ld      a,(fm_data+2)
        ld      c,a
        ld      a,(fm_data+4)
        ld      e,a
        ld      a,b
.mul:   add     a,e
        jr      c,.big
        dec     c
        jr      nz,.mul
        jr      .z
.big:   ld      a,255
.z:     ld      (spawn_wait),a
.dives: jp      dive_sched

; count_free -> A = free enemy records (keeps B)
count_free:
        ld      hl,ENEMY
        ld      de,E_SIZE
        ld      c,MAXE
        xor     a
.l:     inc     (hl)
        dec     (hl)
        jr      nz,.n
        inc     a
.n:     add     hl,de
        dec     c
        jr      nz,.l
        ret

; alloc_enemy -> IX = a free record (zeroed), carry if none
alloc_enemy:
        ld      ix,ENEMY
        ld      de,E_SIZE
        ld      b,MAXE
.l:     ld      a,(ix+E_TYPE)
        or      a
        jr      z,.got
        add     ix,de
        djnz    .l
        scf
        ret
.got:   push    ix
        pop     hl
        ld      b,E_SIZE
.z:     ld      (hl),a
        inc     hl
        djnz    .z
        ld      (ix+E_SLOT),255
        ld      (ix+E_GRP),255
        or      a
        ret

; spawn_formation: fm_data = wait, type, count, path, spacing, amode, angle, flags
spawn_formation:
        ld      a,(fm_data+5)
        or      a
        jr      z,.fix
        dec     a
        jr      nz,.rnd
        ld      a,(pa+1)
        ld      b,a
        ld      a,(fm_data+6)
        add     a,b
        jr      .base
.rnd:   call    rnd
        jr      .base
.fix:   ld      a,(fm_data+6)
.base:  ld      (fm_base),a
        ; spread step = 256 / count
        ld      a,(fm_data+2)
        ld      c,a
        ld      hl,256
        ld      b,0
        ld      d,0
.dv:    or      a
        sbc     hl,bc
        jr      c,.dd
        inc     d
        jr      .dv
.dd:    ld      a,d
        ld      (spread_step),a
        ; a group to judge the formation bonus by
        ld      a,(next_grp)
        inc     a
        and     NGRP-1
        ld      (next_grp),a
        add     a,a
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,GROUPS
        add     hl,de
        ld      a,(fm_data+2)
        ld      (hl),a              ; alive
        inc     hl
        ld      (hl),a              ; total
        inc     hl
        ld      a,(fm_data+1)
        cp      T_POD
        ld      a,0
        jr      nz,.g
        inc     a                   ; a pod is not a formation
.g:     ld      (hl),a              ; broken
        xor     a
        ld      (fm_k),a
.mem:   call    alloc_enemy
        ret     c
        ld      a,(fm_data+1)
        ld      (ix+E_TYPE),a
        call    type_info
        inc     hl
        ld      a,(hl)
        ld      (ix+E_HP),a
        ld      (ix+E_ST),S_WAIT
        ; delay = k * spacing + 1
        ld      a,(fm_data+4)
        ld      c,a
        ld      a,(fm_k)
        ld      b,a
        ld      a,1
        inc     b
        dec     b
        jr      z,.d2
.d1:    add     a,c
        jr      nc,.d1n
        ld      a,255
.d1n:   djnz    .d1
.d2:    ld      (ix+E_T),a
        ; path
        ld      a,(fm_data+3)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,pathtab
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      a,(hl)
        ld      (ix+E_R),a
        inc     hl
        ld      (ix+E_PL),l
        ld      (ix+E_PH),h
        ; angle
        ld      a,(fm_base)
        ld      b,a
        ld      a,(fm_data+7)
        and     2
        jr      z,.a1
        ld      a,(spread_step)
        ld      c,a
        ld      a,(fm_k)
        or      a
        jr      z,.a1
        ld      e,a
.a0:    ld      a,b
        add     a,c
        ld      b,a
        dec     e
        jr      nz,.a0
.a1:    ld      (ix+E_A),b
        ; mirror: MIRROR flag, flipped for odd members when SPLIT
        ld      a,(fm_data+7)
        ld      c,a
        rrca
        rrca
        and     1                   ; MIRROR (bit 2) -> bit 0
        ld      b,a
        bit     0,c
        jr      z,.m1
        ld      a,(fm_k)
        and     1
        xor     b
        ld      b,a
.m1:    ld      (ix+E_FL),b
        ld      a,(next_grp)
        ld      (ix+E_GRP),a
        ld      a,(fm_k)
        ld      (ix+E_K),a
        inc     a
        ld      (fm_k),a
        ld      hl,fm_data+2
        cp      (hl)
        jp      c,.mem
        ret

; type_info: IX -> HL = this type's row (frame, hp, pts lo, pts hi, fire, dive)
type_info:
        ld      a,(ix+E_TYPE)
        dec     a
        add     a,a
        add     a,a
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,typeinfo
        add     hl,de
        ret

; ---------------------------------------------------------------------
; dive_sched: every so often a held enemy breaks off and attacks
; ---------------------------------------------------------------------
dive_sched:
        ld      a,(bonus_rnd)
        or      a
        ret     nz
        ld      a,(palive)
        or      a
        ret     z
        ld      hl,dive_t
        dec     (hl)
        ret     nz
        ld      a,(d_dive)
        ld      b,a
        ld      a,(alive_n)
        cp      6
        ld      a,b
        jr      nc,.t
        srl     a                   ; stragglers attack twice as often
.t:     ld      (hl),a
        ld      a,(d_maxdiv)
        ld      b,a
        ld      a,(divers)
        cp      b
        ret     nc
        ld      a,MAXE
        call    rnd_n
        ld      c,a
        ld      b,MAXE
.l:     ld      l,c
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ex      de,hl
        ld      ix,ENEMY
        add     ix,de
        ld      a,(ix+E_ST)
        cp      S_HOLD
        jr      nz,.n
        ld      a,(ix+E_TYPE)
        call    type_dive
        cp      2
        jr      z,.n
        ld      (ix+E_ST),S_WARN
        ld      (ix+E_T),18
        ld      a,SFX_DIVE
        jp      play_sfx
.n:     inc     c
        ld      a,c
        cp      MAXE
        jr      c,.nw
        ld      c,0
.nw:    djnz    .l
        ret

; type_dive: A = type -> A = dive style (0 sweep, 1 kamikaze, 2 never)
type_dive:
        dec     a
        add     a,a
        add     a,a
        add     a,a
        add     a,5
        ld      e,a
        ld      d,0
        ld      hl,typeinfo
        add     hl,de
        ld      a,(hl)
        ret

; ---------------------------------------------------------------------
; slots: three rings of eight round the eye; the whole thing turns
; ---------------------------------------------------------------------
alloc_slot:     ; -> A = slot, carry if none
        ld      hl,SLOTS
        ld      b,0
.l:     ld      a,(hl)
        or      a
        jr      z,.got
        inc     hl
        inc     b
        ld      a,b
        cp      NSLOT
        jr      c,.l
        scf
        ret
.got:   inc     (hl)
        ld      a,b
        or      a
        ret

free_slot:      ; IX's slot, if it has one
        ld      a,(ix+E_SLOT)
        cp      NSLOT
        ret     nc
        ld      e,a
        ld      d,0
        ld      hl,SLOTS
        add     hl,de
        ld      (hl),0
        ld      (ix+E_SLOT),255
        ret

; slot_pos: A = slot -> D = angle, E = radius
slot_pos:
        ld      c,a
        and     7
        rrca
        rrca
        rrca
        ld      d,a
        ld      a,c
        and     $18
        add     a,a
        add     a,d
        ld      d,a
        ld      a,(hold_rot)
        add     a,d
        ld      d,a
        ld      a,c
        and     $18
        rrca
        rrca
        rrca
        ld      b,a
        add     a,a
        add     a,a
        add     a,a
        sub     b
        add     a,10
        ld      e,a
        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      b,a
        ld      a,(gtick)
        add     a,b
        and     63
        ld      c,a
        ld      b,0
        ld      hl,sin64
        add     hl,bc
        ld      a,(hl)
        sra     a
        sra     a
        sra     a
        sra     a
        sra     a
        add     a,e
        ld      e,a
        ret

; ---------------------------------------------------------------------
; enemies: update and draw every one
; ---------------------------------------------------------------------
enemies:
        ld      a,(gtick)
        and     1
        jr      z,.nr
        ld      hl,hold_rot
        inc     (hl)
.nr:    ld      a,(alive_c)
        ld      (alive_n),a
        ld      a,(divers_c)
        ld      (divers),a
        ld      a,(pods_c)
        ld      (bpods),a
        xor     a
        ld      (alive_c),a
        ld      (divers_c),a
        ld      (pods_c),a
        ld      hl,HITL
        ld      (hitp),hl
        ld      ix,ENEMY
        ld      b,MAXE
.l:     push    bc
        ld      a,(ix+E_TYPE)
        or      a
        call    nz,enemy_one
        ld      de,E_SIZE
        add     ix,de
        pop     bc
        djnz    .l
        ld      hl,(hitp)
        ld      (hl),$80
        ret

enemy_one:
        ld      a,(ix+E_ST)
        cp      S_BOOM
        jr      z,.nc
        ld      hl,alive_c
        inc     (hl)
        cp      S_WARN
        jr      c,.nd
        cp      S_EXIT
        jr      nc,.nd
        ld      hl,divers_c
        inc     (hl)
.nd:    ld      a,(ix+E_TYPE)
        cp      T_ARMOR
        jr      nz,.nc
        ld      hl,pods_c
        inc     (hl)
.nc:    ld      a,(ix+E_ST)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,st_tab-2
        add     hl,de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        jp      (hl)

st_tab: dw st_wait,st_path,st_seek,st_hold,st_warn,st_dive,st_sweep,st_ret
        dw st_exit,st_boom,st_mine,st_pod

st_wait:
        dec     (ix+E_T)
        ret     nz
        ld      (ix+E_ST),S_PATH
        jp      st_path

st_path:
        ld      l,(ix+E_PL)
        ld      h,(ix+E_PH)
.rd:    ld      a,(hl)
        inc     hl
        cp      $10
        jr      nc,.move
        or      a
        jr      z,.hold
        dec     a
        jr      z,.exit
        dec     a
        jr      nz,.vanish
        push    hl
        call    try_fire
        pop     hl
        jr      .rd
.move:  ld      (ix+E_PL),l
        ld      (ix+E_PH),h
        ld      c,a
        rrca
        rrca
        rrca
        rrca
        and     15
        sub     8
        bit     0,(ix+E_FL)
        jr      z,.nm
        neg
.nm:    add     a,(ix+E_A)
        ld      (ix+E_A),a
        ld      a,c
        and     15
        sub     8
        add     a,(ix+E_R)
        cp      64
        jr      c,.r
        ld      a,63
.r:     ld      (ix+E_R),a
        call    body_hit
        jp      e_draw
.hold:  ld      a,(bonus_rnd)
        or      a
        jr      nz,.exit
        call    group_break
        ld      a,(ix+E_TYPE)
        cp      T_MINE
        jr      nz,.seek
        ld      (ix+E_ST),S_MINE
        jp      e_draw
.seek:  call    to_seek
        jp      e_draw
.exit:  set     4,(ix+E_FL)         ; F_EXITP: leave for good
        ld      (ix+E_ST),S_EXIT
        ld      (ix+E_V),24
        jp      e_draw
.vanish:
        jp      remove_enemy

; to_seek: take a slot and head for it (or fly through again if full)
to_seek:
        call    alloc_slot
        jr      c,.full
        ld      (ix+E_SLOT),a
        ld      (ix+E_ST),S_SEEK
        ret
.full:  ld      (ix+E_ST),S_EXIT
        ld      (ix+E_V),20
        ret

st_seek:
        ld      a,(ix+E_SLOT)
        call    slot_pos
        ld      b,0                 ; 0 = arrived
        ld      a,d
        sub     (ix+E_A)
        ld      c,a
        call    clamp6
        cp      c
        jr      z,.ao
        inc     b
.ao:    add     a,(ix+E_A)
        ld      (ix+E_A),a
        ld      a,e
        sub     (ix+E_R)
        ld      c,a
        call    clamp2
        cp      c
        jr      z,.ro
        inc     b
.ro:    add     a,(ix+E_R)
        ld      (ix+E_R),a
        ld      a,b
        or      a
        jr      nz,.d
        ld      (ix+E_ST),S_HOLD
.d:     call    body_hit
        jp      e_draw

; clamp2: A (signed) -> -2..+2
clamp2:
        bit     7,a
        jr      nz,.neg
        cp      3
        ret     c
        ld      a,2
        ret
.neg:   cp      -2
        ret     nc
        ld      a,-2
        ret

; clamp6: A (signed) -> A clamped to -6..+6 (keeps C, D, E)
clamp6:
        bit     7,a
        jr      nz,.neg
        cp      7
        ret     c
        ld      a,6
        ret
.neg:   cp      -6
        ret     nc
        ld      a,-6
        ret

st_hold:
        ld      a,(ix+E_SLOT)
        call    slot_pos
        ld      (ix+E_A),d
        ld      (ix+E_R),e
        ; the sharper sectors fire from the ring now and then
        ld      a,(level)
        cp      3
        jr      c,.d
        call    rnd
        or      a
        call    z,try_fire
.d:     jp      e_draw

st_warn:
        ld      a,(ix+E_SLOT)
        call    slot_pos
        ld      (ix+E_A),d
        ld      (ix+E_R),e
        dec     (ix+E_T)
        jr      nz,.blink
        ld      (ix+E_ST),S_DIVE
        ld      (ix+E_V),6
        res     2,(ix+E_FL)
        ld      (ix+E_RF),0
        jp      e_draw
.blink: ld      a,(gtick)
        and     2
        jp      nz,e_proj           ; blinks while it winds up
        jp      e_draw

st_dive:
        ld      a,(d_accel)
        add     a,(ix+E_V)
        cp      120
        jr      c,.v
        ld      a,120
.v:     ld      (ix+E_V),a
        call    r_add_v
        ; steer for the ship until it commits
        ld      a,(ix+E_R)
        cp      44
        jr      nc,.ns
        ld      a,(pa+1)
        sub     (ix+E_A)
        ld      c,a
        ld      a,(d_steer)
        ld      b,a
        ld      a,c
        bit     7,a
        jr      nz,.sn
        cp      b
        jr      c,.sa
        ld      a,b
        jr      .sa
.sn:    neg
        cp      b
        jr      c,.sb
        ld      a,b
.sb:    neg
.sa:    add     a,(ix+E_A)
        ld      (ix+E_A),a
.ns:    ; one aimed shot on the way out
        bit     2,(ix+E_FL)
        jr      nz,.nf
        ld      a,(ix+E_R)
        cp      24
        jr      c,.nf
        set     2,(ix+E_FL)
        call    try_fire_d
.nf:    ld      a,(ix+E_R)
        cp      54
        jr      c,.d
        ld      a,(ix+E_TYPE)
        call    type_dive
        or      a
        jr      z,.sweep
        ld      (ix+E_ST),S_EXIT    ; kamikaze: straight through and away
        jr      .d
.sweep: ld      (ix+E_ST),S_SWEEP
        ld      (ix+E_T),20
        ld      (ix+E_R),55
        res     1,(ix+E_FL)
        ld      a,(pa+1)
        sub     (ix+E_A)
        jp      p,.d
        set     1,(ix+E_FL)
.d:     call    body_hit
        jp      e_draw

; r_add_v: radius (8.8) += E_V * 8
r_add_v:
        ld      a,(ix+E_V)
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      a,(ix+E_RF)
        add     a,l
        ld      (ix+E_RF),a
        ld      a,(ix+E_R)
        adc     a,h
        ld      (ix+E_R),a
        ret

st_sweep:
        ld      b,3
        ld      a,(level)
        cp      6
        jr      c,.s
        inc     b
.s:     ld      a,b
        bit     1,(ix+E_FL)
        jr      z,.p
        neg
.p:     add     a,(ix+E_A)
        ld      (ix+E_A),a
        dec     (ix+E_T)
        jr      nz,.d
        ld      (ix+E_ST),S_RET
        ld      (ix+E_V),48
.d:     call    body_hit
        jp      e_draw

st_ret:
        ld      a,(ix+E_V)
        cp      18
        jr      c,.v
        sub     2
        ld      (ix+E_V),a
.v:     ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      a,(ix+E_RF)
        sub     l
        ld      (ix+E_RF),a
        ld      a,(ix+E_R)
        sbc     a,h
        jr      nc,.ok
        xor     a
.ok:    ld      (ix+E_R),a
        inc     (ix+E_A)
        ld      a,(ix+E_SLOT)
        call    slot_pos
        ld      a,e
        add     a,4
        cp      (ix+E_R)
        jr      c,.d
        ld      (ix+E_ST),S_SEEK
.d:     call    body_hit
        jp      e_draw

st_exit:
        ld      a,(ix+E_V)
        add     a,4
        cp      120
        jr      c,.v
        ld      a,120
.v:     ld      (ix+E_V),a
        call    r_add_v
        ld      a,(ix+E_R)
        cp      63
        jr      nc,.out
        call    body_hit
        jp      e_draw
.out:   bit     4,(ix+E_FL)
        jp      nz,remove_enemy
        ld      a,(bonus_rnd)
        or      a
        jp      nz,remove_enemy
        ; back in through the eye, to a slot
        call    free_slot
        ld      (ix+E_R),1
        call    rnd
        ld      (ix+E_A),a
        res     2,(ix+E_FL)
        jp      to_seek

st_boom:
        dec     (ix+E_T)
        jr      z,.gone
        ld      a,(ix+E_T)
        cp      5
        ld      a,F_EXA
        jr      nc,.f
        ld      a,F_EXB
.f:     ld      b,(ix+E_X)
        ld      c,(ix+E_Y)
        jp      draw_c
.gone:  ld      (ix+E_TYPE),0
        ret

st_mine:
        ld      a,(d_mine)
        ld      l,a
        ld      h,0
        ld      a,(ix+E_RF)
        add     a,l
        ld      (ix+E_RF),a
        jr      nc,.n
        inc     (ix+E_R)
.n:     ld      a,(ix+E_R)
        cp      40
        jr      c,.q
        bit     3,(ix+E_FL)
        jr      nz,.q
        set     3,(ix+E_FL)
        ld      a,SFX_MINE
        call    play_sfx
.q:     ld      a,(ix+E_R)
        cp      52
        jr      nc,.boom
        ; blinks as it nears the orbit
        cp      40
        jp      c,e_draw
        ld      a,(gtick)
        and     2
        jp      nz,e_proj
        jp      e_draw
.boom:  ; detonates: anything near it on the orbit takes a hit
        ld      a,(ix+E_A)
        ld      b,a
        ld      a,(pa+1)
        sub     b
        jp      p,.ab
        neg
.ab:    cp      22
        call    c,hit_player
        ld      b,(ix+E_X)
        ld      c,(ix+E_Y)
        ld      a,16
        call    burst
        ld      a,SFX_BIGKILL
        call    play_sfx
        ld      a,4
        ld      (flash_t),a
        call    group_break
        call    group_dec
        call    free_slot
        ld      (ix+E_ST),S_BOOM
        ld      (ix+E_T),8
        ret

; remove_enemy: gone without being shot (left the screen for good)
remove_enemy:
        call    group_break
        call    group_dec
        call    free_slot
        ld      (ix+E_TYPE),0
        ret

; ---------------------------------------------------------------------
; e_draw: work out the screen point and draw at the size the radius gives
; ---------------------------------------------------------------------
e_draw:
        call    e_proj
        ld      e,a
        ld      d,0
        ld      hl,size_off
        add     hl,de
        ld      a,(hl)
        cp      2
        jr      c,.na
        ld      d,a
        ld      a,(gtick)
        rrca
        rrca
        add     a,(ix+E_K)
        and     1
        add     a,d
.na:    ld      d,a
        push    de
        call    type_info
        pop     de
        ld      a,(hl)
        add     a,d
        ld      b,(ix+E_X)
        ld      c,(ix+E_Y)
        jp      draw_c

; e_proj: screen point and size of IX; puts it on this frame's hit list
;   -> A = size 0..3
e_proj:
        ld      a,(ix+E_R)
        cp      64
        jr      c,.r
        ld      a,63
.r:     ld      c,a
        ld      a,(ix+E_A)
        call    proj
        ld      (ix+E_X),b
        ld      (ix+E_Y),c
        ld      a,(ix+E_ST)
        cp      S_POD
        ld      a,2
        jr      z,.sz
        ld      a,(ix+E_R)
        call    rsize
.sz:    push    af
        ld      hl,(hitp)
        ld      e,a
        ld      a,(ix+E_R)
        ld      (hl),a
        inc     l
        ld      (hl),e
        inc     l
        ld      (hl),b
        inc     l
        ld      (hl),c
        inc     l
        push    ix
        pop     de
        ld      (hl),e
        inc     l
        ld      (hl),d
        inc     l
        ld      (hitp),hl
        pop     af
        ret

size_off: db 0,1,2,4

; rsize: A = radius -> A = size 0..3
rsize:
        cp      10
        jr      c,.s0
        cp      22
        jr      c,.s1
        cp      36
        jr      c,.s2
        ld      a,3
        ret
.s0:    xor     a
        ret
.s1:    ld      a,1
        ret
.s2:    ld      a,2
        ret

; body_hit: an enemy out on the orbit that touches the ship
body_hit:
        ld      a,(ix+E_R)
        cp      48
        ret     c
        ld      a,(bonus_rnd)
        or      a
        ret     nz
        ld      a,(palive)
        or      a
        ret     z
        ld      b,(ix+E_X)          ; (where it was drawn last frame)
        ld      c,(ix+E_Y)
        ld      a,(px)
        sub     b
        jp      p,.x
        neg
.x:     cp      5
        ret     nc
        ld      a,(py)
        sub     c
        jp      p,.y
        neg
.y:     cp      4
        ret     nc
        ld      a,(pinv)
        or      a
        ret     nz
        call    hit_player
        ; and the enemy breaks up against the hull (no points)
        ld      (ix+E_X),b
        ld      (ix+E_Y),c
        ld      a,10
        call    burst
        call    group_break
        call    group_dec
        call    free_slot
        ld      (ix+E_ST),S_BOOM
        ld      (ix+E_T),8
        pop     hl                  ; skip the caller's draw
        ret

; ---------------------------------------------------------------------
; groups: a formation wiped out before any of it settles earns a bonus
; ---------------------------------------------------------------------
grp_ptr:        ; -> HL = this enemy's group record, carry if none
        ld      a,(ix+E_GRP)
        cp      NGRP
        ccf
        ret     c
        add     a,a
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,GROUPS
        add     hl,de
        or      a
        ret

group_break:
        call    grp_ptr
        ret     c
        inc     hl
        inc     hl
        ld      (hl),1
        ret

group_dec:      ; -> Z if this was the last of an unbroken formation
        call    grp_ptr
        jr      c,.no
        dec     (hl)
        jr      nz,.no
        inc     hl
        ld      a,(hl)
        ld      (tmp1),a            ; formation size
        inc     hl
        ld      a,(hl)
        or      a
        jr      nz,.no
        ld      a,(tmp1)
        cp      4
        jr      c,.no
        xor     a
        ret
.no:    or      1
        ret

; ---------------------------------------------------------------------
; try_fire: maybe fire a shot outward from this enemy (if its type does)
; try_fire_d: the same for a diving enemy (always, if it may fire at all)
; ---------------------------------------------------------------------
try_fire:
        call    fire_ok
        ret     z
        call    rnd
        ld      hl,d_fire
        cp      (hl)
        ret     nc
        jr      try_fire_go
try_fire_d:
        call    fire_ok
        ret     z
try_fire_go:
        ld      a,(ix+E_A)
        ld      c,(ix+E_R)
        ld      b,0
        jp      fire_shot

fire_ok:        ; -> NZ if IX may shoot now
        ld      a,(nofire)
        or      a
        jr      nz,.no
        ld      a,(bonus_rnd)
        or      a
        jr      nz,.no
        ld      a,(palive)
        or      a
        ret     z
        call    type_info
        ld      de,4
        add     hl,de
        ld      a,(hl)
        or      a
        ret
.no:    xor     a
        ret

; fire_shot: A = angle, C = radius, B = kind (0 shot, 1 plasma)
fire_shot:
        ld      e,a
        ld      hl,ESHOT
        ld      d,NES
.l:     ld      a,(hl)
        or      a
        jr      z,.got
        push    de
        ld      de,6
        add     hl,de
        pop     de
        dec     d
        jr      nz,.l
        ret
.got:   ld      a,c
        or      a
        jr      nz,.r
        inc     a
.r:     ld      (hl),a
        inc     hl
        ld      (hl),0
        inc     hl
        ld      (hl),e
        inc     hl
        ld      (hl),b
        ld      a,b
        or      a
        ld      a,SFX_EFIRE
        jp      z,play_sfx
        ret

; ---------------------------------------------------------------------
; kill_enemy: IX shot down.  Points: the type's value, doubled while it
;   is attacking, doubled again when it is hit close in (point blank)
; ---------------------------------------------------------------------
kill_enemy:
        ld      a,(bonus_rnd)
        or      a
        jr      z,.norm
        ld      hl,bon_hits
        inc     (hl)
        ld      de,$0200
        call    add_score
        ld      de,$0200
        call    float_num_ix
        ld      a,SFX_SPARK
        call    play_sfx
        ld      a,6
        jp      .fx
.norm:  call    type_info
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (pts),de
        ld      b,1
        ld      a,(ix+E_ST)
        cp      S_WARN
        jr      c,.m1
        cp      S_BOOM
        jr      nc,.m1
        inc     b                   ; attacking: x2
.m1:    ld      a,(ix+E_R)
        cp      40
        jr      c,.m2
        ld      a,(ix+E_ST)
        cp      S_POD
        jr      z,.m2
        sla     b                   ; point blank: x2
.m2:    ld      hl,0
        ld      (fval),hl
.add:   push    bc
        ld      de,(pts)
        call    add_score
        ld      de,(pts)
        ld      hl,fval+1
        ld      a,(hl)
        add     a,e
        daa
        ld      (hl),a
        dec     hl
        ld      a,(hl)
        adc     a,d
        daa
        ld      (hl),a
        pop     bc
        djnz    .add
        ; show the bigger scores where they happened
        ld      a,(fval)
        cp      $03
        jr      c,.nfl
        ld      a,(fval)
        ld      d,a
        ld      a,(fval+1)
        ld      e,a
        call    float_num_ix
.nfl:   ld      a,SFX_KILL
        call    play_sfx
        ; specials
        ld      a,(ix+E_TYPE)
        cp      T_POD
        call    z,got_pod
        ; formation bonus
        call    group_dec
        jr      nz,.ng
        ld      a,(tmp1)
        ld      b,a
        ld      de,0
.gb:    push    bc
        ld      hl,$0250
        ld      a,e
        add     a,l
        daa
        ld      e,a
        ld      a,d
        adc     a,h
        daa
        ld      d,a
        pop     bc
        djnz    .gb
        push    de
        call    add_score
        pop     de
        call    float_bonus_ix
        ld      a,SFX_BONUS
        call    play_sfx
.ng:    ld      a,(ix+E_R)
        call    rsize
        add     a,a
        add     a,4
.fx:    ld      b,(ix+E_X)
        ld      c,(ix+E_Y)
        call    burst
        call    free_slot
        ld      (ix+E_ST),S_BOOM
        ld      (ix+E_T),8
        ret

got_pod:
        ld      a,(ptwin)
        or      a
        jr      z,.new
        ld      de,$2000
        call    add_score
.new:   ld      a,1
        ld      (ptwin),a
        ld      hl,s_twin
        call    banner_msg
        ld      a,SFX_POWER
        jp      play_sfx

; ---------------------------------------------------------------------
; player shots: fly inward, shrinking with distance
; ---------------------------------------------------------------------
pshots:
        ld      iy,PSHOT
        ld      b,NPS
.l:     push    bc
        ld      a,(iy+0)
        or      a
        jr      z,.n
        ld      c,a
        rrca
        rrca
        rrca
        rrca
        and     15
        add     a,2
        ld      b,a
        ld      a,c
        sub     b
        jr      c,.kill
        cp      4
        jr      c,.kill
        ld      (iy+0),a
        ld      c,a
        ld      a,(iy+1)
        call    proj
        ld      (iy+2),b
        ld      (iy+3),c
        ld      a,(iy+0)
        cp      16
        ld      a,F_SHOT0
        jr      c,.f
        ld      a,(iy+0)
        cp      36
        ld      a,F_SHOT1
        jr      c,.f
        ld      a,F_SHOT2
.f:     ld      b,(iy+2)
        ld      c,(iy+3)
        call    draw_c
        call    shot_hits
        jr      nc,.n
.kill:  ld      (iy+0),0
.n:     ld      de,4
        add     iy,de
        pop     bc
        djnz    .l
        ret

; shot_hits: IY = shot (x, y at +2, +3) -> carry if it hit something
shot_hits:
        ld      a,(boss_on)
        or      a
        jr      z,.en
        call    boss_shot
        ret     c
.en:    ld      hl,HITL
        ld      c,(iy+0)            ; the shot's depth
.l:     ld      a,(hl)
        cp      $80
        jr      z,.none
        sub     c                   ; near it in depth at all?
        jp      p,.rp
        neg
.rp:    cp      14
        jr      c,.box
.skip:  ld      a,l
        add     a,6
        ld      l,a
        jr      .l
.none:  or      a
        ret
.box:   push    hl
        inc     l
        ld      e,(hl)              ; size
        ld      d,0
        inc     l
        ld      a,(iy+2)
        sub     (hl)
        jp      p,.ax
        neg
.ax:    push    hl
        ld      hl,hit_hx
        add     hl,de
        cp      (hl)
        pop     hl
        jr      nc,.miss
        inc     l
        ld      a,(iy+3)
        sub     (hl)
        jp      p,.ay
        neg
.ay:    push    hl
        ld      hl,hit_hy
        add     hl,de
        cp      (hl)
        pop     hl
        jr      nc,.miss
        inc     l
        ld      e,(hl)
        inc     l
        ld      d,(hl)
        push    de
        pop     ix
        pop     hl
        ld      a,(ix+E_TYPE)       ; (already shot down this frame?)
        or      a
        jr      z,.skip
        ld      a,(ix+E_ST)
        cp      S_BOOM
        jr      z,.skip
        jr      .hit
.miss:  pop     hl
        jr      .skip
.hit:   dec     (ix+E_HP)
        jr      z,.dead
        ld      a,SFX_HIT
        call    play_sfx
        ld      b,(ix+E_X)
        ld      c,(ix+E_Y)
        ld      a,F_EXS
        call    draw_c
        scf
        ret
.dead:  call    kill_enemy
        scf
        ret

hit_hx: db 2,3,4,5
hit_hy: db 2,2,3,3

; ---------------------------------------------------------------------
; enemy shots: fly outward, growing as they come
; ---------------------------------------------------------------------
eshots:
        ld      iy,ESHOT
        ld      b,NES
.l:     push    bc
        ld      a,(iy+0)
        or      a
        jp      z,.n
        ; speed = base + r*4 (radius/256 per frame)
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        ld      de,(d_espd)
        add     hl,de
        ld      a,(iy+3)
        or      a
        jr      z,.ns
        ld      e,l                 ; plasma is a quarter quicker
        ld      d,h
        srl     d
        rr      e
        srl     d
        rr      e
        add     hl,de
.ns:    ld      a,(iy+1)
        add     a,l
        ld      (iy+1),a
        ld      a,(iy+0)
        adc     a,h
        cp      62
        jr      nc,.kill
        ld      (iy+0),a
        ld      c,a
        ld      a,(iy+2)
        call    proj
        ld      (iy+4),b
        ld      (iy+5),c
        ld      a,(iy+0)
        cp      20
        ld      d,0
        jr      c,.s
        inc     d
        cp      40
        jr      c,.s
        inc     d
.s:     ld      a,(iy+3)
        or      a
        ld      a,F_ESHOT0
        jr      z,.k
        ld      a,F_PLASMA0
.k:     add     a,d
        call    draw_c
        ; does it reach the ship?
        ld      a,(iy+0)
        cp      46
        jr      c,.n
        ld      a,(palive)
        or      a
        jr      z,.n
        ld      a,(pinv)
        or      a
        jr      nz,.n
        ld      a,(px)
        sub     (iy+4)
        jp      p,.x
        neg
.x:     cp      4
        jr      nc,.n
        ld      a,(py)
        sub     (iy+5)
        jp      p,.y
        neg
.y:     cp      3
        jr      nc,.n
        call    hit_player
.kill:  ld      (iy+0),0
.n:     ld      de,6
        add     iy,de
        pop     bc
        dec     b
        jp      nz,.l
        ret

clear_eshots:
        ld      hl,ESHOT
        ld      b,NES*6
.l:     ld      (hl),0
        inc     hl
        djnz    .l
        ret

; ---------------------------------------------------------------------
; the player
; ---------------------------------------------------------------------
player:
        ld      a,(palive)
        or      a
        jp      z,.dead
        ld      a,(pinv)
        or      a
        jr      z,.ni
        dec     a
        ld      (pinv),a
.ni:    ; ---- steering
        ld      a,(demo)
        or      a
        jr      z,.human
        ld      a,(ai_has)
        or      a
        jr      z,.stop
        ld      a,(ai_tgt)
        jr      .target
.human: ld      a,(keys)
        and     $60
        jr      z,.pad
        bit     5,a                 ; Z: anticlockwise
        ld      a,-1
        jr      nz,.rot
        ld      a,1
.rot:   ld      (pdir),a
        jr      .move
.pad:   ld      a,(joy1)
        ld      b,a
        ld      a,(kmove)
        or      b
        and     $0F
        jr      z,.stop
        ld      e,a
        ld      d,0
        ld      hl,dir2ang
        add     hl,de
        ld      a,(hl)
        cp      255
        jr      z,.stop
.target:
        ld      b,a
        ld      a,(pa+1)
        ld      c,a
        ld      a,b
        sub     c                   ; signed difference
        jr      z,.snap
        ld      c,a
        bit     7,a
        jr      z,.pos
        neg
.pos:   ; close enough to land on it this frame?
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl               ; |diff| * 16
        ld      a,(pspd)
        ld      e,a
        ld      d,0
        or      a
        sbc     hl,de
        jr      c,.snap
        jr      z,.snap
        ld      a,c
        cp      $80
        jr      z,.move             ; dead opposite: keep the old way round
        rlca
        ld      a,1
        jr      nc,.dset
        ld      a,-1
.dset:  ld      (pdir),a
        jr      .move
.snap:  ld      a,b
        ld      (pa+1),a
        xor     a
        ld      (pa),a
        ld      (pspd),a
        jr      .fire
.stop:  xor     a
        ld      (pspd),a
        jr      .fire
.move:  ld      a,(pspd)
        or      a
        jr      nz,.acc
        ld      a,40-8              ; starts briskly
.acc:   add     a,8
        cp      113
        jr      c,.sp
        ld      a,112
.sp:    ld      (pspd),a
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl               ; 8.8 step
        ld      a,(pdir)
        or      a
        jp      p,.addp
        ex      de,hl
        ld      hl,(pa)
        or      a
        sbc     hl,de
        jr      .st
.addp:  ld      de,(pa)
        add     hl,de
.st:    ld      (pa),hl
        ; ---- fire
.fire:  ld      a,(pfire_cd)
        or      a
        jr      z,.cf
        dec     a
        ld      (pfire_cd),a
.cf:    ld      a,(demo)
        or      a
        jr      z,.hf
        ld      a,(ai_fire)
        jr      .fb
.hf:    ld      a,(keys)
        and     $80
        ld      b,a
        ld      a,(jfire)
        or      b
.fb:    or      a
        jr      z,.nofire
        ld      a,(fire_held)
        or      a
        jr      z,.press            ; a fresh press fires at once
        ld      a,(pfire_cd)
        or      a
        jr      nz,.drawp
.press: ld      a,1
        ld      (fire_held),a
        call    p_shoot
        jr      .drawp
.nofire:
        xor     a
        ld      (fire_held),a
.drawp: ; ---- draw (blinks while invulnerable)
        ld      a,(pa+1)
        ld      c,RIM
        call    proj
        ld      a,b
        ld      (px),a
        ld      a,c
        ld      (py),a
        ld      a,(pinv)
        and     2
        ret     nz
        ld      a,(px)
        ld      b,a
        ld      a,(py)
        ld      c,a
        ld      a,(pa+1)
        sub     56
        rrca
        rrca
        rrca
        rrca
        and     15
        add     a,F_SHIP0
        jp      draw_c
.dead:  ld      a,(gover)
        or      a
        ret     nz
        ld      hl,pdead_t
        dec     (hl)
        ret     nz
        ld      hl,lives
        dec     (hl)
        jr      z,.over
        ld      a,(pips_max)
        ld      (pips),a
        ld      a,60
        ld      (pinv),a
        ld      a,1
        ld      (palive),a
        xor     a
        ld      (pspd),a
        ld      hl,s_ready
        jp      banner_msg
.over:  ld      a,1
        ld      (gover),a
        ld      a,150
        ld      (gover_t),a
        ld      hl,s_gameover
        call    banner_msg
        ld      a,150
        ld      (banner_t),a
        ld      hl,mus_gameover
        xor     a
        jp      start_music

; p_shoot: fire one shot (or a twin pair) inward
p_shoot:
        ld      a,4
        ld      (pfire_cd),a
        ld      a,(ptwin)
        or      a
        jr      nz,.twin
        call    count_ps
        cp      4
        ret     nc
        ld      a,(pa+1)
        call    new_ps
        jr      .snd
.twin:  call    count_ps
        cp      7
        ret     nc
        ld      a,(pa+1)
        sub     3
        call    new_ps
        ld      a,(pa+1)
        add     a,3
        call    new_ps
.snd:   ld      a,SFX_SHOT
        jp      play_sfx

count_ps:       ; -> A = shots in flight
        ld      hl,PSHOT
        ld      b,NPS
        ld      c,0
.l:     ld      a,(hl)
        or      a
        jr      z,.n
        inc     c
.n:     inc     hl
        inc     hl
        inc     hl
        inc     hl
        djnz    .l
        ld      a,c
        ret

new_ps:         ; A = angle
        ld      c,a
        ld      hl,PSHOT
        ld      b,NPS
.l:     ld      a,(hl)
        or      a
        jr      z,.got
        inc     hl
        inc     hl
        inc     hl
        inc     hl
        djnz    .l
        ret
.got:   ld      (hl),RIM-3
        inc     hl
        ld      (hl),c
        ret

; hit_player: one shield pip gone, or the ship if it was the last
hit_player:
        push    bc
        push    de
        push    hl
        ld      a,(palive)
        or      a
        jr      z,.x
        ld      a,(pinv)
        or      a
        jr      nz,.x
        ld      a,(gover)
        or      a
        jr      nz,.x
        ld      hl,hits_taken
        inc     (hl)
        ld      hl,pips
        dec     (hl)
        jr      z,.die
        ld      a,40
        ld      (pinv),a
        ld      a,SFX_PHIT
        call    play_sfx
        ld      a,(px)
        ld      b,a
        ld      a,(py)
        ld      c,a
        ld      a,8
        call    burst
        ld      a,2
        ld      (flash_t),a
.x:     pop     hl
        pop     de
        pop     bc
        ret
.die:   xor     a
        ld      (palive),a
        ld      (ptwin),a
        ld      a,75
        ld      (pdead_t),a
        ld      a,SFX_DIE
        call    play_sfx
        ld      a,8
        ld      (flash_t),a
        ld      a,(px)
        ld      b,a
        ld      a,(py)
        ld      c,a
        ld      a,24
        call    burst
        call    clear_eshots
        ; attackers pull back to the ring
        push    ix
        ld      ix,ENEMY
        ld      b,MAXE
.l:     ld      a,(ix+E_TYPE)
        or      a
        jr      z,.n
        ld      a,(ix+E_ST)
        cp      S_WARN
        jr      c,.n
        cp      S_EXIT
        jr      nc,.n
        ld      (ix+E_ST),S_RET
        ld      (ix+E_V),40
.n:     ld      de,E_SIZE
        add     ix,de
        djnz    .l
        pop     ix
        jr      .x

; ---------------------------------------------------------------------
; stars: stream out of the eye, faster as they near you
; ---------------------------------------------------------------------
stars_init:
        ld      hl,STARS
        ld      b,NSTAR
.l:     call    rnd
        ld      (hl),a
        inc     hl
        ld      a,60
        call    rnd_n
        inc     a
        ld      (hl),a
        inc     hl
        inc     hl
        djnz    .l
        ret

stars:
        ld      ix,STARS
        ld      b,NSTAR
        ld      a,(alive_n)         ; a crowded sky: fewer stars
        cp      12
        jr      c,.l
        ld      b,NSTAR-8
.l:     push    bc
        ld      a,(ix+1)
        add     a,6
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        ld      a,(warp)
        or      a
        jr      z,.nw
        add     hl,hl
        add     hl,hl
        add     hl,hl
.nw:    ld      a,(ix+2)
        add     a,l
        ld      (ix+2),a
        ld      a,(ix+1)
        adc     a,h
        cp      63
        jr      c,.ok
        call    rnd
        ld      (ix+0),a
        ld      a,6
        call    rnd_n
        inc     a
.ok:    ld      (ix+1),a
        ld      c,a
        ld      a,(ix+0)
        call    proj
        ld      a,(ix+1)
        cp      22
        ld      a,0                 ; far: green
        jr      c,.c
        ld      a,1                 ; near: yellow
.c:     call    plot_c
        ld      a,(warp)
        or      a
        jr      nz,.streak
        ld      a,(ix+1)
        cp      52
        jr      c,.n
        ld      a,(ix+1)            ; close stars get a short trail
        sub     2
        jr      .tr
.streak:
        ld      a,(ix+1)
        sub     4
        jr      c,.n
.tr:    ld      c,a
        ld      a,(ix+0)
        call    proj
        ld      a,1
        call    plot_c
.n:     ld      de,3
        add     ix,de
        pop     bc
        djnz    .l
        ret

draw_vortex:
        ld      a,(gtick)
        rrca
        and     3
        add     a,F_VORTEX0
        ld      bc,64*256+32
        jp      draw_c

; ---------------------------------------------------------------------
; particles: A = count, B = x, C = y
; ---------------------------------------------------------------------
burst:
        ld      (bx),bc
        ld      (bn),a
        ld      a,(bn)
        ld      d,a
        call    rnd
        and     15
        ld      e,a                 ; first direction
.l:     push    de
        call    new_part
        pop     de
        jr      c,.done
        ; life
        call    rnd
        and     7
        add     a,7
        ld      (hl),a
        inc     hl
        ld      (hl),128
        inc     hl
        ld      a,(bx+1)
        ld      (hl),a              ; x (8.8)
        inc     hl
        ld      (hl),128
        inc     hl
        ld      a,(bx)
        ld      (hl),a              ; y
        inc     hl
        push    hl
        ld      a,e
        and     15
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,dir16
        add     hl,bc
        ld      b,(hl)
        inc     hl
        ld      c,(hl)
        call    rnd
        and     1
        jr      z,.sl
        sra     b                   ; some are slower
        sra     c
.sl:    pop     hl
        ld      (hl),b
        inc     hl
        ld      (hl),c
        inc     hl
        call    rnd
        and     1
        add     a,a
        inc     a                   ; colour 1 or 3
        ld      (hl),a
        ld      a,e
        add     a,5
        ld      e,a
        dec     d
        jr      nz,.l
.done:  ret

new_part:       ; -> HL = a free particle, carry if none
        ld      hl,PART
        ld      b,NPART
        ld      de,8
.l:     ld      a,(hl)
        or      a
        ret     z
        add     hl,de
        djnz    .l
        scf
        ret

particles:
        ld      ix,PART
        ld      b,NPART
.l:     push    bc
        ld      a,(ix+0)
        or      a
        jr      z,.n
        dec     (ix+0)
        jr      z,.n
        ld      a,(ix+5)
        call    .vel
        ld      a,(ix+1)
        add     a,l
        ld      (ix+1),a
        ld      a,(ix+2)
        adc     a,h
        ld      (ix+2),a
        ld      a,(ix+6)
        call    .vel
        ld      a,(ix+3)
        add     a,l
        ld      (ix+3),a
        ld      a,(ix+4)
        adc     a,h
        ld      (ix+4),a
        ld      b,(ix+2)
        ld      c,(ix+4)
        ld      a,c                 ; keep out of the HUD corners
        cp      5
        jr      c,.cx
        cp      52
        jr      c,.ok
.cx:    ld      a,b
        cp      24
        jr      c,.n
        cp      104
        jr      nc,.n
.ok:    ld      a,(ix+0)
        cp      4
        ld      a,3
        jr      c,.c
        ld      a,(ix+7)
.c:     call    plot_c
.n:     ld      de,8
        add     ix,de
        pop     bc
        djnz    .l
        ret
.vel:   ld      l,a                 ; signed 4.4 -> 8.8 in HL
        add     a,a
        sbc     a,a
        ld      h,a
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ret

; ---------------------------------------------------------------------
; floating scores
; ---------------------------------------------------------------------
; float_num_ix: DE = BCD value, at IX's position
float_num_ix:
        ld      b,(ix+E_X)
        ld      c,(ix+E_Y)
        xor     a
        jr      float_add
float_bonus_ix:
        ld      b,(ix+E_X)
        ld      c,(ix+E_Y)
        ld      a,1
; float_add: A = kind (0 number, 1 BONUS number), B = x, C = y, DE = BCD
float_add:
        ld      (tmp2),a
        ld      hl,FLOATS
        push    bc
        ld      b,NFLT
.l:     ld      a,(hl)
        or      a
        jr      z,.got
        inc     hl
        inc     hl
        inc     hl
        inc     hl
        inc     hl
        inc     hl
        djnz    .l
        ld      hl,FLOATS           ; all busy: reuse the first
.got:   pop     bc
        ld      (hl),30
        inc     hl
        ld      a,b
        sub     8
        jr      nc,.x0
        xor     a
.x0:    rrca
        rrca
        and     $3F
        cp      22
        jr      c,.x1
        ld      a,22
.x1:    ld      (hl),a              ; column
        inc     hl
        ld      a,c
        sub     6
        cp      6
        jr      nc,.y0
        ld      a,6
.y0:    cp      46
        jr      c,.y1
        ld      a,46
.y1:    ld      (hl),a
        inc     hl
        ld      (hl),d
        inc     hl
        ld      (hl),e
        inc     hl
        ld      a,(tmp2)
        ld      (hl),a
        ret

floats:
        ld      iy,FLOATS
        ld      b,NFLT
.l:     push    bc
        ld      a,(iy+0)
        or      a
        jr      z,.n
        dec     (iy+0)
        jr      z,.n
        and     3
        jr      nz,.nm
        ld      a,(iy+2)
        cp      7
        jr      c,.nm
        dec     (iy+2)
.nm:    ; "nnnn" without leading zeros (or "BONUS nnnn")
        ld      de,txtbuf
        ld      a,(iy+5)
        or      a
        jr      z,.nb
        ld      hl,s_bonus
        call    strcpy
.nb:    ld      a,(iy+3)
        ld      (numbuf+4),a
        ld      a,(iy+4)
        ld      (numbuf+5),a
        ld      hl,numbuf+4
        push    de
        ld      de,numbuf
        call    bcd2_str
        pop     de
        ld      hl,numbuf
.z:     ld      a,(hl)
        cp      '0'
        jr      nz,.cp
        inc     hl
        jr      .z
.cp:    call    strcpy
        ld      a,(gtick)
        and     2
        ld      a,$55
        jr      z,.c
        ld      a,$FF
.c:     ld      b,(iy+1)
        ld      c,(iy+2)
        ld      hl,txtbuf
        call    text3
.n:     ld      de,6
        add     iy,de
        pop     bc
        djnz    .l
        ret

; bcd2_str: HL = 2 BCD bytes -> DE "nnnn",0
bcd2_str:
        ld      b,2
.l:     ld      a,(hl)
        rrca
        rrca
        rrca
        rrca
        and     15
        add     a,'0'
        ld      (de),a
        inc     de
        ld      a,(hl)
        and     15
        add     a,'0'
        ld      (de),a
        inc     de
        inc     hl
        djnz    .l
        xor     a
        ld      (de),a
        ret

; strcpy: HL -> DE (DE left on the terminator)
strcpy:
        ld      a,(hl)
        ld      (de),a
        or      a
        ret     z
        inc     hl
        inc     de
        jr      strcpy

; ---------------------------------------------------------------------
; banner: a big line (and an optional small one) in the middle
; ---------------------------------------------------------------------
banner_msg:     ; HL = big line
        ld      (banner1),hl
        ld      hl,0
        ld      (banner2),hl
        ld      a,45
        ld      (banner_t),a
        ret

banner:
        ld      a,(banner_t)
        or      a
        ret     z
        dec     a
        ld      (banner_t),a
        ld      hl,(banner1)
        ld      a,h
        or      l
        jr      z,.b2
        ld      a,(gtick)
        and     4
        ld      a,$55
        jr      z,.c
        ld      a,$FF
.c:     ld      c,15
        call    text2xc
.b2:    ld      hl,(banner2)
        ld      a,h
        or      l
        ret     z
        ld      c,42
        ld      a,$55
        jp      text3c

; ---------------------------------------------------------------------
; hud: scores in the top corners, ships and shields in the bottom ones
; ---------------------------------------------------------------------
hud:
        ld      hl,score
        call    bcd_to_str
        ld      bc,0
        ld      a,$55
        call    text3
        ld      hl,HISC             ; the best score - yours once you pass it
        ld      de,score
        ld      b,3
.hc:    ld      a,(de)
        cp      (hl)
        jr      c,.hs
        jr      nz,.hy
        inc     hl
        inc     de
        djnz    .hc
.hs:    ld      hl,HISC
        jr      .hp
.hy:    ld      hl,score
.hp:    call    bcd_to_str
        ld      b,26
        ld      c,0
        ld      a,$FF
        call    text3
        ; spare ships
        ld      a,(lives)
        cp      2
        jr      c,.np
        dec     a
        cp      5
        jr      c,.l0
        ld      a,4
.l0:    ld      b,a
        ld      c,3
.ls:    push    bc
        ld      b,c
        ld      c,61
        ld      a,F_LIFE
        call    draw_c
        pop     bc
        ld      a,c
        add     a,6
        ld      c,a
        djnz    .ls
.np:    ; shields: pip k (max..1) is solid while k <= pips
        ld      a,(pips_max)
        ld      b,a
        ld      c,125
.ps:    push    bc
        ld      a,(pips)
        cp      b
        ld      a,F_PIP
        jr      nc,.pc
        ld      a,F_PIPX
.pc:    ld      b,c
        ld      c,61
        call    draw_c
        pop     bc
        ld      a,c
        sub     4
        ld      c,a
        djnz    .ps
        ; sector and wave ("1-3"), or BOSS, or BONUS
        ld      a,(bonus_rnd)
        or      a
        ld      hl,s_hbonus
        ld      b,27
        jr      nz,.wt
        ld      a,(wave)
        cp      4
        ld      hl,s_hboss
        ld      b,28
        jr      nc,.wt
        ld      hl,txtbuf
        ld      a,(sector)
        add     a,'1'
        ld      (hl),a
        inc     hl
        ld      (hl),'-'
        inc     hl
        ld      a,(wave)
        add     a,'1'
        ld      (hl),a
        inc     hl
        ld      (hl),0
        ld      hl,txtbuf
        ld      b,29
.wt:    ld      c,52
        xor     a
        call    text3
.bar:
.tw:    ld      a,(ptwin)
        or      a
        ret     z
        ld      hl,s_twinhud
        ld      b,0
        ld      c,52
        ld      a,$55
        jp      text3

; hud_bar: the boss's strength, top centre (drawn every frame)
hud_bar:
        ld      a,(boss_on)
        or      a
        ret     z
        ld      a,(bhp)
        or      a
        ret     z
        srl     a
        ld      b,a
        ld      a,64
        sub     b
        ld      b,a
        ld      a,(bhp)
        srl     a
        add     a,64
        ld      d,a
        ld      c,1
        ld      e,$FF
        jp      hline

; ---------------------------------------------------------------------
; the HUD corners are drawn only when something in them changes, into a
; cache in the SRAM; every frame the cache is copied over the corners
; ---------------------------------------------------------------------
hud_check:
        ld      hl,hud_src
        ld      de,txtbuf
        ld      b,HUDSIG
.g:     push    bc
        ld      a,(hl)
        inc     hl
        push    hl
        ld      h,(hl)
        ld      l,a
        ld      a,(hl)
        ld      (de),a
        inc     de
        pop     hl
        inc     hl
        pop     bc
        djnz    .g
        ld      hl,txtbuf
        ld      de,hud_sig
        ld      b,HUDSIG
.c:     ld      a,(de)
        cp      (hl)
        jr      nz,.new
        inc     hl
        inc     de
        djnz    .c
        jr      .dirty
.new:   ld      hl,txtbuf
        ld      de,hud_sig
        ld      bc,HUDSIG
        ldir
        ld      a,2                 ; both buffers
        ld      (hud_dirty),a
.dirty: ld      a,(hud_dirty)
        or      a
        ret     z
        dec     a
        ld      (hud_dirty),a
        ; blank the corners, then draw them
        ld      hl,hud_regions
.r:     ld      c,(hl)
        ld      a,c
        cp      255
        jp      z,hud
        inc     hl
        ld      e,(hl)              ; column
        inc     hl
        ld      b,(hl)              ; rows
        inc     hl
        push    hl
        call    rowaddr
        ld      a,l
        or      e
        ld      l,a
        ld      de,26
.row:   ld      (hl),$AA
        inc     l
        ld      (hl),$AA
        inc     l
        ld      (hl),$AA
        inc     l
        ld      (hl),$AA
        inc     l
        ld      (hl),$AA
        inc     l
        ld      (hl),$AA
        add     hl,de
        inc     hl
        djnz    .row
        pop     hl
        jr      .r

hud_regions:    ; first row, column, rows (6 bytes wide)
        db      0,0,5, 0,26,5, 52,0,12, 52,26,12, 255
hud_src:        ; what the corners show
        dw      score, score+1, score+2, HISC, HISC+1, HISC+2, lives, pips
        dw      pips_max, wave, sector, ptwin, bonus_rnd, boss_on
HUDSIG  equ 14

; dir2ang: pad (R1 L2 U4 D8) -> orbit angle, 255 = none
dir2ang:
        db      255,0,128,255,192,224,160,255,64,32,96,255,255,255,255,255

; ---------------------------------------------------------------------
; demo_ai: the attract-mode pilot
; ---------------------------------------------------------------------
demo_ai:
        ld      a,1
        ld      (ai_fire),a
        xor     a
        ld      (ai_has),a
        ; dodge the nearest incoming shot
        ld      iy,ESHOT
        ld      b,NES
.s:     ld      a,(iy+0)
        cp      30
        jr      c,.sn
        ld      a,(iy+2)
        ld      c,a
        ld      a,(pa+1)
        sub     c
        ld      c,a
        bit     7,a
        jr      z,.sp
        neg
.sp:    cp      14
        jr      nc,.sn
        ld      a,c
        bit     7,a
        ld      a,48
        jr      z,.dg
        ld      a,-48
.dg:    ld      c,a
        ld      a,(pa+1)
        add     a,c
        jr      .set
.sn:    ld      de,6
        add     iy,de
        djnz    .s
        ; otherwise line up on the nearest enemy
        ld      ix,ENEMY
        ld      b,MAXE
        ld      c,0                 ; best radius so far
        ld      d,0
.e:     ld      a,(ix+E_TYPE)
        or      a
        jr      z,.en
        ld      a,(ix+E_ST)
        cp      S_PATH
        jr      c,.en
        cp      S_BOOM
        jr      z,.en
        ld      a,(ix+E_R)
        cp      c
        jr      c,.en
        ld      c,a
        ld      a,(ix+E_A)
        ld      (ai_tgt),a
        ld      a,1
        ld      (ai_has),a
.en:    ld      de,E_SIZE
        add     ix,de
        djnz    .e
        ret
.set:   ld      (ai_tgt),a
        ld      a,1
        ld      (ai_has),a
        ret
