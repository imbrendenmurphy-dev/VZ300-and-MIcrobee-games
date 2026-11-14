; =====================================================================
;  THE CAVE STEP.  One pass over the cave, top row first, left to right;
;  every rule is the same every time, so a fall can be planned.
;
;  * A boulder, gem or keg with nothing under it falls.  Resting on a
;    rounded thing (boulder, gem, keg, brick) it rolls off to a free side,
;    left first.
;  * Something falling that lands on Mort or on a haunter flattens it; a
;    falling boulder breaks a cracked wall; a keg bursts when it lands or
;    when anything lands on it, and sets off the kegs next to it.
;  * Ghosts keep a hand on the left wall, bats on the right, knights
;    march to and fro.  Bats burst into gems.
;  * Bit 7 of a cell marks a thing that has already moved into a cell the
;    scan has yet to reach; the scan clears it and leaves the thing alone.
; =====================================================================
DIR_U   equ 1
DIR_R   equ 2
DIR_D   equ 3
DIR_L   equ 4
INVULN_T equ 16                 ; steps of safety after a ward is used
INBOX_T equ 10

; ---- the change log ---------------------------------------------------
; HL = cell that changed.  keeps HL, BC, DE
chg_plain:
        xor a
; HL = cell, A = the direction its thing arrived from (0 = none)
chg_log:
        set 3,h
        ld (hl),a
        res 3,h
        push de
        push bc
        ld c,a
        ld a,(chg_n)
        cp CHG_MAX
        jr nc,.ovf
        inc a
        ld (chg_n),a
        ld de,(chg_wr)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
        ld (chg_wr),de
        pop bc
        pop de
        ret
.ovf:   ld a,1
        ld (chg_ovf),a
        pop bc
        pop de
        ret

; HL = cell -> A = 80h if the scan has yet to reach it.  keeps all else
ahead:  push de
        ld de,(scanptr)
        ld a,e
        sub l
        ld a,d
        sbc a,h
        pop de
        sbc a,a
        and $80
        ret

; A = tile -> A = its flags.  keeps all else
tflag:  push hl
        ld h,tflags>>8
        ld l,a
        ld a,(hl)
        pop hl
        ret

; move the thing at HL to DE as tile B, going C (DIR_x).  -> HL = where it is now
move_obj:
        ld (hl),T_SPACE
        call chg_plain
        ex de,hl
        call ahead
        or b
        ld (hl),a
        ld a,c
        jp chg_log

; HL = cell -> DE = the cell under it
under:  push hl
        ld de,ROWLEN
        add hl,de
        ex de,hl
        pop hl
        ret

; ---- things that fall: stones, slabs, urns, kegs and the three jewels ----
; A stone, urn, keg or jewel rolls off anything rounded; a slab never rolls
; and nothing rolls off it.  An urn that lands breaks open on a gem.
h_rest: ld b,(hl)
        call under
        ld a,(de)
        or a
        jr nz,.sup
        inc b                   ; nothing under it: it starts to fall
        ld c,DIR_D
        jp move_obj
.sup:   and $7F
        call tflag
        and F_ROUND
        ret z
        ld a,b
        cp T_SLAB
        ret z
        inc b
; HL = cell, B = falling tile: roll off to a free side (left first)
roll:   dec hl
        ld a,(hl)
        inc hl
        or a
        jr nz,.right
        push hl
        ld de,ROWLEN-1
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr nz,.right
        ld d,h
        ld e,l
        dec de
        ld c,DIR_L
        jp move_obj
.right: inc hl
        ld a,(hl)
        dec hl
        or a
        ret nz
        push hl
        ld de,ROWLEN+1
        add hl,de
        ld a,(hl)
        pop hl
        or a
        ret nz
        ld d,h
        ld e,l
        inc de
        ld c,DIR_R
        jp move_obj

h_fall: ld b,(hl)
        dec b                   ; B = the thing at rest
        call under
        ld a,(de)
        or a
        jr nz,.hit
        inc b
        ld c,DIR_D
        jp move_obj
.hit:   and $7F
        ld c,a                  ; C = what it lands on
        cp T_PLAYER
        jp z,.player
        call tflag
        and F_ENEMY
        jp nz,.enemy
        ld a,c
        cp T_KEG
        jp z,.onkeg
        ld a,b
        cp T_KEG
        jp z,.kegland
        ld a,c
        cp T_MAGIC
        jp z,.magic
        cp T_CRACKED
        jr nz,.land
        ld a,b
        cp T_BOULDER
        jr z,.smash
        cp T_SLAB
        jr nz,.land
.smash: ld (hl),b               ; a stone or slab breaks a cracked wall
        ex de,hl
        ld (hl),T_EXPL2+$80
        call chg_plain
        ld a,SFX_CRUMBLE
        jp play_sfx
.land:  ld (hl),b               ; at rest (it looks the same)
        ld a,b
        cp T_URN
        jr nz,.nurn
        ld (hl),T_GEM           ; the urn breaks open
        call chg_plain
        ld a,SFX_URN
        jp play_sfx
.nurn:  cp T_GEM
        ld a,SFX_THUD
        jr c,.s
        ld a,SFX_TINK
.s:     call play_sfx
        ld a,b
        cp T_SLAB
        ret z
        ld a,c
        call tflag
        and F_ROUND
        ret z
        inc b
        jp roll
.kegland:
        ld c,0
        jp explode
.onkeg: ld (hl),b
        ex de,hl
        ld c,0
        jp explode
.enemy: ld (hl),b
        ex de,hl
        ld a,c
        call enemy_kind
        jp explode
.magic: ld a,(magic_st)
        cp 2
        jr z,.land              ; spent: just a wall now
        or a
        jr nz,.awake
        inc a
        ld (magic_st),a
        push hl
        ld a,(CAVEBUF+CH_MAGIC)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (magic_t),hl
        pop hl
.awake: ld a,SFX_MAGIC
        call play_sfx
        ld (hl),T_SPACE         ; swallowed
        call chg_plain
        ex de,hl
        ld de,ROWLEN
        add hl,de               ; under the grate
        ld a,(hl)
        or a
        ret nz
        ld a,b                  ; stone -> gem, slab -> ruby, urn -> emerald,
        cp T_BOULDER            ; any jewel -> stone
        ld c,T_GEMF
        jr z,.mp
        cp T_SLAB
        ld c,T_RUBYF
        jr z,.mp
        cp T_URN
        ld c,T_EMERALDF
        jr z,.mp
        ld c,T_BOULDERF
.mp:    ld a,c
        or $80
        ld (hl),a
        jp chg_plain
.player:
        call player_hit
        jr z,.shatter
        ld (hl),b
        ex de,hl
        ld c,0
        jp explode
.shatter:
        ld (hl),T_EXPL2         ; it breaks on the ward
        jp chg_plain

; ---- the skull: it comes straight for Mort, one step in two -------------
h_skull:
        ld bc,T_SKULL*256
        ld (en_pref),bc
        call en_touch
        ret nz
        ld a,(tick_no)
        rra
        ret c
        ld a,(p_alive)
        or a
        ret z
        push hl
        call tile_xy            ; C = column, B = row of the skull
        ld d,b
        ld e,c
        ld hl,(p_ptr)
        call tile_xy            ; Mort's
        pop hl
        ld a,c
        sub e                   ; dx
        ld c,a
        ld a,b
        sub d                   ; dy
        ld b,a
        ; the two ways that close the gap: across (E) and up/down (D)
        ld e,1                  ; right
        bit 7,c
        jr z,.xr
        ld e,3
        ld a,c
        neg
        ld c,a
.xr:    ld d,2                  ; down
        bit 7,b
        jr z,.yd
        ld d,0
        ld a,b
        neg
        ld b,a
.yd:    ld a,c                  ; |dx| against |dy|: the longer way first
        cp b
        jr nc,.xfirst
        ld a,d
        ld d,e
        ld e,a
        ld a,c
        ld c,b
        ld b,a
.xfirst: ; E = first choice (its gap in C), D = second (gap in B)
        ld a,c
        or a
        jr z,.second
        push de
        push bc
        ld a,e
        call .try
        pop bc
        pop de
        ret z
.second: ld a,b
        or a
        ret z
        ld a,d
.try:   ld (en_nd),a
        call dir_cell
        ld a,(de)
        or a
        ret nz
        ld a,(en_nd)
        inc a
        ld c,a
        ld b,T_SKULL
        call move_obj
        xor a
        ret

; A = an enemy tile -> C = what it bursts into (0 dust, 1 gems)
enemy_kind:
        ld c,0
        cp T_BAT
        ret c
        cp T_KNIGHT
        ret nc
        inc c
        ret

; Something would kill Mort.  -> Z if he is protected (still flashing, or
; a ward takes it), NZ if this is the end of him.  keeps HL, BC, DE
player_hit:
        ld a,(invuln)
        or a
        jr nz,.safe
        ld a,(wards)
        or a
        jr z,.dead
        dec a
        ld (wards),a
        ld a,INVULN_T
        ld (invuln),a
        ld a,2
        ld (hud_cnt),a
        ld a,SFX_WARD
        call play_sfx
.safe:  xor a
        ret
.dead:  or 1
        ret

; ---- blasts -----------------------------------------------------------
; HL = centre, C = 0 dust / 1 gems
explode:
        ld (ex_c),hl
        ld a,SFX_BOOM
        call play_sfx
        ld de,-ROWLEN-1
        add hl,de
        ld b,3
.r:     push bc
        ld b,3
.c:     push bc
        call .cell
        pop bc
        inc hl
        djnz .c
        ld de,ROWLEN-3
        add hl,de
        pop bc
        djnz .r
        ret
.cell:  ld a,(hl)
        and $7F
        ld e,a
        call tflag
        and F_HARD
        ret nz
        ld a,e
        cp T_PLAYER
        jr nz,.np
        call player_hit
        ret z
        ld a,1
        ld (p_dead),a
        jr .put
.np:    cp T_KEG
        jr z,.keg
        cp T_KEGF
        jr z,.keg
        cp T_KEGLIT
        jr nz,.put
        push hl                 ; a keg already lit by another blast still
        ld de,(ex_c)            ; goes off itself
        or a
        sbc hl,de
        pop hl
        ret nz
        jr .put
.keg:   push hl                 ; a keg caught in the blast goes off next step
        ld de,(ex_c)
        or a
        sbc hl,de
        pop hl
        jr z,.put
        call ahead
        or T_KEGLIT
        ld (hl),a
        jp chg_plain
.put:   call ahead
        ld e,a
        ld a,c
        or a
        ld a,T_EXPL1
        jr z,.p2
        ld a,T_GEXPL1
.p2:    or e
        ld (hl),a
        jp chg_plain

h_keglit:
        ld c,0
        jr explode
h_expl: inc (hl)
        jp chg_plain
h_expl3:
        ld (hl),T_SPACE
        jp chg_plain
h_gexpl3:
        ld (hl),T_GEM
        jp chg_plain

; ---- the haunters -------------------------------------------------------
dirtab: dw -ROWLEN, 1, ROWLEN, -1

h_ghost:
        ld b,T_GHOST
        ld c,3                  ; turns left when it can
        jr enemy
h_bat:  ld b,T_BAT
        ld c,1                  ; turns right when it can
enemy:  ld (en_pref),bc
        call en_touch
        ret nz
        ld a,(en_base)
        ld b,a
        ld a,(hl)
        and $7F
        sub b
        ld (en_dir),a
        ld b,a
        ld a,(en_pref)
        add a,b
        and 3
        call en_try
        ret z
        ld a,(en_dir)
        call en_try
        ret z
        ld a,(en_pref)          ; blocked: turn the other way on the spot
        ld b,a
        ld a,(en_dir)
        sub b
        and 3
        ld b,a
        ld a,(en_base)
        add a,b
        ld (hl),a
        ret

h_knight:
        ld b,T_KNIGHT
        ld c,0
        ld (en_pref),bc
        call en_touch
        ret nz
        ld a,(hl)
        and $7F
        sub T_KNIGHT
        ld (en_dir),a
        call en_try
        ret z
        ld a,(en_dir)           ; blocked: about turn
        add a,2
        and 3
        add a,T_KNIGHT
        ld (hl),a
        ret

; HL = enemy, A = direction: step that way if the cell is empty.  Z if it went
en_try: ld (en_nd),a
        call dir_cell
        ld a,(de)
        or a
        ret nz
        ld a,(en_nd)
        ld c,a
        ld a,(en_base)
        add a,c
        ld b,a
        inc c
        call move_obj
        xor a
        ret

; HL = cell, A = direction 0..3 -> DE = the next cell that way.  keeps HL
dir_cell:
        push hl
        add a,a
        ld e,a
        ld d,0
        ld hl,dirtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        push hl
        add hl,de
        ex de,hl
        pop hl
        ret

; Does the enemy at HL touch Mort or the slime?  -> NZ if the enemy is gone
en_touch:
        xor a
.n:     ld (en_nd),a
        call dir_cell
        ld a,(de)
        and $7F
        cp T_PLAYER
        jr z,.pl
        cp T_SLIME
        jr z,.boom
        ld a,(en_nd)
        inc a
        cp 4
        jr nz,.n
        xor a
        ret
.pl:    ld a,(invuln)
        or a
        ret nz                  ; he is flashing: no harm (NZ: stay put this step)
        call player_hit
        jr nz,.boom
        ld (hl),T_EXPL2         ; the ward pops it
        call chg_plain
        or 1
        ret
.boom:  ld a,(en_base)
        call enemy_kind
        call explode
        or 1
        ret

; ---- the slime ----------------------------------------------------------
h_slime:
        ld a,(slime_fate)
        or a
        jr z,.live
        dec a
        ld a,T_GEM
        jr z,.t
        ld a,T_BOULDER
.t:     ld (hl),a
        jp chg_plain
.live:  ld a,(slime_n)
        inc a
        jr z,.sat
        ld (slime_n),a
.sat:   xor a
.n:     ld (en_nd),a
        call dir_cell
        ld a,(de)
        and $7F
        call tflag
        and F_SOFT
        jr z,.nx
        ld a,1
        ld (slime_can),a
.nx:    ld a,(en_nd)
        inc a
        cp 4
        jr nz,.n
        push hl
        call random
        pop hl
        ld b,a
        ld a,(slime_rate)
        ld c,a
        ld a,b
        cp c
        ret nc
        rrca
        rrca
        and 3
        call dir_cell
        ld a,(de)
        and $7F
        call tflag
        and F_SOFT
        ret z
        ex de,hl
        call ahead
        or T_SLIME
        ld (hl),a
        jp chg_plain

; ---- the way in -----------------------------------------------------------
h_inbox:
        ld a,(inbox_t)
        or a
        jr z,.go
        dec a
        ld (inbox_t),a
        ret
.go:    ld (hl),T_PLAYER
        ld (p_ptr),hl
        ld a,1
        ld (p_alive),a
        ld a,SFX_APPEAR
        call play_sfx
        jp chg_plain

; ---- Mort ---------------------------------------------------------------
h_player:
        ld (p_ptr),hl
        ld a,(invuln)
        or a
        jr z,.ni
        dec a
        ld (invuln),a
.ni:    ld a,(tick_pad)
        and 15
        ld c,a
        jr nz,.dir
.idle:  xor a
        ld (pushcnt),a
        ld (p_moving),a
        ret
.dir:   ld a,(tick_new)         ; a newly pressed direction wins,
        and 15
        jr nz,.pick
        ld a,(p_dirbit)         ; then the one in use, then any held
        and c
        jr nz,.have
        ld a,c
.pick:  ld b,a
        neg
        and b                   ; lowest bit
.have:  ld (p_dirbit),a
        ld e,1
        cp PAD_R
        jr z,.d
        ld e,3
        cp PAD_L
        jr z,.d
        ld e,0
        cp PAD_U
        jr z,.d
        ld e,2
.d:     ld a,e
        ld (p_dir),a
        call dir_cell           ; DE = target
        ld a,(de)
        and $7F
        jr z,.walk
        cp T_DIRT4+1
        jr c,.dig               ; any of the four earths
        cp T_EXITO
        jp z,.exit
        cp T_DOOR
        jp z,.door
        cp T_BOULDER
        jp z,.push
        cp T_KEG
        jp z,.push
        cp T_URN
        jp z,.push
        ld b,a
        call tflag
        and F_PICKUP
        jr z,.blocked
        ld a,b
        push hl
        push de
        call collect
        pop de
        pop hl
        jr .walk
.dig:   ld a,SFX_DIG
        call play_sfx
.walk:  xor a
        ld (pushcnt),a
        ld a,(tick_pad)
        and PAD_FIRE
        jr nz,.grab
.step:  ld a,(p_dir)
        inc a
        ld c,a
        ld b,T_PLAYER
        call move_obj
        ld (p_ptr),hl
        ld a,1
        ld (p_moving),a
        ld hl,p_steps
        inc (hl)
        ret
.grab:  ex de,hl                ; reach out without stepping
        ld a,2
        ld (p_moving),a
        ld a,(hl)
        or a
        ret z
        ld (hl),T_SPACE
        jp chg_plain
.blocked:
        xor a
        ld (pushcnt),a
        ld (p_moving),a
        ret
.door:  ld a,(keys_n)
        or a
        jr z,.blocked
        dec a
        ld (keys_n),a
        ld a,2
        ld (hud_cnt),a
        ld a,SFX_DOOR
        call play_sfx
        jr .walk
.exit:  ld (hl),T_SPACE
        call chg_plain
        xor a
        ld (p_alive),a
        inc a
        ld (cave_done),a
        ret
.push:  ld b,a                  ; B = the boulder or keg
        ld a,(p_dir)
        and 1
        jr z,.blocked           ; only sideways
        ld a,2
        ld (p_moving),a
        push hl
        ld a,(p_dir)
        ex de,hl
        call dir_cell           ; HL = the thing, DE = the cell beyond it
        ld a,(de)
        or a
        jr z,.room
        pop hl
        xor a
        ld (pushcnt),a
        ret
.room:  ld a,(pushcnt)
        inc a
        ld (pushcnt),a
        cp 2
        jr nc,.shove
        pop hl                  ; lean on it for a step first
        ret
.shove: xor a
        ld (pushcnt),a
        ld a,(p_dir)
        inc a
        ld c,a
        push hl
        call move_obj           ; the thing slides on
        ld a,SFX_PUSH
        call play_sfx
        pop de                  ; DE = the cell it left
        pop hl                  ; HL = Mort
        ld a,(tick_pad)
        and PAD_FIRE
        ret nz
        jp .step

; A = the pickup Mort has just taken
collect:
        ld c,a
        call tflag
        and F_GEM
        jr nz,.gem
        ld a,c
        cp T_CHALICE
        jr z,.chalice
        cp T_CROWN
        jr z,.crown
        cp T_WARD
        jr z,.ward
        cp T_HOURGLASS
        jr z,.hour
        cp T_KEY
        jr z,.key
        ; a heart: one more life
        ld a,(lives)
        cp 9
        jr nc,.sp
        inc a
        ld (lives),a
.sp:    ld a,SFX_BONUS
        jp .out
.key:   ld hl,keys_n
        inc (hl)
        ld a,SFX_KEY
        jp .out
.hour:  ld hl,(time)
        ld de,20
        add hl,de
        ld (time),hl
        ld a,SFX_BONUS
        jp .out
.ward:  ld a,(wards)
        cp 3
        jr nc,.w3
        inc a
        ld (wards),a
.w3:    ld a,SFX_BONUS
        jr .out
.crown: ld a,$50                ; 1000 points
        call add_score
        ld a,$50
        call add_score
        jr .tre
.chalice:
        ld a,$50                ; 500 points
        call add_score
.tre:   ld hl,treasures
        inc (hl)
        ld a,SFX_CHALICE
        jr .out
.gem:   ; a gem is worth the crypt's rate, a ruby twice, an emerald three
        ; times, and they count as one, two and three gems toward the quota
        ld b,1
        ld a,c
        cp T_RUBY
        jr c,.gv
        inc b
        cp T_EMERALD
        jr c,.gv
        inc b
.gv:    ld a,b
        ld (gem_worth),a
        ld a,(exit_open)
        or a
        ld a,(CAVEBUF+CH_GEMV)
        jr z,.ga
        ld a,(CAVEBUF+CH_GEMX)
.ga:    push af
        push bc
        call add_score
        pop bc
        pop af
        djnz .ga
        ld hl,gems
        ld a,(gem_worth)
        add a,(hl)
        jr nc,.nf
        ld a,255                ; (the count stops at 255)
.nf:    ld (hl),a
        ld a,(exit_open)
        or a
        ld a,SFX_GEM
        jr nz,.out
        ld a,(quota)
        ld b,a
        ld a,(hl)
        cp b
        ld a,SFX_GEM
        jr c,.out
        ld hl,(exit_ptr)        ; enough: the gate opens
        ld (hl),T_EXITO
        call chg_plain
        ld a,6
        ld (flash),a
        ld a,1
        ld (exit_open),a
        ld a,SFX_OPEN
.out:   call play_sfx
        ld a,2
        ld (hud_cnt),a
        ret
.out0:  pop bc                  ; (the gem branch keeps the worth on the stack)
        jr .out

; A = BCD tens of points to add (10h = 100 points)
add_score:
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
        ret

; ---- one step of the whole cave -----------------------------------------
tick:   ld hl,(chg_cur)         ; this step's change list becomes the last one's
        ld de,(chg_prev)
        ld (chg_prev),hl
        ld (chg_cur),de
        ld (chg_wr),de
        ld a,(chg_n)
        ld (prev_n),a
        xor a
        ld (chg_n),a
        ld (pg_sync),a
        ld (pg_sync+1),a
        ld (slime_n),a
        ld (slime_can),a
        ld (p_moving),a
        ld a,(demo_on)
        or a
        jr nz,.demo
        ld hl,padnew
        ld a,(pad)
        or (hl)
        ld (tick_pad),a
        ld a,(hl)
        ld (tick_new),a
        ld (hl),0
        jr .in
.demo:  call demo_next
.in:    ld hl,CAVE
        ld a,(cave_h)
        ld c,a
.row:   push hl
        push bc
        call vschk
        ld a,(cave_w)
        ld b,a
.cell:  ld a,(hl)
        cp T_ACTIVE
        jr c,.next
        or a
        jp m,.flag
        ld (scanptr),hl
        push hl
        push bc
        call dispatch
        pop bc
        pop hl
.next:  inc hl
        djnz .cell
        pop bc
        pop hl
        ld de,ROWLEN
        add hl,de
        dec c
        jr nz,.row
        jr tick_post
.flag:  and $7F
        ld (hl),a
        jr .next

dispatch:
        sub T_ACTIVE
        add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,htab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex (sp),hl
        ret
htab:   dw h_rest, h_fall, h_rest, h_fall, h_rest, h_fall, h_rest, h_fall, h_keglit
        dw h_rest, h_fall, h_rest, h_fall, h_rest, h_fall
        dw h_player
        dw h_ghost, h_ghost, h_ghost, h_ghost, h_bat, h_bat, h_bat, h_bat
        dw h_knight, h_knight, h_knight, h_knight, h_skull
        dw h_expl, h_expl, h_expl3, h_expl, h_expl, h_gexpl3
        dw h_slime, h_inbox, h_none
        ASSERT ($-htab)/2 == NTILES-T_ACTIVE
h_none: ret

tick_post:
        ld hl,$FFFF
        ld (scanptr),hl
        ; the slime: walled in it turns to gems, grown too big to stone
        ld a,(slime_fate)
        or a
        jr nz,.sdone
        ld a,(slime_n)
        or a
        jr z,.sdone
        ld b,a
        ld a,(slime_can)
        or a
        jr nz,.big
        ld a,1
        ld (slime_fate),a
        ld a,SFX_OPEN
        call play_sfx
        jr .sdone
.big:   ld a,(CAVEBUF+CH_SLMAX)
        ld c,a
        ld a,b
        cp c
        jr c,.sdone
        ld a,2
        ld (slime_fate),a
.sdone: ; the grate's time
        ld a,(magic_st)
        dec a
        jr nz,.mdone
        ld hl,(magic_t)
        dec hl
        ld (magic_t),hl
        ld a,h
        or l
        jr nz,.mdone
        ld a,2
        ld (magic_st),a
.mdone: ld a,(chg_ovf)
        or a
        jr z,.nov
        xor a                   ; too much happened to list: draw it all
        ld (chg_ovf),a
        ld (chg_n),a
        ld hl,(chg_cur)
        ld (chg_wr),hl
        call force_both
.nov:   ld a,1
        ld (rn_tick),a
        ld hl,(tick_no)         ; steps completed (the tests count on this)
        inc hl
        ld (tick_no),hl
        ret

; time ran out, or Mort gave up: he bursts where he stands
kill_player:
        ld a,(p_alive)
        or a
        ret z
        xor a
        ld (invuln),a
        ld (wards),a
        ld hl,(p_ptr)
        ld c,0
        jp explode
