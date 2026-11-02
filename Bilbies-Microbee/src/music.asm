; ---------------------------------------------------------------------------
; Music: a three-voice tracker-style player, in the manner of the Cybernoid
; conversion. The three voices take turns at the speaker (175 T a round,
; about 20 kHz, above hearing), each a pulse whose width is its
; volume, so they mix instead of clashing. Voice 1 bass, voice 2 lead,
; voice 3 chords; the drums take over voice 3's slot (kick = falling tone,
; snare / hi-hat = noise read from the ROM).
;
; mus_init (HL = song)  mus_tick (once a frame)  mus_frame (plays until the
; next field sync starts; interrupts must be off)
;
; Channel streams: $00-$5F note (C1 = 0) + frames, $60 rest + frames,
; $80+n instrument n, $FD dw = call pattern, $FC return, $FF dw = jump,
; $FE end of song. Drum stream: note 1 kick, 2 snare, 3 hi-hat.
; ---------------------------------------------------------------------------
MCH     equ 16                  ; channel record
VDEL    equ 10                  ; frames before vibrato starts

mch:    ds 4*MCH                ; ptr, timer, note, inst, pos, ret, envp, arpp, arps, vib
mv1:    ds 3                    ; voice outputs: increment, duty
mv2:    ds 3
mv3:    ds 3
ma1:    dw 0                    ; phase accumulators
ma2:    dw 0
ma3:    dw 0
mnoise: dw $0123
mf_sp:  dw 0
dr_t:   db 0
dr_f:   db 0
dr_n:   db 0
mus_endf: db 0
mgap:   db 0                    ; samples the last pause lasted

mus_init:
        ld de,mch
        ld b,4
.l:     ld a,(hl)
        ld (de),a
        inc hl
        inc de
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        ld a,1
        ld (de),a               ; timer
        inc de
        ld a,$FF
        ld (de),a               ; rest
        inc de
        xor a
        ld (de),a               ; instrument
        ld a,e
        add a,MCH-4
        ld e,a
        adc a,d
        sub e
        ld d,a
        djnz .l
        xor a
        ld (mus_endf),a
        ld (dr_t),a
        ld (dr_n),a
        ld (mv1+2),a
        ld (mv2+2),a
        ld (mv3+2),a
        jp mus_duty

; ---- once a frame -------------------------------------------------------------
mus_tick:
        ld ix,mch
        ld iy,mv1
        ld b,3
.c:     push bc
        call ch_tick
        pop bc
        ld de,MCH
        add ix,de
        inc iy
        inc iy
        inc iy
        djnz .c
        call dr_tick
mus_duty:
        ld a,(mv1+2)
        ld (d1a+1),a
        ld (d1n+1),a
        ld a,(mv2+2)
        ld (d2a+1),a
        ld (d2n+1),a
        ld a,(mv3+2)
        ld (d3a+1),a
        ret

; next event of channel IX -> carry if a note or rest started this frame
ch_ev:  dec (ix+2)
        jr z,.ev
        or a
        ret
.ev:    ld l,(ix+0)
        ld h,(ix+1)
.rd:    ld a,(hl)
        inc hl
        cp $60
        jr c,.note
        jr z,.rest
        cp $FC
        jr c,.inst
        jr z,.ret
        cp $FD
        jr z,.call
        cp $FF
        jr z,.jump
        ld a,1                  ; $FE: end of the song
        ld (mus_endf),a
        dec hl
        ld (ix+0),l
        ld (ix+1),h
        ld (ix+3),$FF
        ld (ix+2),1
        or a
        ret
.inst:  sub $80
        ld (ix+4),a
        jr .rd
.call:  ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ix+6),l
        ld (ix+7),h
        ex de,hl
        jr .rd
.ret:   ld l,(ix+6)
        ld h,(ix+7)
        jr .rd
.jump:  ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jr .rd
.rest:  ld a,$FF
.note:  ld (ix+3),a
        ld (ix+5),0
        ld a,(hl)
        inc hl
        ld (ix+2),a
        ld (ix+0),l
        ld (ix+1),h
        scf
        ret

; a tone channel: IX = channel, IY = its voice output
ch_tick:
        call ch_ev
        jr nc,.play
        ld a,(ix+3)
        inc a
        jr z,.play
        ld a,(ix+4)             ; a new note: the instrument's envelope and arpeggio
        ld l,a
        add a,a
        add a,l
        add a,a
        ld l,a
        ld h,0
        ld de,INSTS
        add hl,de
        ld a,(hl)
        ld (ix+8),a
        inc hl
        ld a,(hl)
        ld (ix+9),a
        inc hl
        ld a,(hl)
        ld (ix+10),a
        ld (ix+12),a
        inc hl
        ld a,(hl)
        ld (ix+11),a
        ld (ix+13),a
        inc hl
        ld a,(hl)
        ld (ix+14),a
.play:  ld a,(ix+3)
        cp $FF
        jp z,.sil
        ld l,(ix+8)             ; volume, the envelope holding its last value
        ld h,(ix+9)
        ld c,(hl)
        inc hl
        ld a,(hl)
        cp $FF
        jr z,.eh
        ld (ix+8),l
        ld (ix+9),h
.eh:    ld l,(ix+10)            ; arpeggio
        ld h,(ix+11)
        ld a,(hl)
        add a,(ix+3)
        ld b,a
        inc hl
        ld a,(hl)
        cp $80
        jr nz,.as
        ld l,(ix+12)
        ld h,(ix+13)
.as:    ld (ix+10),l
        ld (ix+11),h
        ld l,b
        ld h,0
        add hl,hl
        ld de,FREQ
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = increment
        ld a,(ix+14)
        or a
        jr z,.nv
        ld a,(ix+5)             ; vibrato after VDEL frames
        cp VDEL
        jr c,.nv
        and 7
        ld l,a
        ld h,0
        push de
        ld de,VIBT
        add hl,de
        ld a,(hl)
        pop hl                  ; HL = increment
        push hl
        add hl,hl
        ld e,h
        ld d,0                  ; DE = increment / 128
        pop hl
        or a
        jr z,.v0
        jp p,.vp
.vn:    push af
        or a
        sbc hl,de
        pop af
        inc a
        jr nz,.vn
        jr .v0
.vp:    add hl,de
        dec a
        jr nz,.vp
.v0:    ex de,hl
.nv:    ld a,(ix+5)
        inc a
        jr z,.np
        ld (ix+5),a
.np:    ld (iy+0),e
        ld (iy+1),d
        ld b,0
        ld hl,VOLT
        add hl,bc
        ld a,(hl)
        ld (iy+2),a
        ret
.sil:   ld (iy+2),0
        ret

; the drums (channel 4): kick takes over voice 3 for 4 frames, snare and
; hi-hat play noise in voice 3's slot for a number of samples
dr_tick:
        call ch_ev
        jr nc,.go
        ld a,(ix+3)
        inc a
        jr z,.go
        dec a
        ld (dr_t),a
        xor a
        ld (dr_f),a
.go:    xor a
        ld (dr_n),a
        ld a,(dr_f)
        cp 8
        ret nc
        ld e,a
        inc a
        ld (dr_f),a
        ld d,0
        ld a,(dr_t)
        dec a
        jr z,.kick
        dec a
        ld hl,SNT
        jr z,.n
        dec a
        ret nz
        ld hl,HHT
.n:     add hl,de
        ld a,(hl)
        ld (dr_n),a
        ret
.kick:  ld a,e
        cp 4
        ret nc
        ld hl,KICKT
        add hl,de
        add hl,de
        add hl,de
        ld de,mv3
        ld bc,3
        ldir
        ret
KICKT:  dw 160*65536*175/3546900 : db 124
        dw 112*65536*175/3546900 : db 116
        dw 80*65536*175/3546900 : db 96
        dw 58*65536*175/3546900 : db 60
SNT:    db 110,80,56,36,20,10,0,0
HHT:    db 26,8,0,0,0,0,0,0
VIBT:   db 0,1,2,1,0,-1,-2,-1
VOLT:   db 0,6,10,14,18,24,30,36,44,52,60,70,80,92,106,120

; ---- play until the next field sync starts ---------------------------------------
; voice 1: HL/BC, voice 2: HL'/BC', voice 3: IX/SP, D = latch, E = $21.
; The voices are played for a counted number of 175 T samples (about 20 kHz,
; so the switching between them is above hearing), worked out from the last
; frame so that they end just before the field sync; a silent wait follows.
mus_frame:
        ; catch the voices up by the length of the pause, so each note stays
        ; in step with real time (it was silent, not stopped)
        ld a,(mgap)
        or a
        jr z,.ng
        ld hl,(ma1)
        ld de,(mv1)
        call madd
        ld (ma1),hl
        ld a,(mgap)
        ld hl,(ma2)
        ld de,(mv2)
        call madd
        ld (ma2),hl
        ld a,(mgap)
        ld hl,(ma3)
        ld de,(mv3)
        call madd
        ld (ma3),hl
.ng:    ld (mf_sp),sp
        ld a,(v_spkoff)
        ld d,a
        ld e,$21
        exx
        ld d,a
        ld e,$21
        ld hl,(ma2)
        ld bc,(mv2)
        exx
        ld hl,(ma1)
        ld bc,(mv1)
        ld iy,(mnoise)
        ld a,(dr_n)
        or a
        jr z,mn_end
        ld ixl,a
        jp mn
mn_end: ld a,iyh
        and $3F
        ld iyh,a
        ld (mnoise),iy
        ld ix,(ma3)
        ld iy,CHUNK             ; IYL = samples left in the chunk, IYH = chunks
        ld a,$D2                ; jp nc,mt_exit: play until the sync starts
        ld hl,mt_exit
        ex af,af'
        ld a,(LATCH)            ; (in the sync now? then until it ends first)
        rla
        jr c,.s
        ex af,af'
        ld a,$DA                ; jp c,mt_end
        ld hl,mt_end
        ex af,af'
.s:     ex af,af'
        ld (mt_cond),a
        ld (mt_cond+1),hl
        ld hl,(ma1)
        ld sp,(mv3)
        jp mt
mt_end: ld a,$D2                ; the sync has ended: now play until the next
        ld (mt_cond),a
        ld a,mt_exit&255
        ld (mt_cond+1),a
        ld a,mt_exit>>8
        ld (mt_cond+2),a
        jp mt_more
mt_exit:
        ld sp,(mf_sp)
        ld (ma1),hl
        ld (ma3),ix
        exx
        ld (ma2),hl
        exx
        ld a,(v_spkoff)
        ld (LATCH),a
        ; the pause before the next music = a frame less the samples played
        ld a,iyh
        inc a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; x CHUNK
        ld a,(dr_n)
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        ld hl,FRSAMP
        or a
        sbc hl,de
        jr nc,.g0
        ld hl,0
.g0:    ld a,h
        or a
        ld a,l
        jr z,.g1
        ld a,255
.g1:    ld (mgap),a
        ret
FRSAMP  equ 71136/175           ; samples in a frame (312 lines x 228 T)
CHUNK   equ 32

; HL += DE * A
madd:   ld b,8
.l:     srl a
        jr nc,.s
        add hl,de
.s:     sla e
        rl d
        djnz .l
        ret

        MACRO MVOICES d1,d2
        add hl,bc               ; 11
        ld a,h                  ; 4
d1:     cp 0                    ; 7
        sbc a,a                 ; 4
        and e                   ; 4
        xor d                   ; 4
        ld (LATCH),a            ; 13  voice 1
        exx                     ; 4
        add hl,bc               ; 11
        ld a,h                  ; 4
d2:     cp 0                    ; 7
        sbc a,a                 ; 4
        and e                   ; 4
        xor d                   ; 4
        ld (LATCH),a            ; 13  voice 2 (51 after voice 1)
        ENDM

; the voices, in chunks of CHUNK samples; between chunks, look at the sync
mt:     MVOICES d1a,d2a
        add ix,sp               ; 15
        ld a,ixh                ; 8
d3a:    cp 0                    ; 7
        sbc a,a                 ; 4
        and e                   ; 4
        xor d                   ; 4
        exx                     ; 4
        ld (LATCH),a            ; 13  voice 3 (59 after voice 2)
        dec iyl                 ; 8
        jp nz,mt                ; 10  (65 to voice 1) = 175
        ld a,(LATCH)            ; 13
        rla                     ; 4
mt_cond: jp nc,mt_exit          ; 10  (jp nc: sync started / jp c: sync ended)
mt_more: inc iyh                ; 8
        ld iyl,CHUNK            ; 11
        jp mt                   ; 10  (48 T more, once a chunk)
; noise in voice 3's slot, IXL samples
mn:     MVOICES d1n,d2n
        ld a,(iy+0)             ; 19
        and e                   ; 4
        xor d                   ; 4
        inc iy                  ; 10
        nop                     ; 4
        exx                     ; 4
        ld (LATCH),a            ; 13  (58)
        dec ixl                 ; 8
        jp nz,mn                ; 10  = 174
        jp mn_end
