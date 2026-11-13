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
        push af
        ld a,(demo_mode) : or a : jr z,.loud
        pop af : ret
.loud:  pop af
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
