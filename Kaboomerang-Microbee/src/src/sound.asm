; =====================================================================
;  sound: 2-channel music sequencer (title tune, jingles) + SFX.
;  In play there is no music: the bombs do the talking - a fizzing fuse
;  hiss while any bomb is lit, a deep held-noise KABOOM with a thump under
;  it, and a bright two-note ching for pickups.
; =====================================================================
play_music:     ; HL = channel 0 data, DE = channel 1 data
        ld a,(musicon)
        or a
        ret z
        ld (mptr0),hl
        ld (mbase0),hl
        ld (mptr1),de
        ld (mbase1),de
        xor a
        ld (mleft0),a
        ld (mleft1),a
        ld (mfin0),a
        ld (mfin1),a
        ld a,1
        ld (mplaying),a
        ret
stop_music:
        xor a
        ld (mplaying),a
        ld hl,0
        ld (mstep0),hl
        ld (mstep1),hl
        ret
; has the current tune finished?  Z = still playing
music_busy:
        ld a,(mplaying)
        or a
        ret

; SFX: A = id. table: dw start, dw delta, db len, db mode, db prio, db rate
; (noise: start/delta high byte = density, noise step = (left + 2) x rate)
play_sfx:                       ; keeps BC, DE, HL
        push hl
        push de
        push bc
        call .p
        pop bc
        pop de
        pop hl
        ret
.p:     ld l,a
        ld a,(sfxon)
        or a
        ret z
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,sfxtab
        add hl,de
        ld a,(sfxleft)
        or a
        jr z,.go
        ld a,(sfxprio)
        push hl
        ld de,6
        add hl,de
        cp (hl)
        pop hl
        jr z,.go
        ret nc
.go:    ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (sfxstep),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (sfxdelta),de
        ld a,(hl)
        inc hl
        ld (sfxleft),a
        ld a,(hl)
        inc hl
        ld (sfxmode),a
        ld a,(hl)
        inc hl
        ld (sfxprio),a
        ld a,(hl)
        ld (sfxrate),a
        ; the big moments get a burst: the game holds still for a few
        ; fields while the beeper plays them unbroken (a hit-pause)
        ld a,(sfxmode)
        cp 5
        jr z,.bc
        cp 2
        ret nz
        ld a,(sfxprio)
        cp 6
        ret c
        sub 2                   ; KABOOM 4 fields, chain boom 5
        jr .bs
.bc:    ld a,(sfxprio)          ; the pickup ching: all of it
        cp 5
        ret c
        ld a,(sfxleft)
.bs:    ld hl,burst
        cp (hl)
        ret c
        ld (hl),a
        ret

; frame_end, after the page flip: play a burst (A fields) unbroken
sfx_burst:
        ld b,a
        xor a
        ld (burst),a
.l:     push bc
        xor a
        ld (vcount),a
        call sound_tick
        ld a,1
        call frame_wait
        pop bc
        djnz .l
        xor a
        ld (vcount),a
        ret

mus_chan:
        ld a,(ix+4)
        or a
        jr nz,.cont
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
.stop:  ld (ix+5),0
        ld (ix+6),0
        ld (ix+7),1
        ret
.note:  inc hl
        ld b,(hl)
        inc hl
        ld (ix+0),l
        ld (ix+1),h
        ld (ix+4),b
        add a,a
        ld l,a
        ld h,0
        ld de,notetab
        add hl,de
        ld a,(hl)
        ld (ix+5),a
        inc hl
        ld a,(hl)
        ld (ix+6),a
        ld (ix+7),0
.cont:  dec (ix+4)
        ld a,(ix+4)
        cp 1                    ; articulation: last frame of a note is silent
        ret nc
        ld (ix+5),0
        ld (ix+6),0
        ret

sound_tick:
        xor a
        ld (noiseon),a
        ld a,(musicon)
        ld b,a
        ld a,(sfxon)
        or b
        jr nz,.on
        ld (sfxpend),a
        ld hl,0
        ld (step1),hl
        ld (step2),hl
        ret
.on:    ld hl,0
        ld (step1),hl
        ld (step2),hl
        ; a crowd sound waits until the effect channel is free
        ld a,(sfxleft)
        or a
        jr nz,.nopend
        ld a,(sfxpend)
        or a
        jr z,.nopend
        call play_sfx
        xor a
        ld (sfxpend),a
.nopend:
        ld a,(mplaying)
        or a
        jr z,.sfx
        ld ix,mptr0
        call mus_chan
        ld ix,mptr1
        call mus_chan
        ld a,(mfin0)
        ld b,a
        ld a,(mfin1)
        and b
        jr z,.mus_ok
        xor a
        ld (mplaying),a
.mus_ok:
        ld hl,(mstep0)
        ld (step1),hl
        ld hl,(mstep1)
        ld (step2),hl
.sfx:   ld a,(sfxleft)
        or a
        jp z,fuse_hiss
        dec a
        ld (sfxleft),a
        ld a,(sfxmode)
        cp 5
        jr z,.ching
        ld hl,(sfxstep)
        ld de,(sfxdelta)
        add hl,de
        ld (sfxstep),hl
        ld a,(sfxmode)
        or a
        jp z,.plain
        dec a
        jr z,.warble
        dec a
        jr nz,.thump
        ; noise: H = density; the step slows as it dies away (deeper)
        ld a,h
        ld (ndens),a
        ld a,(sfxleft)
        add a,2
        ld b,a
        ld a,(sfxrate)
        ld e,a
        ld d,0
        ld hl,0
.mul:   add hl,de
        djnz .mul
        ld (nrate),hl
        ld a,1
        ld (noiseon),a
        ld a,(mplaying)
        or a
        ret nz
        ld a,(sfxprio)
        cp 6
        ret c
        ld a,(sfxleft)          ; a kaboom: a low falling thump under the roar
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,40
        add hl,de
        ld (step1),hl
        ret
.ching: ld a,(sfxleft)          ; two bright notes, the second shimmering out
        ld hl,(sfxstep)
        cp 5
        jr nc,.plain
        ld hl,(sfxdelta)
        cp 3
        jr nc,.plain
        and 1
        jr z,.plain
        add hl,hl               ; an octave sparkle at the tail
        jr .plain
.thump:                         ; woody racket thud: rough low byte of the pitch
        cp 2                    ; A = mode-2: 1 = thump, 2 = pop
        jr z,.pop
.thud:  push hl
        call random
        pop hl
        ld l,a
        jr .plain
.pop:                           ; smash: two frames of a dense noise crack, then the thud
        ld a,(sfxleft)
        cp 4                    ; first two frames (5 and 4 left)
        jr c,.thud
        call random
        and $3F
        add a,$18               ; pulses at roughly 3-10 kHz: a sharp, loud crack
        push af
        call random
        pop hl                  ; H = crack pitch
        ld l,a
        jr .plain
.warble:
        ld a,(sfxleft)
        and 2
        jr z,.plain
        add hl,hl
.plain: ld a,(mplaying)
        or a
        jr nz,.ch2
        ld (step1),hl
        ret
.ch2:   ld (step2),hl
        ret

;  start, delta, len, mode (0 plain, 1 warble, 2 noise: high byte = density, 3 thump, 4 pop,
;  5 ching: start then delta, 2 + rest frames), prio, noise rate
SFX_PLACE equ 0
SFX_BOOM equ 1
SFX_BIGBOOM equ 2
SFX_CRUMBLE equ 3
SFX_PICKUP equ 4
SFX_HURT equ 5
SFX_THROW equ 6
SFX_CATCH equ 7
SFX_STUN equ 8
SFX_ZAP equ 9
SFX_FIZZ equ 10
SFX_CROAK equ 11
SFX_SQUAWK equ 12
SFX_STEAL equ 13
SFX_DENY equ 14
SFX_MENU equ 15
SFX_DIG equ 16
sfxtab:
        dw 700,-60 : db 4,3,2,0        ; place: a soft thunk
        dw $8000,-$0600 : db 20,2,6,2  ; KABOOM: full roar, deepening, dying away
        dw $8000,-$0400 : db 30,2,7,1  ; big boom (chains): longer, deeper
        dw $5000,-$0800 : db 8,2,4,24  ; crumble: a crunchy rattle
        dw 6497,9734 : db 7,5,5,0      ; pickup: CHING (E7 then B7)
        dw 900,-50 : db 12,4,5,0       ; hurt (under a kaboom)
        dw 1800,250 : db 6,1,3,0       ; throw: whoosh up
        dw 7726,11577 : db 7,5,2,0     ; catch: a little ching (G7, D8)
        dw 1200,-150 : db 4,3,4,0      ; stun: bonk
        dw 3000,-250 : db 10,1,5,0     ; zap (enemy beaten)
        dw $3000,0 : db 2,2,1,64       ; fuse spit (the last second)
        dw 300,30 : db 4,3,1,0         ; croak
        dw 3600,-300 : db 5,1,2,0      ; squawk (frill-neck sees you)
        dw 2500,300 : db 6,1,3,0       ; steal (bin chicken)
        dw 300,0 : db 3,0,1,0          ; deny
        dw 2200,0 : db 2,0,1,0         ; menu tick
        dw $3000,-$0400 : db 6,2,3,20  ; dig
        ASSERT $-sfxtab == 17*8

; no effect playing: a fizzing hiss while any bomb is lit, sharper and
; spitting in a bomb's last second
fuse_hiss:
        ld a,(sfxon)
        or a
        ret z
        ld a,(mplaying)
        or a
        ret nz
        ld ix,bombs
        ld b,NBOMB
        ld c,0
.b:     ld a,(ix+B_ON)
        or a
        jr z,.n
        ld a,c
        or a
        jr nz,$+3
        inc c                   ; lit
        ld a,(ix+B_FUSE)
        cp WARN
        jr nc,.n
        ld c,2                  ; warned
.n:     ld de,BSZ
        add ix,de
        djnz .b
        ld a,c
        or a
        ret z
        dec a
        jr nz,.w
        call random
        and 3
        add a,6
        ld hl,$0100             ; fine hiss
        jr .set
.w:     call random
        and 15
        add a,14
        ld hl,$00E0
.set:   ld (ndens),a
        ld (nrate),hl
        ld a,1
        ld (noiseon),a
        ret
