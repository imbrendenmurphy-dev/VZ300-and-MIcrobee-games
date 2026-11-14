; ============================================================================
;  CPU OPPONENT
;  Table-driven: it sees what the player did some ticks ago (8 Easy, 5 Normal,
;  3 Hard), reacts to attacks starting, whiffs and jump-ins with a dice roll,
;  and otherwise picks from weighted habits for the distance it is at.
; ============================================================================

; observation bits
OB_ATK   equ 1      ; winding up or striking
OB_REC   equ 2      ; recovering from a miss
OB_AIR   equ 4
OB_DOWN  equ 8
OB_LOW   equ 16     ; the attack is low
OB_HIGH  equ 32     ; the attack is overhead / from the air
OB_APPR  equ 64     ; coming in through the air
OB_PROJ  equ 128    ; something thrown is on its way

; actions
A_WAIT   equ 0
A_FWD    equ 1
A_BACK   equ 2
A_BLOCK  equ 3
A_CBLOCK equ 4
A_JFWD   equ 5
A_JBACK  equ 6
A_SA     equ 7
A_SB     equ 8
A_CA     equ 9
A_CB     equ 10
A_SP1    equ 11
A_SP2    equ 12
A_TAUNT  equ 13

; ai_think: IX = CPU fighter.  Sets F_PAD and adds to F_PRS.
ai_think:
        ld a,(fin_on)           ; a dizzy opponent: stand back (fin_tick decides
        dec a                   ; whether the CPU performs its finisher)
        jr nz,.nfin
        ld (ix+F_PAD),0
        ret
.nfin:  ld iy,p1
        push ix
        pop hl
        ld de,p1
        or a
        sbc hl,de
        jr nz,$+6
        ld iy,p2
        ld (opp),iy
        call dist_px
        ld (ai_dist),a
        ; ---- record what the opponent is doing
        call ai_observe
        ld c,a
        ld a,(ix+F_HPOS)
        inc a
        and 15
        ld (ix+F_HPOS),a
        ld e,a
        ld d,0
        push ix
        pop hl
        add hl,de
        ld de,F_HIST
        add hl,de
        ld (hl),c
        ; ---- what it saw 'delay' ticks ago (and the tick before that)
        ld a,(opt_diff)
        ld e,a
        ld d,0
        ld hl,ai_delay
        add hl,de
        ld b,(hl)
        ld a,(ix+F_HPOS)
        sub b
        call .hist
        ld (ai_obs),a
        ld a,(ix+F_HPOS)
        sub b
        dec a
        call .hist
        ld (ai_prev),a
        ; ---- the CPU only acts when it is free
        ld a,(ix+F_ST)
        cp ST_JUMP
        jp z,ai_air
        cp ST_STAND
        jr z,.free
        cp ST_CROUCH
        jr z,.free
        cp ST_BSTUN
        jp z,ai_output          ; keep holding the block
        ld (ix+F_AICNT),0
        ld (ix+F_AIACT),A_WAIT
        jp ai_output
.free:  ; ---- reactions (rolled once, when the thing is first seen)
        ld a,(ai_prev)
        cpl
        ld b,a
        ld a,(ai_obs)
        and b                   ; newly seen bits
        ld (ai_new),a
        bit 0,a
        jr z,.r2
        ld a,(ai_dist)
        cp 66
        jr nc,.r2
        ld hl,ai_pblock
        call ai_roll
        jr nc,.r2
        ld a,(ai_obs)
        ld c,A_BLOCK
        and OB_LOW
        jr z,$+4
        ld c,A_CBLOCK
        ld a,c
        ld b,10
        jp ai_set
.r2:    ld a,(ai_new)
        bit 1,a
        jr z,.r3
        ld hl,ai_ppunish
        call ai_roll
        jr nc,.r3
        call ai_punish
        jr nc,.r3
        ld b,2
        jp ai_set
.r3:    ld a,(ai_new)
        bit 6,a
        jr z,.r4
        ld a,(ai_dist)
        cp 44
        jr nc,.r4
        ld hl,ai_paa
        call ai_roll
        jr nc,.r4
        ld a,4                  ; this fighter's answer to a jump-in
        call ai_x
        ld b,2
        jp ai_set
.r4:    ; something thrown is coming: block it (or, sometimes, jump it)
        ld a,(ai_new)
        bit 7,a
        jr z,.r5
        ld hl,ai_pblock
        call ai_roll
        jr nc,.r5
        call random
        cp 60
        ld a,A_JFWD
        ld b,3
        jp c,ai_set
        ld a,A_BLOCK
        ld b,8
        jp ai_set
.r5:    ; the opponent has just gone down, far away: show off
        ld a,(ai_new)
        bit 3,a
        jr z,.r6
        ld a,(ai_dist)
        cp 44
        jr c,.r6
        call random
        cp 70
        jr nc,.r6
        ld a,A_TAUNT
        ld b,18
        jp ai_set
.r6:    ; ---- carry on with the current action
        ld a,(ix+F_AICNT)
        or a
        jr z,.pick
        dec (ix+F_AICNT)
        jp ai_output
.pick:  ; ---- habits for this distance
        ld l,(ix+F_DEFL)
        ld h,(ix+F_DEFH)
        ld de,D_HAB
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ; three bands: each starts with the band's upper distance limit
.band:  ld a,(ai_dist)
        cp (hl)
        jr c,.inband
        inc hl
.skip:  ld a,(hl)
        inc hl
        inc hl
        or a
        jr nz,.skip
        jr .band
.inband:
        inc hl
        push hl
        call random
        pop hl
        ld c,a
.w:     ld a,(hl)               ; weight
        or a
        jr z,.last
        cp c
        jr nc,.got
        ld a,c
        sub (hl)
        ld c,a
        inc hl
        inc hl
        jr .w
.last:
.got:   inc hl
        ld a,(hl)
        push af
        ; hold time for movement and waiting
        call random
        and 7
        add a,5
        ld b,a
        ld a,(opt_diff)
        or a
        jr nz,$+4
        sla b                   ; Easy: slower to make up its mind
        pop af
        jp ai_set

.hist:  and 15
        push hl
        push de
        ld e,a
        ld d,0
        push ix
        pop hl
        add hl,de
        ld de,F_HIST
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ret

; ai_air: one air attack when close
ai_air:
        ld a,(ix+F_AIR)
        or a
        jr nz,ai_output
        ld a,(ai_dist)
        cp 30
        jr nc,ai_output
        call random
        cp 90
        jr nc,ai_output
        ld a,(ix+F_PRS)
        or $20
        ld (ix+F_PRS),a
        jr ai_output

; ai_set: A = action, B = ticks to hold it; presses buttons now
ai_set:
        ld (ix+F_AIACT),a
        ld (ix+F_AICNT),b
        cp A_SA
        jr c,ai_output
        ; attacks: press once, then stand still
        sub A_SA
        ld e,a
        ld d,0
        ld hl,ai_btns
        add hl,de
        ld a,(hl)
        ld c,a
        and $30
        or (ix+F_PRS)
        ld (ix+F_PRS),a
        ld a,c
        and 3                   ; crouching attack / taunt: hold down / up this tick
        ld (ix+F_PAD),a
        ld (ix+F_AIACT),A_WAIT
        ld (ix+F_AICNT),b
        ret

; ai_output: held directions for the current action
ai_output:
        ld a,(ix+F_AIACT)
        ld e,a
        ld d,0
        ld hl,ai_dirs
        add hl,de
        ld a,(hl)               ; bits: 0 up 1 down 2 back 3 fwd
        ld c,a
        and 3
        ld b,a
        bit 0,(ix+F_FACE)
        jr nz,.l
        ld a,c
        and $0C
        or b
        jr .s
.l:     bit 2,c
        jr z,$+4
        set 3,b
        bit 3,c
        jr z,$+4
        set 2,b
        ld a,b
.s:     ld (ix+F_PAD),a
        ret

; ai_roll: HL = table of 3 chances (by difficulty) -> carry if it happens
ai_roll:
        ld a,(opt_diff)
        ld e,a
        ld d,0
        add hl,de
        ld b,(hl)
        push bc
        call random
        pop bc
        cp b
        ret

; ai_x: A = index into this fighter's CPU extras -> A = the byte
; (near punish range, near punish, far punish range, far punish, anti-air)
ai_x:   push hl
        push de
        ld e,a
        ld d,0
        ld l,(ix+F_DEFL)
        ld h,(ix+F_DEFH)
        push de
        ld de,D_AIX
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ret

; ai_punish: pick a punish for the distance -> carry + A = action
ai_punish:
        xor a
        call ai_x
        ld b,a
        ld a,(ai_dist)
        cp b
        jr nc,.far
        ld a,1
        call ai_x
        scf
        ret
.far:   ld b,a
        ld a,2
        call ai_x
        ld c,a
        ld a,b
        cp c
        ret nc
        ld a,3
        call ai_x
        scf
        ret

; ai_observe: what the opponent (opp) is doing now -> A
ai_observe:
        ld iy,(opp)
        ld c,0
        ld a,(iy+F_ST)
        cp ST_KD
        jr z,.down
        cp ST_KO
        jr z,.down
        cp ST_PREJ
        jr z,.air
        cp ST_JUMP
        jr z,.jump
        cp ST_ATK
        jr nz,.done
        push ix
        push iy
        pop ix
        call move_ptr
        ld a,(iy+M_SU)
        add a,(iy+M_AC)
        ld b,a
        ld a,(iy+M_FL)
        ld e,a
        ld a,(ix+F_T)
        ld d,(ix+F_HITF)
        pop ix
        cp b
        jr nc,.rec
        set 0,c
        ld a,e
        and 3
        cp MF_LOW
        jr nz,$+4
        set 4,c
        cp MF_HIGH
        jr nz,.done
        set 5,c
        jr .done
.rec:   ld a,d
        or a
        jr nz,.done
        set 1,c
        jr .done
.down:  set 3,c
        jr .done
.jump:  ld a,(iy+F_AIR)
        or a
        jr z,.air
        set 0,c
        set 5,c
.air:   set 2,c
        ; coming this way?
        ld a,(ai_dist)
        cp 24
        jr c,.appr
        ld l,(iy+F_XL)
        ld h,(iy+F_XH)
        ld e,(ix+F_XL)
        ld d,(ix+F_XH)
        or a
        sbc hl,de               ; opponent - me
        ld a,(iy+F_VX)
        jr c,.left
        bit 7,a                 ; opponent to my right: approaching if moving left
        jr nz,.appr
        jr .done
.left:  bit 7,a
        jr nz,.done
        or a
        jr z,.done
.appr:  set 6,c
.done:  ; anything thrown at me, close and still coming?
        push ix
        ld ix,(opp)
        call my_proj
        pop ix
        ld a,(hl)
        or a
        jr z,.np
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld l,(ix+F_XL)
        ld h,(ix+F_XH)
        or a
        sbc hl,de
        jr nc,$+9
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld de,56*4
        or a
        sbc hl,de
        jr nc,.np
        set 7,c
.np:    ld a,c
        ret

ai_delay:   db 8,5,3
ai_pblock:  db 60,130,200
ai_ppunish: db 50,140,210
ai_paa:     db 50,130,200

; held directions per action (0 up, 1 down, 2 back, 3 forward)
ai_dirs:
        db 0, 8, 4, 4, 6, 9, 5, 0, 0, 2, 2, 0, 2, 1
; buttons per attack action (bits 4 A, 5 B; bit 1 = crouching)
ai_btns:
        db $10, $20, $12, $22, $30, $32, $31

; habits (in each fighter's block): per distance band, db upper limit, then
; (weight, action) pairs ending with weight 0 (the last takes what is left)
