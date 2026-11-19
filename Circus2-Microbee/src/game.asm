; =====================================================================
;  CIRCUS 2 - gameplay
; =====================================================================
S_NONE  = 0
S_SEAT  = 1
S_FLY   = 2
S_TOWER = 3
S_SPLAT = 4

CS_STATE= 0
CS_X    = 1     ; word 8.8, hi = sprite left pixel
CS_Y    = 3     ; word 8.8, hi = sprite top pixel (signed)
CS_VX   = 5
CS_VY   = 7
CS_T    = 9
CS_ANIM = 10
CS_POPS = 11
CS_FL   = 12    ; bit0 hoop up, bit1 hoop down, bit2 perfect spin, bit3 landing checked
CS_SIDE = 13
CS_CD   = 14    ; collision cooldown

GRAV    = 9
NACTS   = 9

AF_MONKEY = 1
AF_HOOP   = 2
AF_BOB    = 4
AF_BONUS  = 8
AF_PRIZE  = 16

T_NORM  = 0
T_GIFT  = 1
T_BOMB  = 2
T_STEEL = 3

PT_SIZE = 12
NPARTS  = 12
PU_SIZE = 14

; ---------------------------------------------------------------------
; game entry.  A = 0 normal game, 1 demo
; returns when the game (or demo) ends
; ---------------------------------------------------------------------
game_main:
        ld (demo),a
        ld hl,GAMEVARS
        ld de,GAMEVARS+1
        ld bc,GAMEVARS_END-GAMEVARS-1
        ld (hl),0
        ldir
        call stop_music
        ld a,(difficulty)
        ld hl,lives_by_diff
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (lives),a
        ld a,2
        ld (nextlife),a
        ld a,(demo)
        or a
        jr z,.actloop
        ld a,(demo_act)
        ld (act),a
        ld a,9
        ld (lives),a
.actloop:
        call act_setup
        call act_intro
        jr nz,.abort
        call play_act
        ld a,(gameresult)
        or a
        jr nz,.ended
        call act_clear
        ld a,(demo)
        or a
        jr nz,.abort
        ld a,(act)
        inc a
        cp NACTS
        jr c,.n
        ld hl,encore
        inc (hl)
        xor a
.n:     ld (act),a
        jr .actloop
.ended: cp 2
        jr z,.abort
        ld a,(demo)
        or a
        jr nz,.abort
        call game_over
        call hiscore_check
.abort: call stop_music
        xor a
        ld (sfx_ptr),a
        ld (sfx_ptr+1),a
        ret

lives_by_diff: db 5,4,3

; ---------------------------------------------------------------------
; act set-up
; ---------------------------------------------------------------------
act_ptr:        ; -> HL = act data for current act
        ld a,(act)
        add a,a
        ld hl,acttab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

act_setup:
        ld a,(act)
        call load_scene
        ; clear per-act state
        ld hl,clown0
        ld de,clown0+1
        ld bc,GAMEVARS_END-clown0-1
        ld (hl),0
        ldir
        xor a
        ld (pw_wide),a
        ld (pw_slow),a
        ld (pw_x2),a
        ld (pw_umb),a
        ld (combo),a
        ld (misses_act),a
        ld (flipcool),a
        ld (flipanim),a
        ld (piestick),a
        ld (endtimer),a
        ld (gameresult),a
        ld (bonus_pops),a
        ld (balloons_left),a
        ld (balloons_total),a
        call act_ptr
        ld b,(hl)               ; css
        inc hl
        ld a,(hl)               ; bg
        inc hl
        push hl
        call set_theme
        pop hl
        ld a,(hl)
        ld (nrows),a
        inc hl
        ld a,(hl)
        ld (actflags),a
        inc hl
        inc hl                  ; skip name ptr
        inc hl
        inc hl                  ; skip hint ptr
        inc hl
        ; rows
        ld a,(nrows)
        or a
        jr z,.norows
        ld b,a
        ld ix,rows
        ld iy,rowspr
        ld c,0                  ; row index
.rl:    push bc
        ld a,(hl)               ; y
        ld (ix+1),a
        inc hl
        ld e,(hl)               ; speed
        inc hl
        ld d,(hl)
        inc hl
        call scale_speed
        ld (ix+4),e
        ld (ix+5),d
        ld e,(hl)               ; slots
        inc hl
        ld d,(hl)
        inc hl
        ld (ix+6),e
        ld (ix+7),d
        call popcount_de
        ld (ix+0),a
        ld e,a
        ld a,(balloons_left)
        add a,e
        ld (balloons_left),a
        ld (balloons_total),a
        call rnd_off
        ; type masks -> rowtype
        pop bc
        push bc
        push hl
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        ld de,rowtype
        add a,e
        ld e,a
        jr nc,$+3
        inc d
        pop hl
        ld a,T_GIFT
        call apply_typemask
        ld a,T_BOMB
        call apply_typemask
        ld a,T_STEEL
        call apply_typemask
        ld a,(hl)               ; sprite index
        inc hl
        ld (iy+0),a
        inc iy
        ld de,8
        add ix,de
        pop bc
        inc c
        djnz .rl
.norows:
        call build_all_strips
        ; seesaw & clowns
        ld hl,64*256
        ld (see_x),hl
        ld hl,0
        ld (see_v),hl
        ld a,10
        ld (see_hw),a
        xor a
        ld (tilt),a
        ld ix,clown0
        ld (ix+CS_STATE),S_SEAT
        call spawn_tower
        ; monkey / hoop
        ld a,(actflags)
        and AF_MONKEY
        jr z,.nm
        ld ix,monkey
        ld (ix+0),1
        ld (ix+1),40
        ld (ix+2),1
        ld (ix+4),60
.nm:    ld a,(actflags)
        and AF_HOOP
        jr z,.nh
        ld a,1
        ld (hoop),a
        ld a,64
        ld (hoop+1),a
.nh:    ld a,(actflags)
        and AF_BONUS
        jr z,.nb
        ld hl,750
        ld (bonus_time),hl
.nb:    call bob_rows
        ld a,2
        ld (fullpres),a
        call hud_draw
        call render             ; prepare native row caches before the act card
        ret

; HL -> random row offset init (8.8): uses rand
rnd_off:
        call rand
        and $7F
        ld (ix+3),a
        xor a
        ld (ix+2),a
        ret

; DE = speed (signed 8.8) -> scaled by difficulty & encore
scale_speed:
        push hl
        ex de,hl
        ld a,(difficulty)
        or a
        jr nz,.n1
        ; easy: 3/4
        ld d,h
        ld e,l
        sra d
        rr e
        sra d
        rr e
        or a
        sbc hl,de
        jr .enc
.n1:    cp 2
        jr nz,.enc
        ld d,h
        ld e,l
        sra d
        rr e
        sra d
        rr e
        add hl,de               ; hard: 5/4
.enc:   ld a,(encore)
        or a
        jr z,.done
        ld b,a
        ld d,h
        ld e,l
        sra d
        rr e
        sra d
        rr e
.el:    add hl,de               ; +1/4 per encore
        djnz .el
.done:  ex de,hl
        pop hl
        ret

; count bits of DE -> A
popcount_de:
        push bc
        ld b,16
        ld c,0
.l:     srl d
        rr e
        jr nc,$+3
        inc c
        djnz .l
        ld a,c
        pop bc
        ret

; HL -> mask word; DE = rowtype base for row; A = type. Sets types. HL += 2
apply_typemask:
        push de
        push bc
        ld c,a
        ld a,(hl)
        inc hl
        push hl
        ld l,(hl)
        ld h,a                  ; H = lo, L = hi  (bits 0..7 lo, 8..15 hi)
        ld b,16
.l:     srl l
        rr h
        jr nc,.n
        ld a,c
        ld (de),a
.n:     inc de
        djnz .l
        pop hl
        inc hl
        pop bc
        pop de
        ret

; ---------------------------------------------------------------------
; balloon strips
; ---------------------------------------------------------------------
; strip address for row C, shift A -> HL
build_all_strips:
 ld hl,cache_dirty
 ld (hl),1
 inc hl
 ld (hl),1
 inc hl
 ld (hl),1
 inc hl
 ld (hl),1
 ret
build_strip:
strip_slot:
 push bc
 push de
 push hl
 call cache_patch
 pop hl
 pop de
 pop bc
 ret

slot_alive:
        push hl
        ld a,c
        add a,a
        add a,a
        add a,a
        ld hl,rows+6
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,b
        cp 8
        jr c,.lo
        inc hl
        sub 8
.lo:    push bc
        ld b,a
        ld a,(hl)
        inc b
.sh:    dec b
        jr z,.t
        rrca
        jr .sh
.t:     pop bc
        and 1
        pop hl
        ret

; clear alive bit of slot B row C
slot_kill:
        push hl
        push bc
        ld a,c
        add a,a
        add a,a
        add a,a
        ld hl,rows+6
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,b
        cp 8
        jr c,.lo
        inc hl
        sub 8
.lo:    ld b,a
        ld a,$FE
        inc b
.sh:    dec b
        jr z,.t
        rlca
        jr .sh
.t:     and (hl)
        ld (hl),a
        pop bc
        pop hl
        ret

; type of slot B row C -> A ; HL -> rowtype entry
slot_type:
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b
        ld hl,rowtype
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ret

; sprite for slot B row C -> HL
slot_sprite:
        push bc
        call slot_type
        or a
        jr nz,.sp
        ld hl,rowspr
        ld a,c
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld hl,balspr_norm
        jr .tab
.sp:    ld hl,balspr_type
.tab:   add a,a
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop bc
        ret

balspr_norm:    dw BAL_Y,BAL_B,BAL_R
balspr_type:    dw 0,BAL_GIFT1,BAL_BOMB1,BAL_STEEL

; ---------------------------------------------------------------------
; act intro card.  Returns Z normally, NZ if demo aborted by a key
; ---------------------------------------------------------------------
act_intro:
 call clear_scene
 call act_ptr
 ld de,4
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 push hl
 ex de,hl
 ld c,33
 call bigc
 pop hl
 inc hl
 ld e,(hl)
 inc hl
 ld d,(hl)
 ex de,hl
 ld c,43
 call textc
 call present
 ld hl,mus_actstart0
 ld de,mus_actstart1
 call play_music
 ld a,1
 call play_jingle_wait
 call clear_scene
 xor a
 ret

act_number:
        ld b,'0'-1
.t:     inc b
        sub 10
        jr nc,.t
        add a,10+'0'
        ld c,a
        ld a,b
        cp '0'
        jr z,.one
        ld (de),a
        inc de
.one:   ld a,c
        ld (de),a
        inc de
        xor a
        ld (de),a
        ret

; copy zero-terminated HL -> DE, DE left at terminator
strcpy:
        ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        jr strcpy

; ---------------------------------------------------------------------
; main play loop for one act.  Sets gameresult 0 clear / 1 over / 2 quit
; ---------------------------------------------------------------------
play_act:
        ld a,2
        ld (fullpres),a
        ld a,(frames)
        ld (nextframe),a
        sub 2
        ld (sim_frame),a
.loop:
        ld a,2
        call syncframe
        call present
        call snd_tick
        call get_controls
        ; pause / demo abort
        ld a,(demo)
        or a
        jr z,.nd
        call readinput
        or a
        jr z,.dnk
        ld a,1
        ld (demo_key),a
        ld a,2
        ld (gameresult),a
        ret
.dnk:   ld hl,(demo_timer)
        inc hl
        ld (demo_timer),hl
        ld a,h
        cp 3                    ; ~30 s of demo
        jr c,.nd2
        ld a,2
        ld (gameresult),a
        ret
.nd:    ld a,16
        call key_test
        call nz,pause_game
        ld a,(gameresult)
        cp 2
        ret z
.nd2:
        call timed_update
        call render

        ; end conditions
        ld a,(endtimer)
        or a
        jr z,.loop
        dec a
        ld (endtimer),a
        jr nz,.loop
        ret

; ---------------------------------------------------------------------
get_controls:
        ld a,(demo)
        or a
        jr z,.p
        call ai_input
        jr .s
.p:     call readinput
.s:     ld b,a
        ld a,(inp)
        ld (inp_prev),a
        cpl
        and b
        ld (inp_new),a
        ld a,b
        ld (inp),a
        ret

; ---------------------------------------------------------------------
; one game update (25 Hz)
; ---------------------------------------------------------------------
timed_update:
        ; Rendering may take three PAL fields; retain the original 25 Hz rules
        ; and 50 Hz collision/physics substeps using a bounded accumulator.
        ld a,(frames)
        ld b,a
        ld a,(sim_frame)
        ld c,a
        ld a,b
        sub c
        cp 8
        jr c,.step
        ld a,b
        sub 8
        ld (sim_frame),a
        ld a,8
.step:  cp 2
        ret c
        push af
        call update
        ld hl,sim_frame
        inc (hl)
        inc (hl)
        pop af
        sub 2
        jr .step
update:
        ld hl,tickpar
        inc (hl)
        ld a,(endtimer)
        or a
        jr nz,.frozen
        call move_seesaw
.frozen:
        ld a,2
        ld b,a
        ld a,(pw_slow)
        or a
        jr z,.ss
        ld b,1
.ss:    ld a,b
        ld (substeps),a
.sub:   push bc
        call move_rows
        ld ix,clown0
        call clown_step
        ld ix,clown1
        call clown_step
        pop bc
        djnz .sub
        call clown_tick
        call bob_rows
        call monkey_update
        call pies_update
        call hoop_update
        call tokens_update
        call freeb_update
        call parts_update
        call popups_update
        call timers_update
        call check_end
        call anim_bg
        ld a,(tickpar)
        and 3
        ret nz
        ld a,(hud_req)
        or a
        ret z
        ld b,a
        xor a
        ld (hud_req),a
        dec b
        jp z,hud_draw
        jp hud_partial

hud_partial_req:        ; request score/combo/bar refresh unless full pending
        ld a,(hud_req)
        or a
        ret nz
        ld a,2
        ld (hud_req),a
        ret

; ---------------------------------------------------------------------
; background colour cycling: barber-pole stripes roll down the tent poles
; so the dirty-span bookkeeping is unaffected.
; ---------------------------------------------------------------------
anim_bg:
 ret

move_seesaw:
        ld a,(flipcool)
        or a
        jr z,.fc
        dec a
        ld (flipcool),a
.fc:    ld a,(flipanim)
        or a
        jr z,.fa
        dec a
        ld (flipanim),a
.fa:    ; flip on fire
        ld a,(inp_new)
        and $10
        jr z,.nf
        ld a,(flipcool)
        or a
        jr nz,.nf
        call find_seated
        jr nz,.nf
        ld a,(tilt)
        xor 1
        ld (tilt),a
        ld a,8
        ld (flipcool),a
        ld a,2
        ld (flipanim),a
        ld hl,sfx_flip
        call sfx
.nf:    ; movement
        ld a,(inp)
        and 3
        jr nz,.mv
        ld hl,0
        ld (see_v),hl
        ret
.mv:    ld c,a
        ; accelerate (first press moves a whole pixel at once)
        ld hl,(see_v)
        ld a,h
        or l
        ld de,80
        jr nz,.acc
        ld de,256
.acc:   add hl,de
        ld a,(piestick)
        or a
        ld de,720               ; max 2.8 px/update
        jr z,.mx
        ld de,300
.mx:    push hl
        or a
        sbc hl,de
        pop hl
        jr c,.ok
        ex de,hl
.ok:    ld a,h
        or l
        jr nz,.nz
        ld hl,192
.nz:    ld (see_v),hl
        ex de,hl
        ld hl,(see_x)
        bit 0,c
        jr z,.right
        or a
        sbc hl,de
        jr .clamp
.right: add hl,de
.clamp: ; limits: hw+4 .. 123-hw
        ld a,(see_hw)
        add a,4
        cp h
        jr c,.l1
        jr z,.l1
        ld h,a
        ld l,0
.l1:    ld a,(see_hw)
        ld b,a
        ld a,123
        sub b
        cp h
        jr nc,.l2
        ld h,a
        ld l,0
.l2:    ld (see_x),hl
        ret

; find seated clown -> IX, Z if found
find_seated:
        ld ix,clown0
        ld a,(ix+CS_STATE)
        cp S_SEAT
        ret z
        ld ix,clown1
        ld a,(ix+CS_STATE)
        cp S_SEAT
        ret

; ---------------------------------------------------------------------
; rows movement (per substep)
; ---------------------------------------------------------------------
move_rows:
        ld a,(nrows)
        or a
        ret z
        ld b,a
        ld ix,rows
.l:     ld l,(ix+2)
        ld h,(ix+3)
        ld e,(ix+4)
        ld d,(ix+5)
        add hl,de
        ld a,h
        and $7F
        ld (ix+3),a
        ld (ix+2),l
        ld de,8
        add ix,de
        djnz .l
        ret

bob_rows:
        ld a,(nrows)
        or a
        ret z
        ld b,a
        ld hl,rowphase
        inc (hl)
        ld a,(actflags)
        and AF_BOB
        jr z,.nb
        ld a,(hl)
        add a,a
        and 63
        ld hl,sintab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        sra a
        sra a
        sra a
        sra a
        sra a                   ; -4..3
        sra a                   ; -2..1
        jr .s
.nb:    xor a
.s:     ld c,a
        ld ix,rows
        ld hl,rowy
.l:     ld a,(ix+1)
        add a,c
        ld (hl),a
        inc hl
        ld de,8
        add ix,de
        djnz .l
        ret

; ---------------------------------------------------------------------
; clowns
; ---------------------------------------------------------------------
spawn_tower:            ; free clown slot becomes a tower clown
        ld ix,clown0
        ld a,(ix+CS_STATE)
        cp S_SEAT
        jr nz,.u
        ld ix,clown1
.u:     ld (ix+CS_STATE),S_TOWER
        ld (ix+CS_T),45
        ld (ix+CS_FL),0
        ld (ix+CS_POPS),0
        ld a,(respawn_side)
        xor 1
        ld (respawn_side),a
        ld (ix+CS_SIDE),a
        or a
        ld a,0
        jr z,.s
        ld a,121
.s:     ld (ix+CS_X+1),a
        ld (ix+CS_X),0
        ld (ix+CS_Y+1),22
        ld (ix+CS_Y),0
        ret

; per-update clown housekeeping
clown_tick:
        ld ix,clown0
        call .one
        ld ix,clown1
.one:   inc (ix+CS_ANIM)
        ld a,(ix+CS_STATE)
        cp S_TOWER
        jr z,.tower
        cp S_SPLAT
        jr z,.splat
        ret
.tower: dec (ix+CS_T)
        ret nz
        ; jump!
        ld (ix+CS_STATE),S_FLY
        ld (ix+CS_FL),0
        ld (ix+CS_POPS),0
        call rand
        and 63
        add a,100               ; 0.39 .. 0.64 px/substep
        ld l,a
        ld h,0
        ld a,(ix+CS_SIDE)
        or a
        jr z,.r
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
.r:     ld (ix+CS_VX),l
        ld (ix+CS_VX+1),h
        ld hl,-120
        ld (ix+CS_VY),l
        ld (ix+CS_VY+1),h
        ld a,(ix+CS_SIDE)
        or a
        ld a,6
        jr z,$+4
        ld a,115
        ld (ix+CS_X+1),a
        ld hl,sfx_jump
        jp sfx
.splat: dec (ix+CS_T)
        ret nz
        ld (ix+CS_STATE),S_NONE
        ld a,(lives)
        or a
        jr nz,.again
        ld a,1
        ld (gameresult),a
        ld a,2
        ld (endtimer),a
        ret
.again: ld a,(endtimer)
        or a
        ret nz
        jp spawn_tower

; physics substep for clown IX
clown_step:
        ld a,(ix+CS_STATE)
        cp S_FLY
        ret nz
        ld a,(ix+CS_CD)
        or a
        jr z,.cd
        dec (ix+CS_CD)
.cd:    ; gravity
        ld l,(ix+CS_VY)
        ld h,(ix+CS_VY+1)
        ld de,GRAV
        bit 7,h
        jr nz,.g                ; rising: full gravity
        ld a,(pw_umb)
        or a
        jr z,.g
        ld de,4
.g:     add hl,de
        ; cap fall speed
        bit 7,h
        jr nz,.nc
        ld a,(pw_umb)
        or a
        ld de,560
        jr z,.cap
        ld de,150
.cap:   push hl
        or a
        sbc hl,de
        pop hl
        jr c,.nc
        ex de,hl
.nc:    ld (ix+CS_VY),l
        ld (ix+CS_VY+1),h
        ; remember centre y for hoop crossing
        ld a,(ix+CS_Y+1)
        add a,4
        ld (prev_cy),a
        ; y += vy
        ld e,(ix+CS_Y)
        ld d,(ix+CS_Y+1)
        add hl,de
        ld (ix+CS_Y),l
        ld (ix+CS_Y+1),h
        ; x += vx
        ld l,(ix+CS_X)
        ld h,(ix+CS_X+1)
        ld e,(ix+CS_VX)
        ld d,(ix+CS_VX+1)
        add hl,de
        ld (ix+CS_X),l
        ld (ix+CS_X+1),h
        ; walls 4..117
        ld a,h
        cp 4
        jr c,.wl
        cp 118
        jr c,.ww
        ld (ix+CS_X+1),117
        jr .wneg
.wl:    ld (ix+CS_X+1),4
.wneg:  call neg_vx
        ld hl,sfx_wall
        call sfx
.ww:    ; ceiling
        ld a,(ix+CS_Y+1)
        bit 7,a
        jr nz,.ceil
        or a
        jr nz,.nceil
.ceil:  ld (ix+CS_Y+1),1
        ld (ix+CS_Y),0
        ld l,(ix+CS_VY)
        ld h,(ix+CS_VY+1)
        bit 7,h
        jr z,.nceil
        ; vy = -vy/2
        sra h
        rr l
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld (ix+CS_VY),l
        ld (ix+CS_VY+1),h
        ld hl,sfx_bonk
        call sfx
.nceil:
        call clown_balloons
        call clown_hoop
        call clown_monkey
        call clown_tokens
        call clown_freeb
        ; landing / floor
        ld a,(ix+CS_VY+1)
        bit 7,a
        ret nz                  ; rising
        ld a,(ix+CS_Y+1)
        add a,8                 ; feet
        cp 48
        ret c
        cp 52
        jr nc,.floor
        bit 3,(ix+CS_FL)
        ret nz
        set 3,(ix+CS_FL)
        jp try_land
.floor: cp 56
        ret c
        ; hit the floor
        ld a,(actflags)
        and AF_BONUS
        jr nz,.boing
        ld a,(pw_net)
        or a
        jr z,.splat
        dec a
        ld (pw_net),a
        ld a,1
        ld (hud_req),a
.boing: ld hl,-470
        ld (ix+CS_VY),l
        ld (ix+CS_VY+1),h
        ld (ix+CS_Y+1),47
        res 3,(ix+CS_FL)
        ld hl,sfx_launch
        call sfx
        ld hl,txt_boing
        ld a,(ix+CS_X+1)
        ld c,44
        jp popup_at
.splat: ld (ix+CS_STATE),S_SPLAT
        ld (ix+CS_T),40
        ld (ix+CS_Y+1),53
        ld a,(lives)
        dec a
        ld (lives),a
        ld hl,misses_act
        inc (hl)
        xor a
        ld (streak),a
        ld (combo),a
        ld a,1
        ld (hud_req),a
        ld hl,sfx_splat
        call sfx
        ld a,(ix+CS_X+1)
        add a,3
        ld b,a
        ld c,52
        ld a,1
        ld e,10
        call burst
        ld hl,txt_ouch
        ld a,(ix+CS_X+1)
        ld c,44
        jp popup_at

neg_vx:
        ld l,(ix+CS_VX)
        ld h,(ix+CS_VX+1)
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld (ix+CS_VX),l
        ld (ix+CS_VX+1),h
        ret

; feet are at plank height: decide landing / bonk / miss
try_land:
        ld a,(ix+CS_X+1)
        add a,3
        ld c,a                  ; clown centre x
        ld a,(see_x+1)
        ld b,a                  ; pivot
        ld a,(see_hw)
        inc a
        ld d,a                  ; reach
        ; offset = cx - pivot (signed)
        ld a,c
        sub b
        ld e,a                  ; signed offset
        ; raised side: tilt 0 -> right (offset >= 0)
        ld a,(tilt)
        or a
        ld a,e
        jr z,.r
        neg
.r:     ; A = offset toward raised end
        bit 7,a
        jr nz,.lowside
        cp d
        jr nc,.miss
        ; LANDED. zone
        ld e,a
        call find_seated
        jr nz,.miss             ; nobody to launch: treat as miss (rare)
        push ix
        pop iy                  ; IY = seated (will launch)
        ld ix,0                 ; restored below
        jr .land
.lowside:
        neg
        cp d
        jr nc,.miss
        ; bonk on the occupied end
        ld hl,-200
        ld (ix+CS_VY),l
        ld (ix+CS_VY+1),h
        res 3,(ix+CS_FL)
        ld (ix+CS_Y+1),40
        call neg_vx
        ld hl,sfx_bonk
        call sfx
        ld hl,txt_bonk
        ld a,(ix+CS_X+1)
        ld c,36
        jp popup_at
.miss:  ret
.land:  ; restore IX = lander (it was pushed? recompute: the flyer is the non-seated)
        ld ix,clown0
        ld a,(ix+CS_STATE)
        cp S_FLY
        jr z,.got
        ld ix,clown1
.got:   ; E = offset toward raised end (0..hw)
        push de
        ; seesaw tilts toward the lander
        ld a,(tilt)
        xor 1
        ld (tilt),a
        ld a,2
        ld (flipanim),a
        ; lander becomes seated
        ld (ix+CS_STATE),S_SEAT
        ld (ix+CS_T),6          ; squash anim
        ; combo bookkeeping: empty flight resets combo
        ld a,(ix+CS_POPS)
        or a
        jr nz,.kc
        ld (combo),a
.kc:    ; keep incoming vx for the launch
        ld l,(ix+CS_VX)
        ld h,(ix+CS_VX+1)
        ; launch the other clown (IY)
        ld (iy+CS_STATE),S_FLY
        ld (iy+CS_FL),0
        ld (iy+CS_POPS),0
        ld (iy+CS_CD),0
        ; steer
        ld a,(inp)
        bit 0,a
        jr z,.s1
        ld de,-70
        add hl,de
.s1:    bit 1,a
        jr z,.s2
        ld de,70
        add hl,de
.s2:    ; clamp |vx| <= 230
        bit 7,h
        jr nz,.vneg
        ld de,230
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.vok
        ex de,hl
        jr .vok
.vneg:  ld de,-230
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.vok
        ex de,hl
.vok:   ld (iy+CS_VX),l
        ld (iy+CS_VX+1),h
        ; launch position: other end (now raised)
        ld a,(see_hw)
        ld c,a
        ld a,(see_x+1)
        ld b,a
        ld a,(tilt)             ; new tilt: low side = lander side
        or a
        jr z,.lr                ; left low -> raised right
        ld a,b
        sub c
        jr .lp
.lr:    ld a,b
        add a,c
        sub 6
.lp:    ld (iy+CS_X+1),a
        ld (iy+CS_X),0
        ld (iy+CS_Y+1),41
        ld (iy+CS_Y),0
        ; zone -> launch speed
        pop de                  ; E = offset
        ld a,(see_hw)
        sub 2
        cp e
        jr c,.tip
        jr z,.tip
        srl a
        cp e
        jr c,.mid
        ld hl,-333              ; weak 1.30
        jr .setv
.mid:   ld hl,-410              ; mid 1.60
        jr .setv
.tip:   ld hl,-500              ; tip 1.95
        set 2,(iy+CS_FL)
        push hl
        push iy
        ld hl,txt_perfect
        ld a,(iy+CS_X+1)
        ld c,32
        call popup_at
        ld de,$0100
        call add_score_pts
        pop iy
        pop hl
.setv:  ld (iy+CS_VY),l
        ld (iy+CS_VY+1),h
        ld hl,sfx_launch
        call sfx
        xor a
        ld (ai_t),a
        ; streak
        ld hl,streak
        inc (hl)
        ld a,(hl)
        ld hl,best_streak
        cp (hl)
        jr c,$+3
        ld (hl),a
        ; every 5 -> bonus
        ld b,a
.m5:    sub 5
        jr z,.five
        jr nc,.m5
        ret
.five:  ld a,b
        push af
        ld hl,txt_streak
        ld de,strbuf
        call strcpy
        pop af
        call act_number
        ld hl,strbuf
        ld c,26
        call popup_center
        ld de,$0500
        call add_score_pts
        ld b,64
        ld c,30
        ld a,0
        ld e,14
        call confetti
        ld hl,sfx_power
        jp sfx

; ---------------------------------------------------------------------
; clown vs balloons
; ---------------------------------------------------------------------
clown_balloons:
        ld a,(ix+CS_CD)
        or a
        ret nz
        ld a,(nrows)
        or a
        ret z
        ld b,a
        ld c,0
.r:     push bc
        ; vertical overlap: clown y..y+8 with row y..y+4
        ld hl,rowy
        ld a,c
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld d,a                  ; row y
        ld a,(ix+CS_Y+1)
        add a,8
        cp d
        jr c,.nx                ; clown bottom above row
        ld a,d
        add a,4
        ld e,a
        ld a,(ix+CS_Y+1)
        cp e
        jr z,.ov
        jr nc,.nx
.ov:    ; rel = (cx - off) & 127
        push bc
        ld a,c
        add a,a
        add a,a
        add a,a
        ld hl,rows+3
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld e,(hl)               ; offset
        pop bc
        ld a,(ix+CS_X+1)
        sub e
        and $7F
        ld d,a                  ; rel
        sub 3
        and $7F
        rrca
        rrca
        rrca
        and 15
        ld b,a                  ; first candidate slot
        ld e,3                  ; check 3 consecutive slots
.s:     ld a,b
        add a,a
        add a,a
        add a,a
        sub d
        and $7F                 ; (s*8 - rel) & 127
        cp 7
        jr c,.hit
        cp 125
        jr c,.ns
.hit:   call slot_alive
        jr z,.ns
        push bc
        push de
        call hit_balloon
        pop de
        pop bc
        ld a,(ix+CS_CD)
        or a
        jr nz,.done
.ns:    ld a,b
        inc a
        and 15
        ld b,a
        dec e
        jr nz,.s
.nx:    pop bc
        inc c
        dec b
        jr nz,.r
        ret
.done:  pop bc
        ret

; screen x of slot B row C -> A
slot_x:
        push hl
        ld a,c
        add a,a
        add a,a
        add a,a
        ld hl,rows+3
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,(hl)
        and $7F
        pop hl
        ret

row_y:  ; row C -> A
        push hl
        ld hl,rowy
        ld a,c
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        ret

; clown IX hits slot B row C
hit_balloon:
        call slot_type
        cp T_STEEL
        jr nz,pop_balloon
        ; steel: crack to normal, bounce clown
        ld (hl),T_NORM
        push bc
        call slot_sprite
        pop bc
        call strip_slot
        ld (ix+CS_CD),4
        ld l,(ix+CS_VY)
        ld h,(ix+CS_VY+1)
        bit 7,h
        jr z,.dn
        sra h
        rr l
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld (ix+CS_VY),l
        ld (ix+CS_VY+1),h
.dn:    ld hl,sfx_clang
        call sfx
        call slot_x
        ld e,a
        call row_y
        ld c,a
        ld a,e
        ld hl,txt_clang
        jp popup_at

; pop slot B row C (alive). IX = clown (or any; CS_POPS incremented)
pop_balloon:
        call slot_type
        push af                 ; type
        call slot_kill
        ld (hl),T_NORM
        push bc
        ld hl,0
        call strip_slot         ; erase from strips
        pop bc
        ld hl,balloons_left
        dec (hl)
        inc (ix+CS_POPS)
        ld a,(combo)
        cp 99
        jr nc,$+5
        inc a
        ld (combo),a
        ; row alive count
        push bc
        ld a,c
        add a,a
        add a,a
        add a,a
        ld hl,rows
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        dec (hl)
        ld a,(hl)
        ld (rowleft),a
        pop bc
        ; points: (nrows - row) * 10 per balloon, x min(combo,8), x2 power
        ld a,(nrows)
        sub c
        ld e,a                  ; BCD tens digit count (1..4) -> $10*n
        ld a,e
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld a,(combo)
        cp 9
        jr c,$+4
        ld a,8
        ld (mult),a
        call mul_bcd            ; DE = DE*mult (BCD)
        call add_score_pts      ; returns DE final (after x2)
        ; popup "+pts"
        push bc
        call slot_x
        ld (tmpx),a
        call row_y
        ld (tmpy),a
        call bcd_to_str
        ld a,(tmpy)
        ld c,a
        ld a,(tmpx)
        ld hl,strbuf
        call popup_at
        ; particles
        ld a,(tmpx)
        add a,2
        ld b,a
        ld a,(tmpy)
        add a,2
        ld c,a
        pop de                  ; E = slot? (we pushed BC) -> restore below
        push de
        ld a,e                  ; row index C was pushed in BC -> E
        ld hl,rowspr
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc a                   ; logical colour 1..3
        ld e,6
        call burst
        pop bc
        ; combo blip
        ld a,(combo)
        add a,a
        add a,a
        neg
        add a,60
        ld (sfx_pop_var+2),a
        ld hl,sfx_pop_var
        call sfx
        pop af                  ; type
        cp T_GIFT
        jr nz,.ng
        push bc
        call slot_x
        ld b,a
        call row_y
        ld c,a
        call spawn_token
        pop bc
        jr .rowchk
.ng:    cp T_BOMB
        jr nz,.rowchk
        ; KABOOM: neighbours in this row
        push bc
        call slot_x
        ld b,a
        call row_y
        ld c,a
        ld a,3
        ld e,14
        call burst
        ld hl,sfx_boom
        call sfx
        pop bc
        push bc
        ld a,b
        dec a
        and 15
        ld b,a
        call chain_pop
        pop bc
        push bc
        ld a,b
        inc a
        and 15
        ld b,a
        call chain_pop
        pop bc
        ; same x in rows above and below
        push bc
        call slot_x
        pop bc
        ld d,a
        push bc
        push de
        ld a,c
        or a
        jr z,.nab
        dec c
        ld a,d
        call chain_at_x
.nab:   pop de
        pop bc
        push bc
        push de
        ld a,(nrows)
        dec a
        cp c
        jr z,.nbe
        inc c
        ld a,d
        call chain_at_x
.nbe:   pop de
        pop bc
.rowchk:
        ld a,(rowleft)
        or a
        jr nz,.prog
        ; row cleared!
        push bc
        ld hl,txt_rowclear
        ld c,20
        call popup_center
        ld de,$0500
        call add_score_pts
        pop bc
        push bc
        call row_y
        ld c,a
        ld b,64
        ld a,0
        ld e,16
        call confetti
        ld hl,sfx_power
        call sfx
        pop bc
.prog:  jp hud_partial_req

; pop slot at screen x (tmpx) in row C if alive
chain_at_x:     ; A = screen x, C = row
        ; slot = ((x - off + 2) & 127) / 8
        ld (tmpx),a
        push bc
        ld a,c
        add a,a
        add a,a
        add a,a
        ld hl,rows+3
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(tmpx)
        sub (hl)
        add a,2
        and $7F
        rrca
        rrca
        rrca
        and 15
        ld b,a
        call chain_pop
        pop bc
        ret

chain_pop:      ; pop slot B row C if alive and not steel
        call slot_alive
        ret z
        call slot_type
        cp T_STEEL
        ret z
        jp pop_balloon

; ---------------------------------------------------------------------
; BCD helpers
; ---------------------------------------------------------------------
; DE (BCD 4 digits) * (mult) -> DE
mul_bcd:
        push bc
        push hl
        ld a,(mult)
        or a
        jr nz,$+3
        inc a
        ld b,a
        ld hl,0
.l:     ld a,l
        add a,e
        daa
        ld l,a
        ld a,h
        adc a,d
        daa
        ld h,a
        djnz .l
        ex de,hl
        pop hl
        pop bc
        ret

; add DE (BCD) to score, doubled if x2 active. DE returned = amount added
add_score_pts:
        push bc
        push hl
        ld a,(pw_x2)
        or a
        jr z,.n
        ld a,2
        ld (mult),a
        call mul_bcd
.n:     ld hl,score+2
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
        jr nc,.nov
        ld a,$99
        ld (score),a
        ld (score+1),a
        ld (score+2),a
.nov:   ; extra life?
        ld a,(nextlife)
        ld b,a
        ld a,(score)
        cp b
        jr c,.x
        ld a,b
        add a,2
        daa
        ld (nextlife),a
        ld a,(lives)
        cp 9
        jr nc,.x
        inc a
        ld (lives),a
        push de
        ld a,1
        ld (hud_req),a
        ld hl,txt_extralife
        ld c,14
        call popup_center
        ld hl,sfx_1up
        call sfx
        pop de
.x:     call hud_partial_req
        pop hl
        pop bc
        ret

; BCD DE -> "+nnnn" in strbuf (no leading zeros)
bcd_to_str:
        ld hl,strbuf
        ld (hl),'+'
        inc hl
        ld c,0                  ; started flag
        ld a,d
        call .two
        ld a,e
        call .two
        ld a,c
        or a
        jr nz,.e
        ld (hl),'0'
        inc hl
.e:     ld (hl),0
        ret
.two:   push af
        rrca
        rrca
        rrca
        rrca
        call .dig
        pop af
.dig:   and 15
        jr nz,.p
        bit 0,c
        ret z
.p:     add a,'0'
        ld (hl),a
        inc hl
        ld c,1
        ret

; ---------------------------------------------------------------------
; hoop of fire
; ---------------------------------------------------------------------
hoop_update:
        ld a,(hoop)
        or a
        ret z
        ld a,(hoop+2)
        inc a
        ld (hoop+2),a
        and 63
        ld hl,sintab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        sra a                   ; -64..63
        sra a                   ; -32..31
        ld b,a
        sra a
        add a,b                 ; -48..46
        add a,64
        ld (hoop+1),a           ; centre x 16..110
        ret

clown_hoop:
        ld a,(hoop)
        or a
        ret z
        ; did centre y cross line 35?
        ld a,(ix+CS_Y+1)
        add a,4
        ld c,a
        ld a,(prev_cy)
        cp 36
        jr c,.wasabove
        ; was below (>=36): crossing upward if now < 36
        ld a,c
        cp 36
        ret nc
        ld e,1                  ; up flag
        jr .cross
.wasabove:
        ld a,c
        cp 36
        ret c
        ld e,2
.cross: ld a,(ix+CS_X+1)
        add a,3
        ld b,a
        ld a,(hoop+1)
        ld d,a
        ld a,b
        sub d                   ; offset from hoop centre
        jp p,.pos
        neg
.pos:   cp 6
        jr c,.through
        cp 10
        ret nc
        ; rim!
        call neg_vx
        ld hl,sfx_bonk
        call sfx
        ld hl,txt_hot
        ld a,(ix+CS_X+1)
        ld c,30
        jp popup_at
.through:
        ld a,(ix+CS_FL)
        and e
        ret nz
        ld a,(ix+CS_FL)
        or e
        ld (ix+CS_FL),a
        ld a,(combo)
        inc a
        ld (combo),a
        inc (ix+CS_POPS)
        ld de,$0300
        call add_score_pts
        ld hl,txt_hoop
        ld a,(hoop+1)
        sub 8
        ld c,28
        call popup_at
        ld a,(hoop+1)
        ld b,a
        ld c,35
        ld a,1
        ld e,10
        call burst
        ld hl,sfx_hoop
        jp sfx

; ---------------------------------------------------------------------
; monkey and pies
; ---------------------------------------------------------------------
monkey_update:
        ld ix,monkey
        ld a,(ix+0)
        or a
        ret z
        ld a,(ix+5)             ; stun
        or a
        jr z,.ns
        dec (ix+5)
        ret
.ns:    inc (ix+3)              ; anim
        ld a,(ix+3)
        and 1
        jr nz,.nomove
        ld a,(ix+1)
        add a,(ix+2)
        ld (ix+1),a
        cp 8
        jr c,.flip
        cp 113
        jr c,.nomove
.flip:  ld a,(ix+2)
        neg
        ld (ix+2),a
.nomove:
        dec (ix+4)
        ret nz
        call rand
        and 63
        add a,40
        ld (ix+4),a
        ; throw a pie
        ld iy,pies
        ld b,3
.f:     ld a,(iy+0)
        or a
        jr z,.got
        ld de,8
        add iy,de
        djnz .f
        ret
.got:   ld (iy+0),1
        ld a,(ix+1)
        add a,2
        ld (iy+1),a
        ld (iy+3),36
        ld (iy+2),0
        ld (iy+4),0
        ld (iy+5),0
        ld hl,sfx_throw
        jp sfx

pies_update:
        ld iy,pies
        ld b,3
.l:     push bc
        call .one
        pop bc
        ld de,8
        add iy,de
        djnz .l
        ret
.one:   ld a,(iy+0)
        or a
        ret z
        cp 2
        jr nz,.fall
        dec (iy+6)
        ret nz
        ld (iy+0),0
        ret
.fall:  ; vy += 12 ; y += vy
        ld l,(iy+4)
        ld h,(iy+5)
        ld de,12
        add hl,de
        ld (iy+4),l
        ld (iy+5),h
        ld e,(iy+2)
        ld d,(iy+3)
        add hl,de
        ld (iy+2),l
        ld (iy+3),h
        ; hits flying clown?
        ld ix,clown0
        call .vsclown
        ld ix,clown1
        call .vsclown
        ; hits seesaw?
        ld a,(iy+3)
        add a,2
        cp 47
        ret c
        cp 51
        jr nc,.floor
        ld a,(see_x+1)
        ld b,a
        ld a,(iy+1)
        add a,2
        sub b
        jp p,$+5
        neg
        ld b,a
        ld a,(see_hw)
        inc a
        cp b
        ret c
        ; splat on seesaw
        ld a,75
        ld (piestick),a
        ld (iy+0),0
        ld hl,sfx_splat
        call sfx
        ld hl,txt_splat
        ld a,(iy+1)
        ld c,40
        jp popup_at
.floor: cp 56
        ret c
        ld (iy+0),2
        ld (iy+3),54
        ld (iy+6),25
        ret
.vsclown:
        ld a,(ix+CS_STATE)
        cp S_FLY
        ret nz
        ld a,(iy+1)
        sub (ix+CS_X+1)
        add a,3
        cp 10
        ret nc
        ld a,(iy+3)
        sub (ix+CS_Y+1)
        add a,2
        cp 11
        ret nc
        ; pie in the face!
        ld (iy+0),0
        call rand
        and 127
        sub 64
        ld l,a
        rla
        sbc a,a
        ld h,a
        ld e,(ix+CS_VX)
        ld d,(ix+CS_VX+1)
        add hl,de
        ld (ix+CS_VX),l
        ld (ix+CS_VX+1),h
        ld hl,sfx_splat
        call sfx
        ld hl,txt_pied
        ld a,(ix+CS_X+1)
        ld c,(ix+CS_Y+1)
        jp popup_at

clown_monkey:
        ld a,(monkey)
        or a
        ret z
        ld a,(monkey+5)
        or a
        ret nz
        ld a,(monkey+1)
        sub (ix+CS_X+1)
        add a,7
        cp 14
        ret nc
        ld a,(ix+CS_Y+1)
        sub 29
        add a,8
        cp 16
        ret nc
        ld a,100
        ld (monkey+5),a
        ld de,$0250
        call add_score_pts
        ld hl,txt_ook
        ld a,(monkey+1)
        ld c,24
        call popup_at
        ld hl,sfx_bonk
        jp sfx

; ---------------------------------------------------------------------
; power-up tokens
; ---------------------------------------------------------------------
spawn_token:    ; B = x, C = y  (preserves IY)
        push iy
        call spawn_token2
        pop iy
        ret
spawn_token2:
        ld iy,tokens
        ld e,3
.f:     ld a,(iy+0)
        or a
        jr z,.got
        push de
        ld de,8
        add iy,de
        pop de
        dec e
        jr nz,.f
        ret
.got:   call rand
        and 15
        ld hl,token_odds
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc a
        ld (iy+0),a
        ld a,b
        cp 117
        jr c,$+4
        ld a,116
        ld (iy+1),a
        ld (iy+3),c
        ld (iy+2),0
        ret

token_odds:     db 0,0,1,1,2,2,3,3,4,4,5,5,0,3,2,6

tokens_update:
        ld iy,tokens
        ld b,3
.l:     push bc
        call .one
        pop bc
        ld de,8
        add iy,de
        djnz .l
        ret
.one:   ld a,(iy+0)
        or a
        ret z
        ld l,(iy+2)
        ld h,(iy+3)
        ld de,110
        add hl,de
        ld (iy+2),l
        ld (iy+3),h
        ld a,h
        cp 50
        ret c
        cp 56
        jr nc,.gone
        ; caught by plank?
        ld a,(see_x+1)
        ld b,a
        ld a,(iy+1)
        add a,3
        sub b
        jp p,$+5
        neg
        ld b,a
        ld a,(see_hw)
        add a,3
        cp b
        ret c
        jp collect_token
.gone:  ld (iy+0),0
        ret

clown_tokens:
        ld iy,tokens
        ld b,3
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        ld a,(iy+1)
        sub (ix+CS_X+1)
        add a,6
        cp 13
        jr nc,.n
        ld a,(iy+3)
        sub (ix+CS_Y+1)
        add a,6
        cp 15
        jr nc,.n
        call collect_token
.n:     pop bc
        ld de,8
        add iy,de
        djnz .l
        ret

collect_token:  ; IY = token
        ld a,(iy+0)
        dec a
        ld (iy+0),0
        push af
        ld hl,sfx_power
        call sfx
        ld a,1
        ld (hud_req),a
        pop af
        push af
        add a,a
        ld hl,tokname
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,18
        call popup_center
        ld de,$0100
        call add_score_pts
        pop af
        or a
        jr nz,.n0
        ld a,250
        ld (pw_wide),a
        ld a,15
        ld (see_hw),a
        jp clamp_see
.n0:    dec a
        jr nz,.n1
        ld a,200
        ld (pw_slow),a
        ret
.n1:    dec a
        jr nz,.n2
        ld a,(pw_net)
        cp 3
        ret nc
        inc a
        ld (pw_net),a
        ret
.n2:    dec a
        jr nz,.n3
        ld a,250
        ld (pw_x2),a
        ret
.n3:    dec a
        jr nz,.n4
        ld a,250
        ld (pw_umb),a
        ret
.n4:    dec a
        jr nz,.n5
        jp fireworks
.n5:    ld a,(lives)
        cp 9
        ret nc
        inc a
        ld (lives),a
        ld hl,sfx_1up
        jp sfx

clamp_see:
        ld hl,(see_x)
        ld a,(see_hw)
        add a,4
        cp h
        jr c,.a
        ld h,a
.a:     ld a,(see_hw)
        ld b,a
        ld a,123
        sub b
        cp h
        jr nc,.b
        ld h,a
.b:     ld (see_x),hl
        ret

tokname:        dw txt_wide,txt_slow,txt_net,txt_x2,txt_umb,txt_fire,txt_1up
tokspr1:        dw TOK_WIDE1,TOK_SLOW1,TOK_NET1,TOK_X21,TOK_UMB1,TOK_FIRE1,TOK_1UP1

; FIREWORKS: pop up to 6 random balloons
fireworks:
        push ix
        call fireworks2
        pop ix
        ret
fireworks2:
        ld a,6
        ld (fw_n),a
        ld a,40
        ld (fw_try),a
.l:     ld a,(nrows)
        or a
        ret z
        ld a,(balloons_left)
        or a
        ret z
        ld hl,fw_try
        dec (hl)
        ret z
        call rand
        and 3
        ld c,a
        ld a,(nrows)
        dec a
        cp c
        jr c,.l
        call rand
        and 15
        ld b,a
        call slot_alive
        jr z,.l
        call slot_type
        cp T_STEEL
        jr nz,.ok
        ld (hl),T_NORM
.ok:    push bc
        call slot_x
        ld b,a
        pop de
        push de
        ld c,e
        call row_y
        ld c,a
        ld a,2
        ld e,10
        call confetti
        pop bc
        ld ix,clown0            ; credit pops to a clown (any)
        call pop_balloon
        ld hl,fw_n
        dec (hl)
        jr nz,.l
        ld hl,sfx_boom
        jp sfx

; ---------------------------------------------------------------------
; free balloons (bonus rounds)
; struct: +0 active (sprite idx+1), +1 x, +2/3 y 8.8, +4/5 vy
; ---------------------------------------------------------------------
freeb_update:
        ld a,(actflags)
        and AF_BONUS
        ret z
        ; timer
        ld hl,(bonus_time)
        ld a,h
        or l
        jr z,.tdone
        dec hl
        ld (bonus_time),hl
        ld a,l
        and 15
        jr nz,.spawn
        ld a,1
        ld (hud_req),a
        jr .spawn
.tdone: ld a,(endtimer)
        or a
        jr nz,.move
        ld a,30
        ld (endtimer),a
        jr .move
.spawn: ld hl,spawn_t
        dec (hl)
        jp p,.move
        ld (hl),14
        ld iy,freeb
        ld b,12
.f:     ld a,(iy+0)
        or a
        jr z,.got
        ld de,8
        add iy,de
        djnz .f
        jr .move
.got:   call rand
        and 7
        ld c,a
        cp 7
        ld a,4                  ; gold
        jr z,.st
        ld a,(actflags)
        and AF_PRIZE
        jr z,.col
        ld a,c
        cp 3
        ld a,5                  ; gift
        jr c,.st
.col:   ld a,c
.m3:    cp 3
        jr c,.ok3
        sub 3
        jr .m3
.ok3:   inc a
.st:
        ld (iy+0),a
        call rand
        and 63
        ld c,a
        call rand
        and 31
        add a,c
        add a,12
        ld (iy+1),a
        ld (iy+3),50
        ld (iy+2),0
        call rand
        and 63
        add a,40
        neg
        ld (iy+4),a
        ld (iy+5),$FF
.move:  ld iy,freeb
        ld b,12
.m:     ld a,(iy+0)
        or a
        jr z,.mn
        ld l,(iy+2)
        ld h,(iy+3)
        ld e,(iy+4)
        ld d,(iy+5)
        add hl,de
        ld (iy+2),l
        ld (iy+3),h
        ld a,h
        cp 250
        jr c,.mn
        ld (iy+0),0
.mn:    ld de,8
        add iy,de
        djnz .m
        ret

clown_freeb:
        ld a,(actflags)
        and AF_BONUS
        ret z
        ld iy,freeb
        ld b,12
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        ld a,(iy+1)
        sub (ix+CS_X+1)
        add a,4
        cp 11
        jr nc,.n
        ld a,(iy+3)
        sub (ix+CS_Y+1)
        add a,5
        cp 14
        jr nc,.n
        call pop_free
.n:     pop bc
        ld de,8
        add iy,de
        djnz .l
        ret

pop_free:
        ld a,(iy+0)
        ld (iy+0),0
        push af
        ld hl,bonus_pops
        inc (hl)
        inc (ix+CS_POPS)
        ld a,(combo)
        inc a
        ld (combo),a
        cp 9
        jr c,$+4
        ld a,8
        ld (mult),a
        pop af
        push af
        ld de,$0100
        cp 4                    ; gold
        jr nz,.ng
        ld de,$0500
.ng:    call mul_bcd
        call add_score_pts
        call bcd_to_str
        ld a,(iy+1)
        ld c,(iy+3)
        ld hl,strbuf
        call popup_at
        ld a,(iy+1)
        add a,2
        ld b,a
        ld a,(iy+3)
        add a,2
        ld c,a
        pop af
        push af
        ld e,8
        call burst
        ld hl,sfx_pop_var
        call sfx
        pop af
        cp 5                    ; gift
        ret nz
        ld b,(iy+1)
        ld c,(iy+3)
        jp spawn_token

freeb_spr:      dw BAL_Y,BAL_B,BAL_R,BAL_GOLD,BAL_GIFT1

; ---------------------------------------------------------------------
; particles: +0 life, +1 colour(logical), +2/3 x 8.8, +4/5 y 8.8, +6 vx, +7 vy
; ---------------------------------------------------------------------
; burst at B,C colour A count E
burst:
        ld (pb_col),a
        xor a
        ld (pb_style),a
        jr spawn_parts
confetti:
        ld (pb_col),a
        ld a,1
        ld (pb_style),a
spawn_parts:
        push iy
        call spawn_parts2
        pop iy
        ret
spawn_parts2:
        ld iy,parts
        ld d,NPARTS
.f:     ld a,(iy+0)
        or a
        jr nz,.n
        call rand
        and 15
        add a,10
        ld (iy+0),a
        ld a,(pb_col)
        or a
        jr nz,.c
        call rand
        and 3
        jr nz,.c
        inc a
.c:     ld (iy+1),a
        ld (iy+3),b
        ld (iy+2),128
        ld (iy+5),c
        ld (iy+4),128
        ld a,(pb_style)
        or a
        jr nz,.conf
        call rand
        and 63
        sub 32                  ; vx -0.5..0.5 px
        call .s16
        ld (iy+6),l
        ld (iy+7),h
        call rand
        and 63
        sub 48                  ; vy -0.75..0.25
        call .s16
        ld (iy+8),l
        ld (iy+9),h
        jr .dn
.conf:  call rand
        and 127
        sub 64
        call .s16
        ld (iy+6),l
        ld (iy+7),h
        call rand
        and 31
        sub 32
        call .s16
        ld (iy+8),l
        ld (iy+9),h
        ld (iy+0),36
.dn:    dec e
        ret z
.n:     push de
        ld de,PT_SIZE
        add iy,de
        pop de
        dec d
        jp nz,.f
        ret
.s16:   ; A signed (1/64 px) -> HL 8.8 (x4)
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        ret

parts_update:
        ld iy,parts
        ld b,NPARTS
.l:     ld a,(iy+0)
        or a
        jr z,.n
        dec (iy+0)
        ld l,(iy+2)
        ld h,(iy+3)
        ld e,(iy+6)
        ld d,(iy+7)
        add hl,de
        ld (iy+2),l
        ld (iy+3),h
        ld a,h
        cp 128
        jr nc,.kill
        ld l,(iy+8)
        ld h,(iy+9)
        ld de,10                ; gravity
        add hl,de
        ld (iy+8),l
        ld (iy+9),h
        ld e,(iy+4)
        ld d,(iy+5)
        add hl,de
        ld (iy+4),l
        ld (iy+5),h
        ld a,h
        cp 57
        jr c,.n
.kill:  ld (iy+0),0
.n:     ld de,PT_SIZE
        add iy,de
        djnz .l
        ret

parts_draw:
 ld iy,parts
 ld b,NPARTS
.loop: push bc
 ld a,(iy+0)
 or a
 jr z,.next
 ld b,(iy+3)
 ld c,(iy+5)
 ld hl,SPARK
 call drawspr
.next: ld de,PT_SIZE
 add iy,de
 pop bc
 djnz .loop
 ret

popup_at:
        rrca
        rrca
        and $1F
        ld b,a
        push hl
        call strlen
        pop hl
        add a,b
        cp 33
        jr c,popup_col
        ld a,32
        sub b
        ld b,a
        call strlen
        ld e,a
        ld a,32
        sub e
        ld b,a
        jr popup_col
popup_center:   ; HL = text, C = y
        call strlen
        ld b,a
        ld a,32
        sub b
        srl a
        ld b,a
popup_col:      ; HL = text, B = column, C = y   (preserves IY)
        push iy
        call popup_col2
        pop iy
        ret
popup_col2:
        ld a,c
        cp 52
        jr c,$+4
        ld c,51
        push hl
        ld iy,popups
        ld e,4
.f:     ld a,(iy+0)
        or a
        jr z,.got
        push de
        ld de,PU_SIZE
        add iy,de
        pop de
        dec e
        jr nz,.f
        ld iy,popups            ; all busy: reuse first
.got:   ld (iy+0),16
        ld (iy+1),b
        ld (iy+2),c
        pop hl
        push iy
        pop de
        inc de
        inc de
        inc de
        inc de
        ld b,9
.c:     ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        djnz .c
        xor a
        ld (de),a
        ret

popups_update:
        ld iy,popups
        ld b,4
.l:     ld a,(iy+0)
        or a
        jr z,.n
        dec (iy+0)
        and 1
        jr z,.n
        ld a,(iy+2)
        cp 2
        jr c,.n
        dec (iy+2)
.n:     ld de,PU_SIZE
        add iy,de
        djnz .l
        ret

popups_draw:
        ld iy,popups
        ld b,4
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        and 2
        ld a,(colpat+1)
        jr z,$+5
        ld a,(colpat+3)
        ld e,a
        ld b,(iy+1)
        ld c,(iy+2)
        push iy
        pop hl
        inc hl
        inc hl
        inc hl
        inc hl
        call drawtext
.n:     ld de,PU_SIZE
        add iy,de
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; timers and end-of-act check
; ---------------------------------------------------------------------
timers_update:
        ld a,(piestick)
        or a
        jr z,.p
        dec a
        ld (piestick),a
.p:     ld a,(tickpar)
        and 1
        ret nz
        ld hl,pw_wide
        ld b,4
.l:     ld a,(hl)
        or a
        jr z,.n
        dec (hl)
        ld a,(hl)
        cp 50
        jr nc,.n2
        and 7
        jr nz,.n2
        ld a,1
        ld (hud_req),a
.n2:    ld a,(hl)
        or a
        jr nz,.n
        ld a,1
        ld (hud_req),a
.n:     inc hl
        djnz .l
        ld a,(pw_wide)
        or a
        ret nz
        ld a,(see_hw)
        cp 10
        ret z
        ld a,10
        ld (see_hw),a
        ret

check_end:
        ld a,(endtimer)
        or a
        ret nz
        ld a,(actflags)
        and AF_BONUS
        ret nz
        ld a,(balloons_left)
        or a
        ret nz
        xor a
        ld (gameresult),a
        ld a,20
        ld (endtimer),a
        ret

; ---------------------------------------------------------------------
; ---------------------------------------------------------------------
hud_partial:
hud_draw:
 ret

div16_8:
        xor a
        ld b,16
.l:     add hl,hl
        rla
        jr c,.s
        cp c
        jr c,.n
.s:     sub c
        inc l
.n:     djnz .l
        ret

; ---------------------------------------------------------------------
; RENDER into back buffer
; ---------------------------------------------------------------------
render:
        call restore_game
        call draw_rows
        call draw_net
        call draw_freeb
        call draw_hoop
        call draw_monkey
        call draw_pies
        call draw_tokens
        call draw_seesaw
        ld ix,clown0
        call draw_clown
        ld ix,clown1
        call draw_clown
        call parts_draw
        call popups_draw
        call native_hud
        ret

draw_rows:
 jp cached_rows

draw_net:
 ld a,(pw_net)
 or a
 ret z
 ld b,0
.loop: push bc
 ld c,56
 ld hl,NET
 call drawspr
 pop bc
 ld a,b
 add a,8
 ld b,a
 cp 128
 jr c,.loop
 ret

draw_freeb:
        ld a,(actflags)
        and AF_BONUS
        ret z
        ld iy,freeb
        ld b,12
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        dec a
        add a,a
        ld hl,freeb_spr
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,(iy+1)
        ld c,(iy+3)
        call drawspr
.n:     ld de,8
        add iy,de
        pop bc
        djnz .l
        ret

draw_hoop:
        ld a,(hoop)
        or a
        ret z
        ld hl,HOOP1
        ld a,(tickpar)
        and 2
        jr z,$+5
        ld hl,HOOP2
        ld a,(hoop+1)
        sub 8
        ld b,a
        ld c,31
        jp drawspr

draw_monkey:
        ld a,(monkey)
        or a
        ret z
        ld a,(monkey+5)
        or a
        jr z,.ok
        ; stunned: dizzy star above
        ld a,(monkey+1)
        add a,2
        ld b,a
        ld c,25
        ld hl,STAR
        call drawspr
        ld hl,MONKEY1
        jr .d
.ok:    ld hl,MONKEY1
        ld a,(monkey+3)
        and 4
        jr z,.d
        ld hl,MONKEY2
.d:     ld a,(monkey+1)
        ld b,a
        ld c,29
        jp drawspr

draw_pies:
        ld iy,pies
        ld b,3
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        ld hl,PIE
        cp 1
        jr z,.d
        ld hl,PIE_SPLAT
.d:     ld b,(iy+1)
        ld c,(iy+3)
        call drawspr
.n:     ld de,8
        add iy,de
        pop bc
        djnz .l
        ret

draw_tokens:
        ld iy,tokens
        ld b,3
.l:     push bc
        ld a,(iy+0)
        or a
        jr z,.n
        dec a
        add a,a
        ld hl,tokspr1
        ld c,a
        ld a,(tickpar)
        and 6
        jr z,.n                 ; blink
        ld a,c
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld b,(iy+1)
        ld c,(iy+3)
        call drawspr
.n:     ld de,8
        add iy,de
        pop bc
        djnz .l
        ret

draw_seesaw:
        ld a,(see_hw)
        cp 15
        ld hl,see_sprs
        jr nz,$+5
        ld hl,see_sprs_w
        ld a,(tilt)
        add a,a
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(see_hw)
        ld b,a
        ld a,(see_x+1)
        sub b
        ld b,a
        ld c,48
        jp drawspr

see_sprs:       dw SEE_L,SEE_R
see_sprs_w:     dw SEEW_L,SEEW_R

draw_clown:
        ld a,(ix+CS_STATE)
        or a
        ret z
        cp S_SEAT
        jp z,.seat
        cp S_TOWER
        jp z,.tower
        cp S_SPLAT
        jp z,.splat
        ; flying
        ld a,(ix+CS_VY+1)
        bit 7,a
        jr z,.fall
        ld hl,CL_UP
        bit 2,(ix+CS_FL)
        jr z,.d
        ld a,(ix+CS_ANIM)
        and 2
        jr z,.d
        ld hl,CL_FLIP
        jr .d
.fall:  ld hl,CL_FALL1
        ld a,(ix+CS_ANIM)
        and 4
        jr z,.f2
        ld hl,CL_FALL2
.f2:    ld a,(pw_umb)
        or a
        jr z,.d
        push hl
        ld a,(ix+CS_X+1)
        dec a
        ld b,a
        ld a,(ix+CS_Y+1)
        sub 5
        ld c,a
        ld hl,UMBRELLA
        call drawspr
        pop hl
.d:     ld b,(ix+CS_X+1)
        ld c,(ix+CS_Y+1)
        jp drawspr
.seat:  ; position at low end
        ld a,(see_hw)
        ld c,a
        ld a,(see_x+1)
        ld b,a
        ld a,(tilt)
        or a
        jr nz,.rlow
        ld a,b
        sub c
        jr .sx
.rlow:  ld a,b
        add a,c
        sub 6
.sx:    ld (ix+CS_X+1),a
        ld b,a
        ld c,48
        ld hl,CL_SIT
        ld a,(ix+CS_T)
        or a
        jr z,.s1
        dec (ix+CS_T)
        ld hl,CL_SIT2
        inc c
.s1:    ld a,(flipanim)
        or a
        jr z,.s2
        dec c
        dec c
.s2:    push bc
        call drawspr
        pop bc
        ld a,(piestick)
        or a
        ret z
        ld hl,PIE_SPLAT
        jp drawspr
.tower: ld hl,CL_FALL2
        ld a,(ix+CS_ANIM)
        and 4
        jr z,.d
        ld hl,CL_WAVE
        jr .d
.splat: ld b,(ix+CS_X+1)
        dec b
        ld c,53
        ld hl,CL_SPLAT
        push bc
        call drawspr
        pop bc
        ; dizzy stars orbit
        ld a,(ix+CS_ANIM)
        and 4
        ld hl,STAR
        ld a,b
        jr z,$+4
        add a,5
        ld b,a
        ld c,49
        jp drawspr

; ---------------------------------------------------------------------
; pause
; ---------------------------------------------------------------------
pause_game:
 call wait_release
 ld hl,txt_paused
 ld c,35
 call bigc
 call present
.wait: call rearm
 ld a,19
 call key_test
 jr z,.quit
 ld a,(snd_on)
 xor 1
 ld (snd_on),a
 call wait_release
.quit: ld a,17
 call key_test
 jr z,.resume
 ld a,2
 ld (gameresult),a
 ret
.resume: ld a,16
 call key_test
 jr z,.wait
 call wait_release
 ld a,(frames)
 ld (sim_frame),a
 ret

act_clear:
        ld hl,mus_clear0
        ld de,mus_clear1
        xor a
        call play_music
        ; bonus for no misses
        ld a,(actflags)
        and AF_BONUS
        jr nz,.bon
        ld a,(misses_act)
        or a
        jr nz,.cel
        ld de,$5000
        call add_score_pts
        ld a,1
        ld (nomiss),a
        jr .cel
.bon:   ; bonus round tally: pops x 100 already scored; perfect bonus if >= 30
        ld a,(bonus_pops)
        cp 30
        jr c,.cel
        ld de,$3000
        call add_score_pts
.cel:   ld a,75
        ld (cel_t),a
.lp:    ld a,2
        call syncframe
        call present
        call snd_tick
        ld a,(cel_t)
        and 7
        jr nz,.nc
        call rand
        and 63
        add a,32
        ld b,a
        call rand
        and 31
        add a,4
        ld c,a
        xor a
        ld e,12
        call confetti
.nc:    call parts_update
        call popups_update
        call hud_draw
        call render
        ; captions
        ld hl,txt_actclear
        ld a,(actflags)
        and AF_BONUS
        jr z,$+5
        ld hl,txt_bonusdone
        ld c,33
        ld a,(colpat+3)
        ld e,a
        call bigc
        ld a,(actflags)
        and AF_BONUS
        jr nz,.cb
        ld a,(nomiss)
        or a
        jr z,.cn
        ld hl,txt_nomiss
        ld c,43
        ld a,(colpat+1)
        ld e,a
        call textc
        jr .cn
.cb:    ld hl,txt_popped
        ld de,strbuf
        call strcpy
        ld a,(bonus_pops)
        call act_number
        ld hl,strbuf
        ld c,43
        ld a,(colpat+1)
        ld e,a
        call textc
.cn:    ld hl,cel_t
        dec (hl)
        jp nz,.lp
        xor a
        ld (nomiss),a
        ld hl,0
        ld (sfx_ptr),hl
        jp curtain_close

; ---------------------------------------------------------------------
; theatre curtains: close over the screen, or open to reveal the back
; ---------------------------------------------------------------------
curtain_close:
 jp curtain_wipe
curtain_open:
 jp present

game_over:
        ld hl,mus_over0
        ld de,mus_over1
        xor a
        call play_music
        ld a,100
        ld (cel_t),a
.lp:    ld a,2
        call syncframe
        call present
        call snd_tick
        call parts_update
        call popups_update
        call render
        ld hl,txt_gameover
        ld c,33
        ld a,(colpat+3)
        ld e,a
        call bigc
        ld hl,txt_gameover2
        ld c,43
        ld a,(colpat+1)
        ld e,a
        call textc
        ld a,(cel_t)
        cp 60
        jr nc,.nk
        call anykey
        jr nz,.x
.nk:    ld hl,cel_t
        dec (hl)
        jr nz,.lp
.x:     jp stop_music

; ---------------------------------------------------------------------
; demo AI: predicts where the falling clown lands and slides the seesaw
; so the raised end's sweet spot is underneath.  Returns input bits.
; ---------------------------------------------------------------------
ai_input:
        ; find flyer
        ld ix,clown0
        ld a,(ix+CS_STATE)
        cp S_FLY
        jr z,.f
        ld ix,clown1
        ld a,(ix+CS_STATE)
        cp S_FLY
        jr z,.f
        ; nobody flying: drift to middle
        ld a,64
        ld (ai_target),a
        jp .steer
.f:     ld hl,ai_t
        dec (hl)
        jp p,.steer
        ld (hl),9
        ; simulate
        ld l,(ix+CS_X)
        ld h,(ix+CS_X+1)
        ld (ai_x),hl
        ld l,(ix+CS_Y)
        ld h,(ix+CS_Y+1)
        ld (ai_y),hl
        ld l,(ix+CS_VX)
        ld h,(ix+CS_VX+1)
        ld (ai_vx),hl
        ld e,(ix+CS_VY)
        ld d,(ix+CS_VY+1)
        ld b,200
.sim:   ld hl,GRAV
        ld a,(pw_umb)
        or a
        jr z,.g
        bit 7,d
        jr nz,.g
        ld hl,4
.g:     add hl,de
        ex de,hl                ; DE = vy
        ld hl,(ai_y)
        add hl,de
        ld (ai_y),hl
        ld a,h
        bit 7,a
        jr z,.yp
        ; ceiling bounce approx
        ld hl,256
        ld (ai_y),hl
        bit 7,d
        jr z,.yp
        ld hl,0
        or a
        sbc hl,de
        sra h
        rr l
        ex de,hl
.yp:    ld hl,(ai_x)
        push de
        ld de,(ai_vx)
        add hl,de
        pop de
        ld a,h
        cp 4
        jr c,.bw
        cp 118
        jr c,.nw
.bw:    push de
        ld de,(ai_vx)
        ld hl,0
        or a
        sbc hl,de
        ld (ai_vx),hl
        pop de
        ld hl,(ai_x)
.nw:    ld (ai_x),hl
        bit 7,d
        jr nz,.cont
        ld a,(ai_y+1)
        add a,8
        cp 48
        jr nc,.land
.cont:  djnz .sim
.land:  ld a,(ai_x+1)
        add a,3
        ld c,a                  ; landing centre
        ; desired pivot so landing is near raised tip
        ld a,(see_hw)
        sub 3
        ld e,a
        ld a,(tilt)
        or a
        ld a,c
        jr nz,.tl
        sub e                   ; raised right: pivot = x - (hw-3)
        jr .tt
.tl:    add a,e
.tt:    ld (ai_target),a
.steer: ld a,(ai_target)
        ld c,a
        ; clamp target to legal range
        ld a,(see_hw)
        add a,4
        cp c
        jr c,$+3
        ld c,a
        ld a,(see_hw)
        ld b,a
        ld a,123
        sub b
        cp c
        jr nc,$+3
        ld c,a
        ld a,(see_x+1)
        sub c
        jr z,.none
        jp p,.left
        cp -1
        jr z,.none
        ld a,2
        ret
.left:  cp 2
        jr c,.none
        ld a,1
        ret
.none:  xor a
        ret
