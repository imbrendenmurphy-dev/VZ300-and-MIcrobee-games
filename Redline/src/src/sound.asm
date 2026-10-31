; =====================================================================
;  sound.asm - racing sound: the engine tone rides on the screen copy
;  (one speaker sample per row in the ISR, as in BIX), effects are short
;  pitch sequences that take over the same channel.
; =====================================================================
upd_sound:
        ld a,(sfx_n)
        or a
        jr nz,.fx
        call upd_engine
        ld a,(snd_noise)        ; off-road rumble: jittered low tone
        or a
        ret z
        call rand
        and $03
        ld h,a
        call rand
        ld l,a
        ld de,200
        add hl,de
        ld (snd_inc),hl
        ret
.fx:    dec a
        ld (sfx_n),a
        ld hl,(sfx_p)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (sfx_p),hl
        ld a,d
        cp $FF
        jr nz,.t
        call rand               ; $FFxx = noise
        ld d,a
        call rand
        ld e,a
.t:     ld (snd_inc),de
        ret

; HL = sequence (dw inc ...), A = frames
sfx_play:
        ld (sfx_p),hl
        ld (sfx_n),a
        ret
sfx_beep:   ld hl,fx_beep
            ld a,4
            jr sfx_play
sfx_go:     ld hl,fx_go
            ld a,8
            jr sfx_play
sfx_bump:   ld hl,fx_bump
            ld a,4
            jr sfx_play
sfx_crash:  ld hl,fx_crash
            ld a,14
            jr sfx_play
sfx_check:  ld hl,fx_check
            ld a,9
            jr sfx_play
sfx_finish: ld hl,fx_fin
            ld a,12
            jr sfx_play
sfx_tick:   ld hl,fx_tick
            ld a,2
            jr sfx_play

; tone increments for ~6.3 kHz row rate: inc = f * 65536 / 6300
NOTE_C5 equ 5430
NOTE_E5 equ 6840
NOTE_G5 equ 8135
NOTE_C6 equ 10860
fx_beep:  dw 4800,4800,4800,0
fx_go:    dw 9600,9600,9600,9600,9600,9600,9600,9600
fx_bump:  dw $FF00,$FF00,1800,900
fx_crash: dw $FF00,$FF00,$FF00,$FF00,$FF00,$FF00,$FF00,$FF00,$FF00,$FF00,$FF00,$FF00,600,0
fx_check: dw NOTE_C5,NOTE_C5,NOTE_E5,NOTE_E5,NOTE_G5,NOTE_G5,NOTE_C6,NOTE_C6,NOTE_C6
fx_fin:   dw NOTE_G5,NOTE_G5,NOTE_E5,NOTE_E5,NOTE_G5,NOTE_G5,NOTE_C6,NOTE_C6,NOTE_C6,NOTE_C6,0,0
fx_tick:  dw 12000,0
