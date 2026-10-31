; =====================================================================
;  PART 2 : PLASMA OVERLOAD
;  Full-width mode(0) plasma recomputed every frame through a colour LUT
;  (4 bytes per line pair, inside the music kernel) + big smooth scroller.
;  Ends with speech "FOUR COLOURS. NO LIMITS."      music orders 6..13
; =====================================================================
        INCLUDE "ovl.inc"
        INCLUDE "../build/p2/p2const.inc"

P2_END_ORDER EQU 14

RC0     MACRO
        RASTC M0
        ENDM

LUTOP   MACRO lab
        ld a,(hl)
lab = $+1
        add a,0
        ld c,a
        ld a,(bc)
        ld (de),a
        inc hl
        inc e
        ENDM
WLA_E   MACRO
        LUTOP pa1
        LUTOP pa2
        WAIT 21
        ENDM
WLA_O   MACRO
        LUTOP pa3
        LUTOP pa4
        WAIT 21
        ENDM
WLB_E   MACRO
        LUTOP pb1
        LUTOP pb2
        WAIT 21
        ENDM
WLB_O   MACRO
        LUTOP pb3
        LUTOP pb4
        WAIT 21
        ENDM
SU_PL1  MACRO                   ; 115T
        ld hl,(fptr)
        ld de,VRAM
        ld a,(lutp)
        ld b,a
        WAIT 72
        ENDM
SU_PL2  MACRO                   ; 115T  (HL continues, DE -> $7100)
        inc d
        WAIT 111
        ENDM
SU_SC0  MACRO
        SU_HLDE sp0, VRAM+12*32
        ENDM
SU_SC1  MACRO
        SU_HLDE sp1, VRAM+13*32
        ENDM
SU_SC2  MACRO
        SU_HLDE sp2, VRAM+14*32
        ENDM
SU_SC3  MACRO
        SU_HLDE sp3, VRAM+15*32
        ENDM

part_entry:
        ld a,$80
        call cls
        ld a,(kernel_pairs)
        sub 65+33+31+16+1
        ld (c8),a
        ld hl,fields
        ld (fbase),hl
        ld (fptr),hl
        ld a,HIGH luts
        ld (lutp),a
        ld hl,0
        ld (scpos),hl
        call p2_logic
        call music_apply

p2_frame:
        FRAME_START dummy_rt
        SEG f1, f1x, RC0, 105, SU_PL1, WLA_E, WLA_O, c1
        SEG f2, f2x, RC0, 105, SU_PL2, WLB_E, WLB_O, c2
        SEG f3, f3x, RC0, 105, SU_NONE, W_IDLE, W_IDLE, c3
        SEG f4, f4x, RC0, 105, SU_SC0, W_COPY, W_COPY, c4
        SEG f5, f5x, RC0, 105, SU_SC1, W_COPY, W_COPY, c4
        SEG f6, f6x, RC0, 105, SU_SC2, W_COPY, W_COPY, c4
        SEG f7, f7x, RC0, 105, SU_SC3, W_COPY, W_COPY, c4
        SEG f8, f8x, RC0, 105, SU_NONE, W_IDLE, W_IDLE, c8
        FRAME_END
        call p2_logic
        call music_apply
        ld a,(done)
        or a
        jp z,p2_frame
        ; ---- speech: FOUR COLOURS. NO LIMITS. ----
        ld hl,sayscr
        ld de,VRAM
        ld bc,512
        ldir
        ld a,(sram_ok)
        or a
        ret z
        ld a,3
        out ($37),a
        ld hl,$4000
        ld de,SPEECH2_LEN
        ld c,M0
        call speech_play
        ld a,1
        out ($37),a
        ret

c1:     db 64
c2:     db 32
c3:     db 30
c4:     db 3
c8:     db 0
dummy_rt: dw $0000
done:   db 0
fbase:  dw 0
fptr:   dw 0
lutp:   db 0
tcol:   db 0
tspeed: db 2
oph:    db 0
scpos:  dw 0
sp0:    dw 0
sp1:    dw 0
sp2:    dw 0
sp3:    dw 0
pf:     dw 0
flash:  db 0

; ---------------------------------------------------------------------
p2_logic:
        ld hl,(pf)
        inc hl
        ld (pf),hl
        ld a,(m_ordnum)
        cp P2_END_ORDER
        jr c,.run
        ld a,1
        ld (done),a
        ret
.run:   ; ---- choose field + palette from song position ----
        sub 6                   ; 0..7
        ld c,a
        ld b,0
        ld hl,.fsel
        add hl,bc
        ld a,(hl)               ; field number
        ld hl,fields
        ld de,FIELD_BYTES
.fs:    or a
        jr z,.fsd
        add hl,de
        dec a
        jr .fs
.fsd:   ld (fbase),hl
        ; palette: base per order, alternate every 2 bars (32 rows)
        ld hl,.psel
        add hl,bc
        ld a,(m_row)
        and 32
        ld a,(hl)
        jr z,.p0
        rrca
        rrca
        rrca
        rrca
.p0:    and 15
        add a,HIGH luts
        ld (lutp),a
        ; speed: faster in later orders
        ld a,c
        srl a
        inc a
        ld (tspeed),a
        ; ---- dissolve at the end of the last order ----
        ld a,c
        cp 7
        jr nz,.nodis
        ld a,(m_row)
        cp 48
        jr c,.nodis
        ld b,HIGH luts + 5
        cp 54
        jr c,.dis
        inc b
        cp 60
        jr c,.dis
        inc b
.dis:   ld a,b
        ld (lutp),a
.nodis:
        ; ---- colour cycling ----
        ld a,(tspeed)
        ld b,a
        ld a,(tcol)
        add a,b
        ld (tcol),a
        ld (pa1),a
        ld (pa2),a
        ld (pa3),a
        ld (pa4),a
        ld (pb1),a
        ld (pb2),a
        ld (pb3),a
        ld (pb4),a
        ; ---- vertical field drift: row offset = sine ----
        ld a,(oph)
        inc a
        ld (oph),a
        ld l,a
        ld h,HIGH sine64
        ld a,(hl)               ; 0..63
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; *32
        ld de,(fbase)
        add hl,de
        ld (fptr),hl
        ; ---- scroller: 1 cell every 2 frames ----
        ld a,(pf)
        rrca
        jr nc,.nosc
        ld hl,(scpos)
        inc hl
        ld de,SCR_CELLS
        or a
        sbc hl,de
        add hl,de
        jr c,.sok
        ld hl,0
.sok:   ld (scpos),hl
.nosc:  ld hl,(scpos)
        ld a,l
        and 1                   ; phase
        srl h
        rr l                    ; base byte
        ld de,scroll
        add hl,de
        or a
        jr z,.ph0
        ld de,4*SCR_LEN
        add hl,de
.ph0:   ld (sp0),hl
        ld de,SCR_LEN
        add hl,de
        ld (sp1),hl
        add hl,de
        ld (sp2),hl
        add hl,de
        ld (sp3),hl
        ret
.fsel:  db 0,0,1,1,2,2,0,1
.psel:  db $10,$10,$21,$21,$43,$03,$04,$01   ; low nibble first half, high nibble second half

; ---------------------------------------------------------------------
        ALIGN 256
luts:   INCBIN "../build/p2/luts.bin"
sine64: INCBIN "../build/p2/sine64.bin"
fields: INCBIN "../build/p2/fields.bin"
scroll: INCBIN "../build/p2/scroll.bin"
sayscr: INCBIN "../build/p2/sayscr.bin"
p2_end:
        DISPLAY "p2 end: ", p2_end
        ASSERT p2_end <= $FA00
        SAVEBIN "../build/p2.bin", OVL, p2_end - OVL
