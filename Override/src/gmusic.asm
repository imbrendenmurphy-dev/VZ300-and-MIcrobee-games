; =====================================================================
;  gmusic.asm - game-mode sound (upper bank 1): a two-voice soundtrack
;  plus effects, mixed once a frame into a 256-sample ring that every
;  sample site (ISR copy, window copy, idle wait) plays a byte at a time.
;  Voice 1 (speaker line bit 5) = the bass channel.
;  Voice 2 (line bit 0) = the lead channel, or an effect while one plays
;  (a loud effect takes both lines and mutes the bass).
; =====================================================================
SNDBUF      equ $F900           ; 256 samples (latch values)
SND_AHEAD   equ 232             ; keep this many samples queued

GC_PTR      equ 0
GC_WAIT     equ 2
GC_LEN      equ 3
GC_STEP     equ 4
GC_DUTY     equ 6
GC_DECAY    equ 7
GC_DMIN     equ 8
GC_DSTART   equ 9
GC_FLAGS    equ 10              ; bit 7 resting
GC_LOOP     equ 11
GC_SIZE     equ 14

; gm_play: A = tune (0 the ship's main tune, 1 its engine-room tune; both
; load with the ship file into GSBUF), $FF = silence
gm_play:
            push ix
            call .go
            pop ix
            ret
.go:        cp $FF
            jr z,gm_stop
            ld hl,gm_cur
            cp (hl)
            ret z                   ; already playing it
            ld (hl),a
            add a,a
            ld l,a
            ld h,0
            ld de,GSBUF
            add hl,de
            ld a,(hl)
            inc hl
            ld h,(hl)
            ld l,a
            ld ix,gm_ch0
            call .ch
            ld ix,gm_ch1
.ch:        ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (ix+GC_PTR),e
            ld (ix+GC_PTR+1),d
            ld (ix+GC_LOOP),e
            ld (ix+GC_LOOP+1),d
            ld (ix+GC_WAIT),1
            ld (ix+GC_LEN),4
            ld (ix+GC_DUTY),0
            ld (ix+GC_FLAGS),0
            ret
gm_stop:
            ld a,$FF
            ld (gm_cur),a
            xor a
            ld (gm_ch0+GC_PTR+1),a
            ld (gm_ch1+GC_PTR+1),a
            ld (gm_ch0+GC_DUTY),a
            ld (gm_ch1+GC_DUTY),a
            ret

; once a frame: step the tune, then fill the ring
snd_make:
            push ix
            ld ix,gm_ch0
            call gm_ch
            ld ix,gm_ch1
            call gm_ch
            pop ix
            ; ---- voice 1: the bass (muted by a loud effect or music off)
            ld a,(gm_ch0+GC_DUTY)
            ld b,a
            ld a,(music_on)
            or a
            jr nz,.m1
            ld b,a
.m1:        ld a,(snd_mask)
            cp $21
            jr nz,.v1
            ld b,0
.v1:        ld a,b
            ld (.d1+1),a
            ld a,$20                ; the speaker line and/or tape MSB
            ld c,$04
            call so_mask
            ld (.a1+1),a
            ld hl,(gm_ch0+GC_STEP)
            ld (gv1_st),hl
            ; ---- voice 2: an effect, or the lead
            ld a,(snd_mask)
            or a
            jr z,.lead
            and $21
            cp $21
            ld a,$21
            ld c,$06
            jr z,.vol
            ld a,$01
            ld c,$02
.vol:       call so_mask
            ld (.m2+1),a
            ld hl,(snd_step)
            ld (gv2_st),hl
            ld a,128
            ld (.d2+1),a
            ld hl,$09FD             ; add iy,bc
            ld de,$7CFD             ; ld a,iyh
            ld a,(snd_noise)
            or a
            jr z,.tone
            ld hl,$5FED             ; ld a,r
            ld de,$00AD             ; xor l : nop
            jr .tone
.lead:      ld a,$01
            ld c,$02
            call so_mask
            ld (.m2+1),a
            ld hl,(gm_ch1+GC_STEP)
            ld (gv2_st),hl
            ld a,(music_on)
            or a
            jr z,.l0
            ld a,(gm_ch1+GC_DUTY)
.l0:        ld (.d2+1),a
            ld hl,$09FD
            ld de,$7CFD
.tone:      ld (.v2),hl
            ld (.v2+2),de
            ; ---- how many samples to make
            ld a,(snd_rd)
            ld b,a
            ld a,(snd_wr)
            sub b
            cp SND_AHEAD+1
            jr c,.ok
            ld a,b                  ; ran dry: start again from here
            ld (snd_wr),a
            xor a
.ok:        ld b,a
            ld a,SND_AHEAD
            sub b
            ret z
            ret c
            push iy
            exx
            ld b,a
            ld a,(snd_wr)
            ld l,a
            ld h,HIGH(SNDBUF)
            exx
            ld hl,(gv1_ph)
            ld de,(gv1_st)
            ld iy,(gv2_ph)
            ld bc,(gv2_st)
.l:         add hl,de               ; 11  voice 1
            ld a,h                  ; 4
.d1:        cp 0                    ; 7
            sbc a,a                 ; 4
.a1:        and $20                 ; 7
            ex af,af'               ; 4
.v2:        add iy,bc               ; 15  voice 2 (or noise)
            ld a,iyh                ; 8
.d2:        cp 0                    ; 7
            sbc a,a                 ; 4
.m2:        and $01                 ; 7
            exx                     ; 4
            ld c,a                  ; 4
            ex af,af'               ; 4
            or c                    ; 4
            xor LATCH_GAME          ; 7
            ld (hl),a               ; 7
            inc l                   ; 4
            dec b                   ; 4
            exx                     ; 4
            jr nz,.l                ; 12
            ld (gv1_ph),hl
            ld (gv2_ph),iy
            exx
            ld a,l
            ld (snd_wr),a
            exx
            pop iy
            ret

; fill the ring with silence (pause, mode changes)
snd_hush:
            ld hl,SNDBUF
            ld b,0
            ld a,LATCH_GAME
.l:         ld (hl),a
            inc l
            djnz .l
            ret

; one music channel (IX), once a frame
gm_ch:
            ld a,(ix+GC_PTR+1)
            or a
            ret z
            bit 7,(ix+GC_FLAGS)
            jr nz,.dok
            ld a,(ix+GC_DUTY)
            sub (ix+GC_DECAY)
            jr c,.dmin
            cp (ix+GC_DMIN)
            jr nc,.dset
.dmin:      ld a,(ix+GC_DMIN)
.dset:      ld (ix+GC_DUTY),a
.dok:       dec (ix+GC_WAIT)
            ret nz
            ld l,(ix+GC_PTR)
            ld h,(ix+GC_PTR+1)
.next:      ld a,(hl)
            inc hl
            cp $60
            jr c,.note
            cp $80
            jr c,.len
            cp $90
            jr c,.inst
            cp $91
            jr z,.llen
            ; $FE / $FF: back to the start
            ld l,(ix+GC_LOOP)
            ld h,(ix+GC_LOOP+1)
            jr .next
.len:       sub $5F
            ld (ix+GC_LEN),a
            jr .next
.llen:      ld a,(hl)
            inc hl
            ld (ix+GC_LEN),a
            jr .next
.inst:      and $0F
            push hl
            add a,a
            add a,a
            ld e,a
            ld d,0
            ld hl,ginstr
            add hl,de
            ld a,(hl)
            ld (ix+GC_DSTART),a
            inc hl
            ld a,(hl)
            ld (ix+GC_DECAY),a
            inc hl
            ld a,(hl)
            ld (ix+GC_DMIN),a
            pop hl
            jr .next
.note:      ld (ix+GC_PTR),l
            ld (ix+GC_PTR+1),h
            ld b,a
            ld a,(ix+GC_LEN)
            ld (ix+GC_WAIT),a
            ld a,b
            or a
            jr z,.rest
            add a,a
            ld e,a
            ld d,0
            ld hl,gnote_steps-2
            add hl,de
            ld a,(hl)
            ld (ix+GC_STEP),a
            inc hl
            ld a,(hl)
            ld (ix+GC_STEP+1),a
            ld a,(ix+GC_DSTART)
            ld (ix+GC_DUTY),a
            res 7,(ix+GC_FLAGS)
            ret
.rest:      ld (ix+GC_DUTY),0
            set 7,(ix+GC_FLAGS)
            ret

gm_ch0:     ds GC_SIZE
gm_ch1:     ds GC_SIZE
gm_cur:     db $FF
gv1_ph:     ds 2
gv1_st:     ds 2
gv2_ph:     ds 2
gv2_st:     ds 2
            include "gen/gsongs.inc"
