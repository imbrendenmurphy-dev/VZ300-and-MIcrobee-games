; ===================================================================
;  sound.asm - frame-driven 1-bit sound (speaker = PIO B bit 6)
;
;  After the approach of The Lantern Deep: sound is played in the time
;  the game spends waiting for the next frame, so nothing stops for it.
;  wait_frame runs the tone generator until vertical blanking; snd_frame
;  steps the current effect (or the music) once per frame.
;  Tones are narrow pulses (1/8 of the period, 1/4 for an attack): thin
;  and clean.  The serial mouse line is watched inside every loop.
;  Bit 5 of port B (RS232 TXD) is kept at mark throughout.
; ===================================================================
SPK_ON  equ 60h                 ; speaker bit 6 + TXD mark
SPK_OFF equ 20h

; ---- start an effect (HL) / the music (HL) ----
sfx:    ld (fx_ptr),hl
        xor a
        ld (fx_left),a
        ret
music_soft:                     ; the same, with the squelchy sweeping tone
        call music_start
        ld a,1
        ld (mu_soft),a
        ret
music_start:
        ld (mu_ptr),hl
        ld (mu_start),hl
        xor a
        ld (mu_soft),a
        ld (mu_left),a
        ld a,1
        ld (mu_on),a
        ret
music_stop:
        xor a
        ld (mu_on),a
        ret

sfx_click:  ld hl,fx_click
            jr sfx
sfx_tool:   ld hl,fx_tool
            jr sfx
sfx_build:  ld hl,fx_build
            jr sfx
sfx_done:   ld hl,fx_done
            jr sfx
sfx_error:  ld hl,fx_error
            jr sfx
sfx_warn:   ld hl,fx_warn
            jr sfx
sfx_grow:   ld hl,fx_grow
            jr sfx

; ---- once per frame: pick what to play during the next frame ----
snd_frame:
        xor a
        ld (snd_type),a
        ld (snd_sub),a
        ld a,(sound_on)
        or a
        ret z
        ; effect first
        ld hl,(fx_ptr)
        ld a,h
        or l
        jr z,.mus
        ld a,(fx_left)
        or a
        jr nz,.fxgo
        ld a,(hl)               ; next entry
        cp 0FFh
        jr nz,.fxn
        ld hl,0
        ld (fx_ptr),hl
        jr .mus
.fxn:   ld (fx_per),a
        inc hl
        ld a,(hl)
        inc hl
        ld (fx_ptr),hl
        ld b,a
        and 7Fh
        ld (fx_left),a
        ld a,b
        and 80h
        ld (fx_wide),a
.fxgo:  ld hl,fx_left
        dec (hl)
        ld a,(fx_per)
        ld b,a
        ld a,(fx_wide)
        ld c,a
        jp snd_set
.mus:   ld a,(mu_on)
        or a
        ret z
        ld a,(mu_left)
        or a
        jr nz,.mugo
        ld hl,(mu_ptr)
.mrd:   ld a,(hl)
        cp 0FEh
        jr nz,.mn
        ld hl,(mu_start)        ; loop the tune
        jr .mrd
.mn:    cp 0FFh
        jp z,music_stop
        ld (mu_per),a
        inc hl
        ld a,(hl)
        inc hl
        ld (mu_ptr),hl
        ld b,a
        and 80h
        ld (mu_bass),a          ; bit 7 in a tune: a bass note (octave down)
        ld a,b
        and 7Fh
        ld (mu_left),a
        ld (mu_len),a
.mugo:  ld hl,mu_left
        dec (hl)
        ld a,(hl)
        or a
        ret z                   ; last frame of every note is silent
        ld a,(mu_per)
        ld b,a
        ld a,(mu_bass)
        or a
        jr z,.mtop
        ld a,1                  ; bass: a square wave sounding every other period
        ld (snd_sub),a
        ld c,20h
        jr snd_set
.mtop:  ld a,(mu_soft)
        or a
        jr z,.mnorm
        ; squelch: the pulse width sweeps 1/2 -> 1/8 -> back every 8 frames
        ; (a filter "wah"), and odd frames detune by one count for grit
        ld a,(mu_len)
        sub (hl)
        and 7
        ld e,a
        ld d,0
        ld hl,sq_tab
        add hl,de
        ld c,(hl)
        ld a,(frames)
        and 1
        add a,b
        ld b,a
        jr snd_set
.mnorm: ld a,(mu_len)
        dec a
        cp (hl)                 ; first frame of the note: a little attack
        ld c,80h
        jr z,snd_set
        ld c,0
; B = period (0 silence, 1 noise), C = 80h for a wider pulse
snd_set:
        ld a,b
        or a
        ret z
        dec a
        jr nz,.tone
        ld a,2
        ld (snd_type),a
        ret
.tone:  ld a,b
        srl a
        bit 5,c                 ; 1/2: a full square
        jr nz,.w
        srl a
        bit 7,c
        jr nz,.w
        srl a                   ; 1/8 pulse
        bit 6,c
        jr z,.w
        srl a                   ; 1/16 pulse
.w:     cp 2
        jr nc,.h
        ld a,2
.h:     ld (snd_hi),a
        ld c,a
        ld a,b
        sub c
        ld (snd_lo),a
        ld a,1
        ld (snd_type),a
        ret

sq_tab: db 20h,20h,80h,80h,0,0,80h,80h  ; squelch: pulse width per frame

; ---- frame wait = sound + mouse --------------------------------------
wait_frame:
        in a,(P_CRTCA)
        and 20h
        jr z,.p2
        ld d,20h                ; in blanking: play until it ends
        call play_until
.p2:    ld d,0                  ; play until blanking starts
        call play_until
        ld hl,(frames)
        inc hl
        ld (frames),hl
        jp snd_frame

; play the current sound until (status AND 20h) <> D; E = mouse idle level
play_until:
        ld a,(ms_idle)
        ld e,a
        ld a,(snd_type)
        dec a
        jr z,.tone
        dec a
        jr z,.noise
        ld a,SPK_OFF
        out (P_PIOB),a
.s:     in a,(P_CRTCA)
        and 20h
        cp d
        ret nz
        in a,(P_PIOB)
sn_s1 equ $+1
        and 10h
        cp e
        jr z,.s
        call .mouse
        jr .s
.tone:  ; the wave carries on where the last frame left it (no clicks)
        ld a,(snd_cnt)
        or a
        jr z,.hi0
        ld b,a
        ld a,(snd_ph)
        or a
        jr nz,.lo
        jr .hi
.hi0:   ld a,(snd_hi)
        ld b,a
.hi:    ld a,(snd_sub)
        or a
        jr z,.hn
        ld a,(snd_tg)           ; sub-octave: every other pulse stays silent
        xor 40h
        ld (snd_tg),a
        jr .ho
.hn:    ld a,SPK_ON
.ho:    out (P_PIOB),a
        ld c,0
.t1:    in a,(P_CRTCA)          ; 11
        and 20h                 ; 7
        cp d                    ; 4
        jr nz,.save             ; 7
        in a,(P_PIOB)           ; 11
sn_s2 equ $+1
        and 10h                 ; 7
        cp e                    ; 4
        call nz,.mouse          ; 10
        djnz .t1                ; 13  = 74 T per count
        ld a,(snd_lo)
        ld b,a
.lo:    ld a,SPK_OFF
        out (P_PIOB),a
        ld c,1
.t2:    in a,(P_CRTCA)
        and 20h
        cp d
        jr nz,.save
        in a,(P_PIOB)
sn_s3 equ $+1
        and 10h
        cp e
        call nz,.mouse
        djnz .t2
        jr .hi0
.save:  ld a,b
        ld (snd_cnt),a
        ld a,c
        ld (snd_ph),a
        ret
.noise: ; soft noise: short random gaps between thin clicks
        xor a
        ld (snd_cnt),a
.n0:    ld a,SPK_ON
        out (P_PIOB),a
        ld a,SPK_OFF
        out (P_PIOB),a
        ld a,r
        and 3Fh
        add a,8
        ld b,a
.n1:    in a,(P_CRTCA)
        and 20h
        cp d
        ret nz
        in a,(P_PIOB)
sn_s4 equ $+1
        and 10h
        cp e
        call nz,.mouse
        djnz .n1
        jr .n0
.mouse: push bc                 ; a start bit: take the mouse packet
        push de
        push hl
        call mouse_poll
        pop hl
        pop de
        pop bc
        ret

        include "sfx.inc"
