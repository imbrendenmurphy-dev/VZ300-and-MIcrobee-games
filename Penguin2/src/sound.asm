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
; in-game loop music (only in soundmode 2)
game_music:
        ld a,(soundmode)
        cp 2
        jr nz,stop_music
        ld a,(hurry)
        or a
        jr nz,.h
        ld hl,mus_game_0
        ld de,mus_game_1
        jr play_music
.h:     ld hl,mus_hurry_0
        ld de,mus_hurry_1
        jr play_music
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
        push hl
        call random
        pop hl
        and $3F
        add a,h
        ld h,a
        call random
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

SFX_PUSH   equ 0
SFX_SLIDE  equ 1
SFX_CRUMBLE equ 2
SFX_CRUSH  equ 3
SFX_KICK   equ 4
SFX_EGG    equ 5
SFX_SHAKE  equ 6
SFX_ITEM   equ 7
SFX_GET    equ 8
SFX_FREEZE equ 9
SFX_HATCH  equ 10
SFX_TICK   equ 11
SFX_THUD   equ 12
SFX_CLUNK  equ 13
SFX_POP    equ 14
SFX_MUNCH  equ 15
sfxtab:
        ; start, delta, len, mode, prio, pad
        dw 600,-30   : db 3,0,2,0,0       ; push
        dw 2400,-110 : db 12,0,2,0,0      ; slide whoosh
        dw 200,0     : db 10,2,3,0,0      ; crumble (noise)
        dw 1600,-90  : db 18,1,6,0,0      ; crush
        dw 900,160   : db 8,0,4,0,0       ; kick
        dw 300,40    : db 14,2,5,0,0      ; egg smash
        dw 60,0      : db 16,2,4,0,0      ; wall shake rumble
        dw 1400,120  : db 10,1,3,0,0      ; item appears
        dw 800,140   : db 16,1,5,0,0      ; item collected
        dw 3400,-180 : db 16,1,5,0,0      ; freeze
        dw 500,60    : db 14,1,2,0,0      ; hatch
        dw 2300,0    : db 2,0,1,0,0       ; tick
        dw 420,-20   : db 4,0,2,0,0       ; block stops
        dw 260,0     : db 4,2,2,0,0       ; clunk (won't break)
        dw 1500,-90  : db 6,0,2,0,0       ; pop / menu blip
        dw 180,30    : db 5,2,1,0,0       ; munch
