; ==========================================================================
; track.asm - streams the legs' road sections into the 256-segment ring
;             (TRK_CURVE / TRK_YL / TRK_YH, page aligned and consecutive)
;             ahead of the camera.                        ViBED by BPM 2026
; ==========================================================================

LOOKAHEAD equ 40                ; segments kept ready ahead of the camera (view: 24)

; track_reset: start of leg 1 at segment 0 of the ring, camera at 0
track_reset:
        ld hl,LEGSEC
        ld (secptr),hl
        xor a
        ld (secleft),a
        ld (ccurve),a
        ld (cslope),a
        ld (tcurve),a
        ld (tslope),a
        ld (wseg),a
        ld hl,0
        ld (cheight),hl
        ld (tdist),hl
        ld (camPos),hl
        ; fall through: fill the ring ahead

; track_stream: generate segments until LOOKAHEAD lie ready ahead of the camera
track_stream:
        ld a,(camPos+1)
        ld b,a
        ld a,(wseg)
        sub b
        cp LOOKAHEAD
        ret nc
        call gen_seg
        call vbpoll
        jr track_stream

gen_seg:
        ld a,(secleft)
        or a
        jr nz,.have
        ld hl,(secptr)
        ld a,(hl)
        or a
        jr nz,.sec
        ld hl,LEGSEC_LAST       ; past the last leg: keep driving the last one
        ld a,(hl)
.sec    ld (secleft),a
        inc hl
        ld a,(hl)
        ld (tcurve),a
        inc hl
        ld a,(hl)
        ld (tslope),a
        inc hl
        ld (secptr),hl
.have   ld hl,secleft
        dec (hl)
        ld a,(tcurve)           ; ease the curve (3 per segment) and slope (1)
        ld b,a
        ld a,(ccurve)
        ld c,3
        call ease
        ld (ccurve),a
        ld a,(tslope)
        ld b,a
        ld a,(cslope)
        ld c,1
        call ease
        ld (cslope),a
        ld a,(wseg)             ; write the ring entry
        ld l,a
        ld h,high(TRK_CURVE)
        ld a,(ccurve)
        ld (hl),a
        inc h
        ld de,(cheight)
        ld (hl),e
        inc h
        ld (hl),d
        ld a,(cslope)           ; height += slope
        ld l,a
        rlca
        sbc a,a
        ld h,a
        add hl,de
        ld (cheight),hl
        ld hl,wseg
        inc (hl)
        ret

; ease: A = current, B = target (signed), C = step -> A moved towards B
ease:   cp b
        ret z
        ld d,a
        xor 80h
        ld e,a
        ld a,b
        xor 80h
        cp e                    ; target > current (signed)?
        ld a,d
        jr c,.down
        add a,c
        ld d,a                  ; overshoot?  (current+step > target)
        xor 80h
        ld e,a
        ld a,b
        xor 80h
        cp e
        ld a,d
        ret nc
        ld a,b
        ret
.down   sub c
        ld d,a
        xor 80h
        ld e,a
        ld a,b
        xor 80h
        cp e
        ld a,d
        ret c
        ret z
        ld a,b
        ret

; advance_dist: called after camPos moved; D = old segment (high byte)
advance_dist:
        ld a,(camPos+1)
        sub d
        ret z
        ld e,a
        ld d,0
        ld hl,(tdist)
        add hl,de
        ld (tdist),hl
        ret

wseg:    db 0
secleft: db 0
secptr:  dw 0
tcurve:  db 0
tslope:  db 0
ccurve:  db 0
cslope:  db 0
cheight: dw 0
tdist:   dw 0                   ; segments driven since the start line
