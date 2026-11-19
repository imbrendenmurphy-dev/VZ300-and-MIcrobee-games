; =====================================================================
;  SOUND: 2-channel music sequencer + effects (engine from Ghost Hunter 2),
;  stepped once a field (50 Hz) from frame_end.
;  soundmode: 2 = music + effects, 1 = effects + jingles only, 0 = silent
;  SFX play over the bass channel while music runs, so tunes keep going.
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

; SFX: A = id. table: dw start, dw delta, db len, db mode, db prio, db 0
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
        ld (sfxprio),a
        inc hl
        ld a,(hl)
        ld (sfxrumble),a
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
        ret z
        dec a
        ld (sfxleft),a
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
        push hl                 ; noise: density = H + 0-15, varied each frame
        call random
        pop hl
        and $0F
        add a,h
        ld h,a
        ld (step2),hl
        ld a,1
        ld (noiseon),a
        ld a,(sfxrumble)        ; a blast only: under the crackle, a rumble that
        or a                    ; sinks as the noise dies away (the free channel)
        ret z
        ld a,(mplaying)
        or a
        ret nz
        ld a,(sfxleft)
        add a,a
        add a,a
        add a,100
        ld l,a
        ld h,0
        ld (step1),hl
        ret
.thump:                         ; a rough thud: random low byte of the pitch
        cp 2                    ; A = mode-2: 1 = thump, 2 = pop, 3 = chink
        jr z,.pop
        cp 4
        jr z,.voice
        cp 3
        jr nz,.thud
        ; chink: one field of a very high ping (its pitch a little different
        ; every time), one field of silence - too short to be a note
        ld a,(sfxleft)
        rra
        jr c,.ping
        ld hl,0
        jr .plain
.ping:  push hl
        call random
        pop hl
        and 15
        add a,h
        ld h,a
        jr .plain
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
.voice: ld a,(mplaying)         ; a cry: the falling pitch on one channel and
        or a                    ; its octave, a shade sharp, on the other
        jr nz,.plain
        ld (step1),hl
        add hl,hl
        ld de,23
        add hl,de
        ld (step2),hl
        ret
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

;  start, delta, len, mode, prio.  Modes: 0 plain tone, 1 warble, 2 noise
;  (high byte = how dense the crackle is), 3 thump (rough low pitch), 4 pop
;  (a crack, then a thump), 5 chink (very short high pings), 6 voice (a
;  falling cry in two octaves).
;  Nothing here is a held note: earth and blasts are noise, stone is a
;  crack and a thud, gems are chinks.
SFX_THUD equ 0
SFX_TINK equ 1
SFX_BOOM equ 2
SFX_CRUMBLE equ 3
SFX_MAGIC equ 4
SFX_WARD equ 5
SFX_DIG equ 6
SFX_PUSH equ 7
SFX_DOOR equ 8
SFX_KEY equ 9
SFX_BONUS equ 10
SFX_CHALICE equ 11
SFX_GEM equ 12
SFX_OPEN equ 13
SFX_APPEAR equ 14
SFX_TICK equ 15
SFX_MENU equ 16
SFX_DENY equ 17
SFX_COUNT equ 18
SFX_OWW equ 19
SFX_URN equ 20
SFX_COUNTDOWN equ 21
sfxtab:
        dw 420,-30 : db 5,4,3,0         ; thud: a stone lands - crack, then thump
        dw 11000,0 : db 2,5,2,0         ; tink: a gem lands - one chink
        dw $6800,-$0300 : db 34,2,8,1   ; boom: a roar that breaks up into crackle
        dw $3400,-$0400 : db 12,2,5,1   ; crumble: a cracked wall gives way
        dw 9500,0 : db 8,5,4,0          ; the grate: a run of chinks
        dw $0800,$0600 : db 8,2,7,0     ; a ward takes the blow: a rising rush
        dw $1C00,-$0700 : db 4,2,1,0    ; dig: a soft crunch of earth (pure hiss, no tone)
        dw 200,-12 : db 5,3,2,0         ; push: a stone shoved along - a low scrape
        dw 300,-10 : db 12,3,4,0        ; a door grinds open
        dw 12000,0 : db 4,5,5,0         ; key: chink-chink
        dw 10000,0 : db 10,5,6,0        ; charm: a chinkle
        dw 10500,0 : db 14,5,6,0        ; chalice: a long chinkle
        dw 10500,0 : db 4,5,4,0         ; gem: chink-chink
        dw 240,14 : db 30,3,9,0         ; the gate: stone grinding upward
        dw $2800,-$0400 : db 10,2,5,0   ; Mort appears: a puff of dust
        dw $5000,0 : db 1,2,3,0         ; time is short: a dry tick
        dw 11500,0 : db 2,5,1,0         ; menu: one chink
        dw 260,0 : db 4,3,1,0           ; deny: a dull knock
        dw 12500,0 : db 2,5,2,0         ; bonus count: chink
        dw 2300,-120 : db 16,6,9,0      ; "oww!": a yelp falling away (the blast follows)
        dw 10000,0 : db 8,5,5,0         ; an urn breaks open: a chinkle
        dw 700,-40 : db 7,3,9,0         ; the count before Mort gives up: a knock
        ASSERT $-sfxtab == 22*8
