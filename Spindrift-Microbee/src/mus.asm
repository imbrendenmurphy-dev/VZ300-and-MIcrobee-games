; =====================================================================
;  SWIRL - the title music engine. One speaker bit, all of the CPU.
;
;  Three voices take turns at the speaker inside every sample, so they
;  add up like real mixing instead of masking one another:
;    BASS   a pulse with a moving duty (the squelch)
;    PHASE  two oscillators, exclusive-or'd (or OR / AND): two close
;           pitches drift through each other and the tone sweeps -
;           the psychedelic swirl
;    ARP    a pulse with a moving duty: arpeggios and the lead line
;  The bass holds the speaker 80 T of the 218 T sample, the phaser 62,
;  the arp 76: 15 482 samples a second.
;  Drums interrupt the voices: designed 1-bit pulse trains (kick, snare,
;  hats, toms), then the voices carry on where they were.
;
;  The music is a stream of ticks (255 samples, about 59 a second) made
;  by tools/song.py, in RAM block 7, mapped low while it plays:
;    0000h  dw loop point, dw drum table
;    then a tick each: a mask byte, then the fields its bits name:
;      b0 PHASE A step (dw)   b1 PHASE B step (dw)   b2 BASS step (dw)
;      b3 BASS duty (db)      b4 ARP step (dw)       b5 ARP duty (db)
;      b6 drum (db, 1-based)  b7 control (db): 0 = go to the loop point,
;         1 xor, 2 or, 3 and = how the phaser joins its oscillators
; =====================================================================
MUS_TICK    EQU 255

; DE = a hook, called once a tick (it may use any register and map any
; block; NZ from it stops the music, with its A). Plays from mus_pos.
mus_run:
        ld (.hook+1),de
        call mus_mute
.tick:  ld a,MP_MUS
        out (P_MEM),a
        call mus_step
        ld a,(mdrum)
        or a
        ld a,MUS_TICK
        call nz,mus_drum        ; -> A = samples left of this tick
        ld (mus_left),a
.hook:  call 0
        jr nz,.stop
        ld a,(mus_left)
        or a
        jr z,.tick
        ld e,a
        ld hl,(acc_a)
        exx
        ld hl,(acc_b)
        exx
        ld ix,(acc_bass)
        ld iy,(acc_arp)
        call ml
        ld (acc_a),hl
        exx
        ld (acc_b),hl
        exx
        ld (acc_bass),ix
        ld (acc_arp),iy
        jr .tick
.stop:  push af
        xor a
        out (P_PIOB),a
        ld a,MP_TAB
        out (P_MEM),a
        pop af
        ret

; the sample loop: E samples
ml:
mb:     ld bc,0                 ; 10  BASS
        add ix,bc               ; 15
        ld a,ixh                ; 8
mbd:    cp 0                    ; 7
        sbc a,a                 ; 4
mbm:    and $40                 ; 7
        out (P_PIOB),a          ; 11
mpa:    ld bc,0                 ; 10  PHASE
        add hl,bc               ; 11
        ld a,h                  ; 4
        exx                     ; 4
mpb:    ld bc,0                 ; 10
        add hl,bc               ; 11
mpo:    xor h                   ; 4   (or h, and h)
        exx                     ; 4
mpm:    and $80                 ; 7
        rrca                    ; 4
        out (P_PIOB),a          ; 11
mar:    ld bc,0                 ; 10  ARP
        add iy,bc               ; 15
        ld a,iyh                ; 8
mad:    cp 0                    ; 7
        sbc a,a                 ; 4
mam:    and $40                 ; 7
        out (P_PIOB),a          ; 11
        dec e                   ; 4
        jp nz,ml                ; 10  = 218 T
        ret

; music off (sound mode below 2): the voices are gated to silence, so a
; screen that runs on the music's ticks keeps its timing
mus_mute:
        ld a,(sndmode)
        cp 2
        ld a,$40
        ld b,$80
        jr nc,.on
        xor a
        ld b,a
.on:    ld (mbm+1),a
        ld (mam+1),a
        ld a,b
        ld (mpm+1),a
        ret

; read the next tick (MP_MUS mapped)
mus_step:
        ld hl,(mus_pos)
.again: xor a
        ld (mdrum),a
        ld a,(hl)
        inc hl
        ld c,a
        srl c
        jr nc,.n0
        ld a,(hl)
        ld (mpa+1),a
        inc hl
        ld a,(hl)
        ld (mpa+2),a
        inc hl
.n0:    srl c
        jr nc,.n1
        ld a,(hl)
        ld (mpb+1),a
        inc hl
        ld a,(hl)
        ld (mpb+2),a
        inc hl
.n1:    srl c
        jr nc,.n2
        ld a,(hl)
        ld (mb+1),a
        inc hl
        ld a,(hl)
        ld (mb+2),a
        inc hl
.n2:    srl c
        jr nc,.n3
        ld a,(hl)
        ld (mbd+1),a
        inc hl
.n3:    srl c
        jr nc,.n4
        ld a,(hl)
        ld (mar+1),a
        inc hl
        ld a,(hl)
        ld (mar+2),a
        inc hl
.n4:    srl c
        jr nc,.n5
        ld a,(hl)
        ld (mad+1),a
        inc hl
.n5:    srl c
        jr nc,.n6
        ld a,(hl)
        ld (mdrum),a
        inc hl
.n6:    srl c
        jr nc,.n7
        ld a,(hl)
        inc hl
        or a
        jr nz,.op
        ld hl,(0)               ; the loop point
        jr .again
.op:    push hl
        ld hl,phase_ops-1
        add a,l
        ld l,a
        jr nc,.o
        inc h
.o:     ld a,(hl)
        ld (mpo),a
        pop hl
.n7:    ld (mus_pos),hl
        ret

phase_ops:
        xor h
        or h
        and h

; A = drum (1-based): play its pulse train -> A = samples left of the
; tick (the drum's length comes off it)
mus_drum:
        dec a
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de               ; three bytes a drum: dw train, db samples
        ld de,(2)
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        push af
        ex de,hl
        ld a,(sndmode)
        cp 2
        call nc,pulse_play
        pop af
        cpl
        inc a                   ; - samples
        add a,MUS_TICK
        ret c
        xor a                   ; longer than a tick: none left
        ret

; HL = a pulse train: bytes, 0 ends; b0-6 = wait in 51 T units, b7 set =
; keep the level (else the speaker flips first)
pulse_play:
        ld c,0
.n:     ld a,(hl)
        inc hl
        or a
        ret z
        ld b,a
        rla
        jr c,.k
        ld a,c
        xor $40
        ld c,a
        out (P_PIOB),a
.k:     res 7,b
.d:     ex (sp),hl
        ex (sp),hl
        djnz .d
        jr .n

; start the tune from its beginning (the next mus_run plays it)
mus_reset:
        ld a,MP_MUS
        out (P_MEM),a
        ld hl,4
        ld (mus_pos),hl
        ld hl,0
        ld (acc_a),hl
        ld (acc_b),hl
        ld (acc_bass),hl
        ld (acc_arp),hl
        ld (mpa+1),hl
        ld (mpb+1),hl
        ld (mb+1),hl
        ld (mar+1),hl
        xor a
        ld (mbd+1),a
        ld (mad+1),a
        ld a,MP_TAB
        out (P_MEM),a
        ret
