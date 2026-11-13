; ===========================================================================
;  music.asm - 3-voice pulse music + SFX channel
;  Stream bytes:
;    $00          rest (for current length)
;    $01-$5F      note (1 = C1)
;    $60-$7F      length = b-$5F ticks
;    $80-$8F      instrument
;    $90 lo hi    pitch slide per tick
;    $F0 lo hi    call pattern
;    $F1          return
;    $FE lo hi    jump
;    $FF          stop
; ===========================================================================

CH_PTR      equ 0
CH_WAIT     equ 2
CH_LEN      equ 3
CH_STEP     equ 4
CH_DUTY     equ 6
CH_DECAY    equ 7
CH_DMIN     equ 8
CH_DSTART   equ 9
CH_RET      equ 10
CH_FLAGS    equ 12
CH_SLIDE    equ 13
CH_SIZE     equ 16

; play song: HL = song header (3 words: ch1, ch2, ch3 stream pointers)
play_song:
            push ix
            call ps_inner
            pop ix
            ret
ps_inner:
            ld (cur_song),hl
            ld ix,chan1
            ld b,3
.l:         ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (ix+CH_PTR),e
            ld (ix+CH_PTR+1),d
            ld (ix+CH_WAIT),1
            ld (ix+CH_LEN),6
            ld (ix+CH_DUTY),0
            ld (ix+CH_SLIDE),0
            ld (ix+CH_SLIDE+1),0
            ld (ix+CH_FLAGS),0
            ld de,CH_SIZE
            add ix,de
            djnz .l
            ret

stop_song:
            xor a
            ld (chan1+CH_PTR+1),a
            ld (chan2+CH_PTR+1),a
            ld (chan3+CH_PTR+1),a
            ld (chan1+CH_DUTY),a
            ld (chan2+CH_DUTY),a
            ld (chan3+CH_DUTY),a
            ld hl,0
            ld (cur_song),hl
            ret

; play sfx: HL = sfx stream
play_sfx:
            push ix
            ld ix,chsfx
            ld (ix+CH_PTR),l
            ld (ix+CH_PTR+1),h
            ld (ix+CH_WAIT),1
            ld (ix+CH_LEN),1
            ld (ix+CH_SLIDE),0
            ld (ix+CH_SLIDE+1),0
            ld (ix+CH_FLAGS),0
            ld (ix+CH_DUTY),0
            pop ix
            ret

; ---------------------------------------------------------------------------
snd_tick:
            ld ix,chan1
            call ch_tick
            ld ix,chan2
            call ch_tick
            ld ix,chan3
            call ch_tick
            ld ix,chsfx
            call ch_tick
            ; --- write operands into the sample loop ---
            ld a,(music_on)
            or a
            ld hl,(chan1+CH_STEP)
            ld (ml_s1+1),hl
            ld a,(chan1+CH_DUTY)
            call nz_mute
            ld (ml_d1+1),a
            ld hl,(chan2+CH_STEP)
            ld (ml_s2+1),hl
            ld a,(chan2+CH_DUTY)
            call nz_mute
            ld (ml_d2+1),a
            ; channel 3: SFX overrides
            ld a,(chsfx+CH_PTR+1)
            or a
            jr nz,.sfx
            ld a,(chsfx+CH_DUTY)
            or a
            jr nz,.sfx
            ld ix,chan3
            ld a,$20                ; music voice: half swing
            ld (ml_m3+1),a
            ld (ml_m3n+1),a
            ld a,(music_on)
            or a
            ld a,(ix+CH_DUTY)
            jr nz,.ch3
            xor a
            jr .ch3
.sfx:       ld a,$21                ; sound effect: full swing, stands out over the music
            ld (ml_m3+1),a
            ld (ml_m3n+1),a
            ld ix,chsfx
            ld a,(ix+CH_DUTY)
.ch3:       ld (ml_d3+1),a
            ld (ml_d3n+1),a
            ld l,(ix+CH_STEP)
            ld h,(ix+CH_STEP+1)
            ld (ml_s3+1),hl
            ld hl,ml_tone
            bit 0,(ix+CH_FLAGS)
            jr z,.t
            ld hl,ml_noise
.t:         ld (ml_j3+1),hl
            ret

nz_mute:    ; A = duty; zero it if music off (flags from earlier 'or a' are lost, so re-test)
            push af
            ld a,(music_on)
            or a
            jr z,.off
            pop af
            ret
.off:       pop af
            xor a
            ret

; --- per channel tick (IX = channel) ---
ch_tick:
            ld a,(ix+CH_PTR+1)
            or a
            jr nz,.active
            ; inactive: decay to silence
            ld (ix+CH_DUTY),0
            ret
.active:
            ; envelope + slide
            bit 7,(ix+CH_FLAGS)
            jr z,.snd
            ld (ix+CH_DUTY),0
            jr .dok2
.snd:       ld a,(ix+CH_DUTY)
            sub (ix+CH_DECAY)
            jr c,.dmin
            cp (ix+CH_DMIN)
            jr nc,.dok
.dmin:      ld a,(ix+CH_DMIN)
.dok:       ld (ix+CH_DUTY),a
.dok2:
            ld a,(ix+CH_SLIDE)
            or (ix+CH_SLIDE+1)
            jr z,.ns
            ld l,(ix+CH_STEP)
            ld h,(ix+CH_STEP+1)
            ld e,(ix+CH_SLIDE)
            ld d,(ix+CH_SLIDE+1)
            add hl,de
            ld (ix+CH_STEP),l
            ld (ix+CH_STEP+1),h
.ns:
            dec (ix+CH_WAIT)
            ret nz
            ; fetch next events
            ld l,(ix+CH_PTR)
            ld h,(ix+CH_PTR+1)
.next:      ld a,(hl)
            inc hl
            cp $60
            jr c,.note
            cp $80
            jr c,.len
            cp $90
            jr c,.inst
            jr z,.slide
            cp $91
            jr z,.llen
            cp $F0
            jr z,.call
            cp $F1
            jr z,.ret
            cp $FE
            jr z,.jump
            ; $FF stop
            ld (ix+CH_PTR+1),0
            ld (ix+CH_DUTY),0
            ret
.len:       sub $5F
            ld (ix+CH_LEN),a
            jr .next
.llen:      ld a,(hl)
            inc hl
            ld (ix+CH_LEN),a
            jr .next
.inst:      and $0F
            push hl
            add a,a
            add a,a
            ld e,a
            ld d,0
            ld hl,instruments
            add hl,de
            ld a,(hl)
            ld (ix+CH_DSTART),a
            inc hl
            ld a,(hl)
            ld (ix+CH_DECAY),a
            inc hl
            ld a,(hl)
            ld (ix+CH_DMIN),a
            inc hl
            ld a,(hl)
            ld (ix+CH_FLAGS),a
            pop hl
            jr .next
.slide:     ld a,(hl)
            ld (ix+CH_SLIDE),a
            inc hl
            ld a,(hl)
            ld (ix+CH_SLIDE+1),a
            inc hl
            jr .next
.call:      ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (ix+CH_RET),l
            ld (ix+CH_RET+1),h
            ex de,hl
            jr .next
.ret:       ld l,(ix+CH_RET)
            ld h,(ix+CH_RET+1)
            jr .next
.jump:      ld e,(hl)
            inc hl
            ld d,(hl)
            ex de,hl
            jr .next
.note:      ld (ix+CH_PTR),l
            ld (ix+CH_PTR+1),h
            ld b,a
            ld a,(ix+CH_LEN)
            ld (ix+CH_WAIT),a
            ld a,b
            or a
            jr z,.rest
            ; step lookup
            add a,a
            ld e,a
            ld d,0
            ld hl,note_steps-2
            add hl,de
            ld a,(hl)
            ld (ix+CH_STEP),a
            inc hl
            ld a,(hl)
            ld (ix+CH_STEP+1),a
            ld a,(ix+CH_DSTART)
            ld (ix+CH_DUTY),a
            res 7,(ix+CH_FLAGS)
            ret
.rest:      ld (ix+CH_DUTY),0
            set 7,(ix+CH_FLAGS)
            ret
