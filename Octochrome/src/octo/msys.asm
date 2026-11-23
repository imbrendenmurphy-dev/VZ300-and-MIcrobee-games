; msys.asm - the Crownfall channel sequencer (m_ch), shared with CHUNKY FUNKY
CH_PTR      equ 0
CH_WAIT     equ 2
CH_LEN      equ 3
CH_STEP     equ 4
CH_DUTY     equ 6
CH_DECAY    equ 7
CH_DMIN     equ 8
CH_DSTART   equ 9
CH_FLAGS    equ 12
CH_SLIDE    equ 13
CH_SIZE     equ 16

; m_start: start the demo tune from its first bar
m_start:
            ld hl,m_chan1
            ld de,m_chan1+1
            ld bc,CH_SIZE*3+6-1
            ld (hl),0
            ldir
            ld a,$5A
            ld (m_ph3),a            ; the noise generator needs a seed
            ld hl,song_main
            ld ix,m_chan1
            ld b,3
.l:         ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (ix+CH_PTR),e
            ld (ix+CH_PTR+1),d
            ld (ix+CH_WAIT),1
            ld (ix+CH_LEN),6
            ld de,CH_SIZE
            add ix,de
            djnz .l
            ret

; IX = channel
m_ch:
            ld a,(ix+CH_PTR+1)
            or a
            jr nz,.active
            ld (ix+CH_DUTY),0
            ret
.active:    bit 7,(ix+CH_FLAGS)
            jr z,.snd
            ld (ix+CH_DUTY),0
            jr .dok2
.snd:       ld a,(ix+CH_DUTY)
            sub (ix+CH_DECAY)
            jr c,.dmin
            cp (ix+CH_DMIN)
            jr nc,.dok
.dmin:      ld a,(ix+CH_DMIN)
.dok:       ld (ix+CH_DUTY),a
.dok2:      ld a,(ix+CH_SLIDE)
            or (ix+CH_SLIDE+1)
            jr z,.ns
            ld l,(ix+CH_STEP)
            ld h,(ix+CH_STEP+1)
            ld e,(ix+CH_SLIDE)
            ld d,(ix+CH_SLIDE+1)
            add hl,de
            ld (ix+CH_STEP),l
            ld (ix+CH_STEP+1),h
.ns:        dec (ix+CH_WAIT)
            ret nz
            ld l,(ix+CH_PTR)
            ld h,(ix+CH_PTR+1)
.next:      ld a,(hl)
            inc hl
            cp $60
            jr c,.note
            cp $80
            jr c,.len
            cp $90
            jr c,.inst
            jr z,.slide
            cp $91
            jr z,.llen
            cp $FE
            jr z,.jump
            ld (ix+CH_PTR+1),0
            ld (ix+CH_DUTY),0
            ret
.len:       sub $5F
            ld (ix+CH_LEN),a
            jr .next
.llen:      ld a,(hl)
            inc hl
            ld (ix+CH_LEN),a
            jr .next
.inst:      and $0F
            push hl
            add a,a
            add a,a
            ld e,a
            ld d,0
            ld hl,instruments
            add hl,de
            ld a,(hl)
            ld (ix+CH_DSTART),a
            inc hl
            ld a,(hl)
            ld (ix+CH_DECAY),a
            inc hl
            ld a,(hl)
            ld (ix+CH_DMIN),a
            inc hl
            ld a,(hl)
            ld (ix+CH_FLAGS),a
            pop hl
            jr .next
.slide:     ld a,(hl)
            ld (ix+CH_SLIDE),a
            inc hl
            ld a,(hl)
            ld (ix+CH_SLIDE+1),a
            inc hl
            jr .next
.jump:      ld e,(hl)
            inc hl
            ld d,(hl)
            ex de,hl
            jr .next
.note:      ld (ix+CH_PTR),l
            ld (ix+CH_PTR+1),h
            ld b,a
            ld a,(ix+CH_LEN)
            ld (ix+CH_WAIT),a
            ld a,b
            or a
            jr z,.rest
            add a,a
            ld e,a
            ld d,0
            ld hl,note_steps-2
            add hl,de
            ld a,(hl)
            ld (ix+CH_STEP),a
            inc hl
            ld a,(hl)
            ld (ix+CH_STEP+1),a
            ld a,(ix+CH_DSTART)
            ld (ix+CH_DUTY),a
            res 7,(ix+CH_FLAGS)
            ret
.rest:      ld (ix+CH_DUTY),0
            set 7,(ix+CH_FLAGS)
            ret

