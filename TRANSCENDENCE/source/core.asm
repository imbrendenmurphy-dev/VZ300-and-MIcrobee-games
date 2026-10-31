;=====================================================================
; TRANSCENDENCE - VZ300 demo - resident core
; Target: VZ300 + BennVenn SD + 128K. Loads low at $8000 as a .VZ,
; no mapper writes, no DOS calls at run time (proven-safe layout).
;
; Register convention (whole demo):
;   AF', BC', DE', HL', IY belong to the sound engine. Main code must
;   never use EXX, EX AF,AF' or IY.
;   HL' = ch1 phase, DE' = ch1 increment
;   IY  = ch2 phase, BC' = ch2 increment
;=====================================================================

LATCH   equ $6800
VRAM    equ $7000
CHUNKY  equ $7800           ; 64x32 chunky (nibble pairs), 1K, 64-aligned
T1PAGE  equ $7C00           ; converter table top pair
T2PAGE  equ $7D00           ; converter table bottom pair
VARS    equ $7E00
STACKTOP equ $FDF0
IM2TAB  equ $FE00
IM2VEC  equ $FDFD

FRAMES  equ VARS+0          ; 16-bit field counter
VFLAG   equ VARS+2          ; set by ISR each field
MODEB   equ VARS+3          ; latch mode bits (bit3 gfx, bit4 css)
RNDS    equ VARS+4          ; 16-bit random seed
MARK    equ VARS+6          ; music marker (for visual sync)
FADEA   equ VARS+7          ; present mask even cells
FADEB   equ VARS+8          ; present mask odd cells
CHSTART equ VARS+9          ; 16-bit chapter start frame
LASTF   equ VARS+11         ; 16-bit frame at last present
DUTY1   equ VARS+13         ; mirror of ch1 duty (for visuals)
DUTY2   equ VARS+14         ; mirror of ch2 duty
TMPV    equ VARS+16         ; scratch area 32 bytes
FSCNT   equ VARS+15
FSWAIT  equ 22


;---------------------------------------------------------------------
        org $8000
start:  di
        ld sp,STACKTOP
        ; IM2 table: 257 x $FD -> vector $FDFD
        ld hl,IM2TAB
        ld b,0
.im:    ld (hl),$FD
        inc hl
        djnz .im
        ld (hl),$FD
        ld a,$C3
        ld (IM2VEC),a
        ld hl,isr
        ld (IM2VEC+1),hl
        ld a,IM2TAB>>8
        ld i,a
        im 2
        ; clear vars
        ld hl,VARS
        ld b,0
.cv:    ld (hl),0
        inc hl
        djnz .cv
        ld hl,$ACE1
        ld (RNDS),hl
        ld a,$FF
        ld (FADEA),a
        ld (FADEB),a
        ; sound registers
        exx
        ld hl,0
        ld de,0
        ld bc,0
        exx
        ld iy,0
        xor a
        call setmode
        call blackscreen
        call buildconv
        call seqinit
        ei
        jp timeline

;---------------------------------------------------------------------
; Sound tick: two phase-accumulator pulse voices, OR-mixed, constant
; time from entry to speaker write (both paths 40T after the compare).
; Multi-step entries: sndK advances both phases K times (the build sets
; K per call site from measured timing so pitch stays true everywhere).
snd8:   di
        ex af,af'
        exx
        add hl,de
        add iy,bc
        jr s7c
snd7:   di
        ex af,af'
        exx
s7c:    add hl,de
        add iy,bc
        jr s6c
snd6:   di
        ex af,af'
        exx
s6c:    add hl,de
        add iy,bc
        jr s5c
snd5:   di
        ex af,af'
        exx
s5c:    add hl,de
        add iy,bc
        jr s4c
snd4:   di
        ex af,af'
        exx
s4c:    add hl,de
        add iy,bc
        jr s3c
snd3:   di
        ex af,af'
        exx
s3c:    add hl,de
        add iy,bc
        jr s2c
snd2:   di
        ex af,af'
        exx
s2c:    add hl,de
        add iy,bc
        jr s1c
snd:    di
        ex af,af'
        exx
s1c:    add hl,de
        add iy,bc
        ld a,h
sndD1:  cp 0
        jr c,sndOn1
        ld a,iyh
sndD2:  cp 0
        sbc a,a
        and $21
sndX:   xor $01
sndW:   ld (LATCH),a
        exx
        ex af,af'
sndEI:  ei                      ; patched to JP sndchk during field sync
        ret
        nop
sndOn1:
sndO:   ld a,$20
        ld r,a
        jr sndW

; ISR copy (no DI/EI) - same output timing
sndi:   nop
        ex af,af'
        exx
        add hl,de
        add iy,bc
        ld a,h
sndiD1: cp 0
        jr c,sndiOn1
        ld a,iyh
sndiD2: cp 0
        sbc a,a
        and $21
sndiX:  xor $01
sndiW:  ld (LATCH),a
        exx
        ex af,af'
        nop
        ret
sndiOn1:
sndiO:  ld a,$20
        ld r,a
        jr sndiW

; A = mode bits ($00 text, $08 gfx css0, $18 gfx css1)
setmode:
        ld c,a
        ld a,i                  ; P/V = IFF2
        push af
        ld a,c
        di
        ld (MODEB),a
        ld b,a
        or $01
        ld (sndX+1),a
        ld (sndiX+1),a
        ld a,b
        or $20
        ld (sndO+1),a
        ld (sndiO+1),a
        ld a,b
        or $01
        ld (LATCH),a
        pop af
        ret po
        ei
        ret

;---------------------------------------------------------------------
; The ISR runs at the start of field sync, steps the music and returns
; with interrupts still disabled. Sound calls in the main code count
; down and then poll for the end of field sync before re-enabling, so
; no time is wasted busy-waiting and the interrupt cannot retrigger.
isr:    push af
        push bc
        push de
        push hl
        push ix
        call sndi
        call seq
        call sndi
        ld hl,(FRAMES)
        inc hl
        ld (FRAMES),hl
        ld a,1
        ld (VFLAG),a
        ld a,FSWAIT
        ld (FSCNT),a
        ld a,$C3
        ld (sndEI),a
        ld hl,sndchk
        ld (sndEI+1),hl
        call sndi
        pop ix
        pop hl
        pop de
        pop bc
        pop af
        reti

sndchk: push af
.test:  ld a,(LATCH)
        rla
        jr nc,.still
        ld a,$FB                ; field sync over: back to EI / RET
        ld (sndEI),a
        ld a,$C9
        ld (sndEI+1),a
        pop af
        ei
        ret
.still: pop af
        ret

;---------------------------------------------------------------------
; wait for next field (ticking)
waitvb: xor a
        ld (VFLAG),a
.w:     TICK
        ld b,14
.d:     djnz .d
        ld a,(VFLAG)
        or a
        jr z,.w
        ret

; idle N fields (A) with sound
waitn:  push af
        call waitvb
        pop af
        dec a
        jr nz,waitn
        ret

; HL = chapter-local time (FRAMES - CHSTART)
ltime:  ld hl,(FRAMES)
        ld de,(CHSTART)
        or a
        sbc hl,de
        ret

; chapter start on the absolute schedule: A = start bar (128 fields/bar)
chbegin:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (CHSTART),hl
        ret

; 8-bit random in A (xorshift16)
rnd:    push hl
        ld hl,(RNDS)
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
        ld (RNDS),hl
        pop hl
        ret

;---------------------------------------------------------------------
; whole screen black in text/semigraphic mode
blackscreen:
        ld hl,VRAM
        ld bc,512
.l:     ld (hl),$80
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret

;---------------------------------------------------------------------
; Chunky converter tables. Pixel codes 0=black,1..8 = VZ colours.
; T1[l<<4|r] = top pair: 0 if both black, else $80|(max-1)<<4|l?8|r?4
; T2[...]    = bottom pair: $80|(max-1)<<4|l?2|r?1 ($80 if black)
buildconv:
        ld hl,T1PAGE
.l1:    ld a,l
        call pairinfo           ; C = colour bits ($80|..), B = mask bits (l?2,r?1)
        ld a,b
        or a
        jr z,.z1
        rlca
        rlca
        or c
        jr .s1
.z1:    xor a
.s1:    ld (hl),a
        inc h
        ld a,b
        or c
        ld (hl),a
        dec h
        ld a,l
        and 15
        call z,snd
        inc l
        jr nz,.l1
        ret
; A = pair byte -> B = presence mask (left=2,right=1), C=$80|(max-1)<<4
pairinfo:
        ld d,a
        and $0F
        ld e,a                  ; right
        ld a,d
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld d,a                  ; left
        ld b,0
        or a
        jr z,.nl
        set 1,b
.nl:    ld a,e
        or a
        jr z,.nr
        set 0,b
.nr:    ld a,d
        cp e
        jr nc,.mx
        ld a,e
.mx:    or a
        jr z,.blk
        cp 9
        jr c,.ok
        ld a,8
.ok:    dec a
        rlca
        rlca
        rlca
        rlca
        or $80
        ld c,a
        ret
.blk:   ld c,$80
        ret

;---------------------------------------------------------------------
; clear chunky buffer (1K) to colour pair A
cclear: ld hl,CHUNKY
        ld c,32
.r:     ld b,4
.q:     ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc l
        ld (hl),a
        inc hl
        djnz .q
        TICK
        dec c
        jr nz,.r
        ret

;---------------------------------------------------------------------
; Convert chunky -> SG4 cells (in place over top-row bytes) then copy
; to VRAM on the next field. Applies FADEA/FADEB masks.
present:
        ld hl,CHUNKY
        ld d,T1PAGE>>8
        ld a,(FADEA)
        ld (.ma+1),a
        ld a,(FADEB)
        ld (.mb+1),a
        ld b,16                 ; cell rows
.row:   push bc
        ld b,16                 ; 16 x 2 cells
.cell:  ; even cell
        ld e,(hl)
        ld a,(de)
        ld c,a
        set 5,l
        ld e,(hl)
        res 5,l
        inc d
        ld a,(de)
        dec d
        inc c
        dec c
        jr z,.s1
        and 3
        or c
.s1:
.ma:    and $FF
        ld (hl),a
        inc l
        ; odd cell
        ld e,(hl)
        ld a,(de)
        ld c,a
        set 5,l
        ld e,(hl)
        res 5,l
        inc d
        ld a,(de)
        dec d
        inc c
        dec c
        jr z,.s2
        and 3
        or c
.s2:
.mb:    and $FF
        ld (hl),a
        inc l
        TICK
        djnz .cell
        ld bc,32
        add hl,bc
        ; swap fade masks per row for checker
        ld a,(.ma+1)
        ld c,a
        ld a,(.mb+1)
        ld (.ma+1),a
        ld a,c
        ld (.mb+1),a
        pop bc
        djnz .row
        ; wait for field then copy 16 rows
pcopy:  call waitvb
        ld hl,CHUNKY
        ld de,VRAM
        ld a,16
.cr:    ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        TICK
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        TICK
        ld bc,32
        add hl,bc
        dec a
        jr nz,.cr
        ret

;---------------------------------------------------------------------
; Chunky pixel plot: D=x(0-63), E=y(0-31), A=colour 1..8. clips.
pset:   push af
        ld a,d
        cp 64
        jr nc,.out
        ld a,e
        cp 32
        jr nc,.out
        pop af
        push hl
        push bc
        ld c,a
        ld a,e
        rrca
        rrca
        rrca                    ; y*32 low bits: (y&7)<<5
        ld l,a
        and $E0
        ld b,a
        ld a,l
        and $1F                 ; y>>3
        add a,CHUNKY>>8
        ld h,a
        ld a,d
        srl a
        or b
        ld l,a
        bit 0,d
        jr nz,.odd
        ld a,(hl)
        and $0F
        ld b,a
        ld a,c
        rlca
        rlca
        rlca
        rlca
        or b
        ld (hl),a
        pop bc
        pop hl
        ret
.odd:   ld a,(hl)
        and $F0
        or c
        ld (hl),a
        pop bc
        pop hl
        ret
.out:   pop af
        ret

; HL = chunky address of (D=x,E=y) without clipping (x 0-63, y 0-31)
caddr:  ld a,e
        rrca
        rrca
        rrca
        ld h,a
        and $E0
        ld l,a
        ld a,h
        and $1F
        add a,CHUNKY>>8
        ld h,a
        ld a,d
        srl a
        or l
        ld l,a
        ret

;---------------------------------------------------------------------
; unsigned 8x8 multiply: H*E -> HL   (quarter-square table)
; signed variant muls: A(signed) * E(signed) -> HL signed
mulu:   ; in: A,E unsigned  out: HL = A*E  (split quarter-square tables)
        push bc
        push de
        ld d,a
        add a,e
        ld l,a
        ld a,SQL>>8
        adc a,0
        ld h,a
        ld c,(hl)
        inc h
        inc h
        ld b,(hl)               ; BC = sq(a+b)
        ld a,d
        sub e
        jr nc,.p
        neg
.p:     ld l,a
        ld h,SQL>>8
        ld a,c
        sub (hl)
        ld c,a
        inc h
        inc h
        ld a,b
        sbc a,(hl)
        ld h,a
        ld l,c
        pop de
        pop bc
        ret

muls:   ; A signed * E signed -> HL signed
        push de
        ld d,a
        xor e
        push af                 ; sign in bit7
        ld a,d
        bit 7,a
        jr z,.a
        neg
.a:     bit 7,e
        jr z,.b
        ld d,a
        ld a,e
        neg
        ld e,a
        ld a,d
.b:     call mulu
        pop af
        pop de
        ret p
        ld a,h
        cpl
        ld h,a
        ld a,l
        cpl
        ld l,a
        inc hl
        ret

; sine: A = angle (0-255) -> A = signed sin*127
sin8:   push hl
        ld hl,SINTAB
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        pop hl
        ret
cos8:   add a,64
        jr sin8
