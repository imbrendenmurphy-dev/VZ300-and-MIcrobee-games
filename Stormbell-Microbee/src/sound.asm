; =====================================================================
;  SOUND: the speaker (PIO B bit 6).
;
;  Sound is made in slices of about 2.4 ms, played back to back by
;  sound_pump whenever the game is waiting for the next tick, so an
;  effect is a continuous shaped sound, not one beep a tick.
;
;  Two generators:
;   * the toggler: flips the speaker every P + (random & M) delay
;     counts. M = 0 is a clean tone, a small M a gritty one, a large M
;     noise of a chosen brightness. Sweeping P and M slice by slice
;     makes cracks, thumps, swishes and rumbles.
;   * the mixer: two pulse voices sounding together, each with its own
;     pitch and pulse width. Narrowing the pulse fades the voice, which
;     gives plucked notes and ringing bells and gongs. The music plays
;     through it: a melody voice and a bass voice.
;
;  Effect: db priority, db ticks the music waits, then slices:
;    db 1,P,M,N   toggler, 13 T a count, N half cycles
;    db 2,P,M,N   toggler, 55 T a count
;    db 3: dw inc1, inc2: db width1, width2, fade1, fade2   strike the voices
;    db 4,N       let the voices ring for N slices
;    db 0         end (the voices ring on)
;  Tune: dw track1, track2 (0 = none): db width1, fade1, width2, fade2.
;  Track: db note, db ticks; note 0 rests, FFh loops.
; =====================================================================
CH_P        EQU 0           ; track pointer
CH_BASE     EQU 2           ; track start (0 = no track)
CH_T        EQU 4           ; ticks left of this note
CH_W0       EQU 5           ; a new note's pulse width
CH_F0       EQU 6           ; slices between fades
CH_INC      EQU 7           ; phase step
CH_PH       EQU 9           ; phase
CH_W        EQU 11          ; pulse width now (0 = silent)
CH_F        EQU 12
CH_C        EQU 13          ; slices to the next fade
CH_SIZE     EQU 14
MIXN        EQU 80          ; samples a slice (about 109.5 T each)

; A = effect (keeps BC, DE, HL)
sfx:    push hl
        push de
        add a,a
        ld e,a
        ld d,0
        ld hl,sfxtab
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(sfx_p)
        ld a,h
        or l
        jr z,.go
        ld a,(de)
        ld hl,sfx_pri
        cp (hl)
        jr c,.x                 ; something weightier is sounding
.go:    ld a,(de)
        ld (sfx_pri),a
        inc de
        ld a,(de)
        inc de
        ld hl,mus_hold
        cp (hl)
        jr c,.h
        ld (hl),a
.h:     ld (sfx_p),de
        xor a
        ld (sfx_n),a
        ld (ch1+CH_W),a
        ld (ch2+CH_W),a
.x:     pop de
        pop hl
        ret

; HL = tune
play_music:
        ld (mus_base),hl
        push ix
        ld ix,ch1
        call .trk
        ld ix,ch2
        call .trk
        ld a,(hl)
        ld (ch1+CH_W0),a
        inc hl
        ld a,(hl)
        ld (ch1+CH_F0),a
        inc hl
        ld a,(hl)
        ld (ch2+CH_W0),a
        inc hl
        ld a,(hl)
        ld (ch2+CH_F0),a
        pop ix
        ld a,1
        ld (mus_on),a
        ret
.trk:   ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ix+CH_P),e
        ld (ix+CH_P+1),d
        ld (ix+CH_BASE),e
        ld (ix+CH_BASE+1),d
        ld (ix+CH_T),0
        ld (ix+CH_W),0
        ret
stop_music:
        xor a
        ld (mus_on),a
        ld (ch1+CH_W),a
        ld (ch2+CH_W),a
        ret
resume_music:
        ld hl,(mus_base)
        ld a,h
        or l
        ret z
        jr play_music

; once a tick: the music's clock
sound_tick:
        ld a,(mus_hold)
        or a
        jr z,.nh
        dec a
        ld (mus_hold),a
        ret
.nh:    ld a,(mus_on)
        or a
        ret z
        push ix
        ld ix,ch1
        call .trk
        ld ix,ch2
        call .trk
        pop ix
        ret
.trk:   ld l,(ix+CH_BASE)
        ld h,(ix+CH_BASE+1)
        ld a,h
        or l
        ret z
        ld a,(ix+CH_T)
        or a
        jr z,.next
        dec (ix+CH_T)
        ret
.next:  ld l,(ix+CH_P)
        ld h,(ix+CH_P+1)
.f:     ld a,(hl)
        cp $FF
        jr nz,.n
        ld l,(ix+CH_BASE)
        ld h,(ix+CH_BASE+1)
        jr .f
.n:     inc hl
        ld b,(hl)
        inc hl
        ld (ix+CH_P),l
        ld (ix+CH_P+1),h
        dec b
        ld (ix+CH_T),b
        or a
        ret z                   ; a rest: the last note fades on
        ld l,a
        ld h,0
        add hl,hl
        ld de,notetab-2
        add hl,de
        ld a,(hl)
        ld (ix+CH_INC),a
        inc hl
        ld a,(hl)
        ld (ix+CH_INC+1),a
        ld a,(ix+CH_W0)
        ld (ix+CH_W),a
        ld a,(ix+CH_F0)
        ld (ix+CH_F),a
        ld (ix+CH_C),a
        ret

; one slice of whatever is sounding (about 2.4 ms); returns at once if
; nothing is
sound_pump:
        ld a,(sound_on)
        or a
        ret z
        ld hl,(sfx_p)
        ld a,h
        or l
        jr z,.voices
        ld a,(sfx_n)
        or a
        jr z,.fetch
        dec a
        ld (sfx_n),a
        jp mixslice
.fetch: ld a,(hl)
        inc hl
        or a
        jr nz,.op
        ld h,a
        ld l,a
        ld (sfx_p),hl
.voices:
        ld a,(ch1+CH_W)
        ld hl,ch2+CH_W
        or (hl)
        ret z
        jp mixslice
.op:    cp 3
        jr c,toggler
        jr z,.strike
        ld a,(hl)               ; 4: ring on
        inc hl
        ld (sfx_n),a
        ld (sfx_p),hl
        ret
.strike:
        ld de,ch1+CH_INC
        ldi
        ldi
        ld de,ch2+CH_INC
        ldi
        ldi
        ld a,(hl)
        ld (ch1+CH_W),a
        inc hl
        ld a,(hl)
        ld (ch2+CH_W),a
        inc hl
        ld a,(hl)
        ld (ch1+CH_F),a
        ld (ch1+CH_C),a
        inc hl
        ld a,(hl)
        ld (ch2+CH_F),a
        ld (ch2+CH_C),a
        inc hl
        ld (sfx_p),hl
        jr .fetch

; A = 1 (13 T counts) or 2 (55 T counts), HL = P, M, N
toggler:
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld (sfx_p),hl
        dec a
        jr nz,.coarse
.c:     ld a,(spk)
        xor $40
        ld (spk),a
        out (P_PIOB),a
        call srnd
        and c
        add a,d
        jr nc,.k
        ld a,255
.k:     ld b,a
.d:     djnz .d
        ld a,(watch)
        or a
        jr z,.n1
        in a,(P_CRTCA)
        and $20
        ret nz                  ; a blanking: the screen's turn
.n1:    dec e
        jr nz,.c
        ret
.coarse:
.c2:    ld a,(spk)
        xor $40
        ld (spk),a
        out (P_PIOB),a
        call srnd
        and c
        add a,d
        jr nc,.k2
        ld a,255
.k2:    ld b,a
.d2:    push hl
        pop hl
        push hl
        pop hl
        djnz .d2
        ld a,(watch)
        or a
        jr z,.n2
        in a,(P_CRTCA)
        and $20
        ret nz
.n2:    dec e
        jr nz,.c2
        ret

; the sound's own random numbers (the game's stay its own) -> A
srnd:   ld hl,(sseed)
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
        ld (sseed),hl
        ret

; one slice of the two voices, then their fades
mixslice:
        exx
        ld de,(ch2+CH_INC)
        ld hl,(ch2+CH_PH)
        ld a,(ch2+CH_W)
        ld c,a
        exx
        ld de,(ch1+CH_INC)
        ld hl,(ch1+CH_PH)
        ld a,(ch1+CH_W)
        ld c,a
        ld a,MIXN/8
        ld (mx_n),a
        ld b,8
.l:     add hl,de
        ld a,h
        cp c
        sbc a,a
        exx
        ld b,a
        add hl,de
        ld a,h
        cp c
        sbc a,a
        or b
        exx
        and $40
        out (P_PIOB),a
        djnz .l
        ld (spk),a              ; every 8 samples: a blanking to give way to?
        ld b,8
        ld a,(watch)
        or a
        jr z,.nw
        in a,(P_CRTCA)
        and $20
        jr nz,.ab
.nw:    ld a,(mx_n)
        dec a
        ld (mx_n),a
        jr nz,.l
        ld (ch1+CH_PH),hl
        exx
        ld (ch2+CH_PH),hl
        exx
        ld hl,ch1+CH_W
        call .fade
        ld hl,ch2+CH_W
.fade:  ld a,(hl)
        or a
        ret z
        inc hl
        inc hl
        dec (hl)                ; CH_C
        ret nz
        dec hl
        ld a,(hl)               ; CH_F
        inc hl
        ld (hl),a
        dec hl
        dec hl
        ld a,(hl)               ; the width loses an eighth and one
        rra
        rra
        rra
        and $1F
        inc a
        ld b,a
        ld a,(hl)
        sub b
        jr c,.z
        cp 4                    ; too narrow to sound: only clicks, so end
        jr nc,.s
.z:     xor a
.s:     ld (hl),a
        ret
.ab:    ld (ch1+CH_PH),hl
        exx
        ld (ch2+CH_PH),hl
        exx
        ret
