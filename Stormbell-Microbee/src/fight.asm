; =====================================================================
;  FIGHT: the duel rules, shared by Wren and every opponent, and the
;  opponents' brains.
;
;  A fighter is a small state machine ticked 25 times a second. Every
;  attack has three phases: a wind-up you can see coming, a strike that
;  lands on its first tick if the other fighter is in range, and a
;  recovery during which the attacker is open. A fighter hit during
;  their own wind-up takes a counter-hit (one more point). A strike that
;  meets a raised guard knocks the attacker back into a long recoil:
;  that is the window to answer. Nothing is random in the rules; the
;  opponents differ in their timings and their scripts.
; =====================================================================
ST_IDLE     EQU 0
ST_STEP     EQU 1
ST_GUARD    EQU 2
ST_ATK      EQU 3
ST_HIT      EQU 4
ST_BLOCKED  EQU 5
ST_FALL     EQU 6
ST_DOWN     EQU 7
ST_BOW      EQU 8
ST_STAND    EQU 9
ST_RUN      EQU 10          ; running along the road (the game moves it)

; commands (from the pad or a brain)
C_FWD       EQU 1
C_BACK      EQU 2
C_GUARD     EQU 4
C_PUNCH     EQU 8
C_KICK      EQU 16

; timing table (F_TAB points at one)
T_PW        EQU 0           ; punch: wind-up, strike, recovery
T_PS        EQU 1
T_PR        EQU 2
T_KW        EQU 3           ; kick
T_KS        EQU 4
T_KR        EQU 5
T_STEP      EQU 6           ; ticks a step takes
T_DP        EQU 7           ; damage: punch, kick
T_DK        EQU 8
T_HIT       EQU 9           ; ticks of stagger when hit
T_RECOIL    EQU 10          ; ticks of recoil when blocked

WHIFF_EXTRA EQU 4           ; extra recovery after a miss
GUARD_MAX   EQU 45          ; a guard held this long drops (arms tire)
GUARD_REST  EQU 10          ; ... and cannot rise again for this long
MINGAP      EQU 4           ; anchors never closer than this
XMIN        EQU 3
XMAX        EQU 36

;               PW PS PR KW KS KR ST DP DK HT RC
tim_hero:   db  4, 2, 6, 6, 2, 9, 4, 1, 2, 8,13
tim_ox:     db  9, 2,13,12, 3,17, 7, 2, 3, 3,12
tim_reed:   db  6, 2, 9, 7, 2,11, 6, 1, 2, 7,12
tim_sparrow:db  3, 2, 6, 5, 2, 9, 3, 1, 2, 7,12
tim_gorse:  db  4, 2, 7, 6, 2,10, 5, 1, 2, 7,12
tim_crow:   db  4, 2, 7, 5, 2, 9, 4, 2, 2, 7,12

; ---------------------------------------------------------------------
;  IX = fighter, C = command bits this tick (held), B = presses
; ---------------------------------------------------------------------
fighter_tick:
        ld (ix+F_STRIKE),0
        ld a,(ix+F_COOL)
        or a
        jr z,.nc
        dec (ix+F_COOL)
.nc:    ; an attack pressed while busy is kept for a few ticks
        ld a,b
        and C_PUNCH|C_KICK
        jr z,.nb
        ld (ix+F_BUF),a
        ld (ix+F_BUFT),5
.nb:    ld a,(ix+F_BUFT)
        or a
        jr z,.nb2
        dec (ix+F_BUFT)
        jr nz,.nb2
        ld (ix+F_BUF),0
.nb2:   ld a,(ix+F_ST)
        or a
        jp z,st_idle
        dec a
        jp z,st_step
        dec a
        jp z,st_guard
        dec a
        jp z,st_atk
        dec a
        jp z,st_hit
        dec a
        jp z,st_blocked
        dec a
        jp z,st_fall
        dec a
        jp z,st_down
        dec a
        jr z,.bow
        dec a
        jr z,.upright
        ; running: four frames, two ticks each
        ld a,(ticks)
        rra
        and 3
        add a,FR_RUN1
        ld (ix+F_FR),a
        ret
.upright:
        ld (ix+F_FR),FR_IDLE
        ret
.bow:   ld (ix+F_FR),FR_BOW
        ret

; IX = fighter, A = byte offset -> A = its timing entry
timing: push hl
        push de
        ld l,(ix+F_TAB)
        ld h,(ix+F_TAB+1)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ret

go_idle:
        ld (ix+F_ST),ST_IDLE
        ld (ix+F_T),0
        jp breathe

st_idle:
        ; a kept attack goes first
        ld a,(ix+F_BUF)
        or a
        jr z,.nobuf
        ld (ix+F_BUF),0
        ld (ix+F_BUFT),0
        jp start_attack
.nobuf: bit 2,c
        jr z,.ng
        ld a,(ix+F_COOL)
        or a
        jr nz,.ng
        ld (ix+F_ST),ST_GUARD
        ld (ix+F_GUARDT),0
        ld (ix+F_FR),FR_GUARD
        ret
.ng:    bit 0,c
        jr z,.nf
        ld a,1
        call can_step
        jr nz,.nf
        ld (ix+F_PH),1
        jr start_step
.nf:    bit 1,c
        jr z,breathe
        ld a,-1
        call can_step
        jr nz,breathe
        ld (ix+F_PH),-1
start_step:
        ld (ix+F_ST),ST_STEP
        ld (ix+F_T),0
        ld (ix+F_FR),FR_STEP1
        ret
breathe:
        ld a,(ticks)
        and 16
        ld a,FR_STAND
        jr z,.b
        ld a,FR_STAND2
.b:     ld (ix+F_FR),a
        ret

; A = +1 forwards / -1 back: Z if that step is allowed
can_step:
        bit 7,(ix+F_DIR)
        jr z,.d
        neg                     ; the foe's forwards is to the left
.d:     add a,(ix+F_X)          ; the new column
        cp XMIN
        jr c,.no
        cp XMAX+1
        jr nc,.no
        ld e,a
        ; the gap to the other fighter
        bit 7,(ix+F_DIR)
        ld a,(hero+F_X)
        jr z,.h
        ; the foe: new x - hero x
        ld d,a
        ld a,e
        sub d
        jr .g
.h:     ld d,a
        ld a,(foe+F_X)
        sub e
.g:     cp MINGAP
        jr c,.no
        xor a
        ret
.no:    or 1
        ret

st_step:
        ; attacks can be pressed during a step: they are kept
        inc (ix+F_T)
        ld a,T_STEP
        call timing
        ld e,a
        srl a
        ld d,a                  ; half way
        ld a,(ix+F_T)
        cp d
        jr nz,.nm
        ; the foot comes down: move one column if still allowed
        ld a,(ix+F_PH)
        push de
        call can_step
        pop de
        jr nz,.nm
        ld a,(ix+F_PH)
        bit 7,(ix+F_DIR)
        jr z,.p
        neg
.p:     add a,(ix+F_X)
        ld (ix+F_X),a
        ld a,SFX_STEP
        call sfx
.nm:    ld a,(ix+F_T)
        cp e
        jp nc,go_idle
        cp d
        ld a,FR_STEP1
        jr c,.f
        ld a,FR_STEP2
.f:     ld (ix+F_FR),a
        ret

st_guard:
        ld a,(ix+F_BUF)
        or a
        jr z,.nb
        ; attacking out of a guard is allowed (and quick)
        ld (ix+F_BUF),0
        ld (ix+F_BUFT),0
        jp start_attack
.nb:    bit 2,c
        jr z,.drop
        inc (ix+F_GUARDT)
        ld a,(ix+F_GUARDT)
        cp GUARD_MAX
        jr nc,.tired
        ld (ix+F_FR),FR_GUARD
        ret
.tired: ld (ix+F_COOL),GUARD_REST
        jp go_idle
.drop:  ld (ix+F_COOL),2
        jp go_idle

; A = C_PUNCH / C_KICK (punch wins if both)
start_attack:
        ld e,0
        bit 3,a
        jr nz,.p
        inc e
.p:     ld (ix+F_ATK),e
        ld (ix+F_ST),ST_ATK
        ld (ix+F_PH),0
        ld a,e
        or a
        ld a,T_PW
        ld d,FR_PUNCH_W
        jr z,.t
        ld a,T_KW
        ld d,FR_KICK_W
.t:     call timing
        ld (ix+F_T),a
        ld (ix+F_FR),d
        ret

st_atk:
        dec (ix+F_T)
        ret nz
        ld a,(ix+F_PH)
        inc a
        ld (ix+F_PH),a
        cp 1
        jr z,.strike
        cp 2
        jr z,.recover
        jp go_idle
.strike:
        ; the blow: (resolve) checks it after both fighters have ticked
        ld a,(ix+F_ATK)
        inc a
        ld (ix+F_STRIKE),a
        dec a
        ld a,T_PS
        ld d,FR_PUNCH
        jr z,.s
        ld a,T_KS
        ld d,FR_KICK
.s:     call timing
        ld (ix+F_T),a
        ld (ix+F_FR),d
        ld a,(ix+F_ATK)
        add a,SFX_PUNCH
        jp sfx
.recover:
        ld a,(ix+F_ATK)
        or a
        ld a,T_PR
        jr z,.r
        ld a,T_KR
.r:     call timing
        ld e,a
        ld a,(ix+F_WHIFF)
        or a
        jr z,.rw
        ld a,e
        add a,WHIFF_EXTRA       ; a blow into thin air overbalances you
        ld e,a
.rw:    ld (ix+F_T),e
        ld (ix+F_WHIFF),0
        ret

st_hit:
        dec (ix+F_T)
        jr z,.end
        ld a,(ix+F_T)
        cp 4
        ld a,FR_HIT
        jr nc,.f
        ld a,FR_HIT2
.f:     ld (ix+F_FR),a
        ret
.end:   ld a,(ix+F_HP)
        or a
        jp nz,go_idle
        ld (ix+F_ST),ST_FALL
        ld (ix+F_T),0
        ld (ix+F_FR),FR_FALL1
        ld a,SFX_FALL
        jp sfx

st_blocked:
        dec (ix+F_T)
        jp z,go_idle
        ld a,(ix+F_T)
        cp 5
        ld a,FR_HIT
        jr nc,.f
        ld a,FR_STAND
.f:     ld (ix+F_FR),a
        ret

st_fall:
        inc (ix+F_T)
        ld a,(ix+F_T)
        cp 5
        ld b,FR_FALL1
        jr c,.f
        cp 10
        ld b,FR_FALL2
        jr c,.f
        ld (ix+F_ST),ST_DOWN
        ld (ix+F_T),0
        ld b,FR_DOWN
        ld a,SFX_THUD
        call sfx
.f:     ld (ix+F_FR),b
        ret

st_down:
        ld (ix+F_FR),FR_DOWN
        ld a,(ix+F_T)
        inc a
        ret z
        ld (ix+F_T),a
        ret

; ---------------------------------------------------------------------
;  after both have ticked: did a strike land?
; ---------------------------------------------------------------------
resolve:
        ld ix,hero
        ld iy,foe
        call .one
        ld ix,foe
        ld iy,hero
.one:   ld a,(ix+F_STRIKE)
        or a
        ret z
        ; the range: rangetab[stage] = hero punch, hero kick, foe punch, foe kick
        dec a
        ld e,a                  ; 0 punch / 1 kick
        ld a,(ix+F_DIR)
        bit 7,a
        jr z,.h
        inc e
        inc e
.h:     ld d,0
        ld hl,(rangep)
        add hl,de
        ld b,(hl)               ; B = reach in columns
        ld a,(foe+F_X)
        ld hl,hero+F_X
        sub (hl)                ; the distance
        cp b
        jr z,.in
        jr c,.in
.miss:  ld (ix+F_WHIFF),1       ; a miss: a longer recovery
        ret
.in:    ld a,(iy+F_ST)
        cp ST_FALL
        jr nc,.miss             ; falling, down, bowing: nothing to hit
        cp ST_GUARD
        jp z,.blocked
        ; armour: a heavy fighter's own blow goes on through a hit
        ld a,(iy+F_ARMOUR)
        or a
        jr z,.noarm
        ld a,(iy+F_ST)
        cp ST_ATK
        jr nz,.noarm
        ld a,(iy+F_PH)
        cp 2
        jr nc,.noarm
        ld a,(ix+F_STRIKE)
        dec a
        ld a,T_DP
        jr z,.ad
        ld a,T_DK
.ad:    call timing
        ld c,a
        ld a,(iy+F_HP)
        sub c
        jr nc,.ahp
        xor a
.ahp:   ld (iy+F_HP),a
        ld a,1
        ld (hud_dirty),a
        or a
        ld a,(iy+F_HP)
        or a
        jr nz,.alive
        ; the last point stops even him
        jr .noarm
.alive: ld a,SFX_BLOCK
        jp sfx
.noarm:
        ; a hit: counter-hit if caught winding up
        ld a,(ix+F_STRIKE)
        dec a
        ld a,T_DP
        jr z,.dp
        ld a,T_DK
.dp:    call timing
        ld c,a
        ld a,(iy+F_ST)
        cp ST_ATK
        jr nz,.nctr
        ld a,(iy+F_PH)
        or a
        jr nz,.nctr
        inc c
        ld a,1
        ld (counter_flash),a
.nctr:  ld a,(iy+F_HP)
        sub c
        jr nc,.hp
        xor a
.hp:    ld (iy+F_HP),a
        ld a,1
        ld (hud_dirty),a
        ; the target staggers, pushed back a column if there is room
        push ix
        push iy
        pop ix
        ld a,T_HIT
        call timing
        pop ix
        ld (iy+F_T),a
        ld (iy+F_ST),ST_HIT
        ld (iy+F_FR),FR_HIT
        ld (iy+F_BUF),0
        ld (iy+F_BUFT),0
        ld a,(iy+F_X)
        bit 7,(iy+F_DIR)
        jr z,.ph
        inc a
        cp XMAX+1
        jr nc,.np
        jr .pp
.ph:    dec a
        cp XMIN
        jr c,.np
.pp:    ld (iy+F_X),a
.np:    ld a,(ix+F_STRIKE)
        add a,SFX_HIT-1
        jp sfx
.blocked:
        ; a clean block: the attacker recoils, wide open
        ld a,T_RECOIL
        call timing
        ld (ix+F_T),a
        ld (ix+F_ST),ST_BLOCKED
        ld (ix+F_FR),FR_HIT
        ld (ix+F_BUF),0
        ld (ix+F_BUFT),0
        ld (iy+F_GUARDT),0      ; a block rests the arms
        ld a,1
        ld (blocked_flag),a
        ld a,SFX_BLOCK
        jp sfx

; ---------------------------------------------------------------------
;  the opponents' brains. A brain record:
;   dw script, db react (0..255 chance of guarding a blow it sees
;   coming), db delay (ticks of wind-up it needs to see), db counter
;   (1: punches straight back after blocking), db punish (0..255 chance
;   of punishing a whiffed attack), db hp, dw timings, db armour (1: a
;   blow does not stop its own swing)
;
;  Scripts: pairs of bytes, op and argument.
; ---------------------------------------------------------------------
OP_WAIT     EQU 0           ; stand n ticks
OP_NEAR     EQU 1           ; step in until the gap is n or less
OP_FAR      EQU 2           ; step back until the gap is n or more
OP_PUNCH    EQU 3
OP_KICK     EQU 4
OP_GUARD    EQU 5           ; hold the guard n ticks
OP_LOOP     EQU 6
OP_FEINT    EQU 7           ; step in, and straight back out
; a NEAR / FAR argument with bit 7 set is measured from the fighter's
; own reach: RP = its punch, RK = its kick, minus the low bits
RP          EQU $80
RK          EQU $C0

B_SCRIPT    EQU 0
B_REACT     EQU 2
B_DELAY     EQU 3
B_COUNTER   EQU 4
B_PUNISH    EQU 5
B_HP        EQU 6
B_TIM       EQU 7
B_ARMOUR    EQU 9

brains:     dw br_ox,br_reed,br_sparrow,br_gorse,br_crow
br_ox:      dw sc_ox
            db 0,9,0,240,12
            dw tim_ox
            db 1
br_reed:    dw sc_reed
            db 95,4,0,110,10
            dw tim_reed
            db 0
br_sparrow: dw sc_sparrow
            db 125,3,0,140,9
            dw tim_sparrow
            db 0
br_gorse:   dw sc_gorse
            db 150,2,1,120,11
            dw tim_gorse
            db 0
br_crow:    dw sc_crow
            db 160,2,1,180,15
            dw tim_crow
            db 0

; BRAMBLE THE OX: plods in, one huge slow kick, a long rest. Step back
; from the kick and strike while he recovers.
sc_ox:      db OP_NEAR,RK, OP_WAIT,10, OP_KICK,0, OP_WAIT,20
            db OP_NEAR,RP, OP_PUNCH,0, OP_WAIT,24, OP_LOOP,0
; OLD REED: long legs, kept far. Three kicks in strict time, then he
; backs away to breathe.
sc_reed:    db OP_NEAR,RK, OP_KICK,0, OP_WAIT,7, OP_KICK,0, OP_WAIT,7, OP_KICK,0
            db OP_FAR,10, OP_WAIT,26, OP_LOOP,0
; SPARROW: waits far off, darts in for two quick punches, darts out;
; sometimes a kick on the way.
sc_sparrow: db OP_FAR,11, OP_WAIT,16, OP_NEAR,RP, OP_PUNCH,0, OP_PUNCH,0
            db OP_FAR,10, OP_WAIT,8, OP_NEAR,RK, OP_KICK,0, OP_FAR,11, OP_WAIT,18, OP_LOOP,0
; CAPTAIN GORSE: closes behind his guard and answers every blow;
; drops the guard only to throw his own.
sc_gorse:   db OP_NEAR,RK, OP_GUARD,18, OP_KICK,0, OP_WAIT,5
            db OP_NEAR,RP, OP_GUARD,14, OP_PUNCH,0, OP_PUNCH,0, OP_FAR,8, OP_WAIT,8, OP_LOOP,0
; LORD CURRAWONG: all of it, faster, with feints.
sc_crow:    db OP_NEAR,RK, OP_KICK,0, OP_WAIT,3, OP_PUNCH,0, OP_FAR,10, OP_WAIT,10
            db OP_FEINT,0, OP_WAIT,6, OP_NEAR,RP, OP_PUNCH,0, OP_PUNCH,0, OP_KICK,0
            db OP_GUARD,16, OP_FAR,10, OP_WAIT,6, OP_FEINT,0, OP_NEAR,RK, OP_KICK,0, OP_KICK,0
            db OP_WAIT,14, OP_LOOP,0

; -> C = the foe's command this tick, B = its presses
brain:
        ld bc,0
        ld ix,foe
        ld a,(ix+F_ST)
        cp ST_FALL
        ret nc
        ld a,(hero+F_ST)
        cp ST_FALL
        ret nc                  ; the hero is down: nothing more to do
        ld a,(foe+F_X)
        ld hl,hero+F_X
        sub (hl)
        ld (gap),a
        ld hl,(brainp)
        ; -- reflex 0: answer straight back after a clean block
        ld a,(blocked_flag)
        or a
        jr z,.r1
        push hl
        ld de,B_COUNTER
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jr z,.r1
        ld a,(hero+F_ST)
        cp ST_BLOCKED
        jr nz,.r1
        xor a
        ld (guard_t),a
        ld bc,C_PUNCH*256
        ret
.r1:
        ; -- reflex 1: a guard against a blow it sees coming
        ld a,(hero+F_ST)
        cp ST_ATK
        jr z,.hatk
        xor a
        ld (seen),a
        jr .r2
.hatk:  ld a,(hero+F_PH)
        or a
        jr nz,.r2               ; only the wind-up can be read
        ld a,(seen)
        or a
        jr nz,.r2
        ; how long has the wind-up shown?
        ld a,(hero+F_T)
        ld e,a                  ; ticks of wind-up left
        push hl
        ld a,(hero+F_ATK)
        or a
        ld a,(tim_hero+T_PW)
        jr z,.w2
        ld a,(tim_hero+T_KW)
.w2:    sub e                   ; ticks shown so far
        pop hl
        push hl
        ld de,B_DELAY
        add hl,de
        cp (hl)
        pop hl
        jr c,.r2
        ld a,1
        ld (seen),a
        ; only if the blow could reach
        ld a,(hero+F_ATK)
        ld e,a
        ld d,0
        push hl
        ld hl,(rangep)
        add hl,de
        ld a,(gap)
        dec a
        cp (hl)
        pop hl
        jr nc,.r2
        push hl
        ld de,B_REACT
        add hl,de
        ld e,(hl)
        pop hl
        call random
        cp e
        jr nc,.r2
        ld a,(ix+F_COOL)
        or a
        jr nz,.r2
        ; guard until the blow is over
        ld a,(hero+F_T)
        add a,6
        ld (guard_t),a
.r2:    ld a,(guard_t)
        or a
        jr z,.r3
        dec a
        ld (guard_t),a
        ld c,C_GUARD
        ret
.r3:
.r4:    ; -- reflex 3: punish a whiff in reach
        ld a,(hero+F_ST)
        cp ST_ATK
        jr nz,.r5
        ld a,(hero+F_PH)
        cp 2
        jr nz,.r5
        ld a,(punished)
        or a
        jr nz,.r6
        ld a,1
        ld (punished),a
        ld a,(ix+F_ST)
        or a
        jr nz,.r6
        ld de,(rangep)
        inc de
        inc de                  ; the foe's punch reach
        ld a,(de)
        ld e,a
        ld a,(gap)
        dec a
        cp e
        jr nc,.r6
        push hl
        ld de,B_PUNISH
        add hl,de
        ld e,(hl)
        pop hl
        call random
        cp e
        jr nc,.r6
        ld bc,C_PUNCH*256
        ret
.r5:    xor a
        ld (punished),a
.r6:    ; -- the script
        ld a,(ix+F_ST)
        cp ST_GUARD
        jr z,.script
        or a
        ret nz                  ; busy: let it finish
.script:
        ld hl,(scriptp)
        ld a,(scr_pc)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld e,(hl)               ; the argument
        or a
        jr z,.wait
        dec a
        jr z,.near
        dec a
        jr z,.far
        dec a
        jp z,.punch
        dec a
        jp z,.kick
        dec a
        jp z,.guard
        dec a
        jp z,.loop
        ; feint: a step in, a step out
        ld a,(scr_t)
        or a
        jr nz,.fe2
        ld a,1
        ld (scr_t),a
        ld a,(gap)
        cp MINGAP+1
        jp c,.next
        ld c,C_FWD
        ret
.fe2:   call .next
        ld c,C_BACK
        ret
.wait:  ld a,(scr_t)
        inc a
        ld (scr_t),a
        dec a
        cp e
        jp nc,.next
        ret
.near:  call .reach
        ld a,(gap)
        cp e
        jp z,.next
        jp c,.next
        ld a,(scr_t)            ; give up after a while (the hero ran)
        inc a
        ld (scr_t),a
        cp 120
        jr nc,.next
        ; never step into a blow that is already coming (unless armoured)
        ld a,(ix+F_ARMOUR)
        or a
        jr nz,.nstep
        ld a,(hero+F_ST)
        cp ST_ATK
        jr nz,.nstep
        ld a,(hero+F_PH)
        cp 2
        jr nc,.nstep
        ld a,(gap)
        sub 2
        push hl
        ld hl,(rangep)
        inc hl                  ; the hero's kick reach
        cp (hl)
        pop hl
        ret c
.nstep: ld c,C_FWD
        ret
.far:   ld a,(gap)
        cp e
        jr nc,.next
        ld a,(ix+F_X)
        cp XMAX
        jr nc,.next
        ld a,(scr_t)
        inc a
        ld (scr_t),a
        cp 60
        jr nc,.next
        ld c,C_BACK
        ret
; E = a NEAR argument -> E = the gap it means
.reach: bit 7,e
        ret z
        push hl
        ld hl,(rangep)
        inc hl
        inc hl
        bit 6,e
        jr z,.rp
        inc hl
.rp:    ld a,e
        and 7
        ld e,a
        ld a,(hl)
        sub e
        ld e,a
        pop hl
        ret
.punch: call .next
        ld b,C_PUNCH
        ret
.kick:  call .next
        ld b,C_KICK
        ret
.guard: ld a,(scr_t)
        inc a
        ld (scr_t),a
        dec a
        cp e
        jr nc,.gend
        ld c,C_GUARD
        ret
.gend:  call .next
        ret
.loop:  xor a
        ld (scr_pc),a
        ld (scr_t),a
        ret
.next:  ld a,(scr_pc)
        add a,2
        ld (scr_pc),a
        xor a
        ld (scr_t),a
        ret

; a random byte in A (keeps BC, DE, HL)
random: push hl
        ld hl,(rseed)
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
        ld (rseed),hl
        pop hl
        ret
