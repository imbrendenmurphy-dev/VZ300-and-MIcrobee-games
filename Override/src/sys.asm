; =====================================================================
;  sys.asm - game-mode field interrupt (back buffer -> video RAM),
;            frame pacing, input, banking, helpers
; =====================================================================

init_im2:
            di
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
            ld a,MAP_GAME
            call setmap
            ld a,LATCH_GAME
            ld (latchv),a
            ld (LATCH),a
            ei
            ret

; ---------------------------------------------------------------------
; Field ISR. INT is held low for the 56 lines of field sync. When a
; finished back buffer is waiting and at least two fields have passed
; since the last copy, copy it to video RAM with the unrolled stack copy
; (it starts at sync and outruns the beam). Otherwise return with
; interrupts still off - maybe_ei turns them on again once sync is over.
; ---------------------------------------------------------------------
isr:
            push af
            push hl
            ld hl,fieldctr
            inc (hl)
            ld a,(ready)
            or a
            jr z,isr_noc
            ld a,(fieldctr)
            ld hl,lastcopy
            sub (hl)
            cp 2
            jr c,isr_noc
            ld a,(fieldctr)
            ld (lastcopy),a
            push bc
            push de
            push ix
            exx
            push bc
            push de
            push hl
            exx
            ex af,af'
            push af
            ex af,af'
            ld (isr_sp),sp
            ld a,(hud_dirty)
            or a
            jp nz,copy_hud          ; (falls into copy_view, ends at isr_back)
            jp copy_view
isr_back:
            ld sp,(isr_sp)
            ld a,LATCH_GAME
            ld (LATCH),a
            xor a
            ld (ready),a
            ld (hud_dirty),a
            ld (intoff),a
            ex af,af'
            pop af
            ex af,af'
            exx
            pop hl
            pop de
            pop bc
            exx
            pop ix
            pop de
            pop bc
            pop hl
            pop af
            ei
            reti
isr_noc:    ld a,1
            ld (intoff),a
            pop hl
            pop af
            ret                     ; interrupts stay off until maybe_ei

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
; one effects sample (same spacing as the copy loops, ~730 T with the
; caller's loop), used while waiting
; ---------------------------------------------------------------------
idle_sample:
            ld hl,snd_rd            ; 10  the next sample from the ring
            ld a,(hl)               ; 7   (inc (hl) is atomic: the ISR
            inc (hl)                ; 11   reads the ring too)
            ld l,a                  ; 4
            ld h,HIGH(SNDBUF)       ; 7
            ld a,(hl)               ; 7
            ld (LATCH),a            ; 13
            ld b,IDLE_DLY           ; 7
.d:         djnz .d                 ; 13 a loop
            ret                     ; 10
IDLE_DLY    equ 55

; hand the finished back buffer to the ISR
present:
            ld a,1
            ld (ready),a
            ld hl,(frames)
            inc hl
            ld (frames),hl
            ret

; wait until the ISR has copied the back buffer (call before drawing it)
wait_bb:
            call maybe_ei
            call idle_sample
            ld a,(ready)
            or a
            jr nz,wait_bb
            ret

; wait for N fields without drawing (A = fields)
wait_fields:
            ld b,a
.l:         push bc
            ld a,(fieldctr)
            ld c,a
.w:         push bc
            call maybe_ei
            call idle_sample
            pop bc
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
map_store:  ld a,MAP_STORE
setmap:     ld (cur_map),a
            out (BANKPORT),a
            ret

; copy BC bytes from upper bank 0 (HL) to upper bank 1 (DE), through the
; bounce buffer, 256 at a time. Interrupts must be off (game mode: DI).
far_copy:
            ld a,b
            or c
            ret z
            push bc
            ld a,b
            or a
            jr z,.go                ; < 256 left: BC as it is
            ld bc,256
.go:        ld (fcp_n),bc
            push de
            ld de,BOUNCE
            ld a,MAP_STORE
            out (BANKPORT),a
            ldir
            ld a,MAP_GAME
            out (BANKPORT),a
            pop de
            push hl
            ld hl,BOUNCE
            ld bc,(fcp_n)
            ldir
            pop hl
            ex (sp),hl              ; HL = count, source on the stack
            ld bc,(fcp_n)
            or a
            sbc hl,bc
            ld b,h
            ld c,l
            pop hl
            jr far_copy

; the same the other way: upper bank 1 (HL) -> upper bank 0 (DE)
far_copy_out:
            ld a,b
            or c
            ret z
            push bc
            ld a,b
            or a
            jr z,.go
            ld bc,256
.go:        ld (fcp_n),bc
            push de
            ld de,BOUNCE
            ldir
            pop de
            push hl
            ld hl,BOUNCE
            ld bc,(fcp_n)
            ld a,MAP_STORE
            out (BANKPORT),a
            ldir
            ld a,MAP_GAME
            out (BANKPORT),a
            pop hl
            ex (sp),hl
            ld bc,(fcp_n)
            or a
            sbc hl,bc
            ld b,h
            ld c,l
            pop hl
            jr far_copy_out

; ---------------------------------------------------------------------
; input: keyboard (Q A O P, Z X, SPACE M, RETURN) + either joystick
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
K_DIRS      equ 15

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
.n2:        ld a,($68BF)            ; Y O RET I P U : O = bit1, P = bit4, RETURN = bit2
            bit 1,a
            jr nz,.n3
            set 2,e
.n3:        bit 4,a
            jr nz,.n4
            set 3,e
.n4:        bit 2,a
            jr nz,.n4b
            set 5,e
.n4b:       ld a,($68EF)            ; N . - , SPACE M : SPACE bit4, M bit5, N bit0
            bit 4,a
            jr nz,.n5
            set 4,e
.n5:        bit 5,a
            jr nz,.n6
            set 4,e
.n6:        bit 0,a
            jr nz,.n7
            set 6,e
.n7:        ld a,($68FB)            ; B X SHIFT C Z V : Z = left, X = right
            bit 4,a
            jr nz,.n8
            set 2,e
.n8:        bit 1,a
            jr nz,.n9
            set 3,e
.n9:        call joy_read
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
            ld a,(in_new)           ; N: music on / off (and it isn't "any key")
            bit 6,a
            ret z
            and $3F
            ld (in_new),a
            ld a,(music_on)
            xor 1
            ld (music_on),a
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
            ld c,$2D
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
            in a,($2C)
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
; random: A = next pseudo-random byte (xorshift), keeps HL
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

; A = random 0..C-1 (C > 0)
rand_n:
            call random
.l:         cp c
            ret c
            sub c
            jr .l

; HL = HL * A (8-bit A), uses DE
mul16x8:
            ex de,hl
            ld hl,0
            or a
            ret z
.l:         srl a
            jr nc,.s
            add hl,de
.s:         ex de,hl
            add hl,hl
            ex de,hl
            or a
            jr nz,.l
            ret

; HL = HL / 16 (signed-agnostic: unsigned shift)
shr4:
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            ret

; HL = -HL
neg_hl:
            xor a
            sub l
            ld l,a
            sbc a,a
            sub h
            ld h,a
            ret

; HL = |HL|
abs_hl:
            bit 7,h
            ret z
            jr neg_hl

; fill BC bytes at HL with A
fill:
            ld (hl),a
            dec bc
            ld a,b
            or c
            ret z
            ld d,h
            ld e,l
            inc de
            ldir
            ret
