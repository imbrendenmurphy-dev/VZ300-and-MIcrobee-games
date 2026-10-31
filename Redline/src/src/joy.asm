; =====================================================================
;  joy.asm - keyboard + both VZ joysticks interchangeably.  The port map
;  is the one from the Cybernoid conversion v1.7 (fire $2E/$2B, arm
;  $2D/$27, directions $2C (J1) and $29 (J2)), confirmed on this machine.
; =====================================================================
; joy_read -> A: bit0 up 1 down 2 left 3 right 4 fire ; (joyarm) = ARM
joy_read:
        ld a,(joyok)
        or a
        jr nz,.go
        xor a
        ld (joyarm),a
        ret
.go:    push bc
        push de
        push hl
        ld hl,JMAP
        ld e,12
        ld d,0
.jm:    ld c,(hl)
        inc hl
        ld b,0
        in a,(c)
        and (hl)
        inc hl
        jr nz,.js
        ld a,d
        or (hl)
        ld d,a
.js:    inc hl
        dec e
        jr nz,.jm
        ld a,d
        and $20
        ld (joyarm),a
        ld a,d
        and $1F
        pop hl
        pop de
        pop bc
        ret
; (port, active-low mask, result bit): up 1, down 2, left 4, right 8, fire 16, arm 32
JMAP:   db $2C,$01,$01, $2C,$02,$02, $2C,$04,$04, $2C,$08,$08, $2E,$10,$10, $2D,$10,$20
        db $29,$01,$01, $29,$02,$02, $29,$04,$04, $29,$08,$08, $2B,$10,$10, $27,$10,$20

joy_detect:
        ld b,8
        ld c,$FF
.l:     in a,($2E)
        and c
        ld c,a
        in a,($2D)
        and c
        ld c,a
        djnz .l
        ld a,c
        and $1F
        cp $1F
        ld a,1
        jr z,.ok
        xor a
.ok:    ld (joyok),a
        ret
