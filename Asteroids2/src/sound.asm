; ---------------------------------------------------------------------------
; sound.asm - 3-voice 1-bit mixer that runs while waiting for field sync,
; plus SFX and music sequencers ticked once per field (50 Hz).
;
; Each sample writes three latch values in turn (pulse-interleaved mixing):
; voice A, voice B, voice C.  Voice level: +1 when acc.hi < duty else -1.
; Duty doubles as volume / timbre.  Voice C can read memory bytes instead of
; its accumulator (noise).  Sample loop = 214 T  ->  ~16.57 kHz.
; freq word = Hz * 3.954
; ---------------------------------------------------------------------------

        MACRO SNDBODY pa, pb, mc, pc
        add hl,de
        ld a,h
pa:     cp 0
        sbc a,a
        and $21
        xor $20
        or c
        ld (LATCH),a
        exx
        add hl,de
        add ix,bc
        ld a,h
pb:     cp 0
        sbc a,a
        and $21
        xor $20
        exx
        or c
        ld (LATCH),a
mc:     db $DD,$7C,$00          ; ld a,ixh : nop   /  ld a,(ix+0) for noise
pc:     cp 0
        sbc a,a
        and $21
        xor $20
        or c
        ld (LATCH),a
        ENDM

; ---- wait for the next field-sync falling edge, playing sound meanwhile
; (call once per field; ticks the active sequencer first)
wait_fs:
        call fs_poll
        ld hl,(tick_hook)
        call jp_hl
        call snd_apply
        exx
        ld hl,(snd_accB)
        ld de,(snd_frqB)
        ld bc,(snd_frqC)
        exx
        ld ix,(snd_accC)
        ld hl,(snd_accA)
        ld de,(snd_frqA)
        ld a,(latch_base)
        ld c,a
snd_w1: SNDBODY pA1, pB1, mC1, pC1
        ld a,(KBD)
        rla
        jp nc,snd_w1               ; still inside sync: wait for it to end
snd_w2: SNDBODY pA2, pB2, mC2, pC2
        ld a,(KBD)
        rla
        jp c,snd_w2                ; wait for the falling edge
        ld a,c
        ld (LATCH),a            ; park speaker at mid level while we work
        ld (snd_accA),hl
        ld (snd_accC),ix
        exx
        ld (snd_accB),hl
        exx
        ld hl,frame_ct
        inc (hl)
        ld hl,field_ct
        inc (hl)
        xor a
        ld (fs_last),a
        ret

; count field-sync falling edges seen during busy work (call at least every ~10K T)
fs_poll:
        ld a,(KBD)
        and $80
        push hl
        ld hl,fs_last
        cp (hl)
        jr z,.x
        ld (hl),a
        or a
        jr nz,.x
        ld hl,field_ct
        inc (hl)
.x:     pop hl
        ret

jp_hl:  jp (hl)
no_tick: ret

; write channel state into the mixer (duty patches, freqs, noise mode)
snd_apply:
        ld a,(ch0+CH_DUTY)
        ld (pA1+1),a
        ld (pA2+1),a
        ld hl,(ch0+CH_FRQ)
        ld (snd_frqA),hl
        ld a,(ch1+CH_DUTY)
        ld (pB1+1),a
        ld (pB2+1),a
        ld hl,(ch1+CH_FRQ)
        ld (snd_frqB),hl
        ld a,(ch2+CH_DUTY)
        ld (pC1+1),a
        ld (pC2+1),a
        ld hl,(ch2+CH_FRQ)
        ld (snd_frqC),hl
        ld a,(ch2+CH_MODE)
        or a
        ld a,$7C                ; ld a,ixh
        jr z,.tone
        ld a,$7E                ; ld a,(ix+0)
        ; noise: restart read pointer somewhere inside the program code
        ld hl,(rnd_seed)
        ld a,h
        and $1F
        or $80
        ld h,a
        ld (snd_accC),hl
        ld a,$7E
.tone:  ld (mC1+1),a
        ld (mC2+1),a
        ret

; silence everything
snd_off:
        ld hl,ch0
        ld de,ch0+1
        ld bc,CH_SIZE*3-1
        ld (hl),0
        ldir
        ret

; ---------------------------------------------------------------------------
; SFX sequencer
; segment: frames, frq(2), df(2), duty, dd, mode    frames 0 = end, $FF = jump (dw target)

; play sfx A (index into sfx_table: dw prog / db channel / db prio)
sfx_play:
        push hl
        push de
        push bc
        push ix
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld de,sfx_table
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = program
        inc hl
        ld a,(hl)               ; channel
        inc hl
        ld b,(hl)               ; prio
        ld ix,ch0
        or a
        jr z,.c
        ld ix,ch1
        dec a
        jr z,.c
        ld ix,ch2
.c:     ld a,(ix+CH_PTR)
        or (ix+CH_PTR+1)
        jr z,.free
        ld a,(ix+CH_PRIO)
        cp b
        jr z,.free
        jr nc,.x                ; busy with higher priority
.free:  ld (ix+CH_PTR),e
        ld (ix+CH_PTR+1),d
        ld (ix+CH_CNT),0
        ld (ix+CH_PRIO),b
.x:     pop ix
        pop bc
        pop de
        pop hl
        ret

sfx_tick:
        ld ix,ch0
        call ch_tick
        ld ix,ch1
        call ch_tick
        ld ix,ch2
        ; fall through
ch_tick:
        ld l,(ix+CH_PTR)
        ld h,(ix+CH_PTR+1)
        ld a,h
        or l
        jr nz,.act
        ld (ix+CH_DUTY),0
        ld (ix+CH_MODE),0
        ld (ix+CH_PRIO),0
        ret
.act:   ld a,(ix+CH_CNT)
        or a
        jr nz,.run
.load:  ld a,(hl)
        or a
        jr nz,.notend
        ld (ix+CH_PTR),a
        ld (ix+CH_PTR+1),a
        ld (ix+CH_DUTY),a
        ld (ix+CH_MODE),a
        ld (ix+CH_PRIO),a
        ret
.notend:
        cp $FF
        jr nz,.seg
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr .load
.seg:   ld (ix+CH_CNT),a
        inc hl
        ld a,(hl)
        ld (ix+CH_FRQ),a
        inc hl
        ld a,(hl)
        ld (ix+CH_FRQ+1),a
        inc hl
        ld a,(hl)
        ld (ix+CH_DF),a
        inc hl
        ld a,(hl)
        ld (ix+CH_DF+1),a
        inc hl
        ld a,(hl)
        ld (ix+CH_DUTY),a
        inc hl
        ld a,(hl)
        ld (ix+CH_DD),a
        inc hl
        ld a,(hl)
        ld (ix+CH_MODE),a
        inc hl
        ld (ix+CH_PTR),l
        ld (ix+CH_PTR+1),h
        ret
.run:   dec (ix+CH_CNT)
        ld l,(ix+CH_FRQ)
        ld h,(ix+CH_FRQ+1)
        ld e,(ix+CH_DF)
        ld d,(ix+CH_DF+1)
        add hl,de
        ld (ix+CH_FRQ),l
        ld (ix+CH_FRQ+1),h
        ld a,(ix+CH_DD)
        or a
        ret z
        ld b,a
        ld a,(ix+CH_DUTY)
        bit 7,b
        jr nz,.dneg
        add a,b
        jr nc,.dset
        ld a,255
        jr .dset
.dneg:  add a,b
        jr c,.dset
        xor a
.dset:  ld (ix+CH_DUTY),a
        ret
