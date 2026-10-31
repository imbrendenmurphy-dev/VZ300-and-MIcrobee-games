; =====================================================================
;  PART 3 : RASTER INSANITY                       music orders 14..21
;  A/B  Kefrens bars: mode(1) with a line-hold on every scanline so one
;       VRAM row is shown 130 times while bars are drawn into it,
;       mode(0) logo above, rolling colour-set bands.
;  C    synthwave mode(1) picture with rolling CSS raster bars, split to
;       a mode(0) copper-striped text scroller at the bottom.
;  D    FLD rubber stretch of the picture (holds on moving lines).
; =====================================================================
        INCLUDE "ovl.inc"

P3_END_ORDER EQU 22
KROW    EQU VRAM + 5*32         ; kefrens buffer row

KEFA    MACRO                   ; 103T: one 12-pixel bar per line
        ld a,(bc)
        inc c
        ld l,a
        ld h,HIGH KROW
        ld (hl),$BD
        inc l
        ld (hl),$55
        inc l
        ld (hl),$7E
        WAIT 43
        ENDM
KEFB    MACRO                   ; 103T: alternate bar colours
        ld a,(bc)
        inc c
        ld l,a
        ld h,HIGH KROW
        ld (hl),$6F
        inc l
        ld (hl),$FF
        inc l
        ld (hl),$F9
        WAIT 43
        ENDM
SU_K    MACRO                   ; 113T
        ld bc,(kptr)
        ld sp,(bptr)
        WAIT 73
        ENDM
SU_C2   MACRO
        SU_SP cptr
        ENDM

part_entry:
        ld a,(kernel_pairs)
        sub 63+66+1
        ld (kc3),a
        ld a,(kernel_pairs)
        sub 109+1
        ld (cc2),a
        ld a,(kernel_pairs)
        dec a
        ld (dd1),a
        call setup_k
        call logic_k
        call music_apply

; ------------------------------------------------- A/B kefrens frames
kframe:
        FRAME_START taptr
        SEG k1, k1x, RASTHL, 103, SU_NONEH, W_IDLEH, W_IDLEH, kc1
        SEG k2, k2x, RASTHL, 103, SU_K, KEFA, KEFA, kc2
        SEG k3, k3x, RAST, 105, SU_NONE, W_IDLE, W_IDLE, kc3
        FRAME_END
        call logic_k
        call music_apply
        ld a,(sect)
        or a
        jp z,kframe
        cp 1
        jp z,kframe2
        jp to_c

kframe2:
        FRAME_START taptr
        SEG l1, l1x, RASTHL, 103, SU_NONEH, W_IDLEH, W_IDLEH, kc1
        SEG l2, l2x, RASTHL, 103, SU_K, KEFB, KEFB, kc2
        SEG l3, l3x, RAST, 105, SU_NONE, W_IDLE, W_IDLE, kc3
        FRAME_END
        call logic_k
        call music_apply
        ld a,(sect)
        cp 1
        jp z,kframe2
        jp to_c

; ------------------------------------------------- C picture + copper text
to_c:   ; wipe the picture in (rows 0..50), then text rows
        ld hl,pic
        ld de,VRAM
        ld bc,51*32
        ld a,M1W
        call kcopy
        ld hl,crow
        ld de,VRAM+51*32
        ld bc,96
        ldir
        call logic_c
        call music_apply
cframe:
        FRAME_START pptr
        SEG c1, c1x, RASTHL, 103, SU_NONEH, W_IDLEH, W_IDLEH, cc1
        SEG c2, c2x, RASTHL, 103, SU_C2, W_IDLEH, W_IDLEH, cc2
        FRAME_END
        call logic_c
        call music_apply
        ld a,(sect)
        cp 2
        jp z,cframe
        ; ---- D: full picture, rubber stretch ----
        ld hl,pic+51*32
        ld de,VRAM+51*32
        ld bc,13*32
        ldir
        call logic_d
        call music_apply
dframe:
        FRAME_START sptr
        SEG d1, d1x, RASTHL, 103, SU_NONEH, W_IDLEH, W_IDLEH, dd1
        FRAME_END
        call logic_d
        call music_apply
        ld a,(sect)
        cp 3
        jp z,dframe
        ret

kc1:    db 62
kc2:    db 65
kc3:    db 0
cc1:    db 108
cc2:    db 0
dd1:    db 0
sect:   db 0
taptr:  dw ktabA
kptr:   dw 0
bptr:   dw 0
pptr:   dw 0
cptr:   dw 0
sptr:   dw 0
kt:     db 0
bt:     db 0
pf:     dw 0

setup_k:
        ld a,$80
        call cls
        ld hl,klogo
        ld de,VRAM
        ld bc,160
        ldir
        ret

logic_k:
        ld hl,(pf)
        inc hl
        ld (pf),hl
        ; clear the kefrens row (background colour 0)
        ld hl,KROW
        ld de,KROW+1
        ld bc,31
        ld (hl),0
        ldir
        ; bar path start advances
        ld a,(kt)
        add a,3
        ld (kt),a
        ld c,a
        ld a,(sect)
        or a
        ld b,HIGH ksine
        jr z,.s1
        ld b,HIGH ksine2
        ld a,c
        add a,2
        ld c,a
        ld (kt),a
.s1:    ld (kptr),bc
        ; colour bands roll
        ld a,(bt)
        inc a
        ld (bt),a
        and 63
        ld l,a
        ld h,0
        add hl,hl
        ld de,kband
        add hl,de
        ld (bptr),hl
        ; section changes
        ld a,(m_ordnum)
        cp 16
        jr c,.a
        cp 18
        jr c,.b
        ld a,2
        ld (sect),a
        ret
.b:     ld a,(sect)
        or a
        ret nz
        ld a,1
        ld (sect),a
        ret
.a:     xor a
        ld (sect),a
        ret

logic_c:
        ld hl,(pf)
        inc hl
        ld (pf),hl
        ; bars roll through the picture: offset 0..95
        ld a,(bt)
        inc a
        cp 96
        jr c,.b
        xor a
.b:     ld (bt),a
        ld l,a
        ld h,0
        add hl,hl
        ld de,ptab
        add hl,de
        ld (pptr),hl
        ; copper stripes in the text
        ld a,l
        and 15
        add a,a
        ld l,a
        ld h,0
        ld de,ctab
        add hl,de
        ld (cptr),hl
        ; coarse text scroll every 6 frames
        ld a,(.sc)
        inc a
        cp 6
        jr c,.ns
        ld hl,(.tp)
        inc hl
        ld de,ctext_end-32
        or a
        sbc hl,de
        add hl,de
        jr c,.tok
        ld hl,ctext
.tok:   ld (.tp),hl
        ld de,VRAM+52*32
        ld bc,32
        ldir
        xor a
.ns:    ld (.sc),a
        ld a,(m_ordnum)
        cp 20
        ret c
        ld a,3
        ld (sect),a
        ret
.sc:    db 0
.tp:    dw ctext

logic_d:
        ld hl,(pf)
        inc hl
        ld (pf),hl
        ld a,l
        and 14
        ld l,a
        ld h,0
        ld de,sptrs
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (sptr),hl
        ld a,(m_ordnum)
        cp P3_END_ORDER
        ret c
        ld a,4
        ld (sect),a
        ret

sptrs:
        DUP 8, ii
        dw stab + ii*600
        EDUP
mul16:  ld b,h
        ld c,l
        ld hl,0
        ld a,16
.l:     add hl,hl
        sla e
        rl d
        jr nc,.n
        add hl,bc
.n:     dec a
        jr nz,.l
        ret

crow:   ; text rows: inverse-space bar, message row, inverse-space bar
        DUP 32
        db $60
        EDUP
        DUP 32
        db $20
        EDUP
        DUP 32
        db $60
        EDUP

        ALIGN 256
ksine:  INCBIN "../build/p3/ksine.bin"
ksine2: INCBIN "../build/p3/ksine2.bin"
klogo:  INCBIN "../build/p3/klogo.bin"
ktabA:  INCBIN "../build/p3/ktabA.bin"
kband:  INCBIN "../build/p3/kband.bin"
pic:    INCBIN "../build/p3/pic.bin"
ptab:   INCBIN "../build/p3/ptab.bin"
stab:   INCBIN "../build/p3/stab.bin"
ctab:   INCBIN "../build/p3/ctab.bin"
ctext:  INCBIN "../build/p3/ctext.bin"
ctext_end:
p3_end:
        DISPLAY "p3 end: ", p3_end
        ASSERT p3_end <= $FA00
        SAVEBIN "../build/p3.bin", OVL, p3_end - OVL
