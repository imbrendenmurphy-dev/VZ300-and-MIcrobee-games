; ---------------------------------------------------------------------------
; Sound effects on the VZ speaker.
; snd_step is called about every 500-600 T-states from the big loops (screen
; copies, the frame wait, the interrupt's sync wait, particle and sprite loops)
; so effects keep sounding through most of each game update. It uses the
; alternate register set: HL' phase, DE' rate, C' on/off mask, B' latch base.
; ---------------------------------------------------------------------------
SFX_LETSGO  equ 1
SFX_ASSIGN  equ 2
SFX_CLICK   equ 3
SFX_DIG     equ 4
SFX_CLINK   equ 5
SFX_TINK    equ 6
SFX_SPLAT   equ 7
SFX_SPLASH  equ 8
SFX_HOME    equ 9
SFX_OHNO    equ 10
SFX_BOOM    equ 11

snd_step:
        di
        exx
        ld a,(snd_mode)
        or a
        jr nz,.nz
        add hl,de
        ld a,h                  ; tone: top bit of the phase
        jr .o
.nz:    add hl,de
        jr nc,.hold             ; noise: a new random bit at the rate
        ld a,(snd_nbit)
        add a,a
        jr nc,.n1
        xor $1D
.n1:    ld (snd_nbit),a
.hold:  ld a,(snd_nbit)
.o:     rla
        sbc a,a
        and c
        xor b
        or L_MODE               ; whatever's in B', never leave graphics mode
        ld (LATCH),a
        exx
        ld a,(v_hold)
        or a
        jp nz,int_poll
        ei
        ret
snd_mode: db 0
; reset the effect registers (B' latch base, C' on/off mask) - after the music
snd_init:
        push hl
        ld hl,0
        ld (sfx_ptr),hl
        xor a
        ld (sfx_pri),a
        ld (snd_mode),a
        ld a,(v_spkoff)
        exx
        ld b,a
        ld c,0
        ld hl,0
        ld de,0
        exx
        pop hl
        ret
; extra steps from the irregular loops: only for noise (pitch doesn't matter)
snd_nstep:
        ld a,(snd_mode)
        or a
        ret z
        jp snd_step
snd_lfsr: dw $ACE1
snd_nbit: db $5B

; spin for about 550 T-states doing one sound step (frame waits)
snd_wait_step:
        call snd_step
        push bc
        ld b,30
.d:     djnz .d
        pop bc
        ret

; ---- start an effect (higher or equal priority replaces) ------------------
sfx_play:
        push hl
        push de
        push bc
        ld c,a
        ld a,(v_demo)
        or a
        jr nz,.x
        ld a,(v_sfxon)
        or a
        jr z,.x
        ld a,c
        dec a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,SFXTAB
        add hl,de
        ld a,(sfx_pri)
        cp (hl)
        jr z,.ok
        jr nc,.x
.ok:    ld a,(hl)
        ld (sfx_pri),a
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (sfx_ptr),de
.x:     pop bc
        pop de
        pop hl
        ret

; ---- per update: next step of the effect script -----------------------------
; script entries: mode (0 end, 1 tone, 2 noise, 3 silence), rate (word)
sfx_tick:
        ld hl,(sfx_ptr)
        ld a,h
        or l
        jr z,.off
        ld a,(hl)
        or a
        jr z,.end
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (sfx_ptr),hl
        ld c,$21
        ld b,0                  ; tone
        cp 2
        jr nz,.t
        ld b,1                  ; noise
.t:     cp 3
        jr nz,.s
        ld c,0
.s:     ld a,b
        ld (snd_mode),a
        ld a,(v_spkoff)
        exx
        ld b,a
        exx
        push de
        exx
        pop de
        exx
        ld a,c
        exx
        ld c,a
        exx
        jp int_poll
.end:   ld hl,0
        ld (sfx_ptr),hl
.off:   xor a
        ld (sfx_pri),a
        ld a,(v_spkoff)
        di
        exx
        ld b,a
        ld c,0
        exx
        jp int_poll
sfx_ptr: dw 0
sfx_pri: db 0

; priority, -, script
SFXTAB: db 6,0 : dw sx_letsgo
        db 3,0 : dw sx_assign
        db 2,0 : dw sx_click
        db 1,0 : dw sx_dig
        db 2,0 : dw sx_clink
        db 2,0 : dw sx_tink
        db 5,0 : dw sx_splat
        db 5,0 : dw sx_splash
        db 4,0 : dw sx_home
        db 5,0 : dw sx_ohno
        db 7,0 : dw sx_boom

; tone rates for ~6.3 kHz steps: f = rate * 6300 / 65536
; noise rates: how often the noise changes (65535 = every step: bright hiss)
        MACRO TN r
        db 1 : dw r
        ENDM
        MACRO NZ r
        db 2 : dw r
        ENDM
        MACRO SL
        db 3 : dw 0
        ENDM
; "let's go": a rising hop
sx_letsgo:  TN 5200 : TN 5200 : SL : TN 6900 : TN 6900 : SL : TN 8700 : TN 9200 : TN 9800 : TN 10400 : db 0
sx_assign:  TN 12000 : TN 9000 : db 0
sx_click:   TN 14000 : db 0
sx_dig:     NZ 9000 : NZ 6000 : db 0
sx_clink:   TN 20000 : TN 19000 : SL : TN 20000 : db 0
sx_tink:    TN 16000 : SL : db 0
sx_splat:   NZ 30000 : NZ 20000 : NZ 12000 : NZ 7000 : NZ 4000 : db 0
sx_splash:  NZ 65535 : NZ 50000 : NZ 40000 : TN 3000 : TN 2600 : TN 2200 : TN 1900 : db 0
sx_home:    TN 7800 : TN 9800 : TN 11600 : TN 13800 : TN 15600 : db 0
sx_ohno:    TN 9000 : TN 9000 : TN 8400 : SL : TN 6400 : TN 6200 : TN 6000 : TN 5800 : TN 5600 : db 0
sx_boom:    NZ 65535 : NZ 65535 : NZ 58000 : NZ 50000 : NZ 42000 : NZ 34000 : NZ 27000 : NZ 21000 : NZ 16000 : NZ 12000 : NZ 8000 : db 0

; ---- a burst of dense noise (blocking): B = length in 256-sample blocks,
; A = how fast it darkens per block. For the big explosions.
noise_crack:                    ; a very short burst (about 3 ms)
        ld a,96
        ld (nb_first),a
        ld b,1
        ld a,40
        jr nb_go
noise_burst:
        push af
        xor a
        ld (nb_first),a
        pop af
nb_go:  push hl
        push de
        push bc
        ld c,a
        ld a,(v_demo)
        or a
        jr nz,.x
        ld a,c
        ld (nb_dec),a
        di
        ld hl,0
        ld d,$FF
        ld e,$FF
        ld a,(nb_first)
        ld c,a
.l:     add hl,de
        jr nc,.h
        push hl
        ld hl,(snd_lfsr)
        srl h
        rr l
        jr nc,.n
        ld a,h
        xor $B4
        ld h,a
.n:     ld (snd_lfsr),hl
        ld a,l
        pop hl
        rrca
        ld (snd_nbit),a
.h:     ld a,(snd_nbit)
        rla
        sbc a,a
        and $21
        push hl
        ld hl,v_spkoff
        xor (hl)
        pop hl
        ld (LATCH),a
        dec c
        jr nz,.l
        ld a,(nb_dec)
        ld e,a
        ld a,d
        sub e
        jr c,.lo
        cp 6
        jr nc,.ok
.lo:    ld a,6
.ok:    ld d,a
        djnz .l
        ld a,(nb_first)
        or a
        jr nz,.q                ; (a short crack doesn't reset the frame timing)
        ld a,(v_tick)
        ld (v_last),a
.q:     call int_poll
.x:     pop bc
        pop de
        pop hl
        ret
nb_dec: db 0
nb_first: db 0
