; =====================================================================
;  SOUND: one speaker bit. The game makes no sound while it works: the
;  tone is played in the time left over, while the frame waits for the
;  vertical blanking. Effects are lists of (pitch, ticks); the tune is
;  slow, separate blips, so the gaps the frame's work leaves in it do
;  not matter.
;  pitch = half-period loop count (42 T a count + 37), $FF = noise, 0 = rest
; =====================================================================
; HL = effect
play_sfx:
        ld (sfx_ptr),hl
        xor a
        ld (sfx_left),a
        inc a
        ld (sfx_on),a
        ret

snd_tick:
        ld a,(sfx_on)
        or a
        jr z,.music
        ld a,(sfx_left)
        or a
        jr nz,.dec
        ld hl,(sfx_ptr)
        ld a,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (sfx_ptr),hl
        inc b
        dec b
        jr z,.end
        ld (snd_per),a
        ld a,b
.dec:   dec a
        ld (sfx_left),a
        jr .mtime
.end:   xor a
        ld (sfx_on),a
.music: xor a
        ld (snd_per),a
.mtime: ; the tune keeps time under the effects
        ld a,(mus_on)
        or a
        ret z
        ld a,(mus_left)
        or a
        jr nz,.mdec
        ld hl,(mus_ptr)
        ld a,(hl)
        cp $FE
        jr nz,.note
        ld hl,tune
        ld a,(hl)
.note:  ld (mus_note),a
        inc hl
        ld a,(hl)
        inc hl
        ld (mus_ptr),hl
        ld (mus_left),a
        ld a,3                  ; each note sounds in the next three waits
        ld (mus_gate),a
        ld a,(mus_left)
.mdec:  dec a
        ld (mus_left),a
        ret

; wait for the vertical blanking to begin, playing the current pitch
snd_wait:
        ld a,(sfx_on)
        or a
        jr nz,.go               ; an effect: the pitch the tick set
        ld a,(mus_gate)
        or a
        jr z,.q
        dec a
        ld (mus_gate),a
        ld a,(mus_note)
.q:     ld (snd_per),a
.go:    in a,(P_CRTCA)
        and $20
        jr z,.p2
        ld e,0
        call snd_until
.p2:    ld e,$20
        call snd_until
        ld a,$20
        ld (vlast),a
        ld hl,fields
        inc (hl)
        ret

; play until (6545 status & $20) = E
snd_until:
        ld a,(snd_per)
        or a
        jr z,.silent
        cp $FF
        jr z,.noise
        ld d,a
        ld a,(spk)
        ld c,a
.cyc:   ld b,d
.h:     in a,(P_CRTCA)
        and $20
        cp e
        jr z,.out
        djnz .h
        ld a,c
        xor $40
        ld c,a
        out (P_PIOB),a
        jr .cyc
.out:   ld a,c
        ld (spk),a
        ret
.silent:
        in a,(P_CRTCA)
        and $20
        cp e
        jr nz,.silent
        ret
.noise: ld hl,(nseed)
.n:     in a,(P_CRTCA)
        and $20
        cp e
        jr z,.nout
        add hl,hl
        jr nc,.n1
        ld a,l
        xor $2D
        ld l,a
.n1:    ld a,h
        and $40
        out (P_PIOB),a
        ld b,6
.nd:    djnz .nd
        jr .n
.nout:  ld a,h
        or l
        jr nz,.ns
        inc l
.ns:    ld (nseed),hl
        ret

jp_hl:  jp (hl)
hook_none:
        ret
