; =====================================================================
;  SOUND in the game: one speaker bit, no interrupts. Three voices take
;  turns at the speaker in the time the frame waits for the vertical
;  blanking (the work of the frame itself is silent):
;    MELODY  the note and a hair over its octave, exclusive-or'd: the
;            phaser's shimmer instead of a bare square
;    BASS    a pulse whose duty plucks: a "dunk", not a beep
;    FX      the effects' own voice, so they no longer cut the music: a
;            pulse with a duty and a pitch that glides inside the frame,
;            or pitched noise
;  A sample is 264 T (with the glide), 12 780 a second. Tunes, effects
;  and the pitch table are in RAM block 7 (tools/mkmusic.py); snd_tick
;  reads them once a frame.
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
        ld a,(cpend)            ; the last frame's commit to finish?
        or a
        ret z
        jp commit_rest

; play until (6545 status AND 20h) = E
snd_until:
        ld a,e
        ld (gtg+1),a
        ld hl,(sa_m)
        exx
        ld hl,(sa_m2)
        exx
        ld ix,(sa_b)
        ld iy,(sa_f)
        ld a,(lfsr)
        or a
        jr nz,.sd
        ld a,$5A                ; the noise must never be all zeros
.sd:    ld e,a
        ld d,GLIDE_N
        call gl
        ld (sa_m),hl
        exx
        ld (sa_m2),hl
        exx
        ld (sa_b),ix
        ld (sa_f),iy
        ld a,e
        ld (lfsr),a
        ret
GLIDE_N EQU 16

gl:     in a,(P_CRTCA)          ; 11
        and $20                 ; 7
gtg:    cp 0                    ; 7
        ret z                   ; 5
gma:    ld bc,0                 ; 10  MELODY
        add hl,bc               ; 11
        ld a,h                  ; 4
        exx                     ; 4
gmb:    ld bc,0                 ; 10
        add hl,bc               ; 11
        xor h                   ; 4
        exx                     ; 4
        and $80                 ; 7
        rrca                    ; 4
        out (P_PIOB),a          ; 11
gbs:    ld bc,0                 ; 10  BASS
        add ix,bc               ; 15
        ld a,ixh                ; 8
gbd:    cp 0                    ; 7
        sbc a,a                 ; 4
        and $40                 ; 7
        out (P_PIOB),a          ; 11
gfs:    ld bc,0                 ; 10  FX
        add iy,bc               ; 15
gfj:    jp gft                  ; 10  (gft: a tone, gfn: noise)
gft:    ld a,iyh                ; 8
gfd:    cp 0                    ; 7
        sbc a,a                 ; 4
        and $40                 ; 7
        out (P_PIOB),a          ; 11
gtl:    dec d                   ; 4
        jp nz,gl                ; 10  = 258 T
        ld d,GLIDE_N            ; the glide, every 16 samples (~6 T each)
        push hl
        ld hl,(gfs+1)
gsl:    ld bc,0
        add hl,bc
        ld (gfs+1),hl
        pop hl
        jp gl
gfn:    jr nc,.h                ; noise: a new bit when the rate counter
        ld a,e                  ; wraps (the rate is its pitch)
        add a,a
        jr nc,.x
        xor $1D
.x:     ld e,a
.h:     ld a,e
        and $40
        out (P_PIOB),a
        jp gtl

; silence everything
snd_off:
        xor a
        ld (sfx_on),a
        ld (mus_on),a
snd_quiet:
        ld hl,0
        ld (gma+1),hl
        ld (gmb+1),hl
        ld (gbs+1),hl
        ld (gfs+1),hl
        ld (gsl+1),hl
        xor a
        ld (gbd+1),a
        ld (gfd+1),a
        ld hl,gft
        ld (gfj+1),hl
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
        ld a,1
        ld (sfx_on),a
.no:    pop bc
        ret

; HL = tune (melody, bass, gate): it starts at the next snd_tick, which
; reads it from block 7
play_tune:
        ld a,(sndmode)
        cp 2
        ret c
force_tune:
        ld (mus_hdr),hl
        ld a,2
        ld (mus_on),a
        ret

; is a tune playing? NZ = yes
tune_busy:
        ld a,(mus_on)
        or a
        ret

; once a frame: what the voices play while the frame waits
snd_tick:
        call snd_quiet
        ld a,(sndmode)
        or a
        ret z
        ld a,MP_MUS
        out (P_MEM),a
        call .music
        call .fx
        ld a,MP_TAB
        out (P_MEM),a
        ret
.music: ld a,(sndmode)          ; effects only: no music
        cp 2
        jr c,.mq
        ld a,(mus_on)
        or a
        jr z,.mq
        cp 2
        call z,.start
        ld ix,mus_p1
        call .chan
        or a
        jr z,.mq
        call note_step
        ld (gma+1),hl
        add hl,hl               ; a hair over the octave
        ld de,3
        add hl,de
        ld (gmb+1),hl
        jr .nm
.mq:    ld hl,0                 ; the melody silent: its counters to zero,
        ld (sa_m),hl            ; or their exclusive-or could hold the
        ld (sa_m2),hl           ; speaker high and buzz at the frame rate
.nm:    ld a,(sndmode)
        cp 2
        ret c
        ld a,(mus_on)
        or a
        ret z
        ld ix,mus_p2
        call .chan
        or a
        ret z
        call note_step
        ld (gbs+1),hl
        ld a,(ix+7)             ; the pluck: the duty by the note's age
        dec a
        cp 7
        jr c,.pa
        ld a,7
.pa:    ld e,a
        ld d,0
        ld hl,pluck
        add hl,de
        ld a,(hl)
        ld (gbd+1),a
        ret
.start: ld hl,(mus_hdr)
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
.fx:    ld a,(sfx_on)
        or a
        ret z
        ld hl,(sfx_ptr)
        ld a,(hl)               ; an entry: frames, mode, step, glide
        or a
        jr z,.end
        inc hl
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (gfs+1),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (gsl+1),de
        ld (sfx_ptr),hl
        bit 7,a
        jr nz,.noise
        ld (gfd+1),a
        ret
.noise: ld hl,gfn
        ld (gfj+1),hl
        ret
.end:   xor a
        ld (sfx_on),a
        ret

; a channel (IX: ptr, base, left, note, gate count, -, age) -> A = the
; note sounding now (0 = none)
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
        ld (ix+7),0             ; age
        ld a,(mus_gate)
        or a
        jr nz,.g
        ld a,b
        dec a
.g:     ld (ix+6),a             ; frames it sounds
.held:  dec (ix+4)
        inc (ix+7)
        ld a,(ix+6)
        or a
        ret z
        dec (ix+6)
        ld a,(ix+5)
        ret

; the bass's duty over a note's first frames
pluck:  db 120,88,64,48,38,30,25,21

; A = note (1-based) -> HL = its step (block 7 mapped)
note_step:
        add a,a
        ld l,a
        ld h,0
        ld de,NOTETAB-2
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

