; ---------------------------------------------------------------------------
; Music: the three-voice speaker player from the Cybernoid VZ300
; conversion (src/music.asm there), reused as-is: it turns an AY register
; shadow (R0-R13) into three speaker voices once per 50 Hz step -
;  * true pitch: phase increment = K / AY period (16-bit accumulators),
;  * pulse-interleaved mixing (each voice owns a third of every sample),
;  * pulse width follows the AY volume (decays, accents),
;  * AY noise becomes a short noise burst at the start of the step.
; In Cybernoid the shadow was filled by Hewson's AY driver; here it is
; filled by seq_step, a small original sequencer (tools/music.py), so the
; tunes are in the same AY-register "format" the player supports.
; ---------------------------------------------------------------------------
MPERIOD     equ 183             ; T-states per output sample (3 voices)
MFRAME      equ 70937           ; T-states per 50 Hz step (3.5469 MHz)
MITERS      equ MFRAME/MPERIOD - 52 - 12  ; minus per-step overhead (+ sequencer)
MDRUMN      equ 90              ; noise samples in a burst
MDRUMIT     equ 88              ; tone samples the burst replaces

; ---- run music + hook for up to B steps (0 = until a key); returns NZ if a
; key/fire was pressed.  Interrupts are off while the music plays.
vz_mplay:
        di
        ld a,b
        ld (vz_msteps),a
.step:  call vz_mstep
        ld hl,(vz_idle)
        inc hl
        ld (vz_idle),hl
        call vz_anykey
        jr nz,.key
        ld a,(vz_msteps)
        or a
        jr z,.step
        dec a
        ld (vz_msteps),a
        jr nz,.step
        xor a
        ret
.key:   or 1
        ret

vz_hook:
        ld hl,(vz_mhook)
        jp (hl)
vz_nohook:
        ret

; ---- one 50 Hz music step --------------------------------------------------
vz_mstep:
        di
        push ix
        push iy
        call seq_step           ; (Cybernoid: CALL AY_PLAY)
        pop iy
        pop ix
        call vz_hook
        ; --- voices from the register shadow
        ld a,(AYR+7)
        ld (vz_mmix),a
        ld hl,AYR+0
        ld de,AYR+8
        ld a,0
        call .voice
        ld (vz_a1),hl
        ld (.t1+1),a
        ld hl,AYR+2
        ld de,AYR+9
        ld a,1
        call .voice
        ld (vz_a2),hl
        ld (.t2+1),a
        ld hl,AYR+4
        ld de,AYR+10
        ld a,2
        call .voice
        ld (vz_a3),hl
        ld (.t3+1),a
        ; --- noise: any channel with noise on and volume -> burst
        ld a,(vz_mmix)
        cpl
        rrca
        rrca
        rrca
        and 7
        ld c,a
        ld hl,AYR+8
        ld b,3
        ld e,0
.nl:    rrc c
        jr nc,.nn
        ld a,(hl)
        and $1F
        cp 9
        jr c,.nn
        inc e
.nn:    inc hl
        djnz .nl
        ; --- play
        ld a,(spkoff)
        ld d,a
        ld iy,(vz_miters)
        ld a,e
        or a
        ld e,$21
        jr z,.nod
        ld hl,(vz_mrnd)
        ld b,MDRUMN
.nz:    ld a,(hl)
        inc hl
        and e
        xor d
        ld (LATCH),a
        ld c,7
.nzd:   dec c
        jr nz,.nzd
        djnz .nz
        res 5,h                 ; ROM bytes $0000-$1FFF as noise source
        res 6,h
        res 7,h
        ld (vz_mrnd),hl
        push de
        ld iy,(vz_miters)
        ld de,-MDRUMIT
        add iy,de
        pop de
.nod:   ld a,iyl
        or a
        jr z,.c0
        inc iyh
.c0:    ld a,d
        exx
        ld d,a
        ld e,$21
        ld hl,(vz_h2)
        ld bc,(vz_a2)
        exx
        ld hl,(vz_h1)
        ld bc,(vz_a1)
        ld ix,(vz_h3)
        ld (vz_msp),sp
        ld sp,(vz_a3)
.l:     add hl,bc               ; voice 1                   11
        ld a,h                  ;                            4
.t1:    cp 0                    ; pulse width                7
        sbc a,a                 ;                            4
        and e                   ;                            4
        xor d                   ;                            4
        ld (LATCH),a            ;                           13
        nop                     ;                            4
        nop                     ;                            4
        exx                     ; voice 2                    4
        add hl,bc               ;                           11
        ld a,h                  ;                            4
.t2:    cp 0                    ;                            7
        sbc a,a                 ;                            4
        and e                   ;                            4
        xor d                   ;                            4
        ld (LATCH),a            ;                           13
        add ix,sp               ; voice 3                   15
        ld a,ixh                ;                            8
.t3:    cp 0                    ;                            7
        sbc a,a                 ;                            4
        and e                   ;                            4
        xor d                   ;                            4
        exx                     ;                            4
        ld (LATCH),a            ;                           13
        dec iyl                 ;                            8
        jp nz,.l                ;                           10 = 183
        dec iyh
        jp nz,.l
        ld sp,(vz_msp)
        ld (vz_h1),hl
        ld (vz_h3),ix
        exx
        ld (vz_h2),hl
        exx
        ld a,d
        ld (LATCH),a
        ret

; HL -> period (2 bytes), DE -> volume, A = channel. Returns HL = phase
; increment, A = pulse width threshold (0 = silent).
.voice: ld b,a
        ld a,(de)
        and $1F
        bit 4,a
        jr z,.v0
        ld a,13                 ; envelope: treat as loud
.v0:    push hl
        ld hl,VOLTAB
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld c,(hl)               ; threshold
        pop hl
        ld a,(vz_mmix)          ; tone enabled? (active low)
        inc b
.vb:    rrca
        djnz .vb
        jr c,.off
        ld a,c
        or a
        jr z,.off
        ld e,(hl)
        inc hl
        ld a,(hl)
        and $0F
        ld d,a
        push bc
        call vz_pinc
        pop bc
        ld a,h
        or l
        ld a,c
        ret nz
.off:   ld hl,0
        xor a
        ret

; DE = AY period -> HL = K/DE (K = 65536 * 1773400/16 / (3546895/183)),
; 0 if the note is too high to play.
vz_pinc:
        ld a,d
        or a
        jr nz,.ok
        ld a,e
        cp 6
        jr nc,.ok
        ld hl,0
        ret
.ok:    ld hl,0                 ; remainder
        ld a,KDIV>>16
        ld bc,KDIV&$FFFF
        push ix
        ld ixl,24
.l:     sla c
        rl b
        rla
        adc hl,hl
        or a
        sbc hl,de
        jr nc,.s
        add hl,de
        jr .n
.s:     inc c
.n:     dec ixl
        jr nz,.l
        pop ix
        ld h,b
        ld l,c
        ret
KDIV        equ 374830

; AY volume 0-15 -> pulse threshold (Cybernoid's table)
VOLTAB: db 0,0,0,0,0,20,26,32,44,54,66,80,96,112,124,128

vz_mstop:
        xor a
        ld (AYR+8),a
        ld (AYR+9),a
        ld (AYR+10),a
        ld a,(spkoff)
        ld (LATCH),a
        ret

vz_anykey:                      ; NZ if a key or fire is down
        ld a,($6800)
        or $C0
        cpl
        and $3F
        ret nz
        call joy_read
        or a
        ret

vz_mhook  dw vz_nohook
vz_msteps db 0
vz_miters dw MITERS
vz_mmix   db 0
vz_a1     dw 0
vz_a2     dw 0
vz_a3     dw 0
vz_h1     dw 0
vz_h2     dw 0
vz_h3     dw 0
vz_msp    dw 0
vz_mrnd   dw $0100
vz_idle   dw 0
AYR       ds 14

; ---------------------------------------------------------------------------
; seq_step: the sequencer.  Each channel streams bytes:
;   0..95  note (semitone, 0 = C1) then a duration byte (steps)
;   $60 d  rest
;   $61 i  instrument i (volume, decay steps, noise, vibrato)
;   $62    jump back to the channel's loop point (end of song)
;   $63    end of song (channel stops)
; Instruments: start volume, steps per volume drop, noise flag, sustain floor
; ---------------------------------------------------------------------------
NCH equ 3
; per channel: ptr(2), loop(2), dur(1), vol(1), dcnt(1), inst(1), note(1)
CH_PTR  equ 0
CH_LOOP equ 2
CH_DUR  equ 4
CH_VOL  equ 5
CH_DCNT equ 6
CH_INST equ 7
CH_NOTE equ 8
CH_LEN  equ 10

; HL -> song: 3 x dw channel streams
seq_start:
        ld ix,seq_ch
        ld b,NCH
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ix+CH_PTR),e
        ld (ix+CH_PTR+1),d
        ld (ix+CH_LOOP),e
        ld (ix+CH_LOOP+1),d
        ld (ix+CH_DUR),1
        ld (ix+CH_VOL),0
        ld (ix+CH_INST),0
        ld de,CH_LEN
        add ix,de
        djnz .l
        ld a,$38                ; tones on, noise off
        ld (AYR+7),a
        xor a
        ld (seq_done),a
        ret

seq_step:
        ld ix,seq_ch
        ld iy,AYR
        ld c,0                  ; channel number
.ch:    ld a,(ix+CH_DUR)
        or a
        jr z,.env               ; stopped
        dec (ix+CH_DUR)
        jr nz,.env
        call .read
.env:   ; volume decay
        ld a,(ix+CH_VOL)
        or a
        jr z,.out
        dec (ix+CH_DCNT)
        jr nz,.out
        push bc
        call .inst
        ld a,(hl)               ; decay rate
        ld (ix+CH_DCNT),a
        inc hl
        inc hl
        ld b,(hl)               ; floor
        pop bc
        ld a,(ix+CH_VOL)
        cp b
        jr z,.out
        jr c,.out
        dec (ix+CH_VOL)
.out:   ; registers: period, volume, mixer bits
        ld l,(ix+CH_NOTE)
        ld h,0
        add hl,hl
        ld de,ptab
        add hl,de
        ld a,(hl)
        ld (iy+0),a
        inc hl
        ld a,(hl)
        ld (iy+1),a
        push iy
        ld e,c
        ld d,0
        add iy,de
        ld a,(ix+CH_VOL)
        ld (iy+8),a
        pop iy
        inc iy
        inc iy
        ld de,CH_LEN
        add ix,de
        inc c
        ld a,c
        cp NCH
        jr nz,.ch
        ret

.read:  ld l,(ix+CH_PTR)
        ld h,(ix+CH_PTR+1)
.rd:    ld a,(hl)
        inc hl
        cp $60
        jr c,.note
        jr z,.rest
        cp $61
        jr z,.ins
        cp $62
        jr z,.loop
        ; $63: end
        ld (ix+CH_DUR),0
        ld (ix+CH_VOL),0
        ld a,1
        ld (seq_done),a
        jr .sv
.loop:  ld l,(ix+CH_LOOP)
        ld h,(ix+CH_LOOP+1)
        ld a,1
        ld (seq_done),a
        jr .rd
.ins:   ld a,(hl)
        inc hl
        ld (ix+CH_INST),a
        jr .rd
.rest:  ld a,(hl)
        inc hl
        ld (ix+CH_DUR),a
        ld (ix+CH_VOL),0
        jr .sv
.note:  ld (ix+CH_NOTE),a
        ld a,(hl)
        inc hl
        ld (ix+CH_DUR),a
        push hl
        push bc
        call .inst
        ld a,(hl)
        ld (ix+CH_DCNT),a       ; decay rate
        dec hl
        ld a,(hl)
        ld (ix+CH_VOL),a        ; start volume
        inc hl
        inc hl
        ld a,(hl)               ; noise?
        pop bc
        pop hl
        push hl
        ld hl,AYR+7
        ld b,c
        inc b
        ld e,$04                ; noise bit for channel 0 is bit 3 (active low)
.nb:    sla e
        djnz .nb
        or a
        ld a,(hl)
        jr z,.nn
        ld d,a
        ld a,e
        cpl
        and d                   ; noise on
        jr .ns
.nn:    or e                    ; noise off
.ns:    ld (hl),a
        pop hl
.sv:    ld (ix+CH_PTR),l
        ld (ix+CH_PTR+1),h
        ret

; HL -> instrument record + 1 (decay rate) for channel IX
.inst:  ld a,(ix+CH_INST)
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,instruments+1
        add hl,de
        ret

seq_ch:   ds NCH*CH_LEN
seq_done: db 0
