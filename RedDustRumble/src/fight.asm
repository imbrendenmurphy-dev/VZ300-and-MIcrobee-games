; ============================================================================
;  FIGHT: fighters, moves, hits and blocks, rounds
;  Logic runs at 25 ticks a second (one tick = two fields).
;  x positions are in quarter pixels; y is pixels above the ground.
; ============================================================================

; fighter record
F_CHAR  equ 0
F_XL    equ 1
F_XH    equ 2
F_Y     equ 3
F_FACE  equ 4       ; 0 facing right, 1 facing left
F_ST    equ 5
F_T     equ 6       ; ticks in this state
F_MV    equ 7       ; current move
F_HP    equ 8
F_HITF  equ 9       ; move connected: 1 hit, 2 blocked
F_STUN  equ 10
F_JT    equ 11
F_VX    equ 12      ; signed, quarter pixels per tick
F_FRM   equ 13
F_AIR   equ 14      ; air attack used this jump
F_PAD   equ 15      ; held: 0 up 1 down 2 left 3 right 4 A 5 B
F_PRS   equ 16      ; new presses this tick
F_TA    equ 17
F_TB    equ 18
F_WINS  equ 19
F_CPU   equ 20
F_XF    equ 21      ; transform page when facing right
F_BANK  equ 22
F_DIRL  equ 23
F_DIRH  equ 24
F_PUSH  equ 25
F_INV   equ 26
F_KDP   equ 27
F_ANIM  equ 28
F_CRCH  equ 29      ; stunned while crouching
F_AT    equ 30      ; air attack timer
F_DEFL  equ 31
F_DEFH  equ 32
F_SPEC  equ 33      ; special requested this tick
F_REL   equ 34      ; held directions relative to facing: 0 up 1 down 2 back 3 fwd
F_AIACT equ 35
F_AICNT equ 36
F_AIPAD equ 37
F_AIWAIT equ 38
F_HPOS  equ 39
F_HIST  equ 40      ; 16 ticks of the opponent's state, for the CPU's reaction delay
F_JDIR  equ 56
F_HPOLD equ 57
F_SEQ   equ 58      ; progress through the finisher's two directions
F_SEQT  equ 59
F_HIDE  equ 60      ; not drawn (sent flying off the screen)
F_VY    equ 61
FSIZE   equ 64

; states
ST_STAND  equ 0
ST_CROUCH equ 1
ST_PREJ   equ 2
ST_JUMP   equ 3
ST_LAND   equ 4
ST_ATK    equ 5
ST_HSTUN  equ 6
ST_BSTUN  equ 7
ST_KD     equ 8
ST_KO     equ 9
ST_WIN    equ 10
ST_FROZEN equ 11
ST_TAUNT  equ 12
ST_DIZZY  equ 13
ST_FIN    equ 14
ST_FLY    equ 15
ST_GONE   equ 16

; fighter definition
D_WALKF equ 8       ; (offsets into the fighter block header)
D_WALKB equ 9
D_JVXF  equ 10
D_JVXB  equ 11
D_JLEN  equ 12
D_HURTH equ 13
D_FIN1  equ 14      ; finisher: first and second direction (F_REL bits)
D_FIN2  equ 15
D_FINMV equ 16      ; the move whose poses it uses
D_FINVX equ 17      ; how the loser is launched
D_FINVY equ 18
D_JTABL equ 20
D_JTABH equ 21
D_MOVEL equ 22
D_DIR   equ 24
D_HAB   equ 26
D_NAME  equ 28
D_FINNAME equ 30
D_AIX   equ 32
; move record (16 bytes)
M_SU  equ 0
M_AC  equ 1
M_RC  equ 2
M_DMG equ 3
M_X0  equ 4
M_X1  equ 5
M_Y0  equ 6
M_Y1  equ 7
M_FL  equ 8
M_HS  equ 9
M_BS  equ 10
M_FR  equ 11
M_FW  equ 12
M_FS  equ 13
M_VX  equ 14
M_FX  equ 15        ; bits 0-1: 1 whip high, 2 whip low, 3 thrown; bit 2 a straight
                    ; line (staff); bits 2-3 thrown shape; bit 7 a crouching move
MF_LOW   equ 1
MF_HIGH  equ 2
MF_KD    equ 4
MF_SPEC  equ 8
MF_LIGHT equ 16
MF_INVSU equ 32
MF_RISE  equ 64
MF_AIR   equ 128

MV_SA  equ 0
MV_SB  equ 1
MV_CA  equ 2
MV_CB  equ 3
MV_JA  equ 4
MV_JB  equ 5
MV_SP1 equ 6
MV_SP2 equ 7

SCRLO   equ 8           ; screen edges the fighters can't pass (pixels)
SCRHI   equ 119
CAMMAX  equ 64          ; camera range: 0..64 pixels
CAMSLACK equ 12         ; the camera ignores the fight drifting this far
MINSEP  equ 13*4
SPECWIN equ 3       ; ticks allowed between A and B for a signature move

; ---------------------------------------------------------------------------
; set_state: A = state (resets the state timer)
set_state:
        ld (ix+F_ST),a
        ld (ix+F_T),0
        ret

; move_ptr: IY = move record for (ix+F_MV)
move_ptr:
        push hl
        push de
        ld l,(ix+F_DEFL)
        ld h,(ix+F_DEFH)
        ld de,D_MOVEL
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(ix+F_MV)
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        add hl,de
        push hl
        pop iy
        pop de
        pop hl
        ret

; def_byte: A = offset into the fighter definition -> A = value
def_byte:
        push hl
        push de
        ld l,(ix+F_DEFL)
        ld h,(ix+F_DEFH)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ret

; add_x: DE = signed quarter pixels, forwards if facing right (A=0)...
; move_fwd: A = signed quarter pixels in the facing direction
move_fwd:
        bit 0,(ix+F_FACE)
        jr z,move_x
        neg
; move_x: A = signed quarter pixels (+ = right); clamps to the walls
move_x:
        ld e,a
        ld d,0
        bit 7,a
        jr z,$+3
        dec d
        ld l,(ix+F_XL)
        ld h,(ix+F_XH)
        add hl,de
; set_x: HL = new x, kept between the screen edges (camera + 8 .. + 119)
set_x:
        push hl
        ld a,(cam)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,SCRLO*4
        add hl,de
        ex de,hl                ; DE = left edge
        pop hl
        bit 7,h
        jr nz,.lo
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.ok1
.lo:    ex de,hl
        jr .st
.ok1:   push hl
        ex de,hl
        ld de,(SCRHI-SCRLO)*4
        add hl,de
        ex de,hl                ; DE = right edge
        pop hl
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.st
        ex de,hl
.st:    ld (ix+F_XL),l
        ld (ix+F_XH),h
        ret

; scr_x: IX = fighter -> HL = its x on the screen in pixels (signed)
scr_x:
        ld l,(ix+F_XL)
        ld h,(ix+F_XH)
        srl h
        rr l
        srl h
        rr l
        ld a,(cam)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ret

; cam_update: the camera follows the fighters' midpoint, 2 pixels a tick
cam_update:
        ld a,(cam_lock)
        or a
        ret nz
        ld hl,(p1+F_XL)
        ld de,(p2+F_XL)
        add hl,de
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l                    ; midpoint in pixels
        ld de,64
        or a
        sbc hl,de
        jr nc,.p
        ld hl,0
.p:     ld a,h
        or a
        jr nz,.max
        ld a,l
        cp CAMMAX+1
        jr c,.ok
.max:   ld a,CAMMAX
.ok:    and $FE
        ld b,a                  ; where the camera would centre the fight
        ; dead zone: only move when that is more than CAMSLACK away
        ld a,(cam)
        sub b
        jr nc,.pos
        neg
.pos:   cp CAMSLACK+1
        ret c
        ld a,(cam)
        cp b
        ret z
        jr c,.up
        sub 2
        jr .set
.up:    add a,2
.set:   ld (cam),a
        ld a,1
        ld (scrolled),a
        ret

; get_rel: held directions relative to facing -> (ix+F_REL)
get_rel:
        ld a,(ix+F_PAD)
        ld c,a
        and 3
        ld b,a
        bit 0,(ix+F_FACE)
        jr nz,.l
        ld a,c
        and $0C
        or b
        jr .s
.l:     bit 3,c
        jr z,$+4
        set 2,b
        bit 2,c
        jr z,$+4
        set 3,b
        ld a,b
.s:     ld (ix+F_REL),a
        ret

; ---------------------------------------------------------------------------
; fighter_input: fill F_PAD / F_PRS for this tick (player or CPU)
; ---------------------------------------------------------------------------
fighter_input:
        ld a,(inputs_off)
        or a
        jr z,.on
        ld (ix+F_PAD),0
        ld (ix+F_PRS),0
        ret
.on:    ld a,(ix+F_CPU)
        or a
        jp nz,ai_think
        push ix
        pop hl
        ld de,p1
        or a
        sbc hl,de
        jr nz,.p2
        ld a,(p1_cur)
        ld (ix+F_PAD),a
        ld hl,p1_new
        jr .tk
.p2:    ld a,(p2_cur)
        ld (ix+F_PAD),a
        ld hl,p2_new
.tk:    call take_new
        and $30
        or (ix+F_PRS)
        ld (ix+F_PRS),a
        ret

; ---------------------------------------------------------------------------
; update_fighter: IX = fighter, IY = opponent (IY is restored on exit)
; ---------------------------------------------------------------------------
update_fighter:
        ld (opp),iy
        call get_rel
        call seq_track
        ; button timers and the signature-move check
        ld a,(ix+F_PRS)
        bit 4,a
        jr z,.na
        ld (ix+F_TA),0
        jr .tb
.na:    ld a,(ix+F_TA)
        inc a
        jr z,.tb
        ld (ix+F_TA),a
.tb:    ld a,(ix+F_PRS)
        bit 5,a
        jr z,.nb
        ld (ix+F_TB),0
        jr .sp
.nb:    ld a,(ix+F_TB)
        inc a
        jr z,.sp
        ld (ix+F_TB),a
.sp:    ld (ix+F_SPEC),0
        ld a,(ix+F_TA)
        or a
        jr nz,.s2
        ld a,(ix+F_TB)
        cp SPECWIN+1
        jr c,.sy
.s2:    ld a,(ix+F_TB)
        or a
        jr nz,.sn
        ld a,(ix+F_TA)
        cp SPECWIN+1
        jr nc,.sn
.sy:    ld (ix+F_SPEC),1
.sn:    inc (ix+F_T)
        jr nz,.tok
        dec (ix+F_T)
.tok:   ld a,(ix+F_ST)
        add a,a
        ld e,a
        ld d,0
        ld hl,state_tab
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call jp_hl
        ld iy,(opp)
        ret

jp_hl:  jp (hl)

state_tab:
        dw st_free, st_free, st_prej, st_jump, st_land, st_atk
        dw st_hstun, st_bstun, st_kd, st_ko, st_win, st_frozen
        dw st_taunt, st_dizzy, st_fin, st_fly, st_gone

st_frozen:
        ld (ix+F_FRM),FR_IDLE
        ret
st_win:
        ld (ix+F_FRM),FR_WIN
        ret

; ---- standing / crouching: free to act
st_free:
        ld (ix+F_INV),0
        ld a,(ix+F_SPEC)
        or a
        jp nz,start_special
        ld a,(ix+F_PRS)
        and $30
        jr z,.nobtn
        ld c,MV_SA
        bit 4,a
        jr nz,.btn
        ld c,MV_SB
.btn:   bit 1,(ix+F_REL)
        jr z,.st
        inc c
        inc c                   ; crouching version
.st:    ld a,c
        jp start_move
.nobtn: ld a,(ix+F_REL)
        bit 0,a
        jr z,.nojump
        ; jump: straight, forwards or backwards
        ld c,0
        bit 3,a
        jr z,$+4
        ld c,1
        bit 2,a
        jr z,$+4
        ld c,2
        ld (ix+F_JDIR),c
        ld a,ST_PREJ
        call set_state
        ld (ix+F_FRM),FR_CROUCH
        ret
.nojump:
        bit 1,a
        jr z,.stand
        ; crouch (block pose if holding back under threat)
        ld a,ST_CROUCH
        cp (ix+F_ST)
        call nz,set_state
        ld (ix+F_FRM),FR_CROUCH
        bit 2,(ix+F_REL)
        ret z
        call threat
        ret z
        ld (ix+F_FRM),FR_CBLOCK
        ret
.stand: ld a,ST_STAND
        cp (ix+F_ST)
        call nz,set_state
        ld a,(ix+F_REL)
        bit 2,a
        jr z,.nb
        call threat
        jr z,.back
        ld (ix+F_FRM),FR_BLOCK  ; holding back while attacked: block pose
        ret
.back:  ld a,D_WALKB
        call def_byte
        neg
        call move_fwd
        jr .walk
.nb:    bit 3,(ix+F_REL)
        jr z,.idle
        ld a,D_WALKF
        call def_byte
        call move_fwd
.walk:  inc (ix+F_ANIM)
        ld a,(ix+F_ANIM)
        and 4
        ld a,FR_WALK1
        jr z,$+4
        ld a,FR_WALK2
        ld (ix+F_FRM),a
        ret
.idle:  inc (ix+F_ANIM)           ; breathing: two poses, 16 ticks each
        ld a,FR_IDLE
        bit 4,(ix+F_ANIM)
        jr z,$+4
        ld a,FR_IDLE2
        ld (ix+F_FRM),a
        ret

; threat: NZ if the opponent is winding up or striking within 72 pixels
threat:
        ld iy,(opp)
        ld a,(iy+F_ST)
        cp ST_ATK
        jr z,.atk
        cp ST_JUMP
        jr nz,.no
        ld a,(iy+F_AIR)
        or a
        jr z,.no
        jr .near
.atk:   ; not once it's recovering
        push ix
        push iy
        pop ix
        call move_ptr
        ld a,(iy+M_SU)
        add a,(iy+M_AC)
        pop ix
        ld iy,(opp)
        cp (iy+F_T)
        jr c,.no
        jr z,.no
.near:  call dist_px
        cp 72
        jr nc,.no
        or 1
        ret
.no:    xor a
        ret

; dist_px: A = |x - opponent x| in pixels (capped at 255)
dist_px:
        push hl
        push de
        ld iy,(opp)
        ld l,(ix+F_XL)
        ld h,(ix+F_XH)
        ld e,(iy+F_XL)
        ld d,(iy+F_XH)
        or a
        sbc hl,de
        jr nc,.p
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
.p:     srl h
        rr l
        srl h
        rr l
        ld a,l
        pop de
        pop hl
        ret

; start_move: A = move (normal)
start_move:
        ld (ix+F_MV),a
        ld (ix+F_HITF),0
        ld a,ST_ATK
        call set_state
        call move_ptr
        ld a,(iy+M_FW)
        ld (ix+F_FRM),a
        ret

; start_special: down held -> signature move 2, else 1
start_special:
        ; the finisher, if the stick has just been through its two directions
        ld a,(fin_on)
        dec a
        jr nz,.nf
        ld a,(ix+F_SEQ)
        cp 3
        jr nz,.nf
        push ix
        pop hl
        ld de,(fin_who)
        or a
        sbc hl,de
        jp z,start_fin
.nf:    bit 0,(ix+F_REL)        ; up held: a taunt
        jp nz,start_taunt
        ld a,MV_SP1
        bit 1,(ix+F_REL)
        jr z,$+4
        ld a,MV_SP2
        call start_move
        ld (ix+F_TA),$7F
        ld (ix+F_TB),$7F
        ld hl,sfx_special
        jp play_sfx

st_prej:
        ld a,(ix+F_SPEC)        ; A+B just after pushing up: still a taunt
        or a
        jp nz,start_taunt
        ld (ix+F_FRM),FR_CROUCH
        ld a,(ix+F_T)
        cp 2
        ret c
        ld a,ST_JUMP
        call set_state
        ld (ix+F_JT),0
        ld (ix+F_AIR),0
        ld a,(ix+F_JDIR)
        ld c,0
        or a
        jr z,.v
        cp 1
        ld a,D_JVXF
        jr z,.f
        ld a,D_JVXB
        call def_byte
        neg
        ld c,a
        jr .v
.f:     call def_byte
        ld c,a
.v:     ld a,c
        bit 0,(ix+F_FACE)
        jr z,$+4
        neg
        ld (ix+F_VX),a
        ld (ix+F_FRM),FR_JUMP
        ret

st_jump:
        ld a,D_JTABL
        call def_byte
        ld l,a
        ld a,D_JTABH
        call def_byte
        ld h,a
        ld e,(ix+F_JT)
        ld d,0
        add hl,de
        ld a,(hl)
        ld (ix+F_Y),a
        inc (ix+F_JT)
        ld a,(ix+F_VX)
        call move_x
        ; air attack
        ld a,(ix+F_AIR)
        or a
        jr nz,.atk
        ld a,(ix+F_PRS)
        and $30
        jr z,.pose
        ld c,MV_JA
        bit 4,a
        jr nz,$+4
        ld c,MV_JB
        ld (ix+F_MV),c
        ld (ix+F_AIR),1
        ld (ix+F_AT),0
        ld (ix+F_HITF),0
.atk:   call move_ptr
        ld a,(ix+F_AT)
        inc (ix+F_AT)
        cp (iy+M_SU)
        jr c,.pose
        sub (iy+M_SU)
        cp (iy+M_AC)
        jr nc,.pose
        ld a,(iy+M_FS)
        ld (ix+F_FRM),a
        jr .land
.pose:  ld (ix+F_FRM),FR_JUMP
.land:  ld a,D_JLEN
        call def_byte
        cp (ix+F_JT)
        ret nz
        ld (ix+F_Y),0
        ld (ix+F_AIR),0
        ld a,ST_LAND
        call set_state
        ld (ix+F_FRM),FR_CROUCH
        ret

st_land:
        ld (ix+F_FRM),FR_CROUCH
        ld a,(ix+F_T)
        cp 2
        ret c
        jp to_free

; to_free: back to standing or crouching
to_free:
        ld (ix+F_INV),0
        ld (ix+F_Y),0
        ld a,ST_STAND
        bit 1,(ix+F_REL)
        jr z,$+4
        ld a,ST_CROUCH
        call set_state
        ld (ix+F_FRM),FR_IDLE
        cp ST_CROUCH
        ret nz
        ld (ix+F_FRM),FR_CROUCH
        ret

; ---- attacking on the ground
st_atk:
        call move_ptr
        ; a normal can turn into a signature move: within its first ticks, or
        ; (light moves) once it has connected
        ld a,(ix+F_SPEC)
        or a
        jr z,.go
        ld a,(ix+F_MV)
        cp MV_SP1
        jr nc,.go
        ld a,(ix+F_HITF)
        or a
        jr z,.early
        bit 4,(iy+M_FL)
        jp nz,start_special
        jr .go
.early: ld a,(ix+F_T)
        cp SPECWIN+1
        jp c,start_special
.go:    ld a,(ix+F_T)
        cp (iy+M_SU)
        jr nc,.act
        ; wind-up
        ld a,(iy+M_FW)
        ld (ix+F_FRM),a
        ld a,(iy+M_FL)
        and MF_INVSU
        ld (ix+F_INV),a
        ret
.act:   ld (ix+F_INV),0
        sub (iy+M_SU)
        ld c,a                  ; ticks since the strike began
        cp (iy+M_AC)
        jr nc,.rec
        ld a,(iy+M_FS)
        ld (ix+F_FRM),a
        ld a,(iy+M_FX)
        and 3
        cp 3
        jr z,.throw
        ld a,(iy+M_VX)
        or a
        call nz,move_fwd
        call .rise
        ret
.throw: ld a,c                  ; it leaves the hand as the strike starts
        or a
        call z,proj_spawn
        ret
.rec:   ld a,c
        sub (iy+M_AC)
        cp (iy+M_RC)
        jp nc,to_free
        ld a,(iy+M_FR)
        ld (ix+F_FRM),a
        call .rise
        ; a rising move lands in a crouch
        bit 6,(iy+M_FL)
        ret z
        ld a,(ix+F_Y)
        or a
        ret nz
        ld (ix+F_FRM),FR_CROUCH
        ret
.rise:  bit 6,(iy+M_FL)
        ret z
        ld a,c
        cp 11
        jr c,.r1
        xor a
        ld (ix+F_Y),a
        ret
.r1:    ld e,a
        ld d,0
        ld hl,tinroof_y
        add hl,de
        ld a,(hl)
        ld (ix+F_Y),a
        ret

; ---- reeling from a hit / blocking
st_hstun:
        ld (ix+F_FRM),FR_HIT
        call do_push
        dec (ix+F_STUN)
        ret nz
        jp to_free

st_bstun:
        ld (ix+F_FRM),FR_BLOCK
        ld a,(ix+F_CRCH)
        or a
        jr z,$+6
        ld (ix+F_FRM),FR_CBLOCK
        call do_push
        dec (ix+F_STUN)
        ret nz
        jp to_free

; do_push: slide away from the opponent; at a wall the opponent slides instead
do_push:
        ld a,(ix+F_PUSH)
        or a
        ret z
        ld c,8                  ; up to 2 pixels a tick
        cp 9
        jr nc,.s
        ld c,a
.s:     sub c
        ld (ix+F_PUSH),a
        ld l,(ix+F_XL)
        ld h,(ix+F_XH)
        ld (old_x),hl
        ld a,c
        neg
        push bc
        call move_fwd           ; backwards
        pop bc
        ld l,(ix+F_XL)
        ld h,(ix+F_XH)
        ld de,(old_x)
        or a
        sbc hl,de
        ld a,l
        bit 7,a
        jr z,$+4
        neg                     ; A = distance actually moved
        ld b,a
        ld a,c
        sub b
        ret z
        ret c
        ld d,a                  ; the part the wall stopped
        ld iy,(opp)
        ld a,(iy+F_Y)
        or a
        ret nz
        ld a,d
        bit 0,(ix+F_FACE)
        jr z,$+4
        neg
        push ix
        push iy
        pop ix
        call move_x
        pop ix
        ret

; ---- knocked down: fall, lie, get up (invulnerable all the way)
st_kd:
        ld (ix+F_INV),1
        ld a,(ix+F_KDP)
        or a
        jr nz,.lie
        ld (ix+F_FRM),FR_HIT
        ld a,-6
        call move_fwd
        ld a,(ix+F_Y)
        sub 3
        jr nc,$+3
        xor a
        ld (ix+F_Y),a
        ret nz
        ld (ix+F_KDP),1
        ld (ix+F_STUN),12
        ld (ix+F_FRM),FR_DOWN
        ld hl,sfx_thud
        jp play_sfx
.lie:   cp 2
        jr nc,.rise
        ld (ix+F_FRM),FR_DOWN
        dec (ix+F_STUN)
        ret nz
        ld (ix+F_KDP),2
        ld (ix+F_STUN),4
        ret
.rise:  ld (ix+F_FRM),FR_CROUCH
        dec (ix+F_STUN)
        ret nz
        jp to_free

st_ko:
        ld (ix+F_INV),1
        ld a,(ix+F_Y)
        or a
        jr z,.down
        ld (ix+F_FRM),FR_HIT
        ld a,-6
        call move_fwd
        ld a,(ix+F_Y)
        sub 2
        jr nc,$+3
        xor a
        ld (ix+F_Y),a
        ret
.down:  ld (ix+F_FRM),FR_DOWN
        ret

; ---------------------------------------------------------------------------
; active: NZ if IX's attack can hit this tick; IY = its move record
; ---------------------------------------------------------------------------
active:
        ld a,(ix+F_HITF)
        or a
        jr nz,.no
        ld a,(ix+F_ST)
        cp ST_ATK
        jr z,.gnd
        cp ST_JUMP
        jr nz,.no
        ld a,(ix+F_AIR)
        or a
        jr z,.no
        call move_ptr
        ld a,(ix+F_AT)
        dec a                   ; F_AT has already moved on this tick
        jr .ph
.gnd:   call move_ptr
        ld a,(ix+F_T)
.ph:    sub (iy+M_SU)
        jr c,.no
        cp (iy+M_AC)
        jr nc,.no
        or 1
        ret
.no:    xor a
        ret

; ---------------------------------------------------------------------------
; check_hit: IX attacks IY (fighter records).  Resolves hit or block.
; ---------------------------------------------------------------------------
check_hit:
        ld (defender),iy
        call active
        ret z
        ld a,(iy+M_FX)          ; thrown things hit on their own
        and 3
        cp 3
        ret z
        ld (mvrec),iy
        ld iy,(defender)
        call hit_ok
        ret nz
        ; attacker's hitbox in pixels + 64
        call x64                ; A = attacker x + 64
        ld b,a
        ld iy,(mvrec)
        ld c,(iy+M_X0)
        ld d,(iy+M_X1)
        bit 0,(ix+F_FACE)
        jr nz,.hl
        ld a,b
        add a,c
        ld e,a                  ; lo
        ld a,b
        add a,d
        ld d,a                  ; hi
        jr .hy
.hl:    ld a,b
        sub d
        ld e,a
        ld a,b
        sub c
        ld d,a
.hy:    ld (hb_lo),de           ; hb_lo = lo, hb_hi = hi
        ld a,(ix+F_Y)
        add a,(iy+M_Y0)
        ld (hb_y0),a
        ld a,(ix+F_Y)
        add a,(iy+M_Y1)
        ld (hb_y1),a
; hit_resolve: IX = attacker, (defender), (mvrec) and the hit box set
hit_resolve:
        ; defender's hurtbox
        push ix
        ld ix,(defender)
        call hurtbox            ; -> hu_lo, hu_hi, hu_y0, hu_y1
        pop ix
        ; overlap?
        ld a,(hb_lo)
        ld hl,hu_hi
        cp (hl)
        ret nc                  ; lo > hurt hi (allow equal? lo >= hi+... fine)
        ld a,(hb_hi)
        ld hl,hu_lo
        cp (hl)
        ret c
        ld a,(hb_y0)
        ld hl,hu_y1
        cp (hl)
        ret nc
        ld a,(hb_y1)
        ld hl,hu_y0
        cp (hl)
        ret c
        ; contact point for the spark
        ld a,(hb_lo)
        ld hl,hu_lo
        cp (hl)
        jr nc,$+3
        ld a,(hl)
        ld b,a                  ; max lo
        ld a,(hb_hi)
        ld hl,hu_hi
        cp (hl)
        jr c,$+3
        ld a,(hl)               ; min hi
        add a,b
        rra
        sub 64
        ld (spark_x),a
        ld a,(hb_y0)
        ld hl,hu_y0
        cp (hl)
        jr nc,$+3
        ld a,(hl)
        ld b,a
        ld a,(hb_y1)
        ld hl,hu_y1
        cp (hl)
        jr c,$+3
        ld a,(hl)
        add a,b
        rra
        ld b,a
        ld a,GROUND
        sub b
        ld (spark_row),a
        ; ---- blocked?
        ld a,1
        ld (hit_res),a
        ld iy,(defender)
        ld a,(iy+F_ST)
        cp ST_STAND
        jr z,.cb
        cp ST_CROUCH
        jr z,.cb
        cp ST_BSTUN
        jr nz,.hit
.cb:    push ix
        push iy
        pop ix
        call get_rel            ; defender's held directions (facing may lag)
        pop ix
        ld iy,(defender)
        ; must hold away from the attacker
        call away_held
        jr z,.hit
        ld iy,(mvrec)
        ld a,(iy+M_FL)
        and 3
        ld c,a
        ld iy,(defender)
        ld a,(iy+F_PAD)
        and 2                   ; down held = crouch block
        ld b,a
        ld a,c
        cp MF_LOW
        jr nz,.nl
        ld a,b
        or a
        jr z,.hit               ; low: needs a crouching block
        jr .block
.nl:    cp MF_HIGH
        jr nz,.block
        ld a,b
        or a
        jr nz,.hit              ; overhead: needs a standing block
.block: ld (iy+F_CRCH),b
        ld a,ST_BSTUN
        ld (iy+F_ST),a
        ld (iy+F_T),0
        ld iy,(mvrec)
        ld a,(iy+M_BS)
        ld c,(iy+M_FL)
        ld iy,(defender)
        ld (iy+F_STUN),a
        call push_amt
        ld (iy+F_PUSH),a
        ld (iy+F_Y),0
        ; chip damage from signature moves, never the last of it
        bit 3,c
        jr z,.nochip
        ld a,(iy+F_HP)
        cp 3
        jr c,.nochip
        sub 2
        ld (iy+F_HP),a
.nochip:
        ld (ix+F_HITF),2
        call face_attacker
        ld a,2
        ld (hitstop),a
        ld a,2
        ld (spark_t),a
        ld a,1
        ld (spark_blk),a
        ld hl,sfx_block
        jp play_sfx
        ; ---- hit
.hit:   ld (ix+F_HITF),1
        ld iy,(mvrec)
        ld a,(iy+M_DMG)
        ld c,(iy+M_FL)
        ld b,(iy+M_HS)
        ld iy,(defender)
        ld e,a
        ld a,(iy+F_HP)
        sub e
        jr nc,$+3
        xor a
        ld (iy+F_HP),a
        ld (iy+F_AIR),0
        call face_attacker
        call push_amt
        ld (iy+F_PUSH),a
        ld a,(iy+F_HP)
        or a
        jr nz,.alive
        ; knocked out (or left dizzy for the finisher)
        call ko_or_dizzy
        jr .sfx
.alive: bit 2,c
        jr nz,.kd
        ld a,(iy+F_Y)
        or a
        jr nz,.kd               ; hit in the air: knocked down
        ld a,ST_HSTUN
        ld (iy+F_ST),a
        ld (iy+F_T),0
        ld (iy+F_STUN),b
        jr .sfx
.kd:    ld a,ST_KD
        ld (iy+F_ST),a
        ld (iy+F_T),0
        ld (iy+F_KDP),0
        ld a,(iy+F_Y)
        add a,6
        ld (iy+F_Y),a
.sfx:   ld a,1
        ld (hud_dirty),a
        ld a,3
        bit 4,c
        jr z,$+4
        ld a,2
        ld (hitstop),a
        ld a,3
        ld (spark_t),a
        xor a
        ld (spark_blk),a
        ld hl,sfx_hit_hvy
        bit 4,c
        jr z,$+5
        ld hl,sfx_hit_lt
        jp play_sfx

; push_amt: C = move flags -> A = pushback (quarter pixels)
push_amt:
        ld a,32
        bit 4,c
        ret z
        ld a,16
        ret

; face_attacker: the defender (IY) turns to face IX if on the ground
face_attacker:
        ld a,(iy+F_Y)
        or a
        ret nz
        ld l,(ix+F_XL)
        ld h,(ix+F_XH)
        ld e,(iy+F_XL)
        ld d,(iy+F_XH)
        or a
        sbc hl,de               ; attacker - defender
        ret z
        ld a,0
        jr nc,$+4
        ld a,1
        ld (iy+F_FACE),a
        ret

; away_held: NZ if the defender (IY) holds the direction away from IX
away_held:
        ld l,(ix+F_XL)
        ld h,(ix+F_XH)
        ld e,(iy+F_XL)
        ld d,(iy+F_XH)
        or a
        sbc hl,de
        ld a,(iy+F_PAD)
        jr c,.left
        ; attacker to the right: away = left
        and 4
        ret
.left:  and 8
        ret

; x64: A = (ix) x on the screen + 64 (hit boxes are worked out on screen)
x64:
        call scr_x
        ld a,l
        add a,64
        ret

; hurtbox: IX = defender -> hu_lo/hu_hi (pixels + 64), hu_y0/hu_y1
hurtbox:
        call x64
        ld b,a
        sub 6
        ld (hu_lo),a
        ld a,b
        add a,6
        ld (hu_hi),a
        ; standing height by default
        ld a,D_HURTH
        call def_byte
        ld c,a
        ld b,0
        ld a,(ix+F_ST)
        cp ST_CROUCH
        jr z,.cr
        cp ST_BSTUN
        jr nz,.n1
        ld a,(ix+F_CRCH)
        or a
        jr nz,.cr
        jr .ext
.n1:    cp ST_LAND
        jr z,.cr
        cp ST_PREJ
        jr z,.cr
        cp ST_JUMP
        jr z,.air
        cp ST_ATK
        jr nz,.ext
        call move_ptr
        bit 7,(iy+M_FX)
        jr nz,.cr
        ld a,(ix+F_Y)
        or a
        jr nz,.air
        jr .ext
.cr:    ld c,19
        jr .ext
.air:   ld a,(ix+F_Y)
        add a,2
        ld b,a
        add a,24
        ld c,a
.ext:   ld a,b
        ld (hu_y0),a
        ld a,c
        ld (hu_y1),a
        ; an attack in progress puts the limb out where it can be hit
        ld a,(ix+F_ST)
        cp ST_ATK
        ret nz
        call move_ptr
        ld a,(ix+F_T)
        cp (iy+M_SU)
        ret c
        ld a,(iy+M_X1)
        sub 4
        cp 34
        jr c,$+4
        ld a,14
        bit 0,(ix+F_FACE)
        jr nz,.el
        ld c,a
        call x64
        add a,c
        ld hl,hu_hi
        cp (hl)
        ret c
        ld (hl),a
        ret
.el:    ld c,a
        call x64
        sub c
        ld hl,hu_lo
        cp (hl)
        ret nc
        ld (hl),a
        ret

; ---------------------------------------------------------------------------
; separate: keep the bodies apart on the ground; face each other
; ---------------------------------------------------------------------------
separate:
        ld a,(p1+F_Y)
        cp 12
        jr nc,.face
        ld a,(p2+F_Y)
        cp 12
        jr nc,.face
        ld hl,(p1+F_XL)
        ld de,(p2+F_XL)
        ld ix,p1
        ld iy,p2
        or a
        sbc hl,de
        jr c,.ord               ; p1 left of p2
        jr nz,.swap
        ld a,(p1+F_FACE)        ; same spot: p1's facing decides
        or a
        jr z,.ord
.swap:  ld ix,p2
        ld iy,p1
.ord:   ; IX = left fighter, IY = right fighter
        ld l,(iy+F_XL)
        ld h,(iy+F_XH)
        ld e,(ix+F_XL)
        ld d,(ix+F_XH)
        or a
        sbc hl,de               ; gap
        ld de,MINSEP
        or a
        sbc hl,de
        jr nc,.face
        ; overlap = -hl ; left goes left by half
        ld a,l
        neg
        ld c,a
        srl a
        ld b,a
        ld a,b
        neg
        push bc
        call move_x
        pop bc
        ld l,(ix+F_XL)
        ld h,(ix+F_XH)
        ld de,MINSEP
        add hl,de
        push ix
        push iy
        pop ix
        call set_x
        pop ix
        ; if the right one hit the wall, the left one moves back
        ld l,(iy+F_XL)
        ld h,(iy+F_XH)
        ld de,MINSEP
        or a
        sbc hl,de
        call set_x
.face:  ld ix,p1
        ld iy,p2
        call face_opp
        ld ix,p2
        ld iy,p1
        jp face_opp

; face_opp: IX turns to face IY when on the ground and free
face_opp:
        ld a,(ix+F_ST)
        cp ST_STAND
        jr z,.ok
        cp ST_CROUCH
        jr z,.ok
        cp ST_LAND
        jr z,.ok
        cp ST_FROZEN
        ret nz
.ok:    ld l,(ix+F_XL)
        ld h,(ix+F_XH)
        ld e,(iy+F_XL)
        ld d,(iy+F_XH)
        or a
        sbc hl,de
        ret z
        ld a,1
        jr nc,$+3
        xor a
        ld (ix+F_FACE),a
        ret

; ---------------------------------------------------------------------------
; game_logic: one tick of both fighters
; ---------------------------------------------------------------------------
game_logic:
        ld ix,p1
        call fighter_input
        ld ix,p2
        call fighter_input
        ld a,(hitstop)
        or a
        jr z,.run
        dec a
        ld (hitstop),a
        ret
.run:   ld ix,p1
        ld iy,p2
        call update_fighter
        ld ix,p2
        ld iy,p1
        call update_fighter
        xor a
        ld (p1+F_PRS),a
        ld (p2+F_PRS),a
        ld ix,p1
        ld iy,p2
        call check_hit
        ld ix,p2
        ld iy,p1
        call check_hit
        ld ix,p1
        ld de,p2
        ld iy,pr1
        call proj_update
        ld ix,p2
        ld de,p1
        ld iy,pr2
        call proj_update
        call fin_tick
        call separate
        jp cam_update


; ===========================================================================
;  TAUNTS, FINISHERS AND THINGS IN FLIGHT
; ===========================================================================
FIN_TIME equ 80             ; ticks the loser stays dizzy

; ---- taunt: UP + A+B.  Leaves you open for most of a second.
start_taunt:
        ld a,ST_TAUNT
        call set_state
        ld (ix+F_TA),$7F
        ld (ix+F_TB),$7F
        ld (ix+F_FRM),FR_TAUNT
        ld hl,sfx_taunt
        jp play_sfx
st_taunt:
        ld (ix+F_INV),0
        ld a,(ix+F_T)
        cp 20
        jp nc,to_free
        cp 8
        jr c,.t
        cp 12
        jr nc,.t
        ld (ix+F_FRM),FR_IDLE2
        ret
.t:     ld (ix+F_FRM),FR_TAUNT
        ret

; ---- dizzy: beaten in the deciding round, waiting for the finisher
st_dizzy:
        ld (ix+F_INV),0
        ld a,(ix+F_T)
        and 8
        ld a,FR_HIT
        jr z,$+4
        ld a,FR_IDLE2
        ld (ix+F_FRM),a
        ret

; seq_track: follow the stick through this fighter's two finisher directions
; (F_SEQ: 0 nothing, 1 first held, 2 first let go, 3 second held = armed)
seq_track:
        ld a,(ix+F_SEQT)
        or a
        jr z,.t0
        dec (ix+F_SEQT)
        jr nz,.t0
        ld (ix+F_SEQ),0
.t0:    ld a,D_FIN1
        call def_byte
        ld b,a
        ld a,D_FIN2
        call def_byte
        ld c,a
        ld d,(ix+F_REL)
        ld a,(ix+F_SEQ)
        or a
        jr z,.s0
        dec a
        jr z,.s1
        dec a
        ret nz
        ld a,d
        and c
        ret z
        jr .adv
.s0:    ld a,d
        and b
        ret z
        jr .adv
.s1:    ld a,d
        and b
        ret nz
.adv:   inc (ix+F_SEQ)
        ld (ix+F_SEQT),30
        ret

; start_fin: IX = the winner, opponent dizzy
start_fin:
        ld a,3
        ld (fin_on),a
        ld a,D_FINMV
        call def_byte
        ld (ix+F_MV),a
        ld a,ST_FIN
        call set_state
        ld (ix+F_TA),$7F
        ld (ix+F_TB),$7F
        ld (ix+F_SEQ),0
        ld hl,sfx_fin
        jp play_sfx
st_fin:
        call move_ptr
        ld a,(ix+F_T)
        cp 9
        jr nc,.s
        ld a,(iy+M_FW)
        ld (ix+F_FRM),a
        ret
.s:     jr nz,.s2
        ; it lands: the screen flashes and the loser is sent flying
        ld a,6
        ld (flash_t),a
        push iy
        ld iy,(opp)
        ld a,ST_FLY
        ld (iy+F_ST),a
        ld (iy+F_T),0
        ld (iy+F_INV),1
        ld a,D_FINVX
        call def_byte
        bit 0,(ix+F_FACE)
        jr z,$+4
        neg
        ld (iy+F_VX),a
        ld a,D_FINVY
        call def_byte
        ld (iy+F_VY),a
        pop iy
.s2:    ld a,(iy+M_FS)
        ld (ix+F_FRM),a
        ld a,(ix+F_T)
        cp 36
        ret c
        ld a,1
        ld (ko_flag),a
        ret
; the loser, in flight: spinning, up and away
st_fly:
        ld (ix+F_INV),1
        ld a,(ix+F_VX)
        call move_x
        ld a,(ix+F_Y)
        add a,(ix+F_VY)
        cp 110
        jr c,.ok
        ld (ix+F_HIDE),1
        ld a,ST_GONE
        jp set_state
.ok:    ld (ix+F_Y),a
        ld (ix+F_FRM),FR_HIT
        ld a,(ix+F_T)
        rrca
        and 1
        ld (ix+F_FACE),a
st_gone:
        ret

; fin_tick: count down the dizzy time; the CPU may finish; when time runs
; out the loser just drops
fin_tick:
        ld a,(fin_on)
        dec a
        ret nz
        ld hl,fin_t
        ld a,(hl)
        cp FIN_TIME-30
        jr nz,.t
        ld ix,(fin_who)
        ld a,(ix+F_CPU)
        or a
        jr z,.t
        ld a,(ix+F_ST)
        cp ST_PREJ
        jr nc,.t
        call random
        cp 190
        jp c,start_fin
.t:     ld hl,fin_t
        dec (hl)
        ret nz
        ld a,2
        ld (fin_on),a
        ld ix,p1
        ld a,(ix+F_ST)
        cp ST_DIZZY
        jr z,.d
        ld ix,p2
.d:     ld a,ST_KO
        call set_state
        ld a,1
        ld (ko_flag),a
        ret

; ko_or_dizzy: IY = fighter just beaten, IX = the one who did it.  The blow
; that wins the match leaves the loser dizzy for a finisher.
ko_or_dizzy:
        ld a,(fin_on)
        or a
        jr nz,.ko
        ld a,(ix+F_WINS)
        dec a
        jr nz,.ko
        ld a,(iy+F_Y)
        or a
        jr nz,.ko
        ld a,ST_DIZZY
        ld (iy+F_ST),a
        ld (iy+F_T),0
        ld (iy+F_PUSH),0
        ld a,1
        ld (fin_on),a
        ld a,FIN_TIME
        ld (fin_t),a
        ld (fin_who),ix
        ld (ix+F_SEQ),0
        ret
.ko:    ld a,ST_KO
        ld (iy+F_ST),a
        ld (iy+F_T),0
        ld a,(iy+F_Y)
        add a,8
        ld (iy+F_Y),a
        ld a,1
        ld (ko_flag),a
        ld a,(fin_on)
        or a
        ret z
        ld a,2
        ld (fin_on),a
        ret

; hit_ok: IY = defender -> Z if it can be hit now
hit_ok:
        ld a,(iy+F_INV)
        or a
        ret nz
        ld a,(iy+F_ST)
        cp ST_KD
        jr z,.no
        cp ST_KO
        jr z,.no
        cp ST_FLY
        jr z,.no
        cp ST_GONE
        jr z,.no
        xor a
        ret
.no:    or 1
        ret

; ---- things in flight (one per fighter)
PR_ON   equ 0
PR_XL   equ 1
PR_XH   equ 2
PR_Y    equ 3
PR_VX   equ 4
PR_MVL  equ 5
PR_MVH  equ 6
PR_T    equ 7
PR_KIND equ 8

; my_proj: IX = fighter -> HL = its projectile record
my_proj:
        push de
        push ix
        pop hl
        ld de,p1
        or a
        sbc hl,de
        ld hl,pr1
        jr z,$+5
        ld hl,pr2
        pop de
        ret

; proj_spawn: IX = thrower, IY = the move.  Nothing happens if this
; fighter's last one is still in flight.
proj_spawn:
        push bc
        call my_proj
        ld a,(hl)
        or a
        jr nz,.x
        ld (hl),1
        inc hl
        push hl
        ld a,(iy+M_X0)
        add a,a
        add a,a
        ld e,a
        ld d,0
        bit 0,(ix+F_FACE)
        jr z,.r
        neg
        ld e,a
        ld d,$FF
.r:     ld l,(ix+F_XL)
        ld h,(ix+F_XH)
        add hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(iy+M_Y0)
        add a,(iy+M_Y1)
        rra
        ld (hl),a
        inc hl
        ld a,(iy+M_VX)
        bit 0,(ix+F_FACE)
        jr z,$+4
        neg
        ld (hl),a
        inc hl
        push iy
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),0
        inc hl
        ld a,(iy+M_FX)
        rrca
        rrca
        and 3
        ld (hl),a
        ld hl,sfx_shot
        call play_sfx
.x:     pop bc
        ret

; proj_update: IX = owner, DE = the opponent, IY = the owner's projectile
proj_update:
        ld a,(iy+PR_ON)
        or a
        ret z
        ld (defender),de
        inc (iy+PR_T)
        ld a,(iy+PR_VX)
        ld e,a
        ld d,0
        bit 7,a
        jr z,$+3
        dec d
        ld l,(iy+PR_XL)
        ld h,(iy+PR_XH)
        add hl,de
        ld (iy+PR_XL),l
        ld (iy+PR_XH),h
        ; where on the screen?
        srl h
        rr l
        srl h
        rr l
        ld a,(cam)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.off
        ld a,l
        cp 128
        jr nc,.off
        add a,64
        ld b,a                  ; centre + 64
        ld l,(iy+PR_MVL)
        ld h,(iy+PR_MVH)
        ld (mvrec),hl
        ld de,M_X1
        add hl,de
        ld c,(hl)               ; half width
        inc hl
        ld a,(hl)
        ld (hb_y0),a
        inc hl
        ld a,(hl)
        ld (hb_y1),a
        ld a,b
        sub c
        ld (hb_lo),a
        ld a,b
        add a,c
        ld (hb_hi),a
        push iy
        ld iy,(defender)
        call hit_ok
        jr nz,.miss
        xor a
        ld (hit_res),a
        ld a,(ix+F_HITF)
        push af
        call hit_resolve
        pop af
        ld (ix+F_HITF),a
        pop iy
        ld a,(hit_res)
        or a
        ret z
.off:   ld (iy+PR_ON),0
        ret
.miss:  pop iy
        ret
