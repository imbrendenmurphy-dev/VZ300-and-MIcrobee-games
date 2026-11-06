; =====================================================================
;  ROBOGEDDON - gameplay
; =====================================================================

; object types
T_DROID equ 1
T_PYLON equ 2
T_CRUSH equ 3
T_ORB   equ 4
T_FACT  equ 5
T_SEEK  equ 6
T_BRAIN equ 7
T_MUT   equ 8
T_TANK  equ 9
T_MOM   equ 10
T_DAD   equ 11
T_KID   equ 12
T_SKULL equ 13
T_POP   equ 14
T_PICK  equ 15
T_EXPL  equ 16

; tinfo flags
F_SHOOT equ 1
F_COUNT equ 2
F_DEADLY equ 4
F_HUMAN equ 8
F_BIG   equ 16
F_MOVER equ 32

; game states
GS_MAT  equ 1
GS_PLAY equ 2
GS_DYING equ 3
GS_CLEAR equ 4
GS_OVER equ 5
GS_EXIT equ 6

; arena limits
AX0     equ 2
AX1     equ 126                 ; first x outside
AY0     equ 9
AY1     equ 63                  ; first y outside

; ---------------------------------------------------------------------
; new_game / play_game
; ---------------------------------------------------------------------
new_game:
        xor     a
        ld      (score),a
        ld      (score+1),a
        ld      (score+2),a
        ld      (next_life+2),a
        ld      a,$02
        ld      (next_life),a
        ld      a,$50
        ld      (next_life+1),a     ; 025000
        ld      a,3
        ld      (lives),a
        ld      a,1
        ld      (wave),a
        ret

play_game:
        call    stop_music
        xor     a                   ; the key that started the game
        ld      (keysnew),a         ; mustn't also pause it
        ld      (mnunew),a
        call    start_wave
.loop:  ; system keys
        ld      a,(demo)
        or      a
        jr      z,.nd
        ld      a,(mnunew)
        ld      b,a
        ld      a,(keysnew)
        or      b
        jr      z,.dt
        ld      a,1
        ld      (demo_quit),a
        ld      a,GS_EXIT
        ld      (gstate),a
        ret
.dt:    ld      hl,(scr_t)
        dec     hl
        ld      (scr_t),hl
        ld      a,h
        or      l
        jr      nz,.go
        ld      a,GS_EXIT
        ld      (gstate),a
        ret
.nd:    ld      a,(keysnew)
        bit     0,a
        call    nz,cycle_sound
        ld      a,(keysnew)
        bit     1,a
        jr      z,.go
        call    do_pause
        ld      a,(gstate)
        cp      GS_EXIT
        ret     z
.go:    call    player_update
        call    clear_arena
        call    draw_hud
        call    shots_update
        call    objs_update
        call    ebul_update
        call    player_draw
        call    overlay
        call    present
        call    state_step
        ld      a,(gstate)
        cp      GS_EXIT
        jr      nz,.loop
        ret

; cycle_sound: all -> effects only -> off
cycle_sound:
        ld      a,(snd_mode)
        inc     a
        cp      3
        jr      c,.s
        xor     a
.s:     ld      (snd_mode),a
        ret

; ---------------------------------------------------------------------
; do_pause: RETURN again resumes, Q quits
; ---------------------------------------------------------------------
do_pause:
        call    copy_front_to_back
        ld      c,27
        ld      b,16
        call    fill_band
        ld      hl,s_paused
        ld      c,30
        ld      a,$FF
        call    text3c
        ld      hl,s_pausq
        ld      c,36
        ld      a,$55
        call    text3c
        call    present
.w:     call    copy_front_to_back
        call    present
        ld      a,(keysnew)
        bit     0,a
        call    nz,cycle_sound
        ld      a,(keysnew)
        bit     1,a
        ret     nz
        bit     2,a
        jr      z,.w
        ld      a,GS_EXIT
        ld      (gstate),a
        ret

; copy_front_to_back: the picture on screen -> back buffer
copy_front_to_back:
        ld      a,(drawh)
        ld      d,a
        ld      e,0
        xor     $10                 ; $E8 <-> $F8
        ld      h,a
        ld      l,0
        ld      bc,2048
        ldir
        ret

; ---------------------------------------------------------------------
; start_wave: build the wave from the table
; ---------------------------------------------------------------------
start_wave:
        ; clear objects, bullets, shots
        ld      hl,OBJ
        ld      de,OBJ+1
        ld      bc,MAXOBJ*8+NEBUL*8+NSHOT*8-1
        ld      (hl),0
        ldir
        xor     a
        ld      (kills_left),a
        ld      (rescue_n),a
        ld      (fam_total),a
        ld      (fam_saved),a
        ld      (fam_lost),a
        ld      (pshield),a
        ld      (ptriple),a
        ld      (nshots),a
        ld      (nebul),a
        ld      (droid_acc),a
        ; table row: (wave-1) mod 20, level = (wave-1)/20
        ld      a,(wave)
        dec     a
        ld      b,0
.md:    cp      20
        jr      c,.mo
        sub     20
        inc     b
        jr      .md
.mo:    ld      c,a
        ld      a,b
        ld      (wave_lvl),a
        ld      a,c
        ld      l,a
        ld      h,0
        add     hl,hl
        ld      e,l
        ld      d,h
        add     hl,hl
        add     hl,hl
        add     hl,de               ; *10
        ld      de,wavetab
        add     hl,de
        ld      de,wrow
        ld      bc,10
        ldir
        ; easing in: stage 3 = waves 1-2 (about half speed), 2 = waves 3-5
        ; (30% slower), 1 = waves 6-10 (25% slower), 0 = full speed
        ld      a,(wave)
        ld      b,3
        cp      3
        jr      c,.ez
        dec     b
        cp      6
        jr      c,.ez
        dec     b
        cp      11
        jr      c,.ez
        dec     b
.ez:    ld      a,b
        ld      (easy),a
        add     a,a
        add     a,a
        add     a,a                 ; 8 settings per stage
        ld      e,a
        ld      d,0
        ld      hl,ease_tab
        add     hl,de
        ld      de,ez_skip
        ld      bc,8
        ldir
        ld      a,(ez_min)
        ld      (droid_min),a
        ld      a,(ez_box)          ; safe box: x 42-10e..82+10e, y 22-5e..47+5e
        ld      b,a
        add     a,a
        add     a,a
        add     a,b                 ; 5e
        ld      c,a
        add     a,a                 ; 10e
        ld      b,a
        add     a,82
        ld      (safe_box),a
        ld      a,42
        sub     b
        ld      (safe_box+1),a
        ld      a,47
        add     a,c
        ld      (safe_box+2),a
        ld      a,22
        sub     c
        ld      (safe_box+3),a
        ; droid speed: frames between steps
        ld      a,(wrow+9)
        ld      b,a
        ld      a,(ez_dadd)
        add     a,b
        ld      b,a
        ld      a,(wave_lvl)
        neg
        add     a,b
        cp      2
        jr      nc,.sp
        ld      a,2
.sp:    ld      (droid_spd),a
        ; spawn: types in table order
        ld      hl,wrow
        ld      de,spawn_types
        ld      b,9
.ty:    push    bc
        ld      a,(hl)
        inc     hl
        push    hl
        ld      c,a
        ld      a,(de)
        inc     de
        push    de
        ld      b,a
        inc     c
        dec     c
        jr      z,.nx
.sp1:   push    bc
        ld      a,b
        call    spawn_obj
        pop     bc
        dec     c
        jr      nz,.sp1
.nx:    pop     de
        pop     hl
        pop     bc
        djnz    .ty
        ; player
        call    player_centre
        ; looks: blue arena, green dithered edge
        ld      a,MODE1
        ld      (next_vmode),a
        xor     a
        ld      (flash_t),a
        call    build_dither
        ld      hl,375
        ld      (pick_t),hl
        ld      a,2
        ld      (hud_dirty),a
begin_mat:
        ld      a,GS_MAT
        ld      (gstate),a
        ld      a,27
        ld      (mat_t),a
        ld      a,9
        ld      (mat_k),a
        xor     a
        ld      (logic_on),a
        ld      a,SFX_MAT
        jp      play_sfx

player_centre:
        ld      a,62
        ld      (px),a
        ld      a,33
        ld      (py),a
        xor     a
        ld      (pxf),a
        ld      (pyf),a
        ld      (pfirecd),a
        ld      a,4
        ld      (pdir),a
        ld      a,1
        ld      (palive),a
        ret

; ---------------------------------------------------------------------
; spawn_obj: A = type.  random position away from the centre.
;   -> IY = the new object (Z if no room)
; ---------------------------------------------------------------------
spawn_obj:
        ld      c,a
        call    free_slot
        ret     z
        ld      (iy+0),c
        ld      a,c
        call    tinfo_ptr
        ld      a,(hl)              ; w
        ld      (tmp1),a
        inc     hl
        ld      a,(hl)              ; h
        ld      (tmp2),a
        inc     hl
        ld      a,(hl)
        and     F_COUNT
        jr      z,.nc
        ld      hl,kills_left
        inc     (hl)
.nc:    ld      a,c
        cp      T_MOM
        jr      c,.pos
        cp      T_SKULL
        jr      nc,.pos
        ld      hl,fam_total
        inc     (hl)
.pos:   ; x = AX0 + rnd(AX1-AX0-w), y = AY0 + rnd(AY1-AY0-h)
        ld      a,(tmp1)
        ld      b,a
        ld      a,AX1-AX0
        sub     b
        call    rnd_n
        add     a,AX0
        ld      (iy+1),a
        ld      a,(tmp2)
        ld      b,a
        ld      a,AY1-AY0
        sub     b
        call    rnd_n
        add     a,AY0
        ld      (iy+2),a
        ; keep clear of a box round the player (bigger on the first waves)
        ld      hl,safe_box
        ld      a,(iy+1)
        cp      (hl)                ; x1
        jr      nc,.ok
        inc     hl
        cp      (hl)                ; x0
        jr      c,.ok
        inc     hl
        ld      a,(iy+2)
        cp      (hl)                ; y1
        jr      nc,.ok
        inc     hl
        cp      (hl)                ; y0
        jr      nc,.pos
.ok:    ; default fields
        ld      a,8
        call    rnd_n
        inc     a
        ld      (iy+3),a
        xor     a
        ld      (iy+4),a
        ld      (iy+5),a
        call    rnd
        ld      (iy+6),a
        ld      (iy+7),$FF
        ld      a,c
        cp      T_ORB
        jr      z,.orb
        cp      T_FACT
        jr      z,.orb
        cp      T_SEEK
        ret     nz
.orb:   call    rnd_vel
        ld      a,50
        call    rnd_n
        add     a,30
        ld      b,a
        ld      a,(ez_seek)         ; seekers hold their fire longer early on
        add     a,b
        ld      (iy+3),a
        ld      (iy+7),0            ; children spawned
        or      1                   ; NZ
        ret

; rnd_vel: IY object gets dx -2..2 (not 0), dy -1..1
rnd_vel:
        ld      a,4
        call    rnd_n
        sub     2
        jr      nz,.x
        inc     a
.x:     ld      (iy+4),a
        ld      a,3
        call    rnd_n
        dec     a
        ld      (iy+5),a
        ret

; free_slot -> IY = free object (NZ), or Z if full
free_slot:
        ld      iy,OBJ
        ld      de,8
        ld      b,MAXOBJ
.l:     ld      a,(iy+0)
        or      a
        jr      z,.f
        add     iy,de
        djnz    .l
        xor     a
        ret
.f:     or      1
        ret

; tinfo_ptr: A = type -> HL = tinfo entry (w,h,flags,scoreLo,scoreHi)
tinfo_ptr:
        ld      l,a
        ld      h,0
        ld      e,l
        ld      d,h
        add     hl,hl
        add     hl,hl
        add     hl,de
        ld      de,tinfo-5
        add     hl,de
        ret

; ---------------------------------------------------------------------
; state_step: per-frame state machine
; ---------------------------------------------------------------------
state_step:
        ld      a,(flash_t)
        or      a
        jr      z,.nf
        dec     a
        ld      (flash_t),a
        ld      a,2
        ld      (hud_dirty),a
        ld      a,(flash_t)
        or      a
        jr      z,.f0               ; done: back to green
        ld      a,(gtick)
        and     3
        ld      e,a
        ld      d,0
        ld      hl,flash_cols
        add     hl,de
        ld      a,(hl)
.f0:    call    build_dither
.nf:    ld      a,(gstate)
        cp      GS_MAT
        jr      z,.mat
        cp      GS_PLAY
        jr      z,.play
        cp      GS_DYING
        jp      z,.dying
        cp      GS_CLEAR
        jp      z,.clear
        cp      GS_OVER
        jp      z,.over
        ret
.mat:   ld      a,(mat_t)
        dec     a
        ld      (mat_t),a
        ld      b,0
.m3:    sub     3
        jr      c,.m4
        inc     b
        jr      .m3
.m4:    ld      a,b
        ld      (mat_k),a
        ld      a,(mat_t)
        or      a
        ret     nz
        ld      a,GS_PLAY
        ld      (gstate),a
        ld      a,1
        ld      (logic_on),a
        ret
.play:  ; wave cleared?
        ld      a,(kills_left)
        or      a
        jr      nz,.p1
        ld      a,GS_CLEAR
        ld      (gstate),a
        xor     a
        ld      (logic_on),a
        ld      hl,75
        ld      (gtimer),hl
        ; full family bonus
        ld      a,(fam_lost)
        or      a
        jr      nz,.nb
        ld      a,(fam_saved)
        or      a
        jr      z,.nb
        ld      de,$5000
        call    add_score
.nb:    ld      a,(demo)
        or      a
        ret     nz
        ld      hl,mus_wavedone
        xor     a
        call    start_music
        ret
.p1:    ; droids speed up every 4 s (longer in the early waves)
        ld      a,(ez_accel)
        ld      b,a
        ld      hl,droid_acc
        inc     (hl)
        ld      a,(hl)
        cp      b
        jr      c,.p2
        ld      (hl),0
        ld      a,(droid_min)
        ld      b,a
        ld      a,(droid_spd)
        cp      b
        jr      z,.p2
        jr      c,.p2
        dec     a
        ld      (droid_spd),a
.p2:    ; pickups
        ld      a,(wave)
        cp      2
        ret     c
        ld      hl,(pick_t)
        dec     hl
        ld      (pick_t),hl
        ld      a,h
        or      l
        ret     nz
        ld      hl,600
        ld      (pick_t),hl
        ld      a,T_PICK
        call    spawn_obj
        ret     z
        ld      (iy+3),250
        ld      a,2
        call    rnd_n
        ld      (iy+7),a
        ret
.dying: ld      hl,(gtimer)
        dec     hl
        ld      (gtimer),hl
        ld      a,h
        or      l
        ret     nz
        ld      a,(demo)
        or      a
        jr      z,.dy1
        ld      a,GS_EXIT
        ld      (gstate),a
        ret
.dy1:   ld      a,(trainer)
        or      a
        jr      nz,.dy2
        ld      a,(lives)
        dec     a
        ld      (lives),a
        ld      a,2
        ld      (hud_dirty),a
        ld      a,(lives)
        or      a
        jr      nz,.dy2
        ld      a,GS_OVER
        ld      (gstate),a
        ld      hl,90
        ld      (gtimer),hl
        ld      hl,mus_gameover
        xor     a
        jp      start_music
.dy2:   call    regroup
        call    player_centre
        jp      begin_mat
.clear: ld      hl,(gtimer)
        dec     hl
        ld      (gtimer),hl
        ld      a,h
        or      l
        ret     nz
        ld      a,(wave)
        cp      99
        jr      nc,.cl2
        inc     a
        ld      (wave),a
.cl2:   jp      start_wave
.over:  ld      hl,(gtimer)
        dec     hl
        ld      (gtimer),hl
        ld      a,h
        or      l
        ret     nz
        ld      a,GS_EXIT
        ld      (gstate),a
        ret

; regroup: after a death, robots scatter back to the edges, debris cleared
regroup:
        ld      hl,EBUL
        ld      de,EBUL+1
        ld      bc,NEBUL*8+NSHOT*8-1
        ld      (hl),0
        ldir
        xor     a
        ld      (nshots),a
        ld      (nebul),a
        ld      (pshield),a
        ld      (ptriple),a
        ld      ix,OBJ
        ld      b,MAXOBJ
.l:     push    bc
        ld      a,(ix+0)
        or      a
        jr      z,.n
        cp      T_EXPL
        jr      z,.kill
        cp      T_POP
        jr      z,.kill
        cp      T_PICK
        jr      z,.kill
        call    tinfo_ptr
        inc     hl
        inc     hl
        ld      a,(hl)
        and     F_MOVER
        jr      z,.n
        ; re-place it
        ld      a,(ix+0)
        push    ix
        pop     iy
        ld      (ix+0),0
        ld      c,a
        ; spawn_obj picks a free slot: this one is free now (or an earlier one)
        call    tinfo_ptr
        inc     hl
        inc     hl
        ld      a,(hl)
        and     F_COUNT
        jr      z,.nc
        ld      hl,kills_left
        dec     (hl)                ; spawn_obj counts it again
.nc:    ld      a,c
        call    spawn_obj
        jr      .n
.kill:  ld      (ix+0),0
.n:     ld      de,8
        add     ix,de
        pop     bc
        djnz    .l
        ret

; ---------------------------------------------------------------------
; overlay: big messages for the current state
; ---------------------------------------------------------------------
overlay:
        ld      a,(gstate)
        cp      GS_MAT
        jr      z,.mat
        cp      GS_CLEAR
        jr      z,.clr
        cp      GS_OVER
        jp      z,.ovr
        ret
.mat:   ld      a,(demo)
        or      a
        ret     nz
        ld      hl,s_wave
        ld      de,txtbuf
        call    strcpy
        ld      a,(wave)
        call    byte_to_str
        call    strcpy
        ld      hl,txtbuf
        ld      c,13
        ld      a,(gtick)
        and     2
        ld      a,$FF
        jr      z,.m1
        ld      a,$55
.m1:    call    text2xc
        ; subtitle: what this wave is about
        ld      hl,s_sub_first
        ld      a,(wave)
        cp      1
        jr      z,.sub
        ld      hl,s_sub_crush
        ld      a,(wrow+2)
        cp      10
        jr      nc,.sub
        ld      hl,s_sub_brain
        ld      a,(wrow+3)
        or      a
        jr      nz,.sub
        ld      hl,s_sub_tank
        ld      a,(wrow+5)
        or      a
        jr      nz,.sub
        ld      hl,s_sub_orb
        ld      a,(wrow+4)
        or      a
        jr      nz,.sub
        ld      hl,s_sub_droid
.sub:   ld      c,26
        xor     a                   ; green
        jp      text3c
.clr:   call    clear_arena
        ld      hl,s_wave
        ld      de,txtbuf
        call    strcpy
        ld      a,(wave)
        call    byte_to_str
        call    strcpy
        ld      hl,s_cleared
        call    strcpy
        ld      hl,txtbuf
        ld      c,18
        ld      a,$55
        call    text2xc
        ld      hl,s_saved
        ld      de,txtbuf
        call    strcpy
        ld      a,(fam_saved)
        call    byte_to_str
        call    strcpy
        ld      hl,txtbuf
        ld      c,34
        ld      a,0                 ; green
        call    text3c
        ld      a,(fam_lost)
        or      a
        ret     nz
        ld      a,(fam_saved)
        or      a
        ret     z
        ld      a,(gtick)
        and     4
        ret     z
        ld      hl,s_bonus
        ld      c,42
        xor     a
        jp      text3c
.ovr:   ld      c,23
        ld      b,16
        call    fill_band
        ld      hl,s_gameover
        ld      c,26
        ld      a,(gtick)
        and     4
        ld      a,$FF
        jr      z,.o1
        ld      a,$55
.o1:    jp      text2xc

; strcpy: HL = source (0 end) -> DE (0 written, DE left on the 0)
strcpy:
        ld      a,(hl)
        ld      (de),a
        or      a
        ret     z
        inc     hl
        inc     de
        jr      strcpy

; ---------------------------------------------------------------------
; HUD: the 50:50 green/blue edge line (row 0), scores (rows 1-5), a
; dithered divider (row 7) and the bottom edge line (row 63).  Drawn only when it
; changes, into both buffers.
; ---------------------------------------------------------------------
draw_hud:
        ld      a,(hud_dirty)
        or      a
        ret     z
        dec     a
        ld      (hud_dirty),a
        ld      c,0
        ld      b,1
        ld      a,(dith_top)
        call    fill_rows
        ld      c,1
        ld      b,6
        ld      a,$AA
        call    fill_rows
        ld      c,1
        ld      b,6
        call    put_sides
        ld      c,7
        ld      b,1
        ld      a,(dith_div)
        call    fill_rows
        ld      c,63
        ld      b,1
        ld      a,(dith_bot)
        call    fill_rows
        ; score
        ld      hl,score
        call    bcd_to_str
        ld      b,1
        ld      c,1
        ld      a,$55
        call    text3
        ; wave
        ld      hl,s_w
        ld      b,9
        ld      c,1
        xor     a
        call    text3
        ld      a,(wave)
        call    byte_to_str
        ld      b,10
        ld      c,1
        xor     a
        call    text3
        ; high score or DEMO
        ld      a,(demo)
        or      a
        jr      z,.hi
        ld      hl,s_demo
        ld      b,15
        ld      c,1
        xor     a
        call    text3
        jr      .lv
.hi:    ld      hl,s_hi
        ld      b,14
        ld      c,1
        xor     a
        call    text3
        ld      hl,HISC
        call    bcd_to_str
        ld      b,17
        ld      c,1
        ld      a,$55
        call    text3
.lv:    ; lives or trainer
        ld      a,(trainer)
        or      a
        jr      z,.l1
        ld      hl,s_trn
        ld      b,24
        ld      c,1
        ld      a,$55
        jp      text3
.l1:    ld      a,(lives)
        or      a
        ret     z
        dec     a
        ret     z                   ; the man in play is not shown
        cp      6
        jr      c,.l2
        ld      a,6
.l2:    ld      b,a
        ld      hl,txtbuf
.l3:    ld      (hl),92             ; little man
        inc     hl
        djnz    .l3
        ld      (hl),0
        ld      hl,txtbuf
        call    strlen
        ld      a,31
        sub     b
        ld      b,a
        ld      c,1
        ld      a,$55
        jp      text3


; ---------------------------------------------------------------------
; player
; ---------------------------------------------------------------------
player_update:
        ld      a,(gstate)
        cp      GS_PLAY
        ret     nz
        ld      a,(pshield)
        or      a
        jr      z,.t1
        dec     a
        ld      (pshield),a
.t1:    ld      a,(ptriple)
        or      a
        jr      z,.t2
        dec     a
        ld      (ptriple),a
.t2:    ld      a,(pfirecd)
        or      a
        jr      z,.t3
        dec     a
        ld      (pfirecd),a
.t3:    ; ---- gather control bits
        ld      a,(demo)
        or      a
        jr      z,.human
        call    ai_think
        ld      a,(ai_move)
        ld      (moveb),a
        ld      a,(ai_fire)
        ld      (fireb),a
        jr      .dirs
.human: ld      a,(joy1)
        ld      b,a
        ld      a,(kmove)
        or      b
        ld      (moveb),a
        ld      a,(ctl_mode)
        cp      1
        jr      z,.one
        ld      a,(joy2)
        ld      b,a
        ld      a,(kfire)
        or      b
        ld      (fireb),a
        jr      .dirs
.one:   ; one stick: hold fire (or SPACE) to shoot the way you face; facing locks
        ld      a,(jfire)
        ld      b,a
        ld      a,(keys)
        and     $80
        or      b
        jr      z,.nofire
        ld      a,(pdir)
        call    dir_to_bits
        ld      (fireb),a
        ld      a,1
        ld      (firing),a
        jr      .move
.nofire:
        xor     a
        ld      (fireb),a
        ld      (firing),a
.dirs:  xor     a
        ld      (firing),a
.move:  ; ---- movement
        ld      a,(moveb)
        and     15
        ld      e,a
        ld      d,0
        ld      hl,dirtab
        add     hl,de
        ld      a,(hl)
        cp      $FF
        jr      z,.still
        ld      c,a
        ld      a,(firing)
        or      a
        jr      nz,.nf
        ld      a,c
        ld      (pdir),a
.nf:    ld      hl,panim
        inc     (hl)
        ld      a,c
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,pmvx
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      hl,(pxf)
        add     hl,de
        ld      a,h
        cp      AX0
        jr      c,.ny
        cp      AX1-5+1
        jr      nc,.ny
        ld      (pxf),hl
.ny:    ld      a,c
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,pmvy
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      hl,(pyf)
        add     hl,de
        ld      a,h
        cp      AY0
        jr      c,.still
        cp      AY1-6+1
        jr      nc,.still
        ld      (pyf),hl
.still: ; ---- firing
        ld      a,(fireb)
        and     15
        ld      e,a
        ld      d,0
        ld      hl,dirtab
        add     hl,de
        ld      a,(hl)
        cp      $FF
        ret     z
        ld      (fdir),a
        ld      c,a
        ld      a,(moveb)
        and     15
        jr      nz,.fm
        ld      a,c                 ; standing still: face the way you shoot
        ld      (pdir),a
.fm:    ld      a,(pfirecd)
        or      a
        ret     nz
        ld      a,2
        ld      (pfirecd),a
        ld      a,(fdir)
        call    fire_shot
        ld      a,(ptriple)
        or      a
        jr      z,.snd
        ld      a,(fdir)
        dec     a
        and     7
        call    fire_shot
        ld      a,(fdir)
        inc     a
        and     7
        call    fire_shot
.snd:   ld      a,SFX_SHOT
        jp      play_sfx

; dir_to_bits: A = dir -> pad bits
dir_to_bits:
        ld      e,a
        ld      d,0
        ld      hl,dirbits
        add     hl,de
        ld      a,(hl)
        ret

; fire_shot: A = dir
fire_shot:
        ld      c,a
        ld      iy,SHOTS
        ld      de,8
        ld      b,NSHOT
.l:     ld      a,(iy+0)
        or      a
        jr      z,.f
        add     iy,de
        djnz    .l
        ret
.f:     ld      (iy+0),1
        ld      a,(px)
        add     a,2
        ld      (iy+1),a
        ld      a,(py)
        add     a,2
        ld      (iy+2),a
        ld      e,c
        ld      d,0
        ld      hl,sdx
        add     hl,de
        ld      a,(hl)
        ld      (iy+3),a
        ld      hl,sdy
        add     hl,de
        ld      a,(hl)
        ld      (iy+4),a
        ld      hl,nshots
        inc     (hl)
        ret

player_draw:
        ld      a,(gstate)
        cp      GS_DYING
        jr      z,.die
        cp      GS_OVER
        ret     z
        cp      GS_CLEAR
        ret     z
        ld      a,(palive)
        or      a
        ret     z
        ld      a,(pshield)
        or      a
        jr      z,.vis
        cp      40
        jr      nc,.ring
        ld      a,(gtick)           ; running out: the ring flickers
        and     2
        jr      z,.vis
.ring:  ld      a,(px)
        sub     2
        ld      b,a
        ld      a,(py)
        sub     2
        ld      c,a
        ld      a,(px)
        add     a,6
        ld      d,a
        ld      a,(py)
        add     a,7
        cp      AY1
        jr      c,.r1
        ld      a,AY1-1
.r1:    ld      e,a
        ld      a,(gtick)
        and     3
        add     a,low ring_cols
        ld      l,a
        ld      h,high ring_cols
        ld      a,(hl)
        call    rect
.vis:   call    player_frame
        ld      a,(px)
        ld      b,a
        ld      a,(py)
        ld      c,a
        ld      a,e
        jp      draw_frame_g
.die:   ; shatter
        ld      hl,(gtimer)
        ld      a,40
        sub     l
        jr      nc,.d1
        xor     a
.d1:    srl     a
        srl     a
        ld      d,a
        call    player_frame
        ld      a,(px)
        ld      b,a
        ld      a,(py)
        ld      c,a
        ld      a,e
        jp      draw_spread_g

; player_frame -> E = frame number (D kept)
player_frame:
        ld      a,(panim)
        rra
        and     1
        ld      e,a
        ld      a,(pdir)
        or      a
        jr      z,.up
        cp      4
        jr      z,.dn
        jr      c,.rt
        ld      a,F_PL_L0
        jr      .s
.up:    ld      a,F_PL_U0
        jr      .s
.dn:    ld      a,F_PL_D0
        jr      .s
.rt:    ld      a,F_PL_R0
.s:     add     a,e
        ld      e,a
        ret

; kill_player
kill_player:
        ld      a,(palive)
        or      a
        ret     z
        xor     a
        ld      (palive),a
        ld      (logic_on),a
        ld      a,GS_DYING
        ld      (gstate),a
        ld      hl,44
        ld      (gtimer),hl
        ld      a,SFX_DIE
        jp      play_sfx

; ---------------------------------------------------------------------
; player shots
; ---------------------------------------------------------------------
shots_update:
        ld      a,(nshots)
        or      a
        ret     z
        ld      ix,SHOTS
        ld      b,NSHOT
.l:     push    bc
        ld      a,(ix+0)
        or      a
        jr      z,.n
        ld      a,(logic_on)
        or      a
        jr      z,.dr
        ld      a,(ix+1)
        add     a,(ix+3)
        ld      (ix+1),a
        cp      AX0
        jr      c,.off
        cp      AX1
        jr      nc,.off
        ld      a,(ix+2)
        add     a,(ix+4)
        ld      (ix+2),a
        cp      AY0
        jr      c,.off
        cp      AY1
        jr      nc,.off
.dr:    ; three pixels back along the direction
        ld      b,(ix+1)
        ld      c,(ix+2)
        ld      a,1
        call    plot
        call    .back
        ld      a,1
        call    plot
        call    .back
        ld      a,3
        call    plot
        jr      .n
.off:   ld      (ix+0),0
        ld      hl,nshots
        dec     (hl)
.n:     ld      de,8
        add     ix,de
        pop     bc
        djnz    .l
        ret
.back:  ; step B,C one pixel against the shot's direction (stay in arena)
        ld      a,(ix+3)
        or      a
        jr      z,.by
        jp      m,.bxp
        dec     b
        jr      .by
.bxp:   inc     b
.by:    ld      a,(ix+4)
        or      a
        ret     z
        jp      m,.byp
        dec     c
        ret
.byp:   inc     c
        ret

; ---------------------------------------------------------------------
; objects
; ---------------------------------------------------------------------
objs_update:
        ld      ix,OBJ
        ld      b,MAXOBJ
.l:     ld      a,(ix+0)
        or      a
        jr      z,.n
        push    bc
        add     a,a
        ld      l,a
        ld      h,0
        ld      de,upd_tab-2
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        call    jp_hl
        pop     bc
.n:     ld      de,8
        add     ix,de
        djnz    .l
        ret
jp_hl:  jp      (hl)

upd_tab:
        dw      upd_droid, upd_pylon, upd_crush, upd_orb, upd_orb
        dw      upd_seek, upd_brain, upd_mut, upd_tank
        dw      upd_human, upd_human, upd_human
        dw      upd_skull, upd_pop, upd_pick, upd_expl

; ---- common: A = frame, DE = (h<<8)|w : shots, touching, drawing
std_enemy:
        ld      (cur_frame),a
        ld      (cur_wh),de
        ld      a,(logic_on)
        or      a
        jr      z,obj_draw
        call    shot_hit
        jp      c,kill_obj
        call    touch_player
        jr      nc,obj_draw
        ld      a,(pshield)
        or      a
        jp      nz,kill_obj
        call    kill_player
obj_draw:
        ld      b,(ix+1)
        ld      c,(ix+2)
        ld      a,(mat_k)
        or      a
        jr      nz,.sp
        ld      a,(cur_frame)
        jp      draw_frame_g
.sp:    ld      d,a
        ld      a,(cur_frame)
        jp      draw_spread_g

; kill_obj: score, count, turn into a shattering explosion
kill_obj:
        ld      a,(ix+0)
        call    tinfo_ptr
        inc     hl
        inc     hl
        ld      a,(hl)
        ld      (tmp1),a
        and     F_COUNT
        jr      z,.nc
        push    hl
        ld      hl,kills_left
        dec     (hl)
        pop     hl
.nc:    inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        call    add_score
        ld      (ix+0),T_EXPL
        ld      a,(cur_frame)
        ld      (ix+6),a
        ld      (ix+3),0
        ld      a,(tmp1)
        and     F_BIG
        ld      a,SFX_KILL
        jr      z,.s
        ld      a,SFX_BIGKILL
.s:     call    play_sfx
        jp      obj_draw

; touch_player: object box (ix+1,ix+2,cur_wh) vs the player -> C if touching
touch_player:
        ld      a,(palive)
        or      a
        ret     z
        ld      a,(px)
        add     a,3
        cp      (ix+1)
        jr      c,.no
        ld      a,(cur_wh)
        add     a,(ix+1)
        sub     2
        ld      hl,px
        cp      (hl)
        jr      c,.no
        ld      a,(py)
        add     a,4
        cp      (ix+2)
        jr      c,.no
        ld      a,(cur_wh+1)
        add     a,(ix+2)
        sub     2
        ld      hl,py
        cp      (hl)
        jr      c,.no
        scf
        ret
.no:    xor     a
        ret

; shot_hit: any player shot inside the object box (+2 margin)?  C = hit
shot_hit:
        ld      a,(nshots)
        or      a
        ret     z
        ld      iy,SHOTS
        ld      b,NSHOT
.l:     ld      a,(iy+0)
        or      a
        jr      z,.n
        ld      a,(iy+1)
        add     a,2
        cp      (ix+1)
        jr      c,.n
        ld      a,(cur_wh)
        add     a,(ix+1)
        inc     a
        cp      (iy+1)
        jr      c,.n
        ld      a,(iy+2)
        add     a,2
        cp      (ix+2)
        jr      c,.n
        ld      a,(cur_wh+1)
        add     a,(ix+2)
        inc     a
        cp      (iy+2)
        jr      c,.n
        ld      (iy+0),0
        ld      hl,nshots
        dec     (hl)
        ld      a,(iy+3)
        ld      (hit_dx),a
        ld      a,(iy+4)
        ld      (hit_dy),a
        scf
        ret
.n:     ld      de,8
        add     iy,de
        djnz    .l
        or      a
        ret

; ---- movement helpers ------------------------------------------------
; sgn_to: A = target, B = current -> A = -1/0/+1
sgn_to:
        cp      b
        jr      z,.z
        ld      a,1
        ret     nc
        ld      a,$FF
        ret
.z:     xor     a
        ret

; move_obj: add D to x and E to y if the result stays in the arena for
;   an object of size cur_wh.  -> C if blocked on x, and bit in tmp2
move_obj:
        xor     a
        ld      (tmp2),a
        ld      a,(ix+1)
        add     a,d
        cp      AX0
        jr      c,.bx
        ld      b,a
        ld      a,(cur_wh)
        add     a,b
        cp      AX1+1
        jr      nc,.bx
        ld      (ix+1),b
        jr      .y
.bx:    ld      hl,tmp2
        set     0,(hl)
.y:     ld      a,(ix+2)
        add     a,e
        cp      AY0
        jr      c,.by
        ld      b,a
        ld      a,(cur_wh+1)
        add     a,b
        cp      AY1+1
        jr      nc,.by
        ld      (ix+2),b
        ret
.by:    ld      hl,tmp2
        set     1,(hl)
        ret

; toward_player: D = x step (0..2), E = y step -> moves (ix) toward the player
toward_player:
        ld      a,(px)
        ld      c,a
        ld      a,(py)
        ld      l,a
toward_xy:              ; C = target x, L = target y
        push    de
        ld      b,(ix+1)
        ld      a,c
        call    sgn_to
        pop     de
        push    de
        call    mul_sgn
        ld      h,a                 ; x delta
        ld      b,(ix+2)
        ld      a,l
        call    sgn_to
        pop     de
        ld      d,e
        call    mul_sgn
        ld      e,a
        ld      d,h
        jp      move_obj

; mul_sgn: A = -1/0/1, D = magnitude -> A = signed
mul_sgn:
        or      a
        ret     z
        jp      m,.n
        ld      a,d
        ret
.n:     xor     a
        sub     d
        ret

; ease_skip: NZ = sit this frame out (ez_skip frames in every 16).
;   keeps BC, DE, HL
ease_skip:
        ld      a,(ez_skip)
        or      a
        ret     z
        push    bc
        ld      b,a
        ld      a,(gtick)
        and     15
        cp      b                   ; C if (gtick & 15) < frames to skip
        pop     bc
        sbc     a,a                 ; $FF (NZ) if so
        ret

; ---- DROID -----------------------------------------------------------
upd_droid:
        ld      a,(logic_on)
        or      a
        jr      z,.dr
        ld      de,$0505
        ld      (cur_wh),de
        dec     (ix+3)
        jr      nz,.dr
        ld      a,(droid_spd)
        ld      (ix+3),a
        ld      de,$0201
        call    rnd
        and     7
        jr      nz,.d1
        ld      d,0                 ; sometimes only shuffle up/down
.d1:    call    toward_player
        inc     (ix+6)
.dr:    ld      a,(ix+6)
        and     1
        add     a,F_GRUNT0
        ld      de,$0505
        jp      std_enemy

; ---- PYLON (electrode): static, colour and shape by wave -------------
upd_pylon:
        ld      a,(wave)
        dec     a
.m:     cp      9
        jr      c,.ok
        sub     9
        jr      .m
.ok:    add     a,F_ELEC0_1
        ld      de,$0505
        jp      std_enemy

; ---- CRUSHER (hulk): unstoppable, wanders, squashes humans -----------
upd_crush:
        ld      de,$0707
        ld      (cur_wh),de
        ld      a,(logic_on)
        or      a
        jp      z,.dr
        ; shots knock it back
        call    shot_hit
        jr      nc,.ns
        ld      a,(hit_dx)
        call    sgn8
        add     a,a
        ld      d,a
        ld      a,(hit_dy)
        call    sgn8
        ld      e,a
        call    move_obj
        ld      a,SFX_THUD
        call    play_sfx
.ns:    ; retarget now and then
        ld      a,(gtick)
        add     a,(ix+6)
        and     63
        call    z,pick_target
        dec     (ix+3)
        jr      nz,.chk
        ld      a,(ez_step)
        ld      (ix+3),a
        inc     (ix+6)
        call    rnd
        and     31
        call    z,crush_turn
        ld      a,(ix+4)
        or      (ix+5)
        call    z,crush_turn
        ld      d,(ix+4)
        ld      e,(ix+5)
        call    move_obj
        ld      a,(tmp2)
        or      a
        call    nz,crush_turn
.chk:   ; squash the target human
        ld      a,(ix+7)
        cp      $FF
        jr      z,.tp
        call    obj_addr
        ld      a,(hl)
        cp      T_MOM
        jr      c,.tp
        cp      T_SKULL
        jr      nc,.tp
        call    near_obj
        jr      nc,.tp
        ld      (hl),T_SKULL
        inc     hl
        inc     hl
        inc     hl
        ld      (hl),50
        ld      hl,fam_lost
        inc     (hl)
        ld      (ix+7),$FF
        ld      a,SFX_SKULL
        call    play_sfx
.tp:    call    touch_player
        jr      nc,.dr
        ld      a,(pshield)
        or      a
        call    z,kill_player
.dr:    ld      a,(ix+6)
        and     1
        add     a,F_HULK0
        ld      (cur_frame),a
        jp      obj_draw

; crush_turn: new direction: toward its target (or the player) half the time
crush_turn:
        call    rnd
        and     1
        jr      z,.rand
        call    target_xy           ; C,L
        ld      a,c
        sub     (ix+1)
        call    abs_a
        ld      h,a
        ld      a,l
        sub     (ix+2)
        call    abs_a
        add     a,a
        cp      h
        jr      c,.horz
        ld      b,(ix+2)
        ld      a,l
        call    sgn_to
        ld      (ix+5),a
        ld      (ix+4),0
        ret
.horz:  ld      b,(ix+1)
        ld      a,c
        call    sgn_to
        ld      (ix+4),a
        ld      (ix+5),0
        ret
.rand:  ld      a,4
        call    rnd_n
        ld      e,a
        ld      d,0
        ld      hl,card_dx
        add     hl,de
        ld      a,(hl)
        ld      (ix+4),a
        ld      hl,card_dy
        add     hl,de
        ld      a,(hl)
        ld      (ix+5),a
        ret

; target_xy: C,L = position of this object's target human, else the player
target_xy:
        ld      a,(ix+7)
        cp      $FF
        jr      z,.pl
        call    obj_addr
        ld      a,(hl)
        cp      T_MOM
        jr      c,.pl
        cp      T_SKULL
        jr      nc,.pl
        inc     hl
        ld      c,(hl)
        inc     hl
        ld      l,(hl)
        ret
.pl:    ld      a,(px)
        ld      c,a
        ld      a,(py)
        ld      l,a
        ret

; pick_target: nearest human -> (ix+7)
pick_target:
        ld      (ix+7),$FF
        ld      iy,OBJ
        ld      c,0                 ; index
        ld      e,$FF               ; best distance
        ld      b,MAXOBJ
.l:     ld      a,(iy+0)
        cp      T_MOM
        jr      c,.n
        cp      T_SKULL
        jr      nc,.n
        ld      a,(iy+1)
        sub     (ix+1)
        call    abs_a
        ld      d,a
        ld      a,(iy+2)
        sub     (ix+2)
        call    abs_a
        add     a,a
        jr      c,.n
        add     a,d
        jr      c,.n
        cp      e
        jr      nc,.n
        ld      e,a
        ld      (ix+7),c
.n:     inc     c
        push    de
        ld      de,8
        add     iy,de
        pop     de
        djnz    .l
        ret

; obj_addr: A = index -> HL = object
obj_addr:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,OBJ
        add     hl,de
        ret

; near_obj: HL = other object; is it overlapping this one (centres within 5,5)?
;   -> C if so (HL kept)
near_obj:
        push    hl
        inc     hl
        ld      a,(hl)
        sub     (ix+1)
        sub     1                   ; centres: other+2 vs this+3
        call    abs_a
        cp      5
        jr      nc,.no
        inc     hl
        ld      a,(hl)
        sub     (ix+2)
        call    abs_a
        cp      6
        jr      nc,.no
        pop     hl
        scf
        ret
.no:    pop     hl
        or      a
        ret

abs_a:  or      a
        ret     p
        neg
        ret

sgn8:   or      a
        ret     z
        ld      a,1
        ret     p
        ld      a,$FF
        ret

; ---- ORB / FACTORY: bounce around, give birth to seekers / tanks -----
upd_orb:
        ld      de,$0505
        ld      (cur_wh),de
        ld      a,(logic_on)
        or      a
        jp      z,.fr
        call    ease_skip
        jr      nz,.b2
        ld      d,(ix+4)
        ld      a,(gtick)
        and     1
        ld      e,(ix+5)
        jr      z,.m
        ld      e,0
.m:     call    move_obj
        ld      a,(tmp2)
        bit     0,a
        jr      z,.b1
        ld      a,(ix+4)
        neg
        ld      (ix+4),a
.b1:    bit     1,a
        jr      z,.b2
        ld      a,(ix+5)
        neg
        ld      (ix+5),a
.b2:    call    rnd
        and     63
        jr      nz,.nt
        push    ix
        pop     iy
        call    rnd_vel
.nt:    inc     (ix+6)
        dec     (ix+3)
        jp      nz,.fr
        ld      a,60
        call    rnd_n
        add     a,50
        ld      (ix+3),a
        ld      a,(ix+7)
        cp      3
        jp      nc,.fr
        inc     (ix+7)
        ld      a,(ix+0)
        cp      T_ORB
        ld      a,T_SEEK
        jr      z,.ch
        ld      a,T_TANK
.ch:    call    spawn_obj
        jp      z,.fr
        ld      a,(ix+1)
        ld      (iy+1),a
        ld      a,(ix+2)
        ld      (iy+2),a
        ld      a,(iy+0)
        cp      T_TANK
        jr      nz,.sk
        ld      a,(iy+2)            ; tanks are 7x6
        cp      AY1-6
        jr      c,.ty
        ld      (iy+2),AY1-6
.ty:    ld      a,(iy+1)
        cp      AX1-7
        jr      c,.sk
        ld      (iy+1),AX1-7
.sk:    ld      a,SFX_SPAWN
        call    play_sfx
.fr:    ld      a,(ix+0)
        cp      T_FACT
        jr      z,.fac
        ld      a,(ix+6)
        rra
        rra
        and     3
        cp      3
        jr      nz,.f2
        ld      a,1
.f2:    add     a,F_SPH0
        ld      de,$0505
        jp      std_enemy
.fac:   ld      a,(ix+6)
        rra
        and     1
        add     a,F_SPH1
        ld      de,$0505
        jp      std_enemy

; ---- SEEKER (enforcer): drifts after you, fires sparks ---------------
upd_seek:
        ld      de,$0505
        ld      (cur_wh),de
        ld      a,(logic_on)
        or      a
        jr      z,.dr
        ld      a,(gtick)
        add     a,(ix+6)
        and     7
        jr      nz,.mv
        ; re-aim
        ld      a,(px)
        ld      b,(ix+1)
        call    sgn_to
        ld      c,a
        call    rnd
        and     1
        inc     a
        ld      d,a
        ld      a,c
        call    mul_sgn
        ld      (ix+4),a
        ld      a,(py)
        ld      b,(ix+2)
        call    sgn_to
        ld      (ix+5),a
        call    rnd
        and     3
        jr      nz,.mv
        ld      (ix+5),0
.mv:    call    ease_skip
        jr      nz,.fire
        ld      d,(ix+4)
        ld      e,(ix+5)
        ld      a,(gtick)
        and     1
        jr      z,.m2
        ld      e,0
.m2:    call    move_obj
.fire:  dec     (ix+3)
        jr      nz,.dr
        ld      a,(wave_lvl)
        add     a,a
        add     a,a
        add     a,a
        ld      b,a
        ld      a,70
        sub     b
        call    rnd_n
        add     a,30
        ld      b,a
        ld      a,(ez_seek)         ; seekers hold their fire longer early on
        add     a,b
        ld      (ix+3),a
        ld      b,(ix+1)
        inc     b
        inc     b
        ld      c,(ix+2)
        inc     c
        inc     c
        ld      a,1
        call    fire_ebul
.dr:    ld      a,(gtick)
        rra
        rra
        and     1
        add     a,F_ENF0
        ld      de,$0505
        jp      std_enemy

; ---- MINDBOT (brain): hunts humans, makes mutants, fires missiles ----
upd_brain:
        ld      de,$0607
        ld      (cur_wh),de
        ld      a,(logic_on)
        or      a
        jp      z,.dr
        ld      a,(gtick)
        add     a,(ix+6)
        and     31
        call    z,pick_target
        dec     (ix+3)
        jr      nz,.cv
        ld      a,(ez_step)
        ld      (ix+3),a
        inc     (ix+6)
        call    target_xy
        ld      de,$0101
        call    toward_xy
        ; occasionally a cruise missile
        call    rnd
        and     31
        jr      nz,.cv
        ld      b,(ix+1)
        inc     b
        inc     b
        inc     b
        ld      c,(ix+2)
        inc     c
        ld      a,3
        call    fire_ebul
.cv:    ; reached its human? -> mutant
        ld      a,(ix+7)
        cp      $FF
        jp      z,.dr
        call    obj_addr
        ld      a,(hl)
        cp      T_MOM
        jp      c,.dr
        cp      T_SKULL
        jp      nc,.dr
        call    near_obj
        jp      nc,.dr
        ld      (hl),T_MUT
        inc     hl
        inc     hl
        inc     hl
        ld      (hl),1
        ld      hl,kills_left
        inc     (hl)
        ld      hl,fam_lost
        inc     (hl)
        ld      (ix+7),$FF
        ld      a,SFX_MUTATE
        call    play_sfx
.dr:    ld      a,(ix+6)
        and     1
        add     a,F_BRAIN0
        ld      de,$0607
        jp      std_enemy

; ---- MUTANT (prog): fast and twitchy ----------------------------------
upd_mut:
        ld      de,$0505
        ld      (cur_wh),de
        ld      a,(logic_on)
        or      a
        jr      z,.dr
        inc     (ix+6)
        call    ease_skip
        jr      nz,.dr
        ld      de,$0101
        ld      a,(gtick)
        and     1
        jr      z,.m
        ld      e,0
.m:     call    rnd
        and     7
        jr      nz,.m2
        ld      d,2
.m2:    call    toward_player
.dr:    ld      a,(ix+6)
        rra
        and     1
        add     a,F_PROG0
        ld      de,$0505
        jp      std_enemy

; ---- TANK: slow, lobs bouncing shells ---------------------------------
upd_tank:
        ld      de,$0607
        ld      (cur_wh),de
        ld      a,(logic_on)
        or      a
        jr      z,.dr
        dec     (ix+3)
        jr      nz,.dr
        ld      a,(ez_tank)
        ld      (ix+3),a
        inc     (ix+6)
        ld      de,$0101
        call    rnd
        and     3
        jr      nz,.t1
        ld      de,$0100
.t1:    call    toward_player
        ld      a,(ix+6)
        and     15
        jr      nz,.dr
        call    rnd
        and     1
        jr      z,.dr
        ld      b,(ix+1)
        inc     b
        inc     b
        ld      c,(ix+2)
        ld      a,2
        call    fire_ebul
.dr:    ld      a,(ix+6)
        and     1
        add     a,F_TANK0
        ld      de,$0607
        jp      std_enemy

; ---- HUMANS: wander about, waiting to be saved -----------------------
upd_human:
        ld      a,(ix+0)
        cp      T_KID
        ld      de,$0605
        jr      nz,.sz
        ld      de,$0503
.sz:    ld      (cur_wh),de
        ld      a,(logic_on)
        or      a
        jp      z,.dr
        dec     (ix+3)
        jr      nz,.tc
        ld      (ix+3),3
        inc     (ix+6)
        ld      a,(ix+4)
        or      (ix+5)
        jr      z,.nd
        ld      a,(ix+6)
        and     31
        jr      nz,.go
.nd:    push    ix
        pop     iy
        call    rnd_vel
        call    sgn8_ix4
.go:    ld      d,(ix+4)
        ld      e,(ix+5)
        call    move_obj
        ld      a,(tmp2)
        bit     0,a
        jr      z,.h1
        ld      a,(ix+4)
        neg
        ld      (ix+4),a
.h1:    ld      a,(tmp2)
        bit     1,a
        jr      z,.tc
        ld      a,(ix+5)
        neg
        ld      (ix+5),a
.tc:    call    touch_player
        jp      nc,.dr
        ; rescued!
        ld      a,(rescue_n)
        cp      4
        jr      c,.r1
        ld      a,4
.r1:    ld      (ix+6),a            ; popup text index
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,rescue_pts
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        call    add_score
        ld      hl,rescue_n
        inc     (hl)
        ld      hl,fam_saved
        inc     (hl)
        ld      (ix+0),T_POP
        ld      (ix+3),30
        ld      a,(ix+1)
        cp      110
        jr      c,.r2
        ld      (ix+1),110
.r2:    ld      a,SFX_RESCUE
        jp      play_sfx
.dr:    ld      a,(ix+0)
        sub     T_MOM
        add     a,a
        ld      b,a
        ld      a,(ix+6)
        and     1
        add     a,b
        add     a,F_MOM0
        ld      (cur_frame),a
        jp      obj_draw

; sgn8_ix4: humans walk at 1 pixel: clamp dx to -1..1
sgn8_ix4:
        ld      a,(ix+4)
        call    sgn8
        ld      (ix+4),a
        ret

; ---- SKULL left where a human was squashed ---------------------------
upd_skull:
        ld      a,(logic_on)
        or      a
        jr      z,.dr
        dec     (ix+3)
        jr      nz,.dr
        ld      (ix+0),0
        ret
.dr:    ld      a,F_SKULL
        ld      (cur_frame),a
        jp      obj_draw

; ---- POPUP: rescue points --------------------------------------------
upd_pop:
        dec     (ix+3)
        jr      nz,.dr
        ld      (ix+0),0
        ret
.dr:    ld      a,(ix+6)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,pop_strs
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ld      a,(ix+1)
        rrca
        rrca
        and     $3F
        ld      b,a
        ld      c,(ix+2)
        ld      a,(gtick)
        and     2
        ld      a,$55
        jr      z,.c
        ld      a,$FF
.c:     jp      text3

; ---- PICKUP: triple shot / shield -------------------------------------
upd_pick:
        ld      de,$0505
        ld      (cur_wh),de
        ld      a,(logic_on)
        or      a
        jr      z,.dr
        dec     (ix+3)
        jr      nz,.tc
        ld      (ix+0),0
        ret
.tc:    call    touch_player
        jr      nc,.dr
        ld      a,(ix+7)
        or      a
        jr      nz,.sh
        ld      a,250
        ld      (ptriple),a
        jr      .got
.sh:    ld      a,150
        ld      (pshield),a
.got:   ld      (ix+0),0
        ld      de,$0250
        call    add_score
        ld      a,SFX_PICKUP
        jp      play_sfx
.dr:    ld      a,(ix+3)
        cp      75
        jr      nc,.vis
        ld      a,(gtick)
        and     2
        ret     z
.vis:   ld      a,(ix+7)
        add     a,a
        ld      b,a
        ld      a,(gtick)
        rra
        rra
        and     1
        add     a,b
        add     a,F_PICK_TRI0
        ld      (cur_frame),a
        jp      obj_draw

; ---- EXPLOSION: the robot shatters into its scan lines --------------
upd_expl:
        ld      a,(ix+3)
        inc     a
        ld      (ix+3),a
        cp      10
        jr      c,.dr
        ld      (ix+0),0
        ret
.dr:    ld      d,a
        ld      a,(ix+6)
        ld      b,(ix+1)
        ld      c,(ix+2)
        jp      draw_spread_g

; ---------------------------------------------------------------------
; enemy bullets: 1 spark, 2 bouncing shell, 3 cruise missile
;  +1/+2 x (8.8), +3/+4 y (8.8), +5 dx, +6 dy (1/32 px), +7 life
; ---------------------------------------------------------------------
; fire_ebul: A = kind, B = x, C = y : aimed at the player
fire_ebul:
        ld      (tmp1),a
        ld      a,(gstate)
        cp      GS_PLAY
        ret     nz
        ld      iy,EBUL
        ld      de,8
        ld      h,NEBUL
.l:     ld      a,(iy+0)
        or      a
        jr      z,.f
        add     iy,de
        dec     h
        jr      nz,.l
        ret
.f:     ld      a,(tmp1)
        ld      (iy+0),a
        ld      (iy+1),0
        ld      (iy+2),b
        ld      (iy+3),0
        ld      (iy+4),c
        call    aim_dir
        ld      e,a
        ld      d,0
        ld      hl,bvx
        add     hl,de
        ld      b,(hl)
        ld      hl,bvy
        add     hl,de
        ld      c,(hl)
        ld      a,(tmp1)
        cp      1
        jr      nz,.sl
        ld      a,(easy)
        cp      3
        jr      c,.sp               ; sparks: half speed on waves 1-2
.sl:    sra     b                   ; shells and missiles start slower
        sra     c
.sp:    ld      (iy+5),b
        ld      (iy+6),c
        ld      (iy+7),120
        ld      hl,nebul
        inc     (hl)
        ld      a,SFX_EFIRE
        jp      play_sfx

; aim_dir: B = x, C = y -> A = 8-way direction toward the player
aim_dir:
        ld      a,(px)
        add     a,2
        sub     b
        ld      d,a
        ld      a,(py)
        add     a,3
        sub     c
        ld      e,a
        ld      a,d
        call    abs_a
        ld      h,a
        ld      a,e
        call    abs_a
        ld      l,a
        srl     a
        add     a,l
        ld      l,a                 ; |dy| * 1.5 (tall pixels)
        add     a,a
        cp      h
        jr      c,.hz
        ld      a,h
        add     a,a
        cp      l
        jr      c,.vt
        bit     7,d
        jr      nz,.lf
        bit     7,e
        ld      a,1
        ret     nz
        ld      a,3
        ret
.lf:    bit     7,e
        ld      a,7
        ret     nz
        ld      a,5
        ret
.hz:    bit     7,d
        ld      a,2
        ret     z
        ld      a,6
        ret
.vt:    bit     7,e
        ld      a,4
        ret     z
        xor     a
        ret

ebul_update:
        ld      a,(nebul)
        or      a
        ret     z
        ld      ix,EBUL
        ld      b,NEBUL
.l:     push    bc
        ld      a,(ix+0)
        or      a
        jp      z,.n
        ld      a,(logic_on)
        or      a
        jp      z,.dr
        dec     (ix+7)
        jp      z,.kill
        ; missile homing
        ld      a,(ix+0)
        cp      3
        jr      nz,.mv
        ld      a,(gtick)
        and     3
        jr      nz,.mv
        ld      b,(ix+2)
        ld      c,(ix+4)
        call    aim_dir
        ld      e,a
        ld      d,0
        ld      hl,bvx
        add     hl,de
        ld      a,(hl)
        sra     a
        ld      b,(ix+5)
        call    nudge
        ld      (ix+5),a
        ld      hl,bvy
        add     hl,de
        ld      a,(hl)
        sra     a
        ld      b,(ix+6)
        call    nudge
        ld      (ix+6),a
.mv:    ; x += dx*8
        ld      a,(ix+5)
        call    ext8
        ld      e,(ix+1)
        ld      d,(ix+2)
        add     hl,de
        ld      a,h
        cp      AX0
        jr      c,.xo
        cp      AX1-3
        jr      nc,.xo
        ld      (ix+1),l
        ld      (ix+2),h
        jr      .y
.xo:    ld      a,(ix+0)
        cp      2
        jp      nz,.kill
        ld      a,(ix+5)
        neg
        ld      (ix+5),a
.y:     ld      a,(ix+6)
        call    ext8
        ld      e,(ix+3)
        ld      d,(ix+4)
        add     hl,de
        ld      a,h
        cp      AY0
        jr      c,.yo
        cp      AY1-3
        jr      nc,.yo
        ld      (ix+3),l
        ld      (ix+4),h
        jr      .hit
.yo:    ld      a,(ix+0)
        cp      2
        jp      nz,.kill
        ld      a,(ix+6)
        neg
        ld      (ix+6),a
.hit:   ; touches the player?
        ld      a,(palive)
        or      a
        jr      z,.sh
        ld      a,(px)
        add     a,4
        cp      (ix+2)
        jr      c,.sh
        ld      a,(ix+2)
        add     a,2
        ld      hl,px
        cp      (hl)
        jr      c,.sh
        ld      a,(py)
        add     a,5
        cp      (ix+4)
        jr      c,.sh
        ld      a,(ix+4)
        add     a,2
        ld      hl,py
        cp      (hl)
        jr      c,.sh
        ld      a,(pshield)
        or      a
        jr      nz,.kill
        call    kill_player
        jr      .dr
.sh:    ; shot down by the player?
        ld      a,(nshots)
        or      a
        jr      z,.dr
        ld      iy,SHOTS
        ld      b,NSHOT
.sl:    ld      a,(iy+0)
        or      a
        jr      z,.sn
        ld      a,(iy+1)
        sub     (ix+2)
        dec     a
        call    abs_a
        cp      4
        jr      nc,.sn
        ld      a,(iy+2)
        sub     (ix+4)
        dec     a
        call    abs_a
        cp      4
        jr      nc,.sn
        ld      (iy+0),0
        ld      hl,nshots
        dec     (hl)
        ld      de,$0025
        call    add_score
        ld      a,SFX_ZAP
        call    play_sfx
        jr      .kill
.sn:    ld      de,8
        add     iy,de
        djnz    .sl
.dr:    ld      a,(ix+0)
        cp      2
        ld      a,F_SHELL
        jr      z,.df
        ld      a,(ix+0)
        cp      3
        ld      a,F_MISS
        jr      z,.df
        ld      a,(gtick)
        and     1
        add     a,F_SPARK0
.df:    ld      b,(ix+2)
        ld      c,(ix+4)
        call    draw_frame_g
        jr      .n
.kill:  ld      (ix+0),0
        ld      hl,nebul
        dec     (hl)
.n:     ld      de,8
        add     ix,de
        pop     bc
        dec     b
        jp      nz,.l
        ret

; ext8: A = signed 1/32 px -> HL = A*8 (8.8)
ext8:
        ld      l,a
        add     a,a
        sbc     a,a
        ld      h,a
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ret

; nudge: B = current, A = wanted -> A = B moved 6 toward wanted
nudge:
        ld      c,a
        ld      a,b
        sub     c
        jr      z,.eq
        jp      m,.up
        ; current > wanted (signed, small values)
        ld      a,b
        sub     6
        ret
.up:    ld      a,b
        add     a,6
        ret
.eq:    ld      a,b
        ret

; ---------------------------------------------------------------------
; demo AI: shoots the nearest robot, steps toward humans, dodges
; ---------------------------------------------------------------------
ai_think:
        ld      hl,ai_t
        dec     (hl)
        ret     p
        ld      (hl),2
        ld      a,(px)
        add     a,2
        ld      (tmp1),a
        ld      a,(py)
        add     a,3
        ld      (tmp2),a
        ld      iy,OBJ
        ld      b,MAXOBJ
        ld      c,$FF               ; nearest threat distance
        ld      hl,0                ; nearest threat position (H=x, L=y)
        ld      d,$FF               ; nearest human distance
        exx
        ld      hl,0                ; nearest human position
        exx
.l:     ld      a,(iy+0)
        or      a
        jr      z,.n
        cp      T_SKULL
        jr      nc,.n
        push    bc
        push    hl
        ; distance (|dx| + 2|dy|)
        ld      a,(iy+1)
        add     a,2
        ld      hl,tmp1
        sub     (hl)
        call    abs_a
        ld      e,a
        ld      a,(iy+2)
        add     a,2
        ld      hl,tmp2
        sub     (hl)
        call    abs_a
        add     a,a
        jr      c,.far
        add     a,e
        jr      nc,.dk
.far:   ld      a,$FE
.dk:    ld      e,a
        pop     hl
        pop     bc
        ld      a,(iy+0)
        cp      T_MOM
        jr      nc,.hum
        ld      a,e
        cp      c
        jr      nc,.n
        ld      c,a
        ld      h,(iy+1)
        ld      l,(iy+2)
        jr      .n
.hum:   ld      a,e
        cp      d
        jr      nc,.n
        ld      d,a
        exx
        ld      h,(iy+1)
        ld      l,(iy+2)
        exx
.n:     push    de
        ld      de,8
        add     iy,de
        pop     de
        djnz    .l
        ; fire toward the nearest threat
        xor     a
        ld      (ai_fire),a
        ld      a,c
        cp      $FF
        jr      z,.mv
        push    bc
        push    de
        push    hl
        ld      b,h
        ld      c,l
        inc     b
        inc     b
        inc     c
        inc     c
        call    aim_dir             ; direction from the threat to us
        xor     4                   ; ...reversed
        call    dir_to_bits
        ld      (ai_fire),a
        pop     hl
        pop     de
        pop     bc
.mv:    ; too close: back off.  else go for a human.  else drift to the middle
        ld      a,c
        cp      18
        jr      nc,.goh
        ld      a,(ai_fire)
        call    opp_bits
        ld      (ai_move),a
        ret
.goh:   ld      a,d
        cp      $FF
        jr      z,.mid
        exx
        ld      a,h
        ld      b,l
        exx
        ld      h,a
        ld      l,b
        jr      .to
.mid:   ld      h,62
        ld      l,33
.to:    ; bits toward (H,L)
        ld      c,0
        ld      a,(px)
        cp      h
        jr      z,.ty
        jr      nc,.lf
        set     0,c
        jr      .ty
.lf:    set     1,c
.ty:    ld      a,(py)
        cp      l
        jr      z,.dn
        jr      nc,.up
        set     3,c
        jr      .dn
.up:    set     2,c
.dn:    ld      a,c
        ld      (ai_move),a
        ret

; opp_bits: pad bits -> the opposite directions
opp_bits:
        ld      c,0
        bit     0,a
        jr      z,.a
        set     1,c
.a:     bit     1,a
        jr      z,.b
        set     0,c
.b:     bit     2,a
        jr      z,.c
        set     3,c
.c:     bit     3,a
        jr      z,.d
        set     2,c
.d:     ld      a,c
        ret
