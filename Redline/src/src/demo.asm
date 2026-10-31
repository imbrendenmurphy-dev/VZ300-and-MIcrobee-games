; =====================================================================
;  demo.asm - autopilot for the attract demo and the benchmark:
;  steers for the inside of the coming bend, brakes for sharp ones
; =====================================================================
demo_input:
        ; look ~6 segments ahead: sum of curves gives the bend
        ld hl,(pos_s)
        ld de,TRK_CURV+2
        add hl,de
        ld b,6
        ld de,0
.s:     ld a,(hl)
        push hl
        ld l,a
        add a,a
        sbc a,a
        ld h,a
        add hl,de
        ex de,hl
        pop hl
        inc hl
        djnz .s
        ; target x = bend / 2 towards the inside, clamped to +-120
        ex de,hl
        ld (dm_bend),hl
        sra h
        rr l
        ld de,120
        bit 7,h
        jr nz,.ng
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.tg
        ex de,hl
        jr .tg
.ng:    push hl
        add hl,de
        pop hl
        jr c,.tg
        ld hl,-120
.tg:
        ld de,(camx)
        or a
        sbc hl,de               ; target - x
        ld c,K_ACC
        ld a,h
        bit 7,a
        jr nz,.lt
        or a
        jr nz,.rt
        ld a,l
        cp 24
        jr c,.br
.rt:    set 1,c
        jr .br
.lt:    inc a
        jr nz,.lft
        ld a,l
        cp -24
        jr nc,.br
.lft:   set 0,c
.br:    ; sharp bend at speed: lift / brake
        ld hl,(dm_bend)
        bit 7,h
        jr z,.p
        NEGHL
.p:     ld de,140
        or a
        sbc hl,de
        ret c                   ; gentle: full throttle
        ld a,(speed+1)
        cp 205*64/256
        ret c
        res 2,c                 ; lift
        ld de,80
        or a
        sbc hl,de
        ret c
        ld a,(speed+1)
        cp 165*64/256
        ret c
        set 3,c                 ; and brake for the sharp ones
        ret
dm_bend: dw 0
