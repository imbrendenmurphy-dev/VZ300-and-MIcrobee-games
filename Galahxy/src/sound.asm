; =====================================================================
;  sound.asm - one-bit effects and blip music (engine from Zephyr Zone)
;  The field ISR plays one sample per two copied rows and the idle wait
;  keeps playing, so a note is a burst once a frame. In-game music is a
;  slow "dink ... dink-dink" so the game keeps the CPU; effects win.
; =====================================================================
            ; (effect and tune data: gen/sound.inc, in GLXCOM.DAT at COM_LO)

; start effect A (a weapon sound never cuts another effect short)
sfx:
            cp SFX_BOMB+1
            jr nc,.go               ; SHOT/BEAM/TOAST/BOMB are low priority
            ld b,a
            ld hl,(sfx_p)
            ld a,h
            or l
            ld a,b
            jr z,.go
            ld a,(sfx_cur)
            cp SFX_BOMB+1
            ld a,b
            ret nc
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

; start tune HL (0 = silence)
music:
            ld a,h
            or l
            jr z,.off
            ld a,(hl)               ; blip length
            ld (mus_blipl),a
            inc hl
.off:       ld (mus_base),hl
            ld (mus_p),hl
            xor a
            ld (mus_t),a
            ld (blip),a
            ld a,h
            or l
            ld (mus_on),a
            ret

; once per frame (dt = fields since the last call)
sound_tick:
            ld a,(dtf)
            or a
            jr nz,.dt
            inc a
.dt:        ld c,a
            ld hl,(sfx_p)
            ld a,h
            or l
            jr z,.music
            ld a,(sfx_n)
            sub c
            jr z,.next
            jr c,.next
            ld (sfx_n),a
            jr .mclock
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
            call set_voice
            jr .mclock
.end:       ld hl,0
            ld (sfx_p),hl
            xor a
            ld (snd_mask),a
            ld (blip),a
            jr .music
.mclock:    ; the tune keeps time under an effect (silently)
            ld a,(mus_on)
            or a
            ret z
            ld a,(mus_t)
            sub c
            jr z,.adv
            jr c,.adv
            ld (mus_t),a
            ret
.adv:       call mus_fetch
            ret
.music:     ld a,(mus_on)
            or a
            jr z,.quiet
            ld a,(music_off)
            or a
            jr nz,.quiet
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
.note:      call mus_fetch
            ret z                   ; rest
            ld (snd_step),de
            ld a,(mus_blipl)
            or a
            jr nz,.bl
            ld a,(mus_t)
            inc a
.bl:        ld (blip),a
            ld a,$20                ; music: one speaker line (quieter)
            jp set_voice
.quiet:     xor a
            ld (snd_mask),a
            ret

; next tune event -> mus_t set; Z = rest, else DE = step
mus_fetch:
            ld hl,(mus_p)
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
            ret z
            sub NOTE0
            jr nc,.ok
            xor a
            ret
.ok:        add a,a
            ld e,a
            ld d,0
            ld hl,note_steps
            add hl,de
            ld e,(hl)
            inc hl
            ld d,(hl)
            or 1                    ; NZ
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

; one sample for idle waits, paced to the ISR's one sample per two rows
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

silence:
            ld hl,0
            ld (sfx_p),hl
            call music
            xor a
            jp set_voice
