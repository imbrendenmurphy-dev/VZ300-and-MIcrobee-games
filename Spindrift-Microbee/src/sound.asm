; =====================================================================
;  SOUND: one speaker bit, no interrupts. Two square-wave voices are
;  mixed (exclusive-or) in the time the frame waits for the vertical
;  blanking; the work of the frame is silent. Voice 1 is the tune's
;  melody, voice 2 its bass, and effects take voice 2 over.
;  A pitch is a half-period in loop counts (62 T a count); 0 = silent.
; =====================================================================

; wait for the start of the next vertical blanking, sounding the voices
snd_field:
        call vbpoll
        in a,(P_CRTCA)
        and $20
        jr z,.p2
        ld e,0
        call snd_until
.p2:    ld e,$20
        call snd_until
        xor a
        ld (vb_age),a
        ld a,$20
        ld (vlast),a
        ld hl,fields
        inc (hl)
        ret

; play until (6545 status AND 20h) = E
snd_until:
        ld a,(nz_on)
        or a
        jr nz,noise_until
        ld a,(v1per)
        ld h,a
        ld l,a
        or a
        jr z,.s1
        ld a,$40
.s1:    ld (.m1+1),a
        ld a,(v2per)
        ld d,a
        or a
        jr z,.s2
        ld a,$40
.s2:    ld (.m2+1),a
        ld b,e
        ld e,d
        ld c,P_CRTCA
        ld a,(spk)
        ex af,af'
.lp:    in a,(c)
        and $20
        cp b
        jr z,.out
        dec h
        jr nz,.v2
        ld h,l
        ex af,af'
.m1:    xor $40
        out (P_PIOB),a
        ex af,af'
.v2:    dec d
        jr nz,.lp
        ld d,e
        ex af,af'
.m2:    xor $40
        out (P_PIOB),a
        ex af,af'
        jr .lp
.out:   ex af,af'
        ld (spk),a
        ret

noise_until:
        ld b,e
        ld c,P_CRTCA
        ld hl,(rseed)
        ld a,(nz_on)
        ld d,a                  ; density: higher = lower rumble
.n:     in a,(c)
        and $20
        cp b
        jr z,.out
        add hl,hl
        jr nc,.n1
        ld a,l
        xor $2D
        ld l,a
.n1:    ld a,h
        and $40
        out (P_PIOB),a
        ld e,d
.nd:    dec e
        jr nz,.nd
        jr .n
.out:   ld a,h
        or l
        jr nz,.ns
        inc l
.ns:    ld (rseed),hl
        ret

; silence everything
snd_off:
        xor a
        ld (sfx_on),a
        ld (mus_on),a
        ld (v1per),a
        ld (v2per),a
        ld (nz_on),a
        ret

; HL = effect, A = priority: a higher or equal priority replaces
play_sfx:
        push bc
        ld b,a
        ld a,(sndmode)
        or a
        jr z,.no
        ld a,(sfx_on)
        or a
        jr z,.go
        ld a,(sfx_pri)
        cp b
        jr z,.go
        jr nc,.no
.go:    ld a,b
        ld (sfx_pri),a
        ld (sfx_ptr),hl
        xor a
        ld (sfx_left),a
        inc a
        ld (sfx_on),a
.no:    pop bc
        ret

; HL = tune: melody, bass, gate (frames a note sounds; 0 = all but one)
play_tune:
        ld a,(sndmode)
        cp 2
        ret c
force_tune:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (mus_p1),de
        ld (mus_b1),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (mus_p2),de
        ld (mus_b2),de
        ld a,(hl)
        ld (mus_gate),a
        xor a
        ld (mus_l1),a
        ld (mus_l2),a
        ld (mus_n1),a
        ld (mus_n2),a
        inc a
        ld (mus_on),a
        ret

; is a tune playing? NZ = yes
tune_busy:
        ld a,(mus_on)
        or a
        ret

; once a frame: what the voices play while the frame waits
snd_tick:
        xor a
        ld (v1per),a
        ld (v2per),a
        ld (nz_on),a
        ld a,(sndmode)
        or a
        ret z
        ld a,(mus_on)
        or a
        jr z,.sfx
        ld ix,mus_p1
        call .chan
        ld (v1per),a
        ld ix,mus_p2
        call .chan
        ld (v2per),a
.sfx:   ld a,(sfx_on)
        or a
        ret z
        ld a,(sfx_left)
        or a
        jr nz,.cont
        ld hl,(sfx_ptr)
        ld a,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (sfx_ptr),hl
        inc b
        dec b
        jr z,.end
        ld (sfx_cur),a
        ld a,b
.cont:  dec a
        ld (sfx_left),a
        ld a,(sfx_cur)
        cp $F0
        jr nc,.nz
        ld (v2per),a
        ret
.nz:    and $0F                 ; F0h-FFh: noise, low nibble = density
        add a,a
        add a,a
        add a,2
        ld (nz_on),a
        ret
.end:   xor a
        ld (sfx_on),a
        ret
; a channel (IX: ptr, base, left, note, gate count) -> A = its pitch now
.chan:  ld a,(ix+4)             ; frames left of this note
        or a
        jr nz,.held
        ld l,(ix+0)
        ld h,(ix+1)
.fetch: ld a,(hl)
        cp $FF
        jr z,.stop
        cp $FE
        jr nz,.note
        ld l,(ix+2)
        ld h,(ix+3)
        jr .fetch
.stop:  xor a
        ld (mus_on),a
        ret
.note:  inc hl
        ld b,(hl)
        inc hl
        ld (ix+0),l
        ld (ix+1),h
        ld (ix+4),b
        ld (ix+5),a             ; note
        ld a,(mus_gate)
        or a
        jr nz,.g
        ld a,b
        dec a
.g:     ld (ix+6),a             ; frames it sounds
        ld a,(ix+4)
.held:  dec (ix+4)
        ld a,(ix+6)
        or a
        ret z
        dec (ix+6)
        ld a,(ix+5)
        or a
        ret z
        ld hl,notetab-1
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld a,(hl)
        ret
