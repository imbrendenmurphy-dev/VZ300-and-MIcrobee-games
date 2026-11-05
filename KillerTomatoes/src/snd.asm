; =====================================================================
;  snd.asm - 1-bit beeper. Tone is generated while waiting for vsync,
;  so music/sfx only use the frame's idle time (never slows the game).
;  In-game: one voice, pulse-width envelope (quiet, blippy notes).
;  Front-end: two voices (melody + bass) as narrow pulses.
; =====================================================================

; ---- frame_sync: dispatch on engine ----
frame_sync:
        ld a,(mus_kind)
        cp 2
        jp z,frame_sync2
; ---- one voice: snd_period = total period, snd_hi = high-phase length ----
        ld hl,LATCH
        ld a,(latch_val)
        and ~$21
        or $01
        ld e,a                  ; resting state: bit0=1 bit5=0
        ld a,(snd_period)
        or a
        jp z,.sil
        ld a,(snd_noise)
        or a
        jp nz,.noise
        ld a,(snd_hi)
        ld c,a                  ; high-phase length
        ld a,(snd_period)
        sub c
        jr z,.sil
        jr c,.sil
        ld d,a                  ; low-phase length
        ld b,d
.t1:    dec b
        jr nz,.t1n
        ld a,e
        xor $21
        ld e,a
        ld (hl),a
        rra
        ld b,d
        jr c,.t1n
        ld b,c
.t1n:   bit 7,(hl)
        jr z,.t1
.t2:    dec b
        jr nz,.t2n
        ld a,e
        xor $21
        ld e,a
        ld (hl),a
        rra
        ld b,d
        jr c,.t2n
        ld b,c
.t2n:   bit 7,(hl)
        jr nz,.t2
        jr .done
.sil:   bit 7,(hl)
        jr z,.sil
.s2:    bit 7,(hl)
        jr nz,.s2
        jr .done
.noise: ld a,(snd_period)
        ld c,a
        ld b,a
        ld d,a
.n1:    dec b
        jr nz,.n1n
        ld a,r
        xor d
        rlca
        ld d,a
        and c
        inc a
        ld b,a
        ld a,e
        xor $21
        ld e,a
        ld (hl),a
.n1n:   bit 7,(hl)
        jr z,.n1
.n2:    dec b
        jr nz,.n2n
        ld a,r
        xor d
        rlca
        ld d,a
        and c
        inc a
        ld b,a
        ld a,e
        xor $21
        ld e,a
        ld (hl),a
.n2n:   bit 7,(hl)
        jr nz,.n2
.done:  ld a,e
        and $21
        ld e,a
        ld a,(latch_val)
        and ~$21
        or e
        ld (latch_val),a
        ld hl,frame_cnt
        inc (hl)
        ret

; ---- two voices (front-end). B/C voice 1, D/IXH voice 2 (half rate), IYH/IYL widths ----
frame_sync2:
        ld hl,LATCH
        ld a,(latch_val)
        and ~$21
        or $01
        ld e,a
        ld a,(snd_period)       ; sfx override -> voice 1
        or a
        jr nz,.v1
        ld a,(mus_per)
.v1:    ld c,a
        ld b,a
        or a
        ld a,$21
        jr nz,$+3
        xor a
        ld (.x1+1),a
        ld (.y1+1),a
        ld a,(mus2_per)
        ld ixh,a
        ld d,a
        or a
        ld a,$21
        jr nz,$+3
        xor a
        ld (.x2+1),a
        ld (.y2+1),a
        ld a,(snd_period)
        or a
        ld a,(mus_env)
        jr z,.w
        ld a,10
.w:     add a,a
        add a,a
        inc a
        ld iyh,a                ; melody pulse width
        ld a,(mus_env)
        ld b,a
        add a,a
        add a,b
        add a,a
        inc a
        ld iyl,a                ; bass pulse width (wider = rounder)
        ld b,c
        inc b
        inc d
        ld a,c
        or a
        jr nz,$+4
        ld c,1
        ld a,ixh
        or a
        jr nz,$+5
        ld ixh,1
        xor a
        ex af,af'
.t:     dec b
        jr nz,.a
        ld b,c
        ld a,e
.x1:    xor $21
        ld (hl),a
        ld a,iyh
.d1:    dec a
        jr nz,.d1
        ld (hl),e
.a:     dec d
        jr nz,.b
        ld d,ixh
        ex af,af'
        xor 1
        jr z,.nb
        ex af,af'
        ld a,e
.x2:    xor $21
        ld (hl),a
        ld a,iyl
.d2:    dec a
        jr nz,.d2
        ld (hl),e
        jr .b
.nb:    ex af,af'
.b:     bit 7,(hl)
        jr z,.t
.t2:    dec b
        jr nz,.a2
        ld b,c
        ld a,e
.y1:    xor $21
        ld (hl),a
        ld a,iyh
.e1:    dec a
        jr nz,.e1
        ld (hl),e
.a2:    dec d
        jr nz,.b2
        ld d,ixh
        ex af,af'
        xor 1
        jr z,.nb2
        ex af,af'
        ld a,e
.y2:    xor $21
        ld (hl),a
        ld a,iyl
.e2:    dec a
        jr nz,.e2
        ld (hl),e
        jr .b2
.nb2:   ex af,af'
.b2:    bit 7,(hl)
        jr nz,.t2
        ld hl,frame_cnt
        inc (hl)
        ret

; ---- set latch (mode/css) keeping speaker bits ----
; A = new mode bits ($08 graphics | $10 css)
set_mode:
        ld b,a
        ld a,(latch_val)
        and $21
        or b
        ld (latch_val),a
        ld (LATCH),a
        ret

; ---- play_music: HL = melody, DE = bass (0 = none), A = engine (1 game, 2 front-end) ----
play_music:
        ld (mus_kind),a
        ld (mus_start),hl
        ld (mus_ptr),hl
        ld (mus2_start),de
        ld (mus2_ptr),de
        ld a,1
        ld (mus_timer),a
        ld (mus2_timer),a
        ld (mus_on),a
        xor a
        ld (mus_per),a
        ld (mus2_per),a
        ret
stop_music:
        xor a
        ld (mus_on),a
        ld (mus_per),a
        ld (mus2_per),a
        ret

; ---- play_sfx: HL = script (pairs period, frames|flags ; $FF end) ----
play_sfx:
        ld (sfx_ptr),hl
        ld a,1
        ld (sfx_timer),a
        ret

; ---- read one channel: HL = ptr var, returns A = period (via table DE), timer in (IX) ----
; channel record: ptr(2) start(2) timer(1) per(1)
chan_step:
        ld l,(ix+0)
        ld h,(ix+1)
        ld a,h
        or l
        ret z
.rd:    ld a,(hl)
        cp $FF
        jr nz,.nl
        ld l,(ix+2)
        ld h,(ix+3)
        jr .rd
.nl:    cp $FE
        jr nz,.nt
        xor a
        ld (ix+5),a
        ld (ix+4),255
        ret
.nt:    inc hl
        ld (ix+0),l
        ld (ix+1),h
        ld c,a
        rlca
        rlca
        rlca
        and 7
        ld hl,durtab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (ix+4),a
        ld a,c
        and $1F
        ex de,hl
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        ld (ix+5),a
        ret

; ---- sound_tick: once per frame ----
sound_tick:
        ld a,(mus_on)
        or a
        jp z,.sfx
        ; envelope decay (blippy)
        ld a,(frame_cnt)
        and 1
        jr nz,.nodec
        ld a,(mus_env)
        cp 2
        jr c,.nodec
        dec a
        ld (mus_env),a
.nodec: ld ix,mus_ptr
        dec (ix+4)
        jr nz,.c2
        ld de,notetab1
        ld a,(mus_kind)
        cp 2
        jr nz,$+5
        ld de,notetab2
        call chan_step
        ld a,(mus_kind)
        cp 2
        ld a,7
        jr nz,$+4
        ld a,9
        ld (mus_env),a
        ; articulation: silence last part of long notes via env floor
.c2:    ld a,(mus_kind)
        cp 2
        jr nz,.sfx
        ld ix,mus2_ptr
        ld a,(ix+0)
        or (ix+1)
        jr z,.sfx
        dec (ix+4)
        jr nz,.sfx
        ld de,notetab3
        call chan_step
        ; ---------- sfx ----------
.sfx:   ld a,(sfx_timer)
        or a
        jr z,.nosfx
        dec a
        ld (sfx_timer),a
        jr nz,.sfxrun
        ld hl,(sfx_ptr)
        ld a,(hl)
        cp $FF
        jr z,.sfxend
        ld (sfx_per),a
        inc hl
        ld a,(hl)
        inc hl
        ld (sfx_ptr),hl
        ld c,a
        and $3F
        ld (sfx_timer),a
        ld a,c
        and $C0
        ld (sfx_flags),a
        jr .sfxout
.sfxend: xor a
        ld (sfx_timer),a
        jr .nosfx
.sfxrun: ld a,(sfx_flags)
        bit 6,a
        jr z,.sfxout
        ld a,(sfx_per)
        add a,3
        ld (sfx_per),a
.sfxout: ld a,(sfx_flags)
        and $80
        ld (snd_noise),a
        ld a,(sfx_per)
        ld (snd_period),a
        srl a
        ld (snd_hi),a
        ld a,(mus_kind)         ; in 2-voice mode sfx frequency must use table 2 scale
        ret
.nosfx: xor a
        ld (snd_noise),a
        ld (snd_period),a
        ld a,(music_ok)
        or a
        jr nz,.mus
        ld (mus_per),a
        ld (mus2_per),a
        ret
.mus:   ld a,(mus_kind)
        cp 2
        ret z
        ld a,(mus_per)
        ld (snd_period),a
        ; hi = per * env / 16
        ld c,a
        ld a,(mus_env)
        ld b,a
        ld hl,0
        ld d,h
        ld e,c
.ml:    add hl,de
        djnz .ml
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        or a
        jr nz,$+3
        inc a
        ld (snd_hi),a
        ret

durtab: db 3,6,9,12,18,24,36,48

; ---- type_tick: delay a couple of frames with a click (typewriter text) ----
type_tick:
        ld a,(str_delay)
        ld b,a
.l:     push bc
        call sound_tick
        call frame_sync
        pop bc
        djnz .l
        ld hl,sfx_type
        jp play_sfx
