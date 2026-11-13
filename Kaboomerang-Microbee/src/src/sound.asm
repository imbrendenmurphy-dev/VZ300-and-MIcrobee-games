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
        dw 700,-60 : db 4,3,2,0      ; place: a soft thunk
        dw 9000,-300 : db 14,2,6,0      ; boom: noise falling away
        dw 14000,-400 : db 22,2,7,0      ; big boom (chains)
        dw 5000,-150 : db 8,2,4,0      ; crumble
        dw 1500,300 : db 10,1,5,0      ; pickup: rising sparkle
        dw 900,-50 : db 12,4,7,0      ; hurt
        dw 1800,250 : db 6,1,3,0      ; throw: whoosh up
        dw 3000,-200 : db 3,0,2,0      ; catch
        dw 1200,-150 : db 4,3,4,0      ; stun: bonk
        dw 3000,-250 : db 10,1,5,0      ; zap (enemy beaten)
        dw 6000,0 : db 2,2,1,0      ; fuse fizz (last second)
        dw 300,30 : db 4,3,1,0      ; croak
        dw 3600,-300 : db 5,1,2,0      ; squawk (frill-neck sees you)
        dw 2500,300 : db 6,1,3,0      ; steal (bin chicken)
        dw 300,0 : db 3,0,1,0      ; deny
        dw 2200,0 : db 2,0,1,0      ; menu tick
        dw 4000,-100 : db 6,2,3,0      ; dig
        ASSERT $-sfxtab == 17*8
