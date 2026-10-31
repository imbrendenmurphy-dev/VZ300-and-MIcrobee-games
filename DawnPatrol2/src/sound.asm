; ===================================================================
;  DAWN PATROL 2  -  sound: in-game SFX (ISR) and 3-channel music
; ===================================================================

; ------------------------------------------------------------------
; sfx_play: A = effect id (1..). Respects priority.
; ------------------------------------------------------------------
sfx_play:
        push hl
        push de
        push bc
        ld c,a
        ld a,i                  ; P/V = interrupt enable state
        push af
        ld a,c
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; *8
        ld de,SFXTAB-8
        add hl,de
        ld b,a
        ld a,(sfx_cur)
        or a
        jr z,.go
        ld a,(sfx_prio)
        ld c,a
        push hl
        ld de,7
        add hl,de
        ld a,(hl)
        pop hl
        cp c
        jr c,.out
.go:    di
        ld a,b
        ld (sfx_cur),a
        ld a,(hl)
        ld (sfx_type),a
        inc hl
        ld a,(hl)
        ld (sfx_pitch+1),a
        xor a
        ld (sfx_pitch),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (sfx_dp),de
        inc hl
        ld a,(hl)
        ld (sfx_t),a
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        ld (sfx_prio),a
.out:   pop af
        jp po,.di
        ei
.di:    pop bc
        pop de
        pop hl
        ret

in_game_flag db 0

; ------------------------------------------------------------------
; sfx_isr: B = iteration budget (approx 42T each)
; ------------------------------------------------------------------
sfx_isr:
        ld a,(sfx_cur)
        or a
        jr nz,.play
        ; ambient rotor thump
        ld a,(rotor_rate)
        or a
        ret z
        ld c,a
        ld a,(rotor_tick)
        inc a
        cp c
        jr c,.rt
        xor a
.rt:    ld (rotor_tick),a
        or a
        ret nz
        ld e,5                  ; the chop: a short low noise thump
        ld hl,150
        jr noise_gen
.play:  ld a,(sfx_pitch+1)
        or a
        jr nz,.p1
        inc a
.p1:    ld e,a
        ld l,b
        ld h,0
        add hl,hl
        ld a,(sfx_type)
        cp 2
        jr nz,.nb
        ld a,(sfx_t)            ; type 2: tone gated on and off = beep beep
        and 4
        jr z,.adv
        call tone_gen
        jr .adv
.nb:    or a
        push af
        call z,tone_gen
        pop af
        call nz,noise_gen
.adv:
        ; advance
        ld hl,(sfx_pitch)
        ld de,(sfx_dp)
        add hl,de
        ld (sfx_pitch),hl
        ld hl,sfx_t
        dec (hl)
        ret nz
        xor a
        ld (sfx_cur),a
        ret

; tone: E = half period (iterations), HL = iterations
tone_gen:
        ld a,(latchv)           ; speaker bits 0 and 5 must be in opposite states
        and $DE
        or $20
        ld c,a
        ld d,e
.l:     dec d
        jr nz,.n
        ld d,e
        ld a,c
        xor $21
        ld c,a
        ld (LATCH),a
.n:     dec hl
        ld a,h
        or l
        jr nz,.l
        ld a,(latchv)
        ld (LATCH),a
        ret

; noise: E = step period, HL = iterations
noise_gen:
        ld a,(latchv)
        and $DE
        or $20
        ld c,a
        ld d,e
        ld a,(noise_seed)
        ld b,a
        or a
        jr nz,.l
        inc b
.l:     dec d
        jr nz,.n
        ld d,e
        srl b
        jr nc,.n
        ld a,b
        xor $B8
        ld b,a
        ld a,c
        xor $21
        ld c,a
        ld (LATCH),a
.n:     dec hl
        ld a,h
        or l
        jr nz,.l
        ld a,b
        ld (noise_seed),a
        ld a,(latchv)
        ld (LATCH),a
        ret

; effect ids
SFX_SHOT    equ 1
SFX_EXPL    equ 2
SFX_BIGEXPL equ 3
SFX_PICKUP  equ 4
SFX_UNLOAD  equ 5
SFX_HIT     equ 6
SFX_ALARM   equ 7
SFX_MISSILE equ 8
SFX_POWER   equ 9
SFX_LAND    equ 10
SFX_TINK    equ 11
SFX_ESHOT   equ 12
SFX_FLAK    equ 13
SFX_HUT     equ 14
SFX_BLIP    equ 15
SFX_WARN    equ 16
SFX_WHOOSH  equ 17
SFX_RADAR   equ 18

; type, start, dp(word 8.8), frames, -, -, prio
SFXTAB:
        db 0, 10 : dw $0280 : db 3, 0,0, 1      ; shot
        db 1,  2 : dw $0060 : db 14, 0,0, 3     ; explosion
        db 1,  1 : dw $0040 : db 34, 0,0, 6     ; big explosion
        db 0, 40 : dw -$0600: db 4, 0,0, 2      ; pickup
        db 0, 28 : dw -$0300: db 3, 0,0, 2      ; unload / score
        db 1,  5 : dw $0100 : db 6, 0,0, 4      ; hit
        db 0, 22 : dw $0000 : db 5, 0,0, 2      ; alarm
        db 1,  1 : dw $0020 : db 12, 0,0, 2     ; missile launch
        db 0, 70 : dw -$0800: db 8, 0,0, 4      ; powerup
        db 1, 14 : dw $0400 : db 3, 0,0, 1      ; land
        db 0,  6 : dw $0080 : db 2, 0,0, 1      ; tink
        db 0, 18 : dw $0500 : db 3, 0,0, 1      ; enemy shot
        db 1,  3 : dw $0180 : db 6, 0,0, 2      ; flak
        db 0,110 : dw -$0C00: db 8, 0,0, 3      ; hut opened
        db 0, 25 : dw $0000 : db 2, 0,0, 1      ; blip
        db 0, 14 : dw $0100 : db 6, 0,0, 3      ; warning

; ------------------------------------------------------------------
; 1-bit speech at ~8 kHz: HL = clip (word length, then bits, MSB first)
; ------------------------------------------------------------------
speak:
        ld a,i
        push af
        di
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(latchv)
        and $DE
        ld e,a
.byte:  ld d,(hl)
        inc hl
        push bc
        ld b,8
.bit:   ld a,e
        rlc d
        jr nc,.z
        or $20
        jr .w
.z:     or $01
.w:     ld (LATCH),a
        ld c,23
.dl:    dec c
        jr nz,.dl
        djnz .bit
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,.byte
        ld a,(latchv)
        ld (LATCH),a
        pop af
        jp po,.n
        ei
.n:     ret

; ------------------------------------------------------------------
; simple blocking beep for menus (interrupts off): E = period, B = len
; ------------------------------------------------------------------
beep:
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        jp tone_gen

; ===================================================================
;  3-channel music engine (DI). Pin-interleaved 1-bit mixing,
;  phase accumulators, duty-cycle envelopes, noise via memory read.
;  in: HL = song. Calls (mus_cb) each tick. Returns when:
;   - (mus_stop) set nonzero by callback, or song ends (non-looping)
; ===================================================================
MUS_ITER    equ 200

mus_start:
        di
        push hl
        call load_assets
        pop hl
        ld (mus_song),hl
        ld a,(hl)
        ld (mus_speed),a
        inc hl
        ld de,mus_ins
        ld bc,9
        ldir
        ld (mus_order),hl
        ld (mus_opos),hl
        xor a
        ld (mus_stop),a
        ld (mus_rowc),a
        ld (mus_tick),a
        ld (mus_d1v),a
        ld (mus_d2v),a
        ld (mus_d3v),a
        ld (mus_dr),a
        ld hl,0
        ld (mus_i1),hl
        ld (mus_i2),hl
        ld (mus_i3),hl
        call mus_next_pat
        ret c
        call mus_row
        jp mus_loop_enter

mus_next_pat:   ; carry set = song ended
        ld hl,(mus_opos)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr nz,.ok
        scf
        ret
.ok:    ld a,d
        cp $FF
        jr nz,.pat
        ; loop: next word = order position
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (mus_opos),de
        jr mus_next_pat
.pat:   ld (mus_opos),hl
        ld (mus_ppos),de
        ld a,16
        ld (mus_rowc),a
        or a
        ret

; process one row of the current pattern
mus_row:
        ld hl,(mus_ppos)
        ; ch1
        ld a,(hl)
        inc hl
        or a
        jr z,.c2
        dec a
        jr nz,.n1
        ld (mus_d1v),a          ; off
        jr .c2
.n1:    call note_inc
        ld (mus_i1),de
        ld a,(mus_ins)
        ld (mus_d1v),a
.c2:    ld a,(hl)
        inc hl
        or a
        jr z,.c3
        dec a
        jr nz,.n2
        ld (mus_d2v),a
        jr .c3
.n2:    call note_inc
        ld (mus_i2),de
        ld a,(mus_ins+3)
        ld (mus_d2v),a
.c3:    ld a,(hl)
        inc hl
        ld (mus_ppos),hl
        or a
        ret z
        cp $80
        jr nc,.drum
        dec a
        jr nz,.n3
        ld (mus_d3v),a
        ret
.n3:    call note_inc
        ld (mus_i3),de
        ld a,$7C                ; ld a,ixh (tone)
        ld (mus_ch3op+1),a
        xor a
        ld (mus_dr),a
        ld a,(mus_ins+6)
        ld (mus_d3v),a
        ret
.drum:  sub $7F                 ; 1 kick 2 snare 3 hat
        ld (mus_dr),a
        ld b,a
        ld a,$80
        ld (mus_d3v),a
        dec b
        jr nz,.sn
        ld hl,1400              ; kick: falling tone
        ld (mus_i3),hl
        ld a,$7C
        ld (mus_ch3op+1),a
        ld a,7
        ld (mus_drt),a
        ret
.sn:    ld a,$7E                ; ld a,(ix+0) noise
        ld (mus_ch3op+1),a
        ld hl,$0107
        ld (mus_i3),hl
        dec b
        ld a,6
        jr z,.snl
        ld a,2
.snl:   ld (mus_drt),a
        ret

; A = note index (1..) -> DE = increment
note_inc:
        push hl
        add a,a
        ld l,a
        ld h,0
        ld de,NOTETAB-2
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        ret

; per-tick envelope / drum update, then row advance
mus_tick_proc:
        ; ch1 duty decay
        ld a,(mus_d1v)
        ld hl,mus_ins+1
        call .dec
        ld (mus_d1v),a
        ld a,(mus_d2v)
        ld hl,mus_ins+4
        call .dec
        ld (mus_d2v),a
        ld a,(mus_dr)
        or a
        jr nz,.drum
        ld a,(mus_d3v)
        ld hl,mus_ins+7
        call .dec
        ld (mus_d3v),a
        jr .rows
.drum:  ld hl,mus_drt
        dec (hl)
        jr nz,.dk
        xor a
        ld (mus_dr),a
        ld (mus_d3v),a
        jr .rows
.dk:    cp 1
        jr nz,.rows
        ld hl,(mus_i3)          ; kick: pitch falls
        ld de,-170
        add hl,de
        ld (mus_i3),hl
.rows:  ld hl,mus_tick
        inc (hl)
        ld a,(mus_speed)
        cp (hl)
        ret nz
        ld (hl),0
        ld hl,mus_rowc
        dec (hl)
        jr nz,.row
        call mus_next_pat
        jr nc,.row
        ld a,1
        ld (mus_stop),a
        ret
.row:   jp mus_row
.dec:   ; A = duty, (HL) = decay, (HL+1) = floor (sustain) ; result A
        or a
        ret z
        sub (hl)
        jr c,.fl
        inc hl
        cp (hl)
        ret nc
        ld a,(hl)
        ret
.fl:    inc hl
        ld a,(hl)
        ret

mus_loop_enter:
        ; patch duty compares
        ld a,(mus_d1v)
        ld (mus_cp1+1),a
        ld a,(mus_d2v)
        ld (mus_cp2+1),a
        ld a,(mus_d3v)
        ld (mus_cp3+1),a
        ld a,(latchv)
        and $DE
        or $20
        ld (mus_x1+1),a
        ld (mus_x2+1),a
        ld (mus_x3+1),a
        exx
        ld hl,(mus_ph2)
        ld de,(mus_i2)
        ld bc,(mus_i3)
        exx
        ld hl,(mus_ph1)
        ld de,(mus_i1)
        ld ix,(mus_ph3)
        ld b,MUS_ITER
mus_lp:
        add hl,de
        ld a,h
mus_cp1: cp 0
        sbc a,a
        and $21
mus_x1: xor 0
        ld (LATCH),a
        exx
        add hl,de
        ld a,h
mus_cp2: cp 0
        sbc a,a
        and $21
mus_x2: xor 0
        ld (LATCH),a
        add ix,bc
mus_ch3op:
        ld a,ixh
        nop
mus_cp3: cp 0
        sbc a,a
        and $21
mus_x3: xor 0
        ld (LATCH),a
        exx
        djnz mus_lp
        ; tick boundary
        ld (mus_ph1),hl
        ld (mus_ph3),ix
        exx
        ld (mus_ph2),hl
        exx
        call mus_tick_proc
        ld hl,(mus_cb)
        call jp_hl
        ld a,(mus_stop)
        or a
        jp z,mus_loop_enter
        ld a,(latchv)
        ld (LATCH),a
        ret

jp_hl:  jp (hl)

mus_dummy_cb:
        ret

mus_song  dw 0
mus_speed db 0
mus_ins   ds 9                  ; per channel: start duty, decay/tick, floor
mus_order dw 0
mus_opos  dw 0
mus_ppos  dw 0
mus_rowc  db 0
mus_tick  db 0
mus_stop  db 0
mus_d1v   db 0
mus_d2v   db 0
mus_d3v   db 0
mus_dr    db 0
mus_drt   db 0
mus_i1    dw 0
mus_i2    dw 0
mus_i3    dw 0
mus_ph1   dw 0
mus_ph2   dw 0
mus_ph3   dw 0
mus_cb    dw mus_dummy_cb
