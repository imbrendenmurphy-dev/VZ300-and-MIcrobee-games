; =====================================================================
;  sound.asm - one 8253 square-wave voice shared by music and effects
;
;  snd_tick runs once per field (50 Hz, from poll).  A sound effect owns
;  the voice while it plays; otherwise the music player picks, tick by
;  tick, between drum, bass pluck and lead (with arpeggio and vibrato).
;  Noise: poll rewrites counter 0 with random values while noise_on is
;  set, so noise gets finer the more often the code polls.
; =====================================================================

; ---------------------------------------------------------------------
; output primitives
; ---------------------------------------------------------------------
; HL = divisor
out_div:
        xor a
        ld (noise_on),a
        ld a,(cur_div)
        cp l
        jr nz,.w
        ld a,(cur_div+1)
        cp h
        jr z,.g
.w:     ld (cur_div),hl
        ld a,l
        ld (CTR0),a
        ld a,h
        ld (CTR0),a
.g:     ld a,1
        ld (SNDGATE),a
        ret

; A = noise band (high byte of the divisor)
out_noise:
        ld (noise_band),a
        ld a,1
        ld (noise_on),a
        ld (SNDGATE),a
        ld hl,0
        ld (cur_div),hl
        ret

out_off:
        xor a
        ld (noise_on),a
        ld (SNDGATE),a
        ret

noise_step:
        ld a,r
        ld (CTR0),a
        ld a,(noise_band)
        ld (CTR0),a
        ret

; ---------------------------------------------------------------------
; sound effects: one word per tick
;   divisor  /  0FFxxh noise band xx  /  0FE00h rest  /  0 end
; ---------------------------------------------------------------------
; HL = effect, A = priority (replaces a playing effect of equal or lower
; priority)
sfx:
        push bc
        ld b,a
        ld a,(sfxptr+1)
        or a
        jr z,.go
        ld a,(sfxpri)
        cp b
        jr z,.go
        jr nc,.no
.go:    ld (sfxptr),hl
        ld a,b
        ld (sfxpri),a
.no:    pop bc
        ret

sfx_stop:
        ld hl,0
        ld (sfxptr),hl
        jp out_off

snd_tick:
        ld a,(snd_mute)
        or a
        jp nz,out_off
        call mus_step
        ld hl,(sfxptr)
        ld a,h
        or a
        jp z,mus_out
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr nz,.play
        ld (sfxptr),de              ; end of effect
        ld (sfxpri),a
        jp mus_out
.play:  ld (sfxptr),hl
        ld a,d
        cp 0FEh
        jr c,.note
        jp z,out_off
        ld a,e
        jp out_noise
.note:  ex de,hl
        jp out_div

; ---------------------------------------------------------------------
; music
;   song:    db speed / dw pattern, pattern, ... / dw 0 (loop) or 1 (stop)
;   pattern: rows of 4 bytes: lead, bass, drum, fx ; FFh ends the pattern
;            note byte: 0 = hold, 1 = off, else index into NOTETAB
;            drum: 0 none, 1 kick, 2 snare, 3 hat
;            fx: bits 0-1 arpeggio (1 major, 2 minor, 3 octave),
;                bit 2 = bass and lead alternate every tick
; ---------------------------------------------------------------------
; HL = song
mus_play:
        ld a,(hl)
        ld (mus_speed),a
        inc hl
        ld (mus_song),hl
        ld (mus_ord),hl
        xor a
        ld (lead_note),a
        ld (bass_note),a
        ld (drum_kind),a
        ld (mus_fx),a
        ld a,1
        ld (mus_tick),a
        ld (mus_on),a
        call mus_nextpat
        ret

mus_stop:
        xor a
        ld (mus_on),a
        ld (lead_note),a
        ld (bass_note),a
        ld (drum_kind),a
        ret

; A = 0 when the song has finished (or no music)
mus_playing:
        ld a,(mus_on)
        ret

; advance to the next pattern in the order list
mus_nextpat:
        ld hl,(mus_ord)
.rd:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        and e
        inc a
        jr nz,.nj
        ld e,(hl)                   ; FFFFh, address: continue the order there
        inc hl
        ld d,(hl)
        ex de,hl
        jr .rd
.nj:    ld a,d
        or a
        jr nz,.ok
        ld a,e
        or a
        jr nz,.stop
        ld hl,(mus_song)            ; 0: loop
        jr .rd
.stop:  xor a
        ld (mus_on),a
        ld (lead_note),a
        ld (bass_note),a
        ret
.ok:    ld (mus_ord),hl
        ld (mus_row),de
        ret

mus_step:
        ld a,(mus_on)
        or a
        ret z
        ld hl,lead_age
        inc (hl)
        ld hl,bass_age
        inc (hl)
        ld hl,drum_age
        inc (hl)
        ld hl,mus_arp
        inc (hl)
        ld hl,mus_tick
        dec (hl)
        ret nz
        ld a,(mus_speed)
        ld (hl),a
        ld hl,(mus_row)
        ld a,(hl)
        cp 0FFh
        jr nz,.row
        call mus_nextpat
        ld a,(mus_on)
        or a
        ret z
        ld hl,(mus_row)
.row:   ld a,(hl)                   ; lead
        inc hl
        or a
        jr z,.l1
        dec a
        ld (lead_note),a            ; 0 = off
        xor a
        ld (lead_age),a
        ld (mus_arp),a
.l1:    ld a,(hl)                   ; bass
        inc hl
        or a
        jr z,.b1
        dec a
        ld (bass_note),a
        xor a
        ld (bass_age),a
.b1:    ld a,(hl)                   ; drum
        inc hl
        or a
        jr z,.d1
        ld (drum_kind),a
        ld c,a
        xor a
        ld (drum_age),a
        ld a,(bass_age)             ; bass struck on this row: pluck after the drum
        or a
        jr nz,.d1
        ld a,c
        cp 3
        ld a,-2
        jr nz,$+4
        ld a,-1
        ld (bass_age),a
.d1:    ld a,(hl)                   ; fx
        inc hl
        ld (mus_fx),a
        ld (mus_row),hl
        ret

; music output for this tick (voice not taken by an effect)
mus_out:
        ld a,(mus_on)
        or a
        jp z,out_off
        ; drums
        ld a,(drum_kind)
        or a
        jr z,.nodrum
        ld c,a
        ld a,(drum_age)
        ld b,a
        ld a,c
        cp 1
        jr nz,.notkick
        ld a,b                      ; kick: 2 ticks, falling pitch
        cp 2
        jr nc,.drumoff
        add a,a
        ld e,a
        ld d,0
        ld hl,kick_divs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp out_div
.notkick:
        cp 2
        jr nz,.hat
        ld a,b                      ; snare: 2 ticks noise
        cp 2
        jr nc,.drumoff
        ld a,1
        jp out_noise
.hat:   ld a,b                      ; hat: 1 tick high noise
        or a
        jr nz,.drumoff
        xor a
        jp out_noise
.drumoff:
        xor a
        ld (drum_kind),a
.nodrum:
        ld a,(mus_fx)
        bit 2,a
        jr z,.noalt
        ld a,(bass_note)            ; alternate: bass on odd ticks
        or a
        jr z,.noalt
        ld a,(mus_arp)
        rra
        jr c,.bass
        jr .lead
.noalt: ld a,(bass_note)            ; bass pluck: first 2 ticks of a note
        or a
        jr z,.lead
        ld a,(bass_age)
        cp 2
        jr c,.bass
.lead:  ld a,(lead_note)
        or a
        jr z,.basshold
        ld b,a
        ld a,(mus_fx)
        and 3
        jr z,.noarp
        ld c,a
        ld a,(mus_arp)
.mod3:  cp 3
        jr c,.m3
        sub 3
        jr .mod3
.m3:    or a
        jr z,.noarp
        dec a                       ; 0 = second, 1 = third note of the chord
        ld e,a
        ld a,c
        dec a
        add a,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        ld hl,arp_tab
        add hl,de
        ld a,b
        add a,(hl)
        ld b,a
.noarp: ld a,b
        call note_div
        ld a,(lead_age)             ; vibrato after 10 ticks
        cp 10
        jp c,out_div
        and 2
        jp z,out_div
        ld a,l                      ; HL += HL/128 (a bit flat)
        add a,a
        ld a,h
        adc a,a
        ld e,a
        ld a,0
        adc a,0
        ld d,a
        add hl,de
        jp out_div
.basshold:
        ld a,(bass_note)
        or a
        jp z,out_off
.bass:  ld a,(bass_note)
        call note_div
        jp out_div

; A = note index -> HL = divisor
note_div:
        add a,a
        ld l,a
        ld h,high NOTETAB
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ret

arp_tab:
        db 4,7,0,0                  ; major
        db 3,7,0,0                  ; minor
        db 12,0,0,0                 ; octave

kick_divs:
        dw 1600,4200
