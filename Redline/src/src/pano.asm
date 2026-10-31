; =====================================================================
;  pano.asm - distant scenery: 256 px panorama (2 phases, 2 px steps)
;  rows 12-27 of the back buffer, scrolled by the bends
; =====================================================================
draw_pano:
        ld a,(panox+1)
        ld c,a
        rrca
        rrca
        and 63
        ld (pn_off),a
        ld hl,PANO
        bit 1,c
        jr z,.p0
        ld hl,PANO+1024
.p0:    ld de,BB
        ld a,(clip)             ; rows above the road only
        sub PANOTOP
        ret z
        ret c
        cp 17
        jr c,.n
        ld a,16
.n:     ld b,a
.r:     push bc
        push hl
        ld a,(pn_off)
        ld c,a
        ld b,0
        add hl,bc               ; src + off
        ld a,64
        sub c                   ; bytes before the wrap
        cp 32
        jr c,.split
        call ldi32
        jr .nx
.split: ld c,a
        push af
        call ldin
        pop af
        neg
        add a,32
        pop hl
        push hl
        call ldin
.nx:    pop hl
        ld bc,64
        add hl,bc
        pop bc
        djnz .r
        ret
pn_off: db 0

; copy A bytes (1..32) HL -> DE with an LDI chain
ldin:   add a,a
        neg
        add a,64
        ld (.j+1),a
.j:     jr $+2
ldi32:  REPT 32
        ldi
        ENDR
        ret
