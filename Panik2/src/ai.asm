; =====================================================================
;  PANIK 2 - computer player (attract-mode demo, and the soak test)
;  Fills inp / inpnew like the real controls.
; =====================================================================
AI_R    equ 1
AI_L    equ 2
AI_U    equ 4
AI_D    equ 8
AI_F    equ 16

ai_think:
        call .decide
        ; fire only as fresh presses (every other frame)
        ld a,(aiprev)
        and AI_F
        jr z,.f
        ld a,c
        and ~AI_F
        ld c,a
.f:     ld a,(aiprev)
        cpl
        and c
        ld (inpnew),a
        ld a,c
        ld (inp),a
        ld (aiprev),a
        ret

.decide:
        ld c,0
        ld a,(pst)
        cp PS_DIG
        ret z
        cp PS_CLIMB
        jr nz,.walk
        ld a,(aiclimb)
        ld c,a
        ret
.walk:  ld a,(lv_kind)
        or a
        jp nz,ai_gems
        ; 1: a trapped alien on my floor -> bash it
        ld ix,aliens
        ld b,NAL
.t:     ld a,(ix+AL_ST)
        cp AS_TRAP
        jr nz,.tn
        ld a,(pfl)
        cp (ix+AL_FL)
        jr nz,.tn
        ld a,(ix+AL_X)
        jp ai_work_at
.tn:    ld de,16
        add ix,de
        djnz .t
        ; 2: nearest walking alien on my floor
        ld a,$FF
        ld (tmpd),a             ; best distance
        ld ix,aliens
        ld b,NAL
        ld hl,0
.w:     ld a,(ix+AL_ST)
        cp AS_WALK
        jr nz,.wn
        ld a,(pfl)
        cp (ix+AL_FL)
        jr nz,.wn
        ld a,(px)
        sub (ix+AL_X)
        jr nc,.wa
        neg
.wa:    ld e,a
        ld a,(tmpd)
        cp e
        jr c,.wn
        ld a,e
        ld (tmpd),a
        push ix
        pop hl
.wn:    ld de,16
        add ix,de
        djnz .w
        ld a,h
        or l
        jr z,.hunt
        push hl
        pop ix
        ld a,(tmpd)
        cp 7
        jr c,.flee
        cp 48
        jr nc,.near
        ; face it and dig the slot between us
        ld a,(ix+AL_X)
        ld b,a
        ld a,(px)
        cp b
        ld e,0                  ; want right
        jr c,.fd
        ld e,1
.fd:    ld a,(pdir)
        cp e
        jr z,.facing
        ld a,e
        or a
        ld c,AI_R
        ret z
        ld c,AI_L
        ret
.facing:
        ld a,(pfl)
        cp 4
        jr c,.dg
        ld a,3                  ; bedrock can't be dug: go up a floor
        jp ai_route
.dg:    call front_slot
        cp $FF
        jr z,.near
        ld c,a
        ld a,(pfl)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,c
        ld l,a
        ld h,HOLES/256
        ld a,(hl)
        cp 3
        ld c,0
        ret nc                  ; open: wait for it
        ld c,AI_F
        ret
.flee:  ld a,(ix+AL_X)
        ld b,a
        ld a,(px)
        cp b
        ld c,AI_L
        ret c
        ld c,AI_R
        ret
.near:  ld a,(ix+AL_X)
        jp ai_goto
.hunt:  ; 3: go to the floor of the first alien about
        ld ix,aliens
        ld b,NAL
.h:     ld a,(ix+AL_ST)
        cp AS_WALK
        jr z,.hf
        cp AS_TRAP
        jr z,.hf
        ld de,16
        add ix,de
        djnz .h
        ; nobody: wander to the middle of the bottom
        ld a,4
        jr ai_route
.hf:    ld a,(ix+AL_FL)
        cp 5
        jr c,ai_route
        ld a,4

; ai_route: A = target floor -> head for a ladder towards it
ai_route:
        ld b,a
        ld a,(pfl)
        cp b
        jr nz,.go
        ld a,64
        jp ai_goto
.go:    ld e,AI_D
        ld d,a                  ; k = pfl (down)
        jr c,.k
        dec d                   ; k = pfl-1 (up)
        ld e,AI_U
.k:     ld a,e
        ld (aiclimb),a
        ; nearest ladder in row D
        ld a,d
        add a,a
        add a,a
        add a,a
        add a,a
        add a,LAD&255
        ld l,a
        ld h,LAD/256
        ld a,$FF
        ld (tmpd),a
        ld b,0
.s:     ld a,(hl)
        or a
        jr z,.sn
        ld a,b
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,(px)
        sub c
        jr nc,.ab
        neg
.ab:    push hl
        ld hl,tmpd
        cp (hl)
        jr nc,.sk
        ld (hl),a
        ld a,c
        ld (aitx),a
.sk:    pop hl
.sn:    inc l
        inc b
        ld a,b
        cp 16
        jr nz,.s
        ld a,(aitx)
        ld b,a
        ld a,(px)
        cp b
        jr nz,ai_goto_b
        ld a,(aiclimb)
        ld c,a
        ret

; ai_goto: A = x -> C = direction
ai_goto:
        ld b,a
        ld a,(px)
ai_goto_b:
        cp b
        ld c,0
        ret z
        ld c,AI_L
        ret nc
        ld c,AI_R
        ret

; stand next to x (A) facing it, then fire.  Any spot within 3 px of the
; ideal one digs/bashes the same slot (turning round moves the digger 1 px,
; so an exact-spot test would make it shuffle back and forth for ever)
ai_work_at:
        ld b,a
        ld a,(px)
        cp b
        jr nc,.right
        ; we're left of it: stand near x-8 facing right
        ld a,b
        sub 8
        ld b,a
        call ai_near
        jr nc,ai_goto_b0
        ld a,(pdir)
        or a
        ld c,AI_R
        ret nz
        ld c,AI_F
        ret
.right: ld a,b
        add a,8
        ld b,a
        call ai_near
        jr nc,ai_goto_b0
        ld a,(pdir)
        or a
        ld c,AI_L
        ret z
        ld c,AI_F
        ret
ai_goto_b0:
        ld a,(px)
        jp ai_goto_b
; ai_near: B = target x -> carry if |px - B| <= 3
ai_near:
        ld a,(px)
        sub b
        jr nc,.p
        neg
.p:     cp 4
        ret

; gem dig: the nearest buried gem on this floor, else another floor's
ai_gems:
        ld a,(pfl)
        cp 4
        jr nc,.other
        add a,a
        add a,a
        add a,a
        add a,a
        add a,FLT&255
        ld l,a
        ld h,FLT/256
        ld b,0
        ld a,$FF
        ld (tmpd),a
.s:     ld a,(hl)
        cp 2
        jr nz,.sn
        ld a,b
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,(px)
        sub c
        jr nc,.ab
        neg
.ab:    push hl
        ld hl,tmpd
        cp (hl)
        jr nc,.sk
        ld (hl),a
        ld a,c
        ld (aitx),a
.sk:    pop hl
.sn:    inc l
        inc b
        ld a,b
        cp 16
        jr nz,.s
        ld a,(tmpd)
        cp $FF
        jr z,.other
        ld a,(aitx)
        jp ai_work_at
.other: ld hl,FLT
        ld b,0
.o:     ld a,(hl)
        cp 2
        jr z,.of
        inc hl
        inc b
        ld a,b
        cp 64
        jr nz,.o
        ld a,4
        jp ai_route
.of:    ld a,b
        rrca
        rrca
        rrca
        rrca
        and 3
        jp ai_route
