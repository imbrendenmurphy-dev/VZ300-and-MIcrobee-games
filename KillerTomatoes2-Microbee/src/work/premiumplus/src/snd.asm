; Microbee PIO B6, dual 16-bit phase accumulators during PAL idle time.
; Main synthesis loop: 234 T-states on the no-edge path at 3.375 MHz.
frame_sync:
        call video_upload
        ld a,(mus2_per)
        call sound_step
        ld hl,(phase_bass)
        exx
        ld a,(mus_per)
        ld c,a
        ld a,(sfx_timer)
        or a
        jr z,.music
        ld a,(sfx_per)
        ld l,a
        ld h,0
        ld de,effect_steps
        add hl,de
        ld c,(hl)
.music: ld a,(music_ok)
        or a
        ld a,c
        jr nz,.enabled
        xor a
.enabled:
        call sound_step
        ld hl,(phase_melody)
.high:  add hl,de
        ld a,h
        rrca
        and $40
        ld b,a
        exx
        add hl,de
        ld a,h
        rrca
        and $40
        exx
        xor b
        out ($02),a
        call hw_clock
        ; Use the vblank state hw_clock just recorded, not a fresh port read:
        ; otherwise a vblank starting between the two is counted again next frame.
        ld a,(hw_vblank)
        or a
        jr z,.high
        ld a,(hw_pending)
        or a
        jr z,.high
        ld (logic_steps),a
        xor a
        ld (hw_pending),a
        out ($02),a
        ld (phase_melody),hl
        exx
        ld (phase_bass),hl
        exx
        ld hl,frame_cnt
        inc (hl)
        jp video_present
sound_step:
        ld l,a
        ld h,0
        REPT 5
        add hl,hl
        ENDR
        ex de,hl
        ret
effect_steps:
 db 0,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
 db 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
 db 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
 db 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
 db 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
 db 128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128
 db 128,128,126,125,124,122,122,120,119,118,117,116,114,114,112,112
 db 110,110,109,108,107,106,105,104,104,102,102,101,100,100,98,98
 db 97,96,96,95,94,94,93,92,92,90,90,90,89,88,88,87
 db 86,86,85,84,84,84,83,82,82,82,81,80,80,80,79,78
 db 78,78,77,76,76,76,75,74,74,74,74,73,72,72,72,71
 db 71,70,70,70,70,69,68,68,68,68,67,66,66,66,66,66
 db 65,64,64,64,64,64,63,62,62,62,62,62,61,61,60,60
 db 60,60,60,59,59,58,58,58,58,58,58,57,57,56,56,56
 db 56,56,56,55,55,54,54,54,54,54,54,53,53,52,52,52
 db 52,52,52,52,51,51,51,50,50,50,50,50,50,50,49,49
set_mode:
        ld (latch_val),a
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

