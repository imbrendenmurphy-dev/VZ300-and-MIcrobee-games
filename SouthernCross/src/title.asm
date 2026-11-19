; ============================================================================
;  TITLE SCREEN and the three-voice music player
;  (assembled into the front pack, SCROSS00.DAT: it runs from SRAM bank B)
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

; (title, in the core, has loaded this pack and jumps here)
title_main:
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
.und:   call hof_page
        ; voices and sequencer
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
        jr z,.pg
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
        ld a,(t_page)
        or a
        ret nz
        ; last chunk of the title done: the high score
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
.pg:    ; the title, the hall of fame, then the demo
        ld hl,(t_ptm)
        inc hl
        ld (t_ptm),hl
        ld a,(t_page)
        or a
        ld de,1250              ; 25 s of the title
        jr z,.pt
        ld de,400               ; 8 s of the hall of fame, then the demo
.pt:    or a
        sbc hl,de
        jr c,.same
        ld hl,0
        ld (t_ptm),hl
        ld a,(t_page)
        xor 1
        ld (t_page),a
        jr z,.demo
        ld hl,HOFBUF
.src:   ld (t_upsrc),hl
        ld hl,VRAM
        ld (t_updst),hl
        ld a,4
        ld (t_upload),a
        ret
.demo:  ld a,1
        ld (demo),a
        jp start_game
.same:  ld a,(t_page)
        or a
        ret nz
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

; ---------------------------------------------------------------- hall of fame
; the page is drawn once into the overlay (free on the title) and goes up to
; video RAM like the art, 512 bytes a field
HOFBUF  equ OVL

hof_page:
        ld hl,HOFBUF
        ld de,HOFBUF+1
        ld bc,2047
        ld (hl),$AA
        ldir
        ld hl,STR_HOF
        ld bc,$FF00+3           ; centred, row 3
        ld de,$55FF             ; yellow on red
        call p_text
        ld ix,HOF
        ld c,14
        ld a,'1'
.e:     push af
        push bc
        ld hl,txtbuf
        ld (hl),a
        inc hl
        ld (hl),' '
        inc hl
        ld (hl),' '
        inc hl
        ld a,(ix+4)
        ld (hl),a
        inc hl
        ld a,(ix+5)
        ld (hl),a
        inc hl
        ld a,(ix+6)
        ld (hl),a
        inc hl
        ld (hl),' '
        inc hl
        ld (hl),' '
        inc hl
        ld b,4
        push ix
.d:     ld a,(ix+0)
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,'0'
        ld (hl),a
        inc hl
        ld a,(ix+0)
        and 15
        add a,'0'
        ld (hl),a
        inc hl
        inc ix
        djnz .d
        pop ix
        ld (hl),0
        pop bc
        push bc
        ld hl,txtbuf
        ld b,255
        ld de,$55AA             ; yellow on blue
        call p_text
        pop bc
        ld a,c
        add a,8
        ld c,a
        ld de,7
        add ix,de
        pop af
        inc a
        cp '6'
        jr c,.e
        ld hl,STR_FIRE
        ld bc,$FF00+56
        ld de,$00AA             ; green on blue
        jp p_text

; HL = text, B = byte column (255 = centred), C = row, D = ink, E = paper
p_text:
        ld a,b
        inc a
        jr nz,.at
        push hl
        ld b,0
.ln:    ld a,(hl)
        or a
        jr z,.lnd
        inc b
        inc hl
        jr .ln
.lnd:   pop hl
        ld a,32
        sub b
        srl a
        ld b,a
.at:    ld (dt_col),de          ; (paper, ink)
        ld a,e
        ld (dt_paper),a
        ld a,d
        ld (dt_ink),a
        push hl
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; row * 32
        ld c,b
        ld b,0
        add hl,bc
        ld bc,HOFBUF
        add hl,bc
        ex de,hl                ; DE = destination
        pop hl
.ch:    ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        push de
        sub 32
        ld l,a
        ld h,0
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl
        add hl,bc
        ld bc,FONT4
        add hl,bc               ; glyph
        ld a,(dt_paper)
        ld (de),a
        ld b,5
.gr:    ex de,hl
        ld a,l
        add a,32
        ld l,a
        jr nc,$+3
        inc h
        ex de,hl
        push hl
        ld a,(hl)
        ld hl,EXPAND
        add a,l
        ld l,a
        jr nc,$+3
        inc h
        ld c,(hl)
        ld a,(dt_ink)
        and c
        ld l,a
        ld a,c
        cpl
        ld c,a
        ld a,(dt_paper)
        and c
        or l
        ld (de),a
        pop hl
        inc hl
        djnz .gr
        ex de,hl
        ld bc,32
        add hl,bc
        ld a,(dt_paper)
        ld (hl),a
        pop de
        inc de
        pop hl
        jr .ch

STR_HOF:  db "HALL OF FAME",0
STR_FIRE: db "PRESS FIRE",0
