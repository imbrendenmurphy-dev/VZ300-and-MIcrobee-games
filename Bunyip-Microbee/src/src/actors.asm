; ==========================================================================
; actors.asm - creatures, guardians, thrown rocks and fire, things to pick up
;   VIBED BY BPM 2026
; ==========================================================================

; creature kinds: hp, image, ink, height, flags, speed, bite, throws
KT_HP    equ 0
KT_IMG   equ 1
KT_INK   equ 2
KT_F     equ 3
KT_FL    equ 4
KT_SPD   equ 5
KT_BITE  equ 6
KT_THROW equ 7           ; 0 none, else the shot type
KTAB:   db 3, IMG_RB_A, CBRED,    60, F_ANIM,       10, 6, 0       ; redback
        db 2, IMG_FF_A, CBROWN,   52, F_FLY+F_ANIM, 13, 5, 0       ; flying fox
        db 6, IMG_YW_A, CWHITE,  112, F_ANIM,        6, 9, T_ROCK  ; yowie
        db 12, IMG_BN_A, CBGREEN, 110, F_ANIM,       5, 12, T_FIRE ; bunyip
        db 2, IMG_CT_A, CBGREEN,  40, F_ANIM,        9, 4, 0       ; cane toad
        db 4, IMG_DB_A, CGREY,    60, F_FLY+F_ANIM, 12, 7, 0       ; drop bear
        db 3, IMG_MM_A, CBCYAN,   40, F_FLY+F_ANIM,  8, 3, T_FIRE  ; min min light
        db 8, IMG_CR_A, CGREEN,   48, F_ANIM,        7, 12, 0      ; saltwater croc
; guardians, by zone: ink, hp, shots per volley, shot type
BTAB:   db CYELLOW,  20, 1, T_FIRE
        db CBMAG,    26, 2, T_ROCK
        db CBCYAN,   34, 3, T_ROCK
        db CBGREEN,  44, 5, T_FIRE
; items: image, ink
ITAB:   db IMG_KEY, CYELLOW     ; gold key
        db IMG_KEY, CBBLUE      ; blue key
        db IMG_KEY, CBRED       ; red key
        db IMG_PIE, CYELLOW     ; meat pie
        db IMG_CHARGES, CBCYAN  ; charges
        db IMG_OPAL, CBMAG      ; opal
        db IMG_POWER, CWHITE    ; the Southern Cross
; scenery (zone codes 16 on): image, ink, height, flags
PTAB:   db IMG_URN, CBROWN, 52, F_SOLID+F_BREAK                 ; 0 urn
        db IMG_BRAZ_A, CYELLOW, 76, F_SOLID+F_ANIM              ; 1 brazier
        db IMG_STUMP, CBROWN, 56, F_SOLID                       ; 2 stump
        db IMG_SHROOM, CBCYAN, 40, 0                            ; 3 glowing fungus
        db IMG_NEST, CBRED, 56, F_SOLID+F_HURT                  ; 4 bull ant nest
        db IMG_CART, CGREY, 60, F_SOLID                         ; 5 ore cart
        db IMG_LANTERN, CYELLOW, 30, F_FLY                      ; 6 lantern
        db IMG_TNT, CBRED, 48, F_SOLID+F_BREAK+F_BOOM           ; 7 TNT
        db IMG_BONES, CWHITE, 24, 0                             ; 8 bones
        db IMG_REEDS, CBGREEN, 88, 0                            ; 9 reeds
        db IMG_TAR, CBMAG, 16, F_HURT                           ; 10 boiling mud
; what a smashed urn might hold
URNLOOT: db T_PIE, T_CHG, T_CHG, T_PIE, T_POWER, 0, T_CHG, 0
BOOMR   equ 180h            ; a TNT blast reaches 1.5 cells

; --------------------------------------------------------------------------
; spawn_all: the zone's things from ZH (zone header copy) into ENT
; --------------------------------------------------------------------------
spawn_all:
        ld hl,ENT
        ld de,ENT+1
        ld bc,NENT*ESIZE-1
        ld (hl),0
        ldir
        xor a
        ld (ncreat),a
        ld (nopals),a
        ld ix,ENT
        ld hl,ZH+(Z_ENTS-400h)
.l      ld a,(hl)
        cp 0FFh
        ret z
        inc hl
        ld b,(hl)               ; x
        inc hl
        ld c,(hl)               ; y
        inc hl
        push hl
        call spawn
        ld de,ESIZE
        add ix,de
        pop hl
        jr .l

; spawn: A = zone item code, B, C = cell; IX = record
spawn:  ld (ix+E_X),80h
        ld (ix+E_X+1),b
        ld (ix+E_Y),80h
        ld (ix+E_Y+1),c
        ld (ix+E_ST),ST_IDLE
        ld (ix+E_FL),0
        cp 16
        jr nc,.prop
        cp 8
        jr nc,.cr
        ; an item: types 1..7
        cp T_OPAL
        jp nz,mkitem
        ld hl,nopals
        inc (hl)
        jp mkitem
.prop   sub 16                  ; scenery
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,PTAB
        add hl,de
        ld (ix+E_TYPE),T_PROP
        ld a,(hl)
        ld (ix+E_IMG),a
        inc hl
        ld a,(hl)
        ld (ix+E_INK),a
        inc hl
        ld a,(hl)
        ld (ix+E_F),a
        inc hl
        ld a,(hl)
        ld (ix+E_FL),a
        ld (ix+E_CD),0
        ld a,b
        add a,c
        add a,a
        ld (ix+E_AN),a          ; braziers flicker out of step
        bit 4,(ix+E_FL)
        ret z
        call cellat             ; solid: mark its cell
        set 2,h
        set 3,h
        set 4,h
        ld (hl),1
        ret
.cr     ld hl,ncreat
        inc (hl)
        ld e,a                  ; 8, 9 = kind A, B; 10 = the guardian
        sub 8
        ld hl,ZKINDS
        add a,l
        ld l,a
        jr nc,.k
        inc h
.k      ld a,(hl)
        ld (ix+E_KIND),a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld bc,KTAB
        add hl,bc
        ld (ix+E_TYPE),T_ENEMY
        ld a,(hl)
        ld (ix+E_HP),a
        inc hl
        ld a,(hl)
        ld (ix+E_IMG),a
        inc hl
        ld a,(hl)
        ld (ix+E_INK),a
        inc hl
        ld a,(hl)
        ld (ix+E_F),a
        inc hl
        ld a,(hl)
        ld (ix+E_FL),a
        ld a,(ix+E_X)           ; a different step for each creature
        add a,(ix+E_Y+1)
        ld (ix+E_AN),a
        ld (ix+E_CD),30
        ld a,e
        cp 10
        ret nz
        ; the guardian: bigger, tougher, its own colour
        ld (ix+E_TYPE),T_BOSS
        ld a,(ix+E_FL)
        or F_BOSS
        ld (ix+E_FL),a
        ld (ix+E_F),128
        ld a,(zone)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,BTAB
        add hl,de
        ld a,(hl)
        ld (ix+E_INK),a
        inc hl
        ld a,(hl)
        ld (ix+E_HP),a
        ld (bosshp0),a
        ret

; mkitem: A = item type 1..7 -> IX becomes that item (where it is)
mkitem: ld (ix+E_TYPE),a
        ld (ix+E_ST),ST_IDLE
        ld (ix+E_FL),0
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,ITAB
        add hl,de
        ld a,(hl)
        ld (ix+E_IMG),a
        inc hl
        ld a,(hl)
        ld (ix+E_INK),a
        ld (ix+E_F),36
        ret

; tick: IX's timer down by nstep (not below 0) -> Z when it reaches 0
tick:   ld a,(ix+E_TM)
        ld hl,nstep
        sub (hl)
        jr nc,.t
        xor a
.t      ld (ix+E_TM),a
        or a
        ret

; kind: IX = creature -> HL = its KTAB entry
kind:   ld a,(ix+E_KIND)
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,KTAB
        add hl,de
        ret

; --------------------------------------------------------------------------
; actors: everything moves, nstep fields' worth
; --------------------------------------------------------------------------
actors: ld ix,ENT
        ld b,NENT
.l      push bc
        ld a,(ix+E_TYPE)
        or a
        call nz,actor
        call vbpoll
        ld de,ESIZE
        add ix,de
        pop bc
        djnz .l
        ld a,(losn)             ; next creature for a sight check
        inc a
        cp NENT
        jr c,.ln
        xor a
.ln     ld (losn),a
        ret

actor:  ld a,(ix+E_AN)
        ld hl,nstep
        add a,(hl)
        ld (ix+E_AN),a
        ld a,(ix+E_TYPE)
        cp T_PROP
        jp z,prop               ; (scenery works out distance only if it must)
        call reldist            ; pdx, pdy, dist
        ld a,(ix+E_TYPE)
        cp T_ENEMY
        jp c,item
        cp T_ROCK
        jp nc,shot
        ; ---- creatures and guardians
        ld a,(ix+E_ST)
        cp ST_DIE
        jp z,.die
        cp ST_PAIN
        jr z,.pain
        ; sight check, one creature a frame
        ld a,(losn)
        ld hl,ENT
        ld e,a
        ld d,0
        push ix
        pop bc
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        or a
        sbc hl,bc
        jr nz,.nlos
        ld a,(ix+E_FL)
        and ~F_LOS
        ld (ix+E_FL),a
        ld hl,(dist)
        ld a,h
        cp 12
        jr nc,.nlos
        call los
        jr nz,.nlos
        ld a,(ix+E_FL)
        or F_LOS
        ld (ix+E_FL),a
        ld (ix+E_ST),ST_CHASE   ; seen: wake up
.nlos   ld a,(ix+E_ST)
        cp ST_CHASE
        ret nz
        call chase
        jp attack
.pain   ld a,(ix+E_TM)
        ld hl,nstep
        sub (hl)
        jr nc,.p1
        xor a
.p1     ld (ix+E_TM),a
        ret nz
        ld (ix+E_ST),ST_CHASE
        ret
.die    call tick
        ret nz
        ld a,(ix+E_TYPE)
        ld (ix+E_TYPE),0        ; gone
        cp T_BOSS
        jr nz,.drop
        call boss_down
        ld a,T_PIE              ; the guardian leaves a pie
        jp mkitem
.drop   call rnd                ; one in four leaves charges or a pie
        and 7
        cp 2
        ld a,T_CHG
        jp c,mkitem
        ld a,T_PIE
        jp z,mkitem
        ret

; --------------------------------------------------------------------------
; prop: scenery.  Hazards sting, lit TNT goes off, smashed things puff away
; --------------------------------------------------------------------------
prop:   ld a,(ix+E_ST)
        cp ST_DIE
        jr z,.die
        cp ST_PAIN
        jr z,.fuse
        bit 6,(ix+E_FL)         ; F_HURT
        ret z
        ld a,(ix+E_CD)
        ld hl,nstep
        sub (hl)
        jr nc,.c
        xor a
.c      ld (ix+E_CD),a
        ret nz
        call reldist
        ld hl,(adx)
        ld de,-0D0h
        add hl,de
        ret c
        ld hl,(ady)
        add hl,de
        ret c
        ld (ix+E_CD),25         ; (adx, ady from reldist above)
        ld a,MSG_OUCH
        call message
        ld a,3
        jp hurt_player
.fuse   call tick
        ret nz
        jp smash
.die    call tick
        ret nz
        bit 7,(ix+E_FL)
        ld (ix+E_TYPE),0
        ret nz                  ; TNT leaves nothing
        call rnd                ; an urn may hold something
        and 7
        ld e,a
        ld d,0
        ld hl,URNLOOT
        add hl,de
        ld a,(hl)
        or a
        ret z
        jp mkitem

; smash: IX = breakable scenery: it bursts (TNT explodes)
smash:  ld a,(ix+E_ST)
        cp ST_DIE
        ret z
        ld (ix+E_ST),ST_DIE
        ld (ix+E_TM),PUFFT-1    ; straight to the puff
        bit 4,(ix+E_FL)
        jr z,.ns
        ld b,(ix+E_X+1)         ; no longer in the way
        ld c,(ix+E_Y+1)
        call cellat
        set 2,h
        set 3,h
        set 4,h
        ld (hl),0
.ns     bit 7,(ix+E_FL)
        jr nz,boom
        ld de,10
        call addscore
        ld a,SND_HIT
        jp snd_play

; boom: IX = TNT going off.  Hurts creatures and you within BOOMR, lights
;       the fuse of breakable things nearby
boom:   ld (ix+E_INK),CYELLOW
        ld (ix+E_F),120
        ld (ix+E_TM),PUFFT-1
        ld a,SND_BOSS
        call snd_play
        ld de,50
        call addscore
        call reldist
        ld hl,(adx)
        ld de,-BOOMR
        add hl,de
        jr c,.np
        ld hl,(ady)
        add hl,de
        jr c,.np
        ld a,12
        call hurt_player
.np     ld iy,ENT
        ld b,NENT
.l      push bc
        ld a,(iy+E_TYPE)
        cp T_ENEMY
        jr c,.n
        cp T_ROCK
        jr c,.cr                ; creatures and the guardian
        cp T_PROP
        jr nz,.n
        bit 5,(iy+E_FL)         ; breakable scenery: its fuse is lit
        jr z,.n
        ld a,(iy+E_ST)
        or a
        jr nz,.n
        call .near
        jr c,.n
        ld (iy+E_ST),ST_PAIN
        ld (iy+E_TM),10
        jr .n
.cr     ld a,(iy+E_ST)
        cp ST_DIE
        jr nc,.n
        call .near
        jr c,.n
        push ix
        push iy
        pop ix
        ld a,6
        call hurt_ent
        pop ix
.n      ld de,ESIZE
        add iy,de
        pop bc
        djnz .l
        ret
; .near: NC if IY is within BOOMR of IX on both axes
.near   ld l,(iy+E_X)
        ld h,(iy+E_X+1)
        ld e,(ix+E_X)
        ld d,(ix+E_X+1)
        or a
        sbc hl,de
        call absl
        ld de,-BOOMR
        add hl,de
        ret c
        ld l,(iy+E_Y)
        ld h,(iy+E_Y+1)
        ld e,(ix+E_Y)
        ld d,(ix+E_Y+1)
        or a
        sbc hl,de
        call absl
        ld de,-BOOMR
        add hl,de
        ret

; reldist: pdx, pdy = player - this (8.8), dist ~ |d| (8.8)
reldist:
        ld hl,(px+1)
        ld e,(ix+E_X)
        ld d,(ix+E_X+1)
        or a
        sbc hl,de
        ld (pdx),hl
        call absl
        ld (adx),hl
        ld hl,(py+1)
        ld e,(ix+E_Y)
        ld d,(ix+E_Y+1)
        or a
        sbc hl,de
        ld (pdy),hl
        call absl
        ld (ady),hl
        ; max + min / 2
        ld de,(adx)
        or a
        sbc hl,de
        add hl,de
        jr c,.xm                ; ady < adx
        srl d
        rr e
        add hl,de
        ld (dist),hl
        ret
.xm     srl h
        rr l
        add hl,de
        ld (dist),hl
        ret

; absl: HL = |HL|
absl:   bit 7,h
        ret z
negl:   ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ret

; --------------------------------------------------------------------------
; chase: step towards the player (8 directions, sliding on walls); stop
;        at arm's length
; --------------------------------------------------------------------------
chase:  ld hl,(dist)
        ld de,-200h             ; nearer than 2 cells: stay (guardians 2.5)
        bit 1,(ix+E_FL)
        jr z,.d
        ld de,-280h
.d      add hl,de
        ret nc
        call kind
        ld de,KT_SPD
        add hl,de
        ld a,(hl)
        bit 1,(ix+E_FL)         ; guardians are a little slower
        jr z,.s0
        ld e,a
        srl e
        srl e
        sub e
.s0     ld e,a
        ld a,(nstep)
        ld b,a
        xor a
.sm     add a,e
        djnz .sm
        ld (spd),a
        ; mostly along x, mostly along y, or both
        ld hl,(adx)
        ld de,(ady)
        push hl
        add hl,hl
        sbc hl,de               ; 2 adx - ady
        pop hl
        jr c,.yonly             ; 2 adx < ady
        ex de,hl
        push hl
        add hl,hl
        sbc hl,de               ; 2 ady - adx
        pop hl
        jr c,.xonly
        ld a,(spd)              ; diagonal: 0.7 each way
        ld e,a
        srl e
        srl e
        sub e
        ld (spd),a
        call .mx
        jr .my
.xonly  jr .mx
.yonly  jr .my
.mx     ld a,(spd)
        ld e,a
        ld d,0
        ld hl,(pdx)
        bit 7,h
        jr z,.mxp
        call negde
.mxp    ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        add hl,de
        push hl
        ld bc,30h               ; look a little ahead
        bit 7,d
        jr z,.mxa
        ld bc,-30h
.mxa    add hl,bc
        ld e,(ix+E_Y)
        ld d,(ix+E_Y+1)
        call cellxy
        pop hl
        or a
        ret nz
        ld (ix+E_X),l
        ld (ix+E_X+1),h
        ret
.my     ld a,(spd)
        ld e,a
        ld d,0
        ld hl,(pdy)
        bit 7,h
        jr z,.myp
        call negde
.myp    ld l,(ix+E_Y)
        ld h,(ix+E_Y+1)
        add hl,de
        push hl
        ld bc,30h
        bit 7,d
        jr z,.mya
        ld bc,-30h
.mya    add hl,bc
        ex de,hl
        ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        call cellxy
        pop hl
        or a
        ret nz
        ld (ix+E_Y),l
        ld (ix+E_Y+1),h
        ret

; --------------------------------------------------------------------------
; attack: bite when close, throw when it can see you
; --------------------------------------------------------------------------
attack: ld a,(ix+E_CD)
        ld hl,nstep
        sub (hl)
        jr nc,.c
        xor a
.c      ld (ix+E_CD),a
        ret nz
        ld hl,(dist)
        ld de,-260h             ; within 2.4 cells: lunge and bite (guardians 3)
        bit 1,(ix+E_FL)
        jr z,.bd
        ld de,-300h
.bd     add hl,de
        jr c,.far
        call kind
        ld de,KT_BITE
        add hl,de
        ld a,(hl)
        bit 1,(ix+E_FL)
        jr z,.b
        add a,4                 ; guardians bite harder
.b      call hurt_player
        ld (ix+E_CD),40
        ret
.far    ld a,(ix+E_FL)
        and F_LOS
        ret z
        ld hl,(dist)
        ld a,h
        cp 10
        ret nc
        bit 1,(ix+E_FL)
        jr nz,.volley
        call kind
        ld de,KT_THROW
        add hl,de
        ld a,(hl)
        or a
        ret z
        ld (ix+E_CD),70
        ld b,1
        jr throw
.volley ld a,(zone)
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,BTAB+2
        add hl,de
        ld b,(hl)               ; shots
        inc hl
        ld a,(hl)               ; type
        ld (ix+E_CD),60
; throw: A = shot type, B = shots (1, 2, 3 or 5), fanned out
throw:  ld (shtype),a
        ld a,b
        ld (shn),a
        ; aim: v = d * 20 / max(|dx|, |dy|)
        ld hl,(adx)
        ld de,(ady)
        or a
        sbc hl,de
        add hl,de
        jr nc,.m
        ex de,hl
.m      ld (shm),hl             ; the larger
        ld a,h
        or l
        ret z
        ld hl,(adx)
        call .scale
        ld a,(pdx+1)
        call .sign
        ld (svx),a
        ld hl,(ady)
        call .scale
        ld a,(pdy+1)
        call .sign
        ld (svy),a
        ; fan: shot k of n gets a sideways nudge of (k - (n-1)/2) * v/4
        ld a,(shn)
        dec a
        srl a
        neg
        ld (shk),a
.f      call .one
        ld a,(shk)
        inc a
        ld (shk),a
        ld hl,shn
        dec (hl)
        jr nz,.f
        ld a,SND_THROW
        jp snd_play
.scale  ld b,h                  ; HL = |d| -> A = |d| * 20 / m
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc               ; * 5
        add hl,hl
        add hl,hl               ; * 20
        ld de,(shm)
        call div16
        ld a,c
        ret
.sign   bit 7,a
        ld a,c
        ret z
        neg
        ret
.one    push ix                 ; a free slot
        ld iy,ENT
        ld b,NENT
.fs     ld a,(iy+E_TYPE)
        or a
        jr z,.got
        ld de,ESIZE
        add iy,de
        djnz .fs
        pop ix
        ret
.got    pop ix
        ld a,(shtype)
        ld (iy+E_TYPE),a
        ld a,(ix+E_X)
        ld (iy+E_X),a
        ld a,(ix+E_X+1)
        ld (iy+E_X+1),a
        ld a,(ix+E_Y)
        ld (iy+E_Y),a
        ld a,(ix+E_Y+1)
        ld (iy+E_Y+1),a
        ld (iy+E_ST),ST_CHASE
        ld (iy+E_TM),200        ; lifetime, fields
        ld (iy+E_FL),F_FLY
        ld (iy+E_F),28
        ld a,(shtype)
        cp T_FIRE
        ld a,IMG_ROCK
        ld b,CGREY
        jr nz,.r
        ld a,IMG_FIRE
        ld b,CBRED
.r      ld (iy+E_IMG),a
        ld (iy+E_INK),b
        ; velocity with the fan nudge: vx - k*vy/4, vy + k*vx/4
        ld a,(svy)
        call .q
        ld b,a
        ld a,(svx)
        sub b
        ld (iy+E_VX),a
        ld a,(svx)
        call .q
        ld b,a
        ld a,(svy)
        add a,b
        ld (iy+E_VY),a
        ret
.q      sra a                   ; A * k / 4
        sra a
        ld c,a
        ld a,(shk)
        or a
        ld b,a
        ld a,0
        ret z
        jp p,.qp
.qn     sub c
        inc b
        jr nz,.qn
        ret
.qp     add a,c
        djnz .qp
        ret

; --------------------------------------------------------------------------
; shot: flies straight; hurts the player, stops at walls
; --------------------------------------------------------------------------
shot:   ld a,(ix+E_TM)
        ld hl,nstep
        sub (hl)
        jr nc,.t
        xor a
.t      ld (ix+E_TM),a
        jr z,.gone
        ld a,(nstep)
        ld b,a
.st     push bc
        ld a,(ix+E_VX)
        call .add
        ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        add hl,de
        ld (ix+E_X),l
        ld (ix+E_X+1),h
        ld a,(ix+E_VY)
        call .add
        ld l,(ix+E_Y)
        ld h,(ix+E_Y+1)
        add hl,de
        ld (ix+E_Y),l
        ld (ix+E_Y+1),h
        pop bc
        djnz .st
        ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        ld e,(ix+E_Y)
        ld d,(ix+E_Y+1)
        call cellxy
        or a
        jr nz,.gone
        call reldist
        ld hl,(adx)
        ld de,-60h
        add hl,de
        ret c
        ld hl,(ady)
        add hl,de
        ret c
        ld a,(ix+E_TYPE)        ; hit
        cp T_FIRE
        ld a,10
        jr z,.h
        ld a,7
.h      call hurt_player
.gone   ld (ix+E_TYPE),0
        ret
.add    ld e,a                  ; DE = sign-extended A
        rla
        sbc a,a
        ld d,a
        ret

; --------------------------------------------------------------------------
; item: picked up when you walk over it
; --------------------------------------------------------------------------
item:   ld hl,(adx)
        ld de,-80h
        add hl,de
        ret c
        ld hl,(ady)
        add hl,de
        ret c
        ld a,(ix+E_TYPE)
        cp T_PIE
        jr c,.key
        jr z,.pie
        cp T_CHG
        jr z,.chg
        cp T_POWER
        jr z,.pow
        ld hl,opals             ; opal
        inc (hl)
        ld de,250
        call addscore
        ld a,MSG_OPAL
        jr .took
.key    ld e,a                  ; 1 gold, 2 blue, 3 red
        ld d,0
        ld hl,KBITS-1
        add hl,de
        ld a,(hl)
        ld hl,keys
        or (hl)
        ld (hl),a
        ld a,e
        add a,MSG_GKEY-1
        ld (ix+E_TYPE),0
        call message
        ld de,100
        call addscore
        ld a,1
        ld (hud_dirty),a
        ld a,SND_KEY
        jp snd_play
.pie    ld a,(health)           ; only when hurt
        cp 100
        ret nc
        add a,25
        cp 100
        jr c,.p
        ld a,100
.p      ld (health),a
        ld a,MSG_PIE
        jr .took
.chg    ld a,(charges)
        cp 99
        ret nc
        add a,15
        cp 99
        jr c,.c
        ld a,99
.c      ld (charges),a
        ld a,MSG_CHG
        jr .took
.pow    ld hl,POWERT
        ld (pwrt),hl
        ld de,100
        call addscore
        ld a,MSG_POWER
.took   ld (ix+E_TYPE),0
        call message
        ld a,1
        ld (hud_dirty),a
        ld a,SND_PICK
        jp snd_play

KBITS:  db 1,2,4

; --------------------------------------------------------------------------
; los: IX = creature -> Z if nothing solid between it and the player
;      (32 samples along the line)
; --------------------------------------------------------------------------
los:    ld hl,(pdx)
        call .d32
        ld (lsx),hl
        ld hl,(pdy)
        call .d32
        ld (lsy),hl
        ld l,(ix+E_X)
        ld h,(ix+E_X+1)
        ld (lx),hl
        ld l,(ix+E_Y)
        ld h,(ix+E_Y+1)
        ld (ly),hl
        ld b,31
.l      push bc
        ld hl,(lx)
        ld de,(lsx)
        add hl,de
        ld (lx),hl
        ld hl,(ly)
        ld de,(lsy)
        add hl,de
        ld (ly),hl
        ex de,hl
        ld hl,(lx)
        call cellxy
        pop bc
        or a
        ret nz
        djnz .l
        xor a
        ret
.d32    ld b,5                  ; HL / 32, signed
.dl     sra h
        rr l
        djnz .dl
        ret

; --------------------------------------------------------------------------
; hurt_ent: IX = creature, A = damage
; --------------------------------------------------------------------------
hurt_ent:
        ld b,a
        ld a,(ix+E_HP)
        sub b
        jr c,.dead
        jr z,.dead
        ld (ix+E_HP),a
        ld (ix+E_ST),ST_PAIN
        ld (ix+E_TM),6
        ld a,(ix+E_FL)
        or F_LOS
        ld (ix+E_FL),a
        ld a,SND_HIT
        jp snd_play
.dead   ld (ix+E_HP),0
        ld (ix+E_ST),ST_DIE
        ld (ix+E_TM),24         ; flicker, then a puff of smoke
        ld hl,kills
        inc (hl)
        ld de,100
        ld a,(ix+E_TYPE)
        cp T_BOSS
        jr nz,.s
        ld (ix+E_TM),64         ; the guardian takes longer to go
        ld de,2000
.s      call addscore
        ld a,SND_DIE
        jp snd_play

; boss_down: the guardian has fallen: its gates open
boss_down:
        ld a,1
        ld (bossdead),a
        ld hl,MAP
        ld bc,1024
.l      ld a,(hl)
        cp C_BGATE
        jr nz,.n
        ld (hl),0
.n      inc hl
        dec bc
        ld a,b
        or c
        jr nz,.l
        ld a,1
        ld (hud_dirty),a
        ld a,SND_BOSS
        call snd_play
        ld a,MSG_BOSS
        jp message

; hurt_player: A = damage
hurt_player:
        ld b,a
        ld a,(health)
        sub b
        jr nc,.h
        xor a
.h      ld (health),a
        ld a,1
        ld (hud_dirty),a
        ld a,8
        ld (hurtt),a
        ld a,SND_HURT
        jp snd_play
