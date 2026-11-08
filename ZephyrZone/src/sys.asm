; =====================================================================
;  sys.asm - field interrupt + back-buffer copy (racing the beam),
;            present, input, mapping, arithmetic helpers
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
            ei
            ret

; ---------------------------------------------------------------------
; Field ISR. INT is held for the 56 lines of field sync. When a finished
; back buffer is waiting and the frame has had its fields, copy rows
; copy_top..63 to VRAM racing ahead of the beam, with one sound sample
; per row; otherwise return with interrupts still off - maybe_ei turns
; them back on once sync has ended (BIX / Redline technique).
; ---------------------------------------------------------------------
SPLITROW    equ 40              ; rows below this wait for the next field
isr:
            push af
            push hl
            ld hl,fieldctr
            inc (hl)
            ld a,(ready)
            or a
            jr z,.noc
            ld a,(cphase)           ; the bottom of last field's frame still to go?
            or a
            jr nz,.copy
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
            ; SPLIT COPY (test): the copy no longer fits in the frame gap, and
            ; writing video RAM while the picture is drawn makes snow. So rows
            ; up to SPLITROW go in this gap and the rest in the next field's.
            ld a,(cphase)
            or a
            jr z,.ca
            ld hl,BB+SPLITROW*32    ; second half
            ld de,VRAM+SPLITROW*32
            xor a
            ld (cphase),a
            ld a,HIGH(VRAM+2048)
            jr .cgo
.ca:        ld a,(fieldctr)
            ld (lastcopy),a
            ld hl,(copy_src)
            ld de,(copy_dst)
            ld a,d
            cp HIGH(VRAM+SPLITROW*32)
            ld a,HIGH(VRAM+2048)
            jr nc,.cgo              ; starts below the split: all in one go
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
.cend:      cp HIGH(VRAM+2048)
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

; ---------------------------------------------------------------------
; present: hand the frame to the ISR and wait for the copy. The copy
; starts at the first row anything was drawn in this frame or the last
; (rows above that are plain sky in both).
; ---------------------------------------------------------------------
present:
            ld a,(dirty_top)
            ld b,a
            ld a,(dirty_prev)
            cp b
            jr c,.lo
            ld a,b
.lo:        and $FE                 ; (two rows at a time: start on an even row,
            ld c,a                  ; or the copy would overrun its end) first row
            ld a,b
            ld (dirty_prev),a
            ld a,64
            ld (dirty_top),a
            ld a,64
            sub c
            ld (copy_rows),a
            ld l,c
            ld h,0
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            push hl
            ld de,BB
            add hl,de
            ld (copy_src),hl
            pop hl
            ld de,VRAM
            add hl,de
            ld (copy_dst),hl
            ld a,1
            ld (ready),a
            ld (tmark),a            ; emulator timing hook (work done)
.w:         call maybe_ei
            call wait_sound         ; idle time: keep the speaker going
            ld a,(cphase)           ; top half copied (bottom due next field):
            or a                    ; the game can get on with the next frame
            jr nz,.wd
            ld a,(ready)
            or a
            jr nz,.w
.wd:        ld a,(lastcopy)
            ld hl,lastfr
            sub (hl)
            ld (dtf),a              ; fields this frame took
            ld a,(lastcopy)
            ld (lastfr),a
            ld hl,(frames)
            inc hl
            ld (frames),hl
            ret

; before writing the back buffer: wait until all of it is on screen
bb_wait:
            call maybe_ei
            call wait_sound
            ld a,(ready)
            or a
            jr nz,bb_wait
            ret

; wait for N fields without drawing (A = fields)
wait_fields:
            ld b,a
.l:         push bc
            ld a,(fieldctr)
            ld c,a
.w:         call maybe_ei
            ld a,(fieldctr)
            cp c
            jr z,.w
            pop bc
            djnz .l
            ret

; ---------------------------------------------------------------------
; banking
; ---------------------------------------------------------------------
map_game:   ld a,MAP_GAME
            jr setmap
map_fe:     ld a,MAP_FE
setmap:     ld (cur_map),a
            out (BANKPORT),a
            ret

; ---------------------------------------------------------------------
; input: keyboard (Q A O P / SPACE M / N P) + either joystick
;   in_now: bit0 up 1 down 2 left 3 right 4 fire 5 pause 6 music 7 any
; ---------------------------------------------------------------------
K_UP        equ 1
K_DOWN      equ 2
K_LEFT      equ 4
K_RIGHT     equ 8
K_FIRE      equ 16
K_PAUSE     equ 32
K_MUSIC     equ 64
K_ANY       equ 128

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
.n2:        ld a,($68BF)            ; Y O RET I P U : O = bit1, P = bit4
            bit 1,a
            jr nz,.n3
            set 2,e
.n3:        bit 4,a
            jr nz,.n4
            set 3,e
.n4:        ld a,($68EF)            ; N . - , SPACE M : SPACE bit4, M bit5, N bit0
            bit 4,a
            jr nz,.n5
            set 4,e
.n5:        bit 5,a
            jr nz,.n6
            set 4,e
.n6:        bit 0,a
            jr nz,.n7
            set 6,e
.n7:        ld a,($68FB)            ; B X SHIFT C Z V : Z = left, X = right (alt)
            bit 4,a
            jr nz,.n8
            set 2,e
.n8:        bit 1,a
            jr nz,.n9
            set 3,e
.n9:        ld a,($68DF)            ; 6 9 - 8 0 7 : nothing yet
            ld a,($68F7)            ; 5 2 - 3 1 4
            ld a,($68BF)
            bit 4,a                 ; (P is "right"; pause = RETURN)
            ld a,($68BF)
            bit 2,a                 ; RETURN = pause
            jr nz,.n10
            set 5,e
.n10:       call joy_read
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

; both sticks at once (Cybernoid v1.7 port map: fire $2E/$2B,
; arm $2D/$27, directions $2C (J1) and $29 (J2)) -> A bits 0-4
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
            ld c,$2E
            in d,(c)
            ld c,$2B
            in a,(c)
            and d
            ld c,$2D                ; arm button = fire too
            in d,(c)
            and d
            ld c,$27
            in d,(c)
            and d
            and $10
            or e
            cpl
            and $1F
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

; ---------------------------------------------------------------------
; arithmetic
; ---------------------------------------------------------------------
; mul88: A * C -> HL (unsigned), quarter squares in bank 3. Uses B, DE.
mul88:
            ld b,a
            add a,c
            ld l,a
            ld h,HIGH(SQTAB)
            jr nc,.lo
            ld h,HIGH(SQTAB)+2
.lo:        ld e,(hl)
            inc h
            ld d,(hl)
            ld a,b
            sub c
            jr nc,.p
            neg
.p:         ld l,a
            ld h,HIGH(SQTAB)
            ld a,e
            sub (hl)
            ld e,a
            inc h
            ld a,d
            sbc a,(hl)
            ld h,a
            ld l,e
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
            ld hl,BB
            ld de,BB+1
            ld bc,2047
            ld (hl),a
            ldir
            ret

; ---------------------------------------------------------------------
; trampolines between main RAM and the front end in upper bank 0
;   from main:  call to_fe : dw routine     (maps upper bank 0, then back)
;   from FE:    call fecall : dw routine    (back to mapping 3 afterwards)
; A, HL, DE, BC pass through; A and flags come back.
; ---------------------------------------------------------------------
to_fe:
            ld (fc_hl),hl
            ld (fc_a),a
            pop hl
            push de
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (fc_tgt),de
            pop de
            push hl                 ; return address
            ld a,(cur_map)
            push af                 ; mapping to restore
            ld hl,.back
            push hl
            ld hl,(fc_tgt)
            push hl
            ld a,MAP_FE
            ld (cur_map),a
            out (BANKPORT),a
            ld a,(fc_a)
            ld hl,(fc_hl)
            ret
.back:      push af
            ld (fc_hl),hl
            pop hl                  ; result AF
            pop af                  ; saved mapping
            ld (cur_map),a
            out (BANKPORT),a
            push hl
            pop af
            ld hl,(fc_hl)
            ret

fecall:
            ld (fc_hl),hl
            ld (fc_a),a
            pop hl
            push de
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld (fc_tgt),de
            pop de
            push hl                 ; return address (in upper bank 0)
            ld hl,.back
            push hl
            ld hl,(fc_tgt)
            push hl
            ld a,(fc_a)
            ld hl,(fc_hl)
            ret
.back:      push af
            ld a,MAP_FE
            ld (cur_map),a
            out (BANKPORT),a
            pop af
            ret
