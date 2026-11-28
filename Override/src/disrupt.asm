; =====================================================================
;  disrupt.asm - the disruptor (play-only code, CODE2). It fires no shot:
;  it hits everything in sight at once, except disruptor-proof bodies.
;  In: C = owner (0 you, 1 a droid). Yours hits every hostile droid on
;  screen; a droid's hits you (it only fires when it can see you).
; =====================================================================
disrupt:
            ld a,c
            or a
            jr nz,.theirs
            ld hl,(plr+O_XL)        ; the discharge, at your body
            ld a,(plr+O_Y)
            call fx_spark
            push ix
            ld ix,droids
            ld b,MAXDROIDS
.l:         push bc
            bit 7,(ix+O_FLAGS)
            jr z,.n
            ; on screen: within 68 px across and 30 rows up or down of you
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld de,(plr+O_XL)
            or a
            sbc hl,de
            call abs_hl
            ld a,h
            or a
            jr nz,.n
            ld a,l
            cp 68
            jr nc,.n
            ld a,(ix+O_Y)
            ld hl,plr+O_Y
            sub (hl)
            jr nc,.p
            neg
.p:         cp 30
            jr nc,.n
            ld a,(ix+O_TYPE)
            call dis_proof
            jr nz,.n
            ld l,(ix+O_XL)
            ld h,(ix+O_XH)
            ld a,(ix+O_Y)
            call fx_spark
            ld a,DIS_DAMAGE
            call droid_hurt
.n:         ld de,OSZ
            add ix,de
            pop bc
            djnz .l
            pop ix
            ld a,SFX_LINK
            jp sfx
.theirs:    ld a,(plr+O_TYPE)       ; your body may shrug it off
            call dis_proof
            ret nz
            ld hl,(plr+O_XL)
            ld a,(plr+O_Y)
            call fx_spark
            ld a,SFX_LINK
            call sfx
            ld a,DIS_DAMAGE
            jp player_hurt

; A = type: NZ if disruptor-proof
dis_proof:
            call type_ptr
            ld de,T_FLAGS
            add hl,de
            bit 0,(hl)
            ret
