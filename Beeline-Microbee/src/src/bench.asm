; ==========================================================================
; bench.asm - BENCH.COM : video throughput calibration for the Premium Plus
;   ViBED by BPM 2026
;
; Each test runs a fixed block of work repeatedly for exactly 50 video
; fields (one second at 50 Hz) and shows how many blocks completed.
; The same program runs in the emulator, so a difference between the
; emulator figure and the real machine reveals video-RAM wait states or
; other bus effects that the Z80 cycle counts alone cannot show.
;
;   T-states per block = 3,375,000 / blocks per second
; ==========================================================================
        org 100h
        jp start
        include "hw.asm"
        include "math.asm"

NTEST   equ 7

start:
        di
        ld sp,0EF00h
        call map_video
        call init_video
        ld hl,0
        ld (fields),hl
        ; colour the text rows white on blue
        ld a,40h
        out (PORT_08),a
        ld hl,PCGWIN
        ld b,0
.c      ld (hl),(4<<4)|15
        inc hl
        ld (hl),(4<<4)|15
        inc hl
        ld (hl),(4<<4)|15
        inc hl
        ld (hl),(4<<4)|15
        inc hl
        djnz .c
        xor a
        out (PORT_08),a
        ld hl,TITLE
        ld de,VRAM+0*64
        call print
        ld hl,TITLE2
        ld de,VRAM+1*64
        call print
        ; run each test
        ld ix,TESTS
        ld b,NTEST
        ld de,VRAM+3*64
.t      push bc
        push de
        ld l,(ix+0)
        ld h,(ix+1)             ; label
        call print
        ld l,(ix+2)
        ld h,(ix+3)
        ld (run_test.tv+1),hl   ; patch the call target
        call run_test           ; HL = blocks per second
        pop de
        push de
        ld a,e
        add a,40
        ld e,a
        call printnum
        pop de
        ld hl,64
        add hl,de
        ex de,hl
        ld bc,4
        add ix,bc
        pop bc
        djnz .t
        ld hl,DONE
        ld de,VRAM+12*64
        call print
.halt   jr .halt

; run_test: repeat the block for 50 fields, return HL = count
run_test:
        call wait_vb
        ld hl,(fields)
        ld (t0),hl
        ld hl,0
        ld (cnt),hl
.l
.tv     call 0                  ; patched
        ld hl,(cnt)
        inc hl
        ld (cnt),hl
        call vbpoll
        ld hl,(fields)
        ld de,(t0)
        or a
        sbc hl,de
        ld a,l
        cp 50
        jr c,.l
        ld hl,(cnt)
        ret

; ---------------------------------------------------------------- tests
; 1: LDIR 256 bytes main RAM -> main RAM (baseline, no video)
tst_ram:
        ld hl,8000h
        ld de,8100h
        ld bc,256
        ldir
        ret
; 2: LDIR 256 bytes main RAM -> PCG RAM (bank 15, unused)
tst_pcg:
        ld a,X1C|15
        out (PORT_1C),a
        ld hl,8000h
        ld de,PCGWIN+256
        ld bc,256
        ldir
        ld a,X1C
        out (PORT_1C),a
        ret
; 3: unrolled fill of 256 bytes of screen RAM (second page)
tst_scr:
        ld hl,VRAM+400h
        ld a,20h
        ld b,4
.l      call fill64
        djnz .l
        ret
; 4: unrolled fill of 256 bytes of colour RAM (second page)
tst_col:
        ld a,40h
        out (PORT_08),a
        ld hl,PCGWIN+400h
        ld a,(4<<4)|15
        ld b,4
.l      call fill64
        djnz .l
        xor a
        out (PORT_08),a
        ret
; 5: unrolled fill of 256 bytes of attribute RAM (second page)
tst_att:
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld hl,VRAM+400h
        xor a
        ld b,4
.l      call fill64
        djnz .l
        ld a,X1C
        out (PORT_1C),a
        ret
; 6: 16 quarter-square multiplies (pure CPU)
tst_mul:
        ld b,16
.l      push bc
        ld a,b
        ld e,173
        call mul8q
        pop bc
        djnz .l
        ret
; 7: read 256 bytes of PCG RAM (bank 15, unused) into main RAM
tst_pcgr:
        ld a,X1C|15
        out (PORT_1C),a
        ld hl,PCGWIN+256
        ld de,8200h
        ld bc,256
        ldir
        ld a,X1C
        out (PORT_1C),a
        ret

fill64: push bc
        ld b,64
.l      ld (hl),a
        inc hl
        djnz .l
        pop bc
        ret

TESTS:  dw L1,tst_ram, L2,tst_pcg, L3,tst_scr, L4,tst_col, L5,tst_att, L6,tst_mul, L7,tst_pcgr
TITLE:  db "MICROBEE PREMIUM PLUS VIDEO BENCHMARK  VIBED BY BPM 2026",0
TITLE2: db "BLOCKS PER SECOND (T PER BLOCK = 3375000 / BLOCKS)",0
L1:     db "LDIR 256 RAM TO RAM",0
L2:     db "LDIR 256 RAM TO PCG",0
L3:     db "FILL 256 SCREEN RAM",0
L4:     db "FILL 256 COLOUR RAM",0
L5:     db "FILL 256 ATTRIB RAM",0
L6:     db "16 X 8BIT MULTIPLY",0
L7:     db "LDIR 256 PCG TO RAM",0
DONE:   db "DONE - PHOTOGRAPH THIS SCREEN",0

; print: zero-terminated text at HL -> screen at DE (codes + attributes)
print:  ld a,(hl)
        or a
        ret z
        push hl
        push de
        sub 32
        add a,a
        ld l,a
        ld h,0
        ld bc,FONTMAP
        add hl,bc
        ld a,(hl)
        ld (de),a
        inc hl
        ld c,(hl)
        ld a,X1C_ATTR
        out (PORT_1C),a
        ld a,c
        ld (de),a
        ld a,X1C
        out (PORT_1C),a
        pop de
        pop hl
        inc hl
        inc de
        jr print

; printnum: HL (0..65535) as 5 digits at DE
printnum:
        push ix
        call .pn
        pop ix
        ret
.pn     ld ix,NUMBUF
        ld bc,10000
        call .d
        ld bc,1000
        call .d
        ld bc,100
        call .d
        ld bc,10
        call .d
        ld a,l
        add a,'0'
        ld (ix+0),a
        ld (ix+1),0
        ld hl,NUMBUF
        jp print
.d      ld a,'0'-1
.dl     inc a
        or a
        sbc hl,bc
        jr nc,.dl
        add hl,bc
        ld (ix+0),a
        inc ix
        ret
NUMBUF: ds 8
t0:     dw 0
cnt:    dw 0
        include "../build/gfx.inc"
PCGDATA:
        incbin "../build/pcg.bin"
