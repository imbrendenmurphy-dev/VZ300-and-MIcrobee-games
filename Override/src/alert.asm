; =====================================================================
;  alert.asm - the ship's alert level (play-only code, CODE2).
;  Every droid you destroy or take over heats the alert up; it cools a
;  little each second. Yellow and red alert pay a bonus every second
;  while they last, so fighting fast is worth it. The rule under the HUD
;  shows the level: green, yellow, red.
; =====================================================================
AL_KILL     equ 70             ; heat a droid adds (3 quick kills: red)
AL_COOL     equ 12             ; heat lost a second (red to green ~15 s)
AL_YELLOW   equ 80
AL_RED      equ 170

; a droid is gone
alert_kill:
            ld a,(al_heat)
            add a,AL_KILL
            jr nc,.s
            ld a,255
.s:         ld (al_heat),a
            ret

; once a frame: cool, set the level, pay the bonus (once a second)
alert_tick:
            ld hl,al_t
            dec (hl)
            ret p
            ld (hl),24              ; 25 frames a second
            ld a,(al_heat)
            sub AL_COOL
            jr nc,.c
            xor a
.c:         ld (al_heat),a
            ld b,0
            cp AL_YELLOW
            jr c,.l
            inc b
            cp AL_RED
            jr c,.l
            inc b
.l:         ld a,(al_lvl)
            cp b
            jr z,.same
            ld c,a                  ; (the old level)
            ld a,b
            ld (al_lvl),a
            call alert_rule
            ld a,b
            cp c
            jr c,.same              ; cooling: no fuss
            add a,a                 ; heating: say so
            ld e,a
            ld d,0
            ld hl,al_msgs-2
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            push bc
            call show_msg
            pop bc
.same:      ld a,b
            or a
            ret z
            ld de,$0025             ; yellow: 25 a second
            dec a
            jr z,.p
            ld de,$0075             ; red: 75 a second
.p:         jp add_score

; the HUD's bottom rule in the alert colour
alert_rule:
            push bc
            ld a,(al_lvl)
            ld e,a
            ld d,0
            ld hl,al_cols
            add hl,de
            ld a,(hl)
            ld hl,BB+BBW*9
            ld bc,BBW
            call fill
            ld a,1
            ld (hud_dirty),a
            pop bc
            ret

; a fresh ship: all calm
alert_reset:
            xor a
            ld (al_heat),a
            ld (al_lvl),a
            ret

al_cols:    db $00,$55,$FF          ; green, yellow, red
al_msgs:    dw al_m1,al_m2
al_m1:      db "YELLOW ALERT",0
al_m2:      db "RED ALERT",0
