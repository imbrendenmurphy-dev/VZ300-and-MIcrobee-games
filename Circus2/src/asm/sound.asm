; =====================================================================
;  CIRCUS 2 - beeper sound engine
;  Two square-wave voices: voice 0 toggles latch bit 0, voice 1 bit 5.
;  The VZ speaker sits across those two bits, so the voices mix.
;  Sound is generated in the idle time of every update (snd_idle), and
;  sequenced once per update by snd_tick (music streams + sound effects).
;  Pitch: f = 36947 / period  (48 T-state inner loop at 3.5469 MHz)
; =====================================================================

snd_idle:
        ld a,(snd_on)
        or a
        jp z,.quiet
        ld a,(v0per)
        cp $FF
        jp z,noise_idle
        ld d,a
        or a
        ld a,1
        jr nz,$+3
        xor a
        ld (.x0+1),a
        ld a,(v1per)
        ld e,a
        or a
        ld a,$20
        jr nz,$+3
        xor a
        ld (.x1+1),a
        ld a,(latchbase)
        ld h,a
        ld c,d
        ld b,e
.chk:   ld l,64
.tl:    dec c
        jr nz,.a
        ld c,d
        ld a,h
.x0:    xor 1
        ld h,a
        ld (LATCH),a
.a:     dec b
        jr nz,.b
        ld b,e
        ld a,h
.x1:    xor $20
        ld h,a
        ld (LATCH),a
.b:     dec l
        jr nz,.tl
        call rearm
        ld a,(nextframe)
        ld l,a
        ld a,(frames)
        sub l
        jp m,.chk
        ld a,(latchbase)
        ld (LATCH),a
        ret
.quiet: call rearm
        ld a,(nextframe)
        ld l,a
        ld a,(frames)
        sub l
        jp m,.quiet
        ret

; voice 0 noise (period v1per = density), voice 1 silent
noise_idle:
        ld a,(v1per)
        or a
        jr nz,$+4
        ld a,4
        ld d,a
        ld c,a
        ld a,(latchbase)
        ld h,a
.chk:   ld l,64
.tl:    dec c
        jr nz,.a
        ld c,d
        push hl
        ld hl,(nseed)
        add hl,hl
        jr nc,.n1
        ld a,l
        xor $2D
        ld l,a
.n1:    ld (nseed),hl
        ld a,l
        pop hl
        and 1
        xor h
        ld h,a
        ld (LATCH),a
.a:     dec l
        jr nz,.tl
        call rearm
        ld a,(nextframe)
        ld l,a
        ld a,(frames)
        sub l
        jp m,.chk
        ld a,(latchbase)
        ld (LATCH),a
        ret

; ---------------------------------------------------------------------
; per-update sequencer
; ---------------------------------------------------------------------
snd_tick:
        xor a
        ld (v0per),a
        ld (v1per),a
        ; ---- music
        ld a,(mus_on)
        or a
        jr z,.nomus
        ld ix,mus_ch0
        call mus_chan
        ld (v0per),a
        ld ix,mus_ch1
        call mus_chan
        ld (v1per),a
.nomus:
        ; ---- sound effect (overrides)
        ld hl,(sfx_ptr)
        ld a,h
        or l
        ret z
        ld a,(hl)
        cp $FE
        jr z,.sfxend
        cp $FD                  ; $FD = keep v0 (music) and set v1 only
        jr z,.v1only
        ld (v0per),a
        inc hl
        ld a,(hl)
        ld (v1per),a
        inc hl
        ld (sfx_ptr),hl
        ret
.v1only:
        inc hl
        ld a,(hl)
        ld (v1per),a
        inc hl
        ld (sfx_ptr),hl
        ret
.sfxend:
        ld hl,0
        ld (sfx_ptr),hl
        ret

; music channel at IX: +0/1 ptr, +2/3 loop start, +4 ticks left, +5 cur period,
;                       +6 staccato flag.  Returns A = period for this tick.
mus_chan:
        ld a,(ix+4)
        or a
        jr nz,.cont
        ; fetch next note
        ld l,(ix+0)
        ld h,(ix+1)
.fetch: ld a,(hl)
        cp $FF                  ; loop
        jr nz,.nl
        ld l,(ix+2)
        ld h,(ix+3)
        jr .fetch
.nl:    cp $FE                  ; end of tune
        jr nz,.ne
        xor a
        ld (mus_on),a
        ret
.ne:    inc hl
        push hl
        ld hl,notetab
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld a,(hl)
        pop hl
        ld (ix+5),a
        ld a,(hl)
        inc hl
        ld (ix+4),a
        ld (ix+0),l
        ld (ix+1),h
.cont:  dec (ix+4)
        ld a,(ix+4)
        or a
        jr nz,.play
        ld a,(ix+6)             ; staccato: last tick silent
        or a
        jr z,.play
        xor a
        ret
.play:  ld a,(ix+5)
        ret

; start music: HL = channel0 stream, DE = channel1 stream, A=1 loop / 0 once
play_music:
        ld (mus_ch0),hl
        ld (mus_ch0+2),hl
        ld (mus_ch1),de
        ld (mus_ch1+2),de
        xor a
        ld (mus_ch0+4),a
        ld (mus_ch1+4),a
        inc a
        ld (mus_ch0+6),a
        ld (mus_ch1+6),a
        ld (mus_on),a
        ret

stop_music:
        xor a
        ld (mus_on),a
        ret

; play sound effect HL (priority: a new effect always replaces)
sfx:
        ld (sfx_ptr),hl
        ret

; blocking: play current music until it ends or a key is pressed (A=1 allow skip)
; runs at 25 updates/s
play_jingle_wait:
        ld (.skip+1),a
        ld a,(frames)
        ld (nextframe),a
.lp:    call snd_tick
        ld a,2
        call syncframe
        ld a,(mus_on)
        or a
        ret z
.skip:  ld a,0
        or a
        jr z,.lp
        call anykey
        jr z,.lp
        jp stop_music

; inline click for instant feedback (very short, blocking ~1500T)
click:
        ld a,(snd_on)
        or a
        ret z
        ld a,(latchbase)
        ld c,a
        ld b,6
.l:     ld a,c
        xor $21
        ld c,a
        ld (LATCH),a
        push bc
        ld b,30
        djnz $
        pop bc
        djnz .l
        ret

; ---------------------------------------------------------------------
; note period table: index 0 = rest, 1 = D3 ... (semitones)
; ---------------------------------------------------------------------
notetab:
        db 0
        ; D3 .. C7  (MIDI 50..96), calibrated: half period = P*50.3+27 T
        db 240,226,213,201,190,179,169,160,151,142,134,127
        db 120,113,106,100,95,89,84,80,75,71,67,63
        db 59,56,53,50,47,44,42,40,37,35,33,31
        db 29,28,26,25,23,22,21,19,18,17,16

; note name constants (index into notetab)
D3=1
Ds3=2
E3=3
F3=4
Fs3=5
G3=6
Gs3=7
A3=8
As3=9
B3=10
C4=11
Cs4=12
D4=13
Ds4=14
E4=15
F4=16
Fs4=17
G4=18
Gs4=19
A4=20
As4=21
B4=22
C5=23
Cs5=24
D5=25
Ds5=26
E5=27
F5=28
Fs5=29
G5=30
Gs5=31
A5=32
As5=33
B5=34
C6=35
Cs6=36
D6=37
Ds6=38
E6=39
F6=40
Fs6=41
G6=42
RST=0
