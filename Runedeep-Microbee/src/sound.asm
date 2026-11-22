; =====================================================================
;  SOUND: one speaker bit, no interrupts. Three voices take turns at the
;  speaker inside every sample, in the time each frame waits for the
;  vertical blanking (the game is turn-based, so that is most of the
;  frame):
;    MELODY  a pulse whose duty falls over the note (a soft attack and a
;            decay: quieter than the effects, so the music sits behind)
;    BASS    a plucked pulse ("dum", not "beep")
;    FX      effects and drums: a pulse with a gliding pitch, or noise
;  A sample is 214 T: 15 770 samples a second. No undocumented
;  instructions. Tunes and effects are tables (tools/mkmusic.py ->
;  build/snd.inc); snd_tick reads them once a frame.
; =====================================================================

snd_init:
        ld a,2
        ld (snd_mode),a
        ld a,$5A
        ld (lfsr),a
snd_quiet:
        xor a
        ld (sfx_on),a
        ld (mus_on),a
mute:   ld hl,0
        ld (gma+1),hl
        ld (gbs+1),hl
        ld (gfs+1),hl
        ld (sa_m),hl
        ld (sa_b),hl
        ld (sa_f),hl
        xor a
        ld (gmd+1),a
        ld (gbd+1),a
        ld (gfd+1),a
        ld hl,gft
        ld (gfj+1),hl
        ret

; T toggles: music and effects -> effects -> silence
snd_toggle:
        ld a,(snd_mode)
        dec a
        jp p,.s
        ld a,2
.s:     ld (snd_mode),a
        ld hl,t_snd_off
        or a
        jr z,.m
        ld hl,t_snd_fx
        dec a
        jr z,.m
        ld hl,t_snd_all
        push hl
        ld a,(level)
        call mus_level
        pop hl
.m:     jp log_msg

; wait for the start of the next vertical blanking, sounding the voices
snd_field:
        in a,(P_CRTCA)
        and $20
        jr z,.p2
        ld e,0
        call snd_until          ; the blanking we are in: let it end
.p2:    ld e,$20
        jp snd_until

; play until (6545 status AND 20h) = E
snd_until:
        ld a,e
        ld (gtg+1),a
        ld hl,(sa_f)
        exx
        ld hl,(sa_m)
        ld de,(sa_b)
        call gl
        ld (sa_m),hl
        ld (sa_b),de
        exx
        ld (sa_f),hl
        xor a
        out (P_PIOB),a
        ret

gl:     in a,(P_CRTCA)          ; 11
        and $20                 ; 7
gtg:    cp 0                    ; 7
        ret z                   ; 5
gma:    ld bc,0                 ; 10  MELODY: HL
        add hl,bc               ; 11
        ld a,h                  ; 4
gmd:    cp 0                    ; 7
        sbc a,a                 ; 4
        and $40                 ; 7
        out (P_PIOB),a          ; 11
gbs:    ld bc,0                 ; 10  BASS: DE
        ex de,hl                ; 4
        add hl,bc               ; 11
        ld a,h                  ; 4
        ex de,hl                ; 4
gbd:    cp 0                    ; 7
        sbc a,a                 ; 4
        and $40                 ; 7
        out (P_PIOB),a          ; 11
        exx                     ; 4   FX: HL'
gfs:    ld bc,0                 ; 10
        add hl,bc               ; 11
gfj:    jp gft                  ; 10
gft:    ld a,h                  ; 4
gfd:    cp 0                    ; 7
        sbc a,a                 ; 4
        and $40                 ; 7
        out (P_PIOB),a          ; 11
        exx                     ; 4
        jp gl                   ; 10  = 214 T
gfn:    ld a,l                  ; 4   noise: the low byte's bits tumble
        rlca                    ;     with an odd step
        xor h
gfnm:   and $40                 ;     (the mask sets the loudness)
        out (P_PIOB),a
        exx
        jp gl

; ---------------------------------------------------------------------
;  effects: HL = effect. A higher or equal priority replaces.
;  An effect: entries of (frames, duty (80h+: noise), step (dw),
;  glide per frame (dw)), 0 ends.
; ---------------------------------------------------------------------
sfx:    push af
        push bc
        ld a,(snd_mode)
        or a
        jr z,.no
        ld (sfx_ptr),hl
        xor a
        ld (sfx_left),a
        ld a,1
        ld (sfx_on),a
.no:    pop bc
        pop af
        ret

; HL = tune: it starts at the next tick
play_tune:
        ld a,(snd_mode)
        cp 2
        ret c
        ld (mus_hdr),hl
        ld a,2
        ld (mus_on),a
        ret

; A = level: its tune
mus_level:
        add a,a
        ld e,a
        ld d,0
        ld hl,level_tunes
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp play_tune

level_tunes: dw mus_l1, mus_l2, mus_l3, mus_l4

; ---------------------------------------------------------------------
;  once a frame: what the voices play while the next frame waits
; ---------------------------------------------------------------------
snd_tick:
        ld a,(snd_mode)
        or a
        jp z,mute
        call .music
        jp .fx
; the music: melody (channel 1), bass (2), drums (3)
.music: ld a,(mus_on)
        or a
        jr nz,.go
        ld hl,0
        ld (gma+1),hl
        ld (gbs+1),hl
        xor a
        ld (gmd+1),a
        ld (gbd+1),a
        ld (drum),a
        ret
.go:    cp 2
        call z,.start
        ld ix,mus_p1
        call chan
        jr nz,.mel
        ld hl,0
        ld (gma+1),hl
        xor a
        ld (gmd+1),a
        jr .bass
.mel:   call note_step
        ld (gma+1),hl
        ; the melody's duty: rises over 2 frames, then decays
        ld a,(ix+5)             ; age
        cp 2
        ld a,(mel_duty)
        jr nc,.dec
        srl a
        jr .md
.dec:   ld b,a
        ld a,(ix+5)
        sub 2
        add a,a
        ld c,a
        ld a,b
        sub c
        jr c,.lo
        cp 24
        jr nc,.md
.lo:    ld a,24
.md:    ld (gmd+1),a
.bass:  ld ix,mus_p2
        call chan
        jr nz,.bn
        ld hl,0
        ld (gbs+1),hl
        xor a
        ld (gbd+1),a
        jr .drums
.bn:    call note_step
        ld (gbs+1),hl
        ld a,(ix+5)
        cp 8
        jr c,.pa
        ld a,7
.pa:    ld hl,pluck
        call add_a_hl
        ld a,(hl)
        ld (gbd+1),a
.drums: ld ix,mus_p3
        call chan
        ret z
        ld b,a
        ld a,(ix+5)
        or a
        ret nz                  ; a drum starts with its note
        ld a,(sfx_on)
        or a
        ret nz                  ; an effect has the voice
        ld a,b
        dec a
        add a,a
        ld hl,drum_tab
        call add_a_hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (drum_ptr),hl
        ld a,1
        ld (drum),a
        ret
.start: ld hl,(mus_hdr)
        ld de,mus_p1
        call .ch
        ld de,mus_p2
        call .ch
        ld de,mus_p3
        call .ch
        ld a,(hl)
        ld (mel_duty),a
        ld a,1
        ld (mus_on),a
        ret
.ch:    ; channel record: ptr, loop, left, note, age
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ex de,hl
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld (hl),0
        ex de,hl
        ret
; effects (or a drum) on the third voice
.fx:    ld a,(sfx_on)
        or a
        jr nz,.sfx
        ld a,(drum)
        or a
        jr z,.fxoff
        ld hl,(drum_ptr)
        call fx_entry
        ld (drum_ptr),hl
        ret nz
        xor a
        ld (drum),a
.fxoff: ld hl,0
        ld (gfs+1),hl
        xor a
        ld (gfd+1),a
        ld hl,gft
        ld (gfj+1),hl
        ret
.sfx:   ld hl,(sfx_ptr)
        call fx_entry
        ld (sfx_ptr),hl
        ret nz
        xor a
        ld (sfx_on),a
        jr .fxoff

; HL = effect pointer: play its current entry one frame -> NZ while it
; lasts, HL moved on when an entry ends
fx_entry:
        ld a,(hl)
        or a
        ret z
        ld a,(sfx_left)
        or a
        jr nz,.held
        ; a new entry
        ld a,(hl)
        ld (sfx_left),a
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
        dec hl
        dec hl
        dec hl
        dec hl
        dec hl
        ld (fx_glide),de
        bit 7,a
        jr nz,.noise
        ld (gfd+1),a
        ld de,gft
        ld (gfj+1),de
        jr .held
.noise: and $7F
        ld (gfnm+1),a
        ld de,gfn
        ld (gfj+1),de
.held:  ; glide
        push hl
        ld hl,(gfs+1)
        ld de,(fx_glide)
        add hl,de
        ld (gfs+1),hl
        pop hl
        ld a,(sfx_left)
        dec a
        ld (sfx_left),a
        jr nz,.on
        ld de,6
        add hl,de
.on:    or 1
        ret

; a channel (IX: ptr, loop, left, note, age) -> NZ and A = the note
; sounding (Z: a rest or the end)
chan:   ld a,(ix+4)             ; frames left
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
.note:  ld (ix+6),a             ; the note
        inc hl
        ld a,(hl)
        inc hl
        ld (ix+4),a
        ld (ix+0),l
        ld (ix+1),h
        ld (ix+5),0             ; age
        jr .n
.held:  inc (ix+5)
.n:     dec (ix+4)
        ld a,(ix+4)
        or a
        jr nz,.sound
        ; the note's last frame: a short gap (articulation)
        xor a
        ret
.sound: ld a,(ix+6)
        or a
        ret

; A = note (1-based) -> HL = its step
note_step:
        add a,a
        ld hl,NOTETAB-2
        call add_a_hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; the bass's duty over a note's first frames
pluck:  db 112,84,64,52,44,38,34,30

mel_duty:   db 96
drum:       db 0
drum_ptr:   dw 0
sfx_left:   db 0
fx_glide:   dw 0
mus_p1x:

        INCLUDE "../build/snd.inc"
