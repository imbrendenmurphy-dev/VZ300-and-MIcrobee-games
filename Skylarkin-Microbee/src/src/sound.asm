; =====================================================================
;  sound: 2-channel music sequencer + SFX (engine from Ghost Hunter 2)
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
        jr z,.plain
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
        ret
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

;  start, delta, len, mode (0 plain, 1 warble, 2 noise: high byte = density, 3 thump, 4 pop), prio
SFX_SHOT    equ 0
SFX_TINK    equ 1
SFX_POP     equ 2
SFX_BOOM    equ 3
SFX_CAPSULE equ 4
SFX_POWER   equ 5
SFX_DENY    equ 6
SFX_HURT    equ 7
SFX_DIE     equ 8
SFX_SHIELD  equ 9
SFX_DING    equ 10
SFX_DONG    equ 11
SFX_BELLGET equ 12
SFX_BONK    equ 13
SFX_OI      equ 14
SFX_LIFE    equ 15
SFX_SNAP    equ 16
SFX_GULP    equ 17
SFX_CRUMPLE equ 18
SFX_ALARM   equ 19
SFX_SPIT    equ 20
SFX_JAM     equ 21
SFX_BEAM    equ 22
SFX_BOSSHIT equ 23
SFX_MENU    equ 24
SFX_SQUAWK  equ 25
SFX_SIZZLE  equ 26
SFX_HISS    equ 27
SFX_CLACK   equ 28
SFX_HONK    equ 29
SFX_STAMP   equ 30
SFX_NOTE    equ 31
sfxtab:
        dw 2600,-260 : db 2,0,1,0       ; shot: a short pew
        dw 3800,0 : db 1,0,1,0          ; tink: hit, not dead
        dw 5000,-300 : db 6,2,3,0       ; pop: an enemy goes
        dw 9000,-300 : db 14,2,5,0      ; boom
        dw 1200,240 : db 8,1,4,0        ; capsule: rising blip
        dw 900,180 : db 14,1,6,0        ; power up: a big rising warble
        dw 300,0 : db 4,0,3,0           ; deny
        dw 1400,-80 : db 10,4,7,0       ; hurt
        dw 14000,-400 : db 25,2,8,0     ; the pilot goes up
        dw 4000,-200 : db 6,1,6,0       ; shield takes it
        dw 5200,0 : db 3,0,3,0          ; ding (bell)
        dw 3000,-40 : db 8,1,4,0        ; dong: the bell changes colour
        dw 2000,200 : db 12,1,6,0       ; bell caught
        dw 700,-40 : db 4,3,4,0         ; bonk!
        dw 400,60 : db 18,1,7,0         ; OI!
        dw 1500,150 : db 20,1,7,0       ; extra life
        dw 2400,-600 : db 3,0,2,0       ; snap (stapler)
        dw 500,-30 : db 6,3,4,0         ; gulp (the copier swallows)
        dw 6000,-200 : db 5,2,3,0       ; crumple
        dw 2400,0 : db 4,1,6,0          ; alarm (warning light)
        dw 1800,-100 : db 3,0,2,0       ; spit (paper out)
        dw 600,0 : db 20,3,7,0          ; jam: grinding
        dw 7000,0 : db 4,2,5,0          ; toner beam: hiss
        dw 1000,-100 : db 3,3,3,0       ; boss hit
        dw 2200,0 : db 2,0,1,0          ; menu tick
        dw 4200,-350 : db 6,1,5,0       ; squawk (a seagull: MINE!)
        dw 9000,0 : db 6,2,2,0          ; sizzle
        dw 12000,-150 : db 10,2,4,0     ; gas hiss
        dw 3500,0 : db 2,3,5,0          ; clack (tongs)
        dw 600,20 : db 10,0,5,0         ; honk (road train)
        dw 500,-20 : db 8,3,7,0         ; stamp: THUD
        dw 3000,0 : db 4,0,2,0          ; a note (pub rock)
        ASSERT $-sfxtab == 32*8
