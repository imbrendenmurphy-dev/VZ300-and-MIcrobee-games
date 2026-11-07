; =====================================================================
;  sound: music sequencer (2 channels) + SFX + in-game siren
; =====================================================================
; music channel state: ptr, frames left, current step
play_music:     ; HL = channel 0 data, DE = channel 1 data
        ld (mptr0),hl
        ld (mbase0),hl
        ld (mptr1),de
        ld (mbase1),de
        xor a
        ld (mleft0),a
        ld (mleft1),a
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
        ret nc                  ; current higher priority -> ignore
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

; advance one music channel. IX -> state block (ptr,base,left,step)
mus_chan:
        ld a,(ix+4)             ; frames left
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
        ld (ix+7),1             ; finished flag
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
        cp 1                    ; articulation: silence on last frame
        ret nc
        ld (ix+5),0
        ld (ix+6),0
        ret

sound_tick:
        ld a,(soundon)
        or a
        jr nz,.on
        ld hl,0
        ld (step1),hl
        ld (step2),hl
        ret
.on:    ; music
        ld a,(mplaying)
        or a
        jr z,.nomus
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
        jr .sfx
.nomus: ld hl,0
        ld (step1),hl
        call siren
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
        ; mode 2: noise - random step
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
.plain: ld (step1),hl
        ret

; background siren on channel 2 (only during play)
siren:
        ld hl,0
        ld (step2),hl
        ld a,(sirenmode)
        or a
        ret z
        dec a
        jr z,.normal
        dec a
        jr z,.fright
        ; 3: eyes returning - fast high
        ld a,(framecount)
        and 7
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,6
        ld (step2),hl
        ret
.fright:
        ld a,(framecount)
        and 15
        cp 8
        jr c,.f1
        cpl
        add a,16
.f1:    add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,1
        ld (step2),hl
        ret
.normal:
        ld a,(sirenspd)
        ld b,a
        ld a,(sirenpos)
        add a,b
        ld (sirenpos),a
        bit 7,a
        jr z,.n1
        cpl
.n1:    ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,$0280
        add hl,de
        ld (step2),hl
        ret

; SFX ids
SFX_WAKA1  equ 0
SFX_WAKA2  equ 1
SFX_POWER  equ 2
SFX_EATG   equ 3
SFX_ITEM   equ 4
SFX_PUP    equ 5
SFX_TELE   equ 6
SFX_SHIELD equ 7
SFX_THUNDER equ 8
SFX_TICK   equ 9
SFX_FREEZE equ 10
SFX_POP    equ 11
SFX_SPAWN  equ 12
sfxtab:
        ; start, delta, len, mode, prio, pad
        dw 1300,-120 : db 4,0,1,0       ; waka1 (falling)
        dw 900,120   : db 4,0,1,0       ; waka2 (rising)
        dw 400,40    : db 30,1,4,0      ; energiser
        dw 500,110   : db 22,1,6,0      ; ghost eaten - rising warble sweep
        dw 1800,60   : db 10,1,3,0      ; treasure
        dw 700,90    : db 24,1,5,0      ; power-up collect
        dw 2600,-100 : db 16,0,5,0      ; teleport
        dw 3000,-150 : db 14,2,6,0      ; shield pop
        dw 100,0     : db 25,2,7,0      ; thunder (noise)
        dw 2200,0    : db 2,0,1,0       ; tick
        dw 3600,-200 : db 16,1,5,0      ; freeze
        dw 1500,-90  : db 8,0,2,0       ; pop / menu blip
        dw 1000,200  : db 10,0,3,0      ; item spawn
