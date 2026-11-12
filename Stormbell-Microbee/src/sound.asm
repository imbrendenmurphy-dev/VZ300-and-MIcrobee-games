; =====================================================================
;  SOUND: the speaker (PIO B bit 6), played a short burst at a time.
;
;  Once a logic tick (25 a second) sound_tick plays a few milliseconds
;  of tone or noise: the next step of an effect if one is going, else
;  the music. A music note is a single short blip ("dink") at its start
;  and a quieter tail on the tick after, so the tunes are slow and
;  spaced and the game gets on with it between notes.
;
;  Effect steps: dw half period (26 T-state loops; 0 ends), db half
;  cycles, db 1 = noise. Tunes: db note, db ticks; note 0 rests,
;  FFh loops.
; =====================================================================
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
        ld (sfx_p),de
        pop de
        pop hl
        ret

play_music:
        ld (mus_base),hl
        ld (mus_p),hl
        xor a
        ld (mus_t),a
        ld (mus_tail),a
        inc a
        ld (mus_on),a
        ret
stop_music:
        xor a
        ld (mus_on),a
        ld (mus_tail),a
        ret
resume_music:
        ld hl,(mus_base)
        ld a,h
        or l
        ret z
        jr play_music

sound_tick:
        ld a,(sound_on)
        or a
        ret z
        ; the music's clock runs even while an effect plays
        call .music
        ld hl,(sfx_p)
        ld a,h
        or l
        jr z,.tail
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.sfxend
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld (sfx_p),hl
        ex de,hl                ; HL = half period
        ld e,b                  ; E = half cycles
        ld d,c                  ; D = noise
        jp burst
.sfxend:
        ld hl,0
        ld (sfx_p),hl
.tail:  ld a,(mus_tail)
        or a
        ret z
        ; a music note sounding this tick
        ld b,a
        xor a
        ld (mus_tail),a
        ld a,(mus_note)
        or a
        ret z
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,notetab-4
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,b
        cp 2
        jr z,.full
        inc hl
.full:  ld a,(hl)
        ex de,hl
        ld e,a
        ld d,0
        jr burst
.music: ld a,(mus_on)
        or a
        ret z
        ld a,(mus_t)
        or a
        jr z,.next
        dec a
        ld (mus_t),a
        cp 1                    ; one tick after the note: its tail
        ret nz
        ld a,1
        ld (mus_tail),a
        ret
.next:  ld hl,(mus_p)
.f:     ld a,(hl)
        cp $FF
        jr nz,.n
        ld hl,(mus_base)
        jr .f
.n:     inc hl
        ld b,(hl)
        inc hl
        ld (mus_p),hl
        ld (mus_note),a
        ld a,b
        dec a
        ld (mus_t),a
        ld a,2
        ld (mus_tail),a         ; 2 = the full blip now
        ret

; HL = half period, E = half cycles, D = 1 for noise
burst:  ld a,e
        or a
        ret z
.c:     ld a,d
        or a
        ld a,(spk)
        jr z,.t
        call random
        and $40
        ld b,a
        ld a,(spk)
        xor b
        jr .o
.t:     xor $40
.o:     ld (spk),a
        out (P_PIOB),a
        ld b,h
        ld c,l
.d:     dec bc
        ld a,b
        or c
        jr nz,.d
        dec e
        jr nz,.c
        ret
