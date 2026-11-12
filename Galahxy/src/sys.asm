; =====================================================================
;  sys.asm - field interrupt + back-buffer copy, present, input,
;            banking, helpers.  ISR technique from Zephyr Zone v1.0.3
;            (proven on the user's VZ300): the copy is split over two
;            field gaps so video RAM is never written while the picture
;            is drawn, with one speaker sample per two copied rows.
; =====================================================================

init_im2:
            ld hl,IM2TAB
            ld b,0
.l:         ld (hl),HIGH(IM2VEC)
            inc hl
            djnz .l
            ld (hl),HIGH(IM2VEC)
            ld a,$C3
            ld (IM2VEC),a
            ld hl,isr
            ld (IM2VEC+1),hl
            ld a,HIGH(IM2TAB)
            ld i,a
            im 2
            xor a
            ld (intoff),a
            ld (ready),a
            ld (cphase),a
            ld a,2
            ld (minfields),a
            ei
            ret

; ---------------------------------------------------------------------
; Field ISR. INT is held for the 56 lines of field sync. When a finished
; back buffer is waiting and the frame has had its fields, copy rows
; 6..SPLITROW-1 now and SPLITROW..63 in the next field's gap. Otherwise
; return with interrupts still off; maybe_ei turns them back on once
; sync has ended.
; ---------------------------------------------------------------------
isr:
            push af
            push hl
            ld hl,fieldctr
            inc (hl)
            ld a,(cphase)           ; bottom half of the frame still to go?
            or a
            jr nz,.copy
            ld a,(ready)
            or a
            jr z,.noc
            ld a,(lastcopy)
            ld l,a
            ld a,(fieldctr)
            sub l
            ld hl,minfields
            cp (hl)
            jr nc,.copy
.noc:       ld a,1
            ld (intoff),a
            pop hl
            pop af
            ret                     ; interrupts stay off until maybe_ei
.copy:      push bc
            push de
            exx
            push bc
            push de
            push hl
            ld hl,(snd_ph)
            ld de,(snd_step)
            ld a,(snd_mask)
            ld b,a
            ld a,(latchv)
            ld c,a
            exx
            ld a,(cphase)
            or a
            jr z,.ca
            ld a,(cps)              ; second half
            add a,SPLITROW/8
            ld h,a
            ld l,0
            ld de,VRAM+SPLITROW*32
            xor a
            ld (cphase),a
            ld a,HIGH(VRAM+COPYEND*32)
            jr .cgo
.ca:        ld a,(fieldctr)
            ld (lastcopy),a
            ld a,(cps)
            ld h,a
            ld l,HUDROWS*32
            ld de,VRAM+HUDROWS*32
            ld a,1
            ld (cphase),a
            ld a,HIGH(VRAM+SPLITROW*32)
.cgo:       ld (.cend+1),a
.row:       REPT 64
            ldi
            ENDR
            exx
snd_gen     equ $
            add hl,de               ; patched to "ld a,r" for noise
            ld a,h
            rla
            sbc a,a
            and b
            xor c
            ld (LATCH),a
            exx
            ld a,d                  ; copied up to the end of this part?
.cend:      cp HIGH(VRAM+COPYEND*32)
            jp nz,.row
            exx
            ld (snd_ph),hl
            ld a,c
            ld (LATCH),a            ; speaker back to rest
            pop hl
            pop de
            pop bc
            exx
            ld a,(cphase)           ; frame finished (no second half pending)?
            or a
            jr nz,.half
            ld (ready),a
.half:      xor a
            ld (intoff),a
            pop de
            pop bc
            pop hl
            pop af
            ei
            reti

; turn interrupts back on once field sync is over (cheap; call often)
maybe_ei:
            ld a,(intoff)
            or a
            ret z
            ld a,(FSREAD)
            rla
            ret nc                  ; still in field sync
            xor a
            ld (intoff),a
            ei
            ret

; after a DI section: EI unless the ISR left interrupts off on purpose
re_ei:
            ld a,(intoff)
            or a
            ret nz
            ei
            ret

; ---------------------------------------------------------------------
; present: double buffered. Wait until the last frame has gone out in
; full, hand this buffer to the ISR and swap: the next frame is drawn
; into the other buffer straight away. dtf = fields since the last call.
; ---------------------------------------------------------------------
present:
            ld (tmark),a            ; emulator timing hook (work done)
.w:         call maybe_ei
            call wait_sound
            ld a,(ready)
            or a
            jr nz,.w
            ld a,(cphase)
            or a
            jr nz,.w
            ld a,(bbh)
            ld (cps),a
            xor HIGH(BB)^HIGH(BB1)
            ld (bbh),a
            ld a,1
            ld (ready),a
            ld a,(fieldctr)
            ld hl,lastfr
            sub (hl)
            ld (dtf),a
            ld a,(fieldctr)
            ld (lastfr),a
            ld hl,(frames)
            inc hl
            ld (frames),hl
            ret

; wait until both buffers are idle (before the SD loader uses BB, or
; before a front-end screen holds a picture)
bb_wait:
            call maybe_ei
            call wait_sound
            ld a,(ready)
            or a
            jr nz,bb_wait
            ld a,(cphase)
            or a
            jr nz,bb_wait
            ret

; DE = offset into the back buffer -> DE = address (keeps A, HL)
bbde:       push af
            ld a,(bbh)
            add a,d
            ld d,a
            pop af
            ret
; HL = offset into the back buffer -> HL = address in the draw buffer
bbp:        ld a,(bbh)
            add a,h
            ld h,a
            ret

; wait for A fields without drawing
wait_fields:
            ld b,a
.l:         push bc
            ld a,(fieldctr)
            ld c,a
.w:         call maybe_ei
            call wait_sound
            ld a,(fieldctr)
            cp c
            jr z,.w
            pop bc
            djnz .l
            ret

setmap:     ld (cur_map),a
            out (BANKPORT),a
            ret

; ---------------------------------------------------------------------
; input: keyboard Q A O P (Z X) SPACE=fire M/B=buy RETURN=pause, plus
; either joystick (fire $2E/$2B, arm $2D/$27, directions $2C/$29)
; ---------------------------------------------------------------------
read_input:
            ld e,0
            ld a,($68FE)            ; T W - E Q R : Q = bit4
            bit 4,a
            jr nz,.n1
            set 0,e
.n1:        ld a,($68FD)            ; G S CTRL D A F : A = bit4
            bit 4,a
            jr nz,.n2
            set 1,e
.n2:        ld a,($68BF)            ; Y O RET I P U : O bit1, RET bit2, P bit4
            bit 1,a
            jr nz,.n3
            set 2,e
.n3:        bit 4,a
            jr nz,.n4
            set 3,e
.n4:        bit 2,a
            jr nz,.n4b
            set 6,e
.n4b:       ld a,($68EF)            ; N . - , SPACE M : SPACE bit4, M bit5
            bit 4,a
            jr nz,.n5
            set 4,e
.n5:        bit 5,a
            jr nz,.n6
            set 5,e
.n6:        ld a,($68FB)            ; B X SHIFT C Z V : B bit0, X bit1, Z bit4
            bit 4,a
            jr nz,.n7
            set 2,e
.n7:        bit 1,a
            jr nz,.n8
            set 3,e
.n8:        bit 0,a
            jr nz,.n9
            set 5,e
.n9:        ld a,(demo_on)          ; attract demo: the AI drives (any key ends it)
            or a
            jr z,.real
            ld a,e
            ld (in_demokey),a
            ld a,($6800)
            and $3F
            cp $3F
            jr z,.dk
            ld a,K_ANY
            ld (in_demokey),a
.dk:        call joy_read
            or a
            jr z,.dk2
            ld a,K_ANY
            ld (in_demokey),a
.dk2:       ld a,(demo_in)
            ld e,a
            jr .st
.real:      call joy_read
            or e
            ld e,a
            ld a,($6800)            ; any key at all
            and $3F
            cp $3F
            jr z,.nk
            set 7,e
.nk:        ld a,e
            or a
            jr z,.st
            set 7,e
.st:        ld a,(in_real)
            cpl
            and e
            ld (in_new),a
            ld a,e
            ld (in_now),a
            ld (in_real),a
            ret

; both sticks at once -> A bits 0-5 (5 = arm)
joy_read:
            ld a,(joyok)
            or a
            ret z
            push bc
            push de
            ld b,0
            ld c,$2C
            in d,(c)
            ld c,$29
            in a,(c)
            and d
            and $0F
            ld e,a
            ld c,$2E                ; fire
            in d,(c)
            ld c,$2B
            in a,(c)
            and d
            and $10
            or e
            ld e,a
            ld c,$2D                ; arm = buy power-up
            in d,(c)
            ld c,$27
            in a,(c)
            and d
            and $10
            rla
            or e
            or $C0
            cpl
            and $3F
            pop de
            pop bc
            ret
joy_detect:
            ld b,8
            ld c,$FF
.l:         in a,($2E)
            and c
            ld c,a
            in a,($2D)
            and c
            ld c,a
            djnz .l
            ld a,c
            and $1F
            cp $1F
            ld a,1
            jr z,.ok
            xor a
.ok:        ld (joyok),a
            ret

; is key N (music toggle) newly pressed? -> NZ
key_n:
            ld a,($68EF)
            cpl
            and 1
            ld hl,kn_last
            ld b,(hl)
            ld (hl),a
            ret z
            ld a,b
            xor 1
            ret

; random: A = next pseudo-random byte (xorshift)
random:
            push hl
            ld hl,(rng)
            ld a,h
            rra
            ld a,l
            rra
            xor h
            ld h,a
            ld a,l
            rra
            ld a,h
            rra
            xor l
            ld l,a
            xor h
            ld h,a
            ld (rng),hl
            pop hl
            ret

; clear the back buffer to A
cls_bb:
            push af
            ld hl,0
            call bbp
            pop af
            ld d,h
            ld e,l
            inc de
            ld bc,COPYEND*32-1
            ld (hl),a
            ldir
            ret

; clear the HUD rows in VRAM to A
cls_hud:
            ld hl,VRAM
            ld de,VRAM+1
            ld bc,HUDROWS*32-1
            ld (hl),a
            ldir
            ret
