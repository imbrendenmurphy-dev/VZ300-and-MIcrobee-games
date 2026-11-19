; =====================================================================
;  sound.asm - game-mode effects: one voice (pitch, volume, noise) set
;  once a frame from a sequence; the samples come from the ISR copy, the
;  window copy and the idle waits (all ~800 T apart)
;  sequence: db frames, dw step, db mask (bit 7 noise; $21 loud, $20 soft)
;  ... db 0
; =====================================================================
            include "gen/sfx.inc"

; start effect A unless something more important is playing
sfx:
            ld c,a
            ld a,(sfx_on)
            or a
            ret z
            ld hl,(sfx_p)
            ld a,h
            or l
            jr z,.go
            ld a,(sfx_cur)
            ld b,a
            ld a,c
            call sfx_pri
            ld e,a
            ld a,b
            call sfx_pri
            cp e
            jr z,.go                ; same importance: restart
            ret nc                  ; playing something more important
.go:        ld a,c
            ld (sfx_cur),a
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

; A = effect -> A = its priority
sfx_pri:
            push hl
            ld hl,sfx_prio
            add a,l
            ld l,a
            jr nc,.n
            inc h
.n:         ld a,(hl)
            pop hl
            ret

; once a frame
sound_tick:
            call sfx_seq
            jp snd_make             ; (upper bank 1) tune + mix into the ring
sfx_seq:    ld hl,(sfx_p)
            ld a,h
            or l
            jr z,.quiet
            ld a,(sfx_n)
            or a
            jr z,.next
            dec a
            ld (sfx_n),a
            ret
.next:      ld a,(hl)
            or a
            jr z,.end
            dec a
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
            ld b,a
            and $7F
            ld (snd_mask),a
            ld a,b
            and $80
            ld (snd_noise),a
            ret
.end:       ld hl,0
            ld (sfx_p),hl
.quiet:     xor a
            ld (snd_mask),a
            ld (snd_noise),a
            ret

snd_off:
            ld hl,0
            ld (sfx_p),hl
            xor a
            ld (snd_mask),a
            ld (snd_noise),a
            ret
