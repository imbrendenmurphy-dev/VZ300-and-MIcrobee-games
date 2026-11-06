; reference harness: the VZ300 original's rules alone
        DEVICE NOSLOT64K
        INCLUDE "equ.asm"
        INCLUDE "vars.asm"
        ORG $8000
ref_loop:
        call game_tick
        call demo_tick
ref_tick:
        jr ref_loop
int_poll: ret
sfx_play: ret
SFX_LETSGO  equ 1
SFX_ASSIGN  equ 2
SFX_CLICK   equ 3
SFX_DIG     equ 4
SFX_CLINK   equ 5
SFX_TINK    equ 6
SFX_SPLAT   equ 7
SFX_SPLASH  equ 8
SFX_HOME    equ 9
SFX_OHNO    equ 10
SFX_BOOM    equ 11
rand:
        push hl
        ld hl,(v_seed)
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
        ld (v_seed),hl
        ld a,l
        xor h
        pop hl
        ret

        INCLUDE "game.asm"
; Z if creature IX can take skill A (0..7)
can_take:
        ld c,a
        add a,a
        ld l,a
        ld h,0
        ld de,SKMASK
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = states allowed
        ld a,(ix+C_ST)
        or a
        jr z,.no
.sh:    srl d
        rr e
        dec a
        jr nz,.sh
        jr nc,.no
        ld a,c
        cp 3
        jr nc,.yes
        ; climber / floater / bomber: not twice
        inc a
        ld b,a
        ld a,(ix+C_FL)
.fb:    rrca
        djnz .fb
        jr c,.no
.yes:   xor a
        ret
.no:    or 1
        ret
; bit s = state s allowed (bit 0 = state 1 after the shift above)
SKMASK:
        ; states:      1W 2F 3Fl 4C 5H 6Bl 7Bu 8Sh 9Ba 10Mi 11Di
        dw %11111111111 ; climber: anything still on the go
        dw %11111111111 ; floater
        dw %11111111111 ; bomber
        dw %11111000001 ; blocker: walker, builder, shrugger, basher, miner, digger
        dw %11110000001 ; builder: walker, shrugger, basher, miner, digger
        dw %11011000001 ; basher
        dw %10111000001 ; miner
        dw %01111000001 ; digger

; give skill A to creature IX (it can take it); uses one up
apply_skill:
        ld c,a
        ld e,a
        ld d,0
        ld hl,v_skill
        add hl,de
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ld a,1
        ld (v_pdirty),a
        ld a,c
        or a
        jr nz,.a1
        set 0,(ix+C_FL)
        jr .snd
.a1:    dec a
        jr nz,.a2
        set 1,(ix+C_FL)
        jr .snd
.a2:    dec a
        jr nz,.a3
        set 2,(ix+C_FL)
        ld (ix+C_BT),BOMBTICKS
        jr .snd
.a3:    ld hl,SKST-3
        ld e,c
        ld d,0
        add hl,de
        ld a,(hl)
        ld (ix+C_ST),a
        ld (ix+C_AN),0
        ld (ix+C_CNT),0
.snd:   ld a,SFX_ASSIGN
        jp sfx_play
SKST:   db ST_BLOCK,ST_BUILD,ST_BASH,ST_MINE,ST_DIG

demo_start:                     ; HL = script
        ld (v_dptr),hl
        ld hl,v_dfired
        ld b,8
.c:     ld (hl),0
        inc hl
        djnz .c
        ret

; every event not done yet: (tick.w, creature, skill, x from, x to)
demo_tick:
        ld a,(v_demo)
        or a
        ret z
        ld hl,(v_dptr)
        ld c,0                  ; event number
.ev:    ld a,(hl)
        cp $FF
        ret z
        push hl
        push bc
        call .one
        pop bc
        pop hl
        ld de,8
        add hl,de
        inc c
        jr .ev
; HL = event, C = its number
.one:   push hl
        call .bit               ; fired already?
        pop hl
        ret nz
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(v_gtick)
        or a
        sbc hl,de
        pop hl
        ret c                   ; not yet
        ld a,(hl)               ; creature
        inc hl
        ld b,(hl)               ; skill
        inc hl
        push bc
        ld e,(hl)
        inc hl
        ld d,(hl)               ; x from
        inc hl
        ld (v_ev0),de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; x to
        ld (v_ev1),de
        cp $FF
        jr z,.any               ; every bilby that comes by
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,CRT
        add hl,de
        push hl
        pop ix
        pop bc
        ld a,b
        cp 8                    ; nuke
        jr nz,.sk
        ld a,1
        ld (v_nuke),a
        jr .fire
.any:   pop bc
        ld ix,CRT
        ld a,NCRT
.al:    push af
        push bc
        ld a,(ix+C_ST)
        or a
        call nz,.try
        pop bc
        ld de,CSZ
        add ix,de
        pop af
        dec a
        jr nz,.al
        ret
.try:   ld e,(ix+C_XL)
        ld d,(ix+C_XH)
        ld hl,(v_ev0)
        or a
        sbc hl,de
        jr z,.t0
        ret nc
.t0:    ld hl,(v_ev1)
        or a
        sbc hl,de
        ret c
        push bc
        ld a,b
        call can_take
        pop bc
        ret nz
        ld a,b
        add a,2
        ld (v_sel),a
        ld a,b
        jp apply_skill
.sk:    ld e,(ix+C_XL)
        ld d,(ix+C_XH)
        ld hl,(v_ev0)
        or a
        sbc hl,de
        jr z,.x0
        ret nc                  ; x < from
.x0:    ld hl,(v_ev1)
        or a
        sbc hl,de
        ret c                   ; x > to
        push bc
        ld a,b
        call can_take
        pop bc
        ret nz
        ld a,b
        add a,2
        ld (v_sel),a
        push bc
        ld a,b
        call apply_skill
        pop bc
.fire:  call .bit
        or (hl)
        ld (hl),a
        ret
; event C -> HL = its byte in v_dfired, A = its bit; NZ if set
.bit:   push bc
        ld a,c
        rrca
        rrca
        rrca
        and 7
        ld hl,v_dfired
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,c
        and 7
        ld b,a
        ld a,1
        jr z,.b1
.b0:    add a,a
        djnz .b0
.b1:    ld c,a
        and (hl)
        ld a,c
        pop bc
        ret


        ALIGN 16
PMSK:   db $C0,$30,$0C,$03
BITT:   db $80,$40,$20,$10,$08,$04,$02,$01
TEXBUF: ds 16
ref_end:
        SAVEBIN "ref.bin",$8000,ref_end-$8000
