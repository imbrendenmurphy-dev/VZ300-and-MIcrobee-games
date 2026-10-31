; =====================================================================
;  input.asm : keyboard + both VZ joysticks (custom interface map from
;  the Cybernoid port: directions via $2C / $29, FIRE $2E/$2B, ARM $2D/$27)
;  read_input -> A (and in_now): b0 R b1 D b2 L b3 U b4 FIRE b5 MAGIC b6 MAP b7 INV
;  in_new = bits newly pressed this frame
; =====================================================================
in_now:  db 0
in_last: db 0
in_new:  db 0
joy_ok:  db 0

KEYBIT  MACRO addr, bitn, res
        ld a,(addr)
        bit bitn,a
        jr nz,$+4
        set res,c
        ENDM

read_input:
        ld a,(demo_on)
        or a
        jp nz,demo_input
        ld c,0
        KEYBIT KR6,4,IN_R       ; P
        KEYBIT KR6,1,IN_L       ; O
        KEYBIT KR0,4,IN_U       ; Q
        KEYBIT KR1,4,IN_D       ; A
        KEYBIT KR4,4,IN_FIRE    ; SPACE
        KEYBIT KR4,5,IN_MAG     ; M
        KEYBIT KR6,2,IN_MAP     ; RETURN
        KEYBIT KR6,3,IN_INV     ; I
        ; cursor-style alternates: , . for left/right? (VZ arrows need CTRL) - use W S as well
        KEYBIT KR0,1,IN_U       ; W
        KEYBIT KR1,1,IN_D       ; S
        KEYBIT KR1,3,IN_R       ; D
        ld a,(joy_ok)
        or a
        jr z,.nojoy
        ld hl,JMAP
        ld e,12
.jm:    ld a,(hl)
        inc hl
        push bc
        ld c,a
        in a,(c)
        pop bc
        and (hl)
        inc hl
        jr nz,.js
        ld a,c
        or (hl)
        ld c,a
.js:    inc hl
        dec e
        jr nz,.jm
.nojoy:
        IFDEF DEMOREC
        ld a,(rec_on)
        or a
        call nz,rec_input
        ENDIF
ri_store:
        ld a,(in_now)
        ld (in_last),a
        cpl
        and c
        ld (in_new),a
        ld a,c
        ld (in_now),a
        ret

; joystick map: port, active-low mask, result bits
JMAP:   db $2C,$01,1<<IN_U, $2C,$02,1<<IN_D, $2C,$04,1<<IN_L, $2C,$08,1<<IN_R, $2E,$10,1<<IN_FIRE, $2D,$10,1<<IN_MAG
        db $29,$01,1<<IN_U, $29,$02,1<<IN_D, $29,$04,1<<IN_L, $29,$08,1<<IN_R, $2B,$10,1<<IN_FIRE, $27,$10,1<<IN_MAG

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
.ok:    ld (joy_ok),a
        ret

; any key or button held? -> NZ
any_input:
        call read_input
        or a
        ret nz
        ld hl,$68FE
        ld b,8
.k:     ld a,(hl)
        and $3F
        cp $3F
        ret nz
        rlc l
        djnz .k
        xor a
        ret

; wait until nothing held, then until something pressed (plays sound)
wait_key:
.r:     call wait_frame
        call sound_tick
        call any_input
        jr nz,.r
.p:     call wait_frame
        call sound_tick
        call any_input
        jr z,.p
        ret
