; =====================================================================
;  sound.asm - one-bit effects and "blip" music
;  The field ISR plays one sample per copied row, and present() keeps
;  playing while it waits, so a note is a short burst once a frame -
;  music is a slow, separate "dink ... dink-dink" so the game keeps the
;  CPU; effects use both speaker lines (louder) and win over music.
; =====================================================================
            include "gen/sound.inc"

; start effect A (the blaster's own sound never cuts another effect short)
sfx:
            cp SFX_SHOT
            jr nz,.go
            ld b,a
            ld hl,(sfx_p)
            ld a,h
            or l
            ld a,b
            jr z,.go
            ld a,(sfx_cur)
            cp SFX_SHOT
            ld a,b
            ret nz
.go:        ld (sfx_cur),a
            add a,a
            ld e,a
            ld d,0
            ld hl,sfx_tab
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld (sfx_p),hl
            xor a
            ld (sfx_n),a
            ret

; start tune HL (0 = silence): every note is a short blip, so the music
; costs nothing beyond the sample per copied row the ISR plays anyway
music:
            ld (mus_base),hl
            ld (mus_p),hl
            xor a
            ld (mus_t),a
            ld (blip),a
            ld a,h
            or l
            ld (mus_on),a
            ret

; once per frame
sound_tick:
            ld a,(dt)
            ld c,a
            ld hl,(sfx_p)
            ld a,h
            or l
            jr z,.music
            ld a,(sfx_n)
            sub c
            jr z,.next
            jr c,.next
            ld (sfx_n),a
            ret
.next:      ld a,(hl)
            or a
            jr z,.end
            ld (sfx_n),a
            inc hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (snd_step),de
            ld a,(hl)
            inc hl
            ld (sfx_p),hl
            jp set_voice
.end:       ld hl,0
            ld (sfx_p),hl
            xor a
            ld (snd_mask),a
            ld (blip),a
.music:     ld a,(mus_on)
            or a
            jr z,.quiet
            ld a,(blip)
            or a
            jr z,.nb
            sub c
            jr nc,.b1
            xor a
.b1:        ld (blip),a
            or a
            jr nz,.nb
            xor a
            call set_voice          ; end of the blip: silence
.nb:        ld a,(mus_t)
            sub c
            jr z,.note
            jr c,.note
            ld (mus_t),a
            ret
.note:      ld hl,(mus_p)
            ld a,(hl)
            or a
            jr nz,.n1
            ld hl,(mus_base)
            ld a,(hl)
.n1:        ld (mus_t),a
            inc hl
            ld a,(hl)
            inc hl
            ld (mus_p),hl
            or a
            ret z                   ; rest
            sub NOTE0
            ret c
            add a,a
            ld e,a
            ld d,0
            ld hl,note_steps
            add hl,de
            ld e,(hl)
            inc hl
            ld d,(hl)
            ld (snd_step),de
            ld a,(mus_t)            ; the note sounds right up to the next one:
            inc a                   ; music only plays in the attract sequence, so
            ld (blip),a             ; it has all the speaker time there is
            ld a,$20                ; music: one speaker line (quieter)
            jp set_voice
.quiet:     xor a
            ld (snd_mask),a
            ret

; A = mask (bit 7: noise) -> ISR voice
set_voice:
            ld b,a
            and $7F
            ld (snd_mask),a
            bit 7,b
            ld hl,$7C19             ; add hl,de : ld a,h
            jr z,.t
            ld hl,$5FED             ; ld a,r
.t:         ld (snd_gen),hl
            ret

; one sample for present()'s idle wait, paced (with the loop round it) to
; the ISR's one sample per two copied rows, about 1100 T, so pitch holds
wait_sound:
            ld hl,(snd_ph)
            ld de,(snd_step)
            add hl,de
            ld (snd_ph),hl
            ld a,(snd_gen)
            cp $ED
            ld a,h
            jr nz,.t
            ld a,r
.t:         rla
            sbc a,a
            ld b,a
            ld a,(snd_mask)
            and b
            ld b,a
            ld a,(latchv)
            xor b
            ld (LATCH),a
            ld b,WAIT_D
.d:         djnz .d
            ret

; ---------------------------------------------------------------------
; "AAARGH!" - 1-bit sampled speech (tools/speech.py) played with the CPU to
; itself: interrupts off, nothing else running, so it doesn't warble
; ---------------------------------------------------------------------
say_argh:
            ld hl,SPEECH
            ld de,SPEECH_END
            jr say
say_ready:
            ld hl,ready_snd
            ld de,ready_end
; play 1-bit speech HL..DE (in bank 3 or main RAM)
say:
            di
            ld a,MAP_GAME           ; (AAARGH lives in bank 3)
            out (BANKPORT),a
            ld a,(latchv)
            ld b,a
            ld (sp_latch),a
.byte:      push de
            ld e,(hl)
            ld b,8
.bit:       rl e                    ; 8
            sbc a,a                 ; 4
            and $21                 ; 7
            ld d,a                  ; 4
            ld a,(sp_latch)         ; 13
            xor d                   ; 4
            ld (LATCH),a            ; 13
            ld c,SPEECH_DLY-2       ; 7
.d:         dec c                   ; 4
            jr nz,.d                ; 12
            djnz .bit               ; 13
            pop de
            inc hl
            ld a,h
            cp d
            jr nz,.byte
            ld a,l
            cp e
            jr nz,.byte
            ld a,(sp_latch)
            ld (LATCH),a
            ld a,(cur_map)
            out (BANKPORT),a
            xor a
            ld (intoff),a
            ei
            ret
sp_latch:   db 0
