; =====================================================================
;  demo.asm - attract-mode demo playback + shared key helpers
; =====================================================================

demo_start:
        ld hl,demo_data
        ld (demoptr),hl
        xor a
        ld (demot),a
        ret

; demo_input: called by read_input when (demo) is set.  C returns the keys.
demo_input:
        call any_key            ; a real keypress ends the demo
        jr z,.k
        ld a,1
        ld (levdone),a
        ld c,0
        ret
.k:     ld a,(demot)
        or a
        jr nz,.h
        ld hl,(demoptr)
        ld a,(hl)
        cp $FF
        jr nz,.n
        ld a,1                  ; end of the recording
        ld (levdone),a
        ld c,0
        ret
.n:     ld (demokeys),a
        inc hl
        ld a,(hl)
        inc hl
        ld (demoptr),hl
        ld (demot),a
.h:     ld hl,demot
        dec (hl)
        ld a,(demokeys)
        ld c,a
        ret
demokeys db 0

any_key:                        ; NZ if SPACE/M or joystick fire
        ld a,($68EF)
        and $30
        cp $30
        ret nz
        call joy_read
        and $10
        ret
wait_release:
.l:     call any_key
        jr nz,.l
        ret
wait_key:                       ; waits for a key or until BC runs out; NZ = key
.l:     call any_key
        ret nz
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret
delay:  ; BC * 26T
.l:     dec bc
        ld a,b
        or c
        jr nz,.l
        ret

        include "../build/demo.inc"
