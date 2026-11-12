; ============================================================================
;  TITLE SCREEN and the three-voice music player
;
;  The title runs with interrupts off and owns the CPU, as the Cybernoid
;  front end does.  Three pulse voices are mixed by interleaving in one
;  188 T-state pass (18.9 kHz), with pulse width as volume.  Each field:
;    field sync starts -> save the voices, play any drum burst, step the
;    sequencer, update the screen (video RAM is free until the display
;    starts), read the controls -> voices play on through the rest of the
;    field sync and the whole display.
;  Only the work at the start of each field is silent (~5-8%).
;
;  Voice 1: HL acc, DE step, B duty   (C = latch with speaker off)
;  Voice 2: the same in the alternate set
;  Voice 3: IX acc, SP step, IYL duty (SP is free: interrupts are off)
; ============================================================================

; channel record (three tone channels)
TC_PTR   equ 0
TC_START equ 2
TC_DUR   equ 4
TC_NOTE  equ 5
TC_ENV   equ 6
TC_ARPB  equ 8
TC_ARP   equ 10
TC_OFS   equ 12
TC_DUTY  equ 13
TC_STEP  equ 14
TC_INSE  equ 16
TCSIZE   equ 18

title:
        di
        ld sp,STACKTOP
        ld a,$28
        ld (latch),a
        ld (LATCH),a
        call stop_music
        ld hl,PK_FRONT          ; the front-end pack (title art and tune)
        call must_load
        ; unpack the art into the frame buffer
        ld hl,FR_ART
        ld de,FB
.un:    ld a,(hl)
        or a
        jr z,.und
        ld b,a
        inc hl
        ld a,(hl)
        inc hl
.ur:    ld (de),a
        inc de
        djnz .ur
        jr .un
.und:   ; voices and sequencer
        ld hl,TITLEVARS
        ld de,TITLEVARS+1
        ld bc,TITLEVARS_END-TITLEVARS-1
        ld (hl),0
        ldir
        ld ix,TCH1
        ld hl,FR_CH1
        call tc_init
        ld ix,TCH2
        ld hl,FR_CH2
        call tc_init
        ld ix,TCH3
        ld hl,FR_CH3
        call tc_init
        ld hl,FR_DRUMS
        ld (td_ptr),hl
        ld a,1
        ld (td_dur),a
        ld a,4
        ld (t_upload),a         ; art goes to video RAM over 4 fields
        ld hl,FB
        ld (t_upsrc),hl
        ld hl,VRAM
        ld (t_updst),hl
        call read_input         ; (don't start on a held button)
        ; wait for a field sync to start, then into the cycle
.ws:    ld a,(LATCH)
        rla
        jr nc,.ws
.ws2:   ld a,(LATCH)
        rla
        jr c,.ws2
        ld hl,0
        ld (t_acc1),hl
        ld (t_acc2),hl
        ld (t_acc3),hl
        jp tp_work

tc_init:
        ld (ix+TC_PTR),l
        ld (ix+TC_PTR+1),h
        ld (ix+TC_START),l
        ld (ix+TC_START+1),h
        ld (ix+TC_DUR),1
        ld hl,SILENT
        ld (ix+TC_ENV),l
        ld (ix+TC_ENV+1),h
        ld (ix+TC_INSE),l
        ld (ix+TC_INSE+1),h
        ret

SILENT: db 0,$FF

; ---------------------------------------------------------------- the loops
; loop A: the display (and the end of the field): exits when field sync starts
tp_loopA:
        add hl,de
        ld a,h
        add a,b
        sbc a,a
        and $21
        xor c
        ld (LATCH),a
        exx
        add hl,de
        ld a,h
        add a,b
        sbc a,a
        and $21
        xor c
        ld (LATCH),a
        exx
        add ix,sp
        ld a,ixh
        add a,iyl
        sbc a,a
        and $21
        xor c
        ld (LATCH),a
        ld a,(LATCH)            ; bit 7 = 0 during field sync
        rla
        jp c,tp_loopA
        jp tp_work

; loop B: the rest of field sync: exits when it ends
tp_loopB:
        add hl,de
        ld a,h
        add a,b
        sbc a,a
        and $21
        xor c
        ld (LATCH),a
        exx
        add hl,de
        ld a,h
        add a,b
        sbc a,a
        and $21
        xor c
        ld (LATCH),a
        exx
        add ix,sp
        ld a,ixh
        add a,iyl
        sbc a,a
        and $21
        xor c
        ld (LATCH),a
        ld a,(LATCH)
        rla
        jp nc,tp_loopB
        jp tp_loopA

; ---------------------------------------------------------------- the work
tp_work:
        ld (t_acc1),hl
        exx
        ld (t_acc2),hl
        exx
        ld (t_acc3),ix
        ld sp,STACKTOP
        ; 1. video RAM first (it must be done before the display starts)
        call t_screen
        ; 2. a drum burst, if one is due
        call t_noise
        ; 3. the sequencer
        ld ix,TCH1
        call tc_tick
        ld ix,TCH2
        call tc_tick
        ld ix,TCH3
        call tc_tick
        call td_tick
        ; 4. controls
        call read_input
        ld a,(keys_new)
        and (1<<K_FIRE)|(1<<K_BURST)
        jp nz,start_game
        ; back to the voices
        ld a,(latch)
        or $20
        and $FE
        ld c,a
        ld a,(TCH1+TC_DUTY)
        ld b,a
        ld de,(TCH1+TC_STEP)
        ld hl,(t_acc1)
        exx
        ld a,(latch)
        or $20
        and $FE
        ld c,a
        ld a,(TCH2+TC_DUTY)
        ld b,a
        ld de,(TCH2+TC_STEP)
        ld hl,(t_acc2)
        exx
        ld a,(TCH3+TC_DUTY)
        ld iyl,a
        ld ix,(t_acc3)
        ld sp,(TCH3+TC_STEP)
        jp tp_loopB

; ---------------------------------------------------------------- screen
t_screen:
        ld hl,t_cnt
        inc (hl)
        ; the art goes up 512 bytes a field
        ld a,(t_upload)
        or a
        jr z,.anim
        dec a
        ld (t_upload),a
        ld hl,(t_upsrc)
        ld de,(t_updst)
        ld bc,512
        ldir
        ld (t_upsrc),hl
        ld (t_updst),de
        or a
        ret nz
        ; last chunk done: the high score
        ld hl,hiscore
        ld de,FR_HI_VRAM
        ld b,4
.hi:    push bc
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        call t_digit
        ld a,(hl)
        and 15
        call t_digit
        inc hl
        pop bc
        djnz .hi
        ret
.anim:  ; PRESS FIRE: on for 24 fields, off for 8
        ld a,(t_cnt)
        and 31
        jr z,.on
        cp 24
        jr nz,.tw
        ld hl,FR_PRESS_OFF
        jr .pr
.on:    ld hl,FR_PRESS_ON
.pr:    ld de,FR_PRESS_VRAM
        ld b,7
.prl:   push bc
        push de
        ld bc,11
        ldir
        pop de
        ex de,hl
        ld bc,32
        add hl,bc
        ex de,hl
        pop bc
        djnz .prl
        ret
.tw:    ; a star twinkles every 3 fields
        ld a,(t_cnt)
        and 3
        ret nz
        call rand
        ld b,a
        and 7
        cp FR_NSTARS
        ret nc
        ld l,a
        add a,a
        add a,a
        add a,a
        add a,a                 ; *16
        sub l
        sub l                   ; *14
        ld e,a
        ld d,0
        ld hl,FR_TWINKLE
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl                  ; DE = video address, HL = bright rows
        bit 6,b
        jr z,.br
        ld a,6
        add a,l
        ld l,a
        jr nc,$+3
        inc h                   ; dim rows
.br:    ld b,3
.twl:   ld a,(hl)
        ld (de),a
        inc hl
        inc de
        ld a,(hl)
        ld (de),a
        inc hl
        ld a,e
        add a,31
        ld e,a
        jr nc,$+3
        inc d
        djnz .twl
        ret

; digit A -> video RAM at DE (5 rows), DE moves one byte right
t_digit:
        push hl
        push de
        ld l,a
        add a,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        ld bc,DIGITS
        add hl,bc
        ld b,5
.r:     ld a,(hl)
        ld (de),a
        inc hl
        ld a,e
        add a,32
        ld e,a
        jr nc,$+3
        inc d
        djnz .r
        pop de
        inc de
        pop hl
        ret

; ---------------------------------------------------------------- drums
t_noise:
        ld a,(t_nlen)
        or a
        ret z
        ld b,a
        xor a
        ld (t_nlen),a
        ld a,(latch)
        or $20
        and $FE
        ld c,a
        ld hl,(t_npos)
.l:     ld a,(hl)               ; the ROM makes good noise
        inc hl
        and $21
        xor c
        ld (LATCH),a
        djnz .l
        ld a,h
        and $3F
        ld h,a
        ld (t_npos),hl
        ld a,c
        ld (LATCH),a
        ret

td_tick:
        ld hl,td_dur
        dec (hl)
        ret nz
        ld hl,(td_ptr)
.rd:    ld a,(hl)
        cp $FF
        jr nz,.n
        ld hl,FR_DRUMS
        jr .rd
.n:     inc hl
        ld b,(hl)
        inc hl
        ld (td_ptr),hl
        ld hl,td_dur
        ld (hl),b
        or a
        ret z
        cp 1
        ld a,140                ; snare
        jr z,.s
        ld a,36                 ; hat
.s:     ld (t_nlen),a
        ret

; ---------------------------------------------------------------- sequencer
; byte stream: $80+i instrument, $FF loop, else note (0 = rest) + duration
tc_tick:
        dec (ix+TC_DUR)
        jr nz,.env
        ld l,(ix+TC_PTR)
        ld h,(ix+TC_PTR+1)
.rd:    ld a,(hl)
        cp $FF
        jr nz,.n1
        ld l,(ix+TC_START)
        ld h,(ix+TC_START+1)
        jr .rd
.n1:    bit 7,a
        jr z,.note
        and $7F
        add a,a
        add a,a
        push hl
        ld e,a
        ld d,0
        ld hl,FR_INS
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ix+TC_INSE),e
        ld (ix+TC_INSE+1),d
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (ix+TC_ARPB),e
        ld (ix+TC_ARPB+1),d
        pop hl
        inc hl
        jr .rd
.note:  ld (ix+TC_NOTE),a
        inc hl
        ld a,(hl)
        ld (ix+TC_DUR),a
        inc hl
        ld (ix+TC_PTR),l
        ld (ix+TC_PTR+1),h
        ld (ix+TC_OFS),0
        ld a,(ix+TC_NOTE)
        or a
        jr z,.rest
        ld a,(ix+TC_INSE)
        ld (ix+TC_ENV),a
        ld a,(ix+TC_INSE+1)
        ld (ix+TC_ENV+1),a
        ld a,(ix+TC_ARPB)
        ld (ix+TC_ARP),a
        ld a,(ix+TC_ARPB+1)
        ld (ix+TC_ARP+1),a
        jr .env
.rest:  ld hl,SILENT
        ld (ix+TC_ENV),l
        ld (ix+TC_ENV+1),h
        ld (ix+TC_ARP),0
        ld (ix+TC_ARP+1),0
.env:   ld l,(ix+TC_ENV)
        ld h,(ix+TC_ENV+1)
        ld a,(hl)
        cp $FF
        jr z,.arp
        ld (ix+TC_DUTY),a
        inc hl
        ld (ix+TC_ENV),l
        ld (ix+TC_ENV+1),h
.arp:   ld l,(ix+TC_ARP)
        ld h,(ix+TC_ARP+1)
        ld a,h
        or l
        jr z,.pitch
.ar:    ld a,(hl)
        cp $80
        jr nz,.a1
        ld l,(ix+TC_ARPB)
        ld h,(ix+TC_ARPB+1)
        jr .ar
.a1:    cp $81
        jr z,.pitch
        ld (ix+TC_OFS),a
        inc hl
        ld (ix+TC_ARP),l
        ld (ix+TC_ARP+1),h
.pitch: ld a,(ix+TC_NOTE)
        or a
        ret z
        add a,(ix+TC_OFS)
        jr z,.lo
        cp 73
        jr c,.ok
.lo:    ld a,1
.ok:    add a,a
        ld e,a
        ld d,0
        ld hl,FR_NOTE3
        add hl,de
        ld a,(hl)
        ld (ix+TC_STEP),a
        inc hl
        ld a,(hl)
        ld (ix+TC_STEP+1),a
        ret
