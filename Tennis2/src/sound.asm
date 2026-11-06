; =====================================================================
;  sound: 2-channel music sequencer + SFX (engine from Ghost Hunter 2)
;  soundmode: 2 = music + effects, 1 = effects + jingles only, 0 = silent
;  SFX play over the bass channel while music runs, so tunes keep going.
; =====================================================================
play_music:     ; HL = channel 0 data, DE = channel 1 data
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
play_sfx:
        ld l,a
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
        ld a,(soundmode)
        or a
        jr nz,.on
        ld hl,0
        ld (step1),hl
        ld (step2),hl
        ret
.on:    ld hl,0
        ld (step1),hl
        ld (step2),hl
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
        jr z,.plain
        dec a
        jr z,.warble
        dec a
        jr nz,.thump
        push hl
        call random
        pop hl
        and $3F
        add a,h
        ld h,a
        call random
        ld l,a
        jr .plain
.thump:                         ; woody racket thud: rough low byte of the pitch
        push hl
        call random
        pop hl
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

;  start, delta, len, mode (0 plain, 1 warble, 2 noise, 3 thump), prio
SFX_HIT    equ 0
SFX_POWER  equ 1
SFX_BOUNCE equ 2
SFX_NET    equ 3
SFX_OUT    equ 4
SFX_TOSS   equ 5
SFX_CROWD  equ 6
SFX_BLIP   equ 7
SFX_SELECT equ 8
SFX_FAULT  equ 9
SFX_SMASH  equ 10
SFX_TICK   equ 11
SFX_CONE   equ 12
SFX_FEED   equ 13
SFX_SERVE  equ 14
SFX_CORD   equ 15
SFX_CLAP   equ 16
sfxtab:
        dw 1150,-260 : db 3,3,3,0,0       ; racket "thunk" (~380 -> 160 Hz, 60 ms)
        dw 1400,-280 : db 4,3,4,0,0       ; power drive: deeper, fuller thunk (80 ms)
        dw 700,-40   : db 3,0,2,0,0       ; bounce
        dw 260,-8    : db 8,2,4,0,0       ; into the net
        dw 1700,0    : db 14,1,5,0,0      ; line judge "OUT!"
        dw 500,90    : db 6,0,1,0,0       ; toss
        dw 1400,0    : db 34,2,1,0,0      ; crowd roar
        dw 1500,-90  : db 3,0,2,0,0       ; menu blip
        dw 900,160   : db 8,0,3,0,0       ; select
        dw 600,-25   : db 10,0,4,0,0      ; fault
        dw 1750,-300 : db 5,3,5,0,0       ; smash: the biggest thump (100 ms)
        dw 2300,0    : db 2,0,1,0,0       ; tick
        dw 800,140   : db 16,1,5,0,0      ; target hit
        dw 300,50    : db 6,2,2,0,0       ; ball machine
        dw 1300,-270 : db 4,3,4,0,0       ; serve thunk
        dw 900,-120  : db 4,3,4,0,0       ; net cord: a dull clip on the tape
        dw 2600,0    : db 9,2,1,0,0       ; applause
