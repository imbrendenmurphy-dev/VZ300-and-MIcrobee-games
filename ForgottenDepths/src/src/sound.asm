; =====================================================================
;  sound.asm : 3-voice pulse mixer (after the Cybernoid VZ player) + drums
;
;  wait_frame plays until the next field-sync edge. Three voices are
;  pulse-interleaved, 184 T per sample round (19.3 kHz):
;     voice A  lead      HL  += BC        (main set)
;     voice B  harmony   HL' += BC'       (alt set)  - sound effects use it
;     voice C  bass      IX  += SP        (longest slot = loudest)
;  out = (acc.hi < width).  A drum stream fires short noise/thump bursts
;  at the start of a frame.
; =====================================================================
sv_acca:  dw 0
sv_inca:  dw 0
sv_pwa:   db 0
sv_accb:  dw 0
sv_incb:  dw 0
sv_pwb:   db 0
sv_accc:  dw 0
sv_incc:  dw 0
sv_pwc:   db 0
sv_noise: db 0
sv_sp:    dw 0
drum_pend: db 0
noise_ptr: dw $8000
lbase:    db M0O            ; current latch base (mode/css), speaker idle level
frame:    db 0              ; frame counter
frame_w:  dw 0

wait_frame:
        push ix
        ld a,(drum_pend)
        or a
        call nz,drum_play
        ; widths into the loops
        ld a,(sv_pwa)
        ld (.q1+1),a
        ld (.r1+1),a
        ld (.n1+1),a
        ld (.m1+1),a
        ld a,(sv_pwb)
        ld (.q2+1),a
        ld (.r2+1),a
        ld (.n2+1),a
        ld (.m2+1),a
        ld a,(sv_pwc)
        ld (.q3+1),a
        ld (.r3+1),a
        ld (.n3+1),a
        ld (.m3+1),a
        ld a,(lbase)
        ld d,a
        ld e,$21
        exx
        ld d,a
        ld e,$21
        ld hl,(sv_accb)
        ld bc,(sv_incb)
        exx
        ld hl,(sv_acca)
        ld bc,(sv_inca)
        ld ix,(sv_accc)
        ld (sv_sp),sp
        ld sp,(sv_incc)
        ld a,(sv_noise)
        or a
        jp nz,.nz
.l1:
        add hl,bc
        ld a,h
.q1: cp 0
        sbc a,a
        and e
        xor d
        ld (LATCH),a
        exx
        add hl,bc
        ld a,h
.q2: cp 0
        sbc a,a
        and e
        xor d
        ld (LATCH),a
        add ix,sp
        ld a,ixh
.q3: cp 0
        sbc a,a
        and e
        xor d
        exx
        ld (LATCH),a
        ld a,(LATCH)
        rla
        jp nc,.l1               ; while in field sync
.l2:
        add hl,bc
        ld a,h
.r1: cp 0
        sbc a,a
        and e
        xor d
        ld (LATCH),a
        exx
        add hl,bc
        ld a,h
.r2: cp 0
        sbc a,a
        and e
        xor d
        ld (LATCH),a
        add ix,sp
        ld a,ixh
.r3: cp 0
        sbc a,a
        and e
        xor d
        exx
        ld (LATCH),a
        ld a,(LATCH)
        rla
        jp c,.l2                ; until field sync starts
        jp .out
.nz:
.z1:
        add hl,bc
        ld a,h
.n1: cp 0
        sbc a,a
        and e
        xor d
        ld (LATCH),a
        exx
        add hl,bc
        ld a,r
        xor h
.n2: cp 0
        sbc a,a
        and e
        xor d
        ld (LATCH),a
        add ix,sp
        ld a,ixh
.n3: cp 0
        sbc a,a
        and e
        xor d
        exx
        ld (LATCH),a
        ld a,(LATCH)
        rla
        jp nc,.z1
.z2:
        add hl,bc
        ld a,h
.m1: cp 0
        sbc a,a
        and e
        xor d
        ld (LATCH),a
        exx
        add hl,bc
        ld a,r
        xor h
.m2: cp 0
        sbc a,a
        and e
        xor d
        ld (LATCH),a
        add ix,sp
        ld a,ixh
.m3: cp 0
        sbc a,a
        and e
        xor d
        exx
        ld (LATCH),a
        ld a,(LATCH)
        rla
        jp c,.z2
.out:   ld sp,(sv_sp)
        ld (sv_acca),hl
        ld (sv_accc),ix
        exx
        ld (sv_accb),hl
        exx
        ld a,(lbase)
        ld (LATCH),a
        ld hl,frame
        inc (hl)
        ld hl,(frame_w)
        inc hl
        ld (frame_w),hl
        pop ix
        ret

; ---------------------------------------------------------------------
; drum burst: A = type<<6 | n   (1 kick thump, 2 snare noise, 3 hat)
; ---------------------------------------------------------------------
drum_play:
        ld c,a
        xor a
        ld (drum_pend),a
        ld a,(lbase)
        ld d,a
        ld a,c
        rlca
        rlca
        and 3
        cp 1
        jr z,.kick
        ld b,a
        ld a,c
        and $3F
        add a,a
        dec b
        jr nz,.hat
        add a,a                 ; snare: n*4 samples
.hat:   ld b,a
        ld hl,(noise_ptr)
.ns:    ld a,(hl)
        inc hl
        and $21
        xor d
        ld (LATCH),a
        ld a,6
.nd:    dec a
        jr nz,.nd
        djnz .ns
        ld a,h
        and $1F
        or $80
        ld h,a
        ld (noise_ptr),hl
        ld a,d
        ld (LATCH),a
        ret
.kick:  ld hl,KICKT
        ld a,c
        and $3F
        ld b,a                  ; half cycles (<= 8)
        ld a,d
.kh:    xor $21
        ld (LATCH),a
        ld e,(hl)
        inc hl
.kd:    push af
        pop af
        dec e
        jr nz,.kd               ; 33 T per count
        djnz .kh
        ld a,d
        ld (LATCH),a
        ret
KICKT:  db 60,80,105,130,160,190,220,250

; ---------------------------------------------------------------------
; music sequencer: three voice channels + a drum stream, once per frame
; channel struct: ptr(2) start(2) count(1) pw(1) decay(1) floor(1) inc(2) ipw(1)
; ---------------------------------------------------------------------
CH_PTR  EQU 0
CH_START EQU 2
CH_CNT  EQU 4
CH_PW   EQU 5
CH_DEC  EQU 6
CH_FLR  EQU 7
CH_INC  EQU 8
CH_IPW  EQU 10
chan_a: ds 12
chan_b: ds 12
chan_c: ds 12
chan_d: ds 12
mus_on: db 0
mus_track: db 0
mus_en: db 1                ; T toggles the music
sfx_ptr: dw 0               ; 0 = none
sfx_mute: db 0              ; 1 = sound effects off
t_last: db 0

; A = track: 1.. common (title, end, boss), $10.. chapter tracks; 0 = silence
music_play:
        ld (mus_track),a
        or a
        jr z,music_stop
        ld c,a
        ld a,(mus_en)
        or a
        jr z,music_stop
        ld a,(bank_cur)
        push af
        call bank1
        ld a,c
        cp $10
        jr nc,.lev
        dec a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,TRACKTAB
        jr .go
.lev:   sub $10
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,(LB_TRK)
.go:    add hl,de
        ld ix,chan_a
        call .one
        ld ix,chan_b
        call .one
        ld ix,chan_c
        call .one
        ld ix,chan_d
        call .one
        ld a,1
        ld (mus_on),a
        pop af
        jp bank_set
.one:   ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        jp ch_init
music_stop:
        xor a
        ld (mus_on),a
        ld (sv_pwa),a
        ld (sv_pwb),a
        ld (sv_pwc),a
        ld (drum_pend),a
        ret
ch_init:
        ld (ix+CH_PTR),e
        ld (ix+CH_PTR+1),d
        ld (ix+CH_START),e
        ld (ix+CH_START+1),d
        ld (ix+CH_CNT),1
        ld (ix+CH_PW),0
        ld (ix+CH_DEC),2
        ld (ix+CH_FLR),0
        ret

; T key: music on/off (call once per frame)
music_toggle:
        ld a,(KR0)
        cpl
        and 1                   ; T held?
        ld hl,t_last
        ld c,(hl)
        ld (hl),a
        cp c
        ret z
        or a
        ret z                   ; act on the press only
        ld a,(mus_en)
        xor 1
        ld (mus_en),a
        jr z,music_stop
        ld a,(mus_track)
        jp music_play

; per-frame tick: music + sfx -> voice registers
sound_tick:
        call music_toggle
        ld hl,.t
        jp with_bank1
.t:     ld a,(mus_on)
        or a
        jr z,.nomus
        ld ix,chan_a
        call ch_tick
        ld a,(ix+CH_PW)
        ld (sv_pwa),a
        ld l,(ix+CH_INC)
        ld h,(ix+CH_INC+1)
        ld (sv_inca),hl
        ld ix,chan_c
        call ch_tick
        ld a,(ix+CH_PW)
        ld (sv_pwc),a
        ld l,(ix+CH_INC)
        ld h,(ix+CH_INC+1)
        ld (sv_incc),hl
        call drum_tick
        ld ix,chan_b
        call ch_tick
.nomus:
        ; sfx overrides voice B
        ld hl,(sfx_ptr)
        ld a,h
        or l
        jr z,.nosfx
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        cp 255
        jr z,.sfxend
        ld (sv_pwb),a
        ld (sv_incb),de
        ld a,(hl)
        inc hl
        ld (sv_noise),a
        ld (sfx_ptr),hl
        ret
.sfxend:
        ld hl,0
        ld (sfx_ptr),hl
        xor a
        ld (sv_noise),a
        ld (sv_pwb),a
.nosfx:
        ld a,(mus_on)
        or a
        ret z
        ld ix,chan_b
        ld a,(ix+CH_PW)
        ld (sv_pwb),a
        ld l,(ix+CH_INC)
        ld h,(ix+CH_INC+1)
        ld (sv_incb),hl
        ret

; drum stream: (drum byte or 0, frames) pairs, $FF loops
drum_tick:
        ld ix,chan_d
        dec (ix+CH_CNT)
        ret nz
        ld l,(ix+CH_PTR)
        ld h,(ix+CH_PTR+1)
.n:     ld a,(hl)
        inc hl
        cp $FF
        jr nz,.d
        ld l,(ix+CH_START)
        ld h,(ix+CH_START+1)
        jr .n
.d:     ld c,(hl)
        inc hl
        ld (ix+CH_CNT),c
        ld (ix+CH_PTR),l
        ld (ix+CH_PTR+1),h
        or a
        ret z
        ld (drum_pend),a
        ret

; HL = sfx data
sfx:
        ld a,(sfx_mute)
        or a
        ret nz
        ld (sfx_ptr),hl
        ret

ch_tick:
        ; envelope
        ld a,(ix+CH_PW)
        sub (ix+CH_DEC)
        jr c,.flr
        cp (ix+CH_FLR)
        jr nc,.pwok
.flr:   ld a,(ix+CH_FLR)
.pwok:  ld (ix+CH_PW),a
        dec (ix+CH_CNT)
        ret nz
        ld l,(ix+CH_PTR)
        ld h,(ix+CH_PTR+1)
.next:  ld a,(hl)
        inc hl
        cp $FF
        jr nz,.nloop
        ld l,(ix+CH_START)
        ld h,(ix+CH_START+1)
        jr .next
.nloop: cp $FE
        jr nz,.note
        ld a,(hl)
        inc hl
        ld (ix+CH_IPW),a
        ld (ix+CH_PW),a
        ld a,(hl)
        inc hl
        ld (ix+CH_DEC),a
        ld a,(hl)
        inc hl
        ld (ix+CH_FLR),a
        jr .next
.note:  ld c,(hl)               ; duration
        inc hl
        ld (ix+CH_CNT),c
        ld (ix+CH_PTR),l
        ld (ix+CH_PTR+1),h
        or a
        jr z,.rest
        ; inc = NOTEINC[a]
        add a,a
        ld e,a
        ld d,0
        ld hl,NOTEINC
        add hl,de
        ld a,(hl)
        ld (ix+CH_INC),a
        inc hl
        ld a,(hl)
        ld (ix+CH_INC+1),a
        ld a,(ix+CH_IPW)
        ld (ix+CH_PW),a
        ret
.rest:  ld (ix+CH_PW),0
        ld a,(ix+CH_FLR)
        or a
        ret z
        ld (ix+CH_PW),0
        ret
