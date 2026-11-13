; =====================================================================
;  ENEMIES: a small path language moves each enemy in polar space
;  (angle, depth). Groups of eight stream out of the vanishing point
;  along an entry path, settle into one of two rotating formation
;  rings, and peel off one at a time on the sector's attack runs.
; =====================================================================
E_ST    EQU 0           ; 0 free, 1 on a path, 2 holding in formation
E_TYPE  EQU 1
E_AF    EQU 2           ; angle, 8.8
E_A     EQU 3
E_RF    EQU 4           ; depth, 8.8 (224 = the player's orbit)
E_R     EQU 5
E_VAL   EQU 6           ; angular velocity 8.8
E_VAH   EQU 7
E_VRL   EQU 8           ; depth velocity 8.8
E_VRH   EQU 9
E_PL    EQU 10          ; path pointer
E_PH    EQU 11
E_TIM   EQU 12          ; frames left of the current move
E_SLOT  EQU 13          ; formation slot 0-7, + 8 for the outer ring
E_GRP   EQU 14
E_HP    EQU 15
E_COL   EQU 16          ; dim (high nibble), bright (low nibble)
E_FLG   EQU 17          ; b0 attacking, b1 mirrored, b2 bonus jewel
E_XL    EQU 18
E_XH    EQU 19
E_Y     EQU 20
E_SZ    EQU 21
E_WARN  EQU 22          ; warning flash frames
E_ANIM  EQU 23
E_MODE  EQU 24          ; 0 plain move, 1 accelerating, 2 homing
E_ACA   EQU 25
E_ACR   EQU 26
E_HIT   EQU 27          ; hit flash frames
ESIZE   EQU 32
NENEMY  EQU 16
ENEMY   EQU ENT

ST_PATH EQU 1
ST_HOLD EQU 2
EF_ATK  EQU 0
EF_MIR  EQU 1
EF_JWL  EQU 2

; path commands
P_END   EQU 0
P_MV    EQU 1           ; n, da, dr (1/16 a frame)
P_FORM  EQU 2           ; n: to the formation slot in n frames, then hold
P_AIM   EQU 3           ; n, depth: to the player's angle and that depth
P_AIMO  EQU 4           ; n, offset, depth: to the player's angle + offset
P_FIRE  EQU 5
P_WARN  EQU 6
P_CTR   EQU 7           ; back to the vanishing point
P_JMP   EQU 8           ; address
P_HOLD  EQU 9
P_ACC   EQU 10          ; n, dda, ddr (1/64 a frame, each frame)
P_HOME  EQU 11          ; n, dr: chase the player's angle
P_TO    EQU 12          ; n, da, depth: turn at da while going to that depth

SHOTS   EQU ENT+$200    ; 6 x 8: state, angle, depth, x lo, x hi, y, old depth
S_ST    EQU 0
S_A     EQU 1
S_R     EQU 2
S_XL    EQU 3
S_XH    EQU 4
S_Y     EQU 5
S_OLD   EQU 6
NSHOT   EQU 6
BULLETS EQU ENT+$230    ; 9 x 12
B_ST    EQU 0           ; b0 live, b1 homing
B_A     EQU 1
B_AF    EQU 2
B_RF    EQU 3
B_R     EQU 4
B_SPD   EQU 5           ; depth a frame, 1/16
B_XL    EQU 6
B_XH    EQU 7
B_Y     EQU 8
B_DAL   EQU 9           ; turn a frame (8.8): aimed at where you were
B_DAH   EQU 10
BSIZE   EQU 12
NBUL    EQU 9
FX      EQU ENT+$2A4    ; 8 x 8 explosions
X_T     EQU 0
X_SZ    EQU 1
X_XL    EQU 2
X_XH    EQU 3
X_Y     EQU 4
X_COL   EQU 5
NFX     EQU 8
POPS    EQU ENT+$2E4    ; 3 x 8 score popups
O_T     EQU 0
O_REC   EQU 1
O_XL    EQU 2
O_XH    EQU 3
O_Y     EQU 4
O_COL   EQU 5
NPOPS   EQU 3
        ASSERT POPS + NPOPS * 8 <= LISTA

RING0   EQU 104         ; formation depths
RING1   EQU 144

; ---------------------------------------------------------------------
enemies_clear:
        ld hl,ENT
        ld bc,$300
        xor a
        call fill
        xor a
        ld (nenemy),a
        ld (attackers),a
        ld a,$FF
        ld (ring_grp),a
        ld (ring_grp+1),a
        ret

enemies_update:
        call vbpoll
        ld ix,ENEMY
        ld b,NENEMY
.l:     push bc
        ld a,(ix+E_ST)
        or a
        call nz,enemy_one
        ld de,ESIZE
        add ix,de
        pop bc
        djnz .l
        ret

enemy_one:
        ld a,(ix+E_WARN)
        or a
        jr z,.nw
        dec (ix+E_WARN)
.nw:    ld a,(ix+E_HIT)
        or a
        jr z,.nh
        dec (ix+E_HIT)
.nh:    ld a,(ix+E_ST)
        cp ST_HOLD
        jp z,.hold
.run:   ld a,(ix+E_TIM)
        or a
        jr nz,.move
        call vm_next
        ld a,(ix+E_ST)
        or a
        ret z
        cp ST_HOLD
        jp z,.hold
.move:  dec (ix+E_TIM)
        ld a,(ix+E_MODE)
        or a
        jr z,.plain
        dec a
        jr nz,.home
        ; accelerating
        ld a,(ix+E_ACA)
        call sx4
        ld l,(ix+E_VAL)
        ld h,(ix+E_VAH)
        add hl,de
        ld (ix+E_VAL),l
        ld (ix+E_VAH),h
        ld a,(ix+E_ACR)
        call sx4
        ld l,(ix+E_VRL)
        ld h,(ix+E_VRH)
        add hl,de
        ld (ix+E_VRL),l
        ld (ix+E_VRH),h
        jr .plain
.home:  ; steer up to 1.75 a frame toward the player
        ld a,(p_a)
        sub (ix+E_A)
        ld hl,$01C0
        jp p,.hp
        ld hl,-$01C0
        neg
.hp:    cp 2
        jr nc,.hs
        ld hl,0
.hs:    ld (ix+E_VAL),l
        ld (ix+E_VAH),h
.plain: ld l,(ix+E_AF)
        ld h,(ix+E_A)
        ld e,(ix+E_VAL)
        ld d,(ix+E_VAH)
        add hl,de
        ld (ix+E_AF),l
        ld (ix+E_A),h
        ld l,(ix+E_RF)
        ld h,(ix+E_R)
        ld e,(ix+E_VRL)
        ld d,(ix+E_VRH)
        add hl,de
        bit 7,d
        jr nz,.dn
        jr nc,.rs
        ld hl,$FF00             ; past the edge: stays at the edge
        jr .rs
.dn:    jr c,.rs
        ld hl,0
.rs:    ld (ix+E_RF),l
        ld (ix+E_R),h
        jr .pos
.hold:  ld a,(ix+E_SLOT)
        ld c,a
        and 7
        rrca
        rrca
        rrca                    ; slot * 32
        bit 3,c
        ld hl,form_a0+1
        ld b,RING0
        jr z,.r0
        add a,16
        ld hl,form_a1+1
        ld b,RING1
.r0:    add a,(hl)
        ld (ix+E_A),a
        ld a,(breath)
        add a,b
        ld (ix+E_R),a
.pos:   ld a,(ix+E_A)
        ld b,(ix+E_R)
        call polar
        ld (ix+E_XL),l
        ld (ix+E_XH),h
        ld (ix+E_Y),c
        ld b,(ix+E_R)
        call sizeof
        ld (ix+E_SZ),a
        ; touching the player?
        bit EF_JWL,(ix+E_FLG)
        ret nz
        ld a,(ix+E_R)
        cp 206
        ret c
        cp 244
        ret nc
        ld a,(p_a)
        sub (ix+E_A)
        call absa
        cp 7
        ret nc
        ld a,(p_state)
        or a
        ret nz
        ld a,(p_inv)
        or a
        ret nz
        call player_hit
        jp kill_enemy

; A = signed 1/64 -> DE = it in 8.8 (x4)
sx4:    ld e,a
        add a,a
        sbc a,a
        ld d,a
        sla e
        rl d
        sla e
        rl d
        ret
; A = signed 1/16 -> DE = it in 8.8 (x16)
sx16:   ld e,a
        add a,a
        sbc a,a
        ld d,a
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ret

; mirrored enemies turn the other way: A = -A if so
mir:    bit EF_MIR,(ix+E_FLG)
        ret z
        neg
        ret

; ---------------------------------------------------------------------
; the path language: run commands until one takes time
; ---------------------------------------------------------------------
vm_next:
        ld l,(ix+E_PL)
        ld h,(ix+E_PH)
.c:     ld a,(hl)
        inc hl
        or a
        jp z,.end
        dec a
        jr z,.mv
        dec a
        jp z,.form
        dec a
        jp z,.aim
        dec a
        jp z,.aimo
        dec a
        jr z,.fire
        dec a
        jr z,.warn
        dec a
        jr z,.ctr
        dec a
        jr z,.jmp
        dec a
        jp z,.hold
        dec a
        jp z,.acc
        dec a
        jp z,.home
        ; P_TO
        ld a,(hl)
        inc hl
        ld (ix+E_TIM),a
        ld a,(hl)
        inc hl
        call mir
        call sx16
        ld (ix+E_VAL),e
        ld (ix+E_VAH),d
        jp .tod
.fire:  push hl
        call enemy_fire
        pop hl
        jr .c
.warn:  ld (ix+E_WARN),14
        push hl
        ld hl,sfx_warn
        ld a,3
        call play_sfx
        pop hl
        jr .c
.ctr:   ld (ix+E_R),4
        ld (ix+E_RF),0
        jr .c
.jmp:   ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr .c
.mv:    ld a,(hl)
        inc hl
        ld (ix+E_TIM),a
        ld a,(hl)
        inc hl
        call mir
        call sx16
        ld (ix+E_VAL),e
        ld (ix+E_VAH),d
        ld a,(hl)
        inc hl
.setr:  call sx16
        ld (ix+E_VRL),e
        ld (ix+E_VRH),d
        ld (ix+E_MODE),0
.save:  ld (ix+E_PL),l
        ld (ix+E_PH),h
        ret
.acc:   ld a,(hl)
        inc hl
        ld (ix+E_TIM),a
        ld a,(hl)
        inc hl
        call mir
        ld (ix+E_ACA),a
        ld a,(hl)
        inc hl
        ld (ix+E_ACR),a
        ld (ix+E_MODE),1
        jr .save
.home:  ld a,(hl)
        inc hl
        ld (ix+E_TIM),a
        ld a,(hl)
        inc hl
        call sx16
        ld (ix+E_VRL),e
        ld (ix+E_VRH),d
        ld (ix+E_MODE),2
        jr .save
.aim:   xor a
        jr .aim2
.aimo:  ld a,(hl)
        inc hl
        call mir
.aim2:  ld b,a                  ; offset from the player's angle
        ld a,(hl)
        inc hl
        ld (ix+E_TIM),a
        ld c,a
        ld a,(p_a)
        add a,b
        sub (ix+E_A)            ; signed difference
        push hl
        ld h,a
        ld l,0
        call sdiv
        ld (ix+E_VAL),l
        ld (ix+E_VAH),h
        pop hl
.tod:   ld a,(hl)
        inc hl
        push hl
        call vr_to
        pop hl
        ld (ix+E_MODE),0
        jp .save
.form:  ld a,(hl)
        inc hl
        ld (ix+E_TIM),a
        ld c,a
        push hl
        call form_target        ; B = angle there, D = depth there
        ld a,b
        sub (ix+E_A)
        ld h,a
        ld l,0
        push de
        ld c,(ix+E_TIM)
        call sdiv
        ld (ix+E_VAL),l
        ld (ix+E_VAH),h
        pop de
        ld a,d
        call vr_to
        ld (ix+E_MODE),0
        pop hl
        ld hl,path_hold
        jp .save
.hold:  ld (ix+E_ST),ST_HOLD
        bit EF_ATK,(ix+E_FLG)
        ret z
        res EF_ATK,(ix+E_FLG)
        ld hl,attackers
        dec (hl)
        ret
.end:   ; gone without being shot
        call enemy_gone
        ld a,(ix+E_GRP)
        call grp_left
        ret

path_hold:
        db P_HOLD

; A = target depth: the depth velocity that gets there in E_TIM frames
vr_to:  sub (ix+E_R)
        ld l,a
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld c,(ix+E_TIM)
        call sdiv
        add hl,hl
        ld (ix+E_VRL),l
        ld (ix+E_VRH),h
        ret

; C = frames -> B = the slot's angle then, D = its depth
form_target:
        ld a,(ix+E_SLOT)
        ld e,a
        and 7
        rrca
        rrca
        rrca
        bit 3,e
        ld hl,form_a0
        ld de,(spin0)
        ld b,RING0
        jr z,.r
        add a,16
        ld hl,form_a1
        ld de,(spin1)
        ld b,RING1
.r:     push bc
        ld c,a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(ix+E_TIM)
        ld b,a
.m:     add hl,de               ; where the ring will be in n frames
        djnz .m
        ld a,h
        add a,c
        pop bc
        ld d,b
        ld b,a
        ret

; the enemy leaves the board (shot or gone)
enemy_gone:
        ld (ix+E_ST),0
        ld hl,nenemy
        dec (hl)
        bit EF_ATK,(ix+E_FLG)
        ret z
        res EF_ATK,(ix+E_FLG)
        ld hl,attackers
        dec (hl)
        ret

; A = group: one fewer still to come (shot or gone). When none are
; left, its ring is free again.
grp_left:
        cp $FF
        ret z
        ld hl,grp_n
        call .ix
        dec (hl)
        ret nz
        ld b,a
        ld hl,ring_grp
        cp (hl)
        jr nz,.r1
        ld (hl),$FF
.r1:    inc hl
        cp (hl)
        ret nz
        ld (hl),$FF
        ret
.ix:    push af
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     pop af
        ret

; an enemy fires (if the wave allows it and a bullet is free)
enemy_fire:
        ld a,(demo_quiet)
        or a
        ret nz
        call random
        ld hl,w_fire
        cp (hl)
        ret nc
        ld a,(ix+E_R)
        cp 200
        ret nc                  ; too close to be fair
        ld a,(ix+E_A)
        ld b,(ix+E_R)
        jp bullet_new

; A = angle, B = depth: a bullet flies outward from there, curving to
; arrive where the player is now
bullet_new:
        push ix
        call .b
        pop ix
        ret
.b:     ld c,a
        ld ix,BULLETS
        ld de,BSIZE
        ld a,NBUL
.f:     bit 0,(ix+B_ST)
        jr z,.got
        add ix,de
        dec a
        jr nz,.f
        ret
.got:   ld a,(w_home)
        or 1
        ld (ix+B_ST),a
        ld (ix+B_A),c
        ld (ix+B_AF),$80
        ld (ix+B_RF),0
        ld (ix+B_R),b
        ld a,(w_bspd)
        ld (ix+B_SPD),a
        ; frames to the orbit: (224 - depth) * 16 / speed
        ld a,PR_ORBIT
        sub b
        jr nc,.n
        xor a
.n:     ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld c,(ix+B_SPD)
        call sdiv
        ld a,l
        or a
        jr nz,.t
        inc a
.t:     ld c,a
        ld a,(p_a)
        sub (ix+B_A)
        ld h,a
        ld l,0
        call sdiv
        ld (ix+B_DAL),l
        ld (ix+B_DAH),h
        ld hl,sfx_efire
        ld a,1
        jp play_sfx

; ---------------------------------------------------------------------
; shot: kill or damage. IX = enemy
; ---------------------------------------------------------------------
hit_enemy:
        ld (ix+E_HIT),3
        dec (ix+E_HP)
        jr z,kill_enemy
        ld hl,sfx_tink
        ld a,2
        jp play_sfx

kill_enemy:
        ld a,(ix+E_SZ)
        ld c,(ix+E_COL)
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld b,(ix+E_Y)
        call fx_new
        ; points
        ld a,(ix+E_TYPE)
        add a,a
        ld l,a
        ld h,0
        ld de,type_pts
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        bit EF_ATK,(ix+E_FLG)
        call nz,bcd2
        ld a,(ix+E_R)
        cp 176
        jr c,.np
        call bcd2               ; point blank: double again
        push de
        ld a,POP_x2
        ld c,YELLOW
        call pop_at_enemy
        pop de
.np:    call add_score
        ld hl,kills
        inc (hl)
        bit EF_JWL,(ix+E_FLG)
        jr z,.nj
        ld hl,bonus_hits
        inc (hl)
.nj:    ld hl,sfx_boom
        ld a,4
        call play_sfx
        call enemy_gone
        ; the group
        ld a,(ix+E_GRP)
        cp $FF
        ret z
        ld hl,grp_kill
        call grp_left.ix
        inc (hl)
        ld b,(hl)
        ld hl,grp_tot
        call grp_left.ix
        ld c,(hl)
        push af
        ld a,b
        cp c
        jr nz,.nb
        ; the whole group shot: a formation bonus
        ld hl,grp_bonus
        ld a,(hl)
        ld e,a
        ld d,0
        inc a
        cp 5
        jr c,.bb
        ld a,4
.bb:    ld (hl),a
        ld hl,fbonus_pop
        add hl,de
        ld a,(hl)
        ld (tmp1),a
        ld hl,fbonus_pts
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld d,(hl)
        ld e,a
        push de
        ld a,(tmp1)
        ld c,BCYAN
        call pop_at_enemy
        pop de
        call add_score
        ld hl,sfx_bonus
        ld a,5
        call play_sfx
.nb:    pop af
        jp grp_left

; DE = BCD * 2
bcd2:   ld a,e
        add a,e
        daa
        ld e,a
        ld a,d
        adc a,d
        daa
        ld d,a
        ret

type_pts:   ; points / 10, BCD
        dw $0005,$0008,$0010,$0010,$0015,$0010,$0020,$0030,$0050
fbonus_pts:
        dw $0100,$0150,$0200,$0300,$0500
fbonus_pop:
        db POP_1000,POP_1500,POP_2000,POP_3000,POP_5000

; A = popup, C = colour: at the enemy IX
pop_at_enemy:
        ld l,(ix+E_XL)
        ld h,(ix+E_XH)
        ld b,(ix+E_Y)
        ; A = popup, HL = x, B = y, C = colour
pop_new:
        push af
        push hl
        ld hl,POPS
        ld de,8
        ld a,NPOPS
.f:     inc (hl)
        dec (hl)
        jr z,.got
        add hl,de
        dec a
        jr nz,.f
        ld hl,POPS              ; all busy: the oldest goes
.got:   ex de,hl
        pop hl
        pop af
        ex de,hl
        ld (hl),30
        inc hl
        ld (hl),a
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        ret

; A = size class, C = colour (dim/bright), HL = x, B = y: an explosion
fx_new:
        push hl
        push af
        ld hl,FX
        ld de,8
        ld a,NFX
.f:     inc (hl)
        dec (hl)
        jr z,.got
        add hl,de
        dec a
        jr nz,.f
        ld hl,FX
.got:   pop af
        ld (hl),12
        inc hl
        ; size: classes 0-1 small, 2-3 middle, 4-5 large
        srl a
        ld (hl),a
        inc hl
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),b
        inc hl
        ld a,c
        and 15
        ld (hl),a
        ret

; ---------------------------------------------------------------------
; the wave: groups come in while a formation ring is free
; ---------------------------------------------------------------------
; HL = wave record
wave_start:
        ld de,w_atk1
        ld bc,W_HDR
        ldir
        ld (w_ptr),hl
        xor a
        ld (sp_n),a
        ld (grp_bonus),a
        ld (kills),a
        ld a,30
        ld (sp_gap),a
        ld a,60
        ld (att_tim),a
        ld hl,25*35             ; then the stragglers leave
        ld (w_esc),hl
        ; ring speeds from 1/64 a frame
        ld a,(w_spin0)
        call sx4
        ld (spin0),de
        ld a,(w_spin1)
        call sx4
        ld (spin1),de
        ld a,1
        ld (wave_on),a
        ret

; is the wave over? Z = yes
wave_done:
        ld a,(w_ng)
        or a
        ret nz
        ld a,(sp_n)
        or a
        ret nz
        ld a,(nenemy)
        or a
        ret

wave_update:
        ; the rings turn and breathe
        ld hl,(form_a0)
        ld de,(spin0)
        add hl,de
        ld (form_a0),hl
        ld hl,(form_a1)
        ld de,(spin1)
        add hl,de
        ld (form_a1),hl
        ld a,(frameno)
        rrca
        rrca
        and 15
        ld hl,breathtab
        add a,l
        ld l,a
        jr nc,.bn
        inc h
.bn:    ld a,(hl)
        ld (breath),a
        ld a,(wave_on)
        or a
        ret z
        call spawner
        call attacks
        ; the stragglers leave when the wave has run its time
        ld a,(w_ng)
        or a
        ret nz
        ld a,(sp_n)
        or a
        ret nz
        ld hl,(w_esc)
        ld a,h
        or l
        jr z,.leave
        dec hl
        ld (w_esc),hl
        ret
.leave: ld a,(frameno)
        and 7
        ret nz
        ld ix,ENEMY
        ld b,NENEMY
        ld de,ESIZE
.l:     ld a,(ix+E_ST)
        cp ST_HOLD
        jr z,.go
        add ix,de
        djnz .l
        ret
.go:    ld (ix+E_ST),ST_PATH
        ld (ix+E_TIM),0
        ld hl,path_leave
        ld (ix+E_PL),l
        ld (ix+E_PH),h
        ret

spawner:
        ld a,(sp_n)
        or a
        jp nz,.spawn
        ; a new group?
        ld a,(w_ng)
        or a
        ret z
        ld hl,sp_gap
        ld a,(hl)
        or a
        jr z,.g
        dec (hl)
        ret
.g:     ld hl,ring_grp
        ld c,0
        ld a,(hl)
        inc a
        jr z,.ring
        inc hl
        inc c
        ld a,(hl)
        inc a
        ret nz                  ; both rings busy
.ring:  ; group record: type, entry, angle, flags, colour, hp, count
        ld a,c
        ld (sp_ring),a
        ld hl,(w_ptr)
        ld de,sp_type
        ld bc,7
        ldir
        ld (w_ptr),hl
        ld hl,w_ng
        dec (hl)
        ld a,(grp_next)
        ld (sp_grp),a
        inc a
        cp 6
        jr c,.gn
        xor a
.gn:    ld (grp_next),a
        ld a,(sp_grp)
        ld b,a
        ld hl,ring_grp
        ld a,(sp_ring)
        add a,l
        ld l,a
        jr nc,.rn
        inc h
.rn:    ld (hl),b
        ld a,b
        ld hl,grp_n
        call grp_left.ix
        ld a,(sp_cnt)
        ld (hl),a
        ld a,b
        ld hl,grp_tot
        call grp_left.ix
        ld a,(sp_cnt)
        ld (hl),a
        ld a,b
        ld hl,grp_kill
        call grp_left.ix
        ld (hl),0
        ld a,(sp_cnt)
        ld (sp_n),a
        xor a
        ld (sp_i),a
        ld (sp_tim),a
        ld a,70
        ld (sp_gap),a
        ret
.spawn: ld hl,sp_tim
        ld a,(hl)
        or a
        jr z,.s
        dec (hl)
        ret
.s:     ld (hl),5
        call enemy_free         ; IX = a free enemy, or carry
        ret c
        ld hl,sp_n
        dec (hl)
        ld hl,nenemy
        inc (hl)
        ld (ix+E_ST),ST_PATH
        ld a,(sp_type)
        ld (ix+E_TYPE),a
        ld a,(sp_ang)
        ld (ix+E_A),a
        ld (ix+E_AF),0
        ld (ix+E_R),6
        ld (ix+E_RF),0
        ld (ix+E_TIM),0
        ld a,(sp_col)
        ld (ix+E_COL),a
        ld a,(sp_hp)
        ld (ix+E_HP),a
        ld a,(sp_grp)
        ld (ix+E_GRP),a
        ld a,(sp_ring)
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(sp_i)
        ld c,a
        add a,b
        ld (ix+E_SLOT),a
        ld a,c
        inc a
        ld (sp_i),a
        ld (ix+E_ANIM),c
        ; flags: b0 alternate mirror, b1 all mirrored, b2 jewels
        ld a,(sp_flag)
        ld b,0
        bit 1,a
        jr z,.m1
        set EF_MIR,b
.m1:    bit 0,a
        jr z,.m2
        bit 0,c
        jr z,.m2
        ld a,b
        xor 1 << EF_MIR
        ld b,a
.m2:    ld a,(sp_flag)
        bit 2,a
        jr z,.m3
        set EF_JWL,b
.m3:    ld (ix+E_FLG),b
        ld a,(sp_entry)
        add a,a
        ld l,a
        ld h,0
        ld de,entry_tab
        add hl,de
        ld a,(hl)
        ld (ix+E_PL),a
        inc hl
        ld a,(hl)
        ld (ix+E_PH),a
        ld a,(ix+E_A)
        ld b,(ix+E_R)
        call polar
        ld (ix+E_XL),l
        ld (ix+E_XH),h
        ld (ix+E_Y),c
        ld (ix+E_SZ),0
        ret

; IX = a free enemy (carry if none)
enemy_free:
        ld ix,ENEMY
        ld de,ESIZE
        ld b,NENEMY
.l:     ld a,(ix+E_ST)
        or a
        ret z
        add ix,de
        djnz .l
        scf
        ret

; the formation sends attackers, and some of it fires
attacks:
        ld a,(demo_quiet)
        or a
        ret nz
        ld a,(p_state)
        or a
        ret nz
        ; formation fire
        call random
        ld hl,w_ffire
        cp (hl)
        jr nc,.att
        call pick_hold
        jr c,.att
        call enemy_fire
.att:   ld hl,att_tim
        dec (hl)
        ret nz
        call random
        and 15
        ld b,a
        ld a,(w_aint)
        add a,b
        ld (hl),a
        ld a,(attackers)
        ld hl,w_amax
        cp (hl)
        ret nc
        call pick_hold
        ret c
        ; this one attacks
        ld (ix+E_ST),ST_PATH
        ld (ix+E_TIM),0
        set EF_ATK,(ix+E_FLG)
        ld hl,attackers
        inc (hl)
        call random
        ld b,a
        res EF_MIR,(ix+E_FLG)
        bit 0,b
        jr z,.nm
        set EF_MIR,(ix+E_FLG)
.nm:    ld a,(w_atk1)
        bit 1,b
        jr z,.a1
        ld a,(w_atk2)
.a1:    add a,a
        ld l,a
        ld h,0
        ld de,attack_tab
        add hl,de
        ld a,(hl)
        ld (ix+E_PL),a
        inc hl
        ld a,(hl)
        ld (ix+E_PH),a
        ret

; IX = a random enemy holding in formation (carry if none)
pick_hold:
        call random
        and 15
        ld c,a
        ld b,NENEMY
.l:     ld a,c
        and 15
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,ENEMY
        add hl,de
        push hl
        pop ix
        ld a,(ix+E_ST)
        cp ST_HOLD
        ret z
        inc c
        djnz .l
        scf
        ret

breathtab:
        db 0,2,4,5,6,5,4,2,0,-2,-4,-5,-6,-5,-4,-2

; ---------------------------------------------------------------------
; shots, bullets, explosions, popups
; ---------------------------------------------------------------------
shots_update:
        ld ix,SHOTS
        ld b,NSHOT
.l:     push bc
        ld a,(ix+S_ST)
        or a
        jr z,.n
        ld a,(ix+S_R)
        ld (ix+S_OLD),a
        sub 10
        jr c,.kill
        cp 14
        jr c,.kill
        ld (ix+S_R),a
        ld b,a
        ld a,(ix+S_A)
        call polar
        ld (ix+S_XL),l
        ld (ix+S_XH),h
        ld (ix+S_Y),c
        call shot_hits
        jr .n
.kill:  ld (ix+S_ST),0
.n:     ld de,8
        add ix,de
        pop bc
        djnz .l
        ret

; shot IX against every enemy: same angle (within the enemy's width),
; and its depth passed through the enemy's
shot_hits:
        ld iy,ENEMY
        ld b,NENEMY
.l:     ld a,(iy+E_ST)
        or a
        jr z,.n
        ld a,(iy+E_R)
        add a,6
        jr c,.n2
        cp (ix+S_R)
        jr c,.n                 ; enemy deeper than the shot now
.n2:    ld a,(ix+S_OLD)
        add a,6
        jr c,.n3
        cp (iy+E_R)
        jr c,.n                 ; enemy nearer than where the shot was
.n3:    ld a,(iy+E_SZ)
        ld e,a
        ld d,0
        ld hl,hittol
        add hl,de
        ld c,(hl)
        ld a,(ix+S_A)
        sub (iy+E_A)
        call absa
        cp c
        jr nc,.n
        ; hit
        ld (ix+S_ST),0
        push ix
        push iy
        pop ix
        call hit_enemy
        pop ix
        ret
.n:     ld de,ESIZE
        add iy,de
        djnz .l
        ret

hittol: db 5,5,5,6,7,8

bullets_update:
        ld ix,BULLETS
        ld b,NBUL
.l:     push bc
        bit 0,(ix+B_ST)
        jp z,.n
        ld a,(ix+B_SPD)
        call sx16
        ld l,(ix+B_RF)
        ld h,(ix+B_R)
        add hl,de
        jr c,.kill
        ld (ix+B_RF),l
        ld (ix+B_R),h
        ld a,h
        cp 244
        jr nc,.kill
        ld l,(ix+B_AF)
        ld h,(ix+B_A)
        ld e,(ix+B_DAL)
        ld d,(ix+B_DAH)
        add hl,de
        ld (ix+B_AF),l
        ld (ix+B_A),h
        bit 1,(ix+B_ST)
        jr z,.nh
        ld a,(frameno)
        and 1
        jr z,.nh
        ld a,(p_a)
        sub (ix+B_A)
        jr z,.nh
        jp m,.hm
        inc (ix+B_A)
        jr .nh
.hm:    dec (ix+B_A)
.nh:    ld a,(ix+B_A)
        ld b,(ix+B_R)
        call polar
        ld (ix+B_XL),l
        ld (ix+B_XH),h
        ld (ix+B_Y),c
        ; the player?
        ld a,(ix+B_R)
        cp 212
        jr c,.n
        ld a,(p_state)
        or a
        jr nz,.n
        ld a,(p_inv)
        or a
        jr nz,.n
        ld a,(p_a)
        sub (ix+B_A)
        call absa
        cp 5
        jr nc,.n
        call player_hit
.kill:  ld (ix+B_ST),0
.n:     ld de,BSIZE
        add ix,de
        pop bc
        dec b
        jp nz, .l
        ret

bullets_clear:
        ld hl,BULLETS
        ld bc,NBUL*BSIZE
        xor a
        jp fill

fx_update:
        ld hl,FX
        ld b,NFX
        ld de,8
.l:     ld a,(hl)
        or a
        jr z,.n
        dec (hl)
.n:     add hl,de
        djnz .l
        ld hl,POPS
        ld b,NPOPS
.p:     ld a,(hl)
        or a
        jr z,.pn
        dec (hl)
        and 3
        jr nz,.pn
        push hl
        inc hl
        inc hl
        inc hl
        inc hl
        dec (hl)                ; drifts up
        pop hl
.pn:    add hl,de
        djnz .p
        ret
