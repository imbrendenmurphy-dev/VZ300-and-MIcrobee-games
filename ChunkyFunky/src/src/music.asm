; =====================================================================
;  music.asm - three-voice pulse music (the Dracula's Castle II / Crownfall
;  player, music only). The voices are mixed in a 211 T sample loop that runs
;  from the end of the frame's drawing until field sync starts.
;  Stream: $00 rest, $01-$5F note (C1 = 1), $60-$7F length, $80-$8F instrument,
;  $90 lo hi slide, $91 n length, $FE lo hi jump, $FF stop
; =====================================================================
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

m_tick:
            ld ix,m_chan1
            call m_ch
            ld ix,m_chan2
            call m_ch
            ld ix,m_chan3
            call m_ch
            ld hl,(m_chan1+CH_STEP)
            ld (ml_s1+1),hl
            ld a,(m_chan1+CH_DUTY)
            ld (ml_d1+1),a
            ld hl,(m_chan2+CH_STEP)
            ld (ml_s2+1),hl
            ld a,(m_chan2+CH_DUTY)
            ld (ml_d2+1),a
            ld ix,m_chan3
            ld a,(ix+CH_DUTY)
            ld (ml_d3+1),a
            ld (ml_d3n+1),a
            ld l,(ix+CH_STEP)
            ld h,(ix+CH_STEP+1)
            ld (ml_s3+1),hl
            ld hl,ml_tone
            bit 0,(ix+CH_FLAGS)
            jr z,.t
            ld hl,ml_noise
.t:         ld (ml_j3+1),hl
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

; ---------------------------------------------------------------------
; fe_wait: music tick, then play samples until the next field sync
; starts (FS falling). Returns at the very start of the sync gap.
fe_wait:
            push ix
            call m_tick
            ld a,(FSREAD)
            rla
            ld a,$D2                ; JP NC: loop while FS low
            jr nc,.low
            ld a,$DA                ; JP C: loop while FS high
.low:       ld (ml_cond),a
            ld (ml_cond2),a
            ld hl,(m_ph1)
            exx
            ld hl,(m_ph2)
            exx
            ld ix,(m_ph3)
            jp mloop
ml_out:     ld a,(ml_cond)
            cp $DA
            jr z,.done
            ld a,$DA
            ld (ml_cond),a
            ld (ml_cond2),a
            jp mloop
.done:      ld (m_ph1),hl
            exx
            ld (m_ph2),hl
            exx
            ld (m_ph3),ix
            ld a,(fe_latch)
            ld (LATCH),a
            pop ix
            ret

mloop:
ml_s1:      ld bc,0                 ; 10
            add hl,bc               ; 11
            ld a,h                  ; 4
ml_d1:      cp 0                    ; 7
            sbc a,a                 ; 4
            ld e,a                  ; 4
            exx                     ; 4
ml_s2:      ld bc,0                 ; 10
            add hl,bc               ; 11
            ld a,h                  ; 4
ml_d2:      cp 0                    ; 7
            exx                     ; 4
            sbc a,a                 ; 4
            or e                    ; 4
            and $20                 ; 7
            ld e,a                  ; 4
ml_j3:      jp ml_tone              ; 10
ml_tone:
ml_s3:      ld bc,0                 ; 10
            add ix,bc               ; 15
            ld a,ixh                ; 8
ml_d3:      cp 0                    ; 7
            sbc a,a                 ; 4
            and $20                 ; 7
            or e                    ; 4
ml_x1:      xor $09                 ; 7
            ld (LATCH),a            ; 13
            ld a,(FSREAD)           ; 13
            rla                     ; 4
ml_cond:    jp c,mloop              ; 10
            jp ml_out               ; total 211 T a sample
ml_noise:   add ix,ix               ; 15
            sbc a,a                 ; 4
            and $2D                 ; 7
            xor ixl                 ; 8
            ld ixl,a                ; 8
ml_d3n:     cp 0                    ; 7
            sbc a,a                 ; 4
            and $20                 ; 7
            or e                    ; 4
ml_x2:      xor $09                 ; 7
            ld (LATCH),a            ; 13
            ld a,(FSREAD)           ; 13
            rla                     ; 4
ml_cond2:   jp c,mloop              ; 10
            jp ml_out

; set_latch: A = mode/colour-set bits ($00 text, $10 text CSS, $08 mode 1, $18 mode 1 CSS)
set_latch:
            or $01
            ld (fe_latch),a
            ld (LATCH),a
            ld (ml_x1+1),a
            ld (ml_x2+1),a
            ret
