; ==========================================================================
; snd.asm - beeper sound effects and music              ViBED by BPM 2026
;
;  The speaker is driven from the frame-wait loop: while the program would
;  otherwise spin waiting for the next page flip it plays the current sound,
;  half cycle by half cycle, polling the vertical blank in between.  So sound
;  costs no drawing time; notes come out as short blips in the gaps between
;  frames - the slow "dink, dink-dink-dink" style.  Data: build/sound.inc.
; ==========================================================================

; snd_sfx: A = sound number -> starts it (replaces a playing effect)
snd_sfx:
        add a,a
        ld e,a
        ld d,0
        ld hl,SFX_TABLE
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (sfx_ptr),hl
        ld a,1
        ld (sfx_on),a
sfx_next:
        ld hl,(sfx_ptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.end
        ld (snd_hp),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (snd_left),de
        ld (sfx_ptr),hl
        ret
.end    xor a
        ld (sfx_on),a
        ld h,a
        ld l,a
        ld (snd_left),hl
        ret

; snd_music: HL = tune (0 = silence)
snd_music:
        ld (mus_base),hl
        ld (mus_ptr),hl
        ld hl,(fields)
        ld (mus_next),hl
        ret

; snd_frame: once per frame - the music clock
snd_frame:
        ld hl,(mus_ptr)
        ld a,h
        or l
        ret z
        ld a,(musoff)
        or a
        ret nz
        ld hl,(fields)          ; due?
        ld de,(mus_next)
        or a
        sbc hl,de
        ret c
        ld hl,(mus_ptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        and e
        inc a
        jr nz,.n
        ld hl,(mus_base)        ; end: from the top
        ld (mus_ptr),hl
        ret
.n      ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld (mus_ptr),hl
        ld hl,(mus_next)
        add a,l
        ld l,a
        jr nc,.t
        inc h
.t      ld (mus_next),hl
        ld a,(sfx_on)           ; effects have priority
        or a
        ret nz
        ld a,d
        or e
        ret z                   ; a rest
        ld (snd_hp),de
        ld (snd_left),bc
        ret

; snd_wait: wait for the flip time (FRAMEFIELDS fields since the last flip),
;   playing sound meanwhile.  A playing sound always gets at least BUDGET
;   delay counts (~3 ms) per frame, even when the frame is already late.
BUDGET  equ 400
snd_wait:
        ld hl,BUDGET
        ld (.bud),hl
.l      call vbpoll
        ld hl,(fields)
        ld de,(flipf)
        or a
        sbc hl,de
        ld a,l
        cp FRAMEFIELDS
        jr c,.snd
        ld hl,(.bud)            ; due: only the guaranteed share is left
        bit 7,h
        ret nz
        ld a,h
        or l
        ret z
.snd    ld hl,(snd_left)
        ld a,h
        or l
        jr nz,.play
        ld a,(sfx_on)           ; effect step finished: the next one
        or a
        jr z,.idle
        call sfx_next
        jr .l
.idle   ld hl,0                 ; nothing to play: no guaranteed share
        ld (.bud),hl
        jr .l
.play   dec hl
        ld (snd_left),hl
        ld a,(spk)
        xor 40h
        ld (spk),a
        out (PORT_PIOB),a
        ld de,(snd_hp)
        bit 7,d                 ; noise: random jitter on the half period
        jr z,.d0
        res 7,d
        ld a,r
        and 7Fh
        add a,e
        ld e,a
        jr nc,.d0
        inc d
.d0     ld hl,(.bud)
        or a
        sbc hl,de
        ld (.bud),hl
.d      dec de
        ld a,d
        or e
        jr nz,.d
        jr .l
.bud    dw 0

snd_count:  ld a,SND_COUNT
            jp snd_sfx
snd_go:     ld a,SND_GO
            jp snd_sfx
snd_warn:   ld a,SND_WARN
            jp snd_sfx
snd_pass:   ld a,SND_PASS
            jp snd_sfx
snd_crash:  ld a,SND_CRASH
            jp snd_sfx
snd_check:  ld a,SND_CHECK
            jp snd_sfx
snd_timeup: ld a,SND_TIMEUP
            jp snd_sfx
snd_finish: ld a,SND_FINISH
            jp snd_sfx
snd_tally:  ld a,SND_TALLY
            jp snd_sfx

spk:      db 0
sfx_on:   db 0
sfx_ptr:  dw 0
snd_hp:   dw 1
snd_left: dw 0
mus_base: dw 0
mus_ptr:  dw 0
mus_next: dw 0
musoff:   db 0
