; =====================================================================
; THE LANTERN DEEP - 1-bit sound engine (speaker on PIO B bit 6)
;
; The CPU has no sound chip and no spare timer, so sound is played in the
; time the game would otherwise spend waiting for vertical blanking: the
; wait loop *is* the tone generator. One count of the tone loop is 40
; T-states. Each frame plays one of: a pulse wave (hi / lo half counts -
; a narrow pulse is quieter and thinner, which gives 1-bit envelopes),
; noise (random half periods from the refresh register) or silence.
; =====================================================================

snd_type:   DB 0            ; 0 silence, 1 tone, 2 noise
snd_ph:     DB 0            ; tone: which half-wave is playing
snd_cnt:    DB 0            ;       and how much of it is left
snd_hi:     DB 0
snd_lo1:    DB 0
snd_lo2:    DB 0
snd_mask:   DB 0

; Play until the next rising edge of vertical blanking.
snd_wait:   in a,(P_CRTCA) : and $20 : ld d,a
            or a : jr z,.rise
            call play_until                 ; still in blanking: wait for it to end
            ld d,0
.rise:      jp play_until

; play the current sound until (status AND 20h) differs from D
play_until: ld a,(snd_type)
            dec a : jr z,.tone
            dec a : jr z,.noise
            xor a : out (P_PIOB),a : ld (snd_cnt),a
.s1:        in a,(P_CRTCA) : and $20 : cp d : jr z,.s1
            ret
.tone:      ; the wave carries on where the last frame left it, so the
            ; frame boundary makes no click
            ld a,(snd_ph) : ld c,a
            ld a,(snd_cnt) : ld b,a
            or a : jr z,.thi
            ld a,c : or a : jr z,.hi
            dec a : jr z,.lo1
            jr .lo2
.thi:       ld a,(snd_hi) : ld b,a
.hi:        ld a,$40 : out (P_PIOB),a
            ld c,0
.t1:        in a,(P_CRTCA) : and $20 : cp d : jr nz,.save : djnz .t1
            ld a,(snd_lo1) : ld b,a
.lo1:       xor a : out (P_PIOB),a
            ld c,1
.t2:        in a,(P_CRTCA) : and $20 : cp d : jr nz,.save : djnz .t2
            ld a,(snd_lo2) : or a : jr z,.thi
            ld b,a
.lo2:       ld c,2
.t3:        in a,(P_CRTCA) : and $20 : cp d : jr nz,.save : djnz .t3
            jr .thi
.save:      ld a,b : ld (snd_cnt),a
            ld a,c : ld (snd_ph),a
            ret
.noise:     xor a : ld (snd_cnt),a
            ld a,(snd_mask) : ld c,a
            ld e,0
.n0:        ld a,e : xor $40 : ld e,a : out (P_PIOB),a
            ld a,r : and c : inc a : ld b,a
.n1:        in a,(P_CRTCA) : and $20 : cp d : ret nz : djnz .n1
            jr .n0

; ---------------------------------------------------------------------
; Per-frame sequencing (called with the number of frames elapsed in dt)
; ---------------------------------------------------------------------
; the sequencer steps once for every frame that has passed
snd_update: ld a,(frames) : ld hl,snd_seq : sub (hl) : ret z
            cp 5 : jr c,.k
            ld a,4
.k:         ld b,a
.l:         push bc
            call snd_frame
            pop bc
            djnz .l
            ld a,(frames) : ld (snd_seq),a
            ret
snd_seq:    DB 0

; Called when a frame passes in the middle of long work (a relight, a
; redraw): step the music and play a short, fixed-length burst of it, so
; the tune keeps flowing instead of stopping for several frames.
snd_tick:   push bc : push de : push ix : push iy
            call snd_frame
            ld a,(frames) : ld (snd_seq),a
            ld a,(snd_type) : cp 1 : call z,snd_slice
            pop iy : pop ix : pop de : pop bc
            ret

; the tone generator again, for 255 counts (about 10,700 T-states) instead
; of until vertical blanking; same 42 T-states per count, same pitch
snd_slice:  ld e,0
            ld a,(snd_ph) : ld c,a
            ld a,(snd_cnt) : ld b,a
            or a : jr z,.thi
            ld a,c : or a : jr z,.hi
            dec a : jr z,.lo1
            jr .lo2
.thi:       ld a,(snd_hi) : ld b,a
.hi:        ld a,$40 : out (P_PIOB),a
            ld c,0
.t1:        dec e : jr z,.save : ld a,(hl) : ld a,(hl) : nop : djnz .t1
            ld a,(snd_lo1) : ld b,a
.lo1:       xor a : out (P_PIOB),a
            ld c,1
.t2:        dec e : jr z,.save : ld a,(hl) : ld a,(hl) : nop : djnz .t2
            ld a,(snd_lo2) : or a : jr z,.thi
            ld b,a
.lo2:       ld c,2
.t3:        dec e : jr z,.save : ld a,(hl) : ld a,(hl) : nop : djnz .t3
            jr .thi
.save:      ld a,b : ld (snd_cnt),a
            ld a,c : ld (snd_ph),a
            ret

snd_frame:  ld hl,snd_fc : inc (hl)
            ld ix,chan_a : call chan_step
            ld ix,chan_b : call chan_step
            ; sound effect?
            ld hl,(sfx_ptr)
            ld a,h : or l : jr z,.mus
            ld a,(hl) : or a : jr z,.sfxend
            cp 3 : jr nz,.s1
            xor a                           ; silence frame
.s1:        ld (snd_type),a
            inc hl
            ld a,(hl) : ld (snd_hi),a : ld (snd_mask),a : inc hl
            ld a,(hl) : ld (snd_lo1),a : inc hl
            ld a,(hl) : ld (snd_lo2),a : inc hl
            ld (sfx_ptr),hl
            ret
.sfxend:    ld hl,0 : ld (sfx_ptr),hl
.mus:       ld a,(mus_on) : or a : jr z,.quiet
            ; one voice: the melody; the accompaniment only fills its rests
            ld ix,chan_a
            ld a,(ix+CH_N) : or (ix+CH_N+1) : jr nz,.play
            ld ix,chan_b
            ld a,(ix+CH_N) : or (ix+CH_N+1) : jr nz,.play
.quiet:     xor a : ld (snd_type),a
            ret
.play:      ; a note ends with a breath of silence
            ld a,(ix+CH_TIMER) : cp 2 : jr c,.quiet
            ; square wave for the body, a little narrower as it fades
            ld a,(ix+CH_ENV) : cp 24 : ld a,0 : jr c,.e
            inc a
.e:         ld b,a : ld a,(mus_vol) : add a,b : ld b,a
            ld l,(ix+CH_N) : ld h,(ix+CH_N+1)
            push hl
            inc b
            jr .sh1
.sh:        srl h : rr l
.sh1:       djnz .sh
            ld a,h : or a : jr z,.h1
            ld l,255
.h1:        ld a,l : cp 2 : jr nc,.h2
            ld l,2
.h2:        ld a,l : ld (snd_hi),a
            ; lo = 2n - hi, split into two loops of at most 255
            pop de
            ex de,hl : add hl,hl
            ld e,a : ld d,0
            or a : sbc hl,de
            ld a,h : or a : jr nz,.big
            ld a,l : ld (snd_lo1),a
            xor a : ld (snd_lo2),a
            jr .done
.big:       ld a,255 : ld (snd_lo1),a
            ld de,255 : or a : sbc hl,de
            ld a,l : ld (snd_lo2),a
.done:      ld a,1 : ld (snd_type),a
            ret

; IX = channel: advance one frame
CH_PTR      EQU 0
CH_START    EQU 2
CH_TIMER    EQU 4
CH_N        EQU 5
CH_ENV      EQU 7
chan_step:  ld a,(ix+CH_ENV) : inc a : jr z,.t
            ld (ix+CH_ENV),a
.t:         dec (ix+CH_TIMER)
            ret nz
            ld l,(ix+CH_PTR) : ld h,(ix+CH_PTR+1)
            ld a,h : or l : ret z
            ld a,(hl) : or a : jr nz,.ev
            ld l,(ix+CH_START) : ld h,(ix+CH_START+1)       ; loop
            ld a,(hl)
.ev:        ld (ix+CH_TIMER),a
            inc hl
            ld a,(hl) : inc hl
            ld (ix+CH_PTR),l : ld (ix+CH_PTR+1),h
            add a,a : ld e,a : ld d,0
            ld hl,NOTE_TAB : add hl,de
            ld a,(hl) : ld (ix+CH_N),a
            inc hl
            ld a,(hl) : ld (ix+CH_N+1),a
            ld (ix+CH_ENV),0
            ret

chan_a:     DW 0,0
            DB 1
            DW 0
            DB 0
chan_b:     DW 0,0
            DB 1
            DW 0
            DB 0
snd_fc:     DB 0
sfx_ptr:    DW 0
mus_on:     DB 0
mus_vol:    DB 0

; HL = channel A data, DE = channel B data, A = volume (0 loud .. 2 soft)
music_start:
            ld (mus_vol),a
            xor a
            ld (chan_a+CH_N),a : ld (chan_a+CH_N+1),a
            ld (chan_b+CH_N),a : ld (chan_b+CH_N+1),a
            ld (chan_a+CH_PTR),hl : ld (chan_a+CH_START),hl
            ld (chan_b+CH_PTR),de : ld (chan_b+CH_START),de
            ld a,1 : ld (chan_a+CH_TIMER),a : ld (chan_b+CH_TIMER),a
            ld (mus_on),a
            ret

music_stop: xor a : ld (mus_on),a
            ret

; A = effect number
sfx:        push hl : push de
            add a,a : ld e,a : ld d,0
            ld hl,SFX_TAB : add hl,de
            ld a,(hl) : inc hl : ld h,(hl) : ld l,a
            ld (sfx_ptr),hl
            pop de : pop hl
            ret
