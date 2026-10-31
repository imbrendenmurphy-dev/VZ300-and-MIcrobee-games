; =====================================================================
;  VZ300 MEGADEMO 2026 - ViBED by BPM
;  engine.inc : constants, line-kernel macros, timing
; =====================================================================
;
;  THE LINE KERNEL
;  Every scanline is exactly 228 T-states.  Lines come in pairs (E,O).
;
;   E line:  RAST (48)  WORK_E (105)  SND_O (75)            = 228
;   O line:  RAST (48)  WORK_O (105)  SND_E (43)  LOOP (32)  = 228
;
;  RAST  pops 2 bytes from the raster table (SP) and writes them to the
;        latch, XORed with the speaker bits computed at the end of the
;        previous line.  2 writes per line: v1 then v2.  If v1/v2 differ
;        in the A/G bit the 6847 holds the current VRAM row (line hold).
;        Raster table bytes always have bit 5 set ($20) - the speaker
;        is driven push-pull by XORing $00/$21.
;  SND_E voice A  : HL'=acc DE'=freq, pulse width in I register
;  SND_O voice B  : IY =acc BC'=freq (square) XOR drum sample (IX)
;  LOOP  pair counter in A' (ex af,af')
;
;  Pulse-interleaving: voice A sounds on E lines, voice B+drums on O lines.
; =====================================================================

LATCH   EQU $6800
VRAM    EQU $7000
STACKTOP EQU $8000
SCRATCH EQU $F800
DOSOPEN EQU $5F00
DOSSEL  EQU $5F03
DOSNEXT EQU $5F09
DOSDEST EQU $FB80

; latch values (bit5 always set: speaker idle level)
M0      EQU $20         ; text / semigraphics, CSS0
M0O     EQU $30         ; text, CSS1 (orange text)
M1G     EQU $28         ; mode(1) CSS0 : green yellow blue red
M1W     EQU $38         ; mode(1) CSS1 : buff cyan magenta orange

; ---------------------------------------------------------------------
; WAIT n : exact delay, preserves all registers and flags (uses R reg)
; legal n: 4,8,9,10,12,13,14,16,17,18,19,20,21 ... (not 1-3,5,6,7,11,15)
; ---------------------------------------------------------------------
WAIT    MACRO tt
.wq = tt
        IF .wq % 4 = 1
          ld r,a
.wq = .wq - 9
        ENDIF
        IF .wq % 4 = 2
          jp $+3
.wq = .wq - 10
        ENDIF
        IF .wq % 4 = 3
          ld r,a
          jp $+3
.wq = .wq - 19
        ENDIF
        ASSERT .wq >= 0
        IF .wq >= 12
          DUP .wq / 12
            jr $+2
          EDUP
.wq = .wq % 12
        ENDIF
        IF .wq > 0
          DUP .wq / 4
            nop
          EDUP
        ENDIF
        ENDM

; long wait using B (clobbers B, flags): exact n >= 28
WAITB   MACRO tt
.wbk = (tt - 2) / 13
.wbr = tt - 2 - .wbk*13
        WHILE .wbr = 1 || .wbr = 2 || .wbr = 3 || .wbr = 5 || .wbr = 6 || .wbr = 7 || .wbr = 11 || .wbr = 15
.wbk = .wbk - 1
.wbr = .wbr + 13
        ENDW
        ASSERT .wbk >= 1
          ld b,.wbk
          djnz $
          WAIT .wbr
        ENDM

; ---------------------------------------------------------------------
; sound
; ---------------------------------------------------------------------
SND_E   MACRO           ; 43T  -> A = $00/$21
        exx
        add hl,de
        ld a,i
        cp h
        sbc a,a
        and $21
        exx
        ENDM

SND_O   MACRO           ; 75T  -> A = $00/$21
        exx
        add iy,bc
        ld a,iyh
        rla
        sbc a,a
        and $21
        xor (ix+0)
        inc ix
        exx
        ENDM

; ---------------------------------------------------------------------
; raster
; ---------------------------------------------------------------------
RAST    MACRO           ; 48T  writes at +27, +48. clobbers BC
        pop bc
        xor c
        ld (LATCH),a
        xor c
        xor b
        ld (LATCH),a
        ENDM

RASTHL  MACRO           ; 50T  writes at +47, +50 (3T apart). clobbers HL,E
        ld e,a
        pop hl
        xor l
        ld l,a
        ld a,e
        xor h
        ld h,a
        ld (LATCH),hl
        ENDM

; ---------------------------------------------------------------------
; loop control: A' holds pair count.  32T loop, 22T exit
; ---------------------------------------------------------------------
LOOPCTL MACRO lbl, ext
        ex af,af'
        dec a
        jp z,ext
        ex af,af'
        jp lbl
        ENDM
; at exit label put:  ex af,af'   (exit path total 22T: next line starts 10T early)

RASTC   MACRO val       ; 48T  constant latch value (no table), write at +28
        WAIT 8
        xor val
        ld (LATCH),a
        WAIT 20
        ENDM

; ---------------------------------------------------------------------
; Segment = setup pair + loop of `cnt` pairs.
;   rastm : RAST / RASTHL / RASTC-wrapper
;   ww    : work slot size (105 for RAST/RASTC, 103 for RASTHL)
;   su    : setup macro, must take exactly ww+10 T (E line of setup pair)
;   we,wo : work macros, exactly ww T each
;   cntv  : address of byte holding the pair count (>=1)
; A must hold the speaker bits on entry; entry is "10T early" (i.e. right
; after a previous segment's loop exit, or the frame start equivalent).
; ---------------------------------------------------------------------
SEG     MACRO lp, ext, rastm, ww, su, we, wo, cntv
        rastm
        su
        SND_O
        rastm
        WAIT (ww)+11
        SND_E
        ex af,af'
        ld a,(cntv)
        ex af,af'
lp:
        rastm
        we
        SND_O
        rastm
        wo
        SND_E
        LOOPCTL lp, ext
ext:
        ex af,af'
        ENDM

; work macros ----------------------------------------------------------
W_IDLE  MACRO
        WAIT 105
        ENDM
W_IDLEH MACRO
        WAIT 103
        ENDM
SU_NONE MACRO
        WAIT 115
        ENDM
SU_NONEH MACRO
        WAIT 113
        ENDM
W_COPY  MACRO           ; 105T : 6 bytes (HL)->(DE)
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        WAIT 9
        ENDM

; ---------------------------------------------------------------------
; SEG16: windowed copy, 16 bytes per row, 4 lines (2 pairs) per row.
; HL = source (contiguous 16-byte rows), DE = destination (row stride 32).
; RAST family. cntv = number of rows.
; ---------------------------------------------------------------------
SEG16   MACRO lp, ext, su, cntv
        RAST
        su
        SND_O
        RAST
        WAIT 116
        SND_E
        ex af,af'
        ld a,(cntv)
        ex af,af'
lp:
        RAST                    ; E1: 6 bytes
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        WAIT 9
        SND_O
        RAST                    ; O1: 6 bytes
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        WAIT 9
        SND_E
        WAIT 32
        RAST                    ; E2: 4 bytes + skip to next row
        ldi
        ldi
        ldi
        ldi
        ex de,hl
        ld bc,16
        add hl,bc
        ex de,hl
        WAIT 12
        SND_O
        RAST                    ; O2
        WAIT 105
        SND_E
        LOOPCTL lp, ext
ext:
        ex af,af'
        ENDM

; setup macros (exact T) -------------------------------------------------
; set HL from variable, DE immediate : 26T + pad -> 115 (RAST) / 113 (RASTHL)
SU_HLDE MACRO hv, dv
        ld hl,(hv)
        ld de,dv
        WAIT 89
        ENDM
SU_SP   MACRO sv                 ; switch raster table mid frame (RASTHL family: 113T)
        ld sp,(sv)
        WAIT 93
        ENDM
SU_SPR  MACRO sv                 ; same for RAST family (115T)
        ld sp,(sv)
        WAIT 95
        ENDM

